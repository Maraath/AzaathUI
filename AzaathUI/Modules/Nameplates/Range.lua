--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Range.lua
    Esmaecimento por distância usando magias conhecidas da classe/spec/grimório.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, type = pairs, ipairs, pcall, type

local CLASS_SPELLS = {
    [1]  = { 6552, 1464, 772, 355, 7386, 100 },
    [2]  = { 20271, 35395, 879, 853 },
    [3]  = { 185358, 56641, 34026, 3044, 75, 1978, 2974 },
    [4]  = { 1752, 1766, 2098, 53, 1776 },
    [5]  = { 585, 589, 8092 },
    [6]  = { 49998, 47528 },
    [7]  = { 188196, 403, 8042 },
    [8]  = { 116, 133, 30451, 44614, 2136 },
    [9]  = { 232670, 686, 172, 348 },
    [10] = { 100780 },
    [11] = { 190984, 5176, 8921 },
    [12] = { 162794, 203782, 263642, 185123 },
    [13] = { 361469, 362969 },
}
local SPEC_SPELLS = {
    [255] = { 186270, 259387 },
    [103] = { 5221, 1822 },
    [104] = { 33917, 6807 },
    [70]  = { 35395, 96231 },
    [263] = { 17364, 73899 },
}

local ENEMY = { enemynpc = true, enemyplayer = true }
local spells, dirty = {}, true
local ranges, final, fromBook = {}, {}, {}
local LONG = 8

local function SpecID()
    local CS = _G.C_SpecializationInfo
    if not (CS and CS.GetSpecialization and CS.GetSpecializationInfo) then return nil end
    local ok, idx = pcall(CS.GetSpecialization)
    if not ok or type(idx) ~= "number" or NP.IsSecret(idx) then return nil end
    local ok2, id = pcall(CS.GetSpecializationInfo, idx)
    if not ok2 or NP.IsSecret(id) then return nil end
    return id
end

local function IsKnown(id)
    if _G.IsPlayerSpell then
        local ok, v = pcall(_G.IsPlayerSpell, id)
        if ok and NP.Truthy(v, false) then return true end
    end
    local SB = _G.C_SpellBook
    if SB and SB.IsSpellKnownOrInSpellBook then
        local ok, v = pcall(SB.IsSpellKnownOrInSpellBook, id)
        if ok and NP.Truthy(v, false) then return true end
    end
    if SB and SB.IsSpellKnown then
        local ok, v = pcall(SB.IsSpellKnown, id)
        if ok and NP.Truthy(v, false) then return true end
    end
    return false
end

local function SpellRange(id)
    local CS = _G.C_Spell
    if not (CS and CS.GetSpellInfo) then return nil end
    local ok, si = pcall(CS.GetSpellInfo, id)
    if not ok or type(si) ~= "table" then return nil end
    local mr, mn = si.maxRange, si.minRange
    if type(mr) ~= "number" or NP.IsSecret(mr) or type(mn) ~= "number" or NP.IsSecret(mn) then return nil end
    return mr, mn
end

