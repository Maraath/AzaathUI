--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Effects.lua
    Sistema de brilhos (glow 9-slice, halo redondo, outline, formigas marchando),
    marcadores de seleção (16 estilos) e bordas de destaque para alvo/foco/casts.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, tonumber = pairs, ipairs, pcall, tonumber
local floor, max, min = math.floor, math.max, math.min

local TEX = NP.MEDIA
local WHITE = "Interface\\Buttons\\WHITE8x8"
local GLOW_TEX = TEX .. "glow.png"
local HALO_TEX = TEX .. "glow-round.png"
local ANTS_TEX = TEX .. "ants-"
local SEL_TEX  = TEX .. "sel-"

local function NoSnap(t)
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
    if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
end

-- Glow 9-fatias ao redor de qualquer região
local GlowMixin = {}
local PIECES = {
    tl = { 0, 0.5, 0, 0.5 }, tr = { 0.5, 1, 0, 0.5 },
    bl = { 0, 0.5, 0.5, 1 }, br = { 0.5, 1, 0.5, 1 },
    top = { 0.5, 0.5, 0, 0.5 }, bottom = { 0.5, 0.5, 0.5, 1 },
    left = { 0, 0.5, 0.5, 0.5 }, right = { 0.5, 1, 0.5, 0.5 },
}

function GlowMixin:Setup(color, size, alpha, padding, lengthX, heightY)
    local r, g, b, a = NP.RGBA(color)
    a = a * (alpha or 1)
    local d = padding or 0
    local w = max(1, (size or 3) * 2)
    local wy = max(1, w + (heightY or 0))
    w = max(w, wy)
    local dx = d + (lengthX or 0)
    local o, p = self.region, self.pieces
    for _, t in pairs(p) do t:ClearAllPoints(); t:SetVertexColor(r, g, b, a) end

    p.tl:SetPoint("BOTTOMRIGHT", o, "TOPLEFT", -dx, d);  p.tl:SetSize(w, wy)
    p.tr:SetPoint("BOTTOMLEFT", o, "TOPRIGHT", dx, d);   p.tr:SetSize(w, wy)
    p.bl:SetPoint("TOPRIGHT", o, "BOTTOMLEFT", -dx, -d); p.bl:SetSize(w, wy)
    p.br:SetPoint("TOPLEFT", o, "BOTTOMRIGHT", dx, -d);  p.br:SetSize(w, wy)

    p.top:SetPoint("BOTTOMLEFT", o, "TOPLEFT", -dx, d);    p.top:SetPoint("BOTTOMRIGHT", o, "TOPRIGHT", dx, d);     p.top:SetHeight(wy)
    p.bottom:SetPoint("TOPLEFT", o, "BOTTOMLEFT", -dx, -d); p.bottom:SetPoint("TOPRIGHT", o, "BOTTOMRIGHT", dx, -d); p.bottom:SetHeight(wy)
    p.left:SetPoint("TOPRIGHT", o, "TOPLEFT", -dx, d);     p.left:SetPoint("BOTTOMRIGHT", o, "BOTTOMLEFT", -dx, -d); p.left:SetWidth(w)
    p.right:SetPoint("TOPLEFT", o, "TOPRIGHT", dx, d);     p.right:SetPoint("BOTTOMLEFT", o, "BOTTOMRIGHT", dx, -d); p.right:SetWidth(w)

    self.noSides = dx < 0
    local f = self.fill
    if d > 0 then
        local fx = max(0, dx)
        for _, t in pairs(f) do t:ClearAllPoints(); t:SetVertexColor(r, g, b, a) end
        f.top:SetPoint("BOTTOMLEFT", o, "TOPLEFT", -dx, 0);    f.top:SetPoint("BOTTOMRIGHT", o, "TOPRIGHT", dx, 0);    f.top:SetHeight(d)
        f.bottom:SetPoint("TOPLEFT", o, "BOTTOMLEFT", -dx, 0); f.bottom:SetPoint("TOPRIGHT", o, "BOTTOMRIGHT", dx, 0); f.bottom:SetHeight(d)
        f.left:SetPoint("TOPRIGHT", o, "TOPLEFT", 0, 0);       f.left:SetPoint("BOTTOMRIGHT", o, "BOTTOMLEFT", 0, 0);  f.left:SetWidth(max(0.01, fx))
        f.right:SetPoint("TOPLEFT", o, "TOPRIGHT", 0, 0);      f.right:SetPoint("BOTTOMLEFT", o, "BOTTOMRIGHT", 0, 0); f.right:SetWidth(max(0.01, fx))
        self.useFill = true
    else
        self.useFill = false
    end
    if self.shown then self:SetShown(true) end
