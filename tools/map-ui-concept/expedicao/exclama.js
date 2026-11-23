// "!" desenhado na geometria (reto e simétrico) com o mesmo tratamento do "?": miolo vivo + contorno escuro -> PinNewV / PinRepeatV
"use strict";
const path = require("path"), I = require("../../sheet-concept/img");
const W = 56, H = 136, CX = W / 2, SS = 4, R = 6.4;
const TOP = 16, BOT = 76, HW0 = 14, HW1 = 8.5, DOT_Y = 116, DOT_R = 11.5;
const inside = (x, y) => {
  if (y >= TOP && y <= BOT) { const hw = HW0 + (HW1 - HW0) * (y - TOP) / (BOT - TOP); if (Math.abs(x - CX) <= hw) return true; }
  if (Math.hypot(x - CX, y - TOP) <= HW0 && y < TOP) return true;                 // topo arredondado
  if (Math.hypot(x - CX, y - BOT) <= HW1 && y > BOT) return true;                 // base arredondada
  return Math.hypot(x - CX, y - DOT_Y) <= DOT_R;
};
const cov = new Float32Array(W * H);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) { let n = 0; for (let j = 0; j < SS; j++) for (let i = 0; i < SS; i++) if (inside(x + (i + .5) / SS, y + (j + .5) / SS)) n++; cov[y * W + x] = n / (SS * SS); }
function make(name, hi, lo) {
  const out = I.create(W, H), rim = [38, 22, 4], span = Math.ceil(R) + 1;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    let dmin = 99;
    for (let dy = -span; dy <= span; dy++) for (let dx = -span; dx <= span; dx++) { const xx = x + dx, yy = y + dy; if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue; if (cov[yy * W + xx] >= 0.5) dmin = Math.min(dmin, Math.hypot(dx, dy)); }
    const sa = cov[y * W + x], ba = Math.max(0, Math.min(1, R + 0.5 - dmin)), a = Math.max(sa, ba), t = y / H;
    const f = [0, 1, 2].map((k) => hi[k] + (lo[k] - hi[k]) * Math.min(1, t * 1.1));     // leve degradê vertical
    const o = (y * W + x) * 4;
    for (let k = 0; k < 3; k++) out.px[o + k] = rim[k] + (f[k] - rim[k]) * sa;
    out.px[o + 3] = Math.round(a * 255);
  }
  for (const d of ["D:/ProjectAzaath/AzaathUI/Media/MapFrame", "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame"]) I.writeTGA(d + "/" + name + ".tga", out);
  I.writePNG(path.join(__dirname, "out", "icons", name + ".png"), out);
}
make("PinNewV3", [255, 226, 60], [255, 200, 14]);
make("PinRepeatV3", [110, 200, 255], [50, 160, 250]);
