// Ícones minimalistas estilo Black Desert para o Micro Menu (Modules/MicroMenu.lua).
// Traço vetorial em grade 24x24 rasterizado em TGA 64x64 branco + alpha (tinta via SetVertexColor).
// Saída: AzaathUI/Media/MicroMenu/<Nome>.tga.  Uso: node tools/media/generate-micromenu-media.js
"use strict";
const fs = require("fs");
const path = require("path");

const SIZE = 64;
const S = SIZE / 24;
const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "MicroMenu");
const clamp01 = (v) => Math.max(0, Math.min(1, v));

const P = (x, y) => [x, y];
function arc(cx, cy, r, a0, a1, n = 48) {
  const pts = [];
  for (let i = 0; i <= n; i++) {
    const a = (a0 + (a1 - a0) * i / n) * Math.PI / 180;
    pts.push([cx + r * Math.cos(a), cy + r * Math.sin(a)]);
  }
  return pts;
}

const line = (pts, w = 1.7) => ({ kind: "stroke", pts, w });
const ring = (cx, cy, r, w = 1.7) => ({ kind: "stroke", pts: arc(cx, cy, r, 0, 360, 72), w });
const disc = (cx, cy, r) => ({ kind: "disc", cx, cy, r });
const fill = (pts) => ({ kind: "fill", pts });
const subDisc = (cx, cy, r) => ({ kind: "disc", cx, cy, r, sub: true });
const subLine = (pts, w = 1.6) => ({ kind: "stroke", pts, w, sub: true });
const subFill = (pts) => ({ kind: "fill", pts, sub: true });
const radial = (cx, cy, rInner, rOuter) => ({ kind: "radial", cx, cy, rInner, rOuter });

// Dentes de engrenagem para o ícone de Menu
function gearShape(cx, cy, rIn, rOut, teeth) {
  const pts = [];
  const step = (Math.PI * 2) / teeth;
  for (let i = 0; i < teeth; i++) {
    const a0 = i * step;
    const a1 = a0 + step * 0.22;
    const a2 = a0 + step * 0.32;
    const a3 = a0 + step * 0.68;
    const a4 = a0 + step * 0.78;
    pts.push([cx + rIn * Math.cos(a0), cy + rIn * Math.sin(a0)]);
    pts.push([cx + rIn * Math.cos(a1), cy + rIn * Math.sin(a1)]);
    pts.push([cx + rOut * Math.cos(a2), cy + rOut * Math.sin(a2)]);
    pts.push([cx + rOut * Math.cos(a3), cy + rOut * Math.sin(a3)]);
    pts.push([cx + rIn * Math.cos(a4), cy + rIn * Math.sin(a4)]);
  }
  return pts;
}

