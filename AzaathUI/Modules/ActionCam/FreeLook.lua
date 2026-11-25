--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ActionCam/FreeLook.lua
    Máquina de estados do Mouse Look (Free Look), centralização do cursor sem
    tranco, Auto Cursor Unlock (janelas da Azaath + Blizzard + montarias + condições),
    ocultação de tooltips com espiada por modificador, pulso no cursor, embainhar
    armas, Flip Camera 180°, Swap Shoulder e Reset Mouse Look.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local _G = _G

local AC = Azaath.ActionCam or {}
Azaath.ActionCam = AC

local C_Timer               = _G.C_Timer
local CreateFrame           = _G.CreateFrame
local FlipCameraYaw         = _G.FlipCameraYaw
local GameTooltip           = _G.GameTooltip
local GameTooltip_SetDefaultAnchor = _G.GameTooltip_SetDefaultAnchor
local GetBindingKey         = _G.GetBindingKey
local GetCursorPosition     = _G.GetCursorPosition
local GetPetActionInfo      = _G.GetPetActionInfo
local GetSheathState        = _G.GetSheathState
local GetTime               = _G.GetTime
local InCinematic           = _G.InCinematic
local InCombatLockdown      = _G.InCombatLockdown
local IsAltKeyDown          = _G.IsAltKeyDown
local IsControlKeyDown      = _G.IsControlKeyDown
local IsInCinematicScene    = _G.IsInCinematicScene
local IsKeyDown             = _G.IsKeyDown
local IsMouseButtonDown     = _G.IsMouseButtonDown
local IsMouselooking        = _G.IsMouselooking
local IsShiftKeyDown        = _G.IsShiftKeyDown
local MouselookStart        = _G.MouselookStart
local MouselookStop         = _G.MouselookStop
local PlaySound             = _G.PlaySound
local SOUNDKIT              = _G.SOUNDKIT
local SpellIsTargeting      = _G.SpellIsTargeting
local ToggleSheath          = _G.ToggleSheath
local UIParent              = _G.UIParent
local UnitExists            = _G.UnitExists

local ipairs, pcall, tonumber, type = ipairs, pcall, tonumber, type

--------------------------------------------------------------------------------
-- Estado interno
--------------------------------------------------------------------------------
local azMouselookActive = false
local mouseLookCameraChromeActive = false
local freeLookOverride = false
local customLockOnceConsumed = false
local customUnlockOnceConsumed = false
local cursorModeShowTime = 0
local pendingTapSheath = false
local pendingSheathToken = 0

local MOUSE_LOOK_BINDING = "AZAATH_MOUSELOOK"
local HOLD_THRESHOLD = 0.3
local SPURIOUS_KEY_UP = 0.05
local SHEATH_POLL = 0.05
local SHEATH_DEBOUNCE_SEC = 1.5
local CENTERING_DIP_SPEED = 0.1

local MOUSE_BINDING_BUTTON = {
    BUTTON1 = "LeftButton",
    BUTTON2 = "RightButton",
    BUTTON3 = "MiddleButton",
    BUTTON4 = "Button4",
    BUTTON5 = "Button5",
}

