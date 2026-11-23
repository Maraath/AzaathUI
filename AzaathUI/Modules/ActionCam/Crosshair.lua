--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ActionCam/Crosshair.lua
    Mira reticular nativa da AzaathUI + reações de cor + feedback de conjuração
    + HUD de Interação (SoftTargetInteract / mouseover) + Assisted Combat
    Highlight (quando disponível) + Marcador de Target Lock na nameplate.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local _G = _G

local AC = Azaath.ActionCam or {}
Azaath.ActionCam = AC

local CreateFrame         = _G.CreateFrame
local InCombatLockdown    = _G.InCombatLockdown
local IsMounted           = _G.IsMounted
local UIParent            = _G.UIParent
local UnitCanAttack       = _G.UnitCanAttack
local UnitClass           = _G.UnitClass
local UnitExists          = _G.UnitExists
local UnitIsDeadOrGhost   = _G.UnitIsDeadOrGhost
local UnitIsFriend        = _G.UnitIsFriend
local UnitIsPlayer        = _G.UnitIsPlayer
local UnitIsUnit          = _G.UnitIsUnit
local UnitName            = _G.UnitName
local UnitReaction        = _G.UnitReaction

local pcall, type, tonumber = pcall, type, tonumber

--------------------------------------------------------------------------------
-- Estilos e Cores
--------------------------------------------------------------------------------
local STYLES = {
    diamond = { tex = Azaath.media.path .. "Diamond.tga",    size = 24 },
    ring    = { tex = Azaath.media.path .. "Ring.tga",       size = 26 },
    dot     = { tex = Azaath.media.path .. "Disc.tga",       size = 12 },
    cross   = { tex = Azaath.media.path .. "MapUI\\Plus.tga",size = 22 },
    star    = { tex = Azaath.media.path .. "Star.tga",       size = 24 },
    hidden  = { tex = nil,                                 size = 16 },
}

local DEFAULT_COLORS = {
    idle       = { 0.93, 0.90, 0.83, 0.78 },
    hostile    = { 0.94, 0.28, 0.24, 0.95 },
    friendly   = { 0.30, 0.85, 0.45, 0.90 },
    interact   = { 0.96, 0.78, 0.38, 0.95 },
    mounted    = { 0.45, 0.78, 0.98, 0.85 },
    targetlock = { 1.00, 0.62, 0.18, 0.95 },
    support    = { 0.25, 0.88, 0.68, 0.95 },
}

local crosshairFrame, crosshairTex, castRingTex, lockInAnim
local interactHUD, interactIcon, interactKeyBg, interactKeyText, interactLabel
local assistFrame, assistIcon, assistKey
local focusMarkerFrame
local targetPreviewFrame, tpAccent, tpName, tpHpBar
local tpLines = {}
local UpdateTargetPreview

