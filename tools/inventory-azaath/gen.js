// Skin "Azaath" da mochila (inventory.style = "azaath"): arte própria redesenhada a partir
// do conceito (moldura escura azul-petróleo, filetes de ouro, brasão com cristal, losangos
// nos cantos, espaços com aro tingido pela raridade, chips de filtro).
// Cada peça é SVG renderizado pelo Edge sem janela (escala 2 = nítido em telas grandes).
//   node tools/inventory-azaath/gen.js        -> preview.png (peças lado a lado)
//   node tools/inventory-azaath/gen.js apply  -> também grava Media/Inventory/Az*.tga
// (o Edge só grava fora do sandbox do Bash)
"use strict";
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const DIR = __dirname;
const ROOT = path.resolve(DIR, "../..");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const APPLY = process.argv[2] === "apply";
const OUT = path.join(ROOT, "AzaathUI/Media/Inventory");
const SCALE = 2;

const G = "#c9a86b", GL = "#f3dca6", GD = "#6e5630", T = "#5fd6d0", TL = "#c4fff8", TD = "#1d6d6a";
const f = n => (+n).toFixed(2);

const DEFS = `<defs>
 <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="1.4" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
 <filter id="blur2" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2"/></filter>
 <filter id="blur4" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="4"/></filter>
 <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${GL}"/><stop offset=".55" stop-color="${G}"/><stop offset="1" stop-color="${GD}"/></linearGradient>
 <linearGradient id="goldH" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="${GD}" stop-opacity="0"/><stop offset=".3" stop-color="${G}"/><stop offset=".5" stop-color="${GL}"/><stop offset=".7" stop-color="${G}"/><stop offset="1" stop-color="${GD}" stop-opacity="0"/></linearGradient>
 <linearGradient id="crystal" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${TL}"/><stop offset=".45" stop-color="${T}"/><stop offset="1" stop-color="${TD}"/></linearGradient>
 <radialGradient id="body" cx=".5" cy=".18" r=".95"><stop offset="0" stop-color="#14272d"/><stop offset=".55" stop-color="#0c181c"/><stop offset="1" stop-color="#060b0e"/></radialGradient>
 <linearGradient id="slotIn" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#182a30"/><stop offset=".5" stop-color="#0b1518"/><stop offset="1" stop-color="#05090b"/></linearGradient>
 <radialGradient id="slotGear" cx=".5" cy=".35" r=".75"><stop offset="0" stop-color="#2a3c42"/><stop offset=".6" stop-color="#111d21"/><stop offset="1" stop-color="#060b0d"/></radialGradient>
 <radialGradient id="roundIn" cx=".5" cy=".4" r=".6"><stop offset="0" stop-color="#1d2f35"/><stop offset="1" stop-color="#060b0d"/></radialGradient>
 <linearGradient id="lineR" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff"/><stop offset=".6" stop-color="#fff" stop-opacity=".45"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
 <radialGradient id="glowH" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#fff"/><stop offset=".5" stop-color="#fff" stop-opacity=".35"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
</defs>`;
const svg = (w, h, body) => `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg">${DEFS}${body}</svg>`;
const diamond = (x, y, rx, ry, attrs) => `<polygon points="${f(x)},${f(y - ry)} ${f(x + rx)},${f(y)} ${f(x)},${f(y + ry)} ${f(x - rx)},${f(y)}" ${attrs}/>`;

// ------------------------------------------------------------------ peças
// corpo: degradê (esticado no jogo)
const body = () => `<rect width="256" height="256" fill="url(#body)"/>`;

// trama de fundo (ladrilho 128): losangos finos e pontos, quase invisível
function pattern() {
  let b = "";
  for (const [x, y] of [[0, 0], [64, 64], [128, 0], [0, 128], [128, 128]]) {
    b += diamond(x, y, 32, 32, `fill="none" stroke="#fff" stroke-width=".6" opacity=".5"`);
    b += `<circle cx="${x}" cy="${y}" r="1.4" fill="#fff" opacity=".7"/>`;
  }
  b += `<circle cx="64" cy="0" r=".9" fill="#fff" opacity=".5"/><circle cx="0" cy="64" r=".9" fill="#fff" opacity=".5"/>`;
  b += `<circle cx="128" cy="64" r=".9" fill="#fff" opacity=".5"/><circle cx="64" cy="128" r=".9" fill="#fff" opacity=".5"/>`;
  return b;
}

