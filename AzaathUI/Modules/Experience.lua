--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Experience.lua
    Selo de nível em losango (canto inferior esquerdo) e barra de XP fina e
    segmentada na borda inferior da tela (substitui a MainMenuExpBar oculta).

      * Parte descansada (rested) aparece como faixa clara atrás do preenchimento.
      * No nível máximo da expansão a barra some; o selo continua.
      * Passe o mouse na barra para ver XP atual, restante e descansado.
      * Frames de exibição apenas (não protegidos).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("Experience")

local format, floor = string.format, math.floor
local UnitXP, UnitXPMax, UnitLevel, GetXPExhaustion = UnitXP, UnitXPMax, UnitLevel, GetXPExhaustion

local BADGE      = 34
local BAR_LEFT   = BADGE + 22 -- a barra começa depois do selo
local HOVER_H    = 12

local badge, levelText, bar, rested, overlay, dividers, hover
local eventsRegistered = false

-- HUD Azaath (layout "az"): losango do nível centralizado logo abaixo do
-- quadro do jogador, linha fina de XP colada na placa e "XP 45%" ao lado.
local HUD_LINE    = 4    -- padrão; Azaath.HUD.RESOURCE_HEIGHT manda (UnitFrames)
local HUD_AMBER   = { 0.95, 0.72, 0.26 } -- texto "XP" e preenchimento
local HUD_RESTED  = { 0.55, 0.33, 0.90 } -- XP descansada: roxo
local hud -- { badge, level, line, rested, text }

local function IsHud()
    return Azaath.IsHudLayout and Azaath.IsHudLayout() and _G.AzaathUIPlayer ~= nil
end

local function MaxLevel()
    return Azaath.API.MaxLevel() -- GetMaxPlayerLevel no cliente moderno
end

--------------------------------------------------------------------------------
-- Construção
--------------------------------------------------------------------------------
local function BuildBadge()
    local c, media = Azaath.colors, Azaath.media
    local bSize = (M.db and M.db.badgeSize) or BADGE
    badge = CreateFrame("Frame", "AzaathUILevelBadge", Azaath.root)
    badge:SetFrameStrata("LOW")
    badge:SetWidth(bSize)
    badge:SetHeight(bSize)
    badge:SetPoint("BOTTOMLEFT", Azaath.root, "BOTTOMLEFT", (M.db and M.db.badgeX) or 12, (M.db and M.db.badgeY) or 4)

    -- contorno claro + miolo escuro = losango com borda fina
    local outer = badge:CreateTexture(nil, "BACKGROUND")
    outer:SetTexture(media.path .. "Diamond")
    outer:SetVertexColor(c.cream[1], c.cream[2], c.cream[3])
    outer:SetAlpha(0.85)
    outer:SetAllPoints(badge)

    local inner = badge:CreateTexture(nil, "BORDER")
    inner:SetTexture(media.path .. "Diamond")
    inner:SetVertexColor(c.dark[1], c.dark[2], c.dark[3])
    inner:SetAlpha(0.95)
    inner:SetPoint("TOPLEFT", badge, "TOPLEFT", 3, -3)
    inner:SetPoint("BOTTOMRIGHT", badge, "BOTTOMRIGHT", -3, 3)

    levelText = badge:CreateFontString(nil, "OVERLAY")
    levelText:SetFont(media.fontTitleB, 13, "")
    levelText:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    levelText:SetPoint("CENTER", badge, "CENTER", 0, 0)
end

local function LayoutDividers()
    if not bar or not overlay then return end
    local segments = math.max(1, math.min(60, floor((M.db and M.db.segments) or 20)))
    local w = bar:GetWidth()
    if not w or w <= 0 then return end
    local media = Azaath.media
    dividers = dividers or {}
    for i = 1, segments - 1 do
        local d = dividers[i]
        if not d then
            d = overlay:CreateTexture(nil, "OVERLAY")
            d:SetTexture(media.blank)
            d:SetVertexColor(0, 0, 0)
            d:SetAlpha(0.85)
            d:SetWidth(2)
            dividers[i] = d
        end
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", bar, "TOPLEFT", floor(w * i / segments), 0)
        d:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", floor(w * i / segments), 0)
        d:Show()
    end
    for i = segments, #dividers do
        dividers[i]:Hide()
    end
end

