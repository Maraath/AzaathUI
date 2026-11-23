// Gera a arte da aba Santuário (ficha, tecla C) a partir da arte de conceito
// (tools/sanctuary-concept/concept.webp, 2000x1125 — já acima de 1080p).
//
//   1. ffmpeg -i concept.webp concept.png   (feito uma vez)
//   2. node tools/sanctuary-concept/gen.js
//
// Saída (AzaathUI/Media/Sheet):
//   SanctuaryBG   templo + altar + fumaça/fios de energia pintados, SEM nada que o
//                 jogo desenha por cima: cabeçalho (retrato, nome, menu, orbe de
//                 poder), medalhões e nomes dos itens, linha que liga os medalhões,
//                 card de atributos, barra de pose e rodapé. 2048x2048 (2000x1125 úteis).
// Coordenadas no Lua (Sheet/Sanctuary.lua, SANCT_*) = coordenadas desta arte (o quadro
// inteiro é escalado para cobrir a tela).
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Sheet");
const GAME = "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Sheet";
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(PREV, { recursive: true });

const src = readPNG(path.join(__dirname, "concept.png"));
const W = src.w, H = src.h;
const img = { w: W, h: H, px: Float32Array.from(src.px) };
const lum = (x, y) => { const o = (y * W + x) * 4; return 0.3 * img.px[o] + 0.59 * img.px[o + 1] + 0.11 * img.px[o + 2]; };

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
// pixels mais claros (light) ou escuros que o fundo local (média de uma janela grande)
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
// faixa ao longo de uma polilinha (só pixels claros, para a linha fina dos medalhões)
function markPolyline(pts, half, o = {}) {
  for (let i = 0; i < pts.length - 1; i++) {
    const [ax, ay] = pts[i], [bx, by] = pts[i + 1];
    const len = Math.hypot(bx - ax, by - ay);
    for (let s = 0; s <= len; s += 1) {
      const x = Math.round(ax + (bx - ax) * s / len), y = Math.round(ay + (by - ay) * s / len);
      if (o.deviant) markDeviant(x - half, y - 1, x + half, y + 1, { thr: o.thr ?? 10, rad: 8, dil: 2 });
      else markRect(x - half, y, x + half, y);
    }
  }
}

// ---------------------------------------------------------------------------
// 1) Cabeçalho (o jogo desenha retrato, nome, menu e orbe)
// ---------------------------------------------------------------------------
markDisc(122, 97, 80);                       // retrato + moldura
markRect(108, 10, 136, 30);                  // gema do topo
markDisc(120, 166, 24);                      // brasão da classe
markDeviant(205, 38, 570, 118, { thr: 12, dark: true, dil: 4 }); // nome + "NÍVEL..." (com a sombra)
markDeviant(580, 45, 1800, 95, { thr: 12, dark: true, dil: 4 });  // nomes das abas
markRect(470, 94, 1478, 108);                // linha do horizonte
markDisc(665, 100, 34);                      // clarão da aba ativa
markRect(648, 108, 684, 134);                // seta "^"
markDisc(1898, 74, 64);                      // orbe de Poder de Item

