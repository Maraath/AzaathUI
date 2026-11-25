// Arte conceitual do Micro Menu no estilo Azaath (SVG -> Edge Headless -> PNG 2x).
// Compara o visual atual (BDO minimalista) com a nova proposta Azaath (moldura bronze/ouro,
// engastes rúnicos, cristais ciano, divisor losangular, gemas de badge e placar arcano).
// Uso: node tools/micromenu-concept/gen.js
"use strict";
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const { spawnSync } = require("child_process");
const { readTGA } = require("../map-extract/imagecodec.js");

const DIR = __dirname;
const ROOT = path.resolve(DIR, "../..");
const MEDIA_DIR = path.join(ROOT, "AzaathUI", "Media", "MicroMenu");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const SCALE = 2;
const W = 1400, H = 860;

// Paleta Azaath
const G = "#c9a86b", GL = "#f3dca6", GD = "#6e5630", GB = "#3e2f19";
const CY = "#4dd9f2", CYL = "#a8f7ff", CYD = "#156d85";
const AM = "#f5c761", AML = "#fff0bf", AMD = "#9c6816";
const BG = "#06090e", OBS = "#090f17", TXT = "#e8f3f8", MUTED = "#8aa5b5";

const f = (n) => (+n).toFixed(2);
const rad = (d) => d * Math.PI / 180;
const at = (cx, cy, r, d) => [cx + r * Math.cos(rad(d - 90)), cy + r * Math.sin(rad(d - 90))];