local function BuildBar()
    local c, media = Azaath.colors, Azaath.media
    local h = (M.db and M.db.height) or 5

    bar = CreateFrame("StatusBar", "AzaathUIExperienceBar", Azaath.root)
    bar:SetFrameStrata("LOW")
    bar:SetHeight(h)
    bar:SetPoint("BOTTOMLEFT", Azaath.root, "BOTTOMLEFT", BAR_LEFT, 6)
    bar:SetPoint("BOTTOMRIGHT", Azaath.root, "BOTTOMRIGHT", -6, 6)
    bar:SetStatusBarTexture(media.blank)
    bar:SetStatusBarColor(c.parchment[1], c.parchment[2], c.parchment[3])
    bar:SetMinMaxValues(0, 1)

    local bg = bar:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(media.blank)
    bg:SetVertexColor(0, 0, 0)
    bg:SetAlpha(0.55)
    bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -1, 1)
    bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    bar.bg = bg

    -- moldura fina no tom do contorno do losango, envolvendo barra + selo
    local plate = CreateFrame("Frame", nil, bar)
    plate:SetPoint("TOPLEFT", bar, "TOPLEFT", -2, 2)
    plate:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
    if Azaath.SetBackdrop then
        Azaath.SetBackdrop(plate, { edgeFile = media.blank, edgeSize = 1 })
        plate:SetBackdropBorderColor(c.cream[1], c.cream[2], c.cream[3], 0.45)
    end
    bar.plate = plate

    -- XP descansada: barra irmã, atrás do preenchimento
    rested = CreateFrame("StatusBar", nil, bar)
    rested:SetAllPoints(bar)
    rested:SetStatusBarTexture(media.blank)
    rested:SetStatusBarColor(c.accent[1], c.accent[2], c.accent[3])
    rested:SetAlpha(0.35)
    rested:SetFrameLevel(bar:GetFrameLevel())
    bar:SetFrameLevel(rested:GetFrameLevel() + 1)

    -- Divisórias dos segmentos, acima do preenchimento
    overlay = CreateFrame("Frame", nil, bar)
    overlay:SetAllPoints(bar)
    overlay:SetFrameLevel(bar:GetFrameLevel() + 1)
    dividers = {}
    LayoutDividers()
    bar:SetScript("OnSizeChanged", LayoutDividers)

    -- Área de hover mais alta que a barra (5px é difícil de acertar com o mouse)
    hover = CreateFrame("Frame", nil, bar)
    hover:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, -4)
    hover:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, -4)
    hover:SetHeight(HOVER_H)
    hover:EnableMouse(true)
    hover:SetScript("OnEnter", function(self) M.ShowTooltip(self) end)
    hover:SetScript("OnLeave", function() GameTooltip:Hide() end)
end

function M.ShowTooltip(self)
        local c = Azaath.colors
        local cur, max = UnitXP("player"), UnitXPMax("player")
        local restedXP = GetXPExhaustion() or 0
        GameTooltip:SetOwner(self, "ANCHOR_CURSOR")
        GameTooltip:AddLine(format("Nível %d", UnitLevel("player")), c.cream[1], c.cream[2], c.cream[3])
        GameTooltip:AddLine(format("XP: %s / %s (%.1f%%)", Azaath.Thousands(cur), Azaath.Thousands(max),
            max > 0 and cur / max * 100 or 0), 1, 1, 1)
        GameTooltip:AddLine(format("Faltam: %s", Azaath.Thousands(max - cur)), 0.8, 0.8, 0.8)
        if restedXP / max >= 0.005 then
            GameTooltip:AddLine(format("Descansado: %s", Azaath.Thousands(restedXP)), c.accent[1], c.accent[2], c.accent[3])
        end
        GameTooltip:Show()
end

