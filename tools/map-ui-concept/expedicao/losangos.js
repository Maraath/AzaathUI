// "?" e "!" de missão dentro de losango (a marca do addon): anel claro + faixa escura + miolo vivo + glifo escuro,
// com brilho suave por fora, no mesmo desenho do losango ciano PinProgress -> PinTurnInD / PinNewD / PinRepeatD
"use strict";
const path = require("path"), I = require("../../sheet-concept/img");
const S = 96, C0 = S / 2, SS = 3, A = 44, B = 38.5, C = 32.5, GLOW = 4;
const DARK = [38, 22, 4];
const THEMES = {
  gold: { ring: [238, 206, 128], hi: [228, 186, 84], lo: [176, 128, 36], glow: [214, 164, 56] },
  blue: { ring: [150, 215, 255], hi: [120, 205, 255], lo: [40, 150, 245], glow: [70, 170, 255] },
};
// glifos em coordenadas próprias, mapeados para o centro do losango
const gl = {
  "!": (() => {
    const CX = 28, TOP = 16, BOT = 76, HW0 = 14, HW1 = 8.5, DY = 116, DR = 11.5, sc = 42 / 125.5, my = 64.7;
    return (x, y) => { const u = x / sc + CX, v = y / sc + my;
      if (v >= TOP && v <= BOT && Math.abs(u - CX) <= HW0 + (HW1 - HW0) * (v - TOP) / (BOT - TOP)) return true;
      if (v < TOP && Math.hypot(u - CX, v - TOP) <= HW0) return true;
      if (v > BOT && Math.hypot(u - CX, v - BOT) <= HW1) return true;
      return Math.hypot(u - CX, v - DY) <= DR; };
  })(),
  "?": (() => {
    const CX = 36, CY = 34, RAD = 17.5, HW = 7.8, DOT = [36, 94], DR = 9.2, sc = 42 / 93, my = 56, pts = [];
    for (let t = Math.PI * 0.93; t <= Math.PI * 2 + 0.85; t += 0.02) pts.push([CX + RAD * Math.cos(t), CY + RAD * Math.sin(t)]);
    const E = pts[pts.length - 1], Cc = [47, 55], F = [36, 62];
    for (let u = 0.02; u <= 1; u += 0.02) pts.push([(1 - u) ** 2 * E[0] + 2 * u * (1 - u) * Cc[0] + u * u * F[0], (1 - u) ** 2 * E[1] + 2 * u * (1 - u) * Cc[1] + u * u * F[1]]);
    for (let y = 63; y <= 67; y += 0.5) pts.push([36, y]);
    return (x, y) => { const u = x / sc + CX, v = y / sc + my;
      if (Math.hypot(u - DOT[0], v - DOT[1]) <= DR) return true;
      for (const p of pts) if ((u - p[0]) ** 2 + (v - p[1]) ** 2 <= HW * HW) return true;
      return false; };
  })(),
};
function make(name, glyph, th) {
  const T = THEMES[th], out = I.create(S, S), g = gl[glyph] || (() => false);
  for (let py = 0; py < S; py++) for (let px = 0; px < S; px++) {
    let r = 0, gg = 0, b = 0, a = 0;
    for (let j = 0; j < SS; j++) for (let i = 0; i < SS; i++) {
      const x = px + (i + .5) / SS - C0, y = py + (j + .5) / SS - C0, d = Math.abs(x) + Math.abs(y);
      let c, al = 1;
      if (d <= C) { c = g(x, y) ? DARK : [0, 1, 2].map((k) => T.hi[k] + (T.lo[k] - T.hi[k]) * Math.min(1, Math.max(0, (y + C) / (2 * C)))); }
      else if (d <= B) c = DARK;
      else if (d <= A) c = T.ring;
      else if (d <= A + GLOW * 2.5) { c = T.glow; al = 0.45 * Math.pow(1 - (d - A) / (GLOW * 2.5), 2); }
      else continue;
      r += c[0] * al; gg += c[1] * al; b += c[2] * al; a += al;
    }
    const o = (py * S + px) * 4, n = SS * SS;
    if (a > 0) { out.px[o] = Math.round(r / a); out.px[o + 1] = Math.round(gg / a); out.px[o + 2] = Math.round(b / a); out.px[o + 3] = Math.round(255 * a / n); }
  }
  for (const d of ["D:/ProjectAzaath/AzaathUI/Media/MapFrame", "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame"]) I.writeTGA(d + "/" + name + ".tga", out);
  I.writePNG(path.join(__dirname, "out", "icons", name + ".png"), out);
}
make("PinTurnInG", "?", "gold"); make("PinNewG", "!", "gold"); make("PinRepeatD", "!", "blue"); make("PinProgG", null, "gold");
