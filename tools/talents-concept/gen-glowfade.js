// Halo das correntes com transição cruzada: alfa sobe no 1º terço, fica cheio no
// meio e desce no último terço. Trechos vizinhos se sobrepõem exatamente nessas
// rampas (o Lua estica cada trecho 1/4 do comprimento para cada lado), então a
// soma é sempre 100% e as emendas somem. Grava sobre o antigo TalentBtnUndo.tga
// (sem uso desde o astrolábio): trocar arquivo existente vale com /reload.
// Uso: node tools/talents-concept/gen-glowfade.js
const path = require("path");
const I = require("../sheet-concept/img");
const W = 96, H = 64;
const im = I.create(W, H);
for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
  const u = (i + 0.5) / W, d = Math.abs(j + 0.5 - H / 2) / (H / 2);
  const across = Math.exp(-d * d * 5.5) * Math.min(1, (1 - d) * 3);
  const along = Math.min(1, u * 3, (1 - u) * 3); // rampas lineares de 1/3
  const o = (j * W + i) * 4;
  im.px[o] = 255; im.px[o + 1] = 255; im.px[o + 2] = 255; im.px[o + 3] = 255 * across * along;
}
for (const f of [path.join(__dirname, "..", "..", "AzaathUI", "Media", "Talents", "TalentBtnUndo.tga"),
                 "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Talents/TalentBtnUndo.tga"])
  I.writeTGA(f, im);
console.log("halo com transição cruzada gerado");
