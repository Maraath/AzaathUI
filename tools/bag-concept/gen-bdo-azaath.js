// Arte de Conceito AAA — Inventário Azaath + Aba Equipado (estilo Black Desert) + Menu Radial
//
// Uso: node tools/bag-concept/gen-bdo-azaath.js
// Gera: tools/bag-concept/Azaath_Inventario_BDO_Concept.png (1920x1080)
//
"use strict";
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const DIR = __dirname;
const ROOT = path.resolve(DIR, "../..");
const FONTS = "file:///" + path.join(ROOT, "AzaathUI/Media/Fonts").replace(/\\/g, "/");
const ASSETS = "file:///" + path.join(DIR, "assets").replace(/\\/g, "/");
const TOOLS = "file:///" + path.join(ROOT, "tools").replace(/\\/g, "/");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const OUT_PNG = path.join(DIR, "Azaath_Inventario_BDO_Concept.png");
const HTML_FILE = path.join(DIR, "bdo_azaath.html");

const EDGE_PROF = path.join(ROOT, "tools/.cache/edge-concept-prof");
fs.mkdirSync(EDGE_PROF, { recursive: true });

function svgUrl(svg) {
  return "data:image/svg+xml;base64," + Buffer.from(svg.trim(), "utf8").toString("base64");
}

