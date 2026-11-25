// Gera as texturas da HUD "Azaath" (barras de ação + vida/recurso/XP + medalhão)
// a partir da arte de conceito (tools/actionbar-concept/concept.png, 1376x768):
//   * esvazia os 24 espaços (copia o espaço vazio do próprio conceito);
//   * apaga caixinhas de tecla, números, buffs e o anel de brilho do slot "0";
//   * troca o preenchimento das barras pelo trilho vazio e recorta os
//     preenchimentos/fagulhas para o jogo desenhar por cima;
//   * separa a arte do chão de pedra (transparência por diferença de fundo);
//   * extrai camadas aditivas: brilho ciano (pulsa) e anel de proc.
// Também grava AzaathUI/Modules/AzaathLayoutData.lua com as coordenadas.
// Uso: node tools/actionbar-concept/gen.js
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const ROOT = path.join(__dirname, "..", "..", "AzaathUI");
const OUT = path.join(ROOT, "Media", "Azaath");
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(OUT, { recursive: true });
fs.mkdirSync(PREV, { recursive: true });

const src = readPNG(path.join(__dirname, "concept.png"));
const W = src.w, H = src.h;
const clone = (im) => ({ w: im.w, h: im.h, px: Float32Array.from(im.px) });
const C = clone(src); // imagem limpa (vai sendo editada)

const get = (im, x, y) => { const o = (y * im.w + x) * 4; return [im.px[o], im.px[o + 1], im.px[o + 2]]; };
const set = (im, x, y, c) => { const o = (y * im.w + x) * 4; im.px[o] = c[0]; im.px[o + 1] = c[1]; im.px[o + 2] = c[2]; };
const lum = (c) => 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2];
const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const smooth = (e0, e1, v) => { const t = clamp((v - e0) / (e1 - e0)); return t * t * (3 - 2 * t); };

// copia um retângulo de uma foto (snap) para C
function copyRect(snap, sx, sy, w, h, dx, dy) {
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) set(C, dx + i, dy + j, get(snap, sx + i, sy + j));
}

// preenchimento harmônico (Laplace) dos pixels mascarados num retângulo
function inpaint(im, x0, y0, x1, y1, maskFn) {
  const w = x1 - x0 + 1, h = y1 - y0 + 1, m = new Uint8Array(w * h);
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) m[j * w + i] = maskFn(x0 + i, y0 + j) ? 1 : 0;
  // dilata 1 px (anti-aliasing do texto)
  const md = Uint8Array.from(m);
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (m[j * w + i])
    for (let dj = -1; dj <= 1; dj++) for (let di = -1; di <= 1; di++) {
      const ii = i + di, jj = j + dj; if (ii >= 0 && jj >= 0 && ii < w && jj < h) md[jj * w + ii] = 1;
    }
  let acc = [0, 0, 0], n = 0;
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (!md[j * w + i]) { const c = get(im, x0 + i, y0 + j); acc[0] += c[0]; acc[1] += c[1]; acc[2] += c[2]; n++; }
  const mean = n ? acc.map((v) => v / n) : [20, 20, 24];
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (md[j * w + i]) set(im, x0 + i, y0 + j, mean);
  for (let it = 0; it < 1500; it++) for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    if (!md[j * w + i]) continue;
    const x = x0 + i, y = y0 + j; const s = [0, 0, 0]; let c = 0;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const xx = x + dx, yy = y + dy;
      if (xx < x0 - 1 || yy < y0 - 1 || xx > x1 + 1 || yy > y1 + 1) continue;
      const p = get(im, xx, yy); s[0] += p[0]; s[1] += p[1]; s[2] += p[2]; c++;
    }
    set(im, x, y, s.map((v) => v / c));
  }
}

// ---------------------------------------------------------------------------
// Geometria medida no conceito (px)
// ---------------------------------------------------------------------------
const LX = [0, 1, 2, 3, 4, 5].map((i) => Math.round(86 + 54.8 * i)); // painel esquerdo
const LY = [343, 424], LS = 44, LINSET = 5;
const RX = [0, 1, 2, 3, 4, 5].map((i) => Math.round(921 + 64.2 * i)); // painel direito
const RY = [311, 409], RS = 54, RINSET = 6;
const HUD = { x: 36, y: 255, w: 1304, h: 296 }; // área total da HUD
const TABS = [{ x: 85, y: 292, w: 46, h: 46 }, { x: 131, y: 292, w: 46, h: 46 }];

