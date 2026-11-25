--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Minimap.lua
    Minimapa limpo no canto superior direito (3.3.5a).

      * Redondo (padrão) com anel dourado duplo e halo escuro, ou quadrado com
        borda fina. Texturas próprias em Media/ (geradas por tools/media/generate-media.js).
      * Skin Azaath Classic (redondo): "Portulano" — cartão de pergaminho
        com rumos, anel graduado, lírio no norte e rosa dos ventos (ver PORTOLAN).
      * Abaixo: nome da zona (cor pelo tipo de PvP), coordenadas e relógio.
      * Canto superior esquerdo: dificuldade da instância (5N, 5H, 10N, 25H...).
      * Marcador "N" no anel; com o minimapa giratório ligado (rotateMinimap),
        ele acompanha a câmera.
      * Roda do mouse = zoom · clique direito = menu de rastreamento (próprio,
        sem UIDropDownMenu — ver nota de taint abaixo) · clique do meio =
        calendário · clique esquerdo = ping (padrão).

    Integração:
      * O HideBlizz já ocultou o MinimapCluster (zoom, rastreamento, relógio,
        mapa-múndi...). Aqui só o frame Minimap é reparentado para o nosso
        contêiner — Minimap e MinimapCluster não são protegidos.
      * O MinimapCluster oculto é deslocado para baixo do nosso bloco: o
        rastreador de missões (WatchFrame), o indicador de assentos de veículo
        e o de durabilidade se ancoram nele e assim não ficam por cima.
      * Indicadores resgatados (fila BG/LFG, correio) vão para o canto inferior
        esquerdo do mapa; os buffs do jogador se ancoram à esquerda dele.
------------------------------------------------------------------------------]]

local ADDON_NAME, Azaath = ...
local M = Azaath:NewModule("Minimap")

local _G = _G
local sin, cos, max, abs, sqrt, format, date = math.sin, math.cos, math.max, math.abs, math.sqrt, string.format, date
local GetPlayerFacing = GetPlayerFacing
local API = Azaath.API

local MEDIA       = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
-- Máscara redonda: no cliente moderno o caminho "Textures\\MinimapMask" não é
-- garantido; a máscara circular de retrato é a usada pelos addons atuais.
local ROUND_MASK  = Azaath.IS_MODERN and "Interface\\CharacterFrame\\TempPortraitAlphaMask"
                    or "Textures\\MinimapMask"
local SQUARE_MASK = "Interface\\Buttons\\WHITE8X8"
local RING_SCALE  = 1.06 -- a textura do anel é desenhada 6% maior que o mapa
local GLOW_SCALE  = 1.25
local TEXT_BLOCK  = 40   -- altura aproximada de zona + coordenadas/relógio

local INFO_INTERVAL  = 0.2  -- coordenadas, relógio, estado do rotateMinimap
local NORTH_INTERVAL = 0.05 -- marcador "N" (só quando o minimapa gira)

local PVP_COLORS = {
    sanctuary = { 0.41, 0.80, 0.94 },
    arena     = { 1.00, 0.25, 0.25 },
    friendly  = { 0.35, 0.90, 0.35 },
    hostile   = { 1.00, 0.25, 0.25 },
    contested = { 1.00, 0.70, 0.10 },
    combat    = { 1.00, 0.25, 0.25 },
}

-- Skin Azaath Classic: minimapa "Portulano" (carta náutica). Cartão de
-- pergaminho com rede de rumos atrás do mapa, anel com escala de graus, lírio
-- no norte e rosa dos ventos no canto inferior direito. Texturas coloridas em
-- Media/Minimap (tools/media/generate-minimap-classic-media.js); as medidas abaixo,
-- em "tamanhos de mapa", precisam bater com as do gerador.
local PORTOLAN = {
    cardW = 1.36, cardH = 1.66,   -- cartão
    mapX  = 0.68, mapY  = 0.68,   -- centro do mapa dentro do cartão
    ring  = 1.22,                 -- diâmetro exibido da textura do anel
    roseX = 1.14, roseY = 1.42, rose = 0.405,
    fleur = 0.12, northR = 0.57,  -- lírio e raio em que ele corre
    textX = 0.09,                 -- margem esquerda do texto
    zoneY = 1.285,                -- topo do nome da zona (a régua fica em 1.395)
    infoY = 1.415,                -- topo da linha de coordenadas/relógio
    clockX = 0.90,                -- borda direita do relógio
}
-- Tinta das cores de PvP (as originais somem no pergaminho)
local INK_PVP = {
    sanctuary = { 0.10, 0.30, 0.44 },
    arena     = { 0.55, 0.12, 0.08 },
    friendly  = { 0.17, 0.35, 0.11 },
    hostile   = { 0.55, 0.12, 0.08 },
    contested = { 0.55, 0.32, 0.04 },
    combat    = { 0.55, 0.12, 0.08 },
}
local INK       = { 0.18, 0.14, 0.08 }
local INK_SOFT  = { 0.33, 0.27, 0.17 }
local INK_RED   = { 0.54, 0.20, 0.14 }

local holder, zoneText, coordText, clockText, diffText, north, northBacking
local round, northRadius, portolan
local rotating, lastAngle = false, nil
local lastClock

--------------------------------------------------------------------------------
-- Utilitários
--------------------------------------------------------------------------------
local function CreateText(parent, size, layer)
    local c = Azaath.colors.cream
    local fs = parent:CreateFontString(nil, layer or "OVERLAY", "GameFontNormal")
    local fontPath = Azaath.media and Azaath.media.font or "Fonts\\ARIALN.TTF"
    local ok = pcall(fs.SetFont, fs, fontPath, size, "OUTLINE")
    if not ok or not fs:GetFont() then
        fs:SetFont("Fonts\\ARIALN.TTF", size, "OUTLINE")
    end
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    fs:SetTextColor(c[1], c[2], c[3])
    fs.azSize = size
    return fs
end

-- Alterna a tipografia de um texto entre a HUD (contorno, fonte limpa) e a
-- tinta do portulano (serifa, sem contorno)
local function StyleText(fs, ink, italic, inkSize)
    if not fs then return end
    local m = Azaath.media or {}
    local font, size, flags
    if ink then
        font = (italic and m.fontItalic) or m.fontTitle or m.font
        size, flags = inkSize or fs.azSize or 11, ""
    else
        font, size, flags = m.font, fs.azSize or 11, "OUTLINE"
    end
    local ok = pcall(fs.SetFont, fs, font or "Fonts\\ARIALN.TTF", size, flags)
    if not ok or not fs:GetFont() then fs:SetFont("Fonts\\ARIALN.TTF", size, flags) end
    if ink then
        fs:SetShadowOffset(0, 0)
        fs:SetShadowColor(0, 0, 0, 0)
    else
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 0.8)
    end
