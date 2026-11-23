// Prévia dos efeitos "estilo Azaath" do Grimório: soma (ADD) as texturas reais
// sobre a réplica (preview/compare.png, metade esquerda) nas posições do Lua.
// Uso: node preview-azaath.js -> preview/azaath.png
const fs = require("fs");
const I = require("../sheet-concept/img");
const { readPNG } = require("./png");

function readTGA(f) {
  const b = fs.readFileSync(f), idl = b[0], type = b[2], w = b.readUInt16LE(12), h = b.readUInt16LE(14), Bp = b[16] / 8, top = (b[17] & 0x20) !== 0;
  let p = 18 + idl; const raw = [];
  if (type === 10) { while (raw.length < w * h) { const c = b[p++], n = (c & 0x7f) + 1; if (c & 0x80) { const v = b.slice(p, p + Bp); p += Bp; for (let k = 0; k < n; k++) raw.push(v); } else for (let k = 0; k < n; k++) { raw.push(b.slice(p, p + Bp)); p += Bp; } } }
  else for (let i = 0; i < w * h; i++) { raw.push(b.slice(p, p + Bp)); p += Bp; }
  const px = new Float32Array(w * h * 4);
  for (let i = 0; i < w * h; i++) { const x = i % w, y = Math.floor(i / w), yy = top ? y : h - 1 - y, o = (yy * w + x) * 4, v = raw[i]; px[o] = v[2]; px[o + 1] = v[1]; px[o + 2] = v[0]; px[o + 3] = Bp === 4 ? v[3] : 255; }
  return { w, h, px };
}
const M = "../../AzaathUI/Media/";
const T = {
  halo: readTGA(M + "CastRingHalo.tga"), edge: readTGA(M + "CastRingEdge.tga"), glow: readTGA(M + "Glow.tga"), star: readTGA(M + "Star.tga"),
  astro: readTGA(M + "Sheet/AstrolabeRing.tga"), rune: readTGA(M + "Sheet/PedestalRune.tga"), ring: readTGA(M + "Grimoire/GrimTabRing.tga"),
};
const base = readPNG("preview/compare.png");
const out = I.create(1376, 768);
for (let y = 0; y < 768; y++) for (let x = 0; x < 1376; x++) { const q = (y * base.w + x) * 4, o = (y * 1376 + x) * 4; for (let k = 0; k < 4; k++) out.px[o + k] = base.px[q + k]; }