// ---------------------------------------------------------------------------
// 1. Painel esquerdo: apaga as teclas (colunas 1, 2 e 5) copiando a faixa
//    da coluna 3 (sem tecla) e esvazia os 12 espaços
// ---------------------------------------------------------------------------
{
  const snap = clone(C);
  for (const k of [0, 1, 4]) copyRect(snap, LX[2] - 4, 387, 54, 30, LX[k] - 4, 387);
  const snap2 = clone(C);
  for (const y of LY) for (const x of LX) copyRect(snap2, LX[2] - 2, LY[0] - 2, LS + 4, LS + 4, x - 2, y - 2);
}

// ---------------------------------------------------------------------------
// 2. Painel direito: teclas da 1ª fileira ficam sobre o divisor (copia a
//    coluna de pixels do vão entre caixinhas); depois a faixa de baixo das
//    colunas 3-5 (com o anel de brilho) é refeita a partir da coluna 2
// ---------------------------------------------------------------------------
{
  for (let i = 0; i < 6; i++) {
    const cx = RX[i] + 27, gx = i < 5 ? RX[i] + 59 : RX[i] - 5;
    for (let x = cx - 18; x <= cx + 18; x++) for (let y = 364; y <= 393; y++) set(C, x, y, get(C, gx, y));
    // 2ª fileira: o topo das caixinhas encosta na borda de baixo do painel
    for (let x = cx - 18; x <= cx + 18; x++) for (let y = 462; y <= 492; y++) set(C, x, y, get(C, gx, y));
  }
  const snap = clone(C);
  for (const k of [2, 3, 4]) copyRect(snap, RX[1] - 5, 364, 66, 160, RX[k] - 5, 364);
  // espaço vazio "=" (coluna 6, fileira 2); canto inferior direito tem a gema: espelha
  const T = { w: RS + 4, h: RS + 4, px: null };
  const tpl = I.crop(src, RX[5] - 2, RY[1] - 2, T.w, T.h);
  for (let j = T.h - 9; j < T.h; j++) for (let i = T.w - 9; i < T.w; i++) {
    const o = (j * T.w + i) * 4, q = (j * T.w + (T.w - 1 - i)) * 4;
    for (let k = 0; k < 3; k++) tpl.px[o + k] = tpl.px[q + k];
  }
  for (const y of RY) for (const x of RX)
    for (let j = 0; j < T.h; j++) for (let i = 0; i < T.w; i++) { const o = (j * T.w + i) * 4; set(C, x - 2 + i, y - 2 + j, [tpl.px[o], tpl.px[o + 1], tpl.px[o + 2]]); }
}

// ---------------------------------------------------------------------------
// 3. Anel de proc (slot "0"): brilho = conceito - painel limpo
// ---------------------------------------------------------------------------
const PROC = { cx: RX[3] + 27, cy: RY[1] + 27, r: 64 };
{
  const n = PROC.r * 2, im = I.create(n, n);
  const inRect = (x, y, x0, y0, x1, y1) => x >= x0 && x <= x1 && y >= y0 && y <= y1;
  const diffAt = (x, y) => { const a = get(src, x, y), b = get(C, x, y); return [0, 1, 2].map((k) => Math.max(0, a[k] - b[k])); };
  const cx = PROC.cx, cy = PROC.cy;
  for (let j = 0; j < n; j++) for (let i = 0; i < n; i++) {
    const x = cx - PROC.r + i, y = cy - PROC.r + j, dx = x - cx, dy = y - cy;
    const r = Math.hypot(dx, dy);
    let d;
    if (inRect(x, y, RX[3] + RINSET - 1, RY[1] + RINSET - 1, RX[3] + RS - RINSET, RY[1] + RS - RINSET)) d = [0, 0, 0]; // ícone
    else if (inRect(x, y, cx - 18, 462, cx + 18, 492)) d = diffAt(cx - dy, cy + dx);         // tecla "0"
    else if (inRect(x, y, cx - 18, 362, cx + 18, 393)) d = diffAt(cx + dy, cy - dx);         // tecla "4"
    else if (inRect(x, y, RX[4] + 1, RY[1] - 1, RX[4] + RS + 2, RY[1] + RS + 1)) d = diffAt(2 * cx - x, y); // ícone "-"
    else d = diffAt(x, y);
    const fall = 1 - smooth(PROC.r - 10, PROC.r, r);
    const o = (j * n + i) * 4;
    const m = Math.max(d[0], d[1], d[2]) * fall;
    const a = clamp(m / 255);
    im.px[o + 3] = a * 255;
    for (let k = 0; k < 3; k++) im.px[o + k] = a > 0 ? clamp(d[k] * fall / (a * 255)) * 255 : 0;
  }
  const out = I.create(128, 128); I.blit(out, I.resize(im, 128, 128), 0, 0);
  I.writeTGA(path.join(OUT, "Proc.tga"), out); I.writePNG(path.join(PREV, "proc.png"), out);
}

