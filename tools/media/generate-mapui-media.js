// Ícones da janela do mapa (Modules/WorldMap.lua): os mesmos desenhos do protótipo (traço de 24 unidades,
// como SVG), rasterizados em TGA 64x64 branco + alpha. A cor vem no jogo com SetVertexColor.
// Substituem os símbolos de texto (⌕ ✕ ≡ ⛶ ❐ ◎ ◈ ✎) que a fonte do jogo não tem e viravam quadrados.
// Saída: AzaathUI/Media/MapUI/<Nome>.tga.  Uso: node tools/media/generate-mapui-media.js
"use strict";
const fs = require("fs");
const path = require("path");

const SIZE = 64;
const S = SIZE / 24;                 // unidades do desenho -> pixels
const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "MapUI");
const clamp01 = (v) => Math.max(0, Math.min(1, v));

// ---------------------------------------------------------------- formas (em unidades de 24)
const P = (x, y) => [x, y];
function arc(cx, cy, r, a0, a1, n = 48) {          // ângulos em graus, 0 = leste, sentido horário (y para baixo)
  const pts = [];
  for (let i = 0; i <= n; i++) {
    const a = (a0 + (a1 - a0) * i / n) * Math.PI / 180;
    pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  return pts;
}
function cubic(p0, p1, p2, p3, n = 32) {
  const pts = [];
  for (let i = 0; i <= n; i++) {
    const t = i / n, u = 1 - t;
    pts.push([
      u * u * u * p0[0] + 3 * u * u * t * p1[0] + 3 * u * t * t * p2[0] + t * t * t * p3[0],
      u * u * u * p0[1] + 3 * u * u * t * p1[1] + 3 * u * t * t * p2[1] + t * t * t * p3[1],
    ]);
  }
  return pts;
}
const line = (pts, w = 1.7) => ({ kind: "stroke", pts, w });
const ring = (cx, cy, r, w = 1.7) => ({ kind: "stroke", pts: arc(cx, cy, r, 0, 360, 72), w });
const disc = (cx, cy, r) => ({ kind: "disc", cx, cy, r });
const fill = (pts) => ({ kind: "fill", pts });

// o marcador (gota): arco de cima + duas laterais até a ponta
function teardrop(cx, cy, r, tipY) {
  const a = Math.acos(r / (tipY - cy)) * 180 / Math.PI;   // onde a tangente da ponta toca o círculo
  return [[cx, tipY], ...arc(cx, cy, r, 90 + a, 360 + 90 - a, 60), [cx, tipY]];
}

const ICONS = {
  Search:   [ring(10.5, 10.5, 6.5, 1.9), line([P(15.5, 15.5), P(20.5, 20.5)], 2.1)],
  Close:    [line([P(6, 6), P(18, 18)], 2), line([P(18, 6), P(6, 18)], 2)],
  Filter:   [line([P(4, 7), P(13, 7)]), line([P(17, 7), P(20, 7)]), line([P(4, 17), P(7, 17)]), line([P(11, 17), P(20, 17)]),
             ring(15, 7, 2), ring(9, 17, 2)],
  Maximize: [line([P(4, 9), P(4, 4), P(9, 4)], 1.9), line([P(20, 9), P(20, 4), P(15, 4)], 1.9),
             line([P(4, 15), P(4, 20), P(9, 20)], 1.9), line([P(20, 15), P(20, 20), P(15, 20)], 1.9)],
  Restore:  [line([P(4, 9), P(15, 9), P(15, 20), P(4, 20), P(4, 9)], 1.8), line([P(9, 9), P(9, 4), P(20, 4), P(20, 15), P(15, 15)], 1.8)],
  Center:   [ring(12, 12, 6.5), line([P(12, 2.5), P(12, 6)]), line([P(12, 18), P(12, 21.5)]),
             line([P(2.5, 12), P(6, 12)]), line([P(18, 12), P(21.5, 12)]), disc(12, 12, 1.8)],
  Pin:      [line(teardrop(12, 9.8, 6.5, 21)), fill([P(12, 6.8), P(15, 9.8), P(12, 12.8), P(9, 9.8)])],
  Quill:    [line(cubic(P(20, 3.5), P(13, 3.5), P(7.2, 8.5), P(6.5, 16.5))), line([P(6.5, 16.5), P(4, 20.5)]),
             line(cubic(P(6.5, 16.5), P(13, 16.5), P(18.5, 12), P(20, 3.5))), line([P(9.5, 13.5), P(13.5, 13.5)])],
  Plus:     [line([P(12, 5), P(12, 19)], 2.2), line([P(5, 12), P(19, 12)], 2.2)],
  Minus:    [line([P(5, 12), P(19, 12)], 2.2)],
  Layers:   [line([P(12, 4), P(20, 8), P(12, 12), P(4, 8), P(12, 4)]), line([P(4, 12.5), P(12, 16.5), P(20, 12.5)]),
             line([P(4, 16.5), P(12, 20.5), P(20, 16.5)])],
  Eye:      [line([...arc(12, 19, 11, 220, 320, 30)]), line([...arc(12, 5, 11, 40, 140, 30)]), ring(12, 12, 3)],
  Compass:  [ring(12, 12, 9.5, 1.3), fill([P(12, 3.5), P(14, 12), P(12, 20.5), P(10, 12)]),
             line([P(3.5, 12), P(12, 10), P(20.5, 12), P(12, 14), P(3.5, 12)], 1.2)],
  ChevronDown:  [line([P(7, 10), P(12, 15), P(17, 10)], 2.1)],
  ChevronUp:    [line([P(7, 14), P(12, 9), P(17, 14)], 2.1)],
  ChevronRight: [line([P(10, 7), P(15, 12), P(10, 17)], 2.1)],
  Gem:      [line([P(12, 3), P(20, 9), P(17, 20), P(7, 20), P(4, 9), P(12, 3)]), line([P(4, 9), P(20, 9)]),
             line([P(12, 3), P(9, 9), P(12, 20), P(15, 9), P(12, 3)])],
  Book:     [line([P(5, 4), P(15, 4), ...arc(15, 7, 3, 270, 360, 12).slice(1), P(18, 20), P(8, 20), ...arc(8, 17, 3, 90, 180, 12).slice(1), P(5, 4)]),
             line([...arc(8, 17, 3, 180, 270, 12), P(18, 14)])],
  DiamondLine: [line([P(12, 3.5), P(20.5, 12), P(12, 20.5), P(3.5, 12), P(12, 3.5)], 1.6)],
  // marcadores do mapa (Modules/MapPinSkin.lua): o disco escuro e o aro dourado em volta de cada ícone
  Disc:     [disc(12, 12, 11.4)],
  Rim:      [ring(12, 12, 10.7, 1.4)],
  // o marcador de destino: a gota cheia (fundo escuro) por baixo do contorno "Pin"
  PinFill:  [fill(teardrop(12, 9.8, 7.3, 22))],
  // a seta do jogador no mapa (cheia; a borda escura é a mesma seta, maior, por baixo)
  Arrow:    [fill([P(12, 2.5), P(19.2, 20.5), P(12, 16.3), P(4.8, 20.5)])],
  // diário de missões (Modules/MapJournal.lua)
  Check:    [line([P(5, 12.5), P(10, 17.5), P(19, 7)], 2.2)],
  Star:     [fill([P(12, 3), P(14.4, 9.2), P(21, 9.5), P(15.8, 13.6), P(17.6, 20), P(12, 16.4), P(6.4, 20), P(8.2, 13.6), P(3, 9.5), P(9.6, 9.2)])],
};

// ---------------------------------------------------------------- rasterização (distância, antisserrilhado de 1 px)
function segDist(px, py, a, b) {
  const vx = b[0] - a[0], vy = b[1] - a[1];
  const len2 = vx * vx + vy * vy;
  let t = len2 ? ((px - a[0]) * vx + (py - a[1]) * vy) / len2 : 0;
  t = Math.max(0, Math.min(1, t));
  const dx = px - (a[0] + t * vx), dy = py - (a[1] + t * vy);
  return Math.sqrt(dx * dx + dy * dy);
}
function inside(px, py, pts) {
  let c = false;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i], [xj, yj] = pts[j];
    if ((yi > py) !== (yj > py) && px < (xj - xi) * (py - yi) / (yj - yi) + xi) c = !c;
  }
  return c;
}
function coverage(shape, px, py) {          // px, py em pixels
  if (shape.kind === "disc") {
    const d = Math.hypot(px - shape.cx * S, py - shape.cy * S);
    return clamp01(shape.r * S - d + 0.5);
  }
  const pts = shape.pts.map(([x, y]) => [x * S, y * S]);
  let d = Infinity;
  for (let i = 0; i + 1 < pts.length; i++) d = Math.min(d, segDist(px, py, pts[i], pts[i + 1]));
  if (shape.kind === "fill") {
    if (pts.length > 2) d = Math.min(d, segDist(px, py, pts[pts.length - 1], pts[0]));
    return inside(px, py, pts) ? 1 : clamp01(0.5 - d);
  }
  return clamp01(shape.w * S / 2 - d + 0.5);
}

function writeTGA(file, shapes) {
  const header = Buffer.alloc(18);
  header[2] = 2; header.writeUInt16LE(SIZE, 12); header.writeUInt16LE(SIZE, 14);
  header[16] = 32; header[17] = 8;           // BGRA, origem embaixo à esquerda
  const data = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const px = x + 0.5, py = SIZE - y - 0.5; // (linhas de baixo para cima no TGA)
      let a = 0;
      for (const s of shapes) a = Math.max(a, coverage(s, px, py));
      const i = (y * SIZE + x) * 4;
      data[i] = 255; data[i + 1] = 255; data[i + 2] = 255; data[i + 3] = Math.round(a * 255);
    }
  }
  fs.writeFileSync(path.join(OUT, file), Buffer.concat([header, data]));
}

fs.mkdirSync(OUT, { recursive: true });
for (const [name, shapes] of Object.entries(ICONS)) writeTGA(name + ".tga", shapes);
console.log(`${Object.keys(ICONS).length} ícones em ${OUT}`);
