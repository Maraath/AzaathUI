--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ActionCam/CombatCamera.lua
    Câmera de Combate estilo Black Desert Online (BDO) com física em duas camadas:
    1) Oscilador de impacto rápido (hit-shake de alta frequência e decaimento
       veloz) para sensação visceral ao acertar golpes, habilidades e críticos
    2) Mola criticamente amortecida de 2ª ordem para recuo suave, foco de
       conjuração e respiração dinâmica de velocidade (corrida / montaria)
    3) Micro-punch de zoom em acertos críticos + enquadramento de combate
------------------------------------------------------------------------------]]

local _, Azaath = ...
local _G = _G

local AC = Azaath.ActionCam or {}
Azaath.ActionCam = AC

local C_Timer             = _G.C_Timer
local CameraZoomIn        = _G.CameraZoomIn
local CameraZoomOut       = _G.CameraZoomOut
local CreateFrame         = _G.CreateFrame
local GetCameraZoom       = _G.GetCameraZoom
local GetTime             = _G.GetTime
local GetUnitSpeed        = _G.GetUnitSpeed
local IsMounted           = _G.IsMounted
local PlaySound           = _G.PlaySound
local SOUNDKIT            = _G.SOUNDKIT or {}
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitCanAttack       = _G.UnitCanAttack
local UnitExists          = _G.UnitExists

local abs, cos, exp, max, min, sin = math.abs, math.cos, math.exp, math.max, math.min, math.sin

--------------------------------------------------------------------------------
-- Estado da física (Mola suave + Oscilador de Hit-Shake)
--------------------------------------------------------------------------------
local animFrame = CreateFrame("Frame", "AzaathUIBDOCameraDriver", _G.UIParent)
local animActive = false

-- Camada 1: Micro-tremor direcional de impacto (BDO hit-shake)
local shakeAmpX, shakeAmpY = 0, 0
local shakePhase           = 0

-- Camada 2: Mola de recuo e enquadramento
local shoulderPos, shoulderVel = 0, 0
local pitchPos, pitchVel       = 0, 0
local castFocusMix, castFocusGoal = 0, 0
local speedMix, speedGoal         = 0, 0
local kickSign = 1

local castZoomApplied   = 0
local critZoomApplied   = 0
local critZoomToken     = 0
local speedZoomApplied  = 0
local combatZoomApplied = 0

local lastPunchAt     = 0
local lastHitAt       = 0
local lastCritAt      = 0
local lastCritSoundAt = 0

local CRIT_SOUNDS = {
    impact  = SOUNDKIT.UI_ORDERHALL_TALENT_READY_TOAST or 73280,
    ping    = SOUNDKIT.GM_CHAT_WARNING or 15273,
    drum    = SOUNDKIT.PVP_THROUGH_QUEUE or 8458,
    thunder = SOUNDKIT.RAID_BOSS_EMOTE_WARNING or 12197,
}

local function PlayCritSound()
    local db = AC.DB()
    if not db or not db.enabled or db.bdoCritSound == false then return end
    local now = GetTime()
    if (now - lastCritSoundAt) < 0.15 then return end
    lastCritSoundAt = now
    local style = db.bdoCritSoundStyle or "impact"
    local soundID = CRIT_SOUNDS[style] or CRIT_SOUNDS.impact
    if soundID and PlaySound then
        pcall(PlaySound, soundID, "SFX")
    end
end

-- Constantes de física calibradas para vencer a suavização interna do WoW
-- (pulsos direcionais firmes com retorno elástico rápido, sem oscilar em alta
-- frequência onde o filtro passa-baixa do cliente anularia o movimento)
local SPRING_STIFFNESS = 95
local SPRING_DAMPING   = 13
local SHAKE_FREQ       = 24   -- ~3.8 Hz: pulso seco e visível na tela
local SHAKE_DECAY      = 9.5  -- decai em ~0.30s
local FOCUS_SPEED      = 8
local SPEED_LERP       = 3.5
local SETTLE_POS       = 0.002
local SETTLE_VEL       = 0.005

--------------------------------------------------------------------------------
-- Helpers de base da câmera (sempre em sincronia com CVarManager)
--------------------------------------------------------------------------------
local function GetBaseShoulder()
    local db = AC.DB()
    if not db or db.shoulderEnabled == false then return 0 end
    if db.shoulderFollowsMouseLook and not (AC.IsMouseLookCameraChromeActive and AC.IsMouseLookCameraChromeActive()) then
        return 0
    end
    if AC.GetCurrentShoulderTarget then
        return tonumber(AC.GetCurrentShoulderTarget()) or tonumber(db.shoulderOffset) or 0
    end
    return tonumber(db.shoulderOffset) or 0
