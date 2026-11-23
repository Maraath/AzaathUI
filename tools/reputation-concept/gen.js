// Gera a aba Reputação (ficha, tecla C).
//   concept.webp  arte de conceito COM a interface (referência de medidas; dela saem
//                 as linhas da lista, a barra, as caixas e o painel da direita)
//   clean.webp    a mesma cena LIMPA, sem interface
//   clean_hd.png  clean.png ampliada 4x pelo Real-ESRGAN (realesrgan-ncnn-vulkan,
//                 modelo realesrgan-x4plus) e reduzida de volta a 2000x1125 com
//                 lanczos no ffmpeg: mesmo tamanho, detalhe redesenhado (fundo do jogo)
//
//   1. ffmpeg -i concept.webp concept.png && ffmpeg -i clean.webp clean.png   (uma vez)
//      realesrgan-ncnn-vulkan -i clean.png -o up.png -n realesrgan-x4plus
//      ffmpeg -i up.png -vf scale=2000:1125:flags=lanczos -pix_fmt rgb24 clean_hd.png
//   2. node tools/reputation-concept/gen.js
//
// Saída (AzaathUI/Media/Sheet, copiada também para a pasta do jogo):
//   ReputationBG     arte limpa, 2048x2048 (2000x1125 úteis), runas a 55%.
//   ReputationRows   linhas da lista recortadas de concept (texto e barra apagados):
//                    cabeçalho de grupo (y 0), linha comum (y 64), linha selecionada
//                    com o brilho de fora (y 128). 1024x256.
//   ReputationParts  barra do painel (moldura vazia + preenchimento) e caixa de
//                    seleção vazia + visto. 512x128.
//   ReputationPanel  painel da direita (moldura, selo, divisória) sem o conteúdo,
//                    x 1590..1987, y 134..1069 de concept. 512x1024.
//   ReputationRunes  luz das runas das colunas de clean, 4 quadros de pulso subindo
//                    (ADD), meia resolução, atlas 2x2 de 1024x256 (2048x512).
// Coordenadas no Lua (Sheet/Reputation.lua, REP) = coordenadas das artes (as duas são 2000x1125).
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");
const { fill } = require("./fill");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Sheet");
const GAME = "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Sheet";
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(PREV, { recursive: true });

const src = readPNG(path.join(__dirname, "concept.png"));
const W = src.w, H = src.h;
const orig = Float32Array.from(src.px);
const img = { w: W, h: H, px: Float32Array.from(src.px) };
const lum = (x, y) => { const o = (y * W + x) * 4; return 0.3 * img.px[o] + 0.59 * img.px[o + 1] + 0.11 * img.px[o + 2]; };

function save(name, tex) {
  I.writeTGA(path.join(OUT, name + ".tga"), tex);
  if (fs.existsSync(GAME)) fs.copyFileSync(path.join(OUT, name + ".tga"), path.join(GAME, name + ".tga"));
  console.log("gerado", name, tex.w + "x" + tex.h);
}

// ---------------------------------------------------------------------------
// Máscara (1 = apagar)
// ---------------------------------------------------------------------------
const MASK = new Uint8Array(W * H);
const clampX = (x) => Math.max(0, Math.min(W - 1, x)), clampY = (y) => Math.max(0, Math.min(H - 1, y));
function markRect(x0, y0, x1, y1) {
  for (let y = clampY(y0); y <= clampY(y1); y++) for (let x = clampX(x0); x <= clampX(x1); x++) MASK[y * W + x] = 1;
}
function markDisc(cx, cy, r) {
  for (let y = clampY(Math.floor(cy - r)); y <= clampY(Math.ceil(cy + r)); y++)
    for (let x = clampX(Math.floor(cx - r)); x <= clampX(Math.ceil(cx + r)); x++)
      if ((x - cx) ** 2 + (y - cy) ** 2 <= r * r) MASK[y * W + x] = 1;
}
function markDeviant(x0, y0, x1, y1, o = {}) {
  const thr = o.thr ?? 18, rad = o.rad ?? 12, dil = o.dil ?? 2;
  x0 = clampX(x0); y0 = clampY(y0); x1 = clampX(x1); y1 = clampY(y1);
  const bx0 = clampX(x0 - rad), by0 = clampY(y0 - rad), bx1 = clampX(x1 + rad), by1 = clampY(y1 + rad);
  const w = bx1 - bx0 + 1, h = by1 - by0 + 1, S = new Float64Array((w + 1) * (h + 1));
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++)
    S[(y + 1) * (w + 1) + x + 1] = lum(bx0 + x, by0 + y) + S[y * (w + 1) + x + 1] + S[(y + 1) * (w + 1) + x] - S[y * (w + 1) + x];
  const ref = (x, y) => {
    const a = Math.max(0, x - bx0 - rad), b = Math.max(0, y - by0 - rad), c = Math.min(w - 1, x - bx0 + rad), d = Math.min(h - 1, y - by0 + rad);
    return (S[(d + 1) * (w + 1) + c + 1] - S[b * (w + 1) + c + 1] - S[(d + 1) * (w + 1) + a] + S[b * (w + 1) + a]) / ((c - a + 1) * (d - b + 1));
  };
  const hit = [];
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    const dv = lum(x, y) - ref(x, y);
    if ((o.light !== false && dv > thr) || (o.dark && dv < -thr)) hit.push([x, y]);
  }
  for (const [x, y] of hit) markDisc(x, y, dil);
}