--------------------------------------------------------------------------------
-- Janelas monitoradas para Auto Cursor Unlock (Azaath + Blizzard)
--------------------------------------------------------------------------------
local WATCHED_FRAMES = {
    -- Janelas nativas da AzaathUI
    "AzaathUIConfig",
    "AzaathUIEditor",
    "AzaathUIEditorInspector",
    "AzaathUIDialog",
    "AzaathUIInventory",
    "AzaathUILoot",
    "AzaathUIMerchant",
    "AzaathUICharacter",
    "AzaathUISheet",
    "AzaathUISpellbook",
    "AzaathUITalents",
    "AzaathUIWorldMap",
    "AzaathUIMapJournal",
    "AzaathUIMenu",
    "AzaathUITrackingMenu",
    "AzaathChatContextMenu",
    "AzaathUIRadialConsumablesEditor",
    -- Janelas da Blizzard
    "GameMenuFrame",
    "SettingsPanel",
    "InterfaceOptionsFrame",
    "VideoOptionsFrame",
    "KeyBindingFrame",
    "MacroFrame",
    "WorldMapFrame",
    "QuestLogFrame",
    "QuestFrame",
    "GossipFrame",
    "MerchantFrame",
    "MailFrame",
    "SendMailFrame",
    "OpenMailFrame",
    "AuctionFrame",
    "AuctionHouseFrame",
    "BankFrame",
    "CharacterFrame",
    "SpellBookFrame",
    "TalentFrame",
    "PlayerTalentFrame",
    "FriendsFrame",
    "GuildFrame",
    "CommunitiesFrame",
    "LFGParentFrame",
    "PVEFrame",
    "PVPFrame",
    "CollectionsJournal",
    "EncounterJournal",
    "AchievementFrame",
    "TradeFrame",
    "TradeSkillFrame",
    "CraftFrame",
    "ClassTrainerFrame",
    "TaxiFrame",
    "FlightMapFrame",
    "InspectFrame",
    "LootFrame",
    "DressUpFrame",
    "BarberShopFrame",
    "HelpFrame",
    "StaticPopup1",
    "StaticPopup2",
    "StaticPopup3",
    "StaticPopup4",
    "ContainerFrameCombinedBags",
}
for i = 1, 13 do
    WATCHED_FRAMES[#WATCHED_FRAMES + 1] = "ContainerFrame" .. i
end

local function IsAnyWatchedFrameVisible(list)
    if type(list) ~= "table" then return false end
    for _, name in ipairs(list) do
        local f = _G[name]
        if f and not (f.IsForbidden and f:IsForbidden()) then
            if f.IsVisible and f:IsVisible() then
                return true
            end
        end
    end
    return false
end

-- Painel da Blizzard aberto DE VERDADE. O gerenciador de painéis guarda o painel até ele ser
-- fechado por HideUIPanel; o addon fecha alguns com Hide() puro (Azaath.HidePanel, para não
-- contaminar), e aí GetUIPanel continua devolvendo um painel já escondido (ex.: SettingsPanel
-- depois do atalho do /azaath nas Opções), o que travava a tecla V até o /reload.
local function OpenUIPanel(pos)
    local f = _G.GetUIPanel and _G.GetUIPanel(pos)
    if not f or (f.IsForbidden and f:IsForbidden()) then return nil end
    if f.IsVisible and not f:IsVisible() then return nil end
    return f
end

local function IsBlizzardMenuOpen()
    local Menu = _G.Menu
    if not (Menu and Menu.GetManager) then return false end
    local ok, open = pcall(function() return Menu.GetManager():IsAnyMenuOpen() end)
    return ok and open == true
end

function AC.IsUnlockFrameVisible()
    local db = AC.DB()
    if _G.GetUIPanel then
        if OpenUIPanel("left") or OpenUIPanel("right") or OpenUIPanel("center") then
            return true
        end
    end
    if not db or not db.frameWatching then return false end
    if _G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus() then return true end
    if IsBlizzardMenuOpen() then return true end
    if IsAnyWatchedFrameVisible(WATCHED_FRAMES) then return true end
    if IsAnyWatchedFrameVisible(db.watchlist) then return true end
    return false
end

local INTERACTION_FRAMES = {
    MerchantFrame = true, BankFrame = true, AuctionFrame = true, AuctionHouseFrame = true,
    MailFrame = true, GossipFrame = true, QuestFrame = true, ClassTrainerFrame = true,
    TaxiFrame = true, FlightMapFrame = true, GuildBankFrame = true,
}

function AC.CloseUnlockWindows()
    local inCombat = InCombatLockdown()
    local closed = false
    local function TryHide(frame)
        if not frame or (frame.IsForbidden and frame:IsForbidden()) then return false end
        if not (frame.IsVisible and frame:IsVisible()) then return false end
        if inCombat and frame.IsProtected and frame:IsProtected() then return false end
        -- Sem HideUIPanel: chamado pelo addon contamina o gerenciador de painéis e a
        -- próxima janela de NPC abre com taint (ex.: compra de espaço no banco bloqueada).
        -- Janela de NPC: encerra a interação e o próprio jogo fecha a janela com segurança.
        local PIM = _G.C_PlayerInteractionManager
        if INTERACTION_FRAMES[frame:GetName() or ""] and PIM and PIM.ClearInteraction then
            pcall(PIM.ClearInteraction)
            return true
        end
        pcall(frame.Hide, frame)
        return true
    end
    if _G.GetUIPanel then
        for _, pos in ipairs({ "left", "center", "right" }) do
            if TryHide(_G.GetUIPanel(pos)) then closed = true end
        end
    end
    for _, name in ipairs(WATCHED_FRAMES) do
        if name ~= "ChatFrame1EditBox" and TryHide(_G[name]) then
            closed = true
        end
    end
    local db = AC.DB()
    if db and type(db.watchlist) == "table" then
        for _, name in ipairs(db.watchlist) do
            if TryHide(_G[name]) then closed = true end
        end
    end
    return closed
end

--------------------------------------------------------------------------------
-- Predicados de Auto Cursor Unlock
--------------------------------------------------------------------------------
local function HasPlayerAura(spellID)
    if _G.C_UnitAuras and _G.C_UnitAuras.GetPlayerAuraBySpellID then
        return _G.C_UnitAuras.GetPlayerAuraBySpellID(spellID) ~= nil
    end
    if _G.UnitAura then
        for i = 1, 40 do
            local _, _, _, _, _, _, _, _, _, id = _G.UnitAura("player", i)
            if not id then break end
            if id == spellID then return true end
        end
    end
    return false
end

local function IsVendorMountOut()
    local db = AC.DB()
    local csv = db and db.mountsToUnlock
    if type(csv) ~= "string" or csv == "" then return false end
    if _G.IsMounted and not _G.IsMounted() then return false end
    for token in csv:gmatch("%d+") do
        local id = tonumber(token)
        if id and HasPlayerAura(id) then return true end
    end
    return false
end

local function IsFeignDeathActive()
    return HasPlayerAura(5384)
end

local function IsInPetBattle()
    return _G.C_PetBattles and _G.C_PetBattles.IsInBattle and _G.C_PetBattles.IsInBattle() or false
end

local function EvalCustomCondition(code)
    if type(code) ~= "string" or code:match("^%s*$") then return false end
    local fn = _G.loadstring(code)
    if not fn then return false end
    local ok, res = pcall(fn)
    return ok and res == true
end

--------------------------------------------------------------------------------
-- Pet "Move To" ground targeting
--------------------------------------------------------------------------------
local petMoveToAt = nil
local petMoveToArmed = false
local petMoveToPoller = CreateFrame("Frame")
petMoveToPoller:Hide()
petMoveToPoller:SetScript("OnUpdate", function(self)
    if not petMoveToAt then self:Hide() return end
    local now = GetTime()
    if now - petMoveToAt > 10 or (IsKeyDown and IsKeyDown("ESCAPE")) then
        petMoveToAt = nil
        self:Hide()
        AC.ReconcileFreeLook()
        return
    end
    local anyDown = IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") or IsMouseButtonDown("MiddleButton")
    if not anyDown then
        petMoveToArmed = true
    elseif petMoveToArmed and now - petMoveToAt > 0.25 then
        petMoveToAt = nil
        self:Hide()
        AC.ReconcileFreeLook()
    end
end)

if _G.hooksecurefunc and _G.CastPetAction and GetPetActionInfo then
    _G.hooksecurefunc("CastPetAction", function(index)
        local name, _, isToken = GetPetActionInfo(index)
        if isToken and name == "PET_ACTION_MOVE_TO" then
            petMoveToAt = GetTime()
            petMoveToArmed = false
            petMoveToPoller:Show()
            AC.UnlockFreeLook()
        end
    end)
end

local function IsGroundTargeting()
    return (SpellIsTargeting and SpellIsTargeting()) or (petMoveToAt ~= nil)
end

--------------------------------------------------------------------------------
-- Embainhar armas (com debounce de 1.5s)
--------------------------------------------------------------------------------
local function CancelPendingSheath()
    pendingSheathToken = pendingSheathToken + 1
end

local function ApplyWeaponsSheathedNow(wantSheathed)
    local db = AC.DB()
    if not (db and db.sheathWeaponsWithMouselook) then return end
    if not (GetSheathState and ToggleSheath) then return end
    local state = GetSheathState()
    if not state then return end
    local isSheathed = (state == 1)
    if wantSheathed ~= isSheathed then
        ToggleSheath()
    end
end

local function ApplyWeaponsSheathed(wantSheathed)
    if not wantSheathed then
        CancelPendingSheath()
        ApplyWeaponsSheathedNow(false)
        return
    end
    local db = AC.DB()
    if not (db and db.sheathWeaponsWithMouselook) then return end
    CancelPendingSheath()
    local token = pendingSheathToken
    if C_Timer and C_Timer.After then
        C_Timer.After(SHEATH_DEBOUNCE_SEC, function()
            if token ~= pendingSheathToken or IsMouselooking() then return end
            ApplyWeaponsSheathedNow(true)
        end)
    else
        ApplyWeaponsSheathedNow(true)
    end
end

local function ShouldKeepWeaponsDrawnOnTempUnlock()
    if freeLookOverride then return true end
    if IsGroundTargeting() then return true end
    if AC.IsRadialMenuOpen and AC.IsRadialMenuOpen() then return true end
    return false
end

--------------------------------------------------------------------------------
-- Pulso visual no cursor ao destravar
--------------------------------------------------------------------------------
local pulseFrame, pulseTex, pulseAnim
local function EnsureCursorPulse()
    if pulseFrame then return pulseFrame end
    pulseFrame = CreateFrame("Frame", "AzaathUICursorPulse", UIParent)
    pulseFrame:SetSize(52, 52)
    pulseFrame:SetFrameStrata("TOOLTIP")
    pulseFrame:EnableMouse(false)
    pulseFrame:Hide()

    pulseTex = pulseFrame:CreateTexture(nil, "OVERLAY")
    pulseTex:SetAllPoints(pulseFrame)
    pulseTex:SetTexture(Azaath.media.path .. "Ring.tga")
    pulseTex:SetVertexColor(0.96, 0.78, 0.38, 0.9)
    pulseTex:SetBlendMode("ADD")

    local ag = pulseFrame:CreateAnimationGroup()
    local s1 = ag:CreateAnimation("Scale")
    s1:SetScaleFrom(0.35, 0.35)
    s1:SetScaleTo(1.35, 1.35)
    s1:SetDuration(0.32)
    s1:SetSmoothing("OUT")
    local a1 = ag:CreateAnimation("Alpha")
    a1:SetFromAlpha(0.95)
    a1:SetToAlpha(0)
    a1:SetDuration(0.32)
    a1:SetSmoothing("OUT")
    ag:SetScript("OnFinished", function() pulseFrame:Hide() end)
    pulseAnim = ag
    return pulseFrame
end

function AC.ShowCursorPulse()
    local f = EnsureCursorPulse()
    local x, y = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    f:ClearAllPoints()
    f:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    f:Show()
    pulseAnim:Stop()
    pulseAnim:Play()
end

--------------------------------------------------------------------------------
-- Ocultação de Tooltips no Mouse Look + Espiada por modificador
--------------------------------------------------------------------------------
local TOOLTIP_OFFSET_X = 40
local tooltipHidden = false
local isTooltipHooked = false
local tooltipRebuildPending = false

function AC.IsTooltipModifierDown()
    if InCombatLockdown() then return false end
    local db = AC.DB()
    local mod = db and db.tooltipModifier or "ALT"
    if mod == "CTRL" then return IsControlKeyDown() end
    if mod == "SHIFT" then return IsShiftKeyDown() end
    return IsAltKeyDown()
end

local function ShowMouseoverTooltip()
    local crosshair = _G.AzaathUICrosshairFrame
    if not crosshair or not UnitExists("mouseover") then
        GameTooltip:Hide()
        return
    end
    pcall(function()
        GameTooltip:Hide()
        GameTooltip:SetAlpha(1)
        GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
        GameTooltip:SetUnit("mouseover")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("LEFT", crosshair, "CENTER", TOOLTIP_OFFSET_X, 0)
    end)
end

function AC.OnTooltipModifierChanged(event)
    if not tooltipHidden then return end
    if not AC.IsTooltipModifierDown() then
        GameTooltip:SetAlpha(1)
        GameTooltip:Hide()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        tooltipRebuildPending = true
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                if tooltipRebuildPending and tooltipHidden and AC.IsTooltipModifierDown() then
                    tooltipRebuildPending = false
                    ShowMouseoverTooltip()
                end
            end)
        end
    else
        ShowMouseoverTooltip()
    end
