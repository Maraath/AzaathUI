// Astrolábio animado atrás do anel de equipamento (painel "Equipado" da mochila,
// Modules/InventoryEquip.lua). Arte própria: camadas que giram em sentidos opostos,
// com runas de Azoth (alfabeto nosso, traço alquímico) brilhando em azul-esverdeado.
// Cada peça é SVG renderizado pelo Edge sem janela (fundo transparente, escala 2).
//   node tools/equip-astrolabe/gen.js        -> preview.png (montado, para conferir)
//   node tools/equip-astrolabe/gen.js apply  -> também grava Media/Inventory/Astro*.tga
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
const OUTS = [path.join(ROOT, "AzaathUI/Media/Inventory")];
const SCALE = 2;

const G = "#c9a86b", GL = "#f3dca6", GD = "#6e5630", T = "#5fd6d0", TL = "#b8fff6";
const S = 256, C = 128;
const f = n => (+n).toFixed(2);
const rad = d => d * Math.PI / 180;
const pol = (r, deg) => [C + r * Math.cos(rad(deg - 90)), C + r * Math.sin(rad(deg - 90))];

const DEFS = `<defs>
 <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="1.6" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
 <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="6"/></filter>
 <radialGradient id="base" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#10202a" stop-opacity=".95"/><stop offset=".7" stop-color="#0a1218" stop-opacity=".75"/><stop offset=".97" stop-color="#05080b" stop-opacity=".35"/><stop offset="1" stop-color="#000" stop-opacity="0"/></radialGradient>
 <radialGradient id="fade" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset=".4" stop-color="#fff" stop-opacity=".45"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
</defs>`;
const svg = (w, h, body) => `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg">${DEFS}${body}</svg>`;
const ring = (r, col, w, op, extra = "") => `<circle cx="${C}" cy="${C}" r="${r}" fill="none" stroke="${col}" stroke-width="${w}" opacity="${op}" ${extra}/>`;

// Runas de Azoth: alfabeto próprio (caixa 10x14, centro 0,0) — hastes, crescentes,
// olhos e triângulos alquímicos. Nada copiado de jogo nenhum.
const RUNES = [
  "M0 -7 V7 M0 -7 L4 -3 M0 -1 L-4 3",
  "M-4 -7 L4 7 M-4 7 L4 -7 M-2 0 a2 2 0 1 0 4 0 a2 2 0 1 0 -4 0",
  "M0 -7 L5 5 H-5 Z M0 -1 V7",
  "M-4 -6 a4 4 0 1 1 0 6 M0 -7 V7",
  "M-4 -7 V7 M-4 -2 L4 -7 M-4 -2 L4 4",
  "M0 -7 V7 M-4 -4 a4 4 0 0 0 8 0 M-3 4 H3",
  "M-4 7 L0 -7 L4 7 M-2 1 H2",
  "M0 -6 a3 3 0 1 0 0.01 0 M0 0 V7 M-4 4 H4",
  "M-4 -7 H4 L-4 7 H4",
  "M0 -7 L4 0 L0 7 L-4 0 Z M0 -3 V3",
  "M-4 -7 V7 M4 -7 V7 M-4 0 L4 -4",
  "M-3 -7 a5 7 0 0 1 0 14 M2 -4 V4",
  "M0 -7 V3 M-4 3 a4 4 0 0 0 8 0",
  "M-4 -3 L0 -7 L4 -3 M0 -7 V7 M-3 7 H3",
  "M-4 -7 L4 0 L-4 7 M2 -7 V7",
  "M0 -7 V7 M-4 -5 L4 -1 M-4 1 L4 5",
];
const rune = (i, x, y, deg, sc, col, sw, op) =>
  `<path d="${RUNES[i % RUNES.length]}" transform="translate(${f(x)} ${f(y)}) rotate(${f(deg)}) scale(${sc})" fill="none" stroke="${col}" stroke-width="${f(sw / sc)}" stroke-linecap="round" stroke-linejoin="round" opacity="${op}"/>`;