end

function GlowMixin:SetColor(r, g, b, a)
    for _, t in pairs(self.pieces) do t:SetVertexColor(r, g, b, a) end
    for _, t in pairs(self.fill) do t:SetVertexColor(r, g, b, a) end
end

function GlowMixin:SetShown(shown)
    self.shown = shown and true or false
    for _, t in pairs(self.pieces) do t:SetShown(shown) end
    for _, t in pairs(self.fill) do t:SetShown(shown and self.useFill) end
    if shown and self.noSides then
        self.pieces.left:Hide(); self.pieces.right:Hide()
        self.fill.left:Hide(); self.fill.right:Hide()
    end
end

function NP.CreateGlow(parent, region, layer, sublevel)
    local g = { region = region, parent = parent, pieces = {}, fill = {} }
    _G.Mixin(g, GlowMixin)
    for k, tc in pairs(PIECES) do
        local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or -7)
        t:SetTexture(GLOW_TEX)
        t:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        NoSnap(t)
        g.pieces[k] = t
    end
    for _, k in ipairs({ "top", "bottom", "left", "right" }) do
        local t = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sublevel or -7)
        t:SetTexture(WHITE)
        NoSnap(t)
        g.fill[k] = t
    end
    g.top, g.bottom, g.left, g.right = g.pieces.top, g.pieces.bottom, g.pieces.left, g.pieces.right
    g:SetShown(false)
    return g
end

function NP.CreateHalo(region)
    local f = _G.CreateFrame("Frame", nil, region:GetParent())
    f:SetFrameLevel(max(0, region:GetFrameLevel() - 1))
    local t = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    t:SetTexture(HALO_TEX)
    NoSnap(t)
    local h = { frame = f, tex = t, region = region }
    function h:Setup(color, size, alpha, padding, lengthX, heightY)
        local r, g, b, a = NP.RGBA(color)
        local w = max(1, (size or 3) * 2)
        local wy = max(1, w + (heightY or 0))
        local d = padding or 0
        local dx = d + (lengthX or 0)
        self.tex:ClearAllPoints()
        self.tex:SetPoint("TOPLEFT", region, "TOPLEFT", -(dx + w * 4), d + wy * 3)
        self.tex:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", dx + w * 4, -(d + wy * 3))
        self.tex:SetVertexColor(r, g, b, a * (alpha or 1))
        self.frame:SetFrameLevel(max(0, region:GetFrameLevel() - 1))
    end
    function h:SetShown(shown)
        self.shown = shown and true or false
        self.frame:SetShown(shown)
    end
    f:Hide()
    return h
end

function NP.CreateAtlasBorder(parent, region)
    local t = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    local ok = pcall(t.SetAtlas, t, "UI-HUD-Nameplates-Selected", false)
    t.atlasOK = ok and t:GetAtlas() ~= nil
    t:Hide()
    function t:Setup(color, alpha, padding)
        local r, g, b, a = NP.RGBA(color)
        padding = padding or 0
        self:ClearAllPoints()
        self:SetPoint("TOPLEFT", region, "TOPLEFT", -1 - padding, 1 + padding)
        self:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 3 + padding, -3 - padding)
        self:SetVertexColor(r, g, b, a * (alpha or 1))
    end
    return t
end

-- Formigas marchando (linhas tracejadas animadas ao redor de barras e ícones)
local AntsMixin = {}
local ANT_SIDES = {
    { a1 = "TOPLEFT",    a2 = "TOPRIGHT",    dx =  1, dy =  0 },
    { a1 = "TOPRIGHT",   a2 = "BOTTOMRIGHT", dx =  0, dy = -1 },
    { a1 = "BOTTOMLEFT", a2 = "BOTTOMRIGHT", dx = -1, dy =  0 },
    { a1 = "TOPLEFT",    a2 = "BOTTOMLEFT",  dx =  0, dy =  1 },
}

