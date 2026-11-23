// Texturas da Opção 2 das barras de ação (referência: octógonos com filete dourado, abas de tecla
// inclinadas): SplitSlotBg (fundo escuro do octógono), SplitSlot (moldura) e SplitKeyTab (aba da tecla).
// SVG -> Edge sem janela -> Media/ActionBar/<nome>.tga (projeto e pasta do jogo).
// Uso: node tools/split-bar-concept/gen.js
"use strict";
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const ROOT = path.resolve(__dirname, "../..");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const OUTS = [path.join(ROOT, "AzaathUI/Media/ActionBar"),
  "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/ActionBar"];
const SCALE = 2;
const oct = (w, i) => { // octógono de lado w, recuado i, com cantos cortados em 17%
  const c = w * 0.17, a = i, b = w - i;
  return `${a + c},${a} ${b - c},${a} ${b},${a + c} ${b},${b - c} ${b - c},${b} ${a + c},${b} ${a},${b - c} ${a},${a + c}`;
};
const DEFS = `<defs>
<linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f1d894"/><stop offset="0.5" stop-color="#b4893c"/><stop offset="1" stop-color="#6f5222"/></linearGradient>
<linearGradient id="silver" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#f2f5f7"/><stop offset="0.5" stop-color="#aab3ba"/><stop offset="1" stop-color="#5d666e"/></linearGradient>
<linearGradient id="band" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#8a979c" stop-opacity="0.3"/><stop offset="1" stop-color="#3a454a" stop-opacity="0.07"/></linearGradient>
<linearGradient id="glass" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff" stop-opacity="0.85"/><stop offset="0.45" stop-color="#cfd8de" stop-opacity="0.2"/><stop offset="1" stop-color="#ffffff" stop-opacity="0.5"/></linearGradient>
<linearGradient id="sheen" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#ffffff" stop-opacity="0.2"/><stop offset="0.5" stop-color="#ffffff" stop-opacity="0"/></linearGradient>
<linearGradient id="tab" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1a1f25"/><stop offset="1" stop-color="#090b0e"/></linearGradient>
<linearGradient id="tabEdge" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#b9bec3" stop-opacity="0.8"/><stop offset="1" stop-color="#5e6368" stop-opacity="0.5"/></linearGradient>
<linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#1a1f25"/><stop offset="1" stop-color="#090b0e"/></linearGradient>
</defs>`;
const svg = (w, h, body) => `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg">${DEFS}${body}</svg>`;
const SL = 48;
const PIECES = [
  { name: "SplitSlotBg", x: 3, y: 3, w: SL, h: SL, body: `<polygon points="${oct(SL, 1)}" fill="url(#bg)" opacity="0.94"/>` },
  { name: "SplitSlot", x: 57, y: 3, w: SL, h: SL, body:
    `<polygon points="${oct(SL, 0.7)}" fill="none" stroke="#05070a" stroke-width="2.4" stroke-linejoin="round"/>
<polygon points="${oct(SL, 1.6)}" fill="none" stroke="url(#silver)" stroke-width="1.4" stroke-linejoin="round"/>
<polygon points="${oct(SL, 3.6)}" fill="none" stroke="url(#glass)" stroke-width="2.4" stroke-linejoin="round"/>
<polygon points="${oct(SL, 5.2)}" fill="none" stroke="#000" stroke-opacity="0.55" stroke-width="1.2" stroke-linejoin="round"/>
<polygon points="${oct(SL, 5.6)}" fill="url(#sheen)"/>` },
  { name: "SplitKeyTab", x: 3, y: 57, w: 64, h: 15, body:
    `<polygon points="8,0.5 63.5,0.5 55.5,14.5 0.5,14.5" fill="url(#tab)" fill-opacity="0.94" stroke="url(#tabEdge)" stroke-width="1" stroke-linejoin="round"/>` },
  { name: "SplitBandMid", x: 3, y: 80, w: 16, h: 64, body:
    `<rect x="0" y="0" width="16" height="64" fill="url(#band)"/><rect x="0" y="0" width="16" height="1.2" fill="#b4bec3" fill-opacity="0.3"/><rect x="0" y="62.8" width="16" height="1.2" fill="#000" fill-opacity="0.15"/>` },
  { name: "SplitBandSlantA", x: 30, y: 80, w: 24, h: 64, body:
    `<polygon points="0,0 24,0 14,64 0,64" fill="url(#band)"/><rect x="0" y="0" width="24" height="1.2" fill="#b4bec3" fill-opacity="0.3"/><rect x="0" y="62.8" width="14" height="1.2" fill="#000" fill-opacity="0.15"/><line x1="24" y1="0" x2="14" y2="64" stroke="#b4bec3" stroke-opacity="0.28" stroke-width="1.2"/>` },
  { name: "SplitBandSlantB", x: 62, y: 80, w: 24, h: 64, body:
    `<polygon points="10,0 24,0 24,64 0,64" fill="url(#band)"/><rect x="10" y="0" width="14" height="1.2" fill="#b4bec3" fill-opacity="0.3"/><rect x="0" y="62.8" width="24" height="1.2" fill="#000" fill-opacity="0.15"/><line x1="10" y1="0" x2="0" y2="64" stroke="#b4bec3" stroke-opacity="0.28" stroke-width="1.2"/>` },
  { name: "SplitBandFade", x: 92, y: 80, w: 48, h: 64, body:
    `<defs><linearGradient id="ramp" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#000"/><stop offset="1" stop-color="#fff"/></linearGradient>
<mask id="fm" maskUnits="userSpaceOnUse" x="0" y="0" width="48" height="64"><rect x="0" y="0" width="48" height="64" fill="url(#ramp)"/></mask></defs>
<g mask="url(#fm)"><rect x="0" y="0" width="48" height="64" fill="url(#band)"/><rect x="0" y="0" width="48" height="1.2" fill="#b4bec3" fill-opacity="0.3"/><rect x="0" y="62.8" width="48" height="1.2" fill="#000" fill-opacity="0.15"/></g>` },
];
const PAGE_W = 150, PAGE_H = 150;
const html = `<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:transparent;overflow:hidden}
.p{position:absolute}</style></head><body>${PIECES.map((p) =>
  `<div class="p" style="left:${p.x}px;top:${p.y}px;width:${p.w}px;height:${p.h}px">${svg(p.w, p.h, p.body)}</div>`).join("")}</body></html>`;