// losango dos cantos: cristal azul em engaste de ouro
function gem() {
  let b = `<circle cx="16" cy="16" r="11" fill="${T}" opacity=".35" filter="url(#blur4)"/>`;
  b += diamond(16, 16, 11, 11, `fill="#0a0f12" stroke="url(#gold)" stroke-width="1.6"`);
  b += diamond(16, 16, 7, 7, `fill="url(#crystal)"`);
  b += `<polygon points="16,9 19,13 16,16 13,13" fill="#fff" opacity=".55"/>`;
  return b;
}

// brasão do topo: asas de filigrana + cristal central (base encosta no filete)
function crest() {
  const W = 256, cx = 128, by = 52;
  let b = `<ellipse cx="${cx}" cy="${by - 14}" rx="34" ry="22" fill="${T}" opacity=".28" filter="url(#blur4)"/>`;
  // filete-base com brilho
  b += `<rect x="0" y="${by}" width="${W}" height="1.6" fill="url(#goldH)"/>`;
  for (const s of [-1, 1]) {
    const p = (x, y) => `${f(cx + s * x)} ${f(y)}`;
    b += `<path d="M${p(22, by)} C${p(40, by - 2)} ${p(54, by - 20)} ${p(80, by - 18)} C${p(98, by - 16)} ${p(104, by - 6)} ${p(124, by - 4)}" fill="none" stroke="url(#gold)" stroke-width="1.6"/>`;
    b += `<path d="M${p(26, by - 6)} C${p(42, by - 10)} ${p(50, by - 28)} ${p(70, by - 30)}" fill="none" stroke="${G}" stroke-width="1" opacity=".8"/>`;
    b += `<path d="M${p(80, by - 18)} c${s * 6} -6 ${s * 14} -4 ${s * 12} 2" fill="none" stroke="${G}" stroke-width="1" opacity=".8"/>`;
    b += diamond(cx + s * 88, by - 11, 3, 3, `fill="${T}" filter="url(#glow)"`);
    b += diamond(cx + s * 132, by - 1, 2.4, 2.4, `fill="${GL}"`);
  }
  // engaste e cristal
  b += `<path d="M${cx - 20} ${by} L${cx - 14} ${by - 22} L${cx} ${by - 38} L${cx + 14} ${by - 22} L${cx + 20} ${by} Z" fill="#0a0f12" stroke="url(#gold)" stroke-width="1.8"/>`;
  b += `<polygon points="${cx},${by - 32} ${cx + 11},${by - 18} ${cx},${by - 4} ${cx - 11},${by - 18}" fill="url(#crystal)" filter="url(#glow)"/>`;
  b += `<polygon points="${cx},${by - 32} ${cx + 4},${by - 20} ${cx},${by - 16} ${cx - 4},${by - 20}" fill="#fff" opacity=".6"/>`;
  return b;
}

// espaço quadrado: aro claro (tingido pela raridade no jogo) e fundo escuro
function slot(gear) {
  let b = `<rect x="3" y="3" width="58" height="58" rx="3" fill="#fff" opacity=".25" filter="url(#blur2)"/>`;
  b += `<rect x="4" y="4" width="56" height="56" rx="3" fill="${gear ? "url(#slotGear)" : "url(#slotIn)"}"/>`;
  b += `<rect x="4.75" y="4.75" width="54.5" height="54.5" rx="2.5" fill="none" stroke="#e6ecec" stroke-width="1.5"/>`;
  b += `<rect x="7" y="7" width="50" height="50" rx="1.5" fill="none" stroke="#fff" stroke-width=".6" opacity=".25"/>`;
  if (gear) for (const [x, y] of [[7, 7], [57, 7], [7, 57], [57, 57]]) b += diamond(x, y, 2.2, 2.2, `fill="#fff" opacity=".7"`);
  return b;
}

// espaço redondo (materiais): aro duplo e fundo escuro
function slotRound() {
  let b = `<circle cx="32" cy="32" r="29" fill="#fff" opacity=".22" filter="url(#blur2)"/>`;
  b += `<circle cx="32" cy="32" r="28" fill="url(#roundIn)"/>`;
  b += `<circle cx="32" cy="32" r="27.3" fill="none" stroke="#eef2f2" stroke-width="2"/>`;
  b += `<circle cx="32" cy="32" r="24" fill="none" stroke="#fff" stroke-width=".7" opacity=".35"/>`;
  return b;
}

// chip de filtro (3 fatias no jogo: pontas de 12 + meio esticado)
const chip = on => `<rect x="1" y="1" width="62" height="22" rx="11" fill="#fff" opacity="${on ? ".30" : ".06"}"/>
 <rect x="1.5" y="1.5" width="61" height="21" rx="10.5" fill="none" stroke="#fff" stroke-width="1" opacity="${on ? ".95" : ".45"}"/>`;

