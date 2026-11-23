--[[----------------------------------------------------------------------------
    AzaathUI - Modules/MapChrome.lua
    A moldura do mapa-múndi, da arte de conceito tools/map-ui-concept/concept.webp:
      · barra superior: emblema Azaath (pulsando), caminho do lugar (Azeroth • continente • zona,
        clicável), busca de zona ou missão, botões de janela/tela cheia e fechar
      · borda com filete ciano e os cantos em arco
      · menu lateral (estandarte): Missões, Lugares, Coleta, Configurações e Centralizar em mim;
        os três do meio abrem os filtros e as opções do mapa
      · barra de status embaixo: lugar sob o cursor + coordenadas | Nomes | Terreno | Inexploradas
        (clicáveis), e a linha azul da borda de baixo
    Texturas: Media/MapFrame (tools/map-ui-concept/gen.js; tamanhos em Azaath.MapFrameTex).
    O mapa em si (Modules/WorldMap.lua) chama: SetBreadcrumb, SetHover, OnWindowMode.
------------------------------------------------------------------------------]]

local ADDON_NAME, Azaath = ...
local M = Azaath:NewModule("MapChrome")

local TEX = Azaath.media.path .. "MapFrame\\"
local floor, min, max, sin = math.floor, math.min, math.max, math.sin
local ipairs, pairs = ipairs, pairs

local CYAN = { 0.37, 0.89, 0.90 }
local CREAM = { 0.95, 0.92, 0.82 }
local GRAYT = { 0.62, 0.66, 0.68 }
local GOLD = { 0.85, 0.71, 0.42 }
local TOP_H = 46
local RAIL_W = 60

local api                 -- funções do mapa (WorldMap: M.api)
local U = {}              -- peças da moldura

local function Font(fs, size, bold)
    local m = Azaath.media or {}
    local file = bold and (m.fontCard or m.fontCardR) or (m.fontCardR or m.fontCard)
    if not (file and pcall(fs.SetFont, fs, file, size, "")) then fs:SetFontObject(GameFontHighlight) end
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
end

local function Upper(t) return Azaath.Upper and Azaath.Upper(t) or (t or ""):upper() end

-- textura em 9 partes (mx, my: margens em pixels de interface; my = altura/2 vira 3 partes)
local function Nine(parent, name, mx, my, layer, sub)
    local sz = Azaath.MapFrameTex and Azaath.MapFrameTex[name] or { 64, 64 }
    local u, v = mx / sz[1], my / sz[2]
    local cells = {
        { 0, u, 0, v }, { u, 1 - u, 0, v }, { 1 - u, 1, 0, v },
        { 0, u, v, 1 - v }, { u, 1 - u, v, 1 - v }, { 1 - u, 1, v, 1 - v },
        { 0, u, 1 - v, 1 }, { u, 1 - u, 1 - v, 1 }, { 1 - u, 1, 1 - v, 1 },
    }
    local t = {}
    for i, c in ipairs(cells) do
        local x = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
        x:SetTexture(TEX .. name)
        x:SetTexCoord(c[1], c[2], c[3], c[4])
        t[i] = x
    end
    t[1]:SetPoint("TOPLEFT"); t[1]:SetSize(mx, my)
    t[3]:SetPoint("TOPRIGHT"); t[3]:SetSize(mx, my)
    t[7]:SetPoint("BOTTOMLEFT"); t[7]:SetSize(mx, my)
    t[9]:SetPoint("BOTTOMRIGHT"); t[9]:SetSize(mx, my)
    t[2]:SetPoint("TOPLEFT", t[1], "TOPRIGHT"); t[2]:SetPoint("BOTTOMRIGHT", t[3], "BOTTOMLEFT")
    t[8]:SetPoint("TOPLEFT", t[7], "TOPRIGHT"); t[8]:SetPoint("BOTTOMRIGHT", t[9], "BOTTOMLEFT")
    t[4]:SetPoint("TOPLEFT", t[1], "BOTTOMLEFT"); t[4]:SetPoint("BOTTOMRIGHT", t[7], "TOPRIGHT")
    t[6]:SetPoint("TOPLEFT", t[3], "BOTTOMLEFT"); t[6]:SetPoint("BOTTOMRIGHT", t[9], "TOPRIGHT")
    t[5]:SetPoint("TOPLEFT", t[1], "BOTTOMRIGHT"); t[5]:SetPoint("BOTTOMRIGHT", t[9], "TOPLEFT")
    local obj = { tex = t }
    function obj:SetTexture(n) for _, x in ipairs(self.tex) do x:SetTexture(TEX .. n) end end
    function obj:SetVertexColor(r, g, b, a) for _, x in ipairs(self.tex) do x:SetVertexColor(r, g, b, a or 1) end end
    function obj:SetShown(on) for _, x in ipairs(self.tex) do x:SetShown(on) end end
    return obj
end
M.Nine = Nine
M.Font = Font

