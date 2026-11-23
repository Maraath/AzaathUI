// Textura de energia da barra de criação (CraftFlow.tga, 256x32, repete sem
// emenda na horizontal): filetes luminosos de ruído "ridged" periódico, brancos
// (a cor vem do SetVertexColor no jogo) e com queda suave em cima/embaixo.
//   node tools/crafting-concept/gen-flow.js
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");

const W = 256, H = 32;
const ROOT = path.join(__dirname, "..", "..");
const OUTS = [path.join(ROOT, "AzaathUI", "Media", "Sheet"),
  "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Sheet"];

// fios de energia: cada fio é uma senoide com frequências inteiras (repete
// exatamente a cada 256 px), brilho gaussiano em volta e pulsos ao longo dele
const TAU = Math.PI * 2;
let seed = 9137;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const strands = [];
for (let k = 0; k < 7; k++) strands.push({
  f1: 1 + Math.floor(rnd() * 3), f2: 2 + Math.floor(rnd() * 4), p1: rnd() * TAU, p2: rnd() * TAU,
  a1: 4 + rnd() * 6, a2: 1 + rnd() * 3, w: 0.8 + rnd() * 1.6, b: 0.45 + rnd() * 0.55,
  h: 2 + Math.floor(rnd() * 5), ph: rnd() * TAU,
});
const img = I.create(W, H);
for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
  const u = x / W;
  let v = 0;
  for (const st of strands) {
    const cy = H / 2 + st.a1 * Math.sin(TAU * st.f1 * u + st.p1) + st.a2 * Math.sin(TAU * st.f2 * u + st.p2);
    const d = (y + 0.5 - cy) / st.w;
    const pulse = 0.55 + 0.45 * Math.sin(TAU * st.h * u + st.ph);
    v += Math.exp(-d * d) * st.b * pulse + Math.exp(-d * d / 16) * 0.10 * st.b;
  }
  const edge = Math.pow(Math.sin(Math.PI * (y + 0.5) / H), 0.7);
  const a = Math.min(1, v * edge);
  const k = (y * W + x) * 4;
  img.px[k] = 255; img.px[k + 1] = 255; img.px[k + 2] = 255; img.px[k + 3] = a * 255;
}
for (const dir of OUTS) { try { I.writeTGA(path.join(dir, "CraftFlow.tga"), img); } catch (e) { console.log("sem acesso:", dir); } }
// prévia (pré-multiplicada sobre preto, para o canvas em modo "lighter")
const pv = I.create(W, H, 0, 0, 0, 255);
for (let i = 0; i < W * H; i++) { const a = img.px[i * 4 + 3] / 255; for (let k = 0; k < 3; k++) pv.px[i * 4 + k] = 255 * a; }
fs.mkdirSync(path.join(__dirname, "fx"), { recursive: true });
I.writePNG(path.join(__dirname, "fx", "CraftFlow.png"), pv);
console.log("CraftFlow.tga", W + "x" + H);
