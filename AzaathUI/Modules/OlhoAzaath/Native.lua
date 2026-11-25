--[[----------------------------------------------------------------------------
    AzaathUI - Olho de Azaath / Native.lua
    Tudo o que o Olho muda no próprio jogo:
      * as CVars do "soft targeting" de interação (guardadas antes e devolvidas
        ao desligar e ao sair do jogo, para nada ficar para trás);
      * a "porta": no modo exclusivo, o jogo só mostra placa e ícone de interação
        quando o alvo merece brilho;
      * esconder a placa nativa do alvo iluminado (o Olho escreve nome e ícone
        próprios) e, em combate, a de alvos que não deviam aparecer.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local ns = Azaath.OlhoNS
local SafeCall, IsSecret = ns.SafeCall, ns.IsSecret

local pairs, ipairs, pcall, tostring, tonumber, type = pairs, ipairs, pcall, tostring, tonumber, type
local max = math.max

local N = {}
ns.Native = N

local FISHING_RANGE = 60 -- a boia costuma cair além dos 15 m do ajuste

N.MANAGED = {
    "SoftTargetInteract", "SoftTargetNameplateInteract", "SoftTargetInteractRange", "SoftTargetInteractArc",
    "SoftTargetInteractOnlyInRange", "SoftTargetInteractRangeIsHard", "SoftTargetIconInteract",
    "SoftTargetIconGameObject", "nameplateGameObjectMaxDistance", "outlineModeShowLootEffectWhenDisabled",
}
N.WATCHED = { "nameplateMaxDistance" }

-- Brilho do próprio jogo (purpurina dourada em itens de missão e corpos com saque).
-- Os presets de gráficos o desligam; quem muda estas CVars dispara uma nova aplicação.
local SPARKLE = "outlineModeShowLootEffectWhenDisabled"
N.RESET_BY = { graphicsquality = true, raidgraphicsquality = true, [SPARKLE:lower()] = true }

local function Get(name)
    local ok, v = pcall(C_CVar and C_CVar.GetCVar or GetCVar, name)
    if ok then return v end
end

-- só escreve CVars que este cliente conhece (e só quando o valor muda)
local writing = false
local function Set(name, value)
    local cur = Get(name)
    if cur == nil or cur == tostring(value) then return end
    writing = true
    pcall(C_CVar and C_CVar.SetCVar or SetCVar, name, tostring(value))
    writing = false
end
N.Get, N.Set = Get, Set
-- a mudança de CVar veio do próprio Olho? (não reagir ao próprio eco)
function N.Writing() return writing end

local pending       -- "apply" / "restore": esperando o fim do combate
local gate          -- porta aberta? nil = reaplicar
local fishingOut = false

local function LootBeamWantsPlates()
    local lb = Azaath.db and Azaath.db.lootBeam
    return lb and lb.enabled and lb.showOnUnopened ~= false
end

local function LootBeamOn()
    local lb = Azaath.db and Azaath.db.lootBeam
    return lb and lb.enabled
end

function N.WantedRange()
    return fishingOut and FISHING_RANGE or ns.db.range
end

function N.Pending() return pending end
function N.GateState() return gate end
function N.ForgetGate() gate = nil end

-- Plumber com o módulo de nome do alvo de interação: o Olho só põe a luz
local plumberLoaded
function N.Plumber()
    if plumberLoaded == nil then
        plumberLoaded = C_AddOns and C_AddOns.IsAddOnLoaded and SafeCall(C_AddOns.IsAddOnLoaded, "Plumber") == true or false
        if not plumberLoaded then plumberLoaded = nil end -- ele pode carregar depois: pergunta de novo
    end
    return plumberLoaded and type(PlumberDB) == "table" and PlumberDB.SoftTargetName == true or false
end

-- só a luz, sem nome e ícone do Olho
function N.LightOnly()
    return ns.db.glowOnly == true or N.Plumber()
end

-- o jogo só destaca os alvos iluminados?
function N.Exclusive()
    return ns.db.exclusive and not N.Plumber()
end

-- os valores no cliente são os que o Olho aplica?
local function LooksApplied()
    local only = Get("SoftTargetInteractOnlyInRange")
    local range = tonumber(Get("SoftTargetInteractRange"))
    return Get("SoftTargetInteract") == "3" and (only == nil or only == "0")
        and (range == ns.db.range or range == FISHING_RANGE)
end

-- O cliente pode zerar o ícone de objetos depois de entrar no mundo; sem ele não há placa.
function N.KeepObjectIcon()
    if gate == true and Get("SoftTargetIconGameObject") ~= "1" then Set("SoftTargetIconGameObject", 1) end
end

-- abre ou fecha a exibição nativa do alvo de interação
function N.SetGate(open)
    local db = ns.db
    open = open or not N.Exclusive()
    if open == gate or InCombatLockdown() then
        N.KeepObjectIcon()
        return
    end
    gate = open
    local keep = open or LootBeamWantsPlates()
    Set("SoftTargetNameplateInteract", keep and 1 or 0)
    if open then Set("SoftTargetIconGameObject", 1) end
    local saved = db.savedCVars
    local orig = saved and saved.SoftTargetIconInteract
    if orig ~= false then Set("SoftTargetIconInteract", keep and (orig or 1) or 0) end
end

function N.Apply()
    local db = ns.db
    if InCombatLockdown() then pending = "apply" return end
    if db.cvarsReturned then
        -- devolvidos na última saída: se o cliente não está com os nossos, são do jogador
        db.cvarsReturned = nil
        if not LooksApplied() then db.savedCVars = nil end
    end
    db.savedCVars = db.savedCVars or {}
    for _, name in ipairs(N.MANAGED) do
        if db.savedCVars[name] == nil then db.savedCVars[name] = Get(name) or false end
    end
    Set("SoftTargetInteract", 3)
    Set("SoftTargetInteractRange", N.WantedRange())
    Set("SoftTargetInteractArc", LootBeamOn() and 2 or db.arc)
    Set("SoftTargetInteractOnlyInRange", 0)
    Set("SoftTargetInteractRangeIsHard", 0)
    local ownDistance = tonumber(db.savedCVars.nameplateGameObjectMaxDistance) or 0
    Set("nameplateGameObjectMaxDistance", max(ownDistance, FISHING_RANGE))
    -- Ligar vale na hora; desligar só some depois de reiniciar o jogo (limite do cliente)
    local orig = db.savedCVars[SPARKLE]
    Set(SPARKLE, db.nativeSparkle and 1 or (orig ~= false and orig or 0))
    gate = nil
end

function N.Restore()
    local db = ns.db
    if InCombatLockdown() then pending = "restore" return end
    if not db.savedCVars then return end
    for name, v in pairs(db.savedCVars) do
        if v ~= false then Set(name, v) end
    end
    db.savedCVars = nil
    gate = nil
end

-- ao sair do jogo: devolve os valores, mas lembra deles (fechamento abrupto)
function N.ReturnOnLogout()
    local db = ns.db
    if not db.enabled or not db.savedCVars or InCombatLockdown() then return end
    for name, v in pairs(db.savedCVars) do
        if v ~= false then Set(name, v) end
    end
    db.cvarsReturned = true
    gate = nil
end

-- fim do combate: faz o que ficou pendente; devolve true se reaplicou
function N.FlushPending()
    local p = pending
    pending = nil
    if p == "apply" then N.Apply() return true end
    if p == "restore" then N.Restore() end
end

-- linha de pesca na água: o alcance sobe até a boia. Devolve true se mudou.
function N.SetFishing(out)
    out = out and true or false
    if out == fishingOut then return false end
    fishingOut = out
    local db = ns.db
    if not db.enabled or not db.savedCVars or db.cvarsReturned then return true end
    if InCombatLockdown() then
        pending = pending or "apply"
    else
        Set("SoftTargetInteractRange", N.WantedRange())
    end
    return true
end

--------------------------------------------------------------------------------
-- Placa nativa
--------------------------------------------------------------------------------

local function UnitFrameOf(plate)
    local ok, f = pcall(function() return plate.UnitFrame end)
    if ok and type(f) == "table" then return f end
end

-- Alguns addons tiram o ícone de interação (SoftTargetFrame) do quadro da placa;
-- aí esconder o quadro não basta. Devolve o ícone solto, se for o caso.
local function LooseIcon(unitFrame)
    local ok, icon = pcall(function() return unitFrame.SoftTargetFrame end)
    if not ok or type(icon) ~= "table" or IsSecret(icon) then return nil end
    return icon
end

-- quadro escondido -> opacidade original (para devolver)
local hidden = {}

local function Hide(frame)
    if not frame or hidden[frame] then return end
    local ok, a = pcall(frame.GetAlpha, frame)
    if not ok or IsSecret(a) or type(a) ~= "number" or a == 0 then a = 1 end
    if pcall(frame.SetAlpha, frame, 0) then hidden[frame] = a end
end

local function Show(frame)
    local a = frame and hidden[frame]
    if a then
        pcall(frame.SetAlpha, frame, a)
        hidden[frame] = nil
    end
end

-- dois "donos" de esconderijo: o alvo iluminado (lit) e o alvo calado em combate (muted)
local held = { lit = {}, muted = {} }

local function Release(kind)
    local other = kind == "lit" and held.muted or held.lit
    for _, f in ipairs(held[kind]) do
        local shared = false
        for _, g in ipairs(other) do if g == f then shared = true end end
        if not shared then Show(f) end
    end
    held[kind] = {}
end

local function Take(kind, plate)
    local f = plate and UnitFrameOf(plate)
    if f and held[kind][1] == f then return end
    Release(kind)
    if not f then return end
    local list = held[kind]
    Hide(f)
    list[1] = f
    local icon = LooseIcon(f)
    if icon then Hide(icon); list[2] = icon end
end

function N.HidePlate(plate) Take("lit", plate) end
function N.ShowPlate() Release("lit") end
function N.Mute(plate) Take("muted", plate) end
function N.Unmute() Release("muted") end

-- Com as preferências do jogador, esta placa apareceria mesmo sem ser alvo?
local SIDE_CVARS = {
    enemy = { "nameplateShowEnemies" },
    player = { "nameplateShowFriendlyPlayers", "nameplateShowFriends" },
    npc = { "nameplateShowFriendlyNpcs", "nameplateShowFriends" },
}

function N.WouldShowAnyway(unit)
    if SafeCall(UnitIsGameObject, unit) == true then return false end
    if UnitIsDead and SafeCall(UnitIsDead, unit) == true then return false end
    local hostile = UnitCanAttack and SafeCall(UnitCanAttack, "player", unit)
    if hostile == nil then return true end
    local side = hostile and "enemy" or (SafeCall(UnitIsPlayer, unit) == true and "player" or "npc")
    local knows = false
    for _, name in ipairs(SIDE_CVARS[side]) do
        local v = Get(name)
        if v == "1" then return true end
        knows = knows or v ~= nil
    end
    return not knows
end

-- O alvo não merece brilho: fecha a porta. Em combate ela não fecha; devolve então a
-- placa que deve ser calada (salvo modo não exclusivo ou placa que apareceria de todo jeito).
function N.Shut(unit, plate)
    N.SetGate(false)
    if plate and N.Exclusive() and gate ~= false and not N.WouldShowAnyway(unit) then return plate end
end