// ============================================================================
// Ícones SVG de Alta Qualidade (Armas, Armaduras, Acessórios, Consumíveis, Bolsas)
// ============================================================================
const SVG_ICONS = {
  // Armas
  epicSword: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#45196e"/><stop offset="100%" stop-color="#0b0614"/></radialGradient>
      <linearGradient id="blade" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#f5ebff"/><stop offset="45%" stop-color="#a893c4"/><stop offset="100%" stop-color="#332347"/></linearGradient>
      <linearGradient id="rune" x1="0" y1="1" x2="1" y2="0"><stop offset="0%" stop-color="#5fe3e6"/><stop offset="55%" stop-color="#df78ff"/><stop offset="100%" stop-color="#ffffff"/></linearGradient>
      <linearGradient id="gold" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ffe7a6"/><stop offset="50%" stop-color="#c49545"/><stop offset="100%" stop-color="#5a3d14"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <circle cx="52" cy="48" r="38" fill="#b455ff" opacity="0.28"/>
    <g transform="translate(50 50) rotate(42) translate(-50 -50)">
      <path d="M50 8 L58 22 L56 64 L44 64 L42 22 Z" fill="url(#blade)" stroke="#e9dcff" stroke-width="1.2"/>
      <path d="M50 11 L50 62" stroke="#1e1330" stroke-width="2.6"/>
      <path d="M50 17 L50 57 M46.5 27 L53.5 31 M46.5 39 L53.5 43 M46.5 51 L53.5 55" stroke="url(#rune)" stroke-width="2.4" stroke-linecap="round"/>
      <path d="M27 63 Q50 57 73 63 L70 70 Q50 66 30 70 Z" fill="url(#gold)" stroke="#fff2c2" stroke-width="1"/>
      <rect x="46.5" y="68" width="7" height="17" rx="2" fill="#32184a" stroke="url(#gold)" stroke-width="1"/>
      <circle cx="50" cy="89" r="6" fill="url(#gold)" stroke="#fff2c2" stroke-width="1"/>
      <circle cx="50" cy="65" r="4.2" fill="#5fe3e6" stroke="#ffffff" stroke-width="0.9"/>
    </g>
  </svg>`),

  obsidianAxe: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#143248"/><stop offset="100%" stop-color="#060c14"/></radialGradient>
      <linearGradient id="edge" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#b0f9ff"/><stop offset="50%" stop-color="#4e7994"/><stop offset="100%" stop-color="#1a2430"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(32) translate(-50 -50)">
      <rect x="47" y="14" width="6" height="74" rx="2" fill="#5b3d24" stroke="#c9a463" stroke-width="0.9"/>
      <path d="M52 20 Q72 16 82 10 Q90 30 82 52 Q70 42 52 44 Z" fill="url(#edge)" stroke="#8ef2ff" stroke-width="1.3"/>
      <path d="M48 20 Q28 16 18 10 Q10 30 18 52 Q30 42 48 44 Z" fill="url(#edge)" stroke="#8ef2ff" stroke-width="1.3"/>
      <circle cx="50" cy="32" r="5" fill="#5fe3e6" stroke="#e9d29a" stroke-width="1"/>
    </g>
  </svg>`),

  greenSword: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#19422b"/><stop offset="100%" stop-color="#07100c"/></radialGradient>
      <linearGradient id="blade" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#f2f7f4"/><stop offset="50%" stop-color="#94a89d"/><stop offset="100%" stop-color="#35423b"/></linearGradient>
      <linearGradient id="gold" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ffe7a6"/><stop offset="55%" stop-color="#b8893a"/><stop offset="100%" stop-color="#5a3d14"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(42) translate(-50 -50)">
      <path d="M50 11 L57 24 L56 64 L44 64 L43 24 Z" fill="url(#blade)" stroke="#dceee4" stroke-width="1.1"/>
      <path d="M50 15 L50 61" stroke="#2c3a32" stroke-width="2.2"/>
      <path d="M31 63 L69 63 L67 69 L33 69 Z" fill="url(#gold)" stroke="#f5dfa2" stroke-width="0.9"/>
      <rect x="46.5" y="69" width="7" height="16" rx="2" fill="#2b2114" stroke="url(#gold)" stroke-width="1"/>
      <circle cx="50" cy="89" r="5.5" fill="url(#gold)" stroke="#f5dfa2" stroke-width="0.9"/>
      <circle cx="50" cy="66" r="3.6" fill="#4ce67a" stroke="#e4ffe9" stroke-width="0.6"/>
    </g>
  </svg>`),

  dagger: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#1c3b28"/><stop offset="100%" stop-color="#070e0b"/></radialGradient>
      <linearGradient id="bl" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#eef5f0"/><stop offset="55%" stop-color="#7c9084"/><stop offset="100%" stop-color="#28332c"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(45) translate(-50 -50)">
      <path d="M50 15 L56.5 32 L54 62 L46 62 L43.5 32 Z" fill="url(#bl)" stroke="#d9f5e3" stroke-width="1"/>
      <path d="M35 61 Q50 56 65 61 L64 66 L36 66 Z" fill="#c9a463"/>
      <rect x="47" y="66" width="6" height="15" fill="#2c2418" stroke="#c9a463" stroke-width="0.8"/>
      <circle cx="50" cy="84" r="4.5" fill="#3fcf5a" stroke="#e9d29a" stroke-width="1"/>
    </g>
  </svg>`),

  bow: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#173827"/><stop offset="100%" stop-color="#06100a"/></radialGradient>
      <linearGradient id="gd" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ffe7a6"/><stop offset="55%" stop-color="#c49545"/><stop offset="100%" stop-color="#523710"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(35) translate(-50 -50)">
      <path d="M32 14 Q74 50 32 86" fill="none" stroke="url(#gd)" stroke-width="6.5" stroke-linecap="round"/>
      <line x1="32" y1="16" x2="32" y2="84" stroke="#c9f7ff" stroke-width="1.6"/>
      <line x1="20" y1="50" x2="78" y2="50" stroke="#e9d29a" stroke-width="2.6"/>
      <polygon points="84,50 72,44 75,50 72,56" fill="#5fe3e6"/>
    </g>
  </svg>`),

  shield: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#153554"/><stop offset="100%" stop-color="#060e18"/></radialGradient>
      <linearGradient id="st" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#e3eef5"/><stop offset="50%" stop-color="#617b91"/><stop offset="100%" stop-color="#1b2836"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M22 20 Q50 14 78 20 L74 56 Q68 78 50 86 Q32 78 26 56 Z" fill="url(#st)" stroke="#e9c878" stroke-width="3"/>
    <path d="M50 24 L50 80 M28 46 L72 46" stroke="#c9a463" stroke-width="2.2"/>
    <polygon points="50,36 59,46 50,56 41,46" fill="#5fe3e6" stroke="#fff2c2" stroke-width="1.5"/>
  </svg>`),

  // Armaduras e Acessórios
  pauldrons: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#163654"/><stop offset="100%" stop-color="#050c14"/></radialGradient>
    <linearGradient id="st" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#e2eaef"/><stop offset="55%" stop-color="#6e7c85"/><stop offset="100%" stop-color="#273036"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M14 54 Q22 22 46 28 L44 68 Q22 72 14 54 Z" fill="url(#st)" stroke="#d9b25f" stroke-width="2.2"/>
    <path d="M86 54 Q78 22 54 28 L56 68 Q78 72 86 54 Z" fill="url(#st)" stroke="#d9b25f" stroke-width="2.2"/>
    <circle cx="30" cy="46" r="4.5" fill="#5fe3e6"/><circle cx="70" cy="46" r="4.5" fill="#5fe3e6"/>
  </svg>`),

  cloak: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#2c1648"/><stop offset="100%" stop-color="#080510"/></radialGradient>
    <linearGradient id="ck" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#7539ab"/><stop offset="100%" stop-color="#250f3d"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M32 18 Q50 24 68 18 L82 82 Q50 90 18 82 Z" fill="url(#ck)" stroke="#e6c072" stroke-width="2.2"/>
    <circle cx="33" cy="19" r="4.2" fill="#e6c072"/><circle cx="67" cy="19" r="4.2" fill="#e6c072"/>
    <path d="M50 34 L56 54 L50 72 L44 54 Z" fill="#d978ff" opacity="0.65"/>
  </svg>`),

  chestplate: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#291742"/><stop offset="100%" stop-color="#090710"/></radialGradient>
      <linearGradient id="steel" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#dce6ec"/><stop offset="50%" stop-color="#6e7c85"/><stop offset="100%" stop-color="#2b3338"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M22 20 L36 16 Q50 28 64 16 L78 20 L82 42 L70 46 L68 80 Q50 88 32 80 L30 46 L18 42 Z" fill="url(#steel)" stroke="#c9a463" stroke-width="2.5"/>
    <path d="M50 28 L50 80 M34 48 L66 48" stroke="#c9a463" stroke-width="1.8" opacity="0.85"/>
    <polygon points="50,36 56,45 50,54 44,45" fill="#d26bff" stroke="#fff2c2" stroke-width="1"/>
  </svg>`),

  bracers: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#193b26"/><stop offset="100%" stop-color="#06100a"/></radialGradient>
    <linearGradient id="st" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ced8de"/><stop offset="55%" stop-color="#5b666e"/><stop offset="100%" stop-color="#23292e"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M32 22 Q50 16 68 22 L72 78 Q50 84 28 78 Z" fill="url(#st)" stroke="#c9a463" stroke-width="2.4"/>
    <path d="M31 38 Q50 34 69 38 M30 62 Q50 58 70 62" stroke="#c9a463" stroke-width="2" fill="none"/>
  </svg>`),

  gauntlets: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#183324"/><stop offset="100%" stop-color="#070e0b"/></radialGradient>
      <linearGradient id="st" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#d5dee4"/><stop offset="50%" stop-color="#606c75"/><stop offset="100%" stop-color="#23292e"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M35 20 L42 20 L42 42 L45 42 L45 16 L52 16 L52 42 L55 42 L55 18 L62 18 L62 44 L66 44 L66 28 L72 28 L72 56 Q72 68 62 72 L62 86 L36 86 L36 72 Q28 66 28 52 L28 36 L35 36 Z" fill="url(#st)" stroke="#c9a463" stroke-width="2"/>
    <rect x="34" y="68" width="30" height="5" fill="#c9a463"/>
    <circle cx="49" cy="54" r="4.2" fill="#3fcf5a"/>
  </svg>`),

  belt: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#173854"/><stop offset="100%" stop-color="#060e16"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M14 42 Q50 52 86 42 L86 60 Q50 70 14 60 Z" fill="#5e3d20" stroke="#c9a463" stroke-width="2"/>
    <rect x="38" y="38" width="24" height="28" rx="4" fill="#c9a463" stroke="#fff2c2" stroke-width="1.5"/>
    <circle cx="50" cy="52" r="6" fill="#46b6ff"/>
  </svg>`),

  greaves: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#193b26"/><stop offset="100%" stop-color="#06100a"/></radialGradient>
    <linearGradient id="st" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ced8de"/><stop offset="55%" stop-color="#5b666e"/><stop offset="100%" stop-color="#23292e"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M26 16 L74 16 L78 32 L70 84 L54 84 L50 48 L46 84 L30 84 L22 32 Z" fill="url(#st)" stroke="#c9a463" stroke-width="2.2"/>
    <rect x="26" y="16" width="48" height="9" fill="#6b4e24" stroke="#e9d29a" stroke-width="1"/>
  </svg>`),

  boots: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#193b26"/><stop offset="100%" stop-color="#06100a"/></radialGradient>
    <linearGradient id="st" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ced8de"/><stop offset="55%" stop-color="#5b666e"/><stop offset="100%" stop-color="#23292e"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M32 18 L56 18 L56 58 L78 68 L78 82 L28 82 L28 60 Z" fill="url(#st)" stroke="#c9a463" stroke-width="2.2"/>
    <rect x="30" y="22" width="28" height="7" fill="#c9a463"/>
  </svg>`),

  amulet: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#163826"/><stop offset="100%" stop-color="#07100c"/></radialGradient>
      <linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ffeaa8"/><stop offset="100%" stop-color="#8c6320"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M24 14 Q50 54 76 14" fill="none" stroke="url(#g)" stroke-width="3.5" stroke-dasharray="4 2"/>
    <polygon points="50,36 68,58 50,84 32,58" fill="#2bd965" stroke="url(#g)" stroke-width="3"/>
    <polygon points="50,44 60,58 50,74 40,58" fill="#9effbe" opacity="0.7"/>
  </svg>`),

  ring: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#133352"/><stop offset="100%" stop-color="#050b14"/></radialGradient>
      <linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ffeaa8"/><stop offset="50%" stop-color="#c49545"/><stop offset="100%" stop-color="#5e4214"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <ellipse cx="50" cy="58" rx="24" ry="22" fill="none" stroke="url(#g)" stroke-width="9"/>
    <ellipse cx="50" cy="58" rx="24" ry="22" fill="none" stroke="#fff4cc" stroke-width="1.2" opacity="0.7"/>
    <polygon points="50,20 62,32 50,44 38,32" fill="#46b6ff" stroke="#ffeaa8" stroke-width="2.2"/>
    <polygon points="50,24 57,32 50,39 43,32" fill="#bff3ff"/>
  </svg>`),

  ringRuby: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#36143a"/><stop offset="100%" stop-color="#0c050e"/></radialGradient>
      <linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ffeaa8"/><stop offset="50%" stop-color="#c49545"/><stop offset="100%" stop-color="#5e4214"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <ellipse cx="50" cy="58" rx="24" ry="22" fill="none" stroke="url(#g)" stroke-width="9"/>
    <polygon points="50,20 62,32 50,44 38,32" fill="#d96bff" stroke="#ffeaa8" stroke-width="2.2"/>
  </svg>`),

  // Consumíveis, Bolsas, Diversos
  healthPotion: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#3d151d"/><stop offset="100%" stop-color="#0e0608"/></radialGradient>
      <radialGradient id="liq" cx="42%" cy="40%" r="60%"><stop offset="0%" stop-color="#ff8594"/><stop offset="55%" stop-color="#c91832"/><stop offset="100%" stop-color="#590814"/></radialGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <rect x="43" y="14" width="14" height="10" rx="2" fill="#8f6338"/>
    <rect x="41" y="22" width="18" height="12" fill="#7da0b0" opacity="0.55" stroke="#d8eef8" stroke-width="1"/>
    <path d="M41 34 L30 48 Q22 60 28 74 Q34 86 50 86 Q66 86 72 74 Q78 60 70 48 L59 34 Z" fill="url(#liq)" stroke="#e4f4ff" stroke-width="1.8"/>
    <ellipse cx="39" cy="56" rx="5" ry="11" transform="rotate(-18 39 56)" fill="#ffffff" opacity="0.4"/>
  </svg>`),

  manaPotion: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#12364a"/><stop offset="100%" stop-color="#050c12"/></radialGradient>
      <radialGradient id="liq" cx="42%" cy="40%" r="60%"><stop offset="0%" stop-color="#a8f9ff"/><stop offset="55%" stop-color="#22a5c9"/><stop offset="100%" stop-color="#0a3b52"/></radialGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <rect x="43" y="14" width="14" height="10" rx="2" fill="#8f6338"/>
    <rect x="41" y="22" width="18" height="12" fill="#7da0b0" opacity="0.55" stroke="#d8eef8" stroke-width="1"/>
    <path d="M41 34 L30 48 Q22 60 28 74 Q34 86 50 86 Q66 86 72 74 Q78 60 70 48 L59 34 Z" fill="url(#liq)" stroke="#d8f8ff" stroke-width="1.8"/>
    <ellipse cx="39" cy="56" rx="5" ry="11" transform="rotate(-18 39 56)" fill="#ffffff" opacity="0.45"/>
  </svg>`),

  goldElixir: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#163244"/><stop offset="100%" stop-color="#070d14"/></radialGradient>
      <radialGradient id="liq" cx="42%" cy="42%" r="60%"><stop offset="0%" stop-color="#fff099"/><stop offset="55%" stop-color="#e39d24"/><stop offset="100%" stop-color="#6b3e06"/></radialGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <rect x="43" y="13" width="14" height="10" rx="2" fill="#9c6e3e"/>
    <rect x="40" y="23" width="20" height="11" fill="#8bb0c2" opacity="0.5" stroke="#d8eef8" stroke-width="1"/>
    <polygon points="40,34 60,34 74,56 66,84 34,84 26,56" fill="url(#liq)" stroke="#e4f4ff" stroke-width="1.8"/>
    <path d="M36 56 L44 42" stroke="#ffffff" stroke-width="3" stroke-linecap="round" opacity="0.55"/>
  </svg>`),

  furyElixir: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#361c12"/><stop offset="100%" stop-color="#0d0705"/></radialGradient>
      <radialGradient id="liq" cx="42%" cy="42%" r="60%"><stop offset="0%" stop-color="#ffc285"/><stop offset="55%" stop-color="#d9531e"/><stop offset="100%" stop-color="#5e1b06"/></radialGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <rect x="43" y="14" width="14" height="10" rx="2" fill="#8f6338"/>
    <path d="M40 24 L60 24 L58 38 L76 74 Q76 85 62 85 L38 85 Q24 85 24 74 L42 38 Z" fill="url(#liq)" stroke="#ffe0c2" stroke-width="1.6"/>
  </svg>`),

  arcaneTonic: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#2a1647"/><stop offset="100%" stop-color="#090612"/></radialGradient>
      <radialGradient id="liq" cx="42%" cy="42%" r="60%"><stop offset="0%" stop-color="#e3b0ff"/><stop offset="55%" stop-color="#8738d9"/><stop offset="100%" stop-color="#350c66"/></radialGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <rect x="44" y="13" width="12" height="9" rx="2" fill="#9c6e3e"/>
    <path d="M41 22 L59 22 L58 34 Q76 46 72 68 Q68 85 50 85 Q32 85 28 68 Q24 46 42 34 Z" fill="url(#liq)" stroke="#d9c2ff" stroke-width="1.6"/>
    <ellipse cx="39" cy="54" rx="4.5" ry="10" transform="rotate(-14 39 54)" fill="#ffffff" opacity="0.38"/>
  </svg>`),

  speedVial: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#143b2a"/><stop offset="100%" stop-color="#06100c"/></radialGradient>
      <radialGradient id="liq" cx="42%" cy="42%" r="60%"><stop offset="0%" stop-color="#a8ffcf"/><stop offset="55%" stop-color="#26b86a"/><stop offset="100%" stop-color="#0b4d29"/></radialGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <rect x="44" y="14" width="12" height="9" rx="2" fill="#9c6e3e"/>
    <rect x="36" y="26" width="28" height="58" rx="14" fill="url(#liq)" stroke="#c7ffe1" stroke-width="1.6"/>
    <line x1="43" y1="36" x2="43" y2="72" stroke="#ffffff" stroke-width="3" stroke-linecap="round" opacity="0.4"/>
  </svg>`),

  bagLeather: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#2b2118"/><stop offset="100%" stop-color="#0c0907"/></radialGradient>
      <linearGradient id="lea" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#a87648"/><stop offset="60%" stop-color="#5c3a1e"/><stop offset="100%" stop-color="#2e1b0d"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M36 26 Q50 14 64 26" fill="none" stroke="#c9a463" stroke-width="4"/>
    <path d="M24 34 Q24 24 50 24 Q76 24 76 34 L80 76 Q80 86 50 86 Q20 86 20 76 Z" fill="url(#lea)" stroke="#c9a463" stroke-width="2"/>
    <path d="M23 38 Q50 56 77 38 L76 48 Q50 66 24 48 Z" fill="#3a2311" stroke="#c9a463" stroke-width="1.2"/>
    <rect x="44" y="47" width="12" height="14" rx="2" fill="#e0b86b" stroke="#5a3b14" stroke-width="1.5"/>
    <circle cx="50" cy="54" r="2.5" fill="#5fe3e6"/>
  </svg>`),

  bagSilk: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#14322a"/><stop offset="100%" stop-color="#060d0b"/></radialGradient>
      <linearGradient id="slk" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#3fa68a"/><stop offset="60%" stop-color="#1c5c4b"/><stop offset="100%" stop-color="#0d2e26"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M38 18 L62 18 L56 30 L44 30 Z" fill="#2c7a65" stroke="#c9a463" stroke-width="1.5"/>
    <path d="M40 30 Q20 46 24 74 Q28 86 50 86 Q72 86 76 74 Q80 46 60 30 Z" fill="url(#slk)" stroke="#c9a463" stroke-width="2"/>
    <rect x="39" y="28" width="22" height="5" rx="2" fill="#e0b86b"/>
    <polygon points="50,48 58,58 50,68 42,58" fill="#5fe3e6" stroke="#ffe7a6" stroke-width="1.5"/>
  </svg>`),

  bagArcane: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#1a2c4a"/><stop offset="100%" stop-color="#070c16"/></radialGradient>
      <linearGradient id="arc" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#3f6db3"/><stop offset="60%" stop-color="#1b345c"/><stop offset="100%" stop-color="#0d1a30"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M22 30 Q50 20 78 30 L82 78 Q50 88 18 78 Z" fill="url(#arc)" stroke="#88c9e8" stroke-width="2"/>
    <path d="M22 34 L50 56 L78 34" fill="none" stroke="#c9a463" stroke-width="2.5"/>
    <circle cx="50" cy="56" r="7" fill="#5fe3e6" stroke="#fff2c2" stroke-width="1.5"/>
  </svg>`),

  bagCrimson: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#361414"/><stop offset="100%" stop-color="#100606"/></radialGradient>
    <linearGradient id="rd" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#cf4036"/><stop offset="65%" stop-color="#7a1b14"/><stop offset="100%" stop-color="#3b0b08"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M38 18 L62 18 L56 30 L44 30 Z" fill="#8f241c" stroke="#c9a463" stroke-width="1.5"/>
    <path d="M40 30 Q20 46 24 74 Q28 86 50 86 Q72 86 76 74 Q80 46 60 30 Z" fill="url(#rd)" stroke="#c9a463" stroke-width="2"/>
    <rect x="39" y="28" width="22" height="5" rx="2" fill="#e0b86b"/>
  </svg>`),

  scroll: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#2e2518"/><stop offset="100%" stop-color="#0c0907"/></radialGradient>
      <linearGradient id="parch" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#f5e6c4"/><stop offset="60%" stop-color="#c9ad78"/><stop offset="100%" stop-color="#876b3f"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(-22) translate(-50 -50)">
      <rect x="26" y="22" width="48" height="56" rx="4" fill="url(#parch)" stroke="#5c4220" stroke-width="1.8"/>
      <rect x="22" y="18" width="56" height="9" rx="4" fill="#a8844c" stroke="#4a3314" stroke-width="1.2"/>
      <rect x="22" y="73" width="56" height="9" rx="4" fill="#a8844c" stroke="#4a3314" stroke-width="1.2"/>
      <line x1="34" y1="38" x2="66" y2="38" stroke="#664b26" stroke-width="2"/>
      <line x1="34" y1="47" x2="62" y2="47" stroke="#664b26" stroke-width="2"/>
      <line x1="34" y1="56" x2="54" y2="56" stroke="#664b26" stroke-width="2"/>
      <circle cx="62" cy="60" r="8" fill="#a81c1c" stroke="#f0b65a" stroke-width="1.4"/>
    </g>
  </svg>`),

  tome: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#2b1840"/><stop offset="100%" stop-color="#090612"/></radialGradient>
      <linearGradient id="cov" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#5a3480"/><stop offset="60%" stop-color="#2e1647"/><stop offset="100%" stop-color="#170a24"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <rect x="24" y="16" width="54" height="68" rx="4" fill="url(#cov)" stroke="#c9a463" stroke-width="2.5"/>
    <rect x="24" y="16" width="9" height="68" fill="#1e0e30" stroke="#c9a463" stroke-width="1.5"/>
    <circle cx="53" cy="50" r="14" fill="none" stroke="#5fe3e6" stroke-width="2"/>
    <polygon points="53,39 62,50 53,61 44,50" fill="#5fe3e6" opacity="0.9"/>
  </svg>`),

  hearthstone: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#16303d"/><stop offset="100%" stop-color="#060c12"/></radialGradient>
      <linearGradient id="st" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#c2ccd4"/><stop offset="50%" stop-color="#697580"/><stop offset="100%" stop-color="#2b3238"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <ellipse cx="50" cy="52" rx="28" ry="34" fill="url(#st)" stroke="#1b2228" stroke-width="2"/>
    <path d="M50 32 C62 32 66 44 60 52 C54 60 44 58 42 50 C40 42 46 38 52 40 C56 42 54 48 50 48" fill="none" stroke="#5fe3e6" stroke-width="4" stroke-linecap="round"/>
  </svg>`),

  key: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#14324e"/><stop offset="100%" stop-color="#060d16"/></radialGradient>
      <linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ffeaa8"/><stop offset="55%" stop-color="#c49545"/><stop offset="100%" stop-color="#5e4214"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(-35) translate(-50 -50)">
      <circle cx="50" cy="28" r="14" fill="none" stroke="url(#g)" stroke-width="6"/>
      <rect x="47" y="40" width="6" height="44" fill="url(#g)"/>
      <rect x="53" y="68" width="12" height="5" fill="url(#g)"/>
      <rect x="53" y="77" width="9" height="5" fill="url(#g)"/>
      <circle cx="50" cy="28" r="4" fill="#5fe3e6"/>
    </g>
  </svg>`),

  meat: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#2e1b12"/><stop offset="100%" stop-color="#0c0806"/></radialGradient>
      <radialGradient id="mt" cx="45%" cy="40%" r="55%"><stop offset="0%" stop-color="#e37c4d"/><stop offset="60%" stop-color="#8c361a"/><stop offset="100%" stop-color="#45180a"/></radialGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(-30) translate(-50 -50)">
      <rect x="46" y="54" width="8" height="28" rx="3" fill="#eee5d0"/>
      <circle cx="46" cy="82" r="5" fill="#eee5d0"/><circle cx="54" cy="82" r="5" fill="#eee5d0"/>
      <ellipse cx="50" cy="40" rx="24" ry="26" fill="url(#mt)" stroke="#381308" stroke-width="2"/>
      <ellipse cx="44" cy="33" rx="8" ry="5" fill="#ffbe99" opacity="0.45"/>
    </g>
  </svg>`),

  bandage: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#242930"/><stop offset="100%" stop-color="#0a0c10"/></radialGradient>
      <linearGradient id="cl" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#f2ede2"/><stop offset="65%" stop-color="#b8b09e"/><stop offset="100%" stop-color="#696255"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <ellipse cx="50" cy="48" rx="26" ry="24" fill="url(#cl)" stroke="#4f483e" stroke-width="2"/>
    <ellipse cx="50" cy="48" rx="10" ry="9" fill="#5e574c"/>
    <path d="M52 68 L78 78 L72 86 L42 72 Z" fill="url(#cl)" stroke="#4f483e" stroke-width="1.5"/>
  </svg>`),

  herb: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#133326"/><stop offset="100%" stop-color="#050e0a"/></radialGradient>
      <linearGradient id="lf" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#b5ffd4"/><stop offset="55%" stop-color="#3cb878"/><stop offset="100%" stop-color="#175234"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M50 82 Q48 54 32 30" fill="none" stroke="#5cc48c" stroke-width="3"/>
    <path d="M50 82 Q54 52 70 28" fill="none" stroke="#5cc48c" stroke-width="3"/>
    <path d="M32 30 Q18 36 22 52 Q36 48 32 30 Z" fill="url(#lf)"/>
    <path d="M50 16 Q38 36 50 56 Q62 36 50 16 Z" fill="url(#lf)"/>
    <path d="M70 28 Q82 38 76 54 Q62 46 70 28 Z" fill="url(#lf)"/>
    <rect x="44" y="68" width="12" height="5" rx="2" fill="#c9a463"/>
  </svg>`),

  perkBolt: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="50%" r="55%"><stop offset="0%" stop-color="#1c4f78"/><stop offset="100%" stop-color="#071324"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <polygon points="56,14 28,54 48,54 42,86 72,44 52,44" fill="#8ef7ff" stroke="#ffffff" stroke-width="2"/>
  </svg>`),

  perkShout: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="50%" r="55%"><stop offset="0%" stop-color="#612816"/><stop offset="100%" stop-color="#180804"/></radialGradient>
    <linearGradient id="sw" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#fff0c2"/><stop offset="55%" stop-color="#e39d24"/><stop offset="100%" stop-color="#783d08"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M50 14 L57 30 L55 62 L45 62 L43 30 Z" fill="url(#sw)" stroke="#fff7d6" stroke-width="1"/>
    <path d="M32 62 L68 62 L66 68 L34 68 Z" fill="#c9a463"/><rect x="47" y="68" width="6" height="14" fill="#5a3d14"/>
  </svg>`),
};

