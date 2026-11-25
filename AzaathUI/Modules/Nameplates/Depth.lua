--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Depth.lua
    Controle de ordem de camada (FrameLevel) por elemento da placa.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, type = pairs, ipairs, pcall, type
local floor, wipe = math.floor, wipe

local STEP, RANGE = 3, 6
NP.DEPTH_RANGE = RANGE

local function Text(f) return f.textFrame end
local function Ind(f) return f.indicatorFrame end

local PARTS = {
    name          = { home = Text, regions = { "name" }, frames = function(f, out)
        local p = f.nameFill
        if p then out[#out + 1] = p.mask; out[#out + 1] = p.hmask end
    end },
    guild         = { home = Text, regions = { "rpTitle" } },
    healthText    = { home = Text, regions = { "healthText" } },
    level         = { home = Text, regions = { "levelText" } },
    unitTarget    = { home = Text, regions = { "unitTarget" } },
    levelBox      = { frames = function(f, out) out[#out + 1] = f.levelBox end },
    raidMark      = { home = Ind,  regions = { "raidMark" } },
    quest         = { home = Ind,  regions = { "questIcon", "questProgress" } },
    typeIcon      = { home = Ind,  regions = { "typeIcon" } },
    eliteIcon     = { home = Ind,  regions = { "eliteIcon" } },
    serviceIcon   = { home = Ind,  regions = { "serviceIcon" } },
    idleIcon      = { home = Ind,  regions = { "idleIcon" } },
    factionIcon   = { home = Ind,  regions = { "factionIcon" } },
    classIcon     = { home = Ind,  regions = { "classIcon", "classBorder" } },
    threatText    = { home = Ind,  regions = { "threatText", "threatLead" } },
    mplus         = { home = function(f) return f.extrasFrame end, regions = { "mplus" } },
    energy        = { frames = function(f, out) out[#out + 1] = f.energy end },
    cast          = { own = true },
    debuffs       = { row = "debuffRow" },
    buffs         = { row = "buffRow" },
    cc            = { row = "ccRow" },
    friendBuffs   = { row = "friendRow" },
    friendDebuffs = { row = "friendDebuffRow" },
    playerPower   = { own = true },
    playerHealth  = { own = true },
    resources     = { own = true },
    lastSpell     = { own = true },
    executeIcon   = { frames = function(f, out) out[#out + 1] = f.health and f.health.execIcon end, after = function(f)
        if NP.KeepExecTimerOnTop then NP.KeepExecTimerOnTop(f) end
    end },
}
local ALIAS = { castIcon = "cast", castName = "cast", castTimer = "cast", castTarget = "cast", castOnYou = "cast" }

function NP.DepthPart(key)
    key = ALIAS[key] or key
    return PARTS[key] and key or nil
end

function NP.DepthOffset(f, key)
    local d = f and f.cfg and f.cfg.depth
    local v = d and d[key]
    if type(v) ~= "number" then return 0 end
    if v > RANGE then v = RANGE elseif v < -RANGE then v = -RANGE end
    return floor(v + 0.5) * STEP
end

function NP.DepthLevel(f, rel, key)
    local l = f.health:GetFrameLevel() + rel + NP.DepthOffset(f, key)
    return l < 0 and 0 or l
end

local function Level(fr)
    local ok, l = pcall(fr.GetFrameLevel, fr)
    if ok and type(l) == "number" and not NP.IsSecret(l) then return l end
    return nil
end

local function SetLevelDeep(fr, level, depth)
    local old = Level(fr)
    if not old or old == level then return end
    local kids, before
    if depth < 4 and fr.GetChildren then
        kids, before = { fr:GetChildren() }, {}
        for i = 1, #kids do before[i] = Level(kids[i]) end
    end
    fr:SetFrameLevel(level)
    if kids then
        local d = level - old
        for i = 1, #kids do
            local was = before[i]
            if was and Level(kids[i]) == was then
                local to = was + d
                pcall(SetLevelDeep, kids[i], to < 0 and 0 or to, depth + 1)
            end
        end
    end
end

local function ShiftFrame(f, fr, off)
    if not fr or (off == 0 and fr.azDepthRel == nil) then return end
    local hl, cur = Level(f.health), Level(fr)
    if not hl or not cur then return end
    local rel = cur - hl
    local base = (fr.azDepthRel ~= nil and rel == fr.azDepthRel) and fr.azDepthBase or rel
    local want = base + off
    if hl + want < 0 then want = -hl end
    fr.azDepthBase = base
    fr.azDepthRel = off ~= 0 and want or nil
    if rel ~= want then SetLevelDeep(fr, hl + want, 0) end
end

local function HostRegion(f, key, part, name, off)
    local r = f[name]
    if not r then return end
    local host = r.azDepthHost
    if off == 0 then
        if host and r:GetParent() == host then
            local home = part.home(f)
            if home then host:SetAlpha(1); r:SetParent(home) end
        end
        return
    end
    local home = part.home(f)
    if not home then return end
    if not host then
        f.azDepthHosts = f.azDepthHosts or {}
        host = f.azDepthHosts[key]
        if not host then
            host = _G.CreateFrame("Frame", nil, home)
            host:SetAllPoints(home)
            f.azDepthHosts[key] = host
        end
        r.azDepthHost = host
    end
    if r:GetParent() ~= host then r:SetParent(host) end
    local hl = Level(home)
    if hl then
        local want = hl + off
        if want < 0 then want = 0 end
        if Level(host) ~= want then host:SetFrameLevel(want) end
    end
end

local scratch, EMPTY = {}, {}
function NP.ApplyDepths(f)
    if not f or not f.health or not f.cfg then return end
    local d = f.cfg.depth
    if not d and not f.azDepthUsed then return end
    local used = false
    for key, part in pairs(PARTS) do
        if not part.own then
            local off = NP.DepthOffset(f, key)
            if off ~= 0 then used = true end
            if off ~= 0 or f.azDepthUsed then
                if part.regions then
                    for i = 1, #part.regions do HostRegion(f, key, part, part.regions[i], off) end
                end
                if part.frames then
                    wipe(scratch)
                    part.frames(f, scratch)
                    for i = 1, #scratch do ShiftFrame(f, scratch[i], off) end
                end
                if part.row then
                    ShiftFrame(f, f[part.row], off)
                    for _, c in pairs(f.auraContainers or EMPTY) do
                        if type(c) == "table" and c.azRow == part.row then ShiftFrame(f, c, off) end
                    end
                end
                if part.after then part.after(f) end
            end
        end
    end
    f.azDepthUsed = used or nil
end
