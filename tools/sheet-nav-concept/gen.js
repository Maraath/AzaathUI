// Gera as texturas da seleção do menu superior da ficha (tecla C) a partir da
// arte de conceito tools/sheet-nav-concept/concept.png (1024x100):
//   * NavFlare   — clarão da aba ativa: núcleo branco-ciano, risco horizontal
//                  fino e halo ciano (modelo ajustado aos pixels por fit.js);
//   * NavLine    — linha do horizonte sob as abas, esmaecendo nas pontas;
//   * NavChevron — seta "^" logo abaixo do clarão.
// Unidades: "px" = pixel da arte de conceito. Todas são desenhadas em ADD.
// Uso: node tools/sheet-nav-concept/gen.js
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Sheet");
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(PREV, { recursive: true });

const G = (d, s) => Math.exp(-(d * d) / (2 * s * s));
const smooth = (t) => { t = Math.max(0, Math.min(1, t)); return t * t * (3 - 2 * t); };

// ---------------------------------------------------------------------------
// Clarão: área de 384x48 px da arte (±192 x ±24) em 512x64 texels
// Parâmetros de fit.js (erro RMS ~8 em 0..255):
//   núcleo  A=108 σx=6.0  σy=6.6   (branco-ciano)
//   risco   A=88  σx=71   σy=1.32  (branco levemente ciano)
//   halo    A=111 σx=31.7 σy=4.6   (ciano)
// ---------------------------------------------------------------------------
const FLARE = { w: 512, h: 64, spanX: 384, spanY: 48 };
function flareAt(dx, dy) {
  const core = 150 * G(dx, 6.4) * G(dy, 6.0);
  const streak = 88 * G(dx, 71) * G(dy, 1.32);
  const halo = 111 * G(dx, 31.7) * G(dy, 4.6);
  const haze = 14 * G(dx, 70) * G(dy, 14); // névoa azul larga sob o clarão (bg 16,34,48 vs 9,19,28)
  const r = core * 0.92 + streak * 0.80 + halo * 0.45 + haze * 0.45;
  const g = core * 1.00 + streak * 0.97 + halo * 0.93 + haze * 0.95;
  const b = core * 1.00 + streak * 1.00 + halo * 1.00 + haze * 1.00;
  // janela suave para zerar nas bordas da textura
  const wx = 1 - smooth((Math.abs(dx) - 150) / 42);
  const wy = 1 - smooth((Math.abs(dy) - 16) / 8);
  const k = wx * wy;
  return [r * k, g * k, b * k];
}
function makeFlare() {
  const im = I.create(FLARE.w, FLARE.h, 0, 0, 0, 255);
  const SS = 3;
  for (let y = 0; y < FLARE.h; y++) for (let x = 0; x < FLARE.w; x++) {
    let acc = [0, 0, 0];
    for (let sy = 0; sy < SS; sy++) for (let sx = 0; sx < SS; sx++) {
      const dx = ((x + (sx + 0.5) / SS) / FLARE.w - 0.5) * FLARE.spanX;
      const dy = ((y + (sy + 0.5) / SS) / FLARE.h - 0.5) * FLARE.spanY;
      const c = flareAt(dx, dy);
      acc[0] += c[0]; acc[1] += c[1]; acc[2] += c[2];
    }
    const o = (y * FLARE.w + x) * 4;
    // núcleo satura no branco como na arte (o ADD com o fundo completa o resto)
    for (let k = 0; k < 3; k++) im.px[o + k] = Math.min(255, (acc[k] / (SS * SS)) * 1.12);
  }
  return im;
}

// ---------------------------------------------------------------------------
// Linha: 512x8, perfil vertical gaussiano, pontas esmaecendo (~22% de cada lado)
// Na arte: ~45/255 acima do fundo, cor quase neutra (0.93, 0.96, 1.0)
// ---------------------------------------------------------------------------
function makeLine() {
  const w = 512, h = 8;
  const im = I.create(w, h, 0, 0, 0, 255);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const t = (x + 0.5) / w;
    const fade = smooth(t / 0.22) * smooth((1 - t) / 0.22);
    const v = G(y + 0.5 - h / 2, 1.1) * fade * 255;
    const o = (y * w + x) * 4;
    im.px[o] = v * 0.93; im.px[o + 1] = v * 0.96; im.px[o + 2] = v;
  }
  return im;
}

