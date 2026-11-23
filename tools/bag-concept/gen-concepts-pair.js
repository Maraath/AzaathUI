// Gera DUAS artes conceituais para o Inventário (ambas SEM tela cheia):
//   1) Azaath_Inventario_Conceito1_AtualPolido.png  (mesma disposição atual, visual polido Azaath 2026 + novo ItemCard)
//   2) Azaath_Inventario_Conceito2_ModularSurpresa.png (disposição inovadora modular acoplada à direita, zero colisões)
//
//   node tools/bag-concept/gen-concepts-pair.js
//
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const DIR = __dirname;
const ROOT = path.resolve(DIR, "../..");
const FONTS = "file:///" + path.join(ROOT, "AzaathUI/Media/Fonts").replace(/\\/g, "/");
const ASSETS = "file:///" + path.join(DIR, "assets").replace(/\\/g, "/");
const TOOLS = "file:///" + path.join(ROOT, "tools").replace(/\\/g, "/");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const EDGE_PROF = path.join(ROOT, "tools/.cache/edge-concept-prof");
fs.mkdirSync(EDGE_PROF, { recursive: true });

function svgUrl(svg) {
  return "data:image/svg+xml;base64," + Buffer.from(svg.trim(), "utf8").toString("base64");
}

const SVG = {
  // Armas
  swordRare: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#143a66"/><stop offset="100%" stop-color="#050d1a"/></radialGradient>
    <linearGradient id="bl" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#e8f8ff"/><stop offset="50%" stop-color="#6da6d9"/><stop offset="100%" stop-color="#1d3857"/></linearGradient>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ffe7a6"/><stop offset="100%" stop-color="#8a601e"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <circle cx="52" cy="48" r="34" fill="#3d94ff" opacity="0.22"/>
    <g transform="translate(50 50) rotate(42) translate(-50 -50)">
      <path d="M50 9 L57 23 L55 64 L45 64 L43 23 Z" fill="url(#bl)" stroke="#d6f0ff" stroke-width="1.1"/>
      <path d="M50 16 L50 58" stroke="#5fe3e6" stroke-width="2.2" stroke-linecap="round"/>
      <path d="M29 63 Q50 57 71 63 L68 69 Q50 65 32 69 Z" fill="url(#g)" stroke="#fff2c2" stroke-width="0.9"/>
      <rect x="46.5" y="68" width="7" height="17" rx="2" fill="#1e2d40" stroke="url(#g)" stroke-width="1"/>
      <circle cx="50" cy="89" r="5.5" fill="url(#g)" stroke="#fff2c2" stroke-width="0.9"/>
      <circle cx="50" cy="65" r="3.8" fill="#5fe3e6"/>
    </g></svg>`),

  swordGreen: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#183d27"/><stop offset="100%" stop-color="#06100a"/></radialGradient>
    <linearGradient id="bl" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#f2f7f4"/><stop offset="50%" stop-color="#8ca196"/><stop offset="100%" stop-color="#334039"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(42) translate(-50 -50)">
      <path d="M50 11 L57 24 L56 64 L44 64 L43 24 Z" fill="url(#bl)" stroke="#dceee4" stroke-width="1.1"/>
      <path d="M31 63 L69 63 L67 69 L33 69 Z" fill="#c9a463" stroke="#f5dfa2" stroke-width="0.8"/>
      <rect x="46.5" y="69" width="7" height="16" rx="2" fill="#2b2114" stroke="#c9a463" stroke-width="0.9"/>
      <circle cx="50" cy="89" r="5" fill="#c9a463"/><circle cx="50" cy="66" r="3.4" fill="#4ce67a"/>
    </g></svg>`),

  axeWhite: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#262e36"/><stop offset="100%" stop-color="#090c10"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(35) translate(-50 -50)">
      <rect x="47" y="16" width="6" height="72" rx="2" fill="#6b4628" stroke="#a8844c" stroke-width="0.8"/>
      <path d="M52 22 Q72 18 82 12 Q88 32 80 50 Q68 42 52 44 Z" fill="#b8c4cc" stroke="#eef5f8" stroke-width="1.2"/>
    </g></svg>`),

  maceWhite: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#262d34"/><stop offset="100%" stop-color="#090b0f"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(38) translate(-50 -50)">
      <rect x="47" y="34" width="6" height="54" rx="2" fill="#5c3d22"/>
      <circle cx="50" cy="30" r="15" fill="#8f9ca6" stroke="#e4ecf2" stroke-width="1.4"/>
      <polygon points="50,8 54,17 46,17" fill="#e4ecf2"/><polygon points="71,30 62,34 62,26" fill="#e4ecf2"/><polygon points="29,30 38,34 38,26" fill="#e4ecf2"/>
    </g></svg>`),

  gun: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#2b241c"/><stop offset="100%" stop-color="#0a0806"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(-32) translate(-50 -50)">
      <rect x="26" y="42" width="54" height="8" rx="2" fill="#98a4ad" stroke="#e0e8ed" stroke-width="1"/>
      <path d="M16 58 L36 48 L48 54 L26 70 Q18 68 16 58 Z" fill="#704724" stroke="#c9a463" stroke-width="1"/>
    </g></svg>`),

  // Armaduras e acessórios
  helmGold: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#193b26"/><stop offset="100%" stop-color="#06100a"/></radialGradient>
    <linearGradient id="hd" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ffe7a6"/><stop offset="55%" stop-color="#b58335"/><stop offset="100%" stop-color="#52350e"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M24 62 Q22 22 50 18 Q78 22 76 62 L70 82 L56 82 L56 54 L44 54 L44 82 L30 82 Z" fill="url(#hd)" stroke="#fff0bd" stroke-width="1.5"/>
    <path d="M36 44 L46 48 M64 44 L54 48" stroke="#5fe3e6" stroke-width="3" stroke-linecap="round"/>
  </svg>`),

  pauldrons: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#193a26"/><stop offset="100%" stop-color="#06100a"/></radialGradient>
    <linearGradient id="st" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#e2eaef"/><stop offset="55%" stop-color="#6e7c85"/><stop offset="100%" stop-color="#273036"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M14 54 Q22 22 46 28 L44 68 Q22 72 14 54 Z" fill="url(#st)" stroke="#c9a463" stroke-width="2"/>
    <path d="M86 54 Q78 22 54 28 L56 68 Q78 72 86 54 Z" fill="url(#st)" stroke="#c9a463" stroke-width="2"/>
    <circle cx="30" cy="46" r="4" fill="#4ce67a"/><circle cx="70" cy="46" r="4" fill="#4ce67a"/>
  </svg>`),

  cloak: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#291742"/><stop offset="100%" stop-color="#090612"/></radialGradient>
    <linearGradient id="ck" x1="0" y1="0" x2="0" y2="1"><stop offset="0%" stop-color="#61338f"/><stop offset="100%" stop-color="#220f38"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M34 18 Q50 24 66 18 L80 82 Q50 90 20 82 Z" fill="url(#ck)" stroke="#c9a463" stroke-width="2"/>
    <circle cx="34" cy="19" r="4" fill="#c9a463"/><circle cx="66" cy="19" r="4" fill="#c9a463"/>
  </svg>`),

  chestplate: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#193b26"/><stop offset="100%" stop-color="#06100a"/></radialGradient>
    <linearGradient id="steel" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#dce6ec"/><stop offset="50%" stop-color="#6e7c85"/><stop offset="100%" stop-color="#2b3338"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M22 20 L36 16 Q50 28 64 16 L78 20 L82 42 L70 46 L68 80 Q50 88 32 80 L30 46 L18 42 Z" fill="url(#steel)" stroke="#c9a463" stroke-width="2.5"/>
    <path d="M50 28 L50 80 M34 48 L66 48" stroke="#c9a463" stroke-width="1.8" opacity="0.85"/>
  </svg>`),

  bracers: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#193b26"/><stop offset="100%" stop-color="#06100a"/></radialGradient>
    <linearGradient id="st" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ced8de"/><stop offset="55%" stop-color="#5b666e"/><stop offset="100%" stop-color="#23292e"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M32 22 Q50 16 68 22 L72 78 Q50 84 28 78 Z" fill="url(#st)" stroke="#c9a463" stroke-width="2.4"/>
    <path d="M31 38 Q50 34 69 38 M30 62 Q50 58 70 62" stroke="#c9a463" stroke-width="2" fill="none"/>
  </svg>`),

  gauntlets: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#193b26"/><stop offset="100%" stop-color="#06100a"/></radialGradient>
    <linearGradient id="st" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#d5dee4"/><stop offset="50%" stop-color="#606c75"/><stop offset="100%" stop-color="#23292e"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M35 20 L42 20 L42 42 L45 42 L45 16 L52 16 L52 42 L55 42 L55 18 L62 18 L62 44 L66 44 L66 28 L72 28 L72 56 Q72 68 62 72 L62 86 L36 86 L36 72 Q28 66 28 52 L28 36 L35 36 Z" fill="url(#st)" stroke="#c9a463" stroke-width="2"/>
    <rect x="34" y="68" width="30" height="5" fill="#c9a463"/>
  </svg>`),

  belt: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#193b26"/><stop offset="100%" stop-color="#06100a"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M14 42 Q50 52 86 42 L86 60 Q50 70 14 60 Z" fill="#5e3d20" stroke="#c9a463" stroke-width="2"/>
    <rect x="38" y="38" width="24" height="28" rx="4" fill="#c9a463" stroke="#fff2c2" stroke-width="1.5"/>
    <circle cx="50" cy="52" r="6" fill="#4ce67a"/>
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

  ring: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#133352"/><stop offset="100%" stop-color="#050b14"/></radialGradient>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#ffeaa8"/><stop offset="50%" stop-color="#c49545"/><stop offset="100%" stop-color="#5e4214"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <ellipse cx="50" cy="58" rx="24" ry="22" fill="none" stroke="url(#g)" stroke-width="9"/>
    <polygon points="50,20 62,32 50,44 38,32" fill="#46b6ff" stroke="#ffeaa8" stroke-width="2.2"/>
  </svg>`),

  ringSilver: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#193b26"/><stop offset="100%" stop-color="#06100a"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <ellipse cx="50" cy="56" rx="24" ry="22" fill="none" stroke="#cfd8de" stroke-width="8"/>
    <circle cx="50" cy="30" r="8" fill="#4ce67a" stroke="#ffffff" stroke-width="1.5"/>
  </svg>`),

  amulet: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#163826"/><stop offset="100%" stop-color="#07100c"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M24 14 Q50 54 76 14" fill="none" stroke="#c9a463" stroke-width="3.5" stroke-dasharray="4 2"/>
    <polygon points="50,36 68,58 50,84 32,58" fill="#2bd965" stroke="#ffe7a6" stroke-width="3"/>
  </svg>`),

  // Bolsas
  bagRed: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#361414"/><stop offset="100%" stop-color="#100606"/></radialGradient>
    <linearGradient id="rd" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#cf4036"/><stop offset="65%" stop-color="#7a1b14"/><stop offset="100%" stop-color="#3b0b08"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M38 18 L62 18 L56 30 L44 30 Z" fill="#8f241c" stroke="#c9a463" stroke-width="1.5"/>
    <path d="M40 30 Q20 46 24 74 Q28 86 50 86 Q72 86 76 74 Q80 46 60 30 Z" fill="url(#rd)" stroke="#c9a463" stroke-width="2"/>
    <rect x="39" y="28" width="22" height="5" rx="2" fill="#e0b86b"/>
  </svg>`),

  bagLeather: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#2b2118"/><stop offset="100%" stop-color="#0c0907"/></radialGradient>
    <linearGradient id="lea" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#a87648"/><stop offset="60%" stop-color="#5c3a1e"/><stop offset="100%" stop-color="#2e1b0d"/></linearGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M24 34 Q24 24 50 24 Q76 24 76 34 L80 76 Q80 86 50 86 Q20 86 20 76 Z" fill="url(#lea)" stroke="#c9a463" stroke-width="2"/>
    <path d="M23 38 Q50 56 77 38 L76 48 Q50 66 24 48 Z" fill="#3a2311" stroke="#c9a463" stroke-width="1.2"/>
    <rect x="44" y="47" width="12" height="14" rx="2" fill="#e0b86b" stroke="#5a3b14" stroke-width="1.5"/>
  </svg>`),

  // Consumíveis / Missão / Diversos
  bread: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#2e2114"/><stop offset="100%" stop-color="#0c0805"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <ellipse cx="50" cy="54" rx="30" ry="20" fill="#d99a45" stroke="#5e3a12" stroke-width="2.5"/>
    <path d="M30 46 Q38 56 32 62 M50 42 Q58 54 52 64 M68 46 Q74 56 68 62" stroke="#f5cb78" stroke-width="2.5" fill="none" stroke-linecap="round"/>
  </svg>`),

  cheese: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#2b2412"/><stop offset="100%" stop-color="#0b0905"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <polygon points="20,66 50,24 84,54 84,74 20,74" fill="#f0c348" stroke="#7d5910" stroke-width="2"/>
    <circle cx="46" cy="56" r="5" fill="#b88418"/><circle cx="64" cy="62" r="4" fill="#b88418"/>
  </svg>`),

  meat: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#2e1b12"/><stop offset="100%" stop-color="#0c0806"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(-30) translate(-50 -50)">
      <rect x="46" y="54" width="8" height="28" rx="3" fill="#eee5d0"/>
      <ellipse cx="50" cy="40" rx="24" ry="26" fill="#9c3c1e" stroke="#381308" stroke-width="2"/>
      <ellipse cx="44" cy="33" rx="8" ry="5" fill="#ffbe99" opacity="0.45"/>
    </g></svg>`),

  healthPotion: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#3d151d"/><stop offset="100%" stop-color="#0e0608"/></radialGradient>
    <radialGradient id="liq" cx="42%" cy="40%" r="60%"><stop offset="0%" stop-color="#ff8594"/><stop offset="55%" stop-color="#c91832"/><stop offset="100%" stop-color="#590814"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <rect x="43" y="14" width="14" height="10" rx="2" fill="#8f6338"/>
    <rect x="41" y="22" width="18" height="12" fill="#7da0b0" opacity="0.55" stroke="#d8eef8" stroke-width="1"/>
    <path d="M41 34 L30 48 Q22 60 28 74 Q34 86 50 86 Q66 86 72 74 Q78 60 70 48 L59 34 Z" fill="url(#liq)" stroke="#e4f4ff" stroke-width="1.8"/>
    <ellipse cx="39" cy="56" rx="5" ry="11" transform="rotate(-18 39 56)" fill="#ffffff" opacity="0.4"/>
  </svg>`),

  vialSlender: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#36141a"/><stop offset="100%" stop-color="#0d0507"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <rect x="44" y="14" width="12" height="9" rx="2" fill="#8f6338"/>
    <rect x="35" y="24" width="30" height="60" rx="14" fill="#d9263e" stroke="#e4f4ff" stroke-width="1.8"/>
    <line x1="42" y1="34" x2="42" y2="72" stroke="#ffffff" stroke-width="3" stroke-linecap="round" opacity="0.4"/>
  </svg>`),

  manaCup: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#12364a"/><stop offset="100%" stop-color="#050c12"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M24 36 L76 36 L68 78 Q50 86 32 78 Z" fill="#2ccce6" stroke="#dff9ff" stroke-width="2"/>
    <ellipse cx="50" cy="36" rx="26" ry="7" fill="#a8f9ff"/>
  </svg>`),

  hearthstone: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#16303d"/><stop offset="100%" stop-color="#060c12"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <ellipse cx="50" cy="52" rx="28" ry="34" fill="#7c8a96" stroke="#1b2228" stroke-width="2"/>
    <path d="M50 32 C62 32 66 44 60 52 C54 60 44 58 42 50 C40 42 46 38 52 40" fill="none" stroke="#5fe3e6" stroke-width="4" stroke-linecap="round"/>
  </svg>`),

  torch: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#362210"/><stop offset="100%" stop-color="#0d0804"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(35) translate(-50 -50)">
      <rect x="46" y="42" width="8" height="46" rx="2" fill="#6b4420" stroke="#c9a463" stroke-width="1"/>
      <path d="M36 42 Q50 10 64 42 Q50 50 36 42 Z" fill="#ff962e" stroke="#fff099" stroke-width="1.5"/>
    </g></svg>`),

  scroll: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#2e2518"/><stop offset="100%" stop-color="#0c0907"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <g transform="translate(50 50) rotate(-22) translate(-50 -50)">
      <rect x="26" y="22" width="48" height="56" rx="4" fill="#d9c090" stroke="#5c4220" stroke-width="1.8"/>
      <rect x="22" y="18" width="56" height="9" rx="4" fill="#a8844c"/><rect x="22" y="73" width="56" height="9" rx="4" fill="#a8844c"/>
      <circle cx="62" cy="60" r="8" fill="#a81c1c" stroke="#f0b65a" stroke-width="1.4"/>
    </g></svg>`),

  tome: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#261b12"/><stop offset="100%" stop-color="#0a0806"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <rect x="24" y="16" width="54" height="68" rx="4" fill="#5e4124" stroke="#c9a463" stroke-width="2.5"/>
    <rect x="24" y="16" width="9" height="68" fill="#362412" stroke="#c9a463" stroke-width="1.5"/>
    <polygon points="53,38 63,50 53,62 43,50" fill="#e9d29a"/>
  </svg>`),

  silkCloth: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#301836"/><stop offset="100%" stop-color="#0d0710"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M22 30 Q50 18 78 30 L74 74 Q50 86 26 74 Z" fill="#c775d9" stroke="#f0c2fa" stroke-width="2"/>
    <path d="M24 46 Q50 38 76 46" fill="none" stroke="#ffe7ff" stroke-width="2" opacity="0.6"/>
  </svg>`),

  orbStone: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="45%" r="60%"><stop offset="0%" stop-color="#1c2b38"/><stop offset="100%" stop-color="#070c12"/></radialGradient>
    <radialGradient id="ob" cx="38%" cy="35%" r="60%"><stop offset="0%" stop-color="#ffffff"/><stop offset="55%" stop-color="#b8c4cc"/><stop offset="100%" stop-color="#4e5962"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <circle cx="50" cy="50" r="28" fill="url(#ob)" stroke="#243038" stroke-width="2"/>
  </svg>`),

  perkBolt: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="50%" r="55%"><stop offset="0%" stop-color="#1c4f78"/><stop offset="100%" stop-color="#071324"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <polygon points="56,14 28,54 48,54 42,86 72,44 52,44" fill="#8ef7ff" stroke="#ffffff" stroke-width="2"/>
  </svg>`),

  perkShout: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs><radialGradient id="bg" cx="50%" cy="50%" r="55%"><stop offset="0%" stop-color="#612816"/><stop offset="100%" stop-color="#180804"/></radialGradient></defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M50 14 L57 30 L55 62 L45 62 L43 30 Z" fill="#f5d17a" stroke="#fff7d6" stroke-width="1"/>
    <path d="M32 62 L68 62 L66 68 L34 68 Z" fill="#c9a463"/>
    <rect x="47" y="68" width="6" height="14" fill="#5a3d14"/>
  </svg>`),
};

