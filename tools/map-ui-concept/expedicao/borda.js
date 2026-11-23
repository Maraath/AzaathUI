// Borda de pedra nos 4 ícones de missão do mapa: ExpPinQuest/TurnIn/New/Repeat -> ...S (nome novo por causa do cache de textura)
//   node borda.js
"use strict";
const fs = require("fs"), path = require("path");
const I = require("../../sheet-concept/img");
const { readPNG } = require("../../grimoire-concept/png");
const DIR = __dirname, PREV = path.join(DIR, "out", "icons");
const OUT_DIRS = ["D:/ProjectAzaath/AzaathUI/Media/MapFrame",
  "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame"];
const R = 12, PAD = R + 2;
const LIGHT = [168, 160, 146], MID = [118, 112, 102], DARK = [58, 54, 50];
const DISPLAY = { ExpPinQuest: [23, 34], ExpPinTurnIn: [19, 28], ExpPinNew: [10, 30], ExpPinRepeat: [10, 30] };
const offs = []; for (let dy = -R - 1; dy <= R + 1; dy++) for (let dx = -R - 1; dx <= R + 1; dx++) { const d = Math.hypot(dx, dy); if (d <= R + 1) offs.push([dx, dy, d]); }
for (const name of Object.keys(DISPLAY)) {
  const src = readPNG(path.join(PREV, name + ".png"));
  const w = src.w + PAD * 2, h = src.h + PAD * 2, out = I.create(w, h);
  const A = (x, y) => (x < 0 || y < 0 || x >= src.w || y >= src.h) ? 0 : src.px[(y * src.w + x) * 4 + 3] / 255;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const sx = x - PAD, sy = y - PAD;
    let dmin = 99;
    for (const [dx, dy, d] of offs) if (A(sx + dx, sy + dy) >= 0.5 && d < dmin) dmin = d;
    const o = (y * w + x) * 4;
    let ba = Math.max(0, Math.min(1, R + 0.5 - dmin));
    // gradiente de pedra: claro junto ao ícone, escuro na borda externa
    const t = Math.min(1, dmin / R);
    const col = t < 0.5 ? LIGHT.map((c, k) => c + (MID[k] - c) * (t / 0.5)) : MID.map((c, k) => c + (DARK[k] - c) * ((t - 0.5) / 0.5));
    const sa = A(sx, sy), i2 = (Math.max(0, Math.min(src.h - 1, sy)) * src.w + Math.max(0, Math.min(src.w - 1, sx))) * 4;
    const a = sa + ba * (1 - sa);
    for (let k = 0; k < 3; k++) out.px[o + k] = a > 0 ? (src.px[i2 + k] * sa + col[k] * ba * (1 - sa)) / a : 0;
    out.px[o + 3] = Math.round(a * 255);
  }
  for (const d of OUT_DIRS) I.writeTGA(path.join(d, name + "G.tga"), out);
  I.writePNG(path.join(PREV, name + "G.png"), out);
  const [dw, dh] = DISPLAY[name], s = dh / src.h;
  console.log(name, "size", +(w * s).toFixed(1), +(h * s).toFixed(1), "lift", +((h / 2 - PAD) * s).toFixed(1));
}
