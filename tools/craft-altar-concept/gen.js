// Altar de criação da aba Ofícios recortado da arte concept.png (2000x2000).
//   node gen.js   -> Media/Sheet/CraftAltarBase.tga (círculo, medalhões vazios)
//                    Media/Sheet/CraftAltarBeamsA/B.tga (um feixe de energia por slot, somado em ADD)
//                    bloco ALTAR_ART no Professions.lua + prévias em out/
// Base + os 8 feixes em ADD = a arte original; o feixe de um slot sem material some ou esmaece.
"use strict";
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const DIR = __dirname;
const ROOT = path.resolve(DIR, "../..");
const MEDIA = path.join(ROOT, "AzaathUI/Media/Sheet");
const LUA = path.join(ROOT, "AzaathUI/Modules/Professions.lua");
const OUT = path.join(DIR, "out");
fs.mkdirSync(OUT, { recursive: true });

const C = readPNG(path.join(DIR, "concept.png"));
const W = C.w, H = C.h, N = W * H;

// medidas na arte (px)
const CENTER = { x: 994, y: 993 };   // centro do círculo dos medalhões
const CORE = { x: 995, y: 978 };     // o redemoinho dourado fica um pouco acima
const R_CORE = 92;       // ícone do resultado, dentro do anel dourado
const R_INNER = 215;     // até aqui a arte fica sempre (anel rúnico azul do núcleo)
const R_MED_IN = 75;     // miolo do medalhão (vira o ícone do material)
const R_MED_OUT = 104;   // aro de metal (fica sempre na base)
const CROP_R = 980;      // quadrado recortado em volta do centro
const FEATHER = [880, 975];
const TEX = 1024, CELL = 512;
const K = TEX / (2 * CROP_R);
// ordem horária a partir do topo
const GUESS = [[1000, 300], [1486, 500], [1690, 994], [1486, 1490], [996, 1696], [514, 1490], [310, 994], [514, 500]];

const sstep = (a, b, x) => { const t = Math.max(0, Math.min(1, (x - a) / (b - a))); return t * t * (3 - 2 * t); };
const lumAt = (x, y) => {
  x = Math.round(x); y = Math.round(y);
  if (x < 0 || y < 0 || x >= W || y >= H) return 0;
  const i = (y * W + x) * 4; return 0.299 * C.px[i] + 0.587 * C.px[i + 1] + 0.114 * C.px[i + 2];
};

// ------------------------------------------------ centro exato de cada medalhão (borda externa do aro)
function refine([gx, gy]) {
  let best = -1e9, bx = gx, by = gy;
  for (let dy = -18; dy <= 18; dy++) for (let dx = -18; dx <= 18; dx++) {
    const cx = gx + dx, cy = gy + dy; let s = 0;
    for (let k = 0; k < 72; k++) {
      const a = k * Math.PI / 36, c = Math.cos(a), si = Math.sin(a);
      s += lumAt(cx + c * 99, cy + si * 99) - lumAt(cx + c * 112, cy + si * 112);
    }
    if (s > best) { best = s; bx = cx; by = cy; }
  }
  return { x: bx, y: by };
}
const MED = GUESS.map(refine);
MED.forEach((m, i) => { m.ang = Math.atan2(m.y - CENTER.y, m.x - CENTER.x); console.log(`slot ${i + 1}: ${m.x},${m.y}`); });

