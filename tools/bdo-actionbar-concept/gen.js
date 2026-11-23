// Texturas da barra de ação da skin "bdo" (conceito em concept.html):
// losangos de habilidade com a arte do losango de nível da HUD BDO e os
// direcionais de 4 losangos do Throne and Liberty.
// Unidades = unidades da UI; as medidas batem com Azaath.BDO_BAR (BDOBarData.lua).
// Uso: node tools/bdo-actionbar-concept/gen.js
"use strict";
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");

const ROOT = path.join(__dirname, "..", "..", "AzaathUI");
const OUT = path.join(ROOT, "Media", "BDO", "Bar");
fs.mkdirSync(OUT, { recursive: true });

const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const lerp = (a, b, t) => a + (b - a) * t;
const mix = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];

// --------------------------------------------------------------------------
// Medidas (unidades da UI)
// --------------------------------------------------------------------------
const G = {
  r: 30, gap: 2,              // losango do direcional (botão = 2r)
  wr: 22, wgap: 2,            // losango das asas
  pad: 7,                     // folga entre os losangos e a moldura do direcional
  clusterGap: 34,             // espaço entre direcionais
  wingGap: 44,                // espaço entre o direcional e a asa
  keyH: 14,
};
G.R = 2 * G.r + G.gap + G.pad;

// rasterizador: f(X, Y) -> [r, g, b, a] em unidades; caixa `size` un. em T px
function raster(T, size, f, SS = 3) {
  const img = I.create(T, T);
  for (let j = 0; j < T; j++) for (let i = 0; i < T; i++) {
    let acc = [0, 0, 0], aAcc = 0;
    for (let sj = 0; sj < SS; sj++) for (let si = 0; si < SS; si++) {
      const X = ((i + (si + 0.5) / SS) / T) * size - size / 2;
      const Y = ((j + (sj + 0.5) / SS) / T) * size - size / 2;
      const c = f(X, Y);
      if (!c || c[3] <= 0) continue;
      acc = acc.map((v, k) => v + c[k] * c[3]); aAcc += c[3];
    }
    const o = (j * T + i) * 4, n = SS * SS;
    if (aAcc > 0) { img.px[o] = acc[0] / aAcc; img.px[o + 1] = acc[1] / aAcc; img.px[o + 2] = acc[2] / aAcc; }
    img.px[o + 3] = (aAcc / n) * 255;
  }
  return img;
}
// distância perpendicular até a borda de um losango de meia-diagonal h (+ dentro)
const dd = (X, Y, h) => (h - (Math.abs(X) + Math.abs(Y))) / Math.SQRT2;
// "por cima": compõe camadas [r,g,b,a] em ordem
function over(...layers) {
  let c = [0, 0, 0], a = 0;
  for (const l of layers) {
    if (!l || l[3] <= 0) continue;
    const na = l[3] + a * (1 - l[3]);
    c = c.map((v, k) => (l[k] * l[3] + v * a * (1 - l[3])) / na);
    a = na;
  }
  return [...c, a];
}
const band = (d, a, b, soft = 0.6) => clamp(Math.min((d - a) / soft + 0.5, (b - d) / soft + 0.5));

const save = (name, img) => I.writeTGA(path.join(OUT, name + ".tga"), img);

// --------------------------------------------------------------------------
// Losango de habilidade (caixa = botão, 2h; o traço claro fica na borda)
// --------------------------------------------------------------------------
function slotTextures(prefix, r) {
  const h = r - 1.2; // borda externa da moldura escura
  // fundo translúcido (aparece nos espaços vazios)
  save(prefix + "BG", raster(128, 2 * r, (X, Y) => {
    const d = dd(X, Y, h);
    if (d < 0) return null;
    return [46, 44, 48, 0.78 * clamp(d / 0.6)];
  }));
  // moldura: traço claro por fora, borda escura grossa, filete quente por dentro
  save(prefix + "Frame", raster(128, 2 * r, (X, Y) => {
    const d = dd(X, Y, h);
    const L = clamp((12 - Y) / 24);
    return over(
      [0, 0, 0, d < 0 ? 0.3 * Math.exp(d / 1.2) : 0],
      [20, 19, 23, 0.85 * band(d, 0, 1.7, 1.0)],
      [...mix([88, 76, 66], [150, 132, 112], L), lerp(0.5, 0.8, L) * band(d, 1.6, 2.5, 0.9)],
    );
  }));
  // brilho de vidro na metade de cima
  save(prefix + "Gloss", raster(128, 2 * r, (X, Y) => {
    const d = dd(X, Y, h - 1);
    if (d < 0) return null;
    const v = (Y + h) / (2 * h);
    return [255, 255, 255, 0.2 * clamp(1 - v / 0.45) * clamp(d / 0.6)];
  }));
  // aro de proc (ADD): caixa maior que o botão (2r + 16)
  save(prefix + "Proc", raster(128, 2 * r + 16, (X, Y) => {
    const t = Math.abs(-dd(X, Y, h) - 3);
    const core = clamp((1.3 - t) / 0.7);
    const glow = 0.55 * Math.exp(-t / 2.6) * clamp((r + 8 - Math.max(Math.abs(X), Math.abs(Y))) / 5);
    const a = Math.max(core, glow);
    return [255, lerp(200, 245, core), lerp(90, 200, core), a];
  }));
}
slotTextures("Slot", G.r);
slotTextures("Wing", G.wr);