function spriteAltar(cx, cy, r = 62) {
  return { src: `${TOOLS}/craft-altar-concept/concept.jpg`, W: 2000, H: 2000, x: cx - r, y: cy - r, w: r * 2, h: r * 2 };
}
const SPRITES = {
  matAmethyst: spriteAltar(1000, 270, 62),
  matRune:     spriteAltar(484, 1516, 62),
  matPotion:   spriteAltar(1000, 1730, 62),
  matIngot:    spriteAltar(1516, 1516, 62),
  matDust:     spriteAltar(270, 1000, 62),
  grimShield:  { src: `${TOOLS}/grimoire-concept/concept.png`, W: 1376, H: 768, x: 574, y: 358, w: 56, h: 56 },
};

function iconHtml(ref) {
  if (!ref) return "";
  if (SVG[ref]) return `<div class="ic-img" style="background-image:url('${SVG[ref]}');background-size:cover;background-position:center"></div>`;
  const s = SPRITES[ref];
  if (!s) return "";
  // Usa percentual CSS para caber em qualquer tamanho de slot
  const bx = (s.W / s.w) * 100, by = (s.H / s.h) * 100;
  const px = (s.x / (s.W - s.w)) * 100, py = (s.y / (s.H - s.h)) * 100;
  return `<div class="ic-img" style="background-image:url('${s.src}');background-size:${bx.toFixed(2)}% ${by.toFixed(2)}%;background-position:${px.toFixed(2)}% ${py.toFixed(2)}%"></div>`;
}