end

local function UsePortolan()
    return false -- o antigo portulano redondo foi substituído pelo minimapa quadrado estilo Guild Wars 2
end

-- Coloca os indicadores resgatados pelo HideBlizz junto ao minimapa.
-- Também chamada pelo HideBlizz quando ele roda depois deste módulo
-- (ex.: /reload em combate adia o HideBlizz).
function Azaath.AnchorIndicators(indicators)
    local mm = _G.AzaathUIMinimap
    if not (mm and indicators) then return false end
    indicators:ClearAllPoints()
    if portolan then
        -- por fora da borda esquerda do pergaminho, à altura da base do mapa
        local size = mm:GetHeight()
        local leftOffset = -(PORTOLAN.mapX - 0.5) * size - 6
        indicators:SetPoint("TOPRIGHT", mm, "TOPLEFT", leftOffset, -(size * 0.85))
    elseif round then
        -- canto inferior esquerdo do quadrado, fora do círculo
        indicators:SetPoint("TOPRIGHT", mm, "BOTTOMLEFT", 12, 12)
    else
        indicators:SetPoint("TOPRIGHT", mm, "BOTTOMLEFT", -6, 24)
    end
    return true
end

--------------------------------------------------------------------------------
-- Atualizações
--------------------------------------------------------------------------------
local function UpdateZone()
    local pvp = API.ZonePVPInfo()
    local col
    if portolan then
        col = INK_PVP[pvp or ""] or INK
    else
        col = PVP_COLORS[pvp or ""] or Azaath.colors.cream
    end
    zoneText:SetText(GetMinimapZoneText() or "")
    zoneText:SetTextColor(col[1], col[2], col[3])
end

local function UpdateDifficulty()
    local _, instanceType, difficulty, _, maxPlayers = GetInstanceInfo()
    if (instanceType == "party" or instanceType == "raid") and maxPlayers and maxPlayers > 0 then
        local heroic = (instanceType == "party" and difficulty == 2)
                    or (instanceType == "raid" and difficulty and difficulty >= 3)
        diffText:SetText(maxPlayers .. (heroic and "H" or "N"))
        local col
        if portolan then
            col = heroic and INK_RED or INK
        else
            col = heroic and Azaath.colors.accent or Azaath.colors.gold
        end
        diffText:SetTextColor(col[1], col[2], col[3])
    else
        diffText:SetText("")
    end
end

-- Mantém o mapa atual sincronizado para GetPlayerMapPosition, sem atrapalhar
-- quem está navegando no mapa-múndi.
local function SyncMapZone()
    -- só a 3.3.5 precisa: o cliente moderno consulta o mapa do jogador (C_Map)
    local wm = Azaath:GetModule("WorldMap")
    local mapOpen = (WorldMapFrame and WorldMapFrame:IsShown()) or (wm and wm.IsOpen and wm:IsOpen())
    if API.NeedsMapSync and not mapOpen then
        SetMapToCurrentZone()
    end
end

local function UpdateCoords()
    if not coordText then return end
    local x, y = API.PlayerMapPosition()
    if x and y and (x > 0 or y > 0) then
        coordText:SetText(format("%.1f, %.1f", x * 100, y * 100))
    else
        coordText:SetText("--") -- instâncias / mapas sem coordenadas
    end
end

local function UpdateClock()
    if not clockText then return end
    local t = date("%H:%M")
    if t ~= lastClock then
        lastClock = t
        clockText:SetText(t)
    end
end

local function UpdateNorth(force)
    local angle = 0
    if rotating then
        angle = GetPlayerFacing() or 0
    end
    if not force and angle == lastAngle then return end
    lastAngle = angle
    local x, y
    if round then
        x, y = northRadius * sin(angle), northRadius * cos(angle)
    else
        -- Projeção do ângulo no perímetro do quadrado (estilo bússola GW2)
        local dx, dy = sin(angle), cos(angle)
        local m = max(abs(dx), abs(dy))
        if m > 0.001 then
            local scale = northRadius / m
            x, y = dx * scale, dy * scale
        else
            x, y = 0, northRadius
        end
    end
    north:SetPoint("CENTER", holder, "CENTER", x, y)
    northBacking:SetPoint("CENTER", holder, "CENTER", x, y)
    if holder.pFleur then
        holder.pFleur:SetPoint("CENTER", holder, "CENTER", x, y)
        -- a rosa gira junto (SetRotation gira no sentido anti-horário)
        local rose = holder.pRose
        if rose and rose.SetRotation then pcall(rose.SetRotation, rose, -angle) end
    end
end

local ZOOM_YARDS = { [0] = 300, [1] = 240, [2] = 180, [3] = 120, [4] = 80, [5] = 50 }
local mmPathOverlay, mmPathDots = nil, {}