// máscara de losango (recarga, destaque, cópia escura do ícone) — branca, alfa = losango
save("Mask", raster(128, 128, (X, Y) => [255, 255, 255, clamp(dd(X, Y, 63) / 0.5 + 0.5)]));
// máscara do ícone da frente: losango x quadrado de 72% com as bordas esfumadas
// (o ícone fica menor que o botão; a cópia escura atrás cobre as pontas)
const ICON = 0.72;
save("IconMask", raster(256, 2, (X, Y) => {
  const dia = clamp(dd(X, Y, 0.985) / 0.006 + 0.5);
  const sq = clamp((ICON - Math.max(Math.abs(X), Math.abs(Y))) / 0.1);
  return [255, 255, 255, dia * sq * sq * (3 - 2 * sq)];
}));

// --------------------------------------------------------------------------
// Moldura do direcional (caixa = 2R + 16)
// --------------------------------------------------------------------------
const CB = 2 * G.R + 16;
// ruído de valor (granulado do fundo)
function hash(ix, iy, seed) {
  let h = (ix * 374761393 + iy * 668265263 + seed * 2147483647) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  return ((h ^ (h >>> 16)) >>> 0) / 4294967295;
}
function vnoise(x, y, seed) {
  const ix = Math.floor(x), iy = Math.floor(y), fx = x - ix, fy = y - iy;
  const sx = fx * fx * (3 - 2 * fx), sy = fy * fy * (3 - 2 * fy);
  return lerp(lerp(hash(ix, iy, seed), hash(ix + 1, iy, seed), sx), lerp(hash(ix, iy + 1, seed), hash(ix + 1, iy + 1, seed), sx), sy);
}
function fbm(x, y, seed, oct = 4) {
  let s = 0, a = 0.5, f = 1, n = 0;
  for (let o = 0; o < oct; o++) { s += a * vnoise(x * f, y * f, seed + o * 17); n += a; a *= 0.5; f *= 2; }
  return s / n;
}
const sstep = (e0, e1, v) => { const t = clamp((v - e0) / (e1 - e0)); return t * t * (3 - 2 * t); };
// luz de cima: 1 nas arestas de cima, 0 nas de baixo (transição suave no meio)
const lit = (Y) => sstep(12, -12, Y);

// Moldura do direcional: filete fino de metal claro (aceso em cima), sombra
// macia por fora e um aro de vidro escuro translúcido com reflexo suave —
// nada de faixa escura grossa. O que aparece é o aro (folga de G.pad) e as frestas.
save("Cluster", raster(512, CB, (X, Y) => {
  const d = dd(X, Y, G.R);
  const L = lit(Y);
  const shadow = d < 0.6 ? 0.26 * Math.exp((d - 0.6) / 5) : 0;
  const hair = Math.exp(-Math.pow((d - 0.7) / 0.42, 2));                 // filete externo
  const metal = mix([120, 110, 98], [214, 200, 176], L);
  if (d < 0) return [0, 0, 0, Math.max(shadow, 0.55 * hair * lerp(0.45, 0.85, L))].map((v, i) => i < 3 ? (hair > 0.05 ? metal[i] : 0) : v);
  const grain = fbm(X / 3.2, Y / 3.2, 5, 3) - 0.5;
  const t = clamp(d / (G.pad + 1));
  // vidro: mais claro perto do filete, escurece para dentro; reflexo largo em cima
  let glass = mix([46, 44, 48], [24, 23, 27], sstep(0.05, 0.9, t)).map((v) => v * (1 + 0.08 * grain));
  const sheen = 0.16 * L * Math.exp(-Math.pow((d - 2.6) / 1.6, 2));
  glass = mix(glass, [230, 220, 205], sheen);
  // sulco discreto antes dos losangos
  const lip = 0.16 * Math.exp(-Math.pow((d - (G.pad - 1.2)) / 0.45, 2)) * lerp(0.4, 1, L);
  glass = mix(glass, [190, 176, 156], lip);
  // filete externo por cima do vidro
  const c = mix(glass, metal, hair * lerp(0.5, 0.9, L));
  if (d < G.pad + 1.5) return [...c, Math.max(lerp(0.5, 0.42, t), hair * 0.85)];
  const r = (Math.abs(X) + Math.abs(Y)) / G.R;
  const core = mix([36, 34, 39], [20, 19, 23], sstep(0.05, 0.9, r)).map((v) => v * (1 + 0.1 * grain));
  return [...core, 0.45];
}));