// ------------------------------------------------ filtros
function line1D(get, set, n, r, keep) {
  const q = new Int32Array(n); let qh = 0, qt = 0;
  for (let i = 0; i < n + r; i++) {
    if (i < n) { const v = get(i); while (qt > qh && !keep(get(q[qt - 1]), v)) qt--; q[qt++] = i; }
    const c = i - r;
    if (c >= 0) { while (q[qh] < c - r) qh++; set(c, get(q[qh])); }
  }
}
function filt(src, r, isMax) {
  const tmp = new Float32Array(N), dst = new Float32Array(N);
  const keep = isMax ? (a, v) => a > v : (a, v) => a < v;
  for (let y = 0; y < H; y++) { const o = y * W; line1D(i => src[o + i], (i, v) => { tmp[o + i] = v; }, W, r, keep); }
  for (let x = 0; x < W; x++) line1D(i => tmp[i * W + x], (i, v) => { dst[i * W + x] = v; }, H, r, keep);
  return dst;
}
function blur(src, r) {
  const tmp = new Float32Array(N), dst = new Float32Array(N);
  for (let y = 0; y < H; y++) { let s = 0, n = 0; const o = y * W;
    for (let x = -r; x < W; x++) { if (x + r < W) { s += src[o + x + r]; n++; } if (x - r - 1 >= 0) { s -= src[o + x - r - 1]; n--; } if (x >= 0) tmp[o + x] = s / n; } }
  for (let x = 0; x < W; x++) { let s = 0, n = 0;
    for (let y = -r; y < H; y++) { if (y + r < H) { s += tmp[(y + r) * W + x]; n++; } if (y - r - 1 >= 0) { s -= tmp[(y - r - 1) * W + x]; n--; } if (y >= 0) dst[y * W + x] = s / n; } }
  return dst;
}

// ------------------------------------------------ feixes = o que sobra acima do fundo, colorido e longe do núcleo
const chan = [0, 1, 2].map(k => { const a = new Float32Array(N); for (let i = 0; i < N; i++) a[i] = C.px[i * 4 + k]; return a; });
// fundo = abertura larga (some tudo que é mais estreito que o halo do feixe), suavizada para não ficar quadriculada
const excess = chan.map(a => { const o = blur(filt(filt(a, 150, false), 150, true), 60); const e = new Float32Array(N); for (let i = 0; i < N; i++) e[i] = Math.max(0, a[i] - Math.min(a[i], o[i])); return e; });
const eb = excess.map(e => blur(e, 7));
const colw = new Float32Array(N);
for (let i = 0; i < N; i++) {
  const mx = Math.max(eb[0][i], eb[1][i], eb[2][i]), mn = Math.min(eb[0][i], eb[1][i], eb[2][i]);
  colw[i] = sstep(0.18, 0.40, (mx - mn) / (mx + 1e-3)) * sstep(35, 90, mx);
}
// o miolo branco do feixe é pouco saturado: herda o peso do brilho colorido em volta
const wide = blur(filt(colw, 28, true), 12);
const wgt = new Float32Array(N), onRim = new Uint8Array(N);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const i = y * W + x;
  let w = sstep(0.05, 0.4, wide[i]);
  w *= sstep(R_INNER - 15, R_INNER + 15, Math.hypot(x - CORE.x, y - CORE.y)) * sstep(870, 820, Math.hypot(x - CENTER.x, y - CENTER.y));
  for (const m of MED) {
    const d = Math.hypot(x - m.x, y - m.y);
    if (d < R_MED_IN + 4) w *= sstep(R_MED_IN, R_MED_IN + 4, d);
    if (d < R_MED_OUT + 10) onRim[i] = 1;
  }
  wgt[i] = w;
}
// sob o feixe, o fundo é a média dos vizinhos fora dele (o mínimo local deixava um sulco escuro)
function pushPull(val, cov, w, h) { // preenche onde cov=0 com a média dos vizinhos válidos (pirâmide)
  if (w <= 1 && h <= 1) return val.slice();
  const w2 = Math.ceil(w / 2), h2 = Math.ceil(h / 2), v2 = new Float32Array(w2 * h2), c2 = new Float32Array(w2 * h2);
  for (let y = 0; y < h2; y++) for (let x = 0; x < w2; x++) {
    let sv = 0, sc = 0;
    for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 2; dx++) {
      const sx = 2 * x + dx, sy = 2 * y + dy; if (sx >= w || sy >= h) continue;
      const c = cov[sy * w + sx]; sv += val[sy * w + sx] * c; sc += c;
    }
    v2[y * w2 + x] = sc > 0 ? sv / sc : 0; c2[y * w2 + x] = Math.min(1, sc);
  }
  const up = pushPull(v2, c2, w2, h2), out = new Float32Array(w * h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const fx = Math.min(w2 - 1, Math.max(0, (x - 0.5) / 2)), fy = Math.min(h2 - 1, Math.max(0, (y - 0.5) / 2));
    const x0 = Math.floor(fx), y0 = Math.floor(fy), x1 = Math.min(w2 - 1, x0 + 1), y1 = Math.min(h2 - 1, y0 + 1), tx = fx - x0, ty = fy - y0;
    const u = (up[y0 * w2 + x0] * (1 - tx) + up[y0 * w2 + x1] * tx) * (1 - ty) + (up[y1 * w2 + x0] * (1 - tx) + up[y1 * w2 + x1] * tx) * ty;
    const c = cov[y * w + x]; out[y * w + x] = c * val[y * w + x] + (1 - c) * u;
  }
  return out;
}
{
  const m = new Float32Array(N); for (let i = 0; i < N; i++) m[i] = 1 - sstep(0.02, 0.2, wgt[i]);
  chan.forEach((a, k) => {
    const bg = blur(pushPull(a, m, W, H), 6);
    for (let i = 0; i < N; i++) if (m[i] < 1) excess[k][i] = Math.max(0, a[i] - Math.min(a[i], bg[i]));
  });
}
// runas são cinza e fracas: só a parte colorida do excesso (e o miolo muito claro) vai para o feixe
const strength = (() => { const e3 = excess.map(e => blur(e, 3)); const s = new Float32Array(N);
  for (let i = 0; i < N; i++) s[i] = 0.299 * e3[0][i] + 0.587 * e3[1][i] + 0.114 * e3[2][i]; return s; })();