end

local function SetTooltipHidden(shouldHide)
    tooltipHidden = shouldHide
    if not isTooltipHooked then
        GameTooltip:HookScript("OnShow", function(self)
            if tooltipHidden and not AC.IsTooltipModifierDown() and not AC.scanningTargetTooltip then
                self:Hide()
            end
        end)
        GameTooltip:HookScript("OnHide", function(self)
            if not (tooltipHidden and AC.IsTooltipModifierDown()) then
                self:SetAlpha(1)
            end
        end)
        isTooltipHooked = true
    end
    if tooltipHidden then
        if GameTooltip:IsShown() then GameTooltip:Hide() end
    else
        GameTooltip:SetAlpha(1)
    end
end

--------------------------------------------------------------------------------
-- Lógica principal de bloqueio/desbloqueio
--------------------------------------------------------------------------------
function AC.ShouldFreeLookBeOff()
    local db = AC.DB()
    if not db or not db.enabled then return true end

    local condLock = EvalCustomCondition(db.customLockCondition)
    if not condLock or not db.customLockConditionOnce then
        customLockOnceConsumed = false
    end
    local forceLock = condLock and not customLockOnceConsumed

    local condUnlock = EvalCustomCondition(db.customCondition)
    if not condUnlock or not db.customConditionOnce then
        customUnlockOnceConsumed = false
    end
    local forceUnlock = condUnlock and not customUnlockOnceConsumed

    if forceLock and freeLookOverride then
        freeLookOverride = false
        pendingTapSheath = false
        CancelPendingSheath()
    end

    if not forceLock and freeLookOverride then return true end
    if IsFeignDeathActive() or IsInPetBattle() then return true end
    if AC.IsRadialMenuOpen and AC.IsRadialMenuOpen() then return true end
    if IsGroundTargeting()
        or (InCinematic and InCinematic())
        or (IsInCinematicScene and IsInCinematicScene())
        or AC.IsUnlockFrameVisible()
        or IsVendorMountOut()
    then
        return true
    end
    if not forceLock and forceUnlock then return true end
    return false
