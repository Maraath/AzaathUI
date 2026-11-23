--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ActionCam/CVarManager.lua
    Gerenciador de CVars da Câmera Action (SoftTarget / Reticle, ActionCam,
    Ombro com tween, Inclinação Dinâmica, Motion Sickness, Zoom Mínimo e
    redução de velocidade de 1 frame para centralização do cursor sem tranco).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local _G = _G

local AC = Azaath.ActionCam or {}
Azaath.ActionCam = AC

local C_Timer          = _G.C_Timer
local CreateFrame      = _G.CreateFrame
local GetTime          = _G.GetTime
local UnitExists       = _G.UnitExists
local UnitCanAttack    = _G.UnitCanAttack
local GetCameraZoom    = _G.GetCameraZoom
local CameraZoomOut    = _G.CameraZoomOut
local UIParent         = _G.UIParent

local pairs, ipairs, pcall, tonumber, tostring, type = pairs, ipairs, pcall, tonumber, tostring, type
local min, max, abs, floor = math.min, math.max, math.abs, math.floor

--------------------------------------------------------------------------------
-- Helpers seguros de CVar
--------------------------------------------------------------------------------
local function GetCVar(name)
    if _G.C_CVar and _G.C_CVar.GetCVar then
        return _G.C_CVar.GetCVar(name)
    elseif _G.GetCVar then
        return _G.GetCVar(name)
    end
end

local function SetCVar(name, value)
    if value == nil then return end
    if _G.C_CVar and _G.C_CVar.SetCVar then
        return pcall(_G.C_CVar.SetCVar, name, tostring(value))
    elseif _G.SetCVar then
        return pcall(_G.SetCVar, name, tostring(value))
    end
end

AC.GetCVar = GetCVar
AC.SetCVar = SetCVar

--------------------------------------------------------------------------------
-- Acesso ao DB da Câmera Action (global + perfil por personagem)
--------------------------------------------------------------------------------
local charKeyCache
function AC.GetCharKey()
    if not charKeyCache then
        local name = _G.UnitName and _G.UnitName("player") or "Player"
        local realm = _G.GetRealmName and _G.GetRealmName() or "Realm"
        charKeyCache = name .. " - " .. realm
    end
    return charKeyCache
end

function AC.DB()
    return Azaath.db and Azaath.db.actioncam
end

function AC.GetBindingsTable()
    local db = AC.DB()
    if not db then return {} end
    if db.useGlobalBindings ~= false then
        return db.bindings
    end
    db.chars = db.chars or {}
    local ck = AC.GetCharKey()
    db.chars[ck] = db.chars[ck] or {}
    if not db.chars[ck].bindings then
        db.chars[ck].bindings = {}
        for k, v in pairs(db.bindings) do
            db.chars[ck].bindings[k] = {
                enabled   = v.enabled,
                key       = v.key,
                value     = v.value,
                macroName = v.macroName,
            }
        end
    end
    return db.chars[ck].bindings
end

--------------------------------------------------------------------------------
-- Tabelas de CVars
--------------------------------------------------------------------------------
local RETICLE_CVARS = {
    interactKeyWarningTutorial      = 1,
    deselectOnClick                 = 1,
    enableMouseoverCast             = 0,
    SoftTargetForce                 = 0,
    SoftTargetMatchLocked           = 1,
    SoftTargetWithLocked            = 2,
    SoftTargetEnemy                 = 3,
    SoftTargetEnemyArc              = 0,
    SoftTargetEnemyRange            = 60,
    SoftTargetInteract              = 2,
    SoftTargetInteractArc           = 0,
    SoftTargetInteractRange         = 40,
    SoftTargetFriend                = 0,
    SoftTargetFriendArc             = 0,
    SoftTargetFriendRange           = 60,
    SoftTargetNameplateEnemy        = 0,
    SoftTargetIconEnemy             = 0,
    SoftTargetIconFriend            = 0,
    SoftTargetIconInteract          = 0,
    SoftTargetIconGameObject        = 0,
    Outline                         = 3,
    outlineMouseOverFadeDuration    = 3600,
    outlineSelectionFadeDuration    = 3600,
    ObjectSelectionCircle           = 0,
    UnitNameFocused                 = 0,
    CursorFreelookCentering         = 0,
    CursorStickyCentering           = 1,
}

