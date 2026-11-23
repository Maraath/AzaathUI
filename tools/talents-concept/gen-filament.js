// Fio de energia fino para as correntes trançadas do Crisol: miolo claro com
// borda macia e pulsos de brilho ao longo (emenda na horizontal, o jogo faz
// correr). Fios finos não mostram as cunhas das emendas nas curvas.
// Grava sobre o antigo CrucibleRune.tga (sem uso desde o card novo): /reload basta.
// Uso: node tools/talents-concept/gen-filament.js
const path = require("path");
const I = require("../sheet-concept/img");
const W = 256, H = 32;
const im = I.create(W, H);
for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
  const u = i / W, d = Math.abs(j + 0.5 - H / 2) / (H / 2);
  const across = Math.exp(-d * d * 9) + 0.35 * Math.exp(-d * d * 2.2);
  const edge = Math.min(1, (1 - d) * 5);
  // pulsos de energia correndo (frequências inteiras: emenda perfeita)
  const along = 0.55 + 0.25 * Math.sin(2 * Math.PI * 3 * u) + 0.20 * Math.pow(Math.max(0, Math.sin(2 * Math.PI * 2 * u + 1.3)), 6);
  // desenhado OPACO no jogo: os pulsos vão na cor (RGB) e a transparência só
  // na borda; assim a sobreposição nas emendas não acende nem escurece
  const o = (j * W + i) * 4;
  const v = 255 * (0.62 + 0.38 * (along - 0.55) / 0.45);
  im.px[o] = v; im.px[o + 1] = v; im.px[o + 2] = v;
  im.px[o + 3] = 255 * Math.min(1, across * 1.25) * edge;
}
for (const f of [path.join(__dirname, "..", "..", "AzaathUI", "Media", "Talents", "CrucibleRune.tga"),
                 "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Talents/CrucibleRune.tga"])
  I.writeTGA(f, im);
console.log("fio gerado");