end

local function HandleFreeLookUIState(isLocking)
    local db = AC.DB()
    if AC.DisplayCrosshair then
        AC.DisplayCrosshair(isLocking and db and db.crosshair)
    end
    if db and db.hideTooltip then
        SetTooltipHidden(isLocking)
    else
        SetTooltipHidden(false)
    end
    if isLocking then
        mouseLookCameraChromeActive = true
        AC.ApplyMouseLookCamera()
    elseif not db or not db.enabled or not freeLookOverride then
        mouseLookCameraChromeActive = false
        AC.ClearMouseLookCamera()
    end
    if AC.UpdateVignette then AC.UpdateVignette() end
end

local cameraSpeedRestoreScheduled = false
local function RestoreCameraSpeedAfterDip()
    cameraSpeedRestoreScheduled = false
    AC.EndCameraSpeedDip()
end

local function StartFreeLookFresh()
    local db = AC.DB()
    if db and db.crosshair and AC.BeginCameraSpeedDip(CENTERING_DIP_SPEED) then
        if not cameraSpeedRestoreScheduled and C_Timer and C_Timer.After then
            cameraSpeedRestoreScheduled = true
            C_Timer.After(0, RestoreCameraSpeedAfterDip)
        end
        AC.SetCursorFreelookCenteringCVar(true)
        MouselookStart()
        MouselookStop()
    end
    AC.SetCursorFreelookCenteringCVar(false)
    MouselookStart()
    azMouselookActive = true
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            AC.SetCursorFreelookCenteringCVar(false)
            HandleFreeLookUIState(true)
        end)
    else
        HandleFreeLookUIState(true)
    end
    if AC.ShowCrosshairLockIn then AC.ShowCrosshairLockIn() end
