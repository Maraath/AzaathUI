// Moldura de energia dos medalhões do Crisol: fios trançados em volta do ícone,
// como as correntes (branco, o jogo tinge com a cor da árvore e gira).
// Raio do anel = 80px na textura de 256 (metade = 128).
// Grava por cima do antigo TalentRings.tga (não usado): vale com /reload.
// Uso: node tools/talents-concept/gen-ring.js
const path = require("path");
const I = require("../sheet-concept/img");
const N = 256, C = N / 2, R = 80;
const strands = [
  { amp: 3.5, k: 3, ph: 0.0, w: 1.5, b: 1.0 },
  { amp: 3.0, k: 4, ph: 2.1, w: 1.2, b: 0.9 },
  { amp: 4.5, k: 2, ph: 3.7, w: 1.0, b: 0.8 },
  { amp: 2.5, k: 5, ph: 1.2, w: 1.0, b: 0.75 },
  { amp: 5.0, k: 3, ph: 4.9, w: 0.8, b: 0.55 },
];
const im = I.create(N, N);
for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) {
  const dx = i + 0.5 - C, dy = j + 0.5 - C;
  const r = Math.hypot(dx, dy), th = Math.atan2(dy, dx);
  let v = 0;
  for (const s of strands) {
    const rc = R + s.amp * Math.sin(s.k * th + s.ph) + 1.2 * Math.sin((s.k + 4) * th + s.ph * 2);
    const pulse = 0.6 + 0.4 * Math.sin((s.k + 1) * th + s.ph * 1.7);
    const d = r - rc;
    v += (Math.exp(-(d * d) / (2 * s.w * s.w)) + Math.exp(-(d * d) / (2 * 25 * s.w * s.w)) * 0.35) * s.b * pulse;
  }
  // halo largo e suave dos dois lados do anel
  const dh = r - R;
  v += Math.exp(-(dh * dh) / (2 * 14 * 14)) * 0.22;
  const a = Math.min(1, v * 1.1) * Math.min(1, (C - r) / 6);
  const o = (j * N + i) * 4;
  im.px[o] = 255; im.px[o + 1] = 255; im.px[o + 2] = 255; im.px[o + 3] = 255 * Math.max(0, a);
}
const ws = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Talents", "TalentRings.tga");
const game = "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Talents/TalentRings.tga";
I.writeTGA(ws, im); I.writeTGA(game, im);
// prévia sobre fundo escuro, tingida de ciano
const pv = I.create(N, N, 8, 14, 24, 255);
for (let p = 0; p < N * N; p++) { const a = im.px[p * 4 + 3] / 255; pv.px[p * 4] += 80 * a; pv.px[p * 4 + 1] += 220 * a; pv.px[p * 4 + 2] += 255 * a; }
I.writePNG(path.join(__dirname, "preview", "crucible_energyring.png"), pv);
console.log("moldura de energia gerada");