local function FromBook(out)
    fromBook = {}
    for _, id in ipairs(out) do
        local _, mn = SpellRange(id)
        if mn == 0 then return end
    end
    local SB, CS = _G.C_SpellBook, _G.C_Spell
    local bank = _G.Enum and _G.Enum.SpellBookSpellBank and _G.Enum.SpellBookSpellBank.Player
    local kind = _G.Enum and _G.Enum.SpellBookItemType and _G.Enum.SpellBookItemType.Spell
    if not (SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookSkillLineInfo and SB.GetSpellBookItemInfo and bank and kind and CS and CS.IsSpellHarmful) then
        return
    end
    local okn, n = pcall(SB.GetNumSpellBookSkillLines)
    if not okn or type(n) ~= "number" or NP.IsSecret(n) then return end
    local have, close, far = {}, {}, {}
    for _, id in ipairs(out) do have[id] = true end
    for line = 1, n do
        local okl, sl = pcall(SB.GetSpellBookSkillLineInfo, line)
        if okl and type(sl) == "table" and not sl.isGuild and not sl.shouldHide and not sl.offSpecID
            and type(sl.itemIndexOffset) == "number" and type(sl.numSpellBookItems) == "number" then
            for slot = sl.itemIndexOffset + 1, sl.itemIndexOffset + sl.numSpellBookItems do
                local oki, it = pcall(SB.GetSpellBookItemInfo, slot, bank)
                local id = oki and type(it) == "table" and it.itemType == kind and not it.isPassive and not it.isOffSpec and it.spellID
                if type(id) == "number" and not NP.IsSecret(id) and not have[id] then
                    have[id] = true
                    local okh, harmful = pcall(CS.IsSpellHarmful, id)
                    local mr, mn = SpellRange(id)
                    if okh and NP.Truthy(harmful, false) and mn == 0 then
                        local ranged = true
                        if CS.SpellHasRange then
                            local okr, r = pcall(CS.SpellHasRange, id)
                            ranged = okr and NP.Truthy(r, false)
                        end
                        if mr >= LONG then far[#far + 1] = { id = id, r = mr }
                        else close[#close + 1] = { id = id, r = ranged and 1 or 0, n = #close } end
                    end
                end
            end
        end
    end
    table.sort(far, function(a, b) if a.r ~= b.r then return a.r > b.r end; return a.id < b.id end)
    table.sort(close, function(a, b) if a.r ~= b.r then return a.r > b.r end; return a.n < b.n end)
    for i = 1, math.min(2, #far) do out[#out + 1] = far[i].id; fromBook[far[i].id] = true end
    for i = 1, math.min(4, #close) do out[#out + 1] = close[i].id; fromBook[close[i].id] = true end
end

function NP.RangeSpells()
    if not dirty then return spells end
    dirty = false
    spells = {}
    local sid = SpecID()
    local _, _, classID = _G.UnitClass("player")
    for _, id in ipairs(SPEC_SPELLS[sid] or {}) do if IsKnown(id) then spells[#spells + 1] = id end end
    for _, id in ipairs(CLASS_SPELLS[classID] or {}) do if IsKnown(id) then spells[#spells + 1] = id end end
    FromBook(spells)
    ranges, final = {}, {}
    for _, id in ipairs(spells) do
        local mr, mn = SpellRange(id)
        ranges[id] = mr or 0
        final[id] = (mn == 0 and (mr or 0) >= LONG) or nil
    end
    local order = {}
    for i, id in ipairs(spells) do order[id] = i end
    table.sort(spells, function(a, b)
        if ranges[a] ~= ranges[b] then return ranges[a] > ranges[b] end
        return order[a] < order[b]
    end)
    return spells
end

local function Answer(id, unit)
    local ok, r = pcall(_G.C_Spell.IsSpellInRange, id, unit)
    if ok and r ~= nil and not NP.IsSecret(r) and type(r) == "boolean" then return r end
    return nil
end

local function Doubted(id, unit, list)
    if not fromBook[id] then return false end
    for _, other in ipairs(list) do
        if other ~= id and fromBook[other] and (ranges[other] or 0) >= (ranges[id] or 0) and Answer(other, unit) == false then
            return true
        end
    end
    return false
end

local function Out(f, list)
    if not (f.unit and ENEMY[f.kind]) then return false end
    local answered = false
    for _, id in ipairs(list or {}) do
        local r = Answer(id, f.unit)
        if r == true and not Doubted(id, f.unit, list) then return false end
        if r == false then
            if final[id] then return true end
            answered = true
        end
    end
    return answered
end

local function AttacksMe(f)
    local rf = NP.db and NP.db.general and NP.db.general.rangeFade
    if not (rf and rf.notAttackers) or not f.unit then return false end
    local tu = f.unit .. "target"
    if not NP.Truthy(_G.UnitExists(tu), false) then return false end
    if NP.Truthy(_G.UnitIsUnit(tu, "player"), false) then return true end
    return NP.Truthy(_G.UnitExists("pet"), false) and NP.Truthy(_G.UnitIsUnit(tu, "pet"), false)
end

local function SetOut(f, out)
    if f.outOfRange ~= out then
        f.outOfRange = out
        if NP.UpdateAlpha then NP.UpdateAlpha(f) end
    end
end

local ticker
local function Tick()
    local list = NP.RangeSpells()
    for _, f in pairs(NP.ActivePlates) do
        local out = Out(f, list)
        if out and AttacksMe(f) then out = false end
        SetOut(f, out)
    end
end

function NP.UpdateRangeFade()
    local rf = NP.db and NP.db.general and NP.db.general.rangeFade
    local on = rf and rf.enabled and _G.C_Spell and _G.C_Spell.IsSpellInRange and true or false
    if on and not ticker then
        ticker = _G.C_Timer.NewTicker(0.25, NP.Perf.Wrap("range check", Tick))
        Tick()
    elseif not on and ticker then
        ticker:Cancel()
        ticker = nil
        for _, f in pairs(NP.ActivePlates) do SetOut(f, false) end
    end
end

function NP.RangeCheckPlate(f)
    local out = ticker and Out(f, NP.RangeSpells()) or false
    if out and AttacksMe(f) then out = false end
    f.outOfRange = out
end

local watcher = _G.CreateFrame("Frame")
Azaath.SafeRegister(watcher, "SPELLS_CHANGED")
Azaath.SafeRegister(watcher, "PLAYER_ENTERING_WORLD")
Azaath.SafeRegister(watcher, "PLAYER_SPECIALIZATION_CHANGED")
watcher:SetScript("OnEvent", function(_, event)
    dirty = true
    if event == "PLAYER_ENTERING_WORLD" then NP.UpdateRangeFade() end
end)