function sparksHtml(n, w, h, col, seed) {
  let r = seed, out = "";
  const rnd = () => (r = (r * 9301 + 49297) % 233280) / 233280;
  for (let i = 0; i < n; i++) {
    const x = rnd() * w, y = h * (0.18 + rnd() * 0.78), sz = 5 + rnd() * 8, op = 0.45 + rnd() * 0.55;
    const isEmber = rnd() < 0.35;
    out += `<img src="${ASSETS}/${isEmber ? "ic_ember.png" : "ic_spark.png"}" style="position:absolute;left:${x.toFixed(0)}px;top:${y.toFixed(0)}px;width:${isEmber ? (sz * 0.55).toFixed(0) : sz.toFixed(0)}px;height:${isEmber ? (sz * 1.8).toFixed(0) : sz.toFixed(0)}px;opacity:${op.toFixed(2)};mix-blend-mode:screen;filter:drop-shadow(0 0 4px ${col})">`;
  }
  return out;
}

function slotHtml(ic, o = {}) {
  const cls = ["islot", o.q || "", o.round ? "round" : "", o.hov ? "hov" : "", o.empty ? "empty" : ""].filter(Boolean).join(" ");
  return `<div class="${cls}">
    <div class="ic-wrap">${ic ? iconHtml(ic) : `<div class="sil"></div>`}</div>
    ${o.round ? `<div class="rframe"></div>` : ""}
    ${o.ilvl ? `<span class="ilvl">${o.ilvl}</span>` : ""}
    ${o.cnt ? `<span class="cnt">${o.cnt}</span>` : ""}
    ${o.dur != null ? `<div class="dur ${o.dur < 70 ? "mid" : ""}"><i style="width:${o.dur}%"></i></div>` : ""}
    ${o.quest ? `<div class="qbadge"></div>` : ""}
  </div>`;
}

// Novo ItemCard + Comparação reutilizável
function itemCardPairHtml(leftMain, topMain, leftCmp, topCmp, compact = false, showCompare = true) {
  const cmpHtml = !showCompare ? "" : `
  <div class="abs" style="left:${leftCmp}px;top:${topCmp}px;z-index:18">
    <div class="eq-tab"><span>Equipado no momento</span></div>
    <div class="icard uncommon" style="width:${compact ? 302 : 334}px">
      <div class="ic-head" style="height:76px">
        <div class="ic-paper"></div><div class="ic-tint"></div><div class="ic-smoke1"></div><div class="ic-flare"></div>
        <div class="ic-fx">${sparksHtml(8, 300, 74, "#61f24c", 91)}</div>
        <div class="ic-head-content">
          <div class="ic-icon-box" style="width:54px;height:54px"><div class="ic-icon-inner">${iconHtml("swordGreen")}</div></div>
          <div class="ic-hmeta" style="height:54px">
            <div><div class="ic-name" style="font-size:14.5px">Lâmina de Aço da Vigília</div><div class="ic-rar">Incomum</div></div>
            <div class="ic-botrow"><span>Espada</span><span>Uma Mão</span></div>
          </div>
        </div>
      </div>
      <div class="ic-body" style="padding:8px 12px 10px">
        <div class="ilvl-row" style="margin-bottom:3px"><div class="ilvl-hex" style="width:24px;height:24px"></div><div class="ilvl-val" style="font-size:23px">27</div></div>
        <div class="stat-ln"><b>44 - 78</b> Dano &nbsp;·&nbsp; <b>2.40</b> Velocidade</div>
        <div class="div-dia" style="margin:5px 0"><i></i></div>
        <div class="stat-ln"><b>+7</b> Força &nbsp;·&nbsp; <b>+6</b> Vigor</div>
        <div class="div-dia" style="margin:5px 0"><i></i></div>
        <div class="perk-row" style="margin:2px 0">
          <div class="perk-ic"><div class="in">${iconHtml("grimShield")}</div><div class="ring"></div></div>
          <div class="perk-txt"><span class="pre">Equipar:</span> +6 de Poder de Ataque.</div>
        </div>
        <div class="div-dia" style="margin:5px 0"><i></i></div>
        <div style="color:#b8b8b8;font-size:11px">Se equipar o item selecionado:</div>
        <div class="delta-ln">+18 – 26 Dano &nbsp;·&nbsp; +5 Força &nbsp;·&nbsp; +4 Vigor</div>
      </div>
    </div>
  </div>`;

  return `${cmpHtml}
  <div class="abs" style="left:${leftMain}px;top:${topMain}px;z-index:20">
    <div class="icard rare" style="width:${compact ? 318 : 346}px">
      <div class="ic-head" style="height:82px">
        <div class="ic-paper"></div><div class="ic-tint"></div><div class="ic-smoke1"></div><div class="ic-smoke2"></div><div class="ic-flare"></div>
        <div class="ic-fx">${sparksHtml(16, 316, 80, "#5cb8ff", 44)}</div>
        <div class="ic-head-content">
          <div class="ic-icon-box" style="width:62px;height:62px"><div class="ic-icon-inner">${iconHtml("swordRare")}</div></div>
          <div class="ic-hmeta" style="height:62px">
            <div><div class="ic-name" style="font-size:15.5px">Lâmina Rúnica de Vale Gris</div><div class="ic-rar">Raro &nbsp;•&nbsp; Único</div></div>
            <div class="ic-botrow"><span>Espada</span><span>Uma Mão</span></div>
          </div>
        </div>
      </div>
      <div class="ic-body">
        <div class="ilvl-row"><div class="ilvl-hex"></div><div class="ilvl-val">30</div></div>
        <div class="stat-ln"><b>62 - 104</b> Dano &nbsp;·&nbsp; <b>2.50</b> Velocidade</div>
        <div class="stat-ln"><b>33.2</b> Dano por Segundo</div>
        <div class="div-dia"><i></i></div>
        <div class="stat-ln"><b>+12</b> Força &nbsp;·&nbsp; <b>+10</b> Vigor</div>
        <div class="stat-ln"><b>+6</b> Taxa de Crítico</div>
        <div class="div-dia"><i></i></div>
        <div class="perk-row">
          <div class="perk-ic"><div class="in">${iconHtml("perkShout")}</div><div class="ring"></div></div>
          <div class="perk-txt"><span class="pre">Equipar:</span> Aumenta o Poder de Ataque em 24.</div>
        </div>
        <div class="perk-row">
          <div class="perk-ic"><div class="in">${iconHtml("perkBolt")}</div><div class="ring"></div></div>
          <div class="perk-txt"><span class="pre">Chance ao acertar:</span> Dispara um raio de Azoth causando 40 de dano extra.</div>
        </div>
        <div class="div-dia"><i></i></div>
        <div class="flavor">Temperada sob as copas antigas de Vale Gris.</div>
        <div class="div-dia"><i></i></div>
        <div class="bind-ln">Vinculado ao equipar</div>
        <div class="stat-ln"><b>85 / 85</b> Durabilidade &nbsp;·&nbsp; Requer Nível 24</div>
        <div class="sell-ln"><span class="lbl">Preço de venda:</span><span class="val"><span>2<i class="coin g"></i></span><span>45<i class="coin s"></i></span><span>10<i class="coin c"></i></span></span></div>
      </div>
    </div>
  </div>`;
}

