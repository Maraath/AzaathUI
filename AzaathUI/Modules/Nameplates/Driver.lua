--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Driver.lua
    Motor principal das placas de nome: ciclo de vida, supressão das placas da
    Blizzard, geometria (clique e empilhamento), alpha, escala, combate/OOC,
    CVars e integração com o módulo AzaathUI ("Nameplates").
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local M = Azaath:NewModule("Nameplates")
local _G = _G
local pairs, ipairs, pcall, tonumber, tostring, type, select = pairs, ipairs, pcall, tonumber, tostring, type, select
local floor, max, min, wipe = math.floor, math.max, math.min, wipe

local C_NamePlate = _G.C_NamePlate
local UnitIsUnit, UnitIsPlayer, UnitCanAttack, UnitReaction = _G.UnitIsUnit, _G.UnitIsPlayer, _G.UnitCanAttack, _G.UnitReaction
local UnitAffectingCombat, UnitIsDead, UnitClassification = _G.UnitAffectingCombat, _G.UnitIsDead, _G.UnitClassification

local state = {
    unitEventMap = {},
    hookedUF = setmetatable({}, { __mode = "k" }),
    hiddenParent = _G.CreateFrame("Frame"),
    pxPending = {}, pxLate = {}, pxSoon = false, pxLater = false,
    pxTicker = nil, combatTicker = nil,
}
state.hiddenParent:Hide()
NP.targetPlate, NP.focusPlate, NP.mouseoverPlate, NP.softPlate = nil, nil, nil, nil

local function IsGameObjectUnit(unit)
    if _G.UnitIsGameObject then
        local ok, v = pcall(_G.UnitIsGameObject, unit)
        if ok and not NP.IsSecret(v) and v == true then return true end
    end
    if _G.UnitGUID then
        local ok, g = pcall(_G.UnitGUID, unit)
        if ok and not NP.IsSecret(g) and type(g) == "string" and g:find("^GameObject%-") then return true end
    end
    if not NP.Truthy(UnitIsPlayer(unit), false) and not NP.Truthy(UnitCanAttack("player", unit), false) then
        local raw = UnitReaction(unit, "player")
        if raw == nil and not NP.IsSecret(raw) then return true end
    end
    return false
end

local function GetUnitKind(unit)
    local isPlayer = NP.Truthy(UnitIsPlayer(unit), false)
    local canAttack = NP.Truthy(UnitCanAttack("player", unit), false)
    local raw = UnitReaction(unit, "player")
    local reaction = NP.Plain(raw, 4) or 4
    local enemy = canAttack or reaction <= 3 or (reaction == 4 and (NP.inInstance or NP.IsSecret(raw)))
    if isPlayer then
        return (enemy and canAttack) and "enemyplayer" or "friendlyplayer"
    end
    return enemy and "enemynpc" or "friendlynpc"
end

-- Supressão segura das placas padrão da Blizzard
local function ShouldHideBlizz(plate)
    local f = plate and plate.AzNPFrame
    return f and f.active and f.cfg and f.cfg.mode ~= "blizzard" and NP.db and NP.db.general.hideBlizzardPlates
end

local function SuppressBlizz(uf, plate)
    if not uf then return end
    plate = plate or uf.AzNPPlate or uf:GetParent()
    if not ShouldHideBlizz(plate) then return end
    uf.AzNPPlate = plate
    uf:SetAlpha(0)
    if not uf:IsProtected() then uf:Hide() end
    if not uf.AzSilenced then
        uf.AzSilenced = true
        if plate and not plate.AzPark then
            local park = _G.CreateFrame("Frame", nil, plate)
            park:SetAllPoints(plate); park:Hide(); plate.AzPark = park
        end
        pcall(uf.SetParent, uf, (plate and plate.AzPark) or state.hiddenParent)
        pcall(uf.UnregisterAllEvents, uf)
        local cast = uf.castBar or (uf.CastBarsContainer and uf.CastBarsContainer.castBar)
        if cast then pcall(cast.UnregisterAllEvents, cast) end
    end
end

local function AttachBlizzBar(plate, f)
    if not f or f.kind == "friendlyplayer" or f.kind == "friendlynpc" then return end
    local uf = plate and plate.UnitFrame
    local c = uf and uf.HealthBarsContainer
    if not c or c.AzNoAttach or (c.IsForbidden and c:IsForbidden()) or (_G.InCombatLockdown() and c.IsProtected and c:IsProtected()) then return end
    local target = (f.health and f.health:IsShown()) and f.health or f
    local ok = pcall(function()
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
        c:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
    end)
    if not ok then c.AzNoAttach = true end
end

local function RestoreBlizz(plate)
    local uf = plate and plate.UnitFrame
    if not uf then return end
    if uf.AzSilenced then
        uf.AzSilenced = nil
        pcall(uf.SetParent, uf, plate)
    end
    uf:SetAlpha(1)
    if not uf:IsProtected() then uf:Show() end
    local wc = uf.WidgetContainer
    if wc and wc.AzMoved and not (wc.IsForbidden and wc:IsForbidden()) then
        wc.AzMoved = nil
        pcall(function()
            wc:SetParent(uf); wc:ClearAllPoints()
            wc:SetPoint("TOP", uf.CastBarsContainer or uf, "BOTTOM", 0, 0)
        end)
    end
end