// ---------------------------------------------------------------------------
// 4. Centro: barras, textos e nível
// ---------------------------------------------------------------------------
const F = clone(src); // cópia do conceito para recortar preenchimentos (texto apagado)
inpaint(F, 636, 364, 742, 396, (x, y) => lum(get(src, x, y)) > 100);                     // "756 / 756"

const isOrange = (c) => smooth(14, 30, c[0] - c[1]) * smooth(25, 70, c[0]) * (c[1] > c[2] ? 1 : 0);
const isCrimson = (c) => smooth(12, 40, c[0] - Math.max(c[1], c[2]));
const isCyan = (c) => smooth(20, 60, Math.min(c[1], c[2]) - c[0]) * smooth(70, 120, c[2]);

function rowProfile(im, x0, x1, y) { const s = [0, 0, 0]; for (let x = x0; x <= x1; x++) { const c = get(im, x, y); s[0] += c[0]; s[1] += c[1]; s[2] += c[2]; } return s.map((v) => v / (x1 - x0 + 1)); }

// bbox da máscara
function bbox(x0, y0, x1, y1, fn, thr = 0.5) {
  let a = 1e9, b = 1e9, c = -1, d = -1;
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) if (fn(x, y) >= thr) { a = Math.min(a, x); b = Math.min(b, y); c = Math.max(c, x); d = Math.max(d, y); }
  return { x0: a, y0: b, x1: c, y1: d };
}

const BARS = {};
// Trilhos (medidos): retângulo interno de cada barra; nas pontas chanfradas
// (x < 482 ou x > 860) só troca o que a máscara de cor reconhece.
const BAR = {
  power:  { x0: 468, x1: 875, y0: 338, y1: 350, fillEnd: 786, tip: 807, mask: isOrange, src: src },
  health: { x0: 468, x1: 877, y0: 362, y1: 397, fillEnd: 877, mask: isCrimson, src: F },
  xp:     { x0: 469, x1: 875, y0: 405, y1: 411, fillEnd: 816, tip: 822, mask: isCyan, src: src },
};
const inner = (x) => x >= 482 && x <= 860;
function emptyBar(b, troughOf) {
  for (let y = b.y0 - 1; y <= b.y1 + (b.tip ? 3 : 1); y++) for (let x = b.x0 - 14; x <= b.x1 + 4; x++) {
    const c = get(b.src, x, y), t = troughOf(y, c);
    let a = b.mask(c);
    if (y >= b.y0 && y <= b.y1 && inner(x)) a = 1;
    if (b.tip && x > b.fillEnd - 30 && x <= b.tip + 16 && y >= b.y0 - 1 && y <= b.y1 + 3) a = Math.max(a, smooth(4, 30, lum(c) - lum(t)));
    if (a > 0) set(C, x, y, [0, 1, 2].map((k) => c[k] * (1 - a) + t[k] * a));
  }
}
function fillTex(name, b, potW, potH) {
  const w = b.fillEnd - b.x0 + 1, h = b.y1 - b.y0 + 1, crop = I.create(w, h);
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const x = b.x0 + i, y = b.y0 + j, c = get(b.src, x, y), o = (j * w + i) * 4;
    crop.px[o] = c[0]; crop.px[o + 1] = c[1]; crop.px[o + 2] = c[2];
    crop.px[o + 3] = 255 * (inner(x) ? 1 : clamp(b.mask(c) * 1.4));
  }
  const out = I.resize(crop, potW, potH);
  I.writeTGA(path.join(OUT, name + ".tga"), out); I.writePNG(path.join(PREV, name + ".png"), out);
  return { x: b.x0, y: b.y0, w: b.x1 - b.x0 + 1, h };
}
// fagulha da ponta: conceito - trilho (aditivo)
function sparkTex(name, x0, y0, w, h, fade, potW, potH) {
  const sp = I.create(w, h);
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const x = x0 + i, y = y0 + j, a = get(src, x, y), b = get(C, x, y);
    const d = [0, 1, 2].map((k) => Math.max(0, a[k] - b[k]));
    const fx = smooth(0, fade, i) * (1 - smooth(w - fade / 2, w, i)) * smooth(0, 3, j) * (1 - smooth(h - 3, h, j));
    const m = clamp(Math.max(...d) / 255) * fx, o = (j * w + i) * 4;
    sp.px[o + 3] = m * 255; for (let k = 0; k < 3; k++) sp.px[o + k] = m > 0 ? clamp(d[k] * fx / (m * 255)) * 255 : 0;
  }
  const out = I.resize(sp, potW, potH);
  I.writeTGA(path.join(OUT, name + ".tga"), out); I.writePNG(path.join(PREV, name + ".png"), out);
  return { x: x0, y: y0, w, h };
}

