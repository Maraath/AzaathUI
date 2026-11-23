--[[----------------------------------------------------------------------------
    AzaathUI - Modules/CastBar.lua
    Barras de conjuração do jogador e do alvo.

      * Jogador: por padrão um ANEL em espiral no estilo Azaath (o anel se
        preenche no sentido horário a partir do topo; canalizações esvaziam).
        Ícone redondo no centro, nome e tempo embaixo. O estilo antigo (barra
        horizontal com zona de latência) continua disponível nas opções.
      * Interação com o mundo (baús, minérios, ervas, objetos de missão,
        esfolar): a conjuração aparece num segundo anel EM CIMA do objeto,
        como no Azaath. O jogo não informa onde o objeto está na tela; a
        posição vem do cursor no momento em que o objeto foi apontado (a dica
        do objeto na tela confirma que o cursor está sobre ele). Sem cursor
        sobre o objeto (tecla de interagir), o anel fica no centro da tela.
      * Alvo: barra horizontal logo abaixo do frame do alvo; borda/cor
        prateada quando o feitiço não pode ser interrompido.
      * Sucesso = cheio em verde com fade; falha/interrupção = vermelho com
        "Falhou"/"Interrompido", pausa curta e fade.

    Como o anel anda: um widget Cooldown com a textura do anel no "swipe"
    (SetSwipeTexture). O próprio jogo anima o setor a partir de início/duração;
    o addon só move o brilho da ponta (seno/cosseno) e o texto do tempo.
    SetReverse(true) desenha a parte já decorrida (anel enchendo); sem reverse,
    a parte restante (canalização esvaziando).

    Detecção da interação: UNIT_SPELLCAST_SENT (unidade, alvo, castGUID,
    spellID) chega antes do START. É interação quando o feitiço é de coleta/
    abertura (lista de IDs e seus nomes traduzidos) ou quando o "alvo" do
    feitiço tem nome mas não é nenhuma unidade conhecida (é um objeto).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("CastBar")

local _G = _G
local pairs, ipairs, type, select, format, pcall = pairs, ipairs, type, select, string.format, pcall
local max, min, floor, sin, cos, pi = math.max, math.min, math.floor, math.sin, math.cos, math.pi
local GetTime = GetTime
local UnitExists, UnitName = UnitExists, UnitName
local UnitHasVehicleUI = UnitHasVehicleUI

local FADE_TIME     = 0.35 -- segundos de fade-out
local FAIL_HOLD     = 0.5  -- pausa exibindo "Interrompido" antes do fade
local TEXT_INTERVAL = 0.05 -- throttle do texto de tempo
local SPARK_TEXTURE = "Interface\\CastingBar\\UI-CastingBar-Spark"
local TEST_ICON     = "Interface\\Icons\\INV_Misc_QuestionMark"
local RING_RADIUS   = 110 / 128 -- meio da faixa de CastRing.tga, em fração do raio
local RING_TEXT_H   = 30        -- espaço abaixo do anel para nome + tempo
local SENT_WINDOW   = 2.0       -- SENT -> START precisa acontecer dentro disso
local OBJECT_MEMORY = 2.5       -- segundos que a última dica de objeto vale

local COLORS = {
    cast      = { 0.93, 0.72, 0.32 }, -- âmbar
    channel   = { 0.42, 0.70, 0.85 }, -- azul-esverdeado
    shielded  = { 0.62, 0.62, 0.66 }, -- não interrompível
    success   = { 0.45, 0.78, 0.35 },
    failed    = { 0.78, 0.25, 0.20 },
    world     = { 0.96, 0.85, 0.55 }, -- interação: dourado claro do Azaath
}

-- Feitiços de interação com objetos do mundo (todas as versões/postos).
-- Os nomes traduzidos deles também contam (cobre postos que faltarem aqui).
local INTERACT_IDS = {
    -- Abrir (baús, caixas, objetos de missão)
    3365, 6247, 6477, 6478, 21248, 21288, 21651, 22810, 24390, 26868,
    -- Arrombar (ladino)
    1804,
    -- Mineração
    2575, 2576, 3564, 10248, 29354, 50310, 74517, 102161, 158754, 195122, 265837, 366260,
    -- Colher ervas
    2366, 2368, 3570, 11993, 28695, 50300, 74519, 110413, 158745, 195114, 265819, 366252,
    -- Esfolar
    8613, 8617, 8618, 10768, 32678, 50305, 74522, 102216, 158756, 194174, 265855, 366263,
}

local bars = {} -- [key] = frame ("player", "target", "world")

--------------------------------------------------------------------------------
-- Utilidades
--------------------------------------------------------------------------------
local function MediaPath(name)
    return Azaath.media.path .. name
end

local function SpellName(spellID)
    if not spellID then return nil end
    if _G.C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, spellID)
        if ok then return n end
    end
    if _G.GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, spellID)
        if ok then return n end
    end
    return nil
end

local interactIDs, interactNames
local function BuildInteractSets()
    if interactIDs then return end
    interactIDs, interactNames = {}, {}
    for _, id in ipairs(INTERACT_IDS) do
        interactIDs[id] = true
        local n = SpellName(id)
        if type(n) == "string" and not Azaath.IsSecret(n) and n ~= "" then
            interactNames[n] = true
        end
    end
end

-- Texto legível (nem secreto nem vazio)
local function Plain(s)
    if Azaath.IsSecret(s) or type(s) ~= "string" or s == "" then return nil end
    return s
end

local function MouseOverWorld()
    local focus
    if _G.GetMouseFoci then
        local ok, foci = pcall(GetMouseFoci)
        focus = ok and type(foci) == "table" and foci[1] or nil
    elseif _G.GetMouseFocus then
        local ok, f = pcall(GetMouseFocus)
        focus = ok and f or nil
    end
    return focus == nil or focus == _G.WorldFrame
end

--------------------------------------------------------------------------------
-- Rastreio do objeto sob o cursor (pela dica de tela do jogo)
--------------------------------------------------------------------------------
-- Ao apontar um baú/minério/erva o jogo mostra a GameTooltip sem unidade.
-- Guardamos o nome e a posição do cursor enquanto ela está aberta.
local hoverObj = { name = nil, x = 0, y = 0, shown = false, seen = 0 }

local function TooltipObjectName()
    local tt = _G.GameTooltip
    if not tt or not tt:IsShown() then return nil end
    local ok, _, unit = pcall(tt.GetUnit, tt)
    if not ok or Azaath.IsSecret(unit) or unit ~= nil then return nil end
    local owner = tt.GetOwner and tt:GetOwner()
    if owner and owner ~= _G.UIParent and owner ~= _G.WorldFrame then return nil end
    local line = _G.GameTooltipTextLeft1
    return line and Plain(line:GetText())
end

local function TrackTooltip()
    local name = TooltipObjectName()
    if name and MouseOverWorld() then
        local x, y = GetCursorPosition()
        hoverObj.name, hoverObj.x, hoverObj.y = name, x, y
        hoverObj.shown, hoverObj.seen = true, GetTime()
    elseif hoverObj.shown then
        hoverObj.shown = false
        hoverObj.seen = GetTime()
    end
end

local tooltipHooked = false
local function HookTooltip()
    if tooltipHooked or not _G.GameTooltip then return end
    tooltipHooked = true
    GameTooltip:HookScript("OnShow", TrackTooltip)
    GameTooltip:HookScript("OnUpdate", TrackTooltip)
    GameTooltip:HookScript("OnHide", function()
        if hoverObj.shown then
            hoverObj.shown = false
            hoverObj.seen = GetTime()
        end
    end)
end

--------------------------------------------------------------------------------
-- Construção: comum
--------------------------------------------------------------------------------
local backdrop
local function GetBackdrop()
    if not backdrop then
        local blank = Azaath.media.blank
        backdrop = {
            bgFile = blank, edgeFile = blank, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        }
    end
    return backdrop
end

local function CreateText(parent, size, justify, font)
    local c = Azaath.colors.cream
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or Azaath.media.font, size, "OUTLINE")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.7)
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH(justify)
    return fs
end

local function SetBorder(f, shielded)
    local c = shielded and COLORS.shielded or Azaath.colors.gold
    local a = shielded and 0.9 or 0.35
    if f.isRing then
        if f.edge then f.edge:SetVertexColor(c[1], c[2], c[3], shielded and 0.95 or 0.75) end
        return
    end
    f:SetBackdropBorderColor(c[1], c[2], c[3], a)
    if f.iconFrame then f.iconFrame:SetBackdropBorderColor(c[1], c[2], c[3], a) end
end

local OnUpdate -- definido abaixo

local function FrameName(key)
    if key == "player" then return "AzaathUICastBarPlayer" end
    if key == "target" then return "AzaathUICastBarTarget" end
    return "AzaathUICastBarWorld"
end