// Painel da direita: só o conteúdo (moldura, selo e divisória ficam no recorte)
markDeviant(1640, 180, 1940, 238, { thr: 14, dark: true, dil: 3 });   // nome da facção
markDeviant(1690, 238, 1890, 274, { thr: 10, dark: true, dil: 3 });   // posição (Honrado)
markRect(1618, 283, 1958, 321);                                       // barra
markDeviant(1608, 566, 1972, 622, { thr: 14, dark: true, dil: 3 });   // descrição
markRect(1620, 888, 1970, 1002);                                      // caixas + rótulos


// ---------------------------------------------------------------------------
// Peças recortadas da arte ORIGINAL (antes do preenchimento)
// ---------------------------------------------------------------------------
function cropFilled(x0, y0, w, h, rects) {
  const c = I.crop({ w: W, h: H, px: orig }, x0, y0, w, h);
  const m = new Uint8Array(w * h);
  for (const [a, b, cc, d] of rects)
    for (let y = Math.max(0, b - y0); y <= Math.min(h - 1, d - y0); y++)
      for (let x = Math.max(0, a - x0); x <= Math.min(w - 1, cc - x0); x++) m[y * w + x] = 1;
  // linhas quase lisas na vertical: cada pixel apagado = interpolação horizontal entre
  // os trechos limpos à esquerda e à direita na mesma altura (média de 3 px de cada lado)
  for (let y = 0; y < h; y++) {
    let x = 0;
    while (x < w) {
      if (!m[y * w + x]) { x++; continue; }
      let e = x;
      while (e < w && m[y * w + e]) e++;
      const side = (from, dir) => {
        const acc = [0, 0, 0]; let n = 0;
        for (let s = 0; s < 3; s++) {
          const xx = from + dir * s;
          if (xx < 0 || xx >= w || m[y * w + xx]) continue;
          for (let k = 0; k < 3; k++) acc[k] += c.px[(y * w + xx) * 4 + k];
          n++;
        }
        return n ? acc.map((v) => v / n) : null;
      };
      const L = side(x - 1, -1) || side(e, 1), R = side(e, 1) || L;
      for (let xx = x; xx < e; xx++) {
        const t = (xx - x + 1) / (e - x + 1), d = (y * w + xx) * 4;
        for (let k = 0; k < 3; k++) c.px[d + k] = L[k] * (1 - t) + R[k] * t;
      }
      x = e;
    }
  }
  return c;
}
// linhas da lista: caixa x 417..1238 (822 px); cabeçalho y 148..206; linha 210..262;
// selecionada 378..430 (+6 px de brilho em volta)
const rowText = (top) => [[428, top + 6, 760, top + 46], [856, top + 6, 1226, top + 45]];
const rows = I.create(1024, 256, 0, 0, 0, 0);
const hdr = cropFilled(417, 148, 822, 59, [[428, 158, 660, 197]]);
const row = cropFilled(417, 210, 822, 53, rowText(210));
const sel = cropFilled(411, 372, 834, 65, rowText(378));
I.blit(rows, hdr, 0, 0);
I.blit(rows, row, 0, 64);
I.blit(rows, sel, 0, 128);
save("ReputationRows", rows);
I.writePNG(path.join(PREV, "rows.png"), rows);

