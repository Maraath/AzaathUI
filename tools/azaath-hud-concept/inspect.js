const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const src = readPNG(path.join(__dirname, "concept.png"));
const out = { w: src.w, h: src.h, px: Float32Array.from(src.px) };

function put(x, y, r, g, b, a = 1) {
  if (x < 0 || y < 0 || x >= out.w || y >= out.h) return;
  const o = (y * out.w + x) * 4;
  out.px[o] = out.px[o] * (1 - a) + r * a;
  out.px[o + 1] = out.px[o + 1] * (1 - a) + g * a;
  out.px[o + 2] = out.px[o + 2] * (1 - a) + b * a;
}

// Draw grid lines every 50px (bright cyan/yellow) and every 10px (faint)
for (let x = 0; x < out.w; x += 10) {
  const major = x % 50 === 0;
  const cent = x % 100 === 0;
  for (let y = 0; y < out.h; y++) {
    if (cent) put(x, y, 255, 220, 60, 0.45);
    else if (major) put(x, y, 60, 220, 255, 0.25);
    else if (y % 5 === 0) put(x, y, 255, 255, 255, 0.12);
  }
}
for (let y = 0; y < out.h; y += 10) {
  const major = y % 50 === 0;
  const cent = y % 100 === 0;
  for (let x = 0; x < out.w; x++) {
    if (cent) put(x, y, 255, 220, 60, 0.45);
    else if (major) put(x, y, 60, 220, 255, 0.25);
    else if (x % 5 === 0) put(x, y, 255, 255, 255, 0.12);
  }
}

fs.mkdirSync(path.join(__dirname, "preview"), { recursive: true });
I.writePNG(path.join(__dirname, "preview", "grid.png"), out);
console.log("Wrote preview/grid.png", out.w, "x", out.h);
