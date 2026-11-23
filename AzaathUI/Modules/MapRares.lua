--[[----------------------------------------------------------------------------
    AzaathUI - Modules/MapRares.lua
    Rare Scanner: os raros no mapa-múndi (Modules/WorldMap.lua desenha) e o aviso ao vivo.

    Dados: Data/Map/Rares.lua (tools/map-extract/rares.js) = onde cada raro nasce, nível, respawn e drops.
    Ao vivo: placas de nome, alvo e mouse (UnitClassification "rare"/"rareelite"). Nada do log de
    combate (abre a janela de ação bloqueada). Quando um raro aparece: som, aviso na tela, linha no
    chat e um pino "visto agora" onde você estava. Quando ele morre perto de você: guarda a hora,
    e o mapa mostra quanto falta para o respawn estimado.

    Estado (Azaath.db.worldmap.rares): seen[npcID] = { t, map, x, y }, killed[npcID] = hora,
    hide[npcID] = true. Opções: poiRares (camada), rareAlert (aviso), rareSound (som).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("MapRares")

local C_Map = _G.C_Map
local pcall, type, tonumber, time, floor = pcall, type, tonumber, time, math.floor

local SEEN_FOR = 10 * 60        -- o pino "visto agora" fica 10 min
local ALERT_GAP = 5 * 60        -- o mesmo raro só avisa de novo depois de 5 min

M.version = 0

local function Safe(fn, ...)
    if not fn then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function Secret(v)
    local f = Azaath.IsSecret or _G.issecretvalue
    return f and f(v) and true or false
end

local function Changed()
    M.version = M.version + 1
    local wm = Azaath:GetModule("WorldMap")
    if wm and wm.Refresh then wm:Refresh() end
end

---------------------------------------------------------------------------
-- Dados
---------------------------------------------------------------------------
function M:All()
    return (Azaath.MapData and Azaath.MapData.Rares) or {}
end

-- { name, level, elite, respawn, points, drops } ou nil
function M:Info(id)
    local r = self:All()[id]
    if not r then return end
    return { name = r[1], level = r[2], elite = r[3] == 1, respawn = r[4] or 0, points = r[5], drops = r[6],
             display = (r[7] or 0) > 0 and r[7] or nil }
end

-- cada ponto do raro: fn(inst, X, Y) em jardas do mundo (as coordenadas "live" vão pelo jogo)
function M:EachPoint(id, fn)
    local r = self:All()[id]
    local p = r and r[5]
    if not p then return end
    for i = 1, #p - 2, 3 do
        local a, b, c = p[i], p[i + 1], p[i + 2]
        if a >= 0 then
            fn(a, b, c)
        elseif C_Map.GetWorldPosFromMapPos and _G.CreateVector2D then
            local inst, wp = Safe(C_Map.GetWorldPosFromMapPos, -a, CreateVector2D(b / 100, c / 100))
            if inst and wp then
                local X, Y = wp:GetXY()
                fn(inst, X, Y)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Estado
---------------------------------------------------------------------------
function M:State()
    local db = Azaath.db.worldmap
    local r = db.rares
    if type(r) ~= "table" then r = {}; db.rares = r end
    r.seen = r.seen or {}
    r.killed = r.killed or {}
    r.hide = r.hide or {}
    r.display = r.display or {}     -- [npcID] = displayID (retrato da aba de detalhes)
    return r
end

-- segundos até o respawn estimado (nil = sem morte registrada ou já passou)
function M:RespawnLeft(id)
    local k = self:State().killed[id]
    local info = self:Info(id)
    if not (k and info and info.respawn > 0) then return end
    local left = k + info.respawn - time()
    if left > 0 then return left end
end

-- visto há pouco: { t, map, x, y } (x, y 0..1 do mapa)
function M:SeenRecently(id)
    local s = self:State().seen[id]
    if s and time() - s.t < SEEN_FOR then return s end
end

function M:SetHidden(id, on)
    self:State().hide[id] = on or nil
    Changed()
end

function M:Shows(id)
    local db = Azaath.db.worldmap
    if db.poiRares == false then return false end
    return not self:State().hide[id]
end

local function Ago(sec)
    if sec < 60 then return "agora" end
    if sec < 3600 then return floor(sec / 60) .. " min" end
    return floor(sec / 3600) .. " h " .. floor((sec % 3600) / 60) .. " min"
end
M.Ago = Ago
local function Since(sec) return sec < 60 and "agora" or ("há " .. Ago(sec)) end

-- linhas da dica do pino
local QUALITY = { [1] = { 0.92, 0.92, 0.92 }, [2] = { 0.12, 1, 0 }, [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 } }
function M:TipLines(id, live)
    local info = self:Info(id)
    local lines = {}
    if info then
        lines[#lines + 1] = { "Nv. " .. info.level .. (info.elite and " · Raro de elite" or " · Raro"), 0.78, 0.78, 0.86 }
    end
    local s = self:SeenRecently(id)
    if s then
        lines[#lines + 1] = { "Visto " .. Since(time() - s.t) .. (live and " (aqui)" or ""), 0.45, 0.95, 0.55 }
    end
    local left = self:RespawnLeft(id)
    if left then
        lines[#lines + 1] = { "Morto · renasce em ~" .. Ago(left), 0.95, 0.45, 0.4 }
    elseif self:State().killed[id] then
        lines[#lines + 1] = { "Morto " .. Since(time() - self:State().killed[id]) .. " · já pode ter renascido", 0.9, 0.75, 0.4 }
    elseif info and info.respawn > 0 then
        lines[#lines + 1] = { "Respawn: ~" .. Ago(info.respawn), 0.6, 0.6, 0.6 }
    end
    local d = info and info.drops
    -- resumo: os 3 drops mais prováveis (a lista completa fica na aba do botão direito)
    local d = info and info.drops
    if d and #d > 0 then
        local n = math.floor(#d / 4)
        lines[#lines + 1] = { "Drops (" .. n .. "):", 0.86, 0.74, 0.45 }
        for i = 1, math.min(#d, 12) - 3, 4 do
            local itemID, pct, q, name = d[i], d[i + 1], d[i + 2], d[i + 3]
            if not name or name == "" then
                local gn, _, gq = Safe(GetItemInfo, itemID)
                name, q = gn, gq or q
            end
            local c = QUALITY[q or 1] or QUALITY[1]
            lines[#lines + 1] = { "  " .. (name or ("Item " .. itemID)) .. "  " .. pct .. "%", c[1], c[2], c[3] }
        end
        if n > 3 then lines[#lines + 1] = { "  + " .. (n - 3) .. " itens", 0.6, 0.6, 0.6 } end
    elseif info then
        lines[#lines + 1] = { "Drops: só loot aleatório do mundo", 0.7, 0.7, 0.7 }
    end
    lines[#lines + 1] = { "Clique: seguir · Botão direito: detalhes e drops", 0.6, 0.6, 0.6 }
    return lines
end

---------------------------------------------------------------------------
-- Scanner ao vivo
---------------------------------------------------------------------------
local alerted = {}      -- [guid] = hora do aviso
local lastByID = {}     -- [npcID] = hora do aviso

local function NpcID(unit)
    local guid = Safe(UnitGUID, unit)
    if not guid or Secret(guid) then return end
    local kind, _, _, _, _, id = strsplit("-", guid)
    if kind ~= "Creature" then return end
    return tonumber(id), guid
end

local function PlayerSpot()
    local map = Safe(C_Map.GetBestMapForUnit, "player")
    local pos = map and Safe(C_Map.GetPlayerMapPosition, map, "player")
    if not pos then return end
    local x, y = pos:GetXY()
    if not (x and y and (x > 0 or y > 0)) then return end
    local inst, wp = Safe(C_Map.GetWorldPosFromMapPos, map, pos)
    local X, Y
    if wp then X, Y = wp:GetXY() end
    return map, x, y, inst, X, Y
end

local function Alert(name, elite, id)
    local db = Azaath.db.worldmap
    if db.rareAlert == false then return end
    local text = (elite and "Raro de elite: " or "Raro: ") .. name
    if _G.RaidNotice_AddMessage and _G.RaidWarningFrame then
        pcall(RaidNotice_AddMessage, RaidWarningFrame, text, { r = 1, g = 0.82, b = 0.3 })
    end
    if db.rareSound ~= false then
        PlaySound(_G.SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, "Master")
    end
    local info = id and M:Info(id)
    local extra = info and (" (nv. " .. info.level .. ")") or ""
    print("|cffd4a24cAzaath|r |cffffd24d" .. text .. "|r" .. extra .. " - marcado no mapa.")
end

local function Check(unit)
    if not unit or Secret(unit) then return end
    local cls = Safe(UnitClassification, unit)
    if Secret(cls) or (cls ~= "rare" and cls ~= "rareelite") then return end
    local id, guid = NpcID(unit)
    if not id then return end
    local dead = Safe(UnitIsDead, unit)
    if Secret(dead) then dead = nil end
    local st = M:State()
    local now = time()
    if dead then
        if not st.killed[id] or now - st.killed[id] > 60 then
            st.killed[id] = now
            st.seen[id] = nil
            Changed()
        end
        return
    end
    -- vivo: se estava marcado como morto, renasceu
    if st.killed[id] then st.killed[id] = nil end
    -- retrato: guarda o modelo dele (a aba de detalhes usa quando o jogo não o carrega pelo ID)
    local P = Azaath.LootCel and Azaath.LootCel.RarePortraits
    if not st.display[id] and P and P.Capture then
        local pi = Safe(P.Capture, unit, guid)
        if type(pi) == "table" and type(pi.displayID) == "number" then st.display[id] = pi.displayID end
    end
    local map, x, y, inst, X, Y = PlayerSpot()
    if map then st.seen[id] = { t = now, map = map, x = x, y = y, inst = inst, X = X, Y = Y } end
    if alerted[guid] or (lastByID[id] and now - lastByID[id] < ALERT_GAP) then
        Changed()
        return
    end
    alerted[guid], lastByID[id] = now, now
    local name = Safe(UnitName, unit)
    if Secret(name) then name = nil end
    local info = M:Info(id)
    Alert(name or (info and info.name) or "?", cls == "rareelite", id)
    Changed()
end

-- placa sumindo: se o raro morreu ali, guarda a hora
local function Removed(unit)
    local cls = Safe(UnitClassification, unit)
    if Secret(cls) or (cls ~= "rare" and cls ~= "rareelite") then return end
    local dead = Safe(UnitIsDead, unit)
    if dead and not Secret(dead) then Check(unit) end
end

function M:OnEnable()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("NAME_PLATE_UNIT_ADDED")
    ev:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
    ev:RegisterEvent("PLAYER_TARGET_CHANGED")
    ev:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
    ev:RegisterEvent("UNIT_FLAGS")
    ev:SetScript("OnEvent", function(_, event, unit)
        if IsInInstance and IsInInstance() then return end
        if event == "NAME_PLATE_UNIT_ADDED" then Check(unit)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then Removed(unit)
        elseif event == "PLAYER_TARGET_CHANGED" then Check("target")
        elseif event == "UPDATE_MOUSEOVER_UNIT" then Check("mouseover")
        elseif event == "UNIT_FLAGS" and unit == "target" then Check("target") end
    end)
    -- limpeza: avisos velhos e mortes cujo respawn já passou há muito
    local st = self:State()
    local now = time()
    for id, t in pairs(st.killed) do
        local info = self:Info(id)
        if now - t > ((info and info.respawn or 0) + 24 * 3600) then st.killed[id] = nil end
    end
    for id, s in pairs(st.seen) do
        if type(s) ~= "table" or now - (s.t or 0) > 24 * 3600 then st.seen[id] = nil end
    end
end

-- /azrare: lista os raros vistos/mortos (diagnóstico)
SLASH_AZAATHRARE1 = "/azrare"
SlashCmdList.AZAATHRARE = function()
    local st = M:State()
    local n = 0
    for id, s in pairs(st.seen) do
        local info = M:Info(id)
        print(("visto: %s (%d) há %s"):format(info and info.name or "?", id, Ago(time() - s.t)))
        n = n + 1
    end
    for id, t in pairs(st.killed) do
        local info = M:Info(id)
        local left = M:RespawnLeft(id)
        print(("morto: %s (%d) há %s%s"):format(info and info.name or "?", id, Ago(time() - t), left and (", renasce em ~" .. Ago(left)) or ""))
        n = n + 1
    end
    local total = 0
    for _ in pairs(M:All()) do total = total + 1 end
    print(("Azaath raros: %d no banco, %d com registro"):format(total, n))
end
