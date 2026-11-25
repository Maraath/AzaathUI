--[[----------------------------------------------------------------------------
    AzaathUI - Modules/UnitFrames.lua
    Barras de vida e recurso no estilo Azaath (3.3.5a).

      * Jogador: vida + recurso centralizados na parte inferior da tela.
      * Alvo: nome/nível + vida + recurso fino, logo abaixo da bússola.
      * Barra "rastro de dano": ao tomar dano, um pedaço claro fica parado
        por um instante e depois drena, como no Azaath.
      * Barra de inimigo do Azaath (usada pelas placas de nome, módulo
        Nameplates via Azaath.AzBar): nome em serifa espaçada, barra fina
        vermelha com degradê, losango do nível embaixo, moldura com pontas em
        pincel em combate e asas de prata (raro) ou ouro (elite/chefe).
        Texturas em Media/Target (geradas por tools/media/generate-target-media.js
        a partir das capturas de referência). Dano: o pedaço perdido acende
        em branco e some, igual ao jogador.

    Decisões de compatibilidade/performance:
      * Interação segura via SecureUnitButtonTemplate (jogador e alvo): cliques
        esquerdo (alvo), direito (menu de unidade com visual Azaath) e meio (foco).
        O alvo usa RegisterUnitWatch para gerenciar visibilidade sem taint em combate.
      * Não existe RegisterUnitEvent na 3.3.5: um único frame de eventos filtra
        pelo argumento "unit". Não existe UNIT_POWER: usamos UNIT_MANA/RAGE/etc.
      * O recurso do jogador é consultado a cada 0.05s (só redesenha se mudou)
        para a regeneração de energia/runa ficar fluida, como o "frequentUpdates"
        da Blizzard.
      * O OnUpdate do rastro de dano só existe enquanto a animação está ativa.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("UnitFrames")

local _G = _G
local pairs, ipairs, tostring = pairs, ipairs, tostring
local floor, format = math.floor, string.format
local UnitExists, UnitName, UnitLevel, UnitClass = UnitExists, UnitName, UnitLevel, UnitClass
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitPower, UnitPowerMax, UnitPowerType = UnitPower, UnitPowerMax, UnitPowerType
local UnitIsDead, UnitIsGhost, UnitIsConnected = UnitIsDead, UnitIsGhost, UnitIsConnected
local UnitIsPlayer, UnitReaction, UnitIsEnemy = UnitIsPlayer, UnitReaction, UnitIsEnemy
local UnitClassification = UnitClassification
local UnitHasVehicleUI = UnitHasVehicleUI

local TRAIL_DELAY = 0.35 -- segundos parado antes de drenar
local TRAIL_SPEED = 0.8  -- fração do máximo drenada por segundo
local FLASH_HOLD  = 0.12 -- jogador: segundos com o pedaço perdido em branco
local FLASH_FADE  = 0.45 -- jogador: segundos para o branco sumir
local POWER_POLL  = 0.05 -- intervalo de consulta do recurso do jogador
local BAR_GAP     = 3    -- espaço entre vida e recurso

--------------------------------------------------------------------------------
-- Paleta
--------------------------------------------------------------------------------
-- Jogador no estilo Azaath: preenchimento branco em degradê (Media/UnitFrames/
-- HealthFill.tga, cor natural da textura), rastro de dano cinza escuro
local PLAYER_HEALTH  = { 0.80, 0.80, 0.79 }  -- vida cheia: branco acinzentado (HUD Azaath)
local PLAYER_DAMAGED = { 0.86, 0.20, 0.17 }  -- abaixo de 100%: degradê vermelho Azaath
local TEXT_DARK     = { 0.20, 0.20, 0.20 } -- valor sobre a parte preenchida
local TEXT_LIGHT    = { 0.90, 0.90, 0.90 } -- valor sobre a parte vazia (vida baixa)

-- Barra de vida do jogador cheia e fora de combate fica bem transparente (Azaath);
-- em combate ou com dano volta a 100%.
local FADED_ALPHA = 0.25
local FADE_IN     = 6    -- alpha/s ao aparecer (quase instantâneo)
local FADE_OUT    = 1.2  -- alpha/s ao sumir (suave)
local playerInCombat = false

local REACTION = {
    hostile  = { 0.74, 0.22, 0.17 },
    neutral  = { 0.98, 0.82, 0.20 },
    friendly = { 0.36, 0.64, 0.30 },
    tapped   = { 0.50, 0.50, 0.50 },
}

-- Índices de UnitPowerType na 3.3.5a
local POWER_COLORS = {
    [0] = { 0.10, 0.22, 0.62 }, -- mana: azul-marinho
    [1] = { 0.96, 0.08, 0.06 }, -- raiva: vermelho vivo
    [2] = { 0.86, 0.55, 0.26 }, -- foco
    [3] = { 0.79, 0.63, 0.22 }, -- energia: amarelo-mostarda fosco (#C9A038)
    [6] = { 0.10, 0.72, 0.88 }, -- poder rúnico
}
local POWER_FALLBACK = { 0.60, 0.60, 0.60 }

local function PlayerHealthColor() return PLAYER_HEALTH end
local function PlayerDamagedColor() return PLAYER_DAMAGED end

local CLASSIFICATION_SUFFIX = {
    elite = "+", rareelite = " R+", rare = " R", worldboss = " Chefe",
}

-- Barra de inimigo Azaath (placas de nome): cores por reação que multiplicam as texturas em tons de cinza
-- (preenchimento, losango do nível e moldura de combate). Hostil amostrado
-- da captura: barra (121..185, 27..40, 23..36), losango (229, 66, 66).
local AZ_TARGET = {
    hostile  = { fill = { 0.73, 0.16, 0.14 }, badge = { 0.90, 0.26, 0.26 }, frame = { 0.80, 0.25, 0.24 } },
    neutral  = { fill = { 0.96, 0.78, 0.14 }, badge = { 1.00, 0.86, 0.32 }, frame = { 0.98, 0.80, 0.26 } },
    friendly = { fill = { 0.28, 0.58, 0.24 }, badge = { 0.42, 0.78, 0.36 }, frame = { 0.38, 0.70, 0.32 } },
    tapped   = { fill = { 0.45, 0.45, 0.45 }, badge = { 0.62, 0.62, 0.62 }, frame = { 0.55, 0.55, 0.55 } },
}
-- Prata = raro / raro de elite; ouro = elite / chefe
local ELITE_STYLE = {
    rare = "EliteSilver", rareelite = "EliteSilver",
    elite = "EliteGold", worldboss = "EliteGold",
}
local REF_WIDTH     = 155  -- largura da barra na captura (unidades das texturas)
local INK_STYLE     = true -- placas em pincel e tinta (false = barra clássica hachurada)
local NAME_COLOR    = { 0.93, 0.92, 0.89 }
local NAME_TRACKING = 0.20 -- espaço extra entre letras (fração do tamanho da fonte)
local MAX_NAME_CHARS = 48
local COMBAT_DROP   = 3    -- unidades que o losango desce com a moldura de combate

--------------------------------------------------------------------------------
-- HUD Azaath (layout "az"), de cima para baixo:
--   buffs (Auras) > barra de recurso segmentada encostada na vida > vida >
--   linha de XP com pontas afuniladas > losango do nível + "XP" (Experience).
-- Linhas retas e nítidas: bordas, divisórias e fundos são texturas lisas de
-- 1 px (Azaath.media.blank), nada de moldura esticada. O preenchimento usa
-- Media/UnitFrames/HudFill (degradê só vertical, nítido em qualquer largura).
-- Todas as medidas e cores ficam aqui; Experience e Auras leem Azaath.HUD.
--------------------------------------------------------------------------------
local HUD = {
    WIDTH           = 320, -- largura das barras (padrão; o menu pode mudar)
    HEALTH_HEIGHT   = 22,  -- vida
    STAMINA_HEIGHT  = 7,   -- barra de recurso (raiva/mana/energia) em cima da vida
    RESOURCE_HEIGHT = 4,   -- linha de XP abaixo da vida
    SEGMENTS        = 3,   -- divisões do recurso
    FONT_SIZE       = 13,
    BORDER  = { 0.28, 0.30, 0.34, 1 },    -- ferro / ardósia em volta da vida
    OUTLINE = { 0.16, 0.17, 0.20, 0.95 }, -- contorno escuro do recurso e da XP
    EMPTY   = { 0.06, 0.06, 0.07, 0.88 }, -- fundo das barras
    DIVIDER = { 0.08, 0.08, 0.10, 0.95 },
    HATCH_ALPHA = 0.30,                   -- listras na parte vazia da vida
}
Azaath.HUD = HUD

-- HUD da skin Azaath Modern (losango/XP sob a vida); vale também com as
-- barras Azaath Custom
local function IsHud()
    return Azaath.GetSkin and Azaath.GetSkin() == "modern"
end
Azaath.IsHudLayout = IsHud

--------------------------------------------------------------------------------
-- Formatação
--------------------------------------------------------------------------------
local function Short(v)
    if v >= 1e6 then
        return format("%.1fm", v / 1e6)
    elseif v >= 1e4 then
        return format("%.1fk", v / 1e3)
    end
    return tostring(v)
end

local function Percent(cur, max)
    if max <= 0 then return "0%" end
    return floor(cur / max * 100 + 0.5) .. "%"
end

--------------------------------------------------------------------------------
-- Barra genérica (StatusBar + rastro opcional + textos)
--------------------------------------------------------------------------------
local backdrop -- criado sob demanda (Azaath.media já existe)

local function CreateText(parent, size, justify)
    local c = Azaath.colors.cream
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Azaath.media.font, size, "OUTLINE")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.7)
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH(justify)
    return fs
end

local function UnitFrameTex(name)
    return Azaath.media.path .. "UnitFrames\\" .. name
end

local function SetBarFrameColor(holder, r, g, b, a)
    if holder.borderTex then
        holder.borderTex:SetVertexColor(r, g, b, a or 0.40)
    end
end

local function LayoutBarArt(holder)
    if holder.artDisabled then return end
    local w, h = holder:GetWidth(), holder:GetHeight()
    if (not w or w <= 0) and holder:GetParent() then
        w = holder:GetParent():GetWidth()
    end
    if not w or not h or w <= 0 or h <= 0 then return end

    -- Ladrilhos hachurados "/" discretos na parte vazia da barra
    local tiles = holder.emptyTiles
    if tiles then
        local tileSize = math.max(8, h)
        local x, idx = 0, 0
        while x < w - 0.01 do
            idx = idx + 1
            local tw = math.min(tileSize, w - x)
            local t = tiles[idx]
            if not t then
                t = holder:CreateTexture(nil, "BACKGROUND", nil, 1)
                t:SetTexture(Azaath.media.path .. "Target\\Empty")
                tiles[idx] = t
            end
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", holder, "TOPLEFT", x, 0)
            t:SetWidth(tw)
            t:SetHeight(h)
            t:SetTexCoord(0, tw / tileSize, 0, 1)
            t:SetAlpha(holder.tileAlpha or 0.55)
            t:Show()
            x = x + tileSize
        end
        for i = idx + 1, #tiles do
            tiles[i]:Hide()
        end
    end
end

local function CreateBar(parent, height, fontSize, withTrail, isPower)
    local blank = Azaath.media.blank
    backdrop = backdrop or {
        bgFile = blank, edgeFile = blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    }

    local holder = CreateFrame("Frame", nil, parent)
    holder:SetHeight(height)
    Azaath.SetBackdrop(holder, backdrop)
    holder:SetBackdropColor(0, 0, 0, 0)
    holder:SetBackdropBorderColor(0, 0, 0, 0)

    -- Fundo escuro pintado à mão + ladrilhos hachurados "/" do Azaath
    local bgTex = holder:CreateTexture(nil, "BACKGROUND", nil, 0)
    bgTex:SetTexture(UnitFrameTex("BarBg"))
    bgTex:SetAllPoints(holder)
    holder.bgTex = bgTex
    holder.emptyTiles = {}

    local base = holder:GetFrameLevel()
    -- Usa HealthFill (sempre indexado desde o início do jogo) com pintura a óleo
    local fillTex = UnitFrameTex("HealthFill")

    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
    bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
    bar:SetStatusBarTexture(fillTex)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetFrameLevel(base + 2)
    holder.bar = bar

    -- Textura de pincelada diagonal sobre o preenchimento
    local statusTex = bar:GetStatusBarTexture()
    if statusTex then
        local hatch = bar:CreateTexture(nil, "ARTWORK")
        hatch:SetTexture(Azaath.media.path .. "ActionBar\\Hatch")
        hatch:SetAllPoints(statusTex)
        hatch:SetAlpha(isPower and 0.32 or 0.24)
        holder.fillHatch = hatch
    end

    if withTrail then
        local trail = CreateFrame("StatusBar", nil, holder)
        trail:SetAllPoints(bar)
        trail:SetStatusBarTexture(Azaath.media.path .. "Target\\Flash")
        trail:SetStatusBarColor(0.98, 0.90, 0.72)
        trail:SetAlpha(0.55)
        trail:SetMinMaxValues(0, 1)
        trail:SetValue(0)
        trail:SetFrameLevel(base + 1)
        holder.trail = trail
        holder.trailValue = 0
    end

    -- Camada superior: moldura fina e discreta pintada à mão + textos
    local overlay = CreateFrame("Frame", nil, holder)
    overlay:SetAllPoints(bar)
    overlay:SetFrameLevel(base + 3)

    local borderTex = overlay:CreateTexture(nil, "ARTWORK", nil, 1)
    borderTex:SetTexture(UnitFrameTex(isPower and "PowerBorder" or "HealthBorder"))
    borderTex:SetAllPoints(holder)
    borderTex:SetVertexColor(0.35, 0.33, 0.30, 0.40)
    holder.borderTex = borderTex

    holder:SetScript("OnSizeChanged", LayoutBarArt)

    local gloss = overlay:CreateTexture(nil, "BACKGROUND")
    gloss:SetTexture(blank)
    gloss:SetPoint("TOPLEFT", overlay, "TOPLEFT")
    gloss:SetPoint("TOPRIGHT", overlay, "TOPRIGHT")
    gloss:SetHeight(floor(height / 2))
    Azaath.Gradient(gloss, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.10)
    gloss:Hide()
    holder.gloss = gloss

    if fontSize and fontSize > 0 then
        holder.leftText = CreateText(overlay, fontSize, "LEFT")
        holder.leftText:SetPoint("LEFT", overlay, "LEFT", 4, 0)
        holder.rightText = CreateText(overlay, fontSize, "RIGHT")
        holder.rightText:SetPoint("RIGHT", overlay, "RIGHT", -4, 0)
    end

    return holder
end

local function TrailOnUpdate(holder, elapsed)
    if holder.trailHold > 0 then
        holder.trailHold = holder.trailHold - elapsed
        return
    end
    local target = holder.bar:GetValue()
    holder.trailValue = holder.trailValue - holder.trailMax * TRAIL_SPEED * elapsed
    if holder.trailValue <= target then
        holder.trailValue = target
        holder.trailActive = false
        holder:SetScript("OnUpdate", nil)
    end
    holder.trail:SetValue(holder.trailValue)
end

-- Modo "flash" (jogador, Azaath): o pedaço de vida perdido acende em branco e
-- some logo depois. Golpes seguidos somam ao mesmo pedaço e reacendem.
-- O apagar é uma animação nativa (Alpha), não OnUpdate + GetAlpha: o alpha lido
-- de volta podia vir secreto/travar e o branco ficava aceso para sempre (cinza).
local function FlashDone(holder)
    local trail = holder.trail
    trail:SetAlpha(0)
    local v = holder.bar:GetValue()
    trail:SetValue(v)
    -- valor secreto não pode ser comparado depois: não guarda em trailValue
    if not Azaath.IsSecret(v) then holder.trailValue = v end
    holder.trailActive = false
end

local function StopFlash(holder)
    local ag = holder.flashAG
    if ag and ag:IsPlaying() then ag:Stop() end
end

local function StartFlash(holder)
    local ag = holder.flashAG
    if not ag then
        ag = holder.trail:CreateAnimationGroup()
        local fade = ag:CreateAnimation("Alpha")
        fade:SetFromAlpha(1)
        fade:SetToAlpha(0)
        fade:SetStartDelay(FLASH_HOLD)
        fade:SetDuration(FLASH_FADE)
        if ag.SetToFinalAlpha then ag:SetToFinalAlpha(true) end
        ag:SetScript("OnFinished", function() FlashDone(holder) end)
        holder.flashAG = ag
    end
    holder:SetScript("OnUpdate", nil)
    holder.trailActive = true
    ag:Stop()
    holder.trail:SetAlpha(1)
    ag:Play()
end

local function SetBarValues(holder, cur, max, instant)
    -- Valores secretos (cliente moderno, em combate): só repassamos aos
    -- widgets, sem comparações nem contas.
    if Azaath.AnySecret(cur, max) then
        holder.bar:SetMinMaxValues(0, max)
        holder.bar:SetValue(cur)
        local trail = holder.trail
        if trail then
            holder.trailMax = nil -- força realinhar quando voltar a ser comparável
            if holder.flashMode and holder.hasLastCur and not instant then
                -- Flash sem comparar: o rastro vai para o valor ANTERIOR e fica
                -- atrás da barra. Se foi dano, sobra um pedaço branco à direita
                -- do preenchimento; se foi cura, fica todo escondido atrás dele.
                -- Golpes durante o flash mantêm o topo (o pedaço acumula).
                trail:SetMinMaxValues(0, max)
                if not holder.trailActive then
                    trail:SetValue(holder.lastCur)
                    StartFlash(holder)
                end
            else
                StopFlash(holder)
                trail:SetValue(0)
                holder.trailActive = false
                holder:SetScript("OnUpdate", nil)
            end
        end
        holder.lastCur, holder.hasLastCur = cur, true
        return
    end
    if max <= 0 then max = 1 end
    holder.bar:SetMinMaxValues(0, max)
    holder.bar:SetValue(cur)

    -- último valor só serve para comparar se não for secreto
    local lastCur = holder.lastCur
    if Azaath.IsSecret(lastCur) then lastCur = nil end
    holder.lastCur, holder.hasLastCur = cur, true

    local trail = holder.trail
    if not trail then return end
    trail:SetMinMaxValues(0, max)

    if instant or max ~= holder.trailMax or cur >= holder.trailValue then
        -- cura, troca de alvo ou mudança de máximo: alinha o rastro na hora
        holder.trailMax = max
        holder.trailValue = cur
        trail:SetValue(cur)
        if holder.flashMode then
            StopFlash(holder)
            trail:SetAlpha(0)
        end
        if holder.trailActive then
            holder.trailActive = false
            holder:SetScript("OnUpdate", nil)
        end
    elseif holder.flashMode then
        -- dano novo (não reacende em eventos sem mudança de vida)
        if not holder.trailActive or (lastCur and cur < lastCur) then
            StartFlash(holder)
        end
    elseif not holder.trailActive then
        -- dano: congela o pedaço perdido e agenda a drenagem
        holder.trailActive = true
        holder.trailHold = TRAIL_DELAY
        holder:SetScript("OnUpdate", TrailOnUpdate)
    end
end

--------------------------------------------------------------------------------
-- Transparência da barra de vida do jogador (frame próprio: o holder já usa
-- OnUpdate para o rastro de dano)
--------------------------------------------------------------------------------
local function FadeOnUpdate(fader, elapsed)
    local h = fader.holder
    local cur, target = h:GetAlpha(), fader.target
    local step = (target > cur and FADE_IN or FADE_OUT) * elapsed
    if math.abs(target - cur) <= step then
        h:SetAlpha(target)
        fader:SetScript("OnUpdate", nil)
    elseif target > cur then
        h:SetAlpha(cur + step)
    else
        h:SetAlpha(cur - step)
    end
end

-- full: vida cheia (nil = desconhecido, ex. valor secreto -> trata como cheia)
local function UpdatePlayerFade(f, full)
    local h = f.health
    local fader = h and h.fader
    if not fader then return end
    if full ~= nil then f.healthFull = full end
    local pCfg = M.db and M.db.player
    local shouldFade = (pCfg and pCfg.fadeOutOfCombat ~= false) and not IsHud()
    local target = (shouldFade and f.healthFull ~= false and not playerInCombat and not M.editing) and FADED_ALPHA or 1
    if fader.target == target and math.abs(h:GetAlpha() - target) < 0.02 then return end
    fader.target = target
    fader:SetScript("OnUpdate", FadeOnUpdate)
end

--------------------------------------------------------------------------------
-- Atualizações
--------------------------------------------------------------------------------
local function ReactionKey(unit)
    if not UnitIsConnected(unit) then return "tapped" end
    if Azaath.API.IsTappedByOther(unit) then return "tapped" end
    local reaction = UnitReaction(unit, "player")
    if reaction and not Azaath.IsSecret(reaction) then
        if reaction <= 3 then return "hostile" end
        if reaction == 4 then return "neutral" end
        return "friendly"
    end
    return UnitIsEnemy("player", unit) and "hostile" or "friendly"
end

local function HealthColor(f, unit)
    if f.key == "player" then return PlayerHealthColor() end
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if cc then
            return { cc.r, cc.g, cc.b }
        end
    end
    local key = ReactionKey(unit)
    return REACTION[key] or REACTION.friendly
end

-- Curvas de cor (cliente moderno): o próprio jogo avalia a porcentagem de vida
-- (secreta em combate) e devolve a cor, sem o addon comparar nada.
-- Cheia (100%) = branco / texto escuro; abaixo disso = vermelho / texto claro.
local colorCurves -- nil = ainda não tentou; false = indisponível
local function GetColorCurves()
    if colorCurves ~= nil then return colorCurves or nil end
    colorCurves = false
    if not (UnitHealthPercent and C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then
        return nil
    end
    local function build(below, full)
        local curve = C_CurveUtil.CreateColorCurve()
        if curve.SetType and Enum and Enum.LuaCurveType and Enum.LuaCurveType.Step then
            pcall(curve.SetType, curve, Enum.LuaCurveType.Step)
        end
        curve:AddPoint(0, CreateColor(below[1], below[2], below[3]))
        curve:AddPoint(0.9999, CreateColor(below[1], below[2], below[3]))
        curve:AddPoint(1, CreateColor(full[1], full[2], full[3]))
        return curve
    end
    local ok, bar, text, frame = pcall(function()
        return build(PlayerDamagedColor(), PlayerHealthColor()),
               build(TEXT_LIGHT, IsHud() and TEXT_LIGHT or TEXT_DARK),
               build({ 0.50, 0.30, 0.28 }, { 0.35, 0.33, 0.30 })
    end)
    if ok and bar and text then
        colorCurves = { bar = bar, text = text, frame = frame }
    end
    return colorCurves or nil
end

-- Aplica cor vinda de uma curva (r, g, b podem ser secretos: só repassa)
local function ApplyCurveColor(unit, curve, setter)
    local ok = pcall(function()
        local color = UnitHealthPercent(unit, false, curve)
        if not color then error("sem cor") end
        setter(color:GetRGB())
    end)
    return ok
end

--------------------------------------------------------------------------------
-- Barra de inimigo no estilo Azaath (placas de nome)
--------------------------------------------------------------------------------
local function TargetTex(name)
    return Azaath.media.path .. "Target\\" .. name
end

-- Em combate? (booleano secreto ou erro => trata como fora de combate)
local function UnitInCombat(unit)
    local ok, v = pcall(UnitAffectingCombat, unit)
    if not ok or Azaath.IsSecret(v) then return false end
    return v and true or false
end

-- Moldura de combate (pontas em pincel) e losango um pouco mais baixo
local function SetTargetCombat(f, on)
    if f.combatShown == on then return end
    f.combatShown = on
    if on then
        f.combatFrame:Show()
        f.edges:Hide()
    else
        f.combatFrame:Hide()
        f.edges:Show()
    end
    f.badge:ClearAllPoints()
    f.badge:SetPoint("TOP", f.health, "BOTTOM", 0, on and -COMBAT_DROP * (f.bu or f.u) or 0)
end

-- Mouse por cima: a placa inteira fica mais viva (cores 30% mais fortes)
local LIT_BOOST = 1.3
local function Lit(c, k)
    return math.min(1, c[1] * k), math.min(1, c[2] * k), math.min(1, c[3] * k)
end

local function ApplyTargetColors(f, key)
    local lit = f.hlState == "mouseover"
    if f.colorKey == key and f.colorLit == lit then return end
    f.colorKey, f.colorLit = key, lit
    local k = lit and LIT_BOOST or 1
    local pal = AZ_TARGET[key] or AZ_TARGET.hostile
    local h = f.health
    local r, g, b = Lit(pal.fill, k)
    h.bar:SetStatusBarColor(r, g, b)
    local tex = h.bar:GetStatusBarTexture()
    if tex then tex:SetVertexColor(r, g, b) end
    f.badge.tex:SetVertexColor(Lit(pal.badge, k))
    r, g, b = Lit(pal.frame, k)
    for i = 1, #f.framePieces do
        f.framePieces[i]:SetVertexColor(r, g, b)
    end
end

local function UpdateAzHealth(f, instant)
    if not f or not f.health then return end
    local unit, h = f.displayUnit, f.health
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    SetBarValues(h, cur, max, instant)
    ApplyTargetColors(f, ReactionKey(unit))

    local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
    -- placas de nome: a moldura só aparece com o inimigo em você (aggro);
    -- em combate com outras pessoas, não
    if f.marks then
        SetTargetCombat(f, false) -- placas: aggro agora é a aura vermelha, sem moldura de pincel
        return
    end
    -- moldura: alvo em combate, ou já ferido (só dá para saber fora de combate)
    local combat = false
    if not dead then
        combat = UnitInCombat(unit)
        if not combat and not Azaath.AnySecret(cur, max) then
            combat = max > 0 and cur > 0 and cur < max
        end
    end
    SetTargetCombat(f, combat)
end

-- Nome em maiúsculas com espaçamento largo entre letras (o FontString não tem
-- espaçamento de letras: cada letra é um FontString, centralizados juntos)
local function CreateNameChar(f)
    local fs = f:CreateFontString(nil, "OVERLAY")
    fs:SetFont(f.nameFontPath, f.nameSize, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.85)
    return fs
end

local function SetTargetName(f, text, r, g, b)
    local chars, fallback = f.nameChars, f.nameFallback
    if Azaath.IsSecret(text) then
        -- nome secreto: não dá para separar letras, vai inteiro
        for i = 1, #chars do chars[i]:Hide() end
        fallback:SetText(text)
        fallback:SetTextColor(r, g, b)
        fallback:Show()
        f.lastName = nil
        return
    end
    fallback:Hide()
    -- alvo / mouse por cima: o nome aparece inteiro mesmo se for longo
    local full = f.hlState == "target" or f.hlState == "mouseover"
    local sig = text .. format("%.2f%.2f%.2f", r, g, b) .. (full and "+" or "")
    if sig == f.lastName then return end
    f.lastName = sig

    text = Azaath.Upper(text)
    local list = {}
    for ch in text:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        if #list >= MAX_NAME_CHARS then break end
        list[#list + 1] = ch
    end
    local n = #list
    local widths = f.nameWidths

    -- mede (e prepara) as letras num tamanho de fonte; devolve a soma das larguras
    local function Measure(sz)
        local sum = 0
        for i = 1, n do
            local fs = chars[i]
            if not fs then
                fs = CreateNameChar(f)
                chars[i] = fs
            end
            fs:SetFont(f.nameFontPath, sz, "")
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

    local size = f.nameSize
    local track = size * (f.nameTracking or NAME_TRACKING)
    local letters = Measure(size)
    local total = letters + track * math.max(0, n - 1)

    -- placas de nome: nome longo tenta caber antes de ser cortado
    local maxW = f.nameMaxW
    if maxW and total > maxW then
        -- 1) letras juntas (sem o espaçamento extra)
        track = 0
        total = letters
        -- 2) fonte um pouco menor, no máximo até 80% do tamanho
        if total > maxW then
            local minSize = math.floor(f.nameSize * 0.8 + 0.5)
            local fit = math.floor(size * maxW / total)
            local newSize = math.max(minSize, fit)
            if newSize < size then
                size = newSize
                total = Measure(size)
            end
        end
    end

    -- 3) ainda não coube: corta e termina em "..." (menos no alvo / mouse)
    if maxW and total > maxW and n > 3 and not full then
        fallback:SetFont(f.nameFontPath, size, "")
        fallback:SetText(".")
        local dotW = fallback:GetStringWidth()
        fallback:SetFont(f.nameFontPath, f.nameSize, "")
        local dots = 3 * (dotW + track)
        local acc, k = 0, 0
        for i = 1, n do
            local add = widths[i] + (i > 1 and track or 0)
            if acc + add + dots > maxW then break end
            acc, k = acc + add, i
        end
        -- sem espaço antes dos pontos
        while k > 1 and (chars[k]:GetText() or "") == "" do
            acc = acc - widths[k] - track
            k = k - 1
        end
        for j = 1, 3 do
            local i = k + j
            local fs = chars[i]
            if not fs then
                fs = CreateNameChar(f)
                chars[i] = fs
            end
            fs:SetFont(f.nameFontPath, size, "")
            fs:SetText(".")
            fs:SetTextColor(r, g, b)
            widths[i] = dotW
        end
        n = k + 3
        total = acc + dots
    end

    local x = -total / 2
    for i = 1, n do
        local fs = chars[i]
        fs:ClearAllPoints()
        fs:SetPoint("BOTTOMLEFT", f.health, "TOP", x, f.nameGap)
        fs:Show()
        x = x + widths[i] + track
    end
    for i = n + 1, #chars do chars[i]:Hide() end
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