const diamond = (x, y, r, attrs) => `<polygon points="${f(x)},${f(y - r)} ${f(x + r)},${f(y)} ${f(x)},${f(y + r)} ${f(x - r)},${f(y)}" ${attrs}/>`;

// ------------------------------------------------------------------ peças
// fundo fixo: disco escuro esfumado, graus e aros finos
function base() {
  let b = `<circle cx="${C}" cy="${C}" r="127" fill="url(#base)"/>`;
  b += ring(100, G, .6, .25) + ring(70, G, .5, .2) + ring(36, G, .6, .3);
  for (let i = 0; i < 120; i++) {
    const d = i * 3, long = i % 10 === 0, [x1, y1] = pol(100, d), [x2, y2] = pol(long ? 92 : 96.5, d);
    b += `<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke="${G}" stroke-width="${long ? .8 : .45}" opacity="${long ? .5 : .3}"/>`;
  }
  return b;
}

// faixa externa de runas (gira devagar no sentido horário)
function runeBand() {
  let b = ring(124, G, .8, .55) + ring(108, G, .8, .55) + ring(122, GD, .4, .5);
  for (let i = 0; i < 24; i++) {
    const d = i * 15, [x, y] = pol(116, d);
    b += i % 4 === 0 ? diamond(x, y, 2.6, `fill="${GL}" opacity=".9"`)
      : `<g filter="url(#glow)">${rune(i * 7, x, y, d, .55, T, 1.1, .9)}</g>`;
  }
  return b;
}

// rete: aranha do astrolábio (aros concêntricos e ponteiros de estrela)
function rete() {
  let b = `<circle cx="${C}" cy="${C}" r="78" fill="none" stroke="${G}" stroke-width="1.2" opacity=".55"/>`;
  b += `<circle cx="${C}" cy="${C}" r="74" fill="none" stroke="${G}" stroke-width=".5" opacity=".35"/>`;
  for (let i = 0; i < 24; i++) {
    const a = rad(i * 15 - 90), x1 = C + 78 * Math.cos(a), y1 = C + 78 * Math.sin(a), x2 = C + 74 * Math.cos(a), y2 = C + 74 * Math.sin(a);
    b += `<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke="${G}" stroke-width=".6" opacity=".5"/>`;
  }
  // aro tracejado concêntrico (tudo no mesmo centro: girar não desalinha)
  b += `<circle cx="${C}" cy="${C}" r="88" fill="none" stroke="${G}" stroke-width=".7" stroke-dasharray="2 5" opacity=".45"/>`;
  // ponteiros de estrela em chama, cada um com um ponto azul na ponta
  for (const [d, r0, r1] of [[20, 40, 96], [95, 36, 84], [160, 44, 98], [230, 38, 90], [300, 42, 94], [345, 50, 80]]) {
    const [xa, ya] = pol(r0, d - 7), [xb, yb] = pol(r0, d + 7), [xt, yt] = pol(r1, d), [xm, ym] = pol((r0 + r1) / 2, d + 9);
    b += `<path d="M${f(xa)} ${f(ya)} Q${f(xm)} ${f(ym)} ${f(xt)} ${f(yt)} Q${f(xm - (xm - C) * .25)} ${f(ym - (ym - C) * .25)} ${f(xb)} ${f(yb)}" fill="${G}" fill-opacity=".18" stroke="${GL}" stroke-width=".7" opacity=".75"/>`;
    b += `<circle cx="${f(xt)}" cy="${f(yt)}" r="1.8" fill="${TL}" filter="url(#glow)"/>`;
  }
  return b;
}

