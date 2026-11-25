--[[----------------------------------------------------------------------------
    AzaathUI - Modules/BDOHUD.lua
    Skin "bdo": quadro do jogador no estilo Black Desert Online (canto superior
    esquerdo). Arte e medidas: tools/bdo-hud-concept/gen.js -> Media/BDO/*.tga
    e Modules/BDOLayoutData.lua (Azaath.BDO, unidades da UI).

      * losango cinza com o nível e a % de XP; a XP corre num filete dourado
        POR FORA da borda, do vértice de cima em sentido horário;
      * vida (paralelogramo "\") e recurso (paralelogramo "/"): ouro na raiva,
        azul na mana, prata na energia; ponta reta quando não estão cheias;
      * faíscas cintilando dentro do preenchimento e rastro claro no dano.

    Valores secretos (combate): vida/recurso só vão para SetValue e
    SetFormattedText; as faíscas ficam presas à ponta do preenchimento e são
    recortadas pela própria barra (sem ler o valor).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("BDOHUD")

local B -- Azaath.BDO
local hud, ring, hp, hpTrail, hpText, res, resText, levelText, pctText, playerButton
local sparkSets = {}
local flowLayers = {}
local flowClock = 0
local unit = "player"
local resTrail

local function IsBDO() return Azaath.IsBDO and Azaath.IsBDO() and Azaath.BDO ~= nil end
local function Tex(name) return Azaath.media.path .. "BDO\\" .. name end

local function Place(region, x, y, w, h, parent)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", parent or hud, "TOPLEFT", x, -y)
    if w then region:SetSize(w, h) end
end

local function Text(parent, size, font)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or Azaath.media.fontBDO or Azaath.media.font, size, "")
    fs:SetTextColor(0.95, 0.94, 0.93)
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 1)
    return fs
end

--------------------------------------------------------------------------------
-- Filete de XP: 4 quadrantes de XPRing.tga, cada um recortado a partir do seu
-- vértice (cima -> direita -> baixo -> esquerda)
--------------------------------------------------------------------------------
local function BuildRing()
    ring = {}
    for k = 1, 4 do
        local t = hud:CreateTexture(nil, "ARTWORK", nil, 2)
        t:SetTexture(Tex("XPRing"))
        t:Hide()
        ring[k] = t
    end
end

local function SetRing(frac)
    local S, e = B.diamond.size, B.ringEdge
    local span = 0.5 - e
    for k = 1, 4 do
        local t = ring[k]
        local f = math.max(0, math.min(1, frac * 4 - (k - 1)))
        if f <= 0 then
            t:Hide()
        else
            local g = (f >= 1) and 0.5 or f * span
            local u0, u1, v0, v1
            if k == 1 then u0, u1, v0, v1 = 0.5, 0.5 + g, 0, 0.5
            elseif k == 2 then u0, u1, v0, v1 = 0.5, 1, 0.5, 0.5 + g
            elseif k == 3 then u0, u1, v0, v1 = 0.5 - g, 0.5, 0.5, 1
            else u0, u1, v0, v1 = 0, 0.5, 0.5 - g, 0.5 end
            t:SetTexCoord(u0, u1, v0, v1)
            Place(t, B.diamond.x + u0 * S, B.diamond.y + v0 * S, (u1 - u0) * S, (v1 - v0) * S)
            t:Show()
        end
    end
end

--------------------------------------------------------------------------------
-- Faíscas: presas à ponta do preenchimento (RIGHT da textura da barra) com
-- deslocamento para a esquerda; o que passa do início da barra é recortado
--------------------------------------------------------------------------------
local function NewSparkSet(bar, box, count, r, g, b)
    local clip = CreateFrame("Frame", nil, bar)
    clip:SetAllPoints(bar)
    clip:SetFrameLevel(bar:GetFrameLevel() + 2) -- acima da correnteza
    local clips = clip.SetClipsChildren and pcall(clip.SetClipsChildren, clip, true)
    local set = { bar = bar, box = box, clip = clip, clips = clips, list = {} }
    local fill = bar:GetStatusBarTexture()
    for i = 1, count do
        local s = clip:CreateTexture(nil, "OVERLAY")
        s:SetTexture(Tex("Spark"))
        s:SetBlendMode("ADD")
        s:SetVertexColor(r, g, b)
        s:SetAlpha(0)
        s.fill = fill
        s.t, s.life = math.random() * 1.2, 0 -- começa em pontos diferentes do ciclo
        set.list[i] = s
    end
    sparkSets[#sparkSets + 1] = set
    return set
end

-- fração do preenchimento quando o valor pode ser lido (fora de combate);
-- em combate (valor secreto) a barra inteira é sorteada e o recorte resolve
local function FillFraction(bar)
    local v = bar:GetValue()
    local lo, hi = bar:GetMinMaxValues()
    if Azaath.AnySecret and Azaath.AnySecret(v, lo, hi) then return 1 end
    if not hi or hi <= 0 then return 0 end
    return math.max(0, math.min(1, v / hi))
end

local function Respawn(set, s)
    local box = set.box
    local frac = set.clips and 1 or FillFraction(set.bar)
    s.life = 0.55 + math.random() * 0.75
    s.t = 0
    s.peak = 0.55 + math.random() * 0.45
    s.size = 4 + math.random() * 6
    s.vx = 3 + math.random() * 9
    local drift = s.vx * s.life -- a faísca anda para a direita sem passar da ponta
    s.d = drift + math.random() * math.max(0, box.w * frac - drift)
    s.dy = (math.random() - 0.5) * box.h * 0.55
    s:SetSize(s.size, s.size)
end

local function TickSparks(elapsed)
    for _, set in ipairs(sparkSets) do
        if set.bar:IsVisible() then
            for _, s in ipairs(set.list) do
                s.t = s.t + elapsed
                if s.t >= s.life then Respawn(set, s) end
                local p = s.t / s.life
                local a = math.sin(p * math.pi)
                s:SetAlpha(a * a * (s.peak or 0))
                s:ClearAllPoints()
                s:SetPoint("CENTER", s.fill, "RIGHT", -(s.d or 0) + (s.vx or 0) * s.t, s.dy or 0)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Correnteza do líquido: 2 camadas de Flow.tga (ADD) rolando em sentidos
-- opostos, com a máscara do formato da barra e cortadas na ponta do
-- preenchimento. Sem máscara/recorte no cliente, a barra fica só com a arte.
--------------------------------------------------------------------------------
local function AddFlow(bar, box, maskName, tint)
    if not (bar.CreateMaskTexture and bar.SetClipsChildren) then return nil end
    local clip = CreateFrame("Frame", nil, bar)
    clip:SetPoint("TOPLEFT", bar, "TOPLEFT")
    clip:SetPoint("BOTTOMRIGHT", bar:GetStatusBarTexture(), "BOTTOMRIGHT")
    clip:SetFrameLevel(bar:GetFrameLevel() + 1)
    if not pcall(clip.SetClipsChildren, clip, true) then clip:Hide(); return nil end
    local mask = clip:CreateMaskTexture()
    mask:SetTexture(Tex(maskName), "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    mask:SetAllPoints(bar)
    local set = { clip = clip, layers = {} }
    for i, f in ipairs(B.flow) do
        local t = clip:CreateTexture(nil, "ARTWORK", nil, i)
        t:SetTexture(Tex("Flow"), "REPEAT", "REPEAT")
        t:SetAllPoints(bar)
        t:SetBlendMode("ADD")
        t:AddMaskTexture(mask)
        t:SetVertexColor(tint[1], tint[2], tint[3])
        t:SetAlpha(f.alpha)
        t.cfg, t.span = f, box.w / f.tile
        set.layers[i] = t
        flowLayers[#flowLayers + 1] = t
    end
    return set
end

local function TickFlow(elapsed)
    flowClock = flowClock + elapsed
    for _, t in ipairs(flowLayers) do
        local f = t.cfg
        local u = (flowClock * f.speed) % 1
        local v = 0.08 * math.sin(flowClock * 0.6 + f.tile) -- leve balanço vertical
        t:SetTexCoord(u, u + t.span, v, v + f.vScale)
    end
end

--------------------------------------------------------------------------------
-- Construção
--------------------------------------------------------------------------------
local function NewBar(box, texName, level, parent)
    parent = parent or hud
    local b = CreateFrame("StatusBar", nil, parent)
    Place(b, box.x, box.y, box.w, box.h, parent)
    b:SetStatusBarTexture(Tex(texName))
    b:SetMinMaxValues(0, 1)
    b:SetValue(1)
    b:SetFrameLevel(parent:GetFrameLevel() + (level or 2))
    return b
end

local function Build()
    local d = B.diamond
    local diamond = hud:CreateTexture(nil, "ARTWORK", nil, 1)
    diamond:SetTexture(Tex("Diamond"))
    Place(diamond, d.x, d.y, d.size, d.size)
    BuildRing()

    -- Vida
    local hpBg = hud:CreateTexture(nil, "BACKGROUND", nil, 1)
    hpBg:SetTexture(Tex("HPBg"))
    Place(hpBg, B.hp.x, B.hp.y, B.hp.w, B.hp.h)
    hpTrail = NewBar(B.hp, "HPFill", 2)
    hpTrail:GetStatusBarTexture():SetVertexColor(1, 0.92, 0.85)
    hpTrail:GetStatusBarTexture():SetBlendMode("ADD")
    hpTrail:SetAlpha(0)
    hp = NewBar(B.hp, "HPFill", 3)
    AddFlow(hp, B.hp, "HPMask", { 0.95, 0.3, 0.18 })
    NewSparkSet(hp, B.hp, 16, 1, 0.72, 0.55)

    -- Recurso
    local resBg = hud:CreateTexture(nil, "BACKGROUND", nil, 1)
    resBg:SetTexture(Tex("ResBg"))
    Place(resBg, B.res.x, B.res.y, B.res.w, B.res.h)
    resTrail = NewBar(B.res, "ResSilver", 2)
    resTrail:GetStatusBarTexture():SetVertexColor(1, 1, 1)
    resTrail:SetAlpha(0)
    res = NewBar(B.res, "ResGold", 3)
    res.flow = AddFlow(res, B.res, "ResMask", { 0.95, 0.72, 0.2 })
    res.sparks = NewSparkSet(res, B.res, 12, 1, 0.95, 0.80)

    -- Textos (acima de tudo)
    local top = CreateFrame("Frame", nil, hud)
    top:SetAllPoints(hud)
    top:SetFrameLevel(hud:GetFrameLevel() + 8)
    local F = B.fonts
    levelText = Text(top, F.level, Azaath.media.fontBDOB)
    levelText:SetPoint("CENTER", hud, "TOPLEFT", B.levelText[1], -B.levelText[2])
    pctText = Text(top, F.pct)
    pctText:SetPoint("CENTER", hud, "TOPLEFT", B.pctText[1], -B.pctText[2])
    hpText = Text(top, F.bar)
    hpText:SetPoint("CENTER", hud, "TOPLEFT", B.hpText[1], -B.hpText[2])
    resText = Text(top, F.res)
    resText:SetPoint("CENTER", hud, "TOPLEFT", B.resText[1], -B.resText[2])

    hud:SetScript("OnUpdate", function(_, elapsed)
        TickSparks(elapsed)
        TickFlow(elapsed)
    end)
end

-- Clique no losango: seleciona a si mesmo / menu do jogador
local function BuildPlayerButton()
    local b = CreateFrame("Button", "AzaathUIBDOPlayer", hud, "SecureUnitButtonTemplate")
    local s = B.diamond.size * 0.5
    b:SetSize(s, s)
    b:SetPoint("CENTER", hud, "TOPLEFT", B.diamond.x + B.diamond.size / 2, -(B.diamond.y + B.diamond.size / 2))
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

--------------------------------------------------------------------------------
-- Atualização
--------------------------------------------------------------------------------
local trail = { active = false, hold = 0, last = nil, has = false }
local trailDriver = CreateFrame("Frame")
trailDriver:Hide()
trailDriver:SetScript("OnUpdate", function(self, elapsed)
    if trail.hold > 0 then
        trail.hold = trail.hold - elapsed
        return
    end
    local a = hpTrail:GetAlpha() - elapsed / 0.5
    if a <= 0 then
        hpTrail:SetAlpha(0)
        hpTrail:SetValue(hp:GetValue())
        trail.active = false
        self:Hide()
    else
        hpTrail:SetAlpha(a)
    end
end)

local function PairText(fs, cur, max)
    if Azaath.AnySecret(cur, max) then
        if not pcall(fs.SetFormattedText, fs, "%s / %s", cur, max) then fs:SetText("") end
    else
        fs:SetFormattedText("%d / %d", cur or 0, max or 0)
    end
end

local function UpdateHealth(instant)
    if not hp then return end
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    hp:SetMinMaxValues(0, max)
    hp:SetValue(cur)
    hpTrail:SetMinMaxValues(0, max)
    if instant or not trail.has then
        hpTrail:SetValue(cur)
        hpTrail:SetAlpha(0)
    elseif not trail.active then
        -- o rastro fica no valor anterior, atrás da vida: no dano sobra um pedaço claro
        hpTrail:SetValue(trail.last)
        hpTrail:SetAlpha(0.9)
        trail.active, trail.hold = true, 0.25
        trailDriver:Show()
    end
    trail.last, trail.has = cur, true

    if UnitIsDeadOrGhost(unit) then
        hpText:SetText(UnitIsGhost(unit) and "Fantasma" or "Morto")
    else
        PairText(hpText, cur, max)
    end
end

local POWER_TEX = { MANA = "ResBlue", RUNIC_POWER = "ResBlue", ENERGY = "ResSilver" }
local POWER_SPARK = { ResGold = { 1, 0.95, 0.80 }, ResBlue = { 0.75, 0.88, 1 }, ResSilver = { 1, 1, 1 } }
local POWER_FLOW = { ResGold = { 0.95, 0.72, 0.2 }, ResBlue = { 0.45, 0.7, 1 }, ResSilver = { 0.9, 0.9, 0.85 } }
local currentResTex

local function UpdatePowerType()
    if not res then return end
    local ok, _, token = pcall(UnitPowerType, unit)
    if not ok or Azaath.IsSecret(token) then token = nil end
    local name = POWER_TEX[token or ""] or "ResGold"
    if name ~= currentResTex then
        currentResTex = name
        res:SetStatusBarTexture(Tex(name))
        local c = POWER_SPARK[name]
        for _, s in ipairs(res.sparks.list) do
            s:SetVertexColor(c[1], c[2], c[3])
            s.fill = res:GetStatusBarTexture()
        end
        if res.flow then
            local ft = POWER_FLOW[name]
            res.flow.clip:SetPoint("BOTTOMRIGHT", res:GetStatusBarTexture(), "BOTTOMRIGHT")
            for _, t in ipairs(res.flow.layers) do t:SetVertexColor(ft[1], ft[2], ft[3]) end
        end
    end
end

-- Rastro do recurso (igual ao do Black Desert): ao gastar, o preenchimento cai na
-- hora e um trecho cinza fica onde estava, segura ~0,3 s e encolhe devagar até o
-- valor atual; ao ganhar, o cinza some e o preenchimento sobe de uma vez. Com
-- valores secretos (sem poder calcular) o cinza só fica parado e some em fade.
local rt = { has = false, last = nil, hold = 0, active = false, fade = false, target = 0, events = 0, ghosts = 0, secret = 0 }
_G.AZAATH_RT = rt -- diagnóstico: /dump AZAATH_RT
local rtDriver = CreateFrame("Frame")
rtDriver:Hide()
local function RTStop()
    rt.active = false
    if resTrail then resTrail:SetAlpha(0) end
    rtDriver:Hide()
end
rtDriver:SetScript("OnUpdate", function(self, elapsed)
    if not resTrail then return self:Hide() end
    if rt.hold > 0 then
        rt.hold = rt.hold - elapsed
        return
    end
    if rt.fade then
        local a = resTrail:GetAlpha() - elapsed / 0.45
        if a <= 0 then RTStop() else resTrail:SetAlpha(a) end
        return
    end
    local _, hi = resTrail:GetMinMaxValues()
    local v = resTrail:GetValue() - (hi or 1) * 0.4 * elapsed
    if v <= rt.target then
        RTStop()
    else
        resTrail:SetValue(v)
    end
end)

local function UpdatePower(instant)
    if not res then return end
    local cur, max = UnitPower(unit), UnitPowerMax(unit)
    res:SetMinMaxValues(0, max)
    res:SetValue(cur)
    PairText(resText, cur, max)
    rt.events = rt.events + 1
    if not resTrail then return end
    resTrail:SetMinMaxValues(0, max)
    if instant == true or not rt.has then
        RTStop()
        resTrail:SetValue(cur)
    elseif Azaath.AnySecret(cur, max, rt.last) then
        -- valor secreto: o cinza fica no valor anterior (sob o preenchimento se subiu)
        -- os eventos repetem sem mudar o valor: enquanto o cinza está ativo ele não é reposto
        rt.secret = rt.secret + 1
        if not rt.active then
            resTrail:SetValue(rt.last)
            resTrail:SetAlpha(1)
            rt.active, rt.fade, rt.hold = true, true, 0.3
            rtDriver:Show()
        end
    elseif cur < rt.last then
        local from = rt.last
        if rt.active and not rt.fade then from = math.max(from, resTrail:GetValue()) end
        resTrail:SetValue(from)
        resTrail:SetAlpha(1)
        rt.ghosts = rt.ghosts + 1
        rt.active, rt.fade, rt.hold, rt.target = true, false, 0.3, cur
        rtDriver:Show()
    else
        RTStop() -- ganhou: o cinza some na hora
        resTrail:SetValue(cur)
    end
    rt.last = cur
    rt.has = true
end

local function UpdateXP()
    if not hud then return end
    local level = UnitLevel("player")
    levelText:SetText(level or "")
    local maxLevel = (GetMaxLevelForPlayerExpansion and GetMaxLevelForPlayerExpansion())
        or (GetMaxPlayerLevel and GetMaxPlayerLevel()) or MAX_PLAYER_LEVEL or 80
    local atMax = (IsLevelAtEffectiveMaxLevel and IsLevelAtEffectiveMaxLevel(level))
        or (not Azaath.IsSecret(level) and level and level >= maxLevel)
    if atMax then
        SetRing(1)
        pctText:SetText("")
        return
    end
    local cur, max = UnitXP("player") or 0, UnitXPMax("player") or 1
    if Azaath.AnySecret(cur, max) then
        pctText:SetText("")
        return
    end
    if max <= 0 then max = 1 end
    local frac = cur / max
    SetRing(frac)
    pctText:SetFormattedText("%.3f%%", frac * 100)
end

local function UpdateUnit()
    unit = (UnitHasVehicleUI and UnitHasVehicleUI("player")) and "vehicle" or "player"
    if playerButton and not InCombatLockdown() then playerButton:SetAttribute("unit", unit) end
    UpdatePowerType()
    UpdateHealth(true)
    UpdatePower(true)
end

--------------------------------------------------------------------------------
-- Quadro do alvo (inimigo ou aliado): a mesma arte do quadro do jogador em escala
-- menor. Losango com o nível (caveira nos "??"), vida em paralelogramo "\" com
-- correnteza e faíscas, nome acima da vida e recurso em "/" embaixo. A cor da vida
-- segue a relação com o jogador: vermelho hostil, verde amigo, amarelo neutro.
-- Aparece sozinho (RegisterUnitWatch) quando há alvo. Vida/recurso em combate podem
-- ser secretos: só vão para SetValue / SetFormattedText, nunca são comparados.
--------------------------------------------------------------------------------
local TS = 0.78
local tHud, tDiamond, tHp, tTrail, tRes, tResBg, tHpText, tResText, tLevel, tPct, tName, tSkull, tRare
local tReaction, tResTex
local tTrailSt = { active = false, hold = 0, last = nil, has = false }
local T_CREAM = { 0.95, 0.92, 0.82 }
local T_TINT = {
    friendly = { 0.36, 0.86, 0.44 },
    neutral  = { 0.96, 0.80, 0.30 },
    tapped   = { 0.62, 0.62, 0.62 },
}
local CLASS_TINT = {
    elite = { 1, 0.85, 0.55 }, rareelite = { 1, 0.85, 0.55 }, worldboss = { 1, 0.78, 0.40 },
    rare = { 0.80, 0.90, 1 },
}
-- Raro e raro elite = prata; elite e chefe de mundo = ouro (lâminas do alvo e dragão das placas)
local RARE_METAL = { rare = "Silver", rareelite = "Silver", elite = "Gold", worldboss = "Gold" }
-- dragão das placas da própria Blizzard (Interface/TargetingFrame/Nameplates, 256x256)
local DRAGON_COORD = {
    Gold = { 4 / 256, 78 / 256, 4 / 256, 78 / 256 },
    Silver = { 86 / 256, 160 / 256, 4 / 256, 78 / 256 },
}

local function UnitMetal(unit)
    local ok, class = pcall(UnitClassification, unit)
    if not ok or Azaath.IsSecret(class) then return nil end
    return RARE_METAL[class or ""]
end

-- Neutro (amarelo) tem líquido próprio: tingir o vermelho dessaturado deixava
-- um amarelo escuro e opaco. Os demais tipos seguem tingindo o vermelho.
local KIND_FILL = { neutral = "HPFillNeutral" }
local function PaintFill(fill, kind, tint)
    local own = KIND_FILL[kind]
    fill:SetTexture(Tex(own or "HPFill"))
    fill:SetDesaturated(tint ~= nil and not own)
    if tint and not own then fill:SetVertexColor(tint[1], tint[2], tint[3]) else fill:SetVertexColor(1, 1, 1) end
end

local function Scaled(box) return { x = box.x * TS, y = box.y * TS, w = box.w * TS, h = box.h * TS } end

local tTrailDriver = CreateFrame("Frame")
tTrailDriver:Hide()
tTrailDriver:SetScript("OnUpdate", function(self, elapsed)
    local st = tTrailSt
    if st.hold > 0 then
        st.hold = st.hold - elapsed
        return
    end
    local a = tTrail:GetAlpha() - elapsed / 0.5
    if a <= 0 then
        tTrail:SetAlpha(0)
        tTrail:SetValue(tHp:GetValue())
        st.active = false
        self:Hide()
    else
        tTrail:SetAlpha(a)
    end
end)

local function TargetReaction()
    local ok, tapped = pcall(function() return UnitIsTapDenied and UnitIsTapDenied("target") end)
    if ok and tapped and not UnitIsPlayer("target") then return "tapped" end
    if UnitIsFriend("player", "target") then return "friendly" end
    local r = UnitReaction("target", "player")
    if r and r == 4 then return "neutral" end
    return "hostile"
end

local function SetTargetReaction(kind)
    if kind == tReaction then return end
    tReaction = kind
    local tint = T_TINT[kind]
    PaintFill(tHp:GetStatusBarTexture(), kind, tint)
    local f = tint or { 0.95, 0.3, 0.18 }
    if tHp.flow then
        for _, t in ipairs(tHp.flow.layers) do t:SetVertexColor(f[1], f[2], f[3]) end
    end
    local sp = tint and { 0.5 + tint[1] * 0.5, 0.5 + tint[2] * 0.5, 0.5 + tint[3] * 0.5 } or { 1, 0.72, 0.55 }
    for _, s in ipairs(tHp.sparks.list) do s:SetVertexColor(sp[1], sp[2], sp[3]) end
end

local function TargetHealth(instant)
    if not tHp then return end
    local cur, max = UnitHealth("target"), UnitHealthMax("target")
    tHp:SetMinMaxValues(0, max)
    tHp:SetValue(cur)
    tTrail:SetMinMaxValues(0, max)
    local st = tTrailSt
    if instant or not st.has then
        tTrail:SetValue(cur)
        tTrail:SetAlpha(0)
        st.active = false
    elseif not st.active then
        tTrail:SetValue(st.last)
        tTrail:SetAlpha(0.9)
        st.active, st.hold = true, 0.25
        tTrailDriver:Show()
    end
    st.last, st.has = cur, true
    if UnitIsDeadOrGhost("target") then
        tHpText:SetText(UnitIsGhost("target") and "Fantasma" or "Morto")
        tPct:SetText("")
    else
        PairText(tHpText, cur, max)
        if not Azaath.AnySecret(cur, max) and max and max > 0 then
            tPct:SetFormattedText("%d%%", math.floor(cur * 100 / max + 0.5))
        else
            tPct:SetText("")
        end
    end
end

local function TargetPowerType()
    local ok, _, token = pcall(UnitPowerType, "target")
    if not ok or Azaath.IsSecret(token) then token = nil end
    local name = POWER_TEX[token or ""] or "ResGold"
    if name ~= tResTex then
        tResTex = name
        tRes:SetStatusBarTexture(Tex(name))
        local c = POWER_SPARK[name]
        for _, s in ipairs(tRes.sparks.list) do
            s:SetVertexColor(c[1], c[2], c[3])
            s.fill = tRes:GetStatusBarTexture()
        end
        if tRes.flow then
            local ft = POWER_FLOW[name]
            tRes.flow.clip:SetPoint("BOTTOMRIGHT", tRes:GetStatusBarTexture(), "BOTTOMRIGHT")
            for _, t in ipairs(tRes.flow.layers) do t:SetVertexColor(ft[1], ft[2], ft[3]) end
        end
    end
end

local function TargetPower()
    if not tRes then return end
    local max = UnitPowerMax("target")
    local has = true
    if not Azaath.IsSecret(max) then has = (max or 0) > 0 end
    tRes:SetShown(has)
    tResBg:SetShown(has)
    tResText:SetShown(has)
    if not has then return end
    TargetPowerType()
    local cur = UnitPower("target")
    tRes:SetMinMaxValues(0, max)
    tRes:SetValue(cur)
    PairText(tResText, cur, max)
end

local function TargetInfo()
    if not tHud or not UnitExists("target") then return end
    SetTargetReaction(TargetReaction())
    local name = UnitName("target")
    pcall(tName.SetText, tName, name or "")
    local col = T_CREAM
    if UnitIsPlayer("target") then
        local _, class = UnitClass("target")
        local c = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
        if c then col = { c.r, c.g, c.b } end
    end
    tName:SetTextColor(col[1], col[2], col[3])
    local level = UnitLevel("target")
    if level and Azaath.IsSecret(level) then
        pcall(tLevel.SetFormattedText, tLevel, "%d", level)
        tSkull:Hide()
    elseif not level or level < 0 then
        tLevel:SetText("")
        tSkull:Show()
    else
        tLevel:SetText(level)
        tSkull:Hide()
    end
    local tint = CLASS_TINT[UnitClassification("target") or ""]
    if tint then tDiamond:SetVertexColor(tint[1], tint[2], tint[3]) else tDiamond:SetVertexColor(1, 1, 1) end
    local metal = UnitMetal("target")
    if metal then
        tRare:SetTexture(Tex("Rare" .. metal))
        tRare:Show()
    else
        tRare:Hide()
    end
end

-- Conjuração do alvo (inimigo ou aliado): cronômetro nativo do jogo (UnitCastingDuration /
-- SetTimerDuration), o mesmo das placas, que funciona mesmo com tempos secretos.
local tCast, tCastBar, tCastName, tCastTex, tCastFb

local function TargetCastHide()
    if not tCast then return end
    tCastFb = nil
    if tCastBar.SetTimerDuration then pcall(tCastBar.SetTimerDuration, tCastBar, nil) end
    tCast:Hide()
end

local function TargetCastStart()
    if not tCast or not UnitExists("target") then
        TargetCastHide()
        return
    end
    local dur, channel
    if UnitCastingDuration then
        local ok, d = pcall(UnitCastingDuration, "target")
        if ok and d then dur = d end
    end
    if not dur and UnitChannelDuration then
        local ok, d = pcall(UnitChannelDuration, "target")
        if ok and d then dur, channel = d, true end
    end
    local name, text, texture, startMS, endMS, castID, notInt
    if channel then
        name, text, texture, startMS, endMS, castID, notInt = Azaath.API.ChannelInfo("target")
    else
        name, text, texture, startMS, endMS, castID, notInt = Azaath.API.CastingInfo("target")
        if not dur and not name then
            name, text, texture, startMS, endMS, castID, notInt = Azaath.API.ChannelInfo("target")
            channel = name and true or false
        end
    end
    if not dur and not name then
        TargetCastHide()
        return
    end
    local shielded = false
    if notInt ~= nil and not Azaath.IsSecret(notInt) then shielded = notInt and true or false end
    local want = shielded and "ResSilver" or "ResGold"
    if want ~= tCastTex then
        tCastTex = want
        tCastBar:SetStatusBarTexture(Tex(want))
    end
    local used = false
    if dur and tCastBar.SetTimerDuration then
        local Interp = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
        local TD = Enum and Enum.StatusBarTimerDirection
        local dirv = channel and (TD and TD.RemainingTime or 1) or (TD and TD.ElapsedTime or 0)
        used = pcall(tCastBar.SetTimerDuration, tCastBar, dur, Interp, dirv)
    end
    tCastFb = nil
    if not used then
        if startMS and endMS and not Azaath.AnySecret(startMS, endMS) then
            tCastFb = { s = startMS / 1000, e = endMS / 1000, ch = channel }
            tCastBar:SetMinMaxValues(0, math.max(0.001, tCastFb.e - tCastFb.s))
        else
            tCastBar:SetMinMaxValues(0, 1)
            tCastBar:SetValue(0.5)
        end
    end
    if name then
        pcall(tCastName.SetText, tCastName, name)
    elseif text then
        pcall(tCastName.SetText, tCastName, text)
    else
        tCastName:SetText("")
    end
    tCast:Show()
end

local function TargetPreview()
    if not tHud then return end
    SetTargetReaction("hostile")
    tName:SetText("Alvo")
    tName:SetTextColor(T_CREAM[1], T_CREAM[2], T_CREAM[3])
    tLevel:SetText("80")
    tSkull:Hide()
    tRare:Hide()
    tDiamond:SetVertexColor(1, 1, 1)
    tHp:SetMinMaxValues(0, 100)
    tHp:SetValue(100)
    tTrail:SetMinMaxValues(0, 100)
    tTrail:SetValue(100)
    tTrail:SetAlpha(0)
    tHpText:SetText("100 / 100")
    tPct:SetText("100%")
    tRes:Hide()
    tResBg:Hide()
    tResText:Hide()
    TargetCastHide()
end

local function TargetRefresh(instant)
    if not tHud or not UnitExists("target") then return end
    TargetInfo()
    TargetHealth(instant)
    TargetPower()
    TargetCastStart()
end

local function BuildTarget()
    if tHud then return end
    B = Azaath.BDO
    local W, H = B.hud.w * TS, B.hud.h * TS
    -- barX/barW: onde ficam as barras (à direita do losango); gap: espaço entre o fim das barras e a base do quadro
    Azaath.BDOTargetBox = { w = W, h = H, barX = B.hp.x * TS, barW = B.hp.w * TS, gap = H - (B.res.y + B.res.h) * TS }
    tHud = CreateFrame("Button", "AzaathUIBDOTarget", Azaath.root, "SecureUnitButtonTemplate")
    tHud:SetSize(W, H)
    tHud:SetFrameStrata("LOW")
    tHud:SetFrameLevel(2)
    tHud:RegisterForClicks("AnyUp")
    tHud:SetAttribute("unit", "target")
    tHud:SetAttribute("*type1", "target")
    if Azaath.IS_MODERN then tHud:SetAttribute("*type2", "togglemenu") end
    tHud:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetUnit("target")
    end)
    tHud:SetScript("OnLeave", function() GameTooltip:Hide() end)
    tHud:SetScript("OnShow", function() TargetRefresh(true) end)
    tHud:Hide()

    local d = B.diamond
    tDiamond = tHud:CreateTexture(nil, "ARTWORK", nil, 1)
    tDiamond:SetTexture(Tex("Diamond"))
    Place(tDiamond, 0, 0, d.size * TS, d.size * TS, tHud)
    -- raro/elite: lâminas cravadas no losango (textura 1,5x a caixa do losango, centrada nele)
    tRare = tHud:CreateTexture(nil, "ARTWORK", nil, 2)
    tRare:SetSize(d.size * TS * 1.5, d.size * TS * 1.5)
    tRare:SetPoint("CENTER", tHud, "TOPLEFT", d.size * TS / 2, -d.size * TS / 2)
    tRare:Hide()

    -- Vida
    local hb = Scaled(B.hp)
    local hpBg = tHud:CreateTexture(nil, "BACKGROUND", nil, 1)
    hpBg:SetTexture(Tex("HPBg"))
    Place(hpBg, hb.x, hb.y, hb.w, hb.h, tHud)
    tTrail = NewBar(hb, "HPFill", 2, tHud)
    tTrail:GetStatusBarTexture():SetVertexColor(1, 0.92, 0.85)
    tTrail:GetStatusBarTexture():SetBlendMode("ADD")
    tTrail:SetAlpha(0)
    tHp = NewBar(hb, "HPFill", 3, tHud)
    tHp.flow = AddFlow(tHp, hb, "HPMask", { 0.95, 0.3, 0.18 })
    tHp.sparks = NewSparkSet(tHp, hb, 12, 1, 0.72, 0.55)

    -- Recurso (só aparece quando o alvo tem)
    local rb = Scaled(B.res)
    tResBg = tHud:CreateTexture(nil, "BACKGROUND", nil, 1)
    tResBg:SetTexture(Tex("ResBg"))
    Place(tResBg, rb.x, rb.y, rb.w, rb.h, tHud)
    tRes = NewBar(rb, "ResGold", 3, tHud)
    tRes.flow = AddFlow(tRes, rb, "ResMask", { 0.95, 0.72, 0.2 })
    tRes.sparks = NewSparkSet(tRes, rb, 8, 1, 0.95, 0.80)

    -- Textos (acima de tudo)
    local top = CreateFrame("Frame", nil, tHud)
    top:SetAllPoints(tHud)
    top:SetFrameLevel(tHud:GetFrameLevel() + 8)
    local F = B.fonts
    tLevel = Text(top, F.level * TS, Azaath.media.fontBDOB)
    tLevel:SetPoint("CENTER", tHud, "TOPLEFT", B.diamond.size * TS / 2, -B.diamond.size * TS / 2) -- meio do losango
    tSkull = top:CreateTexture(nil, "OVERLAY")
    tSkull:SetTexture("Interface/TargetingFrame/UI-TargetingFrame-Skull")
    tSkull:SetSize(24, 24)
    tSkull:SetPoint("CENTER", tHud, "TOPLEFT", B.diamond.size * TS / 2, -B.diamond.size * TS / 2)
    tSkull:Hide()
    tPct = Text(top, F.pct * TS * 0.85)
    tPct:SetPoint("CENTER", tHud, "TOPLEFT", B.diamond.size * TS / 2, -B.diamond.size * TS * 0.75) -- logo abaixo do nível
    tHpText = Text(top, F.bar * TS)
    tHpText:SetPoint("CENTER", tHud, "TOPLEFT", B.hpText[1] * TS, -B.hpText[2] * TS)
    tResText = Text(top, F.res * TS)
    tResText:SetPoint("CENTER", tHud, "TOPLEFT", B.resText[1] * TS, -B.resText[2] * TS)
    tName = Text(top, 16)
    tName:SetPoint("BOTTOMLEFT", tHud, "TOPLEFT", hb.x + 14, -hb.y + 2)
    tName:SetWidth(hb.w - 50)
    tName:SetJustifyH("LEFT")
    tName:SetWordWrap(false)

    -- Conjuração: barra fina abaixo do recurso, no mesmo desenho
    local cb = { x = rb.x + 4, y = rb.y + rb.h + 6, w = rb.w * 0.82, h = rb.h * 0.82 }
    tCast = CreateFrame("Frame", nil, tHud)
    tCast:SetAllPoints(tHud)
    tCast:SetFrameLevel(tHud:GetFrameLevel() + 1)
    tCast:Hide()
    local cbg = tCast:CreateTexture(nil, "BACKGROUND", nil, 1)
    cbg:SetTexture(Tex("ResBg"))
    Place(cbg, cb.x, cb.y, cb.w, cb.h, tHud)
    tCastBar = NewBar(cb, "ResGold", 3, tCast)
    tCastTex = "ResGold"
    local ctop = CreateFrame("Frame", nil, tCast)
    ctop:SetAllPoints(tHud)
    ctop:SetFrameLevel(tHud:GetFrameLevel() + 9)
    tCastName = Text(ctop, 10.5)
    tCastName:SetPoint("CENTER", tHud, "TOPLEFT", cb.x + cb.w / 2, -(cb.y + cb.h / 2))
    tCastName:SetWidth(cb.w - 30)
    tCastName:SetWordWrap(false)
    tCast:SetScript("OnUpdate", function(self, elapsed)
        local fb = tCastFb
        if fb then
            local now = GetTime()
            tCastBar:SetValue(math.max(0, fb.ch and (fb.e - now) or (now - fb.s)))
        end
        self.poll = (self.poll or 0) + elapsed
        if self.poll >= 0.2 then
            self.poll = 0
            local still = false
            if UnitCastingDuration then
                local ok, d = pcall(UnitCastingDuration, "target")
                if ok and d then still = true end
            end
            if not still and UnitChannelDuration then
                local ok, d = pcall(UnitChannelDuration, "target")
                if ok and d then still = true end
            end
            if not still and (Azaath.API.CastingInfo("target") or Azaath.API.ChannelInfo("target")) then still = true end
            if not still then TargetCastHide() end
        end
    end)

    local tEvents = CreateFrame("Frame")
    tEvents:SetScript("OnEvent", function(_, event, arg1)
        if event == "PLAYER_TARGET_CHANGED" then
            if M.editing and not UnitExists("target") then
                TargetPreview()
            else
                TargetRefresh(true)
            end
        elseif arg1 ~= "target" then
            return
        elseif event:find("UNIT_SPELLCAST", 1, true) then
            TargetCastStart()
        elseif event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
            TargetHealth(event == "UNIT_MAXHEALTH")
        elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" then
            TargetPower()
        elseif event == "UNIT_DISPLAYPOWER" then
            tResTex = nil
            TargetPower()
        else -- nome, nível, facção, classificação, marcações
            TargetInfo()
            TargetHealth(true)
        end
    end)
    for _, e in ipairs({
        "PLAYER_TARGET_CHANGED", "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT",
        "UNIT_MAXPOWER", "UNIT_DISPLAYPOWER", "UNIT_LEVEL", "UNIT_NAME_UPDATE", "UNIT_FACTION",
        "UNIT_CLASSIFICATION_CHANGED", "UNIT_DYNAMIC_FLAGS",
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_STOP", "UNIT_SPELLCAST_FAILED", "UNIT_SPELLCAST_INTERRUPTED",
        "UNIT_SPELLCAST_DELAYED", "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP",
        "UNIT_SPELLCAST_CHANNEL_UPDATE", "UNIT_SPELLCAST_INTERRUPTIBLE", "UNIT_SPELLCAST_NOT_INTERRUPTIBLE",
    }) do
        Azaath.SafeRegister(tEvents, e)
    end
end

-- Posição: usa diretamente as coordenadas de unitframes.target (e sincroniza com o quadro de alvo),
-- assim o Modo de Edição, os buffs/debuffs e a barra de conjuração seguem sempre a mesma posição.
function Azaath.ApplyBDOTarget()
    Azaath:RunOutOfCombat(function()
        if not tHud then return end
        -- skin Zerker com "Ativar quadro do alvo" ligado (desligado: volta o da Blizzard)
        if IsBDO() and Azaath.TargetFrameOn() then
            -- o quadro de alvo do Azaath fica só como âncora invisível (senão aparece atrás deste)
            if _G.AzaathUITarget then _G.AzaathUITarget:SetAlpha(0) end
            if _G.AzaathUITargetClick then _G.AzaathUITargetClick:EnableMouse(false) end
            local tCfg = Azaath.db and Azaath.db.unitframes and Azaath.db.unitframes.target
            local sc = (tCfg and tCfg.scale and tCfg.scale > 0) and tCfg.scale or 1
            local ox = (tCfg and tCfg.offsetX) or 0
            local oy = (tCfg and tCfg.offsetY) or -78
            tHud:SetScale(sc)
            tHud:ClearAllPoints()
            tHud:SetPoint("TOP", Azaath.root, "TOP", ox, oy)
            if Azaath.ClampToScreen then Azaath.ClampToScreen(tHud) end
            if M.editing and not UnitExists("target") then
                if tHud._azWatched then
                    UnregisterUnitWatch(tHud)
                    tHud._azWatched = false
                end
                if not tHud:IsShown() or not tHud._azPreviewing then
                    TargetPreview()
                    tHud._azPreviewing = true
                end
                tHud:Show()
            else
                tHud._azPreviewing = false
                if not tHud._azWatched then
                    RegisterUnitWatch(tHud)
                    tHud._azWatched = true
                end
            end
        else
            if tHud._azWatched then
                UnregisterUnitWatch(tHud)
                tHud._azWatched = false
            end
            tHud._azPreviewing = false
            tHud:Hide()
        end
    end)
end

function M:SetEditing(editing)
    self.editing = editing and true or false
    if not IsBDO() then return end
    Azaath:RunOutOfCombat(function()
        if not tHud then return end
        tHud._azPreviewing = false
        if Azaath.ApplyBDOTarget then Azaath.ApplyBDOTarget() end
        if self.editing and UnitExists("target") then
            tHud:Show()
            TargetRefresh(true)
        end
    end)
end

--------------------------------------------------------------------------------
-- Placas de inimigo da skin Zerker (Azaath.BDOPlate): mesma API da Azaath.AzBar para o
-- módulo Nameplates. Nome com contorno em cima e, embaixo, a vida em paralelogramo
-- (as texturas HPBg/HPFill do quadro do jogador) com rastro claro no dano. Vermelha
-- nos hostis; amarela só nos neutros (os que só atacam se você atacar antes) e cinza
-- nos que já são de outro jogador. Buffs sobem acima do nome e debuffs ficam abaixo
-- da barra (contêineres nativos criados pelo Nameplates). Valores secretos: só vão
-- para SetValue, nunca são comparados.
--------------------------------------------------------------------------------
local Plate = {}
Azaath.BDOPlate = Plate
local plateTrails = {}
local PLATE_CREAM = { 0.95, 0.92, 0.82 }

local plateDriver = CreateFrame("Frame")
plateDriver:Hide()
plateDriver:SetScript("OnUpdate", function(self, elapsed)
    local any = false
    for f in pairs(plateTrails) do
        local st, trail = f.trailSt, f.health.trail
        if st.hold > 0 then
            st.hold = st.hold - elapsed
            any = true
        else
            local a = trail:GetAlpha() - elapsed / 0.5
            if a <= 0 then
                trail:SetAlpha(0)
                trail:SetValue(f.health.bar:GetValue())
                st.active = false
                plateTrails[f] = nil
            else
                trail:SetAlpha(a)
                any = true
            end
        end
    end
    if not any then self:Hide() end
end)

local function PlateKind(unit)
    local ok, tapped = pcall(function() return UnitIsTapDenied and UnitIsTapDenied(unit) end)
    if ok and not Azaath.IsSecret(tapped) and tapped and not UnitIsPlayer(unit) then return "tapped" end
    local okR, r = pcall(UnitReaction, unit, "player")
    if okR and r and not Azaath.IsSecret(r) and r == 4 then return "neutral" end
    return "hostile"
end

local function PlateStatusBar(parent, level)
    local b = CreateFrame("StatusBar", nil, parent)
    b:SetAllPoints(parent)
    b:SetStatusBarTexture(Tex("HPFill"))
    b:SetMinMaxValues(0, 1)
    b:SetValue(1)
    b:SetFrameLevel(parent:GetFrameLevel() + level)
    return b
end

local function PlateDiamond(parent, size, r, g, b)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetColorTexture(r, g, b, 1)
    t:SetSize(size, size)
    if t.SetRotation then pcall(t.SetRotation, t, math.pi / 4) end
    t:Hide()
    return t
end

-- Placa minimalista do BDO (vídeo 19/11): nome pequeno com contorno e, embaixo, barra
-- finíssima (86x5 em 1080p) com borda escura de 1 px, trilho escuro translúcido e
-- preenchimento líquido. Escolhida pela opção nameplates.style (Azaath.PlateStyle).
-- preenchimento = a mesma arte líquida da vida do quadro, em pílula (plate-fill.js)
local MIN_KIND_FILL = { neutral = "PlateFillNeutral" }

local function CreateMinimal(parent, cfg)
    local W = math.floor((cfg.width or 110) * 0.78 + 0.5)
    local H = 5
    local nameSize = 13
    local f = CreateFrame("Frame", nil, parent)
    f:EnableMouse(false)
    f.bdo, f.minimal, f.nameSize, f.nameGap, f.barH = true, true, nameSize, 3, H
    f.targetMarkH = 0
    f.trailSt = { has = false, active = false, hold = 0, last = nil }
    local top = nameSize + 5
    f.barTop = top
    f:SetSize(W, top + H + 1)

    local h = CreateFrame("Frame", nil, f)
    h:EnableMouse(false)
    h:SetSize(W, H)
    h:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top)
    f.health, f.badge = h, h
    -- pílula (pontas arredondadas como no BDO): borda + trilho numa textura só
    local track = h:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(Tex("PlateTrack"))
    track:SetPoint("TOPLEFT", h, "TOPLEFT", -1, 1)
    track:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 1, -1)
    local function Bar(level)
        local b = CreateFrame("StatusBar", nil, h)
        b:SetAllPoints(h)
        b:SetStatusBarTexture(Tex("PlateFill"))
        b:SetMinMaxValues(0, 1)
        b:SetValue(1)
        b:SetFrameLevel(h:GetFrameLevel() + level)
        return b
    end
    h.trail = Bar(1)
    h.trail:GetStatusBarTexture():SetDesaturated(true)
    h.trail:GetStatusBarTexture():SetVertexColor(1, 0.92, 0.85)
    h.trail:GetStatusBarTexture():SetBlendMode("ADD")
    h.trail:SetAlpha(0)
    h.bar = Bar(2)

    local txt = CreateFrame("Frame", nil, f)
    txt:SetAllPoints(f)
    txt:SetFrameLevel(f:GetFrameLevel() + 6)
    f.textLayer = txt
    local name = txt:CreateFontString(nil, "OVERLAY")
    name:SetFont(Azaath.media.fontBDO or Azaath.media.font, nameSize, "OUTLINE")
    name:SetPoint("BOTTOM", h, "TOP", 0, 3)
    name:SetWidth(W * 1.9)
    name:SetWordWrap(false)
    name:SetJustifyH("CENTER")
    name:SetTextColor(PLATE_CREAM[1], PLATE_CREAM[2], PLATE_CREAM[3])
    f.name = name

    -- alvo: ponta da vida acesa + fagulhas pequenas subindo
    local glow = CreateFrame("Frame", nil, f)
    glow:EnableMouse(false)
    glow:SetAllPoints(f)
    glow:SetFrameLevel(h:GetFrameLevel() + 4)
    local tip = glow:CreateTexture(nil, "OVERLAY")
    tip:SetColorTexture(1, 0.98, 0.86, 0.95)
    tip:SetWidth(1)
    tip:SetPoint("TOPRIGHT", h.bar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    tip:SetPoint("BOTTOMRIGHT", h.bar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    local embers = {}
    local function Respawn(p)
        p.life = 0.5 + math.random() * 0.6
        p.age = 0
        p.x = (math.random() - 0.5) * (W + 8)
        p.sway = (math.random() - 0.5) * 10
        p.rise = 10 + math.random() * 14
        p.w = 4 + math.random() * 4
        p.t:SetSize(p.w, p.w * 1.8)
    end
    for i = 1, 12 do
        local t = glow:CreateTexture(nil, "ARTWORK")
        t:SetTexture(Tex("Spark"))
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
            p.t:SetPoint("BOTTOM", h, "TOP", p.x + p.sway * fr, -1 + p.rise * fr)
            p.t:SetVertexColor(1, 0.3 + 0.5 * fr, 0.08)
            p.t:SetAlpha(math.sin(math.pi * fr) * 0.9)
        end
    end)
    tip:Hide() -- 23/11: a linha branca na ponta da vida saiu (pedido do usuário)
    local ag = tip:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local pulse = ag:CreateAnimation("Alpha")
    pulse:SetFromAlpha(1)
    pulse:SetToAlpha(0.6)
    pulse:SetDuration(0.8)
    glow.pulse = ag
    glow:Hide()
    f.glow = glow
    -- aggro em você: aura vermelha macia só por fora da pílula (PlateAggro.tga = trilho + 5 px)
    local aggro = h:CreateTexture(nil, "BACKGROUND", nil, -1)
    aggro:SetTexture(Tex("PlateAggro"))
    aggro:SetPoint("TOPLEFT", h, "TOPLEFT", -6, 6)
    aggro:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 6, -6)
    aggro:Hide()
    f.aggro = aggro
    f.quest = PlateDiamond(txt, 7, 1, 0.82, 0.20)
    f.quest:SetPoint("LEFT", h, "RIGHT", 4, 0)
    local dragon = txt:CreateTexture(nil, "OVERLAY")
    dragon:SetTexture("Interface/TargetingFrame/Nameplates")
    dragon:SetSize(nameSize * 1.15, nameSize * 1.15)
    dragon:Hide()
    f.dragon, f.plateW = dragon, W * 1.9
    return f
end

function Plate.Create(parent, cfg)
    if Azaath.PlateStyle and Azaath.PlateStyle() == "minimal" then return CreateMinimal(parent, cfg) end
    local W = cfg.width or 110
    local H = math.max(7, math.floor(W * 32 / 368 + 0.5))
    local nameSize = 11
    local f = CreateFrame("Frame", nil, parent)
    f:EnableMouse(false)
    f.bdo, f.nameSize, f.nameGap, f.barH = true, nameSize, 3, H
    f.targetMarkH = 0
    f.trailSt = { has = false, active = false, hold = 0, last = nil }
    local top = nameSize + 6
    f.barTop = top
    f:SetSize(W, top + H)

    local h = CreateFrame("Frame", nil, f)
    h:EnableMouse(false)
    h:SetSize(W, H)
    h:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -top)
    f.health, f.badge = h, h
    local bg = h:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(h)
    bg:SetTexture(Tex("HPBg"))
    h.trail = PlateStatusBar(h, 1)
    h.trail:GetStatusBarTexture():SetVertexColor(1, 0.92, 0.85)
    h.trail:GetStatusBarTexture():SetBlendMode("ADD")
    h.trail:SetAlpha(0)
    h.bar = PlateStatusBar(h, 2)

    local txt = CreateFrame("Frame", nil, f)
    txt:SetAllPoints(f)
    txt:SetFrameLevel(f:GetFrameLevel() + 6)
    f.textLayer = txt
    local name = txt:CreateFontString(nil, "OVERLAY")
    name:SetFont(Azaath.media.fontBDO or Azaath.media.font, nameSize, "OUTLINE")
    name:SetPoint("BOTTOM", h, "TOP", 0, 4)
    name:SetWidth(W * 1.4)
    name:SetWordWrap(false)
    name:SetJustifyH("CENTER")
    name:SetTextColor(PLATE_CREAM[1], PLATE_CREAM[2], PLATE_CREAM[3])
    f.name = name

    -- alvo (igual à minimalista): placa 30% maior (Nameplates), nome dourado, ponta da
    -- vida acesa e fagulhas subindo. (O filete TargetOutline.tga saiu em 23/11.)
    local glow = CreateFrame("Frame", nil, f)
    glow:EnableMouse(false)
    glow:SetAllPoints(f)
    glow:SetFrameLevel(f:GetFrameLevel() + 5)
    local line = glow:CreateTexture(nil, "OVERLAY")
    line:SetColorTexture(1, 0.98, 0.86, 0.95)
    line:SetWidth(1)
    line:SetPoint("TOPRIGHT", h.bar:GetStatusBarTexture(), "TOPRIGHT", 0, 0)
    line:SetPoint("BOTTOMRIGHT", h.bar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, 0)
    local embers = {}
    local function Respawn(p)
        p.life = 0.5 + math.random() * 0.6
        p.age = 0
        p.x = (math.random() - 0.5) * (W + 10)
        p.sway = (math.random() - 0.5) * 14
        p.rise = 14 + math.random() * 18
        p.w = 5 + math.random() * 6
        p.t:SetSize(p.w, p.w * 1.8)
    end
    for i = 1, 16 do
        local t = glow:CreateTexture(nil, "ARTWORK", nil, 1)
        t:SetTexture(Tex("Spark"))
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
    line:Hide() -- 23/11: a linha branca na ponta da vida saiu (pedido do usuário)
    local ag = line:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local pulse = ag:CreateAnimation("Alpha")
    pulse:SetFromAlpha(1)
    pulse:SetToAlpha(0.6)
    pulse:SetDuration(0.8)
    glow.pulse = ag
    glow:Hide()
    f.glow = glow
    -- aggro em você: aura vermelha macia só por fora do paralelogramo (PlateAggroPar.tga)
    local aggro = h:CreateTexture(nil, "BACKGROUND", nil, -1)
    aggro:SetTexture(Tex("PlateAggroPar"))
    aggro:SetPoint("TOPLEFT", h, "TOPLEFT", -5, 5)
    aggro:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", 5, -5)
    aggro:Hide()
    f.aggro = aggro
    f.quest = PlateDiamond(txt, 8, 1, 0.82, 0.20)
    f.quest:SetPoint("LEFT", h, "RIGHT", 4, 0)
    -- raro (prata) / elite (ouro): dragão das placas da Blizzard à esquerda do nome
    local dragon = txt:CreateTexture(nil, "OVERLAY")
    dragon:SetTexture("Interface/TargetingFrame/Nameplates")
    dragon:SetSize(nameSize * 1.6, nameSize * 1.6)
    dragon:Hide()
    f.dragon, f.plateW = dragon, W
    return f
end

local function ApplyKind(f, kind)
    if f.kind == kind then return end
    f.kind = kind
    if f.minimal then
        local fill, own, tint = f.health.bar:GetStatusBarTexture(), MIN_KIND_FILL[kind], T_TINT[kind]
        fill:SetTexture(Tex(own or "PlateFill"))
        fill:SetDesaturated(tint ~= nil and not own)
        if tint and not own then fill:SetVertexColor(tint[1], tint[2], tint[3]) else fill:SetVertexColor(1, 1, 1) end
        return
    end
    PaintFill(f.health.bar:GetStatusBarTexture(), kind, T_TINT[kind])
end

function Plate.UpdateHealth(f, instant)
    local unit, h = f.displayUnit, f.health
    if not unit then return end
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    h.bar:SetMinMaxValues(0, max)
    h.bar:SetValue(cur)
    h.trail:SetMinMaxValues(0, max)
    local st = f.trailSt
    if instant or not st.has then
        h.trail:SetValue(cur)
        h.trail:SetAlpha(0)
        st.active = false
        plateTrails[f] = nil
    elseif not st.active then
        h.trail:SetValue(st.last)
        h.trail:SetAlpha(0.9)
        st.active, st.hold = true, 0.25
        plateTrails[f] = true
        plateDriver:Show()
    end
    st.last, st.has = cur, true
end

function Plate.UpdateInfo(f)
    local unit = f.displayUnit
    if not unit then return end
    ApplyKind(f, PlateKind(unit))
    pcall(f.name.SetText, f.name, UnitName(unit) or "")
    local c = PLATE_CREAM
    local okC, class = pcall(UnitClassification, unit)
    local tint = okC and not Azaath.IsSecret(class) and CLASS_TINT[class or ""]
    if tint then c = { PLATE_CREAM[1] * tint[1], PLATE_CREAM[2] * tint[2], PLATE_CREAM[3] * tint[3] } end
    local metal = okC and not Azaath.IsSecret(class) and RARE_METAL[class or ""]
    if metal then
        local tc = DRAGON_COORD[metal]
        f.dragon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        -- encosta no começo do texto (nome centralizado; largura secreta -> meia placa)
        local okW, sw = pcall(f.name.GetStringWidth, f.name)
        local half = f.plateW * 0.5
        if okW and sw and not Azaath.IsSecret(sw) then half = math.min(sw, f.plateW * 1.4) / 2 end
        f.dragon:ClearAllPoints()
        f.dragon:SetPoint("RIGHT", f.name, "CENTER", -half - 1, 0)
        f.dragon:Show()
    else
        f.dragon:Hide()
    end
    if f.hlState == "target" then
        f.name:SetTextColor(1, 0.84, 0.43) -- alvo: nome dourado (todas as placas)
    elseif f.hlState == "mouseover" then
        f.name:SetTextColor(1, 1, 1)
    else
        f.name:SetTextColor(c[1], c[2], c[3])
    end
end

function Plate.SetQuest(f, on)
    on = on and true or false
    if f.questOn == on then return end
    f.questOn = on
    f.quest:SetShown(on)
end

function Plate.SetState(f, state, aggro)
    if f.hlState ~= state then
        f.hlState = state
        if state == "target" then
            f.glow:Show()
            f.glow.pulse:Play()
        else
            f.glow.pulse:Stop()
            f.glow:Hide()
        end
        if f.displayUnit then Plate.UpdateInfo(f) end
    end
    aggro = aggro and true or false
    if f.aggroOn ~= aggro then
        f.aggroOn = aggro
        f.aggro:SetShown(aggro)
    end
end

function Plate.Relevel(f)
    local base = f:GetFrameLevel()
    f.glow:SetFrameLevel(base + 5) -- ponta acesa e fagulhas do alvo por cima da barra
    f.health:SetFrameLevel(base + 1)
    f.health.trail:SetFrameLevel(base + 2)
    f.health.bar:SetFrameLevel(base + 3)
    f.textLayer:SetFrameLevel(base + 6)
end

--------------------------------------------------------------------------------
-- Layout / ciclo de vida
--------------------------------------------------------------------------------
local function Anchor()
    local cfg = Azaath.db.bdo or {}
    hud:SetScale((cfg.scale and cfg.scale > 0) and cfg.scale or 1)
    hud:ClearAllPoints()
    hud:SetPoint("TOPLEFT", Azaath.root, "TOPLEFT", cfg.offsetX or 8, -(cfg.offsetY or 6))
    if Azaath.ClampToScreen then Azaath.ClampToScreen(hud) end
end

function Azaath.GetBDOFrame()
    if not IsBDO() then return nil end
    if hud then return hud end
    B = Azaath.BDO
    hud = CreateFrame("Frame", "AzaathUIBDO", Azaath.root)
    hud:SetSize(B.hud.w, B.hud.h)
    hud:SetFrameStrata("LOW")
    hud:SetFrameLevel(2)
    Anchor()
    Build()
    return hud
end

function M:ApplyLayout()
    if not hud then return end
    Azaath:RunOutOfCombat(function()
        Anchor()
        if Azaath.ApplyBDOTarget then Azaath.ApplyBDOTarget() end
    end)
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        if arg1 == unit then UpdateHealth(event == "UNIT_MAXHEALTH") end
    elseif event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" or event == "UNIT_MAXPOWER" then
        if arg1 == unit then UpdatePower() end
    elseif event == "UNIT_DISPLAYPOWER" then
        if arg1 == unit then UpdatePowerType(); UpdatePower(true) end
    elseif event == "PLAYER_XP_UPDATE" or event == "PLAYER_LEVEL_UP" then
        UpdateXP()
    elseif event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if arg1 == "player" then UpdateUnit() end
    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdateUnit()
        UpdateXP()
    end
end)

function M:OnEnable()
    if not IsBDO() then return end
    -- a 1ª versão ficava embaixo à esquerda (20/80); agora o padrão é no topo
    local cfg = Azaath.db.bdo
    if cfg and not cfg.topV2 then cfg.offsetX, cfg.offsetY, cfg.topV2 = 8, 6, true end
    Azaath:RunOutOfCombat(function()
        if not Azaath.GetBDOFrame() then return end
        BuildPlayerButton()
        for _, e in ipairs({
            "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_POWER_UPDATE", "UNIT_POWER_FREQUENT", "UNIT_MAXPOWER",
            "UNIT_DISPLAYPOWER", "PLAYER_XP_UPDATE", "PLAYER_LEVEL_UP",
            "UNIT_ENTERED_VEHICLE", "UNIT_EXITED_VEHICLE", "PLAYER_ENTERING_WORLD",
        }) do
            Azaath.SafeRegister(events, e)
        end
        UpdateUnit()
        UpdateXP()
        BuildTarget()
        Azaath.ApplyBDOTarget()
        -- o quadro de alvo do Azaath fica invisível e com o tamanho do Zerker (âncora de buffs e conjuração)
        local uf = Azaath:GetModule("UnitFrames")
        if uf and uf.ApplyLayout then uf:ApplyLayout() end
    end)
end