function AntsMixin:Setup(color, thickness, padding, dash, gap, speed)
    self.color = color
    self.thickness = thickness or 1.5
    self.padding = padding or 2
    self.dash = max(1, dash or 6)
    self.gap = max(1, gap or 4)
    self.speed = speed or 1
    self.period = self.dash + self.gap

    local ratio = floor(self.dash / self.period * 10 + 0.5) * 10
    ratio = min(80, max(20, ratio))
    local r, g, b, a = NP.RGBA(color)
    local th, f, P = self.thickness, self.frame, self.period
    for i, sd in ipairs(ANT_SIDES) do
        local side, t = self.sides[i], self.pool[i]
        local horizontal = (sd.dy == 0)
        t:SetTexture(ANTS_TEX .. (horizontal and "h" or "v") .. ratio .. ".png", "REPEAT", "REPEAT")
        t:SetVertexColor(r, g, b, a)
        side.clip:ClearAllPoints()
        side.clip:SetPoint(sd.a1, f, sd.a1)
        side.clip:SetPoint(sd.a2, f, sd.a2)
        side.inner:ClearAllPoints()
        if horizontal then
            side.clip:SetHeight(th)
            side.inner:SetPoint("TOPLEFT", side.clip, "TOPLEFT", sd.dx > 0 and -P or 0, 0)
            side.inner:SetPoint("BOTTOMRIGHT", side.clip, "BOTTOMRIGHT", sd.dx > 0 and 0 or P, 0)
        else
            side.clip:SetWidth(th)
            side.inner:SetPoint("TOPLEFT", side.clip, "TOPLEFT", 0, sd.dy < 0 and P or 0)
            side.inner:SetPoint("BOTTOMRIGHT", side.clip, "BOTTOMRIGHT", 0, sd.dy < 0 and 0 or -P)
        end
        side.move:SetOffset(sd.dx * P, sd.dy * P)
        side.move:SetDuration(P / (20 * max(0.1, self.speed)))
    end
    self.w = nil
    if self.running then self:Draw(); self:Play() end
end

function AntsMixin:Draw()
    local w, h = self.w, self.h
    if not w then
        local pad = self.padding or 0
        w, h = self.region:GetWidth(), self.region:GetHeight()
        if NP.IsSecret(w) or NP.IsSecret(h) or not w or not h then return end
        w, h = w + 2 * pad, h + 2 * pad
        if w <= 0 or h <= 0 then return end
        self.w, self.h = w, h
    end
    local P = self.period or 10
    local p = self.pool
    p[1]:SetTexCoord(-1, w / P, 0, 1)
    p[2]:SetTexCoord(0, 1, (w - P) / P, (w + h) / P)
    p[3]:SetTexCoord((2 * w + h) / P, (w + h - P) / P, 0, 1)
    p[4]:SetTexCoord(0, 1, (2 * w + 2 * h) / P, (2 * w + h - P) / P)
end

function AntsMixin:Play()
    for _, side in ipairs(self.sides) do
        if not side.ag:IsPlaying() then side.ag:Play() end
    end
end

function AntsMixin:Start()
    self.frame:Show()
    self.w = nil
    self.running = true
    self:Draw()
    self:Play()
end

function AntsMixin:Stop()
    self.running = false
    for _, side in ipairs(self.sides) do side.ag:Stop() end
    self.frame:Hide()
end

function NP.CreateAnts(parent, region)
    local f = _G.CreateFrame("Frame", nil, parent)
    f:Hide()
    local ants = { frame = f, region = region, pool = {}, sides = {} }
    f.ants = ants
    for i = 1, 4 do
        local side = { clip = _G.CreateFrame("Frame", nil, f) }
        side.clip:SetClipsChildren(true)
        side.inner = _G.CreateFrame("Frame", nil, side.clip)
        side.ag = side.inner:CreateAnimationGroup()
        side.ag:SetLooping("REPEAT")
        side.move = side.ag:CreateAnimation("Translation")
        local t = side.inner:CreateTexture(nil, "OVERLAY", nil, 6)
        t:SetAllPoints(side.inner)
        ants.pool[i] = t
        ants.sides[i] = side
    end
    _G.Mixin(ants, AntsMixin)
    f:SetScript("OnSizeChanged", function() ants.w = nil; if ants.running then ants:Draw() end end)
    function ants:Anchor(padding)
        f:ClearAllPoints()
        f:SetPoint("TOPLEFT", region, "TOPLEFT", -padding, padding)
        f:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", padding, -padding)
        self.w = nil
    end
    return ants
end

