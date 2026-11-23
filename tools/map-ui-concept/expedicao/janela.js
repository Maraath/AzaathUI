// Botões da janela do mapa (canto da moldura de pedra): medalhão de pedra escura com aro de bronze e o símbolo em
// creme-dourado com sombra: X (fechar), quatro cantos para fora (tela cheia), quatro cantos para dentro (janela)
//   node janela.js -> Media/MapFrame/ExpWinClose / ExpWinMax / ExpWinRestore (128x128)
"use strict";
const path = require("path"), I = require("../../sheet-concept/img");
const S = 128, C = 64, SS = 4;
const lerp = (a, b, t) => a.map((v, k) => v + (b[k] - v) * t);
const clamp = (t) => Math.min(1, Math.max(0, t));
const segD = (x, y, ax, ay, bx, by) => { const dx = bx - ax, dy = by - ay, t = clamp(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)); return Math.hypot(x - ax - t * dx, y - ay - t * dy); };
// símbolos: listas de segmentos [ax, ay, bx, by] (relativos ao centro) com meia-espessura W
const W = 6.2;
const GLYPH = {
  close: [[-22, -22, 22, 22], [22, -22, -22, 22]],
  max: [].concat(...[[-1, -1], [1, -1], [-1, 1], [1, 1]].map(([sx, sy]) => [
    [sx * 27, sy * 27, sx * 11, sy * 27], [sx * 27, sy * 27, sx * 27, sy * 11]])),
  restore: [].concat(...[[-1, -1], [1, -1], [-1, 1], [1, 1]].map(([sx, sy]) => [
    [sx * 15, sy * 15, sx * 30, sy * 15], [sx * 15, sy * 15, sx * 15, sy * 30]])),
};
const RIM_HI = [196, 158, 92], RIM_LO = [104, 74, 38], IN_HI = [52, 56, 60], IN_LO = [22, 24, 28];
const GL_HI = [246, 232, 196], GL_LO = [214, 186, 128], SHADOW = [8, 8, 10];
function make(name, key) {
  const segs = GLYPH[key], out = I.create(S, S);
  const gd = (x, y) => { let d = 1e9; for (const s of segs) d = Math.min(d, segD(x, y, s[0], s[1], s[2], s[3])); return d; };
  for (let py = 0; py < S; py++) for (let px = 0; px < S; px++) {
    let r = 0, g = 0, b = 0, a = 0;
    for (let j = 0; j < SS; j++) for (let i = 0; i < SS; i++) {
      const x = px + (i + .5) / SS - C, y = py + (j + .5) / SS - C, d = Math.hypot(x, y);
      let c = null, al = 1;
      if (d <= 52) {
        if (d > 45) c = lerp(RIM_HI, RIM_LO, clamp((y + 50) / 100));                 // aro de bronze
        else if (d > 43.5) c = [14, 12, 10];                                           // sulco
        else c = lerp(IN_HI, IN_LO, clamp((y + 44) / 88 + d / 200));                  // pedra escura
        const gs = gd(x - 2, y - 3);                                                   // sombra do símbolo
        if (d <= 43.5 && gs <= W + 1.5) c = lerp(c, SHADOW, 0.75);
        const g0 = gd(x, y);
        if (d <= 43.5 && g0 <= W) c = lerp(GL_HI, GL_LO, clamp((y + 28) / 56));      // símbolo
        if (d <= 43.5 && g0 > W && g0 <= W + 1) c = lerp(c, [60, 44, 20], 0.8);      // fio escuro em volta
      } else if (d <= 55) { c = SHADOW; al = 0.45 * (1 - (d - 52) / 3); }             // sombra suave fora
      if (c) { r += c[0] * al; g += c[1] * al; b += c[2] * al; a += al; }
    }
    const o = (py * S + px) * 4;
    if (a > 0) { out.px[o] = Math.round(r / a); out.px[o + 1] = Math.round(g / a); out.px[o + 2] = Math.round(b / a); out.px[o + 3] = Math.round(255 * a / (SS * SS)); }
  }
  for (const d of ["D:/ProjectAzaath/AzaathUI/Media/MapFrame", "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame"]) I.writeTGA(d + "/" + name + ".tga", out);
  I.writePNG(path.join(__dirname, "out", "icons", name + ".png"), out);
}
make("ExpWinClose", "close"); make("ExpWinMax", "max"); make("ExpWinRestore", "restore");
