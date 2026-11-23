--[[----------------------------------------------------------------------------
    AzaathUI - Olho de Azaath / Base.lua
    Utilidades, ajustes salvos (AzaathUIDB.olho) e a API de opções que os outros
    arquivos do Olho usam. Nada aqui desenha ou lê o mundo.

    Ajustes:
      * da conta (db): aparência, cores, listas aprendidas, ignorados;
      * do personagem (db.chars[nome-reino] = cdb): categorias mostradas, recorte
        do corpo e a alternância de rastreamento;
      * "aparência" (APPEARANCE) vale para todos os objetos, mas uma categoria pode
        ter a sua em db.categorySettings[categoria].
------------------------------------------------------------------------------]]

local _, Azaath = ...
local ns = Azaath.OlhoNS
local L = ns.L

local M = Azaath:NewModule("OlhoAzaath")
ns.M = M

local pairs, ipairs, type, pcall, tostring, tonumber = pairs, ipairs, type, pcall, tostring, tonumber
local floor, min, max = math.floor, math.min, math.max

local SCHEMA = 12

--------------------------------------------------------------------------------
-- Utilidades
--------------------------------------------------------------------------------

local function IsSecret(v)
    return issecretvalue ~= nil and issecretvalue(v) or false
end

-- chama protegido; um resultado secreto conta como "não sei"
local function SafeCall(fn, ...)
    if not fn then return nil end
    local ok, r = pcall(fn, ...)
    if ok and not IsSecret(r) then return r end
end

local function Clamp(v, lo, hi)
    return v < lo and lo or (v > hi and hi or v)
end

local function Print(text)
    print(L.PREFIX .. text)
end

local function Flag(v)
    if v == nil then return "?" end
    return v and L.YES or L.NO
end

-- Minúsculas sem acento. string.lower só entende ASCII, então as letras acentuadas
-- latinas e o cirílico (UTF-8 de dois bytes) passam por uma tabela.
local FOLD = {}
do
    local pairsList = {
        "àa", "áa", "âa", "ãa", "äa", "çc", "èe", "ée", "êe", "ëe", "ìi", "íi", "îi", "ïi",
        "ñn", "òo", "óo", "ôo", "õo", "öo", "ùu", "úu", "ûu", "üu",
        "Àa", "Áa", "Âa", "Ãa", "Äa", "Çc", "Èe", "Ée", "Êe", "Ëe", "Ìi", "Íi", "Îi", "Ïi",
        "Ñn", "Òo", "Óo", "Ôo", "Õo", "Öo", "Ùu", "Úu", "Ûu", "Üu",
    }
    for _, p in ipairs(pairsList) do FOLD[p:sub(1, 2)] = p:sub(3) end
    FOLD["ß"] = "ss"
    -- cirílico maiúsculo: А..П (D0 90..9F) -> а..п (D0 B0..BF); Р..Я (D0 A0..AF) -> р..я (D1 80..8F)
    for b = 0x90, 0xAF do
        local up = "\208" .. string.char(b)
        FOLD[up] = b < 0xA0 and ("\208" .. string.char(b + 0x20)) or ("\209" .. string.char(b - 0x20))
    end
    FOLD["\208\129"] = "\208\181" -- Ё -> е
    FOLD["\209\145"] = "\208\181" -- ё -> е
end

local function Fold(s)
    return (s:gsub("[\195-\197\208\209][\128-\191]", FOLD):lower())
end

-- chave de um nome de objeto (lista de ignorados): sem acento, sem espaço nas pontas
local function NameKey(name)
    name = name:gsub("\194\160", " "):gsub("\226\128\153", "'")
    return (Fold(name):match("^%s*(.-)%s*$"))
end

ns.IsSecret, ns.SafeCall, ns.Clamp, ns.Print, ns.Flag = IsSecret, SafeCall, Clamp, Print, Flag
ns.Fold, ns.NameKey = Fold, NameKey

--------------------------------------------------------------------------------
-- Ajustes
--------------------------------------------------------------------------------

ns.CATEGORY_ORDER = { "ore", "herb", "quest", "chest", "bobber", "other" }

local ACCOUNT = {
    enabled = true,
    range = 15, arc = 2,
    effect = "aura", size = 120, intensity = 100, offsetY = -45,
    followAlpha = false, silhouette = true,
    showName = true, showIcon = true, textSize = 100, textFont = "game",
    exclusive = true, glowOnly = false,
    nativeSparkle = true, -- purpurina do próprio jogo em itens de missão (vários ao mesmo tempo)
    hideInCombat = false, hideInInstance = false, hideLocked = false, hideUntrained = true,
    debug = false, language = "auto",
    colors = {
        ore = { 1.00, 0.60, 0.18 }, herb = { 0.40, 1.00, 0.42 }, quest = { 1.00, 0.84, 0.15 },
        chest = { 0.45, 0.78, 1.00 }, bobber = { 1.00, 0.45, 0.40 }, other = { 0.90, 0.90, 0.94 },
    },
    categorySettings = {},
    questObjects = {}, -- nome do objeto -> título da missão, aprendido da dica
    ignored = {},      -- chave do nome -> nome mostrado ("" = objetos sem nome)
    containers = {},   -- número do objeto -> true: já revistado, conta como baú
    minimap = { hide = false, angle = 205 },
}