// ADD de uma textura (centro cx,cy; tamanho w,h; cor; alfa; dessaturar; rotação)
function add(tex, cx, cy, w, h, col, alpha, desat, rot = 0) {
  const c = Math.cos(rot), s = Math.sin(rot);
  for (let y = Math.floor(cy - h); y <= cy + h; y++) for (let x = Math.floor(cx - w); x <= cx + w; x++) {
    if (x < 0 || y < 0 || x >= 1376 || y >= 768) continue;
    const dx = x + 0.5 - cx, dy = y + 0.5 - cy, u = (dx * c + dy * s) / w + 0.5, v = (-dx * s + dy * c) / h + 0.5;
    if (u < 0 || v < 0 || u >= 1 || v >= 1) continue;
    const q = (Math.floor(v * tex.h) * tex.w + Math.floor(u * tex.w)) * 4;
    let r = tex.px[q], g = tex.px[q + 1], b = tex.px[q + 2];
    if (desat) { const L = 0.3 * r + 0.59 * g + 0.11 * b; r = g = b = L; }
    const a = (tex.px[q + 3] / 255) * alpha, o = (y * 1376 + x) * 4;
    out.px[o] = Math.min(255, out.px[o] + r * col[0] * a); out.px[o + 1] = Math.min(255, out.px[o + 1] + g * col[1] * a); out.px[o + 2] = Math.min(255, out.px[o + 2] + b * col[2] * a);
  }
}
function mix(tex, cx, cy, w, h, col, alpha, desat, rot = 0) {
  const c = Math.cos(rot), s = Math.sin(rot);
  for (let y = Math.floor(cy - h); y <= cy + h; y++) for (let x = Math.floor(cx - w); x <= cx + w; x++) {
    if (x < 0 || y < 0 || x >= 1376 || y >= 768) continue;
    const dx = x + 0.5 - cx, dy = y + 0.5 - cy, u = (dx * c + dy * s) / w + 0.5, v = (-dx * s + dy * c) / h + 0.5;
    if (u < 0 || v < 0 || u >= 1 || v >= 1) continue;
    const q = (Math.floor(v * tex.h) * tex.w + Math.floor(u * tex.w)) * 4;
    let r = tex.px[q], g = tex.px[q + 1], b = tex.px[q + 2];
    if (desat) { const L = 0.3 * r + 0.59 * g + 0.11 * b; r = g = b = L; }
    const a = (tex.px[q + 3] / 255) * alpha, o = (y * 1376 + x) * 4;
    out.px[o] = out.px[o] * (1 - a) + r * col[0] * a; out.px[o + 1] = out.px[o + 1] * (1 - a) + g * col[1] * a; out.px[o + 2] = out.px[o + 2] * (1 - a) + b * col[2] * a;
  }
}
const TEAL = [0.10, 0.56, 0.80], DEEP = [0.05, 0.36, 0.58];
const CY = [0.37, 0.89, 1.0], ICE = [0.55, 0.95, 1.0], WH = [0.85, 0.99, 1.0];
// o anel dourado da réplica sai antes (era o efeito antigo)
// marcador ativo (PROTEÇÃO: nome em 245,485; anel em 232,485)
add(T.glow, 244, 485, 96, 46, CY, 0.2, false);
add(T.astro, 232, 485, 86, 86, CY, 0.38, true, 0.6);
add(T.ring, 232, 485, 128, 128, CY, 0.95, true);
for (let k = 0; k < 3; k++) { const a = 0.7 + k * 2.094; add(T.star, 232 + Math.cos(a) * 36, 485 + Math.sin(a) * 33, 11, 11, WH, 0.85, false, k); }
// medalhão escolhido (Fender, 80 px)
mix(T.halo, 432, 266, 114, 114, TEAL, 0.6, false);
mix(T.edge, 432, 266, 104, 104, DEEP, 0.75, false, 0.4);
for (let k = 0; k < 2; k++) { const a = 1.0 + k * Math.PI; add(T.star, 432 + Math.cos(a) * 51, 266 + Math.sin(a) * 51, 10, 10, WH, 0.9, false); }
// centro do diagrama: diagrama (GrimDiagram) + aura + ícone + anel rúnico
{
  const dg = readTGA(M + "Grimoire/GrimDiagram.tga");
  for (let y = 0; y < 207; y++) for (let x = 0; x < 226; x++) {
    const q = (y * dg.w + x) * 4, a = dg.px[q + 3] / 255, o = ((230 + y) * 1376 + 755 + x) * 4;
    for (let k = 0; k < 3; k++) out.px[o + k] = out.px[o + k] * (1 - a) + dg.px[q + k] * a;
  }
}
mix(T.halo, 867.5, 328, 104, 104, TEAL, 0.5, false);
{ // ícone (recorte do conceito)
  const src = readPNG("concept.png");
  for (let y = -31; y <= 31; y++) for (let x = -31; x <= 31; x++) {
    if (x * x + y * y > 31 * 31) continue;
    const q = ((328 + y) * src.w + 867 + x) * 4, o = ((328 + y) * 1376 + 867 + x) * 4;
    for (let k = 0; k < 3; k++) out.px[o + k] = src.px[q + k];
  }
}
mix(T.edge, 867.5, 328, 86, 86, DEEP, 0.75, false, 0.3);
I.writePNG("preview/azaath.png", out);
const crop = (x0, y0, w, h, S, f) => { const o = I.create(w * S, h * S); for (let y = 0; y < h * S; y++) for (let x = 0; x < w * S; x++) { const q = ((y0 + (y / S | 0)) * 1376 + x0 + (x / S | 0)) * 4, d = (y * o.w + x) * 4; for (let k = 0; k < 4; k++) o.px[d + k] = out.px[q + k]; } I.writePNG(f, o); };
crop(170, 160, 900, 440, 1, "preview/azaath_crop.png");
console.log("ok");