-- um pixel da tela em unidades de interface do quadro (linhas nítidas em qualquer escala)
local function Pixel(frame)
    local f = (PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()) or 1
    local s = frame:GetEffectiveScale() or 1
    return f / (s > 0 and s or 1)
end
M.Pixel = Pixel

-- caixa arredondada da arte: fundo de cantos redondos e UM filete com arcos lisos nos cantos.
-- As retas são linhas de exatamente 1 pixel da tela; os arcos têm a mesma espessura.
-- radius (em pixels da tela): 6 = cartões (CardFill/CardArc), 9 = janelas (PanelFill/PanelArc).
-- fill, edge: { r, g, b, a }
function M.RoundBox(parent, radius, fill, edge, layer)
    local p = Pixel(parent)
    local R = radius * p
    local big = radius >= 9
    local box = { edge = {} }
    box.fill = Nine(parent, big and "PanelFill" or "CardFill", R, R, layer or "BACKGROUND", -4)
    box.fill:SetVertexColor(fill[1], fill[2], fill[3], fill[4] or 1)
    local function Edge(a1, x1, y1, a2, x2, y2, w, h)
        local t = parent:CreateTexture(nil, "BORDER", nil, 1)
        t:SetColorTexture(1, 1, 1, 1)
        t:SetPoint(a1, x1, y1); t:SetPoint(a2, x2, y2)
        if w then t:SetWidth(w) else t:SetHeight(h) end
        box.edge[#box.edge + 1] = t
    end
    Edge("TOPLEFT", R, 0, "TOPRIGHT", -R, 0, nil, p)
    Edge("BOTTOMLEFT", R, 0, "BOTTOMRIGHT", -R, 0, nil, p)
    Edge("TOPLEFT", 0, -R, "BOTTOMLEFT", 0, R, p, nil)
    Edge("TOPRIGHT", 0, -R, "BOTTOMRIGHT", 0, R, p, nil)
    for _, c in ipairs({ { "TOPLEFT", 0, 1, 0, 1 }, { "TOPRIGHT", 1, 0, 0, 1 },
                         { "BOTTOMLEFT", 0, 1, 1, 0 }, { "BOTTOMRIGHT", 1, 0, 1, 0 } }) do
        local t = parent:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture(TEX .. (big and "PanelArc" or "CardArc"))
        t:SetTexCoord(c[2], c[3], c[4], c[5])
        t:SetSize(R, R)
        t:SetPoint(c[1])
        box.edge[#box.edge + 1] = t
    end
    function box:SetEdgeColor(r, g, b, a) for _, t in ipairs(self.edge) do t:SetVertexColor(r, g, b, a or 1) end end
    function box:SetEdgeAlpha(a) for _, t in ipairs(self.edge) do t:SetAlpha(a) end end
    box:SetEdgeColor(edge[1], edge[2], edge[3], edge[4] or 1)
    box.R, box.p = R, p
    return box
end

-- as janelas (missões, detalhes, menus, busca): ardósia translúcida e filete verde-acinzentado
local PANEL_FILL, PANEL_EDGE = { 0.055, 0.078, 0.092, 0.95 }, { 0.27, 0.40, 0.43, 1 }
function M.PanelBox(parent)
    local box = M.RoundBox(parent, 9, PANEL_FILL, PANEL_EDGE)
    -- luz fina no alto, por dentro
    local hi = parent:CreateTexture(nil, "BORDER", nil, 0)
    hi:SetColorTexture(1, 1, 1, 0.04)
    hi:SetPoint("TOPLEFT", box.R, -2 * box.p); hi:SetPoint("TOPRIGHT", -box.R, -2 * box.p); hi:SetHeight(box.p)
    return box
end

local function Tex(parent, name, w, h, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    t:SetTexture(TEX .. name)
    if w then t:SetSize(w, h or w) end
    return t
end
M.Tex = Tex

-- X no canto superior direito de um painel do estandarte: fecha pelo menu lateral (o ícone apaga junto)
function M.PanelClose(panel)
    local b = CreateFrame("Button", nil, panel)
    b:SetSize(24, 24)
    b:SetPoint("TOPRIGHT", -8, -8)
    b:SetFrameLevel(panel:GetFrameLevel() + 5)
    local i = Tex(b, "IcoClose", 14, 14)
    i:SetPoint("CENTER")
    b:SetScript("OnEnter", function() i:SetVertexColor(CYAN[1], CYAN[2], CYAN[3]) end)
    b:SetScript("OnLeave", function() i:SetVertexColor(1, 1, 1) end)
    b:SetScript("OnClick", function() M:SetActive(nil) end)
    return b
end

local function DB() return Azaath.db.worldmap end

-- faixa de nível de um mapa, nesta ordem:
--   1) a do jogo (C_Map.GetMapLevels; no Forever devolve 0);
--   2) a dos roteiros de leveling da nossa ferramenta (Azaath.TryhardRoutes, categoria Leveling): cada roteiro
--      conta para a zona onde ficam a maioria das etapas dele (o campo z de alguns roteiros aponta outra zona);
--   3) a das missões que começam na zona (QuestDB:ZoneLevelRange), para as zonas sem roteiro.
local routeLevels
local TRAVEL = { goto = true, fly = true, enter = true, hs = true, level = true }
function M.MapLevels(mapID)
    if C_Map and C_Map.GetMapLevels then
        local ok, lo, hi = pcall(C_Map.GetMapLevels, mapID)
        if ok and lo and hi and lo > 0 and hi > 0 then return lo, hi end
    end
    if not routeLevels then
        routeLevels = {}
        for _, g in ipairs(Azaath.TryhardRoutes or {}) do
            if (g.cat or "Leveling") == "Leveling" and (g.min or 0) > 0 then
                local count, best, bc = {}, g.z, -1
                for _, st in ipairs(g.steps or {}) do
                    if st.m and st.m > 0 and not TRAVEL[st.t] then count[st.m] = (count[st.m] or 0) + 1 end
                end
                for m, c in pairs(count) do if c > bc then best, bc = m, c end end
                if best and best > 0 then
                    local r = routeLevels[best]
                    if not r then r = { g.min, g.max or g.min }; routeLevels[best] = r end
                    r[1] = math.min(r[1], g.min)
                    r[2] = math.max(r[2], g.max or g.min)
                end
            end
        end
    end
    local r = routeLevels[mapID]
    if r then return r[1], r[2] end
    local Q = Azaath:GetModule("QuestDB")
    if Q and Q.ZoneLevelRange then
        local lo, hi = Q:ZoneLevelRange(mapID)
        if lo and hi then return lo, hi end
    end
