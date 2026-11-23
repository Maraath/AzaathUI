// Gera as texturas do card "Atributos & Combate" (tecla C) a partir da arte
// de conceito (tools/sheet-concept/concept.bmp, 768x1376):
//   * apaga todo texto e valor dinâmico (preenchimento harmônico a partir da borda);
//   * esvazia as barras e o seletor de telemetria;
//   * recorta preenchimentos (vida, recurso, medidores) e destaques (aba ativa,
//     pílula ativa) para o jogo desenhar por cima.
// Uso: node tools/sheet-concept/gen.js  [--preview]
const fs = require("fs");
const path = require("path");
const I = require("./img");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Sheet");
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(PREV, { recursive: true });

const src = I.readBMP(path.join(__dirname, "concept.bmp"));
const W = src.w, H = src.h;
const img = { w: W, h: H, px: Float32Array.from(src.px) };

// Card: borda externa em x 62..705 / y 63..1314 (1 px de folga para o anti-aliasing)
const CARD = { x: 61, y: 62, w: 646, h: 1254, r: 13 };

const idx = (x, y) => (y * W + x) * 4;
const lum = (im, x, y) => { const o = (y * im.w + x) * 4; return 0.3 * im.px[o] + 0.59 * im.px[o + 1] + 0.11 * im.px[o + 2]; };
const get = (im, x, y) => { const o = (y * im.w + x) * 4; return [im.px[o], im.px[o + 1], im.px[o + 2]]; };
const set = (im, x, y, c) => { const o = (y * im.w + x) * 4; im.px[o] = c[0]; im.px[o + 1] = c[1]; im.px[o + 2] = c[2]; };
const clone = (im) => ({ w: im.w, h: im.h, px: Float32Array.from(im.px) });

// ---------------------------------------------------------------------------
// Preenchimento harmônico (Laplace) dos pixels mascarados dentro de um retângulo
// ---------------------------------------------------------------------------
function inpaint(x0, y0, x1, y1, mask) {
  const w = x1 - x0 + 1, h = y1 - y0 + 1;
  const m = (i, j) => mask[j * w + i];
  // chute inicial: média da borda não mascarada
  let acc = [0, 0, 0], n = 0;
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (!m(i, j)) {
    const c = get(img, x0 + i, y0 + j); acc[0] += c[0]; acc[1] += c[1]; acc[2] += c[2]; n++;
  }
  const mean = n ? acc.map((v) => v / n) : [14, 20, 28];
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (m(i, j)) set(img, x0 + i, y0 + j, mean);
  const iters = Math.max(300, Math.min(4000, Math.max(w, h) * 6));
  for (let it = 0; it < iters; it++) {
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
      if (!m(i, j)) continue;
      const x = x0 + i, y = y0 + j;
      let s = [0, 0, 0], c = 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const xx = x + dx, yy = y + dy;
        if (xx < x0 - 1 || yy < y0 - 1 || xx > x1 + 1 || yy > y1 + 1) continue;
        const p = get(img, xx, yy); s[0] += p[0]; s[1] += p[1]; s[2] += p[2]; c++;
      }
      if (c) set(img, x, y, s.map((v) => v / c));
    }
  }
}

function dilate(mask, w, h, r) {
  let cur = mask;
  for (let k = 0; k < r; k++) {
    const nx = Uint8Array.from(cur);
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (cur[j * w + i]) {
      for (let dj = -1; dj <= 1; dj++) for (let di = -1; di <= 1; di++) {
        const ii = i + di, jj = j + dj;
        if (ii >= 0 && jj >= 0 && ii < w && jj < h) nx[jj * w + ii] = 1;
      }
    }
    cur = nx;
  }
  return cur;
}

const pct = (arr, p) => { const s = Float32Array.from(arr).sort(); return s[Math.min(s.length - 1, Math.floor(p * s.length))]; };

