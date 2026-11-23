--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Character.lua
    Equipamento "no mundo", no estilo Azaath (3.3.5a e 12.x / Camelot).

    Abre junto com a mochila (tecla B, via Inventory.lua): a câmera do jogo
    gira para a frente do personagem e os espaços de equipamento flutuam ao
    redor dele, direto sobre o mundo (como no inventário do Azaath).
    A tecla C abre a ficha completa (Modules/Sheet/), sem mexer na câmera.

      * Sobreposição de tela cheia sem moldura e sem mouse (cliques no vazio
        continuam indo para o mundo — dá para orbitar a câmera arrastando).
      * Coluna esquerda: armaduras (Cabeça → Pés) com a barra vertical de
        durabilidade ao lado (no lugar da "carga" do Azaath) e, abaixo, as 4
        bolsas equipadas em grade 2x2.
      * Coluna direita: armas no topo, berloques no meio e acessórios
        (colar, anéis, camisa, tabardo e munição) em grade 2x3 embaixo.
      * Painel à esquerda: nível médio de item ("Gear Score"), atributos
        "36 (5 + 31)" e status de ataque, magia e defesa.
      * Base da tela: barras de recurso, experiência e vida, e os botões
        [Reparar tudo] e [Ficha completa] (abre a ficha Azaath).
      * Escurecimento (vinheta) nas laterais e o HUD da Azaath some enquanto
        a tela está aberta. Andar ou entrar em combate fecha tudo.
      * Seguro: em combate apenas consulta; fora de combate equipa e arrasta.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("Character")

local _G = _G
local ipairs, pairs, format, floor, min, max, type, pcall, select =
      ipairs, pairs, string.format, math.floor, math.min, math.max, type, pcall, select

--------------------------------------------------------------------------------
-- Layout (unidades de UI; x relativo ao centro do personagem, y a partir do topo)
--------------------------------------------------------------------------------
local SLOT  = 46
local GAP   = 6
local STEP  = SLOT + GAP
local HALF  = 250              -- distância do centro até a borda externa de cada coluna
local COL_L = -HALF            -- borda esquerda da coluna de armaduras
local COL_R = HALF - SLOT      -- borda esquerda da coluna de armas
local DOLL_W = HALF * 2
local INFO_W, INFO_GAP = 170, 26 -- painel de atributos, à esquerda da coluna de armaduras

local ARMOR_SLOTS  = { "HeadSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "WristSlot",
                       "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot" }
local WEAPON_SLOTS = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot" }
local TRINKET_SLOTS = { "Trinket0Slot", "Trinket1Slot" }
local ACCESSORY_SLOTS = { "NeckSlot", "Finger0Slot", "Finger1Slot", "ShirtSlot", "TabardSlot", "AmmoSlot" }

local ARMOR_H = #ARMOR_SLOTS * STEP - GAP             -- 462
local BAGS_Y  = ARMOR_H + 18                          -- 480
local LOWER_END = BAGS_Y + 2 * STEP - GAP             -- 578
local TRINKET_Y = 3 * STEP + 34
local ACC_Y   = LOWER_END - (3 * STEP - GAP)          -- 428
local VITALS_W = 300
local VITALS_H = 82            -- barras + botões, fixos na base da tela
local DOLL_H  = LOWER_END

-- Espaços que contam para o nível médio de item (sem camisa e tabardo)
local ILVL_SLOTS = { 1, 2, 3, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 }

local POWER_COLORS = {
    [0] = { 0.24, 0.47, 0.85 }, -- mana
    [1] = { 0.78, 0.25, 0.20 }, -- raiva
    [2] = { 0.86, 0.55, 0.26 }, -- foco
    [3] = { 0.92, 0.80, 0.33 }, -- energia
    [6] = { 0.10, 0.72, 0.88 }, -- poder rúnico
}

local frame, shade, doll, vitals
local slots = {}
local attrRows = {}
local ilvlText, duraText, duraBar
local healthBar, powerBar, xpBar, repairButton
local dirty = true

--------------------------------------------------------------------------------
-- Utilitários
--------------------------------------------------------------------------------
local function CreateText(parent, font, size, color, justify, flags)
    local c = color or Azaath.colors.cream
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, flags or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

-- Posiciona uma região no "boneco": x relativo ao centro, y a partir do topo
local function At(region, x, y)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", doll, "TOP", x, -y)
end

local function SafeNum(v, fallback)
    if v == nil or Azaath.IsSecret(v) then return fallback or 0 end
    return v
end

local function FormatAttackPower()
    local base, pos, neg = UnitAttackPower("player")
    if Azaath.AnySecret(base, pos, neg) then return SafeNum(base, "?") end
    return (base or 0) + (pos or 0) + (neg or 0)
end

local function FormatPercent(v)
    if v == nil or Azaath.IsSecret(v) then return "0.00%" end
    return format("%.2f%%", v)
end

local function Rating(id)
    if not (id and GetCombatRatingBonus) then return 0 end
    return SafeNum(GetCombatRatingBonus(id), 0)
end

local function MaxSpellPower()
    local best = 0
    if not GetSpellBonusDamage then return 0 end
    for school = 2, 7 do
        local sp = SafeNum(GetSpellBonusDamage(school), 0)
        if sp > best then best = sp end
    end
    return best
end

local function ShortNumber(v)
    if Azaath.IsSecret(v) then return v end
    return Azaath.Thousands(v or 0)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Câmera cinematográfica de frente para o personagem (estilo Azaath)
--------------------------------------------------------------------------------
local cameraActive = false
local savedViewStored = false
local savedZoom, savedCVars = nil, nil
local orbitActive = false

local camAnimFrame = CreateFrame("Frame")
local camStartTime = 0
local camFrom, camTo = {}, {}
local ENTER_DURATION = 0.40
local EXIT_DURATION  = 0.25

local CAMERA_CVARS = {
    "cameraViewBlendStyle",
    "cameraZoomSpeed",
    "CameraKeepCharacterCentered",
    "CameraReduceUnexpectedMovement",
    "test_cameraOverShoulder",
    "test_cameraDynamicPitch",
    "test_cameraDynamicPitchBaseFovPad",
    "cameraFov",
}

local function GetCV(name)
    local fn = (_G.C_CVar and C_CVar.GetCVar) or _G.GetCVar
    if not fn then return nil end
    local ok, v = pcall(fn, name)
    return ok and v or nil
end

local function SetCV(name, value)
    -- só grava se mudou (cada SetCVar dispara CVAR_UPDATE e contamina a Blizzard)
    local cur = GetCV(name)
    if cur ~= nil then
        local a, b = tonumber(cur), tonumber(value)
        if (a and b and a == b) or tostring(cur) == tostring(value) then return end
    end
    local fn = (_G.C_CVar and C_CVar.SetCVar) or _G.SetCVar
    if fn then pcall(fn, name, value) end
end

