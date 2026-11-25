--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Auras.lua
    Buffs e debuffs (3.3.5a).

      * Buffs do jogador: grade no canto superior direito (substitui o BuffFrame
        ocultado pelo HideBlizz), com encantamentos temporários de arma.
        Clique direito cancela o buff/encantamento.
      * Debuffs do jogador: linha centralizada acima da barra de conjuração
        (estilo Azaath: efeitos de status perto da vida), borda na cor do
        tipo (Magia/Maldição/Doença/Veneno) e espiral de duração.
      * Alvo: debuffs e depois buffs abaixo do frame do alvo. Debuffs de outros
        jogadores ficam esmaecidos; buffs roubáveis têm borda azul.

    Notas 3.3.5a:
      * UnitAura(unit, i, filter) -> name, rank, icon, count, debuffType,
        duration, expirationTime, unitCaster, isStealable, ...
      * Não existe SecureAuraHeaderTemplate (só na 4.0): os ícones são Buttons
        comuns. CancelUnitBuff/CancelItemTempEnchantment não são protegidas
        nesta versão, então o clique direito funciona sem frames seguros.
      * Um único timer (0.1s) atualiza os textos de tempo de todos os ícones
        visíveis; UNIT_AURA só reconstrói o grupo da unidade afetada.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("Auras")

local _G = _G
local pairs, tostring = pairs, tostring
local floor, min, format = math.floor, math.min, string.format
local GetTime, UnitExists = GetTime, UnitExists
local GetInventoryItemTexture = GetInventoryItemTexture

local TICK           = 0.1 -- atualização dos textos de tempo
local WEAPON_CHECK   = 1   -- consulta dos encantamentos de arma
local TIME_ROW       = 11  -- altura reservada para o tempo abaixo do ícone
local PLAYER_CASTERS = { player = true, pet = true, vehicle = true }

local WEAPON_BORDER    = { 0.62, 0.42, 0.88 }
local STEALABLE_BORDER = { 0.40, 0.75, 1.00 }
local DEBUFF_FALLBACK  = { r = 0.80, g = 0.00, b = 0.00 }

local containers = {}  -- lista de grupos
local byKey = {}       -- [key] = grupo
local weaponContainer  -- grupo que mostra encantamentos de arma
local lastWeaponSignature
local eventsRegistered = false

--------------------------------------------------------------------------------
-- Utilitários
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

local function FormatTime(s)
    if s >= 3600 then
        return format("%dh", floor(s / 3600 + 0.5))
    elseif s >= 60 then
        return format("%dm", floor(s / 60 + 0.5))
    elseif s >= 10 then
        return format("%d", s)
    end
    return format("%.1f", s)
end

local function CreateText(parent, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Azaath.media.font, size, "OUTLINE")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.7)
    return fs
end

--------------------------------------------------------------------------------
-- Ícones
--------------------------------------------------------------------------------
local function Icon_OnEnter(self)
    GameTooltip:SetOwner(self, self.container.tooltipAnchor)
    if self.slot then
        GameTooltip:SetInventoryItem("player", self.slot)
    elseif type(self.index) == "number" then
        -- o índice some quando a aura é limpa com o mouse em cima (ver UpdateIcons)
        pcall(GameTooltip.SetUnitAura, GameTooltip, self.container.unit, self.index, self.filter)
    else
        GameTooltip:Hide()
    end
end

local function Icon_OnLeave()
    GameTooltip:Hide()
end

local function Icon_OnClick(self, button)
    if button ~= "RightButton" or not self.container.cancelable then return end
    -- No cliente moderno, cancelar buff/encantamento é ação protegida
    -- (exigiria SecureAuraHeader). Lá o clique direito não faz nada.
    if not Azaath.API.CanCancelAuras then return end
    if self.slot then
        CancelItemTempEnchantment(self.slot == 16 and 1 or 2)
    elseif self.filter == "HELPFUL" then
        CancelUnitBuff("player", self.index, self.filter)
    end
end

local function CreateIcon(c, i)
    local cfg, colors = c.cfg, Azaath.colors
    local size = cfg.size

    local b = CreateFrame("Button", c:GetName() .. "Icon" .. i, c)
    b:SetWidth(size)
    b:SetHeight(size)
    Azaath.SetBackdrop(b, GetBackdrop())
    b:SetBackdropColor(colors.dark[1], colors.dark[2], colors.dark[3], 0.8)
    b:RegisterForClicks("RightButtonUp")
    b:SetScript("OnEnter", Icon_OnEnter)
    b:SetScript("OnLeave", Icon_OnLeave)
    b:SetScript("OnClick", Icon_OnClick)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.icon = icon

    local level = b:GetFrameLevel()
    if c.spiral then
        local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        cd:SetAllPoints(icon)
        cd:SetReverse(true) -- escurece conforme o tempo passa
        b.cd = cd
        level = cd:GetFrameLevel()
    end

    local textLayer = CreateFrame("Frame", nil, b)
    textLayer:SetAllPoints(b)
    textLayer:SetFrameLevel(level + 1)

    b.count = CreateText(textLayer, size >= 26 and 11 or 9)
    b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 2)
    b.count:SetTextColor(1, 1, 1)

    b.time = CreateText(textLayer, c.timeBelow and 10 or 9)
    if c.timeBelow then
        b.time:SetPoint("TOP", b, "BOTTOM", 0, -2)
        -- HUD Azaath: tempo numa plaquinha escura colada sob o ícone
        if c.timePlate and Azaath.CreateKeyBox then
            local plate = Azaath.CreateKeyBox(textLayer)
            plate:SetFrameLevel(math.max(0, textLayer:GetFrameLevel() - 1))
            plate:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 0, 1)
            plate:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 0, 1)
            plate:SetHeight(TIME_ROW + 3)
            if plate.mid then plate.mid:Show() end
            plate:Hide()
            b.timePlate = plate
            b.time:ClearAllPoints()
            b.time:SetPoint("CENTER", plate, "CENTER", 0, 0)
            -- HUD Azaath: acúmulos como "x3" logo acima do ícone
            b.count:ClearAllPoints()
            b.count:SetPoint("BOTTOM", b, "TOP", 0, 1)
            b.count:SetFont(Azaath.media.fontBold, 10, "OUTLINE")
            b.stackPrefix = true
        end
    else
        b.time:SetPoint("TOP", b, "TOP", 0, -1)
    end

    b.container = c
    b.expiration = 0
    b:Hide()
    c.icons[i] = b
    return b
