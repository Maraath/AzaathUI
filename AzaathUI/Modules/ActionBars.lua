--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ActionBars.lua
    Barras de ação centralizadas, compactas, sem a arte clássica (grifos etc.).

    Por que botões PRÓPRIOS e não reaproveitar ActionButton1-12?
      * ActionButton_Update() da Blizzard chama self:Show()/Hide(). Se esse
        código rodar a partir de um hook de addon em combate, a execução está
        "tainted" e o jogo bloqueia (ADDON_ACTION_BLOCKED).
      * Aqui cada botão é um CheckButton com SecureActionButtonTemplate (o clique
        é 100% seguro) e TODO o visual é atualizado por código nosso que nunca
        chama métodos protegidos. Os botões ficam sempre visíveis (slots vazios
        aparecem escurecidos), então nada precisa ser mostrado/escondido em combate.

    Paginação (3.3.5a):
      * Barra principal: SecureHandlerStateTemplate + RegisterStateDriver("page").
        O snippet seguro repassa a página aos botões via control:ChildUpdate,
        que recalcula o atributo "action" — funciona em combate.
      * Posturas/formas (bonusbar:1-4), possessão/veículo (bonusbar:5 / vehicleui)
        e Shift+Roda (bar:2-6) seguem a mesma lógica da barra da Blizzard.
      * Barra 2 = slots 61-72 (MultiBarBottomLeft), barra 3 = slots 49-60
        (MultiBarBottomRight): os mesmos slots e keybinds da UI padrão.

    Keybinds: SetOverrideBindingClick reaproveita as teclas já configuradas em
    ACTIONBUTTONx / MULTIACTIONBAR1BUTTONx / MULTIACTIONBAR2BUTTONx (menu Teclas
    de Atalho do jogo continua valendo).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("ActionBars")
local API = Azaath.API

local _G = _G
local pairs, ipairs, select, format = pairs, ipairs, select, string.format
local HasAction, GetActionTexture, GetActionCount = HasAction, GetActionTexture, GetActionCount
local GetActionCooldown, IsUsableAction, IsActionInRange = GetActionCooldown, IsUsableAction, IsActionInRange
local ActionHasRange, IsCurrentAction, IsAutoRepeatAction = ActionHasRange, IsCurrentAction, IsAutoRepeatAction
local IsEquippedAction, IsConsumableAction, IsStackableAction = IsEquippedAction, IsConsumableAction, IsStackableAction

local NUM_BUTTONS = 12

-- Definição das barras: página fixa (ou driver de estado) e comando de keybind.
local BAR_DEFS = {
    {
        id = 1,
        binding = "ACTIONBUTTON%d",
        page = 1,
        pageDriver = "[vehicleui] 11; [bonusbar:5] 11; [bar:2] 2; [bar:3] 3; [bar:4] 4; [bar:5] 5; [bar:6] 6; "
                  .. "[bonusbar:1] 7; [bonusbar:2] 8; [bonusbar:3] 9; [bonusbar:4] 10; 1",
    },
    { id = 2, binding = "MULTIACTIONBAR1BUTTON%d", page = 6, visibility = "[vehicleui] hide; show" },
    { id = 3, binding = "MULTIACTIONBAR2BUTTON%d", page = 5, visibility = "[vehicleui] hide; show" },
}

-- Botões da Blizzard que ficam inúteis (e gastando CPU com eventos) quando
-- nossas barras assumem.
local BLIZZARD_BUTTON_PREFIXES = {
    "ActionButton", "BonusActionButton", "MultiBarBottomLeftButton", "MultiBarBottomRightButton",
}

local bars, buttons = {}, {}
local bindOwner -- frame dono das override bindings
local leaveButton, bagButton

--------------------------------------------------------------------------------
-- Utilitários
--------------------------------------------------------------------------------
local function ShortKey(key)
    if not key then return "" end
    key = key:upper()
    key = key:gsub("SHIFT%-", "S"):gsub("CTRL%-", "C"):gsub("ALT%-", "A")
    key = key:gsub("MOUSEWHEELUP", "WU"):gsub("MOUSEWHEELDOWN", "WD")
    key = key:gsub("BUTTON", "M"):gsub("NUMPAD", "N"):gsub("SPACE", "Sp")
    return key
end
Azaath.ShortKey = ShortKey

--------------------------------------------------------------------------------
-- Visual compartilhado (também usado pelas barras de postura/pet)
--------------------------------------------------------------------------------
local backdrop
local function GetBackdrop()
    if not backdrop then
        local blank = Azaath.media.blank
        backdrop = {
            bgFile = blank, edgeFile = blank, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        }
    end
    return backdrop
end
Azaath.GetButtonBackdrop = GetBackdrop

-- Espaço de habilidade estilo Azaath: fundo quase preto com degradê e
-- hachura diagonal (Media/ActionBar/Slot.tga). A moldura é uma textura à parte
-- (Media/ActionBar/SlotBorder.tga): filete claro irregular, pintado à mão.
local slotBackdrop
local function GetSlotBackdrop()
    if not slotBackdrop then
        slotBackdrop = {
            bgFile = Azaath.media.path .. "ActionBar\\Slot",
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        }
    end
    return slotBackdrop
end

-- Moldura por botão numa tabela local (fraca), sem gravar campos no botão:
-- seguro também para botões da Blizzard e não duplica se reaplicado.
local slotBorders = setmetatable({}, { __mode = "k" })
local function GetSlotBorder(b)
    local tex = slotBorders[b]
    if not tex then
        tex = b:CreateTexture(nil, "OVERLAY", nil, 6)
        tex:SetTexture(Azaath.media.path .. "ActionBar\\SlotBorder")
        tex:SetPoint("TOPLEFT", b, "TOPLEFT", -1, 1)
        tex:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, -1)
        slotBorders[b] = tex
    end
    return tex
end

-- Some com a moldura Azaath de um botão (skin Black Desert: pet, StancePetBars.lua)
function Azaath.HideSlotBorder(b)
    GetSlotBorder(b):SetAlpha(0)
end

-- Cor da moldura (branca = arte original; verde = item equipado)
local function SetSlotBorderColor(b, r, g, bl)
    GetSlotBorder(b):SetVertexColor(r, g, bl)
end

local function FlatStateTexture(tex, icon, r, g, b, alpha, blend)
    if not tex then return end
    tex:ClearAllPoints()
    tex:SetAllPoints(icon)
    tex:SetVertexColor(r, g, b)
    tex:SetAlpha(alpha)
    if blend then tex:SetBlendMode(blend) end
end

-- Aplica fundo, borda e texturas de estado planas a QUALQUER botão (nosso ou
-- da Blizzard). Só chama métodos de widget: não grava campos na tabela do
-- botão, então é seguro para botões da Blizzard (sem taint).
function Azaath.StyleButton(b, icon)
    local c, blank = Azaath.colors, Azaath.media.blank
    Azaath.SetBackdrop(b, GetSlotBackdrop())
    b:SetBackdropColor(1, 1, 1, 1)
    SetSlotBorderColor(b, 1, 1, 1)

    icon:ClearAllPoints()
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- corta a moldura embutida dos ícones

    b:SetHighlightTexture(blank)
    FlatStateTexture(b:GetHighlightTexture(), icon, 1, 1, 1, 0.15, "ADD")
    b:SetPushedTexture(blank)
    FlatStateTexture(b:GetPushedTexture(), icon, 0, 0, 0, 0.35)
    if b.SetCheckedTexture then
        b:SetCheckedTexture(blank)
        FlatStateTexture(b:GetCheckedTexture(), icon, c.accent[1], c.accent[2], c.accent[3], 0.35, "ADD")
    end
end

local KEYBOX_H = 18 -- altura da caixinha de tecla (estilo Azaath)

-- Caixinha preta arredondada com filete cinza (Media/ActionBar/KeyBox.tga) em
-- 3 fatias: as pontas mantêm os cantos redondos e só o meio estica.
function Azaath.CreateKeyBox(parent)
    local tex = Azaath.media.path .. "ActionBar\\KeyBox"
    local box = CreateFrame("Frame", nil, parent)
    box:SetHeight(KEYBOX_H)
    box:SetWidth(KEYBOX_H)
    local cap = KEYBOX_H / 2
    local left = box:CreateTexture(nil, "BACKGROUND")
    left:SetTexture(tex)
    left:SetTexCoord(0, 0.5, 0, 1)
    left:SetWidth(cap)
    left:SetPoint("TOPLEFT")
    left:SetPoint("BOTTOMLEFT")
    local right = box:CreateTexture(nil, "BACKGROUND")
    right:SetTexture(tex)
    right:SetTexCoord(0.5, 1, 0, 1)
    right:SetWidth(cap)
    right:SetPoint("TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT")
    local mid = box:CreateTexture(nil, "BACKGROUND")
    mid:SetTexture(tex)
    mid:SetTexCoord(0.49, 0.51, 0, 1)
    mid:SetPoint("TOPLEFT", left, "TOPRIGHT")
    mid:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
    box.mid = mid
    box.left, box.right = left, right
    return box
end

-- Define o texto de atalho; com caixinha (estilo Azaath), ajusta a largura dela
-- ao texto e a esconde quando não há tecla.
function Azaath.SetHotkeyText(b, text)
    text = text or ""
    b.hotkey:SetText(text)
    local box = b.keyBox
    if not box then return end
    if text == "" then
        box:Hide()
    else
        local w = math.max(box.minW or KEYBOX_H, math.floor(b.hotkey:GetStringWidth() + (box.pad or 10) + 0.5))
        box:SetWidth(w)
        if box.mid then
            if w > (box.capsW or KEYBOX_H) then box.mid:Show() else box.mid:Hide() end
        end
        box:Show()
    end
end

-- Cria ícone, cooldown, atalho e contador para um botão NOVO (nosso).
-- Chame depois de definir o tamanho do botão.
-- opts.keyBox = true: tecla numa caixinha escura ABAIXO do botão (estilo Azaath).
function Azaath.SkinButton(b, name, opts)
    local c = Azaath.colors
    local small = (b:GetWidth() or 34) < 30

    -- 1. Ícone base (layer ARTWORK de b)
    local icon = b:CreateTexture(name .. "Icon", "ARTWORK")
    b.icon = icon
    Azaath.StyleButton(b, icon)

    -- 2. Overlay de pergaminho Azaath para habilidades em recarga (fica atrás da espiral)
    local cdOverlay = b:CreateTexture(name .. "CDOverlay", "OVERLAY")
    cdOverlay:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    cdOverlay:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    cdOverlay:SetTexture(Azaath.media.blank)
    cdOverlay:SetVertexColor(0.76, 0.65, 0.50, 0.85) -- #c4a982 / pergaminho Azaath
    cdOverlay:Hide()
    b.cdOverlay = cdOverlay

    -- 2b. Hachura diagonal escura no canto inferior esquerdo, por cima do
    -- ícone e do pergaminho (como nos espaços do Azaath)
    local hatch = b:CreateTexture(nil, "OVERLAY", nil, 7)
    hatch:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    hatch:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    hatch:SetTexture(Azaath.media.path .. "ActionBar\\Hatch")
    hatch:Hide()
    b.hatch = hatch

    -- 3. CooldownFrame da Blizzard (nível b + 3, roda por cima do pergaminho)
    local cd = CreateFrame("Cooldown", name .. "Cooldown", b, "CooldownFrameTemplate")
    cd:ClearAllPoints()
    cd:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    cd:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    cd:SetFrameLevel(b:GetFrameLevel() + 3)
    cd:Hide()
    if cd.SetDrawSwipe then
        pcall(cd.SetDrawSwipe, cd, true)
    end
    if cd.SetDrawEdge then
        pcall(cd.SetDrawEdge, cd, true)
    end
    if cd.SetHideCountdownNumbers then
        pcall(cd.SetHideCountdownNumbers, cd, true)
    end
    b.cooldown = cd

    -- 4. Camada de texto superior (nível b + 5, acima da espiral para nitidez total)
    local textLayer = CreateFrame("Frame", nil, b)
    textLayer:ClearAllPoints()
    textLayer:SetAllPoints(b)
    textLayer:SetFrameLevel(b:GetFrameLevel() + 5)
    textLayer:EnableMouse(false)
    b.textLayer = textLayer

    -- Texto numérico da recarga no centro (dígitos escuros e nítidos como o "9" da foto)
    local cdText = textLayer:CreateFontString(nil, "OVERLAY")
    local cdFontSize = small and 12 or 16
    cdText:SetFont(Azaath.media.font, cdFontSize, "OUTLINE")
    cdText:SetTextColor(0.12, 0.10, 0.08, 1)
    cdText:SetShadowOffset(1, -1)
    cdText:SetShadowColor(0.9, 0.85, 0.75, 0.6)
    cdText:SetPoint("CENTER", b, "CENTER", 0, 0)
    cdText:Hide()
    b.cdText = cdText
    b.cdFontSize = cdFontSize

    -- Recarga secreta (combate nos clientes novos): quem conta é o próprio
    -- frame nativo; ao terminar ele avisa e o pergaminho sai.
    cd:SetScript("OnCooldownDone", function()
        if b.cdSecret then
            b.cdSecret = nil
            if b.cdOverlay then b.cdOverlay:Hide() end
            if b.cdBinding then pcall(b.cdBinding.SetEnabled, b.cdBinding, false) end
            if b.cdText then b.cdText:Hide() end
        end
    end)

    local hotkey
    if opts and opts.keyBox then
        local box = Azaath.CreateKeyBox(b)
        box:SetPoint("TOP", b, "BOTTOM", 0, -3)
        hotkey = box:CreateFontString(nil, "OVERLAY")
        hotkey:SetFont(Azaath.media.font, 11, "OUTLINE")
        hotkey:SetTextColor(1, 1, 1)
        hotkey:SetPoint("CENTER", box, "CENTER", 0, 0)
        box:Hide()
        b.keyBox = box
    else
        hotkey = textLayer:CreateFontString(nil, "OVERLAY")
        hotkey:SetFont(Azaath.media.font, small and 10 or 11, "OUTLINE")
        hotkey:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
        hotkey:SetPoint("TOPRIGHT", b, "TOPRIGHT", -2, -3)
        hotkey:SetJustifyH("RIGHT")
    end
    b.hotkey = hotkey

    local count = textLayer:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local okC = pcall(count.SetFont, count, Azaath.media.fontTitleB, small and 10 or 12, "OUTLINE")
    if not okC or not count:GetFont() then
        count:SetFont("Fonts\\ARIALN.TTF", small and 10 or 12, "OUTLINE")
    end
    count:SetTextColor(1, 1, 1)
    count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 3)
    b.count = count