const close = () => `<circle cx="16" cy="16" r="13" fill="#000" opacity=".35"/><circle cx="16" cy="16" r="12.5" fill="none" stroke="#fff" stroke-width="1.4"/>
 <path d="M11.5 11.5 L20.5 20.5 M20.5 11.5 L11.5 20.5" stroke="#fff" stroke-width="1.8" stroke-linecap="round"/>`;
const search = () => `<circle cx="7" cy="7" r="4.6" fill="none" stroke="#fff" stroke-width="1.6"/><path d="M10.4 10.4 L14 14" stroke="#fff" stroke-width="1.9" stroke-linecap="round"/>`;
const glowLine = () => `<ellipse cx="64" cy="8" rx="62" ry="5" fill="url(#glowH)"/><rect x="8" y="7.4" width="112" height="1.2" fill="#fff" opacity=".9"/>`;
const line = () => `<rect x="0" y="1" width="256" height="2" fill="url(#lineR)"/>`;
// cantoneira de ouro (canto superior esquerdo; o jogo espelha nos outros)
const corner = () => `<path d="M2 30 V2 H30" fill="none" stroke="url(#gold)" stroke-width="1.6"/><path d="M6 22 V6 H22" fill="none" stroke="${G}" stroke-width=".8" opacity=".7"/>`;

const PIECES = [
  ["AzBody", 256, 256, body()], ["AzPattern", 128, 128, pattern()], ["AzGem", 32, 32, gem()], ["AzCrest", 256, 64, crest()],
  ["AzSlot", 64, 64, slot(false)], ["AzSlotGear", 64, 64, slot(true)], ["AzSlotRound", 64, 64, slotRound()],
  ["AzChip", 64, 24, chip(false)], ["AzChipOn", 64, 24, chip(true)], ["AzClose", 32, 32, close()], ["AzSearch", 16, 16, search()],
  ["AzGlow", 128, 16, glowLine()], ["AzLine", 256, 4, line()], ["AzCorner", 32, 32, corner()],
];

// ------------------------------------------------------------------ render
function render(html, w, h, out) {
  const tmp = path.join(require("os").tmpdir(), "azaath-invaz");
  fs.mkdirSync(tmp, { recursive: true });
  const htmlFile = path.join(tmp, "page.html");
  if (fs.existsSync(out)) fs.unlinkSync(out);
  fs.writeFileSync(htmlFile, `<!doctype html><html><head><style>html,body{margin:0;background:transparent;overflow:hidden}</style></head><body>${html}</body></html>`);
  spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--user-data-dir=" + path.join(tmp, "profile"), "--no-first-run", "--hide-scrollbars",
    "--default-background-color=00000000", "--force-device-scale-factor=" + SCALE, "--window-size=" + w + "," + h, "--virtual-time-budget=2500",
    "--screenshot=" + out, "file:///" + htmlFile.replace(/\\/g, "/")], { stdio: "ignore" });
  const t0 = Date.now(); let last = -1;
  while (Date.now() - t0 < 30000) {
    const sz = fs.existsSync(out) ? fs.statSync(out).size : 0;
    if (sz > 0 && sz === last) break;
    last = sz; Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
  }
  if (!fs.existsSync(out)) { console.log("o Edge não gravou o print (rodar fora do sandbox)"); process.exit(1); }
}

// folha com todas as peças (usada na prévia e no recorte)
let x = 0, y = 0, rowH = 0, sheetBody = "";
const PAGE_W = 900;
for (const p of PIECES) {
  if (x + p[1] > PAGE_W) { x = 0; y += rowH + 6; rowH = 0; }
  p.x = x; p.y = y;
  sheetBody += `<svg x="${x}" y="${y}" width="${p[1]}" height="${p[2]}" viewBox="0 0 ${p[1]} ${p[2]}" overflow="hidden">${p[3]}</svg>`;
  x += p[1] + 6; rowH = Math.max(rowH, p[2]);
}
const PAGE_H = y + rowH;
const sheet = path.join(DIR, "preview.png");
render(svg(PAGE_W, PAGE_H, `<rect width="${PAGE_W}" height="${PAGE_H}" fill="#000" opacity="0"/>` + sheetBody), PAGE_W, PAGE_H, sheet);
console.log("folha: " + sheet);

if (APPLY) {
  const page = readPNG(sheet);
  for (const p of PIECES) {
    const im = I.crop(page, p.x * SCALE, p.y * SCALE, p[1] * SCALE, p[2] * SCALE);
    I.writeTGA(path.join(OUT, p[0] + ".tga"), im);
  }
  console.log(PIECES.length, "texturas gravadas em Media/Inventory");
}
