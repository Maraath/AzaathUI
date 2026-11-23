// Mapa "Expedição": peças da moldura e o mar de papel velho tirados da arte concept.png (2000x1116).
//   node gen.js chrome   -> moldura (Exp*.tga) + prévias em out/
//   node gen.js sea      -> mar (ExpSeaL/R.tga, ExpPaper.tga), alinhado ao terreno do jogo
//   node gen.js labels   -> nomes dos mares (ExpLabelsL/R.tga)
//   node gen.js all
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");
const I = require("../../sheet-concept/img");
const { readPNG } = require("../../grimoire-concept/png");

const DIR = __dirname;
const ROOT = path.resolve(DIR, "../../..");
const OUT_DIRS = [
  path.join(ROOT, "AzaathUI/Media/MapFrame"),
  "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame",
];
const PREV = path.join(DIR, "out");
fs.mkdirSync(PREV, { recursive: true });
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";

const C = readPNG(path.join(DIR, "concept.png"));
const CW = C.w, CH = C.h;
// área do papel na arte (medida): x 76..1923, y 65..1047
const PX0 = 76, PX1 = 1923, PY0 = 65, PY1 = 1047;

// ---------------------------------------------------------------- utilidades
const lumOf = (r, g, b) => 0.299 * r + 0.587 * g + 0.114 * b;
function pix(img, x, y) { const i = (y * img.w + x) * 4; return [img.px[i], img.px[i + 1], img.px[i + 2], img.px[i + 3]]; }
function hash(i, j) { let h = (Math.imul(i | 0, 374761393) + Math.imul(j | 0, 668265263)) | 0; h = Math.imul(h ^ (h >>> 13), 1274126177); h ^= h >>> 16; return (h >>> 0) / 4294967296; }
function vn(x, y) { const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi, u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = hash(xi, yi), b = hash(xi + 1, yi), c = hash(xi, yi + 1), d = hash(xi + 1, yi + 1); return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v; }

function boxBlur(src, w, h, r) { // Float32 1 canal
  const tmp = new Float32Array(w * h), out = new Float32Array(w * h);
  for (let y = 0; y < h; y++) { let s = 0, n = 0;
    for (let x = -r; x < w; x++) { if (x + r < w) { s += src[y * w + x + r]; n++; } if (x - r - 1 >= 0) { s -= src[y * w + x - r - 1]; n--; } if (x >= 0) tmp[y * w + x] = s / n; } }
  for (let x = 0; x < w; x++) { let s = 0, n = 0;
    for (let y = -r; y < h; y++) { if (y + r < h) { s += tmp[(y + r) * w + x]; n++; } if (y - r - 1 >= 0) { s -= tmp[(y - r - 1) * w + x]; n--; } if (y >= 0) out[y * w + x] = s / n; } }
  return out;
}
function dilate(mask, w, h, r) { const f = new Float32Array(w * h); for (let i = 0; i < w * h; i++) f[i] = mask[i] ? 1 : 0;
  const b = boxBlur(f, w, h, r), o = new Uint8Array(w * h); for (let i = 0; i < w * h; i++) o[i] = b[i] > 0.001 ? 1 : 0; return o; }
function erode(mask, w, h, r) { const f = new Float32Array(w * h); for (let i = 0; i < w * h; i++) f[i] = mask[i] ? 1 : 0;
  const b = boxBlur(f, w, h, r), o = new Uint8Array(w * h); for (let i = 0; i < w * h; i++) o[i] = b[i] > 0.999 ? 1 : 0; return o; }