local function UpdateAzInfo(f)
    local unit = f.displayUnit
    local c = NAME_COLOR
    local r, g, b = c[1], c[2], c[3]
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local cc = class and not Azaath.IsSecret(class) and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if cc then r, g, b = cc.r, cc.g, cc.b end
    end
    if f.hlState == "mouseover" then -- nome clareia junto com a placa
        r, g, b = r + (1 - r) * 0.6, g + (1 - g) * 0.6, b + (1 - b) * 0.6
    elseif f.hlState == "target" and f.marks then -- placa do alvo: nome dourado
        r, g, b = 1, 0.84, 0.43
    end
    if UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit) then
        r, g, b = r * 0.6, g * 0.6, b * 0.6
    end
    SetTargetName(f, GetUnitDisplayName(unit), r, g, b)

    -- nível no losango (crânio quando desconhecido / chefe)
    local level = UnitLevel(unit)
    if Azaath.IsSecret(level) then
        f.levelText:SetText(level)
        f.skull:Hide()
    elseif level and level > 0 then
        f.levelText:SetText(level)
        f.skull:Hide()
    else
        f.levelText:SetText("")
        f.skull:Show()
    end

    -- asas de prata (raro) ou ouro (elite / chefe)
    local class = UnitClassification(unit)
    local style = class and not Azaath.IsSecret(class) and ELITE_STYLE[class]
    if style then
        if f.eliteStyle ~= style then
            f.elite:SetTexture(TargetTex(style))
            f.eliteStyle = style
        end
        f.elite:Show()
        f.badge.rare:SetTexture(TargetTex(style == "EliteGold" and "RareTriGold" or "RareTriSilver"))
        f.badge.rare:Show()
    else
        f.elite:Hide()
        f.badge.rare:Hide()
    end
