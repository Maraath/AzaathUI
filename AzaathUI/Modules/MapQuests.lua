--[[----------------------------------------------------------------------------
    AzaathUI - Modules/MapQuests.lua
    "Missões ativas" do mapa-múndi, da arte de conceito (tools/map-ui-concept/concept.webp):
      · agrupadas por zona como no diário da Blizzard (cabeçalho da zona recolhível, na ordem do diário)
      · um cartão por missão: "?" dourado (pronta para entregar, "— Entregar"), losango ciano com
        barra de progresso ("(8/10 Lobos)", "80%") e "!" (sem contagem)
      · clicar no cartão mostra a missão no mapa (anel pulsando e rota a partir de você) e abre os
        detalhes ao lado; clicar numa missão no mapa também abre os detalhes
      · detalhes completos como na janela de missões da Blizzard: título, nível e zona, resumo dos
        objetivos e o progresso, a descrição inteira, as recompensas (itens com ícone, as de escolher,
        dinheiro e experiência) e os botões Mostrar no mapa, Acompanhar e Compartilhar; o texto rola
    Dados: o diário do jogo (C_QuestLog / GetQuestLogTitle, GetQuestLogQuestText, recompensas...).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("MapQuests")

local TEX = Azaath.media.path .. "MapFrame\\"
local UITEX = Azaath.media.path .. "MapUI\\"
local min, max, floor = math.min, math.max, math.floor
local ipairs, type = ipairs, type

local CYAN = { 0.37, 0.89, 0.90 }
local CREAM = { 0.95, 0.92, 0.82 }
local TEAL = { 0.45, 0.78, 0.80 }
local MUTED = { 0.62, 0.66, 0.68 }
local GOLD = { 0.85, 0.71, 0.42 }
local PANEL_W, DETAIL_W = 300, 380             -- tela cheia; no modo janela: 262 e 330 (Layout)
local CARD_H, CARD_HP, HEAD_H = 60, 82, 30     -- cartão; com barra de progresso; cabeçalho de zona

local api, C                                   -- funções do mapa; a moldura (MapChrome: Nine, Tex, Font)
local U = { cards = {}, heads = {} }

local function Safe(fn, ...)
    if not fn then return end
    local ok, a, b, c, d, e, f, g, h = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h end
end

local function DB() return Azaath.db.worldmap end

---------------------------------------------------------------------------
-- Diário de missões
---------------------------------------------------------------------------
local QL = _G.C_QuestLog

local function NumEntries()
    if QL and QL.GetNumQuestLogEntries then return (QL.GetNumQuestLogEntries()) or 0 end
    return GetNumQuestLogEntries and (GetNumQuestLogEntries()) or 0
end

-- título, nível, é cabeçalho, questID, completa
local function EntryInfo(i)
    if QL and QL.GetInfo then
        local d = Safe(QL.GetInfo, i)
        if d then return d.title, d.level, d.isHeader, d.questID, d.isComplete end
    end
    if GetQuestLogTitle then
        local title, level, _, isHeader, _, isComplete, _, questID = GetQuestLogTitle(i)
        return title, level, isHeader, questID, isComplete
    end
end

local function Objectives(questID, index)
    local list = {}
    local objs = QL and QL.GetQuestObjectives and Safe(QL.GetQuestObjectives, questID)
    if type(objs) == "table" and #objs > 0 then
        for _, o in ipairs(objs) do
            list[#list + 1] = { text = o.text or "", done = o.finished, have = o.numFulfilled, need = o.numRequired }
        end
        return list
    end
    if index and GetNumQuestLeaderBoards and GetQuestLogLeaderBoard then
        for j = 1, (GetNumQuestLeaderBoards(index) or 0) do
            local text, _, finished = GetQuestLogLeaderBoard(j, index)
            local have, need = (text or ""):match("(%d+)%s*/%s*(%d+)")
            list[#list + 1] = { text = text or "", done = finished, have = tonumber(have), need = tonumber(need) }
        end
    end
    return list
end

-- as missões do diário, na ordem dele, com a zona (o cabeçalho) de cada uma
function M:List()
    local out, zone = {}, nil
    for i = 1, NumEntries() do
        local title, level, isHeader, questID, isComplete = EntryInfo(i)
        if isHeader then
            zone = title
        elseif title and questID then
            local done = (isComplete == 1 or isComplete == true) or (QL and QL.IsComplete and Safe(QL.IsComplete, questID)) or false
            local objs = Objectives(questID, i)
            local have, need, sub = 0, 0, nil
            for _, o in ipairs(objs) do
                if o.need and o.need > 0 then
                    have, need = have + min(o.have or 0, o.need), need + o.need
                    if not sub and not o.done then
                        local what = (o.text or ""):match("^(.-)%s*:%s*%d") or (o.text or ""):gsub("%s*%d+%s*/%s*%d+%s*", "")
                        sub = string.format("(%d/%d %s)", o.have or 0, o.need, what)
                    end
                end
            end
            out[#out + 1] = { questID = questID, index = i, title = title, level = level, zone = zone or "",
                done = done, objectives = objs, kind = done and "turnin" or (need > 0 and "progress" or "new"),
                pct = need > 0 and have / need or nil, sub = done and "— Entregar" or sub }
        end
    end
    return out
end

local function FindEntry(questID)
    for _, q in ipairs(M:List()) do if q.questID == questID then return q end end
end

---------------------------------------------------------------------------
-- Linhas da lista: cabeçalhos de zona e cartões
---------------------------------------------------------------------------
local ICON = { turnin = "QTurnIn", progress = "QProgress", new = "QNew" }

-- um pixel da tela em unidades de interface do quadro (linhas nítidas em qualquer escala)
local function Pixel(frame)
    local f = (PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()) or 1
    local s = frame:GetEffectiveScale() or 1
    return f / (s > 0 and s or 1)
end

local function Grad(t, orient, r1, g1, b1, a1, r2, g2, b2, a2)
    t:SetColorTexture(1, 1, 1, 1)
    if _G.CreateColor and pcall(t.SetGradient, t, orient, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2)) then return end
    if t.SetGradientAlpha and pcall(t.SetGradientAlpha, t, orient, r1, g1, b1, a1, r2, g2, b2, a2) then return end
    t:SetColorTexture((r1 + r2) / 2, (g1 + g2) / 2, (b1 + b2) / 2, (a1 + a2) / 2)
end

-- caixa da arte (cartão): fundo de ardósia com cantos redondos e UM filete bronze-cinza, com os
-- cantos em arco liso. As retas são linhas de exatamente 1 pixel da tela (nítidas em qualquer
-- escala); os arcos (Media/MapFrame/CardArc) têm a mesma espessura: raio de 6 pixels da tela.
-- Sob o mouse o filete clareia; selecionado fica ciano, com um brilho subindo por dentro.
local BOX = {
    normal = { 0.43, 0.42, 0.34 },
    hover  = { 0.64, 0.62, 0.50 },
    sel    = { 0.37, 0.89, 0.90 },
}
local function Box(parent)
    local b = C.RoundBox(parent, 6, { 0.085, 0.113, 0.133, 0.97 }, BOX.normal)
    local p, R = b.p, b.R
    b.glow = parent:CreateTexture(nil, "BACKGROUND", nil, -2)
    b.glow:SetPoint("TOPLEFT", R, -2 * p); b.glow:SetPoint("BOTTOMRIGHT", -R, 2 * p)
    Grad(b.glow, "VERTICAL", 0.37, 0.89, 0.90, 0.0, 0.37, 0.89, 0.90, 0.12)
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()
    -- luz fina no alto, por dentro (volume da arte)
    local hi = parent:CreateTexture(nil, "BORDER", nil, 0)
    hi:SetColorTexture(1, 1, 1, 0.045)
    hi:SetPoint("TOPLEFT", R, -2 * p); hi:SetPoint("TOPRIGHT", -R, -2 * p); hi:SetHeight(p)
    function b:SetState(st)
        local c = BOX[st] or BOX.normal
        self:SetEdgeColor(c[1], c[2], c[3], 1)
        self.glow:SetShown(st == "sel")
        self.state = st
    end
    function b:SetPulse(a)
        self:SetEdgeAlpha(a)
        self.glow:SetAlpha(a)
    end
    b:SetState("normal")
    return b
end
M.Box = Box

-- barra de progresso nítida: trilho escuro com filete, preenchimento ciano em degradê e brilho
local function Bar(parent)
    local b = CreateFrame("Frame", nil, parent)
    b:SetHeight(8)
    local p = Pixel(parent)
    local bg = b:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.03, 0.05, 0.06, 0.95)
    for _, side in ipairs({ "TOP", "BOTTOM" }) do
        local t = b:CreateTexture(nil, "BORDER"); t:SetColorTexture(0.24, 0.31, 0.33, 1)
        t:SetPoint(side .. "LEFT"); t:SetPoint(side .. "RIGHT"); t:SetHeight(p)
    end
    for _, side in ipairs({ "LEFT", "RIGHT" }) do
        local t = b:CreateTexture(nil, "BORDER"); t:SetColorTexture(0.24, 0.31, 0.33, 1)
        t:SetPoint("TOP" .. side); t:SetPoint("BOTTOM" .. side); t:SetWidth(p)
    end
    b.fill = b:CreateTexture(nil, "ARTWORK")
    b.fill:SetPoint("TOPLEFT", 2 * p, -2 * p); b.fill:SetPoint("BOTTOMLEFT", 2 * p, 2 * p)
    Grad(b.fill, "HORIZONTAL", 0.09, 0.50, 0.58, 1, 0.62, 0.97, 1.0, 1)
    b.tip = b:CreateTexture(nil, "OVERLAY")
    b.tip:SetTexture(TEX .. "BarShine")
    b.tip:SetSize(18, 12)
    b.tip:SetBlendMode("ADD")
    b.shine = b:CreateTexture(nil, "OVERLAY")
    b.shine:SetTexture(TEX .. "BarShine")
    b.shine:SetSize(28, 10)
    b.shine:SetBlendMode("ADD")
    function b:SetValue(v)
        local w = (self:GetWidth() or 0) - 4 * p
        if w <= 0 then w = PANEL_W - 24 - 70 end
        self.w = max(0, w * (v or 0))
        self.fill:SetWidth(max(p, self.w))
        self.fill:SetShown((v or 0) > 0)
        self.tip:ClearAllPoints()
        self.tip:SetPoint("CENTER", self, "LEFT", 2 * p + self.w, 0)
        self.tip:SetShown((v or 0) > 0)
    end
    return b
end

local function Head(i)
    local h = U.heads[i]
    if h then return h end
    h = CreateFrame("Button", nil, U.list)
    h:SetHeight(HEAD_H)
    local p = Pixel(h)
    -- faixa da zona: fundo teal escuro, acento ciano à esquerda e filete embaixo
    h.bg = h:CreateTexture(nil, "BACKGROUND")
    h.bg:SetAllPoints()
    Grad(h.bg, "HORIZONTAL", 0.07, 0.20, 0.23, 0.85, 0.05, 0.10, 0.12, 0.25)
    h.accent = h:CreateTexture(nil, "BORDER")
    h.accent:SetPoint("TOPLEFT"); h.accent:SetPoint("BOTTOMLEFT")
    h.accent:SetWidth(3)
    h.accent:SetColorTexture(CYAN[1], CYAN[2], CYAN[3], 0.95)
    h.under = h:CreateTexture(nil, "BORDER")
    h.under:SetPoint("BOTTOMLEFT"); h.under:SetPoint("BOTTOMRIGHT")
    h.under:SetHeight(p)
    Grad(h.under, "HORIZONTAL", CYAN[1], CYAN[2], CYAN[3], 0.6, CYAN[1], CYAN[2], CYAN[3], 0.0)
    h.arrow = h:CreateTexture(nil, "ARTWORK")
    h.arrow:SetSize(14, 14)
    h.arrow:SetPoint("LEFT", 10, 0)
    h.arrow:SetVertexColor(CYAN[1], CYAN[2], CYAN[3])
    h.fs = h:CreateFontString(nil, "OVERLAY")
    local m = Azaath.media or {}
    if not (m.fontTitleB and pcall(h.fs.SetFont, h.fs, m.fontTitleB, 13, "")) then C.Font(h.fs, 13, true) end
    h.fs:SetShadowOffset(1, -1); h.fs:SetShadowColor(0, 0, 0, 0.9)
    h.fs:SetPoint("LEFT", h.arrow, "RIGHT", 6, 0)
    h.fs:SetJustifyH("LEFT"); h.fs:SetWordWrap(false)
    h.fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    h.count = h:CreateFontString(nil, "OVERLAY"); C.Font(h.count, 12, true)
    h.count:SetPoint("RIGHT", -10, 0)
    h.count:SetTextColor(TEAL[1], TEAL[2], TEAL[3])
    h.fs:SetPoint("RIGHT", h.count, "LEFT", -8, 0)
    local hl = h:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(CYAN[1], CYAN[2], CYAN[3], 0.08)
    h:SetScript("OnClick", function(self)
        local c = DB().questCollapsed
        c[self.zone] = not c[self.zone] or nil
        M:Refresh()
    end)
    U.heads[i] = h
    return h
end

local function TextW(fs) return fs.GetUnboundedStringWidth and fs:GetUnboundedStringWidth() or fs:GetStringWidth() end

-- o nome da zona cabe inteiro: a fonte desce de 13 até 10; se ainda não couber, quebra em 2 linhas
local function FitHead(hd, text)
    local font = (Azaath.media or {}).fontTitleB
    local function Size(sz)
        if not (font and pcall(hd.fs.SetFont, hd.fs, font, sz, "")) then C.Font(hd.fs, sz, true) end
    end
    hd.fs:SetWordWrap(false)
    hd.fs:SetText(text)
    local room = (hd:GetWidth() or 0) - 34 - (hd.count:GetStringWidth() or 0) - 14
    local size = 13
    Size(size)
    while size > 10 and room > 0 and TextW(hd.fs) > room do
        size = size - 1
        Size(size)
    end
    if room > 0 and TextW(hd.fs) > room then
        hd.fs:SetWordWrap(true)
        hd.fs:SetMaxLines(2)
        hd:SetHeight(HEAD_H + 12)
    else
        hd:SetHeight(HEAD_H)
    end
end

local function Card(i)
    local c = U.cards[i]
    if c then return c end
    c = CreateFrame("Button", nil, U.list)
    c.box = Box(c)
    c.icon = C.Tex(c, "QTurnIn", 34, 34)
    c.icon:SetPoint("TOPLEFT", 12, -12)
    c.title = c:CreateFontString(nil, "OVERLAY"); C.Font(c.title, 15, true)
    c.title:SetJustifyH("LEFT"); c.title:SetWordWrap(false)
    c.title:SetTextColor(CREAM[1], CREAM[2], CREAM[3])
    c.sub = c:CreateFontString(nil, "OVERLAY"); C.Font(c.sub, 13)
    c.sub:SetPoint("TOPLEFT", 56, -34); c.sub:SetPoint("RIGHT", -12, 0)
    c.sub:SetJustifyH("LEFT"); c.sub:SetWordWrap(false)
    -- barra de progresso
    c.pct = c:CreateFontString(nil, "OVERLAY"); C.Font(c.pct, 13)
    c.pct:SetPoint("BOTTOMLEFT", 12, 11)
    c.pct:SetTextColor(TEAL[1], TEAL[2], TEAL[3])
    c.bar = Bar(c)
    c.bar:SetPoint("BOTTOMLEFT", 56, 14); c.bar:SetPoint("BOTTOMRIGHT", -14, 14)
    c:SetScript("OnClick", function(self) M:Open(self.questID, true) end)
    c:SetScript("OnEnter", function(self) if U.sel ~= self.questID then self.box:SetState("hover") end end)
    c:SetScript("OnLeave", function(self) if U.sel ~= self.questID then self.box:SetState("normal") end end)
    U.cards[i] = c
    return c
end

-- linhas da lista: { head = zona, n = quantas } ou { quest = q }
local function Rows(list)
    local rows, idx = {}, {}
    local collapsed = DB().questCollapsed
    for _, q in ipairs(list) do
        if not idx[q.zone] then
            idx[q.zone] = { head = q.zone, n = 0 }
            rows[#rows + 1] = idx[q.zone]
        end
        local h = idx[q.zone]
        h.n = h.n + 1
        if not collapsed[q.zone] then rows[#rows + 1] = { quest = q } end
    end
    return rows
end

function M:Refresh()
    if not U.panel then return end
    local list = self:List()
    U.data = list
    local rows = Rows(list)
    U.rows = rows
    for _, c in ipairs(U.cards) do c:Hide() end
    for _, h in ipairs(U.heads) do h:Hide() end
    local maxH = U.list:GetHeight()
    U.offset = max(0, min(U.offset or 0, #rows - 1))
    local y, nc, nh, last = 0, 0, 0, U.offset
    for i = 1 + U.offset, #rows do
        local r = rows[i]
        local h = r.head and HEAD_H or (r.quest.kind == "progress" and CARD_HP or CARD_H)
        if y + h > maxH and (nc + nh) > 0 then break end
        last = i
        if r.head then
            nh = nh + 1
            local hd = Head(nh)
            hd.zone = r.head
            if nh > 1 or i > 1 then y = y + 8 end        -- respiro entre um grupo e outro
            hd:ClearAllPoints()
            hd:SetPoint("TOPLEFT", 0, -y); hd:SetPoint("TOPRIGHT", 0, -y)
            hd.count:SetText(r.n)
            FitHead(hd, Azaath.Upper and Azaath.Upper(r.head ~= "" and r.head or "Outras") or r.head)
            h = hd:GetHeight()
            hd.arrow:SetTexture(UITEX .. (DB().questCollapsed[r.head] and "ChevronRight.tga" or "ChevronDown.tga"))
            hd:Show()
            y = y + h + 6
        else
            local q = r.quest
            nc = nc + 1
            local c = Card(nc)
            c.questID = q.questID
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", 0, -y); c:SetPoint("TOPRIGHT", 0, -y)
            c:SetHeight(h)
            c.box:SetState(U.sel == q.questID and "sel" or "normal")
            c.icon:SetTexture(TEX .. ICON[q.kind])
            c.title:SetText(q.title)
            c.title:ClearAllPoints()
            if q.sub then
                c.sub:SetText(q.sub); c.sub:Show()
                local col = q.kind == "turnin" and TEAL or MUTED
                c.sub:SetTextColor(col[1], col[2], col[3])
                c.title:SetPoint("TOPLEFT", 56, -13); c.title:SetPoint("RIGHT", -12, 0)
            else
                c.sub:Hide()
                c.title:SetPoint("TOPLEFT", 56, -21); c.title:SetPoint("RIGHT", -12, 0)
            end
            if q.kind == "progress" then
                c.pct:SetText(floor((q.pct or 0) * 100 + 0.5) .. "%"); c.pct:Show()
                c.bar:Show()
                c.bar:SetValue(q.pct or 0)
            else
                c.pct:Hide(); c.bar:Hide()
            end
            c:Show()
            y = y + h + 8
        end
    end
    U.empty:SetShown(#list == 0)
    U.more:SetShown(last < #rows)
    if U.detail:IsShown() and U.sel then self:ShowDetail(U.sel) end
end

---------------------------------------------------------------------------
-- Detalhes da missão (rolam)
---------------------------------------------------------------------------
local function Btn(parent, label, w)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w or 120, 28)
    C.Nine(b, "Button", 6, 6, "BACKGROUND")
    b.fs = b:CreateFontString(nil, "OVERLAY"); C.Font(b.fs, 13, true)
    b.fs:SetPoint("CENTER")
    b.fs:SetText(label)
    b.fs:SetTextColor(CREAM[1], CREAM[2], CREAM[3])
    local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(CYAN[1], CYAN[2], CYAN[3], 0.14)
    return b
end

local function IsWatched(q)
    if QL and QL.GetQuestWatchType then return Safe(QL.GetQuestWatchType, q.questID) ~= nil end
    if IsQuestWatched then return Safe(IsQuestWatched, q.index) and true or false end
    return false
end

local function SetWatched(q, on)
    if QL and QL.AddQuestWatch and QL.RemoveQuestWatch then
        if on then Safe(QL.AddQuestWatch, q.questID) else Safe(QL.RemoveQuestWatch, q.questID) end
    elseif on and AddQuestWatch then Safe(AddQuestWatch, q.index)
    elseif RemoveQuestWatch then Safe(RemoveQuestWatch, q.index) end
end

-- peças do conteúdo: textos e linhas de item, reaproveitados a cada missão
local function DText(i)
    local d = U.detail
    local fs = d.texts[i]
    if not fs then
        fs = d.content:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetJustifyV("TOP")
        d.texts[i] = fs
    end
    fs:Show()
    return fs
end

local function DItem(i)
    local d = U.detail
    local it = d.items[i]
    if not it then
        it = CreateFrame("Button", nil, d.content)
        it:SetSize((U.dw or DETAIL_W) - 56, 34)
        it.box = Box(it)
        it.icon = it:CreateTexture(nil, "ARTWORK")
        it.icon:SetSize(26, 26)
        it.icon:SetPoint("LEFT", 5, 0)
        it.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        it.count = it:CreateFontString(nil, "OVERLAY"); C.Font(it.count, 11, true)
        it.count:SetPoint("BOTTOMRIGHT", it.icon, "BOTTOMRIGHT", 1, -1)
        it.fs = it:CreateFontString(nil, "OVERLAY"); C.Font(it.fs, 13, true)
        it.fs:SetPoint("LEFT", it.icon, "RIGHT", 8, 0); it.fs:SetPoint("RIGHT", -6, 0)
        it.fs:SetJustifyH("LEFT"); it.fs:SetWordWrap(false)
        it:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if GameTooltip.SetQuestLogItem then pcall(GameTooltip.SetQuestLogItem, GameTooltip, self.kind, self.slot) end
            GameTooltip:Show()
        end)
        it:SetScript("OnLeave", function() GameTooltip:Hide() end)
        d.items[i] = it
    end
    it:Show()
    return it
end

local function QualityColor(q)
    local c = _G.ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q or 1]
    if c then return c.r, c.g, c.b end
    return 1, 1, 1
end

function M:ShowDetail(questID)
    local q = FindEntry(questID)
    local d = U.detail
    if not q then d:Hide() return end
    d.title:SetText(q.title)
    d.meta:SetText(((q.level and q.level > 0) and ("Nível " .. q.level) or "") .. (q.zone ~= "" and ("  -  " .. q.zone) or ""))
    -- texto e recompensas: o diário precisa da missão selecionada (cliente moderno: pelo ID;
    -- antigo: pelo índice). GetQuestLogQuestText aceita o índice; as recompensas, o ID.
    if QL and QL.SetSelectedQuest then Safe(QL.SetSelectedQuest, questID) end
    if SelectQuestLogEntry and q.index then Safe(SelectQuestLogEntry, q.index) end
    local desc, objText = Safe(GetQuestLogQuestText, q.index)
    if (not desc or desc == "") then desc, objText = Safe(GetQuestLogQuestText) end
    for _, fs in ipairs(d.texts) do fs:Hide() end
    for _, it in ipairs(d.items) do it:Hide() end
    local W = (U.dw or DETAIL_W) - 40
    d.content:SetWidth(W)
    local y, nt, ni = 0, 0, 0
    local function Text(str, size, color, bold, gap)
        if not str or str == "" then return end
        nt = nt + 1
        local fs = DText(nt)
        C.Font(fs, size, bold)
        fs:SetWidth(W)
        fs:SetTextColor(color[1], color[2], color[3])
        fs:SetText(str)
        fs:ClearAllPoints()
        fs:SetPoint("TOPLEFT", 0, -y)
        y = y + fs:GetStringHeight() + (gap or 8)
    end
    local function Section(label) y = y + 6; Text(Azaath.Upper and Azaath.Upper(label) or label, 13, GOLD, true, 6) end
    local function Item(kind, slot, name, tex, count, quality)
        ni = ni + 1
        local it = DItem(ni)
        it.kind, it.slot = kind, slot
        it.icon:SetTexture(tex)
        it.count:SetText((count and count > 1) and count or "")
        it.fs:SetText(name or "")
        it.fs:SetTextColor(QualityColor(quality))
        it:ClearAllPoints()
        it:SetPoint("TOPLEFT", 0, -y)
        y = y + 38
    end

    -- objetivos: o resumo do jogo e o progresso de cada um
    Section("Objetivos")
    if q.done then Text("Pronta para entregar.", 14, TEAL, true, 6) end
    Text(objText, 14, { 0.86, 0.86, 0.84 }, false, 8)
    for _, o in ipairs(q.objectives) do
        local col = o.done and { 0.5, 0.85, 0.55 } or { 0.86, 0.86, 0.84 }
        Text((o.done and "[x]  " or "[  ]  ") .. (o.text or ""), 13, col, false, 4)
    end
    -- descrição completa
    if desc and desc ~= "" then
        Section("Descrição")
        Text(desc, 13, { 0.80, 0.82, 0.82 }, false, 8)
    end
    -- recompensas
    local nRew = Safe(GetNumQuestLogRewards, questID) or Safe(GetNumQuestLogRewards) or 0
    local nCho = Safe(GetNumQuestLogChoices, questID) or Safe(GetNumQuestLogChoices) or 0
    local money = Safe(GetQuestLogRewardMoney, questID) or Safe(GetQuestLogRewardMoney) or 0
    local xp = Safe(GetQuestLogRewardXP, questID) or Safe(GetQuestLogRewardXP) or 0
    -- diagnóstico (AzaathUIDB.worldmap.questDiag): o que o jogo devolveu para esta missão
    DB().questDiag = { time = date("%H:%M:%S"), questID = questID, index = q.index, title = q.title,
        desc = desc and #desc or -1, obj = objText and #objText or -1, objectives = #q.objectives,
        rewards = nRew, choices = nCho, money = money, xp = xp,
        api = (QL and QL.SetSelectedQuest and "SetSelectedQuest " or "") .. (SelectQuestLogEntry and "SelectQuestLogEntry " or "")
            .. (GetQuestLogQuestText and "GetQuestLogQuestText" or "-") }
    if (nRew or 0) > 0 or (nCho or 0) > 0 or (money or 0) > 0 or (xp or 0) > 0 then
        Section("Recompensas")
        if (nCho or 0) > 0 then
            Text("Você poderá escolher uma destas recompensas:", 13, MUTED, false, 6)
            for i = 1, nCho do
                local name, tex, count, quality = Safe(GetQuestLogChoiceInfo, i, questID)
                Item("choice", i, name, tex, count, quality)
            end
            y = y + 4
        end
        if (nRew or 0) > 0 then
            Text("Você receberá:", 13, MUTED, false, 6)
            for i = 1, nRew do
                local name, tex, count, quality = Safe(GetQuestLogRewardInfo, i, questID)
                Item("reward", i, name, tex, count, quality)
            end
            y = y + 4
        end
        if (money or 0) > 0 and GetCoinTextureString then Text(GetCoinTextureString(money), 14, CREAM, false, 6) end
        if (xp or 0) > 0 then Text(xp .. " de experiência", 13, TEAL, false, 6) end
    end
    d.content:SetHeight(max(1, y))
    d.scroll:SetVerticalScroll(0)
    d.scroll.max = max(0, y - d.scroll:GetHeight())
    d.hint:SetShown(d.scroll.max > 0)

    d.track.fs:SetText(IsWatched(q) and "Não acompanhar" or "Acompanhar")
    d.track:SetScript("OnClick", function() SetWatched(q, not IsWatched(q)); M:ShowDetail(questID) end)
    d.share:SetScript("OnClick", function()
        if SelectQuestLogEntry then Safe(SelectQuestLogEntry, q.index) end
        if QuestLogPushQuest then Safe(QuestLogPushQuest) end
    end)
    d.show:SetScript("OnClick", function() M:Locate(questID) end)
    d.noMark:SetShown(not api.FindQuest(questID))
    d:Show()
end

-- mostra a missão no mapa (anel + rota) e diz se ela tem marca
function M:Locate(questID)
    local ok = api.FocusQuest(questID)
    U.detail.noMark:SetShown(not ok)
    return ok
end

-- abre a missão: seleciona o cartão, mostra os detalhes e (se pedido) leva o mapa até ela
function M:Open(questID, focus)
    local chrome = Azaath:GetModule("MapChrome")
    if chrome and chrome.SetActive and not U.panel:IsShown() then chrome:SetActive("quests") end
    U.sel = questID
    -- a zona dela aberta, e o cartão à vista
    local q = FindEntry(questID)
    if q and DB().questCollapsed[q.zone] then DB().questCollapsed[q.zone] = nil end
    for i, r in ipairs(Rows(self:List())) do
        if r.quest and r.quest.questID == questID then
            local first = (U.offset or 0) + 1
            if i < first or i > first + 6 then U.offset = max(0, i - 2) end
        end
    end
    self:Refresh()
    if focus then self:Locate(questID) else api.SelectQuest(questID) end
    self:ShowDetail(questID)
end

function M:SetShown(on)
    if not U.panel then return end
    U.panel:SetShown(on)
    if not on then U.detail:Hide() end
    if on then self:Refresh() end
end

---------------------------------------------------------------------------
function M:Build(f, v, mapApi)
    api = mapApi
    C = Azaath:GetModule("MapChrome")
    if not C then return end
    if type(DB().questCollapsed) ~= "table" then DB().questCollapsed = {} end
    -- painel "MISSÕES ATIVAS" (ao lado do estandarte da esquerda)
    local p = CreateFrame("Frame", nil, f)
    if C.PanelAnchor then C.PanelAnchor(p) else p:SetPoint("TOPLEFT", v, "TOPLEFT", 78, -24) end
    p:SetWidth(PANEL_W)
    p:SetFrameLevel(f:GetFrameLevel() + 32)
    p:EnableMouse(true)
    p:EnableMouseWheel(true)
    C.PanelBox(p)
    local gem = C.Tex(p, "PanelGem", 20, 12, "OVERLAY")
    gem:SetPoint("CENTER", p, "TOP", 0, 0)
    local hdr = p:CreateFontString(nil, "OVERLAY"); C.Font(hdr, 18)
    hdr:SetPoint("TOPLEFT", 16, -16)
    hdr:SetText(Azaath.Upper and Azaath.Upper("Missões ativas") or "MISSÕES ATIVAS")
    hdr:SetTextColor(0.88, 0.9, 0.9)
    -- fechar o painel (pelo menu lateral, para o ícone de Missões apagar junto)
    local px = CreateFrame("Button", nil, p)
    px:SetSize(24, 24); px:SetPoint("TOPRIGHT", -8, -8)
    local pxi = C.Tex(px, "IcoClose", 14, 14); pxi:SetPoint("CENTER")
    px:SetScript("OnEnter", function() pxi:SetVertexColor(TEAL[1], TEAL[2], TEAL[3]) end)
    px:SetScript("OnLeave", function() pxi:SetVertexColor(1, 1, 1) end)
    px:SetScript("OnClick", function()
        if C.SetActive then C:SetActive(nil) else M:SetShown(false) end
    end)
    hdr:SetPoint("RIGHT", px, "LEFT", -4, 0)
    hdr:SetJustifyH("LEFT")
    local rule = C.Tex(p, "Rule", nil, 10, "OVERLAY")
    rule:SetPoint("TOPLEFT", 10, -42); rule:SetPoint("TOPRIGHT", -10, -42)
    rule:SetBlendMode("ADD")
    U.rule = rule
    local list = CreateFrame("Frame", nil, p)
    list:SetPoint("TOPLEFT", 12, -58); list:SetPoint("BOTTOMRIGHT", -12, 26)
    U.list = list
    U.empty = p:CreateFontString(nil, "OVERLAY"); C.Font(U.empty, 14)
    U.empty:SetPoint("TOP", list, "TOP", 0, -10)
    U.empty:SetText("Nenhuma missão no diário.")
    U.empty:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    U.more = p:CreateFontString(nil, "OVERLAY"); C.Font(U.more, 12)
    U.more:SetPoint("BOTTOM", 0, 8)
    U.more:SetText("role para ver mais")
    U.more:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    p:SetScript("OnMouseWheel", function(_, delta)
        U.offset = max(0, (U.offset or 0) - delta)
        M:Refresh()
    end)
    p:Hide()
    U.panel = p

    -- detalhes (ao lado do painel); o conteúdo rola com a roda do mouse
    local d = CreateFrame("Frame", nil, f)
    d:SetPoint("TOPLEFT", p, "TOPRIGHT", 12, 0)
    d:SetWidth(DETAIL_W)
    d:SetFrameLevel(f:GetFrameLevel() + 32)
    d:EnableMouse(true)
    C.PanelBox(d)
    local dgem = C.Tex(d, "PanelGem", 20, 12, "OVERLAY")
    dgem:SetPoint("CENTER", d, "TOP", 0, 0)
    local x = CreateFrame("Button", nil, d)
    x:SetSize(24, 24); x:SetPoint("TOPRIGHT", -8, -8)
    local xi = C.Tex(x, "IcoClose", 14, 14); xi:SetPoint("CENTER")
    x:SetScript("OnClick", function() d:Hide() end)      -- (a missão continua marcada no mapa)
    d.title = d:CreateFontString(nil, "OVERLAY"); C.Font(d.title, 18, true)
    d.title:SetPoint("TOPLEFT", 18, -16); d.title:SetPoint("RIGHT", -36, 0)
    d.title:SetJustifyH("LEFT")
    d.title:SetTextColor(CREAM[1], CREAM[2], CREAM[3])
    d.meta = d:CreateFontString(nil, "OVERLAY"); C.Font(d.meta, 13)
    d.meta:SetPoint("TOPLEFT", d.title, "BOTTOMLEFT", 0, -4)
    d.meta:SetTextColor(TEAL[1], TEAL[2], TEAL[3])
    local drule = C.Tex(d, "Rule", nil, 10, "OVERLAY")
    drule:SetPoint("TOPLEFT", d.meta, "BOTTOMLEFT", -8, -6); drule:SetPoint("RIGHT", -10, 0)
    drule:SetBlendMode("ADD")
    local sf = CreateFrame("ScrollFrame", nil, d)
    sf:SetPoint("TOPLEFT", drule, "BOTTOMLEFT", 8, -6)
    sf:SetPoint("BOTTOMRIGHT", -14, 76)
    sf:EnableMouseWheel(true)
    local content = CreateFrame("Frame", nil, sf)
    content:SetSize(DETAIL_W - 40, 10)
    sf:SetScrollChild(content)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local nv = max(0, min(self.max or 0, self:GetVerticalScroll() - delta * 40))
        self:SetVerticalScroll(nv)
    end)
    d.scroll, d.content, d.texts, d.items = sf, content, {}, {}
    d.hint = d:CreateFontString(nil, "OVERLAY"); C.Font(d.hint, 11)
    d.hint:SetPoint("BOTTOMRIGHT", -16, 62)
    d.hint:SetText("role para ler tudo")
    d.hint:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    d.noMark = d:CreateFontString(nil, "OVERLAY"); C.Font(d.noMark, 12)
    d.noMark:SetPoint("BOTTOMLEFT", 18, 50)
    d.noMark:SetText("Esta missão não tem marca no mapa.")
    d.noMark:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    -- três botões do mesmo tamanho, dividindo a largura da janela (LayoutButtons)
    d.show = Btn(d, "Ver no mapa"); d.track = Btn(d, "Acompanhar"); d.share = Btn(d, "Compartilhar")
    for _, b in ipairs({ d.show, d.track, d.share }) do C.Font(b.fs, 12, true); b.fs:SetWidth(0) end
    local function LayoutButtons()
        local gap, side = 6, 12
        local w = floor(((U.dw or DETAIL_W) - 2 * side - 2 * gap) / 3)
        d.show:ClearAllPoints(); d.show:SetPoint("BOTTOMLEFT", side, 12); d.show:SetSize(w, 26)
        d.track:ClearAllPoints(); d.track:SetPoint("LEFT", d.show, "RIGHT", gap, 0); d.track:SetSize(w, 26)
        d.share:ClearAllPoints(); d.share:SetPoint("LEFT", d.track, "RIGHT", gap, 0); d.share:SetSize(w, 26)
        for _, b in ipairs({ d.show, d.track, d.share }) do
            b.fs:ClearAllPoints(); b.fs:SetPoint("LEFT", 4, 0); b.fs:SetPoint("RIGHT", -4, 0)
            b.fs:SetJustifyH("CENTER"); b.fs:SetWordWrap(false)
        end
    end
    U.layoutButtons = LayoutButtons
    d:Hide()
    U.detail = d

    -- altura dos painéis: acompanha a janela (ficam acima da barra de status)
    local function Layout()
        local h = v:GetHeight() or 600
        local maxed = api.IsMaximized and api.IsMaximized()
        -- no modo janela as duas ficam mais estreitas e mais baixas, para o mapa respirar
        U.pw, U.dw = maxed and PANEL_W or 262, maxed and DETAIL_W or 300
        if U.layoutButtons then U.layoutButtons() end
        -- escala menor (cartões, fontes e botões juntos) e altura limitada: o mapa fica à vista
        local s = maxed and 0.7 or 0.64
        p:SetScale(s)
        d:SetScale(s)
        if C.PanelAnchor then C.PanelAnchor(p) end
        p:SetWidth(U.pw)
        d:SetWidth(U.dw)
        p:SetHeight(max(220, min((maxed and (h - 110) or (h * 0.70)) / s, maxed and 600 or 560)))
        d:SetHeight(max(280, min((maxed and (h - 110) or (h * 0.62)) / s, maxed and 540 or 480)))
        if d:IsShown() and U.sel then M:ShowDetail(U.sel) end
        if p:IsShown() then M:Refresh() end
    end
    v:HookScript("OnSizeChanged", Layout)
    Layout()

    -- efeito Azaath: brilho correndo nas barras de progresso e o cartão selecionado pulsando
    p:SetScript("OnUpdate", function()
        local t = GetTime()
        for _, c in ipairs(U.cards) do
            if c:IsShown() and c.bar:IsShown() and (c.bar.w or 0) > 0 then
                local k = (t * 0.6 + (c.questID or 0) * 0.13) % 1
                c.bar.shine:ClearAllPoints()
                c.bar.shine:SetPoint("CENTER", c.bar, "LEFT", k * c.bar.w, 0)
                c.bar.shine:SetAlpha(c.bar.w > 10 and 0.8 or 0)
                c.bar.tip:SetAlpha(0.6 + 0.4 * math.sin(t * 3))
            elseif c:IsShown() then
                c.bar.shine:SetAlpha(0)
            end
            if c:IsShown() then c.box:SetPulse(U.sel == c.questID and (0.75 + 0.25 * math.sin(t * 3)) or 1) end
        end
        U.rule:SetAlpha(0.75 + 0.25 * math.sin(t * 2.2))
    end)

    -- clique numa missão do mapa: abre os detalhes
    local WM = Azaath:GetModule("WorldMap")
    if WM then WM.onQuestClick = function(questID) M:Open(questID, false) end end

    local ev = CreateFrame("Frame")
    ev:RegisterEvent("QUEST_LOG_UPDATE")
    ev:SetScript("OnEvent", function()
        if p:IsShown() and GetTime() - (U.refAt or 0) > 0.5 then
            U.refAt = GetTime()
            M:Refresh()
        end
    end)
end