// preenchimento por pirâmide (push-pull): cada canal inválido recebe a média ponderada dos válidos ao redor
function pushPull(rgb, valid, w, h) {
  const levels = [{ w, h, c: rgb, a: Float32Array.from(valid, (v) => (v ? 1 : 0)) }];
  while (levels[levels.length - 1].w > 1 || levels[levels.length - 1].h > 1) {
    const L = levels[levels.length - 1], nw = Math.max(1, Math.ceil(L.w / 2)), nh = Math.max(1, Math.ceil(L.h / 2));
    const c = new Float32Array(nw * nh * 3), a = new Float32Array(nw * nh);
    for (let y = 0; y < L.h; y++) for (let x = 0; x < L.w; x++) {
      const i = y * L.w + x, j = (y >> 1) * nw + (x >> 1), wa = L.a[i];
      a[j] += wa; c[j * 3] += L.c[i * 3] * wa; c[j * 3 + 1] += L.c[i * 3 + 1] * wa; c[j * 3 + 2] += L.c[i * 3 + 2] * wa;
    }
    for (let j = 0; j < nw * nh; j++) if (a[j] > 0) { c[j * 3] /= a[j]; c[j * 3 + 1] /= a[j]; c[j * 3 + 2] /= a[j]; a[j] = Math.min(1, a[j]); }
    levels.push({ w: nw, h: nh, c, a });
  }
  for (let l = levels.length - 2; l >= 0; l--) {
    const L = levels[l], P = levels[l + 1];
    for (let y = 0; y < L.h; y++) for (let x = 0; x < L.w; x++) {
      const i = y * L.w + x, wa = L.a[i];
      if (wa >= 1) continue;
      const fx = Math.min(P.w - 1, Math.max(0, (x + 0.5) / 2 - 0.5)), fy = Math.min(P.h - 1, Math.max(0, (y + 0.5) / 2 - 0.5));
      const x0 = Math.floor(fx), y0 = Math.floor(fy), x1 = Math.min(P.w - 1, x0 + 1), y1 = Math.min(P.h - 1, y0 + 1), tx = fx - x0, ty = fy - y0;
      for (let k = 0; k < 3; k++) {
        const p = (xx, yy) => P.c[(yy * P.w + xx) * 3 + k];
        const v = (p(x0, y0) * (1 - tx) + p(x1, y0) * tx) * (1 - ty) + (p(x0, y1) * (1 - tx) + p(x1, y1) * tx) * ty;
        L.c[i * 3 + k] = L.c[i * 3 + k] * wa + v * (1 - wa);
      }
      L.a[i] = 1;
    }
  }
  return levels[0].c;
}

function save(name, img) {
  for (const d of OUT_DIRS) { if (fs.existsSync(path.dirname(d)) || fs.existsSync(d)) { fs.mkdirSync(d, { recursive: true }); I.writeTGA(path.join(d, name + ".tga"), img); } }
}
function preview(name, img) { I.writePNG(path.join(PREV, name + ".png"), img); }

// polilinha grossa (máscara)
function strokeMask(mask, w, pts, rad) {
  for (let k = 0; k < pts.length - 1; k++) {
    const [ax, ay] = pts[k], [bx, by] = pts[k + 1], len = Math.hypot(bx - ax, by - ay);
    for (let t = 0; t <= len; t += 0.5) {
      const cx = ax + (bx - ax) * t / len, cy = ay + (by - ay) * t / len;
      for (let y = Math.floor(cy - rad); y <= cy + rad; y++) for (let x = Math.floor(cx - rad); x <= cx + rad; x++)
        if (Math.hypot(x - cx, y - cy) <= rad) mask[y * w + x] = 1;
    }
  }
}

// ---------------------------------------------------------------- moldura (alfa sobre a arte)
const BANNER_TOP = { x0: 734, x1: 1270, y0: 0, y1: 178 };
const BANNER_LEFT = { x0: 90, x1: 322, y0: 80, y1: 640 };
const BUTTONS = [[84, 982, 190, 1040], [1800, 982, 1922, 1040]];
const ROPE_L = [[600, 0], [640, 20], [680, 47], [713, 72], [742, 92]];
const ROPE_R = [[1257, 97], [1290, 75], [1320, 60], [1357, 33], [1393, 8], [1408, 0]];

