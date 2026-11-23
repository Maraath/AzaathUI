// Efeitos do feitiço selecionado, tirados da arte de conceito fx-concept.webp
// (convertida em fx-concept.png pelo Edge sem janela, como a concept.png):
//   GrimRuneSeal    selo rúnico ciano em volta do medalhão selecionado (página esquerda)
//   GrimIconRing    aro incandescente em volta do ícone no diagrama (página direita)
//   GrimDiagramGlow o diagrama aceso em ciano (estrela, círculo interno, símbolos),
//                   gerado a partir do GrimDiagram para casar com as linhas de tinta
// A luz é separada do pergaminho por "matte" mínimo: para cada pixel, o menor alfa
// que explica a cor da arte sobre o papel estimado por baixo (cor = papel + Δ/alfa).
// Tinta escura (nomes, linhas) fica de fora: só entra o que é azulado ou mais claro.
// Uso: node tools/grimoire-concept/gen-fx.js
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("./png");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Grimoire");
const PREV = path.join(__dirname, "preview");
const src = readPNG(path.join(__dirname, "fx-concept.png"));
const W = src.w;
const px = (x, y) => { x = Math.max(0, Math.min(W - 1, Math.round(x))); y = Math.max(0, Math.min(src.h - 1, Math.round(y))); const o = (y * W + x) * 4; return [src.px[o], src.px[o + 1], src.px[o + 2]]; };
const lum = (c) => 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2];
// amostra bilinear
function bil(x, y) {
  const x0 = Math.floor(x), y0 = Math.floor(y), tx = x - x0, ty = y - y0;
  const a = px(x0, y0), b = px(x0 + 1, y0), c = px(x0, y0 + 1), d = px(x0 + 1, y0 + 1);
  return [0, 1, 2].map((k) => (a[k] * (1 - tx) + b[k] * tx) * (1 - ty) + (c[k] * (1 - tx) + d[k] * tx) * ty);
}

// Papel por baixo do efeito: média, por ângulo, de um anel limpo logo fora dele
function paperRing(cx, cy, r0, r1) {
  const bins = 72, acc = [];
  for (let b = 0; b < bins; b++) {
    let s = [0, 0, 0], n = 0;
    for (let k = -2; k <= 2; k++) {
      const a = ((b + k / 5) / bins) * 2 * Math.PI;
      for (let r = r0; r <= r1; r += 1.5) {
        const c = px(cx + Math.cos(a) * r, cy + Math.sin(a) * r);
        if (lum(c) < 150 || c[2] - c[0] > 0) continue;       // ignora tinta e luz
        s[0] += c[0]; s[1] += c[1]; s[2] += c[2]; n++;
      }
    }
    acc.push(n ? s.map((v) => v / n) : null);
  }
  const avg = [0, 1, 2].map((k) => { let s = 0, n = 0; for (const c of acc) if (c) { s += c[k]; n++; } return s / n; });
  for (let b = 0; b < bins; b++) if (!acc[b]) acc[b] = avg;
  return (x, y) => {
    const a = (Math.atan2(y - cy, x - cx) / (2 * Math.PI) + 1) % 1 * bins, b0 = Math.floor(a) % bins, b1 = (b0 + 1) % bins, t = a - Math.floor(a);
    return [0, 1, 2].map((k) => acc[b0][k] * (1 - t) + acc[b1][k] * t);
  };
}

// Matte mínimo: menor alfa tal que cor = papel + (arte - papel)/alfa fique em 0..255
function matte(o, p) {
  let a = 0;
  for (let k = 0; k < 3; k++) {
    const d = o[k] - p[k];
    if (d > 0) a = Math.max(a, d / Math.max(1, 255 - p[k]));
    else if (d < 0) a = Math.max(a, -d / Math.max(1, p[k]));
  }
  a = Math.min(1, a);
  if (a < 0.02) return [0, 0, 0, 0];
  return [...[0, 1, 2].map((k) => Math.max(0, Math.min(255, p[k] + (o[k] - p[k]) / a))), a];
}

// Extrai um anel de efeito (centro cx,cy; raios rIn..rOut na arte) para uma textura
// N x N que cobre raio rOut; "fadeIn" suaviza a borda de dentro.
function extractRing(cx, cy, rIn, rOut, N, paper, fadeIn = 3) {
  const out = I.create(N, N), sc = (2 * rOut) / N;
  for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) {
    const x = cx - rOut + (i + 0.5) * sc, y = cy - rOut + (j + 0.5) * sc, r = Math.hypot(x - cx, y - cy);
    if (r < rIn - fadeIn || r > rOut) continue;
    const o = bil(x, y), p = paper(x, y);
    const bluish = o[2] - o[0] > 6 || lum(o) > lum(p) + 6;
    if (!bluish) continue;                                   // tinta escura: fica de fora
    // nomes escritos sob o selo ("Atacar", "5 Feitiços"): ali só entra ciano forte
    const inText = (x > 160 && x < 250 && y > 262 && y < 298) || (x > 210 && x < 320 && y > 76 && y < 100);
    if (inText && o[2] - o[0] < 70) continue;
    const m = matte(o, p);
    let k = Math.min(1, (r - (rIn - fadeIn)) / fadeIn) * Math.min(1, (rOut - r) / 4);
    const q = (j * N + i) * 4;
    out.px[q] = m[0]; out.px[q + 1] = m[1]; out.px[q + 2] = m[2]; out.px[q + 3] = 255 * m[3] * k;
  }
  return out;
}

