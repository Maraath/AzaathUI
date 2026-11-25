// Barras "Reforged" minimalistas (23/11/2026): em vez dos painéis grandes da
// arte de conceito, cada barra é uma faixa escura translúcida com filete
// dourado e os espaços recortados do próprio conceito (moldura dourada).
// Com 3 barras, a barra 3 vira uma fileira a mais em cima de cada faixa
// (1-6 na esquerda, 7-12 na direita). Gera Media/Azaath/RBar*.tga e prévias
// sobre um print do jogo (preview/compare2.png e compare3.png).
// Uso: node tools/reforged-bars/gen.js [print.png]
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const ROOT = path.join(__dirname, "..", "..", "AzaathUI");
const OUT = path.join(ROOT, "Media", "Azaath");
const AC = path.join(__dirname, "..", "actionbar-concept", "preview"); // saída do gen.js da HUD
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(PREV, { recursive: true });

const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const smooth = (e0, e1, v) => { const t = clamp((v - e0) / (e1 - e0)); return t * t * (3 - 2 * t); };
const save = (name, im) => { I.writeTGA(path.join(OUT, name + ".tga"), im); I.writePNG(path.join(PREV, name + ".png"), im); };

// --- espaço do botão: recorte do painel direito do conceito (54 px) ---
const right = readPNG(path.join(AC, "Right.png"));
const slot = I.resize(I.crop(right, 9, 56, 54, 54), 64, 64);
save("RBarSlot", slot);

// --- faixa (3 fatias: ponta 32 px + meio 32 px repetível; a direita é a ponta espelhada) ---
const PH = 64, R = 12;
const BG = [12, 15, 18], GOLD = [176, 150, 100];
function plateCol(x, w, isCap) {
  // devolve coluna: alpha do fundo e do filete
  return (y) => {
    let shape = 1;
    if (isCap) {
      const qx = Math.max(R - x - 0.5, 0), qy = Math.max(R - y - 0.5, y + 0.5 - (PH - R), 0);
      shape = 1 - smooth(-0.6, 0.8, Math.hypot(qx, qy) - R);
    }
    const line = (y >= 2 && y <= 3) || (y >= PH - 4 && y <= PH - 3) ? (isCap ? smooth(R, 30, x) : 1) : 0;
    return { a: shape * 0.62, line: line * 0.85 };
  };
}
function plate(w, isCap) {
  const im = I.create(w, PH);
  for (let x = 0; x < w; x++) { const col = plateCol(x, w, isCap); for (let y = 0; y < PH; y++) {
    const { a, line } = col(y), o = (y * w + x) * 4;
    const A = a + line * (1 - a);
    for (let k = 0; k < 3; k++) im.px[o + k] = A > 0 ? (BG[k] * a * (1 - line) + GOLD[k] * line) / A : 0;
    im.px[o + 3] = A * 255;
  } }
  return im;
}
// prévia usa as fatias soltas; o jogo usa RBarPlate (128x64, 9 fatias):
// colunas ponta 0-32 | meio 32-96 | ponta espelhada 96-128; linhas topo 0-16 | meio 16-48 | base 48-64
const capIm = plate(32, true), midIm = plate(32, false);
I.writePNG(path.join(PREV, "RBarCap.png"), capIm); I.writePNG(path.join(PREV, "RBarMid.png"), midIm);
{
  const pl = I.create(128, PH);
  for (let y = 0; y < PH; y++) for (let x = 0; x < 128; x++) {
    const srcIm = (x < 32 || x >= 96) ? capIm : midIm, sx = x < 32 ? x : x >= 96 ? 127 - x : (x - 32) % 32;
    const o = (y * 128 + x) * 4, q = (y * 32 + sx) * 4;
    for (let k = 0; k < 4; k++) pl.px[o + k] = srcIm.px[q + k];
  }
  save("RBarPlate", pl);
}

