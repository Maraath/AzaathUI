--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ActionCam/Core.lua
    Módulo coordenador da Câmera Action (ActionCam): ciclo de vida, eventos,
    loop OnUpdate throttled (0.1s), atalhos no menu Teclas e ApplyLayout.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local _G = _G

local M = Azaath:NewModule("ActionCam")
local AC = Azaath.ActionCam or {}
Azaath.ActionCam = AC

local CreateFrame      = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown

--------------------------------------------------------------------------------
-- Nomes dos atalhos na janela Teclas da Blizzard
--------------------------------------------------------------------------------
_G.BINDING_HEADER_AZAATH_ACTIONCAM      = "AzaathUI - Câmera Action"
_G.BINDING_NAME_AZAATH_MOUSELOOK        = "Alternar / Segurar Mouse Look"
_G.BINDING_NAME_AZAATH_FLIPCAMERA       = "Virar Câmera 180°"
_G.BINDING_NAME_AZAATH_SWAPSHOULDER     = "Trocar Ombro da Câmera"
_G.BINDING_NAME_AZAATH_RESETMOUSELOOK   = "Resetar Mouse Look (recuperar cursor)"
_G.BINDING_NAME_AZAATH_ALLYCYCLE_NEXT   = "Ciclo de Aliados: Próximo"
_G.BINDING_NAME_AZAATH_ALLYCYCLE_PREV   = "Ciclo de Aliados: Anterior"
_G.BINDING_NAME_AZAATH_SUPPORTMODE      = "Modo Suporte (alternar)"
_G.BINDING_NAME_AZAATH_RADIALMENU       = "Menu Radial (segurar)"
_G.BINDING_NAME_AZAATH_TOGGLEFOCUS      = "Target Lock (travar / destravar foco)"
_G.BINDING_NAME_AZAATH_CYCLEFOCUS_NEXT  = "Target Lock: Próximo inimigo"
_G.BINDING_NAME_AZAATH_CYCLEFOCUS_PREV  = "Target Lock: Inimigo anterior"

local eventFrame = CreateFrame("Frame", "AzaathUIActionCamController", _G.UIParent)
local elapsedAcc = 0
local TICK_INTERVAL = 0.10