local function EnsureCrosshair()
    if crosshairFrame then return crosshairFrame end

    crosshairFrame = CreateFrame("Frame", "AzaathUICrosshairFrame", UIParent)
    crosshairFrame:SetSize(32, 32)
    crosshairFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 100)
    crosshairFrame:SetFrameStrata("MEDIUM")
    crosshairFrame:EnableMouse(false)
    crosshairFrame:Hide()

    crosshairTex = crosshairFrame:CreateTexture(nil, "ARTWORK")
    crosshairTex:SetPoint("CENTER", crosshairFrame, "CENTER", 0, 0)
    crosshairTex:SetSize(24, 24)

    castRingTex = crosshairFrame:CreateTexture(nil, "OVERLAY")
    castRingTex:SetPoint("CENTER", crosshairFrame, "CENTER", 0, 0)
    castRingTex:SetSize(36, 36)
    castRingTex:SetTexture(Azaath.media.path .. "CastRingThin.tga")
    castRingTex:SetVertexColor(0.96, 0.78, 0.38, 0.85)
    castRingTex:SetBlendMode("ADD")
    castRingTex:Hide()

    local ag = crosshairFrame:CreateAnimationGroup()
    local s1 = ag:CreateAnimation("Scale")
    s1:SetScaleFrom(1.35, 1.35)
    s1:SetScaleTo(1.0, 1.0)
    s1:SetDuration(0.18)
    s1:SetSmoothing("OUT")
    lockInAnim = ag

    -- Interaction HUD (medalhão compacto e ornamentado ao lado direito da mira)
    interactHUD = CreateFrame("Frame", "AzaathUIInteractionHUD", crosshairFrame)
    interactHUD:SetSize(200, 26)
    interactHUD:SetScale(0.80)
    interactHUD:SetPoint("LEFT", crosshairFrame, "RIGHT", 10, 0)
    interactHUD:EnableMouse(false)
    interactHUD:Hide()

    local iconBg = interactHUD:CreateTexture(nil, "BACKGROUND")
    iconBg:SetSize(22, 22)
    iconBg:SetPoint("LEFT", interactHUD, "LEFT", 4, 0)
    iconBg:SetTexture(Azaath.media.path .. "Disc.tga")
    iconBg:SetVertexColor(0.06, 0.05, 0.04, 0.86)

    local iconMask = interactHUD:CreateMaskTexture()
    iconMask:SetSize(16, 16)
    iconMask:SetPoint("CENTER", iconBg, "CENTER", 0, 0)
    iconMask:SetTexture(Azaath.media.path .. "Inventory\\RoundMask.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

    interactIcon = interactHUD:CreateTexture(nil, "ARTWORK")
    interactIcon:SetSize(16, 16)
    interactIcon:SetPoint("CENTER", iconBg, "CENTER", 0, 0)
    interactIcon:AddMaskTexture(iconMask)

    local iconRing = interactHUD:CreateTexture(nil, "OVERLAY")
    iconRing:SetSize(26, 26)
    iconRing:SetPoint("CENTER", iconBg, "CENTER", 0, 0)
    iconRing:SetTexture(Azaath.media.path .. "MapUI\\Rim.tga")
    iconRing:SetVertexColor(0.83, 0.70, 0.44, 0.95)

    local pointer = interactHUD:CreateTexture(nil, "OVERLAY")
    pointer:SetSize(8, 8)
    pointer:SetPoint("RIGHT", iconBg, "LEFT", 1, 0)
    pointer:SetTexture(Azaath.media.path .. "Target\\TargetArrow.tga")
    pointer:SetRotation(math.rad(90))
    pointer:SetVertexColor(0.83, 0.70, 0.44, 0.90)

    interactKeyBg = CreateFrame("Frame", nil, interactHUD)
    interactKeyBg:SetSize(12, 12)
    interactKeyBg:SetPoint("TOPRIGHT", iconBg, "TOPRIGHT", 4, 3)
    interactKeyBg:SetFrameLevel(interactHUD:GetFrameLevel() + 3)

    interactKeyText = interactKeyBg:CreateFontString(nil, "OVERLAY")
    interactKeyText:SetFont(Azaath.media.fontTitleB or Azaath.media.fontBold, 10, "OUTLINE")
    interactKeyText:SetShadowColor(0, 0, 0, 0.9)
    interactKeyText:SetShadowOffset(1, -1)
    interactKeyText:SetPoint("CENTER", interactKeyBg, "CENTER", 0, 0)
    interactKeyText:SetTextColor(0.96, 0.92, 0.82)

    interactLabel = interactHUD:CreateFontString(nil, "OVERLAY")
    interactLabel:SetFont(Azaath.media.fontCinzel or Azaath.media.fontBold, 10.5, "OUTLINE")
    interactLabel:SetShadowColor(0, 0, 0, 0.9)
    interactLabel:SetShadowOffset(1, -1)
    interactLabel:SetPoint("LEFT", iconBg, "RIGHT", 6, 0)
    interactLabel:SetTextColor(0.95, 0.91, 0.83)

    -- Assisted Combat Highlight (só aparece se C_AssistedCombat existir)
    assistFrame = CreateFrame("Frame", "AzaathUIAssistHUD", crosshairFrame)
    assistFrame:SetSize(28, 28)
    assistFrame:SetPoint("LEFT", crosshairFrame, "RIGHT", 24, 0)
    assistFrame:EnableMouse(false)
    assistFrame:Hide()

    assistIcon = assistFrame:CreateTexture(nil, "ARTWORK")
    assistIcon:SetAllPoints(assistFrame)
    assistIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local assistBorder = assistFrame:CreateTexture(nil, "OVERLAY")
    assistBorder:SetPoint("TOPLEFT", -2, 2)
    assistBorder:SetPoint("BOTTOMRIGHT", 2, -2)
    assistBorder:SetTexture(Azaath.media.path .. "ActionBar\\SlotBorder.tga")
    assistBorder:SetVertexColor(0.79, 0.66, 0.42, 0.9)

    assistKey = assistFrame:CreateFontString(nil, "OVERLAY")
    assistKey:SetFont(Azaath.media.fontBold, 10, "OUTLINE")
    assistKey:SetPoint("BOTTOMRIGHT", assistFrame, "BOTTOMRIGHT", -1, 1)
    assistKey:SetTextColor(1, 1, 1)

    return crosshairFrame
end

local function EvalSituational(db)
    local code = db and db.crosshairSituationalCondition
    if type(code) ~= "string" or code:match("^%s*$") then return false end
    local fn = _G.loadstring(code)
    if not fn then return false end
    local ok, res = pcall(fn)
    return ok and res == true
end

function AC.ApplyCrosshairLayout()
    local f = EnsureCrosshair()
    local db = AC.DB()
    if not db then return end
    local scale = tonumber(db.crosshairScale) or 1.0
    local y = tonumber(db.crosshairY) or 100
    f:SetScale(scale)
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "CENTER", 0, y)
    AC.SyncCursorCenteredYPos()

    -- Assist HUD side/scale/padding
    local side = db.assistedHighlightSide or "RIGHT"
    local pad = tonumber(db.assistedHighlightPadding) or 24
    assistFrame:SetScale(tonumber(db.assistedHighlightScale) or 1.0)
    assistFrame:ClearAllPoints()
    if side == "LEFT" then
        assistFrame:SetPoint("RIGHT", f, "LEFT", -pad, 0)
    elseif side == "TOP" then
        assistFrame:SetPoint("BOTTOM", f, "TOP", 0, pad)
    elseif side == "BOTTOM" then
        assistFrame:SetPoint("TOP", f, "BOTTOM", 0, -pad)
    else
        assistFrame:SetPoint("LEFT", f, "RIGHT", pad, 0)
    end