function chromeAlpha() {
  const w = CW, h = CH, N = w * h, A = new Uint8Array(N);
  const L = new Float32Array(N), sat = new Float32Array(N), warm = new Float32Array(N);
  for (let i = 0; i < N; i++) {
    const r = C.px[i * 4], g = C.px[i * 4 + 1], b = C.px[i * 4 + 2], mx = Math.max(r, g, b), mn = Math.min(r, g, b);
    L[i] = lumOf(r, g, b); sat[i] = mx > 0 ? (mx - mn) / mx : 0; warm[i] = r - b;
  }
  const inPaper = (x, y) => x >= PX0 && x <= PX1 && y >= PY0 && y <= PY1;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (!inPaper(x, y)) A[y * w + x] = 1;

  // faixa interna: pedra e bordas queimadas ligadas à moldura
  const BAND = 75;
  const inBand = (x, y) => inPaper(x, y) && (x - PX0 < BAND || PX1 - x < BAND || y - PY0 < BAND || PY1 - y < BAND)
    && Math.hypot(x - 218, y - 600) > 100;
  const pass = (i) => L[i] < 52 || (sat[i] < 0.17 && L[i] < 165);
  const stack = [];
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) if (A[y * w + x]) stack.push(y * w + x);
  while (stack.length) {
    const i = stack.pop(), x = i % w, y = (i / w) | 0;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx, ny = y + dy; if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue;
      const j = ny * w + nx; if (A[j] || !inBand(nx, ny) || !pass(j)) continue;
      A[j] = 1; stack.push(j);
    }
  }
  // botões da arte saem (viram papel; os nossos vão por cima)
  for (const [x0, y0, x1, y1] of BUTTONS) for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) if (y < PY1 - 2) A[y * w + x] = 0;

  // estandartes: tudo na caixa, menos o papel que se alcança de fora dela
  // corpo (linhas de cima): de cada lado, anda para dentro pelo papel até bater no contorno do pano.
  // franjas (embaixo): só o pano azulado e o contorno escuro colado nele.
  const bTop = new Uint8Array(N), bLeft = new Uint8Array(N);
  const paperish = (i) => L[i] > 118 || (warm[i] > 18 && L[i] > 28);
  const bluish = (i) => C.px[i * 4 + 2] > C.px[i * 4] + 2 && L[i] < 115;
  for (const [B, banner, bodyEnd] of [[BANNER_TOP, bTop, 128], [BANNER_LEFT, bLeft, 470]]) {
    for (let y = Math.max(B.y0, PY0); y <= B.y1; y++) {
      if (y <= bodyEnd) {
        let a = B.x0, b = B.x1;
        while (a < b && paperish(y * w + a)) a++;
        while (b > a && paperish(y * w + b)) b--;
        for (let x = a; x <= b; x++) banner[y * w + x] = 1;
      } else {
        for (let x = B.x0; x <= B.x1; x++) if (bluish(y * w + x)) banner[y * w + x] = 1;
      }
    }
    // filete dourado entre o corpo e a franja: vãos verticais curtos com pano em cima e embaixo
    for (let x = B.x0; x <= B.x1; x++) {
      let y = bodyEnd - 2;
      while (y <= B.y1) {
        if (banner[y * w + x]) { y++; continue; }
        let e = y; while (e <= B.y1 && !banner[e * w + x]) e++;
        if (e <= B.y1 && e - y <= 20 && banner[(y - 1) * w + x]) for (let q = y; q < e; q++) banner[q * w + x] = 1;
        y = e;
      }
    }
    // contorno escuro colado no pano (franjas) e furos internos
    const near = dilate(banner, w, h, 2);
    for (let y = bodyEnd + 1; y <= B.y1; y++) for (let x = B.x0; x <= B.x1; x++) { const i = y * w + x; if (near[i] && L[i] < 50) banner[i] = 1; }
    const closed = erode(dilate(banner, w, h, 2), w, h, 2);
    for (let i = 0; i < N; i++) if (closed[i]) banner[i] = 1;
  }
  // vãos entre as alças do estandarte da esquerda
  for (let y = 99; y <= 116; y++) for (let x = 112; x <= 290; x++) { const i = y * w + x; if (warm[i] > 30 && L[i] > 62) bLeft[i] = 0; }
  // varão do estandarte da esquerda
  for (let y = 85; y <= 103; y++) for (let x = 92; x <= 304; x++) bLeft[y * w + x] = 1;
  strokeMask(bTop, w, ROPE_L, 3.2);
  strokeMask(bTop, w, ROPE_R, 3.2);
  // fecha furinhos de 1 px
  for (const m of [bTop, bLeft]) { const c = erode(dilate(m, w, h, 1), w, h, 1); for (let i = 0; i < N; i++) if (c[i]) m[i] = 1; }
  for (let i = 0; i < N; i++) if (bTop[i]) A[i] = 1;
  // o estandarte da esquerda é peça própria: dentro do papel ele não entra na moldura
  const bl = dilate(bLeft, w, h, 3);
  for (let y = PY0; y <= PY1; y++) for (let x = PX0; x <= PX1; x++) { const i = y * w + x; if (bl[i]) A[i] = 0; }
  return { A, bTop, bLeft };
}