function spriteAltar(cx, cy, r = 62) {
  return { src: `${TOOLS}/craft-altar-concept/concept.jpg`, W: 2000, H: 2000, x: cx - r, y: cy - r, w: r * 2, h: r * 2 };
}
function spriteHelm(col, row) {
  return { src: `${TOOLS}/drops-concept/helmets_grid.jpg`, W: 1376, H: 768, x: col * 344 + 28, y: row * 384 + 22, w: 288, h: 330, screen: true };
}
function spriteBox(src, W, H, x, y, w, h) {
  return { src, W, H, x, y, w, h };
}

const SPRITES = {
  matAmethyst: spriteAltar(1000, 270, 62),
  matEmber:    spriteAltar(1516, 484, 62),
  matPearl:    spriteAltar(1730, 1000, 62),
  matIngot:    spriteAltar(1516, 1516, 62),
  matPotion:   spriteAltar(1000, 1730, 62),
  matRune:     spriteAltar(484, 1516, 62),
  matDust:     spriteAltar(270, 1000, 62),
  matWood:     spriteAltar(484, 484, 62),
  helmFlame:   spriteHelm(1, 0),
  helmObsid:   spriteHelm(2, 0),
  helmWinged:  spriteHelm(3, 0),
  helmCrown:   spriteHelm(2, 1),
  grimShield:  spriteBox(`${TOOLS}/grimoire-concept/concept.png`, 1376, 768, 574, 358, 56, 56),
};

function iconHtml(ref, size, extraStyle = "") {
  if (!ref) return "";
  const url = SVG_ICONS[ref];
  if (url) {
    return `<div class="ic-img" style="background-image:url('${url}');background-size:cover;background-position:center;${extraStyle}"></div>`;
  }
  const s = SPRITES[ref];
  if (!s) return "";
  const scale = size / Math.min(s.w, s.h);
  const bw = s.W * scale, bh = s.H * scale;
  const ox = s.x * scale + (s.w * scale - size) / 2;
  const oy = s.y * scale + (s.h * scale - size) / 2;
  const blend = s.screen ? "mix-blend-mode:lighten;" : "";
  return `<div class="ic-img" style="background-image:url('${s.src}');background-size:${bw.toFixed(1)}px ${bh.toFixed(1)}px;background-position:-${ox.toFixed(1)}px -${oy.toFixed(1)}px;${blend}${extraStyle}"></div>`;
}

// ============================================================================
// Ornamentos SVG AAA (Coroa Arquitetônica Azaath + Constelação BDO + Cadeado)
// ============================================================================
function crownSvg(w, accent) {
  return `<svg class="az-crown" style="width:${w}px" viewBox="0 0 320 52" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <linearGradient id="brz" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#f7e3ab"/><stop offset="45%" stop-color="#b89048"/><stop offset="100%" stop-color="#4e3814"/></linearGradient>
      <linearGradient id="cgem" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#eaffff"/><stop offset="45%" stop-color="#5fe3e6"/><stop offset="100%" stop-color="#0b4e5a"/></linearGradient>
      <radialGradient id="halo"><stop offset="0%" stop-color="${accent}" stop-opacity="0.72"/><stop offset="100%" stop-color="${accent}" stop-opacity="0"/></radialGradient>
    </defs>
    <ellipse cx="160" cy="30" rx="125" ry="20" fill="url(#halo)"/>
    <path d="M18 42 C58 42, 86 30, 118 30 L132 16 L160 4 L188 16 L202 30 C234 30, 262 42, 302 42" fill="#0b151e" stroke="url(#brz)" stroke-width="2"/>
    <path d="M44 42 C78 39, 102 32, 126 32 M276 42 C242 39, 218 32, 194 32" stroke="#7d6232" stroke-width="1.4" fill="none"/>
    <path d="M128 32 Q144 20 160 12 Q176 20 192 32 Q176 42 160 46 Q144 42 128 32 Z" fill="#071119" stroke="url(#brz)" stroke-width="1.8"/>
    <path d="M160 9 L172 28 L160 46 L148 28 Z" fill="url(#cgem)" stroke="#fff0bf" stroke-width="1.4"/>
    <path d="M160 9 L160 46 M148 28 L172 28" stroke="#ffffffaa" stroke-width="0.8"/>
    <circle cx="114" cy="33" r="3" fill="#e6c37a"/><circle cx="206" cy="33" r="3" fill="#e6c37a"/>
    <path d="M136 27 L142 23 M184 27 L178 23" stroke="#5fe3e6" stroke-width="1.6" stroke-linecap="round"/>
  </svg>`;
}

