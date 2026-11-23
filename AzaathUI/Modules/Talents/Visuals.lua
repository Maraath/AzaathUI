--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Talents/Visuals.lua
    Crisol de talentos: partículas, frasco de essências, correntes de energia e medalhões.
    Símbolos comuns vêm de Azaath.TalentsUI (Modules/Talents/Core.lua).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.TalentsUI
local _G, atan2, floor, format = _G, math.atan2, math.floor, string.format
local ipairs, max, min, pcall = ipairs, math.max, math.min, pcall
local random, sin, sqrt, wipe = math.random, math.sin, math.sqrt, wipe
local AURA_TEX, AZ_BRIGHT, At, CORE_X = U.AURA_TEX, U.AZ_BRIGHT, U.At, U.CORE_X
local CORE_Y, CYAN, Call, CircleMask = U.CORE_Y, U.CYAN, U.Call, U.CircleMask
local EMBLEM_X, EMBLEM_Y, EaseOut, ICON_R = U.EMBLEM_X, U.EMBLEM_Y, U.EaseOut, U.ICON_R
local LABEL_COLS, LOCK_COL, MEDIA, TAL = U.LABEL_COLS, U.LOCK_COL, U.MEDIA, U.TAL
local TREES, TREE_COLORS, Tex, Text = U.TREES, U.TREE_COLORS, U.Tex, U.Text
local Tracked, Upper, WHITE8, ambient = U.Tracked, U.Upper, U.WHITE8, U.ambient
local labels, particles, pending, right = U.labels, U.particles, U.pending, U.right
local segs, top = U.segs, U.top

--------------------------------------------------------------------------------
-- Partículas (faíscas, brasas e poeira de Azaath) e efeitos de ambiente
--------------------------------------------------------------------------------
local partIdx = 0
local function EmitParticle(x, y, col, upSpeed, spread, size, drift)
    if not U.fxF or #particles == 0 then return end
    partIdx = partIdx % #particles + 1
    local p = particles[partIdx]
    spread = spread or 14
    p.x = x + (random() - 0.5) * spread
    p.y = y + (random() - 0.5) * (spread * 0.6)
    p.vx = (random() - 0.5) * (drift or 22)
    p.vy = -(upSpeed or (14 + random() * 26))
    p.life = 0.9 + random() * 0.9
    p.L = p.life
    p.size = size or (2.0 + random() * 3.4)
    col = col or CYAN
    p.tex:SetVertexColor(col[1], col[2], col[3], 1)
    p.tex:Show()
end

local function EmitBurst(cx, cy, col, count)
    for _ = 1, count or 16 do
        EmitParticle(cx, cy, col, 20 + random() * 35, 36)
    end
end

local function BuildAmbient()
    local function G(x, y, w, h, c, layer, sub)
        local t = Tex(U.art, layer or "ARTWORK", MEDIA .. "Glow", "ADD", sub or 0)
        t:SetSize(w, h)
        t:SetVertexColor(c[1], c[2], c[3], 1)
        At(t, U.art, x, y)
        return t
    end
    ambient.coreGlow  = G(CORE_X, CORE_Y + 10, 300, 320, { 0.20, 0.80, 1.00 }, "BORDER", 1)
    ambient.coreHeart = G(CORE_X, CORE_Y, 130, 150, { 0.65, 0.98, 1.00 }, "ARTWORK", 1)
    ambient.vialGlow  = G(447, 197, 90, 90, CYAN, "BORDER", 2)
    ambient.panelGlow = G(EMBLEM_X, EMBLEM_Y, 230, 230, CYAN, "BORDER", 2)
    -- Núcleo Primordial ao selar: clarão, raios, duas auras vivas e ondas de choque
    ambient.coreFlare = G(CORE_X, CORE_Y, 300, 330, { 0.50, 0.96, 1.00 }, "ARTWORK", 3)
    ambient.coreFlare:SetAlpha(0)
    ambient.coreRays = Tex(U.art, "ARTWORK", MEDIA .. "Rays", "ADD", 2)
    ambient.coreRays:SetSize(420, 420)
    ambient.coreRays:SetVertexColor(0.45, 0.92, 1.00, 1)
    At(ambient.coreRays, U.art, CORE_X, CORE_Y + 6)
    ambient.coreRays:SetAlpha(0)
    ambient.coreAura = {}
    for i = 1, 2 do
        local a = Tex(U.art, "ARTWORK", AURA_TEX, "ADD", 2)
        a:SetVertexColor(i == 1 and 0.30 or 0.70, i == 1 and 0.85 or 0.98, 1.00, 1)
        At(a, U.art, CORE_X, CORE_Y + 8)
        a:SetAlpha(0)
        ambient.coreAura[i] = a
    end
    -- ondas dos golpes: anel de fios de energia (o mesmo dos medalhões) girando
    -- enquanto se abre, com uma aura irregular por trás; nada de anel liso
    ambient.shocks = {}
    for i = 1, 3 do
        local sh = { t = -1, parts = {} }
        for k, spec in ipairs({
            { TAL .. "TalentDiagramGlow", { 0.30, 0.85, 1.00 } }, -- aura de borda irregular
            { TAL .. "TalentRings", { 0.45, 0.95, 1.00 } },       -- fios trançados
            { TAL .. "TalentRings", { 0.80, 1.00, 1.00 } },       -- segundo anel, contra-giro
        }) do
            local tx = Tex(U.art, "ARTWORK", spec[1], "ADD", 4)
            tx:SetVertexColor(spec[2][1], spec[2][2], spec[2][3], 1)
            At(tx, U.art, CORE_X, CORE_Y + 8)
            tx:SetAlpha(0)
            sh.parts[k] = tx
        end
        ambient.shocks[i] = sh
    end

    U.fxF = CreateFrame("Frame", nil, U.art)
    U.fxF:SetAllPoints(U.art)
    U.fxF:SetFrameLevel(U.art:GetFrameLevel() + 25)
    for i = 1, 72 do
        local t = Tex(U.fxF, "OVERLAY", (i % 5 == 0) and (MEDIA .. "Star") or (MEDIA .. "Glow"), "ADD", 2)
        t:Hide()
        particles[i] = { tex = t, life = 0 }
    end