function buildChrome() {
  const { A, bTop, bLeft } = chromeAlpha();
  const w = CW, h = CH, N = w * h;
  // camada: alfa suave (1 px) + sombra projetada do estandarte
  const layer = (mask, shadowOf) => {
    const af = new Float32Array(N); for (let i = 0; i < N; i++) af[i] = mask[i];
    const soft = boxBlur(af, w, h, 1);
    const sh = new Float32Array(N);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const sx = x - 6, sy = y - 9; if (sx >= 0 && sy >= 0) sh[y * w + x] = shadowOf[sy * w + sx]; }
    const shB = boxBlur(boxBlur(sh, w, h, 6), w, h, 6);
    const img = I.create(w, h);
    for (let i = 0; i < N; i++) {
      const a = mask[i] ? Math.max(soft[i], 0.999) : soft[i] * (mask === A ? 1 : 0);
      const s = shB[i] * 0.5, tot = a + s * (1 - a);
      for (let k = 0; k < 3; k++) img.px[i * 4 + k] = tot > 0 ? C.px[i * 4 + k] * a / tot : 0;
      img.px[i * 4 + 3] = tot * 255;
    }
    return img;
  };
  const img = layer(A, bTop);
  const flagImg = layer(bLeft, bLeft);
  // onde o estandarte da esquerda cobre a moldura, a moldura fica por baixo (o estandarte vem por cima)
  for (let i = 0; i < N; i++) if (A[i] && flagImg.px[i * 4 + 3] > 0) flagImg.px[i * 4 + 3] = bLeft[i] ? 255 : 0;
  preview("chrome_full", img);
  preview("flag_full", flagImg);
  // título "AZEROTH" sai do estandarte (o jogo escreve o nome do lugar)
  eraseTitle(img);
  preview("chrome_notitle", img);
  const both = new Uint8Array(N); for (let i = 0; i < N; i++) both[i] = A[i] || bLeft[i] ? 1 : 0;
  fs.writeFileSync(path.join(PREV, "chrome_alpha.bin"), Buffer.from(both.buffer));

  const P = {
    ExpTopL: [0, 0, 340, 180], ExpTopMidL: [340, 0, 220, 180], ExpBanner: [560, 0, 880, 180],
    ExpTopMidR: [1440, 0, 220, 180], ExpTopR: [1660, 0, 340, 180],
    ExpLeft: [0, 180, 150, 750], ExpRight: [1850, 180, 150, 750],
    ExpBotL: [0, 930, 340, 186], ExpBotMid: [340, 930, 1320, 186], ExpBotR: [1660, 930, 340, 186],
    ExpFlag: [BANNER_LEFT.x0 - 10, BANNER_LEFT.y0, 260, 580],
  };
  const sizes = {};
  for (const [name, [x, y, cw, ch]] of Object.entries(P)) {
    const piece = I.crop(name === "ExpFlag" ? flagImg : img, x, y, cw, ch);
    save(name, piece);
    sizes[name] = [cw, ch];
  }
  // encaixe dos botões: a moldura do botão "<<" sem o desenho de dentro
  const slot = I.crop(C, 86, 986, 46, 46);
  for (let j = 0; j < 46; j++) for (let i = 0; i < 46; i++) {
    const d = (j * 46 + i) * 4, e = Math.min(i, j, 45 - i, 45 - j);
    if (e >= 7) { const t = Math.min(1, (e - 7) / 4); const base = [26, 22, 18];
      for (let k = 0; k < 3; k++) slot.px[d + k] = slot.px[d + k] * (1 - t) + base[k] * t; }
  }
  save("ExpSlot", slot); preview("slot", slot);
  fs.writeFileSync(path.join(PREV, "sizes.json"), JSON.stringify(sizes, null, 1));
  console.log("moldura ok");
}

// apaga as letras claras do estandarte e cobre com o tecido de colunas sem letra
// (letra = tudo que não é pano azulado na caixa do título; cada trecho de letra numa linha
//  é coberto pelo pano logo à esquerda dele, espelhado)
function eraseTitle(img) {
  const x0 = 818, x1 = 1186, y0 = 58, y1 = 130, w = img.w;
  const isLetter = (x, y) => { const i = (y * w + x) * 4; return !(img.px[i + 2] > img.px[i] + 2) || lumOf(img.px[i], img.px[i + 1], img.px[i + 2]) > 112; };
  const m = new Uint8Array(w * img.h);
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) if (isLetter(x, y)) m[y * w + x] = 1;
  const src = Float32Array.from(img.px);
  const at = (x, y, c) => src[(y * w + x) * 4 + c];
  // retângulo do título refeito: cor de cada coluna logo acima das letras (as dobras são verticais),
  // sombreado vertical medido nas laterais sem letra, trama suave e bordas esfumadas
  const R = { x0: 818, x1: 1188, y0: 57, y1: 127 };
  const sides = [];
  for (let x = 770; x <= 812; x++) sides.push(x);
  for (let x = 1196; x <= 1236; x++) sides.push(x);
  const lumAt = (x, y) => lumOf(at(x, y, 0), at(x, y, 1), at(x, y, 2));
  const ref = sides.reduce((s, x) => s + lumAt(x, 53), 0) / sides.length;
  const prof = {};
  for (let y = R.y0 - 6; y <= R.y1 + 6; y++) prof[y] = Math.min(1.15, Math.max(0.6, sides.reduce((s, x) => s + lumAt(x, y), 0) / sides.length / ref));
  for (let y = R.y0 - 6; y <= R.y1 + 6; y++) for (let x = R.x0 - 6; x <= R.x1 + 6; x++) {
    const e = Math.min(x - (R.x0 - 6), (R.x1 + 6) - x, y - (R.y0 - 6), (R.y1 + 6) - y);
    const k = Math.min(1, e / 6);
    if (k <= 0) continue;
    const d = (y * w + x) * 4;
    const weave = (hash(x, y) - 0.5) * 7 + (vn(x / 2.2, y / 2.2) - 0.5) * 9 + ((x + y) % 2 ? 1.5 : -1.5);
    for (let c = 0; c < 3; c++) {
      let top = 0; for (let j = 49; j <= 54; j++) top += at(x, j, c); top /= 6;
      const v = top * prof[y] + weave;
      img.px[d + c] = src[d + c] * (1 - k) + v * k;
    }
  }
}