local function EaseOutCubic(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    local u = 1 - t
    return 1 - u * u * u
end

local function StopOrbit()
    if not orbitActive then return end
    orbitActive = false
    if _G.MoveViewLeftStop then pcall(_G.MoveViewLeftStop) end
    if _G.MoveViewRightStop then pcall(_G.MoveViewRightStop) end
    if _G.MoveViewUpStop then pcall(_G.MoveViewUpStop) end
    if _G.MoveViewDownStop then pcall(_G.MoveViewDownStop) end
end

local function ZoomTo(distance)
    local cur = _G.GetCameraZoom and GetCameraZoom()
    if cur and not Azaath.IsSecret(cur) then
        if cur > distance + 0.1 then
            pcall(CameraZoomIn, cur - distance)
        elseif cur < distance - 0.1 then
            pcall(CameraZoomOut, distance - cur)
        end
    elseif _G.CameraZoomIn and _G.CameraZoomOut then
        pcall(CameraZoomIn, 50)
        pcall(CameraZoomOut, distance)
    end
end

-- Em combate nada disso é chamado: no motor moderno parte da câmera/CVars é
-- protegida e geraria "A ação falhou devido a um AddOn".
local function EngageCamera()
    local inv = Azaath.db.inventory
    if cameraActive or inv.cameraLock == false or InCombatLockdown() then return end
    local nm, mf = _G.AzaathUIMerchant, _G.MerchantFrame
    if (nm and nm:IsShown()) or (mf and mf:IsShown()) then return end

    cameraActive = true
    if Azaath.ActionCam then
        Azaath.ActionCam.npcCinematicActive = true
    end

    savedCVars = {}
    for _, name in ipairs(CAMERA_CVARS) do
        savedCVars[name] = GetCV(name)
    end
    savedZoom = _G.GetCameraZoom and GetCameraZoom()
    if savedZoom and Azaath.IsSecret(savedZoom) then savedZoom = nil end

    savedViewStored = false
    if _G.SaveView then
        SetCV("cameraViewBlendStyle", 1)
        local ok = pcall(_G.SaveView, 5)
        if ok then savedViewStored = true end
    end

    -- Normaliza o ponto de partida (atrás do personagem, altura nivelada) para que
    -- o enquadramento final seja sempre idêntico independente do ângulo anterior.
    if _G.ResetView and _G.SetView then
        SetCV("cameraViewBlendStyle", 0)
        pcall(_G.ResetView, 2)
        pcall(_G.SetView, 2)
    end
    if _G.ConsoleExec then
        pcall(_G.ConsoleExec, "pitchlimit 5")
    end

    -- Libera centralização rígida e garante zoom rápido e consistente independente da distância anterior
    SetCV("CameraKeepCharacterCentered", 0)
    SetCV("CameraReduceUnexpectedMovement", 0)
    SetCV("cameraViewBlendStyle", 1)
    SetCV("cameraZoomSpeed", 28)
    SetCV("test_cameraDynamicPitch", 0)

    local targetDist = 3.7
    if _G.C_Timer and _G.C_Timer.After then
        _G.C_Timer.After(0, function()
            if cameraActive then ZoomTo(targetDist) end
        end)
    else
        ZoomTo(targetDist)
    end

    camFrom.shoulder = tonumber(GetCV("test_cameraOverShoulder")) or 0
    camTo.shoulder   = 0 -- personagem perfeitamente centralizado
    camFrom.pitchPad = tonumber(GetCV("test_cameraDynamicPitchBaseFovPad")) or 0.4
    camTo.pitchPad   = 0
    camFrom.fov      = tonumber(GetCV("cameraFov")) or 90
    camTo.fov        = 90

    local yawSpeedNorm = 180 / (tonumber(GetCV("cameraYawMoveSpeed")) or 180)
    local targetDeg = 170 -- ângulo frontal consistente (entre Equipamentos e Inventário)
    local baseSpeed = (targetDeg / 180) / (ENTER_DURATION * 0.6366) * yawSpeedNorm

    camStartTime = GetTime()
    local phase = "enter" -- "enter" -> "drift"
    local driftStart = 0

    camAnimFrame:SetScript("OnUpdate", function(self)
        if not cameraActive then
            StopOrbit()
            self:SetScript("OnUpdate", nil)
            return
        end

        local now = GetTime()
        if phase == "enter" then
            local rawT = math.min(1, (now - camStartTime) / ENTER_DURATION)
            local t = EaseOutCubic(rawT)

            -- Órbita suave (ease-in-out senoidal) até a frente do personagem
            if _G.MoveViewRightStart then
                local vel = math.sin(math.pi * rawT) * baseSpeed
                if vel > 0.005 then
                    orbitActive = true
                    pcall(_G.MoveViewRightStart, vel)
                else
                    StopOrbit()
                end
            end

            local s = camFrom.shoulder + (camTo.shoulder - camFrom.shoulder) * t
            local p = camFrom.pitchPad + (camTo.pitchPad - camFrom.pitchPad) * t
            local fov = camFrom.fov + (camTo.fov - camFrom.fov) * t
            SetCV("test_cameraOverShoulder", string.format("%.3f", s))
            SetCV("test_cameraDynamicPitchBaseFovPad", string.format("%.3f", p))
            SetCV("cameraFov", string.format("%.2f", fov))

            if rawT >= 1 then
                StopOrbit()
                phase = "drift"
                driftStart = now
            end
        else
            -- Movimento vivo e sutil (respiração cinematográfica) enquanto o inventário está aberto
            if _G.IsPlayerMoving and _G.IsPlayerMoving() then
                StopOrbit()
                return
            end
            local dt = now - driftStart
            local sway = math.sin(dt * 0.65) * 0.05
            SetCV("test_cameraOverShoulder", string.format("%.3f", camTo.shoulder + sway))
        end
    end)
end

local function FinishDisengage()
    camAnimFrame:SetScript("OnUpdate", nil)
    StopOrbit()
    if _G.ConsoleExec then
        pcall(_G.ConsoleExec, "pitchlimit 88")
    end

    if savedViewStored and _G.SetView then
        SetCV("cameraViewBlendStyle", 0)
        pcall(_G.SetView, 5)
    elseif savedZoom then
        ZoomTo(savedZoom)
    end

    if savedCVars then
        if savedCVars.CameraKeepCharacterCentered ~= nil then
            SetCV("CameraKeepCharacterCentered", savedCVars.CameraKeepCharacterCentered)
        end
        if savedCVars.CameraReduceUnexpectedMovement ~= nil then
            SetCV("CameraReduceUnexpectedMovement", savedCVars.CameraReduceUnexpectedMovement)
        end
        if savedCVars.cameraFov then
            SetCV("cameraFov", savedCVars.cameraFov)
        end
        if savedCVars.cameraZoomSpeed then
            SetCV("cameraZoomSpeed", savedCVars.cameraZoomSpeed)
        end
        if savedCVars.cameraViewBlendStyle then
            SetCV("cameraViewBlendStyle", savedCVars.cameraViewBlendStyle)
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
        if savedCVars.test_cameraOverShoulder ~= nil then
            SetCV("test_cameraOverShoulder", savedCVars.test_cameraOverShoulder)
        end
        if savedCVars.test_cameraDynamicPitch ~= nil then
            SetCV("test_cameraDynamicPitch", savedCVars.test_cameraDynamicPitch)
        end
        if savedCVars.test_cameraDynamicPitchBaseFovPad ~= nil then
            SetCV("test_cameraDynamicPitchBaseFovPad", savedCVars.test_cameraDynamicPitchBaseFovPad)
        end
    end

    savedCVars = nil
    savedZoom = nil
    savedViewStored = false
end

local function DisengageCamera()
    if not cameraActive then return end
    camAnimFrame:SetScript("OnUpdate", nil)
    StopOrbit()
    if _G.ConsoleExec then
        pcall(_G.ConsoleExec, "pitchlimit 88")
    end
    if InCombatLockdown() then
        Azaath:RunOutOfCombat(DisengageCamera)
        return
    end
    cameraActive = false

    -- Retorno rápido e suave (~0.25s) sem usar o blend lento nativo do SetView
    SetCV("cameraZoomSpeed", 28)
    if savedZoom then
        ZoomTo(savedZoom)
    end

    local yawSpeedNorm = 180 / (tonumber(GetCV("cameraYawMoveSpeed")) or 180)
    local targetDeg = 170
    local baseSpeed = (targetDeg / 180) / (EXIT_DURATION * 0.6366) * yawSpeedNorm

    local exitStart = GetTime()
    local exitFromFov = tonumber(GetCV("cameraFov")) or 80
    local exitToFov   = (savedCVars and tonumber(savedCVars.cameraFov)) or 90
    local exitFromSh  = tonumber(GetCV("test_cameraOverShoulder")) or 0
    local exitToSh    = (savedCVars and tonumber(savedCVars.test_cameraOverShoulder)) or 0

    camAnimFrame:SetScript("OnUpdate", function()
        if cameraActive then return end
        local rawT = math.min(1, (GetTime() - exitStart) / EXIT_DURATION)
        local t = EaseOutCubic(rawT)

        if _G.MoveViewLeftStart then
            local vel = math.sin(math.pi * rawT) * baseSpeed
            if vel > 0.005 then
                orbitActive = true
                pcall(_G.MoveViewLeftStart, vel)
            else
                StopOrbit()
            end
        end

        SetCV("cameraFov", string.format("%.2f", exitFromFov + (exitToFov - exitFromFov) * t))
        SetCV("test_cameraOverShoulder", string.format("%.3f", exitFromSh + (exitToSh - exitFromSh) * t))

        if rawT >= 1 then
            FinishDisengage()
        end
    end)
end

--------------------------------------------------------------------------------
-- HUD: some enquanto o personagem está em foco (barra de XP e nível ficam)
--------------------------------------------------------------------------------
local hudAlpha = {}
local HUD_KEEP = { AzaathUIExperienceBar = true, AzaathUILevelBadge = true }

local function SetHUDHidden(hide)
    if hide then
        if not M.db.hideHUD or InCombatLockdown() then return end
        for _, kid in ipairs({ Azaath.root:GetChildren() }) do
            local name = kid:GetName()
            if not (name and HUD_KEEP[name]) and not hudAlpha[kid] then
                hudAlpha[kid] = kid:GetAlpha()
                kid:SetAlpha(0)
            end
        end
    else
        for kid, alpha in pairs(hudAlpha) do kid:SetAlpha(alpha) end
        wipe(hudAlpha)
    end
end

--------------------------------------------------------------------------------
-- Espaços de equipamento
--------------------------------------------------------------------------------
local function Slot_OnEnter(self)
    GameTooltip:SetOwner(self, self.side == "LEFT" and "ANCHOR_LEFT" or "ANCHOR_RIGHT")
    if GetInventoryItemTexture("player", self.slotID) then
        GameTooltip:SetInventoryItem("player", self.slotID)
    elseif self.bagIndex then
        GameTooltip:SetText(_G.BAGSLOT or "Bolsa")
    else
        GameTooltip:SetText(_G[self.slotName:upper()] or self.slotName)
    end
    GameTooltip:Show()
end

local function Slot_OnClick(self, button)
    local link = GetInventoryItemLink("player", self.slotID)
    if link and IsModifiedClick("CHATLINK") then
        ChatEdit_InsertLink(link)
    elseif link and IsModifiedClick("DRESSUP") then
        DressUpItemLink(link)
    elseif InCombatLockdown() then
        return
    elseif self.bagIndex then
        if CursorHasItem() then
            PutItemInBag(self.slotID)
        else
            PickupBagFromSlot(self.slotID)
        end
    elseif SpellIsTargeting and SpellIsTargeting() then
        if UseInventoryItem then UseInventoryItem(self.slotID) end
    elseif button == "RightButton" then
        if UseInventoryItem then UseInventoryItem(self.slotID) end
    else
        PickupInventoryItem(self.slotID)
    end
end

local function Slot_OnDrag(self)
    if InCombatLockdown() then return end
    if self.bagIndex then
        if CursorHasItem() then PutItemInBag(self.slotID) else PickupBagFromSlot(self.slotID) end
    else
        PickupInventoryItem(self.slotID)
    end
end

-- Cliente moderno: usar/aplicar item em espaço de equipamento é ação PROTEGIDA.
-- Um único botão seguro (secureUse) é posicionado sobre o espaço sob o mouse,
-- fora de combate, com /use <slotID>.
local USE_SECURE = Azaath.IS_MODERN and true or false
local secureUse
local AttachSecure

local function DetachSecure()
    if not secureUse or InCombatLockdown() then return end
    local owner = secureUse.owner
    secureUse.owner = nil
    secureUse:Hide()
    secureUse:ClearAllPoints()
    secureUse:SetAttribute("type1", nil)
    secureUse:SetAttribute("type2", nil)
    secureUse:SetAttribute("macrotext", nil)
    secureUse:SetAttribute("macrotext1", nil)
    secureUse:SetAttribute("macrotext2", nil)
    if owner then
        if owner.UnlockHighlight then owner:UnlockHighlight() end
        if owner.hoverRing then owner.hoverRing:Hide() end
        if owner.hoverVeil then owner.hoverVeil:Hide() end
    end
end

local function CreateSecureUse()
    if secureUse or InCombatLockdown() then return end
    local o = CreateFrame("Button", "AzaathUICharEquipUse", UIParent, "SecureActionButtonTemplate")
    o:SetFrameStrata("DIALOG")
    o:RegisterForClicks("AnyUp", "AnyDown")
    o:SetAttribute("useOnKeyDown", false)
    o:RegisterForDrag("LeftButton")
    o:Hide()

    o:SetScript("OnEnter", function(self)
        local owner = self.owner
        if not owner then return end
        if owner.LockHighlight then owner:LockHighlight() end
        if owner.hoverRing then owner.hoverRing:Show() end
        if owner.hoverVeil then owner.hoverVeil:Show() end
        Slot_OnEnter(owner)
    end)
    o:SetScript("OnLeave", function()
        GameTooltip:Hide()
        DetachSecure()
    end)
    o:SetScript("PreClick", function(self, button, down)
        if down then return end
        self._hadType1 = (self:GetAttribute("type1") ~= nil)
        self._hadType2 = (self:GetAttribute("type2") ~= nil)
    end)
    o:SetScript("PostClick", function(self, button, down)
        if down then return end
        local hadType1, hadType2 = self._hadType1, self._hadType2
        self._hadType1, self._hadType2 = nil, nil
        local owner = self.owner
        if not owner then return end
        if button == "LeftButton" and not hadType1 then
            Slot_OnClick(owner, "LeftButton")
        elseif button == "RightButton" and not hadType2 and SpellIsTargeting and SpellIsTargeting() then
            if SpellStopTargeting then pcall(SpellStopTargeting) end
        end
        if self:IsShown() and self.owner and not InCombatLockdown() then
            AttachSecure(self.owner)
        end
    end)
    o:SetScript("OnDragStart", function(self)
        if self.owner then Slot_OnDrag(self.owner) end
    end)
    o:SetScript("OnReceiveDrag", function(self)
        if self.owner then Slot_OnDrag(self.owner) end
    end)

    pcall(o.RegisterEvent, o, "CURRENT_SPELL_CAST_CHANGED")
    o:SetScript("OnEvent", function(self)
        if self:IsShown() and self.owner and not InCombatLockdown() then
            AttachSecure(self.owner)
        end
    end)
    secureUse = o
end

AttachSecure = function(owner)
    if not USE_SECURE or InCombatLockdown() or not owner or not owner:IsVisible() then return end
    if not secureUse then CreateSecureUse() end
    if not secureUse then return end
    local l, t = owner:GetLeft(), owner:GetTop()
    if not (l and t) then return end
    local s = owner:GetEffectiveScale() / secureUse:GetEffectiveScale()
    secureUse:ClearAllPoints()
    secureUse:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * s, t * s)
    secureUse:SetWidth(owner:GetWidth() * s)
    secureUse:SetHeight(owner:GetHeight() * s)
    secureUse.owner = owner
    local macro = format("/use %d", owner.slotID)
    if SpellIsTargeting and SpellIsTargeting() then
        -- Com feitiço/item aguardando alvo (kit de armadura, encantamento etc.),
        -- o clique esquerdo aplica no equipamento e o direito cancela a mira.
        secureUse:SetAttribute("type1", "macro")
        secureUse:SetAttribute("macrotext1", macro)
        secureUse:SetAttribute("type2", nil)
        secureUse:SetAttribute("macrotext2", nil)
    else
        secureUse:SetAttribute("type1", nil)
        secureUse:SetAttribute("type2", "macro")
        secureUse:SetAttribute("macrotext1", nil)
        secureUse:SetAttribute("macrotext2", macro)
    end
    secureUse:SetAttribute("macrotext", macro)
    secureUse:Show()
