// Skin "bdo": HUD do jogador no estilo Black Desert Online (referência:
// print do usuário, 728x154 em 1080p, e o vídeo 1080p do BDO).
//   * losango cinza translúcido (borda escura + filete claro) com nível e % de XP;
//   * XP = filete dourado POR FORA da borda do losango, saindo do vértice de cima
//     em sentido horário (4 quadrantes de XPRing.tga recortados no jogo);
//   * vida: paralelogramo "\" vermelho; recurso: paralelogramo "/" (ouro na raiva,
//     azul na mana, prata na energia) -> juntos formam a seta do BDO;
//   * preenchimento em "tubo": borda interna clara, miolo escuro, manchas e pontinhos.
// Medidas em px da referência (1080p) x K = unidades da UI. Também grava
// AzaathUI/Modules/BDOLayoutData.lua e preview/compare.png (referência x HUD).
// Uso: node tools/bdo-hud-concept/gen.js
"use strict";
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const ROOT = path.join(__dirname, "..", "..", "AzaathUI");
const OUT = path.join(ROOT, "Media", "BDO");
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(OUT, { recursive: true });
fs.mkdirSync(PREV, { recursive: true });

const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const mix = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];
const smooth = (e0, e1, v) => { const t = clamp((v - e0) / (e1 - e0)); return t * t * (3 - 2 * t); };

// ---------------------------------------------------------------------------
// Geometria (unidades da UI). K = 1.4: 1 px da referência em 1080p ~ 1.4 un.
// ---------------------------------------------------------------------------
const K = 1.4;
const D = 41.5 * K;            // meia-diagonal do losango (borda externa)
const M = 10;                  // margem da caixa do losango (filete de XP + sombra)
const C = D + M;               // centro do losango (x = y)
const BOX = 2 * C;             // lado da caixa do losango
const GAP = 11;               // faixa vazia entre o losango e as barras (horizontal)
const SL = 1;                  // inclinação 45°

const hpTop = C - 25.5 * K, hpBot = hpTop + 21 * K;
const rsTop = hpBot + 4 * K, rsBot = rsTop + 14 * K;
const hpLeft = (y) => C + D - (C - y) + GAP;     // acompanha a aresta superior direita
const rsLeft = (y) => C + D - (y - C) + GAP;     // acompanha a aresta inferior direita
const HP_RIGHT_BOT = C + 284.5 * K;              // ponta da seta (vida embaixo / recurso em cima)
const RS_RIGHT_TOP = HP_RIGHT_BOT - 2 * K;

const HP = [
  [hpLeft(hpTop), hpTop], [HP_RIGHT_BOT - (hpBot - hpTop) * SL, hpTop],
  [HP_RIGHT_BOT, hpBot], [hpLeft(hpBot), hpBot],
];
const RS = [
  [rsLeft(rsTop), rsTop], [RS_RIGHT_TOP, rsTop],
  [RS_RIGHT_TOP - (rsBot - rsTop) * SL, rsBot], [rsLeft(rsBot), rsBot],
];
const bbox = (P) => {
  const xs = P.map((p) => p[0]), ys = P.map((p) => p[1]);
  const x = Math.floor(Math.min(...xs)) - 1, y = Math.floor(Math.min(...ys)) - 1;
  return { x, y, w: Math.ceil(Math.max(...xs)) + 1 - x, h: Math.ceil(Math.max(...ys)) + 1 - y };
};
const HPB = bbox(HP), RSB = bbox(RS);
const HUD = { w: Math.ceil(Math.max(HPB.x + HPB.w, RSB.x + RSB.w)) + 2, h: Math.ceil(BOX) };

// distância assinada a um polígono convexo (horário na tela), + dentro
function polyDist(P, x, y) {
  let d = Infinity;
  for (let i = 0; i < P.length; i++) {
    const [ax, ay] = P[i], [bx, by] = P[(i + 1) % P.length];
    const ex = bx - ax, ey = by - ay, L = Math.hypot(ex, ey);
    // normal para dentro (polígono horário com y para baixo)
    const nx = -ey / L, ny = ex / L;
    d = Math.min(d, (x - ax) * nx + (y - ay) * ny);
  }
  return d;
}

