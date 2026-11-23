// Card do talento (painel à direita do Crisol) a partir da arte de conceito
// tools/card-concept/concept.webp (896x1200; concept.png é o "print" do Edge:
//   msedge --headless=new --window-size=896,1200 --screenshot=concept.png shot.html).
//
// Sai em Media/Talents/ (sobre arquivos antigos do astrolábio que não eram mais
// usados: trocar um arquivo que já existe vale com /reload, sem reiniciar):
//   TalentBG.tga        o card inteiro (coroa, moldura, placa, círculo rúnico,
//                       pílulas, caixa da descrição e os três botões) SEM textos,
//                       ícone e losangos — o jogo desenha esses por cima.
//                       Recorte x 170..730, y 40..1130 da arte -> 512x997.
//   TalentArtIcons.tga  só o brilho ciano das runas (coroa e círculo), para pulsar
//   TalentBtnApply.tga  losango de grau aceso (célula 0) e apagado (célula 1), 64x64
//
// Uso: node tools/card-concept/gen.js

const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const OUT_WS = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Talents");
const OUT_GAME = "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Talents";
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(PREV, { recursive: true });

let seed = 98765;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };

const src = readPNG(path.join(__dirname, "concept.png"));
const W = src.w, H = src.h;
const clone = (im) => ({ w: im.w, h: im.h, px: Float32Array.from(im.px) });
const img = clone(src), snap = clone(src);
const get = (im, x, y) => {
  x = Math.max(0, Math.min(im.w - 1, Math.round(x))); y = Math.max(0, Math.min(im.h - 1, Math.round(y)));
  const o = (y * im.w + x) * 4; return [im.px[o], im.px[o + 1], im.px[o + 2]];
};
const bil = (im, x, y) => {
  x = Math.max(0, Math.min(im.w - 1.001, x)); y = Math.max(0, Math.min(im.h - 1.001, y));
  const xi = Math.floor(x), yi = Math.floor(y), tx = x - xi, ty = y - yi;
  return [0, 1, 2].map((k) => {
    const p = (a, b) => im.px[(b * im.w + a) * 4 + k];
    return (p(xi, yi) * (1 - tx) + p(xi + 1, yi) * tx) * (1 - ty) + (p(xi, yi + 1) * (1 - tx) + p(xi + 1, yi + 1) * tx) * ty;
  });
};
const set = (im, x, y, c) => {
  if (x < 0 || y < 0 || x >= im.w || y >= im.h) return;
  const o = (y * im.w + x) * 4; im.px[o] = c[0]; im.px[o + 1] = c[1]; im.px[o + 2] = c[2];
};
const lumC = (c) => 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2];
const clamp01 = (v) => Math.max(0, Math.min(1, v));