// ---------------------------------------------------------------- mar
function readTGA(file) {
  const b = fs.readFileSync(file), w = b.readUInt16LE(12), h = b.readUInt16LE(14), bpp = b[16] / 8, top = (b[17] & 0x20) !== 0, off = 18 + b[0];
  const px = new Float32Array(w * h * 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const sy = top ? y : h - 1 - y, s = off + (sy * w + x) * bpp, d = (y * w + x) * 4;
    px[d] = b[s + 2]; px[d + 1] = b[s + 1]; px[d + 2] = b[s]; px[d + 3] = bpp === 4 ? b[s + 3] : 255;
  }
  return { w, h, px };
}

function oldSeaAlpha() {
  const keep = path.join(DIR, "old");
  fs.mkdirSync(keep, { recursive: true });
  for (const s of ["L", "R"]) {
    const f = path.join(keep, "SeaChart" + s + ".tga");
    if (!fs.existsSync(f)) fs.copyFileSync(path.join(ROOT, "AzaathUI/Media/MapFrame/SeaChart" + s + ".tga"), f);
  }
  const Lh = readTGA(path.join(keep, "SeaChartL.tga")), Rh = readTGA(path.join(keep, "SeaChartR.tga"));
  const w = Lh.w + Rh.w, h = Lh.h, a = new Float32Array(w * h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) a[y * w + x] = (x < Lh.w ? Lh.px[(y * Lh.w + x) * 4 + 3] : Rh.px[(y * Rh.w + x - Lh.w) * 4 + 3]) / 255;
  return { w, h, a, hw: Lh.w };
}

// terra na arte (só para alinhar): textura forte ou verde, em blocos grandes
function conceptLandRough() {
  const w = CW, h = CH, N = w * h, Lm = new Float32Array(N), L2 = new Float32Array(N), green = new Uint8Array(N);
  for (let i = 0; i < N; i++) { const r = C.px[i * 4], g = C.px[i * 4 + 1], b = C.px[i * 4 + 2]; const l = lumOf(r, g, b); Lm[i] = l; L2[i] = l * l; if (g > r + 4 && g > b + 6) green[i] = 1; }
  const m1 = boxBlur(Lm, w, h, 3), m2 = boxBlur(L2, w, h, 3), v = new Float32Array(N);
  for (let i = 0; i < N; i++) v[i] = Math.sqrt(Math.max(0, m2[i] - m1[i] * m1[i]));
  const vs = boxBlur(v, w, h, 7), gs = boxBlur(Float32Array.from(green), w, h, 6);
  const land = new Uint8Array(N);
  for (let y = PY0; y <= PY1; y++) for (let x = PX0; x <= PX1; x++) { const i = y * w + x; if (vs[i] > 15 || gs[i] > 0.35) land[i] = 1; }
  // só blocos grandes
  const lab = new Int32Array(N), out = new Uint8Array(N); let id = 0;
  for (let s = 0; s < N; s++) {
    if (!land[s] || lab[s]) continue; id++; const comp = [s]; lab[s] = id;
    for (let k = 0; k < comp.length; k++) { const i = comp[k], x = i % w, y = (i / w) | 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const nx = x + dx, ny = y + dy; if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue; const j = ny * w + nx; if (land[j] && !lab[j]) { lab[j] = id; comp.push(j); } } }
    if (comp.length > 9000) for (const i of comp) out[i] = 1;
  }
  // preenche os buracos (neve, desertos) e tira a borda inchada pelo desfoque
  const reach = new Uint8Array(N), st = [];
  for (let x = 0; x < w; x++) { st.push(x, (h - 1) * w + x); }
  for (let y = 0; y < h; y++) { st.push(y * w, y * w + w - 1); }
  for (const i of st) reach[i] = 1;
  while (st.length) { const i = st.pop(), x = i % w, y = (i / w) | 0;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) { const nx = x + dx, ny = y + dy; if (nx < 0 || ny < 0 || nx >= w || ny >= h) continue; const j = ny * w + nx; if (!reach[j] && !out[j]) { reach[j] = 1; st.push(j); } } }
  const filled = new Uint8Array(N); for (let i = 0; i < N; i++) filled[i] = reach[i] ? 0 : 1;
  return erode(filled, w, h, 6);
}