local CHARACTER = {
    categories = { ore = true, herb = true, quest = true, chest = true, bobber = true, other = false },
    bodyScale = 100, bodyShift = 0,
    nodeSwitch = false, nodeSwitchYards = 15,
}

-- ajustes de aparência: valem por categoria quando ela tem os seus
local APPEARANCE = {
    effect = true, size = true, intensity = true, offsetY = true, followAlpha = true,
    showName = true, showIcon = true, textSize = true, textFont = true, silhouette = true,
}

local LIMITS = {
    range = { 5, 15 }, arc = { 0, 2 },
    size = { 40, 300 }, intensity = { 30, 150 }, offsetY = { -200, 200 }, textSize = { 60, 200 },
    bodyScale = { 40, 300 }, bodyShift = { -100, 100 },
    nodeSwitchYards = { 10, 50 },
}
ns.LIMITS = LIMITS
ns.ACCOUNT_DEFAULTS, ns.CHARACTER_DEFAULTS = ACCOUNT, CHARACTER

-- o que "Redefinir" não toca: não são ajustes do brilho
local KEEP_ON_RESET = {
    enabled = true, language = true, minimap = true, questObjects = true, ignored = true, containers = true,
}

local function Fill(dst, src)
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            Fill(dst[k], v)
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
end

local db, cdb

local function Owner(key)
    if CHARACTER[key] ~= nil then return cdb end
    return db
end

-- saneia um valor de ajuste; devolve nil se não servir
local function Sane(key, v)
    local default = ACCOUNT[key]
    if default == nil then default = CHARACTER[key] end
    if default == nil or type(v) ~= type(default) then return nil end
    if type(v) == "number" then
        local lim = LIMITS[key]
        if lim then v = Clamp(v, lim[1], lim[2]) + 0 end -- "+0" desfaz o -0 relido do arquivo
    elseif key == "effect" then
        if not ns.EFFECTS[v] or v == "fallback" then return nil end
    elseif key == "textFont" then
        if not ns.IsFont(v) then return nil end
    end
    return v
end

local DEAD_KEYS = {
    -- ícones no minimapa (retirados em 21/11/2026) e protótipos antigos
    "nodeHerbs", "nodeOre", "nodeSize", "nodeRing", "nodeCombat", "nodeScanYards", "nodeNames", "nodesOffNotice",
    "farGlow", "farDrop", "farRestore", "farPins", "farSecretError", "coordProbe",
    "style", "categories", "showOther", "bodyScale", "bodyShift", "categoryEffects", "showLabel", "inherited",
}

local function Migrate()
    if db.schema == SCHEMA then return end
    for _, k in ipairs(DEAD_KEYS) do db[k] = nil end
    if type(db.categorySettings) == "table" then
        for _, own in pairs(db.categorySettings) do
            if type(own) == "table" then own.showLabel = nil end
        end
    end
    db.schema = SCHEMA
end

local function Sanitize()
    for key in pairs(ACCOUNT) do
        if type(ACCOUNT[key]) ~= "table" then
            local v = Sane(key, db[key])
            if v == nil then db[key] = ACCOUNT[key] else db[key] = v end
        end
    end
    for key in pairs(CHARACTER) do
        if type(CHARACTER[key]) ~= "table" then
            local v = Sane(key, cdb[key])
            if v == nil then cdb[key] = CHARACTER[key] else cdb[key] = v end
        end
    end
    for cat, default in pairs(ACCOUNT.colors) do
        local c = db.colors[cat]
        for i = 1, 3 do
            c[i] = type(c[i]) == "number" and Clamp(c[i], 0, 1) or default[i]
        end
    end
    for cat, own in pairs(db.categorySettings) do
        if type(own) ~= "table" or not ACCOUNT.colors[cat] then
            db.categorySettings[cat] = nil
        else
            for key, v in pairs(own) do
                own[key] = APPEARANCE[key] and Sane(key, v) or nil
            end
            if next(own) == nil then db.categorySettings[cat] = nil end
        end
    end
    if not ns.LOCALES[db.language] and db.language ~= "auto" then db.language = "auto" end
    -- a chave dos ignorados é refeita: a regra de remover acentos pode ter mudado
    local ignored = {}
    for _, shown in pairs(db.ignored) do
        if type(shown) == "string" then ignored[shown == "" and "" or NameKey(shown)] = shown end
    end
    db.ignored = ignored
end

