// Gera as texturas originais do sistema de Nameplates do AzaathUI (PNG RGBA 8-bit).
// Todas as texturas são criadas proceduralmente para o projeto.
// Uso: node tools/media/generate-nameplate-media.js
"use strict";

const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Nameplates");
fs.mkdirSync(OUT, { recursive: true });

// --- Escritor mínimo de PNG RGBA ---
const crcTable = new Uint32Array(256);
for (let n = 0; n < 256; n++) {
  let c = n;
  for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
  crcTable[n] = c >>> 0;
}
function crc32(buf) {
  let c = 0xffffffff;
  for (let i = 0; i < buf.length; i++) c = crcTable[(c ^ buf[i]) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function chunk(type, data) {
  const len = Buffer.alloc(4);
  len.writeUInt32BE(data.length, 0);
  const ty = Buffer.from(type, "ascii");
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([ty, data])), 0);
  return Buffer.concat([len, ty, data, crc]);
}
function writePNG(name, w, h, fn) {
  const raw = Buffer.alloc((w * 4 + 1) * h);
  for (let y = 0; y < h; y++) {
    const row = y * (w * 4 + 1);
    raw[row] = 0; // filter None
    for (let x = 0; x < w; x++) {
      const [r, g, b, a] = fn(x, y, w, h);
      const i = row + 1 + x * 4;
      raw[i] = Math.max(0, Math.min(255, Math.round(r * 255)));
      raw[i + 1] = Math.max(0, Math.min(255, Math.round(g * 255)));
      raw[i + 2] = Math.max(0, Math.min(255, Math.round(b * 255)));
      raw[i + 3] = Math.max(0, Math.min(255, Math.round(a * 255)));
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0);
  ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; // bit depth
  ihdr[9] = 6; // RGBA
  const sig = Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]);
  const idat = zlib.deflateSync(raw, { level: 9 });
  fs.writeFileSync(path.join(OUT, name), Buffer.concat([sig, chunk("IHDR", ihdr), chunk("IDAT", idat), chunk("IEND", Buffer.alloc(0))]));
}

const clamp01 = (v) => (v < 0 ? 0 : v > 1 ? 1 : v);
const mix = (a, b, t) => a + (b - a) * t;
const smoothstep = (e0, e1, x) => {
  const t = clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
};
const hash = (x, y) => {
  const s = Math.sin(x * 127.1 + y * 311.7) * 43758.5453;
  return s - Math.floor(s);
};

