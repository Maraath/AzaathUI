// Recorta os ícones das folhas do usuário (fundo liso cinza ou escuro) com alfa por diferença ao fundo:
// o que é alcançável a partir da borda sem cruzar contorno forte vira transparência proporcional
// (brilho e sombra suaves ficam); o que fica cercado pelos contornos é opaco.
//   node icons.js  -> Media/MapFrame/ExpIco*.tga, ExpPin*.tga, ExpPlayerArrow.tga + out/icons/*.png + out/icons_sheet.png
"use strict";
const fs = require("fs");
const path = require("path");
const I = require("../../sheet-concept/img");
const { readPNG } = require("../../grimoire-concept/png");

const DIR = __dirname, SRC = path.join(DIR, "icons-src"), ROOT = path.resolve(DIR, "../../..");
const OUT_DIRS = [path.join(ROOT, "AzaathUI/Media/MapFrame"),
  "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame"];
const PREV = path.join(DIR, "out", "icons");
fs.mkdirSync(PREV, { recursive: true });

function boxBlur(src, w, h, r) {
  const tmp = new Float32Array(w * h), out = new Float32Array(w * h);
  for (let y = 0; y < h; y++) { let s = 0, n = 0;
    for (let x = -r; x < w; x++) { if (x + r < w) { s += src[y * w + x + r]; n++; } if (x - r - 1 >= 0) { s -= src[y * w + x - r - 1]; n--; } if (x >= 0) tmp[y * w + x] = s / n; } }
  for (let x = 0; x < w; x++) { let s = 0, n = 0;
    for (let y = -r; y < h; y++) { if (y + r < h) { s += tmp[(y + r) * w + x]; n++; } if (y - r - 1 >= 0) { s -= tmp[(y - r - 1) * w + x]; n--; } if (y >= 0) out[y * w + x] = s / n; } }
  return out;
}

// fundo estimado: média ponderada (desfocada) só dos pixels de fundo
function bgEstimate(img, isBg, r) {
  const { w, h } = img, N = w * h, wgt = new Float32Array(N), ch = [0, 1, 2].map(() => new Float32Array(N));
  for (let i = 0; i < N; i++) if (isBg[i]) { wgt[i] = 1; for (let k = 0; k < 3; k++) ch[k][i] = img.px[i * 4 + k]; }
  const wb = boxBlur(wgt, w, h, r), cb = ch.map((c) => boxBlur(c, w, h, r));
  let gm = [0, 0, 0], gn = 0;
  for (let i = 0; i < N; i++) if (isBg[i]) { for (let k = 0; k < 3; k++) gm[k] += img.px[i * 4 + k]; gn++; }
  gm = gm.map((v) => v / Math.max(1, gn));
  const bg = new Float32Array(N * 3);
  for (let i = 0; i < N; i++) for (let k = 0; k < 3; k++) bg[i * 3 + k] = wb[i] > 0.02 ? cb[k][i] / wb[i] : gm[k];
  return bg;
}

function flood(img, diffOf, thr) {
  const { w, h } = img, N = w * h, seen = new Uint8Array(N), st = [];
  const push = (i) => { if (!seen[i] && diffOf(i) < thr) { seen[i] = 1; st.push(i); } };
  for (let x = 0; x < w; x++) { push(x); push((h - 1) * w + x); }
  for (let y = 0; y < h; y++) { push(y * w); push(y * w + w - 1); }
  while (st.length) { const i = st.pop(), x = i % w, y = (i / w) | 0;
    if (x > 0) push(i - 1); if (x < w - 1) push(i + 1); if (y > 0) push(i - w); if (y < h - 1) push(i + w); }
  return seen;
}

function matte(img, { thrA, thrB, soft }) {
  const { w, h } = img, N = w * h;
  // 1) fundo grosseiro: perto da cor média da borda
  let m = [0, 0, 0], n = 0;
  for (let x = 0; x < w; x++) for (const y of [0, h - 1]) { for (let k = 0; k < 3; k++) m[k] += img.px[(y * w + x) * 4 + k]; n++; }
  m = m.map((v) => v / n);
  const d0 = (i) => Math.max(...[0, 1, 2].map((k) => Math.abs(img.px[i * 4 + k] - m[k])));
  const bg0 = flood(img, d0, thrA);
  // 2) fundo fino (com o degradê) e a diferença de cada pixel para ele
  const bg = bgEstimate(img, bg0, 40);
  const diff = new Float32Array(N);
  for (let i = 0; i < N; i++) diff[i] = Math.max(...[0, 1, 2].map((k) => Math.abs(img.px[i * 4 + k] - bg[i * 3 + k])));
  const out = flood(img, (i) => diff[i], thrB);
  const res = I.create(w, h);
  for (let i = 0; i < N; i++) {
    let a = out[i] ? Math.max(0, Math.min(1, (diff[i] - 4) / soft)) : 1;
    res.px[i * 4 + 3] = a * 255;
    for (let k = 0; k < 3; k++) {
      const c = img.px[i * 4 + k], b = bg[i * 3 + k];
      res.px[i * 4 + k] = a > 0.02 ? Math.max(0, Math.min(255, b + (c - b) / a)) : 0;
    }
  }
  return res;
}

