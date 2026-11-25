--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Colors.lua
    Regras de cor das barras de vida e nomes: reação, ameaça (Tank/DPS),
    conjurador, tipo de unidade (boss/miniboss/elite/trivial), mundo aberto,
    missões, ociosos, reputação e cores sociais.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, tonumber, type = pairs, ipairs, pcall, tonumber, type
local wipe = wipe

local UnitIsTapDenied        = _G.UnitIsTapDenied
local UnitIsPlayer           = _G.UnitIsPlayer
local UnitReaction           = _G.UnitReaction
local UnitClass              = _G.UnitClass
local UnitThreatSituation    = _G.UnitThreatSituation
local UnitAffectingCombat    = _G.UnitAffectingCombat
local UnitClassification     = _G.UnitClassification
local UnitLevel              = _G.UnitLevel
local UnitCanAttack          = _G.UnitCanAttack
local UnitIsBossMob          = _G.UnitIsBossMob
local UnitIsLieutenant       = _G.UnitIsLieutenant
local UnitIsWildBattlePet    = _G.UnitIsWildBattlePet
local UnitPowerType          = _G.UnitPowerType
local UnitPowerMax           = _G.UnitPowerMax
local UnitGroupRolesAssigned = _G.UnitGroupRolesAssigned

NP.CLASS_COLORS = {}
local classColorObjs = {}

function NP.RefreshClassColors()
    local src = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS or {}
    for cls, c in pairs(src) do
        local t = NP.CLASS_COLORS[cls]
        if not t then t = {}; NP.CLASS_COLORS[cls] = t end
        t[1], t[2], t[3], t[4] = c.r, c.g, c.b, 1
    end
    local cols = NP.db and NP.db.colors and NP.db.colors.classColors
    for cls, c in pairs(cols or {}) do
        local t = NP.CLASS_COLORS[cls]
        if t and type(c) == "table" then
            t[1], t[2], t[3], t[4] = c[1] or t[1], c[2] or t[2], c[3] or t[3], 1
        end
    end
    wipe(classColorObjs)
end
NP.RefreshClassColors()

function NP.ClassColorObj(cls)
    if cls == nil then return nil end
    if not NP.IsSecret(cls) then
        if cls == "" then return nil end
        local t = NP.CLASS_COLORS[cls]
        if t then
            local o = classColorObjs[cls]
            if not o then o = _G.CreateColor(t[1], t[2], t[3], 1); classColorObjs[cls] = o end
            return o
        end
    end
    local CC = _G.C_ClassColor
    if not (CC and CC.GetClassColor) then return nil end
    local ok, col = pcall(CC.GetClassColor, cls)
    if ok and type(col) == "table" and col.GetRGB then return col end
    return nil
end

function NP.ClassColorFromToken(cls)
    if NP.IsSecret(cls) then
        local CC = _G.C_ClassColor
        if not (CC and CC.GetClassColor) then return nil end
        local ok, col = pcall(CC.GetClassColor, cls)
        if not ok or type(col) ~= "table" or not col.GetRGB then return nil end
        local r, g, b = col:GetRGB()
        return { r, g, b, 1 }
    end
    return cls and NP.CLASS_COLORS[cls] or nil
end

function NP.GetClassColor(unit)
    local _, cls = UnitClass(unit)
    return NP.ClassColorFromToken(cls)
end

function NP.MyClassColor(fallback, use)
    if not use then return fallback end
    local _, cls = UnitClass("player")
    return NP.ClassColorFromToken(cls) or fallback
end

NP.inInstance = false
NP.inRaid = false
function NP.UpdateInstanceState()
    local inInst, instType = _G.IsInInstance()
    NP.inInstance = inInst and (instType == "party" or instType == "raid" or instType == "scenario") or false
    NP.inRaid = inInst and instType == "raid" or false
end

function NP.IsCasterHere(frame)
    if not frame.isCaster then return false end
    local c = NP.db and NP.db.colors and NP.db.colors.caster
    return c and (NP.inInstance or not c.instancesOnly) or false
end

local function EffectiveLevel(unit)
    local l = _G.UnitEffectiveLevel and _G.UnitEffectiveLevel(unit) or UnitLevel(unit)
    if NP.IsSecret(l) then return nil end
    return l
end