// --- máscara + difusão ---------------------------------------------------------
let MASK = new Uint8Array(W * H);
function markRect(x0, y0, x1, y1) {
  for (let y = Math.max(0, y0); y <= Math.min(H - 1, y1); y++)
    for (let x = Math.max(0, x0); x <= Math.min(W - 1, x1); x++) MASK[y * W + x] = 1;
}
function fill(x0, y0, x1, y1, grain = 0.8, iters = 220) {
  const pts = [];
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) if (MASK[y * W + x]) pts.push(y * W + x);
  const known = new Uint8Array(W * H);
  for (let i = 0; i < W * H; i++) known[i] = MASK[i] ? 0 : 1;
  for (const r of [3, 6, 12, 24, 48, 96]) for (const p of pts) {
    if (known[p] === 2) continue;
    const px = p % W, py = (p / W) | 0; let s0 = 0, s1 = 0, s2 = 0, n = 0; const st = Math.max(1, r >> 2);
    for (let dy = -r; dy <= r; dy += st) for (let dx = -r; dx <= r; dx += st) {
      const x = px + dx, y = py + dy;
      if (x < 0 || y < 0 || x >= W || y >= H || known[y * W + x] !== 1) continue;
      const w = 1 / (1 + dx * dx + dy * dy), c = get(img, x, y); s0 += c[0] * w; s1 += c[1] * w; s2 += c[2] * w; n += w;
    }
    if (n > 0) { set(img, px, py, [s0 / n, s1 / n, s2 / n]); known[p] = 2; }
  }
  for (let it = 0; it < iters; it++) for (const p of pts) {
    const x = p % W, y = (p / W) | 0;
    const a = get(img, x - 1, y), b = get(img, x + 1, y), c = get(img, x, y - 1), d = get(img, x, y + 1);
    set(img, x, y, [0, 1, 2].map((k) => (a[k] + b[k] + c[k] + d[k]) / 4));
  }
  for (const p of pts) { const n = (rnd() + rnd() + rnd() - 1.5) * grain, x = p % W, y = (p / W) | 0, c = get(img, x, y); set(img, x, y, [c[0] + n, c[1] + n, c[2] + n]); MASK[p] = 0; }
}
// faixa de texto: interpola entre a linha acima e a de baixo
function cleanBand(x0, y0, x1, y1) {
  for (let x = x0; x <= x1; x++) {
    const tc = get(img, x, y0 - 1), bc = get(img, x, y1 + 1);
    for (let y = y0; y <= y1; y++) {
      const t = (y - y0 + 1) / (y1 - y0 + 2), ex = clamp01(Math.min(x - x0, x1 - x) / 4), o = get(img, x, y);
      const f = [0, 1, 2].map((k) => tc[k] * (1 - t) + bc[k] * t + (rnd() - 0.5));
      set(img, x, y, [0, 1, 2].map((k) => f[k] * ex + o[k] * (1 - ex)));
    }
  }
}
// interior de pílula/botão: copia uma coluna limpa (preserva o degradê vertical)
function cleanPill(x0, y0, x1, y1, refX) {
  for (let y = y0; y <= y1; y++) {
    const rc = [0, 1, 2].map((k) => (get(img, refX, y)[k] + get(img, refX + 1, y)[k]) / 2);
    for (let x = x0; x <= x1; x++) {
      const a = clamp01(Math.min(x - x0, x1 - x) / 3), o = get(img, x, y);
      set(img, x, y, [0, 1, 2].map((k) => rc[k] * a + o[k] * (1 - a)));
    }
  }
}

// --- fundo "baixo" local (percentil 25 em blocos) para achar o que brilha ------
const BS = 16, GW = Math.ceil(W / BS), GH = Math.ceil(H / BS), low = new Float32Array(GW * GH);
for (let gy = 0; gy < GH; gy++) for (let gx = 0; gx < GW; gx++) {
  const v = [];
  for (let y = gy * BS - BS; y < gy * BS + 2 * BS; y += 2) for (let x = gx * BS - BS; x < gx * BS + 2 * BS; x += 2)
    if (x >= 0 && y >= 0 && x < W && y < H) v.push(lumC(get(snap, x, y)));
  v.sort((a, b) => a - b); low[gy * GW + gx] = v[Math.floor(v.length * 0.25)] || 0;
}
const bgLow = (x, y) => {
  const fx = Math.max(0, Math.min(GW - 1.001, x / BS - 0.5)), fy = Math.max(0, Math.min(GH - 1.001, y / BS - 0.5));
  const xi = Math.floor(fx), yi = Math.floor(fy), tx = fx - xi, ty = fy - yi, g = (a, b) => low[b * GW + a];
  return (g(xi, yi) * (1 - tx) + g(xi + 1, yi) * tx) * (1 - ty) + (g(xi, yi + 1) * (1 - tx) + g(xi + 1, yi + 1) * tx) * ty;
};

// ---------------------------------------------------------------------------
// 1. Losangos de grau (aceso = o dourado da esquerda, apagado = o do meio)
// ---------------------------------------------------------------------------
const diam = I.create(128, 64);
[[405, 624], [450, 626]].forEach(([cx, cy], cell) => {
  const R = 22; // meia-diagonal útil (inclui o brilho do aceso)
  for (let j = 0; j < 64; j++) for (let i = 0; i < 64; i++) {
    const dx = (i + 0.5 - 32) / 32 * R, dy = (j + 0.5 - 32) / 32 * R;
    const m = Math.abs(dx) + Math.abs(dy);
    const c = bil(snap, cx + dx, cy + dy);
    const a = clamp01((19.5 - m) / 1.5);
    const o = (j * 128 + cell * 64 + i) * 4;
    diam.px[o] = c[0]; diam.px[o + 1] = c[1]; diam.px[o + 2] = c[2]; diam.px[o + 3] = 255 * a;
  }
});