end

local function GetBasePitchPad()
    local db = AC.DB()
    if not db or not db.dynamicPitch then return 0 end
    return tonumber(db.dynamicPitchStrength) or 0.4
end

local function IsBDOEnabled()
    local db = AC.DB()
    if not db or not db.enabled or db.bdoEnabled == false then
        return false, 0
    end
    local intensity = tonumber(db.bdoIntensity) or 0.65
    return intensity > 0.01, max(0, min(1, intensity))
end

local function ApplyCameraOffsets()
    if AC.npcCinematicActive then return end
    local baseS = GetBaseShoulder()
    local baseP = GetBasePitchPad()

    -- Tremor de impacto de alta frequência
    local shakeX = shakeAmpX * sin(shakePhase)
    local shakeY = shakeAmpY * cos(shakePhase * 1.15)

    -- Foco durante conjuração aproxima visivelmente o enquadramento
    local focusShoulder = -0.35 * castFocusMix
    local focusPitch    = -0.22 * castFocusMix

    -- Corrida/montaria abre o ângulo vertical (sensação de velocidade BDO)
    local speedPitch    = 0.16 * speedMix

    AC.SetCVar("test_cameraOverShoulder", baseS + shoulderPos + shakeX + focusShoulder)
    AC.SetCVar("test_cameraDynamicPitchBaseFovPad", max(0, min(1, baseP + pitchPos + shakeY + focusPitch + speedPitch)))
end

local function EnsureAnimRunning()
    if animActive then return end
    animActive = true
    animFrame:SetScript("OnUpdate", function(_, elapsed)
        local dt = min(elapsed or 0.016, 0.05)
        local damp = exp(-SPRING_DAMPING * dt)

        -- Camada 1: Decaimento do micro-tremor de impacto
        if abs(shakeAmpX) > 0.0005 or abs(shakeAmpY) > 0.0005 then
            local shakeDecay = exp(-SHAKE_DECAY * dt)
            shakeAmpX  = shakeAmpX * shakeDecay
            shakeAmpY  = shakeAmpY * shakeDecay
            shakePhase = shakePhase + SHAKE_FREQ * dt
        else
            shakeAmpX, shakeAmpY = 0, 0
        end

        -- Camada 2: Mola do ombro e pitch
        shoulderVel = (shoulderVel - shoulderPos * SPRING_STIFFNESS * dt) * damp
        shoulderPos = shoulderPos + shoulderVel * dt

        pitchVel = (pitchVel - pitchPos * SPRING_STIFFNESS * dt) * damp
        pitchPos = pitchPos + pitchVel * dt

        -- Interpolação do foco de conjuração
        if castFocusMix ~= castFocusGoal then
            local step = min(1, dt * FOCUS_SPEED)
            castFocusMix = castFocusMix + (castFocusGoal - castFocusMix) * step
            if abs(castFocusGoal - castFocusMix) < 0.004 then
                castFocusMix = castFocusGoal
            end
        end

        -- Interpolação da respiração de velocidade (corrida / montaria)
        if speedMix ~= speedGoal then
            local step = min(1, dt * SPEED_LERP)
            speedMix = speedMix + (speedGoal - speedMix) * step
            if abs(speedGoal - speedMix) < 0.004 then
                speedMix = speedGoal
            end
        end

        ApplyCameraOffsets()

        local settled = abs(shakeAmpX) < 0.0005
            and abs(shakeAmpY) < 0.0005
            and abs(shoulderPos) < SETTLE_POS
            and abs(shoulderVel) < SETTLE_VEL
            and abs(pitchPos) < SETTLE_POS
            and abs(pitchVel) < SETTLE_VEL
            and castFocusMix == 0
            and castFocusGoal == 0
            and speedMix == 0
            and speedGoal == 0

        if settled then
            shakeAmpX, shakeAmpY = 0, 0
            shoulderPos, shoulderVel = 0, 0
            pitchPos, pitchVel = 0, 0
            ApplyCameraOffsets()
            animActive = false
            animFrame:SetScript("OnUpdate", nil)
        end
    end)
end

