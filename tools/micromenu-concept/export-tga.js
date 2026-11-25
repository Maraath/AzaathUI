// Exporta todas as texturas TGA dos 3 novos estilos de MicroMenu para AzaathUI/Media/MicroMenu/:
//   1) Azaath Arcano:     AzWingL/R, AzSocket, AzActiveRing, AzToggle, AzBadge, AzGem, AzCorner
//   2) Forja de Númenor:  NumWingL/R, NumSocket, NumActiveRing, NumToggle, NumBadge, NumGem, NumCorner, NumCrest + 16 Num_<Icon>
//   3) Mesa de RPG (WoW): WowRail, WowCapL/R, WowSlot, WowSlotActive, WowToggle, WowArrows, WowBadge,
//                         WowParchment, WowCorner, WowPlaque, WowTab, WowSeal, WowMedal + 14 Wow_<Icon>
// Uso: node tools/micromenu-concept/export-tga.js
"use strict";
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const { spawnSync } = require("child_process");
const { readTGA, writeTGA } = require("../map-extract/imagecodec.js");

const DIR = __dirname;
const ROOT = path.resolve(DIR, "../..");
const OUT_DIR = path.join(ROOT, "AzaathUI", "Media", "MicroMenu");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";

const crcTable = (() => {
  const t = new Uint32Array(256);
  for (let n = 0; n < 256; n++) {
    let c = n;
    for (let k = 0; k < 8; k++) c = (c & 1) ? (0xedb88320 ^ (c >>> 1)) : (c >>> 1);
    t[n] = c >>> 0;
  }
  return t;
})();
function crc32(buf) {
  let c = 0xffffffff;
  for (const v of buf) c = crcTable[(c ^ v) & 0xff] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}
function pngChunk(type, data) {
  const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
  const td = Buffer.concat([Buffer.from(type), data]);
  const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td));
  return Buffer.concat([len, td, crc]);
}
function tgaToUri(relPath) {
  const img = readTGA(path.join(ROOT, relPath));
  const raw = Buffer.alloc((img.w * 4 + 1) * img.h);
  for (let y = 0; y < img.h; y++) {
    const r = y * (img.w * 4 + 1);
    raw[r] = 0;
    for (let x = 0; x < img.w; x++) {
      const s = (y * img.w + x) * 4, d = r + 1 + x * 4;
      raw[d] = img.data[s]; raw[d + 1] = img.data[s + 1]; raw[d + 2] = img.data[s + 2]; raw[d + 3] = img.data[s + 3];
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(img.w, 0); ihdr.writeUInt32BE(img.h, 4); ihdr[8] = 8; ihdr[9] = 6;
  const png = Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    pngChunk("IHDR", ihdr),
    pngChunk("IDAT", zlib.deflateSync(raw, { level: 9 })),
    pngChunk("IEND", Buffer.alloc(0)),
  ]);
  return "data:image/png;base64," + png.toString("base64");
}
function fileToUri(relPath, mime) {
  return `data:${mime};base64,` + fs.readFileSync(path.join(ROOT, relPath)).toString("base64");
}

const ICONS_DIR = "tools/map-ui-concept/expedicao/out/icons/";
const ASSETS = {
  bgTable:    fileToUri("tools/grimoire-concept/bg_hd.png", "image/png"),
  chrome:     fileToUri("tools/map-ui-concept/expedicao/out/chrome_notitle.png", "image/png"),
  refFrames:  fileToUri("tools/professions-ui-concept/ref-frames.png", "image/png"),
  refRings:   fileToUri("tools/professions-ui-concept/ref-rings.png", "image/png"),
  helmets:    fileToUri("tools/drops-concept/helmets_grid.jpg", "image/jpeg"),
  dropCats:   tgaToUri("AzaathUI/Media/Sheet/DropCategoryIcons.tga"),
  leatherTab: tgaToUri("AzaathUI/Media/Grimoire/GrimTabsCut.tga"),
  grimMedal:  tgaToUri("AzaathUI/Media/Grimoire/GrimMedal.tga"),
  grimSeal:   tgaToUri("AzaathUI/Media/Grimoire/GrimSeal.tga"),
  icoLore:    fileToUri(ICONS_DIR + "ExpBtnLore.png", "image/png"),
  icoClose:   fileToUri(ICONS_DIR + "ExpBtnClose.png", "image/png"),
  icoQuests:  fileToUri(ICONS_DIR + "ExpBtnQuests.png", "image/png"),
  icoGather:  fileToUri(ICONS_DIR + "ExpBtnGather.png", "image/png"),
  icoCenter:  fileToUri(ICONS_DIR + "ExpBtnCenter.png", "image/png"),
  icoGear:    fileToUri(ICONS_DIR + "ExpBtnSettings.png", "image/png"),
  icoMax:     fileToUri(ICONS_DIR + "ExpBtnMax.png", "image/png"),
  icoHelp:    fileToUri(ICONS_DIR + "ExpPinTurnIn.png", "image/png"),
};

// ------------------------------------------------------------------ SVG Builders (Azaath + Númenor)
const f = (n) => (+n).toFixed(2);
const rad = (d) => d * Math.PI / 180;
const at = (cx, cy, r, d) => [cx + r * Math.cos(rad(d - 90)), cy + r * Math.sin(rad(d - 90))];
const diamondPts = (cx, cy, rx, ry = rx) =>
  `${f(cx)},${f(cy - ry)} ${f(cx + rx)},${f(cy)} ${f(cx)},${f(cy + ry)} ${f(cx - rx)},${f(cy)}`;