// CSS Comum (ItemCard + Slots + Glass Azaath 2026)
const COMMON_CSS = `
@font-face{font-family:Cinzel;src:url(${FONTS}/Cinzel-Regular.ttf)}
@font-face{font-family:CinzelB;src:url(${FONTS}/Cinzel-Bold.ttf)}
@font-face{font-family:PTS;src:url(${FONTS}/PTSans-Regular.ttf)}
@font-face{font-family:PTSB;src:url(${FONTS}/PTSans-Bold.ttf)}
@font-face{font-family:Segoe;src:url(${FONTS}/SegoeUI-Regular.ttf)}
@font-face{font-family:SegoeB;src:url(${FONTS}/SegoeUI-Semibold.ttf)}

:root{--gold:#c9a463;--gold2:#8a6d3a;--cy:#5fe3e6;--txt:#e6e0d2;--mut:#8c9ba8}
*{box-sizing:border-box}
html,body{margin:0;padding:0;background:#020508;overflow:hidden;width:1920px;height:1080px}
.stage{position:relative;width:1920px;height:1080px;overflow:hidden;font-family:PTS,sans-serif;color:var(--txt);background:#04080d}
.abs{position:absolute}
.cz{font-family:Cinzel,serif}
.czb{font-family:CinzelB,serif}

/* Painel vidro obsidiana Azaath 2026 */
.az-panel{background:linear-gradient(180deg,rgba(10,17,26,0.90) 0%,rgba(6,10,16,0.95) 100%);
  border:1px solid rgba(138,109,58,0.56);
  box-shadow:0 0 0 1px #020508,inset 0 1px 0 rgba(95,227,230,0.14),inset 0 0 34px rgba(0,0,0,0.84),0 20px 56px rgba(0,0,0,0.88)}
.az-panel:before{content:"";position:absolute;inset:4px;border:1px solid rgba(201,164,99,0.14);pointer-events:none}
.c-dia{position:absolute;width:8px;height:8px;transform:rotate(45deg);background:#122530;border:1px solid var(--gold);box-shadow:0 0 6px rgba(95,227,230,0.45);z-index:6}
.c-dia.tl{left:-4px;top:-4px}.c-dia.tr{right:-4px;top:-4px}.c-dia.bl{left:-4px;bottom:-4px}.c-dia.br{right:-4px;bottom:-4px}

/* Slots */
.islot{position:relative;width:48px;height:48px;background:radial-gradient(circle at 50% 35%,#1a2732,#091016 80%);
  border:1px solid #35444e;box-shadow:inset 0 0 0 1px #000,inset 0 0 10px #000}
.islot:before,.islot:after{content:"";position:absolute;width:6px;height:6px;border:1px solid rgba(201,164,99,0.55);pointer-events:none;z-index:3}
.islot:before{left:-1px;top:-1px;border-right:0;border-bottom:0}
.islot:after{right:-1px;bottom:-1px;border-left:0;border-top:0}
.islot .ic-wrap{position:absolute;inset:3px;overflow:hidden;background:#070c11}
.ic-img{width:100%;height:100%;background-repeat:no-repeat}
.islot.q2{border-color:#2e9a46;box-shadow:inset 0 0 9px rgba(63,207,90,0.35),0 0 6px rgba(63,207,90,0.22)}
.islot.q3{border-color:#2f78de;box-shadow:inset 0 0 9px rgba(61,148,255,0.42),0 0 8px rgba(61,148,255,0.30)}
.islot.q4{border-color:#9e46eb;box-shadow:inset 0 0 11px rgba(194,77,255,0.48),0 0 10px rgba(194,77,255,0.36)}
.islot.hov{border-color:#d8ffff;box-shadow:0 0 0 2px #5fe3e6,0 0 18px rgba(95,227,230,0.88),inset 0 0 12px rgba(61,148,255,0.65);z-index:5}
.islot.empty .sil{position:absolute;inset:9px;border:1.5px solid rgba(155,180,196,0.18);border-radius:4px}
.islot .ilvl{position:absolute;left:3.5px;top:2px;font-family:CinzelB,serif;font-size:10px;color:#f5efe0;text-shadow:0 1px 3px #000,0 0 4px #000;z-index:4}
.islot .cnt{position:absolute;right:3.5px;bottom:1.5px;font-family:CinzelB,serif;font-size:11.5px;color:#fff;text-shadow:0 1px 2px #000,0 0 4px #000;z-index:4}
.islot .dur{position:absolute;left:4px;right:4px;bottom:3px;height:2.5px;background:#0a0f14;z-index:4}
.islot .dur i{display:block;height:100%;background:#4be894}
.islot .dur.mid i{background:#f0a830}
.islot .qbadge{position:absolute;right:-4px;top:-4px;width:16px;height:16px;background:url('${ASSETS}/inv_badge.png') center/contain no-repeat;z-index:5}

.islot.round{border-radius:50%;border:0;background:none;box-shadow:none}
.islot.round:before,.islot.round:after{display:none}
.islot.round .ic-wrap{inset:4px;border-radius:50%}
.islot.round .rframe{position:absolute;inset:-3px;background:url('${ASSETS}/sh_roundframe.png') center/contain no-repeat;pointer-events:none;z-index:3}
.islot.round .cnt{right:2px;bottom:0px;font-size:11px;background:rgba(5,10,16,0.8);padding:0 3px;border-radius:3px}
.islot.free{background:rgba(8,14,20,0.62);border:1px dashed #334550;display:flex;align-items:center;justify-content:center}
.islot.free span{font-family:CinzelB,serif;font-size:15px;color:#788894}

/* Botões Azaath */
.sbtn{position:relative;height:30px;padding:0 14px;background:linear-gradient(180deg,rgba(22,34,48,0.92),rgba(10,16,24,0.96));
  border:1px solid rgba(138,109,58,0.65);font-family:Cinzel,serif;font-size:10.5px;letter-spacing:1.4px;color:#efe6cf;display:inline-flex;align-items:center;justify-content:center;gap:6px}
.sbtn.on{border-color:#5fe3e6;box-shadow:0 0 10px rgba(95,227,230,0.28)}
.sbtn:after{content:"";position:absolute;left:10px;right:10px;bottom:-1px;height:2px;background:linear-gradient(90deg,transparent,#5fe3e6,transparent);box-shadow:0 0 8px #5fe3e6}
.sbtn.gold:after{background:linear-gradient(90deg,transparent,#e6b450,transparent);box-shadow:0 0 8px #e6b450}

.coin{display:inline-block;width:12px;height:12px;border-radius:50%;margin-left:3.5px;vertical-align:-1px;box-shadow:0 1px 2px #000}
.coin.g{background:radial-gradient(circle at 35% 30%,#fff6bd,#e5b53e 50%,#855810)}
.coin.s{background:radial-gradient(circle at 35% 30%,#ffffff,#c2cbd1 50%,#5b646b)}
.coin.c{background:radial-gradient(circle at 35% 30%,#ffd8b0,#c86f32 50%,#662f0f)}

/* Novo ItemCard */
.icard{position:relative;background:#131314;border:1px solid #050506;box-shadow:inset 0 0 0 1px #404247,0 22px 54px rgba(0,0,0,0.92)}
.eq-tab{position:relative;display:inline-flex;align-items:center;justify-content:center;height:21px;padding:0 12px;background:#131314;
  border:1px solid #050506;border-bottom:0;box-shadow:inset 1px 1px 0 #404247,inset -1px 0 0 #404247;margin-bottom:-1px;z-index:2}
.eq-tab span{font-family:SegoeB,sans-serif;font-size:11.5px;color:#ffd140;border-bottom:1px solid rgba(255,209,64,0.72);padding-bottom:1px}
.ic-head{position:relative;overflow:hidden;border-bottom:1px solid rgba(255,255,255,0.45)}
.ic-paper{position:absolute;inset:0;background:url('${ASSETS}/ic_grunge.png') center/100% 100% no-repeat;filter:brightness(1.05)}
.ic-tint{position:absolute;inset:0;mix-blend-mode:multiply}
.ic-smoke1{position:absolute;inset:-20px 0 0 0;background:url('${ASSETS}/ic_smoke1.png') 0 20%/115% auto repeat;mix-blend-mode:screen;opacity:0.52}
.ic-smoke2{position:absolute;inset:-20px 0 0 0;background:url('${ASSETS}/ic_smoke2.png') 40% 50%/85% auto repeat;mix-blend-mode:screen;opacity:0.38}
.ic-flare{position:absolute;left:0;right:0;bottom:0;height:68px;background:url('${ASSETS}/ic_flare.png') center bottom/100% 100% no-repeat;mix-blend-mode:screen;opacity:0.68}
.ic-fx{position:absolute;inset:0;pointer-events:none}
.ic-head-content{position:relative;z-index:3;height:100%;display:flex;align-items:center;padding:0 11px;gap:10px}
.ic-icon-box{position:relative;flex:none;padding:3px;box-shadow:0 4px 12px rgba(0,0,0,0.7)}
.ic-icon-inner{width:100%;height:100%;overflow:hidden;background:#08080a}
.ic-hmeta{flex:1;min-width:0;display:flex;flex-direction:column;justify-content:space-between;padding:1px 0}
.ic-name{font-family:SegoeB,sans-serif;line-height:1.15;text-shadow:1px 1px 2px #000}
.ic-rar{font-family:SegoeB,sans-serif;font-size:11.5px;text-shadow:1px 1px 2px #000;margin-top:2px}
.ic-botrow{display:flex;justify-content:space-between;font-family:SegoeB,sans-serif;font-size:11.5px;color:#fff;text-shadow:1px 1px 2px #000}

.icard.rare .ic-head{border-bottom-color:rgba(76,184,255,0.65)}
.icard.rare .ic-tint{background:linear-gradient(180deg,#0f4875 0%,#29a8f5 100%)}
.icard.rare .ic-smoke1,.icard.rare .ic-smoke2{filter:sepia(1) hue-rotate(175deg) saturate(4.5)}
.icard.rare .ic-flare{filter:sepia(1) hue-rotate(175deg) saturate(4.5)}
.icard.rare .ic-icon-box{background:linear-gradient(180deg,#125c94,#08080a);border:1px solid #59bcff}
.icard.rare .ic-name,.icard.rare .ic-rar{color:#66c2ff}

.icard.uncommon .ic-head{border-bottom-color:rgba(97,242,76,0.55)}
.icard.uncommon .ic-tint{background:linear-gradient(180deg,#165919 0%,#36bf36 100%)}
.icard.uncommon .ic-smoke1,.icard.uncommon .ic-smoke2{filter:sepia(1) hue-rotate(75deg) saturate(4)}
.icard.uncommon .ic-flare{filter:sepia(1) hue-rotate(75deg) saturate(4)}
.icard.uncommon .ic-icon-box{background:linear-gradient(180deg,#1d6e20,#08080a);border:1px solid #5fe84d}
.icard.uncommon .ic-name,.icard.uncommon .ic-rar{color:#61f24c}

.ic-body{padding:9px 14px 11px;font-family:Segoe,sans-serif;font-size:12.5px;color:#dcdcdc}
.ilvl-row{display:flex;align-items:center;gap:8px;margin-bottom:4px}
.ilvl-hex{width:28px;height:28px;background:url('${ASSETS}/ic_ilvl.png') center/contain no-repeat}
.ilvl-val{font-family:SegoeB,sans-serif;font-size:30px;line-height:1;color:#fff;text-shadow:1px 1px 2px #000}
.stat-ln{line-height:1.36;color:#dcdcdc}
.stat-ln b{font-family:SegoeB,sans-serif;color:#fff;font-weight:400}
.div-dia{position:relative;height:11px;margin:5px 0;display:flex;align-items:center}
.div-dia:before,.div-dia:after{content:"";flex:1;height:1px;background:rgba(82,83,86,0.9)}
.div-dia i{width:10px;height:10px;margin:0 4px;background:url('${ASSETS}/ic_diamond.png') center/contain no-repeat;opacity:0.78}
.perk-row{display:flex;align-items:flex-start;gap:8px;margin:4px 0}
.perk-ic{position:relative;width:25px;height:25px;flex:none;margin-top:1px}
.perk-ic .in{position:absolute;inset:2px;border-radius:50%;overflow:hidden}
.perk-ic .ring{position:absolute;inset:-1px;background:url('${ASSETS}/ic_perkring.png') center/contain no-repeat;opacity:0.92}
.perk-txt{font-family:SegoeB,sans-serif;font-size:12px;line-height:1.3;color:#6ba8ff}
.perk-txt .pre{color:#9ecbff}
.flavor{font-size:12px;line-height:1.32;color:#c8c8c8;font-style:italic}
.bind-ln{font-family:SegoeB,sans-serif;color:#3dcc6b;margin-bottom:2px}
.sell-ln{display:flex;align-items:center;gap:6px;margin-top:4px}
.sell-ln .val{font-family:SegoeB,sans-serif;color:#fff;display:flex;align-items:center;gap:5px}
.delta-ln{font-size:11.5px;line-height:1.3;color:#45e074}
`;