function fitTransform(sea, landC) {
  // texel (u,v) do mar -> pixel da arte: x = ax*u + bx, y = ay*v + by
  const st = 12, uw = Math.floor(sea.w / st), vh = Math.floor(sea.h / st), sm = [];
  for (let v = 0; v < vh; v++) for (let u = 0; u < uw; u++) sm.push([u * st + st / 2, v * st + st / 2, sea.a[(v * st + st / 2) * sea.w + u * st + st / 2] < 0.03 ? 1 : 0]);
  const score = (ax, ay, bx, by) => {
    let inter = 0, uni = 0;
    for (const [u, v, l] of sm) {
      const x = Math.round(ax * u + bx), y = Math.round(ay * v + by);
      if (x < PX0 + 30 || x > PX1 - 30 || y < PY0 + 30 || y > PY1 - 30) continue;
      const c = landC[y * CW + x];
      if (l && c) inter++; if (l || c) uni++;
    }
    return uni ? inter / uni : 0;
  };
  let best = { s: -1 };
  for (let a = 0.66; a <= 0.86; a += 0.006) for (let bx = -60; bx <= 120; bx += 5) for (let by = -60; by <= 90; by += 5) {
    const s = score(a, a, bx, by); if (s > best.s) best = { s, ax: a, ay: a, bx, by };
  }
  for (let it = 0; it < 3; it++) {
    const step = [0.002, 0.001, 0.0005][it], sb = [2, 1, 0.5][it];
    let improved = true;
    while (improved) { improved = false;
      for (const [dax, day, dbx, dby] of [[step, 0, 0, 0], [-step, 0, 0, 0], [0, step, 0, 0], [0, -step, 0, 0], [0, 0, sb, 0], [0, 0, -sb, 0], [0, 0, 0, sb], [0, 0, 0, -sb]]) {
        const c = { ax: best.ax + dax, ay: best.ay + day, bx: best.bx + dbx, by: best.by + dby };
        const s = score(c.ax, c.ay, c.bx, c.by); if (s > best.s + 1e-6) { best = { s, ...c }; improved = true; }
      }
    }
  }
  return best;
}

// caixas dos nomes dos mares da arte (saem; voltam escritos certo em ExpLabels)
const LABEL_BOXES = [[548, 128, 712, 162], [858, 284, 1172, 340], [1040, 350, 1234, 382], [1680, 148, 1915, 194],
  [716, 606, 880, 640], [940, 652, 1072, 688], [1572, 690, 1788, 728], [1004, 832, 1238, 866], [895, 935, 1120, 985], [232, 968, 398, 1000]];

