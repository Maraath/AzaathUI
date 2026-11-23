--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates.lua
    Placas de nome dos inimigos (barras sobre a cabeça) no estilo Azaath.

      * Usa a barra de inimigo Azaath de UnitFrames (Azaath.AzBar): nome em serifa
        espaçada, barra fina vermelha com degradê, losango do nível, moldura
        com pontas em pincel quando o inimigo está em combate/ferido, flash
        branco no dano e asas de prata (raro) ou ouro (elite/chefe).
      * Efeitos sobre o inimigo (debuffs e depois buffs, de qualquer origem:
        seus e dos aliados) em ícones pequenos acima do nome.
      * Jogadores aliados: losango preto com o nível e o nome ao lado; em
        combate (ou ferido) aparece uma barra branca fina saindo do losango,
        com o nome em cima, e o pedaço de vida perdido some em cinza.
      * Pets amigos (o seu e os dos aliados): a mesma placa de aliado, menor.
      * NPCs amigáveis continuam com a placa da Blizzard.

    Efeitos em combate (cliente com valores secretos):
      * Addons não podem ler efeitos de inimigos em combate ("Auras cannot be
        accessed when secret while tainted"). Como o BetterNamePlates e o
        MFNameplates, usamos o widget nativo AuraContainer
        (CustomAuraContainerTemplate): o próprio motor do jogo escolhe, ordena
        e desenha os efeitos da unidade; o addon só define filtros, layout e o
        visual de cada ícone (initializeFrame). Nada de UNIT_AURA.
      * A placa da Blizzard (plate.UnitFrame) fica com alpha 0, com gancho em
        SetAlpha para não voltar (mesmo método dos dois addons).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("Nameplates")

local _G = _G
local pairs, ipairs, pcall = pairs, ipairs, pcall
local floor, max = math.floor, math.max
local GetTime = GetTime

local cfg
local active = {}   -- [unit] = barra Azaath ligada a uma placa
local pool = {}        -- barras de inimigo livres para reaproveitar
local allyPool = {}    -- placas de aliado livres
local utilityPool = {} -- placas de NPCs utilitários livres
local holder        -- pai oculto das barras livres
local hovered       -- barra de inimigo com o mouse em cima
local IsQuestUnit
local UpdateUtilityPlates

local DEBUFF_BORDER = { 0.55, 0.06, 0.05 }
local BUFF_BORDER   = { 0.79, 0.66, 0.42 }

-- API da barra de inimigo: skin Zerker usa a placa BDO (BDOHUD.lua), as demais a barra Azaath
-- Estilo das placas de inimigo (opção nameplates.style): "azaath" | "zerker" | "minimal";
-- "auto" segue a skin (Zerker = minimalista, demais = Azaath). Trocar exige /reload.
function Azaath.PlateStyle()
    local s = Azaath.db and Azaath.db.nameplates and Azaath.db.nameplates.style or "auto"
    if s == "azaath" or s == "zerker" or s == "minimal" then return s end
    return (Azaath.IsBDO and Azaath.IsBDO()) and "minimal" or "azaath"
end
local function E()
    if Azaath.BDOPlate and Azaath.PlateStyle() ~= "azaath" then return Azaath.BDOPlate end
    return Azaath.AzBar
end

--------------------------------------------------------------------------------
-- Placa da Blizzard
--------------------------------------------------------------------------------
local function GetPlate(unit)
    if not (_G.C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok then return plate end
end

local suppressed = {}   -- [UnitFrame da Blizzard] = alpha original enquanto escondido
local hooked = {}       -- [UnitFrame da Blizzard] = true depois do gancho
local settingAlpha = {} -- guarda de reentrância ao forçar SetAlpha(0)

local function KeepHidden(uf)
    if suppressed[uf] == nil or settingAlpha[uf] then return end
    settingAlpha[uf] = true
    uf:SetAlpha(0)
    settingAlpha[uf] = nil
end

local function HideBlizzard(plate)
    local uf = plate and plate.UnitFrame
    if not uf then return end
    if not hooked[uf] then
        hooked[uf] = true
        hooksecurefunc(uf, "SetAlpha", KeepHidden)
        if uf.SetAlphaFromBoolean then
            hooksecurefunc(uf, "SetAlphaFromBoolean", KeepHidden)
        end
        if uf.Show then
            hooksecurefunc(uf, "Show", KeepHidden)
        end
        if uf.HookScript then
            pcall(uf.HookScript, uf, "OnShow", KeepHidden)
        end
    end
    if suppressed[uf] == nil then
        local a = uf:GetAlpha()
        suppressed[uf] = (not Azaath.IsSecret(a) and a and a > 0) and a or 1
    end
    KeepHidden(uf)
end

local function ShowBlizzard(plate)
    local uf = plate and plate.UnitFrame
    local alpha = uf and suppressed[uf]
    if alpha ~= nil then
        suppressed[uf] = nil
        uf:SetAlpha(alpha)
    end
end

-- Só inimigos atacáveis ganham o visual Azaath (nunca a própria placa)
local function ShouldStyle(unit)
    if UnitIsUnit and UnitIsUnit(unit, "player") then return false end
    local ok, can = pcall(UnitCanAttack, "player", unit)
    if ok and not Azaath.IsSecret(can) then return can and true or false end
    local reaction = UnitReaction(unit, "player")
    return reaction ~= nil and not Azaath.IsSecret(reaction) and reaction <= 4
end

--------------------------------------------------------------------------------
-- Efeitos: contêiner nativo de auras (o jogo lê e desenha; nós só estilizamos)
--------------------------------------------------------------------------------
local function AuraContainersAvailable()
    return _G.C_XMLUtil and C_XMLUtil.GetTemplateInfo
        and C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate") and true or false
end

-- Tempo restante: "12", "3m", "1h" (formatador nativo, aceita valores secretos)
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

-- Visual de cada ícone (chamado pelo contêiner ao criar um botão)
local function StyleAuraButton(b, border)
    if b.azStyled then return end
    b.azStyled = true
    local size = cfg.auraSize
    b:SetSize(size, size)
    if b.EnableMouse then b:EnableMouse(false) end
    if b.SetMouseMotionEnabled then pcall(b.SetMouseMotionEnabled, b, false) end
    if b.SetMouseClickEnabled then pcall(b.SetMouseClickEnabled, b, false) end

    local edge = b:CreateTexture(nil, "BACKGROUND")
    edge:SetAllPoints(b)
    edge:SetColorTexture(border[1], border[2], border[3], 0.95)

    local icon = b:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b:SetIcon(icon)

    local cd = CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    cd:SetAllPoints(icon)
    cd:SetDrawEdge(false)
    if cd.SetDrawBling then cd:SetDrawBling(false) end
    cd:SetHideCountdownNumbers(true)
    cd:SetReverse(true)
    cd.noCooldownCount = true
    if cd.EnableMouse then cd:EnableMouse(false) end
    b:SetDurationCooldown(cd)

    -- textos acima da espiral
    local texts = CreateFrame("Frame", nil, b)
    texts:SetAllPoints(b)
    texts:SetFrameLevel(cd:GetFrameLevel() + 2)

    local fontSize = max(8, floor(size * 0.62 + 0.5))
    local timer = texts:CreateFontString(nil, "OVERLAY")
    timer:SetFont(Azaath.media.fontBold, fontSize, "OUTLINE")
    timer:SetPoint("CENTER", b, "CENTER", 0, 0)
    timer:SetTextColor(1, 1, 1)
    local fmt = TimeFormatter()
    if fmt then
        b:SetDurationText(timer, { textFormatter = fmt })
    else
        timer:Hide()
    end

    local count = texts:CreateFontString(nil, "OVERLAY")
    count:SetFont(Azaath.media.fontBold, max(7, fontSize - 1), "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -1)
    count:SetTextColor(1, 0.9, 0.6)
    b:SetApplicationCount(count)
end

local function StyleDebuff(b) StyleAuraButton(b, DEBUFF_BORDER) end
local function StyleBuff(b) StyleAuraButton(b, BUFF_BORDER) end

local function GroupOptions(maxCount, initializeFrame)
    local size, sp = cfg.auraSize, 1
    local sortMethod = _G.AuraContainerSortMethod
    return {
        maxFrameCount = maxCount,
        sortMethod = sortMethod and (sortMethod.Expiration or sortMethod.Default) or 0,
        sortDirection = _G.AuraContainerSortDirection and AuraContainerSortDirection.Normal or 0,
        initializeFrame = initializeFrame,
        layout = {
            elementSpacing = sp, lineSpacing = sp, groupSpacing = sp + 2, groupLineSpacing = sp,
            elementWidth = size, elementHeight = size,
        },
    }
end

-- Um contêiner por barra Azaath: debuffs (de qualquer origem) e depois buffs,
-- em linha a partir da esquerda, logo acima do nome; quebra linha para cima.
-- Skin Zerker (mode): "buffs" = só buffs acima do nome; "debuffs" = só debuffs
-- numa linha logo abaixo da barra.
local function CreateAuraContainer(bar, mode)
    local c = CreateFrame("AuraContainer", nil, bar, "CustomAuraContainerTemplate")
    c:SetSize(1, 1)
    local groups
    if mode == "debuffs" then
        if bar.bdo then
            c:SetPoint("TOPLEFT", bar.health, "BOTTOMLEFT", 0, -3)
        else
            -- barra Azaath: abaixo de tudo (losango do nível e moldura de combate)
            c:SetPoint("TOPLEFT", bar, "BOTTOMLEFT", 0, -2)
        end
        groups = { { "debuffs", "HARMFUL", cfg.maxDebuffs or 8, StyleDebuff } }
    elseif mode == "buffs" then
        c:SetPoint("BOTTOMLEFT", bar.health, "TOPLEFT", 0, bar.nameGap + bar.nameSize + 3)
        groups = { { "buffs", "HELPFUL", cfg.maxBuffs or 4, StyleBuff } }
    else
        c:SetPoint("BOTTOMLEFT", bar.health, "TOPLEFT", 0, bar.nameGap + bar.nameSize + 3)
        groups = {
            { "debuffs", "HARMFUL", cfg.maxDebuffs or 8, StyleDebuff },
            { "buffs", "HELPFUL", cfg.maxBuffs or 4, StyleBuff },
        }
    end
    for _, g in ipairs(groups) do
        local opts = GroupOptions(g[3], g[4])
        c:AddAuraGroup(g[1], g[2], opts)
        c:SetAuraGroupLayout(g[1], opts.layout)
    end
    local flow = _G.AnchorUtil and AnchorUtil.FlowDirection or { Right = 1, Left = 2, Up = 1, Down = 2 }
    if mode == "debuffs" then
        c:SetFlowLayoutAnchorPoint("TOPLEFT")
        c:SetFlowLayoutGrowthDirection(flow.Right, flow.Down)
    else
        c:SetFlowLayoutAnchorPoint("BOTTOMLEFT")
        c:SetFlowLayoutGrowthDirection(flow.Right, flow.Up)
    end
    c:SetFlowLayoutMaximumLineSize(cfg.width + 1)
    c:SetEnabled(false)
    return c
end

local function EnableAuras(bar, unit)
    for _, c in ipairs({ bar.auraContainer or false, bar.auraContainer2 or false }) do
        if c then
            c:SetUnit(unit)
            c:SetEnabled(true)
            c:Show()
        end
    end
end

local function DisableAuras(bar)
    for _, c in ipairs({ bar.auraContainer or false, bar.auraContainer2 or false }) do
        if c then
            c:SetEnabled(false)
            c:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- Placa de ALIADOS (jogadores amigos) — medidas das capturas do Azaath (1080p):
--   fora de combate: losango preto 22 px com o nível + nome à direita
--   em combate/ferido: barra branca de 106 x 3 px saindo da ponta do losango,
--   com o nome em cima da barra
--------------------------------------------------------------------------------
local DIAMOND      = 22     -- losango do nível (tamanho nativo da textura AllyDiamond: 22 px)
local ALLY_BAR_H   = 3
local ALLY_NAME_GAP_OUT = 4 -- nome fora de combate: distância da ponta do losango
local ALLY_NAME_X_IN    = 7 -- nome em combate: recuo em relação ao início da barra
local ALLY_NAME_Y_IN    = 5 -- nome em combate: altura acima da barra
local ALLY_TRACKING     = 0.10
local ALLY_NAME_COLOR   = { 0.96, 0.96, 0.94 }

local function TargetTex(name)
    return Azaath.media.path .. "Target\\" .. name
end

local function NewAlly()
    local f = CreateFrame("Frame", nil, holder)
    f.kind = "ally"
    f:EnableMouse(false)
    local barW = cfg.allyBarWidth or 104
    f:SetSize(DIAMOND + barW, DIAMOND)

    -- barra (fica atrás do losango; começa na ponta direita dele)
    local h = CreateFrame("Frame", nil, f)
    h:EnableMouse(false)
    h:SetSize(barW, ALLY_BAR_H)
    h:SetPoint("LEFT", f, "LEFT", DIAMOND - 1, 0)
    local edge = h:CreateTexture(nil, "BACKGROUND")
    edge:SetColorTexture(0, 0, 0, 0.55) -- filetes escuros em cima/embaixo e fundo vazio
    edge:SetPoint("TOPLEFT", h, "TOPLEFT", 0, 1)
    edge:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 1, -1)
    local trail = CreateFrame("StatusBar", nil, h)
    trail:EnableMouse(false)
    trail:SetAllPoints(h)
    trail:SetStatusBarTexture(Azaath.media.blank)
    trail:SetStatusBarColor(0.62, 0.60, 0.58) -- pedaço perdido: cinza que some
    trail:SetMinMaxValues(0, 1)
    trail:SetValue(0)
    trail:SetAlpha(0)
    local bar = CreateFrame("StatusBar", nil, h)
    bar:EnableMouse(false)
    bar:SetAllPoints(h)
    bar:SetStatusBarTexture(TargetTex("AllyFill"))
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(1)
    h.bar, h.trail, h.flashMode, h.trailValue = bar, trail, true, 0
    f.health = h

    -- losango do nível por cima da ponta da barra
    local dia = CreateFrame("Frame", nil, f)
    dia:EnableMouse(false)
    dia:SetSize(DIAMOND, DIAMOND)
    dia:SetPoint("LEFT", f, "LEFT", 0, 0)
    local tex = dia:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(TargetTex("AllyDiamond"))
    tex:SetSize(DIAMOND * 26 / 22, DIAMOND * 26 / 22)
    tex:SetPoint("CENTER", dia, "CENTER")
    local level = dia:CreateFontString(nil, "OVERLAY")
    level:SetFont(Azaath.media.fontBold, 12, "")
    level:SetShadowOffset(0, 0)
    level:SetTextColor(1, 1, 1)
    level:SetPoint("CENTER", dia, "CENTER", 0, 0)
    f.diamond, f.diamondTex, f.levelText = dia, tex, level

    -- nome (letras separadas para o espaçamento)
    f.nameLayer = CreateFrame("Frame", nil, f)
    f.nameLayer:EnableMouse(false)
    f.nameLayer:SetAllPoints(f)
    f.nameChars, f.nameWidths, f.nameWidth = {}, {}, 0
    f.nameSize = cfg.allyNameFont or 14
    f.nameFontPath = Azaath.media.fontCinzel or Azaath.media.fontTitleB
    f.nameMaxW = cfg.allyNameMaxW or 185
    local fallback = f.nameLayer:CreateFontString(nil, "OVERLAY")
    fallback:SetFont(f.nameFontPath, f.nameSize, "")
    fallback:SetShadowOffset(1, -1)
    fallback:SetShadowColor(0, 0, 0, 0.95)
    fallback:Hide()
    f.nameFallback = fallback
    return f
end

local function AllyLevels(f)
    local base = f:GetFrameLevel()
    f.health:SetFrameLevel(base + 1)
    f.health.trail:SetFrameLevel(base + 2)
    f.health.bar:SetFrameLevel(base + 3)
    f.diamond:SetFrameLevel(base + 5)
    f.nameLayer:SetFrameLevel(base + 6)
end

-- Posiciona as letras do nome conforme o estado (fora/dentro de combate)
local function LayoutAllyName(f)
    local inCombat = f.combatShown
    local x0 = inCombat and (DIAMOND - 1 + ALLY_NAME_X_IN) or (DIAMOND + ALLY_NAME_GAP_OUT)
    local track = f.appliedTrack ~= nil and f.appliedTrack or ((f.nameSize or 12) * ALLY_TRACKING)
    local fallback = f.nameFallback
    fallback:ClearAllPoints()
    if inCombat then
        fallback:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", ALLY_NAME_X_IN, ALLY_NAME_Y_IN)
    else
        fallback:SetPoint("LEFT", f, "LEFT", x0, 0)
    end
    local x = x0
    for i = 1, f.nameCount or 0 do
        local fs = f.nameChars[i]
        fs:ClearAllPoints()
        if inCombat then
            fs:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", x - (DIAMOND - 1), ALLY_NAME_Y_IN)
        else
            fs:SetPoint("LEFT", f, "LEFT", x, 0)
        end
        x = x + f.nameWidths[i] + track
    end
end

local function SetAllyName(f, text, r, g, b)
    local chars = f.nameChars
    if Azaath.IsSecret(text) then
        for i = 1, #chars do chars[i]:Hide() end
        f.nameCount, f.nameWidth = 0, 0
        f.appliedTrack = 0
        f.nameFallback:SetText(text)
        f.nameFallback:SetTextColor(r, g, b)
        f.nameFallback:Show()
        f.nameWidth = 60 -- largura aproximada (texto secreto não pode ser medido)
        return
    end
    f.nameFallback:Hide()

    local full = f.hlState == "target" or f.hlState == "mouseover"
    local list = {}
    local n = 0
    for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if n >= 32 then break end
        n = n + 1
        list[n] = ch
    end

    local widths = f.nameWidths
    local fontPath = f.nameFontPath or Azaath.media.fontCinzel or Azaath.media.fontTitleB

    local function Measure(sz)
        local sum = 0
        for i = 1, n do
            local fs = chars[i]
            if not fs then
                fs = f.nameLayer:CreateFontString(nil, "OVERLAY")
                fs:SetShadowOffset(1, -1)
                fs:SetShadowColor(0, 0, 0, 0.95)
                chars[i] = fs
            end
            fs:SetFont(fontPath, sz, "")
            if list[i] == " " then
                fs:SetText("")
                widths[i] = sz * 0.32
            else
                fs:SetText(list[i])
                widths[i] = fs:GetStringWidth()
            end
            fs:SetTextColor(r, g, b)
            sum = sum + widths[i]
        end
        return sum
    end

    local size = f.nameSize or 14
    local track = size * ALLY_TRACKING
    local letters = Measure(size)
    local total = letters + track * math.max(0, n - 1)

    -- Placas de aliado: o nome tenta caber por completo antes de ser cortado
    -- (só corta com "..." se for super comprido, exatamente como nos mobs inimigos)
    local maxW = f.nameMaxW or cfg.allyNameMaxW or 185
    if maxW and total > maxW then
        -- 1) letras juntas (sem o espaçamento extra)
        track = 0
        total = letters
        -- 2) fonte um pouco menor para caber o nome todo (até 80% do tamanho, mín. 11 px)
        if total > maxW then
            local minSize = math.floor((f.nameSize or 14) * 0.8 + 0.5)
            local fit = math.floor(size * maxW / total)
            local newSize = math.max(minSize, fit)
            if newSize < size then
                size = newSize
                total = Measure(size)
            end
        end
    end

    -- 3) ainda não coube (super comprido): corta e termina em "..." (menos no alvo / mouse)
    if maxW and total > maxW and n > 3 and not full then
        local fallback = f.nameFallback
        fallback:SetFont(fontPath, size, "")
        fallback:SetText(".")
        local dotW = fallback:GetStringWidth()
        fallback:SetFont(fontPath, f.nameSize or 14, "")
        local dots = 3 * (dotW + track)
        local acc, k = 0, 0
        for i = 1, n do
            local add = widths[i] + (i > 1 and track or 0)
            if acc + add + dots > maxW then break end
            acc, k = acc + add, i
        end
        while k > 1 and (chars[k]:GetText() or "") == "" do
            acc = acc - widths[k] - track
            k = k - 1
        end
        for j = 1, 3 do
            local i = k + j
            local fs = chars[i]
            if not fs then
                fs = f.nameLayer:CreateFontString(nil, "OVERLAY")
                fs:SetShadowOffset(1, -1)
                fs:SetShadowColor(0, 0, 0, 0.95)
                chars[i] = fs
            end
            fs:SetFont(fontPath, size, "")
            fs:SetText(".")
            fs:SetTextColor(r, g, b)
            widths[i] = dotW
        end
        n = k + 3
        total = acc + dots
    end

    for i = 1, n do
        chars[i]:Show()
    end
    for i = n + 1, #chars do
        chars[i]:Hide()
    end

    f.nameCount = n
    f.nameWidth = total
    f.appliedTrack = track
    f.appliedSize = size