end

--------------------------------------------------------------------------------
-- Atualização visual de um botão (nunca chama métodos protegidos)
--------------------------------------------------------------------------------
local function UpdateBorder(b)
    if b.action and IsEquippedAction(b.action) then
        SetSlotBorderColor(b, 0.45, 1, 0.45)
    else
        SetSlotBorderColor(b, 1, 1, 1)
    end
end

local function UpdateUsable(b)
    local a = b.action
    if not (a and HasAction(a)) then return end
    local icon = b.icon
    if not icon then return end
    if b.outOfRange then
        icon:SetVertexColor(0.85, 0.25, 0.20)
        return
    end

    local isUsable, notEnoughMana = IsUsableAction(a)
    local usable = false
    local noMana = false

    if not Azaath.IsSecret(isUsable) then
        usable = (isUsable and true or false)
    else
        usable = true
    end

    if not Azaath.IsSecret(notEnoughMana) then
        noMana = (notEnoughMana and true or false)
    end

    if usable then
        icon:SetVertexColor(1, 1, 1)
    elseif noMana then
        -- Recurso insuficiente (mana/fúria/energia): escurecida com tom azul
        icon:SetVertexColor(0.5, 0.5, 0.85)
    else
        -- Não utilizável (condição não atendida, ex: Sobrepujar sem esquiva, postura errada): apagada
        icon:SetVertexColor(0.4, 0.4, 0.4)
    end
end

local function FormatCooldown(rem)
    if not rem or rem <= 0 then return "" end
    if rem >= 3600 then
        return format("%dh", math.ceil(rem / 3600))
    elseif rem >= 60 then
        local m = math.floor(rem / 60)
        local s = math.floor(rem % 60)
        return format("%d:%02d", m, s)
    else
        return format("%d", math.ceil(rem))
    end
end
Azaath.FormatCooldown = FormatCooldown

--------------------------------------------------------------------------------
-- Resolução robusta de recargas (100% compatível com a API do Azaath / 3.3.5 / 12.x)
--------------------------------------------------------------------------------
local spellToBookIndex = {}
local spellNameCache = {}
local activeCooldowns = {}

-- Tabela de recargas conhecidas para habilidades de Guerreiro e gerais
-- Garante exibição instantânea do pergaminho e do contador numérico Azaath
local KNOWN_COOLDOWNS = {
    -- Guerreiro / Warrior (IDs)
    [100] = 15,    -- Investida / Charge (Posto 1)
    [6178] = 15,   -- Investida / Charge (Posto 2)
    [11578] = 15,  -- Investida / Charge (Posto 3)
    [2687] = 60,   -- Ira Sangrenta / Bloodrage
    [26297] = 180, -- Fúria Berserker / Berserking (Racial Troll)
    [20572] = 120, -- Fúria Sangrenta / Blood Fury (Racial Orc)
    [20594] = 120, -- Forma de Pedra / Stoneform (Racial Anão)
    [59547] = 180, -- Dádiva dos Naaru / Gift of the Naaru (Racial Draenei)
    [7384] = 5,    -- Golpe Desarmante / Sobrepujar / Overpower (Posto 1)
    [7887] = 5,    -- (Posto 2)
    [11584] = 5,   -- (Posto 3)
    [11585] = 5,   -- (Posto 4)
    [6343] = 6,    -- Trovão / Thunder Clap (Posto 1)
    [8198] = 6,    -- (Posto 2)
    [8204] = 6,    -- (Posto 3)
    [8205] = 6,    -- (Posto 4)
    [11580] = 6,   -- (Posto 5)
    [11581] = 6,   -- (Posto 6)
    [25264] = 6,   -- (Posto 7)
    [355] = 8,     -- Provocar / Taunt
    [23922] = 6,   -- Escudada / Shield Slam (Posto 1)
    [23923] = 6,   -- (Posto 2)
    [23924] = 6,   -- (Posto 3)
    [23925] = 6,   -- (Posto 4)
    [25258] = 6,   -- (Posto 5)
    [30356] = 6,   -- (Posto 6)
    [2565] = 40,   -- Bloqueio com Escudo / Shield Block
    [676] = 60,    -- Desarmar / Disarm
    [20230] = 300, -- Retaliação / Retaliation
    [871] = 300,   -- Muralha de Escudos / Shield Wall
    [1719] = 300,  -- Temeridade / Recklessness
    [6552] = 10,   -- Murro / Pummel (Posto 1)
    [6554] = 10,   -- (Posto 2)
    [20252] = 30,  -- Interceptar / Intercept (Posto 1)
    [20616] = 30,  -- (Posto 2)
    [20617] = 30,  -- (Posto 3)
    [25272] = 30,  -- (Posto 4)
    [25275] = 30,  -- (Posto 5)
    [5246] = 180,  -- Brado Intimidador / Intimidating Shout
    [1161] = 600,  -- Brado Desafiador / Challenging Shout
    [694] = 120,   -- Golpe Provocador / Mocking Blow (Posto 1)
    [7400] = 120,  -- (Posto 2)
    [7402] = 120,  -- (Posto 3)
    [20559] = 120, -- (Posto 4)
    [20560] = 120, -- (Posto 5)
    [25266] = 120, -- (Posto 6)
    [12328] = 30,  -- Golpes Amplos / Sweeping Strikes
    [12292] = 180, -- Desejo de Morte / Death Wish
    [12975] = 180, -- Último Reduto / Last Stand
    [12809] = 45,  -- Golpe Concussivo / Concussion Blow
    [55694] = 180, -- Regeneração Enfurecida / Enraged Regeneration
    [57755] = 60,  -- Arremesso Heroico / Heroic Throw
    [64382] = 300, -- Arremesso Estilhaçante / Shattering Throw
    [23920] = 10,  -- Reflexão de Feitiço / Spell Reflection
    [1680] = 10,   -- Redemoinho / Whirlwind
    [12294] = 6,   -- Golpe Mortal / Mortal Strike (Posto 1)
    [21551] = 6,   -- (Posto 2)
    [21552] = 6,   -- (Posto 3)
    [21553] = 6,   -- (Posto 4)
    [25248] = 6,   -- (Posto 5)
    [30330] = 6,   -- (Posto 6)
    [47485] = 6,   -- (Posto 7)
    [47486] = 6,   -- (Posto 8)
    [23881] = 4,   -- Sede de Sangue / Bloodthirst (Posto 1)
    [23892] = 4,   -- (Posto 2)
    [23893] = 4,   -- (Posto 3)
    [23894] = 4,   -- (Posto 4)
    [25251] = 4,   -- (Posto 5)
    [30335] = 4,   -- (Posto 6)
    [47466] = 4,   -- (Posto 7)
    [47467] = 4,   -- (Posto 8)

    -- Nomes em português e inglês (fallback de contingência)
    ["Investida"] = 15,
    ["Charge"] = 15,
    ["Ira Sangrenta"] = 60,
    ["Bloodrage"] = 60,
    ["Fúria Berserker"] = 180,
    ["Berserking"] = 180,
    ["Fúria Sangrenta"] = 120,
    ["Blood Fury"] = 120,
    ["Golpe Desarmante"] = 5,
    ["Sobrepujar"] = 5,
    ["Overpower"] = 5,
    ["Trovão"] = 6,
    ["Thunder Clap"] = 6,
    ["Provocar"] = 8,
    ["Taunt"] = 8,
    ["Escudada"] = 6,
    ["Shield Slam"] = 6,
    ["Bloqueio com Escudo"] = 40,
    ["Shield Block"] = 40,
    ["Desarmar"] = 60,
    ["Disarm"] = 60,
    ["Retaliação"] = 300,
    ["Retaliation"] = 300,
    ["Muralha de Escudos"] = 300,
    ["Shield Wall"] = 300,
    ["Temeridade"] = 300,
    ["Recklessness"] = 300,
    ["Murro"] = 10,
    ["Pummel"] = 10,
    ["Interceptar"] = 30,
    ["Intercept"] = 30,
    ["Brado Intimidador"] = 180,
    ["Intimidating Shout"] = 180,
    ["Brado Desafiador"] = 600,
    ["Challenging Shout"] = 600,
    ["Golpe Provocador"] = 120,
    ["Mocking Blow"] = 120,
    ["Golpes Amplos"] = 30,
    ["Sweeping Strikes"] = 30,
    ["Desejo de Morte"] = 180,
    ["Death Wish"] = 180,
    ["Último Reduto"] = 180,
    ["Last Stand"] = 180,
    ["Golpe Concussivo"] = 45,
    ["Concussion Blow"] = 45,
    ["Regeneração Enfurecida"] = 180,
    ["Enraged Regeneration"] = 180,
    ["Arremesso Heroico"] = 60,
    ["Heroic Throw"] = 60,
    ["Arremesso Estilhaçante"] = 300,
    ["Shattering Throw"] = 300,
    ["Reflexão de Feitiço"] = 10,
    ["Spell Reflection"] = 10,
    ["Redemoinho"] = 10,
    ["Whirlwind"] = 10,
    ["Golpe Mortal"] = 6,
    ["Mortal Strike"] = 6,
    ["Sede de Sangue"] = 4,
    ["Bloodthirst"] = 4,
}

local function CleanSpellName(name)
    if not name or type(name) ~= "string" then return nil end
    local clean = name:match("^([^(]+)")
    if clean then
        clean = clean:gsub("%s+$", "")
        return clean
    end
    return name
end

local function UpdateSpellBookCache()
    wipe(spellToBookIndex)
    local numTabs = (API.SpellTabCount and API.SpellTabCount()) or (GetNumSpellTabs and GetNumSpellTabs()) or 0
    for tab = 1, numTabs do
        local _, offset, num
        if API.SpellTabInfo then
            _, offset, num = API.SpellTabInfo(tab)
        elseif GetSpellTabInfo then
            _, _, offset, num = GetSpellTabInfo(tab)
        end
        local first = (offset or 0) + 1
        local last = (offset or 0) + (num or 0)
        for i = first, last do
            local name
            if API.SpellName then
                name = API.SpellName(i, "spell")
            elseif GetSpellName then
                name = GetSpellName(i, "spell")
            elseif GetSpellBookItemName then
                name = GetSpellBookItemName(i, "spell")
            end
            if name and name ~= "" and not Azaath.IsSecret(name) then
                spellToBookIndex[name] = i
                local clean = CleanSpellName(name)
                if clean and clean ~= name then
                    spellToBookIndex[clean] = i
                end
            end
            local link = (API.SpellLink and API.SpellLink(i, "spell")) or (GetSpellLink and GetSpellLink(i, "spell"))
            local id = link and tonumber(link:match("spell:(%d+)"))
            if id and not Azaath.IsSecret(id) then
                spellToBookIndex[id] = i
            end
        end
    end
end
Azaath.UpdateSpellBookCache = UpdateSpellBookCache

local function GetSpellNameByID(spellID)
    if not spellID then return nil end
    if spellNameCache[spellID] then return spellNameCache[spellID] end
    local name
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, spellID)
        if ok and n and not Azaath.IsSecret(n) and type(n) == "string" and n ~= "" then
            name = n
        end
    end
    if not name and C_Spell and C_Spell.GetSpellInfo then
        local ok, info = pcall(C_Spell.GetSpellInfo, spellID)
        if ok and info then
            if type(info) == "table" and info.name and not Azaath.IsSecret(info.name) then
                name = info.name
            elseif type(info) == "string" and not Azaath.IsSecret(info) then
                name = info
            end
        end
    end
    if not name and GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, spellID)
        if ok and n and not Azaath.IsSecret(n) and type(n) == "string" then
            name = n
        end
    end
    if name then
        spellNameCache[spellID] = name
    end
    return name
end