end

---------------------------------------------------------------------------
-- Barra superior
---------------------------------------------------------------------------
local function BuildTopBar(f)
    local bar = CreateFrame("Frame", nil, f)
    bar:SetPoint("TOPLEFT"); bar:SetPoint("TOPRIGHT")
    bar:SetHeight(TOP_H)
    bar:SetFrameLevel(f:GetFrameLevel() + 40)
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function() api.StartMoving() end)
    bar:SetScript("OnDragStop", function() api.StopMoving() end)
    bar:SetScript("OnMouseUp", function(_, b)
        -- dois cliques na barra: janela <-> tela cheia
        local now = GetTime()
        if b == "LeftButton" and U.lastBarClick and now - U.lastBarClick < 0.35 then
            api.SetMaximized(not api.IsMaximized())
            U.lastBarClick = nil
        else
            U.lastBarClick = now
        end
    end)
    local bg = Tex(bar, "TopBar", nil, nil, "BACKGROUND")
    bg:SetAllPoints()
    U.bar = bar

    -- emblema Azaath, com um segundo brilho pulsando por cima
    local em = Tex(bar, "Emblem", 44, 44, "ARTWORK")
    em:SetPoint("TOPLEFT", 14, -1)
    local glow = Tex(bar, "Emblem", 44, 44, "ARTWORK", 2)
    glow:SetPoint("CENTER", em)
    glow:SetBlendMode("ADD")
    U.emGlow = glow

    -- caminho do lugar
    U.crumbs = {}
    U.crumbX = 66

    -- botões (tela cheia e fechar)
    local function Btn(icon, onClick, tip)
        local b = CreateFrame("Button", nil, bar)
        b:SetSize(32, 32)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        hl:SetColorTexture(CYAN[1], CYAN[2], CYAN[3], 0.12)
        b.icon = Tex(b, icon, 18, 18)
        b.icon:SetPoint("CENTER")
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            self.icon:SetVertexColor(CYAN[1] * 1.1, CYAN[2] * 1.1, CYAN[3] * 1.1)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(type(tip) == "function" and tip() or tip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self) self.icon:SetVertexColor(1, 1, 1); GameTooltip:Hide() end)
        return b
    end
    local close = Btn("IcoClose", function() api.Close() end, "Fechar")
    close:SetPoint("RIGHT", -10, 0)
    local maxb = Btn("IcoMax", function() api.SetMaximized(not api.IsMaximized()) end,
        function() return api.IsMaximized() and "Janela" or "Tela cheia" end)
    maxb:SetPoint("RIGHT", close, "LEFT", -6, 0)
    U.maxBtn = maxb

    -- busca de zona ou missão
    local sb = CreateFrame("EditBox", nil, bar)
    sb:SetSize(280, 30)
    sb:SetPoint("RIGHT", maxb, "LEFT", -40, 0)
    sb:SetAutoFocus(false)
    sb:SetTextInsets(32, 10, 0, 0)
    Font(sb, 14)
    sb:SetTextColor(CREAM[1], CREAM[2], CREAM[3])
    Nine(sb, "Search", 8, 8, "BACKGROUND")
    local ic = Tex(sb, "IcoSearch", 16, 16)
    ic:SetPoint("LEFT", 10, 0)
    local ph = sb:CreateFontString(nil, "ARTWORK")
    Font(ph, 14)
    ph:SetTextColor(0.55, 0.6, 0.62)
    ph:SetPoint("LEFT", 32, 0)
    ph:SetText("Buscar zona ou missão...")
    U.search, U.searchPH = sb, ph
    sb:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    sb:SetScript("OnEditFocusGained", function() ph:Hide() end)
    sb:SetScript("OnEditFocusLost", function(self) if self:GetText() == "" then ph:Show() end end)
    sb:SetScript("OnTextChanged", function(self) M:Search(self:GetText()) end)
    sb:SetScript("OnEnterPressed", function(self)
        local r = U.results and U.results.items and U.results.items[1]
        if r then r.go() end
        self:ClearFocus()
    end)

    -- lista de resultados
    local res = CreateFrame("Frame", nil, bar)
    res:SetPoint("TOPLEFT", sb, "BOTTOMLEFT", 0, -4)
    res:SetPoint("TOPRIGHT", sb, "BOTTOMRIGHT", 0, -4)
    res:SetFrameLevel(bar:GetFrameLevel() + 20)
    M.PanelBox(res)
    res:Hide()
    res.rows = {}
    U.results = res