end

-- Grupo centralizado na placa: (losango + barra) em combate, (losango + nome) fora
local function PlaceAlly(f)
    local plate = f.plate
    if not plate then return end
    local fw = DIAMOND + (cfg.allyBarWidth or 104)
    local gw = f.combatShown and fw or (DIAMOND + ALLY_NAME_GAP_OUT + (f.nameWidth or 0))
    local offsetY = (cfg and cfg.allyOffsetY) or -8
    f:ClearAllPoints()
    f:SetPoint("CENTER", plate, "CENTER", (fw - gw) / 2, offsetY)
end

local function IsUnitInGroup(unit)
    if not unit then return false end
    if UnitPlayerOrPetInParty and UnitPlayerOrPetInParty(unit) then return true end
    if UnitInParty and UnitInParty(unit) then return true end
    if UnitInRaid and UnitInRaid(unit) then return true end
    return false
end

local function UpdateAllyHealth(f, instant)
    local unit = f.displayUnit
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    Azaath.AzBar.SetBarValues(f.health, cur, max, instant)

    local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
    if Azaath.IsSecret(dead) then dead = false end
    local inGroup = IsUnitInGroup(unit)
    local combat = false
    if not dead then
        combat = inGroup or Azaath.AzBar.InCombat(unit)
        if not combat and not Azaath.AnySecret(cur, max) then
            combat = max > 0 and cur > 0 and cur < max
        end
    end
    if f.combatShown ~= combat then
        f.combatShown = combat
        f.health:SetShown(combat)
        LayoutAllyName(f)
        PlaceAlly(f)
    end
end

local function GetUnitDisplayName(unit)
    if not unit then return "" end
    if UnitPVPName and UnitIsPlayer and UnitIsPlayer(unit) then
        local ok, pvp = pcall(UnitPVPName, unit)
        if ok and pvp and not Azaath.IsSecret(pvp) and pvp ~= "" then
            return pvp
        end
    end
    local ok, n = pcall(UnitName, unit)
    if ok and n and not Azaath.IsSecret(n) then
        return n
    end
    return ""
end