local function HookBlizzUF(plate)
    local uf = plate.UnitFrame
    if not uf or state.hookedUF[uf] then return end
    state.hookedUF[uf] = true
    uf.AzNPPlate = plate
    _G.hooksecurefunc(uf, "Show", function(self) SuppressBlizz(self) end)
    if uf.UpdateAnchors then
        _G.hooksecurefunc(uf, "UpdateAnchors", function(self)
            local p = self.AzNPPlate
            local f = p and p.UnitFrame == self and p.AzNPFrame
            if f and f.active and ShouldHideBlizz(p) then AttachBlizzBar(p, f) end
        end)
    end
    _G.hooksecurefunc(uf, "SetAlpha", function(self, a)
        if not NP.IsSecret(a) and a ~= 0 and ShouldHideBlizz(self.AzNPPlate) then self:SetAlpha(0) end
    end)
end

-- Geometria de clique e empilhamento
local function ApplyGeometry(f, unit, blizzMode)
    local plate = f.plate
    if not (plate and plate.SetStackingBoundsFrame) then return end
    local g = NP.db.general
    local friendly = (f.kind == "friendlyplayer" or f.kind == "friendlynpc")
    local w = friendly and g.friendlyClickWidth or g.clickWidth
    local h = friendly and g.friendlyClickHeight or g.clickHeight
    local sw = friendly and g.friendlyStackWidthScale or g.stackWidthScale
    local sh = friendly and g.friendlyStackHeightScale or g.stackHeightScale
    if friendly and not blizzMode and f.cfg and f.cfg.mode ~= "nameOnly" and type(f.cfg.healthWidth) == "number" then
        w = max(w, f.cfg.healthWidth + 4)
        h = max(h, (tonumber(f.cfg.healthHeight) or 12) + 12)
    end
    if not f.stackFrame then
        f.stackFrame = _G.CreateFrame("Frame", nil, plate); f.stackFrame:EnableMouse(false)
        f.stackFrame.tex = f.stackFrame:CreateTexture(nil, "BACKGROUND"); f.stackFrame.tex:SetAllPoints()
        f.hitFrame = _G.CreateFrame("Frame", nil, plate); f.hitFrame:EnableMouse(false)
        f.hitFrame.tex = f.hitFrame:CreateTexture(nil, "BACKGROUND"); f.hitFrame.tex:SetAllPoints()
    end
    local ox, oy = 0, 0
    if not blizzMode and f.cfg and f.cfg.mode ~= "nameOnly" then
        ox, oy = f.cfg.healthOffsetX or 0, f.cfg.healthOffsetY or 0
    end
    local sc = (not blizzMode and f:GetScale()) or 1
    f.stackFrame:SetParent(plate); f.hitFrame:SetParent(plate)
    f.stackFrame:SetScale(sc); f.hitFrame:SetScale(sc)
    local clickY = (not blizzMode and not friendly) and (tonumber(g.clickOffsetY) or 0) or 0
    local stackY = (not blizzMode and not friendly) and (tonumber(g.stackOffsetY) or 0) or 0
    f.stackFrame:ClearAllPoints(); f.stackFrame:SetPoint("CENTER", plate, "CENTER", ox, oy + stackY)
    if g.stackAuto and not friendly and f.cfg then
        local tall = 4 + ((f.cfg.name and f.cfg.name.size) or 11) + (f.cfg.healthHeight or 14) + (f.cfg.castHeight or 10)
        f.stackFrame:SetSize(f.cfg.healthWidth or w, tall * ((g.stackSpacing or 100) / 100))
    else
        f.stackFrame:SetSize(w * sw, h * sh)
    end
    f.hitFrame:ClearAllPoints(); f.hitFrame:SetPoint("CENTER", plate, "CENTER", ox, oy + clickY)
    f.hitFrame:SetSize(w, h)

    local dbg = g.debugBoxes and not blizzMode
    f.stackFrame.tex:SetColorTexture(0.1, 0.8, 0.1, dbg and 0.35 or 0)
    f.hitFrame.tex:SetColorTexture(0.2, 0.4, 1.0, dbg and 0.25 or 0)
    plate:SetStackingBoundsFrame(f.stackFrame)
    if not blizzMode and plate.CanChangeHitTestPoints and plate:CanChangeHitTestPoints() then
        plate:ClearAllHitTestPoints()
        plate:SetAllHitTestPoints(f.hitFrame)
    end
    if unit and _G.C_NamePlateManager and _G.C_NamePlateManager.SetNamePlateSimplified then
        pcall(_G.C_NamePlateManager.SetNamePlateSimplified, unit, false)
    end
end

