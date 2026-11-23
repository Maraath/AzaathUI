// Codec de imagens para o gerador do mapa Azaath (sem dependências externas).
// Lê BLP2 (DXT1/3/5, paleta, BGRA cru) e TGA (cru ou RLE, 24/32 bits);
// grava BLP2 com compressão DXT1/DXT5 e mipmaps, TGA 32 bits e PNG (pré-visualização).
// As imagens em memória são { w, h, data: Uint8ClampedArray RGBA, origem no topo }.
"use strict";
const fs = require("fs");
const zlib = require("zlib");

function makeImage(w, h) {
  return { w, h, data: new Uint8ClampedArray(w * h * 4) };
}

// ---------------------------------------------------------------- DXT decode
function rgb565(c) {
  const r = (c >> 11) & 31, g = (c >> 5) & 63, b = c & 31;
  return [(r << 3) | (r >> 2), (g << 2) | (g >> 4), (b << 3) | (b >> 2)];
}

function decodeColorBlock(buf, off, out, w, bx, by, dxt1, alphas) {
  const c0 = buf.readUInt16LE(off), c1 = buf.readUInt16LE(off + 2);
  const p0 = rgb565(c0), p1 = rgb565(c1);
  const pal = [p0, p1];
  let transparent3 = false;
  if (c0 > c1 || !dxt1) {
    pal.push([(2 * p0[0] + p1[0]) / 3, (2 * p0[1] + p1[1]) / 3, (2 * p0[2] + p1[2]) / 3]);
    pal.push([(p0[0] + 2 * p1[0]) / 3, (p0[1] + 2 * p1[1]) / 3, (p0[2] + 2 * p1[2]) / 3]);
  } else {
    pal.push([(p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2]);
    pal.push([0, 0, 0]);
    transparent3 = true;
  }
  const bits = buf.readUInt32LE(off + 4);
  for (let py = 0; py < 4; py++) {
    for (let px = 0; px < 4; px++) {
      const x = bx + px, y = by + py;
      if (x >= w || y >= out.h) continue;
      const k = (bits >> (2 * (py * 4 + px))) & 3;
      const i = (y * w + x) * 4;
      const p = pal[k];
      out.data[i] = p[0]; out.data[i + 1] = p[1]; out.data[i + 2] = p[2];
      out.data[i + 3] = alphas ? alphas[py * 4 + px] : (transparent3 && k === 3 ? 0 : 255);
    }
  }
}

function decodeDXT(buf, off, w, h, kind) {
  const img = makeImage(w, h);
  const bw = Math.max(1, Math.ceil(w / 4)), bh = Math.max(1, Math.ceil(h / 4));
  const blockSize = kind === 1 ? 8 : 16;
  for (let by = 0; by < bh; by++) {
    for (let bx = 0; bx < bw; bx++) {
      const o = off + (by * bw + bx) * blockSize;
      let alphas = null;
      if (kind === 3) {
        alphas = new Array(16);
        for (let i = 0; i < 16; i++) {
          const byte = buf[o + (i >> 1)];
          const v = (i & 1) ? (byte >> 4) : (byte & 15);
          alphas[i] = v * 17;
        }
      } else if (kind === 5) {
        const a0 = buf[o], a1 = buf[o + 1];
        const ap = [a0, a1];
        if (a0 > a1) for (let i = 1; i <= 6; i++) ap.push(((7 - i) * a0 + i * a1) / 7);
        else { for (let i = 1; i <= 4; i++) ap.push(((5 - i) * a0 + i * a1) / 5); ap.push(0, 255); }
        // 48 bits de índices (3 bits cada)
        let lo = buf.readUInt32LE(o + 2), hi = buf.readUInt16LE(o + 6);
        alphas = new Array(16);
        for (let i = 0; i < 16; i++) {
          const bit = i * 3;
          let v;
          if (bit + 3 <= 32) v = (lo >>> bit) & 7;
          else if (bit >= 32) v = (hi >>> (bit - 32)) & 7;
          else v = ((lo >>> bit) | (hi << (32 - bit))) & 7;
          alphas[i] = ap[v];
        }
      }
      decodeColorBlock(buf, kind === 1 ? o : o + 8, img, w, bx * 4, by * 4, kind === 1, alphas);
    }
  }
  return img;
}

// ---------------------------------------------------------------- BLP read
function readBLP(file) {
  const buf = fs.readFileSync(file);
  if (buf.toString("ascii", 0, 4) !== "BLP2") throw new Error("não é BLP2: " + file);
  const compression = buf[8], alphaDepth = buf[9], alphaType = buf[10];
  const w = buf.readUInt32LE(12), h = buf.readUInt32LE(16);
  const off = buf.readUInt32LE(20);
  if (compression === 2) {
    const kind = alphaType === 7 ? 5 : (alphaType === 1 ? 3 : (alphaDepth === 0 || alphaDepth === 1 ? 1 : 3));
    return decodeDXT(buf, off, w, h, kind);
  }
  if (compression === 1) {
    const pal = 148;
    const img = makeImage(w, h);
    const n = w * h;
    for (let i = 0; i < n; i++) {
      const k = buf[off + i];
      img.data[i * 4] = buf[pal + k * 4 + 2];
      img.data[i * 4 + 1] = buf[pal + k * 4 + 1];
      img.data[i * 4 + 2] = buf[pal + k * 4];
      let a = 255;
      if (alphaDepth === 8) a = buf[off + n + i];
      else if (alphaDepth === 1) a = (buf[off + n + (i >> 3)] >> (i & 7)) & 1 ? 255 : 0;
      else if (alphaDepth === 4) a = ((buf[off + n + (i >> 1)] >> ((i & 1) * 4)) & 15) * 17;
      img.data[i * 4 + 3] = a;
    }
    return img;
  }
  if (compression === 3) {
    const img = makeImage(w, h);
    for (let i = 0; i < w * h; i++) {
      img.data[i * 4] = buf[off + i * 4 + 2];
      img.data[i * 4 + 1] = buf[off + i * 4 + 1];
      img.data[i * 4 + 2] = buf[off + i * 4];
      img.data[i * 4 + 3] = buf[off + i * 4 + 3];
    }
    return img;
  }
  throw new Error("compressão BLP desconhecida " + compression + ": " + file);
}

// ---------------------------------------------------------------- TGA read/write
function readTGA(file) {
  const buf = fs.readFileSync(file);
  const idLen = buf[0], type = buf[2];
  const w = buf.readUInt16LE(12), h = buf.readUInt16LE(14);
  const bpp = buf[16], desc = buf[17];
  const topOrigin = (desc & 0x20) !== 0;
  const bytes = bpp / 8;
  let p = 18 + idLen + (buf[1] ? buf.readUInt16LE(5) * Math.ceil(buf[7] / 8) : 0);
  const n = w * h;
  const raw = Buffer.alloc(n * bytes);
  if (type === 2 || type === 3) {
    buf.copy(raw, 0, p, p + n * bytes);
  } else if (type === 10 || type === 11) {
    let o = 0;
    while (o < raw.length) {
      const hdr = buf[p++];
      const count = (hdr & 0x7f) + 1;
      if (hdr & 0x80) {
        for (let i = 0; i < count; i++) { buf.copy(raw, o, p, p + bytes); o += bytes; }
        p += bytes;
      } else {
        buf.copy(raw, o, p, p + count * bytes); o += count * bytes; p += count * bytes;
      }
    }
  } else throw new Error("TGA tipo " + type + " não suportado: " + file);
  const img = makeImage(w, h);
  for (let y = 0; y < h; y++) {
    const sy = topOrigin ? y : h - 1 - y;
    for (let x = 0; x < w; x++) {
      const s = (sy * w + x) * bytes, d = (y * w + x) * 4;
      if (bytes === 1) {
        img.data[d] = img.data[d + 1] = img.data[d + 2] = raw[s]; img.data[d + 3] = 255;
      } else {
        img.data[d] = raw[s + 2]; img.data[d + 1] = raw[s + 1]; img.data[d + 2] = raw[s];
        img.data[d + 3] = bytes === 4 ? raw[s + 3] : 255;
      }
    }
  }
  return img;
}

function writeTGA(file, img, withAlpha = true) {
  const bytes = withAlpha ? 4 : 3;
  const header = Buffer.alloc(18);
  header[2] = 2;
  header.writeUInt16LE(img.w, 12);
  header.writeUInt16LE(img.h, 14);
  header[16] = bytes * 8;
  header[17] = withAlpha ? 8 : 0;           // origem inferior esquerda
  const data = Buffer.alloc(img.w * img.h * bytes);
  for (let y = 0; y < img.h; y++) {
    const sy = img.h - 1 - y;
    for (let x = 0; x < img.w; x++) {
      const s = (y * img.w + x) * 4, d = (sy * img.w + x) * bytes;
      data[d] = img.data[s + 2]; data[d + 1] = img.data[s + 1]; data[d + 2] = img.data[s];
      if (withAlpha) data[d + 3] = img.data[s + 3];
    }
  }
  fs.writeFileSync(file, Buffer.concat([header, data]));
}

function readImage(file) {
  return /\.blp$/i.test(file) ? readBLP(file) : readTGA(file);
}

// ---------------------------------------------------------------- DXT encode
function to565(r, g, b) {
  return ((Math.round(r * 31 / 255) & 31) << 11) | ((Math.round(g * 63 / 255) & 63) << 5) | (Math.round(b * 31 / 255) & 31);
}

// bloco de cor 4x4 (DXT1 opaco / parte de cor do DXT5): extremos pelo eixo principal
function encodeColorBlock(px, out, o) {
  // média e eixo principal (iteração de potência sobre a covariância)
  let mr = 0, mg = 0, mb = 0;
  for (let i = 0; i < 16; i++) { mr += px[i * 4]; mg += px[i * 4 + 1]; mb += px[i * 4 + 2]; }
  mr /= 16; mg /= 16; mb /= 16;
  let crr = 0, crg = 0, crb = 0, cgg = 0, cgb = 0, cbb = 0;
  for (let i = 0; i < 16; i++) {
    const r = px[i * 4] - mr, g = px[i * 4 + 1] - mg, b = px[i * 4 + 2] - mb;
    crr += r * r; crg += r * g; crb += r * b; cgg += g * g; cgb += g * b; cbb += b * b;
  }
  let vr = 1, vg = 1, vb = 1;
  for (let k = 0; k < 6; k++) {
    const nr = crr * vr + crg * vg + crb * vb;
    const ng = crg * vr + cgg * vg + cgb * vb;
    const nb = crb * vr + cgb * vg + cbb * vb;
    const len = Math.sqrt(nr * nr + ng * ng + nb * nb);
    if (len < 1e-6) { vr = 0.577; vg = 0.577; vb = 0.577; break; }
    vr = nr / len; vg = ng / len; vb = nb / len;
  }
  let minT = Infinity, maxT = -Infinity;
  for (let i = 0; i < 16; i++) {
    const t = (px[i * 4] - mr) * vr + (px[i * 4 + 1] - mg) * vg + (px[i * 4 + 2] - mb) * vb;
    if (t < minT) minT = t;
    if (t > maxT) maxT = t;
  }
  // recuo leve das pontas (reduz erro médio)
  const inset = (maxT - minT) / 16;
  minT += inset; maxT -= inset;
  const clamp = (v) => Math.max(0, Math.min(255, v));
  let c0 = to565(clamp(mr + vr * maxT), clamp(mg + vg * maxT), clamp(mb + vb * maxT));
  let c1 = to565(clamp(mr + vr * minT), clamp(mg + vg * minT), clamp(mb + vb * minT));
  if (c0 < c1) { const t = c0; c0 = c1; c1 = t; }
  let bits = 0;
  if (c0 === c1) {
    bits = 0;
  } else {
    const p0 = rgb565(c0), p1 = rgb565(c1);
    const pal = [p0, p1,
      [(2 * p0[0] + p1[0]) / 3, (2 * p0[1] + p1[1]) / 3, (2 * p0[2] + p1[2]) / 3],
      [(p0[0] + 2 * p1[0]) / 3, (p0[1] + 2 * p1[1]) / 3, (p0[2] + 2 * p1[2]) / 3]];
    for (let i = 0; i < 16; i++) {
      let best = 0, bd = Infinity;
      for (let k = 0; k < 4; k++) {
        const dr = px[i * 4] - pal[k][0], dg = px[i * 4 + 1] - pal[k][1], db = px[i * 4 + 2] - pal[k][2];
        const d = dr * dr * 0.3 + dg * dg * 0.59 + db * db * 0.11;
        if (d < bd) { bd = d; best = k; }
      }
      bits |= best << (2 * i);
    }
  }
  out.writeUInt16LE(c0, o);
  out.writeUInt16LE(c1, o + 2);
  out.writeUInt32LE(bits >>> 0, o + 4);
}

function encodeAlphaBlock(px, out, o) {
  let a0 = 0, a1 = 255;
  for (let i = 0; i < 16; i++) { const a = px[i * 4 + 3]; if (a > a0) a0 = a; if (a < a1) a1 = a; }
  out[o] = a0; out[o + 1] = a1;
  const ap = [a0, a1];
  for (let i = 1; i <= 6; i++) ap.push(((7 - i) * a0 + i * a1) / 7);
  let lo = 0, hi = 0;
  for (let i = 0; i < 16; i++) {
    let best = 0;
    if (a0 !== a1) {
      let bd = Infinity;
      for (let k = 0; k < 8; k++) { const d = Math.abs(px[i * 4 + 3] - ap[k]); if (d < bd) { bd = d; best = k; } }
    }
    const bit = i * 3;
    if (bit + 3 <= 32) lo |= best << bit;
    else if (bit >= 32) hi |= best << (bit - 32);
    else { lo |= best << bit; hi |= best >>> (32 - bit); }
  }
  out.writeUInt32LE(lo >>> 0, o + 2);
  out.writeUInt16LE(hi & 0xffff, o + 6);
}

function encodeDXT(img, alpha) {
  const bw = Math.max(1, Math.ceil(img.w / 4)), bh = Math.max(1, Math.ceil(img.h / 4));
  const bs = alpha ? 16 : 8;
  const out = Buffer.alloc(bw * bh * bs);
  const px = new Float32Array(64);
  for (let by = 0; by < bh; by++) {
    for (let bx = 0; bx < bw; bx++) {
      for (let py = 0; py < 4; py++) {
        for (let pxx = 0; pxx < 4; pxx++) {
          const x = Math.min(img.w - 1, bx * 4 + pxx), y = Math.min(img.h - 1, by * 4 + py);
          const s = (y * img.w + x) * 4, d = (py * 4 + pxx) * 4;
          px[d] = img.data[s]; px[d + 1] = img.data[s + 1]; px[d + 2] = img.data[s + 2]; px[d + 3] = img.data[s + 3];
        }
      }
      const o = (by * bw + bx) * bs;
      if (alpha) { encodeAlphaBlock(px, out, o); encodeColorBlock(px, out, o + 8); }
      else encodeColorBlock(px, out, o);
    }
  }
  return out;
}

// metade do tamanho (média 2x2, com cor ponderada pelo alpha)
function halve(img) {
  const w = Math.max(1, img.w >> 1), h = Math.max(1, img.h >> 1);
  const o = makeImage(w, h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let r = 0, g = 0, b = 0, a = 0, n = 0;
      for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 2; dx++) {
        const sx = Math.min(img.w - 1, x * 2 + dx), sy = Math.min(img.h - 1, y * 2 + dy);
        const s = (sy * img.w + sx) * 4;
        const wa = img.data[s + 3] + 1;
        r += img.data[s] * wa; g += img.data[s + 1] * wa; b += img.data[s + 2] * wa; a += img.data[s + 3]; n += wa;
      }
      const d = (y * w + x) * 4;
      o.data[d] = r / n; o.data[d + 1] = g / n; o.data[d + 2] = b / n; o.data[d + 3] = a / 4;
    }
  }
  return o;
}

