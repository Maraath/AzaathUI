// Gera as texturas da aba de Talentos (O Crisol de Azaath) a partir da arte de
// conceito tools/talents-concept/crucible.png (1376x768, convertida de
// concept_azaath_crucible.jpg). O gerador anterior (astrolábio) ficou em
// gen-astrolabe-old.js.
//
// O que sai daqui (Media/Talents/):
//   CrucibleBG          fundo: céu, núcleo de cristal, frasco, painel e botões,
//                       sem os medalhões/correntes/textos pintados (o jogo
//                       desenha os talentos reais por cima)
//   CrucibleRings       atlas 512x256 (8 células 128x128) com os aros reais dos
//                       medalhões da arte: ouro/brasa/ciano/apagado, simples e
//                       ornamentado. Em toda célula o miolo (ícone) tem raio 30.
//   CrucibleStream      corrente de energia trançada (branca, emendável na
//                       horizontal) para as ligações; o jogo tinge e faz correr
//   CrucibleStreamGlow  halo largo das correntes
//   CrucibleRune        brilho do círculo rúnico do painel (pulsa)
//   CrucibleBtnSeal     botão "SELAR INFUSÃO" aceso (o fundo leva a versão apagada)
//
// Uso: node tools/talents-concept/gen.js

const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const OUT_WS = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Talents");
const OUT_GAME = "C:\\Program Files (x86)\\World of Warcraft\\_forever_\\Interface\\AddOns\\AzaathUI\\Media\\Talents";
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(OUT_WS, { recursive: true });
try { fs.mkdirSync(OUT_GAME, { recursive: true }); } catch (e) {}
fs.mkdirSync(PREV, { recursive: true });

// PRNG determinístico (o resultado não muda a cada execução)
let seed = 1234567;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };

const src = readPNG(path.join(__dirname, "crucible.png"));
require("./rename-arc")(src); // "NÚCLEO PRIMORDIAL DE AZAATH" no arco do núcleo
const W = src.w, H = src.h;
const clone = (im) => ({ w: im.w, h: im.h, px: Float32Array.from(im.px) });
const img = clone(src);
const snapshot = clone(src);
const get = (im, x, y) => {
  x = Math.max(0, Math.min(im.w - 1, Math.round(x)));
  y = Math.max(0, Math.min(im.h - 1, Math.round(y)));
  const o = (y * im.w + x) * 4;
  return [im.px[o], im.px[o + 1], im.px[o + 2]];
};
const bil = (im, x, y) => {
  x = Math.max(0, Math.min(im.w - 1.001, x)); y = Math.max(0, Math.min(im.h - 1.001, y));
  const xi = Math.floor(x), yi = Math.floor(y), tx = x - xi, ty = y - yi;
  return [0, 1, 2].map((k) => {
    const p = (xx, yy) => im.px[(yy * im.w + xx) * 4 + k];
    return (p(xi, yi) * (1 - tx) + p(xi + 1, yi) * tx) * (1 - ty) + (p(xi, yi + 1) * (1 - tx) + p(xi + 1, yi + 1) * tx) * ty;
  });
};
const set = (im, x, y, c) => {
  if (x < 0 || y < 0 || x >= im.w || y >= im.h) return;
  const o = (y * im.w + x) * 4;
  im.px[o] = c[0]; im.px[o + 1] = c[1]; im.px[o + 2] = c[2];
};
const lumC = (c) => 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2];
const lum = (im, x, y) => lumC(get(im, x, y));
const clamp01 = (v) => Math.max(0, Math.min(1, v));

