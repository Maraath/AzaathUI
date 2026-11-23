// Texturas da aba Ofícios recortadas das referências de arte (ref-frames.png e
// ref-rings.png, convertidas de 3.webp/4.webp que o usuário enviou em 2026-11-17):
//
//   CraftFrames.tga  molduras chanfradas (cartas/painéis normal e ativo), busca,
//                    pílulas, botões (dourado, escuro, vermelho, quadrado),
//                    barra de progresso (vazia e cheia), losango e clarão
//   CraftRings.tga   círculo rúnico do altar, anéis (bronze, escuro, pequeno),
//                    gemas de dificuldade, estrelas e setas
//
// O fundo preto vira transparência (luminância -> alfa, cor "despremultiplicada").
// Ornamentos (losango no meio da borda, clarão) são apagados da moldura e saem
// como peças próprias, para não esticarem no 9-slice.
// Também grava o bloco CRAFT_ATLAS dentro de Modules/Professions.lua (entre marcas)
// e preview/*.png com as molduras montadas nos tamanhos usados na aba.
//
//   node tools/professions-ui-concept/gen.js
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const ROOT = path.join(__dirname, "..", "..");
const OUTS = [path.join(ROOT, "AzaathUI", "Media", "Sheet"),
  "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Sheet"];
const LUA = path.join(ROOT, "AzaathUI", "Modules", "Professions.lua");
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(PREV, { recursive: true });

const FR = readPNG(path.join(__dirname, "ref-frames.png"));
const RG = readPNG(path.join(__dirname, "ref-rings.png"));

// --- utilidades ------------------------------------------------------------------
const px = (img, x, y) => (y * img.w + x) * 4;
function extract(img, lo = 8, hi = 46) {
  const o = I.create(img.w, img.h);
  for (let i = 0; i < img.w * img.h; i++) {
    const r = img.px[i * 4], g = img.px[i * 4 + 1], b = img.px[i * 4 + 2];
    const m = Math.max(r, g, b), a = Math.max(0, Math.min(1, (m - lo) / (hi - lo)));
    if (a <= 0) continue;
    const dv = Math.max(a, 0.3); // só "despremultiplica" onde há cobertura (evita franjas de ruído)
    o.px[i * 4] = Math.min(255, r / dv); o.px[i * 4 + 1] = Math.min(255, g / dv); o.px[i * 4 + 2] = Math.min(255, b / dv);
    o.px[i * 4 + 3] = a * 255;
  }
  return o;
}
// apaga ornamentos em [x0..x1] x [y0..y1]: interpola, linha a linha, entre a coluna
// logo à esquerda e a logo à direita (srcX só é usado se a direita sair da imagem)
function clearCols(img, x0, x1, y0, y1, srcX) {
  const L = x0 - 1, R = x1 + 1 < img.w ? x1 + 1 : srcX;
  for (let y = Math.max(0, y0); y <= Math.min(img.h - 1, y1); y++)
    for (let x = x0; x <= x1; x++) {
      const t = R === srcX ? 0 : (x - L) / (R - L);
      for (let k = 0; k < 4; k++) img.px[px(img, x, y) + k] = img.px[px(img, L, y) + k] * (1 - t) + img.px[px(img, R, y) + k] * t;
    }
}
// diferença (original - limpo): isola um brilho para desenhar em modo ADD
function diff(a, b) {
  const o = I.create(a.w, a.h);
  for (let i = 0; i < a.w * a.h; i++) {
    let m = 0;
    for (let k = 0; k < 3; k++) { const v = Math.max(0, a.px[i * 4 + k] - b.px[i * 4 + k]); o.px[i * 4 + k] = v; m = Math.max(m, v); }
    o.px[i * 4 + 3] = 255;
  }
  return o;
}
// máscara de losango (|dx|+|dy| <= r) para recortar o ornamento de bronze
function diamondMask(img, feather = 1.5) {
  const cx = (img.w - 1) / 2, cy = (img.h - 1) / 2, r = Math.min(cx, cy);
  for (let y = 0; y < img.h; y++) for (let x = 0; x < img.w; x++) {
    const d = Math.abs(x - cx) + Math.abs(y - cy), a = Math.max(0, Math.min(1, (r - d) / feather));
    img.px[px(img, x, y) + 3] = 255 * a;
  }
  return img;
}