function hasAlpha(img) {
  for (let i = 3; i < img.data.length; i += 4) if (img.data[i] < 250) return true;
  return false;
}

// BLP2 com DXT1 (opaco) ou DXT5 (com alpha), mipmaps até 1x1
function writeBLP(file, img, opts = {}) {
  const alpha = opts.alpha !== undefined ? opts.alpha : hasAlpha(img);
  const mips = [];
  let cur = img;
  for (let i = 0; i < 16; i++) {
    mips.push(encodeDXT(cur, alpha));
    if (cur.w === 1 && cur.h === 1) break;
    if (opts.mips === false) break;
    cur = halve(cur);
  }
  const header = Buffer.alloc(148 + 1024);
  header.write("BLP2", 0, "ascii");
  header.writeUInt32LE(1, 4);
  header[8] = 2;                       // DXT
  header[9] = alpha ? 8 : 0;           // profundidade do alpha
  header[10] = alpha ? 7 : 0;          // 7 = DXT5
  header[11] = mips.length > 1 ? 1 : 0;
  header.writeUInt32LE(img.w, 12);
  header.writeUInt32LE(img.h, 16);
  let off = header.length;
  for (let i = 0; i < mips.length; i++) {
    header.writeUInt32LE(off, 20 + i * 4);
    header.writeUInt32LE(mips[i].length, 84 + i * 4);
    off += mips[i].length;
  }
  fs.writeFileSync(file, Buffer.concat([header, ...mips]));
}

