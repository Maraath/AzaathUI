--[[----------------------------------------------------------------------------
    AzaathUI - Modules/QuestDB.lua
    Motor nativo de missões (Fase 2):
      * Lê Azaath.QuestDBRaw (Data/Quests/QuestDB.lua) sob demanda.
      * Filtra rigorosamente por Facção, Raça (races + raceHigh) e Classe
        (classes), garantindo que o guia/Loremaster nunca sugira missões
        inexistentes para o personagem atual.
      * Calcula o status de cada missão:
          "completed" | "active" | "available" | "locked" | "excluded"
      * Fornece consultas por zona (uiMapID) com totais para o Loremaster.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("QuestDB")

local _G = _G
local pcall, type, ipairs, pairs, tonumber = pcall, type, ipairs, pairs, tonumber
local band, lshift = bit.band, bit.lshift

local parsed = false
local byID, byZone = {}, {}

local function Safe(fn, ...)
    if not fn then return end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

local function IsCompleted(qid)
    local QL = _G.C_QuestLog
    if QL and QL.IsQuestFlaggedCompleted then
        return Safe(QL.IsQuestFlaggedCompleted, qid) == true
    end
    if _G.IsQuestFlaggedCompleted then
        return Safe(_G.IsQuestFlaggedCompleted, qid) == true
    end
    return false
end

local function SplitNums(s)
    if not s or s == "" then return nil end
    local t = {}
    for num in s:gmatch("(%d+)") do
        t[#t + 1] = tonumber(num)
    end
    return #t > 0 and t or nil
end

-- missões com zona 0 no banco (quase todas de masmorra): a área do AzerothCore (Data/Quests/QuestFix.lua)
-- vira a chave negativa -areaID (cartão de masmorra no Loremaster); cidades viram o mapa delas;
-- sem área, a zona de quem entrega/recebe; sem nada, -1 ("Diversas")
local CITY_AREA = { [1519] = 1453, [1537] = 1455, [1657] = 1457, [1637] = 1454, [1638] = 1456, [1497] = 1458 }
local CONTINENT = { [0] = true, [947] = true, [1414] = true, [1415] = true }
M.MISC_ZONE = -1
local function FixZone(q, fix)
    if q.zone ~= 0 then return q.zone end
    local area = fix and fix.zone and fix.zone[q.id]
    if area then return CITY_AREA[area] or -area end
    if q.sMap and not CONTINENT[q.sMap] then return q.sMap end
    if q.eMap and not CONTINENT[q.eMap] then return q.eMap end
    return M.MISC_ZONE
end

local function EnsureParsed()
    if parsed then return end
    parsed = true
    local raw = Azaath.QuestDBRaw
    if type(raw) ~= "string" then return end
    local fix = Azaath.QuestFix

    for line in raw:gmatch("[^\r\n]+") do
        local id, lvl, minLvl, races, raceHigh, classes, faction, zone,
              sMap, sX, sY, eMap, eX, eY, preAll, preAny, excl, startId, endId, title, skill, qflags =
            line:match("^(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t?([RE]*)$")
        if id then
            id = tonumber(id)
            zone = tonumber(zone) or 0
            local q = {
                id       = id,
                level    = tonumber(lvl) or 0,
                minLevel = tonumber(minLvl) or 0,
                races    = tonumber(races) or 0,
                raceHigh = tonumber(raceHigh) or 0,
                classes  = tonumber(classes) or 0,
                faction  = tonumber(faction) or 0,
                zone     = zone,
                sMap     = tonumber(sMap),
                sX       = tonumber(sX),
                sY       = tonumber(sY),
                eMap     = tonumber(eMap),
                eX       = tonumber(eX),
                eY       = tonumber(eY),
                preAll   = SplitNums(preAll),
                preAny   = SplitNums(preAny),
                excl     = SplitNums(excl),
                startId  = tonumber(startId),
                endId    = tonumber(endId),
                title    = title ~= "" and title or ("Quest #" .. id),
                -- profissão exigida "SkillLine:nível" (nível do QuestieDB) ou só "SkillLine"
                skill      = tonumber(skill:match("^(%d+)")),
                skillMin   = tonumber(skill:match(":(%d+)$")) or 1,
                repeatable = qflags and qflags:find("R", 1, true) ~= nil or false,
                isEvent    = qflags and qflags:find("E", 1, true) ~= nil or false,
            }
            zone = FixZone(q, fix)
            q.zone = zone
            local fm = fix and fix.minLevel and fix.minLevel[id]
            if fm and q.minLevel == 0 then q.minLevel = fm end
            byID[id] = q
            if zone ~= 0 then
                local zlist = byZone[zone]
                if not zlist then zlist = {}; byZone[zone] = zlist end
                zlist[#zlist + 1] = q
            end
        end
    end
    Azaath.QuestDBRaw = nil -- libera memória da string bruta após indexar

    -- Mescla missões aprendidas dinamicamente em AzaathUIDB
    local learned = _G.AzaathUIDB and _G.AzaathUIDB.learnedQuests
    if type(learned) == "table" then
        for id, q in pairs(learned) do
            if type(q) == "table" and not byID[id] then
                byID[id] = q
                if q.zone and q.zone > 0 then
                    local zlist = byZone[q.zone]
                    if not zlist then zlist = {}; byZone[q.zone] = zlist end
                    zlist[#zlist + 1] = q
                end
            end
        end
    end
end

-- Auto-aprendizado de missões novas vistas em NPCs/diário
local function LearnCurrentQuest(questID)
    if not (questID and questID > 0) then return end
    EnsureParsed()
    if byID[questID] then return end

    local CMap = _G.C_Map
    local mapID = CMap and CMap.GetBestMapForUnit and Safe(CMap.GetBestMapForUnit, "player")
    if not mapID then return end
    local pos = CMap.GetPlayerMapPosition and Safe(CMap.GetPlayerMapPosition, mapID, "player")
    local px, py = pos and pos:GetXY()

    local title = (_G.GetTitleText and Safe(_G.GetTitleText))
               or (_G.C_QuestLog and _G.C_QuestLog.GetTitleForQuestID and Safe(_G.C_QuestLog.GetTitleForQuestID, questID))
               or ("Quest #" .. questID)
    local prof = M:GetPlayerProfile()
    local q = {
        id = questID,
        level = prof.level,
        minLevel = 1,
        races = prof.raceBit,
        raceHigh = prof.raceHighBit,
        classes = 0,
        faction = prof.faction,
        zone = mapID,
        sMap = mapID,
        sX = px and math.floor(px * 1000 + 0.5) / 10 or nil,
        sY = py and math.floor(py * 1000 + 0.5) / 10 or nil,
        eMap = mapID,
        eX = px and math.floor(px * 1000 + 0.5) / 10 or nil,
        eY = py and math.floor(py * 1000 + 0.5) / 10 or nil,
        title = title,
        learned = true,
    }
    byID[questID] = q
    local zlist = byZone[mapID]
    if not zlist then zlist = {}; byZone[mapID] = zlist end
    zlist[#zlist + 1] = q

    if _G.AzaathUIDB then
        _G.AzaathUIDB.learnedQuests = _G.AzaathUIDB.learnedQuests or {}
        _G.AzaathUIDB.learnedQuests[questID] = q
    end
end

local learnFrame = CreateFrame("Frame")
learnFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "QUEST_DETAIL" and _G.GetQuestID then
        LearnCurrentQuest(Safe(_G.GetQuestID))
    elseif event == "QUEST_ACCEPTED" then
        local qid = type(arg1) == "number" and arg1 or nil
        if qid and qid > 0 then LearnCurrentQuest(qid) end
    elseif event == "QUEST_TURNED_IN" then
        -- repetíveis não ficam marcadas como concluídas no jogo: guardamos por personagem
        local qid = type(arg1) == "number" and arg1 or nil
        if qid then EnsureParsed() end
        local q = qid and byID[qid]
        if q and q.repeatable and Azaath.db then
            Azaath.db.repeatDone = Azaath.db.repeatDone or {}
            Azaath.db.repeatDone[qid] = (Azaath.db.repeatDone[qid] or 0) + 1
        end
    end
end)
Azaath.SafeRegister(learnFrame, "QUEST_TURNED_IN")
Azaath.SafeRegister(learnFrame, "QUEST_DETAIL")
Azaath.SafeRegister(learnFrame, "QUEST_ACCEPTED")

--------------------------------------------------------------------------------
-- Perfil do jogador (Facção, Raça, Classe, Nível)
--------------------------------------------------------------------------------
local RACE_FALLBACK = {
    Human = 1, Orc = 2, Dwarf = 3, NightElf = 4, Scourge = 5,
    Tauren = 6, Gnome = 7, Troll = 8, Goblin = 9, BloodElf = 10, Draenei = 11,
}

-- profissões do personagem (SkillLine -> nível); nil se o jogo não informar (aí não filtra)
-- (nomes do jogo em inglês e português, para o caso de só haver a lista de perícias por nome)
local SKILL_NAMES = {
    [129] = { "First Aid", "Primeiros Socorros" }, [164] = { "Blacksmithing", "Ferraria" },
    [165] = { "Leatherworking", "Couraria" },      [171] = { "Alchemy", "Alquimia" },
    [182] = { "Herbalism", "Herborismo" },         [185] = { "Cooking", "Culinária" },
    [186] = { "Mining", "Mineração" },             [197] = { "Tailoring", "Alfaiataria" },
    [202] = { "Engineering", "Engenharia" },       [333] = { "Enchanting", "Encantamento" },
    [356] = { "Fishing", "Pesca" },                [393] = { "Skinning", "Esfolamento" },
}
local function PlayerSkills()
    local set, any = {}, false
    if GetProfessions and GetProfessionInfo then
        any = true      -- (a lista vazia também vale: personagem sem profissão)
        local ok, p1, p2, p3, p4, p5 = pcall(GetProfessions)
        if ok then
            for _, idx in pairs({ p1, p2, p3, p4, p5 }) do
                -- name, icon, rank, maxRank, numSpells, spellOffset, skillLine
                local ok2, _, _, rank, _, _, _, line = pcall(GetProfessionInfo, idx)
                if ok2 and line then set[line] = rank or 0 end
            end
        end
    end
    if GetNumSkillLines and GetSkillLineInfo then
        local ranks = {}
        local okN, num = pcall(GetNumSkillLines)
        for i = 1, (okN and num or 0) do
            -- name, isHeader, isExpanded, rank, ...
            local ok, name, isHeader, _, rank = pcall(GetSkillLineInfo, i)
            if ok and name and not isHeader then ranks[name:lower()] = rank or 0; any = true end
        end
        for id, list in pairs(SKILL_NAMES) do
            for _, nm in ipairs(list) do
                local r = ranks[nm:lower()]
                if r and (set[id] or 0) < r then set[id] = r end
            end
        end
    end
    return any and set or nil
end

function M:GetPlayerProfile()
    local _, _, classID = UnitClass("player")
    local _, raceFile, raceID = UnitRace("player")
    if not raceID and raceFile then raceID = RACE_FALLBACK[raceFile] end
    local factionStr = UnitFactionGroup("player")
    local faction = (factionStr == "Alliance" and 1) or (factionStr == "Horde" and 2) or 0
    local level = UnitLevel("player") or 1

    local classBit = classID and lshift(1, classID - 1) or 0
    local raceBit, raceHighBit = 0, 0
    if raceID then
        if raceID <= 32 then
            raceBit = lshift(1, raceID - 1)
        else
            raceHighBit = lshift(1, raceID - 33)
        end
    end
    return {
        level       = level,
        faction     = faction,
        classBit    = classBit,
        raceBit     = raceBit,
        raceHighBit = raceHighBit,
        skills      = PlayerSkills(),
    }
end

local holidayCheckedAt, holidayActive = 0, false
local function HasActiveHoliday()
    local now = _G.GetTime and _G.GetTime() or 0
    if holidayCheckedAt > 0 and (now - holidayCheckedAt) < 60 then return holidayActive end
    holidayCheckedAt = now
    holidayActive = false
    local cal = _G.C_Calendar
    local dt = _G.C_DateAndTime and _G.C_DateAndTime.GetCurrentCalendarTime and Safe(_G.C_DateAndTime.GetCurrentCalendarTime)
    if cal and cal.GetNumDayEvents and dt and dt.monthDay then
        if cal.OpenCalendar then Safe(cal.OpenCalendar) end
        local n = Safe(cal.GetNumDayEvents, 0, dt.monthDay) or 0
        for i = 1, n do
            local ev = cal.GetDayEvent and Safe(cal.GetDayEvent, 0, dt.monthDay, i)
            if ev and (ev.calendarType == "HOLIDAY" or ev.eventType == 0) then
                holidayActive = true
                break
            end
        end
    end
    return holidayActive
end

function M:IsForPlayer(q, prof)
    if not q then return false end
    prof = prof or self:GetPlayerProfile()

    -- Oculta missões de eventos sazonais / feriados quando não há evento ativo
    if q.isEvent and not HasActiveHoliday() then return false end

    -- Oculta missões exclusivas de Season of Discovery (76000..84999) quando SoD não está ativo
    if q.id >= 76000 and q.id < 85000 then
        local season = _G.C_Seasons and _G.C_Seasons.GetActiveSeason and Safe(_G.C_Seasons.GetActiveSeason)
        if season ~= 2 then return false end
    end

    -- Facção (1 = Aliança, 2 = Horda, 0/3 = Ambas)
    if q.faction == 1 and prof.faction ~= 1 then return false end
    if q.faction == 2 and prof.faction ~= 2 then return false end

    -- Classe
    if q.classes > 0 and prof.classBit > 0 then
        if band(q.classes, prof.classBit) == 0 then return false end
    end

    -- Raça (suporta raças padrão + raceHigh para Forever)
    if q.races > 0 or q.raceHigh > 0 then
        local matchLow = (q.races > 0 and prof.raceBit > 0 and band(q.races, prof.raceBit) ~= 0)
        local matchHigh = (q.raceHigh > 0 and prof.raceHighBit > 0 and band(q.raceHigh, prof.raceHighBit) ~= 0)
        if not (matchLow or matchHigh) then return false end
    end

    return true
end

--------------------------------------------------------------------------------
-- Missões ativas no diário atual
--------------------------------------------------------------------------------
local function GetActiveSet()
    local active = {}
    local QL = _G.C_QuestLog
    local n = (QL and QL.GetNumQuestLogEntries and Safe(QL.GetNumQuestLogEntries))
           or (GetNumQuestLogEntries and (GetNumQuestLogEntries())) or 0
    for i = 1, n do
        local qid
        if QL and QL.GetInfo then
            local info = Safe(QL.GetInfo, i)
            if info and not info.isHeader then qid = info.questID end
        elseif GetQuestLogTitle then
            local _, _, _, isHeader, _, _, _, id = GetQuestLogTitle(i)
            if not isHeader then qid = id end
        end
        if qid and qid > 0 then active[qid] = true end
    end
    return active
end

function M:GetStatus(q, prof, activeSet)
    if not q then return "locked" end
    if IsCompleted(q.id) then return "completed" end
    activeSet = activeSet or GetActiveSet()
    if activeSet[q.id] then return "active" end

    if q.excl then
        for _, exId in ipairs(q.excl) do
            if IsCompleted(exId) or activeSet[exId] then
                return "excluded"
            end
        end
    end

    prof = prof or self:GetPlayerProfile()
    -- o servidor só barra pelo nível mínimo; a estimativa (nível da missão - 8) fica para quem não tem mínimo
    if (q.minLevel > 0 and prof.level < q.minLevel) or (q.minLevel == 0 and q.level > 0 and prof.level + 8 < q.level) then
        return "locked", "level"
    end

    -- profissão exigida e nível mínimo (ex.: Deschanfradores pede Pesca 30); sem isso o NPC nem oferece
    if q.skill and prof.skills and (prof.skills[q.skill] or -1) < (q.skillMin or 1) then
        return "locked", "skill"
    end

    if q.preAll then
        for _, pId in ipairs(q.preAll) do
            if not IsCompleted(pId) then return "locked", "prereq" end
        end
    end

    if q.preAny then
        local anyOk = false
        for _, pId in ipairs(q.preAny) do
            if IsCompleted(pId) then anyOk = true; break end
        end
        if not anyOk then return "locked", "prereq" end
    end

    return "available"
end

-- faixa de nível típica de uma zona pelas missões que COMEÇAM nela (sem as de classe e de profissão):
-- descarta as que ficam a mais de 10 níveis da mediana e devolve os percentis 10 e 90. nil com menos de 8.
local zoneRange = {}
function M:ZoneLevelRange(uiMapID)
    EnsureParsed()
    if zoneRange[uiMapID] ~= nil then return unpack(zoneRange[uiMapID] or {}) end
    local lv = {}
    for _, q in pairs(byID) do
        if q.sMap == uiMapID and (q.level or 0) > 0 and (q.classes or 0) == 0 and not q.skill then
            lv[#lv + 1] = q.level
        end
    end
    local r = false
    if #lv >= 8 then
        table.sort(lv)
        local med = lv[math.floor(#lv / 2) + 1]
        local t = {}
        for _, v in ipairs(lv) do if v >= med - 10 and v <= med + 10 then t[#t + 1] = v end end
        local function P(p) return t[math.floor(p * (#t - 1)) + 1] end
        r = { P(0.1), P(0.9) }
    end
    zoneRange[uiMapID] = r
    if r then return r[1], r[2] end
end

-- quantas vezes o personagem já entregou esta repetível (desde que o AzaathUI passou a contar)
function M:RepeatDoneCount(questID)
    local t = Azaath.db and Azaath.db.repeatDone
    return t and t[questID] or 0
end

-- marca/desmarca à mão (repetíveis entregues antes de o AzaathUI contar)
function M:ToggleRepeatDone(questID)
    if not Azaath.db then return end
    local t = Azaath.db.repeatDone or {}
    Azaath.db.repeatDone = t
    t[questID] = (t[questID] or 0) > 0 and nil or 1
end

function M:GetQuest(questID)
    EnsureParsed()
    return byID[questID]
end

function M:GetTitle(q)
    if not q then return "" end
    local QL = _G.C_QuestLog
    if QL and QL.GetTitleForQuestID then
        local t = Safe(QL.GetTitleForQuestID, q.id)
        if t and t ~= "" then return t end
    end
    return q.title
end

-- zonas (uiMapID) que têm missões no banco
function M:GetZoneIDs()
    EnsureParsed()
    local ids = {}
    for id in pairs(byZone) do ids[#ids + 1] = id end      -- negativos: -areaID (masmorra) e -1 (diversas)
    return ids
end

-- Retorna lista ordenada + contadores de uma zona (uiMapID) filtrada para o jogador
function M:GetZoneQuests(uiMapID)
    EnsureParsed()
    local rawList = byZone[uiMapID]
    local out = {}
    local counts = { total = 0, completed = 0, active = 0, available = 0, locked = 0 }
    if not rawList then return out, counts end

    local prof = self:GetPlayerProfile()
    local activeSet = GetActiveSet()

    for _, q in ipairs(rawList) do
        if self:IsForPlayer(q, prof) then
            local status, reason = self:GetStatus(q, prof, activeSet)
            if status ~= "excluded" then
                counts.total = counts.total + 1
                counts[status] = (counts[status] or 0) + 1
                out[#out + 1] = {
                    quest  = q,
                    title  = self:GetTitle(q),
                    status = status,
                    reason = reason,
                }
            end
        end
    end

    local ORDER = { active = 1, available = 2, locked = 3, completed = 4 }
    table.sort(out, function(a, b)
        local oa, ob = ORDER[a.status] or 9, ORDER[b.status] or 9
        if oa ~= ob then return oa < ob end
        if a.quest.level ~= b.quest.level then return a.quest.level < b.quest.level end
        return a.title < b.title
    end)

    return out, counts
end