-- Recarga real de um feitiço consultando o jogo (nil se não houver recarga
-- maior que a global ou se o valor for secreto)
local function RealSpellCooldown(id, sName, cleanName)
    -- 2. Consulta C_Spell.GetSpellCooldown
    if C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, id)
        if ok and type(info) == "table" and not Azaath.AnySecret(info.startTime, info.duration) then
            local s = info.startTime or 0
            local d = info.duration or 0
            if s > 0 and d > 1.5 then
                return s, d, info.isEnabled
            end
        end
    end

    -- 3. Consulta GetSpellCooldown por ID
    if GetSpellCooldown then
        local ok, s, d, e = pcall(GetSpellCooldown, id)
        if ok and not Azaath.AnySecret(s, d) and s and d and s > 0 and d > 1.5 then
            return s, d, (e == nil) or Azaath.IsOn(e)
        end
    end

    -- 4. Consulta GetSpellCooldown por nome
    if sName and GetSpellCooldown then
        local ok, s, d, e = pcall(GetSpellCooldown, sName)
        if ok and not Azaath.AnySecret(s, d) and s and d and s > 0 and d > 1.5 then
            return s, d, (e == nil) or Azaath.IsOn(e)
        end
    end

    -- 5. Consulta Livro de Feitiços
    local bookIndex = spellToBookIndex[id]
        or (sName and spellToBookIndex[sName])
        or (cleanName and spellToBookIndex[cleanName])
    if bookIndex and API and API.SpellCooldown then
        local ok, s, d, e = pcall(API.SpellCooldown, bookIndex, "spell")
        if ok and not Azaath.AnySecret(s, d) and s and d and s > 0 and d > 1.5 then
            return s, d, (e == nil) or Azaath.IsOn(e)
        end
    end
end

local function GetButtonCooldown(b)
    local a = b.action
    if not (a and HasAction(a)) then return 0, 0, false end

    if GetActionInfo then
        local actionType, id = GetActionInfo(a)
        if actionType == "spell" and id then
            local sName = GetSpellNameByID(id)
            local cleanName = CleanSpellName(sName)

            -- O valor real do jogo vem antes do rastreador: o rastreador guarda
            -- um palpite no momento do lançamento (ex.: Fusão Sombria registra
            -- a base de 10 s, mas em combate o jogo aplica 2 min logo depois).
            local s, d, e = RealSpellCooldown(id, sName, cleanName)
            if s then return s, d, e end

            -- Valor secreto (combate): o palpite do rastreador pode estar errado
            -- (Fusão Sombria: base 10 s, real 2 min). Repassa os valores
            -- secretos ao frame nativo e só avisa se havia recarga registrada.
            local as, ad, ae, am = GetActionCooldown(a)
            if Azaath.AnySecret(as, ad) then
                local c = activeCooldowns[id]
                    or (sName and activeCooldowns[sName])
                    or (cleanName and activeCooldowns[cleanName])
                return as, ad, ae, am, (c and (c.start + c.duration) > GetTime()) and true or false
            end

            -- 1. Rastreador ativo: cobre os momentos em que o jogo devolve
            -- valores secretos (combate nos clientes novos)
            local cached = activeCooldowns[id]
                or (sName and activeCooldowns[sName])
                or (cleanName and activeCooldowns[cleanName])
            if cached then
                if (cached.start + cached.duration) > GetTime() then
                    return cached.start, cached.duration, true
                end
                activeCooldowns[id] = nil
                if sName then activeCooldowns[sName] = nil end
                if cleanName then activeCooldowns[cleanName] = nil end
            end

        elseif actionType == "macro" and id then
            local macroSpell = GetMacroSpell and GetMacroSpell(id)
            if macroSpell then
                if GetSpellCooldown then
                    local ok, s, d, e = pcall(GetSpellCooldown, macroSpell)
                    if ok and not Azaath.AnySecret(s, d) and s and d and s > 0 and d > 1.5 then
                        return s, d, (e == nil) or Azaath.IsOn(e)
                    end
                end
                local clean = CleanSpellName(macroSpell)
                local cached = activeCooldowns[macroSpell] or (clean and activeCooldowns[clean])
                if cached and (cached.start + cached.duration) > GetTime() then
                    return cached.start, cached.duration, true
                end
            end

        elseif actionType == "item" and id then
            local getItemCD = Azaath.API.GetItemCooldown or (C_Container and C_Container.GetItemCooldown) or GetItemCooldown
            if getItemCD then
                local ok, s, d, e = pcall(getItemCD, id)
                if ok and not Azaath.AnySecret(s, d) and s and d and s > 0 and d > 1.5 then
                    return s, d, (e == nil) or Azaath.IsOn(e)
                end
            end
        end
    end

    -- 6. Consulta nativa GetActionCooldown
    local aStart, aDuration, aEnable, aModRate = GetActionCooldown(a)
    if not Azaath.AnySecret(aStart, aDuration) and aStart and aDuration then
        local enabled = (aEnable == nil) or (not Azaath.IsSecret(aEnable) and Azaath.IsOn(aEnable))
        if aStart > 0 and aDuration > 0 then
            return aStart, aDuration, enabled, aModRate
        else
            return 0, 0, enabled, aModRate
        end
    end

    -- 7. Se for secret value, repassa ao frame C++
    return aStart, aDuration, aEnable, aModRate
end

-- Recarga secreta: objeto de duração do jogo (cliente 12.x)
local function SecretCooldownDuration(b)
    local a = b.action
    if C_ActionBar and C_ActionBar.GetActionCooldownDuration then
        local ok, d = pcall(C_ActionBar.GetActionCooldownDuration, a)
        if ok and d then return d end
    end
    if GetActionInfo and C_Spell and C_Spell.GetSpellCooldownDuration then
        local t, id = GetActionInfo(a)
        if t == "macro" and id and GetMacroSpell then id = GetMacroSpell(id) end
        if (t == "spell" or t == "macro") and id then
            local ok, d = pcall(C_Spell.GetSpellCooldownDuration, id)
            if ok and d then return d end
        end
    end
end

-- Formatador do jogo no mesmo formato do FormatCooldown (s, m:ss, h)
local cdFormatter
local function CooldownFormatter()
    if cdFormatter ~= nil then return cdFormatter or nil end
    cdFormatter = false
    if not (C_StringUtil and C_StringUtil.CreateNumericRuleFormatter) then return nil end
    local ok, f = pcall(C_StringUtil.CreateNumericRuleFormatter)
    if not (ok and f) then return nil end
    local DOWN = 2 -- arredonda para baixo (mesmo valor usado pelo BetterNamePlates)
    pcall(f.AddBreakpoint, f, { threshold = 0, step = 1, rounding = DOWN, format = "%d" })
    pcall(f.AddBreakpoint, f, { threshold = 60, format = "%d:%02d", components = {
        { div = 60, step = 1, rounding = DOWN }, { mod = 60, step = 1, rounding = DOWN } } })
    pcall(f.AddBreakpoint, f, { threshold = 3600, format = "%dh", components = {
        { div = 3600, step = 1, rounding = DOWN } } })
    cdFormatter = f
    return f
end

-- Liga o texto da recarga ao objeto de duração: o jogo atualiza o número
local function BindCooldownText(b, dur)
    if not (b.cdText and C_DurationUtil and C_DurationUtil.CreateDurationTextBinding) then return false end
    local fmt = CooldownFormatter()
    if not fmt then return false end
    local bind = b.cdBinding
    if not bind then
        local ok, nb = pcall(C_DurationUtil.CreateDurationTextBinding)
        if not (ok and nb) then return false end
        bind = nb
        pcall(bind.SetFontString, bind, b.cdText)
        pcall(bind.SetFormatter, bind, fmt)
        pcall(bind.SetExpiredText, bind, "")
        pcall(bind.SetZeroDurationText, bind, "")
        pcall(bind.SetUpdateInterval, bind, 0.1)
        b.cdBinding = bind
    end
    if not pcall(bind.SetDuration, bind, dur) then return false end
    pcall(bind.SetEnabled, bind, true)
    b.cdText:Show()
    return true
end

local function UnbindCooldownText(b)
    if b.cdBinding then pcall(b.cdBinding.SetEnabled, b.cdBinding, false) end
end