const octPts = (cx, cy, r, cut = 0.36) => {
  const c = r * cut;
  return [
    [cx - r + c, cy - r], [cx + r - c, cy - r],
    [cx + r, cy - r + c], [cx + r, cy + r - c],
    [cx + r - c, cy + r], [cx - r + c, cy + r],
    [cx - r, cy + r - c], [cx - r, cy - r + c],
  ].map((p) => p.map(f).join(",")).join(" ");
};
function facet(cx, cy, rx, ry, cols) {
  const T = [cx, cy - ry], R = [cx + rx, cy], B = [cx, cy + ry], L = [cx - rx, cy], C = [cx, cy];
  const tri = (a, b, c, col) => `<polygon points="${a.map(f)} ${b.map(f)} ${c.map(f)}" fill="${col}"/>`;
  return tri(L, T, C, cols[0]) + tri(T, R, C, cols[1]) + tri(R, B, C, cols[2]) + tri(B, L, C, cols[3]);
}

const G = "#c9a86b", GL = "#f3dca6", GD = "#6e5630";
const CY = "#4dd9f2", CYL = "#a8f7ff", CYD = "#156d85";
const AM = "#f5c761", AML = "#fff0bf", AMD = "#9c6816";
const AU = "#9e8152", AUL = "#d8c092", AUD = "#4d3d23", AUB = "#f2d8a7";
const AGL = "#dce3eb", AGD = "#3d444d", EMB = "#d97a2b", EMBL = "#f7c77e", EMBD = "#5e2206";

const RUNES_AZ = [
  "M0 -5 V5 M0 -5 L3 -2 M0 0 L-3 3", "M-3 -5 V5 M-3 -1 L3 -5 M-3 -1 L3 5",
  "M0 -5 L3 0 L0 5 L-3 0 Z", "M-3 -5 L3 5 M3 -5 L-3 5 M-3 0 H3",
  "M0 -5 V5 M-3 -2 L0 -5 L3 -2", "M-3 5 V-5 L3 -1 L-3 2",
  "M-3 -4 H3 M0 -4 V5 M-3 5 H3", "M-3 -5 L0 0 L3 -5 M0 0 V5",
];
const RUNES_ELV = [
  "M-2 -4 C0 -5 2 -3 2 0 C2 3 0 4 -2 4 M-2 -4 V5",
  "M-3 -3 C-1 -5 3 -4 3 0 C3 3 0 4 -2 2 M0 -5 V4",
  "M-2 4 V-3 C-2 -5 2 -5 2 -2 V4 M-3 0 H3",
  "M0 -5 L3 0 L0 5 L-3 0 Z M0 -2 V2",
  "M-3 -4 L0 -1 L3 -4 M0 -1 V5",
  "M-2 -4 C2 -4 2 0 -2 0 C2 0 2 4 -2 4",
  "M-3 4 C-3 -2 0 -5 3 -2 C3 2 0 4 -1 1",
  "M0 -5 V5 M-3 -2 C0 -4 3 -2 3 1",
];

const svgWrap = (w, h, body) => `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg"><defs>
  <filter id="gCy" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="2.2" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <filter id="gEm" x="-60%" y="-60%" width="220%" height="220%"><feGaussianBlur stdDeviation="2.0" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
  <linearGradient id="goldM" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${GL}"/><stop offset=".45" stop-color="${G}"/><stop offset="1" stop-color="${GD}"/></linearGradient>
  <linearGradient id="goldB" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#fff0c6"/><stop offset=".5" stop-color="${GL}"/><stop offset="1" stop-color="${G}"/></linearGradient>
  <linearGradient id="antG" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${AUL}"/><stop offset=".45" stop-color="${AU}"/><stop offset="1" stop-color="${AUD}"/></linearGradient>
  <radialGradient id="obsW" cx=".5" cy=".42" r=".55"><stop offset="0" stop-color="#111b26"/><stop offset="1" stop-color="#05080d"/></radialGradient>
  <radialGradient id="cyW" cx=".5" cy=".5" r=".55"><stop offset="0" stop-color="${CY}" stop-opacity=".35"/><stop offset="1" stop-color="#081a24" stop-opacity=".95"/></radialGradient>
  <radialGradient id="cyH" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="${CYL}" stop-opacity=".75"/><stop offset=".45" stop-color="${CY}" stop-opacity=".32"/><stop offset="1" stop-color="${CY}" stop-opacity="0"/></radialGradient>
  <radialGradient id="emH" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="${EMBL}" stop-opacity=".68"/><stop offset=".45" stop-color="${EMB}" stop-opacity=".28"/><stop offset="1" stop-color="${EMB}" stop-opacity="0"/></radialGradient>
  <radialGradient id="emW" cx=".5" cy=".5" r=".58"><stop offset="0" stop-color="${EMB}" stop-opacity=".30"/><stop offset="1" stop-color="#170b04" stop-opacity=".95"/></radialGradient>
  <linearGradient id="bdgG" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${AML}"/><stop offset=".45" stop-color="${AM}"/><stop offset="1" stop-color="${AMD}"/></linearGradient>
</defs>${body}</svg>`;