// Apaga texto claro (ou escuro, dark=true) numa caixa [x0,y0,x1,y1] + folga
function erase(x0, y0, x1, y1, o = {}) {
  const pad = o.pad ?? 3, thr = o.thr ?? 16, dil = o.dil ?? 2;
  x0 -= pad; y0 -= pad; x1 += pad; y1 += pad;
  const w = x1 - x0 + 1, h = y1 - y0 + 1;
  const border = [];
  for (let i = 0; i < w; i++) { border.push(lum(img, x0 + i, y0), lum(img, x0 + i, y1)); }
  for (let j = 0; j < h; j++) { border.push(lum(img, x0, y0 + j), lum(img, x1, y0 + j)); }
  const ref = o.dark ? pct(border, 0.2) : pct(border, 0.85);
  let mask = new Uint8Array(w * h);
  for (let j = 1; j < h - 1; j++) for (let i = 1; i < w - 1; i++) {
    const L = lum(img, x0 + i, y0 + j);
    if (o.all || (o.dark ? L < ref - thr : L > ref + thr)) mask[j * w + i] = 1;
  }
  mask = dilate(mask, w, h, dil);
  // nunca mascara a moldura de 1 px (é a condição de contorno)
  for (let i = 0; i < w; i++) { mask[i] = 0; mask[(h - 1) * w + i] = 0; }
  for (let j = 0; j < h; j++) { mask[j * w] = 0; mask[j * w + w - 1] = 0; }
  inpaint(x0, y0, x1, y1, mask);
}

// Cor típica do texto numa caixa (média dos 25% pixels mais claros/escuros)
function textColor(x0, y0, x1, y1, dark) {
  const px = [];
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) px.push([lum(src, x, y), get(src, x, y)]);
  px.sort((a, b) => (dark ? a[0] - b[0] : b[0] - a[0]));
  const top = px.slice(0, Math.max(1, Math.floor(px.length * 0.12)));
  const c = [0, 0, 0]; for (const [, p] of top) { c[0] += p[0]; c[1] += p[1]; c[2] += p[2]; }
  return c.map((v) => +(v / top.length / 255).toFixed(2));
}

// ---------------------------------------------------------------------------
// 1) Textos (coordenadas do conceito)
// ---------------------------------------------------------------------------
const TEXTS = {
  tab1: [94, 88, 324, 102], tab2: [369, 89, 526, 102], tab3: [583, 89, 664, 102],
  hHero: [317, 147, 451, 162], hConst: [224, 282, 542, 297], hTele: [216, 787, 551, 801], hElem: [296, 1143, 472, 1157],
  vitL: [110, 177, 224, 190], vitV: [338, 176, 370, 190], powL: [397, 177, 453, 190], powV: [647, 176, 656, 190],
  sub: [228, 234, 540, 245],
  agi: [100, 448, 197, 461], vig: [570, 448, 626, 461], spi: [249, 664, 329, 677], int: [429, 664, 527, 677], str: [425, 344, 488, 358],
  n39: [225, 444, 252, 464], n54: [514, 445, 542, 464], n32: [275, 613, 303, 632], n22: [464, 613, 491, 632], n50: [368, 342, 400, 363],
  pill2: [299, 731, 469, 743], pill3: [536, 731, 614, 743], pill1: [146, 731, 239, 743],
  hero1: [165, 826, 316, 861], hero2: [491, 826, 560, 861], heroL1: [160, 875, 322, 888], heroL2: [437, 875, 616, 890],
  g1L: [112, 939, 258, 953], g1V: [322, 939, 367, 953], g2L: [399, 939, 522, 953], g2V: [607, 939, 655, 953],
  g3L: [111, 1003, 275, 1016], g3V: [311, 1002, 367, 1016], g4L: [400, 1003, 527, 1020], g4V: [599, 1002, 655, 1016],
  chip1: [183, 1081, 298, 1094], chip2: [412, 1081, 641, 1094],
  res: [251, 1173, 516, 1192],
};

const colors = {};
for (const [k, b] of Object.entries(TEXTS)) colors[k] = textColor(...b, k === "n50" || k === "pill1");