// ---------------------------------------------------------------------------
// 2) Medalhões laterais (o jogo desenha 8 de cada lado ao longo das mesmas linhas)
// ---------------------------------------------------------------------------
const LEFT = [[77, 249], [67, 367], [62, 480], [66, 593], [67, 712], [78, 827], [90, 940]];
const RIGHT = [[1410, 247], [1417, 362], [1422, 477], [1422, 592], [1417, 710], [1409, 822], [1398, 940]];
const GREEN = { L: [2], R: [0, 1, 2] }; // medalhões com aura verde (raio maior)
LEFT.forEach(([x, y], i) => markDisc(x, y, GREEN.L.includes(i) ? 50 : 37));
RIGHT.forEach(([x, y], i) => markDisc(x, y, GREEN.R.includes(i) ? 50 : 37));
// halo verde/azul que vaza além do aro: pixels dominados pela cor perto dos medalhões
function markTint(cx, cy, r, test) {
  for (let y = clampY(cy - r); y <= clampY(cy + r); y++) for (let x = clampX(cx - r); x <= clampX(cx + r); x++) {
    if ((x - cx) ** 2 + (y - cy) ** 2 > r * r) continue;
    const o = (y * W + x) * 4, R = img.px[o], G = img.px[o + 1], B = img.px[o + 2];
    if (test(R, G, B)) markDisc(x, y, 3);
  }
}
const greenish = (R, G, B) => G > R + 18 && G > B + 4;
GREEN.L.forEach((i) => markTint(LEFT[i][0], LEFT[i][1], 80, greenish));
GREEN.R.forEach((i) => markTint(RIGHT[i][0], RIGHT[i][1], 80, greenish));
markPolyline(LEFT, 6, { deviant: true });
markPolyline(RIGHT, 6, { deviant: true });
markRect(1376, 960, 1420, 1000);             // ponta solta da linha sob o último medalhão
// nomes dos itens (à direita dos medalhões da esquerda / à esquerda dos da direita)
const LBL_L = [[100, 230, 260, 262], [96, 343, 220, 375], [96, 455, 270, 495], [96, 570, 270, 610], [100, 688, 270, 728], [108, 803, 210, 835], [118, 915, 270, 960]];
const LBL_R = [[1220, 225, 1374, 268], [1210, 340, 1384, 380], [1260, 455, 1390, 495], [1330, 575, 1388, 600], [1330, 690, 1390, 718], [1300, 803, 1378, 835], [1270, 917, 1368, 950]];
for (const [a, b, c, d] of LBL_L) markDeviant(a, b, c, d, { thr: 14, dark: true, dil: 3 });
for (const [a, b, c, d] of LBL_R) markDeviant(a, b, c, d, { thr: 14, dark: true, dil: 3 });

// ---------------------------------------------------------------------------
// 3) Card de atributos (o jogo desenha o card por cima, na mesma caixa)
// ---------------------------------------------------------------------------
markRect(1474, 96, 1999, 1078);

// ---------------------------------------------------------------------------
// 4) Barra de pose: faixa, setas, texto e as 4 armas
// ---------------------------------------------------------------------------
markRect(576, 955, 910, 986);                // faixa da pose inteira (o jogo desenha faixa, setas e texto)
for (const [x, y, r] of [[614, 1020, 44], [705, 1020, 36], [785, 1020, 36], [862, 1020, 36]]) markDisc(x, y, r);
markTint(614, 1020, 70, (R, G, B) => B > R + 40 && B > G + 8);   // aura azul da arma ativa
markDeviant(590, 1046, 900, 1072, { thr: 12, dark: true, dil: 3 });

// ---------------------------------------------------------------------------
// 5) Rodapé (textos e botões)
// ---------------------------------------------------------------------------
markDeviant(40, 1080, 660, 1118, { thr: 12, dark: true, dil: 4 });
markRect(1505, 1076, 1999, 1124);