end

local function BuildAzBar(f, cfg)
    local u = cfg.width / REF_WIDTH        -- escala das medidas da captura
    local barH = cfg.healthHeight
    local fu = barH / 10                   -- escala da moldura (acompanha a altura)
    local isTarget = (f.key == "target")
    local bu = isTarget and math.min(1.3, math.max(0.9, barH / 11)) or u
    local nu = isTarget and 1.15 or u
    local blank = Azaath.media.blank
    local h = f.health
    f.az, f.u, f.bu = true, u, bu

    -- o visual vem das texturas: sem fundo/borda/brilho do CreateBar
    h.artDisabled = true
    h:SetBackdropColor(0, 0, 0, 0)
    h:SetBackdropBorderColor(0, 0, 0, 0)
    if h.bgTex then h.bgTex:Hide() end
    if h.borderTex then h.borderTex:Hide() end
    if h.fillHatch then h.fillHatch:Hide() end
    if h.framePieces then
        for i = 1, #h.framePieces do h.framePieces[i]:Hide() end
    end
    h.gloss:Hide()
    h.bar:ClearAllPoints()
    h.bar:SetAllPoints(h)
    h.bar:SetStatusBarTexture(TargetTex(INK_STYLE and "InkFill" or "Fill"))
    -- dano: pedaço perdido acende em branco granulado e some (como no jogador)
    h.trail:ClearAllPoints()
    h.trail:SetAllPoints(h)
    -- (no pincel, o flash tem as mesmas bordas da vida: senão o branco de trás
    -- aparece pelas bordas transparentes e contorna a barra inteira)
    h.trail:SetStatusBarTexture(TargetTex(INK_STYLE and "InkFlash" or "Flash"))
    h.trail:SetStatusBarColor(1, 1, 1)
    h.trail:SetAlpha(0)
    h.flashMode = true

    if INK_STYLE then
        -- parte vazia: mancha de tinta cor de carvão, maior que a barra
        local mx, my = math.max(5, barH * 0.9), math.max(3, barH * 0.6)
        local back = h:CreateTexture(nil, "BACKGROUND")
        back:SetTexture(TargetTex("InkBack"))
        back:SetPoint("TOPLEFT", h, "TOPLEFT", -mx, my)
        back:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", mx, -my)
    else
        -- parte vazia: ladrilhos hachurados do tamanho da altura da barra
        local x = 0
        while x < cfg.width - 0.01 do
            local w = math.min(barH, cfg.width - x)
            local t = h:CreateTexture(nil, "BACKGROUND")
            t:SetTexture(TargetTex("Empty"))
            t:SetPoint("TOPLEFT", h, "TOPLEFT", x, 0)
            t:SetWidth(w)
            t:SetHeight(barH)
            t:SetTexCoord(0, w / barH, 0, 1)
            x = x + barH
        end
    end

    local base = h:GetFrameLevel()

    -- losango do nível (abaixo da moldura de combate, que o cobre um pouco)
    local badge = CreateFrame("Frame", nil, f)
    badge:SetFrameLevel(base + 3)
    badge:SetWidth(64 * bu)
    badge:SetHeight(32 * bu)
    badge:SetPoint("TOP", h, "BOTTOM", 0, 0)
    badge.tex = badge:CreateTexture(nil, "ARTWORK")
    badge.tex:SetAllPoints(badge)
    badge.tex:SetTexture(TargetTex(INK_STYLE and "InkBadge" or "Badge"))
    -- raro/elite: contorno de metal do triângulo (prata ou ouro, junto com as asas)
    badge.rare = badge:CreateTexture(nil, "ARTWORK", nil, 2)
    badge.rare:SetAllPoints(badge)
    badge.rare:Hide()
    f.badge = badge

    local elite = badge:CreateTexture(nil, "BACKGROUND")
    elite:SetWidth(144 * bu)
    elite:SetHeight(36 * bu)
    elite:SetPoint("TOP", badge, "TOP", 0, 0)
    elite:Hide()
    f.elite = elite

    local level = badge:CreateFontString(nil, "OVERLAY")
    level:SetFont(Azaath.media.fontBold, math.floor(13 * bu + 0.5), "")
    level:SetShadowOffset(0, 0)
    level:SetTextColor(0.09, 0.03, 0.03)
    level:SetPoint("CENTER", badge, "TOP", 0, -9 * bu)
    f.levelText = level

    local skull = badge:CreateTexture(nil, "OVERLAY")
    skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    skull:SetWidth(14 * bu)
    skull:SetHeight(14 * bu)
    skull:SetPoint("CENTER", badge, "TOP", 0, -9 * bu)
    skull:SetVertexColor(0.12, 0.04, 0.04)
    skull:Hide()
    f.skull = skull

    -- filetes da barra fora de combate: claro em cima/laterais, escuro embaixo
    local edges = CreateFrame("Frame", nil, h)
    edges:SetAllPoints(h)
    edges:SetFrameLevel(base + 4)
    local function Edge(r, g, b, a)
        local t = edges:CreateTexture(nil, "OVERLAY")
        t:SetTexture(blank)
        t:SetVertexColor(r, g, b, a)
        return t
    end
    local edgeTop = Edge(0.95, 0.58, 0.58, 0.45)
    edgeTop:SetPoint("TOPLEFT", h, "TOPLEFT")
    edgeTop:SetPoint("TOPRIGHT", h, "TOPRIGHT")
    edgeTop:SetHeight(1)
    local bottom = Edge(0.16, 0.02, 0.03, 0.85)
    bottom:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT")
    bottom:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT")
    bottom:SetHeight(1)
    local left = Edge(0.95, 0.62, 0.62, 0.45)
    left:SetPoint("TOPLEFT", h, "TOPLEFT")
    left:SetPoint("BOTTOMLEFT", h, "BOTTOMLEFT")
    left:SetWidth(1)
    local right = Edge(0.95, 0.62, 0.62, 0.45)
    right:SetPoint("TOPRIGHT", h, "TOPRIGHT")
    right:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT")
    right:SetWidth(1)
    f.edges = edges
    if INK_STYLE then edges:SetAlpha(0) end -- tinta não tem filete reto

    -- moldura de combate em 3 fatias (Frame.tga: pontas de 20 unidades,
    -- barra entra 4 unidades em cada ponta; altura = 2x a barra)
    local cf = CreateFrame("Frame", nil, h)
    cf:SetAllPoints(h)
    cf:SetFrameLevel(base + 5)
    local function Piece(l, r)
        local t = cf:CreateTexture(nil, "ARTWORK")
        t:SetTexture(TargetTex(INK_STYLE and "InkFrame" or "Frame"))
        t:SetTexCoord(l, r, 0, 1)
        t:SetHeight(20 * fu)
        return t
    end
    local capL = Piece(0, 0.25)
    capL:SetWidth(20 * fu)
    capL:SetPoint("TOPLEFT", h, "TOPLEFT", -16 * fu, 5 * fu)
    local capR = Piece(0.75, 1)
    capR:SetWidth(20 * fu)
    capR:SetPoint("TOPRIGHT", h, "TOPRIGHT", 16 * fu, 5 * fu)
    local mid = Piece(0.3, 0.7)
    mid:SetPoint("TOPLEFT", capL, "TOPRIGHT")
    mid:SetPoint("BOTTOMRIGHT", capR, "BOTTOMLEFT")
    cf:Hide()
    f.combatFrame = cf
    f.framePieces = { capL, mid, capR }
    f.combatShown = nil

    -- nome: Cinzel espaçado, centralizado acima da barra
    f.nameFontPath = Azaath.media.fontCinzel or Azaath.media.fontTitleB
    f.nameSize = math.floor((cfg.nameFont or 14) * nu + 0.5)
    f.nameGap = math.floor(5 * nu + 0.5)
    f.nameChars, f.nameWidths = {}, {}
    local fallback = f:CreateFontString(nil, "OVERLAY")
    fallback:SetFont(f.nameFontPath, f.nameSize, "")
    fallback:SetShadowOffset(1, -1)
    fallback:SetShadowColor(0, 0, 0, 0.85)
    fallback:SetPoint("BOTTOM", h, "TOP", 0, f.nameGap)
    fallback:Hide()
    f.nameFallback = fallback

    -- Marcadores de estado (conceito B): ficam fora da barra, que não muda
    local marks = CreateFrame("Frame", nil, f)
    marks:SetAllPoints(h)
    marks:SetFrameLevel(base + 7)
    f.marks = marks

    -- alvo selecionado: seta dourada logo acima do nome, com brilho por trás,
    -- subindo e descendo pouco (os efeitos sobem para dar lugar a ela)
    local arrowSize = math.floor(22 * nu + 0.5)
    local arrow = CreateFrame("Frame", nil, marks)
    arrow:SetWidth(arrowSize)
    arrow:SetHeight(arrowSize)
    arrow:SetPoint("BOTTOM", h, "TOP", 0, f.nameGap + f.nameSize)
    local shine = arrow:CreateTexture(nil, "ARTWORK")
    shine:SetTexture(TargetTex("TargetArrow"))
    shine:SetBlendMode("ADD")
    shine:SetVertexColor(1, 0.8, 0.35, 0.7)
    shine:SetPoint("CENTER", arrow, "CENTER", 0, 0)
    shine:SetWidth(arrowSize * 1.5)
    shine:SetHeight(arrowSize * 1.5)
    local tip = arrow:CreateTexture(nil, "OVERLAY")
    tip:SetTexture(TargetTex("TargetArrow"))
    tip:SetAllPoints(arrow)
    arrow:Hide()
    local bob = arrow:CreateAnimationGroup()
    bob:SetLooping("BOUNCE")
    local move = bob:CreateAnimation("Translation")
    move:SetOffset(0, 3)
    move:SetDuration(0.6)
    move:SetSmoothing("IN_OUT")
    f.targetMark, f.targetBob, f.targetMarkH = arrow, bob, 0 -- a seta não é mais usada: o alvo ganha uma aura

    -- alvo selecionado: brasas subindo da barra (a aura em volta da barra foi removida)
    local glow = CreateFrame("Frame", nil, f)
    glow:EnableMouse(false)
    glow:SetAllPoints(f)
    glow:SetFrameLevel(base)
    local sparkPath = Azaath.media.path .. "BDO\\Spark" -- brilho redondo e macio: sem cantos nem pixels
    local embers, bw = {}, cfg.width
    local function Respawn(p)
        p.life = 0.5 + math.random() * 0.6
        p.age = 0
        p.x = (math.random() - 0.5) * (bw + 10)
        p.sway = (math.random() - 0.5) * 14
        p.rise = 14 + math.random() * 18
        p.w = 5 + math.random() * 6
        p.t:SetSize(p.w, p.w * 1.8)
    end
    for i = 1, 16 do
        local t = glow:CreateTexture(nil, "ARTWORK")
        t:SetTexture(sparkPath)
        t:SetBlendMode("ADD")
        t:SetAlpha(0)
        local p = { t = t }
        Respawn(p)
        p.age = math.random() * p.life
        embers[i] = p
    end
    glow:SetScript("OnUpdate", function(_, el)
        for _, p in ipairs(embers) do
            p.age = p.age + el
            if p.age >= p.life then Respawn(p) end
            local fr = p.age / p.life
            p.t:ClearAllPoints()
            p.t:SetPoint("BOTTOM", h, "TOP", p.x + p.sway * fr, -2 + p.rise * fr)
            p.t:SetVertexColor(1, 0.3 + 0.5 * fr, 0.08)
            p.t:SetAlpha(math.sin(math.pi * fr) * 0.95)
        end
    end)
    local gag = glow:CreateAnimationGroup()
    gag:SetLooping("BOUNCE")
    local pulse = gag:CreateAnimation("Alpha")
    pulse:SetFromAlpha(1)
    pulse:SetToAlpha(0.55)
    pulse:SetDuration(0.7)
    glow.pulse = gag
    glow:Hide()
    f.glow = glow

    -- alvo: ponta da vida acesa (por cima da barra, junto dos marcadores)
    local tipMark = marks:CreateTexture(nil, "OVERLAY")
    tipMark:SetColorTexture(1, 0.98, 0.86, 0.95)
    tipMark:SetWidth(1)
    tipMark:SetPoint("TOPRIGHT", h.bar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    tipMark:SetPoint("BOTTOMRIGHT", h.bar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    tipMark:Hide()
    f.tipMark = tipMark

    -- aggro em você: aura vermelha macia só por fora da barra (a mesma da placa
    -- minimalista, Media/BDO/PlateAggro.tga = trilho + 5 px; antes: olho + moldura)
    local aura = f:CreateTexture(nil, "BACKGROUND")
    aura:SetTexture(Azaath.media.path .. "BDO\\PlateAggro")
    aura:SetPoint("TOPLEFT", h, "TOPLEFT", -6, 6)
    aura:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 6, -6)
    aura:Hide()
    f.aggroMark = aura

    -- mob de missão: losango amarelo das missões (igual ao do rastreador),
    -- à esquerda, no começo da barra
    local qSize = math.floor(16 * nu + 0.5)
    local quest = CreateFrame("Frame", nil, marks)
    quest:SetWidth(qSize)
    quest:SetHeight(qSize)
    quest:SetPoint("RIGHT", h, "LEFT", -math.max(4, math.floor(barH * 0.7 + 0.5)), 0)
    local qOuter = quest:CreateTexture(nil, "ARTWORK")
    qOuter:SetTexture(Azaath.media.path .. "Diamond")
    qOuter:SetAllPoints(quest)
    qOuter:SetVertexColor(1.00, 0.82, 0.36)
    local qInner = quest:CreateTexture(nil, "OVERLAY")
    qInner:SetTexture(Azaath.media.path .. "Diamond")
    qInner:SetVertexColor(0.07, 0.085, 0.10)
    qInner:SetPoint("CENTER", quest, "CENTER", 0, 0)
    qInner:SetWidth(qSize * 0.6)
    qInner:SetHeight(qSize * 0.6)
    quest:Hide()
    f.questMark = quest

    return f.nameSize + f.nameGap + 2, math.floor((32 + COMBAT_DROP) * bu + 0.5)
end

-- API para o módulo Nameplates: cria uma barra de inimigo Azaath num frame pai
-- (a placa de nome). cfg: width, healthHeight, nameFont.
-- Uso: bar.displayUnit = unit; AzBar.UpdateHealth(bar, true); AzBar.UpdateInfo(bar)
Azaath.AzBar = {
    Create = function(parent, cfg)
        local f = CreateFrame("Frame", nil, parent)
        f:EnableMouse(false)
        f.health = CreateBar(f, cfg.healthHeight, 0, true)
        f.health:EnableMouse(false)
        local top, below = BuildAzBar(f, cfg)
        f:SetWidth(cfg.width)
        f:SetHeight(top + cfg.healthHeight + below)
        f.health:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top)
        f.health:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -top)
        f.barTop = top
        -- placas: letras menos espaçadas e nome no máximo 1,3x a largura da barra
        f.nameTracking = cfg.nameTracking or 0.12
        f.nameMaxW = cfg.width * (cfg.nameMaxRatio or 1.3)
        return f
    end,
    UpdateHealth = function(f, instant) UpdateAzHealth(f, instant) end,
    UpdateInfo = function(f) UpdateAzInfo(f) end,
    -- Mob de missão: mostra/esconde o losango amarelo
    SetQuest = function(f, on)
        if not f.questMark then return end
        on = on and true or false
        if f.questOn == on then return end
        f.questOn = on
        if on then f.questMark:Show() else f.questMark:Hide() end
    end,
    -- Estado da placa: state = "target" | "mouseover" | nil; aggro = boolean
    SetState = function(f, state, aggro)
        if not f.marks then return end
        if f.hlState ~= state then
            f.hlState = state
            if f.colorKey then ApplyTargetColors(f, f.colorKey) end
            if f.displayUnit then UpdateAzInfo(f) end
            if state == "target" then
                f.glow:Show()
                f.glow.pulse:Play()
            else
                f.glow.pulse:Stop()
                f.glow:Hide()
            end
            -- (23/11: sem a linha branca na ponta da vida do alvo)
        end
        aggro = aggro and true or false
        if f.aggroOn ~= aggro then
            f.aggroOn = aggro
            if aggro then f.aggroMark:Show() else f.aggroMark:Hide() end
        end
    end,
    -- usados pela placa de aliados: valores da barra (com flash de dano que
    -- funciona com valores secretos) e "está em combate?" seguro
    SetBarValues = function(holder, cur, max, instant) SetBarValues(holder, cur, max, instant) end,
    InCombat = function(unit) return UnitInCombat(unit) end,
    -- Reaplica a ordem das camadas depois de trocar o pai / nível do frame
    Relevel = function(f)
        local base = f:GetFrameLevel()
        local h = f.health
        if f.glow then f.glow:SetFrameLevel(base) end
        h:SetFrameLevel(base + 1)
        h.trail:SetFrameLevel(base + 2)
        h.bar:SetFrameLevel(base + 3)
        f.badge:SetFrameLevel(base + 4)
        f.edges:SetFrameLevel(base + 5)
        f.combatFrame:SetFrameLevel(base + 6)
        if f.marks then f.marks:SetFrameLevel(base + 7) end
        if f.clickButton then f.clickButton:SetFrameLevel(base + 10) end
    end,
}

