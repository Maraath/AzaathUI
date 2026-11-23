--[[----------------------------------------------------------------------------
    AzaathUI - Modules/CombatText.lua
    Dano flutuante (Floating Combat Text) no autêntico estilo Azaath.

    Características:
      * Fonte oficial de títulos e números do Azaath: IM Fell DW Pica.
      * Dano Normal (como o "65" na captura de referência):
        - Número em branco puro e nítido (#FFFFFF).
        - Ícone do tipo de dano ao lado (corte / Slash, perfuração / Thrust, etc.)
          na mesma cor branca.
      * Dano Crítico (como o "84" na captura de referência):
        - Número em tamanho ampliado e imponente.
        - Cor laranja vibrante Azaath (#FA7A14).
        - Ícone do tipo de dano tingido no mesmo laranja do crítico.
        - Pop de impacto com escala elástica acentuada.
      * Compatibilidade Universal de Eventos:
        - Suporta UNIT_COMBAT, COMBAT_TEXT_UPDATE e COMBAT_LOG_EVENT_UNFILTERED
          garantindo funcionamento perfeito no motor 12.x / Forever e no 3.3.5a.
      * Animação Azaath:
        - Impacto com expansão rápida ("pop") e retorno elástico ao tamanho base.
        - Flutuação ascendente suave com desaceleração quadrática (ease-out).
        - Alta legibilidade com atraso no esmaecimento (fade-out no final da vida).
      * Ancoragem 3D inteligente:
        - Vincula à placa de nome (Nameplate) do inimigo quando disponível,
          flutuando sobre o tronco/peito do alvo e acompanhando o movimento 3D.
        - Se o alvo não possuir placa visível, ancora acima do alvo ou centro da tela.
        - Variação randômica leve (jitter) para evitar sobreposição em golpes rápidos.
      * Desativa o texto flutuante nativo da Blizzard para evitar sobreposição.
      * Pool de frames pré-alocados para consumo zero de memória e alta taxa de FPS.
------------------------------------------------------------------------------]]

local ADDON_NAME, Azaath = ...
local M = Azaath:NewModule("CombatText")

local _G = _G
local pairs, ipairs, pcall, tostring, tonumber, type = pairs, ipairs, pcall, tostring, tonumber, type
local max, min, floor, random = math.max, math.min, math.floor, math.random
local GetTime = GetTime
local UnitGUID, UnitExists, UnitIsUnit = UnitGUID, UnitExists, UnitIsUnit
local UnitCanAttack, UnitReaction = UnitCanAttack, UnitReaction
local CreateFrame, UIParent = CreateFrame, UIParent

local cfg
local MEDIA_COMBAT = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\CombatText\\"

-- Paleta de cores oficial Azaath
local COLOR_NORMAL = { 1.00, 1.00, 1.00 } -- Branco puro (#FFFFFF)
local COLOR_CRIT   = { 0.98, 0.48, 0.08 } -- Laranja vibrante (#FA7A14)
local COLOR_DOT    = { 0.90, 0.88, 0.82 } -- Branco pergaminho suave para DoTs
local COLOR_PET    = { 0.85, 0.88, 0.96 } -- Branco azulado suave para dano do ajudante
local COLOR_MISS   = { 0.72, 0.72, 0.75 } -- Cinza claro para Esquiva / Apara / Erro

-- Mapeamento dos ícones de dano
local ICONS = {
    slash     = MEDIA_COMBAT .. "Slash.tga",
    thrust    = MEDIA_COMBAT .. "Thrust.tga",
    strike    = MEDIA_COMBAT .. "Strike.tga",
    bleed     = MEDIA_COMBAT .. "Bleed.tga",
    fire      = MEDIA_COMBAT .. "Fire.tga",
    frost     = MEDIA_COMBAT .. "Frost.tga",
    nature    = MEDIA_COMBAT .. "Nature.tga",
    lightning = MEDIA_COMBAT .. "Lightning.tga",
    holy      = MEDIA_COMBAT .. "Holy.tga",
    shadow    = MEDIA_COMBAT .. "Shadow.tga",
    arcane    = MEDIA_COMBAT .. "Arcane.tga",
    frostfire = MEDIA_COMBAT .. "Frostfire.tga",
    chaos     = MEDIA_COMBAT .. "Chaos.tga",
}

-- Ícones que possuem paleta própria gravada na textura (mágicos + sangramento).
-- Ícones físicos (slash, thrust, strike) recebem SetVertexColor branco/laranja.
local COLORED_ICONS = {
    [ICONS.bleed]     = true,
    [ICONS.fire]      = true,
    [ICONS.frost]     = true,
    [ICONS.nature]    = true,
    [ICONS.lightning] = true,
    [ICONS.holy]      = true,
    [ICONS.shadow]    = true,
    [ICONS.arcane]    = true,
    [ICONS.frostfire] = true,
    [ICONS.chaos]     = true,
}

-- Mapeamento de escolas de magia do WoW (bitmask) para os ícones Azaath
-- 1: Físico, 2: Sagrado, 4: Fogo, 8: Natureza, 16: Gelo, 20: Fogo-Gelo, 32: Sombra, 64: Arcano
local SCHOOL_ICONS = {
    [1]  = ICONS.slash,
    [2]  = ICONS.holy,
    [4]  = ICONS.fire,
    [8]  = ICONS.nature,
    [16] = ICONS.frost,
    [20] = ICONS.frostfire,
    [32] = ICONS.shadow,
    [64] = ICONS.arcane,
}

-- Textos localizados para falhas / defesas
local MISS_TEXTS = {
    ["ABSORB"]  = "Absorvido",
    ["BLOCK"]   = "Bloqueado",
    ["DEFLECT"] = "Desviado",
    ["DODGE"]   = "Esquiva",
    ["EVADE"]   = "Evadiu",
    ["IMMUNE"]  = "Imune",
    ["MISS"]    = "Errou",
    ["PARRY"]   = "Aparado",
    ["REFLECT"] = "Refletido",
    ["RESIST"]  = "Resistido",
}

--------------------------------------------------------------------------------
-- Pool de Frames de Texto Flutuante
--------------------------------------------------------------------------------
local pool = {}
local active = {}
local nameplates = {} -- [guid] = plateFrame
local recentHits = {} -- [key] = timestamp (deduplicação entre eventos)

local animDriver = CreateFrame("Frame")
animDriver:Hide()

local debugMode = false
local function DebugLog(msg)
    if debugMode and _G.DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFA7A14[Azaath CombatText]|r " .. tostring(msg))
    end
end

--------------------------------------------------------------------------------
-- Buffer de Coalescência de Golpes (Resolve o problema do Golpe Heroico)
-- Quando o Golpe Heroico conecta, o servidor envia 2 pacotes no mesmo instante:
--   1º pacote: o swing básico de arma com dano 0 (pois foi convertido na magia)
--   2º pacote: o dano real do Golpe Heroico (como dano físico/magia)
-- Com este buffer de 40ms, pacotes de conversão "no próximo golpe" (Heroic Strike,
-- Cleave, Maul, Raptor Strike) substituem o swing 0 pelo dano real sem suprimir
-- outros ataques básicos ou habilidades instantâneas simultâneas.
--------------------------------------------------------------------------------
local pendingHits = {}
local pendingDriver = CreateFrame("Frame")
pendingDriver:Hide()
local pendingElapsed = 0

--------------------------------------------------------------------------------
-- Atribuição de autoria ("só o MEU dano")
-- O UNIT_COMBAT do alvo informa TODO dano que ele recebe, sem dizer quem causou;
-- o log de combate (que diria) é proibido neste cliente. Então cada golpe só é
-- mostrado se coincidir com uma ação do jogador:
--   * lançamento bem-sucedido (UNIT_SPELLCAST_SUCCEEDED) no mesmo instante, ou até
--     CAST_TTL depois APENAS para projéteis ofensivos à distância (com escola compatível);
--   * canalização ofensiva ativa (ticks do canal, com escola compatível);
--   * ataque automático / tiro automático: respeitando a cadência real (com suporte
--     a duas mãos / Dual Wield e bônus de aceleração) e, para quem usa Raiva,
--     exigindo alteração de Raiva no mesmo tick que NÃO tenha sido causada por
--     dano recebido pelo jogador.
-- Golpes sem correspondência são de aliados (ou de outros) e são descartados.
--------------------------------------------------------------------------------
local TIGHT    = 0.14  -- janela de "mesmo instante" para habilidades (s)
local CAST_TTL = 2.0   -- voo de um projétil à distância + atraso da animação do número (s)

local myCasts             = {} -- { t, isPet, harmful, isProjectile, isNextMelee, schoolMask, iconKey, used }
local myShotCasts         = {} -- { t, used } para Tiro Automático / Varinha
local seenAutoRepeatCast  = false
local autoAttacking       = false
local autoRepeating       = false
local channelUntil        = 0
local channelSchoolMask   = nil
local channelIconKey      = nil
local lastPowerTick       = -10
local lastPlayerWoundedAt = -10
-- Neste cliente o UNIT_COMBAT sai sincronizado com a animação do golpe: o ganho de
-- Raiva do swing chega 0,3-0,7 s ANTES do número. Cada ganho vira um "tick" que só
-- pode pagar um golpe (ou um dano recebido / um lançamento).
local RAGE_LEAD   = 0.85
local powerTicks  = {} -- { t, used }
local lastRageVal = nil
-- DoTs aplicados pelo jogador (Dilacerar, Ferimentos Profundos, Garrote...)
local myDots      = {} -- [chave] = { untilT, interval, lastTick, schoolMask, iconKey }
local lastUnitCombatAt    = -10
local lastSwingShown      = {} -- [slot] = instante (1 = mão principal/única, "off" = secundária, "ranged", "miss")
local spellMetaCache      = {} -- [spellID] = metadados em cache

-- Subtipo físico por arma equipada (cache atualizado fora/em combate)
local weaponKinds = { main = "slash", off = nil, ranged = "thrust" }

local band = _G.bit and _G.bit.band

local function IsSec(v) return Azaath.IsSecret and Azaath.IsSecret(v) end
local function Readable(v) return type(v) == "number" and not IsSec(v) end
local function ReadableStr(v) return type(v) == "string" and not IsSec(v) and v ~= "" and v or nil end

local NEXT_MELEE_NAMES = {
    "golpe heroico", "heroic strike",
    "fissurar", "cleave", "transpassante",
    "espancar", "maul",
    "golpe do raptor", "raptor strike",
    "golpe rúnico", "golpe runico", "rune strike",
}

local AUTO_REPEAT_IDS = {
    [75]   = true, -- Tiro Automático (Auto Shot)
    [5019] = true, -- Disparar (Varinha / Shoot)
    [3018] = true, -- Disparar (Arco/Besta/Arma de Fogo)
    [2764] = true, -- Arremessar (Throw)
}

local AUTO_REPEAT_NAMES = {
    "tiro automático", "tiro automatico", "auto shot",
    "disparar", "shoot",
}

local DESC_SCHOOL_MASKS = {
    { mask = 1,  keys = { "dano físico", "dano fisico", "physical damage" } },
    { mask = 2,  keys = { "dano sagrado", "holy damage" } },
    { mask = 4,  keys = { "dano de fogo", "fire damage", "dano ígneo", "dano igneo" } },
    { mask = 8,  keys = { "dano de natureza", "nature damage" } },
    { mask = 16, keys = { "dano de gelo", "frost damage", "dano gélido", "dano gelido" } },
    { mask = 32, keys = { "dano de sombra", "shadow damage" } },
    { mask = 64, keys = { "dano arcano", "arcane damage" } },
    { mask = 36, keys = { "chamas sombrias", "shadowflame" } },
    { mask = 20, keys = { "fogo-gelo", "frostfire" } },
    { mask = 124, keys = { "dano de caos", "dano caótico", "chaos damage", "fel damage", "dano vil" } },
}

-- Palavras-chave para distinguir subtipos específicos por habilidade (sangramento, raio, contundente, perfurante, corte, híbridos)
local SPELL_ICON_RULES = {
    { key = "frostfire", keys = { "fogo-gelo", "fogo gelo", "frostfire" } },
    { key = "chaos",     keys = { "seta do caos", "chaos bolt", "chamas sombrias", "shadowflame", "golpe vil", "fel strike" } },
    { key = "bleed",     keys = { "sangr", "bleed", "dilacerar", "rend", "ferimento profundo", "deep wounds", "garrote", "ruptura", "rupture", "rasgar", "rake", "rasgão", "rasgao", "rip", "estilhaçar", "estilhacar", "lacerate" } },
    { key = "lightning", keys = { "raio", "relâmpago", "relampago", "lightning", "trovão", "trovao", "thunder", "trovoada", "tempestade", "storm", "tufão", "tufao", "typhoon", "fúria dos ventos", "windfury" } },
    { key = "strike",    keys = { "escudada", "shield slam", "pancada", "shield bash", "onda de choque", "shockwave", "atordoar", "concussion", "esmagar", "crush", "pisão", "pisao", "stomp", "chute", "kick", "esmurrar", "pummel", "espancar", "maul", "martelo da justiça", "hammer of" } },
    { key = "thrust",    keys = { "tiro", "shot", "picada", "sting", "punhalada", "backstab", "emboscada", "ambush", "mutilar", "mutilate", "estocada", "perfur", "pierc", "saraivada", "volley", "arremess", "throw", "disparo", "aimed" } },
    { key = "slash",     keys = { "retalhar", "shred", "patada", "swipe", "garra", "claw", "mutilação feroz", "ferocious bite", "fissurar", "cleave" } },
}

local WEAPON_SUBCLASS_KIND = {
    [0]  = "slash",  -- Machado 1M
    [1]  = "slash",  -- Machado 2M
    [2]  = "thrust", -- Arco
    [3]  = "thrust", -- Arma de fogo
    [4]  = "strike", -- Maça 1M
    [5]  = "strike", -- Maça 2M
    [6]  = "slash",  -- Arma de haste (Polearm)
    [7]  = "slash",  -- Espada 1M
    [8]  = "slash",  -- Espada 2M
    [10] = "strike", -- Cajado
    [13] = "strike", -- Arma de punho
    [14] = "strike", -- Diversas
    [15] = "thrust", -- Adaga
    [16] = "thrust", -- Arremesso
    [18] = "thrust", -- Besta
    [19] = "arcane", -- Varinha (fallback)
    [20] = "strike", -- Vara de pescar
}

local function ContainsAny(haystack, list)
    for _, k in ipairs(list) do
        if haystack:find(k, 1, true) then return true end
    end
    return false
end

local function DetectWeaponSlotKind(slot)
    local itemRef = (_G.GetInventoryItemID and GetInventoryItemID("player", slot))
        or (_G.GetInventoryItemLink and GetInventoryItemLink("player", slot))
    if not itemRef or IsSec(itemRef) then return nil end

    if Azaath.API and Azaath.API.GetItemInfoInstant then
        local ok, _, itemType, subType, _, _, classID, subclassID = pcall(Azaath.API.GetItemInfoInstant, itemRef)
        if ok then
            if Readable(classID) and Readable(subclassID) then
                if classID == 2 then
                    return WEAPON_SUBCLASS_KIND[subclassID] or "slash"
                elseif classID == 4 and subclassID == 6 then
                    return "strike" -- Escudo
                end
            end
            local st = ReadableStr(subType)
            if st then
                local ls = st:lower()
                if ls:find("adaga", 1, true) or ls:find("dagger", 1, true)
                    or ls:find("arco", 1, true) or ls:find("bow", 1, true)
                    or ls:find("besta", 1, true) or ls:find("crossbow", 1, true)
                    or ls:find("fogo", 1, true) or ls:find("gun", 1, true)
                    or ls:find("arremess", 1, true) or ls:find("thrown", 1, true) then
                    return "thrust"
                elseif ls:find("maça", 1, true) or ls:find("maca", 1, true) or ls:find("mace", 1, true)
                    or ls:find("cajado", 1, true) or ls:find("staff", 1, true)
                    or ls:find("punho", 1, true) or ls:find("fist", 1, true)
                    or ls:find("escudo", 1, true) or ls:find("shield", 1, true) then
                    return "strike"
                elseif ls:find("espada", 1, true) or ls:find("sword", 1, true)
                    or ls:find("machado", 1, true) or ls:find("axe", 1, true)
                    or ls:find("haste", 1, true) or ls:find("polearm", 1, true) then
                    return "slash"
                end
            end
        end
    end
    return nil
end

local function RefreshWeaponKinds()
    weaponKinds.main   = DetectWeaponSlotKind(16) or "strike" -- desarmado = contundente
    weaponKinds.off    = DetectWeaponSlotKind(17)
    weaponKinds.ranged = DetectWeaponSlotKind(18) or "thrust"
end

local function GetWeaponAttackKind(isRanged, isOffHand)
    if isRanged then
        return weaponKinds.ranged or "thrust"
    end
    -- Druida em forma de Felino/Urso ataca com garras (cortante)
    local okC, _, class = pcall(UnitClass, "player")
    if okC and not IsSec(class) and class == "DRUID" and _G.GetShapeshiftForm then
        local okF, form = pcall(GetShapeshiftForm)
        if okF and Readable(form) and (form == 1 or form == 3) then
            return "slash"
        end
    end
    if isOffHand and weaponKinds.off then
        return weaponKinds.off
    end
    return weaponKinds.main or "slash"
end

local function SchoolMatches(mask, school)
    if not mask or type(school) ~= "number" then return true end
    if band then
        return band(mask, school) ~= 0
    end
    return mask == school
end

local function ResolveSchoolIcon(school, iconKey, isRanged, isOffHand)
    if type(school) == "number" then
        if school == 1 then
            if iconKey == "bleed" or iconKey == "slash" or iconKey == "thrust" or iconKey == "strike" then
                return ICONS[iconKey]
            end
            -- Trovoada / Pisão do Trovão: físico de impacto, não de lâmina
            if iconKey == "lightning" then
                return ICONS.strike
            end
            local wKind = GetWeaponAttackKind(isRanged, isOffHand)
            return ICONS[wKind] or ICONS.slash
        elseif school == 8 then
            if iconKey == "lightning" then return ICONS.lightning end
            return ICONS.nature
        elseif school == 20 then
            return ICONS.frostfire
        elseif SCHOOL_ICONS[school] then
            return SCHOOL_ICONS[school]
        elseif school > 1 then
            -- Se for Físico + 1 escola mágica (ex.: 3, 5, 9, 17, 33, 65), usa a escola mágica
            if band and band(school, 1) ~= 0 then
                local magic = school - 1
                if magic == 8 and iconKey == "lightning" then return ICONS.lightning end
                if SCHOOL_ICONS[magic] then return SCHOOL_ICONS[magic] end
            end
            return ICONS.chaos
        end
    end

    if iconKey and ICONS[iconKey] then
        return ICONS[iconKey]
    end
    local wKind = GetWeaponAttackKind(isRanged, isOffHand)
    return ICONS[wKind] or ICONS.slash
end

local function InspectSpell(spellID)
    if IsSec(spellID) or type(spellID) ~= "number" then
        return { harmful = true, isProjectile = false, isNextMelee = false, isAutoRepeat = false }
    end
    if spellMetaCache[spellID] then
        return spellMetaCache[spellID]
    end

    local name, maxRange
    if _G.C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and type(info) == "table" and not IsSec(info) then
            name = ReadableStr(info.name)
            maxRange = Readable(info.maxRange) and info.maxRange or nil
        end
    end
    if not name and _G.GetSpellInfo then
        local ok, n, _, _, _, _, rMax = pcall(GetSpellInfo, spellID)
        if ok then
            name = ReadableStr(n)
            if maxRange == nil and Readable(rMax) then maxRange = rMax end
        end
    end

    local isAutoRepeat = AUTO_REPEAT_IDS[spellID] or false
    if not isAutoRepeat and _G.C_Spell and C_Spell.IsAutoRepeatSpell then
        local ok, r = pcall(C_Spell.IsAutoRepeatSpell, spellID)
        if ok and not IsSec(r) and r then isAutoRepeat = true end
    end
    if not isAutoRepeat and name then
        local lname = name:lower()
        for _, key in ipairs(AUTO_REPEAT_NAMES) do
            if lname == key then isAutoRepeat = true; break end
        end
    end

    local isNextMelee = false
    if name then
        local lname = name:lower()
        for _, key in ipairs(NEXT_MELEE_NAMES) do
            if lname:find(key, 1, true) then isNextMelee = true; break end
        end
    end

    -- Verifica se o feitiço é benéfico (buff/cura) ou ofensivo
    local helpful = false
    if _G.C_Spell and C_Spell.IsSpellHelpful then
        local ok, r = pcall(C_Spell.IsSpellHelpful, spellID)
        if ok and not IsSec(r) and r then helpful = true end
    elseif _G.IsHelpfulSpell and name then
        local ok, r = pcall(IsHelpfulSpell, name)
        if ok and not IsSec(r) and r then helpful = true end
    end

    local harmfulExplicit
    if _G.C_Spell and C_Spell.IsSpellHarmful then
        local ok, r = pcall(C_Spell.IsSpellHarmful, spellID)
        if ok and not IsSec(r) and r ~= nil then harmfulExplicit = (r and true or false) end
    elseif _G.IsHarmfulSpell and name then
        local ok, r = pcall(IsHarmfulSpell, name)
        if ok and not IsSec(r) and r ~= nil then harmfulExplicit = (r and true or false) end
    end

    local harmful = true
    if harmfulExplicit ~= nil then
        harmful = harmfulExplicit
    elseif helpful then
        harmful = false
    end

    -- Descrição para saber se causa dano direto, escola e subtipo de ícone
    local desc
    local descFn = (_G.C_Spell and C_Spell.GetSpellDescription) or _G.GetSpellDescription
    if descFn then
        local okD, d = pcall(descFn, spellID)
        if okD then desc = ReadableStr(d) end
    end

    local schoolMask
    local hasDamageWord = false
    local ldesc = desc and desc:lower() or ""
    if desc then
        if ldesc:find("dano", 1, true) or ldesc:find("damage", 1, true) then
            hasDamageWord = true
        end
        for _, entry in ipairs(DESC_SCHOOL_MASKS) do
            if ContainsAny(ldesc, entry.keys) then
                schoolMask = (schoolMask or 0) + entry.mask
            end
        end
    end

    local iconKey
    local searchBlob = ((name and name:lower() or "") .. " " .. ldesc)
    for _, rule in ipairs(SPELL_ICON_RULES) do
        if ContainsAny(searchBlob, rule.keys) then
            iconKey = rule.key
            break
        end
    end

    -- Só permite janela de projétil (CAST_TTL) se for ofensivo, de longo alcance (> 8m)
    -- e causar dano (evita que gritos, buffs, provocações ou golpes corpo a corpo
    -- deixem um token aberto por >1s para aliados consumirem).
    local isProjectile = false
    if harmful and not isNextMelee and not isAutoRepeat then
        if maxRange and maxRange > 8 then
            local lname = name and name:lower() or ""
            local isThrowLike = ContainsAny(lname, { "arremess", "throw", "faca", "knife", "adaga", "dagger", "disparo", "tiro", "shot", "flecha", "arrow" })
            if desc == nil or hasDamageWord or isThrowLike then
                isProjectile = true
            end
        end
    end

    -- Dano periódico: "ao longo de 15 s", "durante 21 s", "over 15 sec", "a cada 3 s"
    local dotDuration
    if harmful and hasDamageWord and not isAutoRepeat then
        local periodic = iconKey == "bleed"
            or ContainsAny(ldesc, { "ao longo de", "a cada", "por segundo", "over ", "every ", "per second", "periodic" })
        if periodic then
            local secs = ldesc:match("ao longo de%s+(%d+[,.]?%d*)%s*s")
                or ldesc:match("durante%s+(%d+[,.]?%d*)%s*s")
                or ldesc:match("over%s+(%d+[,.]?%d*)%s*sec")
                or ldesc:match("por%s+(%d+[,.]?%d*)%s*s")
            dotDuration = secs and tonumber((secs:gsub(",", "."))) or 21
        end
    end

    local meta = {
        dotDuration  = dotDuration,
        harmful      = harmful,
        isAutoRepeat = isAutoRepeat,
        isNextMelee  = isNextMelee,
        isProjectile = isProjectile,
        schoolMask   = schoolMask,
        iconKey      = iconKey,
    }
    if name then
        spellMetaCache[spellID] = meta
    end
    return meta
end

local function RecordMyCast(spellID, isPet)
    local now = GetTime()
    local meta = InspectSpell(spellID)
    if not meta.harmful then return end

    if (not isPet) and meta.isAutoRepeat then
        seenAutoRepeatCast = true
        myShotCasts[#myShotCasts + 1] = { t = now, used = false }
        while myShotCasts[1] and (now - myShotCasts[1].t) > CAST_TTL + 0.5 do
            table.remove(myShotCasts, 1)
        end
        return
    end

    -- Gasto de Raiva do lançamento não é ganho de swing
    for _, p in ipairs(powerTicks) do
        if math.abs(p.t - now) <= 0.06 then p.used = true end
    end

    if (not isPet) and meta.dotDuration then
        myDots[spellID] = {
            untilT     = now + meta.dotDuration + 0.6,
            interval   = 2.0,
            lastTick   = now,
            schoolMask = meta.schoolMask,
            iconKey    = meta.iconKey or (((meta.schoolMask or 1) == 1) and "bleed" or nil),
        }
    end

    myCasts[#myCasts + 1] = {
        t            = now,
        isPet        = isPet and true or false,
        harmful      = true,
        isProjectile = meta.isProjectile,
        isNextMelee  = meta.isNextMelee,
        schoolMask   = meta.schoolMask,
        iconKey      = meta.iconKey,
        used         = false,
    }
    while myCasts[1] and (now - myCasts[1].t) > CAST_TTL + 0.5 do
        table.remove(myCasts, 1)
    end
end

-- (em combate o motor 12.x devolve velocidade de arma e tipo de poder como valores
-- secretos, que não podem ser comparados: guardamos a última leitura legível)
local cachedMain, cachedOff, cachedRanged = 2.0, nil, 2.0
local cachedRage

local function RefreshSpeeds()
    local ok, main, off = pcall(UnitAttackSpeed, "player")
    if ok and Readable(main) and main > 0 then
        cachedMain = main
        cachedOff = (Readable(off) and off > 0) and off or nil
    end
    if _G.UnitRangedDamage then
        local okR, speed = pcall(UnitRangedDamage, "player")
        if okR and Readable(speed) and speed > 0 then cachedRanged = speed end
    end
    local okP, pt = pcall(UnitPowerType, "player")
    if okP and Readable(pt) then
        cachedRage = (pt == 1)
    else
        local okC, _, class = pcall(UnitClass, "player")
        if okC and not IsSec(class) then
            if class == "WARRIOR" then
                cachedRage = true
            elseif class == "DRUID" then
                local okF, form = pcall(_G.GetShapeshiftForm or function() return 0 end)
                if okF and Readable(form) then
                    cachedRage = (form == 1)
                elseif cachedRage == nil then
                    cachedRage = false
                end
            elseif cachedRage == nil then
                cachedRage = false
            end
        elseif cachedRage == nil then
            cachedRage = false
        end
    end
end

local function UsesRage()
    RefreshSpeeds()
    return cachedRage and true or false
end

local function IsRageCapped()
    if not _G.UnitPower or not _G.UnitPowerMax then return false end
    local ok1, cur = pcall(UnitPower, "player", 1)
    local ok2, mx  = pcall(UnitPowerMax, "player", 1)
    if ok1 and ok2 and Readable(cur) and Readable(mx) and mx > 0 then
        return cur >= mx
    end
    return false
end

local function IsAutoAttackActive()
    if _G.IsCurrentSpell then
        local ok, on = pcall(IsCurrentSpell, 6603)
        if ok and not IsSec(on) and on then
            autoAttacking = true
        end
    end
    return autoAttacking
end

-- Consome o ganho de Raiva mais antigo ainda livre que precedeu o instante h
local function ClaimPowerTick(h)
    for _, p in ipairs(powerTicks) do
        local d = h - p.t
        if not p.used and d >= -0.06 and d <= RAGE_LEAD then
            p.used = true
            return true
        end
    end
    return false
end

local function IsRageTickForHit(h)
    return ClaimPowerTick(h)
end

-- Ferimentos Profundos (talento): sangramento de 6 s após um crítico corpo a corpo
local DEEP_WOUNDS_IDS = { 12834, 12849, 12867 }
local function KnowsDeepWounds()
    local fn = _G.IsPlayerSpell or _G.IsSpellKnown
    if not fn then return false end
    for _, id in ipairs(DEEP_WOUNDS_IDS) do
        local ok, r = pcall(fn, id)
        if ok and not IsSec(r) and r then return true end
    end
    return false
end

-- Tick de um DoT meu que já "venceu" (intervalo mínimo desde o tick anterior)
local function MatchDot(h, school)
    local best, bestKey
    for key, d in pairs(myDots) do
        if h > d.untilT then
            myDots[key] = nil
        elseif (h - d.lastTick) >= d.interval * 0.8 and SchoolMatches(d.schoolMask, school) then
            if not best or d.lastTick < best.lastTick then best, bestKey = d, key end
        end
    end
    if best then
        -- aprende a cadência real (Dilacerar 3 s, Ferimentos Profundos 1 s...)
        local gap = h - best.lastTick
        if gap >= 0.9 and gap <= 3.6 then best.interval = gap end
        best.lastTick = h
        return best
    end
    return nil
end

local function HasFreePowerTick(h)
    for _, p in ipairs(powerTicks) do
        local d = h - p.t
        if not p.used and d >= -0.06 and d <= RAGE_LEAD then return true end
    end
    return false
end

-- Decide se o golpe registrado no instante h foi causado pelo jogador (ou pet).
-- Devolve motivo ("cast", "canal", "auto", "projetil"), petFlag, nextMeleeFlag, iconKey, isOffHand, isRangedAuto.
local function IsMyHit(h, school, isMiss)
    -- 1. Lançamento no mesmo instante (golpes instantâneos / corpo a corpo)
    for _, c in ipairs(myCasts) do
        if not c.used and math.abs(c.t - h) <= TIGHT then
            if isMiss or SchoolMatches(c.schoolMask, school) then
                c.used = true
                c.matchedAt = h
                return "cast", c.isPet, c.isNextMelee, c.iconKey, false, false
            end
        end
    end

    -- 2. Canal ofensivo ativo (ou recém-terminado: o último tick chega junto do fim)
    if h <= channelUntil and (isMiss or SchoolMatches(channelSchoolMask, school)) then
        return "canal", false, false, channelIconKey, false, false
    end

    -- 3. Tick de DoT meu (sangramento, veneno, Corrupção...) já vencido
    -- (DoT não gera Raiva: com ganho de Raiva pendente, o pacote é o swing)
    if not isMiss and not (school == 1 and UsesRage() and HasFreePowerTick(h)) then
        local dot = MatchDot(h, school)
        if dot then
            return "dot", false, false, dot.iconKey, false, false
        end
    end

    -- 4a. Arremesso / tiro lançado (avulso ou automático), mesmo com o corpo a corpo ligado
    if seenAutoRepeatCast and (isMiss or school == 1 or school == "?") then
        for _, s in ipairs(myShotCasts) do
            if not s.used and h >= s.t - 0.06 and (h - s.t) <= CAST_TTL then
                s.used = true
                lastSwingShown["ranged"] = h
                if UsesRage() then ClaimPowerTick(h) end
                return "auto", false, false, nil, false, true
            end
        end
    end

    -- 4. Ataque automático / tiro automático
    local meleeOn = IsAutoAttackActive()
    if meleeOn or autoRepeating then
        if isMiss then
            local minInt = (autoRepeating and (cachedRanged * 0.65) or (cachedMain * 0.70))
            local lastPhys = max(lastSwingShown[1] or -10, lastSwingShown["miss"] or -10)
            if (h - lastPhys) >= minInt then
                lastSwingShown["miss"] = h
                return "auto", false, false, nil, false, autoRepeating
            end
        elseif autoRepeating and not meleeOn then
            if seenAutoRepeatCast then
                for _, s in ipairs(myShotCasts) do
                    if not s.used and h >= s.t and (h - s.t) <= CAST_TTL then
                        s.used = true
                        lastSwingShown["ranged"] = h
                        return "auto", false, false, nil, false, true
                    end
                end
            elseif (h - (lastSwingShown["ranged"] or -10)) >= (cachedRanged * 0.65) then
                lastSwingShown["ranged"] = h
                return "auto", false, false, nil, false, true
            end
        elseif meleeOn and (school == 1 or school == "?") then
            RefreshSpeeds()
            local rageUser = UsesRage()
            local rageOk = (not rageUser) or IsRageTickForHit(h) or IsRageCapped()
            if rageOk then
                local factor = rageUser and 0.45 or 0.55
                if (h - (lastSwingShown[1] or -10)) >= (cachedMain * factor) then
                    lastSwingShown[1] = h
                    return "auto", false, false, nil, false, false
                elseif cachedOff and (h - (lastSwingShown["off"] or -10)) >= (cachedOff * factor) then
                    lastSwingShown["off"] = h
                    return "auto", false, false, nil, true, false
                end
            end
        end
    end

    -- 4. Projétil de um lançamento ofensivo à distância recente ainda não "pago"
    for _, c in ipairs(myCasts) do
        if not c.used and c.isProjectile and c.harmful and h >= c.t and (h - c.t) <= CAST_TTL then
            if isMiss or SchoolMatches(c.schoolMask, school) then
                c.used = true
                return "projetil", c.isPet, false, c.iconKey, false, false
            end
        end
    end

    return nil, false, false, nil, false, false
end

local function FlushPendingHits()
    local textEnabled = cfg and cfg.enabled
    for _, list in pairs(pendingHits) do
        local nextMeleeMatchedAt = nil
        local nextMeleeIconKey = nil
        local nextMeleeCoalesced = false
        -- 1. Autoria de cada pacote
        for _, hitData in ipairs(list) do
            if nextMeleeMatchedAt and (not nextMeleeCoalesced) and hitData.school == 1 and math.abs(hitData.time - nextMeleeMatchedAt) <= 0.015 then
                -- Segundo pacote do mesmo Golpe Heroico / Fissurar (substitui o swing 0)
                hitData.mineReason  = "cast_coalesce"
                hitData.isNextMelee = true
                hitData.iconKey     = nextMeleeIconKey
                nextMeleeCoalesced  = true
            else
                local reason, isPet, isNextMelee, iconKey, isOffHand, isRangedAuto = IsMyHit(hitData.time, hitData.school, hitData.miss)
                hitData.mineReason   = reason
                hitData.iconKey      = iconKey
                hitData.isOffHand    = isOffHand
                hitData.isRangedAuto = isRangedAuto
                if isPet then hitData.pet = true end
                if reason == "dot" then hitData.periodic = true end
                -- Crítico corpo a corpo meu abre o sangramento de Ferimentos Profundos
                if hitData.critical and hitData.school == 1 and not isPet and not hitData.miss
                    and (reason == "auto" or reason == "cast") and not isRangedAuto and KnowsDeepWounds() then
                    myDots.deepWounds = {
                        untilT = hitData.time + 6.6, interval = 1.0, lastTick = hitData.time,
                        schoolMask = 1, iconKey = "bleed",
                    }
                end
                if reason == "cast" and isNextMelee then
                    hitData.isNextMelee = true
                    nextMeleeMatchedAt  = hitData.time
                    nextMeleeIconKey    = iconKey
                    lastSwingShown[1]   = hitData.time
                end
            end
        end
        -- 2. Efeito mágico simultâneo (proc/selo/aura de arma) dentro do mesmo lote:
        --    exige escola mágica (school > 1) diferente da do golpe principal e intervalo <= 0.05s,
        --    nunca dando carona para ataques físicos de aliados.
        for _, hitData in ipairs(list) do
            if not hitData.mineReason and type(hitData.school) == "number" and hitData.school > 1 then
                for _, other in ipairs(list) do
                    if other ~= hitData and other.mineReason
                        and (other.mineReason == "cast" or other.mineReason == "auto" or other.mineReason == "projetil")
                        and not other.pet
                        and other.school ~= hitData.school
                        and math.abs(other.time - hitData.time) <= 0.05 then
                        hitData.mineReason = "efeito"
                        break
                    end
                end
            end
            hitData.reason = hitData.mineReason or (textEnabled and cfg and cfg.onlyMine == false and "todos" or nil)
        end
        -- 3. Escolhe o que mostrar: apenas pacotes de "conversão no próximo golpe"
        --    (Golpe Heroico / Fissurar) se fundem para eliminar o pacote 0; ataques
        --    básicos e habilidades instantâneas simultâneas aparecem todos empilhados.
        local shown = {}
        local coalescedNextMelee = false
        for _, hitData in ipairs(list) do
            if hitData.reason then
                if hitData.mineReason == "cast_coalesce" and nextMeleeMatchedAt then
                    local replaced = false
                    for idx = #shown, 1, -1 do
                        if shown[idx].isNextMelee and shown[idx].school == hitData.school then
                            hitData.mineReason = "cast"
                            hitData.reason = "cast"
                            shown[idx] = hitData
                            replaced = true
                            coalescedNextMelee = true
                            break
                        end
                    end
                    if not replaced then
                        shown[#shown + 1] = hitData
                    end
                else
                    shown[#shown + 1] = hitData
                end
            end
        end
        local firedCrit, firedHit = false, false
        for i, hitData in ipairs(shown) do
            hitData.stackIndex = i - 1 -- empilha números simultâneos
            recentHits._lastTime = GetTime()
            if not hitData.miss then
                hitData.icon = ResolveSchoolIcon(hitData.school, hitData.iconKey, hitData.isRangedAuto, hitData.isOffHand)
            end
            if hitData.mineReason and not hitData.pet and hitData.mineReason ~= "dot" then
                if (not firedCrit) and (hitData.critical or hitData.isCrushing) then
                    firedCrit = true
                    firedHit = true
                    if Azaath.ActionCam and Azaath.ActionCam.OnPlayerTargetCrit then
                        Azaath.ActionCam.OnPlayerTargetCrit()
                    end
                elseif not firedHit then
                    firedHit = true
                    if Azaath.ActionCam and Azaath.ActionCam.OnPlayerTargetHit then
                        Azaath.ActionCam.OnPlayerTargetHit()
                    end
                end
            end
            if textEnabled then
                M:SpawnText(hitData)
            end
        end
        -- Diagnóstico: motivo de cada decisão no histórico salvo
        for _, hitData in ipairs(list) do
            if hitData.trace then
                hitData.trace.mine = hitData.reason or "nao"
                hitData.trace.auto = autoAttacking and "1" or "0"
                hitData.trace.dPow = string.format("%.3f", hitData.time - lastPowerTick)
                if coalescedNextMelee and hitData.mineReason == "cast" then
                    hitData.trace.mine = "cast_hs"
                end
            end
        end
    end
    wipe(pendingHits)
end

pendingDriver:SetScript("OnUpdate", function(self, elapsed)
    pendingElapsed = pendingElapsed + elapsed
    if pendingElapsed >= 0.040 then
        self:Hide()
        pendingElapsed = 0
        FlushPendingHits()
    end
end)

local function QueueHit(unitKey, hitData)
    hitData.time = GetTime()
    if hitData.school == nil then hitData.school = hitData.miss and "miss" or "?" end
    local list = pendingHits[unitKey]
    if not list then
        list = {}
        pendingHits[unitKey] = list
    end
    list[#list + 1] = hitData
    if not pendingDriver:IsShown() then
        pendingElapsed = 0
        pendingDriver:Show()
    end
end

local function IsZeroDamage(val)
    if val == nil then return true end
    if Azaath.IsSecret and Azaath.IsSecret(val) then
        return false -- valores secretos são gerenciados com segurança pelo QueueHit
    end
    local num = tonumber(val)
    return num ~= nil and num <= 0
end

local function RecordHit(amount, isCrit)
    if amount == nil then return false end
    local now = GetTime()
    if Azaath.IsSecret and Azaath.IsSecret(amount) then
        return true
    end
    local val = floor(tonumber(amount) or 0)
    if val <= 0 then return false end
    local key = tostring(val) .. ":" .. (isCrit and "1" or "0")
    if recentHits[key] and (now - recentHits[key]) < 0.08 then
        return false
    end
    recentHits[key] = now
    recentHits._lastTime = now
    return true
end

local function GetFontPath()
    if cfg and cfg.fontStyle == "ptsans" then
        return Azaath.media.fontBold or Azaath.media.font
    elseif cfg and cfg.fontStyle == "imfell_old" then
        return Azaath.media.fontTitle
    end
    -- Padrão oficial Azaath (mesma fonte dos itens e inventário): Cinzel Bold
    return Azaath.media.fontDamage or Azaath.media.fontTitleB or "Fonts\\FRIZQT__.TTF"
end

local function CreateCombatTextFrame()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetSize(220, 60)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(100)
    f:SetClampedToScreen(false)

    -- Texto do dano
    local text = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("CENTER", f, "CENTER", -12, 0)
    text:SetShadowOffset(1.5, -1.5)
    text:SetShadowColor(0, 0, 0, 0.90)

    -- Ícone do tipo de dano ao lado do número
    local icon = f:CreateTexture(nil, "OVERLAY")
    icon:SetPoint("LEFT", text, "RIGHT", 5, 0)
    icon:SetBlendMode("BLEND")

    local item = {
        frame = f,
        text  = text,
        icon  = icon,
    }
    return item
end

local function AcquireItem()
    local item = table.remove(pool)
    if not item then
        item = CreateCombatTextFrame()
    end
    active[item] = true
    animDriver:Show()
    return item
end

local function ReleaseItem(item)
    if not item then return end
    active[item] = nil
    item.frame:Hide()
    item.frame:ClearAllPoints()
    table.insert(pool, item)

    -- Se não há mais animações ativas, desliga o OnUpdate para economizar CPU
    if not next(active) then
        animDriver:Hide()
    end
end

--------------------------------------------------------------------------------
-- Motor de Animação OnUpdate (Único para todos os frames)
--------------------------------------------------------------------------------
animDriver:SetScript("OnUpdate", function(self, elapsed)
    local now = GetTime()
    for item in pairs(active) do
        local progress = (now - item.startTime) / item.duration
        if progress >= 1.0 then
            ReleaseItem(item)
        else
            -- 1. Pop elástico de escala inicial (0.0 até 0.15s)
            local scale = item.baseScale
            if progress < 0.15 then
                local t = progress / 0.15
                -- Começa maior (ex.: 1.25x normal, 1.45x crítico) e acomoda em 1.0x
                local pop = (item.startPop - 1.0) * (1 - t) * (1 - t)
                scale = scale * (1.0 + pop)
            end
            item.frame:SetScale(scale * (cfg.scale or 1))

            -- 2. Flutuação ascendente com desaceleração quadrática (ease-out)
            local easeOut = 1.0 - (1.0 - progress) * (1.0 - progress)
            local curY = item.startY + (item.floatDist * easeOut)
            local curX = item.startX + (item.driftX * progress)

            -- Mantém ancoragem segura caso o frame pai seja destruído
            local parent = item.anchorFrame
            if parent and parent.IsShown and parent:IsShown() then
                if item.usingFallback then
                    item.frame:ClearAllPoints()
                    item.usingFallback = false
                end
                item.frame:SetPoint("CENTER", parent, item.anchorPoint, curX, curY)
            else
                -- Fallback se a placa do alvo sumir durante a animação
                if not item.usingFallback then
                    item.frame:ClearAllPoints()
                    item.usingFallback = true
                end
                item.frame:SetPoint("CENTER", UIParent, "CENTER", (item.fallbackX or 0) + (item.driftX * progress), (item.fallbackY or 110) + (item.floatDist * easeOut))
            end

            -- 3. Curva de transparência (Fade):
            -- Fica 100% nítido até 65% do tempo, depois desvanece suavemente
            if progress < 0.65 then
                item.frame:SetAlpha(1.0)
            else
                local fade = (1.0 - progress) / 0.35
                item.frame:SetAlpha(max(0, min(1, fade)))
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Disparo de Dano Flutuante
--------------------------------------------------------------------------------
local function FormatDamage(amount)
    if amount == nil then return "" end
    if Azaath.IsSecret and Azaath.IsSecret(amount) then
        return amount -- repassa o secret number diretamente para o FontString
    end
    local num = tonumber(amount)
    if not num or num <= 0 then return "" end
    if num >= 1000000 then
        return string.format("%.1fM", num / 1000000)
    elseif num >= 10000 then
        return string.format("%.1fk", num / 1000)
    end
    return tostring(floor(num))
end

function M:SpawnText(opts)
    if not cfg or not cfg.enabled then return end

    local isCrit   = opts.critical or false
    local isMiss   = opts.miss or false
    local isDot    = opts.periodic or false
    local isPet    = opts.pet or false

    -- Descarta números vazios ou zero espúrio (se não for valor secreto)
    if not isMiss then
        if opts.text == nil or opts.text == "" or opts.text == "0" then
            return
        end
        if not (Azaath.IsSecret and Azaath.IsSecret(opts.text)) then
            local numVal = tonumber(opts.text)
            if numVal and numVal <= 0 then
                return
            end
        end
    end

    local item = AcquireItem()
    local f    = item.frame
    local text = item.text
    local icon = item.icon
    local fontPath = GetFontPath()

    local isSecText = Azaath.IsSecret and Azaath.IsSecret(opts.text)
    DebugLog("SpawnText isSec=" .. tostring(isSecText) .. (isSecText and "" or (" text=" .. tostring(opts.text))) .. " crit=" .. tostring(isCrit) .. " miss=" .. tostring(isMiss))

    -- 1. Tamanho e Fonte (Tamanhos ampliados estilo Azaath)
    local baseNormal = (cfg and cfg.normalSize and cfg.normalSize >= 24) and cfg.normalSize or 28
    local baseCrit   = (cfg and cfg.critSize and cfg.critSize >= 34) and cfg.critSize or 40
    local fontSize   = isCrit and baseCrit or baseNormal
    if isDot then
        fontSize = max(16, floor(fontSize * 0.85))
    end
    local ok = pcall(text.SetFont, text, fontPath, fontSize, "OUTLINE")
    local curFont = text:GetFont()
    if not ok or not curFont then
        local fallbackFont = Azaath.media.fontDamage or Azaath.media.fontTitleB or "Fonts\\FRIZQT__.TTF"
        pcall(text.SetFont, text, fallbackFont, fontSize, "OUTLINE")
    end
    if opts.text ~= nil then
        text:SetText(opts.text)
    else
        text:SetText("")
    end

    -- 2. Cor do texto e do ícone
    local color
    if isCrit then
        color = COLOR_CRIT
    elseif isMiss then
        color = COLOR_MISS
    elseif isPet then
        color = COLOR_PET
    elseif isDot then
        color = COLOR_DOT
    else
        color = COLOR_NORMAL
    end

    text:SetTextColor(color[1], color[2], color[3], 1.0)

    -- 3. Ícone do tipo de dano (Slash, Thrust, Strike, Bleed, Fire, Frost, etc.)
    local iconPath = opts.icon or ICONS.slash
    text:ClearAllPoints()
    if cfg.showIcons and not isMiss and iconPath then
        local iconSize = isCrit and (cfg.critIconSize or baseCrit) or (cfg.iconSize or baseNormal)
        if isDot then iconSize = max(14, floor(iconSize * 0.85)) end
        icon:SetTexture(iconPath)
        icon:SetSize(iconSize, iconSize)
        if COLORED_ICONS[iconPath] then
            -- Ícones mágicos e sangramento preservam suas cores próprias em dois tons
            icon:SetVertexColor(1.0, 1.0, 1.0, 1.0)
        else
            -- Ícones físicos assumem exatamente a cor do dano (branco no normal, laranja no crítico)
            icon:SetVertexColor(color[1], color[2], color[3], 1.0)
        end
        icon:Show()
        text:SetPoint("CENTER", f, "CENTER", -floor(iconSize * 0.35), 0)
    else
        icon:Hide()
        text:SetPoint("CENTER", f, "CENTER", 0, 0)
    end

    -- 4. Ancoragem no Espaço de Jogo: posicionado à DIREITA do alvo (estilo Azaath)
    local targetPlate
    if opts.unit and _G.C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, p = pcall(C_NamePlate.GetNamePlateForUnit, opts.unit)
        if ok and p then targetPlate = p end
    end
    if not targetPlate and opts.destGUID and not IsSec(opts.destGUID) then
        targetPlate = nameplates[opts.destGUID]
    end
    if not targetPlate and UnitExists("target") and _G.C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, p = pcall(C_NamePlate.GetNamePlateForUnit, "target")
        if ok and p then targetPlate = p end
    end

    local targetGUID = UnitExists("target") and UnitGUID("target") or nil
    if IsSec(targetGUID) then targetGUID = nil end

    local anchorFrame = targetPlate
    local anchorPoint = "TOP"
    local baseRight   = (cfg and cfg.offsetX) or 68
    local startX, startY, driftX

    if anchorFrame and anchorFrame.IsShown and anchorFrame:IsShown() then
        -- A placa fica acima da cabeça; o dano aparece ao lado DIREITO do alvo (corpo/ombro)
        if isCrit then
            startX = (baseRight + 12) + random(-8, 16) -- crítico um pouco mais aberto à direita
            startY = -24 + random(-12, 10)
        else
            startX = baseRight + random(-10, 14)
            startY = -26 + random(-14, 8)
        end
        driftX = random(6, 14) -- flutua suavemente para cima e levemente mais para a direita
    elseif UnitExists("target") and (opts.unit == "target" or (opts.destGUID and targetGUID and targetGUID == opts.destGUID)) and _G.TargetFrame and TargetFrame:IsShown() then
        -- Ancoragem no quadro do alvo (deslocado para a direita)
        anchorFrame = TargetFrame
        anchorPoint = "TOP"
        startX = (baseRight + 10) + random(-10, 18)
        startY = 25 + random(-10, 15)
        driftX = random(5, 12)
    else
        -- Fallback: centro da tela, deslocado para o lado direito da visão
        anchorFrame = UIParent
        anchorPoint = "CENTER"
        startX = (baseRight + 20) + random(-15, 20)
        startY = 90 + random(-15, 20)
        driftX = random(6, 14)
    end

    -- Números que saem no mesmo instante (golpe + bônus) ficam um acima do outro
    if opts.stackIndex and opts.stackIndex > 0 then
        startY = startY + opts.stackIndex * floor(fontSize * 1.1)
    end

    -- 5. Parâmetros da Animação
    item.startTime     = GetTime()
    item.duration      = cfg.duration or 1.15
    item.floatDist     = cfg.floatDistance or 48
    item.baseScale     = 1.0
    item.startPop      = isCrit and 1.45 or 1.25 -- crítico "estoura" mais forte
    item.startX        = startX
    item.startY        = startY
    item.driftX        = driftX -- desvio ascendente-direito
    item.anchorFrame   = anchorFrame
    item.anchorPoint   = anchorPoint
    item.usingFallback = false

    -- Guarda coordenadas de tela para caso a placa suma no meio
    item.fallbackX = startX
    item.fallbackY = 120

    f:ClearAllPoints()
    f:SetPoint("CENTER", anchorFrame, anchorPoint, startX, startY)
    f:SetAlpha(1.0)
    f:SetScale(item.startPop * (cfg.scale or 1))
    f:Show()
end

--------------------------------------------------------------------------------
-- Resolução de Ícone por Escola e Tipo de Ataque
--------------------------------------------------------------------------------
local function GetAttackIcon(subevent, school, spellId)
    if subevent == "SWING_DAMAGE" or subevent == "SWING_MISSED" then
        return ResolveSchoolIcon(1, nil, false, false)
    elseif subevent == "RANGE_DAMAGE" or subevent == "RANGE_MISSED" then
        return ResolveSchoolIcon(1, nil, true, false)
    end

    local iconKey
    if spellId and not IsSec(spellId) then
        local meta = InspectSpell(spellId)
        iconKey = meta and meta.iconKey or nil
    end

    if school then
        return ResolveSchoolIcon(school, iconKey, false, false)
    end

    return ResolveSchoolIcon(1, iconKey, false, false)
end

--------------------------------------------------------------------------------
-- Fonte 1: UNIT_COMBAT (Suporte nativo a todas as versões de motor, incluindo 12.x)
--------------------------------------------------------------------------------
local function OnUnitCombat(unit, action, descriptor, damage, damageType)
    if not unit then return end
    local isPlayerUnit = (unit == "player")
    if not isPlayerUnit and UnitIsUnit then
        local ok, isSelf = pcall(UnitIsUnit, unit, "player")
        if ok and not IsSec(isSelf) and isSelf then
            isPlayerUnit = true
        end
    end
    if isPlayerUnit then
        -- Registra quando o jogador recebe dano para distinguir ganho de Raiva
        -- causado por apanhar de ganho de Raiva causado pelo nosso ataque básico.
        if not IsSec(action) and (action == "WOUND" or action == "ABSORB" or action == "BLOCK") then
            lastPlayerWoundedAt = GetTime()
            -- a Raiva de dano recebido também chega antes do número: paga um tick
            ClaimPowerTick(lastPlayerWoundedAt)
        end
        return
    end

    local textEnabled = cfg and cfg.enabled
    local camNeedsCrit = Azaath.ActionCam and Azaath.ActionCam.WantsTargetCrit and Azaath.ActionCam.WantsTargetCrit()
    if not textEnabled and not camNeedsCrit then return end

    -- Apenas processa o alvo principal ("target") ou "softenemy" quando não há alvo fixo
    if unit ~= "target" and not (unit == "softenemy" and not UnitExists("target")) then
        return
    end

    -- Ignora unidades aliadas/amigáveis (mas mantém inimigos em duelo e golpe fatal em mob)
    local canAtk
    local ok1, ca = pcall(UnitCanAttack, "player", unit)
    if ok1 and not IsSec(ca) then canAtk = (ca and true or false) end
    if canAtk == false then
        if _G.UnitIsFriend then
            local okF, isFriend = pcall(UnitIsFriend, "player", unit)
            if okF and not IsSec(isFriend) and isFriend then return end
        end
        local ok2, reaction = pcall(UnitReaction, unit, "player")
        if ok2 and not IsSec(reaction) and reaction ~= nil and reaction > 4 then
            return
        end
    end

    if IsSec(action) then return end
    lastUnitCombatAt = GetTime()

    local isSecDmg  = IsSec(damage)
    local isSecDesc = IsSec(descriptor)
    local isSecType = IsSec(damageType)

    local descStr = not isSecDesc and tostring(descriptor) or "SECRET"
    local typeStr = not isSecType and tostring(damageType) or "SECRET"
    local dmgStr  = not isSecDmg  and tostring(damage)     or "SECRET"

    DebugLog("UC: act=" .. tostring(action) .. " desc=" .. descStr .. " type=" .. typeStr .. " dmg=" .. dmgStr)

    -- Grava histórico para diagnóstico seguro
    _G.AzaathUIDB = _G.AzaathUIDB or {}
    _G.AzaathUIDB.hitTrace = _G.AzaathUIDB.hitTrace or {}
    local traceEntry = {
        time = lastUnitCombatAt,
        act  = tostring(action),
        desc = descStr,
        type = typeStr,
        dmg  = dmgStr,
    }
    table.insert(_G.AzaathUIDB.hitTrace, traceEntry)
    if #_G.AzaathUIDB.hitTrace > 25 then
        table.remove(_G.AzaathUIDB.hitTrace, 1)
    end

    local guid = UnitGUID(unit)
    if IsSec(guid) then guid = nil end

    local isCrit = (not isSecDesc) and (descriptor == "CRITICAL")
    local isCrushing = (not isSecDesc) and (descriptor == "CRUSHING")

    if action == "WOUND" and damage ~= nil then
        local schoolVal = (not isSecType and damageType ~= nil) and damageType or nil
        local icon = ResolveSchoolIcon(schoolVal, nil, false, false)
        local fmt = FormatDamage(damage)
        QueueHit("target", {
            trace      = traceEntry,
            school     = schoolVal,
            text       = fmt,
            critical   = isCrit,
            isCrushing = isCrushing,
            icon       = icon,
            unit       = unit,
            destGUID   = guid,
        })
    elseif MISS_TEXTS[action] and cfg and cfg.showMiss then
        local missText = MISS_TEXTS[action] or action or "Errou"
        QueueHit("target", {
            trace    = traceEntry,
            text     = missText,
            critical = false,
            miss     = true,
            unit     = unit,
            destGUID = guid,
        })
    end
end

--------------------------------------------------------------------------------
-- Fonte 3: COMBAT_LOG_EVENT_UNFILTERED (Para clientes que suportam CLEU aberto)
--------------------------------------------------------------------------------
local playerGUID
local petGUID

local function OnCombatLogEvent(...)
    if not cfg or not cfg.enabled then return end

    local e_time, e_event, e_hide, sGUID, sName, sFlags, sRaidFlags, dGUID, dName, dFlags, dRaidFlags
    local p12, p13, p14, p15, p16, p17, p18, p19, p20, p21, p22

    if _G.C_CombatLogInternal and type(C_CombatLogInternal.GetCurrentEventInfo) == "function" then
        local ok, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19, r20, r21, r22 = pcall(C_CombatLogInternal.GetCurrentEventInfo)
        if ok and r2 then
            e_time, e_event, e_hide, sGUID, sName, sFlags, sRaidFlags, dGUID, dName, dFlags, dRaidFlags = r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11
            p12, p13, p14, p15, p16, p17, p18, p19, p20, p21, p22 = r12, r13, r14, r15, r16, r17, r18, r19, r20, r21, r22
        end
    end

    if not e_event and _G.CombatLogGetCurrentEventInfo then
        local ok, r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11, r12, r13, r14, r15, r16, r17, r18, r19, r20, r21, r22 = pcall(CombatLogGetCurrentEventInfo)
        if ok and r2 then
            e_time, e_event, e_hide, sGUID, sName, sFlags, sRaidFlags, dGUID, dName, dFlags, dRaidFlags = r1, r2, r3, r4, r5, r6, r7, r8, r9, r10, r11
            p12, p13, p14, p15, p16, p17, p18, p19, p20, p21, p22 = r12, r13, r14, r15, r16, r17, r18, r19, r20, r21, r22
        end
    end

    if not e_event then
        local a1, a2, a3, a4, a5, a6, a7, a8, a9, a10, a11, a12, a13, a14, a15, a16, _, _, a19 = ...
        e_time, e_event, e_hide = a1, a2, a3
        sGUID, sName, sFlags = a4, a5, a6
        dGUID, dName, dFlags = a7, a8, a9
        p12, p13, p14, p15, p16, p17, p18 = a10, a11, a12, a13, a14, a15, a16
        p21 = a19
    end

    if not sGUID or not e_event then return end

    -- Apenas dano causado pelo jogador ou seu pet
    local myGUID   = playerGUID or (UnitGUID and UnitGUID("player"))
    local isPlayer = (sGUID == myGUID)
    local isPet    = (cfg.showPet and petGUID and sGUID == petGUID)
    if not (isPlayer or isPet) then return end

    DebugLog("CLEU: " .. tostring(e_event) .. " p12=" .. tostring(p12) .. " p15=" .. tostring(p15))

    -- Dano Corpo a Corpo (Ataque Automático / Swing)
    if e_event == "SWING_DAMAGE" then
        local amount   = p12
        local critical = p18
        if not amount or IsZeroDamage(amount) or not RecordHit(amount, critical) then return end
        local fmt = FormatDamage(amount)
        local isSec = Azaath.IsSecret and Azaath.IsSecret(fmt)
        if fmt and (isSec or (fmt ~= "" and fmt ~= "0")) then
            M:SpawnText({
                text     = fmt,
                critical = critical,
                icon     = ICONS.slash,
                destGUID = dGUID,
                pet      = isPet,
            })
        end

    -- Dano à Distância (Tiro / Flecha / Arremesso)
    elseif e_event == "RANGE_DAMAGE" then
        local amount   = p15 or p12
        local critical = p21 or p18
        if not amount or IsZeroDamage(amount) or not RecordHit(amount, critical) then return end
        local fmt = FormatDamage(amount)
        local isSec = Azaath.IsSecret and Azaath.IsSecret(fmt)
        if fmt and (isSec or (fmt ~= "" and fmt ~= "0")) then
            M:SpawnText({
                text     = fmt,
                critical = critical,
                icon     = ICONS.thrust,
                destGUID = dGUID,
                pet      = isPet,
            })
        end

    -- Dano Direto de Habilidades e Feitiços (GOLPE HEROICO / HEROIC STRIKE)
    elseif e_event == "SPELL_DAMAGE" then
        local spellId  = p12
        local school   = p14
        local amount   = p15 or p12
        local critical = p21 or p18
        if not amount or IsZeroDamage(amount) or not RecordHit(amount, critical) then return end
        local fmt = FormatDamage(amount)
        local isSec = Azaath.IsSecret and Azaath.IsSecret(fmt)
        if fmt and (isSec or (fmt ~= "" and fmt ~= "0")) then
            M:SpawnText({
                text     = fmt,
                critical = critical,
                icon     = GetAttackIcon(e_event, school, spellId),
                destGUID = dGUID,
                pet      = isPet,
            })
        end

    -- Dano Periódico (DoTs / Sangramentos / Venenos)
    elseif e_event == "SPELL_PERIODIC_DAMAGE" and cfg.showPeriodic then
        local spellId  = p12
        local school   = p14
        local amount   = p15 or p12
        local critical = p21 or p18
        if not amount or IsZeroDamage(amount) or not RecordHit(amount, critical) then return end
        local fmt = FormatDamage(amount)
        local isSec = Azaath.IsSecret and Azaath.IsSecret(fmt)
        if fmt and (isSec or (fmt ~= "" and fmt ~= "0")) then
            M:SpawnText({
                text     = fmt,
                critical = critical,
                icon     = GetAttackIcon(e_event, school, spellId),
                destGUID = dGUID,
                periodic = true,
                pet      = isPet,
            })
        end

    -- Falhas / Defesas no Ataque Corpo a Corpo
    elseif e_event == "SWING_MISSED" and cfg.showMiss then
        local missType = p12
        local missText = MISS_TEXTS[missType] or missType or "Errou"
        M:SpawnText({
            text     = missText,
            critical = false,
            miss     = true,
            destGUID = dGUID,
            pet      = isPet,
        })

    -- Falhas / Defesas em Feitiços e Tiros
    elseif (e_event == "SPELL_MISSED" or e_event == "RANGE_MISSED") and cfg.showMiss then
        local missType = p15 or p12
        local missText = MISS_TEXTS[missType] or missType or "Errou"
        M:SpawnText({
            text     = missText,
            critical = false,
            miss     = true,
            destGUID = dGUID,
            pet      = isPet,
        })
    end
end

--------------------------------------------------------------------------------
-- Fonte 2: Mensagens de Combate Próprias do Chat (Fallback legado sem UNIT_COMBAT)
--------------------------------------------------------------------------------
local function OnChatMessage(event, msg)
    if not cfg or not cfg.enabled or not msg then return end
    if IsSec(msg) then return end
    -- Só atua como fallback se UNIT_COMBAT não entregou eventos recentemente
    if (GetTime() - lastUnitCombatAt) <= 0.5 then return end

    local lower = string.lower(msg)
    local isHeroic = string.find(lower, "golpe heroico", 1, true) or string.find(lower, "heroic strike", 1, true)
    local isCleave = string.find(lower, "fissurar", 1, true) or string.find(lower, "cleave", 1, true) or string.find(lower, "transpassante", 1, true)

    if isHeroic or isCleave then
        DebugLog("ChatHeroic: " .. tostring(msg))
        local isCrit = (string.find(lower, "crítico", 1, true) or string.find(lower, "critico", 1, true) or string.find(lower, "critical", 1, true)) and true or false

        local amount = string.match(msg, "causando (%d+)")
                    or string.match(msg, "for (%d+)")
                    or string.match(msg, "(%d+) de dano")
                    or string.match(msg, "(%d+) damage")
                    or string.match(msg, "(%d+)")

        local num = tonumber(amount)
        if num and num > 0 then
            if not RecordHit(num, isCrit) then return end
            DebugLog("-> Golpe Heroico via Chat: " .. tostring(num) .. " crit=" .. tostring(isCrit))
            M:SpawnText({
                text     = tostring(num),
                critical = isCrit,
                icon     = ResolveSchoolIcon(1, isCleave and "slash" or nil, false, false),
                unit     = "target",
                destGUID = UnitGUID("target"),
            })
        end
    end
end


--------------------------------------------------------------------------------
-- Rastreamento de Placas de Nome (Nameplates) para Posicionamento 3D
--------------------------------------------------------------------------------
local function OnNamePlateAdded(unit)
    if not unit then return end
    local guid = UnitGUID(unit)
    -- (em combate o GUID da placa pode ser um valor secreto: usá-lo como chave de tabela dá erro)
    if not guid or (Azaath.IsSecret and Azaath.IsSecret(guid)) then return end
    local plate
    if _G.C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, p = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok and p then plate = p end
    end
    if plate then
        nameplates[guid] = plate
    end
end

local function OnNamePlateRemoved(unit)
    if not unit then return end
    local guid = UnitGUID(unit)
    if guid and not (Azaath.IsSecret and Azaath.IsSecret(guid)) then
        nameplates[guid] = nil
    end
end

--------------------------------------------------------------------------------
-- Supressão e Ajuste de Fontes Globais da Blizzard
--------------------------------------------------------------------------------
local function ApplyFontOverrides()
    local fontPath = GetFontPath()
    if not fontPath then return end

    local fontObjects = {
        _G.DamageNumberFont,
        _G.WorldTextFont,
        _G.CombatTextFont,
        _G.NumberFont_Outline_Huge,
        _G.NumberFont_Outline_Large,
        _G.NumberFont_Outline_Med,
        _G.NumberFont_Shadow_Huge,
        _G.NumberFont_Shadow_Med,
        _G.GameFontNormalLarge,
    }
    for _, fontObj in ipairs(fontObjects) do
        if fontObj and fontObj.SetFont then
            pcall(function()
                local _, size, flags = fontObj:GetFont()
                fontObj:SetFont(fontPath, size or 24, flags or "OUTLINE")
            end)
        end
    end
end

local function SilenceBlizzardCombatText()
    ApplyFontOverrides()

    local hideBlizz = true
    if cfg and cfg.hideBlizzard ~= nil then
        hideBlizz = cfg.hideBlizzard
    end
    if not hideBlizz then return end

    if SetCVar then
        local cvars = {
            "CombatDamage",
            "CombatHealing",
            "CombatLogPeriodicSpells",
            "PetMeleeDamage",
            "PetSpellDamage",
            "floatingCombatTextCombatDamage",
            "floatingCombatTextCombatDamage_v2",
            "floatingCombatTextCombatDamageDirectionalScale",
            "floatingCombatTextCombatHealing",
            "floatingCombatTextCombatHealing_v2",
            "floatingCombatTextCombatLogPeriodicSpells",
            "floatingCombatTextCombatLogPeriodicSpells_v2",
            "floatingCombatTextPetMeleeDamage",
            "floatingCombatTextPetMeleeDamage_v2",
            "floatingCombatTextPetSpellDamage",
            "floatingCombatTextPetSpellDamage_v2",
        }
        -- Só grava o que está diferente: cada SetCVar dispara CVAR_UPDATE na hora,
        -- e o código da Blizzard que reage a ele roda "contaminado" pelo addon
        -- (depois dá erros de valor secreto em quadros da Blizzard, ex.:
        -- CompactUnitFrame_UpdateHealthColor, e ações bloqueadas nas barras).
        local getcv = (_G.C_CVar and C_CVar.GetCVar) or _G.GetCVar
        local function current(cvar)
            if not getcv then return nil end
            local ok, v = pcall(getcv, cvar)
            return ok and v ~= nil and tostring(v) or nil
        end
        for _, cvar in ipairs(cvars) do
            local cur = current(cvar)
            if cur ~= nil and cur ~= "0" then pcall(SetCVar, cvar, "0") end
        end
        local fct = current("enableFloatingCombatText")
        if fct ~= nil and fct ~= "1" then pcall(SetCVar, "enableFloatingCombatText", "1") end
    end

    if _G.CombatText then
        if CombatText.UnregisterAllEvents then
            pcall(CombatText.UnregisterAllEvents, CombatText)
        end
        CombatText:Hide()
    end
end
M.SilenceBlizzardCombatText = SilenceBlizzardCombatText

--------------------------------------------------------------------------------
-- Ciclo de Vida do Módulo
--------------------------------------------------------------------------------
function M:OnInitialize()
    cfg = Azaath.db and Azaath.db.combattext or Azaath.defaults.combattext
    if cfg and cfg.hideBlizzard == nil then
        cfg.hideBlizzard = true
    end
end

function M:OnEnable()
    cfg = Azaath.db and Azaath.db.combattext or Azaath.defaults.combattext
    if cfg then
        if cfg.fontStyle == "imfell" or not cfg.fontStyle then
            cfg.fontStyle = "cinzel"
        end
        if cfg.hideBlizzard == nil then
            cfg.hideBlizzard = true
        end
    end
    playerGUID = UnitGUID("player")
    petGUID    = UnitGUID("pet")

    -- Define globalmente a fonte de dano do cliente para a fonte do Azaath
    if Azaath.media and (Azaath.media.fontDamage or Azaath.media.fontTitleB) then
        _G.DAMAGE_TEXT_FONT = Azaath.media.fontDamage or Azaath.media.fontTitleB
    end

    ApplyFontOverrides()

    -- Cria frame ouvinte de eventos de combate
    local eventFrame = CreateFrame("Frame")
    pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_COMBAT")
    -- (sem COMBAT_LOG_EVENT_UNFILTERED: neste cliente o log de combate é proibido para addons, e
    -- só tentar registrá-lo abria a janela de "ação bloqueada" a cada /reload, mesmo com pcall)
    -- (sem COMBAT_TEXT_UPDATE e sem CHAT_MSG_SPELL_DAMAGING_CREATURE: eles reportam dano
    -- recebido pelo jogador ou dano de criaturas/aliados ao redor, gerando falsos positivos)
    pcall(eventFrame.RegisterEvent, eventFrame, "CHAT_MSG_SPELL_SELF_DAMAGE")
    pcall(eventFrame.RegisterEvent, eventFrame, "CHAT_MSG_COMBAT_SELF_HITS")
    pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_ENTERING_WORLD")
    pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_PET")

    -- Sinais de autoria e troca de arma/forma (ver IsMyHit / GetWeaponAttackKind)
    for _, ev in ipairs({
        "UNIT_SPELLCAST_SUCCEEDED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE",
        "UNIT_SPELLCAST_CHANNEL_STOP", "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT",
        "START_AUTOREPEAT_SPELL", "STOP_AUTOREPEAT_SPELL", "UNIT_POWER_FREQUENT", "UNIT_RAGE",
        "UNIT_ATTACK_SPEED", "PLAYER_TARGET_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_SHAPESHIFT_FORM",
    }) do
        pcall(eventFrame.RegisterEvent, eventFrame, ev)
    end
    RefreshSpeeds()
    RefreshWeaponKinds()
    if _G.IsCurrentSpell then
        local ok, on = pcall(IsCurrentSpell, 6603) -- ataque automático já ligado após /reload
        if ok and not IsSec(on) and on then autoAttacking = true end
    end

    if _G.C_NamePlate then
        pcall(eventFrame.RegisterEvent, eventFrame, "NAME_PLATE_UNIT_ADDED")
        pcall(eventFrame.RegisterEvent, eventFrame, "NAME_PLATE_UNIT_REMOVED")
    end

    eventFrame:SetScript("OnEvent", function(self, event, ...)
        if event == "UNIT_COMBAT" then
            OnUnitCombat(...)
        elseif event == "COMBAT_LOG_EVENT_UNFILTERED" or event == "COMBAT_LOG_EVENT_INTERNAL_UNFILTERED" then
            OnCombatLogEvent(...)
        elseif event == "CHAT_MSG_SPELL_SELF_DAMAGE" or event == "CHAT_MSG_COMBAT_SELF_HITS" then
            OnChatMessage(event, ...)
        elseif event == "PLAYER_ENTERING_WORLD" then
            playerGUID = UnitGUID("player")
            petGUID    = UnitGUID("pet")
            RefreshSpeeds()
            RefreshWeaponKinds()
            SilenceBlizzardCombatText()
        elseif event == "PLAYER_EQUIPMENT_CHANGED" or event == "UPDATE_SHAPESHIFT_FORM" then
            RefreshWeaponKinds()
            RefreshSpeeds()
        elseif event == "PLAYER_TARGET_CHANGED" then
            RefreshSpeeds()
        elseif event == "UNIT_ATTACK_SPEED" then
            local unit = ...
            if unit == "player" then RefreshSpeeds() end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            local unit, _, spellID = ...
            if unit == "player" then
                RecordMyCast(spellID, false)
            elseif unit == "pet" and cfg and cfg.showPet then
                RecordMyCast(spellID, true)
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
            local unit, _, spellID = ...
            if unit == "player" then
                local meta = InspectSpell(spellID)
                if meta.harmful then
                    channelUntil = math.huge
                    channelSchoolMask = meta.schoolMask
                    channelIconKey = meta.iconKey
                else
                    channelUntil = 0
                    channelSchoolMask = nil
                    channelIconKey = nil
                end
            end
        elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
            local unit = ...
            if unit == "player" then
                channelUntil = (channelUntil > 0) and (GetTime() + 0.25) or 0
                if channelUntil == 0 then
                    channelSchoolMask = nil
                    channelIconKey = nil
                end
            end
        elseif event == "PLAYER_ENTER_COMBAT" then
            autoAttacking = true
        elseif event == "PLAYER_LEAVE_COMBAT" then
            autoAttacking = false
        elseif event == "START_AUTOREPEAT_SPELL" then
            autoRepeating = true
        elseif event == "STOP_AUTOREPEAT_SPELL" then
            autoRepeating = false
        elseif event == "UNIT_POWER_FREQUENT" or event == "UNIT_RAGE" then
            local unit, powerType = ...
            if unit == "player" then
                if event == "UNIT_POWER_FREQUENT" and UsesRage() and powerType ~= nil and not IsSec(powerType) and powerType ~= "RAGE" then
                    return
                end
                local now = GetTime()
                lastPowerTick = now
                if UsesRage() then
                    -- Só ganhos contam (gasto de habilidade não é swing); valor secreto = aceita
                    local gain = true
                    local okR, cur = pcall(UnitPower, "player", 1)
                    if okR and Readable(cur) then
                        gain = (lastRageVal == nil) or (cur > lastRageVal)
                        lastRageVal = cur
                    end
                    if gain then
                        local castNow = false
                        for _, c in ipairs(myCasts) do
                            if math.abs(c.t - now) <= 0.06 and not c.isPet then castNow = true; break end
                        end
                        powerTicks[#powerTicks + 1] = { t = now, used = castNow }
                        while powerTicks[1] and (now - powerTicks[1].t) > 2 do
                            table.remove(powerTicks, 1)
                        end
                    end
                end
            end
        elseif event == "UNIT_PET" then
            local unit = ...
            if unit == "player" then
                petGUID = UnitGUID("pet")
            end
        elseif event == "NAME_PLATE_UNIT_ADDED" then
            OnNamePlateAdded(...)
        elseif event == "NAME_PLATE_UNIT_REMOVED" then
            OnNamePlateRemoved(...)
        end
    end)
    self.eventFrame = eventFrame

    SilenceBlizzardCombatText()

    if _G.DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFA7A14[Azaath CombatText]|r Versão 1.2.0 carregada.")
    end
end

--------------------------------------------------------------------------------
-- Função de Teste Visual (Dano físico da arma atual, crítico e exemplos coloridos)
--------------------------------------------------------------------------------
function M:Test()
    local guid = UnitGUID("target") or playerGUID
    RefreshWeaponKinds()
    local weaponIcon = ResolveSchoolIcon(1, nil, false, false)

    -- 1. Dano físico normal com o tipo de arma equipada
    self:SpawnText({
        text     = "65",
        critical = false,
        icon     = weaponIcon,
        destGUID = guid,
        unit     = "target",
    })

    local C_Timer = _G.C_Timer
    if C_Timer and C_Timer.After then
        -- 2. Dano físico crítico (laranja)
        C_Timer.After(0.30, function()
            self:SpawnText({
                text     = "184",
                critical = true,
                icon     = weaponIcon,
                destGUID = guid,
                unit     = "target",
            })
        end)
        -- 3. Sangramento (vermelho carmesim)
        C_Timer.After(0.60, function()
            self:SpawnText({
                text     = "48",
                critical = false,
                periodic = true,
                icon     = ICONS.bleed,
                destGUID = guid,
                unit     = "target",
            })
        end)
        -- 4. Exemplo elemental/mágico colorido (Fogo-Gelo crítico)
        C_Timer.After(0.90, function()
            self:SpawnText({
                text     = "245",
                critical = true,
                icon     = ICONS.frostfire,
                destGUID = guid,
                unit     = "target",
            })
        end)
    else
        self:SpawnText({
            text     = "184",
            critical = true,
            icon     = weaponIcon,
            destGUID = guid,
            unit     = "target",
        })
    end
end

-- Comandos diretos de barra para facilidade de teste
SLASH_AZAATHDAMAGE1 = "/azaathdamage"
SLASH_AZAATHDAMAGE2 = "/damage"
SlashCmdList["AZAATHDAMAGE"] = function()
    M:Test()
end

SLASH_AZAATHDEBUG1 = "/azctdebug"
SlashCmdList["AZAATHDEBUG"] = function()
    debugMode = not debugMode
    if _G.DEFAULT_CHAT_FRAME then
        DEFAULT_CHAT_FRAME:AddMessage("|cffFA7A14[Azaath CombatText]|r Debug " .. (debugMode and "|cff55ff55ATIVADO|r" or "|cffff5555DESATIVADO|r"))
    end
end