// Astrolábio Radial Completo (baseado na linguagem real de tools/radial-concept/gen.js)
function radialAstrolabeHtml() {
  const G = "#c9a86b", GL = "#f3dca6", GD = "#6e5630", COL = "#6ee698";
  const f = (n) => (+n).toFixed(2);
  const rad = (d) => (d * Math.PI) / 180;
  const pol = (cx, cy, r, deg) => [cx + r * Math.cos(rad(deg)), cy + r * Math.sin(rad(deg))];
  const diamond = (cx, cy, r, attrs) =>
    `<polygon points="${f(cx)},${f(cy - r)} ${f(cx + r)},${f(cy)} ${f(cx)},${f(cy + r)} ${f(cx - r)},${f(cy)}" ${attrs}/>`;
  const RUNES = [
    "M0 -5 V5 M0 -5 L3 -2 M0 0 L-3 3", "M-3 -5 V5 M-3 -1 L3 -5 M-3 -1 L3 5",
    "M0 -5 L3 0 L0 5 L-3 0 Z", "M-3 -5 L3 5 M3 -5 L-3 5 M-3 0 H3",
    "M0 -5 V5 M-3 -2 L0 -5 L3 -2", "M-3 5 V-5 L3 -1 L-3 2",
  ];
  const S = 480, C0 = 240, R_IN = 120, R_OUT = 198, R_SLOT = 159, R_CORE = 82;
  const aim = 1; // Poção de Cura em destaque (direita-topo)
  const aimDeg = (360 * aim) / 8;

  let b = `<svg viewBox="0 0 ${S} ${S}" class="rad-svg" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <filter id="rglow" x="-40%" y="-40%" width="180%" height="180%"><feGaussianBlur stdDeviation="2.5" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
    <linearGradient id="rgold" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="${GL}"/><stop offset=".5" stop-color="${G}"/><stop offset="1" stop-color="${GD}"/></linearGradient>
    <radialGradient id="rstone" cx=".5" cy=".42" r=".6"><stop offset="0" stop-color="#1b232d"/><stop offset=".72" stop-color="#0f141a"/><stop offset="1" stop-color="#070a0e"/></radialGradient>
    <radialGradient id="rpit" cx=".5" cy=".45" r=".55"><stop offset="0" stop-color="#131920"/><stop offset="1" stop-color="#040608"/></radialGradient>
    <radialGradient id="rwedge" cx="240" cy="240" r="200" gradientUnits="userSpaceOnUse"><stop offset=".55" stop-color="${COL}" stop-opacity="0"/><stop offset=".82" stop-color="${COL}" stop-opacity=".28"/><stop offset="1" stop-color="${COL}" stop-opacity=".75"/></radialGradient>
  </defs>
  <circle cx="${C0}" cy="${C0}" r="218" fill="url(#rstone)"/>
  <circle cx="${C0}" cy="${C0}" r="${R_OUT}" fill="#ffffff" opacity=".022"/>`;

  for (let d = 0; d < 360; d += 7.5) {
    const [x1, y1] = pol(C0, C0, R_IN + 4, d), [x2, y2] = pol(C0, C0, R_OUT - 4, d);
    b += `<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke="${G}" stroke-width=".6" opacity=".09"/>`;
  }
  // Banda de runas externa
  b += `<circle cx="${C0}" cy="${C0}" r="224" fill="none" stroke="${G}" stroke-width=".8" opacity=".55"/>`;
  b += `<circle cx="${C0}" cy="${C0}" r="236" fill="none" stroke="${G}" stroke-width=".8" opacity=".4"/>`;
  for (let i = 0; i < 48; i++) {
    const d = i * 7.5, [x, y] = pol(C0, C0, 230, d - 90);
    b += i % 6 === 0
      ? diamond(x, y, 2.8, `fill="${GL}" opacity=".9"`)
      : `<path d="${RUNES[(i * 5) % RUNES.length]}" transform="translate(${f(x)} ${f(y)}) rotate(${f(d)}) scale(.76)" fill="none" stroke="${GL}" stroke-width="1.15" stroke-linecap="round" opacity=".7"/>`;
  }

  // Aros principais & graduação
  b += `<circle cx="${C0}" cy="${C0}" r="${R_OUT}" fill="none" stroke="${G}" stroke-width="1.1" opacity=".5"/>`;
  b += `<circle cx="${C0}" cy="${C0}" r="${R_IN}" fill="none" stroke="url(#rgold)" stroke-width="1.8"/>`;
  b += `<circle cx="${C0}" cy="${C0}" r="207" fill="none" stroke="url(#rgold)" stroke-width="2.6"/>`;
  b += `<circle cx="${C0}" cy="${C0}" r="213" fill="none" stroke="${GD}" stroke-width="1.2"/>`;
  for (let d = 0; d < 360; d += 5) {
    const long = d % 45 === 0, mid = d % 15 === 0;
    const [x1, y1] = pol(C0, C0, 207, d), [x2, y2] = pol(C0, C0, long ? 216 : mid ? 213 : 211, d);
    b += `<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke="${long ? GL : G}" stroke-width="${long ? 1.6 : .8}" opacity="${long ? 1 : .7}"/>`;
  }
  for (let d = 0; d < 360; d += 90) {
    const [x, y] = pol(C0, C0, 210, d - 90);
    b += diamond(x, y, 6, `fill="url(#rgold)" stroke="${GD}" stroke-width=".7"`) + diamond(x, y, 2.5, `fill="#5fe3e6"`);
  }

  // Fatia iluminada (Poção de Cura)
  const half = 180 / 8 - 1.2;
  const [ax, ay] = pol(C0, C0, R_OUT - 1, -90 - half), [bx, by] = pol(C0, C0, R_OUT - 1, -90 + half);
  const [cx, cy] = pol(C0, C0, R_IN + 1, -90 + half), [dx, dy] = pol(C0, C0, R_IN + 1, -90 - half);
  const wd = `M${f(ax)} ${f(ay)} A${R_OUT - 1} ${R_OUT - 1} 0 0 1 ${f(bx)} ${f(by)} L${f(cx)} ${f(cy)} A${R_IN + 1} ${R_IN + 1} 0 0 0 ${f(dx)} ${f(dy)} Z`;
  const [ox, oy] = pol(C0, C0, R_OUT - 2, -90 - half), [px, py] = pol(C0, C0, R_OUT - 2, -90 + half);
  b += `<g transform="rotate(${f(aimDeg)} ${C0} ${C0})">
    <path d="${wd}" fill="url(#rwedge)"/>
    <path d="M${f(ox)} ${f(oy)} A${R_OUT - 2} ${R_OUT - 2} 0 0 1 ${f(px)} ${f(py)}" fill="none" stroke="#9effc4" stroke-width="2.8" filter="url(#rglow)"/>
  </g>`;

  // Divisores
  for (let i = 0; i < 8; i++) {
    const d = (360 * i) / 8 + 180 / 8;
    const [x1, y1] = pol(C0, C0, R_IN + 2, d - 90), [x2, y2] = pol(C0, C0, R_OUT, d - 90);
    b += `<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke="url(#rgold)" stroke-width="1.2" opacity=".75"/>`;
    b += diamond(x2, y2, 3.6, `fill="url(#rgold)" stroke="${GD}" stroke-width=".6"`);
  }

  // Núcleo central + ponteiro
  b += `<circle cx="${C0}" cy="${C0}" r="${R_CORE + 6}" fill="url(#rpit)" stroke="${GD}" stroke-width="1.2"/>`;
  b += `<circle cx="${C0}" cy="${C0}" r="${R_CORE}" fill="none" stroke="url(#rgold)" stroke-width="2.2"/>`;
  b += `<circle cx="${C0}" cy="${C0}" r="${R_CORE - 8}" fill="none" stroke="${G}" stroke-width=".8" opacity=".6"/>`;
  b += `<ellipse cx="${C0}" cy="${C0}" rx="${R_CORE - 16}" ry="${(R_CORE - 16) * 0.36}" fill="none" stroke="#5fe3e6" stroke-width=".7" opacity=".28"/>`;
  b += `<g transform="rotate(${f(aimDeg)} ${C0} ${C0})">
    <path d="M${C0} ${C0 - R_CORE - 20} L${C0 + 10} ${C0 - R_CORE - 2} L${C0} ${C0 - R_CORE - 7} L${C0 - 10} ${C0 - R_CORE - 2} Z" fill="url(#rgold)" stroke="#fff2c2" stroke-width=".9" filter="url(#rglow)"/>
  </g></svg>`;

  const radItems = [
    { ic: "hearthstone", cnt: "18m", cd: true },
    { ic: "healthPotion", cnt: "15", sel: true },
    { ic: "manaPotion", cnt: "8" },
    { ic: "goldElixir", cnt: "4" },
    { ic: "meat", cnt: "12" },
    { ic: "bandage", cnt: "20" },
    { ic: "speedVial", cnt: "6" },
    { ic: "arcaneTonic", cnt: "3" },
  ];

  let slotsHtml = "";
  radItems.forEach((it, i) => {
    const deg = (360 * i) / 8 - 90;
    const radA = (deg * Math.PI) / 180;
    const pctX = ((C0 + R_SLOT * Math.cos(radA)) / S) * 100;
    const pctY = ((C0 + R_SLOT * Math.sin(radA)) / S) * 100;
    if (it) {
      slotsHtml += `<div class="rad-node ${it.sel ? "sel" : ""} ${it.cd ? "cd" : ""}" style="left:${pctX.toFixed(2)}%;top:${pctY.toFixed(2)}%">
        <div class="rn-in">${iconHtml(it.ic, 38)}</div>
        <div class="rn-rim"></div>
        ${it.cd ? `<span class="rn-cd">${it.cnt}</span>` : `<span class="rn-cnt">${it.cnt}</span>`}
      </div>`;
    } else {
      slotsHtml += `<div class="rad-node empty" style="left:${pctX.toFixed(2)}%;top:${pctY.toFixed(2)}%"><span>+</span></div>`;
    }
  });

  return `<div class="rad-astro">
    ${b}
    <div class="rad-slots-layer">${slotsHtml}</div>
    <div class="rad-core-txt">
      <div class="rc-sub">CONSUMÍVEIS · G</div>
      <div class="rc-name">Poção de Cura</div>
      <div class="rc-hint">arraste para fixar</div>
    </div>
    <div class="rad-tabs">
      <span class="rtab"><i class="gem"></i>MENU</span>
      <span class="rtab"><i class="gem"></i>GESTOS</span>
      <span class="rtab on"><i class="gem"></i>CONSUMÍVEIS</span>
    </div>
  </div>`;
}