// versão dourada (por cima da comum): filete de ouro fino e aceso em cima,
// brilho largo e bem macio, quinas pequenas
save("ClusterGold", raster(512, CB, (X, Y) => {
  const d = dd(X, Y, G.R);
  const L = lit(Y);
  const line = Math.exp(-Math.pow((d - 0.7) / 0.55, 2));
  const glow = 0.3 * Math.exp(-Math.abs(d - 0.7) / 4.5);
  const gold = mix([168, 128, 52], [252, 234, 176], clamp(0.3 + 0.6 * L + 0.3 * line));
  const inner = 0.3 * Math.exp(-Math.pow((d - 3.2) / 0.5, 2)) * lerp(0.4, 1, L);
  let stud = 0;
  for (const [vx, vy] of [[0, -1], [1, 0], [0, 1], [-1, 0]]) {
    const sx = X - vx * (G.R + 0.4), sy = Y - vy * (G.R + 0.4);
    stud = Math.max(stud, clamp((1.9 - Math.hypot(sx, sy)) / 0.7 + 0.5));
  }
  return over(
    [226, 189, 98, glow],
    [...gold, line],
    [246, 226, 168, inner],
    [...mix([170, 130, 56], [252, 238, 186], clamp(0.4 + 0.5 * L)), stud],
  );
}));

// gema central (apagada / acesa)
save("Gem", raster(64, 26, (X, Y) => {
  const d = dd(X, Y, 11.5), r = Math.hypot(X + 1.5, Y + 1.5) / 6;
  return over(
    [14, 13, 16, band(d, 0, 20)],
    [106, 90, 76, band(d, 0.3, 1.6)],
    [...mix([138, 130, 120], [42, 38, 34], clamp(r)), band(d, 4.8, 20)],
  );
}));
save("GemLit", raster(64, 26, (X, Y) => {
  const d = dd(X, Y, 11.5), r = Math.hypot(X + 1.5, Y + 1.5) / 6;
  return over(
    [226, 189, 98, d < 0 ? 0.6 * Math.exp(d / 2.5) * clamp((13 - Math.max(Math.abs(X), Math.abs(Y))) / 2.5) : 0],
    [14, 13, 16, band(d, 0, 20)],
    [226, 189, 98, band(d, 0.3, 1.6)],
    [...mix([255, 246, 207], [184, 134, 46], clamp(r)), band(d, 4.8, 20)],
  );
}));

// plaquinha da tecla (3 fatias: metade esquerda / meio / metade direita)
{
  const W = 32, H = 16, img = I.create(W, H), SS = 4, rad = 3.2;
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
    let a = 0, b = 0;
    for (let sj = 0; sj < SS; sj++) for (let si = 0; si < SS; si++) {
      const x = i + (si + 0.5) / SS, y = j + (sj + 0.5) / SS;
      const qx = Math.max(rad - x, 0, x - (W - rad)), qy = Math.max(rad - y, 0, y - (H - rad));
      const dist = rad - Math.hypot(qx, qy); // + dentro
      if (dist < 0) continue;
      a += 1; if (dist < 1.1) b += 1;
    }
    const o = (j * W + i) * 4, n = SS * SS, cov = a / n, edge = a ? b / a : 0;
    const c = mix([14, 13, 16], [120, 102, 86], edge);
    img.px[o] = c[0]; img.px[o + 1] = c[1]; img.px[o + 2] = c[2];
    img.px[o + 3] = 255 * cov * lerp(0.85, 0.9, edge);
  }
  save("Key", img);
}

// --------------------------------------------------------------------------
// Medidas para o Lua
// --------------------------------------------------------------------------
const lua = `-- GERADO por tools/bdo-actionbar-concept/gen.js: não editar à mão.
-- Barra de ação da skin "bdo" (unidades da UI).
local _, Azaath = ...
Azaath.BDO_BAR = {
    r = ${G.r}, gap = ${G.gap}, R = ${G.R}, clusterBox = ${CB},
    wr = ${G.wr}, wgap = ${G.wgap},
    clusterGap = ${G.clusterGap}, wingGap = ${G.wingGap},
    procBox = { slot = ${2 * G.r + 16}, wing = ${2 * G.wr + 16} },
    gem = 26, keyH = ${G.keyH}, icon = ${ICON},
}
`;
fs.writeFileSync(path.join(ROOT, "Modules", "BDOBarData.lua"), lua);
console.log("BDO bar: texturas em", OUT);
