// Nova Arte de Conceito da Aba de Inventário (Janela Flutuante) — AzaathUI (V3, 2026)
// Alinhada às abas do Santuário e ao novo Card de Itens (ItemCard.lua), mantendo a janela
// compacta e flutuante à direita para funcionar no mundo aberto e junto ao Mercador/Banco.
//
//   node tools/bag-concept/gen-v3.js
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
const OUT_PNG = path.join(DIR, "Azaath_Inventario_ConceptArt_V3.png");
const HTML_FILE = path.join(DIR, "v3.html");

const EDGE_PROF = path.join(ROOT, "tools/.cache/edge-concept-prof");
fs.mkdirSync(EDGE_PROF, { recursive: true });

// ============================================================================
// Ícones SVG em Base64
// ============================================================================
function svgUrl(svg) {
  return "data:image/svg+xml;base64," + Buffer.from(svg.trim(), "utf8").toString("base64");
}

const SVG_ICONS = {
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
    <defs>
      <radialGradient id="bg" cx="50%" cy="50%" r="55%"><stop offset="0%" stop-color="#1c4f78"/><stop offset="100%" stop-color="#071324"/></radialGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <polygon points="56,14 28,54 48,54 42,86 72,44 52,44" fill="#8ef7ff" stroke="#ffffff" stroke-width="2"/>
  </svg>`),

  perkShout: svgUrl(`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100">
    <defs>
      <radialGradient id="bg" cx="50%" cy="50%" r="55%"><stop offset="0%" stop-color="#612816"/><stop offset="100%" stop-color="#180804"/></radialGradient>
      <linearGradient id="sw" x1="0" y1="0" x2="1" y2="1"><stop offset="0%" stop-color="#fff0c2"/><stop offset="55%" stop-color="#e39d24"/><stop offset="100%" stop-color="#783d08"/></linearGradient>
    </defs>
    <rect width="100" height="100" fill="url(#bg)"/>
    <path d="M50 14 L57 30 L55 62 L45 62 L43 30 Z" fill="url(#sw)" stroke="#fff7d6" stroke-width="1"/>
    <path d="M32 62 L68 62 L66 68 L34 68 Z" fill="#c9a463"/>
    <rect x="47" y="68" width="6" height="14" fill="#5a3d14"/>
    <path d="M22 36 Q32 24 38 36 M78 36 Q68 24 62 36" fill="none" stroke="#ff9a3c" stroke-width="3" stroke-linecap="round"/>
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
  grimBar1:    spriteBox(`${TOOLS}/grimoire-concept/concept.png`, 1376, 768, 1052, 642, 36, 36),
  grimBar4:    spriteBox(`${TOOLS}/grimoire-concept/concept.png`, 1376, 768, 1206, 642, 36, 36),
};

