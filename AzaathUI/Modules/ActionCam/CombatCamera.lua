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

-- Zoom extra vai por camadas do diretor ("cast", "crit", "speed", "combat")
local critZoomToken = 0

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

local function IsBDOEnabled()
    local db = AC.DB()
    if not db or not db.enabled or db.bdoEnabled == false then
        return false, 0
    end
    local intensity = tonumber(db.bdoIntensity) or 0.65
    return intensity > 0.01, max(0, min(1, intensity))
end

-- Só calcula as camadas; quem grava (e soma com a base) é o diretor de câmera
local function ApplyCameraOffsets()
    -- Tremor de impacto de alta frequência
    local shakeX = shakeAmpX * sin(shakePhase)
    local shakeY = shakeAmpY * cos(shakePhase * 1.15)

    -- Foco durante conjuração aproxima visivelmente o enquadramento
    local focusShoulder = -0.35 * castFocusMix
    local focusPitch    = -0.22 * castFocusMix

    -- Corrida/montaria abre o ângulo vertical (sensação de velocidade BDO)
    local speedPitch    = 0.16 * speedMix

    AC.Cam.SetOffset("bdo", "shoulder", shoulderPos + shakeX + focusShoulder)
    AC.Cam.SetOffset("bdo", "pitch", pitchPos + shakeY + focusPitch + speedPitch)
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

--------------------------------------------------------------------------------
-- Chute genérico (habilidades e dano recebido): impulsos já multiplicados pela
-- intensidade; side = 1/-1 (nil alterna); shakeX/shakeY = amplitude do tremor
--------------------------------------------------------------------------------
function AC.CameraKick(shoulderImpulse, pitchImpulse, shakeX, shakeY, side)
    local ok, intensity = IsBDOEnabled()
    if not ok then return end
    if side then kickSign = side else kickSign = -kickSign end
    shoulderVel = shoulderVel + kickSign * (shoulderImpulse or 0) * intensity
    pitchVel    = pitchVel + (pitchImpulse or 0) * intensity
    if (shakeX or 0) > 0 or (shakeY or 0) > 0 then
        shakeAmpX  = max(abs(shakeAmpX), (shakeX or 0) * intensity) * kickSign
        shakeAmpY  = max(abs(shakeAmpY), (shakeY or 0) * intensity)
        shakePhase = 0.25
    end
    EnsureAnimRunning()
end

-- Dano recebido (UNIT_COMBAT no jogador): tremor curto mais vertical que o
-- do ataque, lado sorteado (o jogo não diz de onde veio o golpe)
local lastHurtAt = 0
function AC.OnPlayerWounded(isCrit)
    local db = AC.DB()
    if not db or db.bdoHurtShake == false then return end
    local now = GetTime()
    if (now - lastHurtAt) < (isCrit and 0.2 or 0.35) then return end
    lastHurtAt = now
    local m = isCrit and 1.6 or 1
    AC.CameraKick(2.4 * m, 2.6 * m, 0.22 * m, 0.30 * m, (math.random() < 0.5) and 1 or -1)
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
    local Cam = AC.Cam
    if Cam.GetZoom("crit") == 0 and Cam.GetZoom("cast") == 0 and C_Timer and C_Timer.After then
        Cam.SetZoom("crit", -1.35 * intensity)
        critZoomToken = critZoomToken + 1
        local token = critZoomToken
        C_Timer.After(0.12, function()
            if token ~= critZoomToken then return end
            Cam.SetZoom("crit", nil)
        end)
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

    local curZoom = GetCameraZoom and GetCameraZoom()
    if AC.Cam.GetZoom("cast") == 0 and curZoom and not (Azaath.IsSecret and Azaath.IsSecret(curZoom)) then
        local delta = min(1.6 * intensity, max(0, curZoom - 3.2) * 0.35)
        if delta >= 0.15 then
            AC.Cam.SetZoom("cast", -delta)
        end
    end
end

function AC.EndBDOCastFocus(wasSuccess)
    castFocusGoal = 0
    AC.Cam.SetZoom("cast", nil)
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
        AC.Cam.SetZoom("speed", nil)
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
    AC.Cam.SetZoom("speed", wantZoom >= 0.25 and wantZoom or nil)
end

function AC.OnBDOCombatState(inCombat)
    local ok, intensity = IsBDOEnabled()
    local db = AC.DB()
    if not ok or not db or db.bdoCombatZoomOut ~= true or not inCombat then
        AC.Cam.SetZoom("combat", nil)
        return
    end
    local delta = 1.6 * intensity
    AC.Cam.SetZoom("combat", delta >= 0.25 and delta or nil)
end

function AC.OnBDOUnitCombat(unit, action, descriptor)
    if Azaath.IsSecret(unit) or Azaath.IsSecret(descriptor) then return end
    if unit ~= "player" or Azaath.IsSecret(action) then return end
    if action == "WOUND" then
        AC.OnPlayerWounded(descriptor == "CRITICAL" or descriptor == "CRUSHING")
    end
end

function AC.ResetBDOCamera()
    shakeAmpX, shakeAmpY = 0, 0
    shoulderPos, shoulderVel = 0, 0
    pitchPos, pitchVel = 0, 0
    castFocusMix, castFocusGoal = 0, 0
    speedMix, speedGoal = 0, 0
    critZoomToken = critZoomToken + 1
    if animActive then
        animActive = false
        animFrame:SetScript("OnUpdate", nil)
    end
    -- zera as camadas e devolve na hora o zoom extra que o jogo de fato andou
    AC.Cam.ClearAll()
end
