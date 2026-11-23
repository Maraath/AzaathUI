--[[----------------------------------------------------------------------------
    AzaathUI - Olho de Azaath / Tracking.lua
    Herborista e minerador ao mesmo tempo: o minimapa só mostra um rastreamento
    por vez. Com a alternância ligada (cdb.nodeSwitch), a cada N metros andados o
    Olho troca entre "Encontrar Ervas" e "Encontrar Minerais", sem o clique de
    interface que o jogo toca na troca.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local ns = Azaath.OlhoNS
local SafeCall, IsSecret = ns.SafeCall, ns.IsSecret

local pcall, type = pcall, type

local T = {}
ns.Tracking = T

local FINDER = { [2383] = "herb", [8387] = "herb", [2580] = "ore", [8388] = "ore" }
local CLICK_SOUND = 567407        -- clique tocado pelo jogo ao trocar de rastreamento
local QUIET_FOR = 0.6             -- segundos com o clique silenciado
local CHECK_EVERY = 0.5
local RETRY_AFTER, MAX_TRIES = 1.5, 3

local driver = CreateFrame("Frame")
local since = 0
local looting = false
local from         -- { map, x, y }: onde foi a última troca
local asked        -- { kind, at, tries }: troca pedida e ainda não confirmada
local quietUntil

-- rastreamentos ligados e posição de cada um na lista do jogo
local function Finders()
    local MM = C_Minimap
    if not (MM and MM.GetNumTrackingTypes and MM.GetTrackingInfo) then return nil end
    local count = SafeCall(MM.GetNumTrackingTypes)
    if type(count) ~= "number" then return nil end
    local active, index = {}, {}
    for i = 1, count do
        local info = SafeCall(MM.GetTrackingInfo, i)
        if type(info) == "table" then
            if IsSecret(info.spellID) or IsSecret(info.active) then return nil end
            local kind = info.spellID and FINDER[info.spellID]
            if kind then
                index[kind] = i
                if info.active then active[kind] = true end
            end
        end
    end
    return active, index
end
T.Finders = Finders

local function Casting(fn)
    if not fn then return false end
    local ok, name = pcall(fn, "player")
    return ok and (IsSecret(name) or name ~= nil)
end

local function Busy()
    return looting or InCombatLockdown() or Casting(UnitCastingInfo) or Casting(UnitChannelInfo)
end

-- posição do jogador em metros no mapa atual
local function Where()
    local CM = C_Map
    if not (CM and CM.GetBestMapForUnit and CM.GetPlayerMapPosition and CM.GetMapWorldSize) then return nil end
    local map = SafeCall(CM.GetBestMapForUnit, "player")
    if not map then return nil end
    local pos = SafeCall(CM.GetPlayerMapPosition, map, "player")
    if not pos then return nil end
    local ok, x, y = pcall(pos.GetXY, pos)
    if not ok or IsSecret(x) or not x then return nil end
    local ok2, w, h = pcall(CM.GetMapWorldSize, map)
    if not ok2 or IsSecret(w) or not w or w == 0 then return nil end
    return map, x * w, y * h
end

local function Quiet()
    if MuteSoundFile and pcall(MuteSoundFile, CLICK_SOUND) then quietUntil = GetTime() + QUIET_FOR end
end

local function Unquiet()
    if quietUntil and GetTime() >= quietUntil then
        if UnmuteSoundFile then pcall(UnmuteSoundFile, CLICK_SOUND) end
        quietUntil = nil
    end
end

local function Ask(kind, i)
    asked = asked and asked.kind == kind and asked or { kind = kind, tries = 0 }
    asked.at, asked.tries = GetTime(), asked.tries + 1
    Quiet()
    pcall(C_Minimap.SetTracking, i, true)
end

local function Step()
    Unquiet()
    local active, index = Finders()
    if not active or not (index.herb and index.ore) then return end
    if not (ns.cdb.nodeSwitch and ns.db.enabled) then return end

    -- uma troca pedida: confirmou? se não, tenta de novo algumas vezes
    if asked then
        if active[asked.kind] then
            asked = nil
        elseif GetTime() - asked.at >= RETRY_AFTER then
            if asked.tries >= MAX_TRIES then asked = nil
            elseif not Busy() then Ask(asked.kind, index[asked.kind]) end
        end
        return
    end

    -- só um dos dois ligado: alterna quando andou o bastante
    if (active.herb == true) == (active.ore == true) then return end
    local map, x, y = Where()
    if not map then return end
    if not from or from.map ~= map then from = { map = map, x = x, y = y } return end
    local dx, dy = x - from.x, y - from.y
    local need = ns.cdb.nodeSwitchYards
    if dx * dx + dy * dy < need * need or Busy() then return end
    from.x, from.y = x, y
    local other = active.herb and "ore" or "herb"
    Ask(other, index[other])
end

driver:SetScript("OnEvent", function(_, event)
    if event == "LOOT_OPENED" or event == "LOOT_READY" then looting = true
    elseif event == "LOOT_CLOSED" then looting = false
    elseif event == "PLAYER_ENTERING_WORLD" then from, asked = nil, nil end
end)
for _, e in ipairs({ "LOOT_OPENED", "LOOT_READY", "LOOT_CLOSED", "PLAYER_ENTERING_WORLD" }) do
    pcall(driver.RegisterEvent, driver, e)
end

local function OnUpdate(_, dt)
    since = since + dt
    if since < CHECK_EVERY then return end
    since = 0
    Step()
end

function T.Update()
    local on = ns.db and ns.db.enabled and ns.cdb.nodeSwitch
    from, asked = nil, nil
    driver:SetScript("OnUpdate", on and OnUpdate or nil)
    if not on and quietUntil then
        quietUntil = 0
        Unquiet()
    end
end

ns.OnOption("nodeSwitch", T.Update)
ns.OnOption("enabled", T.Update)
ns.OnOption("reset", T.Update)