for (let i = 0; i < N; i++) {
  if (wgt[i] <= 0) continue;
  const g = Math.min(excess[0][i], excess[1][i], excess[2][i]), keepGray = onRim[i] ? 1 : 1 - sstep(4, 18, strength[i]);
  for (let k = 0; k < 3; k++) excess[k][i] -= g * keepGray;
}

{ const dbg = I.create(W, H); for (let i = 0; i < N; i++) { const v = wgt[i] * 255, e = Math.max(excess[0][i], excess[1][i], excess[2][i]); dbg.px[i * 4] = v; dbg.px[i * 4 + 1] = e; dbg.px[i * 4 + 2] = 0; dbg.px[i * 4 + 3] = 255; }
  I.writePNG(path.join(OUT, "wgt.png"), I.resize(dbg, 700, 700)); }

// base = arte sem os feixes
const base = I.create(W, H);
for (let i = 0; i < N; i++) {
  for (let k = 0; k < 3; k++) base.px[i * 4 + k] = chan[k][i] - wgt[i] * excess[k][i];
  base.px[i * 4 + 3] = 255;
}
if (process.argv[2] === "zoom") {
  const [zx, zy, zw, zh] = process.argv.slice(3).map(Number), z = I.create(zw, zh * 2);
  I.blit(z, I.crop(C, zx, zy, zw, zh), 0, 0); I.blit(z, I.crop(base, zx, zy, zw, zh), 0, zh);
  I.writePNG(path.join(OUT, "zoom.png"), z); process.exit(0);
}
// miolo dos medalhões vazio: cor do aro interno puxada para dentro, escurecendo no meio
for (const m of MED) {
  const ring = [];
  for (let a = 0; a < 360; a++) {
    const t = a * Math.PI / 180; let r = 0, g = 0, b = 0, n = 0;
    for (let rr = R_MED_IN - 1; rr <= R_MED_IN + 2; rr++) {
      const x = Math.round(m.x + Math.cos(t) * rr), y = Math.round(m.y + Math.sin(t) * rr), j = (y * W + x) * 4;
      r += base.px[j]; g += base.px[j + 1]; b += base.px[j + 2]; n++;
    }
    ring.push([r / n, g / n, b / n]);
  }
  // mediana por canal: o feixe que encosta no aro não tinge o fundo
  const c = [0, 1, 2].map(k => ring.map(v => v[k]).sort((p, q) => p - q)[180]);
  for (let y = Math.floor(m.y - R_MED_IN); y <= m.y + R_MED_IN; y++) for (let x = Math.floor(m.x - R_MED_IN); x <= m.x + R_MED_IN; x++) {
    const d = Math.hypot(x - m.x, y - m.y);
    if (d >= R_MED_IN) continue;
    const f = 0.6 + 0.4 * (d / R_MED_IN) ** 2, j = (y * W + x) * 4;
    const blend = sstep(R_MED_IN - 3, R_MED_IN, d);
    for (let k = 0; k < 3; k++) base.px[j + k] = c[k] * f * (1 - blend) + base.px[j + k] * blend;
  }
}