// barra do painel: moldura 1622..1954 x 285..318; interior vazio = coluna x 1700
const parts = I.create(512, 128, 0, 0, 0, 0);
{
  const fr = I.crop({ w: W, h: H, px: orig }, 1622, 285, 333, 34);
  for (let y = 291 - 285; y <= 312 - 285; y++) {
    const s = ((285 + y) * W + 1700) * 4;
    for (let x = 1630 - 1622; x <= 1938 - 1622; x++) {
      const d = (y * fr.w + x) * 4;
      for (let k = 0; k < 3; k++) fr.px[d + k] = orig[s + k];
    }
  }
  I.blit(parts, fr, 0, 0);
  // preenchimento: perfil vertical da arte, clareando rumo à ponta (128x22)
  const fl = I.create(128, 22, 0, 0, 0, 255);
  for (let y = 0; y < 22; y++) for (let x = 0; x < 128; x++) {
    const u = x / 127;
    const sx = u > 0.95 ? 1671 : Math.round(1640 + u * 27);
    const s = ((291 + y) * W + sx) * 4, d = (y * 128 + x) * 4;
    for (let k = 0; k < 3; k++) fl.px[d + k] = orig[s + k];
  }
  I.blit(parts, fl, 0, 40);
  // caixa de seleção vazia (1626..1652 x 895..922) e visto (caixa marcada - vazia)
  const box = I.crop({ w: W, h: H, px: orig }, 1625, 894, 28, 28);
  for (let i = 0; i < 28 * 28; i++) box.px[i * 4 + 3] = 255;
  I.blit(parts, box, 340, 0);
  const chk = I.create(40, 40, 0, 0, 0, 255);
  for (let y = 0; y < 40; y++) for (let x = 0; x < 40; x++) {
    const a = ((961 + y) * W + 1622 + x) * 4, b = ((887 + y) * W + 1622 + x) * 4, d = (y * 40 + x) * 4;
    for (let k = 0; k < 3; k++) chk.px[d + k] = Math.max(0, orig[a + k] - orig[b + k]) * 1.1;
  }
  I.blit(parts, chk, 380, 0);
}
save("ReputationParts", parts);
I.writePNG(path.join(PREV, "parts.png"), parts);

// ---------------------------------------------------------------------------
// Painel da direita: conteúdo apagado na arte com interface e recortado
// ---------------------------------------------------------------------------
{
  const PX = 1590, PY = 134, PW = 398, PH = 936;
  const crop = I.crop(img, PX, PY, PW, PH);
  const m = new Uint8Array(PW * PH);
  for (let y = 0; y < PH; y++) for (let x = 0; x < PW; x++) m[y * PW + x] = MASK[(PY + y) * W + PX + x];
  const f = fill(crop.px, m, PW, PH);
  let seed = 11;
  const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
  for (let i = 0; i < PW * PH; i++) if (m[i]) {
    const n = (rnd() + rnd() + rnd() - 1.5) * 2.4;
    for (let k = 0; k < 3; k++) crop.px[i * 4 + k] = Math.max(0, Math.min(255, f[i * 4 + k] + n));
  }
  // fora da moldura (x > 1985, preto da arte) transparente
  for (let y = 0; y < PH; y++) for (let x = 0; x < PW; x++) crop.px[(y * PW + x) * 4 + 3] = PX + x > 1986 ? 0 : 255;
  const tex = I.create(512, 1024, 0, 0, 0, 0);
  I.blit(tex, crop, 0, 0);
  save("ReputationPanel", tex);
  I.writePNG(path.join(PREV, "panel.png"), crop);
}

