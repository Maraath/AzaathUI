--[[----------------------------------------------------------------------------
    AzaathUI - Modules/HideBlizz.lua
    Oculta os frames padrão da Blizzard de forma segura (3.3.5a).

    Regras para não gerar taint / ADDON_ACTION_BLOCKED:
      * NUNCA substituir métodos da Blizzard (ex.: PlayerFrame.Show = function() end).
        Isso contamina a tabela do frame e quebra código seguro mais tarde.
      * Usar apenas chamadas de API: UnregisterAllEvents, Hide, SetParent(hider).
      * Fazer tudo fora de combate (Azaath:RunOutOfCombat adia se necessário).
      * Frames com RegisterUnitWatch (Target/ToT) precisam de UnregisterUnitWatch,
        senão o state driver seguro volta a mostrá-los.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("HideBlizz")

local _G = _G
local type, ipairs, pcall, tostring = type, ipairs, pcall, tostring
local hider = Azaath.hider

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------
local function Resolve(frame)
    if type(frame) == "string" then return _G[frame] end
    return frame
end

-- Chama o método C original do widget, pulando sobrescritas em Lua da Blizzard.
-- No cliente moderno as barras de ação (ActionBarMixin) trocam :Hide/:Show por
-- versões Lua que gravam campos (visibilidade externa) e rodam o layout do
-- EditModeManager. Se o addon chamar essas versões, os campos ficam contaminados
-- e, em combate, o PetActionBar:Update -> Hide -> UpdateVisibility seguro passa a
-- ler valores do addon e o MainActionBar:SetPoint é barrado (ADDON_ACTION_BLOCKED).
-- O método do metatable (tabela de métodos do widget) não executa Lua nenhum.
local function Raw(frame, method, ...)
    local mt = getmetatable(frame)
    local idx = mt and mt.__index
    local fn = type(idx) == "table" and rawget(idx, method) or nil
    if type(fn) ~= "function" then fn = frame[method] end
    if type(fn) == "function" then return fn(frame, ...) end
end
Azaath.RawFrameCall = Raw

-- Neutraliza um frame. opts:
--   keepEvents = true  -> não desregistra eventos (útil quando o frame ainda
--                         precisa reagir, ex.: troca de barra em veículos)
--   unitWatch  = true  -> remove o RegisterUnitWatch do frame
local function Disable(frame, opts)
    frame = Resolve(frame)
    if not frame then return end
    if not (opts and opts.keepEvents) then
        frame:UnregisterAllEvents()
    end
    if opts and opts.unitWatch and UnregisterUnitWatch then
        UnregisterUnitWatch(frame)
    end
    Raw(frame, "Hide")
    Raw(frame, "SetParent", hider)
end

-- Apenas desliga eventos (economiza CPU de barras filhas que já estarão ocultas).
local function Silence(...)
    for i = 1, select("#", ...) do
        local f = Resolve((select(i, ...)))
        if f then f:UnregisterAllEvents() end
    end
end

-- Exposto para os próximos módulos (ex.: CastingBarFrame no UnitFrames).
Azaath.DisableBlizzardFrame = Disable

--------------------------------------------------------------------------------
-- Partes da interface
--------------------------------------------------------------------------------
local Hide = {}

-- Invisível de vez: além de reparentar, alpha 0 e mouse desligado na árvore
-- toda. No cliente moderno alguns frames de barra são reexibidos/reancorados
-- pelo sistema de layout; assim, mesmo se voltarem a aparecer, não se veem nem
-- capturam cliques. Só fora de combate (Apply roda via RunOutOfCombat).
local function SetMouseTree(f, enabled)
    if f.EnableMouse then
        if not (f.IsProtected and f:IsProtected() and InCombatLockdown()) then
            pcall(f.EnableMouse, f, enabled)
        end
    end
    for _, kid in ipairs({ f:GetChildren() }) do SetMouseTree(kid, enabled) end
end

local function Vanish(name, opts)
    local f = Resolve(name)
    if not f then return end
    Disable(f, opts)
    Raw(f, "SetAlpha", 0)
    SetMouseTree(f, false)
end
Azaath.VanishBlizzardFrame = Vanish

local vanished = {}        -- [frame] = opts para manter oculto após EditMode/Layout
local vanishHooked = {}    -- [frame] = true
local enforcingAlpha = {}  -- guarda de reentrância ao forçar SetAlpha(0)
local enforcingParent = {} -- guarda de reentrância ao forçar SetParent(hider)
local pendingRestore = {}  -- [frame] = true quando aguardando sair de combate

local function UnregisterEventTree(f)
    if not f then return end
    if f.UnregisterAllEvents then
        pcall(f.UnregisterAllEvents, f)
    end
    if f.GetChildren then
        for _, kid in ipairs({ f:GetChildren() }) do
            UnregisterEventTree(kid)
        end
    end
end

local function EnforceVanish(f, combatSafeOnly)
    local opts = vanished[f]
    if not opts then return end
    if not enforcingAlpha[f] then
        enforcingAlpha[f] = true
        pcall(Raw, f, "SetAlpha", 0)
        enforcingAlpha[f] = nil
    end
    if combatSafeOnly or (InCombatLockdown and InCombatLockdown()) then
        if not pendingRestore[f] and Azaath.RunOutOfCombat then
            pendingRestore[f] = true
            Azaath:RunOutOfCombat(function()
                pendingRestore[f] = nil
                EnforceVanish(f, false)
            end)
        end
        return
    end
    if opts.unitWatch and UnregisterUnitWatch then
        pcall(UnregisterUnitWatch, f)
    end
    if not opts.keepEvents then
        UnregisterEventTree(f)
    end
    pcall(Raw, f, "Hide")
    if f.GetParent and f:GetParent() ~= hider and not enforcingParent[f] then
        enforcingParent[f] = true
        pcall(Raw, f, "SetParent", hider)
        enforcingParent[f] = nil
    end
    SetMouseTree(f, false)
end

local function KeepVanished(name, opts)
    local f = Resolve(name)
    if not f then return end
    vanished[f] = opts or {}
    if not vanishHooked[f] then
        vanishHooked[f] = true
        if f.SetAlpha then
            hooksecurefunc(f, "SetAlpha", function(self) EnforceVanish(self, true) end)
        end
        if f.SetAlphaFromBoolean then
            hooksecurefunc(f, "SetAlphaFromBoolean", function(self) EnforceVanish(self, true) end)
        end
        if f.Show then
            hooksecurefunc(f, "Show", function(self) EnforceVanish(self, false) end)
        end
        if f.SetParent then
            hooksecurefunc(f, "SetParent", function(self, parent)
                if parent ~= hider and not enforcingParent[self] then
                    EnforceVanish(self, false)
                end
            end)
        end
        if f.HookScript then
            pcall(f.HookScript, f, "OnShow", function(self) EnforceVanish(self, false) end)
        end
    end
    EnforceVanish(f, false)
end

local function EnforceAllVanished()
    if not next(vanished) then return end
    Azaath:RunOutOfCombat(function()
        for f in pairs(vanished) do
            EnforceVanish(f, false)
        end
    end)
end

-- Barra de ação + arte, micro menu e bolsas nos nomes da 3.3.5 e do motor moderno
local ACTIONBAR_FRAMES = {
    "MainMenuBar", "MainActionBar", "MainMenuBarArtFrame", "MainMenuBarArtFrameBackground",
    "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap",
    "MicroButtonAndBagsBar", "MicroMenuContainer", "MicroMenu", "BagsBar",
    "StatusTrackingBarManager", "MainStatusTrackingBarContainer", "SecondaryStatusTrackingBarContainer",
    "OverrideActionBar",
    "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
    "MultiBar5", "MultiBar6", "MultiBar7",
    "StanceBar", "StanceBarFrame", "ShapeshiftBarFrame", "PossessBarFrame",
    "GamepadMainActionBarFrame", "GamepadMainActionBar",
}

local NOOP = function() end

local function SilenceButton(btn, isContainer, noWrite)
    if not btn then return end
    if btn.UnregisterAllEvents then
        pcall(btn.UnregisterAllEvents, btn)
    end
    if btn.SetScript then
        pcall(btn.SetScript, btn, "OnEvent", nil)
        pcall(btn.SetScript, btn, "OnUpdate", nil)
    end
    -- No cliente 12.x/Camelot (Blizzard_GamepadActionBars / ActionBarButtonEventsFrame),
    -- os gerenciadores chamam btn:OnEvent(...) diretamente como método de tabela Lua.
    -- Nunca na própria barra (MainActionBar/MultiBar*): campos gravados nela são lidos
    -- pelo layout do EditModeManager e contaminariam o reposicionamento em combate.
    if isContainer or noWrite then return end
    if type(btn.OnEvent) == "function" then btn.OnEvent = NOOP end
    if type(btn.UpdateState) == "function" then btn.UpdateState = NOOP end
    if type(btn.UpdateCooldown) == "function" then btn.UpdateCooldown = NOOP end
    if type(btn.UpdateUsable) == "function" then btn.UpdateUsable = NOOP end
    if type(btn.UpdateAction) == "function" then btn.UpdateAction = NOOP end
    if type(btn.UpdateFlash) == "function" then btn.UpdateFlash = NOOP end

    local name = btn.GetName and btn:GetName()
    local cd = btn.cooldown or btn.Cooldown or (type(name) == "string" and _G[name .. "Cooldown"] or nil)
    if cd and cd.UnregisterAllEvents then
        pcall(cd.UnregisterAllEvents, cd)
    end
end

local function SilenceTree(f, isContainer, noWrite)
    if not f then return end
    SilenceButton(f, isContainer, noWrite)
    if f.GetChildren then
        for _, kid in ipairs({ f:GetChildren() }) do
            SilenceTree(kid, nil, noWrite)
        end
    end
end

function Azaath.SilenceBlizzardActionBars()
    local eventManagers = {
        _G.ActionBarButtonEventsFrame,
        _G.ActionBarActionEventsFrame,
    }
    for _, mgr in ipairs(eventManagers) do
        if mgr then
            if mgr.UnregisterAllEvents then
                pcall(mgr.UnregisterAllEvents, mgr)
            end
            if mgr.SetScript then
                pcall(mgr.SetScript, mgr, "OnEvent", nil)
            end
            if type(mgr.frames) == "table" then
                for k in pairs(mgr.frames) do mgr.frames[k] = nil end
            end
        end
    end

    local prefixes = {
        "ActionButton", "BonusActionButton",
        "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
        "MultiBarRightButton", "MultiBarLeftButton",
        "MultiBar5Button", "MultiBar6Button", "MultiBar7Button",
        "ShapeshiftButton", "StanceButton", "StanceBarActionButton",
        "PossessButton", "OverrideActionBarButton",
    }
    for _, prefix in ipairs(prefixes) do
        for i = 1, 12 do
            SilenceButton(_G[prefix .. i])
        end
    end

    local containers = {
        "MainMenuBar", "MainActionBar", "OverrideActionBar",
        "StanceBar", "StanceBarFrame", "ShapeshiftBarFrame", "PossessBarFrame",
        "MultiBarBottomLeft", "MultiBarBottomRight", "MultiBarRight", "MultiBarLeft",
        "MultiBar5", "MultiBar6", "MultiBar7",
        "GamepadMainActionBarFrame", "GamepadMainActionBar",
    }
    for _, name in ipairs(containers) do
        local f = Resolve(name)
        if f then
            -- Barras de gamepad: sem gravar campos nos botões. A Blizzard chama
            -- SetEnabled neles em combate (TurnOrActionStop) e o campo nosso
            -- contaminava a chamada (ADDON_ACTION_BLOCKED).
            SilenceTree(f, true, name:find("^Gamepad") ~= nil)
        end
    end
end

function Hide.actionBars()
    -- Oculta e neutraliza frames da barra padrão (sem manter eventos para evitar erros de valor secreto por taint)
    for _, name in ipairs(ACTIONBAR_FRAMES) do
        Vanish(name)
    end

    -- Grifos / extremidades de arte da barra da Blizzard
    local artPieces = { "MainMenuBarLeftEndCap", "MainMenuBarRightEndCap" }
    for _, name in ipairs(artPieces) do
        local f = Resolve(name)
        if f then
            Raw(f, "Hide")
            Raw(f, "SetAlpha", 0)
        end
    end

    -- Barras de XP/reputação: sem uso e consomem eventos frequentes.
    Disable("MainMenuExpBar")
    Disable("MainMenuBarMaxLevelBar")
    Disable("ReputationWatchBar")

    -- Silencia completamente todos os botões e árvores da Blizzard
    Azaath.SilenceBlizzardActionBars()
end

function Hide.playerFrame()
    Disable(PlayerFrame)
    Silence("PlayerFrameHealthBar", "PlayerFrameManaBar")

    -- Suporte a veículos: o PlayerFrame precisa continuar ouvindo estes eventos
    -- para que a sequência de troca de arte/unidade da Blizzard rode normalmente
    -- (mesma abordagem usada pelo oUF). Ele segue invisível sob o hider.
    Azaath.SafeRegister(PlayerFrame, "UNIT_ENTERING_VEHICLE")
    Azaath.SafeRegister(PlayerFrame, "UNIT_ENTERED_VEHICLE")
    Azaath.SafeRegister(PlayerFrame, "UNIT_EXITING_VEHICLE")
    Azaath.SafeRegister(PlayerFrame, "UNIT_EXITED_VEHICLE")
end

-- No cliente moderno as barras do quadro de alvo ficam aninhadas (sem nome global), então o Silence por
-- nome não as alcança: elas seguiam ouvindo UNIT_HEALTH e rodando a conta de vida da Blizzard, que com
-- valores secretos dá erro ("execution tainted"). Aqui elas são alcançadas pelo caminho.
local function Dig(root, ...)
    local t = root
    for i = 1, select("#", ...) do
        if type(t) ~= "table" then return nil end
        t = t[select(i, ...)]
    end
    return t
end

local function SilenceUnitFrameBars(uf, tot)
    if not uf then return end
    local main = Dig(uf, "TargetFrameContent", "TargetFrameContentMain")
    local ctx = Dig(uf, "TargetFrameContent", "TargetFrameContentContextual")
    local list = {
        Dig(main, "HealthBarsContainer", "HealthBar"),
        Dig(main, "HealthBarsContainer", "TempMaxHealthLoss"),
        Dig(main, "ManaBar"),
        Dig(ctx, "Auras"),
        Dig(uf, "healthbar"), Dig(uf, "manabar"), Dig(uf, "spellbar"), Dig(uf, "powerBarAlt"),
        Dig(tot, "HealthBar"), Dig(tot, "ManaBar"),
    }
    for i = 1, 10 do
        local f = list[i]
        if f and f.UnregisterAllEvents then pcall(f.UnregisterAllEvents, f) end
    end
end

function Hide.targetFrame()
    local tf = _G.TargetFrame
    KeepVanished(tf, { unitWatch = true })
    KeepVanished("TargetFrameToT", { unitWatch = true })
    if tf and tf.totFrame and tf.totFrame ~= _G.TargetFrameToT then
        KeepVanished(tf.totFrame, { unitWatch = true })
    end
    if tf and tf.spellbar and tf.spellbar ~= _G.TargetFrameSpellBar then
        KeepVanished(tf.spellbar)
    end
    if tf and tf.powerBarAlt then
        KeepVanished(tf.powerBarAlt)
    end
    KeepVanished("ComboFrame")
    Silence("TargetFrameHealthBar", "TargetFrameManaBar", "TargetFrameSpellBar")
    SilenceUnitFrameBars(tf, (tf and tf.totFrame) or _G.TargetFrameToT)

    -- A Câmera Action (Target Lock / autoTargetLockOnAttack) usa a unidade "focus" por baixo
    -- dos panos (/focus ao atacar), o que fazia o FocusFrame nativo da Blizzard (que usa o
    -- mesmo TargetFrameTemplate do quadro de alvo) aparecer no canto inferior direito.
    local ff = _G.FocusFrame
    if ff then
        KeepVanished(ff, { unitWatch = true })
        KeepVanished("FocusFrameToT", { unitWatch = true })
        if ff.totFrame and ff.totFrame ~= _G.FocusFrameToT then
            KeepVanished(ff.totFrame, { unitWatch = true })
        end
        if ff.spellbar and ff.spellbar ~= _G.FocusFrameSpellBar then
            KeepVanished(ff.spellbar)
        end
        if ff.powerBarAlt then
            KeepVanished(ff.powerBarAlt)
        end
        Silence("FocusFrameHealthBar", "FocusFrameManaBar", "FocusFrameSpellBar")
        SilenceUnitFrameBars(ff, ff.totFrame or _G.FocusFrameToT)
    end
end

-- Indicadores que vivem dentro do MinimapCluster e seriam perdidos junto com ele.
local RESCUED_INDICATORS = { "MiniMapBattlefieldFrame", "MiniMapLFGFrame", "MiniMapMailFrame" }

function Hide.minimap()
    Disable(MinimapCluster)
    Disable("MinimapBackdrop")
    Disable("MinimapBorder")
    Disable("MinimapBorderTop")
    Disable("MiniMapTracking")
    Disable("MiniMapTrackingButton")
    Disable("MiniMapWorldMapButton")
    Disable("MinimapZoomIn")
    Disable("MinimapZoomOut")
    Disable("MinimapZoneTextButton")
    Disable("GameTimeFrame")
    Disable("MinimapNorthTag")

    -- Resgata fila de BG/LFG e correio para um pequeno contêiner no canto superior direito.
    local holder = CreateFrame("Frame", "AzaathUIIndicators", Azaath.root)
    holder:SetWidth(1)
    holder:SetHeight(1)
    holder:SetScale(0.85)
    -- Se o minimapa da Azaath já existe (HideBlizz adiado por combate), ancora nele;
    -- caso contrário o módulo Minimap reposiciona o contêiner ao ser criado.
    if not (Azaath.AnchorIndicators and Azaath.AnchorIndicators(holder)) then
        holder:SetPoint("TOPRIGHT", Azaath.root, "TOPRIGHT", -12, -12)
    end

    local prev
    for _, name in ipairs(RESCUED_INDICATORS) do
        local f = _G[name]
        if f then
            f:SetParent(holder)
            f:ClearAllPoints()
            if prev then
                f:SetPoint("TOPRIGHT", prev, "TOPLEFT", -4, 0)
            else
                f:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)
            end
            prev = f
        end
    end
end

function Hide.buffs()
    KeepVanished("BuffFrame")
    KeepVanished("DebuffFrame")
    Disable("TemporaryEnchantFrame")
    Disable("ConsolidatedBuffs") -- existe a partir da 3.3; ignorado se ausente
end

-- Ordem determinística de aplicação.
local ORDER = { "actionBars", "playerFrame", "targetFrame", "minimap", "buffs" }

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:OnInitialize()
    self.db = Azaath.db.hideBlizzard
end

function M:Apply()
    if self.applied then return end
    self.applied = true
    for _, key in ipairs(ORDER) do
        -- (opções "Blizzard" de barra/skin: Azaath.HideBlizzOn deixa a parte do jogo à mostra)
        if Azaath.HideBlizzOn(key) then
            local ok, err = pcall(Hide[key])
            if not ok then
                geterrorhandler()(("AzaathUI [HideBlizz:%s] %s"):format(key, tostring(err)))
            end
        end
    end
end

local layoutEvents = CreateFrame("Frame")
layoutEvents:SetScript("OnEvent", function()
    EnforceAllVanished()
end)

function M:OnEnable()
    Azaath.SafeRegister(layoutEvents, "PLAYER_ENTERING_WORLD")
    Azaath.SafeRegister(layoutEvents, "EDIT_MODE_LAYOUTS_UPDATED")
    local em = _G.EditModeManagerFrame
    if em then
        if em.UpdateLayoutInfo then
            hooksecurefunc(em, "UpdateLayoutInfo", EnforceAllVanished)
        end
        if em.ExitEditMode then
            hooksecurefunc(em, "ExitEditMode", EnforceAllVanished)
        end
    end

    -- PLAYER_LOGIN normalmente já é fora de combate, mas um /reload em combate
    -- pode cair aqui com lockdown ativo: nesse caso adiamos para PLAYER_REGEN_ENABLED.
    if not Azaath:RunOutOfCombat(function() self:Apply() end) then
        Azaath:Print("em combate: os frames da Blizzard serão ocultados ao sair do combate.")
    end
end
