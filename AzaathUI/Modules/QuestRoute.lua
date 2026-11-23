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

local card, skipped, skipHistory, autoDone, pickerFrame = nil, {}, {}, {}, nil
local currentSteps = {}
local nextZoneSuggestion = nil
local activeGuideZoneName = nil
local activeGuideProgress = nil
local lastAutoKey = nil
local lastGuideH = 0
local lastLoremasterTopKey = nil

local MAX_NEXT = 3

local KIND_STYLE = {
    turnin    = { tag = "ENTREGAR", col = { 0.38, 0.92, 0.58 } },
    objective = { tag = "FAZER",    col = { 0.37, 0.89, 0.90 } },
    complete  = { tag = "FAZER",    col = { 0.37, 0.89, 0.90 } },
    collect   = { tag = "COLETAR",  col = { 0.37, 0.89, 0.90 } },
    kill      = { tag = "MATAR",    col = { 0.95, 0.45, 0.40 } },
    pickup    = { tag = "PEGAR",    col = { 1.00, 0.82, 0.36 } },
    accept    = { tag = "PEGAR",    col = { 1.00, 0.82, 0.36 } },
    use       = { tag = "USAR",     col = { 0.92, 0.62, 1.00 } },
    fly       = { tag = "VOAR",     col = { 0.72, 0.82, 0.95 } },
    boat      = { tag = "BARCO",    col = { 0.37, 0.89, 0.90 } },
    zep       = { tag = "ZEPELIM",  col = { 0.95, 0.62, 0.30 } },
    getfp     = { tag = "VOO",      col = { 0.72, 0.82, 0.95 } },
    sethome   = { tag = "LAR",      col = { 0.72, 0.82, 0.95 } },
    level     = { tag = "NÍVEL",    col = { 1.00, 0.82, 0.36 } },
    train     = { tag = "TREINAR",  col = { 0.72, 0.82, 0.95 } },
    buy       = { tag = "COMPRAR",  col = { 0.72, 0.82, 0.95 } },
    vendor    = { tag = "VENDER",   col = { 0.72, 0.82, 0.95 } },
    craft     = { tag = "CRIAR",    col = { 0.72, 0.82, 0.95 } },
    learn     = { tag = "APRENDER", col = { 0.72, 0.82, 0.95 } },
    talk      = { tag = "FALAR",    col = { 0.72, 0.82, 0.95 } },
    interact  = { tag = "INTERAGIR",col = { 0.72, 0.82, 0.95 } },
    explore   = { tag = "EXPLORAR", col = { 0.72, 0.82, 0.95 } },
    goto      = { tag = "IR",       col = { 0.72, 0.82, 0.95 } },
    enter     = { tag = "ENTRAR",   col = { 0.72, 0.82, 0.95 } },
    die       = { tag = "MORRER",   col = { 0.95, 0.35, 0.35 } },
    grind     = { tag = "GRIND",    col = { 0.98, 0.65, 0.25 } },
    note      = { tag = "DICA",     col = { 0.85, 0.85, 0.55 } },
    auction   = { tag = "LEILÃO",   col = { 1.00, 0.82, 0.36 } },
}

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

local function IsQuestDone(qid)
    if not (qid and qid > 0) then return false end
    local QL = _G.C_QuestLog
    if QL and QL.IsQuestFlaggedCompleted and Safe(QL.IsQuestFlaggedCompleted, qid) then return true end
    if _G.IsQuestFlaggedCompleted and Safe(_G.IsQuestFlaggedCompleted, qid) then return true end
    local qdb = Azaath:GetModule("QuestDB")
    if qdb and qdb.IsCompleted and qdb:IsCompleted(qid) then return true end
    return false
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

local function OpenStepOnMap(s)
    if not s then return end
    FocusStep(s)
    local wm = Azaath:GetModule("WorldMap")
    if wm and wm.Open then
        wm:Open()
        if wm.api and wm.api.FocusMapXY then
            local qParam = (s.kind == "pickup" or s.kind == "accept" or s.kind == "complete" or s.kind == "collect" or s.kind == "kill" or s.kind == "objective" or s.kind == "turnin") and s.questID or nil
            local fx = (s.x and s.x > 0) and s.x or 50
            local fy = (s.y and s.y > 0) and s.y or 50
            wm.api.FocusMapXY(s.mapID, fx, fy, qParam, s.title)
        end
    end
end

local function MatchCSV(csv, val)
    if not csv or csv == "" or not val then return true end
    local v = val:lower()
    for tok in csv:gmatch("[^,]+") do
        if tok:lower() == v then return true end
    end
    return false
end

local function CalcGuideProgress(g)
    if not (g and g.steps) then return 0, 0 end
    local totalQ, doneQ, seenQ = 0, 0, {}
    for _, st in ipairs(g.steps) do
        if st.q and st.q > 0 and not seenQ[st.q] then
            seenQ[st.q] = true
            totalQ = totalQ + 1
            if IsQuestDone(st.q) then doneQ = doneQ + 1 end
        end
    end
    return doneQ, totalQ
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

    local totalZ, doneZ = 0, 0
    if qdb and qdb.GetZoneQuests then
        for _, item in ipairs(qdb:GetZoneQuests(mapID)) do
            local q = item.quest
            if not q.repeatable then
                totalZ = totalZ + 1
                if item.status == "completed" then doneZ = doneZ + 1 end
            end
            if item.status == "available" and not q.repeatable and not seen[q.id] and not skipped[q.id]
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
    activeGuideProgress = (totalZ > 0) and format("%d/%d", doneZ, totalZ) or nil

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

function M:GetSteps()
    return currentSteps
end

function M:GetHeight()
    if not (self.db and self.db.enabled and card and card:IsShown()) then return 0 end
    return (card:GetHeight() or 0) + 8
end