// ---------------------------------------------------------------------------
// 2. Brilho ciano das runas (coroa e círculo rúnico) para pulsar no jogo
// ---------------------------------------------------------------------------
const CRX = 450, CRY = 506; // centro do círculo rúnico / ícone
const glow = I.create(W, H);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const r = Math.hypot(x - CRX, y - CRY);
  const crown = y >= 50 && y <= 215 && x >= 290 && x <= 610;
  const ring = r >= 100 && r <= 140 && y < 640;
  if (!crown && !ring) continue;
  const c = get(snap, x, y);
  const ex = Math.max(0, Math.min(c[1], c[2]) - c[0] - 25);
  const a = clamp01(ex / 90) * clamp01((lumC(c) - 60) / 60);
  if (a < 0.03) continue;
  const o = (y * W + x) * 4;
  glow.px[o] = Math.min(255, c[0] * 1.1); glow.px[o + 1] = Math.min(255, c[1] * 1.15); glow.px[o + 2] = Math.min(255, c[2] * 1.2); glow.px[o + 3] = 255 * a;
}

// ---------------------------------------------------------------------------
// 3. Limpeza: textos, ícone, brilho dourado do ícone e losangos
// ---------------------------------------------------------------------------
cleanPill(314, 250, 586, 283, 306);           // ARMAS • CÍRCULO 1 (placa)
markRect(224, 309, 676, 344); fill(214, 300, 686, 352, 0.8, 300); // GOLPE HEROICO APRIMORADO
// losangos sobre o círculo rúnico: o anel é circular, então cada pixel apagado
// copia o mesmo raio em ângulos vizinhos livres
{
  const hole = (x, y) => (Math.abs(x - 405) + Math.abs(y - 624) < 28) || (Math.abs(x - 450) + Math.abs(y - 626) < 28) || (Math.abs(x - 495) + Math.abs(y - 624) < 28);
  for (let y = 590; y <= 660; y++) for (let x = 370; x <= 530; x++) {
    if (!hole(x, y)) continue;
    if (Math.hypot(x - CRX, y - CRY) > 140) { MASK[y * W + x] = 1; continue; }
    const r = Math.hypot(x - CRX, y - CRY), th = Math.atan2(y - CRY, x - CRX), st = 0.6 / r;
    const side = (dir) => { for (let k = 1; k < 2000; k++) { const a = th + dir * k * st, sx = CRX + r * Math.cos(a), sy = CRY + r * Math.sin(a); if (!hole(Math.round(sx), Math.round(sy))) return { k, c: bil(snap, sx, sy) }; } return null; };
    const A = side(1), B = side(-1);
    if (!A || !B) continue;
    const t = B.k / (A.k + B.k);
    set(img, x, y, [0, 1, 2].map((i) => A.c[i] * t + B.c[i] * (1 - t)));
  }
  fill(360, 585, 540, 665, 0.6, 200); // abaixo do anel: difusão
  // o mesmo para o brilho das runas extraído
  for (let y = 590; y <= 660; y++) for (let x = 370; x <= 530; x++) if (hole(x, y)) { const o = (y * W + x) * 4; glow.px[o + 3] = 0; }
}
// ícone: o miolo vira um poço escuro; o brilho dourado em volta (raios) esfria
for (let y = CRY - 104; y <= CRY + 104; y++) for (let x = CRX - 104; x <= CRX + 104; x++) {
  const r = Math.hypot(x - CRX, y - CRY), c = get(img, x, y);
  if (r <= 71) {
    const sh = 0.55 + 0.45 * (r / 71), well = [8 * sh, 14 * sh, 22 * sh], a = clamp01(71.5 - r);
    set(img, x, y, [0, 1, 2].map((k) => well[k] * a + c[k] * (1 - a)));
  } else if (r >= 77 && r <= 102) {
    // tira o calor do brilho dourado (fica o tom frio do card); o aro dourado
    // fino até r 76 e o anel branco em r ~102 ficam
    const warm = Math.max(0, (c[0] + c[1]) / 2 - c[2] - 6);
    const k = clamp01(Math.min(r - 77, 102 - r) / 4);
    const L = lumC(c), cool = [L * 0.42, L * 0.55, L * 0.72];
    const f = clamp01(warm / 40) * k;
    set(img, x, y, [0, 1, 2].map((i) => c[i] * (1 - f) + cool[i] * f));
  }
}
cleanBand(388, 658, 512, 683);                // GRAU 0 / 3
cleanPill(266, 716, 354, 743, 262);           // PASSIVA
cleanPill(396, 716, 636, 743, 393);           // PRONTO PARA INFUNDIR
markRect(230, 796, 670, 874); fill(222, 788, 678, 882);  // descrição
cleanPill(312, 938, 592, 974, 307);           // INFUNDIR AZAATH (+1)
cleanPill(196, 1072, 428, 1105, 192);         // PURIFICAR FLUXO
cleanPill(472, 1072, 704, 1105, 468);         // SELAR INFUSÃO

