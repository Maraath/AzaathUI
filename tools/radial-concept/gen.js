// Menu radial do AzaathUI: arte própria (astrolábio de pedra e ouro, como o resto do Azaath).
// Cada peça é SVG renderizado pelo Edge sem janela (fundo transparente, escala 2).
//   node tools/radial-concept/gen.js           -> preview.png (o menu montado, para aprovar)
//   node tools/radial-concept/gen.js apply     -> também grava Media/Radial/<peça>.tga
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
const OUTS = [path.join(ROOT, "AzaathUI/Media/Radial"),
  "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Radial"];
const FONTS = "file:///" + path.join(ROOT, "AzaathUI/Media/Fonts").replace(/\\/g, "/");
const SCALE = 2;

// paleta Azaath
const G = "#c9a86b", GL = "#f3dca6", GD = "#6e5630", AM = "#f5c761", INK = "#07090c";
const WHEEL = { menu: "#f5c761", gestos: "#5fd6d0", consumiveis: "#7fd88a" };

const f = n => (+n).toFixed(2);
const rad = d => d * Math.PI / 180;
const pol = (cx, cy, r, deg) => [cx + r * Math.cos(rad(deg)), cy + r * Math.sin(rad(deg))];

const DEFS = `<defs>
 <filter id="glow" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
 <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="10"/></filter>
 <filter id="blur3" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3"/></filter>
 <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${GL}"/><stop offset=".55" stop-color="${G}"/><stop offset="1" stop-color="${GD}"/></linearGradient>
 <linearGradient id="goldR" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${GL}"/><stop offset=".5" stop-color="${G}"/><stop offset="1" stop-color="${GD}"/></linearGradient>
 <radialGradient id="stone" cx=".5" cy=".42" r=".6"><stop offset="0" stop-color="#1d232b"/><stop offset=".7" stop-color="#11151a"/><stop offset="1" stop-color="#090b0e"/></radialGradient>
 <radialGradient id="pit" cx=".5" cy=".45" r=".55"><stop offset="0" stop-color="#151a20"/><stop offset="1" stop-color="#040506"/></radialGradient>
 <radialGradient id="whiteFade" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="#fff" stop-opacity="1"/><stop offset=".45" stop-color="#fff" stop-opacity=".45"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
 <radialGradient id="wedgeG" cx="240" cy="240" r="200" gradientUnits="userSpaceOnUse"><stop offset=".55" stop-color="#fff" stop-opacity="0"/><stop offset=".8" stop-color="#fff" stop-opacity=".35"/><stop offset="1" stop-color="#fff" stop-opacity=".85"/></radialGradient>
</defs>`;
const svg = (w, h, body) => `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg">${DEFS}${body}</svg>`;

const diamond = (cx, cy, r, attrs) => `<polygon points="${f(cx)},${f(cy - r)} ${f(cx + r)},${f(cy)} ${f(cx)},${f(cy + r)} ${f(cx - r)},${f(cy)}" ${attrs}/>`;
const RUNES = ["M0 -5 V5 M0 -5 L3 -2 M0 0 L-3 3", "M-3 -5 V5 M-3 -1 L3 -5 M-3 -1 L3 5", "M0 -5 L3 0 L0 5 L-3 0 Z",
  "M-3 -5 L3 5 M3 -5 L-3 5 M-3 0 H3", "M0 -5 V5 M-3 -2 L0 -5 L3 -2", "M-3 5 V-5 L3 -1 L-3 2", "M-3 -4 H3 M0 -4 V5 M-3 5 H3",
  "M-3 -5 L0 0 L3 -5 M0 0 V5"];

// ------------------------------------------------------------------ peças (480 = moldura do menu)
const S = 480, C0 = 240;
const R_IN = 120, R_OUT = 198, R_SLOT = 159, R_CORE = 82;