// --- 1. Texturas de Barra (256x32, escala de cinza/branco para VertexColor) ---
function genBars() {
  const W = 256, H = 32;
  const bar = (name, fn) => writePNG(`bar-${name}.png`, W, H, (x, y) => {
    const u = x / (W - 1), v = y / (H - 1);
    const l = clamp01(fn(u, v, x, y));
    return [l, l, l, 1];
  });

  bar("smooth", (u, v) => 0.88 + 0.12 * Math.sin(v * Math.PI) - 0.08 * Math.pow(Math.abs(v - 0.5) * 2, 2));
  bar("gloss", (u, v) => v < 0.48 ? 1.0 - 0.12 * (v / 0.48) : 0.78 + 0.10 * ((v - 0.48) / 0.52));
  bar("crisp", (u, v) => {
    if (v < 0.12 || v > 0.88) return 0.72;
    return 0.94 + 0.06 * (1 - Math.abs(v - 0.5) * 2);
  });
  bar("brushed", (u, v, x, y) => 0.84 + 0.10 * Math.sin(v * Math.PI) + 0.08 * (hash(Math.floor(x / 6), y) - 0.5));
  bar("bevel", (u, v) => {
    const edge = Math.min(v, 1 - v);
    if (v < 0.18) return mix(0.75, 1.0, v / 0.18);
    if (v > 0.82) return mix(0.9, 0.62, (v - 0.82) / 0.18);
    return 0.92 + 0.05 * Math.sin(edge * Math.PI);
  });
  bar("glass", (u, v) => {
    const shine = Math.exp(-Math.pow((v - 0.25) / 0.16, 2)) * 0.22;
    return 0.76 + shine + (v > 0.75 ? 0.06 : 0);
  });
  bar("runic", (u, v, x, y) => {
    const base = 0.86 + 0.08 * Math.sin(v * Math.PI);
    const cell = (x % 32);
    const mark = (cell >= 12 && cell <= 18 && y >= 8 && y <= 23 && ((cell === 15) || (Math.abs(cell - 15) === Math.abs(y - 15)))) ? -0.18 : 0;
    return base + mark;
  });
  bar("arcane", (u, v) => {
    const wave = Math.sin(u * Math.PI * 10 + v * 3) * 0.06 + Math.cos(u * Math.PI * 4 - v * 5) * 0.05;
    return 0.88 + wave - 0.08 * Math.abs(v - 0.5);
  });
  bar("scales", (u, v, x, y) => {
    const sx = ((x + (Math.floor(y / 8) % 2) * 8) % 16) / 16 - 0.5;
    const sy = (y % 8) / 8 - 0.5;
    const d = Math.sqrt(sx * sx + sy * sy);
    return 0.94 - smoothstep(0.35, 0.62, d) * 0.2;
  });
  bar("silk", (u, v) => 0.84 + 0.14 * Math.sin(v * Math.PI) + 0.03 * Math.sin(u * Math.PI * 6));
  bar("stone", (u, v, x, y) => 0.84 + 0.12 * (hash(Math.floor(x / 3), Math.floor(y / 3)) - 0.5) - 0.08 * Math.abs(v - 0.5));
  bar("frost", (u, v, x, y) => {
    const crystal = Math.abs(Math.sin((u * 12 + v * 2) * Math.PI)) * 0.08;
    return 0.85 + crystal + (v < 0.35 ? 0.08 : 0);
  });
  bar("ridge", (u, v) => 0.82 + 0.18 * (1 - Math.abs(v - 0.5) * 2));
  bar("lines", (u, v, x, y) => 0.90 - ((y % 4 === 0) ? 0.16 : 0));
  bar("gilded", (u, v) => {
    if (v < 0.10 || v > 0.90) return 0.98;
    if (v < 0.18 || v > 0.82) return 0.68;
    return 0.88 + 0.08 * Math.sin(v * Math.PI);
  });
  bar("aurora", (u, v) => 0.84 + 0.12 * Math.sin(u * Math.PI * 3 + v * 2) + 0.06 * Math.sin(v * Math.PI));
  bar("embers", (u, v, x, y) => {
    const sp = hash(Math.floor(x / 4), Math.floor(y / 4)) > 0.86 ? 0.16 : 0;
    return 0.82 + 0.08 * (1 - v) + sp;
  });
  bar("plate", (u, v) => 0.92 - 0.18 * Math.pow(Math.abs(v - 0.5) * 2, 3));
}

// --- 2. Cantos arredondados (masks e rings para 9-slice) ---
function genRoundedCorners() {
  const TEXELS = 2;
  for (const r of [3, 5, 8]) {
    const R = r * TEXELS;
    const S = R * 2 + 8;
    const mid = S / 2;
    const distBox = (x, y, half) => {
      const px = Math.abs(x + 0.5 - mid) - (half - R);
      const py = Math.abs(y + 0.5 - mid) - (half - R);
      const ox = Math.max(px, 0), oy = Math.max(py, 0);
      return Math.sqrt(ox * ox + oy * oy) + Math.min(Math.max(px, py), 0) - R;
    };
    writePNG(`round-mask-${r}.png`, S, S, (x, y) => {
      const d = distBox(x, y, mid);
      const a = clamp01(0.5 - d);
      return [1, 1, 1, a];
    });
    for (let t2 = 1; t2 <= 12; t2++) {
      const th = t2; // em texels (TEXELS=2 -> t2/2 px em escala 1)
      const S2 = (R + th) * 2 + 8;
      const m2 = S2 / 2;
      writePNG(`round-ring-${r}-${t2}.png`, S2, S2, (x, y) => {
        const px = Math.abs(x + 0.5 - m2) - (m2 - (R + th));
        const py = Math.abs(y + 0.5 - m2) - (m2 - (R + th));
        const ox = Math.max(px, 0), oy = Math.max(py, 0);
        const outer = Math.sqrt(ox * ox + oy * oy) + Math.min(Math.max(px, py), 0) - (R + th);
        const inner = outer + th;
        const a = clamp01(0.5 - outer) * clamp01(0.5 + inner);
        return [1, 1, 1, a];
      });
    }
  }
}