// 1) Selo rúnico (medalhão "Atacar" no conceito: centro 220,190; aro de bronze r≈52)
const SEAL = { cx: 220, cy: 190, rIn: 50, rOut: 110 };
const seal = extractRing(SEAL.cx, SEAL.cy, SEAL.rIn, SEAL.rOut, 256, paperRing(SEAL.cx, SEAL.cy, 112, 122));

// 2) Aro do ícone no diagrama (conceito: centro 1020,300; ícone r≈52)
const RING = { cx: 1020, cy: 300, rIn: 53, rOut: 88 };
const paperFlat = (() => { const c = [0, 0, 0]; let n = 0; for (let y = 455; y < 475; y++) for (let x = 1130; x < 1170; x++) { const p = px(x, y); c[0] += p[0]; c[1] += p[1]; c[2] += p[2]; n++; } return () => c.map((v) => v / n); })();
const iconRing = extractRing(RING.cx, RING.cy, RING.rIn, RING.rOut, 128, paperFlat, 2);

// 3) Diagrama aceso: linhas internas do GrimDiagram (sem o anel externo e o texto rúnico)
function readTGA(f) {
  const b = fs.readFileSync(f), w = b.readUInt16LE(12), h = b.readUInt16LE(14), top = (b[17] & 0x20) !== 0, im = I.create(w, h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const s = 18 + ((top ? y : h - 1 - y) * w + x) * 4, o = (y * w + x) * 4; im.px[o] = b[s + 2]; im.px[o + 1] = b[s + 1]; im.px[o + 2] = b[s]; im.px[o + 3] = b[s + 3]; }
  return im;
}
const diag = readTGA(path.join(OUT, "GrimDiagram.tga"));
// centro do diagrama dentro da caixa (755,230): (866,333) -> (111,103); anel externo começa em r≈90
const DC = [111, 103];
// símbolos do anel (centros na caixa): acendem como na arte; anel externo e runas escritas não
const SYMS = [[106, 26], [178, 65], [182, 144], [115, 180], [40, 142], [40, 62]];
const lineA = new Float32Array(256 * 256);
for (let y = 0; y < 256; y++) for (let x = 0; x < 256; x++) {
  const dx = (x - DC[0]) / 1.0, dy = (y - DC[1]) / 0.95, r = Math.hypot(dx, dy);
  let keep = Math.max(0, Math.min(1, (71 - r) / 3));         // estrela e círculo interno
  for (const [sx, sy] of SYMS) keep = Math.max(keep, Math.max(0, Math.min(1, (14 - Math.hypot(x - sx, y - sy)) / 2)));
  lineA[y * 256 + x] = (diag.px[(y * 256 + x) * 4 + 3] / 255) * keep;
}
const blur = (a, rad) => {
  const t = new Float32Array(a.length), o = new Float32Array(a.length);
  for (let y = 0; y < 256; y++) for (let x = 0; x < 256; x++) { let s = 0, n = 0; for (let k = -rad; k <= rad; k++) { const xx = x + k; if (xx >= 0 && xx < 256) { s += a[y * 256 + xx]; n++; } } t[y * 256 + x] = s / n; }
  for (let y = 0; y < 256; y++) for (let x = 0; x < 256; x++) { let s = 0, n = 0; for (let k = -rad; k <= rad; k++) { const yy = y + k; if (yy >= 0 && yy < 256) { s += t[yy * 256 + x]; n++; } } o[y * 256 + x] = s / n; }
  return o;
};
const halo = blur(blur(lineA, 3), 3);
const CORE = [190, 250, 255], GLOW = [70, 205, 245];
const diagGlow = I.create(256, 256);
for (let i = 0; i < 256 * 256; i++) {
  const l = Math.min(1, lineA[i] * 1.4), g = Math.min(1, halo[i] * 2.6) * 0.75;
  const a = Math.max(l, g);
  if (a <= 0.01) continue;
  const t = l / a;
  diagGlow.px[i * 4] = GLOW[0] * (1 - t) + CORE[0] * t; diagGlow.px[i * 4 + 1] = GLOW[1] * (1 - t) + CORE[1] * t;
  diagGlow.px[i * 4 + 2] = GLOW[2] * (1 - t) + CORE[2] * t; diagGlow.px[i * 4 + 3] = 255 * a;
}

for (const [name, im] of [["GrimRuneSeal", seal], ["GrimIconRing", iconRing], ["GrimDiagramGlow", diagGlow]]) {
  I.writeTGA(path.join(OUT, name + ".tga"), im);
  // prévia sobre pergaminho
  const pv = I.create(im.w, im.h, 222, 204, 170, 255);
  for (let i = 0; i < im.w * im.h; i++) { const a = im.px[i * 4 + 3] / 255; for (let k = 0; k < 3; k++) pv.px[i * 4 + k] = pv.px[i * 4 + k] * (1 - a) + im.px[i * 4 + k] * a; }
  I.writePNG(path.join(PREV, name + ".png"), pv);
  console.log("gerado", name, im.w + "x" + im.h);
}
// escalas para o Lua: raio externo do efeito / raio de referência no conceito
console.log("selo: textura cobre r", SEAL.rOut, "do conceito; aro de bronze do conceito r 52 (no jogo, r 38)");
console.log("aro do ícone: cobre r", RING.rOut, "do conceito; ícone do conceito r 52 (no jogo, r 31)");