// ---------------------------------------------------------------------------
// Prévia: print do jogo -> fundo da cena (sem os painéis velhos), moldura central
// recortada (pixels do print, máscara da arte nova) e as barras novas com os
// ícones recortados do mesmo print.
// ---------------------------------------------------------------------------
const shotFile = process.argv[2];
if (shotFile) {
  const shot = readPNG(shotFile), W = shot.w, H = shot.h;
  const cv = I.create(W, H, 0, 0, 0, 255);
  const px = (im, x, y) => { x = clamp(Math.round(x), 0, im.w - 1); y = clamp(Math.round(y), 0, im.h - 1); const o = (y * im.w + x) * 4; return [im.px[o], im.px[o + 1], im.px[o + 2], im.px[o + 3]]; };
  const put = (x, y, c, a) => { if (x < 0 || y < 0 || x >= W || y >= H || a <= 0) return; const o = (y * W + x) * 4; for (let k = 0; k < 3; k++) cv.px[o + k] = cv.px[o + k] * (1 - a) + c[k] * a; };
  // cena: faixa de cima do print espelhada para baixo
  for (let y = 0; y < H; y++) { const p = Math.floor(y / 56), r = y % 56, sy = (p % 2) ? 55 - r : r;
    for (let x = 0; x < W; x++) put(x, y, px(shot, x, sy), 1); }
  // moldura central: HUD -> print (escala/origem medidas no print)
  const s = 0.963, ox = -22, oy = 95;
  const hc = readPNG(path.join(AC, "HudCenter.png")), HX = 414;
  for (let y = 0; y < H; y++) for (let x = 360; x < 880; x++) {
    const u = (x - ox) / s - HX, v = (y - oy) / s;
    if (u < 0 || v < 0 || u >= 446 || v >= 296) continue;
    const c = px(hc, u, v), a = c[3] / 255;
    // colchetes das pontas: arte nova (no print a gema velha cobre o filete); resto: pixels do print
    put(x, y, (u < 26 || u > 414) ? c : px(shot, x, y), a);
  }
  const scene = Float32Array.from(cv.px);
  // barras: faixa + espaços + ícones do print; com 3 barras a faixa cresce uma fileira para cima
  const SZ = 44, SP = 6, PAD = 10, COLS = 6;
  const cap = readPNG(path.join(PREV, "RBarCap.png")), mid = readPNG(path.join(PREV, "RBarMid.png"));
  const drawImg = (im, x0, y0, w, h, flip) => { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const u = (flip ? (w - 1 - i) : i) * im.w / w, v = j * im.h / h, c = px(im, u, v); put(x0 + i, y0 + j, c, c[3] / 255); } };
  const iconsR = [], iconsL = [];
  for (const y of [132.5, 226]) for (let i = 0; i < 6; i++) iconsR.push([869 + 61.8 * i, y, 19.5]);
  for (const y of [133, 210]) for (let i = 0; i < 6; i++) iconsL.push((y === 210 && i > 2) ? null : [79.5 + 52.3 * i, y, 17]);
  // barra 3 (só na prévia de 3 barras): alguns ícones do print repetidos, o resto vazio
  const bar3L = [iconsR[8], iconsR[9], iconsR[10], null, null, null];
  const bar3R = [iconsL[3], iconsL[4], null, null, null, null];
  for (const ROWS of [2, 3]) {
    cv.px.set(scene);
    const pw = COLS * SZ + (COLS - 1) * SP + 2 * PAD, ph = ROWS * SZ + (ROWS - 1) * SP + 2 * PAD;
    const bottom = 215 + (2 * SZ + SP + 2 * PAD) / 2; // base fixa: a faixa cresce para cima
    const drawBar = (x0, icons, top) => {
      const y0 = bottom - ph, cw = Math.round(32 * ph / PH);
      drawImg(cap, x0, y0, cw, ph, false); drawImg(cap, x0 + pw - cw, y0, cw, ph, true);
      drawImg(mid, x0 + cw, y0, pw - 2 * cw, ph, false);
      const list = ROWS === 3 ? top.concat(icons) : icons;
      for (let r = 0; r < ROWS; r++) for (let c = 0; c < COLS; c++) {
        const bx = x0 + PAD + c * (SZ + SP), by = y0 + PAD + r * (SZ + SP);
        drawImg(slot, bx, by, SZ, SZ, false);
        const ic = list[r * COLS + c]; if (!ic) continue;
        const ins = 5, iw = SZ - 2 * ins;
        for (let j = 0; j < iw; j++) for (let i = 0; i < iw; i++)
          put(bx + ins + i, by + ins + j, px(shot, ic[0] - ic[2] + i * 2 * ic[2] / iw, ic[1] - ic[2] + j * 2 * ic[2] / iw), 1);
      }
      return y0;
    };
    const lx = 392 - 16 - pw;
    const ly = drawBar(lx, iconsL, bar3L);
    drawBar(800 + 16, iconsR, bar3R);
    // abas de postura do print, acima da faixa esquerda
    for (let y = 62; y < 108; y++) for (let x = 56; x < 150; x++) put(x - 56 + lx + 4, y - 62 + ly - 50, px(shot, x, y), 1);
    const f = path.join(PREV, "compare" + ROWS + ".png");
    I.writePNG(f, cv);
    console.log("prévia:", f);
  }
}