// ---------------------------------------------------------------------------
// Ruído (valor, periódico em x quando pedido)
// ---------------------------------------------------------------------------
function hash(ix, iy, seed) {
  let h = (ix * 374761393 + iy * 668265263 + seed * 2147483647) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
}
function vnoise(x, y, seed) {
  const ix = Math.floor(x), iy = Math.floor(y), fx = x - ix, fy = y - iy;
  const sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
  const a = hash(ix, iy, seed), b = hash(ix + 1, iy, seed), c = hash(ix, iy + 1, seed), d = hash(ix + 1, iy + 1, seed);
  return lerp(lerp(a, b, sx), lerp(c, d, sx), sy);
}
// ruído periódico (px, py células) -> textura que repete sem emenda
function pnoise(x, y, seed, px, py) {
  const ix = Math.floor(x), iy = Math.floor(y), fx = x - ix, fy = y - iy;
  const sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
  const m = (a, p) => ((a % p) + p) % p;
  const h = (a, b) => hash(m(a, px), m(b, py), seed);
  return lerp(lerp(h(ix, iy), h(ix + 1, iy), sx), lerp(h(ix, iy + 1), h(ix + 1, iy + 1), sx), sy);
}
function pfbm(x, y, seed, px, py, oct = 4) {
  let s = 0, a = 0.5, f = 1, n = 0;
  for (let o = 0; o < oct; o++) { s += a * pnoise(x * f, y * f, seed + o * 17, px * f, py * f); n += a; a *= 0.5; f *= 2; }
  return s / n;
}
function fbm(x, y, seed, oct = 4) {
  let s = 0, a = 0.5, f = 1, n = 0;
  for (let o = 0; o < oct; o++) { s += a * vnoise(x * f, y * f, seed + o * 17); n += a; a *= 0.5; f *= 2; }
  return s / n;
}

// pontinhos fixos (brilhos miúdos já pintados no preenchimento)
function speckles(B, count, seed) {
  const out = [];
  for (let i = 0; i < count; i++) {
    out.push({ x: B.x + hash(i, 1, seed) * B.w, y: B.y + hash(i, 2, seed) * B.h, r: 0.35 + hash(i, 3, seed) * 0.55, a: 0.35 + hash(i, 4, seed) * 0.65 });
  }
  return out;
}

// ---------------------------------------------------------------------------
// Paletas dos preenchimentos (miolo / borda interna clara / brilho das manchas)
// ---------------------------------------------------------------------------
const PAL = {
  hp:     { core: [120, 24, 16], rim: [212, 62, 44],  hot: [192, 50, 34], spk: [255, 170, 120], wisp: 0.45, mot: 0.55 },
  // mob neutro: amarelo vivo (líquido próprio, sem tingir o vermelho)
  neutral: { core: [226, 178, 26], rim: [255, 236, 120], hot: [255, 238, 150], spk: [255, 252, 220], wisp: 0.45, mot: 0.3 },
  gold:   { core: [168, 124, 10], rim: [228, 182, 42], hot: [226, 186, 72], spk: [255, 250, 215], wisp: 0.55, mot: 0.32 },
  blue:   { core: [20, 58, 164], rim: [98, 166, 255], hot: [150, 205, 255], spk: [225, 240, 255], wisp: 0.45, mot: 0.40 },
  silver: { core: [158, 152, 142], rim: [246, 242, 228], hot: [255, 252, 238], spk: [255, 255, 255], wisp: 0.45, mot: 0.30 },
};