const ICONS = {
  // 1. Personagem: silhueta de peitoral/armadura estilo BDO
  Character: [
    fill([
      P(6.5, 4.5), P(9.2, 4.5), P(10.2, 6.4), P(13.8, 6.4), P(14.8, 4.5), P(17.5, 4.5),
      P(20.5, 8.2), P(18.5, 11.4), P(16.6, 10.2), P(16.2, 19.5), P(7.8, 19.5), P(7.4, 10.2),
      P(5.5, 11.4), P(3.5, 8.2),
    ]),
    subLine([P(12, 7.5), P(12, 18.0)], 1.2),
    subLine([P(8.8, 12.2), P(15.2, 12.2)], 1.1),
  ],

  // 2. Livro de Feitiços: grimório fechado com losango arcano recortado
  Spellbook: [
    fill([P(5.5, 3.8), P(18.5, 3.8), P(18.5, 20.2), P(5.5, 20.2)]),
    subLine([P(8.2, 3.8), P(8.2, 20.2)], 1.3),
    subFill([P(13.4, 8.0), P(15.9, 11.5), P(13.4, 15.0), P(10.9, 11.5)]),
    subLine([P(7.8, 18.2), P(17.5, 18.2)], 1.1),
  ],

  // 3. Talentos: constelação de 3 nós conectados
  Talents: [
    line([P(12, 6.2), P(6.5, 16.8)], 1.7),
    line([P(12, 6.2), P(17.5, 16.8)], 1.7),
    line([P(6.5, 16.8), P(17.5, 16.8)], 1.5),
    disc(12, 6.2, 3.0),
    disc(6.5, 16.8, 2.5),
    disc(17.5, 16.8, 2.5),
    subDisc(12, 6.2, 1.1),
  ],

  // 4. Conquistas: cálice/troféu estilizado
  Achievements: [
    fill([P(7.0, 4.5), P(17.0, 4.5), P(15.8, 11.5), P(13.3, 13.8), P(10.7, 13.8), P(8.2, 11.5)]),
    line([P(7.2, 6.2), P(4.8, 6.2), P(4.8, 9.6), P(7.8, 10.6)], 1.5),
    line([P(16.8, 6.2), P(19.2, 6.2), P(19.2, 9.6), P(16.2, 10.6)], 1.5),
    line([P(12, 13.5), P(12, 17.8)], 2.2),
    fill([P(7.8, 17.5), P(16.2, 17.5), P(17.0, 19.8), P(7.0, 19.8)]),
  ],

  // 5. Missões: pergaminho limpo com linhas de texto recortadas
  Quests: [
    fill([P(6.0, 4.0), P(15.5, 4.0), P(18.5, 7.0), P(18.5, 20.0), P(6.0, 20.0)]),
    subLine([P(15.2, 4.0), P(15.2, 7.2), P(18.5, 7.2)], 1.2),
    subLine([P(8.6, 9.8), P(15.6, 9.8)], 1.4),
    subLine([P(8.6, 13.0), P(15.6, 13.0)], 1.4),
    subLine([P(8.6, 16.2), P(13.4, 16.2)], 1.4),
  ],

  // 6. Mapa-Múndi: mapa dobrado em 3 painéis com pino central
  Map: [
    fill([
      P(3.8, 5.8), P(9.2, 4.0), P(14.8, 6.0), P(20.2, 4.2),
      P(20.2, 18.2), P(14.8, 20.0), P(9.2, 18.0), P(3.8, 19.8),
    ]),
    subLine([P(9.2, 4.0), P(9.2, 18.0)], 1.2),
    subLine([P(14.8, 6.0), P(14.8, 20.0)], 1.2),
    subDisc(12.0, 11.4, 2.0),
  ],

  // 7. Social & Amigos: duas silhuetas humanas
  Social: [
    disc(9.5, 7.8, 2.7),
    fill([P(4.2, 18.8), ...arc(9.5, 17.8, 5.2, 190, 350, 24), P(14.8, 18.8)]),
    disc(15.5, 8.6, 2.2),
    fill([P(13.8, 18.8), ...arc(15.5, 18.2, 4.2, 240, 355, 20), P(19.8, 18.8)]),
  ],

  // 8. Guilda: escudo heráldico com chevron recortado
  Guild: [
    fill([P(12, 3.6), P(19.0, 6.0), P(18.2, 13.6), P(12, 20.4), P(5.8, 13.6), P(5.0, 6.0)]),
    subLine([P(8.5, 10.5), P(12, 13.8), P(15.5, 10.5)], 1.5),
    subLine([P(12, 6.8), P(12, 16.5)], 1.3),
  ],

  // 9. Masmorras & JxJ: espada e machado cruzados (inspirado no BDO)
  GroupFinder: [
    // Espada (canto inferior esquerdo ao superior direito)
    line([P(4.8, 19.2), P(18.6, 5.4)], 2.0),
    line([P(6.0, 14.4), P(9.6, 18.0)], 1.7),
    // Machado (canto inferior direito ao superior esquerdo)
    line([P(19.2, 19.2), P(6.5, 6.5)], 2.0),
    fill([P(5.2, 4.4), P(10.2, 4.8), P(8.2, 9.2), P(4.4, 7.8)]),
  ],

  // 10. Coleções & Montarias: silhueta estilizada de cavalo/montaria
  Collections: [
    fill([
      P(6.5, 19.5), P(7.2, 13.5), P(5.2, 11.2), P(7.8, 6.4), P(10.5, 4.0),
      P(12.2, 5.8), P(16.8, 7.2), P(18.4, 10.2), P(15.6, 11.8), P(13.2, 10.6),
      P(14.5, 14.5), P(16.5, 19.5),
    ]),
    subDisc(12.6, 7.6, 0.9),
  ],

  // 11. Ajuda & Suporte: balão de diálogo com "?" recortado
  Help: [
    fill([
      P(5.5, 4.5), P(18.5, 4.5), P(19.5, 5.5), P(19.5, 15.8),
      P(18.5, 16.8), P(10.2, 16.8), P(6.4, 20.2), P(7.2, 16.8),
      P(5.5, 16.8), P(4.5, 15.8), P(4.5, 5.5),
    ]),
    subLine([...arc(12, 9.2, 2.2, 180, 395, 24), P(12, 12.2)], 1.6),
    subDisc(12, 14.3, 0.95),
  ],

  // 12. Menu do Jogo: engrenagem mecânica (idêntica à do BDO)
  Menu: [
    fill(gearShape(12, 12, 7.2, 9.8, 8)),
    subDisc(12, 12, 3.6),
  ],

  // Botão losango BDO (recolher / expandir)
  ToggleClose: [
    line([P(7.5, 7.5), P(16.5, 16.5)], 2.1),
    line([P(16.5, 7.5), P(7.5, 16.5)], 2.1),
  ],
  ToggleOpen: [
    line([P(14.5, 6.5), P(9.0, 12.0), P(14.5, 17.5)], 2.2),
  ],

  // Fundos e molduras
  Disc: [disc(12, 12, 11.2)],
  Glow: [radial(12, 12, 2.0, 11.8)],
  Diamond: [fill([P(12, 1.5), P(22.5, 12), P(12, 22.5), P(1.5, 12)])],
  DiamondBorder: [line([P(12, 2.0), P(22.0, 12), P(12, 22.0), P(2.0, 12), P(12, 2.0)], 1.4)],
  Badge: [disc(12, 12, 11.0)],
};

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

function coverage(shape, px, py) {
  if (shape.kind === "radial") {
    const d = Math.hypot(px - shape.cx * S, py - shape.cy * S);
    const t = clamp01((d - shape.rInner * S) / ((shape.rOuter - shape.rInner) * S));
    return Math.pow(1 - t, 1.8);
  }
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
  header[16] = 32; header[17] = 8;
  const data = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const px = x + 0.5, py = SIZE - y - 0.5;
      let a = 0;
      for (const s of shapes) {
        const cov = coverage(s, px, py);
        if (s.sub) a = Math.max(0, a * (1 - cov));
        else a = Math.max(a, cov);
      }
      const i = (y * SIZE + x) * 4;
      data[i] = 255; data[i + 1] = 255; data[i + 2] = 255; data[i + 3] = Math.round(clamp01(a) * 255);
    }
  }
  fs.writeFileSync(path.join(OUT, file), Buffer.concat([header, data]));
}

fs.mkdirSync(OUT, { recursive: true });
for (const [name, shapes] of Object.entries(ICONS)) writeTGA(name + ".tga", shapes);
console.log(`${Object.keys(ICONS).length} ícones gerados em ${OUT}`);