// separa em faixas horizontais (um ícone por faixa), juntando os vãos menores até sobrar `count`
function bands(img, count) {
  const { w, h } = img, rows = [];
  for (let y = 0; y < h; y++) { let on = false; for (let x = 0; x < w; x++) if (img.px[(y * w + x) * 4 + 3] > 128) { on = true; break; } rows.push(on); }
  let segs = [];
  for (let y = 0; y < h; y++) if (rows[y]) { if (segs.length && segs[segs.length - 1][1] === y - 1) segs[segs.length - 1][1] = y; else segs.push([y, y]); }
  segs = segs.filter(([a, b]) => b - a >= 2);
  while (segs.length > count) {
    let bi = 0, bg = 1e9;
    for (let i = 0; i < segs.length - 1; i++) { const g = segs[i + 1][0] - segs[i][1]; if (g < bg) { bg = g; bi = i; } }
    segs.splice(bi, 2, [segs[bi][0], segs[bi + 1][1]]);
  }
  // limites de cada faixa: metade do vão até a vizinha
  return segs.map(([a, b], i) => [a, b, i ? Math.ceil((segs[i - 1][1] + a) / 2) : 0, i < segs.length - 1 ? Math.floor((b + segs[i + 1][0]) / 2) : h - 1]);
}

function cutBand(img, [y0, y1, lo, hi], pad, maxDim) {
  const { w } = img;
  let x0 = w, x1 = -1, ya = y1, yb = y0;
  const top = Math.max(0, lo ?? y0 - 12), bot = Math.min(img.h - 1, hi ?? y1 + 12);
  for (let y = top; y <= bot; y++) for (let x = 0; x < w; x++) {
    if (img.px[(y * w + x) * 4 + 3] > 20) { if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < ya) ya = y; if (y > yb) yb = y; }
  }
  const cw = x1 - x0 + 1 + pad * 2, ch = yb - ya + 1 + pad * 2;
  const crop = I.crop(img, x0 - pad, ya - pad, cw, ch);
  for (let j = 0; j < ch; j++) for (let i = 0; i < cw; i++) { const sx = x0 - pad + i, sy = ya - pad + j; if (sx < 0 || sy < 0 || sx >= w || sy >= img.h) crop.px[(j * cw + i) * 4 + 3] = 0; }
  const s = maxDim / Math.max(cw, ch);
  return I.resize(crop, Math.max(1, Math.round(cw * s)), Math.max(1, Math.round(ch * s)));
}

// centra num quadrado (ícones de botão e a seta, que gira em torno do centro)
function square(img, size) {
  const out = I.create(size, size);
  I.blit(out, img, Math.floor((size - img.w) / 2), Math.floor((size - img.h) / 2));
  return out;
}

// botões sobre o pano escuro do estandarte: cor mais viva e um filete de luz dourada em volta
// (o ícone encolhe para 112 de 128 para caber o brilho)
function vivid(img) {
  const S = img.w, inner = Math.round(S * 0.875), off = Math.floor((S - inner) / 2);
  const small = I.resize(img, inner, inner), base = I.create(S, S);
  I.blit(base, small, off, off);
  const N = S * S, a = new Float32Array(N);
  for (let i = 0; i < N; i++) a[i] = base.px[i * 4 + 3] / 255;
  // cor: brilho, contraste e saturação
  for (let i = 0; i < N; i++) {
    const d = i * 4; if (a[i] <= 0) continue;
    let r = base.px[d], g = base.px[d + 1], b = base.px[d + 2];
    const l = 0.299 * r + 0.587 * g + 0.114 * b;
    const sat = 1.35, gain = 1.28;
    r = l + (r - l) * sat; g = l + (g - l) * sat; b = l + (b - l) * sat;
    r = (r - 128) * 1.12 + 128; g = (g - 128) * 1.12 + 128; b = (b - 128) * 1.12 + 128;
    base.px[d] = Math.min(255, Math.max(0, r * gain)); base.px[d + 1] = Math.min(255, Math.max(0, g * gain)); base.px[d + 2] = Math.min(255, Math.max(0, b * gain));
  }
  // filete: dilata o contorno (forte) e um brilho largo e suave por fora
  const solid = new Float32Array(N); for (let i = 0; i < N; i++) solid[i] = a[i] > 0.5 ? 1 : 0;
  const ring = boxBlur(solid, S, S, 3), halo = boxBlur(boxBlur(solid, S, S, 5), S, S, 5);
  const out = I.create(S, S), GLOW = [255, 230, 165];
  for (let i = 0; i < N; i++) {
    const d = i * 4;
    const ga = Math.min(1, Math.min(1, ring[i] * 3.5) + halo[i] * 0.8);
    // brilho por baixo, ícone por cima
    const ia = a[i], ta = ia + ga * (1 - ia);
    for (let k = 0; k < 3; k++) out.px[d + k] = ta > 0 ? (base.px[d + k] * ia + GLOW[k] * ga * (1 - ia)) / ta : 0;
    out.px[d + 3] = ta * 255;
  }
  return out;
}

