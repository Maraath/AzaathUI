--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Quest.lua
    Detecção de mobs de missão (QuestLog, Tooltip, progresso 3/10, Questie) +
    detecção preservada de NPCs utilitários aliados (leilão, estalagem, banco,
    voo, treinador, conserto, vendedor e pinos de missão).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, tonumber, tostring, type = pairs, ipairs, pcall, tonumber, tostring, type
local wipe, GetTime = wipe, _G.GetTime

local QL = _G.C_QuestLog
local TI = _G.C_TooltipInfo
local TLT = _G.Enum and _G.Enum.TooltipDataLineType
local QUEST_OBJ_LINE = TLT and TLT.QuestObjective or 8
local QUEST_TITLE_LINE = TLT and TLT.QuestTitle or 17
local QUEST_PLAYER_LINE = TLT and TLT.QuestPlayer or 18

-- Utilitários aliados (preservado do sistema original do AzaathUI)
NP.UTILITY_ICONS = {
    auction         = "Interface\\Icons\\INV_Misc_Coin_01",
    inn             = "Interface\\Icons\\INV_Misc_Rune_01",
    bank            = "Interface\\GossipFrame\\BankerGossipIcon",
    repair          = "Interface\\Icons\\Trade_BlackSmithing",
    flight          = "Interface\\GossipFrame\\TaxiGossipIcon",
    trainer         = "Interface\\GossipFrame\\TrainerGossipIcon",
    vendor          = "Interface\\GossipFrame\\VendorGossipIcon",
    quest_available = "Interface\\GossipFrame\\AvailableQuestIcon",
    quest_turnin    = "Interface\\GossipFrame\\ActiveQuestIcon",
    quest           = "Interface\\GossipFrame\\ActiveQuestIcon",
}

NP.NPC_QUEST_PIN = {
    new  = { "PinGetN2",  15, 27 },
    done = { "PinDoneN3", 14, 29 },
    prog = { "PinProgN2", 21, 25 },
}

local UTILITY_KEYWORDS = {
    { type = "auction", words = { "leiloeir", "leilao", "leilão", "auctioneer", "auction", "subasta" } },
    { type = "inn",     words = { "estalajad", "estalagem", "taverneir", "taverna", "taberneir", "pousadeir", "pousada", "innkeeper", "inn", "tavern", "bartender", "posader", "taberner" } },
    { type = "bank",    words = { "banqueir", "banker", "banco", "bank", "cofre", "vault" } },
    { type = "flight",  words = { "mestre de voo", "mestra de voo", "mestre de vôo", "mestre de grifos", "mestra de grifos", "dracole", "hipogrifo", "grifo", "flight master", "flightmaster", "gryphon master", "bat rider", "wind rider", "maestro de vuelo" } },
    { type = "trainer", words = { "treinador", "treinadora", "instrutor", "instrutora", "trainer", "instructor", "mestre de armas", "weapon master" } },
    { type = "repair",  words = { "conserto", "consertos", "repara", "reparo", "ferreir", "ferraria", "armeir", "armaria", "armadur", "forja", "repair", "blacksmith", "armorer", "armourer", "weaponsmith", "armorsmith", "herrero", "armero" } },
    { type = "vendor",  words = { "vendedor", "vendedora", "comerciante", "mercador", "mercadora", "suprimentos", "provis", "vendor", "merchant", "supplies", "provisions", "alquimista", "alfaiate", "coureiro", "comida", "bebida", "reagentes", "reagents", "trader", "goods" } },
    { type = "quest",   words = { "missões", "missoes", "missao", "missão", "quest" } },
}
local NAME_TYPES = { inn = true, bank = true, flight = true, trainer = true, auction = true }

local function WordAt(clean, word, startOnly)
    local init = 1
    while true do
        local s = clean:find(word, init, true)
        if not s then return false end
        if s == 1 then return true end
        if startOnly then return false end
        if not clean:sub(s - 1, s - 1):find("[%w\128-\255]") then return true end
        init = s + 1
    end
end

local function MatchUtilityType(text, isName)
    if type(text) ~= "string" or text == "" or NP.IsSecret(text) then return nil end
    local clean = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s*<", ""):lower()
    for _, entry in ipairs(UTILITY_KEYWORDS) do
        if entry.type ~= "quest" and (not isName or NAME_TYPES[entry.type]) then
            for _, w in ipairs(entry.words) do
                if WordAt(clean, w, isName) then return entry.type end
            end
        end
    end
    return nil
