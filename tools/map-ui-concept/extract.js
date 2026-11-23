// Recorta da própria arte de conceito (concept.png, 1376x768) os ícones do estandarte e o cristal
// Azaath do canto superior esquerdo, tirando o fundo escuro, para ficarem idênticos à arte.
//   · ícones do menu: em tons de branco (o jogo tinge: ativo ciano, os outros prata);
//     alfa = quanto o pixel é mais claro que o fundo do estandarte
//   · cristal: com as cores da arte (alfa pelo brilho acima do fundo da barra; cor sem o fundo)
// Grava Media/MapFrame/<nome>.tga no projeto e na pasta do jogo (2x, suavizado).
//   node tools/map-ui-concept/extract.js   (gerar concept.png antes: ffmpeg -i concept.webp concept.png)
"use strict";
const path = require("path");
const fs = require("fs");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const DIR = __dirname;
const ROOT = path.resolve(DIR, "../..");
const OUTS = [path.join(ROOT, "AzaathUI/Media/MapFrame"),
  "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame"];
const art = readPNG(path.join(DIR, "concept.png"));
const px = (x, y) => { const o = (y * art.w + x) * 4; return [art.px[o], art.px[o + 1], art.px[o + 2]]; };
const lum = (c) => 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2];
const clamp = (v) => Math.max(0, Math.min(1, v));
const sm = (t) => { t = clamp(t); return t * t * (3 - 2 * t); };

function save(name, img) {
  for (const d of OUTS) { fs.mkdirSync(d, { recursive: true }); I.writeTGA(path.join(d, name + ".tga"), img); }
  I.writePNG(path.join(DIR, "crops", "x_" + name + ".png"), img);
}

// ícone branco: cx, cy = centro na arte; s = lado do recorte; t0..t1 = brilho do fundo ao traço
function whiteIcon(name, cx, cy, s, t0, t1) {
  const out = I.create(s, s, 255, 255, 255, 0);
  for (let y = 0; y < s; y++) for (let x = 0; x < s; x++) {
    const c = px(Math.round(cx - s / 2 + x), Math.round(cy - s / 2 + y));
    const a = sm((lum(c) - t0) / (t1 - t0));
    const o = (y * s + x) * 4;
    const g = 200 + 55 * a;                    // um pouco de volume: o claro mais branco
    out.px[o] = g; out.px[o + 1] = g; out.px[o + 2] = g; out.px[o + 3] = a * 255;
  }
  save(name, I.resize(out, s * 2, s * 2));
}

// cristal colorido sobre fundo escuro: alfa pelo brilho acima do fundo; cor "desmisturada" do fundo
function colorIcon(name, x0, y0, w, h) {
  // fundo: a mediana da borda do recorte
  const border = [];
  for (let x = 0; x < w; x++) { border.push(px(x0 + x, y0), px(x0 + x, y0 + h - 1)); }
  for (let y = 0; y < h; y++) { border.push(px(x0, y0 + y), px(x0 + w - 1, y0 + y)); }
  const med = (k) => border.map((c) => c[k]).sort((a, b) => a - b)[Math.floor(border.length / 2)];
  const bg = [med(0), med(1), med(2)];
  const out = I.create(w, h, 0, 0, 0, 0);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const c = px(x0 + x, y0 + y);
    const d = Math.max(c[0] - bg[0], c[1] - bg[1], c[2] - bg[2]);
    const a = sm(d / 70);
    const o = (y * w + x) * 4;
    for (let k = 0; k < 3; k++) out.px[o + k] = a > 0.02 ? Math.min(255, bg[k] + (c[k] - bg[k]) / a) : c[k];
    out.px[o + 3] = a * 255;
  }
  console.log(name, "fundo", bg.join(","));
  save(name, I.resize(out, w * 2, h * 2));
}

// estandarte (fundo ~ 14,19,23): posições medidas na arte
whiteIcon("RIcoQuests", 30, 161, 36, 95, 190);     // a crista (na arte, o item ativo: fundo com brilho ciano)
whiteIcon("RIcoPlaces", 30, 215, 34, 40, 120);     // espadas cruzadas
whiteIcon("RIcoGather", 30, 273, 34, 40, 120);     // pergaminho
whiteIcon("RIcoSettings", 30, 332, 34, 40, 120);   // elmo no anel
whiteIcon("RIcoCenter", 31, 511, 34, 40, 120);     // seta de rota
// o cristal Azaath da barra superior
colorIcon("Emblem", 14, 1, 44, 44);
console.log("pronto");