--------------------------------------------------------------------------------
-- Construção: barra horizontal (alvo; jogador no estilo "bar")
--------------------------------------------------------------------------------
local function CreateLinearBar(key, width, height, withLatency)
    local c, blank = Azaath.colors, Azaath.media.blank
    local f = CreateFrame("Frame", FrameName(key), Azaath.root)
    f.key = key
    f.unit = key
    f:SetFrameStrata("LOW")
    f:SetWidth(width)
    f:SetHeight(height)
    Azaath.SetBackdrop(f, GetBackdrop())
    f:SetBackdropColor(c.dark[1], c.dark[2], c.dark[3], 0.8)

    local bar = CreateFrame("StatusBar", nil, f)
    bar:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(blank)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    f.bar = bar

    -- Zona segura (latência) no fim da barra — só para conjurações do jogador
    if withLatency then
        local safe = bar:CreateTexture(nil, "OVERLAY") -- acima do preenchimento
        safe:SetTexture(blank)
        safe:SetVertexColor(0.85, 0.20, 0.15)
        safe:SetAlpha(0.45)
        safe:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
        safe:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
        safe:SetWidth(1)
        safe:Hide()
        f.safe = safe
    end

    local overlay = CreateFrame("Frame", nil, f)
    overlay:SetAllPoints(bar)
    overlay:SetFrameLevel(bar:GetFrameLevel() + 1)

    local gloss = overlay:CreateTexture(nil, "BACKGROUND")
    gloss:SetTexture(blank)
    gloss:SetPoint("TOPLEFT", overlay, "TOPLEFT")
    gloss:SetPoint("TOPRIGHT", overlay, "TOPRIGHT")
    gloss:SetHeight(floor(height / 2))
    Azaath.Gradient(gloss, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.10)
    f.gloss = gloss

    local spark = overlay:CreateTexture(nil, "ARTWORK")
    spark:SetTexture(SPARK_TEXTURE)
    spark:SetBlendMode("ADD")
    spark:SetWidth(14)
    spark:SetHeight(height * 2.2)
    spark:Hide()
    f.spark = spark

    local fontSize = height >= 14 and 11 or 9
    f.time = CreateText(overlay, fontSize, "RIGHT")
    f.time:SetPoint("RIGHT", overlay, "RIGHT", -4, 0)

    f.text = CreateText(overlay, fontSize, "LEFT")
    f.text:SetPoint("LEFT", overlay, "LEFT", 4, 0)
    f.text:SetPoint("RIGHT", f.time, "LEFT", -4, 0) -- trunca nomes longos
    f.text:SetHeight(fontSize + 2)

    -- Ícone quadrado à esquerda, fora da barra
    local iconFrame = CreateFrame("Frame", nil, f)
    iconFrame:SetWidth(height + 4)
    iconFrame:SetHeight(height + 4)
    iconFrame:SetPoint("RIGHT", f, "LEFT", -4, 0)
    Azaath.SetBackdrop(iconFrame, GetBackdrop())
    iconFrame:SetBackdropColor(c.dark[1], c.dark[2], c.dark[3], 0.8)
    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.iconFrame, f.icon = iconFrame, icon

    SetBorder(f, false)

    f.holdTime, f.textElapsed = 0, 0
    f:SetScript("OnUpdate", OnUpdate)
    f:Hide()

    bars[key] = f
    return f
end

--------------------------------------------------------------------------------
-- Construção: anel em espiral (estilo Azaath)
--------------------------------------------------------------------------------
-- O swipe com textura própria existe no motor moderno (WoW Forever).
local function RingSupported()
    local probe = M.ringProbe
    if probe == nil then
        local ok, cd = pcall(CreateFrame, "Cooldown", nil, UIParent, "CooldownFrameTemplate")
        probe = ok and cd and cd.SetSwipeTexture ~= nil and cd.SetReverse ~= nil or false
        if ok and cd then cd:Hide() end
        M.ringProbe = probe
    end
    return probe
end

--------------------------------------------------------------------------------
-- Efeitos por escola de magia (anel das habilidades)
--------------------------------------------------------------------------------
-- O jogo não diz a escola de um feitiço para addons. Ela é deduzida pelo nome
-- (pt-BR e inglês), depois pela descrição ("dano Sagrado", "Fire damage") e
-- por fim pela classe (paladino = Luz, bruxo = Sombra...). Cada escola tem cor,
-- aura, raios girando, partículas com movimento próprio, rastro na ponta e
-- uma explosão de luz ao concluir.
local random = math.random
local THEMES = {
    holy = {
        color = { 1.00, 0.84, 0.42 }, glow = { 1.00, 0.88, 0.50 }, aura = 0.55,
        rays = { alpha = 0.60, speed = 0.35, color = { 1.00, 0.93, 0.62 } },
        motes = { mode = "rise", tex = "Star", color = { 1.00, 0.95, 0.72 }, rate = 14, size = { 6, 11 }, life = 0.95, spin = 1.5 },
        shine = 0.35,
    },
    fire = {
        color = { 1.00, 0.50, 0.12 }, glow = { 1.00, 0.38, 0.06 }, aura = 0.60, flicker = true,
        motes = { mode = "embers", tex = "Glow", color = { 1.00, 0.72, 0.25 }, color2 = { 1.00, 0.30, 0.04 }, rate = 24, size = { 3, 6 }, life = 0.8 },
        shine = 0.25,
    },
    frost = {
        color = { 0.58, 0.86, 1.00 }, glow = { 0.42, 0.72, 1.00 }, aura = 0.42,
        rays = { alpha = 0.28, speed = -0.15, color = { 0.72, 0.90, 1.00 } },
        motes = { mode = "drift", tex = "Star", color = { 0.82, 0.95, 1.00 }, rate = 10, size = { 6, 10 }, life = 1.1, spin = 0.8 },
        shine = 0.25,
    },
    arcane = {
        color = { 0.82, 0.52, 1.00 }, glow = { 0.68, 0.38, 1.00 }, aura = 0.48,
        rays = { alpha = 0.32, speed = 0.70, color = { 0.86, 0.62, 1.00 } },
        motes = { mode = "orbit", tex = "Star", color = { 0.92, 0.72, 1.00 }, rate = 12, size = { 5, 9 }, life = 1.2, spin = 2.5 },
        shine = 0.30,
    },
    shadow = {
        color = { 0.68, 0.42, 1.00 }, glow = { 0.42, 0.12, 0.80 }, aura = 0.55,
        motes = { mode = "inward", tex = "Glow", color = { 0.62, 0.30, 0.98 }, rate = 18, size = { 4, 9 }, life = 0.9 },
        shine = 0.15,
    },
    fel = {
        color = { 0.58, 1.00, 0.25 }, glow = { 0.32, 0.90, 0.08 }, aura = 0.55, flicker = true,
        motes = { mode = "embers", tex = "Glow", color = { 0.70, 1.00, 0.30 }, color2 = { 0.25, 0.80, 0.05 }, rate = 22, size = { 3, 6 }, life = 0.8 },
        shine = 0.20,
    },
    nature = {
        color = { 0.55, 0.95, 0.40 }, glow = { 0.38, 0.85, 0.30 }, aura = 0.42,
        motes = { mode = "rise", tex = "Glow", color = { 0.72, 1.00, 0.52 }, rate = 12, size = { 3, 6 }, life = 1.0 },
        shine = 0.20,
    },
    physical = {
        color = COLORS.cast, glow = { 1.00, 0.72, 0.32 }, aura = 0.25,
        shine = 0.10,
    },
}

-- Palavras do NOME (minúsculas; o nome vai cercado de espaços: " luz sagrada ")
local NAME_KEYS = {
    arcane = { "arcan", "lunar", "estelar", "astral", "arcane", "moon", "starfire", "starsurge" },
    fel    = { " vil", "caos", "chaos", " fel " },
    shadow = { "sombr", "mental", "shadow", " mind", "corrup", "agonia", "dreno", "drenar", "drain", "vazio", "void", "medo", "fear", "profan", "unholy" },
    frost  = { "gelo", "geada", "congel", "frio", "nevasca", "glacial", "gélid", "gelid", "frost", " ice", "blizzard", "inverno" },
    fire   = { "fogo", "chama", "ígne", "igne", "incend", "incinera", "piro", "lava", "fire", "flame", "pyro", "scorch", "abrasa", "combust", "inferno", "imola", "immolat", "meteoro", "brasa" },
    holy   = { "luz", "sagrad", "divin", "light", "holy", "divine", "consagr", "exorc", "santo", "sacro", "bênção", "bencao" },
    nature = { "natur", "raio", "relâmpago", "relampago", "trovão", "trovao", "tempest", "rejuven", "recresc", "crescimento", "enraiz", "lightning", "nature", "thunder", " ira ", "wrath" },
}
-- Frases da DESCRIÇÃO
local DESC_KEYS = {
    arcane = { "dano arcano", "arcane damage" },
    fel    = { "dano vil", "fel damage", "dano caótico", "chaos damage" },
    shadow = { "dano de sombra", "shadow damage" },
    frost  = { "dano de gelo", "frost damage" },
    fire   = { "dano de fogo", "fire damage" },
    holy   = { "dano sagrado", "holy damage" },
    nature = { "dano de natureza", "nature damage" },
}
local SCHOOL_ORDER = { "arcane", "fel", "shadow", "frost", "fire", "holy", "nature" }

local function HasAny(text, list)
    if not text or text == "" then return false end
    for _, k in ipairs(list) do
        if text:find(k, 1, true) then return true end
    end
    return false
end

local function SpellDescription(spellID)
    if not spellID then return nil end
    local fn = (_G.C_Spell and C_Spell.GetSpellDescription) or _G.GetSpellDescription
    if not fn then return nil end
    local ok, d = pcall(fn, spellID)
    return ok and Plain(d) or nil
end