end

function M:SetBreadcrumb(chain)
    if not U.bar then return end
    for _, c in ipairs(U.crumbs) do c:Hide(); if c.dot then c.dot:Hide() end end
    local x = U.crumbX
    for i, item in ipairs(chain or {}) do
        local b = U.crumbs[i]
        if not b then
            b = CreateFrame("Button", nil, U.bar)
            b.fs = b:CreateFontString(nil, "OVERLAY")
            Font(b.fs, 17)
            b.fs:SetPoint("LEFT")
            b.dot = Tex(U.bar, "Dot", 9, 9, "OVERLAY")
            b:SetScript("OnEnter", function(self) if not self.last then self.fs:SetTextColor(CYAN[1], CYAN[2], CYAN[3]) end end)
            b:SetScript("OnLeave", function(self)
                local c = self.last and CREAM or GRAYT
                self.fs:SetTextColor(c[1], c[2], c[3])
            end)
            U.crumbs[i] = b
        end
        local last = i == #chain
        b.last = last
        local text = Upper(item.name or "")
        -- faixa de nível do mapa atual: "VALE GRIS (22 - 25)"
        if last and item.mapID then
            local lo, hi = M.MapLevels(item.mapID)
            if lo then
                local range = lo == hi and tostring(lo) or (lo .. " - " .. hi)
                text = text .. "  |cffd9b46a(" .. range .. ")|r"
            end
        end
        b.fs:SetText(text)
        local c = last and CREAM or GRAYT
        b.fs:SetTextColor(c[1], c[2], c[3])
        b:SetSize(b.fs:GetStringWidth() + 2, 24)
        b:ClearAllPoints()
        b:SetPoint("LEFT", U.bar, "LEFT", x, 0)
        b:SetScript("OnClick", function() if not last then api.ShowMap(item.mapID) end end)
        b:Show()
        x = x + b.fs:GetStringWidth() + 6
        if not last then
            b.dot:ClearAllPoints()
            b.dot:SetPoint("LEFT", U.bar, "LEFT", x + 4, 0)
            b.dot:Show()
            x = x + 22
        end
    end
end