end

local function UpdateParticles(dt)
    for _, p in ipairs(particles) do
        if p.life > 0 then
            p.life = p.life - dt
            if p.life <= 0 then
                p.tex:Hide()
            else
                p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
                local u = p.life / p.L
                local s = p.size * (0.6 + u)
                p.tex:SetSize(s, s)
                p.tex:SetAlpha(min(1, u * 2) * 0.9)
                At(p.tex, U.fxF, p.x, p.y)
            end
        end
    end
end

local EMBER_SPARK = { 1.00, 0.55, 0.20 }
local GOLD_SPARK  = { 1.00, 0.80, 0.40 }
local function UpdateAmbient(dt, t)
    ambient.coreGlow:SetAlpha(0.22 + 0.08 * sin(t * 1.9))
    ambient.coreHeart:SetAlpha(0.26 + 0.14 * sin(t * 3.1 + 0.8))
    ambient.vialGlow:SetAlpha(((top.vialBtn and top.vialBtn.hover) and 0.42 or 0.20) + 0.08 * sin(t * 2.6))
    ambient.panelGlow:SetAlpha(0.10 + 0.05 * sin(t * 2.2))
    -- poeira do núcleo, brasas da Fúria, faíscas de Armas e motes de Proteção
    if random() < 0.22 then EmitParticle(CORE_X, CORE_Y + 20, CYAN, 14 + random() * 20, 90, nil, 16) end
    if random() < 0.16 then EmitParticle(40 + random() * 660, 520 + random() * 200, EMBER_SPARK, 10 + random() * 18, 6, 1.6 + random() * 2.2, 30) end
    if random() < 0.06 then EmitParticle(90 + random() * 320, 170 + random() * 260, GOLD_SPARK, 8 + random() * 12, 6, 1.4 + random() * 2, 20) end
    if random() < 0.10 then EmitParticle(720 + random() * 280, 170 + random() * 470, AZ_BRIGHT, 6 + random() * 12, 6, 1.4 + random() * 2.4, 14) end
    UpdateParticles(dt)
end

--------------------------------------------------------------------------------
-- Frasco de essências (topo) e rótulos das árvores
--------------------------------------------------------------------------------

local function BuildTop()
    U.topF = CreateFrame("Frame", nil, U.art)
    U.topF:SetAllPoints(U.art)
    U.topF:SetFrameLevel(U.art:GetFrameLevel() + 5)
    local fontCinzel = Azaath.media.fontCinzel or Azaath.media.fontTitleB

    top.points = Text(U.topF, fontCinzel, 15, { 0.86, 0.94, 0.98 }, "LEFT")
    At(top.points, U.topF, 490, 184, "LEFT")
    top.dot = Tex(U.topF, "OVERLAY", MEDIA .. "Diamond")
    top.dot:SetSize(5, 5)
    top.dot:SetVertexColor(0.55, 0.80, 0.90, 0.9)
    At(top.dot, U.topF, 495, 201)
    top.spec = Text(U.topF, fontCinzel, 10, { 0.55, 0.72, 0.80 }, "LEFT")
    At(top.spec, U.topF, 503, 201, "LEFT")

    -- frasco + textos: clique troca de especialização (quando houver duas)
    top.vialBtn = CreateFrame("Button", nil, U.topF)
    top.vialBtn:SetSize(270, 66)
    At(top.vialBtn, U.topF, 418, 162, "TOPLEFT")
    top.vialBtn:SetScript("OnClick", function()
        local numGroups = (_G.GetNumTalentGroups and Call(_G.GetNumTalentGroups, false, false)) or 1
        if numGroups > 1 and _G.SetActiveTalentGroup and not InCombatLockdown() then
            pcall(SetActiveTalentGroup, (U.specMode == 1) and 2 or 1)
            wipe(pending)
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            EmitBurst(447, 197, CYAN, 12)
            U.dirty = true
        end
    end)
    top.vialBtn:SetScript("OnEnter", function(self)
        self.hover = true
        local numGroups = (_G.GetNumTalentGroups and Call(_G.GetNumTalentGroups, false, false)) or 1
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Essências de Azaath", 1, 0.85, 0.35)
        GameTooltip:AddLine("Pontos de talento livres para infundir.", 0.85, 0.90, 0.95, true)
        if numGroups > 1 then
            GameTooltip:AddLine("Clique para trocar entre a especialização principal e a secundária.", 0.72, 0.86, 0.95, true)
        end
        GameTooltip:Show()
    end)
    top.vialBtn:SetScript("OnLeave", function(self) self.hover = false; GameTooltip:Hide() end)

    for i = 1, 3 do
        local L = TREES[i]
        local fs = Text(U.topF, fontCinzel, 13, LABEL_COLS[i], "CENTER")
        At(fs, U.topF, L.label[1], L.label[2])
        labels[i] = fs
    end