// --- peças ------------------------------------------------------------------------
// box = retângulo da moldura (sem brilho) em coordenadas da folha; crop = box + pad
// m = margens do 9-slice medidas a partir da borda da moldura (sem o pad)
const P = 10;
const pieces = [];
function frame(name, src, box, m, opts = {}) {
  const pad = opts.pad ?? P;
  const cx = box[0] - pad, cy = box[1] - pad, cw = box[2] - box[0] + 1 + pad * 2, ch = box[3] - box[1] + 1 + pad * 2;
  let raw = I.crop(src, cx, cy, cw, ch);
  const clean = I.crop(src, cx, cy, cw, ch);
  for (const c of opts.clear || []) clearCols(clean, c[0] - cx, c[1] - cx, c[2] - cy, c[3] - cy, c[4] - cx);
  pieces.push({ name, atlas: opts.atlas || "CraftFrames", img: extract(clean, opts.lo, opts.hi), pad, m, kind: "frame",
    ow: box[2] - box[0] + 1, oh: box[3] - box[1] + 1 });
  if (opts.flare) {
    const f = opts.flare; // [x0,y0,x1,y1] em coordenadas da folha
    const d = diff(I.crop(src, f[0], f[1], f[2] - f[0] + 1, f[3] - f[1] + 1),
      I.crop(clean, f[0] - cx, f[1] - cy, f[2] - f[0] + 1, f[3] - f[1] + 1));
    pieces.push({ name: name + "Flare", atlas: "CraftFrames", img: d, kind: "add", cy: opts.flareCY - f[1] });
  }
  return raw;
}
function sprite(name, src, b, opts = {}) {
  const pad = opts.pad ?? 3;
  let img = I.crop(src, b[0] - pad, b[1] - pad, b[2] - b[0] + 1 + pad * 2, b[3] - b[1] + 1 + pad * 2);
  img = opts.raw ? img : extract(img, opts.lo, opts.hi);
  if (opts.size) img = I.resize(img, opts.size, opts.size);
  if (opts.mask) diamondMask(img);
  pieces.push({ name, atlas: opts.atlas || "CraftRings", img, kind: "sprite" });
}

// Cartas (retrato): chanfro ~34 px; losango de bronze em cima/baixo; clarão no ativo
frame("CardN", FR, [355, 38, 620, 383], [40, 40, 40, 40],
  { clear: [[470, 506, 28, 62, 460], [470, 506, 360, 392, 460]] });
frame("CardA", FR, [760, 38, 1026, 384], [40, 40, 40, 40],
  { clear: [[840, 950, 0, 120, 830], [880, 908, 368, 395, 870]], flare: [833, 0, 955, 100], flareCY: 40 });
// Painéis largos (trilhas): chanfro ~14 px
frame("WideN", FR, [42, 457, 333, 557], [30, 26, 30, 26],
  { clear: [[174, 200, 448, 470, 168], [174, 200, 545, 568, 168]] });
frame("WideA", FR, [372, 458, 664, 558], [30, 26, 30, 26],
  { clear: [[470, 570, 420, 520, 460]], flare: [462, 418, 576, 500], flareCY: 457 });
// Busca e pílulas (3 fatias: pontas arredondadas)
frame("Search", FR, [704, 468, 1123, 542], [38, 0, 38, 0], { pad: 6 });
frame("PillN", FR, [1164, 457, 1333, 500], [22, 0, 22, 0], { pad: 5 });
frame("PillA", FR, [1164, 514, 1333, 559], [24, 0, 24, 0], { pad: 7 });
// Botões
frame("BtnGold", FR, [44, 630, 324, 727], [56, 0, 56, 0], { pad: 10 });
frame("BtnDark", FR, [361, 632, 592, 723], [24, 24, 24, 24], { pad: 4 });
frame("BtnRed", FR, [622, 633, 854, 723], [16, 16, 16, 16], { pad: 4 });
frame("BtnSquare", FR, [891, 632, 982, 723], [24, 24, 24, 24], { pad: 4 });
// Barra: vazia (divisões apagadas; a aba desenha as suas) e cheia
frame("BarEmpty", FR, [1018, 632, 1333, 670], [10, 0, 10, 0],
  { pad: 3, clear: [[1110, 1140, 625, 676, 1080], [1213, 1243, 625, 676, 1080]] });
