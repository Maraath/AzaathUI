// Cadeado do "Trancar item" da mochila (Modules/InventoryLock.lua): arte própria,
// ouro do Azaath com contorno escuro. SVG renderizado pelo Edge sem janela (escala 2).
//   node tools/inventory-lock/gen.js        -> preview.png
//   node tools/inventory-lock/gen.js apply  -> também grava Media/Inventory/Lock.tga
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
const SCALE = 2, S = 32;

// branco/cinza: o jogo tinge (dourado no item, mais claro no botão aceso)
const lock = () => `<svg width="${S}" height="${S}" viewBox="0 0 ${S} ${S}" xmlns="http://www.w3.org/2000/svg">
 <defs><linearGradient id="g" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff6dc"/><stop offset=".55" stop-color="#e2c48a"/><stop offset="1" stop-color="#8a6a36"/></linearGradient></defs>
 <path d="M10 15 V10.5 a6 6 0 0 1 12 0 V15" fill="none" stroke="#000" stroke-width="6" stroke-linecap="round" opacity=".75"/>
 <path d="M10 15 V10.5 a6 6 0 0 1 12 0 V15" fill="none" stroke="url(#g)" stroke-width="3" stroke-linecap="round"/>
 <rect x="6" y="14" width="20" height="15" rx="3" fill="#000" opacity=".8"/>
 <rect x="7.5" y="15.5" width="17" height="12" rx="2" fill="url(#g)"/>
 <circle cx="16" cy="20.5" r="2" fill="#2a1d0c"/><rect x="15.2" y="21" width="1.6" height="4" rx=".8" fill="#2a1d0c"/>
</svg>`;

function render(html, w, h, out) {
  const tmp = path.join(require("os").tmpdir(), "azaath-lock");
  fs.mkdirSync(tmp, { recursive: true });
  const htmlFile = path.join(tmp, "page.html");
  if (fs.existsSync(out)) fs.unlinkSync(out);
  fs.writeFileSync(htmlFile, `<!doctype html><html><head><style>html,body{margin:0;background:transparent;overflow:hidden}</style></head><body>${html}</body></html>`);
  spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--user-data-dir=" + path.join(tmp, "profile"), "--no-first-run", "--hide-scrollbars",
    "--default-background-color=00000000", "--force-device-scale-factor=" + SCALE, "--window-size=" + w + "," + h, "--virtual-time-budget=2000",
    "--screenshot=" + out, "file:///" + htmlFile.replace(/\\/g, "/")], { stdio: "ignore" });
  const t0 = Date.now(); let last = -1;
  while (Date.now() - t0 < 30000) {
    const sz = fs.existsSync(out) ? fs.statSync(out).size : 0;
    if (sz > 0 && sz === last) break;
    last = sz; Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
  }
  if (!fs.existsSync(out)) { console.log("o Edge não gravou o print (rodar fora do sandbox)"); process.exit(1); }
}

const png = path.join(DIR, "preview.png");
render(lock(), S, S, png);
console.log("prévia: " + png);
if (APPLY) {
  const im = I.crop(readPNG(png), 0, 0, S * SCALE, S * SCALE);
  I.writeTGA(path.join(ROOT, "AzaathUI/Media/Inventory/Lock.tga"), im);
  console.log("gravado Media/Inventory/Lock.tga");
}
