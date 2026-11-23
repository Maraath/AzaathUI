// Ferramenta de inspeção: recorta uma região da arte e amplia com grade de coordenadas.
// node crop.js x0 y0 x1 y1 escala saida.png
const I = require("../sheet-concept/img");
const { readPNG } = require("./png");
const [x0, y0, x1, y1, s, out] = process.argv.slice(2);
const src = readPNG(__dirname + "/concept.png");
const X0 = +x0, Y0 = +y0, W = +x1 - X0, H = +y1 - Y0, S = +s;
const im = I.create(W * S, H * S, 0, 0, 0, 255);
for (let y = 0; y < H * S; y++) for (let x = 0; x < W * S; x++) {
  const sx = X0 + Math.floor(x / S), sy = Y0 + Math.floor(y / S), o = (y * im.w + x) * 4, q = (sy * src.w + sx) * 4;
  for (let k = 0; k < 4; k++) im.px[o + k] = src.px[q + k];
  const fx = X0 + x / S, fy = Y0 + y / S;
  const big = (fx % 50 < 1 / S) || (fy % 50 < 1 / S), hund = (fx % 100 < 1 / S) || (fy % 100 < 1 / S);
  if (hund) { im.px[o] = 0; im.px[o + 1] = 255; im.px[o + 2] = 0; }
  else if (big) { im.px[o] = 255; im.px[o + 1] = 0; im.px[o + 2] = 255; }
}
I.writePNG(out, im);
console.log("src", src.w + "x" + src.h);