frame("BarFill", FR, [1018, 689, 1333, 723], [8, 0, 8, 0], { pad: 3 });
// Losango de bronze (ornamento das molduras normais)
sprite("Diamond", FR, [478, 28, 498, 49], { pad: 2, raw: true, mask: true, atlas: "CraftFrames" });

// Anéis, gemas, estrelas, setas
sprite("Runes", RG, [33, 36, 716, 733], { pad: 6, size: 640 });
sprite("RingBronze", RG, [870, 25, 1211, 367], { pad: 4 });
sprite("RingDark", RG, [776, 367, 1047, 637], { pad: 4 });
sprite("RingSmall", RG, [1140, 388, 1258, 509], { pad: 4 });
sprite("StarGold", RG, [1128, 532, 1216, 619]);
sprite("StarGray", RG, [1231, 536, 1314, 616]);
sprite("GemOptimal", RG, [776, 658, 826, 719]);
sprite("GemMedium", RG, [850, 659, 901, 719]);
sprite("GemEasy", RG, [924, 659, 974, 719]);
sprite("GemTrivial", RG, [998, 658, 1047, 719]);
sprite("ArrowL", RG, [1134, 647, 1194, 729]);
sprite("ArrowR", RG, [1248, 646, 1308, 729]);

// --- empacotamento (skyline) --------------------------------------------------------
const SIZE = 1024;
const atlases = {};
for (const name of ["CraftFrames", "CraftRings"]) {
  const list = pieces.filter((p) => p.atlas === name).sort((a, b) => b.img.h - a.img.h);
  const sky = new Int32Array(SIZE).fill(0), tex = I.create(SIZE, SIZE);
  for (const p of list) {
    const w = p.img.w + 2, h = p.img.h + 2;
    let best = null;
    for (let x = 0; x + w <= SIZE; x++) {
      let y = 0; for (let k = x; k < x + w; k++) y = Math.max(y, sky[k]);
      if (y + h <= SIZE && (!best || y < best.y)) best = { x, y };
    }
    if (!best) throw new Error("não coube no atlas " + name + ": " + p.name);
    for (let k = best.x; k < best.x + w; k++) sky[k] = best.y + h;
    p.x = best.x + 1; p.y = best.y + 1;
    I.blit(tex, p.img, p.x, p.y);
  }
  atlases[name] = tex;
  for (const dir of OUTS) { try { I.writeTGA(path.join(dir, name + ".tga"), tex); } catch (e) { console.log("sem acesso:", dir); } }
  I.writePNG(path.join(PREV, name + ".png"), tex);
  console.log(name, list.length, "peças, altura usada", Math.max(...sky));
}

// --- bloco Lua --------------------------------------------------------------------------
{
  const L = ["-- @@CRAFT ATLAS (gerado por tools/professions-ui-concept/gen.js)@@",
    "-- x, y, w, h em px do atlas 1024; pad = brilho fora da moldura; m = margens do 9-slice (l, t, r, b)",
    "local CRAFT_ATLAS = {"];
  for (const p of pieces) {
    let s = `    ${p.name} = { file = "${p.atlas}", x = ${p.x}, y = ${p.y}, w = ${p.img.w}, h = ${p.img.h}`;
    if (p.kind === "frame") s += `, pad = ${p.pad}, ow = ${p.ow}, oh = ${p.oh}, m = { ${p.m.join(", ")} }`;
    if (p.kind === "add") s += `, add = true, cy = ${p.cy}`;
    L.push(s + " },");
  }
  L.push("}", "-- @@FIM DO CRAFT ATLAS@@");
  let lua = fs.readFileSync(LUA, "utf8");
  const BEGIN = "-- @@CRAFT ATLAS", END = "-- @@FIM DO CRAFT ATLAS@@";
  const i = lua.indexOf(BEGIN), j = lua.indexOf(END);
  if (i < 0 || j < 0) console.log("AVISO: marcas do atlas não encontradas em Professions.lua");
  else { lua = lua.slice(0, i) + L.join("\n") + lua.slice(j + END.length); fs.writeFileSync(LUA, lua); console.log("CRAFT_ATLAS gravado em Professions.lua"); }
}

