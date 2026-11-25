--[[----------------------------------------------------------------------------
    AzaathUI - Modules/QuestRoute.lua
    Guia e Rastreador Unificado de Missões (Fase 3 Completa):
      * 100% integrado ao topo do AzaathUIQuestTracker (frame único).
      * 3 Modos de Up:
          1) Livre (none): apenas suas missões acompanhadas abaixo.
          2) Loremaster (loremaster): guia por 100% das missões disponíveis da
             zona escolhida + contador X/Y concluídas na zona.
          3) Tryhard (tryhard): rota curada (Azaath.TryhardRoutes: Leveling,
             Classe, Profissões, Reputação, Colecionáveis, Exploração) com
             passos de voo/lar/nível/item usável e sugestão de próximo mapa.
      * Aba Grande estilo Polestar (740x480) com abas por categoria, busca,
        filtros, progresso % real e prévia dos passos.
      * Automação opcional (AutoQ): aceita/entrega missões automaticamente
        (pausa ao segurar Shift; nunca escolhe recompensa múltipla sozinho).
      * Botão de Item Usável acoplado ao passo quando o passo pede `use`.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("QuestRoute")

local _G = _G
local ipairs, pairs, pcall, type, tonumber = ipairs, pairs, pcall, type, tonumber
local sqrt, floor, min, max, format = math.sqrt, math.floor, math.min, math.max, string.format

local skipped = {}
local currentSteps = {}
local lastAutoKey = nil
local lastLoremasterTopKey = nil

local function Safe(fn, ...)
    if not fn then return end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

local function PlayerMapPos()
    local CMap = _G.C_Map
    if not (CMap and CMap.GetBestMapForUnit and CMap.GetPlayerMapPosition) then return end
    local mapID = Safe(CMap.GetBestMapForUnit, "player")
    if not mapID then return end
    local pos = Safe(CMap.GetPlayerMapPosition, mapID, "player")
    if not pos then return mapID end
    local px, py = pos:GetXY()
    local w, h = 1000, 1000
    if CMap.GetMapWorldSize then
        local mw, mh = Safe(CMap.GetMapWorldSize, mapID)
        if mw and mh and mw > 0 and mh > 0 then w, h = mw, mh end
    end
    return mapID, px, py, w, h
end

local function ZoneName(mapID)
    if not (mapID and mapID > 0 and _G.C_Map and _G.C_Map.GetMapInfo) then return "Zona Atual" end
    local info = Safe(_G.C_Map.GetMapInfo, mapID)
    return (info and info.name) or "Zona Atual"
end

local function GetQuestLogMap()
    local logMap = {}
    local QL = _G.C_QuestLog
    local n = (QL and QL.GetNumQuestLogEntries and Safe(QL.GetNumQuestLogEntries))
           or (GetNumQuestLogEntries and (GetNumQuestLogEntries())) or 0
    for i = 1, n do
        local title, isHeader, isComplete, qid
        if QL and QL.GetInfo then
            local info = Safe(QL.GetInfo, i)
            if info then title, isHeader, isComplete, qid = info.title, info.isHeader, info.isComplete, info.questID end
        elseif GetQuestLogTitle then
            local t, _, _, hdr, _, comp, _, id = GetQuestLogTitle(i)
            title, isHeader, isComplete, qid = t, hdr, (comp == 1), id
        end
        if not isHeader and qid and qid > 0 then
            local done = isComplete or (QL and QL.IsComplete and Safe(QL.IsComplete, qid))
            logMap[qid] = { title = title, done = done and true or false }
        end
    end
    return logMap
end

