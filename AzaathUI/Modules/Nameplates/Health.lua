--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Health.lua
    Barra de vida: bordas (pixel, clássica, cantos arredondados), texturas,
    degradê, absorção, previsão de cura, overlays de alvo/foco/hover e
    integração com Execute/DoT Kill.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, unpack, tonumber, type = pairs, ipairs, pcall, unpack, tonumber, type
local floor, max, min = math.floor, math.max, math.min

local UnitHealth           = _G.UnitHealth
local UnitHealthMax        = _G.UnitHealthMax
local UnitGetTotalAbsorbs  = _G.UnitGetTotalAbsorbs
local UnitGetIncomingHeals = _G.UnitGetIncomingHeals
local Interp               = _G.Enum and _G.Enum.StatusBarInterpolation

local TEX = NP.MEDIA
local TARGET_TEX = "Interface\\AddOns\\AzaathUI\\Media\\Target\\"
local BDO_TEX    = "Interface\\AddOns\\AzaathUI\\Media\\BDO\\"
local CLASSIC_FRAME = TEX .. "classic-frame.png"
local ROUND_TEX = TEX .. "round-"
local CORNER_RADIUS = { slight = 3, medium = 5, round = 8 }
local TEXELS = 2

NP.BORDER_STYLES = { pixel = "Linha fina", classic = "Moldura clássica" }
NP.CORNER_STYLES = { off = "Quadrado", slight = "Leve", medium = "Médio", round = "Redondo" }
NP.CORNER_ORDER  = { "off", "slight", "medium", "round" }

local function TexelScale(owner)
    local ok, eff = pcall(owner.GetEffectiveScale, owner)
    local okp, _, physH = pcall(_G.GetPhysicalScreenSize)
    if not ok or type(eff) ~= "number" or NP.IsSecret(eff) or eff <= 0 then return 1 end
    if not okp or type(physH) ~= "number" or physH <= 0 then return 1 end
    local u = 768 / physH / eff
    return max(1, floor(1 / u + 0.5)) * u
end

local function CornerPixelScale(region)
    local ok, eff = pcall(region.GetEffectiveScale, region)
    local physH = _G.GetPhysicalScreenSize and select(2, _G.GetPhysicalScreenSize())
    if not ok or type(eff) ~= "number" or NP.IsSecret(eff) or eff <= 0 or type(physH) ~= "number" or physH <= 0 then
        return 1
    end
    return eff * physH / 768 / TEXELS
end

local function Slice(t, m)
    if t.SetTextureSliceMargins then
        t:SetTextureSliceMargins(m, m, m, m)
        if t.SetTextureSliceMode and _G.Enum and _G.Enum.UITextureSliceMode then
            t:SetTextureSliceMode(_G.Enum.UITextureSliceMode.Stretched)
        end
    end
end

function NP.CanRoundCorners()
    return _G.UIParent and _G.UIParent.CreateMaskTexture ~= nil and _G.UIParent.CreateTexture ~= nil
end

function NP.CornerRadius(which, f)
    local st = NP.Prof(f).style
    if st.borderStyle == "classic" or not NP.CanRoundCorners() then return 0 end
    local c = st.corners
    return CORNER_RADIUS[c and c[which] or "off"] or 0
end