// ---------------------------------------------------------------------------
// 4. Recorte do card com transparência fora da silhueta
// ---------------------------------------------------------------------------
const CX0 = 170, CY0 = 40, CW = 560, CH = 1090;
const inRound = (x, y, x0, y0, x1, y1, r) => {
  const dx = Math.max(x0 + r - x, 0, x - (x1 - r)), dy = Math.max(y0 + r - y, 0, y - (y1 - r));
  return r - Math.hypot(dx, dy); // > 0 dentro
};
const card = I.create(CW, CH), glowCrop = I.create(CW, CH);
for (let j = 0; j < CH; j++) for (let i = 0; i < CW; i++) {
  const x = CX0 + i, y = CY0 + j, c = get(img, x, y);
  let a = 0;
  a = Math.max(a, clamp01(inRound(x, y, 181, 201, 719, 1037, 14) + 0.5));          // corpo do card
  a = Math.max(a, clamp01(inRound(x, y, 183, 1060, 440, 1118, 6) + 0.5));          // PURIFICAR
  a = Math.max(a, clamp01(inRound(x, y, 460, 1060, 717, 1118, 6) + 0.5));          // SELAR
  // coroa, brilho das bordas e o resto: o que se destaca do céu
  const L = lumC(get(snap, x, y));
  const cAlpha = clamp01((L - bgLow(x, y) - 10) / 40);
  const nearCard = inRound(x, y, 171, 40, 729, 1128, 10) > 0;
  if (nearCard && (y < 215 || y > 1000 || x < 190 || x > 710)) a = Math.max(a, cAlpha);
  const o = (j * CW + i) * 4;
  card.px[o] = c[0]; card.px[o + 1] = c[1]; card.px[o + 2] = c[2]; card.px[o + 3] = 255 * a;
  const g = (y * W + x) * 4;
  glowCrop.px[o] = glow.px[g]; glowCrop.px[o + 1] = glow.px[g + 1]; glowCrop.px[o + 2] = glow.px[g + 2]; glowCrop.px[o + 3] = glow.px[g + 3];
}
const TW = 512, TH = Math.round(CH * TW / CW); // 997
function pad(im, w, h) { const out = I.create(w, h); I.blit(out, im, 0, 0); return out; }
const cardOut = pad(I.resize(card, TW, TH), 512, 1024);
const glowOut = pad(I.resize(glowCrop, TW, TH), 512, 1024);

for (const [name, im] of Object.entries({ TalentBG: cardOut, TalentArtIcons: glowOut, TalentBtnApply: diam })) {
  I.writeTGA(path.join(OUT_WS, name + ".tga"), im);
  try { I.writeTGA(OUT_GAME + "/" + name + ".tga", im); } catch (e) { console.log("sem acesso à pasta do jogo:", e.code); }
  console.log("gerado", name, im.w + "x" + im.h);
}
// prévia: card sobre fundo escuro
const pv = I.create(CW, CH, 10, 16, 28, 255);
for (let p = 0; p < CW * CH; p++) { const a = card.px[p * 4 + 3] / 255; for (let k = 0; k < 3; k++) pv.px[p * 4 + k] = pv.px[p * 4 + k] * (1 - a) + card.px[p * 4 + k] * a; }
I.writePNG(path.join(PREV, "card.png"), pv);
I.writePNG(path.join(PREV, "diamonds.png"), diam);
console.log("TH", TH);
