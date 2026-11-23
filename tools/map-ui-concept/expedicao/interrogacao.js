// "?" desenhado na geometria, no mesmo acabamento dos "!" (miolo vivo com degradê + contorno escuro) -> PinTurnInV3
"use strict";
const path = require("path"), I = require("../../sheet-concept/img");
const W = 72, H = 108, SS = 3, R = 4.6, HW = 6.8;
const CX = 36, CY = 34, RAD = 17.5, DOT = [36, 94], DOT_R = 9;
const pts = [];
for (let t = Math.PI * 0.93; t <= Math.PI * 2 + 0.85; t += 0.02) pts.push([CX + RAD * Math.cos(t), CY + RAD * Math.sin(t)]);
const E = pts[pts.length - 1], Cc = [47, 55], F = [36, 62];
for (let u = 0.02; u <= 1; u += 0.02) pts.push([(1 - u) * (1 - u) * E[0] + 2 * u * (1 - u) * Cc[0] + u * u * F[0], (1 - u) * (1 - u) * E[1] + 2 * u * (1 - u) * Cc[1] + u * u * F[1]]);
for (let y = 63; y <= 67; y += 0.5) pts.push([36, y]);
const inside = (x, y) => {
  if (Math.hypot(x - DOT[0], y - DOT[1]) <= DOT_R) return true;
  for (let i = 0; i < pts.length; i++) { const dx = x - pts[i][0], dy = y - pts[i][1]; if (dx * dx + dy * dy <= HW * HW) return true; }
  return false;
};
const cov = new Float32Array(W * H);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { let n = 0; for (let j = 0; j < SS; j++) for (let i = 0; i < SS; i++) if (inside(x + (i + .5) / SS, y + (j + .5) / SS)) n++; cov[y * W + x] = n / (SS * SS); }
const out = I.create(W, H), rim = [38, 22, 4], hi = [255, 226, 60], lo = [255, 200, 14], span = Math.ceil(R) + 1;
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  let dmin = 99;
  for (let dy = -span; dy <= span; dy++) for (let dx = -span; dx <= span; dx++) { const xx = x + dx, yy = y + dy; if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue; if (cov[yy * W + xx] >= 0.5) dmin = Math.min(dmin, Math.hypot(dx, dy)); }
  const sa = cov[y * W + x], ba = Math.max(0, Math.min(1, R + 0.5 - dmin)), a = Math.max(sa, ba), t = y / H;
  const f = [0, 1, 2].map((k) => hi[k] + (lo[k] - hi[k]) * Math.min(1, t * 1.1)), o = (y * W + x) * 4;
  for (let k = 0; k < 3; k++) out.px[o + k] = rim[k] + (f[k] - rim[k]) * sa;
  out.px[o + 3] = Math.round(a * 255);
}
for (const d of ["D:/ProjectAzaath/AzaathUI/Media/MapFrame", "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame"]) I.writeTGA(d + "/PinTurnInV3.tga", out);
I.writePNG(path.join(__dirname, "out", "icons", "PinTurnInV3.png"), out);
