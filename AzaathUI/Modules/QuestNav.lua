--[[----------------------------------------------------------------------------
    AzaathUI - Modules/QuestNav.lua
    Navegação 3D nativa e estado espacial de missões (Fase 1):
      * Integra com C_SuperTrack e C_Navigation do cliente (16001) para
        exibir marcador 3D no estilo Azaath com altura real.
      * Se C_Navigation não retornar um frame visível, usa projeção direcional
        na tela baseada na posição do jogador, orientação (GetPlayerFacing) e
        coordenadas da missão (GetNextWaypoint / GetQuestsOnMap / QuestAreaData),
        garantindo que o losango apareça sempre.
      * Mudança de foco funciona inclusive em combate (a chamada protegida
        ao C_SuperTrack fica enfileirada para PLAYER_REGEN_ENABLED).
      * Detecta contexto espacial: Dentro / Fora, Desnível e Na área.
      * Quando o NPC do destino (quem dá / recebe a missão) tem placa visível, o
        losango vai sobre a cabeça dele (altura exata, inclusive em andares).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("QuestNav")

local _G = _G
local pcall, type, ipairs, tonumber = pcall, type, ipairs, tonumber
local floor, sqrt, atan2, abs, format = math.floor, math.sqrt, math.atan2, math.abs, string.format
local GetTime = GetTime

local NAV_IN_AREA  = (_G.Enum and _G.Enum.NavigationState and _G.Enum.NavigationState.InArea) or 2
local NAV_OCCLUDED = (_G.Enum and _G.Enum.NavigationState and _G.Enum.NavigationState.Occluded) or 1
local NAV_INVALID  = (_G.Enum and _G.Enum.NavigationState and _G.Enum.NavigationState.Invalid) or 0
local RAD2DEG = 180 / math.pi

local markerFrame, focusedQuestID, customTarget, UpdateNavigation
local navGone = false
local pendingNativeCheckAt = 0
local usingUserWaypoint = false
local pendingSuperTrack = false
-- destino escolhido pelo jogador (mapa, rastreador, cartão da rota): o avanço automático
-- do QuestRoute não pode trocá-lo. M.autoFocusing = true marca as trocas automáticas.
local userPicked, userQuestWasInLog = false, false

local function Safe(fn, ...)
    if not fn then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local magicState = { key = nil, lastReqAt = 0, lastX = 0, lastY = 0, job = nil, coarseJob = nil, hasFine = false, nodes = nil, mapID = nil, idx = 1, totalYds = nil }

-- diagnóstico (SavedVariables: AzaathUIDB.questnav.pathDiag): o último motivo do caminho mágico, só quando muda
local lastWhy
local function Why(msg)
    if msg == lastWhy or not M.db then return end
    lastWhy = msg
    M.db.pathDiag = { time = date("%H:%M:%S"), why = msg }
end

local function ClearMagicPath()
    if Azaath.NavEngine and Azaath.NavEngine.Cancel then
        if magicState.job then pcall(Azaath.NavEngine.Cancel, magicState.job) end
        if magicState.coarseJob then pcall(Azaath.NavEngine.Cancel, magicState.coarseJob) end
    end
    magicState.key, magicState.lastReqAt, magicState.job, magicState.coarseJob, magicState.hasFine = nil, 0, nil, nil, false
    magicState.nodes, magicState.mapID, magicState.idx, magicState.totalYds = nil, nil, 1, nil
end

local function ApplyMagicPathResult(path, tMap, pInst)
    local CMap = _G.C_Map
    if type(path) ~= "table" or #path < 2 then return false end
    local nodes = {}
    local total = 0
    for i, pt in ipairs(path) do
        local mx, my
        if CMap and CMap.GetMapPosFromWorldPos then
            local _, mvec = Safe(CMap.GetMapPosFromWorldPos, pInst, _G.CreateVector2D(pt.x, pt.y), tMap)
            if mvec and mvec.GetXY then mx, my = mvec:GetXY() end
        end
        if i > 1 then
            local prev = path[i - 1]
            total = total + sqrt((pt.x - prev.x) ^ 2 + (pt.y - prev.y) ^ 2)
        end
        nodes[i] = { wx = pt.x, wy = pt.y, mx = mx, my = my }
    end
    magicState.nodes = nodes
    magicState.mapID = tMap
    magicState.idx = 2
    magicState.totalYds = total
    local cp = Azaath:GetModule("Compass")
    if cp and cp.UpdateHeading then cp:UpdateHeading(true) end
    return true
end

local function UpdateMagicPath(tMap, tx, ty)
    if not (M.db and M.db.magicPath ~= false and tMap and tx and ty) then
        if magicState.nodes then ClearMagicPath() end
        return
    end
    -- só no destino escolhido pelo jogador (ou na volta ao cadáver): foco automático do
    -- QuestRoute ou rastreio herdado do jogo não desenham caminho
    if not ((customTarget and customTarget.isCorpse) or M:HasUserTarget()) then
        if magicState.nodes or magicState.job or magicState.coarseJob then ClearMagicPath() end
        Why("destino não escolhido pelo jogador")
        return
    end
    local eng = Azaath.NavEngine
    local CMap = _G.C_Map
    if not (eng and eng.Available and eng.Find and _G.UnitPosition and CMap and CMap.GetWorldPosFromMapPos and _G.CreateVector2D) then
        Why("motor ausente: eng=" .. tostring(eng) .. " Available=" .. tostring(eng and eng.Available) .. " Find=" .. tostring(eng and eng.Find)
            .. " UnitPosition=" .. tostring(_G.UnitPosition) .. " CreateVector2D=" .. tostring(_G.CreateVector2D))
        return
    end
    local pwx, pwy, _, pInst = Safe(_G.UnitPosition, "player")
    if not (pwx and pwy and pInst and eng.Available(pInst)) then
        Why("sem dados de rota: pos=" .. tostring(pwx) .. "," .. tostring(pwy) .. " inst=" .. tostring(pInst)
            .. " Available=" .. tostring(pInst and eng.Available(pInst)) .. " | " .. (function()
                local d = Azaath.navLoadDiag
                if not d then return "navLoadDiag ausente (API.lua não rodou)" end
                return "decodes=" .. tostring(d.decodes) .. " C_EncodingUtil=" .. d.enc .. " b64=" .. d.b64 .. " zlib=" .. d.zlib
                    .. " PolestarPathData=" .. d.data .. " mapas=[" .. d.maps .. "] descartados=[" .. d.dropped .. "]"
            end)())
        return
    end

    local key = format("%d:%.3f,%.3f", tMap, tx, ty)
    local now = GetTime()
    local moved = sqrt((pwx - magicState.lastX) ^ 2 + (pwy - magicState.lastY) ^ 2)
    if magicState.key == key and moved < 22 and (now - magicState.lastReqAt) < 3.0 then
        return
    end
    if (now - magicState.lastReqAt) < 1.0 and magicState.key == key then
        return
    end
    -- busca do mesmo destino ainda rodando: deixar terminar (cancelar e recomeçar a cada 3 s
    -- impedia rotas longas de chegar ao fim); só desiste após 15 s
    if magicState.key == key and magicState.job and (now - (magicState.jobAt or 0)) < 15 then
        return
    end

    local tInst, vec = Safe(CMap.GetWorldPosFromMapPos, tMap, _G.CreateVector2D(tx, ty))
    local twx, twy
    if vec and vec.GetXY then twx, twy = vec:GetXY() end
    if not (tInst and tInst == pInst and twx and twy) then
        Why("alvo em outra instância/sem posição: tMap=" .. tostring(tMap) .. " tInst=" .. tostring(tInst) .. " pInst=" .. tostring(pInst))
        return
    end

    local isNewKey = (magicState.key ~= key)
    if magicState.job and eng.Cancel then pcall(eng.Cancel, magicState.job) end
    if isNewKey and magicState.coarseJob and eng.Cancel then
        pcall(eng.Cancel, magicState.coarseJob)
        magicState.coarseJob = nil
    end
    if isNewKey then magicState.hasFine = false end
    magicState.key = key
    magicState.lastReqAt = now
    magicState.lastX, magicState.lastY = pwx, pwy

    local fromPt = { x = pwx, y = pwy }
    local toPt = { x = twx, y = twy }

    if isNewKey and eng.FindCoarse then
        magicState.coarseJob = eng.FindCoarse(pInst, fromPt, toPt, function(path, reason)
            magicState.coarseJob = nil
            if magicState.key ~= key or magicState.hasFine then return end
            if not ApplyMagicPathResult(path, tMap, pInst) then Why("rota grossa falhou: " .. tostring(reason)) end
        end, nil, true)
        if magicState.coarseJob then magicState.coarseJob.urgent = true end
    end

    local job
    job = eng.Find(pInst, fromPt, toPt, function(path, reason)
        if magicState.job == job then magicState.job = nil end
        if magicState.key ~= key then return end
        Why("rota fina: " .. (type(path) == "table" and (#path .. " pontos") or ("falhou: " .. tostring(reason))))
        -- falha da fina não apaga a grossa já desenhada; tenta de novo no próximo ciclo
        if not ApplyMagicPathResult(path, tMap, pInst) then return end
        magicState.hasFine = true
        if magicState.coarseJob and eng.Cancel then
            pcall(eng.Cancel, magicState.coarseJob)
            magicState.coarseJob = nil
        end
    end)
    magicState.job, magicState.jobAt = job, now
    if magicState.job then magicState.job.urgent = true; Why("pedido enviado, aguardando o motor") else Why("eng.Find devolveu nil") end
end

local function NextMagicSteer()
    local nodes = magicState.nodes
    if not (M.db and M.db.magicPath ~= false and nodes and #nodes >= 2 and _G.UnitPosition) then return end
    local pwx, pwy = Safe(_G.UnitPosition, "player")
    if not (pwx and pwy) then return end
    local idx = magicState.idx or 2
    while idx < #nodes do
        local nd = nodes[idx]
        local d = sqrt((nd.wx - pwx) ^ 2 + (nd.wy - pwy) ^ 2)
        if d > 14 then break end
        idx = idx + 1
    end
    magicState.idx = idx
    local target = nodes[idx] or nodes[#nodes]
    local dNorth = target.wx - pwx
    local dEast = -(target.wy - pwy)
    local angle = (atan2(dEast, dNorth) * RAD2DEG) % 360
    return angle, magicState.totalYds
end

function M:GetMagicPath()
    if not (self.db and self.db.magicPath ~= false and magicState.nodes) then return nil end
    return magicState
end

function M:SetMagicPathEnabled(on)
    if not self.db then return end
    self.db.magicPath = on and true or false
    if not self.db.magicPath then ClearMagicPath() end
    UpdateNavigation(true)
end

local currentInfo = {
    questID    = nil,
    distance   = nil,
    state      = nil,
    clamped    = false,
    indoors    = false,
    elevation  = nil,   -- "diff" (outro nível) | nil
    contextTag = nil,   -- "Lá fora" | "Na área" | "Dentro / Oculto" | "Desnível N m"
    mapX       = nil,
    mapY       = nil,
}

local function NavSupported()
    return _G.C_SuperTrack ~= nil and _G.C_Navigation ~= nil and type(_G.C_Navigation.GetFrame) == "function"
end

--------------------------------------------------------------------------------
-- Posição da missão no mapa atual (NextWaypoint -> GetQuestsOnMap -> QuestAreaData)
-- Para missões ainda NÃO aceitas (!), usa exclusivamente a posição do NPC/objeto
-- que entrega a missão (QuestDB: sMap, sX, sY), nunca os objetivos.
--------------------------------------------------------------------------------
local function IsQuestInLog(questID)
    if not (questID and questID > 0) then return false end
    local QL = _G.C_QuestLog
    if QL and QL.GetLogIndexForQuestID then
        local idx = Safe(QL.GetLogIndexForQuestID, questID)
        if idx and idx > 0 then return true end
    end
    if Azaath.API and Azaath.API.NumQuestLogEntries then
        for i = 1, Azaath.API.NumQuestLogEntries() do
            local _, _, _, _, isHeader, _, _, id = Azaath.API.QuestInfo8(i)
            if not isHeader and id == questID then return true end
        end
    end
    return false
end

local function GetUnacceptedQuestPos(questID)
    if not (questID and questID > 0) or IsQuestInLog(questID) then return end
    local qdb = Azaath:GetModule("QuestDB")
    local q = qdb and qdb.GetQuest and qdb:GetQuest(questID)
    if q and q.sMap and q.sX and q.sY and q.sX > 0 and q.sY > 0 then
        return q.sMap, q.sX / 100, q.sY / 100
    end
end

-- Pontos dos objetivos ainda não cumpridos (Data/Map/QuestAreas.lua) no mapa pedido, em 0..1.
-- A posição que o jogo dá (GetQuestsOnMap / GetNextWaypoint) erra em algumas missões no Forever
-- (ex.: 1032, sátiros no leste de Vale Gris, marcada onde o jogador estava).
local areaCache = {}
local function AreaToMap(D, srcMap, f, x, y, mapID)
    if f == 0 then
        local fr = D.frames and D.frames[srcMap]
        local CMap = _G.C_Map
        if fr and CMap and CMap.GetMapPosFromWorldPos and _G.CreateVector2D then
            local wy = fr[2] + (fr[3] - fr[2]) * y / 100
            local wx = fr[4] + (fr[5] - fr[4]) * x / 100
            local _, mvec = Safe(CMap.GetMapPosFromWorldPos, fr[1], _G.CreateVector2D(wy, wx), mapID)
            if mvec and mvec.GetXY then
                local mx, my = mvec:GetXY()
                if mx and my and mx >= 0 and mx <= 1 and my >= 0 and my <= 1 then return mx, my end
            end
        end
    end
    if srcMap == mapID then return x / 100, y / 100 end
end

local function QuestAreaPoints(questID, mapID)
    local key = questID .. ":" .. mapID
    local c = areaCache[key]
    local now = GetTime()
    if c and now - c.t < 5 then return c.pts end
    local pts = {}
    local D = Azaath.QuestAreaData
    local per = D and D.quests and D.quests[questID]
    if per and D.spawns then
        local QL = _G.C_QuestLog
        local objs = (QL and QL.GetQuestObjectives and Safe(QL.GetQuestObjectives, questID)) or {}
        for i, keys in ipairs(per) do
            local o = objs[i]
            if keys ~= "" and not (o and o.finished) then
                for k in keys:gmatch("[^%s,]+") do
                    local raw = D.spawns[k]
                    if raw then
                        for seg in raw:gmatch("[^|]+") do
                            local m, f, rest = seg:match("^(%d+),(%d+):(.+)$")
                            m, f = tonumber(m), tonumber(f)
                            if m and rest then
                                for sx, sy, sr in rest:gmatch("([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)") do
                                    local mx, my = AreaToMap(D, m, f, tonumber(sx), tonumber(sy), mapID)
                                    if mx then pts[#pts + 1] = { mx, my, tonumber(sr) or 0 } end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    areaCache[key] = { t = now, pts = pts }
    return pts
end

-- ponto da área mais perto do jogador (sem posição do jogador: o de maior raio = grupo principal)
local function QuestAreaPos(questID, mapID)
    local pts = QuestAreaPoints(questID, mapID)
    if #pts == 0 then return end
    local CMap = _G.C_Map
    local pPos = CMap and CMap.GetPlayerMapPosition and Safe(CMap.GetPlayerMapPosition, mapID, "player")
    local px, py
    if pPos and pPos.GetXY then px, py = pPos:GetXY() end
    local best, bestV
    for _, p in ipairs(pts) do
        local v
        if px and py then v = (p[1] - px) ^ 2 + (p[2] - py) ^ 2 else v = -p[3] end
        if not bestV or v < bestV then best, bestV = p, v end
    end
    return best[1], best[2]
end

function M:GetQuestAreaPos(questID, mapID)
    if not (questID and mapID) then return end
    return QuestAreaPos(questID, mapID)
end

local function GetQuestTargetMapPos(questID, mapID)
    if not (questID and questID > 0 and mapID) then return end
    if not IsQuestInLog(questID) then
        local uMap, ux, uy = GetUnacceptedQuestPos(questID)
        if uMap and ux and uy then
            if uMap == mapID then return ux, uy end
            local CMap = _G.C_Map
            if CMap and CMap.GetWorldPosFromMapPos and CMap.GetMapPosFromWorldPos and _G.CreateVector2D then
                local inst, wvec = Safe(CMap.GetWorldPosFromMapPos, uMap, _G.CreateVector2D(ux, uy))
                if inst and wvec then
                    local _, mvec = Safe(CMap.GetMapPosFromWorldPos, inst, wvec, mapID)
                    if mvec and mvec.GetXY then
                        local mx, my = mvec:GetXY()
                        if mx and my then return mx, my end
                    end
                end
            end
        end
        return
    end
    local QL = _G.C_QuestLog

    -- objetivo em andamento: as áreas dos nossos dados vêm antes da posição do jogo
    local done = QL and QL.IsComplete and Safe(QL.IsComplete, questID)
    if done ~= true then
        local ax, ay = QuestAreaPos(questID, mapID)
        if ax and ay then return ax, ay end
    end

    if QL and QL.GetNextWaypoint then
        local wx, wy = Safe(QL.GetNextWaypoint, questID)
        if wx and wy and (wx > 0 or wy > 0) then
            return wx, wy
        end
    end

    if QL and QL.GetQuestsOnMap then
        local list = Safe(QL.GetQuestsOnMap, mapID)
        if type(list) == "table" then
            for _, q in ipairs(list) do
                if q.questID == questID and q.x and q.y then
                    return q.x, q.y
                end
            end
        end
    end

    -- (as áreas de QuestAreas.lua já foram tentadas no começo, para objetivo em andamento)
end

local function ComputeMapVector(questID)
    local CMap = _G.C_Map
    if not (CMap and CMap.GetBestMapForUnit and CMap.GetPlayerMapPosition) then return end
    local mapID = Safe(CMap.GetBestMapForUnit, "player")
    if not mapID then return end

    local pPos = Safe(CMap.GetPlayerMapPosition, mapID, "player")
    if not pPos then return end
    local px, py = pPos:GetXY()
    if not (px and py) then return end

    local tx, ty = GetQuestTargetMapPos(questID, mapID)
    if not (tx and ty) then return end

    local dx = tx - px
    local dy = ty - py
    local angle = (atan2(dx, -dy) * RAD2DEG) % 360

    local distYards
    if CMap.GetMapWorldSize then
        local w, h = Safe(CMap.GetMapWorldSize, mapID)
        if w and h and w > 0 and h > 0 then
            distYards = sqrt((dx * w) ^ 2 + (dy * h) ^ 2)
        end
    end
    return angle, distYards, tx, ty, mapID
end

--------------------------------------------------------------------------------
-- Foco / SuperTrack (100% funcional em combate)
--------------------------------------------------------------------------------
local function ApplySuperTrack(qid)
    pendingSuperTrack = false
    if not (M.db and M.db.enabled) then return end
    if InCombatLockdown and InCombatLockdown() then
        pendingSuperTrack = true
        return
    end

    if _G.GetCVar and _G.SetCVar and _G.GetCVar("inGameNavigation") == "0" then
        Safe(_G.SetCVar, "inGameNavigation", "1")
    end

    local st = _G.C_SuperTrack
    if not qid then
        if usingUserWaypoint and _G.C_Map and _G.C_Map.ClearUserWaypoint then
            Safe(_G.C_Map.ClearUserWaypoint)
        end
        usingUserWaypoint = false
        if st and st.SetSuperTrackedQuestID then Safe(st.SetSuperTrackedQuestID, 0) end
        return
    end

    if usingUserWaypoint and _G.C_Map and _G.C_Map.ClearUserWaypoint then
        Safe(_G.C_Map.ClearUserWaypoint)
        usingUserWaypoint = false
    end

    if st and st.SetSuperTrackedQuestID then
        Safe(st.SetSuperTrackedQuestID, qid)
    end
    pendingNativeCheckAt = GetTime() + 0.25
end

local PlaceFallbackUserWaypoint

-- O pin 3D do jogo segue o ponto do usuário (no Forever o SuperTrack de missão não pega) e esse
-- ponto sobrevive ao /reload: se ficou velho ou o alvo mudou, recoloca no alvo atual.
local lastWpSyncAt = 0
local function SyncQuestUserWaypoint(qid, now)
    if not qid or customTarget or now - lastWpSyncAt < 1 then return end
    lastWpSyncAt = now
    if InCombatLockdown and InCombatLockdown() then return end
    local st, CMap = _G.C_SuperTrack, _G.C_Map
    if not (CMap and CMap.GetBestMapForUnit and CMap.GetUserWaypoint) then return end
    local mapID = Safe(CMap.GetBestMapForUnit, "player")
    if not mapID then return end
    -- rastrear a missão em si faz o jogo usar a posição dele (errada em algumas, ex.: 1032).
    -- Objetivo em andamento com área nos nossos dados: o pin segue o nosso ponto.
    local QL = _G.C_QuestLog
    local done = QL and QL.IsComplete and Safe(QL.IsComplete, qid) == true
    local ownArea = not done and QuestAreaPos(qid, mapID)
    if not ownArea and st and st.GetSuperTrackedQuestID and Safe(st.GetSuperTrackedQuestID) == qid then return end
    local tx, ty = GetQuestTargetMapPos(qid, mapID)
    if not (tx and ty) then return end
    local wp = Safe(CMap.GetUserWaypoint)
    local wx, wy
    if wp and wp.position and wp.position.GetXY then wx, wy = wp.position:GetXY() end
    local tracking = st and st.IsSuperTrackingUserWaypoint and Safe(st.IsSuperTrackingUserWaypoint)
    if wp and wp.uiMapID == mapID and wx and abs(wx - tx) < 0.004 and abs(wy - ty) < 0.004 and tracking then return end
    PlaceFallbackUserWaypoint(qid)
end

PlaceFallbackUserWaypoint = function(qid)
    if InCombatLockdown and InCombatLockdown() then return end
    local CMap = _G.C_Map
    local st = _G.C_SuperTrack
    if not (CMap and CMap.SetUserWaypoint and _G.UiMapPoint and _G.UiMapPoint.CreateFromCoordinates and st and st.SetSuperTrackedUserWaypoint) then
        return
    end
    local _, _, tx, ty, mapID = ComputeMapVector(qid)
    if not (mapID and tx and ty) then return end
    local pt = Safe(_G.UiMapPoint.CreateFromCoordinates, mapID, tx, ty)
    if pt then
        Safe(CMap.SetUserWaypoint, pt)
        Safe(st.SetSuperTrackedUserWaypoint, true)
        usingUserWaypoint = true
    end
end

function M:GetFocusedQuest()
    return focusedQuestID
end

function M:SetFocusedQuest(questID, fromMap)
    ClearMagicPath()
    customTarget = nil
    focusedQuestID = (questID and questID > 0) and questID or nil
    userPicked = (focusedQuestID ~= nil) and not M.autoFocusing
    userQuestWasInLog = focusedQuestID ~= nil and IsQuestInLog(focusedQuestID)
    ApplySuperTrack(focusedQuestID)

    if not fromMap then
        local wm = Azaath:GetModule("WorldMap")
        if wm and wm.api and wm.api.SelectQuest then
            wm.api.SelectQuest(focusedQuestID, true)
        end
    end
    local qt = Azaath:GetModule("QuestTracker")
    if qt and qt.Refresh then qt:Refresh() end
    UpdateNavigation(true)
    local cp = Azaath:GetModule("Compass")
    if cp and cp.UpdateHeading then cp:UpdateHeading(true) end
end

function M:SetCustomWaypoint(mapID, xPct, yPct, label)
    if not (mapID and xPct and yPct) then return end
    ClearMagicPath()
    focusedQuestID = nil
    customTarget = { mapID = mapID, x = xPct / 100, y = yPct / 100, label = label or "Destino" }
    userPicked = not M.autoFocusing
    UpdateMagicPath(mapID, customTarget.x, customTarget.y)
    if not (InCombatLockdown and InCombatLockdown()) then
        local CMap, st = _G.C_Map, _G.C_SuperTrack
        if CMap and CMap.SetUserWaypoint and _G.UiMapPoint and _G.UiMapPoint.CreateFromCoordinates then
            local pt = Safe(_G.UiMapPoint.CreateFromCoordinates, mapID, customTarget.x, customTarget.y)
            if pt then
                Safe(CMap.SetUserWaypoint, pt)
                usingUserWaypoint = true
                if st and st.SetSuperTrackedUserWaypoint then
                    Safe(st.SetSuperTrackedUserWaypoint, true)
                end
            end
        end
    end
    local qt = Azaath:GetModule("QuestTracker")
    if qt and qt.Refresh then qt:Refresh() end
    UpdateNavigation(true)
    local cp = Azaath:GetModule("Compass")
    if cp and cp.UpdateHeading then cp:UpdateHeading(true) end
end

function M:GetCustomWaypoint()
    return customTarget
end

-- tira o destino personalizado (pin do mapa): caminho mágico, marcador do jogo e bússola
function M:ClearCustomWaypoint()
    if not customTarget or customTarget.isCorpse then return end
    customTarget = nil
    userPicked = false
    ClearMagicPath()
    if _G.C_Map and _G.C_Map.ClearUserWaypoint then Safe(_G.C_Map.ClearUserWaypoint) end
    usingUserWaypoint = false
    local qt = Azaath:GetModule("QuestTracker")
    if qt and qt.Refresh then qt:Refresh() end
    UpdateNavigation(true)
    local cp = Azaath:GetModule("Compass")
    if cp and cp.UpdateHeading then cp:UpdateHeading(true) end
end

-- true enquanto o destino atual foi escolhido pelo jogador e ainda vale:
-- missão segue até ser entregue/abandonada; ponto do mapa até chegar (< 10 jardas)
function M:HasUserTarget()
    if not userPicked then return false end
    if customTarget then
        if customTarget.isCorpse then return true end
        local d = currentInfo.distance
        if type(d) == "number" and d >= 0 and d < 10 then userPicked = false end
    elseif focusedQuestID then
        local inLog = IsQuestInLog(focusedQuestID)
        if inLog then
            userQuestWasInLog = true
        elseif userQuestWasInLog then
            userPicked = false
        end
    else
        userPicked = false
    end
    return userPicked
end

function M:GetNavInfo()
    return currentInfo
end

function M:GetCompassVector()
    if not (self.db and self.db.enabled and self.db.compassPin) then return end
    if customTarget then
        local CMap = _G.C_Map
        local tMap = customTarget.mapID
        local pPos = tMap and CMap and CMap.GetPlayerMapPosition and Safe(CMap.GetPlayerMapPosition, tMap, "player")
        local px, py
        if pPos and pPos.GetXY then px, py = pPos:GetXY() end
        if px and py then
            local dx, dy = customTarget.x - px, customTarget.y - py
            local angle = (atan2(dx, -dy) * RAD2DEG) % 360
            local distYards = currentInfo.distance
            if not distYards and CMap.GetMapWorldSize then
                local w, h = Safe(CMap.GetMapWorldSize, tMap)
                if w and h and w > 0 and h > 0 then distYards = sqrt((dx * w) ^ 2 + (dy * h) ^ 2) end
            end
            local mAngle, mDist = NextMagicSteer()
            if mAngle then angle = mAngle end
            return angle, mDist or distYards
        end
        return
    end
    local qid = self:GetFocusedQuest()
    if not qid then return end
    local angle, distYards = ComputeMapVector(qid)
    if not angle then return end
    return angle, currentInfo.distance or distYards
end

--------------------------------------------------------------------------------
-- Marcador na tela (3D nativo via C_Navigation ou projeção direcional Azaath)
--------------------------------------------------------------------------------
local function FormatDist(yards)
    if not yards then return "" end
    if yards < 10 then return "Perto" end
    if yards >= 1000 then return format("%.1f km", yards / 1000) end
    return format("%d m", floor(yards + 0.5))
end

local function BuildMarker()
    if markerFrame then return end
    local c, media = Azaath.colors, Azaath.media

    local f = CreateFrame("Frame", "AzaathUIQuestNavMarker", UIParent)
    f:SetSize(48, 48)
    f:SetFrameStrata("MEDIUM")
    f:Hide()

    f.outer = f:CreateTexture(nil, "ARTWORK")
    f.outer:SetTexture(media.path .. "Diamond")
    f.outer:SetSize(24, 24)
    f.outer:SetPoint("CENTER", f, "CENTER", 0, 0)
    f.outer:SetVertexColor(c.gold[1], c.gold[2], c.gold[3], 0.95)

    f.inner = f:CreateTexture(nil, "OVERLAY")
    f.inner:SetTexture(media.path .. "Diamond")
    f.inner:SetSize(15, 15)
    f.inner:SetPoint("CENTER", f.outer, "CENTER", 0, 0)
    f.inner:SetVertexColor(c.dark[1], c.dark[2], c.dark[3], 0.95)

    f.dot = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.dot:SetTexture(media.path .. "Diamond")
    f.dot:SetSize(7, 7)
    f.dot:SetPoint("CENTER", f.outer, "CENTER", 0, 0)
    f.dot:SetVertexColor(c.gold[1], c.gold[2], c.gold[3], 1)

    f.distText = f:CreateFontString(nil, "OVERLAY")
    f.distText:SetFont(media.font, 11, "OUTLINE")
    f.distText:SetPoint("TOP", f.outer, "BOTTOM", 0, -2)
    f.distText:SetTextColor(1, 1, 1, 0.95)

    f.tagText = f:CreateFontString(nil, "OVERLAY")
    f.tagText:SetFont(media.font, 10, "OUTLINE")
    f.tagText:SetPoint("BOTTOM", f.outer, "TOP", 0, 2)
    f.tagText:SetTextColor(c.gold[1], c.gold[2], c.gold[3], 0.95)

    markerFrame = f
end

-- vert = desnível em jardas (distância 3D do motor contra a distância no mapa, que é só
-- horizontal). A posição do pin na tela não serve: muda com a inclinação da câmera e
-- trocava Acima/Abaixo. O sentido (cima/baixo) não é exposto pelo cliente, só o tamanho.
local function ComputeContextTag(state, clamped, indoors, dist, vert)
    local elev
    if vert and vert >= 7 and dist and dist < 90 then elev = "diff" end

    if elev then
        return format("Desnível %d m", floor(vert + 0.5)), elev
    elseif state == NAV_IN_AREA or (dist and dist < 35) then
        return indoors and "Na área - aqui dentro" or "Na área", nil
    elseif indoors then
        -- Jogador está em ambiente fechado e o objetivo está longe -> objetivo lá fora
        return "Lá fora", nil
    elseif state == NAV_OCCLUDED and dist and dist < 140 then
        -- Jogador está do lado de fora e o marcador está ocluso perto -> dentro/atrás de algo
        return "Dentro / Oculto", nil
    end
    return nil, nil
end

local function PaintMarker(dist, tag, state, clamped)
    local c = Azaath.colors
    if state == NAV_IN_AREA or (dist and dist < 35) then
        markerFrame.outer:SetVertexColor(0.38, 0.92, 0.58, 0.95)
        markerFrame.dot:SetVertexColor(0.38, 0.92, 0.58, 1)
    elseif state == NAV_OCCLUDED then
        markerFrame.outer:SetVertexColor(1.00, 0.65, 0.28, 0.92)
        markerFrame.dot:SetVertexColor(1.00, 0.65, 0.28, 1)
    else
        markerFrame.outer:SetVertexColor(c.gold[1], c.gold[2], c.gold[3], 0.95)
        markerFrame.dot:SetVertexColor(c.gold[1], c.gold[2], c.gold[3], 1)
    end
    markerFrame.distText:SetText(FormatDist(dist))
    markerFrame.tagText:SetText(tag or "")
    markerFrame:SetAlpha(clamped and 0.72 or 0.96)
    markerFrame:Show()
end

local lastSync = 0
local lastTargetAt, cachedQid, cachedMapID, cachedTx, cachedTy = 0, nil, nil, nil, nil

local function GetCachedTargetPos(qid, mapID)
    local now = GetTime()
    if cachedQid == qid and cachedMapID == mapID and (now - lastTargetAt) < 0.5 and cachedTx then
        return cachedTx, cachedTy
    end
    lastTargetAt, cachedQid, cachedMapID = now, qid, mapID
    cachedTx, cachedTy = GetQuestTargetMapPos(qid, mapID)
    return cachedTx, cachedTy
end

local function ComputeFastMapVector(questID)
    local CMap = _G.C_Map
    if not (CMap and CMap.GetBestMapForUnit and CMap.GetPlayerMapPosition) then return end
    local mapID = Safe(CMap.GetBestMapForUnit, "player")
    if not mapID then return end

    local pPos = Safe(CMap.GetPlayerMapPosition, mapID, "player")
    if not pPos then return end
    local px, py = pPos:GetXY()
    if not (px and py) then return end

    local tx, ty = GetCachedTargetPos(questID, mapID)
    if not (tx and ty) then return end

    local dx, dy = tx - px, ty - py
    local angle = (atan2(dx, -dy) * RAD2DEG) % 360

    local distYards
    if CMap.GetMapWorldSize then
        local w, h = Safe(CMap.GetMapWorldSize, mapID)
        if w and h and w > 0 and h > 0 then
            distYards = sqrt((dx * w) ^ 2 + (dy * h) ^ 2)
        end
    end
    return angle, distYards, tx, ty, mapID
end

--------------------------------------------------------------------------------
-- NPC do destino pela placa de nome: âncora 3D exata (o pin do motor usa a altura
-- do chão sob a coordenada do mapa e erra NPC em andar de cima / porão).
--------------------------------------------------------------------------------
local plateNpc = {}   -- unidade da placa -> id do NPC (lido ao surgir a placa)
local npcCacheAt, npcCacheQid, npcCacheId = 0, nil, nil

local function NpcIdFromUnit(unit)
    local g = Safe(_G.UnitGUID, unit)
    if type(g) ~= "string" or (_G.issecretvalue and _G.issecretvalue(g)) then return end
    local kind, _, _, _, _, id = strsplit("-", g)
    if kind == "Creature" then return tonumber(id) end
end

-- quem está no destino: missão não aceita = quem dá; pronta para entregar = quem recebe
local function TargetNpcId(qid)
    if customTarget or not qid then return end
    local now = GetTime()
    if npcCacheQid == qid and now - npcCacheAt < 1 then return npcCacheId end
    npcCacheAt, npcCacheQid, npcCacheId = now, qid, nil
    local qdb = Azaath:GetModule("QuestDB")
    local q = qdb and qdb.GetQuest and qdb:GetQuest(qid)
    if not q then return end
    if not IsQuestInLog(qid) then
        npcCacheId = q.startId
    else
        local QL = _G.C_QuestLog
        local done = QL and ((QL.ReadyForTurnIn and Safe(QL.ReadyForTurnIn, qid))
            or (QL.IsComplete and Safe(QL.IsComplete, qid)))
        if done == true then npcCacheId = q.endId end
    end
    return npcCacheId
end

local function FindTargetPlate(qid)
    local npc = TargetNpcId(qid)
    local CNP = _G.C_NamePlate
    if not (npc and npc > 0 and CNP and CNP.GetNamePlateForUnit) then return end
    for unit, id in pairs(plateNpc) do
        if id == npc then
            local plate = Safe(CNP.GetNamePlateForUnit, unit)
            if plate and not (plate.IsForbidden and plate:IsForbidden()) and plate:IsVisible() then
                return plate
            end
        end
    end
end

-- desnível: distância 3D do motor contra a horizontal no mapa (só perto, onde é confiável)
local function VerticalYards(dist3d, tMap, tx, ty)
    if not (dist3d and dist3d > 0 and dist3d < 90 and tMap and tx and ty) then return end
    local CMap = _G.C_Map
    if not (CMap and CMap.GetPlayerMapPosition and CMap.GetMapWorldSize) then return end
    local pPos = Safe(CMap.GetPlayerMapPosition, tMap, "player")
    local px, py
    if pPos and pPos.GetXY then px, py = pPos:GetXY() end
    local w, h = Safe(CMap.GetMapWorldSize, tMap)
    if not (px and py and w and h and w > 0 and h > 0) then return end
    local horiz = sqrt(((tx - px) * w) ^ 2 + ((ty - py) * h) ^ 2)
    if dist3d <= horiz then return 0 end
    local v = sqrt(dist3d * dist3d - horiz * horiz)
    -- diferença pequena perto do alvo é ruído entre a coordenada do mapa e a do motor
    if v < horiz * 0.3 then return 0 end
    return v
end

local lastNativeAt = 0
local NATIVE_GRACE = 0.75   -- segura o pin quando o motor some por instantes (evita piscar)

local lastTextAt = 0
UpdateNavigation = function(forceText)
    if not (M.db and M.db.enabled) then
        if markerFrame then markerFrame:Hide() end
        return
    end

    local qid = focusedQuestID
    currentInfo.questID = qid
    currentInfo.indoors = IsIndoors and (IsIndoors() == true) or false

    -- rastreia cadáver dinamicamente enquanto fantasma
    if _G.UnitIsGhost and _G.UnitIsGhost("player") then
        local CMap = _G.C_Map
        local CDeath = _G.C_DeathInfo
        if CMap and CDeath and CDeath.GetCorpseMapPosition and CMap.GetBestMapForUnit then
            local mapID = Safe(CMap.GetBestMapForUnit, "player")
            if mapID then
                local cPos = Safe(CDeath.GetCorpseMapPosition, mapID)
                if cPos and cPos.GetXY then
                    local cx, cy = cPos:GetXY()
                    if cx and cy and (cx ~= 0 or cy ~= 0) then
                        customTarget = { mapID = mapID, x = cx, y = cy, label = "Cadáver", isCorpse = true }
                    end
                end
            end
        end
    elseif customTarget and customTarget.isCorpse then
        customTarget = nil
    end

    if not qid and not customTarget then
        Why("sem missão em foco (rastreie uma missão)")
        currentInfo.distance = nil
        currentInfo.state = nil
        currentInfo.contextTag = nil
        currentInfo.elevation = nil
        if markerFrame then markerFrame:Hide() end
        return
    end

    local now = GetTime()
    SyncQuestUserWaypoint(qid, now)
    local updateText = forceText or (now - lastTextAt >= 0.15)
    if updateText then lastTextAt = now end

    local navFrame, dist, state, clamped
    if NavSupported() and not navGone then
        local CNav = _G.C_Navigation
        navFrame = Safe(CNav.GetFrame)
        dist = Safe(CNav.GetDistance)
        state = Safe(CNav.GetTargetState)
        clamped = Safe(CNav.WasClampedToScreen) and true or false
    end

    local nx, ny
    if navFrame and navFrame.GetCenter then nx, ny = Safe(navFrame.GetCenter, navFrame) end
    -- no Forever GetTargetState devolve 0 (Invalid) mesmo com o pin ativo e distância válida
    -- (visto no navDiag): a distância positiva também confirma o pin nativo
    local hasNative3D = navFrame and navFrame:IsVisible() and nx and ny and (nx ~= 0 or ny ~= 0)
        and (state ~= NAV_INVALID or (type(dist) == "number" and dist > 0))

    -- diagnóstico (SavedVariables: questnav.navDiag): por que o pin nativo está ou não ativo
    if updateText then
        local st, CMap = _G.C_SuperTrack, _G.C_Map
        local d = format("sup=%s gone=%s frame=%s vis=%s state=%s ctr=%s,%s dist=%s clamp=%s cvar=%s stQ=%s stWp=%s hasWp=%s userWp=%s qid=%s",
            tostring(NavSupported()), tostring(navGone), tostring(navFrame ~= nil),
            tostring(navFrame and navFrame:IsVisible()), tostring(state),
            tostring(nx and floor(nx)), tostring(ny and floor(ny)), tostring(dist), tostring(clamped),
            tostring(_G.GetCVar and Safe(_G.GetCVar, "inGameNavigation")),
            tostring(st and st.GetSuperTrackedQuestID and Safe(st.GetSuperTrackedQuestID)),
            tostring(st and st.IsSuperTrackingUserWaypoint and Safe(st.IsSuperTrackingUserWaypoint)),
            tostring(CMap and CMap.HasUserWaypoint and Safe(CMap.HasUserWaypoint)),
            tostring(usingUserWaypoint), tostring(qid))
        if M.db.navDiag == nil or M.db.navDiag.d ~= d then
            M.db.navDiag = { time = date("%H:%M:%S"), d = d, native = hasNative3D and true or false }
        end
    end

    if not hasNative3D and pendingNativeCheckAt > 0 and now >= pendingNativeCheckAt then
        pendingNativeCheckAt = 0
        PlaceFallbackUserWaypoint(qid)
    end

    -- NPC do destino com placa visível: a âncora mais precisa (cabeça do NPC)
    local plate = M.db.worldMarker and FindTargetPlate(qid)

    if hasNative3D then
        pendingNativeCheckAt = 0
        lastNativeAt = now
        currentInfo.distance = (type(dist) == "number" and dist >= 0) and dist or nil
        currentInfo.state = state
        currentInfo.clamped = clamped

        if navFrame.SetAlpha and navFrame:GetAlpha() > 0 then
            navFrame:SetAlpha(0)
        end

        local tMap, tx, ty
        if customTarget then
            tMap, tx, ty = customTarget.mapID, customTarget.x, customTarget.y
        elseif qid then
            local CMap = _G.C_Map
            tMap = CMap and CMap.GetBestMapForUnit and Safe(CMap.GetBestMapForUnit, "player")
            if tMap then tx, ty = GetCachedTargetPos(qid, tMap) end
        end

        if updateText then
            local vert = not clamped and VerticalYards(currentInfo.distance, tMap, tx, ty) or nil
            local tag, elev = ComputeContextTag(state, clamped, currentInfo.indoors, currentInfo.distance, vert)
            currentInfo.contextTag = tag
            currentInfo.elevation = elev
        end

        if M.db.worldMarker then
            if not markerFrame then BuildMarker() end
            markerFrame:ClearAllPoints()
            if plate and not clamped then
                markerFrame:SetPoint("BOTTOM", plate, "TOP", 0, 6)
            else
                markerFrame:SetPoint("CENTER", navFrame, "CENTER", 0, 0)
            end
            if updateText or not markerFrame:IsShown() then
                PaintMarker(currentInfo.distance, currentInfo.contextTag, state, clamped)
            end
            if tMap and tx and ty then
                UpdateMagicPath(tMap, tx, ty)
            end
            return
        end
    elseif M.db.worldMarker and markerFrame and markerFrame:IsShown() and now - lastNativeAt < NATIVE_GRACE then
        -- o motor apagou o pin por instantes (atualização do registro, troca de rastreio):
        -- mantém o losango onde estava em vez de saltar para a projeção direcional
        if plate then
            markerFrame:ClearAllPoints()
            markerFrame:SetPoint("BOTTOM", plate, "TOP", 0, 6)
        end
        return
    end

    -- sem pin do motor mas com a placa do NPC à vista: usa a placa (posição 3D real)
    if plate then
        local _, mapDist = ComputeFastMapVector(qid)
        currentInfo.distance = mapDist
        currentInfo.state, currentInfo.clamped, currentInfo.elevation = nil, false, nil
        currentInfo.contextTag = ComputeContextTag(nil, false, currentInfo.indoors, mapDist, nil)
        markerFrame:ClearAllPoints()
        markerFrame:SetPoint("BOTTOM", plate, "TOP", 0, 6)
        if updateText or not markerFrame:IsShown() then
            PaintMarker(mapDist, currentInfo.contextTag, nil, false)
        end
        return
    end

    -- Fallback direcional na tela (atualiza posição a cada frame para 100% de fluidez)
    local angle, mapDist, tx, ty
    if customTarget then
        local CMap = _G.C_Map
        local tMap = customTarget.mapID
        local pPos = tMap and CMap and CMap.GetPlayerMapPosition and Safe(CMap.GetPlayerMapPosition, tMap, "player")
        local px, py
        if pPos and pPos.GetXY then px, py = pPos:GetXY() end
        if px and py then
            local dx, dy = customTarget.x - px, customTarget.y - py
            angle = (atan2(dx, -dy) * RAD2DEG) % 360
            if CMap.GetMapWorldSize then
                local w, h = Safe(CMap.GetMapWorldSize, tMap)
                if w and h and w > 0 and h > 0 then mapDist = sqrt((dx * w) ^ 2 + (dy * h) ^ 2) end
            end
            tx, ty = customTarget.x, customTarget.y
        end
    else
        angle, mapDist, tx, ty = ComputeFastMapVector(qid)
    end
    if tx and ty then
        local tMap = (customTarget and customTarget.mapID) or (_G.C_Map and _G.C_Map.GetBestMapForUnit and Safe(_G.C_Map.GetBestMapForUnit, "player"))
        if tMap then UpdateMagicPath(tMap, tx, ty) end
        local mAngle, mDist = NextMagicSteer()
        if mAngle then
            angle = mAngle
            if mDist and mDist > 0 then mapDist = mDist end
        end
        magicState.missingSince = nil
    else
        Why("sem posição do alvo no mapa (qid=" .. tostring(qid) .. ")")
        -- a posição da missão some por instantes (registro atualizando): só apaga após 2 s
        magicState.missingSince = magicState.missingSince or now
        if now - magicState.missingSince > 2 then ClearMagicPath() end
    end
    currentInfo.distance = mapDist
    currentInfo.state = nil
    currentInfo.elevation = nil
    currentInfo.mapX, currentInfo.mapY = tx, ty

    local tag = ComputeContextTag(nil, false, currentInfo.indoors, mapDist, nil)
    currentInfo.contextTag = tag

    if M.db.worldMarker and angle and GetPlayerFacing then
        local facing = Safe(GetPlayerFacing)
        if facing then
            if not markerFrame then BuildMarker() end
            local h = (360 - facing * RAD2DEG) % 360
            local delta = (angle - h + 540) % 360 - 180
            local fov = 52
            local offscreen = abs(delta) > fov
            currentInfo.clamped = offscreen

            local sw = UIParent:GetWidth() or 1280
            local sh = UIParent:GetHeight() or 768
            local clampedDelta = delta
            if clampedDelta > fov then clampedDelta = fov
            elseif clampedDelta < -fov then clampedDelta = -fov end

            local x = (clampedDelta / fov) * (sw * 0.42)
            local y = sh * 0.14
            markerFrame:ClearAllPoints()
            markerFrame:SetPoint("CENTER", UIParent, "CENTER", x, y)
            if updateText or not markerFrame:IsShown() then
                PaintMarker(mapDist, tag, nil, offscreen)
            else
                markerFrame:SetAlpha(offscreen and 0.72 or 0.96)
            end
            return
        end
    end

    if markerFrame then markerFrame:Hide() end
end

--------------------------------------------------------------------------------
-- Driver e eventos
--------------------------------------------------------------------------------
local driver = CreateFrame("Frame", nil, UIParent)

driver:SetScript("OnUpdate", function()
    UpdateNavigation(false)

    local now = GetTime()
    if now - lastSync >= 0.4 then
        lastSync = now
        local qt = Azaath:GetModule("QuestTracker")
        if qt and qt.UpdateNavBadge then qt:UpdateNavBadge() end
    end
end)

driver:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        if unit then plateNpc[unit] = NpcIdFromUnit(unit) end
        return
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        if unit then plateNpc[unit] = nil end
        return
    end
    if event == "NAVIGATION_FRAME_CREATED" then
        navGone = false
    elseif event == "NAVIGATION_FRAME_DESTROYED" then
        navGone = true
    elseif event == "PLAYER_REGEN_ENABLED" then
        if pendingSuperTrack then
            ApplySuperTrack(focusedQuestID)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        if not focusedQuestID and _G.C_SuperTrack and _G.C_SuperTrack.GetSuperTrackedQuestID then
            local qid = Safe(_G.C_SuperTrack.GetSuperTrackedQuestID)
            if qid and qid > 0 then focusedQuestID = qid end
        end
    end
    UpdateNavigation()
    local qt = Azaath:GetModule("QuestTracker")
    if qt and qt.Refresh then qt:Refresh() end
end)

function M:OnInitialize()
    self.db = Azaath.db.questnav
end

function M:OnEnable()
    if not (self.db and self.db.enabled) then return end
    -- diagnóstico: resultado do carregamento do motor de rotas (Nav/API.lua) a cada início
    do
        local d, eng = Azaath.navLoadDiag, Azaath.NavEngine
        local avail = {}
        for _, inst in ipairs({ 0, 1 }) do avail[#avail + 1] = inst .. "=" .. tostring(eng and eng.Available and eng.Available(inst)) end
        self.db.navLoadDiag = { time = date("%H:%M:%S"), tag = "fix7", avail = table.concat(avail, " "),
            load = d and ("decodes=" .. tostring(d.decodes) .. " C_EncodingUtil=" .. d.enc .. " b64=" .. d.b64 .. " zlib=" .. d.zlib
                .. " dados=" .. d.data .. " mapas=[" .. d.maps .. "] descartados=[" .. d.dropped .. "]") or "navLoadDiag ausente",
            eng = tostring(eng), loadAddOn = tostring(_G.LoadAddOn) .. " C_AddOns=" .. tostring(_G.C_AddOns) }
    end
    BuildMarker()
    -- placas que já estavam na tela no /reload
    local CNP = _G.C_NamePlate
    if CNP and CNP.GetNamePlates then
        for _, plate in ipairs(Safe(CNP.GetNamePlates) or {}) do
            local u = plate.namePlateUnitToken
            if u then plateNpc[u] = NpcIdFromUnit(u) end
        end
    end
    for _, ev in ipairs({
        "PLAYER_ENTERING_WORLD",
        "PLAYER_REGEN_ENABLED",
        "SUPER_TRACKING_CHANGED",
        "NAVIGATION_FRAME_CREATED",
        "NAVIGATION_FRAME_DESTROYED",
        "QUEST_LOG_UPDATE",
        "ZONE_CHANGED",
        "ZONE_CHANGED_INDOORS",
        "PLAYER_DEAD",
        "PLAYER_ALIVE",
        "PLAYER_UNGHOST",
        "NAME_PLATE_UNIT_ADDED",
        "NAME_PLATE_UNIT_REMOVED",
    }) do
        Azaath.SafeRegister(driver, ev)
    end
    UpdateNavigation()
end

_G.SLASH_AZAATHNAV1 = "/azaathnav"
_G.SlashCmdList["AZAATHNAV"] = function()
    local CMap = _G.C_Map
    local bMap = CMap and CMap.GetBestMapForUnit and Safe(CMap.GetBestMapForUnit, "player")
    local tMap = (customTarget and customTarget.mapID) or bMap
    local pPos = tMap and CMap and CMap.GetPlayerMapPosition and Safe(CMap.GetPlayerMapPosition, tMap, "player")
    local px, py
    if pPos and pPos.GetXY then px, py = pPos:GetXY() end
    local a, d = M:GetCompassVector()
    local eng = Azaath.NavEngine
    local _, _, _, pInst = Safe(_G.UnitPosition, "player")
    print(format("|cff5edee6[Azaath Nav]|r en=%s wm=%s cp=%s mp=%s eng=%s avail=%s nodes=%d bMap=%s px=%s py=%s custom=%s ang=%s dist=%s mk=%s",
        tostring(M.db and M.db.enabled),
        tostring(M.db and M.db.worldMarker),
        tostring(M.db and M.db.compassPin),
        tostring(M.db and M.db.magicPath),
        tostring(eng ~= nil),
        tostring(eng and pInst and eng.Available and eng.Available(pInst)),
        magicState.nodes and #magicState.nodes or 0,
        tostring(bMap),
        tostring(px and format("%.3f", px) or "nil"),
        tostring(py and format("%.3f", py) or "nil"),
        tostring(customTarget and format("%d:%.1f,%.1f", customTarget.mapID, customTarget.x*100, customTarget.y*100) or "nil"),
        tostring(a and floor(a) or "nil"),
        tostring(d and floor(d) or "nil"),
        tostring(markerFrame and markerFrame:IsShown())))
    -- para onde o pin 3D do jogo aponta (ponto do usuário) x alvo do Azaath (bússola / caminho)
    local st = _G.C_SuperTrack
    local wp = CMap and CMap.GetUserWaypoint and Safe(CMap.GetUserWaypoint)
    local wx, wy
    if wp and wp.position and wp.position.GetXY then wx, wy = wp.position:GetXY() end
    local qx, qy
    if focusedQuestID and bMap then qx, qy = GetQuestTargetMapPos(focusedQuestID, bMap) end
    local CNav = _G.C_Navigation
    print(format("|cff5edee6[Azaath Nav]|r qid=%s alvo=%s wp=%s stWp=%s stQ=%s navDist=%s getWp=%s",
        tostring(focusedQuestID),
        qx and format("%d:%.1f,%.1f", bMap, qx * 100, qy * 100) or "nil",
        wx and format("%s:%.1f,%.1f", tostring(wp.uiMapID), wx * 100, wy * 100) or tostring(wp),
        tostring(st and st.IsSuperTrackingUserWaypoint and Safe(st.IsSuperTrackingUserWaypoint)),
        tostring(st and st.GetSuperTrackedQuestID and Safe(st.GetSuperTrackedQuestID)),
        tostring(CNav and CNav.GetDistance and Safe(CNav.GetDistance)),
        tostring(CMap and CMap.GetUserWaypoint ~= nil)))
end