-- busca: zonas e continentes (pelo nome do jogo) e as missões do diário
function M:Search(text)
    local res = U.results
    for _, r in ipairs(res.rows) do r:Hide() end
    res.items = {}
    text = (text or ""):lower()
    if #text < 2 then res:Hide() return end
    local items = res.items
    local function Add(label, sub, go)
        if #items < 8 then items[#items + 1] = { label = label, sub = sub, go = go } end
    end
    for _, c in ipairs(api.Conts()) do
        if c.name and c.name:lower():find(text, 1, true) then
            Add(c.name, "Continente", function() api.FitPlace(c) end)
        end
    end
    for _, z in ipairs(api.Zones()) do
        if z.name and z.name:lower():find(text, 1, true) then
            Add(z.name, z.cont and z.cont.name or "Zona", function() api.FitPlace(z) end)
        end
    end
    local Q = Azaath:GetModule("MapQuests")
    if Q and Q.List then
        for _, q in ipairs(Q:List()) do
            if q.title and q.title:lower():find(text, 1, true) then
                Add(q.title, "Missão", function() Q:Open(q.questID, true) end)
            end
        end
    end
    if #items == 0 then res:Hide() return end
    for i, it in ipairs(items) do
        local r = res.rows[i]
        if not r then
            r = CreateFrame("Button", nil, res)
            r:SetHeight(26)
            r.fs = r:CreateFontString(nil, "OVERLAY"); Font(r.fs, 14); r.fs:SetPoint("LEFT", 12, 0)
            r.sub = r:CreateFontString(nil, "OVERLAY"); Font(r.sub, 12); r.sub:SetPoint("RIGHT", -12, 0)
            r.sub:SetTextColor(0.5, 0.75, 0.76)
            local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(CYAN[1], CYAN[2], CYAN[3], 0.12)
            res.rows[i] = r
        end
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", 4, -6 - (i - 1) * 26)
        r:SetPoint("TOPRIGHT", -4, -6 - (i - 1) * 26)
        r.fs:SetText(it.label)
        r.fs:SetTextColor(CREAM[1], CREAM[2], CREAM[3])
        r.sub:SetText(it.sub or "")
        r:SetScript("OnClick", function()
            it.go()
            U.search:SetText("")
            U.search:ClearFocus()
            res:Hide()
        end)
        r:Show()
    end
    res:SetHeight(12 + #items * 26)
    res:Show()
end

---------------------------------------------------------------------------
-- Borda, linha de baixo e barra de status
---------------------------------------------------------------------------
local FRAME_IN = 13          -- a moldura fica recuada da beira da janela (a arte: 19 px com a borda)
local function BuildBorder(f, v)
    local top = CreateFrame("Frame", nil, f)
    top:SetPoint("TOPLEFT", v, "TOPLEFT", FRAME_IN, 0)
    top:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", -FRAME_IN, FRAME_IN)
    top:SetFrameLevel(f:GetFrameLevel() + 28)
    local border = Nine(top, "Frame", 56, 56, "OVERLAY")
    U.border = border
    -- o compasso do canto superior direito
    local comp = Tex(top, "Compass", 190, 150, "OVERLAY", 1)
    comp:SetPoint("TOPRIGHT", v, "TOPRIGHT", 0, 0)
    -- a linha azul de baixo (a mesma da arte, sem o botão de fechar): o brilho por cima do filete
    local line = Tex(top, "BottomLine", nil, nil, "OVERLAY", 2)
    line:SetPoint("BOTTOMLEFT", top, "BOTTOMLEFT", 44, -3.5)
    line:SetPoint("BOTTOMRIGHT", top, "BOTTOMRIGHT", -44, -3.5)
    line:SetHeight(12)
    line:SetBlendMode("ADD")
    U.bottomLine = line
end

local PILL_H = 36
local function BuildStatus(f, v)
    local p = CreateFrame("Frame", nil, f)
    p:SetHeight(PILL_H)
    p:SetPoint("BOTTOM", v, "BOTTOM", 0, 22)
    p:SetFrameLevel(f:GetFrameLevel() + 36)
    p:EnableMouse(true)
    Nine(p, "Pill", 18, 18, "BACKGROUND")
    U.pill = p

    local parts = {}
    local function Text(size, color)
        local fs = p:CreateFontString(nil, "OVERLAY")
        Font(fs, size or 14)
        fs:SetTextColor(color[1], color[2], color[3])
        return fs
    end
    local function Sep()
        local fs = Text(14, { 0.45, 0.5, 0.52 })
        fs:SetText("|")
        return fs
    end
    local function Toggle(label, get, set)
        local b = CreateFrame("Button", nil, p)
        b:SetHeight(PILL_H - 8)
        b.fs = b:CreateFontString(nil, "OVERLAY"); Font(b.fs, 14); b.fs:SetPoint("LEFT")
        b.fs:SetText(label)
        b.check = Tex(b, "Check", 15, 15, "OVERLAY")
        b.check:SetPoint("LEFT", b.fs, "RIGHT", 4, 0)
        b.get, b.set = get, set
        b:SetScript("OnClick", function(self) self.set(not self.get()); M:UpdateStatus() end)
        b:SetScript("OnEnter", function(self) self.fs:SetTextColor(CYAN[1], CYAN[2], CYAN[3]) end)
        b:SetScript("OnLeave", function(self) M:UpdateStatus() end)
        return b
    end
    parts.place = Text(14, { 0.86, 0.86, 0.84 })
    parts.dot = Tex(p, "Dot", 8, 8, "OVERLAY")
    parts.coords = Text(14, { 0.86, 0.86, 0.84 })
    parts.s1 = Sep()
    parts.names = Toggle("Nomes", function() return DB().showNames ~= false end,
        function(on) DB().showNames = on; api.Labels() end)
    parts.s2 = Sep()
    parts.terrain = Toggle("Terreno", function() return DB().terrain and true or false end,
        function(on) DB().terrain = on; api.ShowMap(api.PlayerMap() or api.WORLD) end)
    parts.s3 = Sep()
    -- inexploradas: escuras -> ocultas -> coloridas
    local ub = CreateFrame("Button", nil, p)
    ub:SetHeight(PILL_H - 8)
    ub.fs = ub:CreateFontString(nil, "OVERLAY"); Font(ub.fs, 14); ub.fs:SetPoint("LEFT")
    ub:SetScript("OnClick", function()
        local db = DB()
        if db.revealAll then db.showUnexplored, db.revealAll = true, false
        elseif db.showUnexplored then db.showUnexplored, db.revealAll = false, false
        else db.showUnexplored, db.revealAll = true, true end
        api.Redraw()
        M:UpdateStatus()
    end)
    parts.unexplored = ub
    U.parts = parts
end

local function UnexploredState()
    local db = DB()
    if db.revealAll then return "Coloridas" end
    return db.showUnexplored and "Escuras" or "Ocultas"
end

-- reposiciona as peças da barra de status (a largura acompanha o texto)
function M:UpdateStatus()
    local P = U.parts
    if not P then return end
    local x = 24
    local function Put(region, w, gap)
        region:ClearAllPoints()
        region:SetPoint("LEFT", U.pill, "LEFT", x, 0)
        x = x + w + (gap or 10)
    end
    P.place:SetText(U.hoverText or "")
    Put(P.place, P.place:GetStringWidth(), 8)
    if U.hoverCoords then
        P.dot:Show(); P.coords:Show()
        Put(P.dot, 8, 8)
        P.coords:SetText(U.hoverCoords)
        Put(P.coords, P.coords:GetStringWidth(), 12)
    else
        P.dot:Hide(); P.coords:Hide()
    end
    Put(P.s1, P.s1:GetStringWidth(), 12)
    for _, key in ipairs({ "names", "terrain" }) do
        local b = P[key]
        local on = b.get()
        b.check:SetShown(on)
        local c = on and { 0.86, 0.86, 0.84 } or { 0.5, 0.54, 0.56 }
        if not b:IsMouseOver() then b.fs:SetTextColor(c[1], c[2], c[3]) end
        local w = b.fs:GetStringWidth() + (on and 21 or 0)
        b:SetWidth(w)
        Put(b, w, 12)
        local sep = key == "names" and P.s2 or P.s3
        Put(sep, sep:GetStringWidth(), 12)
    end
    P.unexplored.fs:SetText("Inexploradas: |cffd9b46a" .. UnexploredState() .. "|r")
    P.unexplored.fs:SetTextColor(0.86, 0.86, 0.84)
    local w = P.unexplored.fs:GetStringWidth()
    P.unexplored:SetWidth(w)
    Put(P.unexplored, w, 0)
    U.pill:SetWidth(x + 24)
end

function M:SetHover(text, cx, cy)
    local coords = cx and cy and string.format("%.1f, %.1f", cx, cy) or nil
    if text == U.hoverText and coords == U.hoverCoords then return end
    U.hoverText, U.hoverCoords = text, coords
    self:UpdateStatus()
end

---------------------------------------------------------------------------
-- Menu lateral (estandarte) e os menus de filtros/configuração
---------------------------------------------------------------------------
local function CheckRow(panel, i)
    local r = panel.rows[i]
    if not r then
        r = CreateFrame("Button", nil, panel)
        r:SetHeight(22)
        r.box = Tex(r, "Box", 16, 16)
        r.box:SetPoint("LEFT", 0, 0)
        r.mark = Tex(r, "CheckCyan", 16, 16, "OVERLAY")
        r.mark:SetPoint("CENTER", r.box)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(15, 15)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.fs = r:CreateFontString(nil, "OVERLAY"); Font(r.fs, 14)
        local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(CYAN[1], CYAN[2], CYAN[3], 0.08)
        panel.rows[i] = r
    end
    r:Show()
    return r
end

-- items: { label, get, set, icon?, gap?, cycle? (get devolve o texto) }
local function FillMenu(panel, title, items)
    for _, r in ipairs(panel.rows) do r:Hide() end
    panel.title:SetText(Upper(title))
    local n, line, col = 0, 0, 0
    local perCol = 16
    for _, it in ipairs(items) do
        if it.gap then
            line = line + 0.45
        else
            if line >= perCol then col, line = col + 1, 0 end
            n = n + 1
            local r = CheckRow(panel, n)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + col * 210, -48 - line * 24)
            r:SetWidth(196)
            r.fs:ClearAllPoints()
            if it.cycle then
                r.box:Hide(); r.mark:Hide(); r.icon:Hide()
                r.fs:SetPoint("LEFT", 0, 0)
                r.fs:SetText(it.label .. ": |cffd9b46a" .. it.get() .. "|r")
            else
                r.box:Show()
                r.mark:SetShown(it.get() and true or false)
                if it.icon then
                    r.icon:SetTexture(it.icon); r.icon:Show()
                    r.icon:ClearAllPoints(); r.icon:SetPoint("LEFT", r.box, "RIGHT", 6, 0)
                    r.fs:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
                else
                    r.icon:Hide()
                    r.fs:SetPoint("LEFT", r.box, "RIGHT", 8, 0)
                end
                r.fs:SetText(it.label)
            end
            r.fs:SetTextColor(0.86, 0.86, 0.84)
            r:SetScript("OnClick", function()
                if it.cycle then it.set() else it.set(not it.get()) end
                FillMenu(panel, title, items)
                api.Redraw()
                M:UpdateStatus()
            end)
            line = line + 1
        end
    end
    local cols = col + 1
    panel:SetSize(32 + cols * 210 - 14, 62 + (cols > 1 and perCol or line) * 24)
