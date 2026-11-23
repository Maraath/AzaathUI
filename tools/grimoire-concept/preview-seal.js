// Prévia do selecionado (selo rúnico + diagrama aceso) sobre a réplica do livro,
// nas posições do Grimoire.lua. Uso: node preview-seal.js -> preview/seal.png
const fs = require("fs");
const I = require("../sheet-concept/img");
const { readPNG } = require("./png");
function readTGA(f) {
  const b = fs.readFileSync(f), w = b.readUInt16LE(12), h = b.readUInt16LE(14), top = (b[17] & 0x20) !== 0, im = I.create(w, h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { const s = 18 + ((top ? y : h - 1 - y) * w + x) * 4, o = (y * w + x) * 4; im.px[o] = b[s + 2]; im.px[o + 1] = b[s + 1]; im.px[o + 2] = b[s]; im.px[o + 3] = b[s + 3]; }
  return im;
}
const G = "../../AzaathUI/Media/Grimoire/";
const SEAL_K = 1.62;   // igual ao Grimoire.lua
const base = readPNG("preview/compare.png");
const out = I.create(1376, 768);
for (let y = 0; y < 768; y++) for (let x = 0; x < 1376; x++) { const q = (y * base.w + x) * 4, o = (y * 1376 + x) * 4; for (let k = 0; k < 4; k++) out.px[o + k] = base.px[q + k]; }
// desenha a textura (região até u1, v1) num retângulo com mistura normal (BLEND)
function blend(tex, x0, y0, w, h, u1 = 1, v1 = 1) {
  for (let y = Math.floor(y0); y < y0 + h; y++) for (let x = Math.floor(x0); x < x0 + w; x++) {
    const u = (x + 0.5 - x0) / w * u1, v = (y + 0.5 - y0) / h * v1;
    if (u < 0 || v < 0 || u >= 1 || v >= 1) continue;
    const q = (Math.floor(v * tex.h) * tex.w + Math.floor(u * tex.w)) * 4, a = tex.px[q + 3] / 255, o = (y * 1376 + x) * 4;
    for (let k = 0; k < 3; k++) out.px[o + k] = out.px[o + k] * (1 - a) + tex.px[q + k] * a;
  }
}
// página direita: diagrama + brilho + ícone + aro (ícone recortado do conceito)
blend(readTGA(G + "GrimDiagram.tga"), 755, 230, 226, 207, 226 / 256, 207 / 256);
blend(readTGA(G + "GrimDiagramGlow.tga"), 755, 230, 226, 207, 226 / 256, 207 / 256);
const con = readPNG("concept.png");
for (let y = -31; y <= 31; y++) for (let x = -31; x <= 31; x++) if (x * x + y * y <= 961) { const q = ((328 + y) * con.w + 867 + x) * 4, o = ((328 + y) * 1376 + 867 + x) * 4; for (let k = 0; k < 3; k++) out.px[o + k] = con.px[q + k]; }
blend(readTGA(G + "GrimIconRing.tga"), 867.5 - 52.5, 328 - 52.5, 105, 105);
// página esquerda: selo no medalhão selecionado (Fender, 80 px)
const ss = 80 * SEAL_K;
blend(readTGA(G + "GrimRuneSeal.tga"), 432 - ss / 2, 266 - ss / 2, ss, ss);
const crop = I.create(900, 440);
for (let y = 0; y < 440; y++) for (let x = 0; x < 900; x++) { const q = ((160 + y) * 1376 + 170 + x) * 4, d = (y * 900 + x) * 4; for (let k = 0; k < 4; k++) crop.px[d + k] = out.px[q + k]; }
I.writePNG("preview/seal.png", crop);
console.log("ok");