local function UpdateHealth(f, instant)
    if f.az then
        UpdateAzHealth(f, instant)
        return
    end
    local unit, h = f.displayUnit, f.health
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    SetBarValues(h, cur, max, instant)

    -- Valores secretos: mostra o número direto no widget, sem contas/comparações
    if Azaath.AnySecret(cur, max) then
        local col = HealthColor(f, unit)
        local tex = h.bar:GetStatusBarTexture()
        local curves = (f.key == "player") and GetColorCurves()
        local colored = curves and tex and ApplyCurveColor(unit, curves.bar, function(r, g, b)
            tex:SetVertexColor(r, g, b)
        end)
        if not colored then
            h.bar:SetStatusBarColor(col[1], col[2], col[3])
            if tex then tex:SetVertexColor(col[1], col[2], col[3]) end
        end
        if f.key == "player" then
            if curves and curves.frame then
                ApplyCurveColor(unit, curves.frame, function(r, g, b)
                    SetBarFrameColor(h, r, g, b, 0.45)
                end)
            else
                SetBarFrameColor(h, 0.50, 0.30, 0.28, 0.45)
            end
        end
        local dead = UnitIsDeadOrGhost and UnitIsDeadOrGhost(unit)
        if h.centerText and curves then
            -- jogador Azaath: mesma fonte sem contorno, cor pela curva + sombra sutil
            h.centerText:SetShadowOffset(1, -1)
            h.centerText:SetShadowColor(0, 0, 0, 0.75)
            if not ApplyCurveColor(unit, curves.text, function(r, g, b)
                h.centerText:SetTextColor(r, g, b)
            end) then
                h.centerText:SetTextColor(TEXT_LIGHT[1], TEXT_LIGHT[2], TEXT_LIGHT[3])
            end
            if dead then
                h.centerText:SetText("Morto")
            elseif not pcall(h.centerText.SetFormattedText, h.centerText, "%s", cur) then
                h.centerText:SetText(cur)
            end
        elseif h.centerText then
            -- branco com contorno: legível sobre o pergaminho e sobre o vazio
            if not h.secretStyled then
                local font, size = h.centerText:GetFont()
                font = font or Azaath.media.font or "Fonts\\ARIALN.TTF"
                size = size or 13
                pcall(h.centerText.SetFont, h.centerText, font, size, "OUTLINE")
                h.secretStyled = true
            end
            h.centerText:SetTextColor(1, 1, 1)
            if dead then
                h.centerText:SetText("Morto")
            else
                local ok = pcall(function()
                    h.centerText:SetFormattedText("%s", cur)
                end)
                if not ok then
                    h.centerText:SetText(cur)
                end
            end
        elseif h.leftText then
            if dead then h.leftText:SetText("Morto") else h.leftText:SetText(cur) end
            h.rightText:SetText("")
            if UnitHealthPercent and not dead then
                local scale = _G.CurveConstants and CurveConstants.ScaleTo100
                -- assinatura pode variar entre versões: tudo dentro do pcall
                pcall(function()
                    h.rightText:SetFormattedText("%d%%", UnitHealthPercent(unit, true, scale))
                end)
            end
        end
        if f.key == "player" then UpdatePlayerFade(f, nil) end
        return
    end

    local col = HealthColor(f, unit)
    local damaged = (f.key == "player" and cur < max)
    if damaged then col = PlayerDamagedColor() end
    h.bar:SetStatusBarColor(col[1], col[2], col[3])
    local tex = h.bar:GetStatusBarTexture()
    if tex then tex:SetVertexColor(col[1], col[2], col[3]) end
    if f.key == "player" then
        if not IsHud() then
            if damaged then
                SetBarFrameColor(h, 0.50, 0.30, 0.28, 0.45)
            else
                SetBarFrameColor(h, 0.35, 0.33, 0.30, 0.40)
            end
        end
    else
        SetBarFrameColor(h, 0.40, 0.38, 0.35, 0.45)
    end

    -- Jogador (Azaath): valor centralizado
    if h.centerText then
        local text
        if UnitIsGhost(unit) then
            text = "Fantasma"
        elseif UnitIsDead(unit) then
            text = "Morto"
        else
            text = Azaath.Thousands(cur)
        end
        if h.secretStyled then
            -- volta ao estilo Azaath (sem contorno) depois de um período com valores secretos
            local font, size = h.centerText:GetFont()
            h.centerText:SetFont(font or Azaath.media.fontBold, size or 13, "")
            h.secretStyled = nil
        end
        h.centerText:SetText(text)
        if IsHud() then
            h.centerText:SetTextColor(1, 1, 1)
            h.centerText:SetShadowOffset(1, -1)
            h.centerText:SetShadowColor(0, 0, 0, 0.85)
        else
            -- HUD Azaath: valor sempre claro com sombra (como a captura)
            local darkText = (cur >= max) and not IsHud()
            local tc = darkText and TEXT_DARK or TEXT_LIGHT
            h.centerText:SetTextColor(tc[1], tc[2], tc[3])
            if darkText then
                h.centerText:SetShadowOffset(0, 0)
            else
                h.centerText:SetShadowOffset(1, -1)
                h.centerText:SetShadowColor(0, 0, 0, 0.85)
            end
        end
        if f.key == "player" then UpdatePlayerFade(f, cur >= max) end
        return
    end

    if not h.leftText then return end
    if not UnitIsConnected(unit) then
        h.leftText:SetText("Offline")
        h.rightText:SetText("")
    elseif UnitIsGhost(unit) then
        h.leftText:SetText("Fantasma")
        h.rightText:SetText("")
    elseif UnitIsDead(unit) then
        h.leftText:SetText("Morto")
        h.rightText:SetText("")
    else
        h.leftText:SetText(Short(cur))
        h.rightText:SetText(Percent(cur, max))
    end
