--[[----------------------------------------------------------------------------
    AzaathUI - Modules/StancePetBars.lua
    Barra de postura/forma/aura/presença e barra de pet (3.3.5a).

    POSTURA — botões PRÓPRIOS (CheckButton + SecureActionButtonTemplate):
      * type = "click" + clickbutton = ShapeshiftButtonN (oculto, da Blizzard).
        O clique é repassado pela cadeia segura ao botão original, que chama
        CastShapeshiftForm(N). Funciona em combate e é baseado em ÍNDICE, então
        não depende do nome localizado da forma.
      * Não reaproveitamos ShapeshiftButton1-10 porque ShapeshiftBar_Update()
        re-ancora o botão 1 ao ShapeshiftBarFrame, desfazendo o layout.
      * Quantidade de botões só muda ao aprender formas: Show/Hide e o driver de
        visibilidade são aplicados fora de combate (fila do Core).

    PET — botões DA BLIZZARD (PetActionButton1-10) reparentados:
      * Mantém toda a lógica nativa: clique esquerdo usa a ação, clique direito
        alterna autocast (TogglePetAutocast é chamado pelo OnClick seguro da
        Blizzard), keybinds BONUSACTIONBUTTONx, brilho de autocast, grid.
      * O PetActionBarFrame continua registrado nos eventos (oculto no hider)
        e segue atualizando ícones/cooldowns dos botões, agora no nosso layout.
      * Restyle só via métodos de widget + hooksecurefunc (pós-hook não
        contamina a função original).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("StancePetBars")

local _G = _G
local ipairs = ipairs
local GetNumShapeshiftForms, GetShapeshiftFormInfo = GetNumShapeshiftForms, GetShapeshiftFormInfo
local GetShapeshiftFormCooldown = GetShapeshiftFormCooldown

local NUM_STANCE = NUM_SHAPESHIFT_SLOTS or 10
local NUM_PET    = NUM_PET_ACTION_SLOTS or 10
local GAP        = 4 -- distância vertical até a barra de ação superior

local STANCE_VISIBILITY = "[vehicleui] hide; [bonusbar:5] hide; show"
local PET_VISIBILITY    = "[vehicleui] hide; [bonusbar:5] hide; [pet] show; hide"

local stanceBar, petBar
local stanceButtons = {}
local layoutPending = false

local function HideTooltip() GameTooltip:Hide() end

--------------------------------------------------------------------------------
-- Postura
--------------------------------------------------------------------------------
-- Skin Azaath: moldura dourada na postura ativa, de aço nas outras (abas CF1/CF2 do conceito)
local function AzaathTabTex(name)
    return Azaath.media.path .. "Azaath\\" .. name
end
-- Skin Black Desert: losangos pequenos em zigue-zague acima dos direcionais;
-- a postura ativa ganha o aro dourado (parado)
local BDO_SR = 18 -- meia-diagonal do losango da postura
local BDO_SR_SPLIT = 21 -- Opção 2: losangos um pouco maiores, lado a lado
local SPLIT_STANCE_SIZE, SPLIT_STANCE_GAP = 36, 6 -- Opção 2 fora da skin BDO
-- Losangos da postura: Opção 1 (BDO) e Opção 2 (split), em qualquer skin; a Reforged tem as abas dela
local function IsBDOStance()
    if Azaath.IsAzaath and Azaath.IsAzaath() then return false end
    local ab = Azaath.db and Azaath.db.actionbars
    local l = ab and ab.layout
    return (l == "bdo" or l == "split") and Azaath.BDO_BAR ~= nil and Azaath.BDOSkinButton ~= nil
end

local function UpdateAzaathRing(b)
    if b.azaathRing then b.azaathRing:SetTexture(AzaathTabTex(b:GetChecked() and "TabGold" or "TabSteel")) end
    local t = b.bdo
    if t then
        if b:GetChecked() then
            t.proc:SetAlpha(0.85)
            t.proc:Show()
        else
            t.proc:Hide()
        end
    end
end

local function UpdateStanceButton(b)
    local texture, isActive, isCastable = Azaath.API.ShapeshiftFormInfo(b.index)
    if not texture then
        b.icon:Hide()
        b.cooldown:Hide()
        b:SetChecked(false)
        UpdateAzaathRing(b)
        return
    end

    b.icon:SetTexture(texture)
    b.icon:Show()
    if isCastable then
        b.icon:SetVertexColor(1, 1, 1)
    else
        b.icon:SetVertexColor(0.4, 0.4, 0.4)
    end
    local shouldCheck = false
    if not Azaath.IsSecret(isActive) then
        shouldCheck = (isActive and true or false)
    end
    if b:GetChecked() ~= shouldCheck then
        b:SetChecked(shouldCheck)
    end
    UpdateAzaathRing(b)

    local start, duration, enable, modRate = GetShapeshiftFormCooldown(b.index)
    local isSecret = Azaath.AnySecret(start, duration)

    if not isSecret then
        local enabled = (enable == nil) or Azaath.IsOn(enable)
        local active = enabled and start and duration and start > 0 and duration > 0
        local rem = active and ((start + duration) - GetTime()) or 0

        if active and rem > 0.05 then
            b.cooldown:Show()
            pcall(b.cooldown.SetCooldown, b.cooldown, start, duration)
            if duration > 1.5 then
                b.cdExpiration = start + duration
                if b.cdOverlay then b.cdOverlay:Show() end
                if b.cdText then
                    local fmt = Azaath.FormatCooldown
                    b.cdText:SetText(fmt and fmt(rem) or math.ceil(rem))
                    b.cdText:Show()
                end
            else
                b.cdExpiration = nil
                if b.cdOverlay then b.cdOverlay:Hide() end
                if b.cdText then b.cdText:Hide() end
            end
        else
            b.cooldown:Hide()
            b.cdExpiration = nil
            if b.cdOverlay then b.cdOverlay:Hide() end
            if b.cdText then b.cdText:Hide() end
        end
    else
        b.cdExpiration = nil
        if b.cdOverlay then b.cdOverlay:Hide() end
        if b.cdText then b.cdText:Hide() end
        b.cooldown:Show()
        local ok = false
        if modRate ~= nil then
            ok = pcall(b.cooldown.SetCooldown, b.cooldown, start, duration, modRate)
        end
        if not ok then
            pcall(b.cooldown.SetCooldown, b.cooldown, start, duration)
        end
    end
end

local function UpdateAllStance()
    for i = 1, #stanceButtons do
        UpdateStanceButton(stanceButtons[i])
    end
end

local function UpdateStanceHotkeys()
    local show = Azaath.db.actionbars.showHotkeys
    local short = Azaath.ShortKey or function(k) return k or "" end
    for i, b in ipairs(stanceButtons) do
        b.hotkey:SetText(show and short(GetBindingKey("SHAPESHIFTBUTTON" .. i)) or "")
    end
end

-- Protegido: só roda fora de combate (via RequestStanceLayout).
local function LayoutStanceBar()
    layoutPending = false
    if not stanceBar then return end
    local db = M.db.stance
    local n = GetNumShapeshiftForms() or 0
    local showCount = (M.editing and n == 0) and 4 or n

    for i, b in ipairs(stanceButtons) do
        if i <= showCount then
            b:Show()
            if M.editing and i > n then
                b.icon:SetTexture("Interface\\Icons\\Ability_Warrior_DefensiveStance")
                b.icon:SetDesaturated(true)
                b.icon:Show()
            end
        else
            b:Hide()
        end
    end

    if showCount > 0 then
        local bs, sp = db.buttonSize, db.spacing
        local A = Azaath.AZAATH
        if Azaath.IsAzaath and Azaath.IsAzaath() and A then
            local t1, t2 = A.tabs[1], A.tabs[2]
            bs, sp = t1.w, t2.x - t1.x - t1.w
        end
        if IsBDOStance() then
            local d = BDO_SR + Azaath.BDO_BAR.wgap
            if Azaath.IsSplitLayout(M.db.layout) then
                stanceBar:SetWidth((showCount - 1) * (2 * BDO_SR_SPLIT + 10) + 2 * BDO_SR_SPLIT)
            else
                stanceBar:SetWidth((showCount - 1) * d + 2 * BDO_SR)
            end
        else
            stanceBar:SetWidth(showCount * bs + (showCount - 1) * sp)
        end
        if M.editing then
            UnregisterStateDriver(stanceBar, "visibility")
            stanceBar:Show()
        else
            RegisterStateDriver(stanceBar, "visibility", STANCE_VISIBILITY)
        end
    else
        UnregisterStateDriver(stanceBar, "visibility")
        stanceBar:Hide()
    end
    UpdateAllStance()
end

local function RequestStanceLayout()
    if layoutPending then return end
    layoutPending = true
    Azaath:RunOutOfCombat(LayoutStanceBar)
end

local function Stance_OnEnter(self)
    if not GetShapeshiftFormInfo(self.index) then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:SetShapeshift(self.index)
end

local function CreateStanceBar(anchor)
    local db = M.db.stance
    local size, spacing = db.buttonSize, db.spacing

    stanceBar = CreateFrame("Frame", "AzaathUIStanceBar", Azaath.root, "SecureHandlerStateTemplate")
    stanceBar:SetFrameStrata("MEDIUM")
    stanceBar:SetFrameLevel(10)
    stanceBar:SetHeight(size)
    stanceBar:SetWidth(size)
    if anchor then
        stanceBar:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, GAP)
    else
        stanceBar:SetPoint("BOTTOMRIGHT", Azaath.root, "BOTTOM", -4, 14)
    end

    for i = 1, NUM_STANCE do
        -- cliente moderno: StanceButtonN · 3.3.5: ShapeshiftButtonN
        local blizz = _G["StanceButton" .. i] or _G["ShapeshiftButton" .. i]
        local name = "AzaathUIStanceButton" .. i
        local b = CreateFrame("CheckButton", name, stanceBar, "SecureActionButtonTemplate")
        b:SetWidth(size)
        b:SetHeight(size)
        b:SetFrameLevel(stanceBar:GetFrameLevel() + 2)
        b:SetPoint("LEFT", stanceBar, "LEFT", (i - 1) * (size + spacing), 0)
        b:RegisterForClicks("AnyDown", "AnyUp")
        b:EnableMouse(true)
        b:SetAttribute("useOnKeyDown", false)
        if blizz then
            b:SetAttribute("type", "click")
            b:SetAttribute("clickbutton", blizz)
        end
        b.index = i

        Azaath.SkinButton(b, name)
        local baseLevel = stanceBar:GetFrameLevel() + 2
        b:SetFrameLevel(baseLevel)
        if b.cooldown then b.cooldown:SetFrameLevel(baseLevel + 3) end
        if b.textLayer then b.textLayer:SetFrameLevel(baseLevel + 5) end

        b:SetScript("OnEnter", Stance_OnEnter)
        b:SetScript("OnLeave", HideTooltip)
        b:SetScript("PostClick", UpdateStanceButton) -- desfaz o auto-toggle do CheckButton
        b:Hide()

        stanceButtons[i] = b
    end

    -- A barra original da Blizzard: neutralizada e sem eventos para evitar erros de taint
    Azaath.DisableBlizzardFrame("ShapeshiftBarFrame")
    Azaath.DisableBlizzardFrame("StanceBarFrame")
    Azaath.DisableBlizzardFrame("StanceBar")
    if Azaath.SilenceBlizzardActionBars then
        pcall(Azaath.SilenceBlizzardActionBars)
    end

    LayoutStanceBar()
    UpdateStanceHotkeys()
end

-- Azaath: posturas no lugar das abas CF1/CF2, em cima do painel esquerdo
local function AzaathStanceStyle(b)
    if b.azaathRing then return end
    local inset = 4
    b:SetBackdropColor(0, 0, 0, 0.85)
    if b.SetBackdropBorderColor then b:SetBackdropBorderColor(0, 0, 0, 0) end
    for _, t in ipairs({ b.icon, b.cdOverlay, b.cooldown }) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
        t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
    end
    if b.hatch then b.hatch:SetAlpha(0) end
    local ck = b.GetCheckedTexture and b:GetCheckedTexture()
    if ck then ck:SetAlpha(0) end -- a moldura dourada marca a ativa
    local ring = b.textLayer:CreateTexture(nil, "ARTWORK")
    ring:SetAllPoints(b)
    b.azaathRing = ring
    -- atalho ("CF1") numa faixa escura no alto do ícone, como no conceito
    local band = b.textLayer:CreateTexture(nil, "BACKGROUND")
    band:SetTexture(Azaath.media.blank)
    band:SetPoint("TOPLEFT", b, "TOPLEFT", inset + 3, -(inset + 3))
    band:SetPoint("TOPRIGHT", b, "TOPRIGHT", -(inset + 3), -(inset + 3))
    band:SetHeight(15)
    if Azaath.Gradient then Azaath.Gradient(band, "VERTICAL", 0, 0, 0, 0.15, 0, 0, 0, 0.75) else band:SetVertexColor(0, 0, 0, 0.6) end
    b.hotkey:SetFont(Azaath.media.fontCardR or Azaath.media.font, 14, "")
    b.hotkey:SetTextColor(0.93, 0.90, 0.82)
    b.hotkey:SetShadowOffset(1, -1)
    b.hotkey:SetShadowColor(0, 0, 0, 1)
    b.hotkey:ClearAllPoints()
    b.hotkey:SetPoint("TOP", b, "TOP", 0, -(inset + 3))
    b.hotkey:SetJustifyH("CENTER")
    UpdateAzaathRing(b)
end

--------------------------------------------------------------------------------
-- Pet
--------------------------------------------------------------------------------
-- A Blizzard redefine a NormalTexture (moldura clássica) a cada PetActionBar_Update.
local function HidePetNormalTextures()
    for i = 1, NUM_PET do
        local b = _G["PetActionButton" .. i]
        if b then
            local nt = b:GetNormalTexture()
            if nt then nt:SetAlpha(0) end
            local nt2 = _G["PetActionButton" .. i .. "NormalTexture2"]
            if nt2 then nt2:SetAlpha(0) end
        end
    end
end

local function SkinPetButton(b, index, size, spacing)
    local name = b:GetName()

    b:SetParent(petBar)
    b:ClearAllPoints()
    b:SetPoint("LEFT", petBar, "LEFT", (index - 1) * (size + spacing), 0)
    b:SetWidth(size)
    b:SetHeight(size)

    local icon = _G[name .. "Icon"]
    if icon then
        Azaath.StyleButton(b, icon)
        local cd = _G[name .. "Cooldown"]
        if cd then
            cd:ClearAllPoints()
            cd:SetAllPoints(icon)
            if cd.SetDrawSwipe then
                pcall(cd.SetDrawSwipe, cd, true)
            end
            if cd.SetDrawEdge then
                pcall(cd.SetDrawEdge, cd, true)
            end
        end
    end

    local hotkey = _G[name .. "HotKey"]
    if hotkey then
        local c = Azaath.colors.cream
        hotkey:SetFont(Azaath.media.font, 9, "OUTLINE")
        hotkey:SetTextColor(c[1], c[2], c[3])
        hotkey:ClearAllPoints()
        hotkey:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -3)
        if not Azaath.db.actionbars.showHotkeys then hotkey:SetAlpha(0) end
    end

    -- Cantos de "autocast disponível" e brilho de autocast: reescala para o novo tamanho
    local autocastable = _G[name .. "AutoCastable"]
    if autocastable then
        autocastable:SetWidth(size * 1.95)
        autocastable:SetHeight(size * 1.95)
    end
    local shine = _G[name .. "Shine"]
    if shine then
        shine:ClearAllPoints()
        shine:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
        shine:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    end