end

function AC.DisplayCrosshair(show)
    local f = EnsureCrosshair()
    local db = AC.DB()
    if show and db and db.enabled and db.crosshair then
        AC.ApplyCrosshairLayout()
        f:Show()
        AC.UpdateCrosshairReaction()
    else
        f:Hide()
        if targetPreviewFrame then targetPreviewFrame:Hide() end
    end
end

function AC.ShowCrosshairLockIn()
    if not crosshairFrame or not crosshairFrame:IsShown() then return end
    if lockInAnim then
        lockInAnim:Stop()
        lockInAnim:Play()
    end
end

function AC.UpdateCrosshairCastFeedback(casting)
    if not crosshairFrame or not castRingTex then return end
    local db = AC.DB()
    local isWorldInteract = (_G.AzaathUICastBarWorld and _G.AzaathUICastBarWorld:IsShown())
        or UnitExists("softinteract")
    if casting and not isWorldInteract and db and db.crosshairCastFeedback and crosshairFrame:IsShown() then
        castRingTex:Show()
    else
        castRingTex:Hide()
    end
end

local function SafeUnitName(unit)
    local name = UnitName(unit)
    if Azaath.IsSecret(name) or type(name) ~= "string" or name == "" then
        return nil
    end
    return name
end

local function SafeUnitNameUnmodified(unit)
    if not _G.UnitNameUnmodified then return nil end
    local name = _G.UnitNameUnmodified(unit)
    if Azaath.IsSecret(name) or type(name) ~= "string" or name == "" then
        return nil
    end
    return name
end