// ---------------------------------------------------------------------------
// Máscara + preenchimento por difusão (mesma técnica dos outros geradores)
// ---------------------------------------------------------------------------
let MASK = new Uint8Array(W * H);
const M = (x, y) => MASK[y * W + x];
function markRect(x0, y0, x1, y1) {
  for (let y = Math.max(0, y0); y <= Math.min(H - 1, y1); y++)
    for (let x = Math.max(0, x0); x <= Math.min(W - 1, x1); x++) MASK[y * W + x] = 1;
}
function markCircle(cx, cy, r) {
  for (let y = Math.floor(cy - r); y <= Math.ceil(cy + r); y++)
    for (let x = Math.floor(cx - r); x <= Math.ceil(cx + r); x++)
      if (x >= 0 && y >= 0 && x < W && y < H && Math.hypot(x - cx, y - cy) <= r) MASK[y * W + x] = 1;
}
function dilateMask(r) {
  for (let k = 0; k < r; k++) {
    const nx = Uint8Array.from(MASK);
    for (let y = 1; y < H - 1; y++) for (let x = 1; x < W - 1; x++) if (MASK[y * W + x]) {
      nx[y * W + x - 1] = nx[y * W + x + 1] = nx[(y - 1) * W + x] = nx[(y + 1) * W + x] = 1;
    }
    MASK = nx;
  }
}
function fill(x0, y0, x1, y1, grain = 0, iters = 220) {
  x0 = Math.max(0, x0); y0 = Math.max(0, y0); x1 = Math.min(W - 1, x1); y1 = Math.min(H - 1, y1);
  const pts = [];
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) if (M(x, y)) pts.push(y * W + x);
  if (!pts.length) return [];
  const known = new Uint8Array(W * H);
  for (let i = 0; i < W * H; i++) known[i] = MASK[i] ? 0 : 1;
  for (const r of [4, 8, 16, 32, 64, 128, 256]) {
    for (const p of pts) {
      if (known[p] === 2) continue;
      const px = p % W, py = (p / W) | 0;
      let s0 = 0, s1 = 0, s2 = 0, n = 0;
      const st = Math.max(1, r >> 2);
      for (let dy = -r; dy <= r; dy += st) for (let dx = -r; dx <= r; dx += st) {
        const x = px + dx, y = py + dy;
        if (x < 0 || y < 0 || x >= W || y >= H || known[y * W + x] !== 1) continue;
        const wgt = 1 / (1 + dx * dx + dy * dy);
        const c = get(img, x, y); s0 += c[0] * wgt; s1 += c[1] * wgt; s2 += c[2] * wgt; n += wgt;
      }
      if (n > 0) { set(img, px, py, [s0 / n, s1 / n, s2 / n]); known[p] = 2; }
    }
  }
  for (let it = 0; it < iters; it++) for (const p of pts) {
    const x = p % W, y = (p / W) | 0;
    if (x < 1 || y < 1 || x >= W - 1 || y >= H - 1) continue;
    const a = get(img, x - 1, y), b = get(img, x + 1, y), c = get(img, x, y - 1), d = get(img, x, y + 1);
    set(img, x, y, [0, 1, 2].map((k) => (a[k] + b[k] + c[k] + d[k]) / 4));
  }
  if (grain) for (const p of pts) {
    const n = (rnd() + rnd() + rnd() - 1.5) * grain;
    const x = p % W, y = (p / W) | 0, c = get(img, x, y);
    set(img, x, y, [c[0] + n, c[1] + n * 0.95, c[2] + n * 1.05]);
  }
  for (const p of pts) MASK[p] = 0;
  return pts;
}
// Faixa de texto sobre fundo liso: interpola verticalmente entre a linha acima e a abaixo
function cleanBand(x0, y0, x1, y1, noise = 1.0) {
  const topY = y0 - 1, botY = y1 + 1;
  for (let x = x0; x <= x1; x++) {
    const topC = [0, 1, 2].map((k) => (get(img, x, topY)[k] + get(img, x, topY - 1)[k]) * 0.5);
    const botC = [0, 1, 2].map((k) => (get(img, x, botY)[k] + get(img, x, botY + 1)[k]) * 0.5);
    for (let y = y0; y <= y1; y++) {
      const t = (y - y0 + 1) / (y1 - y0 + 2);
      const ex = clamp01(Math.min(x - x0, x1 - x) / 4);
      const n = (rnd() - 0.5) * noise;
      const o = get(img, x, y);
      const f = [0, 1, 2].map((k) => topC[k] * (1 - t) + botC[k] * t + n);
      set(img, x, y, [0, 1, 2].map((k) => f[k] * ex + o[k] * (1 - ex)));
    }
  }
}
// Interior de pílula/botão: copia uma coluna limpa da própria peça (preserva o degradê)
function cleanPill(x0, y0, x1, y1, refX) {
  for (let y = y0; y <= y1; y++) {
    const refC = [0, 1, 2].map((k) => (get(img, refX, y)[k] + get(img, refX + 1, y)[k]) * 0.5);
    for (let x = x0; x <= x1; x++) {
      const a = clamp01(Math.min(x - x0, x1 - x) / 3);
      const o = get(img, x, y);
      set(img, x, y, [0, 1, 2].map((k) => refC[k] * a + o[k] * (1 - a)));
    }
  }
}