// ---------------------------------------------------------------- PNG (pré-visualização)
const CRC_TABLE = (() => {
  const t = new Int32Array(256);
  for (let n = 0; n < 256; n++) { let c = n; for (let k = 0; k < 8; k++) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1; t[n] = c; }
  return t;
})();
function crc32(buf) {
  let c = -1;
  for (let i = 0; i < buf.length; i++) c = CRC_TABLE[(c ^ buf[i]) & 255] ^ (c >>> 8);
  return (c ^ -1) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type, "ascii"), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function writePNG(file, img) {
  const raw = Buffer.alloc((img.w * 4 + 1) * img.h);
  for (let y = 0; y < img.h; y++) {
    raw[y * (img.w * 4 + 1)] = 0;
    for (let x = 0; x < img.w * 4; x++) raw[y * (img.w * 4 + 1) + 1 + x] = img.data[y * img.w * 4 + x];
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.w, 0); ihdr.writeUInt32BE(img.h, 4);
  ihdr[8] = 8; ihdr[9] = 6;
  fs.writeFileSync(file, Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw, { level: 6 })), chunk("IEND", Buffer.alloc(0)),
  ]));
}

module.exports = { makeImage, readBLP, readTGA, readImage, writeTGA, writeBLP, writePNG, halve, hasAlpha };