end

local function GetIcon(c, i)
    return c.icons[i] or CreateIcon(c, i)
end

local function SetBorder(b, color, alpha)
    b:SetBackdropBorderColor(color[1] or color.r, color[2] or color.g, color[3] or color.b, alpha)
end

local function SetAura(c, b, index, filter, texture, count, debuffType, duration, expiration, caster, stealable)
    b.index, b.filter, b.slot = index, filter, nil
    b.icon:SetTexture(texture)
    -- Valores secretos (cliente moderno): sem contas => sem tempo/espiral;
    -- a contagem vai direto para o texto
    if Azaath.IsSecret(count) then
        if not (b.stackPrefix and pcall(b.count.SetFormattedText, b.count, "x%s", count)) then
            b.count:SetText(count)
        end
    elseif count and count > 1 then
        b.count:SetText(b.stackPrefix and ("x" .. count) or count)
    else
        b.count:SetText("")
    end
    if Azaath.AnySecret(duration, expiration) then
        duration, expiration = 0, 0
    end

    duration, expiration = duration or 0, expiration or 0
    b.expiration = (duration > 0) and expiration or 0
    if b.expiration == 0 then b.time:SetText("") end
    if b.timePlate then
        if b.expiration > 0 then b.timePlate:Show() else b.timePlate:Hide() end
    end
    if b.cd then
        if duration > 0 and expiration > 0 then
            b.cd:SetCooldown(expiration - duration, duration)
            b.cd:Show()
        else
            b.cd:Hide()
        end
    end

    if filter == "HARMFUL" then
        local col = (DebuffTypeColor and DebuffTypeColor[debuffType or "none"]) or DEBUFF_FALLBACK
        SetBorder(b, col, 0.95)
    elseif not Azaath.IsSecret(stealable) and stealable and c.unit ~= "player" then
        SetBorder(b, STEALABLE_BORDER, 0.95)
    else
        SetBorder(b, Azaath.colors.gold, 0.45)
    end

    if c.dimOthers and filter == "HARMFUL" and not PLAYER_CASTERS[caster or ""] then
        b.icon:SetDesaturated(true)
        b:SetAlpha(0.7)
    else
        b.icon:SetDesaturated(false)
        b:SetAlpha(1)
    end
    b:Show()
end

local function SetWeapon(b, slot, expirationMS, charges, now)
    b.index, b.filter, b.slot = nil, nil, slot
    b.icon:SetTexture(GetInventoryItemTexture("player", slot))
    b.icon:SetDesaturated(false)
    b:SetAlpha(1)
    if Azaath.IsSecret(charges) then
        b.count:SetText(charges)
    else
        b.count:SetText((charges and charges > 1) and charges or "")
    end
    if Azaath.IsSecret(expirationMS) then
        b.expiration = 0
    else
        b.expiration = (expirationMS and expirationMS > 0) and (now + expirationMS / 1000) or 0
    end
    if b.cd then b.cd:Hide() end
    if b.timePlate then
        if b.expiration > 0 then b.timePlate:Show() else b.timePlate:Hide() end
    end
    SetBorder(b, WEAPON_BORDER, 0.95)
    b:Show()
end