// Filete dos títulos de seção: recorta o da esquerda de "HERO VITALS" (x 100..302,
// fica mais claro perto do texto) antes de apagar; no jogo ele é esticado até o texto.
const headerLine = I.create(203, 10);
{
  // fundo local = média das linhas logo acima e abaixo do filete
  for (let j = 0; j < 10; j++) for (let i = 0; i < 203; i++) {
    const x = 100 + i, y = 150 + j;
    const a = get(img, x, y), up = get(img, x, 146), dn = get(img, x, 163);
    const o = (j * 203 + i) * 4;
    for (let k = 0; k < 3; k++) headerLine.px[o + k] = Math.max(0, a[k] - (up[k] + dn[k]) / 2);
    headerLine.px[o + 3] = 255;
  }
}
// títulos de seção: texto + filetes saem da arte (o jogo desenha em PT-BR com filetes do tamanho certo)
for (const y of [[145, 164], [280, 299], [785, 803], [1141, 1159]]) erase(96, y[0], 672, y[1], { all: true, pad: 2 });

// Força: rótulo sobre o halo da esfera dourada
erase(...TEXTS.str, { all: true, pad: 5 });
for (const [k, b] of Object.entries(TEXTS)) {
  if (k === "str" || k.startsWith("pill")) continue;
  if (k === "n50") erase(...b, { dark: true, thr: 14, pad: 2, dil: 3 });
  else if (k.startsWith("n")) erase(...b, { thr: 10, pad: 2, dil: 3 });
  else erase(...b, { all: true, pad: 5 });
}
erase(...TEXTS.pill2, { all: true, pad: 4 });
erase(...TEXTS.pill3, { all: true, pad: 4 });
// "OFENSIVA" (texto escuro sobre a pílula ciano): sai da textura do destaque
erase(...TEXTS.pill1, { all: true, pad: 3 });

// ---------------------------------------------------------------------------
// 2) Seletor de telemetria: tira a pílula ativa (espelha a ponta direita)
// ---------------------------------------------------------------------------
const PILL = { x0: 106, x1: 662, y0: 698, y1: 774 };
const pillSnap = clone(img);
for (let y = PILL.y0; y <= PILL.y1; y++) {
  for (let x = 88; x <= 300; x++) {
    const sx = x < 160 ? PILL.x0 + PILL.x1 - x : 500;
    set(img, x, y, get(pillSnap, sx, y));
  }
}
// destaque (ADD) = original - vazio
const pillAct = I.create(220, 80);
for (let j = 0; j < 80; j++) for (let i = 0; i < 220; i++) {
  const x = 84 + i, y = 696 + j;
  const a = get(pillSnap, x, y), b = get(img, x, y);
  const o = (j * 220 + i) * 4;
  pillAct.px[o] = Math.max(0, a[0] - b[0]); pillAct.px[o + 1] = Math.max(0, a[1] - b[1]); pillAct.px[o + 2] = Math.max(0, a[2] - b[2]); pillAct.px[o + 3] = 255;
}

// ---------------------------------------------------------------------------
// 3) Abas: tira o destaque da aba ativa (usa a coluna x=684, linha fina apagada)
// ---------------------------------------------------------------------------
const TAB = { x0: 64, x1: 702, y0: 66, y1: 138 };
const tabSnap = clone(img);
for (let y = TAB.y0; y <= TAB.y1; y++) for (let x = TAB.x0; x <= TAB.x1; x++) set(img, x, y, get(tabSnap, x > 640 ? x : 640, y));
const tabAct = I.create(TAB.x1 - TAB.x0 + 1, TAB.y1 - TAB.y0 + 1);
for (let j = 0; j < tabAct.h; j++) for (let i = 0; i < tabAct.w; i++) {
  const x = TAB.x0 + i, y = TAB.y0 + j;
  const a = get(tabSnap, x, y), b = get(img, x, y);
  const o = (j * tabAct.w + i) * 4;
  for (let k = 0; k < 3; k++) tabAct.px[o + k] = Math.max(0, a[k] - b[k]);
  tabAct.px[o + 3] = 255;
}