function AC.UpdateCrosshairReaction()
    local f = crosshairFrame
    if not f or not f:IsShown() then return end
    local db = AC.DB()
    if not db then return end

    if castRingTex and castRingTex:IsShown() and ((_G.AzaathUICastBarWorld and _G.AzaathUICastBarWorld:IsShown()) or UnitExists("softinteract")) then
        castRingTex:Hide()
    end

    local styleKey = db.crosshairStyle or "diamond"
    if EvalSituational(db) then
        styleKey = db.crosshairSituationalStyle or "hidden"
    end
    local st = STYLES[styleKey] or STYLES.diamond
    if not st.tex then
        crosshairTex:Hide()
    else
        crosshairTex:SetTexture(st.tex)
        crosshairTex:SetSize(st.size, st.size)
        crosshairTex:Show()
    end

    -- Cor por reação
    local colorKey = "idle"
    if db.supportModeActive then
        colorKey = "support"
    elseif UnitExists("softenemy") or (UnitExists("mouseover") and UnitCanAttack("player", "mouseover") and not UnitIsDeadOrGhost("mouseover")) then
        colorKey = "hostile"
    elseif UnitExists("softinteract") then
        colorKey = "interact"
    elseif UnitExists("mouseover") and UnitIsFriend("player", "mouseover") then
        colorKey = "friendly"
    elseif UnitExists("focus") then
        colorKey = "targetlock"
    elseif IsMounted and IsMounted() then
        colorKey = "mounted"
    end

    local c = (db.crosshairColors and db.crosshairColors[colorKey]) or DEFAULT_COLORS[colorKey] or DEFAULT_COLORS.idle
    crosshairTex:SetVertexColor(c[1], c[2], c[3], c[4] or 0.9)

    -- Interaction HUD (minérios, ervas, baús, NPCs, objetos e jogadores)
    if db.interactionHUD then
        local hasSoftInteract = UnitExists("softinteract")
            or (_G.UnitGUID and _G.UnitGUID("softinteract") ~= nil)
            or (_G.UnitIsGameObject and not Azaath.IsSecret(_G.UnitIsGameObject("softinteract")) and _G.UnitIsGameObject("softinteract"))
        local unit = hasSoftInteract and "softinteract" or (UnitExists("mouseover") and "mouseover" or nil)
        if unit then
            local isPlayer = UnitIsPlayer(unit)
            if not Azaath.IsSecret(isPlayer) and isPlayer and not db.interactionHUDPlayers then
                unit = nil
            end
            if unit and UnitIsUnit(unit, "player") then
                unit = nil
            end
        end
        if unit and (unit == "softinteract" or not UnitCanAttack("player", unit)) then
            local name = SafeUnitName(unit)
                or SafeUnitNameUnmodified(unit)
                or (_G.GetUnitName and _G.GetUnitName(unit, false))
            if name and (Azaath.IsSecret(name) or name ~= "") then
                local stamped = false
                if _G.SetUnitCursorTexture then
                    interactIcon:SetTexture(nil)
                    local ok, res = pcall(_G.SetUnitCursorTexture, interactIcon, unit, nil, true)
                    stamped = ok and res and (interactIcon:GetTexture() ~= nil)
                end
                if not stamped then
                    interactIcon:SetTexture(Azaath.media.path .. "MapUI\\Gem.tga")
                end
                interactIcon:SetAlpha(1)

                local key = _G.GetBindingKey and (_G.GetBindingKey("INTERACTTARGET") or _G.GetBindingKey("INTERACTMOUSEOVER")) or nil
                if key and key ~= "" then
                    interactKeyText:SetText(key)
                    local kw = math.max(14, (interactKeyText:GetStringWidth() or 8) + 6)
                    interactKeyBg:SetWidth(kw)
                    interactKeyBg:Show()
                else
                    interactKeyBg:Hide()
                end

                interactLabel:SetText(name)
                interactHUD:Show()
            else
                interactHUD:Hide()
            end
        else
            interactHUD:Hide()
        end
    else
        interactHUD:Hide()
    end

    -- Assisted Combat Highlight (se disponível no cliente)
    local mode = db.assistedHighlightMode or "always"
    if mode ~= "hidden" and _G.C_AssistedCombat and _G.C_AssistedCombat.GetNextCastSpell then
        local showAssist = (mode == "always") or (mode == "combat" and InCombatLockdown())
        if showAssist then
            local ok, spellID = pcall(_G.C_AssistedCombat.GetNextCastSpell, true)
            if ok and spellID and not Azaath.IsSecret(spellID) and _G.C_Spell and _G.C_Spell.GetSpellTexture then
                local tex = _G.C_Spell.GetSpellTexture(spellID)
                if tex then
                    assistIcon:SetTexture(tex)
                    assistFrame:Show()
                else
                    assistFrame:Hide()
                end
            else
                assistFrame:Hide()
            end
        else
            assistFrame:Hide()
        end
    else
        assistFrame:Hide()
    end

    UpdateTargetPreview(db)