end

-- Skin Black Desert no pet: os botões são da Blizzard, então o estado fica
-- numa tabela fraca (nada é gravado neles) e só métodos de widget são usados.
local BDO_PR = 18 -- meia-diagonal do losango do pet
local petBDO = setmetatable({}, { __mode = "k" })
local function BDOTexP(n) return Azaath.media.path .. "BDO\\Bar\\" .. n end

local function BDOPetSkin(b)
    local name, r = b:GetName(), BDO_PR
    local icon = _G[name .. "Icon"]
    if not icon then return end
    local t = petBDO[b]
    if not t then
        t = {}
        petBDO[b] = t
        t.bg = b:CreateTexture(nil, "BACKGROUND", nil, -8)
        t.bg:SetTexture(BDOTexP("WingBG"))
        t.bg:SetAllPoints(b)
        t.gloss = b:CreateTexture(nil, "OVERLAY", nil, 5)
        t.gloss:SetTexture(BDOTexP("WingGloss"))
        t.gloss:SetAllPoints(b)
        t.frame = b:CreateTexture(nil, "OVERLAY", nil, 6)
        t.frame:SetTexture(BDOTexP("WingFrame"))
        t.frame:SetAllPoints(b)
        if b.CreateMaskTexture and icon.AddMaskTexture and Azaath.BDOIconLayers then
            local m = Azaath.BDOIconLayers(b, icon)
            for _, tex in ipairs({ b:GetHighlightTexture(), b:GetPushedTexture(),
                b.GetCheckedTexture and b:GetCheckedTexture() or nil }) do
                if tex and tex.AddMaskTexture then tex:AddMaskTexture(m) end
            end
        end
    end
    -- some a arte Azaath que o StyleButton reaplica
    b:SetBackdropColor(0, 0, 0, 0)
    if b.SetBackdropBorderColor then b:SetBackdropBorderColor(0, 0, 0, 0) end
    if Azaath.HideSlotBorder then Azaath.HideSlotBorder(b) end
    if Azaath.BDOPlaceIcon then Azaath.BDOPlaceIcon(b, icon, r) else icon:ClearAllPoints(); icon:SetAllPoints(b) end
    for _, tex in ipairs({ b:GetHighlightTexture(), b:GetPushedTexture(), b.GetCheckedTexture and b:GetCheckedTexture() or nil }) do
        if tex then tex:ClearAllPoints(); tex:SetAllPoints(b) end
    end
    local cd = _G[name .. "Cooldown"]
    if cd then
        cd:ClearAllPoints()
        cd:SetAllPoints(b)
        if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, BDOTexP("Mask")) end
        if cd.SetSwipeColor then pcall(cd.SetSwipeColor, cd, 0.235, 0.133, 0.44, 0.72) end -- roxo da recarga
        if cd.SetDrawEdge then pcall(cd.SetDrawEdge, cd, false) end
    end
    local hotkey = _G[name .. "HotKey"]
    if hotkey then
        hotkey:SetFont(Azaath.media.fontBDOB or Azaath.media.font, 9, "OUTLINE")
        hotkey:SetTextColor(0.94, 0.91, 0.85)
        hotkey:SetShadowOffset(1, -1)
        hotkey:SetShadowColor(0, 0, 0, 1)
        hotkey:ClearAllPoints()
        hotkey:SetPoint("CENTER", b, "BOTTOM", 0, r * 0.42)
        hotkey:SetJustifyH("CENTER")
    end
    local shine = _G[name .. "Shine"]
    if shine then
        shine:ClearAllPoints()
        shine:SetPoint("TOPLEFT", b, "TOPLEFT", r * 0.45, -r * 0.45)
        shine:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -r * 0.45, r * 0.45)
    end
    local autocastable = _G[name .. "AutoCastable"]
    if autocastable then
        autocastable:SetWidth(2 * r * 1.45)
        autocastable:SetHeight(2 * r * 1.45)
    end
    local ins = math.floor(r * 0.3)
    b:SetHitRectInsets(ins, ins, ins, ins)