// ============================================================================
// CSS Geral (Azaath AAA Obsidian + Bronze Esculpido + Energia Ciano)
// ============================================================================
const CSS = `
@font-face{font-family:Cinzel;src:url(${FONTS}/Cinzel-Regular.ttf)}
@font-face{font-family:CinzelB;src:url(${FONTS}/Cinzel-Bold.ttf)}
@font-face{font-family:PTS;src:url(${FONTS}/PTSans-Regular.ttf)}
@font-face{font-family:PTSB;src:url(${FONTS}/PTSans-Bold.ttf)}
@font-face{font-family:Segoe;src:url(${FONTS}/SegoeUI-Regular.ttf)}
@font-face{font-family:SegoeB;src:url(${FONTS}/SegoeUI-Semibold.ttf)}

:root{
  --gold:#c9a463; --goldHi:#f5dfa6; --goldLo:#7a5e2f;
  --cy:#5fe3e6; --cyHi:#c7ffff; --cyLo:#186c7a;
  --txt:#efe7d4; --mut:#91a1ae; --dim:#5f6f7d;
}
*{box-sizing:border-box}
html,body{margin:0;padding:0;background:#020508;overflow:hidden;width:1920px;height:1080px}
.stage{position:relative;width:1920px;height:1080px;overflow:hidden;font-family:PTS,sans-serif;color:var(--txt);background:#04080d}
.abs{position:absolute}
.cz{font-family:Cinzel,serif}
.czb{font-family:CinzelB,serif}

/* Cenário vivo do mundo (sem personagem 3D no centro!) */
.world-bg{position:absolute;inset:0;background:url('${ASSETS}/vault_bg.jpg') center/cover no-repeat;filter:brightness(0.92) saturate(0.96)}
.world-atmos{position:absolute;inset:0;background:
  radial-gradient(60% 70% at 24% 48%, rgba(45,145,165,0.10), transparent 65%),
  linear-gradient(90deg, rgba(2,6,11,0.12) 0%, rgba(3,8,14,0.34) 42%, rgba(3,7,12,0.78) 68%, rgba(2,5,9,0.88) 100%)}
.world-floor-mist{position:absolute;left:0;bottom:0;width:100%;height:340px;
  background:radial-gradient(60% 80% at 28% 100%, rgba(58,185,205,0.12), transparent 70%);pointer-events:none}

/* HUD Azaath discreta na base esquerda (mostra integração perfeita sem colisão) */
.hud-preview{position:absolute;left:62px;bottom:-22px;width:540px;height:265px;
  background:url('${TOOLS}/azaath-hud-concept/concept.png') center/contain no-repeat;
  -webkit-mask-image:radial-gradient(48% 36% at 50% 54%, #000 56%, rgba(0,0,0,0.35) 78%, transparent 96%);
  opacity:0.90;pointer-events:none;filter:drop-shadow(0 8px 24px rgba(0,0,0,0.95))}

/* Etiqueta sutil de mundo aberto */
.world-tag{position:absolute;left:34px;top:28px;display:flex;align-items:center;gap:10px;padding:7px 14px;
  background:rgba(6,12,19,0.72);border:1px solid rgba(201,164,99,0.35);box-shadow:0 8px 24px rgba(0,0,0,0.55)}
.world-tag i{width:7px;height:7px;transform:rotate(45deg);background:var(--cy);box-shadow:0 0 8px var(--cy)}
.world-tag span{font-family:Cinzel,serif;font-size:10.5px;letter-spacing:2px;color:#d6e1e8}

/* =====================================================================
   MOLDURA MESTRE AZAATH AAA (aplicada na Mochila e na Aba Equipado)
   ===================================================================== */
.az-win{
  position:absolute;
  background:
    radial-gradient(120% 42% at 50% 0%, rgba(34,118,136,0.20), transparent 62%),
    radial-gradient(90% 35% at 50% 100%, rgba(24,70,88,0.16), transparent 65%),
    linear-gradient(180deg, rgba(11,19,28,0.94) 0%, rgba(6,11,17,0.97) 100%);
  border:1px solid #96773f;
  box-shadow:
    0 0 0 1px #030609,
    0 0 0 3px #101b24,
    0 0 0 4px rgba(122,94,47,0.75),
    inset 0 1px 0 rgba(199,255,255,0.22),
    inset 0 0 42px rgba(0,0,0,0.88),
    0 28px 70px rgba(0,0,0,0.92);
}
.az-win:before{content:"";position:absolute;inset:5px;border:1px solid rgba(201,164,99,0.20);pointer-events:none}
.az-win:after{content:"";position:absolute;left:18px;right:18px;top:-1px;height:2px;
  background:linear-gradient(90deg,transparent,rgba(95,227,230,0.85),transparent);box-shadow:0 0 12px rgba(95,227,230,0.55);pointer-events:none}

.az-crown{position:absolute;left:50%;top:-34px;height:52px;transform:translateX(-50%);pointer-events:none;z-index:8;filter:drop-shadow(0 6px 14px rgba(0,0,0,0.9))}

.gem-corner{position:absolute;width:11px;height:11px;transform:rotate(45deg);z-index:9;
  background:radial-gradient(circle at 35% 35%, #e8ffff, #5fe3e6 42%, #136875 88%);
  border:1px solid #e6c67e;box-shadow:0 0 10px rgba(95,227,230,0.75)}
.gem-corner.tl{left:-6px;top:-6px}.gem-corner.tr{right:-6px;top:-6px}.gem-corner.bl{left:-6px;bottom:-6px}.gem-corner.br{right:-6px;bottom:-6px}

/* =====================================================================
   ABA MENOR À ESQUERDA: EQUIPADO (ESTILO BLACK DESERT + ASTROLÁBIO AZAATH)
   ===================================================================== */
.eq-win{left:904px;top:156px;width:344px;height:738px;padding:22px 18px 16px;border-right-color:#7d6232}

/* Feixe de Acoplamento (dobradiça rúnica unindo Equipado <-> Mochila) */
.dock-bridge{position:absolute;left:1244px;top:248px;width:14px;height:550px;z-index:7;
  background:linear-gradient(180deg,transparent,rgba(95,227,230,0.16) 15%,rgba(201,164,99,0.35) 50%,rgba(95,227,230,0.16) 85%,transparent);
  border-left:1px solid rgba(201,164,99,0.5);border-right:1px solid rgba(201,164,99,0.5);
  display:flex;align-items:center;justify-content:center}
.dock-tab{width:20px;height:76px;background:linear-gradient(180deg,#152834,#09121a);border:1px solid #c9a463;
  box-shadow:0 0 14px rgba(95,227,230,0.4);display:flex;align-items:center;justify-content:center}
.dock-tab i{width:0;height:0;border-right:6px solid #5fe3e6;border-top:5px solid transparent;border-bottom:5px solid transparent;filter:drop-shadow(0 0 4px #5fe3e6)}

.eq-hdr{display:flex;align-items:center;justify-content:space-between;padding-bottom:10px;border-bottom:1px solid rgba(201,164,99,0.24)}
.eq-title-wrap{display:flex;align-items:center;gap:10px}
.gs-orb{position:relative;width:48px;height:48px;display:flex;align-items:center;justify-content:center;flex:none}
.gs-orb-art{position:absolute;inset:-4px;background:url('${ASSETS}/sh_orb.png') center/contain no-repeat;filter:drop-shadow(0 0 8px rgba(95,227,230,0.4))}
.gs-orb b{position:relative;font-family:CinzelB,serif;font-size:17px;color:#f5f0e1;text-shadow:0 0 8px rgba(95,227,230,0.65)}
.eq-sub{font-size:10px;color:#66eb9f;margin-top:2px;letter-spacing:0.4px}
.sheet-btn{height:24px;padding:0 9px;background:linear-gradient(180deg,#162634,#0a131c);border:1px solid rgba(201,164,99,0.65);
  font-family:Cinzel,serif;font-size:9.5px;letter-spacing:1.3px;color:#e9dfc8;display:flex;align-items:center;gap:5px}

/* Palco de Anel Estilo Black Desert (SEM boneco 3D: constelação rúnica Azaath ao centro!) */
.bdo-ring{position:relative;height:470px;margin:10px 0 8px;
  background:radial-gradient(circle at 50% 46%, rgba(28,88,104,0.22), rgba(5,10,16,0.62) 74%);
  border:1px solid rgba(95,227,230,0.16);overflow:hidden}
.bdo-constellation{position:absolute;inset:0;pointer-events:none}

/* Slots ao redor do Anel BDO */
.eq-slot-pos{position:absolute;transform:translate(-50%,-50%)}
.eq-slot-lbl{position:absolute;left:50%;bottom:-13px;transform:translateX(-50%);font-family:PTS,sans-serif;font-size:8.5px;letter-spacing:0.4px;color:#8c9da8;white-space:nowrap;text-shadow:0 1px 2px #000}

/* Mini barra de armas na base do anel BDO */
.bdo-wpn-lbl{position:absolute;left:0;right:0;bottom:78px;text-align:center;font-family:Cinzel,serif;font-size:9px;letter-spacing:2.4px;color:#b8c8d4;
  display:flex;align-items:center;gap:10px;padding:0 28px}
.bdo-wpn-lbl:before,.bdo-wpn-lbl:after{content:"";flex:1;height:1px;background:linear-gradient(90deg,transparent,rgba(201,164,99,0.55),transparent)}
.bdo-wpns{position:absolute;left:0;right:0;bottom:20px;display:flex;justify-content:center;gap:14px}

/* Pílulas de Telemetria + Integridade na base do painel Equipado */
.bdo-stats{display:grid;grid-template-columns:repeat(3,1fr);gap:6px;margin-top:6px}
.bstat{background:linear-gradient(180deg,rgba(14,26,36,0.85),rgba(7,13,20,0.92));border:1px solid rgba(201,164,99,0.28);padding:6px 4px;text-align:center}
.bstat .k{font-family:Cinzel,serif;font-size:8.5px;letter-spacing:1.4px;color:#8b9ca8}
.bstat .v{font-family:CinzelB,serif;font-size:13.5px;color:#f4ecda;margin-top:1px}
.bstat.cy .v{color:#86f5f7;text-shadow:0 0 8px rgba(95,227,230,0.45)}

.eq-foot{display:flex;align-items:center;justify-content:space-between;gap:8px;margin-top:10px}
.dur-pill{flex:1;padding:6px 10px;background:rgba(6,12,18,0.85);border:1px solid rgba(95,227,230,0.22)}
.dur-top{display:flex;justify-content:space-between;font-size:9.5px;color:#9eb0be;margin-bottom:4px}
.dur-bar{height:4px;background:#04080d;border:1px solid #22323d;position:relative}
.dur-bar i{position:absolute;left:0;top:0;bottom:0;background:linear-gradient(90deg,#1a8896,#5fe3e6);box-shadow:0 0 6px #5fe3e6}

/* =====================================================================
   JANELA PRINCIPAL DA MOCHILA À DIREITA (Disposição Atual + Estética AAA)
   ===================================================================== */
.bag-win{left:1256px;top:86px;width:626px;height:880px}
.bag-hdr{padding:20px 22px 0}
.bag-top{display:flex;align-items:center;justify-content:space-between}
.bag-title{display:flex;align-items:center;gap:11px}
.bag-title h1{margin:0;font-family:Cinzel,serif;font-size:21px;font-weight:400;letter-spacing:3.4px;color:#f5edd9;text-shadow:0 0 14px rgba(95,227,230,0.28)}
.cap-pill{font-family:CinzelB,serif;font-size:11px;letter-spacing:1px;color:#9df2f5;padding:2px 9px;
  background:rgba(15,44,56,0.55);border:1px solid rgba(95,227,230,0.38)}

.vtabs{display:flex;gap:18px;align-items:center}
.vtab{position:relative;font-family:Cinzel,serif;font-size:11px;letter-spacing:2px;color:#788996;padding-bottom:5px}
.vtab.on{color:#ebfbff;text-shadow:0 0 10px rgba(95,227,230,0.8)}
.vtab.on:after{content:"";position:absolute;left:-20px;right:-20px;bottom:-9px;height:13px;background:url('${ASSETS}/sh_navflare.png') center/100% 100% no-repeat;mix-blend-mode:screen}
.close-btn{width:24px;height:24px;border-radius:50%;background:radial-gradient(circle,#142330,#070d14);border:1px solid rgba(201,164,99,0.75);display:flex;align-items:center;justify-content:center}

/* Doca das 5 Mochilas (ícones reais + capacidade de cada bolsa + barra livre) */
.bags-dock{margin-top:11px;padding:7px 12px;background:rgba(5,11,17,0.78);border:1px solid rgba(201,164,99,0.28);
  display:flex;align-items:center;justify-content:space-between;gap:14px}
.bags-row{display:flex;align-items:center;gap:6px}
.bags-lbl{font-family:Cinzel,serif;font-size:9.5px;letter-spacing:1.6px;color:#c9bfa8;margin-right:3px}
.bag-cell{position:relative;width:32px;height:32px;background:#081018;border:1px solid #8a6d3a;overflow:hidden;box-shadow:inset 0 0 8px #000}
.bag-cell.main{border-color:#5fe3e6;box-shadow:0 0 8px rgba(95,227,230,0.3)}
.bag-cell.empty{border:1px dashed #334652;display:flex;align-items:center;justify-content:center;color:#5c6e7a;font-size:13px}
.bag-cell .bcap{position:absolute;right:1px;bottom:0;font-family:CinzelB,serif;font-size:8.5px;color:#fff;background:rgba(4,8,14,0.84);padding:0 2.5px;line-height:1.15}
.gauge-wrap{flex:1;max-width:250px}
.gauge-top{display:flex;justify-content:space-between;font-size:10px;color:#9eb0bd}
.gauge-bar{height:5px;background:#04080d;border:1px solid #22323d;position:relative;margin-top:4px}
.gauge-bar i{position:absolute;left:0;top:0;bottom:0;background:linear-gradient(90deg,#168694,#5fe3e6);box-shadow:0 0 8px #5fe3e6}

/* Controles: Busca, Ordenação, Botão de Trancar Item */
.bag-ctrl{display:flex;align-items:center;gap:7px;margin-top:10px}
.search-box{flex:1;height:28px;background:rgba(4,9,14,0.94);border:1px solid #2c3e49;display:flex;align-items:center;padding:0 10px;gap:7px;color:#738490;font-size:12px}
.lens{width:10px;height:10px;border:1.8px solid #7f919e;border-radius:50%;position:relative}
.lens:after{content:"";position:absolute;right:-5px;bottom:-4px;width:5px;height:1.8px;background:#7f919e;transform:rotate(45deg)}
.qmark{margin-left:auto;width:14px;height:14px;border-radius:50%;background:radial-gradient(circle,#f3d184,#9c7026);color:#140d02;font-weight:700;font-size:10px;display:flex;align-items:center;justify-content:center}

.sort-lbl{font-size:11px;color:#8c9ba8;margin-left:2px}
.ico-btn{width:26px;height:26px;background:rgba(10,18,26,0.9);border:1px solid #30414c;display:flex;align-items:center;justify-content:center}
.ico-btn img{width:14px;height:14px;opacity:0.84}
.ico-btn.on{border-color:#5fe3e6;box-shadow:0 0 10px rgba(95,227,230,0.36)}
.lock-mode-btn{height:26px;padding:0 10px;background:linear-gradient(180deg,#2a2112,#141008);border:1px solid #c9a463;
  color:#f5dfa6;font-family:Cinzel,serif;font-size:9.5px;letter-spacing:1.3px;display:flex;align-items:center;gap:5px;
  box-shadow:0 0 10px rgba(201,164,99,0.22)}

/* Pílulas de Filtro Rápido */
.filter-strip{display:flex;gap:6px;margin-top:10px;padding-bottom:10px;border-bottom:1px solid rgba(201,164,99,0.22)}
.fpill{padding:3.5px 10px;border-radius:11px;font-size:10.5px;color:#8e9da8;background:rgba(10,18,26,0.74);border:1px solid rgba(90,110,124,0.28)}
.fpill.on{color:#f0fcff;background:linear-gradient(180deg,rgba(24,84,96,0.78),rgba(11,44,54,0.88));border-color:#5fe3e6;box-shadow:0 0 10px rgba(95,227,230,0.32)}

/* Corpo em 2 Colunas (disposição da mochila atual) */
.bag-body{padding:12px 22px 0;display:grid;grid-template-columns:1fr 1fr;gap:18px}
.sec-hdr{display:flex;align-items:center;gap:7px;margin:0 0 7px}
.sec-hdr .t{font-family:Cinzel,serif;font-size:11px;letter-spacing:2px;color:#dfd4b8}
.sec-hdr .ln{flex:1;height:1px;background:linear-gradient(90deg,rgba(201,164,99,0.55),rgba(201,164,99,0.06))}
.sec-hdr .n{font-family:CinzelB,serif;font-size:12px;color:#e6dec8}
.sec-hdr .ar{width:13px;height:13px;border:1px solid #594726;background:#0a131a;position:relative}
.sec-hdr .ar:after{content:"";position:absolute;left:2.5px;top:4px;border-top:4.5px solid #c9a463;border-left:3.5px solid transparent;border-right:3.5px solid transparent}

.slot-grid{display:grid;grid-template-columns:repeat(5,48px);gap:7px;margin-bottom:13px}

/* Espaços de Item (Mochila + Equipado) */
.islot{position:relative;width:48px;height:48px;background:radial-gradient(circle at 50% 35%,#1b2934,#091016 80%);
  border:1px solid #35444e;box-shadow:inset 0 0 0 1px #000,inset 0 0 10px #000}
.islot:before,.islot:after{content:"";position:absolute;width:6px;height:6px;border:1px solid rgba(201,164,99,0.58);pointer-events:none;z-index:3}
.islot:before{left:-1px;top:-1px;border-right:0;border-bottom:0}
.islot:after{right:-1px;bottom:-1px;border-left:0;border-top:0}
.islot .ic-wrap{position:absolute;inset:3px;overflow:hidden;background:#070c11}
.ic-img{width:100%;height:100%;background-repeat:no-repeat}

.islot.q2{border-color:#2e9a46;box-shadow:inset 0 0 9px rgba(63,207,90,0.34),0 0 6px rgba(63,207,90,0.22)}
.islot.q3{border-color:#2f78de;box-shadow:inset 0 0 9px rgba(61,148,255,0.40),0 0 8px rgba(61,148,255,0.28)}
.islot.q4{border-color:#9e46eb;box-shadow:inset 0 0 11px rgba(194,77,255,0.48),0 0 10px rgba(194,77,255,0.36)}
.islot.locked-item{box-shadow:inset 0 0 0 1px rgba(245,223,166,0.55),0 0 9px rgba(201,164,99,0.36)}
.islot.hovered{border-color:#d5ffff;box-shadow:0 0 0 2px #5fe3e6,0 0 18px rgba(95,227,230,0.85),inset 0 0 12px rgba(194,77,255,0.7);z-index:5}
.islot .ilvl{position:absolute;left:3px;top:2px;font-family:CinzelB,serif;font-size:9.5px;color:#f5efe0;text-shadow:0 1px 3px #000,0 0 4px #000;z-index:4}
.islot .cnt{position:absolute;right:3px;bottom:1px;font-family:CinzelB,serif;font-size:11px;color:#fff;text-shadow:0 1px 2px #000,0 0 4px #000;z-index:4}
.islot .dur{position:absolute;left:4px;right:4px;bottom:3px;height:2.5px;background:#0a0f14;z-index:4}
.islot .dur i{display:block;height:100%;background:#5fe3e6}
.islot .dur.mid i{background:#f0a830}
.islot .qbadge{position:absolute;right:-4px;top:-4px;width:15px;height:15px;background:url('${ASSETS}/inv_badge.png') center/contain no-repeat;z-index:5}
.islot .newgem{position:absolute;right:3px;top:3px;width:6px;height:6px;transform:rotate(45deg);background:#ffd966;box-shadow:0 0 6px #ffd966;z-index:5}
.islot .lockpip{position:absolute;right:2px;top:2px;width:14px;height:14px;border-radius:2px;background:rgba(12,16,22,0.92);
  border:1px solid #e6c37a;display:flex;align-items:center;justify-content:center;z-index:6;box-shadow:0 0 6px rgba(0,0,0,0.9)}
.islot.empty-eq{background:rgba(6,11,17,0.72);border-color:#2b3a44}
.islot.empty-eq .esig{position:absolute;inset:10px;border:1px dashed rgba(95,227,230,0.22);border-radius:3px}

/* Materiais redondos com aro Azaath */
.islot.round{border-radius:50%;border:0;background:none;box-shadow:none}
.islot.round:before,.islot.round:after{display:none}
.islot.round .ic-wrap{inset:4px;border-radius:50%}
.islot.round .rframe{position:absolute;inset:-3px;background:url('${ASSETS}/sh_roundframe.png') center/contain no-repeat;pointer-events:none;z-index:3}
.islot.round.q3 .rframe{filter:drop-shadow(0 0 5px rgba(61,148,255,0.85))}
.islot.round.q4 .rframe{filter:drop-shadow(0 0 5px rgba(194,77,255,0.9))}
.islot.round.q2 .rframe{filter:drop-shadow(0 0 4px rgba(63,207,90,0.8))}
.islot.round .cnt{right:1px;bottom:0;font-size:10.5px;background:rgba(5,10,16,0.85);padding:0 3px;border-radius:3px}

.islot.free{background:rgba(8,14,20,0.65);border:1px dashed #334550;display:flex;align-items:center;justify-content:center}
.islot.free span{font-family:CinzelB,serif;font-size:14.5px;color:#788894}

/* Rodapé da Mochila (SEM botão de vender cinzas!) */
.bag-foot{position:absolute;left:22px;right:22px;bottom:14px;height:46px;border-top:1px solid rgba(201,164,99,0.24);
  display:flex;align-items:center;justify-content:space-between;padding-top:6px}
.money{display:flex;align-items:center;gap:12px;font-family:CinzelB,serif;font-size:16px;color:#f4ecda}
.coin{display:inline-block;width:12px;height:12px;border-radius:50%;margin-left:3.5px;vertical-align:-1px;box-shadow:0 1px 2px #000}
.coin.g{background:radial-gradient(circle at 35% 30%,#fff6bd,#e5b53e 50%,#855810)}
.coin.s{background:radial-gradient(circle at 35% 30%,#ffffff,#c2cbd1 50%,#5b646b)}
.coin.c{background:radial-gradient(circle at 35% 30%,#ffd8b0,#c86f32 50%,#662f0f)}
.foot-btns{display:flex;gap:8px}
.sbtn{position:relative;height:30px;padding:0 13px;background:linear-gradient(180deg,rgba(22,34,48,0.94),rgba(10,16,24,0.97));
  border:1px solid rgba(138,109,58,0.68);font-family:Cinzel,serif;font-size:10px;letter-spacing:1.4px;color:#efe6cf;display:flex;align-items:center;gap:6px}
.sbtn.on{border-color:#5fe3e6;box-shadow:0 0 12px rgba(95,227,230,0.32)}
.sbtn:after{content:"";position:absolute;left:10px;right:10px;bottom:-1px;height:2px;background:linear-gradient(90deg,transparent,#5fe3e6,transparent);box-shadow:0 0 8px #5fe3e6}
.sbtn.gold:after{background:linear-gradient(90deg,transparent,#e6b450,transparent);box-shadow:0 0 8px #e6b450}

/* =====================================================================
   MENU RADIAL ASTROLÁBIO AZAATH (esquerda inferior, ao lado da Aba Equipado)
   ===================================================================== */
.rad-wrap{position:absolute;left:606px;top:628px;width:276px;height:310px;z-index:8}
.rad-astro{position:relative;width:276px;height:276px;filter:drop-shadow(0 18px 42px rgba(0,0,0,0.92))}
.rad-connector{position:absolute;left:886px;top:768px;width:44px;height:1px;border-top:1px dashed rgba(95,227,230,0.45);z-index:6;pointer-events:none}
.rad-connector:after{content:"";position:absolute;right:-3px;top:-3px;width:5px;height:5px;transform:rotate(45deg);background:#5fe3e6;box-shadow:0 0 6px #5fe3e6}
.rad-svg{width:100%;height:100%;display:block}
.rad-slots-layer{position:absolute;inset:0}
.rad-node{position:absolute;width:38px;height:38px;transform:translate(-50%,-50%);border-radius:50%}
.rad-node.sel{transform:translate(-50%,-50%) scale(1.14);z-index:4}
.rad-node .rn-in{position:absolute;inset:3px;border-radius:50%;overflow:hidden;background:#080e14}
.rad-node .rn-rim{position:absolute;inset:-2px;background:url('${ASSETS}/sh_roundframe.png') center/contain no-repeat;pointer-events:none}
.rad-node.sel .rn-rim{filter:drop-shadow(0 0 7px #74f2a8)}
.rad-node.cd .rn-in{filter:brightness(0.45)}
.rad-node .rn-cd{position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-family:PTSB,sans-serif;font-size:10px;color:#fff;text-shadow:0 1px 3px #000}
.rad-node .rn-cnt{position:absolute;right:-2px;bottom:-2px;font-family:CinzelB,serif;font-size:10px;color:#fff;text-shadow:0 1px 2px #000,0 0 4px #000}
.rad-node.empty{background:rgba(7,12,18,0.85);border:1px solid #3c4b55;display:flex;align-items:center;justify-content:center;color:#627480;font-size:13px}
.rad-core-txt{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);text-align:center;width:96px;pointer-events:none}
.rc-sub{font-family:Cinzel,serif;font-size:7px;letter-spacing:1.4px;color:#7fe8a8}
.rc-name{font-family:CinzelB,serif;font-size:10px;color:#fff;margin-top:2px;line-height:1.15;text-shadow:0 0 6px rgba(110,230,152,0.7)}
.rc-hint{font-size:8px;color:#8fa0ad;margin-top:3px}
.rad-tabs{position:absolute;left:0;right:0;bottom:-22px;display:flex;justify-content:center;gap:16px}
.rtab{display:flex;align-items:center;gap:4px;font-family:Cinzel,serif;font-size:8px;letter-spacing:1.3px;color:#6e7f8c}
.rtab .gem{width:6px;height:6px;transform:rotate(45deg);background:#485662;display:inline-block}
.rtab.on{color:#7fe8a8;text-shadow:0 0 8px rgba(127,232,168,0.55)}
.rtab.on .gem{background:#7fe8a8;box-shadow:0 0 6px #7fe8a8}

/* =====================================================================
   CARD DE ITEM + COMPARAÇÃO LIMPA (esquerda superior, sem colisão)
   ===================================================================== */
.icard{position:relative;width:302px;background:#131314;border:1px solid #050506;box-shadow:inset 0 0 0 1px #404247,0 20px 52px rgba(0,0,0,0.90)}
.eq-tab{position:relative;display:inline-flex;align-items:center;justify-content:center;height:20px;padding:0 12px;background:#131314;
  border:1px solid #050506;border-bottom:0;box-shadow:inset 1px 1px 0 #404247,inset -1px 0 0 #404247;margin-bottom:-1px;z-index:2}
.eq-tab span{font-family:SegoeB,sans-serif;font-size:11px;color:#ffd140;border-bottom:1px solid rgba(255,209,64,0.72);padding-bottom:1px}
.ic-head{position:relative;height:78px;overflow:hidden;border-bottom:1px solid rgba(255,255,255,0.45)}
.ic-paper{position:absolute;inset:0;background:url('${ASSETS}/ic_grunge.png') center/100% 100% no-repeat;filter:brightness(1.05)}
.ic-tint{position:absolute;inset:0;mix-blend-mode:multiply}
.ic-smoke1{position:absolute;inset:-20px 0 0 0;background:url('${ASSETS}/ic_smoke1.png') 0 20%/115% auto repeat;mix-blend-mode:screen;opacity:0.5}
.ic-flare{position:absolute;left:0;right:0;bottom:0;height:62px;background:url('${ASSETS}/ic_flare.png') center bottom/100% 100% no-repeat;mix-blend-mode:screen;opacity:0.65}
.ic-head-content{position:relative;z-index:3;height:100%;display:flex;align-items:center;padding:0 10px;gap:10px}
.ic-icon-box{position:relative;width:58px;height:58px;flex:none;padding:2px;box-shadow:0 4px 12px rgba(0,0,0,0.7)}
.ic-icon-inner{width:100%;height:100%;overflow:hidden;background:#08080a}
.ic-hmeta{flex:1;min-width:0;height:58px;display:flex;flex-direction:column;justify-content:space-between;padding:1px 0}
.ic-name{font-family:SegoeB,sans-serif;font-size:14.5px;line-height:1.15;text-shadow:1px 1px 2px #000}
.ic-rar{font-family:SegoeB,sans-serif;font-size:11px;text-shadow:1px 1px 2px #000}
.ic-botrow{display:flex;justify-content:space-between;font-family:SegoeB,sans-serif;font-size:11px;color:#fff;text-shadow:1px 1px 2px #000}
.icard.epic .ic-tint{background:linear-gradient(180deg,#5a1380 0%,#b838f5 100%)}
.icard.epic .ic-smoke1,.icard.epic .ic-flare{filter:sepia(1) hue-rotate(245deg) saturate(5)}
.icard.epic .ic-icon-box{background:linear-gradient(180deg,#6e1b99,#08080a);border:1px solid #db6bff}
.icard.epic .ic-name,.icard.epic .ic-rar{color:#df78ff}
.icard.uncommon .ic-tint{background:linear-gradient(180deg,#165919 0%,#36bf36 100%)}
.icard.uncommon .ic-smoke1,.icard.uncommon .ic-flare{filter:sepia(1) hue-rotate(75deg) saturate(4)}
.icard.uncommon .ic-icon-box{background:linear-gradient(180deg,#1d6e20,#08080a);border:1px solid #5fe84d}
.icard.uncommon .ic-name,.icard.uncommon .ic-rar{color:#61f24c}
.ic-body{padding:9px 12px 11px;font-family:Segoe,sans-serif;font-size:11.8px;color:#dcdcdc}
.ilvl-row{display:flex;align-items:center;gap:7px;margin-bottom:3px}
.ilvl-hex{width:24px;height:24px;background:url('${ASSETS}/ic_ilvl.png') center/contain no-repeat}
.ilvl-val{font-family:SegoeB,sans-serif;font-size:26px;line-height:1;color:#fff;text-shadow:1px 1px 2px #000}
.stat-ln{line-height:1.35;color:#dcdcdc}.stat-ln b{font-family:SegoeB,sans-serif;color:#fff;font-weight:400}
.div-dia{position:relative;height:10px;margin:5px 0;display:flex;align-items:center}
.div-dia:before,.div-dia:after{content:"";flex:1;height:1px;background:rgba(82,83,86,0.9)}
.div-dia i{width:9px;height:9px;margin:0 4px;background:url('${ASSETS}/ic_diamond.png') center/contain no-repeat;opacity:0.78}
.perk-row{display:flex;align-items:flex-start;gap:7px;margin:4px 0}
.perk-ic{position:relative;width:22px;height:22px;flex:none;margin-top:1px}
.perk-ic .in{position:absolute;inset:2px;border-radius:50%;overflow:hidden}
.perk-ic .ring{position:absolute;inset:-1px;background:url('${ASSETS}/ic_perkring.png') center/contain no-repeat}
.perk-txt{font-family:SegoeB,sans-serif;font-size:11.4px;line-height:1.28;color:#6ba8ff}.perk-txt .pre{color:#9ecbff}
.delta-ln{font-size:11.5px;color:#45e074;margin-top:2px}
`;

