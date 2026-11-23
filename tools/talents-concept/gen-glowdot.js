// Ponto de luz macio (gaussiano) para "carimbar" o halo das correntes ao longo
// da curva: redondo, sem cantos, então curvas fechadas não soltam feixes retos.
// Grava sobre o antigo TalentBtnImbuir.tga (sem uso): vale com /reload.
// Uso: node tools/talents-concept/gen-glowdot.js
const path = require("path");
const I = require("../sheet-concept/img");
const N = 128, C = N / 2;
const im = I.create(N, N);
for (let j = 0; j < N; j++) for (let i = 0; i < N; i++) {
  const d = Math.hypot(i + 0.5 - C, j + 0.5 - C) / C;
  const a = Math.exp(-d * d * 5.5) * Math.min(1, (1 - d) * 4);
  const o = (j * N + i) * 4;
  im.px[o] = 255; im.px[o + 1] = 255; im.px[o + 2] = 255; im.px[o + 3] = 255 * Math.max(0, a);
}
for (const f of [path.join(__dirname, "..", "..", "AzaathUI", "Media", "Talents", "TalentBtnImbuir.tga"),
                 "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Talents/TalentBtnImbuir.tga"])
  I.writeTGA(f, im);
console.log("ponto de luz gerado");