end

U.UpdateLabels = function()
    for i = 1, 3 do
        local info = U.treeData and U.treeData.tabs[i]
        local fs = labels[i]
        if info then
            local staged = 0
            for _, r in ipairs(info.nodes) do staged = staged + (r.rank - r.baseRank) end
            local txt = Tracked(format("%s - %d PTS", Upper(info.name), info.spent))
            if staged > 0 then txt = txt .. format("  |cff52e6ff(+%d)|r", staged) end
            fs:SetText(txt)
        else
            fs:SetText("")
        end
    end
end

--------------------------------------------------------------------------------
-- Correntes de energia (linhas texturizadas que correm do núcleo para fora)
--------------------------------------------------------------------------------

local function NewLine(parent, layer, sub)
    if parent.CreateLine then return parent:CreateLine(nil, layer or "ARTWORK", nil, sub or 0) end
    return Tex(parent, layer or "ARTWORK", WHITE8, "BLEND", sub or 0)
end

local function DrawLine(ln, x1, y1, x2, y2, thickness)
    if ln.SetStartPoint then
        ln:SetStartPoint("TOPLEFT", U.astroF, x1, -y1)
        ln:SetEndPoint("TOPLEFT", U.astroF, x2, -y2)
        ln:SetThickness(thickness or 2)
        return
    end
    local dx, dy = x2 - x1, y2 - y1
    ln:ClearAllPoints()
    ln:SetSize(max(1, sqrt(dx * dx + dy * dy)), thickness or 2)
    ln:SetPoint("CENTER", U.astroF, "TOPLEFT", (x1 + x2) * 0.5, -(y1 + y2) * 0.5)
    if ln.SetRotation then ln:SetRotation(atan2(-dy, dx)) end
end

local function GetSeg(i)
    local s = segs[i]
    if s then return s end
    s = {}
    s.core = NewLine(U.astroF, "BORDER", 3)
    if not (U.lineTiling and pcall(s.core.SetTexture, s.core, TAL .. "CrucibleStream", "REPEAT", "CLAMP")) then
        U.lineTiling = false
        s.core:SetTexture(TAL .. "CrucibleStream")
    end
    segs[i] = s
    return s
end

-- Estilos: "lit" (pontos gastos, corre forte), "open" (liberado, corre fraco),
-- "smoke" (bloqueado: fumaça escura parada)
local function StyleSeg(s, style, col)
    s.style = style
    if style == "smoke" then
        s.core:SetBlendMode("BLEND")
        s.core:SetVertexColor(0.12, 0.13, 0.15, 0.55)
    else
        s.core:SetBlendMode("ADD")
        s.core:SetVertexColor(col[1], col[2], col[3], (style == "lit") and 1 or 0.38)
    end
end

local function SetSegUV(s, off)
    if not U.lineTiling then return end
    local ok = pcall(s.core.SetTexCoord, s.core, s.u0 - off, s.u1 - off, 0, 1)
    if not ok then U.lineTiling = false end
end