// Fundo "baixo" local: percentil 25 da luminância em blocos de 16px (janela 48px),
// interpolado. Serve para achar o que brilha acima do céu (correntes, medalhões).
const BS = 16, GW = Math.ceil(W / BS), GH = Math.ceil(H / BS);
const lowGrid = new Float32Array(GW * GH);
for (let gy = 0; gy < GH; gy++) for (let gx = 0; gx < GW; gx++) {
  const vals = [];
  for (let y = gy * BS - BS; y < gy * BS + 2 * BS; y += 2) for (let x = gx * BS - BS; x < gx * BS + 2 * BS; x += 2) {
    if (x < 0 || y < 0 || x >= W || y >= H) continue;
    vals.push(lum(snapshot, x, y));
  }
  vals.sort((a, b) => a - b);
  lowGrid[gy * GW + gx] = vals[Math.floor(vals.length * 0.25)] || 0;
}
const bgLow = (x, y) => {
  const fx = Math.max(0, Math.min(GW - 1.001, x / BS - 0.5)), fy = Math.max(0, Math.min(GH - 1.001, y / BS - 0.5));
  const xi = Math.floor(fx), yi = Math.floor(fy), tx = fx - xi, ty = fy - yi;
  const g = (a, b) => lowGrid[Math.min(GH - 1, b) * GW + Math.min(GW - 1, a)];
  return (g(xi, yi) * (1 - tx) + g(xi + 1, yi) * tx) * (1 - ty) + (g(xi, yi + 1) * (1 - tx) + g(xi + 1, yi + 1) * tx) * ty;
};