-- Criação e ciclo dos elementos
local function BuildEventMap()
    wipe(state.unitEventMap)
    for _, el in ipairs(NP.ElementOrder) do
        for ev, method in pairs(el.unitEvents or {}) do
            state.unitEventMap[ev] = state.unitEventMap[ev] or {}
            state.unitEventMap[ev][#state.unitEventMap[ev] + 1] = { el, method }
        end
    end
end

local function OnUnitEvent(self, event, ...)
    local f = self.owner
    if not f.active then return end
    local handlers = state.unitEventMap[event]
    if not handlers then return end
    for i = 1, #handlers do
        local el, method = handlers[i][1], handlers[i][2]
        local ok, err = pcall(el[method], el, f, event, ...)
        if not ok then Azaath.LogError("NP " .. (el.name or "?") .. ":" .. method .. ": " .. tostring(err)) end
    end
end

local function RegisterUnitEvents(f, unit)
    local ef = f.eventFrame
    ef:UnregisterAllEvents()
    for ev, handlers in pairs(state.unitEventMap) do
        for i = 1, #handlers do
            local el = handlers[i][1]
            if not el.WantsEvent or el:WantsEvent(f, ev) then
                pcall(ef.RegisterUnitEvent, ef, ev, unit)
                break
            end
        end
    end
end

local function CreateNPFrame(plate)
    local f = _G.CreateFrame("Frame", nil, plate)
    f.azOwn = true
    f:SetPoint("CENTER", plate, "CENTER", 0, 0)
    f:SetSize(10, 10)
    f:SetFrameStrata("BACKGROUND")
    f:SetIgnoreParentAlpha(true)
    f.plate = plate
    plate.AzNPFrame = f
    f.eventFrame = _G.CreateFrame("Frame", nil, f)
    f.eventFrame.owner = f
    f.eventFrame:SetScript("OnEvent", OnUnitEvent)
    for _, el in ipairs(NP.ElementOrder) do
        if el.Create then el:Create(f) end
    end
    f:Hide()
    return f
end

function NP.CreatePreviewFrame(parent)
    local f = CreateNPFrame(parent)
    parent.AzNPFrame = nil
    f:SetFrameStrata(parent:GetFrameStrata() or "DIALOG")
    f:SetFrameLevel((parent:GetFrameLevel() or 1) + 12)
    f.isPreview = true; f.active = true
    return f
end

function NP.LayoutFrame(f)
    for _, el in ipairs(NP.ElementOrder) do
        if el.Layout then pcall(el.Layout, el, f) end
    end
    if NP.ApplyDepths then NP.ApplyDepths(f) end
    NP.PixelRound(f)
end

function NP.UpdateFrame(f)
    for _, el in ipairs(NP.ElementOrder) do
        if el.Update then pcall(el.Update, el, f) end
    end
    NP.UpdateAlpha(f)
end

-- Alpha, escala e visibilidade condicional
function NP.Targeted(f) return f.isTarget or f.isSoftTarget or false end

local function SmallPlateScale(f)
    local s = NP.db.general.smallPlates
    if not (s and s.enabled) or not f.unit then return 1 end
    if f.kind == "friendlynpc" then
        if not s.friendlyMinions then return 1 end
        local minion = (_G.UnitIsMinion and NP.Truthy(_G.UnitIsMinion(f.unit), false)) or NP.IsPet(f.unit)
        return minion and max(0.3, min(1, tonumber(s.scale) or 0.7)) or 1
    end
    if f.kind ~= "enemynpc" then return 1 end
    local small = s.minions and _G.UnitIsMinion and NP.Truthy(_G.UnitIsMinion(f.unit), false)
    if not small then
        local c = UnitClassification(f.unit)
        if not NP.IsSecret(c) and c ~= nil then
            if s.minor and c == "minus" then small = true
            elseif s.dungeonNormal and NP.inInstance and not NP.inRaid and (c == "normal" or c == "trivial") then small = true end
        end
    end
    return small and max(0.3, min(1, tonumber(s.scale) or 0.7)) or 1
end

local function DistanceScaleFactor(unit)
    local g = NP.db and NP.db.general
    local ds = g and g.distanceScale
    if not (ds and ds.enabled) or not unit or not _G.UnitDistanceSquared then return 1 end
    local ok, sq = pcall(_G.UnitDistanceSquared, unit)
    if not ok or NP.IsSecret(sq) or type(sq) ~= "number" or sq <= 0 then return ds.max or 1 end
    local dist = math.sqrt(sq)
    local full = max(5, tonumber(ds.fullDist) or 10)
    local mn = tonumber(ds.min) or 0.80
    local mx = tonumber(ds.max) or 1.0
    local maxDist = max(full + 10, tonumber(g.viewDistance) or 60)
    if dist <= full then return mx end
    local t = min(1, (dist - full) / (maxDist - full))
    return mx + (mn - mx) * t
end

local function ApplyScale(f)
    local g = NP.db.general
    local s = (g.globalScale or 1) * SmallPlateScale(f) * DistanceScaleFactor(not f.isPreview and f.unit)
    if NP.Targeted(f) then s = s * (g.targetScale or 1) end
    if f.azScale ~= s then f.azScale = s; f:SetScale(s) end
end

local function WaitsForCombat(f)
    if not NP.db.general.combatOnly or f.isPreview or (f.kind ~= "enemynpc" and f.kind ~= "enemyplayer") or not f.unit then return false end
    if f.isTarget or f.isSoftTarget or f.isMouseover then return false end
    local c = UnitAffectingCombat(f.unit)
    return not NP.IsSecret(c) and c == false
end

local function FriendlyHidden(f)
    local g = NP.db.general
    if f.isPreview or (f.kind ~= "friendlyplayer" and f.kind ~= "friendlynpc") then return false end
    if f.isTarget or f.isSoftTarget or f.isMouseover then return false end
    if f.kind == "friendlyplayer" and g.friendlyOnlyFocused then return true end
    if g.friendlyOnlyGroup and not g.friendlyGroupOrHurt and f.kind == "friendlyplayer" and f.unit and not NP.IsGroupMate(f.unit) then return true end
    if f.kind == "friendlynpc" and g.friendlyNpcHidePets and f.unit and NP.IsPet(f.unit) and not NP.Truthy(UnitIsUnit(f.unit, "pet"), false) then return true end
    if f.kind == "friendlynpc" and (g.friendlyNpcImportant or g.friendlyNpcOnlyFocused) then
        if g.friendlyNpcImportant and f.unit and ((NP.DetectNPCUtility and NP.DetectNPCUtility(f.unit)) or (NP.IsMyQuestUnit and NP.IsMyQuestUnit(f.unit))) then
            return false
        end
        return true
    end
    return false
end

local function DeadHidden(f)
    if f.isPreview or not f.unit or (f.kind ~= "enemynpc" and f.kind ~= "friendlynpc") then return false end
    if NP.db.general.hideDead == false or not UnitIsDead then return false end
    return NP.Truthy(UnitIsDead(f.unit), false)
end

local function FriendlyHurt(unit)
    local hp, mx = _G.UnitHealth(unit), _G.UnitHealthMax(unit)
    if NP.IsSecret(hp) or NP.IsSecret(mx) or type(hp) ~= "number" or type(mx) ~= "number" or mx <= 0 then return nil end
    return hp < mx
end

function NP.UpdateAlpha(f)
    local g = NP.db.general
    local walls = g.fadeOccluded and not f.isPreview or false
    f:SetIgnoreParentAlpha(not walls)
    if WaitsForCombat(f) or FriendlyHidden(f) or DeadHidden(f) then
        if f.azAlpha ~= 0 then f.azAlpha = 0; f:SetAlpha(0) end
        return
    end
    local a = 1
    if f.isTarget or f.isSoftTarget then a = g.targetAlpha
    elseif NP.targetPlate then
        if f.kind == "friendlyplayer" or f.kind == "friendlynpc" then a = tonumber(g.friendlyNonTargetAlpha) or 1
        elseif g.nonTargetAlphaEnabled and (not g.fadeInstancesOnly or NP.inInstance) then a = g.nonTargetAlpha end
    elseif not g.fadeInstancesOnly or NP.inInstance then a = g.noTargetAlpha end

    if f.kind == "friendlynpc" and f.cfg and f.cfg.mode == "nameOnly" and not (f.isTarget or f.isSoftTarget) then
        a = min(a, tonumber(g.friendlyNpcNameAlpha) or 1)
    end
    if f.outOfRange then
        local rf = g.rangeFade
        if not (f.isTarget or f.isSoftTarget) then a = min(a, tonumber(rf and rf.alpha) or 0.35)
        elseif f.isTarget and rf and rf.target then a = min(a, tonumber(rf.targetAlpha) or 0.6) end
    end
    if f.isMouseover and g.mouseoverFullAlpha then a = 1 end
    if f.kind == "friendlyplayer" and g.friendlyOnlyHurt and not (f.isTarget or f.isSoftTarget or f.isMouseover) then
        if FriendlyHurt(f.unit) == false then a = 0 end
    end
    local ch = NP.Prof(f).extras.castHighlight
    if f.isCasting and ch.enabled and a < 1 and (f.kind == "enemynpc" or f.kind == "enemyplayer") then
        local imp = f.cast and f.cast.isImportant
        if not ch.importantOnly or not _G.C_Spell.IsSpellImportant then a = 1
        elseif NP.IsSecret(imp) and _G.C_CurveUtil then
            f.azAlpha = nil; f:SetAlpha(NP.EvalBool(imp, 1, a)); return
        elseif imp then a = 1 end
    end
    if f.azAlpha ~= a then f.azAlpha = a; f:SetAlpha(a) end
end

-- Decisão dinâmica de configuração da unidade (modo completo / nameOnly / OOC)
local function CombatNameCfg(cfg, base)
    local cn = cfg.combatName
    if not (cn and cn.own) then
        local pc = NP.CopyTable(cfg); pc.mode = "nameOnly"
        if base and base.name then pc.name = base.name end
        return pc, false
    end
    local c = NP.CopyTable(cfg); c.mode = "nameOnly"
    c.name.size = tonumber(cn.nameSize) or c.name.size
    c.name.anchor = { side = 10, x = tonumber(cn.nameX) or 0, y = tonumber(cn.nameY) or 0 }
    if cn.nameColorMode == "reaction" then c.name.reactionTint, c.name.useClassColor = true, false
    elseif cn.nameColorMode == "color" then c.name.reactionTint, c.name.useClassColor = false, false; c.name.color = cn.nameColor or c.name.color end
    c.eliteIcon.enabled = cn.eliteShow and true or false
    c.eliteIcon.size = tonumber(cn.eliteSize) or 14
    c.eliteIcon.anchor = NP.CopyTable(cn.eliteAnchor or c.eliteIcon.anchor)
    c.level.enabled = cn.levelShow and true or false
    c.level.size = tonumber(cn.levelSize) or 10
    c.level.onName = true
    c.level.nameAnchor = NP.CopyTable(cn.levelAnchor or c.level.nameAnchor)
    return c, true
end

local function ResolveUnitCfg(f, unit, kind)
    local g = NP.db.general
    local cfg = NP.db.units[kind]
    local profKind = kind
    f.azCombatName, f.azCombatOwn = nil, nil

    if kind == "friendlyplayer" and cfg.mode == "nameOnly" then
        local full = (g.friendlyFullOnTarget and f.isTarget)
            or (g.friendlyFullInCombat and NP.Truthy(UnitAffectingCombat(unit), false))
            or (g.friendlyFullGroup and NP.IsGroupMate(unit))
            or (g.friendlyFullWhenHurt and not (g.friendlyHurtNotResting and _G.IsResting and _G.IsResting()) and FriendlyHurt(unit) == true)
        if full then profKind = "friendlyplate"; cfg = NP.db.units.friendlyplate end
    elseif (kind == "enemynpc" or kind == "enemyplayer") and cfg.mode == "full" and cfg.nameOnlyUntilCombat then
        local inCbt = NP.Truthy(UnitAffectingCombat(unit), true)
        local onlyHostile = (kind == "enemynpc" and cfg.nameOnlyHostileOnly)
        local blockedInst = (cfg.nameOnlyNotInstances and NP.inInstance)
        local react = NP.Plain(UnitReaction(unit, "player"), 4) or 4
        if not inCbt and not blockedInst and (not onlyHostile or react <= 3) and not NP.CastFullWanted(f) then
            local ooc = NP.OOC_OF[kind]
            profKind = ooc
            local base = cfg
            cfg, f.azCombatOwn = CombatNameCfg(NP.db.units[ooc], base)
            f.azCombatName = true
        end
    end
    return cfg, profKind
end

function NP.PreviewFrame(f, kind, st)
    local profKind = kind
    kind = NP.NAME_ONLY_OF[kind] or kind
    f.kind = kind
    f.profKind = (profKind ~= kind) and profKind or nil
    f.cfg = NP.previewProfile and NP.previewProfile.units[profKind] or NP.db.units[profKind]
    f.azCombatName, f.azCombatOwn = nil, nil
    if st.ooc and (kind == "enemynpc" or kind == "enemyplayer") then
        local ooc = NP.OOC_OF[kind]
        f.profKind = ooc
        f.cfg, f.azCombatOwn = CombatNameCfg(NP.previewProfile and NP.previewProfile.units[ooc] or NP.db.units[ooc], f.cfg)
        f.azCombatName = true
    end
    f.unitTypeKey = st.boss and "boss" or "elite"
    f.hostile = kind:find("enemy") and true or false
    f.isCasting = st.casting
    f.azSelected = st.selected
    NP.LayoutFrame(f)
    for _, el in ipairs(NP.ElementOrder) do
        if el.Preview then pcall(el.Preview, el, f, st) end
    end
    if NP.ApplyDepths then NP.ApplyDepths(f) end
    f:SetAlpha(1); f.azAlpha = 1; f:Show()
end

-- Entrada / saída de placas
function M:OnUnitAdded(unit)
    if not (NP.db and NP.db.general.enabled) or Azaath.IsBlizzPlates() then return end
    if UnitIsUnit and UnitIsUnit(unit, "player") then return end
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate then return end
    if IsGameObjectUnit(unit) then
        if plate.AzNPFrame then
            plate.AzNPFrame.active = false
            plate.AzNPFrame:Hide()
        end
        return
    end

    local kind = GetUnitKind(unit)
    local f = plate.AzNPFrame or CreateNPFrame(plate)
    f.unit, f.kind, f.active = unit, kind, true
    f.isTarget = NP.Truthy(UnitIsUnit(unit, "target"), false)
    f.isFocus = NP.Truthy(UnitIsUnit(unit, "focus"), false)
    f.isMouseover = NP.Truthy(UnitIsUnit(unit, "mouseover"), false)
    f.isSoftTarget = NP.Truthy((UnitIsUnit(unit, "softenemy") or UnitIsUnit(unit, "softfriend") or UnitIsUnit(unit, "softinteract")), false)
    if f.isTarget then NP.targetPlate = plate end
    if f.isFocus then NP.focusPlate = plate end
    if f.isMouseover then NP.mouseoverPlate = plate end
    if f.isSoftTarget then NP.softPlate = plate end

    local cfg, profKind = ResolveUnitCfg(f, unit, kind)
    f.cfg, f.profKind = cfg, (profKind ~= kind) and profKind or nil
    NP.ActivePlates[unit] = f

    if cfg.mode == "blizzard" then
        f:Hide(); RestoreBlizz(plate)
        ApplyGeometry(f, unit, true)
        return
    end

    HookBlizzUF(plate)
    SuppressBlizz(plate.UnitFrame, plate)

    f.hostile = NP.Truthy(UnitCanAttack("player", unit), false)
    f.unitTypeKey = (kind == "enemynpc") and NP.UnitTypeKey(unit) or nil
    f.isCaster = (kind == "enemynpc" and NP.db.colors.caster.detectByMana and NP.HasMana(unit)) or false
    NP.UpdateNpcID(f)
    if kind == "enemynpc" and NP.IsMyQuestUnit then
        f.isQuest, f.questText, f.questKind = NP.IsMyQuestUnit(unit)
    else
        f.isQuest, f.questText, f.questKind = false, nil, nil
    end

    local enemy = (kind == "enemynpc" or kind == "enemyplayer") and NP.db.general.enemiesOnTop
    f:SetFrameStrata(enemy and "MEDIUM" or "BACKGROUND")
    ApplyScale(f)
    NP.LayoutFrame(f)
    RegisterUnitEvents(f, unit)
    NP.RangeCheckPlate(f)
    f:Show()
    NP.UpdateFrame(f)
    AttachBlizzBar(plate, f)
    ApplyGeometry(f, unit, false)
    if NP.RP then NP.RP.OnPlateAdded(f) end
end

function M:OnUnitRemoved(unit)
    local f = NP.ActivePlates[unit]
    if not f then return end
    NP.ActivePlates[unit] = nil
    f.active = false
    f.eventFrame:UnregisterAllEvents()
    for _, el in ipairs(NP.ElementOrder) do
        if el.Clear then pcall(el.Clear, el, f) end
    end
    if NP.RP then NP.RP.Forget(unit) end
    if NP.targetPlate == f.plate then NP.targetPlate = nil end
    if NP.focusPlate == f.plate then NP.focusPlate = nil end
    if NP.mouseoverPlate == f.plate then NP.mouseoverPlate = nil end
    if NP.softPlate == f.plate then NP.softPlate = nil end
    f.unit = nil
    f:Hide()
end

-- Atualização de alvo, foco, mouseover e combate
local function UpdateTargetFocus()
    local newT = C_NamePlate.GetNamePlateForUnit("target")
    local newF = C_NamePlate.GetNamePlateForUnit("focus")
    NP.targetPlate, NP.focusPlate = newT, newF
    for _, f in pairs(NP.ActivePlates) do
        if f.active then
            local wasT, wasF = f.isTarget, f.isFocus
            f.isTarget = (f.plate == newT)
            f.isFocus = (f.plate == newF)
            if wasT ~= f.isTarget or wasF ~= f.isFocus then
                ApplyScale(f)
                for _, el in ipairs(NP.ElementOrder) do
                    if el.OnTargetChanged then pcall(el.OnTargetChanged, el, f) end
                end
                if f.kind == "friendlyplayer" and NP.db.general.friendlyFullOnTarget then
                    M:OnUnitRemoved(f.unit); M:OnUnitAdded(f.unit)
                end
            end
            NP.UpdateAlpha(f)
        end
    end
end

local function UpdateSoftTarget()
    local newS = C_NamePlate.GetNamePlateForUnit("softenemy")
        or C_NamePlate.GetNamePlateForUnit("softfriend")
        or C_NamePlate.GetNamePlateForUnit("softinteract")
    if newS == NP.softPlate then return end
    local oldS = NP.softPlate
    NP.softPlate = newS
    for _, p in ipairs({ oldS or false, newS or false }) do
        local f = p and p.AzNPFrame
        if f and f.active then
            f.isSoftTarget = (p == newS)
            ApplyScale(f)
            for _, el in ipairs(NP.ElementOrder) do
                if el.OnTargetChanged then pcall(el.OnTargetChanged, el, f) end
            end
            if NP.UpdateSoftIcon then NP.UpdateSoftIcon(f) end
            NP.UpdateAlpha(f)
        end
    end
end

local function UpdateMouseover()
    local newM = (_G.UnitExists and _G.UnitExists("mouseover")) and C_NamePlate.GetNamePlateForUnit("mouseover") or nil
    local oldM = NP.mouseoverPlate
    if newM == oldM then return end
    NP.mouseoverPlate = newM
    for _, p in ipairs({ oldM or false, newM or false }) do
        local f = p and p.AzNPFrame
        if f and f.active then
            f.isMouseover = (p == newM)
            NP.UpdateHealthBorder(f)
            NP.UpdateAlpha(f)
        end
    end
end

local function EnsureCombatTicker()
    if state.combatTicker then return end
    state.combatTicker = _G.C_Timer.NewTicker(0.15, function()
        if not (NP.db and NP.db.general.enabled) or Azaath.IsBlizzPlates() then return end
        if NP.mouseoverPlate and not (_G.UnitExists and _G.UnitExists("mouseover")) then
            UpdateMouseover()
        end
        local dsOn = NP.db.general.distanceScale and NP.db.general.distanceScale.enabled
        for _, f in pairs(NP.ActivePlates) do
            if f.active and f.unit then
                if dsOn then ApplyScale(f) end
                if f.kind == "enemynpc" or f.kind == "enemyplayer" then
                    local th = NP.db.colors and NP.db.colors.threat
                    local curTh = (th and th.enabled) and NP.GetThreatColor(f.unit, th) or nil
                    if f.azPollThreat ~= curTh then
                        f.azPollThreat = curTh
                        if NP.UpdateHealthColor then NP.UpdateHealthColor(f) end
                        if NP.UpdateNameText then NP.UpdateNameText(f) end
                    end
                end
                local cfg = NP.db.units[f.kind]
                if f.kind == "friendlyplayer" and cfg and cfg.mode == "nameOnly" then
                    local nextCfg, nextProf = ResolveUnitCfg(f, f.unit, f.kind)
                    if (nextProf ~= f.kind) ~= (f.profKind ~= nil) then
                        local u = f.unit; M:OnUnitRemoved(u); M:OnUnitAdded(u)
                    end
                elseif (f.kind == "enemynpc" or f.kind == "enemyplayer") and cfg and cfg.mode == "full" and cfg.nameOnlyUntilCombat then
                    local nextCfg = ResolveUnitCfg(f, f.unit, f.kind)
                    if (nextCfg.mode == "nameOnly") ~= (f.cfg.mode == "nameOnly") then
                        local u = f.unit; M:OnUnitRemoved(u); M:OnUnitAdded(u)
                    end
                end
            end
        end
    end)
end

-- CVars e tamanhos de placa no cliente
local function SetCVarSafe(name, value)
    local ok, cur = pcall(_G.C_CVar and _G.C_CVar.GetCVar or _G.GetCVar, name)
    if ok and cur ~= nil and tostring(cur) == tostring(value) then return end
    if _G.C_CVar and _G.C_CVar.SetCVar then pcall(_G.C_CVar.SetCVar, name, value)
    elseif _G.SetCVar then pcall(_G.SetCVar, name, value) end
end

local WORLD_NAME_CVARS = {
    "UnitNameFriendlyPlayerName", "UnitNameFriendlyPetName",
    "UnitNameFriendlyGuardianName", "UnitNameFriendlyTotemName",
}

function NP.ApplyWorldNames()
    local g = NP.db and NP.db.general
    if not g then return end
    local on = g.enabled and not Azaath.IsBlizzPlates()
    if on and g.hideWorldNames then
        for _, n in ipairs(WORLD_NAME_CVARS) do SetCVarSafe(n, "0") end
    end
end

function M:ApplyNamePlateSize()
    if Azaath.IsBlizzPlates() or (_G.InCombatLockdown and _G.InCombatLockdown()) or not C_NamePlate then return end
    local g = NP.db.general
    if C_NamePlate.SetNamePlateEnemySize then pcall(C_NamePlate.SetNamePlateEnemySize, g.clickWidth or 172, g.clickHeight or 26) end
    if C_NamePlate.SetNamePlateFriendlySize then pcall(C_NamePlate.SetNamePlateFriendlySize, g.friendlyClickWidth or 110, g.friendlyClickHeight or 28) end
    if C_NamePlate.SetNamePlateEnemyClickThrough then pcall(C_NamePlate.SetNamePlateEnemyClickThrough, false) end
    if C_NamePlate.SetNamePlateFriendlyClickThrough then
        local click = g.friendlyClickable ~= false
        pcall(C_NamePlate.SetNamePlateFriendlyClickThrough, not click)
        SetCVarSafe("namePlateFriendlyClickThrough", click and "0" or "1")
    end
end

function M:ApplyCVars()
    if Azaath.IsBlizzPlates() or (_G.InCombatLockdown and _G.InCombatLockdown()) then return end
    local g = NP.db.general
    if not g.applyCVars then return end
    local c = g.cvars
    SetCVarSafe("nameplateMaxDistance", tostring(g.viewDistance or c.nameplateMaxDistance or 60))
    SetCVarSafe("nameplateMotion", g.stackEnemies and "1" or "0")
    SetCVarSafe("nameplateOverlapH", tostring(g.overlapH or 1.1))
    SetCVarSafe("nameplateOverlapV", tostring(g.overlapV or 1.2))
    SetCVarSafe("nameplateSelectedScale", tostring(g.targetScale or 1.2))
    SetCVarSafe("nameplateShowOffscreen", g.showOffscreen and "1" or "0")
    SetCVarSafe("nameplateShowEnemies", "1")
    SetCVarSafe("nameplateShowFriends", "1")
    SetCVarSafe("nameplateShowFriendlyPlayers", "1")
    SetCVarSafe("nameplateShowFriendlyNPCs", (g.utilityNPCs ~= false) and "1" or "0")
    SetCVarSafe("nameplateShowFriendlyMinions", "1")
    SetCVarSafe("nameplateOccludedAlphaMult", g.fadeOccluded and tostring(g.occludedAlpha or 0.4) or "1")
end

function NP.RefreshAll(keepAuraStyle)
    if not NP.db then return end
    NP.RefreshClassColors()
    NP.ComputePlayerRole()
    NP.InvalidateUnitProfiles()
    if not keepAuraStyle then NP.AuraStyleVersion = (NP.AuraStyleVersion or 0) + 1 end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local f = plate.AzNPFrame
        local unit = (f and f.unit) or plate.namePlateUnitToken or plate.unitToken
        if unit then
            M:OnUnitRemoved(unit)
            M:OnUnitAdded(unit)
        end
    end
    M:ApplyNamePlateSize()
    M:ApplyCVars()
    NP.ApplyWorldNames()
    if NP.UpdateRangeFade then NP.UpdateRangeFade() end
    if not keepAuraStyle and NP.AuraContainers and NP.AuraContainers.available then NP.AuraContainers.OnSettingsChanged() end
end
NP.ForEachPlate = function(fn) for _, f in pairs(NP.ActivePlates) do fn(f) end end

-- Eventos globais
local events = _G.CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "NAME_PLATE_UNIT_ADDED" then M:OnUnitAdded(arg1)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then M:OnUnitRemoved(arg1)
    elseif event == "UNIT_FACTION" then if arg1 and arg1:find("^nameplate") then M:OnUnitRemoved(arg1); M:OnUnitAdded(arg1) end
    elseif event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then UpdateTargetFocus()
    elseif event == "PLAYER_SOFT_ENEMY_CHANGED" or event == "PLAYER_SOFT_FRIEND_CHANGED" or event == "PLAYER_SOFT_INTERACT_CHANGED" then UpdateSoftTarget()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then UpdateMouseover()
    elseif event == "GROUP_ROSTER_UPDATE" or event == "ACTIVE_TALENT_GROUP_CHANGED" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        NP.MarkGroupTanksDirty(); NP.UpdatePlayerRole()
    elseif event == "INSTANCE_ENCOUNTER_ENGAGE_UNIT" then
        if NP.UpdateEncounterUnits() then NP.RefreshAll(true) end
    elseif event == "PLAYER_REGEN_ENABLED" then
        M:ApplyNamePlateSize(); M:ApplyCVars()
        for _, f in pairs(NP.ActivePlates) do if f.active then NP.UpdateAlpha(f) end end
    elseif event == "PLAYER_REGEN_DISABLED" then
        for _, f in pairs(NP.ActivePlates) do if f.active then NP.UpdateAlpha(f) end end
    elseif event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        NP.UpdateInstanceState(); NP.UpdateEncounterUnits(); NP.ApplyWorldNames()
        _G.C_Timer.After(0.4, function() NP.RefreshAll(true) end)
    end
end)