end

local function MenuItems(which)
    local db = DB()
    if which == "places" then
        return {
            { label = "Mestres de voo", get = function() return db.poiTaxi ~= false end, set = function(on) db.poiTaxi = on end },
            { label = "Masmorras e raides", get = function() return db.poiDungeons ~= false end, set = function(on) db.poiDungeons = on end },
            { label = "Missões", get = function() return db.poiQuests ~= false end, set = function(on) db.poiQuests = on end },
            { label = "Áreas das missões", get = function() return db.questAreas ~= false end, set = function(on) db.questAreas = on end },
            { label = "Grupo", get = function() return db.poiGroup ~= false end, set = function(on) db.poiGroup = on end },
        }, "Lugares no mapa"
    elseif which == "gather" then
        local G = Azaath:GetModule("MapGather")
        local items = {
            { label = "Ervas", get = function() return db.gatherHerb ~= false end, set = function(on) db.gatherHerb = on end },
            { label = "Minérios", get = function() return db.gatherOre ~= false end, set = function(on) db.gatherOre = on end },
            { label = "Só o que sei colher", get = function() return db.gatherOnlyKnown and true end, set = function(on) db.gatherOnlyKnown = on end },
            { label = "Usar dados do GatherLite", get = function() return db.gatherLite ~= false end,
              set = function(on) db.gatherLite = on; if G then G:Invalidate() end end },
            { gap = true },
        }
        if G then
            for _, t in ipairs(G:Types()) do
                items[#items + 1] = { label = t.name, icon = t.icon,
                    get = function() return not db.gatherHide[t.name] end,
                    set = function(on) db.gatherHide[t.name] = (not on) or nil end }
            end
        end
        return items, "Coleta"
    else
        return {
            { label = "Nomes", get = function() return db.showNames ~= false end, set = function(on) db.showNames = on; api.Labels() end },
            { label = "Visão de terreno", get = function() return db.terrain and true or false end,
              set = function(on) db.terrain = on; api.ShowMap(api.PlayerMap() or api.WORLD) end },
            { label = "Inexploradas", cycle = true, get = UnexploredState, set = function()
                if db.revealAll then db.showUnexplored, db.revealAll = true, false
                elseif db.showUnexplored then db.showUnexplored, db.revealAll = false, false
                else db.showUnexplored, db.revealAll = true, true end
            end },
            -- interiores: automático = subterrâneos (cidades, cavernas, minas) + a construção onde você está
            { label = "Interiores", cycle = true,
              get = function()
                  local m = db.interiors or "auto"
                  return m == "all" and "Todos" or m == "off" and "Nenhum" or "Automático"
              end,
              set = function()
                  local m = db.interiors or "auto"
                  db.interiors = m == "auto" and "all" or m == "all" and "off" or "auto"
                  if api.Redraw then api.Redraw() end
              end },
        }, "Configurações do mapa"
    end