end

-- Botão de espaço de equipamento (sem posição): usado aqui e na ficha (Modules/Sheet/)
local function MakeSlotButton(parent, globalName, name, slotID, emptyTexture, size, side)
    local c, media = Azaath.colors, Azaath.media
    local b = CreateFrame("Button", globalName, parent)
    b:SetWidth(size)
    b:SetHeight(size)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    b.slotID, b.slotName, b.emptyTexture, b.side = slotID, name, emptyTexture, side

    Azaath.SetBackdrop(b, { bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    b:SetBackdropColor(0.03, 0.04, 0.05, 0.72)

    b.tint = b:CreateTexture(nil, "BACKGROUND")
    b.tint:SetTexture(media.blank)
    b.tint:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    b.tint:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    Azaath.Gradient(b.tint, "VERTICAL", 1, 1, 1, 0.05, 1, 1, 1, 0.3)

    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 3)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    b.cooldown = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b.icon)

    local textLayer = CreateFrame("Frame", nil, b)
    textLayer:SetAllPoints(b)
    textLayer:SetFrameLevel(b.cooldown:GetFrameLevel() + 1)
    b.level = CreateText(textLayer, media.font, 12, c.cream, "LEFT", "OUTLINE")
    b.level:SetPoint("TOPLEFT", b, "TOPLEFT", 3, -3)
    b.count = CreateText(textLayer, media.font, 14, { 1, 1, 1 }, "RIGHT", "OUTLINE")
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)

    -- faixa vermelha na base = durabilidade baixa
    b.broken = textLayer:CreateTexture(nil, "OVERLAY")
    b.broken:SetTexture(media.blank)
    b.broken:SetVertexColor(0.9, 0.2, 0.15)
    b.broken:SetHeight(3)
    b.broken:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 2)
    b.broken:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    b.broken:Hide()

    -- mini-barra vertical de durabilidade no estilo Azaath
    b.duraBar = textLayer:CreateTexture(nil, "OVERLAY")
    b.duraBar:SetTexture(media.blank)
    b.duraBar:SetWidth(2)
    b.duraBar:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    b.duraBar:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 2, 2)
    b.duraBar:Hide()

    -- mini-indicadores de gemas (estilo Aion 2 / nova geração)
    b.gemPips = {}
    for i = 1, 4 do
        local pip = textLayer:CreateTexture(nil, "OVERLAY")
        pip:SetTexture(media.blank)
        pip:SetSize(4, 4)
        pip:SetPoint("TOPLEFT", b, "TOPLEFT", 3 + (i - 1) * 5, -2)
        pip:Hide()
        b.gemPips[i] = pip
    end

    -- mini-indicador de encantamento ativo (canto superior direito)
    b.enchantPip = textLayer:CreateTexture(nil, "OVERLAY")
    b.enchantPip:SetTexture(media.blank)
    b.enchantPip:SetSize(4, 4)
    b.enchantPip:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -2)
    b.enchantPip:SetVertexColor(0.95, 0.82, 0.35, 0.95)
    b.enchantPip:Hide()

    b:SetHighlightTexture(media.blank)
    local hl = b:GetHighlightTexture()
    hl:SetAllPoints(b.icon)
    hl:SetVertexColor(1, 1, 1)
    hl:SetAlpha(0.15)

    b:SetScript("OnEnter", function(self)
        Slot_OnEnter(self)
        if USE_SECURE and not self.bagIndex then AttachSecure(self) end
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnHide", function(self)
        if secureUse and secureUse.owner == self then DetachSecure() end
    end)
    b:SetScript("OnClick", Slot_OnClick)
    b:SetScript("OnDragStart", Slot_OnDrag)
    b:SetScript("OnReceiveDrag", Slot_OnDrag)
    return b