// ---------------------------------------------------------------------------
// Preenchimento multiescala (pirâmide + relaxamento harmônico em cada nível)
// ---------------------------------------------------------------------------
function fill(px, mask, w, h) {
  const levels = [{ w, h, px: Float32Array.from(px), m: Uint8Array.from(mask) }];
  while (levels[levels.length - 1].w > 8 && levels[levels.length - 1].h > 8) {
    const L = levels[levels.length - 1];
    const nw = Math.ceil(L.w / 2), nh = Math.ceil(L.h / 2);
    const npx = new Float32Array(nw * nh * 4), nm = new Uint8Array(nw * nh);
    for (let y = 0; y < nh; y++) for (let x = 0; x < nw; x++) {
      let s = [0, 0, 0], c = 0;
      for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 2; dx++) {
        const xx = Math.min(L.w - 1, 2 * x + dx), yy = Math.min(L.h - 1, 2 * y + dy), i = yy * L.w + xx;
        if (!L.m[i]) { s[0] += L.px[i * 4]; s[1] += L.px[i * 4 + 1]; s[2] += L.px[i * 4 + 2]; c++; }
      }
      const o = y * nw + x;
      if (c) { npx[o * 4] = s[0] / c; npx[o * 4 + 1] = s[1] / c; npx[o * 4 + 2] = s[2] / c; } else nm[o] = 1;
      npx[o * 4 + 3] = 255;
    }
    levels.push({ w: nw, h: nh, px: npx, m: nm });
  }
  const relax = (L, iters) => {
    const idx = [];
    for (let i = 0; i < L.w * L.h; i++) if (L.m[i]) idx.push(i);
    for (let it = 0; it < iters; it++) for (const i of idx) {
      const x = i % L.w, y = (i / L.w) | 0;
      let s0 = 0, s1 = 0, s2 = 0, c = 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const xx = x + dx, yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= L.w || yy >= L.h) continue;
        const j = (yy * L.w + xx) * 4; s0 += L.px[j]; s1 += L.px[j + 1]; s2 += L.px[j + 2]; c++;
      }
      L.px[i * 4] = s0 / c; L.px[i * 4 + 1] = s1 / c; L.px[i * 4 + 2] = s2 / c;
    }
  };
  relax(levels[levels.length - 1], 400);
  for (let k = levels.length - 2; k >= 0; k--) {
    const L = levels[k], C = levels[k + 1];
    for (let i = 0; i < L.w * L.h; i++) if (L.m[i]) {
      const x = i % L.w, y = (i / L.w) | 0;
      const fx = Math.min(C.w - 1, Math.max(0, (x + 0.5) / 2 - 0.5)), fy = Math.min(C.h - 1, Math.max(0, (y + 0.5) / 2 - 0.5));
      const x0 = Math.floor(fx), y0 = Math.floor(fy), x1 = Math.min(C.w - 1, x0 + 1), y1 = Math.min(C.h - 1, y0 + 1), tx = fx - x0, ty = fy - y0;
      for (let ch = 0; ch < 3; ch++) {
        const v = (C.px[(y0 * C.w + x0) * 4 + ch] * (1 - tx) + C.px[(y0 * C.w + x1) * 4 + ch] * tx) * (1 - ty)
                + (C.px[(y1 * C.w + x0) * 4 + ch] * (1 - tx) + C.px[(y1 * C.w + x1) * 4 + ch] * tx) * ty;
        L.px[i * 4 + ch] = v;
      }
    }
    relax(L, k === 0 ? 60 : 30);
  }
  return levels[0].px;
}

const filled = fill(img.px, MASK, W, H);
// grão leve nas áreas preenchidas (a pintura tem textura; o preenchimento puro fica "plástico")
let seed = 7;
const rnd = () => { seed = (seed * 16807) % 2147483647; return seed / 2147483647; };
for (let i = 0; i < W * H; i++) if (MASK[i]) {
  const n = (rnd() + rnd() + rnd() - 1.5) * 3.2;
  for (let ch = 0; ch < 3; ch++) img.px[i * 4 + ch] = Math.max(0, Math.min(255, filled[i * 4 + ch] + n));
}