local themeCache = {}
local function ResolveTheme(spellID, name)
    if spellID and themeCache[spellID] then return THEMES[themeCache[spellID]] end
    local n = " " .. (Plain(name) or ""):lower() .. " "
    local d = (SpellDescription(spellID) or ""):lower()
    local function is(school) return HasAny(n, NAME_KEYS[school]) or HasAny(d, DESC_KEYS[school]) end
    local generic
    for _, s in ipairs(SCHOOL_ORDER) do
        if is(s) then generic = s; break end
    end
    local _, cls = UnitClass("player")
    local function oneOf(...)
        for i = 1, select("#", ...) do
            if generic == select(i, ...) then return generic end
        end
        return nil
    end
    local school
    if cls == "PALADIN" then school = "holy"
    elseif cls == "PRIEST" then school = is("shadow") and "shadow" or "holy"
    elseif cls == "WARLOCK" then school = oneOf("fire", "fel") or "shadow"
    elseif cls == "MAGE" then school = oneOf("frost", "fire", "arcane") or "arcane"
    elseif cls == "SHAMAN" then school = oneOf("fire", "frost") or "nature"
    elseif cls == "DRUID" then school = oneOf("arcane") or "nature"
    elseif cls == "DEATHKNIGHT" then school = oneOf("frost", "shadow") or "frost"
    elseif cls == "DEMONHUNTER" then school = "fel"
    elseif cls == "EVOKER" then school = oneOf("frost", "nature", "arcane") or "fire"
    elseif cls == "MONK" then school = generic or "nature"
    else school = generic or "physical" end
    -- só guarda quando a descrição já carregou (senão tenta de novo na próxima)
    if spellID and d ~= "" then themeCache[spellID] = school end
    return THEMES[school]
end

local function CurrentSpellID(unit, channel)
    if not Azaath.IS_MODERN then return nil end
    local ok, id
    if channel then
        ok, id = pcall(function() return select(8, UnitChannelInfo(unit)) end)
    else
        ok, id = pcall(function() return select(9, UnitCastingInfo(unit)) end)
    end
    if not ok or Azaath.IsSecret(id) or type(id) ~= "number" then return nil end
    return id
end

local MOTE_POOL, TRAIL_N = 26, 6

-- Camadas extras do anel das habilidades
local function CreateFX(f)
    local glowTex, haloTex = MediaPath("Glow"), MediaPath("CastRingHalo")
    local fx = { motes = {}, trail = {}, rayRot = 0, clock = 0, spawnAcc = 0 }
    f.fx = fx

    -- Atrás do anel: raios girando e aura colorida
    fx.rays = f.ring:CreateTexture(nil, "BACKGROUND", nil, -6)
    fx.rays:SetTexture(MediaPath("Rays"))
    fx.rays:SetBlendMode("ADD")
    fx.rays:SetPoint("CENTER")
    fx.aura = f.ring:CreateTexture(nil, "BACKGROUND", nil, -5)
    fx.aura:SetTexture(glowTex)
    fx.aura:SetBlendMode("ADD")
    fx.aura:SetPoint("CENTER")
    fx.ringGlow = f.ring:CreateTexture(nil, "BACKGROUND", nil, -4)
    fx.ringGlow:SetTexture(haloTex)
    fx.ringGlow:SetBlendMode("ADD")
    fx.ringGlow:SetPoint("CENTER")

    -- Por cima: brilho no ícone, rastro da ponta, partículas e explosão final
    local top = CreateFrame("Frame", nil, f)
    top:SetAllPoints(f.ring)
    top:SetFrameLevel(f.overlay:GetFrameLevel() + 3)
    fx.top = top
    fx.shine = f.overlay:CreateTexture(nil, "ARTWORK", nil, 3)
    fx.shine:SetTexture(glowTex)
    fx.shine:SetBlendMode("ADD")
    fx.shine:SetPoint("CENTER")
    for i = 1, TRAIL_N do
        local t = top:CreateTexture(nil, "ARTWORK")
        t:SetTexture(glowTex)
        t:SetBlendMode("ADD")
        fx.trail[i] = t
    end
    for i = 1, MOTE_POOL do
        local t = top:CreateTexture(nil, "OVERLAY")
        t:SetBlendMode("ADD")
        t:Hide()
        fx.motes[i] = { tex = t, alive = false }
    end
    fx.burst = top:CreateTexture(nil, "OVERLAY", nil, 2)
    fx.burst:SetTexture(haloTex)
    fx.burst:SetBlendMode("ADD")
    fx.burst:SetPoint("CENTER")
    fx.flash = top:CreateTexture(nil, "OVERLAY", nil, 3)
    fx.flash:SetTexture(glowTex)
    fx.flash:SetBlendMode("ADD")
    fx.flash:SetPoint("CENTER")
end

local function HideFX(f)
    local fx = f.fx
    if not fx then return end
    fx.rays:Hide(); fx.aura:Hide(); fx.ringGlow:Hide(); fx.shine:Hide()
    fx.burst:Hide(); fx.flash:Hide()
    for i = 1, TRAIL_N do fx.trail[i]:Hide() end
    for _, m in ipairs(fx.motes) do m.alive = false; m.tex:Hide() end
    fx.active, fx.burstT = false, nil
end

local function SetSize(t, w) t:SetWidth(w); t:SetHeight(w) end

local function SpawnMote(f, mode)
    local fx, th = f.fx, f.theme
    local mc = th and th.motes
    if not mc then return end
    local m
    for _, x in ipairs(fx.motes) do
        if not x.alive then m = x; break end
    end
    if not m then return end
    local s = (f.size or 56) / 56
    local R = (f.size or 56) * 0.5 * (f.radius or RING_RADIUS)
    mode = mode or mc.mode
    m.alive, m.t, m.mode = true, 0, mode
    m.life = mc.life * (0.8 + random() * 0.4)
    m.size = (mc.size[1] + random() * (mc.size[2] - mc.size[1])) * s
    m.spin = (mc.spin or 0) * (random() < 0.5 and -1 or 1)
    m.rot = random() * pi
    local a = random() * 2 * pi
    m.ang = a
    if mode == "rise" then
        m.x, m.y = R * sin(a), R * cos(a) * 0.9
        m.vx, m.vy = (random() * 12 - 6) * s, (18 + random() * 18) * s
    elseif mode == "embers" then
        m.x, m.y = R * sin(a) * 0.9, R * cos(a) * 0.7 - R * 0.15
        m.vx, m.vy = (random() * 16 - 8) * s, (32 + random() * 28) * s
    elseif mode == "drift" then
        m.r0, m.r1 = R * 1.75, R * 1.0
    elseif mode == "orbit" then
        m.r0 = R * (1.18 + random() * 0.12)
        m.av = (1.8 + random() * 1.0)
    elseif mode == "inward" then
        m.r0, m.r1 = R * 1.85, R * 0.25
    elseif mode == "burst" then
        m.x, m.y = R * sin(a), R * cos(a)
        local v = (55 + random() * 35) * s
        m.vx, m.vy = sin(a) * v, cos(a) * v
        m.life = 0.45 + random() * 0.2
    end
    local c = mc.color
    if mc.color2 and random() < 0.5 then c = mc.color2 end
    m.tex:SetTexture(MediaPath(mc.tex or "Glow"))
    m.tex:SetVertexColor(c[1], c[2], c[3], 1)
    SetSize(m.tex, m.size)
    m.tex:Show()
end

local function StartFX(f)
    local fx = f.fx
    if not fx then return end
    HideFX(f)
    if not (M.db and M.db.player.effects ~= false) then return end
    local th = f.theme or THEMES.physical
    local size = f.size or 56
    fx.active = true
    fx.spawnAcc, fx.clock = 0, 0
    local g = th.glow
    fx.aura:SetVertexColor(g[1], g[2], g[3], 0)
    SetSize(fx.aura, size * 1.75)
    fx.aura:Show()
    fx.ringGlow:SetVertexColor(th.color[1], th.color[2], th.color[3], 0)
    SetSize(fx.ringGlow, size * 1.14)
    fx.ringGlow:Show()
    if th.rays then
        local rc = th.rays.color
        fx.rays:SetVertexColor(rc[1], rc[2], rc[3], 0)
        fx.rays:Show()
    end
    fx.shine:SetVertexColor(g[1], g[2], g[3], 0)
    SetSize(fx.shine, size * 0.62)
    fx.shine:Show()
    for i = 1, TRAIL_N do
        local t = fx.trail[i]
        t:SetVertexColor(th.color[1], th.color[2], th.color[3], 0)
        SetSize(t, max(4, size * (0.16 - i * 0.017)))
        t:Show()
    end
end

-- Explosão de luz ao concluir com sucesso
local function BurstFX(f)
    local fx = f.fx
    if not (fx and fx.active) then return end
    local th = f.theme or THEMES.physical
    fx.burstT = 0
    local c = th.glow
    fx.burst:SetVertexColor(th.color[1], th.color[2], th.color[3], 0.9)
    fx.burst:Show()
    fx.flash:SetVertexColor(c[1], c[2], c[3], 0.8)
    fx.flash:Show()
    for i = 1, TRAIL_N do fx.trail[i]:Hide() end
    if th.motes then
        for _ = 1, 10 do SpawnMote(f, "burst") end
    end
end