// --- 3. Formatos da Caixa de Nível ---
function genBoxes() {
  const S = 64, C = S / 2;
  writePNG("box-rounded.png", S, S, (x, y) => {
    const R = 14;
    const px = Math.abs(x + 0.5 - C) - (C - 2 - R);
    const py = Math.abs(y + 0.5 - C) - (C - 2 - R);
    const d = Math.sqrt(Math.max(px, 0) ** 2 + Math.max(py, 0) ** 2) + Math.min(Math.max(px, py), 0) - R;
    return [1, 1, 1, clamp01(0.5 - d)];
  });
  writePNG("box-bevel.png", S, S, (x, y) => {
    const ax = Math.abs(x + 0.5 - C), ay = Math.abs(y + 0.5 - C);
    const d = Math.max(ax - (C - 2), ay - (C - 2), (ax + ay) - (S - 18));
    return [1, 1, 1, clamp01(0.5 - d)];
  });
  writePNG("box-hex.png", S, S, (x, y) => {
    const ax = Math.abs(x + 0.5 - C), ay = Math.abs(y + 0.5 - C);
    const r = C - 3;
    const d = Math.max(ay - r * 0.866, ax * 0.866 + ay * 0.5 - r * 0.866);
    return [1, 1, 1, clamp01(0.5 - d)];
  });
  writePNG("box-circle.png", S, S, (x, y) => {
    const d = Math.hypot(x + 0.5 - C, y + 0.5 - C) - (C - 2);
    return [1, 1, 1, clamp01(0.5 - d)];
  });
}

// --- 4. Efeitos: Glow, Halo, Spark, Formigas Marchando, Moldura Clássica ---
function genEffects() {
  // glow.png (64x64 9-slice, centro opaco com queda suave para as bordas)
  writePNG("glow.png", 64, 64, (x, y) => {
    const dx = Math.abs(x + 0.5 - 32) / 32;
    const dy = Math.abs(y + 0.5 - 32) / 32;
    const d = Math.hypot(Math.max(0, dx), Math.max(0, dy));
    const a = Math.pow(clamp01(1 - d), 1.8);
    return [1, 1, 1, a];
  });
  // glow-round.png (128x128 radial halo)
  writePNG("glow-round.png", 128, 128, (x, y) => {
    const d = Math.hypot(x + 0.5 - 64, y + 0.5 - 64) / 64;
    const a = Math.pow(clamp01(1 - d), 2.2);
    return [1, 1, 1, a];
  });
  // spark.png (32x64 brilho vertical de cast)
  writePNG("spark.png", 32, 64, (x, y) => {
    const nx = (x + 0.5 - 16) / 16;
    const ny = (y + 0.5 - 32) / 32;
    const core = Math.exp(-nx * nx * 8) * Math.exp(-ny * ny * 3);
    const center = Math.exp(-nx * nx * 24) * clamp01(1 - Math.abs(ny));
    return [1, 1, 1, clamp01(core * 0.8 + center * 0.6)];
  });
  // ants-h{20..80} e ants-v{20..80}
  for (let ratio = 20; ratio <= 80; ratio += 10) {
    const W = 64, H = 8;
    const cut = Math.round((ratio / 100) * W);
    writePNG(`ants-h${ratio}.png`, W, H, (x, y) => {
      const a = x < cut ? clamp01(1 - Math.abs(y + 0.5 - H / 2) / (H / 2)) : 0;
      return [1, 1, 1, a > 0 ? 1 : 0];
    });
    writePNG(`ants-v${ratio}.png`, H, W, (x, y) => {
      const a = y < cut ? 1 : 0;
      return [1, 1, 1, a];
    });
  }
  // classic-frame.png (64x64 moldura chanfrada 9-slice)
  writePNG("classic-frame.png", 64, 64, (x, y) => {
    const d = Math.min(x, y, 63 - x, 63 - y);
    if (d > 6) return [0, 0, 0, 0];
    if (d === 0 || d === 6) return [0.12, 0.1, 0.08, 0.95];
    if (d === 1 || d === 5) return [0.45, 0.38, 0.25, 0.98];
    return [0.78, 0.68, 0.45, 1];
  });
}