// sem `stone`: só os aros de ouro (modo transparente do menu)
function basePiece(stone = true) {
  let b = "";
  if (stone) {
  b += `<circle cx="${C0}" cy="${C0}" r="226" fill="#000" opacity=".55" filter="url(#soft)"/>`;
  b += `<circle cx="${C0}" cy="${C0}" r="216" fill="url(#stone)"/>`;
  // banda das fatias: um pouco mais clara, com raios finos
  b += `<circle cx="${C0}" cy="${C0}" r="${R_OUT}" fill="#ffffff" opacity=".025"/>`;
  }
  for (let d = 0; stone && d < 360; d += 7.5) {
    const [x1, y1] = pol(C0, C0, R_IN + 4, d), [x2, y2] = pol(C0, C0, R_OUT - 4, d);
    b += `<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke="${G}" stroke-width=".6" opacity=".07"/>`;
  }
  // aros
  b += `<circle cx="${C0}" cy="${C0}" r="${R_OUT}" fill="none" stroke="${G}" stroke-width="1" opacity=".45"/>`;
  b += `<circle cx="${C0}" cy="${C0}" r="${R_IN}" fill="none" stroke="url(#goldR)" stroke-width="1.6" opacity=".9"/>`;
  b += `<circle cx="${C0}" cy="${C0}" r="${R_IN - 5}" fill="none" stroke="${GD}" stroke-width=".8" opacity=".8"/>`;
  b += `<circle cx="${C0}" cy="${C0}" r="207" fill="none" stroke="url(#goldR)" stroke-width="2.6"/>`;
  b += `<circle cx="${C0}" cy="${C0}" r="213" fill="none" stroke="${GD}" stroke-width="1.2"/>`;
  // graduação do astrolábio entre 207 e 213
  for (let d = 0; d < 360; d += 5) {
    const long = d % 45 === 0, mid = d % 15 === 0;
    const [x1, y1] = pol(C0, C0, 207, d), [x2, y2] = pol(C0, C0, long ? 216 : mid ? 213 : 211, d);
    b += `<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke="${long ? GL : G}" stroke-width="${long ? 1.6 : .8}" opacity="${long ? 1 : .7}"/>`;
  }
  for (let d = 0; d < 360; d += 90) {
    const [x, y] = pol(C0, C0, 210, d - 90);
    b += diamond(x, y, 6, `fill="url(#goldR)" stroke="${GD}" stroke-width=".6"`);
    b += diamond(x, y, 2.4, `fill="${GL}"`);
  }
  // encaixe do núcleo
  if (stone) b += `<circle cx="${C0}" cy="${C0}" r="${R_CORE + 6}" fill="url(#pit)" stroke="${GD}" stroke-width="1"/>`;
  return b;
}

function runeBand() {
  let b = `<circle cx="${C0}" cy="${C0}" r="223" fill="none" stroke="${G}" stroke-width=".7" opacity=".55"/>`;
  b += `<circle cx="${C0}" cy="${C0}" r="235" fill="none" stroke="${G}" stroke-width=".7" opacity=".4"/>`;
  for (let i = 0; i < 48; i++) {
    const d = i * 7.5, [x, y] = pol(C0, C0, 229, d - 90);
    b += i % 6 === 0 ? diamond(x, y, 2.6, `fill="${GL}" opacity=".85"`)
      : `<path d="${RUNES[(i * 5) % RUNES.length]}" transform="translate(${f(x)} ${f(y)}) rotate(${f(d)}) scale(.75)" fill="none" stroke="${GL}" stroke-width="1.1" stroke-linecap="round" opacity=".7"/>`;
  }
  return b;
}

// fatia acesa (branca, tingida no jogo) para N fatias, centrada no topo
function wedge(n) {
  const half = 180 / n - 1.2;
  const [ax, ay] = pol(C0, C0, R_OUT - 1, -90 - half), [bx, by] = pol(C0, C0, R_OUT - 1, -90 + half);
  const [cx, cy] = pol(C0, C0, R_IN + 1, -90 + half), [dx, dy] = pol(C0, C0, R_IN + 1, -90 - half);
  const big = half * 2 > 180 ? 1 : 0;
  const d = `M${f(ax)} ${f(ay)} A${R_OUT - 1} ${R_OUT - 1} 0 ${big} 1 ${f(bx)} ${f(by)} L${f(cx)} ${f(cy)} A${R_IN + 1} ${R_IN + 1} 0 ${big} 0 ${f(dx)} ${f(dy)} Z`;
  const [ox, oy] = pol(C0, C0, R_OUT - 2, -90 - half), [px, py] = pol(C0, C0, R_OUT - 2, -90 + half);
  return `<path d="${d}" fill="url(#wedgeG)"/>` +
    `<path d="M${f(ox)} ${f(oy)} A${R_OUT - 2} ${R_OUT - 2} 0 ${big} 1 ${f(px)} ${f(py)}" fill="none" stroke="#fff" stroke-width="2.4" filter="url(#glow)"/>`;
}