-- API pública esperada pelo AzaathUI (Options.lua / Core.lua)
function M:OnInitialize()
    NP.InitDatabase()
    BuildEventMap()
end

function M:OnEnable()
    NP.UpdateInstanceState()
    NP.ComputePlayerRole()
    NP.ScanExecute()
    NP.ApplyWorldNames()
    M:ApplyNamePlateSize()
    M:ApplyCVars()
    if not (NP.db and NP.db.general.enabled) or Azaath.IsBlizzPlates() then return end
    for _, ev in ipairs({
        "NAME_PLATE_UNIT_ADDED", "NAME_PLATE_UNIT_REMOVED", "UNIT_FACTION",
        "PLAYER_TARGET_CHANGED", "PLAYER_FOCUS_CHANGED", "UPDATE_MOUSEOVER_UNIT",
        "PLAYER_SOFT_ENEMY_CHANGED", "PLAYER_SOFT_FRIEND_CHANGED", "PLAYER_SOFT_INTERACT_CHANGED",
        "GROUP_ROSTER_UPDATE", "PLAYER_SPECIALIZATION_CHANGED",
        "INSTANCE_ENCOUNTER_ENGAGE_UNIT", "PLAYER_REGEN_ENABLED", "PLAYER_REGEN_DISABLED",
        "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA",
    }) do Azaath.SafeRegister(events, ev) end
    EnsureCombatTicker()
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local u = plate.namePlateUnitToken or plate.unitToken
        if u then M:OnUnitAdded(u) end
    end