local function UpdateAllyInfo(f)
    local unit = f.displayUnit
    local c = ALLY_NAME_COLOR
    local r, g, b = c[1], c[2], c[3]
    local state = f.hlState
    if state == "target" then
        r, g, b = 1, 0.92, 0.55 -- Destaque dourado Azaath ao selecionar
    elseif state == "mouseover" then
        r, g, b = 1, 1, 0.90   -- Marfim brilhante ao passar o mouse
    end
    local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
    if dead and not Azaath.IsSecret(dead) then r, g, b = r * 0.6, g * 0.6, b * 0.6 end
    SetAllyName(f, GetUnitDisplayName(unit), r, g, b)

    local inGroup = IsUnitInGroup(unit)
    if inGroup then
        f.health.bar:SetStatusBarColor(0.22, 0.58, 0.98)
        local _, cls = UnitClass and UnitClass(unit)
        local col = cls and ((_G.CUSTOM_CLASS_COLORS and _G.CUSTOM_CLASS_COLORS[cls]) or (_G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[cls]))
        if col and f.diamondTex then
            f.diamondTex:SetVertexColor(col.r, col.g, col.b)
            f.levelText:SetShadowOffset(1, -1)
            f.levelText:SetShadowColor(0, 0, 0, 0.95)
        elseif f.diamondTex then
            f.diamondTex:SetVertexColor(1, 1, 1)
            f.levelText:SetShadowOffset(0, 0)
        end
    else
        f.health.bar:SetStatusBarColor(1, 1, 1)
        if f.diamondTex then f.diamondTex:SetVertexColor(1, 1, 1) end
        f.levelText:SetShadowOffset(0, 0)
    end

    local level = UnitLevel(unit)
    if Azaath.IsSecret(level) then
        f.levelText:SetText(level)
    elseif level and level > 0 then
        f.levelText:SetText(level)
    else
        f.levelText:SetText("??")
    end
    LayoutAllyName(f)
    PlaceAlly(f)
end

local function IsAllyPlayer(unit)
    if not cfg.allies then return false end
    if UnitIsUnit and UnitIsUnit(unit, "player") then return false end
    local ok, isPlayer = pcall(UnitIsPlayer, unit)
    if not ok or Azaath.IsSecret(isPlayer) or not isPlayer then return false end
    local ok2, can = pcall(UnitCanAttack, "player", unit)
    if ok2 and not Azaath.IsSecret(can) then return not can end
    return UnitIsFriend and UnitIsFriend("player", unit) and true or false
end

--------------------------------------------------------------------------------
-- Placas de NPCs UTILITÁRIOS (Leilão, Conserto, Venda, Estalagem, Quests, etc.)
--   Estilo limpo Azaath: ícone de utilidade + nome em Cinzel + subtítulo
--------------------------------------------------------------------------------
local UTILITY_ICONS = {
    auction         = "Interface\\Icons\\INV_Misc_Coin_01",
    inn             = "Interface\\Icons\\INV_Misc_Rune_01",
    bank            = "Interface\\GossipFrame\\BankerGossipIcon",
    repair          = "Interface\\Icons\\Trade_BlackSmithing",
    flight          = "Interface\\GossipFrame\\TaxiGossipIcon",
    trainer         = "Interface\\GossipFrame\\TrainerGossipIcon",
    vendor          = "Interface\\GossipFrame\\VendorGossipIcon",
    quest_available = "Interface\\GossipFrame\\AvailableQuestIcon",
    quest_turnin    = "Interface\\GossipFrame\\ActiveQuestIcon",
    quest           = "Interface\\GossipFrame\\ActiveQuestIcon",
}

local UTILITY_KEYWORDS = {
    { type = "auction", words = { "leiloeir", "leilao", "leilão", "auctioneer", "auction", "subasta" } },
    { type = "inn",     words = {
        "estalajad", "estalagem",
        "taverneir", "taverna", "taberneir", "taberna",
        "pousadeir", "pousada", "hospedeir", "hospedaria", "hosped",
        "innkeeper", "inn", "tavern", "bartender", "barkeeper",
        "posader", "posada", "taberner", "mesonero", "mesonera", "albergue", "hostal",
    } },
    { type = "bank",    words = { "banqueir", "banker", "banco", "bank", "cofre", "vault" } },
    { type = "flight",  words = {
        "mestre de voo", "mestra de voo", "mestre de vôo", "mestra de vôo",
        "mestre de grifos", "mestra de grifos", "mestre dos grifos", "mestra dos grifos",
        "tratador de grifos", "tratadora de grifos", "piloto de grifo",
        "mestre das serpentes", "mestre de serpentes", "mestre dos morcegos", "mestre de morcegos",
        "mestre dos dracoleões", "mestre de dracoleões", "dracoleão", "dracoleao",
        "mestre dos hipogrifos", "mestre de hipogrifos", "hipogrifo", "hipogrifos",
        "mestre dos pterodáctilos", "mestre de pterodáctilos", "mantícora", "manticora",
        "falcão-dragão", "falcao-dragao", "grifo", "grifos",
        "flight master", "flightmaster", "gryphon master", "bat rider", "wind rider master", "flight",
        "maestro de vuelo", "señor de los grifos", "ponto de voo", "vôo", "voo",
    } },
    { type = "trainer", words = { "treinador", "treinadora", "instrutor", "instrutora", "trainer", "instructor", "mestre de armas", "weapon master" } },
    { type = "repair",  words = {
        -- Português
        "conserto", "consertos", "repara", "reparo", "reparos",
        "ferreir", "ferraria", "ferrador", "ferradores", "ferrar",
        "armeir", "armaria", "armadur",
        "forja", "forjador", "forjadora", "forjadores", "bigorna",
        "cutel", "cutileir",
        "engenh",
        "artigos de ferro", "artigos de metal",
        "armas e armaduras", "armas", "escudo", "escudos",
        "machados", "espadas", "maças", "lâminas", "laminas",
        "arcos e armas de fogo", "arcos", "bestas", "armas de fogo", "espingardas", "pistolas",
        "adagas", "lanças", "lancas", "martelos", "cajados", "varinhas",
        "armaduras de placa", "armaduras de malha", "armaduras de couro",
        -- Inglês
        "repair", "repairer", "repairs",
        "blacksmith", "blacksmithing", "smithy",
        "armorer", "armourer", "armor", "armour",
        "weaponsmith", "armorsmith", "bladesmith", "gunsmith", "bowyer", "farrier",
        "weapons & armor", "weapons", "weapon",
        "forge", "anvil", "shield", "shields",
        "axes", "swords", "maces", "blades", "ironware", "bows", "crossbows", "guns", "daggers", "staves", "wands",
        "engineering supplies", "blacksmithing supplies",
        "heavy armor", "chain armor", "plate armor",
        -- Espanhol
        "herrero", "herrera", "herrería", "herreria",
        "armero", "armera", "armería", "armeria",
        "reparación", "reparacion",
    } },
    { type = "vendor",  words = {
        "vendedor", "vendedora", "comerciante", "mercador", "mercadora", "mercadorias",
        "suprimentos", "provisões", "provisoes", "vendor", "merchant",
        "supplies", "provisions", "vended", "alquimista", "alfaiate",
        "coureiro", "açougueiro", "peixeiro", "comida", "comidas", "bebida", "bebidas",
        "pães", "paes", "pão", "pao", "frutas", "carnes", "queijos", "peixes",
        "água", "agua", "vinhos", "cervejas", "doces", "bolos", "tortas", "cogumelos", "fungos",
        "munição", "municao", "flechas", "balas", "venenos", "poções", "pocoes", "elixires",
        "pergaminhos", "bolsas", "mochilas", "tabardos", "camisas", "flores", "ferramentas", "iscas",
        "receitas", "diagramas", "moldes", "fórmulas", "formulas", "bens gerais",
        "artigos", "reagentes", "reagents", "trader", "suministros",
        "bread", "breads", "food", "drink", "drinks", "beverages", "meat", "fish", "fruit", "cheese",
        "water", "wine", "ale", "ammunition", "ammo", "arrows", "bullets", "poisons", "potions",
        "scrolls", "bags", "tabards", "flowers", "tools", "baits", "recipes", "patterns", "plans",
        "general goods", "trade goods",
    } },
    { type = "quest",   words = { "missões", "missoes", "missao", "missão", "quest" } },
}

local DEFAULT_SUBTITLES = {
    inn             = "Estalagem",
    repair          = "Conserto",
    auction         = "Leilão",
    bank            = "Banco",
    flight          = "Mestre de Voo",
    trainer         = "Treinador",
    vendor          = "Comerciante",
    quest_available = "Nova Missão",
    quest_turnin    = "Missão",
}

local function MatchUtilityType(text)
    if not text or text == "" then return nil end
    local clean = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):lower()
    for _, entry in ipairs(UTILITY_KEYWORDS) do
        if entry.type ~= "quest" then
            for _, word in ipairs(entry.words) do
                if clean:find(word, 1, true) then
                    return entry.type
                end
            end
        end
    end
    return nil
end

local scanTip
local function IsNoiseTooltipLine(t)
    if type(t) ~= "string" or t == "" or Azaath.IsSecret(t) then return true end
    local low = t:lower()
    if t:find("%d") or t:find("%?%?") then return true end
    if low:find("nivel") or low:find("nível") or low:find("level")
        or low:find("facção") or low:find("faccao") or low:find("faction")
        or low:find("horda") or low:find("horde")
        or low:find("aliança") or low:find("alianca") or low:find("alliance")
        or low:find("neutro") or low:find("neutra") or low:find("neutral")
        or low:find("humanóide") or low:find("humanoide") or low:find("humanoid")
        or low:find("carregando") or low:find("retrieving")
        or low == "unknown" or low == "desconhecido" then
        return true
    end
    return false
end

local function GetNPCTooltipLines(unit)
    local out = {}
    if not unit or (UnitIsPlayer and UnitIsPlayer(unit)) then return out end
    local TI = _G.C_TooltipInfo
    if TI and TI.GetUnit then
        local ok, data = pcall(TI.GetUnit, unit)
        if ok and type(data) == "table" and type(data.lines) == "table" then
            if _G.TooltipUtil and TooltipUtil.SurfaceArgs then
                pcall(TooltipUtil.SurfaceArgs, data)
            end
            for i = 2, math.min(6, #data.lines) do
                local line = data.lines[i]
                if line then
                    local t = line.leftText
                    if (not t or t == "") and type(line.args) == "table" then
                        for _, arg in ipairs(line.args) do
                            if type(arg) == "table" and type(arg.stringVal) == "string" and arg.stringVal ~= "" then
                                t = arg.stringVal
                                break
                            end
                        end
                    end
                    if not IsNoiseTooltipLine(t) then
                        out[#out + 1] = t
                    end
                end
            end
        end
        return out
    end

    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "AZAATHNPCScanTip", nil, "GameTooltipTemplate")
        local sb = scanTip.StatusBar or _G["AZAATHNPCScanTipStatusBar"]
        if sb then sb:SetScript("OnValueChanged", nil) end
    end
    pcall(function()
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
        scanTip:ClearLines()
        scanTip:SetUnit(unit)
    end)
    for i = 2, 5 do
        local l = _G["AZAATHNPCScanTipTextLeft" .. i]
        local t = l and l:GetText()
        if not IsNoiseTooltipLine(t) then
            out[#out + 1] = t
        end
    end
    scanTip:Hide()
    return out
end

local function GetNPCSubtitle(unit)
    local lines = GetNPCTooltipLines(unit)
    return lines[1]
end

--------------------------------------------------------------------------------
-- Mob de missão (losango amarelo à esquerda da barra ou ícone utilitário)
--------------------------------------------------------------------------------
local QUEST_OBJECTIVE_LINE = _G.Enum and Enum.TooltipDataLineType and Enum.TooltipDataLineType.QuestObjective or 8

-- 1) o jogo diz direto se a unidade faz parte de uma missão ativa;
-- 2) senão, o tooltip da unidade tem um objetivo de missão não concluído
local function IsQuestUnit(unit)
    if not unit then return false end
    local QL = _G.C_QuestLog
    if QL and QL.UnitIsRelatedToActiveQuest then
        local ok, v = pcall(QL.UnitIsRelatedToActiveQuest, unit)
        if ok and not Azaath.IsSecret(v) and v then return true end
    end
    local TI = _G.C_TooltipInfo
    if not (TI and TI.GetUnit) then return false end
    local ok, data = pcall(TI.GetUnit, unit)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return false end
    if _G.TooltipUtil and TooltipUtil.SurfaceArgs then
        pcall(TooltipUtil.SurfaceArgs, data)
    end
    for _, line in ipairs(data.lines) do
        if type(line) == "table" then
            local t, done = line.type, line.completed
            if not Azaath.IsSecret(t) and t == QUEST_OBJECTIVE_LINE
                and not Azaath.IsSecret(done) and not done then
                return true
            end
        end
    end
    return false