-- Marcadores de seleção e destaques compostos
NP.SELECTION_MARKERS = {
    arrows         = { file = "arrow",       inward = true,  label = "Setas" },
    arrowsOut      = { file = "arrow",       inward = false, label = "Setas (fora)" },
    chevron        = { file = "chevron",     inward = true,  label = "Divisa" },
    chevrons       = { file = "chevrons",    inward = true,  label = "Divisas duplas" },
    chevrons3      = { file = "chevrons3",   inward = true,  label = "Divisas triplas" },
    brackets       = { file = "bracket",     bracket = true, label = "Colchetes" },
    arrowDown      = { file = "arrowdown",   top = true,     label = "Seta acima" },
    chevronDown    = { file = "chevrondown", top = true,     label = "Divisa acima" },
    dart           = { file = "dart",        inward = true,  label = "Dardo" },
    thin           = { file = "thin",        inward = true,  label = "Traço fino" },
    pointer        = { file = "pointer",     inward = true,  label = "Ponteiro" },
    caret          = { file = "caret",       inward = true,  label = "Acento" },
    diamond        = { file = "diamond",     inward = true,  label = "Losango" },
    cornerArrows   = { file = "arrow",       corners = true, label = "Setas nos cantos" },
    cornerChevrons = { file = "chevron",     corners = true, label = "Divisas nos cantos" },
    cornerDarts    = { file = "dart",        corners = true, label = "Dardos nos cantos" },
}
NP.MARKER_ORDER = {
    "arrows", "arrowsOut", "chevron", "chevrons", "chevrons3", "brackets",
    "arrowDown", "chevronDown", "dart", "thin", "pointer", "caret", "diamond",
    "cornerArrows", "cornerChevrons", "cornerDarts",
}
NP.HIGHLIGHT_STYLES = {
    glow    = "Brilho suave",
    pulse   = "Brilho pulsante",
    outline = "Borda pulsante",
    ants    = "Formigas marchando",
    blizz   = "Borda Blizzard",
}
NP.HIGHLIGHT_ORDER = { "glow", "pulse", "outline", "ants", "blizz" }

local function MakeMarkerFrame(parent)
    local mf = _G.CreateFrame("Frame", nil, parent)
    local tex = mf:CreateTexture(nil, "OVERLAY", nil, 7)
    tex:SetAllPoints()
    NoSnap(tex)
    mf.tex = tex
    local ag = mf:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local tr = ag:CreateAnimation("Translation")
    tr:SetSmoothing("IN_OUT")
    mf.anim, mf.tr = ag, tr
    function mf:SetMove(dx, dy) self.tr:SetOffset(dx, dy) end
    function mf:SetMoveDuration(d) self.tr:SetDuration(d) end
    mf:Hide()
    return mf
end

local function SetupMarker(holder, file, mirrored, r, g, b, a)
    holder.tex:SetTexture(SEL_TEX .. file .. ".png")
    if mirrored then holder.tex:SetTexCoord(1, 0, 0, 1) else holder.tex:SetTexCoord(0, 1, 0, 1) end
    holder.tex:SetVertexColor(r, g, b, a)
end

local HighlightMixin = {}

function HighlightMixin:EnsureMarkers()
    if self.markL then return end
    self.markL = MakeMarkerFrame(self.frame)
    self.markR = MakeMarkerFrame(self.frame)
    self.cornerMarks = {}
    for i = 1, 4 do self.cornerMarks[i] = MakeMarkerFrame(self.frame) end
end