-- pct = fração decorrida (0..1) enquanto conjura; nil depois do fim
local function UpdateFX(f, elapsed, pct)
    local fx = f.fx
    if not (fx and fx.active) then return end
    local th = f.theme or THEMES.physical
    local size = f.size or 56
    local R = size * 0.5 * (f.radius or RING_RADIUS)
    fx.clock = fx.clock + elapsed
    local pulse = 0.85 + 0.15 * sin(fx.clock * 5)
    local casting = pct ~= nil
    local p = pct or 1
    local fade = casting and 1 or max(0, 1 - (fx.burstT or 0) / 0.45)

    -- aura e brilho do anel crescem com o progresso
    local flick = th.flicker and (0.8 + random() * 0.35) or 1
    local g = th.glow
    fx.aura:SetVertexColor(g[1], g[2], g[3], th.aura * (0.25 + 0.75 * p) * pulse * flick * fade)
    fx.ringGlow:SetVertexColor(th.color[1], th.color[2], th.color[3], (0.15 + 0.45 * p) * pulse * fade)
    fx.shine:SetVertexColor(g[1], g[2], g[3], (th.shine or 0.2) * (0.3 + 0.7 * p) * pulse * fade)

    if th.rays then
        local rc = th.rays
        fx.rayRot = fx.rayRot + rc.speed * elapsed
        if fx.rays.SetRotation then fx.rays:SetRotation(fx.rayRot) end
        local boost = (fx.burstT and (1 + 1.2 * fade)) or 1
        SetSize(fx.rays, size * (1.6 + 0.35 * p) * (fx.burstT and (1 + 0.5 * (1 - fade)) or 1))
        fx.rays:SetVertexColor(rc.color[1], rc.color[2], rc.color[3], min(1, rc.alpha * (0.35 + 0.65 * p) * pulse * boost * fade))
    end

    -- rastro de luz atrás da ponta do arco
    if casting then
        local a = p * 2 * pi
        for i = 1, TRAIL_N do
            local t = fx.trail[i]
            local ai = a - i * 0.075
            if ai < 0 then
                t:Hide()
            else
                t:ClearAllPoints()
                t:SetPoint("CENTER", f.ring, "CENTER", R * sin(ai), R * cos(ai))
                t:SetVertexColor(th.color[1], th.color[2], th.color[3], 0.55 * (1 - i / (TRAIL_N + 1)))
                t:Show()
            end
        end
        -- novas partículas (mais energia perto do fim)
        if th.motes then
            fx.spawnAcc = fx.spawnAcc + elapsed * th.motes.rate * (0.45 + 0.9 * p)
            while fx.spawnAcc >= 1 do
                fx.spawnAcc = fx.spawnAcc - 1
                SpawnMote(f)
            end
        end
    end

    -- explosão final
    if fx.burstT then
        fx.burstT = fx.burstT + elapsed
        local k = min(1, fx.burstT / 0.45)
        SetSize(fx.burst, size * (1.0 + 0.9 * k))
        fx.burst:SetVertexColor(th.color[1], th.color[2], th.color[3], 0.9 * (1 - k))
        SetSize(fx.flash, size * (0.7 + 0.8 * k))
        fx.flash:SetVertexColor(g[1], g[2], g[3], 0.85 * (1 - k) ^ 2)
    end

    -- partículas
    for _, m in ipairs(fx.motes) do
        if m.alive then
            m.t = m.t + elapsed
            local L = m.life
            if m.t >= L then
                m.alive = false
                m.tex:Hide()
            else
                local u = m.t / L
                local x, y
                if m.mode == "drift" or m.mode == "inward" then
                    local r = m.r0 + (m.r1 - m.r0) * (u ^ (m.mode == "inward" and 1.6 or 1))
                    local a = m.ang + (m.mode == "inward" and u * 1.2 or u * 0.3)
                    x, y = r * sin(a), r * cos(a)
                elseif m.mode == "orbit" then
                    m.ang = m.ang + m.av * elapsed
                    local r = m.r0 + sin(m.t * 6) * 2
                    x, y = r * sin(m.ang), r * cos(m.ang)
                else
                    m.x = m.x + m.vx * elapsed + (m.mode == "embers" and sin(m.t * 9 + m.ang) * 0.4 or 0)
                    m.y = m.y + m.vy * elapsed
                    if m.mode == "burst" then m.vx, m.vy = m.vx * 0.94, m.vy * 0.94 end
                    x, y = m.x, m.y
                end
                m.tex:ClearAllPoints()
                m.tex:SetPoint("CENTER", f.ring, "CENTER", x, y)
                local alpha = min(u / 0.2, 1) * min((1 - u) / 0.45, 1)
                if m.mode == "embers" then alpha = alpha * (0.6 + random() * 0.4) end
                m.tex:SetAlpha(alpha)
                if m.spin ~= 0 and m.tex.SetRotation then
                    m.rot = m.rot + m.spin * elapsed
                    m.tex:SetRotation(m.rot)
                end
                if m.mode == "inward" then SetSize(m.tex, m.size * (1 - u * 0.6)) end
            end
        end
    end
end