// Ícone pequeno de cadeado dourado SVG para o botão e para os slots trancados
const LOCK_SVG = `<svg width="10" height="10" viewBox="0 0 16 16" fill="none" xmlns="http://www.w3.org/2000/svg">
  <path d="M5 7V5a3 3 0 0 1 6 0v2" stroke="#f5dfa6" stroke-width="1.8" stroke-linecap="round"/>
  <rect x="3.5" y="7" width="9" height="7" rx="1.5" fill="#c9a463" stroke="#fff3c9" stroke-width="0.9"/>
  <circle cx="8" cy="10.5" r="1" fill="#181207"/>
</svg>`;

function slot(ic, opts = {}) {
  const cls = [
    "islot",
    opts.q || "",
    opts.round ? "round" : "",
    opts.hovered ? "hovered" : "",
    opts.locked ? "locked-item" : "",
    opts.emptyEq ? "empty-eq" : "",
  ].filter(Boolean).join(" ");

  const sz = opts.sz || 48;
  const st = opts.sz ? `width:${sz}px;height:${sz}px;` : "";
  return `<div class="${cls}" style="${st}">
    ${opts.emptyEq ? `<div class="esig"></div>` : `<div class="ic-wrap">${iconHtml(ic, sz - 6)}</div>`}
    ${opts.round ? `<div class="rframe"></div>` : ""}
    ${opts.ilvl ? `<span class="ilvl">${opts.ilvl}</span>` : ""}
    ${opts.cnt ? `<span class="cnt">${opts.cnt}</span>` : ""}
    ${opts.dur != null ? `<div class="dur ${opts.dur < 70 ? "mid" : ""}"><i style="width:${opts.dur}%"></i></div>` : ""}
    ${opts.quest ? `<div class="qbadge"></div>` : ""}
    ${opts.isNew ? `<div class="newgem"></div>` : ""}
    ${opts.locked ? `<div class="lockpip">${LOCK_SVG}</div>` : ""}
  </div>`;
}