// ---------------------------------------------------------------------------
// 4) Barras vitais: trilha vazia + preenchimentos
// ---------------------------------------------------------------------------
const VB = { y0: 194, y1: 224 };           // faixa (com brilho) das barras vitais
const RAGE = { x0: 391, x1: 662 }, VIT = { x0: 105, x1: 377 };
const barSnap = clone(img);
// trilha vazia do recurso: ponta esquerda = espelho da direita, meio = coluna 560
for (let y = VB.y0; y <= VB.y1; y++) for (let x = RAGE.x0 - 4; x <= 446; x++) {
  const sx = x < RAGE.x0 + 16 ? RAGE.x0 + RAGE.x1 - x : 560;
  set(img, x, y, get(barSnap, sx, y));
}
// trilha vazia da vitalidade = trilha do recurso recolorida de dourado para carmesim
const recol = (c) => [c[0] * 0.92 + 4, c[1] * 0.42, c[2] * 0.62 + 6];
for (let y = VB.y0; y <= VB.y1; y++) for (let x = VIT.x0 - 6; x <= VIT.x1 + 6; x++) {
  let sx;
  if (x < VIT.x0 + 16) sx = RAGE.x0 + (x - VIT.x0);
  else if (x > VIT.x1 - 16) sx = RAGE.x1 - (VIT.x1 - x);
  else sx = 560;
  const g = get(img, sx, y), o = get(barSnap, x, y);
  // fora da trilha (brilho difuso) mistura com o fundo original
  const inTrack = y >= 199 && y <= 219;
  set(img, x, y, inTrack ? recol(g) : recol(g).map((v, k) => v * 0.5 + o[k] * 0.5 * 0.6));
}

const CAPW = 8;
function cropRect(im, x0, y0, x1, y1) { return I.crop(im, x0, y0, x1 - x0 + 1, y1 - y0 + 1); }
// Vida: corpo (sem a ponta direita) + ponta
const healthBody = cropRect(barSnap, VIT.x0, 199, VIT.x1 - CAPW, 219);
const healthCap = cropRect(barSnap, VIT.x1 - CAPW + 1, 199, VIT.x1, 219);
// Recurso: monta um preenchimento longo com a ponta esquerda, a coluna 412 repetida e a ponta (423..430)
function longFill(snap, xs, y0, y1, len, repCol, capX0, capX1) {
  const h = y1 - y0 + 1, out = I.create(len, h);
  for (let j = 0; j < h; j++) for (let i = 0; i < len; i++) {
    const sx = i < xs.length ? xs[i] : repCol;
    const c = get(snap, sx, y0 + j), o = (j * len + i) * 4;
    out.px[o] = c[0]; out.px[o + 1] = c[1]; out.px[o + 2] = c[2]; out.px[o + 3] = 255;
  }
  return { body: out, cap: cropRect(snap, capX0, y0, capX1, y1) };
}
const range = (a, b) => Array.from({ length: b - a + 1 }, (_, i) => a + i);
const power = longFill(barSnap, range(RAGE.x0, 412), 199, 219, RAGE.x1 - RAGE.x0 + 1 - CAPW, 412, 430 - CAPW + 1, 430);

// ---------------------------------------------------------------------------
// 5) Medidores (crítico/velocidade): trilha vazia copiada da linha de baixo (+63 px)
// ---------------------------------------------------------------------------
const GA = { y0: 960, y1: 981 };
const gaugeSnap = clone(img);
for (let y = GA.y0; y <= GA.y1; y++) for (let x = 100; x <= 668; x++) set(img, x, y, get(gaugeSnap, x, y + 63));
const gauge = longFill(gaugeSnap, range(397, 412), 963, 978, 0, 440, 0, 0);
const GAUGE_L = { x0: 110, x1: 369 }, GAUGE_R = { x0: 397, x1: 657 };
const gaugeFill = longFill(gaugeSnap, range(397, 414), 963, 978, (GAUGE_R.x1 - GAUGE_R.x0 + 1) - CAPW, 440, 467 - CAPW + 1, 467);

