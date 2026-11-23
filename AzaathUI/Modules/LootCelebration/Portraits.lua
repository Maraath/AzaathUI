--[[----------------------------------------------------------------------------
    AzaathUI - Modules/LootCelebration/Portraits.lua
    Captura segura de retrato 3D de inimigos raros enquanto a unidade ainda está
    disponível, evitando vazamento entre alvos ou falha quando a placa some.
    Baseado em LootDopamine/Portraits.lua (MIT).
------------------------------------------------------------------------------]]

local _, Azaath = ...

local LC = Azaath.LootCel or {}
Azaath.LootCel = LC

local _G = _G
local ipairs, pcall, setmetatable, type = ipairs, pcall, setmetatable, type
local floor, huge = math.floor, math.huge
local CreateFrame, UIParent = CreateFrame, UIParent

local Portraits = {}
LC.RarePortraits = Portraits

local function Safe(v)
    return not Azaath.IsSecret(v)
end

local function Valid(v, kind)
    return Safe(v) and type(v) == kind
end

local function ValidDisplayID(v)
    return Valid(v, "number") and v > 0 and v < huge and v == floor(v)
end

local function Matches(unit, guid)
    if not Valid(unit, "string") or not Valid(guid, "string") or type(_G.UnitGUID) ~= "function" then
        return false
    end
    local ok, value = pcall(_G.UnitGUID, unit)
    return ok and Valid(value, "string") and value == guid
end
Portraits.UnitMatches = Matches

local function Ready(unit)
    if type(_G.IsUnitModelReadyForUI) ~= "function" then return true end
    local ok, result = pcall(_G.IsUnitModelReadyForUI, unit)
    return ok and Safe(result) and result ~= false
end

local probeModel, probeTried
local function CaptureDisplayID(unit, guid)
    if not Matches(unit, guid) or not Ready(unit) then return nil end
    if not probeTried then
        probeTried = true
        local ok, frame = pcall(CreateFrame, "PlayerModel", nil, UIParent)
        if ok and frame then
            frame:Hide()
            if type(frame.ClearModel) == "function" and type(frame.SetUnit) == "function" and type(frame.GetDisplayInfo) == "function" then
                probeModel = frame
                probeModel:SetSize(1, 1)
            end
        end
    end
    if probeModel then
        local cleared = pcall(probeModel.ClearModel, probeModel)
        if cleared then
            local ok, res = pcall(probeModel.SetUnit, probeModel, unit)
            if ok and Safe(res) and res ~= false and Matches(unit, guid) then
                local read, value = pcall(probeModel.GetDisplayInfo, probeModel)
                pcall(probeModel.ClearModel, probeModel)
                if read and ValidDisplayID(value) and Matches(unit, guid) then
                    return value
                end
            else
                pcall(probeModel.ClearModel, probeModel)
            end
        end
    end
    for _, name in ipairs({ "UnitCreatureDisplayID", "UnitDisplayID", "GetCreatureDisplayID" }) do
        local api = _G[name]
        if type(api) == "function" then
            local ok, value = pcall(api, unit)
            if ok and ValidDisplayID(value) and Matches(unit, guid) then
                return value
            end
        end
    end
end

local storage = CreateFrame("Frame", nil, UIParent)
storage:Hide()
local slots = {}
local leases = setmetatable({}, { __mode = "v" })
local MAX_SNAPSHOTS = 96

local function Acquire(info)
    local index
    for i = 1, #slots do
        if leases[i] == nil then
            index = i
            break
        end
    end
    if not index then
        if #slots >= MAX_SNAPSHOTS then return nil end
        index = #slots + 1
        local host = CreateFrame("Frame", nil, storage)
        host:SetSize(64, 64)
        host:EnableMouse(false)
        host:Hide()
        local texture = host:CreateTexture(nil, "ARTWORK")
        texture:SetAllPoints(host)
        if host.CreateMaskTexture then
            local mask = host:CreateMaskTexture()
            mask:SetTexture(Azaath.media.path .. "Inventory\\RoundMask", "CLAMPTOBLACKADDITIONAL", "CLAMPTOBLACKADDITIONAL")
            mask:SetAllPoints(texture)
            texture:AddMaskTexture(mask)
        end
        host.portraitTexture = texture
        host.slot = index
        slots[index] = host
    end
    local host = slots[index]
    host:Hide()
    host:ClearAllPoints()
    host:SetParent(storage)
    host.portraitTexture:SetTexture(nil)
    leases[index] = info
    return host