// divisor entre fatias (vertical, de R_IN a R_OUT+4), 16 x 96
function divider() {
  return `<line x1="8" y1="6" x2="8" y2="90" stroke="url(#gold)" stroke-width="1.3" opacity=".85"/>` +
    diamond(8, 6, 4.5, `fill="url(#goldR)" stroke="${GD}" stroke-width=".5"`) + diamond(8, 6, 1.8, `fill="${GL}"`);
}

// medalhão do espaço (64): aro de ouro, fundo escuro
function slotRim() {
  let b = `<circle cx="32" cy="32" r="29" fill="none" stroke="url(#goldR)" stroke-width="2.4"/>`;
  b += `<circle cx="32" cy="32" r="25.6" fill="none" stroke="${GD}" stroke-width="1"/>`;
  for (const d of [0, 90, 180, 270]) { const [x, y] = pol(32, 32, 29, d - 90); b += diamond(x, y, 2.6, `fill="${GL}"`); }
  return b;
}
const slotBack = () => `<circle cx="32" cy="32" r="27" fill="url(#pit)"/>`;
const halo = () => `<circle cx="64" cy="64" r="62" fill="url(#whiteFade)"/>`;

// núcleo (176): medalhão de astrolábio
function core() {
  let b = `<circle cx="88" cy="88" r="${R_CORE}" fill="url(#pit)"/>`;
  b += `<circle cx="88" cy="88" r="${R_CORE}" fill="none" stroke="url(#goldR)" stroke-width="2"/>`;
  b += `<circle cx="88" cy="88" r="${R_CORE - 7}" fill="none" stroke="${G}" stroke-width=".7" opacity=".6"/>`;
  b += `<ellipse cx="88" cy="88" rx="${R_CORE - 16}" ry="${(R_CORE - 16) * .38}" fill="none" stroke="${G}" stroke-width=".6" opacity=".25"/>`;
  b += `<ellipse cx="88" cy="88" rx="${(R_CORE - 16) * .38}" ry="${R_CORE - 16}" fill="none" stroke="${G}" stroke-width=".6" opacity=".18"/>`;
  for (const d of [0, 90, 180, 270]) { const [x, y] = pol(88, 88, R_CORE - 7, d - 90); b += diamond(x, y, 3.2, `fill="url(#goldR)"`); }
  return b;
}

// ponteiro (32): chevron apontando para fora (para cima), girado no jogo
const needle = () => `<path d="M16 3 L27 22 L16 17 L5 22 Z" fill="url(#gold)" stroke="${GD}" stroke-width=".8" filter="url(#glow)"/>`;
// gema das abas (24): branca facetada, tingida no jogo
const tabGem = () => diamond(12, 12, 9, `fill="#fff" opacity=".9"`) + diamond(12, 12, 9, `fill="none" stroke="#fff" stroke-width="1"`) +
  `<polygon points="12,3 21,12 12,12" fill="#000" opacity=".18"/><polygon points="12,21 3,12 12,12" fill="#000" opacity=".28"/>`;
// fechar (48): X de runa
const closeX = () => `<circle cx="24" cy="24" r="20" fill="#2a0c0a" stroke="#c2533f" stroke-width="1.6"/>` +
  `<path d="M16 16 L32 32 M32 16 L16 32" stroke="#ffb59e" stroke-width="2.6" stroke-linecap="round" filter="url(#glow)"/>`;

