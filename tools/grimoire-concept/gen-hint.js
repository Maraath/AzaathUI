// Gera Media/Grimoire/GrimHint.tga: a frase "Arraste a runa do livro..." curvada
// sobre a folha da página direita (letra a letra, girada pela inclinação da curva
// medida na arte), em 4x para ficar nítida.
// Uso: node tools/grimoire-concept/gen-hint.js   (precisa do Microsoft Edge)
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const I = require("../sheet-concept/img");
const { readPNG } = require("./png");

const EDGE = "C:\\Program Files (x86)\\Microsoft\\Edge\\Application\\msedge.exe";
const shot = path.join(__dirname, "preview", "hint-raw.png");
const page = "file:///" + path.join(__dirname, "hint.html").replace(/\\/g, "/");
spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
  "--allow-file-access-from-files", "--user-data-dir=" + path.join(process.env.TEMP || ".", "azaath-edge"),
  "--window-size=1200,128", "--virtual-time-budget=5000", "--screenshot=" + shot, page], { stdio: "ignore" });

const src = readPNG(shot);
const INK = [41, 28, 20];
const out = I.create(2048, 128);
for (let y = 0; y < 128; y++) for (let x = 0; x < 1200; x++) {
  const q = (y * src.w + x) * 4, o = (y * 2048 + x) * 4;
  const a = (src.px[q] + src.px[q + 1] + src.px[q + 2]) / 3;
  out.px[o] = INK[0]; out.px[o + 1] = INK[1]; out.px[o + 2] = INK[2]; out.px[o + 3] = a;
}
I.writeTGA(path.join(__dirname, "..", "..", "AzaathUI", "Media", "Grimoire", "GrimHint.tga"), out);
console.log("gerado GrimHint 2048x128 (frase em 1200x128)");