function buildSea() {
  const sea = oldSeaAlpha();
  console.log("mar antigo:", sea.w + "x" + sea.h);
  let T;
  const tf = path.join(PREV, "fit.json");
  if (fs.existsSync(tf) && !process.argv.includes("--refit")) T = JSON.parse(fs.readFileSync(tf, "utf8"));
  else {
    const landC = conceptLandRough();
    const lp = I.create(CW, CH); for (let i = 0; i < CW * CH; i++) { const v = landC[i] ? 255 : 0; lp.px[i * 4] = v; lp.px[i * 4 + 1] = v; lp.px[i * 4 + 2] = v; lp.px[i * 4 + 3] = 255; }
    preview("land_concept", I.resize(lp, 1000, 558));
    T = fitTransform(sea, landC); fs.writeFileSync(tf, JSON.stringify(T));
  }
  console.log("alinhamento:", T);

  // máscara do que não é mar na arte: terra do jogo projetada, moldura, estandartes, nomes, botões
  const w = CW, h = CH, N = w * h, bad = new Uint8Array(N);
  const A = new Uint8Array(fs.readFileSync(path.join(PREV, "chrome_alpha.bin")));
  for (let i = 0; i < N; i++) if (A[i]) bad[i] = 1;
  const badChrome = dilate(bad, w, h, 14);
  for (let i = 0; i < N; i++) bad[i] = badChrome[i];
  const gameLand = new Uint8Array(N);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const u = Math.round((x - T.bx) / T.ax), v = Math.round((y - T.by) / T.ay);
    if (u >= 0 && v >= 0 && u < sea.w && v < sea.h && sea.a[v * sea.w + u] < 0.03) gameLand[y * w + x] = 1;
  }
  const nearLand = dilate(gameLand, w, h, 26);
  const landC = conceptLandRough();
  for (let i = 0; i < N; i++) if (gameLand[i] || (nearLand[i] && landC[i])) bad[i] = 1;
  const bad2 = dilate(bad, w, h, 2);
  for (const [x0, y0, x1, y1] of LABEL_BOXES.concat(BUTTONS)) for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) bad2[y * w + x] = 1;

  const rgb = new Float32Array(N * 3), valid = new Uint8Array(N);
  for (let i = 0; i < N; i++) { rgb[i * 3] = C.px[i * 4]; rgb[i * 3 + 1] = C.px[i * 4 + 1]; rgb[i * 3 + 2] = C.px[i * 4 + 2]; valid[i] = bad2[i] ? 0 : 1; }
  const filled = pushPull(rgb, valid, w, h);
  // grão de papel onde foi preenchido
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const i = y * w + x; if (valid[i]) continue;
    const g = (hash(x, y) - 0.5) * 10 + (vn(x / 3, y / 3) - 0.5) * 12 + (vn(x / 14 + 9, y / 14) - 0.5) * 14;
    filled[i * 3] += g; filled[i * 3 + 1] += g * 0.95; filled[i * 3 + 2] += g * 0.85;
  }
  const clean = I.create(w, h);
  for (let i = 0; i < N; i++) { clean.px[i * 4] = filled[i * 3]; clean.px[i * 4 + 1] = filled[i * 3 + 1]; clean.px[i * 4 + 2] = filled[i * 3 + 2]; clean.px[i * 4 + 3] = 255; }
  preview("sea_clean", I.resize(clean, 1000, 558));

  // conferência: contorno da terra do jogo sobre a arte
  const chk = I.create(w, h);
  for (let i = 0; i < N; i++) { for (let k = 0; k < 3; k++) chk.px[i * 4 + k] = C.px[i * 4 + k]; chk.px[i * 4 + 3] = 255; }
  for (let y = 1; y < h - 1; y++) for (let x = 1; x < w - 1; x++) { const i = y * w + x;
    if (gameLand[i] && (!gameLand[i - 1] || !gameLand[i + 1] || !gameLand[i - w] || !gameLand[i + w])) { chk.px[i * 4] = 255; chk.px[i * 4 + 1] = 0; chk.px[i * 4 + 2] = 255; } }
  preview("fit_check", chk);

  // texturas do mar: mesmas dimensões e furos do mar antigo
  const sample = (fx, fy, k) => {
    fx = Math.min(PX1 - 1, Math.max(PX0, fx)); fy = Math.min(PY1 - 1, Math.max(PY0, fy));
    const x0 = Math.floor(fx), y0 = Math.floor(fy), tx = fx - x0, ty = fy - y0;
    const p = (xx, yy) => filled[(yy * w + xx) * 3 + k];
    return (p(x0, y0) * (1 - tx) + p(x0 + 1, y0) * tx) * (1 - ty) + (p(x0, y0 + 1) * (1 - tx) + p(x0 + 1, y0 + 1) * tx) * ty;
  };
  for (const side of ["L", "R"]) {
    const ox = side === "L" ? 0 : sea.hw, tw = side === "L" ? sea.hw : sea.w - sea.hw, out = I.create(tw, sea.h);
    for (let v = 0; v < sea.h; v++) for (let u = 0; u < tw; u++) {
      const d = (v * tw + u) * 4, gu = u + ox, fx = T.ax * gu + T.bx, fy = T.ay * v + T.by;
      for (let k = 0; k < 3; k++) out.px[d + k] = sample(fx, fy, k);
      const a0 = sea.a[v * sea.w + gu] / 0.125;
      out.px[d + 3] = (a0 >= 1 ? 1 : a0 * a0 * (3 - 2 * a0)) * 255;
    }
    preview("sea_" + side, out);
    // no jogo a arte do mar fica por baixo do terreno (tools/map-extract/sea-mask.js): opaca, sem furos
    for (let i = 3; i < out.px.length; i += 4) out.px[i] = 255;
    save("ExpOcean" + side, out);
    if (side === "L") preview("sea_L_small", I.resize(out, 678, 731));
  }
  // papel liso (fundo quando a arte do mar some, ao aproximar ou nas zonas)
  const paperRGB = new Float32Array(rgb.length);
  for (let i = 0; i < N; i++) for (let k = 0; k < 3; k++) paperRGB[i * 3 + k] = filled[i * 3 + k];
  const lowValid = new Uint8Array(N);
  for (let y = PY0 + 40; y < PY1 - 40; y++) for (let x = PX0 + 40; x < PX1 - 40; x++) lowValid[y * w + x] = valid[y * w + x];
  const low = pushPull(Float32Array.from(paperRGB), lowValid, w, h);
  const paper = I.create(1024, 576);
  for (let y = 0; y < 576; y++) for (let x = 0; x < 1024; x++) {
    const sx = Math.round(PX0 + 40 + x / 1024 * (PX1 - PX0 - 80)), sy = Math.round(PY0 + 40 + y / 576 * (PY1 - PY0 - 80));
    const d = (y * 1024 + x) * 4, i = sy * w + sx;
    let acc = [0, 0, 0], n = 0;
    for (let j = -12; j <= 12; j += 4) for (let q = -12; q <= 12; q += 4) { const ii = Math.min(N - 1, Math.max(0, i + j * w + q)); for (let k = 0; k < 3; k++) acc[k] += low[ii * 3 + k]; n++; }
    const g = (hash(x, y) - 0.5) * 8 + (vn(x / 4, y / 4) - 0.5) * 10;
    for (let k = 0; k < 3; k++) paper.px[d + k] = acc[k] / n + g * (k === 2 ? 0.8 : 1);
    paper.px[d + 3] = 255;
  }
  save("ExpPaper", paper); preview("paper", I.resize(paper, 512, 288));
  console.log("mar ok");
}

