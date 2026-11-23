--[[----------------------------------------------------------------------------
    AzaathUI - Modules/WorldMap.lua
    Mapa-múndi próprio do Azaath (feito do zero; tecla do mapa, normalmente M).

    Tudo o que o jogo informa vem dele em tempo real, para acompanhar os patches sozinho:
      · mapas, continentes e zonas ... C_Map.GetMapInfo / GetMapChildrenInfo / GetMapRectOnMap
      · onde cada mapa fica no mundo . C_Map.GetWorldPosFromMapPos
      · arte pintada ................. C_Map.GetMapArtLayers / GetMapArtLayerTextures
      · partes já exploradas ......... C_MapExplorationInfo.GetExploredMapTextures
      · posição do jogador ........... C_Map.GetBestMapForUnit / GetPlayerMapPosition
    O que o jogo NÃO informa vem de Data/Map/*.lua, gerado por tools/map-extract/extract.js a partir
    dos arquivos do cliente:
      · Reveal.lua ... as partes das zonas (inclusive as ainda não exploradas)
      · Minimap.lua .. que imagem do minimapa (do próprio jogo) cobre cada quadro do mundo, as cópias
                       reduzidas para a vista de longe (Media/MapTerrain) e a cor da água
    Uma zona que ainda não está nas tabelas (patch novo, extrator não rodado) cai no que o jogo informa.

    Duas vistas:
      · TERRENO (padrão): um plano só, do mundo inteiro até o detalhe de uma zona, com o chão de
        verdade (as imagens do minimapa). O zoom é contínuo; o título segue o que está no centro.
        De perto, as áreas exploradas acendem por máscara com a forma das partes do jogo.
      · ARTE: a arte pintada de cada mapa, uma página por mapa (clique entra, botão direito sobe).
    Roda do mouse = zoom, arrastar = mover, clique = enquadrar a zona, botão direito = subir.

    Fase 1 (funcionamento): janela simples, sem a arte Azaath (vem depois).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("WorldMap")

local C_Map, C_MapExplorationInfo = _G.C_Map, _G.C_MapExplorationInfo
local floor, ceil, min, max, abs = math.floor, math.ceil, math.min, math.max, math.abs
local log, exp = math.log, math.exp
local pairs, ipairs, pcall, tostring, type = pairs, ipairs, pcall, tostring, type

local W, H = 1002, 668          -- a grade de todo mapa (pixels da arte); o plano do terreno usa a do mundo
local TILE = 256                -- quadros das partes reveladas
local YARDS = 1600 / 3          -- 533,33 jardas por quadro do minimapa
local DIM = 0.42                -- brilho das áreas inexploradas quando visíveis
local DARK = 0.13               -- brilho delas com "mostrar inexploradas" desligado
local MAX_NATIVE = 260          -- acima disso, o terreno usa as cópias reduzidas
local WORLD = 947               -- o mapa do mundo (Azeroth)
local T_CONTINENT, T_ZONE = 2, 3   -- Enum.UIMapType
local UI = Azaath.media.path .. "MapUI\\"
local TERRAIN = Azaath.media.path .. "MapTerrain\\"
local WATER = Azaath.media.path .. "MapWater\\"
-- mar de papel (tools/map-extract/sea-mask.js): a arte do mar fica por baixo do terreno; o terreno
-- fica transparente no mar aberto (máscara de terra por quadro de costa; cópias de longe já sem o mar)
-- e só lagos e rios continuam com água azul
local LAND = Azaath.media.path .. "MapLand\\"
local LAKE = Azaath.media.path .. "MapLake\\"
local TERRAIN_S = Azaath.media.path .. "MapTerrainS\\"
local FRAME_TEX = Azaath.media.path .. "MapFrame\\"

local S = { zoom = 1, ox = 0, oy = 0, vw = W, vh = H, zmin = 1 }

-- no terreno, a vista fica dentro do retângulo do plano que o papel da arte do mar cobre
-- (tools/map-ui-concept/expedicao/out/fit.json): afastar ou arrastar além mostraria a beira esticada.
-- Afastado ao máximo, a vista é exatamente a arte.
local SEA_X0, SEA_Y0, SEA_X1, SEA_Y1 = -61, 20, 1056, 616
local function UpdateZMin()
    local fit = min(S.vw / W, S.vh / H)
    if S.mode == "terrain" then
        S.zmin = max(S.vw / (SEA_X1 - SEA_X0), S.vh / (SEA_Y1 - SEA_Y0))
    else
        S.zmin = fit
    end
end

local function Safe(fn, ...)
    if not fn then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function FileSize(px)     -- quadros parciais ficam em imagens de lado potência de 2
    local s = 16
    while s < px do s = s * 2 end
    return s
end

---------------------------------------------------------------------------
-- Pools
---------------------------------------------------------------------------
local function NewPool(parent, layer, sub)
    return { parent = parent, layer = layer, sub = sub or 0, list = {}, used = 0 }
end

local function PoolGet(p)
    p.used = p.used + 1
    local t = p.list[p.used]
    if not t then
        t = p.parent:CreateTexture(nil, p.layer, nil, p.sub)
        p.list[p.used] = t
    end
    if t._mask then t:RemoveMaskTexture(t._mask); t._mask = nil end
    if t._land then t:RemoveMaskTexture(t._land); t._land = nil end
    t:ClearAllPoints()
    t:SetVertexColor(1, 1, 1, 1)
    t:SetDesaturated(false)
    t:SetTexCoord(0, 1, 0, 1)
    t:Show()
    return t
end

local function PoolReset(p)
    for i = 1, #p.list do
        local t = p.list[i]
        if t._mask then t:RemoveMaskTexture(t._mask); t._mask = nil end
        if t._land then t:RemoveMaskTexture(t._land); t._land = nil end
        t:Hide()
    end
    p.used = 0
end

local function MaskGet(p)
    p.used = p.used + 1
    local m = p.list[p.used]
    if not m then
        m = p.parent:CreateMaskTexture()
        p.list[p.used] = m
    end
    m:ClearAllPoints()
    m:Show()
    return m
end

-- põe uma textura no plano: x, y, w, h em pixels do plano (sem zoom)
local function Place(t, x, y, w, h)
    local z = S.zoom
    t:SetSize(w * z, h * z)
    t:SetPoint("TOPLEFT", S.canvas, "TOPLEFT", x * z, -y * z)
end

---------------------------------------------------------------------------
-- Vista
---------------------------------------------------------------------------
-- a vista (S.vw x S.vh) tem o tamanho que a moldura der; o plano (W x H) é centrado quando cabe inteiro
local function ClampPan()
    local z, vw, vh = S.zoom, S.vw, S.vh
    local x0, y0, x1, y1 = 0, 0, W, H
    if S.mode == "terrain" then x0, y0, x1, y1 = SEA_X0, SEA_Y0, SEA_X1, SEA_Y1 end
    local bw, bh = (x1 - x0) * z, (y1 - y0) * z
    if bw <= vw then S.ox = (vw - bw) / 2 - x0 * z else S.ox = min(-x0 * z, max(vw - x1 * z, S.ox)) end
    if bh <= vh then S.oy = y0 * z - (vh - bh) / 2 else S.oy = max(y0 * z, min(y1 * z - vh, S.oy)) end
end

-- cada camada foi desenhada num zoom (dz); entre um desenho e outro ela só é esticada (zoom suave)
local function PositionCanvas(cv)
    if not (cv and cv.dz) then return end
    local r = S.zoom / cv.dz
    cv.frame:SetScale(r)
    cv.frame:ClearAllPoints()
    cv.frame:SetPoint("TOPLEFT", S.view, "TOPLEFT", S.ox / r, S.oy / r)
end

local SEA_X0, SEA_HALF_W, SEA_H = -119.364, 620.364, 668
local function PositionSeaArt()
    if not (S.seaChartL and S.seaLabelsL) then return end
    if S.mode ~= "terrain" then
        S.seaChartL:Hide(); S.seaChartR:Hide()
        S.seaLabelsL:Hide(); S.seaLabelsR:Hide()
        return
    end
    local z = S.zoom
    local rel = z / (S.zmin and S.zmin > 0 and S.zmin or 1)
    local zoneFade = (S.place and S.place.kind == "zone") and 0 or 1
    -- o mar de papel é o mar: nunca some (por baixo dele só há a água dos ladrilhos do terreno)
    local chartA = 1
    local labelA = (M.db and M.db.showNames == false) and 0 or (max(0, min(1, (1.75 - rel) / (1.75 - 1.22))) * zoneFade)
    local w, h = SEA_HALF_W * z, SEA_H * z
    local x, y = S.ox + SEA_X0 * z, S.oy
    local function FitPair(a, b, alpha)
        if alpha <= 0.01 then a:Hide(); b:Hide() return end
        a:ClearAllPoints(); a:SetPoint("TOPLEFT", S.view, "TOPLEFT", x, y); a:SetSize(w, h)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", a, "TOPRIGHT"); b:SetSize(w, h)
        a:SetAlpha(alpha); b:SetAlpha(alpha)
        a:Show(); b:Show()
    end
    FitPair(S.seaChartL, S.seaChartR, chartA)
    FitPair(S.seaLabelsL, S.seaLabelsR, labelA)
end

local function ApplyPan()
    ClampPan()
    PositionCanvas(S.cvA)
    PositionCanvas(S.cvB)
    PositionSeaArt()
    if S.onPan then S.onPan() end      -- os nomes acompanham (PlaceLabels)
end

local function Visible()        -- retângulo visível, em pixels do plano
    local z = S.zoom
    local x0, y0 = -S.ox / z, S.oy / z
    return x0, y0, x0 + S.vw / z, y0 + S.vh / z
end

local function Overlaps(ax0, ay0, ax1, ay1, bx0, by0, bx1, by1)
    return ax0 < bx1 and ay0 < by1 and ax1 > bx0 and ay1 > by0
end

-- cursor em pixels do plano (nil fora da vista)
local function Cursor()
    if not S.view:IsMouseOver() then return nil end
    local x, y = GetCursorPosition()
    local s = S.view:GetEffectiveScale()
    local left, top = S.view:GetLeft(), S.view:GetTop()
    if not (left and top) then return nil end
    local vx, vy = x / s - left, top - y / s
    return (vx - S.ox) / S.zoom, (vy + S.oy) / S.zoom
end

-- enquadra o retângulo do plano na vista (animate: com transição suave)
local function Fit(x0, y0, x1, y1, animate)
    local z = min(S.vw / (x1 - x0), S.vh / (y1 - y0)) * 0.92
    z = max(S.zmin, min(S.maxZoom or 8, z))
    local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    if animate then
        local z0 = S.zoom
        S.anim = { kind = "fit", t = 0, dur = 0.35, z0 = z0, z1 = z,
            cx0 = (S.vw / 2 - S.ox) / z0, cy0 = (S.oy + S.vh / 2) / z0, cx1 = cx, cy1 = cy }
        -- afastando, o destino é desenhado já; aproximando, a vista atual esticada cobre tudo
        if z < z0 then S.anim.predraw = { z, S.vw / 2 - cx * z, cy * z - S.vh / 2 } end
        return
    end
    S.anim = nil
    S.zoom = z
    S.ox = S.vw / 2 - cx * z
    S.oy = cy * z - S.vh / 2
    ClampPan()
end

---------------------------------------------------------------------------
-- O plano contínuo (vista de terreno): mundo -> continentes -> zonas
---------------------------------------------------------------------------
-- onde um mapa fica no mundo: instância e limites em jardas (X norte, Y oeste)
local function WorldRect(mapID)
    if not (C_Map.GetWorldPosFromMapPos and _G.CreateVector2D) then return end
    local i1, a = Safe(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
    local i2, b = Safe(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
    if not (i1 and a and b) or i1 ~= i2 then return end
    local top, left = a:GetXY()
    local bottom, right = b:GetXY()
    if not (top and left and bottom and right) or top == bottom or left == right then return end
    return i1, top, left, bottom, right
end

-- monta o plano: cada continente no lugar que o mapa do mundo dá a ele, em jardas -> pixels
local function BuildWorld()
    local data = Azaath.MapData or {}
    local P = { conts = {}, zones = {}, byID = {} }
    local conts = Safe(C_Map.GetMapChildrenInfo, WORLD, T_CONTINENT, false) or {}
    for _, ci in ipairs(conts) do
        local inst, top, left, bottom, right = WorldRect(ci.mapID)
        local x0, x1, y0, y1 = Safe(C_Map.GetMapRectOnMap, ci.mapID, WORLD)
        if inst and x0 and data.MinimapTiles and data.MinimapTiles[inst] then
            local c = { id = ci.mapID, name = ci.name, inst = inst, kind = "cont" }
            -- jardas -> pixels do plano: x = ax + bx * Y,  y = ay + by * X
            c.bx = (x1 - x0) * W / (right - left)
            c.ax = x0 * W - c.bx * left
            c.by = (y1 - y0) * H / (bottom - top)
            c.ay = y0 * H - c.by * top
            c.x0, c.y0, c.x1, c.y1 = x0 * W, y0 * H, x1 * W, y1 * H
            P.conts[#P.conts + 1] = c
            P.byID[c.id] = c
            local kids = Safe(C_Map.GetMapChildrenInfo, ci.mapID, T_ZONE, true) or {}
            for _, zi in ipairs(kids) do
                local zinst, zt, zl, zb, zr = WorldRect(zi.mapID)
                if zinst == inst then
                    local z = { id = zi.mapID, name = zi.name, cont = c, kind = "zone" }
                    z.x0, z.x1 = c.ax + c.bx * zl, c.ax + c.bx * zr
                    z.y0, z.y1 = c.ay + c.by * zt, c.ay + c.by * zb
                    local artID = Safe(C_Map.GetMapArtID, zi.mapID)
                    z.pieces = artID and data.Reveal and data.Reveal[artID] or nil
                    P.zones[#P.zones + 1] = z
                    P.byID[z.id] = z
                end
            end
        end
    end
    if #P.conts == 0 then return nil end
    -- nomes: cada área do terreno (Data/Map/Areas.lua) no plano; o texto vem do jogo quando aparece
    P.labels, P.zoneNames = {}, {}
    for _, z in ipairs(P.zones) do if z.name then P.zoneNames[z.name] = z end end
    local byInst = {}
    for _, c in ipairs(P.conts) do byInst[c.inst] = c end
    for _, a in ipairs(data.Areas or {}) do
        local c = byInst[a[1]]
        if c then
            P.labels[#P.labels + 1] = { x = c.ax + c.bx * a[3], y = c.ay + c.by * a[2], area = a[4],
                ext = math.sqrt(a[5]) * (YARDS / 16) * abs(c.bx) }
        end
    end
    -- zoom máximo: um quadro do minimapa (imagem de 512 px) com no máximo ~2x o tamanho real;
    -- além disso a imagem só fica borrada
    P.maxZoom = 400
    for _, c in ipairs(P.conts) do P.maxZoom = min(P.maxZoom, 1024 / (YARDS * abs(c.bx))) end
    P.maxZoom = max(8, P.maxZoom)
    return P
end

-- de pixels do plano para coordenadas 0..1 de um mapa do plano
local function ToMap(m, x, y)
    return (x - m.x0) / (m.x1 - m.x0), (y - m.y0) / (m.y1 - m.y0)
end

-- continente sob o ponto; os retângulos se sobrepõem no mar: vale o de centro mais perto
local function ContAt(x, y)
    local best, bd
    for _, c in ipairs(S.P.conts) do
        if x >= c.x0 and x < c.x1 and y >= c.y0 and y < c.y1 then
            local dx, dy = x - (c.x0 + c.x1) / 2, y - (c.y0 + c.y1) / 2
            local d = dx * dx + dy * dy
            if not bd or d < bd then best, bd = c, d end
        end
    end
    return best
end

-- zona sob o ponto: pela forma real que o jogo dá (GetMapInfoAtPosition no continente)
local function ZoneAt(x, y)
    local c = ContAt(x, y)
    if not c then return nil, nil end
    local nx, ny = ToMap(c, x, y)
    local info = Safe(C_Map.GetMapInfoAtPosition, c.id, nx, ny)
    local id = info and info.mapID
    -- subir até uma zona conhecida (a resposta pode ser uma sub-zona)
    while id and not S.P.byID[id] do
        local i = Safe(C_Map.GetMapInfo, id)
        id = i and i.parentMapID
    end
    local z = id and S.P.byID[id]
    if z and z.kind == "zone" then return z, c end
    return nil, c
end

-- o mapa "atual" pelo que está no centro e pelo zoom
local function CurrentPlace()
    if S.zoom < S.zmin * 1.25 then return nil end      -- perto do zoom mínimo: o mundo
    local x0, y0, x1, y1 = Visible()
    local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    local z, c = ZoneAt(cx, cy)
    if z and (z.x1 - z.x0) * S.zoom >= S.vw * 0.45 then return z end
    if c and (c.x1 - c.x0) * S.zoom >= S.vw * 0.6 then return c end
    return nil
end

---------------------------------------------------------------------------
-- Terreno
---------------------------------------------------------------------------
local function TileRect(c, col, row, n)       -- canto noroeste do quadro e o tamanho de n quadros
    local x = c.ax + c.bx * ((32 - col) * YARDS)
    local y = c.ay + c.by * ((32 - row) * YARDS)
    return x, y, abs(c.bx) * n * YARDS, abs(c.by) * n * YARDS
end

local function TileRange(c, n, x0, y0, x1, y1)
    local function col(x) return 32 - ((x - c.ax) / c.bx) / YARDS end
    local function row(y) return 32 - ((y - c.ay) / c.by) / YARDS end
    local ca, cb = col(x0), col(x1)
    local ra, rb = row(y0), row(y1)
    return max(0, floor(min(ca, cb) / n)), min(63, floor(max(ca, cb) / n)),
           max(0, floor(min(ra, rb) / n)), min(63, floor(max(ra, rb) / n))
end

local function TerrainLevel(c, x0, y0, x1, y1)
    local ppt = YARDS * abs(c.bx) * S.zoom
    local lod = Azaath.MapData.MinimapLOD and Azaath.MapData.MinimapLOD[c.inst]
    if not lod then return 1 end
    if ppt >= 48 then
        local c0, c1, r0, r1 = TileRange(c, 1, x0, y0, x1, y1)
        if (c1 - c0 + 1) * (r1 - r0 + 1) <= MAX_NATIVE then return 1 end
    end
    if ppt >= 12 and lod[4] then return 4 end
    return lod[16] and 16 or 4
end

-- os quadros de terreno à vista: { x, y, w, h, textura }
local function TerrainTiles(x0, y0, x1, y1)
    local data, out = Azaath.MapData, {}
    for _, c in ipairs(S.P.conts) do
        if Overlaps(x0, y0, x1, y1, c.x0, c.y0, c.x1, c.y1) then
            local n = TerrainLevel(c, x0, y0, x1, y1)
            local c0, c1, r0, r1 = TileRange(c, n, x0, y0, x1, y1)
            local src = n == 1 and data.MinimapTiles[c.inst] or data.MinimapLOD[c.inst][n]
            local seaT = data.MinimapSea and data.MinimapSea[c.inst]
            if seaT then
                -- mar de papel: costa recortada pela máscara de terra; lagos e rios por cima
                local lake = n == 1 and data.MinimapLake and data.MinimapLake[c.inst] or nil
                for r = r0, r1 do
                    for k = c0, c1 do
                        local key = r * 64 + k
                        local v = src[key]
                        local sv = n == 1 and seaT[key]
                        if v and sv ~= 2 then           -- (2: quadro só de mar; a arte do mar já está por baixo)
                            local x, y, w, h = TileRect(c, k * n, r * n, n)
                            local tex = n == 1 and v or (TERRAIN_S .. c.inst .. "_" .. n .. "_" .. k .. "_" .. r)
                            out[#out + 1] = { x, y, w, h, tex, land = sv == 1 and (LAND .. c.inst .. "_" .. key) or nil }
                            if lake and lake[key] then
                                out[#out + 1] = { x, y, w, h, LAKE .. c.inst .. "_" .. key, water = true }
                            end
                        end
                    end
                end
            else
                local water = n == 1 and data.MinimapWater and data.MinimapWater[c.inst] or nil
                for r = r0, r1 do
                    for k = c0, c1 do
                        local key = r * 64 + k
                        local v = src[key]
                        local wv = water and water[key]
                        if v and wv ~= 2 then           -- (2: quadro só de mar; o fundo já é o mar)
                            local x, y, w, h = TileRect(c, k * n, r * n, n)
                            local tex = n == 1 and v or (TERRAIN .. c.inst .. "_" .. n .. "_" .. k .. "_" .. r)
                            out[#out + 1] = { x, y, w, h, tex }
                            if wv == 1 then             -- a água funda no tom do mapa, por cima da imagem do jogo
                                out[#out + 1] = { x, y, w, h, WATER .. c.inst .. "_" .. key, water = true }
                            end
                        end
                    end
                end
            end
        end
    end
    return out
end

local function ExploredSet(zoneID)
    S.exploredCache = S.exploredCache or {}
    local set = S.exploredCache[zoneID]
    if not set then
        set = {}
        for _, e in ipairs(Safe(C_MapExplorationInfo.GetExploredMapTextures, zoneID) or {}) do
            set[(e.offsetX or 0) .. ":" .. (e.offsetY or 0)] = true
        end
        S.exploredCache[zoneID] = set
    end
    return set
end

-- acende uma área do plano: cópias do chão recortadas pela máscara (parte do jogo) ou por retângulo
local function Lit(tiles, mx, my, mw, mh, maskTex, maskW, maskH)
    local mask
    if maskTex then
        mask = MaskGet(S.masks)
        mask:SetTexture(maskTex, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        Place(mask, mx, my, maskW, maskH)
    end
    for _, q in ipairs(tiles) do
        if Overlaps(q[1], q[2], q[1] + q[3], q[2] + q[4], mx, my, mx + mw, my + mh) then
            local t = PoolGet(q.water and S.litW or S.lit)
            t:SetTexture(q[5])
            if q.landMask then t:AddMaskTexture(q.landMask); t._land = q.landMask end
            if mask then
                Place(t, q[1], q[2], q[3], q[4])
                t:AddMaskTexture(mask)
                t._mask = mask
            else       -- recorte retangular (cidades, zonas sem partes)
                local ix0, iy0 = max(q[1], mx), max(q[2], my)
                local ix1, iy1 = min(q[1] + q[3], mx + mw), min(q[2] + q[4], my + mh)
                Place(t, ix0, iy0, ix1 - ix0, iy1 - iy0)
                t:SetTexCoord((ix0 - q[1]) / q[3], (ix1 - q[1]) / q[3], (iy0 - q[2]) / q[4], (iy1 - q[2]) / q[4])
            end
        end
    end
end

---------------------------------------------------------------------------
-- Interiores (Data/Map/Interiors.lua, job "interiors" do extrator): tudo o que fica abaixo do chão (cidades
-- como Altaforja e a Cidade Baixa, cavernas, minas, criptas) sempre à vista de perto; construções de
-- superfície (casas, estalagens, torres) só quando você está dentro (como o minimapa do jogo).
-- db.interiors: "auto" (subterrâneos + onde você está), "all" (todos) ou "off".
---------------------------------------------------------------------------
local INTERIOR = Azaath.media.path .. "MapInterior\\"
-- só de perto (pixels da tela por jarda; a vista de uma zona inteira fica perto de 0,5 e o zoom máximo perto de 1,9):
-- subterrâneos surgem a partir de 0,9 e ficam cheios em 1,3; a construção onde você está aparece já de longe
local INTERIOR_MIN_PPY = 0.12
local UNDER_FADE0, UNDER_FADE1 = 0.9, 1.3

local function Interiors()
    if S.interiors then return S.interiors end
    local list = {}
    for _, e in ipairs(Azaath.MapData and Azaath.MapData.Interiors or {}) do
        local inst, Xn, Yw, kind, uid, res, tw, th, tl = unpack(e)
        local it = { inst = inst, Xn = Xn, Yw = Yw, kind = kind, uid = uid, tyw = tw / res, tyh = th / res, tiles = {} }
        local cmax, rmax = 0, 0
        for c, r in tl:gmatch("(%d+),(%d+)") do
            c, r = tonumber(c), tonumber(r)
            it.tiles[#it.tiles + 1] = { c, r }
            cmax, rmax = max(cmax, c), max(rmax, r)
        end
        it.Xs, it.Ye = Xn - (rmax + 1) * it.tyh, Yw - (cmax + 1) * it.tyw   -- bordas sul e leste
        list[#list + 1] = it
    end
    S.interiors = list
    return list
end

-- posição do jogador no mundo: instância, X (norte), Y (oeste)
local function PlayerWorld()
    local best = Safe(C_Map.GetBestMapForUnit, "player")
    local pos = best and Safe(C_Map.GetPlayerMapPosition, best, "player")
    if not pos then return end
    local inst, wp = Safe(C_Map.GetWorldPosFromMapPos, best, pos)
    if not (inst and wp) then return end
    local X, Y = wp:GetXY()
    return inst, X, Y
end

-- o interior (não cidade) em que o jogador está: o menor que o contém, só dentro de construções
local function InteriorHere()
    if not (IsIndoors and IsIndoors()) then return nil end
    local inst, X, Y = PlayerWorld()
    if not inst then return nil end
    local best, area
    for _, it in ipairs(Interiors()) do
        if it.kind == 0 and it.inst == inst and X <= it.Xn and X >= it.Xs and Y <= it.Yw and Y >= it.Ye then
            local a = (it.Xn - it.Xs) * (it.Yw - it.Ye)
            if not area or a < area then best, area = it, a end
        end
    end
    return best
end

local function DrawInteriors(x0, y0, x1, y1)
    local mode = M.db.interiors or "auto"
    if mode == "off" then return end
    S.insideNow = InteriorHere()
    for _, c in ipairs(S.P.conts) do
        if abs(c.bx) * S.zoom >= INTERIOR_MIN_PPY and Overlaps(x0, y0, x1, y1, c.x0, c.y0, c.x1, c.y1) then
            local sx, sy = abs(c.bx), abs(c.by)
            local ppy = sx * S.zoom
            local fade = max(0, min(1, (ppy - UNDER_FADE0) / (UNDER_FADE1 - UNDER_FADE0)))
            for _, it in ipairs(Interiors()) do
                local here = it == S.insideNow
                local alpha = here and 1 or fade
                if it.inst == c.inst and alpha > 0 and (mode == "all" or it.kind > 0 or here) then
                    local px, py = c.ax + c.bx * it.Yw, c.ay + c.by * it.Xn
                    local pw, ph = sx * (it.Yw - it.Ye), sy * (it.Xn - it.Xs)
                    if Overlaps(x0, y0, x1, y1, px, py, px + pw, py + ph) then
                        for _, q in ipairs(it.tiles) do
                            local t = PoolGet(S.inner)
                            t:SetTexture(INTERIOR .. it.inst .. "_" .. it.uid .. "_" .. q[1] .. "_" .. q[2])
                            Place(t, px + q[1] * it.tyw * sx, py + q[2] * it.tyh * sy, it.tyw * sx, it.tyh * sy)
                            t:SetAlpha(alpha)
                        end
                    end
                end
            end
        end
    end
end

local function DrawTerrain()
    local x0, y0, x1, y1 = Visible()
    local tiles = TerrainTiles(x0, y0, x1, y1)
    -- névoa só de perto (quando o mapa atual é uma zona), e se o cliente tem máscaras
    local here = S.place
    -- (cidades e zonas sem partes no centro: sem névoa)
    -- ("inexploradas coloridas": tudo como se estivesse explorado, sem névoa)
    local fog = not M.db.revealAll and here and here.kind == "zone" and here.pieces and S.canvas.CreateMaskTexture and true or false
    local k = M.db.showUnexplored and DIM or DARK
    -- (o mar é o papel: não escurece com a névoa, que é só da terra)
    S.sea:SetVertexColor(1, 1, 1, 1)
    for _, q in ipairs(tiles) do
        local t = PoolGet(q.water and S.baseW or S.base)
        t:SetTexture(q[5])
        Place(t, q[1], q[2], q[3], q[4])
        if q.land and t.AddMaskTexture then
            local m = MaskGet(S.masks)
            m:SetTexture(q.land, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
            Place(m, q[1], q[2], q[3], q[4])
            t:AddMaskTexture(m)
            t._land = m
            q.landMask = m
        end
        if fog then
            -- (a água não perde a cor: tem de casar com o fundo, que só escurece)
            t:SetDesaturated(not q.water and M.db.showUnexplored and true or false)
            t:SetVertexColor(k, k, k, 1)
        end
    end
    DrawInteriors(x0, y0, x1, y1)
    if not fog then return end
    for _, z in ipairs(S.P.zones) do
        if Overlaps(x0, y0, x1, y1, z.x0, z.y0, z.x1, z.y1) then
            local sx, sy = (z.x1 - z.x0) / W, (z.y1 - z.y0) / H   -- pixels da arte da zona -> plano
            if z.pieces then
                local seen = ExploredSet(z.id)
                for _, p in ipairs(z.pieces) do
                    if seen[p[1] .. ":" .. p[2]] then
                        local cols = ceil(p[3] / TILE)
                        for i = 6, #p do
                            local j = i - 6
                            local col, row = j % cols, floor(j / cols)
                            local pw, ph = min(TILE, p[3] - col * TILE), min(TILE, p[4] - row * TILE)
                            if pw > 0 and ph > 0 then
                                local mx, my = z.x0 + (p[1] + col * TILE) * sx, z.y0 + (p[2] + row * TILE) * sy
                                if Overlaps(x0, y0, x1, y1, mx, my, mx + pw * sx, my + ph * sy) then
                                    Lit(tiles, mx, my, pw * sx, ph * sy, p[i], FileSize(pw) * sx, FileSize(ph) * sy)
                                end
                            end
                        end
                    end
                end
            elseif z == here then
                -- cidade no centro: inteira acesa (dentro de outra zona, segue a névoa dela)
                Lit(tiles, z.x0, z.y0, z.x1 - z.x0, z.y1 - z.y0)
            end
        end
    end
end

---------------------------------------------------------------------------
-- Nomes (vista de terreno): zonas de longe, sub-regiões de perto, sem sobrepor
---------------------------------------------------------------------------
local GOLD = { 0.953, 0.812, 0.447 }
local SEA_INK = { 1, 1, 1, 0.92 }
local SEA_WORDS = {
    mar = true, oceano = true, ["baía"] = true, enseada = true, estreito = true, golfo = true, canal = true,
    sea = true, ocean = true, bay = true, strait = true, gulf = true, cove = true, sound = true,
}
local nameCache = {}

local function IsSea(text)
    for word in text:lower():gmatch("[^%s%-']+") do
        if SEA_WORDS[word] then return true end
    end
    return false
end

local function LabelName(L)
    local n = nameCache[L.area]
    if n == nil then
        n = Safe(C_Map.GetAreaInfo, L.area) or false
        if n == "" then n = false end
        nameCache[L.area] = n
    end
    return n or nil
end

local function LabelGet()
    local p = S.names
    p.used = p.used + 1
    local fs = p.list[p.used]
    if not fs then
        fs = p.parent:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("CENTER")
        fs:SetWordWrap(false)
        p.list[p.used] = fs
    end
    fs._dy = nil
    fs:Show()
    return fs
end

-- estilo por tipo: "cont" (continente), "zone", "sub" (sub-região), "sea" (mar)
--   continente e zona: Cinzel negrito dourado, maiúsculas espaçadas, contorno e sombra
--   sub-região: Cinzel regular em pergaminho claro, maiúsculas sem espaçar (mais discreta e curta)
--   mar: IM Fell itálico claro, sem contorno, sombra para ler sobre a água
local PARCHMENT = { 0.91, 0.87, 0.76 }
local function StyleLabel(fs, text, size, kind, alpha)
    local media = Azaath.media or {}
    if kind == "sea" then
        if not pcall(fs.SetFont, fs, media.fontItalic or media.fontTitle, size + 2, "") then fs:SetFontObject(GameFontNormal) end
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0.04, 0.05, 0.9)
        fs:SetTextColor(SEA_INK[1], SEA_INK[2], SEA_INK[3], SEA_INK[4] * alpha)
        fs:SetText(text)
        return
    end
    local up = Azaath.Upper and Azaath.Upper(text) or text:upper()
    if kind == "sub" then
        if not pcall(fs.SetFont, fs, media.fontCinzel or media.fontTitleB, size, "OUTLINE") then fs:SetFontObject(GameFontNormalSmall) end
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 0.8)
        fs:SetTextColor(PARCHMENT[1], PARCHMENT[2], PARCHMENT[3], alpha)
        fs:SetText(up)
        return
    end
    if not pcall(fs.SetFont, fs, media.fontTitleB or media.fontCinzel, size, "OUTLINE") then fs:SetFontObject(GameFontNormalSmall) end
    fs:SetShadowOffset(1.5, -1.5)
    fs:SetShadowColor(0, 0, 0, 0.75)
    fs:SetTextColor(GOLD[1], GOLD[2], GOLD[3], alpha)
    fs:SetText(Azaath.Tracked and Azaath.Tracked(up) or up)
end

-- reposiciona os nomes já escolhidos (ao mover ou durante o zoom animado)
local function PlaceLabels()
    local p = S.names
    if not p then return end
    local z = S.zoom
    for i = 1, p.used do
        local fs = p.list[i]
        fs:ClearAllPoints()
        fs:SetPoint("CENTER", S.view, "TOPLEFT", S.ox + fs._x * z, S.oy - fs._y * z - (fs._dy or 0))
    end
end

-- onde escrever o nome de cada zona: no maior pedaço de terreno com o código da própria zona
-- (cai dentro dela); sem ele, no centro do retângulo
local function ZoneLabelPos(zone)
    if zone.lx == nil then
        zone.lx = false
        for _, L in ipairs(S.P.labels) do             -- (maiores primeiro)
            if L.x >= zone.x0 and L.x <= zone.x1 and L.y >= zone.y0 and L.y <= zone.y1 and LabelName(L) == zone.name then
                zone.lx, zone.ly = L.x, L.y
                break
            end
        end
        if not zone.lx then zone.lx, zone.ly = (zone.x0 + zone.x1) / 2, (zone.y0 + zone.y1) / 2 end
    end
    return zone.lx, zone.ly
end

-- a zona de um rótulo (guardada; false = mar ou fora de zona)
local function LabelZone(L)
    if L.zone == nil then L.zone = (ZoneAt(L.x, L.y)) or false end
    return L.zone
end

-- faixa de nível embaixo do nome da zona (MapChrome.MapLevels: roteiros de leveling / missões),
-- na cor da dificuldade para o seu nível; some se não couber
local function ZoneLevelLabel(nameFs, zone, size, placed)
    if zone.lvLo == nil then
        local C = Azaath:GetModule("MapChrome")
        local lo, hi
        if C and C.MapLevels then lo, hi = C.MapLevels(zone.id) end
        zone.lvLo, zone.lvHi = lo or false, hi or lo or false
    end
    local lo, hi = zone.lvLo, zone.lvHi
    if not lo then return end
    local fs = LabelGet()
    local media = Azaath.media or {}
    if not pcall(fs.SetFont, fs, media.fontCinzel or media.fontTitleB, size - 1, "OUTLINE") then fs:SetFontObject(GameFontNormalSmall) end
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
    local me = UnitLevel and UnitLevel("player") or 0
    if me < lo - 2 then fs:SetTextColor(0.95, 0.38, 0.28)
    elseif me < lo then fs:SetTextColor(1, 0.62, 0.25)
    elseif me <= hi then fs:SetTextColor(1, 0.84, 0.3)
    elseif me <= hi + 5 then fs:SetTextColor(0.5, 0.86, 0.42)
    else fs:SetTextColor(0.62, 0.62, 0.62) end
    fs:SetText(lo == hi and tostring(lo) or (lo .. " - " .. hi))
    local z = S.zoom
    local dy = size + 3
    local sx, sy = S.ox + nameFs._x * z, nameFs._y * z - S.oy + dy
    local hw, hh = fs:GetStringWidth() / 2 + 4, size / 2 + 2
    local free = sy + hh <= S.vh
    local own = placed[#placed]          -- o retângulo do próprio nome (acabou de entrar) não conta
    if free then
        for _, r in ipairs(placed) do
            if r ~= own and sx - hw < r[3] and sx + hw > r[1] and sy - hh < r[4] and sy + hh > r[2] then free = false break end
        end
    end
    if not free then
        fs:Hide()
        S.names.used = S.names.used - 1
        return
    end
    placed[#placed + 1] = { sx - hw, sy - hh, sx + hw, sy + hh }
    fs._x, fs._y, fs._dy = nameFs._x, nameFs._y, dy
end

local function LayoutLabels()
    PositionSeaArt()
    local p = S.names
    for i = 1, #p.list do p.list[i]:Hide() end
    p.used = 0
    if S.mode ~= "terrain" or M.db.showNames == false or not S.P.labels then return end
    local x0, y0, x1, y1 = Visible()
    local z = S.zoom
    local placed, names = {}, {}

    -- nudge: quantas posições alternativas (acima/abaixo) tentar se a principal estiver ocupada
    local function Try(name, x, y, size, alpha, kind, nudge)
        if names[name] or p.used >= 90 then return end
        local fs = LabelGet()
        StyleLabel(fs, name, size, kind, alpha)
        local hw, hh = fs:GetStringWidth() / 2 + 6, size / 2 + 4
        for k = 0, (nudge or 0) * 2 do
            local dy = (k == 0) and 0 or ((k % 2 == 1) and -1 or 1) * ceil(k / 2) * hh * 1.6
            local sx, sy = S.ox + x * z, y * z - S.oy + dy
            local free = sx - hw >= 0 and sx + hw <= S.vw and sy - hh >= 0 and sy + hh <= S.vh
            if free then
                for _, r in ipairs(placed) do
                    if sx - hw < r[3] and sx + hw > r[1] and sy - hh < r[4] and sy + hh > r[2] then free = false break end
                end
            end
            if free then
                placed[#placed + 1] = { sx - hw, sy - hh, sx + hw, sy + hh }
                names[name] = true
                fs._x, fs._y = x, y + dy / z
                return fs
            end
        end
        fs:Hide()
        p.used = p.used - 1
    end

    -- 0) mundo inteiro: só os continentes
    if not S.place then
        for _, c in ipairs(S.P.conts) do
            if c.name then
                local lx, ly, n = 0, 0, 0                  -- no meio do terreno do continente
                for _, L in ipairs(S.P.labels) do
                    if L.x >= c.x0 and L.x <= c.x1 and L.y >= c.y0 and L.y <= c.y1 then
                        lx, ly, n = lx + L.x, ly + L.y, n + 1
                    end
                end
                if n == 0 then lx, ly, n = (c.x0 + c.x1) / 2, (c.y0 + c.y1) / 2, 1 end
                Try(c.name, lx / n, ly / n, 15, 1, "cont", 2)
            end
        end
        PlaceLabels()
        return
    end

    -- 1) zonas: pelo tamanho real na tela, as maiores primeiro, até você estar dentro dela
    if not S.P.zonesBySize then
        S.P.zonesBySize = {}
        for _, zone in ipairs(S.P.zones) do S.P.zonesBySize[#S.P.zonesBySize + 1] = zone end
        table.sort(S.P.zonesBySize, function(a, b)
            return (a.x1 - a.x0) * (a.y1 - a.y0) > (b.x1 - b.x0) * (b.y1 - b.y0)
        end)
    end
    for _, zone in ipairs(S.P.zonesBySize) do
        local zw = (zone.x1 - zone.x0) * z
        if zone.name and zw >= 55 and zw < S.vw * 0.75 then
            local x, y = ZoneLabelPos(zone)
            if x >= x0 and x <= x1 and y >= y0 and y <= y1 then
                local size = zw >= 220 and 9 or 8
                local nfs = Try(zone.name, x, y, size, 1, "zone", 2)
                if nfs then ZoneLevelLabel(nfs, zone, size, placed) end
            end
        end
    end
    -- 2) sub-regiões (só com a zona delas já grande na vista) e mares
    for _, L in ipairs(S.P.labels) do
        if p.used >= 90 then break end
        if L.x >= x0 and L.x <= x1 and L.y >= y0 and L.y <= y1 then
            local ext = L.ext * z
            local name = ext >= 45 and LabelName(L)
            if name and not S.P.zoneNames[name] and not names[name] then
                local zone = LabelZone(L)
                if not zone then
                    if IsSea(name) then Try(name, L.x, L.y, 9, 1, "sea") end
                elseif ext >= 60 and (zone.x1 - zone.x0) * z >= S.vw * 0.45 then
                    Try(name, L.x, L.y, ext >= 260 and 9 or 8, ext >= 140 and 1 or 0.9, "sub")
                end
            end
        end
    end
    PlaceLabels()
end

---------------------------------------------------------------------------
-- Ervas e minérios (dados: Modules/MapGather.lua)
---------------------------------------------------------------------------
local PIN_ICON = { herb = "Interface\\Icons\\INV_Misc_Flower_02", ore = "Interface\\Icons\\INV_Ore_Copper_01" }
local PIN_RIM = { herb = { 0.45, 0.85, 0.40 }, ore = { 0.95, 0.75, 0.40 } }
local PIN_CELL = 14             -- pontos mais perto que isso (pixels de tela) viram um pino só

local function PinGet()
    local p = S.pins
    p.used = p.used + 1
    local pin = p.list[p.used]
    if not pin then
        pin = { rim = p.parent:CreateTexture(nil, "ARTWORK", nil, 1), icon = p.parent:CreateTexture(nil, "ARTWORK", nil, 2) }
        pin.rim:SetTexture(UI .. "Disc.tga")
        pin.rim:SetSize(17, 17)
        pin.icon:SetSize(12, 12)
        pin.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        p.list[p.used] = pin
    end
    pin.rim:Show(); pin.icon:Show()
    return pin
end

local function PlacePins()
    local p = S.pins
    if not p then return end
    local z = S.zoom
    for i = 1, p.used do
        local pin = p.list[i]
        local sx, sy = S.ox + pin._x * z, S.oy - pin._y * z
        pin.rim:ClearAllPoints(); pin.rim:SetPoint("CENTER", S.view, "TOPLEFT", sx, sy)
        pin.icon:ClearAllPoints(); pin.icon:SetPoint("CENTER", S.view, "TOPLEFT", sx, sy)
    end
end

local function LayoutPins()
    local p = S.pins
    for i = 1, #p.list do p.list[i].rim:Hide(); p.list[i].icon:Hide() end
    p.used = 0
    local G = Azaath:GetModule("MapGather")
    if S.mode ~= "terrain" or not (G and G.AnyOn and G:AnyOn()) then return end
    local x0, y0, x1, y1 = Visible()
    local z = S.zoom
    local cells = {}
    for _, zone in ipairs(S.P.zones) do
        local zw, zh = zone.x1 - zone.x0, zone.y1 - zone.y0
        -- só com a zona já grande na vista (de longe seriam milhares de pontos)
        if zw * z >= S.vw * 0.3 and Overlaps(x0, y0, x1, y1, zone.x0, zone.y0, zone.x1, zone.y1) then
            for _, pt in ipairs(G:GetZonePoints(zone.id)) do
                local x, y = zone.x0 + pt.x * zw, zone.y0 + pt.y * zh
                if x >= x0 and x <= x1 and y >= y0 and y <= y1 and G:Shows(pt) then
                    local key = floor((x * z + S.ox) / PIN_CELL) .. ":" .. floor((y * z - S.oy) / PIN_CELL)
                    local c = cells[key]
                    if c then
                        c.pin.n = c.pin.n + (pt.count or 1)
                        c.pin.names[pt.name] = (c.pin.names[pt.name] or 0) + (pt.count or 1)
                    elseif p.used < 500 then
                        local pin = PinGet()
                        pin.icon:SetTexture(pt.icon or PIN_ICON[pt.kind] or PIN_ICON.herb)
                        local rim = PIN_RIM[pt.kind] or PIN_RIM.herb
                        pin.rim:SetVertexColor(rim[1] * 0.35, rim[2] * 0.35, rim[3] * 0.35, 0.95)
                        pin._x, pin._y, pin.n, pin.names = x, y, pt.count or 1, { [pt.name] = pt.count or 1 }
                        cells[key] = { pin = pin }
                    end
                end
            end
        end
    end
    PlacePins()
end

-- pino sob o cursor (para a dica)
local function PinAt(x, y)
    local p = S.pins
    if not (p and x) then return end
    local z, best, bd = S.zoom, nil, 81
    for i = 1, p.used do
        local pin = p.list[i]
        local dx, dy = (pin._x - x) * z, (pin._y - y) * z
        local d = dx * dx + dy * dy
        if d < bd then best, bd = pin, d end
    end
    return best
end

local function ShowPinTip(pin)
    local tt = GameTooltip
    tt:SetOwner(S.view, "ANCHOR_CURSOR")
    if pin.rare and not pin.lines then      -- raros: as linhas são montadas na hora (drops, respawn)
        local R = Azaath:GetModule("MapRares")
        pin.lines = R and R:TipLines(pin.rare) or {}
        pin.tempLines = true
    end
    if pin.title then                       -- lugares e grupo: título + linhas
        tt:AddLine(pin.title, 1, 0.82, 0.45)
        for _, l in ipairs(pin.lines or {}) do
            if type(l) == "table" then tt:AddLine(l[1], l[2], l[3], l[4], true)
            elseif l ~= "" then tt:AddLine(l, 0.85, 0.85, 0.85, true) end
        end
        tt:Show()
        S.tipPin = pin
        return
    end
    local list = {}
    for name, n in pairs(pin.names) do list[#list + 1] = { name, n } end
    table.sort(list, function(a, b) return a[2] > b[2] end)
    for i, e in ipairs(list) do
        if i > 8 then tt:AddLine("...", 0.7, 0.7, 0.7) break end
        tt:AddDoubleLine(e[1], e[2] > 1 and ("x" .. e[2]) or "", 1, 0.82, 0.45, 0.8, 0.8, 0.8)
    end
    tt:Show()
    S.tipPin = pin
end

---------------------------------------------------------------------------
-- Lugares: mestres de voo, entradas de masmorra, missões (dados do jogo, em tempo real)
--   voo ........ C_TaxiMap.GetTaxiNodesForMap (no continente; o seu lado e os neutros)
--   masmorras .. C_EncounterJournal.GetDungeonEntrancesForMap (em cada zona)
--   missões .... C_QuestLog.GetQuestsOnMap (em cada zona, só de perto)
---------------------------------------------------------------------------
local POI_RIM = { taxi = { 0.35, 0.62, 0.98 }, dungeon = { 0.95, 0.32, 0.25 }, raid = { 0.75, 0.38, 0.95 },
                  quest = { 0.98, 0.80, 0.30 }, questDone = { 0.98, 0.80, 0.30 },
                  rare = { 0.80, 0.82, 0.90 }, rareElite = { 1.00, 0.78, 0.25 }, rareLive = { 0.35, 1.00, 0.45 },
                  rareDead = { 0.55, 0.20, 0.18 } }
local POI_ICON = {
    taxi = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green",
    -- (só se o cliente não tiver os ícones de mapa "Dungeon" / "Raid" do próprio jogo)
    dungeon = "Interface\\Icons\\INV_Misc_Bone_HumanSkull_01",
    raid = "Interface\\Icons\\INV_Misc_Head_Dragon_01",
    quest = Azaath.media.path .. "Star.tga",
    questDone = "Interface\\GossipFrame\\ActiveQuestIcon",
    -- raros (Modules/MapRares.lua): a caveira da marca de alvo do jogo
    rare = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
    rareElite = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
    rareLive = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
    rareDead = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8",
}

-- raros no plano: { x, y, id, zone }, montados uma vez por plano (Data/Map/Rares.lua)
local function RarePlaces()
    if S.P.rares then return S.P.rares end
    local R = Azaath:GetModule("MapRares")
    local list = {}
    if R then
        for id in pairs(R:All()) do
            R:EachPoint(id, function(inst, X, Y)
                for _, c in ipairs(S.P.conts) do
                    if c.inst == inst then
                        local px, py = c.ax + c.bx * Y, c.ay + c.by * X
                        if px >= c.x0 and px <= c.x1 and py >= c.y0 and py <= c.y1 then
                            list[#list + 1] = { x = px, y = py, id = id, zone = (ZoneAt(px, py)) }
                        end
                        break
                    end
                end
            end)
        end
    end
    S.P.rares = list
    return list
end

local function PoiCached(key, fn)
    S.poiCache = S.poiCache or {}
    local v = S.poiCache[key]
    if v == nil then v = fn() or false; S.poiCache[key] = v end
    return v or {}
end

local function SetIcon(tex, atlas, fallback)
    if atlas and tex.SetAtlas and _G.C_Texture and C_Texture.GetAtlasInfo and Safe(C_Texture.GetAtlasInfo, atlas) then
        tex:SetAtlas(atlas)
        return true
    end
    tex:SetTexture(fallback)
    tex:SetTexCoord(0, 1, 0, 1)
    return false
end

local function PoiGet()
    local p = S.poi
    p.used = p.used + 1
    local e = p.list[p.used]
    if not e then
        e = { rim = p.parent:CreateTexture(nil, "ARTWORK", nil, 1), icon = p.parent:CreateTexture(nil, "ARTWORK", nil, 2) }
        e.rim:SetTexture(UI .. "Disc.tga")
        e.rim:SetSize(21, 21)
        e.icon:SetSize(15, 15)
        p.list[p.used] = e
    end
    e.rim:Show(); e.icon:Show()
    e.rim:SetSize(21, 21)
    e.icon:SetSize(15, 15)
    e.icon:SetVertexColor(1, 1, 1, 1)
    e.icon:SetBlendMode("BLEND")
    e.questID = nil
    return e
end

local function PlacePOI()
    local p = S.poi
    if not p then return end
    local z = S.zoom
    for i = 1, p.used do
        local e = p.list[i]
        local sx, sy = S.ox + e._x * z, S.oy - e._y * z
        e.rim:ClearAllPoints(); e.rim:SetPoint("CENTER", S.view, "TOPLEFT", sx, sy + (e.haloOff or 0))
        e.icon:ClearAllPoints(); e.icon:SetPoint("CENTER", S.view, "TOPLEFT", sx, sy + (e.lift or 0))
    end
end

local function FactionOK(node, mine)
    local f = node.faction
    local horde, alliance = 1, 2               -- Enum.FlightPathFaction
    if _G.Enum and Enum.FlightPathFaction then
        horde, alliance = Enum.FlightPathFaction.Horde or 1, Enum.FlightPathFaction.Alliance or 2
    end
    if f == horde then return mine == "Horde" end
    if f == alliance then return mine == "Alliance" end
    local a = node.atlasName or ""
    if a:find("Horde") then return mine == "Horde" end
    if a:find("Alliance") then return mine == "Alliance" end
    return true
end

local function QuestTip(questID)
    local title = Safe(C_QuestLog.GetTitleForQuestID, questID)
    if not title and C_QuestLog.GetLogIndexForQuestID and GetQuestLogTitle then
        local idx = Safe(C_QuestLog.GetLogIndexForQuestID, questID)
        title = idx and Safe(GetQuestLogTitle, idx)
    end
    local lines = {}
    local counted = false
    for _, o in ipairs(Safe(C_QuestLog.GetQuestObjectives, questID) or {}) do
        if (o.numRequired or 0) > 0 then counted = true end
        if o.text and o.text ~= "" then
            lines[#lines + 1] = o.finished and { o.text, 0.5, 0.85, 0.5 } or { o.text, 0.85, 0.85, 0.85 }
        end
    end
    return title or ("Missão " .. tostring(questID)), lines, counted
end

-- localizador de grupo do jogo: por mapa de instância, { name, wings = { {name, min, max} }, raid }
-- (nil se o cliente não tem GetLFGDungeonInfo; tabela vazia se tem mas não achou nada)
local function LFGByMap()
    if S.lfg ~= nil then return S.lfg or nil end
    if not _G.GetLFGDungeonInfo then S.lfg = false return nil end
    local byMap = {}
    for id = 1, 500 do
        local ok, name, _, subtype, minL, maxL, _, _, _, _, _, _, _, maxPlayers, _, _, _, _, _, _, _, _, mapID =
            pcall(GetLFGDungeonInfo, id)
        if ok and name and mapID and mapID > 0 then
            local e = byMap[mapID]
            if not e then e = { name = name, wings = {} }; byMap[mapID] = e end
            e.wings[#e.wings + 1] = { name, minL, maxL }
            if subtype == 3 or (maxPlayers and maxPlayers > 5) then e.raid = true end
        end
    end
    -- (nada achado: o cliente responde num formato diferente; melhor mostrar todas do que nenhuma)
    if not next(byMap) then S.lfg = false return nil end
    S.lfg = byMap
    return byMap
end

-- entradas das instâncias (Data/Map/Instances.lua) no plano: o continente é aquele em que o ponto
-- cai dentro de uma zona dele; o nome e os níveis vêm do localizador de grupo do jogo
-- A porta (Corpse da tabela Map) vem em jardas do mundo, sem o continente: o mesmo X/Y cai numa zona dos
-- dois continentes (a do Monastério Escarlate, em Tirisfal, caía no Vale Gris). As instâncias clássicas
-- de Kalimdor são fixas; as demais ficam nos Reinos do Leste (as desconhecidas: o primeiro que servir).
local KAL_UIMAP, EK_UIMAP = 1414, 1415
local KALIMDOR_INST = { [43] = true, [47] = true, [48] = true, [129] = true, [209] = true, [249] = true, [349] = true,
    [389] = true, [429] = true, [509] = true, [531] = true }
local EK_INST = { [33] = true, [34] = true, [36] = true, [44] = true, [70] = true, [90] = true, [109] = true, [189] = true,
    [229] = true, [230] = true, [289] = true, [309] = true, [329] = true, [409] = true, [469] = true, [533] = true }
-- área da masmorra (QuestSortID / AreaTable) -> instância (mapa): liga as missões de masmorra à porta
local DUNGEON_AREA_INST = { [796] = 189, [2557] = 429, [1584] = 230, [25] = 230, [1583] = 229, [2017] = 329,
    [2717] = 409, [722] = 129, [2057] = 289, [1417] = 109, [2100] = 349, [2159] = 249, [1581] = 36, [718] = 43,
    [209] = 33, [717] = 34, [719] = 48, [721] = 90, [491] = 47, [1337] = 70, [1176] = 209, [2437] = 389,
    [1977] = 309, [3429] = 509, [3428] = 531, [2677] = 469, [3456] = 533 }

local function InstanceConts(mapID)
    local want = KALIMDOR_INST[mapID] and KAL_UIMAP or (EK_INST[mapID] and EK_UIMAP)
    if not want then return S.P.conts end
    for _, c in ipairs(S.P.conts) do
        if c.id == want then return { c } end
    end
    return S.P.conts
end

local function InstancePlaces()
    if S.P.instances then return S.P.instances end
    local list, lfg = {}, LFGByMap()
    for _, e in ipairs((Azaath.MapData and Azaath.MapData.Instances) or {}) do
        local mapID, X, Y = e[1], e[2], e[3]
        local info = lfg and lfg[mapID]
        if info or not lfg then                -- (com o localizador: só as que ele conhece; sem ele: todas)
            for _, c in ipairs(InstanceConts(mapID)) do
                local px, py = c.ax + c.bx * Y, c.ay + c.by * X
                if px >= c.x0 and px <= c.x1 and py >= c.y0 and py <= c.y1 then
                    local z = ZoneAt(px, py)
                    if z and z.cont == c then
                        local name = info and info.name or Safe(GetRealZoneText, mapID) or ("Instância " .. mapID)
                        local lines = { info and info.raid and "Raide" or "Masmorra" }
                        for _, w in ipairs(info and info.wings or {}) do
                            local lv = (w[2] and w[3] and w[2] > 0) and (" (" .. w[2] .. "-" .. w[3] .. ")") or ""
                            lines[#lines + 1] = { w[1] .. lv, 0.85, 0.85, 0.85 }
                        end
                        list[#list + 1] = { x = px, y = py, name = name, raid = info and info.raid, lines = lines, zone = z,
                            ids = { [mapID] = true } }
                        break
                    end
                end
            end
        end
    end
    -- a mesma porta para dois mapas (fases, alas, raides vizinhas): um pino só, com os dois nomes
    local out = {}
    for _, a in ipairs(list) do
        local same
        for _, b in ipairs(out) do
            if abs(a.x - b.x) + abs(a.y - b.y) < 0.5 then same = b break end
        end
        if same then for id in pairs(a.ids) do same.ids[id] = true end end
        if not same then
            out[#out + 1] = a
        elseif same.name ~= a.name then
            same.name = same.name .. " / " .. a.name
            same.raid = same.raid or a.raid
            for i = 2, #a.lines do same.lines[#same.lines + 1] = a.lines[i] end
        end
    end
    S.P.instances = out
    return out
end

-- pins personalizados salvos (o antigo pin único vira o primeiro da lista)
local function UserPins()
    local db = M.db
    if db.userPin then
        db.userPins = db.userPins or {}
        table.insert(db.userPins, db.userPin)
        db.userPin = nil
    end
    db.userPins = db.userPins or {}
    return db.userPins
end

local function UserPinIndex(questID)
    return questID and questID <= -1000001 and questID > -2000000 and (-questID - 1000000) or nil
end

-- a navegação está seguindo este pin?
local function IsFollowed(up)
    local qn = Azaath:GetModule("QuestNav")
    local ct = qn and qn.GetCustomWaypoint and qn:GetCustomWaypoint()
    return ct and not ct.isCorpse and ct.mapID == up.mapID and math.abs(ct.x - up.nx) < 0.002 and math.abs(ct.y - up.ny) < 0.002
end

local function LayoutPOI()
    local p = S.poi
    for i = 1, #p.list do p.list[i].rim:Hide(); p.list[i].icon:Hide() end
    p.used = 0
    if S.mode ~= "terrain" or not S.place then return end     -- (mundo inteiro: só os continentes)
    local db = M.db
    local x0, y0, x1, y1 = Visible()
    local z = S.zoom

    -- missões no estilo da arte: losango ciano (em andamento), "?" dourado (entregar), "!" dourado (normal), "!" azul (repetível)
    local QUEST_PIN = {
        -- { textura, largura, nil, altura, subida } (tools/map-ui-concept/expedicao/fidel.js, medidos das capturas do Azaath)
        questProg = { "PinProgN2", 35, nil, 42, -4 },    -- em andamento: losango dourado com sombra e chevron (o losango cai no ponto)
        mark      = { "PinProgress", 26 },              -- losango azul: ponto marcado pelo guarda
        userPin   = { "PinUserY", 19, nil, 36, 15 },    -- alfinete redondo amarelo: pin personalizado (Ctrl+clique)
        questDone = { "PinDoneN3", 24, nil, 50, 23 },    -- entregar: alfinete verde (a ponta cai no ponto)
        questNew  = { "PinGetN2", 26, nil, 46, 22 },     -- pegar: losango vazado na agulha
        questRep  = { "PinGetB2", 26, nil, 46, 22 },    -- repetível: o mesmo em azul
    }
    local function Add(x, y, kind, atlas, title, lines, questID)
        if x < x0 or x > x1 or y < y0 or y > y1 or p.used >= 300 then return end
        local e = PoiGet()
        e.questID = questID
        local qp = QUEST_PIN[kind]
        if qp then
            e.rim:Hide()
            e.icon:SetTexture(FRAME_TEX .. qp[1])
            e.icon:SetTexCoord(0, 1, 0, 1)
            e.icon:SetSize(qp[2], qp[4] or qp[2])
            if qp[3] then e.icon:SetVertexColor(qp[3][1], qp[3][2], qp[3][3], 1)
            else e.icon:SetVertexColor(1, 1, 1, 1) end
            e.lift = qp[5] or 0
            e.hw, e.hh = qp[2] / 2, (qp[4] or qp[2]) / 2       -- área clicável = o desenho inteiro (não só a ponta)
            e._x, e._y, e.title, e.lines = x, y, title, lines
            e.rare = nil
            return e
        end
        e.rare = nil
        e.lift = 0
        e.hw, e.hh = nil, nil
        e.haloOff = 0
        local rim = POI_RIM[kind] or POI_RIM.taxi
        e.rim:SetVertexColor(rim[1] * 0.32, rim[2] * 0.32, rim[3] * 0.32, 0.95)
        -- masmorras e raides: o ícone de mapa do próprio jogo
        if (kind == "dungeon" or kind == "raid") and not atlas then atlas = kind == "raid" and "Raid" or "Dungeon" end
        local fromAtlas = SetIcon(e.icon, atlas, POI_ICON[kind])
        if (kind == "dungeon" or kind == "raid") and not fromAtlas then
            e.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)          -- (ícone de item: sem a moldura)
        end
        if kind == "quest" then e.icon:SetVertexColor(rim[1], rim[2], rim[3], 1) end
        if kind == "rareDead" then e.icon:SetVertexColor(0.55, 0.55, 0.55, 0.7) end
        if kind == "rare" or kind == "rareElite" or kind == "rareDead" then
            e.rim:SetSize(18, 18); e.icon:SetSize(13, 13)
        end
        e._x, e._y, e.title, e.lines = x, y, title, lines
        return e
    end

    -- voo (no continente)
    if db.poiTaxi ~= false and _G.C_TaxiMap and not S.taxiMode then   -- (no mestre de voo: Modules/MapTaxi.lua)
        local mine = UnitFactionGroup("player")
        for _, c in ipairs(S.P.conts) do
            if Overlaps(x0, y0, x1, y1, c.x0, c.y0, c.x1, c.y1) then
                for _, n in ipairs(PoiCached("taxi" .. c.id, function() return Safe(C_TaxiMap.GetTaxiNodesForMap, c.id) end)) do
                    local pos = n.position
                    local nx, ny
                    if pos and pos.GetXY then nx, ny = pos:GetXY() elseif pos then nx, ny = pos.x, pos.y end
                    if nx and ny and FactionOK(n, mine) then
                        Add(c.x0 + nx * (c.x1 - c.x0), c.y0 + ny * (c.y1 - c.y0), "taxi", n.atlasName, n.name, { "Mestre de voo" })
                    end
                end
            end
        end
    end
    -- masmorras e raides: as entradas que o jogo informa (se informar); senão, as da tabela Map
    local ejZones = {}
    -- masmorras e missões (por zona)
    for _, zone in ipairs(S.P.zones) do
        if Overlaps(x0, y0, x1, y1, zone.x0, zone.y0, zone.x1, zone.y1) then
            local zw, zh = zone.x1 - zone.x0, zone.y1 - zone.y0
            if db.poiDungeons ~= false and _G.C_EncounterJournal then
                local list = PoiCached("dun" .. zone.id, function()
                    return Safe(C_EncounterJournal.GetDungeonEntrancesForMap, zone.id)
                end)
                if #list > 0 then ejZones[zone] = true end
                for _, d in ipairs(list) do
                    local pos = d.position
                    if pos and pos.GetXY then
                        local nx, ny = pos:GetXY()
                        local raid = (d.atlasName or ""):lower():find("raid") and true or false
                        Add(zone.x0 + nx * zw, zone.y0 + ny * zh, raid and "raid" or "dungeon", d.atlasName, d.name,
                            { raid and "Raide" or "Masmorra", d.description or "" })
                    end
                end
            end
            if db.poiQuests ~= false and _G.C_QuestLog and C_QuestLog.GetQuestsOnMap and zw * z >= S.vw * 0.3 then
                for _, q in ipairs(PoiCached("q" .. zone.id, function() return Safe(C_QuestLog.GetQuestsOnMap, zone.id) end)) do
                    if q.x and q.y and q.questID then
                        local done = Safe(C_QuestLog.IsComplete, q.questID)
                        local title, lines, counted = QuestTip(q.questID)
                        if done then table.insert(lines, 1, { "Pronta para entregar", 0.5, 0.85, 0.5 }) end
                        local kind = done and "questDone" or (counted and "questProg" or "questNew")
                        -- em andamento: área dos objetivos (QuestAreas.lua); a posição do jogo erra em algumas
                        local qx, qy = q.x, q.y
                        local qn = not done and Azaath:GetModule("QuestNav")
                        local skip = false
                        if qn and qn.GetQuestAreaPos then
                            local ax, ay = qn:GetQuestAreaPos(q.questID, zone.id)
                            if ax then
                                qx, qy = ax, ay
                            else
                                -- tem área nos dados, mas noutra zona: o ponto do jogo aqui é a marca errada (pin duplicado)
                                local QA = Azaath.QuestAreaData
                                skip = QA and QA.quests and QA.quests[q.questID] ~= nil
                                    and QA.zones and QA.zones[q.questID] and QA.zones[q.questID] ~= zone.id
                            end
                        end
                        if not skip then
                            Add(zone.x0 + qx * zw, zone.y0 + qy * zh, kind, nil, title, lines, q.questID)
                        end
                    end
                end
                local qdb = Azaath:GetModule("QuestDB")
                if qdb and qdb.GetZoneQuests then
                    for _, item in ipairs(PoiCached("lm" .. zone.id, function() return (qdb:GetZoneQuests(zone.id)) or {} end)) do
                        local q = item.quest
                        if item.status == "available" and q and q.sMap == zone.id
                           and q.sX and q.sX > 0 and q.sY and q.sY > 0 then
                            local kind = q.repeatable and "questRep" or "questNew"
                            local tip = q.repeatable and "Missão repetível" or "Disponível para pegar"
                            local tc = q.repeatable and { 0.35, 0.82, 1.00 } or { 0.98, 0.80, 0.30 }
                            Add(zone.x0 + (q.sX / 100) * zw, zone.y0 + (q.sY / 100) * zh, kind, nil, item.title,
                                { { string.format("Nv. %d · %s", q.level or 0, tip), tc[1], tc[2], tc[3] } }, q.id)
                        end
                    end
                end
            end
        end
    end
    -- raros (Modules/MapRares.lua): os pontos de spawn com a zona já grande na vista; os vistos agora, sempre
    local R = db.poiRares ~= false and Azaath:GetModule("MapRares")
    if R then
        local live = {}
        for id, s in pairs(R:State().seen) do
            local px, py
            if R:SeenRecently(id) and R:Shows(id) then
                local uz = S.P.byID[s.map]
                if uz then
                    px, py = uz.x0 + s.x * (uz.x1 - uz.x0), uz.y0 + s.y * (uz.y1 - uz.y0)
                elseif s.inst and s.X then           -- (subzona fora do plano: pela posição no mundo)
                    for _, c in ipairs(S.P.conts) do
                        if c.inst == s.inst then px, py = c.ax + c.bx * s.Y, c.ay + c.by * s.X break end
                    end
                end
            end
            if px then
                local info = R:Info(id)
                local e = Add(px, py, "rareLive", nil,
                    info and info.name or ("Raro " .. id), R:TipLines(id, true))
                if e then e.rare = id; e.rim:SetSize(24, 24); e.icon:SetSize(16, 16) end
                live[id] = true
            end
        end
        for _, r in ipairs(RarePlaces()) do
            local zone = r.zone
            if not live[r.id] and zone and (zone.x1 - zone.x0) * z >= S.vw * 0.3 and R:Shows(r.id) then
                local info = R:Info(r.id)
                local kind = R:RespawnLeft(r.id) and "rareDead" or (info and info.elite and "rareElite" or "rare")
                local e = Add(r.x, r.y, kind, nil, info and info.name or ("Raro " .. r.id), nil)
                if e then e.rare = r.id; e.lines = nil end
            end
        end
    end
    if S.customPin and S.customPin.x and S.customPin.y then
        Add(S.customPin.x, S.customPin.y, "mark", nil, S.customPin.label or "Destino marcado",
            { { "Ponto marcado", 0.37, 0.89, 0.90 }, { "Clique: seguir com o caminho mágico", 0.6, 0.6, 0.6 } }, -999999)
    end
    -- pins personalizados: ficam no mapa até serem removidos (independem da missão selecionada);
    -- o "questID" deles é -(1000000 + índice), para o clique saber qual é
    for i, up in ipairs(UserPins()) do
        local uz = S.P.byID[up.mapID]
        if uz then
            local lines = {}
            if up.name and up.name ~= "" then lines[#lines + 1] = { up.label or "", 0.62, 0.62, 0.62 } end
            if up.note and up.note ~= "" then lines[#lines + 1] = { up.note, 0.95, 0.92, 0.82 } end
            lines[#lines + 1] = { "Clique: seguir · Botão direito: editar · Ctrl+clique: remover", 0.6, 0.6, 0.6 }
            Add(uz.x0 + up.nx * (uz.x1 - uz.x0), uz.y0 + up.ny * (uz.y1 - uz.y0), "userPin", nil,
                (up.name and up.name ~= "") and up.name or (up.label or "Ponto marcado"), lines, -(1000000 + i))
        end
    end
    if db.poiDungeons ~= false then
        for _, inst in ipairs(InstancePlaces()) do
            if not ejZones[inst.zone] then
                Add(inst.x, inst.y, inst.raid and "raid" or "dungeon", nil, inst.name, inst.lines)
            end
        end
    end
    PlacePOI()
end

---------------------------------------------------------------------------
-- Grupo: os membros do grupo/raide no plano, na cor da classe (ao vivo)
---------------------------------------------------------------------------
-- posição de uma unidade no plano de terreno (nil fora dos continentes, ex.: dentro de instâncias)
local function UnitPlane(unit)
    local best = Safe(C_Map.GetBestMapForUnit, unit)
    if not best then return end
    local pos = Safe(C_Map.GetPlayerMapPosition, best, unit)
    if not pos then return end
    local inst, wp = Safe(C_Map.GetWorldPosFromMapPos, best, pos)
    if not (inst and wp) then return end
    local X, Y = wp:GetXY()
    for _, c in ipairs(S.P.conts) do
        if c.inst == inst then return c.ax + c.bx * Y, c.ay + c.by * X end
    end
end

local function GroupUnits()
    local out = {}
    if IsInRaid and IsInRaid() then
        for i = 1, (GetNumGroupMembers and GetNumGroupMembers() or 0) do
            local u = "raid" .. i
            if not UnitIsUnit(u, "player") then out[#out + 1] = u end
        end
    else
        for i = 1, 4 do
            if UnitExists("party" .. i) then out[#out + 1] = "party" .. i end
        end
    end
    return out
end

local function UpdateGroup()
    local g = S.group
    if not g then return end
    for i = 1, #g.list do g.list[i].dot:Hide(); g.list[i].ring:Hide() end
    g.used = 0
    if S.mode ~= "terrain" or M.db.poiGroup == false then return end
    local z = S.zoom
    for _, u in ipairs(GroupUnits()) do
        local x, y = UnitPlane(u)
        if x then
            g.used = g.used + 1
            local e = g.list[g.used]
            if not e then
                e = { ring = g.parent:CreateTexture(nil, "ARTWORK", nil, 1), dot = g.parent:CreateTexture(nil, "ARTWORK", nil, 2) }
                e.ring:SetTexture(UI .. "Disc.tga"); e.ring:SetSize(13, 13); e.ring:SetVertexColor(0, 0, 0, 0.9)
                e.dot:SetTexture(UI .. "Disc.tga"); e.dot:SetSize(9, 9)
                g.list[g.used] = e
            end
            local _, class = UnitClass(u)
            local cc = class and _G.RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
            e.dot:SetVertexColor(cc and cc.r or 0.4, cc and cc.g or 0.8, cc and cc.b or 1, 1)
            local sx, sy = S.ox + x * z, S.oy - y * z
            e.ring:ClearAllPoints(); e.ring:SetPoint("CENTER", S.view, "TOPLEFT", sx, sy)
            e.dot:ClearAllPoints(); e.dot:SetPoint("CENTER", S.view, "TOPLEFT", sx, sy)
            e.ring:Show(); e.dot:Show()
            e._x, e._y = x, y
            e.title = UnitName(u)
            local lv = UnitLevel(u)
            e.lines = { (lv and lv > 0 and ("Nível " .. lv .. " ") or "") .. (UnitClass(u) or "") }
        end
    end
end

-- o que está sob o cursor, para a dica: grupo, depois lugares, depois ervas e minérios
local function HitAt(x, y)
    if not x then return end
    local z, best, bd = S.zoom, nil, 81
    local function Scan(pool, n)
        for i = 1, n do
            local e = pool.list[i]
            local dx, dy = (e._x - x) * z, (e._y - y) * z
            local d = dx * dx + dy * dy
            if d < bd then best, bd = e, d end
        end
    end
    if S.group then Scan(S.group, S.group.used) end
    if best then return best end
    if S.poi then
        -- pinos de missão: acerta em qualquer parte do desenho (retângulo do ícone, já com a subida)
        for i = S.poi.used, 1, -1 do
            local e = S.poi.list[i]
            if e.hh then
                local dx = (x - e._x) * z
                local dy = (e._y - y) * z - (e.lift or 0)          -- y para cima, relativo ao centro do ícone
                if math.abs(dx) <= e.hw + 2 and math.abs(dy) <= e.hh + 2 then return e end
            end
        end
        Scan(S.poi, S.poi.used)
    end
    if best then return best end
    return PinAt(x, y)
end

---------------------------------------------------------------------------
-- Áreas das missões (onde ficam os monstros/objetivos): a forma é a do próprio jogo
-- (QuestPOIFrame:DrawBlob, um quadro por zona com o mapa dela), pintada no lugar do azul padrão
-- com um âmbar semitransparente e um filete claro. ATENÇÃO: esse quadro só carrega
-- texturas dos arquivos do jogo (as de addon, TGA ou BLP, saem verdes = textura ausente); por isso
-- o preenchimento é o âmbar liso ButtonsYellowOrange64 e a borda a faixa ButtonsGoldGradiant
-- (dourado claro no contorno, bronze para fora). A missão selecionada vai por cima, mais forte.
---------------------------------------------------------------------------
-- Como no Polestar: só a área da missão em foco (a selecionada), com um véu âmbar bem leve e um
-- filete fino e claro (WHITE8X8 do jogo, em baixa opacidade, sobre o terreno lê como creme).
local BLOB_LOOK = { 26, 150, 0.18 }                                         -- preenchimento, borda (0-255), espessura
local BLOB_FILL, BLOB_EDGE = "Interface\\Buttons\\YellowOrange64", "Interface\\Buttons\\WHITE8X8"

-- diagnóstico (AzaathUIDB.worldmap.blobDiag): as funções que o quadro de área tem neste cliente
-- (procurando um jeito de tingir o filete de dourado)
local function BlobDiag(f)
    if M.db.blobDiag then return end
    local names = {}
    local mt = getmetatable(f)
    local idx = mt and mt.__index
    if type(idx) == "table" then
        for k, v in pairs(idx) do
            if type(v) == "function" and (k:find("Blob") or k:find("Fill") or k:find("Border") or k:find("Color")
                or k:find("Draw") or k:find("Map") or k:find("Scalar") or k:find("Mask")) then
                names[#names + 1] = k
            end
        end
    end
    table.sort(names)
    M.db.blobDiag = table.concat(names, " ")
end

local function BlobGet()
    local p = S.blobs
    p.used = p.used + 1
    local f = p.list[p.used]
    if not f then
        local ok, made = pcall(CreateFrame, "QuestPOIFrame", nil, p.parent)
        if not ok or not made then p.used = p.used - 1 return nil end
        f = made
        if f.EnableMouse then f:EnableMouse(false) end
        pcall(f.SetFillTexture, f, BLOB_FILL)
        pcall(f.SetBorderTexture, f, BLOB_EDGE)
        pcall(f.SetFillAlpha, f, BLOB_LOOK[1])
        pcall(f.SetBorderAlpha, f, BLOB_LOOK[2])
        pcall(f.SetBorderScalar, f, BLOB_LOOK[3])
        pcall(BlobDiag, f)
        p.list[p.used] = f
    end
    f:Show()
    return f
end

-- ao mover: a área acompanha; no zoom ela some (o jogo a desenhou num tamanho) e volta
-- redesenhada no tamanho certo quando o zoom termina (Redraw -> LayoutBlobs)
local function PlaceBlobs()
    local p = S.blobs
    if not p then return end
    local z = S.zoom
    for i = 1, p.used do
        local f = p.list[i]
        if math.abs(z - (f.drawZoom or 0)) > 1e-4 then
            f:Hide()
        else
            local zone = f.zone
            f:ClearAllPoints()
            f:SetPoint("TOPLEFT", S.view, "TOPLEFT", S.ox + zone.x0 * z, S.oy - zone.y0 * z)
            f:Show()
        end
    end
end

local function LayoutBlobs()
    local p = S.blobs
    if not p then return end
    for i = 1, #p.list do
        local f = p.list[i]
        pcall(f.DrawNone, f)
        f:Hide()
    end
    p.used = 0
    if S.hullsActive then return end
    local qid = S.selQuest
    if not qid or S.mode ~= "terrain" or M.db.poiQuests == false or M.db.questAreas == false then return end
    if not (_G.C_QuestLog and C_QuestLog.GetQuestsOnMap) or Safe(C_QuestLog.IsComplete, qid) then return end
    local x0, y0, x1, y1 = Visible()
    local z = S.zoom
    for _, zone in ipairs(S.P.zones) do
        if (zone.x1 - zone.x0) * z >= S.vw * 0.3 and Overlaps(x0, y0, x1, y1, zone.x0, zone.y0, zone.x1, zone.y1) then
            for _, q in ipairs(PoiCached("q" .. zone.id, function() return Safe(C_QuestLog.GetQuestsOnMap, zone.id) end)) do
                if q.questID == qid then
                    local f = BlobGet()
                    if f then
                        f.zone, f.drawZoom = zone, z
                        pcall(f.SetMapID, f, zone.id)
                        f:ClearAllPoints()
                        f:SetPoint("TOPLEFT", S.view, "TOPLEFT", S.ox + zone.x0 * z, S.oy - zone.y0 * z)
                        f:SetSize(max(1, (zone.x1 - zone.x0) * z), max(1, (zone.y1 - zone.y0) * z))
                        pcall(f.DrawBlob, f, qid, true)
                    end
                    break
                end
            end
        end
    end
end

---------------------------------------------------------------------------
-- Áreas das missões no estilo do Polestar (pedido do usuário, 2026-11-17): as regiões onde ficam os
-- monstros/objetos de cada missão do diário, com os dados próprios (Data/Map/QuestAreas.lua, do
-- banco do Polestar; não precisa dele ligado) e o agrupamento dele (Modules/MapRegions.lua),
-- desenhadas como as dele: um véu dourado leve e um filete fino.
-- O desenho de polígono com quadriláteros dobrados (SetVertexOffset) e o recuo da borda seguem o
-- layHull do Polestar (Nav/Pins.lua, GPL-3.0-only, "The Polestar authors"), adaptado ao plano deste mapa.
-- Sem esses dados, fica a mancha do próprio jogo (QuestPOIFrame, abaixo).
---------------------------------------------------------------------------
-- (como no Polestar, só as áreas da missão em foco; o filete usa Media/MapFrame/AreaRim, um degradê
-- na largura dele: transparente fora, forte logo dentro e descendo até o véu -> borda sem serrilhado)
local HULL = { r = 0.98, g = 0.82, b = 0.44,
    selFill = 0.22, selRim = 0.92,    -- véu e filete (o fim do degradê do filete = 0.24 = véu / filete)
    width = 4 }                       -- largura do degradê do filete, em pixels da tela
local RIM_TEX = FRAME_TEX .. "AreaRim"
local hx, hy, inX, inY = {}, {}, {}, {}


-- as regiões de uma missão (guardadas até o diário mudar): os lugares dos objetivos ainda não
-- cumpridos (Data/Map/QuestAreas.lua: monstros que matar, objetos que usar, quem deixa cair os itens)
-- agrupados em regiões (Modules/MapRegions.lua); como no Polestar, só 3 ou mais pontos viram área.
-- { { c = instância, hull = { wx1, wy1, ... }, quest = questID }, ... }
local function ToWorld(map, f, x, y)
    local D = Azaath.QuestAreaData
    if f == 0 then
        local fr = D.frames[map]
        if not fr then return end
        return fr[1], fr[2] + (fr[3] - fr[2]) * y / 100, fr[4] + (fr[5] - fr[4]) * x / 100
    end
    if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
    local c, pos = Safe(C_Map.GetWorldPosFromMapPos, map, CreateVector2D(x / 100, y / 100))
    if not (c and pos) then return end
    local wx, wy = pos:GetXY()
    return c, wx, wy
end

local function QuestHulls(qid)
    S.qhCache = S.qhCache or {}
    local v = S.qhCache[qid]
    if v then return v end
    v = {}
    local D, R = Azaath.QuestAreaData, Azaath.MapRegions
    local per = D and D.quests[qid]
    if per and R and R.Of then
        local objs = Safe(C_QuestLog.GetQuestObjectives, qid) or {}
        local cs, xs, ys, rs, n = {}, {}, {}, {}, 0
        local zone = D.zones and D.zones[qid]
        for i, keys in ipairs(per) do
            local o = objs[i]
            if keys ~= "" and not (o and o.finished) then
                -- os blocos (mapa, lugares) do objetivo; se algum fica na zona da missão, só esses
                -- (um item que também cai em outras zonas não puxa a área para o outro lado do mundo)
                local blocks, inZone = {}, false
                for key in keys:gmatch("%S+") do
                    local txt = D.spawns[key]
                    if txt then
                        for block in txt:gmatch("[^|]+") do
                            local map, f, rest = block:match("^(%d+),(%d+):(.*)$")
                            map, f = tonumber(map), tonumber(f)
                            if map and rest then
                                blocks[#blocks + 1] = { map, f, rest }
                                if map == zone then inZone = true end
                            end
                        end
                    end
                end
                for _, b in ipairs(blocks) do
                    if not inZone or b[1] == zone then
                        for x, y, r in b[3]:gmatch("([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)") do
                            local c, wx, wy = ToWorld(b[1], b[2], tonumber(x), tonumber(y))
                            if c and wx then
                                n = n + 1
                                cs[n], xs[n], ys[n], rs[n] = c, wx, wy, tonumber(r) or 0
                            end
                        end
                    end
                end
            end
        end
        if n > 0 then
            local regs = Safe(R.Of, cs, xs, ys, rs)
            for _, rg in ipairs(type(regs) == "table" and regs or {}) do
                if type(rg.hull) == "table" then
                    v[#v + 1] = { c = rg.c, hull = rg.hull, quest = qid, m = #(rg.members or {}) }
                end
            end
        end
    end
    S.qhCache[qid] = v
    return v
end

local function HullTex()
    local p = S.hulls
    p.used = p.used + 1
    local t = p.list[p.used]
    if not t then
        t = p.holder:CreateTexture(nil, "ARTWORK")
        t:SetTexture("Interface\\Buttons\\WHITE8X8")
        if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
        if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
        p.list[p.used] = t
    end
    t:Show()
    return t
end

-- dobra o quadrilátero da textura t sobre a, b, c, d (sentido horário, unidades locais em volta
-- do centro do retângulo de meias-medidas hw, hh; y para cima)
local function Bend(t, hw, hh, ax, ay, bx, by, cx, cy, dx, dy)
    t:SetVertexOffset(1, ax + hw, ay - hh)
    t:SetVertexOffset(3, bx - hw, by - hh)
    t:SetVertexOffset(4, cx - hw, cy + hh)
    t:SetVertexOffset(2, dx + hw, dy + hh)
end

-- um polígono convexo de n pontos (hx/hy, em pixels de tela relativos a cx, cy; y para cima):
-- preenchimento em leque e um filete de `rim` pixels por aresta
local function LayHull(n, cx, cy, rim, fillA, rimA)
    local area2, hw, hh, mx, my = 0, 0, 0, 0, 0
    for i = 1, n do
        local j = i % n + 1
        area2 = area2 + hx[i] * hy[j] - hx[j] * hy[i]
        hw, hh = max(hw, abs(hx[i])), max(hh, abs(hy[i]))
        mx, my = mx + hx[i] / n, my + hy[i] / n
    end
    if hw < 1 or hh < 1 then return end
    if area2 > 0 then               -- anti-horário: os cantos dos quadriláteros andam no horário
        for i = 1, floor(n / 2) do
            local j = n + 1 - i
            hx[i], hx[j] = hx[j], hx[i]
            hy[i], hy[j] = hy[j], hy[i]
        end
    end
    local inner = math.huge
    for i = 1, n do
        local j = i % n + 1
        local dx, dy = hx[j] - hx[i], hy[j] - hy[i]
        local len = math.sqrt(dx * dx + dy * dy)
        if len < 1e-6 then return end
        local nx, ny = -dy / len, dx / len
        inX[i], inY[i] = nx, ny
        local d = (hx[i] - mx) * nx + (hy[i] - my) * ny
        if d < inner then inner = d end
    end
    local w = min(rim, max(0, inner * 0.4))
    local px, py = inX[n], inY[n]
    for i = 1, n do
        local nx, ny = inX[i], inY[i]
        local k = w / (1 + px * nx + py * ny)
        inX[i], inY[i] = hx[i] - (px + nx) * k, hy[i] - (py + ny) * k
        px, py = nx, ny
    end
    local function Quad(a1, a2, b1, b2, c1, c2, d1, d2, alpha, tex)
        local t = HullTex()
        t:SetTexture(tex or "Interface\\Buttons\\WHITE8X8")
        t:SetTexCoord(0, 1, 0, 1)
        t:ClearAllPoints()
        t:SetPoint("CENTER", S.hulls.holder, "TOPLEFT", cx, cy)
        t:SetSize(2 * hw, 2 * hh)
        Bend(t, hw, hh, a1, a2, b1, b2, c1, c2, d1, d2)
        t:SetVertexColor(HULL.r, HULL.g, HULL.b, alpha)
    end
    for k = 2, n - 1, 2 do
        local k2 = k + 2 > n and n or k + 2
        Quad(inX[1], inY[1], inX[k], inY[k], inX[k + 1], inY[k + 1], inX[k2], inY[k2], fillA)
    end
    for i = 1, n do
        local j = i % n + 1
        Quad(hx[i], hy[i], hx[j], hy[j], inX[j], inY[j], inX[i], inY[i], rimA, RIM_TEX)
    end
end

-- posição da camada das áreas (ao mover; no zoom animado ela é esticada até o redesenho)
local function PlaceHulls()
    local p = S.hulls
    if not (p and p.dz) then return end
    local r = S.zoom / p.dz
    p.holder:SetScale(r)
    p.holder:ClearAllPoints()
    p.holder:SetPoint("TOPLEFT", S.view, "TOPLEFT", S.ox / r, S.oy / r)
end

-- desenha as áreas do Polestar à vista; devolve false se o Polestar não as tem (vale a do jogo)
local function LayoutHulls()
    local p = S.hulls
    if not p then return false end
    for i = 1, #p.list do p.list[i]:Hide() end
    p.used = 0
    S.hullHit = {}                    -- polígonos desenhados (no plano), para a dica ao passar o mouse
    if S.mode ~= "terrain" or M.db.poiQuests == false or M.db.questAreas == false then return true end
    local Qm = Azaath:GetModule("MapQuests")
    if not (Azaath.QuestAreaData and Azaath.MapRegions and Qm and Qm.List) then return false end
    local z = S.zoom
    -- só a missão em foco (como no Polestar), com todas as regiões dela, mesmo as de 1 ou 2 pontos
    local pins = {}
    if S.selQuest and not Safe(C_QuestLog.IsComplete, S.selQuest) then
        for _, h in ipairs(QuestHulls(S.selQuest)) do pins[#pins + 1] = h end
    end
    p.dz = z
    PlaceHulls()
    local x0, y0, x1, y1 = Visible()
    local cont = {}
    for _, c in ipairs(S.P.conts) do cont[c.inst] = c end
    -- (o filete com HULL.width pixels da tela, em qualquer escala de interface)
    local pf = (PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()) or 1
    local W = HULL.width * pf / max(0.01, S.view:GetEffectiveScale() or 1)
    local count = 0
    -- primeiro as outras, depois a em foco (por cima)
    for pass = 1, 2 do
        for _, pin in ipairs(pins) do
            local hull = pin.hull
            local c = type(hull) == "table" and cont[pin.c]
            if c and #hull >= 6 then
                local sel = S.selQuest ~= nil and pin.quest == S.selQuest
                if (pass == 2) == sel then
                    -- os pontos no plano e o retângulo deles
                    local n, bx0, by0, bx1, by1 = 0, math.huge, math.huge, -math.huge, -math.huge
                    for k = 1, #hull - 1, 2 do
                        local wx, wy = hull[k], hull[k + 1]
                        local px, py = c.ax + c.bx * wy, c.ay + c.by * wx
                        n = n + 1
                        hx[n], hy[n] = px, py
                        if px < bx0 then bx0 = px end
                        if px > bx1 then bx1 = px end
                        if py < by0 then by0 = py end
                        if py > by1 then by1 = py end
                    end
                    -- à vista e com tamanho para se ver (alguns pixels na tela)
                    if n >= 3 and Overlaps(x0, y0, x1, y1, bx0, by0, bx1, by1) and (bx1 - bx0) * z >= 6 then
                        local poly = { quest = pin.quest, x0 = bx0, y0 = by0, x1 = bx1, y1 = by1 }
                        for k = 1, n do poly[#poly + 1] = hx[k]; poly[#poly + 1] = hy[k] end
                        S.hullHit[#S.hullHit + 1] = poly
                        local cx, cy = (bx0 + bx1) / 2 * z, (by0 + by1) / 2 * z
                        for k = 1, n do
                            hx[k], hy[k] = hx[k] * z - cx, cy - hy[k] * z     -- local, y para cima
                        end
                        LayHull(n, cx, -cy, W, HULL.selFill, HULL.selRim)
                        count = count + 1
                    end
                end
            end
        end
    end
    M.db.hullDiag = { time = date("%H:%M:%S"), pins = #pins, drawn = count }
    return true
end

-- as áreas: as do Polestar se ele estiver ligado; senão, a mancha do jogo
local function LayoutAreas()
    S.hullsActive = LayoutHulls()
    LayoutBlobs()
end

S.onPan = function() PlaceLabels(); PlacePins(); PlacePOI(); PlaceBlobs(); PlaceHulls(); UpdateGroup() end

---------------------------------------------------------------------------
-- Arte pintada (uma página por mapa)
---------------------------------------------------------------------------
local function DrawPiece(x, y, w, h, fids, first, explored)
    local cols = ceil(w / TILE)
    local n = 0
    for i = first, #fids do
        local fid = fids[i]
        local col, row = n % cols, floor(n / cols)
        local pw, ph = min(TILE, w - col * TILE), min(TILE, h - row * TILE)
        if pw > 0 and ph > 0 and fid and fid > 0 then
            local t = PoolGet(S.reveal)
            t:SetTexture(fid)
            Place(t, x + col * TILE, y + row * TILE, pw, ph)
            t:SetTexCoord(0, pw / FileSize(pw), 0, ph / FileSize(ph))
            if not explored then
                t:SetDesaturated(true)
                t:SetVertexColor(DIM, DIM, DIM, 1)
            end
        end
        n = n + 1
    end
end

local function DrawArt(mapID)
    local layers = Safe(C_Map.GetMapArtLayers, mapID)
    local L = layers and layers[1]
    local files = Safe(C_Map.GetMapArtLayerTextures, mapID, 1)
    if not (L and files and #files > 0) then return false end
    local tw, th = L.tileWidth or TILE, L.tileHeight or TILE
    local cols = ceil((L.layerWidth or W) / tw)
    local sx, sy = W / (L.layerWidth or W), H / (L.layerHeight or H)
    for i, fid in ipairs(files) do
        local col, row = (i - 1) % cols, floor((i - 1) / cols)
        local t = PoolGet(S.base)
        t:SetTexture(fid)
        Place(t, col * tw * sx, row * th * sy, tw * sx, th * sy)
    end
    local explored = Safe(C_MapExplorationInfo.GetExploredMapTextures, mapID) or {}
    local artID = Safe(C_Map.GetMapArtID, mapID)
    local pieces = artID and Azaath.MapData and Azaath.MapData.Reveal and Azaath.MapData.Reveal[artID]
    S.pagePieces = pieces
    if pieces then
        local seen = {}
        for _, e in ipairs(explored) do seen[(e.offsetX or 0) .. ":" .. (e.offsetY or 0)] = true end
        for _, p in ipairs(pieces) do
            local ok = seen[p[1] .. ":" .. p[2]]
            if M.db.revealAll then ok = true end
            if ok or M.db.showUnexplored then DrawPiece(p[1], p[2], p[3], p[4], p, 6, ok) end
        end
    else
        for _, e in ipairs(explored) do
            DrawPiece(e.offsetX or 0, e.offsetY or 0, e.textureWidth or 0, e.textureHeight or 0, e.fileDataIDs or {}, 1, true)
        end
    end
    return true
end

---------------------------------------------------------------------------
-- Redesenho, título, jogador, nome sob o mouse
---------------------------------------------------------------------------
-- o caminho do lugar atual (Azeroth > continente > zona), para a barra superior da moldura
local function UpdateTitle()
    local chain = {}
    local world = (Safe(C_Map.GetMapInfo, WORLD) or {}).name or "Azeroth"
    if S.mode == "terrain" then
        local p = S.place
        chain[1] = { name = world, mapID = WORLD }
        if p and p.kind == "zone" then
            chain[2] = { name = p.cont.name, mapID = p.cont.id }
            chain[3] = { name = p.name, mapID = p.id }
        elseif p then
            chain[2] = { name = p.name, mapID = p.id }
        end
    else
        local id, guard = S.mapID, 0
        while id and id > 0 and guard < 8 do
            local info = Safe(C_Map.GetMapInfo, id)
            if not info then break end
            table.insert(chain, 1, { name = info.name, mapID = id })
            id, guard = info.parentMapID, guard + 1
        end
    end
    S.crumbs = chain
    if M.ui and M.ui.SetBreadcrumb then M.ui:SetBreadcrumb(chain) end
end

local function ResetCanvas(cv)
    PoolReset(cv.base); PoolReset(cv.reveal); PoolReset(cv.lit); PoolReset(cv.baseW); PoolReset(cv.litW); PoolReset(cv.inner)
    for i = 1, #cv.masks.list do cv.masks.list[i]:Hide() end
    cv.masks.used = 0
end

-- a camada nova só aparece quando o jogo terminou de ler todas as texturas dela (quadros, máscaras de
-- costa, lagos): até lá fica quase invisível (1%, para o jogo carregar) e a anterior continua à vista.
-- Sem isso, ao aproximar/afastar rápido, os quadros apareciam um instante sem o recorte da costa.
local REVEAL_MAX = 0.6
local function CanvasTextures(cv)
    local list = {}
    for _, p in ipairs({ cv.base, cv.baseW, cv.lit, cv.litW, cv.reveal, cv.inner }) do
        for i = 1, p.used do list[#list + 1] = p.list[i] end
    end
    for i = 1, cv.masks.used do list[#list + 1] = cv.masks.list[i] end
    return list
end

local function OtherCanvas(cv) return cv == S.cvA and S.cvB or S.cvA end

local function RevealCanvas(cv)
    cv.pending = nil
    cv.frame:SetAlpha(1)
    local old = OtherCanvas(cv)
    if old.frame:IsShown() then old.hideAt = GetTime() + 0.1 end
end

local function CanvasLoaded(cv)
    for i = 1, #cv.pending do
        local t = cv.pending[i]
        if t.IsObjectLoaded and not t:IsObjectLoaded() then return false end
    end
    return true
end

-- desenha na camada de trás; enquanto ela carrega, a da frente (a que está à vista) não é tocada —
-- se o mapa mudar de novo nesse meio tempo, redesenha na mesma camada que ainda carrega
local function Redraw()
    local cv
    if S.front and S.front.pending then cv = S.front else cv = OtherCanvas(S.front or S.cvB) end
    -- (o prazo conta da primeira vez que esta camada ficou esperando: arrastando sem parar, ela não fica escondida)
    local deadline = cv.pending and cv.revealBy or (GetTime() + REVEAL_MAX)
    ResetCanvas(cv)
    S.canvas, S.base, S.reveal, S.lit, S.masks = cv.frame, cv.base, cv.reveal, cv.lit, cv.masks
    S.baseW, S.litW, S.inner = cv.baseW, cv.litW, cv.inner
    cv.dz = S.zoom
    cv.hideAt = nil
    PositionCanvas(cv)
    cv.frame:SetFrameLevel(S.levelTop)
    cv.frame:SetAlpha(0.01)
    cv.frame:Show()
    S.front = cv
    local old = OtherCanvas(cv)
    old.frame:SetFrameLevel(S.levelLow)
    old.hideAt = nil
    if S.mode ~= "terrain" then S.sea:SetVertexColor(1, 1, 1, 1) end
    local ok = true
    if S.mode == "terrain" then
        S.place = CurrentPlace()
        DrawTerrain()
    else
        ok = DrawArt(S.mapID)
    end
    S.empty:SetShown(not ok)
    S.lastDraw = GetTime()
    S.dirty = false
    cv.pending = CanvasTextures(cv)
    cv.revealBy = deadline
    if CanvasLoaded(cv) then RevealCanvas(cv) end
    UpdateTitle()
    PositionSeaArt()
    LayoutLabels()
    LayoutPins()
    LayoutPOI()
    LayoutAreas()
    UpdateGroup()
end

-- posição do jogador no plano atual
local function PlayerXY()
    local best = Safe(C_Map.GetBestMapForUnit, "player")
    if not best then return end
    if S.mode == "terrain" then
        return UnitPlane("player")
    else
        local pos = Safe(C_Map.GetPlayerMapPosition, S.mapID, "player")
        if pos then
            local x, y = pos:GetXY()
            if x and y and (x ~= 0 or y ~= 0) then return x * W, y * H end
        end
    end
end

-- o corpo do jogador (morto ou fantasma): C_DeathInfo.GetCorpseMapPosition no mapa do jogador; se o corpo
-- não está nele (o fantasma andou para outra zona), tenta os mapas acima (continente)
local function CorpseXY()
    if not (UnitIsDeadOrGhost and UnitIsDeadOrGhost("player")) then return end
    if not (C_DeathInfo and C_DeathInfo.GetCorpseMapPosition) then return end
    if S.mode ~= "terrain" then
        local pos = Safe(C_DeathInfo.GetCorpseMapPosition, S.mapID)
        if pos then
            local x, y = pos:GetXY()
            if x and y and (x ~= 0 or y ~= 0) then return x * W, y * H end
        end
        return
    end
    local id, guard = Safe(C_Map.GetBestMapForUnit, "player"), 0
    while id and id > 0 and guard < 4 do
        local pos = Safe(C_DeathInfo.GetCorpseMapPosition, id)
        if pos then
            local inst, wp = Safe(C_Map.GetWorldPosFromMapPos, id, pos)
            if inst and wp then
                local X, Y = wp:GetXY()
                for _, c in ipairs(S.P.conts) do
                    if c.inst == inst then return c.ax + c.bx * Y, c.ay + c.by * X end
                end
            end
            return
        end
        local info = Safe(C_Map.GetMapInfo, id)
        id, guard = info and info.parentMapID, guard + 1
    end
end

local function UpdateCorpse()
    local x, y = CorpseXY()
    if not x then S.corpse:Hide() return end
    S.corpse:ClearAllPoints()
    S.corpse:SetPoint("CENTER", S.view, "TOPLEFT", S.ox + x * S.zoom, S.oy - y * S.zoom)
    S.corpse:Show()
end

local function UpdatePlayer()
    if GetTime() - (S.groupAt or 0) > 0.2 then      -- o grupo anda: atualiza 5x por segundo
        S.groupAt = GetTime()
        UpdateGroup()
    end
    -- entrou ou saiu de uma caverna/casa: redesenha para mostrar (ou tirar) o interior dela
    if S.mode == "terrain" and (M.db.interiors or "auto") == "auto" and GetTime() - (S.insideAt or 0) > 0.5 then
        S.insideAt = GetTime()
        if InteriorHere() ~= S.insideNow then Redraw() end
    end
    UpdateCorpse()
    local x, y = PlayerXY()
    if not x then S.player:Hide() return end
    S.player:ClearAllPoints()
    S.player:SetPoint("CENTER", S.view, "TOPLEFT", S.ox + x * S.zoom, S.oy - y * S.zoom)
    S.player:SetRotation(GetPlayerFacing() or 0)
    S.player:Show()
end

local function AreaName(areaID)
    if not areaID or areaID == 0 then return nil end
    return Safe(C_Map.GetAreaInfo, areaID)
end

local function PieceAreaAt(pieces, px, py)    -- px, py em pixels da arte da zona
    if not pieces then return nil end
    local best, size
    for _, p in ipairs(pieces) do
        if px >= p[1] and py >= p[2] and px < p[1] + p[3] and py < p[2] + p[4] then
            local s = p[3] * p[4]
            if not size or s < size then best, size = p[5], s end
        end
    end
    return AreaName(best)
end

-- área de missão sob o cursor (como no mapa da Blizzard: passar o mouse na área mostra a missão)
local function InPoly(x, y, poly)
    local inside, n = false, #poly / 2
    local j = n
    for i = 1, n do
        local xi, yi, xj, yj = poly[2 * i - 1], poly[2 * i], poly[2 * j - 1], poly[2 * j]
        if (yi > y) ~= (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi then inside = not inside end
        j = i
    end
    return inside
end

local areaTips = {}
local function AreaAt(x, y)
    for _, poly in ipairs(S.hullHit or {}) do
        if x >= poly.x0 and x <= poly.x1 and y >= poly.y0 and y <= poly.y1 and InPoly(x, y, poly) then
            local qid = poly.quest
            local tip = areaTips[qid]
            if not tip then
                tip = {}
                areaTips[qid] = tip
            end
            if GetTime() - (tip.at or 0) > 1 then          -- objetivos relidos no máximo 1x/s
                tip.at = GetTime()
                local title, lines = QuestTip(qid)
                tip.title, tip.lines = title, lines
            end
            return tip
        end
    end
end

local function UpdateHover()
    local x, y = Cursor()
    local text
    -- dica dos pinos de ervas e minérios
    local pin = x and S.mode == "terrain" and not S.taxiHover and (HitAt(x, y) or AreaAt(x, y))
    if pin then
        if S.tipPin ~= pin then ShowPinTip(pin) end
    elseif S.tipPin then
        S.tipPin = nil
        GameTooltip:Hide()
    end
    if x then
        if S.mode == "terrain" then
            local z, c = ZoneAt(x, y)
            if z then
                if (z.x1 - z.x0) * S.zoom >= S.vw * 0.3 then
                    local nx, ny = ToMap(z, x, y)
                    text = PieceAreaAt(z.pieces, nx * W, ny * H)
                end
                text = text or z.name
            elseif c then
                text = c.name
            end
        else
            text = PieceAreaAt(S.pagePieces, x, y)
            if not text then
                local child = Safe(C_Map.GetMapInfoAtPosition, S.mapID, x / W, y / H)
                if child and child.mapID ~= S.mapID then text = child.name end
            end
        end
    end
    -- coordenadas (0-100) na zona sob o cursor; sem cursor no mapa, as do jogador
    local cx, cy
    if x and S.mode == "terrain" then
        local z = ZoneAt(x, y)
        if z then cx, cy = ToMap(z, x, y) end
    elseif x then
        cx, cy = x / W, y / H
    end
    if not cx then
        local best = Safe(C_Map.GetBestMapForUnit, "player")
        local pos = best and Safe(C_Map.GetPlayerMapPosition, best, "player")
        if pos then cx, cy = pos:GetXY() end
        if not text and best then text = (Safe(C_Map.GetMapInfo, best) or {}).name end
    end
    if M.ui and M.ui.SetHover then M.ui:SetHover(text, cx and cx * 100, cy and cy * 100) end
end

---------------------------------------------------------------------------
-- Navegação
---------------------------------------------------------------------------
-- desenha já a vista de destino da animação (anim.predraw = { zoom, ox, oy }): o que vai entrar
-- na vista fica pronto antes, em vez de aparecer preto até a animação acabar
local function PreDraw()
    local a = S.anim
    if not (a and a.predraw) then return end
    local z, ox, oy = S.zoom, S.ox, S.oy
    S.zoom, S.ox, S.oy = a.predraw[1], a.predraw[2], a.predraw[3]
    ClampPan()
    Redraw()
    S.zoom, S.ox, S.oy = z, ox, oy
    ApplyPan()
    a.drawn = true
end

local function FitPlace(p, animate)
    if p then Fit(p.x0, p.y0, p.x1, p.y1, animate) else Fit(0, 0, W, H, animate) end
    if animate then PreDraw(); return end
    ApplyPan()
    Redraw()
    UpdatePlayer()
end

-- um passo da animação de zoom (roda: em torno do cursor; enquadrar: centro e zoom juntos)
local function StepAnim(dt)
    local a = S.anim
    if not a then return end
    local done
    if a.kind == "wheel" then
        local lz, lt = log(S.zoom), log(a.target)
        local nl = lz + (lt - lz) * min(1, dt * 14)
        if abs(lt - nl) < 0.003 then nl, done = lt, true end
        S.zoom = exp(nl)
        S.ox, S.oy = a.vx - a.px * S.zoom, a.py * S.zoom - a.vy
    else
        a.t = a.t + dt
        local u = min(1, a.t / a.dur)
        u = u * u * (3 - 2 * u)
        S.zoom = exp(log(a.z0) + (log(a.z1) - log(a.z0)) * u)
        local cx, cy = a.cx0 + (a.cx1 - a.cx0) * u, a.cy0 + (a.cy1 - a.cy0) * u
        S.ox, S.oy = S.vw / 2 - cx * S.zoom, cy * S.zoom - S.vh / 2
        done = u >= 1
    end
    ApplyPan()
    UpdatePlayer()
    if done then
        S.anim = nil
        if a.drawn then
            -- o terreno do destino já foi desenhado; os ícones são refeitos na vista final
            -- (FocusMapXY/FocusQuest os recalculam na vista antiga e o da missão ficava de fora)
            UpdateTitle(); LayoutLabels(); LayoutPins(); LayoutPOI(); LayoutAreas(); UpdateGroup()
        else
            Redraw()
        end
    elseif not a.drawn and S.front and S.front.dz then
        -- esticou demais: redesenha no meio do caminho para não perder detalhe
        local r = S.zoom / S.front.dz
        if (r > 2.2 or r < 0.45) and GetTime() - (S.lastDraw or 0) > 0.1 then Redraw() end
    end
end

-- mostra um mapa: no plano de terreno quando ele faz parte dele; senão, a página de arte
function M:ShowMap(mapID)
    if not mapID or not S.frame then return end
    S.exploredCache = nil
    S.anim = nil
    if M.db.terrain and S.P and (mapID == WORLD or S.P.byID[mapID]) then
        S.mode = "terrain"
        UpdateZMin()
        S.maxZoom = S.P.maxZoom
        FitPlace(S.P.byID[mapID])
    else
        S.mode, S.mapID = "art", mapID
        UpdateZMin()
        S.maxZoom = S.zmin * 8
        S.zoom, S.ox, S.oy = S.zmin, 0, 0
        ApplyPan()
        Redraw()
        UpdatePlayer()
    end
end

function M:Refresh()
    if not self:IsOpen() then return end
    S.exploredCache = nil
    Redraw()
end

local function GoUp()
    if S.mode == "terrain" then
        local p = S.place
        FitPlace(p and p.kind == "zone" and p.cont or nil, true)
    else
        local info = Safe(C_Map.GetMapInfo, S.mapID)
        if info and info.parentMapID and info.parentMapID > 0 then M:ShowMap(info.parentMapID) end
    end
end

local function GoDown()
    local x, y = Cursor()
    if not x then return end
    if S.mode == "terrain" then
        local z, c = ZoneAt(x, y)
        local here = S.place
        if z and here ~= z and (not here or here.kind == "cont") then FitPlace(z, true)
        elseif not here and c then FitPlace(c, true) end
    else
        local child = Safe(C_Map.GetMapInfoAtPosition, S.mapID, x / W, y / H)
        if child and child.mapID and child.mapID ~= S.mapID then M:ShowMap(child.mapID) end
    end
end

-- zoom pela roda: anima até o alvo, em torno do ponto sob o cursor (passos seguidos se somam)
local function ZoomAt(factor)
    local a = S.anim
    local from = (a and a.kind == "wheel") and a.target or S.zoom
    local nz = min(S.maxZoom or 8, max(S.zmin, from * factor))
    if abs(nz - from) < 1e-6 then return false end
    local px, py = Cursor()
    local z = S.zoom
    if not px then local x0, y0, x1, y1 = Visible(); px, py = (x0 + x1) / 2, (y0 + y1) / 2 end
    local vx, vy = px * z + S.ox, py * z - S.oy
    if a and a.kind == "wheel" then vx, vy, px, py = a.vx, a.vy, a.px, a.py end
    S.anim = { kind = "wheel", target = nz, px = px, py = py, vx = vx, vy = vy }
    if nz < S.zoom then
        -- afastando: a área que vai aparecer é desenhada já (no nível do destino)
        S.anim.predraw = { nz, vx - px * nz, py * nz - vy }
        PreDraw()
    end
    return true
end

local function PlayerMap()
    return Safe(C_Map.GetBestMapForUnit, "player")
end

---------------------------------------------------------------------------
-- Janela
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- Janela: a área do mapa ocupa todo o interior; a moldura (barra superior, menu lateral, missões,
-- barra de status, borda) é desenhada por Modules/MapChrome.lua e Modules/MapQuests.lua
---------------------------------------------------------------------------
local TOP_H, BORDER = 46, 6

-- a vista mudou de tamanho (janela <-> tela cheia): mantém o centro e o enquadramento
local function OnViewResize()
    local v = S.view
    local vw, vh = v:GetWidth(), v:GetHeight()
    if not vw or vw < 50 or not vh or vh < 50 then return end
    local cx, cy = (S.vw / 2 - S.ox) / S.zoom, (S.oy + S.vh / 2) / S.zoom
    local rel = S.zoom / (S.zmin or 1)
    S.vw, S.vh = vw, vh
    UpdateZMin()
    if S.mode == "art" then S.maxZoom = S.zmin * 8 end
    S.zoom = max(S.zmin, min(S.maxZoom or (S.zmin * 8), S.zmin * rel))
    S.ox, S.oy = vw / 2 - cx * S.zoom, cy * S.zoom - vh / 2
    ApplyPan()
    if M:IsOpen() and S.mode then Redraw(); UpdatePlayer() end
end

-- rota até a missão selecionada (ou rota multi-paradas das missões do mapa) e o anel pulsando
local function HideMultiRoute(r)
    if r.multi then
        for i = 1, #r.multi do r.multi[i]:Hide(); r.multi[i].o:Hide() end
    end
    if r.magicDots then
        for i = 1, #r.magicDots do r.magicDots[i]:Hide(); r.magicDots[i].o:Hide() end
    end
end


-- diagnóstico (SavedVariables: AzaathUIDB.worldmap.magicDiag): por que o caminho foi ou não desenhado
local function MagicDiag(why, mp, extra)
    local now = GetTime()
    if not M.db or now - (S.magicDiagAt or 0) < 1 then return end
    S.magicDiagAt = now
    M.db.magicDiag = { time = date("%H:%M:%S"), why = why, nodes = mp and mp.nodes and #mp.nodes or 0, mapID = mp and mp.mapID,
        mode = S.mode, extra = extra }
end

local function DrawMagicPath(r)
    local qn = Azaath:GetModule("QuestNav")
    local mp = qn and qn.GetMagicPath and qn:GetMagicPath()
    if not (mp and mp.nodes and #mp.nodes >= 2 and S.mode == "terrain") then
        MagicDiag(not qn and "sem QuestNav" or not mp and "sem caminho" or "modo/nós", mp)
        if r.magicDots then for i = 1, #r.magicDots do r.magicDots[i]:Hide(); r.magicDots[i].o:Hide() end end
        return false
    end
    -- os nós trazem a posição no mundo (jardas): vai direto para o plano pelo continente, sem depender de o mapa
    -- do alvo ser uma das zonas do plano (cidades e sub-zonas não são)
    local pl = S.route and S.route.parent
    local cont
    if mp.mapID and S.P and _G.CreateVector2D then
        local inst = Safe(C_Map.GetWorldPosFromMapPos, mp.mapID, CreateVector2D(0.5, 0.5))
        for _, c in ipairs(S.P.conts) do if c.inst == inst then cont = c break end end
    end
    if not (cont and pl) then
        MagicDiag(not cont and "continente não achado" or "sem camada", mp)
        if r.magicDots then for i = 1, #r.magicDots do r.magicDots[i]:Hide(); r.magicDots[i].o:Hide() end end
        return false
    end
    if r.multi then for i = 1, #r.multi do r.multi[i]:Hide(); r.multi[i].o:Hide() end end
    local z = S.zoom
    r.magicDots = r.magicDots or {}
    local dotTex = Azaath.media.path .. "MapFrame\\ExpPathDotS.tga"
    local now = GetTime()
    local phase = (now % 1.1) / 1.1
    local count, maxDots = 0, 650
    local totalYds = mp.totalYds or 0
    local spacingYds = math.max(10, totalYds > 0 and (totalYds / (maxDots - 8)) or 10)
    local carry = phase * spacingYds

    for i = 1, #mp.nodes - 1 do
        local a, b = mp.nodes[i], mp.nodes[i + 1]
        if a.wx and a.wy and b.wx and b.wy then
            local dx = b.wx - a.wx
            local dy = b.wy - a.wy
            local segLen = math.sqrt(dx * dx + dy * dy)
            if segLen > 0.1 then
                -- extremos no plano: x = ax + bx * Y (oeste), y = ay + by * X (norte)
                local ax, ay = cont.ax + cont.bx * a.wy, cont.ay + cont.by * a.wx
                local bx, by = cont.ax + cont.bx * b.wy, cont.ay + cont.by * b.wx
                local pos = carry
                while pos <= segLen do
                    local frac = pos / segLen
                    local wx = ax + (bx - ax) * frac
                    local wy = ay + (by - ay) * frac
                    local x, y = S.ox + wx * z, S.oy - wy * z
                    count = count + 1
                    if count > maxDots then break end
                    local dot = r.magicDots[count]
                    if not dot then
                        -- (mistura normal com contorno escuro: a aditiva some sobre o papel claro do mar)
                        dot = pl:CreateTexture(nil, "OVERLAY", nil, 2)
                        dot:SetTexture(dotTex)
                        dot.o = pl:CreateTexture(nil, "OVERLAY", nil, 1)
                        dot.o:SetTexture(dotTex)
                        dot.o:SetVertexColor(0.03, 0.09, 0.12, 1)
                        r.magicDots[count] = dot
                    end
                    local wave = 0.5 + 0.5 * math.sin(now * 5.0 - count * 0.55)
                    local sz = 4.5 + wave * 1.5
                    dot:SetSize(sz, sz)
                    dot:ClearAllPoints()
                    dot:SetPoint("CENTER", S.view, "TOPLEFT", x, y)
                    dot:SetVertexColor(0.25 + 0.30 * wave, 0.92, 0.97)
                    dot:SetAlpha(0.95)
                    dot:Show()
                    dot.o:SetSize(sz + 3, sz + 3)
                    dot.o:ClearAllPoints()
                    dot.o:SetPoint("CENTER", S.view, "TOPLEFT", x, y)
                    dot.o:SetAlpha(0.5)
                    dot.o:Show()
                    pos = pos + spacingYds
                end
                carry = pos - segLen
                if count >= maxDots then break end
            end
        end
    end
    MagicDiag("desenhado", mp, "pontos=" .. count .. " cont=" .. tostring(cont.id) .. " zoom=" .. string.format("%.2f", z))
    if count == 0 then return false end
    for i = count + 1, #r.magicDots do r.magicDots[i]:Hide(); r.magicDots[i].o:Hide() end
    return true
end

local function UpdateRoute()
    local r = S.route
    if not r then return end
    r.line:Hide(); r.head:Hide()
    HideMultiRoute(r)
    local target
    if S.selQuest and S.mode == "terrain" and S.poi then
        for i = 1, S.poi.used do
            local e = S.poi.list[i]
            if e.questID == S.selQuest then target = e break end
        end
    elseif S.customPin and S.mode == "terrain" then
        target = { _x = S.customPin.x, _y = S.customPin.y }
    elseif S.mode == "terrain" and S.P then
        -- o anel vai no pin personalizado que a navegação está seguindo
        for _, up in ipairs(UserPins()) do
            local z = S.P.byID[up.mapID]
            if z and IsFollowed(up) then
                target = { _x = z.x0 + up.nx * (z.x1 - z.x0), _y = z.y0 + up.ny * (z.y1 - z.y0) }
                break
            end
        end
    end
    if not target then
        r.ring:Hide(); r.ringO:Hide()
        DrawMagicPath(r)
        return
    end
    DrawMagicPath(r)
    local z, t = S.zoom, GetTime()
    local tx, ty = S.ox + target._x * z, S.oy - target._y * z
    local pulse = 0.5 + 0.5 * math.sin(t * 4)
    r.ring:ClearAllPoints()
    r.ring:SetPoint("CENTER", S.view, "TOPLEFT", tx, ty)
    r.ring:SetSize(34 + pulse * 10, 34 + pulse * 10)
    r.ring:SetAlpha(0.55 + 0.45 * (1 - pulse))
    r.ring:Show()
    r.ringO:ClearAllPoints()
    r.ringO:SetPoint("CENTER", S.view, "TOPLEFT", tx, ty)
    r.ringO:SetSize(38 + pulse * 10, 38 + pulse * 10)
    r.ringO:SetAlpha(0.7 * (0.55 + 0.45 * (1 - pulse)))
    r.ringO:Show()
end

---------------------------------------------------------------------------
-- Pin personalizado (como no mapa da Blizzard): Ctrl+clique marca o ponto (marcador do jogo, seguido na
-- bússola/navegação); Ctrl+clique no próprio pin remove
---------------------------------------------------------------------------
local function FollowUserPin(i)
    local up = UserPins()[i]
    if not up then return end
    S.selQuest = nil
    local qn = Azaath:GetModule("QuestNav")
    if qn and qn.SetCustomWaypoint then
        -- a navegação põe o marcador do jogo, segue o ponto na bússola e calcula o caminho mágico
        qn:SetCustomWaypoint(up.mapID, up.nx * 100, up.ny * 100, up.label)
    elseif C_Map.SetUserWaypoint and _G.UiMapPoint and UiMapPoint.CreateFromCoordinates then
        local pt = UiMapPoint.CreateFromCoordinates(up.mapID, up.nx, up.ny)
        if pt then
            Safe(C_Map.SetUserWaypoint, pt)
            if _G.C_SuperTrack and C_SuperTrack.SetSuperTrackedUserWaypoint then Safe(C_SuperTrack.SetSuperTrackedUserWaypoint, true) end
        end
    end
end

-- Ctrl+clique num lugar vazio: pin novo (salvo; volta após /reload), já seguido
local function AddUserPin(zone, nx, ny)
    local list = UserPins()
    list[#list + 1] = { mapID = zone.id, nx = nx, ny = ny, label = zone.name }
    FollowUserPin(#list)
    PlaySound(_G.SOUNDKIT and SOUNDKIT.UI_MAP_WAYPOINT_CONTROL_CLICK or 856)
end

-- Ctrl+clique num pin: remove só ele (e para a navegação, se era ele o seguido)
local function RemoveUserPin(i)
    local list = UserPins()
    local up = list[i]
    if not up then return end
    table.remove(list, i)
    if IsFollowed(up) then
        local qn = Azaath:GetModule("QuestNav")
        if qn and qn.ClearCustomWaypoint then qn:ClearCustomWaypoint() end
    end
    PlaySound(_G.SOUNDKIT and SOUNDKIT.UI_MAP_WAYPOINT_REMOVE or 857)
end

-- editor do pin (botão direito no pin): nome e anotações, como no mapa da Blizzard
local pinEd
local function EditUserPin(i)
    local up = UserPins()[i]
    if not (up and S.frame) then return end
    local C = Azaath:GetModule("MapChrome")
    if not pinEd then
        local p = CreateFrame("Frame", nil, S.frame)
        p:SetSize(300, 236)
        p:SetFrameLevel(S.frame:GetFrameLevel() + 60)
        p:EnableMouse(true)
        p:SetPoint("CENTER", S.view, "CENTER")
        if C and C.PanelBox then C.PanelBox(p) end
        local function FS(size, r, g, b)
            local t = p:CreateFontString(nil, "OVERLAY")
            if C and C.Font then C.Font(t, size) else t:SetFontObject("GameFontNormal") end
            t:SetTextColor(r, g, b)
            return t
        end
        local function Box(h, multi)
            local bg = CreateFrame("Frame", nil, p)
            bg:SetSize(268, h)
            local t = bg:CreateTexture(nil, "BACKGROUND")
            t:SetAllPoints(); t:SetColorTexture(0, 0, 0, 0.45)
            local e = CreateFrame("EditBox", nil, bg)
            e:SetPoint("TOPLEFT", 6, -5); e:SetPoint("BOTTOMRIGHT", -6, 5)
            e:SetAutoFocus(false)
            e:SetMultiLine(multi and true or false)
            e:SetFontObject("ChatFontNormal")
            e:SetTextColor(0.95, 0.92, 0.82)
            e:SetScript("OnEscapePressed", function() p:Hide() end)
            bg:EnableMouse(true)
            bg:SetScript("OnMouseDown", function() e:SetFocus() end)
            return bg, e
        end
        local hdr = FS(15, 0.92, 0.76, 0.36)
        hdr:SetPoint("TOPLEFT", 16, -14)
        hdr:SetText("PIN PERSONALIZADO")
        p.where = FS(11, 0.6, 0.6, 0.6)
        p.where:SetPoint("TOPLEFT", 16, -34)
        local l1 = FS(11, 0.8, 0.8, 0.8); l1:SetPoint("TOPLEFT", 16, -56); l1:SetText("Nome")
        local b1, e1 = Box(26)
        b1:SetPoint("TOPLEFT", 16, -72)
        e1:SetMaxLetters(40)
        local l2 = FS(11, 0.8, 0.8, 0.8); l2:SetPoint("TOPLEFT", 16, -106); l2:SetText("Anotações")
        local b2, e2 = Box(74, true)
        b2:SetPoint("TOPLEFT", 16, -122)
        e2:SetMaxLetters(300)
        e1:SetScript("OnTabPressed", function() e2:SetFocus() end)
        e1:SetScript("OnEnterPressed", function() p.save:Click() end)
        p.name, p.note = e1, e2
        local function Btn(text, x, fn)
            local b = CreateFrame("Button", nil, p, "UIPanelButtonTemplate")
            b:SetSize(84, 22)
            b:SetPoint("BOTTOMLEFT", x, 12)
            b:SetText(text)
            b:SetScript("OnClick", fn)
            return b
        end
        p.save = Btn("Salvar", 16, function()
            local cur = UserPins()[p.idx]
            if cur then
                cur.name = strtrim(p.name:GetText() or "")
                cur.note = strtrim(p.note:GetText() or "")
            end
            p:Hide()
            S.poiCache = nil
            LayoutPOI(); LayoutAreas()
        end)
        Btn("Remover", 108, function()
            RemoveUserPin(p.idx)
            p:Hide()
            S.poiCache = nil
            LayoutPOI(); LayoutAreas()
        end)
        Btn("Cancelar", 200, function() p:Hide() end)
        p:SetScript("OnHide", function() p.name:ClearFocus(); p.note:ClearFocus() end)
        pinEd = p
    end
    pinEd.idx = i
    pinEd.where:SetText(up.label or "")
    pinEd.name:SetText(up.name or "")
    pinEd.note:SetText(up.note or "")
    pinEd:Show()
    pinEd.name:SetFocus()
    pinEd.name:HighlightText()
end

local function Build()
    local f = CreateFrame("Frame", "AzaathUIWorldMap", UIParent)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:EnableMouse(true)
    f:SetMovable(true)
    f:SetClampedToScreen(true)
    f:SetSize(1180, 760)
    f:SetPoint("CENTER")
    f:Hide()
    tinsert(UISpecialFrames, "AzaathUIWorldMap")
    S.frame = f
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetAllPoints()
    bg:SetColorTexture(0.03, 0.045, 0.055, 0.98)

    local v = CreateFrame("Frame", nil, f)
    v:SetPoint("TOPLEFT", BORDER, -TOP_H)
    v:SetPoint("BOTTOMRIGHT", -BORDER, BORDER)
    v:SetClipsChildren(true)
    v:EnableMouse(true)
    v:EnableMouseWheel(true)
    local sea = v:CreateTexture(nil, "BACKGROUND", nil, -8)   -- papel liso (fora da arte do mar e nos mapas de arte)
    sea:SetAllPoints()
    sea:SetTexture(FRAME_TEX .. "ExpPaper")
    S.sea = sea
    S.view = v
    -- a arte do mar (tools/map-ui-concept/expedicao/gen.js): POR BAIXO do terreno, que é transparente no mar
    S.seaChartL = v:CreateTexture(nil, "BACKGROUND", nil, -7)
    S.seaChartL:SetTexture(FRAME_TEX .. "ExpOceanL")
    S.seaChartR = v:CreateTexture(nil, "BACKGROUND", nil, -7)
    S.seaChartR:SetTexture(FRAME_TEX .. "ExpOceanR")

    -- duas camadas de desenho (ver Redraw)
    local function NewCanvas()
        local c = CreateFrame("Frame", nil, v)
        c:SetSize(1, 1)
        return { frame = c, base = NewPool(c, "BACKGROUND", 0), reveal = NewPool(c, "BORDER", 0),
                 lit = NewPool(c, "ARTWORK", 0), masks = { parent = c, list = {}, used = 0 },
                 baseW = NewPool(c, "BACKGROUND", 1), litW = NewPool(c, "ARTWORK", 1),
                 inner = NewPool(c, "ARTWORK", 3) }   -- interiores: por cima do terreno e da névoa
    end
    S.cvA, S.cvB = NewCanvas(), NewCanvas()
    S.levelLow = v:GetFrameLevel() + 1
    S.levelTop = v:GetFrameLevel() + 2
    S.canvas = S.cvA.frame

    local nf = CreateFrame("Frame", nil, v)    -- nomes: acima do terreno, abaixo do jogador
    nf:SetAllPoints()
    nf:SetFrameLevel(v:GetFrameLevel() + 5)
    S.names = { parent = nf, list = {}, used = 0 }
    S.seaLabelsL = nf:CreateTexture(nil, "ARTWORK", nil, -1)
    S.seaLabelsL:SetTexture(FRAME_TEX .. "ExpLabelsL")
    S.seaLabelsR = nf:CreateTexture(nil, "ARTWORK", nil, -1)
    S.seaLabelsR:SetTexture(FRAME_TEX .. "ExpLabelsR")

    local bf = CreateFrame("Frame", nil, v)    -- áreas das missões: logo acima do terreno
    bf:SetAllPoints()
    bf:SetFrameLevel(v:GetFrameLevel() + 3)
    S.blobs = { parent = bf, list = {}, used = 0 }
    local hf = CreateFrame("Frame", nil, bf)
    hf:SetSize(1, 1)
    S.hulls = { holder = hf, list = {}, used = 0 }

    local pf = CreateFrame("Frame", nil, v)    -- ervas e minérios: abaixo dos nomes
    pf:SetAllPoints()
    pf:SetFrameLevel(v:GetFrameLevel() + 4)
    S.pins = { parent = pf, list = {}, used = 0 }

    local of = CreateFrame("Frame", nil, v)    -- lugares (voo, masmorras, missões): acima da coleta
    of:SetAllPoints()
    of:SetFrameLevel(v:GetFrameLevel() + 4)
    S.poi = { parent = of, list = {}, used = 0 }

    local pl = CreateFrame("Frame", nil, v)
    pl:SetAllPoints()
    pl:SetFrameLevel(v:GetFrameLevel() + 6)
    S.group = { parent = pl, list = {}, used = 0 }   -- grupo: no mesmo nível do jogador, abaixo da seta
    S.player = pl:CreateTexture(nil, "OVERLAY")
    S.player:SetTexture(FRAME_TEX .. "ExpPlayerArrow")   -- cristal azul com aro dourado (expedicao/icons.js)
    S.player:SetSize(38, 38)
    S.player:Hide()
    -- o seu corpo, quando morto/fantasma (abaixo da seta do jogador)
    S.corpse = pl:CreateTexture(nil, "OVERLAY", nil, -1)
    S.corpse:SetTexture(FRAME_TEX .. "PinCorpse")
    S.corpse:SetSize(30, 30)
    S.corpse:Hide()

    -- rota até a missão selecionada (linha ciano com brilho) e o anel na missão
    S.route = { parent = pl }
    S.route.line = pl.CreateLine and pl:CreateLine(nil, "ARTWORK", nil, 2) or pl:CreateTexture(nil, "ARTWORK", nil, 2)
    S.route.line:SetTexture(FRAME_TEX .. "Route")
    if S.route.line.SetThickness then S.route.line:SetThickness(10) end
    S.route.line:SetBlendMode("ADD")
    S.route.line:Hide()
    S.route.head = pl:CreateTexture(nil, "ARTWORK", nil, 3)
    S.route.head:SetTexture(FRAME_TEX .. "RouteHead")
    S.route.head:SetSize(22, 22)
    S.route.head:SetBlendMode("ADD")
    S.route.head:Hide()
    S.route.ring = of:CreateTexture(nil, "OVERLAY", nil, 3)
    S.route.ring:SetTexture(FRAME_TEX .. "PinRing")
    S.route.ring:Hide()
    S.route.ringO = of:CreateTexture(nil, "OVERLAY", nil, 2)       -- contorno escuro (a mistura aditiva some no papel)
    S.route.ringO:SetTexture(FRAME_TEX .. "PinRing")
    S.route.ringO:SetVertexColor(0.03, 0.09, 0.12, 1)
    S.route.ringO:Hide()

    S.empty = v:CreateFontString(nil, "OVERLAY", "GameFontDisable")
    S.empty:SetPoint("CENTER")
    S.empty:SetText("Sem mapa para este lugar.")
    S.empty:Hide()

    v:SetScript("OnMouseDown", function(_, button)
        if button ~= "LeftButton" then return end
        S.anim = nil
        local x, y = GetCursorPosition()
        local s = v:GetEffectiveScale()
        S.drag = { x = x / s, y = y / s, ox = S.ox, oy = S.oy, moved = false }
    end)
    v:SetScript("OnMouseUp", function(_, button)
        if button == "RightButton" then
            local x, y = Cursor()
            local hit = x and S.mode == "terrain" and HitAt(x, y)
            if hit and UserPinIndex(hit.questID) then
                EditUserPin(UserPinIndex(hit.questID))
            elseif hit and hit.rare then
                -- raro: botão direito abre a aba de detalhes (retrato + drops; Modules/MapRarePanel.lua)
                local P = Azaath:GetModule("MapRarePanel")
                local px, py, title = hit._x, hit._y, hit.title
                GameTooltip:Hide()
                if P then
                    P:Open(hit.rare, S.frame, function()
                        local z = ZoneAt(px, py)
                        local qn = Azaath:GetModule("QuestNav")
                        if z and qn and qn.SetCustomWaypoint then
                            S.selQuest = nil
                            local nx, ny = ToMap(z, px, py)
                            qn:SetCustomWaypoint(z.id, nx * 100, ny * 100, title)
                            PlaySound(_G.SOUNDKIT and SOUNDKIT.UI_MAP_WAYPOINT_CONTROL_CLICK or 856)
                            if S.frame and S.frame:IsShown() then LayoutPOI(); LayoutAreas() end
                        end
                    end)
                end
            else
                GoUp()
            end
        elseif button == "LeftButton" and S.drag then
            local moved = S.drag.moved
            S.drag = nil
            if moved then
                S.dirty = true
            else
                -- clique numa missão do mapa: abre os detalhes dela
                local x, y = Cursor()
                local hit = x and S.mode == "terrain" and HitAt(x, y)
                if x and S.mode == "terrain" and IsControlKeyDown() then
                    -- pin personalizado: Ctrl+clique no pin remove; em outro lugar de uma zona, marca
                    if hit and UserPinIndex(hit.questID) then
                        RemoveUserPin(UserPinIndex(hit.questID))
                    else
                        local z = ZoneAt(x, y)
                        if z then
                            local nx, ny = ToMap(z, x, y)
                            AddUserPin(z, nx, ny)
                        end
                    end
                    S.poiCache = nil
                    LayoutPOI(); LayoutAreas()
                elseif hit and UserPinIndex(hit.questID) then
                    FollowUserPin(UserPinIndex(hit.questID))   -- clique num pin personalizado: segue ele
                    LayoutPOI(); LayoutAreas()
                elseif hit and hit.rare then
                    -- raro: segue o ponto (caminho mágico + bússola)
                    local z = ZoneAt(hit._x, hit._y)
                    local qn = Azaath:GetModule("QuestNav")
                    if z and qn and qn.SetCustomWaypoint then
                        S.selQuest = nil
                        local nx, ny = ToMap(z, hit._x, hit._y)
                        qn:SetCustomWaypoint(z.id, nx * 100, ny * 100, hit.title)
                        PlaySound(_G.SOUNDKIT and SOUNDKIT.UI_MAP_WAYPOINT_CONTROL_CLICK or 856)
                    end
                    LayoutPOI(); LayoutAreas()
                elseif hit and hit.questID == -999999 then
                    -- ponto do guarda: segue ele (caminho mágico + bússola)
                    local cp = S.customPin
                    local z = cp and cp.mapID and S.P and S.P.byID[cp.mapID]
                    local qn = Azaath:GetModule("QuestNav")
                    if z and qn and qn.SetCustomWaypoint then
                        S.selQuest = nil
                        local nx, ny = ToMap(z, cp.x, cp.y)
                        qn:SetCustomWaypoint(cp.mapID, nx * 100, ny * 100, cp.label)
                        PlaySound(_G.SOUNDKIT and SOUNDKIT.UI_MAP_WAYPOINT_CONTROL_CLICK or 856)
                    end
                    LayoutPOI(); LayoutAreas()
                elseif hit and hit.questID then
                    if M.onQuestClick then
                        M.onQuestClick(hit.questID)
                    elseif M.api and M.api.SelectQuest then
                        M.api.SelectQuest(hit.questID)
                    end
                else
                    GoDown()
                end
            end
        end
    end)
    v:SetScript("OnMouseWheel", function(_, delta)
        if delta > 0 then
            ZoomAt(1.3)
        elseif not ZoomAt(1 / 1.3) and S.mode == "art" then
            GoUp()
        end
    end)
    v:SetScript("OnSizeChanged", OnViewResize)

    local elapsed = 0
    f:SetScript("OnUpdate", function(_, dt)
        if S.drag then
            local x, y = GetCursorPosition()
            local s = v:GetEffectiveScale()
            local dx, dy = x / s - S.drag.x, y / s - S.drag.y
            if S.drag.moved or abs(dx) + abs(dy) > 4 then
                S.drag.moved = true
                S.ox, S.oy = S.drag.ox + dx, S.drag.oy + dy
                ApplyPan()
                S.dirty = true
            end
        end
        StepAnim(dt)
        UpdateRoute()
        -- a camada nova aparece quando carregou (ou no limite); a antiga some logo depois
        local now = GetTime()
        for _, cv in ipairs({ S.cvA, S.cvB }) do
            if cv.pending and (now >= cv.revealBy or CanvasLoaded(cv)) then RevealCanvas(cv) end
            if cv.hideAt and now >= cv.hideAt then
                cv.hideAt = nil
                ResetCanvas(cv)
                cv.frame:Hide()
            end
        end
        elapsed = elapsed + dt
        if elapsed < 0.05 then return end
        elapsed = 0
        -- só o que está à vista é desenhado: redesenha depois de mover
        if S.dirty and not S.anim and now - (S.lastDraw or 0) > 0.12 then Redraw() end
        UpdatePlayer()
        UpdateHover()
    end)

    -- a moldura e o painel de missões
    local chrome = Azaath:GetModule("MapChrome")
    if chrome and chrome.Build then
        M.ui = chrome
        chrome:Build(f, v, M.api)
    end
    local quests = Azaath:GetModule("MapQuests")
    if quests and quests.Build then quests:Build(f, v, M.api) end
    local loremaster = Azaath:GetModule("MapLoremaster")
    if loremaster and loremaster.Build then loremaster:Build(f, v, M.api) end
    M:ApplyWindowMode()
end

-- janela ou tela cheia (Azaath.db.worldmap.maximized)
function M:ApplyWindowMode()
    local f = S.frame
    if not f then return end
    f:ClearAllPoints()
    f:SetScale(1)
    if M.db.maximized then
        f:SetAllPoints(UIParent)
        f:SetMovable(false)
    else
        -- proporção da arte da moldura (2000 x 1116)
        local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
        local w = min(1240, sw * 0.9)
        local h = w * 1116 / 2000
        if h > sh * 0.88 then h = sh * 0.88; w = h * 2000 / 1116 end
        f:SetSize(w, h)
        local p = M.db.windowPos
        if p and p[1] then f:SetPoint(p[1], UIParent, p[1], p[2], p[3]) else f:SetPoint("CENTER") end
        f:SetMovable(true)
    end
    if M.ui and M.ui.OnWindowMode then M.ui:OnWindowMode(M.db.maximized and true or false) end
end

-- onde está a marca de uma missão no plano (procura nas zonas: C_QuestLog.GetQuestsOnMap)
local function FindQuest(questID)
    if not (S.P and _G.C_QuestLog and C_QuestLog.GetQuestsOnMap) then return end
    for _, zone in ipairs(S.P.zones) do
        for _, q in ipairs(PoiCached("q" .. zone.id, function() return Safe(C_QuestLog.GetQuestsOnMap, zone.id) end)) do
            if q.questID == questID and q.x and q.y then
                local qx, qy = q.x, q.y
                local qn = not Safe(C_QuestLog.IsComplete, questID) and Azaath:GetModule("QuestNav")
                if qn and qn.GetQuestAreaPos then
                    local ax, ay = qn:GetQuestAreaPos(questID, zone.id)
                    if ax then qx, qy = ax, ay end
                end
                return zone.x0 + qx * (zone.x1 - zone.x0), zone.y0 + qy * (zone.y1 - zone.y0), zone
            end
        end
    end
end

-- funções para a moldura (MapChrome) e o painel de missões (MapQuests)
M.api = {
    S = S, W = W, H = H, WORLD = WORLD,
    Redraw = function() Redraw() end,
    Labels = function() LayoutLabels() end,
    ShowMap = function(id) M:ShowMap(id) end,
    GoUp = function() GoUp() end,
    FitPlace = function(p) FitPlace(p, true) end,
    Fit = function(x0, y0, x1, y1) Fit(x0, y0, x1, y1, true) end,
    LayoutPOI = function() S.poiCache = nil; if S.poi then LayoutPOI() end end,
    Place = function(id) return S.P and S.P.byID[id] end,
    Zones = function() return S.P and S.P.zones or {} end,
    Conts = function() return S.P and S.P.conts or {} end,
    PlayerMap = function() return PlayerMap() end,
    IsTerrain = function() return S.mode == "terrain" end,
    -- centraliza no jogador, com parte da zona dele enquadrada
    FocusPlayer = function()
        if S.mode ~= "terrain" then M:ShowMap(PlayerMap() or WORLD) return end
        local x, y = UnitPlane("player")
        if not x then return end
        local z = ZoneAt(x, y)
        local w = z and (z.x1 - z.x0) * 0.5 or 60
        Fit(x - w / 2, y - w / 3, x + w / 2, y + w / 3, true)
        PreDraw()
    end,
    FindQuest = FindQuest,
    -- porta da masmorra de uma área (QuestSortID): zona (uiMapID), x e y (0-100) e nome; nil se não conhecida
    DungeonDoor = function(areaID)
        local inst = DUNGEON_AREA_INST[areaID]
        if not inst then return end
        if not S.P then S.P = BuildWorld() end
        if not S.P then return end
        for _, p in ipairs(InstancePlaces()) do
            if p.ids[inst] and p.zone then
                local z = p.zone
                return z.id, (p.x - z.x0) / (z.x1 - z.x0) * 100, (p.y - z.y0) / (z.y1 - z.y0) * 100, p.name
            end
        end
    end,
    -- mostra a missão no mapa: enquadra o ponto dela e a seleciona (anel + rota); false se não tem marca
    FocusQuest = function(questID)
        S.selQuest = questID
        local qn = Azaath:GetModule("QuestNav")
        if qn and qn.SetFocusedQuest then qn:SetFocusedQuest(questID, true) end
        if S.mode ~= "terrain" then M:ShowMap(WORLD) end
        local x, y, zone = FindQuest(questID)
        if not x then LayoutPOI(); LayoutAreas() return false end
        local w = (zone.x1 - zone.x0) * 0.42
        Fit(x - w / 2, y - w / 3, x + w / 2, y + w / 3, true)
        PreDraw()
        LayoutPOI()
        LayoutAreas()   -- troca as áreas já (o enquadramento pode não redesenhar se a vista não mudar)
        return true
    end,
    SelectQuest = function(questID, fromNav)
        S.selQuest = questID
        S.customPin = nil
        if not fromNav then
            local qn = Azaath:GetModule("QuestNav")
            if qn and qn.SetFocusedQuest then qn:SetFocusedQuest(questID, true) end
        end
        if S.frame and S.poi then
            LayoutPOI(); LayoutAreas()
        end
    end,
    FocusMapXY = function(mapID, xPct, yPct, questID, pinLabel)
        local hasPoi = false
        if questID and S.poi then
            for i = 1, S.poi.used do
                if S.poi.list[i].questID == questID then hasPoi = true; break end
            end
        end
        if questID and hasPoi then
            S.selQuest = questID
            S.customPin = nil
        elseif pinLabel then
            S.selQuest = nil
        end
        if S.mode ~= "terrain" then M:ShowMap(WORLD) end
        local z = mapID and S.P and S.P.byID and S.P.byID[mapID]
        if z and xPct and yPct then
            local x = z.x0 + (xPct / 100) * (z.x1 - z.x0)
            local y = z.y0 + (yPct / 100) * (z.y1 - z.y0)
            if pinLabel and not (questID and hasPoi) then
                S.customPin = { mapID = mapID, x = x, y = y, label = pinLabel }
            end
            local w = (z.x1 - z.x0) * 0.42
            Fit(x - w / 2, y - w / 3, x + w / 2, y + w / 3, true)
            PreDraw()
        end
        if S.frame and S.poi then LayoutPOI(); LayoutAreas() end
    end,
    -- pin fixo vindo de outra tela (ex.: missões da aba Masmorras): igual ao de Ctrl+clique, salvo e só
    -- removido pelo jogador (Ctrl+clique no pin); já fica seguido. Mesmo ponto e nome não duplica.
    AddUserPin = function(mapID, xPct, yPct, name, note)
        if not (mapID and xPct and yPct) then return end
        local list = UserPins()
        local nx, ny = xPct / 100, yPct / 100
        for i, up in ipairs(list) do
            if up.mapID == mapID and abs(up.nx - nx) < 0.002 and abs(up.ny - ny) < 0.002 and up.name == name then
                FollowUserPin(i)
                if S.frame and S.poi then LayoutPOI() end
                return i
            end
        end
        local info = C_Map.GetMapInfo and C_Map.GetMapInfo(mapID)
        list[#list + 1] = { mapID = mapID, nx = nx, ny = ny, label = info and info.name or nil, name = name, note = note }
        FollowUserPin(#list)
        PlaySound(_G.SOUNDKIT and SOUNDKIT.UI_MAP_WAYPOINT_CONTROL_CLICK or 856)
        S.customPin = nil
        if S.frame and S.poi then LayoutPOI() end
        return #list
    end,
    SetMaximized = function(on) M.db.maximized = on and true or false; M:ApplyWindowMode() end,
    IsMaximized = function() return M.db.maximized and true or false end,
    Close = function() M:Close() end,
    StartMoving = function() if not M.db.maximized then S.frame:StartMoving() end end,
    StopMoving = function()
        if M.db.maximized then return end
        S.frame:StopMovingOrSizing()
        local p, _, _, x, y = S.frame:GetPoint(1)
        M.db.windowPos = { p, x, y }
    end,
}


---------------------------------------------------------------------------
-- Ponto de utilidade do guarda (mestre de classe, banco, etc.): GOSSIP_POI_UPDATE
---------------------------------------------------------------------------
local function ReadGossipPin()
    local gi = _G.C_GossipInfo
    if not (gi and gi.GetPoiForUiMapID and gi.GetPoiInfo and S.P and S.P.byID) then return false end
    local id = Safe(C_Map.GetBestMapForUnit, "player")
    local guard = 0
    while id and id > 0 and guard < 8 do
        guard = guard + 1
        local poiID = Safe(gi.GetPoiForUiMapID, id)
        local info = poiID and Safe(gi.GetPoiInfo, id, poiID)
        local pos = info and info.position
        local z = S.P.byID[id]
        if pos and pos.GetXY and z then
            local nx, ny = pos:GetXY()
            S.selQuest = nil
            S.customPin = { mapID = id, x = z.x0 + nx * (z.x1 - z.x0), y = z.y0 + ny * (z.y1 - z.y0),
                            label = info.name or "Ponto de interesse", gossip = true }
            return true
        end
        local mi = Safe(C_Map.GetMapInfo, id)
        id = mi and mi.parentMapID
    end
    return false
end

---------------------------------------------------------------------------
-- Abrir / fechar e a tecla do mapa
---------------------------------------------------------------------------
function M:IsOpen()
    return S.frame and S.frame:IsShown() or false
end

-- ao abrir: centra no personagem, mais perto que a zona inteira (~0,5 px/jarda);
-- dentro de caverna/construção, no zoom máximo para mostrar o interior
local OPEN_PPY = 1.0
local function FocusPlayer()
    if S.mode ~= "terrain" then return end
    local x, y = PlayerXY()
    local c = x and ContAt(x, y)
    if not c then return end
    local indoors = (IsIndoors and IsIndoors()) or InteriorHere()
    local z = indoors and (S.maxZoom or 8) or (OPEN_PPY / abs(c.bx))
    z = max(S.zmin, min(S.maxZoom or 8, z))
    S.anim = nil
    S.zoom = z
    S.ox = S.vw / 2 - x * z
    S.oy = y * z - S.vh / 2
    ClampPan()
    ApplyPan()
    Redraw()
    UpdatePlayer()
end

function M:Open(mapID)
    if not S.frame then Build() end
    if not S.P then S.P = BuildWorld() end
    local G = Azaath:GetModule("MapGather")
    if G and G.Flush then G:Flush() end
    if not S.customPin or S.customPin.gossip then pcall(ReadGossipPin) end
    S.poiCache = nil                           -- voo, masmorras e missões: relidos a cada abertura
    S.qhCache = nil
    S.frame:Show()
    self:ShowMap(mapID or PlayerMap() or WORLD)
    if not mapID then FocusPlayer() end
end

function M:Close()
    if S.frame then S.frame:Hide() end
    S.drag = nil
end

function M:Toggle()
    if self:IsOpen() then self:Close() else self:Open() end
end

function M:OpenDefaultWorldMap()
    if _G.ToggleWorldMap and not InCombatLockdown() then pcall(_G.ToggleWorldMap) end
end

local bindOwner = CreateFrame("Frame")
local toggleButton = CreateFrame("Button", "AzaathUIWorldMapToggle", UIParent)
toggleButton:SetScript("OnClick", function() M:Toggle() end)
local lastSignature

local function UpdateBinding()
    local key1, key2 = GetBindingKey("TOGGLEWORLDMAP")
    local signature = tostring(M.db and M.db.enabled) .. "," .. (key1 or "") .. "," .. (key2 or "")
    if signature == lastSignature then return end
    Azaath:RunOutOfCombat(function()
        lastSignature = signature
        ClearOverrideBindings(bindOwner)
        if not (M.db and M.db.enabled) then return end
        for _, key in ipairs({ key1, key2 }) do
            if key and key ~= "" then
                SetOverrideBindingClick(bindOwner, false, key, "AzaathUIWorldMapToggle", "LeftButton")
            end
        end
    end)
end

function M:OnInitialize()
    self.db = Azaath.db.worldmap
    if self.db.showUnexplored == nil then self.db.showUnexplored = true end
    if self.db.terrain == nil then self.db.terrain = true end
    if self.db.showNames == nil then self.db.showNames = true end
end

-- o jogo só lê uma textura do disco quando ela aparece pela primeira vez (e esquece na tela de
-- carregamento): sem isto, o primeiro mapa aberto mostra os continentes chegando aos pedaços.
-- Pré-carrega, aos poucos, a vista de longe (cópias reduzidas, arte do mar, moldura) e os quadros de
-- perto da zona onde o jogador está (com as máscaras de costa e os lagos), num quadro de 1 px quase invisível.
local preload
local PRELOAD_FRAME = { "ExpOceanL", "ExpOceanR", "ExpLabelsL", "ExpLabelsR", "ExpPaper",
    "ExpTopL", "ExpTopMidL", "ExpBanner", "ExpTopMidR", "ExpTopR", "ExpLeft", "ExpRight", "ExpBotL", "ExpBotMid", "ExpBotR", "ExpFlag",
    "ExpBtnQuests", "ExpBtnLore", "ExpBtnGather", "ExpBtnFilter", "ExpBtnSettings", "ExpBtnCenter", "ExpBtnMax", "ExpBtnClose",
    "ExpPlayerArrow", "ExpPinQuest", "ExpPinTurnIn", "ExpPinNew", "ExpPinRepeat" }
local function PreloadTextures()
    local data = Azaath.MapData or {}
    local files = {}
    for _, n in ipairs(PRELOAD_FRAME) do files[#files + 1] = FRAME_TEX .. n end
    local dir = data.MinimapSea and TERRAIN_S or TERRAIN
    for inst, lod in pairs(data.MinimapLOD or {}) do
        for n, set in pairs(lod) do
            for g in pairs(set) do files[#files + 1] = dir .. inst .. "_" .. n .. "_" .. (g % 64) .. "_" .. floor(g / 64) end
        end
    end
    -- a zona do jogador, de perto
    local id, guard = Safe(C_Map.GetBestMapForUnit, "player"), 0
    while S.P and id and not S.P.byID[id] and guard < 6 do     -- (cidade/sub-zona: sobe até a zona)
        local i = Safe(C_Map.GetMapInfo, id)
        id, guard = i and i.parentMapID, guard + 1
    end
    local here = S.P and id and S.P.byID[id]
    local c = here and (here.kind == "cont" and here or here.cont)
    if here and c and data.MinimapTiles and data.MinimapTiles[c.inst] then
        local c0, c1, r0, r1 = TileRange(c, 1, here.x0, here.y0, here.x1, here.y1)
        local tiles = data.MinimapTiles[c.inst]
        local seaT = data.MinimapSea and data.MinimapSea[c.inst] or {}
        local lake = data.MinimapLake and data.MinimapLake[c.inst] or {}
        if (c1 - c0 + 1) * (r1 - r0 + 1) <= 120 then
            for r = r0, r1 do
                for k = c0, c1 do
                    local key = r * 64 + k
                    if tiles[key] and seaT[key] ~= 2 then
                        files[#files + 1] = tiles[key]
                        if seaT[key] == 1 then files[#files + 1] = LAND .. c.inst .. "_" .. key end
                        if lake[key] then files[#files + 1] = LAKE .. c.inst .. "_" .. key end
                    end
                end
            end
        end
    end
    if not preload then
        preload = CreateFrame("Frame", nil, UIParent)
        preload:SetSize(1, 1)
        preload:SetPoint("BOTTOMLEFT")
        preload:SetAlpha(0.01)
        preload.list = {}
    end
    local i = 0
    preload:SetScript("OnUpdate", function(self)
        for _ = 1, 6 do
            i = i + 1
            local f = files[i]
            if not f then
                for j = i, #self.list do self.list[j]:SetTexture(nil) end
                self:SetScript("OnUpdate", nil)
                return
            end
            local t = self.list[i]
            if not t then
                t = self:CreateTexture(nil, "ARTWORK")
                t:SetAllPoints()
                self.list[i] = t
            end
            t:SetTexture(f)
        end
    end)
end

function M:OnEnable()
    UpdateBinding()
    -- pré-aquece o plano e o LFG no login, e as texturas a cada tela de carregamento: quando o jogador
    -- abrir o mapa ele já está pronto
    local warm = CreateFrame("Frame")
    warm:RegisterEvent("PLAYER_ENTERING_WORLD")
    warm:SetScript("OnEvent", function(self)
        local t = 0
        self:SetScript("OnUpdate", function(_, dt)
            t = t + dt
            if t < 2 then return end
            self:SetScript("OnUpdate", nil)
            if not S.P then
                S.P = BuildWorld()
                LFGByMap()
            end
            PreloadTextures()
        end)
    end)
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("UPDATE_BINDINGS")
    ev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    ev:RegisterEvent("MAP_EXPLORATION_UPDATED")
    ev:RegisterEvent("QUEST_LOG_UPDATE")
    ev:RegisterEvent("TAXIMAP_OPENED")
    for _, e in ipairs({ "GOSSIP_POI_UPDATE", "GOSSIP_CLOSED", "GOSSIP_SHOW" }) do pcall(ev.RegisterEvent, ev, e) end
    ev:SetScript("OnEvent", function(_, event)
        if event == "UPDATE_BINDINGS" then
            UpdateBinding()
        elseif event == "GOSSIP_POI_UPDATE" or event == "GOSSIP_CLOSED" or event == "GOSSIP_SHOW" then
            if not S.P then S.P = BuildWorld() end
            local ok, found = pcall(ReadGossipPin)
            if ok and found then
                S.poiCache = nil
                if M:IsOpen() then LayoutPOI(); LayoutAreas() end
            end
        elseif event == "QUEST_LOG_UPDATE" or event == "TAXIMAP_OPENED" then
            -- missões e voos mudaram: relê na próxima vez (e já, se o mapa estiver aberto, sem repetir à toa)
            S.poiCache = nil
            S.qhCache = nil
            if M:IsOpen() and GetTime() - (S.poiAt or 0) > 1 then
                S.poiAt = GetTime()
                LayoutPOI()
                LayoutAreas()
            end
        elseif event == "ZONE_CHANGED_NEW_AREA" then
            if M:IsOpen() and S.mode == "art" then M:ShowMap(PlayerMap() or S.mapID) end
        else
            M:Refresh()
        end
    end)
end