--------------------------------------------------------------------------------
-- Contêiner nativo de auras (cliente moderno)
-- Em combate o jogo bloqueia a leitura de auras por addons ("Auras cannot be
-- accessed when secret while tainted"): a consulta falhava e os ícones sumiam
-- ao entrar/sair de combate. Como nas placas de nome, o widget AuraContainer
-- lê e desenha as auras pelo próprio motor; aqui só definimos visual e posição.
-- Encantamentos de arma (que o widget não mostra) seguem com ícones do addon.
--------------------------------------------------------------------------------
local function NativeAvailable()
    return Azaath.IS_MODERN and _G.C_XMLUtil and C_XMLUtil.GetTemplateInfo
        and C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") and true or false
end

-- "12", "3m", "1h"; o formatador nativo aceita a duração secreta
local timeFormatter
local function TimeFormatter()
    if timeFormatter ~= nil then return timeFormatter or nil end
    timeFormatter = false
    if _G.C_StringUtil and C_StringUtil.CreateNumericRuleFormatter then
        local ok, fmt = pcall(C_StringUtil.CreateNumericRuleFormatter)
        if ok and fmt and pcall(function()
            fmt:AddBreakpoint({ threshold = 0, format = "" })
            fmt:AddBreakpoint({ threshold = 1, step = 1, format = "%d" })
            fmt:AddBreakpoint({ threshold = 60, format = "%dm", components = { { div = 60, step = 1 } } })
            fmt:AddBreakpoint({ threshold = 3600, format = "%dh", components = { { div = 3600, step = 1 } } })
        end) then
            timeFormatter = fmt
        end
    end
    return timeFormatter or nil
end

local function NativeButton_OnEnter(b)
    local c = b.azContainer
    GameTooltip:SetOwner(b, c.tooltipAnchor)
    local id
    if b.GetAuraInstanceID then
        local ok, v = pcall(b.GetAuraInstanceID, b)
        if ok then id = v end
    end
    id = id or b.auraInstanceID
    if id and GameTooltip.SetUnitAuraByAuraInstanceID then
        pcall(GameTooltip.SetUnitAuraByAuraInstanceID, GameTooltip, c.unit, id)
    end
    GameTooltip:Show()
end

local function StyleNativeButton(c, b, harmful)
    if b.azStyled then return end
    b.azStyled = true
    b.azContainer = c
    local size, colors = c.cfg.size, Azaath.colors
    b:SetSize(size, size)

    local edge = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    edge:SetAllPoints(b)
    local col = harmful and DEBUFF_FALLBACK or colors.gold
    edge:SetColorTexture(col[1] or col.r, col[2] or col.g, col[3] or col.b, harmful and 0.95 or 0.45)
    -- Azaath: filete claro de pedra (2 px), vão escuro e o ícone (como no conceito)
    local az = c.azaathStyle
    if az and not harmful then edge:SetColorTexture(0.62, 0.58, 0.50, 1) end
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetPoint("TOPLEFT", b, "TOPLEFT", az and 2 or 1, az and -2 or -1)
    bg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", az and -2 or -1, az and 2 or 1)
    bg:SetColorTexture(colors.dark[1], colors.dark[2], colors.dark[3], az and 1 or 0.8)

    local icon = b:CreateTexture(nil, "ARTWORK")
    local ii = az and 3 or 1
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", ii, -ii)
    icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -ii, ii)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b:SetIcon(icon)

    local level = b:GetFrameLevel()
    if c.spiral then
        local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        cd:SetAllPoints(icon)
        cd:SetDrawEdge(false)
        if cd.SetDrawBling then cd:SetDrawBling(false) end
        cd:SetHideCountdownNumbers(true)
        cd:SetReverse(true)
        cd.noCooldownCount = true
        if cd.EnableMouse then cd:EnableMouse(false) end
        pcall(b.SetDurationCooldown, b, cd)
        level = cd:GetFrameLevel()
    end

    local texts = CreateFrame("Frame", nil, b)
    texts:SetAllPoints(b)
    texts:SetFrameLevel(level + 2)

    local timer = CreateText(texts, c.timeBelow and 10 or 9)
    if az then
        timer:SetFont(Azaath.media.fontCardR or Azaath.media.font, 13, "")
        timer:SetShadowOffset(1, -1)
        timer:SetShadowColor(0, 0, 0, 0.9)
    end
    if c.timeBelow then
        timer:SetPoint("TOP", b, "BOTTOM", 0, az and -3 or -2)
    else
        timer:SetPoint("TOP", b, "TOP", 0, -1)
    end
    local cream = az and { 0.84, 0.84, 0.82 } or colors.cream
    timer:SetTextColor(cream[1], cream[2], cream[3])
    local fmt = TimeFormatter()
    if not (fmt and pcall(b.SetDurationText, b, timer, { textFormatter = fmt })) then
        timer:Hide()
    end

    local count = CreateText(texts, size >= 26 and 11 or 9)
    if c.timePlate then
        count:SetFont(Azaath.media.fontBold, 10, "OUTLINE")
        count:SetPoint("BOTTOM", b, "TOP", 0, 1)
    else
        count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 2)
    end
    count:SetTextColor(1, 1, 1)
    pcall(b.SetApplicationCount, b, count)

    if b.EnableMouse then b:EnableMouse(true) end
    pcall(b.SetScript, b, "OnEnter", NativeButton_OnEnter)
    pcall(b.SetScript, b, "OnLeave", Icon_OnLeave)
end

local function NativeGroupLayout(c)
    local cfg = c.cfg
    local sp = cfg.spacing or 4
    return {
        elementSpacing = sp, lineSpacing = sp + (c.timeBelow and TIME_ROW or 0),
        groupSpacing = sp, groupLineSpacing = sp + (c.timeBelow and TIME_ROW or 0),
        elementWidth = cfg.size, elementHeight = cfg.size,
    }
end

