// Ícones novos do micromenu (64x64, glifo branco chapado com recortes, no estilo dos que já existem):
//   Drops.tga    = baú de tesouro (aba Drops do Santuário)
//   Dungeons.tga = portal com grade levadiça (aba Masmorras do Santuário)
// Uso: node tools/micromenu-icons/gen.js   (grava em AzaathUI/Media/MicroMenu)
"use strict";
const path = require("path");
const { writeTGA } = require("../map-extract/imagecodec.js");

const OUT = path.join(__dirname, "../../AzaathUI/Media/MicroMenu");
const N = 64, SS = 4; // supersample 4x4 para borda suave

const rect = (x0, y0, x1, y1) => (x, y) => x >= x0 && x <= x1 && y >= y0 && y <= y1;
const circ = (cx, cy, r) => (x, y) => (x - cx) ** 2 + (y - cy) ** 2 <= r * r;
const any = (...fs) => (x, y) => fs.some((f) => f(x, y));
// retângulo com cantos de cima arredondados
const roundTop = (x0, y0, x1, y1, r) => any(rect(x0, y0 + r, x1, y1), rect(x0 + r, y0, x1 - r, y1),
  circ(x0 + r, y0 + r, r), circ(x1 - r, y0 + r, r));

const SHAPES = {
  // baú: tampa arredondada, fenda entre tampa e corpo, faixas e fechadura
  Drops: (x, y) => {
    const lid = roundTop(9, 13, 55, 27, 7);
    const body = rect(9, 31, 55, 53);
    const solid = lid(x, y) || body(x, y);
    if (!solid) return false;
    if (rect(17, 13, 19.5, 53)(x, y) || rect(44.5, 13, 47, 53)(x, y)) return false; // faixas
    const plate = rect(26, 22, 38, 41);
    if (plate(x, y)) {
      // placa da fechadura recortada, com o cadeado sólido e o buraco da chave
      const lock = rect(28.5, 25.5, 35.5, 38.5)(x, y);
      const hole = circ(32, 30.5, 2)(x, y) || rect(31.2, 30.5, 32.8, 35.5)(x, y);
      return lock && !hole;
    }
    return true;
  },
  // portal em arco com a grade levadiça descida até a metade
  Dungeons: (x, y) => {
    const outer = any(rect(10, 27, 54, 55), circ(32, 27, 22));
    if (!outer(x, y) || y > 55) return false;
    const opening = any(rect(19, 31, 45, 55), circ(32, 31, 13));
    if (!opening(x, y)) return true;
    // dentro da abertura: só as barras da grade (até y=44) e as pontas
    const bars = [24, 30.5, 37, 43.5].some((bx) => x >= bx - 1.4 && x <= bx + 1.4 && y <= 44);
    const cross = y >= 33 && y <= 35.6;
    const tips = [24, 30.5, 37, 43.5].some((bx) => y > 44 && y <= 48 && Math.abs(x - bx) <= 1.4 * (48 - y) / 4);
    return bars || (cross && y <= 44) || tips;
  },
};

for (const [name, fn] of Object.entries(SHAPES)) {
  const data = Buffer.alloc(N * N * 4);
  for (let y = 0; y < N; y++) for (let x = 0; x < N; x++) {
    let hit = 0;
    for (let sy = 0; sy < SS; sy++) for (let sx = 0; sx < SS; sx++) {
      if (fn(x + (sx + 0.5) / SS, y + (sy + 0.5) / SS)) hit++;
    }
    const i = (y * N + x) * 4;
    data[i] = data[i + 1] = data[i + 2] = 255;
    data[i + 3] = Math.round(255 * hit / (SS * SS));
  }
  writeTGA(path.join(OUT, name + ".tga"), { w: N, h: N, data }, true);
  console.log("gravado", name + ".tga");
}