local function UpdateCooldown(b)
    local a = b.action
    if not (a and HasAction(a)) then
        b.cooldown:Hide()
        b.cdExpiration = nil
        if b.cdOverlay then b.cdOverlay:Hide() end
        if b.cdText then b.cdText:Hide() end
        return
    end

    local start, duration, enable, modRate, tracked = GetButtonCooldown(b)

    -- Se são números normais em Lua:
    if not Azaath.AnySecret(start, duration) then
        b.cdSecret = nil
        UnbindCooldownText(b)
        local enabled = (enable == nil) or Azaath.IsOn(enable)
        local now = GetTime()
        local active = enabled and start and duration and (start > 0) and (duration > 0)
        local rem = active and ((start + duration) - now) or 0

        if active and rem > 0.05 then
            b.cooldown:Show()
            pcall(b.cooldown.SetCooldown, b.cooldown, start, duration)
            if duration > 1.5 then
                -- Recarga real da habilidade: exibe visual Azaath (pergaminho #c4a982 + número)
                b.cdExpiration = start + duration
                if b.cdOverlay then b.cdOverlay:Show() end
                if b.cdText then
                    b.cdText:SetText(FormatCooldown(rem))
                    b.cdText:Show()
                end
            else
                -- GCD (<= 1.5s): apenas o frame nativo roda, sem overlay opaco
                b.cdExpiration = nil
                if b.cdOverlay then b.cdOverlay:Hide() end
                if b.cdText then b.cdText:Hide() end
            end
        else
            -- Pronta / sem recarga
            b.cooldown:Hide()
            b.cdExpiration = nil
            if b.cdOverlay then b.cdOverlay:Hide() end
            if b.cdText then b.cdText:Hide() end
        end
    else
        -- Valores secretos (combate, cliente 12.x): o jogo entrega um objeto de
        -- duração que o frame nativo e um texto ligado a ele sabem usar sem o
        -- addon ler o número (mesmo caminho do BetterNamePlates).
        b.cdExpiration = nil
        local cd = b.cooldown
        cd:Show()
        local dur = SecretCooldownDuration(b)
        local applied = false
        if dur and cd.SetCooldownFromDurationObject then
            applied = pcall(cd.SetCooldownFromDurationObject, cd, dur)
        end
        if not applied then
            if modRate ~= nil then
                applied = pcall(cd.SetCooldown, cd, start, duration, modRate)
            end
            if not applied then pcall(cd.SetCooldown, cd, start, duration) end
        end

        -- pergaminho e número: só se houve um lançamento registrado (evita
        -- piscar na recarga global); saem no OnCooldownDone do frame nativo
        if tracked then
            b.cdSecret = true
            if b.cdOverlay then b.cdOverlay:Show() end
            if not (dur and BindCooldownText(b, dur)) and b.cdText then b.cdText:Hide() end
        else
            if not b.cdSecret then
                if b.cdOverlay then b.cdOverlay:Hide() end
                UnbindCooldownText(b)
                if b.cdText then b.cdText:Hide() end
            end
        end
    end
end

local function UpdateState(b)
    local a = b.action
    local checked = false
    if a and HasAction(a) then
        local cur = IsCurrentAction(a)
        local rep = IsAutoRepeatAction(a)
        if not Azaath.AnySecret(cur, rep) and (cur or rep) then
            checked = true
        end
    end
    if b:GetChecked() ~= checked then
        b:SetChecked(checked)
    end
end

local function UpdateCount(b)
    local a = b.action
    if a and HasAction(a) and (IsConsumableAction(a) or IsStackableAction(a)) then
        local n = GetActionCount(a)
        if Azaath.IsSecret(n) then
            b.count:SetText(n or "")
        elseif type(n) == "number" and n > 1 then
            b.count:SetText(n > 9999 and "*" or n)
        else
            b.count:SetText("")
        end
    else
        b.count:SetText("")
    end
end

local function UpdateButton(b)
    local a = b.action
    local hasAction = a and HasAction(a)
    if hasAction then
        b.icon:SetTexture(GetActionTexture(a))
        b.icon:Show()
        if b.hatch then b.hatch:Show() end
        b.outOfRange = nil
        UpdateUsable(b)
    else
        b.icon:Hide()
        if b.hatch then b.hatch:Hide() end
        b.outOfRange = nil
        b.cdExpiration = nil
        if b.cdOverlay then b.cdOverlay:Hide() end
        if b.cdText then b.cdText:Hide() end
    end
    UpdateCooldown(b)
    UpdateState(b)
    UpdateCount(b)
    UpdateBorder(b)
end

local function ForEachButton(fn)
    for i = 1, #buttons do fn(buttons[i]) end
end

-- /azaath cd [nome]: mostra no chat o que o jogo responde sobre a recarga de
-- cada botão (filtra pelo nome da habilidade; sem nome, só os que têm recarga)
function Azaath.DebugCooldowns(filter)
    local function v(x)
        if Azaath.IsSecret(x) then return "SECRETO" end
        if type(x) == "number" then return format("%.1f", x) end
        return tostring(x)
    end
    local now = GetTime()
    local out = DEFAULT_CHAT_FRAME
    out:AddMessage(format("|cffe3c78bAzaath cd|r agora=%.1f filtro=%s", now, filter ~= "" and filter or "-"))
    local shown = 0
    for i = 1, #buttons do
        local b = buttons[i]
        local a = b.action
        if a and HasAction(a) and GetActionInfo then
            local t, id = GetActionInfo(a)
            local name = (t == "spell" and id and GetSpellNameByID(id))
                or (t == "macro" and id and GetMacroSpell and GetMacroSpell(id)) or tostring(id)
            local as, ad, ae = GetActionCooldown(a)
            local bs, bd, be = GetButtonCooldown(b)
            local match
            if filter and filter ~= "" then
                match = type(name) == "string" and name:lower():find(filter, 1, true)
            else
                match = Azaath.AnySecret(as, bs) or (as and as > 0 and ad and ad > 1.5) or (bs and bs > 0)
                    or b.cdExpiration
            end
            if match then
                shown = shown + 1
                out:AddMessage(format("[%d] %s %s id=%s  ação: %s/%s/%s  botão: %s/%s/%s  exp=%s vis=%s",
                    a, t or "?", tostring(name), tostring(id), v(as), v(ad), v(ae), v(bs), v(bd), v(be),
                    b.cdExpiration and format("%.1f", b.cdExpiration - now) or "-",
                    tostring(b.cooldown:IsShown())))
                if t == "spell" and id then
                    if C_Spell and C_Spell.GetSpellCooldown then
                        local ok, info = pcall(C_Spell.GetSpellCooldown, id)
                        if ok and type(info) == "table" then
                            out:AddMessage(format("    C_Spell: início=%s dur=%s ativo=%s modRate=%s cat=%s",
                                v(info.startTime), v(info.duration), v(info.isEnabled), v(info.modRate),
                                v(info.activeCategory)))
                        else
                            out:AddMessage("    C_Spell: " .. tostring(info))
                        end
                    end
                    if GetSpellCooldown then
                        local ok, s, d, e = pcall(GetSpellCooldown, id)
                        out:AddMessage(format("    GetSpellCooldown: %s %s/%s/%s", tostring(ok), v(s), v(d), v(e)))
                    end
                    if GetSpellBaseCooldown then
                        local ok, base = pcall(GetSpellBaseCooldown, id)
                        out:AddMessage(format("    base=%s", ok and v(base) or "erro"))
                    end
                    local c = activeCooldowns[id] or (name and activeCooldowns[name])
                    out:AddMessage(c and format("    rastreador: início=%.1f dur=%.1f", c.start, c.duration)
                        or "    rastreador: -")
                    out:AddMessage(format("    12.x: durAção=%s durFeitiço=%s duração=%s fromDur=%s texto=%s formato=%s ligado=%s",
                        tostring(C_ActionBar and C_ActionBar.GetActionCooldownDuration ~= nil),
                        tostring(C_Spell and C_Spell.GetSpellCooldownDuration ~= nil),
                        type(SecretCooldownDuration(b)),
                        tostring(b.cooldown.SetCooldownFromDurationObject ~= nil),
                        tostring(C_DurationUtil and C_DurationUtil.CreateDurationTextBinding ~= nil),
                        tostring(CooldownFormatter() ~= nil),
                        tostring(b.cdBinding ~= nil)))
                end
            end
        end
    end
    if shown == 0 then out:AddMessage("nenhum botão encontrado") end
end

--------------------------------------------------------------------------------
-- Scripts dos botões
--------------------------------------------------------------------------------
local function Button_OnAttributeChanged(self, name, value)
    if name == "action" then
        self.action = value
        UpdateButton(self)
        if GameTooltip:IsOwned(self) then self:GetScript("OnEnter")(self) end
    end
end

local function Button_OnEnter(self)
    if not (self.action and HasAction(self.action)) then return end
    GameTooltip_SetDefaultAnchor(GameTooltip, self)
    GameTooltip:SetAction(self.action)
end

local function Button_OnLeave(self)
    GameTooltip:Hide()
end

-- PickupAction/PlaceAction são protegidas em combate quando chamadas por addon
-- (a Blizzard pode, pois o código dela é seguro). Sem esta guarda, arrastar em
-- combate gera ADDON_ACTION_BLOCKED. Clicar num botão segurando uma magia
-- continua funcionando em combate: isso passa pelo clique seguro (UseAction).
local function Button_OnDragStart(self)
    if InCombatLockdown() then return end
    if not Azaath.API.ActionBarsLocked() or IsModifiedClick("PICKUPACTION") then
        PickupAction(self.action)
    end
end

local function Button_OnReceiveDrag(self)
    if InCombatLockdown() then return end
    PlaceAction(self.action)
end

local function Button_PostClick(self)
    UpdateState(self) -- CheckButton alterna "checked" sozinho; corrigimos pelo estado real
end

--------------------------------------------------------------------------------
-- Barras Reforged (Opção 4): botões transparentes sobre os espaços da faixa
-- (desenho e arranjo em PlaceAzaathBar, abaixo); as abas de postura ficam em
-- cima da faixa esquerda (StancePetBars.lua).
--------------------------------------------------------------------------------
local AZ_KEY_H, AZ_KEY_CAP = 22, 9
-- Opção 4 (Reforged), em qualquer skin: cada faixa é a própria barra e se move à parte
local function IsAzaath() return Azaath.IsReforgedBars and Azaath.IsReforgedBars() end

-- Caixinha de tecla recortada do conceito (Media/Azaath/Key)
function Azaath.AzaathStyleKeyBox(box)
    if not box or box.azaath then return end
    box.azaath = true
    local tex, cap = Azaath.media.path .. "Azaath\\Key", AZ_KEY_CAP / 43
    box:SetHeight(AZ_KEY_H)
    if box.left then
        box.left:SetTexture(tex); box.left:SetTexCoord(0, cap, 0, 1); box.left:SetWidth(AZ_KEY_CAP)
    end
    if box.right then
        box.right:SetTexture(tex); box.right:SetTexCoord(1 - cap, 1, 0, 1); box.right:SetWidth(AZ_KEY_CAP)
    end
    if box.mid then box.mid:SetTexture(tex); box.mid:SetTexCoord(cap, 1 - cap, 0, 1) end
    box.minW, box.pad, box.capsW = 28, 18, AZ_KEY_CAP * 2
end

local function AzaathSkinButton(b, inset, circular)
    if b.azaathInset == inset and b.azaathCircular == (circular == true) then return end
    b.azaathInset = inset
    b.azaathCircular = (circular == true)
    b:SetBackdropColor(0, 0, 0, 0)
    if b.SetBackdropBorderColor then b:SetBackdropBorderColor(0, 0, 0, 0) end
    GetSlotBorder(b):SetAlpha(0)
    local function Inner(t)
        if not t then return end
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
        t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
    end
    Inner(b.icon); Inner(b.cdOverlay); Inner(b.cooldown)
    if b.hatch then b.hatch:SetAlpha(0) end -- o conceito não tem a hachura Azaath
    local fontR = Azaath.media.fontCardR or Azaath.media.font
    b.hotkey:SetFont(fontR, 13, "")
    b.hotkey:SetTextColor(0.86, 0.86, 0.84)
    b.hotkey:SetShadowOffset(1, -1)
    b.hotkey:SetShadowColor(0, 0, 0, 0.9)
    if b.keyBox then
        Azaath.AzaathStyleKeyBox(b.keyBox)
        b.keyBox:ClearAllPoints()
        b.keyBox:SetPoint("TOP", b, "BOTTOM", 0, -4)
    end
    -- acúmulos grandes e centralizados na base do ícone ("13", "12", "11")
    b.count:SetFont(Azaath.media.fontCard or fontR, inset >= 6 and 17 or 15, "OUTLINE")
    b.count:ClearAllPoints()
    b.count:SetPoint("BOTTOM", b, "BOTTOM", 0, inset + 1)
end

-- Opção 4 (Reforged) minimalista (tools/reforged-bars/gen.js): cada barra é uma
-- faixa escura com filete dourado (RBarPlate, 9 fatias) e espaços com a
-- moldura dourada do conceito (RBarSlot). A barra 2 fica à esquerda da moldura
-- de vida, a barra 1 à direita. Com 3 barras, a barra 3 vira a fileira de cima
-- das duas faixas: botões 1-6 na esquerda, 7-12 na direita (a faixa cresce
-- para cima). Posição de fábrica: BOTTOM na raiz, base fixa.
local RB_SIZE, RB_SP, RB_PAD = 44, 6, 10
local REFORGED_BASE = { [1] = { 396, 122 }, [2] = { -396, 122 } }
local function RTex(n) return Azaath.media.path .. "Azaath\\" .. n end

-- faixa em 9 fatias: pontas de 32 px e topo/base de 16 px em tamanho real
local PLATE_UV = { { 0, 0.25 }, { 0.25, 0.75 }, { 0.75, 1 } }
local function ReforgedPlate(bar)
    if bar.rplate then return bar.rplate end
    local p = {}
    for r = 1, 3 do
        for c = 1, 3 do
            local t = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
            t:SetTexture(RTex("RBarPlate"))
            t:SetTexCoord(PLATE_UV[c][1], PLATE_UV[c][2], PLATE_UV[r][1], PLATE_UV[r][2])
            p[(r - 1) * 3 + c] = t
        end
    end
    -- cantos fixos
    for k, pt in pairs({ [1] = "TOPLEFT", [3] = "TOPRIGHT", [7] = "BOTTOMLEFT", [9] = "BOTTOMRIGHT" }) do
        p[k]:SetPoint(pt, bar, pt, 0, 0)
        p[k]:SetSize(32, 16)
    end
    -- bordas e meio esticam entre os cantos
    local function Span(t, a, aPt, b, bPt)
        t:SetPoint("TOPLEFT", a, aPt)
        t:SetPoint("BOTTOMRIGHT", b, bPt)
    end
    Span(p[2], p[1], "TOPRIGHT", p[3], "BOTTOMLEFT")
    Span(p[8], p[7], "TOPRIGHT", p[9], "BOTTOMLEFT")
    Span(p[4], p[1], "BOTTOMLEFT", p[7], "TOPRIGHT")
    Span(p[6], p[3], "BOTTOMLEFT", p[9], "TOPRIGHT")
    Span(p[5], p[1], "BOTTOMRIGHT", p[9], "TOPLEFT")
    bar.rplate = p
    return p
end

-- espaço com a moldura dourada atrás do botão
local function ReforgedSlot(b, size)
    if not b.rslot then
        b.rslot = b:CreateTexture(nil, "BACKGROUND", nil, -7)
        b.rslot:SetTexture(RTex("RBarSlot"))
        b.rslot:SetAllPoints(b)
    end
    b:SetWidth(size)
    b:SetHeight(size)
    b:Show()
    AzaathSkinButton(b, math.floor(size * 6 / 54 + 0.5))
end

local function ReforgedHasBar3()
    local db = Azaath.db.actionbars
    return db.enabled and math.min(#BAR_DEFS, db.bars or 3) >= 3 and bars[3] ~= nil
end

local function PlaceAzaathBar(bar, id)
    local db = Azaath.db.actionbars
    if bar.def.visibility then
        RegisterStateDriver(bar, "visibility", bar.def.visibility)
    else
        bar:Show()
    end
    local step = RB_SIZE + RB_SP
    if id == 3 then
        -- sem faixa própria: 1-6 na fileira de cima da barra 2, 7-12 na da barra 1
        -- (cada botão pega a escala da barra onde fica)
        bar:SetScale(1)
        bar:SetSize(1, 1)
        bar:ClearAllPoints()
        bar:SetPoint("BOTTOM", Azaath.root, "BOTTOM", 0, 0)
        for i, b in ipairs(bar.buttons or {}) do
            local host = (i <= 6) and bars[2] or bars[1]
            b:ClearAllPoints()
            if host then
                b:SetScale(host:GetScale())
                b:SetPoint("TOPLEFT", host, "TOPLEFT", RB_PAD + ((i - 1) % 6) * step, -RB_PAD)
                ReforgedSlot(b, RB_SIZE)
            else
                b:Hide()
            end
        end
        return
    end
    local bcfg = db["bar" .. id] or {}
    local scale = (bcfg.scale and bcfg.scale > 0) and bcfg.scale or (db.scale or 1)
    local base = REFORGED_BASE[id]
    local extra = ReforgedHasBar3() and 1 or 0
    bar:SetScale(scale > 0 and scale or 1)
    bar:SetWidth(6 * RB_SIZE + 5 * RB_SP + 2 * RB_PAD)
    bar:SetHeight((2 + extra) * RB_SIZE + (1 + extra) * RB_SP + 2 * RB_PAD)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", Azaath.root, "BOTTOM", base[1] + (bcfg.offsetX or 0), base[2] + (bcfg.offsetY or 0))
    ReforgedPlate(bar)
    for i, b in ipairs(bar.buttons or {}) do
        local r, c = math.floor((i - 1) / 6) + extra, (i - 1) % 6
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", bar, "TOPLEFT", RB_PAD + c * step, -(RB_PAD + r * step))
        ReforgedSlot(b, RB_SIZE)
    end
    if Azaath.ClampToScreen then Azaath.ClampToScreen(bar) end
end

--------------------------------------------------------------------------------
-- Skin Black Desert (tools/bdo-actionbar-concept): losangos com a arte do
-- losango de nível da HUD BDO, arranjados como no Throne and Liberty.
--   barra 1 -> 3 direcionais de 4 losangos (1-4, 5-8, 9-=), em grade 2x2 girada (1 esq., 2 cima, 3 baixo, 4 dir.)
--   barra 2 -> 2 asas de 6 losangos em zigue-zague (esquerda 1-6, direita 7-12)
--   barra 3 -> oculta (os atalhos dela seguem valendo)
-- O direcional fica dourado por alguns segundos quando um botão dele é usado;
-- magias com proc (SPELL_ACTIVATION_OVERLAY) ganham o aro dourado.
--------------------------------------------------------------------------------
local function IsBDOBar()
    local ab = Azaath.db and Azaath.db.actionbars
    return ab ~= nil and ab.layout == "bdo" and Azaath.BDO_BAR ~= nil -- Opção 1, em qualquer skin
end
local function BDOTex(n) return Azaath.media.path .. "BDO\\Bar\\" .. n end
local BDO_BASE_Y = 26
local BDO_GOLD_HOLD, BDO_GOLD_FADE = 2.5, 0.6

local bdoGold = CreateFrame("Frame") -- apaga o dourado dos direcionais
bdoGold:Hide()
bdoGold:SetScript("OnUpdate", function(self)
    local now, any = GetTime(), false
    local list = bars[1] and bars[1].bdoClusters
    for _, cl in ipairs(list or {}) do
        if cl.lit then
            local a = 1 - math.max(0, now - cl.lit - BDO_GOLD_HOLD) / BDO_GOLD_FADE
            if a <= 0 then
                cl.lit = nil
                cl.gold:Hide()
                cl.gemLit:Hide()
            else
                cl.gold:SetAlpha(a)
                cl.gemLit:SetAlpha(a)
                any = true
            end
        end
    end
    if not any then self:Hide() end
end)

local function BDOLightCluster(b)
    local k = b.bdoCluster
    local cl = k and bars[1] and bars[1].bdoClusters and bars[1].bdoClusters[k]
    if not cl then return end
    cl.lit = GetTime()
    cl.gold:SetAlpha(1); cl.gold:Show()
    cl.gemLit:SetAlpha(1); cl.gemLit:Show()
    bdoGold:Show()
end

-- Ícone no losango: o da frente fica menor (Azaath.BDO_BAR.icon do botão) com
-- máscara de bordas esfumadas, e uma cópia escura em tamanho cheio atrás
-- cobre as pontas do losango. A cópia segue o ícone (textura e visibilidade).
function Azaath.BDOIconLayers(b, icon, size)
    local diamond = b:CreateMaskTexture()
    diamond:SetTexture(BDOTex("Mask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    diamond:SetAllPoints(b)
    local front = b:CreateMaskTexture()
    front:SetTexture(BDOTex("IconMask"), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    front:SetAllPoints(b)
    icon:AddMaskTexture(front)
    local back = b:CreateTexture(nil, "BACKGROUND", nil, 4)
    back:SetAllPoints(b)
    back:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    back:SetVertexColor(0.32, 0.31, 0.33)
    if back.SetDesaturation then back:SetDesaturation(0.35) end
    back:AddMaskTexture(diamond)
    back:SetTexture(icon:GetTexture())
    if icon:IsShown() then back:Show() else back:Hide() end
    hooksecurefunc(icon, "SetTexture", function(_, tex) back:SetTexture(tex) end)
    hooksecurefunc(icon, "Show", function() back:Show() end)
    hooksecurefunc(icon, "Hide", function() back:Hide() end)
    if icon.SetShown then hooksecurefunc(icon, "SetShown", function(_, v) back:SetShown(v) end) end
    return diamond, back
end

function Azaath.BDOPlaceIcon(b, icon, r)
    icon:ClearAllPoints()
    icon:SetPoint("CENTER", b, "CENTER")
    icon:SetSize(2 * r * Azaath.BDO_BAR.icon, 2 * r * Azaath.BDO_BAR.icon)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
end

local function BDOSkinButton(b, wing, radius)
    local G = Azaath.BDO_BAR
    local kind = wing and "Wing" or "Slot"
    local r = radius or (wing and G.wr or G.r)
    if b.bdoKind == kind .. r then return end
    b.bdoKind = kind .. r
    local t = b.bdo
    if not t then
        t = {}
        b.bdo = t
        t.bg = b:CreateTexture(nil, "BACKGROUND", nil, 2)
        t.bg:SetAllPoints(b)
        -- vidro e moldura acima da espiral de recarga (camada de texto, b + 5)
        t.gloss = b.textLayer:CreateTexture(nil, "BACKGROUND", nil, 1)
        t.gloss:SetAllPoints(b)
        t.frame = b.textLayer:CreateTexture(nil, "BACKGROUND", nil, 2)
        t.frame:SetAllPoints(b)
        t.proc = b.textLayer:CreateTexture(nil, "ARTWORK", nil, 3)
        t.proc:SetPoint("CENTER", b, "CENTER")
        t.proc:SetBlendMode("ADD")
        t.proc:Hide()
        local ag = t.proc:CreateAnimationGroup()
        ag:SetLooping("BOUNCE")
        local al = ag:CreateAnimation("Alpha")
        al:SetFromAlpha(0.55)
        al:SetToAlpha(1)
        al:SetDuration(0.55)
        t.procAnim = ag
        -- ícone, recarga e estados recortados em losango
        if b.CreateMaskTexture and b.icon.AddMaskTexture then
            local m = Azaath.BDOIconLayers(b, b.icon)
            for _, tex in ipairs({ b.cdOverlay, b:GetHighlightTexture(), b:GetPushedTexture(),
                b.GetCheckedTexture and b:GetCheckedTexture() or nil }) do
                if tex and tex.AddMaskTexture then tex:AddMaskTexture(m) end
            end
            t.mask = m
        end
        if not b.keyBox then
            -- layout sem caixinha de tecla: cria uma e põe o texto da tecla nela
            local box = Azaath.CreateKeyBox(b)
            box:SetFrameLevel(b.textLayer:GetFrameLevel() - 1)
            b.hotkey:ClearAllPoints()
            b.hotkey:SetPoint("CENTER", box, "CENTER", 0, 0)
            b.hotkey:SetJustifyH("CENTER")
            box:Hide()
            b.keyBox = box
        end
        b:HookScript("PostClick", BDOLightCluster)
    end

    -- some a arte Azaath do botão
    b:SetBackdropColor(0, 0, 0, 0)
    if b.SetBackdropBorderColor then b:SetBackdropBorderColor(0, 0, 0, 0) end
    GetSlotBorder(b):SetAlpha(0)
    if b.hatch then b.hatch:SetAlpha(0) end

    t.bg:SetTexture(BDOTex(kind .. "BG"))
    t.gloss:SetTexture(BDOTex(kind .. "Gloss"))
    t.frame:SetTexture(BDOTex(kind .. "Frame"))
    t.proc:SetTexture(BDOTex(kind .. "Proc"))
    local pb = wing and G.procBox.wing * r / G.wr or G.procBox.slot * r / G.r
    t.proc:SetSize(pb, pb)

    b.cdOverlay:ClearAllPoints()
    b.cdOverlay:SetAllPoints(b)
    Azaath.BDOPlaceIcon(b, b.icon, r)
    for _, tex in ipairs({ b:GetHighlightTexture(), b:GetPushedTexture(), b.GetCheckedTexture and b:GetCheckedTexture() or nil }) do
        if tex then tex:ClearAllPoints(); tex:SetAllPoints(b) end
    end
    b.cdOverlay:SetTexture(Azaath.media.blank)
    b.cdOverlay:SetVertexColor(0.235, 0.133, 0.44, 0.72) -- roxo da recarga
    local cd = b.cooldown
    cd:ClearAllPoints()
    cd:SetAllPoints(b)
    if cd.SetSwipeTexture then pcall(cd.SetSwipeTexture, cd, BDOTex("Mask")) end
    if cd.SetSwipeColor then pcall(cd.SetSwipeColor, cd, 0, 0, 0, 0.55) end
    if cd.SetDrawEdge then pcall(cd.SetDrawEdge, cd, false) end

    -- área de clique: o quadrado dentro do losango (sem invadir os vizinhos)
    local ins = math.floor(r * 0.3)
    b:SetHitRectInsets(ins, ins, ins, ins)

    local fontB = Azaath.media.fontBDOB or Azaath.media.font
    b.cdText:SetFont(fontB, math.floor(r * (wing and 0.64 or 0.6) + 0.5), "OUTLINE")
    b.cdText:SetTextColor(0.96, 0.94, 1)
    b.cdText:SetShadowOffset(1, -1)
    b.cdText:SetShadowColor(0, 0, 0, 0.8)
    b.cdText:ClearAllPoints()
    b.cdText:SetPoint("CENTER", b, "CENTER", 0, 1)

    -- plaquinha da tecla no vértice de baixo, dentro do losango
    local box = b.keyBox
    local key = BDOTex("Key")
    box:SetHeight(G.keyH)
    box.left:SetTexture(key); box.left:SetTexCoord(0, 0.5, 0, 1); box.left:SetWidth(G.keyH / 2)
    box.right:SetTexture(key); box.right:SetTexCoord(0.5, 1, 0, 1); box.right:SetWidth(G.keyH / 2)
    box.mid:SetTexture(key); box.mid:SetTexCoord(0.49, 0.51, 0, 1)
    box.minW, box.pad, box.capsW = G.keyH + 2, 8, G.keyH
    box:ClearAllPoints()
    box:SetPoint("CENTER", b, "BOTTOM", 0, r * 0.42)
    b.hotkey:SetFont(fontB, r < 20 and 9 or (wing and 9.5 or 10.5), "")
    b.hotkey:SetTextColor(0.94, 0.91, 0.85)
    b.hotkey:SetShadowOffset(1, -1)
    b.hotkey:SetShadowColor(0, 0, 0, 0.9)

    b.count:SetFont(fontB, wing and 11 or 13, "OUTLINE")
    b.count:ClearAllPoints()
    b.count:SetPoint("RIGHT", b, "RIGHT", -r * 0.3, 0)
end

Azaath.BDOSkinButton = BDOSkinButton -- postura (StancePetBars.lua)

local function BDOClusters(bar)
    if bar.bdoClusters then return bar.bdoClusters end
    local G, list = Azaath.BDO_BAR, {}
    for k = 1, 3 do
        local cl = {}
        cl.frame = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
        cl.frame:SetTexture(BDOTex("Cluster"))
        cl.frame:SetSize(G.clusterBox, G.clusterBox)
        cl.gold = bar:CreateTexture(nil, "BORDER", nil, 1)
        cl.gold:SetTexture(BDOTex("ClusterGold"))
        cl.gold:SetSize(G.clusterBox, G.clusterBox)
        cl.gold:Hide()
        cl.gem = bar:CreateTexture(nil, "BORDER", nil, 2)
        cl.gem:SetTexture(BDOTex("Gem"))
        cl.gem:SetSize(G.gem, G.gem)
        cl.gemLit = bar:CreateTexture(nil, "BORDER", nil, 3)
        cl.gemLit:SetTexture(BDOTex("GemLit"))
        cl.gemLit:SetSize(G.gem, G.gem)
        cl.gemLit:Hide()
        list[k] = cl
    end
    bar.bdoClusters = list
    return list
end

local function PlaceBDOBar(bar, id)
    local G, db = Azaath.BDO_BAR, Azaath.db.actionbars
    if bar.def.visibility then
        RegisterStateDriver(bar, "visibility", bar.def.visibility)
    else
        bar:Show()
    end
    local bcfg = db["bar" .. id] or {}
    local scale = (bcfg.scale and bcfg.scale > 0) and bcfg.scale or (db.scale or 1)
    local R, r, d = G.R, G.r, G.r + G.gap
    local w1 = 3 * 2 * R + 2 * G.clusterGap
    local dw = G.wr + G.wgap
    local wingW = 5 * dw + 2 * G.wr
    bar:SetScale(scale > 0 and scale or 1)
    bar:ClearAllPoints()
    bar:SetPoint("BOTTOM", Azaath.root, "BOTTOM", bcfg.offsetX or 0, BDO_BASE_Y + (id == 3 and (2 * R + 14) or 0) + (bcfg.offsetY or 0))
    -- grade 2x2 girada: 1 esquerda, 2 cima, 3 baixo, 4 direita
    local OFF = { { -d, 0 }, { 0, -d }, { 0, d }, { d, 0 } }

    if id == 1 then
        bar:SetSize(w1, 2 * R)
        local list = BDOClusters(bar)
        for k, cl in ipairs(list) do
            local cx = R + (k - 1) * (2 * R + G.clusterGap)
            for _, tex in ipairs({ cl.frame, cl.gold, cl.gem, cl.gemLit }) do
                tex:ClearAllPoints()
                tex:SetPoint("CENTER", bar, "TOPLEFT", cx, -R)
            end
        end
        for i, b in ipairs(bar.buttons or {}) do
            local k, j = math.floor((i - 1) / 4) + 1, (i - 1) % 4 + 1
            local cx = R + (k - 1) * (2 * R + G.clusterGap)
            b.bdoCluster = k
            b:SetSize(2 * r, 2 * r)
            b:ClearAllPoints()
            b:SetPoint("CENTER", bar, "TOPLEFT", cx + OFF[j][1], -(R + OFF[j][2]))
            b:Show()
            BDOSkinButton(b, false)
        end
    else
        bar:SetSize(w1 + 2 * (G.wingGap + wingW), 2 * R)
        for i, b in ipairs(bar.buttons or {}) do
            local n = (i - 1) % 6
            local x0 = (i <= 6) and G.wr or (wingW + G.wingGap + w1 + G.wingGap + G.wr)
            local up = (n % 2 == 0)
            b.bdoCluster = nil
            b:SetSize(2 * G.wr, 2 * G.wr)
            b:ClearAllPoints()
            b:SetPoint("CENTER", bar, "TOPLEFT", x0 + n * dw, -(R + (up and -dw / 2 or dw / 2)))
            b:Show()
            BDOSkinButton(b, true)
        end
    end
    if Azaath.ClampToScreen then Azaath.ClampToScreen(bar) end
end

-- Aro de proc: magia do botão com SPELL_ACTIVATION_OVERLAY_GLOW_SHOW
local bdoProcs = {}
local function BDOActionSpell(action)
    if not action or not HasAction(action) then return nil end
    local kind, sid = GetActionInfo(action)
    if Azaath.AnySecret(kind, sid) then return nil end
    if kind == "spell" then return sid end
    if kind == "macro" and GetMacroSpell then
        local ok, ms = pcall(GetMacroSpell, sid)
        if ok and not Azaath.IsSecret(ms) then return ms end
    end
    return nil
end
local function BDOUpdateProcs()
    for i = 1, #buttons do
        local b = buttons[i]
        local t = b.bdo
        if t then
            local sid = BDOActionSpell(b.action)
            local on = sid and bdoProcs[sid]
            if on and not t.proc:IsShown() then
                t.proc:Show(); t.procAnim:Play()
            elseif not on and t.proc:IsShown() then
                t.procAnim:Stop(); t.proc:Hide()
            end
        end
    end
end
local bdoProcEvents = CreateFrame("Frame")
bdoProcEvents:SetScript("OnEvent", function(_, event, sid)
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        if sid and not Azaath.IsSecret(sid) then bdoProcs[sid] = true end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        if sid and not Azaath.IsSecret(sid) then bdoProcs[sid] = nil end
    elseif not next(bdoProcs) then
        return
    end
    BDOUpdateProcs()
end)

--------------------------------------------------------------------------------
-- Construção
--------------------------------------------------------------------------------
local function CreateButton(bar, index, size, keyBox)
    local name = format("AzaathUIBar%dButton%d", bar.def.id, index)

    local b = CreateFrame("CheckButton", name, bar, "SecureActionButtonTemplate")
    b:SetWidth(size)
    b:SetHeight(size)
    b:RegisterForClicks("AnyDown", "AnyUp")
    b:RegisterForDrag("LeftButton", "RightButton")
    b:EnableMouse(true)

    -- Atributos seguros
    b:SetAttribute("type", "action")
    b:SetAttribute("index", index)
    b:SetAttribute("useOnKeyDown", false)
    b:SetAttribute("checkselfcast", true)   -- Alt+clique = auto-alvo (padrão Blizzard)
    b:SetAttribute("checkfocuscast", true)
    b:SetAttribute("_childupdate-actionpage", [[
        self:SetAttribute("action", self:GetAttribute("index") + (tonumber(message) - 1) * 12)
    ]])

    -- Visual: slot escuro, borda fina, ícone recortado, textos
    Azaath.SkinButton(b, name, { keyBox = keyBox })

    b:SetScript("OnAttributeChanged", Button_OnAttributeChanged)
    b:SetScript("OnEnter", Button_OnEnter)
    b:SetScript("OnLeave", Button_OnLeave)
    b:SetScript("OnDragStart", Button_OnDragStart)
    b:SetScript("OnReceiveDrag", Button_OnReceiveDrag)
    b:SetScript("PostClick", Button_PostClick)

    b.bindingCommand = format(bar.def.binding, index)

    -- Slot inicial (o driver de página da barra principal sobrescreve logo depois)
    b:SetAttribute("action", (bar.def.page - 1) * NUM_BUTTONS + index)

    buttons[#buttons + 1] = b
    return b
end

--------------------------------------------------------------------------------
-- Geometria de cada barra conforme o layout.
--   "az": barra principal à direita e barras secundárias à esquerda da vida.
--   "center": 3 fileiras de 12 empilhadas no centro inferior.
--------------------------------------------------------------------------------
-- Opção 2 (split): octógonos com filete dourado, abas de tecla inclinadas e faixa escura com linha dourada
-- atrás de cada bloco (referência do usuário). As texturas vêm de tools/split-bar-concept/gen.js.
local SPLIT_MARGIN = 32 -- distância da borda da tela
local function ABTex(n) return Azaath.media.path .. "ActionBar" .. string.char(92) .. n end

local function SplitStyleKeyBox(box)
    if box.split then return end
    box.split = true
    local tex, cap = ABTex("SplitKeyTab"), 10 / 64
    box:SetHeight(15)
    if box.left then box.left:SetTexture(tex); box.left:SetTexCoord(0, cap, 0, 1); box.left:SetWidth(10) end
    if box.right then box.right:SetTexture(tex); box.right:SetTexCoord(1 - cap, 1, 0, 1); box.right:SetWidth(10) end
    if box.mid then box.mid:SetTexture(tex); box.mid:SetTexCoord(cap, 1 - cap, 0, 1) end
    box.minW, box.pad, box.capsW = 24, 16, 20
end

local function SplitSkinButton(b, size)
    local inset = math.floor(size * 0.11 + 0.5)
    if b.splitInset ~= inset then
        b.splitInset = inset
        for _, t in ipairs({ b.icon, b.cdOverlay, b.cooldown }) do
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
            t:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)
        end
    end
    if b.splitOn then return end
    b.splitOn = true
    b:SetBackdropColor(0, 0, 0, 0)
    if b.SetBackdropBorderColor then b:SetBackdropBorderColor(0, 0, 0, 0) end
    GetSlotBorder(b):SetAlpha(0)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    bg:SetTexture(ABTex("SplitSlotBg"))
    local ring = b.textLayer:CreateTexture(nil, "ARTWORK")
    ring:SetAllPoints(b)
    ring:SetTexture(ABTex("SplitSlot"))
    b.splitRing = ring
    if b.keyBox then
        SplitStyleKeyBox(b.keyBox)
        b.keyBox.minW = math.max(24, math.floor(size * 0.7 + 0.5)) -- aba com ~70% da largura do botão
        b.keyBox:ClearAllPoints()
        b.keyBox:SetPoint("TOP", b, "BOTTOM", 0, -3)
    end
    b.hotkey:SetFont(Azaath.media.font, 11, "")
    b.hotkey:SetTextColor(0.93, 0.93, 0.91)
end

-- Faixa de vidro atrás das duas fileiras: a da esquerda (barra 2) termina inclinada para o centro e a
-- da direita (barra 1) começa inclinada ("/" nas duas), com degradê e filetes, como na referência.
local function SplitDeco(bar, size, spacing, left)
    local d = bar.splitDeco
    if not d then
        d = CreateFrame("Frame", nil, bar)
        d:SetFrameLevel(math.max(1, bar:GetFrameLevel() - 1))
        d.mid = d:CreateTexture(nil, "BACKGROUND")
        d.mid:SetTexture(ABTex("SplitBandMid"))
        d.cap = d:CreateTexture(nil, "BACKGROUND")
        d.cap:SetTexture(ABTex(left and "SplitBandSlantA" or "SplitBandSlantB"))
        d.cap:SetWidth(24)
        d.fade = d:CreateTexture(nil, "BACKGROUND")
        d.fade:SetTexture(ABTex("SplitBandFade"))
        d.fade:SetWidth(48)
        if not left then d.fade:SetTexCoord(1, 0, 0, 1) end -- esmaece para a borda da tela
        d.line = d:CreateTexture(nil, "ARTWORK")
        d.line:SetTexture(Azaath.media.blank)
        d.line:SetVertexColor(0.80, 0.66, 0.38, 0.45)
        d.dots = {}
        for k = 1, 3 do
            local t = d:CreateTexture(nil, "OVERLAY")
            t:SetTexture(Azaath.media.path .. "Diamond")
            t:SetVertexColor(0.92, 0.76, 0.44, 0.8)
            t:SetWidth(8)
            t:SetHeight(8)
            d.dots[k] = t
        end
        bar.splitDeco = d
    end
    local keyH = KEYBOX_H + 3
    local rowStep = size + spacing + keyH
    local top, bottom = size * 0.55, rowStep + size * 0.35
    local lineY = size + keyH + spacing / 2
    local outer, inner = size * 0.6, size * (left and 0.7 or 0.3)
    d:ClearAllPoints()
    d:SetPoint("TOPLEFT", bar, "TOPLEFT", -(left and outer or inner), -top)
    d:SetPoint("BOTTOMRIGHT", bar, "TOPRIGHT", (left and inner or outer), -bottom)
    d.cap:ClearAllPoints()
    d.mid:ClearAllPoints()
    d.fade:ClearAllPoints()
    if left then
        d.cap:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, 0)
        d.cap:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 0, 0)
        d.fade:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
        d.fade:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, 0)
        d.mid:SetPoint("TOPLEFT", d.fade, "TOPRIGHT", 0, 0)
        d.mid:SetPoint("BOTTOMRIGHT", d.cap, "BOTTOMLEFT", 0, 0)
    else
        d.cap:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
        d.cap:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, 0)
        d.fade:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, 0)
        d.fade:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 0, 0)
        d.mid:SetPoint("TOPLEFT", d.cap, "TOPRIGHT", 0, 0)
        d.mid:SetPoint("BOTTOMRIGHT", d.fade, "BOTTOMLEFT", 0, 0)
    end
    d.line:ClearAllPoints()
    d.line:SetPoint("TOPLEFT", d, "TOPLEFT", 8, -(lineY - top))
    d.line:SetPoint("TOPRIGHT", d, "TOPRIGHT", -8, -(lineY - top))
    d.line:SetHeight(1)
    local W = bar:GetWidth()
    for k, t in ipairs(d.dots) do
        t:ClearAllPoints()
        t:SetPoint("CENTER", bar, "TOPLEFT", W * (0.25 * k), -lineY)
    end
    d:Show()