// ---------------------------------------------------------------------------
// 1. Aros dos medalhões (antes de qualquer limpeza)
//    [nome, cx, cy, raio do miolo, raio do aro, ornamentado]
// ---------------------------------------------------------------------------
const RINGS = [
  ["goldOrnate", 136, 212.5, 29, 38, true],
  ["gold",       327.5, 231, 23, 31, false],
  ["emberOrnate", 313, 555, 23, 31, true],
  ["ember",      419.5, 559.5, 20.5, 28, false],
  ["cyanOrnate", 854.5, 202, 29, 36, true],
  ["cyan",       853, 407, 22, 32, false],
  ["darkOrnate", 637, 633, 23, 30, true],
  ["dark",       381, 669, 23, 30, false],
];
const CELL = 128, CR = 30; // raio do miolo dentro da célula
// Pontas dos aros ornamentados: quantas, comprimento e meia-largura (graus).
// Todas copiam a ponta de cima (a única limpa de correntes em todos eles).
const SPIKES = {
  goldOrnate: { n: 4, len: 10, w: 13 },
  emberOrnate: { n: 4, len: 10, w: 13 },
  cyanOrnate: { n: 8, len: 17, w: 15 },
  darkOrnate: { n: 4, len: 10, w: 13 },
};
const ringsAtlas = I.create(512, 256);
RINGS.forEach(([name, cx, cy, disk, rim, ornate], idx) => {
  const ox = (idx % 4) * CELL, oy = Math.floor(idx / 4) * CELL;
  const sc = disk / CR;
  // anel em coordenadas polares; ângulos tomados por correntes (muito mais
  // claros que a mediana do mesmo raio) são refeitos com os vizinhos limpos
  const NA = 720, r0 = disk - 1.5, r1 = rim + 2.5, RS = 0.5;
  const NR = Math.ceil((r1 - r0) / RS) + 1;
  const P = [];
  for (let ri = 0; ri < NR; ri++) {
    const r = r0 + ri * RS, row = [];
    for (let ai = 0; ai < NA; ai++) {
      const t = (ai / NA) * 2 * Math.PI;
      row.push(bil(snapshot, cx + r * Math.cos(t), cy + r * Math.sin(t)));
    }
    const ls = row.map(lumC).slice().sort((a, b) => a - b);
    const med = ls[NA >> 1];
    const bad = row.map((c) => {
      const mx = Math.max(...c), mn = Math.min(...c), sat = mx > 0 ? (mx - mn) / mx : 0;
      return lumC(c) > med * 1.3 + 14 || (sat > 0.6 && lumC(c) > med + 10);
    });
    // alarga um pouco os trechos ruins (halo da corrente)
    const bad2 = bad.slice();
    for (let ai = 0; ai < NA; ai++) if (bad[ai]) for (let k = -6; k <= 6; k++) bad2[(ai + k + NA) % NA] = true;
    if (bad2.some((v) => !v)) {
      for (let ai = 0; ai < NA; ai++) if (bad2[ai]) {
        let a = 1, b = 1;
        while (bad2[(ai + a) % NA]) a++;
        while (bad2[(ai - b + NA) % NA]) b++;
        const ca = row[(ai + a) % NA], cb = row[(ai - b + NA) % NA], t = b / (a + b);
        row[ai] = [0, 1, 2].map((k) => ca[k] * t + cb[k] * (1 - t));
      }
    }
    P.push(row);
  }
  const polar = (r, t) => {
    const fr = Math.max(0, Math.min(NR - 1.001, (r - r0) / RS));
    let fa = ((t / (2 * Math.PI)) * NA) % NA; if (fa < 0) fa += NA;
    const ri = Math.floor(fr), ai = Math.floor(fa), tr = fr - ri, ta = fa - ai;
    const g = (R, A) => P[R][A % NA];
    return [0, 1, 2].map((k) =>
      (g(ri, ai)[k] * (1 - ta) + g(ri, ai + 1)[k] * ta) * (1 - tr) + (g(ri + 1, ai)[k] * (1 - ta) + g(ri + 1, ai + 1)[k] * ta) * tr);
  };
  const sp = SPIKES[name];
  const TOP = -Math.PI / 2;
  for (let j = 0; j < CELL; j++) for (let i = 0; i < CELL; i++) {
    const dx = (i + 0.5 - CELL / 2) * sc, dy = (j + 0.5 - CELL / 2) * sc;
    const d = Math.hypot(dx, dy), th = Math.atan2(dy, dx);
    let c, a;
    if (d <= rim + 1.6) {
      c = polar(d, th);
      a = clamp01((d - (disk - 1.0)) / 1.2) * clamp01((rim + 1.6 - d) / 1.1);
    } else {
      c = [0, 0, 0]; a = 0;
    }
    if (ornate && d > rim - 1) {
      // ponta mais próxima e o desvio angular até ela
      const step = (2 * Math.PI) / sp.n;
      let rel = th - TOP; rel = ((rel % step) + step * 1.5) % step - step / 2;
      const degOff = Math.abs(rel) * 180 / Math.PI;
      const lim = rim + sp.len * (1 - degOff / sp.w);
      if (degOff < sp.w && d <= lim + 1.5) {
        const t = TOP + rel, sx = cx + d * Math.cos(t), sy = cy + d * Math.sin(t);
        const cs = bil(snapshot, sx, sy);
        const k = name === "darkOrnate" || name === "emberOrnate" ? 20 : 40;
        const al = clamp01((lumC(cs) - bgLow(sx, sy) - 4) / k) * clamp01((lim + 1.5 - d) / 1.5);
        if (al > a) { c = cs; a = al; }
      }
    }
    const o = ((oy + j) * 512 + ox + i) * 4;
    ringsAtlas.px[o] = c[0]; ringsAtlas.px[o + 1] = c[1]; ringsAtlas.px[o + 2] = c[2]; ringsAtlas.px[o + 3] = 255 * a;
  }
});

// ---------------------------------------------------------------------------
// 2. Brilho do círculo rúnico do painel (centro 1190, 352.5)
// ---------------------------------------------------------------------------
const RCX = 1190, RCY = 352.5;
const rune = I.create(256, 256);
for (let j = 0; j < 256; j++) for (let i = 0; i < 256; i++) {
  const x = RCX - 128 + i + 0.5, y = RCY - 128 + j + 0.5;
  const r = Math.hypot(i + 0.5 - 128, j + 0.5 - 128);
  if (r < 56 || r > 112) continue;
  if (y < 256) continue; // acima: título e grau
  const c = bil(snapshot, x, y);
  const excess = Math.max(0, c[1] - 40, c[2] - 55);
  let a = Math.min(1, excess / 150) * clamp01((r - 56) / 4) * clamp01((112 - r) / 5);
  if (a < 0.03) continue;
  const o = (j * 256 + i) * 4;
  rune.px[o] = Math.min(255, c[0] * 1.1); rune.px[o + 1] = Math.min(255, c[1] * 1.15); rune.px[o + 2] = Math.min(255, c[2] * 1.2);
  rune.px[o + 3] = 255 * a;
}

