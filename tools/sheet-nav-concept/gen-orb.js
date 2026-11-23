// Gera o orbe de "Poder de Item" do cabeçalho da ficha (tecla C) recortando-o da
// arte de conceito tools/sheet-nav-concept/concept.png (1024x100):
//   * moldura metálica com 4 pontas + 4 entalhes, anel ciano (esq.) / ouro (dir.),
//     disco interno escuro com aro fino — exatamente como na arte;
//   * o número ("10") é apagado por preenchimento harmônico (o jogo escreve o valor);
//   * fora do disco, a transparência sai do contraste com o fundo da arte, então o
//     brilho e as pontas se fundem ao fundo do jogo.
// Saída: AzaathUI/Media/Sheet/ItemPowerOrb.tga (256x256) + preview/orb-*.png
// Uso: node tools/sheet-nav-concept/gen-orb.js
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Sheet");
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(PREV, { recursive: true });

const src = readPNG(path.join(__dirname, "concept.png"));
const CX = 975, CY = 49, R = 38;          // centro do orbe e raio até a ponta das espinhas (+2)
const N = R * 2 + 1;                        // 77x77 px da arte
const OPAQUE_R = 29;                        // disco + anéis: opaco até aqui
const BG = [7, 11, 17];                     // fundo da arte ao redor do orbe

const im = I.crop(src, CX - R, CY - R, N, N);
const get = (x, y) => { const o = (y * N + x) * 4; return [im.px[o], im.px[o + 1], im.px[o + 2]]; };
const set = (x, y, c) => { const o = (y * N + x) * 4; im.px[o] = c[0]; im.px[o + 1] = c[1]; im.px[o + 2] = c[2]; };

// 1) apaga o número: elipse |dx|<=13, |dy|<=10 em volta do centro, preenchida por Laplace
const inNumber = (x, y) => { const dx = (x - R) / 15, dy = (y - R) / 12.5; return dx * dx + dy * dy <= 1; };
{
  let acc = [0, 0, 0], n = 0;
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    const dx = (x - R) / 17, dy = (y - R) / 14.5, e = dx * dx + dy * dy;
    if (e > 1 && e <= 1.25) { const c = get(x, y); acc = acc.map((v, k) => v + c[k]); n++; }
  }
  const mean = acc.map((v) => v / n);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) if (inNumber(x, y)) set(x, y, mean);
  for (let it = 0; it < 3000; it++) for (let y = 1; y < N - 1; y++) for (let x = 1; x < N - 1; x++) {
    if (!inNumber(x, y)) continue;
    const a = get(x + 1, y), b = get(x - 1, y), c = get(x, y + 1), d = get(x, y - 1);
    set(x, y, [0, 1, 2].map((k) => (a[k] + b[k] + c[k] + d[k]) / 4));
  }
}

// 2) transparência: opaco no disco; fora dele, pelo contraste com o fundo
const smooth = (t) => { t = Math.max(0, Math.min(1, t)); return t * t * (3 - 2 * t); };
const out = I.create(N, N);
for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
  const c = get(x, y), r = Math.hypot(x - R, y - R);
  const diff = Math.max(c[0] - BG[0], c[1] - BG[1], c[2] - BG[2], 0);
  let a = Math.max(smooth(diff / 46), 1 - smooth((r - OPAQUE_R) / 2));
  a *= 1 - smooth((r - (R - 3)) / 3);       // zera na borda do recorte
  const o = (y * N + x) * 4;
  for (let k = 0; k < 3; k++) out.px[o + k] = a > 0.02 ? Math.max(0, Math.min(255, BG[k] + (c[k] - BG[k]) / a)) : BG[k];
  out.px[o + 3] = a * 255;
}

// 3) amplia para 256x256 (o jogo desenha ~65 unidades de UI, perto da resolução da arte)
const big = I.resize(out, 256, 256);
I.writeTGA(path.join(OUT, "ItemPowerOrb.tga"), big);

// prévias: textura sobre o fundo da arte, ampliada, ao lado do recorte original
const S = 6, prev = I.create(N * S * 2, N * S, 0, 0, 0, 255);
for (let y = 0; y < N * S; y++) for (let x = 0; x < N * S; x++) {
  const sx = Math.floor(x / S), sy = Math.floor(y / S);
  const so = ((CY - R + sy) * src.w + (CX - R + sx)) * 4, d = (y * prev.w + x) * 4;
  for (let k = 0; k < 3; k++) prev.px[d + k] = src.px[so + k];
  const bo = (Math.floor(y * 256 / (N * S)) * 256 + Math.floor(x * 256 / (N * S))) * 4, a = big.px[bo + 3] / 255;
  const d2 = (y * prev.w + x + N * S) * 4;
  for (let k = 0; k < 3; k++) prev.px[d2 + k] = BG[k] * (1 - a) + big.px[bo + k] * a;
}
I.writePNG(path.join(PREV, "orb-compare.png"), prev);
console.log("ok: ItemPowerOrb.tga + preview/orb-compare.png");
