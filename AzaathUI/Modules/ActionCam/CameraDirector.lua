--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ActionCam/CameraDirector.lua
    Diretor de câmera: ÚNICO módulo que grava ombro (test_cameraOverShoulder),
    inclinação (test_cameraDynamicPitchBaseFovPad) e o zoom extra da Câmera
    Action. Os outros módulos só pedem:
      * base do ombro (preferência do jogador, com transição suave);
      * camadas somadas por nome (tremor, recuo, foco de conjuração...);
      * camadas de zoom por nome (+ afasta, - aproxima), reconciliadas pela
        soma: nada de "aproxima X e depois devolve X" espalhado pelo código.
    O ombro é proporcional à distância da câmera (enquadramento igual de perto
    e de longe). Cenas (NPC, ficha) suspendem o diretor; ao sair, ele volta
    misturando a partir de onde a cena deixou a câmera.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local _G = _G

local AC = Azaath.ActionCam or {}
Azaath.ActionCam = AC

local Cam = {}
AC.Cam = Cam

local CreateFrame   = _G.CreateFrame
local GetTime       = _G.GetTime
local GetCameraZoom = _G.GetCameraZoom

local pairs, tonumber, format = pairs, tonumber, string.format
local abs, max, min = math.abs, math.max, math.min

local SHOULDER_FADE  = 0.35   -- transição da base do ombro (mesmo tempo do tween antigo)
local RESUME_FADE    = 0.35   -- volta suave depois de uma cena
local SHOULDER_REF   = 8      -- distância (jardas) em que o ombro vale 100%
local SHOULDER_MIN_K = 0.45
local SHOULDER_MAX_K = 1.6
local ZOOM_STEP_MIN  = 0.15   -- menor passo de zoom que vale a pena mandar
local WRITE_EPS      = 0.001

--------------------------------------------------------------------------------
-- Estado
--------------------------------------------------------------------------------
local baseFrom, baseTo, baseStart = 0, 0, 0
local offsets = { shoulder = {}, pitch = {} }
local zoomLayers = {}
local zoomApplied = 0

-- Foco no inimigo travado: força entra suave em vez de pular
local FOCUS_FADE = 0.6
local focus = { active = false, yawFrom = 0, yawTo = 0, pitchFrom = 0, pitchTo = 0, start = 0 }
local pulseToken = {}

-- Situação atual (Situations.lua): multiplica a base do ombro e soma na inclinação
local sit = { name = "-", mulFrom = 1, mulTo = 1, pitchFrom = 0, pitchTo = 0, start = 0, dur = 0.6 }

local lastWritten = {}
local wasSuspended = false
local resumeStart, resumeShoulder, resumePitch = nil, nil, nil

local out = { shoulder = 0, pitch = 0, zoomK = 1, zoom = 0 }