// rasteriza um preenchimento/fundo de barra numa textura que cobre a bbox
function renderBar(P, B, TW, TH, kind, pal, seed) {
  const img = I.create(TW, TH);
  const SS = 3;
  const spk = pal ? speckles(B, Math.round(B.w * 0.03), seed + 5) : [];
  for (let j = 0; j < TH; j++) for (let i = 0; i < TW; i++) {
    let acc = [0, 0, 0], aAcc = 0;
    for (let sj = 0; sj < SS; sj++) for (let si = 0; si < SS; si++) {
      const X = B.x + ((i + (si + 0.5) / SS) / TW) * B.w;
      const Y = B.y + ((j + (sj + 0.5) / SS) / TH) * B.h;
      const d = polyDist(P, X, Y);
      if (kind === "bg") {
        if (d < 0) continue;
        // contorno escuro fino + filete claro + interior escuro translúcido
        let c, a;
        if (d < 0.8) { c = [30, 22, 24]; a = 0.6; }
        else if (d < 1.7) { c = [104, 98, 96]; a = 0.5; }
        else { c = mix([30, 24, 26], [14, 11, 13], smooth(2, 9, d)); a = 0.62; }
        acc = acc.map((v, k) => v + c[k] * a); aAcc += a;
      } else {
        const di = d - 1.0; // preenchimento recuado 1 un. (o contorno do fundo aparece)
        if (di < 0) continue;
        if (kind === "mask") { acc = acc.map((v) => v + 255); aAcc += 1; continue; }
        // líquido num tubo de vidro: reflexo fino no topo, faixa escura no meio,
        // brilho difuso embaixo, manchas macias com redemoinho (sem granulado)
        const v = clamp((Y - P[0][1]) / (P[3][1] - P[0][1]));
        const spec = Math.exp(-Math.pow((v - 0.11) / 0.075, 2));
        const low = Math.exp(-Math.pow((v - 0.84) / 0.13, 2));
        const dark = Math.exp(-Math.pow((v - 0.52) / 0.2, 2));
        const wx = X + 22 * (fbm(X / 48, Y / 14, seed + 51, 3) - 0.5);
        const wy = Y + 6 * (fbm(X / 40, Y / 12, seed + 77, 3) - 0.5);
        const n = fbm(wx / 52, wy / 13, seed, 4);
        let c = pal.core.map((x) => x * (1 - pal.mot * 0.45 + pal.mot * 0.9 * n));
        c = c.map((x) => x * (1 - 0.16 * dark));
        const w = smooth(0.5, 0.78, fbm(wx / 34, wy / 7.5, seed + 7, 3));
        c = mix(c, pal.hot, clamp(w * pal.wisp * 0.55 + low * 0.22 * (0.6 + 0.6 * n)));
        c = mix(c, pal.rim, clamp(spec * 0.8 + Math.exp(-di / 1.4) * 0.55));
        // poucas gotinhas de luz, macias
        for (const s of spk) {
          const r = Math.hypot(X - s.x, Y - s.y);
          if (r < s.r * 3) c = mix(c, pal.spk, clamp((1 - r / (s.r * 3)) * s.a * 0.6));
        }
        acc = acc.map((x, k) => x + c[k]); aAcc += 1;
      }
    }
    const o = (j * TW + i) * 4, n = SS * SS;
    if (aAcc > 0) {
      img.px[o] = acc[0] / aAcc; img.px[o + 1] = acc[1] / aAcc; img.px[o + 2] = acc[2] / aAcc;
    }
    img.px[o + 3] = (kind === "bg" ? aAcc / n : aAcc / n) * 255;
  }
  return img;
}

// ---------------------------------------------------------------------------
// Losango e filete de XP (caixa BOX x BOX, centro C)
// ---------------------------------------------------------------------------
// distância euclidiana até a borda externa do losango (+ dentro)
const diaDist = (X, Y) => (D - (Math.abs(X - C) + Math.abs(Y - C))) / Math.SQRT2;
const RING_OFF = 0.8, RING_HALF = 1.5; // filete colado por fora da borda, ~3 un. de espessura