-- Desenha uma polilinha como corrente; devolve o comprimento total
-- Corrente = trechos RETOS com a trança larga + halo de pontos de luz.
-- No jogo, toda emenda entre duas linhas deixa marca (fresta ou sobreposição,
-- por causa da suavização das pontas); por isso cada ligação é UMA linha só e o
-- tronco tem poucas dobras, cada uma coberta por um orbe de luz (as contas
-- brilhantes das correntes da arte).
local function Filament(pts, style, col, w, from, to)
    from, to = from or 1, to or #pts - 1
    local tile = w * 4
    local acc = 0
    for i = from, to do
        local a, b = pts[i], pts[i + 1]
        local len = sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
        if len > 0.5 then
            U.segCount = U.segCount + 1
            local s = GetSeg(U.segCount)
            DrawLine(s.core, a[1], a[2], b[1], b[2], w)
            s.u0, s.u1 = acc / tile, (acc + len) / tile
            s.speed = (style == "lit") and 0.55 or 0.18
            StyleSeg(s, style, col)
            SetSegUV(s, 0)
            s.core:Show()
        end
        acc = acc + len
    end
    -- halo: pontos de luz redondos carimbados ao longo da curva (pincel). Sem
    -- cantos, então nem emendas nem curvas fechadas soltam riscos ou feixes.
    local size = w * 3
    local step = size * 0.35
    local A = ambient
    A.dots = A.dots or {}
    local r, g, bl, al, mode
    if style == "smoke" then
        r, g, bl, al, mode = 0.01, 0.02, 0.04, 0.20, "BLEND"
    else
        r, g, bl, al, mode = col[1], col[2], col[3], (style == "lit") and 0.72 or 0.14, "ADD"
    end
    al = al * 0.42 -- os pontos se sobrepõem ~3x
    local need = 0
    for i = from, to do
        local a, b = pts[i], pts[i + 1]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local len = sqrt(dx * dx + dy * dy)
        while need <= len do
            local u = (len > 0) and need / len or 0
            A.dotCount = (A.dotCount or 0) + 1
            local d = A.dots[A.dotCount]
            if not d then
                d = Tex(U.astroF, "BORDER", TAL .. "TalentBtnImbuir", "ADD", 0)
                A.dots[A.dotCount] = d
            end
            d:SetDrawLayer("BORDER", 0)
            d:SetBlendMode(mode)
            d:SetVertexColor(r, g, bl, al)
            d:SetSize(size, size)
            At(d, U.astroF, a[1] + dx * u, a[2] + dy * u)
            d:Show()
            need = need + step
        end
        need = need - len
    end
    -- orbe de luz em cada dobra interna (esconde a junção dos trechos)
    if style ~= "smoke" then
        for i = from + 1, to do
            A.dotCount = A.dotCount + 1
            local d = A.dots[A.dotCount]
            if not d then
                d = Tex(U.astroF, "BORDER", TAL .. "TalentBtnImbuir", "ADD", 0)
                A.dots[A.dotCount] = d
            end
            d:SetDrawLayer("ARTWORK", 1)
            d:SetBlendMode("ADD")
            local wv = 0.45
            d:SetVertexColor(col[1] + (1 - col[1]) * wv, col[2] + (1 - col[2]) * wv, col[3] + (1 - col[3]) * wv,
                (style == "lit") and 1 or 0.45)
            d:SetSize(w * 2.1, w * 2.1)
            At(d, U.astroF, pts[i][1], pts[i][2])
            d:Show()
        end
    end
end

--------------------------------------------------------------------------------
-- Medalhões
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Cantos corais (Media/Sounds/Talents, de tools/talents-concept/gen-sounds.js).
-- Um canto novo corta o anterior com fade, menos o de selar, que é o grande final.
--------------------------------------------------------------------------------
local SND = MEDIA .. "Sounds\\Talents\\Talent"
-- @@CURVAS DOS CANTOS (gerado por tools/talents-concept/gen-sounds.js)@@
local CUE_FPS = 30
local CUE_ENV = {
    Select = {
        0.08, 0.12, 0.19, 0.26, 0.33, 0.43, 0.52, 0.65, 0.82, 0.79, 0.77, 0.83, 1, 0.97, 0.93, 0.88, 0.85, 0.8, 0.79, 0.77, 0.73, 0.72, 0.67, 0.63, 0.64, 0.66, 0.63, 0.59, 0.56, 0.54,
        0.52, 0.49, 0.47, 0.44, 0.42, 0.4, 0.39, 0.37, 0.36, 0.34, 0.31, 0.3, 0.28, 0.26, 0.25, 0.24, 0.23, 0.22, 0.21, 0.19, 0.18, 0.17, 0.16, 0.16, 0.15, 0.14, 0.13, 0.12, 0.11, 0.11,
        0.1, 0.09, 0.08, 0.07, 0.07, 0.06, 0.06, 0.05, 0.05, 0.04, 0.04, 0.04, 0.03, 0.03, 0.03, 0.03, 0.03, 0.02,
    },
    Infuse = {
        0.09, 0.17, 0.27, 0.4, 0.49, 0.52, 0.6, 0.78, 0.78, 0.84, 0.86, 0.89, 0.89, 0.96, 0.97, 0.97, 0.93, 0.93, 0.95, 0.95, 0.94, 0.93, 1, 1, 0.99, 0.99, 0.96, 0.92, 0.89, 0.85,
        0.82, 0.8, 0.78, 0.76, 0.74, 0.72, 0.69, 0.66, 0.62, 0.6, 0.57, 0.54, 0.52, 0.49, 0.46, 0.45, 0.44, 0.42, 0.4, 0.39, 0.37, 0.34, 0.33, 0.31, 0.29, 0.29, 0.28, 0.27, 0.26, 0.25,
        0.24, 0.22, 0.21, 0.2, 0.19, 0.18, 0.17, 0.16, 0.15, 0.15, 0.14, 0.14, 0.13, 0.12, 0.12, 0.11, 0.1, 0.1, 0.09, 0.08, 0.08, 0.07, 0.07, 0.06, 0.06, 0.05, 0.05, 0.05, 0.04, 0.04,
        0.04, 0.04, 0.04, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.03, 0.02,
    },
    Purify = {
        0.04, 0.1, 0.25, 0.46, 0.54, 0.55, 0.55, 0.61, 0.66, 0.69, 0.68, 0.7, 0.76, 0.74, 0.71, 0.69, 0.66, 0.63, 0.6, 0.57, 0.56, 0.56, 0.63, 0.63, 0.91, 0.87, 0.85, 0.88, 0.88, 0.97,
        0.95, 0.93, 0.9, 0.91, 1, 0.99, 0.96, 0.93, 0.92, 0.87, 0.86, 0.85, 0.8, 0.78, 0.77, 0.72, 0.68, 0.64, 0.59, 0.55, 0.51, 0.51, 0.49, 0.47, 0.44, 0.42, 0.39, 0.38, 0.36, 0.35,
        0.33, 0.31, 0.3, 0.3, 0.29, 0.27, 0.26, 0.24, 0.23, 0.22, 0.2, 0.18, 0.17, 0.16, 0.14, 0.13, 0.12, 0.11, 0.1, 0.09, 0.09, 0.08, 0.08, 0.07, 0.07, 0.06, 0.06, 0.06, 0.05, 0.05,
    },
    Seal = {
        0, 0.01, 0.01, 0.02, 0.03, 0.04, 0.04, 0.05, 0.06, 0.07, 0.08, 0.08, 0.09, 0.1, 0.11, 0.12, 0.56, 0.92, 1, 0.99, 0.99, 0.97, 0.94, 0.94, 0.93, 0.89, 0.86, 0.86, 0.84, 0.8,
        0.85, 0.85, 0.83, 0.81, 0.82, 0.78, 0.77, 0.75, 0.75, 0.74, 0.75, 0.74, 0.75, 0.74, 0.74, 0.75, 0.73, 0.7, 0.67, 0.64, 0.63, 0.6, 0.58, 0.54, 0.52, 0.49, 0.46, 0.44, 0.41, 0.39,
        0.38, 0.49, 0.6, 0.62, 0.62, 0.66, 0.65, 0.66, 0.65, 0.67, 0.66, 0.65, 0.68, 0.68, 0.69, 0.67, 0.66, 0.66, 0.63, 0.61, 0.6, 0.62, 0.62, 0.6, 0.59, 0.57, 0.57, 0.55, 0.52, 0.5,
        0.49, 0.47, 0.45, 0.42, 0.56, 0.72, 0.72, 0.72, 0.71, 0.7, 0.69, 0.69, 0.69, 0.68, 0.68, 0.68, 0.67, 0.68, 0.66, 0.66, 0.66, 0.73, 0.72, 0.72, 0.71, 0.75, 0.73, 0.71, 0.73, 0.7,
        0.69, 0.69, 0.67, 0.65, 0.64, 0.63, 0.63, 0.63, 0.62, 0.61, 0.6, 0.59, 0.57, 0.58, 0.57, 0.56, 0.58, 0.58, 0.56, 0.53, 0.51, 0.49, 0.48, 0.46, 0.45, 0.43, 0.41, 0.4, 0.39, 0.38,
        0.37, 0.37, 0.35, 0.34, 0.33, 0.32, 0.31, 0.3, 0.29, 0.28, 0.27, 0.26, 0.25, 0.25, 0.24, 0.24, 0.23, 0.23, 0.21, 0.21, 0.2, 0.19, 0.19, 0.17, 0.16, 0.15, 0.15, 0.14, 0.13, 0.12,
        0.12, 0.11, 0.11, 0.11, 0.1, 0.1,
    },
}
-- @@FIM DAS CURVAS@@