end

local function HasTexture(texture)
    if type(texture.GetTexture) ~= "function" then return false end
    local ok, value = pcall(texture.GetTexture, texture)
    return ok and ((Valid(value, "string") and value ~= "") or (Valid(value, "number") and value > 0))
end

local function DrawPortrait(api, texture, arg)
    if type(api) ~= "function" then return false end
    texture:SetTexture(nil)
    local ok, result = pcall(api, texture, arg)
    return ok and Safe(result) and result ~= false and HasTexture(texture)
end

local function RememberUnit(info, unit)
    for _, known in ipairs(info.units) do
        if known == unit then return end
    end
    if #info.units < 32 then
        info.units[#info.units + 1] = unit
    end
end

function Portraits.Capture(unit, guid, previous)
    local info = type(previous) == "table" and previous.guid == guid and previous or { guid = guid, units = {} }
    if not Matches(unit, guid) then return info end
    RememberUnit(info, unit)
    if not Ready(unit) then return info end
    if not info.displayID then
        info.displayID = CaptureDisplayID(unit, guid)
    end
    if not info.host and type(_G.SetPortraitTexture) == "function" then
        local host = Acquire(info)
        if host then
            local ok = DrawPortrait(_G.SetPortraitTexture, host.portraitTexture, unit)
            if ok and Matches(unit, guid) then
                info.host = host
            else
                leases[host.slot] = nil
                host.portraitTexture:SetTexture(nil)
            end
        end
    end
    return info
end

function Portraits.Clear(texture)
    if not texture then return end
    local info = texture.azaathPortraitLease
    local host = info and info.host
    texture.azaathPortraitLease = nil
    if host and host.owner == texture then
        host.owner = nil
        host:Hide()
        host:ClearAllPoints()
        host:SetParent(storage)
    end
    texture:Show()
end

local function Attach(texture, info)
    local host = info and info.host
    if not host then return false end
    if host.owner and host.owner ~= texture then
        host.owner.azaathPortraitLease = nil
        host.owner:Show()
    end
    local parent = texture:GetParent()
    host:SetParent(parent)
    host:ClearAllPoints()
    host:SetAllPoints(texture)
    host:SetFrameLevel(parent:GetFrameLevel() + 1)
    host.owner = texture
    texture.azaathPortraitLease = info
    texture:Hide()
    host:Show()
    return true
end

function Portraits.Apply(texture, item)
    Portraits.Clear(texture)
    if type(item) ~= "table" or item.kind ~= "rare_kill" or not Valid(item.portraitGUID, "string") then
        return false
    end
    local guid = item.portraitGUID
    local info = type(item.portrait) == "table" and item.portrait.guid == guid and item.portrait or nil
    if info and Attach(texture, info) then return true end

    local id = info and info.displayID or item.portraitDisplayID
    if ValidDisplayID(id) and DrawPortrait(_G.SetPortraitTextureFromCreatureDisplayID, texture, id) then
        texture:SetTexCoord(0, 1, 0, 1)
        return true
    end

    local units = { "target", "focus", "mouseover", "targettarget", "focustarget" }
    if Valid(item.portraitUnit, "string") then units[#units + 1] = item.portraitUnit end
    for _, unit in ipairs(info and info.units or item.portraitUnits or {}) do
        units[#units + 1] = unit
    end
    local visited = {}
    for _, unit in ipairs(units) do
        if not visited[unit] and Matches(unit, guid) then
            visited[unit] = true
            info = Portraits.Capture(unit, guid, info)
            item.portrait = info
            if Attach(texture, info) then return true end
            if DrawPortrait(_G.SetPortraitTexture, texture, unit) and Matches(unit, guid) then
                texture:SetTexCoord(0, 1, 0, 1)
                return true
            end
        end
    end
    return false
end