end

-- qual item do menu está ativo: "quests", "places", "gather", "settings" ou nil
function M:SetActive(key)
    U.active = key
    for k, b in pairs(U.railItems) do
        local on = k == key
        b.glow:SetShown(on)
        local c = on and CYAN or GRAYT
        b.icon:SetVertexColor(c[1], c[2], c[3])
    end
    local Q = Azaath:GetModule("MapQuests")
    if Q and Q.SetShown then Q:SetShown(key == "quests") end
    local LM = Azaath:GetModule("MapLoremaster")
    if LM and LM.SetShown then LM:SetShown(key == "loremaster") end
    if key == "places" or key == "gather" or key == "settings" then
        local items, title = MenuItems(key)
        U.menu.key = key
        FillMenu(U.menu, title, items)
        U.menu:Show()
    else
        U.menu:Hide()
    end
end

local function BuildRail(f, v)
    local rail = CreateFrame("Frame", nil, f)
    rail:SetPoint("TOPLEFT", v, "TOPLEFT", 0, 0)
    rail:SetWidth(RAIL_W)
    rail:SetFrameLevel(f:GetFrameLevel() + 30)
    rail:EnableMouse(true)
    local top = Tex(rail, "RailTop", RAIL_W, 96, "BACKGROUND")
    top:SetPoint("TOPLEFT")
    local bot = Tex(rail, "RailBot", RAIL_W, 60, "BACKGROUND")
    bot:SetPoint("BOTTOMLEFT")
    local mid = Tex(rail, "RailMid", nil, nil, "BACKGROUND")
    mid:SetPoint("TOPLEFT", top, "BOTTOMLEFT")
    mid:SetPoint("BOTTOMRIGHT", bot, "TOPRIGHT")
    U.rail = rail

    U.railItems = {}
    local function Item(key, icon, tip, y, onClick, anchorBottom, size)
        local b = CreateFrame("Button", nil, rail)
        b:SetSize(RAIL_W, 56)
        if anchorBottom then b:SetPoint("BOTTOMLEFT", 0, y) else b:SetPoint("TOPLEFT", 0, y) end
        b.glow = Tex(b, "RailActive", RAIL_W, 56, "BORDER")
        b.glow:SetPoint("LEFT")
        b.glow:SetBlendMode("ADD")
        b.glow:Hide()
        b.icon = Tex(b, icon, size or 34, size or 34)
        b.icon:SetPoint("CENTER", 0, 0)
        b.icon:SetVertexColor(GRAYT[1], GRAYT[2], GRAYT[3])
        b:SetScript("OnEnter", function(self)
            if U.active ~= key then self.icon:SetVertexColor(0.85, 0.9, 0.92) end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(tip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            local c = U.active == key and CYAN or GRAYT
            self.icon:SetVertexColor(c[1], c[2], c[3])
            GameTooltip:Hide()
        end)
        b:SetScript("OnClick", onClick)
        if key then U.railItems[key] = b end
        return b
    end
    local function Toggle(key) M:SetActive(U.active == key and nil or key) end
    -- (posições da arte: os ícones a 58 px um do outro, a seta de rota perto da ponta)
    Item("quests", "RIcoQuests", "Missões ativas", -87, function() Toggle("quests") end, nil, 36)
    Item("places", "RIcoPlaces", "Lugares no mapa", -141, function() Toggle("places") end)
    Item("gather", "RIcoGather", "Coleta: ervas e minérios", -199, function() Toggle("gather") end)
    Item("settings", "RIcoSettings", "Configurações do mapa", -258, function() Toggle("settings") end)
    Item("loremaster", "RIcoQuests", "Loremaster da zona (todas as missões)", -316, function() Toggle("loremaster") end, nil, 32)
    local center = Item(nil, "RIcoCenter", "Centralizar em mim", 46, function() api.FocusPlayer() end, true)
    center.icon:SetVertexColor(GRAYT[1], GRAYT[2], GRAYT[3])

    -- o menu de filtros/configuração (ao lado do estandarte)
    local menu = CreateFrame("Frame", nil, f)
    menu:SetPoint("TOPLEFT", v, "TOPLEFT", RAIL_W + 18, -24)
    menu:SetFrameLevel(f:GetFrameLevel() + 32)
    menu:EnableMouse(true)
    M.PanelBox(menu)
    local gem = Tex(menu, "PanelGem", 20, 12, "OVERLAY")
    gem:SetPoint("CENTER", menu, "TOP", 0, 0)
    menu.title = menu:CreateFontString(nil, "OVERLAY"); Font(menu.title, 16)
    menu.title:SetPoint("TOPLEFT", 16, -14)
    menu.title:SetTextColor(0.88, 0.9, 0.9)
    local rule = Tex(menu, "Rule", nil, 10, "OVERLAY")
    rule:SetPoint("TOPLEFT", 10, -36); rule:SetPoint("TOPRIGHT", -10, -36)
    rule:SetBlendMode("ADD")
    menu.rows = {}
    M.PanelClose(menu)       -- Lugares, Coleta e Configurações
    menu:Hide()
    U.menu = menu
end

-- altura do estandarte: acompanha a janela (a ponta fica bem acima da barra de status)
local function LayoutRail(v)
    local h = v:GetHeight()
    if not h or h < 100 then return end
    U.rail:SetHeight(max(380, min(560, h - 120)))
end

---------------------------------------------------------------------------
-- Efeitos Azaath: o emblema, o item ativo e a linha de baixo respiram em ciano
---------------------------------------------------------------------------
local function Effects()
    local t = GetTime()
    local p = 0.5 + 0.5 * sin(t * 2.2)
    if U.emGlow then U.emGlow:SetAlpha(0.15 + 0.45 * p) end
    if U.active and U.railItems[U.active] then U.railItems[U.active].glow:SetAlpha(0.7 + 0.3 * p) end
    if U.bottomLine then U.bottomLine:SetAlpha(0.75 + 0.25 * p) end
end

---------------------------------------------------------------------------
function M:Build(f, v, mapApi)
    api = mapApi
    BuildBorder(f, v)
    BuildTopBar(f)
    BuildRail(f, v)
    BuildStatus(f, v)
    v:HookScript("OnSizeChanged", function() LayoutRail(v) end)
    LayoutRail(v)
    U.fx = CreateFrame("Frame", nil, f)
    U.fx:SetScript("OnUpdate", Effects)
    f:HookScript("OnShow", function()
        M:UpdateStatus()
        M:SetActive(nil)
    end)
    self:UpdateStatus()
end

function M:OnWindowMode(maxed)
    if U.maxBtn then U.maxBtn.icon:SetTexture(TEX .. (maxed and "IcoRestore" or "IcoMax")) end
end
