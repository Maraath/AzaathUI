--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Compass.lua
    Bússola horizontal no topo central, na linguagem visual de Azaath:
    linha fina sem fundo, números a cada 15°, letras cardeais com serifa (Cinzel)
    e uma placa dourada central com o nome da subzona em maiúsculas espaçadas.

    * GetPlayerFacing() (3.3.5a) retorna radianos: 0 = Norte, crescendo no sentido
      ANTI-horário (pi/2 = Oeste). Convertemos para rumo de bússola em graus
      no sentido horário: heading = (360 - deg(facing)) % 360.
    * OnUpdate com throttle (0.03s–0.05s) e atualização só quando o rumo muda.
    * Sem SetClipsChildren na 3.3.5: marcadores fora da área são escondidos à mão,
      com fade nas bordas.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("Compass")

local GetPlayerFacing = GetPlayerFacing
local abs, floor = math.abs, math.floor
local RAD2DEG = 180 / math.pi

local CARDINALS = {
    [0] = "N", [45] = "NE", [90] = "E", [135] = "SE",
    [180] = "S", [225] = "SW", [270] = "W", [315] = "NW",
}
local STEP         = 15   -- números e tracinhos a cada 15°
local LINE_Y       = 9    -- altura da linha a partir da base do frame
local EDGE_PADDING = 18   -- px escondidos em cada ponta (evita texto cortado)
local PLAQUE_W, PLAQUE_H = 300, 18
local MIN_INTERVAL, MAX_INTERVAL = 0.03, 0.05
local HEADING_EPSILON = 0.1 -- graus; abaixo disso não reposiciona nada

-- Estado local (upvalues = acesso rápido dentro do OnUpdate)
local frame, degreeText, plaque, zoneText, wpPin, wpText
local markers = {}
local heading, lastHeading, lastDegree = 0, nil, nil
local half, pxPerDegree = 0, 0
local interval, accumulator = 0.04, 0

local function Clamp(v, lo, hi)
    if v < lo then return lo elseif v > hi then return hi end
    return v
end

--------------------------------------------------------------------------------
-- Construção visual
--------------------------------------------------------------------------------
-- Faixa horizontal em duas metades com degradê de alpha (transparente nas pontas).
local function CreateFadedStrip(parent, layer, r, g, b, a)
    local blank = Azaath.media.blank
    local left = parent:CreateTexture(nil, layer)
    left:SetTexture(blank)
    Azaath.Gradient(left, "HORIZONTAL", r, g, b, 0, r, g, b, a)
    local right = parent:CreateTexture(nil, layer)
    right:SetTexture(blank)
    Azaath.Gradient(right, "HORIZONTAL", r, g, b, a, r, g, b, 0)
    return left, right
end

-- Ancora as duas metades de uma faixa horizontal de altura h, na altura y do frame
local function PlaceStrip(left, right, parent, y, h)
    left:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, y)
    left:SetPoint("BOTTOMRIGHT", parent, "BOTTOM", 0, y)
    left:SetHeight(h)
    right:SetPoint("BOTTOMLEFT", parent, "BOTTOM", 0, y)
    right:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, y)
    right:SetHeight(h)
end

local function AddMarker(angle, region, anchor, y, alpha)
    markers[#markers + 1] = {
        angle  = angle,
        region = region,
        anchor = anchor,
        y      = y,
        alpha  = alpha or 1,
        shown  = true,
    }
end