function M:Rebuild()
    currentSteps = {}
    nextZoneSuggestion = nil
    activeGuideZoneName = nil
    activeGuideProgress = nil
    if not (self.db and self.db.enabled) then
        if card then card:Hide() end
        return currentSteps
    end

    local mode = self.db.mode or "loremaster"
    if mode == "none" then
        self:UpdateCard()
        return currentSteps
    end

    local pMapID, px, py, w, h = PlayerMapPos()
    local targetMapID = self.db.selectedMapID or pMapID
    if not targetMapID then
        self:UpdateCard()
        return currentSteps
    end

    local cx, cy = (pMapID == targetMapID and px or 0.5) * 100, (pMapID == targetMapID and py or 0.5) * 100
    local logMap = GetQuestLogMap()

    activeGuideZoneName = ZoneName(targetMapID)
    currentSteps, nextZoneSuggestion = BuildLoremasterSteps(targetMapID, cx, cy, w or 1000, h or 1000, logMap)
    if #currentSteps == 0 and not nextZoneSuggestion then
        nextZoneSuggestion = { name = "Zona completa — abrir mapa", zoneID = targetMapID, minLevel = 0 }
    end

    -- Injeta passos automáticos de viagem (Voo / Barco / Zepelim) se o destino estiver em outro mapa
    if pMapID and currentSteps[1] and currentSteps[1].mapID and currentSteps[1].mapID ~= pMapID then
        local tSteps = BuildTravelSteps(pMapID, px, py, currentSteps[1])
        if #tSteps > 0 then
            for _, cs in ipairs(currentSteps) do
                if #tSteps >= 12 then break end
                tSteps[#tSteps + 1] = cs
            end
            currentSteps = tSteps
            self:RefreshDistances()
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

    self:UpdateCard()
    return currentSteps
end

function M:RefreshDistances()
    if not (card and card:IsShown() and #currentSteps > 0) then return end
    local mapID, px, py, w, h = PlayerMapPos()
    if not (mapID and px and py) then return end
    local cx, cy = px * 100, py * 100
    for _, s in ipairs(currentSteps) do
        if s.mapID == mapID and s.x and s.y and s.x > 0 then
            local dx = ((s.x - cx) / 100) * w
            local dy = ((s.y - cy) / 100) * h
            s.yards = sqrt(dx * dx + dy * dy)
        end
    end
    local s1 = currentSteps[1]
    if s1 and card.cur:IsShown() then
        card.dist:SetText(s1.yards and s1.yards > 0 and (s1.yards < 10 and "Perto" or format("%d m", floor(s1.yards + 0.5))) or "")
    end
    for i = 1, MAX_NEXT do
        local row = card.nextRows[i]
        local s = currentSteps[i + 1]
        if row and row:IsShown() and s then
            row.dist:SetText(s.yards and s.yards > 0 and (s.yards < 10 and "Perto" or format("%d m", floor(s.yards + 0.5))) or "")
        end
    end
end

--------------------------------------------------------------------------------
-- Aba Grande de Guias e Mapas (estilo Polestar — 740x480)
--------------------------------------------------------------------------------
local pickerCat = "Leveling"
local pickerFilter = "all"
local pickerQuery = ""
local pickerSelected = nil

local CATEGORIES = {
    { key = "Leveling",      text = "Leveling" },
    { key = "Class",         text = "Classe" },
    { key = "Professions",   text = "Profissões" },
    { key = "Reputation",    text = "Reputação" },
    { key = "Collectibles",  text = "Colecionáveis" },
    { key = "Exploration",   text = "Exploração" },
    { key = "Miscellaneous", text = "Outros" },
}

local function GetPickerEntries()
    local entries = {}
    local pFac = _G.UnitFactionGroup and Safe(_G.UnitFactionGroup, "player")
    local fCode = (pFac == "Alliance" and "A") or (pFac == "Horde" and "H") or "AH"
    local _, pRace = _G.UnitRace and Safe(_G.UnitRace, "player")
    local _, pClass = _G.UnitClass and Safe(_G.UnitClass, "player")
    local pLvl = (_G.UnitLevel and Safe(_G.UnitLevel, "player")) or 1
    local q = pickerQuery:lower():match("^%s*(.-)%s*$") or ""

    if type(Azaath.TryhardRoutes) == "table" then
        for _, g in ipairs(Azaath.TryhardRoutes) do
            if (g.cat or "Leveling") == pickerCat
               and (g.f == "AH" or g.f == fCode)
               and MatchCSV(g.r, pRace)
               and MatchCSV(g.cls, pClass) then
                local zName = (g.z and g.z > 0 and ZoneName(g.z)) or g.zn or g.id
                local ok = true
                if q ~= "" and not zName:lower():find(q, 1, true) and not (g.id or ""):lower():find(q, 1, true) then ok = false end
                if ok and pickerFilter == "level" then
                    ok = pLvl >= ((g.min or 1) - 2) and pLvl <= ((g.max or 60) + 2)
                elseif ok and pickerFilter == "start" then
                    ok = (g.max or 60) <= 14
                elseif ok and pickerFilter == "ek" then
                    ok = g.k == "EK"
                elseif ok and pickerFilter == "kal" then
                    ok = g.k == "Kalimdor"
                end
                if ok then
                    local dq, tq = CalcGuideProgress(g)
                    entries[#entries + 1] = {
                        label   = zName,
                        sub     = format("Nv. %d–%d", g.min or 1, g.max or 60),
                        cont    = g.k == "EK" and "Reinos do Leste" or (g.k == "Kalimdor" and "Kalimdor" or "Outro"),
                        why     = g.why or "",
                        nextZ   = g.nzn or "",
                        steps   = g.steps,
                        doneQ   = dq,
                        totalQ  = tq,
                        min     = g.min or 1,
                        mapID   = g.z,
                        guideID = g.id,
                    }
                end
            end
        end
    end
    table.sort(entries, function(a, b)
        if a.min ~= b.min then return a.min < b.min end
        return a.label < b.label
    end)
    return entries
end

local function RefreshPicker()
    if not pickerFrame then return end
    local entries = GetPickerEntries()
    if not pickerSelected and entries[1] then pickerSelected = entries[1] end

    for _, cb in ipairs(pickerFrame.catBtns) do
        local on = (cb.key == pickerCat)
        cb.bg:SetColorTexture(on and 0.18 or 0.07, on and 0.36 or 0.11, on and 0.42 or 0.14, 0.96)
        cb.txt:SetTextColor(on and 1.00 or 0.72, on and 0.82 or 0.76, on and 0.36 or 0.80)
    end
    for _, fb in ipairs(pickerFrame.filterBtns) do
        local on = (fb.key == pickerFilter)
        fb.bg:SetColorTexture(on and 0.16 or 0.08, on and 0.34 or 0.12, on and 0.38 or 0.15, 0.94)
        fb.txt:SetTextColor(on and 0.37 or 0.70, on and 0.89 or 0.75, on and 0.90 or 0.78)
    end

    for i, e in ipairs(entries) do
        local r = pickerFrame.rows[i]
        if not r then
            r = CreateFrame("Button", nil, pickerFrame.sc)
            r:SetSize(256, 32)
            r:SetPoint("TOPLEFT", 0, -(i - 1) * 34)
            r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
            r.lbl = r:CreateFontString(nil, "OVERLAY")
            r.lbl:SetFont(Azaath.media.fontTitle, 11, ""); r.lbl:SetPoint("TOPLEFT", 8, -4); r.lbl:SetWidth(182); r.lbl:SetJustifyH("LEFT"); r.lbl:SetWordWrap(false)
            r.sub = r:CreateFontString(nil, "OVERLAY")
            r.sub:SetFont(Azaath.media.font, 9, ""); r.sub:SetPoint("BOTTOMLEFT", 8, 4); r.sub:SetTextColor(0.62, 0.70, 0.74)
            r.cnt = r:CreateFontString(nil, "OVERLAY")
            r.cnt:SetFont(Azaath.media.font, 9, ""); r.cnt:SetPoint("RIGHT", -8, 0); r.cnt:SetTextColor(0.37, 0.89, 0.90)
            r:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.14, 0.26, 0.30, 0.95) end)
            r:SetScript("OnLeave", function(self)
                local sel = (pickerSelected and pickerSelected.guideID == self.entry.guideID)
                self.bg:SetColorTexture(sel and 0.12 or 0.06, sel and 0.24 or 0.09, sel and 0.28 or 0.12, 0.88)
            end)
            pickerFrame.rows[i] = r
        end
        r.entry = e
        local sel = (pickerSelected and pickerSelected.guideID == e.guideID)
        r.bg:SetColorTexture(sel and 0.12 or 0.06, sel and 0.24 or 0.09, sel and 0.28 or 0.12, 0.88)
        r.lbl:SetText(e.label)
        r.lbl:SetTextColor(sel and 1.0 or 0.92, sel and 0.82 or 0.95, sel and 0.36 or 0.96)
        r.sub:SetText(e.sub .. " · " .. e.cont)
        local pctTxt = (e.totalQ > 0) and format("%d/%d", e.doneQ, e.totalQ) or ((e.steps and #e.steps or 0) .. " p.")
        r.cnt:SetText(pctTxt)
        r:SetScript("OnClick", function()
            pickerSelected = e
            RefreshPicker()
        end)
        r:Show()
    end
    for i = #entries + 1, #pickerFrame.rows do pickerFrame.rows[i]:Hide() end
    pickerFrame.sc:SetHeight(max(1, #entries * 34))

    local sel = pickerSelected
    if sel then
        pickerFrame.dTitle:SetText(sel.label)
        local progStr = (sel.totalQ > 0) and format(" · Progresso: %d/%d (%d%%)", sel.doneQ, sel.totalQ, floor((sel.doneQ / sel.totalQ) * 100)) or ""
        pickerFrame.dMeta:SetText(sel.sub .. " · " .. sel.cont .. progStr .. (sel.nextZ ~= "" and ("  |  Próximo: " .. sel.nextZ) or ""))
        pickerFrame.dWhy:SetText(sel.why ~= "" and sel.why or "Rota otimizada desta região/categoria.")
        local lines, shown = {}, 0
        for _, st in ipairs(sel.steps or {}) do
            shown = shown + 1
            local kst = KIND_STYLE[st.t] or KIND_STYLE.goto
            local extra = (st.nt and st.nt ~= "" and (" — " .. st.nt)) or (st.n and st.n ~= "" and (" (" .. st.n .. ")") or "")
            lines[#lines + 1] = format("|cff5edee6%d. [%s]|r %s%s", shown, kst.tag, st.l or "", extra)
            if shown >= 10 then break end
        end
        pickerFrame.dSteps:SetText(table.concat(lines, "\n"))
        pickerFrame.startBtn:Show()
        pickerFrame.viewMapBtn:Show()
    else
        pickerFrame.dTitle:SetText("Nenhum guia nesta categoria")
        pickerFrame.dMeta:SetText("")
        pickerFrame.dWhy:SetText("")
        pickerFrame.dSteps:SetText("")
        pickerFrame.startBtn:Hide()
        pickerFrame.viewMapBtn:Hide()
    end
end

local function ToggleMapPicker()
    local qgm = Azaath:GetModule("QuestGuideMenu")
    if qgm and qgm.Toggle then
        qgm:Toggle()
        return
    end
    if pickerFrame and pickerFrame:IsShown() then
        pickerFrame:Hide()
        return
    end
    local c, media = Azaath.colors, Azaath.media
    if not pickerFrame then
        local pf = CreateFrame("Frame", "AzaathUIQuestRoutePicker", Azaath.root)
        pf:SetSize(740, 480)
        pf:SetPoint("CENTER")
        pf:SetFrameStrata("DIALOG")
        pf:EnableMouse(true)
        pf:SetMovable(true)
        pf:RegisterForDrag("LeftButton")
        pf:SetScript("OnDragStart", pf.StartMoving)
        pf:SetScript("OnDragStop", pf.StopMovingOrSizing)

        local pbg = pf:CreateTexture(nil, "BACKGROUND"); pbg:SetAllPoints()
        pbg:SetColorTexture(0.03, 0.05, 0.08, 0.97)

        local hdr = pf:CreateFontString(nil, "OVERLAY")
        hdr:SetFont(media.fontTitleB, 14, "")
        hdr:SetPoint("TOPLEFT", 16, -12)
        hdr:SetText("CENTRAL DE GUIAS E ROTAS Azaath")
        hdr:SetTextColor(c.gold[1], c.gold[2], c.gold[3])

        local autoBtn = CreateFrame("Button", nil, pf)
        autoBtn:SetSize(165, 22); autoBtn:SetPoint("TOPRIGHT", -38, -10)
        autoBtn.bg = autoBtn:CreateTexture(nil, "BACKGROUND"); autoBtn.bg:SetAllPoints()
        autoBtn.bg:SetColorTexture(0.12, 0.24, 0.28, 0.95)
        autoBtn.t = autoBtn:CreateFontString(nil, "OVERLAY")
        autoBtn.t:SetFont(media.font, 10, ""); autoBtn.t:SetPoint("CENTER"); autoBtn.t:SetText("★ Usar Zona Atual (Auto)")
        autoBtn.t:SetTextColor(0.37, 0.89, 0.90)
        autoBtn:SetScript("OnClick", function()
            M.db.selectedMapID = nil
            M.db.selectedGuideID = nil
            lastAutoKey = nil
            pf:Hide()
            M:Rebuild()
        end)

        local close = CreateFrame("Button", nil, pf)
        close:SetSize(24, 24); close:SetPoint("TOPRIGHT", -8, -8)
        close.t = close:CreateFontString(nil, "OVERLAY")
        close.t:SetFont(media.fontTitleB, 14, ""); close.t:SetPoint("CENTER"); close.t:SetText("×")
        close:SetScript("OnClick", function() pf:Hide() end)

        -- Abas de Categoria no topo
        pf.catBtns = {}
        local cx = 14
        for idx, cd in ipairs(CATEGORIES) do
            local b = CreateFrame("Button", nil, pf)
            b:SetSize(96, 22); b:SetPoint("TOPLEFT", cx, -38)
            b.key = cd.key
            b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
            b.txt = b:CreateFontString(nil, "OVERLAY"); b.txt:SetFont(media.fontTitle, 10, ""); b.txt:SetPoint("CENTER"); b.txt:SetText(cd.text)
            b:SetScript("OnClick", function() pickerCat = cd.key; pickerSelected = nil; RefreshPicker() end)
            pf.catBtns[idx] = b
            cx = cx + 100
        end

        -- Sub-filtros + Busca à esquerda
        local filters = {
            { key = "all",   text = "Todos",    w = 46 },
            { key = "level", text = "Meu Nível",w = 60 },
            { key = "start", text = "1–12",     w = 38 },
            { key = "ek",    text = "R. Leste", w = 54 },
            { key = "kal",   text = "Kalimdor", w = 56 },
        }
        pf.filterBtns = {}
        local fx = 14
        for idx, fd in ipairs(filters) do
            local b = CreateFrame("Button", nil, pf)
            b:SetSize(fd.w, 20); b:SetPoint("TOPLEFT", fx, -68)
            b.key = fd.key
            b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
            b.txt = b:CreateFontString(nil, "OVERLAY"); b.txt:SetFont(media.font, 9, ""); b.txt:SetPoint("CENTER"); b.txt:SetText(fd.text)
            b:SetScript("OnClick", function() pickerFilter = fd.key; pickerSelected = nil; RefreshPicker() end)
            pf.filterBtns[idx] = b
            fx = fx + fd.w + 3
        end

        local sbox = CreateFrame("EditBox", nil, pf, "InputBoxTemplate")
        sbox:SetSize(256, 22); sbox:SetPoint("TOPLEFT", 18, -94); sbox:SetAutoFocus(false)
        sbox:SetScript("OnTextChanged", function(self) pickerQuery = self:GetText() or ""; pickerSelected = nil; RefreshPicker() end)
        sbox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

        local sf = CreateFrame("ScrollFrame", nil, pf)
        sf:SetPoint("TOPLEFT", 14, -122); sf:SetSize(260, 344)
        local sc = CreateFrame("Frame", nil, sf); sc:SetSize(256, 1); sf:SetScrollChild(sc)
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, delta)
            local cur = self:GetVerticalScroll() or 0
            local maxS = max(0, (sc:GetHeight() or 0) - self:GetHeight())
            self:SetVerticalScroll(min(maxS, max(0, cur - delta * 34)))
        end)
        pf.sc, pf.sf, pf.rows = sc, sf, {}

        -- Painel de detalhes à direita
        local rp = CreateFrame("Frame", nil, pf)
        rp:SetPoint("TOPLEFT", 286, -68); rp:SetPoint("BOTTOMRIGHT", -14, 14)
        local rbg = rp:CreateTexture(nil, "BACKGROUND"); rbg:SetAllPoints()
        rbg:SetColorTexture(0.05, 0.08, 0.11, 0.82)

        pf.dTitle = rp:CreateFontString(nil, "OVERLAY")
        pf.dTitle:SetFont(media.fontTitleB, 16, ""); pf.dTitle:SetPoint("TOPLEFT", 14, -12); pf.dTitle:SetWidth(410); pf.dTitle:SetJustifyH("LEFT")
        pf.dTitle:SetTextColor(c.gold[1], c.gold[2], c.gold[3])

        pf.dMeta = rp:CreateFontString(nil, "OVERLAY")
        pf.dMeta:SetFont(media.font, 11, ""); pf.dMeta:SetPoint("TOPLEFT", 14, -34); pf.dMeta:SetWidth(410); pf.dMeta:SetJustifyH("LEFT")
        pf.dMeta:SetTextColor(0.37, 0.89, 0.90)

        pf.dWhy = rp:CreateFontString(nil, "OVERLAY")
        pf.dWhy:SetFont(media.font, 10, ""); pf.dWhy:SetPoint("TOPLEFT", 14, -56); pf.dWhy:SetWidth(410); pf.dWhy:SetJustifyH("LEFT")
        pf.dWhy:SetTextColor(0.82, 0.86, 0.88)

        local sep = rp:CreateFontString(nil, "OVERLAY")
        sep:SetFont(media.fontTitleB, 11, ""); sep:SetPoint("TOPLEFT", 14, -104); sep:SetText("PRÓXIMOS PASSOS DO GUIA:")
        sep:SetTextColor(0.95, 0.92, 0.82)

        pf.dSteps = rp:CreateFontString(nil, "OVERLAY")
        pf.dSteps:SetFont(media.font, 10, ""); pf.dSteps:SetPoint("TOPLEFT", 14, -124); pf.dSteps:SetWidth(410); pf.dSteps:SetJustifyH("LEFT"); pf.dSteps:SetSpacing(4)
        pf.dSteps:SetTextColor(0.88, 0.91, 0.93)

        pf.startBtn = CreateFrame("Button", nil, rp)
        pf.startBtn:SetSize(200, 28); pf.startBtn:SetPoint("BOTTOMLEFT", 14, 12)
        pf.startBtn.bg = pf.startBtn:CreateTexture(nil, "BACKGROUND"); pf.startBtn.bg:SetAllPoints()
        pf.startBtn.bg:SetColorTexture(0.14, 0.36, 0.40, 0.96)
        pf.startBtn.t = pf.startBtn:CreateFontString(nil, "OVERLAY")
        pf.startBtn.t:SetFont(media.fontTitleB, 11, ""); pf.startBtn.t:SetPoint("CENTER"); pf.startBtn.t:SetText("Iniciar Guia Selecionado")
        pf.startBtn:SetScript("OnClick", function()
            if not pickerSelected then return end
            M.db.selectedMapID = pickerSelected.mapID
            M.db.selectedGuideID = pickerSelected.guideID
            if M.db.mode ~= "loremaster" then
                M.db.mode = "loremaster"
            end
            lastAutoKey = nil
            pf:Hide()
            M:Rebuild()
        end)

        pf.viewMapBtn = CreateFrame("Button", nil, rp)
        pf.viewMapBtn:SetSize(160, 28); pf.viewMapBtn:SetPoint("BOTTOMRIGHT", -14, 12)
        pf.viewMapBtn.bg = pf.viewMapBtn:CreateTexture(nil, "BACKGROUND"); pf.viewMapBtn.bg:SetAllPoints()
        pf.viewMapBtn.bg:SetColorTexture(0.10, 0.18, 0.22, 0.94)
        pf.viewMapBtn.t = pf.viewMapBtn:CreateFontString(nil, "OVERLAY")
        pf.viewMapBtn.t:SetFont(media.font, 11, ""); pf.viewMapBtn.t:SetPoint("CENTER"); pf.viewMapBtn.t:SetText("Abrir Mapa da Zona")
        pf.viewMapBtn:SetScript("OnClick", function()
            if not pickerSelected or not pickerSelected.mapID or pickerSelected.mapID == 0 then return end
            local st1 = pickerSelected.steps and pickerSelected.steps[1]
            local wm = Azaath:GetModule("WorldMap")
            if wm and wm.Open then
                wm:Open()
                if wm.api and wm.api.FocusMapXY then
                    wm.api.FocusMapXY(pickerSelected.mapID, (st1 and st1.x and st1.x > 0) and st1.x or 50, (st1 and st1.y and st1.y > 0) and st1.y or 50, nil, pickerSelected.label)
                end
            end
        end)

        pickerFrame = pf
    end
    RefreshPicker()
    pickerFrame:Show()
end

--------------------------------------------------------------------------------
-- UI Unificada acoplada ao topo de AzaathUIQuestTracker
--------------------------------------------------------------------------------
local function BuildCard()
    if card then return end
    local c, media = Azaath.colors, Azaath.media

    local f = CreateFrame("Frame", "AzaathUIQuestRouteCard", Azaath.root)
    f:SetSize(270, 24)

    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.04, 0.06, 0.08, 0.86)
    f.bg = bg

    -- Barra de Modos + AutoQ + Caminho + Mapa
    local hdr = CreateFrame("Frame", nil, f)
    hdr:SetPoint("TOPLEFT", 0, 0)
    hdr:SetPoint("TOPRIGHT", 0, 0)
    hdr:SetHeight(24)
    local hbg = hdr:CreateTexture(nil, "BACKGROUND")
    hbg:SetAllPoints()
    hbg:SetColorTexture(0.07, 0.11, 0.14, 0.96)
    f.hdrBg = hbg

    local function ModeBtn(key, label, x, w, tip)
        local b = CreateFrame("Button", nil, hdr)
        b:SetSize(w, 18)
        b:SetPoint("LEFT", x, 0)
        b.key = key
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
        b.txt = b:CreateFontString(nil, "OVERLAY")
        b.txt:SetFont(media.font, 9, "")
        b.txt:SetPoint("CENTER")
        b.txt:SetText(label)
        b:SetScript("OnClick", function()
            M.db.mode = key
            lastAutoKey = nil
            M:Rebuild()
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(tip, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end

    f.modeBtns = {
        ModeBtn("none",       "Livre",   3,  27, "Livre: sem guia, apenas suas missões acompanhadas"),
        ModeBtn("loremaster", "Lorem.",  32, 39, "Loremaster: guia 100% das missões disponíveis da zona"),
    }

    local function ToolBtn(label, rightOff, w, onClick, tip)
        local b = CreateFrame("Button", nil, hdr)
        b:SetSize(w, 18)
        b:SetPoint("RIGHT", rightOff, 0)
        b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
        b.bg:SetColorTexture(0.12, 0.20, 0.24, 0.9)
        b.txt = b:CreateFontString(nil, "OVERLAY")
        b.txt:SetFont(media.font, 9, "")
        b.txt:SetPoint("CENTER")
        b.txt:SetText(label)
        b:SetScript("OnClick", onClick)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(tip, 1, 1, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        return b
    end

    f.expBtn = ToolBtn("▼", -2, 15, function()
        M.db.expanded = (M.db.expanded == false)
        M:UpdateCard()
    end, "Expandir / recolher próximos passos")

    f.magicBtn = ToolBtn("Caminho", -19, 38, function()
        local qn = Azaath:GetModule("QuestNav")
        local curOn = not (qn and qn.db and qn.db.magicPath == false)
        if qn and qn.SetMagicPathEnabled then qn:SetMagicPathEnabled(not curOn) end
        M:UpdateCard()
    end, "Caminho Mágico (rota caminhável evitando obstáculos)")

    f.autoQBtn = ToolBtn("AutoQ", -59, 32, function()
        M.db.autoQuest = not M.db.autoQuest
        M:UpdateCard()
    end, "Aceitar e entregar missões automaticamente ao falar com NPC (segure Shift para pausar)")

    f.mapBtn = ToolBtn("Mapa", -93, 28, function()
        OpenStepOnMap(currentSteps[1])
    end, "Abrir mapa no passo atual")

    -- Barra de seleção de mapa / guia
    local zb = CreateFrame("Button", nil, f)
    zb:SetPoint("TOPLEFT", 0, -24)
    zb:SetPoint("TOPRIGHT", 0, -24)
    zb:SetHeight(20)
    zb.bg = zb:CreateTexture(nil, "BACKGROUND"); zb.bg:SetAllPoints()
    zb.bg:SetColorTexture(0.05, 0.08, 0.11, 0.90)
    zb.txt = zb:CreateFontString(nil, "OVERLAY")
    zb.txt:SetFont(media.font, 10, "")
    zb.txt:SetPoint("LEFT", 8, 0)
    zb.txt:SetWidth(188)
    zb.txt:SetJustifyH("LEFT")
    zb.txt:SetWordWrap(false)
    zb.txt:SetTextColor(c.gold[1], c.gold[2], c.gold[3])
    zb.pick = zb:CreateFontString(nil, "OVERLAY")
    zb.pick:SetFont(media.font, 9, "")
    zb.pick:SetPoint("RIGHT", -19, 0)
    zb.pick:SetText("Guias")
    zb.pick:SetTextColor(0.37, 0.89, 0.90)
    zb.pickArrow = zb:CreateTexture(nil, "OVERLAY")
    zb.pickArrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    zb.pickArrow:SetSize(10, 10)
    zb.pickArrow:SetPoint("RIGHT", -7, 0)
    zb.pickArrow:SetRotation(-math.pi / 2)
    zb.pickArrow:SetVertexColor(0.37, 0.89, 0.90)
    zb:SetScript("OnClick", ToggleMapPicker)
    zb:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.09, 0.15, 0.19, 0.95) end)
    zb:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.05, 0.08, 0.11, 0.90) end)
    f.zoneBar = zb

    -- Passo Atual (#1)
    local cur = CreateFrame("Button", nil, f)
    cur:SetPoint("TOPLEFT", 0, -44)
    cur:SetPoint("TOPRIGHT", 0, -44)
    cur:SetHeight(64)
    cur:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    cur.bg = cur:CreateTexture(nil, "BACKGROUND"); cur.bg:SetAllPoints()
    cur.bg:SetColorTexture(0.06, 0.10, 0.13, 0.85)
    f.cur = cur

    local bar = cur:CreateTexture(nil, "ARTWORK")
    bar:SetPoint("TOPLEFT", 0, 0)
    bar:SetPoint("BOTTOMLEFT", 0, 0)
    bar:SetWidth(3)
    f.bar = bar

    f.tag = cur:CreateFontString(nil, "OVERLAY")
    f.tag:SetFont(media.fontTitleB, 9, "")
    f.tag:SetPoint("TOPLEFT", 10, -5)

    f.dist = cur:CreateFontString(nil, "OVERLAY")
    f.dist:SetFont(media.font, 10, "")
    f.dist:SetPoint("TOPRIGHT", -38, -5)
    f.dist:SetTextColor(c.cream[1], c.cream[2], c.cream[3], 0.9)

    f.title = cur:CreateFontString(nil, "OVERLAY")
    f.title:SetFont(media.fontTitle, 12, "")
    f.title:SetPoint("TOPLEFT", 10, -18)
    f.title:SetWidth(220)
    f.title:SetJustifyH("LEFT")
    f.title:SetWordWrap(false)
    f.title:SetTextColor(1, 1, 1, 0.96)

    f.sub = cur:CreateFontString(nil, "OVERLAY")
    f.sub:SetFont(media.font, 10, "")
    f.sub:SetPoint("TOPLEFT", 10, -34)
    f.sub:SetWidth(220)
    f.sub:SetHeight(24)
    f.sub:SetJustifyH("LEFT")
    f.sub:SetJustifyV("TOP")
    f.sub:SetWordWrap(true)
    f.sub:SetTextColor(0.72, 0.82, 0.86)

    local prevBtn = CreateFrame("Button", nil, cur)
    prevBtn:SetSize(16, 20); prevBtn:SetPoint("TOPRIGHT", -18, -2)
    prevBtn.txt = prevBtn:CreateFontString(nil, "OVERLAY")
    prevBtn.txt:SetFont(media.fontTitleB, 13, ""); prevBtn.txt:SetPoint("CENTER"); prevBtn.txt:SetText("‹")
    prevBtn.txt:SetTextColor(0.65, 0.72, 0.76)
    prevBtn:SetScript("OnClick", function()
        local lastKey = table.remove(skipHistory)
        if lastKey then
            skipped[lastKey] = nil
            M:Rebuild()
        end
    end)

    local skip = CreateFrame("Button", nil, cur)
    skip:SetSize(16, 20); skip:SetPoint("TOPRIGHT", -2, -2)
    skip.txt = skip:CreateFontString(nil, "OVERLAY")
    skip.txt:SetFont(media.fontTitleB, 13, ""); skip.txt:SetPoint("CENTER"); skip.txt:SetText("›")
    skip.txt:SetTextColor(0.75, 0.80, 0.84)
    skip:SetScript("OnClick", function()
        local s = currentSteps[1]
        if s then
            local k = s.skipKey or s.questID
            skipped[k] = true
            skipHistory[#skipHistory + 1] = k
            M:Rebuild()
            if currentSteps[1] then FocusStep(currentSteps[1]) end
        end
    end)

    -- Botão de Item Usável do passo (SecureActionButtonTemplate).
    -- Filho do root e SEM âncora no cartão: botão seguro filho/ancorado de cur
    -- deixava cur, o cartão e o rastreador protegidos (ADDON_ACTION_BLOCKED em
    -- Show/SetHeight/SetPoint em combate). Posição copiada de cur só fora de
    -- combate (M:SyncItemBtn).
    local itemBtn = CreateFrame("Button", "AzaathUIRouteItemBtn", Azaath.root, "SecureActionButtonTemplate")
    itemBtn:SetSize(24, 24)
    itemBtn:RegisterForClicks("AnyUp")
    itemBtn.icon = itemBtn:CreateTexture(nil, "ARTWORK")
    itemBtn.icon:SetAllPoints()
    itemBtn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    itemBtn:SetScript("OnEnter", function(self)
        if self.itemID and self.itemID > 0 then
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetItemByID(self.itemID)
            GameTooltip:Show()
        end
    end)
    itemBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    itemBtn:Hide()
    f.itemBtn = itemBtn
    cur:HookScript("OnShow", function() M:SyncItemBtn() end)
    cur:HookScript("OnHide", function() M:SyncItemBtn() end)
    f:HookScript("OnShow", function() M:SyncItemBtn() end)
    f:HookScript("OnHide", function() M:SyncItemBtn() end)

    cur:SetScript("OnClick", function(_, btn)
        local s = currentSteps[1]
        if not s then return end
        if btn == "RightButton" then
            local k = s.skipKey or s.questID
            skipped[k] = true
            skipHistory[#skipHistory + 1] = k
            M:Rebuild()
        else
            OpenStepOnMap(s)
        end
    end)
    cur:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.10, 0.16, 0.20, 0.95)
        local s = currentSteps[1]
        if s then
            local pMap = _G.C_Map and _G.C_Map.GetBestMapForUnit and Safe(_G.C_Map.GetBestMapForUnit, "player")
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine(s.title, 1, 0.82, 0.36)
            if s.mapID and pMap and s.mapID ~= pMap then
                GameTooltip:AddLine("Em outro mapa: " .. ZoneName(s.mapID) .. " (clique para abrir no mapa)", 0.37, 0.89, 0.90)
            end
            if s.note and s.note ~= "" then
                GameTooltip:AddLine(s.note, 0.95, 0.92, 0.82, true)
            elseif s.detail and s.detail ~= "" then
                GameTooltip:AddLine(s.detail, 0.85, 0.92, 0.95, true)
            end
            if s.x and s.x > 0 then
                GameTooltip:AddLine(format("Coordenadas: (%.1f, %.1f)", s.x, s.y), 0.65, 0.72, 0.75)
            end
            GameTooltip:AddLine("Clique direito: pular passo", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end
    end)
    cur:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.06, 0.10, 0.13, 0.85)
        GameTooltip:Hide()
    end)

    -- Próximos passos (#2..#4)
    f.nextRows = {}
    for i = 1, MAX_NEXT do
        local r = CreateFrame("Button", nil, f)
        r:SetPoint("TOPLEFT", 0, -108 - (i - 1) * 22)
        r:SetPoint("TOPRIGHT", 0, -108 - (i - 1) * 22)
        r:SetHeight(22)
        r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        r.bg = r:CreateTexture(nil, "BACKGROUND"); r.bg:SetAllPoints()
        r.bg:SetColorTexture(0.04, 0.06, 0.08, 0.75)

        r.tag = r:CreateFontString(nil, "OVERLAY")
        r.tag:SetFont(media.fontTitleB, 8, "")
        r.tag:SetPoint("LEFT", 8, 0)
        r.tag:SetWidth(54)
        r.tag:SetJustifyH("LEFT")

        r.title = r:CreateFontString(nil, "OVERLAY")
        r.title:SetFont(media.font, 10, "")
        r.title:SetPoint("LEFT", 64, 0)
        r.title:SetWidth(154)
        r.title:SetJustifyH("LEFT")
        r.title:SetWordWrap(false)
        r.title:SetTextColor(0.84, 0.88, 0.90)

        r.dist = r:CreateFontString(nil, "OVERLAY")
        r.dist:SetFont(media.font, 9, "")
        r.dist:SetPoint("RIGHT", -8, 0)
        r.dist:SetTextColor(0.62, 0.68, 0.70)

        r:SetScript("OnClick", function(self, btn)
            if not self.step then return end
            if btn == "RightButton" then
                local k = self.step.skipKey or self.step.questID
                skipped[k] = true
                skipHistory[#skipHistory + 1] = k
                M:Rebuild()
            else
                local pMap = _G.C_Map and _G.C_Map.GetBestMapForUnit and Safe(_G.C_Map.GetBestMapForUnit, "player")
                if (self.step.mapID and pMap and self.step.mapID ~= pMap) or not (self.step.x and self.step.x > 0) then
                    OpenStepOnMap(self.step)
                else
                    FocusStep(self.step)
                end
            end
        end)
        r:SetScript("OnEnter", function(self) self.bg:SetColorTexture(0.09, 0.14, 0.17, 0.9) end)
        r:SetScript("OnLeave", function(self) self.bg:SetColorTexture(0.04, 0.06, 0.08, 0.75) end)
        r:Hide()
        f.nextRows[i] = r
    end

    -- Sugestão de Próximo Mapa (modo Tryhard)
    local nxt = CreateFrame("Button", nil, f)
    nxt:SetHeight(22)
    nxt.bg = nxt:CreateTexture(nil, "BACKGROUND"); nxt.bg:SetAllPoints()
    nxt.bg:SetColorTexture(0.14, 0.18, 0.08, 0.88)
    nxt.txt = nxt:CreateFontString(nil, "OVERLAY")
    nxt.txt:SetFont(media.font, 10, "")
    nxt.txt:SetPoint("LEFT", 8, 0)
    nxt.txt:SetWidth(252)
    nxt.txt:SetJustifyH("LEFT")
    nxt.txt:SetTextColor(c.gold[1], c.gold[2], c.gold[3])
    nxt:SetScript("OnClick", function()
        if nextZoneSuggestion then
            if nextZoneSuggestion.guideID and nextZoneSuggestion.guideID ~= "" then
                M.db.selectedGuideID = nextZoneSuggestion.guideID
                M.db.selectedMapID = nextZoneSuggestion.zoneID > 0 and nextZoneSuggestion.zoneID or nil
                lastAutoKey = nil
                M:Rebuild()
            elseif nextZoneSuggestion.zoneID > 0 then
                local wm = Azaath:GetModule("WorldMap")
                if wm and wm.Open then
                    wm:Open()
                    if wm.api and wm.api.SetMapID then wm.api.SetMapID(nextZoneSuggestion.zoneID) end
                end
            end
        end
    end)
    nxt:Hide()
    f.nextZoneBtn = nxt

    card = f
    M:AnchorCard()
end

function M:AnchorCard()
    if not card then return end
    card:ClearAllPoints()
    local qt = _G.AzaathUIQuestTracker
    if qt then
        if card:GetParent() ~= qt then card:SetParent(qt) end
        card:SetPoint("TOPLEFT", qt, "TOPLEFT", 0, 0)
        card:SetPoint("TOPRIGHT", qt, "TOPRIGHT", 0, 0)
    else
        card:SetPoint("TOPRIGHT", Azaath.root, "TOPRIGHT", -8, -260)
    end
end

-- Mostra/posiciona o botão seguro de item sobre o canto de cur. Só fora de
-- combate; em combate fica para a saída (fila do Core), uma vez só.
local itemSyncQueued = false
function M:SyncItemBtn()
    if not card then return end
    if InCombatLockdown and InCombatLockdown() then
        if not itemSyncQueued then
            itemSyncQueued = true
            Azaath:RunOutOfCombat(function()
                itemSyncQueued = false
                M:SyncItemBtn()
            end)
        end
        return
    end
    local b, cur, root = card.itemBtn, card.cur, Azaath.root
    local id = b.wantItem
    local r, bt, rl = cur:GetRight(), cur:GetBottom(), root:GetLeft()
    if not (id and card:IsVisible() and cur:IsShown() and r and bt and rl) then
        b:Hide()
        return
    end
    local curES, rootES = cur:GetEffectiveScale(), root:GetEffectiveScale()
    b:SetScale(curES / rootES)
    b:SetFrameStrata(cur:GetFrameStrata())
    b:SetFrameLevel(cur:GetFrameLevel() + 5)
    b:ClearAllPoints()
    b:SetPoint("BOTTOMRIGHT", root, "BOTTOMLEFT",
        r - rl * rootES / curES - 6,
        bt - root:GetBottom() * rootES / curES + 6)
    if b.itemID ~= id then
        local icon = (_G.C_Item and _G.C_Item.GetItemIconByID and Safe(_G.C_Item.GetItemIconByID, id))
                  or (_G.GetItemIcon and Safe(_G.GetItemIcon, id))
                  or "Interface\\Icons\\INV_Misc_QuestionMark"
        b.itemID = id
        b.icon:SetTexture(icon)
        b:SetAttribute("type", "item")
        b:SetAttribute("item", "item:" .. id)
    end
    b:Show()
end

local function NotifyTrackerLayout()
    local newH = M:GetHeight()
    if newH ~= lastGuideH then
        lastGuideH = newH
        local qt = Azaath:GetModule("QuestTracker")
        if qt and qt.Refresh then qt:Refresh() end
    end
end

function M:UpdateCard()
    if not (self.db and self.db.enabled) then
        if card then card:Hide() end
        NotifyTrackerLayout()
        return
    end
    if not card then BuildCard() end
    self:AnchorCard()

    local mode = self.db.mode or "loremaster"
    for _, b in ipairs(card.modeBtns) do
        local on = (b.key == mode)
        b.bg:SetColorTexture(on and 0.16 or 0.08, on and 0.34 or 0.12, on and 0.38 or 0.15, 0.94)
        b.txt:SetTextColor(on and 0.37 or 0.65, on and 0.89 or 0.70, on and 0.90 or 0.72)
    end

    local qn = Azaath:GetModule("QuestNav")
    local magicOn = not (qn and qn.db and qn.db.magicPath == false)
    card.magicBtn.bg:SetColorTexture(magicOn and 0.14 or 0.09, magicOn and 0.30 or 0.13, magicOn and 0.36 or 0.16, 0.94)
    card.magicBtn.txt:SetTextColor(magicOn and 0.37 or 0.60, magicOn and 0.89 or 0.65, magicOn and 0.90 or 0.68)

    local transparent = Azaath.db and Azaath.db.questtracker and Azaath.db.questtracker.transparentBg
    local bgAlpha = transparent and 0 or 1
    if card.bg then card.bg:SetAlpha(bgAlpha) end
    if card.hdrBg then card.hdrBg:SetAlpha(bgAlpha) end
    if card.zoneBar and card.zoneBar.bg then card.zoneBar.bg:SetAlpha(bgAlpha) end
    if card.cur and card.cur.bg then card.cur.bg:SetAlpha(bgAlpha) end
    if card.nextRows then
        for i = 1, MAX_NEXT do
            local nr = card.nextRows[i]
            if nr and nr.bg then nr.bg:SetAlpha(bgAlpha) end
        end
    end
    if card.nextZoneBtn and card.nextZoneBtn.bg then card.nextZoneBtn.bg:SetAlpha(bgAlpha) end

    local aqOn = self.db.autoQuest == true
    card.autoQBtn.bg:SetColorTexture(aqOn and 0.14 or 0.09, aqOn and 0.32 or 0.13, aqOn and 0.22 or 0.16, 0.94)
    card.autoQBtn.txt:SetTextColor(aqOn and 0.38 or 0.60, aqOn and 0.92 or 0.65, aqOn and 0.58 or 0.68)

    local s = (mode ~= "none") and currentSteps[1] or nil
    if mode == "none" then
        card.zoneBar:Hide()
        card.cur:Hide()
        for i = 1, MAX_NEXT do card.nextRows[i]:Hide() end
        card.nextZoneBtn:Hide()
        card.expBtn:Hide()
        card.mapBtn:Hide()
        if pickerFrame then pickerFrame:Hide() end
        card:SetHeight(24)
        card:Show()
        NotifyTrackerLayout()
        return
    end

    card.zoneBar:Show()
    local zLabel = activeGuideZoneName or ZoneName(self.db.selectedMapID)
    local prog = activeGuideProgress and (" · " .. activeGuideProgress) or ""
    card.zoneBar.txt:SetText(zLabel .. prog)

    if not s then
        card.cur:Hide()
        for i = 1, MAX_NEXT do card.nextRows[i]:Hide() end
        card.expBtn:Hide()
        card.mapBtn:Hide()
        local emptyH = 44
        if nextZoneSuggestion then
            card.nextZoneBtn:ClearAllPoints()
            card.nextZoneBtn:SetPoint("TOPLEFT", 0, -44)
            card.nextZoneBtn:SetPoint("TOPRIGHT", 0, -44)
            local lvlTxt = nextZoneSuggestion.minLevel > 0 and format(" (Nv. %d+)", nextZoneSuggestion.minLevel) or ""
            card.nextZoneBtn.txt:SetText("Próximo mapa: " .. nextZoneSuggestion.name .. lvlTxt)
            card.nextZoneBtn:Show()
            emptyH = 66
        else
            card.nextZoneBtn:Hide()
        end
        card:SetHeight(emptyH)
        card:Show()
        NotifyTrackerLayout()
        return
    end

    card.expBtn:Show()
    card.mapBtn:Show()
    card.cur:Show()

    local expanded = (self.db.expanded ~= false)
    card.expBtn.txt:SetText(expanded and "▼" or "▲")

    local st = KIND_STYLE[s.kind] or KIND_STYLE.pickup
    card.bar:SetColorTexture(st.col[1], st.col[2], st.col[3], 0.95)
    card.tag:SetText("1. " .. st.tag)
    card.tag:SetTextColor(st.col[1], st.col[2], st.col[3])
    card.dist:SetText(s.yards and s.yards > 0 and (s.yards < 10 and "Perto" or format("%d m", floor(s.yards + 0.5))) or "")
    card.title:SetText(s.title)

    -- Item Usável no passo (botão seguro: aplicado fora de combate)
    card.itemBtn.wantItem = (s.itemID and s.itemID > 0 and s.kind == "use") and s.itemID or nil
    self:SyncItemBtn()

    local pMap = _G.C_Map and _G.C_Map.GetBestMapForUnit and Safe(_G.C_Map.GetBestMapForUnit, "player")
    if s.mapID and pMap and s.mapID ~= pMap then
        local hint = (s.note and s.note ~= "") and s.note or ("Ir para " .. ZoneName(s.mapID))
        if s.x and s.x > 0 then
            card.sub:SetText(format("[%s] %s (%.1f, %.1f)", ZoneName(s.mapID), hint, s.x, s.y))
        else
            card.sub:SetText(format("[%s] %s", ZoneName(s.mapID), hint))
        end
    elseif s.x and s.x > 0 then
        card.sub:SetText(format("%s · (%.1f, %.1f)", s.detail or "", s.x, s.y))
    else
        card.sub:SetText(s.detail or "")
    end

    local shownNext = 0
    for i = 1, MAX_NEXT do
        local row = card.nextRows[i]
        local ns = expanded and currentSteps[i + 1] or nil
        if ns then
            local nst = KIND_STYLE[ns.kind] or KIND_STYLE.pickup
            row.step = ns
            row.tag:SetText((i + 1) .. ". " .. nst.tag)
            row.tag:SetTextColor(nst.col[1], nst.col[2], nst.col[3])
            row.title:SetText(ns.title)
            row.dist:SetText(ns.yards and ns.yards > 0 and (ns.yards < 10 and "Perto" or format("%d m", floor(ns.yards + 0.5))) or "")
            row:Show()
            shownNext = shownNext + 1
        else
            row.step = nil
            row:Hide()
        end
    end

    local h = 108 + shownNext * 22
    if nextZoneSuggestion then
        card.nextZoneBtn:ClearAllPoints()
        card.nextZoneBtn:SetPoint("TOPLEFT", 0, -h)
        card.nextZoneBtn:SetPoint("TOPRIGHT", 0, -h)
        local lvlTxt = nextZoneSuggestion.minLevel > 0 and format(" (Nv. %d+)", nextZoneSuggestion.minLevel) or ""
        card.nextZoneBtn.txt:SetText("Próximo mapa: " .. nextZoneSuggestion.name .. lvlTxt)
        card.nextZoneBtn:Show()
        h = h + 22
    else
        card.nextZoneBtn:Hide()
    end

    card:SetHeight(h)
    card:Show()
    NotifyTrackerLayout()
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
-- Eventos e atualização periódica
--------------------------------------------------------------------------------
local driver = CreateFrame("Frame", nil, UIParent)
driver.rebuildElapsed = 0
driver.distElapsed = 0
driver:SetScript("OnUpdate", function(self, elapsed)
    if not (M.db and M.db.enabled) then return end
    elapsed = elapsed or 0
    self.distElapsed = self.distElapsed + elapsed
    if self.distElapsed >= 0.4 then
        self.distElapsed = 0
        M:RefreshDistances()
    end
    self.rebuildElapsed = self.rebuildElapsed + elapsed
    if self.rebuildElapsed >= 2.5 then
        self.rebuildElapsed = 0
        M:Rebuild()
    end
end)

driver:SetScript("OnEvent", function(_, event)
    if event == "QUEST_DETAIL" or event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" or event == "GOSSIP_SHOW" then
        HandleQuestAuto(event)
        return
    end
    local s1 = currentSteps[1]
    if s1 and s1.autoKey then
        if event == "MERCHANT_SHOW" and (s1.kind == "vendor" or s1.kind == "buy") then
            autoDone[s1.autoKey] = true
        elseif event == "TRAINER_SHOW" and s1.kind == "train" then
            autoDone[s1.autoKey] = true
        elseif event == "HEARTHSTONE_BOUND" and s1.kind == "sethome" then
            autoDone[s1.autoKey] = true
        end
    end
    if M.db and M.db.enabled then M:Rebuild() end
end)

function M:OnInitialize()
    self.db = Azaath.db.questroute
end

function M:OnEnable()
    if not (self.db and self.db.enabled) then return end
    BuildCard()
    for _, ev in ipairs({
        "PLAYER_ENTERING_WORLD",
        "QUEST_LOG_UPDATE",
        "QUEST_ACCEPTED",
        "QUEST_REMOVED",
        "QUEST_TURNED_IN",
        "ZONE_CHANGED_NEW_AREA",
        "QUEST_DETAIL",
        "QUEST_PROGRESS",
        "QUEST_COMPLETE",
        "GOSSIP_SHOW",
        "MERCHANT_SHOW",
        "TRAINER_SHOW",
        "HEARTHSTONE_BOUND",
        "BAG_UPDATE_DELAYED",
    }) do
        Azaath.SafeRegister(driver, ev)
    end
    self:Rebuild()
end

--------------------------------------------------------------------------------
-- API pública para QuestGuideMenu
--------------------------------------------------------------------------------
function M:GetKindStyle(kind)
    return KIND_STYLE[kind] or KIND_STYLE.goto
end

function M:CalcGuideProgress(g)
    return CalcGuideProgress(g)
end

function M:IsGuideQuestDone(qid)
    return qid and qid > 0 and IsQuestDone(qid) or false
end

function M:IsStepAutoDone(guideID, st, idx)
    local qid = (st and st.q) or 0
    local skey = (qid > 0 and (st.t .. ":" .. qid)) or ("s" .. (idx or 0))
    if skipped[skey] then return true end
    if guideID and autoDone[guideID .. ":" .. skey] then return true end
    if qid > 0 and IsQuestDone(qid) then return true end
    return false
end

function M:ZoneName(mapID)
    return ZoneName(mapID)
end

function M:MatchCSV(csv, val)
    return MatchCSV(csv, val)
end

function M:SetMode(mode)
    if not self.db then return end
    self.db.mode = mode
    lastAutoKey = nil
    self:Rebuild()
end

function M:SelectGuide(guideID, mapID, keepMode)
    if not self.db then return end
    self.db.selectedGuideID = guideID
    self.db.selectedMapID = mapID
    lastAutoKey = nil
    self:Rebuild()
end

function M:SelectAutoZone()
    if not self.db then return end
    self.db.selectedMapID = nil
    self.db.selectedGuideID = nil
    lastAutoKey = nil
    self:Rebuild()
end

function M:FocusGuideStep(step, openMap)
    if openMap then
        OpenStepOnMap(step)
    else
        FocusStep(step)
    end
end

function M:GetCurrentSteps()
    return currentSteps
end

function M:GetActiveGuideInfo()
    return activeGuideZoneName, activeGuideProgress, nextZoneSuggestion
end

function M:UndoLastSkip()
    local last = table.remove(skipHistory)
    if last then
        skipped[last] = nil
        lastAutoKey = nil
        self:Rebuild()
        return true
    end
    return false
end

function M:ResetAllSkips()
    skipped = {}
    skipHistory = {}
    autoDone = {}
    lastAutoKey = nil
    self:Rebuild()
end

function M:GetSkippedCount()
    local n = 0
    for _ in pairs(skipped) do n = n + 1 end
    return n
end
