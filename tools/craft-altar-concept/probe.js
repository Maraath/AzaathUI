// Prévia com grade para medir a arte: node probe.js [x y w h escala]
"use strict";
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");
const C = readPNG(path.join(__dirname, "concept.png"));
const [x = 0, y = 0, w = C.w, h = C.h, s = 0.5] = process.argv.slice(2).map(Number);
const out = I.resize(I.crop(C, x, y, w, h), Math.round(w * s), Math.round(h * s));
const step = w > 600 ? 100 : 20;
for (let j = 0; j < out.h; j++) for (let i = 0; i < out.w; i++) {
  const ax = x + i / s, ay = y + j / s;
  const onX = Math.abs(ax / step - Math.round(ax / step)) * step < 0.5 / s;
  const onY = Math.abs(ay / step - Math.round(ay / step)) * step < 0.5 / s;
  if (onX || onY) {
    const d = (j * out.w + i) * 4, major = (onX && Math.round(ax / step) % 5 === 0) || (onY && Math.round(ay / step) % 5 === 0);
    out.px[d] = major ? 255 : 255; out.px[d + 1] = major ? 40 : 200; out.px[d + 2] = major ? 40 : 0; out.px[d + 3] = 255;
  }
}
I.writePNG(path.join(__dirname, "out", "probe.png"), out);
