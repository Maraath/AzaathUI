--[[----------------------------------------------------------------------------
    AzaathUI - Olho de Azaath / Watch.lua
    O laço de decisão: a cada pouco (e a cada evento útil) olha o alvo de
    interação, decide se ele merece brilho e mantém o jogo de acordo
    (porta da exibição nativa, placas caladas em combate, alcance de pesca).
    Também o ciclo de vida do módulo (OnInitialize / OnEnable / ApplyConfig).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local ns = Azaath.OlhoNS
local L = ns.L
local M = ns.M
local S, N, G = ns.Sense, ns.Native, ns.Glow
local SafeCall, IsSecret, Flag, NameKey = ns.SafeCall, ns.IsSecret, ns.Flag, ns.NameKey

local pairs, ipairs, tostring, type = pairs, ipairs, tostring, type

local POLL = 0.12
local PLATE_PATIENCE = 0.5 -- segundos esperando a placa antes de avisar no diagnóstico

local W = {}
ns.Watch = W

local inCombat, leaving = false, false
local plateWaitSince
local lastLine

--------------------------------------------------------------------------------
-- Diagnóstico (/olho debug)
--------------------------------------------------------------------------------

local function Report(line, detail)
    if not ns.db.debug or line == lastLine then return end
    lastLine = line
    ns.Print(line)
    local extra = detail and detail()
    if extra and extra ~= "" then print("    " .. extra) end
end

function W.ForgetReport() lastLine = nil end

local function CatName(cat) return L["NAME_" .. (cat or "none"):upper()] end

local function Describe(unit, name, via, cursor, near)
    local id = S.ObjectID(unit)
    local parts = {
        L.DEBUG_CURSOR:format(tostring(cursor)), L.DEBUG_VIA:format(via), L.DEBUG_RANGE:format(Flag(near)),
        L.DEBUG_OBJECT:format(tostring(id or "?")), L.DEBUG_FISHING:format(Flag(S.Fishing())),
    }
    if C_QuestLog and C_QuestLog.UnitIsRelatedToActiveQuest then
        parts[#parts + 1] = L.DEBUG_QUEST:format(Flag(SafeCall(C_QuestLog.UnitIsRelatedToActiveQuest, unit)))
    end
    local _, kind = S.ReadCursor(unit)
    local service = kind == "service" and L.MATCH_CURSOR
    local list = S.Objectives()
    parts[#parts + 1] = L.DEBUG_MATCH:format(service or S.QuestMatch(name) or L.MATCH_NONE, #list)
    parts[#parts + 1] = L.DEBUG_CHEST:format(service or S.ContainerMatch(id, name) or L.MATCH_NONE)
    if C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret then
        parts[#parts + 1] = L.DEBUG_SECRET:format(Flag(SafeCall(C_Secrets.ShouldUnitIdentityBeSecret, unit)))
    end
    if C_NamePlateManager and C_NamePlateManager.IsNamePlateUnitBehindCamera then
        parts[#parts + 1] = L.DEBUG_BEHIND:format(Flag(SafeCall(C_NamePlateManager.IsNamePlateUnitBehindCamera, unit)))
    end
    return table.concat(parts, " | ")
end

--------------------------------------------------------------------------------
-- Decisão
--------------------------------------------------------------------------------

function W.Paused()
    local db = ns.db
    if db.hideInCombat and (inCombat or InCombatLockdown()) then return true end
    return db.hideInInstance and IsInInstance ~= nil and SafeCall(IsInInstance) == true
end

local function LootBeamTakes(unit)
    local lb = Azaath.GetModule and Azaath:GetModule("LootBeam")
    return lb and lb.WantsUnit and lb:WantsUnit(unit)
end

-- Devolve a placa de um alvo sem brilho que o jogo ainda mostra (combate): será calada.
local function Decide()
    local db = ns.db
    if leaving or (G.Previewing() and not G.HoldingPreview()) then return end
    if not db.enabled then G.Release() return end

    if W.Paused() then
        Report(L.DEBUG_PAUSED)
        G.Release()
        local unit, plate = S.Target()
        if unit then return N.Shut(unit, plate) end
        N.SetGate(false)
        return
    end

    local unit, plate, via, unknown = S.Target()
    if plate or not unit then plateWaitSince = nil end
    if not unit then
        if lastLine then Report(L.DEBUG_NO_TARGET) end
        N.SetGate(unknown == true) -- sem saber, deixa o jogo mostrar
        G.Release()
        return
    end

    local name = SafeCall(UnitName, unit)
    local shown = name or "?"

    -- só objetos do cenário: nem PNJs nem cadáveres (o facho de saque cuida dos corpos)
    if SafeCall(UnitIsGameObject, unit) ~= true then
        Report(L.DEBUG_IGNORED:format(shown))
        G.Release()
        if LootBeamTakes(unit) then N.SetGate(true) return end
        return N.Shut(unit, plate)
    end

    local plainName = S.NameOf(unit)
    if plainName and ns.db.ignored[NameKey(plainName)] then
        Report(L.DEBUG_SKIPPED:format(plainName == "" and L.NAME_UNNAMED or shown))
        G.Release()
        return N.Shut(unit, plate)
    end

    local cat, unable, cursor = S.Classify(unit, name)
    local state, near = S.State(unit, unable)
    local detail = function() return Describe(unit, name, via, cursor, near) end

    if not (cat and ns.cdb.categories[cat]) then
        Report(L.DEBUG_HIDDEN:format(shown, CatName(cat)), detail)
        G.Release()
        return N.Shut(unit, plate)
    end
    if db.hideUntrained and S.Trained(cat) == false then
        Report(L.DEBUG_UNTRAINED:format(shown, CatName(cat)), detail)
        G.Release()
        return N.Shut(unit, plate)
    end

    N.SetGate(true)
    if not plate then
        -- a placa foi pedida agora; se não vier, o jogo conhece o alvo mas não o mostra
        G.Release()
        local now = GetTime()
        plateWaitSince = plateWaitSince or now
        if now - plateWaitSince > PLATE_PATIENCE then
            Report(L.DEBUG_NO_PLATE:format(shown, CatName(cat)), detail)
        end
        return
    end

    G.Present(plate, unit, name, cat, state)
    Report(L.DEBUG_SHOWN:format(shown, CatName(cat), L["STATE_" .. (G.State() or state):upper()]), detail)
end

-- A prévia "suave" da janela de ajustes guarda o brilho até o jogo apontar algo a iluminar.
function W.Evaluate()
    if not ns.db then return end
    G.SetKeep(G.HoldingPreview())
    local mute = Decide()
    G.SetKeep(false)
    if mute then N.Mute(mute) else N.Unmute() end
end
local Evaluate = W.Evaluate
ns.Evaluate = Evaluate

-- linha de pesca na água: o jogo procura a boia mais longe
local function WatchFishing()
    local out = ns.db.enabled and ns.cdb.categories.bobber and S.Fishing() or false
    if N.SetFishing(out) and ns.db.debug then
        ns.Print((out and L.DEBUG_LINE_OUT or L.DEBUG_LINE_IN):format(N.WantedRange(), tostring(N.Get("SoftTargetInteractRange"))))
    end
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------

local driver = CreateFrame("Frame")
local since = 0

driver:SetScript("OnUpdate", function(_, dt)
    if not ns.db or leaving then return end
    if G.Previewing() then
        G.UpdatePreview(dt)
        if not G.HoldingPreview() then return end
    end
    since = since + dt
    if since < POLL then return end
    since = 0
    WatchFishing()
    N.KeepObjectIcon()
    Evaluate()
end)

local on = {}

local function ApplyAll()
    if ns.db.enabled then N.Apply() end
    Evaluate()
end

-- Reaplica depois de um atraso, uma vez só mesmo com vários pedidos seguidos
local applyToken = 0
local function ApplyLater(delay)
    applyToken = applyToken + 1
    local mine = applyToken
    C_Timer.After(delay, function()
        if mine == applyToken and not leaving and ns.db then ApplyAll() end
    end)
end

on.VARIABLES_LOADED = ApplyAll       -- ajustes da conta podem chegar depois do login
function on.PLAYER_ENTERING_WORLD()
    ApplyAll()
    ApplyLater(5)                    -- ajustes sincronizados da conta chegam atrasados
end

-- Preset de gráficos (ou outro addon) desfez nossas CVars: devolve 1 s depois.
-- Em combate N.Apply só anota e aplica no fim da luta.
function on.CVAR_UPDATE(name)
    if N.Writing() or not ns.db.enabled or type(name) ~= "string" or IsSecret(name) then return end
    if N.RESET_BY[name:lower()] then ApplyLater(1) end
end

function on.PLAYER_LOGOUT()
    G.Release(true)
    N.Unmute()
    N.ReturnOnLogout()
    leaving = true
end

-- em combate não dá para mexer nas CVars: a porta é ajustada logo antes
function on.PLAYER_REGEN_DISABLED()
    if ns.db.enabled then N.SetGate(not ns.db.hideInCombat) end
    inCombat = true
end

function on.PLAYER_REGEN_ENABLED()
    inCombat = false
    N.FlushPending()
    Evaluate()
end

function on.NAME_PLATE_UNIT_ADDED(unit)
    S.PlateAdded(unit)
    Evaluate()
end

function on.NAME_PLATE_UNIT_REMOVED(unit)
    S.PlateRemoved(unit)
    local plate = S.PlateOf(unit)
    if plate and plate == G.Anchor() then G.Release(true) end
end

function on.PLAYER_SOFT_INTERACT_CHANGED(old, new)
    -- a mesma placa reciclada para outro alvo: força recomeçar o brilho
    if not IsSecret(old) and not IsSecret(new) and old and new and old ~= new then G.Retarget() end
    Evaluate()
end

function on.QUEST_LOG_UPDATE() S.QuestsChanged() end
function on.WORLD_CURSOR_TOOLTIP_UPDATE() if S.LearnFromTooltip() then Evaluate() end end
function on.LOOT_READY() S.LearnLootSources() end
on.LOOT_OPENED = on.LOOT_READY

driver:SetScript("OnEvent", function(_, event, ...)
    if leaving or not ns.db then return end
    local fn = on[event]
    if fn then fn(...) end
end)
for event in pairs(on) do pcall(driver.RegisterEvent, driver, event) end

--------------------------------------------------------------------------------
-- Reações aos ajustes
--------------------------------------------------------------------------------

local function Tag() G.RefreshTag(nil, nil); if not G.Previewing() then Evaluate() end end
local function Place() G.Reposition(); Evaluate() end

for _, k in ipairs({ "offsetY", "followAlpha" }) do ns.OnOption(k, Place) end
for _, k in ipairs({ "showName", "showIcon", "textSize", "textFont", "glowOnly" }) do ns.OnOption(k, Tag) end
for _, k in ipairs({ "hideInCombat", "hideInInstance", "hideUntrained", "hideLocked", "categories", "ignored" }) do
    ns.OnOption(k, function() W.ForgetReport(); Evaluate() end)
end
ns.OnOption("silhouette", function() G.ApplyCut() end)
ns.OnOption("color", function() G.RecolorIfShown() end)
ns.OnOption("debug", function() W.ForgetReport() end)
ns.OnOption("exclusive", function() N.ForgetGate(); Evaluate() end)

local function Reapply() if ns.db.enabled then N.Apply() end; Evaluate() end
ns.OnOption("nativeSparkle", function()
    Reapply()
    if not ns.db.nativeSparkle then ns.Print(ns.L.MSG_SPARKLE_RESTART) end
end)
ns.OnOption("range", Reapply)
ns.OnOption("arc", Reapply)

ns.OnOption("enabled", function()
    if ns.db.enabled then
        N.Apply()
        Evaluate()
    else
        G.Release(true)
        N.Unmute()
        N.Restore()
    end
end)

ns.OnOption("appearance", function()
    G.ApplyCut()
    G.Reposition()
    G.RefreshTag(nil, nil)
    Evaluate()
end)

ns.OnOption("reset", function()
    ns.ShowZone(false)
    N.ForgetGate()
    W.ForgetReport()
    if ns.db.enabled then N.Apply() end
    G.Reposition()
    G.RefreshTag(nil, nil)
    Evaluate()
end)

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------

function M:OnInitialize()
    ns.LoadSettings()
    if ns.ApplyLanguage then ns.ApplyLanguage() end
    S.Init()
    if ns.SetupInterface then ns.SetupInterface() end -- Menu.lua: botão do minimapa
end

function M:OnEnable()
    if ns.db.enabled then N.Apply() end
    Evaluate()
    if ns.Tracking then ns.Tracking.Update() end
end

-- O painel geral do AzaathUI muda AzaathUIDB.olho direto e chama isto
function M:ApplyConfig()
    if not ns.db then return end
    if ns.db.enabled then N.Apply() else G.Release(true); N.Unmute(); N.Restore() end
    N.ForgetGate()
    Evaluate()
    if ns.Tracking then ns.Tracking.Update() end
    ns.Notify()
end