end

-- zigue-zague: posição do botão i (centro em relação ao LEFT da barra)
local function BDOPetPoint(i)
    local d = BDO_PR + (Azaath.BDO_BAR and Azaath.BDO_BAR.wgap or 2)
    return BDO_PR + (i - 1) * d, (i % 2 == 1) and d / 2 or -d / 2
end

local function CreatePetBar(anchor, isRightSide)
    local db = M.db.pet
    local size, spacing = db.buttonSize, db.spacing

    petBar = CreateFrame("Frame", "AzaathUIPetBar", Azaath.root, "SecureHandlerStateTemplate")
    petBar:SetFrameStrata("MEDIUM")
    petBar:SetFrameLevel(10)
    petBar:SetHeight(size)
    petBar:SetWidth(NUM_PET * size + (NUM_PET - 1) * spacing)
    if anchor then
        if isRightSide then
            petBar:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, GAP)
        else
            petBar:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, GAP)
        end
    else
        petBar:SetPoint("BOTTOMLEFT", Azaath.root, "BOTTOM", 4, 14)
    end

    petBar.previewSlots = {}
    for i = 1, NUM_PET do
        local b = _G["PetActionButton" .. i]
        if b then SkinPetButton(b, i, size, spacing) end
        local slot = CreateFrame("Frame", nil, petBar)
        slot:SetWidth(size)
        slot:SetHeight(size)
        slot:SetPoint("LEFT", petBar, "LEFT", (i - 1) * (size + spacing), 0)
        Azaath.SetBackdrop(slot, {
            bgFile = Azaath.media.blank, edgeFile = Azaath.media.blank, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        slot:SetBackdropColor(0.05, 0.06, 0.08, 0.80)
        slot:SetBackdropBorderColor(Azaath.colors.slate[1], Azaath.colors.slate[2], Azaath.colors.slate[3], 0.55)
        local tex = slot:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", slot, "TOPLEFT", 2, -2)
        tex:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -2, 2)
        tex:SetTexture("Interface\\Icons\\Ability_Hunter_BeastCall")
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tex:SetDesaturated(true)
        tex:SetAlpha(0.45)
        slot:Hide()
        petBar.previewSlots[i] = slot
    end

    -- Oculta o frame original mas mantém eventos: ele atualiza os botões.
    Azaath.DisableBlizzardFrame("PetActionBarFrame", { keepEvents = true })
    Azaath.DisableBlizzardFrame("PetActionBar", { keepEvents = true }) -- nome no cliente moderno

    HidePetNormalTextures()
    if PetActionBar_Update then
        hooksecurefunc("PetActionBar_Update", HidePetNormalTextures)
    end

    RegisterStateDriver(petBar, "visibility", PET_VISIBILITY)
end

--------------------------------------------------------------------------------
-- Eventos (apenas postura; o pet é atualizado pela própria Blizzard)
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "UPDATE_SHAPESHIFT_FORMS" or event == "LEARNED_SPELL_IN_TAB"
        or event == "PLAYER_ENTERING_WORLD" then
        RequestStanceLayout()   -- Show/Hide protegido: adiado se em combate
        UpdateAllStance()       -- visual: pode rodar já
        UpdateStanceHotkeys()
    elseif event == "UPDATE_BINDINGS" then
        UpdateStanceHotkeys()
    else
        UpdateAllStance()
    end
end)

