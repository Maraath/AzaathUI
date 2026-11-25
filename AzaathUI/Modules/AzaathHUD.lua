--[[----------------------------------------------------------------------------
    AzaathUI - Modules/AzaathHUD.lua
    Skin "Azaath": HUD única recortada da arte de conceito de 15/11/2026
    (tools/actionbar-concept/concept.png -> gen.js -> Media/Azaath/*.tga e
    Modules/AzaathLayoutData.lua). Tudo é posicionado em px do conceito.

      * painéis esquerdo/direito: são a Opção 4 das barras (ActionBars.lua,
        Azaath.AzaathPanelArt), soltos da HUD e livres no Modo de Edição;
      * moldura central: recurso (fogo laranja com chama correndo), vida
        carmim "atual / máx", XP ciano com "XP 85.3%", medalhão com o nível;
      * efeitos: gemas e filetes ciano pulsando, fagulhas nas pontas das
        barras, clarão branco no dano e anel de energia nos botões com proc.

    Valores secretos (combate, cliente moderno): vida e recurso só são
    repassados aos widgets (StatusBar:SetValue, SetFormattedText), sem
    comparações; o clarão de dano usa o valor anterior, sem conta.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("AzaathHUD")

local A -- Azaath.AZAATH (Modules/AzaathLayoutData.lua)
local hud, art = nil, {}
local health, healthTrail, healthText, power, flame, powerSpark, xpBar, xpSpark, xpText, levelText
local playerButton
local anchors = {}

local function Tex(name) return Azaath.media.path .. "Azaath\\" .. name end
local function IsAzaath() return Azaath.IsAzaath and Azaath.IsAzaath() and Azaath.AZAATH ~= nil end
local function IsReforgedBars() return Azaath.IsReforgedBars and Azaath.IsReforgedBars() end

-- A HUD é só a peça central: coordenadas do conceito menos o x dela
local CX = 0

-- Coordenadas do conceito -> ponto TOPLEFT na HUD
local function Place(region, x, y, w, h, parent)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent or hud, "TOPLEFT", x - CX, -y)
    if w then region:SetSize(w, h) end
end

--------------------------------------------------------------------------------
-- Arte de uma peça do conceito (1 = painel esquerdo, 2 = moldura central,
-- 3 = painel direito) no canto superior esquerdo de `frame`, com as gemas e
-- filetes ciano pulsando (camada aditiva de meia resolução). Usada pela HUD e
-- pelas barras Reforged (ActionBars.lua).
--------------------------------------------------------------------------------
local PIECE_NAMES = { "Left", "HudCenter", "Right" }
function Azaath.AzaathPanelArt(frame, idx, glowParent)
    local AA = Azaath.AZAATH
    local p = AA.pieces[idx]
    local t = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    t:SetTexture(Tex(PIECE_NAMES[idx]))
    t:SetTexCoord(0, p.w / 512, 0, AA.hud.h / 512)
    t:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    t:SetSize(p.w, AA.hud.h)
    local glow = (glowParent or frame):CreateTexture(nil, glowParent and "ARTWORK" or "BORDER")
    glow:SetTexture(Tex("HudGlow"))
    glow:SetTexCoord(p.x / 2 / 1024, (p.x + p.w) / 2 / 1024, 0, (AA.hud.h / 2) / 256)
    glow:SetAllPoints(t)
    glow:SetBlendMode("ADD")
    local ag = glow:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local fade = ag:CreateAnimation("Alpha")
    fade:SetFromAlpha(0.15)
    fade:SetToAlpha(0.75)
    fade:SetDuration(1.8)
    if fade.SetSmoothing then fade:SetSmoothing("IN_OUT") end
    return { art = t, glow = glow, anim = ag }
end

-- Liga/desliga o pulso conforme azaath.glow
function Azaath.AzaathGlowApply(o)
    if not o then return end
    local cfg = Azaath.db.azaath or {}
    if cfg.glow ~= false then
        o.glow:Show()
        if not o.anim:IsPlaying() then o.anim:Play() end
    else
        o.anim:Stop()
        o.glow:Hide()
    end
end

--------------------------------------------------------------------------------
-- Moldura central (arte + brilho)
--------------------------------------------------------------------------------
local function BuildArt()
    local glowFrame = CreateFrame("Frame", nil, hud)
    glowFrame:SetAllPoints(hud)
    glowFrame:SetFrameLevel(hud:GetFrameLevel() + 6)
    art = Azaath.AzaathPanelArt(hud, 2, glowFrame)
end

--------------------------------------------------------------------------------
-- Barras
--------------------------------------------------------------------------------
local function NewBar(r, texName, level)
    local b = CreateFrame("StatusBar", nil, hud)
    Place(b, r.x, r.y, r.w, r.h)
    b:SetStatusBarTexture(Tex(texName))
    b:SetMinMaxValues(0, 1)
    b:SetValue(0)
    b:SetFrameLevel(hud:GetFrameLevel() + (level or 2))
    return b
end

local function Text(parent, font, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, "")
    fs:SetTextColor(r, g, b)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    return fs
end

local function BuildBars()
    local media = Azaath.media
    local fontR = media.fontCardR or media.font

    -- Recurso: fogo laranja + chama correndo + fagulha na ponta
    power = NewBar(A.power, "PowerFill", 2)
    local ptex = power:GetStatusBarTexture()
    flame = power:CreateTexture(nil, "OVERLAY")
    flame:SetTexture(Tex("Flame"), "REPEAT", "CLAMP")
    flame:SetHorizTile(true)
    flame:SetAllPoints(ptex)
    flame:SetBlendMode("ADD")
    flame:SetAlpha(0.35)
    powerSpark = power:CreateTexture(nil, "OVERLAY", nil, 2)
    powerSpark:SetTexture(Tex("PowerSpark"))
    powerSpark:SetBlendMode("ADD")
    powerSpark:SetSize(A.powerSpark.w, A.powerSpark.h)
    -- a ponta do conceito (powerTip) cai na borda direita do preenchimento
    local sx = (A.powerSpark.x - A.power.x) - A.powerTip
    local sy = (A.powerSpark.y + A.powerSpark.h / 2) - (A.power.y + A.power.h / 2)
    powerSpark:SetPoint("LEFT", ptex, "RIGHT", sx, -sy)

    -- Vida: clarão branco atrás do carmim (mostra o pedaço perdido)
    healthTrail = NewBar(A.health, "HealthFill", 2)
    healthTrail:GetStatusBarTexture():SetVertexColor(1, 1, 1)
    healthTrail:GetStatusBarTexture():SetBlendMode("ADD")
    healthTrail:SetAlpha(0)
    health = NewBar(A.health, "HealthFill", 3)
    local htop = CreateFrame("Frame", nil, hud)
    htop:SetAllPoints(health)
    htop:SetFrameLevel(hud:GetFrameLevel() + 8)
    healthText = Text(htop, fontR, 22, 0.96, 0.93, 0.93)
    healthText:SetPoint("CENTER", hud, "TOPLEFT", A.healthText[1] - CX, -A.healthText[2])

    -- XP: ciano + fagulha + "XP 85.3%"
    xpBar = NewBar(A.xp, "XPFill", 2)
    local xtex = xpBar:GetStatusBarTexture()
    xpSpark = xpBar:CreateTexture(nil, "OVERLAY", nil, 2)
    xpSpark:SetTexture(Tex("XPSpark"))
    xpSpark:SetBlendMode("ADD")
    xpSpark:SetSize(A.xpSpark.w, A.xpSpark.h)
    local xx = (A.xpSpark.x - A.xp.x) - A.xpTip
    local xy = (A.xpSpark.y + A.xpSpark.h / 2) - (A.xp.y + A.xp.h / 2)
    xpSpark:SetPoint("LEFT", xtex, "RIGHT", xx, -xy)
    xpText = Text(htop, fontR, 13, 0.60, 0.70, 0.72)
    xpText:SetPoint("LEFT", hud, "TOPLEFT", A.xpText[1] - CX, -A.xpText[2])

    -- Nível no medalhão (serifa clássica, ciano claro, halo suave)
    local halo = htop:CreateTexture(nil, "ARTWORK")
    halo:SetTexture(Azaath.media.path .. "Glow")
    halo:SetVertexColor(0.30, 0.85, 0.95)
    halo:SetBlendMode("ADD")
    halo:SetAlpha(0.22)
    halo:SetSize(46, 46)
    halo:SetPoint("CENTER", hud, "TOPLEFT", A.level[1] - CX, -A.level[2])
    levelText = Text(htop, media.fontCinzel or media.fontTitleB, 29, 0.74, 0.94, 0.95)
    levelText:SetPoint("CENTER", hud, "TOPLEFT", A.level[1] - CX, -A.level[2] + 1)

    -- chama correndo (só desenha quando a HUD está visível)
    local off = 0
    power:SetScript("OnUpdate", function(_, elapsed)
        off = (off + elapsed * 0.18) % 1
        flame:SetTexCoord(off, off + 1.6, 0, 1)
    end)
end

--------------------------------------------------------------------------------
-- Atualização (valores secretos: só repassa aos widgets)
--------------------------------------------------------------------------------
local unit = "player"
local trail = { active = false, hold = 0, last = nil, has = false }

-- apagar do clarão = animação nativa (sem OnUpdate + GetAlpha, que podia travar aceso)
local trailAG
local function TrailFlash()
    if not trailAG then
        trailAG = healthTrail:CreateAnimationGroup()
        local fade = trailAG:CreateAnimation("Alpha")
        fade:SetFromAlpha(0.85)
        fade:SetToAlpha(0)
        fade:SetStartDelay(0.2)
        fade:SetDuration(0.45)
        if trailAG.SetToFinalAlpha then trailAG:SetToFinalAlpha(true) end
        trailAG:SetScript("OnFinished", function()
            healthTrail:SetAlpha(0)
            healthTrail:SetValue(health:GetValue())
            trail.active = false
        end)
    end
    trail.active = true
    trailAG:Stop()
    healthTrail:SetAlpha(0.85)
    trailAG:Play()
end

local function UpdateHealth(instant)
    if not health then return end
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    health:SetMinMaxValues(0, max)
    health:SetValue(cur)
    healthTrail:SetMinMaxValues(0, max)
    if instant or not trail.has then
        if trailAG then trailAG:Stop() end
        trail.active = false
        healthTrail:SetValue(cur)
        healthTrail:SetAlpha(0)
    elseif not trail.active then
        -- o rastro fica no valor anterior, atrás do carmim: no dano sobra um
        -- pedaço claro à direita; na cura fica escondido
        healthTrail:SetValue(trail.last)
        TrailFlash()
    end
    trail.last, trail.has = cur, true

    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
        healthText:SetText(UnitIsGhost(unit) and "Fantasma" or "Morto")
    elseif Azaath.AnySecret(cur, max) then
        if not pcall(healthText.SetFormattedText, healthText, "%s / %s", cur, max) then
            healthText:SetText(cur)
        end
    else
        healthText:SetText(format("%s / %s", Azaath.Thousands and Azaath.Thousands(cur) or cur,
            Azaath.Thousands and Azaath.Thousands(max) or max))
    end
end

-- Curva de cor com alpha 0 em 0% e 1 acima: o jogo avalia a porcentagem do
-- recurso (mesmo secreta) e devolve a cor -> fagulha some com o recurso vazio
local sparkCurve
local function SparkCurve()
    if sparkCurve ~= nil then return sparkCurve or nil end
    sparkCurve = false
    if not (UnitPowerPercent and C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end
    local ok, c = pcall(function()
        local curve = C_CurveUtil.CreateColorCurve()
        if curve.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then
            pcall(curve.SetType, curve, Enum.LuaCurveType.Step)
        end
        curve:AddPoint(0, CreateColor(1, 1, 1, 0))
        curve:AddPoint(0.001, CreateColor(1, 1, 1, 1))
        curve:AddPoint(1, CreateColor(1, 1, 1, 1))
        return curve
    end)
    if ok and c then sparkCurve = c end
    return sparkCurve or nil
end

local function SparkByCurve()
    local curve = SparkCurve()
    if not curve then return false end
    return pcall(function()
        local color = UnitPowerPercent(unit, nil, false, curve)
        if not color then error("sem cor") end
        powerSpark:SetVertexColor(color:GetRGBA())
    end)
end

local function UpdatePower()
    if not power then return end
    local cur, max = UnitPower(unit), UnitPowerMax(unit)
    power:SetMinMaxValues(0, max)
    power:SetValue(cur)
    -- fagulha só com recurso (fora de combate dá para comparar; em combate fica acesa)
    if Azaath.AnySecret(cur, max) then
        powerSpark:Show()
        if not SparkByCurve() then powerSpark:SetVertexColor(1, 1, 1, 1) end
    else
        powerSpark:SetVertexColor(1, 1, 1, 1)
        powerSpark:SetShown(cur > 0)
    end
end

local function UpdateXP()
    if not xpBar then return end
    local level = UnitLevel("player")
    levelText:SetText(level or "")
    local maxLevel = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion())
        or (GetMaxPlayerLevel and GetMaxPlayerLevel()) or MAX_PLAYER_LEVEL or 80
    local atMax = (IsLevelAtEffectiveMaxLevel and IsLevelAtEffectiveMaxLevel(level))
        or (not Azaath.IsSecret(level) and level and level >= maxLevel)
    if atMax then
        xpBar:SetMinMaxValues(0, 1)
        xpBar:SetValue(1)
        xpText:SetText("")
        return
    end
    local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 1
    if Azaath.AnySecret(cur, max) then
        xpBar:SetMinMaxValues(0, max)
        xpBar:SetValue(cur)
        xpText:SetText("")
        return
    end
    if max <= 0 then max = 1 end
    xpBar:SetMinMaxValues(0, max)
    xpBar:SetValue(cur)
    xpSpark:SetShown(cur > 0)
    xpText:SetText(format("XP %.1f%%", cur / max * 100))
end

local function UpdateUnit()
    unit = (UnitHasVehicleUI and UnitHasVehicleUI("player")) and "vehicle" or "player"
    if playerButton and not InCombatLockdown() then playerButton:SetAttribute("unit", unit) end
    UpdateHealth(true)
    UpdatePower()
end

--------------------------------------------------------------------------------
-- Anel de energia nos botões com proc (SPELL_ACTIVATION_OVERLAY_GLOW_*)
--------------------------------------------------------------------------------
local overlayed = {}
local rings = setmetatable({}, { __mode = "k" })

local function GetRing(b)
    local r = rings[b]
    if r then return r end
    r = CreateFrame("Frame", nil, b)
    r:SetFrameLevel(b:GetFrameLevel() + 4) -- acima da espiral (+3), abaixo do texto (+5) e da tecla (+6)
    r:SetPoint("CENTER", b, "CENTER", 0, 0)
    r:EnableMouse(false)
    local base = r:CreateTexture(nil, "OVERLAY")
    base:SetTexture(Tex("Proc"))
    base:SetBlendMode("ADD")
    base:SetAllPoints(r)
    local spin = r:CreateTexture(nil, "OVERLAY", nil, 1)
    spin:SetTexture(Tex("Proc"))
    spin:SetBlendMode("ADD")
    spin:SetAllPoints(r)
    spin:SetAlpha(0.45)
    local ag = spin:CreateAnimationGroup()
    ag:SetLooping("REPEAT")
    local rot = ag:CreateAnimation("Rotation")
    rot:SetDegrees(-360)
    rot:SetDuration(9)
    local pulse = r:CreateAnimationGroup()
    pulse:SetLooping("BOUNCE")
    local al = pulse:CreateAnimation("Alpha")
    al:SetFromAlpha(0.7)
    al:SetToAlpha(1)
    al:SetDuration(0.6)
    r.spinAnim, r.pulseAnim = ag, pulse
    r:Hide()
    rings[b] = r
    return r
end

local function ActionSpell(action)
    if not action or not HasAction(action) then return nil end
    local kind, id = GetActionInfo(action)
    if Azaath.AnySecret(kind, id) then return nil end
    if kind == "spell" then return id end
    if kind == "macro" and GetMacroSpell then
        local ok, sid = pcall(GetMacroSpell, id)
        if ok and not Azaath.IsSecret(sid) then return sid end
    end
    return nil
end

local forcedRing -- /azaath azaath proc: mostra o anel no botão 10 da barra 1
local function UpdateRings()
    if not (A and IsReforgedBars()) then return end
    local ab = Azaath:GetModule("ActionBars")
    local list = ab and ab.buttons
    if not list then return end
    for _, b in ipairs(list) do
        local sid = ActionSpell(b.action)
        local on = (sid and overlayed[sid]) or (forcedRing == b)
        local r = rings[b]
        if on then
            r = r or GetRing(b)
            local s = (b:GetWidth() or 54) / 54 * A.proc.size * 0.94
            r:SetSize(s, s)
            if not r:IsShown() then
                r:Show()
                r.spinAnim:Play()
                r.pulseAnim:Play()
            end
        elseif r and r:IsShown() then
            r.spinAnim:Stop()
            r.pulseAnim:Stop()
            r:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- Construção / layout
--------------------------------------------------------------------------------
function Azaath.GetAzaathFrame()
    if not IsAzaath() then return nil end
    if hud then return hud end
    A = Azaath.AZAATH
    hud = CreateFrame("Frame", "AzaathUIAzaath", Azaath.root)
    CX = A.pieces[2].x
    hud:SetSize(A.pieces[2].w, A.hud.h)
    hud:SetFrameStrata("LOW")
    hud:SetFrameLevel(2)
    local cfg = Azaath.db.azaath or {}
    hud:SetScale((cfg.scale and cfg.scale > 0) and cfg.scale or 1)
    hud:SetPoint("BOTTOM", Azaath.root, "BOTTOM", cfg.offsetX or 0, cfg.offsetY or 10)
    if Azaath.ClampToScreen then Azaath.ClampToScreen(hud) end
    BuildArt()
    BuildBars()
    return hud
end

-- Âncoras para os buffs/debuffs do jogador (Auras.lua)
function Azaath.AzaathAnchor(kind)
    local f = Azaath.GetAzaathFrame()
    if not f then return nil end
    local a = anchors[kind]
    if not a then
        a = CreateFrame("Frame", nil, f)
        a:SetSize(1, 1)
        anchors[kind] = a
    end
    a:ClearAllPoints()
    local B = A.buffs
    if kind == "debuffs" then
        -- à direita da crista central, crescendo para a direita dentro da moldura
        a:SetPoint("BOTTOMLEFT", f, "TOPLEFT", A.level[1] + 28 - CX, -B.y)
    else
        a:SetPoint("BOTTOMLEFT", f, "TOPLEFT", B.x - CX, -B.y)
    end
    return a
end

function M:ApplyLayout()
    if not hud then return end
    local cfg = Azaath.db.azaath or {}
    Azaath:RunOutOfCombat(function()
        hud:SetScale((cfg.scale and cfg.scale > 0) and cfg.scale or 1)
        hud:ClearAllPoints()
        hud:SetPoint("BOTTOM", Azaath.root, "BOTTOM", cfg.offsetX or 0, cfg.offsetY or 10)
        if Azaath.ClampToScreen then Azaath.ClampToScreen(hud) end
        local auras = Azaath:GetModule("Auras")
        if auras and auras.ApplyLayout then auras:ApplyLayout() end
    end)
    Azaath.AzaathGlowApply(art)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_HEALTH_FREQUENT" then
        if arg1 == unit then UpdateHealth(event == "UNIT_MAXHEALTH") end
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER"
        or event == "UNIT_DISPLAYPOWER" then
        if arg1 == unit then UpdatePower() end
    elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" or event == "UPDATE_EXHAUSTION" then
        UpdateXP()
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if arg1 == "player" then UpdateUnit() end
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
        if arg1 and not Azaath.IsSecret(arg1) then overlayed[arg1] = true end
        UpdateRings()
    elseif event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        if arg1 and not Azaath.IsSecret(arg1) then overlayed[arg1] = nil end
        UpdateRings()
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "ACTIONBAR_PAGE_CHANGED"
        or event == "UPDATE_BONUS_ACTIONBAR" then
        if next(overlayed) or forcedRing then UpdateRings() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateUnit()
        UpdateXP()
        UpdateRings()
    end
end)

-- Clique na moldura central: seleciona a si mesmo / menu do jogador
local function BuildPlayerButton()
    local b = CreateFrame("Button", "AzaathUIAzaathPlayer", hud, "SecureUnitButtonTemplate")
    b:SetPoint("TOPLEFT", hud, "TOPLEFT", A.power.x - CX, -A.power.y)
    b:SetPoint("BOTTOMRIGHT", hud, "TOPLEFT", A.xp.x + A.xp.w - CX, -(A.xp.y + A.xp.h))
    b:SetFrameLevel(hud:GetFrameLevel() + 9)
    b:RegisterForClicks("AnyUp")
    b:SetAttribute("unit", "player")
    b:SetAttribute("type1", "target")
    b:SetAttribute("type2", "togglemenu")
    b:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetUnit("player")
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    playerButton = b
end

function M:OnEnable()
    -- skin Reforged (moldura central) e/ou barras Reforged (anel de proc nos botões)
    if not (IsAzaath() or IsReforgedBars()) then return end
    A = Azaath.AZAATH
    Azaath:RunOutOfCombat(function()
        if Azaath.GetAzaathFrame() then BuildPlayerButton() end
        for _, e in ipairs({
            "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
            "UNIT_DISPLAYPOWER", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP", "UPDATE_EXHAUSTION",
            "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "PLAYER_ENTERING_WORLD",
            "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
            "ACTIONBAR_SLOT_CHANGED", "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR",
        }) do
            Azaath.SafeRegister(events, e)
        end
        UpdateUnit()
        UpdateXP()
        self:ApplyLayout()
    end)

    -- /azaath azaath proc | scale <n> | glow
    if Azaath.commands then
        Azaath.commands.azaath = function(arg)
            local cmd, v = (arg or ""):match("^(%S*)%s*(.-)$")
            if cmd == "proc" then
                local ab = Azaath:GetModule("ActionBars")
                local b = ab and ab.bars and ab.bars[1] and ab.bars[1].buttons[10]
                forcedRing = (forcedRing == nil) and b or nil
                UpdateRings()
            elseif cmd == "scale" and tonumber(v) then
                Azaath.db.azaath.scale = math.max(0.4, math.min(2, tonumber(v)))
                M:ApplyLayout()
            elseif cmd == "glow" then
                Azaath.db.azaath.glow = not (Azaath.db.azaath.glow ~= false)
                M:ApplyLayout()
            else
                Azaath:Print("/azaath azaath proc (testa o anel de proc) | scale <0.4-2> | glow (liga/desliga o pulso)")
            end
        end
    end
end