// --- 5. Overlays de Foco ---
function genFocusOverlays() {
  const S = 32;
  writePNG("focus-stripes.png", S, S, (x, y) => [1, 1, 1, ((x + y) % 16) < 7 ? 0.9 : 0]);
  writePNG("focus-stripes-reverse.png", S, S, (x, y) => [1, 1, 1, ((x - y + S * 2) % 16) < 7 ? 0.9 : 0]);
  writePNG("focus-stripes-thin.png", S, S, (x, y) => [1, 1, 1, ((x + y) % 8) < 2 ? 0.9 : 0]);
  writePNG("focus-chevrons.png", S, S, (x, y) => {
    const yy = Math.abs((y % 16) - 8);
    return [1, 1, 1, ((x + yy) % 16) < 5 ? 0.9 : 0];
  });
  writePNG("focus-dots.png", S, S, (x, y) => {
    const d = Math.hypot((x % 8) - 3.5, (y % 8) - 3.5);
    return [1, 1, 1, clamp01(2.2 - d)];
  });
  writePNG("focus-checker.png", S, S, (x, y) => [1, 1, 1, (((x >> 3) + (y >> 3)) & 1) ? 0.85 : 0]);
  writePNG("focus-grid.png", S, S, (x, y) => [1, 1, 1, (x % 8 < 2 || y % 8 < 2) ? 0.85 : 0]);
  writePNG("focus-edges.png", 64, 32, (x, y, w, h) => {
    const dx = Math.min(x, w - 1 - x) / 10;
    const dy = Math.min(y, h - 1 - y) / 6;
    const e = 1 - Math.min(dx, dy);
    return [1, 1, 1, clamp01(e)];
  });
  writePNG("focus-shine.png", 64, 32, (x, y, w, h) => {
    const v = y / (h - 1);
    return [1, 1, 1, clamp01((1 - v * 2.2)) * 0.95];
  });
}

