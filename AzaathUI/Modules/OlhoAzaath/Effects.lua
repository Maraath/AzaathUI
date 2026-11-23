--[[----------------------------------------------------------------------------
    AzaathUI - Olho de Azaath / Effects.lua
    Os desenhos do brilho. Cada efeito é uma tabela:
      Build(fx, Layer)   cria as camadas; Layer(imagem, camada, subnível, mistura)
      Update(fx, c)      anima a partir do contexto c (ver Glow.lua)
      wave / flat        imagem das ondas e achatamento (sem wave, sem ondas)
      waveGain, ping     força das ondas; ping=false desliga a onda periódica
      band               imagem da dissipação (sem ela: um brilho simples)
      icon               desenho no botão do menu: { imagem, larg, alt, x, y, opac[, claro] }
    Update pode deixar fx.waveSize, fx.waveY e fx.waveAngle para as ondas.
    O LootBeam reutiliza a "aura" com o mesmo contrato.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local ns = Azaath.OlhoNS

local sin, cos, min, max, sqrt, abs, floor = math.sin, math.cos, math.min, math.max, math.sqrt, math.abs, math.floor
local random, pi = math.random, math.pi
local atan2 = math.atan2 or function(y, x) return math.atan(y, x) end
local TAU = 2 * pi

local FLOOR = 0.36   -- achatamento de um círculo deitado no chão visto pela câmera
local ORBIT = 0.37   -- raio do anel fino nas imagens ring/arcs (fração da largura)
local FEET = -0.12   -- altura do chão em relação ao centro do objeto (fração do tamanho)

--------------------------------------------------------------------------------
-- Peças
--------------------------------------------------------------------------------

local function mix(a, b, t) return a + (b - a) * t end
local function wave01(x) return 0.5 + 0.5 * sin(x) end

local function size(t, w, h) t:SetSize(max(w, 0.01), max(h or w, 0.01)) end
local function paint(t, r, g, b, a) t:SetVertexColor(r, g, b, a <= 0 and 0 or (a >= 1 and 1 or a)) end
local function put(t, f, x, y) t:SetPoint("CENTER", f, "CENTER", x, y) end

ns.Lerp, ns.Sized, ns.Tint, ns.Place = mix, size, paint, put

-- véu escuro (BLEND) para o efeito aditivo não sumir em neve ou areia
local function veil(t, c, w, h, a)
    size(t, w, h)
    paint(t, 0, 0, 0, c.alpha * a)
end

-- véu deitado no chão
local function floorVeil(t, c, w, y)
    size(t, w, w * FLOOR * 1.3)
    put(t, c.frame, 0, y)
    paint(t, 0, 0, 0, c.alpha * 0.30)
end

-- poça de luz no pé do objeto
local function pool(t, c, scale, y, lo, hi)
    local w = c.size * (scale + 0.10 * c.breath)
    size(t, w, w * FLOOR * 1.3)
    put(t, c.frame, 0, y)
    paint(t, c.r, c.g, c.b, c.alpha * mix(lo or 0.55, hi or 0.90, c.ready))
end

-- núcleo cintilante (imagem flare): cresce ao alcance e no clarão de "travou"
local function core(t, c, base, lo, hi, x, y, grow)
    size(t, c.size * (base + (grow or 0.08) * c.ready + 0.04 * c.twinkle + 0.30 * c.flash))
    if x then put(t, c.frame, x, y) end
    paint(t, c.wr, c.wg, c.wb,
        c.alpha * (mix(lo, hi, c.ready) * (0.7 + 0.3 * c.twinkle) + 0.4 * c.flash) * (1 - c.locked))
end

-- rastro: lista de camadas [0..n] onde 0 é a cabeça; pos(k) devolve x, y, escala
local function trail(list, n, c, pos, headSize, tailSize, decay, headA, tailA)
    for k = 0, n do
        local x, y, s = pos(k)
        local t = list[k]
        put(t, c.frame, x, y)
        size(t, c.size * (k == 0 and headSize or tailSize) * (s or 1) * decay ^ k)
        if k == 0 then
            paint(t, c.wr, c.wg, c.wb, headA)
        else
            paint(t, c.hr, c.hg, c.hb, tailA * 0.75 ^ k)
        end
    end
end

local function makeTrail(Layer, n, layer)
    local list = {}
    for k = n, 0, -1 do list[k] = Layer("glow", layer or "OVERLAY", k == 0 and 1 or 0) end
    return list
end

local E = {}
ns.EFFECTS = E
ns.EFFECT_ORDER = { "aura", "subtle", "sigil", "brackets", "vortex", "rift", "flame", "storm", "beam", "geyser",
    "beacon", "orbit", "spirit", "ripple", "sparkle" }

--------------------------------------------------------------------------------
-- Halos (aura, discreto e reserva): a mesma montagem com pesos diferentes
--------------------------------------------------------------------------------

local function Halo(w)
    local e = { band = "halo", wave = "ring", waveGain = w.waves }

    function e.Build(fx, Layer)
        fx.veil = Layer("halo", "BACKGROUND", -1, "BLEND")
        fx.band = Layer("halo", "BACKGROUND")
        fx.mist = { Layer("wisp", "BACKGROUND", 1), Layer("wisp", "BACKGROUND", 1) }
        fx.ring = Layer("ring", "ARTWORK")
        fx.comets = Layer("arcs", "ARTWORK", 1)
        fx.fireflies = { Layer("glow", "OVERLAY"), Layer("glow", "OVERLAY"), Layer("glow", "OVERLAY") }
        fx.heart = Layer("flare", "OVERLAY", 1)
        if w.crown then
            fx.tongues, fx.sparks = {}, {}
            for i = 1, 7 do fx.tongues[i] = Layer("flame", "BACKGROUND", 2) end
            for i = 1, 5 do fx.sparks[i] = Layer("glow", "OVERLAY") end
        end
    end

    function e.Update(fx, c)
        local a, ready, locked, flash = c.alpha, c.ready, c.locked, c.flash
        local s = c.size * (1 + 0.45 * (1 - c.arrive)) -- chega aberto e se fecha
        local live = 1 - locked
        fx.waveSize = s

        veil(fx.veil, c, s * 1.06, s * 1.06, w.shade * 0.30)
        size(fx.band, s * (0.96 + 0.07 * c.breath))
        paint(fx.band, c.r, c.g, c.b, a * w.band * mix(0.50, 0.80, ready) * (0.8 + 0.2 * c.breath))

        -- névoa: dois véus de filamentos girando em sentidos opostos
        local mist = a * w.mist * (mix(0.28, 0.42, ready) + 0.3 * flash) * (1 - 0.6 * locked)
        size(fx.mist[1], s * 1.03); fx.mist[1]:SetRotation(0.22 * c.spin)
        paint(fx.mist[1], c.hr, c.hg, c.hb, mist)
        size(fx.mist[2], s * 0.93); fx.mist[2]:SetRotation(2.1 - 0.31 * c.spin)
        paint(fx.mist[2], c.hr, c.hg, c.hb, mist * 0.8)

        size(fx.ring, s)
        paint(fx.ring, c.hr, c.hg, c.hb, a * w.ring * (mix(0.25, 0.75, ready) + 0.25 * flash))
        size(fx.comets, s); fx.comets:SetRotation(c.spin)
        paint(fx.comets, c.hr, c.hg, c.hb, a * w.comets * mix(0.45, 0.95, ready) * live)

        size(fx.heart, s * (0.34 + 0.10 * ready + 0.04 * c.twinkle + 0.30 * flash + 0.50 * (1 - c.arrive)))
        fx.heart:SetRotation(0.10 * sin(c.phase * 0.5))
        paint(fx.heart, c.wr, c.wg, c.wb,
            a * w.heart * (mix(0.35, 0.90, ready) * (0.7 + 0.3 * c.twinkle) + 0.4 * flash) * live)

        if fx.tongues then
            -- coroa: línguas de fogo lambendo o anel para fora, e fagulhas escapando
            local t = -c.spin
            local n = #fx.tongues
            for i, tongue in ipairs(fx.tongues) do
                local ang = 0.12 * c.spin + i * TAU / n + 0.25 * sin(t * 0.7 + i * 1.7)
                local beat = wave01(t * (2.6 + 0.37 * i) + i * 2.1)
                local len = s * (0.20 + 0.16 * beat + 0.10 * ready + 0.30 * flash)
                local rad = s * 0.35 + len * 0.42
                size(tongue, s * 0.22, len)
                put(tongue, c.frame, cos(ang) * rad, sin(ang) * rad)
                tongue:SetRotation(ang - pi / 2)
                paint(tongue, c.r, c.g, c.b, a * w.crown * (mix(0.35, 0.70, ready) + 0.3 * flash) * (0.7 + 0.3 * beat) * live)
            end
            local m = #fx.sparks
            for i, spark in ipairs(fx.sparks) do
                local cyc = t * 0.33 + i / m
                local f = cyc % 1
                local ang = i * 2.4 + floor(cyc) * 1.9 + 0.6 * f
                local rad = s * (0.37 + 0.45 * f)
                put(spark, c.frame, cos(ang) * rad, sin(ang) * rad)
                size(spark, s * 0.10 * (1 - 0.6 * f))
                paint(spark, c.hr, c.hg, c.hb, a * w.crown * sin(pi * f) * mix(0.40, 1, ready) * live)
            end
        end

        -- vaga-lumes em órbita no anel, contra os cometas
        local r = s * ORBIT
        for i, fly in ipairs(fx.fireflies) do
            local ang = -0.6 * c.spin + i * TAU / 3
            local glint = wave01(c.phase * 3.1 + i * 2.1)
            put(fly, c.frame, cos(ang) * r, sin(ang) * r)
            size(fly, s * (0.10 + 0.05 * glint))
            paint(fly, c.hr, c.hg, c.hb, a * w.flies * ready * live * (0.45 + 0.55 * glint))
        end
    end

    return e
end

E.aura = Halo({ crown = 1, shade = 1.0, band = 0.75, mist = 1.0, ring = 0.85, comets = 0.90, heart = 0.90, flies = 1, waves = 1.0 })
E.subtle = Halo({ shade = 0.8, band = 0.75, mist = 0.5, ring = 0, comets = 0, heart = 0.45, flies = 0, waves = 0.4 })
E.fallback = Halo({ shade = 0, band = 1.0, mist = 0, ring = 0, comets = 0, heart = 1.0, flies = 0, waves = 0 })
E.aura.icon = { { "halo", 1, 1, 0, 0, 0.45 }, { "wisp", 1, 1, 0, 0, 0.5 }, { "ring", 1, 1, 0, 0, 1 }, { "flare", 0.6, 0.6, 0, 0, 1, true } }
E.subtle.icon = { { "halo", 1, 1, 0, 0, 0.9 }, { "flare", 0.36, 0.36, 0, 0, 0.6, true } }

--------------------------------------------------------------------------------
-- Selo: círculo de runas e figura interna girando em sentidos opostos
--------------------------------------------------------------------------------

E.sigil = {
    band = "halo", wave = "ring",
    icon = { { "sigil", 1, 1, 0, 0, 1 }, { "glyph", 0.7, 0.7, 0, 0, 0.9, true } },
    Build = function(fx, Layer)
        fx.veil = Layer("halo", "BACKGROUND", -1, "BLEND")
        fx.band = Layer("halo", "BACKGROUND")
        fx.circle = Layer("sigil", "ARTWORK")
        fx.figure = Layer("glyph", "ARTWORK", 1)
        fx.heart = Layer("flare", "OVERLAY")
        fx.turn = 0
    end,
    Update = function(fx, c)
        local a, ready, locked, flash = c.alpha, c.ready, c.locked, c.flash
        local s = c.size * (1 + 0.30 * (1 - c.arrive))
        fx.waveSize = s
        -- acelera ao alcance, congela quando recusado
        fx.turn = fx.turn + c.elapsed * (mix(0.22, 0.55, ready) + 2.5 * flash) * (1 - locked)
        veil(fx.veil, c, s * 1.10, s * 1.10, 0.34)
        size(fx.band, s * (0.94 + 0.05 * c.breath))
        paint(fx.band, c.r, c.g, c.b, a * mix(0.28, 0.48, ready) * (0.8 + 0.2 * c.breath))
        local d = s * 0.94 * (1 + 0.06 * flash)
        size(fx.circle, d); fx.circle:SetRotation(fx.turn)
        paint(fx.circle, c.hr, c.hg, c.hb, a * (mix(0.55, 0.95, ready) + 0.25 * flash))
        size(fx.figure, d * 0.72); fx.figure:SetRotation(-1.6 * fx.turn)
        paint(fx.figure, c.hr, c.hg, c.hb, a * mix(0.38, 0.85, ready) * (1 - 0.4 * locked))
        core(fx.heart, c, 0.26, 0.20, 0.80)
    end,
}

--------------------------------------------------------------------------------
-- Mira: quatro cantos em losango buscam o objeto e se fecham em quadrado ao alcance
--------------------------------------------------------------------------------

local CORNER = 0.37 -- posição dos cantos na imagem brackets (fração da largura)

-- ponto do contorno de um quadrado de meio-lado 1 (um lado por unidade de p)
local function edge(p)
    local side, u = floor(p) % 4, 2 * (p % 1) - 1
    if side == 0 then return 1, u end
    if side == 1 then return -u, 1 end
    if side == 2 then return -1, -u end
    return u, -1
end

E.brackets = {
    wave = "brackets", waveGain = 0.7,
    icon = { { "glow", 1, 1, 0, 0, 0.45 }, { "brackets", 0.94, 0.94, 0, 0, 1 }, { "ring", 0.62, 0.62, 0, 0, 0.55 },
        { "flare", 0.4, 0.4, 0, 0, 0.9, true } },
    Build = function(fx, Layer)
        fx.veil = Layer("glow", "BACKGROUND", -1, "BLEND")
        fx.haze = Layer("glow", "BACKGROUND")
        fx.ghosts = { { t = Layer("brackets", "BORDER", 1), k = 9 }, { t = Layer("brackets", "BORDER", 1), k = 4.5 } }
        fx.frameTex = Layer("brackets", "ARTWORK")
        fx.focus = Layer("ring", "ARTWORK", 1)
        fx.inner = Layer("brackets", "ARTWORK", 2)
        fx.runners = {}
        for i = 1, 4 do fx.runners[i] = makeTrail(Layer, 3) end
        fx.darts = {}
        for i = 1, 4 do fx.darts[i] = Layer("flare", "OVERLAY", 1) end
        fx.heart = Layer("flare", "OVERLAY", 2)
    end,
    Update = function(fx, c)
        local a, ready, locked, flash = c.alpha, c.ready, c.locked, c.flash
        local live = 1 - locked
        local t = -c.spin
        -- encaixe com leve passada do ponto (curva "back")
        local b = ready - 1
        local snap = 1 + 2.70158 * b * b * b + 1.70158 * b * b
        local hunt = (0.10 * sin(t * 0.9) + 0.05 * sin(t * 2.3 + 1)) * (1 - ready) * live
        local ang = (1 - snap) * pi / 4 + hunt
        local s = c.size * (mix(1.02, 0.94, snap) + 0.035 * c.breath * (1 - ready) + 0.40 * (1 - c.arrive))
        fx.waveSize, fx.waveAngle = s, ang

        veil(fx.veil, c, s * 2.0, s * 2.0, 0.30)
        size(fx.haze, s * (1.5 + 0.1 * c.breath))
        paint(fx.haze, c.r, c.g, c.b, a * mix(0.30, 0.50, ready))

        -- cópias atrasadas da moldura: só aparecem enquanto ela gira
        for _, g in ipairs(fx.ghosts) do
            local k = min(c.elapsed * g.k, 1)
            g.ang = mix(g.ang or ang, ang, k)
            g.s = mix(g.s or s, s, k)
            size(g.t, g.s); g.t:SetRotation(g.ang)
            paint(g.t, c.r, c.g, c.b, a * min(abs(ang - g.ang) * 5, 1) * 0.35)
        end

        size(fx.frameTex, s); fx.frameTex:SetRotation(ang)
        paint(fx.frameTex, c.hr, c.hg, c.hb, a * (mix(0.60, 0.95, ready) + 0.25 * flash))
        size(fx.focus, s * mix(1.20, 0.74, snap))
        paint(fx.focus, c.hr, c.hg, c.hb, a * 0.55 * ready * live)
        size(fx.inner, s * (mix(0.56, 0.44, snap) + 0.05 * flash)); fx.inner:SetRotation(pi / 4 - ang)
        paint(fx.inner, c.wr, c.wg, c.wb, a * (0.80 * ready + 0.2 * flash) * live)

        -- lampejos correndo pela moldura
        local half = s * CORNER
        local ca, sa = cos(ang), sin(ang)
        for i, list in ipairs(fx.runners) do
            trail(list, 3, c, function(k)
                local x, y = edge(t * 0.55 + i - k * 0.07)
                return (x * ca - y * sa) * half, (x * sa + y * ca) * half
            end, 0.13, 0.11, 0.85, a * mix(0.35, 1, ready) * live, a * mix(0.25, 0.80, ready) * live)
        end

        -- ao travar, um lampejo sai de cada canto
        for i, dart in ipairs(fx.darts) do
            local corner = ang + (i - 0.5) * pi / 2
            local reach = half * sqrt(2) * (1 + 0.9 * (1 - flash))
            put(dart, c.frame, cos(corner) * reach, sin(corner) * reach)
            size(dart, s * (0.14 + 0.24 * flash)); dart:SetRotation(corner)
            paint(dart, c.wr, c.wg, c.wb, a * flash * live)
        end
        core(fx.heart, c, 0.22, 0.12, 0.85, nil, nil, 0.10)
    end,
}

--------------------------------------------------------------------------------
-- Vórtice: braços de luz se enrolando, como um portal se abrindo
--------------------------------------------------------------------------------

E.vortex = {
    band = "halo", wave = "ring", waveGain = 0.7,
    icon = { { "halo", 1, 1, 0, 0, 0.4 }, { "swirl", 1.05, 1.05, 0, 0, 1 }, { "flare", 0.4, 0.4, 0, 0, 0.9, true } },
    Build = function(fx, Layer)
        fx.veil = Layer("halo", "BACKGROUND", -1, "BLEND")
        fx.band = Layer("halo", "BACKGROUND")
        fx.outer = Layer("swirl", "ARTWORK")
        fx.inner = Layer("swirl", "ARTWORK", 1)
        fx.motes = {}
        for i = 1, 7 do fx.motes[i] = { Layer("glow", "OVERLAY"), Layer("glow", "OVERLAY") } end
        fx.heart = Layer("flare", "OVERLAY")
        fx.turn = 0
    end,
    Update = function(fx, c)
        local a, ready, locked, flash = c.alpha, c.ready, c.locked, c.flash
        local live = 1 - locked
        local s = c.size * (1 + 0.35 * (1 - c.arrive))
        fx.waveSize = s
        fx.turn = fx.turn + c.elapsed * (mix(0.55, 1.15, ready) + 3.0 * flash) * (1 - 0.85 * locked)
        veil(fx.veil, c, s * 1.10, s * 1.10, 0.32)
        size(fx.band, s * (0.98 + 0.05 * c.breath))
        paint(fx.band, c.r, c.g, c.b, a * mix(0.30, 0.50, ready) * (0.8 + 0.2 * c.breath))
        size(fx.outer, s * (1.16 + 0.04 * c.breath)); fx.outer:SetRotation(-fx.turn)
        paint(fx.outer, c.r, c.g, c.b, a * (mix(0.60, 0.90, ready) + 0.2 * flash))
        size(fx.inner, s * (0.74 - 0.06 * ready)); fx.inner:SetRotation(1.3 - 1.8 * fx.turn)
        paint(fx.inner, c.hr, c.hg, c.hb, a * mix(0.45, 0.95, ready) * (1 - 0.5 * locked))
        -- partículas na corrente: mais rápidas perto do centro
        for i, pair in ipairs(fx.motes) do
            local r = s * (0.20 + 0.055 * i)
            local ang = i * 1.7 - fx.turn * (3.4 - 0.28 * i)
            for k = 1, 2 do
                local at = ang + (k - 1) * 0.16
                put(pair[k], c.frame, cos(at) * r, sin(at) * r)
                size(pair[k], s * (k == 1 and 0.10 or 0.07))
                paint(pair[k], c.wr, c.wg, c.wb, a * mix(0.45, 1, ready) * (k == 1 and 1 or 0.5) * live)
            end
        end
        core(fx.heart, c, 0.30, 0.30, 0.90, nil, nil, 0.10)
        fx.heart:SetRotation(-0.5 * fx.turn)
    end,
}

--------------------------------------------------------------------------------
-- Fenda: um buraco escuro com borda de luz que engole lampejos em espiral
--------------------------------------------------------------------------------

E.rift = {
    band = "halo", wave = "ring", waveGain = 0.8,
    icon = { { "swirl", 1.1, 1.1, 0, 0, 1 }, { "ring", 0.5, 0.5, 0, 0, 1, true }, { "flare", 0.3, 0.3, -0.3, 0.26, 0.9, true },
        { "flare", 0.22, 0.22, 0.3, -0.22, 0.8, true } },
    Build = function(fx, Layer)
        fx.veil = Layer("halo", "BACKGROUND", -1, "BLEND")
        fx.disc = Layer("swirl", "BACKGROUND")
        fx.inner = Layer("swirl", "ARTWORK")
        fx.hole = Layer("glow", "ARTWORK", 1, "BLEND")
        fx.rim = Layer("ring", "ARTWORK", 2)
        fx.shards = {}
        for i = 1, 10 do
            fx.shards[i] = { head = Layer("flare", "OVERLAY"), tail = Layer("glow", "OVERLAY"), t = i / 10, ang = i * 2.4 }
        end
        fx.glint = Layer("flare", "OVERLAY", 1)
        fx.turn = 0
    end,
    Update = function(fx, c)
        local a, ready, locked, flash = c.alpha, c.ready, c.locked, c.flash
        local live = 1 - locked
        local s = c.size * (1 + 0.40 * (1 - c.arrive))
        local speed = (mix(0.9, 1.9, ready) + 4.0 * flash) * (1 - 0.9 * locked)
        fx.turn = fx.turn + c.elapsed * speed
        fx.waveSize = s
        veil(fx.veil, c, s * 1.2, s * 1.2, 0.35)
        size(fx.disc, s * (1.28 + 0.05 * c.breath)); fx.disc:SetRotation(-fx.turn)
        paint(fx.disc, c.r, c.g, c.b, a * mix(0.55, 0.90, ready))
        size(fx.inner, s * 0.82); fx.inner:SetRotation(1.0 - 2.3 * fx.turn)
        paint(fx.inner, c.hr, c.hg, c.hb, a * mix(0.50, 0.95, ready) * (1 - 0.5 * locked))
        local hole = s * (0.66 - 0.14 * flash + 0.03 * c.breath)
        size(fx.hole, hole)
        paint(fx.hole, 0, 0, 0, a * 0.97)
        size(fx.rim, hole * 0.62 * (1 + 0.03 * c.twinkle))
        paint(fx.rim, c.wr, c.wg, c.wb, a * (mix(0.55, 1, ready) + 0.4 * flash) * (1 - 0.7 * locked))
        for _, sh in ipairs(fx.shards) do
            sh.t = sh.t + c.elapsed * speed * 0.38
            if sh.t >= 1 then sh.t, sh.ang = sh.t - 1, random() * TAU end
            local fall = sh.t * sh.t
            local r = s * (0.70 * (1 - fall) + 0.10)
            local ang = sh.ang - 5.0 * fall
            local shine = min(sh.t * 6, 1) * (1 - fall) ^ 0.4 * live
            put(sh.head, c.frame, cos(ang) * r, sin(ang) * r)
            size(sh.head, s * (0.26 - 0.14 * sh.t)); sh.head:SetRotation(ang)
            paint(sh.head, c.wr, c.wg, c.wb, a * shine)
            put(sh.tail, c.frame, cos(ang + 0.22) * r * 1.04, sin(ang + 0.22) * r * 1.04)
            size(sh.tail, s * (0.16 - 0.08 * sh.t))
            paint(sh.tail, c.hr, c.hg, c.hb, a * shine * 0.7)
        end
        size(fx.glint, s * (0.24 + 0.12 * c.twinkle + 0.40 * flash))
        put(fx.glint, c.frame, -hole * 0.21, hole * 0.21)
        fx.glint:SetRotation(0.4)
        paint(fx.glint, c.wr, c.wg, c.wb, a * (mix(0.30, 0.90, ready) * c.twinkle + 0.5 * flash) * live)
    end,
}

--------------------------------------------------------------------------------
-- Chama: línguas de fogo sobem do objeto
--------------------------------------------------------------------------------

-- cada língua: posição x (fração), altura, ritmo, defasagem
local TONGUES = { { -0.25, 0.60, 2.9, 0.0 }, { -0.12, 0.88, 3.7, 1.9 }, { 0.01, 1.12, 3.1, 4.1 }, { 0.14, 0.80, 4.3, 2.6 }, { 0.26, 0.54, 3.4, 5.3 } }

E.flame = {
    wave = "ring", flat = FLOOR, waveGain = 0.6,
    icon = { { "glow", 1, 0.5, 0, -0.32, 0.9 }, { "flame", 0.5, 0.82, -0.17, -0.02, 0.9 }, { "flame", 0.46, 0.7, 0.19, -0.08, 0.9 },
        { "flame", 0.56, 1, 0.02, 0.07, 1 }, { "flame", 0.3, 0.6, 0.02, -0.13, 1, true } },
    Build = function(fx, Layer)
        fx.veil = Layer("glow", "BACKGROUND", -1, "BLEND")
        fx.pool = Layer("glow", "BACKGROUND")
        fx.tongues = {}
        for i = 1, #TONGUES do fx.tongues[i] = { Layer("flame", "ARTWORK"), Layer("flame", "ARTWORK", 1) } end
        fx.embers = {}
        for i = 1, 8 do fx.embers[i] = Layer("glow", "OVERLAY") end
        fx.smoke = {}
        for i = 1, 3 do fx.smoke[i] = Layer("glow", "BACKGROUND", -1, "BLEND") end
        fx.heart = Layer("flare", "OVERLAY", 1)
    end,
    Update = function(fx, c)
        local s, a, ready, locked, flash = c.size, c.alpha, c.ready, c.locked, c.flash
        local live = 1 - locked
        local foot = FEET * s
        local fire = (0.80 + 0.30 * ready + 0.30 * flash) * (0.30 + 0.70 * c.arrive) * (1 - 0.50 * locked)
        local t = -c.spin
        fx.waveSize, fx.waveY = s * 0.95, foot

        size(fx.veil, s * 1.7, s * 1.9 * fire)
        put(fx.veil, c.frame, 0, foot + s * 0.55 * fire)
        paint(fx.veil, 0, 0, 0, a * 0.24)
        pool(fx.pool, c, 1.15, foot, 0.55, 0.95)

        for i, pair in ipairs(fx.tongues) do
            local sh = TONGUES[i]
            local beat = wave01(t * sh[3] + sh[4])
            local flick = wave01(t * sh[3] * 2.7 + sh[4] * 1.7)
            local h = s * sh[2] * fire * (0.74 + 0.20 * beat + 0.10 * flick)
            local wdt = s * 0.54 * (0.90 + 0.16 * (1 - beat))
            local x = sh[1] * s * 0.80 + sin(t * 1.3 + sh[4]) * s * 0.015
            local lean = -0.75 * sh[1] + 0.08 * sin(t * 1.9 + sh[4] * 2.3)
            -- a imagem gira pelo centro: a base é reposta no pé
            local outer, inner = pair[1], pair[2]
            size(outer, wdt, h)
            put(outer, c.frame, x - sin(lean) * h * 0.46, foot + cos(lean) * h * 0.46)
            outer:SetRotation(lean)
            paint(outer, c.r, c.g, c.b, a * mix(0.50, 0.80, ready) * (0.85 + 0.15 * flick))
            local middle = 1 - 3 * abs(sh[1])
            size(inner, wdt * 0.60, h * 0.66)
            put(inner, c.frame, x - sin(lean) * h * 0.30, foot + cos(lean) * h * 0.30)
            inner:SetRotation(lean)
            paint(inner, c.wr, c.wg, c.wb, a * middle * (mix(0.35, 0.70, ready) + 0.3 * flash) * (1 - 0.8 * locked))
        end

        local n = #fx.smoke
        for i, puff in ipairs(fx.smoke) do
            local up = (t * 0.16 + i / n) % 1
            size(puff, s * (0.55 + 0.60 * up))
            put(puff, c.frame, sin(t * 0.6 + i * 2.2) * s * 0.12, foot + s * (0.75 + 0.95 * up) * fire)
            paint(puff, 0, 0, 0, a * 0.26 * sin(pi * up))
        end
        local m = #fx.embers
        for i, em in ipairs(fx.embers) do
            local up = (t * 0.22 + i / m) % 1
            local glint = wave01(c.phase * 3.1 + i * 2.1)
            put(em, c.frame, (i - 4.5) * s * 0.09 + sin(t * 1.1 + i * 1.9) * s * 0.09, foot + (0.35 + up * 1.25) * s * fire)
            size(em, s * (0.10 + 0.04 * glint) * (1 - 0.5 * up))
            paint(em, c.hr, c.hg, c.hb, a * sin(pi * up) * mix(0.50, 1, ready) * live)
        end
        core(fx.heart, c, 0.26, 0.20, 0.70, 0, foot + s * 0.05)
    end,
}

--------------------------------------------------------------------------------
-- Facho: coluna de luz subindo do objeto, com dois fios em espiral
--------------------------------------------------------------------------------

E.beam = {
    wave = "ring", flat = FLOOR,
    icon = { { "glow", 1, 0.46, 0, -0.3, 0.9 }, { "beam", 0.62, 0.96, 0, 0.02, 1 }, { "beam", 0.3, 0.9, 0, 0.02, 1, true } },
    Build = function(fx, Layer)
        fx.veil = Layer("glow", "BACKGROUND", -1, "BLEND")
        fx.pool = Layer("glow", "BACKGROUND")
        fx.shaft = Layer("beam", "ARTWORK")
        fx.core = Layer("beam", "ARTWORK", 1)
        fx.sparks = {}
        for i = 1, 4 do fx.sparks[i] = Layer("glow", "OVERLAY") end
        fx.helix = {}
        for i = 1, 12 do fx.helix[i] = Layer("glow", "OVERLAY") end
        fx.fan = Layer("flare", "BACKGROUND", 1)
        fx.heart = Layer("flare", "OVERLAY", 1)
    end,
    Update = function(fx, c)
        local s, a, ready, locked, flash = c.size, c.alpha, c.ready, c.locked, c.flash
        local live = 1 - locked
        local foot = FEET * s
        local h = s * (1.75 + 0.45 * ready + 0.25 * flash) * (0.25 + 0.75 * c.arrive) * (1 - 0.40 * locked)
        local mid = foot + h / 2
        local t = -c.spin
        fx.waveSize, fx.waveY = s * 0.90, foot

        size(fx.veil, s * 1.5, h * 1.5)
        put(fx.veil, c.frame, 0, mid - h * 0.12)
        paint(fx.veil, 0, 0, 0, a * 0.22)
        pool(fx.pool, c, 1.10, foot, 0.55, 0.90)
        size(fx.shaft, s * (0.66 + 0.06 * c.breath + 0.22 * flash), h)
        put(fx.shaft, c.frame, 0, mid)
        paint(fx.shaft, c.r, c.g, c.b, a * mix(0.50, 0.85, ready))
        size(fx.core, s * (0.30 + 0.03 * c.breath + 0.14 * flash), h * 0.94)
        put(fx.core, c.frame, 0, foot + h * 0.47)
        paint(fx.core, c.wr, c.wg, c.wb, a * (mix(0.50, 0.95, ready) + 0.3 * flash) * (1 - 0.6 * locked))

        local n = #fx.sparks
        for i, sp in ipairs(fx.sparks) do
            local up = (t * 0.30 + i / n) % 1
            local glint = wave01(c.phase * 3.1 + i * 2.1)
            put(sp, c.frame, sin(t * 1.3 + i * 1.9) * s * 0.06, foot + up * h * 0.80)
            size(sp, s * (0.13 + 0.05 * glint) * (1 - 0.5 * up))
            paint(sp, c.hr, c.hg, c.hb, a * sin(pi * up) * mix(0.55, 1, ready) * live)
        end
        local m = #fx.helix
        for i, bead in ipairs(fx.helix) do
            local up = (t * 0.28 + floor((i + 1) / 2) / (m / 2)) % 1
            local ang = up * TAU * 2 + (i % 2) * pi + t * 1.2
            local depth = sin(ang)
            put(bead, c.frame, cos(ang) * s * 0.17 * (1 - 0.35 * up), foot + up * h * 0.82)
            size(bead, s * (0.11 + 0.035 * depth) * (1 - 0.4 * up))
            paint(bead, c.wr, c.wg, c.wb, a * sin(pi * up) * (0.55 + 0.45 * depth) * mix(0.55, 1, ready) * live)
        end
        size(fx.fan, s * (1.9 + 0.2 * c.breath), s * 0.55)
        put(fx.fan, c.frame, 0, foot)
        paint(fx.fan, c.hr, c.hg, c.hb, a * mix(0.25, 0.60, ready) * live)
        core(fx.heart, c, 0.30, 0.35, 0.90, 0, foot)
    end,
}

--------------------------------------------------------------------------------
-- Farol: um cristal flutuando acima do objeto, preso por um fio de luz
--------------------------------------------------------------------------------

E.beacon = {
    wave = "ring", flat = FLOOR,
    icon = { { "glow", 0.9, 0.4, 0, -0.33, 0.8 }, { "beam", 0.2, 0.44, 0, -0.15, 0.8 }, { "glow", 0.85, 0.85, 0, 0.15, 0.6 },
        { "gem", 0.52, 0.52, 0, 0.15, 1, true } },
    Build = function(fx, Layer)
        fx.veil = Layer("glow", "BACKGROUND", -1, "BLEND")
        fx.pool = Layer("glow", "BACKGROUND")
        fx.thread = Layer("beam", "BACKGROUND", 1)
        fx.halo = Layer("glow", "ARTWORK")
        fx.gem = Layer("gem", "ARTWORK", 1, "BLEND")
        fx.glint = Layer("flare", "OVERLAY")
    end,
    Update = function(fx, c)
        local s, a, ready, locked, flash = c.size, c.alpha, c.ready, c.locked, c.flash
        local foot = FEET * s
        local hover = s * (mix(0.78, 0.66, ready) + 0.55 * (1 - c.arrive) + 0.035 * sin(c.phase) * (1 - locked))
        local gem = s * (0.52 + 0.06 * flash)
        fx.waveSize, fx.waveY = s * 0.80, foot
        floorVeil(fx.veil, c, s * 1.7, foot)
        pool(fx.pool, c, 0.95, foot, 0.50, 0.85)
        local reach = max(hover - gem * 0.40 - foot, 0.01)
        size(fx.thread, s * 0.22, reach)
        put(fx.thread, c.frame, 0, foot + reach / 2)
        paint(fx.thread, c.hr, c.hg, c.hb, a * mix(0.40, 0.75, ready) * (1 - locked))
        size(fx.halo, gem * (2.0 + 0.3 * c.breath))
        put(fx.halo, c.frame, 0, hover)
        paint(fx.halo, c.r, c.g, c.b, a * mix(0.50, 0.90, ready))
        size(fx.gem, gem)
        put(fx.gem, c.frame, 0, hover)
        paint(fx.gem, mix(c.r, 1, 0.25), mix(c.g, 1, 0.25), mix(c.b, 1, 0.25), a * mix(0.85, 1, ready))
        size(fx.glint, gem * (0.55 + 0.25 * c.twinkle + 0.60 * flash))
        put(fx.glint, c.frame, -gem * 0.07, hover + gem * 0.17)
        paint(fx.glint, c.wr, c.wg, c.wb, a * (mix(0.30, 0.85, ready) * c.twinkle + 0.5 * flash) * (1 - locked))
    end,
}

--------------------------------------------------------------------------------
-- Órbita: três fogos-fátuos em órbitas inclinadas, como em volta de um núcleo
--------------------------------------------------------------------------------

local ORBITS = { { 0, 0.0, 1.00 }, { 1.05, 2.1, 0.86 }, { -1.05, 4.2, 1.14 } } -- inclinação, defasagem, velocidade

E.orbit = {
    wave = "ring", waveGain = 0.6,
    icon = { { "ring", 1, 0.46, 0, 0, 0.5 }, { "glow", 0.32, 0.32, -0.33, 0.03, 1, true }, { "glow", 0.3, 0.3, 0.3, -0.1, 1, true },
        { "glow", 0.2, 0.2, 0.12, 0.14, 0.7 }, { "flare", 0.3, 0.3, 0, 0, 0.6, true } },
    Build = function(fx, Layer)
        fx.veil = Layer("glow", "BACKGROUND", -1, "BLEND")
        fx.core = Layer("glow", "BACKGROUND")
        fx.paths, fx.tails = {}, {}
        for i = 1, #ORBITS do
            fx.paths[i] = Layer("ring", "BACKGROUND", 1)
            fx.tails[i] = makeTrail(Layer, 8)
        end
        fx.heart = Layer("flare", "ARTWORK")
    end,
    Update = function(fx, c)
        local s, a, ready, locked = c.size, c.alpha, c.ready, c.locked
        local r = s * mix(0.52, 0.44, ready) * (1 + 0.6 * (1 - c.arrive))
        local t = -2 * c.spin
        fx.waveSize = s
        veil(fx.veil, c, s * 1.9, s * 1.9, 0.28)
        size(fx.core, s * (0.80 + 0.10 * c.breath))
        paint(fx.core, c.r, c.g, c.b, a * mix(0.40, 0.65, ready))
        for i, list in ipairs(fx.tails) do
            local o = ORBITS[i]
            local tilt = o[1] + 0.12 * sin(c.phase * 0.5 + i)
            local ct, st = cos(tilt), sin(tilt)
            local path = fx.paths[i]
            size(path, r / ORBIT, r / ORBIT * FLOOR); path:SetRotation(tilt)
            paint(path, c.hr, c.hg, c.hb, a * mix(0.14, 0.30, ready))
            local head = t * o[3] + o[2]
            local front = 0.66 + 0.34 * -sin(head) -- na frente: maior e mais claro
            trail(list, 8, c, function(k)
                local ang = head - k * 0.08
                local x, y = cos(ang) * r, sin(ang) * r * FLOOR
                return x * ct - y * st, x * st + y * ct, 1 + 0.28 * -sin(ang)
            end, 0.20, 0.17, 0.90, a * front * mix(0.70, 1, ready), a * front * mix(0.50, 0.85, ready) * (1 - locked))
        end
        size(fx.heart, s * (0.30 + 0.10 * ready + 0.05 * c.twinkle + 0.30 * c.flash))
        fx.heart:SetRotation(0.2 * t)
        paint(fx.heart, c.wr, c.wg, c.wb, a * (mix(0.30, 0.85, ready) * (0.7 + 0.3 * c.twinkle) + 0.4 * c.flash) * (1 - locked))
    end,
}

--------------------------------------------------------------------------------
-- Ondas: ondulações abrindo no chão em volta do objeto
--------------------------------------------------------------------------------

E.ripple = {
    wave = "ring", flat = FLOOR, ping = false,
    icon = { { "glow", 1, 0.5, 0, 0, 0.5 }, { "ring", 1, 0.44, 0, 0, 0.7 }, { "ring", 0.62, 0.27, 0, 0, 0.9 },
        { "ring", 0.28, 0.12, 0, 0, 1, true } },
    Build = function(fx, Layer)
        fx.veil = Layer("glow", "BACKGROUND", -1, "BLEND")
        fx.pool = Layer("glow", "BACKGROUND")
        fx.rings = { Layer("ring", "ARTWORK"), Layer("ring", "ARTWORK"), Layer("ring", "ARTWORK") }
        fx.heart = Layer("flare", "OVERLAY")
    end,
    Update = function(fx, c)
        local s, a, ready = c.size, c.alpha, c.ready
        local foot = FEET * s
        local t = -c.spin
        fx.waveSize, fx.waveY = s * 1.10, foot
        floorVeil(fx.veil, c, s * 2.6, foot)
        local w0 = s * (1.20 + 0.12 * c.breath)
        size(fx.pool, w0, w0 * FLOOR * 1.3); put(fx.pool, c.frame, 0, foot)
        paint(fx.pool, c.r, c.g, c.b, a * mix(0.55, 0.90, ready))
        local n = #fx.rings
        for i, ring in ipairs(fx.rings) do
            local p = (t * 0.40 + i / n) % 1
            local w = s * mix(0.30, 1.70, 1 - (1 - p) ^ 2) * (0.6 + 0.4 * c.arrive)
            size(ring, w, w * FLOOR); put(ring, c.frame, 0, foot)
            paint(ring, c.hr, c.hg, c.hb, a * mix(0.60, 1, ready) * min(p * 6, 1) * (1 - p) ^ 1.3)
        end
        core(fx.heart, c, 0.26, 0.25, 0.80, 0, foot)
    end,
}

--------------------------------------------------------------------------------
-- Cintilar: lampejos que nascem e apagam em pontos aleatórios do disco
--------------------------------------------------------------------------------

E.sparkle = {
    icon = { { "glow", 1, 1, 0, 0, 0.45 }, { "flare", 0.64, 0.64, -0.12, 0.1, 1, true }, { "flare", 0.42, 0.42, 0.22, -0.2, 0.9, true },
        { "flare", 0.3, 0.3, 0.2, 0.26, 0.8, true } },
    Build = function(fx, Layer)
        fx.veil = Layer("glow", "BACKGROUND", -1, "BLEND")
        fx.haze = Layer("glow", "BACKGROUND")
        fx.dust = { Layer("glow", "ARTWORK"), Layer("glow", "ARTWORK"), Layer("glow", "ARTWORK") }
        fx.stars = {}
        for i = 1, 6 do fx.stars[i] = { t = Layer("flare", "OVERLAY"), age = 0, life = 0 } end
        fx.lastFlash = 0
    end,
    Update = function(fx, c)
        local s, a, ready, locked = c.size, c.alpha, c.ready, c.locked
        local live = 1 - locked
        veil(fx.veil, c, s * 1.9, s * 1.9, 0.28)
        size(fx.haze, s * (1.55 + 0.12 * c.breath))
        paint(fx.haze, c.r, c.g, c.b, a * mix(0.40, 0.62, ready) * (0.85 + 0.15 * c.breath))
        local t = -c.spin
        local n = #fx.dust
        for i, d in ipairs(fx.dust) do
            local up = (t * 0.14 + i / n) % 1
            put(d, c.frame, (i - 2) * s * 0.24 + sin(t * 0.9 + i * 2.3) * s * 0.05, (up - 0.45) * s * 0.8)
            size(d, s * 0.11)
            paint(d, c.hr, c.hg, c.hb, a * sin(pi * up) * 0.75 * live)
        end
        -- ao travar, todos os lampejos recomeçam juntos
        local burst = c.flash > fx.lastFlash
        fx.lastFlash = c.flash
        for _, star in ipairs(fx.stars) do
            star.age = star.age + c.elapsed * mix(1, 1.5, ready)
            if burst or star.age >= star.life then
                local ang, d = random() * TAU, sqrt(random())
                star.x, star.y = cos(ang) * d, sin(ang) * d
                star.life = 0.7 + 0.9 * random()
                star.scale = 0.55 + 0.75 * random()
                star.age = burst and 0 or -0.5 * random() -- um tempo apagado antes de reaparecer
            end
            local glow = star.age > 0 and sin(pi * star.age / star.life) or 0
            put(star.t, c.frame, star.x * s * 0.40, star.y * s * 0.40)
            size(star.t, s * 0.55 * star.scale * (0.4 + 0.6 * glow) * (1 + 0.25 * ready))
            paint(star.t, c.wr, c.wg, c.wb, a * glow * mix(0.70, 1, ready) * live)
        end
    end,
}

--------------------------------------------------------------------------------
-- Tempestade: nuvem escura acima do objeto soltando raios nele
--------------------------------------------------------------------------------

-- massas da nuvem: x, y (fração do tamanho, em volta do meio), largura, altura
local CLOUD = { { -0.36, -0.02, 0.62, 0.36 }, { -0.12, 0.07, 0.74, 0.46 }, { 0.14, 0.04, 0.70, 0.42 }, { 0.38, -0.03, 0.58, 0.34 },
    { 0.00, -0.08, 0.86, 0.34 } }

E.storm = {
    wave = "ring", flat = FLOOR, waveGain = 0.8,
    icon = { { "glow", 1, 0.5, 0, -0.34, 0.8 }, { "bolt", 0.44, 0.8, -0.06, -0.08, 1, true }, { "glow", 0.8, 0.5, -0.14, 0.3, 0.5 },
        { "glow", 0.8, 0.5, 0.16, 0.32, 0.45 } },
    Build = function(fx, Layer)
        fx.veil = Layer("glow", "BACKGROUND", -1, "BLEND")
        fx.pool = Layer("glow", "BACKGROUND")
        fx.core = Layer("glow", "ARTWORK")
        fx.bolts = {}
        for i = 1, 3 do
            fx.bolts[i] = { glow = Layer("bolt", "ARTWORK", 1), line = Layer("bolt", "ARTWORK", 2),
                age = 0, life = 0, rest = 0.6 + i * 0.9, top = 0, bottom = 0 }
        end
        fx.cloud = {}
        for i = 1, #CLOUD do fx.cloud[i] = { dark = Layer("glow", "OVERLAY", 0, "BLEND"), lit = Layer("glow", "OVERLAY", 1) } end
        fx.heart = Layer("flare", "OVERLAY", 2)
    end,
    Update = function(fx, c)
        local s, a, ready, locked, flash = c.size, c.alpha, c.ready, c.locked, c.flash
        local foot = FEET * s
        local t = -c.spin
        local sky = foot + s * (1.25 + 0.5 * (1 - c.arrive) + 0.02 * sin(c.phase))
        fx.waveSize, fx.waveY = s, foot

        local strike = 0 -- o raio mais forte do momento ilumina a nuvem e o chão
        for _, b in ipairs(fx.bolts) do
            b.age = b.age + c.elapsed
            if b.age >= b.life + b.rest or (flash > 0.92 and b.age > 0.05) then
                b.age = 0
                b.life = 0.16 + 0.14 * random()
                b.rest = mix(3.2, 1.6, ready) + random() * mix(4.0, 2.2, ready)
                b.top = (random() - 0.5) * s * 0.60
                b.bottom = (random() - 0.5) * s * 0.30
            end
            local lit = 0
            if b.age < b.life then lit = (1 - b.age / b.life) ^ 0.5 * (0.80 + 0.20 * random()) * c.arrive * (1 - locked) end
            strike = max(strike, lit)
            local dx, dy = b.top - b.bottom, sky - foot
            local len = sqrt(dx * dx + dy * dy)
            local lean = atan2(dy, dx) - pi / 2
            local mx, my = (b.top + b.bottom) / 2, (sky + foot) / 2
            size(b.glow, len * 0.62, len); put(b.glow, c.frame, mx, my); b.glow:SetRotation(lean)
            paint(b.glow, c.r, c.g, c.b, a * lit)
            size(b.line, len * 0.50, len); put(b.line, c.frame, mx, my); b.line:SetRotation(lean)
            paint(b.line, c.wr, c.wg, c.wb, a * lit)
        end

        for i, puff in ipairs(fx.cloud) do
            local sh = CLOUD[i]
            local drift = sin(t * 0.35 + i * 1.9)
            local x = (sh[1] + 0.04 * drift) * s
            local y = sky + (sh[2] + 0.015 * sin(t * 0.5 + i)) * s
            local w, h = sh[3] * s * (1.9 + 0.1 * drift), sh[4] * s * 1.9
            size(puff.dark, w, h); put(puff.dark, c.frame, x, y)
            paint(puff.dark, 0.05, 0.05, 0.07, a * 0.85 * (1 - 0.4 * locked))
            size(puff.lit, w * 0.80, h * 0.75); put(puff.lit, c.frame, x, y - h * 0.05)
            paint(puff.lit, c.r, c.g, c.b, a * (mix(0.16, 0.30, ready) * (0.8 + 0.2 * drift) + 0.75 * strike) * (1 - 0.7 * locked))
        end

        floorVeil(fx.veil, c, s * 2.4, foot)
        local w0 = s * (1.10 + 0.10 * c.breath + 0.35 * strike)
        size(fx.pool, w0, w0 * FLOOR * 1.3); put(fx.pool, c.frame, 0, foot)
        paint(fx.pool, c.r, c.g, c.b, a * (mix(0.40, 0.65, ready) + 0.5 * strike))
        size(fx.core, s * (0.50 + 0.45 * strike)); put(fx.core, c.frame, 0, foot + s * 0.10)
        paint(fx.core, c.hr, c.hg, c.hb, a * (mix(0.15, 0.30, ready) + 0.6 * strike) * (1 - 0.6 * locked))
        size(fx.heart, s * (0.20 + 0.55 * strike + 0.30 * flash)); put(fx.heart, c.frame, 0, foot + s * 0.04)
        paint(fx.heart, c.wr, c.wg, c.wb, a * (0.20 * ready + strike + 0.4 * flash) * (1 - locked))
    end,
}

--------------------------------------------------------------------------------
-- Gêiser: um jato curto e gotas de luz que sobem e caem em volta
--------------------------------------------------------------------------------

E.geyser = {
    wave = "ring", flat = FLOOR, waveGain = 0.7,
    icon = { { "glow", 1, 0.5, 0, -0.32, 0.9 }, { "beam", 0.5, 0.7, 0, -0.1, 1 }, { "glow", 0.2, 0.2, -0.26, 0.2, 1, true },
        { "glow", 0.18, 0.18, 0.28, 0.12, 1, true }, { "flare", 0.34, 0.34, 0.06, 0.3, 1, true }, { "glow", 0.14, 0.14, -0.36, -0.08, 0.8, true } },
    Build = function(fx, Layer)
        fx.veil = Layer("glow", "BACKGROUND", -1, "BLEND")
        fx.pool = Layer("glow", "BACKGROUND")
        fx.jet = Layer("beam", "ARTWORK")
        fx.core = Layer("beam", "ARTWORK", 1)
        fx.drops = {}
        for i = 1, 18 do
            local big = i % 3 == 0
            fx.drops[i] = { t = Layer(big and "flare" or "glow", "OVERLAY"), big = big, p = i / 18,
                vx = (random() - 0.5) * 2.4, vy = 1.7 + 0.9 * random() }
        end
        fx.heart = Layer("flare", "OVERLAY", 1)
        fx.lastFlash = 0
    end,
    Update = function(fx, c)
        local s, a, ready, locked, flash = c.size, c.alpha, c.ready, c.locked, c.flash
        local foot = FEET * s
        local push = (0.80 + 0.30 * ready + 0.40 * flash) * (0.4 + 0.6 * c.arrive)
        fx.waveSize, fx.waveY = s, foot
        floorVeil(fx.veil, c, s * 2.4, foot)
        pool(fx.pool, c, 1.20, foot, 0.55, 0.90)
        local h = s * (0.85 + 0.12 * c.twinkle) * push * (1 - 0.6 * locked)
        size(fx.jet, s * 0.75, h); put(fx.jet, c.frame, 0, foot + h / 2)
        paint(fx.jet, c.r, c.g, c.b, a * mix(0.55, 0.90, ready))
        size(fx.core, s * 0.34, h * 0.9); put(fx.core, c.frame, 0, foot + h * 0.45)
        paint(fx.core, c.wr, c.wg, c.wb, a * mix(0.50, 0.95, ready) * (1 - 0.6 * locked))
        local burst = flash > fx.lastFlash
        fx.lastFlash = flash
        local n = #fx.drops
        for i, d in ipairs(fx.drops) do
            d.p = d.p + c.elapsed / 1.5 * mix(0.8, 1.25, ready) * (1 - 0.8 * locked)
            if burst then d.p = 1 + i / n * 0.12 end
            if d.p >= 1 then
                d.p = d.p - 1
                d.vx, d.vy = (random() - 0.5) * 2.4, 1.7 + 1.0 * random()
            end
            local p = d.p
            local rise = (d.vy * p - 2.7 * p * p) * push
            put(d.t, c.frame, d.vx * p * s * 0.95, foot + max(rise, 0) * s * 0.95)
            size(d.t, s * (d.big and 0.34 or 0.15) * (1 - 0.5 * p))
            paint(d.t, c.wr, c.wg, c.wb, a * (rise < 0 and 0 or min(p * 10, 1) * (1 - p) ^ 0.6) * (1 - locked))
        end
        core(fx.heart, c, 0.30, 0.35, 0.90, 0, foot + s * 0.03)
    end,
}

--------------------------------------------------------------------------------
-- Espírito: dois fogos-fátuos dançam um "oito" em volta do objeto, com fita de luz
--------------------------------------------------------------------------------

local SPIRITS = { { 0, 0.0, 1.00 }, { pi, 1.3, 0.72 } } -- defasagem, forma, escala
local RIBBON = 24

E.spirit = {
    band = "halo", wave = "ring", waveGain = 0.5,
    icon = { { "glow", 0.9, 0.9, 0, 0, 0.35 }, { "arcs", 0.95, 0.95, 0, 0, 1 }, { "flare", 0.42, 0.42, -0.41, 0.03, 1, true },
        { "flare", 0.36, 0.36, 0.41, -0.03, 1, true } },
    Build = function(fx, Layer)
        fx.veil = Layer("glow", "BACKGROUND", -1, "BLEND")
        fx.haze = Layer("glow", "BACKGROUND")
        fx.spirits = {}
        for i = 1, #SPIRITS do
            local sp = { ribbon = {} }
            for k = RIBBON, 1, -1 do sp.ribbon[k] = Layer("glow", "ARTWORK") end
            sp.body = Layer("glow", "OVERLAY")
            sp.star = Layer("flare", "OVERLAY", 1)
            fx.spirits[i] = sp
        end
    end,
    Update = function(fx, c)
        local s, a, ready, locked = c.size, c.alpha, c.ready, c.locked
        local t = -c.spin * 1.5
        local reach = s * mix(0.66, 0.50, ready) * (1 + 0.6 * (1 - c.arrive)) * (1 - 0.35 * locked)
        fx.waveSize = s
        veil(fx.veil, c, s * 2.0, s * 2.0, 0.26)
        size(fx.haze, s * (1.30 + 0.10 * c.breath))
        paint(fx.haze, c.r, c.g, c.b, a * mix(0.30, 0.50, ready))
        for i, sp in ipairs(fx.spirits) do
            local sh = SPIRITS[i]
            local function at(m)
                local turn = m + sh[1]
                return sin(turn) * reach * sh[3],
                    (sin(2 * turn + sh[2]) * 0.42 + 0.10 * sin(m * 0.7 + i)) * reach * sh[3],
                    cos(turn)
            end
            local x, y, depth = at(t)
            local near = 1 + 0.25 * depth
            for k, tex in ipairs(sp.ribbon) do
                local rx, ry, rd = at(t - k * 0.04)
                put(tex, c.frame, rx, ry)
                size(tex, s * 0.24 * sh[3] * (1 + 0.25 * rd) * 0.95 ^ k)
                paint(tex, c.hr, c.hg, c.hb, a * mix(0.50, 0.85, ready) * 0.90 ^ k * (1 - 0.5 * locked))
            end
            put(sp.body, c.frame, x, y)
            size(sp.body, s * 0.34 * sh[3] * near)
            paint(sp.body, c.wr, c.wg, c.wb, a * mix(0.75, 1, ready))
            put(sp.star, c.frame, x, y)
            size(sp.star, s * (0.46 + 0.14 * c.twinkle + 0.4 * c.flash) * sh[3] * near)
            sp.star:SetRotation(t * 0.6 + i)
            paint(sp.star, c.wr, c.wg, c.wb, a * (mix(0.55, 1, ready) + 0.4 * c.flash) * (1 - 0.7 * locked))
        end
    end,
}