function HighlightMixin:SetupMarkers(m, cfg, r, g, b, a)
    self:EnsureMarkers()
    local L, R, region = self.markL, self.markR, self.region
    local leftR, rightR = self.leftRegion or region, self.rightRegion or region
    local gap = (cfg.padding or 0) + 2
    local size = 8 + (cfg.size or 6) * 2
    local mw = max(3, size + (cfg.markW or 0))
    local mh = max(3, size + (cfg.markH or 0))
    local move = 3
    local off = tonumber(cfg.markOffset) or 0
    if off ~= 0 then
        local w, h = region:GetWidth(), region:GetHeight()
        local motion = cfg.arrowMotion and move or 0
        if m.top then
            if type(h) == "number" and not NP.IsSecret(h) and h > 0 then off = max(off, -(gap + h / 2)) end
        elseif type(w) == "number" and not NP.IsSecret(w) and w > 0 then
            off = max(off, -(gap + w / 2) + motion)
        end
    end
    gap = gap + off
    local lvl = region:GetFrameLevel() + 4
    L:SetFrameLevel(lvl); R:SetFrameLevel(lvl)
    L:ClearAllPoints(); R:ClearAllPoints()
    self.cornerOn = false
    if m.corners then
        local q = math.pi / 4
        local spots = {
            { "BOTTOMRIGHT", "TOPLEFT",     -1,  1, -q },
            { "BOTTOMLEFT",  "TOPRIGHT",     1,  1, -3 * q },
            { "TOPRIGHT",    "BOTTOMLEFT",  -1, -1,  q },
            { "TOPLEFT",     "BOTTOMRIGHT",  1, -1,  3 * q },
        }
        local cg = gap * 0.7
        for i, sp in ipairs(spots) do
            local c = self.cornerMarks[i]
            c:SetFrameLevel(lvl)
            c:ClearAllPoints()
            SetupMarker(c, m.file, false, r, g, b, a)
            if c.tex.SetRotation then c.tex:SetRotation(sp[5]) end
            c:SetSize(mw, mh)
            c:SetPoint(sp[1], region, sp[2], sp[3] * cg, sp[4] * cg)
            c:SetMove(-sp[3] * move * 0.7, -sp[4] * move * 0.7)
            c:SetMoveDuration(0.45 / max(0.2, cfg.speed or 1))
        end
        self.cornerOn = true
        self.markCount = 0
        self.markMotion = cfg.arrowMotion and true or false
        return
    end
    if m.top then
        SetupMarker(L, m.file, false, r, g, b, a)
        L:SetSize(mw, mh)
        L:SetPoint("BOTTOM", region, "TOP", 0, gap)
        L:SetMove(0, -move)
        self.markCount = 1
    elseif m.bracket then
        local w = max(3, max(5, (cfg.size or 6) + 3) + (cfg.markW or 0))
        local vh = max(0, (cfg.padding or 0) + 2) + (cfg.markH or 0) / 2
        SetupMarker(L, m.file, false, r, g, b, a)
        SetupMarker(R, m.file, true, r, g, b, a)
        L:SetWidth(w); R:SetWidth(w)
        L:SetPoint("TOPRIGHT", leftR, "TOPLEFT", -gap, vh);   L:SetPoint("BOTTOMRIGHT", leftR, "BOTTOMLEFT", -gap, -vh)
        R:SetPoint("TOPLEFT", rightR, "TOPRIGHT", gap, vh);   R:SetPoint("BOTTOMLEFT", rightR, "BOTTOMRIGHT", gap, -vh)
        L:SetMove(move, 0); R:SetMove(-move, 0)
        self.markCount = 2
    else
        SetupMarker(L, m.file, not m.inward, r, g, b, a)
        SetupMarker(R, m.file, m.inward, r, g, b, a)
        L:SetSize(mw, mh); R:SetSize(mw, mh)
        L:SetPoint("RIGHT", leftR, "LEFT", -gap, 0)
        R:SetPoint("LEFT", rightR, "RIGHT", gap, 0)
        local d = m.inward and move or -move
        L:SetMove(d, 0); R:SetMove(-d, 0)
        self.markCount = 2
    end
    local dur = 0.45 / max(0.2, cfg.speed or 1)
    L:SetMoveDuration(dur); R:SetMoveDuration(dur)
    self.markMotion = cfg.arrowMotion and true or false
end

function HighlightMixin:ShowMarkers()
    if self.cornerOn then
        for _, c in ipairs(self.cornerMarks) do
            c:Show()
            if self.markMotion then c.anim:Play() else c.anim:Stop() end
        end
        return
    end
    local L, R = self.markL, self.markR
    if not L then return end
    L:Show()
    R:SetShown((self.markCount or 2) == 2)
    if self.markMotion then L.anim:Play(); R.anim:Play() else L.anim:Stop(); R.anim:Stop() end
end

function HighlightMixin:HideMarkers()
    if self.cornerMarks then
        for _, c in ipairs(self.cornerMarks) do c.anim:Stop(); c:Hide() end
    end
    if self.markL then
        self.markL.anim:Stop(); self.markR.anim:Stop()
        self.markL:Hide(); self.markR:Hide()
    end
end

function HighlightMixin:HideParts()
    if self.atlas then self.atlas:Hide() end
    if self.glow then self.glow:SetShown(false) end
    if self.halo then self.halo:SetShown(false) end
    if self.outline then self.outline:SetShown(false) end
    if self.pulse then self.pulse:Stop() end
    if self.ants then self.ants:Stop() end
    self:HideMarkers()
end

