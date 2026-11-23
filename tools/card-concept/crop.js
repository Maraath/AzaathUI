const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");
const [x0, y0, x1, y1, s, out] = process.argv.slice(2);
const src = readPNG(process.env.SRC);
const X0 = +x0, Y0 = +y0, W = +x1 - X0, H = +y1 - Y0, S = +s;
const im = I.create(W * S, H * S, 0, 0, 0, 255);
for (let y = 0; y < H * S; y++) for (let x = 0; x < W * S; x++) {
  const sx = X0 + Math.floor(x / S), sy = Y0 + Math.floor(y / S), o = (y * im.w + x) * 4, q = (sy * src.w + sx) * 4;
  for (let k = 0; k < 4; k++) im.px[o + k] = src.px[q + k];
  im.px[o+3]=255;
  const fx = X0 + x / S, fy = Y0 + y / S;
  const big = (fx % 10 < 1 / S) || (fy % 10 < 1 / S), hund = (fx % 50 < 1 / S) || (fy % 50 < 1 / S);
  if (hund) { im.px[o] = 0; im.px[o + 1] = 255; im.px[o + 2] = 0; }
  else if (big && S>=3) { im.px[o] = im.px[o]*0.6+100; im.px[o + 1] *=0.6; im.px[o + 2] = im.px[o+2]*0.6+100; }
}
I.writePNG(out, im);