local function CreateLabel(parent, text, font, size, color, outline)
    local fs = parent:CreateFontString(nil, "ARTWORK")
    fs:SetFont(font, size, outline or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetTextColor(color[1], color[2], color[3])
    fs:SetText(text)
    return fs
end

function M:Build()
    local c, media = Azaath.colors, Azaath.media
    frame = CreateFrame("Frame", "AzaathUICompass", Azaath.root)
    frame:SetFrameStrata("LOW")

    -- Linha fina, clara, esmaecendo nas pontas
    local lineL, lineR = CreateFadedStrip(frame, "BORDER", c.cream[1], c.cream[2], c.cream[3], 0.55)
    PlaceStrip(lineL, lineR, frame, LINE_Y, 1)

    -- Marcadores: letras cardeais (Cinzel) e números a cada 15° com tracinho
    for angle = 0, 360 - STEP, STEP do
        local label = CARDINALS[angle]
        if label then
            local primary = (angle % 90 == 0)
            local fs = CreateLabel(frame, label, media.fontTitle, primary and 19 or 14, c.cream)
            AddMarker(angle, fs, "BOTTOM", LINE_Y + 3, primary and 1 or 0.85)
        else
            local fs = CreateLabel(frame, tostring(angle), media.font, 11, c.dim)
            AddMarker(angle, fs, "BOTTOM", LINE_Y + 4, 0.8)
            local tick = frame:CreateTexture(nil, "ARTWORK")
            tick:SetTexture(media.blank)
            tick:SetVertexColor(c.cream[1], c.cream[2], c.cream[3])
            tick:SetWidth(1)
            tick:SetHeight(4)
            AddMarker(angle, tick, "BOTTOM", LINE_Y - 2, 0.6)
        end
    end

    -- Marcador central: pequeno entalhe dourado cruzando a linha
    local notch = frame:CreateTexture(nil, "OVERLAY")
    notch:SetTexture(media.blank)
    notch:SetVertexColor(c.accent[1], c.accent[2], c.accent[3])
    notch:SetWidth(2)
    notch:SetHeight(7)
    notch:SetPoint("BOTTOM", frame, "BOTTOM", 0, LINE_Y - 3)

    -- Marcador de destino personalizado (colocado no Mapa Azaath com clique direito)
    wpPin = CreateFrame("Frame", nil, frame)
    wpPin:SetWidth(18)
    wpPin:SetHeight(18)
    local wpOuter = wpPin:CreateTexture(nil, "OVERLAY")
    wpOuter:SetTexture(media.path .. "Diamond")
    wpOuter:SetAllPoints(wpPin)
    wpOuter:SetVertexColor(c.accent[1], c.accent[2], c.accent[3], 1)
    local wpInner = wpPin:CreateTexture(nil, "OVERLAY")
    wpInner:SetTexture(media.path .. "Diamond")
    wpInner:SetWidth(8)
    wpInner:SetHeight(8)
    wpInner:SetPoint("CENTER", wpPin, "CENTER", 0, 0)
    wpInner:SetVertexColor(c.dark[1], c.dark[2], c.dark[3], 1)
    wpText = CreateLabel(wpPin, "", media.font, 10, c.accent, "OUTLINE")
    wpText:SetPoint("BOTTOM", wpPin, "TOP", 0, 1)
    wpPin:Hide()

    -- Placa dourada com o nome da subzona (abaixo da linha)
    plaque = CreateFrame("Frame", nil, frame)
    plaque:SetWidth(PLAQUE_W)
    plaque:SetHeight(PLAQUE_H)
    plaque:SetPoint("TOP", frame, "BOTTOM", 0, 2)
    local g = c.gold
    local bgL, bgR = CreateFadedStrip(plaque, "BACKGROUND", g[1], g[2], g[3], 0.92)
    PlaceStrip(bgL, bgR, plaque, 0, PLAQUE_H)
    -- brilho superior e sombra inferior dão o aspecto de placa metálica
    local hiL, hiR = CreateFadedStrip(plaque, "BORDER", 1, 0.95, 0.8, 0.55)
    PlaceStrip(hiL, hiR, plaque, PLAQUE_H - 1, 1)
    local loL, loR = CreateFadedStrip(plaque, "BORDER", 0.25, 0.18, 0.08, 0.7)
    PlaceStrip(loL, loR, plaque, 0, 1)

    zoneText = plaque:CreateFontString(nil, "OVERLAY")
    zoneText:SetFont(media.fontTitleB, 11, "")
    zoneText:SetTextColor(0.13, 0.10, 0.06)
    zoneText:SetShadowOffset(0, -1)
    zoneText:SetShadowColor(1, 0.95, 0.8, 0.35)
    zoneText:SetPoint("CENTER", plaque, "CENTER", 0, 0)

    -- Rumo numérico (opcional) abaixo da placa
    degreeText = frame:CreateFontString(nil, "OVERLAY")
    degreeText:SetFont(media.font, 11, "OUTLINE")
    degreeText:SetTextColor(c.dim[1], c.dim[2], c.dim[3])
    degreeText:SetPoint("TOP", plaque, "BOTTOM", 0, -3)

    frame:SetScript("OnUpdate", function(_, elapsed)
        accumulator = accumulator + elapsed
        if accumulator < interval then return end
        accumulator = 0
        M:UpdateHeading()
    end)

    frame:SetScript("OnShow", function()
        accumulator = 0
        M:UpdateHeading(true)
        M:UpdateZone()
    end)

    frame:SetScript("OnEvent", function() M:UpdateZone() end)
    Azaath.SafeRegister(frame, "ZONE_CHANGED")
    Azaath.SafeRegister(frame, "ZONE_CHANGED_INDOORS")
    Azaath.SafeRegister(frame, "ZONE_CHANGED_NEW_AREA")
    Azaath.SafeRegister(frame, "PLAYER_ENTERING_WORLD")

    self:ApplyLayout()
    self:UpdateZone()
end

--------------------------------------------------------------------------------
-- Layout / configuração
--------------------------------------------------------------------------------
function M:ApplyLayout()
    if not frame then return end
    local db = self.db

    local width = Clamp(db.width, 200, 1400)
    local fov   = Clamp(db.fov, 90, 360)
    interval    = Clamp(db.interval, MIN_INTERVAL, MAX_INTERVAL)

    frame:SetWidth(width)
    frame:SetHeight(Clamp(db.height, 18, 64))
    frame:SetScale((db.scale and db.scale > 0) and db.scale or 1)
    frame:ClearAllPoints()
    frame:SetPoint("TOP", Azaath.root, "TOP", db.offsetX or 0, db.offsetY or -10)
    if Azaath.ClampToScreen then Azaath.ClampToScreen(frame) end

    half        = width / 2
    pxPerDegree = width / fov

    if db.showDegrees then degreeText:Show() else degreeText:Hide() end
    self:UpdateZone()
    self:UpdateHeading(true)
end

function M:UpdateZone()
    if not plaque then return end
    local zone = GetMinimapZoneText and GetMinimapZoneText() or ""
    if self.db.showZone and zone ~= "" then
        zoneText:SetText(Azaath.Tracked(zone))
        -- a placa cresce com nomes longos, sem passar da largura da bússola
        plaque:SetWidth(Clamp(zoneText:GetStringWidth() + 140, PLAQUE_W, half * 2))
        plaque:Show()
    else
        plaque:Hide()
    end
end

--------------------------------------------------------------------------------
-- Atualização (caminho quente)
--------------------------------------------------------------------------------
local function UpdateMarkers()
    local limit = half - EDGE_PADDING
    for i = 1, #markers do
        local m = markers[i]
        -- Diferença angular em [-180, 180): positivo = à direita do jogador
        local delta = (m.angle - heading + 540) % 360 - 180
        local x = delta * pxPerDegree
        local ax = abs(x)
        if ax > limit then
            if m.shown then
                m.region:Hide()
                m.shown = false
            end
        else
            local t = ax / half
            m.region:SetPoint(m.anchor, frame, m.anchor, x, m.y)
            m.region:SetAlpha(m.alpha * (1 - t * t)) -- fade suave em direção às pontas
            if not m.shown then
                m.region:Show()
                m.shown = true
            end
        end
    end
end

local function UpdateWaypointMarker()
    if not wpPin then return end
    local wpAngle, wpDist
    local wm = Azaath:GetModule("WorldMap")
    if wm and wm.GetActiveWaypointVector then
        wpAngle, wpDist = wm:GetActiveWaypointVector()
    end
    if not wpAngle then
        local qn = Azaath:GetModule("QuestNav")
        if qn and qn.GetCompassVector then
            wpAngle, wpDist = qn:GetCompassVector()
        end
    end
    if not wpAngle then
        wpPin:Hide()
        return
    end
    local limit = half - EDGE_PADDING
    local delta = (wpAngle - heading + 540) % 360 - 180
    local x = Clamp(delta * pxPerDegree, -limit, limit)
    wpPin:ClearAllPoints()
    wpPin:SetPoint("CENTER", frame, "BOTTOM", x, LINE_Y + 9)
    wpText:SetText(wpDist and string.format("%d m", floor(wpDist + 0.5)) or "")
    wpPin:Show()
end

function M:UpdateHeading(force)
    if not frame then return end
    local facing = GetPlayerFacing()
    if not facing then return end -- pode ser nil em telas de carregamento

    local h = (360 - facing * RAD2DEG) % 360
    local headingChanged = force or not lastHeading or abs(h - lastHeading) >= HEADING_EPSILON
    if headingChanged then
        heading, lastHeading = h, h
        UpdateMarkers()
        if self.db.showDegrees then
            local d = floor(h + 0.5) % 360
            if d ~= lastDegree or force then
                lastDegree = d
                degreeText:SetText(d .. "°")
            end
        end
    end
    UpdateWaypointMarker()
end

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:SetEnabled(enabled)
    self.db.enabled = enabled and true or false
    if self.db.enabled then
        if not frame then self:Build() end
        frame:Show()
    elseif frame then
        frame:Hide() -- oculto => OnUpdate deixa de rodar (custo zero)
    end
end

function M:OnInitialize()
    self.db = Azaath.db.compass
end

function M:OnEnable()
    if self.db.enabled then
        self:SetEnabled(true)
    end
end