local function SafeZoomIn(delta)
    if not (CameraZoomIn and GetCameraZoom and delta and delta > 0.05) then return 0 end
    local db = AC.DB()
    local minZoom = (db and tonumber(db.minCameraZoom)) or 0
    local cur = GetCameraZoom() or 0
    local allowed = max(0, cur - max(1.8, minZoom))
    local actual = min(delta, allowed)
    if actual >= 0.15 then
        CameraZoomIn(actual)
        return actual
    end
    return 0
end

local function SafeZoomOut(delta)
    if not (CameraZoomOut and delta and delta >= 0.15) then return end
    CameraZoomOut(delta)
end

--------------------------------------------------------------------------------
-- Efeitos individuais estilo Black Desert
--------------------------------------------------------------------------------
function AC.TriggerBDOCameraImpact(mult, isCrit, includeShake)
    local ok, intensity = IsBDOEnabled()
    if not ok then return end
    local db = AC.DB()
    if isCrit and db.bdoCritImpact == false then return end
    if (not isCrit) and db.bdoSkillPunch == false then return end

    local now = GetTime()
    if isCrit then
        if (now - lastCritAt) < 0.18 then return end
        lastCritAt = now
    else
        if (now - lastPunchAt) < 0.15 then return end
        lastPunchAt = now
    end

    local m = (mult or 1.0) * intensity
    kickSign = -kickSign

    -- Impulso de recuo firme na mola (visível além da suavização do cliente)
    shoulderVel = shoulderVel + kickSign * (6.5 * m)
    pitchVel    = pitchVel + (isCrit and -3.2 or -2.0) * m

    -- Tremor de impacto (BDO hit-shake)
    if includeShake ~= false and db.bdoHitShake ~= false then
        shakeAmpX  = max(abs(shakeAmpX), 0.55 * m) * kickSign
        shakeAmpY  = max(abs(shakeAmpY), 0.24 * m)
        shakePhase = 0.25
    end

    EnsureAnimRunning()
end

function AC.OnPlayerTargetHit()
    local ok, intensity = IsBDOEnabled()
    if not ok then return end
    local db = AC.DB()
    if db.bdoHitShake == false then return end

    local now = GetTime()
    if (now - lastHitAt) < 0.14 then return end
    lastHitAt = now

    kickSign = -kickSign
    local m = 0.85 * intensity
    shakeAmpX   = max(abs(shakeAmpX), 0.42 * m) * kickSign
    shakeAmpY   = max(abs(shakeAmpY), 0.18 * m)
    shakePhase  = 0.25
    shoulderVel = shoulderVel + kickSign * (4.2 * m)
    pitchVel    = pitchVel - (1.8 * m)
    EnsureAnimRunning()
end

function AC.WantsTargetCrit()
    local db = AC.DB()
    if not db or not db.enabled then return false end
    return (db.bdoCritSound ~= false) or (db.bdoEnabled ~= false and db.bdoCritImpact ~= false)
end

function AC.OnPlayerTargetCrit()
    local db = AC.DB()
    if not db or not db.enabled then return end
    PlayCritSound()

    local ok, intensity = IsBDOEnabled()
    if not ok or db.bdoCritImpact == false then return end

    AC.TriggerBDOCameraImpact(1.55, true, true)

    -- Micro-punch de zoom no crítico (aproxima por 120ms e solta, estilo hit-stop BDO)
    if critZoomApplied == 0 and castZoomApplied == 0 and C_Timer and C_Timer.After then
        local punched = SafeZoomIn(1.35 * intensity)
        if punched > 0 then
            critZoomApplied = punched
            critZoomToken = critZoomToken + 1
            local token = critZoomToken
            C_Timer.After(0.12, function()
                if token ~= critZoomToken then return end
                if critZoomApplied > 0 then
                    local d = critZoomApplied
                    critZoomApplied = 0
                    SafeZoomOut(d)
                end
            end)
        end
    end
end

function AC.StartBDOCastFocus()
    local ok, intensity = IsBDOEnabled()
    if not ok then return end
    local db = AC.DB()
    if db.bdoCastFocus == false then return end
    if IsMounted and IsMounted() then return end

    if not (UnitAffectingCombat and UnitAffectingCombat("player"))
        and not (UnitExists and UnitExists("target") and UnitCanAttack and UnitCanAttack("player", "target")) then
        return
    end

    castFocusGoal = intensity
    EnsureAnimRunning()

    if castZoomApplied == 0 and CameraZoomIn and GetCameraZoom then
        local curZoom = GetCameraZoom()
        local delta = min(1.6 * intensity, max(0, curZoom - 3.2) * 0.35)
        local applied = SafeZoomIn(delta)
        if applied > 0 then
            castZoomApplied = applied
        end
    end
