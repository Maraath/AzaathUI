const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const src = readPNG(path.join(__dirname, "concept.png"));
const out = { w: src.w, h: src.h, px: Float32Array.from(src.px) };

function put(x, y, r, g, b, a = 1) {
  x = Math.round(x); y = Math.round(y);
  if (x < 0 || y < 0 || x >= out.w || y >= out.h) return;
  const o = (y * out.w + x) * 4;
  out.px[o] = out.px[o] * (1 - a) + r * a;
  out.px[o + 1] = out.px[o + 1] * (1 - a) + g * a;
  out.px[o + 2] = out.px[o + 2] * (1 - a) + b * a;
}

function circle(cx, cy, rad, r, g, b) {
  for (let a = 0; a < 360; a += 1) {
    const t = (a * Math.PI) / 180;
    put(cx + Math.cos(t) * rad, cy + Math.sin(t) * rad, r, g, b, 0.9);
  }
  for (let d = -3; d <= 3; d++) { put(cx + d, cy, r, g, b, 0.9); put(cx, cy + d, r, g, b, 0.9); }
}

function rect(x, y, w, h, r, g, b) {
  for (let i = 0; i <= w; i++) { put(x + i, y, r, g, b, 0.9); put(x + i, y + h, r, g, b, 0.9); }
  for (let j = 0; j <= h; j++) { put(x, y + j, r, g, b, 0.9); put(x + w, y + j, r, g, b, 0.9); }
}

// Left wing slots (6x2)
const LX = [0, 1, 2, 3, 4, 5].map((i) => Math.round(81 + 40.7 * i));
const LY = [273, 331];
const LR = 19;
for (const y of LY) for (const x of LX) circle(x, y, LR, 0, 255, 180);

// Right wing slots (6x2)
const RX = [0, 1, 2, 3, 4, 5].map((i) => Math.round(694 + 51.4 * i));
const RY = [254, 331];
const RR = 24;
for (const y of RY) for (const x of RX) circle(x, y, RR, 0, 255, 180);

// CF1 / CF2 tabs
rect(62, 215, 35, 31, 255, 220, 0);
rect(101, 215, 35, 31, 255, 220, 0);

// Health, Power, XP, Center
rect(176, 392, 206, 42, 255, 80, 80);
rect(626, 392, 206, 42, 255, 180, 40);
rect(368, 442, 274, 62, 80, 220, 255);
circle(508, 350, 25, 255, 255, 0);

// HUD bounds
rect(24, 122, 976, 408, 255, 255, 255);

I.writePNG(path.join(__dirname, "preview", "measure.png"), out);
console.log("LX:", LX, "LY:", LY);
console.log("RX:", RX, "RY:", RY);
