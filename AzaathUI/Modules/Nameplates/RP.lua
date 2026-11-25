--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/RP.lua
    Integração opcional com Total RP 3 (TRP3_NamePlates) para nomes/títulos de RP.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, pcall, type, wipe = pairs, pcall, type, wipe

local RP = {}
NP.RP = RP
local info = {}
local registered = false

function RP.Enabled()
    return NP.db and NP.db.general and NP.db.general.rpNames ~= false
end

local function Hub()
    local h = _G.TRP3_NamePlates
    return type(h) == "table" and type(h.RegisterCallback) == "function" and h.callbacks and h or nil
end

function RP.Available() return Hub() ~= nil end

local function IsPlayerKind(f)
    return f.kind == "friendlyplayer" or f.kind == "enemyplayer"
end

local function RefreshUnit(unit)
    local f = unit and NP.ActivePlates[unit]
    if f and f.active and IsPlayerKind(f) and NP.UpdateNameText then NP.UpdateNameText(f) end
end

function RP:OnNamePlateDataUpdated(_, _, unitToken, displayInfo)
    if not unitToken then return end
    info[unitToken] = displayInfo
    RefreshUnit(unitToken)
end

local asked, ticker = {}, nil
local function Ask(unit, force)
    local hub = Hub()
    if not (registered and hub and hub.UpdateNamePlateForUnit and unit) then return end
    if not force then
        local ok, guid = pcall(_G.UnitGUID, unit)
        if ok and type(guid) == "string" and not NP.IsSecret(guid) then
            local now = _G.GetTime()
            local a = asked[guid]
            if a and now - a.t > 300 then a = nil end
            if a and a.n >= 2 then return end
            if not a then a = { n = 0, t = now }; asked[guid] = a end
            a.n = a.n + 1
        else
            return
        end
    end
    pcall(hub.UpdateNamePlateForUnit, hub, unit)
end

function RP.StartTicker()
    if ticker or not (_G.C_Timer and _G.C_Timer.NewTicker) then return end
    ticker = _G.C_Timer.NewTicker(10, function()
        if not registered then return end
        for unit, f in pairs(NP.ActivePlates) do
            if f.active and f.kind == "friendlyplayer" then
                local d = info[unit]
                if type(d) ~= "table" or not d.nameUncropped then Ask(unit) end
            end
        end
    end)
end

function RP.Sync()
    local hub = Hub()
    if not hub then return end
    local want = RP.Enabled()
    if want == registered then return end
    if want then
        registered = pcall(hub.RegisterCallback, RP, "OnNamePlateDataUpdated")
        if registered and hub.UpdateAllNamePlates then pcall(hub.UpdateAllNamePlates, hub) end
        if registered then RP.StartTicker() end
    else
        pcall(hub.UnregisterCallback, RP, "OnNamePlateDataUpdated")
        registered = false
        wipe(info)
        for unit in pairs(NP.ActivePlates) do RefreshUnit(unit) end
    end
end

function RP.Forget(unit) if unit then info[unit] = nil end end

function RP.OnPlateAdded(f)
    if not registered or f.kind ~= "friendlyplayer" then return end
    local unit = f.unit
    _G.C_Timer.After(0, function()
        if f.unit == unit and f.active then Ask(unit) end
    end)
end

local function Call(t, k, ...)
    local fn = t and t[k]
    if type(fn) ~= "function" then return nil end
    local ok, a, b = pcall(fn, ...)
    if ok then return a, b end
end

local function IsNPC(unit)
    local nt = _G.AddOn_TotalRP3 and _G.AddOn_TotalRP3.Enums and _G.AddOn_TotalRP3.Enums.UNIT_TYPE
    local misc = _G.TRP3_API and _G.TRP3_API.ui and _G.TRP3_API.ui.misc
    local ty = misc and Call(misc, "getTargetType", unit)
    return nt and ty == nt.NPC
end

function RP.Get(f)
    if not registered or not IsPlayerKind(f) then return nil end
    local d = info[f.unit]
    if type(d) ~= "table" then return nil end
    if d.shouldHide then return "", nil, nil, nil, "" end
    local name = d.nameUncropped
    if type(name) ~= "string" or name == "" then return nil end
    local r, g, b
    if d.shouldColorName and type(d.color) == "table" and d.color.GetRGB then
        r, g, b = d.color:GetRGB()
    end
    local U = _G.TRP3_NamePlatesUtil
    if d.roleplayStatus then
        name = Call(U, "PrependRoleplayStatusToText", name, d.roleplayStatus) or name
    end
    if d.icon and _G.TRP3_MarkupUtil and _G.TRP3_MarkupUtil.GenerateIconMarkup then
        local size = Call(U, "GetPreferredIconSize") or 16
        local icon = Call(_G.TRP3_MarkupUtil, "GenerateIconMarkup", d.icon, { size = size })
        if icon then name = icon .. " " .. name end
    end
    local sub
    if NP.db and NP.db.general and NP.db.general.rpTitle ~= false then
        if Call(U, "IsFullTitleEnabled") then
            sub = d.fullTitleUncropped
            if not sub and not IsNPC(f.unit) then sub = "" end
        elseif Call(U, "IsGuildNameEnabled") then
            sub = d.guildNameUncropped
            if sub and not NP.db.general.plainTitles then sub = "<" .. sub .. ">" end
        end
    end
    if type(sub) ~= "string" then sub = "" end
    return name, r, g, b, sub
end

local boot = _G.CreateFrame("Frame")
Azaath.SafeRegister(boot, "PLAYER_LOGIN")
Azaath.SafeRegister(boot, "ADDON_LOADED")
boot:SetScript("OnEvent", function(_, event, name)
    if event == "ADDON_LOADED" and name ~= "totalRP3" then return end
    if not NP.db then return end
    RP.Sync()
    if not registered and event == "PLAYER_LOGIN" and _G.C_Timer then
        _G.C_Timer.After(2, RP.Sync)
    end
end)