// ---------------------------------------------------------------------------
// Seta "^": 16x16 px da arte em 64x64 texels. Ápice 4 px abaixo do topo,
// braços abrem ±5.5 px e descem 6.5 px; traço ~2.6 px; brilho leve ao redor.
// ---------------------------------------------------------------------------
function makeChevron() {
  const N = 64, span = 16, ax = 8, ay = 4.2, arm = [5.0, 5.8], hw = 1.05;
  const im = I.create(N, N, 0, 0, 0, 255);
  const segDist = (px, py, x1, y1, x2, y2) => {
    const vx = x2 - x1, vy = y2 - y1, t = Math.max(0, Math.min(1, ((px - x1) * vx + (py - y1) * vy) / (vx * vx + vy * vy)));
    return Math.hypot(px - (x1 + vx * t), py - (y1 + vy * t));
  };
  const SS = 3;
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    let ink = 0, glow = 0;
    for (let sy = 0; sy < SS; sy++) for (let sx = 0; sx < SS; sx++) {
      const px = (x + (sx + 0.5) / SS) / N * span, py = (y + (sy + 0.5) / SS) / N * span;
      const d = Math.min(segDist(px, py, ax, ay, ax - arm[0], ay + arm[1]), segDist(px, py, ax, ay, ax + arm[0], ay + arm[1]));
      ink += 1 - smooth((d - hw + 0.35) / 0.7);
      glow += G(d, 1.8);
    }
    ink /= SS * SS; glow /= SS * SS;
    const o = (y * N + x) * 4;
    const r = ink * 190 + glow * 12, g = ink * 222 + glow * 34, b = ink * 234 + glow * 42;
    im.px[o] = Math.min(255, r); im.px[o + 1] = Math.min(255, g); im.px[o + 2] = Math.min(255, b);
  }
  return im;
}

const flare = makeFlare(), line = makeLine(), chev = makeChevron();
I.writeTGA(path.join(OUT, "NavFlare.tga"), flare);
I.writeTGA(path.join(OUT, "NavLine.tga"), line);
I.writeTGA(path.join(OUT, "NavChevron.tga"), chev);

// ---------------------------------------------------------------------------
// Prévia: recorte da arte (em cima) x composição gerada (embaixo), escala 3x.
// A composição usa o fundo da própria arte sem o clarão (linha y=72).
// ---------------------------------------------------------------------------
const src = readPNG(path.join(__dirname, "concept.png"));
const RX = 300, RW = 640, RY = 20, RH = 56, S = 3;
const prev = I.create(RW * S, RH * S * 2, 0, 0, 0, 255);
const sample = (im, u, v) => { // bilinear
  const x = Math.max(0, Math.min(im.w - 1.001, u * im.w - 0.5)), y = Math.max(0, Math.min(im.h - 1.001, v * im.h - 0.5));
  const x0 = Math.floor(x), y0 = Math.floor(y), fx = x - x0, fy = y - y0, out = [0, 0, 0];
  for (let k = 0; k < 3; k++) {
    const p = (xx, yy) => im.px[(yy * im.w + xx) * 4 + k];
    out[k] = (p(x0, y0) * (1 - fx) + p(x0 + 1, y0) * fx) * (1 - fy) + (p(x0, y0 + 1) * (1 - fx) + p(x0 + 1, y0 + 1) * fx) * fy;
  }
  return out;
};
const LINE = { x0: 318, x1: 912, y: 50 }, FL = { x: 498, y: 50 }, CH = { x: 498, y: 58 };
for (let j = 0; j < RH * S; j++) for (let i = 0; i < RW * S; i++) {
  const cx = RX + i / S, cy = RY + j / S;
  const sp = src.px, so = (Math.floor(cy) * src.w + Math.floor(cx)) * 4;
  const top = (j * prev.w + i) * 4;
  prev.px[top] = sp[so]; prev.px[top + 1] = sp[so + 1]; prev.px[top + 2] = sp[so + 2];
  // fundo: arte com linhas 27..41 (texto) preservadas e o resto trocado pelo fundo de y=72
  let c = (cy >= 26 && cy < 42) ? [sp[so], sp[so + 1], sp[so + 2]] : (() => { const o2 = (72 * src.w + Math.floor(cx)) * 4; return [sp[o2], sp[o2 + 1], sp[o2 + 2]]; })();
  c = c.slice();
  if (cy >= 26 && cy < 42 && Math.abs(cx - FL.x) < 160) { // remove o clarão já presente no fundo do texto
    const f = flareAt(cx - FL.x, cy - FL.y); for (let k = 0; k < 3; k++) c[k] = Math.max(0, c[k] - f[k]);
  }
  const add = (im, u, v, a = 1) => { if (u < 0 || u > 1 || v < 0 || v > 1) return; const s = sample(im, u, v); for (let k = 0; k < 3; k++) c[k] += s[k] * a; };
  add(line, (cx - LINE.x0) / (LINE.x1 - LINE.x0), (cy - LINE.y) / 4 + 0.5, 0.20 * 255 / 255);
  add(flare, (cx - FL.x) / FLARE.spanX + 0.5, (cy - FL.y) / FLARE.spanY + 0.5);
  add(chev, (cx - CH.x) / 16 + 0.5, (cy - CH.y + 4.2) / 16);
  const bot = ((j + RH * S) * prev.w + i) * 4;
  for (let k = 0; k < 3; k++) prev.px[bot + k] = Math.min(255, c[k]);
}
I.writePNG(path.join(PREV, "nav-compare.png"), prev);
console.log("ok: NavFlare, NavLine, NavChevron + preview/nav-compare.png");