local INTERACT_ONLY_CVARS = {
    interactKeyWarningTutorial = 1,
    SoftTargetInteract         = 3,
    SoftTargetInteractArc      = 2,
    SoftTargetInteractRange    = 30,
    SoftTargetIconFriend       = 0,
    SoftTargetIconInteract     = 0,
    SoftTargetIconGameObject   = 0,
}

local BLIZZARD_DEFAULTS = {
    SoftTargetEnemy                         = 1,
    SoftTargetEnemyArc                      = 2,
    SoftTargetEnemyRange                    = 45,
    SoftTargetInteract                      = 1,
    SoftTargetInteractArc                   = 0,
    SoftTargetInteractRange                 = 10,
    SoftTargetIconEnemy                     = 0,
    SoftTargetIconFriend                    = 0,
    SoftTargetIconInteract                  = 0,
    SoftTargetIconGameObject                = 0,
    CursorStickyCentering                   = 0,
    CursorFreelookCentering                 = 0,
    Outline                                 = 2,
    outlineMouseOverFadeDuration            = 0.9,
    outlineSelectionFadeDuration            = 0.32,
    ObjectSelectionCircle                   = 1,
    UnitNameFocused                         = 1,
    test_cameraDynamicPitch                 = 0,
    test_cameraDynamicPitchBaseFovPad       = 0.4,
    test_cameraDynamicPitchBaseFovPadFlying = 0.75,
    test_cameraDynamicPitchBaseFovPadDownScale = 0.25,
    test_cameraDynamicPitchSmartPivotCutoffDist = 10,
    test_cameraOverShoulder                 = 0,
    CameraKeepCharacterCentered             = 1,
    CameraReduceUnexpectedMovement          = 1,
    test_cameraTargetFocusEnemyEnable       = 0,
    test_cameraTargetFocusEnemyStrengthYaw  = 0.4,
    test_cameraTargetFocusEnemyStrengthPitch = 0.5,
    test_cameraHeadMovementStrength         = 0,
    test_cameraHeadMovementMovingStrength   = 0.5,
    test_cameraHeadMovementStandingStrength = 0.3,
    test_cameraHeadMovementRangeScale       = 5,
    test_cameraHeadMovementMovingDampRate   = 10,
    test_cameraHeadMovementStandingDampRate = 10,
    cameraSmoothStyle                       = 4,
    cameraZoomSpeed                         = 20,
}