// ============================================================================
// CONCEITO 1: Mesma Disposição Atual (Polida com o Visual Azaath 2026)
// ============================================================================
function buildConcept1() {
  const CSS1 = COMMON_CSS + `
  /* Fundo de Vale Gris sem nenhum fantasma da UI antiga: floresta/torre nítida à esquerda + névoa noturna atrás dos painéis */
  .world-bg{position:absolute;inset:0;background:
    radial-gradient(60% 70% at 46% 52%, rgba(16,32,42,0.45), rgba(4,9,14,0.94) 75%),
    linear-gradient(180deg,#050b12,#03070c)}
  .forest-left{position:absolute;left:0;top:0;width:362px;height:1080px;
    background:url('${ASSETS}/ss_current.jpg') left top/1920px 1080px no-repeat;
    -webkit-mask-image:linear-gradient(90deg, #000 50%, rgba(0,0,0,0.45) 78%, transparent 99%);
    opacity:0.92}
  .hero-center{position:absolute;left:700px;top:210px;width:380px;height:680px;
    background:url('${TOOLS}/drops-concept/warrior_pedestal.jpg') center top/118% auto no-repeat;
    -webkit-mask-image:radial-gradient(45% 49% at 50% 47%, #000 46%, rgba(0,0,0,0.45) 70%, transparent 93%),
                       linear-gradient(180deg, transparent 0%, #000 10%, #000 82%, transparent 98%);
    -webkit-mask-composite:source-in;opacity:0.95}

  /* Painel de Atributos (Esquerda do boneco) */
  .attr-panel{position:absolute;left:368px;top:96px;width:222px;padding:14px 15px}
  .attr-top{display:flex;align-items:center;gap:10px;margin-bottom:8px}
  .attr-gs{font-family:CinzelB,serif;font-size:32px;line-height:1;color:#f5efe0;text-shadow:0 0 12px rgba(95,227,230,0.5)}
  .attr-sec{display:flex;align-items:center;gap:6px;margin:9px 0 4px;font-family:Cinzel,serif;font-size:10px;letter-spacing:2px;color:#c9bfa8}
  .attr-sec i{flex:1;height:1px;background:linear-gradient(90deg,rgba(201,164,99,0.55),transparent)}
  .arow{display:flex;align-items:baseline;font-size:12px;line-height:19px}
  .arow .k{flex:1;color:#d6d0c2}.arow .b{font-size:10px;color:#728492;margin-right:6px}.arow .v{color:#f5efe0;font-weight:700}
  .abar{height:2px;background:#0a131a;margin-bottom:2px}.abar i{display:block;height:100%;background:linear-gradient(90deg,#1a8896,#5fe3e6)}

  /* Barra vertical de durabilidade */
  .vdur-wrap{position:absolute;left:674px;top:96px;display:flex;flex-direction:column;align-items:center}
  .vdur-bar{width:6px;height:445px;background:rgba(5,10,16,0.9);border:1px solid #2b3c46;position:relative;margin-top:6px}
  .vdur-bar i{position:absolute;left:0;right:0;bottom:0;height:55%;background:linear-gradient(180deg,#5fe3e6,#2fb872);box-shadow:0 0 8px rgba(95,227,230,0.55)}

  /* Barras vitais embaixo do personagem */
  .vitals-dock{position:absolute;left:734px;top:912px;width:320px;display:flex;flex-direction:column;gap:5px;align-items:center}
  .vbar{position:relative;width:100%;height:14px;background:rgba(6,11,16,0.92);border:1px solid rgba(138,109,58,0.5);box-shadow:inset 0 0 6px #000}
  .vbar i{position:absolute;left:1px;top:1px;bottom:1px}
  .vbar span{position:relative;z-index:2;display:block;text-align:center;font-size:10.5px;line-height:12px;color:#fff;text-shadow:0 1px 2px #000}

  /* Painel do Inventário (Direita — 2 colunas x 4 slots) */
  .inv-panel{position:absolute;left:1296px;top:86px;width:584px;height:868px}
  .inv-hdr{padding:16px 20px 0}
  .inv-top{display:flex;align-items:center;justify-content:space-between}
  .inv-top h1{margin:0;font-family:Cinzel,serif;font-size:21px;font-weight:400;letter-spacing:3.5px;color:#f3ebd6}
  .view-tabs{display:flex;gap:18px;align-items:center}
  .vtab{position:relative;font-family:Cinzel,serif;font-size:11.5px;letter-spacing:2px;color:#7c8c98;padding-bottom:4px}
  .vtab.on{color:#ebfbff;text-shadow:0 0 10px rgba(95,227,230,0.8)}
  .vtab.on:after{content:"";position:absolute;left:-20px;right:-20px;bottom:-8px;height:13px;background:url('${ASSETS}/sh_navflare.png') center/100% 100% no-repeat;mix-blend-mode:screen}

  .inv-ctrl{display:flex;align-items:center;gap:8px;margin-top:10px;padding-bottom:10px;border-bottom:1px solid rgba(201,164,99,0.24)}
  .search-box{flex:1;height:26px;background:rgba(4,9,14,0.92);border:1px solid #2b3c46;display:flex;align-items:center;padding:0 8px;gap:6px;color:#788894;font-size:12px}
  .qmark{margin-left:auto;width:14px;height:14px;border-radius:50%;background:radial-gradient(circle,#f3d184,#9c7026);color:#140d02;font-weight:700;font-size:10px;display:flex;align-items:center;justify-content:center}
  .ico-btn{width:24px;height:24px;background:rgba(10,18,26,0.9);border:1px solid #30414c;display:flex;align-items:center;justify-content:center}
  .ico-btn img{width:14px;height:14px;opacity:0.82}
  .ico-btn.on{border-color:#5fe3e6;box-shadow:0 0 8px rgba(95,227,230,0.4)}

  .inv-body{padding:12px 20px 0;display:grid;grid-template-columns:1fr 1fr;gap:18px}
  .sec-hdr{display:flex;align-items:center;gap:6px;margin:0 0 6px}
  .sec-hdr .t{font-family:Cinzel,serif;font-size:11.5px;letter-spacing:2px;color:#dfd4b8}
  .sec-hdr .ln{flex:1;height:1px;background:linear-gradient(90deg,rgba(201,164,99,0.5),transparent)}
  .sec-hdr .n{font-family:CinzelB,serif;font-size:12px;color:#e6dec8}
  .sec-hdr .ar{width:13px;height:13px;border:1px solid #594726;background:#0a131a;position:relative}
  .sec-hdr .ar:after{content:"";position:absolute;left:2px;top:4px;border-top:4.5px solid #c9a463;border-left:3.5px solid transparent;border-right:3.5px solid transparent}
  .grid4{display:grid;grid-template-columns:repeat(4,54px);gap:8px;margin-bottom:14px}
  .grid4 .islot{width:54px;height:54px}

  .inv-foot{position:absolute;left:20px;right:20px;bottom:12px;height:42px;border-top:1px solid rgba(201,164,99,0.24);display:flex;align-items:center;justify-content:space-between;padding-top:6px}
  .money{display:flex;align-items:center;gap:12px;font-family:CinzelB,serif;font-size:16px;color:#f4ecda}

  /* Mini Radial (G) posicionado limpo sem esmagar os anéis */
  .rad-wrap{position:absolute;left:1148px;top:636px;width:134px;height:134px;border-radius:50%;
    background:radial-gradient(circle,rgba(12,26,36,0.94),rgba(5,10,16,0.97) 72%);
    border:1px solid rgba(201,164,99,0.65);box-shadow:0 0 22px rgba(95,227,230,0.22),inset 0 0 18px #000}
  .rad-ring{position:absolute;inset:12px;border-radius:50%;border:1px dashed rgba(95,227,230,0.3)}
  .rad-key{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);font-family:CinzelB,serif;font-size:14px;color:var(--gold)}
  .rad-slot{position:absolute;width:28px;height:28px;border-radius:50%;transform:translate(-50%,-50%);background:#0a131b;border:1px solid #7d6232;box-shadow:0 0 6px #000}
  .rad-slot .in{position:absolute;inset:2px;border-radius:50%;overflow:hidden}
  .rad-slot .cnt{position:absolute;right:-3px;bottom:-3px;font-family:CinzelB,serif;font-size:9px;color:#fff;text-shadow:0 1px 2px #000}
  .rad-slot.empty{border-color:#2c3a44;color:#5d6c78;display:flex;align-items:center;justify-content:center;font-size:11px}
  `;

  // Slots verticais esquerda do boneco (9 armaduras)
  const armLeft = [
    ["helmGold", "q2", 32], ["pauldrons", "q2", 32], ["cloak", "q4", 32],
    ["chestplate", "q2", 29], ["bracers", "q2", 25], ["gauntlets", "q2", 30],
    ["belt", "q2", 32], ["greaves", "q2", 24], ["boots", "q2", 26],
  ];
  let armLeftHtml = armLeft.map(([ic, q, ilvl], i) =>
    `<div class="abs" style="left:610px;top:${92 + i * 56}px">${slotHtml(ic, { q, ilvl })}</div>`
  ).join("");

  // Bolsas 2x2 abaixo da coluna esquerda
  const bags4 = [["bagRed", 12], ["bagRed", 12], ["bagRed", 12], ["bagLeather", 10]];
  let bags4Html = bags4.map(([ic, cap], i) =>
    `<div class="abs" style="left:${604 + (i % 2) * 54}px;top:${640 + Math.floor(i / 2) * 54}px">${slotHtml(ic, { cnt: cap })}</div>`
  ).join("");

  // Coluna direita do boneco (3 armas, 2 berloques, grade 2x3 acessórios)
  const wpnRight = [["swordRare", "q3", 31], ["swordGreen", "q2", 27], ["gun", "q2", 21]];
  let wpnRightHtml = wpnRight.map(([ic, q, ilvl], i) =>
    `<div class="abs" style="left:1126px;top:${92 + i * 56}px">${slotHtml(ic, { q, ilvl })}</div>`
  ).join("");
  const trkRightHtml =
    `<div class="abs" style="left:1126px;top:308px">${slotHtml("orbStone", { q: "q2", ilvl: 30 })}</div>` +
    `<div class="abs" style="left:1126px;top:364px">${slotHtml(null, { empty: true })}</div>`;
  const acc2x3 = [
    ["amulet", "q2", 24], ["ring", "q3", 33],
    ["ringSilver", "q2", 26], [null, "", null],
    [null, "", null], [null, "", null],
  ];
  let accHtml = acc2x3.map(([ic, q, ilvl], i) =>
    `<div class="abs" style="left:${1098 + (i % 2) * 54}px;top:${474 + Math.floor(i / 2) * 54}px">${slotHtml(ic, ic ? { q, ilvl } : { empty: true })}</div>`
  ).join("");

  // Radial (G)
  const radItems = [["healthPotion", "5"], ["bread", "14"], ["cheese", "4"], ["manaCup", "1"], null, null, null, null];
  let radHtml = radItems.map((it, i) => {
    const a = (i / 8) * Math.PI * 2 - Math.PI / 2, sx = 67 + Math.cos(a) * 46, sy = 67 + Math.sin(a) * 46;
    return it
      ? `<div class="rad-slot" style="left:${sx.toFixed(1)}px;top:${sy.toFixed(1)}px"><div class="in">${iconHtml(it[0])}</div><span class="cnt">${it[1]}</span></div>`
      : `<div class="rad-slot empty" style="left:${sx.toFixed(1)}px;top:${sy.toFixed(1)}px">+</div>`;
  }).join("");

  const sec = (t, n, body) => `<div><div class="sec-hdr"><span class="t">${t}</span><span class="ln"></span><span class="n">${n}</span><span class="ar"></span></div><div class="grid4">${body}</div></div>`;

  const colL = [
    sec("ARMAS", 4,
      slotHtml("swordRare", { q: "q3", ilvl: 30, dur: 100, hov: true }) +
      slotHtml("axeWhite", { cnt: 4, dur: 92 }) +
      slotHtml("gun", { cnt: 10, dur: 100 }) +
      slotHtml("maceWhite", { dur: 100 })
    ),
    sec("CONSUMÍVEIS", 26,
      slotHtml("meat", { cnt: 20 }) + slotHtml("scroll", { cnt: 1 }) + slotHtml("cheese", { cnt: 7 }) + slotHtml("bread", { cnt: 5 }) +
      slotHtml("bread", { cnt: 13 }) + slotHtml("bread", { cnt: 14 }) + slotHtml("cheese", { cnt: 4 }) + slotHtml("meat", { cnt: 2 }) +
      slotHtml("healthPotion", { cnt: 5 }) + slotHtml("healthPotion", { cnt: 5 }) + slotHtml("healthPotion", { cnt: 5 }) + slotHtml("healthPotion", { cnt: 5 }) +
      slotHtml("healthPotion", { cnt: 5 }) + slotHtml("healthPotion", { cnt: 5 }) + slotHtml("healthPotion", { cnt: 5 }) + slotHtml("healthPotion", { cnt: 5 }) +
      slotHtml("vialSlender", { cnt: 5 }) + slotHtml("vialSlender", { cnt: 2 }) + slotHtml("meat", { cnt: 2 }) + slotHtml("manaCup", { cnt: 1 }) +
      slotHtml("orbStone", { cnt: 6 }) + slotHtml("healthPotion", { cnt: 3 })
    ),
    sec("ESPAÇO LIVRE", 32, `<div class="islot free"><span>32</span></div>`),
  ].join("");

  const colR = [
    sec("EQUIPAMENTO", 1, slotHtml("ring", { q: "q2", ilvl: 24, dur: 100 })),
    sec("MATERIAIS", 1, slotHtml("silkCloth", { round: true, cnt: 4 })),
    sec("MISSÃO", 5,
      slotHtml("scroll", { quest: true }) + slotHtml("matAmethyst", { quest: true }) +
      slotHtml("tome", { quest: true }) + slotHtml("orbStone", { quest: true }) + slotHtml("matDust", { quest: true })
    ),
    sec("DIVERSOS", 2, slotHtml("hearthstone", { q: "q2" }) + slotHtml("torch", {})),
    sec("LIXO", 1, slotHtml("tome", {})),
  ].join("");

  const arow = (k, b, v, pct) => `<div class="arow"><span class="k">${k}</span><span class="b">${b || ""}</span><span class="v">${v}</span></div>${pct != null ? `<div class="abar"><i style="width:${pct}%"></i></div>` : ""}`;

  return `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Conceito 1 — Disposição Atual Polida</title><style>${CSS1}</style></head><body>
<div class="stage">
  <div class="world-bg"></div>
  <div class="forest-left"></div>
  <div class="hero-center"></div>

  <!-- Painel de Atributos (mesma posição à esquerda) -->
  <aside class="az-panel attr-panel">
    <i class="c-dia tl"></i><i class="c-dia tr"></i><i class="c-dia bl"></i><i class="c-dia br"></i>
    <div class="attr-top">
      <img src="${ASSETS}/ic_ilvl.png" style="width:26px;height:26px">
      <div class="attr-gs">28</div>
      <div class="cz" style="font-size:10px;letter-spacing:1.4px;color:#9eb0be;line-height:1.2">NÍVEL<br>DE ITEM</div>
    </div>
    <div class="attr-sec">ATRIBUTOS<i></i></div>
    ${arow("Força", "(60+68)", 128, 82)}
    ${arow("Agilidade", "(50+25)", 75, 50)}
    ${arow("Vigor", "(57+45)", 102, 68)}
    ${arow("Intelecto", "(34+4)", 38, 28)}
    ${arow("Espírito", "(30+9)", 39, 30)}
    <div class="attr-sec">ATAQUE<i></i></div>
    ${arow("Poder de ataque", "", 375)}
    ${arow("Crítico", "", "11.95%")}
    ${arow("Acerto", "", "0.00%")}
    ${arow("Aceleração", "", "0.00%")}
    <div class="attr-sec">MAGIA<i></i></div>
    ${arow("Poder mágico", "", 0)}
    ${arow("Crítico mágico", "", "0.00%")}
    ${arow("Aceleração mágica", "", "0.00%")}
    ${arow("Regeneração", "", "0.0 / s")}
    <div class="attr-sec">DEFESA<i></i></div>
    ${arow("Armadura", "", "1.357")}
    ${arow("Esquiva", "", "7.79%")}
    ${arow("Aparar", "", "4.72%")}
    ${arow("Bloqueio", "", "4.72%")}
  </aside>

  <!-- Coluna esquerda de armaduras + Durabilidade + Bolsas 2x2 -->
  ${armLeftHtml}
  <div class="vdur-wrap">
    <div class="czb" style="font-size:13px;color:#62ee9a;text-shadow:0 1px 3px #000">55%</div>
    <div class="cz" style="font-size:8px;letter-spacing:1.2px;color:#9eb0be">DURABILIDADE</div>
    <div class="vdur-bar"><i></i></div>
  </div>
  ${bags4Html}

  <!-- Coluna direita de armas, berloques e acessórios 2x3 -->
  ${wpnRightHtml}
  ${trkRightHtml}
  ${accHtml}

  <!-- Mini Radial (G) -->
  <div class="rad-wrap"><div class="rad-ring"></div><span class="rad-key">G</span>${radHtml}</div>

  <!-- Barras vitais e botões embaixo do personagem -->
  <div class="vitals-dock">
    <div class="vbar"><i style="width:12%;background:linear-gradient(90deg,#9c3518,#e37524)"></i><span>0</span></div>
    <div class="vbar"><i style="width:9%;background:linear-gradient(90deg,#3d2680,#63b8ff)"></i><span>2.500 / 28.400 · 9%</span></div>
    <div class="vbar"><i style="width:100%;background:linear-gradient(90deg,#167048,#38d984)"></i><span>1.241</span></div>
    <div style="display:flex;gap:10px;width:100%;margin-top:4px">
      <div class="sbtn gold" style="flex:1">REPARAR TUDO</div>
      <div class="sbtn" style="flex:1">FICHA COMPLETA</div>
    </div>
  </div>

  <!-- Novo ItemCard (à esquerda da ficha para não cobrir o personagem nem os slots!) -->
  ${itemCardPairHtml(32, 102, 0, 0, true, false)}

  <!-- Painel do Inventário (mesma posição à direita, 2x4 slots) -->
  <main class="az-panel inv-panel">
    <i class="c-dia tl"></i><i class="c-dia tr"></i><i class="c-dia bl"></i><i class="c-dia br"></i>
    <div class="inv-hdr">
      <div class="inv-top">
        <h1>INVENTÁRIO</h1>
        <div class="view-tabs"><span class="vtab on">CATEGORIAS</span><span class="vtab">BOLSAS</span></div>
      </div>
      <div class="inv-ctrl">
        <div class="search-box"><span>Buscar...</span><span class="qmark">?</span></div>
        <span style="font-size:11.5px;color:#8c9ba8;margin-left:4px">Ordenar</span>
        <div class="ico-btn on"><img src="${ASSETS}/inv_clock.png"></div>
        <div class="ico-btn"><img src="${ASSETS}/inv_star.png"></div>
        <div class="ico-btn"><img src="${ASSETS}/inv_tier.png"></div>
      </div>
    </div>
    <div class="inv-body"><div>${colL}</div><div>${colR}</div></div>
    <div class="inv-foot">
      <div class="money"><span>12<i class="coin g"></i></span><span>75<i class="coin s"></i></span><span>20<i class="coin c"></i></span></div>
      <div class="sbtn on">RADIAL (G)</div>
    </div>
  </main>
</div></body></html>`;
}