-- Canto tocando agora: o brilho do talento (e do núcleo, no selar) segue a curva
-- de volume do próprio áudio. cue.key = talento que acende (nil = só o card).
-- (estado numa tabela só: o arquivo está perto do limite de 200 locais do Lua)
local Cue = { cur = nil, seal = nil, handle = nil, at = -1 }
local function PlayCue(name, key)
    local now = _G.GetTime and GetTime() or U.clock
    if name == "Select" and now - Cue.at < 0.12 then return end
    if _G.PlaySoundFile then
        if Cue.handle and _G.StopSound then pcall(StopSound, Cue.handle, 350) end
        local ok, willPlay, handle = pcall(PlaySoundFile, SND .. name .. ".ogg", "SFX")
        Cue.handle = (ok and willPlay and name ~= "Seal") and handle or nil
    end
    Cue.at = now
    local c = { name = name, t0 = U.clock, env = CUE_ENV and CUE_ENV[name], key = key }
    if name == "Seal" then Cue.seal = c else Cue.cur = c end
end

-- nível 0..1 da curva no instante atual (interpolado); some ao fim do canto
function Cue.Level(c)
    if not (c and c.env) then return 0 end
    local f = (U.clock - c.t0) * CUE_FPS + 1
    local i = floor(f)
    local a, b = c.env[i], c.env[i + 1]
    if not a then return 0 end
    return a + ((b or 0) - a) * (f - i)
end

-- golpe no canto (subida brusca da curva): devolve true uma vez por golpe
function Cue.Hit(c)
    if not (c and c.env) then return false end
    local i = floor((U.clock - c.t0) * CUE_FPS) + 1
    local a, b = c.env[i], c.env[i - 1]
    if a and b and a - b > 0.09 and c.lastHit ~= i and (not c.lastHit or i - c.lastHit > 6) then
        c.lastHit = i
        return true
    end
    return false
end