const SVG_ITEMS = {};

// --- Peças Azaath Arcano
{
  const wing = (dir) => {
    const x0 = dir < 0 ? 124 : 4;
    return `
      <path d="M${x0} 10 C${x0 + dir * 40} 8 ${x0 + dir * 70} 20 ${x0 + dir * 112} 32 C${x0 + dir * 70} 44 ${x0 + dir * 40} 56 ${x0} 54 Z" fill="#070c12" stroke="url(#goldM)" stroke-width="2.2"/>
      <path d="M${x0 + dir * 10} 18 C${x0 + dir * 36} 20 ${x0 + dir * 58} 26 ${x0 + dir * 92} 32 C${x0 + dir * 58} 38 ${x0 + dir * 36} 44 ${x0 + dir * 10} 46" fill="none" stroke="${CY}" stroke-width="1.3" opacity=".82"/>
      <g filter="url(#gCy)">${facet(x0 + dir * 36, 32, 13, 10, ["#e4fcff", CY, CYD, "#7cecf9"])}<polygon points="${diamondPts(x0 + dir * 36, 32, 13, 10)}" fill="none" stroke="${CYL}" stroke-width="1"/></g>`;
  };
  SVG_ITEMS.AzWingL = svgWrap(128, 64, wing(-1));
  SVG_ITEMS.AzWingR = svgWrap(128, 64, wing(1));

  let cr = "";
  for (let d = 0; d < 360; d += 90) { const [x, y] = at(32, 32, 28, d); cr += `<polygon points="${diamondPts(x, y, 2.5)}" fill="${GL}"/>`; }
  SVG_ITEMS.AzSocket = svgWrap(64, 64, `<circle cx="32" cy="32" r="28" fill="url(#obsW)" stroke="url(#goldM)" stroke-width="2.6"/><circle cx="32" cy="32" r="23" fill="none" stroke="${GD}" stroke-width="1.1"/>${cr}`);

  let ar = `<circle cx="64" cy="64" r="58" fill="url(#cyH)" opacity=".92"/><circle cx="64" cy="64" r="46" fill="none" stroke="${CYL}" stroke-width="1.4" stroke-dasharray="9 5 3 5" opacity=".75"/>`;
  for (let i = 0; i < 8; i++) { const [x, y] = at(64, 64, 39, i * 45 + 22.5); ar += `<path d="${RUNES_AZ[i]}" transform="translate(${f(x)} ${f(y)}) rotate(${f(i * 45 + 22.5)}) scale(.8)" fill="none" stroke="${CYL}" stroke-width="1.4" stroke-linecap="round"/>`; }
  SVG_ITEMS.AzActiveRing = svgWrap(128, 128, ar);

  SVG_ITEMS.AzToggle = svgWrap(64, 64, `
    <polygon points="${diamondPts(32, 32, 27, 27)}" fill="#060b12" stroke="url(#goldB)" stroke-width="2.2"/>
    <polygon points="${diamondPts(32, 32, 21, 21)}" fill="url(#cyW)" stroke="${CY}" stroke-width="1.4"/>
    ${facet(32, 4, 4, 4, [AML, AM, AMD, "#d99d34"])}${facet(32, 60, 4, 4, [AML, AM, AMD, "#d99d34"])}`);

  SVG_ITEMS.AzBadge = svgWrap(32, 32, `<circle cx="16" cy="16" r="13.5" fill="url(#bdgG)" stroke="${GL}" stroke-width="1.6"/>`);
  SVG_ITEMS.AzGem = svgWrap(32, 32, `<g filter="url(#gCy)">${facet(16, 16, 10, 11, ["#e4fcff", CY, CYD, "#7cecf9"])}<polygon points="${diamondPts(16, 16, 10, 11)}" fill="none" stroke="${CYL}" stroke-width="1.1"/></g>`);
  SVG_ITEMS.AzCorner = svgWrap(32, 32, `
    <path d="M2 30 V8 L8 2 H30" fill="none" stroke="${GL}" stroke-width="2"/>
    <path d="M8 26 V12 L12 8 H26" fill="none" stroke="${G}" stroke-width="1" opacity=".75"/>
    ${facet(7, 7, 4, 4, ["#e4fcff", CY, CYD, "#7cecf9"])}`);
}