end

local function BarGeometry(id, db, bars, count)
    if Azaath.IsSplitLayout(db.layout) then
        -- Opção 2: barra 2 colada na borda esquerda e barra 1 na direita, na base, cada uma em grade 6x2
        local y = db.offsetY or 34
        local size = db.buttonSize or 42
        if id == 1 then
            return size, 6, true, "BOTTOMRIGHT", Azaath.root, "BOTTOMRIGHT", -SPLIT_MARGIN, y
        end
        if id == 3 then -- barra 3: bloco extra, no mesmo estilo, acima da barra 2
            local rowStep = size + (db.spacing or 5) + KEYBOX_H + 3
            return size, 6, true, "BOTTOMLEFT", Azaath.root, "BOTTOMLEFT", SPLIT_MARGIN, y + 2 * rowStep + 6
        end
        return size, 6, true, "BOTTOMLEFT", Azaath.root, "BOTTOMLEFT", SPLIT_MARGIN, y
    end
    if Azaath.IsAzLayout(db.layout) then
        local small = db.smallSize or 32
        local mainSize = db.buttonSize or 42
        local pCfg = Azaath.db.unitframes and Azaath.db.unitframes.player
        local pWidth = (pCfg and pCfg.width) or 270
        local pScale = (pCfg and pCfg.scale and pCfg.scale > 0) and pCfg.scale or 1
        local sideOffset = math.floor((pWidth * pScale) / 2) + 22
        local y = db.offsetY or 34

        if id == 1 then
            -- Barra principal de skills: à DIREITA da barra central de vida (ícones maiores)
            return mainSize, 6, true, "BOTTOMLEFT", Azaath.root, "BOTTOM", sideOffset, y
        elseif id == 2 then
            -- Barra secundária 1: à ESQUERDA da barra central de vida (ícones menores)
            return small, 6, true, "BOTTOMRIGHT", Azaath.root, "BOTTOM", -sideOffset, y
        else
            -- Barra secundária 2: acima da barra secundária 1 na esquerda (independente para arraste)
            local spacing = db.spacing or 6
            local b2cfg = db.bar2 or {}
            local b2Size = (b2cfg.buttonSize and b2cfg.buttonSize > 0) and b2cfg.buttonSize or small
            local b2Cols = (b2cfg.cols and b2cfg.cols > 0) and b2cfg.cols or 6
            local b2Rows = math.ceil(NUM_BUTTONS / b2Cols)
            local b2Step = b2Size + spacing + (KEYBOX_H + 3)
            local b2Height = b2Rows * b2Step - spacing
            return small, 6, true, "BOTTOMRIGHT", Azaath.root, "BOTTOM", -sideOffset, y + b2Height + 10
        end
    end
    local prev = bars[id - 1]
    if prev then
        return db.buttonSize, 12, false, "BOTTOM", prev, "TOP", 0, db.spacing
    end
    return db.buttonSize, 12, false, "BOTTOM", Azaath.root, "BOTTOM", 0, db.offsetY