local function SilenceExperimentalCVarPopup()
    if _G.GameEvent and _G.GameEvent.UnregisterInternalEvent then
        pcall(_G.GameEvent.UnregisterInternalEvent, "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
    end
    if _G.UIParent and _G.UIParent.UnregisterEvent then
        pcall(_G.UIParent.UnregisterEvent, _G.UIParent, "EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")
    end
    if _G.StaticPopup_Hide then
        pcall(_G.StaticPopup_Hide, "EXPERIMENTAL_CVAR_CONFIRMATION")
        pcall(_G.StaticPopup_Hide, "EXPERIMENTAL_CVAR_WARNING")
    end
end
SilenceExperimentalCVarPopup()

local function ApplyAll()
    local db = AC.DB()
    if not db then return end
    if not db.enabled then
        if AC.IsMouselooking and AC.IsMouselooking() then
            AC.UnlockFreeLook()
        end
        if AC.DisplayCrosshair then AC.DisplayCrosshair(false) end
        if AC.UpdateVignette then AC.UpdateVignette() end
        if AC.UpdateAllyCycleHUD then AC.UpdateAllyCycleHUD() end
        if AC.UpdateFocusNameplateMarker then AC.UpdateFocusNameplateMarker() end
        if AC.ResetBDOCamera then AC.ResetBDOCamera() end
        AC.RefreshClickCastBindings()
        AC.RefreshRadialBindings()
        AC.RestorePriorCVars()
        return
    end

    SilenceExperimentalCVarPopup()
    AC.CapturePriorCVarSnapshot()
    AC.ApplyReticleCVars()
    AC.ApplyMouseLookSpeed()
    AC.ApplyDynamicPitch()
    AC.ApplyBDOCameraInertia()
    AC.ApplyMinCameraZoom()
    AC.SyncTargetFocusFromFocusUnit()
    AC.RefreshClickCastBindings()
    AC.RefreshRadialBindings()
    if AC.ApplyCrosshairLayout then AC.ApplyCrosshairLayout() end
    AC.ReconcileFreeLook()
    if AC.UpdateVignette then AC.UpdateVignette() end
    if AC.UpdateFocusNameplateMarker then AC.UpdateFocusNameplateMarker() end
end

function M:ApplyLayout()
    ApplyAll()
end

function AC.ResetAllToDefaults()
    AC.RestorePriorCVars()
    if Azaath.db and Azaath.defaults and Azaath.defaults.actioncam then
        Azaath.db.actioncam = Azaath.CopyDeep and Azaath.CopyDeep(Azaath.defaults.actioncam) or Azaath.db.actioncam
    end
    ApplyAll()
end

function M:OnEnable()
    local events = {
        "PLAYER_ENTERING_WORLD",
        "PLAYER_REGEN_ENABLED",
        "PLAYER_REGEN_DISABLED",
        "PLAYER_TARGET_CHANGED",
        "PLAYER_FOCUS_CHANGED",
        "PLAYER_SOFT_INTERACT_CHANGED",
        "PLAYER_SOFT_ENEMY_CHANGED",
        "MODIFIER_STATE_CHANGED",
        "GLOBAL_MOUSE_DOWN",
        "UNIT_SPELLCAST_SENT",
        "UPDATE_MOUSEOVER_UNIT",
        "UNIT_SPELLCAST_START",
        "UNIT_SPELLCAST_STOP",
        "UNIT_SPELLCAST_SUCCEEDED",
        "UNIT_SPELLCAST_CHANNEL_START",
        "UNIT_SPELLCAST_CHANNEL_STOP",
        "UNIT_SPELLCAST_INTERRUPTED",
        "UNIT_COMBAT",
        "NAME_PLATE_UNIT_ADDED",
        "NAME_PLATE_UNIT_REMOVED",
        "GROUP_ROSTER_UPDATE",
        "UPDATE_BINDINGS",
    }
    for _, ev in ipairs(events) do
        Azaath.SafeRegister(eventFrame, ev)
    end

    eventFrame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3)
        if event == "PLAYER_ENTERING_WORLD" then
            ApplyAll()
        elseif event == "PLAYER_REGEN_ENABLED" then
            AC.FlushPendingClickCastRefresh()
            AC.RefreshRadialBindings()
            if AC.UpdateCrosshairReaction then AC.UpdateCrosshairReaction() end
            if AC.UpdateVignette then AC.UpdateVignette() end
            if AC.OnBDOCombatState then AC.OnBDOCombatState(false) end
        elseif event == "PLAYER_REGEN_DISABLED" then
            if AC.UpdateCrosshairReaction then AC.UpdateCrosshairReaction() end
            if AC.UpdateVignette then AC.UpdateVignette() end
            if AC.OnBDOCombatState then AC.OnBDOCombatState(true) end
            if AC.UpdateCameraSituation then AC.UpdateCameraSituation() end
        elseif event == "PLAYER_FOCUS_CHANGED" then
            AC.SyncTargetFocusFromFocusUnit()
            if AC.UpdateFocusNameplateMarker then AC.UpdateFocusNameplateMarker() end
            if AC.UpdateCrosshairReaction then AC.UpdateCrosshairReaction() end
        elseif event == "PLAYER_TARGET_CHANGED"
            or event == "PLAYER_SOFT_INTERACT_CHANGED"
            or event == "PLAYER_SOFT_ENEMY_CHANGED" then
            if AC.UpdateCrosshairReaction then AC.UpdateCrosshairReaction() end
            if AC.UpdateVignette then AC.UpdateVignette() end
        elseif event == "GLOBAL_MOUSE_DOWN" or (event == "UNIT_SPELLCAST_SENT" and arg1 == "player") then
            if AC.OnCtrlToggleMouseDown then AC.OnCtrlToggleMouseDown() end
        elseif event == "MODIFIER_STATE_CHANGED" or event == "UPDATE_MOUSEOVER_UNIT" then
            if event == "MODIFIER_STATE_CHANGED" and AC.OnCtrlToggleModifier then
                AC.OnCtrlToggleModifier(arg1, arg2)
            end
            AC.OnTooltipModifierChanged(event)
            if AC.UpdateCrosshairReaction then AC.UpdateCrosshairReaction() end
        elseif event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            if arg1 == "player" then
                if AC.UpdateCrosshairCastFeedback then AC.UpdateCrosshairCastFeedback(true) end
                if AC.StartBDOCastFocus then AC.StartBDOCastFocus() end
                if event == "UNIT_SPELLCAST_CHANNEL_START" and AC.OnSpellChannel then
                    local ok, chName = pcall(_G.UnitChannelInfo, "player")
                    if ok and chName and not Azaath.IsSecret(chName) then AC.OnSpellChannel(true, chName) end
                end
            end
        elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
            if arg1 == "player" and AC.EndBDOCastFocus then
                AC.EndBDOCastFocus(true)
                if AC.OnSpellMove then AC.OnSpellMove(AC.SpellNameSafe(arg3)) end
            end
        elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_INTERRUPTED" then
            if arg1 == "player" then
                if AC.UpdateCrosshairCastFeedback then AC.UpdateCrosshairCastFeedback(false) end
                if AC.EndBDOCastFocus then AC.EndBDOCastFocus(false) end
                if event == "UNIT_SPELLCAST_CHANNEL_STOP" and AC.OnSpellChannel then AC.OnSpellChannel(false) end
            end
        elseif event == "UNIT_COMBAT" then
            if AC.OnBDOUnitCombat then
                AC.OnBDOUnitCombat(arg1, arg2, arg3)
            end
        elseif event == "NAME_PLATE_UNIT_ADDED" or event == "NAME_PLATE_UNIT_REMOVED" then
            if AC.UpdateFocusNameplateMarker then AC.UpdateFocusNameplateMarker() end
        elseif event == "GROUP_ROSTER_UPDATE" then
            if AC.OnGroupRosterChanged then AC.OnGroupRosterChanged() end
        elseif event == "UPDATE_BINDINGS" then
            if not InCombatLockdown() then
                AC.RefreshClickCastBindings()
                AC.RefreshRadialBindings()
            end
        end
    end)

    eventFrame:SetScript("OnUpdate", function(_, elapsed)
        elapsedAcc = elapsedAcc + (elapsed or 0)
        if elapsedAcc < TICK_INTERVAL then return end
        elapsedAcc = 0
        local db = AC.DB()
        if not db or not db.enabled then return end
        AC.ReconcileFreeLook()
        if AC.UpdateCameraSituation then AC.UpdateCameraSituation() end
        if AC.UpdateBDOMovement then AC.UpdateBDOMovement() end
        if AC.UpdateCrosshairReaction then AC.UpdateCrosshairReaction() end
        if AC.UpdateVignette then AC.UpdateVignette() end
        if AC.UpdateFocusNameplateMarker then AC.UpdateFocusNameplateMarker() end
    end)

    ApplyAll()