end

local function UpdatePower(f, instant)
    local unit, p = f.displayUnit, f.power
    local max = UnitPowerMax(unit)
    local secret = Azaath.IsSecret(max)
    if not secret and (max <= 0 or not UnitIsConnected(unit)) then
        p:Hide()
        f.lastPower = nil
        return
    end
    p:Show()

    local cur = UnitPower(unit)
    local ptype = UnitPowerType(unit)
    if ptype ~= p.ptype then
        local col = POWER_COLORS[ptype] or POWER_FALLBACK
        p.bar:SetStatusBarColor(col[1], col[2], col[3])
        local tex = p.bar:GetStatusBarTexture()
        if tex then tex:SetVertexColor(col[1], col[2], col[3]) end
        -- moldura fina e discreta
        SetBarFrameColor(
            p,
            0.32 + col[1] * 0.15,
            0.30 + col[2] * 0.15,
            0.28 + col[3] * 0.15,
            0.40
        )
        p.ptype = ptype
        if p.centerText then
            -- HUD Azaath: valor escuro sobre o amarelo da energia; claro nas demais
            if ptype == 3 then
                p.centerText:SetTextColor(0.10, 0.10, 0.10)
                p.centerText:SetShadowOffset(0, 0)
            else
                p.centerText:SetTextColor(0.96, 0.96, 0.96)
                p.centerText:SetShadowOffset(1, -1)
                p.centerText:SetShadowColor(0, 0, 0, 0.9)
            end
        end
    end
    SetBarValues(p, cur, max, instant)

    if secret or Azaath.IsSecret(cur) then
        -- sem comparações: barra sempre visível, texto direto do widget
        f.lastPower = nil
        p:SetAlpha(1)
        if p.leftText then
            p.leftText:SetText(cur)
            p.rightText:SetText("")
        end
        if p.centerText then p.centerText:SetText(cur) end
        return
    end
    f.lastPower = cur

    -- Jogador (Azaath): a barra de recurso some quando está "em repouso" fora de
    -- combate (mana/energia cheias, raiva/poder rúnico zerados).
    if p.centerText then p.centerText:SetText(cur) end
    if f.key == "player" and not IsHud() then
        local full, empty = cur >= max, cur <= 0
        local resting = (ptype == 0 or ptype == 3) and full or (ptype == 1 or ptype == 6) and empty
        p:SetAlpha((resting and not playerInCombat and not M.editing) and 0 or 1)
    end

    if p.leftText then
        p.leftText:SetText(Short(cur))
        -- porcentagem só faz sentido para mana; raiva/energia/runa já são 0–100
        p.rightText:SetText(ptype == 0 and Percent(cur, max) or "")
    end
end

local function UpdateInfo(f)
    if f.az then
        UpdateAzInfo(f)
        return
    end
    if not f.nameText then return end
    local unit = f.displayUnit

    local name = GetUnitDisplayName(unit)
    f.nameText:SetText(name)

    local r, g, b = 1, 1, 1
    if UnitIsPlayer(unit) then
        local _, class = UnitClass(unit)
        local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if cc then
            r, g, b = cc.r, cc.g, cc.b
        else
            local c = Azaath.colors.cream
            r, g, b = c[1], c[2], c[3]
        end
    else
        local col = REACTION[ReactionKey(unit)] or Azaath.colors.cream
        r, g, b = col[1], col[2], col[3]
    end
    f.nameText:SetTextColor(r, g, b)

    -- Atualiza o pequeno cristal de nível estilo Azaath (AllyDiamond)
    if f.diamond then
        local level = UnitLevel(unit)
        local suffix = CLASSIFICATION_SUFFIX[UnitClassification(unit)] or ""
        if level and level > 0 then
            f.levelText:SetText(level .. suffix)
            local getColor = GetQuestDifficultyColor or GetDifficultyColor
            local dc = getColor and getColor(level)
            if dc then
                f.levelText:SetTextColor(dc.r, dc.g, dc.b)
            else
                f.levelText:SetTextColor(1, 1, 1)
            end
        else
            f.levelText:SetText("??" .. suffix)
            f.levelText:SetTextColor(1, 0.25, 0.2)
        end
        if f.diamond.tex then
            f.diamond.tex:SetVertexColor(r * 0.85 + 0.15, g * 0.85 + 0.15, b * 0.85 + 0.15)
        end
        if f.diamond.rare then
            local okC, class = pcall(UnitClassification, unit)
            local style = okC and class and not Azaath.IsSecret(class) and ELITE_STYLE[class]
            if style then
                f.diamond.rare:SetTexture(Azaath.media.path .. "BDO\\" .. (style == "EliteGold" and "RareGold" or "RareSilver"))
                f.diamond.rare:Show()
            else
                f.diamond.rare:Hide()
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Cura prevista (como o recurso da Blizzard): faixa verde-clara logo depois
-- do preenchimento da vida, do tamanho da cura que está sendo conjurada no
-- jogador/alvo/grupo. Vale para todas as disposições (Modern, Classic,
-- Custom), para o alvo e para os quadros de grupo (Azaath.UpdateHealPrediction).
-- Sem contas: a faixa é uma StatusBar com a mesma largura da
-- vida, presa na ponta do preenchimento; o widget faz a proporção (aceita
-- valores secretos) e o que passar do fim da barra é cortado.
--------------------------------------------------------------------------------
local HEAL_COLOR = { 0.42, 1.00, 0.48 }
local HEAL_ALPHA = 0.50

local function EnsureHealBar(bar)
    if bar.azHealBar ~= nil then return bar.azHealBar or nil end
    local tex = bar:GetStatusBarTexture()
    if not tex then
        bar.azHealBar = false
        return nil
    end
    if bar.SetClipsChildren then pcall(bar.SetClipsChildren, bar, true) end
    local hb = CreateFrame("StatusBar", nil, bar)
    hb:SetStatusBarTexture(Azaath.media.blank)
    hb:SetStatusBarColor(HEAL_COLOR[1], HEAL_COLOR[2], HEAL_COLOR[3])
    hb:SetAlpha(HEAL_ALPHA)
    hb:SetPoint("TOPLEFT", tex, "TOPRIGHT", 0, 0)
    hb:SetPoint("BOTTOMLEFT", tex, "BOTTOMRIGHT", 0, 0)
    hb:SetWidth(math.max(1, bar:GetWidth() or 1))
    -- mesmo nível da vida: fica abaixo da moldura e dos textos (overlay = +1)
    hb:SetFrameLevel(bar:GetFrameLevel())
    hb:SetMinMaxValues(0, 1)
    hb:SetValue(0)
    bar:HookScript("OnSizeChanged", function(_, w)
        if w and w > 0 then hb:SetWidth(w) end
    end)
    bar.azHealBar = hb
    return hb
end

local healCalc
local function IncomingHeals(unit)
    if UnitGetIncomingHeals then
        local ok, v = pcall(UnitGetIncomingHeals, unit)
        if ok and v ~= nil then return v end
    end
    -- cliente moderno: calculadora de previsão de cura
    if _G.CreateUnitHealPredictionCalculator and _G.UnitGetDetailedHealPrediction then
        local ok, v = pcall(function()
            healCalc = healCalc or CreateUnitHealPredictionCalculator()
            UnitGetDetailedHealPrediction(unit, nil, healCalc)
            return (healCalc:GetIncomingHeals())
        end)
        if ok then return v end
    end
    return nil
end

-- bar = StatusBar da vida; unit = unidade mostrada nela; hide = esconder já
function Azaath.UpdateHealPrediction(bar, unit, hide)
    if not bar or not bar.GetStatusBarTexture then return end
    local hb = EnsureHealBar(bar)
    if not hb then return end
    if hide then
        hb:SetValue(0)
        return
    end
    local inc = IncomingHeals(unit)
    if inc == nil or not UnitExists(unit) then
        hb:SetValue(0)
        return
    end
    if not pcall(function()
        hb:SetMinMaxValues(0, UnitHealthMax(unit))
        hb:SetValue(inc)
    end) then
        hb:SetValue(0)
    end
end

local function UpdateHealPrediction(f)
    if f.health then Azaath.UpdateHealPrediction(f.health.bar, f.displayUnit) end
end

local function UpdateHealthAndHeal(f, instant)
    UpdateHealth(f, instant)
    UpdateHealPrediction(f)
end

local function Refresh(f, instant)
    if not UnitExists(f.displayUnit) then return end
    UpdateHealth(f, instant)
    UpdateHealPrediction(f)
    UpdatePower(f, instant)
    UpdateInfo(f)