end

local FREELOOK_SOUND = (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON) or 856
local lastSoundTime = 0
local function PlayFreeLookSound()
    local db = AC.DB()
    if not (db and db.soundMouseLook) then return end
    local now = GetTime()
    if PlaySound and now - lastSoundTime >= 0.15 then
        lastSoundTime = now
        PlaySound(FREELOOK_SOUND, "Master", true)
    end
end

function AC.LockFreeLook()
    if IsMouselooking() then return end
    StartFreeLookFresh()
    PlayFreeLookSound()
    CancelPendingSheath()
    if not freeLookOverride then
        ApplyWeaponsSheathed(false)
    end
end

function AC.UnlockFreeLook()
    if not IsMouselooking() then return end
    azMouselookActive = false
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            AC.SetCursorFreelookCenteringCVar(false)
            HandleFreeLookUIState(false)
        end)
    else
        HandleFreeLookUIState(false)
    end
    MouselookStop()
    PlayFreeLookSound()
    local db = AC.DB()
    if db and db.pulseCursor then
        AC.ShowCursorPulse()
    end
    if not ShouldKeepWeaponsDrawnOnTempUnlock() then
        ApplyWeaponsSheathed(true)
    end
end

function AC.ReconcileFreeLook()
    local db = AC.DB()
    if not db or not db.enabled then
        if azMouselookActive then AC.UnlockFreeLook() end
        return
    end
    if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
        return
    end
    if AC.ShouldFreeLookBeOff() then
        if IsMouselooking() and azMouselookActive then
            AC.UnlockFreeLook()
        end
    else
        if not IsMouselooking() then
            AC.LockFreeLook()
        end
    end