-- Função (Tank vs DPS) e tanques do grupo
NP.playerIsTank = false
local tanksDirty = true
local function HasTankAura()
    if not _G.UnitHasEffectivelyTankAura then return nil end
    local ok, v = pcall(_G.UnitHasEffectivelyTankAura, "player")
    if not ok or NP.IsSecret(v) then return nil end
    return v and true or false
end

function NP.ComputePlayerRole()
    tanksDirty = true
    local setting = NP.db and NP.db.colors and NP.db.colors.threat and NP.db.colors.threat.role or "auto"
    if setting == "tank" then NP.playerIsTank = true; return end
    if setting == "dps" then NP.playerIsTank = false; return end
    if HasTankAura() then NP.playerIsTank = true; return end
    local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned("player")
    if not NP.IsSecret(role) and role and role ~= "NONE" then
        NP.playerIsTank = (role == "TANK")
        return
    end
    local CS = _G.C_SpecializationInfo
    if CS and CS.GetSpecialization then
        local spec = CS.GetSpecialization()
        if spec and not NP.IsSecret(spec) and spec > 0 then
            local sr = CS.GetSpecializationInfo and select(5, CS.GetSpecializationInfo(spec))
                or (_G.GetSpecializationRole and _G.GetSpecializationRole(spec))
            if sr and not NP.IsSecret(sr) then
                NP.playerIsTank = (sr == "TANK")
                return
            end
        end
    end
    NP.playerIsTank = false
end

function NP.UpdatePlayerRole()
    local was = NP.playerIsTank
    NP.ComputePlayerRole()
    if was ~= NP.playerIsTank and NP.ForEachPlate and NP.UpdateHealthColor then
        NP.ForEachPlate(function(f) if f.active then NP.UpdateHealthColor(f) end end)
    end
end

-- Unidades de encontro (boss1..boss5)
local bossTokens = {}
NP.bossTokens = bossTokens
function NP.UpdateEncounterUnits()
    local changed = false
    for i = 1, 5 do
        local tok = "boss" .. i
        local has = NP.Truthy(_G.UnitExists(tok), false) and tok or nil
        if bossTokens[i] ~= has then bossTokens[i] = has; changed = true end
    end
    return changed
end

function NP.IsEncounterUnit(unit)
    for i = 1, 5 do
        local tok = bossTokens[i]
        if tok and NP.Truthy(_G.UnitIsUnit(tok, unit), false) then return true end
    end
    return false
end

local function Flag(fn, unit)
    if not fn then return false end
    local ok, v = pcall(fn, unit)
    return ok and NP.Truthy(v, false)
end

local function AbovePlayer(unit)
    if not NP.inInstance then return nil end
    local c = UnitClassification(unit)
    if NP.IsSecret(c) or (c ~= "elite" and c ~= "rareelite") then return nil end
    local l, pl = EffectiveLevel(unit), EffectiveLevel("player")
    if type(l) ~= "number" or type(pl) ~= "number" or l <= 0 then return nil end
    return l - pl
end

function NP.IsBoss(unit)
    if Flag(UnitIsBossMob, unit) then return true end
    if UnitClassification(unit) == "worldboss" then return true end
    if bossTokens[1] and NP.IsEncounterUnit(unit) then return true end
    if EffectiveLevel(unit) == -1 then return true end
    local d = AbovePlayer(unit)
    return d ~= nil and d >= 2
end

function NP.IsMiniboss(unit)
    if Flag(UnitIsLieutenant, unit) then return true end
    local d = AbovePlayer(unit)
    if d == nil then return false end
    if NP.inRaid then return d >= 1 end
    return d == 1
end

function NP.UnitTypeKey(unit)
    if NP.IsBoss(unit) then return "boss" end
    if NP.IsMiniboss(unit) then return "miniboss" end
    local c = UnitClassification(unit)
    if c == "minus" or c == "trivial" then return "trivial" end
    if c == "elite" or c == "rareelite" or c == "rare" then return "elite" end
    return nil
end

function NP.HasMana(unit)
    local MANA = _G.Enum and _G.Enum.PowerType and _G.Enum.PowerType.Mana or 0
    if UnitPowerType then
        local pt = UnitPowerType(unit)
        if not NP.IsSecret(pt) and pt == MANA then return true end
    end
    if _G.UnitHasPowerType then
        local ok, has = pcall(_G.UnitHasPowerType, unit, MANA)
        if ok and not NP.IsSecret(has) and has then return true end
    end
    if UnitPowerMax then
        local mx = UnitPowerMax(unit, MANA)
        if not NP.IsSecret(mx) and type(mx) == "number" and mx > 0 then return true end
    end
    return false