end

local function ReadyToTurnInAt(guid)
    if not guid or NP.IsSecret(guid) then return false end
    local npcID = tonumber((select(6, _G.strsplit("-", guid))))
    local qdb = npcID and QL and QL.GetNumQuestLogEntries and QL.GetInfo and QL.IsComplete and Azaath:GetModule("QuestDB")
    if not (qdb and qdb.GetQuest) then return false end
    local okN, n = pcall(QL.GetNumQuestLogEntries)
    for i = 1, (okN and n or 0) do
        local ok, info = pcall(QL.GetInfo, i)
        local id = ok and info and not info.isHeader and info.questID
        if id and id > 0 then
            local okC, done = pcall(QL.IsComplete, id)
            local q = okC and done and qdb:GetQuest(id)
            if q and q.endId == npcID then return true end
        end
    end
    return false
end

NP.utilityCache = {}
NP.npcQuestState = {}

local function GetInteractingNPCGUID(strict)
    if _G.UnitExists and _G.UnitExists("npc") then
        local g = _G.UnitGUID("npc")
        if g and not NP.IsSecret(g) and g ~= "" then return g end
    end
    if strict then return nil end
    if _G.UnitExists and _G.UnitExists("target") and _G.UnitCanAttack and not NP.Truthy(_G.UnitCanAttack("player", "target"), false) then
        local g = _G.UnitGUID("target")
        if g and not NP.IsSecret(g) and g ~= "" then return g end
    end
    return nil
end

function NP.DetectNPCUtility(unit)
    if not unit then return nil end
    if _G.UnitIsPlayer and NP.Truthy(_G.UnitIsPlayer(unit), false) then return nil end
    local guid = _G.UnitGUID and _G.UnitGUID(unit)
    if guid and NP.IsSecret(guid) then guid = nil end
    if guid and NP.utilityCache[guid] ~= nil then return NP.utilityCache[guid] or nil end
    local gtype = guid and guid:match("^(%a+)%-")
    if gtype and gtype ~= "Creature" and gtype ~= "Vehicle" then
        if guid then NP.utilityCache[guid] = false end
        return nil
    end

    local subtitle = NP.NPCTitle and NP.NPCTitle(unit)
    local rawName = _G.UnitName and _G.UnitName(unit)
    if rawName and NP.IsSecret(rawName) then rawName = nil end

    local serviceType = MatchUtilityType(subtitle) or (rawName and MatchUtilityType(rawName, true))
    local qState = guid and NP.npcQuestState[guid]
    local isRelated = NP.IsMyQuestUnit(unit)
    if qState and qState.turnedInTime and (GetTime() - qState.turnedInTime < 2.5) and not qState.hasTurnIn then
        isRelated = false
    end
    local readyHere = ReadyToTurnInAt(guid)
    if readyHere then isRelated = true end

    local questType, questIcon
    if (qState and qState.hasTurnIn) or isRelated then
        questType, questIcon = "quest_turnin", NP.UTILITY_ICONS.quest_turnin
    elseif qState and qState.hasAvailable then
        questType, questIcon = "quest_available", NP.UTILITY_ICONS.quest_available
    elseif not (qState and qState.noQuests) and type(subtitle) == "string" then
        local low = subtitle:lower()
        if low:find("miss", 1, true) or low:find("quest", 1, true) then
            questType, questIcon = "quest_available", NP.UTILITY_ICONS.quest_available
        end
    end

    local uType = questType or serviceType
    local icon = questIcon or (serviceType and NP.UTILITY_ICONS[serviceType])
    local res = nil
    if uType and icon then
        res = {
            type = uType,
            icon = icon,
            pin  = (uType == "quest_turnin" and (((qState and qState.hasTurnIn) or readyHere) and "done" or "prog"))
                or (uType == "quest_available" and "new") or nil,
        }
        if guid then NP.utilityCache[guid] = res end
    end
    return res
end

-- Detecção de inimigos de missão + progresso (ex: "3/10") e tipo (kill / item)
local function QuestieOn()
    local g = NP.db and NP.db.general
    if not (g and g.questieSource) then return false end
    return type(_G.QuestieLoader) == "table" and not NP.inInstance
end