end

function AC.IsMouselooking()
    return azMouselookActive and IsMouselooking()
end

function AC.IsMouseLookCameraChromeActive()
    return mouseLookCameraChromeActive
end

--------------------------------------------------------------------------------
-- Keybinds globais (Bindings.xml)
--------------------------------------------------------------------------------
local function IsMouseLookBindingKeyDown()
    if not GetBindingKey then return false end
    local k1, k2 = GetBindingKey(MOUSE_LOOK_BINDING)
    for i = 1, 2 do
        local key = (i == 1) and k1 or k2
        if key then
            if IsKeyDown and IsKeyDown(key) then return true end
            local mb = MOUSE_BINDING_BUTTON[key]
            if mb and IsMouseButtonDown(mb) then return true end
        end
    end
    return false
end

local function ClearMouseLookCameraChrome()
    if not mouseLookCameraChromeActive then return end
    mouseLookCameraChromeActive = false
    AC.ClearMouseLookCamera()
    if AC.UpdateVignette then AC.UpdateVignette() end
end

local function ScheduleTapSheathPoll()
    pendingTapSheath = true
    if not (C_Timer and C_Timer.After) then
        pendingTapSheath = false
        return
    end
    local function poll()
        if not pendingTapSheath then return end
        if not freeLookOverride then pendingTapSheath = false return end
        local elapsed = GetTime() - cursorModeShowTime
        if IsMouseLookBindingKeyDown() then
            if elapsed >= HOLD_THRESHOLD then
                pendingTapSheath = false
                return
            end
            C_Timer.After(SHEATH_POLL, poll)
            return
        end
        if elapsed < SPURIOUS_KEY_UP then
            C_Timer.After(SHEATH_POLL, poll)
            return
        end
        pendingTapSheath = false
        if IsMouselooking() then return end
        ApplyWeaponsSheathed(true)
        ClearMouseLookCameraChrome()
    end
    C_Timer.After(SPURIOUS_KEY_UP, poll)