// --- Peças Forja de Númenor
{
  const nWing = (dir) => {
    const x0 = dir < 0 ? 124 : 4;
    return `
      <polygon points="${x0},8 ${x0 + dir * 34},17 ${x0 + dir * 114},32 ${x0 + dir * 34},47 ${x0},56" fill="#0a0c0e" stroke="url(#antG)" stroke-width="1.8"/>
      <polyline points="${x0 + dir * 8},19 ${x0 + dir * 82},32 ${x0 + dir * 8},45" fill="none" stroke="${AUD}" stroke-width="1.1"/>
      <g filter="url(#gEm)">${facet(x0 + dir * 30, 32, 7.5, 7.5, [EMBL, EMB, EMBD, "#a84c12"])}<polygon points="${diamondPts(x0 + dir * 30, 32, 7.5, 7.5)}" fill="none" stroke="${AUL}" stroke-width=".9"/></g>`;
  };
  SVG_ITEMS.NumWingL = svgWrap(128, 64, nWing(-1));
  SVG_ITEMS.NumWingR = svgWrap(128, 64, nWing(1));

  SVG_ITEMS.NumSocket = svgWrap(64, 64, `
    <path d="M6 48 V18 C6 10 32 3 32 3 C32 3 58 10 58 18 V48" fill="none" stroke="${AUD}" stroke-width="1.2" opacity=".7"/>
    <polygon points="${octPts(32, 32, 27, 0.36)}" fill="#0b0d10" stroke="url(#antG)" stroke-width="1.8"/>
    <polygon points="${octPts(32, 32, 23, 0.36)}" fill="none" stroke="${AUD}" stroke-width=".9"/>`);

  let nr = `<circle cx="64" cy="64" r="56" fill="url(#emH)" opacity=".9"/><line x1="64" y1="6" x2="64" y2="122" stroke="${EMB}" stroke-width="1.6" opacity=".75"/>
    <circle cx="64" cy="64" r="44" fill="none" stroke="${EMB}" stroke-width="1.4"/><circle cx="64" cy="64" r="49" fill="none" stroke="${EMBL}" stroke-width=".7" stroke-dasharray="4 5" opacity=".65"/>`;
  for (let i = 0; i < 10; i++) { const [x, y] = at(64, 64, 44, i * 36 + 18); nr += `<path d="${RUNES_ELV[i % RUNES_ELV.length]}" transform="translate(${f(x)} ${f(y)}) rotate(${f(i * 36 + 18)}) scale(.75)" fill="none" stroke="${EMBL}" stroke-width="1.3" stroke-linecap="round"/>`; }
  SVG_ITEMS.NumActiveRing = svgWrap(128, 128, nr);

  SVG_ITEMS.NumToggle = svgWrap(64, 64, `
    <polygon points="${diamondPts(32, 32, 18, 28)}" fill="#0a0c0f" stroke="url(#antG)" stroke-width="1.8"/>
    <polygon points="${diamondPts(32, 32, 13, 21)}" fill="url(#emW)" stroke="${AUD}" stroke-width="1"/>
    <polygon points="${diamondPts(32, 3, 2.8, 3.5)}" fill="${AUL}"/><polygon points="${diamondPts(32, 61, 2.8, 3.5)}" fill="${AUL}"/>`);

  SVG_ITEMS.NumBadge = svgWrap(32, 32, `<polygon points="${diamondPts(16, 16, 13, 13)}" fill="#07080a" stroke="${AU}" stroke-width="1.5"/><polygon points="${diamondPts(16, 16, 10, 10)}" fill="none" stroke="${AUD}" stroke-width=".8"/>`);
  SVG_ITEMS.NumGem = svgWrap(32, 32, `<g filter="url(#gEm)">${facet(16, 16, 8, 11, [EMBL, EMB, EMBD, "#a84c12"])}<polygon points="${diamondPts(16, 16, 8, 11)}" fill="none" stroke="${AUL}" stroke-width="1"/></g>`);
  SVG_ITEMS.NumCorner = svgWrap(32, 32, `<path d="M2 30 V10 L10 2 H30" fill="none" stroke="${AUL}" stroke-width="1.8"/><path d="M7 25 V12 L12 7 H25" fill="none" stroke="${AUD}" stroke-width="1"/><polygon points="${diamondPts(9, 9, 2.5)}" fill="${AUL}"/>`);
  SVG_ITEMS.NumCrest = svgWrap(128, 32, `<line x1="4" y1="16" x2="124" y2="16" stroke="${AUL}" stroke-width="1.4"/><polygon points="${diamondPts(64, 16, 26, 8)}" fill="#0b0d10" stroke="${AUL}" stroke-width="1.3"/>${facet(64, 16, 6, 6, [EMBL, EMB, EMBD, "#a84c12"])}`);

  // 16 ícones gravados a buril (prata de mithril + bronze oxidado; tintados pelo jogo no ativo!)
  const pri = AGL, sec = AUL, dim = AGD;
  const ETCH = {
    Character: `<path d="M0 -13 L-4 -9 L-6 -1 V7 L0 12 L6 7 V-1 L4 -9 Z" fill="#111418" stroke="${pri}" stroke-width="1.25"/><path d="M0 -13 V12 M-5 -2 H5" stroke="${sec}" stroke-width="1.05"/><path d="M-5 -2 L-2 1 H-5 M5 -2 L2 1 H5" fill="#050608" stroke="${pri}" stroke-width=".75"/><path d="M-5 -5 C-9 -8 -12 -12 -11 -13 C-10 -9 -8 -5 -6 -1 M5 -5 C9 -8 12 -12 11 -13 C10 -9 8 -5 6 -1" fill="none" stroke="${sec}" stroke-width="1.1"/>`,
    Spellbook: `<polygon points="-10,-11 9,-11 11,-9 11,9 9,11 -10,11" fill="#0d0f12" stroke="${pri}" stroke-width="1.15"/><line x1="-6" y1="-11" x2="-6" y2="11" stroke="${sec}" stroke-width="1"/><rect x="8" y="-3" width="4" height="6" fill="#0d0f12" stroke="${sec}" stroke-width="1"/><polygon points="2,-6 3.2,-1.2 8,0 3.2,1.2 2,6 0.8,1.2 -4,0 0.8,-1.2" fill="none" stroke="${pri}" stroke-width="1.05"/>`,
    Talents: `<path d="M0 11 V-2 M0 8 C-3 10 -7 11 -10 11 M0 8 C3 10 7 11 10 11 M0 2 C-4 0 -8 -3 -9 -7 M0 2 C4 0 8 -3 9 -7 M0 -2 C-2 -5 -4 -8 -4 -11 M0 -2 C2 -5 4 -8 4 -11" fill="none" stroke="${pri}" stroke-width="1.2" stroke-linecap="round"/><circle cx="0" cy="-11" r="1.8" fill="${pri}"/><circle cx="-9" cy="-7" r="1.5" fill="${sec}"/><circle cx="9" cy="-7" r="1.5" fill="${sec}"/><circle cx="0" cy="-3" r="6.8" fill="none" stroke="${sec}" stroke-width=".7" stroke-dasharray="2 2.5"/>`,
    Drops: `<polygon points="-9,-5 0,-11 9,-5 9,9 -9,9" fill="#0e1013" stroke="${pri}" stroke-width="1.15"/><line x1="-9" y1="-2" x2="9" y2="-2" stroke="${sec}" stroke-width="1.05"/><polygon points="${diamondPts(0, 1, 3.2, 4.4)}" fill="#08090b" stroke="${sec}" stroke-width="1"/><circle cx="0" cy="1" r="1.2" fill="${pri}"/>`,
    Dungeons: `<path d="M-10 11 V-1 C-10 -9 0 -13 0 -13 C0 -13 10 -9 10 -1 V11" fill="#0b0c0e" stroke="${pri}" stroke-width="1.2"/><path d="M-7 11 V0 C-7 -6 0 -9.5 0 -9.5 C0 -9.5 7 -6 7 0 V11" fill="none" stroke="${sec}" stroke-width=".85"/><line x1="-3.5" y1="-7" x2="-3.5" y2="11" stroke="${dim}" stroke-width=".85"/><line x1="3.5" y1="-7" x2="3.5" y2="11" stroke="${dim}" stroke-width=".85"/><polygon points="0,-6 1.8,1 0,8 -1.8,1" fill="${sec}" stroke="${pri}" stroke-width=".65"/>`,
    Achievements: `<circle cx="0" cy="1" r="9.5" fill="none" stroke="${sec}" stroke-width=".85" stroke-dasharray="3 2"/><polygon points="0,-10 2.1,-2.6 9.5,-2.4 3.6,2.1 5.8,9.2 0,4.9 -5.8,9.2 -3.6,2.1 -9.5,-2.4 -2.1,-2.6" fill="none" stroke="${pri}" stroke-width="1.15"/><polygon points="${diamondPts(0, 1, 2.5, 2.5)}" fill="${sec}"/>`,
    Quests: `<polygon points="-7,-10 7,-10 7,9 0,12 -7,9" fill="#0d0f12" stroke="${pri}" stroke-width="1.1"/><line x1="-4" y1="-5" x2="4" y2="-5" stroke="${dim}" stroke-width=".85"/><line x1="-4" y1="-1" x2="4" y2="-1" stroke="${dim}" stroke-width=".85"/><line x1="9" y1="-11" x2="-3" y2="5" stroke="${pri}" stroke-width="1.45" stroke-linecap="round"/><line x1="3.5" y1="-8.5" x2="7.5" y2="-4.5" stroke="${sec}" stroke-width="1.25"/>`,
    Social: `<circle cx="0" cy="-2" r="7.5" fill="none" stroke="${dim}" stroke-width=".9"/><line x1="-9" y1="10" x2="9" y2="-10" stroke="${pri}" stroke-width="1.35" stroke-linecap="round"/><line x1="9" y1="10" x2="-9" y2="-10" stroke="${pri}" stroke-width="1.35" stroke-linecap="round"/><line x1="-8" y1="4.5" x2="-4.5" y2="8" stroke="${sec}" stroke-width="1.25"/><line x1="8" y1="4.5" x2="4.5" y2="8" stroke="${sec}" stroke-width="1.25"/>`,
    Guild: `<polygon points="-8,-10 8,-10 9,2 0,12 -9,2" fill="#0d0f12" stroke="${pri}" stroke-width="1.2"/><line x1="0" y1="-7" x2="0" y2="8" stroke="${pri}" stroke-width="1.05"/><polygon points="${diamondPts(0, -1, 3.5, 3.5)}" fill="none" stroke="${sec}" stroke-width="1.05"/>`,
    GroupFinder: `<polygon points="-7,11 -4,4 4,4 7,11" fill="#0d0f12" stroke="${pri}" stroke-width="1.1"/><line x1="-9" y1="4" x2="9" y2="4" stroke="${sec}" stroke-width="1.25"/><path d="M0 -12 C3 -7 6 -3 4 3 C2 1 1 -1 0 -3 C-1 -1 -2 1 -4 3 C-6 -3 -3 -7 0 -12 Z" fill="none" stroke="${pri}" stroke-width="1.2"/>`,
    Collections: `<path d="M-5 11 L-4 2 L-8 -1 L-3 -9 L3 -11 L5 -7 L10 -5 L8 -1 L3 -2 L4 5 L6 11" fill="#0d0f12" stroke="${pri}" stroke-width="1.2" stroke-linejoin="round"/><path d="M-3 -9 C-8 -6 -9 0 -6 6" fill="none" stroke="${sec}" stroke-width="1.15"/><circle cx="3.5" cy="-6.5" r="1" fill="${pri}"/>`,
    ToggleClose: `<polygon points="${diamondPts(0, 0, 5.5, 9)}" fill="none" stroke="${AUL}" stroke-width="1.3"/><line x1="-7" y1="0" x2="7" y2="0" stroke="${EMBL}" stroke-width="1.15"/><circle cx="0" cy="0" r="2.1" fill="${EMBL}"/>`,
    ToggleOpen: `<polygon points="${diamondPts(0, 0, 9, 5.5)}" fill="none" stroke="${AUL}" stroke-width="1.3"/><line x1="0" y1="-7" x2="0" y2="7" stroke="${EMBL}" stroke-width="1.15"/><circle cx="0" cy="0" r="2.1" fill="${EMBL}"/>`,
    Map: `<circle cx="0" cy="0" r="10.5" fill="none" stroke="${sec}" stroke-width=".95"/><polygon points="0,-12 1.8,-1.8 12,0 1.8,1.8 0,12 -1.8,1.8 -12,0 -1.8,-1.8" fill="none" stroke="${pri}" stroke-width="1.1"/><circle cx="0" cy="0" r="1.9" fill="${sec}"/>`,
    Help: `<path d="M-7 10 V-1 C-7 -7 0 -11 0 -11 C0 -11 7 -7 7 -1 V10" fill="none" stroke="${sec}" stroke-width="1.05"/><line x1="-9" y1="10" x2="9" y2="10" stroke="${pri}" stroke-width="1.15"/><polygon points="0,-7 1.3,-1.3 6,0 1.3,1.3 0,6 -1.3,1.3 -6,0 -1.3,-1.3" fill="none" stroke="${pri}" stroke-width="1.05"/>`,
    Menu: `<circle cx="0" cy="0" r="9.5" fill="none" stroke="${pri}" stroke-width="1.9" stroke-dasharray="2.4 2.2"/><circle cx="0" cy="0" r="6.8" fill="#0b0d10" stroke="${sec}" stroke-width="1.05"/><polygon points="${diamondPts(0, 0, 2.8, 2.8)}" fill="${pri}"/>`,
  };
  for (const [k, path] of Object.entries(ETCH)) {
    SVG_ITEMS["Num_" + k] = svgWrap(64, 64, `<g transform="translate(32 32) scale(1.88)">${path}</g>`);
  }
}