// ------------------------------------------------ textura da base (quadrado em volta do centro, borda esfumada)
const X0 = CENTER.x - CROP_R, Y0 = CENTER.y - CROP_R;
const crop = I.crop(base, X0, Y0, 2 * CROP_R, 2 * CROP_R);
for (let y = 0; y < crop.h; y++) for (let x = 0; x < crop.w; x++) {
  const d = Math.hypot(x - CROP_R, y - CROP_R);
  crop.px[(y * crop.w + x) * 4 + 3] = 255 * sstep(FEATHER[1], FEATHER[0], d);
}
const baseTex = I.resize(crop, TEX, TEX);
I.writeTGA(path.join(MEDIA, "CraftAltarBase.tga"), baseTex);

// ------------------------------------------------ um feixe por slot (divisão suave pelo ângulo)
const SIG = 13 * Math.PI / 180;
const angd = (a, b) => { let d = a - b; while (d > Math.PI) d -= 2 * Math.PI; while (d < -Math.PI) d += 2 * Math.PI; return d; };
const atlases = [I.create(TEX, TEX, 0, 0, 0, 255), I.create(TEX, TEX, 0, 0, 0, 255)];
const beams = [];
MED.forEach((m, s) => {
  const lay = I.create(W, H, 0, 0, 0, 255);
  let bx0 = W, by0 = H, bx1 = 0, by1 = 0;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const i = y * W + x; if (wgt[i] <= 0) continue;
    const a = Math.atan2(y - CENTER.y, x - CENTER.x);
    let tot = 0, mine = 0;
    MED.forEach((o, t) => { const v = Math.exp(-((angd(a, o.ang) / SIG) ** 2)); tot += v; if (t === s) mine = v; });
    const f = wgt[i] * mine / tot; let mx = 0;
    for (let k = 0; k < 3; k++) { const v = f * excess[k][i]; lay.px[i * 4 + k] = v; mx = Math.max(mx, v); }
    if (mx > 1.5) { bx0 = Math.min(bx0, x); by0 = Math.min(by0, y); bx1 = Math.max(bx1, x); by1 = Math.max(by1, y); }
  }
  bx0 -= 4; by0 -= 4; bx1 += 4; by1 += 4;
  const bw = bx1 - bx0 + 1, bh = by1 - by0 + 1;
  const tw = Math.min(CELL, Math.round(bw * K)), th = Math.min(CELL, Math.round(bh * K));
  if (Math.round(bw * K) > CELL || Math.round(bh * K) > CELL) console.warn(`slot ${s + 1}: feixe maior que a célula`);
  const at = s < 4 ? 0 : 1, cell = s % 4, u = (cell % 2) * CELL, v = Math.floor(cell / 2) * CELL;
  I.blit(atlases[at], I.resize(I.crop(lay, bx0, by0, bw, bh), tw, th), u, v);
  beams.push({ file: at ? "CraftAltarBeamsB" : "CraftAltarBeamsA", u, v, tw, th, x: (bx0 - X0) * K, y: (by0 - Y0) * K, w: bw * K, h: bh * K });
});
atlases.forEach((a, i) => { for (let j = 0; j < TEX * TEX; j++) a.px[j * 4 + 3] = 255; I.writeTGA(path.join(MEDIA, i ? "CraftAltarBeamsB.tga" : "CraftAltarBeamsA.tga"), a); });