end

--------------------------------------------------------------------------------
-- Prévia de Placa do Alvo sob a Mira (Estilo Azaath, Canto Inferior Direito)
--------------------------------------------------------------------------------
local PREVIEW_UNITS = { "softenemy", "mouseover", "softfriend", "softinteract" }
local CLASSIF_LABELS = {
    rare      = "Raro",
    elite     = "Elite",
    rareelite = "Raro Elite",
    worldboss = "Chefe",
}

local function EnsureTargetPreview()
    if targetPreviewFrame then return targetPreviewFrame end

    local f = CreateFrame("Frame", "AzaathUITargetPreview", UIParent, "BackdropTemplate")
    f:SetFrameStrata("HIGH")
    f:SetClampedToScreen(true)
    f:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -24, 96)
    f:SetSize(220, 58)
    Azaath.ApplyPanel(f, 0.94)

    tpAccent = f:CreateTexture(nil, "ARTWORK")
    tpAccent:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    tpAccent:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    tpAccent:SetHeight(2)

    tpName = f:CreateFontString(nil, "OVERLAY")
    tpName:SetFont(Azaath.media.fontTitleB, 14, "OUTLINE")
    tpName:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -8)
    tpName:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -8)
    tpName:SetJustifyH("LEFT")
    tpName:SetWordWrap(false)

    for i = 1, 8 do
        local line = f:CreateFontString(nil, "OVERLAY")
        line:SetFont(Azaath.media.font, 11, "OUTLINE")
        if i == 1 then
            line:SetPoint("TOPLEFT", tpName, "BOTTOMLEFT", 0, -3)
            line:SetPoint("TOPRIGHT", tpName, "BOTTOMRIGHT", 0, -3)
        else
            line:SetPoint("TOPLEFT", tpLines[i - 1], "BOTTOMLEFT", 0, -2)
            line:SetPoint("TOPRIGHT", tpLines[i - 1], "BOTTOMRIGHT", 0, -2)
        end
        line:SetJustifyH("LEFT")
        line:SetWordWrap(false)
        line:SetTextColor(0.86, 0.88, 0.90)
        line:Hide()
        tpLines[i] = line
    end

    local hpBg = f:CreateTexture(nil, "BACKGROUND", nil, 2)
    hpBg:SetTexture(Azaath.media.blank)
    hpBg:SetVertexColor(0.06, 0.07, 0.09, 0.92)
    hpBg:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 10, 8)
    hpBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -10, 8)
    hpBg:SetHeight(6)

    tpHpBar = CreateFrame("StatusBar", nil, f)
    tpHpBar:SetStatusBarTexture(Azaath.media.blank)
    tpHpBar:SetAllPoints(hpBg)
    tpHpBar:SetMinMaxValues(0, 1)
    tpHpBar:SetValue(1)

    f:Hide()
    targetPreviewFrame = f
    return f
end

local function GetPreviewUnit()
    for _, u in ipairs(PREVIEW_UNITS) do
        if UnitExists(u) and not UnitIsUnit(u, "player") then
            return u
        end
    end
    return nil
end

local function GetPreviewColor(unit)
    local okTap, tapped = pcall(UnitIsTapDenied, unit)
    if okTap and not Azaath.IsSecret(tapped) and tapped then
        return 0.55, 0.55, 0.55
    end
    local okDead, dead = pcall(UnitIsDeadOrGhost, unit)
    if okDead and not Azaath.IsSecret(dead) and dead then
        return 0.55, 0.55, 0.55
    end
    if UnitIsPlayer(unit) then
        local ok, _, classFile = pcall(UnitClass, unit)
        local c = ok and classFile and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classFile]
        if c then return c.r, c.g, c.b end
    end
    local okR, reaction = pcall(UnitReaction, "player", unit)
    if okR and reaction and not Azaath.IsSecret(reaction) then
        if reaction <= 3 then
            return 0.90, 0.25, 0.22
        elseif reaction == 4 then
            return 0.95, 0.80, 0.20
        else
            return 0.25, 0.80, 0.35
        end
    end
    if UnitIsFriend("player", unit) then
        return 0.25, 0.80, 0.35
    elseif UnitCanAttack("player", unit) then
        return 0.90, 0.25, 0.22
    end
    return 0.95, 0.80, 0.20