// --- prévia: 9-slice montado nos tamanhos da aba, sobre um fundo escuro -----------------
function nine(dst, p, X, Y, W, H, s) {
  const src = I.crop(atlases[p.atlas], p.x, p.y, p.img.w, p.img.h);
  const [ml, mt, mr, mb] = p.m.map((v) => v + p.pad);
  const dl = ml * s, dt = mt * s, dr = mr * s, db = mb * s;
  const ox = X - p.pad * s, oy = Y - p.pad * s, OW = W + 2 * p.pad * s, OH = H + 2 * p.pad * s;
  const cols = [[0, ml, 0, dl], [ml, src.w - mr, dl, OW - dr], [src.w - mr, src.w, OW - dr, OW]];
  const rows = [[0, mt, 0, dt], [mt, src.h - mb, dt, OH - db], [src.h - mb, src.h, OH - db, OH]];
  for (const [sx0, sx1, dx0, dx1] of cols) for (const [sy0, sy1, dy0, dy1] of rows) {
    const sw = sx1 - sx0, sh = sy1 - sy0, dw = Math.round(ox + dx1) - Math.round(ox + dx0), dh = Math.round(oy + dy1) - Math.round(oy + dy0);
    if (sw <= 0 || sh <= 0 || dw <= 0 || dh <= 0) continue;
    const part = I.resize(I.crop(src, sx0, sy0, sw, sh), dw, dh);
    for (let y = 0; y < dh; y++) for (let x = 0; x < dw; x++) {
      const tx = Math.round(ox + dx0) + x, ty = Math.round(oy + dy0) + y;
      if (tx < 0 || ty < 0 || tx >= dst.w || ty >= dst.h) continue;
      const a = part.px[(y * dw + x) * 4 + 3] / 255, d = (ty * dst.w + tx) * 4;
      for (let k = 0; k < 3; k++) dst.px[d + k] = dst.px[d + k] * (1 - a) + part.px[(y * dw + x) * 4 + k] * a;
    }
  }
}
{
  const by = Object.fromEntries(pieces.map((p) => [p.name, p]));
  const pv = I.create(1200, 520, 14, 22, 30, 255);
  nine(pv, by.CardN, 20, 30, 260, 250, 1); nine(pv, by.CardA, 300, 30, 260, 250, 1);
  nine(pv, by.CardN, 580, 30, 160, 118, 0.62); nine(pv, by.CardA, 760, 30, 160, 118, 0.62);
  nine(pv, by.WideN, 20, 320, 262, 76, 0.7); nine(pv, by.WideA, 300, 320, 262, 76, 0.7);
  nine(pv, by.Search, 580, 330, 560, 34, 0.46);
  nine(pv, by.BtnDark, 20, 430, 54, 46, 0.5); nine(pv, by.BtnSquare, 90, 430, 46, 46, 0.5);
  nine(pv, by.BtnGold, 150, 430, 200, 46, 0.45); nine(pv, by.BtnRed, 370, 430, 92, 46, 0.5);
  nine(pv, by.BarEmpty, 500, 440, 560, 14, 0.37); nine(pv, by.PillA, 580, 390, 120, 24, 0.55); nine(pv, by.PillN, 720, 390, 120, 24, 0.55);
  I.writePNG(path.join(PREV, "montagem.png"), pv);
  console.log("prévia:", path.join(PREV, "montagem.png"));
}

// prévia dos atlas sobre fundo escuro (como ficam no jogo)
for (const name of ["CraftRings", "CraftFrames"]) {
  const a = atlases[name], o = I.create(a.w, a.h, 14, 22, 30, 255);
  for (let i = 0; i < a.w * a.h; i++) { const al = a.px[i * 4 + 3] / 255; for (let k = 0; k < 3; k++) o.px[i * 4 + k] = o.px[i * 4 + k] * (1 - al) + a.px[i * 4 + k] * al; }
  I.writePNG(path.join(PREV, name + "_sobre_fundo.png"), o);
}