end

--------------------------------------------------------------------------------
-- Construção dos frames
--------------------------------------------------------------------------------
local frames = {} -- [key] = frame

local function PlayerPowerPoll(self, elapsed)
    self.pollElapsed = self.pollElapsed + elapsed
    if self.pollElapsed < POWER_POLL then return end
    self.pollElapsed = 0
    -- lastPower nil ou valor secreto (não comparável): atualiza sempre (barato)
    local curPower = UnitPower(self.displayUnit)
    if Azaath.IsSecret(curPower) or not self.lastPower or curPower ~= self.lastPower then
        UpdatePower(self)
    end
end

--------------------------------------------------------------------------------
-- HUD Azaath (layout "az"): placa escura com recurso em cima e vida embaixo,
-- preenchimento liso (Media/UnitFrames/HudFill, tingido pela cor), espadas
-- cruzadas à esquerda da vida e divisões em terços no recurso.
--------------------------------------------------------------------------------
-- Moldura de ferro/ardósia chanfrada com reflexo metálico (estilo Azaath)
local function PixelBorder(owner, target, c)
    local lines = {}
    local col = c or { 0.28, 0.30, 0.34, 1 }

    -- Contorno de ferro escuro (1px por fora)
    local t1 = owner:CreateTexture(nil, "OVERLAY", nil, 6)
    t1:SetTexture(Azaath.media.blank)
    t1:SetVertexColor(0.08, 0.08, 0.10, 0.95)
    t1:SetPoint("BOTTOMLEFT", target, "TOPLEFT", -1, 0)
    t1:SetPoint("BOTTOMRIGHT", target, "TOPRIGHT", 1, 0)
    t1:SetHeight(1)
    lines[1] = t1

    local t2 = owner:CreateTexture(nil, "OVERLAY", nil, 6)
    t2:SetTexture(Azaath.media.blank)
    t2:SetVertexColor(0.08, 0.08, 0.10, 0.95)
    t2:SetPoint("TOPLEFT", target, "BOTTOMLEFT", -1, 0)
    t2:SetPoint("TOPRIGHT", target, "BOTTOMRIGHT", 1, 0)
    t2:SetHeight(1)
    lines[2] = t2

    local t3 = owner:CreateTexture(nil, "OVERLAY", nil, 6)
    t3:SetTexture(Azaath.media.blank)
    t3:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
    t3:SetPoint("TOPRIGHT", target, "TOPLEFT", 0, 0)
    t3:SetPoint("BOTTOMRIGHT", target, "BOTTOMLEFT", 0, 0)
    t3:SetWidth(1)
    lines[3] = t3

    local t4 = owner:CreateTexture(nil, "OVERLAY", nil, 6)
    t4:SetTexture(Azaath.media.blank)
    t4:SetVertexColor(col[1], col[2], col[3], col[4] or 1)
    t4:SetPoint("TOPLEFT", target, "TOPRIGHT", 0, 0)
    t4:SetPoint("BOTTOMLEFT", target, "BOTTOMRIGHT", 0, 0)
    t4:SetWidth(1)
    lines[4] = t4

    -- Chanfro interno metálico (crista com brilho de aço e base sombreada)
    local hl = owner:CreateTexture(nil, "OVERLAY", nil, 7)
    hl:SetTexture(Azaath.media.blank)
    hl:SetVertexColor(0.50, 0.54, 0.60, 0.50)
    hl:SetPoint("TOPLEFT", target, "TOPLEFT", 0, 0)
    hl:SetPoint("TOPRIGHT", target, "TOPRIGHT", 0, 0)
    hl:SetHeight(1)
    lines[5] = hl

    local sh = owner:CreateTexture(nil, "OVERLAY", nil, 7)
    sh:SetTexture(Azaath.media.blank)
    sh:SetVertexColor(0.04, 0.04, 0.05, 0.60)
    sh:SetPoint("BOTTOMLEFT", target, "BOTTOMLEFT", 0, 0)
    sh:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 0, 0)
    sh:SetHeight(1)
    lines[6] = sh

    return lines
end
Azaath.PixelBorder = PixelBorder

local function LayoutHudDividers(p)
    local divs = p.hudDividers
    if not divs then return end
    local w = p:GetWidth()
    if not w or w <= 0 then return end
    local pcts = { 0.25, 0.50, 0.75 }
    for i, d in ipairs(divs) do
        local pct = pcts[i] or (i / (#divs + 1))
        local x = math.floor(w * pct + 0.5)
        d:ClearAllPoints()
        d:SetPoint("TOPLEFT", p, "TOPLEFT", x, 0)
        d:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", x, 0)
    end
end

-- Uma barra da HUD: fundo escuro (BACKGROUND), preenchimento Azaath (ARTWORK),
-- moldura de ferro ardósia e divisórias (OVERLAY, num frame acima do preenchimento)
local function StyleHud(f)
    if f.hudStyled then return end
    f.hudStyled = true
    local h, p = f.health, f.power

    -- 1. Fundo escuro uniforme com degradê sutil sem hachuras (Background Frame)
    h.bgTex:SetTexture(UnitFrameTex("HudEmpty"))
    h.bgTex:SetVertexColor(1, 1, 1, 0.95)
    p.bgTex:SetTexture(UnitFrameTex("HudEmpty"))
    p.bgTex:SetVertexColor(1, 1, 1, 0.95)

    -- 2. StatusBars (Preenchimento liso e sedoso original do Azaath via HudFill)
    h.bar:SetStatusBarTexture(UnitFrameTex("HudFill"))
    p.bar:SetStatusBarTexture(UnitFrameTex("HudFill"))
    if h.fillHatch then h.fillHatch:Hide() end
    if p.fillHatch then p.fillHatch:Hide() end
    if h.gloss then h.gloss:Hide() end
    if p.gloss then p.gloss:Hide() end

    -- 3. Overlay Frame (Molduras, divisórias e detalhes em Strata HIGH)
    local overlay = CreateFrame("Frame", "AzaathUIPlayerOverlay", f)
    overlay:SetFrameStrata("HIGH")
    overlay:SetAllPoints(f)
    f.hudOverlay = overlay

    -- Moldura metálica chanfrada ultra-limpa estilo Azaath
    PixelBorder(overlay, h, { HUD.BORDER[1], HUD.BORDER[2], HUD.BORDER[3], HUD.BORDER[4] })
    PixelBorder(overlay, p, { HUD.OUTLINE[1], HUD.OUTLINE[2], HUD.OUTLINE[3], HUD.OUTLINE[4] })

    -- Separadores da Barra Superior em 25%, 50% e 75% da largura (linhas finas de 1px)
    p.hudDividers = {}
    for i = 1, 3 do
        local d = overlay:CreateTexture(nil, "OVERLAY")
        d:SetTexture(Azaath.media.blank)
        d:SetVertexColor(0.08, 0.08, 0.10, 0.90)
        d:SetWidth(1)
        p.hudDividers[i] = d
    end
    p:HookScript("OnSizeChanged", LayoutHudDividers)
    LayoutHudDividers(p)

    -- Oculta elementos que não pertencem ao HUD
    if h.diamondCrest then h.diamondCrest:Hide() end
    if h.badge then h.badge:Hide() end
    if h.borderTex then h.borderTex:Hide() end
    if p.borderTex then p.borderTex:Hide() end

    -- Texto da Vida ancorado no Overlay Frame (centralizado e nítido)
    if h.centerText then
        h.centerText:SetParent(overlay)
        h.centerText:SetFont(Azaath.media.fontBold, HUD.FONT_SIZE or 14, "")
        h.centerText:ClearAllPoints()
        h.centerText:SetPoint("CENTER", h, "CENTER", 0, 0)
        h.centerText:SetTextColor(0.96, 0.96, 0.96)
        h.centerText:SetShadowOffset(1, -1)
        h.centerText:SetShadowColor(0, 0, 0, 0.90)
    end
end

-- Altura total do quadro do jogador
local function PlayerFrameHeight(f, hh, ph)
    if f.hudStyled then return hh + ph + 1 end -- recurso encostado (linha comum)
    return hh + (ph > 0 and (BAR_GAP + ph) or 0)
end

-- Posiciona as barras do jogador: HUD (recurso em cima) ou padrão (vida em cima)
local function ArrangePlayerBars(f, hh, ph)
    local h, p = f.health, f.power
    h:ClearAllPoints()
    p:ClearAllPoints()
    if f.hudStyled then
        p:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        p:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        h:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 0, 0)
        h:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", 0, 0)
        LayoutHudDividers(p)
    else
        h:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 0)
        h:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 0)
        p:SetPoint("TOPLEFT", h, "BOTTOMLEFT", 0, -BAR_GAP)
        p:SetPoint("TOPRIGHT", h, "BOTTOMRIGHT", 0, -BAR_GAP)
    end
end