end

local function NewSlotButton(name, slotID, emptyTexture, x, y, side)
    local b = MakeSlotButton(doll, "AzaathUIChar" .. name, name, slotID, emptyTexture, SLOT, side)
    At(b, x, y)
    slots[#slots + 1] = b
    return b
end

-- Retorna nil se o espaço não existir neste cliente (ex.: munição no motor moderno)
local function CreateSlot(slotName, x, y, side)
    local ok, slotID, emptyTexture = pcall(GetInventorySlotInfo, slotName)
    if not ok or not slotID then return nil end
    return NewSlotButton(slotName, slotID, emptyTexture, x, y, side)
end

local function CreateBagSlot(index, x, y)
    local slotName = format("Bag%dSlot", index - 1)
    local ok, slotID, emptyTexture = pcall(GetInventorySlotInfo, slotName)
    if not ok or not slotID then
        local toInv = (_G.C_Container and C_Container.ContainerIDToInventoryID) or _G.ContainerIDToInventoryID
        slotID = toInv and toInv(index)
        emptyTexture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"
    end
    if not slotID then return nil end
    local b = NewSlotButton(slotName, slotID, emptyTexture or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag", x, y, "LEFT")
    b.bagIndex = index
    return b
end

local function UpdateSlot(b)
    local c = Azaath.colors
    local texture = GetInventoryItemTexture("player", b.slotID)
    if texture then
        b.icon:SetTexture(texture)
        b.icon:SetDesaturated(false)
        b.icon:SetAlpha(1)
        local quality = GetInventoryItemQuality("player", b.slotID)
        if quality and not Azaath.IsSecret(quality) and quality >= 2 then
            local r, g, bl = Azaath.API.GetItemQualityColor(quality)
            r, g, bl = r or 1, g or 1, bl or 1
            Azaath.Gradient(b.tint, "VERTICAL", r, g, bl, 0.08, r, g, bl, 0.4)
            b:SetBackdropBorderColor(r, g, bl, 0.9)
        else
            Azaath.Gradient(b.tint, "VERTICAL", 1, 1, 1, 0.05, 1, 1, 1, 0.3)
            b:SetBackdropBorderColor(c.slate[1], c.slate[2], c.slate[3], 0.8)
        end
        b.tint:Show()

        if b.bagIndex then
            -- bolsa: número de espaços no canto
            b.level:SetText("")
            local n = Azaath.API.GetContainerNumSlots(b.bagIndex)
            b.count:SetText(SafeNum(n, 0) > 0 and n or "")
            if b.gemPips then for i = 1, 4 do b.gemPips[i]:Hide() end end
            if b.enchantPip then b.enchantPip:Hide() end
        else
            local link = GetInventoryItemLink("player", b.slotID)
            local level = link and select(4, Azaath.API.GetItemInfo(link))
            b.level:SetText((level and not Azaath.IsSecret(level) and level > 1) and level or "")
            local n = GetInventoryItemCount and GetInventoryItemCount("player", b.slotID)
            b.count:SetText((n and not Azaath.IsSecret(n) and n > 1) and n or "")

            -- Indicadores de Gemas e Encantamento
            if b.gemPips and link then
                do
                    local _, enchantID, gem1, gem2, gem3, gem4 = link:match("item:(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)")
                    local gems = { gem1, gem2, gem3, gem4 }
                    local socketTypes = {}
                    local okStats, stats = pcall(GetItemStats, link)
                    if okStats and type(stats) == "table" then
                        for k, v in pairs(stats) do
                            if type(k) == "string" and k:find("EMPTY_SOCKET") then
                                local count = type(v) == "number" and v or 1
                                local sType = k:match("EMPTY_SOCKET_(%w+)") or "PRISMATIC"
                                for _ = 1, count do
                                    socketTypes[#socketTypes + 1] = sType
                                end
                            end
                        end
                    end
                    local filledCount = 0
                    for i = 1, 4 do
                        local gid = tonumber(gems[i])
                        if gid and gid > 0 then filledCount = filledCount + 1 end
                    end
                    local totalSockets = max(#socketTypes, filledCount)
                    if totalSockets > 4 then totalSockets = 4 end

                    for i = 1, 4 do
                        local pip = b.gemPips[i]
                        if i <= totalSockets then
                            local gid = tonumber(gems[i])
                            local isFilled = gid and gid > 0
                            local sType = socketTypes[i] or "PRISMATIC"
                            local cr, cg, cb = 0.85, 0.85, 0.85
                            if sType == "RED" then cr, cg, cb = 0.95, 0.25, 0.25
                            elseif sType == "BLUE" then cr, cg, cb = 0.25, 0.65, 0.95
                            elseif sType == "YELLOW" then cr, cg, cb = 0.95, 0.85, 0.2
                            elseif sType == "META" then cr, cg, cb = 0.9, 0.9, 1.0
                            elseif sType == "PRISMATIC" then cr, cg, cb = 0.8, 0.45, 0.95
                            end
                            pip:SetVertexColor(cr, cg, cb, isFilled and 0.95 or 0.3)
                            pip:Show()
                        else
                            pip:Hide()
                        end
                    end

                    if b.enchantPip then
                        local eid = enchantID and tonumber(enchantID)
                        if eid and eid > 0 then
                            b.enchantPip:Show()
                        else
                            b.enchantPip:Hide()
                        end
                    end
                end
            else
                if b.gemPips then for i = 1, 4 do b.gemPips[i]:Hide() end end
                if b.enchantPip then b.enchantPip:Hide() end
            end
        end

        local cur, maxDur = GetInventoryItemDurability(b.slotID)
        if cur and maxDur and not Azaath.AnySecret(cur, maxDur) and maxDur > 0 and cur / maxDur < 0.25 then
            b.broken:Show()
        else
            b.broken:Hide()
        end
        if b.duraBar then
            if cur and maxDur and not Azaath.AnySecret(cur, maxDur) and maxDur > 0 and cur < maxDur then
                local ratio = cur / maxDur
                b.duraBar:SetHeight(max(4, (b:GetHeight() - 4) * ratio))
                if ratio < 0.25 then
                    b.duraBar:SetVertexColor(0.9, 0.2, 0.15)
                elseif ratio < 0.60 then
                    b.duraBar:SetVertexColor(0.95, 0.75, 0.2)
                else
                    b.duraBar:SetVertexColor(0.2, 0.8, 0.4)
                end
                b.duraBar:Show()
            else
                b.duraBar:Hide()
            end
        end
        local start, duration, enable = GetInventoryItemCooldown("player", b.slotID)
        if Azaath.IsOn(enable) and start and not Azaath.AnySecret(start, duration, enable) and start > 0 and duration > 0 then
            b.cooldown:SetCooldown(start, duration)
            b.cooldown:Show()
        else
            b.cooldown:Hide()
        end
    else
        b.icon:SetTexture(b.emptyTexture)
        b.icon:SetDesaturated(true)
        b.icon:SetAlpha(0.3)
        b.tint:Hide()
        b:SetBackdropBorderColor(c.slate[1], c.slate[2], c.slate[3], 0.45)
        b.level:SetText("")
        b.count:SetText("")
        b.broken:Hide()
        b.cooldown:Hide()
        if b.duraBar then b.duraBar:Hide() end
        if b.gemPips then for i = 1, 4 do b.gemPips[i]:Hide() end end
        if b.enchantPip then b.enchantPip:Hide() end
    end
end

--------------------------------------------------------------------------------
-- Números
--------------------------------------------------------------------------------
local function AverageItemLevel()
    local total = 0
    for _, id in ipairs(ILVL_SLOTS) do
        local link = GetInventoryItemLink("player", id)
        if link then
            local _, _, _, level, _, _, _, _, equipLoc = Azaath.API.GetItemInfo(link)
            level = SafeNum(level, 0)
            total = total + level
            if id == 16 and equipLoc == "INVTYPE_2HWEAPON" and not GetInventoryItemLink("player", 17) then
                total = total + level
            end
        end
    end
    return floor(total / #ILVL_SLOTS + 0.5)
end

local function Durability()
    local cur, maxDur = 0, 0
    for id = 1, 18 do
        local c, m = GetInventoryItemDurability(id)
        if c and m and not Azaath.AnySecret(c, m) and m > 0 then
            cur, maxDur = cur + c, maxDur + m
        end
    end
    if maxDur == 0 then return 1 end
    return cur / maxDur
end

local function Call(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    return ok and v or nil
end

local function Pct(fn, ...) return FormatPercent(Call(fn, ...)) end

local function ManaRegen()
    local base = Call(_G.GetManaRegen)
    if base == nil or Azaath.IsSecret(base) then return "—" end
    return format("%.1f / s", base * 1) -- GetManaRegen já vem por segundo
end

local ATTRIBUTES = {
    { "Força", 1 }, { "Agilidade", 2 }, { "Vigor", 3 }, { "Intelecto", 4 }, { "Espírito", 5 },
}

-- Seções do painel de status (rótulo, função que devolve o valor)
local SECTIONS = {
    { title = "Ataque", rows = {
        { "Poder de ataque", FormatAttackPower },
        { "Crítico", function() return Pct(_G.GetCritChance) end },
        { "Acerto", function() return FormatPercent(Rating(_G.CR_HIT_MELEE or 6)) end },
        { "Aceleração", function() return FormatPercent(Rating(_G.CR_HASTE_MELEE or 18)) end },
    } },
    { title = "Magia", rows = {
        { "Poder mágico", MaxSpellPower },
        { "Crítico mágico", function() return Pct(_G.GetSpellCritChance, 2) end },
        { "Aceleração mágica", function() return FormatPercent(Rating(_G.CR_HASTE_SPELL or 20)) end },
        { "Regeneração", ManaRegen },
    } },
    { title = "Defesa", rows = {
        { "Armadura", function() return select(2, UnitArmor("player")) or 0 end },
        { "Esquiva", function() return Pct(_G.GetDodgeChance) end },
        { "Aparar", function() return Pct(_G.GetParryChance) end },
        { "Bloqueio", function() return Pct(_G.GetBlockChance) end },
    } },
}
local sectionRows = {} -- { def, value }

local function UpdateStats()
    ilvlText:SetText(AverageItemLevel())

    for i, def in ipairs(ATTRIBUTES) do
        local row = attrRows[i]
        local _, stat, pos, neg = UnitStat("player", def[2])
        if Azaath.AnySecret(stat, pos, neg) then
            row.value:SetText(stat)
            row.extra:SetText("")
        else
            stat = stat or 0
            local bonus = (pos or 0) + (neg or 0)
            row.value:SetText(floor(stat + 0.5))
            if bonus ~= 0 then
                row.extra:SetText(format("(%d %s %d)", floor(stat - bonus + 0.5), bonus > 0 and "+" or "-", math.abs(floor(bonus + 0.5))))
            else
                row.extra:SetText("")
            end
        end
    end

    for _, row in ipairs(sectionRows) do
        local ok, v = pcall(row.def[2])
        if not ok or v == nil then v = "—" end
        row.value:SetText(type(v) == "number" and Azaath.Thousands(v) or v)
    end

    local d = Durability()
    duraText:SetText(format("%d%%", floor(d * 100 + 0.5)))
    duraBar:SetValue(d)
    if d < 0.25 then
        duraBar:SetStatusBarColor(0.85, 0.25, 0.2)
    elseif d < 0.5 then
        duraBar:SetStatusBarColor(0.85, 0.7, 0.25)
    else
        duraBar:SetStatusBarColor(0.25, 0.62, 0.42)
    end
end

local function UpdateVitals()
    -- vida (valores secretos podem ir direto para o widget)
    local cur, mx = UnitHealth("player"), UnitHealthMax("player")
    healthBar:SetMinMaxValues(0, Azaath.IsSecret(mx) and mx or max(1, mx or 1))
    healthBar:SetValue(cur)
    healthBar.text:SetText(ShortNumber(cur))

    local ptype = UnitPowerType("player")
    local pmax, pcur = UnitPowerMax("player"), UnitPower("player")
    if not Azaath.IsSecret(pmax) and (pmax or 0) <= 0 then
        powerBar:Hide()
    else
        powerBar:Show()
        local col = (not Azaath.IsSecret(ptype) and POWER_COLORS[ptype]) or { 0.6, 0.6, 0.6 }
        powerBar:SetStatusBarColor(col[1], col[2], col[3])
        powerBar:SetMinMaxValues(0, pmax)
        powerBar:SetValue(pcur)
        powerBar.text:SetText(ShortNumber(pcur))
    end

    local level = UnitLevel("player")
    local xmax = UnitXPMax("player")
    if Azaath.API.MaxLevel() <= (level or 0) or not xmax or Azaath.IsSecret(xmax) or xmax <= 0 then
        xpBar:SetMinMaxValues(0, 1)
        xpBar:SetValue(1)
        xpBar.text:SetText(format("Nível %d", level or 0))
    else
        local xp = UnitXP("player") or 0
        xpBar:SetMinMaxValues(0, xmax)
        xpBar:SetValue(xp)
        xpBar.text:SetText(format("Nível %d  ·  %d%%", level, floor(xp / xmax * 100)))
    end
end

local function UpdateRepair()
    if not repairButton then return end
    local canRepair = _G.CanMerchantRepair and CanMerchantRepair()
        and _G.MerchantFrame and MerchantFrame:IsShown()
    local cost = canRepair and _G.GetRepairAllCost and GetRepairAllCost() or 0
    repairButton.active = canRepair and cost and cost > 0
    local c = Azaath.colors
    local col = repairButton.active and c.cream or c.dim
    repairButton.text:SetTextColor(col[1], col[2], col[3])
    repairButton.cost = cost
end

local function UpdateAll()
    dirty = false
    for _, b in ipairs(slots) do UpdateSlot(b) end
    UpdateStats()
    UpdateVitals()
    UpdateRepair()
end

--------------------------------------------------------------------------------
-- Construção
--------------------------------------------------------------------------------
local function MakeBar(y, height, r, g, b, fontSize)
    local media = Azaath.media
    local bar = CreateFrame("StatusBar", nil, vitals)
    bar:SetWidth(VITALS_W)
    bar:SetHeight(height)
    bar:SetPoint("TOPLEFT", vitals, "TOPLEFT", 0, -y)
    bar:SetStatusBarTexture(media.blank)
    bar:SetStatusBarColor(r, g, b)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    Azaath.SetBackdrop(bar, { bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 } })
    bar:SetBackdropColor(0, 0, 0, 0.55)
    bar:SetBackdropBorderColor(0, 0, 0, 0.8)
    bar.text = CreateText(bar, media.font, fontSize or 10, { 1, 1, 1 }, "CENTER", "OUTLINE")
    bar.text:SetPoint("CENTER", bar, "CENTER", 0, 0)
    return bar
end

local function MakeButton(label, x, y, width, onClick)
    local c, media = Azaath.colors, Azaath.media
    local b = CreateFrame("Button", nil, vitals)
    b:SetWidth(width)
    b:SetHeight(22)
    b:SetPoint("TOPLEFT", vitals, "TOPLEFT", x, -y)
    Azaath.SetBackdrop(b, { bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    b:SetBackdropColor(0.05, 0.065, 0.08, 0.85)
    b:SetBackdropBorderColor(c.slate[1], c.slate[2], c.slate[3], 0.7)
    b.text = CreateText(b, media.font, 12, c.cream, "CENTER")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.9) end)
    b:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(c.slate[1], c.slate[2], c.slate[3], 0.7)
        GameTooltip:Hide()
    end)
    b:SetScript("OnClick", function(self, button)
        Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        onClick(self, button)
    end)
    return b
end

-- Fecha a mochila e abre a ficha Azaath (Modules/Sheet/) na aba pedida
local function OpenSheet(tab)
    M:Close()
    local sheet = Azaath:GetModule("Sheet")
    if sheet and sheet.Open and Azaath.db.sheet and Azaath.db.sheet.enabled then
        sheet:Open(tab)
    elseif _G.ToggleCharacter then
        pcall(ToggleCharacter, "PaperDollFrame")
    end
end

local function BuildShade()
    local media = Azaath.media
    shade = CreateFrame("Frame", nil, frame)
    shade:SetAllPoints(frame)
    shade:SetFrameStrata("BACKGROUND")

    local base = shade:CreateTexture(nil, "BACKGROUND")
    base:SetTexture(media.blank)
    base:SetVertexColor(0, 0, 0)
    base:SetAlpha(0.18)
    base:SetAllPoints(shade)

    -- laterais escuras, centro livre para o personagem
    local left = shade:CreateTexture(nil, "BORDER")
    left:SetTexture(media.blank)
    left:SetPoint("TOPLEFT", shade, "TOPLEFT", 0, 0)
    left:SetPoint("BOTTOMRIGHT", shade, "BOTTOM", -200, 0)
    Azaath.Gradient(left, "HORIZONTAL", 0, 0, 0, 0.6, 0, 0, 0, 0)

    local right = shade:CreateTexture(nil, "BORDER")
    right:SetTexture(media.blank)
    right:SetPoint("TOPLEFT", shade, "TOP", 120, 0)
    right:SetPoint("BOTTOMRIGHT", shade, "BOTTOMRIGHT", 0, 0)
    Azaath.Gradient(right, "HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, 0.6)

    local bottom = shade:CreateTexture(nil, "BORDER")
    bottom:SetTexture(media.blank)
    bottom:SetPoint("BOTTOMLEFT", shade, "BOTTOMLEFT", 0, 0)
    bottom:SetPoint("BOTTOMRIGHT", shade, "BOTTOMRIGHT", 0, 0)
    bottom:SetHeight(260)
    Azaath.Gradient(bottom, "VERTICAL", 0, 0, 0, 0.55, 0, 0, 0, 0)
end

local function Build()
    local c, media = Azaath.colors, Azaath.media

    -- Sobreposição de tela cheia (sem mouse: o mundo continua clicável)
    frame = CreateFrame("Frame", "AzaathUICharacter", UIParent)
    M.frame = frame
    frame:SetAllPoints(UIParent)
    frame:SetFrameStrata("MEDIUM")
    frame:EnableMouse(false)
    frame:Hide()
    tinsert(UISpecialFrames, "AzaathUICharacter")

    BuildShade()

    doll = CreateFrame("Frame", "AzaathUIPaperDoll", frame)
    M.doll = doll
    doll:SetFrameStrata("HIGH")
    doll:SetWidth(DOLL_W)
    doll:SetHeight(DOLL_H)
    doll:EnableMouse(false)

    -- barras e botões ficam na base da tela, abaixo dos pés do personagem
    vitals = CreateFrame("Frame", "AzaathUIPaperDollVitals", frame)
    vitals:SetFrameStrata("HIGH")
    vitals:SetWidth(VITALS_W)
    vitals:SetHeight(VITALS_H)
    vitals:EnableMouse(false)

    ----------------------------------------------------------------------------
    -- Coluna esquerda: armaduras + durabilidade + bolsas
    ----------------------------------------------------------------------------
    for i, name in ipairs(ARMOR_SLOTS) do
        CreateSlot(name, COL_L, (i - 1) * STEP, "LEFT")
    end

    duraBar = CreateFrame("StatusBar", nil, doll)
    duraBar:SetOrientation("VERTICAL")
    duraBar:SetWidth(4)
    duraBar:SetHeight(ARMOR_H)
    At(duraBar, COL_L + SLOT + 5, 0)
    duraBar:SetStatusBarTexture(media.blank)
    duraBar:SetMinMaxValues(0, 1)
    local duraBg = duraBar:CreateTexture(nil, "BACKGROUND")
    duraBg:SetTexture(media.blank)
    duraBg:SetVertexColor(0, 0, 0, 0.6)
    duraBg:SetAllPoints(duraBar)
    -- marcas de 25% / 50% / 75%
    for _, p in ipairs({ 0.25, 0.5, 0.75 }) do
        local tick = duraBar:CreateTexture(nil, "OVERLAY")
        tick:SetTexture(media.blank)
        tick:SetVertexColor(0, 0, 0, 0.8)
        tick:SetHeight(1)
        tick:SetWidth(8)
        tick:SetPoint("CENTER", duraBar, "BOTTOM", 0, ARMOR_H * p)
    end

    duraText = CreateText(doll, media.font, 15, c.cream, "LEFT")
    At(duraText, COL_L + SLOT + 14, 0)
    local duraLabel = CreateText(doll, media.fontTitleB, 8, c.dim, "LEFT")
    duraLabel:SetPoint("TOPLEFT", duraText, "BOTTOMLEFT", 0, -2)
    duraLabel:SetText("DURABILIDADE")

    for i = 1, 4 do
        local col, row = (i - 1) % 2, floor((i - 1) / 2)
        CreateBagSlot(i, COL_L + col * STEP, BAGS_Y + row * STEP)
    end

    ----------------------------------------------------------------------------
    -- Coluna direita: armas, berloques, acessórios
    ----------------------------------------------------------------------------
    for i, name in ipairs(WEAPON_SLOTS) do
        CreateSlot(name, COL_R, (i - 1) * STEP, "RIGHT")
    end
    for i, name in ipairs(TRINKET_SLOTS) do
        CreateSlot(name, COL_R, TRINKET_Y + (i - 1) * STEP, "RIGHT")
    end
    local accIndex = 0
    for _, name in ipairs(ACCESSORY_SLOTS) do
        local col, row = accIndex % 2, floor(accIndex / 2)
        if CreateSlot(name, COL_R - STEP + col * STEP, ACC_Y + row * STEP, "RIGHT") then
            accIndex = accIndex + 1
        end
    end

    ----------------------------------------------------------------------------
    -- Painel de status à esquerda: nível de item, atributos, ataque, magia, defesa
    ----------------------------------------------------------------------------
    local ix = COL_L - INFO_GAP - INFO_W
    local info = CreateFrame("Frame", nil, doll)
    info:SetWidth(INFO_W + 16)
    At(info, ix - 8, -8)
    local infoBg = info:CreateTexture(nil, "BACKGROUND")
    infoBg:SetTexture(media.blank)
    infoBg:SetAllPoints(info)
    Azaath.Gradient(infoBg, "HORIZONTAL", 0, 0, 0, 0.15, 0, 0, 0, 0.55)
    local infoEdge = info:CreateTexture(nil, "ARTWORK")
    infoEdge:SetTexture(media.blank)
    infoEdge:SetWidth(1)
    infoEdge:SetPoint("TOPRIGHT", info, "TOPRIGHT", 0, 0)
    infoEdge:SetPoint("BOTTOMRIGHT", info, "BOTTOMRIGHT", 0, 0)
    Azaath.Gradient(infoEdge, "VERTICAL", c.gold[1], c.gold[2], c.gold[3], 0, c.gold[1], c.gold[2], c.gold[3], 0.6)

    ilvlText = CreateText(doll, media.font, 34, c.cream, "LEFT")
    At(ilvlText, ix, 0)
    local ilvlLabel = CreateText(doll, media.font, 12, c.cream, "LEFT")
    ilvlLabel:SetPoint("LEFT", ilvlText, "RIGHT", 8, 0)
    ilvlLabel:SetText("Nível\nde item")

    local ROW_H = 17
    local y = 48
    local function Header(text)
        y = y + 6
        local h = CreateText(doll, media.fontTitleB, 10, c.gold, "LEFT")
        At(h, ix, y)
        h:SetText(Azaath.Tracked(text))
        local line = doll:CreateTexture(nil, "ARTWORK")
        line:SetTexture(media.blank)
        line:SetHeight(1)
        line:SetWidth(INFO_W)
        At(line, ix, y + 15)
        Azaath.Gradient(line, "HORIZONTAL", c.gold[1], c.gold[2], c.gold[3], 0.7, c.gold[1], c.gold[2], c.gold[3], 0)
        y = y + 21
    end
    local function Row()
        local row = {}
        row.label = CreateText(doll, media.font, 13, c.cream)
        At(row.label, ix, y)
        row.value = CreateText(doll, media.font, 13, { 1, 1, 1 }, "RIGHT")
        row.value:SetPoint("TOPRIGHT", doll, "TOP", ix + INFO_W, -y)
        y = y + ROW_H
        return row
    end

    Header("Atributos")
    for _, def in ipairs(ATTRIBUTES) do
        local row = Row()
        row.label:SetText(def[1])
        -- "(base + bônus)" fica entre o rótulo e o valor
        row.extra = CreateText(doll, media.font, 11, c.dim, "RIGHT")
        row.extra:SetPoint("RIGHT", row.value, "LEFT", -6, 0)
        attrRows[#attrRows + 1] = row
    end
    for _, section in ipairs(SECTIONS) do
        Header(section.title)
        for _, def in ipairs(section.rows) do
            local row = Row()
            row.label:SetText(def[1])
            row.def = def
            sectionRows[#sectionRows + 1] = row
        end
    end
    info:SetHeight(y + 16)

    ----------------------------------------------------------------------------
    -- Centro inferior: barras e botões
    ----------------------------------------------------------------------------
    local p = c.parchment
    powerBar  = MakeBar(0, 12, 0.24, 0.47, 0.85, 9)
    xpBar     = MakeBar(16, 12, c.gold[1], c.gold[2] * 0.95, c.gold[3] * 0.6, 9)
    healthBar = MakeBar(32, 18, p[1], p[2], p[3], 11)
    healthBar.text:SetTextColor(0.1, 0.1, 0.1)
    healthBar.text:SetShadowOffset(0, 0)
    healthBar.text:SetFont(media.font, 11, "")

    local btnY = 58
    local btnW = floor((VITALS_W - 8) / 2)
    repairButton = MakeButton("Reparar tudo", 0, btnY, btnW, function(self)
        if self.active and _G.RepairAllItems then
            RepairAllItems()
            UpdateAll()
        end
    end)
    repairButton:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        if self.active then
            GameTooltip:SetText("Reparar todo o equipamento")
            GameTooltip:AddLine(Azaath.FormatMoney(self.cost or 0), 1, 1, 1)
        else
            GameTooltip:SetText("Reparar tudo")
            GameTooltip:AddLine("Disponível com um ferreiro/vendedor que conserta.", 0.7, 0.7, 0.7, true)
        end
        GameTooltip:Show()
    end)

    local sheet = MakeButton("Ficha completa", btnW + 8, btnY, btnW, function(self, button)
        if button == "RightButton" then
            Azaath:ShowMenu({
                title = "Ficha",
                { text = "Reputação", func = function() OpenSheet("reputation") end },
                { text = "Habilidades", func = function() OpenSheet("skills") end },
                { text = "Moedas", func = function() OpenSheet("currency") end },
            })
        else
            OpenSheet("character")
        end
    end)
    sheet:HookScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Ficha completa")
        GameTooltip:AddLine("Clique direito: reputação, moedas e habilidades.", 0.7, 0.7, 0.7, true)
        GameTooltip:Show()
    end)

    ----------------------------------------------------------------------------
    -- Scripts
    ----------------------------------------------------------------------------
    frame:SetScript("OnShow", function()
        M:Layout()
        EngageCamera()
        SetHUDHidden(true)
        UpdateAll()
        Azaath.PlaySound("igCharacterInfoOpen")

        local inv = Azaath:GetModule("Inventory")
        if M.db.unified ~= false and Azaath.db.inventory.unified ~= false and inv then
            if inv.frame and inv.frame:IsShown() then
                if inv.Reposition then inv:Reposition() end
            elseif inv.Open then
                inv:Open(true)
            end
        end
    end)

    frame:SetScript("OnHide", function()
        DisengageCamera()
        SetHUDHidden(false)
        Azaath.PlaySound("igCharacterInfoClose")

        local inv = Azaath:GetModule("Inventory")
        if inv and inv.frame and inv.frame:IsShown() then
            if Azaath.db.inventory.unified ~= false and inv.Close and not M.keepInventory then
                inv:Close(true)
            elseif inv.Reposition then
                inv:Reposition()
            end
        end
    end)

    local elapsed = 0
    frame:SetScript("OnUpdate", function(_, e)
        elapsed = elapsed + e
        if elapsed < 0.2 then return end
        elapsed = 0
        if dirty then UpdateAll() else UpdateVitals() end
    end)
end

-- Escala e posição do "boneco". A câmera do WoW mira na cabeça (centro da
-- tela), então o corpo fica na metade de baixo: o conjunto ocupa ~68% da
-- altura e começa um pouco acima da cabeça, como no Azaath.
local HEIGHT_PCT, TOP_PCT, BOTTOM_GAP = 0.60, 0.19, 26

function M:Layout()
    if not doll then return end
    local h = UIParent:GetHeight()
    local scale = min(1.8, h * HEIGHT_PCT / DOLL_H) * (self.db.scale or 1)
    local ox = (self.db.offsetX or 0) / scale
    doll:SetScale(scale)
    doll:ClearAllPoints()
    doll:SetPoint("TOP", UIParent, "TOP", ox, (-h * TOP_PCT + (self.db.offsetY or 0)) / scale)
    vitals:SetScale(scale)
    vitals:ClearAllPoints()
    vitals:SetPoint("BOTTOM", UIParent, "BOTTOM", ox, BOTTOM_GAP / scale)
end

--------------------------------------------------------------------------------
-- Métodos públicos
--------------------------------------------------------------------------------
function M:IsOpen()
    return frame and frame:IsShown()
end

function M:Open(fromInv)
    if not frame then return end
    if InCombatLockdown() then
        -- em combate (como no Azaath): só o inventário, sem girar a câmera
        local inv = Azaath:GetModule("Inventory")
        if not fromInv and inv and inv.Open and not (inv.frame and inv.frame:IsShown()) then
            inv:Open(true)
        end
        return
    end
    if not frame:IsShown() then frame:Show() end
end

function M:Close(fromInv)
    if not frame then return end
    if frame:IsShown() then frame:Hide() end
end

function M:Toggle()
    local inv = Azaath:GetModule("Inventory")
    local invShown = inv and inv.frame and inv.frame:IsShown()
    if (frame and frame:IsShown()) or invShown then
        self:Close()
        if inv and inv.Close and invShown then inv:Close(true) end
    else
        self:Open()
    end
end

-- API compartilhada com a ficha do personagem (Modules/Sheet/, tecla C)
M.UpdateSlot = UpdateSlot
M.AverageItemLevel = AverageItemLevel
M.Durability = Durability
M.ATTRIBUTES = ATTRIBUTES
M.SECTIONS = SECTIONS
M.POWER_COLORS = POWER_COLORS
function M.CreateEquipSlot(parent, slotName, size, side, prefix)
    local ok, slotID, emptyTexture = pcall(GetInventorySlotInfo, slotName)
    if not ok or not slotID then return nil end
    return MakeSlotButton(parent, (prefix or "AzaathUISheet") .. slotName, slotName, slotID, emptyTexture, size, side)
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
    if not (frame and frame:IsShown()) then
        dirty = true
        return
    end
    if event == "PLAYER_STARTED_MOVING" or event == "PLAYER_REGEN_DISABLED" then
        -- andando com a opção ligada: fecha só o personagem (solta a câmera)
        -- e deixa o inventário aberto
        M.keepInventory = (event == "PLAYER_STARTED_MOVING" and Azaath.db.inventory.keepOnMove ~= false)
        M:Close()
        M.keepInventory = false
        return
    end
    if event == "MERCHANT_SHOW" or event == "MERCHANT_CLOSED" then
        UpdateRepair()
        return
    end
    if event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        M:Layout()
        return
    end
    if event:sub(1, 5) == "UNIT_" and unit ~= "player" then return end
    dirty = true
end)

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:OnInitialize()
    self.db = Azaath.db.character
end

function M:OnEnable()
    if not self.db.enabled then return end
    Build()
    -- abre pela mochila (tecla B / Inventory.lua); a tecla C é da ficha (Modules/Sheet/)

    for _, e in ipairs({ "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_INVENTORY_DURABILITY",
                         "UNIT_STATS", "UNIT_RESISTANCES", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER",
                         "COMBAT_RATING_UPDATE", "PLAYER_DAMAGE_DONE_MODS", "PLAYER_LEVEL_UP",
                         "BAG_UPDATE", "BAG_UPDATE_COOLDOWN", "MERCHANT_SHOW", "MERCHANT_CLOSED",
                         "PLAYER_STARTED_MOVING", "PLAYER_REGEN_DISABLED",
                         "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
        Azaath.SafeRegister(events, e)
    end
end