// ------------------------------------------------------------------ TGA -> Data URI PNG (com tint opcional)
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
function hexToRgb(hex) {
  const m = hex.replace("#", "");
  return [parseInt(m.slice(0, 2), 16), parseInt(m.slice(2, 4), 16), parseInt(m.slice(4, 6), 16)];
}
const iconCache = {};
function loadIconUri(name, tintHex = "#ffffff") {
  const key = `${name}:${tintHex}`;
  if (iconCache[key]) return iconCache[key];
  const img = readTGA(path.join(MEDIA_DIR, name + ".tga"));
  const [tr, tg, tb] = hexToRgb(tintHex);
  const raw = Buffer.alloc((img.w * 4 + 1) * img.h);
  for (let y = 0; y < img.h; y++) {
    const rowOff = y * (img.w * 4 + 1);
    raw[rowOff] = 0;
    for (let x = 0; x < img.w; x++) {
      const s = (y * img.w + x) * 4;
      const d = rowOff + 1 + x * 4;
      raw[d] = Math.round(img.data[s] * tr / 255);
      raw[d + 1] = Math.round(img.data[s + 1] * tg / 255);
      raw[d + 2] = Math.round(img.data[s + 2] * tb / 255);
      raw[d + 3] = img.data[s + 3];
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
  const uri = "data:image/png;base64," + png.toString("base64");
  iconCache[key] = uri;
  return uri;
}

// ------------------------------------------------------------------ Helpers geométricos e runas
const diamondPts = (cx, cy, rx, ry = rx) =>
  `${f(cx)},${f(cy - ry)} ${f(cx + rx)},${f(cy)} ${f(cx)},${f(cy + ry)} ${f(cx - rx)},${f(cy)}`;

function facet(cx, cy, rx, ry, cols) {
  const T = [cx, cy - ry], R = [cx + rx, cy], B = [cx, cy + ry], L = [cx - rx, cy], C = [cx, cy];
  const tri = (a, b, c, col) => `<polygon points="${a.map(f)} ${b.map(f)} ${c.map(f)}" fill="${col}"/>`;
  return tri(L, T, C, cols[0]) + tri(T, R, C, cols[1]) + tri(R, B, C, cols[2]) + tri(B, L, C, cols[3]);
}

const cyanGem = (cx, cy, rx, ry = rx * 1.15) =>
  facet(cx, cy, rx, ry, ["#e4fcff", CY, CYD, "#7cecf9"]) +
  `<polygon points="${diamondPts(cx, cy, rx, ry)}" fill="none" stroke="${CYL}" stroke-width="0.9" opacity="0.85"/>`;

const goldGem = (cx, cy, rx, ry = rx) =>
  facet(cx, cy, rx, ry, [AML, AM, AMD, "#d99d34"]) +
  `<polygon points="${diamondPts(cx, cy, rx, ry)}" fill="none" stroke="${GL}" stroke-width="0.8" opacity="0.85"/>`;

const RUNES = [
  "M0 -5 V5 M0 -5 L3 -2 M0 0 L-3 3", "M-3 -5 V5 M-3 -1 L3 -5 M-3 -1 L3 5",
  "M0 -5 L3 0 L0 5 L-3 0 Z", "M-3 -5 L3 5 M3 -5 L-3 5 M-3 0 H3",
  "M0 -5 V5 M-3 -2 L0 -5 L3 -2", "M-3 5 V-5 L3 -1 L-3 2",
  "M-3 -4 H3 M0 -4 V5 M-3 5 H3", "M-3 -5 L0 0 L3 -5 M0 0 V5",
];
const rune = (cx, cy, i, deg, col, sc = 0.75, op = 0.85) =>
  `<path d="${RUNES[i % RUNES.length]}" transform="translate(${f(cx)} ${f(cy)}) rotate(${f(deg)}) scale(${sc})" fill="none" stroke="${col}" stroke-width="1.1" stroke-linecap="round" opacity="${op}"/>`;

// Definição dos 15 botões reais de Modules/MicroMenu.lua
const MAIN_BTNS = [
  { key: "character",    icon: "Character",    label: "Personagem" },
  { key: "spellbook",    icon: "Spellbook",    label: "Grimório" },
  { key: "talents",      icon: "Talents",      label: "Talentos", badge: "3", active: true },
  { key: "drops",        icon: "Drops",        label: "Relicário" },
  { key: "dungeons",     icon: "Dungeons",     label: "Masmorras" },
  { key: "achievements", icon: "Achievements", label: "Conquistas" },
  { key: "quests",       icon: "Quests",       label: "Missões", badge: "12" },
  { key: "social",       icon: "Social",       label: "Social", badge: "4" },
  { key: "guild",        icon: "Guild",        label: "Guilda", badge: "9" },
  { key: "lfd",          icon: "GroupFinder",  label: "Grupos" },
  { key: "collections",  icon: "Collections",  label: "Montarias" },
];
const SYS_BTNS = [
  { key: "map",  icon: "Map",  label: "Mapa" },
  { key: "help", icon: "Help", label: "Ajuda" },
  { key: "menu", icon: "Menu", label: "Sistema" },
];

// ------------------------------------------------------------------ Fundo Azaath
function drawBackground() {
  const astro = (cx, cy, R, op) => {
    let s = `<g opacity="${op}" fill="none" stroke="${G}">`;
    for (const [r, w] of [[R, 1.2], [R * 0.85, 0.7], [R * 0.60, 0.8], [R * 0.36, 0.5]]) {
      s += `<circle cx="${cx}" cy="${cy}" r="${f(r)}" stroke-width="${w}"/>`;
    }
    for (let d = 0; d < 360; d += 10) {
      const [x1, y1] = at(cx, cy, R, d), [x2, y2] = at(cx, cy, R - (d % 30 === 0 ? 12 : 5), d);
      s += `<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke-width=".7"/>`;
    }
    for (let i = 0; i < 12; i++) {
      const [x, y] = at(cx, cy, R * 0.72, i * 30 + 15);
      s += rune(x, y, i, i * 30 + 90, G, 0.9, 1);
    }
    return s + `</g>`;
  };

  return `
  <rect width="${W}" height="${H}" fill="url(#bgGrad)"/>
  <rect width="${W}" height="${H}" filter="url(#mist)" opacity="0.55"/>
  ${astro(1220, 120, 290, 0.06)}
  ${astro(140, 740, 260, 0.05)}
  <ellipse cx="700" cy="545" rx="600" ry="120" fill="url(#cyanAura)" opacity="0.28"/>
  <ellipse cx="520" cy="360" rx="340" ry="140" fill="url(#cyanAura)" opacity="0.18"/>
  <rect width="${W}" height="${H}" fill="url(#vignette)"/>
  <rect width="${W}" height="${H}" filter="url(#grain)" opacity="0.35"/>`;
}

// ------------------------------------------------------------------ Cabeçalho da Prancha
function drawHeader() {
  return `
  <g transform="translate(700, 38)">
    <text x="0" y="0" text-anchor="middle" font-family="Cinzel, Georgia, serif" font-size="13" letter-spacing="5" fill="${G}" opacity="0.9">PROJECT AZAATH · CONCEPT ART DE INTERFACE</text>
    <text x="0" y="26" text-anchor="middle" font-family="Cinzel, Georgia, serif" font-size="23" font-weight="700" letter-spacing="3" fill="${TXT}">MICRO MENU — ESTILO AZAATH</text>
    <path d="M-280 38 H-28 M28 38 H280" stroke="url(#goldLineH)" stroke-width="1.1" opacity="0.8"/>
    <g filter="url(#glowCyan)">${cyanGem(0, 38, 6, 6)}</g>
    <polygon points="${diamondPts(-34, 38, 2.5)}" fill="${GL}"/>
    <polygon points="${diamondPts(34, 38, 2.5)}" fill="${GL}"/>
  </g>`;
}

// ------------------------------------------------------------------ Seção 1: Estado Atual (BDO Minimalista)
function drawCurrentSection() {
  const cy = 148;
  const r = 15, step = 39;
  const x0 = 112;

  let s = `
  <g>
    <text x="90" y="${cy - 34}" font-family="Cinzel, Georgia, serif" font-size="11.5" letter-spacing="2.2" fill="${MUTED}">1. VISUAL ATUAL — MINIMALISTA BDO (Modules/MicroMenu.lua)</text>
    <line x1="90" y1="${cy - 26}" x2="545" y2="${cy - 26}" stroke="${MUTED}" stroke-width="0.6" opacity="0.35"/>
    <rect x="70" y="${cy - 22}" width="1260" height="58" rx="8" fill="#05080d" fill-opacity="0.55" stroke="#1b2c3b" stroke-width="0.8"/>
  `;

  // 11 principais + toggle + 3 sistema
  const all = [...MAIN_BTNS, { key: "toggle", isToggle: true }, ...SYS_BTNS];
  all.forEach((b, i) => {
    const cx = x0 + i * step;
    if (b.isToggle) {
      s += `<polygon points="${diamondPts(cx, cy, 14, 14)}" fill="#0e1620" fill-opacity="0.82" stroke="${CY}" stroke-opacity="0.45" stroke-width="1.1"/>`;
      s += `<image href="${loadIconUri("ToggleClose", "#d8e6f0")}" x="${cx - 7.5}" y="${cy - 7.5}" width="15" height="15"/>`;
      return;
    }
    if (b.active) {
      s += `<circle cx="${cx}" cy="${cy}" r="21" fill="url(#cyanHalo)" opacity="0.7"/>`;
      s += `<circle cx="${cx}" cy="${cy}" r="${r}" fill="#172b3a" fill-opacity="0.9"/>`;
      s += `<image href="${loadIconUri(b.icon, "#8cedff")}" x="${cx - 9.5}" y="${cy - 9.5}" width="19" height="19"/>`;
      s += `<rect x="${cx - 5}" y="${cy + 16}" width="10" height="2" rx="1" fill="#8cedff"/>`;
    } else {
      s += `<circle cx="${cx}" cy="${cy}" r="${r}" fill="#0c141e" fill-opacity="0.55"/>`;
      s += `<image href="${loadIconUri(b.icon, "#e4ebf0")}" x="${cx - 9.5}" y="${cy - 9.5}" width="19" height="19" opacity="0.88"/>`;
    }
    if (b.badge) {
      s += `<circle cx="${cx + 11}" cy="${cy + 11}" r="6.5" fill="#c79429"/>`;
      s += `<text x="${cx + 11}" y="${cy + 14}" text-anchor="middle" font-family="Segoe UI, sans-serif" font-size="8" font-weight="700" fill="#fff9e6">${b.badge}</text>`;
    }
  });

  s += `
    <text x="1306" y="${cy + 4}" text-anchor="end" font-family="Segoe UI, sans-serif" font-size="11.5" fill="${MUTED}">Discos translúcidos sem moldura · glifos simples · ativo com traço 10×2 · losango central</text>
  </g>`;
  return s;
}

// ------------------------------------------------------------------ Ornamento reutilizável de canto (estilo ConfigUI)
function cornerOrnament(x, y, sx, sy, size = 18) {
  return `<g transform="translate(${x} ${y}) scale(${sx} ${sy})">
    <path d="M1 ${size} V5 L5 1 H${size}" fill="none" stroke="${GL}" stroke-width="1.3"/>
    <path d="M5 ${size - 3} V8 L8 5 H${size - 3}" fill="none" stroke="${G}" stroke-width="0.7" opacity="0.7"/>
    ${cyanGem(4.5, 4.5, 2.5, 2.5)}
  </g>`;
}

// ------------------------------------------------------------------ Medalhão estilo Azaath (para dock expandido e recolhido)
function drawAzaathMedallion(cx, cy, b, r = 21) {
  const active = !!b.active;
  const isMenu = b.key === "menu";
  let s = `<g>`;

  if (active) {
    // Aura externa intensa + anel rúnico giratório
    s += `<circle cx="${cx}" cy="${cy}" r="${r + 24}" fill="url(#cyanHalo)" opacity="0.9"/>`;
    s += `<circle cx="${cx}" cy="${cy}" r="${r + 12}" fill="none" stroke="${CYL}" stroke-width="1.0" opacity="0.55" stroke-dasharray="6 4 2 4"/>`;
    for (let i = 0; i < 8; i++) {
      const [rx, ry] = at(cx, cy, r + 9, i * 45 + 22.5);
      s += rune(rx, ry, i + 2, i * 45 + 22.5, CYL, 0.55, 0.9);
    }
    // Motes de energia flutuando
    s += `<circle cx="${cx - 18}" cy="${cy - 26}" r="1.4" fill="${CYL}" filter="url(#glowCyan)"/>`;
    s += `<circle cx="${cx + 21}" cy="${cy - 21}" r="1.1" fill="${CYL}" filter="url(#glowCyan)"/>`;
    s += `<circle cx="${cx + 15}" cy="${cy - 30}" r="0.9" fill="#fff" opacity="0.8"/>`;
  }

  // Sombra de profundidade do engaste
  s += `<circle cx="${cx}" cy="${cy + 2}" r="${r + 3}" fill="#000" opacity="0.65"/>`;

  // Anel externo de bronze/ouro envelhecido
  const outerStroke = active ? "url(#cyanGoldRing)" : (isMenu ? "url(#goldBright)" : "url(#goldMetal)");
  s += `<circle cx="${cx}" cy="${cy}" r="${r + 2.5}" fill="url(#obsidianWell)" stroke="${outerStroke}" stroke-width="${active ? 2.4 : 2.0}"/>`;
  s += `<circle cx="${cx}" cy="${cy}" r="${r - 1.5}" fill="none" stroke="${active ? CY : GD}" stroke-width="0.9" opacity="${active ? 0.9 : 0.75}"/>`;

  // 4 cravos cardeais no aro metálico
  for (let d = 0; d < 360; d += 90) {
    const [tx, ty] = at(cx, cy, r + 2.5, d);
    s += `<polygon points="${diamondPts(tx, ty, 1.8)}" fill="${active ? CYL : GL}" opacity="${active ? 0.95 : 0.75}"/>`;
  }

  // Brilho interno do poço se ativo
  if (active) {
    s += `<circle cx="${cx}" cy="${cy}" r="${r - 2}" fill="url(#cyanWell)" opacity="0.85"/>`;
  } else {
    s += `<circle cx="${cx}" cy="${cy}" r="${r - 2}" fill="url(#innerDepth)"/>`;
  }

  // Ícone vetorial Azaath
  const tint = active ? "#a8f7ff" : "#dce8f0";
  const icoSize = 24;
  s += `<g ${active ? 'filter="url(#glowCyan)"' : ""}>
    <image href="${loadIconUri(b.icon, tint)}" x="${cx - icoSize / 2}" y="${cy - icoSize / 2}" width="${icoSize}" height="${icoSize}" opacity="${active ? 1 : 0.92}"/>
  </g>`;

  // Indicador inferior de janela aberta: gema losangular ciano engastada (em vez de traço simples)
  if (active) {
    s += `<g filter="url(#glowCyan)">${cyanGem(cx, cy + r + 3.5, 4.2, 4.2)}</g>`;
  }

  // Badge numérica como gema de âmbar dourado com aro metálico
  if (b.badge) {
    const bx = cx + r * 0.84, by = cy + r * 0.68;
    s += `<circle cx="${bx}" cy="${by + 1}" r="8.6" fill="#000" opacity="0.65"/>`;
    s += `<circle cx="${bx}" cy="${by}" r="8.4" fill="url(#badgeGrad)" stroke="${GL}" stroke-width="1.1"/>`;
    s += `<text x="${bx}" y="${by + 3.2}" text-anchor="middle" font-family="Segoe UI, sans-serif" font-size="9" font-weight="800" fill="#fffdf2" stroke="#361c00" stroke-width="0.4">${b.badge}</text>`;
  }

  s += `</g>`;
  return s;
}

// ------------------------------------------------------------------ Joia Losango Divisora (Toggle)
function drawDiamondToggle(cx, cy, collapsed = false) {
  const icon = collapsed ? "ToggleOpen" : "ToggleClose";
  return `<g>
    <ellipse cx="${cx}" cy="${cy}" rx="28" ry="26" fill="url(#cyanHalo)" opacity="0.45"/>
    <!-- Volutas de conexão -->
    <path d="M${cx - 26} ${cy} C${cx - 20} ${cy - 12} ${cx - 12} ${cy - 18} ${cx} ${cy - 28}
             C${cx + 12} ${cy - 18} ${cx + 20} ${cy - 12} ${cx + 26} ${cy}
             C${cx + 20} ${cy + 12} ${cx + 12} ${cy + 18} ${cx} ${cy + 28}
             C${cx - 12} ${cy + 18} ${cx - 20} ${cy + 12} ${cx - 26} ${cy} Z"
          fill="#060b12" stroke="url(#goldBright)" stroke-width="1.6"/>
    <polygon points="${diamondPts(cx, cy, 22, 22)}" fill="#07121b" stroke="${CY}" stroke-width="1.2" opacity="0.9"/>
    <polygon points="${diamondPts(cx, cy, 17, 17)}" fill="url(#cyanWell)" stroke="${GL}" stroke-width="0.9" opacity="0.85"/>
    <image href="${loadIconUri(icon, "#c2f9ff")}" x="${cx - 9}" y="${cy - 9}" width="18" height="18" filter="url(#glowCyan)"/>
    <!-- Cristais de ponta superior/inferior -->
    ${goldGem(cx, cy - 28, 3.5, 4.5)}
    ${goldGem(cx, cy + 28, 3.5, 4.5)}
  </g>`;
}

// ------------------------------------------------------------------ Doca Arquitetônica Azaath (Expandida ou Recolhida)
function drawAzaathDock(cx, cy, buttonsList, toggleCollapsed = false) {
  const step = 58;
  const gapToggle = 14;
  // Calcular largura total
  const count = buttonsList.length;
  const span = (count - 1) * step + gapToggle * 2;
  const xStart = cx - span / 2;
  const leftEdge = xStart - 44;
  const rightEdge = xStart + span + 44;
  const dockW = rightEdge - leftEdge;
  const dockH = 56;

  let s = `<g>`;
  // Sombra projetada da barra inteira
  s += `<rect x="${leftEdge + 6}" y="${cy - dockH / 2 + 8}" width="${dockW - 12}" height="${dockH}" rx="12" fill="#000" opacity="0.7" filter="url(#softBlur)"/>`;

  // Asas pontudas laterais (filigrana élfica / gótica Azaath)
  const wing = (edgeX, dir) => `
    <path d="M${edgeX} ${cy - 22} C${edgeX + dir * 24} ${cy - 24} ${edgeX + dir * 38} ${cy - 10} ${edgeX + dir * 52} ${cy}
             C${edgeX + dir * 38} ${cy + 10} ${edgeX + dir * 24} ${cy + 24} ${edgeX} ${cy + 22} Z"
          fill="#070c12" stroke="url(#goldMetal)" stroke-width="1.8"/>
    <path d="M${edgeX + dir * 6} ${cy - 13} C${edgeX + dir * 20} ${cy - 11} ${edgeX + dir * 30} ${cy - 5} ${edgeX + dir * 42} ${cy}
             C${edgeX + dir * 30} ${cy + 5} ${edgeX + dir * 20} ${cy + 11} ${edgeX + dir * 6} ${cy + 13}"
          fill="none" stroke="${CY}" stroke-width="1.1" opacity="0.75"/>
    <g filter="url(#glowCyan)">${cyanGem(edgeX + dir * 18, cy, 8, 6)}</g>
  `;
  s += wing(leftEdge + 8, -1);
  s += wing(rightEdge - 8, 1);

  // Corpo principal de vidro obsidiana
  s += `<rect x="${leftEdge}" y="${cy - dockH / 2}" width="${dockW}" height="${dockH}" rx="10" fill="url(#dockGlass)" stroke="url(#goldMetal)" stroke-width="2.1"/>`;
  s += `<rect x="${leftEdge + 4}" y="${cy - dockH / 2 + 4}" width="${dockW - 8}" height="${dockH - 8}" rx="7" fill="none" stroke="${GD}" stroke-width="0.9" opacity="0.85"/>`;

  // Condutos de energia ciano ao longo do trilho superior e inferior
  s += `<line x1="${leftEdge + 26}" y1="${cy - dockH / 2 + 2.5}" x2="${rightEdge - 26}" y2="${cy - dockH / 2 + 2.5}" stroke="url(#cyanLineH)" stroke-width="1.4" opacity="0.8"/>`;
  s += `<line x1="${leftEdge + 26}" y1="${cy + dockH / 2 - 2.5}" x2="${rightEdge - 26}" y2="${cy + dockH / 2 - 2.5}" stroke="url(#cyanLineH)" stroke-width="1.4" opacity="0.55"/>`;

  // Posicionar cada botão
  let x = xStart;
  let activePos = null;
  buttonsList.forEach((b) => {
    if (b.isToggle) {
      x += gapToggle;
      s += drawDiamondToggle(x, cy, toggleCollapsed);
      x += gapToggle + step;
    } else {
      s += drawAzaathMedallion(x, cy, b, 21);
      if (b.active) activePos = { x, y: cy };
      x += step;
    }
  });

  s += `</g>`;
  return { svg: s, activePos, leftEdge, rightEdge };
}

// ------------------------------------------------------------------ Placar Flutuante Estilo Azaath
function drawAzaathPlacard(cx, bottomY, data) {
  const pw = data.w || 356, ph = data.h || 128;
  const x = cx - pw / 2, y = bottomY - ph;
  const beamX = data.beamX || cx;

  return `<g>
    ${data.showBeam !== false ? `
    <!-- Feixe luminoso ligando o botão ao placar -->
    <polygon points="${beamX - 12},${bottomY + 14} ${beamX + 12},${bottomY + 14} ${beamX + 4},${bottomY - 2} ${beamX - 4},${bottomY - 2}" fill="url(#cyanBeam)" opacity="0.58"/>
    <g filter="url(#glowCyan)">${cyanGem(beamX, bottomY + 1, 4.5, 4.5)}</g>` : ""}

    <!-- Sombra e halo externo -->
    <rect x="${x + 4}" y="${y + 6}" width="${pw}" height="${ph}" rx="7" fill="#000" opacity="0.78" filter="url(#softBlur)"/>
    <rect x="${x}" y="${y}" width="${pw}" height="${ph}" rx="6" fill="url(#placardBg)" stroke="url(#goldMetal)" stroke-width="1.8"/>
    <rect x="${x + 3.5}" y="${y + 3.5}" width="${pw - 7}" height="${ph - 7}" rx="4" fill="none" stroke="${CY}" stroke-width="0.7" opacity="0.4"/>

    <!-- Filete superior de energia ciano + crista -->
    <rect x="${x + 12}" y="${y + 1.5}" width="${pw - 24}" height="2.4" rx="1.2" fill="url(#cyanLineH)" filter="url(#glowCyan)"/>
    <rect x="${x + 4}" y="${y + 4}" width="${pw - 8}" height="34" rx="3" fill="url(#headerGrad)"/>

    <!-- Cantoneiras ornamentadas -->
    ${cornerOrnament(x - 1, y - 1, 1, 1, 17)}
    ${cornerOrnament(x + pw + 1, y - 1, -1, 1, 17)}
    ${cornerOrnament(x - 1, y + ph + 1, 1, -1, 17)}
    ${cornerOrnament(x + pw + 1, y + ph + 1, -1, -1, 17)}

    <!-- Cabeçalho: ícone + título + atalho -->
    <image href="${loadIconUri(data.icon, "#8ef4ff")}" x="${x + 16}" y="${y + 12}" width="18" height="18" filter="url(#glowCyan)"/>
    <text x="${x + 42}" y="${y + 25.5}" font-family="Cinzel, Georgia, serif" font-size="13.5" font-weight="700" letter-spacing="0.8" fill="${TXT}">${data.title}</text>

    <!-- Keycap do atalho -->
    <rect x="${x + pw - 56}" y="${y + 11}" width="40" height="20" rx="3" fill="#0b1722" stroke="${G}" stroke-width="1"/>
    <text x="${x + pw - 36}" y="${y + 25}" text-anchor="middle" font-family="Segoe UI, sans-serif" font-size="11" font-weight="700" fill="${CYL}">${data.key}</text>

    <!-- Divisor luminoso ciano com losango central -->
    <line x1="${x + 16}" y1="${y + 40}" x2="${x + pw - 16}" y2="${y + 40}" stroke="url(#cyanLineH)" stroke-width="1.1" opacity="0.75"/>
    ${cyanGem(x + pw / 2, y + 40, 3.2, 3.2)}

    <!-- Descrição -->
    <text x="${x + 16}" y="${y + 60}" font-family="Segoe UI, sans-serif" font-size="12" fill="#bdd0dc">${data.desc1}</text>
    <text x="${x + 16}" y="${y + 77}" font-family="Segoe UI, sans-serif" font-size="12" fill="#bdd0dc">${data.desc2}</text>

    <!-- Status / FPS / Dica -->
    <text x="${x + 16}" y="${y + 101}" font-family="Segoe UI, sans-serif" font-size="11.5" font-weight="600" fill="${CYL}">${data.status}</text>
    <text x="${x + 16}" y="${y + 117}" font-family="Segoe UI, sans-serif" font-size="10.5" fill="${G}" opacity="0.92">${data.hint}</text>
  </g>`;
}

// ------------------------------------------------------------------ Seção 2: Herói (Novo Conceito Expandido)
function drawHeroSection() {
  const dockY = 532;
  const allBtns = [...MAIN_BTNS, { key: "toggle", isToggle: true }, ...SYS_BTNS];
  const dock = drawAzaathDock(700, dockY, allBtns, false);

  const placard = drawAzaathPlacard(dock.activePos.x + 18, dockY - 56, {
    w: 372,
    h: 130,
    beamX: dock.activePos.x,
    icon: "Talents",
    title: "TALENTOS & ESPECIALIZAÇÃO",
    key: "[N]",
    desc1: "Distribua pontos de talento, alterne especializações",
    desc2: "e personalize sua build no Crisol de Azaath.",
    status: "Pontos disponíveis: 3",
    hint: "Clique direito: Janela padrão do jogo",
  });

  // Anotações conceituais limpas em volta da peça principal
  const callout = (x1, y1, x2, y2, anchor, title, sub) => `
    <g opacity="0.92">
      <polyline points="${x1},${y1} ${x2},${y2}" fill="none" stroke="${G}" stroke-width="0.9" stroke-dasharray="2 3"/>
      <circle cx="${x1}" cy="${y1}" r="2.3" fill="${CYL}"/>
      <text x="${x2 + (anchor === "start" ? 6 : -6)}" y="${y2 - 2}" text-anchor="${anchor}" font-family="Cinzel, Georgia, serif" font-size="11" font-weight="700" fill="${GL}">${title}</text>
      <text x="${x2 + (anchor === "start" ? 6 : -6)}" y="${y2 + 12}" text-anchor="${anchor}" font-family="Segoe UI, sans-serif" font-size="10.5" fill="${MUTED}">${sub}</text>
    </g>`;

  const talX = dock.activePos.x;
  const questsX = talX + 4 * 58;
  const togX = talX + 9 * 58 + 14;
  const sysMidX = togX + 14 + 2 * 58;

  return `
  <g>
    <text x="90" y="232" font-family="Cinzel, Georgia, serif" font-size="12" letter-spacing="2.2" fill="${GL}">2. NOVO CONCEITO — MICRO MENU ARCANO ESTILO AZAATH (EXPANDIDO + PLACAR)</text>
    <line x1="90" y1="240" x2="690" y2="240" stroke="url(#goldLineH)" stroke-width="0.9" opacity="0.6"/>

    ${dock.svg}
    ${placard}

    ${callout(dock.leftEdge - 36, dockY + 8, 90, 615, "start", "PONTEIRAS & CRISTAIS", "Filigrana bronze/ouro + cristal ciano")}
    ${callout(talX - 10, dockY + 28, 360, 615, "start", "ENGASTE RÚNICO ATIVO", "Runas de Azoth + gema ciano na base")}
    ${callout(questsX + 16, dockY + 18, 635, 615, "start", "BADGES EM GEMA DOURADA", "Contadores em medalhão âmbar")}
    ${callout(togX, dockY + 29, 920, 615, "start", "DIVISOR LOSANGULAR", "Recolhe/expande os 11 atalhos")}
    ${callout(sysMidX, dockY - 26, 980, 415, "start", "GRUPO DE SISTEMA", "Mapa, Ajuda e Menu sempre visíveis")}
    ${callout(dock.activePos.x + 206, dockY - 122, 680, 345, "start", "PLACAR ARCANO AZAATH", "Cantoneiras ouro, filete ciano e atalho rúnico")}
  </g>`;
}

// ------------------------------------------------------------------ Seção 3: Modo Recolhido + Placar de Sistema
function drawCollapsedSection() {
  const cy = 758;
  const collapsedBtns = [{ key: "toggle", isToggle: true }, ...SYS_BTNS];
  const dock = drawAzaathDock(340, cy, collapsedBtns, true);

  const sysPlacard = drawAzaathPlacard(975, cy + 44, {
    w: 390,
    h: 126,
    showBeam: false,
    icon: "Menu",
    title: "CONFIGURAR JOGO",
    key: "[ESC]",
    desc1: "Abra o menu do jogo para gráficos, áudio, teclas",
    desc2: "e configurações completas da interface AzaathUI.",
    status: "FPS: 144    Latência: 18 ms",
    hint: "Clique direito: Opções AzaathUI (/azaath)",
  });

  // Remover feixe apontando para baixo no placar demonstrativo e deixá-lo limpo
  return `
  <g>
    <text x="90" y="668" font-family="Cinzel, Georgia, serif" font-size="11.5" letter-spacing="2.2" fill="${GL}">3. MODO RECOLHIDO (COLLAPSED) &amp; PLACAR DE SISTEMA</text>
    <line x1="90" y1="676" x2="545" y2="676" stroke="url(#goldLineH)" stroke-width="0.8" opacity="0.5"/>
    ${dock.svg}
    <text x="340" y="${cy + 48}" text-anchor="middle" font-family="Segoe UI, sans-serif" font-size="11" fill="${MUTED}">Barra compacta no canto inferior direito quando recolhida</text>
    ${sysPlacard}
  </g>`;
}

// ------------------------------------------------------------------ Montagem SVG completa
const body = `
<defs>
  <linearGradient id="bgGrad" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#0b1018"/><stop offset="0.5" stop-color="#06090e"/><stop offset="1" stop-color="#040609"/>
  </linearGradient>
  <radialGradient id="cyanAura" cx=".5" cy=".5" r=".5">
    <stop offset="0" stop-color="${CY}" stop-opacity="0.55"/><stop offset="1" stop-color="${CY}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="cyanHalo" cx=".5" cy=".5" r=".5">
    <stop offset="0" stop-color="${CYL}" stop-opacity="0.65"/><stop offset=".45" stop-color="${CY}" stop-opacity="0.28"/><stop offset="1" stop-color="${CY}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="vignette" cx=".5" cy=".48" r=".72">
    <stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.72"/>
  </radialGradient>
  <filter id="mist" x="-10%" y="-10%" width="120%" height="120%">
    <feTurbulence type="fractalNoise" baseFrequency="0.008 0.015" numOctaves="4" seed="11"/>
    <feColorMatrix values="0 0 0 0 0.14  0 0 0 0 0.36  0 0 0 0 0.44  0 0 0 0.18 -0.04"/>
  </filter>
  <filter id="grain" x="0%" y="0%" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.85" numOctaves="2" seed="5"/>
    <feColorMatrix values="0 0 0 0 0.7  0 0 0 0 0.75  0 0 0 0 0.8  0 0 0 0.05 0"/>
  </filter>
  <filter id="glowCyan" x="-60%" y="-60%" width="220%" height="220%">
    <feGaussianBlur stdDeviation="2.4" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="softBlur" x="-30%" y="-30%" width="160%" height="160%">
    <feGaussianBlur stdDeviation="6"/>
  </filter>
  <linearGradient id="goldMetal" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${GL}"/><stop offset="0.45" stop-color="${G}"/><stop offset="1" stop-color="${GD}"/>
  </linearGradient>
  <linearGradient id="goldBright" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff0c6"/><stop offset="0.5" stop-color="${GL}"/><stop offset="1" stop-color="${G}"/>
  </linearGradient>
  <linearGradient id="cyanGoldRing" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${CYL}"/><stop offset="0.5" stop-color="${CY}"/><stop offset="1" stop-color="${G}"/>
  </linearGradient>
  <linearGradient id="goldLineH" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="${G}" stop-opacity="0"/><stop offset="0.5" stop-color="${GL}" stop-opacity="1"/><stop offset="1" stop-color="${G}" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="cyanLineH" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="${CY}" stop-opacity="0"/><stop offset="0.5" stop-color="${CYL}" stop-opacity="1"/><stop offset="1" stop-color="${CY}" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="cyanBeam" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${CYL}" stop-opacity="0.05"/><stop offset="1" stop-color="${CY}" stop-opacity="0.7"/>
  </linearGradient>
  <linearGradient id="dockGlass" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#111a26" stop-opacity="0.96"/><stop offset="0.5" stop-color="#070b11" stop-opacity="0.97"/><stop offset="1" stop-color="#04070b" stop-opacity="0.98"/>
  </linearGradient>
  <linearGradient id="placardBg" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#0d1622" stop-opacity="0.96"/><stop offset="1" stop-color="#05080d" stop-opacity="0.97"/>
  </linearGradient>
  <linearGradient id="headerGrad" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="${CY}" stop-opacity="0.16"/><stop offset="1" stop-color="${CY}" stop-opacity="0.02"/>
  </linearGradient>
  <radialGradient id="obsidianWell" cx=".5" cy=".42" r=".55">
    <stop offset="0" stop-color="#111b26"/><stop offset="1" stop-color="#05080d"/>
  </radialGradient>
  <radialGradient id="innerDepth" cx=".5" cy=".35" r=".65">
    <stop offset="0" stop-color="#142230" stop-opacity="0.7"/><stop offset="1" stop-color="#04070b" stop-opacity="0.95"/>
  </radialGradient>
  <radialGradient id="cyanWell" cx=".5" cy=".5" r=".55">
    <stop offset="0" stop-color="${CY}" stop-opacity="0.34"/><stop offset="1" stop-color="#081a24" stop-opacity="0.95"/>
  </radialGradient>
  <linearGradient id="badgeGrad" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="${AML}"/><stop offset="0.4" stop-color="${AM}"/><stop offset="1" stop-color="${AMD}"/>
  </linearGradient>
</defs>
${drawBackground()}
${drawHeader()}
${drawCurrentSection()}
${drawHeroSection()}
${drawCollapsedSection()}
`;

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;padding:0;background:#06090e;overflow:hidden;width:${W}px;height:${H}px}
</style></head><body><svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">${body}</svg></body></html>`;

const htmlFile = path.join(DIR, "concept.html");
const outFile = path.join(DIR, "concept.png");
fs.writeFileSync(htmlFile, html);
if (fs.existsSync(outFile)) fs.unlinkSync(outFile);

const profile = path.join(require("os").tmpdir(), "azaath_micromenu_edge_" + Date.now());
spawnSync(EDGE, [
  "--headless=new",
  "--disable-gpu",
  "--user-data-dir=" + profile,
  "--no-first-run",
  "--hide-scrollbars",
  "--default-background-color=00000000",
  "--force-device-scale-factor=" + SCALE,
  "--window-size=" + W + "," + H,
  "--virtual-time-budget=2500",
  "--allow-file-access-from-files",
  "--screenshot=" + outFile,
  "file:///" + htmlFile.replace(/\\/g, "/"),
], { stdio: "ignore" });

const t0 = Date.now();
let last = -1;
while (Date.now() - t0 < 30000) {
  const sz = fs.existsSync(outFile) ? fs.statSync(outFile).size : 0;
  if (sz > 0 && sz === last) break;
  last = sz;
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
}
if (!fs.existsSync(outFile)) {
  console.error("O Edge não gravou o screenshot (rode fora do sandbox).");
  process.exit(1);
}
console.log("Arte conceitual gerada:", outFile, fs.statSync(outFile).size, "bytes");