// ------------------------------------------------ bloco Lua
const f1 = v => (Math.round(v * 10) / 10).toString();
const lua = [
  "-- @@ALTAR ART (gerado por tools/craft-altar-concept/gen.js)@@",
  "-- px da textura CraftAltarBase (1024); feixes em CraftAltarBeamsA/B, somados em ADD",
  "local ALTAR_ART = {",
  `    size = ${TEX},`,
  `    core = { x = ${f1((CORE.x - X0) * K)}, y = ${f1((CORE.y - Y0) * K)}, r = ${f1(R_CORE * K)} },`,
  "    slots = {",
  ...MED.map((m, s) => { const b = beams[s];
    return `        { x = ${f1((m.x - X0) * K)}, y = ${f1((m.y - Y0) * K)}, r = ${f1(R_MED_IN * K)}, beam = { file = "${b.file}", u = ${b.u}, v = ${b.v}, tw = ${b.tw}, th = ${b.th}, x = ${f1(b.x)}, y = ${f1(b.y)}, w = ${f1(b.w)}, h = ${f1(b.h)} } },`; }),
  "    },",
  "}",
  "-- @@FIM ALTAR ART@@",
].join("\n");
let src = fs.readFileSync(LUA, "utf8");
const re = /-- @@ALTAR ART[\s\S]*?-- @@FIM ALTAR ART@@/;
if (re.test(src)) src = src.replace(re, lua);
else src = src.replace("-- @@FIM DO CRAFT ATLAS@@", "-- @@FIM DO CRAFT ATLAS@@\n" + lua);
fs.writeFileSync(LUA, src);

// ------------------------------------------------ prévias: tudo aceso (deve ser a arte) e só 3 materiais
function compose(on, fillFromArt) {
  const img = I.resize(crop, TEX, TEX);
  MED.forEach((m, s) => {
    const k = on[s]; if (!k) return; const b = beams[s];
    const lay = I.crop(atlases[b.file === "CraftAltarBeamsA" ? 0 : 1], b.u, b.v, b.tw, b.th);
    const sc = I.resize(lay, Math.round(b.w), Math.round(b.h));
    for (let y = 0; y < sc.h; y++) for (let x = 0; x < sc.w; x++) {
      const dx = Math.round(b.x) + x, dy = Math.round(b.y) + y; if (dx < 0 || dy < 0 || dx >= TEX || dy >= TEX) continue;
      const d = (dy * TEX + dx) * 4, sI = (y * sc.w + x) * 4;
      for (let c = 0; c < 3; c++) img.px[d + c] = Math.min(255, img.px[d + c] + sc.px[sI + c] * k);
    }
    if (fillFromArt) { // ícone fictício = o próprio item da arte
      const r = R_MED_IN * K, cx = (m.x - X0) * K, cy = (m.y - Y0) * K;
      for (let y = Math.floor(cy - r); y <= cy + r; y++) for (let x = Math.floor(cx - r); x <= cx + r; x++) {
        if (Math.hypot(x - cx, y - cy) > r) continue;
        const ax = Math.round(X0 + x / K), ay = Math.round(Y0 + y / K), sI = (ay * W + ax) * 4, d = (y * TEX + x) * 4;
        for (let c = 0; c < 3; c++) img.px[d + c] = C.px[sI + c];
      }
    }
  });
  return img;
}
const all = compose([1, 1, 1, 1, 1, 1, 1, 1], true);
const orig = I.resize(I.crop(C, X0, Y0, 2 * CROP_R, 2 * CROP_R), TEX, TEX);
let err = 0, cnt = 0;
for (let y = 0; y < TEX; y++) for (let x = 0; x < TEX; x++) {
  if (Math.hypot(x - TEX / 2, y - TEX / 2) > 440) continue;
  const d = (y * TEX + x) * 4; for (let c = 0; c < 3; c++) err += Math.abs(all.px[d + c] - orig.px[d + c]); cnt += 3;
}
console.log(`diferença média para a arte (tudo aceso): ${(err / cnt).toFixed(2)} / 255`);
I.writePNG(path.join(OUT, "compose-all.png"), I.resize(all, 640, 640));
I.writePNG(path.join(OUT, "compose-3.png"), I.resize(compose([1, 0, 0, 0.35, 0, 1, 0, 0], true), 640, 640));
I.writePNG(path.join(OUT, "base.png"), I.resize(baseTex, 640, 640));
