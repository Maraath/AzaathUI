--[[----------------------------------------------------------------------------
    AzaathUI - Olho de Azaath / Glow.lua
    O brilho em si: um único quadro preso à placa do alvo, que anima o efeito
    escolhido (Effects.lua) conforme o estado do alvo.

    Estado comum a todos os efeitos, recalculado a cada quadro e entregue a eles
    numa tabela "c" (o LootBeam usa o mesmo formato):
      frame, elapsed, size, arrive (0..1 chegada), alpha, ready, locked, flash,
      phase, spin, breath, twinkle, r g b (cor), hr hg hb (clara), wr wg wb (quase branca)

    Também aqui: nome e ícone próprios sobre o objeto, a "dissipação" quando o alvo
    some, o recorte em volta do personagem (silhueta) e a prévia da janela de ajustes.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local ns = Azaath.OlhoNS
local L = ns.L
local SafeCall, IsSecret, Clamp = ns.SafeCall, ns.IsSecret, ns.Clamp
local Look = function(cat, key) return ns.Look(cat, key) end

local ipairs, pcall, type = ipairs, pcall, type
local sin, min, max, rad, tan, random = math.sin, math.min, math.max, math.rad, math.tan, math.random
local TAU = 2 * math.pi

local MEDIA = ns.MEDIA
local SPARE_TEXTURE = "Interface\\Cooldown\\star4" -- quando falta uma imagem do Olho

-- tempos (segundos)
local T_ARRIVE, T_BLEND, T_FLASH, T_FADE = 0.45, 0.30, 0.50, 0.40
local HOLD_STATE, HOLD_LOCKED = 0.15, 0.60 -- estabilidade exigida antes de mostrar um estado

local G = {}
ns.Glow = G

local function Mix(a, b, t) return a + (b - a) * t end
local function Toward(v, goal, step)
    if v < goal then return min(v + step, goal) end
    return max(v - step, goal)
end

-- estado do brilho
local st = {
    frame = nil, anchor = nil, category = nil, effect = nil,
    state = nil, pendingState = nil, pendingAt = 0,
    appear = 0, ready = 0, locked = 0, flash = 0, phase = 0, spin = 0, nextPing = 0,
    r = 1, g = 1, b = 1, tr = 1, tg = 1, tb = 1,
    sx = nil, sy = nil, sscale = 1, measureBroken = false,
    preview = nil, keepForPreview = false, retarget = false,
}
local allLayers = {} -- todas as camadas criadas (para pôr e tirar a máscara da silhueta)

--------------------------------------------------------------------------------
-- Camadas
--------------------------------------------------------------------------------

local function Picture(tex, file)
    if tex:SetTexture(MEDIA .. file .. ".tga") == false then
        tex:SetTexture(SPARE_TEXTURE)
        return false
    end
    return true
end

local function MakeLayer(parent, file, drawLayer, sub, blend)
    local tex = parent:CreateTexture(nil, drawLayer or "ARTWORK", nil, sub or 0)
    local ok = Picture(tex, file)
    tex:SetBlendMode(blend or "ADD")
    tex:SetPoint("CENTER")
    tex:SetVertexColor(1, 1, 1, 0)
    if tex.SetSnapToPixelGrid then tex:SetSnapToPixelGrid(false) end
    if tex.SetTexelSnappingBias then tex:SetTexelSnappingBias(0) end
    return tex, ok
end
G.MakeLayer = MakeLayer

local cut = {} -- silhueta: holder, mask, outline, on, show, failed

local function Build(effect)
    local fx = { waves = {} }
    local mine = {}
    local function Layer(file, drawLayer, sub, blend)
        local tex, ok = MakeLayer(st.frame, file, drawLayer, sub, blend)
        if not ok then effect.missing = true end
        mine[#mine + 1] = tex
        allLayers[#allLayers + 1] = tex
        if cut.on then pcall(tex.AddMaskTexture, tex, cut.mask) end
        return tex
    end
    effect.Build(fx, Layer)
    if effect.wave then
        for i = 1, 2 do fx.waves[i] = { tex = Layer(effect.wave, "BORDER") } end
    end
    effect.fx, effect.layers = fx, mine
end

local function SilenceWaves(fx)
    for _, w in ipairs(fx.waves) do
        w.age = nil
        w.tex:SetVertexColor(1, 1, 1, 0)
    end
end

-- efeito da categoria atual (construído no primeiro uso; reserva se faltar imagem)
local function CurrentEffect()
    local effect = ns.EFFECTS[Look(st.category, "effect")] or ns.EFFECTS.aura
    if not effect.fx then Build(effect) end
    if effect.missing then
        effect = ns.EFFECTS.fallback
        if not effect.fx then Build(effect) end
    end
    if effect ~= st.effect then
        if st.effect then for _, t in ipairs(st.effect.layers) do t:Hide() end end
        for _, t in ipairs(effect.layers) do t:Show() end
        SilenceWaves(effect.fx)
        st.effect = effect
    end
    return effect
end

-- uma onda: anel que se abre (ou se fecha, inward) e apaga
local function Wave(from, to, duration, peak, inward)
    local pick
    for _, w in ipairs(st.effect.fx.waves) do
        if not w.age then pick = w break end
        if not pick or w.age > pick.age then pick = w end
    end
    if not pick then return end
    pick.age, pick.from, pick.to, pick.duration, pick.peak, pick.inward = 0, from, to, duration, peak, inward
end

--------------------------------------------------------------------------------
-- Nome e ícone próprios
--------------------------------------------------------------------------------

local tag -- quadro com .icon e .name

local function Tag()
    if tag then return tag end
    tag = CreateFrame("Frame", nil, st.frame)
    tag:SetSize(1, 1)
    tag.icon = tag:CreateTexture(nil, "OVERLAY")
    tag.icon:SetSize(22, 22)
    tag.name = tag:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    tag.name:SetPoint("CENTER")
    tag.baseFont, tag.baseHeight, tag.baseFlags = tag.name:GetFont()
    return tag
end

local function HideTag()
    if tag then tag:Hide() end
end

local function ShouldHideTagNow()
    local wb = _G.AzaathUICastBarWorld
    if wb and not wb.atCrosshair and wb:IsShown() and (wb.casting or wb.channeling or wb.holdTime > 0 or wb.fadeOut) then
        return true
    end
    return false
end

local function ShowTag(unit, text, cat)
    local wantName, wantIcon = Look(cat, "showName"), Look(cat, "showIcon")
    if not st.anchor or not (wantName or wantIcon) or ns.Native.LightOnly() or ShouldHideTagNow() then HideTag() return end
    local f = Tag()
    local hasIcon = false
    if wantIcon then
        if unit then
            hasIcon = SafeCall(SetUnitCursorTexture, f.icon, unit, nil, true) == true
        else
            local sample = ns.Sense.SAMPLE_CURSOR[cat] or "Interact"
            hasIcon = f.icon:SetTexture("Interface\\Cursor\\" .. sample) ~= false
        end
    end
    f.icon:SetShown(hasIcon)
    f.name:SetText(text or "")
    f.name:SetShown(wantName and true or false)
    f.icon:ClearAllPoints()
    if wantName then
        local h = (f.baseHeight or 12) * Look(cat, "textSize") / 100
        if f.baseFont then
            local file = ns.FontFile(Look(cat, "textFont"))
            local ok, done
            if file then ok, done = pcall(f.name.SetFont, f.name, file, h, f.baseFlags) end
            if not (ok and done ~= false) then f.name:SetFont(f.baseFont, h, f.baseFlags) end
        end
        f.icon:SetPoint("BOTTOM", f, "CENTER", 0, h / 2 + 2)
    else
        f.icon:SetPoint("CENTER")
    end
    if f.anchor ~= st.anchor then
        f.anchor = st.anchor
        f:ClearAllPoints()
        f:SetPoint("CENTER", st.anchor, "CENTER", 0, 0)
    end
    f:Show()
end

--------------------------------------------------------------------------------
-- Silhueta: a interface fica sempre na frente do mundo; para o brilho parecer
-- passar atrás do próprio personagem, uma máscara em elipse o recorta onde o
-- corpo está (a câmera mira o personagem: o tamanho na tela sai do zoom).
--------------------------------------------------------------------------------

local BODY = 1.9 -- altura do corpo em alturas de tela com a câmera a 1 m (campo de visão padrão)

local function Smooth(lo, hi, v)
    local t = Clamp((v - lo) / (hi - lo), 0, 1)
    return t * t * (3 - 2 * t)
end

-- largura, altura e posição dos pés (em relação ao centro da tela); nil em 1ª pessoa
local function BodyOnScreen()
    local zoom = GetCameraZoom and SafeCall(GetCameraZoom)
    if not zoom or zoom < 2 then return nil end
    local cdb = ns.cdb
    local fov = tonumber(ns.Native.Get("cameraFov")) or 90
    local h = BODY * UIParent:GetHeight() / zoom / tan(rad(fov / 2)) * cdb.bodyScale / 100
    local w = h * 0.45
    if IsMounted and SafeCall(IsMounted) == true then
        h = h * 1.3
        w = h * 0.8
    end
    h = h * 0.9 -- vista de cima: o corpo encurta
    return w, h, (cdb.bodyShift / 100 - 0.92) * h
end

local function UpdateCut()
    local w, h, feet = BodyOnScreen()
    if not w then
        cut.mask:SetSize(0.01, 0.01)
        cut.outline:Hide()
        return
    end
    -- só recorta se o objeto estiver atrás do personagem (mais alto na tela que os pés)
    local strength = 1
    if st.preview then
        strength = 0
    elseif st.anchor and st.sy then
        strength = Smooth(feet - 0.10 * h, feet + 0.20 * h, st.sy - UIParent:GetHeight() / 2)
    end
    local cy = feet + h / 2
    local mw, mh = w * 1.9, h * 1.5
    cut.mask:SetSize(max(mw * strength, 0.01), max(mh * strength, 0.01))
    cut.mask:SetPoint("CENTER", cut.holder, "CENTER", 0, cy)
    if cut.show then
        cut.outline:SetSize(mw * 0.55 / 0.74, mh * 0.55 / 0.74)
        cut.outline:SetPoint("CENTER", cut.holder, "CENTER", 0, cy)
        cut.outline:Show()
    else
        cut.outline:Hide()
    end
end

local function MakeCut()
    local holder = CreateFrame("Frame", nil, UIParent)
    holder:SetSize(1, 1)
    holder:SetPoint("CENTER", WorldFrame or UIParent, "CENTER")
    holder:Hide()
    local ok, mask = pcall(holder.CreateMaskTexture, holder)
    if not ok or not mask then cut.failed = "FAIL_NO_MASK" return end
    local set, loaded = pcall(mask.SetTexture, mask, MEDIA .. "hole.tga", "CLAMPTOWHITE", "CLAMPTOWHITE")
    if not set or loaded == false then cut.failed = "FAIL_MASK_TEXTURE" return end
    mask:SetSize(0.01, 0.01)
    mask:SetPoint("CENTER", holder, "CENTER")
    local outline = holder:CreateTexture(nil, "OVERLAY")
    outline:SetTexture(MEDIA .. "ring.tga")
    outline:SetVertexColor(1, 0.25, 0.25, 0.9)
    outline:Hide()
    cut.holder, cut.mask, cut.outline = holder, mask, outline
    holder:SetScript("OnUpdate", UpdateCut)
end

function G.ApplyCut()
    local want = Look(st.anchor and st.category, "silhouette") and not cut.failed
    if not (want or cut.show or cut.on) then return end
    if not cut.holder and not cut.failed then MakeCut() end
    if not cut.holder then return end
    if st.frame and (want and true or false) ~= (cut.on == true) then
        local method = want and "AddMaskTexture" or "RemoveMaskTexture"
        for _, t in ipairs(allLayers) do
            if not pcall(t[method], t, cut.mask) then cut.failed = "FAIL_MASK_REFUSED" break end
        end
        if cut.failed then
            for _, t in ipairs(allLayers) do pcall(t.RemoveMaskTexture, t, cut.mask) end
            want = false
        end
        cut.on = want and true or false
    end
    cut.holder:SetShown((cut.on and st.anchor) or cut.show or false)
end

function ns.ShowZone(on)
    cut.show = on and true or false
    G.ApplyCut()
    ns.Notify()
end
function ns.IsZoneShown() return cut.show == true end
function ns.SilhouetteFailure() return cut.failed and L[cut.failed] end

--------------------------------------------------------------------------------
-- Dissipação: quando a placa some, o brilho se abre e apaga no lugar onde estava
--------------------------------------------------------------------------------

local fade

local function MakeFade()
    fade = CreateFrame("Frame", nil, UIParent)
    fade:SetFrameStrata("BACKGROUND")
    fade:SetSize(1, 1)
    fade:Hide()
    fade.band = MakeLayer(fade, "halo", "BACKGROUND")
    fade.ring = MakeLayer(fade, "ring", "BORDER")
    fade:SetScript("OnUpdate", function(self, dt)
        self.t = self.t + dt
        local p = self.t / T_FADE
        if p >= 1 then self:Hide() return end
        local grow = self.size * (1 + 0.35 * (1 - (1 - p) ^ 3))
        local a = self.alpha * (1 - p) ^ 2
        self.band:SetSize(max(grow * self.spread, 0.01), max(grow * self.spread * self.flat, 0.01))
        self.band:SetVertexColor(self.r, self.g, self.b, min(0.7 * a, 1))
        self.ring:SetSize(max(grow, 0.01), max(grow * self.flat, 0.01))
        self.ring:SetVertexColor(Mix(self.r, 1, 0.55), Mix(self.g, 1, 0.55), Mix(self.b, 1, 0.55), self.ringed and min(a, 1) or 0)
    end)
end

local function Dissipate()
    local e = st.effect
    if not st.sx or st.preview or not e or e == ns.EFFECTS.fallback or st.appear < 0.3 then return end
    if not fade then MakeFade() end
    if fade.effect ~= e then
        fade.effect = e
        Picture(fade.band, e.band or "glow")
        Picture(fade.ring, e.wave or "ring")
    end
    local fx = e.fx
    fade.spread = e.band and 1 or 1.5
    fade.flat, fade.ringed = e.flat or 1, e.wave ~= nil
    fade.ring:SetRotation(fx.waveAngle or 0)
    fade:ClearAllPoints()
    fade:SetPoint("CENTER", UIParent, "BOTTOMLEFT", st.sx, st.sy + (fx.waveY or 0) * st.sscale)
    fade.size = (fx.waveSize or Look(st.category, "size")) * st.sscale
    fade.r, fade.g, fade.b = st.r, st.g, st.b
    fade.alpha = Look(st.category, "intensity") / 100 * (1 - (ns.db.hideLocked and 1 or 0.5) * st.locked)
    fade.t = 0
    fade:Show()
end

--------------------------------------------------------------------------------
-- Animação
--------------------------------------------------------------------------------

-- guarda o centro na tela (para a dissipação e a silhueta); algumas medidas são proibidas
local function Remember(frame)
    st.sx = nil
    if st.measureBroken then return end
    local ok, x, y = pcall(frame.GetCenter, frame)
    local ok2, scale = pcall(frame.GetEffectiveScale, frame)
    if not ok or not ok2 then st.measureBroken = true return end
    local ui = UIParent:GetEffectiveScale()
    if IsSecret(x) or IsSecret(y) or IsSecret(scale) or IsSecret(ui) then return end
    if not x or not y or not scale or ui == 0 then return end
    local k = scale / ui
    st.sx, st.sy, st.sscale = x * k, y * k, k
end

local c = {} -- contexto entregue ao efeito

local function Tick(self, dt)
    if dt > 0.1 then dt = 0.1 end
    local effect = CurrentEffect()
    local fx = effect.fx
    local db = ns.db

    st.appear = Toward(st.appear, 1, dt / T_ARRIVE)
    st.ready = Toward(st.ready, st.state == "ready" and 1 or 0, dt / T_BLEND)
    st.locked = Toward(st.locked, st.state == "locked" and 1 or 0, dt / T_BLEND)
    st.flash = max(st.flash - dt / T_FLASH, 0)
    local k = min(dt * 8, 1)
    st.r, st.g, st.b = Mix(st.r, st.tr, k), Mix(st.g, st.tg, k), Mix(st.b, st.tb, k)

    local ready, locked = st.ready, st.locked
    st.phase = st.phase + dt * TAU / Mix(3.4, 1.7, ready)               -- respiração
    st.spin = st.spin - dt * Mix(0.55, 1.6, ready) * (1 - 0.7 * locked) -- giro

    local dim = db.hideLocked and 1 or 0.5
    c.frame, c.elapsed, c.size = self, dt, Look(st.category, "size")
    c.arrive = 1 - (1 - st.appear) ^ 3
    c.alpha = c.arrive * Look(st.category, "intensity") / 100 * (1 - dim * locked)
    c.ready, c.locked, c.flash, c.phase, c.spin = ready, locked, st.flash, st.phase, st.spin
    c.breath = 0.5 + 0.5 * sin(st.phase)
    c.twinkle = 0.5 + 0.5 * sin(st.phase * 2.3 + 1.3)
    local grey = 0.75 * locked
    local r, g, b = Mix(st.r, 0.62, grey), Mix(st.g, 0.62, grey), Mix(st.b, 0.62, grey)
    c.r, c.g, c.b = r, g, b
    c.hr, c.hg, c.hb = Mix(r, 1, 0.55), Mix(g, 1, 0.55), Mix(b, 1, 0.55)
    c.wr, c.wg, c.wb = Mix(r, 1, 0.75), Mix(g, 1, 0.75), Mix(b, 1, 0.75)

    effect.Update(fx, c)

    -- "ping" periódico para fora (some num objeto recusado)
    st.nextPing = st.nextPing - dt
    if st.nextPing <= 0 then
        st.nextPing = Mix(2.4, 3.8, ready)
        if st.state ~= "locked" and effect.ping ~= false then Wave(0.55, 1.45, 1.0, 0.55) end
    end
    local base, flat, gain = fx.waveSize or c.size, effect.flat or 1, c.alpha * (effect.waveGain or 1)
    for _, w in ipairs(fx.waves) do
        if w.age then
            w.age = w.age + dt
            local p = w.age / w.duration
            if p >= 1 then
                w.age = nil
                w.tex:SetVertexColor(1, 1, 1, 0)
            else
                local a = w.inward and (p < 0.7 and p / 0.7 or (1 - p) / 0.3) or (1 - p) ^ 1.5
                local width = base * Mix(w.from, w.to, 1 - (1 - p) ^ 2)
                w.tex:SetSize(max(width, 0.01), max(width * flat, 0.01))
                if fx.waveY then w.tex:SetPoint("CENTER", self, "CENTER", 0, fx.waveY) end
                if fx.waveAngle then w.tex:SetRotation(fx.waveAngle) end
                w.tex:SetVertexColor(c.hr, c.hg, c.hb, Clamp(gain * w.peak * a, 0, 1))
            end
        end
    end

    if tag then
        if ShouldHideTagNow() then
            if tag:IsShown() then tag:Hide() end
        elseif tag:IsShown() then
            tag:SetAlpha(c.arrive * (1 - (db.hideLocked and 1 or 0.4) * locked))
            tag.name:SetTextColor(c.hr, c.hg, c.hb)
        end
    end
    Remember(self)
end

local function Frame()
    if not st.frame then
        local f = CreateFrame("Frame")
        f:SetSize(1, 1)
        f:Hide()
        f:SetScript("OnUpdate", Tick)
        st.frame = f
    end
    return st.frame
end

--------------------------------------------------------------------------------
-- Prender e soltar
--------------------------------------------------------------------------------

local function SetState(state)
    if state == st.state then return end
    if state == "ready" then
        st.flash = 1
        Wave(1.50, 1.00, 0.35, 0.9, true) -- anel que se fecha: "travou"
    end
    st.state = state
end

-- só mostra um estado novo quando ele se mantém (evita piscar no limite do alcance)
local function Propose(state)
    if state == st.state then st.pendingState = nil return end
    local now = GetTime()
    if st.pendingState ~= state then
        st.pendingState, st.pendingAt = state, now
    elseif now - st.pendingAt >= (state == "locked" and HOLD_LOCKED or HOLD_STATE) then
        st.pendingState = nil
        SetState(state)
    end
end

function G.Release(force)
    ns.Native.ShowPlate()
    if not st.anchor then return end
    if st.keepForPreview and st.preview and not force then return end
    Dissipate()
    st.frame:Hide()
    st.frame:ClearAllPoints()
    st.frame:SetParent(nil)
    if tag then
        tag:Hide()
        tag:ClearAllPoints()
        tag.anchor = nil
    end
    st.anchor, st.preview, st.retarget, st.sx = nil, nil, false, nil
    G.ApplyCut()
end

local function Attach(anchor, cat, state)
    local f = Frame()
    f:SetParent(anchor)
    local ok, level = pcall(anchor.GetFrameLevel, anchor)
    if ok and level and not IsSecret(level) then f:SetFrameLevel(max(level - 1, 0)) end
    f:ClearAllPoints()
    f:SetPoint("CENTER", anchor, "CENTER", 0, Look(cat, "offsetY"))
    f:SetIgnoreParentAlpha(not Look(cat, "followAlpha"))
    st.anchor, st.category = anchor, cat
    st.state, st.pendingState = state, nil
    st.ready = state == "ready" and 1 or 0
    st.locked = state == "locked" and 1 or 0
    st.r, st.g, st.b = ns.GetColor(cat)
    st.tr, st.tg, st.tb = st.r, st.g, st.b
    st.appear, st.flash, st.phase, st.nextPing = 0, 0, 0, 1.6
    st.spin = random() * TAU
    SilenceWaves(CurrentEffect().fx)
    Wave(0.50, 1.50, 0.9, 0.8)
    f:Show()
    G.ApplyCut()
end

-- mostra o brilho na placa do alvo
function G.Present(plate, unit, text, cat, state)
    if st.anchor ~= plate or st.retarget or st.category ~= cat then
        st.keepForPreview = false -- um alvo real tira o brilho da prévia
        G.Release(true)
        Attach(plate, cat, state)
    else
        st.tr, st.tg, st.tb = ns.GetColor(cat)
        Propose(state)
    end
    if ns.Native.LightOnly() then ns.Native.ShowPlate() else ns.Native.HidePlate(plate) end
    ShowTag(unit, text, cat)
end

function G.Anchor() return st.anchor end
function G.Category() return st.category end
function G.State() return st.state end
function G.Effect() return st.effect end
function G.Retarget() if st.anchor and not st.preview then st.retarget = true end end
function G.HoldingPreview() return st.preview ~= nil and st.preview.soft and true or false end
function G.Previewing() return st.preview ~= nil end
function G.SetKeep(v) st.keepForPreview = v and true or false end

-- a cor da categoria mudou: o brilho atual vai até ela
function G.RecolorIfShown()
    if st.anchor then st.tr, st.tg, st.tb = ns.GetColor(st.category) end
end

-- ajustes de posição mudaram
function G.Reposition()
    if not st.anchor then return end
    if st.preview then
        st.frame:ClearAllPoints()
        st.frame:SetPoint("CENTER", st.anchor, "CENTER", 0, Look(st.category, "offsetY"))
        st.frame:SetIgnoreParentAlpha(not Look(st.category, "followAlpha"))
    else
        st.retarget = true
    end
end

--------------------------------------------------------------------------------
-- Prévia (janela de ajustes): passa pelos três estados em loop
--------------------------------------------------------------------------------

local STAGES = { { "far", 3.0 }, { "ready", 4.5 }, { "locked", 2.5 } }

local function SampleName(cat) return L["SAMPLE_" .. cat:upper()] end

-- `soft`: a prévia cede o brilho ao primeiro alvo real
function ns.StartPreview(anchor, cat, soft)
    st.keepForPreview = false
    G.Release(true)
    if not soft then ns.Native.Unmute() end
    Attach(anchor, cat, "far")
    st.preview = { stage = 1, left = STAGES[1][2], soft = soft and true or nil }
    ShowTag(nil, SampleName(cat), cat)
end

function ns.StopPreview()
    st.keepForPreview = false
    if st.preview then G.Release(true) end
end

function G.UpdatePreview(dt)
    local p = st.preview
    if not p then return end
    p.left = p.left - dt
    if p.left > 0 then return end
    p.stage = p.stage + 1
    local stage = STAGES[p.stage]
    if not stage then
        ns.StartPreview(st.anchor, st.category, p.soft)
        return
    end
    SetState(stage[1])
    p.left = stage[2]
end

function G.RefreshTag(unit, text)
    if st.preview then
        ShowTag(nil, SampleName(st.category), st.category)
    elseif st.anchor then
        ShowTag(unit, text, st.category)
    end
end

function ns.IsPreviewing() return st.preview ~= nil end
function ns.GlowTaken() return st.anchor ~= nil and not st.preview end
function ns.PreviewState() return st.preview and st.state end
ns.GlowBare = function() return ns.Native.LightOnly() end