function NP.ApplyCorners(bar, r, regions)
    if not bar.CreateMaskTexture then return end
    local m = bar.cornerMask
    if r > 0 and not m then
        m = bar:CreateMaskTexture()
        local box = bar:CreateTexture(nil, "BACKGROUND", nil, -8)
        box:SetColorTexture(0, 0, 0, 0)
        local o = bar.underBorder or 0
        box:SetPoint("TOPLEFT", bar, "TOPLEFT", -o, o)
        box:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", o, -o)
        m:SetAllPoints(box)
        bar.cornerMask, bar.cornerBox = m, box
    end
    if not m then return end
    for _, t in ipairs(bar.cornerMasked or {}) do t:RemoveMaskTexture(m) end
    bar.cornerMasked = nil
    if r <= 0 then return end
    if m.SetBlockingLoadsRequested then m:SetBlockingLoadsRequested(true) end
    m:SetTexture(ROUND_TEX .. "mask-" .. r .. ".png", "CLAMPTOWHITE", "CLAMPTOWHITE")
    Slice(m, r * TEXELS)
    local e = bar.underBorder or 0
    if m.SetScale then m:SetScale(CornerPixelScale(bar) * (r + e) / r) end
    local list = {}
    for i = 1, 24 do
        local t = regions[i]
        if t then t:AddMaskTexture(m); list[#list + 1] = t end
    end
    bar.cornerMasked = list
end

function NP.UnderBorderSize(size, corner, f)
    if NP.Prof(f).style.borderStyle == "classic" then return 0 end
    if (corner or 0) <= 0 then return 0 end
    size = tonumber(size) or 0
    if size <= 0 then return 0 end
    return max(0.5, min(6, floor(size * 2 + 0.5) / 2)) * 0.5
end

function NP.SetBarUnderBorder(bar, e, bgs)
    bar.underBorder = e
    local fill = bar:GetStatusBarTexture()
    local edge = bar.fillEdge
    if e > 0 and not edge then
        edge = bar:CreateTexture(nil, "BORDER", nil, -2)
        edge:SetTexture("Interface\\Buttons\\WHITE8x8")
        bar.fillEdge = edge
    end
    if edge then
        edge:ClearAllPoints()
        if e > 0 and fill then
            edge:SetPoint("TOPLEFT", fill, "TOPLEFT", -e, e)
            edge:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", e, -e)
            edge:Show()
        else
            edge:Hide()
        end
    end
    for _, t in ipairs(bgs) do
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", bar, "TOPLEFT", -e, e)
        t:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", e, -e)
    end
    if bar.cornerBox then
        bar.cornerBox:ClearAllPoints()
        bar.cornerBox:SetPoint("TOPLEFT", bar, "TOPLEFT", -e, e)
        bar.cornerBox:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", e, -e)
    end
end

-- Borda reutilizável (pixel / clássica / cantos arredondados)
local BorderMixin = {}
function BorderMixin:SetCorner(r)
    self.corner = r or 0
    self:SetBorderSize(self.size)
end
function BorderMixin:SetBorderStyle(style)
    self.style = style
    if style == "classic" and not self.frameTex then
        self.frameTex = self.parent:CreateTexture(nil, self.layer, nil, self.sublevel)
        self.frameTex:SetVertexColor(1, 1, 1, 1)
    end
    self:SetBorderSize(self.size)
end
function BorderMixin:SetBorderSize(size)
    self.size = size
    if self.style == "classic" then
        for _, t in ipairs(self.edges) do t:Hide() end
        if self.ringTex then self.ringTex:Hide() end
        local t = self.frameTex
        local owner = self.owner
        local out = 3
        t:SetTexture(CLASSIC_FRAME)
        local k = TexelScale(owner)
        if t.SetScale then t:SetScale(k) end
        NP.PixelRound(t)
        local m = 8
        local ok, h = pcall(owner.GetHeight, owner)
        if ok and type(h) == "number" and not NP.IsSecret(h) and h > 0 then
            m = max(2, min(m, floor((h / k + 2 * out) / 2)))
        end
        Slice(t, m)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", owner, "TOPLEFT", -out, out)
        t:SetPoint("BOTTOMRIGHT", owner, "BOTTOMRIGHT", out, -out)
        t:Show()
        return
    elseif self.frameTex then
        self.frameTex:Hide()
    end
    local s = size or 1
    if (self.corner or 0) > 0 then
        for _, t in ipairs(self.edges) do t:Hide() end
        local ring = self.ringTex
        if not ring then
            self.ringBox = self.parent:CreateTexture(nil, self.layer, nil, self.sublevel)
            self.ringBox:SetColorTexture(0, 0, 0, 0)
            ring = self.parent:CreateTexture(nil, self.layer, nil, self.sublevel)
            ring:SetVertexColor(NP.RGBA(self.color or { 0, 0, 0, 1 }))
            ring:SetAllPoints(self.ringBox)
            self.ringTex = ring
        end
        local t2 = max(1, min(12, floor(s * 2 + 0.5)))
        local th = t2 / 2
        self.ringBox:ClearAllPoints()
        self.ringBox:SetPoint("TOPLEFT", self.owner, "TOPLEFT", -th, th)
        self.ringBox:SetPoint("BOTTOMRIGHT", self.owner, "BOTTOMRIGHT", th, -th)
        if ring.SetBlockingLoadsRequested then ring:SetBlockingLoadsRequested(true) end
        ring:SetTexture(ROUND_TEX .. "ring-" .. self.corner .. "-" .. t2 .. ".png")
        Slice(ring, self.corner * TEXELS + t2)
        if ring.SetScale then ring:SetScale(CornerPixelScale(self.owner)) end
        ring:SetShown(s > 0)
        return
    elseif self.ringTex then
        self.ringTex:Hide()
    end
    local t, b, l, r = self.top, self.bottom, self.left, self.right
    local o = (s > 0) and 1 or 0
    t:ClearAllPoints(); t:SetPoint("TOPLEFT", self.owner, "TOPLEFT", -s, s);  t:SetPoint("TOPRIGHT", self.owner, "TOPRIGHT", s, s);   t:SetHeight(s + o)
    b:ClearAllPoints(); b:SetPoint("BOTTOMLEFT", self.owner, "BOTTOMLEFT", -s, -s); b:SetPoint("BOTTOMRIGHT", self.owner, "BOTTOMRIGHT", s, -s); b:SetHeight(s + o)
    l:ClearAllPoints(); l:SetPoint("TOPLEFT", self.owner, "TOPLEFT", -s, 0);  l:SetPoint("BOTTOMLEFT", self.owner, "BOTTOMLEFT", -s, 0); l:SetWidth(s + o)
    r:ClearAllPoints(); r:SetPoint("TOPRIGHT", self.owner, "TOPRIGHT", s, 0); r:SetPoint("BOTTOMRIGHT", self.owner, "BOTTOMRIGHT", s, 0); r:SetWidth(s + o)
    self:SetShown(s > 0)
end
function BorderMixin:SetBorderColor(r, g, b, a)
    self.color = { r, g, b, a }
    for _, t in ipairs(self.edges) do t:SetVertexColor(r, g, b, a) end
    if self.frameTex then self.frameTex:SetVertexColor(r, g, b, a) end
    if self.ringTex then self.ringTex:SetVertexColor(r, g, b, a) end
end
function BorderMixin:SetShown(shown)
    if self.style ~= "classic" and (self.corner or 0) > 0 and self.ringTex then
        for _, t in ipairs(self.edges) do t:Hide() end
        self.ringTex:SetShown(shown and (self.size or 0) > 0)
        return
    end
    if self.style == "classic" then
        for _, t in ipairs(self.edges) do t:Hide() end
        if self.frameTex then self.frameTex:SetShown(shown) end
        return
    end
    for _, t in ipairs(self.edges) do t:SetShown(shown) end
end

function NP.CreateBorder(owner, layer, sublevel)
    local holder = { owner = owner, edges = {}, parent = owner, layer = layer or "OVERLAY", sublevel = sublevel or 7 }
    for _, k in ipairs({ "top", "bottom", "left", "right" }) do
        local t = owner:CreateTexture(nil, layer or "OVERLAY", nil, sublevel or 7)
        t:SetColorTexture(1, 1, 1, 1)
        t:SetVertexColor(0, 0, 0, 1)
        holder[k] = t
        holder.edges[#holder.edges + 1] = t
    end
    _G.Mixin(holder, BorderMixin)
    holder:SetBorderSize(1)
    return holder
end

-- Overlays de foco (sem listras)
NP.FOCUS_TEXTURES = {
    edges   = { label = "Brilho nas bordas", file = TEX .. "focus-edges.png" },
    shine   = { label = "Brilho superior",   file = TEX .. "focus-shine.png" },
    solid   = { label = "Cor sólida",        file = "Interface\\Buttons\\WHITE8x8" },
    dots    = { label = "Pontos",            file = TEX .. "focus-dots.png",     tiled = true },
    grid    = { label = "Grade",             file = TEX .. "focus-grid.png",     tiled = true },
}
NP.FOCUS_TEXTURE_ORDER = { "edges", "shine", "solid", "dots", "grid" }

function NP.LayoutFocusOverlay(f)
    local hb, cfg = f.health, NP.Prof(f).indicators.focusOverlay
    local t = NP.FOCUS_TEXTURES[cfg.texture] or NP.FOCUS_TEXTURES.edges
    local o = hb.focusOverlay
    if t.tiled then
        o:SetTexture(t.file, "REPEAT", "REPEAT")
        local period = max(2, cfg.size or 10) * 4
        o:SetTexCoord(0, (f.cfg.healthWidth or 100) / period, 0, (f.cfg.healthHeight or 10) / period)
    else
        o:SetTexture(t.file)
        o:SetTexCoord(0, 1, 0, 1)
    end
    o:SetVertexColor(NP.RGBA(cfg.color))
    o:SetBlendMode(cfg.additive and "ADD" or "BLEND")
end

-- Cor do preenchimento com controle de transparência da textura
function NP.SetHealthFillColor(hb, r, g, b, a)
    a = 1
    hb.lastColor = { r, g, b, a }
    local k = hb.texStrength
    if k == nil then k = 1 end
    local fill = hb:GetStatusBarTexture()
    if fill then
        fill:SetDesaturated(false)
        fill:SetVertexColor(r, g, b, k)
    end
    if hb.flatFill and k < 1 then hb.flatFill:SetVertexColor(r, g, b, 1 - k) end
    if hb.fillEdge then hb.fillEdge:SetVertexColor(r, g, b, 1) end
    if hb.azFramePieces then
        local fr, fg, fb = min(1, r * 1.12), min(1, g * 1.35), min(1, b * 1.35)
        for i = 1, #hb.azFramePieces do hb.azFramePieces[i]:SetVertexColor(fr, fg, fb, 1) end
    end
    local f = hb.ownerFrame
    if f and f.azBadge and f.azBadge.tex then
        f.azBadge.tex:SetVertexColor(min(1, r * 1.24), min(1, g * 1.55), min(1, b * 1.55), 1)
    end
end

-- Elemento Health
local Health = {}

function Health:Create(f)
    local hb = _G.CreateFrame("StatusBar", nil, f)
    hb:SetPoint("CENTER", f, "CENTER", 0, 0)
    hb:SetMinMaxValues(0, 1)
    hb:SetValue(1)
    hb:SetClipsChildren(false)
    hb:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    hb.ownerFrame = f
    f.health = hb

    -- Camadas visuais autênticas das skins originais (Azaath Tinta, Azaath Clássico, Zerker BDO, Minimalista BDO)
    hb.inkBack = hb:CreateTexture(nil, "BACKGROUND", nil, -2)
    hb.inkBack:SetTexture(TARGET_TEX .. "InkBack.tga")
    hb.inkBack:Hide()

    hb.bdoTrack = hb:CreateTexture(nil, "BACKGROUND", nil, -2)
    hb.bdoTrack:SetTexture(BDO_TEX .. "PlateTrack.tga")
    hb.bdoTrack:SetPoint("TOPLEFT", hb, "TOPLEFT", -1, 1)
    hb.bdoTrack:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", 1, -1)
    hb.bdoTrack:Hide()

    hb.azAggro = hb:CreateTexture(nil, "OVERLAY", nil, 5)
    hb.azAggro:SetTexture(BDO_TEX .. "PlateAggro.tga")
    hb.azAggro:SetBlendMode("ADD")
    hb.azAggro:Hide()

    hb.azAggroRim = NP.CreateBorder(hb, "OVERLAY", 6)
    hb.azAggroRim.owner = hb
    hb.azAggroRim:SetBorderSize(1.5)
    hb.azAggroRim:SetBorderColor(0.95, 0.18, 0.15, 1)
    hb.azAggroRim:SetShown(false)

    hb.emptyTiles = {}

    local azEdges = _G.CreateFrame("Frame", nil, hb)
    azEdges:SetAllPoints(hb)
    local function MakeEdge(r, g, b, al)
        local t = azEdges:CreateTexture(nil, "OVERLAY")
        t:SetColorTexture(r, g, b, al)
        return t
    end
    azEdges.top = MakeEdge(0.95, 0.58, 0.58, 0.45); azEdges.top:SetPoint("TOPLEFT"); azEdges.top:SetPoint("TOPRIGHT"); azEdges.top:SetHeight(1)
    azEdges.bot = MakeEdge(0.16, 0.02, 0.03, 0.85); azEdges.bot:SetPoint("BOTTOMLEFT"); azEdges.bot:SetPoint("BOTTOMRIGHT"); azEdges.bot:SetHeight(1)
    azEdges.left = MakeEdge(0.95, 0.62, 0.62, 0.45); azEdges.left:SetPoint("TOPLEFT"); azEdges.left:SetPoint("BOTTOMLEFT"); azEdges.left:SetWidth(1)
    azEdges.right = MakeEdge(0.95, 0.62, 0.62, 0.45); azEdges.right:SetPoint("TOPRIGHT"); azEdges.right:SetPoint("BOTTOMRIGHT"); azEdges.right:SetWidth(1)
    azEdges:Hide()
    hb.azEdges = azEdges

    local azFrame = _G.CreateFrame("Frame", nil, hb)
    azFrame:SetAllPoints(hb)
    local function MakePiece(l, r)
        local t = azFrame:CreateTexture(nil, "ARTWORK", nil, 4)
        t:SetTexture(TARGET_TEX .. "Frame.tga")
        t:SetTexCoord(l, r, 0, 1)
        return t
    end
    azFrame.capL = MakePiece(0, 0.25)
    azFrame.capR = MakePiece(0.75, 1)
    azFrame.mid  = MakePiece(0.3, 0.7)
    azFrame.mid:SetPoint("TOPLEFT", azFrame.capL, "TOPRIGHT")
    azFrame.mid:SetPoint("BOTTOMRIGHT", azFrame.capR, "BOTTOMLEFT")
    azFrame:Hide()
    hb.azFrame = azFrame
    hb.azFramePieces = { azFrame.capL, azFrame.mid, azFrame.capR }

    -- Brasas subindo no alvo selecionado (estilo original Azaath / BDO)
    local embersFrame = _G.CreateFrame("Frame", nil, hb)
    embersFrame:SetAllPoints(hb)
    embersFrame:Hide()
    local embers = {}
    local function RespawnEmber(p, bw)
        p.life = 0.5 + math.random() * 0.6
        p.age = 0
        p.x = (math.random() - 0.5) * ((bw or 110) + 8)
        p.sway = (math.random() - 0.5) * 12
        p.rise = 12 + math.random() * 16
        local w = 4 + math.random() * 5
        p.t:SetSize(w, w * 1.8)
    end
    for i = 1, 12 do
        local t = embersFrame:CreateTexture(nil, "ARTWORK", nil, 2)
        t:SetTexture(BDO_TEX .. "Spark.tga")
        t:SetBlendMode("ADD")
        t:SetAlpha(0)
        local p = { t = t }
        RespawnEmber(p, 110)
        p.age = math.random() * p.life
        embers[i] = p
    end
    embersFrame:SetScript("OnUpdate", function(self, el)
        local bw = hb:GetWidth() or 110
        for i = 1, #embers do
            local p = embers[i]
            p.age = p.age + el
            if p.age >= p.life then RespawnEmber(p, bw) end
            local fr = p.age / p.life
            p.t:ClearAllPoints()
            p.t:SetPoint("BOTTOM", hb, "TOP", p.x + p.sway * fr, -1 + p.rise * fr)
            p.t:SetVertexColor(1, 0.3 + 0.5 * fr, 0.08)
            p.t:SetAlpha(math.sin(math.pi * fr) * 0.92)
        end
    end)
    hb.azEmbers = embersFrame

    hb.bgFlat = hb:CreateTexture(nil, "BACKGROUND", nil, -1)
    hb.bgFlat:SetAllPoints()
    hb.bgFlat:SetColorTexture(1, 1, 1, 1)
    hb.bg = hb:CreateTexture(nil, "BACKGROUND")
    hb.bg:SetAllPoints()

    hb.flatFill = hb:CreateTexture(nil, "BORDER")
    hb.flatFill:SetAllPoints(hb:GetStatusBarTexture())
    hb.flatFill:SetColorTexture(1, 1, 1, 1)
    hb.flatFill:Hide()

    hb.overlay = _G.CreateFrame("Frame", nil, hb)
    hb.overlay:SetAllPoints()
    hb.overlay:SetFrameLevel(hb:GetFrameLevel() + 2)

    hb.kickTint = hb.overlay:CreateTexture(nil, "ARTWORK", nil, 3)
    hb.kickTint:SetAllPoints(hb:GetStatusBarTexture())
    hb.kickTint:Hide()

    local clip = _G.CreateFrame("Frame", nil, hb)
    clip:SetAllPoints()
    clip:SetFrameLevel(hb:GetFrameLevel() + 2)
    clip:SetClipsChildren(true)

    hb.heal = _G.CreateFrame("StatusBar", nil, clip)
    hb.heal:SetPoint("LEFT", hb:GetStatusBarTexture(), "RIGHT")
    hb.heal:SetMinMaxValues(0, 1)
    hb.heal:SetValue(0)
    hb.heal:Hide()

    hb.absorb = _G.CreateFrame("StatusBar", nil, clip)
    hb.absorb:SetPoint("LEFT", hb:GetStatusBarTexture(), "RIGHT")
    hb.absorb:SetStatusBarTexture("Interface\\RaidFrame\\Shield-Fill")
    hb.absorb:SetMinMaxValues(0, 1)
    hb.absorb:SetValue(0)

    hb.absorbOver = _G.CreateFrame("StatusBar", nil, clip)
    hb.absorbOver:SetAllPoints(hb)
    hb.absorbOver:SetReverseFill(true)
    hb.absorbOver:SetMinMaxValues(0, 1)
    hb.absorbOver:SetValue(0)

    hb.gradient = hb.overlay:CreateTexture(nil, "ARTWORK", nil, 2)
    hb.gradient:SetAllPoints()
    hb.gradient:SetColorTexture(1, 1, 1, 1)

    hb.selection = hb.overlay:CreateTexture(nil, "ARTWORK", nil, 3)
    hb.selection:SetAllPoints()
    hb.selection:SetBlendMode("BLEND")
    hb.selection:Hide()

    hb.focusOverlay = hb.overlay:CreateTexture(nil, "ARTWORK", nil, 3)
    hb.focusOverlay:SetAllPoints()
    hb.focusOverlay:Hide()

    hb.hover = hb.overlay:CreateTexture(nil, "ARTWORK", nil, 4)
    hb.hover:SetAllPoints()
    hb.hover:SetColorTexture(1, 1, 1, 1)
    hb.hover:SetBlendMode("ADD")
    hb.hover:Hide()

    hb.executeZone = hb.overlay:CreateTexture(nil, "ARTWORK", nil, 3)
    hb.executeZone:SetColorTexture(1, 1, 1, 1)
    hb.executeZone:Hide()

    hb.execute = hb.overlay:CreateTexture(nil, "ARTWORK", nil, 5)
    hb.execute:Hide()

    hb.targetFx = NP.CreateHighlight(hb, hb, 2)

    hb.borderFrame = _G.CreateFrame("Frame", nil, hb)
    hb.borderFrame:SetAllPoints()
    hb.borderFrame:SetFrameLevel(hb:GetFrameLevel() + 3)
    hb.border = NP.CreateBorder(hb.borderFrame, "OVERLAY", 7)
    hb.border.owner = hb
    hb.border:SetBorderSize(1)
end

NP.THREAT_SPOTS = { border = "Borda", halo = "Halo (Brilho externo)", bar = "Barra de vida", name = "Nome" }
NP.THREAT_SPOT_ORDER = { "border", "halo", "bar", "name" }
local THREAT_ON = { glowThreat = true }

function NP.GlowThreatColor(f, g)
    if not (g and g.glowThreat and f and f.unit and not f.isPreview) then return nil end
    local ok, c = pcall(NP.GetThreatColor, f.unit, NP.Prof(f).colors.threat)
    return ok and c or nil
end

function NP.ThreatBorderColor(f)
    if not f or f.kind ~= "enemynpc" or NP.Prof(f).colors.threat.showOn ~= "border" then return nil end
    return NP.GlowThreatColor(f, THREAT_ON)
end

function NP.HealthBorderSize(f)
    local db = NP.Prof(f)
    local tb = db.indicators.targetBorder
    local size = db.style.borderSize
    if NP.Targeted(f) and tb.enabled and (tb.size or 0) > 0 then size = tb.size end
    if f.azThreatBorder then
        local ts = tonumber(db.colors.threat.borderSize) or 2.5
        if ts > (tonumber(size) or 0) then size = ts end
    end
    return size
end

local function LevelBoxSide(f)
    local box = f and f.levelBox
    if not box or not box:IsShown() or not f.cfg or not f.cfg.level then return nil end
    local l = f.cfg.level
    local side = NP.ANCHOR_SIDES[l.anchor and l.anchor.side or 9] or NP.ANCHOR_SIDES[9]
    local W = f.cfg.healthWidth or 0
    local s = f.levelText:GetWidth()
    if type(s) ~= "number" or NP.IsSecret(s) then s = 0 end
    local bw = box:GetWidth()
    if type(bw) ~= "number" or NP.IsSecret(bw) then bw = l.boxWidth or 22 end
    local function xOf(pt, w)
        if pt:find("LEFT") then return -w / 2 elseif pt:find("RIGHT") then return w / 2 end
        return 0
    end
    local cx = xOf(side[2], W) + (l.anchor and l.anchor.x or 0) - xOf(side[1], s) + (tonumber(l.boxX) or 0)
    if cx - bw / 2 >= W / 2 - 1 then return "right" end
    if cx + bw / 2 <= -W / 2 + 1 then return "left" end
    return nil
end
NP.LevelBoxSide = LevelBoxSide

local function SetGlow(hb, cfg, shown, f)
    if not shown or not cfg or (f and f.cfg and f.cfg.mode == "nameOnly") or not hb:IsShown() then
        hb.targetFx:Hide()
        return
    end
    local boxSide = LevelBoxSide(f)
    hb.targetFx.leftRegion = (boxSide == "left") and f.levelBox or nil
    hb.targetFx.rightRegion = (boxSide == "right") and f.levelBox or nil
    local tc = NP.GlowThreatColor(f, cfg)
    f.azGlowThreat = tc
    hb.targetFx.threatColor = tc
    hb.targetFx:ApplyTarget(cfg)
    if hb.targetFx.anyPart then hb.targetFx:Show() else hb.targetFx:Hide() end
end

function NP.HealPredictionOn(f)
    local hp = NP.Prof(f).style.healPrediction
    return hp and hp.enabled and true or false
end

function Health:Layout(f)
    local db = NP.Prof(f)
    local cfg, style = f.cfg, db.style
    local hb = f.health

    if cfg.mode == "nameOnly" then
        hb:Hide()
        return
    end
    hb:Show()
    hb:ClearAllPoints()
    hb:SetPoint("CENTER", f, "CENTER", NP.PxSnap(f, cfg.healthOffsetX or 0), NP.PxSnap(f, cfg.healthOffsetY or 0))
    hb:SetSize(NP.PxSnap(f, cfg.healthWidth, true), NP.PxSnap(f, cfg.healthHeight, true))
    hb:SetStatusBarTexture(NP.GetStatusBarTexture(style.healthTexture))
    do
        local k = max(0, min(1, tonumber(style.healthTextureAlpha) or 1))
        hb.texStrength = k
        local fill = hb:GetStatusBarTexture()
        fill:SetDrawLayer("ARTWORK", 0)
        hb.flatFill:ClearAllPoints(); hb.flatFill:SetAllPoints(fill)
        hb.kickTint:ClearAllPoints(); hb.kickTint:SetAllPoints(fill)
        hb.kickTint:SetTexture(NP.GetStatusBarTexture(style.healthTexture))
        hb.hover:ClearAllPoints(); hb.hover:SetAllPoints(fill)
        hb.hover:SetTexture(NP.GetStatusBarTexture(style.healthTexture))
        hb.flatFill:SetShown(k < 1)
        if hb.lastColor then NP.SetHealthFillColor(hb, unpack(hb.lastColor)) end
    end

    hb.bg:SetTexture(NP.GetStatusBarTexture(style.healthBgTexture))
    local bs = style.barStyle or "modern"
    hb.inkBack:Hide()
    hb.bdoTrack:Hide()
    hb.azEdges:Hide()
    hb.azFrame:Hide()
    for i = 1, #hb.emptyTiles do hb.emptyTiles[i]:Hide() end

    if bs == "azaath_ink" then
        hb.bg:Hide(); hb.bgFlat:Hide()
        local mx, my = max(5, cfg.healthHeight * 0.9), max(3, cfg.healthHeight * 0.6)
        hb.inkBack:ClearAllPoints()
        hb.inkBack:SetPoint("TOPLEFT", hb, "TOPLEFT", -mx, my)
        hb.inkBack:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", mx, -my)
        hb.inkBack:Show()
    elseif bs == "azaath" then
        hb.bg:Hide()
        hb.bgFlat:SetVertexColor(0.08, 0.06, 0.06, 0.88)
        hb.bgFlat:Show()
        local barH = max(4, cfg.healthHeight or 7)
        local mx, my = max(5, barH * 0.9), max(3, barH * 0.6)
        hb.inkBack:ClearAllPoints()
        hb.inkBack:SetPoint("TOPLEFT", hb, "TOPLEFT", -mx, my)
        hb.inkBack:SetPoint("BOTTOMRIGHT", hb, "BOTTOMRIGHT", mx, -my)
        hb.inkBack:Show()
        hb.azEdges:SetFrameLevel(hb:GetFrameLevel() + 4)
        hb.azEdges:Show()
        local fu = barH / 10
        hb.azFrame:SetFrameLevel(hb:GetFrameLevel() + 5)
        hb.azFrame.capL:ClearAllPoints()
        hb.azFrame.capL:SetSize(20 * fu, 20 * fu)
        hb.azFrame.capL:SetPoint("TOPLEFT", hb, "TOPLEFT", -16 * fu, 5 * fu)
        hb.azFrame.capR:ClearAllPoints()
        hb.azFrame.capR:SetSize(20 * fu, 20 * fu)
        hb.azFrame.capR:SetPoint("TOPRIGHT", hb, "TOPRIGHT", 16 * fu, 5 * fu)
        hb.azFrame.mid:SetHeight(20 * fu)
        hb.azFrame:Show()
    elseif bs == "bdo" then
        hb.bgFlat:Hide()
        hb.bg:SetTexture(BDO_TEX .. "HPBg.tga")
        hb.bg:SetVertexColor(1, 1, 1, 0.95)
        hb.bg:Show()
    elseif bs == "bdo_pill" then
        hb.bg:Hide(); hb.bgFlat:Hide()
        hb.bdoTrack:Show()
    else
        hb.bg:Show()
        local r, g, b, a = NP.RGBA(style.healthBgColor)
        local k = max(0, min(1, tonumber(style.healthBgTextureAlpha) or 1))
        hb.bg:SetVertexColor(r, g, b, a * k)
        hb.bgFlat:SetVertexColor(r, g, b, a * (1 - k))
        hb.bgFlat:SetShown(k < 1)
    end

    if bs == "bdo" then
        hb.azAggro:SetTexture(BDO_TEX .. "PlateAggroPar.tga")
    else
        hb.azAggro:SetTexture(BDO_TEX .. "PlateAggro.tga")
    end
    hb.azAggro:SetAlpha(1)

    local corner = (bs == "modern") and NP.CornerRadius("health", f) or 0
    hb.border.corner = corner
    hb.border:SetBorderStyle(style.borderStyle)
    local bsize = (bs == "modern") and NP.HealthBorderSize(f) or 0
    hb.border:SetBorderSize(bsize)
    NP.SetBarUnderBorder(hb, (bs == "modern") and NP.UnderBorderSize(bsize, corner, f) or 0, { hb.bgFlat, hb.bg })
    if hb.lastColor then NP.SetHealthFillColor(hb, unpack(hb.lastColor)) end

    local hp = style.healPrediction
    local healOn = NP.HealPredictionOn(f)
    local healOver = hp and hp.position == "over"
    hb.heal:ClearAllPoints()
    if healOver then hb.heal:SetAllPoints(hb) else
        hb.heal:SetPoint("LEFT", hb:GetStatusBarTexture(), "RIGHT")
        hb.heal:SetSize(cfg.healthWidth, cfg.healthHeight)
    end
    hb.heal:SetReverseFill(healOver and true or false)
    hb.heal:SetStatusBarTexture(NP.GetStatusBarTexture(style.healthTexture))
    hb.heal:SetStatusBarColor(NP.RGBA(hp and hp.color or { 0.3, 1, 0.4, 0.55 }))
    hb.heal:SetShown(healOn)

    local ab = style.absorbs
    local over = ab.position == "over"
    local abTex = NP.GetStatusBarTexture(ab.texture or "AzNP Shield")
    hb.absorb:ClearAllPoints()
    hb.absorb:SetPoint("LEFT", (healOn and not healOver) and hb.heal:GetStatusBarTexture() or hb:GetStatusBarTexture(), "RIGHT")
    hb.absorb:SetSize(cfg.healthWidth, cfg.healthHeight)
    hb.absorb:SetStatusBarTexture(abTex)
    hb.absorb:SetStatusBarColor(NP.RGBA(ab.color))
    hb.absorb:SetShown(ab.enabled and not over)
    hb.absorbOver:SetStatusBarTexture(abTex)
    hb.absorbOver:SetStatusBarColor(NP.RGBA(ab.color))
    hb.absorbOver:SetShown(ab.enabled and over)

    if style.gradient.enabled then
        Azaath.Gradient(hb.gradient, "VERTICAL", 0, 0, 0, style.gradient.alpha, 0, 0, 0, 0)
        hb.gradient:Show()
    else
        hb.gradient:Hide()
    end

    local ind = db.indicators
    hb.selection:SetTexture(TEX .. "focus-shine.png")
    hb.selection:SetVertexColor(NP.RGBA(ind.targetOverlay.color))
    hb.selection:SetAlpha(min(0.35, tonumber(ind.targetOverlay.alpha) or 0.14))
    hb.hover:SetAlpha(min(0.22, tonumber(ind.hover.alpha) or 0.14))
    NP.LayoutFocusOverlay(f)
    if NP.LayoutExecute then NP.LayoutExecute(f) end
    if NP.DotKill then NP.DotKill.Layout(f) end

    if corner > 0 or hb.cornerMask then
        NP.ApplyCorners(hb, corner, {
            hb.bgFlat, hb.bg, hb:GetStatusBarTexture(), hb.flatFill, hb.fillEdge,
            hb.heal:GetStatusBarTexture(), hb.absorb:GetStatusBarTexture(), hb.absorbOver:GetStatusBarTexture(),
            hb.gradient, hb.kickTint, hb.selection, hb.focusOverlay, hb.hover, hb.execute, hb.executeZone,
            hb.dotMarker and hb.dotMarker:GetStatusBarTexture() or nil,
        })
    end
end

local function UpdateValues(f, animate)
    local hb, unit = f.health, f.unit
    local interp = (animate and NP.Prof(f).style.animateHealth and Interp) and Interp.ExponentialEaseOut or (Interp and Interp.Immediate)
    local maxH = UnitHealthMax(unit)
    local curH = UnitHealth(unit)
    if interp then
        hb:SetMinMaxValues(0, maxH, interp)
        hb:SetValue(curH, interp)
    else
        hb:SetMinMaxValues(0, maxH)
        hb:SetValue(curH)
    end

    local heal = NP.HealPredictionOn(f) and UnitGetIncomingHeals and UnitGetIncomingHeals(unit) or 0
    hb.heal:SetMinMaxValues(0, maxH)
    if NP.IsSecret(heal) or type(heal) == "number" then hb.heal:SetValue(heal) else hb.heal:SetValue(0) end

    local ab = NP.Prof(f).style.absorbs
    if not (ab and ab.enabled) then
        hb.absorb:Hide(); hb.absorbOver:Hide()
        return
    end
    local absorb = UnitGetTotalAbsorbs and UnitGetTotalAbsorbs(unit) or 0
    if not NP.IsSecret(absorb) and (type(absorb) ~= "number" or absorb <= 0) then
        hb.absorb:SetValue(0); hb.absorbOver:SetValue(0)
        hb.absorb:Hide(); hb.absorbOver:Hide()
        return
    end
    if ab.position == "over" then
        hb.absorb:Hide(); hb.absorbOver:Show()
        hb.absorbOver:SetMinMaxValues(0, maxH)
        hb.absorbOver:SetValue(absorb)
    elseif ab.position == "smart" then
        hb.absorb:Show()
        hb.absorb:SetMinMaxValues(0, maxH)
        hb.absorb:SetValue(absorb)
        if not NP.IsSecret(curH) and not NP.IsSecret(maxH) and not NP.IsSecret(absorb) and type(absorb) == "number" then
            local over = (curH + absorb) > maxH
            hb.absorbOver:SetShown(over)
            hb.absorbOver:SetMinMaxValues(0, maxH)
            hb.absorbOver:SetValue(over and (curH + absorb - maxH) or 0)
        else
            hb.absorbOver:SetShown(false)
        end
    else
        hb.absorb:Show()
        hb.absorb:SetMinMaxValues(0, maxH)
        hb.absorb:SetValue(absorb)
        hb.absorbOver:SetShown(false)
    end
end

function NP.UpdateHealthColor(f)
    if not f or not f.health or f.cfg.mode == "nameOnly" or not f.unit then return end
    local c = NP.GetHealthColor(f)
    NP.SetHealthFillColor(f.health, NP.RGBA(c))
    if NP.UpdateHealthBorder then NP.UpdateHealthBorder(f) end
end

function NP.UpdateHealthBorder(f)
    if not f or not f.health or f.cfg.mode == "nameOnly" then return end
    local db = NP.Prof(f)
    local ind = db.indicators
    local targeted = NP.Targeted(f)
    local bs = db.style.barStyle or "modern"
    local threatCol = NP.ThreatBorderColor(f)
    f.azThreatBorder = threatCol ~= nil
    f.health.border:SetBorderSize((bs == "modern") and NP.HealthBorderSize(f) or 0)

    local col
    if threatCol then
        col = threatCol
    elseif f.isFocus and ind.focusBorder.enabled then
        col = (ind.focusBorder.classColor and f.unit and NP.GetClassColor(f.unit)) or ind.focusBorder.color
    elseif targeted and ind.targetBorder.enabled then
        if ind.targetBorder.threatColor and f.kind == "enemynpc" and f.unit then
            local ok, tc = pcall(NP.GetThreatColor, f.unit, db.colors.threat)
            col = ok and tc or nil
        end
        if not col then
            col = (ind.targetBorder.classColor and f.unit and NP.GetClassColor(f.unit)) or ind.targetBorder.color
        end
    else
        col = db.style.borderColor
    end
    f.health.border:SetBorderColor(NP.RGBA(col))

    local fx = ind.targetGlow
    local showGlow = targeted and fx.enabled and (fx.glowOn ~= false or fx.marksOn)
    SetGlow(f.health, fx, showGlow, f)
    f.health.azEmbers:SetShown(targeted and bs ~= "modern" and f.health:IsShown() or false)
    local thCfg = db.colors and db.colors.threat
    local thOn = thCfg and thCfg.enabled and (not thCfg.instancesOnly or NP.inInstance or f.isPreview)
    local showOn = (thCfg and thCfg.showOn) or "border"
    local bsz = max(0.5, tonumber(thCfg and thCfg.borderSize) or 1.5)
    local haloMode = (showOn == "halo")

    local hasAggro = false
    local aggroCol = threatCol
    if thOn and (showOn == "border" or haloMode) then
        if f.isPreview then
            hasAggro = f.azPreviewAggro and true or false
            aggroCol = (thCfg.role == "tank" and thCfg.tank and thCfg.tank.noaggro) or (thCfg.dps and thCfg.dps.aggro)
        elseif aggroCol then
            hasAggro = true
        elseif f.unit and (f.kind == "enemynpc" or f.kind == "enemyplayer") then
            local ok, c = pcall(NP.GetThreatColor, f.unit, thCfg)
            if ok and c then
                hasAggro = true
                aggroCol = c
            end
        end
    end
    aggroCol = aggroCol or { 0.95, 0.16, 0.14, 0.90 }

    local ar, ag, ab = aggroCol[1] or 0.95, aggroCol[2] or 0.16, aggroCol[3] or 0.14
    local glowPad = max(2, bsz * 2.5)
    f.health.azAggro:ClearAllPoints()
    f.health.azAggro:SetPoint("TOPLEFT", f.health, "TOPLEFT", -glowPad, glowPad)
    f.health.azAggro:SetPoint("BOTTOMRIGHT", f.health, "BOTTOMRIGHT", glowPad, -glowPad)
    f.health.azAggro:SetVertexColor(ar, ag, ab, 1)

    if f.health.azAggroHalo then f.health.azAggroHalo:SetShown(false) end
    if f.health.azAggroGlow then f.health.azAggroGlow:SetShown(false) end

    if haloMode then
        f.health.azAggro:SetShown(false)
        f.health.azAggroRim:SetShown(false)
        if hasAggro then
            local shape = thCfg.haloShape or "round"
            local hsz = tonumber(thCfg.haloSize) or 3
            local hal = tonumber(thCfg.haloAlpha) or 0.85
            local hc = { ar, ag, ab, 1 }
            if shape == "round" then
                f.health.azAggroHalo = f.health.azAggroHalo or NP.CreateHalo(f.health)
                f.health.azAggroHalo:Setup(hc, hsz, hal, 0)
                f.health.azAggroHalo:SetShown(true)
            else
                f.health.azAggroGlow = f.health.azAggroGlow or NP.CreateGlow(f.health, f.health, "BACKGROUND", -7)
                f.health.azAggroGlow:Setup(hc, hsz, hal, 0)
                f.health.azAggroGlow:SetShown(true)
            end
        end
    elseif bs == "bdo" then
        f.health.azAggro:SetShown(hasAggro)
        f.health.azAggroRim:SetShown(false)
    elseif bs == "bdo_pill" or bs == "azaath" or bs == "azaath_ink" then
        f.health.azAggro:SetShown(hasAggro)
        f.health.azAggroRim:SetBorderSize(bsz)
        f.health.azAggroRim:SetBorderColor(ar, ag, ab, 1)
        f.health.azAggroRim:SetShown(hasAggro)
    else
        f.health.azAggro:SetShown(hasAggro)
        f.health.azAggroRim:SetShown(false)
        if hasAggro then
            f.health.border:SetBorderSize(bsz)
            f.health.border:SetBorderColor(ar, ag, ab, 1)
        end
    end
    f.health.selection:SetShown(targeted and ind.targetOverlay.enabled)
    f.health.focusOverlay:SetShown(f.isFocus and ind.focusOverlay.enabled and f.health:IsShown() or false)
    f.health.hover:SetShown(f.isMouseover and ind.hover.enabled and f.health:IsShown() or false)
end

function Health:Update(f)
    if f.cfg.mode == "nameOnly" then
        f.health:Hide()
        if f.health.targetFx then f.health.targetFx:Hide() end
        return
    end
    UpdateValues(f, false)
    NP.UpdateHealthColor(f)
    if NP.UpdateExecute then NP.UpdateExecute(f) end
    if NP.DotKill then NP.DotKill.Update(f) end
end

function Health:OnHealth(f)
    if f.cfg.mode == "nameOnly" then return end
    UpdateValues(f, true)
    if NP.UpdateExecute then NP.UpdateExecute(f) end
    if NP.DotKill then NP.DotKill.Update(f) end
end

function Health:OnThreat(f)
    NP.UpdateHealthColor(f)
    if NP.UpdateNameText then NP.UpdateNameText(f) end
end

function Health:OnTargetChanged(f)
    NP.UpdateHealthBorder(f)
end

function Health:Clear(f)
    if f.health.targetFx then f.health.targetFx:Hide() end
    if f.health.azAggro then f.health.azAggro:Hide() end
    if f.health.azAggroRim then f.health.azAggroRim:SetShown(false) end
    if f.health.azAggroHalo then f.health.azAggroHalo:SetShown(false) end
    if f.health.azAggroGlow then f.health.azAggroGlow:SetShown(false) end
    if f.health.selection then f.health.selection:Hide() end
    if f.health.focusOverlay then f.health.focusOverlay:Hide() end
    if f.health.hover then f.health.hover:Hide() end
    if NP.ClearExecute then NP.ClearExecute(f) end
    if NP.DotKill then NP.DotKill.Clear(f) end
end

function Health:WantsEvent(f)
    return f.cfg.mode ~= "nameOnly"
end

Health.unitEvents = {
    UNIT_HEALTH                  = "OnHealth",
    UNIT_MAXHEALTH               = "OnHealth",
    UNIT_ABSORB_AMOUNT_CHANGED   = "OnHealth",
    UNIT_HEAL_PREDICTION         = "OnHealth",
    UNIT_THREAT_LIST_UPDATE      = "OnThreat",
    UNIT_THREAT_SITUATION_UPDATE = "OnThreat",
    UNIT_TARGET                  = "OnThreat",
}

function Health:Preview(f, st)
    if f.cfg.mode == "nameOnly" then Health:Clear(f); return end
    local db = NP.Prof(f)
    local hb = f.health
    hb:SetMinMaxValues(0, 100)
    hb:SetValue(st.dots and 71 or (st.execute and 18 or 72))

    local col
    local th = db.colors and db.colors.threat
    if st.aggro and th and th.enabled and th.showOn == "bar" and f.kind == "enemynpc" then
        col = (th.role == "tank" and th.tank and th.tank.noaggro) or (th.dps and th.dps.aggro)
    elseif st.colorMode == "class" and (f.kind == "enemyplayer" or f.kind == "friendlyplayer") then
        col = NP.CLASS_COLORS.MAGE or { 0.25, 0.78, 0.92, 1 }
    elseif st.colorMode == "boss" then
        col = db.colors.unitType.boss
    elseif st.colorMode == "caster" then
        col = db.colors.caster.color
    elseif st.colorMode == "quest" then
        col = db.colors.quest.hostile
    elseif st.colorMode == "threat" then
        col = db.colors.threat.dps.aggro
    else
        col = f.kind:find("friendly") and db.colors.reaction.friendly or db.colors.reaction.hostile
    end
    NP.SetHealthFillColor(hb, NP.RGBA(col))

    hb.heal:SetMinMaxValues(0, 100)
    hb.heal:SetValue(NP.HealPredictionOn(f) and 10 or 0)
    local ab = db.style.absorbs
    local showAb = ab.enabled and st.absorb and true or false
    local abVal = showAb and 18 or 0
    hb.absorb:SetMinMaxValues(0, 100); hb.absorb:SetValue(abVal)
    hb.absorb:SetShown(showAb and ab.position ~= "over")
    hb.absorbOver:SetMinMaxValues(0, 100); hb.absorbOver:SetValue(ab.position == "over" and abVal or 0)
    hb.absorbOver:SetShown(showAb and ab.position == "over")

    f.isTarget, f.isFocus = st.target, st.focus
    f.azPreviewAggro = st.aggro and true or false
    NP.UpdateHealthBorder(f)
    if NP.PreviewExecute then NP.PreviewExecute(f, st) end
    if NP.DotKill then NP.DotKill.Preview(f, st.dots) end
end

NP.RegisterElement("Health", Health)