local function ResolveObjectiveTarget(qid, mapID, cx, cy, w, h)
    local QL = _G.C_QuestLog
    local objs = (QL and QL.GetQuestObjectives and Safe(QL.GetQuestObjectives, qid)) or {}
    local incomplete = {}
    for i, o in ipairs(objs) do
        if o and not o.finished then
            incomplete[#incomplete + 1] = { idx = i, text = o.text }
        end
    end
    if #incomplete == 0 and objs[1] then
        incomplete[1] = { idx = 1, text = objs[1].text }
    end

    local bestObjIdx = incomplete[1] and incomplete[1].idx
    local bestObjText = incomplete[1] and incomplete[1].text
    local D = Azaath.QuestAreaData
    local per = D and D.quests and D.quests[qid]
    local bestX, bestY, bestD2 = nil, nil, math.huge
    if per and D.spawns then
        local tryList = {}
        if #incomplete > 0 then
            for _, inc in ipairs(incomplete) do
                tryList[#tryList + 1] = inc
            end
        else
            for i = 1, #per do
                tryList[#tryList + 1] = { idx = i, text = nil }
            end
        end
        for _, entry in ipairs(tryList) do
            local keys = per[entry.idx]
            if keys and keys ~= "" then
                for key in keys:gmatch("%S+") do
                    local txt = D.spawns[key]
                    if txt then
                        for block in txt:gmatch("[^|]+") do
                            local bm, _, rest = block:match("^(%d+),(%d+):(.*)$")
                            if tonumber(bm) == mapID and rest then
                                for sx, sy in rest:gmatch("([%d%.%-]+),([%d%.%-]+),[%d%.%-]+") do
                                    local x, y = tonumber(sx), tonumber(sy)
                                    if x and y and x > 0 and y > 0 then
                                        local dx = ((x - cx) / 100) * w
                                        local dy = ((y - cy) / 100) * h
                                        local d2 = dx * dx + dy * dy
                                        if d2 < bestD2 then
                                            bestD2, bestX, bestY = d2, x, y
                                            bestObjIdx = entry.idx
                                            if entry.text then bestObjText = entry.text end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return bestX, bestY, bestObjIdx, bestObjText
end

local function FocusStep(step, silent)
    if not step then return end
    local qn = Azaath:GetModule("QuestNav")
    if step.kind == "pickup" or step.kind == "accept" or step.kind == "goto" or step.kind == "enter" or step.kind == "fly" or step.kind == "boat" or step.kind == "zep" then
        if qn and qn.SetCustomWaypoint and step.mapID and step.x and step.y and step.x > 0 then
            qn:SetCustomWaypoint(step.mapID, step.x, step.y, step.title)
        end
        if (step.kind == "pickup" or step.kind == "accept") and step.questID and step.questID > 0 then
            local wm = Azaath:GetModule("WorldMap")
            if wm and wm.api and wm.api.SelectQuest then
                wm.api.SelectQuest(step.questID, true)
            end
        end
    else
        if qn and qn.SetFocusedQuest and step.questID and step.questID > 0 then
            qn:SetFocusedQuest(step.questID)
        end
        if qn and qn.SetCustomWaypoint and step.mapID and step.x and step.y and step.x > 0 then
            local prefix = step.kind == "turnin" and "Entregar: " or ""
            qn:SetCustomWaypoint(step.mapID, step.x, step.y, prefix .. step.title)
        end
    end
    if not silent and step.mapID and step.x and step.y and step.x > 0 and _G.C_Map and _G.C_Map.SetUserWaypoint and _G.UiMapPoint then
        if not (InCombatLockdown and InCombatLockdown()) then
            local pt = Safe(_G.UiMapPoint.CreateFromCoordinates, step.mapID, step.x / 100, step.y / 100)
            if pt then Safe(_G.C_Map.SetUserWaypoint, pt) end
        end
    elseif not silent and (not step.x or step.x <= 0) and (not step.questID or step.questID == 0) and _G.C_Map and _G.C_Map.ClearUserWaypoint then
        if not (InCombatLockdown and InCombatLockdown()) then
            Safe(_G.C_Map.ClearUserWaypoint)
        end
    end
end

local function TerrainPenalty(mapID, x1Pct, y1Pct, x2Pct, y2Pct)
    local eng = Azaath.NavEngine or _G.Polestar_NavEngine
    local CMap = _G.C_Map
    if not (eng and eng.Sight and CMap and CMap.GetWorldPosFromMapPos) then return 1.0 end
    local inst1, p1 = Safe(CMap.GetWorldPosFromMapPos, mapID, { x = x1Pct / 100, y = y1Pct / 100 })
    local inst2, p2 = Safe(CMap.GetWorldPosFromMapPos, mapID, { x = x2Pct / 100, y = y2Pct / 100 })
    if not (inst1 and p1 and inst2 and p2 and inst1 == inst2) then return 1.0 end
    local wx1, wy1 = p1:GetXY()
    local wx2, wy2 = p2:GetXY()
    if not (wx1 and wy1 and wx2 and wy2) then return 1.0 end
    local ok, clear = pcall(eng.Sight, inst1, wx1, wy1, nil, wx2, wy2, nil)
    if ok and clear == false then
        return 1.35
    end
    return 1.0
end

local function BuildLoremasterSteps(mapID, cx, cy, w, h, logMap)
    local qdb = Azaath:GetModule("QuestDB")
    local QL = _G.C_QuestLog
    local activeCoords = {}
    if QL and QL.GetQuestsOnMap then
        for _, p in ipairs(Safe(QL.GetQuestsOnMap, mapID) or {}) do
            if p.questID and p.x and p.y then
                activeCoords[p.questID] = { x = p.x * 100, y = p.y * 100 }
            end
        end
    end

    local candidates, seen = {}, {}
    for qid, ql in pairs(logMap) do
        if not skipped[qid] then
            local q = qdb and qdb:GetQuest(qid)
            local ac = activeCoords[qid]
            local tx, ty, objIdx, objText, detail
            if ql.done then
                if q and q.eMap == mapID and q.eX and q.eY then tx, ty = q.eX, q.eY
                elseif ac then tx, ty = ac.x, ac.y end
                detail = "Missão pronta para entregar"
            else
                local ox, oy, idx, otxt = ResolveObjectiveTarget(qid, mapID, cx, cy, w, h)
                objIdx, objText = idx, otxt
                if ox and oy then tx, ty = ox, oy
                elseif ac then tx, ty = ac.x, ac.y
                elseif q and q.sMap == mapID and q.sX and q.sX > 0 and q.sY and q.sY > 0 then tx, ty = q.sX, q.sY end
                detail = objText or "Completar objetivo"
            end
            if tx and ty then
                seen[qid] = true
                local dx = ((tx - cx) / 100) * w
                local dy = ((ty - cy) / 100) * h
                local yds = sqrt(dx * dx + dy * dy)
                candidates[#candidates + 1] = {
                    questID = qid,
                    skipKey = qid,
                    title   = ql.title or (q and qdb:GetTitle(q)) or ("Quest #" .. qid),
                    kind    = ql.done and "turnin" or "objective",
                    detail  = detail,
                    objIdx  = objIdx,
                    mapID   = mapID,
                    x       = tx,
                    y       = ty,
                    weight  = ql.done and (yds <= 120 and 0.50 or 0.80) or 0.95,
                }
            end
        end
    end

    if qdb and qdb.GetZoneQuests then
        for _, item in ipairs(qdb:GetZoneQuests(mapID)) do
            local q = item.quest
            if item.status == "available" and not q.repeatable and not q.noStarter and not seen[q.id] and not skipped[q.id]
               and q.sMap == mapID and q.sX and q.sX > 0 and q.sY and q.sY > 0 then
                local qx = q.sX
                local qy = q.sY
                local dx = ((qx - cx) / 100) * w
                local dy = ((qy - cy) / 100) * h
                local yds = sqrt(dx * dx + dy * dy)
                local lvlTxt = (q.level and q.level > 0) and format("Nv. %d · ", q.level) or ""
                candidates[#candidates + 1] = {
                    questID = q.id,
                    skipKey = q.id,
                    title   = item.title,
                    kind    = "pickup",
                    detail  = lvlTxt .. "Pegar missão disponível",
                    mapID   = mapID,
                    x       = qx,
                    y       = qy,
                    weight  = (yds <= 120) and 0.65 or 1.20,
                }
            end
        end
    end

    -- Bônus de cluster (quest stacking): objetivos/coletas próximos entre si
    for i, c in ipairs(candidates) do
        if c.kind == "objective" or c.kind == "pickup" then
            local near = 0
            for j, o in ipairs(candidates) do
                if i ~= j and (o.kind == "objective" or o.kind == "pickup") then
                    local dx = ((c.x - o.x) / 100) * w
                    local dy = ((c.y - o.y) / 100) * h
                    if (dx * dx + dy * dy) <= (140 * 140) then
                        near = near + 1
                    end
                end
            end
            if near >= 1 then
                c.weight = c.weight * 0.85
            end
        end
    end

    local steps, rcx, rcy = {}, cx, cy
    while #candidates > 0 and #steps < 12 do
        local hasLocalWork = false
        for _, c in ipairs(candidates) do
            if c.kind == "objective" or c.kind == "pickup" then
                local dx = ((c.x - rcx) / 100) * w
                local dy = ((c.y - rcy) / 100) * h
                if (dx * dx + dy * dy) <= (150 * 150) then
                    hasLocalWork = true
                    break
                end
            end
        end

        local bestIdx, bestScore = 1, math.huge
        for i, c in ipairs(candidates) do
            local dx = ((c.x - rcx) / 100) * w
            local dy = ((c.y - rcy) / 100) * h
            local dist = sqrt(dx * dx + dy * dy)
            local wt = c.weight
            if hasLocalWork and c.kind == "turnin" and dist > 40 then
                wt = 1.15 -- termina o cluster local antes de voltar para entregar
            end
            local tPen = (dist > 30 and dist <= 650) and TerrainPenalty(mapID, rcx, rcy, c.x, c.y) or 1.0
            local stab = (#steps == 0 and lastLoremasterTopKey and c.skipKey == lastLoremasterTopKey) and 0.85 or 1.0
            local score = dist * wt * tPen * stab
            if score < bestScore then bestScore, bestIdx = score, i end
        end
        local pick = table.remove(candidates, bestIdx)
        local pdx = ((pick.x - cx) / 100) * w
        local pdy = ((pick.y - cy) / 100) * h
        pick.yards = sqrt(pdx * pdx + pdy * pdy)
        steps[#steps + 1] = pick
        rcx, rcy = pick.x, pick.y
    end
    lastLoremasterTopKey = steps[1] and steps[1].skipKey or nil
    return steps, nil
end

local function ContinentOf(mapID)
    if not (mapID and mapID > 0) then return 0 end
    if mapID == 2652 then return 12 end -- Shen'dralas -> Kalimdor
    local CMap = _G.C_Map
    if not (CMap and CMap.GetMapInfo) then return 0 end
    local cur = mapID
    for _ = 1, 6 do
        local info = Safe(CMap.GetMapInfo, cur)
        if not info then break end
        if info.mapType == 2 then return info.mapID end
        if not info.parentMapID or info.parentMapID == 0 or info.parentMapID == cur then break end
        cur = info.parentMapID
    end
    return 0
end

local function FindNearestTaxi(mapID, cx, cy)
    local CT = _G.C_TaxiMap
    if not (CT and CT.GetTaxiNodesForMap and mapID and mapID > 0) then return nil end
    local nodes = Safe(CT.GetTaxiNodesForMap, mapID)
    if type(nodes) ~= "table" then return nil end
    local pFac = _G.UnitFactionGroup and Safe(_G.UnitFactionGroup, "player")
    local wantF = (pFac == "Horde" and 1) or (pFac == "Alliance" and 2) or 0
    local best, bestD2 = nil, math.huge
    for _, n in ipairs(nodes) do
        if n.position and (n.faction == 0 or n.faction == wantF) then
            local nx, ny = n.position:GetXY()
            if nx and ny then
                local x, y = nx * 100, ny * 100
                local d2 = (x - (cx or 50)) ^ 2 + (y - (cy or 50)) ^ 2
                if d2 < bestD2 then
                    bestD2 = d2
                    best = { name = n.name or "Mestre de Voo", x = x, y = y, mapID = mapID }
                end
            end
        end
    end
    return best
end


-- Gera passos automáticos de viagem (Voo, Barco, Zepelim) de pMapID -> step1.mapID
local function BuildTravelSteps(pMapID, px, py, destStep)
    if not (pMapID and destStep and destStep.mapID and destStep.mapID > 0) then return {} end
    local dMap = destStep.mapID
    if pMapID == dMap then return {} end

    local pCont = ContinentOf(pMapID)
    local dCont = ContinentOf(dMap)
    local pFac = _G.UnitFactionGroup and Safe(_G.UnitFactionGroup, "player")
    local cx, cy = (px or 0.5) * 100, (py or 0.5) * 100
    local out = {}

    local function AddFlight(fromMap, toName, key)
        if skipped[key] then return end
        local fm = FindNearestTaxi(fromMap, fromMap == pMapID and cx or 50, fromMap == pMapID and cy or 50)
        if fm then
            out[#out + 1] = {
                questID = 0, skipKey = key, kind = "fly",
                title  = "Voar para " .. toName,
                detail = "Fale com " .. fm.name,
                note   = "Vá ao Mestre de Voo (" .. fm.name .. ") e voe para " .. toName,
                mapID  = fromMap, x = fm.x, y = fm.y, yards = 0,
            }
        end
    end

    -- 1. Entre continentes (Reinos do Leste 13 <-> Kalimdor 12)
    if pCont == 13 and dCont == 12 then
        if pFac == "Horde" then
            if pMapID ~= 1420 and pMapID ~= 1434 and pMapID ~= 1458 then
                AddFlight(pMapID, "Clareiras de Tirisfal", "tr:fly:tirisfal")
            end
            if not skipped["tr:zep:org"] then
                local zm = (pMapID == 1434) and 1434 or 1420
                local zx, zy = (zm == 1434) and 31.4 or 60.6, (zm == 1434) and 30.1 or 58.8
                out[#out + 1] = {
                    questID = 0, skipKey = "tr:zep:org", kind = "zep",
                    title  = "Pegar Zepelim para Orgrimmar",
                    detail = "Torre do Zepelim em " .. ZoneName(zm),
                    note   = "Suba na torre e pegue o zepelim até Durotar / Orgrimmar",
                    mapID  = zm, x = zx, y = zy, yards = 0,
                }
            end
        else
            if pMapID ~= 1437 then
                AddFlight(pMapID, "Porto de Menethil (Pantanal)", "tr:fly:menethil")
            end
            local northKal = (dMap == 1438 or dMap == 1439 or dMap == 1440 or dMap == 1448 or dMap == 1452)
            local bx, by = northKal and 4.6 or 9.4, northKal and 57.1 or 59.6
            local destDock = northKal and "Auberdine (Costa Negra)" or "Theramore (Pântano Vadeoso)"
            if not skipped["tr:boat:kal"] then
                out[#out + 1] = {
                    questID = 0, skipKey = "tr:boat:kal", kind = "boat",
                    title  = "Barco para " .. destDock,
                    detail = "Píer de Porto de Menethil (Pantanal)",
                    note   = "Pegue o barco no píer de Porto de Menethil até " .. destDock,
                    mapID  = 1437, x = bx, y = by, yards = 0,
                }
            end
        end
        return out
    elseif pCont == 12 and dCont == 13 then
        if pFac == "Horde" then
            if pMapID ~= 1411 and pMapID ~= 1454 then
                AddFlight(pMapID, "Orgrimmar (Durotar)", "tr:fly:org")
            end
            if not skipped["tr:zep:ek"] then
                out[#out + 1] = {
                    questID = 0, skipKey = "tr:zep:ek", kind = "zep",
                    title  = "Pegar Zepelim para Reinos do Leste",
                    detail = "Torre do Zepelim fora de Orgrimmar",
                    note   = "Pegue o zepelim em Durotar para Clareiras de Tirisfal ou Grom'gol",
                    mapID  = 1411, x = 50.8, y = 13.8, yards = 0,
                }
            end
        else
            if pMapID == 1438 and not skipped["tr:boat:rut"] then
                out[#out + 1] = {
                    questID = 0, skipKey = "tr:boat:rut", kind = "boat",
                    title  = "Barco para Auberdine (Costa Negra)",
                    detail = "Vila de Rut'theran (Teldrassil)",
                    note   = "Pegue o barco em Vila de Rut'theran para Auberdine",
                    mapID  = 1438, x = 54.9, y = 96.8, yards = 0,
                }
            elseif pMapID ~= 1439 then
                AddFlight(pMapID, "Auberdine (Costa Negra)", "tr:fly:aub")
            end
            if not skipped["tr:boat:men"] then
                out[#out + 1] = {
                    questID = 0, skipKey = "tr:boat:men", kind = "boat",
                    title  = "Barco para Porto de Menethil (Pantanal)",
                    detail = "Píer de Auberdine (Costa Negra)",
                    note   = "Pegue o barco em Auberdine até Porto de Menethil",
                    mapID  = 1439, x = 32.4, y = 43.8, yards = 0,
                }
            end
        end
        return out
    end

    -- 2. Mesmo continente: Teldrassil (ilha) <-> Kalimdor
    if pMapID == 1438 and dMap ~= 1438 and not skipped["tr:boat:rut"] then
        out[#out + 1] = {
            questID = 0, skipKey = "tr:boat:rut", kind = "boat",
            title  = "Barco para Auberdine (Costa Negra)",
            detail = "Vila de Rut'theran (Teldrassil)",
            note   = "Pegue o barco no píer de Vila de Rut'theran para sair de Teldrassil",
            mapID  = 1438, x = 54.9, y = 96.8, yards = 0,
        }
        return out
    elseif dMap == 1438 and pMapID ~= 1438 then
        if pMapID ~= 1439 then AddFlight(pMapID, "Auberdine (Costa Negra)", "tr:fly:aub") end
        if not skipped["tr:boat:tel"] then
            out[#out + 1] = {
                questID = 0, skipKey = "tr:boat:tel", kind = "boat",
                title  = "Barco para Teldrassil (Rut'theran)",
                detail = "Píer de Auberdine (Costa Negra)",
                note   = "Pegue o barco em Auberdine até Vila de Rut'theran",
                mapID  = 1439, x = 33.2, y = 40.1, yards = 0,
            }
        end
        return out
    end

    -- 3. Mesmo continente: voo direto para a zona de destino (se houver Mestre de Voo lá)
    local destFM = FindNearestTaxi(dMap, 50, 50)
    if destFM and pCont ~= 0 and pCont == dCont then
        AddFlight(pMapID, destFM.name .. " (" .. ZoneName(dMap) .. ")", "tr:fly:" .. dMap)
    end
    return out
end

function M:GetHeight()
    return 0
end

function M:UpdateCard()
end

function M:Rebuild()
    currentSteps = {}
    if not (self.db and self.db.enabled) then
        return currentSteps
    end

    local mode = self.db.mode or "loremaster"
    if mode == "none" then
        return currentSteps
    end

    local pMapID, px, py, w, h = PlayerMapPos()
    local targetMapID = self.db.selectedMapID or pMapID
    if not targetMapID then
        return currentSteps
    end

    local cx, cy = (pMapID == targetMapID and px or 0.5) * 100, (pMapID == targetMapID and py or 0.5) * 100
    local logMap = GetQuestLogMap()

    currentSteps = BuildLoremasterSteps(targetMapID, cx, cy, w or 1000, h or 1000, logMap)

    -- Injeta passos automáticos de viagem (Voo / Barco / Zepelim) se o destino estiver em outro mapa
    if pMapID and currentSteps[1] and currentSteps[1].mapID and currentSteps[1].mapID ~= pMapID then
        local tSteps = BuildTravelSteps(pMapID, px, py, currentSteps[1])
        if #tSteps > 0 then
            for _, cs in ipairs(currentSteps) do
                if #tSteps >= 12 then break end
                tSteps[#tSteps + 1] = cs
            end
            currentSteps = tSteps
        end
    end

    if self.db.autoAdvance ~= false and currentSteps[1] then
        local s1 = currentSteps[1]
        local key = mode .. ":" .. s1.kind .. ":" .. (s1.skipKey or 0) .. ":" .. (s1.objIdx or 0)
        local qn = Azaath:GetModule("QuestNav")
        if qn and qn.HasUserTarget and qn:HasUserTarget() then
            -- o jogador escolheu o destino: não trocar; ao liberar, foca a etapa do topo
            lastAutoKey = nil
        elseif key ~= lastAutoKey then
            lastAutoKey = key
            if qn then qn.autoFocusing = true end
            pcall(FocusStep, s1, true)
            if qn then qn.autoFocusing = false end
        end
    end

    return currentSteps
end

--------------------------------------------------------------------------------
-- Auto-Aceitar / Auto-Entregar opcional (pausa com Shift)
--------------------------------------------------------------------------------
local function HandleQuestAuto(event)
    if not (M.db and M.db.enabled and M.db.autoQuest) then return end
    if _G.IsShiftKeyDown and _G.IsShiftKeyDown() then return end

    if event == "QUEST_DETAIL" and _G.AcceptQuest then
        Safe(_G.AcceptQuest)
    elseif event == "QUEST_PROGRESS" and _G.IsQuestCompletable and _G.CompleteQuest then
        if Safe(_G.IsQuestCompletable) then Safe(_G.CompleteQuest) end
    elseif event == "QUEST_COMPLETE" and _G.GetNumQuestChoices and _G.GetQuestReward then
        local n = Safe(_G.GetNumQuestChoices) or 0
        if n <= 1 then Safe(_G.GetQuestReward, 1) end
    elseif event == "GOSSIP_SHOW" and _G.C_GossipInfo then
        local cg = _G.C_GossipInfo
        if cg.GetActiveQuests and cg.SelectActiveQuest then
            for _, q in ipairs(Safe(cg.GetActiveQuests) or {}) do
                if q.isComplete and q.questID then Safe(cg.SelectActiveQuest, q.questID); return end
            end
        end
        if cg.GetAvailableQuests and cg.SelectAvailableQuest then
            for _, q in ipairs(Safe(cg.GetAvailableQuests) or {}) do
                if q.questID then Safe(cg.SelectAvailableQuest, q.questID); return end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local driver = CreateFrame("Frame", nil, UIParent)
driver:Hide()
driver:SetScript("OnEvent", function(_, event)
    if event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" or event == "GOSSIP_SHOW" then
        HandleQuestAuto(event)
    end
end)

function M:OnInitialize()
    self.db = Azaath.db.questroute
end

function M:OnEnable()
    if not (self.db and self.db.enabled) then return end
    for _, ev in ipairs({
        "QUEST_DETAIL",
        "QUEST_PROGRESS",
        "QUEST_COMPLETE",
        "GOSSIP_SHOW",
    }) do
        Azaath.SafeRegister(driver, ev)
    end
end