const DIR = __dirname;
const htmlFile = path.join(DIR, "pieces.html"), pngFile = path.join(DIR, "pieces.png");
fs.writeFileSync(htmlFile, html);
if (fs.existsSync(pngFile)) fs.unlinkSync(pngFile);
const profile = path.join(require("os").tmpdir(), "azaath_edge_" + Date.now());
spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--user-data-dir=" + profile, "--no-first-run", "--hide-scrollbars",
  "--default-background-color=00000000", "--force-device-scale-factor=" + SCALE, "--window-size=" + PAGE_W + "," + PAGE_H,
  "--virtual-time-budget=2000", "--allow-file-access-from-files", "--screenshot=" + pngFile,
  "file:///" + htmlFile.split(String.fromCharCode(92)).join("/")], { stdio: "ignore" });
{
  const t0 = Date.now();
  let last = -1;
  while (Date.now() - t0 < 30000) {
    const sz = fs.existsSync(pngFile) ? fs.statSync(pngFile).size : 0;
    if (sz > 0 && sz === last) break;
    last = sz;
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
  }
}
const page = readPNG(pngFile);
for (const d of OUTS) fs.mkdirSync(d, { recursive: true });
for (const p of PIECES) {
  const im = I.crop(page, p.x * SCALE, p.y * SCALE, p.w * SCALE, p.h * SCALE);
  for (const d of OUTS) I.writeTGA(path.join(d, p.name + ".tga"), im);
}
console.log("ok:", PIECES.map((p) => p.name).join(", "));
