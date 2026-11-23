--[[----------------------------------------------------------------------------
    AzaathUI - Modules/NpcCamera.lua
    Câmera cinematográfica nativa (estilo Immersion / Interaction) para diálogos
    com NPCs de missão, gossip e serviços (mercador, treinador, banco, leilão,
    estábulo, voo).

    Comportamento:
      * Salva a câmera (SaveView(4), zoom e CVars) antes de iniciar;
      * Aproxima suavemente a câmera até uma distância de conversa;
      * Ativa foco automático no NPC (test_cameraTargetFocusInteractEnable) com
        easing suave em Pitch e Yaw para enquadrar o NPC;
      * Desloca o ombro (test_cameraOverShoulder) para enquadrar personagem e NPC
        à esquerda do painel de diálogo (que fica à direita);
      * Opcionalmente aplica FOV cinematográfico, inclinação dinâmica, leve
        panorâmica e vinheta nas bordas;
      * Faz transição contínua entre janelas (ex.: Gossip -> Missão / Mercador)
        sem recuar a câmera no meio da interação;
      * Restaura tudo suavemente ao encerrar a interação ou imediatamente ao
        entrar em combate.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("NpcCamera")

local _G = _G
local C_Timer          = _G.C_Timer
local CreateFrame      = _G.CreateFrame
local GetTime          = _G.GetTime
local InCombatLockdown = _G.InCombatLockdown
local IsInInstance     = _G.IsInInstance
local IsIndoors        = _G.IsIndoors
local IsMounted        = _G.IsMounted
local IsFlying         = _G.IsFlying
local IsPlayerMoving   = _G.IsPlayerMoving
local UnitExists       = _G.UnitExists
local UnitIsUnit       = _G.UnitIsUnit
local GetCameraZoom    = _G.GetCameraZoom
local CameraZoomIn     = _G.CameraZoomIn
local CameraZoomOut    = _G.CameraZoomOut
local SaveView         = _G.SaveView
local SetView          = _G.SetView
local MoveViewRightStart = _G.MoveViewRightStart
local MoveViewLeftStop   = _G.MoveViewLeftStop
local MoveViewRightStop  = _G.MoveViewRightStop

local pairs, ipairs, pcall, tonumber, tostring = pairs, ipairs, pcall, tonumber, tostring
local min, max, format = math.min, math.max, string.format

--------------------------------------------------------------------------------
-- Helpers de CVar
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

local function IsSkyriding()
    local info = _G.C_PlayerInfo and _G.C_PlayerInfo.GetGlidingInfo
    if info then
        local ok, gliding = pcall(info)
        if ok and gliding then return true end
    end
    return IsFlying and IsFlying() or false
end

local function EaseOutCubic(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    local u = 1 - t
    return 1 - u * u * u
end

--------------------------------------------------------------------------------
-- Estado
--------------------------------------------------------------------------------
local VIEW_SLOT       = 4
local TRANSITION_DUR  = 0.85
local EXIT_DEBOUNCE   = 0.12
local VIGNETTE_ALPHA  = 0.52

local isActive        = false
local activeContexts  = {}
local exitTimerToken  = 0
local savedViewStored = false
local savedZoom       = nil
local savedCVars      = nil
local panActive       = false

local animFrame       = CreateFrame("Frame")
local animStart       = 0
local animDuration    = TRANSITION_DUR
local animFrom        = {}
local animTo          = {}

local vignetteFrame, vignetteTex
local vigAlpha, vigTarget = 0, 0
local VIG_FADE_DUR = 0.35

local QUEST_GOSSIP_EVENTS = {
    GOSSIP_SHOW    = { ctx = "gossip",   open = true },
    GOSSIP_CLOSED  = { ctx = "gossip",   open = false },
    QUEST_GREETING = { ctx = "quest",    open = true },
    QUEST_DETAIL   = { ctx = "quest",    open = true },
    QUEST_PROGRESS = { ctx = "quest",    open = true },
    QUEST_COMPLETE = { ctx = "quest",    open = true },
    QUEST_FINISHED = { ctx = "quest",    open = false },
}

local OTHER_NPC_EVENTS = {
    MERCHANT_SHOW          = { ctx = "merchant",  open = true },
    MERCHANT_CLOSED        = { ctx = "merchant",  open = false },
    TRAINER_SHOW           = { ctx = "trainer",   open = true },
    TRAINER_CLOSED         = { ctx = "trainer",   open = false },
    BANKFRAME_OPENED       = { ctx = "bank",      open = true },
    BANKFRAME_CLOSED       = { ctx = "bank",      open = false },
    AUCTION_HOUSE_SHOW     = { ctx = "auction",   open = true },
    AUCTION_HOUSE_CLOSED   = { ctx = "auction",   open = false },
    GUILDBANKFRAME_OPENED  = { ctx = "guildbank", open = true },
    GUILDBANKFRAME_CLOSED  = { ctx = "guildbank", open = false },
    PET_STABLE_SHOW        = { ctx = "stable",    open = true },
    PET_STABLE_CLOSED      = { ctx = "stable",    open = false },
    TAXIMAP_OPENED         = { ctx = "taxi",      open = true },
    TAXIMAP_CLOSED         = { ctx = "taxi",      open = false },
}

--------------------------------------------------------------------------------
-- Vinheta cinematográfica
--------------------------------------------------------------------------------
local function EnsureVignette()
    if vignetteFrame then return vignetteFrame end
    vignetteFrame = CreateFrame("Frame", "AzaathUINpcCinematicVignette", _G.UIParent)
    vignetteFrame:SetAllPoints(_G.UIParent)
    vignetteFrame:SetFrameStrata("BACKGROUND")
    vignetteFrame:SetFrameLevel(1)
    vignetteFrame:EnableMouse(false)
    vignetteFrame:SetAlpha(0)
    vignetteFrame:Hide()

    vignetteTex = vignetteFrame:CreateTexture(nil, "BACKGROUND")
    vignetteTex:SetAllPoints(vignetteFrame)
    vignetteTex:SetTexture(Azaath.media.path .. "Minimap\\MinimapVignette.tga")
    vignetteTex:SetVertexColor(0, 0, 0, 0.78)

    vignetteFrame:SetScript("OnUpdate", function(self, elapsed)
        local step = (elapsed or 0.016) / VIG_FADE_DUR
        if vigAlpha < vigTarget then
            vigAlpha = min(vigTarget, vigAlpha + step)
        elseif vigAlpha > vigTarget then
            vigAlpha = max(vigTarget, vigAlpha - step)
        end
        self:SetAlpha(vigAlpha)
        if vigAlpha <= 0.001 and vigTarget == 0 then
            vigAlpha = 0
            self:Hide()
        end
    end)

    return vignetteFrame
end

local function SetVignetteVisible(show)
    if show then
        local f = EnsureVignette()
        vigTarget = VIGNETTE_ALPHA
        f:Show()
    elseif vignetteFrame then
        vigTarget = 0
    end
end

--------------------------------------------------------------------------------
-- Panorâmica sutil
--------------------------------------------------------------------------------
local function StopPan()
    if not panActive then return end
    panActive = false
    if MoveViewLeftStop then pcall(MoveViewLeftStop) end
    if MoveViewRightStop then pcall(MoveViewRightStop) end
end

local function StartPan()
    if panActive then return end
    if IsPlayerMoving and IsPlayerMoving() then return end
    if MoveViewRightStart then
        panActive = true
        pcall(MoveViewRightStart, 0.014)
    end
end

--------------------------------------------------------------------------------
-- Validação de contexto e alvo
--------------------------------------------------------------------------------
local function HasAnyContext()
    for _, v in pairs(activeContexts) do
        if v then return true end
    end
    return false
end

local function HasValidNpcTarget()
    local hasNpc = UnitExists("npc") or UnitExists("questnpc")
    if not hasNpc then return false end
    if UnitExists("npc") and UnitIsUnit("npc", "player") then return false end
    if UnitExists("questnpc") and UnitIsUnit("questnpc", "player") then return false end
    return true
end

local function CanEnterCinematic()
    local db = M.db
    if not db or not db.enabled then return false end
    if db.disableInCombat and InCombatLockdown() then return false end
    if db.disableInInstances and IsInInstance and IsInInstance() then return false end
    if IsSkyriding() then return false end
    if not HasValidNpcTarget() then return false end
    return true
end

--------------------------------------------------------------------------------
-- Snapshot e Restauração de CVars / Câmera
--------------------------------------------------------------------------------
local CVARS_TO_SAVE = {
    "cameraViewBlendStyle",
    "CameraKeepCharacterCentered",
    "CameraReduceUnexpectedMovement",
    "test_cameraOverShoulder",
    "test_cameraTargetFocusInteractEnable",
    "test_cameraTargetFocusInteractStrengthPitch",
    "test_cameraTargetFocusInteractStrengthYaw",
    "test_cameraDynamicPitch",
    "test_cameraDynamicPitchBaseFovPad",
    "cameraFov",
}

local function SaveCameraState()
    savedCVars = {}
    for _, name in ipairs(CVARS_TO_SAVE) do
        savedCVars[name] = GetCVar(name)
    end
    savedZoom = GetCameraZoom and GetCameraZoom() or nil
    savedViewStored = false
    if SaveView and not InCombatLockdown() then
        SetCVar("cameraViewBlendStyle", 1)
        local ok = pcall(SaveView, VIEW_SLOT)
        if ok then savedViewStored = true end
    end
end

local function RestoreCameraState(instant)
    animFrame:SetScript("OnUpdate", nil)
    StopPan()
    SetVignetteVisible(false)

    -- Restaura visão/zoom antes de devolver o controle ao ActionCam
    if savedViewStored and SetView and not InCombatLockdown() then
        SetCVar("cameraViewBlendStyle", instant and 0 or 1)
        pcall(SetView, VIEW_SLOT)
    elseif savedZoom and GetCameraZoom then
        local cur = GetCameraZoom()
        if cur and savedZoom > cur + 0.1 and CameraZoomOut then
            pcall(CameraZoomOut, savedZoom - cur)
        elseif cur and savedZoom < cur - 0.1 and CameraZoomIn then
            pcall(CameraZoomIn, cur - savedZoom)
        end
    end

    if savedCVars then
        SetCVar("test_cameraTargetFocusInteractEnable", savedCVars.test_cameraTargetFocusInteractEnable or 0)
        SetCVar("test_cameraTargetFocusInteractStrengthPitch", savedCVars.test_cameraTargetFocusInteractStrengthPitch or 0)
        SetCVar("test_cameraTargetFocusInteractStrengthYaw", savedCVars.test_cameraTargetFocusInteractStrengthYaw or 0)
        if savedCVars.CameraKeepCharacterCentered ~= nil then
            SetCVar("CameraKeepCharacterCentered", savedCVars.CameraKeepCharacterCentered)
        end
        if savedCVars.CameraReduceUnexpectedMovement ~= nil then
            SetCVar("CameraReduceUnexpectedMovement", savedCVars.CameraReduceUnexpectedMovement)
        end
        if savedCVars.cameraFov then
            SetCVar("cameraFov", savedCVars.cameraFov)
        end
        if savedCVars.cameraViewBlendStyle then
            SetCVar("cameraViewBlendStyle", savedCVars.cameraViewBlendStyle)
        end
    end

    if Azaath.ActionCam then
        Azaath.ActionCam.npcCinematicActive = false
    end

    local acEnabled = Azaath.db and Azaath.db.actioncam and Azaath.db.actioncam.enabled
    local acMod = Azaath:GetModule("ActionCam")
    if acEnabled and acMod and acMod.ApplyLayout then
        acMod:ApplyLayout()
    elseif savedCVars then
        SetCVar("test_cameraOverShoulder", savedCVars.test_cameraOverShoulder or 0)
        SetCVar("test_cameraDynamicPitch", savedCVars.test_cameraDynamicPitch or 0)
        if savedCVars.test_cameraDynamicPitchBaseFovPad then
            SetCVar("test_cameraDynamicPitchBaseFovPad", savedCVars.test_cameraDynamicPitchBaseFovPad)
        end
    end

    savedCVars = nil
    savedZoom = nil
    savedViewStored = false
end

--------------------------------------------------------------------------------
-- Transição de entrada
--------------------------------------------------------------------------------
local function IsMerchantContext()
    return activeContexts.merchant == true
end

local function ComputeTargetShoulder(db, targetZoom)
    -- No mercador, a janela do NPC fica à esquerda e o inventário à direita:
    -- usa um deslocamento sutil de ombro para tirar as costas do personagem da frente
    -- e deixar o vendedor visível no centro da tela, entre os dois quadros.
    if IsMerchantContext() then
        return 0.85
    end
    local base = tonumber(db.shoulderOffset) or 1.25
    local mod = 1
    if IsMounted and IsMounted() then
        mod = 1.15
    elseif IsIndoors and IsIndoors() then
        mod = 0.85
    end
    local zoomScale = max(0.55, min(1.35, (targetZoom or 4.5) / 5.0))
    return base * mod * zoomScale
end

local function StartTransitionAnim(db, targetZoom)
    animFrom.shoulder = tonumber(GetCVar("test_cameraOverShoulder")) or 0
    animTo.shoulder   = ComputeTargetShoulder(db, targetZoom)

    animFrom.focus    = tonumber(GetCVar("test_cameraTargetFocusInteractStrengthPitch")) or 0
    local focusBase   = tonumber(db.focusStrength) or 0.80
    animTo.focus      = IsMerchantContext() and max(focusBase, 0.95) or focusBase

    animFrom.pitchPad = tonumber(GetCVar("test_cameraDynamicPitchBaseFovPad")) or 0.4
    animTo.pitchPad   = db.dynamicPitch and 0.35 or animFrom.pitchPad

    local useFov = db.fovZoom and not IsSkyriding()
    animFrom.fov = tonumber(GetCVar("cameraFov")) or 90
    animTo.fov   = useFov and (tonumber(db.fovTarget) or 78) or animFrom.fov

    animStart    = GetTime()
    animDuration = TRANSITION_DUR

    animFrame:SetScript("OnUpdate", function(self)
        if not isActive then
            self:SetScript("OnUpdate", nil)
            return
        end
        if panActive and IsPlayerMoving and IsPlayerMoving() then
            StopPan()
        end

        local elapsed = GetTime() - animStart
        local rawT = min(1, elapsed / animDuration)
        local t = EaseOutCubic(rawT)

        local s = animFrom.shoulder + (animTo.shoulder - animFrom.shoulder) * t
        local f = animFrom.focus + (animTo.focus - animFrom.focus) * t
        SetCVar("test_cameraOverShoulder", format("%.3f", s))
        SetCVar("test_cameraTargetFocusInteractStrengthPitch", format("%.3f", f))
        SetCVar("test_cameraTargetFocusInteractStrengthYaw", format("%.3f", f))

        if db.dynamicPitch then
            local p = animFrom.pitchPad + (animTo.pitchPad - animFrom.pitchPad) * t
            SetCVar("test_cameraDynamicPitchBaseFovPad", format("%.3f", p))
        end

        if useFov then
            local fov = animFrom.fov + (animTo.fov - animFrom.fov) * t
            SetCVar("cameraFov", format("%.2f", fov))
        end

        if rawT >= 1 then
            self:SetScript("OnUpdate", nil)
            if db.subtlePan and not IsMerchantContext() then
                StartPan()
            end
        end
    end)
end

local function EnterCinematic()
    local db = M.db
    local targetZoom = (db and tonumber(db.zoomDistance)) or 4.5
    if isActive then
        if db then
            if IsMerchantContext() then StopPan() end
            StartTransitionAnim(db, targetZoom)
        end
        return
    end
    if not CanEnterCinematic() then return end

    isActive = true
    if Azaath.ActionCam then
        Azaath.ActionCam.npcCinematicActive = true
    end

    SaveCameraState()

    -- Ativa ActionCam de foco no NPC e libera centralização no personagem
    SetCVar("cameraViewBlendStyle", 1)
    SetCVar("CameraKeepCharacterCentered", 0)
    SetCVar("CameraReduceUnexpectedMovement", 0)
    SetCVar("test_cameraTargetFocusInteractEnable", 1)
    SetCVar("test_cameraTargetFocusInteractStrengthPitch", 0)
    SetCVar("test_cameraTargetFocusInteractStrengthYaw", 0)

    if db.dynamicPitch then
        SetCVar("test_cameraDynamicPitch", 1)
    end

    -- Zoom suave até distância de conversa
    local curZoom = GetCameraZoom and GetCameraZoom() or targetZoom
    if curZoom > targetZoom + 0.15 and CameraZoomIn then
        pcall(CameraZoomIn, curZoom - targetZoom)
    elseif curZoom < targetZoom - 1.0 and CameraZoomOut then
        pcall(CameraZoomOut, targetZoom - curZoom)
    end

    StartTransitionAnim(db, targetZoom)

    if db.vignette then
        SetVignetteVisible(true)
    end
end

local function ExitCinematic(instant)
    if not isActive then return end
    isActive = false
    RestoreCameraState(instant)
end

local function ScheduleExitCheck()
    exitTimerToken = exitTimerToken + 1
    local myToken = exitTimerToken
    C_Timer.After(EXIT_DEBOUNCE, function()
        if myToken ~= exitTimerToken then return end
        if not HasAnyContext() then
            ExitCinematic(false)
        end
    end)
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        for k in pairs(activeContexts) do activeContexts[k] = nil end
        exitTimerToken = exitTimerToken + 1
        if isActive and (not M.db or M.db.disableInCombat ~= false) then
            ExitCinematic(true)
        end
        return
    elseif event == "PLAYER_ENTERING_WORLD" or event == "CINEMATIC_START" or event == "PLAY_MOVIE" then
        for k in pairs(activeContexts) do activeContexts[k] = nil end
        exitTimerToken = exitTimerToken + 1
        if isActive then
            ExitCinematic(true)
        end
        return
    end

    local db = M.db
    if not db or not db.enabled then return end

    local qg = QUEST_GOSSIP_EVENTS[event]
    if qg then
        if qg.open then
            if not db.questAndGossip then return end
            activeContexts[qg.ctx] = true
            exitTimerToken = exitTimerToken + 1
            EnterCinematic()
        else
            activeContexts[qg.ctx] = nil
            ScheduleExitCheck()
        end
        return
    end

    local other = OTHER_NPC_EVENTS[event]
    if other then
        if other.open then
            if not db.otherNPCs then return end
            activeContexts[other.ctx] = true
            exitTimerToken = exitTimerToken + 1
            EnterCinematic()
        else
            activeContexts[other.ctx] = nil
            ScheduleExitCheck()
        end
    end
end)

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:ApplyLayout()
    if not self.db then return end
    if not self.db.enabled and isActive then
        for k in pairs(activeContexts) do activeContexts[k] = nil end
        ExitCinematic(false)
    end
end

function M:OnInitialize()
    self.db = Azaath.db and Azaath.db.npcCamera
end

function M:OnEnable()
    if not self.db then self.db = Azaath.db and Azaath.db.npcCamera end
    for ev in pairs(QUEST_GOSSIP_EVENTS) do
        Azaath.SafeRegister(eventFrame, ev)
    end
    for ev in pairs(OTHER_NPC_EVENTS) do
        Azaath.SafeRegister(eventFrame, ev)
    end
    for _, ev in ipairs({ "PLAYER_REGEN_DISABLED", "PLAYER_ENTERING_WORLD", "CINEMATIC_START", "PLAY_MOVIE" }) do
        Azaath.SafeRegister(eventFrame, ev)
    end
end