local function CreateNative(c)
    local nc = CreateFrame("AuraContainer", nil, c, "CustomAuraContainerTemplate")
    nc:SetSize(1, 1)
    local sortMethod = _G.AuraContainerSortMethod
    local layout = NativeGroupLayout(c)
    c.nativeGroups = {}
    for gi, filter in ipairs(c.filters) do
        local harmful = filter:find("HARMFUL", 1, true) ~= nil
        if harmful and c.onlyMine then filter = "HARMFUL|PLAYER" end
        local name = "g" .. gi
        nc:AddAuraGroup(name, filter, {
            maxFrameCount = c.cfg.max or 16,
            sortMethod = sortMethod and (sortMethod.Default or sortMethod.Expiration) or 0,
            sortDirection = _G.AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0,
            initializeFrame = function(b) StyleNativeButton(c, b, harmful) end,
            layout = layout,
        })
        nc:SetAuraGroupLayout(name, layout)
        c.nativeGroups[#c.nativeGroups + 1] = name
    end
    nc:SetUnit(c.unit)
    nc:SetEnabled(false)
    nc:Show()
    return nc
end

-- Direção do fluxo e geometria (chamado no ApplyLayout)
local function ConfigureNative(c)
    local nc = c.native
    if not nc then return end
    local flow = _G.AnchorUtil and AnchorUtil.FlowDirection or { Right = 1, Left = 2, Up = 1, Down = 2 }
    local layout = NativeGroupLayout(c)
    for _, g in ipairs(c.nativeGroups) do pcall(nc.SetAuraGroupLayout, nc, g, layout) end
    if c.centered then
        if c.centeredDown then
            nc:SetFlowLayoutAnchorPoint("TOPLEFT")
            nc:SetFlowLayoutGrowthDirection(flow.Right, flow.Down)
        else
            nc:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
            nc:SetFlowLayoutGrowthDirection(flow.Right, flow.Up)
        end
    else
        nc:SetFlowLayoutAnchorPoint(c.point)
        nc:SetFlowLayoutGrowthDirection(c.growX < 0 and flow.Left or flow.Right,
            c.growY < 0 and flow.Down or flow.Up)
    end
    local cfg = c.cfg
    local step = (cfg.size or 30) + (cfg.spacing or 4)
    nc:SetFlowLayoutMaximumLineSize(math.max(1, (cfg.perRow or 10) - (c.numShown or 0)) * step)
    -- re-estiliza o tamanho dos botões já criados
    local kids = { nc:GetChildren() }
    for i = 1, #kids do
        if kids[i].azStyled then kids[i]:SetSize(cfg.size, cfg.size) end
    end
    -- força o AuraContainer a recalcular o FlowLayout apenas quando a geometria/configuração mudar
    local cfgSig = format("%s:%s:%s:%s:%s:%s:%s:%s:%s",
        tostring(cfg.size), tostring(cfg.spacing), tostring(cfg.perRow),
        tostring(c.point), tostring(c.growX), tostring(c.growY),
        tostring(c.centered), tostring(c.centeredDown), tostring(c.onlyMine))
    if c._nativeCfgSig ~= cfgSig then
        c._nativeCfgSig = cfgSig
        nc:SetEnabled(false)
        nc:SetEnabled(true)
        if nc.MarkDirty then pcall(nc.MarkDirty, nc) end
    end
    c.nativeSig = nil
end

-- Posiciona o widget nativo logo depois dos ícones do addon (armas/prévia).
-- Não dá para centralizar pela quantidade: a visibilidade dos botões do
-- widget é secreta (IsShown => booleano secreto). Nos grupos "centralizados"
-- a fileira começa na borda esquerda da área (largura = perRow ícones),
-- que já é centralizada na HUD.
local function PositionNative(c)
    local nc = c.native
    if not nc then return end
    local cfg = c.cfg
    local size, spacing, perRow = cfg.size, cfg.spacing, cfg.perRow
    local step = size + spacing
    local own = c.numShown or 0
    local sig = tostring(own)
    if sig == c.nativeSig then return end
    c.nativeSig = sig

    nc:SetFlowLayoutMaximumLineSize(math.max(1, perRow - own) * step)
    nc:ClearAllPoints()
    if c.centered then
        local vert = c.centeredDown and "TOP" or "BOTTOM"
        for i = 1, own do
            local b = c.icons[i]
            b:ClearAllPoints()
            b:SetPoint(vert .. "LEFT", c, vert .. "LEFT", (i - 1) * step, 0)
        end
        nc:SetPoint(vert .. "LEFT", c, vert .. "LEFT", own * step, 0)
    else
        nc:SetPoint(c.point, c, c.point, own * step * c.growX, 0)
    end
end

--------------------------------------------------------------------------------
-- Layout e atualização de um grupo
--------------------------------------------------------------------------------
local function Layout(c, n)
    if c.native and c.centered then
        c.laidOut = nil
        c.nativeSig = nil
        PositionNative(c)
        return
    end
    if n == c.laidOut then return end
    c.laidOut = n

    local cfg = c.cfg
    local size, spacing, perRow = cfg.size, cfg.spacing, cfg.perRow
    local step = size + spacing
    local rowHeight = size + spacing + (c.timeBelow and TIME_ROW or 0)

    for i = 1, n do
        local b = c.icons[i]
        local row = floor((i - 1) / perRow)
        local col = (i - 1) % perRow
        b:ClearAllPoints()
        if c.centered then
            -- cada linha centralizada; linhas extras crescem para cima
            -- (ou para baixo, com centeredDown: debuffs sob a HUD)
            local inRow = min(perRow, n - row * perRow)
            local rowWidth = inRow * size + (inRow - 1) * spacing
            if c.centeredDown then
                b:SetPoint("TOPLEFT", c, "TOP", -rowWidth / 2 + col * step, -row * rowHeight)
            else
                b:SetPoint("BOTTOMLEFT", c, "BOTTOM", -rowWidth / 2 + col * step, row * rowHeight)
            end
        else
            b:SetPoint(c.point, c, c.point, col * step * c.growX, row * rowHeight * c.growY)
        end
    end
    if c.native then
        c.nativeSig = nil
        PositionNative(c)
    end
end

local function AddWeaponEnchants(c, n, now)
    local hasMain, mainExp, mainCharges, hasOff, offExp, offCharges = Azaath.API.GetWeaponEnchantInfo()
    if hasMain then
        n = n + 1
        SetWeapon(GetIcon(c, n), 16, mainExp, mainCharges, now)
    end
    if hasOff then
        n = n + 1
        SetWeapon(GetIcon(c, n), 17, offExp, offCharges, now)
    end
    return n
end

local PREVIEW_ICONS = {
    "Interface\\Icons\\Spell_Nature_Regeneration",
    "Interface\\Icons\\Spell_Holy_WordFortitude",
    "Interface\\Icons\\Spell_Shadow_ShadowWordPain",
    "Interface\\Icons\\Ability_Warrior_BattleShout",
}

local function UpdateContainer(c)
    local n, maxIcons = 0, c.cfg.max
    local unit = c.unit

    if UnitExists(unit) then
        if c.weapon then
            local ok, res = pcall(AddWeaponEnchants, c, n, GetTime())
            if ok then
                n = res
            elseif Azaath.LogError then
                Azaath.LogError("AzaathUI Auras(weapon): " .. tostring(res))
            end
        end
        for f = 1, (c.native and 0 or #c.filters) do
            local filter = c.filters[f]
            local i = 1
            while n < maxIcons do
                local name, texture, count, debuffType, duration, expiration, caster, stealable =
                    Azaath.API.UnitAura(unit, i, filter)
                if not name then break end
                if not (c.onlyMine and filter == "HARMFUL" and not PLAYER_CASTERS[caster or ""]) then
                    -- uma aura problemática (valor secreto inesperado) não pode
                    -- interromper a lista inteira: pula só ela e anota o erro
                    local ok, err = pcall(SetAura, c, GetIcon(c, n + 1), i, filter, texture, count,
                        debuffType, duration, expiration, caster, stealable)
                    if ok then
                        n = n + 1
                    elseif Azaath.LogError then
                        Azaath.LogError("AzaathUI Auras(" .. tostring(c.key) .. "): " .. tostring(err))
                    end
                end
                i = i + 1
            end
        end
    end

    if n == 0 and M.editing then
        local sampleCount = math.min(4, c.cfg.perRow or 4, maxIcons or 4)
        local isHarm = (c.filters[1] == "HARMFUL")
        for i = 1, sampleCount do
            n = n + 1
            local b = GetIcon(c, n)
            b.index, b.filter, b.slot = nil, nil, nil
            b.icon:SetTexture(PREVIEW_ICONS[((i - 1) % #PREVIEW_ICONS) + 1])
            b.icon:SetDesaturated(false)
            b:SetAlpha(0.85)
            b.count:SetText(i > 1 and tostring(i) or "")
            b.expiration = 0
            b.time:SetText("12s")
            if b.timePlate then b.timePlate:Show() end
            if b.cd then b.cd:Hide() end
            SetBorder(b, isHarm and DEBUFF_FALLBACK or Azaath.colors.gold, isHarm and 0.90 or 0.55)
            b:Show()
        end
    end

    for i = n + 1, #c.icons do
        c.icons[i]:Hide()
        c.icons[i].expiration = 0
    end
    c.numShown = n
    Layout(c, n)

    -- Mantém o tooltip correto se o mouse estiver sobre um ícone que mudou
    for i = 1, n do
        local b = c.icons[i]
        if GameTooltip:IsOwned(b) then Icon_OnEnter(b) end
    end
end

local function WeaponSignature()
    local hasMain, _, mainCharges, hasOff, _, offCharges = Azaath.API.GetWeaponEnchantInfo()
    -- cargas secretas não podem ir para a assinatura (seria comparar segredo)
    if Azaath.IsSecret(mainCharges) then mainCharges = "?" end
    if Azaath.IsSecret(offCharges) then offCharges = "?" end
    return tostring(hasMain) .. tostring(mainCharges) .. tostring(hasOff) .. tostring(offCharges)
end

--------------------------------------------------------------------------------
-- Criação de grupos
--------------------------------------------------------------------------------
-- opts: unit, filters, parent, point/relPoint/anchor/x/y, centered, growX, growY,
--       timeBelow, spiral, weapon, cancelable, dimOthers, onlyMine, tooltipAnchor
local function CreateContainer(key, name, cfg, opts)
    local c = CreateFrame("Frame", name, opts.parent or Azaath.root)
    c:SetFrameStrata("LOW")
    local scale = (cfg.scale and cfg.scale > 0) and cfg.scale or 1
    if (key == "playerBuffs" or key == "playerDebuffs") and Azaath.IsAzaath and Azaath.IsAzaath() then
        local hud = Azaath.GetAzaathFrame and Azaath.GetAzaathFrame()
        if hud then scale = hud:GetScale() end
    end
    c:SetScale(scale)
    c:SetWidth(cfg.perRow * (cfg.size + cfg.spacing) - cfg.spacing)
    c:SetHeight(cfg.size)
    c:SetPoint(opts.point, opts.anchor, opts.relPoint, opts.x or 0, opts.y or 0)

    c.key = key
    c.cfg = cfg
    c.icons = {}
    c.numShown = 0
    for k, v in pairs(opts) do
        if k ~= "parent" and k ~= "anchor" and k ~= "relPoint" and k ~= "x" and k ~= "y" then
            c[k] = v
        end
    end
    c.growX = c.growX or 1
    c.growY = c.growY or -1

    if NativeAvailable() then
        local ok, nc = pcall(CreateNative, c)
        if ok then
            c.native = nc
        elseif Azaath.LogError then
            Azaath.LogError("AzaathUI Auras AuraContainer(" .. key .. "): " .. tostring(nc))
        end
    end

    containers[#containers + 1] = c
    byKey[key] = c
    if c.weapon then weaponContainer = c end
    return c
end

--------------------------------------------------------------------------------
-- Eventos e timer
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_AURA" then
        for i = 1, #containers do
            local c = containers[i]
            if c.unit == unit then UpdateContainer(c) end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        for i = 1, #containers do
            local c = containers[i]
            if c.unit == "target" then
                if c.native then
                    pcall(c.native.SetUnit, c.native, "target")
                    -- trocar direto de um alvo para outro não esconde o grupo: esconder e mostrar recarrega a lista
                    if c:IsShown() then
                        c:Hide()
                        c:Show()
                    end
                end
                UpdateContainer(c)
            end
        end
    elseif event == "UNIT_INVENTORY_CHANGED" then
        if unit == "player" and weaponContainer then
            lastWeaponSignature = WeaponSignature()
            UpdateContainer(weaponContainer)
        end
    elseif event == "PLAYER_ENTERING_WORLD" then
        for i = 1, #containers do UpdateContainer(containers[i]) end
    end
end)

local function Ticker(self, elapsed)
    self.elapsed = (self.elapsed or 0) + (elapsed or 0)
    if self.elapsed < TICK then return end
    local dt = self.elapsed
    self.elapsed = 0

    local now = GetTime()
    local cream = Azaath.colors.cream
    for ci = 1, #containers do
        local c = containers[ci]
        if c:IsVisible() then
            if c.native then PositionNative(c) end
            for i = 1, c.numShown do
                local b = c.icons[i]
                if b.expiration > 0 then
                    local left = b.expiration - now
                    if left > 0 then
                        b.time:SetText(FormatTime(left))
                        if left < 5 then
                            b.time:SetTextColor(1, 0.35, 0.25)
                        else
                            b.time:SetTextColor(cream[1], cream[2], cream[3])
                        end
                    else
                        b.time:SetText("")
                    end
                end
            end
        end
    end

    -- Rede de segurança (1s): reconstrói os grupos do jogador. O UNIT_AURA do
    -- motor 12.x às vezes chega antes dos dados ou em lote, e os buffs ficavam
    -- faltando até a próxima mudança. Também cobre encantamentos de arma, que
    -- não disparam evento ao expirar/perder cargas.
    self.weaponElapsed = self.weaponElapsed + dt
    if self.weaponElapsed >= WEAPON_CHECK then
        self.weaponElapsed = 0
        local weaponDone = false
        for ci = 1, #containers do
            local c = containers[ci]
            if c.unit == "player" and c:IsShown() then
                UpdateContainer(c)
                if c == weaponContainer then weaponDone = true end
            end
        end
        if weaponContainer and not weaponDone then
            local sig = WeaponSignature()
            if sig ~= lastWeaponSignature then
                lastWeaponSignature = sig
                UpdateContainer(weaponContainer)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
local function EnsureAuraEvents()
    if eventsRegistered then return end
    eventsRegistered = true
    Azaath.SafeRegister(events, "UNIT_AURA")
    Azaath.SafeRegister(events, "PLAYER_TARGET_CHANGED")
    Azaath.SafeRegister(events, "PLAYER_ENTERING_WORLD")
    Azaath.SafeRegister(events, "UNIT_INVENTORY_CHANGED")
    events.elapsed, events.weaponElapsed = 0, 0
    events:SetScript("OnUpdate", Ticker)
end

local function RefreshContainerGeometry(c)
    local cfg = c.cfg
    local size = cfg.size or 30
    local spacing = cfg.spacing or 4
    local perRow = cfg.perRow or 10
    local scale = (cfg.scale and cfg.scale > 0) and cfg.scale or 1
    if (c.key == "playerBuffs" or c.key == "playerDebuffs") and Azaath.IsAzaath and Azaath.IsAzaath() then
        local hud = Azaath.GetAzaathFrame and Azaath.GetAzaathFrame()
        if hud then scale = hud:GetScale() end
    end
    c:SetScale(scale)
    c:SetWidth(perRow * (size + spacing) - spacing)
    c:SetHeight(size)
    for i = 1, #c.icons do
        local b = c.icons[i]
        b:SetWidth(size)
        b:SetHeight(size)
    end
    c.laidOut = nil
end

function M:ApplyLayout()
    local db = self.db
    if not db then return end
    local playerAurasAllowed = Azaath.db.hideBlizzard.buffs

    -- 1. Player Buffs
    if db.playerBuffs.enabled and playerAurasAllowed and not byKey.playerBuffs then
        local cfg = db.playerBuffs
        local minimap = _G.AzaathUIMinimap
        CreateContainer("playerBuffs", "AzaathUIPlayerBuffs", cfg, {
            unit = "player", filters = { "HELPFUL" },
            point = "TOPRIGHT",
            anchor = minimap or Azaath.root,
            relPoint = minimap and "TOPLEFT" or "TOPRIGHT",
            x = minimap and -(minimap.leftPad or 24) or (cfg.offsetX or -12),
            y = minimap and 0 or (cfg.offsetY or -52),
            growX = -1, growY = -1, timeBelow = true, spiral = false,
            timePlate = Azaath.IsHudLayout and Azaath.IsHudLayout() or nil,
            azaathStyle = Azaath.IsAzaath and Azaath.IsAzaath() or nil,
            weapon = cfg.weaponEnchants, cancelable = true,
            tooltipAnchor = "ANCHOR_BOTTOMLEFT",
        })
    end
    if byKey.playerBuffs then
        local c = byKey.playerBuffs
        local cfg = db.playerBuffs
        c.cfg = cfg
        c.weapon = cfg.weaponEnchants
        c.timePlate = Azaath.IsHudLayout and Azaath.IsHudLayout() or nil
        c.azaathStyle = Azaath.IsAzaath and Azaath.IsAzaath() or nil
        weaponContainer = cfg.weaponEnchants and c or nil
        if not (cfg.enabled and playerAurasAllowed) then
            c:Hide()
        else
            c:Show()
            RefreshContainerGeometry(c)
            c:ClearAllPoints()
            local minimap = _G.AzaathUIMinimap
            local pf = _G.AzaathUIPlayer
            local hudAnchor = Azaath.IsHudLayout and Azaath.IsHudLayout() and pf and pf:IsShown() and pf
            local azaath = Azaath.AzaathAnchor and Azaath.AzaathAnchor("buffs")
            c.centered = (hudAnchor and not azaath) and true or nil
            c.laidOut = nil
            if azaath then
                -- Azaath: fileira da esquerda para a direita sobre a moldura central (presa à HUD)
                c.point, c.growX, c.growY = "BOTTOMLEFT", 1, 1
                c:SetPoint("BOTTOMLEFT", azaath, "BOTTOMLEFT", 0, 0)
            elseif hudAnchor then
                -- HUD Azaath: fileira centralizada logo acima da placa de vida/recurso
                c:SetPoint("BOTTOM", hudAnchor, "TOP", cfg.offsetX or 0, 10 + TIME_ROW + (cfg.offsetY or 0))
            elseif Azaath.IsBDO and Azaath.IsBDO() then
                -- Black Desert: mesma caixa na tela, mas os ícones enchem da esquerda para a direita
                c.point, c.growX, c.growY = "TOPLEFT", 1, -1
                local w = c:GetWidth()
                if minimap then
                    c:SetPoint("TOPLEFT", minimap, "TOPLEFT", -(minimap.leftPad or 24) - w + (cfg.offsetX or 0), cfg.offsetY or 0)
                else
                    c:SetPoint("TOPLEFT", Azaath.root, "TOPRIGHT", -220 - w + (cfg.offsetX or 0), -24 + (cfg.offsetY or 0))
                end
            elseif minimap then
                -- leftPad: o pergaminho do minimapa Classic avança à esquerda do mapa
                c:SetPoint("TOPRIGHT", minimap, "TOPLEFT", -(minimap.leftPad or 24) + (cfg.offsetX or 0), cfg.offsetY or 0)
            else
                c:SetPoint("TOPRIGHT", Azaath.root, "TOPRIGHT", -220 + (cfg.offsetX or 0), -24 + (cfg.offsetY or 0))
            end
            if Azaath.ClampToScreen then
                Azaath.ClampToScreen(c, { left = 2, right = 2, top = 2, bottom = c.timeBelow and (TIME_ROW + 2) or 2 })
            end
            pcall(ConfigureNative, c)
            UpdateContainer(c)
        end
    end

    -- 2. Player Debuffs
    if db.playerDebuffs.enabled and playerAurasAllowed and not byKey.playerDebuffs then
        local cfg = db.playerDebuffs
        local anchor = _G.AzaathUICastBarPlayer or _G.AzaathUIPlayer
        CreateContainer("playerDebuffs", "AzaathUIPlayerDebuffs", cfg, {
            unit = "player", filters = { "HARMFUL" },
            point = "BOTTOM", anchor = anchor or Azaath.root, relPoint = anchor and "TOP" or "BOTTOM",
            y = anchor and (8 + TIME_ROW) or 250,
            centered = true, timeBelow = true, spiral = true,
            timePlate = Azaath.IsHudLayout and Azaath.IsHudLayout() or nil,
            azaathStyle = Azaath.IsAzaath and Azaath.IsAzaath() or nil,
            tooltipAnchor = "ANCHOR_TOP",
        })
    end
    if byKey.playerDebuffs then
        local c = byKey.playerDebuffs
        local cfg = db.playerDebuffs
        c.cfg = cfg
        c.timePlate = Azaath.IsHudLayout and Azaath.IsHudLayout() or nil
        c.azaathStyle = Azaath.IsAzaath and Azaath.IsAzaath() or nil
        if not (cfg.enabled and playerAurasAllowed) then
            c:Hide()
        else
            c:Show()
            RefreshContainerGeometry(c)
            c:ClearAllPoints()
            local pf = _G.AzaathUIPlayer
            local anchor = _G.AzaathUICastBarPlayer or (pf and pf:IsShown() and pf)
            local hudAnchor = Azaath.IsHudLayout and Azaath.IsHudLayout() and pf and pf:IsShown() and pf
            local azaath = Azaath.AzaathAnchor and Azaath.AzaathAnchor("debuffs")
            c.centeredDown = (hudAnchor and not azaath) and true or nil
            c.laidOut = nil
            if azaath then
                -- Azaath: à direita da crista central, crescendo para a direita (presa à HUD)
                c.point, c.growX, c.growY = "BOTTOMLEFT", 1, 1
                c:SetPoint("BOTTOMLEFT", azaath, "BOTTOMLEFT", 0, 0)
            elseif hudAnchor then
                -- HUD Azaath: fileira centralizada abaixo do losango de nível/XP, crescendo para baixo
                c:SetPoint("TOP", hudAnchor, "BOTTOM", cfg.offsetX or 0, -40 + (cfg.offsetY or 0))
            elseif anchor then
                c:SetPoint("BOTTOM", anchor, "TOP", cfg.offsetX or 0, (cfg.offsetY or 18) + TIME_ROW)
            else
                c:SetPoint("BOTTOM", Azaath.root, "BOTTOM", cfg.offsetX or 0, 150 + (cfg.offsetY or 0))
            end
            if Azaath.ClampToScreen then
                Azaath.ClampToScreen(c, { left = 2, right = 2, top = 2, bottom = c.timeBelow and (TIME_ROW + 2) or 2 })
            end
            pcall(ConfigureNative, c)
            UpdateContainer(c)
        end
    end

    -- 3. Target Auras. Skin Zerker: buffs acima do quadro e debuffs abaixo das barras; os dois ficam
    -- presos à tela (não ao quadro de alvo do Azaath, que nessa skin é invisível)
    local zerker = Azaath.IsBDO and Azaath.IsBDO() and true or false
    -- skin Zerker: os grupos são filhos do quadro Zerker (aparecem e somem com o alvo, e o contêiner nativo recarrega)
    local holder = zerker and _G.AzaathUIBDOTarget or nil
    if zerker and db.target.enabled and not byKey.targetBuffs then
        local cfg = db.target
        CreateContainer("targetBuffs", "AzaathUITargetBuffs", cfg, {
            unit = "target", filters = { "HELPFUL" },
            parent = holder,
            point = "BOTTOMLEFT", anchor = Azaath.root, relPoint = "TOP", x = -140, y = -110,
            growX = 1, growY = 1, timeBelow = false, spiral = true,
            dimOthers = false, onlyMine = false,
            tooltipAnchor = "ANCHOR_TOPRIGHT",
        })
    end
    -- skin Blizzard: o quadro de alvo do jogo já mostra as auras dele
    local targetOn = db.target.enabled and Azaath.HideBlizzOn("targetFrame")   -- (o da Blizzard já tem as auras dele)
    if targetOn and not byKey.target then
        local cfg = db.target
        local targetFrame = _G.AzaathUITarget
        CreateContainer("target", "AzaathUITargetAuras", cfg, {
            unit = "target", filters = zerker and { "HARMFUL" } or { "HARMFUL", "HELPFUL" },
            parent = zerker and (holder or Azaath.root) or targetFrame,
            point = "TOPLEFT",
            anchor = targetFrame or Azaath.root,
            relPoint = targetFrame and "BOTTOMLEFT" or "TOP",
            x = targetFrame and 0 or -140,
            y = targetFrame and cfg.offsetY or -140,
            growX = 1, growY = -1, timeBelow = false, spiral = true,
            dimOthers = true, onlyMine = cfg.onlyMine,
            tooltipAnchor = "ANCHOR_BOTTOMRIGHT",
        })
    end
    if byKey.target then
        local c = byKey.target
        local cfg = db.target
        c.cfg = cfg
        c.onlyMine = cfg.onlyMine
        if not cfg.enabled then
            c:Hide()
        else
            c:Show()
            RefreshContainerGeometry(c)
            c:ClearAllPoints()
            if zerker then
                local th = _G.AzaathUIBDOTarget
                if th and c:GetParent() ~= th then c:SetParent(th) end
            end
            local targetFrame = (zerker and _G.AzaathUIBDOTarget) or _G.AzaathUITarget
            if targetFrame then
                -- skin Zerker: sob as barras do quadro (à direita do losango), logo abaixo do recurso
                local bz = Azaath.IsBDO and Azaath.IsBDO() and Azaath.BDOTargetBox
                c:SetPoint("TOPLEFT", targetFrame, "BOTTOMLEFT", (cfg.offsetX or 0) + (bz and bz.barX or 0), (cfg.offsetY or -26) + (bz and bz.gap or 0))
            else
                c:SetPoint("TOP", Azaath.root, "TOP", cfg.offsetX or 0, -140 + (cfg.offsetY or 0))
            end
            if Azaath.ClampToScreen then Azaath.ClampToScreen(c, 2) end
            pcall(ConfigureNative, c)
            UpdateContainer(c)
        end
    end

    if byKey.targetBuffs then
        local c = byKey.targetBuffs
        local cfg = db.target
        c.cfg = cfg
        c.onlyMine = false
        if not (zerker and cfg.enabled) then
            c:Hide()
        else
            c:Show()
            RefreshContainerGeometry(c)
            c:ClearAllPoints()
            local th = _G.AzaathUIBDOTarget
            if th and c:GetParent() ~= th then c:SetParent(th) end
            local tf, bz = th or _G.AzaathUITarget, Azaath.BDOTargetBox
            if tf and bz then
                c:SetPoint("BOTTOMLEFT", tf, "TOPLEFT", bz.barX, 6)
            else
                c:SetPoint("BOTTOMLEFT", Azaath.root, "TOP", -140, -110)
            end
            if Azaath.ClampToScreen then Azaath.ClampToScreen(c, 2) end
            pcall(ConfigureNative, c)
            UpdateContainer(c)
        end
    end

    if #containers > 0 then
        EnsureAuraEvents()
    end
end

function M:SetEditing(editing)
    self.editing = editing and true or false
    for i = 1, #containers do
        UpdateContainer(containers[i])
    end
end

function M:OnInitialize()
    self.db = Azaath.db.auras
end

function M:OnEnable()
    self:ApplyLayout()
end
