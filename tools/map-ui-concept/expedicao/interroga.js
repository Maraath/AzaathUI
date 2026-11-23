// "?" de entregar mais visível: recorta o glifo, amarelo vivo e contorno escuro mais grosso -> PinTurnInV.tga
"use strict";
const fs = require("fs"), path = require("path"), cp = require("child_process");
const I = require("../../sheet-concept/img");
const JOBS = [["PinTurnIn", "PinTurnInV", [255, 216, 24]]];
const MF = "D:/ProjectAzaath/AzaathUI/Media/MapFrame";
for (const [SRC, DST, INNER] of JOBS) {
const raw = cp.execFileSync("ffmpeg", ["-loglevel", "error", "-i", MF + "/" + SRC + ".tga", "-f", "rawvideo", "-pix_fmt", "rgba", "-"], { maxBuffer: 1 << 24 });
const W = 64, H = 64, K = 3;
// "!" vem dentro de um disco escuro: o glifo é só a parte amarela (r bem acima de b); o disco some
const SIZE = raw.length / 4;
if (SRC === "PinNew") for (let i = 0; i < SIZE; i++) { const rb = raw[i * 4] - raw[i * 4 + 2]; const m = Math.max(0, Math.min(1, (rb - 40) / 70)); raw[i * 4 + 3] = Math.round(raw[i * 4 + 3] * m); raw[i * 4] = raw[i * 4 + 1] = raw[i * 4 + 2] = 200; }                  // K = ampliação (suave abaixo)
// endireita o "!": ângulo do eixo maior (momentos) em relação à vertical e rotação inversa em volta do centro de massa
if (SRC === "PinNew") {
  let sa = 0, cx = 0, cy = 0;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const q = raw[(y * W + x) * 4 + 3]; sa += q; cx += q * x; cy += q * y; }
  cx /= sa; cy /= sa;
  let sxx = 0, syy = 0, sxy = 0;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { const q = raw[(y * W + x) * 4 + 3]; sxx += q * (x - cx) ** 2; syy += q * (y - cy) ** 2; sxy += q * (x - cx) * (y - cy); }
  const th = 0.5 * Math.atan2(2 * sxy, syy - sxx);        // desvio da vertical (rad)
  console.log("inclinação do !:", (th * 180 / Math.PI).toFixed(2), "graus");
  const c = Math.cos(th), sn = Math.sin(th), src = Buffer.from(raw);
  const at = (x, y, k) => (x < 0 || y < 0 || x >= W || y >= H) ? 0 : src[(y * W + x) * 4 + k];
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    const dx = x - cx, dy = y - cy, ux = cx + dx * c + dy * sn, uy = cy - dx * sn + dy * c;   // amostra a imagem girada de volta
    const fx = Math.floor(ux), fy = Math.floor(uy), tx = ux - fx, ty = uy - fy;
    for (let k = 0; k < 4; k++) raw[(y * W + x) * 4 + k] = Math.round((at(fx, fy, k) * (1 - tx) + at(fx + 1, fy, k) * tx) * (1 - ty) + (at(fx, fy + 1, k) * (1 - tx) + at(fx + 1, fy + 1, k) * tx) * ty);
  }
}
let x0 = W, y0 = H, x1 = 0, y1 = 0;
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) if (raw[(y * W + x) * 4 + 3] > 90) { x0 = Math.min(x0, x); x1 = Math.max(x1, x); y0 = Math.min(y0, y); y1 = Math.max(y1, y); }
const P = 4, w = (x1 - x0 + 1) + P * 2, h = (y1 - y0 + 1) + P * 2;
const fill = new Float32Array(w * h), al = new Float32Array(w * h);
for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
  const sx = x - P + x0, sy = y - P + y0;
  if (sx < 0 || sy < 0 || sx >= W || sy >= H) continue;
  const o = (sy * W + sx) * 4, a = raw[o + 3] / 255, lum = (raw[o] + raw[o + 1] + raw[o + 2]) / 3;
  al[y * w + x] = a; fill[y * w + x] = a * Math.min(1, Math.max(0, (lum - 70) / 90));   // 1 = miolo claro, 0 = contorno
}
const out = I.create(w, h), R = 3.2;
for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
  let dmin = 99;
  for (let dy = -4; dy <= 4; dy++) for (let dx = -4; dx <= 4; dx++) {
    const xx = x + dx, yy = y + dy; if (xx < 0 || yy < 0 || xx >= w || yy >= h) continue;
    if (al[yy * w + xx] >= 0.5) dmin = Math.min(dmin, Math.hypot(dx, dy));
  }
  const ba = Math.max(0, Math.min(1, R + 0.5 - dmin)), sa = al[y * w + x], f = fill[y * w + x] / Math.max(sa, 0.001);
  const o = (y * w + x) * 4, a = Math.max(sa, ba);
  const inner = INNER, rim = [38, 22, 4];
  for (let k = 0; k < 3; k++) out.px[o + k] = rim[k] + (inner[k] - rim[k]) * Math.min(1, f * (sa > 0.5 ? 1 : 0));
  out.px[o + 3] = Math.round(a * 255);
}
const big = I.resize ? I.resize(out, w * 2, h * 2) : out;
for (const d of [MF, "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame"]) I.writeTGA(d + "/" + DST + ".tga", big);
I.writePNG(path.join(__dirname, "out", "icons", DST + ".png"), big);
console.log(DST, big.w, big.h);
}