-- Brilho junto com a música. Devolve (talento que acende, nível) para o laço
-- dos medalhões; o card e o núcleo são tratados aqui.
local function UpdateCueVisuals(dt, t)
    local cue, lv = Cue.cur, Cue.Level(Cue.cur)
    if cue and cue.env and (U.clock - cue.t0) * CUE_FPS > #cue.env + 2 then Cue.cur, cue, lv = nil, nil, 0 end
    local sealCue, sl = Cue.seal, Cue.Level(Cue.seal)
    if sealCue and sealCue.env and (U.clock - sealCue.t0) * CUE_FPS > #sealCue.env + 2 then Cue.seal, sealCue, sl = nil, nil, 0 end

    -- card: o ícone acende com o canto do talento mostrado (e com o selar)
    local shown = U.hovKey or U.selKey
    local pl = (cue and (cue.key == nil or cue.key == shown)) and lv or 0
    pl = max(pl, sl * 0.7)
    right.cueLv = pl

    -- núcleo: só no selar
    local A = ambient
    A.coreFlare:SetAlpha(sl * 0.85)
    local fs = 300 * (0.85 + 0.35 * sl)
    A.coreFlare:SetSize(fs, fs * 1.1)
    A.coreRays:SetAlpha(sl * 0.55)
    A.coreRays:SetSize(380 + 160 * sl, 380 + 160 * sl)
    if A.coreRays.SetRotation then A.coreRays:SetRotation(t * 0.35) end
    for i, a in ipairs(A.coreAura) do
        local br = 0.5 + 0.5 * sin(t * (i == 1 and 2.1 or 3.7) + i)
        local sz = (i == 1 and 260 or 330) * (0.9 + 0.25 * sl + 0.06 * br)
        a:SetSize(sz, sz)
        if a.SetRotation then a:SetRotation((i == 1 and 1 or -1) * t * (0.4 + 0.3 * i)) end
        a:SetAlpha(sl * (i == 1 and 0.75 or 0.45) * (0.7 + 0.3 * br))
    end
    A.coreGlow:SetAlpha(min(1, A.coreGlow:GetAlpha() + sl * 0.6))
    A.coreHeart:SetAlpha(min(1, A.coreHeart:GetAlpha() + sl * 0.7))
    if sl > 0.15 and random() < sl * 0.9 then
        EmitParticle(CORE_X, CORE_Y + 10, (random() < 0.5) and CYAN or AZ_BRIGHT, 30 + random() * 50 * sl, 120, 2 + random() * 3, 60)
    end
    if Cue.Hit(sealCue) then
        -- golpe do coral: onda de choque e chuva de faíscas
        for _, sh in ipairs(A.shocks) do
            if sh.t < 0 then
                sh.t, sh.ph, sh.spin = 0, random() * 6.283, (random() < 0.5) and -1 or 1
                sh.dur = 1.1 + random() * 0.4
                break
            end
        end
        EmitBurst(CORE_X, CORE_Y, AZ_BRIGHT, 28)
    end
    for _, sh in ipairs(A.shocks) do
        if sh.t >= 0 then
            sh.t = sh.t + dt
            local u = sh.t / sh.dur
            if u >= 1 then
                sh.t = -1
                for _, p in ipairs(sh.parts) do p:SetAlpha(0) end
            else
                local e = EaseOut(u)
                local fade = (1 - u) ^ 1.6
                -- borda respirando e levemente achatada, girando enquanto se abre
                local wob = sin(sh.t * 7 + sh.ph) * 0.07
                local rot = sh.ph + sh.spin * sh.t * 1.4
                local a, r1, r2 = sh.parts[1], sh.parts[2], sh.parts[3]
                local sa = 160 + 380 * e
                a:SetSize(sa * (1 + wob), sa * (1 - wob))
                a:SetAlpha(fade * 0.55)
                local sr = 110 + 360 * EaseOut(min(1, u * 1.15))
                r1:SetSize(sr * (1 - wob * 0.6), sr * (1 + wob * 0.6))
                r1:SetAlpha(fade * 0.85)
                local sr2 = sr * (0.88 + 0.06 * sin(sh.t * 5 + sh.ph))
                r2:SetSize(sr2, sr2)
                r2:SetAlpha(fade * 0.45 * (0.6 + 0.4 * sin(sh.t * 9 + sh.ph)))
                if a.SetRotation then
                    a:SetRotation(rot)
                    r1:SetRotation(rot * 1.3)
                    r2:SetRotation(-rot * 1.7 + 1)
                end
            end
        end
    end

    -- medalhão do talento do canto (infundir, escolher, retirar)
    local key = cue and cue.key
    if Cue.Hit(cue) and key and U.treeData and U.treeData.byKey[key] then
        local r = U.treeData.byKey[key]
        EmitBurst(r.cx, r.cy, TREE_COLORS[r.tab] or CYAN, 10)
    end
    return key, lv
end

local function NodeState(r)
    if r.rank >= r.max then return "max" end
    if not r.available then return "locked" end
    if r.canBuy then return "buy" end
    if r.rank > 0 then return "prog" end
    return "nopts"
end

-- Moldura de energia (tools/talents-concept/gen-ring.js): fios trançados com
-- raio de 80px numa textura de 256. Duas camadas girando em sentidos opostos.
local RING_TEX = TAL .. "TalentRings"
local function RingPx(radius) return radius * 2 * 128 / 80 end