function renderDiamond(T) {
  const img = I.create(T, T);
  const SS = 3;
  for (let j = 0; j < T; j++) for (let i = 0; i < T; i++) {
    let acc = [0, 0, 0], aAcc = 0;
    for (let sj = 0; sj < SS; sj++) for (let si = 0; si < SS; si++) {
      const X = ((i + (si + 0.5) / SS) / T) * BOX, Y = ((j + (sj + 0.5) / SS) / T) * BOX;
      const d = diaDist(X, Y);
      let c, a;
      if (d < 0) {
        // trilho claro da XP (o filete dourado corre por cima) + sombra externa
        const t = Math.abs(-d - (RING_OFF + RING_HALF));
        const ta = 0.17 * clamp((RING_HALF + 0.2 - t) / 0.9);
        const sa = 0.30 * Math.exp(d / 2.4);
        a = Math.max(ta, sa);
        c = ta >= sa ? [196, 196, 204] : [0, 0, 0];
      } else if (d < 3.6) {
        c = mix([22, 21, 27], [40, 37, 42], smooth(0, 3.6, d));           // borda escura grossa
        a = 0.97;
      } else {
        // miolo: cinza frio em cima -> oliva/âmbar embaixo, granulado fino
        const v = clamp((Y - (C - D)) / (2 * D));
        // tom neutro escuro: o azul em cima/âmbar embaixo do BDO vem do cenário que transparece
        let base = mix([52, 50, 52], [62, 54, 44], smooth(0.15, 0.95, v));
        const r = Math.hypot(X - C, Y - C) / D;
        base = base.map((x) => x * (1.06 - 0.12 * smooth(0.1, 0.9, r)));
        base = base.map((x) => x * (0.93 + 0.1 * fbm(X / 14, Y / 14, 7, 3) + 0.05 * (vnoise(X * 1.3, Y * 0.35, 3) - 0.5)));
        // chanfro quente logo depois da borda escura
        const rim = smooth(8.5, 4.0, d);
        c = mix(base, [92, 80, 70], rim * 0.85);
        a = lerp(0.7, 0.88, rim);
      }
      acc = acc.map((v, k) => v + c[k] * a); aAcc += a;
    }
    const o = (j * T + i) * 4, n = SS * SS;
    if (aAcc > 0) { img.px[o] = acc[0] / aAcc; img.px[o + 1] = acc[1] / aAcc; img.px[o + 2] = acc[2] / aAcc; }
    img.px[o + 3] = (aAcc / n) * 255;
  }
  return img;
}

function renderRing(T) {
  const img = I.create(T, T);
  const SS = 3;
  for (let j = 0; j < T; j++) for (let i = 0; i < T; i++) {
    let acc = [0, 0, 0], aAcc = 0;
    for (let sj = 0; sj < SS; sj++) for (let si = 0; si < SS; si++) {
      const X = ((i + (si + 0.5) / SS) / T) * BOX, Y = ((j + (sj + 0.5) / SS) / T) * BOX;
      const t = Math.abs(-diaDist(X, Y) - (RING_OFF + RING_HALF));     // distância ao eixo do filete
      const core = clamp((RING_HALF + 0.5 - t) / 1.0);
      const halo = 0.28 * Math.exp(-Math.max(0, t - RING_HALF) / 1.4);
      // a XP nasce no vértice de cima: corte reto ali (sem a ponta da quina para cima)
      let cap = 1;
      if (X >= C && Y < C) {
        const R = D + RING_OFF + RING_HALF;
        cap = clamp(((X - C) + (Y - (C - R))) / Math.SQRT2 / 0.8 + 0.5);
      }
      const a = Math.max(core, halo) * cap;
      if (a <= 0.002) continue;
      const c = core > 0 ? mix([196, 160, 78], [250, 222, 140], clamp(1 - t / RING_HALF)) : [230, 190, 90];
      acc = acc.map((v, k) => v + c[k] * a); aAcc += a;
    }
    const o = (j * T + i) * 4, n = SS * SS;
    if (aAcc > 0) { img.px[o] = acc[0] / aAcc; img.px[o + 1] = acc[1] / aAcc; img.px[o + 2] = acc[2] / aAcc; }
    img.px[o + 3] = (aAcc / n) * 255;
  }
  return img;
}

// correnteza do líquido: veios cáusticos macios, repete nos 2 eixos (o jogo
// rola 2 camadas em sentidos opostos, mascaradas pelo formato da barra)
function renderFlow(TW, TH) {
  const img = I.create(TW, TH);
  const PX = 6, PY = 2;
  for (let j = 0; j < TH; j++) for (let i = 0; i < TW; i++) {
    const u = i / TW, v = j / TH;
    const wu = u * PX + 1.1 * (pfbm(u * 4, v * 2, 3, 4, 2, 3) - 0.5) * 2;
    const wv = v * PY + 0.5 * (pfbm(u * 4, v * 2, 5, 4, 2, 3) - 0.5) * 2;
    const r = 1 - Math.abs(2 * pfbm(wu, wv, 9, PX, PY, 3) - 1);
    const soft = pfbm(u * 3, v * 1, 13, 3, 1, 2);
    const k = clamp(Math.pow(r, 5) * 1.1 + 0.25 * smooth(0.45, 0.8, soft));
    const o = (j * TW + i) * 4;
    img.px[o] = img.px[o + 1] = img.px[o + 2] = 255 * k; img.px[o + 3] = 255;
  }
  return img;
}
const FLOW = [ // largura da repetição (un.), velocidade (repetições/s), altura (fração), alpha
  { tile: 150, speed: 0.045, vScale: 1.0, alpha: 0.17 },
  { tile: 230, speed: -0.028, vScale: 0.7, alpha: 0.12 },
];