// ---------------------------------------------------------------------------
// 3. Botão "SELAR INFUSÃO" aceso: recorte com o halo (o texto sai depois)
// ---------------------------------------------------------------------------
const SEAL = { x: 1176, y: 648, w: 192, h: 66 };
// texto do botão aceso (x 1210..1325, y 672..691): copia coluna interna
{
  const tmp = clone(img);
  const keep = img.px; img.px = tmp.px;
  cleanPill(1206, 671, 1330, 692, 1203);
  img.px = keep;
  const out = I.create(256, 128);
  for (let j = 0; j < SEAL.h; j++) for (let i = 0; i < SEAL.w; i++) {
    const c = get(tmp, SEAL.x + i, SEAL.y + j);
    const L = lumC(c), bgL = 16;
    // halo: alfa pela luz acima do céu; dentro da caixa, opaco
    const inBox = (SEAL.x + i) >= 1197 && (SEAL.x + i) <= 1337 && (SEAL.y + j) >= 665 && (SEAL.y + j) <= 697;
    const a = inBox ? 1 : clamp01((Math.max(c[1], c[2]) - 30) / 110);
    const o = (j * 256 + i) * 4;
    out.px[o] = c[0]; out.px[o + 1] = c[1]; out.px[o + 2] = c[2]; out.px[o + 3] = 255 * a;
  }
  var btnSeal = out;
}

// ---------------------------------------------------------------------------
// 4. Corrente trançada (256x64, emenda na horizontal) e o halo dela (64x64)
// ---------------------------------------------------------------------------
const stream = I.create(256, 64);
{
  const strands = [
    { amp: 9, k: 1, ph: 0.0, w: 1.6, b: 1.0 },
    { amp: 7, k: 2, ph: 2.1, w: 1.2, b: 0.9 },
    { amp: 11, k: 1, ph: 3.7, w: 1.0, b: 0.75 },
    { amp: 5, k: 3, ph: 1.2, w: 0.9, b: 0.7 },
    { amp: 13, k: 2, ph: 4.9, w: 0.7, b: 0.5 },
    { amp: 3, k: 4, ph: 0.6, w: 1.4, b: 0.85 },
  ];
  const acc = new Float32Array(256 * 64);
  for (let i = 0; i < 256; i++) {
    const u = i / 256;
    for (const s of strands) {
      const yc = 32 + s.amp * Math.sin(2 * Math.PI * s.k * u + s.ph) + 2 * Math.sin(2 * Math.PI * (s.k + 3) * u + s.ph * 2);
      // brilho varia ao longo do fio (pulsos de energia)
      const pulse = 0.65 + 0.35 * Math.sin(2 * Math.PI * (s.k + 1) * u + s.ph * 1.7);
      for (let j = 0; j < 64; j++) {
        const d = Math.abs(j + 0.5 - yc);
        const core = Math.exp(-(d * d) / (2 * s.w * s.w));
        const halo = Math.exp(-(d * d) / (2 * (s.w * 4.5) * (s.w * 4.5))) * 0.42;
        acc[j * 256 + i] += (core + halo) * s.b * pulse;
      }
    }
  }
  for (let j = 0; j < 64; j++) for (let i = 0; i < 256; i++) {
    const v = acc[j * 256 + i];
    const edge = clamp01(Math.min(j, 63 - j) / 6);
    const a = clamp01(v * 1.2) * edge;
    const o = (j * 256 + i) * 4;
    const hot = clamp01(v - 0.9); // miolo quente fica mais branco
    stream.px[o] = 255; stream.px[o + 1] = 255; stream.px[o + 2] = 255;
    stream.px[o + 3] = 255 * Math.min(1, a + hot * 0.2);
  }
}
const streamGlow = I.create(64, 64);
for (let j = 0; j < 64; j++) for (let i = 0; i < 64; i++) {
  const d = Math.abs(j + 0.5 - 32) / 32;
  const a = Math.exp(-d * d * 5.5) * clamp01((1 - d) * 3);
  const o = (j * 64 + i) * 4;
  streamGlow.px[o] = 255; streamGlow.px[o + 1] = 255; streamGlow.px[o + 2] = 255; streamGlow.px[o + 3] = 255 * a;
}

// ---------------------------------------------------------------------------
// 5. Limpeza do fundo
// ---------------------------------------------------------------------------
const CORE = { x: 528, y: 402, r: 128 };
const inCore = (x, y) => Math.hypot(x - CORE.x, y - CORE.y) < CORE.r;
const starPts = [];
const remember = (pts) => { for (const p of pts) starPts.push(p); };

