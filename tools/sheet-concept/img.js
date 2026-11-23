// Utilitários mínimos de imagem (sem dependências): BMP 32 bits -> RGBA,
// recorte, redimensionamento por área, PNG (pré-visualização) e TGA (jogo).
const fs = require("fs");
const zlib = require("zlib");

function readBMP(file) {
  const b = fs.readFileSync(file);
  const off = b.readUInt32LE(10);
  const w = b.readInt32LE(18);
  let h = b.readInt32LE(22);
  const bpp = b.readUInt16LE(28);
  const topDown = h < 0; h = Math.abs(h);
  const stride = Math.ceil((w * bpp) / 32) * 4;
  const px = new Float32Array(w * h * 4);
  for (let y = 0; y < h; y++) {
    const sy = topDown ? y : h - 1 - y;
    for (let x = 0; x < w; x++) {
      const i = off + sy * stride + x * (bpp / 8);
      const o = (y * w + x) * 4;
      px[o] = b[i + 2]; px[o + 1] = b[i + 1]; px[o + 2] = b[i]; px[o + 3] = 255;
    }
  }
  return { w, h, px };
}

function create(w, h, r = 0, g = 0, bl = 0, a = 0) {
  const px = new Float32Array(w * h * 4);
  for (let i = 0; i < w * h; i++) { px[i * 4] = r; px[i * 4 + 1] = g; px[i * 4 + 2] = bl; px[i * 4 + 3] = a; }
  return { w, h, px };
}

function crop(img, x, y, w, h) {
  const out = create(w, h);
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const sx = Math.min(img.w - 1, Math.max(0, x + i)), sy = Math.min(img.h - 1, Math.max(0, y + j));
    const s = (sy * img.w + sx) * 4, d = (j * w + i) * 4;
    for (let k = 0; k < 4; k++) out.px[d + k] = img.px[s + k];
  }
  return out;
}

// Redimensiona com amostragem bilinear (supersample 4x4 para reduzir)
function resize(img, w, h) {
  const out = create(w, h);
  const ss = 4;
  const sample = (fx, fy, k) => {
    fx = Math.min(img.w - 1, Math.max(0, fx)); fy = Math.min(img.h - 1, Math.max(0, fy));
    const x0 = Math.floor(fx), y0 = Math.floor(fy);
    const x1 = Math.min(img.w - 1, x0 + 1), y1 = Math.min(img.h - 1, y0 + 1);
    const tx = fx - x0, ty = fy - y0;
    const p = (x, y) => img.px[(y * img.w + x) * 4 + k];
    return (p(x0, y0) * (1 - tx) + p(x1, y0) * tx) * (1 - ty) + (p(x0, y1) * (1 - tx) + p(x1, y1) * tx) * ty;
  };
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    const d = (j * w + i) * 4;
    for (let k = 0; k < 4; k++) {
      let acc = 0;
      for (let sj = 0; sj < ss; sj++) for (let si = 0; si < ss; si++) {
        const fx = (i + (si + 0.5) / ss) * (img.w / w) - 0.5;
        const fy = (j + (sj + 0.5) / ss) * (img.h / h) - 0.5;
        acc += sample(fx, fy, k);
      }
      out.px[d + k] = acc / (ss * ss);
    }
  }
  return out;
}

function blit(dst, src, x, y) {
  for (let j = 0; j < src.h; j++) for (let i = 0; i < src.w; i++) {
    const dx = x + i, dy = y + j;
    if (dx < 0 || dy < 0 || dx >= dst.w || dy >= dst.h) continue;
    const s = (j * src.w + i) * 4, d = (dy * dst.w + dx) * 4;
    for (let k = 0; k < 4; k++) dst.px[d + k] = src.px[s + k];
  }
}

const crcTable = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c >>> 0; }
  return t;
})();
function crc32(buf) { let c = 0xffffffff; for (const v of buf) c = crcTable[(c ^ v) & 0xff] ^ (c >>> 8); return (c ^ 0xffffffff) >>> 0; }
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
const c8 = (v) => Math.max(0, Math.min(255, Math.round(v)));

function writePNG(file, img) {
  const raw = Buffer.alloc((img.w * 4 + 1) * img.h);
  for (let y = 0; y < img.h; y++) {
    raw[y * (img.w * 4 + 1)] = 0;
    for (let x = 0; x < img.w; x++) for (let k = 0; k < 4; k++)
      raw[y * (img.w * 4 + 1) + 1 + x * 4 + k] = c8(img.px[(y * img.w + x) * 4 + k]);
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.w, 0); ihdr.writeUInt32BE(img.h, 4); ihdr[8] = 8; ihdr[9] = 6;
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw, { level: 9 })), chunk("IEND", Buffer.alloc(0)),
  ]));
}

function writeTGA(file, img) {
  const header = Buffer.alloc(18);
  header[2] = 2; header.writeUInt16LE(img.w, 12); header.writeUInt16LE(img.h, 14);
  header[16] = 32; header[17] = 8; // origem inferior esquerda
  const data = Buffer.alloc(img.w * img.h * 4);
  for (let y = 0; y < img.h; y++) for (let x = 0; x < img.w; x++) {
    const s = ((img.h - 1 - y) * img.w + x) * 4, d = (y * img.w + x) * 4;
    data[d] = c8(img.px[s + 2]); data[d + 1] = c8(img.px[s + 1]); data[d + 2] = c8(img.px[s]); data[d + 3] = c8(img.px[s + 3]);
  }
  fs.writeFileSync(file, Buffer.concat([header, data]));
}

module.exports = { readBMP, create, crop, resize, blit, writePNG, writeTGA };