const FLOW_TINT = { hp: [0.95, 0.3, 0.18], gold: [0.95, 0.72, 0.2], blue: [0.45, 0.7, 1], silver: [0.9, 0.9, 0.85] };

// faísca (núcleo + 4 raios finos), branca; o jogo tinge
function renderSpark(T) {
  const img = I.create(T, T);
  const c = (T - 1) / 2;
  for (let j = 0; j < T; j++) for (let i = 0; i < T; i++) {
    const dx = (i - c) / c, dy = (j - c) / c, r = Math.hypot(dx, dy);
    const core = Math.exp(-(r * r) / 0.035);
    const glow = 0.35 * Math.exp(-(r * r) / 0.18);
    const rays = 0.55 * (Math.exp(-(dy * dy) / 0.002) * Math.max(0, 1 - Math.abs(dx)) +
                         Math.exp(-(dx * dx) / 0.002) * Math.max(0, 1 - Math.abs(dy)));
    const a = clamp(core + glow + rays);
    const o = (j * T + i) * 4;
    img.px[o] = 255; img.px[o + 1] = 255; img.px[o + 2] = 255; img.px[o + 3] = a * 255;
  }
  return img;
}

// ---------------------------------------------------------------------------
// Gera tudo
// ---------------------------------------------------------------------------
const tex = {};
const save = (name, img) => { tex[name] = img; I.writeTGA(path.join(OUT, name + ".tga"), img); };

save("Diamond", renderDiamond(256));
save("XPRing", renderRing(256));
save("Spark", renderSpark(32));
save("HPBg", renderBar(HP, HPB, 1024, 64, "bg", null, 1));
save("HPFill", renderBar(HP, HPB, 1024, 64, "fill", PAL.hp, 11));
save("HPFillNeutral", renderBar(HP, HPB, 1024, 64, "fill", PAL.neutral, 11));
save("ResBg", renderBar(RS, RSB, 1024, 64, "bg", null, 2));
save("ResGold", renderBar(RS, RSB, 1024, 64, "fill", PAL.gold, 23));
save("ResBlue", renderBar(RS, RSB, 1024, 64, "fill", PAL.blue, 37));
save("ResSilver", renderBar(RS, RSB, 1024, 64, "fill", PAL.silver, 41));
save("HPMask", renderBar(HP, HPB, 1024, 64, "mask", null, 1));
save("ResMask", renderBar(RS, RSB, 1024, 64, "mask", null, 2));
save("Flow", renderFlow(256, 64));