// --- 6. Marcadores de Seleção (sel-*.png, 64x64 apontando para direita/baixo) ---
function genSelectionMarkers() {
  const S = 64, C = 32;
  const mark = (name, fn) => writePNG(`sel-${name}.png`, S, S, (x, y) => {
    const a = clamp01(fn(x + 0.5, y + 0.5));
    return [1, 1, 1, a];
  });
  // Seta sólida apontando para a direita
  mark("arrow", (x, y) => {
    const dy = Math.abs(y - C);
    if (x < 12 || x > 54) return 0;
    if (x < 32) return dy <= 8 ? 1 : 0;
    return clamp01((54 - x) * 0.7 - dy + 1);
  });
  mark("arrowdown", (x, y) => {
    const dx = Math.abs(x - C);
    if (y < 10 || y > 52) return 0;
    if (y < 32) return dx <= 8 ? 1 : 0;
    return clamp01((52 - y) * 0.7 - dx + 1);
  });
  mark("bracket", (x, y) => {
    if (x >= 18 && x <= 26 && y >= 6 && y <= 58) return 1;
    if ((y <= 14 || y >= 50) && x >= 18 && x <= 44) return 1;
    return 0;
  });
  mark("caret", (x, y) => {
    const dy = Math.abs(y - C);
    return clamp01(1 - Math.abs((x - 16) - (28 - dy)) / 3.5) * (dy <= 24 ? 1 : 0);
  });
  mark("chevron", (x, y) => {
    const dy = Math.abs(y - C);
    const tip = 48 - dy * 0.9;
    return (x <= tip && x >= tip - 10 && dy <= 24) ? 1 : 0;
  });
  mark("chevrondown", (x, y) => {
    const dx = Math.abs(x - C);
    const tip = 48 - dx * 0.9;
    return (y <= tip && y >= tip - 10 && dx <= 24) ? 1 : 0;
  });
  mark("chevrons", (x, y) => {
    const dy = Math.abs(y - C);
    if (dy > 22) return 0;
    const t1 = 34 - dy * 0.85, t2 = 52 - dy * 0.85;
    return ((x <= t1 && x >= t1 - 7) || (x <= t2 && x >= t2 - 7)) ? 1 : 0;
  });
  mark("chevrons3", (x, y) => {
    const dy = Math.abs(y - C);
    if (dy > 20) return 0;
    const t1 = 24 - dy * 0.85, t2 = 39 - dy * 0.85, t3 = 54 - dy * 0.85;
    return ((x <= t1 && x >= t1 - 6) || (x <= t2 && x >= t2 - 6) || (x <= t3 && x >= t3 - 6)) ? 1 : 0;
  });
  mark("dart", (x, y) => {
    const dy = Math.abs(y - C);
    return (x >= 14 && x <= 54) ? clamp01((54 - x) * 0.55 - dy + 1) : 0;
  });
  mark("thin", (x, y) => {
    const dy = Math.abs(y - C);
    return (x >= 10 && x <= 56 && dy <= 4) ? 1 : 0;
  });
  mark("pointer", (x, y) => {
    const dy = Math.abs(y - C);
    if (x < 16 || x > 54) return 0;
    return clamp01((54 - x) * 0.7 - dy + 1) * (x < 28 && dy < 7 ? 0 : 1);
  });
  mark("diamond", (x, y) => clamp01(22 - (Math.abs(x - C) + Math.abs(y - C))));
}