function buildHtml() {
  // Anel ovalado estilo Black Desert ao redor do núcleo rúnico central (centro em 153, 188 dentro de 306x470)
  // Top-arc + lados em anel + base com Relíquias e Arsenal Ativo: zero espaço morto em cima/embaixo!
  const CX = 153, CY = 186;
  const bdoNodes = [
    // Arco Superior (Amuleto / Cabeça / Ombros)
    { x: 153, y: 38,  ic: "helmWinged", q: "q3", ilvl: 38, dur: 96,  lbl: "Cabeça" },
    { x: 76,  y: 64,  ic: "amulet",     q: "q2", ilvl: 32,           lbl: "Amuleto" },
    { x: 230, y: 64,  ic: "pauldrons",  q: "q3", ilvl: 36, dur: 98,  lbl: "Ombros" },
    // Flanco Esquerdo
    { x: 34,  y: 122, ic: "cloak",      q: "q4", ilvl: 42, dur: 100, lbl: "Manto" },
    { x: 28,  y: 186, ic: "chestplate", q: "q4", ilvl: 44, dur: 94,  lbl: "Torso" },
    { x: 36,  y: 250, ic: "bracers",    q: "q2", ilvl: 30, dur: 90,  lbl: "Pulsos" },
    { x: 64,  y: 308, ic: "gauntlets",  q: "q2", ilvl: 31, dur: 88,  lbl: "Mãos" },
    // Flanco Direito
    { x: 272, y: 122, ic: "belt",       q: "q3", ilvl: 35, dur: 100, lbl: "Cinto" },
    { x: 278, y: 186, ic: "greaves",    q: "q3", ilvl: 36, dur: 92,  lbl: "Pernas" },
    { x: 270, y: 250, ic: "boots",      q: "q2", ilvl: 30, dur: 95,  lbl: "Botas" },
    { x: 242, y: 308, ic: "ring",       q: "q3", ilvl: 35,           lbl: "Anel I" },
    // Arco Inferior (Relíquia I + Anel II) + Relíquia II acima do núcleo
    { x: 118, y: 332, ic: "tome",       q: "q3", ilvl: 34,           lbl: "Relíquia" },
    { x: 188, y: 332, ic: "ringRuby",   q: "q4", ilvl: 40,           lbl: "Anel II" },
    { x: 153, y: 106, ic: null,         emptyEq: true,               lbl: "Relíquia II" },
  ];

  // Linhas de constelação ligando cada slot equipado ao núcleo rúnico central
  let constLines = "";
  bdoNodes.forEach((n) => {
    const stroke = n.q === "q4" ? "#c278ff" : n.q === "q3" ? "#5fe3e6" : "#c9a463";
    const op = n.emptyEq ? "0.14" : "0.42";
    constLines += `<line x1="${CX}" y1="${CY}" x2="${n.x}" y2="${n.y}" stroke="${stroke}" stroke-width="1" opacity="${op}"/>`;
    if (!n.emptyEq) {
      const mx = (CX + n.x) / 2, my = (CY + n.y) / 2;
      constLines += `<circle cx="${mx.toFixed(1)}" cy="${my.toFixed(1)}" r="2.1" fill="${stroke}" opacity="0.72"/>`;
    }
  });

  const constellationSvg = `<svg class="bdo-constellation" viewBox="0 0 306 470" xmlns="http://www.w3.org/2000/svg">
    <defs>
      <radialGradient id="ccore" cx="50%" cy="50%" r="50%"><stop offset="0%" stop-color="#5fe3e6" stop-opacity="0.38"/><stop offset="62%" stop-color="#196070" stop-opacity="0.14"/><stop offset="100%" stop-color="transparent"/></radialGradient>
    </defs>
    <circle cx="${CX}" cy="${CY}" r="134" fill="url(#ccore)"/>
    <ellipse cx="${CX}" cy="${CY}" rx="124" ry="144" fill="none" stroke="#c9a463" stroke-width="0.9" stroke-dasharray="3 4" opacity="0.36"/>
    <circle cx="${CX}" cy="${CY}" r="94" fill="none" stroke="#c9a463" stroke-width="0.9" stroke-dasharray="4 4" opacity="0.40"/>
    <circle cx="${CX}" cy="${CY}" r="58" fill="none" stroke="#5fe3e6" stroke-width="1.2" opacity="0.50"/>
    <circle cx="${CX}" cy="${CY}" r="38" fill="#061018" stroke="#c9a463" stroke-width="1.6" opacity="0.94"/>
    <polygon points="${CX},${CY - 48} ${CX + 11},${CY - 11} ${CX + 48},${CY} ${CX + 11},${CY + 11} ${CX},${CY + 48} ${CX - 11},${CY + 11} ${CX - 48},${CY} ${CX - 11},${CY - 11}"
      fill="none" stroke="#5fe3e6" stroke-width="1" opacity="0.55"/>
    <circle cx="${CX}" cy="${CY}" r="14" fill="none" stroke="#5fe3e6" stroke-width="1.5" opacity="0.88"/>
    <polygon points="${CX},${CY - 8} ${CX + 8},${CY} ${CX},${CY + 8} ${CX - 8},${CY}" fill="#5fe3e6" opacity="0.85"/>
    ${constLines}
  </svg>`;

  const eqSlotsHtml = bdoNodes.map((n) =>
    `<div class="eq-slot-pos" style="left:${n.x}px;top:${n.y}px">${slot(n.ic, { q: n.q, ilvl: n.ilvl, dur: n.dur, emptyEq: n.emptyEq, sz: 44 })}</div>`
  ).join("");

  // 2) Seções da Mochila (Disposição atual em 2 colunas)
  function sec(title, n, body) {
    return `<div><div class="sec-hdr"><span class="t">${title}</span><span class="ln"></span><span class="n">${n}</span><span class="ar"></span></div>
      <div class="slot-grid">${body}</div></div>`;
  }

  const colLeft = [
    sec("ARMAS", 3,
      slot("epicSword", { q: "q4", ilvl: 48, dur: 100, hovered: true, isNew: true }) +
      slot("obsidianAxe", { q: "q3", ilvl: 36, dur: 94, locked: true }) +
      slot("dagger", { q: "q2", ilvl: 29, dur: 100 })
    ),
    sec("EQUIPAMENTO", 5,
      slot("helmFlame", { q: "q4", ilvl: 45, dur: 100, locked: true }) +
      slot("helmWinged", { q: "q3", ilvl: 38, dur: 88 }) +
      slot("helmCrown", { q: "q3", ilvl: 34, dur: 100 }) +
      slot("gauntlets", { q: "q2", ilvl: 31, dur: 58 }) +
      slot("chestplate", { q: "q2", ilvl: 27, dur: 100 })
    ),
    sec("CONSUMÍVEIS", 10,
      slot("healthPotion", { cnt: 15 }) +
      slot("manaPotion", { q: "q2", cnt: 8 }) +
      slot("goldElixir", { q: "q3", cnt: 4 }) +
      slot("meat", { cnt: 12 }) +
      slot("bandage", { cnt: 20 }) +
      slot("hearthstone", { cnt: 1, locked: true }) +
      slot("matPotion", { q: "q2", cnt: 3, isNew: true }) +
      slot("furyElixir", { q: "q2", cnt: 5 }) +
      slot("arcaneTonic", { q: "q3", cnt: 2 }) +
      slot("speedVial", { q: "q2", cnt: 6 })
    ),
    sec("ESPAÇO LIVRE", 20, `<div class="islot free"><span>20</span></div>`),
  ].join("");

  const colRight = [
    sec("MATERIAIS", 9,
      slot("matRune", { round: true, q: "q3", cnt: 14 }) +
      slot("matAmethyst", { round: true, q: "q4", cnt: 6 }) +
      slot("matEmber", { round: true, q: "q3", cnt: 3 }) +
      slot("matIngot", { round: true, cnt: 12 }) +
      slot("matDust", { round: true, cnt: 24 }) +
      slot("matPearl", { round: true, q: "q2", cnt: 2 }) +
      slot("matWood", { round: true, cnt: 18 }) +
      slot("herb", { round: true, cnt: 16 }) +
      slot("matPotion", { round: true, q: "q2", cnt: 5 })
    ),
    sec("MISSÃO", 5,
      slot("scroll", { quest: true, isNew: true }) +
      slot("tome", { quest: true }) +
      slot("key", { quest: true, cnt: 3 }) +
      slot("hearthstone", { quest: true }) +
      slot("matRune", { quest: true })
    ),
    sec("DIVERSOS", 3,
      slot("key", { q: "q3", locked: true }) +
      slot("amulet", { q: "q2" }) +
      slot("ring", { q: "q3" })
    ),
  ].join("");

  return `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Inventário BDO + Azaath — Arte Conceitual AAA</title>
<style>${CSS}</style></head><body>
<div class="stage">
  <div class="world-bg"></div>
  <div class="world-atmos"></div>
  <div class="world-floor-mist"></div>

  <div class="world-tag"><i></i><span>MUNDO ABERTO</span></div>
  <div class="hud-preview"></div>

  <!-- COMPARAÇÃO DE ITEM FLUTUANTE (à esquerda do conjunto, sem colisões) -->
  <div class="abs" style="left:572px;top:94px;z-index:9">
    <div class="eq-tab"><span>Equipado no momento</span></div>
    <div class="icard uncommon">
      <div class="ic-head">
        <div class="ic-paper"></div><div class="ic-tint"></div><div class="ic-smoke1"></div><div class="ic-flare"></div>
        <div class="ic-head-content">
          <div class="ic-icon-box"><div class="ic-icon-inner">${iconHtml("greenSword", 54)}</div></div>
          <div class="ic-hmeta">
            <div><div class="ic-name">Espada Larga da Vigília</div><div class="ic-rar">Incomum</div></div>
            <div class="ic-botrow"><span>Espada</span><span>Duas Mãos</span></div>
          </div>
        </div>
      </div>
      <div class="ic-body">
        <div class="ilvl-row"><div class="ilvl-hex"></div><div class="ilvl-val">34</div></div>
        <div class="stat-ln"><b>58 - 96</b> Dano · <b>2.60</b> Vel. · <b>+10</b> Força</div>
        <div class="div-dia"><i></i></div>
        <div class="delta-ln">Se equipar selecionada: +26 – 46 Dano · +8 Força</div>
      </div>
    </div>
  </div>

  <div class="abs" style="left:572px;top:314px;z-index:10">
    <div class="icard epic">
      <div class="ic-head">
        <div class="ic-paper"></div><div class="ic-tint"></div><div class="ic-smoke1"></div><div class="ic-flare"></div>
        <div class="ic-head-content">
          <div class="ic-icon-box"><div class="ic-icon-inner">${iconHtml("epicSword", 54)}</div></div>
          <div class="ic-hmeta">
            <div><div class="ic-name">Lâmina Rúnica de Azaath</div><div class="ic-rar">Épico · Único</div></div>
            <div class="ic-botrow"><span>Espada</span><span>Duas Mãos</span></div>
          </div>
        </div>
      </div>
      <div class="ic-body">
        <div class="ilvl-row"><div class="ilvl-hex"></div><div class="ilvl-val">48</div></div>
        <div class="stat-ln"><b>84 - 142</b> Dano · <b>2.80</b> Vel. · <b>40.4</b> DPS</div>
        <div class="div-dia"><i></i></div>
        <div class="stat-ln"><b>+18</b> Força · <b>+14</b> Vigor · <b>+9</b> Crítico</div>
        <div class="div-dia"><i></i></div>
        <div class="perk-row">
          <div class="perk-ic"><div class="in">${iconHtml("perkBolt", 20)}</div><div class="ring"></div></div>
          <div class="perk-txt"><span class="pre">Chance ao acertar:</span> Canaliza Azoth causando 65 de dano extra.</div>
        </div>
      </div>
    </div>
  </div>

  <!-- MENU RADIAL ASTROLÁBIO AZAATH (G) -->
  <div class="rad-wrap">${radialAstrolabeHtml()}</div>
  <div class="rad-connector"></div>

  <!-- ABA MENOR ACOPLADA À ESQUERDA: EQUIPADO (ESTILO BLACK DESERT + AZAATH) -->
  <aside class="az-win eq-win">
    ${crownSvg(220, "#5fe3e6")}
    <i class="gem-corner tl"></i><i class="gem-corner bl"></i>

    <div class="eq-hdr">
      <div class="eq-title-wrap">
        <div class="gs-orb"><div class="gs-orb-art"></div><b>38</b></div>
        <div>
          <div class="cz" style="font-size:14px;letter-spacing:2.4px;color:#f5edd9">EQUIPADO</div>
          <div class="eq-sub">Nível de Item · 96% Íntegro</div>
        </div>
      </div>
      <div class="sheet-btn">FICHA (C)</div>
    </div>

    <!-- Anel de Equipamento Black Desert (constelação rúnica central, zero boneco 3D) -->
    <div class="bdo-ring">
      ${constellationSvg}
      ${eqSlotsHtml}
      <div class="bdo-wpn-lbl">ARSENAL ATIVO</div>
      <div class="bdo-wpns">
        ${slot("greenSword", { q: "q2", ilvl: 34, dur: 94, sz: 46, locked: true })}
        ${slot("shield",     { q: "q3", ilvl: 37, dur: 98, sz: 46 })}
        ${slot("bow",        { q: "q2", ilvl: 31, dur: 100, sz: 46 })}
      </div>
    </div>

    <div class="bdo-stats">
      <div class="bstat cy"><div class="k">PODER ATQ</div><div class="v">375</div></div>
      <div class="bstat"><div class="k">ARMADURA</div><div class="v">1.357</div></div>
      <div class="bstat"><div class="k">CRÍTICO</div><div class="v">11.9%</div></div>
    </div>

    <div class="eq-foot">
      <div class="dur-pill">
        <div class="dur-top"><span class="cz" style="letter-spacing:1.2px">INTEGRIDADE</span><span style="color:#8cf4f7">96%</span></div>
        <div class="dur-bar"><i style="width:96%"></i></div>
      </div>
      <div class="sbtn gold" style="height:32px;padding:0 12px">REPARAR</div>
    </div>
  </aside>

  <!-- DOBRADIÇA RÚNICA ENTRE EQUIPADO E MOCHILA -->
  <div class="dock-bridge"><div class="dock-tab"><i></i></div></div>

  <!-- JANELA PRINCIPAL DA MOCHILA À DIREITA -->
  <main class="az-win bag-win">
    ${crownSvg(300, "#c9a463")}
    <i class="gem-corner tl"></i><i class="gem-corner tr"></i><i class="gem-corner bl"></i><i class="gem-corner br"></i>

    <div class="bag-hdr">
      <div class="bag-top">
        <div class="bag-title">
          <h1>INVENTÁRIO</h1>
          <span class="cap-pill">46 / 66</span>
        </div>
        <div style="display:flex;align-items:center;gap:16px">
          <div class="vtabs">
            <span class="vtab on">CATEGORIAS</span>
            <span class="vtab">BOLSAS</span>
          </div>
          <div class="close-btn"><svg width="10" height="10" viewBox="0 0 16 16"><path d="M3 3 L13 13 M13 3 L3 13" stroke="#e6dcc5" stroke-width="1.8" stroke-linecap="round"/></svg></div>
        </div>
      </div>

      <!-- DOCA DAS 5 MOCHILAS COM ÍCONES REAIS -->
      <div class="bags-dock">
        <div class="bags-row">
          <span class="bags-lbl">MOCHILAS</span>
          <div class="bag-cell main">${iconHtml("bagLeather", 32)}<span class="bcap">16</span></div>
          <div class="bag-cell">${iconHtml("bagSilk", 32)}<span class="bcap">14</span></div>
          <div class="bag-cell">${iconHtml("bagArcane", 32)}<span class="bcap">12</span></div>
          <div class="bag-cell">${iconHtml("bagCrimson", 32)}<span class="bcap">12</span></div>
          <div class="bag-cell">${iconHtml("bagLeather", 32)}<span class="bcap">12</span></div>
        </div>
        <div class="gauge-wrap">
          <div class="gauge-top"><span class="cz" style="letter-spacing:1.4px">ESPAÇO LIVRE</span><span style="color:#e6f9ff">20 / 66 LIVRES</span></div>
          <div class="gauge-bar"><i style="width:70%"></i></div>
        </div>
      </div>

      <div class="bag-ctrl">
        <div class="search-box"><span class="lens"></span><span>Buscar item...</span><span class="qmark">?</span></div>
        <span class="sort-lbl">Ordenar</span>
        <div class="ico-btn on"><img src="${ASSETS}/inv_clock.png"></div>
        <div class="ico-btn"><img src="${ASSETS}/inv_star.png"></div>
        <div class="ico-btn"><img src="${ASSETS}/inv_tier.png"></div>
        <div class="lock-mode-btn">${LOCK_SVG}<span>TRANCAR</span></div>
      </div>

      <div class="filter-strip">
        <span class="fpill on">Todos</span>
        <span class="fpill">Armas</span>
        <span class="fpill">Equip.</span>
        <span class="fpill">Consumíveis</span>
        <span class="fpill">Materiais</span>
        <span class="fpill">Missão</span>
        <span class="fpill">Diversos</span>
      </div>
    </div>

    <div class="bag-body">
      <div>${colLeft}</div>
      <div>${colRight}</div>
    </div>

    <!-- RODAPÉ LIMPO (SEM BOTÃO DE VENDER CINZAS!) -->
    <div class="bag-foot">
      <div class="money">
        <span>142<i class="coin g"></i></span>
        <span>65<i class="coin s"></i></span>
        <span>30<i class="coin c"></i></span>
      </div>
      <div class="foot-btns">
        <div class="sbtn gold">${LOCK_SVG}<span>TRANCAR ITEM</span></div>
        <div class="sbtn on">RADIAL (G)</div>
      </div>
    </div>
  </main>
</div>
</body></html>`;
}

fs.writeFileSync(HTML_FILE, buildHtml(), "utf8");
console.log("HTML gravado:", HTML_FILE);

const r = spawnSync(EDGE, [
  "--headless=new",
  "--disable-gpu",
  "--no-sandbox",
  "--user-data-dir=" + EDGE_PROF,
  "--hide-scrollbars",
  "--force-device-scale-factor=1.3333334",
  "--window-size=1920,1080",
  "--virtual-time-budget=1400",
  "--allow-file-access-from-files",
  "--screenshot=" + OUT_PNG,
  "file:///" + HTML_FILE.replace(/\\/g, "/"),
], { encoding: "utf8" });

console.log("Edge status:", r.status, "PNG:", OUT_PNG, fs.existsSync(OUT_PNG) ? fs.statSync(OUT_PNG).size + " bytes" : "ERRO");
if (r.status !== 0 && r.stderr) console.error(r.stderr);