// ------------------------------------------------------------------ HTML Executor (SVG + Canvas Pintados)
const html = `<!doctype html><html><head><meta charset="utf-8"></head><body><script>
"use strict";
const ASSETS = ${JSON.stringify(ASSETS)};
const SVGS = ${JSON.stringify(SVG_ITEMS)};

function loadImg(src) {
  return new Promise((ok, no) => { const i = new Image(); i.onload = () => ok(i); i.onerror = no; i.src = src; });
}
function cleanDarkBg(img, sx, sy, sw, sh, thresh = 25) {
  const c = document.createElement("canvas"); c.width = sw; c.height = sh;
  const cx = c.getContext("2d"); cx.drawImage(img, sx, sy, sw, sh, 0, 0, sw, sh);
  const id = cx.getImageData(0, 0, sw, sh); const d = id.data;
  const vis = new Uint8Array(sw * sh); const st = [];
  for (let x = 0; x < sw; x++) { st.push(x); st.push((sh - 1) * sw + x); }
  for (let y = 0; y < sh; y++) { st.push(y * sw); st.push(y * sw + (sw - 1)); }
  const isBg = (i) => Math.max(d[i * 4], d[i * 4 + 1], d[i * 4 + 2]) < thresh;
  while (st.length) {
    const p = st.pop(); if (vis[p] || !isBg(p)) continue; vis[p] = 1; d[p * 4 + 3] = 0;
    const x = p % sw, y = (p / sw) | 0;
    if (x > 0) st.push(p - 1); if (x < sw - 1) st.push(p + 1);
    if (y > 0) st.push(p - sw); if (y < sh - 1) st.push(p + sw);
  }
  for (let y = 1; y < sh - 1; y++) for (let x = 1; x < sw - 1; x++) {
    const p = y * sw + x; if (vis[p]) continue;
    if (vis[p - 1] || vis[p + 1] || vis[p - sw] || vis[p + sw]) {
      const lum = Math.max(d[p * 4], d[p * 4 + 1], d[p * 4 + 2]);
      if (lum < thresh * 2.5) d[p * 4 + 3] = Math.round(d[p * 4 + 3] * Math.max(0.2, lum / (thresh * 2.5)));
    }
  }
  cx.putImageData(id, 0, 0); return c;
}
function packRgba(cv) {
  const u8 = new Uint8Array(cv.getContext("2d").getImageData(0, 0, cv.width, cv.height).data.buffer);
  let bin = ""; const CH = 0x8000;
  for (let i = 0; i < u8.length; i += CH) bin += String.fromCharCode.apply(null, u8.subarray(i, i + CH));
  return { w: cv.width, h: cv.height, b64: btoa(bin) };
}
function makeCanvas(w, h, fn) {
  const c = document.createElement("canvas"); c.width = w; c.height = h;
  const g = c.getContext("2d"); g.imageSmoothingQuality = "high";
  fn(g, w, h); return c;
}
function drawSlotTex(w, h, active) {
  return makeCanvas(w, h, (g) => {
    const r = 8, arch = 9;
    const path = (x, y, pw, ph) => {
      g.beginPath(); g.moveTo(x + r, y + arch); g.quadraticCurveTo(x + pw / 2, y - arch * 0.2, x + pw - r, y + arch);
      g.lineTo(x + pw, y + arch + r); g.lineTo(x + pw, y + ph - r); g.arcTo(x + pw, y + ph, x + pw - r, y + ph, r);
      g.lineTo(x + r, y + ph); g.arcTo(x, y + ph, x, y + ph - r, r); g.lineTo(x, y + arch + r); g.closePath();
    };
    path(1, 2, w - 2, h - 4);
    const bg = g.createLinearGradient(0, 0, 0, h);
    if (active) { bg.addColorStop(0, "#1c1306"); bg.addColorStop(0.5, "#3b270b"); bg.addColorStop(1, "#5c3b0e"); }
    else { bg.addColorStop(0, "#24211e"); bg.addColorStop(0.55, "#151413"); bg.addColorStop(1, "#0d0c0b"); }
    g.fillStyle = bg; g.fill();
    g.save(); path(3, 4, w - 6, h - 8); g.clip();
    if (active) {
      const sh = g.createLinearGradient(0, 0, 0, h * 0.45); sh.addColorStop(0, "rgba(0,0,0,0.85)"); sh.addColorStop(1, "rgba(0,0,0,0)");
      g.fillStyle = sh; g.fillRect(0, 0, w, h * 0.45);
    } else {
      const hi = g.createLinearGradient(0, 0, 0, h * 0.35); hi.addColorStop(0, "rgba(255,235,190,0.22)"); hi.addColorStop(1, "rgba(255,235,190,0)");
      g.fillStyle = hi; g.fillRect(0, 0, w, h * 0.35);
    }
    g.restore();
    path(1.5, 2.5, w - 3, h - 5);
    const rim = g.createLinearGradient(0, 0, 0, h);
    if (active) { rim.addColorStop(0, "#ffe97a"); rim.addColorStop(0.5, "#ffd100"); rim.addColorStop(1, "#a67114"); }
    else { rim.addColorStop(0, "#b89b6a"); rim.addColorStop(0.45, "#6b5941"); rim.addColorStop(1, "#332c24"); }
    g.strokeStyle = rim; g.lineWidth = active ? 3.2 : 2.2; g.stroke();
    g.fillStyle = active ? "#ffd100" : "#cfa966";
    g.beginPath(); g.arc(w / 2, arch * 0.48, 2.4, 0, Math.PI * 2); g.fill();
  });
}
function fitSquare(src, size = 64, pad = 4) {
  return makeCanvas(size, size, (g) => {
    const m = size - pad * 2, sc = Math.min(m / src.width, m / src.height);
    const dw = src.width * sc, dh = src.height * sc;
    g.drawImage(src, (size - dw) / 2, (size - dh) / 2, dw, dh);
  });
}

(async () => {
  const out = {};
  // 1) Rasterizar todos os SVGs (Azaath + Númenor)
  for (const [k, svg] of Object.entries(SVGS)) {
    const im = await loadImg("data:image/svg+xml;charset=utf-8," + encodeURIComponent(svg));
    out[k] = packRgba(makeCanvas(im.width, im.height, (g) => g.drawImage(im, 0, 0)));
  }

  // 2) Extrair e pintar peças do estilo Mesa de RPG (WoW)
  const raw = {};
  for (const [k, v] of Object.entries(ASSETS)) raw[k] = await loadImg(v);

  out.WowRail = packRgba(makeCanvas(256, 64, (g) => {
    g.drawImage(raw.chrome, 460, 1052, 560, 64, 0, 0, 256, 64);
    g.fillStyle = "rgba(8,7,6,0.45)"; g.fillRect(0, 8, 256, 48);
  }));
  out.WowCapL = packRgba(makeCanvas(64, 64, (g) => g.drawImage(raw.chrome, 0, 0, 155, 155, 0, 0, 64, 64)));
  out.WowCapR = packRgba(makeCanvas(64, 64, (g) => g.drawImage(raw.chrome, 1845, 0, 155, 155, 0, 0, 64, 64)));
  out.WowCorner = out.WowCapL;
  out.WowSlot = packRgba(drawSlotTex(64, 128, false));
  out.WowSlotActive = packRgba(drawSlotTex(64, 128, true));

  out.WowToggle = packRgba(makeCanvas(64, 128, (g) => {
    const r = 8;
    g.save(); g.beginPath(); g.roundRect(4, 4, 56, 120, r); g.clip();
    g.drawImage(raw.leatherTab, 0, 0, 128, 64, -10, 0, 96, 128);
    g.restore();
    g.beginPath(); g.roundRect(4, 4, 56, 120, r);
    g.strokeStyle = "#b89050"; g.lineWidth = 3; g.stroke();
  }));
  out.WowArrows = packRgba(fitSquare(raw.icoMax, 64, 8));
  out.WowBadge = packRgba(makeCanvas(32, 32, (g) => {
    const bg = g.createRadialGradient(12, 12, 1, 16, 16, 14);
    bg.addColorStop(0, "#e33946"); bg.addColorStop(1, "#6b0e17");
    g.fillStyle = bg; g.beginPath(); g.arc(16, 16, 13.5, 0, Math.PI * 2); g.fill();
    g.strokeStyle = "#f2cf7e"; g.lineWidth = 2; g.stroke();
  }));
  out.WowParchment = packRgba(makeCanvas(256, 256, (g) => {
    g.drawImage(raw.bgTable, 690, 350, 560, 740, 0, 0, 256, 256);
    const pv = g.createRadialGradient(128, 128, 60, 128, 128, 180);
    pv.addColorStop(0, "rgba(255,244,214,0.06)"); pv.addColorStop(1, "rgba(42,24,10,0.45)");
    g.fillStyle = pv; g.fillRect(0, 0, 256, 256);
  }));
  out.WowPlaque = packRgba(makeCanvas(256, 64, (g) => {
    const pl = cleanDarkBg(raw.refFrames, 36, 632, 300, 92, 26);
    g.drawImage(pl, 0, 0, 256, 64);
  }));
  out.WowTab = packRgba(makeCanvas(128, 64, (g) => {
    g.translate(128, 0); g.scale(-1, 1);
    g.drawImage(raw.leatherTab, 0, 0, 128, 64, 0, 0, 128, 64);
  }));
  const goldStar = cleanDarkBg(raw.refRings, 1044, 500, 112, 108, 22);
  out.WowSeal = packRgba(makeCanvas(64, 64, (g) => {
    const gr = g.createRadialGradient(26, 26, 2, 32, 32, 24);
    gr.addColorStop(0, "#d9303e"); gr.addColorStop(0.65, "#87111c"); gr.addColorStop(1, "#45060c");
    g.fillStyle = gr; g.beginPath(); g.arc(32, 32, 20, 0, Math.PI * 2); g.fill();
    g.drawImage(raw.grimSeal, 4, 4, 56, 56);
    g.drawImage(goldStar, 20, 20, 24, 24);
  }));
  out.WowMedal = packRgba(makeCanvas(64, 64, (g) => g.drawImage(raw.grimMedal, 0, 0, 64, 64)));

  // 14 ícones 3D pintados Wow_<Icon>
  const dropCell = (idx) => {
    const c = document.createElement("canvas"); c.width = 128; c.height = 128;
    c.getContext("2d").drawImage(raw.dropCats, (idx % 4) * 128, Math.floor(idx / 4) * 128, 128, 128, 0, 0, 128, 128);
    return c;
  };
  const hw = Math.floor(raw.helmets.width / 4), hh = Math.floor(raw.helmets.height / 2);
  const helmCell = (idx) => cleanDarkBg(raw.helmets, (idx % 4) * hw, Math.floor(idx / 4) * hh, hw, hh, 24);
  const WOW_SPR = {
    Character:    dropCell(1),
    Spellbook:    raw.icoLore,
    Talents:      dropCell(0),
    Drops:        dropCell(5),
    Dungeons:     raw.icoClose,
    Achievements: helmCell(4),
    Quests:       raw.icoQuests,
    Social:       dropCell(6),
    Guild:        dropCell(4),
    GroupFinder:  raw.icoGather,
    Collections:  helmCell(0),
    Map:          raw.icoCenter,
    Help:         raw.icoHelp,
    Menu:         raw.icoGear,
  };
  for (const [k, spr] of Object.entries(WOW_SPR)) {
    out["Wow_" + k] = packRgba(fitSquare(spr, 64, 4));
  }

  const pre = document.createElement("pre");
  pre.id = "out";
  pre.textContent = JSON.stringify(out);
  document.body.appendChild(pre);
})();
</script></body></html>`;

