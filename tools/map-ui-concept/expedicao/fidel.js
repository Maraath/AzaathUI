// Marcadores de missão medidos pixel a pixel das capturas do Azaath (8.jpg = escala dos alfinetes, 9.jpg = losango em andamento)
//   unidades = pixels da captura; K texels por unidade (textura nítida); o jogo exibe em tamanho de unidade
//   pegar (dourado/azul): losango vazado 24 px (meia-diagonal 12, furo 6, bordas escuras de 1 px), furo = escurecimento leve,
//                         agulha de 4 px (miolo claro 2 + bordas) até 45
//   entregar (verde): espigão fino, barbas laterais agudas, cauda longa, furo escuro quase opaco
//   andamento: losango 53x51 (unidades da 9.jpg), borda marrom, sombra deslocada 7 abaixo, um chevron claro
//   node fidel.js -> PinGetN / PinGetB2 / PinDoneN / PinProgN
"use strict";
const path = require("path"), I = require("../../sheet-concept/img");
const SS = 4;
const lerp = (a, b, t) => a.map((v, k) => v + (b[k] - v) * t);
const clamp = (t) => Math.min(1, Math.max(0, t));
const inPoly = (x, y, p) => { let c = false; for (let i = 0, j = p.length - 1; i < p.length; j = i++) if (((p[i][1] > y) !== (p[j][1] > y)) && (x < (p[j][0] - p[i][0]) * (y - p[i][1]) / (p[j][1] - p[i][1]) + p[i][0])) c = !c; return c; };
const segD = (x, y, a, b) => { const dx = b[0] - a[0], dy = b[1] - a[1]; if (dx === 0 && dy === 0) return Math.hypot(x - a[0], y - a[1]); const t = clamp(((x - a[0]) * dx + (y - a[1]) * dy) / (dx * dx + dy * dy)); return Math.hypot(x - a[0] - t * dx, y - a[1] - t * dy); };
const polyD = (x, y, p) => { let d = 1e9; for (let i = 0, j = p.length - 1; i < p.length; j = i++) d = Math.min(d, segD(x, y, p[j], p[i])); return d; };
// cada forma devolve [r,g,b,a] (a em 0..1) ou null, em unidades
function render(name, W, H, K, f) {
  const w = Math.round(W * K), h = Math.round(H * K), out = I.create(w, h);
  for (let py = 0; py < h; py++) for (let px = 0; px < w; px++) {
    let r = 0, g = 0, b = 0, a = 0;
    for (let j = 0; j < SS; j++) for (let i = 0; i < SS; i++) {
      const c = f((px + (i + .5) / SS) / K, (py + (j + .5) / SS) / K);
      if (c) { r += c[0] * c[3]; g += c[1] * c[3]; b += c[2] * c[3]; a += c[3]; }
    }
    const o = (py * w + px) * 4;
    if (a > 0) { out.px[o] = Math.round(r / a); out.px[o + 1] = Math.round(g / a); out.px[o + 2] = Math.round(b / a); out.px[o + 3] = Math.round(255 * a / (SS * SS)); }
  }
  for (const d of ["D:/ProjectAzaath/AzaathUI/Media/MapFrame", "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame"]) I.writeTGA(d + "/" + name + ".tga", out);
  I.writePNG(path.join(__dirname, "out", "icons", name + ".png"), out);
  console.log(name, w + "x" + h);
}
// --- alfinete de pegar (26 x 46), centro do losango (13,13)
function getPin(T) {
  return (x, y) => {
    const dd = Math.abs(x - 13) + Math.abs(y - 13);
    if (dd <= 12) {
      if (dd > 11.1) return [...T.edge, 0.9];
      if (dd > 5.6) return [...T.ring, 1];
      if (dd > 4.6) return [...T.edge, 0.95];
      return [0, 0, 0, 0.28];
    }
    if (y >= 24 && y <= 45 && Math.abs(x - 13) <= 2) {
      const fade = y > 44 ? 0.6 : 1;
      return Math.abs(x - 13) > 1 ? [...T.nEdge, 0.9 * fade] : [...T.needle, fade];
    }
    return null;
  };
}
// cor média das capturas (8.jpg, 6.webp, 10.jpg): dourado-creme, não amarelo-limão
const GOLD = { ring: [247, 218, 108], edge: [150, 118, 40], needle: [246, 226, 150], nEdge: [160, 132, 55] };
const BLUE = { ring: [110, 190, 250], edge: [30, 80, 150], needle: [165, 215, 255], nEdge: [40, 95, 165] };
render("PinGetN2", 26, 46, 4, getPin(GOLD));
render("PinGetB2", 26, 46, 4, getPin(BLUE));
// --- alfinete verde de entregar (24 x 50), eixo x = 12; meias-larguras medidas por linha da captura
{
  const R = [[2.5, 0.4], [3.5, 1.3], [12, 1.3], [18.5, 1.4], [20, 1.8], [22, 3], [23, 4.2], [24, 6.5], [25, 8], [26, 8.6], [26.9, 10.6],
             [27.6, 9], [28.5, 8.4], [29.5, 7.6], [30.5, 6.8], [31.5, 6], [33, 5.2], [35, 4.5], [37, 3.6], [39, 3], [41, 2.6], [43, 1.9], [45, 1.2], [47, 0.5], [48, 0]];
  R.sort((a, b) => a[0] - b[0]);
  const BL = R.map(([y, hw]) => [12 + hw, y]).concat(R.slice().reverse().map(([y, hw]) => [12 - hw, y]));
  const HO = [[12, 23], [17, 27.1], [12, 36.8], [7, 27.1]];
  const FILL = [120, 245, 165], FILL2 = [145, 252, 185], EDGE = [30, 125, 72], HOLE = [40, 58, 50];
  render("PinDoneN3", 24, 50, 4, (x, y) => {
    if (!inPoly(x, y, BL)) return null;
    if (inPoly(x, y, HO)) return polyD(x, y, HO) < 0.7 ? [...EDGE, 0.95] : [...HOLE, 0.92];
    const d = polyD(x, y, BL), dh = polyD(x, y, HO);
    if (d < 0.75) return [...EDGE, 0.85];
    return [...lerp(FILL2, FILL, clamp(Math.min(d, dh) / 2.5)), 1];
  });
}
// --- losango em andamento (unidades da 9.jpg; 60 x 72), centro (30,29)
{
  const CX = 30, CY = 29, HX = 26.5, HY = 26.5, SH = 5.5;
  const FC = [254, 202, 88], FE = [250, 190, 74], EDGE = [120, 80, 20], SHC = [92, 70, 36], CHV = [248, 214, 120], CHE = [123, 98, 27];
  const dia = (x, y, oy) => Math.abs(x - CX) / HX + Math.abs(y - CY - oy) / HY;   // 1 = borda
  render("PinProgN2", 60, 72, 2.4, (x, y) => {
    const d = dia(x, y, 0);
    if (d <= 1) {
      const inner = 1 - d;                              // distância relativa até a borda
      if (inner * 26 < 1.5) return [...EDGE, 0.95];
      return [...lerp(FC, FE, Math.pow(clamp(d), 3)), 1];
    }
    // chevron: eixo em V com ápice (30, 66), braços a 45° até |dx| = 18
    const dx = Math.abs(x - CX);
    if (dx <= 18.5 && y > 44) {
      const dist = Math.abs((y - (66 - dx))) * Math.SQRT1_2;
      if (dist <= 1.9 && dx <= 18) return dist > 1.2 ? [...CHE, 0.95] : [...CHV, 1];
    }
    if (dia(x, y, SH) <= 1) return [...SHC, 0.8];
    // sombra suave em volta
    const dg = Math.min(dia(x, y, 0), dia(x, y, SH)) - 1;
    if (dg < 0.12) return [30, 20, 10, 0.3 * (1 - dg / 0.12)];
    return null;
  });
}
// --- alfinete redondo amarelo (pin personalizado), medido da 9.jpg: círculo R 10.5 com centro (11,11.5), ponta 30 abaixo,
//     borda marrom de ~1, furo escuro R 4 com aro marrom; 22 x 44 unidades
{
  const P = 1.6, CX = 11 + P, CY = 11.5 + P, R = 10.5, TIP = 41.5 + P, FILL = [96, 56, 20], LITE = [138, 86, 36], EDGE = [252, 206, 62], RIM = [60, 34, 10], HOLE = [252, 214, 80];
  // tangentes do círculo até a ponta
  const d = TIP - CY, a = Math.asin(R / d);
  const ty = CY + R * Math.sin(a), tx = R * Math.cos(a);
  const inside = (x, y) => {
    if (Math.hypot(x - CX, y - CY) <= R) return true;
    if (y < ty || y > TIP) return false;
    return Math.abs(x - CX) <= tx * (TIP - y) / (TIP - ty);
  };
  const edgeD = (x, y) => {                       // distância aproximada até a borda (por dentro)
    let best = 9;
    for (let k = 0; k < 24; k++) { const ang = k / 24 * Math.PI * 2, dx = Math.cos(ang), dy = Math.sin(ang);
      for (let t = 0.25; t < 2.5; t += 0.25) if (!inside(x + dx * t, y + dy * t)) { best = Math.min(best, t); break; } }
    return best;
  };
  // borda creme por fora do contorno marrom (destaca o pin no mapa): até 1.4 unidades fora da forma
  const outD = (x, y) => {
    let best = 9;
    for (let k = 0; k < 24; k++) { const ang = k / 24 * Math.PI * 2;
      for (let t = 0.2; t <= 1.6; t += 0.2) if (inside(x + Math.cos(ang) * t, y + Math.sin(ang) * t)) { best = Math.min(best, t); break; } }
    return best;
  };
  render("PinUserY", 22 + 2 * P, 44 + 2 * P, 4, (x, y) => {
    if (!inside(x, y)) { const o = outD(x, y); return o <= 1.2 ? [40, 22, 6, 0.9 * clamp((1.4 - o) / 0.4)] : null; }
    const h = Math.hypot(x - CX, y - CY);
    if (h <= 3.1) return [...HOLE, 0.97];
    if (h <= 4.1) return [...RIM, 1];
    const e = edgeD(x, y);
    if (e <= 1.7) return [...EDGE, 1];
    return [...lerp(LITE, FILL, clamp((y - 1) / 18)), 1];
  });
}