end

--------------------------------------------------------------------------------
-- Diagnóstico da mira: /azaath mira grava por 15 s (AzaathUIDB.actioncam.aimDiag)
-- o que está sob a mira e quem captura o mouse no centro da tela. Leitura fora do
-- jogo depois de /reload (SavedVariables do personagem).
--------------------------------------------------------------------------------
local function DiagName(unit)
    if not (_G.UnitExists and _G.UnitExists(unit)) then return "-" end
    local n = _G.UnitName(unit)
    if Azaath.IsSecret(n) then return "secreto" end
    local friend = _G.UnitIsFriend and _G.UnitIsFriend("player", unit)
    return tostring(n) .. (Azaath.IsSecret(friend) and "" or (friend and "(amigo)" or "(hostil)"))
end

local function DiagFoci()
    local list = {}
    local foci = _G.GetMouseFoci and _G.GetMouseFoci() or { _G.GetMouseFocus and _G.GetMouseFocus() }
    for _, f in ipairs(foci or {}) do
        if f and f.GetName then
            local ok, name = pcall(f.GetName, f)
            name = ok and name or nil
            if not name then
                local p = f.GetParent and f:GetParent()
                local okp, pn = pcall(function() return p and p:GetName() end)
                name = "(sem nome, pai " .. tostring(okp and pn or "?") .. ")"
            end
            local okv, vis = pcall(f.IsVisible, f)
            local oka, alpha = pcall(f.GetEffectiveAlpha, f)
            list[#list + 1] = name .. string.format("[%s a%.2f]", okv and tostring(vis) or "?", oka and alpha or -1)
        end
    end
    return #list > 0 and table.concat(list, ",") or "mundo"
end

local function CVarV(n)
    local get = _G.C_CVar and _G.C_CVar.GetCVar or _G.GetCVar
    local ok, v = pcall(get, n)
    return ok and tostring(v) or "?"
end

if Azaath.commands then
    Azaath.commands.mira = function()
        local db = AC.DB()
        if not db then return end
        db.aimDiag = {
            date("%H:%M:%S") .. " CVars: Interact=" .. CVarV("SoftTargetInteract") .. " IRange=" .. CVarV("SoftTargetInteractRange")
                .. " IArc=" .. CVarV("SoftTargetInteractArc") .. " Friend=" .. CVarV("SoftTargetFriend")
                .. " Enemy=" .. CVarV("SoftTargetEnemy") .. " reticle=" .. tostring(db.reticleTargeting)
                .. " hud=" .. tostring(db.interactionHUD),
        }
        Azaath:Print("diagnóstico da mira por 15 s: entre no Mouse Look (V) e mire em NPCs aliados; depois /reload.")
        local last, t0 = nil, GetTime()
        local ticker
        ticker = C_Timer.NewTicker(0.25, function()
            local line = "ml=" .. tostring(_G.IsMouselooking and _G.IsMouselooking())
                .. " mouseover=" .. DiagName("mouseover") .. " softinteract=" .. DiagName("softinteract")
                .. " softfriend=" .. DiagName("softfriend") .. " softenemy=" .. DiagName("softenemy")
                .. " target=" .. DiagName("target") .. " foco=" .. DiagFoci()
            if line ~= last and #db.aimDiag < 120 then
                db.aimDiag[#db.aimDiag + 1] = string.format("%.1fs ", GetTime() - t0) .. line
                last = line
            end
            if GetTime() - t0 > 15 then
                ticker:Cancel()
                Azaath:Print("diagnóstico da mira concluído. Dê /reload para gravar.")
            end
        end)
    end
end