local function StyleEnergyRing(t1, t2, col, locked)
    if locked then
        -- bloqueado: fumaça escura, como as correntes ainda fechadas
        t1:SetBlendMode("BLEND"); t2:SetBlendMode("BLEND")
        t1:SetVertexColor(0.30, 0.32, 0.36, 0.60)
        t2:SetVertexColor(0.18, 0.19, 0.22, 0.45)
    else
        t1:SetBlendMode("ADD"); t2:SetBlendMode("ADD")
        t1:SetVertexColor(col[1], col[2], col[3], 1)
        t2:SetVertexColor(0.55 + col[1] * 0.45, 0.55 + col[2] * 0.45, 0.55 + col[3] * 0.45, 0.85)
    end
end

local function Node_OnEnter(self)
    self.hover = true
    if not self.rec then return end
    U.hovKey = self.rec.key
    U.UpdateRight(false)
    local r = self.rec
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(r.name, 1, 1, 1)
    GameTooltip:AddLine(format("Grau %d / %d", r.rank, r.max), 0.74, 0.80, 0.86)
    local st = NodeState(r)
    GameTooltip:AddLine("Clique: ver os detalhes", AZ_BRIGHT[1], AZ_BRIGHT[2], AZ_BRIGHT[3])
    if st == "buy" then
        GameTooltip:AddLine("Infunda pelo botão INFUNDIR AZAATH", 0.74, 0.80, 0.86)
    elseif st == "locked" then
        GameTooltip:AddLine("Bloqueado: veja o motivo no painel", LOCK_COL[1], LOCK_COL[2], LOCK_COL[3])
    elseif st == "nopts" or st == "prog" then
        GameTooltip:AddLine("Sem essências livres", 0.62, 0.66, 0.72)
    end
    GameTooltip:Show()
end

local function Node_OnLeave(self)
    self.hover = false
    if self.rec and U.hovKey == self.rec.key then U.hovKey = nil end
    GameTooltip:Hide()
    U.UpdateRight(false)
end

local function Node_OnClick(self, button)
    local r = self.rec
    if not r then return end
    -- o clique só escolhe o talento (detalhes no painel); o ponto entra pelo
    -- botão INFUNDIR AZAATH e sai por "Retirar 1 ponto"
    if U.selKey ~= r.key then
        U.SelectNode(r.key)
        PlayCue("Select", r.key)
    end
end

local MAX_PIPS = 5
local function CreateNodeButton()
    local b = CreateFrame("Button", nil, U.astroF)
    b:SetFrameLevel(U.astroF:GetFrameLevel() + 3)
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b.pop, b.lift, b.fx = 1, 1, 0

    -- aura viva: duas camadas de halo de borda irregular girando em sentidos
    -- opostos, cada medalhão com fase e ritmo próprios (nada sincronizado)
    b.aura = Tex(b, "BACKGROUND", AURA_TEX, "ADD", 0)
    b.aura:SetPoint("CENTER")
    b.aura:SetAlpha(0)
    b.aura2 = Tex(b, "BACKGROUND", AURA_TEX, "ADD", 0)
    b.aura2:SetPoint("CENTER")
    b.aura2:SetAlpha(0)
    b.ph, b.sp, b.spin = random() * 6.283, 0.75 + random() * 0.5, (random() < 0.5) and -1 or 1

    b.backdrop = Tex(b, "BACKGROUND", WHITE8, "BLEND", 1)
    b.backdrop:SetPoint("CENTER")
    b.backdrop:SetVertexColor(0.02, 0.03, 0.05, 1)
    CircleMask(b, b.backdrop)

    b.icon = Tex(b, "ARTWORK", nil, "BLEND", 1)
    b.icon:SetPoint("CENTER")
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    CircleMask(b, b.icon)

    -- véu da cor da árvore sobre o ícone (os glifos da arte são monocromáticos)
    b.tint = Tex(b, "ARTWORK", MEDIA .. "Disc", "ADD", 2)
    b.tint:SetPoint("CENTER")
    b.tint:SetAlpha(0)

    b.ring = Tex(b, "OVERLAY", RING_TEX, "ADD", 1)
    b.ring:SetPoint("CENTER")
    b.ring2 = Tex(b, "OVERLAY", RING_TEX, "ADD", 2)
    b.ring2:SetPoint("CENTER")

    b.sel = Tex(b, "OVERLAY", MEDIA .. "CastRingThin", "ADD", 4)
    b.sel:SetPoint("CENTER")
    b.sel:SetVertexColor(0.85, 0.97, 1.0, 1)
    b.sel:SetAlpha(0)

    -- prévia (infundido, ainda não selado): anel ciano em ondas
    b.stage = Tex(b, "OVERLAY", MEDIA .. "CastRingThin", "ADD", 4)
    b.stage:SetPoint("CENTER")
    b.stage:SetVertexColor(0.32, 0.90, 1.0, 1)
    b.stage:SetAlpha(0)
    b.stageWave = Tex(b, "OVERLAY", MEDIA .. "CastRingThin", "ADD", 4)
    b.stageWave:SetPoint("CENTER")
    b.stageWave:SetVertexColor(0.32, 0.90, 1.0, 1)
    b.stageWave:SetAlpha(0)

    b.flash = Tex(b, "OVERLAY", MEDIA .. "Glow", "ADD", 5)
    b.flash:SetPoint("CENTER")
    b.flash:SetVertexColor(AZ_BRIGHT[1], AZ_BRIGHT[2], AZ_BRIGHT[3], 1)
    b.flash:SetAlpha(0)

    -- losangos de pontos (como sob os medalhões de Proteção na arte)
    b.pips = {}
    for i = 1, MAX_PIPS do
        local p = Tex(b, "OVERLAY", MEDIA .. "Diamond", "BLEND", 3)
        p:SetSize(6, 6)
        b.pips[i] = p
    end

    b:SetScript("OnEnter", Node_OnEnter)
    b:SetScript("OnLeave", Node_OnLeave)
    b:SetScript("OnClick", Node_OnClick)
    return b