end

local utilityCache = {}
local npcQuestState = {}

local function GetInteractingNPCGUID()
    if UnitExists and UnitExists("npc") then
        local g = UnitGUID("npc")
        if g and not Azaath.IsSecret(g) and g ~= "" then return g end
    end
    if UnitExists and UnitExists("target") and UnitCanAttack and not UnitCanAttack("player", "target") then
        local g = UnitGUID("target")
        if g and not Azaath.IsSecret(g) and g ~= "" then return g end
    end
    return nil
end

local function DetectNPCUtility(unit)
    if not unit then return nil end
    if UnitIsPlayer then
        local ok, isPl = pcall(UnitIsPlayer, unit)
        if ok and not Azaath.IsSecret(isPl) and isPl then return nil end
    end
    local guid = UnitGUID and UnitGUID(unit)
    if guid and Azaath.IsSecret(guid) then guid = nil end
    if guid and utilityCache[guid] ~= nil then
        return utilityCache[guid] or nil
    end

    local tipLines = GetNPCTooltipLines(unit)
    local subtitle = tipLines[1]
    local rawName = UnitName and UnitName(unit)
    if rawName and Azaath.IsSecret(rawName) then rawName = nil end
    local serviceType = nil
    local displaySub = subtitle

    -- 1) Tenta por todas as linhas de subtítulo do NPC (ex: <Estalajadeira>, <Ferreiro>, <Mestre de Grifos>)
    for _, line in ipairs(tipLines) do
        local matched = MatchUtilityType(line)
        if matched then
            serviceType = matched
            displaySub = line
            break
        end
    end

    -- 2) Se não achou pelo subtítulo, tenta pelo nome do NPC (ex: "Estalajadeira Allison", "Ferreiro Thurman", "Taverneiro Gryshka")
    if not serviceType and rawName and rawName ~= "" then
        serviceType = MatchUtilityType(rawName)
        if serviceType and (not displaySub or displaySub == "") then
            displaySub = DEFAULT_SUBTITLES[serviceType]
        end
    end

    -- 3) Missões (Quests)
    local questType, questIcon
    local qState = guid and npcQuestState[guid]
    local isRelated = IsQuestUnit(unit)

    -- Se acabou de entregar a missão nos últimos 2.5s neste NPC, ignore lag do QuestLog
    if qState and qState.turnedInTime and (GetTime() - qState.turnedInTime < 2.5) then
        if not qState.hasTurnIn then
            isRelated = false
        end
    end

    if (qState and qState.hasTurnIn) or isRelated then
        questType = "quest_turnin"
        questIcon = UTILITY_ICONS.quest_turnin
    elseif qState and qState.hasAvailable then
        questType = "quest_available"
        questIcon = UTILITY_ICONS.quest_available
    elseif not (qState and qState.noQuests) then
        if subtitle then
            local lower = subtitle:lower()
            for _, word in ipairs({ "missões", "missoes", "missao", "missão", "quest" }) do
                if lower:find(word, 1, true) then
                    questType = "quest_available"
                    questIcon = UTILITY_ICONS.quest_available
                    break
                end
            end
        end
    end

    -- Missão tem prioridade visual sobre serviço, mas se não houver missão ativa/disponível,
    -- o NPC exibe seu serviço normal (ex: Conserto / Estalagem / Vendedor)
    local uType, icon
    if questType and questIcon then
        uType = questType
        icon = questIcon
        displaySub = displaySub or (questType == "quest_available" and "Nova Missão" or "Missão")
    elseif serviceType then
        uType = serviceType
        icon = UTILITY_ICONS[serviceType]
    end

    local res = nil
    if uType and icon then
        res = {
            type = uType,
            icon = icon,
            subtitle = displaySub,
        }
    end

    if guid and res then
        utilityCache[guid] = res
    end
    return res
end

local function PlaceUtility(f)
    local plate = f.plate
    if not plate then return end
    local nameW = f.name:GetStringWidth() or 60
    local subW = f.subtitle:IsShown() and (f.subtitle:GetStringWidth() or 0) or 0
    local textW = math.max(nameW, subW)
    local hasIcon = f.iconFrame:IsShown()
    local iconW = hasIcon and 25 or 0
    local totalW = iconW + textW
    local totalH = f.subtitle:IsShown() and 28 or 18
    f:SetSize(totalW, totalH)

    local offsetY = (cfg and cfg.allyOffsetY) or -8
    f:ClearAllPoints()
    f:SetPoint("CENTER", plate, "CENTER", 0, offsetY)
end

local function UpdateUtilityInfo(f)
    local unit = f.displayUnit
    if not unit then return end
    local name = UnitName(unit) or ""
    f.name:SetText(name)

    local util = f.utilityInfo
    if util and util.icon then
        f.icon:SetTexture(util.icon)
        f.iconFrame:Show()
        if util.subtitle and util.subtitle ~= "" then
            local cleanSub = util.subtitle:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("^%s*<", ""):gsub(">%s*$", "")
            f.subtitle:SetText(cleanSub)
            f.subtitle:Show()
        else
            f.subtitle:SetText("")
            f.subtitle:Hide()
        end
    else
        f.iconFrame:Hide()
        f.subtitle:Hide()
    end

    local state = f.hlState
    if state == "target" then
        f.name:SetTextColor(1, 0.92, 0.55) -- Destaque dourado Azaath
        f.icon:SetVertexColor(1, 0.92, 0.55)
    elseif state == "mouseover" then
        f.name:SetTextColor(1, 1, 0.85)
        f.icon:SetVertexColor(1, 1, 0.85)
    else
        f.name:SetTextColor(0.96, 0.94, 0.88)
        f.icon:SetVertexColor(1, 1, 1)
    end

    PlaceUtility(f)
end

local function NewUtility()
    local f = CreateFrame("Frame", nil, holder)
    f.kind = "utility"
    f:EnableMouse(false)

    -- Container do ícone (moldura quadrada elegante estilo Azaath)
    local iconFrame = CreateFrame("Frame", nil, f)
    iconFrame:SetSize(20, 20)
    iconFrame:SetPoint("LEFT", f, "LEFT", 0, 0)

    local bg = iconFrame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(iconFrame)
    bg:SetColorTexture(0, 0, 0, 0.65)

    local border = iconFrame:CreateTexture(nil, "BORDER")
    border:SetColorTexture(0.35, 0.32, 0.28, 0.9)
    border:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", -1, 1)
    border:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", 1, -1)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icon = icon
    f.iconFrame = iconFrame

    -- Nome do NPC (Cinzel 13 px, marfim clássico)
    local name = f:CreateFontString(nil, "OVERLAY")
    name:SetFont(Azaath.media.fontCinzel or Azaath.media.fontTitleB, 13, "")
    name:SetShadowOffset(1, -1)
    name:SetShadowColor(0, 0, 0, 0.95)
    name:SetTextColor(0.96, 0.94, 0.88)
    name:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 5, 2)
    f.name = name

    -- Subtítulo da utilidade (ex: Estalajadeira, Conserto) em PT Sans 10 px
    local sub = f:CreateFontString(nil, "OVERLAY")
    sub:SetFont(Azaath.media.font, 10, "")
    sub:SetShadowOffset(1, -1)
    sub:SetShadowColor(0, 0, 0, 0.95)
    sub:SetTextColor(0.85, 0.80, 0.68)
    sub:SetPoint("TOPLEFT", name, "BOTTOMLEFT", 0, -1)
    f.subtitle = sub

    return f
end

-- Pets amigos (o seu e os dos aliados): unidade controlada por jogador que
-- não é jogador nem atacável. Ganham a placa de aliado em tamanho menor.
local function IsFriendlyPet(unit)
    if not cfg.pets then return false end
    local ok, controlled = pcall(UnitPlayerControlled, unit)
    if not ok or Azaath.IsSecret(controlled) or not controlled then return false end
    local ok1, isPlayer = pcall(UnitIsPlayer, unit)
    if not ok1 or Azaath.IsSecret(isPlayer) or isPlayer then return false end
    local ok2, can = pcall(UnitCanAttack, "player", unit)
    if ok2 and not Azaath.IsSecret(can) then return not can end
    return UnitIsFriend and UnitIsFriend("player", unit) and true or false
end

--------------------------------------------------------------------------------
-- Barra de conjuração nos inimigos (discreta e tática)
--------------------------------------------------------------------------------
local CAST_COLORS = {
    cast      = { 0.93, 0.72, 0.32 }, -- âmbar dourado Azaath
    channel   = { 0.42, 0.70, 0.85 }, -- azul-celeste
    shielded  = { 0.62, 0.62, 0.66 }, -- cinza-aço fosco (ininterruptível)
    failed    = { 0.78, 0.25, 0.20 }, -- vermelho de interrupção
    success   = { 0.45, 0.78, 0.35 }, -- verde de sucesso
}
local CAST_FADE_TIME = 0.25
local CAST_FAIL_HOLD = 0.35

local CAST_EVENTS = {
    UNIT_SPELLCAST_START = true, UNIT_SPELLCAST_STOP = true,
    UNIT_SPELLCAST_SUCCEEDED = true,
    UNIT_SPELLCAST_FAILED = true, UNIT_SPELLCAST_INTERRUPTED = true,
    UNIT_SPELLCAST_DELAYED = true, UNIT_SPELLCAST_CHANNEL_START = true,
    UNIT_SPELLCAST_CHANNEL_UPDATE = true, UNIT_SPELLCAST_CHANNEL_STOP = true,
    UNIT_SPELLCAST_EMPOWER_START = true, UNIT_SPELLCAST_EMPOWER_UPDATE = true,
    UNIT_SPELLCAST_EMPOWER_STOP = true,
    UNIT_SPELLCAST_INTERRUPTIBLE = true, UNIT_SPELLCAST_NOT_INTERRUPTIBLE = true,
}

local function ApplyCastColor(f)
    local c
    if f.interrupted then
        c = CAST_COLORS.failed
    elseif f.notInterruptible then
        c = CAST_COLORS.shielded
    elseif f.channeling then
        c = CAST_COLORS.channel
    else
        c = CAST_COLORS.cast
    end
    f.bar:SetStatusBarColor(c[1], c[2], c[3])
    if f.iconFrame then
        if f.notInterruptible then
            if f.iconFrame.SetBackdropBorderColor then
                f.iconFrame:SetBackdropBorderColor(c[1], c[2], c[3], 0.9)
            end
        else
            local gold = Azaath.colors.gold
            if f.iconFrame.SetBackdropBorderColor then
                f.iconFrame:SetBackdropBorderColor(gold[1], gold[2], gold[3], 0.7)
            end
        end
    end
end

local function ResetCast(f)
    if not f then return end
    f.casting, f.channeling, f.fadeOut, f.interrupted = false, false, false, false
    f.holdTime = 0
    f.castID = nil
    f.duration = nil
    f.isTest = false
    if f.bar and f.bar.SetTimerDuration then
        pcall(f.bar.SetTimerDuration, f.bar, nil)
    end
    f:Hide()
end

