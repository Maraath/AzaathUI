--[[----------------------------------------------------------------------------
    AzaathUI - Olho de Azaath / Sense.lua
    O que o Olho sabe do alvo de interação do jogo ("softinteract"):
      * qual é a unidade e a placa de nome dela;
      * a categoria do objeto: minério, erva, missão, baú, boia de pesca ou outro;
      * o estado: longe, pronto para interagir ou recusado pelo jogo agora.

    A categoria sai, em ordem de confiança:
      1. do número do objeto no GUID (a boia de pesca tem um número fixo);
      2. do cursor que o jogo mostraria sobre ele (mineração, herborismo, missão...);
      3. de o jogo dizer que o objeto pertence a uma missão ativa;
      4. do nome do objeto comparado aos objetivos das missões abertas;
      5. de o jogador já ter saqueado um objeto com esse número, ou de o nome
         soar como baú no idioma do cliente.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local ns = Azaath.OlhoNS
local L = ns.L
local SafeCall, IsSecret, Fold, NameKey = ns.SafeCall, ns.IsSecret, ns.Fold, ns.NameKey

local pairs, ipairs, type, pcall, tonumber = pairs, ipairs, type, pcall, tonumber

local SOFT = "softinteract"
local BOBBER = { [35591] = true }       -- número da boia de pesca (o mesmo em todo lançamento)
local FISHING_ICON = 136245              -- ícone do feitiço de pesca

local S = {}
ns.Sense = S

--------------------------------------------------------------------------------
-- Cursor
--------------------------------------------------------------------------------

-- palavra no nome do cursor -> categoria; a primeira que aparece vale
local CURSOR_WORDS = {
    { "gatherherb", "herb" }, { "herb", "herb" }, { "mine", "ore" },
    { "quest", "quest" }, { "important", "quest" }, { "recurring", "quest" }, { "wrapper", "quest" },
    { "fishing", "bobber" },
    { "lootall", "chest" }, { "picklock", "chest" }, { "pickup", "chest" },
    { "mail", "service" }, { "speak", "service" }, { "buy", "service" }, { "trainer", "service" },
    { "taxi", "service" }, { "innkeeper", "service" }, { "repair", "service" }, { "stable", "service" },
    { "interact", "other" }, { "inspect", "other" },
}

-- cursores conhecidos, para achar pelo número do arquivo quando o jogo só dá o número
local CURSOR_FILES = {
    "Mine", "GatherHerbs", "Quest", "QuestRepeatable", "QuestTurnIn", "QuestInteract", "CampaignQuest",
    "CampaignQuestTurnIn", "LegendaryQuest", "LegendaryQuestTurnIn", "Important", "ImportantTurnIn",
    "Recurring", "Recurringturnin", "Wrapper", "Wrapperturnin", "PickLock", "LootAll", "Pickup",
    "Fishing", "FishingCursor", "Interact", "GamepadInteract", "Inspect", "Mail", "Speak", "Buy", "Trainer",
    "Taxi", "Innkeeper", "Repair", "RepairNPC", "Stablemaster",
}

local fileToName = {} -- fileID -> nome do cursor ("Mine", "UnableMine"...)
local probe

local function Probe()
    if not probe then
        probe = UIParent:CreateTexture(nil, "BACKGROUND")
        probe:Hide()
    end
    return probe
end

function S.Init()
    Probe()
    if not GetFileIDFromPath then return end
    for _, base in ipairs(CURSOR_FILES) do
        for _, prefix in ipairs({ "", "Unable" }) do
            local path = "Interface\\Cursor\\" .. prefix .. base
            local id = SafeCall(GetFileIDFromPath, path) or SafeCall(GetFileIDFromPath, path .. ".blp")
            if id then fileToName[id] = prefix .. base end
        end
    end
end

-- categoria e "acinzentado" (cursor Unable*: o jogo recusa por enquanto) de um nome de cursor
local function FromCursorName(text)
    if type(text) ~= "string" then return nil, false end
    text = text:lower()
    local unable = text:find("unable", 1, true) ~= nil
    for _, w in ipairs(CURSOR_WORDS) do
        if text:find(w[1], 1, true) then return w[2], unable end
    end
    return nil, unable
end

-- devolve: tem cursor?, categoria, acinzentado, texto bruto do cursor
function S.ReadCursor(unit)
    local tex = Probe()
    if not SafeCall(SetUnitCursorTexture, tex, unit, nil, true) then return false end
    local file = tex:GetTexture()
    local atlas = tex.GetAtlas and tex:GetAtlas()
    if IsSecret(file) then file = nil end
    if IsSecret(atlas) then atlas = nil end
    local raw = type(file) == "number" and fileToName[file] or file
    local cat, unable = FromCursorName(raw)
    if not cat then
        local c2, u2 = FromCursorName(atlas)
        cat, unable = c2, unable or u2
    end
    return true, cat, unable, atlas or raw
end

-- cursor de exemplo por categoria (a prévia não tem objeto a quem perguntar)
S.SAMPLE_CURSOR = { ore = "Mine", herb = "GatherHerbs", quest = "Quest", chest = "Pickup", bobber = "Fishing", other = "Interact" }

--------------------------------------------------------------------------------
-- Número do objeto, pesca
--------------------------------------------------------------------------------

local function ObjectNumber(guid)
    if type(guid) ~= "string" then return nil end
    return tonumber(guid:match("^GameObject%-%d+%-%d+%-%d+%-%d+%-(%d+)"))
end

function S.ObjectID(unit)
    return ObjectNumber(SafeCall(UnitGUID, unit))
end

-- o jogador está pescando? (devolve também nome e ícone da canalização, para o diagnóstico)
function S.Fishing()
    if not UnitChannelInfo then return false end
    local ok, name, _, icon = pcall(UnitChannelInfo, "player")
    if not ok then return false end
    if IsSecret(name) then name = nil end
    if IsSecret(icon) then icon = nil end
    if not name and not icon then return false end
    local yes = icon == FISHING_ICON
        or (type(icon) == "string" and icon:lower():find("trade_fishing", 1, true) ~= nil)
        or (name ~= nil and name == PROFESSIONS_FISHING)
    return yes, name, icon
end

--------------------------------------------------------------------------------
-- Missões
--------------------------------------------------------------------------------

local objectives = {}   -- { text = texto normalizado, item = objetivo de pegar/usar }
local titles = {}       -- título normalizado -> true (missões abertas)
local stale = true

local function Normalize(text)
    text = text:lower():gsub("\194\160", " "):gsub("\226\128\153", "'")
    text = text:gsub("%d+%s*/%s*%d+", "")     -- tira contadores "0/5"
    return (text:match("^[%s:%-]*(.-)[%s:%-]*$"))
end

local commonWords
local function Common()
    if not commonWords then
        commonWords = {}
        for w in Normalize(ns.CommonWords()):gmatch("%S+") do commonWords[w] = true end
    end
    return commonWords
end

local function Rebuild()
    stale = false
    wipe(objectives)
    wipe(titles)
    local QL = C_QuestLog
    if not (QL and QL.GetQuestObjectives) then return end
    local count = SafeCall(QL.GetNumQuestLogEntries or GetNumQuestLogEntries) or 0
    for i = 1, count do
        local id, title
        if QL.GetQuestIDForLogIndex then
            id = SafeCall(QL.GetQuestIDForLogIndex, i)
            title = type(id) == "number" and SafeCall(QL.GetTitleForQuestID, id)
        elseif GetQuestLogTitle then
            local ok, t, _, _, header, _, _, _, qid = pcall(GetQuestLogTitle, i)
            if ok and not header then id, title = qid, t end
        end
        if type(title) == "string" then titles[Normalize(title)] = true end
        local list = type(id) == "number" and SafeCall(QL.GetQuestObjectives, id)
        if type(list) == "table" then
            for _, o in ipairs(list) do
                local t = o.text
                if not o.finished and type(t) == "string" and not IsSecret(t) then
                    t = Normalize(t)
                    if #t >= 4 then
                        objectives[#objectives + 1] = { text = t, item = o.type == nil or o.type == "item" or o.type == "object" }
                    end
                end
            end
        end
    end
end

function S.QuestsChanged() stale = true end

function S.Objectives()
    if stale then Rebuild() end
    return objectives, titles
end

-- uma palavra marcante (5+ letras, não comum) de `a` que inicia uma palavra de `b`
local function MarkedWord(a, b)
    local common = Common()
    b = " " .. b:gsub("%p", " ")
    for w in a:gmatch("[^%s%p]+") do
        if #w >= 5 and not common[w] and b:find(" " .. w, 1, true) then return w end
    end
end

-- o que liga um nome de objeto a uma missão aberta (texto do diagnóstico), ou nil
function S.QuestMatch(name)
    if type(name) ~= "string" or #name < 4 then return nil end
    if stale then Rebuild() end
    local n = Normalize(name)
    local learned = ns.db.questObjects[n]
    if learned and titles[learned] then return L.MATCH_TOOLTIP end
    for _, o in ipairs(objectives) do
        if o.text:find(n, 1, true) or (#o.text >= 5 and n:find(o.text, 1, true)) then return L.MATCH_NAME end
    end
    for _, o in ipairs(objectives) do
        if o.item then -- nunca com objetivo de matar: "Cabana Murloc" não é "Murloc morto"
            local w = MarkedWord(n, o.text) or MarkedWord(o.text, n)
            if w then return L.MATCH_WORD:format(w) end
        end
    end
end

-- A dica do cursor no mundo mostra o título da missão de um objeto de missão:
-- guarda nome -> título. Devolve true se aprendeu algo novo.
function S.LearnFromTooltip()
    local TI = C_TooltipInfo
    if not (TI and TI.GetWorldCursor) then return false end
    local data = SafeCall(TI.GetWorldCursor)
    local lines = type(data) == "table" and data.lines
    if type(lines) ~= "table" or not lines[1] then return false end
    if Enum and Enum.TooltipDataType and data.type == Enum.TooltipDataType.Unit then return false end
    local name = lines[1].leftText
    if type(name) ~= "string" or IsSecret(name) then return false end
    if stale then Rebuild() end
    for i = 2, #lines do
        local t = lines[i].leftText
        if type(t) == "string" and not IsSecret(t) then
            local title = Normalize(t)
            if titles[title] then
                local key = Normalize(name)
                if ns.db.questObjects[key] == title then return false end
                ns.db.questObjects[key] = title
                return true
            end
        end
    end
    return false
end

local QUEST_LINE = Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective

-- o próprio jogo liga a unidade a uma missão ativa?
local function GameSaysQuest(unit)
    if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest
        and SafeCall(C_QuestLog.UnitIsRelatedToActiveQuest, unit) == true then
        return true
    end
    if QUEST_LINE and C_TooltipInfo and C_TooltipInfo.GetUnit then
        local data = SafeCall(C_TooltipInfo.GetUnit, unit)
        if type(data) == "table" and type(data.lines) == "table" then
            for _, line in ipairs(data.lines) do
                if line.type == QUEST_LINE then return true end
            end
        end
    end
    return false
end
S.GameSaysQuest = GameSaysQuest

--------------------------------------------------------------------------------
-- Baús
--------------------------------------------------------------------------------

local chestWords
local gatheredIDs = {} -- números de veios/ervas vistos nesta sessão (não viram baú)

function S.ContainerMatch(id, name)
    if id and ns.db.containers[id] then return L.MATCH_LOOT end
    if type(name) ~= "string" then return nil end
    if not chestWords then
        chestWords = {}
        for w in ns.ChestWords():gmatch("%S+") do chestWords[#chestWords + 1] = Fold(w) end
    end
    for w in NameKey(name):gmatch("[^%s%p]+") do
        for _, c in ipairs(chestWords) do
            if w:sub(1, #c) == c or w:sub(-#c) == c then return L.MATCH_NAME end
        end
    end
end

-- saque aberto: os objetos de onde veio passam a contar como baú
function S.LearnLootSources()
    if not (GetNumLootItems and GetLootSourceInfo) then return end
    for slot = 1, SafeCall(GetNumLootItems) or 0 do
        local id = ObjectNumber(SafeCall(GetLootSourceInfo, slot))
        if id and not BOBBER[id] and not gatheredIDs[id] then ns.db.containers[id] = true end
    end
end

--------------------------------------------------------------------------------
-- Classificação
--------------------------------------------------------------------------------

-- devolve categoria, acinzentado, cursor bruto, número do objeto
function S.Classify(unit, name)
    local hasCursor, cat, unable, raw = S.ReadCursor(unit)
    local id = S.ObjectID(unit)
    local service = cat == "service"
    if service then cat = "other" end

    if id and BOBBER[id] then
        cat = "bobber"
    elseif cat ~= "ore" and cat ~= "herb" and cat ~= "bobber" then
        local plain = cat == nil or cat == "other"
        if GameSaysQuest(unit) then
            cat = "quest"
        elseif service then
            -- caixa de correio, vendedor...: o cursor já disse o que é
        elseif plain and not id and S.Fishing() then
            cat = "bobber" -- sem número legível, apontado durante a pesca: é a boia
        elseif S.QuestMatch(name) then
            cat = "quest"
        elseif plain and S.ContainerMatch(id, name) then
            cat = "chest"
        end
    end
    if id and (cat == "ore" or cat == "herb") then gatheredIDs[id] = true end
    if not cat and (hasCursor or SafeCall(UnitIsInteractable, unit) == true) then cat = "other" end
    return cat, unable or false, raw, id
end

-- O personagem tem a profissão desta categoria? true / false / nil (não sei ainda).
local GATHER = {
    herb = { line = 182, spells = { 2383, 8387 } },
    ore = { line = 186, spells = { 2580, 8388 } },
}

function S.Trained(cat)
    local g = GATHER[cat]
    if not g then return nil end
    local answered = false
    local known = (C_SpellBook and C_SpellBook.IsSpellKnown) or IsPlayerSpell
    if known then
        for _, spell in ipairs(g.spells) do
            local r = SafeCall(known, spell)
            if r == true then return true end
            if r == false then answered = true end
        end
    end
    local SI = C_SkillInfo
    if SI and SI.GetSkillLineInfoByID then
        if (SafeCall(SI.GetNumSkillLines) or 0) == 0 then return nil end
        local ok, info = pcall(SI.GetSkillLineInfoByID, g.line)
        if not ok or IsSecret(info) then return nil end
        if type(info) == "table" then
            local top = info.maxRank
            if IsSecret(top) or type(top) ~= "number" or top > 0 then return true end
        end
        answered = true
    end
    if answered then return false end
    return nil
end

-- "far" longe / "ready" ao alcance / "locked" ao alcance mas recusado
function S.State(unit, unable)
    local near = UnitIsInInteractRange and SafeCall(UnitIsInInteractRange, unit)
    if near == false then return "far", near end
    if unable then return near == true and "locked" or "far", near end
    return "ready", near
end

--------------------------------------------------------------------------------
-- Alvo e placa
--------------------------------------------------------------------------------

local plates = {}      -- token nameplateN -> true (placas visíveis)
local directOK = false -- o token "softinteract" já deu a placa de um objeto?

function S.PlateAdded(unit) plates[unit] = true end
function S.PlateRemoved(unit) plates[unit] = nil end
function S.DirectWorks() return directOK end

local function PlateOf(unit)
    return C_NamePlate and SafeCall(C_NamePlate.GetNamePlateForUnit, unit)
end
S.PlateOf = PlateOf

-- existe alvo de interação? true / false / nil (o jogo não diz)
local function TargetExists()
    local u, o = SafeCall(UnitExists, SOFT), SafeCall(UnitIsGameObject, SOFT)
    if u == true or o == true then return true end
    if u == false and o == false then return false end
end

-- Devolve unidade, placa, caminho (diagnóstico) e, sem unidade, se foi por não saber.
function S.Target()
    local exists = TargetExists()
    if exists == false then return nil end
    local plate = PlateOf(SOFT)
    if plate then
        if not directOK and SafeCall(UnitIsGameObject, SOFT) == true then directOK = true end
        return SOFT, plate, L.VIA_DIRECT
    end
    if not directOK then
        -- clientes em que o token não dá a placa: procura entre as placas visíveis
        for unit in pairs(plates) do
            if SafeCall(UnitIsGameObject, unit) == true or SafeCall(UnitIsUnit, unit, SOFT) == true then
                local p = PlateOf(unit)
                if p then return unit, p, L.VIA_SWEEP end
            end
        end
    end
    if exists then return SOFT, nil, L.VIA_DIRECT end
    return nil, nil, nil, true
end

-- nome para a lista de ignorados: "" sem nome, nil se ilegível
function S.NameOf(unit)
    local ok, n = pcall(UnitName, unit)
    if not ok or IsSecret(n) then return nil end
    if type(n) ~= "string" or NameKey(n) == "" then return "" end
    return n
end

-- nome do objeto do cenário mirado agora (iluminado ou não)
function S.TargetObjectName()
    local unit = S.Target()
    if unit and SafeCall(UnitIsGameObject, unit) == true then return S.NameOf(unit) end
end