end

function M:Apply()
    NP.RefreshAll()
end

function M:ApplyLayout()
    NP.RefreshAll()
end

function M:Test()
    local tested = 0
    for _, f in pairs(NP.ActivePlates) do
        if f.active and f.cast and not f.cast.disabled then
            local cb = f.cast
            cb.ended = false; cb.channeling = false; cb.notInterruptible = false; cb.isImportant = true
            cb:SetAlpha(1); cb:SetMinMaxValues(0, 1); cb.kickFrame:SetMinMaxValues(0, 1)
            cb.previewAnim = true; cb.previewT = 0
            cb:SetStatusBarColor(NP.RGBA(NP.Prof(f).cast.colors.important))
            cb.icon:SetTexture("Interface\\Icons\\Spell_Fire_FlameBolt")
            cb.spellName:SetText("Bola de Fogo (Teste)")
            cb.target:SetText("Tanque")
            cb:Show()
            tested = tested + 1
        end
    end
    if tested > 0 then
        Azaath:Print(("Barra de conjuração exibida em %d placa(s) ativa(s) para teste."):format(tested))
    else
        Azaath:Print("Nenhuma placa visível no momento. Abrindo o Designer Visual para visualização.")
        if NP.OpenDesigner then NP.OpenDesigner() end
    end