// --- 7. Ícones de Tipo, Quest, Facção e Discos de Classe ---
function genIcons() {
  const S = 64, C = 32;
  // type-boss (caveira estilizada)
  writePNG("type-boss.png", S, S, (x, y) => {
    const dx = (x + 0.5 - C) / 22, dy = (y + 0.5 - 26) / 20;
    const head = Math.hypot(dx, dy) < 1;
    const jaw = Math.abs(x + 0.5 - C) < 12 && y >= 34 && y <= 52;
    const eyeL = Math.hypot(x + 0.5 - 23, y + 0.5 - 28) < 5;
    const eyeR = Math.hypot(x + 0.5 - 41, y + 0.5 - 28) < 5;
    const nose = Math.abs(x + 0.5 - C) < 3 && y >= 33 && y <= 40;
    const teeth = jaw && y >= 45 && ((Math.floor((x - 20) / 5) % 2) === 1);
    const on = (head || jaw) && !eyeL && !eyeR && !nose && !teeth;
    return on ? [0.95, 0.93, 0.90, 1] : [0, 0, 0, 0];
  });
  // type-miniboss (coroa / diamante duplo)
  writePNG("type-miniboss.png", S, S, (x, y) => {
    const d1 = Math.abs(x + 0.5 - C) + Math.abs(y + 0.5 - C);
    const in1 = d1 <= 24 && d1 >= 16;
    const in2 = d1 <= 10;
    return (in1 || in2) ? [0.72, 0.52, 1, 1] : [0, 0, 0, 0];
  });
  // type-caster (orbe arcano com anel)
  writePNG("type-caster.png", S, S, (x, y) => {
    const d = Math.hypot(x + 0.5 - C, y + 0.5 - C);
    if (d <= 11) return [1, 0.42, 0.92, 1];
    if (d >= 16 && d <= 22) return [0.95, 0.30, 0.85, 0.9];
    return [0, 0, 0, 0];
  });
  // type-elite (estrela de 4 pontas dourada)
  writePNG("type-elite.png", S, S, (x, y) => {
    const ax = Math.abs(x + 0.5 - C) / 26, ay = Math.abs(y + 0.5 - C) / 26;
    const s = Math.pow(ax, 0.55) + Math.pow(ay, 0.55);
    return s <= 0.95 ? [1, 0.84, 0.25, 1] : [0, 0, 0, 0];
  });
  // type-idle (Zzz)
  writePNG("type-idle.png", S, S, (x, y) => {
    const z = (zx, zy, sz) => {
      const lx = x - zx, ly = y - zy;
      if (lx < 0 || lx > sz || ly < 0 || ly > sz) return false;
      return ly < 3 || ly > sz - 3 || Math.abs((sz - lx) - ly) < 2.8;
    };
    const on = z(10, 26, 20) || z(32, 14, 16) || z(44, 6, 12);
    return on ? [0.75, 0.85, 1, 1] : [0, 0, 0, 0];
  });

  // quest-exclamation, quest-kill, quest-loot
  writePNG("quest-exclamation.png", S, S, (x, y) => {
    const dx = Math.abs(x + 0.5 - C);
    const bar = dx <= 5 && y >= 10 && y <= 38;
    const dot = Math.hypot(x + 0.5 - C, y + 0.5 - 49) <= 5.5;
    if (bar || dot) return [1, 0.84, 0.15, 1];
    const outline = (dx <= 7.5 && y >= 8 && y <= 40) || Math.hypot(x + 0.5 - C, y + 0.5 - 49) <= 8;
    return outline ? [0.1, 0.06, 0.02, 0.95] : [0, 0, 0, 0];
  });
  writePNG("quest-kill.png", S, S, (x, y) => {
    const d1 = Math.abs((x - C) - (y - C));
    const d2 = Math.abs((x - C) + (y - C));
    const inside = Math.abs(x - C) <= 18 && Math.abs(y - C) <= 18;
    if (inside && (d1 <= 4.5 || d2 <= 4.5)) return [1, 0.35, 0.25, 1];
    if (inside && (d1 <= 7 || d2 <= 7)) return [0.1, 0.04, 0.04, 0.95];
    return [0, 0, 0, 0];
  });
  writePNG("quest-loot.png", S, S, (x, y) => {
    const bag = Math.hypot((x + 0.5 - C) / 16, (y + 0.5 - 38) / 15) <= 1;
    const neck = Math.abs(x + 0.5 - C) <= 8 && y >= 20 && y <= 28;
    const top = Math.abs(x + 0.5 - C) <= 12 && y >= 13 && y <= 20;
    if (bag || neck || top) return [1, 0.84, 0.32, 1];
    return [0, 0, 0, 0];
  });

  // class-disc & class-disc-soft
  writePNG("class-disc.png", S, S, (x, y) => {
    const d = Math.hypot(x + 0.5 - C, y + 0.5 - C);
    return [1, 1, 1, clamp01(30 - d)];
  });
  writePNG("class-disc-soft.png", S, S, (x, y) => {
    const d = Math.hypot(x + 0.5 - C, y + 0.5 - C) / 31;
    return [1, 1, 1, Math.pow(clamp01(1 - d), 1.8)];
  });

  // faction-Alliance / Horde (emblemas estilizados limpos)
  writePNG("faction-Alliance.png", S, S, (x, y) => {
    const d = Math.hypot(x + 0.5 - C, y + 0.5 - C);
    if (d > 28) return [0, 0, 0, 0];
    if (d > 24) return [0.92, 0.78, 0.32, 1];
    const inCross = Math.abs(x + 0.5 - C) <= 5 || Math.abs(y + 0.5 - C) <= 5;
    if (inCross && d <= 18) return [0.95, 0.85, 0.45, 1];
    return [0.10, 0.34, 0.78, 1];
  });
  writePNG("faction-Horde.png", S, S, (x, y) => {
    const d = Math.hypot(x + 0.5 - C, y + 0.5 - C);
    if (d > 28) return [0, 0, 0, 0];
    if (d > 24) return [0.75, 0.16, 0.14, 1];
    const dDiamond = Math.abs(x + 0.5 - C) + Math.abs(y + 0.5 - C);
    if (dDiamond <= 15 && dDiamond >= 9) return [0.95, 0.25, 0.20, 1];
    return [0.16, 0.04, 0.04, 1];
  });
}