end

local function CreateBar(def, db, count)
    -- já existe (ApplyLayout pode criar antes do Build): criar de novo deixaria a
    -- cópia antiga, com o mesmo nome global, congelada por baixo da nova ("fantasma")
    if bars[def.id] then return bars[def.id] end
    local size, cols, keyBox, point, rel, relPoint, x, y = BarGeometry(def.id, db, bars, count)
    local spacing = db.spacing
    local displaySlots = NUM_BUTTONS
    local rows = math.ceil(displaySlots / cols)
    -- cada fileira reserva espaço para a caixinha de tecla abaixo dos botões
    local rowStep = size + spacing + (keyBox and (KEYBOX_H + 3) or 0)

    local bar = CreateFrame("Frame", "AzaathUIBar" .. def.id, Azaath.root, "SecureHandlerStateTemplate")
    bar.def = def
    bar.buttons = {}
    bar:SetWidth(cols * size + (cols - 1) * spacing)
    bar:SetHeight(rows * rowStep - spacing)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(10)
    bar:SetPoint(point, rel, relPoint, x, y)

    for i = 1, NUM_BUTTONS do
        local b = CreateButton(bar, i, size, keyBox)
        bar.buttons[i] = b
        local baseLevel = bar:GetFrameLevel() + 2
        b:SetFrameLevel(baseLevel)
        if b.cooldown then
            b.cooldown:SetFrameLevel(baseLevel + 3)
        end
        if b.textLayer then
            b.textLayer:SetFrameLevel(baseLevel + 5)
        end
        if b.keyBox then
            b.keyBox:SetFrameLevel(baseLevel + 6)
        end
        local row, col = math.floor((i - 1) / cols), (i - 1) % cols
        b:SetPoint("TOPLEFT", bar, "TOPLEFT", col * (size + spacing), -row * rowStep)
        if i > displaySlots then
            b:Hide()
        end
    end

    if def.pageDriver then
        bar:SetAttribute("_onstate-page", [[
            self:SetAttribute("actionpage", newstate)
            control:ChildUpdate("actionpage", newstate)
        ]])
        RegisterStateDriver(bar, "page", def.pageDriver)
    end
    if def.visibility then
        RegisterStateDriver(bar, "visibility", def.visibility)
    end

    bars[def.id] = bar
    return bar