// ---------------------------------------------------------------- nomes
const LABELS = [
  ["Mar Velado", 630, 146, 22], ["·  O Grande Mar  ·", 1015, 312, 38], ["Golfo de Lordaeron", 1137, 367, 19],
  ["Mar Proibido", 1797, 171, 32], ["Canal das Marés", 798, 623, 20], ["A Voragem", 1006, 670, 22],
  ["Baía da Tempestade", 1690, 709, 19], ["Enseada dos Mercadores", 1121, 849, 19], ["Mares do Sul", 1007, 960, 33],
  ["Mar das Brumas", 315, 984, 19],
];
function buildLabels() {
  const T = JSON.parse(fs.readFileSync(path.join(PREV, "fit.json"), "utf8"));
  const sea = oldSeaAlpha();
  const font = "file:///" + path.join(ROOT, "AzaathUI/Media/Fonts/IMFell-Italic.ttf").replace(/\\/g, "/");
  const items = LABELS.map(([t, x, y, s]) => ({ t, u: (x - T.bx) / T.ax, v: (y - T.by) / T.ay, s: s / T.ax }));
  const html = `<!doctype html><html><head><meta charset="utf-8"><style>@font-face{font-family:F;src:url('${font}')}
html,body{margin:0;background:transparent}</style></head><body><canvas id="c" width="${sea.w}" height="${sea.h}"></canvas><span style="font-family:F">.</span>
<script>document.fonts.load('40px F').then(()=>{const c=document.getElementById('c'),x=c.getContext('2d');
const it=${JSON.stringify(items)};x.textAlign='center';x.textBaseline='middle';
for(const l of it){x.font=l.s+'px F';x.lineJoin='round';
 x.save();x.shadowColor='rgba(30,16,4,.55)';x.shadowBlur=l.s*.25;x.shadowOffsetY=l.s*.06;x.strokeStyle='rgba(58,32,12,1)';x.lineWidth=l.s*.2;x.strokeText(l.t,l.u,l.v);x.restore();
 x.strokeStyle='rgba(44,24,8,1)';x.lineWidth=l.s*.12;x.strokeText(l.t,l.u,l.v);
 x.fillStyle='#f4e7c8';x.fillText(l.t,l.u,l.v);}
document.title='ok';});</script></body></html>`;
  const work = fs.mkdtempSync(path.join(os.tmpdir(), "azaath_exp_"));
  const hf = path.join(work, "l.html"), pf = path.join(work, "l.png");
  fs.writeFileSync(hf, html, "utf8");
  spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--user-data-dir=" + path.join(work, "p"), "--no-first-run", "--hide-scrollbars",
    "--default-background-color=00000000", "--force-device-scale-factor=1", "--window-size=" + sea.w + "," + sea.h,
    "--virtual-time-budget=4000", "--allow-file-access-from-files", "--screenshot=" + pf, "file:///" + hf.replace(/\\/g, "/")], { timeout: 120000 });
  const img = readPNG(pf);
  for (const side of ["L", "R"]) {
    const ox = side === "L" ? 0 : sea.hw, tw = side === "L" ? sea.hw : sea.w - sea.hw;
    save("ExpLabels" + side, I.crop(img, ox, 0, tw, sea.h));
  }
  preview("labels", img);
  console.log("nomes ok");
}

const what = process.argv[2] || "all";
if (what === "chrome" || what === "all") buildChrome();
if (what === "sea" || what === "all") buildSea();
if (what === "labels" || what === "all") buildLabels();