function iconHtml(ref, size, extraStyle = "") {
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
// CSS Principal (Janela Flutuante à Direita sobre o Mundo Aberto + HUD Azaath)
// ============================================================================
const CSS = `
@font-face{font-family:Cinzel;src:url(${FONTS}/Cinzel-Regular.ttf)}
@font-face{font-family:CinzelB;src:url(${FONTS}/Cinzel-Bold.ttf)}
@font-face{font-family:PTS;src:url(${FONTS}/PTSans-Regular.ttf)}
@font-face{font-family:PTSB;src:url(${FONTS}/PTSans-Bold.ttf)}
@font-face{font-family:Segoe;src:url(${FONTS}/SegoeUI-Regular.ttf)}
@font-face{font-family:SegoeB;src:url(${FONTS}/SegoeUI-Semibold.ttf)}

:root{
  --gold:#c9a463; --gold2:#8a6d3a; --cy:#5fe3e6;
  --txt:#e6e0d2; --mut:#8c9ba8; --dim:#5d6c78;
}
*{box-sizing:border-box}
html,body{margin:0;padding:0;background:#020508;overflow:hidden;width:1920px;height:1080px}
.stage{position:relative;width:1920px;height:1080px;overflow:hidden;font-family:PTS,sans-serif;color:var(--txt);background:#04080d}
.abs{position:absolute}
.cz{font-family:Cinzel,serif}
.czb{font-family:CinzelB,serif}

/* Cenário Vivo do Mundo / Câmara (sem tela cheia bloqueando a esquerda) */
.world-bg{position:absolute;inset:0;background:url('${ASSETS}/vault_bg.jpg') center/cover no-repeat;filter:brightness(0.86) saturate(0.95)}
.world-dim{position:absolute;inset:0;background:
  linear-gradient(90deg, transparent 0%, rgba(3,8,14,0.18) 38%, rgba(3,7,12,0.58) 72%, rgba(3,6,11,0.72) 100%),
  radial-gradient(60% 70% at 22% 52%, transparent 35%, rgba(2,5,9,0.58) 100%)}

/* Personagem livre no mundo (à esquerda) + HUD da Azaath embaixo */
.world-hero{position:absolute;left:58px;top:248px;width:360px;height:570px;
  background:url('${TOOLS}/drops-concept/warrior_pedestal.jpg') center top/120% auto no-repeat;
  -webkit-mask-image:radial-gradient(43% 47% at 50% 48%, #000 44%, rgba(0,0,0,0.45) 68%, transparent 92%),
                     linear-gradient(180deg, transparent 0%, #000 10%, #000 78%, transparent 97%);
  -webkit-mask-composite:source-in;opacity:0.94}
.hud-preview{position:absolute;left:340px;bottom:-18px;width:580px;height:290px;
  background:url('${TOOLS}/azaath-hud-concept/concept.png') center/contain no-repeat;
  -webkit-mask-image:radial-gradient(48% 36% at 50% 54%, #000 56%, rgba(0,0,0,0.35) 78%, transparent 96%);
  opacity:0.90;pointer-events:none;filter:drop-shadow(0 8px 24px rgba(0,0,0,0.95))}

/* Badge contextual sutil mostrando que o lado esquerdo fica livre (Mundo / Mercador) */
.world-hint{position:absolute;left:34px;top:28px;display:flex;align-items:center;gap:10px;
  padding:8px 14px;background:rgba(7,13,20,0.72);border:1px solid rgba(138,109,58,0.38);backdrop-filter:blur(4px)}
.world-hint .dot{width:8px;height:8px;transform:rotate(45deg);background:var(--cy);box-shadow:0 0 8px var(--cy)}
.world-hint span{font-family:Cinzel,serif;font-size:11px;letter-spacing:1.8px;color:#cfd8e0}

/* =====================================================================
   JANELA FLUTUANTE DO INVENTÁRIO (Direita, compacta e arrastável)
   ===================================================================== */
.inv-win{position:absolute;left:1232px;top:92px;width:646px;height:858px;
  background:linear-gradient(180deg,rgba(10,17,26,0.92) 0%,rgba(6,10,16,0.96) 100%);
  border:1px solid rgba(138,109,58,0.58);
  box-shadow:0 0 0 1px #020508,inset 0 1px 0 rgba(95,227,230,0.16),inset 0 0 36px rgba(0,0,0,0.85),0 24px 64px rgba(0,0,0,0.88)}
.inv-win:before{content:"";position:absolute;inset:4px;border:1px solid rgba(201,164,99,0.16);pointer-events:none}
.c-dia{position:absolute;width:8px;height:8px;transform:rotate(45deg);background:#122530;border:1px solid var(--gold);box-shadow:0 0 6px rgba(95,227,230,0.45)}
.c-dia.tl{left:-4px;top:-4px}.c-dia.tr{right:-4px;top:-4px}.c-dia.bl{left:-4px;bottom:-4px}.c-dia.br{right:-4px;bottom:-4px}

.inv-hdr{padding:18px 22px 0}
.inv-top{display:flex;align-items:center;justify-content:space-between}
.inv-title{display:flex;align-items:center;gap:12px}
.inv-title h1{margin:0;font-family:Cinzel,serif;font-size:20px;font-weight:400;letter-spacing:3.2px;color:#f3ebd6;text-shadow:0 0 12px rgba(95,227,230,0.22)}
.cap-pill{font-family:Cinzel,serif;font-size:10.5px;letter-spacing:1.2px;color:#9de8ed;padding:2px 8px;border:1px solid rgba(95,227,230,0.34);background:rgba(16,42,54,0.45);border-radius:2px}

.top-right{display:flex;align-items:center;gap:18px}
.view-tabs{display:flex;gap:18px;align-items:center}
.vtab{position:relative;font-family:Cinzel,serif;font-size:11.5px;letter-spacing:2.2px;color:#788894;padding-bottom:5px}
.vtab.on{color:#ebfbff;text-shadow:0 0 10px rgba(95,227,230,0.75)}
.vtab.on:after{content:"";position:absolute;left:-24px;right:-24px;bottom:-9px;height:14px;background:url('${ASSETS}/sh_navflare.png') center/100% 100% no-repeat;mix-blend-mode:screen;pointer-events:none}
.close-btn{width:24px;height:24px;border-radius:50%;background:radial-gradient(circle,#12202b,#070d14);border:1px solid rgba(138,109,58,0.75);display:flex;align-items:center;justify-content:center}

.inv-controls{display:flex;align-items:center;gap:8px;margin-top:12px}
.search-box{flex:1;height:28px;background:rgba(4,9,14,0.92);border:1px solid #2b3c46;display:flex;align-items:center;padding:0 10px;gap:8px;color:#70808c;font-size:12.5px}
.lens{width:10.5px;height:10.5px;border:1.8px solid #7f919e;border-radius:50%;position:relative}
.lens:after{content:"";position:absolute;right:-5px;bottom:-4px;width:5px;height:1.8px;background:#7f919e;transform:rotate(45deg)}
.qmark{margin-left:auto;width:14px;height:14px;border-radius:50%;background:radial-gradient(circle,#f3d184,#9c7026);color:#140d02;font-weight:700;font-size:10.5px;display:flex;align-items:center;justify-content:center}

.sort-lbl{font-size:11.5px;color:#8c9ba8;margin-left:4px}
.ico-btn{width:26px;height:26px;background:rgba(10,18,26,0.9);border:1px solid #30414c;display:flex;align-items:center;justify-content:center}
.ico-btn img{width:15px;height:15px;opacity:0.82}
.ico-btn.on{border-color:#5fe3e6;box-shadow:0 0 10px rgba(95,227,230,0.35),inset 0 0 8px rgba(95,227,230,0.2)}
.ico-btn.on img{opacity:1;filter:drop-shadow(0 0 4px #5fe3e6)}
.org-btn{height:26px;padding:0 10px;background:linear-gradient(180deg,#152532,#0b131b);border:1px solid #6b5630;color:#e5dcc5;font-family:Cinzel,serif;font-size:10px;letter-spacing:1.4px;display:flex;align-items:center}

.filter-strip{display:flex;gap:6px;margin-top:10px;padding-bottom:10px;border-bottom:1px solid rgba(201,164,99,0.2)}
.fpill{padding:3.5px 10px;border-radius:11px;font-size:11px;letter-spacing:0.4px;color:#8e9da8;background:rgba(10,18,26,0.72);border:1px solid rgba(90,110,124,0.28)}
.fpill.on{color:#f0fcff;background:linear-gradient(180deg,rgba(24,84,96,0.75),rgba(11,44,54,0.85));border-color:#5fe3e6;box-shadow:0 0 10px rgba(95,227,230,0.3)}

/* Grade em 2 Colunas (5 slots por linha em cada coluna = 10 slots de largura) */
.inv-body{position:relative;padding:12px 22px 0;display:grid;grid-template-columns:1fr 1fr;gap:18px}
.sec-hdr{display:flex;align-items:center;gap:7px;margin:0 0 7px}
.sec-hdr .t{font-family:Cinzel,serif;font-size:11.5px;letter-spacing:2px;color:#dfd4b8}
.sec-hdr .ln{flex:1;height:1px;background:linear-gradient(90deg,rgba(201,164,99,0.55),rgba(201,164,99,0.06))}
.sec-hdr .n{font-family:CinzelB,serif;font-size:12px;color:#e6dec8}
.sec-hdr .ar{width:14px;height:14px;border:1px solid #594726;background:#0a131a;position:relative}
.sec-hdr .ar:after{content:"";position:absolute;left:2.5px;top:4.5px;border-top:5px solid #c9a463;border-left:4px solid transparent;border-right:4px solid transparent}

.slot-grid{display:grid;grid-template-columns:repeat(5,50px);gap:7px;margin-bottom:14px}
.islot{position:relative;width:50px;height:50px;background:radial-gradient(circle at 50% 35%,#1a2732,#091016 80%);
  border:1px solid #35444e;box-shadow:inset 0 0 0 1px #000,inset 0 0 10px #000}
.islot:before,.islot:after{content:"";position:absolute;width:6px;height:6px;border:1px solid rgba(201,164,99,0.55);pointer-events:none;z-index:3}
.islot:before{left:-1px;top:-1px;border-right:0;border-bottom:0}
.islot:after{right:-1px;bottom:-1px;border-left:0;border-top:0}
.islot .ic-wrap{position:absolute;inset:3px;overflow:hidden;background:#070c11}
.ic-img{width:100%;height:100%;background-repeat:no-repeat}

.islot.q2{border-color:#2e9a46;box-shadow:inset 0 0 9px rgba(63,207,90,0.35),0 0 6px rgba(63,207,90,0.22)}
.islot.q3{border-color:#2f78de;box-shadow:inset 0 0 9px rgba(61,148,255,0.40),0 0 8px rgba(61,148,255,0.28)}
.islot.q4{border-color:#9e46eb;box-shadow:inset 0 0 11px rgba(194,77,255,0.48),0 0 10px rgba(194,77,255,0.36)}
.islot.junk{opacity:0.65;border-color:#444a50}
.islot.hovered{border-color:#d5ffff;box-shadow:0 0 0 2px #5fe3e6,0 0 18px rgba(95,227,230,0.85),inset 0 0 12px rgba(194,77,255,0.7);z-index:5}
.islot .ilvl{position:absolute;left:3.5px;top:2.5px;font-family:CinzelB,serif;font-size:10px;color:#f5efe0;text-shadow:0 1px 3px #000,0 0 4px #000;z-index:4}
.islot .cnt{position:absolute;right:3.5px;bottom:1.5px;font-family:CinzelB,serif;font-size:11.5px;color:#fff;text-shadow:0 1px 2px #000,0 0 4px #000;z-index:4}
.islot .dur{position:absolute;left:4px;right:4px;bottom:3px;height:2.5px;background:#0a0f14;z-index:4}
.islot .dur i{display:block;height:100%;background:#5fe3e6}
.islot .dur.mid i{background:#f0a830}
.islot .qbadge{position:absolute;right:-4px;top:-4px;width:16px;height:16px;background:url('${ASSETS}/inv_badge.png') center/contain no-repeat;z-index:5}
.islot .newgem{position:absolute;right:3px;top:3px;width:6.5px;height:6.5px;transform:rotate(45deg);background:#ffd966;box-shadow:0 0 6px #ffd966;z-index:5}

.islot.round{border-radius:50%;border:0;background:none;box-shadow:none}
.islot.round:before,.islot.round:after{display:none}
.islot.round .ic-wrap{inset:4px;border-radius:50%}
.islot.round .rframe{position:absolute;inset:-3px;background:url('${ASSETS}/sh_roundframe.png') center/contain no-repeat;pointer-events:none;z-index:3}
.islot.round.q3 .rframe{filter:drop-shadow(0 0 5px rgba(61,148,255,0.85))}
.islot.round.q4 .rframe{filter:drop-shadow(0 0 5px rgba(194,77,255,0.9))}
.islot.round.q2 .rframe{filter:drop-shadow(0 0 4px rgba(63,207,90,0.8))}
.islot.round .cnt{right:2px;bottom:0px;font-size:11px;background:rgba(5,10,16,0.8);padding:0 3px;border-radius:3px}

.islot.free{background:rgba(8,14,20,0.65);border:1px dashed #334550;display:flex;align-items:center;justify-content:center}
.islot.free span{font-family:CinzelB,serif;font-size:15px;color:#788894}

/* Faixa de Bolsas Equipadas + Capacidade dentro da janela */
.bags-strip{position:absolute;left:22px;right:22px;bottom:68px;height:48px;display:flex;align-items:center;justify-content:space-between;
  padding:0 12px;background:rgba(7,12,19,0.72);border:1px solid rgba(138,109,58,0.28)}
.bags-mini{display:flex;align-items:center;gap:6px}
.bag-cell{position:relative;width:32px;height:32px;background:#080f16;border:1px solid #4a5a64;overflow:hidden}
.bag-cell.on{border-color:#c9a463}
.bag-cell .cap{position:absolute;right:1px;bottom:1px;font-family:CinzelB,serif;font-size:9px;color:#f5edd8;background:rgba(4,8,14,0.78);padding:0 2px;border-radius:2px;line-height:1.1}
.cap-gauge-wrap{width:230px}
.gauge{height:5px;background:#050a10;border:1px solid #23333d;position:relative;margin-top:4px}
.gauge i{position:absolute;left:0;top:0;bottom:0;background:linear-gradient(90deg,#1a8896,#5fe3e6);box-shadow:0 0 8px #5fe3e6}

/* Rodapé da Janela */
.inv-foot{position:absolute;left:22px;right:22px;bottom:14px;height:44px;border-top:1px solid rgba(201,164,99,0.22);display:flex;align-items:center;justify-content:space-between;padding-top:6px}
.money{display:flex;align-items:center;gap:12px;font-family:CinzelB,serif;font-size:16px;color:#f4ecda}
.coin{display:inline-block;width:12px;height:12px;border-radius:50%;margin-left:3.5px;vertical-align:-1px;box-shadow:0 1px 2px #000}
.coin.g{background:radial-gradient(circle at 35% 30%,#fff6bd,#e5b53e 50%,#855810)}
.coin.s{background:radial-gradient(circle at 35% 30%,#ffffff,#c2cbd1 50%,#5b646b)}
.coin.c{background:radial-gradient(circle at 35% 30%,#ffd8b0,#c86f32 50%,#662f0f)}
.foot-btns{display:flex;gap:8px}
.sbtn{position:relative;height:30px;padding:0 12px;background:linear-gradient(180deg,rgba(22,34,48,0.9),rgba(10,16,24,0.95));
  border:1px solid rgba(138,109,58,0.65);font-family:Cinzel,serif;font-size:10.5px;letter-spacing:1.4px;color:#efe6cf;display:flex;align-items:center;gap:5px}
.sbtn.on{border-color:#5fe3e6;box-shadow:0 0 10px rgba(95,227,230,0.28)}
.sbtn:after{content:"";position:absolute;left:10px;right:10px;bottom:-1px;height:2px;background:linear-gradient(90deg,transparent,#5fe3e6,transparent);box-shadow:0 0 8px #5fe3e6}
.sbtn.gold:after{background:linear-gradient(90deg,transparent,#e6b450,transparent);box-shadow:0 0 8px #e6b450}

/* Mini Radial (G) ancorado à esquerda do rodapé do Inventário (como no Inventory.lua) */
.radial-float{position:absolute;left:1076px;top:766px;width:140px;height:164px;display:flex;flex-direction:column;align-items:center}
.radial-disc{position:relative;width:128px;height:128px;border-radius:50%;
  background:radial-gradient(circle,rgba(15,32,42,0.94) 0%,rgba(6,13,20,0.96) 72%);
  border:1px solid rgba(201,164,99,0.62);box-shadow:0 0 24px rgba(95,227,230,0.22),inset 0 0 22px #000}
.radial-ring{position:absolute;inset:12px;border-radius:50%;border:1px dashed rgba(95,227,230,0.3)}
.radial-key{position:absolute;left:50%;top:50%;transform:translate(-50%,-50%);font-family:CinzelB,serif;font-size:14px;color:var(--gold);text-shadow:0 0 8px rgba(201,164,99,0.6)}
.rad-slot{position:absolute;width:28px;height:28px;border-radius:50%;transform:translate(-50%,-50%);
  background:#0a131b;border:1px solid #7d6232;box-shadow:0 0 6px #000}
.rad-slot .in{position:absolute;inset:2px;border-radius:50%;overflow:hidden}
.rad-slot .cnt{position:absolute;right:-3px;bottom:-3px;font-family:CinzelB,serif;font-size:9.5px;color:#fff;text-shadow:0 1px 2px #000,0 0 4px #000}
.rad-slot.empty{border-color:#2c3a44;color:#5d6c78;display:flex;align-items:center;justify-content:center;font-size:12px}

/* =====================================================================
   NOVO CARD DE ITENS + COMPARAÇÃO (ANCORADO À ESQUERDA, ANCHOR_LEFT)
   ===================================================================== */
.icard{position:relative;width:348px;background:#131314;border:1px solid #050506;box-shadow:inset 0 0 0 1px #404247,0 22px 54px rgba(0,0,0,0.90)}
.eq-tab{position:relative;display:inline-flex;align-items:center;justify-content:center;height:22px;padding:0 14px;background:#131314;
  border:1px solid #050506;border-bottom:0;box-shadow:inset 1px 1px 0 #404247,inset -1px 0 0 #404247;margin-bottom:-1px;z-index:2}
.eq-tab span{font-family:SegoeB,sans-serif;font-size:12px;color:#ffd140;border-bottom:1px solid rgba(255,209,64,0.72);padding-bottom:1px}

.ic-head{position:relative;height:90px;overflow:hidden;border-bottom:1px solid rgba(255,255,255,0.45)}
.ic-paper{position:absolute;inset:0;background:url('${ASSETS}/ic_grunge.png') center/100% 100% no-repeat;filter:brightness(1.05)}
.ic-tint{position:absolute;inset:0;mix-blend-mode:multiply}
.ic-smoke1{position:absolute;inset:-20px 0 0 0;background:url('${ASSETS}/ic_smoke1.png') 0 20%/115% auto repeat;mix-blend-mode:screen;opacity:0.52}
.ic-smoke2{position:absolute;inset:-20px 0 0 0;background:url('${ASSETS}/ic_smoke2.png') 40% 50%/85% auto repeat;mix-blend-mode:screen;opacity:0.38}
.ic-flare{position:absolute;left:0;right:0;bottom:0;height:70px;background:url('${ASSETS}/ic_flare.png') center bottom/100% 100% no-repeat;mix-blend-mode:screen;opacity:0.68}
.ic-fx{position:absolute;inset:0;pointer-events:none}
.ic-head-content{position:relative;z-index:3;height:100%;display:flex;align-items:center;padding:0 11px;gap:11px}
.ic-icon-box{position:relative;width:70px;height:70px;flex:none;padding:3px;box-shadow:0 4px 12px rgba(0,0,0,0.7)}
.ic-icon-inner{width:100%;height:100%;overflow:hidden;background:#08080a}
.ic-hmeta{flex:1;min-width:0;height:70px;display:flex;flex-direction:column;justify-content:space-between;padding:1px 0}
.ic-name{font-family:SegoeB,sans-serif;font-size:16.5px;line-height:1.15;text-shadow:1px 1px 2px #000}
.ic-rar{font-family:SegoeB,sans-serif;font-size:12px;text-shadow:1px 1px 2px #000;margin-top:2px}
.ic-botrow{display:flex;justify-content:space-between;font-family:SegoeB,sans-serif;font-size:12px;color:#fff;text-shadow:1px 1px 2px #000}

.icard.epic .ic-head{border-bottom-color:rgba(219,107,255,0.65)}
.icard.epic .ic-tint{background:linear-gradient(180deg,#5a1380 0%,#b838f5 100%)}
.icard.epic .ic-smoke1,.icard.epic .ic-smoke2{filter:drop-shadow(0 0 8px #d45cff) sepia(1) hue-rotate(245deg) saturate(5)}
.icard.epic .ic-flare{filter:sepia(1) hue-rotate(245deg) saturate(5)}
.icard.epic .ic-icon-box{background:linear-gradient(180deg,#6e1b99,#08080a);border:1px solid #db6bff}
.icard.epic .ic-name,.icard.epic .ic-rar{color:#df78ff}

.icard.uncommon .ic-head{border-bottom-color:rgba(97,242,76,0.55)}
.icard.uncommon .ic-tint{background:linear-gradient(180deg,#165919 0%,#36bf36 100%)}
.icard.uncommon .ic-smoke1,.icard.uncommon .ic-smoke2{filter:sepia(1) hue-rotate(75deg) saturate(4)}
.icard.uncommon .ic-flare{filter:sepia(1) hue-rotate(75deg) saturate(4)}
.icard.uncommon .ic-icon-box{background:linear-gradient(180deg,#1d6e20,#08080a);border:1px solid #5fe84d}
.icard.uncommon .ic-name,.icard.uncommon .ic-rar{color:#61f24c}

.ic-body{padding:10px 14px 12px;font-family:Segoe,sans-serif;font-size:12.8px;color:#dcdcdc}
.ilvl-row{display:flex;align-items:center;gap:9px;margin-bottom:4px}
.ilvl-hex{width:30px;height:30px;background:url('${ASSETS}/ic_ilvl.png') center/contain no-repeat}
.ilvl-val{font-family:SegoeB,sans-serif;font-size:32px;line-height:1;color:#fff;text-shadow:1px 1px 2px #000}

.stat-ln{line-height:1.38;color:#dcdcdc}
.stat-ln b{font-family:SegoeB,sans-serif;color:#fff;font-weight:400}

.div-dia{position:relative;height:12px;margin:6px 0;display:flex;align-items:center}
.div-dia:before,.div-dia:after{content:"";flex:1;height:1px;background:rgba(82,83,86,0.9)}
.div-dia i{width:11px;height:11px;margin:0 4px;background:url('${ASSETS}/ic_diamond.png') center/contain no-repeat;opacity:0.78}

.perk-row{display:flex;align-items:flex-start;gap:9px;margin:5px 0}
.perk-ic{position:relative;width:26px;height:26px;flex:none;margin-top:1px}
.perk-ic .in{position:absolute;inset:2px;border-radius:50%;overflow:hidden}
.perk-ic .ring{position:absolute;inset:-1px;background:url('${ASSETS}/ic_perkring.png') center/contain no-repeat;opacity:0.92}
.perk-txt{font-family:SegoeB,sans-serif;font-size:12.4px;line-height:1.32;color:#6ba8ff}
.perk-txt .pre{color:#9ecbff}

.flavor{font-size:12.2px;line-height:1.35;color:#c8c8c8;font-style:italic}
.bind-ln{font-family:SegoeB,sans-serif;color:#3dcc6b;margin-bottom:2px}
.sell-ln{display:flex;align-items:center;gap:6px;margin-top:5px}
.sell-ln .lbl{color:#dcdcdc}
.sell-ln .val{font-family:SegoeB,sans-serif;color:#fff;display:flex;align-items:center;gap:5px}
.delta-ln{font-size:12px;line-height:1.35;color:#45e074}
`;

// ============================================================================
// Montagem do HTML
// ============================================================================
function buildHtml() {
  const radItems = [
    ["healthPotion", "15"],
    ["manaPotion", "8"],
    ["goldElixir", "4"],
    ["meat", "12"],
    ["bandage", "20"],
    null,
    null,
    null,
  ];
  let radHtml = "";
  radItems.forEach((it, i) => {
    const a = (i / 8) * Math.PI * 2 - Math.PI / 2;
    const sx = 64 + Math.cos(a) * 44;
    const sy = 64 + Math.sin(a) * 44;
    if (it) {
      radHtml += `<div class="rad-slot" style="left:${sx.toFixed(1)}px;top:${sy.toFixed(1)}px">
        <div class="in">${iconHtml(it[0], 24)}</div><span class="cnt">${it[1]}</span></div>`;
    } else {
      radHtml += `<div class="rad-slot empty" style="left:${sx.toFixed(1)}px;top:${sy.toFixed(1)}px">+</div>`;
    }
  });

  function slot(ic, opts = {}) {
    const cls = ["islot", opts.q || "", opts.round ? "round" : "", opts.hovered ? "hovered" : "", opts.junk ? "junk" : ""].filter(Boolean).join(" ");
    return `<div class="${cls}">
      <div class="ic-wrap">${iconHtml(ic, 44)}</div>
      ${opts.round ? `<div class="rframe"></div>` : ""}
      ${opts.ilvl ? `<span class="ilvl">${opts.ilvl}</span>` : ""}
      ${opts.cnt ? `<span class="cnt">${opts.cnt}</span>` : ""}
      ${opts.dur != null ? `<div class="dur ${opts.dur < 70 ? "mid" : ""}"><i style="width:${opts.dur}%"></i></div>` : ""}
      ${opts.quest ? `<div class="qbadge"></div>` : ""}
      ${opts.isNew ? `<div class="newgem"></div>` : ""}
    </div>`;
  }
  function sec(title, n, body) {
    return `<div><div class="sec-hdr"><span class="t">${title}</span><span class="ln"></span><span class="n">${n}</span><span class="ar"></span></div>
      <div class="slot-grid">${body}</div></div>`;
  }

  const colLeft = [
    sec("ARMAS", 3,
      slot("epicSword", { q: "q4", ilvl: 48, dur: 100, hovered: true, isNew: true }) +
      slot("obsidianAxe", { q: "q3", ilvl: 36, dur: 94 }) +
      slot("dagger", { q: "q2", ilvl: 29, dur: 100 })
    ),
    sec("EQUIPAMENTO", 5,
      slot("helmFlame", { q: "q4", ilvl: 45, dur: 100 }) +
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
      slot("hearthstone", { cnt: 1 }) +
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
      slot("key", { q: "q3" }) +
      slot("amulet", { q: "q2" }) +
      slot("ring", { q: "q3" })
    ),
    sec("LIXO", 2,
      slot("helmObsid", { junk: true, dur: 22 }) +
      slot("bandage", { junk: true, cnt: 3 })
    ),
  ].join("");

  function sparksSvg(n, w, h, col, seed) {
    let r = seed, out = "";
    const rnd = () => (r = (r * 9301 + 49297) % 233280) / 233280;
    for (let i = 0; i < n; i++) {
      const x = rnd() * w, y = h * (0.18 + rnd() * 0.78), sz = 5 + rnd() * 9, op = 0.45 + rnd() * 0.55;
      const isEmber = rnd() < 0.35;
      out += `<img src="${ASSETS}/${isEmber ? "ic_ember.png" : "ic_spark.png"}" style="position:absolute;left:${x.toFixed(0)}px;top:${y.toFixed(0)}px;width:${isEmber ? (sz * 0.55).toFixed(0) : sz.toFixed(0)}px;height:${isEmber ? (sz * 1.8).toFixed(0) : sz.toFixed(0)}px;opacity:${op.toFixed(2)};mix-blend-mode:screen;filter:drop-shadow(0 0 4px ${col})">`;
    }
    return out;
  }

  return `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>Inventário Flutuante — AzaathUI Concept V3</title>
<style>${CSS}</style></head><body>
<div class="stage">
  <div class="world-bg"></div>
  <div class="world-dim"></div>

  <!-- Lado esquerdo livre: Mundo Aberto / Personagem / Espaço para Mercador -->
  <div class="world-hero"></div>
  <div class="hud-preview"></div>
  <div class="world-hint"><i class="dot"></i><span>MUNDO ABERTO / ESPAÇO PARA MERCADOR & BANCO</span></div>

  <!-- MINI RADIAL (G) aberto ao lado do botão no rodapé do inventário -->
  <div class="radial-float">
    <div class="radial-disc">
      <div class="radial-ring"></div>
      <span class="radial-key">G</span>
      ${radHtml}
    </div>
    <div class="cz" style="margin-top:8px;font-size:9.5px;letter-spacing:1.8px;color:#b8c8d4;text-shadow:0 1px 3px #000">RADIAL (G)</div>
  </div>

  <!-- NOVO CARD DE ITENS + COMPARAÇÃO (ANCORADO À ESQUERDA DO ITEM, ANCHOR_LEFT) -->
  <div class="abs" style="left:866px;top:164px;z-index:10">
    <div class="icard epic">
      <div class="ic-head">
        <div class="ic-paper"></div>
        <div class="ic-tint"></div>
        <div class="ic-smoke1"></div>
        <div class="ic-smoke2"></div>
        <div class="ic-flare"></div>
        <div class="ic-fx">${sparksSvg(18, 346, 88, "#df78ff", 44)}</div>
        <div class="ic-head-content">
          <div class="ic-icon-box"><div class="ic-icon-inner">${iconHtml("epicSword", 66)}</div></div>
          <div class="ic-hmeta">
            <div>
              <div class="ic-name">Lâmina Rúnica de Azaath</div>
              <div class="ic-rar">Épico &nbsp;•&nbsp; Único</div>
            </div>
            <div class="ic-botrow"><span>Espada</span><span>Duas Mãos</span></div>
          </div>
        </div>
      </div>

      <div class="ic-body">
        <div class="ilvl-row"><div class="ilvl-hex"></div><div class="ilvl-val">48</div></div>
        <div class="stat-ln"><b>84 - 142</b> Dano</div>
        <div class="stat-ln"><b>2.80</b> Velocidade</div>
        <div class="stat-ln"><b>40.4</b> Dano por Segundo</div>

        <div class="div-dia"><i></i></div>
        <div class="stat-ln"><b>+18</b> Força</div>
        <div class="stat-ln"><b>+14</b> Vigor</div>
        <div class="stat-ln"><b>+9</b> Taxa de Crítico</div>

        <div class="div-dia"><i></i></div>
        <div class="perk-row">
          <div class="perk-ic"><div class="in">${iconHtml("perkShout", 24)}</div><div class="ring"></div></div>
          <div class="perk-txt"><span class="pre">Equipar:</span> Aumenta o Poder de Ataque em 36.</div>
        </div>
        <div class="perk-row">
          <div class="perk-ic"><div class="in">${iconHtml("perkBolt", 24)}</div><div class="ring"></div></div>
          <div class="perk-txt"><span class="pre">Chance ao acertar:</span> Canaliza Azoth arcano causando 65 de dano extra ao alvo.</div>
        </div>

        <div class="div-dia"><i></i></div>
        <div class="flavor">Forjada nas câmaras abissais sob a luz das primeiras runas.</div>

        <div class="div-dia"><i></i></div>
        <div class="bind-ln">Vinculado ao equipar</div>
        <div class="stat-ln"><b>95 / 95</b> Durabilidade</div>
        <div class="stat-ln">Requer Nível 24</div>
        <div class="sell-ln">
          <span class="lbl">Preço de venda:</span>
          <span class="val"><span>4<i class="coin g"></i></span><span>18<i class="coin s"></i></span><span>50<i class="coin c"></i></span></span>
        </div>
      </div>
    </div>
  </div>

  <!-- CARD DE COMPARAÇÃO (AO LADO DO PRINCIPAL, COMO ShoppingTooltip1) -->
  <div class="abs" style="left:506px;top:142px;z-index:9">
    <div class="eq-tab"><span>Equipado no momento</span></div>
    <div class="icard uncommon" style="width:342px">
      <div class="ic-head" style="height:82px">
        <div class="ic-paper"></div>
        <div class="ic-tint"></div>
        <div class="ic-smoke1"></div>
        <div class="ic-flare"></div>
        <div class="ic-fx">${sparksSvg(10, 340, 80, "#61f24c", 91)}</div>
        <div class="ic-head-content">
          <div class="ic-icon-box" style="width:62px;height:62px"><div class="ic-icon-inner">${iconHtml("greenSword", 58)}</div></div>
          <div class="ic-hmeta" style="height:62px">
            <div>
              <div class="ic-name" style="font-size:15.5px">Espada Larga da Vigília</div>
              <div class="ic-rar">Incomum</div>
            </div>
            <div class="ic-botrow"><span>Espada</span><span>Duas Mãos</span></div>
          </div>
        </div>
      </div>

      <div class="ic-body" style="padding:9px 14px 11px">
        <div class="ilvl-row" style="margin-bottom:3px"><div class="ilvl-hex" style="width:26px;height:26px"></div><div class="ilvl-val" style="font-size:26px">34</div></div>
        <div class="stat-ln"><b>58 - 96</b> Dano &nbsp;·&nbsp; <b>2.60</b> Velocidade</div>
        <div class="div-dia" style="margin:5px 0"><i></i></div>
        <div class="stat-ln"><b>+10</b> Força &nbsp;·&nbsp; <b>+8</b> Vigor</div>
        <div class="div-dia" style="margin:5px 0"><i></i></div>
        <div class="perk-row" style="margin:3px 0">
          <div class="perk-ic"><div class="in">${iconHtml("grimShield", 24)}</div><div class="ring"></div></div>
          <div class="perk-txt"><span class="pre">Equipar:</span> Aumenta a taxa de acerto em 1%.</div>
        </div>
        <div class="div-dia" style="margin:5px 0"><i></i></div>
        <div style="color:#b8b8b8;font-size:11.5px;margin-bottom:1px">Se equipar o item selecionado:</div>
        <div class="delta-ln">+26 – 46 Dano &nbsp;·&nbsp; +8 Força &nbsp;·&nbsp; +6 Vigor</div>
      </div>
    </div>
  </div>

  <!-- JANELA FLUTUANTE DO INVENTÁRIO (DIREITA) -->
  <main class="inv-win">
    <i class="c-dia tl"></i><i class="c-dia tr"></i><i class="c-dia bl"></i><i class="c-dia br"></i>
    <div class="inv-hdr">
      <div class="inv-top">
        <div class="inv-title">
          <h1>INVENTÁRIO</h1>
          <span class="cap-pill">46 / 66</span>
        </div>
        <div class="top-right">
          <div class="view-tabs">
            <span class="vtab on">CATEGORIAS</span>
            <span class="vtab">BOLSAS</span>
          </div>
          <div class="close-btn"><svg width="10" height="10" viewBox="0 0 16 16"><path d="M3 3 L13 13 M13 3 L3 13" stroke="#c9bfa8" stroke-width="1.8" stroke-linecap="round"/></svg></div>
        </div>
      </div>

      <div class="inv-controls">
        <div class="search-box"><span class="lens"></span><span>Buscar item...</span><span class="qmark">?</span></div>
        <span class="sort-lbl">Ordenar</span>
        <div class="ico-btn on"><img src="${ASSETS}/inv_clock.png"></div>
        <div class="ico-btn"><img src="${ASSETS}/inv_star.png"></div>
        <div class="ico-btn"><img src="${ASSETS}/inv_tier.png"></div>
        <div class="org-btn">ORGANIZAR</div>
      </div>

      <div class="filter-strip">
        <span class="fpill on">Todos</span>
        <span class="fpill">Armas</span>
        <span class="fpill">Equip.</span>
        <span class="fpill">Consumíveis</span>
        <span class="fpill">Materiais</span>
        <span class="fpill">Missão</span>
        <span class="fpill">Diversos</span>
        <span class="fpill">Lixo</span>
      </div>
    </div>

    <div class="inv-body">
      <div>${colLeft}</div>
      <div>${colRight}</div>
    </div>

    <!-- Bolsas Equipadas & Barra de Capacidade -->
    <div class="bags-strip">
      <div class="bags-mini">
        <span class="cz" style="font-size:10px;letter-spacing:1.6px;color:#b8ae96;margin-right:4px">BOLSAS</span>
        <div class="bag-cell on">${iconHtml("bagLeather", 30)}<span class="cap">16</span></div>
        <div class="bag-cell on">${iconHtml("bagSilk", 30)}<span class="cap">14</span></div>
        <div class="bag-cell on">${iconHtml("bagArcane", 30)}<span class="cap">12</span></div>
        <div class="bag-cell on">${iconHtml("bagLeather", 30)}<span class="cap">12</span></div>
        <div class="bag-cell">${iconHtml("bagArcane", 30, "opacity:0.45")}<span class="cap" style="color:#8c9ba8">12</span></div>
      </div>
      <div class="cap-gauge-wrap">
        <div style="display:flex;justify-content:space-between;font-size:10.5px;color:#9eb0bd">
          <span class="cz" style="letter-spacing:1.4px">ESPAÇO LIVRE</span><span style="color:#e6f9ff">20 / 66 LIVRES</span>
        </div>
        <div class="gauge"><i style="width:70%"></i></div>
      </div>
    </div>

    <div class="inv-foot">
      <div class="money">
        <span>142<i class="coin g"></i></span>
        <span>65<i class="coin s"></i></span>
        <span>30<i class="coin c"></i></span>
      </div>
      <div class="foot-btns">
        <div class="sbtn on">RADIAL (G)</div>
        <div class="sbtn gold">VENDER LIXO</div>
        <div class="sbtn">REPARAR</div>
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
  "--virtual-time-budget=1200",
  "--allow-file-access-from-files",
  "--screenshot=" + OUT_PNG,
  "file:///" + HTML_FILE.replace(/\\/g, "/"),
], { encoding: "utf8" });

console.log("Edge status:", r.status, "PNG:", OUT_PNG, fs.existsSync(OUT_PNG) ? fs.statSync(OUT_PNG).size + " bytes" : "ERRO");
if (r.status !== 0 && r.stderr) console.error(r.stderr);
