// Leitor mínimo de PNG (8 bits, RGB/RGBA, sem entrelaçamento) -> { w, h, px: Float32Array RGBA }
// A arte vem em .webp; o Edge sem janela tira um "print" dela em PNG (ver gen.js).
const fs = require("fs");
const zlib = require("zlib");

function readPNG(file) {
  const b = fs.readFileSync(file);
  let p = 8, w = 0, h = 0, ct = 0;
  const idat = [];
  while (p < b.length) {
    const len = b.readUInt32BE(p), type = b.toString("latin1", p + 4, p + 8);
    const data = b.subarray(p + 8, p + 8 + len);
    if (type === "IHDR") { w = data.readUInt32BE(0); h = data.readUInt32BE(4); ct = data[9]; if (data[8] !== 8 || data[12]) throw new Error("PNG não suportado"); }
    else if (type === "IDAT") idat.push(data);
    else if (type === "IEND") break;
    p += 12 + len;
  }
  const bpp = ct === 6 ? 4 : ct === 2 ? 3 : 0;
  if (!bpp) throw new Error("tipo de cor não suportado: " + ct);
  const raw = zlib.inflateSync(Buffer.concat(idat));
  const stride = w * bpp, out = Buffer.alloc(h * stride);
  for (let y = 0; y < h; y++) {
    const f = raw[y * (stride + 1)], row = raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1));
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? out[y * stride + x - bpp] : 0, up = y ? out[(y - 1) * stride + x] : 0, c = (x >= bpp && y) ? out[(y - 1) * stride + x - bpp] : 0;
      let v = row[x];
      if (f === 1) v += a; else if (f === 2) v += up; else if (f === 3) v += (a + up) >> 1;
      else if (f === 4) { const pp = a + up - c, pa = Math.abs(pp - a), pb = Math.abs(pp - up), pc = Math.abs(pp - c); v += (pa <= pb && pa <= pc) ? a : pb <= pc ? up : c; }
      out[y * stride + x] = v & 255;
    }
  }
  const px = new Float32Array(w * h * 4);
  for (let i = 0; i < w * h; i++) {
    px[i * 4] = out[i * bpp]; px[i * 4 + 1] = out[i * bpp + 1]; px[i * 4 + 2] = out[i * bpp + 2]; px[i * 4 + 3] = bpp === 4 ? out[i * bpp + 3] : 255;
  }
  return { w, h, px };
}

module.exports = { readPNG };