local function StartCast(f, channel)
    if not f or not f.unit then return false end
    if cfg and cfg.castBar == false then return false end

    -- Obtenção da duração nativa quando suportada (motor moderno / 1.60.x)
    local duration
    if channel then
        if _G.UnitChannelDuration then
            local ok, d = pcall(_G.UnitChannelDuration, f.unit)
            if ok and d then duration = d end
        end
    else
        if _G.UnitCastingDuration then
            local ok, d = pcall(_G.UnitCastingDuration, f.unit)
            if ok and d then duration = d end
        end
    end

    local name, text, texture, startMS, endMS, castID, notInterruptible
    if channel then
        name, text, texture, startMS, endMS, castID, notInterruptible = Azaath.API.ChannelInfo(f.unit)
    else
        name, text, texture, startMS, endMS, castID, notInterruptible = Azaath.API.CastingInfo(f.unit)
    end

    -- Se não há duração nativa nem nome da magia, a unidade não está conjurando
    if not duration and not name then
        f:Hide()
        return false
    end

    if Azaath.IsSecret(castID) then castID = nil end
    local isShielded = false
    if notInterruptible ~= nil and not Azaath.IsSecret(notInterruptible) then
        isShielded = notInterruptible and true or false
    end

    f.startTime = nil
    f.endTime = nil
    f.durationVal = nil
    f.casting = not channel
    f.channeling = channel and true or false
    f.castID = castID
    f.notInterruptible = isShielded
    f.interrupted = false
    f.holdTime = 0
    f.fadeOut = false
    f.isTest = false
    f.duration = duration

    local usedTimerDuration = false
    if duration and f.bar.SetTimerDuration then
        local Interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
        local TimerDir = Enum and Enum.StatusBarTimerDirection
        local dir = channel and (TimerDir and TimerDir.RemainingTime or 1) or (TimerDir and TimerDir.ElapsedTime or 0)
        local ok = pcall(f.bar.SetTimerDuration, f.bar, duration, Interp, dir)
        if ok then usedTimerDuration = true end
    end

    if not usedTimerDuration then
        if startMS and endMS and not Azaath.AnySecret(startMS, endMS) then
            f.startTime = startMS / 1000
            f.endTime = endMS / 1000
            f.durationVal = max(f.endTime - f.startTime, 0.001)
            f.bar:SetMinMaxValues(0, f.durationVal)
            f.bar:SetValue(channel and f.durationVal or 0)
        else
            f.bar:SetMinMaxValues(0, 1)
            f.bar:SetValue(0.5)
        end
    end

    if texture then
        f.icon:SetTexture(texture)
        f.iconFrame:Show()
    else
        f.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        f.iconFrame:Show()
    end

    if name then
        f.spellName:SetText(name)
    elseif text then
        f.spellName:SetText(text)
    else
        f.spellName:SetText("")
    end
    f.spellName:SetTextColor(Azaath.colors.cream[1], Azaath.colors.cream[2], Azaath.colors.cream[3])
    f.timeText:SetText("")

    ApplyCastColor(f)
    f:SetAlpha(1)
    f:Show()
    return true
end

local function FinishCast(f)
    if not f or not f:IsShown() then return end
    f.casting, f.channeling = false, false
    f.holdTime = 0.15
    f.fadeOut = true
    if f.bar.SetTimerDuration then
        pcall(f.bar.SetTimerDuration, f.bar, nil)
    end
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(1)
    f.bar:SetStatusBarColor(CAST_COLORS.success[1], CAST_COLORS.success[2], CAST_COLORS.success[3])
    f.timeText:SetText("")
end

local function FailCast(f, interrupted)
    if not f or not f:IsShown() then return end
    f.casting, f.channeling = false, false
    f.interrupted = interrupted
    f.holdTime = CAST_FAIL_HOLD
    f.fadeOut = true
    if f.bar.SetTimerDuration then
        pcall(f.bar.SetTimerDuration, f.bar, nil)
    end
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(1)
    f.bar:SetStatusBarColor(CAST_COLORS.failed[1], CAST_COLORS.failed[2], CAST_COLORS.failed[3])
    if interrupted then
        f.spellName:SetText("Interrompido")
        f.spellName:SetTextColor(CAST_COLORS.failed[1], CAST_COLORS.failed[2], CAST_COLORS.failed[3])
    end
    f.timeText:SetText("")
end

local function CastBar_OnUpdate(self, elapsed)
    local now = GetTime()
    if self.casting or self.channeling then
        if self.isTest then
            local rem = max(0, (self.endTime or now) - now)
            local val = (self.durationVal or 3) - rem
            self.bar:SetValue(val)
            self.timeText:SetFormattedText("%.1fs", rem)
            if rem <= 0 then
                self.isTest = false
                FinishCast(self)
            end
            return
        end

        -- Se a unidade morrer ou deixar de existir, esconde imediatamente
        if not self.unit or not UnitExists(self.unit) or (UnitIsDead and UnitIsDead(self.unit)) then
            ResetCast(self)
            return
        end

        local rem
        if self.duration and self.duration.GetRemainingDuration then
            local ok, r = pcall(self.duration.GetRemainingDuration, self.duration)
            if ok and r and not Azaath.IsSecret(r) then
                rem = r
                if rem <= 0 then
                    FinishCast(self)
                    return
                end
                self.timeText:SetFormattedText("%.1fs", rem)
            else
                self.timeText:SetText("")
            end
        elseif self.startTime and self.endTime then
            if now >= self.endTime then
                FinishCast(self)
                return
            end
            local val
            if self.casting then
                val = now - self.startTime
                if val > (self.durationVal or 1) then val = self.durationVal or 1 end
            else
                val = self.endTime - now
                if val < 0 then val = 0 end
            end
            self.bar:SetValue(val)
            rem = max(0, self.endTime - now)
            self.timeText:SetFormattedText("%.1fs", rem)
        end

        -- Checagem periódica a cada 0.1s para detectar fim de cast caso o evento tenha sido perdido
        self.pollElapsed = (self.pollElapsed or 0) + elapsed
        if self.pollElapsed >= 0.1 then
            self.pollElapsed = 0
            local stillCasting = false
            if self.channeling then
                if _G.UnitChannelDuration and pcall(_G.UnitChannelDuration, self.unit) and UnitChannelDuration(self.unit) then
                    stillCasting = true
                elseif Azaath.API.ChannelInfo(self.unit) then
                    stillCasting = true
                end
            else
                if _G.UnitCastingDuration and pcall(_G.UnitCastingDuration, self.unit) and UnitCastingDuration(self.unit) then
                    stillCasting = true
                elseif Azaath.API.CastingInfo(self.unit) then
                    stillCasting = true
                end
            end
            if not stillCasting then
                FinishCast(self)
                return
            end
        end
    elseif self.holdTime > 0 then
        self.holdTime = self.holdTime - elapsed
    elseif self.fadeOut then
        local a = self:GetAlpha() - elapsed / CAST_FADE_TIME
        if a <= 0 then
            ResetCast(self)
        else
            self:SetAlpha(a)
        end
    else
        ResetCast(self)
    end
end