// --- 8. Recursos de Classe (9 formas geométricas: slot, body, shine) ---
function genResources() {
  const S = 48, C = 24;
  const shapes = {
    gems: (x, y) => Math.max(Math.abs(x - C) * 0.9, Math.abs(y - C)) - 17,
    orbs: (x, y) => Math.hypot(x - C, y - C) - 18,
    diamonds: (x, y) => (Math.abs(x - C) + Math.abs(y - C)) * 0.78 - 17,
    hex: (x, y) => {
      const ax = Math.abs(x - C), ay = Math.abs(y - C);
      return Math.max(ay - 15, ax * 0.866 + ay * 0.5 - 15);
    },
    shards: (x, y) => (Math.abs(x - C) * 1.45 + Math.abs(y - C) * 0.72) - 16,
    capsules: (x, y) => {
      const px = Math.max(0, Math.abs(x - C) - 9);
      return Math.hypot(px, y - C) - 10;
    },
    blades: (x, y) => {
      const nx = (x - C) / 18, ny = (y - C) / 10;
      return (Math.abs(nx) + Math.abs(ny) - 1.0) * 12;
    },
    skull: (x, y) => Math.hypot((x - C) / 1.05, (y - C) / 1.1) - 16,
    holy1: (x, y) => (Math.abs(x - C) * 0.95 + Math.abs(y - C) * 0.95) - 17,
  };
  for (const [name, sdf] of Object.entries(shapes)) {
    const keys = name === "holy1" ? ["holy1", "holy2", "holy3", "holy4", "holy5"] : [name];
    for (const k of keys) {
      writePNG(`res-${k}-slot.png`, S, S, (x, y) => {
        const d = sdf(x + 0.5, y + 0.5);
        if (d > 2) return [0, 0, 0, 0];
        if (d > -1.5) return [0.08, 0.08, 0.1, 0.95];
        return [0.22, 0.22, 0.26, 0.65];
      });
      writePNG(`res-${k}-body.png`, S, S, (x, y) => {
        const d = sdf(x + 0.5, y + 0.5);
        const a = clamp01(-0.5 - d);
        const shade = clamp01(0.82 + 0.18 * (1 - (y / S)));
        return [shade, shade, shade, a];
      });
      writePNG(`res-${k}-shine.png`, S, S, (x, y) => {
        const d = sdf(x + 0.5, y + 0.5);
        if (d > -1.5) return [0, 0, 0, 0];
        const top = clamp01(1 - y / (S * 0.65));
        return [1, 1, 1, top * 0.55];
      });
    }
  }
}

genBars();
genRoundedCorners();
genBoxes();
genEffects();
genFocusOverlays();
genSelectionMarkers();
genIcons();
genResources();

console.log("Texturas geradas em:", OUT);