// --- recurso (laranja) ---
{
  const b = BAR.power, tr = [];
  for (let y = b.y0 - 4; y <= b.y1 + 4; y++) tr[y] = rowProfile(src, 828, 868, y);
  emptyBar(b, (y) => tr[y]);
  BARS.power = fillTex("PowerFill", b, 512, 16);
  BARS.power.tip = b.tip;
  BARS.powerSpark = sparkTex("PowerSpark", 770, b.y0 - 8, 60, b.y1 - b.y0 + 17, 16, 64, 32);
  // chama que corre por cima do preenchimento (só as listras claras, repetível)
  const fl = I.create(256, 16), fw = b.fillEnd - 30 - (b.x0 + 16);
  for (let j = 0; j < 16; j++) for (let i = 0; i < 256; i++) {
    const y = b.y0 + Math.round(j * (b.y1 - b.y0) / 15);
    const t = i / 256, xa = b.x0 + 16 + t * fw, xb = b.x0 + 16 + ((t + 0.5) % 1) * fw;
    const ca = get(src, Math.round(xa), y), cb = get(src, Math.round(xb), y);
    const wa = 0.5 + 0.5 * Math.cos(2 * Math.PI * t); // costura sem emenda
    const c = [0, 1, 2].map((k) => ca[k] * wa + cb[k] * (1 - wa));
    const hi = smooth(140, 230, lum(c)), o = (j * 256 + i) * 4;
    fl.px[o] = 255; fl.px[o + 1] = 196; fl.px[o + 2] = 104; fl.px[o + 3] = hi * 255;
  }
  I.writeTGA(path.join(OUT, "Flame.tga"), fl); I.writePNG(path.join(PREV, "Flame.png"), fl);
}

// --- vida (carmim): o conceito está cheio, o trilho é o próprio carmim escurecido ---
{
  const b = BAR.health;
  emptyBar(b, (y, c) => [c[0] * 0.22 + 5, c[1] * 0.22 + 5, c[2] * 0.26 + 9]);
  BARS.health = fillTex("HealthFill", b, 512, 64);
  BARS.health.text = { x: 687, y: 381 };
}

// --- XP (ciano) ---
{
  const b = BAR.xp, tr = [];
  for (let y = b.y0 - 4; y <= b.y1 + 4; y++) tr[y] = rowProfile(src, 830, 868, y);
  emptyBar(b, (y) => tr[y]);
  BARS.xp = fillTex("XPFill", b, 512, 8);
  BARS.xp.tip = b.tip;
  BARS.xpSpark = sparkTex("XPSpark", 800, b.y0 - 6, 34, b.y1 - b.y0 + 13, 10, 32, 32);
  BARS.xp.text = { x: 730, y: 423 };
}

// --- textos fixos da arte: "XP 85.3%" e o nível "21" ---
// "XP 85.3%": a faixa sob a XP é quase uniforme na horizontal -> copia de 220 px à esquerda
for (let y = 414; y <= 432; y++) for (let x = 724; x <= 790; x++) set(C, x, y, get(C, x - 220, y));
const LEVEL = { x: 686, y: 474 };
inpaint(C, LEVEL.x - 20, LEVEL.y - 16, LEVEL.x + 20, LEVEL.y + 16, (x, y) => Math.hypot(x - LEVEL.x, y - LEVEL.y) < 22); // disco inteiro: degradê liso

