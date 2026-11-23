// node crop.js x0 y0 x1 y1 escala saida.png  (grade: magenta a cada 10px, verde a cada 50)
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");
const [x0, y0, x1, y1, s, out] = process.argv.slice(2);
const src = readPNG(__dirname + "/concept.png");
const X0 = +x0, Y0 = +y0, W = +x1 - X0, H = +y1 - Y0, S = +s;
const im = I.create(W * S, H * S, 0, 0, 0, 255);
for (let y = 0; y < H * S; y++) for (let x = 0; x < W * S; x++) {
  const sx = X0 + Math.floor(x / S), sy = Y0 + Math.floor(y / S), o = (y * im.w + x) * 4, q = (sy * src.w + sx) * 4;
  for (let k = 0; k < 4; k++) im.px[o + k] = src.px[q + k];
  const onx = x % S === 0, ony = y % S === 0;
  const g50 = (onx && sx % 50 === 0) || (ony && sy % 50 === 0), g10 = (onx && sx % 10 === 0) || (ony && sy % 10 === 0);
  if (g50) { im.px[o] = 0; im.px[o + 1] = 255; im.px[o + 2] = 0; }
  else if (g10 && S >= 3) { im.px[o] = 255; im.px[o + 1] = 0; im.px[o + 2] = 255; }
}
I.writePNG(out, im);