local MANAGED_CVARS = {}
do
    local seen = {}
    local function add(t)
        for k in pairs(t) do
            if not seen[k] then
                seen[k] = true
                MANAGED_CVARS[#MANAGED_CVARS + 1] = k
            end
        end
    end
    add(RETICLE_CVARS)
    add(INTERACT_ONLY_CVARS)
    add(BLIZZARD_DEFAULTS)
    for _, k in ipairs({ "cameraYawMoveSpeed", "cameraPitchMoveSpeed", "CursorCenteredYPos" }) do
        if not seen[k] then
            seen[k] = true
            MANAGED_CVARS[#MANAGED_CVARS + 1] = k
        end
    end
end

--------------------------------------------------------------------------------
-- Snapshot / Restauração de CVars
--------------------------------------------------------------------------------
local restoringCVars = false

function AC.CapturePriorCVarSnapshot()
    if restoringCVars then return end
    local db = AC.DB()
    if not db then return end
    if type(db.priorCVarSnapshot) == "table" and next(db.priorCVarSnapshot) ~= nil then
        return
    end
    local snap = {}
    for _, name in ipairs(MANAGED_CVARS) do
        local v = GetCVar(name)
        if v ~= nil then snap[name] = v end
    end
    db.priorCVarSnapshot = snap
end

function AC.RestorePriorCVars()
    local db = AC.DB()
    local snap = db and db.priorCVarSnapshot
    restoringCVars = true
    for _, name in ipairs(MANAGED_CVARS) do
        local targetVal = (snap and snap[name] ~= nil) and snap[name] or BLIZZARD_DEFAULTS[name]
        if targetVal ~= nil then
            SetCVar(name, targetVal)
        end
    end
    restoringCVars = false
end

--------------------------------------------------------------------------------
-- Redução de velocidade da câmera por 1 frame (centralização sem tranco 10.2+)
--------------------------------------------------------------------------------
local cameraSpeedDipPending = false
local cameraSpeedDipRestore = {}

function AC.BeginCameraSpeedDip(dipSpeed)
    if cameraSpeedDipPending then return true end
    local curYaw = GetCVar("cameraYawMoveSpeed")
    local curPitch = GetCVar("cameraPitchMoveSpeed")
    cameraSpeedDipRestore.cameraYawMoveSpeed = curYaw
    cameraSpeedDipRestore.cameraPitchMoveSpeed = curPitch
    SetCVar("cameraYawMoveSpeed", dipSpeed)
    SetCVar("cameraPitchMoveSpeed", dipSpeed)
    local actual = tonumber(GetCVar("cameraYawMoveSpeed"))
    if not actual or abs(actual - dipSpeed) > 0.05 then
        if curYaw then SetCVar("cameraYawMoveSpeed", curYaw) end
        if curPitch then SetCVar("cameraPitchMoveSpeed", curPitch) end
        return false
    end
    cameraSpeedDipPending = true
    return true
end

function AC.EndCameraSpeedDip()
    if not cameraSpeedDipPending then return end
    cameraSpeedDipPending = false
    if cameraSpeedDipRestore.cameraYawMoveSpeed then
        SetCVar("cameraYawMoveSpeed", cameraSpeedDipRestore.cameraYawMoveSpeed)
    end
    if cameraSpeedDipRestore.cameraPitchMoveSpeed then
        SetCVar("cameraPitchMoveSpeed", cameraSpeedDipRestore.cameraPitchMoveSpeed)
    end
    cameraSpeedDipRestore = {}
end

function AC.ApplyMouseLookSpeed()
    local db = AC.DB()
    if not db or not db.enabled then return end
    local speed = tonumber(db.mouseLookSpeed) or 100
    -- Blizzard padrão: yaw ~180, pitch ~90 (ou escala proporcional ao valor do slider 100 = padrão)
    local yaw = floor(180 * (speed / 100) + 0.5)
    local pitch = floor(90 * (speed / 100) + 0.5)
    if not cameraSpeedDipPending then
        SetCVar("cameraYawMoveSpeed", yaw)
        SetCVar("cameraPitchMoveSpeed", pitch)
    else
        cameraSpeedDipRestore.cameraYawMoveSpeed = yaw
        cameraSpeedDipRestore.cameraPitchMoveSpeed = pitch
    end
end

function AC.SetCursorFreelookCenteringCVar(enabled)
    SetCVar("CursorFreelookCentering", enabled and 1 or 0)
end

function AC.SyncCursorCenteredYPos()
    local db = AC.DB()
    if not db then return end
    local h = UIParent and UIParent:GetHeight() or 1080
    local yOff = tonumber(db.crosshairY) or 100
    -- CursorCenteredYPos: 0 = fundo, 0.5 = centro, 1 = topo
    local norm = 0.5 + (yOff / max(1, h))
    norm = max(0.05, min(0.95, norm))
    SetCVar("CursorCenteredYPos", string.format("%.4f", norm))
end

--------------------------------------------------------------------------------
-- Ombro com tween suave (test_cameraOverShoulder) + Motion Sickness + Pitch
--------------------------------------------------------------------------------
AC.FADE_DURATION = 0.35

local shoulderTweenFrame = CreateFrame("Frame")
shoulderTweenFrame:Hide()
local shoulderFrom = 0
local shoulderTo = 0
local shoulderStart = 0
local shoulderGoal = 0

shoulderTweenFrame:SetScript("OnUpdate", function(self)
    local now = GetTime()
    local t = (now - shoulderStart) / AC.FADE_DURATION
    if t >= 1 then
        SetCVar("test_cameraOverShoulder", shoulderTo)
        self:Hide()
        return
    end
    -- Smoothstep
    local s = t * t * (3 - 2 * t)
    local cur = shoulderFrom + (shoulderTo - shoulderFrom) * s
    SetCVar("test_cameraOverShoulder", string.format("%.3f", cur))
end)

function AC.GetCurrentShoulderTarget()
    return shoulderGoal
end

function AC.SetShoulderOffset(targetOffset, instant)
    targetOffset = tonumber(targetOffset) or 0
    shoulderGoal = targetOffset
    local cur = tonumber(GetCVar("test_cameraOverShoulder")) or 0
    if instant or abs(cur - targetOffset) < 0.01 then
        shoulderTweenFrame:Hide()
        SetCVar("test_cameraOverShoulder", string.format("%.3f", targetOffset))
        return
    end
    shoulderFrom = cur
    shoulderTo = targetOffset
    shoulderStart = GetTime()
    shoulderTweenFrame:Show()
end

function AC.ApplyBDOCameraInertia()
    local db = AC.DB()
    if not db or not db.enabled then return end
    -- Câmera livre estilo BDO: não força auto-rotação atrás do personagem ao andar de lado/costas
    SetCVar("cameraSmoothStyle", 0)
    -- Zoom suave para não tremer ao girar o scroll do mouse
    SetCVar("cameraZoomSpeed", 18)
    if db.bdoEnabled ~= false and db.bdoCameraInertia ~= false and not db.respectMotionSickness then
        local intensity = max(0.25, min(1.0, tonumber(db.bdoIntensity) or 0.70))
        AC.ApplyMotionSicknessGate(true)
        SetCVar("test_cameraHeadMovementStrength", string.format("%.2f", 0.90 * intensity))
        SetCVar("test_cameraHeadMovementMovingStrength", "0.85")
        SetCVar("test_cameraHeadMovementStandingStrength", "0.00")
        SetCVar("test_cameraHeadMovementRangeScale", "5.00")
        SetCVar("test_cameraHeadMovementMovingDampRate", "5.5")
        SetCVar("test_cameraHeadMovementStandingDampRate", "10.0")
    else
        SetCVar("test_cameraHeadMovementStrength", 0)
    end
end

function AC.ApplyMotionSicknessGate(needActionCam)
    local db = AC.DB()
    if not db then return end
    if db.respectMotionSickness then return end
    local val = needActionCam and 0 or 1
    SetCVar("CameraKeepCharacterCentered", val)
    SetCVar("CameraReduceUnexpectedMovement", val)
end

function AC.ApplyDynamicPitch()
    local db = AC.DB()
    if not db or not db.enabled then return end
    if db.dynamicPitch then
        local base = tonumber(db.dynamicPitchStrength) or 0.4
        local flying = min(1, base * (0.75 / 0.4))
        SetCVar("test_cameraDynamicPitch", 1)
        SetCVar("test_cameraDynamicPitchBaseFovPad", string.format("%.2f", base))
        SetCVar("test_cameraDynamicPitchBaseFovPadFlying", string.format("%.2f", flying))
        SetCVar("test_cameraDynamicPitchBaseFovPadDownScale", 0.25)
        SetCVar("test_cameraDynamicPitchSmartPivotCutoffDist", 39)
        AC.ApplyMotionSicknessGate(true)
    else
        SetCVar("test_cameraDynamicPitch", 0)
    end
end

function AC.ApplyMouseLookCamera()
    local db = AC.DB()
    if not db or not db.enabled then return end
    local shoulder = tonumber(db.shoulderOffset) or 0
    if abs(shoulder) > 0.01 or db.dynamicPitch or db.autofocusLockedTarget then
        AC.ApplyMotionSicknessGate(true)
    end
    AC.SetShoulderOffset(shoulder, false)
    AC.ApplyDynamicPitch()
end

function AC.ClearMouseLookCamera()
    local db = AC.DB()
    if not db then return end
    if db.shoulderFollowsMouseLook then
        AC.SetShoulderOffset(0, false)
    end
    if not db.dynamicPitch and not db.autofocusLockedTarget then
        AC.ApplyMotionSicknessGate(false)
    end
end

function AC.SyncTargetFocusFromFocusUnit()
    local db = AC.DB()
    if not db or not db.enabled or not db.autofocusLockedTarget then
        SetCVar("test_cameraTargetFocusEnemyEnable", 0)
        return
    end
    local hasHostileFocus = UnitExists("focus") and UnitCanAttack("player", "focus")
    if hasHostileFocus then
        AC.ApplyMotionSicknessGate(true)
        SetCVar("test_cameraTargetFocusEnemyEnable", 1)
        SetCVar("test_cameraTargetFocusEnemyStrengthYaw", 0.7)
        SetCVar("test_cameraTargetFocusEnemyStrengthPitch", 0.2)
    else
        SetCVar("test_cameraTargetFocusEnemyEnable", 0)
    end
end

--------------------------------------------------------------------------------
-- Reticle Targeting CVars (SoftTarget + Outline + Selection Circle)
--------------------------------------------------------------------------------
function AC.ApplyReticleCVars()
    local db = AC.DB()
    if not db or not db.enabled then return end

    if db.reticleTargeting then
        for k, v in pairs(RETICLE_CVARS) do
            SetCVar(k, v)
        end
        -- Outline
        if db.reticleOutline then
            SetCVar("Outline", 3)
            SetCVar("outlineMouseOverFadeDuration", 3600)
            SetCVar("outlineSelectionFadeDuration", 3600)
        else
            SetCVar("Outline", 0)
            SetCVar("outlineMouseOverFadeDuration", 0.9)
            SetCVar("outlineSelectionFadeDuration", 0.32)
        end
        -- Selection Circle
        local sc = db.selectionCircleMode or "target"
        if sc == "target" then
            SetCVar("ObjectSelectionCircle", 1)
            SetCVar("UnitNameFocused", 0)
            SetCVar("SoftTargetMatchLocked", 1)
        elseif sc == "locked" then
            SetCVar("ObjectSelectionCircle", 1)
            SetCVar("UnitNameFocused", 0)
            SetCVar("SoftTargetMatchLocked", 1)
        elseif sc == "soft" then
            SetCVar("ObjectSelectionCircle", 1)
            SetCVar("UnitNameFocused", 1)
            SetCVar("SoftTargetMatchLocked", 0)
        else -- "hidden"
            SetCVar("ObjectSelectionCircle", 0)
            SetCVar("UnitNameFocused", 0)
        end
        -- Ícones nativos da Blizzard se o InteractionHUD estiver desligado
        if not db.interactionHUD then
            SetCVar("SoftTargetIconFriend", 1)
            SetCVar("SoftTargetIconInteract", 1)
            SetCVar("SoftTargetIconGameObject", 1)
        end
    else
        -- Restaura SoftTargetEnemy para padrão Blizzard
        SetCVar("SoftTargetEnemy", BLIZZARD_DEFAULTS.SoftTargetEnemy)
        SetCVar("SoftTargetEnemyArc", BLIZZARD_DEFAULTS.SoftTargetEnemyArc)
        SetCVar("SoftTargetEnemyRange", BLIZZARD_DEFAULTS.SoftTargetEnemyRange)
        SetCVar("Outline", BLIZZARD_DEFAULTS.Outline)
        SetCVar("ObjectSelectionCircle", BLIZZARD_DEFAULTS.ObjectSelectionCircle)
        SetCVar("UnitNameFocused", BLIZZARD_DEFAULTS.UnitNameFocused)
        if db.interactionHUD then
            for k, v in pairs(INTERACT_ONLY_CVARS) do
                SetCVar(k, v)
            end
        end
    end

    AC.SyncCursorCenteredYPos()
end

--------------------------------------------------------------------------------
-- Zoom Mínimo da Câmera (minCameraZoom)
--------------------------------------------------------------------------------
local zoomHooked = false
local function EnforceMinCameraZoom()
    if AC.npcCinematicActive then return end
    local db = AC.DB()
    if not db or not db.enabled then return end
    local minZoom = tonumber(db.minCameraZoom) or 0
    if minZoom <= 0 or not GetCameraZoom or not CameraZoomOut then return end
    local cur = GetCameraZoom()
    if cur and cur < minZoom then
        CameraZoomOut(minZoom - cur)
    end
end

function AC.ApplyMinCameraZoom()
    local db = AC.DB()
    if not db or not db.enabled then return end
    if not zoomHooked and _G.hooksecurefunc and _G.CameraZoomIn then
        zoomHooked = true
        _G.hooksecurefunc("CameraZoomIn", function()
            if C_Timer and C_Timer.After then
                C_Timer.After(0, EnforceMinCameraZoom)
            else
                EnforceMinCameraZoom()
            end
        end)
    end
    EnforceMinCameraZoom()
end