// ---------------------------------------------------------------------------
// 5. Abas CF1/CF2 (inteiras) e as molduras ouro/aço (para trocar a ativa)
// ---------------------------------------------------------------------------
{
  const names = ["Tab1", "Tab2"], rings = ["TabGold", "TabSteel"];
  TABS.forEach((t, k) => {
    const full = I.create(64, 64); I.blit(full, I.resize(I.crop(src, t.x, t.y, t.w, t.h), 64, 64), 0, 0);
    I.writeTGA(path.join(OUT, names[k] + ".tga"), full); I.writePNG(path.join(PREV, names[k] + ".png"), full);
    const ring = clone(full);
    const inset = 6 * 64 / t.w;
    for (let j = 0; j < 64; j++) for (let i = 0; i < 64; i++) {
      const d = Math.min(i, j, 63 - i, 63 - j);
      ring.px[(j * 64 + i) * 4 + 3] = 255 * (1 - smooth(inset - 1, inset + 0.5, d));
    }
    I.writeTGA(path.join(OUT, rings[k] + ".tga"), ring); I.writePNG(path.join(PREV, rings[k] + ".png"), ring);
  });
}

// ---------------------------------------------------------------------------
// 6. Caixinha de tecla (da "M5", sem o texto), cantos arredondados
// ---------------------------------------------------------------------------
const KEY = { x: LX[1] + 1, y: 390, w: 43, h: 24 };
{
  const k = I.crop(src, KEY.x, KEY.y, KEY.w, KEY.h);
  const kk = { w: k.w, h: k.h, px: k.px };
  inpaint(kk, 8, 5, KEY.w - 9, KEY.h - 6, (x, y) => lum(get(kk, x, y)) > 70);
  const r = 6;
  for (let j = 0; j < k.h; j++) for (let i = 0; i < k.w; i++) {
    const qx = Math.max(r - i - 0.5, i + 0.5 - (k.w - r), 0), qy = Math.max(r - j - 0.5, j + 0.5 - (k.h - r), 0);
    const dist = Math.hypot(qx, qy) - r;
    k.px[(j * k.w + i) * 4 + 3] = 255 * (1 - smooth(-0.5, 0.8, dist));
  }
  const out = I.create(64, 32); I.blit(out, I.resize(k, 64, 32), 0, 0);
  I.writeTGA(path.join(OUT, "Key.tga"), out); I.writePNG(path.join(PREV, "Key.png"), out);
}

// ---------------------------------------------------------------------------
// 6b. Colchetes dourados das laterais da moldura central (23/11): a borda de
//     fora de cada colchete foi medida linha a linha no conceito (px do
//     conceito). Onde a gema ciano cobre o filete, ele é redesenhado copiando
//     o perfil de uma linha limpa; o vão entre o filete e as barras é
//     preenchido com o fundo escuro da própria moldura (Laplace).
// ---------------------------------------------------------------------------
const lerpPts = (pts) => (y) => {
  if (y <= pts[0][1]) return pts[0][0];
  for (let k = 1; k < pts.length; k++) if (y <= pts[k][1]) {
    const [x0, y0] = pts[k - 1], [x1, y1] = pts[k];
    return x0 + (x1 - x0) * (y - y0) / (y1 - y0);
  }
  return pts[pts.length - 1][0];
};
const BRACKET = {
  y0: 328, y1: 437, // acima de 328 só há o fundo do conceito
  // borda de fora (esquerda) do colchete esquerdo
  L: lerpPts([[466, 328], [466, 330], [463, 333], [461, 335], [460, 337], [459, 339], [457, 341], [455, 343], [453, 345], [454, 347], [456, 352], [456, 369],
    [455, 400], [455, 405], [457, 410], [460, 415], [462, 420], [463, 425], [466, 430], [469, 434], [470, 437]]),
  // borda de fora (direita) do colchete direito
  R: lerpPts([[880, 328], [881, 331], [882, 333], [884, 335], [885, 337], [887, 339], [891, 341], [893, 343], [892, 346], [890, 350], [889, 356],
    [889, 405], [889, 410], [888, 413], [885, 416], [884, 419], [883, 422], [881, 425], [879, 430], [876, 434], [874, 437]]),
};
{
  const isCy = (c) => Math.min(c[1], c[2]) - c[0] > 18;
  const ref = clone(C), REF = 362, SW = 4;
  // esquerda: filete coberto nas linhas 366..400
  for (let y = 366; y <= 400; y++) {
    const e = Math.round(BRACKET.L(y)), er = Math.round(BRACKET.L(REF));
    for (let x = e; x <= 462; x++) set(C, x, y, get(ref, er + (x - e), REF)); // filete + vão, da linha limpa
  }
  inpaint(C, 452, 364, 470, 402, (x, y) => {
    const e = BRACKET.L(y);
    return x >= e + SW && x <= 470 && isCy(get(C, x, y));
  });
  // direita: filete coberto nas linhas 370..402
  for (let y = 370; y <= 402; y++) {
    const e = Math.round(BRACKET.R(y)), er = Math.round(BRACKET.R(REF));
    for (let x = e; x >= 880; x--) set(C, x, y, get(ref, er - (e - x), REF)); // filete + vão, da linha limpa
  }
  inpaint(C, 864, 368, 892, 404, (x, y) => {
    const e = BRACKET.R(y);
    return x <= e - SW && x >= 864 && isCy(get(C, x, y));
  });
  // ciano solto nas pontas dos colchetes (fora das faixas acima)
  inpaint(C, 452, 328, 472, 437, (x, y) => x >= BRACKET.L(y) + 3 && isCy(get(C, x, y)));
  inpaint(C, 862, 328, 894, 437, (x, y) => x <= BRACKET.R(y) - 3 && isCy(get(C, x, y)));
}