local function UpdateMagicMinimap()
    local qn = Azaath:GetModule("QuestNav")
    local mp = qn and qn.GetMagicPath and qn:GetMagicPath()
    if not (mp and mp.nodes and #mp.nodes >= 2 and _G.UnitPosition and Minimap and Minimap:IsVisible()) then
        for i = 1, #mmPathDots do mmPathDots[i]:Hide() end
        return
    end
    local pwx, pwy = _G.UnitPosition("player")
    if not (pwx and pwy) then
        for i = 1, #mmPathDots do mmPathDots[i]:Hide() end
        return
    end
    if not mmPathOverlay then
        mmPathOverlay = CreateFrame("Frame", nil, Minimap)
        mmPathOverlay:SetAllPoints(Minimap)
        mmPathOverlay:SetFrameLevel((Minimap:GetFrameLevel() or 2) + 3)
    end
    local halfW = (Minimap:GetWidth() or 160) * 0.5
    local halfH = (Minimap:GetHeight() or 160) * 0.5
    local radiusYds = (_G.C_Minimap and _G.C_Minimap.GetViewRadius and _G.C_Minimap.GetViewRadius())
                   or ZOOM_YARDS[Minimap:GetZoom() or 0] or 180
    local scale = halfW / radiusYds
    local cosF, sinF = 1, 0
    if rotating and _G.GetPlayerFacing then
        local f = _G.GetPlayerFacing()
        if f then cosF, sinF = math.cos(f), math.sin(f) end
    end

    local dotTex = Azaath.media.path .. "MapFrame\\Dot.tga"
    local spacingYds = 26
    local now = GetTime()
    local phase = (now % 1.1) / 1.1
    local carry = phase * spacingYds
    local count, maxDots = 0, 48

    for i = 1, #mp.nodes - 1 do
        local a, b = mp.nodes[i], mp.nodes[i + 1]
        local dx = b.wx - a.wx
        local dy = b.wy - a.wy
        local segLen = math.sqrt(dx * dx + dy * dy)
        if segLen > 0.1 then
            local pos = carry
            while pos <= segLen do
                local frac = pos / segLen
                local wx = a.wx + dx * frac
                local wy = a.wy + dy * frac
                local dEast = -(wy - pwy)
                local dNorth = wx - pwx
                local rx, ry
                if rotating then
                    rx = (dEast * cosF - dNorth * sinF) * scale
                    ry = (dEast * sinF + dNorth * cosF) * scale
                else
                    rx = dEast * scale
                    ry = dNorth * scale
                end
                if math.abs(rx) <= halfW - 6 and math.abs(ry) <= halfH - 6 then
                    local r2 = rx * rx + ry * ry
                    count = count + 1
                    if count > maxDots then break end
                    local dot = mmPathDots[count]
                    if not dot then
                        dot = mmPathOverlay:CreateTexture(nil, "OVERLAY")
                        dot:SetTexture(dotTex)
                        dot:SetBlendMode("ADD")
                        mmPathDots[count] = dot
                    end
                    local wave = 0.5 + 0.5 * math.sin(now * 5.0 - count * 0.55)
                    local sz = 5 + wave * 2.2
                    dot:SetSize(sz, sz)
                    dot:ClearAllPoints()
                    dot:SetPoint("CENTER", mmPathOverlay, "CENTER", rx, ry)
                    dot:SetVertexColor(0.45 + 0.55 * wave, 0.90, 0.55 + 0.45 * (1 - wave))
                    dot:SetAlpha(r2 < 144 and 0.35 or (0.68 + 0.32 * wave))
                    dot:Show()
                end
                pos = pos + spacingYds
            end
            carry = pos - segLen
            if count >= maxDots then break end
        end
    end
    for i = count + 1, #mmPathDots do mmPathDots[i]:Hide() end
end

local function OnUpdate(self, elapsed)
    self.infoElapsed = self.infoElapsed + elapsed
    if self.infoElapsed >= INFO_INTERVAL then
        self.infoElapsed = 0
        UpdateCoords()
        UpdateClock()
        local nowRotating = GetCVar("rotateMinimap") == "1"
        if nowRotating ~= rotating then
            rotating = nowRotating
            UpdateNorth(true)
        end
    end
    if rotating then
        self.northElapsed = self.northElapsed + elapsed
        if self.northElapsed >= NORTH_INTERVAL then
            self.northElapsed = 0
            UpdateNorth()
        end
    end
    self.pathElapsed = (self.pathElapsed or 0) + elapsed
    if self.pathElapsed >= 0.05 then
        self.pathElapsed = 0
        UpdateMagicMinimap()
    end
end

--------------------------------------------------------------------------------
-- Interação
--------------------------------------------------------------------------------
local function Minimap_OnMouseWheel(self, delta)
    local zoom, levels = self:GetZoom(), self:GetZoomLevels()
    if delta > 0 and zoom < levels - 1 then
        self:SetZoom(zoom + 1)
    elseif delta < 0 and zoom > 0 then
        self:SetZoom(zoom - 1)
    end
end

local function OpenCalendar()
    if ToggleCalendar then ToggleCalendar() end
end

--------------------------------------------------------------------------------
-- Menu de rastreamento próprio
-- NÃO usamos ToggleDropDownMenu(MiniMapTrackingDropDown): abrir um
-- UIDropDownMenu a partir de código de addon contamina as globais
-- UIDROPDOWNMENU_* e, depois disso, "Definir foco" nos menus de unidade da
-- Blizzard (grupo/raide/chat) passa a ser bloqueado. GetTrackingInfo/SetTracking
-- não são protegidas, então um menu simples resolve sem taint.
--------------------------------------------------------------------------------
local trackingMenu
local TRACK_ROW, TRACK_WIDTH = 20, 200

local function RefreshTrackingMenu()
    if not (trackingMenu and trackingMenu:IsShown()) then return end
    local c = Azaath.colors
    local n = API.NumTracking()
    for i = 1, n do
        local row = trackingMenu.rows[i]
        if not row then
            row = CreateFrame("Button", nil, trackingMenu)
            row:SetHeight(TRACK_ROW)
            row:SetPoint("TOPLEFT", trackingMenu, "TOPLEFT", 6, -6 - (i - 1) * TRACK_ROW)
            row:SetPoint("TOPRIGHT", trackingMenu, "TOPRIGHT", -6, -6 - (i - 1) * TRACK_ROW)
            row:SetHighlightTexture(Azaath.media.blank)
            local hl = row:GetHighlightTexture()
            hl:SetVertexColor(1, 1, 1)
            hl:SetAlpha(0.08)

            row.check = row:CreateTexture(nil, "ARTWORK")
            row.check:SetTexture(Azaath.media.blank)
            row.check:SetVertexColor(c.accent[1], c.accent[2], c.accent[3])
            row.check:SetWidth(6)
            row.check:SetHeight(6)
            row.check:SetPoint("LEFT", row, "LEFT", 4, 0)

            row.icon = row:CreateTexture(nil, "ARTWORK")
            row.icon:SetWidth(14)
            row.icon:SetHeight(14)
            row.icon:SetPoint("LEFT", row, "LEFT", 16, 0)
            row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

            row.text = CreateText(row, 11)
            row.text:SetPoint("LEFT", row.icon, "RIGHT", 6, 0)
            row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
            row.text:SetJustifyH("LEFT")

            row:SetScript("OnClick", function(self)
                local _, _, active = API.TrackingInfo(self.id)
                -- rastreamentos de "spell" são exclusivos; os de "other"
                -- (estalajadeiro, mestre de voo...) somam. SetTracking cuida disso.
                API.SetTracking(self.id, not active)
                Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            end)
            trackingMenu.rows[i] = row
        end

        local name, texture, active = API.TrackingInfo(i)
        row.id = i
        row.icon:SetTexture(texture)
        row.text:SetText(name or "?")
        if active then
            row.check:Show()
            row.text:SetTextColor(1, 1, 1)
        else
            row.check:Hide()
            row.text:SetTextColor(c.dim[1], c.dim[2], c.dim[3])
        end
        row:Show()
    end
    for i = n + 1, #trackingMenu.rows do
        trackingMenu.rows[i]:Hide()
    end
    trackingMenu:SetHeight(12 + n * TRACK_ROW)
end

-- O global MouseIsOver não existe em todos os clientes: prefere o método do frame
local function IsOver(f)
    if f.IsMouseOver then return f:IsMouseOver() end
    if _G.MouseIsOver then return _G.MouseIsOver(f) end
    return false
end

local function TrackingMenu_OnUpdate(self, elapsed)
    -- Fecha sozinho quando o mouse fica fora do menu e do minimapa
    if IsOver(self) or IsOver(Minimap) then
        self.idle = 0
    else
        self.idle = self.idle + elapsed
        if self.idle > 1.5 then self:Hide() end
    end
end

local function ToggleTrackingMenu()
    if not trackingMenu then
        local c = Azaath.colors
        trackingMenu = CreateFrame("Frame", "AzaathUITrackingMenu", UIParent)
        trackingMenu:SetFrameStrata("DIALOG")
        trackingMenu:SetWidth(TRACK_WIDTH)
        trackingMenu:SetClampedToScreen(true)
        trackingMenu:EnableMouse(true)
        Azaath.SetBackdrop(trackingMenu, {
            bgFile = Azaath.media.blank, edgeFile = Azaath.media.blank, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        trackingMenu:SetBackdropColor(c.dark[1], c.dark[2], c.dark[3], 0.95)
        trackingMenu:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.6)
        trackingMenu.rows = {}
        trackingMenu.idle = 0
        trackingMenu:SetScript("OnUpdate", TrackingMenu_OnUpdate)
        trackingMenu:SetScript("OnShow", function(self) self.idle = 0 end)
        trackingMenu:Hide()
        tinsert(UISpecialFrames, "AzaathUITrackingMenu") -- fecha com ESC
    end

    if trackingMenu:IsShown() then
        trackingMenu:Hide()
        return
    end

    -- Abre no cursor, crescendo para a esquerda/baixo (o minimapa fica à direita)
    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    trackingMenu:ClearAllPoints()
    trackingMenu:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    trackingMenu:Show()
    RefreshTrackingMenu()
end

local function Minimap_OnMouseUp(self, button)
    if button == "RightButton" then
        ToggleTrackingMenu()
    elseif button == "MiddleButton" then
        OpenCalendar()
    elseif Minimap_OnClick then
        Minimap_OnClick(self) -- ping padrão (3.3.5)
    elseif self.PingLocation then
        -- cliente moderno: ping no ponto clicado, relativo ao centro do mapa
        local x, y = GetCursorPosition()
        local scale = self:GetEffectiveScale()
        x = x / scale - (self:GetLeft() + self:GetWidth() / 2)
        y = y / scale - (self:GetBottom() + self:GetHeight() / 2)
        self:PingLocation(x, y)
    end
end

local function HideTimeManagerButton()
    local b = _G.TimeManagerClockButton
    if b and Azaath.DisableBlizzardFrame then
        Azaath.DisableBlizzardFrame(b, { keepEvents = true }) -- mantém alarmes funcionando
    end
end

-- Posiciona um botão ao redor do minimapa a partir de um ângulo (radianos) e raio:
-- no modo redondo usa círculo; no quadrado projeta no perímetro reto do quadrado.
function Azaath.MinimapButtonOffset(angleRad, radius)
    local dx, dy = cos(angleRad), sin(angleRad)
    if round then
        return dx * radius, dy * radius
    end
    local m = max(abs(dx), abs(dy))
    if m > 0.001 then
        local s = radius / m
        return dx * s, dy * s
    end
    return radius, 0
end

local BLIZZ_MM_BUTTONS = {
    MinimapZoomIn = true, MinimapZoomOut = true,
    MiniMapTracking = true, MiniMapTrackingButton = true,
    MiniMapWorldMapButton = true, GameTimeFrame = true,
    MiniMapBattlefieldFrame = true, MiniMapMailFrame = true,
    QueueStatusMinimapButton = true,
    GarrisonLandingPageMinimapButton = true,
    ExpansionLandingPageMinimapButton = true,
    TimeManagerClockButton = true,
    OlhoAzaathMinimapButton = true,
}

local function LayoutAddonButtons()
    if not (Minimap and Minimap:GetWidth()) then return end
    local half = Minimap:GetWidth() / 2
    if half <= 0 then return end
    local targetR = half + 5

    if Azaath.OlhoNS and Azaath.OlhoNS.PlaceMinimapButton then
        Azaath.OlhoNS.PlaceMinimapButton()
    end

    local LDBI = _G.LibStub and _G.LibStub("LibDBIcon-1.0", true)
    if LDBI and LDBI.GetButtonList and LDBI.Refresh then
        for _, name in ipairs(LDBI:GetButtonList()) do
            pcall(LDBI.Refresh, LDBI, name)
        end
    end

    local mx, my = Minimap:GetCenter()
    if not (mx and my) then return end
    for _, child in ipairs({ Minimap:GetChildren() }) do
        if child and child.IsObjectType and child:IsObjectType("Button") and child:IsShown() then
            local name = child.GetName and child:GetName() or ""
            if not BLIZZ_MM_BUTTONS[name] then
                local w, h = child:GetWidth() or 0, child:GetHeight() or 0
                if w >= 18 and w <= 46 and h >= 18 and h <= 46 then
                    local bx, by = child:GetCenter()
                    if bx and by then
                        local dx, dy = bx - mx, by - my
                        local dist = sqrt(dx * dx + dy * dy)
                        if dist >= half * 0.45 and dist <= half * 1.65 then
                            local isLDBI = name:sub(1, 11) == "LibDBIcon10"
                            if not round then
                                if max(abs(dx), abs(dy)) < targetR - 1 then
                                    local m = max(abs(dx), abs(dy))
                                    if m > 0.001 then
                                        local s = targetR / m
                                        child:ClearAllPoints()
                                        child:SetPoint("CENTER", Minimap, "CENTER", dx * s, dy * s)
                                        if not isLDBI then child.azaathSquareAdjusted = true end
                                    end
                                end
                            elseif child.azaathSquareAdjusted then
                                child.azaathSquareAdjusted = nil
                                if dist > 0.001 then
                                    local s = targetR / dist
                                    child:ClearAllPoints()
                                    child:SetPoint("CENTER", Minimap, "CENTER", dx * s, dy * s)
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Construção
--------------------------------------------------------------------------------
local function IsRound(db)
    return (db and db.shape ~= "square")
end

local function BuildDecor(size)
    local c, blank = Azaath.colors, Azaath.media.blank
    local decor = CreateFrame("Frame", nil, holder)
    decor:SetAllPoints(holder)
    decor:SetFrameLevel(Minimap:GetFrameLevel() + 2)
    holder.decor = decor

    local glow = holder:CreateTexture(nil, "BACKGROUND")
    glow:SetTexture(MEDIA .. "Glow")
    glow:SetVertexColor(0, 0, 0)
    glow:SetAlpha(0.6)
    glow:SetWidth(size * GLOW_SCALE)
    glow:SetHeight(size * GLOW_SCALE)
    glow:SetPoint("CENTER", holder, "CENTER")
    holder.glow = glow

    local ring = decor:CreateTexture(nil, "ARTWORK")
    ring:SetTexture(MEDIA .. "Ring")
    ring:SetVertexColor(c.gold[1], c.gold[2], c.gold[3])
    ring:SetAlpha(0.9)
    ring:SetWidth(size * RING_SCALE)
    ring:SetHeight(size * RING_SCALE)
    ring:SetPoint("CENTER", holder, "CENTER")
    holder.ring = ring

    local border = CreateFrame("Frame", nil, holder)
    border:SetPoint("TOPLEFT", holder, "TOPLEFT", -2, 2)
    border:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 2, -2)
    border:SetFrameLevel(Minimap:GetFrameLevel() - 1 >= 0 and Minimap:GetFrameLevel() - 1 or 0)
    Azaath.SetBackdrop(border, {
        bgFile = blank, edgeFile = blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    border:SetBackdropColor(c.dark[1], c.dark[2], c.dark[3], 0.8)
    border:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.6)
    holder.border = border

    -- Vinheta Suave estilo Guild Wars 2 (Opção 2 - degradê painterly / aquarela)
    -- Aponta para PortolanCard que já era indexado pelo WoW na inicialização (compatível com /reload)
    local vignette = decor:CreateTexture(nil, "ARTWORK")
    vignette:SetTexture(MEDIA .. "Minimap\\PortolanCard")
    vignette:SetAllPoints(holder)
    vignette:Hide()
    holder.vignette = vignette

    -- Botões de zoom flutuantes (+ / −) estilo Guild Wars 2
    local zoomIn = CreateFrame("Button", "AzaathUIZoomIn", holder)
    zoomIn:SetWidth(18)
    zoomIn:SetHeight(18)
    zoomIn:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -4, -4)
    zoomIn:SetFrameLevel(decor:GetFrameLevel() + 2)
    Azaath.SetBackdrop(zoomIn, {
        bgFile = blank, edgeFile = blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    zoomIn:SetBackdropColor(c.dark[1], c.dark[2], c.dark[3], 0.75)
    zoomIn:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.45)
    local tIn = CreateText(zoomIn, 12)
    tIn:SetPoint("CENTER", zoomIn, "CENTER", 0, 0)
    tIn:SetText("+")
    tIn:SetTextColor(c.accent[1], c.accent[2], c.accent[3])
    zoomIn:SetScript("OnClick", function()
        local z = Minimap:GetZoom()
        if z < Minimap:GetZoomLevels() - 1 then
            Minimap:SetZoom(z + 1)
            Azaath.PlaySound("igMiniMapZoomIn")
        end
    end)
    zoomIn:SetScript("OnEnter", function(self)
        self:SetBackdropColor(c.gold[1], c.gold[2], c.gold[3], 0.3)
        self:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.9)
    end)
    zoomIn:SetScript("OnLeave", function(self)
        self:SetBackdropColor(c.dark[1], c.dark[2], c.dark[3], 0.75)
        self:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.45)
    end)
    holder.zoomIn = zoomIn

    local zoomOut = CreateFrame("Button", "AzaathUIZoomOut", holder)
    zoomOut:SetWidth(18)
    zoomOut:SetHeight(18)
    zoomOut:SetPoint("TOPRIGHT", zoomIn, "BOTTOMRIGHT", 0, -2)
    zoomOut:SetFrameLevel(decor:GetFrameLevel() + 2)
    Azaath.SetBackdrop(zoomOut, {
        bgFile = blank, edgeFile = blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    zoomOut:SetBackdropColor(c.dark[1], c.dark[2], c.dark[3], 0.75)
    zoomOut:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.45)
    local tOut = CreateText(zoomOut, 12)
    tOut:SetPoint("CENTER", zoomOut, "CENTER", 0, 0)
    tOut:SetText("−")
    tOut:SetTextColor(c.accent[1], c.accent[2], c.accent[3])
    zoomOut:SetScript("OnClick", function()
        local z = Minimap:GetZoom()
        if z > 0 then
            Minimap:SetZoom(z - 1)
            Azaath.PlaySound("igMiniMapZoomOut")
        end
    end)
    zoomOut:SetScript("OnEnter", function(self)
        self:SetBackdropColor(c.gold[1], c.gold[2], c.gold[3], 0.3)
        self:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.9)
    end)
    zoomOut:SetScript("OnLeave", function(self)
        self:SetBackdropColor(c.dark[1], c.dark[2], c.dark[3], 0.75)
        self:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.45)
    end)
    holder.zoomOut = zoomOut

    if round then
        border:Hide()
        vignette:Hide()
        zoomIn:Hide()
        zoomOut:Hide()
        northRadius = size * 0.51 -- centro da faixa principal do anel
    else
        glow:Hide()
        ring:Hide()
        border:Hide()
        vignette:Show()
        zoomIn:Show()
        zoomOut:Show()
        northRadius = size * 0.49
    end

    -- Marcador "N" com fundo escuro circular
    northBacking = decor:CreateTexture(nil, "OVERLAY")
    northBacking:SetTexture(MEDIA .. "Glow")
    northBacking:SetVertexColor(c.dark[1], c.dark[2], c.dark[3])
    northBacking:SetAlpha(0.85)
    northBacking:SetWidth(18)
    northBacking:SetHeight(18)

    north = CreateText(decor, 11)
    north:SetText("N")
    north:SetTextColor(c.accent[1], c.accent[2], c.accent[3])

    -- Dificuldade da instância (canto superior esquerdo)
    diffText = CreateText(decor, 11)
    diffText:SetPoint("TOPLEFT", holder, "TOPLEFT", round and 2 or 6, round and -2 or -6)

    -- Fundo escuro do minimapa (garante que cavernas e interiores sem tiles
    -- de terreno desenhem o fundo escuro clássico em vez de ficarem transparentes).
    local mapBackdrop = holder:CreateTexture(nil, "ARTWORK")
    mapBackdrop:SetPoint("CENTER", holder, "CENTER")
    holder.mapBackdrop = mapBackdrop

    -- Portulano (skin Classic): o cartão e a rosa ficam no holder, atrás do
    -- mapa; o anel e o lírio ficam no decor, por cima da borda do mapa.
    local card = holder:CreateTexture(nil, "BORDER")
    card:SetTexture(MEDIA .. "Minimap\\PortolanCard")
    card:Hide()
    holder.pCard = card

    local rose = holder:CreateTexture(nil, "ARTWORK")
    rose:SetTexture(MEDIA .. "Minimap\\PortolanRose")
    rose:Hide()
    holder.pRose = rose

    local pring = decor:CreateTexture(nil, "ARTWORK")
    pring:SetTexture(MEDIA .. "Minimap\\PortolanRing")
    pring:SetPoint("CENTER", holder, "CENTER")
    pring:Hide()
    holder.pRing = pring

    local fleur = decor:CreateTexture(nil, "OVERLAY")
    fleur:SetTexture(MEDIA .. "Minimap\\PortolanFleur")
    fleur:Hide()
    holder.pFleur = fleur

    return decor