// ---------------------------------------------------------------------------
// 5b) Constelação sem as linhas: no jogo as ligações entre as esferas são
//     grilhões de energia animados (os mesmos da aba de Talentos, Sheet/Sanctuary.lua
//     SanctFX). Apaga as linhas e o círculo externo, mantém as 5 esferas.
// ---------------------------------------------------------------------------
{
  const ORBS = [[384, 352.5, 34], [528, 454.5, 30], [477.5, 622.5, 30], [289, 622.5, 30], [238.5, 454, 30]];
  const x0 = 150, y0 = 300, x1 = 618, y1 = 700, w = x1 - x0 + 1, h = y1 - y0 + 1;
  // fundo local: média numa janela de 13 px (as linhas têm 2..4 px)
  const R = 6, S = new Float64Array((w + 1) * (h + 1));
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) S[(j + 1) * (w + 1) + i + 1] = lum(img, x0 + i, y0 + j) + S[j * (w + 1) + i + 1] + S[(j + 1) * (w + 1) + i] - S[j * (w + 1) + i];
  const mean = (i, j) => { const a = Math.max(0, i - R), b = Math.max(0, j - R), c = Math.min(w - 1, i + R), d = Math.min(h - 1, j + R); return (S[(d + 1) * (w + 1) + c + 1] - S[b * (w + 1) + c + 1] - S[(d + 1) * (w + 1) + a] + S[b * (w + 1) + a]) / ((c - a + 1) * (d - b + 1)); };
  let mask = new Uint8Array(w * h);
  for (let j = 1; j < h - 1; j++) for (let i = 1; i < w - 1; i++) {
    const x = x0 + i, y = y0 + j;
    if (ORBS.some(([cx, cy, r]) => (x - cx) ** 2 + (y - cy) ** 2 < (r + 7) ** 2)) continue;
    const L = lum(img, x, y);
    if (L > mean(i, j) + 7 || L > 46) mask[j * w + i] = 1;
  }
  mask = dilate(mask, w, h, 2);
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const x = x0 + i, y = y0 + j;
    if (ORBS.some(([cx, cy, r]) => (x - cx) ** 2 + (y - cy) ** 2 < (r + 4) ** 2)) mask[j * w + i] = 0;
  }
  for (let i = 0; i < w; i++) { mask[i] = 0; mask[(h - 1) * w + i] = 0; }
  for (let j = 0; j < h; j++) { mask[j * w] = 0; mask[j * w + w - 1] = 0; }
  inpaint(x0, y0, x1, y1, mask);
}

// ---------------------------------------------------------------------------
// 6) Saída
// ---------------------------------------------------------------------------
function cardAlpha(im) {
  // cantos arredondados (raio CARD.r) com anti-aliasing
  const r = CARD.r;
  for (let y = 0; y < im.h; y++) for (let x = 0; x < im.w; x++) {
    const cx = Math.min(Math.max(x + 0.5, r), im.w - r), cy = Math.min(Math.max(y + 0.5, r), im.h - r);
    const d = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
    im.px[(y * im.w + x) * 4 + 3] = Math.max(0, Math.min(1, r - d + 0.5)) * 255;
  }
  return im;
}
function padTo(im, w, h) { const out = I.create(w, h); I.blit(out, im, 0, 0); return out; }

const card = cardAlpha(cropRect(img, CARD.x, CARD.y, CARD.x + CARD.w - 1, CARD.y + CARD.h - 1));