// ---------------------------------------------------------------------------
// 6) Fios de energia pintados: separa a luz dos fios do chão/parede e gera os
//    quadros de pulso (SanctuaryFlow). No jogo a arte fica com os fios mais
//    fracos e os quadros (ADD, trocados em cruz) fazem a energia escorrer pelos
//    próprios fios, dos itens para o altar, como se o altar a sugasse.
// ---------------------------------------------------------------------------
const L = require("./layout");
const FLOW = { x: 100, y: 260, w: 1340, h: 750, scale: 0.5, frames: 8, cols: 3, lambda: 190, dim: 0.58 };
// caminhos dos fios, do item (início) até o altar; esticados nas duas pontas
const paths = Object.values(L.TRUNKS).map((pts) => {
  const p = pts.map((q) => q.slice());
  const ext = (a, b, d) => { const l = Math.hypot(a[0] - b[0], a[1] - b[1]); return [a[0] + (a[0] - b[0]) / l * d, a[1] + (a[1] - b[1]) / l * d]; };
  p.unshift(ext(p[0], p[1], 70));
  p.push(ext(p[p.length - 1], p[p.length - 2], 40));
  const cum = [0];
  for (let i = 1; i < p.length; i++) cum.push(cum[i - 1] + Math.hypot(p[i][0] - p[i - 1][0], p[i][1] - p[i - 1][1]));
  return { p, cum, total: cum[cum.length - 1] };
});
// para cada pixel: distância ao fio mais próximo e quanto falta até o altar
const FW = FLOW.w, FH = FLOW.h;
const fDist = new Float32Array(FW * FH).fill(1e9), fRem = new Float32Array(FW * FH), fFrac = new Float32Array(FW * FH);
for (let j = 0; j < FH; j++) for (let i = 0; i < FW; i++) {
  const x = FLOW.x + i + 0.5, y = FLOW.y + j + 0.5, k = j * FW + i;
  for (const P of paths) for (let s = 0; s < P.p.length - 1; s++) {
    const [ax, ay] = P.p[s], [bx, by] = P.p[s + 1], dx = bx - ax, dy = by - ay, l2 = dx * dx + dy * dy;
    const t = Math.max(0, Math.min(1, ((x - ax) * dx + (y - ay) * dy) / l2));
    const d = Math.hypot(x - ax - dx * t, y - ay - dy * t);
    if (d < fDist[k]) { fDist[k] = d; const along = P.cum[s] + Math.sqrt(l2) * t; fRem[k] = P.total - along; fFrac[k] = along / P.total; }
  }
}
// pixels de fio: ciano forte perto de um caminho (fora do altar e da névoa central)
const WMASK = new Uint8Array(W * H);
const inAltar = (x, y) => ((x - 790) / 255) ** 2 + ((y - 765) / 72) ** 2 < 1;
for (let j = 0; j < FH; j++) for (let i = 0; i < FW; i++) {
  const x = FLOW.x + i, y = FLOW.y + j, k = j * FW + i;
  if (fDist[k] > 85 || inAltar(x, y) || MASK[y * W + x]) continue;
  const o = (y * W + x) * 4, R = img.px[o], G = img.px[o + 1], B = img.px[o + 2];
  if (B - R > 28 && 0.3 * R + 0.59 * G + 0.11 * B > 48) WMASK[y * W + x] = 1;
}
{ // engorda 3 px (o halo dos fios)
  const src = Uint8Array.from(WMASK);
  for (let y = 3; y < H - 3; y++) for (let x = 3; x < W - 3; x++) if (src[y * W + x])
    for (let dy = -3; dy <= 3; dy++) for (let dx = -3; dx <= 3; dx++) if (!MASK[(y + dy) * W + x + dx]) WMASK[(y + dy) * W + x + dx] = 1;
}
const base = fill(img.px, WMASK, W, H);
const smooth = (e0, e1, v) => { const t = Math.max(0, Math.min(1, (v - e0) / (e1 - e0))); return t * t * (3 - 2 * t); };
const wisp = new Float32Array(FW * FH * 3);
for (let j = 0; j < FH; j++) for (let i = 0; i < FW; i++) {
  const x = FLOW.x + i, y = FLOW.y + j, g = y * W + x, k = j * FW + i;
  if (!WMASK[g]) continue;
  const feather = 1 - smooth(65, 85, fDist[k]);
  for (let ch = 0; ch < 3; ch++) {
    const v = Math.max(0, img.px[g * 4 + ch] - base[g * 4 + ch]) * feather;
    wisp[k * 3 + ch] = v;
    img.px[g * 4 + ch] -= v * (1 - FLOW.dim);   // arte com os fios mais fracos
  }
}
// quadros: pulsos que andam pelo fio rumo ao altar (fase k/N); nascem fracos na ponta do item
const FWs = Math.round(FW * FLOW.scale), FHs = Math.round(FH * FLOW.scale);
const flowTex = I.create(2048, 2048, 0, 0, 0, 255);
for (let f = 0; f < FLOW.frames; f++) {
  const ox = (f % FLOW.cols) * 680, oy = Math.floor(f / FLOW.cols) * 376;
  for (let j = 0; j < FHs; j++) for (let i = 0; i < FWs; i++) {
    const acc = [0, 0, 0];
    let n = 0;
    for (let sj = 0; sj < 2; sj++) for (let si = 0; si < 2; si++) {
      const xi = Math.min(FW - 1, i * 2 + si), yj = Math.min(FH - 1, j * 2 + sj), k = yj * FW + xi;
      const ph = fRem[k] / FLOW.lambda + f / FLOW.frames;
      const c = (1 + Math.cos(2 * Math.PI * ph)) / 2;
      const p = (0.10 + 0.90 * Math.pow(c, 2.4)) * (0.55 + 0.45 * smooth(0, 0.35, fFrac[k]));
      for (let ch = 0; ch < 3; ch++) acc[ch] += wisp[k * 3 + ch] * p * 1.15;
      n++;
    }
    const o = ((oy + j) * 2048 + ox + i) * 4;
    for (let ch = 0; ch < 3; ch++) flowTex.px[o + ch] = Math.min(255, acc[ch] / n);
  }
}
I.writeTGA(path.join(OUT, "SanctuaryFlow.tga"), flowTex);
if (fs.existsSync(GAME)) fs.copyFileSync(path.join(OUT, "SanctuaryFlow.tga"), path.join(GAME, "SanctuaryFlow.tga"));
{
  const fp = I.create(FWs, FHs, 0, 0, 0, 255);
  for (let j = 0; j < FHs; j++) for (let i = 0; i < FWs; i++) for (let ch = 0; ch < 3; ch++) fp.px[(j * FWs + i) * 4 + ch] = flowTex.px[(j * 2048 + i) * 4 + ch];
  I.writePNG(path.join(PREV, "flow0.png"), fp);
}
fs.writeFileSync(path.join(PREV, "flow.json"), JSON.stringify({ ...FLOW, fw: FWs, fh: FHs }));
console.log("gerado SanctuaryFlow 2048x2048,", FLOW.frames, "quadros de", FWs + "x" + FHs);

// ---------------------------------------------------------------------------
// Saída
// ---------------------------------------------------------------------------
const tex = I.create(2048, 2048, 0, 0, 0, 255);
I.blit(tex, img, 0, 0);
for (let i = 0; i < W * H; i++) img.px[i * 4 + 3] = 255;
I.writeTGA(path.join(OUT, "SanctuaryBG.tga"), tex);
if (fs.existsSync(GAME)) fs.copyFileSync(path.join(OUT, "SanctuaryBG.tga"), path.join(GAME, "SanctuaryBG.tga"));
I.writePNG(path.join(PREV, "bg.png"), img);
const mk = I.create(W, H, 0, 0, 0, 255);
for (let i = 0; i < W * H; i++) if (MASK[i]) { mk.px[i * 4] = 255; mk.px[i * 4 + 1] = 60; mk.px[i * 4 + 2] = 60; }
I.writePNG(path.join(PREV, "mask.png"), mk);
console.log("gerado SanctuaryBG 2048x2048 (", W + "x" + H, "úteis )");