-- Dois visuais de anel:
--   * clássico (habilidades): faixa larga, filetes dourados, fundo escuro, título serifado;
--   * moderno (interação com objetos): linha fina, trilho translúcido, sem moldura,
--     ícone pequeno num disco escuro, nome em PT Sans e sem o tempo (mais discreto).
local function CreateRing(key, size, parent)
    local c = Azaath.colors
    local modern = (key == "world" or key == "player") -- 12/11: estilo moderno nos dois
    local ringTex = MediaPath(modern and "CastRingThin" or "CastRing")
    local edgeTex = MediaPath("CastRingEdge")
    local glowTex = MediaPath("Glow")

    local f = CreateFrame("Frame", FrameName(key), parent or Azaath.root)
    f.key = key
    f.unit = (key == "world") and "player" or key
    f.isRing = true
    f.modern = modern
    f.radius = modern and (112 / 128) or RING_RADIUS
    f.textH = modern and 16 or RING_TEXT_H
    f:SetFrameStrata(key == "world" and "MEDIUM" or "LOW")
    if key == "world" then f:SetClampedToScreen(true) end

    -- Área do anel (o frame principal inclui o texto embaixo, para o Modo de Edição)
    local ring = CreateFrame("Frame", nil, f)
    ring:SetPoint("TOP", f, "TOP", 0, 0)
    f.ring = ring

    local shadow = ring:CreateTexture(nil, "BACKGROUND", nil, -2)
    shadow:SetTexture(glowTex)
    shadow:SetVertexColor(0, 0, 0, modern and 0.28 or 0.55)
    shadow:SetPoint("CENTER")
    f.shadow = shadow

    local track = ring:CreateTexture(nil, "BACKGROUND", nil, 1)
    track:SetTexture(ringTex)
    track:SetAllPoints(ring)
    if modern then
        track:SetVertexColor(1, 1, 1, 0.16)
    else
        track:SetVertexColor(c.dark[1] * 0.6, c.dark[2] * 0.6, c.dark[3] * 0.6, 0.85)
    end
    f.track = track

    if modern then
        -- Disco escuro atrás do ícone (dá contraste sem moldura)
        local iconBg = ring:CreateTexture(nil, "BACKGROUND", nil, 2)
        iconBg:SetTexture(MediaPath("Disc"))
        iconBg:SetVertexColor(0.04, 0.035, 0.03, 0.7)
        iconBg:SetPoint("CENTER")
        f.iconBg = iconBg
    end

    local cd = CreateFrame("Cooldown", nil, ring, "CooldownFrameTemplate")
    cd:SetAllPoints(ring)
    cd:SetSwipeTexture(ringTex)
    if cd.SetDrawEdge then cd:SetDrawEdge(false) end
    if cd.SetDrawBling then cd:SetDrawBling(false) end
    if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
    if cd.SetDrawSwipe then cd:SetDrawSwipe(true) end
    if cd.SetUseCircularEdge then cd:SetUseCircularEdge(true) end
    cd.noCooldownCount = true -- OmniCC e afins: sem números aqui
    cd:Hide()
    f.cd = cd

    local overlay = CreateFrame("Frame", nil, f)
    overlay:SetAllPoints(ring)
    overlay:SetFrameLevel(cd:GetFrameLevel() + 2)
    f.overlay = overlay

    -- Anel cheio (sucesso/falha e pré-visualização sem Pause)
    local full = overlay:CreateTexture(nil, "BACKGROUND")
    full:SetTexture(ringTex)
    full:SetAllPoints(ring)
    full:Hide()
    f.full = full

    if modern then
        -- Halo suave que acende junto com o anel cheio (fim da coleta)
        local halo = overlay:CreateTexture(nil, "BACKGROUND", nil, -1)
        halo:SetTexture(MediaPath("CastRingHalo"))
        halo:SetBlendMode("ADD")
        halo:SetPoint("CENTER")
        halo:Hide()
        f.halo = halo
    else
        local edge = overlay:CreateTexture(nil, "BORDER")
        edge:SetTexture(edgeTex)
        edge:SetAllPoints(ring)
        f.edge = edge
    end

    -- Ícone redondo no centro
    local icon = overlay:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if overlay.CreateMaskTexture and icon.AddMaskTexture then
        local mask = overlay:CreateMaskTexture()
        mask:SetTexture(MediaPath("Disc"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end
    f.icon = icon

    -- Brilho na ponta do arco
    local spark = overlay:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(glowTex)
    spark:SetBlendMode("ADD")
    spark:Hide()
    f.spark = spark
    local sparkCore = overlay:CreateTexture(nil, "OVERLAY", nil, 1)
    sparkCore:SetTexture(glowTex)
    sparkCore:SetBlendMode("ADD")
    sparkCore:SetVertexColor(1, 1, 1, 0.9)
    sparkCore:SetPoint("CENTER", spark, "CENTER")
    sparkCore:Hide()
    f.sparkCore = sparkCore

    -- Nome e tempo embaixo do anel (centralizados)
    f.text = CreateText(f, 12, "CENTER", modern and Azaath.media.fontBold or Azaath.media.fontTitle)
    f.text:SetPoint("TOP", ring, "BOTTOM", 0, modern and -2 or -3)
    f.text:SetWidth(240)
    f.text:SetHeight(14)
    f.time = CreateText(f, 10, "CENTER", Azaath.media.fontBold)
    f.time:SetPoint("TOP", f.text, "BOTTOM", 0, -1)
    if modern then
        f.text:SetShadowOffset(0, -1)
        f.text:SetShadowColor(0, 0, 0, 1)
        f.time:Hide() -- discreto: só o nome do objeto
    end

    if key == "player" then CreateFX(f) end -- efeitos por escola de magia

    SetBorder(f, false)

    f.holdTime, f.textElapsed = 0, 0
    f:SetScript("OnUpdate", OnUpdate)
    f:Hide()

    bars[key] = f
    return f
end

local function ApplyRingSize(f, size, scale)
    f:SetScale((scale and scale > 0) and scale or 1)
    f.size = size
    f:SetWidth(size)
    f:SetHeight(size + f.textH)
    f.ring:SetWidth(size)
    f.ring:SetHeight(size)
    if f.modern then
        f.shadow:SetWidth(size * 1.2)
        f.shadow:SetHeight(size * 1.2)
        f.icon:SetWidth(size * 0.46)
        f.icon:SetHeight(size * 0.46)
        f.iconBg:SetWidth(size * 0.72)
        f.iconBg:SetHeight(size * 0.72)
        f.halo:SetWidth(size * 1.12)
        f.halo:SetHeight(size * 1.12)
        local s = max(8, size * 0.26)
        f.spark:SetWidth(s)
        f.spark:SetHeight(s)
        f.sparkCore:SetWidth(s * 0.35)
        f.sparkCore:SetHeight(s * 0.35)
        f.text:SetFont(Azaath.media.fontBold, size >= 52 and 11 or 10, "")
        return
    end
    f.shadow:SetWidth(size * 1.35)
    f.shadow:SetHeight(size * 1.35)
    f.icon:SetWidth(size * 0.56)
    f.icon:SetHeight(size * 0.56)
    local s = max(10, size * 0.30)
    f.spark:SetWidth(s)
    f.spark:SetHeight(s)
    f.sparkCore:SetWidth(s * 0.4)
    f.sparkCore:SetHeight(s * 0.4)
    local nameSize = size >= 64 and 13 or 11
    f.text:SetFont(Azaath.media.fontTitle, nameSize, "OUTLINE")
    f.time:SetFont(Azaath.media.fontBold, nameSize - 2, "OUTLINE")
end

--------------------------------------------------------------------------------
-- Visual (barra ou anel)
--------------------------------------------------------------------------------
local function CooldownClear(cd)
    if cd.Clear then cd:Clear() else cd:SetCooldown(0, 0) end
    cd:Hide()
end

local function ViewColor(f, c)
    if f.isRing then
        f.cd:SetSwipeColor(c[1], c[2], c[3], 1)
        f.full:SetVertexColor(c[1], c[2], c[3], 1)
        f.spark:SetVertexColor(c[1], c[2], c[3], 0.9)
    else
        f.bar:SetStatusBarColor(c[1], c[2], c[3])
    end
end

-- Início (ou novos tempos após atraso): bar = escala; anel = Cooldown
local function ViewRange(f)
    if f.isRing then
        f.full:Hide()
        if f.halo then f.halo:Hide() end
        f.cd:SetReverse(not f.channeling) -- conjuração enche, canalização esvazia
        f.cd:Show()
        f.cd:SetCooldown(f.startTime, f.duration)
        if f.cd.Resume then pcall(f.cd.Resume, f.cd) end
    else
        f.bar:SetMinMaxValues(0, f.duration)
    end
end

-- Ponta do progresso. value = decorrido (conjuração) ou restante (canalização)
local function ViewValue(f, value)
    local pct = value / f.duration
    if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
    if f.isRing then
        local elapsedPct = f.channeling and (1 - pct) or pct
        local a = elapsedPct * 2 * pi -- horário a partir do topo
        local r = (f.size or 64) * 0.5 * (f.radius or RING_RADIUS)
        f.spark:ClearAllPoints()
        f.spark:SetPoint("CENTER", f.ring, "CENTER", r * sin(a), r * cos(a))
        -- O Cooldown some ao terminar; até o STOP chegar, mantém o anel cheio
        if f.casting and pct >= 0.995 then f.full:Show() end
    else
        f.bar:SetValue(value)
        f.spark:SetPoint("CENTER", f.bar, "LEFT", pct * f.bar:GetWidth(), 0)
    end
end

local function ViewSpark(f, show)
    if show then
        f.spark:Show()
        if f.sparkCore then f.sparkCore:Show() end
    else
        f.spark:Hide()
        if f.sparkCore then f.sparkCore:Hide() end
    end
end

-- Fim: tudo cheio na cor dada
local function ViewFull(f, c)
    if f.isRing then
        CooldownClear(f.cd)
        f.full:SetVertexColor(c[1], c[2], c[3], 1)
        f.full:Show()
        if f.halo then f.halo:SetVertexColor(c[1], c[2], c[3], 0.55); f.halo:Show() end
    else
        f.bar:SetValue(f.duration)
        f.bar:SetStatusBarColor(c[1], c[2], c[3])
    end
end

--------------------------------------------------------------------------------
-- Estado
--------------------------------------------------------------------------------
local function ApplyColor(f)
    local c
    if f.notInterruptible and not f.fx then c = COLORS.shielded
    elseif f.key == "world" then c = COLORS.world
    elseif f.fx and f.theme and M.db.player.effects ~= false then c = f.theme.color
    elseif f.channeling then c = COLORS.channel
    else c = COLORS.cast end
    ViewColor(f, c)
    SetBorder(f, f.notInterruptible)
end

local function UpdateSafeZone(f)
    local safe = f.safe
    if not safe then return end
    if not (f.casting and M.db.player.showLatency) then
        safe:Hide()
        return
    end
    local _, _, latency = GetNetStats()
    local width = f.bar:GetWidth()
    local w = width * min((latency or 0) / 1000 / f.duration, 1)
    if w >= 1 then
        safe:SetWidth(w)
        safe:Show()
    else
        safe:Hide()
    end
end

local function ShowEditPreview(f)
    if not f or f.key == "world" then return end
    f.isEditPreview = true
    f.casting, f.channeling, f.fadeOut, f.isTest = false, false, false, false
    f.holdTime = 0
    f.duration = 2.0
    f.notInterruptible = (f.key == "target")
    f.text:SetText(f.key == "target" and "Conjuração do Alvo" or "Conjuração")
    f.time:SetText("1.4")
    f.icon:SetTexture(TEST_ICON)
    if f.fx then
        f.theme = ResolveTheme(nil, "") -- escola padrão da classe
        StartFX(f)
    end
    ApplyColor(f)
    if f.isRing then
        -- 65% parado: Cooldown pausado quando o cliente permite; senão, anel cheio
        local cd = f.cd
        cd:SetReverse(true)
        cd:Show()
        cd:SetCooldown(GetTime() - 1.3, 2.0)
        if cd.Pause then
            pcall(cd.Pause, cd)
            f.full:Hide()
        else
            CooldownClear(cd)
            f.full:Show()
        end
        ViewValue(f, 1.3)
        if f.fx then UpdateFX(f, 0, 0.65) end
    else
        f.bar:SetMinMaxValues(0, 1)
        f.bar:SetValue(0.65)
        f.spark:SetPoint("CENTER", f.bar, "LEFT", 0.65 * f.bar:GetWidth(), 0)
    end
    if f.safe then f.safe:Hide() end
    ViewSpark(f, true)
    f:SetAlpha(1)
    f:Show()
end

local function Reset(f)
    f.casting, f.channeling, f.fadeOut, f.isTest = false, false, false, false
    f.holdTime = 0
    f.anchorGUID, f.plate = nil, nil -- solta a placa do objeto
    if f.isRing then
        CooldownClear(f.cd)
        f.full:Hide()
        if f.halo then f.halo:Hide() end
        HideFX(f)
    end
    if M.editing and M.db and M.db[f.key] and M.db[f.key].enabled and f.key ~= "world" then
        ShowEditPreview(f)
        return
    end
    f.isEditPreview = false
    f:Hide()
end

-- Lê UnitCastingInfo/UnitChannelInfo e inicia a barra. Retorna true se há conjuração.
local function StartCast(f, channel)
    if f.key == "target" and Azaath.BDOTargetBox and Azaath.IsBDO and Azaath.IsBDO() then return false end -- skin Zerker
    -- Compat normaliza as assinaturas (3.3.5 e cliente moderno)
    local name, text, texture, startMS, endMS, castID, notInterruptible
    if channel then
        name, text, texture, startMS, endMS, castID, notInterruptible = Azaath.API.ChannelInfo(f.unit)
    else
        name, text, texture, startMS, endMS, castID, notInterruptible = Azaath.API.CastingInfo(f.unit)
    end
    -- Valores secretos (cliente moderno, ex.: conjurações de outras unidades):
    -- sem contas com os tempos não dá para animar a barra -> não mostra.
    if Azaath.AnySecret(name, startMS, endMS) then return false end
    if Azaath.IsSecret(notInterruptible) then notInterruptible = nil end
    if Azaath.IsSecret(text) then text = name end
    if Azaath.IsSecret(castID) then castID = nil end
    if Azaath.IsSecret(texture) then texture = nil end
    if not name then return false end

    f.isEditPreview = false
    f.startTime = startMS / 1000
    f.endTime = endMS / 1000
    f.duration = max(f.endTime - f.startTime, 0.001)
    f.casting, f.channeling = not channel, channel and true or false
    f.castID = castID
    f.notInterruptible = notInterruptible and true or false
    f.holdTime, f.fadeOut, f.isTest = 0, false, false
    f.textElapsed = TEXT_INTERVAL -- força atualizar o texto no próximo frame

    ViewRange(f)
    if not f.isRing then f.bar:SetValue(channel and f.duration or 0) end
    -- Anel do objeto: nome do objeto ("Pedaço de Âmbar Grande"), não do feitiço ("Mineração")
    f.text:SetText((f.key == "world" and f.objName) or (text ~= "" and text or name))
    f.time:SetText("")
    f.icon:SetTexture(texture or TEST_ICON)
    if f.fx then
        f.theme = ResolveTheme(CurrentSpellID(f.unit, channel), name)
        StartFX(f)
    end
    ApplyColor(f)
    UpdateSafeZone(f)
    ViewValue(f, channel and f.duration or 0)
    ViewSpark(f, true)
    f:SetAlpha(1)
    f:Show()
    return true
end

local function RefreshTimes(f)
    local name, _, _, startMS, endMS
    if f.channeling then
        name, _, _, startMS, endMS = Azaath.API.ChannelInfo(f.unit)
    else
        name, _, _, startMS, endMS = Azaath.API.CastingInfo(f.unit)
    end
    if Azaath.AnySecret(name, startMS, endMS) or not name then return end
    f.startTime = startMS / 1000
    f.endTime = endMS / 1000
    f.duration = max(f.endTime - f.startTime, 0.001)
    ViewRange(f)
    UpdateSafeZone(f)
end

local function Finish(f, success)
    f.casting, f.channeling = false, false
    ViewSpark(f, false)
    if f.safe then f.safe:Hide() end
    f.time:SetText("")
    if success and f.fx and f.fx.active then
        -- conjuração temática: anel cheio na cor da escola + explosão de luz
        ViewFull(f, f.theme and f.theme.color or COLORS.success)
        BurstFX(f)
        f.holdTime = 0.25 -- deixa a explosão aparecer antes do fade
        f.fadeOut = true
        return
    end
    if success then
        ViewFull(f, COLORS.success)
    elseif f.isRing then
        CooldownClear(f.cd) -- canalização terminou: anel vazio
    end
    f.holdTime = 0
    f.fadeOut = true
end

local function Fail(f, interrupted)
    f.casting, f.channeling = false, false
    ViewSpark(f, false)
    if f.safe then f.safe:Hide() end
    HideFX(f) -- a magia se desfaz
    ViewFull(f, COLORS.failed)
    f.text:SetText(interrupted and "Interrompido" or "Falhou")
    f.time:SetText("")
    f.holdTime = FAIL_HOLD
    f.fadeOut = true
end

local function Refresh(f)
    if f.key == "world" then
        -- O anel do mundo só nasce de uma interação nova (SENT -> START)
        if not (f.casting or f.channeling) then Reset(f) end
        return
    end
    if not UnitExists(f.unit) then
        Reset(f)
        return
    end
    if not StartCast(f, false) and not StartCast(f, true) then
        Reset(f)
    end
end

-- O evento pertence à conjuração atual? (castID quando disponível)
local function IsCurrentCast(f, castID)
    -- número (3.3.5) ou GUID em texto (cliente moderno); sem ID, aceita
    return not (f.castID and castID ~= nil and castID ~= f.castID)
end

--------------------------------------------------------------------------------
-- OnUpdate (só roda com a barra visível)
--------------------------------------------------------------------------------
local TrackWorld -- definido em "Interação com objetos do mundo"

OnUpdate = function(f, elapsed)
    if f.anchorGUID and TrackWorld then
        f.trackElapsed = (f.trackElapsed or 0) + elapsed
        if f.trackElapsed >= 0.1 then
            f.trackElapsed = 0
            TrackWorld(f)
        end
    end
    if f.casting or f.channeling then
        local now = GetTime()
        local value
        if f.casting then
            value = now - f.startTime
            if value > f.duration then value = f.duration end -- espera o evento STOP
            if f.isTest and now >= f.endTime then
                Finish(f, true)
                return
            end
        else
            value = f.endTime - now
            if value < 0 then value = 0 end
        end
        ViewValue(f, value)
        if f.fx then
            local p = (now - f.startTime) / f.duration
            UpdateFX(f, elapsed, p < 0 and 0 or (p > 1 and 1 or p))
        end

        f.textElapsed = f.textElapsed + elapsed
        if f.textElapsed >= TEXT_INTERVAL then
            f.textElapsed = 0
            f.time:SetText(format("%.1f", max(f.endTime - now, 0)))
        end
    elseif f.holdTime > 0 then
        f.holdTime = f.holdTime - elapsed
        if f.fx then UpdateFX(f, elapsed, nil) end
    elseif f.fadeOut then
        if f.fx then UpdateFX(f, elapsed, nil) end
        local a = f:GetAlpha() - elapsed / FADE_TIME
        if a <= 0 then
            Reset(f)
        else
            f:SetAlpha(a)
        end
    elseif f.isEditPreview and M.editing then
        -- Mantém visível como pré-visualização durante o modo de edição
        return
    else
        f:Hide()
    end
end

--------------------------------------------------------------------------------
-- Interação com objetos do mundo
--------------------------------------------------------------------------------
local sent = { guid = nil, spellID = nil, target = nil, time = 0 }

-- O nome é de alguma unidade por perto (alvo, mouseover, grupo...)?
local UNIT_TOKENS = { "player", "target", "mouseover", "focus", "pet", "softenemy", "softfriend", "vehicle" }
local function IsUnitName(name)
    -- O SENT pode trazer o nome com o reino ("Maraath Il", "Nome-Reino"):
    -- conta como a unidade se for igual ou começar pelo nome + espaço/hífen.
    local function same(u)
        if not UnitExists(u) then return false end
        local ok, n = pcall(UnitName, u)
        n = ok and Plain(n)
        if not n then return false end
        if n == name then return true end
        local c = name:sub(#n + 1, #n + 1)
        return name:sub(1, #n) == n and (c == " " or c == "-")
    end
    for _, u in ipairs(UNIT_TOKENS) do
        if same(u) then return true end
    end
    local inRaid = _G.IsInRaid and IsInRaid()
    local n = (_G.GetNumGroupMembers and GetNumGroupMembers()) or 0
    for i = 1, min(n, 40) do
        if same(inRaid and ("raid" .. i) or ("party" .. i)) then return true end
    end
    return false
end

local function IsKnownSpell(spellID)
    if not spellID then return false end
    if _G.IsPlayerSpell then
        local ok, v = pcall(IsPlayerSpell, spellID)
        if ok and v and not Azaath.IsSecret(v) then return true end
    end
    if _G.C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        local ok, v = pcall(C_SpellBook.IsSpellInSpellBook, spellID)
        if ok and v and not Azaath.IsSecret(v) then return true end
    end
    return false
end

local function IsInteraction(spellID, target)
    BuildInteractSets()
    if Azaath.IsSecret(spellID) then spellID = nil end
    if spellID then
        if interactIDs[spellID] then return true end
        local n = Plain(SpellName(spellID))
        if n and interactNames[n] then return true end
    end
    -- O feitiço tem um alvo com nome que não é unidade: é um objeto. Só vale para
    -- feitiços fora do livro (Usar/Coletar de missão); habilidades do livro
    -- (curativo, Bola de Fogo...) são sempre em unidades. Coleta já veio da lista.
    target = Plain(target)
    if target and not IsKnownSpell(spellID) and not IsUnitName(target) then return true end
    -- Sem nome de alvo: objeto sob o cursor + feitiço fora do livro (Usar, Coletar...)
    if not target and hoverObj.shown and spellID and not IsKnownSpell(spellID) then
        return true
    end
    return false
end

-- Onde desenhar o anel: posição do cursor sobre o objeto (pixels de tela) ou nil
local function ObjectScreenPos(target)
    TrackTooltip()
    target = Plain(target)
    local recent = hoverObj.name and (hoverObj.shown or GetTime() - hoverObj.seen <= OBJECT_MEMORY)
    if recent and (not target or hoverObj.name == target) then
        if hoverObj.shown and MouseOverWorld() then
            return GetCursorPosition()
        end
        return hoverObj.x, hoverObj.y
    end
    return nil
end

-- Posição fixa na tela (cursor sobre o objeto ou centro): só quando não há placa
local function PlaceWorldRing(f, x, y)
    local cfg = M.db.world
    f:ClearAllPoints()
    if x then
        local s = f:GetEffectiveScale()
        f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s - (f.textH or RING_TEXT_H) / 2)
    else
        f:SetPoint("CENTER", UIParent, "CENTER", cfg.fallbackX or 0, cfg.fallbackY or -20)
    end
end

--------------------------------------------------------------------------------
-- Anel PRESO ao objeto: placa de interação ("softinteract")
--------------------------------------------------------------------------------
-- Com SoftTargetNameplateInteract=1 (ligado pelo LootBeam e aqui) o motor
-- moderno cria uma placa de nome também para o objeto de interação (baú,
-- minério, erva) e a move a cada quadro junto com o objeto. Medir a placa é
-- proibido ("restricted region"), mas ANCORAR nela funciona: o anel passa a
-- seguir o objeto quando a câmera gira ou o personagem anda.
-- Esfolar usa o corpo (alvo/mouseover), que também tem placa.
local OBJECT_UNITS = { "softinteract", "mouseover", "target" }

local function SafeGUID(unit)
    if not _G.UnitGUID then return nil end
    local ok, g = pcall(UnitGUID, unit)
    if not ok or Azaath.IsSecret(g) or type(g) ~= "string" then return nil end
    return g
end

local function SafeUnitName(unit)
    local ok, n = pcall(UnitName, unit)
    return ok and Plain(n) or nil
end

local function PlateFor(unit)
    if not (_G.C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and plate and not Azaath.IsSecret(plate) then return plate end
    return nil
end

-- Unidade que hoje tem o GUID dado (a placa muda de token quando o alvo troca)
local function UnitWithGUID(guid)
    for _, u in ipairs(OBJECT_UNITS) do
        if SafeGUID(u) == guid then return u end
    end
    return nil
end

-- Procura a placa do objeto da interação. Prioridade: o "softinteract" do
-- momento do SENT (mesmo GUID), depois quem tiver o nome do alvo do feitiço.
local function FindObjectPlate(target, sentGUID)
    if sentGUID then
        local u = UnitWithGUID(sentGUID)
        local plate = u and PlateFor(u)
        if plate then return plate, u, sentGUID end
    end
    for _, u in ipairs(OBJECT_UNITS) do
        local guid = SafeGUID(u)
        if guid then
            local name = SafeUnitName(u)
            -- sem nome de alvo, só a retícula de interação vale (não um mob qualquer)
            local match = (target and name == target) or (not target and u == "softinteract")
            if match then
                local plate = PlateFor(u)
                if plate then return plate, u, guid end
            end
        end
    end
    return nil
end

local function AnchorToPlate(f, plate)
    f:ClearAllPoints()
    -- a placa fica acima do objeto; plateOffsetY negativo desce o anel ao centro do item
    f:SetPoint("CENTER", plate, "CENTER", 0, (M.db.world.plateOffsetY or -45) - (f.textH or RING_TEXT_H) / 2)
    f.plate = plate
end

-- Chamado no OnUpdate do anel do mundo: a placa pode ser reciclada/trocar de token
TrackWorld = function(f)
    local guid = f.anchorGUID
    if not guid then return end
    local unit = UnitWithGUID(guid)
    local plate = unit and PlateFor(unit)
    if plate then
        if plate ~= f.plate then
            -- a placa apareceu depois do início: anota no diagnóstico
            if not f.plate and (f.casting or f.channeling) then
                local d = type(AzaathUIDB) == "table" and AzaathUIDB.castDiag
                if type(d) == "table" and d[1] then d[1].lateAnchor = unit end
            end
            AnchorToPlate(f, plate)
        end
    elseif f.plate then
        -- objeto saiu da tela / retícula mudou: volta para a posição fixa
        f.plate = nil
        PlaceWorldRing(f, f.staticX, f.staticY)
    end
end

local function CVarValue(name)
    local get = (_G.C_CVar and C_CVar.GetCVar) or _G.GetCVar
    if not get then return "?" end
    local ok, v = pcall(get, name)
    return ok and tostring(v) or "erro"
end

-- Diagnóstico: as últimas interações ficam em AzaathUIDB.castDiag (/reload grava)
local function RecordDiag(spellID, target, plateUnit)
    if type(AzaathUIDB) ~= "table" then return end
    local units = {}
    for _, u in ipairs(OBJECT_UNITS) do
        local guid = SafeGUID(u)
        if guid then
            local isObj
            if _G.UnitIsGameObject then
                local ok, v = pcall(UnitIsGameObject, u)
                isObj = ok and not Azaath.IsSecret(v) and v or nil
            end
            units[#units + 1] = format("%s | %s | %s | objeto=%s | placa=%s", u, tostring(SafeUnitName(u)),
                guid:match("^[^-]+") or "?", tostring(isObj), tostring(PlateFor(u) ~= nil))
        end
    end
    local diag = AzaathUIDB.castDiag
    if type(diag) ~= "table" then diag = {}; AzaathUIDB.castDiag = diag end
    table.insert(diag, 1, {
        time = date and date("%H:%M:%S") or "",
        spell = format("%s (%s)", tostring(Plain(SpellName(spellID))), tostring(spellID)),
        target = tostring(target),
        anchored = plateUnit or "nenhuma placa (posição fixa)",
        sentSoft = tostring(sent.softGUID),
        units = units,
        cvars = format("IconGameObject=%s IconInteract=%s NameplateInteract=%s Interact=%s",
            CVarValue("SoftTargetIconGameObject"), CVarValue("SoftTargetIconInteract"),
            CVarValue("SoftTargetNameplateInteract"), CVarValue("SoftTargetInteract")),
    })
    while #diag > 6 do table.remove(diag) end
end

-- START do jogador: se o SENT anterior foi uma interação, a conjuração vai para o anel do mundo
local function ClaimWorldCast(castGUID, spellID)
    local world = bars.world
    if not (world and M.db.world.enabled) then return false end
    if not sent.guid and not sent.spellID then return false end
    if GetTime() - sent.time > SENT_WINDOW then return false end
    if Azaath.IsSecret(castGUID) then castGUID = nil end
    if castGUID and sent.guid and castGUID ~= sent.guid then return false end
    local id = sent.spellID or spellID
    if not IsInteraction(id, sent.target) then return false end

    world.staticX, world.staticY = sent.x, sent.y
    local plate, unit, guid = FindObjectPlate(sent.target, sent.softGUID)
    -- Nome do objeto: alvo do SENT, senão a unidade da placa / retícula, senão a dica
    world.objName = sent.target
        or (unit and SafeUnitName(unit))
        or (sent.softGUID and SafeUnitName("softinteract"))
        or (hoverObj.shown and hoverObj.name)
        or nil
    -- Sem placa agora, continua procurando pelo GUID do objeto durante a coleta
    world.anchorGUID, world.plate, world.trackElapsed = guid or sent.softGUID, nil, 0
    if plate then
        AnchorToPlate(world, plate)
    else
        PlaceWorldRing(world, sent.x, sent.y)
    end
    RecordDiag(id, sent.target, unit)
    return true
end

-- Garante as placas de interação (o LootBeam também liga; aqui vale mesmo sem ele)
local function EnsureInteractPlates()
    if not (M.db and M.db.world and M.db.world.enabled) then return end
    if InCombatLockdown and InCombatLockdown() then return end
    local get = (_G.C_CVar and C_CVar.GetCVar) or _G.GetCVar
    local set = (_G.C_CVar and C_CVar.SetCVar) or _G.SetCVar
    if not (get and set) then return end
    local ok, v = pcall(get, "SoftTargetNameplateInteract")
    if ok and v ~= nil and v ~= "1" then pcall(set, "SoftTargetNameplateInteract", "1") end
    ok, v = pcall(get, "SoftTargetInteract")
    if ok and v == "0" then pcall(set, "SoftTargetInteract", "3") end
    -- Diagnóstico de 12/11: "softinteract" era GameObject mas SEM placa. O motor
    -- só cria placa para objeto quando o ícone de interação de objetos está ligado
    -- (a placa existe para desenhar esse ícone).
    ok, v = pcall(get, "SoftTargetIconGameObject")
    if ok and v ~= nil and v ~= "1" then pcall(set, "SoftTargetIconGameObject", "1") end
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local function HandleCastEvent(f, event, claimWorld, ...)
    -- ... = (castGUID, spellID) no cliente moderno · (nome, posto, castID) na 3.3.5
    local castID = Azaath.API.EventCastID(...)
    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
        -- O anel do mundo e a barra do jogador dividem a unidade "player"
        if f.key == "world" then
            if not claimWorld then return end
        elseif f.key == "player" and claimWorld then
            return
        end
        StartCast(f, event == "UNIT_SPELLCAST_CHANNEL_START")

    elseif event == "UNIT_SPELLCAST_STOP" then
        if f.casting and IsCurrentCast(f, castID) then
            Finish(f, true)
        end

    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        if f.casting and IsCurrentCast(f, castID) then
            -- FAILED de outra tentativa enquanto a conjuração atual continua: ignora
            if event == "UNIT_SPELLCAST_FAILED" and Azaath.API.CastingInfo(f.unit) then return end
            Fail(f, event == "UNIT_SPELLCAST_INTERRUPTED")
        elseif f.channeling and event == "UNIT_SPELLCAST_INTERRUPTED" then
            Fail(f, true)
        end

    elseif event == "UNIT_SPELLCAST_DELAYED" then
        if f.casting then RefreshTimes(f) end

    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" then
        if f.channeling then RefreshTimes(f) end

    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" then
        if f.channeling then Finish(f, false) end

    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        if f.casting or f.channeling then
            f.notInterruptible = (event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
            ApplyColor(f)
        end
    end
end

local CAST_EVENTS = {
    "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED",
    "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_DELAYED",
    "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_CHANNEL_STOP",
    "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
}

local function UpdatePlayerUnit()
    local f = bars.player
    if not f then return end
    local unit = (UnitHasVehicleUI and UnitHasVehicleUI("player")) and "vehicle" or "player"
    if unit ~= f.unit then
        f.unit = unit
        Refresh(f)
    end
end

local function OnSent(unit, ...)
    if unit ~= "player" then return end
    -- moderno: (alvo, castGUID, spellID) · 3.3.5: (feitiço, posto, alvo[, castID])
    local target, guid, spellID
    if Azaath.IS_MODERN then
        target, guid, spellID = ...
    else
        target = select(3, ...)
        guid = select(4, ...)
    end
    if Azaath.IsSecret(guid) then guid = nil end
    if Azaath.IsSecret(spellID) then spellID = nil end
    sent.guid, sent.spellID, sent.target, sent.time = guid, spellID, Plain(target), GetTime()
    sent.x, sent.y = ObjectScreenPos(sent.target)
    EnsureInteractPlates() -- só grava se outro addon mudou
    -- Objeto na retícula de interação agora (a placa dele é a âncora preferida)
    sent.softGUID = SafeGUID("softinteract")
    if sent.softGUID and sent.target and SafeUnitName("softinteract") ~= sent.target then
        sent.softGUID = nil -- a retícula está em outra coisa (clicou num objeto diferente)
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit, ...)
    if event == "PLAYER_TARGET_CHANGED" then
        if bars.target then Refresh(bars.target) end
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if unit == "player" then UpdatePlayerUnit() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdatePlayerUnit()
        for _, f in pairs(bars) do Refresh(f) end
        EnsureInteractPlates() -- depois dos outros addons aplicarem os CVars deles
    elseif event == "UNIT_SPELLCAST_SENT" then
        OnSent(unit, ...)
    else
        local claimWorld = false
        if unit == "player" and (event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START") then
            local guid, spellID = ...
            if not Azaath.IS_MODERN then guid, spellID = Azaath.API.EventCastID(...), nil end
            if Azaath.IsSecret(guid) then guid = nil end
            if Azaath.IsSecret(spellID) then spellID = nil end
            claimWorld = ClaimWorldCast(guid, spellID)
            sent.guid, sent.spellID = nil, nil -- cada SENT vale para um START
        end
        for _, f in pairs(bars) do
            if f.unit == unit then
                HandleCastEvent(f, event, claimWorld, ...)
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
local eventsRegistered = false
local function EnsureCastEvents()
    if eventsRegistered then return end
    eventsRegistered = true
    for _, e in pairs(CAST_EVENTS) do
        Azaath.SafeRegister(events, e)
    end
    Azaath.SafeRegister(events, "UNIT_SPELLCAST_SENT")
    Azaath.SafeRegister(events, "PLAYER_TARGET_CHANGED")
    Azaath.SafeRegister(events, "PLAYER_ENTERING_WORLD")
    Azaath.SafeRegister(events, "UNIT_ENTERED_VEHICLE")
    Azaath.SafeRegister(events, "UNIT_EXITED_VEHICLE")
end

local function ApplyBarGeometry(f, width, height, scale)
    f:SetScale((scale and scale > 0) and scale or 1)
    f:SetWidth(width)
    f:SetHeight(height)
    if f.gloss then f.gloss:SetHeight(floor(height / 2)) end
    if f.spark then f.spark:SetHeight(height * 2.2) end
    if f.iconFrame then
        f.iconFrame:SetWidth(height + 4)
        f.iconFrame:SetHeight(height + 4)
    end
    local fontSize = height >= 14 and 11 or 9
    if f.time then f.time:SetFont(Azaath.media.font, fontSize, "OUTLINE") end
    if f.text then
        f.text:SetFont(Azaath.media.font, fontSize, "OUTLINE")
        f.text:SetHeight(fontSize + 2)
    end
end

-- Estilo do jogador: "ring" (espiral Azaath) ou "bar"
function M:PlayerUsesRing()
    local cfg = self.db and self.db.player
    return cfg and cfg.style ~= "bar" and RingSupported()
end

function M:ApplyLayout()
    local db = self.db
    if not db then return end

    if db.player.enabled and not bars.player then
        if self:PlayerUsesRing() then
            CreateRing("player", db.player.ringSize or 56)
        else
            CreateLinearBar("player", db.player.width or 300, db.player.height or 14, true)
        end
        if Azaath.DisableBlizzardFrame then
            Azaath.DisableBlizzardFrame("CastingBarFrame")
            Azaath.DisableBlizzardFrame("PlayerCastingBarFrame")
        end
    end
    if bars.player then
        local cfg = db.player
        local f = bars.player
        if not cfg.enabled then
            Reset(f)
        else
            if f.isRing then
                ApplyRingSize(f, cfg.ringSize or 56, cfg.scale)
            else
                ApplyBarGeometry(f, cfg.width or 300, cfg.height or 14, cfg.scale)
            end
            f:ClearAllPoints()
            local anchor = _G.AzaathUIPlayer
            if not anchor or not anchor:IsShown() then
                f:SetPoint("BOTTOM", Azaath.root, "BOTTOM", cfg.offsetX or 0, 180 + (cfg.offsetY or 0))
            else
                -- HUD Azaath: os buffs ficam logo acima da vida; a conjuração sobe acima deles
                local hudLift = (Azaath.IsHudLayout and Azaath.IsHudLayout()) and 50 or 0
                f:SetPoint("BOTTOM", anchor, "TOP", cfg.offsetX or 0, (cfg.offsetY or 18) + hudLift)
            end
            if Azaath.ClampToScreen then Azaath.ClampToScreen(f) end
            if self.editing and not (f.casting or f.channeling) then
                ShowEditPreview(f)
            end
        end
    end

    -- Anel sobre objetos do mundo (baús, minérios, ervas...)
    local wcfg = db.world
    if wcfg and wcfg.enabled and db.player.enabled and not bars.world and RingSupported() then
        CreateRing("world", wcfg.size or 44, UIParent)
        HookTooltip()
    end
    EnsureInteractPlates()
    if bars.world then
        local f = bars.world
        if not (wcfg and wcfg.enabled and db.player.enabled) then
            Reset(f)
        else
            ApplyRingSize(f, wcfg.size or 44, 1)
        end
    end

    if db.target.enabled and not bars.target then
        local anchor = _G.AzaathUITarget
        local width = (db.target.width and db.target.width > 0) and db.target.width or (anchor and anchor:GetWidth()) or 300
        CreateLinearBar("target", width, db.target.height or 12, false)
    end
    if bars.target then
        local cfg = db.target
        local f = bars.target
        if not cfg.enabled then
            f.isEditPreview = false
            f:Hide()
        else
            local bz = Azaath.IsBDO and Azaath.IsBDO() and Azaath.BDOTargetBox -- skin Zerker: acompanha as barras do quadro
            local anchor = (bz and _G.AzaathUIBDOTarget) or _G.AzaathUITarget
            local width = (cfg.width and cfg.width > 0) and cfg.width or (bz and bz.barW) or (anchor and anchor:GetWidth()) or 300
            ApplyBarGeometry(f, width, cfg.height or 12, cfg.scale)
            f:ClearAllPoints()
            if anchor and bz then
                f:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", bz.barX + (cfg.offsetX or 0), (cfg.offsetY or -8) - 14 + bz.gap)
            elseif anchor then
                f:SetPoint("TOP", anchor, "BOTTOM", cfg.offsetX or 0, cfg.offsetY or -8)
            else
                f:SetPoint("TOP", Azaath.root, "TOP", cfg.offsetX or 0, -110 + (cfg.offsetY or 0))
            end
            if Azaath.ClampToScreen then Azaath.ClampToScreen(f) end
            if self.editing and not (f.casting or f.channeling) then
                ShowEditPreview(f)
            end
        end
    end

    if next(bars) then
        EnsureCastEvents()
    end
    local auras = Azaath:GetModule("Auras")
    if auras and auras.ApplyLayout then auras:ApplyLayout() end
end

function M:SetEditing(editing)
    self.editing = editing and true or false
    for key, f in pairs(bars) do
        local cfg = self.db and self.db[key]
        if key ~= "world" and self.editing and cfg and cfg.enabled then
            if not (f.casting or f.channeling) then
                ShowEditPreview(f)
            end
        else
            f.isEditPreview = false
            Refresh(f)
        end
    end
end

function M:OnInitialize()
    self.db = Azaath.db.castbar
    -- Anel moderno do objeto (12/11): o tamanho antigo padrão (64) vira o novo (44)
    local w = self.db.world
    if w and not w.modernV1 then
        if w.size == 64 or w.size == nil then w.size = 44 end
        w.modernV1 = true
    end
    -- Anel do objeto (20/11): tamanho 44→54, posição centralizada no item (plateOffsetY=-45)
    if w and not w.modernV2 then
        if w.size == 44 then w.size = 54 end
        if not w.plateOffsetY or w.plateOffsetY == 0 then w.plateOffsetY = -45 end
        w.modernV2 = true
    end
    -- Anel moderno das habilidades: o padrão antigo (72) vira o novo (56),
    -- também nas cópias de geometria de cada skin/disposição (layoutProfiles)
    local p = self.db.player
    if p and not p.modernV1 then
        if p.ringSize == 72 or p.ringSize == nil then p.ringSize = 56 end
        local profiles = type(AzaathUIDB) == "table" and AzaathUIDB.layoutProfiles
        if type(profiles) == "table" then
            for _, prof in pairs(profiles) do
                local geo = type(prof) == "table" and prof["castbar.player"]
                if type(geo) == "table" and geo.ringSize == 72 then geo.ringSize = 56 end
            end
        end
        p.modernV1 = true
    end
end

function M:OnEnable()
    self:ApplyLayout()
end

-- /azaath cast: conjuração falsa de 3s em todas as barras, para posicionamento.
-- O anel do mundo aparece no cursor (ou no centro, se o cursor estiver sobre a interface).
local TEST_SCHOOLS = {
    luz = "holy", sagrado = "holy", holy = "holy", fogo = "fire", fire = "fire",
    gelo = "frost", frost = "frost", arcano = "arcane", arcane = "arcane",
    sombra = "shadow", shadow = "shadow", vil = "fel", fel = "fel",
    natureza = "nature", nature = "nature", fisico = "physical", physical = "physical",
}
function M:Test(arg)
    if not next(bars) then
        Azaath:Print("nenhuma barra de conjuração ativa.")
        return
    end
    local testSchool = type(arg) == "string" and TEST_SCHOOLS[arg:lower():match("^%s*(%S*)")] or nil
    local now = GetTime()
    for key, f in pairs(bars) do
        f.startTime, f.endTime, f.duration = now, now + 3, 3
        f.casting, f.channeling, f.isTest = true, false, true
        f.isEditPreview = false
        f.castID, f.notInterruptible = nil, (key == "target")
        f.holdTime, f.fadeOut, f.textElapsed = 0, false, TEXT_INTERVAL
        if key == "world" then
            if MouseOverWorld() then
                PlaceWorldRing(f, GetCursorPosition())
            else
                PlaceWorldRing(f, nil)
            end
            f.text:SetText("Coletando")
        else
            f.text:SetText("Conjuração de teste")
        end
        ViewRange(f)
        if not f.isRing then f.bar:SetValue(0) end
        f.icon:SetTexture(TEST_ICON)
        if f.fx then
            f.theme = THEMES[testSchool] or ResolveTheme(nil, "")
            StartFX(f)
        end
        ApplyColor(f)
        UpdateSafeZone(f)
        ViewValue(f, 0)
        ViewSpark(f, true)
        f:SetAlpha(1)
        f:Show()
    end
end