local function HandleCastEvent(f, event, ...)
    if not f or not f.unit then return end
    local castID = Azaath.API.EventCastID(...)
    if event == "UNIT_SPELLCAST_START" then
        if not f.casting or (castID and f.castID ~= castID) then
            StartCast(f, false)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_EMPOWER_START" then
        if not f.channeling then
            StartCast(f, true)
        end
    elseif event == "UNIT_SPELLCAST_STOP" or event == "UNIT_SPELLCAST_SUCCEEDED" then
        if f.casting then
            FinishCast(f)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_EMPOWER_STOP" then
        if f.channeling then
            FinishCast(f)
        end
    elseif event == "UNIT_SPELLCAST_FAILED" or event == "UNIT_SPELLCAST_INTERRUPTED" then
        local isInterrupted = (event == "UNIT_SPELLCAST_INTERRUPTED")
        if f.casting then
            if event == "UNIT_SPELLCAST_FAILED" then
                local castingNow = (_G.UnitCastingDuration and UnitCastingDuration(f.unit) ~= nil)
                    or (Azaath.API.CastingInfo(f.unit) ~= nil)
                if castingNow then return end
            end
            FailCast(f, isInterrupted)
        elseif f.channeling and isInterrupted then
            FailCast(f, true)
        end
    elseif event == "UNIT_SPELLCAST_DELAYED" then
        if f.casting then
            StartCast(f, false)
        end
    elseif event == "UNIT_SPELLCAST_CHANNEL_UPDATE" or event == "UNIT_SPELLCAST_EMPOWER_UPDATE" then
        if f.channeling then
            StartCast(f, true)
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTIBLE" or event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE" then
        if f.casting or f.channeling then
            f.notInterruptible = (event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
            ApplyCastColor(f)
        end
    end
end

local function CreateNameplateCastBar(bar)
    local c = Azaath.colors
    local blank = Azaath.media.blank
    local width = cfg and cfg.width or 110
    local height = 5

    local f = CreateFrame("Frame", nil, bar, _G.BackdropTemplateMixin and "BackdropTemplate")
    f:SetSize(width, height)
    f:SetPoint("TOP", bar.badge or bar, "BOTTOM", 0, -3)
    f:SetFrameLevel(bar:GetFrameLevel() + 15)
    Azaath.SetBackdrop(f, {
        bgFile = blank, edgeFile = blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(0.06, 0.06, 0.08, 0.85)
    f:SetBackdropBorderColor(0, 0, 0, 0.8)

    local barTex = CreateFrame("StatusBar", nil, f)
    barTex:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    barTex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -1, 1)
    barTex:SetStatusBarTexture(blank)
    barTex:SetMinMaxValues(0, 1)
    barTex:SetValue(0)
    barTex:SetFrameLevel(f:GetFrameLevel() + 1)
    f.bar = barTex

    local iconFrame = CreateFrame("Frame", nil, f, _G.BackdropTemplateMixin and "BackdropTemplate")
    iconFrame:SetSize(16, 16)
    iconFrame:SetPoint("RIGHT", f, "LEFT", -4, 0)
    iconFrame:SetFrameLevel(f:GetFrameLevel() + 2)
    Azaath.SetBackdrop(iconFrame, {
        bgFile = blank, edgeFile = blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    iconFrame:SetBackdropColor(0, 0, 0, 0.9)
    iconFrame:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.7)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 1, -1)
    icon:SetPoint("BOTTOMRIGHT", iconFrame, "BOTTOMRIGHT", -1, 1)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    f.icon = icon
    f.iconFrame = iconFrame

    local spellName = f:CreateFontString(nil, "OVERLAY")
    spellName:SetFont(Azaath.media.font, 9, "OUTLINE")
    spellName:SetPoint("TOPLEFT", f, "BOTTOMLEFT", 0, -2)
    spellName:SetPoint("RIGHT", f, "RIGHT", -26, 0)
    spellName:SetHeight(12)
    spellName:SetJustifyH("LEFT")
    spellName:SetWordWrap(false)
    spellName:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    f.spellName = spellName

    local timeText = f:CreateFontString(nil, "OVERLAY")
    timeText:SetFont(Azaath.media.font, 9, "OUTLINE")
    timeText:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 0, -2)
    timeText:SetHeight(12)
    timeText:SetJustifyH("RIGHT")
    timeText:SetWordWrap(false)
    timeText:SetTextColor(c.dim[1], c.dim[2], c.dim[3])
    f.timeText = timeText

    f:SetScript("OnEvent", function(self, event, unit, ...)
        HandleCastEvent(self, event, ...)
    end)

    f:Hide()
    return f
end

--------------------------------------------------------------------------------
-- Ligação barra <-> placa
--------------------------------------------------------------------------------
local function NewBar()
    local bar = E().Create(holder, cfg)
    if AuraContainersAvailable() then
        local ok, c = pcall(CreateAuraContainer, bar, "buffs")
        if ok then
            bar.auraContainer = c
        else
            Azaath.LogError("Nameplates AuraContainer: " .. tostring(c))
        end
        do
            local ok2, c2 = pcall(CreateAuraContainer, bar, "debuffs")
            if ok2 then
                bar.auraContainer2 = c2
            else
                Azaath.LogError("Nameplates AuraContainer debuffs: " .. tostring(c2))
            end
        end
        if bar.bdo then
            -- a conjuração desce para baixo da linha de debuffs
            bar.castDrop = 3 + (cfg.auraSize or 12) + 4
        end
    end
    bar.castBar = CreateNameplateCastBar(bar)
    return bar
end

local function Detach(unit)
    local bar = active[unit]
    if not bar then return end
    active[unit] = nil
    if bar.kind ~= "ally" and bar.kind ~= "utility" then
        pcall(DisableAuras, bar)
        if bar.castBar then
            bar.castBar:UnregisterAllEvents()
            ResetCast(bar.castBar)
            bar.castBar.unit = nil
            bar.castBar:SetScript("OnUpdate", nil)
        end
        E().SetState(bar, nil, false) -- volta limpa para o depósito
        E().SetQuest(bar, false)
        if hovered == bar then hovered = nil end
    end
    ShowBlizzard(bar.plate)
    bar:Hide()
    bar:ClearAllPoints()
    bar:SetParent(holder)
    bar.plate, bar.displayUnit = nil, nil
    if bar.kind == "utility" then
        bar.hlState = nil
        bar.utilityInfo = nil
        utilityPool[#utilityPool + 1] = bar
    elseif bar.kind == "ally" then
        bar.hlState = nil
        allyPool[#allyPool + 1] = bar
    else
        pool[#pool + 1] = bar
    end
end

-- Inimigo selecionado: o jogo aumenta a placa dele; a barra Azaath compensa
-- ficando um pouco menor (nameplates.selectedScale)
local function ApplyScale(bar)
    -- alvo selecionado um pouco maior (antes 0,85 compensava o aumento do jogo)
    if cfg.selScaleV2 ~= 4 then cfg.selectedScale, cfg.selScaleV2 = 1.12, 4 end
    local ok, isTarget = pcall(UnitIsUnit, bar.displayUnit, "target")
    if not ok or Azaath.IsSecret(isTarget) then isTarget = false end
    -- placas de inimigo (as 3: Azaath, Zerker, minimalista), pedido de 23/11:
    --  * o alvo fica 30% maior (destaque principal, junto do nome dourado);
    --  * todas do mesmo tamanho: a minimalista a 0,8 (barra de 0,78 x largura) e as
    --    outras (barra = largura) a 0,8 x 0,78 = 0,624, para a barra ter a mesma medida.
    local enemy = bar.bdo or bar.marks
    local sel = enemy and 1.3 or (cfg.selectedScale or 1)
    local size = bar.minimal and 0.8 or (enemy and 0.624 or 1)
    local scale = (bar.baseScale or 1) * size * (isTarget and sel or 1)
    if bar.appliedScale ~= scale then
        bar.appliedScale = scale
        bar:SetScale(scale)
    end
end

local function IsPlateUnitDead(u)
    if not u then return false end
    local ok, dead = pcall(UnitIsDeadOrGhost, u)
    if ok and not Azaath.IsSecret(dead) and dead then return true end
    local okH, hp = pcall(UnitHealth, u)
    if okH and not Azaath.IsSecret(hp) and hp == 0 then return true end
    return false
end

local function Refresh(bar)
    local u = bar.displayUnit
    if IsPlateUnitDead(u) then
        bar:SetAlpha(0)
    else
        bar:SetAlpha(1)
        E().UpdateHealth(bar, true)
        E().UpdateInfo(bar)
    end
end

--------------------------------------------------------------------------------
-- Estados: mouse por cima, alvo selecionado e aggro em você
--------------------------------------------------------------------------------
-- (respostas secretas ou com erro contam como "não")
local function UnitIs(a, b)
    local ok, v = pcall(UnitIsUnit, a, b)
    if not ok or Azaath.IsSecret(v) then return false end
    return v and true or false
end

-- Aggro: pela tabela de ameaça (2 ou 3 = você é o tanque desse inimigo); se
-- o jogo não responder, vale "o inimigo está mirando em você"
local function HasAggro(unit)
    local ok, s = pcall(UnitThreatSituation, "player", unit)
    if ok and not Azaath.IsSecret(s) and s then return s >= 2 end
    return UnitIs(unit .. "target", "player")
end

local function UpdateState(bar)
    if not bar or not bar.displayUnit then return end
    local u = bar.displayUnit
    local state
    if UnitIs(u, "target") then
        state = "target"
    elseif UnitIs(u, "mouseover") then
        state = "mouseover"
    end
    if UnitIs(u, "mouseover") then hovered = bar end

    if bar.kind == "utility" then
        if bar.hlState ~= state then
            bar.hlState = state
            UpdateUtilityInfo(bar)
        end
        return
    end

    if bar.kind == "ally" then
        if bar.hlState ~= state then
            bar.hlState = state
            UpdateAllyInfo(bar)
            PlaceAlly(bar)
        end
        return
    end

    E().SetState(bar, state, HasAggro(u))
    -- alvo: a seta fica logo acima do nome e os efeitos sobem para cima dela
    local lifted = state == "target"
    if bar.auraContainer and bar.aurasLifted ~= lifted then
        bar.aurasLifted = lifted
        local y = bar.nameGap + bar.nameSize + 3 + (lifted and (bar.targetMarkH or 0) or 0)
        bar.auraContainer:ClearAllPoints()
        bar.auraContainer:SetPoint("BOTTOMLEFT", bar.health, "TOPLEFT", 0, y)
    end
end

local function UpdateAllStates()
    hovered = nil
    for _, bar in pairs(active) do UpdateState(bar) end
end

local function UpdateQuest(bar)
    if not bar or bar.kind == "ally" or bar.kind == "utility" or not bar.displayUnit then return end
    E().SetQuest(bar, IsQuestUnit(bar.displayUnit))
end

-- o registro de missões muda várias vezes seguidas: junta numa só leitura
local questPending = false
local function UpdateAllQuests()
    if questPending then return end
    questPending = true
    C_Timer.After(0.2, function()
        questPending = false
        for _, bar in pairs(active) do pcall(UpdateQuest, bar) end
        if UpdateUtilityPlates then pcall(UpdateUtilityPlates) end
    end)
end

-- O jogo avisa quando o mouse entra numa unidade, mas não quando sai:
-- enquanto houver uma placa com o mouse, confere a cada 0,1 s
local hoverWatch = CreateFrame("Frame")
hoverWatch:Hide()
hoverWatch.elapsed = 0
hoverWatch:SetScript("OnUpdate", function(self, e)
    self.elapsed = self.elapsed + e
    if self.elapsed < 0.1 then return end
    self.elapsed = 0
    if not hovered or not hovered.displayUnit or not UnitIs(hovered.displayUnit, "mouseover") then
        UpdateAllStates()
        if not hovered then self:Hide() end
    end
end)

local function AttachAlly(unit, plate, isPet)
    local f = table.remove(allyPool) or NewAlly()
    f.plate, f.displayUnit, f.combatShown = plate, unit, nil
    f.isPet = isPet
    f.diamond:Show()
    f:SetAlpha(1)
    f.baseScale = isPet and (cfg.petScale or 0.72) or 1 -- pet: mesma placa, menor
    f:SetParent(plate)
    f:SetFrameLevel(plate:GetFrameLevel() + 5)
    AllyLevels(f)
    active[unit] = f
    HideBlizzard(plate)
    ApplyScale(f)
    f:Show()
    -- atualiza estado inicial (alvo/mouseover), depois nome (mede a largura) e vida
    pcall(UpdateState, f)
    local ok, err = pcall(UpdateAllyInfo, f)
    if not ok then Azaath.LogError("Nameplates aliado info: " .. tostring(err)) end
    ok, err = pcall(UpdateAllyHealth, f, true)
    if not ok then Azaath.LogError("Nameplates aliado vida: " .. tostring(err)) end
end

local function AttachUtility(unit, plate, utilInfo)
    local f = table.remove(utilityPool) or NewUtility()
    f.plate, f.displayUnit = plate, unit
    f.utilityInfo = utilInfo
    f.baseScale = 1
    f:SetParent(plate)
    f:SetFrameLevel(plate:GetFrameLevel() + 5)
    active[unit] = f
    HideBlizzard(plate)
    ApplyScale(f)
    f:Show()
    pcall(UpdateState, f)
    pcall(UpdateUtilityInfo, f)
end

local function RetryCheckUtility(unit)
    if not (cfg and cfg.utilityNPCs ~= false) or not (_G.C_Timer and C_Timer.After) then return end
    local expectedGuid = UnitGUID and UnitGUID(unit)
    if expectedGuid and Azaath.IsSecret(expectedGuid) then expectedGuid = nil end
    local delays = { 0.15, 0.35, 0.7, 1.2, 2.0 }
    for _, d in ipairs(delays) do
        C_Timer.After(d, function()
            if not active[unit] then
                if expectedGuid and UnitGUID then
                    local curGuid = UnitGUID(unit)
                    if Azaath.IsSecret(curGuid) or curGuid ~= expectedGuid then return end
                end
                local p = GetPlate(unit)
                if p and p:IsShown() then
                    local info = DetectNPCUtility(unit)
                    if info then
                        AttachUtility(unit, p, info)
                    end
                end
            end
        end)
    end
end

local function Attach(unit)
    if active[unit] then Detach(unit) end
    local enemy = ShouldStyle(unit)
    local pet = not enemy and IsFriendlyPet(unit)
    local allyPlayer = not enemy and not pet and IsAllyPlayer(unit)
    local utilInfo = not enemy and not pet and not allyPlayer and (cfg.utilityNPCs ~= false) and DetectNPCUtility(unit)

    if not enemy and not pet and not allyPlayer and not utilInfo then
        local plate = GetPlate(unit)
        if plate then HideBlizzard(plate) end
        RetryCheckUtility(unit)
        return
    end
    local plate = GetPlate(unit)
    if not plate then return end -- placa protegida (ex.: aliados em instância)
    if not enemy then
        if utilInfo then
            return AttachUtility(unit, plate, utilInfo)
        else
            return AttachAlly(unit, plate, pet)
        end
    end

    local bar = table.remove(pool) or NewBar()
    bar.plate, bar.displayUnit = plate, unit
    bar:SetParent(plate)
    bar:SetFrameLevel(plate:GetFrameLevel() + 5)
    E().Relevel(bar)
    if bar.auraContainer then bar.auraContainer:SetFrameLevel(bar:GetFrameLevel() + 8) end
    if bar.auraContainer2 then bar.auraContainer2:SetFrameLevel(bar:GetFrameLevel() + 8) end
    bar:ClearAllPoints()
    -- centro da barra de vida no centro da placa da Blizzard
    bar:SetPoint("TOP", plate, "CENTER", 0, bar.barTop + (bar.barH or cfg.healthHeight) / 2)
    active[unit] = bar

    HideBlizzard(plate)
    ApplyScale(bar)
    bar:Show()
    local ok, err = pcall(Refresh, bar)
    if not ok then Azaath.LogError("Nameplates Refresh: " .. tostring(err)) end
    ok, err = pcall(UpdateState, bar)
    if not ok then Azaath.LogError("Nameplates estado: " .. tostring(err)) end
    ok, err = pcall(UpdateQuest, bar)
    if not ok then Azaath.LogError("Nameplates missão: " .. tostring(err)) end
    ok, err = pcall(EnableAuras, bar, unit)
    if not ok then Azaath.LogError("Nameplates auras: " .. tostring(err)) end

    if bar.castBar then
        bar.castBar:SetWidth(cfg and cfg.width or 110)
        bar.castBar.unit = unit
        bar.castBar:SetParent(bar)
        bar.castBar:ClearAllPoints()
        bar.castBar:SetPoint("TOP", bar.badge or bar, "BOTTOM", 0, -(bar.castDrop or 3))
        bar.castBar:SetFrameLevel(bar:GetFrameLevel() + 15)
        if bar.castBar.bar then bar.castBar.bar:SetFrameLevel(bar.castBar:GetFrameLevel() + 1) end
        if bar.castBar.iconFrame then bar.castBar.iconFrame:SetFrameLevel(bar.castBar:GetFrameLevel() + 2) end

        -- Registra eventos de conjuração específicos desta unidade (nameplateN)
        bar.castBar:UnregisterAllEvents()
        for e in pairs(CAST_EVENTS) do
            if bar.castBar.RegisterUnitEvent then
                bar.castBar:RegisterUnitEvent(e, unit)
            else
                bar.castBar:RegisterEvent(e)
            end
        end

        bar.castBar:SetScript("OnUpdate", CastBar_OnUpdate)
        if not StartCast(bar.castBar, false) then
            StartCast(bar.castBar, true)
        end
    end
end

UpdateUtilityPlates = function()
    local toDetach = nil
    for u, bar in pairs(active) do
        if bar.kind == "utility" then
            local newInfo = DetectNPCUtility(u)
            if newInfo then
                bar.utilityInfo = newInfo
                UpdateUtilityInfo(bar)
            else
                if not toDetach then toDetach = {} end
                toDetach[#toDetach + 1] = u
            end
        end
    end

    if toDetach then
        for i = 1, #toDetach do
            local u = toDetach[i]
            local bar = active[u]
            local plate = bar and bar.plate or GetPlate(u)
            Detach(u)
            if plate then
                HideBlizzard(plate)
            end
        end
    end

    if (cfg and cfg.utilityNPCs ~= false) and C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local u = plate.namePlateUnitToken
            if u and not active[u] and not ShouldStyle(u) and not IsFriendlyPet(u) and not IsAllyPlayer(u) then
                local info = DetectNPCUtility(u)
                if info then
                    AttachUtility(u, plate, info)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local HEALTH_EVENTS = {
    UNIT_HEALTH = true, UNIT_MAXHEALTH = true, UNIT_FLAGS = true,
    UNIT_CONNECTION = true, UNIT_DYNAMIC_FLAGS = true,
}
local INFO_EVENTS = {
    UNIT_NAME_UPDATE = true, UNIT_LEVEL = true, UNIT_CLASSIFICATION_CHANGED = true,
}

local function AttachExisting()
    if not (C_NamePlate and C_NamePlate.GetNamePlates) then return end
    for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
        local u = plate.namePlateUnitToken
        if u then Attach(u) end
    end
end

--------------------------------------------------------------------------------
-- Nomes no mundo do WoW (texto 3D) de aliados e pets
--------------------------------------------------------------------------------
-- Além do alcance das placas (nameplateMaxDistance) o jogo mostra o nome
-- padrão do WoW, que addons não conseguem estilizar. Como no Azaath, só
-- mostramos o nome dentro do alcance (placa Azaath): os nomes no mundo de
-- jogadores aliados e pets ficam desligados. Os valores originais ficam
-- guardados em nameplates.savedWorldNames e voltam ao desligar a opção.
local WORLD_NAME_CVARS = {
    "UnitNameFriendlyPlayerName", "UnitNameFriendlyPetName",
    "UnitNameFriendlyGuardianName", "UnitNameFriendlyTotemName",
}

local function GetCV(name)
    if _G.C_CVar and C_CVar.GetCVar then return C_CVar.GetCVar(name) end
    return GetCVar and GetCVar(name)
end

-- Só grava se mudou: SetCVar dispara CVAR_UPDATE na hora e contamina o código
-- da Blizzard que reage a ele (erros de valor secreto nos quadros compactos)
local function SetCV(name, value)
    local ok, cur = pcall(GetCV, name)
    if ok and cur ~= nil and tostring(cur) == tostring(value) then return true end
    if _G.C_CVar and C_CVar.SetCVar then return pcall(C_CVar.SetCVar, name, value) end
    return pcall(SetCVar, name, value)
end

local function ApplyWorldNames()
    if cfg and cfg.enabled then
        if cfg.utilityNPCs ~= false or cfg.allies ~= false then
            SetCV("nameplateShowFriends", "1")
        end
        if cfg.allies ~= false then
            SetCV("nameplateShowFriendlyPlayers", "1")
        end
        if cfg.pets ~= false then
            SetCV("nameplateShowFriendlyMinions", "1")
        end
        if cfg.utilityNPCs ~= false then
            SetCV("nameplateShowFriendlyNPCs", "1")
        end
    end
    if cfg.hideWorldNames and cfg.enabled then
        if type(cfg.savedWorldNames) ~= "table" then
            local saved = {}
            for _, name in ipairs(WORLD_NAME_CVARS) do
                local ok, v = pcall(GetCV, name)
                if ok and v ~= nil then saved[name] = tostring(v) end
            end
            cfg.savedWorldNames = saved
        end
        for _, name in ipairs(WORLD_NAME_CVARS) do
            if cfg.savedWorldNames[name] ~= nil then SetCV(name, "0") end
        end
    elseif type(cfg.savedWorldNames) == "table" then
        for name, v in pairs(cfg.savedWorldNames) do
            SetCV(name, cfg.forceShowWorldNames and "1" or v)
        end
        cfg.savedWorldNames = nil
        cfg.forceShowWorldNames = nil
    elseif cfg.forceShowWorldNames then
        for _, name in ipairs(WORLD_NAME_CVARS) do
            SetCV(name, "1")
        end
        cfg.forceShowWorldNames = nil
    end
end

local function ApplyNameplateSizes()
    if InCombatLockdown and InCombatLockdown() then return end
    if not _G.C_NamePlate then return end

    local clickable = (cfg and cfg.friendlyClickable ~= false)
    if C_NamePlate.SetNamePlateFriendlyClickThrough then
        pcall(C_NamePlate.SetNamePlateFriendlyClickThrough, not clickable)
    end
    SetCV("namePlateFriendlyClickThrough", clickable and "0" or "1")

    if C_NamePlate.SetNamePlateFriendlySize then
        local w = (cfg and cfg.allyBarWidth and (cfg.allyBarWidth + 24)) or 128
        pcall(C_NamePlate.SetNamePlateFriendlySize, w, 30)
    end

    if C_NamePlate.SetNamePlateEnemyClickThrough then
        pcall(C_NamePlate.SetNamePlateEnemyClickThrough, false)
    end
    SetCV("namePlateEnemyClickThrough", "0")

    if C_NamePlate.SetNamePlateEnemySize then
        local w = (cfg and cfg.width) or 110
        pcall(C_NamePlate.SetNamePlateEnemySize, w, 32)
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit, ...)
    if event == "NAME_PLATE_UNIT_ADDED" then
        Attach(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        Detach(unit)
    elseif event == "UNIT_FACTION" then
        -- pode ter virado inimigo (ou deixado de ser): reavalia a placa
        if unit and unit:find("^nameplate") then Attach(unit) end
    elseif HEALTH_EVENTS[event] then
        local bar = active[unit]
        if bar then
            if bar.kind == "utility" then
                -- utilitário não tem barra de vida
            elseif bar.kind == "ally" then
                UpdateAllyHealth(bar)
            else
                if IsPlateUnitDead(unit) then
                    bar:SetAlpha(0)
                else
                    bar:SetAlpha(1)
                    E().UpdateHealth(bar)
                end
            end
        end
    elseif INFO_EVENTS[event] then
        local bar = active[unit]
        if bar then
            if bar.kind == "utility" then
                UpdateUtilityInfo(bar)
            elseif bar.kind == "ally" then
                UpdateAllyInfo(bar)
            else
                E().UpdateInfo(bar)
            end
        elseif event == "UNIT_NAME_UPDATE" and unit and unit:find("^nameplate") and cfg and cfg.utilityNPCs ~= false then
            if not ShouldStyle(unit) and not IsFriendlyPet(unit) and not IsAllyPlayer(unit) then
                local p = GetPlate(unit)
                if p and p:IsShown() then
                    local info = DetectNPCUtility(unit)
                    if info then AttachUtility(unit, p, info) end
                end
            end
        end
    elseif CAST_EVENTS[event] then
        local bar = unit and active[unit]
        if bar and bar.castBar then
            HandleCastEvent(bar.castBar, event, ...)
        else
            for u, b in pairs(active) do
                if b.castBar and UnitIs(u, unit) then
                    HandleCastEvent(b.castBar, event, ...)
                    break
                end
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        for _, bar in pairs(active) do ApplyScale(bar) end
        UpdateAllStates()
        if (cfg and cfg.utilityNPCs ~= false) and C_NamePlate and C_NamePlate.GetNamePlates then
            local tPlate = C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("target")
            if tPlate then
                local u = tPlate.namePlateUnitToken
                if u and not active[u] and not ShouldStyle(u) and not IsFriendlyPet(u) and not IsAllyPlayer(u) then
                    local guid = UnitGUID("target")
                    if guid then utilityCache[guid] = nil end
                    local info = DetectNPCUtility(u)
                    if info then
                        AttachUtility(u, tPlate, info)
                    end
                end
            end
        end
        for u, b in pairs(active) do
            if b.castBar and UnitIs(u, "target") then
                if not (b.castBar.casting or b.castBar.channeling) then
                    if not StartCast(b.castBar, false) then
                        StartCast(b.castBar, true)
                    end
                end
                break
            end
        end
    elseif event == "QUEST_LOG_UPDATE" or event == "UNIT_QUEST_LOG_CHANGED" then
        if utilityCache then
            if _G.wipe then wipe(utilityCache) else for k in pairs(utilityCache) do utilityCache[k] = nil end end
        end
        UpdateAllQuests()
    elseif event == "GOSSIP_SHOW" then
        local guid = GetInteractingNPCGUID()
        if guid then
            local hasTurnIn = false
            local hasAvailable = false
            if Azaath.API and Azaath.API.GossipActiveQuests then
                local act = Azaath.API.GossipActiveQuests() or {}
                if #act > 0 then
                    hasTurnIn = true
                end
            end
            if Azaath.API and Azaath.API.GossipAvailableQuests then
                local av = Azaath.API.GossipAvailableQuests() or {}
                if #av > 0 then
                    hasAvailable = true
                end
            end

            -- Detecta se é Estalajadeiro pelo menu de Gossip (opção de definir o lar / binder)
            local isInnkeeper = false
            local GI = _G.C_GossipInfo
            if GI and GI.GetOptions then
                local opts = GI.GetOptions()
                if type(opts) == "table" then
                    for _, opt in ipairs(opts) do
                        if opt then
                            local oKind = tostring(opt.type or opt.icon or ""):lower()
                            local oName = tostring(opt.name or ""):lower()
                            if oKind:find("binder") or oKind:find("132057") or oKind:find("132058")
                               or oName:find("estalagem") or oName:find("lar") or oName:find("home")
                               or oName:find("hearth") then
                                isInnkeeper = true
                                break
                            end
                        end
                    end
                end
            end

            npcQuestState[guid] = {
                hasTurnIn = hasTurnIn,
                hasAvailable = hasAvailable,
                noQuests = (not hasTurnIn and not hasAvailable),
                lastCheck = GetTime(),
            }
            if isInnkeeper then
                utilityCache[guid] = {
                    type = "inn",
                    icon = UTILITY_ICONS.inn,
                    subtitle = GetNPCSubtitle("target") or "Estalagem",
                }
            else
                utilityCache[guid] = nil
            end
            UpdateUtilityPlates()
        end
    elseif event == "QUEST_GREETING" then
        local guid = GetInteractingNPCGUID()
        if guid then
            local nAct = GetNumActiveQuests and GetNumActiveQuests() or 0
            local nAvail = GetNumAvailableQuests and GetNumAvailableQuests() or 0
            npcQuestState[guid] = {
                hasTurnIn = (nAct > 0),
                hasAvailable = (nAvail > 0),
                noQuests = (nAct == 0 and nAvail == 0),
                lastCheck = GetTime(),
            }
            utilityCache[guid] = nil
            UpdateUtilityPlates()
        end
    elseif event == "QUEST_PROGRESS" or event == "QUEST_COMPLETE" then
        local guid = GetInteractingNPCGUID()
        if guid then
            local cur = npcQuestState[guid]
            npcQuestState[guid] = {
                hasTurnIn = true,
                hasAvailable = cur and cur.hasAvailable or false,
                noQuests = false,
                lastCheck = GetTime(),
            }
            utilityCache[guid] = nil
            UpdateUtilityPlates()
        end
    elseif event == "QUEST_DETAIL" then
        local guid = GetInteractingNPCGUID()
        if guid then
            local cur = npcQuestState[guid]
            npcQuestState[guid] = {
                hasTurnIn = cur and cur.hasTurnIn or false,
                hasAvailable = true,
                noQuests = false,
                lastCheck = GetTime(),
            }
            utilityCache[guid] = nil
            UpdateUtilityPlates()
        end
    elseif event == "QUEST_TURNED_IN" then
        local guid = GetInteractingNPCGUID()
        if guid then
            local cur = npcQuestState[guid]
            if cur then
                cur.hasTurnIn = false
                cur.turnedInTime = GetTime()
            else
                npcQuestState[guid] = {
                    hasTurnIn = false,
                    hasAvailable = false,
                    noQuests = false,
                    turnedInTime = GetTime(),
                    lastCheck = GetTime(),
                }
            end
            utilityCache[guid] = nil
        end
        if _G.wipe then wipe(utilityCache) else for k in pairs(utilityCache) do utilityCache[k] = nil end end
        UpdateUtilityPlates()
        if _G.C_Timer and C_Timer.After then
            C_Timer.After(0.2, UpdateUtilityPlates)
            C_Timer.After(0.5, UpdateUtilityPlates)
        end
    elseif event == "QUEST_ACCEPTED" then
        local guid = GetInteractingNPCGUID()
        if guid and npcQuestState[guid] then
            npcQuestState[guid].hasAvailable = false
            utilityCache[guid] = nil
        end
        if _G.wipe then wipe(utilityCache) else for k in pairs(utilityCache) do utilityCache[k] = nil end end
        UpdateUtilityPlates()
        UpdateAllQuests()
    elseif event == "QUEST_FINISHED" or event == "GOSSIP_CLOSED" then
        local guid = GetInteractingNPCGUID()
        if guid and npcQuestState[guid] then
            if not npcQuestState[guid].hasAvailable then
                npcQuestState[guid].noQuests = true
                npcQuestState[guid].hasTurnIn = false
            end
            utilityCache[guid] = nil
        end
        UpdateUtilityPlates()
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        UpdateAllStates()
        if hovered then hoverWatch:Show() end
        if (cfg and cfg.utilityNPCs ~= false) and C_NamePlate and C_NamePlate.GetNamePlates then
            local moPlate = C_NamePlate.GetNamePlateForUnit and C_NamePlate.GetNamePlateForUnit("mouseover")
            if moPlate then
                local u = moPlate.namePlateUnitToken
                if u and not active[u] and not ShouldStyle(u) and not IsFriendlyPet(u) and not IsAllyPlayer(u) then
                    local guid = UnitGUID("mouseover")
                    if guid then utilityCache[guid] = nil end
                    local info = DetectNPCUtility(u)
                    if info then AttachUtility(u, moPlate, info) end
                end
            else
                for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
                    local u = plate.namePlateUnitToken
                    if u and not active[u] and UnitIs(u, "mouseover") then
                        local guid = UnitGUID("mouseover")
                        if guid then utilityCache[guid] = nil end
                        local info = DetectNPCUtility(u)
                        if info then AttachUtility(u, plate, info) end
                        break
                    end
                end
            end
        end
    elseif event == "TAXIMAP_OPENED" then
        local guid = GetInteractingNPCGUID()
        if guid then
            utilityCache[guid] = {
                type = "flight",
                icon = UTILITY_ICONS.flight,
                subtitle = GetNPCSubtitle("target") or DEFAULT_SUBTITLES.flight,
            }
            UpdateUtilityPlates()
        end
    elseif event == "MERCHANT_SHOW" then
        local guid = GetInteractingNPCGUID()
        if guid then
            local canRepair = _G.CanMerchantRepair and CanMerchantRepair()
            local uType = canRepair and "repair" or "vendor"
            local icon = canRepair and UTILITY_ICONS.repair or UTILITY_ICONS.vendor
            local sub = GetNPCSubtitle("target") or (canRepair and "Conserto" or "Comerciante")
            utilityCache[guid] = {
                type = uType,
                icon = icon,
                subtitle = sub,
            }
            UpdateUtilityPlates()
        end
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE"
        or event == "UNIT_TARGET" then
        local bar = unit and active[unit]
        if bar then
            UpdateState(bar)
        elseif event ~= "UNIT_TARGET" then -- alvo de outro (grupo, pet): ignora
            UpdateAllStates()
        end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        if event == "PLAYER_REGEN_ENABLED" then
            pcall(ApplyNameplateSizes)
        end
        -- moldura de combate de quem entrou/saiu de combate junto com você
        for _, bar in pairs(active) do
            if bar.kind == "ally" then
                UpdateAllyHealth(bar)
            elseif bar.kind ~= "utility" then
                E().UpdateHealth(bar)
            end
        end
        UpdateAllStates()
    elseif event == "PLAYER_ENTERING_WORLD" then
        pcall(ApplyWorldNames)
        if _G.C_Timer and C_Timer.After then
            C_Timer.After(0.5, function()
                if not (InCombatLockdown and InCombatLockdown()) then
                    pcall(ApplyWorldNames)
                    AttachExisting()
                end
            end)
        end
        for u in pairs(active) do Detach(u) end
        AttachExisting()
    elseif event == "GROUP_ROSTER_UPDATE" then
        for _, bar in pairs(active) do
            if bar and bar.kind == "ally" then
                pcall(UpdateAllyInfo, bar)
                pcall(UpdateAllyHealth, bar, true)
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:OnInitialize()
    cfg = Azaath.db.nameplates
    -- 07/11/2026: barra mais fina e efeitos em ícones pequenos (só uma vez)
    if cfg and (cfg.layout or 0) < 4 then
        cfg.healthHeight, cfg.auraSize, cfg.auraScale = 8, 14, nil
        cfg.maxAuras = nil
        cfg.layout = 4
    end
    -- 10/11/2026: placas menores e mais discretas (tela menos poluída)
    if cfg and (cfg.layout or 0) < 5 then
        cfg.width, cfg.healthHeight, cfg.nameFont, cfg.auraSize = 110, 6, 15, 12
        cfg.layout = 5
    end
    -- 11/11/2026: tipografia dos aliados alinhada aos mobs (Cinzel 14px, sem outline)
    if cfg and (cfg.layout or 0) < 7 then
        cfg.allyNameFont = 14
        cfg.layout = 7
    end
    -- 17/11/2026: restaura placas de aliados estilo Azaath (com losango + barra em combate)
    if cfg and (cfg.layout or 0) < 12 then
        cfg.allies = true
        cfg.allyNameFont = 14
        cfg.hideWorldNames = true
        cfg.forceShowWorldNames = nil
        cfg.layout = 12
    end
    if cfg and cfg.utilityNPCs == nil then
        cfg.utilityNPCs = true
    end
    if cfg and cfg.castBar == nil then
        cfg.castBar = true
    end
    if cfg and cfg.friendlyClickable == nil then
        cfg.friendlyClickable = true
    end
end

function M:Test()
    local tested = 0
    for u, bar in pairs(active) do
        if bar and bar.castBar then
            local cb = bar.castBar
            cb.casting = true
            cb.channeling = false
            cb.notInterruptible = false
            cb.interrupted = false
            cb.holdTime = 0
            cb.fadeOut = false
            cb.duration = nil
            cb.isTest = true
            cb.startTime = GetTime()
            cb.endTime = cb.startTime + 3
            cb.durationVal = 3
            if cb.bar.SetTimerDuration then
                pcall(cb.bar.SetTimerDuration, cb.bar, nil)
            end
            cb.bar:SetMinMaxValues(0, 3)
            cb.bar:SetValue(0)
            cb.bar:SetStatusBarColor(CAST_COLORS.cast[1], CAST_COLORS.cast[2], CAST_COLORS.cast[3])
            cb.icon:SetTexture("Interface\\Icons\\Spell_Fire_FlameBolt")
            cb.iconFrame:Show()
            cb.spellName:SetText("Bola de Fogo (Teste)")
            cb.spellName:SetTextColor(Azaath.colors.cream[1], Azaath.colors.cream[2], Azaath.colors.cream[3])
            cb.timeText:SetText("3.0s")
            cb:SetAlpha(1)
            cb:Show()
            cb:SetScript("OnUpdate", CastBar_OnUpdate)
            tested = tested + 1
        end
    end
    if tested > 0 then
        Azaath:Print(("Barra de conjuração exibida em %d placa(s) ativa(s) para teste."):format(tested))
    else
        Azaath:Print("Nenhuma placa de inimigo visível no momento para testar. Aproxime-se de um mob.")
    end
end

function M:OnEnable()
    if cfg then
        local ok, err = pcall(ApplyWorldNames)
        if not ok then Azaath.LogError("Nameplates nomes no mundo: " .. tostring(err)) end
        ok, err = pcall(ApplyNameplateSizes)
        if not ok then Azaath.LogError("Nameplates tamanhos: " .. tostring(err)) end
    end
    if not (cfg and cfg.enabled) then return end
    if not (_G.C_NamePlate and Azaath.AzBar) then return end

    holder = CreateFrame("Frame", nil, UIParent)
    holder:Hide()

    Azaath.SafeRegister(events, "NAME_PLATE_UNIT_ADDED")
    Azaath.SafeRegister(events, "NAME_PLATE_UNIT_REMOVED")
    Azaath.SafeRegister(events, "UNIT_FACTION")
    Azaath.SafeRegister(events, "PLAYER_TARGET_CHANGED")
    Azaath.SafeRegister(events, "UPDATE_MOUSEOVER_UNIT")
    Azaath.SafeRegister(events, "MERCHANT_SHOW")
    Azaath.SafeRegister(events, "TAXIMAP_OPENED")
    Azaath.SafeRegister(events, "QUEST_LOG_UPDATE")
    Azaath.SafeRegister(events, "UNIT_QUEST_LOG_CHANGED")
    Azaath.SafeRegister(events, "GOSSIP_SHOW")
    Azaath.SafeRegister(events, "GOSSIP_CLOSED")
    Azaath.SafeRegister(events, "QUEST_GREETING")
    Azaath.SafeRegister(events, "QUEST_DETAIL")
    Azaath.SafeRegister(events, "QUEST_PROGRESS")
    Azaath.SafeRegister(events, "QUEST_COMPLETE")
    Azaath.SafeRegister(events, "QUEST_ACCEPTED")
    Azaath.SafeRegister(events, "QUEST_TURNED_IN")
    Azaath.SafeRegister(events, "QUEST_FINISHED")
    Azaath.SafeRegister(events, "UNIT_THREAT_SITUATION_UPDATE")
    Azaath.SafeRegister(events, "UNIT_THREAT_LIST_UPDATE")
    Azaath.SafeRegister(events, "UNIT_TARGET")
    Azaath.SafeRegister(events, "PLAYER_REGEN_DISABLED")
    Azaath.SafeRegister(events, "PLAYER_REGEN_ENABLED")
    Azaath.SafeRegister(events, "PLAYER_ENTERING_WORLD")
    Azaath.SafeRegister(events, "GROUP_ROSTER_UPDATE")
    for e in pairs(HEALTH_EVENTS) do Azaath.SafeRegister(events, e) end
    for e in pairs(INFO_EVENTS) do Azaath.SafeRegister(events, e) end
    for e in pairs(CAST_EVENTS) do Azaath.SafeRegister(events, e) end

    AttachExisting() -- placas que já estavam na tela (após /reload)
end

function M:Apply()
    pcall(ApplyWorldNames)
    pcall(ApplyNameplateSizes)
    for _, bar in pairs(active) do
        ApplyScale(bar)
        if bar.kind == "ally" then
            UpdateAllyInfo(bar)
            PlaceAlly(bar)
        elseif bar.kind == "utility" then
            UpdateUtilityInfo(bar)
            PlaceUtility(bar)
        end
    end
end