// anel interno com runas menores (gira no sentido contrário, mais rápido)
function innerRing() {
  let b = ring(56, G, .8, .6) + ring(44, G, .8, .6);
  for (let i = 0; i < 12; i++) {
    const d = i * 30, [x, y] = pol(50, d), [lx1, ly1] = pol(44, d + 15), [lx2, ly2] = pol(56, d + 15);
    b += `<line x1="${f(lx1)}" y1="${f(ly1)}" x2="${f(lx2)}" y2="${f(ly2)}" stroke="${G}" stroke-width=".6" opacity=".5"/>`;
    b += `<g filter="url(#glow)">${rune(i * 3 + 1, x, y, d, .4, TL, .9, .85)}</g>`;
  }
  return b;
}

// brilho azul-esverdeado (branco, tingido e pulsando no jogo)
const glow = () => `<circle cx="${C}" cy="${C}" r="126" fill="url(#fade)"/>`;

const PIECES = [["AstroBase", base()], ["AstroRunes", runeBand()], ["AstroRete", rete()], ["AstroInner", innerRing()], ["AstroGlow", glow()]];

// ------------------------------------------------------------------ prévia e render
function preview() {
  let b = `<rect width="560" height="300" fill="#0b1014"/>`;
  b += `<g transform="translate(20 22)"><circle cx="${C}" cy="${C}" r="126" fill="${T}" opacity=".12"/>${base()}${runeBand()}${rete()}${innerRing()}
   <circle cx="${C}" cy="${C}" r="33" fill="#05090c" stroke="${G}" stroke-width="1" opacity=".95"/>${diamond(C, C, 8, `fill="${T}"`)}</g>`;
  b += `<g transform="translate(296 22) rotate(25 128 128)"><g transform="rotate(-25 128 128)">${base()}</g>${runeBand()}<g transform="rotate(-60 128 128)">${rete()}</g><g transform="rotate(-80 128 128)">${innerRing()}</g></g>`;
  return svg(560, 300, b);
}

function render(html, w, h, out) {
  const tmp = path.join(require("os").tmpdir(), "azaath-astro");
  fs.mkdirSync(tmp, { recursive: true });
  const htmlFile = path.join(tmp, "page.html");
  if (fs.existsSync(out)) fs.unlinkSync(out);
  fs.writeFileSync(htmlFile, `<!doctype html><html><head><style>html,body{margin:0;background:transparent;overflow:hidden}</style></head><body>${html}</body></html>`);
  spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--user-data-dir=" + path.join(tmp, "profile"), "--no-first-run", "--hide-scrollbars",
    "--default-background-color=00000000", "--force-device-scale-factor=" + SCALE, "--window-size=" + w + "," + h, "--virtual-time-budget=2500",
    "--allow-file-access-from-files", "--screenshot=" + out, "file:///" + htmlFile.replace(/\\/g, "/")], { stdio: "ignore" });
  const t0 = Date.now(); let last = -1;
  while (Date.now() - t0 < 30000) {
    const sz = fs.existsSync(out) ? fs.statSync(out).size : 0;
    if (sz > 0 && sz === last) break;
    last = sz; Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
  }
  if (!fs.existsSync(out)) { console.log("o Edge não gravou o print (rodar fora do sandbox)"); process.exit(1); }
}

render(preview(), 560, 300, path.join(DIR, "preview.png"));
console.log("prévia: " + path.join(DIR, "preview.png"));

if (APPLY) {
  let body = "";
  PIECES.forEach((p, i) => { body += `<g transform="translate(${i * (S + 4)} 0)">${p[1]}</g>`; });
  const W = PIECES.length * (S + 4);
  const sheet = path.join(require("os").tmpdir(), "azaath-astro", "sheet.png");
  render(svg(W, S, body), W, S, sheet);
  const page = readPNG(sheet);
  PIECES.forEach((p, i) => {
    const im = I.crop(page, i * (S + 4) * SCALE, 0, S * SCALE, S * SCALE); // 512x512
    for (const d of OUTS) I.writeTGA(path.join(d, p[0] + ".tga"), im);
  });
  console.log(PIECES.length, "texturas gravadas em Media/Inventory");
}
