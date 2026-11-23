// Gera Media/BDO/RareSilver.tga e RareGold.tga (lâminas do alvo Zerker para raro/elite).
// O desenho fica em rare-blades.ps1 (GDI+); aqui só reduz 512 -> 256 e grava TGA.
// Uso: node tools/bdo-hud-concept/rare-blades.js
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");
const { execFileSync } = require("child_process");
const { readPNG } = require("../grimoire-concept/png");
const C = require("../map-extract/imagecodec");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "BDO");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "rare-blades-"));
execFileSync("powershell", ["-NoProfile", "-File", path.join(__dirname, "rare-blades.ps1"), tmp], { stdio: "inherit" });
// RareTri*: contorno do triângulo do nível das placas da skin Azaath (vai para Media/Target)
const TARGET = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Target");
for (const k of ["Silver", "Gold"]) {
  for (const [name, dir] of [["Rare" + k, OUT], ["RareTri" + k, TARGET]]) {
    const p = readPNG(path.join(tmp, name + ".png"));
    const img = C.makeImage(p.w, p.h);
    for (let i = 0; i < p.px.length; i++) img.data[i] = p.px[i];
    const out = C.halve(img);
    C.writeTGA(path.join(dir, name + ".tga"), out);
    console.log(name + ".tga", out.w + "x" + out.h);
  }
}
{
  const p = readPNG(path.join(tmp, "TargetOutline.png"));
  const img = C.makeImage(p.w, p.h);
  for (let i = 0; i < p.px.length; i++) img.data[i] = p.px[i];
  const out = C.halve(img);
  C.writeTGA(path.join(OUT, "TargetOutline.tga"), out);
  console.log("TargetOutline.tga", out.w + "x" + out.h);
}
// (PlateFill / PlateFillNeutral saem de plate-fill.js, com a arte líquida da vida)
for (const name of ["PlateTrack"]) {
  const p = readPNG(path.join(tmp, name + ".png"));
  const img = C.makeImage(p.w, p.h);
  for (let i = 0; i < p.px.length; i++) img.data[i] = p.px[i];
  const out = C.halve(C.halve(img));
  C.writeTGA(path.join(OUT, name + ".tga"), out);
  console.log(name + ".tga", out.w + "x" + out.h);
}
fs.rmSync(tmp, { recursive: true, force: true });