// ============================================================================
// CONCEITO 2: Disposição Inovadora "Relicário Modular & Gaveta Retrátil"
// ============================================================================
function buildConcept2() {
  const CSS2 = COMMON_CSS + `
  /* Fundo limpo: câmara/floresta à esquerda sem fantasmas de UI antiga */
  .world-bg{position:absolute;inset:0;background:url('${ASSETS}/vault_bg.jpg') center/cover no-repeat;filter:brightness(0.84) saturate(0.95)}
  .forest-left{position:absolute;left:0;top:0;width:540px;height:1080px;
    background:url('${ASSETS}/ss_current.jpg') left top/1920px 1080px no-repeat;
    -webkit-mask-image:linear-gradient(90deg, #000 28%, rgba(0,0,0,0.4) 55%, transparent 90%);
    opacity:0.55}
  .world-mask{position:absolute;inset:0;background:
    linear-gradient(90deg, transparent 0%, transparent 44%, rgba(4,9,15,0.74) 52%, rgba(4,8,13,0.92) 100%);
    pointer-events:none}
  .world-hero{position:absolute;left:-14px;top:245px;width:330px;height:620px;
    background:url('${TOOLS}/drops-concept/warrior_pedestal.jpg') center top/124% auto no-repeat;
    -webkit-mask-image:radial-gradient(43% 47% at 50% 48%, #000 46%, rgba(0,0,0,0.45) 70%, transparent 93%),
                       linear-gradient(180deg, transparent 0%, #000 10%, #000 80%, transparent 98%);
    -webkit-mask-composite:source-in}
  .hud-mini{position:absolute;left:220px;bottom:-16px;width:540px;height:270px;
    background:url('${TOOLS}/azaath-hud-concept/concept.png') center/contain no-repeat;
    -webkit-mask-image:radial-gradient(48% 36% at 50% 54%, #000 58%, rgba(0,0,0,0.35) 78%, transparent 96%);
    opacity:0.92;pointer-events:none}

  /* GAVETA RETRÁTIL DE ARSENAL & STATUS (acoplada à esquerda da mochila) */
  .arsenal-drawer{position:absolute;left:954px;top:88px;width:316px;height:878px;padding:16px 16px 14px}
  .hinge-tab{position:absolute;left:-26px;top:50%;transform:translateY(-50%);width:26px;height:112px;
    background:linear-gradient(180deg,#12202c,#081018);border:1px solid rgba(138,109,58,0.65);border-right:0;
    display:flex;flex-direction:column;align-items:center;justify-content:center;gap:6px;box-shadow:-6px 0 18px rgba(0,0,0,0.7)}
  .hinge-tab span{writing-mode:vertical-rl;transform:rotate(180deg);font-family:Cinzel,serif;font-size:9.5px;letter-spacing:2px;color:#d6cbb2}

  .ar-top{display:flex;align-items:center;justify-content:space-between;padding-bottom:10px;border-bottom:1px solid rgba(201,164,99,0.22)}
  .ar-orb{position:relative;width:54px;height:54px;display:flex;align-items:center;justify-content:center}
  .ar-orb-bg{position:absolute;inset:-4px;background:url('${ASSETS}/sh_orb.png') center/contain no-repeat}
  .ar-orb b{position:relative;font-family:CinzelB,serif;font-size:20px;color:#f5efe0}

  .doll-stage{position:relative;height:444px;margin:10px 0;background:radial-gradient(circle at 50% 45%, rgba(28,68,84,0.22), rgba(5,10,16,0.4) 75%);
    border:1px solid rgba(95,227,230,0.12)}
  .doll-crest{position:absolute;left:50%;top:45%;width:150px;height:290px;transform:translate(-50%,-50%);opacity:0.25}
  .doll-col{position:absolute;top:10px;display:flex;flex-direction:column;gap:5px}
  .doll-col.L{left:10px}.doll-col.R{right:10px}
  .doll-col .islot{width:44px;height:44px}
  .doll-wpns{position:absolute;left:0;right:0;bottom:10px;display:flex;justify-content:center;gap:10px}
  .doll-wpns .islot{width:46px;height:46px}

  .stat-chips{display:grid;grid-template-columns:repeat(5,1fr);gap:5px;margin-top:8px}
  .schip{background:rgba(6,12,18,0.85);border:1px solid rgba(95,227,230,0.2);padding:5px 2px;text-align:center}
  .schip .k{font-family:Cinzel,serif;font-size:9px;letter-spacing:1px;color:#8c9ba8}
  .schip .v{font-family:CinzelB,serif;font-size:13px;color:#efe6cf;margin-top:1px}
  .tele-grid{display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:8px}
  .tchip{display:flex;justify-content:space-between;align-items:center;padding:5px 8px;background:rgba(7,13,20,0.82);border:1px solid rgba(138,109,58,0.28);font-size:11px}
  .tchip span{color:#9eb0be}.tchip b{font-family:CinzelB,serif;color:#f3ebd6;font-size:12px}

  /* JANELA PRINCIPAL DO INVENTÁRIO (Direita) */
  .inv-main{position:absolute;left:1280px;top:88px;width:606px;height:878px}
  .inv-hdr{padding:16px 20px 0}
  .inv-top{display:flex;align-items:center;justify-content:space-between}
  .inv-top h1{margin:0;font-family:Cinzel,serif;font-size:20px;font-weight:400;letter-spacing:3px;color:#f3ebd6}
  .cap-pill{font-family:Cinzel,serif;font-size:10.5px;color:#9de8ed;padding:2px 8px;border:1px solid rgba(95,227,230,0.34);background:rgba(16,42,54,0.45)}
  .vtabs{display:flex;gap:16px;align-items:center}
  .vtab{position:relative;font-family:Cinzel,serif;font-size:11px;letter-spacing:2px;color:#788894;padding-bottom:4px}
  .vtab.on{color:#ebfbff;text-shadow:0 0 10px rgba(95,227,230,0.8)}
  .vtab.on:after{content:"";position:absolute;left:-18px;right:-18px;bottom:-8px;height:12px;background:url('${ASSETS}/sh_navflare.png') center/100% 100% no-repeat;mix-blend-mode:screen}
  .close-btn{width:24px;height:24px;border-radius:50%;background:#0a131c;border:1px solid rgba(138,109,58,0.75);display:flex;align-items:center;justify-content:center}

  /* Dock Integrado de Bolsas */
  .bags-top{display:flex;align-items:center;justify-content:space-between;margin-top:10px;padding:6px 10px;background:rgba(5,10,16,0.76);border:1px solid rgba(138,109,58,0.28)}
  .bag-cell{position:relative;width:30px;height:30px;background:#080f16;border:1px solid #4a5a64;overflow:hidden}
  .bag-cell.on{border-color:#c9a463}
  .bag-cell .cap{position:absolute;right:1px;bottom:0;font-family:CinzelB,serif;font-size:8.5px;background:rgba(4,8,14,0.8);padding:0 2px;color:#f5edd8}
  .gauge{height:5px;background:#050a10;border:1px solid #23333d;position:relative;margin-top:4px}
  .gauge i{position:absolute;left:0;top:0;bottom:0;background:linear-gradient(90deg,#1a8896,#5fe3e6);box-shadow:0 0 8px #5fe3e6}

  .inv-ctrl{display:flex;align-items:center;gap:7px;margin-top:10px}
  .search-box{flex:1;height:27px;background:rgba(4,9,14,0.92);border:1px solid #2b3c46;display:flex;align-items:center;padding:0 8px;color:#788894;font-size:12px}
  .qmark{margin-left:auto;width:14px;height:14px;border-radius:50%;background:radial-gradient(circle,#f3d184,#9c7026);color:#140d02;font-weight:700;font-size:10px;display:flex;align-items:center;justify-content:center}
  .ico-btn{width:25px;height:25px;background:rgba(10,18,26,0.9);border:1px solid #30414c;display:flex;align-items:center;justify-content:center}
  .ico-btn img{width:14px;height:14px;opacity:0.82}
  .ico-btn.on{border-color:#5fe3e6;box-shadow:0 0 8px rgba(95,227,230,0.4)}

  .fpills{display:flex;gap:5px;margin-top:9px;padding-bottom:9px;border-bottom:1px solid rgba(201,164,99,0.2)}
  .fpill{padding:3px 9px;border-radius:10px;font-size:10.5px;color:#8e9da8;background:rgba(10,18,26,0.72);border:1px solid rgba(90,110,124,0.28)}
  .fpill.on{color:#f0fcff;background:linear-gradient(180deg,rgba(24,84,96,0.75),rgba(11,44,54,0.85));border-color:#5fe3e6;box-shadow:0 0 10px rgba(95,227,230,0.3)}

  .inv-body{padding:11px 20px 0;display:grid;grid-template-columns:1fr 1fr;gap:16px}
  .sec-hdr{display:flex;align-items:center;gap:6px;margin:0 0 6px}
  .sec-hdr .t{font-family:Cinzel,serif;font-size:11px;letter-spacing:1.8px;color:#dfd4b8}
  .sec-hdr .ln{flex:1;height:1px;background:linear-gradient(90deg,rgba(201,164,99,0.5),transparent)}
  .sec-hdr .n{font-family:CinzelB,serif;font-size:11.5px;color:#e6dec8}
  .sec-hdr .ar{width:12px;height:12px;border:1px solid #594726;background:#0a131a;position:relative}
  .sec-hdr .ar:after{content:"";position:absolute;left:2px;top:3.5px;border-top:4px solid #c9a463;border-left:3.5px solid transparent;border-right:3.5px solid transparent}
  .grid5{display:grid;grid-template-columns:repeat(5,48px);gap:6px;margin-bottom:12px}

  /* Cinturão Rápido Radial (G) Embutido no Rodapé (Zero colisão!) */
  .radial-belt{position:absolute;left:20px;right:20px;bottom:60px;height:52px;
    background:linear-gradient(90deg,rgba(7,14,22,0.85),rgba(14,34,44,0.92),rgba(7,14,22,0.85));
    border:1px solid rgba(95,227,230,0.28);display:flex;align-items:center;justify-content:space-between;padding:0 12px}
  .rb-slots{display:flex;align-items:center;gap:8px}
  .rb-cell{position:relative;width:36px;height:36px;border-radius:50%;background:#09121a;border:1px solid #7d6232;box-shadow:inset 0 0 8px #000}
  .rb-cell .in{position:absolute;inset:3px;border-radius:50%;overflow:hidden}
  .rb-cell .cnt{position:absolute;right:-2px;bottom:-2px;font-family:CinzelB,serif;font-size:9.5px;color:#fff;text-shadow:0 1px 2px #000}
  .rb-cell.empty{border-color:#2a3a44;color:#5d6c78;display:flex;align-items:center;justify-content:center;font-size:12px}
  .rb-core{width:42px;height:42px;border-radius:50%;background:radial-gradient(circle,#163844,#071118);border:1.5px solid var(--cy);
    box-shadow:0 0 14px rgba(95,227,230,0.45);display:flex;flex-direction:column;align-items:center;justify-content:center}
  .rb-core b{font-family:CinzelB,serif;font-size:13px;color:var(--gold);line-height:1}
  .rb-core span{font-size:7px;letter-spacing:1px;color:#9de8ed}

  .inv-foot{position:absolute;left:20px;right:20px;bottom:12px;height:40px;display:flex;align-items:center;justify-content:space-between}
  .money{display:flex;align-items:center;gap:12px;font-family:CinzelB,serif;font-size:15.5px;color:#f4ecda}
  `;

  // Paperdoll compacto da gaveta
  const dLeft = [
    ["helmGold", "q2", 32], ["pauldrons", "q2", 32], ["cloak", "q4", 32],
    ["chestplate", "q2", 29], ["bracers", "q2", 25], ["gauntlets", "q2", 30], ["belt", "q2", 32],
  ];
  const dRight = [
    ["amulet", "q2", 24], ["greaves", "q2", 24], ["boots", "q2", 26],
    ["ring", "q3", 33], ["ringSilver", "q2", 26], ["orbStone", "q2", 30], [null, "", null],
  ];

  const sec = (t, n, body) => `<div><div class="sec-hdr"><span class="t">${t}</span><span class="ln"></span><span class="n">${n}</span><span class="ar"></span></div><div class="grid5">${body}</div></div>`;
  const colL = [
    sec("ARMAS", 4,
      slotHtml("swordRare", { q: "q3", ilvl: 30, dur: 100, hov: true }) +
      slotHtml("axeWhite", { cnt: 4, dur: 92 }) +
      slotHtml("gun", { cnt: 10, dur: 100 }) +
      slotHtml("maceWhite", { dur: 100 })
    ),
    sec("CONSUMÍVEIS", 22,
      slotHtml("meat", { cnt: 20 }) + slotHtml("bread", { cnt: 14 }) + slotHtml("cheese", { cnt: 7 }) +
      slotHtml("healthPotion", { cnt: 20 }) + slotHtml("healthPotion", { cnt: 18 }) +
      slotHtml("vialSlender", { cnt: 7 }) + slotHtml("manaCup", { cnt: 1 }) + slotHtml("scroll", { cnt: 1 }) +
      slotHtml("orbStone", { cnt: 6 }) + slotHtml("meat", { cnt: 2 })
    ),
    sec("ESPAÇO LIVRE", 32, `<div class="islot free"><span>32</span></div>`),
  ].join("");

  const colR = [
    sec("EQUIPAMENTO", 1, slotHtml("ring", { q: "q2", ilvl: 24, dur: 100 })),
    sec("MATERIAIS", 3,
      slotHtml("silkCloth", { round: true, cnt: 4 }) +
      slotHtml("matRune", { round: true, q: "q3", cnt: 8 }) +
      slotHtml("matIngot", { round: true, cnt: 12 })
    ),
    sec("MISSÃO", 5,
      slotHtml("scroll", { quest: true }) + slotHtml("matAmethyst", { quest: true }) +
      slotHtml("tome", { quest: true }) + slotHtml("orbStone", { quest: true }) + slotHtml("matDust", { quest: true })
    ),
    sec("DIVERSOS", 2, slotHtml("hearthstone", { q: "q2" }) + slotHtml("torch", {})),
    sec("LIXO", 1, slotHtml("tome", {})),
  ].join("");

  const rbCell = (ic, cnt) => ic
    ? `<div class="rb-cell"><div class="in">${iconHtml(ic)}</div><span class="cnt">${cnt}</span></div>`
    : `<div class="rb-cell empty">+</div>`;

  return `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Conceito 2 — Relicário Modular (Sem Tela Cheia)</title><style>${CSS2}</style></head><body>
<div class="stage">
  <div class="world-bg"></div>
  <div class="forest-left"></div>
  <div class="world-mask"></div>
  <div class="world-hero"></div>
  <div class="hud-mini"></div>

  <!-- Novo ItemCard + Comparação flutuando livre na zona esquerda sem cobrir nenhum slot nem o herói -->
  ${itemCardPairHtml(606, 134, 290, 134, true, true)}

  <!-- GAVETA RETRÁTIL DE ARSENAL & TELEMETRIA -->
  <aside class="az-panel arsenal-drawer">
    <i class="c-dia tl"></i><i class="c-dia tr"></i><i class="c-dia bl"></i><i class="c-dia br"></i>
    <div class="hinge-tab"><div style="color:var(--cy);font-size:11px">◀</div><span>ARSENAL</span></div>

    <div class="ar-top">
      <div style="display:flex;align-items:center;gap:10px">
        <div class="ar-orb"><div class="ar-orb-bg"></div><b>28</b></div>
        <div>
          <div class="cz" style="font-size:11px;letter-spacing:1.8px;color:#f3ebd6">ARSENAL</div>
          <div style="font-size:10.5px;color:#62ee9a">55% Durabilidade</div>
        </div>
      </div>
      <div class="sbtn" style="height:26px;padding:0 10px;font-size:9.5px">FICHA (C)</div>
    </div>

    <div class="doll-stage">
      <svg class="doll-crest" viewBox="0 0 120 240"><circle cx="60" cy="110" r="52" fill="none" stroke="#5fe3e6" stroke-width="1.2"/><circle cx="60" cy="110" r="36" fill="none" stroke="#c9a463" stroke-width="1"/><path d="M60 30 L74 110 L60 190 L46 110 Z" fill="none" stroke="#5fe3e6" stroke-width="1.2"/></svg>
      <div class="doll-col L">${dLeft.map(([ic, q, il]) => slotHtml(ic, { q, ilvl: il })).join("")}</div>
      <div class="doll-col R">${dRight.map(([ic, q, il]) => slotHtml(ic, ic ? { q, ilvl: il } : { empty: true })).join("")}</div>
      <div class="doll-wpns">
        ${slotHtml("swordRare", { q: "q3", ilvl: 31 })}
        ${slotHtml("swordGreen", { q: "q2", ilvl: 27 })}
        ${slotHtml("gun", { q: "q2", ilvl: 21 })}
      </div>
    </div>

    <div class="cz" style="font-size:10px;letter-spacing:2px;color:#c9bfa8;margin-top:6px">ATRIBUTOS & COMBATE</div>
    <div class="stat-chips">
      <div class="schip"><div class="k">FOR</div><div class="v">128</div></div>
      <div class="schip"><div class="k">AGI</div><div class="v">75</div></div>
      <div class="schip"><div class="k">VIG</div><div class="v">102</div></div>
      <div class="schip"><div class="k">INT</div><div class="v">38</div></div>
      <div class="schip"><div class="k">ESP</div><div class="v">39</div></div>
    </div>
    <div class="tele-grid">
      <div class="tchip"><span>Poder Atq.</span><b>375</b></div>
      <div class="tchip"><span>Crítico</span><b>11.95%</b></div>
      <div class="tchip"><span>Armadura</span><b>1.357</b></div>
      <div class="tchip"><span>Esquiva</span><b>7.79%</b></div>
    </div>
    <div class="sbtn gold" style="width:100%;margin-top:12px">REPARAR TUDO</div>
  </aside>

  <!-- JANELA PRINCIPAL DO INVENTÁRIO (Direita) -->
  <main class="az-panel inv-main">
    <i class="c-dia tl"></i><i class="c-dia tr"></i><i class="c-dia bl"></i><i class="c-dia br"></i>
    <div class="inv-hdr">
      <div class="inv-top">
        <div style="display:flex;align-items:center;gap:10px">
          <h1>INVENTÁRIO</h1>
          <span class="cap-pill">34 / 66</span>
        </div>
        <div style="display:flex;align-items:center;gap:14px">
          <div class="vtabs"><span class="vtab on">CATEGORIAS</span><span class="vtab">BOLSAS</span></div>
          <div class="close-btn"><svg width="10" height="10" viewBox="0 0 16 16"><path d="M3 3 L13 13 M13 3 L3 13" stroke="#c9bfa8" stroke-width="1.8" stroke-linecap="round"/></svg></div>
        </div>
      </div>

      <!-- Bolsas equipadas + Medidor integrados no topo -->
      <div class="bags-top">
        <div style="display:flex;align-items:center;gap:5px">
          <span class="cz" style="font-size:9.5px;letter-spacing:1.4px;color:#b8ae96;margin-right:4px">BOLSAS</span>
          <div class="bag-cell on">${iconHtml("bagRed")}<span class="cap">12</span></div>
          <div class="bag-cell on">${iconHtml("bagRed")}<span class="cap">12</span></div>
          <div class="bag-cell on">${iconHtml("bagRed")}<span class="cap">12</span></div>
          <div class="bag-cell on">${iconHtml("bagLeather")}<span class="cap">10</span></div>
        </div>
        <div style="width:240px">
          <div style="display:flex;justify-content:space-between;font-size:10px;color:#9eb0bd"><span class="cz">ESPAÇO LIVRE</span><span style="color:#e6f9ff">32 / 66 LIVRES</span></div>
          <div class="gauge"><i style="width:52%"></i></div>
        </div>
      </div>

      <div class="inv-ctrl">
        <div class="search-box"><span>Buscar item...</span><span class="qmark">?</span></div>
        <span style="font-size:11px;color:#8c9ba8">Ordenar</span>
        <div class="ico-btn on"><img src="${ASSETS}/inv_clock.png"></div>
        <div class="ico-btn"><img src="${ASSETS}/inv_star.png"></div>
        <div class="ico-btn"><img src="${ASSETS}/inv_tier.png"></div>
        <div class="sbtn" style="height:25px;padding:0 10px;font-size:9.5px">ORGANIZAR</div>
      </div>

      <div class="fpills">
        <span class="fpill on">Todos</span><span class="fpill">Armas</span><span class="fpill">Equip.</span>
        <span class="fpill">Consumíveis</span><span class="fpill">Materiais</span><span class="fpill">Missão</span><span class="fpill">Lixo</span>
      </div>
    </div>

    <div class="inv-body"><div>${colL}</div><div>${colR}</div></div>

    <!-- Cinturão Radial (G) embutido no rodapé (zero colisão com equipamentos!) -->
    <div class="radial-belt">
      <div class="rb-slots">${rbCell("healthPotion", 5)}${rbCell("bread", 14)}${rbCell("cheese", 4)}${rbCell("manaCup", 1)}</div>
      <div class="rb-core"><b>G</b><span>RADIAL</span></div>
      <div class="rb-slots">${rbCell("vialSlender", 2)}${rbCell(null)}${rbCell(null)}${rbCell(null)}</div>
    </div>

    <div class="inv-foot">
      <div class="money"><span>12<i class="coin g"></i></span><span>75<i class="coin s"></i></span><span>20<i class="coin c"></i></span></div>
      <div style="display:flex;gap:8px">
        <div class="sbtn gold">VENDER LIXO</div>
        <div class="sbtn on">ABRIR RODA (G)</div>
      </div>
    </div>
  </main>
</div></body></html>`;
}