end

local RAID_TOKENS, PARTY_TOKENS = {}, {}
for i = 1, 40 do RAID_TOKENS[i] = "raid" .. i end
for i = 1, 4  do PARTY_TOKENS[i] = "party" .. i end
local groupTanks = {}

function NP.MarkGroupTanksDirty() tanksDirty = true end
function NP.PetsAsTanks()
    local t = NP.db and NP.db.colors and NP.db.colors.threat
    return not t or t.petsAsTanks ~= false
end

local function GroupTanks()
    if not tanksDirty then return groupTanks end
    tanksDirty = false
    wipe(groupTanks)
    local list, count, petPrefix
    if _G.IsInRaid() then list, count, petPrefix = RAID_TOKENS, _G.GetNumGroupMembers(), "raidpet"
    elseif _G.IsInGroup() then list, count, petPrefix = PARTY_TOKENS, _G.GetNumSubgroupMembers(), "partypet" end
    local pets = NP.PetsAsTanks()
    if pets and NP.Truthy(_G.UnitExists("pet"), false) then groupTanks[#groupTanks + 1] = "pet" end
    if not list then return groupTanks end
    for i = 1, math.min(count or 0, #list) do
        local member = list[i]
        if list == PARTY_TOKENS or not NP.Truthy(_G.UnitIsUnit(member, "player"), true) then
            local role = UnitGroupRolesAssigned and UnitGroupRolesAssigned(member)
            if not NP.IsSecret(role) and role == "TANK" then groupTanks[#groupTanks + 1] = member end
            if pets then
                local pet = petPrefix .. i
                if NP.Truthy(_G.UnitExists(pet), false) and not NP.Truthy(_G.UnitIsUnit(pet, "pet"), false) then
                    groupTanks[#groupTanks + 1] = pet
                end
            end
        end
    end
    return groupTanks
end

local function GroupTankHasAggro(unit, minStatus)
    minStatus = minStatus or 2
    local tanks = GroupTanks()
    for i = 1, #tanks do
        local s = UnitThreatSituation(tanks[i], unit)
        if not NP.IsSecret(s) and s and s >= minStatus then return true end
    end
    return false
end

local function MobTargetsGroupMate(unit)
    local tu = unit .. "target"
    if not NP.Truthy(_G.UnitExists(tu), false) then return false end
    if NP.Truthy(_G.UnitIsUnit(tu, "player"), false) then return false end
    if not NP.Truthy(UnitIsPlayer(tu), true) and not NP.PetsAsTanks() then return false end
    return NP.IsGroupMate(tu)
end
NP.MobTargetsGroupMate = MobTargetsGroupMate

local function OtherHasAggro(unit)
    if GroupTankHasAggro(unit) then return true end
    local list, count
    if _G.IsInRaid() then list, count = RAID_TOKENS, _G.GetNumGroupMembers()
    elseif _G.IsInGroup() then list, count = PARTY_TOKENS, _G.GetNumSubgroupMembers() end
    if not list then return false end
    local unknown = false
    for i = 1, math.min(count or 0, #list) do
        local m = list[i]
        if NP.Truthy(_G.UnitExists(m), false) then
            local s = UnitThreatSituation(m, unit)
            if NP.IsSecret(s) then unknown = true
            elseif s and s >= 2 and not NP.Truthy(_G.UnitIsUnit(m, "player"), false) then return true end
        end
    end
    return unknown or MobTargetsGroupMate(unit)
end

function NP.GetThreatColor(unit, cfg)
    if not (cfg and cfg.enabled) then return nil end
    if cfg.instancesOnly and not NP.inInstance then return nil end
    local status = UnitThreatSituation("player", unit)
    if NP.IsSecret(status) then status = nil end
    if (status == nil or status < 2) and _G.UnitIsUnit then
        local okT, isT = pcall(_G.UnitIsUnit, unit .. "target", "player")
        if okT and not NP.IsSecret(isT) and isT then
            status = 3
        end
    end
    if status == nil then
        if not NP.Truthy(UnitAffectingCombat(unit), false) then return nil end
        if not NP.playerIsTank and cfg.dps.useTankColor and OtherHasAggro(unit) then return cfg.dps.tank end
        return nil
    end
    if NP.playerIsTank then
        if status == 3 then return cfg.tank.useAggroColor and cfg.tank.aggro or cfg.dps.aggro end
        if GroupTankHasAggro(unit) then return cfg.tank.anothertank end
        if status == 2 then return cfg.tank.pulling end
        return cfg.tank.noaggro
    else
        if status >= 2 then return cfg.dps.aggro end
        if status == 1 then return cfg.dps.pulling end
        if cfg.dps.useTankColor and OtherHasAggro(unit) then return cfg.dps.tank end
        return nil
    end
end

function NP.NpcID(unit)
    if not unit then return nil end
    if _G.C_Secrets and _G.C_Secrets.ShouldUnitIdentityBeSecret and NP.Truthy(_G.C_Secrets.ShouldUnitIdentityBeSecret(unit), true) then
        return nil
    end
    if _G.UnitCreatureID then
        local id = _G.UnitCreatureID(unit)
        if id ~= nil and not NP.IsSecret(id) then return tonumber(id) end
    end
    local guid = _G.UnitGUID(unit)
    if not guid or NP.IsSecret(guid) then return nil end
    local kind, _, _, _, _, id = _G.strsplit("-", guid)
    if kind == "Creature" or kind == "Vehicle" then return tonumber(id) end
    return nil
end

function NP.UpdateNpcID(f)
    if f.kind ~= "enemynpc" or NP.inInstance then f.npcID = nil; return end
    f.npcID = NP.NpcID(f.unit)
end

local function WorldOn(w, key)
    local c = w[key]
    return c and c.enabled and c.color
end

local function WorldColor(frame, w, first)
    if first then
        return frame.isPrey and WorldOn(w, "prey") or nil
    end
    local unit = frame.unit
    if w.custom.enabled and frame.npcID then
        local e = w.npcs and w.npcs[frame.npcID]
        if e and e.color then return e.color end
    end
    local c = UnitClassification(unit)
    if NP.IsSecret(c) then c = nil end
    if c == "worldboss" or (UnitIsBossMob and NP.Truthy(UnitIsBossMob(unit), false)) then
        local col = WorldOn(w, "worldBoss"); if col then return col end
    end
    if c == "rareelite" then
        local col = WorldOn(w, "rareElite") or WorldOn(w, "rare"); if col then return col end
    elseif c == "rare" then
        local col = WorldOn(w, "rare"); if col then return col end
    end
    if w.highLevel.enabled then
        local l, me = EffectiveLevel(unit), EffectiveLevel("player")
        if l and (l == -1 or (me and l >= me + (tonumber(w.highLevel.levels) or 3))) then
            return w.highLevel.color
        end
    end
    if c == "elite" or c == "rareelite" then
        local col = WorldOn(w, "elite"); if col then return col end
    end
    if w.battlePet.enabled and UnitIsWildBattlePet and NP.Truthy(UnitIsWildBattlePet(unit), false) then
        return w.battlePet.color
    end
    return nil
end

local function BaseHealthColor(frame)
    local colors = NP.db.colors
    local unit = frame.unit
    local isPlayer = NP.Truthy(UnitIsPlayer(unit), false)
    local reaction = NP.Plain(UnitReaction(unit, "player"), 4) or 4
    local canAttack = NP.Truthy(UnitCanAttack("player", unit), false)

    local world = not NP.inInstance and colors.world.enabled and colors.world
    if world and frame.isPrey then
        local c = WorldColor(frame, world, true); if c then return c end
    end

    if not isPlayer and UnitIsTapDenied and NP.Truthy(UnitIsTapDenied(unit), false) then
        return colors.tapped
    end

    if canAttack and not isPlayer then
        local threat = (colors.threat.showOn or "bar") == "bar" and NP.GetThreatColor(unit, colors.threat) or nil
        local typeKey = frame.unitTypeKey
        local typeAllowed = colors.unitType.enabled and (NP.inInstance or not colors.unitType.instancesOnly)
        if threat then
            local t, dps = colors.threat.tank, colors.threat.dps
            local special = (typeAllowed and (typeKey == "boss" or typeKey == "miniboss"))
                or (colors.caster.enabled and NP.IsCasterHere(frame))
            local keep = special and ((threat == t.aggro and t.aggroKeepSpecial) or (threat == dps.tank and dps.tankKeepSpecial))
            if not keep then return threat end
        end
        if colors.quest.enabled and not NP.inInstance and frame.isQuest then
            return reaction <= 3 and colors.quest.hostile or colors.quest.neutral
        end
        if colors.caster.enabled and NP.IsCasterHere(frame) and typeKey ~= "boss" and typeKey ~= "miniboss" then
            return colors.caster.color
        end
        if world then
            local c = WorldColor(frame, world); if c then return c end
        end
        if typeAllowed and typeKey then
            if typeKey == "elite" and not colors.unitType.enableElite then typeKey = nil end
            if typeKey == "trivial" and not colors.unitType.enableTrivial then typeKey = nil end
        end
        if typeAllowed and not typeKey and colors.unitType.normalAsTrivial and UnitClassification(unit) == "normal" then
            typeKey = "trivial"
        end
        if typeAllowed and typeKey then return colors.unitType[typeKey] end
    end

    if isPlayer and frame.kind == "friendlyplayer" and frame.cfg and frame.cfg.name and frame.cfg.name.socialOnBar and NP.SocialNameColor then
        local c = NP.SocialNameColor(frame, frame.cfg.name); if c then return c end
    end
    if isPlayer and frame.cfg and frame.cfg.useClassColor then
        local c = NP.GetClassColor(unit); if c then return c end
    end
    if reaction <= 3 then return colors.reaction.hostile end
    if reaction == 4 then return colors.reaction.neutral end
    if isPlayer and colors.reaction.friendlyPlayerOn then return colors.reaction.friendlyPlayer end
    return colors.reaction.friendly
end

function NP.NameReputationColor(unit)
    if not unit or NP.Truthy(UnitIsPlayer(unit), true) then return nil end
    if UnitIsTapDenied and NP.Truthy(UnitIsTapDenied(unit), false) then return nil end
    local r = UnitReaction(unit, "player")
    if type(r) ~= "number" or NP.IsSecret(r) then return nil end
    local t = NP.db.colors.reputation
    return t and t["r" .. r] or nil
end

function NP.UnitReactionColor(unit)
    local colors = NP.db.colors
    local isPlayer = NP.Truthy(UnitIsPlayer(unit), false)
    if not isPlayer and UnitIsTapDenied and NP.Truthy(UnitIsTapDenied(unit), false) then return colors.tapped end
    local reaction = NP.Plain(UnitReaction(unit, "player"), 4) or 4
    if reaction <= 3 then return colors.reaction.hostile end
    if reaction == 4 then return colors.reaction.neutral end
    return colors.reaction.friendly
end

function NP.NameReactionColor2(unit)
    local colors = NP.db.colors
    local nr = colors.nameReaction
    if not (nr and nr.enabled) then return NP.UnitReactionColor(unit) end
    local isPlayer = NP.Truthy(UnitIsPlayer(unit), false)
    if not isPlayer and UnitIsTapDenied and NP.Truthy(UnitIsTapDenied(unit), false) then return nr.tapped end
    local reaction = NP.Plain(UnitReaction(unit, "player"), 4) or 4
    if reaction <= 3 then return nr.hostile end
    if reaction == 4 then return nr.neutral end
    return nr.friendly
end

function NP.IsIdleMob(frame)
    local unit = frame and frame.unit
    if not unit or frame.kind ~= "enemynpc" then return false end
    local c = UnitAffectingCombat(unit)
    if c == nil or NP.IsSecret(c) or c then return false end
    return NP.Truthy(UnitCanAttack("player", unit), false)
end

function NP.IdleRuleOn(cfg)
    return cfg and cfg.enabled and (NP.inInstance or not cfg.instancesOnly) and true or false
end

local function Darker(frame, c, k)
    local r, g, b, a = NP.RGBA(c)
    if NP.IsSecret(r) then return c end
    local gray = r * 0.3 + g * 0.59 + b * 0.11
    local mix, dark = k * 0.6, 1 - k * 0.55
    local t = frame.idleColor or {}
    frame.idleColor = t
    t[1] = (r + (gray - r) * mix) * dark
    t[2] = (g + (gray - g) * mix) * dark
    t[3] = (b + (gray - b) * mix) * dark
    t[4] = a
    return t
end

function NP.GetHealthColor(frame)
    local c = BaseHealthColor(frame)
    local idle = NP.db.colors.idle
    if NP.IdleRuleOn(idle) and NP.IsIdleMob(frame) then
        if idle.mode == "color" then return idle.color end
        return Darker(frame, c, tonumber(idle.strength) or 0.5)
    end
    return c
end