// ---------------------------------------------------------------------------
// Layout para o Lua
// ---------------------------------------------------------------------------
const r1 = (v) => Math.round(v * 10) / 10;
const box = (B) => `{ x = ${r1(B.x)}, y = ${r1(B.y)}, w = ${r1(B.w)}, h = ${r1(B.h)} }`;
const L = {
  // centros da tinta dos algarismos medidos no print (px a partir do centro do losango)
  level: [r1(C + 1.0 * K), r1(C - 13.0 * K)], pct: [r1(C + 1.5 * K), r1(C + 8.4 * K)],
  hpText: [r1(HPB.x + HPB.w / 2), r1(HPB.y + HPB.h / 2)],
  rsText: [r1(RSB.x + RSB.w / 2), r1(RSB.y + RSB.h / 2)],
};
// filete: fração da textura onde ficam os vértices (centro do traço)
const ringV = r1(((C - (D + RING_OFF + RING_HALF)) / BOX) * 1000) / 1000;
const lua = `-- GERADO por tools/bdo-hud-concept/gen.js: não editar à mão.
-- HUD "bdo" em unidades da UI, relativas ao canto superior esquerdo da HUD.
local _, Azaath = ...
Azaath.BDO = {
    hud = { w = ${HUD.w}, h = ${HUD.h} },
    diamond = { x = 0, y = 0, size = ${r1(BOX)} },
    ringEdge = ${ringV}, -- vértice do filete de XP (fração da caixa a partir da borda)
    hp = ${box(HPB)},
    res = ${box(RSB)},
    hpPoly = { ${HP.map((p) => `{ ${r1(p[0])}, ${r1(p[1])} }`).join(", ")} },
    resPoly = { ${RS.map((p) => `{ ${r1(p[0])}, ${r1(p[1])} }`).join(", ")} },
    levelText = { ${L.level[0]}, ${L.level[1]} },
    pctText = { ${L.pct[0]}, ${L.pct[1]} },
    hpText = { ${L.hpText[0]}, ${L.hpText[1]} },
    resText = { ${L.rsText[0]}, ${L.rsText[1]} },
    -- Noto Sans Medium: algarismos = 0.714 do tamanho -> 15 px (nível) e 8.5 px (%) do print
    fonts = { level = ${r1((15 * K) / 0.714)}, pct = ${r1((8.5 * K) / 0.714)}, bar = 14, res = 13 },
    flow = { ${FLOW.map((f) => `{ tile = ${f.tile}, speed = ${f.speed}, vScale = ${f.vScale}, alpha = ${f.alpha} }`).join(", ")} },
}
`;
fs.writeFileSync(path.join(ROOT, "Modules", "BDOLayoutData.lua"), lua);