end

local function SizeNode(b, r)
    local ir = r.iconR or ICON_R.normal
    local ringPx = 128 * ir / 30
    b:SetSize(ir * 2 + 10, ir * 2 + 10)
    b.icon:SetSize(ir * 2, ir * 2)
    b.backdrop:SetSize(ir * 2, ir * 2)
    b.tint:SetSize(ir * 2, ir * 2)
    ringPx = RingPx(ir + (r.cap and 2.5 or 1.5))
    b.ring:SetSize(ringPx, ringPx)
    b.ring2:SetSize(ringPx * 1.04, ringPx * 1.04)
    b.ir = ir
    b.sel:SetSize(ir * 3.2, ir * 3.2)
    b.flash:SetSize(ir * 5, ir * 5)
    local n = min(MAX_PIPS, r.max)
    local y = -(ir * 1.36 + 6)
    for i = 1, MAX_PIPS do
        local p = b.pips[i]
        if i <= n then
            p:ClearAllPoints()
            p:SetPoint("CENTER", b, "CENTER", (i - (n + 1) / 2) * 7.5, y)
            p:Show()
        else
            p:Hide()
        end
    end
end

local function PlaceNode(b)
    local sc = max(0.05, b.pop * b.lift)
    b:SetScale(sc)
    b:ClearAllPoints()
    b:SetPoint("CENTER", U.astroF, "TOPLEFT", b.cx / sc, -b.cy / sc)
end

local function ApplyNodeVisual(b)
    local r = b.rec
    local col = TREE_COLORS[r.tab] or CYAN
    local st = NodeState(r)
    b.state = st
    SizeNode(b, r)
    b.icon:SetTexture(r.icon)
    local locked = (st == "locked")
    StyleEnergyRing(b.ring, b.ring2, col, locked)
    b.ringLocked = locked
    b.staged = (r.rank or 0) > (r.baseRank or 0)
    -- liberado mas sem grau: moldura fraca respirando, ícone meio apagado
    b.dormant = (not locked) and (r.rank or 0) == 0
    b.icon:SetDesaturated(locked or b.dormant)
    b.tint:SetVertexColor(col[1], col[2], col[3], 1)
    b.aura:SetVertexColor(col[1], col[2], col[3], 1)
    b.aura2:SetVertexColor(0.55 + col[1] * 0.45, 0.55 + col[2] * 0.45, 0.55 + col[3] * 0.45, 1)

    if locked then
        b.icon:SetVertexColor(0.36, 0.36, 0.38, 1)
        b.tint:SetAlpha(0)
    elseif b.dormant then
        b.icon:SetVertexColor(0.70, 0.72, 0.76, 1)
        b.tint:SetAlpha(0.18)
    elseif st == "nopts" then
        b.icon:SetVertexColor(0.62, 0.64, 0.68, 1)
        b.tint:SetAlpha(0.06)
    elseif st == "buy" and r.rank == 0 then
        b.icon:SetVertexColor(0.85, 0.86, 0.88, 1)
        b.tint:SetAlpha(0.10)
    else
        b.icon:SetVertexColor(1, 1, 1, 1)
        b.tint:SetAlpha(0.16)
    end

    -- losangos: acesos = pontos (prévia em ciano), apagados = o que falta
    local litC = { 0.55 + col[1] * 0.45, 0.55 + col[2] * 0.45, 0.55 + col[3] * 0.45 }
    for i = 1, min(MAX_PIPS, r.max) do
        local p = b.pips[i]
        if i <= r.baseRank then
            p:SetVertexColor(litC[1], litC[2], litC[3], 1)
        elseif i <= r.rank then
            p:SetVertexColor(AZ_BRIGHT[1], AZ_BRIGHT[2], AZ_BRIGHT[3], 1)
        else
            p:SetVertexColor(0.22, 0.24, 0.27, locked and 0.55 or 0.85)
        end
    end
end

-- compartilhado com os outros arquivos de Modules/Talents/
U.ApplyNodeVisual, U.BuildAmbient, U.BuildTop, U.CreateNodeButton = ApplyNodeVisual, BuildAmbient, BuildTop, CreateNodeButton
U.EmitBurst, U.Filament, U.NodeState, U.PlaceNode = EmitBurst, Filament, NodeState, PlaceNode
U.PlayCue, U.SetSegUV, U.UpdateAmbient, U.UpdateCueVisuals = PlayCue, SetSegUV, UpdateAmbient, UpdateCueVisuals