// ---------------------------------------------------------------------------
// 7. Transparência: fundo estimado (Laplace a partir da borda da área) e
//    alpha pela diferença de brilho/cor; regiões sólidas ficam opacas
// ---------------------------------------------------------------------------
const Bg = (() => {
  const s = 4, gw = Math.ceil(HUD.w / s) + 1, gh = Math.ceil(HUD.h / s) + 1;
  const g = new Float32Array(gw * gh * 3), fixed = new Uint8Array(gw * gh);
  for (let j = 0; j < gh; j++) for (let i = 0; i < gw; i++) {
    const x = Math.min(W - 1, HUD.x + i * s), y = Math.min(H - 1, HUD.y + j * s);
    if (i === 0 || j === 0 || i === gw - 1 || j === gh - 1) {
      // média 5x5 na borda
      const acc = [0, 0, 0]; let n = 0;
      for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) { const c = get(src, Math.min(W - 1, x + dx), Math.min(H - 1, y + dy)); acc[0] += c[0]; acc[1] += c[1]; acc[2] += c[2]; n++; }
      for (let k = 0; k < 3; k++) g[(j * gw + i) * 3 + k] = acc[k] / n;
      fixed[j * gw + i] = 1;
    }
  }
  for (let it = 0; it < 3000; it++) for (let j = 1; j < gh - 1; j++) for (let i = 1; i < gw - 1; i++) {
    const o = (j * gw + i) * 3;
    for (let k = 0; k < 3; k++) {
      const v = (g[o - 3 + k] + g[o + 3 + k] + g[o - gw * 3 + k] + g[o + gw * 3 + k]) / 4;
      g[o + k] += 1.6 * (v - g[o + k]);
    }
  }
  return (x, y) => {
    const fx = (x - HUD.x) / s, fy = (y - HUD.y) / s;
    const i0 = clamp(Math.floor(fx), 0, gw - 2), j0 = clamp(Math.floor(fy), 0, gh - 2), tx = fx - i0, ty = fy - j0;
    const p = (i, j, k) => g[(j * gw + i) * 3 + k];
    return [0, 1, 2].map((k) => (p(i0, j0, k) * (1 - tx) + p(i0 + 1, j0, k) * tx) * (1 - ty) + (p(i0, j0 + 1, k) * (1 - tx) + p(i0 + 1, j0 + 1, k) * tx) * ty);
  };
})();

