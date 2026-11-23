// Preenchimento da placa minimalista (Zerker): a MESMA arte líquida da vida do quadro
// (HPFill / HPFillNeutral do gen.js), recortada do miolo do paralelogramo e posta numa
// pílula (pontas arredondadas). 256x16, cobre a barra de 86x5 da placa.
// Uso: node tools/bdo-hud-concept/plate-fill.js  (depois de gen.js)
"use strict";
const path = require("path");
const C = require("../map-extract/imagecodec");
const DIR = path.join(__dirname, "..", "..", "AzaathUI", "Media", "BDO");
const OW = 256, OH = 16, SX0 = 100, SX1 = 920, SY0 = 4, SY1 = 60; // miolo sem as pontas inclinadas
const SW = 86, SH = 5;                                             // tamanho na tela
const rx = (SH / 2) * OW / SW, ry = OH / 2;                        // raio da ponta (px da textura)
function sample(im, x, y) {
  const x0 = Math.max(0, Math.min(im.w - 2, Math.floor(x))), y0 = Math.max(0, Math.min(im.h - 2, Math.floor(y)));
  const fx = x - x0, fy = y - y0, out = [0, 0, 0, 0];
  for (const [dx, dy, w] of [[0, 0, (1 - fx) * (1 - fy)], [1, 0, fx * (1 - fy)], [0, 1, (1 - fx) * fy], [1, 1, fx * fy]]) {
    const i = ((y0 + dy) * im.w + x0 + dx) * 4;
    for (let c = 0; c < 4; c++) out[c] += im.data[i + c] * w;
  }
  return out;
}
function inside(x, y) { // pílula: retângulo + elipses nas pontas
  const cy = OH / 2;
  let cx = x;
  if (x < rx) cx = rx; else if (x > OW - rx) cx = OW - rx; else return Math.abs(y - cy) <= ry;
  const dx = (x - cx) / rx, dy = (y - cy) / ry;
  return dx * dx + dy * dy <= 1;
}
// LIFT: o vermelho da placa um pouco mais claro que o do quadro (pedido 23/11)
const LIFT = { PlateFill: 1.22, PlateFillNeutral: 1 };
for (const [src, dst] of [["HPFill", "PlateFill"], ["HPFillNeutral", "PlateFillNeutral"]]) {
  const im = C.readTGA(path.join(DIR, src + ".tga"));
  const o = C.makeImage(OW, OH);
  const SS = 4;
  for (let y = 0; y < OH; y++) for (let x = 0; x < OW; x++) {
    let cov = 0;
    for (let j = 0; j < SS; j++) for (let i = 0; i < SS; i++) if (inside(x + (i + 0.5) / SS, y + (j + 0.5) / SS)) cov++;
    const p = sample(im, SX0 + (x + 0.5) / OW * (SX1 - SX0), SY0 + (y + 0.5) / OH * (SY1 - SY0));
    const k = (y * OW + x) * 4;
    const L = LIFT[dst];
    o.data[k] = Math.min(255, p[0] * L + 6 * (L - 1) * 10); o.data[k + 1] = Math.min(255, p[1] * L); o.data[k + 2] = Math.min(255, p[2] * L);
    o.data[k + 3] = Math.round(255 * cov / (SS * SS));
  }
  C.writeTGA(path.join(DIR, dst + ".tga"), o);
  console.log(dst + ".tga", OW + "x" + OH);
}

// Aura de aggro (mob agrado em você): brilho vermelho macio SÓ por fora da pílula.
// Cobre o trilho (88x7 na tela) + 5 px de cada lado = 98x17; miolo transparente para
// o vermelho não vazar pelo fundo translúcido da barra.
{
  const AW = 256, AH = 48, VW = 98, VH = 17, PAD = 5, TW = 88, TH = 7;
  const o = C.makeImage(AW, AH), SS = 4, r = TH / 2;
  for (let y = 0; y < AH; y++) for (let x = 0; x < AW; x++) {
    let acc = 0;
    for (let j = 0; j < SS; j++) for (let i = 0; i < SS; i++) {
      const sx = (x + (i + 0.5) / SS) / AW * VW - PAD, sy = (y + (j + 0.5) / SS) / AH * VH - PAD;
      const cx = Math.max(r, Math.min(TW - r, sx));
      const d = Math.hypot(sx - cx, sy - TH / 2) - r; // > 0 = fora do trilho
      if (d > 0 && d < PAD) acc += 0.8 * Math.pow(1 - d / PAD, 1.6);
    }
    const k = (y * AW + x) * 4;
    o.data[k] = 255; o.data[k + 1] = 34; o.data[k + 2] = 18;
    o.data[k + 3] = Math.round(255 * acc / (SS * SS));
  }
  C.writeTGA(path.join(DIR, "PlateAggro.tga"), o);
  console.log("PlateAggro.tga", AW + "x" + AH);
}

// Aura de aggro da placa Zerker (paralelogramo do HPBg, barra de 110x10 na tela):
// cobre a barra + 5 px de cada lado; miolo transparente.
{
  const AW = 256, AH = 48, BW = 110, BH = 10, PAD = 5, VW = BW + 2 * PAD, VH = BH + 2 * PAD;
  const fx = BW / 1024, fy = BH / 64;
  const P = [[7 * fx, 4 * fy], [939 * fx, 4 * fy], [1017 * fx, 60 * fy], [85 * fx, 60 * fy]];
  function segDist(px, py, a, b) {
    const dx = b[0] - a[0], dy = b[1] - a[1];
    const t = Math.max(0, Math.min(1, ((px - a[0]) * dx + (py - a[1]) * dy) / (dx * dx + dy * dy)));
    return Math.hypot(px - (a[0] + t * dx), py - (a[1] + t * dy));
  }
  function inside(px, py) {
    for (let i = 0; i < 4; i++) {
      const a = P[i], b = P[(i + 1) % 4];
      if ((b[0] - a[0]) * (py - a[1]) - (b[1] - a[1]) * (px - a[0]) < 0) return false;
    }
    return true;
  }
  const o = C.makeImage(AW, AH), SS = 4;
  for (let y = 0; y < AH; y++) for (let x = 0; x < AW; x++) {
    let acc = 0;
    for (let j = 0; j < SS; j++) for (let i = 0; i < SS; i++) {
      const sx = (x + (i + 0.5) / SS) / AW * VW - PAD, sy = (y + (j + 0.5) / SS) / AH * VH - PAD;
      if (inside(sx, sy)) continue;
      let d = Infinity;
      for (let k = 0; k < 4; k++) d = Math.min(d, segDist(sx, sy, P[k], P[(k + 1) % 4]));
      if (d < PAD) acc += 0.8 * Math.pow(1 - d / PAD, 1.6);
    }
    const k = (y * AW + x) * 4;
    o.data[k] = 255; o.data[k + 1] = 34; o.data[k + 2] = 18;
    o.data[k + 3] = Math.round(255 * acc / (SS * SS));
  }
  C.writeTGA(path.join(DIR, "PlateAggroPar.tga"), o);
  console.log("PlateAggroPar.tga", AW + "x" + AH);
}
