--[[----------------------------------------------------------------------------
    AzaathUI - Modules/QuestTracker.lua
    Rastreador de missões na linguagem visual de Azaath (3.3.5a).

      * Cada missão: losango numerado (cor pelo tipo) + título colorido +
        objetivos no formato "2 / 5 - Descrição", com caixinha ou ✓.
          dourado = normal · verde = diária · laranja = elite/grupo/masmorra ·
          roxo = conquista · vermelho = falhou
      * Destaque dourado ao passar o mouse e por alguns segundos quando um
        objetivo avança.
      * Clique: abre a missão no registro (ou a conquista) · clique direito:
        para de acompanhar.
      * Conquistas acompanhadas aparecem depois das missões (opcional).
      * Substitui o WatchFrame da Blizzard; também reproduz o auto-acompanhar
        ao aceitar/progredir missões (CVars autoQuestWatch/autoQuestProgress),
        que era feito pelo WatchFrame.

    Botões de item de missão (seguros):
      * São SecureActionButtons com macro "/use item:ID" (o uso de item é ação
        protegida). Atributos, posição e Show/Hide só podem mudar FORA de
        combate: se a lista mudar em combate, o texto atualiza na hora e os
        itens se realinham ao sair do combate (fila do Core).
      * Ancorados ao root (que nunca se move), e não aos blocos de texto:
        ancorar um frame protegido em um frame comum restringiria a
        movimentação desse frame comum em combate.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("QuestTracker")

local _G = _G
local ipairs, format, max = ipairs, string.format, math.max
local GetTime = GetTime

local THROTTLE      = 0.2  -- reconstrução no máximo 5x por segundo
local FLASH_TIME    = 4    -- destaque após progresso
local PAD_X         = 8    -- recuo interno do painel moderno
local INDENT        = 24   -- recuo do título (espaço do losango)
local BOX_INDENT    = 14   -- recuo do texto do objetivo (espaço da caixinha)
local LINE_GAP      = 2
local BLOCK_GAP     = 6
local HEADER_H      = 22
local MAX_CRITERIA  = 5
local CHECK_TEXTURE = "Interface\\Buttons\\UI-CheckBox-Check"

local TYPE_COLORS = {
    normal      = { 1.00, 0.82, 0.36 },
    daily       = { 0.38, 0.92, 0.58 },
    group       = { 1.00, 0.58, 0.28 },
    achievement = { 0.78, 0.62, 1.00 },
    failed      = { 1.00, 0.30, 0.25 },
}
local READY_COLOR = { 0.38, 0.92, 0.58 }

local tracker, header, headerCount, headerArrow, listBg, content, moreText
local blocks = {}
local signatures, flashUntil = {}, {}
local dirty = true

--------------------------------------------------------------------------------
-- Coleta de dados
--------------------------------------------------------------------------------
-- "Elites derrotados: 2/5" -> "2 / 5 - Elites derrotados" (formato do Azaath)
local function FormatObjective(text)
    local desc, have, need = text:match("^(.-):%s*(%d+)%s*/%s*(%d+)%s*$")
    if desc then
        return format("|cffffffff%s / %s|r - %s", have, need, desc)
    end
    return text
end

local function CollectQuests(list)
    local API = Azaath.API
    for _, index in ipairs(API.WatchedQuestIndexes()) do
        do
            -- Compat padroniza as assinaturas do registro (3.3.5 e moderno)
            local title, level, tag, group, isHeader, isComplete, isDaily, questID = API.QuestInfo8(index)
            if title and not isHeader then
                local e = {
                    kind = "quest", index = index, questID = questID, key = "q" .. (questID or title),
                    title = title, level = level, tag = tag, objectives = {},
                }
                if isComplete == -1 then
                    e.color = TYPE_COLORS.failed
                    e.objectives[1] = { text = "Falhou", failed = true }
                elseif isDaily then
                    e.color = TYPE_COLORS.daily
                elseif (tag and tag ~= "") or (group and group > 0) then
                    e.color = TYPE_COLORS.group
                    local grpN = type(group) == "number" and group or (type(tag) == "number" and tag or 0)
                    local typeStr = grpN >= 10 and "Raide" or grpN >= 5 and "Masmorra" or (grpN > 1 and ("Grupo · " .. grpN .. " jog.") or "Elite")
                    if type(tag) == "string" and tag ~= "" then typeStr = tag end
                    e.groupType = typeStr
                else
                    e.color = TYPE_COLORS.normal
                end

                if e.groupType then
                    e.objectives[1] = { text = e.groupType, groupLabel = true }
                end
                if isComplete == 1 then
                    e.ready = true
                    e.objectives[#e.objectives + 1] = { text = "Pronta para entregar", ready = true }
                elseif isComplete ~= -1 then
                    for _, o in ipairs(API.QuestObjectives(index, questID)) do
                        e.objectives[#e.objectives + 1] = { text = FormatObjective(o.text), done = o.finished }
                    end
                end

                local sig = tostring(isComplete)
                for _, o in ipairs(e.objectives) do sig = sig .. "|" .. o.text end
                e.signature = sig
                list[#list + 1] = e
            end
        end
    end
end

local function CollectAchievements(list)
    if not (M.db.showAchievements and GetTrackedAchievements) then return end
    local ids = { GetTrackedAchievements() }
    for _, id in ipairs(ids) do
        local _, name, _, completed, _, _, _, description = GetAchievementInfo(id)
        if name and not completed then
            local e = {
                kind = "achievement", achievementID = id, key = "a" .. id,
                title = name, color = TYPE_COLORS.achievement, objectives = {},
            }
            local num = GetAchievementNumCriteria(id)
            if num == 0 then
                e.objectives[1] = { text = description or "" }
            else
                for j = 1, num do
                    local desc, _, done, _, _, _, flags, _, quantityString = GetAchievementCriteriaInfo(id, j)
                    if not done then
                        local text = desc or ""
                        -- critérios de "barra de progresso" (flag 1) mostram a quantidade
                        if flags and bit.band(flags, 1) == 1 and quantityString then
                            text = (text ~= "") and format("|cffffffff%s|r - %s", quantityString, text) or quantityString
                        end
                        e.objectives[#e.objectives + 1] = { text = text }
                        if #e.objectives >= MAX_CRITERIA then break end
                    end
                end
            end
            local sig = ""
            for _, o in ipairs(e.objectives) do sig = sig .. "|" .. o.text end
            e.signature = sig
            list[#list + 1] = e
        end
    end
end

--------------------------------------------------------------------------------
-- Interação com os blocos
--------------------------------------------------------------------------------
local function OpenQuest(index, questID)
    local wm = Azaath:GetModule("WorldMap")
    local mq = Azaath:GetModule("MapQuests")
    if wm and wm.Open and mq and mq.Open and questID and Azaath.db.worldmap and Azaath.db.worldmap.enabled then
        wm:Open()
        mq:Open(questID, true)
        return
    end
    Azaath.API.OpenQuest(index) -- Fallback se o mapa próprio estiver desligado
end

local function OpenAchievement(id)
    if not AchievementFrame and AchievementFrame_LoadUI then AchievementFrame_LoadUI() end
    if AchievementFrame and AchievementFrame_SelectAchievement then
        Azaath.ShowPanel(AchievementFrame)
        AchievementFrame_SelectAchievement(id)
    end
end

local function SetHighlight(b, on)
    if on then
        local col = (b.entry and b.entry.objectives and b.entry.objectives[1] and b.entry.objectives[1].failed)
            and TYPE_COLORS.failed or { 0.37, 0.89, 0.90 }
        if M.db and M.db.transparentBg then
            b.hlBg:Hide()
        else
            b.hlBg:Show()
        end
        b.hlBar:SetColorTexture(col[1], col[2], col[3], 0.95)
        b.hlBar:Show()
    else
        b.hlBg:Hide()
        b.hlBar:Hide()
    end
end

local function Block_OnClick(self, button)
    local e = self.entry
    if not e then return end
    if e.kind == "quest" then
        if button == "RightButton" then
            Azaath.API.RemoveQuestWatch(e.index, e.questID)
            dirty = true
        elseif IsShiftKeyDown and IsShiftKeyDown() then
            OpenQuest(e.index, e.questID)
        else
            local qn = Azaath:GetModule("QuestNav")
            if qn and qn.SetFocusedQuest and e.questID then
                if qn:GetFocusedQuest() == e.questID then
                    OpenQuest(e.index, e.questID)
                else
                    qn:SetFocusedQuest(e.questID)
                end
            else
                OpenQuest(e.index, e.questID)
            end
        end
    else
        if button == "RightButton" then
            if RemoveTrackedAchievement then RemoveTrackedAchievement(e.achievementID) end
            dirty = true
        else
            OpenAchievement(e.achievementID)
        end
    end
end

local function Block_OnEnter(self)
    self.hover = true
    SetHighlight(self, true)
    local e = self.entry
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine(e.title, e.color[1], e.color[2], e.color[3])
    if e.kind == "quest" then
        local extra = (e.tag and e.tag ~= "") and (" · " .. e.tag) or ""
        GameTooltip:AddLine(format("Nível %d%s", e.level or 0, extra), 1, 1, 1)
        GameTooltip:AddLine("Clique: focar no marcador 3D (ou abrir se já focada)", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Shift + Clique: abrir no registro de missões", 0.8, 0.8, 0.8)
    else
        GameTooltip:AddLine("Clique: abrir a conquista", 0.8, 0.8, 0.8)
    end
    GameTooltip:AddLine("Clique direito: parar de acompanhar", 0.8, 0.8, 0.8)
    GameTooltip:Show()
end

local function IsFocusedEntry(e)
    if not (e and e.kind == "quest" and e.questID) then return false end
    local qn = Azaath:GetModule("QuestNav")
    return qn and qn.GetFocusedQuest and qn:GetFocusedQuest() == e.questID
end

local function Block_OnLeave(self)
    self.hover = false
    local until_ = self.entry and flashUntil[self.entry.key]
    SetHighlight(self, IsFocusedEntry(self.entry) or (until_ and GetTime() < until_))
    GameTooltip:Hide()
end

--------------------------------------------------------------------------------
-- Construção dos blocos (pool)
--------------------------------------------------------------------------------

local function CreateText(parent, size, font)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or Azaath.media.font, size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.95)
    fs:SetJustifyH("LEFT")
    fs:SetJustifyV("TOP")
    return fs
end

local function GetBlock(i)
    if blocks[i] then return blocks[i] end
    local media = Azaath.media
    local b = CreateFrame("Button", nil, content)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnClick", Block_OnClick)
    b:SetScript("OnEnter", Block_OnEnter)
    b:SetScript("OnLeave", Block_OnLeave)

    -- destaque exatamente igual ao passo #1 do card superior (só aparece em foco/hover/progresso)
    b.hlBg = b:CreateTexture(nil, "BACKGROUND")
    b.hlBg:SetColorTexture(0.06, 0.10, 0.13, 0.85)
    b.hlBg:SetPoint("TOPLEFT", b, "TOPLEFT", -PAD_X, 4)
    b.hlBg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", PAD_X, -4)

    b.hlBar = b:CreateTexture(nil, "ARTWORK")
    b.hlBar:SetWidth(3)
    b.hlBar:SetColorTexture(0.37, 0.89, 0.90, 0.95)
    b.hlBar:SetPoint("TOPLEFT", b.hlBg, "TOPLEFT", 0, 0)
    b.hlBar:SetPoint("BOTTOMLEFT", b.hlBg, "BOTTOMLEFT", 0, 0)
    SetHighlight(b, false)

    b.diamondOuter = b:CreateTexture(nil, "ARTWORK")
    b.diamondOuter:SetTexture(media.path .. "Diamond")
    b.diamondOuter:SetWidth(18)
    b.diamondOuter:SetHeight(18)
    b.diamondOuter:SetPoint("TOPLEFT", b, "TOPLEFT", 1, 1)

    b.diamondInner = b:CreateTexture(nil, "OVERLAY")
    b.diamondInner:SetTexture(media.path .. "Diamond")
    b.diamondInner:SetVertexColor(0.04, 0.06, 0.08)
    b.diamondInner:SetWidth(14)
    b.diamondInner:SetHeight(14)
    b.diamondInner:SetPoint("CENTER", b.diamondOuter, "CENTER", 0, 0)

    b.number = CreateText(b, 9, media.fontTitleB)
    b.number:SetJustifyH("CENTER")
    b.number:SetPoint("CENTER", b.diamondOuter, "CENTER", 0, 0)

    -- pronta para entregar: o mesmo alfinete verde do mapa (PinDoneN3) no lugar do losango
    b.pinDone = b:CreateTexture(nil, "ARTWORK")
    b.pinDone:SetTexture(media.path .. "MapFrame\\PinDoneN3")
    b.pinDone:SetSize(11, 23)
    b.pinDone:SetPoint("CENTER", b.diamondOuter, "CENTER", 0, -2)
    b.pinDone:Hide()

    b.title = CreateText(b, 12, media.fontTitle)
    b.title:SetPoint("TOPLEFT", b, "TOPLEFT", INDENT + 2, 0)

    b.navBadge = CreateText(b, 10, media.font)
    b.navBadge:SetJustifyH("RIGHT")
    b.navBadge:SetPoint("TOPRIGHT", b, "TOPRIGHT", 0, -2)
    b.navBadge:SetTextColor(0.88, 0.92, 0.94, 0.90)
    b.navBadge:Hide()

    b.lines = {}
    blocks[i] = b
    return b
end

local function GetLine(b, j)
    local line = b.lines[j]
    if line then return line end
    line = {}
    line.text = CreateText(b, 13)

    -- ponto discreto moderno (objetivo pendente, sem caixinha quadrada)
    local box = b:CreateTexture(nil, "OVERLAY")
    box:SetTexture(Azaath.media.path .. "MapFrame\\Dot.tga")
    box:SetWidth(7)
    box:SetHeight(7)
    box:SetVertexColor(0.37, 0.89, 0.90, 0.75)
    line.box = box

    -- ✓ (objetivo concluído / pronta para entregar)
    line.check = b:CreateTexture(nil, "OVERLAY")
    line.check:SetTexture(CHECK_TEXTURE)
    line.check:SetWidth(16)
    line.check:SetHeight(16)

    b.lines[j] = line
    return line
end

local function RenderBlock(b, e, number, width)
    local col = e.color
    b.diamondOuter:SetVertexColor(col[1], col[2], col[3])
    local ready = e.kind == "quest" and e.ready
    b.diamondOuter:SetShown(not ready)
    b.diamondInner:SetShown(not ready)
    b.pinDone:SetShown(ready and true or false)
    b.number:SetText((e.kind == "quest" and not ready) and number or "")
    b.number:SetTextColor(col[1], col[2], col[3])

    b.title:SetWidth(width - INDENT - (IsFocusedEntry(e) and 96 or 0))
    b.title:SetText(e.title)
    if col == TYPE_COLORS.failed then
        b.title:SetTextColor(1.00, 0.42, 0.38, 0.96)
    else
        b.title:SetTextColor(1, 1, 1, 0.96)
    end

    local y = -(b.title:GetStringHeight() + 4)
    for j, o in ipairs(e.objectives) do
        local line = GetLine(b, j)
        local tc = (o.groupLabel and TYPE_COLORS.group) or (o.done and { 0.45, 0.54, 0.58 }) or (o.ready and READY_COLOR) or (o.failed and TYPE_COLORS.failed) or { 0.72, 0.82, 0.86 }
        line.text:SetWidth(width - INDENT - BOX_INDENT)
        line.text:SetText(o.text)
        line.text:SetTextColor(tc[1], tc[2], tc[3])
        line.text:ClearAllPoints()
        line.text:SetPoint("TOPLEFT", b, "TOPLEFT", INDENT + BOX_INDENT, y)
        line.text:Show()

        line.box:ClearAllPoints()
        line.box:SetPoint("TOPLEFT", b, "TOPLEFT", INDENT + 1, y - 4)
        line.check:ClearAllPoints()
        line.check:SetPoint("TOPLEFT", b, "TOPLEFT", INDENT - 3, y + 1)
        if o.done or o.ready then
            line.box:Hide()
            line.check:SetVertexColor(tc[1], tc[2], tc[3])
            line.check:Show()
        elseif o.failed then
            line.box:Hide()
            line.check:Hide()
        else
            line.box:Show()
            line.check:Hide()
        end
        y = y - line.text:GetStringHeight() - LINE_GAP
    end
    for j = #e.objectives + 1, #b.lines do
        local line = b.lines[j]
        line.text:Hide()
        line.box:Hide()
        line.check:Hide()
    end

    local height = -y
    b:SetWidth(width)
    b:SetHeight(height)
    return height
end


--------------------------------------------------------------------------------
-- Reconstrução
--------------------------------------------------------------------------------
local function Update()
    dirty = false
    if not tracker or not header then return end
    local db = M.db
    local list = {}
    CollectQuests(list)
    CollectAchievements(list)

    local now = GetTime()
    for _, e in ipairs(list) do
        local old = signatures[e.key]
        if old and old ~= e.signature then
            flashUntil[e.key] = now + FLASH_TIME -- objetivo avançou: destaca
        end
        signatures[e.key] = e.signature
    end

    local qr = Azaath:GetModule("QuestRoute")
    local guideH = (qr and qr.GetHeight and qr:GetHeight()) or 0
    header:ClearAllPoints()
    header:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, -guideH)
    header:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", 0, -guideH)
    content:ClearAllPoints()
    content:SetPoint("TOPLEFT", tracker, "TOPLEFT", PAD_X, -(guideH + HEADER_H + 6))

    headerCount:SetText(#list > 0 and #list or "")
    if headerArrow then headerArrow:SetRotation(db.collapsed and 0 or (-math.pi / 2)) end
    if #list == 0 and guideH == 0 then
        tracker:Hide()
        if listBg then listBg:Hide() end
        return
    end
    tracker:Show()
    if #list == 0 then
        header:Hide()
        content:Hide()
        if listBg then listBg:Hide() end
        tracker:SetHeight(guideH)
        return
    end
    header:Show()
    local bgAlpha = db.transparentBg and 0 or 1
    if listBg then listBg:SetAlpha(bgAlpha); listBg:Show() end
    if header.hbg then header.hbg:SetAlpha(bgAlpha) end
    if header.hTop then header.hTop:SetAlpha(bgAlpha) end
    if header.hBot then header.hBot:SetAlpha(bgAlpha) end
    if header.bgBtn and header.bgBtn.eye then
        if db.transparentBg then
            header.bgBtn.eye:SetVertexColor(0.48, 0.58, 0.65, 0.70)
        else
            header.bgBtn.eye:SetVertexColor(0.37, 0.89, 0.90, 0.95)
        end
    end

    if db.collapsed then
        content:Hide()
        tracker:SetHeight(guideH + HEADER_H)
        return
    end
    content:Show()

    local width = (db.width or 270) - PAD_X * 2
    local limit = db.maxHeight
    content:SetWidth(width)
    local y, shown = 0, 0
    for i, e in ipairs(list) do
        local b = GetBlock(i)
        b.entry = e
        local h = RenderBlock(b, e, i, width)
        if shown > 0 and (-y + h) > limit then break end
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        b:Show()
        SetHighlight(b, b.hover or IsFocusedEntry(e) or (flashUntil[e.key] and now < flashUntil[e.key]))
        y = y - h - BLOCK_GAP
        shown = i
    end
    for i = 1, shown do
        if blocks[i].sep then
            if i < shown then blocks[i].sep:Show() else blocks[i].sep:Hide() end
        end
    end
    for i = shown + 1, #blocks do
        blocks[i]:Hide()
        blocks[i].entry = nil
    end

    local hidden = #list - shown
    if hidden > 0 then
        moreText:SetText(format("+%d %s", hidden, hidden == 1 and "missão" or "missões"))
        moreText:ClearAllPoints()
        moreText:SetPoint("TOPLEFT", content, "TOPLEFT", INDENT, y + BLOCK_GAP - 2)
        moreText:Show()
        y = y - 16
    else
        moreText:Hide()
    end

    content:SetHeight(max(1, -y))
    tracker:SetHeight(guideH + HEADER_H + 6 - y + 4)
    M:UpdateNavBadge()
end

function M:UpdateNavBadge()
    local qn = Azaath:GetModule("QuestNav")
    local info = qn and qn.GetNavInfo and qn:GetNavInfo()
    local focusedID = info and info.questID
    for i = 1, #blocks do
        local b = blocks[i]
        if b:IsShown() and b.navBadge and b.entry then
            if focusedID and b.entry.kind == "quest" and b.entry.questID == focusedID then
                local parts = {}
                if info.distance then
                    parts[#parts + 1] = info.distance < 10 and "Perto" or format("%d m", math.floor(info.distance + 0.5))
                end
                if info.contextTag then
                    parts[#parts + 1] = info.contextTag
                end
                if #parts > 0 then
                    b.navBadge:SetText(table.concat(parts, " · "))
                else
                    b.navBadge:SetText("Em foco")
                end
                b.navBadge:Show()
            else
                b.navBadge:Hide()
            end
        elseif b.navBadge then
            b.navBadge:Hide()
        end
    end
end

function M:Refresh()
    dirty = true
end

function M:ApplyAnchor()
    if not tracker then return end
    tracker:ClearAllPoints()
    local db = self.db or M.db
    local mm = _G.AzaathUIMinimap
    local x = (db and db.offsetX) or -8

    if db and db.customPos then
        tracker:SetPoint("TOPRIGHT", Azaath.root, "TOPRIGHT", x, db.offsetY or -80)
    elseif mm and mm:IsShown() then
        -- Rente à borda direita da tela (-8px), abaixo das coordenadas e relógio do minimapa
        local root = Azaath.root or UIParent
        local rScale = root:GetEffectiveScale()
        local mScale = mm:GetEffectiveScale()
        local tScale = tracker:GetEffectiveScale()
        local rootTop = root:GetTop()
        local mmBottom = mm:GetBottom()
        local y = -260
        if mmBottom and rootTop and rScale and rScale > 0 and mScale and mScale > 0 and tScale and tScale > 0 then
            -- belowHeight: o pergaminho do minimapa Classic desce além dos textos
            y = (mmBottom * mScale - (mm.belowHeight or 58) * mScale - rootTop * rScale) / tScale
        end
        tracker:SetPoint("TOPRIGHT", Azaath.root, "TOPRIGHT", x, y)
    else
        -- Rente à borda direita da tela (-8px), abaixo da bússola (como no Azaath)
        local y = (db and db.offsetY) or -80
        if y < -600 or y > 0 then y = -80 end
        tracker:SetPoint("TOPRIGHT", Azaath.root, "TOPRIGHT", x, y)
    end
    if Azaath.ClampToScreen then Azaath.ClampToScreen(tracker) end
end

function M:ApplyLayout()
    local db = self.db or M.db
    if not db or not tracker then return end
    tracker:SetScale((db.scale and db.scale > 0) and db.scale or 1)
    tracker:SetWidth(db.width or 270)
    if content then content:SetWidth(db.width or 270) end
    self:ApplyAnchor()
    Update()
    local qr = Azaath:GetModule("QuestRoute")
    if qr and qr.UpdateCard then qr:UpdateCard() end
end

--------------------------------------------------------------------------------
-- Construção do rastreador
--------------------------------------------------------------------------------
local function BuildTracker()
    local db, c, media = M.db, Azaath.colors, Azaath.media

    tracker = CreateFrame("Frame", "AzaathUIQuestTracker", Azaath.root)
    tracker:SetFrameStrata("LOW")
    tracker:SetScale((db.scale and db.scale > 0) and db.scale or 1)
    tracker:SetWidth(db.width)
    tracker:SetHeight(HEADER_H)

    -- Fundo moderno contínuo (mesma linguagem visual escura do painel de guia acima)
    listBg = tracker:CreateTexture(nil, "BACKGROUND")
    listBg:SetColorTexture(0.04, 0.06, 0.08, 0.86)

    -- Cabeçalho moderno: "M I S S Õ E S" + contagem + seta; clique recolhe/expande
    header = CreateFrame("Button", nil, tracker)
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT", tracker, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", tracker, "TOPRIGHT", 0, 0)
    local hbg = header:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(0.07, 0.11, 0.14, 0.96)
    header.hbg = hbg
    local hTop = header:CreateTexture(nil, "ARTWORK")
    hTop:SetHeight(1)
    hTop:SetPoint("TOPLEFT"); hTop:SetPoint("TOPRIGHT")
    hTop:SetColorTexture(0.14, 0.22, 0.27, 0.70)
    header.hTop = hTop
    local hBot = header:CreateTexture(nil, "ARTWORK")
    hBot:SetHeight(1)
    hBot:SetPoint("BOTTOMLEFT"); hBot:SetPoint("BOTTOMRIGHT")
    hBot:SetColorTexture(0.14, 0.22, 0.27, 0.50)
    header.hBot = hBot

    listBg:SetPoint("TOPLEFT", header, "TOPLEFT", 0, 0)
    listBg:SetPoint("BOTTOMRIGHT", tracker, "BOTTOMRIGHT", 0, 0)

    local title = CreateText(header, 10, media.fontTitleB)
    title:SetPoint("LEFT", header, "LEFT", PAD_X, 0)
    title:SetText(Azaath.Tracked("Missões"))
    title:SetTextColor(0.75, 0.82, 0.88)
    headerCount = CreateText(header, 10)
    headerCount:SetPoint("LEFT", title, "RIGHT", 6, 0)
    headerCount:SetTextColor(0.37, 0.89, 0.90)
    headerArrow = header:CreateTexture(nil, "OVERLAY")
    headerArrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    headerArrow:SetSize(11, 11)
    headerArrow:SetPoint("RIGHT", header, "RIGHT", -PAD_X, 0)
    headerArrow:SetRotation(-math.pi / 2)
    headerArrow:SetVertexColor(0.55, 0.75, 0.82)

    local bgBtn = CreateFrame("Button", nil, header)
    bgBtn:SetSize(16, 16)
    bgBtn:SetPoint("RIGHT", header, "RIGHT", -PAD_X - 18, 0)
    bgBtn.eye = bgBtn:CreateTexture(nil, "OVERLAY")
    bgBtn.eye:SetTexture(media.path .. "MapUI\\Eye.tga")
    bgBtn.eye:SetSize(14, 14)
    bgBtn.eye:SetPoint("CENTER")
    bgBtn:SetScript("OnClick", function()
        db.transparentBg = not db.transparentBg
        Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        M:ApplyLayout()
    end)
    bgBtn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Fundo do rastreador: " .. (db.transparentBg and "Transparente" or "Escuro"), 1, 1, 1)
        GameTooltip:AddLine("Clique para alternar", 0.75, 0.85, 0.90)
        GameTooltip:Show()
    end)
    bgBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    header.bgBtn = bgBtn

    local loreBtn = CreateFrame("Button", nil, header)
    loreBtn:SetSize(16, 16)
    loreBtn:SetPoint("RIGHT", bgBtn, "LEFT", -4, 0)
    loreBtn.icon = loreBtn:CreateTexture(nil, "OVERLAY")
    loreBtn.icon:SetTexture(media.path .. "MapUI\\Book.tga")
    loreBtn.icon:SetSize(14, 14)
    loreBtn.icon:SetPoint("CENTER")
    loreBtn.icon:SetVertexColor(0.37, 0.89, 0.90, 0.85)
    loreBtn:SetScript("OnClick", function()
        local qgm = Azaath:GetModule("QuestGuideMenu")
        if qgm and qgm.Toggle then
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            qgm:Toggle()
        end
    end)
    loreBtn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 0.82, 0.36, 1)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("Painel Loremaster", 1, 1, 1)
        GameTooltip:AddLine("Clique para abrir o guia de missões", 0.75, 0.85, 0.90)
        GameTooltip:Show()
    end)
    loreBtn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.37, 0.89, 0.90, 0.85)
        GameTooltip:Hide()
    end)
    header.loreBtn = loreBtn
    header:SetScript("OnEnter", function()
        hbg:SetColorTexture(0.09, 0.15, 0.19, 0.96)
        headerArrow:SetVertexColor(0.37, 0.89, 0.90)
    end)
    header:SetScript("OnLeave", function()
        hbg:SetColorTexture(0.07, 0.11, 0.14, 0.96)
        headerArrow:SetVertexColor(0.55, 0.75, 0.82)
    end)
    header:SetScript("OnClick", function()
        db.collapsed = not db.collapsed
        Azaath.PlaySound(db.collapsed and "igMainMenuOptionCheckBoxOff" or "igMainMenuOptionCheckBoxOn")
        Update()
    end)

    content = CreateFrame("Frame", nil, tracker)
    content:SetPoint("TOPLEFT", tracker, "TOPLEFT", PAD_X, -(HEADER_H + 6))
    content:SetWidth((db.width or 270) - PAD_X * 2)
    content:SetHeight(1)

    moreText = CreateText(content, 12)
    moreText:SetTextColor(c.dim[1], c.dim[2], c.dim[3])
    moreText:Hide()

    M:ApplyAnchor()

    local mm = _G.AzaathUIMinimap
    if mm and mm.HookScript then
        mm:HookScript("OnShow", function() M:ApplyAnchor() end)
        mm:HookScript("OnHide", function() M:ApplyAnchor() end)
    end
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local MAX_WATCH = MAX_WATCHABLE_QUESTS or 25

-- Posição no registro de uma missão pelo questID (nil se ainda não entrou)
local function IndexForQuestID(questID)
    local API = Azaath.API
    local QL = _G.C_QuestLog
    if QL and QL.GetLogIndexForQuestID then
        local idx = QL.GetLogIndexForQuestID(questID)
        if idx and idx > 0 then return idx end
    end
    for i = 1, API.NumQuestLogEntries() do
        local title, _, _, _, isHeader, _, _, qid = API.QuestInfo8(i)
        if title and not isHeader and qid == questID then return i end
    end
end

-- Os eventos de missão trazem índice do registro (3.3.5), índice + questID
-- (clássicos antigos) ou só o questID (clientes novos). Devolve o índice
-- válido de uma missão (não cabeçalho), ou nil se ela ainda não está no registro.
local function ResolveIndex(a1, a2)
    local API = Azaath.API
    if type(a2) == "number" and a2 > 0 then
        local idx = IndexForQuestID(a2)
        if idx then return idx end
    end
    if type(a1) ~= "number" or a1 <= 0 then return nil end
    if Azaath.IS_MODERN then
        local idx = IndexForQuestID(a1)
        if idx then return idx end
    end
    if a1 <= API.NumQuestLogEntries() then
        local title, _, _, _, isHeader = API.QuestInfo8(a1)
        if title and not isHeader then return a1 end
    end
end

-- true = resolvido (acompanhado ou não precisa); false = tentar de novo
local function AutoWatch(a1, a2, cvar)
    local API = Azaath.API
    if GetCVar(cvar) ~= "1" then return true end
    local index = ResolveIndex(a1, a2)
    if not index then return false end
    if API.IsQuestWatched(index) then return true end
    if API.NumQuestWatches() >= MAX_WATCH then return true end
    API.AddQuestWatch(index)
    return true
end

-- Missões aceitas que ainda não apareceram no registro: o QUEST_ACCEPTED pode
-- chegar antes do registro ser atualizado. Tenta de novo por alguns segundos.
local PENDING_TIME = 5
local pending = {}

local function ProcessPending()
    if #pending == 0 then return end
    local now = GetTime()
    for i = #pending, 1, -1 do
        local p = pending[i]
        if AutoWatch(p[1], p[2], "autoQuestWatch") or now > p.expires then
            table.remove(pending, i)
            dirty = true
        end
    end
end

local driver = CreateFrame("Frame")
driver:Hide()
driver.elapsed = 0
driver:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "PLAYER_ENTERING_WORLD" or event == "UI_SCALE_CHANGED" then
        M:ApplyAnchor()
    elseif event == "QUEST_ACCEPTED" then
        if not AutoWatch(arg1, arg2, "autoQuestWatch") then
            pending[#pending + 1] = { arg1, arg2, expires = GetTime() + PENDING_TIME }
        end
    elseif event == "QUEST_LOG_UPDATE" then
        ProcessPending()
    elseif event == "QUEST_WATCH_UPDATE" then
        -- progresso em missão não acompanhada: acompanha (como o WatchFrame fazia)
        local index = ResolveIndex(arg1, arg2)
        local objs = index and Azaath.API.QuestObjectives(index) or nil
        if objs and #objs > 0 then
            AutoWatch(index, nil, "autoQuestProgress")
        end
    end
    dirty = true
end)

driver:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + (elapsed or 0)
    if self.elapsed < THROTTLE then return end
    self.elapsed = 0
    ProcessPending()
    if dirty then
        Update()
        return
    end
    -- apaga destaques de progresso vencidos
    local now = GetTime()
    for i = 1, #blocks do
        local b = blocks[i]
        if b:IsShown() and b.entry and not b.hover then
            local until_ = flashUntil[b.entry.key]
            if until_ then
                SetHighlight(b, IsFocusedEntry(b.entry) or now < until_)
                if now >= until_ then flashUntil[b.entry.key] = nil end
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:OnInitialize()
    self.db = Azaath.db.questtracker
end

function M:OnEnable()
    if not self.db.enabled then return end
    -- Com o rastreador da Blizzard visível, não duplica
    if not Azaath.db.hideBlizzard.questTracker then return end

    BuildTracker()

    -- WatchFrame tem botões seguros (itens): ocultar só fora de combate
    Azaath:RunOutOfCombat(function()
        if Azaath.DisableBlizzardFrame then
            Azaath.DisableBlizzardFrame("WatchFrame")             -- 3.3.5
            Azaath.DisableBlizzardFrame("QuestWatchFrame")        -- clássicos modernos
            Azaath.DisableBlizzardFrame("ObjectiveTrackerFrame")  -- motor atual
        end
    end)

    -- QUEST_WATCH_LIST_CHANGED: o jogo (ou o registro de missões) mudou a
    -- lista de acompanhadas; sem ele a missão nova só aparecia no próximo
    -- QUEST_LOG_UPDATE
    for _, e in ipairs({ "QUEST_LOG_UPDATE", "QUEST_WATCH_UPDATE", "QUEST_ACCEPTED",
                         "QUEST_WATCH_LIST_CHANGED", "QUEST_REMOVED",
                         "UNIT_QUEST_LOG_CHANGED", "TRACKED_ACHIEVEMENT_UPDATE",
                         "ACHIEVEMENT_EARNED", "CRITERIA_UPDATE", "PLAYER_ENTERING_WORLD",
                         "UI_SCALE_CHANGED" }) do
        Azaath.SafeRegister(driver, e)
    end
    driver.elapsed = THROTTLE
    dirty = true
    driver:Show()
end