end

function AC.EndBDOCastFocus(wasSuccess)
    castFocusGoal = 0
    if castZoomApplied > 0 then
        local delta = castZoomApplied
        castZoomApplied = 0
        SafeZoomOut(delta)
    end
    if wasSuccess then
        AC.TriggerBDOCameraImpact(1.25, false, true)
    elseif animActive then
        EnsureAnimRunning()
    end
end

function AC.UpdateBDOMovement()
    local ok, intensity = IsBDOEnabled()
    local db = AC.DB()
    if not ok or not db or db.bdoSpeedZoom == false then
        if speedGoal ~= 0 then
            speedGoal = 0
            EnsureAnimRunning()
        end
        if speedZoomApplied > 0 then
            local d = speedZoomApplied
            speedZoomApplied = 0
            SafeZoomIn(d)
        end
        return
    end

    local speed = GetUnitSpeed and GetUnitSpeed("player") or 0
    if Azaath.IsSecret and Azaath.IsSecret(speed) then
        speed = nil
    end
    local mounted = IsMounted and IsMounted()
    local moving = _G.IsPlayerMoving and _G.IsPlayerMoving()
    if Azaath.IsSecret and Azaath.IsSecret(moving) then
        moving = nil
    end

    local targetGoal = 0
    if speed ~= nil then
        if mounted and speed > 7.5 then
            targetGoal = intensity
        elseif speed > 7.6 then
            targetGoal = 0.65 * intensity
        end
    elseif mounted and moving ~= false then
        targetGoal = intensity
    end

    if abs(speedGoal - targetGoal) > 0.02 then
        speedGoal = targetGoal
        EnsureAnimRunning()
    end

    -- Afastamento ao galopar / sprintar em alta velocidade (> 7.6 yd/s ou montado)
    local wantZoom = 0
    if speed ~= nil and speed > 7.6 then
        wantZoom = 1.8 * intensity
    elseif speed == nil and mounted and moving ~= false then
        wantZoom = 1.8 * intensity
    end
    if wantZoom >= 0.25 and speedZoomApplied == 0 then
        speedZoomApplied = wantZoom
        SafeZoomOut(wantZoom)
    elseif wantZoom == 0 and speedZoomApplied > 0 then
        local d = speedZoomApplied
        speedZoomApplied = 0
        SafeZoomIn(d)
    end
end

function AC.OnBDOCombatState(inCombat)
    local ok, intensity = IsBDOEnabled()
    local db = AC.DB()
    if not ok or not db or db.bdoCombatZoomOut ~= true then
        if combatZoomApplied > 0 then
            local d = combatZoomApplied
            combatZoomApplied = 0
            SafeZoomIn(d)
        end
        return
    end

    if inCombat then
        if combatZoomApplied == 0 then
            local delta = 1.6 * intensity
            if delta >= 0.25 then
                combatZoomApplied = delta
                SafeZoomOut(delta)
            end
        end
    else
        if combatZoomApplied > 0 then
            local delta = combatZoomApplied
            combatZoomApplied = 0
            SafeZoomIn(delta)
        end
    end
end

function AC.OnBDOUnitCombat(unit, action, descriptor)
    if Azaath.IsSecret(unit) or Azaath.IsSecret(descriptor) then return end
    if unit ~= "player" then return end
    if descriptor == "CRITICAL" or descriptor == "CRUSHING" then
        AC.TriggerBDOCameraImpact(1.05, true, true)
    end
end

function AC.ResetBDOCamera()
    shakeAmpX, shakeAmpY = 0, 0
    shoulderPos, shoulderVel = 0, 0
    pitchPos, pitchVel = 0, 0
    castFocusMix, castFocusGoal = 0, 0
    speedMix, speedGoal = 0, 0
    critZoomToken = critZoomToken + 1

    if critZoomApplied > 0 then
        SafeZoomOut(critZoomApplied)
        critZoomApplied = 0
    end
    if castZoomApplied > 0 then
        SafeZoomOut(castZoomApplied)
        castZoomApplied = 0
    end
    if speedZoomApplied > 0 then
        SafeZoomIn(speedZoomApplied)
        speedZoomApplied = 0
    end
    if combatZoomApplied > 0 then
        SafeZoomIn(combatZoomApplied)
        combatZoomApplied = 0
    end
    if animActive then
        ApplyCameraOffsets()
        animActive = false
        animFrame:SetScript("OnUpdate", nil)
    end
end