end

-- Posiciona a decoração e os textos conforme o modo: portulano (Classic e
-- redondo), redondo com anel dourado, ou quadrado estilo Guild Wars 2.
local function LayoutDecor(size, db)
    portolan = UsePortolan() and true or false
    local P = PORTOLAN
    local card, rose, pring, fleur = holder.pCard, holder.pRose, holder.pRing, holder.pFleur

    -- A posição salva vale para o bloco inteiro: no portulano é o pergaminho
    -- que encosta na margem do canto, então o mapa desce/recua a sobra dele.
    local overR, overT = 0, 0
    if portolan then
        overR = (P.cardW - P.mapX - 0.5) * size
        overT = (P.mapY - 0.5) * size
    end
    holder.overTop = overT
    holder:ClearAllPoints()
    holder:SetPoint("TOPRIGHT", Azaath.root, "TOPRIGHT", (db.offsetX or -24) - overR, (db.offsetY or -24) - overT)

    if portolan then
        holder.glow:Hide()
        holder.ring:Hide()
        holder.border:Hide()
        if holder.vignette then holder.vignette:Hide() end
        if holder.zoomIn then holder.zoomIn:Hide() end
        if holder.zoomOut then holder.zoomOut:Hide() end
        north:Hide()
        northBacking:Hide()

        card:ClearAllPoints()
        card:SetPoint("TOPLEFT", holder, "TOPLEFT", -(P.mapX - 0.5) * size, (P.mapY - 0.5) * size)
        card:SetWidth(P.cardW * size)
        card:SetHeight(P.cardH * size)
        card:Show()

        pring:SetWidth(P.ring * size)
        pring:SetHeight(P.ring * size)
        pring:Show()

        rose:ClearAllPoints()
        rose:SetPoint("CENTER", card, "TOPLEFT", P.roseX * size, -P.roseY * size)
        rose:SetWidth(P.rose * size)
        rose:SetHeight(P.rose * size)
        if rose.SetRotation then pcall(rose.SetRotation, rose, 0) end
        rose:Show()

        fleur:SetWidth(P.fleur * size)
        fleur:SetHeight(P.fleur * size)
        fleur:Show()
        northRadius = P.northR * size

        -- espaço que o cartão ocupa além do mapa (buffs à esquerda, missões embaixo)
        holder.leftPad = (P.mapX - 0.5) * size + 10
        holder.belowHeight = (P.cardH - P.mapY - 0.5) * size + 10
    else
        card:Hide()
        rose:Hide()
        pring:Hide()
        fleur:Hide()
        north:Show()
        northBacking:Show()
        if round then
            if holder.vignette then holder.vignette:Hide() end
            if holder.zoomIn then holder.zoomIn:Hide() end
            if holder.zoomOut then holder.zoomOut:Hide() end
            holder.glow:SetWidth(size * GLOW_SCALE)
            holder.glow:SetHeight(size * GLOW_SCALE)
            holder.glow:Show()
            holder.ring:SetWidth(size * RING_SCALE)
            holder.ring:SetHeight(size * RING_SCALE)
            holder.ring:Show()
            holder.border:Hide()
            northRadius = size * 0.51
        else
            holder.glow:Hide()
            holder.ring:Hide()
            holder.border:Hide()
            if holder.vignette then holder.vignette:Show() end
            if holder.zoomIn then holder.zoomIn:Show() end
            if holder.zoomOut then holder.zoomOut:Show() end
            northRadius = size * 0.49
        end
        holder.leftPad, holder.belowHeight = nil, nil
    end

    if holder.mapBackdrop then
        holder.mapBackdrop:SetWidth(size)
        holder.mapBackdrop:SetHeight(size)
        if round then
            holder.mapBackdrop:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
        else
            holder.mapBackdrop:SetTexture(Azaath.media.blank)
        end
        holder.mapBackdrop:SetVertexColor(0, 0, 0, 1)
        holder.mapBackdrop:Show()
    end

    -- Textos
    StyleText(zoneText, portolan, true, (round or portolan) and 15 or 12)
    StyleText(coordText, portolan, false, 11)
    StyleText(clockText, portolan, false, 11)
    StyleText(diffText, portolan, false, 12)

    diffText:ClearAllPoints()
    zoneText:ClearAllPoints()
    coordText:ClearAllPoints()
    clockText:ClearAllPoints()

    if portolan then
        -- medidas do cartão convertidas para a borda inferior esquerda do mapa
        local left = (P.textX - (P.mapX - 0.5)) * size
        local function below(y) return -((y - P.mapY - 0.5) * size) end
        diffText:SetPoint("TOPLEFT", card, "TOPLEFT", 0.075 * size, -0.07 * size)

        zoneText:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", left, below(P.zoneY))
        zoneText:SetWidth((P.clockX - P.textX) * size)
        zoneText:SetHeight(18)
        zoneText:SetJustifyH("LEFT")

        coordText:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", left, below(P.infoY))
        coordText:SetTextColor(INK_SOFT[1], INK_SOFT[2], INK_SOFT[3])

        clockText:SetPoint("TOPRIGHT", card, "TOPLEFT", P.clockX * size, -P.infoY * size)
        clockText:SetTextColor(INK[1], INK[2], INK[3])
    elseif not round then
        -- Modo Quadrado estilo Guild Wars 2 (Opção 2):
        -- Textos integrados no rodapé sobre o degradê da vinheta
        local c = Azaath.colors
        diffText:SetPoint("TOPLEFT", holder, "TOPLEFT", 6, -6)

        zoneText:SetPoint("BOTTOM", holder, "BOTTOM", 0, 16)
        zoneText:SetWidth(size - 16)
        zoneText:SetHeight(14)
        zoneText:SetJustifyH("CENTER")

        coordText:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 6, 3)
        coordText:SetTextColor(c.gold[1], c.gold[2], c.gold[3])

        clockText:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -6, 3)
        clockText:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    else
        local c = Azaath.colors
        local gap = size * (RING_SCALE - 1) / 2 + 6
        diffText:SetPoint("TOPLEFT", holder, "TOPLEFT", 2, -2)

        zoneText:SetPoint("TOP", holder, "BOTTOM", 0, -gap)
        zoneText:SetWidth(size + 40)
        zoneText:SetHeight(14)
        zoneText:SetJustifyH("CENTER")

        coordText:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 4, -(gap + 16))
        coordText:SetTextColor(c.dim[1], c.dim[2], c.dim[3])

        clockText:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", -4, -(gap + 16))
        clockText:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    end

    if db.showCoords then coordText:Show() else coordText:Hide() end
    if db.showClock then
        clockText:Show()
        if holder.clockClick then holder.clockClick:Show() end
        lastClock = nil
        UpdateClock()
    else
        clockText:Hide()
        if holder.clockClick then holder.clockClick:Hide() end
    end

    UpdateZone()
    UpdateDifficulty()