const tmpHtml = path.join(DIR, "_export_tga.html");
fs.writeFileSync(tmpHtml, html, "utf8");
const prof = path.join(require("os").tmpdir(), "azaath_export_tga_" + Date.now());
const res = spawnSync(EDGE, [
  "--headless=new",
  "--disable-gpu",
  "--user-data-dir=" + prof,
  "--allow-file-access-from-files",
  "--virtual-time-budget=30000",
  "--dump-dom",
  "file:///" + tmpHtml.replace(/\\/g, "/"),
], { encoding: "utf8", maxBuffer: 1 << 26 });
fs.unlinkSync(tmpHtml);

if (res.error) throw res.error;
if (res.status !== 0) {
  console.error("Edge stderr:", res.stderr);
  process.exit(1);
}
const m = res.stdout.match(/<pre[^>]*id="out"[^>]*>([\s\S]*?)<\/pre>/i);
if (!m) {
  console.error("Não encontrou <pre id=\"out\"> (rode fora do sandbox se o Edge bloquear).");
  process.exit(1);
}

const payload = JSON.parse(m[1].trim());
fs.mkdirSync(OUT_DIR, { recursive: true });
let count = 0;
for (const [name, obj] of Object.entries(payload)) {
  const buf = Buffer.from(obj.b64, "base64");
  writeTGA(path.join(OUT_DIR, name + ".tga"), { w: obj.w, h: obj.h, data: new Uint8ClampedArray(buf) }, true);
  count++;
}
console.log(`${count} texturas .tga gravadas em ${OUT_DIR}`);