// ícones do Menu (64), traço dourado
const ST = `fill="none" stroke="url(#gold)" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"`;
const ICONS = {
  character: `<path d="M20 34 Q20 14 32 12 Q44 14 44 34 L44 46 L36 46 L36 38 L28 38 L28 46 L20 46 Z" ${ST}/><path d="M24 30 H40 M32 30 V38" ${ST}/><path d="M32 12 V6" ${ST}/>`,
  bags: `<path d="M18 26 Q32 20 46 26 L48 48 Q32 56 16 48 Z" ${ST}/><path d="M22 26 Q24 16 32 16 Q40 16 42 26" ${ST}/>` + diamond(32, 38, 5, `fill="url(#gold)"`),
  spellbook: `<path d="M12 18 Q22 14 32 20 Q42 14 52 18 V48 Q42 44 32 50 Q22 44 12 48 Z" ${ST}/><path d="M32 20 V50" ${ST}/><path d="M22 26 L24 30 L28 31 L24 33 L22 37 L20 33 L16 31 L20 30 Z" fill="url(#gold)"/>`,
  talents: `<path d="M32 10 L18 28 L32 36 L46 28 Z M32 36 L24 52 M32 36 L40 52" ${ST}/>` +
    [[32, 10], [18, 28], [46, 28], [32, 36], [24, 52], [40, 52]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="3.4" fill="url(#gold)"/>`).join(""),
  quests: `<path d="M18 14 H42 Q48 14 48 20 V50 H24 Q18 50 18 44 Z" ${ST}/><path d="M18 14 Q14 14 14 18 V22 H18" ${ST}/><path d="M33 22 V36" ${ST}/><circle cx="33" cy="43" r="2.4" fill="url(#gold)"/>`,
  fullmap: `<circle cx="32" cy="32" r="20" ${ST}/><path d="M32 8 L36 28 L56 32 L36 36 L32 56 L28 36 L8 32 L28 28 Z" fill="url(#gold)" opacity=".9"/>`,
  groupfinder: `<circle cx="32" cy="22" r="6" ${ST}/><path d="M22 44 Q22 32 32 32 Q42 32 42 44" ${ST}/><circle cx="17" cy="27" r="4.5" ${ST}/><path d="M9 45 Q9 36 17 36" ${ST}/><circle cx="47" cy="27" r="4.5" ${ST}/><path d="M55 45 Q55 36 47 36" ${ST}/>`,
  gamemenu: (() => { let s = ""; for (let i = 0; i < 8; i++) { const [x1, y1] = pol(32, 32, 14, i * 45), [x2, y2] = pol(32, 32, 21, i * 45); s += `<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke="url(#gold)" stroke-width="5" stroke-linecap="round"/>`; } return s + `<circle cx="32" cy="32" r="14" ${ST}/><circle cx="32" cy="32" r="5" ${ST}/>`; })(),
};

// ------------------------------------------------------------------ prévia montada
function iconData(file) { return "data:image/png;base64," + fs.readFileSync(file).toString("base64"); }

function menuMock(x0, y0, title, color, slots, aim, opts) {
  const n = slots.length;
  const g = (inner, extra = "") => `<g transform="translate(${x0} ${y0})" ${extra}>${inner}</g>`;
  let b = g(basePiece()) + g(`<g transform="rotate(12 240 240)">${runeBand()}</g>`);
  // fatia escolhida
  const aimDeg = 360 * aim / n;
  b += g(`<g transform="rotate(${f(aimDeg)} 240 240)" style="mix-blend-mode:screen" opacity=".95"><g style="filter:drop-shadow(0 0 6px ${color})">${wedge(n).replace(/#fff/g, color)}</g></g>`);
  for (let i = 0; i < n; i++) {
    const d = 360 * i / n + 180 / n;
    b += g(`<g transform="rotate(${f(d)} 240 240) translate(232 ${240 - R_OUT - 4})">${divider()}</g>`);
  }
  slots.forEach((s, i) => {
    const d = 360 * i / n - 90;
    const [cx, cy] = pol(C0, C0, R_SLOT, d);
    const sel = i === aim, k = sel ? 1.14 : 1;
    let inner = "";
    if (sel) inner += `<g transform="translate(-64 -64)" opacity=".75">${halo().replace(/#fff/g, color)}</g>`;
    inner += `<g transform="scale(${k}) translate(-32 -32)">${slotBack()}`;
    if (s.icon) inner += `<clipPath id="c${x0}${i}"><circle cx="32" cy="32" r="25.5"/></clipPath><image href="${s.icon}" x="5" y="5" width="54" height="54" clip-path="url(#c${x0}${i})" ${s.dim ? 'opacity=".45"' : ""}/>`;
    if (s.glyph) inner += `<g transform="translate(13 13) scale(.6)" ${sel ? "" : 'opacity=".85"'}>${ICONS[s.glyph]}</g>`;
    if (s.word) inner += `<text x="32" y="36.5" text-anchor="middle" font-family="CinzelB" font-size="10.5" fill="${sel ? "#fff" : GL}" letter-spacing=".6">${s.word}</text>`;
    if (s.cd) inner += `<path d="M32 32 L32 5 A27 27 0 ${s.cd > .5 ? 1 : 0} 1 ${f(32 + 27 * Math.sin(2 * Math.PI * s.cd))} ${f(32 - 27 * Math.cos(2 * Math.PI * s.cd))} Z" fill="#000" opacity=".6"/><text x="32" y="38" text-anchor="middle" font-family="PTB" font-size="14" fill="#fff">${s.cdText}</text>`;
    inner += `<g ${sel ? 'style="filter:brightness(1.35)"' : ""}>${slotRim()}</g>`;
    if (s.count) inner += `<text x="54" y="56" text-anchor="end" font-family="PTB" font-size="12" fill="#fff" stroke="#000" stroke-width="2.5" paint-order="stroke">${s.count}</text>`;
    inner += `</g>`;
    b += g(`<g transform="translate(${f(cx)} ${f(cy)})">${inner}</g>`);
  });
  // núcleo, ponteiro e textos
  b += g(`<g transform="translate(152 152)">${core()}</g>`);
  b += g(`<g transform="rotate(${f(aimDeg)} 240 240) translate(224 ${240 - R_CORE - 26})" style="filter:drop-shadow(0 0 4px ${color})">${needle()}</g>`);
  const sel = slots[aim];
  b += g(`<text x="240" y="216" text-anchor="middle" font-family="Cinzel" font-size="10" letter-spacing="3" fill="${color}">${title.toUpperCase()}</text>` +
    `<text x="240" y="246" text-anchor="middle" font-family="CinzelB" font-size="${sel.label.length > 12 ? 14 : 17}" fill="#fff" style="filter:drop-shadow(0 0 6px ${color})">${sel.label}</text>` +
    `<line x1="200" y1="258" x2="280" y2="258" stroke="${G}" stroke-width=".7" opacity=".6"/>` +
    `<text x="240" y="274" text-anchor="middle" font-family="PT" font-size="10.5" fill="#9aa0a6">${opts.hint}</text>`);
  // abas (embaixo, fora do disco)
  const tabs = [["Menu", WHEEL.menu], ["Gestos", WHEEL.gestos], ["Consumíveis", WHEEL.consumiveis]];
  let tx = 240 - 150;
  tabs.forEach(([name, col], i) => {
    const on = name === title, cx = tx + i * 150;
    b += g(`<g transform="translate(${cx - 12} 478)" ${on ? `style="filter:drop-shadow(0 0 5px ${col})"` : 'opacity=".55"'}>${tabGem().replace(/#fff"/g, `${on ? col : "#8a8f96"}"`)}</g>` +
      `<text x="${cx}" y="514" text-anchor="middle" font-family="Cinzel${on ? "B" : ""}" font-size="11" letter-spacing="2" fill="${on ? col : "#8a8f96"}">${name.toUpperCase()}</text>`);
  });
  return b;
}

function preview() {
  const IC = path.join(require("os").tmpdir(), "azaath-radial-icons");
  const ic = id => { const p = path.join(IC, "i" + id + ".png"); return fs.existsSync(p) ? iconData(p) : null; };
  const W = 1100, H = 640;
  let body = `<rect width="${W}" height="${H}" fill="#0b0f14"/>` +
    `<radialGradient id="bgv" cx=".5" cy=".45" r=".7"><stop offset="0" stop-color="#243140"/><stop offset="1" stop-color="#06080b"/></radialGradient><rect width="${W}" height="${H}" fill="url(#bgv)"/>`;
  const menu = [
    { label: "Personagem", glyph: "character" }, { label: "Mochilas", glyph: "bags" }, { label: "Grimório", glyph: "spellbook" },
    { label: "Talentos", glyph: "talents" }, { label: "Missões", glyph: "quests" }, { label: "Mapa-Múndi", glyph: "fullmap" },
    { label: "Localizador", glyph: "groupfinder" }, { label: "Menu do Jogo", glyph: "gamemenu" },
  ];
  body += menuMock(40, 30, "Menu", WHEEL.menu, menu, 2, { hint: "solte para abrir" });
  const cons = [
    { label: "Pedra de Regresso", icon: ic(134414), cd: .62, cdText: "18m" }, { label: "Poção de Cura", icon: ic(134830), count: 12 },
    { label: "Galinha Assada", icon: ic(133971), count: 20 }, { label: "Elixir do Gigante", icon: ic(134821), count: 3 },
  ];
  body += menuMock(580, 30, "Consumíveis", WHEEL.consumiveis, cons, 1, { hint: "roda do mouse: trocar aba" });
  return svg(W, H, body);
}

// ------------------------------------------------------------------ página e render
const PIECES = [
  ["Base", S, S, basePiece()], ["Rings", S, S, basePiece(false)], ["RuneBand", S, S, runeBand()], ["Divider", 16, 96, divider()], ["SlotRim", 64, 64, slotRim()],
  ["SlotBack", 64, 64, slotBack()], ["Halo", 128, 128, halo()], ["Core", 176, 176, core()], ["Needle", 32, 32, needle()],
  ["TabGem", 24, 24, tabGem()], ["Close", 48, 48, closeX()],
  ...[2, 3, 4, 5, 6, 7, 8].map(n => ["Wedge" + n, S, S, wedge(n)]),
  ...Object.entries(ICONS).map(([k, v]) => ["Icon_" + k, 64, 64, v]),
];

function render(html, w, h, out) {
  const tmp = path.join(require("os").tmpdir(), "azaath-radial");
  fs.mkdirSync(tmp, { recursive: true });
  const htmlFile = path.join(tmp, "page.html"), png = out;
  if (fs.existsSync(png)) fs.unlinkSync(png);
  fs.writeFileSync(htmlFile, `<!doctype html><html><head><style>
@font-face{font-family:Cinzel;src:url('${FONTS}/Cinzel-Regular.ttf')} @font-face{font-family:CinzelB;src:url('${FONTS}/Cinzel-Bold.ttf')}
@font-face{font-family:PT;src:url('${FONTS}/PTSans-Regular.ttf')} @font-face{font-family:PTB;src:url('${FONTS}/PTSans-Bold.ttf')}
html,body{margin:0;background:transparent;overflow:hidden}</style></head><body>${html}</body></html>`);
  spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--user-data-dir=" + path.join(tmp, "profile"), "--no-first-run", "--hide-scrollbars",
    "--default-background-color=00000000", "--force-device-scale-factor=" + SCALE, "--window-size=" + w + "," + h, "--virtual-time-budget=2500",
    "--allow-file-access-from-files", "--screenshot=" + png, "file:///" + htmlFile.replace(/\\/g, "/")], { stdio: "ignore" });
  const t0 = Date.now(); let last = -1;
  while (Date.now() - t0 < 30000) {
    const sz = fs.existsSync(png) ? fs.statSync(png).size : 0;
    if (sz > 0 && sz === last) break;
    last = sz; Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
  }
  if (!fs.existsSync(png)) { console.log("o Edge não gravou o print (rodar fora do sandbox)"); process.exit(1); }
}

render(preview(), 1100, 640, path.join(DIR, "preview.png"));
console.log("prévia: " + path.join(DIR, "preview.png"));

if (APPLY) {
  // peças lado a lado numa página, depois recortadas
  let x = 0, y = 0, rowH = 0, body = "";
  const PAGE_W = 2000;
  for (const p of PIECES) {
    if (x + p[1] > PAGE_W) { x = 0; y += rowH + 4; rowH = 0; }
    p.x = x; p.y = y;
    body += `<g transform="translate(${x} ${y})">${p[3]}</g>`;
    x += p[1] + 4; rowH = Math.max(rowH, p[2]);
  }
  const PAGE_H = y + rowH;
  const sheet = path.join(require("os").tmpdir(), "azaath-radial", "sheet.png");
  render(svg(PAGE_W, PAGE_H, body), PAGE_W, PAGE_H, sheet);
  const page = readPNG(sheet);
  for (const d of OUTS) { try { fs.mkdirSync(d, { recursive: true }); } catch (e) { /* jogo ausente */ } }
  for (const p of PIECES) {
    const im = I.crop(page, p.x * SCALE, p.y * SCALE, p[1] * SCALE, p[2] * SCALE); // resolução dobrada: nítido em telas grandes
    for (const d of OUTS) { try { I.writeTGA(path.join(d, p[0] + ".tga"), im); } catch (e) { console.log("falhou", d, e.message); } }
  }
  console.log(PIECES.length, "texturas gravadas em Media/Radial");
}