end

-- Botão "sair do veículo" (não seguro: VehicleExit() não é protegida).
local function CreateLeaveButton(mainBar, size, azLayout)
    local c, blank = Azaath.colors, Azaath.media.blank
    local b = CreateFrame("Button", "AzaathUILeaveVehicle", Azaath.root)
    b:SetWidth(size)
    b:SetHeight(size)
    if azLayout then
        b:SetPoint("BOTTOMLEFT", mainBar, "TOPLEFT", 0, 10)
    else
        b:SetPoint("LEFT", mainBar, "RIGHT", 10, 0)
    end
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(15)
    b:RegisterForClicks("AnyDown", "AnyUp")
    Azaath.SetBackdrop(b, GetBackdrop())
    b:SetBackdropColor(c.dark[1], c.dark[2], c.dark[3], 0.75)
    b:SetBackdropBorderColor(c.accent[1], c.accent[2], c.accent[3], 0.8)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
    icon:SetTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up")
    icon:SetTexCoord(0.14, 0.86, 0.14, 0.86)

    b:SetHighlightTexture(blank)
    local hl = b:GetHighlightTexture()
    hl:SetAllPoints(icon)
    hl:SetVertexColor(1, 1, 1)
    hl:SetAlpha(0.15)

    b:SetScript("OnClick", function(self)
        if UnitOnTaxi and UnitOnTaxi("player") and TaxiRequestEarlyLanding then
            pcall(TaxiRequestEarlyLanding)
        end
        if VehicleExit then
            pcall(VehicleExit)
        end
        self:Hide()
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetText(LEAVE_VEHICLE or "Sair do veículo")
    end)
    b:SetScript("OnLeave", Button_OnLeave)
    b:Hide()
    return b
end

-- Botão redondo de inventário (o MainMenuBar, com as bolsas e o micro menu,
-- está oculto). Não é seguro: abrir bolsas não é ação protegida.
local function FreeBagSlots()
    local free, total = 0, 0
    for bag = 0, 4 do
        free = free + (Azaath.API.GetContainerNumFreeSlots(bag) or 0)
        total = total + (Azaath.API.GetContainerNumSlots(bag) or 0)
    end
    return free, total
end