// 5a) Cabeçalho (retrato, nome, abas, poder de item): a ficha desenha o dela
markRect(0, 0, W - 1, 96);
markRect(20, 96, 150, 140);
markRect(1236, 96, 1360, 146);
dilateMask(1);
remember(fill(0, 0, W - 1, 150, 1.2, 160));

// 5b) Rodapé (textos)
markRect(24, 738, 470, 762);
markRect(1240, 738, 1350, 762);
remember(fill(0, 730, W - 1, H - 1, 0.8, 160));

// 5c) Medalhões, correntes e rótulos das três árvores
const TREE_BOXES = [
  [80, 128, 425, 440],   // Armas
  [262, 440, 705, 728],  // Fúria
  [636, 128, 1012, 664], // Proteção
];
for (const [x0, y0, x1, y1] of TREE_BOXES) {
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    if (inCore(x, y)) continue;
    const c = get(snapshot, x, y);
    const L = lumC(c), b = bgLow(x, y);
    const mx = Math.max(c[0], c[1], c[2]), mn = Math.min(c[0], c[1], c[2]);
    const sat = mx > 0 ? (mx - mn) / mx : 0;
    if (L > b + 16 || (sat > 0.45 && L > b + 7 && mx > 60)) MASK[y * W + x] = 1;
  }
}
// medalhões inteiros (inclui as partes escuras dos aros apagados)
for (const [cx, cy, r] of [
  [136, 212.5, 47], [327.5, 231, 34], [254, 281, 34], [274, 384, 34],
  [313, 555, 45], [419.5, 559.5, 32], [537, 600, 32], [637, 633, 42], [381, 669, 35], [525.5, 684, 32],
  [854.5, 202, 54], [759.5, 293, 37], [853, 308.5, 29], [934.5, 294.5, 29], [934.5, 382.5, 37],
  [853, 407, 36], [771, 472.5, 29], [934.5, 472.5, 29], [853, 551, 43], [853, 609, 29],
]) markCircle(cx, cy, r);
// rastros escuros (fumaça) das correntes apagadas da Fúria
for (let y = 560; y <= 720; y++) for (let x = 560; x <= 700; x++) {
  const c = get(snapshot, x, y), b = bgLow(x, y);
  if (lumC(c) < b - 6) MASK[y * W + x] = 1;
}
markRect(134, 136, 262, 158);  // ARMAS - 14 PTS
markRect(180, 504, 292, 528);  // FÚRIA - 8 PTS
markRect(778, 128, 934, 152);  // PROTEÇÃO - 21 PTS
dilateMask(4);
for (let i = 0; i < W * H; i++) if (MASK[i] && inCore(i % W, (i / W) | 0)) MASK[i] = 0;
remember(fill(60, 120, 1020, 735, 1.4, 260));

// 5d) Textos do frasco ("12 ESSÊNCIAS DE AZAATH" / "• ESPECIALIZAÇÃO PRINCIPAL")
markRect(486, 172, 676, 210);
dilateMask(1);
fill(470, 160, 690, 222, 1.0, 200);

// 5e) Painel do talento
cleanBand(1074, 195, 1308, 209);   // — PROTEÇÃO • TALENTO PRIMORDIAL —
cleanBand(1052, 213, 1328, 237);   // ÉGIDE DA CORRENTE DE AZAATH
cleanBand(1146, 238, 1234, 252);   // ◆ GRAU 2 / 3
// emblema central (escudo e cristais): vira um poço escuro; o jogo põe o ícone
{
  const rad = 61.5;
  for (let y = Math.floor(RCY - rad - 2); y <= Math.ceil(RCY + rad + 2); y++)
    for (let x = Math.floor(RCX - rad - 2); x <= Math.ceil(RCX + rad + 2); x++) {
      const d = Math.hypot(x - RCX, y - RCY);
      if (d > rad + 1) continue;
      const a = clamp01(rad + 0.5 - d);
      const o = get(img, x, y);
      const sh = 0.55 + 0.45 * (d / rad);
      const well = [7 * sh, 20 * sh, 30 * sh];
      set(img, x, y, [0, 1, 2].map((k) => well[k] * a + o[k] * (1 - a)));
    }
}
cleanPill(1083, 446, 1139, 461, 1083);   // PASSIVA
cleanPill(1153, 446, 1296, 461, 1150);   // RESSONÂNCIA DE AZAATH
markRect(1060, 464, 1322, 558);          // descrição
fill(1052, 458, 1330, 566, 0.8, 260);
cleanPill(1110, 587, 1272, 607, 1106);   // INFUNDIR AZAATH (+1)
cleanPill(1046, 671, 1178, 692, 1044);   // PURIFICAR FLUXO