local function IsMyName(txt)
    if type(txt) ~= "string" or NP.IsSecret(txt) then return false end
    local myName = _G.UnitName and _G.UnitName("player")
    if type(myName) ~= "string" or NP.IsSecret(myName) or myName == "" then return false end
    local clean = txt:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):match("^%s*(.-)%s*$")
    if clean == myName then return true end
    return clean:sub(1, #myName) == myName and clean:sub(#myName + 1, #myName + 1) == "-"
end

local function IsMyQuestID(qid)
    if type(qid) ~= "number" or NP.IsSecret(qid) or qid <= 0 then return nil end
    if QL and QL.IsOnQuest then
        local ok, onQ = pcall(QL.IsOnQuest, qid)
        if ok and not NP.IsSecret(onQ) then return onQ == true end
    end
    return nil
end

local function ReadTooltipQuests(unit)
    if not (TI and TI.GetUnit) then return false, nil, nil, false end
    local ok, data = pcall(TI.GetUnit, unit)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return false, nil, nil, false end
    if _G.TooltipUtil and _G.TooltipUtil.SurfaceArgs then pcall(_G.TooltipUtil.SurfaceArgs, data) end
    local related, progText, qKind, sawQuestLine = false, nil, nil, false
    local foreignSection = false
    for _, line in ipairs(data.lines) do
        if type(line) == "table" then
            local t = line.type
            if not NP.IsSecret(t) then
                if t == QUEST_PLAYER_LINE then
                    sawQuestLine = true
                    foreignSection = not IsMyName(line.leftText)
                elseif t == QUEST_TITLE_LINE then
                    sawQuestLine = true
                    local mine = IsMyQuestID(line.id or line.questID)
                    if mine ~= nil then foreignSection = not mine end
                elseif t == QUEST_OBJ_LINE then
                    sawQuestLine = true
                    local mine = IsMyQuestID(line.id or line.questID)
                    local allowed = (mine ~= nil) and mine or (not foreignSection)
                    local done = line.completed
                    if allowed and not NP.IsSecret(done) and not done then
                        related = true
                        local txt = line.leftText
                        if type(txt) == "string" and not NP.IsSecret(txt) then
                            local cur, tot = txt:match("(%d+)%s*/%s*(%d+)")
                            if cur and tot and tonumber(cur) < tonumber(tot) then
                                progText = cur .. "/" .. tot
                            end
                            local low = txt:lower()
                            if low:find("slain") or low:find("mort") or low:find("abatid") or low:find("killed") then
                                qKind = qKind or "kill"
                            else
                                qKind = qKind or "item"
                            end
                        end
                    end
                end
            end
        end
    end
    return related, progText, qKind, sawQuestLine
end

function NP.IsMyQuestUnit(unit)
    if not unit or NP.inInstance then return false, nil, nil end
    if QuestieOn() then
        local qid = NP.NpcID and NP.NpcID(unit)
        local qdb = _G.QuestieDB
        local qpl = _G.QuestiePlayer
        if qid and qdb and qpl and type(qpl.currentQuestlog) == "table" and qdb.GetNPC then
            local ok, npc = pcall(qdb.GetNPC, qid)
            if ok and type(npc) == "table" and type(npc.questStarts) == "table" then
                for _, questId in ipairs(npc.questStarts) do
                    if qpl.currentQuestlog[questId] then return true, nil, "default" end
                end
            end
            if ok and type(npc) == "table" and type(npc.questEnds) == "table" then
                for _, questId in ipairs(npc.questEnds) do
                    if qpl.currentQuestlog[questId] then return true, nil, "default" end
                end
            end
        end
    end
    local tipRel, prog, kind, sawQuestLine = ReadTooltipQuests(unit)
    if tipRel then return true, prog, kind end
    if sawQuestLine then return false, nil, nil end
    local related = false
    if QL and QL.UnitIsRelatedToActiveQuest then
        local ok, v = pcall(QL.UnitIsRelatedToActiveQuest, unit)
        if ok and not NP.IsSecret(v) and v then related = true end
    end
    return related, prog, kind
end

function NP.QuestKind(unit)
    local _, _, kind = NP.IsMyQuestUnit(unit)
    return kind or "default"
end

-- Eventos de atualização de missões e interações com NPCs
local qEvents = _G.CreateFrame("Frame")
for _, e in ipairs({
    "QUEST_LOG_UPDATE", "UNIT_QUEST_LOG_CHANGED", "GOSSIP_SHOW", "GOSSIP_CLOSED",
    "QUEST_GREETING", "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE",
    "QUEST_ACCEPTED", "QUEST_TURNED_IN", "QUEST_FINISHED", "MERCHANT_SHOW", "TAXIMAP_OPENED",
}) do
    Azaath.SafeRegister(qEvents, e)
end

local questPending = false
local function RefreshAllQuests()
    if questPending then return end
    questPending = true
    _G.C_Timer.After(0.2, function()
        questPending = false
        for _, f in pairs(NP.ActivePlates) do
            if f.active then
                local q, prog, kind = NP.IsMyQuestUnit(f.unit)
                f.isQuest, f.questText, f.questKind = q, prog, kind
                if NP.UpdateQuestIcon then NP.UpdateQuestIcon(f) end
                if NP.UpdateServiceIcon then NP.UpdateServiceIcon(f) end
                if NP.UpdateHealthColor then NP.UpdateHealthColor(f) end
            end
        end
    end)
end

qEvents:SetScript("OnEvent", function(_, event)
    if not NP.db then return end
    if event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
        wipe(NP.utilityCache)
        RefreshAllQuests()
    elseif event == "GOSSIP_SHOW" then
        local g = GetInteractingNPCGUID()
        if g then
            local act = Azaath.API.GossipActiveQuests and Azaath.API.GossipActiveQuests() or {}
            local av = Azaath.API.GossipAvailableQuests and Azaath.API.GossipAvailableQuests() or {}
            NP.npcQuestState[g] = { hasTurnIn = #act > 0, hasAvailable = #av > 0, noQuests = (#act == 0 and #av == 0), lastCheck = GetTime() }
            NP.utilityCache[g] = nil
            RefreshAllQuests()
        end
    elseif event == "QUEST_GREETING" then
        local g = GetInteractingNPCGUID()
        if g then
            local na = _G.GetNumActiveQuests and _G.GetNumActiveQuests() or 0
            local nv = _G.GetNumAvailableQuests and _G.GetNumAvailableQuests() or 0
            NP.npcQuestState[g] = { hasTurnIn = na > 0, hasAvailable = nv > 0, noQuests = (na == 0 and nv == 0), lastCheck = GetTime() }
            NP.utilityCache[g] = nil
            RefreshAllQuests()
        end
    elseif event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        local g = GetInteractingNPCGUID()
        if g then
            local cur = NP.npcQuestState[g]
            NP.npcQuestState[g] = { hasTurnIn = true, hasAvailable = cur and cur.hasAvailable or false, noQuests = false, lastCheck = GetTime() }
            NP.utilityCache[g] = nil; RefreshAllQuests()
        end
    elseif event == "QUEST_DETAIL" then
        local g = GetInteractingNPCGUID()
        if g then
            local cur = NP.npcQuestState[g]
            NP.npcQuestState[g] = { hasTurnIn = cur and cur.hasTurnIn or false, hasAvailable = true, noQuests = false, lastCheck = GetTime() }
            NP.utilityCache[g] = nil; RefreshAllQuests()
        end
    elseif event == "QUEST_TURNED_IN" then
        local g = GetInteractingNPCGUID()
        if g then
            NP.npcQuestState[g] = { hasTurnIn = false, hasAvailable = false, noQuests = false, turnedInTime = GetTime(), lastCheck = GetTime() }
        end
        wipe(NP.utilityCache); RefreshAllQuests()
    elseif event == "QUEST_ACCEPTED" then
        local g = GetInteractingNPCGUID()
        if g and NP.npcQuestState[g] then NP.npcQuestState[g].hasAvailable = false end
        wipe(NP.utilityCache); RefreshAllQuests()
    elseif event == "QUEST_FINISHED" or event == "GOSSIP_CLOSED" then
        local g = GetInteractingNPCGUID()
        if g and NP.npcQuestState[g] and not NP.npcQuestState[g].hasAvailable then
            NP.npcQuestState[g].noQuests = true; NP.npcQuestState[g].hasTurnIn = false
            NP.utilityCache[g] = nil; RefreshAllQuests()
        end
    elseif event == "MERCHANT_SHOW" then
        local g = GetInteractingNPCGUID(true)
        if g then
            local rep = _G.CanMerchantRepair and _G.CanMerchantRepair()
            NP.utilityCache[g] = { type = rep and "repair" or "vendor", icon = rep and NP.UTILITY_ICONS.repair or NP.UTILITY_ICONS.vendor }
            RefreshAllQuests()
        end
    elseif event == "TAXIMAP_OPENED" then
        local g = GetInteractingNPCGUID(true)
        if g then
            NP.utilityCache[g] = { type = "flight", icon = NP.UTILITY_ICONS.flight }
            RefreshAllQuests()
        end
    end
end)