end

-- diagnóstico (AzaathUIDB.actioncam.vDiag): por que a tecla V não travou a câmera
local function FreeLookBlockReason()
    local why = {}
    local function add(s) why[#why + 1] = s end
    if freeLookOverride then add("override") end
    if IsFeignDeathActive() then add("fingirMorte") end
    if IsInPetBattle() then add("batalhaPet") end
    if AC.IsRadialMenuOpen and AC.IsRadialMenuOpen() then add("radial") end
    if IsGroundTargeting() then add("miraNoChao") end
    if (InCinematic and InCinematic()) or (IsInCinematicScene and IsInCinematicScene()) then add("cinematica") end
    if IsVendorMountOut() then add("montariaVendedor") end
    if _G.GetUIPanel then
        for _, p in ipairs({ "left", "center", "right" }) do
            local f = OpenUIPanel(p)
            if f then add("painel:" .. tostring(f:GetName())) end
        end
    end
    local kf = _G.GetCurrentKeyBoardFocus and _G.GetCurrentKeyBoardFocus()
    if kf then add("foco:" .. tostring(kf:GetName())) end
    if IsBlizzardMenuOpen() then add("menuBlizzard") end
    local db = AC.DB()
    for _, list in ipairs({ WATCHED_FRAMES, db and db.watchlist or {} }) do
        for _, name in ipairs(list) do
            local f = _G[name]
            if f and not (f.IsForbidden and f:IsForbidden()) and f.IsVisible and f:IsVisible() then
                add("janela:" .. name .. "(alpha " .. string.format("%.2f", f:GetEffectiveAlpha()) .. ")")
            end
        end
    end
    if db and EvalCustomCondition(db.customCondition) then add("condicaoCustom") end
    return #why > 0 and table.concat(why, " ") or "nenhum"
end

local function RecordVDiag(msg)
    local db = AC.DB()
    if db then db.vDiag = date("%H:%M:%S") .. " " .. msg end
end

function _G.AZAATH_MouseLookKey(keystate)
    local db = AC.DB()
    if not db or not db.enabled then return end
    if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then
        if keystate == "down" then RecordVDiag("botaoMouse") end
        return
    end
    if keystate == "down" and not IsMouselooking() then
        local base = FreeLookBlockReason()
        RecordVDiag(base)
        if not AC._vStopHooked and hooksecurefunc then
            AC._vStopHooked = true
            hooksecurefunc("MouselookStop", function()
                local d = AC.DB()
                if d and AC._vWatchUntil and GetTime() < AC._vWatchUntil then
                    d.vDiagStop = (d.vDiagStop or "") .. " | " .. date("%H:%M:%S") .. " "
                        .. (debugstack and debugstack(2, 4, 0) or "?")
                end
            end)
        end
        local d = AC.DB()
        if d then d.vDiagStop = "" end
        AC._vWatchUntil = GetTime() + 1.5
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                RecordVDiag(base .. " | depois: mouselook=" .. tostring(IsMouselooking())
                    .. " az=" .. tostring(azMouselookActive))
            end)
            C_Timer.After(0.5, function()
                local d2 = AC.DB()
                if d2 and d2.vDiag then
                    d2.vDiag = d2.vDiag .. " | 0.5s: mouselook=" .. tostring(IsMouselooking())
                        .. " az=" .. tostring(azMouselookActive)
                        .. " override=" .. tostring(freeLookOverride)
                end
            end)
        end
    end

    if keystate == "down" then
        if not IsMouselooking() then
            local unlockOnce = db.customConditionOnce and EvalCustomCondition(db.customCondition)
            if unlockOnce then customUnlockOnceConsumed = true end
            if not unlockOnce and db.closeWindowsOnMouseLook and AC.IsUnlockFrameVisible() and AC.CloseUnlockWindows() then
                pendingTapSheath = false
                CancelPendingSheath()
                freeLookOverride = false
                cursorModeShowTime = 0
                AC.ReconcileFreeLook()
                return
            end
            if freeLookOverride or unlockOnce or not AC.ShouldFreeLookBeOff() then
                pendingTapSheath = false
                CancelPendingSheath()
                AC.LockFreeLook()
                freeLookOverride = false
                cursorModeShowTime = 0
                ApplyWeaponsSheathed(false)
            end
        else
            if EvalCustomCondition(db.customLockCondition) then
                if not db.customLockConditionOnce then return end
                customLockOnceConsumed = true
            end
            cursorModeShowTime = GetTime()
            freeLookOverride = true
            AC.UnlockFreeLook()
            ScheduleTapSheathPoll()
        end
    elseif keystate == "up" then
        if not freeLookOverride then return end
        if (GetTime() - cursorModeShowTime) < HOLD_THRESHOLD then return end
        pendingTapSheath = false
        CancelPendingSheath()
        AC.LockFreeLook()
        freeLookOverride = false
    end
