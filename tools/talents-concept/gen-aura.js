// Aura dos medalhões do Crisol: halo macio de borda irregular (lambidas de
// energia), branco para o jogo tingir com a cor da árvore. Grava por cima do
// antigo TalentDiagramGlow.tga (não usado desde o astrolábio): trocar um
// arquivo que já existe vale com /reload, sem reiniciar o cliente.
// Uso: node tools/talents-concept/gen-aura.js
const path = require("path");
const I = require("../sheet-concept/img");
const N = 256, C = N / 2;
const im = I.create(N, N);
for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) {
  const dx = (i + 0.5 - C) / C, dy = (j + 0.5 - C) / C;
  const r = Math.hypot(dx, dy), th = Math.atan2(dy, dx);
  // borda ondulada: frequências inteiras para emendar no ângulo
  const wob = 0.10 * Math.sin(3 * th + 0.7) + 0.07 * Math.sin(5 * th + 2.1) + 0.05 * Math.sin(8 * th + 4.0) + 0.03 * Math.sin(13 * th + 1.3);
  const re = r / (0.62 * (1 + wob));
  let a = Math.exp(-re * re * 2.6);
  // fios mais claros saindo do centro (como as correntes)
  const fil = Math.pow(Math.max(0, Math.sin(7 * th + 3 * r + 0.5)), 6) * 0.25 * Math.exp(-re * re * 1.4);
  a = Math.min(1, a + fil) * Math.min(1, (1 - r) * 6);
  const o = (j * N + i) * 4;
  im.px[o] = 255; im.px[o + 1] = 255; im.px[o + 2] = 255; im.px[o + 3] = 255 * Math.max(0, a);
}
const ws = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Talents", "TalentDiagramGlow.tga");
const game = "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Talents/TalentDiagramGlow.tga";
I.writeTGA(ws, im); I.writeTGA(game, im);
I.writePNG(path.join(__dirname, "preview", "crucible_aura.png"), im);
console.log("aura gerada");