local STANCE_EVENTS = {
    "UPDATE_SHAPESHIFT_FORMS", "UPDATE_SHAPESHIFT_FORM", "UPDATE_SHAPESHIFT_USABLE",
    "UPDATE_SHAPESHIFT_COOLDOWN", "SPELL_UPDATE_COOLDOWN", "ACTIONBAR_UPDATE_COOLDOWN",
    "LEARNED_SPELL_IN_TAB", "PLAYER_ENTERING_WORLD", "UPDATE_BINDINGS",
}

local function StanceTick()
    local now = GetTime()
    for i = 1, #stanceButtons do
        local b = stanceButtons[i]
        local exp = b.cdExpiration
        if exp then
            local rem = exp - now
            if rem > 0 then
                if b.cdText then
                    local fmt = Azaath.FormatCooldown
                    b.cdText:SetText(fmt and fmt(rem) or math.ceil(rem))
                end
            else
                b.cdExpiration = nil
                if b.cdOverlay then b.cdOverlay:Hide() end
                if b.cdText then b.cdText:Hide() end
                UpdateStanceButton(b)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:OnInitialize()
    self.db = Azaath.db.actionbars
end

function M:Build()
    local ab = Azaath:GetModule("ActionBars")
    local stanceAnchor = ab and ab.topBar -- nil se ActionBars estiver desligado
    local isAz = (self.db and Azaath.IsSixCols(self.db.layout))
    local petAnchor = (isAz and ab and ab.mainBar) or stanceAnchor

    -- O ActionBars:ApplyLayout (no OnEnable dele) já chama o nosso ApplyLayout,
    -- que cria as barras. Criar de novo aqui deixava uma cópia órfã na tela,
    -- longe da caixa do Modo de Edição (que segue a última criada).
    if self.db.stance.enabled and not stanceBar then
        CreateStanceBar(stanceAnchor)
        for _, e in ipairs(STANCE_EVENTS) do
            Azaath.SafeRegister(events, e)
        end
        events:SetScript("OnUpdate", StanceTick)
    end
    if self.db.pet.enabled and not petBar then
        CreatePetBar(petAnchor, isAz)
    end
    self:ApplyLayout()