function save(name, img) {
  for (const d of OUT_DIRS) { fs.mkdirSync(d, { recursive: true }); I.writeTGA(path.join(d, name + ".tga"), img); }
  I.writePNG(path.join(PREV, name + ".png"), img);
}

const sizes = {};
// botões: espadas, setas, pergaminho, picareta, engrenagem, livro, bússola
{
  const m = matte(readPNG(path.join(SRC, "botoes.png")), { thrA: 22, thrB: 55, soft: 50 });
  const names = ["ExpBtnClose", "ExpBtnMax", "ExpBtnQuests", "ExpBtnGather", "ExpBtnSettings", "ExpBtnLore", "ExpBtnCenter"];
  const segs = bands(m, names.length);
  segs.forEach((s, i) => { const ic = vivid(square(cutBand(m, s, 4, 128), 128)); save(names[i], ic); sizes[names[i]] = [128, 128]; });
}
// filtro (fundo escuro; a primeira linha tem um resto de letra)
{
  const src = readPNG(path.join(SRC, "filtro32.png"));
  const img = I.crop(src, 0, 12, src.w, src.h - 12);
  const m = matte(img, { thrA: 26, thrB: 34, soft: 40 });
  const ic = vivid(square(cutBand(m, [0, m.h - 1], 3, 128), 128));
  save("ExpBtnFilter", ic); sizes.ExpBtnFilter = [128, 128];
}
// mapa: seta do jogador, pino de missão, ?, !, ! azul
{
  const m = matte(readPNG(path.join(SRC, "pins.png")), { thrA: 22, thrB: 55, soft: 50 });
  const names = ["ExpPlayerArrow", "ExpPinQuest", "ExpPinTurnIn", "ExpPinNew", "ExpPinRepeat"];
  const segs = bands(m, names.length);
  segs.forEach((s, i) => {
    let ic = cutBand(m, s, 4, 128);
    if (i === 0) ic = square(ic, 128);
    save(names[i], ic); sizes[names[i]] = [ic.w, ic.h];
  });
}
fs.writeFileSync(path.join(PREV, "sizes.json"), JSON.stringify(sizes, null, 1));

// folha de conferência: cada ícone sobre o papel do mar e sobre fundo escuro
{
  const list = Object.keys(sizes), cell = 150, sheet = I.create(cell * list.length, cell * 2);
  const paper = [176, 140, 88], dark = [24, 22, 20];
  for (let y = 0; y < sheet.h; y++) for (let x = 0; x < sheet.w; x++) { const c = y < cell ? paper : dark, d = (y * sheet.w + x) * 4; sheet.px[d] = c[0]; sheet.px[d + 1] = c[1]; sheet.px[d + 2] = c[2]; sheet.px[d + 3] = 255; }
  list.forEach((n, k) => {
    const ic = readPNG(path.join(PREV, n + ".png"));
    for (const row of [0, 1]) for (let j = 0; j < ic.h; j++) for (let i = 0; i < ic.w; i++) {
      const s = (j * ic.w + i) * 4, a = ic.px[s + 3] / 255, x = k * cell + 11 + i, y = row * cell + 11 + j, d = (y * sheet.w + x) * 4;
      for (let c = 0; c < 3; c++) sheet.px[d + c] = sheet.px[d + c] * (1 - a) + ic.px[s + c] * a;
    }
  });
  I.writePNG(path.join(DIR, "out", "icons_sheet.png"), sheet);
}
console.log(JSON.stringify(sizes));