// Card vazio (Arsenal Salvo / Títulos): abaixo das abas, fundo suavizado do próprio card
const empty = clone(card);
{
  const bx = 24, cols = Math.ceil(empty.w / bx), rows = Math.ceil(empty.h / bx);
  const grid = [];
  for (let gy = 0; gy < rows; gy++) for (let gx = 0; gx < cols; gx++) {
    const ps = [];
    for (let y = gy * bx; y < Math.min(empty.h, (gy + 1) * bx); y++) for (let x = gx * bx; x < Math.min(empty.w, (gx + 1) * bx); x++)
      ps.push([lum(card, x, y), get(card, x, y)]);
    ps.sort((a, b) => a[0] - b[0]);
    const m = ps[Math.floor(ps.length * 0.35)][1];
    grid.push(m);
  }
  const G = (gx, gy) => grid[Math.min(rows - 1, Math.max(0, gy)) * cols + Math.min(cols - 1, Math.max(0, gx))];
  for (let y = 78; y < empty.h - 8; y++) for (let x = 8; x < empty.w - 8; x++) {
    const fx = (x + 0.5) / bx - 0.5, fy = (y + 0.5) / bx - 0.5, x0 = Math.floor(fx), y0 = Math.floor(fy), tx = fx - x0, ty = fy - y0;
    const c = [0, 1, 2].map((k) => (G(x0, y0)[k] * (1 - tx) + G(x0 + 1, y0)[k] * tx) * (1 - ty) + (G(x0, y0 + 1)[k] * (1 - tx) + G(x0 + 1, y0 + 1)[k] * tx) * ty);
    set(empty, x, y, c);
  }
}

const out = {
  AttrCard: [padTo(card, 1024, 2048)],
  AttrCardEmpty: [I.resize(empty, 512, 1024)],
  AttrTabActive: [padTo(tabAct, 1024, 128)],
  AttrPillActive: [padTo(pillAct, 256, 128)],
  AttrFillHealth: [I.resize(healthBody, 256, 32)],
  AttrFillHealthCap: [I.resize(healthCap, 16, 32)],
  AttrFillPower: [I.resize(power.body, 256, 32)],
  AttrFillPowerCap: [I.resize(power.cap, 16, 32)],
  AttrFillGauge: [I.resize(gaugeFill.body, 256, 16)],
  AttrFillGaugeCap: [I.resize(gaugeFill.cap, 16, 16)],
  AttrHeaderLine: [padTo(headerLine, 256, 16)],
};
// recurso em cinza (tingido no jogo para mana etc.)
{
  const g = clone(out.AttrFillPower[0]);
  for (let i = 0; i < g.w * g.h; i++) { const o = i * 4, L = 0.3 * g.px[o] + 0.59 * g.px[o + 1] + 0.11 * g.px[o + 2]; g.px[o] = g.px[o + 1] = g.px[o + 2] = Math.min(255, L * 1.25); }
  out.AttrFillPowerGray = [g];
  const c = clone(out.AttrFillPowerCap[0]);
  for (let i = 0; i < c.w * c.h; i++) { const o = i * 4, L = 0.3 * c.px[o] + 0.59 * c.px[o + 1] + 0.11 * c.px[o + 2]; c.px[o] = c.px[o + 1] = c.px[o + 2] = Math.min(255, L * 1.25); }
  out.AttrFillPowerGrayCap = [c];
}

for (const [name, [im]] of Object.entries(out)) {
  I.writeTGA(path.join(OUT, name + ".tga"), im);
  console.log("gerado", name, im.w + "x" + im.h);
}
// prévia (PNG) para conferir no navegador
I.writePNG(path.join(PREV, "card.png"), card);
I.writePNG(path.join(PREV, "empty.png"), empty);
I.writePNG(path.join(PREV, "tab.png"), tabAct);
I.writePNG(path.join(PREV, "pill.png"), pillAct);
I.writePNG(path.join(PREV, "fillHealth.png"), healthBody);
I.writePNG(path.join(PREV, "fillHealthCap.png"), healthCap);
I.writePNG(path.join(PREV, "fillPower.png"), power.body);
I.writePNG(path.join(PREV, "fillPowerCap.png"), power.cap);
I.writePNG(path.join(PREV, "fillGauge.png"), gaugeFill.body);
I.writePNG(path.join(PREV, "fillGaugeCap.png"), gaugeFill.cap);
fs.writeFileSync(path.join(PREV, "colors.json"), JSON.stringify({ colors, CARD, sizes: { tab: [tabAct.w, tabAct.h], pill: [pillAct.w, pillAct.h], health: [healthBody.w, healthBody.h], power: [power.body.w, power.body.h], gauge: [gaugeFill.body.w, gaugeFill.body.h] } }, null, 1));
console.log(JSON.stringify(colors));