// ---------------------------------------------------------------------------
// Fundo = arte limpa; runas das colunas separadas (arte com elas a 55%) e
// 4 quadros de pulso subindo pelas colunas (o jogo cruza 2 vizinhos em ADD)
// ---------------------------------------------------------------------------
const clean = readPNG(path.join(__dirname, "clean_hd.png"));
const bgImg = { w: W, h: H, px: Float32Array.from(clean.px) };
const RUNE = { x: 390, y: 70, w: 1240, h: 490, frames: 4, lambda: 150, dim: 0.55 };
const PILLARS = [[395, 75, 468, 560], [952, 130, 1022, 530], [1558, 75, 1628, 555]];
const RMASK = new Uint8Array(W * H);
for (const [x0, y0, x1, y1] of PILLARS)
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    const o = (y * W + x) * 4, R = bgImg.px[o], G = bgImg.px[o + 1], B = bgImg.px[o + 2];
    const L0 = 0.3 * R + 0.59 * G + 0.11 * B;
    if (!(B - R > 70 && G - R > 60 && L0 > 110)) continue;
    // só traços finos e mais claros que a pedra em volta (a névoa/feixe é larga e lisa)
    let acc = 0, n = 0;
    for (let dy = -9; dy <= 9; dy += 3) for (let dx = -9; dx <= 9; dx += 3) {
      const q = ((y + dy) * W + x + dx) * 4;
      acc += 0.3 * bgImg.px[q] + 0.59 * bgImg.px[q + 1] + 0.11 * bgImg.px[q + 2]; n++;
    }
    if (L0 - acc / n > 22) RMASK[y * W + x] = 1;
  }
{ // engorda 3 px (halo das runas)
  const s = Uint8Array.from(RMASK);
  for (let y = 3; y < H - 3; y++) for (let x = 3; x < W - 3; x++) if (s[y * W + x])
    for (let dy = -3; dy <= 3; dy++) for (let dx = -3; dx <= 3; dx++) RMASK[(y + dy) * W + x + dx] = 1;
}
const rbase = fill(bgImg.px, RMASK, W, H);
const glow = new Float32Array(RUNE.w * RUNE.h * 3);
for (let j = 0; j < RUNE.h; j++) for (let i = 0; i < RUNE.w; i++) {
  const g = (RUNE.y + j) * W + RUNE.x + i, k = j * RUNE.w + i;
  if (!RMASK[g]) continue;
  for (let ch = 0; ch < 3; ch++) {
    const v = Math.max(0, bgImg.px[g * 4 + ch] - rbase[g * 4 + ch]);
    glow[k * 3 + ch] = v;
    bgImg.px[g * 4 + ch] -= v * (1 - RUNE.dim);
  }
}
const runes = I.create(2048, 512, 0, 0, 0, 255);
const RW = RUNE.w / 2, RH = RUNE.h / 2;
for (let f = 0; f < RUNE.frames; f++) {
  const ox = (f % 2) * 1024, oy = Math.floor(f / 2) * 256;
  for (let j = 0; j < RH; j++) for (let i = 0; i < RW; i++) {
    const acc = [0, 0, 0];
    for (let sj = 0; sj < 2; sj++) for (let si = 0; si < 2; si++) {
      const k = (j * 2 + sj) * RUNE.w + i * 2 + si;
      const y = RUNE.y + j * 2 + sj;
      const ph = y / RUNE.lambda + f / RUNE.frames;          // sobe com o tempo
      const c = (1 + Math.cos(2 * Math.PI * ph)) / 2;
      const p = 0.25 + 0.75 * Math.pow(c, 2.0);
      for (let ch = 0; ch < 3; ch++) acc[ch] += glow[k * 3 + ch] * p * 1.25;
    }
    const o = ((oy + j) * 2048 + ox + i) * 4;
    for (let ch = 0; ch < 3; ch++) runes.px[o + ch] = Math.min(255, acc[ch] / 4);
  }
}
save("ReputationRunes", runes);
{
  const r0 = I.create(RW, RH, 0, 0, 0, 255);
  for (let j = 0; j < RH; j++) for (let i = 0; i < RW; i++) for (let ch = 0; ch < 3; ch++) r0.px[(j * RW + i) * 4 + ch] = runes.px[(j * 2048 + i) * 4 + ch];
  I.writePNG(path.join(PREV, "runes0.png"), r0);
}

const tex = I.create(2048, 2048, 0, 0, 0, 255);
for (let i = 0; i < W * H; i++) bgImg.px[i * 4 + 3] = 255;
I.blit(tex, bgImg, 0, 0);
save("ReputationBG", tex);
I.writePNG(path.join(PREV, "bg.png"), bgImg);
const mk = I.create(W, H, 0, 0, 0, 255);
for (let i = 0; i < W * H; i++) if (RMASK[i]) mk.px[i * 4 + 1] = 220;
I.writePNG(path.join(PREV, "mask.png"), mk);
