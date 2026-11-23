--[[----------------------------------------------------------------------------
    AzaathUI - Olho de Azaath / Locales/Locales.lua
    Cria o espaço do Olho (Azaath.OlhoNS) e a tabela de textos L, que entrega
    o idioma escolhido (ou o do cliente) e cai para o inglês quando falta algo.
    Também guarda dados que dependem do idioma do CLIENTE (não do exibido):
    palavras comuns demais para ligar objeto a missão, palavras de baú e fontes.
------------------------------------------------------------------------------]]

local _, Azaath = ...
Azaath.OlhoNS = Azaath.OlhoNS or {}
local ns = Azaath.OlhoNS
ns.MEDIA = "Interface\\AddOns\\AzaathUI\\Media\\OlhoAzaath\\"

local LOCALES = {}
ns.LOCALES = LOCALES

local ALIAS = { enGB = "enUS", ptPT = "ptBR" }
local function Client()
    local code = GetLocale()
    return ALIAS[code] or code
end

local picked -- textos do idioma escolhido; nil = o do cliente

ns.L = setmetatable({}, {
    __index = function(_, key)
        local own = picked or LOCALES[Client()] or LOCALES.enUS
        local v = own[key]
        if v == nil then v = LOCALES.enUS and LOCALES.enUS[key] end
        if v == nil then return key end
        return v
    end,
})

-- "auto" ou código desconhecido: segue o cliente
function ns.UseLanguage(code)
    picked = LOCALES[code]
end

-- adjetivos que, sozinhos, não provam que um objeto é de uma missão
local COMMON = {
    enUS = "small little large big great giant old ancient",
    ptBR = "pequeno pequena pequenos pequenas grande grandes velho velha velhos velhas antigo antiga antigos antigas",
    esES = "pequeño pequeña grande grandes viejo vieja antiguo antigua",
    frFR = "petit petite grand grande vieux vieille ancien ancienne",
    deDE = "klein kleine kleiner groß große großer alt alte alter uralt",
}
function ns.CommonWords() return COMMON[Client()] or COMMON.enUS end

-- como um baú costuma se chamar (o jogo não dá cursor próprio a baús)
local CHEST = {
    enUS = "chest coffer strongbox lockbox footlocker",
    ptBR = "baú cofre arca",
    esES = "cofre arcón baúl",
    frFR = "coffre malle",
    deDE = "truhe kassette",
}
function ns.ChestWords() return CHEST[Client()] or CHEST.enUS end

-- fontes para o nome escrito sobre o objeto ("game" = a do jogo)
local FONTS = {
    { key = "game" },
    { key = "arial", name = "Arial Narrow", latin = "Fonts\\ARIALN.TTF", cyrillic = "Fonts\\ARIALN.TTF" },
    { key = "morpheus", name = "Morpheus", latin = "Fonts\\MORPHEUS.ttf", cyrillic = "Fonts\\MORPHEUS_CYR.TTF" },
    { key = "skurri", name = "Skurri", latin = "Fonts\\skurri.ttf", cyrillic = "Fonts\\SKURRI_CYR.TTF" },
}
local BY_KEY = {}
for _, f in ipairs(FONTS) do BY_KEY[f.key] = f end
-- alfabeto do cliente: false = nenhuma fonte extra escreve esse idioma
local SCRIPT = { ruRU = "cyrillic", koKR = false, zhCN = false, zhTW = false }

function ns.IsFont(key) return BY_KEY[key] ~= nil end

function ns.FontFile(key)
    local f = BY_KEY[key]
    if not f or key == "game" then return nil end
    local script = SCRIPT[GetLocale()]
    if script == nil then script = "latin" end
    return script and f[script] or nil
end

function ns.FontChoices()
    local out = {}
    for _, f in ipairs(FONTS) do
        if f.key == "game" or ns.FontFile(f.key) then out[#out + 1] = f.key end
    end
    return out
end

function ns.FontName(key)
    local f = BY_KEY[key]
    return f and f.name
end