const SOLID = [
  (x, y) => x >= 78 && x <= 410 && y >= 335 && y <= 476,      // painel esquerdo
  (x, y) => x >= 915 && x <= 1302 && y >= 304 && y <= 468,    // painel direito
  (x, y) => x >= 470 && x <= 872 && y >= 331 && y <= 436,     // moldura central
  (x, y) => Math.hypot(x - LEVEL.x, y - LEVEL.y) <= 44,        // medalhão
];
const ZERO = [
  (x, y) => x >= 455 && x <= 618 && y >= 262 && y <= 318,      // buffs do conceito
  (x, y) => x >= 455 && x <= 612 && y >= 262 && y <= 328,
  (x, y) => y >= 492 && !(x >= 600 && x <= 772),                // chão abaixo dos painéis
  (x, y) => y < 286 && !(x >= 620 && x <= 752),                 // acima (fora a crista)
  (x, y) => (x < 48 || x > 1334),
  (x, y) => x >= 926 && x <= 1289 && y >= 470,                  // teclas da 2ª fileira (direita)
  (x, y) => TABS.some((t) => x >= t.x && x < t.x + t.w && y >= t.y && y < t.y + t.h - 3), // abas (texturas próprias)
];

const O = I.create(HUD.w, HUD.h);
for (let j = 0; j < HUD.h; j++) for (let i = 0; i < HUD.w; i++) {
  const x = HUD.x + i, y = HUD.y + j, c = get(C, x, y), o = (j * HUD.w + i) * 4;
  let a;
  if (ZERO.some((f) => f(x, y))) a = 0;
  else if (SOLID.some((f) => f(x, y))) a = 1;
  else {
    const b = Bg(x, y);
    const dl = lum(c) - lum(b);
    const chroma = Math.hypot(c[0] - b[0] - dl, c[1] - b[1] - dl, c[2] - b[2] - dl);
    a = smooth(12, 60, Math.max(dl, 0) + 0.8 * chroma);
  }
  O.px[o + 3] = a * 255;
  if (a > 0 && a < 1) {
    const b = Bg(x, y);
    for (let k = 0; k < 3; k++) O.px[o + k] = clamp(b[k] + (c[k] - b[k]) / a, 0, 255);
  } else for (let k = 0; k < 3; k++) O.px[o + k] = c[k];
}

// ---------------------------------------------------------------------------
// 7b. Moldura central sozinha (23/11): fica só o que está dentro dos colchetes
//     (borda medida em 6b, com 1 px de suavização); dentro deles é opaco.
//     Fora da altura dos colchetes, as laterais ficam vazias.
// ---------------------------------------------------------------------------
{
  for (let j = 0; j < HUD.h; j++) for (let i = 410; i < 862; i++) {
    const X = i + HUD.x, Y = j + HUD.y, o = (j * HUD.w + i) * 4;
    if (X >= 476 && X <= 864) continue; // corpo da moldura, crista e medalhão: como estava
    let a;
    if (Y < BRACKET.y0 || Y > BRACKET.y1) a = 0;
    else if (X < 476) a = smooth(BRACKET.L(Y) - 0.5, BRACKET.L(Y) + 0.7, X);
    else a = 1 - smooth(BRACKET.R(Y) - 0.7, BRACKET.R(Y) + 0.5, X);
    const c = get(C, X, Y);
    O.px[o] = c[0]; O.px[o + 1] = c[1]; O.px[o + 2] = c[2];
    // topo dos chanfros: borda de cima medida (sobe da ponta até o filete de cima)
    const top = X < 476 ? 328 + (X - 466) * 3 / 7 : 331 - (X - 866) * 4 / 14;
    if ((X < 476 && X >= 466) || (X > 864 && X <= 880)) a *= smooth(top - 0.7, top + 0.5, Y);
    O.px[o + 3] = a * 255;
  }
}

// ---------------------------------------------------------------------------
// 8. Peças (esquerda / centro / direita) em 512x512 e camada de brilho
//    O centro chama "HudCenter" (nome novo: o jogo guarda a textura antiga)
// ---------------------------------------------------------------------------
const PIECES = [
  { name: "Left", x0: 36, x1: 436 },
  { name: "HudCenter", x0: 450, x1: 896 },
  { name: "Right", x0: 912, x1: 1340 },
];
for (const p of PIECES) {
  const out = I.create(512, 512);
  I.blit(out, I.crop(O, p.x0 - HUD.x, 0, p.x1 - p.x0, HUD.h), 0, 0);
  I.writeTGA(path.join(OUT, p.name + ".tga"), out); I.writePNG(path.join(PREV, p.name + ".png"), out);
}
// brilho ciano (aditivo, meia resolução)
{
  const gl = I.create(HUD.w, HUD.h);
  for (let j = 0; j < HUD.h; j++) for (let i = 0; i < HUD.w; i++) {
    const o = (j * HUD.w + i) * 4, c = [O.px[o], O.px[o + 1], O.px[o + 2]], a = O.px[o + 3] / 255;
    const cy = smooth(25, 90, Math.min(c[1], c[2]) - c[0]) * smooth(110, 200, Math.max(c[1], c[2])) * a;
    gl.px[o] = c[0]; gl.px[o + 1] = c[1]; gl.px[o + 2] = c[2]; gl.px[o + 3] = cy * 255;
  }
  const half = I.resize(gl, HUD.w / 2, HUD.h / 2);
  const out = I.create(1024, 256); I.blit(out, half, 0, 0);
  I.writeTGA(path.join(OUT, "HudGlow.tga"), out); I.writePNG(path.join(PREV, "glow.png"), out);
}