end

local flipPressedAt
function _G.AZAATH_FlipCameraKey(keystate)
    if not FlipCameraYaw then return end
    if keystate == "down" then
        flipPressedAt = GetTime()
        pcall(FlipCameraYaw, 180)
    elseif keystate == "up" then
        if not flipPressedAt then return end
        local held = GetTime() - flipPressedAt
        flipPressedAt = nil
        if held >= HOLD_THRESHOLD then
            pcall(FlipCameraYaw, 180)
        end
    end
end

function _G.AZAATH_SwapShoulder()
    local db = AC.DB()
    if not db then return end
    db.shoulderOffset = -(tonumber(db.shoulderOffset) or 0)
    if AC.IsMouseLookCameraChromeActive() then
        AC.SetShoulderOffset(db.shoulderOffset, false)
    end
end

--------------------------------------------------------------------------------
-- Ctrl alterna o Mouse Look (opção ctrlToggle): toque limpo no Ctrl = toque no V.
-- Ctrl+tecla, Ctrl+clique ou segurar (> CTRL_TAP_MAX) não alternam.
--------------------------------------------------------------------------------
-- Sem quadro de teclado (EnableKeyboard travava o ESC): Ctrl+tecla é detectado
-- por magia enviada durante o toque (UNIT_SPELLCAST_SENT) e pelo tempo curto.
local CTRL_TAP_MAX = 0.35
local ctrlDownAt, ctrlCombo

function AC.OnCtrlToggleModifier(key, down)
    if key ~= "LCTRL" and key ~= "RCTRL" then
        if ctrlDownAt and down == 1 then ctrlCombo = true end
        return
    end
    local db = AC.DB()
    if not (db and db.enabled and db.ctrlToggle) then ctrlDownAt = nil return end
    if down == 1 then
        ctrlDownAt, ctrlCombo = GetTime(), false
        return
    end
    local t0 = ctrlDownAt
    ctrlDownAt = nil
    if not t0 or ctrlCombo or (GetTime() - t0) > CTRL_TAP_MAX then return end
    if IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton") then return end
    _G.AZAATH_MouseLookKey("down")
end

function AC.OnCtrlToggleMouseDown()
    if ctrlDownAt then ctrlCombo = true end
end

function _G.AZAATH_ResetMouseLook()
    AC.LockFreeLook()
    local function settle()
        if AC.ShouldFreeLookBeOff() then
            AC.UnlockFreeLook()
        end
    end
    if C_Timer and C_Timer.After then
        C_Timer.After(0, settle)
    else
        settle()
    end
end