end

function M:ApplyLayout()
    if not Azaath.db.hideBlizzard.actionBars then return end
    Azaath:RunOutOfCombat(function()
        local ab = Azaath:GetModule("ActionBars")
        local stanceAnchor = ab and ab.topBar
        local isAz = (self.db and Azaath.IsSixCols(self.db.layout))
        local petAnchor = (isAz and ab and ab.mainBar) or stanceAnchor

        local sdb = self.db and self.db.stance
        if sdb then
            if sdb.enabled and not stanceBar then
                CreateStanceBar(stanceAnchor)
                for _, e in ipairs(STANCE_EVENTS) do
                    Azaath.SafeRegister(events, e)
                end
                events:SetScript("OnUpdate", StanceTick)
            end
            if stanceBar then
                if not sdb.enabled then
                    UnregisterStateDriver(stanceBar, "visibility")
                    stanceBar:Hide()
                else
                    local size = sdb.buttonSize or 28
                    local spacing = sdb.spacing or 3
                    stanceBar:SetScale((sdb.scale and sdb.scale > 0) and sdb.scale or 1)
                    local hud = Azaath.IsAzaath and Azaath.IsAzaath() and Azaath.GetAzaathFrame and Azaath.GetAzaathFrame()
                    local A = Azaath.AZAATH
                    if hud and A then
                        local t1, t2 = A.tabs[1], A.tabs[2]
                        size, spacing = t1.w, t2.x - t1.x - t1.w
                        stanceBar:SetScale(hud:GetScale())
                    end
                    local split = Azaath.IsSplitLayout(self.db.layout) and not (Azaath.IsAzaath and Azaath.IsAzaath()) and not IsBDOStance()
                    if split then size, spacing = SPLIT_STANCE_SIZE, SPLIT_STANCE_GAP end
                    local bdoSplit = Azaath.IsSplitLayout(self.db.layout) and IsBDOStance() -- Opção 2 na skin BDO: 2 losangos lado a lado, à esquerda
                    stanceBar:SetHeight(size)
                    stanceBar:ClearAllPoints()
                    if hud and A then
                        local t1 = A.tabs[1]
                        stanceBar:SetPoint("TOPLEFT", hud, "TOPLEFT", t1.x, -t1.y)
                        for _, b in ipairs(stanceButtons) do AzaathStanceStyle(b) end
                    elseif IsBDOStance() and stanceAnchor then
                        -- centralizada acima dos direcionais da barra 1
                        local d = BDO_SR + Azaath.BDO_BAR.wgap
                        if bdoSplit then
                            stanceBar:SetHeight(2 * BDO_SR_SPLIT)
                            stanceBar:SetPoint("BOTTOMLEFT", stanceAnchor, "TOPLEFT", sdb.offsetX or 0, GAP + (sdb.offsetY or 0))
                        else
                            stanceBar:SetHeight(2 * BDO_SR + d)
                            stanceBar:SetPoint("BOTTOM", stanceAnchor, "TOP", sdb.offsetX or 0, GAP + (sdb.offsetY or 0))
                        end
                    elseif stanceAnchor then
                        stanceBar:SetPoint("BOTTOMLEFT", stanceAnchor, "TOPLEFT", sdb.offsetX or 0, GAP + (sdb.offsetY or 0))
                    else
                        stanceBar:SetPoint("BOTTOMRIGHT", Azaath.root, "BOTTOM", -4 + (sdb.offsetX or 0), 14 + (sdb.offsetY or 0))
                    end
                    if not hud and Azaath.ClampToScreen then Azaath.ClampToScreen(stanceBar) end
                    local bdo = IsBDOStance() and stanceAnchor
                    local d = BDO_SR + (Azaath.BDO_BAR and Azaath.BDO_BAR.wgap or 2)
                    for i, b in ipairs(stanceButtons) do
                        b:ClearAllPoints()
                        if bdo then
                            local up = (i % 2 == 1)
                            local sr = bdoSplit and BDO_SR_SPLIT or BDO_SR
                            local dx = bdoSplit and (2 * sr + 10) or d
                            b:SetWidth(2 * sr)
                            b:SetHeight(2 * sr)
                            b:SetPoint("CENTER", stanceBar, "LEFT", sr + (i - 1) * dx, bdoSplit and 0 or (up and d / 2 or -d / 2))
                            Azaath.BDOSkinButton(b, true, sr)
                        else
                            b:SetWidth(size)
                            b:SetHeight(size)
                            b:SetPoint("LEFT", stanceBar, "LEFT", (i - 1) * (size + spacing), 0)
                        end
                    end
                    LayoutStanceBar()
                    UpdateStanceHotkeys()
                end
            end
        end

        local pdb = self.db and self.db.pet
        if pdb then
            if pdb.enabled and not petBar then
                CreatePetBar(petAnchor, isAz)
            end
            if petBar then
                if not pdb.enabled then
                    UnregisterStateDriver(petBar, "visibility")
                    petBar:Hide()
                else
                    local size = pdb.buttonSize or 28
                    local spacing = pdb.spacing or 3
                    local bdo = IsBDOStance() and petAnchor
                    petBar:SetScale((pdb.scale and pdb.scale > 0) and pdb.scale or 1)
                    petBar:ClearAllPoints()
                    if bdo then
                        -- acima do lado esquerdo dos direcionais (a postura fica no centro)
                        local d = BDO_PR + Azaath.BDO_BAR.wgap
                        petBar:SetHeight(2 * BDO_PR + d)
                        petBar:SetWidth((NUM_PET - 1) * d + 2 * BDO_PR)
                        petBar:SetPoint("BOTTOMRIGHT", petAnchor, "TOP", -60 + (pdb.offsetX or 0), GAP + (pdb.offsetY or 0))
                    else
                        petBar:SetHeight(size)
                        petBar:SetWidth(NUM_PET * size + (NUM_PET - 1) * spacing)
                    end
                    if bdo then
                        -- já ancorada acima
                    elseif petAnchor then
                        if isAz then
                            petBar:SetPoint("BOTTOMLEFT", petAnchor, "TOPLEFT", pdb.offsetX or 0, GAP + (pdb.offsetY or 0))
                        else
                            petBar:SetPoint("BOTTOMRIGHT", petAnchor, "TOPRIGHT", pdb.offsetX or 0, GAP + (pdb.offsetY or 0))
                        end
                    else
                        petBar:SetPoint("BOTTOMLEFT", Azaath.root, "BOTTOM", 4 + (pdb.offsetX or 0), 14 + (pdb.offsetY or 0))
                    end
                    if Azaath.ClampToScreen then Azaath.ClampToScreen(petBar) end
                    for i = 1, NUM_PET do
                        local b = _G["PetActionButton" .. i]
                        if b then
                            SkinPetButton(b, i, bdo and 2 * BDO_PR or size, spacing)
                            if bdo then
                                local x, y = BDOPetPoint(i)
                                b:ClearAllPoints()
                                b:SetPoint("CENTER", petBar, "LEFT", x, y)
                                BDOPetSkin(b)
                            end
                        end
                        local slot = petBar.previewSlots and petBar.previewSlots[i]
                        if slot then
                            slot:SetWidth(bdo and 2 * BDO_PR or size)
                            slot:SetHeight(bdo and 2 * BDO_PR or size)
                            slot:ClearAllPoints()
                            if bdo then
                                local x, y = BDOPetPoint(i)
                                slot:SetPoint("CENTER", petBar, "LEFT", x, y)
                            else
                                slot:SetPoint("LEFT", petBar, "LEFT", (i - 1) * (size + spacing), 0)
                            end
                            if self.editing and not (PetHasActionBar and PetHasActionBar()) then
                                slot:Show()
                            else
                                slot:Hide()
                            end
                        end
                    end
                    if self.editing then
                        UnregisterStateDriver(petBar, "visibility")
                        petBar:Show()
                    else
                        RegisterStateDriver(petBar, "visibility", PET_VISIBILITY)
                    end
                end
            end
        end
    end)
end

function M:SetEditing(editing)
    self.editing = editing and true or false
    self:ApplyLayout()
end

function M:OnEnable()
    -- Com as barras da Blizzard restauradas, as delas já estão visíveis.
    if not Azaath.db.hideBlizzard.actionBars then return end
    if not Azaath.DisableBlizzardFrame then return end
    -- Enfileirado depois do ActionBars (mesma fila), então ab.topBar já existe.
    Azaath:RunOutOfCombat(function() self:Build() end)
end