// prévias: arte limpa sobre cinza e sobre o conceito original
{
  const pv = I.create(HUD.w, HUD.h, 70, 90, 70, 255);
  for (let i = 0; i < HUD.w * HUD.h; i++) {
    const a = O.px[i * 4 + 3] / 255;
    for (let k = 0; k < 3; k++) pv.px[i * 4 + k] = O.px[i * 4 + k] * a + pv.px[i * 4 + k] * (1 - a);
  }
  I.writePNG(path.join(PREV, "hud-on-green.png"), pv);
  const cl = I.crop(C, HUD.x, HUD.y, HUD.w, HUD.h);
  for (let i = 0; i < HUD.w * HUD.h; i++) cl.px[i * 4 + 3] = 255;
  I.writePNG(path.join(PREV, "hud-clean.png"), cl);
}

// ---------------------------------------------------------------------------
// 9. Dados para o Lua (coordenadas do conceito -> relativas à HUD)
// ---------------------------------------------------------------------------
const rel = (x, y) => [x - HUD.x, y - HUD.y];
const fmt = (v) => (Number.isInteger(v) ? String(v) : v.toFixed(2));
const tbl = (o) => "{ " + Object.entries(o).map(([k, v]) => `${k} = ${Array.isArray(v) ? "{ " + v.map(fmt).join(", ") + " }" : typeof v === "object" ? tbl(v) : fmt(v)}`).join(", ") + " }";
const rect = (r) => { const [x, y] = rel(r.x, r.y); return { x, y, w: r.w, h: r.h }; };
const D = {
  hud: { w: HUD.w, h: HUD.h },
  pieces: PIECES.map((p) => ({ x: p.x0 - HUD.x, w: p.x1 - p.x0 })),
  left: { x: LX.map((v) => v - HUD.x), y: LY.map((v) => v - HUD.y), size: LS, inset: LINSET },
  right: { x: RX.map((v) => v - HUD.x), y: RY.map((v) => v - HUD.y), size: RS, inset: RINSET },
  tabs: TABS.map(rect),
  power: rect(BARS.power), powerSpark: rect(BARS.powerSpark), powerTip: BARS.power.tip - BARS.power.x,
  health: rect(BARS.health), healthText: rel(BARS.health.text.x, BARS.health.text.y),
  xp: rect(BARS.xp), xpSpark: rect(BARS.xpSpark), xpTip: BARS.xp.tip - BARS.xp.x, xpText: rel(BARS.xp.text.x, BARS.xp.text.y),
  level: rel(LEVEL.x, LEVEL.y),
  proc: { size: PROC.r * 2 },
  buffs: { x: 464 - HUD.x, y: 309 - HUD.y, size: 34, spacing: 6 },
  key: { w: KEY.w, h: KEY.h },
};
let lua = "-- GERADO por tools/actionbar-concept/gen.js: não editar à mão.\n";
lua += "-- Coordenadas da HUD Azaath em px do conceito, relativas ao canto superior esquerdo da HUD.\n";
lua += "local _, Azaath = ...\nAzaath.AZAATH = {\n";
for (const [k, v] of Object.entries(D)) {
  if (Array.isArray(v)) lua += `    ${k} = { ${v.map((e) => (typeof e === "object" ? tbl(e) : fmt(e))).join(", ")} },\n`;
  else lua += `    ${k} = ${typeof v === "object" ? tbl(v) : fmt(v)},\n`;
}
lua += "}\n";
fs.writeFileSync(path.join(ROOT, "Modules", "AzaathLayoutData.lua"), lua);
fs.writeFileSync(path.join(PREV, "layout.js"), "window.AZ = " + JSON.stringify({ ...D, origin: HUD }) + ";");
console.log(lua);