// 5f) "SELAR INFUSÃO" no fundo vira a versão apagada (cópia do PURIFICAR) e o
//     halo some; o jogo acende o recorte do item 3 quando há prévia
markRect(1186, 644, 1375, 726);
fill(1150, 630, 1375, 730, 0.8, 200);
for (let y = 660; y <= 702; y++) for (let x = 1036; x <= 1188; x++) {
  const c = get(img, x, y);
  // borda externa do botão copiado se mistura ao céu
  const a = clamp01(Math.min(x - 1036, 1188 - x, y - 660, 702 - y) / 4);
  const dst = get(img, x + 155, y);
  set(img, x + 155, y, [0, 1, 2].map((k) => c[k] * a + dst[k] * (1 - a)));
}

// 5f2) O painel pintado da arte saiu: o card do talento agora é a arte de
//      tools/card-concept (TalentBG.tga), desenhada por cima pelo jogo. Aqui o
//      lugar dele vira céu.
markRect(1024, 156, 1360, 730);
remember(fill(990, 120, 1375, 740, 1.2, 300));

// 5g) Estrelas de volta nas áreas apagadas (densidade parecida com o céu da arte)
{
  const area = new Uint8Array(W * H);
  for (const p of starPts) area[p] = 1;
  const n = Math.floor(starPts.length / 1400);
  for (let s = 0; s < n; s++) {
    const p = starPts[Math.floor(rnd() * starPts.length)];
    const sx = p % W, sy = (p / W) | 0;
    if (inCore(sx, sy)) continue;
    const big = rnd() < 0.12;
    const r = big ? 1.3 : 0.7 + rnd() * 0.4;
    const br = big ? 170 + rnd() * 60 : 50 + rnd() * 110;
    const tint = rnd() < 0.2 ? [0.8, 0.95, 1.1] : [1, 1, 1];
    for (let y = sy - 3; y <= sy + 3; y++) for (let x = sx - 3; x <= sx + 3; x++) {
      if (x < 0 || y < 0 || x >= W || y >= H || !area[y * W + x]) continue;
      const d = Math.hypot(x - sx, y - sy);
      let v = Math.exp(-(d * d) / (2 * r * r)) * br;
      if (big && (x === sx || y === sy)) v += Math.exp(-d / 1.6) * br * 0.35;
      const c = get(img, x, y);
      set(img, x, y, [0, 1, 2].map((k) => Math.min(255, c[k] + v * tint[k])));
    }
  }
}

// ---------------------------------------------------------------------------
// 6. Saída
// ---------------------------------------------------------------------------
function padTo(im, w, h) { const out = I.create(w, h); I.blit(out, im, 0, 0); return out; }
const bgOut = padTo(img, 2048, 1024);
for (let i = 0; i < 2048 * 1024; i++) if (bgOut.px[i * 4 + 3] === 0 && (i % 2048) < W && ((i / 2048) | 0) < H) bgOut.px[i * 4 + 3] = 255;

const OUTS = {
  CrucibleBG: bgOut,
  CrucibleRings: ringsAtlas,
  CrucibleStream: stream,
  CrucibleStreamGlow: streamGlow,
  CrucibleRune: rune,
  CrucibleBtnSeal: btnSeal,
};
for (const [name, im] of Object.entries(OUTS)) {
  I.writeTGA(path.join(OUT_WS, name + ".tga"), im);
  try { I.writeTGA(path.join(OUT_GAME, name + ".tga"), im); } catch (e) { console.log("sem acesso à pasta do jogo:", e.code); }
  console.log("gerado", name, im.w + "x" + im.h);
}
I.writePNG(path.join(PREV, "crucible_bg.png"), img);
I.writePNG(path.join(PREV, "crucible_rings.png"), ringsAtlas);
I.writePNG(path.join(PREV, "crucible_stream.png"), stream);
I.writePNG(path.join(PREV, "crucible_rune.png"), rune);
I.writePNG(path.join(PREV, "crucible_seal.png"), btnSeal);
console.log("Concluído.");