end

local function CollectTooltipDetails(unit)
    local details = {}
    local hasQuestLine = false

    local gt = _G.GameTooltip
    if gt and not gt:IsShown() then
        AC.scanningTargetTooltip = true
        local prevAlpha = gt:GetAlpha() or 1
        gt:SetAlpha(0)
        gt:SetOwner(_G.WorldFrame, "ANCHOR_NONE")
        gt:ClearLines()
        pcall(gt.SetUnit, gt, unit)
        local nLines = math.min((gt.NumLines and gt:NumLines()) or 9, 10)
        for i = 2, nLines do
            local fs = _G["GameTooltipTextLeft" .. i]
            local txt = fs and fs:GetText()
            if txt and not Azaath.IsSecret(txt) and type(txt) == "string" and txt ~= "" then
                local lr, lg, lb = fs:GetTextColor()
                if txt:find("%d+/%d+") or (lr and lg and lb and lr > 0.9 and lg > 0.75 and lb < 0.2) then
                    hasQuestLine = true
                end
                details[#details + 1] = {
                    text = txt,
                    r = lr or 0.88,
                    g = lg or 0.90,
                    b = lb or 0.92,
                }
                if #details >= 8 then break end
            end
        end
        gt:ClearLines()
        gt:Hide()
        gt:SetAlpha(prevAlpha)
        AC.scanningTargetTooltip = false
    end

    if #details == 0 and _G.C_TooltipInfo and _G.C_TooltipInfo.GetUnit then
        local ok, info = pcall(_G.C_TooltipInfo.GetUnit, unit)
        if ok and info and info.lines then
            local qt = _G.Enum and _G.Enum.TooltipDataLineType and _G.Enum.TooltipDataLineType.QuestTitle
            local qo = _G.Enum and _G.Enum.TooltipDataLineType and _G.Enum.TooltipDataLineType.QuestObjective
            for i = 2, #info.lines do
                local line = info.lines[i]
                local txt = line and line.leftText
                if txt and not Azaath.IsSecret(txt) and type(txt) == "string" and txt ~= "" then
                    if line.type == qt or line.type == qo or txt:find("%d+/%d+") then
                        hasQuestLine = true
                    end
                    local c = line.leftColor
                    details[#details + 1] = {
                        text = txt,
                        r = c and c.r or 0.88,
                        g = c and c.g or 0.90,
                        b = c and c.b or 0.92,
                    }
                    if #details >= 8 then break end
                end
            end
        end
    end

    if #details == 0 then
        local okLvl, lvl = pcall(UnitLevel, unit)
        local parts = { (okLvl and lvl and not Azaath.IsSecret(lvl) and lvl > 0) and ("Nível " .. lvl) or "Nível ??" }
        local okCls, cls = pcall(UnitClassification, unit)
        if okCls and cls and not Azaath.IsSecret(cls) and CLASSIF_LABELS[cls] then
            parts[#parts + 1] = CLASSIF_LABELS[cls]
        end
        if UnitIsPlayer(unit) then
            local okC, className = pcall(UnitClass, unit)
            if okC and className and not Azaath.IsSecret(className) and className ~= "" then
                parts[#parts + 1] = className
            end
        else
            local okT, creature = pcall(UnitCreatureType, unit)
            if okT and creature and not Azaath.IsSecret(creature) and creature ~= "" then
                parts[#parts + 1] = creature
            end
        end
        details[1] = { text = table.concat(parts, " • "), r = 0.86, g = 0.88, b = 0.90 }
    end

    if not hasQuestLine and #details < 8 then
        local isQuest = false
        if _G.C_QuestLog and _G.C_QuestLog.UnitIsRelatedToActiveQuest then
            local okQ, q = pcall(_G.C_QuestLog.UnitIsRelatedToActiveQuest, unit)
            if okQ and not Azaath.IsSecret(q) and q then isQuest = true end
        end
        if not isQuest and _G.UnitIsQuestBoss then
            local okQB, qb = pcall(_G.UnitIsQuestBoss, unit)
            if okQB and not Azaath.IsSecret(qb) and qb then isQuest = true end
        end
        if isQuest then
            details[#details + 1] = { text = "Objetivo de Missão", r = 1.0, g = 0.82, b = 0.20 }
        end
    end

    return details
end

function UpdateTargetPreview(db)
    if not (db and db.enabled and db.crosshair and db.crosshairTargetPreview and AC.IsMouselooking())
        or (_G.GameTooltip and _G.GameTooltip:IsShown()) then
        if targetPreviewFrame then targetPreviewFrame:Hide() end
        return
    end

    local unit = GetPreviewUnit()
    if not unit then
        if targetPreviewFrame then targetPreviewFrame:Hide() end
        return
    end

    local name = SafeUnitNameUnmodified(unit)
    if not name or name == "" then
        if targetPreviewFrame then targetPreviewFrame:Hide() end
        return
    end

    local f = EnsureTargetPreview()
    local r, g, b = GetPreviewColor(unit)

    tpAccent:SetColorTexture(r, g, b, 0.92)
    tpName:SetText(name)
    tpName:SetTextColor(r, g, b)

    local details = CollectTooltipDetails(unit)
    local maxW = tpName:GetStringWidth() or 0
    local numLines = #details
    for i = 1, 8 do
        local fs = tpLines[i]
        local d = details[i]
        if d then
            fs:SetText(d.text)
            fs:SetTextColor(d.r, d.g, d.b)
            fs:Show()
            local lw = fs:GetStringWidth() or 0
            if lw > maxW then maxW = lw end
        else
            fs:Hide()
        end
    end

    local okHp, hp = pcall(UnitHealth, unit)
    local okMax, hpMax = pcall(UnitHealthMax, unit)
    if okHp and okMax and hp and hpMax and not Azaath.IsSecret(hp) and not Azaath.IsSecret(hpMax) and hpMax > 0 then
        tpHpBar:SetMinMaxValues(0, hpMax)
        tpHpBar:SetValue(hp)
        tpHpBar:SetStatusBarColor(r, g, b, 0.95)
    else
        tpHpBar:SetMinMaxValues(0, 1)
        tpHpBar:SetValue(1)
        tpHpBar:SetStatusBarColor(r, g, b, 0.55)
    end

    local h = 8 + 16 + 4 + (numLines * 14) + 8 + 6 + 8
    f:SetSize(math.max(190, math.min(300, maxW + 24)), h)
    f:Show()
end

--------------------------------------------------------------------------------
-- Marcador de Target Lock (focus) na Nameplate
--------------------------------------------------------------------------------
local function EnsureFocusMarker()
    if focusMarkerFrame then return focusMarkerFrame end
    focusMarkerFrame = CreateFrame("Frame", "AzaathUIFocusLockMarker", UIParent)
    focusMarkerFrame:SetSize(20, 20)
    focusMarkerFrame:EnableMouse(false)
    focusMarkerFrame:Hide()

    local tex = focusMarkerFrame:CreateTexture(nil, "OVERLAY")
    tex:SetAllPoints(focusMarkerFrame)
    tex:SetTexture(Azaath.media.path .. "Target\\AllyDiamond.tga")
    tex:SetVertexColor(1.0, 0.65, 0.15, 0.95)
    return focusMarkerFrame
end

function AC.UpdateFocusNameplateMarker()
    local m = EnsureFocusMarker()
    local db = AC.DB()
    if not (db and db.enabled and db.showTargetLockMarker) then
        m:Hide()
        return
    end
    if not UnitExists("focus") or not (_G.C_NamePlate and _G.C_NamePlate.GetNamePlateForUnit) then
        m:Hide()
        return
    end
    local np = _G.C_NamePlate.GetNamePlateForUnit("focus")
    if np and not (np.IsForbidden and np:IsForbidden()) then
        m:ClearAllPoints()
        m:SetPoint("BOTTOM", np, "TOP", 0, 4)
        m:Show()
    else
        m:Hide()
    end
end