local function CreateUnitFrame(key, cfg)
    local f = CreateFrame("Frame", "AzaathUI" .. (key == "player" and "Player" or "Target"), Azaath.root)
    f.key, f.unit, f.displayUnit, f.cfg = key, key, key, cfg
    f:SetFrameStrata("LOW")
    f:EnableMouse(false)

    local isPlayer = (key == "player")
    f.health = CreateBar(f, cfg.healthHeight, isPlayer and 0 or (cfg.healthFont or 11), true, false)
    f.power  = CreateBar(f, cfg.powerHeight, isPlayer and 0 or (cfg.powerFont or 0), isPlayer, true)

    if isPlayer then
        -- Estilo Azaath: barras de vida e raiva/recurso com textura e arte de pintura,
        -- "+" branco na ponta esquerda e valor atual centralizado
        local h = f.health
        h.bar:SetStatusBarTexture(UnitFrameTex("HealthFill"))
        h.gloss:Hide()
        -- dano: pedaço perdido acende em branco granulado e some (modo flash)
        h.trail:SetStatusBarTexture(TargetTex("Flash"))
        h.trail:SetStatusBarColor(1, 1, 1)
        h.trail:SetAlpha(0)
        h.flashMode = true

        -- recurso (raiva/mana/energia): rastro pintado ao gastar recurso
        if f.power.trail then
            f.power.trail:SetStatusBarTexture(TargetTex("Flash"))
            f.power.trail:SetStatusBarColor(1, 0.92, 0.76)
            f.power.trail:SetAlpha(0.55)
        end

        local overlay = CreateFrame("Frame", nil, h)
        overlay:SetAllPoints(h)
        overlay:SetFrameLevel(h.bar:GetFrameLevel() + 2)

        -- Brasão central de diamante (estilo Azaath / Aeternum)
        local diamondCrest = CreateFrame("Frame", nil, overlay)
        diamondCrest:SetSize(20, 20)
        diamondCrest:SetPoint("CENTER", overlay, "TOP", 0, 8)
        diamondCrest:SetFrameLevel(overlay:GetFrameLevel() + 5)

        local diaTex = diamondCrest:CreateTexture(nil, "ARTWORK")
        diaTex:SetTexture(TargetTex("AllyDiamond"))
        diaTex:SetAllPoints(diamondCrest)
        diamondCrest.tex = diaTex
        h.diamondCrest = diamondCrest
        diamondCrest:Hide() -- losango decorativo sobre a vida: removido a pedido (sem utilidade)

        -- "+" branco na extremidade esquerda (sem caixinha, como no Azaath)
        local badgeSize = math.max(14, cfg.healthHeight - 6)
        local badge = CreateFrame("Frame", nil, overlay)
        badge:SetWidth(badgeSize)
        badge:SetHeight(badgeSize)
        badge:SetPoint("LEFT", overlay, "LEFT", 5, 0)
        local plus = badge:CreateFontString(nil, "OVERLAY")
        plus:SetFont(Azaath.media.fontBold, badgeSize, "")
        plus:SetTextColor(1, 1, 1)
        plus:SetShadowOffset(1, -1)
        plus:SetShadowColor(0, 0, 0, 0.75)
        plus:SetPoint("CENTER", badge, "CENTER", 0, 0)
        plus:SetText("+")
        h.badge = badge
        h.plus = plus

        local value = overlay:CreateFontString(nil, "OVERLAY")
        value:SetFont(Azaath.media.fontBold, cfg.healthFont or 13, "")
        value:SetShadowOffset(0, 0)
        value:SetTextColor(TEXT_DARK[1], TEXT_DARK[2], TEXT_DARK[3])
        value:SetPoint("CENTER", overlay, "CENTER", 0, 0)
        h.centerText = value

        -- transparência fora de combate com vida cheia
        local fader = CreateFrame("Frame", nil, f)
        fader.holder = h
        fader.target = 1
        h.fader = fader

        -- Cliques como no quadro de jogador da Blizzard: botão seguro sobre a
        -- barra de vida. Esquerdo = selecionar a si mesmo; direito = menu do
        -- jogador da PRÓPRIA Blizzard ("togglemenu", caminho seguro: Definir
        -- foco, marcadores, PvP, saque etc. funcionam sem taint), pintado no
        -- visual Azaath pelo módulo Skins.
        local click = CreateFrame("Button", "AzaathUIPlayerClick", f, "SecureUnitButtonTemplate")
        click:SetPoint("TOPLEFT", h, "TOPLEFT")
        click:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT")
        click:SetFrameLevel(h:GetFrameLevel() + 10)
        click:RegisterForClicks("AnyUp")
        click:SetAttribute("unit", "player")
        click:SetAttribute("*type1", "target")
        if Azaath.IS_MODERN then
            click:SetAttribute("*type2", "togglemenu")
            if Azaath.RegisterAzMenuOwner then Azaath.RegisterAzMenuOwner(click) end
        end
        -- dica do jogador ao passar o mouse, como no quadro padrão
        click:SetScript("OnEnter", function(self)
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetUnit("player")
            GameTooltip:Show()
        end)
        click:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        f.clickButton = click
    else
        -- Alvo no estilo Azaath (semelhante ao quadro de aliado / party):
        -- Pequeno cristal de nível (AllyDiamond) à esquerda do nome,
        -- nome em serifa com a cor da classe/reação, barra texturizada
        -- com a cor da classe/reação, informações de vida (valor e %)
        -- e barra de recurso embaixo.
        local top = 22
        local diamondSize = 22

        -- Pequeno cristal do nível (losango preto com aro fino de metal)
        local dia = CreateFrame("Frame", nil, f)
        dia:SetSize(diamondSize, diamondSize)
        dia:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", 1, 2)

        local diaTex = dia:CreateTexture(nil, "ARTWORK")
        diaTex:SetTexture(TargetTex("AllyDiamond"))
        diaTex:SetSize(diamondSize * 26 / 22, diamondSize * 26 / 22)
        diaTex:SetPoint("CENTER", dia, "CENTER")

        -- raro/elite: lâminas cravadas no losango (mesma arte da Zerker, Media/BDO/Rare*)
        local rare = dia:CreateTexture(nil, "ARTWORK", nil, 2)
        rare:SetSize(diamondSize * 1.85, diamondSize * 1.85)
        rare:SetPoint("CENTER", dia, "CENTER")
        rare:Hide()
        dia.rare = rare

        local levelText = dia:CreateFontString(nil, "OVERLAY")
        levelText:SetFont(Azaath.media.fontBold, 11, "")
        levelText:SetShadowOffset(1, -1)
        levelText:SetShadowColor(0, 0, 0, 0.95)
        levelText:SetPoint("CENTER", dia, "CENTER", 0, 0)

        dia.tex = diaTex
        f.diamond = dia
        f.levelText = levelText

        -- Nome do alvo logo ao lado do cristal (fonte Cinzel / Azaath com serifa)
        f.nameText = CreateText(f, cfg.nameFont or 14, "LEFT")
        f.nameText:SetFont(Azaath.media.fontTitle, cfg.nameFont or 14, "OUTLINE")
        f.nameText:SetPoint("LEFT", dia, "RIGHT", 6, 0)
        f.nameText:SetPoint("RIGHT", f.health, "RIGHT", -2, 0)
        f.nameText:SetHeight(20)

        -- Estilização da barra de vida e recurso do alvo no visual pintado Azaath
        f.health.bar:SetStatusBarTexture(UnitFrameTex("HealthFill"))
        if f.health.borderTex then
            f.health.borderTex:SetVertexColor(0.86, 0.76, 0.56, 0.88)
        end

        -- Botão de clique seguro sobre todo o quadro (interações, menu Azaath, foco, tooltip)
        local click = CreateFrame("Button", "AzaathUITargetClick", f, "SecureUnitButtonTemplate")
        click:SetPoint("TOPLEFT", f, "TOPLEFT")
        click:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT")
        click:SetFrameLevel(f.health:GetFrameLevel() + 10)
        click:RegisterForClicks("AnyUp")
        click:SetAttribute("unit", "target")
        click:SetAttribute("*type1", "target")
        if Azaath.IS_MODERN then
            click:SetAttribute("*type2", "togglemenu")
            if Azaath.RegisterAzMenuOwner then Azaath.RegisterAzMenuOwner(click) end
        else
            click:SetAttribute("*type2", "menu")
            click.menu = function()
                if _G.TargetFrameDropDown then
                    ToggleDropDownMenu(1, nil, _G.TargetFrameDropDown, "cursor")
                end
            end
        end
        click:SetAttribute("*type3", "focus")
        click:SetScript("OnEnter", function(self)
            GameTooltip_SetDefaultAnchor(GameTooltip, self)
            GameTooltip:SetUnit("target")
            GameTooltip:Show()
        end)
        click:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)
        f.clickButton = click

        -- Visibilidade gerenciada de forma segura via RegisterUnitWatch para
        -- evitar erros de ação bloqueada (ADDON_ACTION_BLOCKED) ao trocar de
        -- alvo durante combate.
        f:SetAttribute("unit", "target")
        RegisterUnitWatch(f)
        f:HookScript("OnShow", function(self)
            Refresh(self, true)
        end)

        f.topOffset = top
    end

    if key == "player" then
        f:SetScale(cfg.scale and cfg.scale > 0 and cfg.scale or 1)
        f:SetWidth(cfg.width)
        f:SetHeight(cfg.healthHeight + BAR_GAP + cfg.powerHeight)

        if IsHud() then StyleHud(f) end
        f:SetHeight(PlayerFrameHeight(f, cfg.healthHeight, cfg.powerHeight))
        ArrangePlayerBars(f, cfg.healthHeight, cfg.powerHeight)

        f:SetPoint("BOTTOM", Azaath.root, "BOTTOM", cfg.offsetX or 0, cfg.offsetY)
        f.pollElapsed = 0
        f:SetScript("OnUpdate", PlayerPowerPoll)
    else
        local top = f.topOffset or 22
        local hasPower = cfg.powerHeight and cfg.powerHeight > 0
        local powerH = hasPower and cfg.powerHeight or 0
        local totalH = top + cfg.healthHeight + BAR_GAP + powerH

        f:SetScale(cfg.scale and cfg.scale > 0 and cfg.scale or 1)
        f:SetWidth(cfg.width)
        f:SetHeight(totalH)

        f.health:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top)
        f.health:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -top)
        f.power:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", 0, -BAR_GAP)
        f.power:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", 0, -BAR_GAP)

        f:SetPoint("TOP", Azaath.root, "TOP", cfg.offsetX or 0, cfg.offsetY)
        f:Hide()
    end

    LayoutBarArt(f.health)
    LayoutBarArt(f.power)

    frames[key] = f
    return f
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local function UpdateInfoAndHealth(f)
    UpdateHealth(f)
    UpdateInfo(f)
end

-- Eventos de unidade -> função de atualização
local UNIT_EVENTS = {
    UNIT_HEALTH         = UpdateHealthAndHeal,
    UNIT_MAXHEALTH      = UpdateHealthAndHeal,
    UNIT_HEAL_PREDICTION = UpdateHealPrediction, -- cura sendo conjurada na unidade
    UNIT_DYNAMIC_FLAGS  = UpdateHealth, -- tapped/untapped
    UNIT_FACTION        = UpdateInfoAndHealth,
    UNIT_MANA           = UpdatePower,
    UNIT_RAGE           = UpdatePower,
    UNIT_ENERGY         = UpdatePower,
    UNIT_FOCUS          = UpdatePower,
    UNIT_RUNIC_POWER    = UpdatePower,
    UNIT_MAXMANA        = UpdatePower,
    UNIT_MAXRAGE        = UpdatePower,
    UNIT_MAXENERGY      = UpdatePower,
    UNIT_MAXFOCUS       = UpdatePower,
    UNIT_MAXRUNIC_POWER = UpdatePower,
    UNIT_DISPLAYPOWER   = UpdatePower,
    -- cliente moderno (WoW Forever): eventos unificados de recurso e marcação
    UNIT_POWER_UPDATE   = UpdatePower,
    UNIT_MAXPOWER       = UpdatePower,
    UNIT_FLAGS          = UpdateHealth,
    UNIT_CONNECTION     = UpdateHealth,
    UNIT_NAME_UPDATE    = UpdateInfo,
    UNIT_LEVEL          = UpdateInfo,
    UNIT_CLASSIFICATION_CHANGED = UpdateInfo, -- asas de elite
}

local function ShowTargetPreview(f)
    if not f then return end
    if f.az then
        SetBarValues(f.health, 100, 100, true)
        ApplyTargetColors(f, "hostile")
        SetTargetCombat(f, true)
        local c = NAME_COLOR
        SetTargetName(f, "Alvo", c[1], c[2], c[3])
        if f.levelText then f.levelText:SetText("80") end
        if f.skull then f.skull:Hide() end
        if f.elite then f.elite:Hide() end
    end
end

local function UpdateTarget()
    local f = frames.target
    if not f then return end
    if not Azaath.TargetFrameOn() then
        if not InCombatLockdown() then
            if f._azWatched ~= false then
                UnregisterUnitWatch(f)
                f._azWatched = false
            end
            f:Hide()
        end
        return
    end
    if UnitExists("target") then
        if not InCombatLockdown() then
            if not f._azWatched then
                RegisterUnitWatch(f)
                f._azWatched = true
            end
            f:Show()
        end
        Refresh(f, true)
    elseif M.editing then
        ShowTargetPreview(f)
        if not InCombatLockdown() then
            if f._azWatched ~= false then
                UnregisterUnitWatch(f)
                f._azWatched = false
            end
            f:Show()
        end
    else
        if not InCombatLockdown() then
            if not f._azWatched then
                RegisterUnitWatch(f)
                f._azWatched = true
            end
            f:Hide()
        end
    end
end

-- Em veículos com interface própria, a barra do jogador mostra o veículo.
local function UpdatePlayerUnit(force)
    local f = frames.player
    if not f then return end
    local unit = (UnitHasVehicleUI and UnitHasVehicleUI("player")) and "vehicle" or "player"
    if force or unit ~= f.displayUnit then
        f.displayUnit = unit
        Refresh(f, true)
    end
end

