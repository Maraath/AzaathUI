// Filete suave das áreas das missões (Modules/WorldMap.lua, LayHull): cada aresta do polígono é um
// quadrilátero dobrado cujo lado de CIMA da textura fica na borda de fora e o de BAIXO na de dentro.
// Esta textura tem, na altura, o perfil do filete: transparente fora (borda sem serrilhado), forte um
// pouco para dentro e descendo até a opacidade do véu (RIM_TO_FILL), para emendar sem degrau.
//   node tools/map-ui-concept/rim.js   -> Media/MapFrame/AreaRim.tga
"use strict";
const path = require("path");
const fs = require("fs");
const I = require("../sheet-concept/img");

const ROOT = path.resolve(__dirname, "../..");
const OUTS = [path.join(ROOT, "AzaathUI/Media/MapFrame"),
  "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame"];
const H = 32, W = 4;
const RIM_TO_FILL = 0.24;     // a opacidade do véu dividida pela do filete (WorldMap: HULL.fill / HULL.rim)
const sm = (t) => { t = Math.max(0, Math.min(1, t)); return t * t * (3 - 2 * t); };
const img = I.create(W, H, 255, 255, 255, 0);
for (let y = 0; y < H; y++) {
  const t = (y + 0.5) / H;               // 0 = borda de fora, 1 = borda de dentro
  let a;
  if (t < 0.38) a = sm(t / 0.38);                                        // sobe suave até o pico
  else a = RIM_TO_FILL + (1 - RIM_TO_FILL) * (1 - sm((t - 0.38) / 0.62)); // desce até o véu
  for (let x = 0; x < W; x++) img.px[(y * W + x) * 4 + 3] = a * 255;
}
for (const d of OUTS) { fs.mkdirSync(d, { recursive: true }); I.writeTGA(path.join(d, "AreaRim.tga"), img); }
console.log("AreaRim.tga gravada");