local function SmoothStep(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return t * t * (3 - 2 * t)
end

local function ReadCVarNumber(name)
    local get = _G.C_CVar and _G.C_CVar.GetCVar or _G.GetCVar
    if not get then return nil end
    local ok, v = pcall(get, name)
    return ok and tonumber(v) or nil
end

local function Write(name, value)
    local last = lastWritten[name]
    if last and abs(last - value) < WRITE_EPS then return end
    lastWritten[name] = value
    AC.SetCVar(name, format("%.3f", value))
end

local function Sum(t)
    local s = 0
    for _, v in pairs(t) do s = s + v end
    return s
end

local function CurrentZoom()
    if not GetCameraZoom then return nil end
    local z = GetCameraZoom()
    if z == nil or (Azaath.IsSecret and Azaath.IsSecret(z)) then return nil end
    return tonumber(z)
end

local function BaseShoulderNow(now)
    local t = (now - baseStart) / SHOULDER_FADE
    return baseFrom + (baseTo - baseFrom) * SmoothStep(t)
end

local function ShoulderZoomFactor(db)
    if db.shoulderZoomScale == false then return 1 end
    local z = CurrentZoom()
    if not z then return out.zoomK end
    return max(SHOULDER_MIN_K, min(SHOULDER_MAX_K, z / SHOULDER_REF))
end

--------------------------------------------------------------------------------
-- Zoom por camada: cada uma guarda o pedido (want) e o que o jogo de fato
-- andou (done). Ao soltar a camada, devolve só o "done" e esquece o resto:
-- se o limite mínimo/máximo cortou o movimento, nada de dívida acumulada
-- (era isso que fazia a câmera "andar" sozinha com o tempo).
--------------------------------------------------------------------------------
local function MoveZoom(diff, cur, db)
    if diff > 0 then
        if not _G.CameraZoomOut then return 0 end
        local maxDist = 15 * (ReadCVarNumber("cameraDistanceMaxZoomFactor") or 2.6)
        local actual = cur and min(diff, max(0, maxDist - cur)) or diff
        if actual < ZOOM_STEP_MIN then return 0 end
        _G.CameraZoomOut(actual)
        return actual
    else
        if not _G.CameraZoomIn then return 0 end
        local floorZoom = max(1.8, (db and tonumber(db.minCameraZoom)) or 0)
        local actual = cur and min(-diff, max(0, cur - floorZoom)) or -diff
        if actual < ZOOM_STEP_MIN then return 0 end
        _G.CameraZoomIn(actual)
        return -actual
    end
end

local function ReconcileZoom(db)
    local cur = CurrentZoom()
    local total = 0
    for name, L in pairs(zoomLayers) do
        local diff = L.want - L.done
        if abs(diff) >= ZOOM_STEP_MIN then
            local moved = MoveZoom(diff, cur, db)
            L.done = L.done + moved
            if cur then cur = cur + moved end
        end
        if L.want == 0 then
            zoomLayers[name] = nil
        else
            total = total + L.done
        end
    end
    zoomApplied = total
end

--------------------------------------------------------------------------------
-- Laço principal
--------------------------------------------------------------------------------
local driver = CreateFrame("Frame", "AzaathUICameraDirector", _G.UIParent)
local running = false

local function Stop()
    running = false
    driver:SetScript("OnUpdate", nil)
end

local function Tick()
    local db = AC.DB and AC.DB()
    if not db or not db.enabled then
        Stop()
        return
    end

    if AC.npcCinematicActive then
        wasSuspended = true
        return
    end

    local now = GetTime()
    if wasSuspended then
        -- A cena mexeu nas CVars por fora: parte de onde ela deixou
        wasSuspended = false
        lastWritten = {}
        resumeStart = now
        resumeShoulder = ReadCVarNumber("test_cameraOverShoulder")
        resumePitch = ReadCVarNumber("test_cameraDynamicPitchBaseFovPad")
    end

    out.zoomK = ShoulderZoomFactor(db)
    local sk = SmoothStep((now - sit.start) / sit.dur)
    local sitMul = sit.mulFrom + (sit.mulTo - sit.mulFrom) * sk
    local sitPitch = sit.pitchFrom + (sit.pitchTo - sit.pitchFrom) * sk

    local base = (db.shoulderEnabled == false) and 0 or BaseShoulderNow(now) * sitMul
    local shoulder = (base + Sum(offsets.shoulder)) * out.zoomK

    local pitch = Sum(offsets.pitch) + sitPitch
    if db.dynamicPitch then
        pitch = pitch + (tonumber(db.dynamicPitchStrength) or 0.4)
    end
    pitch = max(0, min(1, pitch))

    if resumeStart then
        local k = 1 - SmoothStep((now - resumeStart) / RESUME_FADE)
        if k <= 0 then
            resumeStart = nil
        else
            if resumeShoulder then shoulder = shoulder + (resumeShoulder - shoulder) * k end
            if resumePitch then pitch = pitch + (resumePitch - pitch) * k end
        end
    end

    out.shoulder, out.pitch = shoulder, pitch
    Write("test_cameraOverShoulder", shoulder)
    Write("test_cameraDynamicPitchBaseFovPad", pitch)

    if focus.active then
        local fk = SmoothStep((now - focus.start) / FOCUS_FADE)
        Write("test_cameraTargetFocusEnemyStrengthYaw", focus.yawFrom + (focus.yawTo - focus.yawFrom) * fk)
        Write("test_cameraTargetFocusEnemyStrengthPitch", focus.pitchFrom + (focus.pitchTo - focus.pitchFrom) * fk)
    end

    ReconcileZoom(db)
    out.zoom = zoomApplied
end

function Cam.Wake()
    if running then return end
    running = true
    lastWritten = {}
    driver:SetScript("OnUpdate", Tick)
end

-- Alguém gravou as CVars por fora: regrava tudo no próximo quadro
function Cam.Invalidate()
    lastWritten = {}
end

--------------------------------------------------------------------------------
-- API para os outros módulos
--------------------------------------------------------------------------------
function Cam.SetBaseShoulder(value, instant)
    value = tonumber(value) or 0
    local now = GetTime()
    if instant then
        baseFrom, baseTo = value, value
    else
        baseFrom = BaseShoulderNow(now)
        baseTo = value
    end
    baseStart = now
    Cam.Wake()
end

function Cam.GetBaseShoulderGoal()
    return baseTo
end

-- channel = "shoulder" | "pitch"; value nil ou 0 remove a camada
function Cam.SetOffset(layer, channel, value)
    local t = offsets[channel]
    if not t then return end
    if value == nil or value == 0 then
        t[layer] = nil
    else
        t[layer] = value
        Cam.Wake()
    end
end

-- delta > 0 afasta, < 0 aproxima; nil ou 0 devolve
function Cam.SetZoom(layer, delta)
    local L = zoomLayers[layer]
    if delta == nil or delta == 0 then
        if L then L.want = 0 end
    elseif L then
        L.want = delta
    else
        zoomLayers[layer] = { want = delta, done = 0 }
    end
    Cam.Wake()
end

-- Troca de situação: parte do valor atual (mesmo no meio de outra transição)
function Cam.SetSituation(name, shoulderMul, pitchAdd, duration)
    local now = GetTime()
    local sk = SmoothStep((now - sit.start) / sit.dur)
    sit.mulFrom = sit.mulFrom + (sit.mulTo - sit.mulFrom) * sk
    sit.pitchFrom = sit.pitchFrom + (sit.pitchTo - sit.pitchFrom) * sk
    sit.mulTo = tonumber(shoulderMul) or 1
    sit.pitchTo = tonumber(pitchAdd) or 0
    sit.dur = max(0.05, tonumber(duration) or 0.6)
    sit.start = now
    sit.name = name or "-"
    Cam.Wake()
end

-- Distância "do jogador" = zoom atual sem o extra das camadas
function Cam.GetUserZoom()
    local z = CurrentZoom()
    return z and (z - zoomApplied) or nil
end

-- Move a distância base (memória de zoom por situação); devolve o que andou
function Cam.ZoomBy(delta)
    if not delta or abs(delta) < ZOOM_STEP_MIN then return 0 end
    return MoveZoom(delta, CurrentZoom(), AC.DB and AC.DB())
end

-- Zoom de ida e volta: segura "hold" segundos e solta (golpes, investidas)
function Cam.PulseZoom(layer, delta, hold)
    pulseToken[layer] = (pulseToken[layer] or 0) + 1
    local token = pulseToken[layer]
    Cam.SetZoom(layer, delta)
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(hold or 0.2, function()
            if pulseToken[layer] == token then Cam.SetZoom(layer, nil) end
        end)
    end
end

-- Foco no inimigo: entra em FOCUS_FADE s a partir de 0; desligar é imediato
function Cam.SetEnemyFocus(on, yaw, pitch)
    if on then
        AC.SetCVar("test_cameraTargetFocusEnemyEnable", 1)
        if not focus.active then
            focus.yawFrom, focus.pitchFrom = 0, 0
        else
            local fk = SmoothStep((GetTime() - focus.start) / FOCUS_FADE)
            focus.yawFrom = focus.yawFrom + (focus.yawTo - focus.yawFrom) * fk
            focus.pitchFrom = focus.pitchFrom + (focus.pitchTo - focus.pitchFrom) * fk
        end
        focus.active = true
        focus.yawTo, focus.pitchTo = yaw or 0.7, pitch or 0.2
        focus.start = GetTime()
        lastWritten.test_cameraTargetFocusEnemyStrengthYaw = nil
        lastWritten.test_cameraTargetFocusEnemyStrengthPitch = nil
        Cam.Wake()
    else
        focus.active = false
        AC.SetCVar("test_cameraTargetFocusEnemyEnable", 0)
    end
end

-- Teste fora de combate: até onde o cliente aceita o cameraFov (fase 3)
function Cam.ProbeFov()
    if _G.InCombatLockdown and _G.InCombatLockdown() then return "saia do combate para testar" end
    local orig = ReadCVarNumber("cameraFov")
    local function try(v)
        AC.SetCVar("cameraFov", v)
        return ReadCVarNumber("cameraFov")
    end
    local hi, lo = try(120), try(30)
    if orig then AC.SetCVar("cameraFov", orig) end
    return format("cameraFov atual=%s aceita de %s a %s", tostring(orig), tostring(lo), tostring(hi))
end

function Cam.GetZoom(layer)
    local L = zoomLayers[layer]
    return L and L.want or 0
end

-- Desligar a Câmera Action: zera as camadas e devolve o zoom extra na hora
-- (a base do ombro fica, para religar como estava)
function Cam.ClearAll()
    for _, t in pairs(offsets) do
        for k in pairs(t) do t[k] = nil end
    end
    for _, L in pairs(zoomLayers) do L.want = 0 end
    ReconcileZoom(AC.DB and AC.DB())
    resumeStart = nil
    lastWritten = {}
end

function Cam.Diag()
    local parts = { format("situação=%s ombro=%.3f (x%.2f, sit x%.2f) incl=%.3f zoomExtra=%.2f",
        sit.name, out.shoulder, out.zoomK, sit.mulTo, out.pitch, zoomApplied) }
    for ch, t in pairs(offsets) do
        for k, v in pairs(t) do parts[#parts + 1] = format("%s.%s=%.3f", ch, k, v) end
    end
    for k, L in pairs(zoomLayers) do parts[#parts + 1] = format("zoom.%s=%.2f/%.2f", k, L.done, L.want) end
    return table.concat(parts, " ")
end

if Azaath.commands then
    Azaath.commands.camera = function(arg)
        if arg == "fov" then
            Azaath:Print("câmera: " .. Cam.ProbeFov())
            return
        end
        Azaath:Print("câmera: " .. Cam.Diag())
    end
end