end

function M:OpenDesigner()
    if NP.OpenDesigner then NP.OpenDesigner() end
end

-- Comandos de barra (/azplates, /np)
_G.SLASH_AZAATHNP1 = "/azplates"
_G.SLASH_AZAATHNP2 = "/np"
_G.SlashCmdList["AZAATHNP"] = function(msg)
    local cmd, rest = (msg or ""):match("^%s*(%S*)%s*(.*)$")
    cmd = (cmd or ""):lower()
    if cmd == "refresh" then
        NP.RefreshAll(); Azaath:Print("Placas recarregadas.")
    elseif cmd == "cvars" then
        M:ApplyCVars(); M:ApplyNamePlateSize(); Azaath:Print("CVars das placas aplicadas.")
    elseif cmd == "color" then
        local id = _G.UnitExists("target") and NP.NpcID("target")
        if not id then Azaath:Print("Selecione um NPC fora de instância para definir cor personalizada."); return end
        local colMap = {
            red = { 1, 0.2, 0.2, 1 }, aqua = { 0, 1, 1, 1 }, gold = { 1, 0.84, 0, 1 },
            purple = { 0.72, 0.35, 1, 1 }, green = { 0.2, 0.9, 0.35, 1 }, pink = { 1, 0.35, 0.85, 1 },
        }
        if rest == "clear" or rest == "off" then
            NP.db.colors.world.npcs[id] = nil
            Azaath:Print("Cor personalizada removida do NPC " .. id)
        else
            local c = colMap[(rest or ""):lower()] or NP.db.colors.world.custom.newColor
            NP.db.colors.world.enabled = true
            NP.db.colors.world.custom.enabled = true
            NP.db.colors.world.npcs[id] = { name = _G.UnitName("target") or tostring(id), color = NP.CopyTable(c) }
            Azaath:Print("Cor aplicada ao NPC " .. id .. " (" .. (_G.UnitName("target") or "") .. ")")
        end
        NP.RefreshAll(true)
    elseif cmd == "perf" then
        if NP.Perf.on then NP.Perf.on = false; Azaath:Print("Profiler encerrado."); return end
        wipe(NP.Perf.data); NP.Perf.on = true
        Azaath:Print("Medindo desempenho das placas por 10s...")
        _G.C_Timer.After(10, function()
            NP.Perf.on = false
            local rows, tot = {}, 0
            for k, e in pairs(NP.Perf.data) do rows[#rows + 1] = { k, e[1], e[2] }; tot = tot + e[2] end
            table.sort(rows, function(a, b) return a[3] > b[3] end)
            Azaath:Print(("Nameplates: %.2f ms/s total"):format(tot / 10))
            for i = 1, min(8, #rows) do
                Azaath:Print(("  %d. %s: %.2f ms/s (%d chamadas)"):format(i, rows[i][1], rows[i][3] / 10, rows[i][2]))
            end
        end)
    else
        if NP.OpenDesigner then NP.OpenDesigner() end
    end
end