function HighlightMixin:Apply(cfg)
    self:HideParts()
    local st = cfg.style or "glow"
    local r, g, b, a = NP.RGBA(cfg.color)
    if st == "ants" then
        self.ants = self.ants or NP.CreateAnts(self.frame, self.region)
        self.ants:Anchor(cfg.padding or 2)
        self.ants:Setup(cfg.color, cfg.size or 1.5, cfg.padding or 2, cfg.dash or 6, cfg.gap or 4, cfg.speed or 1)
        self.ants:Start()
    elseif st == "outline" then
        self.outline = self.outline or NP.CreateBorder(self.frame, "OVERLAY", 6)
        self.outline.owner = self.region
        self.outline:SetBorderSize(cfg.size or 2)
        self.outline:SetBorderColor(r, g, b, a * (cfg.alpha or 1))
        self.outline:SetShown(true)
        self.pulseAnim:SetDuration(0.45 / max(0.2, cfg.speed or 1))
        self.pulse:Play()
    elseif st == "pulse" then
        self.glow = self.glow or NP.CreateGlow(self.frame, self.region, "BACKGROUND", -7)
        self.glow:Setup(cfg.color, cfg.size or 3, cfg.alpha or 1, cfg.padding or 0)
        self.glow:SetShown(true)
        self.pulseAnim:SetDuration(0.45 / max(0.2, cfg.speed or 1))
        self.pulse:Play()
    elseif st == "blizz" then
        self.atlas = self.atlas or NP.CreateAtlasBorder(self.frame, self.region)
        self.atlas:Setup(cfg.color, cfg.alpha or 1, cfg.padding or 0)
        self.atlas:Show()
    elseif NP.SELECTION_MARKERS[st] then
        self:SetupMarkers(NP.SELECTION_MARKERS[st], cfg, r, g, b, a * (cfg.alpha or 1))
        self:ShowMarkers()
    else
        self.glow = self.glow or NP.CreateGlow(self.frame, self.region, "BACKGROUND", -7)
        self.glow:Setup(cfg.color, cfg.size or 3, cfg.alpha or 1, cfg.padding or 0)
        self.glow:SetShown(true)
    end
    self.anyPart = true
end

function HighlightMixin:ApplyTarget(cfg)
    self:HideParts()
    self.anyPart = false
    if cfg.glowOn ~= false then
        local gc = self.threatColor or cfg.glowColor or cfg.color
        local useHalo = (cfg.glowShape == "round")
        if useHalo then
            self.halo = self.halo or NP.CreateHalo(self.region)
            self.halo:Setup(gc, cfg.glowSize or cfg.size or 3, cfg.alpha or 0.9, cfg.padding or 0, cfg.glowW or 0, cfg.glowH or 0)
            self.halo:SetShown(true)
        else
            self.glow = self.glow or NP.CreateGlow(self.frame, self.region, "BACKGROUND", -7)
            self.glow:Setup(gc, cfg.glowSize or cfg.size or 3, cfg.alpha or 0.9, cfg.padding or 0, cfg.glowW or 0, cfg.glowH or 0)
            self.glow:SetShown(true)
        end
        self.anyPart = true
    end
    if cfg.marksOn and NP.SELECTION_MARKERS[cfg.style or "arrows"] then
        local mc = self.threatColor or cfg.color
        local r, g, b, a = NP.RGBA(mc)
        self:SetupMarkers(NP.SELECTION_MARKERS[cfg.style or "arrows"], cfg, r, g, b, a * (cfg.alpha or 1))
        self:ShowMarkers()
        self.anyPart = true
    end
end

function HighlightMixin:Show()
    self.frame:SetAlpha(1)
    self.frame:Show()
    if self.halo and self.halo.shown then self.halo:SetShown(true) end
end

function HighlightMixin:Hide()
    self.frame:Hide()
    if self.halo then self.halo:SetShown(false) end
end

function NP.CreateHighlight(parent, region, levelOff)
    local fr = _G.CreateFrame("Frame", nil, parent)
    fr:SetAllPoints(region)
    fr:SetFrameLevel(max(0, region:GetFrameLevel() + (levelOff or 1)))
    fr:Hide()
    local ag = fr:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local pa = ag:CreateAnimation("Alpha")
    pa:SetFromAlpha(1)
    pa:SetToAlpha(0.25)
    pa:SetDuration(0.45)
    local hl = { frame = fr, region = region, pulse = ag, pulseAnim = pa }
    _G.Mixin(hl, HighlightMixin)
    return hl
end