local function BuildHud()
    local media = Azaath.media
    hud = {}

    local line = CreateFrame("StatusBar", "AzaathUIHudXP", Azaath.root)
    line:SetFrameStrata("LOW")
    line:SetHeight(HUD_LINE)
    line:SetStatusBarTexture(media.blank)
    line:SetStatusBarTexture(media.path .. "UnitFrames\\HudFill")
    line:SetStatusBarColor(HUD_AMBER[1], HUD_AMBER[2], HUD_AMBER[3])
    line:SetMinMaxValues(0, 1)
    local bg = line:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(media.blank)
    bg:SetVertexColor(0.05, 0.05, 0.06, 0.90)
    bg:SetPoint("TOPLEFT", line, "TOPLEFT", 0, 0)
    bg:SetPoint("BOTTOMRIGHT", line, "BOTTOMRIGHT", 0, 0)

    -- moldura escura e elegante de 1px
    local frameTop = CreateFrame("Frame", nil, line)
    frameTop:SetAllPoints(line)
    frameTop:SetFrameLevel(line:GetFrameLevel() + 3)
    if Azaath.SetBackdrop then
        Azaath.SetBackdrop(frameTop, {
            edgeFile = media.blank,
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        frameTop:SetBackdropBorderColor(0.22, 0.24, 0.27, 0.95)
    end

    -- Pontas chanfradas metálicas da barra de XP (tapered capsule Azaath)
    local capL = line:CreateTexture(nil, "OVERLAY", nil, 4)
    capL:SetTexture(media.path .. "UnitFrames\\HudXPCap")
    capL:SetTexCoord(1, 0, 0, 1)
    capL:SetSize(8, HUD_LINE + 4)
    capL:SetPoint("RIGHT", line, "LEFT", 2, 0)
    capL:SetVertexColor(0.40, 0.42, 0.46, 0.95)
    hud.capL = capL

    local capR = line:CreateTexture(nil, "OVERLAY", nil, 4)
    capR:SetTexture(media.path .. "UnitFrames\\HudXPCap")
    capR:SetTexCoord(0, 1, 0, 1)
    capR:SetSize(8, HUD_LINE + 4)
    capR:SetPoint("LEFT", line, "RIGHT", -2, 0)
    capR:SetVertexColor(0.40, 0.42, 0.46, 0.95)
    hud.capR = capR

    local r = CreateFrame("StatusBar", nil, line)
    r:SetAllPoints(line)
    r:SetStatusBarTexture(media.path .. "UnitFrames\\HudFill")
    r:SetStatusBarColor(HUD_RESTED[1], HUD_RESTED[2], HUD_RESTED[3]) -- descansado: roxo
    r:SetAlpha(0.95)
    r:SetMinMaxValues(0, 1)
    r:SetFrameLevel(line:GetFrameLevel())
    line:SetFrameLevel(r:GetFrameLevel() + 1)
    hud.line, hud.rested = line, r

    -- Aba trapezoidal de sustentação escura sob a linha (estilo Azaath)
    local tab = CreateFrame("Frame", nil, line)
    tab:SetFrameStrata("MEDIUM")
    tab:SetFrameLevel(line:GetFrameLevel() + 1)
    tab:SetWidth(104)
    tab:SetHeight(18)
    tab:SetPoint("TOP", line, "BOTTOM", 0, 0)
    local tabTex = tab:CreateTexture(nil, "BACKGROUND")
    tabTex:SetTexture(media.path .. "UnitFrames\\HudXPTab")
    tabTex:SetAllPoints(tab)
    hud.tab = tab

    -- Escudo de nível: Losango de metal Azaath
    local b = CreateFrame("Frame", "AzaathUIHudLevel", line)
    b:SetFrameStrata("HIGH")
    b:SetFrameLevel(line:GetFrameLevel() + 5)
    b:SetSize(28, 28)
    b:SetPoint("CENTER", line, "BOTTOM", 0, -3)

    -- Contorno chanfrado de ferro/aço Azaath
    local outer = b:CreateTexture(nil, "BACKGROUND")
    outer:SetTexture(media.path .. "Diamond")
    outer:SetVertexColor(0.48, 0.50, 0.54, 0.95)
    outer:SetAllPoints(b)
    b.outer = outer

    local inner = b:CreateTexture(nil, "BORDER")
    inner:SetTexture(media.path .. "Diamond")
    inner:SetVertexColor(0.06, 0.06, 0.08, 0.98)
    inner:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    inner:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.inner = inner

    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(media.path .. "UnitFrames\\HudDiamond")
    tex:SetAllPoints(b)
    b.tex = tex

    local lvl = b:CreateFontString(nil, "OVERLAY")
    lvl:SetFont(media.fontTitleB, 12, "")
    lvl:SetTextColor(0.96, 0.96, 0.96)
    lvl:SetShadowOffset(1, -1)
    lvl:SetShadowColor(0, 0, 0, 0.95)
    lvl:SetPoint("CENTER", b, "CENTER", 0, 0)
    hud.badge, hud.level = b, lvl

    local t = b:CreateFontString(nil, "OVERLAY")
    t:SetFont(media.fontBold, 11, "")
    t:SetShadowOffset(1, -1)
    t:SetShadowColor(0, 0, 0, 0.9)
    t:SetPoint("LEFT", b, "RIGHT", 7, 0)
    hud.text = t

    -- seta dourada para bônus de XP
    local arrow = b:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture(media.path .. "UnitFrames\\HudArrow")
    arrow:SetWidth(11)
    arrow:SetHeight(11)
    arrow:SetPoint("LEFT", t, "RIGHT", 3, 1)
    arrow:Hide()
    hud.arrow = arrow

    -- dica com XP atual/restante/descansado no losango e na linha
    for _, f in ipairs({ b, line }) do
        f:EnableMouse(true)
        f:SetScript("OnEnter", function(self) M.ShowTooltip(self) end)
        f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    end
end

local function UpdateHud(level, cur, max, restedXP, isMax)
    if not hud then return end
    hud.level:SetText(level)
    if isMax and not (M.db and M.db.showAtMax) then
        hud.line:Hide()
        hud.text:SetText("")
        if hud.arrow then hud.arrow:Hide() end
        return
    end
    hud.line:Show()
    hud.line:SetMinMaxValues(0, max)
    hud.line:SetValue(cur)
    hud.rested:SetMinMaxValues(0, max)
    hud.rested:SetValue(isMax and 0 or math.min(max, cur + restedXP))
    if isMax then
        hud.text:SetText("")
        if hud.arrow then hud.arrow:Hide() end
    else
        local pct = max > 0 and cur / max * 100 or 0
        if restedXP > 0 then
            -- Formato autêntico Azaath: XP x 4 ▲ (ouro/âmbar com multiplicador de bônus)
            hud.text:SetText("|cffdcdcdcXP|r |cffffc838x 4|r |cffffaa1e▲|r")
            hud.arrow:Show()
        else
            hud.text:SetFormattedText("|cffdcdcdcXP|r |cffffc838%.1f%%|r", pct)
            hud.arrow:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- Atualização
--------------------------------------------------------------------------------
local function Update(level)
    level = level or UnitLevel("player")
    if levelText then levelText:SetText(level) end

    if hud and hud.badge:IsShown() then
        local cur, max = UnitXP("player"), UnitXPMax("player")
        local isMax = (level >= MaxLevel())
        if isMax or not max or max <= 0 then cur, max = 1, 1 end
        UpdateHud(level, cur, max, GetXPExhaustion() or 0, isMax)
        if bar then bar:Hide() end
        return
    end

    if not bar then return end
    if not (M.db and M.db.enabled) then
        bar:Hide()
        return
    end
    local isMax = (level >= MaxLevel())
    if isMax and not (M.db and M.db.showAtMax) and not M.editing then
        bar:Hide()
        return
    end
    bar:Show()
    local cur, max = UnitXP("player"), UnitXPMax("player")
    if isMax or not max or max <= 0 then
        cur, max = 1, 1
    end
    bar:SetMinMaxValues(0, max)
    bar:SetValue(cur)
    rested:SetMinMaxValues(0, max)
    rested:SetValue(isMax and 0 or math.min(max, cur + (GetXPExhaustion() or 0)))
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "PLAYER_LEVEL_UP" then
        Update(arg1) -- UnitLevel ainda pode devolver o nível antigo neste evento
    else
        Update()
    end
end)

local function EnsureEvents()
    if eventsRegistered then return end
    eventsRegistered = true
    for _, e in ipairs({ "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION",
                         "PLAYER_ENTERING_WORLD" }) do
        Azaath.SafeRegister(events, e)
    end
end

function M:ApplyLayout()
    local db = self.db
    if not db then return end
    if not db.enabled or (Azaath.IsAzaath and Azaath.IsAzaath()) or (Azaath.IsBDO and Azaath.IsBDO()) then
        -- skin Azaath/BDO: a XP e o nível ficam na HUD própria
        if badge then badge:Hide() end
        if bar then bar:Hide() end
        if hud then hud.badge:Hide(); hud.line:Hide(); hud.tab:Hide() end
        return
    end
    if not badge then BuildBadge() end
    if not bar then BuildBar() end
    EnsureEvents()

    if IsHud() then
        -- HUD Azaath: tudo junto do quadro do jogador; selo e barra da base somem
        if not hud then BuildHud() end
        local pf = _G.AzaathUIPlayer
        -- linha da largura das barras, 3 px abaixo da vida; aba e losango embaixo
        hud.line:ClearAllPoints()
        local lineH = (Azaath.HUD and Azaath.HUD.RESOURCE_HEIGHT) or HUD_LINE
        hud.line:SetHeight(lineH)
        hud.line:SetPoint("TOPLEFT", pf, "BOTTOMLEFT", 0, -3)
        hud.line:SetPoint("TOPRIGHT", pf, "BOTTOMRIGHT", 0, -3)
        hud.line:SetScale(1)
        if hud.tab then
            hud.tab:ClearAllPoints()
            hud.tab:SetPoint("TOP", hud.line, "BOTTOM", 0, 0)
            hud.tab:Show()
        end
        hud.badge:ClearAllPoints()
        hud.badge:SetPoint("TOP", hud.line, "BOTTOM", 0, -1)
        hud.badge:Show()
        badge:Hide()
        bar:Hide()
        Update()
        return
    elseif hud then
        hud.badge:Hide()
        hud.line:Hide()
        hud.tab:Hide()
    end

    -- Barra de XP e selo de nível formam uma peça só (como no Azaath):
    -- o losango fica encaixado na ponta esquerda da barra e anda junto com ela.
    local showBadge = db.showBadge ~= false
    local bSize = math.max(16, db.badgeSize or BADGE)
    local bScale = (db.badgeScale and db.badgeScale > 0) and db.badgeScale or 1
    local h = math.max(2, db.height or 5)
    local scale = (db.scale and db.scale > 0) and db.scale or 1
    -- quanto do losango fica para fora da barra, à esquerda (no espaço da barra)
    local badgeOut = showBadge and floor(bSize * bScale * 0.62 + 0.5) or 0

    bar:SetScale(scale)
    bar:SetHeight(h)
    bar:ClearAllPoints()

    local customW = db.width or 0
    local ox = db.offsetX or 0
    local oy = db.offsetY or 6
    if customW > 0 then
        bar:SetWidth(customW)
        bar:SetPoint("BOTTOM", Azaath.root, "BOTTOM", ox, oy)
    else
        local leftPad = 8 + badgeOut
        local rootW = (Azaath.root:GetWidth() or UIParent:GetWidth() or 1280) / scale
        local calcW = math.max(60, rootW - leftPad - 6)
        bar:SetWidth(calcW)
        bar:SetPoint("BOTTOMLEFT", Azaath.root, "BOTTOMLEFT", leftPad + ox, oy)
        bar:SetPoint("BOTTOMRIGHT", Azaath.root, "BOTTOMRIGHT", -6 + ox, oy)
    end
    if Azaath.ClampToScreen then Azaath.ClampToScreen(bar) end

    -- Selo preso à barra: mesma escala, centro na altura da barra, cobrindo a ponta.
    -- Continua visível no nível máximo, quando a barra some (âncora vale mesmo oculta).
    badge:SetScale(scale * bScale)
    badge:SetWidth(bSize)
    badge:SetHeight(bSize)
    badge:SetFrameStrata(bar:GetFrameStrata())
    badge:SetFrameLevel(bar:GetFrameLevel() + 6)
    badge:ClearAllPoints()
    badge:SetPoint("CENTER", bar, "LEFT", (-badgeOut + bSize * bScale * 0.5) / bScale, 0)
    if Azaath.ClampToScreen then Azaath.ClampToScreen(badge) end

    -- trilho escuro e moldura correm por baixo do losango até o centro dele,
    -- para barra e selo parecerem uma peça contínua
    local under = showBadge and (badgeOut - floor(bSize * bScale * 0.5)) or 0
    if bar.bg then
        bar.bg:ClearAllPoints()
        bar.bg:SetPoint("TOPLEFT", bar, "TOPLEFT", -1 - under, 1)
        bar.bg:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 1, -1)
    end
    if bar.plate then
        bar.plate:ClearAllPoints()
        bar.plate:SetPoint("TOPLEFT", bar, "TOPLEFT", -2 - under, 2)
        bar.plate:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 2, -2)
    end
    if levelText then
        local fSize = math.max(8, floor(bSize * 13 / 34 + 0.5))
        levelText:SetFont(Azaath.media.fontTitleB, fSize, "")
    end
    if showBadge then
        badge:Show()
    else
        badge:Hide()
    end

    if hover then
        hover:SetHeight(math.max(HOVER_H, h + 8))
    end

    LayoutDividers()
    Update()
end

function M:SetEnabled(enabled)
    self.db.enabled = enabled and true or false
    self:ApplyLayout()
end

function M:SetEditing(editing)
    self.editing = editing and true or false
    self:ApplyLayout()
end

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:OnInitialize()
    self.db = Azaath.db.experience
end

function M:OnEnable()
    if not self.db.enabled then return end
    self:ApplyLayout()
end