function M:ApplyLayout()
    -- skin Blizzard: ficam os quadros de jogador e alvo do jogo (HideBlizz não os esconde)
    if Azaath.IsBlizzSkin() then return end
    Azaath:RunOutOfCombat(function()
        if self._inApply then return end
        self._inApply = true
        local db = (Azaath.db and Azaath.db.unitframes) or self.db
        self.db = db
        local pCfg = db and db.player
        if pCfg then
            if pCfg.enabled and not frames.player then
                CreateUnitFrame("player", pCfg)
            end
            local pf = frames.player
            if pf then
                -- skin Azaath/BDO: vida/recurso/XP vivem na HUD própria
                if not pCfg.enabled or (Azaath.IsAzaath and Azaath.IsAzaath()) or (Azaath.IsBDO and Azaath.IsBDO()) then
                    pf:Hide()
                    if pf.health and pf.health.fader then
                        pf.health.fader:SetScript("OnUpdate", nil)
                    end
                else
                    pf:Show()
                    local w = math.max(120, pCfg.width or 270)
                    local hh = math.max(8, pCfg.healthHeight or 22)
                    local ph = math.max(0, pCfg.powerHeight or 9)
                    pf:SetScale((pCfg.scale and pCfg.scale > 0) and pCfg.scale or 1)
                    pf:SetWidth(w)
                    pf:SetHeight(PlayerFrameHeight(pf, hh, ph))
                    pf.health:SetHeight(hh)
                    if pf.health.gloss then pf.health.gloss:SetHeight(floor(hh / 2)) end
                    if pf.health.badge then
                        local bSize = math.max(12, hh - 6)
                        pf.health.badge:SetWidth(bSize)
                        pf.health.badge:SetHeight(bSize)
                        if pf.health.plus then
                            pf.health.plus:SetFont(Azaath.media.fontBold, bSize, "")
                        end
                    end
                    if pf.health.centerText then
                        pf.health.centerText:SetFont(Azaath.media.fontBold, pCfg.healthFont or 13, "")
                    end
                    pf.power:SetHeight(math.max(1, ph))
                    if pf.power.gloss then pf.power.gloss:SetHeight(floor(math.max(1, ph) / 2)) end
                    if IsHud() then StyleHud(pf) end
                    ArrangePlayerBars(pf, hh, ph)
                    LayoutBarArt(pf.health)
                    LayoutBarArt(pf.power)
                    pf:ClearAllPoints()
                    pf:SetPoint("BOTTOM", Azaath.root, "BOTTOM", pCfg.offsetX or 0, pCfg.offsetY or 70)
                    if Azaath.ClampToScreen then Azaath.ClampToScreen(pf) end
                    Refresh(pf, true)
                    UpdatePlayerFade(pf)
                end
            end
        end

        local tCfg = db and db.target
        if tCfg then
            local isBDO = Azaath.IsBDO and Azaath.IsBDO()
            if Azaath.TargetFrameOn() and not frames.target then
                CreateUnitFrame("target", tCfg)
            end
            local tf = frames.target
            if tf then
                if not Azaath.TargetFrameOn() then
                    UnregisterUnitWatch(tf)
                    tf:Hide()
                else
                    -- na skin Zerker este quadro nunca aparece, mesmo antes da BDOHUD montar o dela
                    local bz = isBDO and (Azaath.BDOTargetBox or { w = tf:GetWidth(), h = tf:GetHeight() })
                    tf:SetScale((tCfg.scale and tCfg.scale > 0) and tCfg.scale or 1)
                    if bz then
                        -- skin Zerker: o quadro de alvo é o da BDOHUD; este fica invisível, sem clique,
                        -- com o mesmo tamanho dele (continua servindo de âncora para buffs e conjuração)
                        tf:SetWidth(bz.w)
                        tf:SetHeight(bz.h)
                        tf:SetAlpha(0)
                    else
                        local w = math.max(120, tCfg.width or 300)
                        local hh = math.max(8, tCfg.healthHeight or 14)
                        local ph = math.max(0, tCfg.powerHeight or 4)
                        local top = tf.topOffset or 22
                        tf:SetWidth(w)
                        tf:SetHeight(top + hh + (ph > 0 and (BAR_GAP + ph) or 0))
                        tf.health:SetHeight(hh)
                        if tf.health.gloss then tf.health.gloss:SetHeight(floor(hh / 2)) end
                        if tf.health.leftText and (tCfg.healthFont or 11) > 0 then
                            tf.health.leftText:SetFont(Azaath.media.font, tCfg.healthFont or 11, "OUTLINE")
                            tf.health.rightText:SetFont(Azaath.media.font, tCfg.healthFont or 11, "OUTLINE")
                        end
                        if tf.nameText then
                            tf.nameText:SetFont(Azaath.media.fontTitle, tCfg.nameFont or 14, "OUTLINE")
                        end
                        tf.power:SetHeight(math.max(1, ph))
                        if tf.power.gloss then tf.power.gloss:SetHeight(floor(math.max(1, ph) / 2)) end
                        LayoutBarArt(tf.health)
                        LayoutBarArt(tf.power)
                        tf:SetAlpha(1)
                    end
                    tf:ClearAllPoints()
                    tf:SetPoint("TOP", Azaath.root, "TOP", tCfg.offsetX or 0, tCfg.offsetY or -78)
                    UpdateTarget()
                    if Azaath.ClampToScreen then Azaath.ClampToScreen(tf) end
                    if _G.AzaathUITargetClick then _G.AzaathUITargetClick:EnableMouse(not bz) end
                    if Azaath.ApplyBDOTarget then Azaath.ApplyBDOTarget() end
                end
            end
        end

        self._inApply = false
        local cb = Azaath:GetModule("CastBar")
        if cb and cb.ApplyLayout then cb:ApplyLayout() end
        local auras = Azaath:GetModule("Auras")
        if auras and auras.ApplyLayout then auras:ApplyLayout() end
        local xp = Azaath:GetModule("Experience")
        if xp and xp.ApplyLayout then xp:ApplyLayout() end
    end)
end

function M:SetEditing(editing)
    self.editing = editing and true or false
    if frames.player then
        UpdatePower(frames.player, true)
        UpdatePlayerFade(frames.player)
    end
    if self.editing or (Azaath.IsBDO and Azaath.IsBDO()) then
        self:ApplyLayout()
    elseif frames.target then
        Azaath:RunOutOfCombat(UpdateTarget)
    end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
    local fn = UNIT_EVENTS[event]
    if fn then
        for _, f in pairs(frames) do
            if f.displayUnit == unit and f:IsShown() then
                fn(f)
            end
        end
    elseif event == "PLAYER_TARGET_CHANGED" then
        UpdateTarget()
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if unit == "player" then UpdatePlayerUnit() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        playerInCombat = UnitAffectingCombat("player") and true or false
        UpdatePlayerUnit(true)
        UpdateTarget()
        if frames.player then UpdatePlayerFade(frames.player) end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        -- InCombatLockdown() ainda é falso durante PLAYER_REGEN_DISABLED: usa o evento
        playerInCombat = (event == "PLAYER_REGEN_DISABLED")
        -- recurso do jogador aparece em combate e some em repouso fora dele;
        -- barra de vida cheia volta a ficar transparente fora de combate
        if frames.player then
            UpdatePower(frames.player)
            UpdatePlayerFade(frames.player)
        end
        -- moldura de combate do alvo
        local t = frames.target
        if t and t:IsShown() and UnitExists("target") then UpdateHealth(t) end
    end
end)

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:OnInitialize()
    self.db = Azaath.db.unitframes
    local t = self.db.target
    if t then
        t.healthFont = t.healthFont or 11
        t.nameFont = t.nameFont or 14
    end
end

function M:OnEnable()
    if Azaath.IsBlizzSkin() then return end
    for _, key in ipairs({ "player", "target" }) do
        local cfg = self.db[key]
        -- o ApplyLayout (chamado por outros módulos no login) pode já ter criado o quadro:
        -- criar de novo deixava uma cópia congelada por cima (texto duplo + barra cinza)
        if cfg and cfg.enabled and not frames[key] then
            CreateUnitFrame(key, cfg)
        end
    end
    if not next(frames) then return end

    for event in pairs(UNIT_EVENTS) do
        Azaath.SafeRegister(events, event)
    end
    Azaath.SafeRegister(events, "PLAYER_TARGET_CHANGED")
    Azaath.SafeRegister(events, "PLAYER_ENTERING_WORLD")
    Azaath.SafeRegister(events, "UNIT_ENTERED_VEHICLE")
    Azaath.SafeRegister(events, "UNIT_EXITED_VEHICLE")
    Azaath.SafeRegister(events, "PLAYER_REGEN_DISABLED")
    Azaath.SafeRegister(events, "PLAYER_REGEN_ENABLED")

    UpdatePlayerUnit(true)
    UpdateTarget()
    self:ApplyLayout()
end

function M:OnVisibilityChanged(shown)
    if shown then
        UpdatePlayerUnit(true)
        UpdateTarget()
    end
end

--------------------------------------------------------------------------------
-- Diagnóstico das barras (/barradiag [alvo]): grava em AzaathUIDB.barDiag tudo o
-- que está desenhado na barra de vida do jogador (ou do alvo) e os frames
-- visíveis sobre a parte vazia dela. Ler no SavedVariables depois do /reload.
--------------------------------------------------------------------------------
local function DiagStr(v)
    if Azaath.IsSecret and Azaath.IsSecret(v) then return "<secreto>" end
    local ok, s = pcall(tostring, v)
    return ok and s or "?"
end

local function DiagCall(obj, method, ...)
    local fn = obj and obj[method]
    if type(fn) ~= "function" then return "-" end
    local r = { pcall(fn, obj, ...) }
    if not r[1] then return "erro" end
    local out = {}
    for i = 2, #r do out[#out + 1] = DiagStr(r[i]) end
    return table.concat(out, ",")
end

local function DiagRegion(lines, reg, pad, ref)
    local t = DiagCall(reg, "GetObjectType")
    local s = pad .. t .. " layer=" .. DiagCall(reg, "GetDrawLayer") .. " shown=" .. DiagCall(reg, "IsShown")
        .. " vis=" .. DiagCall(reg, "IsVisible") .. " a=" .. DiagCall(reg, "GetAlpha")
    if t == "Texture" then
        s = s .. " tex=" .. DiagCall(reg, "GetTexture") .. " atlas=" .. DiagCall(reg, "GetAtlas")
            .. " cor=" .. DiagCall(reg, "GetVertexColor") .. " blend=" .. DiagCall(reg, "GetBlendMode")
    elseif t == "FontString" then
        s = s .. " txt=" .. DiagCall(reg, "GetText") .. " cor=" .. DiagCall(reg, "GetTextColor")
    end
    local okL, l = pcall(reg.GetLeft, reg)
    local okR, r = pcall(reg.GetRight, reg)
    local rl, rr = ref:GetLeft(), ref:GetRight()
    if okL and okR and l and r and rl and not Azaath.IsSecret(l) and not Azaath.IsSecret(r) then
        s = s .. (" x=%.0f..%.0f (barra %.0f)"):format(l - rl, r - rl, rr - rl)
    end
    lines[#lines + 1] = s
end

local function DiagFrame(lines, fr, pad, ref, depth)
    local t = DiagCall(fr, "GetObjectType")
    local s = pad .. "[" .. t .. "] " .. DiagCall(fr, "GetDebugName") .. " lvl=" .. DiagCall(fr, "GetFrameLevel")
        .. " strata=" .. DiagCall(fr, "GetFrameStrata") .. " shown=" .. DiagCall(fr, "IsShown")
        .. " vis=" .. DiagCall(fr, "IsVisible") .. " a=" .. DiagCall(fr, "GetAlpha")
    if t == "StatusBar" then
        s = s .. " val=" .. DiagCall(fr, "GetValue") .. " minmax=" .. DiagCall(fr, "GetMinMaxValues")
        local tex = fr:GetStatusBarTexture()
        if tex then
            s = s .. " fill=" .. DiagCall(tex, "GetTexture") .. " cor=" .. DiagCall(tex, "GetVertexColor")
                .. " fillA=" .. DiagCall(tex, "GetAlpha")
        end
    end
    lines[#lines + 1] = s
    for _, reg in ipairs({ fr:GetRegions() }) do DiagRegion(lines, reg, pad .. "  ", ref) end
    if depth > 0 then
        for _, ch in ipairs({ fr:GetChildren() }) do DiagFrame(lines, ch, pad .. "  ", ref, depth - 1) end
    end
end

SLASH_AZBARDIAG1 = "/barradiag"
SlashCmdList["AZBARDIAG"] = function(msg)
    local key = (msg and msg:find("alvo")) and "target" or "player"
    local f = frames[key]
    local lines = { date("%H:%M:%S") .. " " .. key .. " skin=" .. DiagStr(Azaath.db and Azaath.db.skin)
        .. " combate=" .. DiagStr(InCombatLockdown()) }
    if not (f and f.health) then
        lines[#lines + 1] = "sem quadro"
    else
        local h = f.health
        lines[#lines + 1] = "flashMode=" .. DiagStr(h.flashMode) .. " trailActive=" .. DiagStr(h.trailActive)
            .. " anim=" .. DiagStr(h.flashAG and h.flashAG:IsPlaying()) .. " hudStyled=" .. DiagStr(f.hudStyled)
        DiagFrame(lines, f, "", h, 4)
        if f.hudOverlay then DiagFrame(lines, f.hudOverlay, "OV ", h, 1) end
        -- frames visíveis sobre a parte vazia (perto da ponta direita da barra)
        local x, y = h:GetRight() - 6, (h:GetTop() + h:GetBottom()) / 2
        lines[#lines + 1] = ("-- frames em cima do ponto %.0f,%.0f:"):format(x, y)
        local fr = EnumerateFrames()
        local n = 0
        while fr and n < 80 do
            local ok, inside = pcall(function()
                if not fr:IsVisible() then return false end
                local l, r, b, t = fr:GetLeft(), fr:GetRight(), fr:GetBottom(), fr:GetTop()
                if not (l and r and b and t) then return false end
                local s = fr:GetEffectiveScale() / h:GetEffectiveScale()
                return l * s <= x and r * s >= x and b * s <= y and t * s >= y
            end)
            if ok and inside then
                n = n + 1
                lines[#lines + 1] = "  " .. DiagCall(fr, "GetDebugName") .. " " .. DiagCall(fr, "GetObjectType")
                    .. " strata=" .. DiagCall(fr, "GetFrameStrata") .. " lvl=" .. DiagCall(fr, "GetFrameLevel")
                    .. " a=" .. DiagCall(fr, "GetAlpha")
            end
            fr = EnumerateFrames(fr)
        end
    end
    if Azaath.db then Azaath.db.barDiag = lines end
    print("|cffd9b45aAzaathUI|r: diagnóstico gravado (" .. #lines .. " linhas). Dê /reload para salvar.")
end