local function CreateBagButton(anchor, size)
    local c, media = Azaath.colors, Azaath.media
    local d = size + 4
    local b = CreateFrame("Button", "AzaathUIBagButton", Azaath.root)
    b:SetWidth(d)
    b:SetHeight(d)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(15)
    b:RegisterForClicks("AnyUp")      -- (só ao soltar: arrastar não abre o inventário)
    -- Canto direito inferior da tela (estilo Azaath); arrastável, a posição fica em db.bag.offsetX/Y
    b:SetPoint("BOTTOMRIGHT", Azaath.root, "BOTTOMRIGHT", -24, 30)
    b:SetMovable(true)
    b:SetClampedToScreen(true)
    b:RegisterForDrag("LeftButton")
    b:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:StartMoving()
    end)
    b:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local root, es = Azaath.root, self:GetEffectiveScale()
        local rs = root:GetEffectiveScale()
        local ox = (self:GetRight() * es - root:GetRight() * rs) / es
        local oy = (self:GetBottom() * es - root:GetBottom() * rs) / es
        M.db.bag = M.db.bag or {}
        M.db.bag.offsetX, M.db.bag.offsetY = ox, oy
        self:ClearAllPoints()
        self:SetPoint("BOTTOMRIGHT", root, "BOTTOMRIGHT", ox, oy)
    end)

    local back = b:CreateTexture(nil, "BACKGROUND")
    back:SetTexture(media.path .. "Glow")
    back:SetVertexColor(c.dark[1], c.dark[2], c.dark[3])
    back:SetAlpha(0.9)
    back:SetAllPoints(b)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetTexture("Interface\\Buttons\\Button-Backpack-Up")
    icon:SetWidth(size * 0.55)
    icon:SetHeight(size * 0.55)
    icon:SetPoint("CENTER", b, "CENTER", 0, 0)
    icon:SetDesaturated(true)
    icon:SetVertexColor(0.85, 0.85, 0.85)
    b.icon = icon

    local ring = b:CreateTexture(nil, "OVERLAY")
    ring:SetTexture(media.path .. "Ring")
    ring:SetVertexColor(c.cream[1], c.cream[2], c.cream[3])
    ring:SetAlpha(0.75)
    ring:SetAllPoints(b)

    b:SetHighlightTexture(media.path .. "Glow")
    local hl = b:GetHighlightTexture()
    hl:SetVertexColor(1, 1, 1)
    hl:SetAlpha(0.12)
    hl:SetBlendMode("ADD")

    -- caixinha de tecla abaixo, como nos botões de ação
    local box = Azaath.CreateKeyBox(b)
    box:SetPoint("TOP", b, "BOTTOM", 0, -3)
    local key = box:CreateFontString(nil, "OVERLAY")
    key:SetFont(media.font, 11, "")
    key:SetPoint("CENTER", box, "CENTER", 0, 0)
    b.keyBox, b.hotkey = box, key

    local function UpdateKey()
        local k = GetBindingKey("OPENALLBAGS") or GetBindingKey("TOGGLEBACKPACK")
        Azaath.SetHotkeyText(b, k and Azaath.ShortKey(k) or "")
    end
    UpdateKey()
    Azaath.SafeRegister(b, "UPDATE_BINDINGS")
    b:SetScript("OnEvent", UpdateKey)

    b:SetScript("OnClick", function()
        local inv = Azaath:GetModule("Inventory", true)
        if inv and inv.Toggle then
            inv:Toggle()
        elseif ToggleAllBags then
            ToggleAllBags()
        elseif OpenAllBags then
            OpenAllBags()
        end
    end)
    b:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        local free, total = FreeBagSlots()
        GameTooltip:AddLine("Inventário", c.cream[1], c.cream[2], c.cream[3])
        GameTooltip:AddLine(format("%d de %d espaços livres", free, total), 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", Button_OnLeave)
    return b
end

local function UpdateLeaveButton()
    if not leaveButton then return end
    local onTaxi = UnitOnTaxi and UnitOnTaxi("player")
    if Azaath.IsSecret(onTaxi) then onTaxi = false end
    local inVeh = true
    if UnitInVehicle then
        local v = UnitInVehicle("player")
        local ui = UnitHasVehicleUI and UnitHasVehicleUI("player")
        if not Azaath.AnySecret(v, ui) then
            inVeh = (v or ui) and true or false
        end
    end
    local canExit = inVeh and CanExitVehicle and CanExitVehicle()
    if Azaath.IsSecret(canExit) then canExit = false end
    local show = (onTaxi or canExit) and true or false
    if leaveButton:IsShown() ~= show then
        leaveButton:SetShown(show)
    end
end

--------------------------------------------------------------------------------
-- Keybinds
--------------------------------------------------------------------------------
local lastBindingSignature

function M:UpdateBindings()
    -- Texto de atalho pode ser atualizado a qualquer momento
    local parts = {}
    for i = 1, #buttons do
        local b = buttons[i]
        local key1, key2 = GetBindingKey(b.bindingCommand)
        Azaath.SetHotkeyText(b, self.db.showHotkeys and ShortKey(key1) or "")
        parts[#parts + 1] = (key1 or "") .. "," .. (key2 or "")
    end

    -- Evita reaplicar se nada mudou (SetOverrideBinding pode disparar UPDATE_BINDINGS)
    local signature = table.concat(parts, ";")
    if signature == lastBindingSignature then return end

    Azaath:RunOutOfCombat(function()
        if not bindOwner then return end
        lastBindingSignature = signature
        ClearOverrideBindings(bindOwner)
        for i = 1, #buttons do
            local b = buttons[i]
            local name = b:GetName()
            for k = 1, select("#", GetBindingKey(b.bindingCommand)) do
                local key = select(k, GetBindingKey(b.bindingCommand))
                if key and key ~= "" then
                    SetOverrideBindingClick(bindOwner, false, key, name, "LeftButton")
                end
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- Eventos e checagem de alcance
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")

local function UpdateAllCooldowns()
    ForEachButton(UpdateCooldown)
end

local function OnCooldownEvent()
    UpdateAllCooldowns()
    if C_Timer and C_Timer.After then
        C_Timer.After(0.05, UpdateAllCooldowns)
        C_Timer.After(0.15, UpdateAllCooldowns)
        C_Timer.After(0.3, UpdateAllCooldowns)
    end
end

local function HandleSpellcastSucceeded(unit, ...)
    if unit ~= "player" then return end
    local a1, a2, a3, _, a5 = ...
    local spellID, spellName
    if type(a1) == "string" and (type(a2) == "string" or not a2) and type(a3) == "number" then
        spellName = a1
        spellID = a3
    elseif type(a1) == "string" and type(a2) == "string" and type(a5) == "number" then
        spellName = a1
        spellID = a5
    elseif type(a3) == "number" then
        spellID = a3
    elseif type(a2) == "number" then
        spellID = a2
    elseif type(a1) == "number" then
        spellID = a1
    elseif type(a1) == "string" then
        spellName = a1
    end

    if not spellName and spellID then
        spellName = GetSpellNameByID(spellID)
    end

    local cleanName = CleanSpellName(spellName)

    -- Resolve a duração da recarga
    local start, duration
    if spellID and C_Spell and C_Spell.GetSpellCooldown then
        local ok, info = pcall(C_Spell.GetSpellCooldown, spellID)
        if ok and type(info) == "table" and not Azaath.AnySecret(info.startTime, info.duration) then
            local s = info.startTime or 0
            local d = info.duration or 0
            if s > 0 and d > 1.5 then
                start, duration = s, d
            end
        end
    end
    if not duration and spellID and GetSpellCooldown then
        local ok, s, d = pcall(GetSpellCooldown, spellID)
        if ok and not Azaath.AnySecret(s, d) and s and d and s > 0 and d > 1.5 then
            start, duration = s, d
        end
    end
    if not duration and spellName and GetSpellCooldown then
        local ok, s, d = pcall(GetSpellCooldown, spellName)
        if ok and not Azaath.AnySecret(s, d) and s and d and s > 0 and d > 1.5 then
            start, duration = s, d
        end
    end
    if not duration and spellID and GetSpellBaseCooldown then
        local ok, base = pcall(GetSpellBaseCooldown, spellID)
        if ok and base and base > 1500 then
            start = GetTime()
            duration = base / 1000
        end
    end
    if not duration and spellID and KNOWN_COOLDOWNS[spellID] then
        start = GetTime()
        duration = KNOWN_COOLDOWNS[spellID]
    end
    if not duration and (cleanName or spellName) then
        local kd = (cleanName and KNOWN_COOLDOWNS[cleanName]) or (spellName and KNOWN_COOLDOWNS[spellName])
        if kd then
            start = GetTime()
            duration = kd
        end
    end

    if start and duration and duration > 1.5 then
        local entry = { start = start, duration = duration }
        if spellID then activeCooldowns[spellID] = entry end
        if spellName then activeCooldowns[spellName] = entry end
        if cleanName then activeCooldowns[cleanName] = entry end
    end

    OnCooldownEvent()
end

local function UpdateAllUsable()
    ForEachButton(UpdateUsable)
end

local EVENT_HANDLERS = {
    ACTIONBAR_UPDATE_STATE     = function() ForEachButton(UpdateState) end,
    ACTIONBAR_UPDATE_USABLE    = UpdateAllUsable,
    SPELL_UPDATE_USABLE        = UpdateAllUsable,
    PLAYER_TARGET_CHANGED      = UpdateAllUsable,
    UNIT_POWER_UPDATE          = function(unit) if unit == "player" then UpdateAllUsable() end end,
    UNIT_MANA                  = function(unit) if unit == "player" then UpdateAllUsable() end end,
    UNIT_RAGE                  = function(unit) if unit == "player" then UpdateAllUsable() end end,
    UNIT_ENERGY                = function(unit) if unit == "player" then UpdateAllUsable() end end,
    ACTIONBAR_UPDATE_COOLDOWN  = OnCooldownEvent,
    SPELL_UPDATE_COOLDOWN      = OnCooldownEvent,
    SPELL_UPDATE_CHARGES       = OnCooldownEvent,
    SPELLS_CHANGED             = function() UpdateSpellBookCache(); OnCooldownEvent() end,
    UNIT_SPELLCAST_SUCCEEDED   = HandleSpellcastSucceeded,
    BAG_UPDATE                 = function() ForEachButton(UpdateCount) end,
    UPDATE_BINDINGS            = function() M:UpdateBindings() end,
    PLAYER_ENTERING_WORLD      = function() UpdateSpellBookCache(); ForEachButton(UpdateButton); UpdateLeaveButton() end,
}
local function UpdateAllStates()
    ForEachButton(UpdateState)
end
local function UpdateAllButtons()
    UpdateSpellBookCache()
    ForEachButton(UpdateButton)
end
local function UpdateEquipment()
    ForEachButton(UpdateBorder)
    ForEachButton(UpdateCount)
end

for _, e in ipairs({ "PLAYER_ENTER_COMBAT", "PLAYER_LEAVE_COMBAT", "START_AUTOREPEAT_SPELL",
                     "STOP_AUTOREPEAT_SPELL", "TRADE_SKILL_SHOW", "TRADE_SKILL_CLOSE",
                     "UPDATE_SHAPESHIFT_FORM", "COMPANION_UPDATE" }) do
    EVENT_HANDLERS[e] = UpdateAllStates
end
for _, e in ipairs({ "UPDATE_SHAPESHIFT_FORMS", "LEARNED_SPELL_IN_TAB", "UPDATE_MACROS" }) do
    EVENT_HANDLERS[e] = UpdateAllButtons
end
EVENT_HANDLERS.UPDATE_VEHICLE_ACTIONBAR = function()
    UpdateAllButtons()
    UpdateLeaveButton()
end
for _, e in ipairs({ "PLAYER_CONTROL_GAINED", "PLAYER_CONTROL_LOST", "UPDATE_BONUS_ACTIONBAR", "VEHICLE_UPDATE" }) do
    EVENT_HANDLERS[e] = UpdateLeaveButton
end
for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED" }) do
    EVENT_HANDLERS[e] = UpdateEquipment
end

events:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4, arg5)
    if event == "ACTIONBAR_SLOT_CHANGED" then
        for i = 1, #buttons do
            local b = buttons[i]
            if arg1 == 0 or b.action == arg1 then UpdateButton(b) end
        end
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if arg1 == "player" then
            UpdateAllButtons()
            UpdateLeaveButton()
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        HandleSpellcastSucceeded(arg1, arg2, arg3, arg4, arg5)
    else
        local fn = EVENT_HANDLERS[event]
        if fn then fn(arg1, arg2, arg3, arg4, arg5) end
    end
end)

-- Ticker contínuo para atualizar as contagens de recarga ativas (Azaath) e o alcance
local function MainTick(self, elapsed)
    local now = GetTime()

    -- Atualiza as contagens numéricas das recargas ativas
    for i = 1, #buttons do
        local b = buttons[i]
        local exp = b.cdExpiration
        if exp then
            local rem = exp - now
            if rem > 0 then
                if b.cdText then
                    b.cdText:SetText(FormatCooldown(rem))
                end
            else
                b.cdExpiration = nil
                if b.cdOverlay then b.cdOverlay:Hide() end
                if b.cdText then b.cdText:Hide() end
                b.cooldown:Hide()
                -- confere de novo: a recarga real pode ser maior que a contada
                -- (o jogo estendeu depois do lançamento sem novo evento)
                UpdateCooldown(b)
                UpdateUsable(b)
            end
        end
    end

    self.elapsed = (self.elapsed or 0) + (elapsed or 0)
    if self.elapsed < (self.interval or 0.2) then return end
    self.elapsed = 0
    UpdateLeaveButton()
    for i = 1, #buttons do
        local b = buttons[i]
        local a = b.action
        if a and HasAction(a) then
            local out = ActionHasRange(a) and IsActionInRange(a) == 0 or nil
            if out ~= b.outOfRange then
                b.outOfRange = out
                UpdateUsable(b)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:OnInitialize()
    self.db = Azaath.db.actionbars
    self.buttons = buttons -- AzaathHUD (anel de proc) percorre os botões
    self.bars = bars
end

-- Reler ícones e atalhos de todos os botões (depois do /reload o cliente pode
-- entregar ações/atalhos um pouco depois do PLAYER_LOGIN)
local function RefreshAllButtons()
    UpdateSpellBookCache()
    ForEachButton(UpdateButton)
    lastBindingSignature = nil
    M:UpdateBindings()
end

-- Diagnóstico: AzaathUICharDB.abDiag (gravado no /reload ou ao sair)
local function WriteBarDiag()
    local d = { time = date("%Y-%m-%d %H:%M:%S"), built = M.built and true or false,
        buttons = #buttons, layout = tostring(M.db and M.db.layout), owner = bindOwner and bindOwner:GetName() or "nil",
        bars = {}, sample = {} }
    for id = 1, #BAR_DEFS do
        local bar = bars[id]
        d.bars[id] = bar and format("%s shown=%s vis=%s", bar:GetName() or "?", tostring(bar:IsShown()), tostring(bar:IsVisible())) or "nil"
    end
    for _, i in ipairs({ 1, 2, 13, 14, 25 }) do
        local b = buttons[i]
        if b then
            local a = b:GetAttribute("action")
            local k = GetBindingKey(b.bindingCommand)
            d.sample[#d.sample + 1] = format("%s action=%s has=%s key=%s icon=%s shown=%s",
                b:GetName() or "?", tostring(a), tostring(a and HasAction(a)), tostring(k),
                tostring(b.icon and b.icon:GetTexture()), tostring(b:IsVisible()))
        end
    end
    Azaath.db.abDiag = d
end

function M:Build()
    -- uma vez só: os botões, a saída de veículo e a mochila têm nome global
    if self.built then return self:ApplyLayout() end
    self.built = true
    local db = self.db
    local count = math.max(1, math.min(#BAR_DEFS, db.bars or 3))

    local prev
    for i = 1, count do
        prev = CreateBar(BAR_DEFS[i], db, count)
    end
    -- Âncora das barras de postura/pet: a fileira mais alta da pilha
    -- (no "az" é a barra 2, que fica no topo; no "center", a última criada).
    self.mainBar = bars[1]
    if Azaath.IsAzLayout(db.layout) then
        self.topBar = bars[3] or bars[2] or bars[1]
    elseif Azaath.IsSplitLayout(db.layout) then
        self.topBar = (count >= 3 and bars[3]) or bars[2]
    else
        self.topBar = prev
    end
    bindOwner = bars[1]
    leaveButton = CreateLeaveButton(bars[1], db.buttonSize, Azaath.IsSixCols(db.layout))
    if Azaath.IsAzLayout(db.layout) and db.bagButton then
        bagButton = CreateBagButton(bars[1], db.buttonSize) -- à esquerda da fileira de baixo
    end

    -- Neutraliza os botões e a barra de veículo da Blizzard (já ocultos pelo HideBlizz).
    if Azaath.SilenceBlizzardActionBars then
        pcall(Azaath.SilenceBlizzardActionBars)
    end
    for _, prefix in ipairs(BLIZZARD_BUTTON_PREFIXES) do
        for i = 1, NUM_BUTTONS do
            local f = _G[prefix .. i]
            if f and f.UnregisterAllEvents then pcall(f.UnregisterAllEvents, f) end
        end
    end
    if Azaath.DisableBlizzardFrame then
        pcall(Azaath.DisableBlizzardFrame, "VehicleMenuBar")
    end

    UpdateSpellBookCache()
    ForEachButton(UpdateButton)
    self:UpdateBindings()

    Azaath.SafeRegister(events, "ACTIONBAR_SLOT_CHANGED")
    Azaath.SafeRegister(events, "UNIT_ENTERED_VEHICLE")
    Azaath.SafeRegister(events, "UNIT_EXITED_VEHICLE")
    for event in pairs(EVENT_HANDLERS) do
        Azaath.SafeRegister(events, event)
    end

    if IsBDOBar() then
        for _, e in ipairs({ "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
            "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR" }) do
            Azaath.SafeRegister(bdoProcEvents, e)
        end
    end

    events.elapsed = 0
    events.interval = math.max(0.1, db.rangeInterval or 0.2)
    events:SetScript("OnUpdate", MainTick)

    self:ApplyLayout()
    if C_Timer and C_Timer.After then
        C_Timer.After(1, RefreshAllButtons)
        C_Timer.After(4, function() RefreshAllButtons(); pcall(WriteBarDiag) end)
    end
end

function M:ApplyLayout()
    if not Azaath.HideBlizzOn("actionBars") then return end
    -- só depois do Build: barras criadas antes dele ficavam sem eventos nem atalhos
    if not self.built then return end
    if self.applyingLayout then return end
    self.applyingLayout = true
    Azaath:RunOutOfCombat(function()
        self.applyingLayout = false
        local db = self.db
        if not db then return end
        local count = math.max(1, math.min(#BAR_DEFS, db.bars or 3))

        for id = 1, count do
            if not bars[id] then
                CreateBar(BAR_DEFS[id], db, count)
            end
        end

        local prev
        for id = 1, #BAR_DEFS do
            local bar = bars[id]
            if bar then
                if not db.enabled or id > count then
                    UnregisterStateDriver(bar, "visibility")
                    bar:Hide()
                else
                    if IsAzaath() then
                        PlaceAzaathBar(bar, id)
                    elseif IsBDOBar() then
                        PlaceBDOBar(bar, id)
                    else
                    if bar.def.visibility then
                        RegisterStateDriver(bar, "visibility", bar.def.visibility)
                    else
                        bar:Show()
                    end
                    local size, cols, keyBox, point, rel, relPoint, x, y = BarGeometry(id, db, bars, count)
                    local bcfg = db["bar" .. id]
                    local barScale = db.scale or 1
                    if bcfg then
                        if bcfg.buttonSize and bcfg.buttonSize > 0 then size = bcfg.buttonSize end
                        if bcfg.cols and bcfg.cols > 0 then cols = bcfg.cols end
                        if bcfg.scale and bcfg.scale > 0 then barScale = bcfg.scale end
                        x = x + (bcfg.offsetX or 0)
                        y = y + (bcfg.offsetY or 0)
                    end

                    local spacing = db.spacing or 5
                    local displaySlots = NUM_BUTTONS
                    local rows = math.ceil(displaySlots / cols)
                    local rowStep = size + spacing + (keyBox and (KEYBOX_H + 3) or 0)

                    bar:SetScale(barScale > 0 and barScale or 1)
                    bar:SetWidth(cols * size + (cols - 1) * spacing)
                    bar:SetHeight(rows * rowStep - spacing)
                    bar:ClearAllPoints()
                    bar:SetPoint(point, rel, relPoint, x, y)
                    if Azaath.ClampToScreen then Azaath.ClampToScreen(bar) end

                    if bar.buttons then
                        for i, b in ipairs(bar.buttons) do
                            b:SetWidth(size)
                            b:SetHeight(size)
                            local r, c = math.floor((i - 1) / cols), (i - 1) % cols
                            b:ClearAllPoints()
                            b:SetPoint("TOPLEFT", bar, "TOPLEFT", c * (size + spacing), -r * rowStep)
                            if Azaath.IsSplitLayout(db.layout) then SplitSkinButton(b, size) end
                            if i <= displaySlots then
                                b:Show()
                            else
                                b:Hide()
                            end
                        end
                    end
                    if Azaath.IsSplitLayout(db.layout) then
                        SplitDeco(bar, size, spacing, id ~= 1)
                    elseif bar.splitDeco then
                        bar.splitDeco:Hide()
                    end

                    end -- não Azaath
                    prev = bar
                end
            end
        end

        self.mainBar = bars[1]
        if IsAzaath() or IsBDOBar() then
            self.topBar = bars[1] -- postura/pet acima do painel direito / dos direcionais
        elseif Azaath.IsSplitLayout(db.layout) then
            self.topBar = (count >= 3 and bars[3]) or bars[2]
        elseif Azaath.IsAzLayout(db.layout) then
            self.topBar = bars[3] or bars[2] or bars[1]
        else
            self.topBar = prev
        end

        if db.enabled and db.bagButton then
            if not bagButton and bars[1] then
                bagButton = CreateBagButton(bars[1], db.buttonSize or 42)
            end
            if bagButton then
                local bagCfg = db.bag or {}
                local bSize = (bagCfg.size and bagCfg.size > 0) and bagCfg.size or db.buttonSize or 42
                local d = bSize + 4
                bagButton:SetScale((bagCfg.scale and bagCfg.scale > 0) and bagCfg.scale or 1)
                bagButton:SetWidth(d)
                bagButton:SetHeight(d)
                if bagButton.icon then
                    bagButton.icon:SetWidth(bSize * 0.55)
                    bagButton.icon:SetHeight(bSize * 0.55)
                end
                bagButton:ClearAllPoints()
                bagButton:SetPoint("BOTTOMRIGHT", Azaath.root, "BOTTOMRIGHT", bagCfg.offsetX or -24, bagCfg.offsetY or 30)
                if Azaath.ClampToScreen then Azaath.ClampToScreen(bagButton) end
                bagButton:Show()
            end
        elseif bagButton then
            bagButton:Hide()
        end

        ForEachButton(UpdateButton)

        lastBindingSignature = nil
        self:UpdateBindings()

        local sp = Azaath:GetModule("StancePetBars")
        if sp and sp.ApplyLayout then sp:ApplyLayout() end
        local uf = Azaath:GetModule("UnitFrames")
        if uf and uf.ApplyLayout then uf:ApplyLayout() end
        local cb = Azaath:GetModule("CastBar")
        if cb and cb.ApplyLayout then cb:ApplyLayout() end
    end)
end

function M:OnEnable()
    if not self.db.enabled then return end
    if not Azaath.HideBlizzOn("actionBars") then
        -- Barras da Blizzard restauradas (/azaath blizz actionbars): não sobrepõe.
        return
    end
    -- Frames seguros só podem ser criados/posicionados fora de combate.
    if not Azaath:RunOutOfCombat(function() self:Build() end) then
        Azaath:Print("em combate: as barras de ação serão criadas ao sair do combate.")
    end
end