// ============================================================================
// Renderiza os dois arquivos via Edge Headless
// ============================================================================
const JOBS = [
  { html: "concept1.html", png: "Azaath_Inventario_Conceito1_AtualPolido.png", build: buildConcept1 },
  { html: "concept2.html", png: "Azaath_Inventario_Conceito2_ModularSurpresa.png", build: buildConcept2 },
];

for (const job of JOBS) {
  const htmlPath = path.join(DIR, job.html);
  const pngPath = path.join(DIR, job.png);
  fs.writeFileSync(htmlPath, job.build(), "utf8");
  const r = spawnSync(EDGE, [
    "--headless=new",
    "--disable-gpu",
    "--no-sandbox",
    "--user-data-dir=" + EDGE_PROF,
    "--hide-scrollbars",
    "--force-device-scale-factor=1.3333334",
    "--window-size=1920,1080",
    "--virtual-time-budget=1200",
    "--allow-file-access-from-files",
    "--screenshot=" + pngPath,
    "file:///" + htmlPath.replace(/\\/g, "/"),
  ], { encoding: "utf8" });
  console.log(job.png, "status:", r.status, fs.existsSync(pngPath) ? fs.statSync(pngPath).size + " bytes" : "ERRO");
  if (r.status !== 0 && r.stderr) console.error(r.stderr);
}