// ---------------------------------------------------------------------------
// Prévia: referência (escalada a K*S) em cima, HUD recomposta embaixo
// ---------------------------------------------------------------------------
{
  const S = 2; // px por unidade na prévia
  const W = Math.ceil(HUD.w * S) + 40, H = Math.ceil(HUD.h * S) + 20;
  const sample = (img, u, v) => {
    const x = clamp(u * img.w - 0.5, 0, img.w - 1), y = clamp(v * img.h - 0.5, 0, img.h - 1);
    const x0 = Math.floor(x), y0 = Math.floor(y), x1 = Math.min(img.w - 1, x0 + 1), y1 = Math.min(img.h - 1, y0 + 1);
    const tx = x - x0, ty = y - y0, out = [0, 0, 0, 0];
    for (let k = 0; k < 4; k++) {
      const p = (xx, yy) => img.px[(yy * img.w + xx) * 4 + k];
      out[k] = lerp(lerp(p(x0, y0), p(x1, y0), tx), lerp(p(x0, y1), p(x1, y1), tx), ty);
    }
    return out;
  };
  // layer: textura, recorte (u0,u1,v0,v1), destino (x,y,w,h em un.), cor, blend
  function draw(dst, ox, oy, img, tc, rc, tint = [1, 1, 1], alpha = 1, add = false) {
    const [u0, u1, v0, v1] = tc;
    for (let j = Math.floor(rc.y * S); j < Math.ceil((rc.y + rc.h) * S); j++)
      for (let i = Math.floor(rc.x * S); i < Math.ceil((rc.x + rc.w) * S); i++) {
        const fx = ((i + 0.5) / S - rc.x) / rc.w, fy = ((j + 0.5) / S - rc.y) / rc.h;
        if (fx < 0 || fy < 0 || fx > 1 || fy > 1) continue;
        const s = sample(img, lerp(u0, u1, fx), lerp(v0, v1, fy));
        const a = (s[3] / 255) * alpha, X = ox + i, Y = oy + j;
        if (X < 0 || Y < 0 || X >= dst.w || Y >= dst.h || a <= 0) continue;
        const o = (Y * dst.w + X) * 4;
        for (let k = 0; k < 3; k++) {
          const c = s[k] * tint[k];
          dst.px[o + k] = add ? Math.min(255, dst.px[o + k] + c * a) : dst.px[o + k] * (1 - a) + c * a;
        }
      }
  }
  function compose(hpF, rsF, xpF, resTex) {
    const im = I.create(W, H, 104, 128, 158, 255); // céu azulado como no print
    for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) { const o = (j * W + i) * 4; const t = j / H; im.px[o] = lerp(120, 150, t); im.px[o + 1] = lerp(140, 150, t); im.px[o + 2] = lerp(170, 160, t); }
    const ox = 20, oy = 10;
    draw(im, ox, oy, tex.Diamond, [0, 1, 0, 1], { x: 0, y: 0, w: BOX, h: BOX });
    // filete de XP: 4 arestas (cima->dir->baixo->esq), mesma lógica do Lua
    const e = ringV, span = 0.5 - e;
    const parts = [];
    for (let k = 0; k < 4; k++) {
      const f = clamp(xpF * 4 - k);
      if (f <= 0) continue;
      const g = f >= 1 ? 0.5 : f * span;
      if (k === 0) parts.push([0.5, 0.5 + g, 0, 0.5]);
      if (k === 1) parts.push([0.5, 1, 0.5, 0.5 + g]);
      if (k === 2) parts.push([0.5 - g, 0.5, 0.5, 1]);
      if (k === 3) parts.push([0, 0.5, 0.5 - g, 0.5]);
    }
    for (const [u0, u1, v0, v1] of parts)
      draw(im, ox, oy, tex.XPRing, [u0, u1, v0, v1], { x: u0 * BOX, y: v0 * BOX, w: (u1 - u0) * BOX, h: (v1 - v0) * BOX });
    draw(im, ox, oy, tex.HPBg, [0, 1, 0, 1], HPB);
    draw(im, ox, oy, tex.HPFill, [0, hpF, 0, 1], { x: HPB.x, y: HPB.y, w: HPB.w * hpF, h: HPB.h });
    draw(im, ox, oy, tex.ResBg, [0, 1, 0, 1], RSB);
    draw(im, ox, oy, resTex, [0, rsF, 0, 1], { x: RSB.x, y: RSB.y, w: RSB.w * rsF, h: RSB.h });
    // correnteza (ADD, mascarada pelo formato e cortada na ponta do preenchimento)
    const flow = (Bx, mask, frac, tint) => {
      for (const f of FLOW) {
        for (let j = Math.floor(Bx.y * S); j < Math.ceil((Bx.y + Bx.h) * S); j++)
          for (let i = Math.floor(Bx.x * S); i < Math.ceil((Bx.x + Bx.w * frac) * S); i++) {
            const fx = ((i + 0.5) / S - Bx.x) / Bx.w, fy = ((j + 0.5) / S - Bx.y) / Bx.h;
            if (fx < 0 || fy < 0 || fx > 1 || fy > 1) continue;
            const m = sample(mask, fx, fy)[3] / 255;
            const s = sample(tex.Flow, ((fx * Bx.w) / f.tile + 0.3) % 1, (fy * f.vScale) % 1);
            const a = m * f.alpha, o = ((oy + j) * im.w + ox + i) * 4;
            for (let k = 0; k < 3; k++) im.px[o + k] = Math.min(255, im.px[o + k] + s[k] * tint[k] * a);
          }
      }
    };
    flow(HPB, tex.HPMask, hpF, FLOW_TINT.hp);
    flow(RSB, tex.ResMask, rsF, resTex === tex.ResBlue ? FLOW_TINT.blue : FLOW_TINT.gold);
    return im;
  }
  const ref = readPNG(process.argv[2] || path.join(__dirname, "reference.png"));
  // a referência: centro do losango em (59.5, 49) px -> C un.
  const refImg = I.create(W, H);
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
    const ux = (i - 20) / S, uy = (j - 10) / S;
    const rx = 59.5 + (ux - C) / K, ry = 49 + (uy - C) / K;
    const s = sample(ref, rx / ref.w, ry / ref.h), o = (j * W + i) * 4;
    refImg.px[o] = s[0]; refImg.px[o + 1] = s[1]; refImg.px[o + 2] = s[2]; refImg.px[o + 3] = 255;
  }
  const a = compose(1, 1, 0.02367, tex.ResGold);
  const b = compose(0.62, 0.38, 0.6, tex.ResGold);
  const c = compose(1, 0.8, 0.3, tex.ResBlue);
  const all = I.create(W, H * 4);
  I.blit(all, refImg, 0, 0); I.blit(all, a, 0, H); I.blit(all, b, 0, H * 2); I.blit(all, c, 0, H * 3);
  I.writePNG(path.join(PREV, "compare.png"), all);
}

console.log("BDO: texturas em", OUT, "| HUD", HUD.w, "x", HUD.h, "| prévia em", PREV);