function ns.LoadSettings()
    AzaathUIDB = AzaathUIDB or {}
    AzaathUIDB.olho = type(AzaathUIDB.olho) == "table" and AzaathUIDB.olho or {}
    db = AzaathUIDB.olho
    Migrate()
    Fill(db, ACCOUNT)
    db.chars = type(db.chars) == "table" and db.chars or {}
    local who = (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
    db.chars[who] = type(db.chars[who]) == "table" and db.chars[who] or {}
    cdb = db.chars[who]
    Fill(cdb, CHARACTER)
    Sanitize()
    ns.db, ns.cdb = db, cdb
    return db, cdb
end

--------------------------------------------------------------------------------
-- API de opções
--------------------------------------------------------------------------------

local reactions = {} -- ajuste -> { funções chamadas quando ele muda }

-- registra uma reação a um ajuste (os outros arquivos do Olho chamam isto ao carregar)
function ns.OnOption(key, fn)
    local list = reactions[key]
    if not list then list = {}; reactions[key] = list end
    list[#list + 1] = fn
end

local function React(key)
    local list = reactions[key]
    if list then for _, fn in ipairs(list) do fn(key) end end
    local any = reactions["*"]
    if any then for _, fn in ipairs(any) do fn(key) end end
end

-- avisa a janela de ajustes (se existir) que algo mudou
local function Notify()
    if ns.Refresh then ns.Refresh() end
end
ns.Notify = Notify

-- valor de aparência para uma categoria (o dela, senão o geral)
function ns.Look(category, key)
    local own = category and db.categorySettings[category]
    if own and own[key] ~= nil then return own[key] end
    return db[key]
end

function ns.GetOption(key, category)
    if APPEARANCE[key] then return ns.Look(category, key) end
    return Owner(key)[key]
end

-- Muda um ajuste. Um ajuste de aparência com categoria vira próprio dela; sem
-- categoria vale para todos e tira o próprio das categorias que o tinham.
function ns.SetOption(key, value, category)
    local lim = LIMITS[key]
    if lim and type(value) == "number" then value = Clamp(floor(value + 0.5), lim[1], lim[2]) end
    if APPEARANCE[key] and category then
        local own = db.categorySettings[category] or {}
        if value == db[key] then own[key] = nil else own[key] = value end
        db.categorySettings[category] = next(own) and own or nil
    elseif APPEARANCE[key] then
        db[key] = value
        for cat, own in pairs(db.categorySettings) do
            own[key] = nil
            if not next(own) then db.categorySettings[cat] = nil end
        end
    else
        Owner(key)[key] = value
    end
    React(key)
    Notify()
end

function ns.HasOwnSettings(category)
    return db.categorySettings[category] ~= nil
end

function ns.ClearOwnSettings(category)
    db.categorySettings[category] = nil
    React("appearance")
    Notify()
end

function ns.IsCategoryShown(category)
    return cdb.categories[category] == true
end

function ns.SetCategory(category, shown)
    cdb.categories[category] = shown and true or false
    React("categories")
    Notify()
end

function ns.GetColor(category)
    local c = db.colors[category] or db.colors.other
    return c[1], c[2], c[3]
end

-- sem r, g, b: volta à cor original
function ns.SetColor(category, r, g, b)
    local c, d = db.colors[category], ACCOUNT.colors[category]
    if not c then return end
    c[1] = Clamp(r or d[1], 0, 1)
    c[2] = Clamp(g or d[2], 0, 1)
    c[3] = Clamp(b or d[3], 0, 1)
    React("color")
    Notify()
end

-- nome de objeto ignorado ou não; devolve o novo estado (nil se o nome não servir)
function ns.ToggleIgnored(name, unnamed)
    local key = unnamed and "" or (type(name) == "string" and NameKey(name) or "")
    if key == "" and not unnamed then return nil end
    if db.ignored[key] then
        db.ignored[key] = nil
    else
        db.ignored[key] = unnamed and "" or name
    end
    React("ignored")
    Notify()
    return db.ignored[key] ~= nil
end

function ns.IsIgnored(name)
    return name ~= nil and db.ignored[NameKey(name)] ~= nil
end

function ns.ClearIgnored()
    for k in pairs(db.ignored) do db.ignored[k] = nil end
    React("ignored")
    Notify()
end

function ns.IgnoredNames()
    local out = {}
    for _, n in pairs(db.ignored) do out[#out + 1] = (n == "" and L.NAME_UNNAMED) or n end
    table.sort(out)
    return out
end

local function Reset(store, defaults)
    for k, v in pairs(defaults) do
        if not KEEP_ON_RESET[k] then
            if type(v) == "table" then
                store[k] = {}
                Fill(store[k], v)
            else
                store[k] = v
            end
        end
    end
end

function ns.ResetOptions()
    Reset(db, ACCOUNT)
    Reset(cdb, CHARACTER)
    React("reset")
    Notify()
end

function ns.Toggle(on)
    ns.SetOption("enabled", on and true or false)
    Print(on and L.MSG_ENABLED or L.MSG_DISABLED)
end

-- troca {chave} pelos limites e {chave=} pelo valor padrão (textos de ajuda)
function ns.FillLimits(text)
    return (text:gsub("{(%w+)(=?)}", function(key, eq)
        if eq == "=" then
            local d = ACCOUNT[key]
            if d == nil then d = CHARACTER[key] end
            return tostring(d)
        end
        local lim = LIMITS[key]
        return lim and (lim[1] .. ".." .. lim[2]) or key
    end))
end