end

-- Altura ocupada abaixo do mapa (textos/cartão), usada pelo MinimapCluster
local function BelowHeight(size)
    if portolan then return (PORTOLAN.cardH - PORTOLAN.mapY - 0.5) * size end
    if not round then return 4 end -- minimapa quadrado: textos integrados no rodapé do mapa
    return TEXT_BLOCK + (round and size * (RING_SCALE - 1) / 2 or 0)
end

-- Desloca o MinimapCluster (oculto) para baixo do nosso bloco: quem se
-- ancora nele (rastreador de missões, durabilidade, assentos) desce junto.
local function PlaceCluster(size, db)
    if not MinimapCluster then return end
    local bottom = -(db.offsetY or -24) + (holder.overTop or 0) + size + BelowHeight(size)
    MinimapCluster:ClearAllPoints()
    MinimapCluster:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", 0,
        -max(0, bottom - MinimapCluster:GetHeight() + 8))
end

local function BuildInfo(size, db)
    local gap = round and (size * (RING_SCALE - 1) / 2 + 6) or 6

    zoneText = CreateText(holder, 12)
    zoneText:SetPoint("TOP", holder, "BOTTOM", 0, -gap)
    zoneText:SetWidth(size + 40)
    zoneText:SetHeight(14)

    coordText = CreateText(holder, 10)
    coordText:SetPoint("TOPLEFT", holder, "BOTTOMLEFT", 4, -(gap + 16))
    coordText:SetTextColor(Azaath.colors.dim[1], Azaath.colors.dim[2], Azaath.colors.dim[3])
    if not db.showCoords then coordText:Hide() end

    clockText = CreateText(holder, 10)
    clockText:SetPoint("TOPRIGHT", holder, "BOTTOMRIGHT", -4, -(gap + 16))

    -- Área clicável sobre o relógio: cronômetro/alarme e calendário
    local click = CreateFrame("Button", "AzaathUIMinimapClock", holder)
    click:SetWidth(44)
    click:SetHeight(14)
    click:SetPoint("TOPRIGHT", clockText, "TOPRIGHT", 4, 2)
    click:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    click:SetScript("OnClick", function(_, button)
        if button == "RightButton" then
            OpenCalendar()
        elseif TimeManager_Toggle then
            TimeManager_Toggle()
        end
    end)
    click:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
        local h, m = GetGameTime()
        GameTooltip:AddLine(format("Horário do servidor: %02d:%02d", h, m), 1, 1, 1)
        GameTooltip:AddLine("Clique: relógio e cronômetro", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Clique direito: calendário", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    click:SetScript("OnLeave", function() GameTooltip:Hide() end)
    holder.clockClick = click
    if not db.showClock then
        clockText:Hide()
        click:Hide()
    end
end

function M:ApplyLayout()
    if not holder then return end
    local db = self.db
    if not db then return end
    if not db.enabled then
        holder:Hide()
        return
    end
    holder:Show()

    round = IsRound(db)

    local size = db.size or 170
    local scale = (db.scale and db.scale > 0) and db.scale or 1

    holder:SetScale(scale)
    holder:SetWidth(size)
    holder:SetHeight(size)
    holder:ClearAllPoints()
    holder:SetPoint("TOPRIGHT", Azaath.root, "TOPRIGHT", db.offsetX or -24, db.offsetY or -24)
    if Azaath.ClampToScreen then Azaath.ClampToScreen(holder) end

    Minimap:SetWidth(size)
    Minimap:SetHeight(size)
    Minimap:SetMaskTexture(round and ROUND_MASK or SQUARE_MASK)

    local backdrop = _G.MinimapBackdrop
    if backdrop then backdrop:Hide() if Azaath.hider then backdrop:SetParent(Azaath.hider) end end
    local mb = _G.MinimapBorder
    if mb then mb:Hide() end
    local mt = _G.MiniMapTracking
    if mt then mt:Hide() if Azaath.hider then mt:SetParent(Azaath.hider) end end

    local zoom = Minimap:GetZoom()
    Minimap:SetZoom(zoom > 0 and zoom - 1 or zoom + 1)
    Minimap:SetZoom(zoom)

    if zoneText then
        LayoutDecor(size, db)
        PlaceCluster(size, db)
    end

    UpdateNorth(true)
    Azaath.AnchorIndicators(_G.AzaathUIIndicators)
    LayoutAddonButtons()

    local qt = Azaath:GetModule("QuestTracker")
    if qt and qt.ApplyAnchor then qt:ApplyAnchor() end
    local auras = Azaath:GetModule("Auras")
    if auras and auras.ApplyLayout then auras:ApplyLayout() end
end

function M:Build()
    local db = self.db
    round = IsRound(db)
    local size = db.size

    holder = CreateFrame("Frame", "AzaathUIMinimap", Azaath.root)
    holder:SetFrameStrata("LOW")
    holder:SetScale((db.scale and db.scale > 0) and db.scale or 1)
    holder:SetWidth(size)
    holder:SetHeight(size)
    holder:SetPoint("TOPRIGHT", Azaath.root, "TOPRIGHT", db.offsetX, db.offsetY)
    if Azaath.ClampToScreen then Azaath.ClampToScreen(holder) end

    -- Reaproveita o Minimap nativo (renderização, blips, ping)
    Minimap:SetParent(holder)
    Minimap:ClearAllPoints()
    Minimap:SetPoint("CENTER", holder, "CENTER")
    Minimap:SetWidth(size)
    Minimap:SetHeight(size)
    Minimap:SetFrameStrata("LOW")
    Minimap:SetFrameLevel(holder:GetFrameLevel() + 2)
    Minimap:SetMaskTexture(round and ROUND_MASK or SQUARE_MASK)
    Minimap:EnableMouseWheel(true)
    Minimap:SetScript("OnMouseWheel", Minimap_OnMouseWheel)
    Minimap:SetScript("OnMouseUp", Minimap_OnMouseUp)

    -- Neutraliza bordas e botões legados da Blizzard / Forever que residem fora do MinimapCluster
    for _, name in ipairs({
        "MinimapBackdrop", "MinimapBorder", "MinimapBorderTop",
        "MiniMapTracking", "MiniMapTrackingButton", "MiniMapTrackingBorder", "MiniMapTrackingIcon",
        "MiniMapWorldMapButton", "MinimapZoomIn", "MinimapZoomOut",
        "MinimapZoneTextButton", "GameTimeFrame", "MinimapNorthTag",
    }) do
        local f = _G[name]
        if f then
            if f.UnregisterAllEvents then f:UnregisterAllEvents() end
            f:Hide()
            if f.SetParent and Azaath.hider then f:SetParent(Azaath.hider) end
        end
    end
    for _, region in ipairs({ Minimap:GetRegions() }) do
        if region and region.IsObjectType and region:IsObjectType("Texture") then
            local tex = region:GetTexture()
            if tex and type(tex) == "string" and (tex:find("Border") or tex:find("Corner") or tex:find("Compass")) then
                region:SetTexture(nil)
                region:Hide()
            end
        end
    end

    -- Após redimensionar, os blips só se reposicionam quando o zoom muda.
    local zoom = Minimap:GetZoom()
    Minimap:SetZoom(zoom > 0 and zoom - 1 or zoom + 1)
    Minimap:SetZoom(zoom)

    BuildDecor(size)
    BuildInfo(size, db)

    -- Bibliotecas de botões de minimapa (ex.: LibDBIcon) consultam este global.
    _G.GetMinimapShape = function() return round and "ROUND" or "SQUARE" end

    LayoutDecor(size, db)
    PlaceCluster(size, db)

    Azaath.AnchorIndicators(_G.AzaathUIIndicators)
    HideTimeManagerButton()
    LayoutAddonButtons()

    holder.infoElapsed, holder.northElapsed = INFO_INTERVAL, 0
    holder:SetScript("OnUpdate", OnUpdate)

    rotating = GetCVar("rotateMinimap") == "1"
    UpdateNorth(true)
    SyncMapZone()
    UpdateZone()
    UpdateDifficulty()
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1)
    if event == "ZONE_CHANGED_NEW_AREA" or event == "PLAYER_ENTERING_WORLD" then
        SyncMapZone()
        UpdateZone()
        UpdateDifficulty()
        if event == "PLAYER_ENTERING_WORLD" then
            LayoutAddonButtons()
            if C_Timer and C_Timer.After then
                C_Timer.After(0.5, LayoutAddonButtons)
                C_Timer.After(2.0, LayoutAddonButtons)
            end
        end
    elseif event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" then
        UpdateZone()
    elseif event == "PLAYER_DIFFICULTY_CHANGED" or event == "UPDATE_INSTANCE_INFO" then
        UpdateDifficulty()
    elseif event == "MINIMAP_UPDATE_TRACKING" then
        RefreshTrackingMenu()
    elseif event == "ADDON_LOADED" then
        if arg1 == "Blizzard_TimeManager" then HideTimeManagerButton() end
        if C_Timer and C_Timer.After then C_Timer.After(0.1, LayoutAddonButtons) end
    end
end)

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:OnInitialize()
    self.db = Azaath.db.minimap
    if self.db and self.db.enabled and Azaath.db and Azaath.db.hideBlizzard and Azaath.db.hideBlizzard.minimap then
        round = IsRound(self.db)
        _G.GetMinimapShape = function() return round and "ROUND" or "SQUARE" end
    end
end

function M:OnEnable()
    if not self.db.enabled then return end
    -- Com o minimapa da Blizzard restaurado (/azaath blizz minimap), não interfere.
    if not Azaath.db.hideBlizzard.minimap then return end

    self:Build()

    for _, e in ipairs({ "ZONE_CHANGED", "ZONE_CHANGED_INDOORS", "ZONE_CHANGED_NEW_AREA",
                         "PLAYER_ENTERING_WORLD", "PLAYER_DIFFICULTY_CHANGED",
                         "UPDATE_INSTANCE_INFO", "MINIMAP_UPDATE_TRACKING", "ADDON_LOADED" }) do
        Azaath.SafeRegister(events, e)
    end
end
