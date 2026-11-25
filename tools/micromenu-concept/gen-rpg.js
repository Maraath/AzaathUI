// Arte conceitual 2 do Micro Menu — Estética Sóbria & Cinematográfica (New World × O Senhor dos Anéis).
// Ardósia negra, bronze oxidado de Númenor, prata de mithril gravada a buril, tracery élfico,
// linhas de astrolábio e brasa contida de forja.
// Uso: node tools/micromenu-concept/gen-rpg.js
"use strict";
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const DIR = __dirname;
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const SCALE = 2;
const W = 1440, H = 900;

// Paleta Sóbria New World / Terra-média
const AU = "#9e8152", AUL = "#d8c092", AUD = "#4d3d23", AUB = "#f2d8a7";
const AG = "#8d97a3", AGL = "#cfd7e0", AGD = "#3d444d";
const EMB = "#d97a2b", EMBL = "#f7c77e", EMBD = "#5e2206";
const SLATE = "#0a0c0e", SLATE2 = "#12151a", INK = "#060708";
const TXT = "#e6dfd1", MUTED = "#7d828a", SILVER = "#b4bcc4";

const f = (n) => (+n).toFixed(2);
const rad = (d) => d * Math.PI / 180;
const at = (cx, cy, r, d) => [cx + r * Math.cos(rad(d - 90)), cy + r * Math.sin(rad(d - 90))];

const diamondPts = (cx, cy, rx, ry = rx) =>
  `${f(cx)},${f(cy - ry)} ${f(cx + rx)},${f(cy)} ${f(cx)},${f(cy + ry)} ${f(cx - rx)},${f(cy)}`;

const octPts = (cx, cy, r, cut = 0.42) => {
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
const emberShard = (cx, cy, rx, ry = rx * 1.4) =>
  facet(cx, cy, rx, ry, [EMBL, EMB, EMBD, "#a84c12"]) +
  `<polygon points="${diamondPts(cx, cy, rx, ry)}" fill="none" stroke="${AUL}" stroke-width="0.6" opacity="0.8"/>`;

// Runas élficas / tengwar estilizadas em traço fino (para anel de forja e astrolábio)
const RUNES = [
  "M-2 -4 C0 -5 2 -3 2 0 C2 3 0 4 -2 4 M-2 -4 V5",
  "M-3 -3 C-1 -5 3 -4 3 0 C3 3 0 4 -2 2 M0 -5 V4",
  "M-2 4 V-3 C-2 -5 2 -5 2 -2 V4 M-3 0 H3",
  "M0 -5 L3 0 L0 5 L-3 0 Z M0 -2 V2",
  "M-3 -4 L0 -1 L3 -4 M0 -1 V5",
  "M-2 -4 C2 -4 2 0 -2 0 C2 0 2 4 -2 4",
  "M-3 4 C-3 -2 0 -5 3 -2 C3 2 0 4 -1 1",
  "M0 -5 V5 M-3 -2 C0 -4 3 -2 3 1",
];
const elvenRune = (cx, cy, i, deg, col, sc = 0.6, op = 0.85) =>
  `<path d="${RUNES[i % RUNES.length]}" transform="translate(${f(cx)} ${f(cy)}) rotate(${f(deg)}) scale(${sc})" fill="none" stroke="${col}" stroke-width="1.05" stroke-linecap="round" opacity="${op}"/>`;

// ------------------------------------------------------------------ 15 ÍCONES ESTILO GRAVURA A BURIL (NEW WORLD × LOTR)
function etchedIcon(key, active = false) {
  const pri = active ? EMBL : AGL;
  const sec = active ? EMB : AU;
  const dim = active ? AUL : AGD;

  switch (key) {
    case "character": // Elmo Alto da Guarda de Gondor (asas gravadas, nasal afilado)
      return `
        <path d="M0 -13 L-4 -9 L-6 -1 V7 L0 12 L6 7 V-1 L4 -9 Z" fill="#111418" stroke="${pri}" stroke-width="1.15"/>
        <path d="M0 -13 V12 M-5 -2 H5" stroke="${sec}" stroke-width="1.0"/>
        <path d="M-5 -2 L-2 1 H-5 M5 -2 L2 1 H5" fill="#050608" stroke="${pri}" stroke-width="0.7"/>
        <!-- Asas gravadas estilo Númenor -->
        <path d="M-5 -5 C-9 -8 -12 -12 -11 -13 C-10 -9 -8 -5 -6 -1" fill="none" stroke="${sec}" stroke-width="1.05"/>
        <path d="M5 -5 C9 -8 12 -12 11 -13 C10 -9 8 -5 6 -1" fill="none" stroke="${sec}" stroke-width="1.05"/>
        <path d="M-9 -7 L-6 -3 M9 -7 L6 -3" stroke="${dim}" stroke-width="0.7"/>`;

    case "spellbook": // Códice de Eärendil (livro angular com estrela de oito raios e fechos)
      return `
        <polygon points="-10,-11 9,-11 11,-9 11,9 9,11 -10,11" fill="#0d0f12" stroke="${pri}" stroke-width="1.1"/>
        <line x1="-6" y1="-11" x2="-6" y2="11" stroke="${sec}" stroke-width="1.0"/>
        <line x1="-10" y1="-5" x2="-6" y2="-5" stroke="${sec}" stroke-width="0.9"/>
        <line x1="-10" y1="5" x2="-6" y2="5" stroke="${sec}" stroke-width="0.9"/>
        <rect x="8" y="-3" width="4" height="6" fill="#0d0f12" stroke="${sec}" stroke-width="0.9"/>
        <!-- Estrela de Eärendil gravada -->
        <polygon points="2,-6 3.2,-1.2 8,0 3.2,1.2 2,6 0.8,1.2 -4,0 0.8,-1.2" fill="none" stroke="${pri}" stroke-width="0.95"/>
        <circle cx="2" cy="0" r="4.5" fill="none" stroke="${sec}" stroke-width="0.6" stroke-dasharray="1.5 2"/>`;

    case "talents": // Árvore Branca & Constelação de Fogo
      return `
        <!-- Raízes e tronco afilado -->
        <path d="M0 11 V-2 M0 8 C-3 10 -7 11 -10 11 M0 8 C3 10 7 11 10 11" fill="none" stroke="${pri}" stroke-width="1.2" stroke-linecap="round"/>
        <!-- Copa de ramos simétricos -->
        <path d="M0 2 C-4 0 -8 -3 -9 -7 M0 2 C4 0 8 -3 9 -7 M0 -2 C-2 -5 -4 -8 -4 -11 M0 -2 C2 -5 4 -8 4 -11" fill="none" stroke="${pri}" stroke-width="1.05" stroke-linecap="round"/>
        <!-- Três estrelas / nós da constelação -->
        <circle cx="0" cy="-11" r="1.7" fill="${pri}"/>
        <circle cx="-9" cy="-7" r="1.4" fill="${sec}"/>
        <circle cx="9" cy="-7" r="1.4" fill="${sec}"/>
        <circle cx="0" cy="-3" r="6.8" fill="none" stroke="${sec}" stroke-width="0.65" stroke-dasharray="2 2.5"/>`;

    case "drops": // Relicário / Cofre de Ferro Forjado
      return `
        <polygon points="-9,-5 0,-11 9,-5 9,9 -9,9" fill="#0e1013" stroke="${pri}" stroke-width="1.1"/>
        <line x1="-9" y1="-2" x2="9" y2="-2" stroke="${sec}" stroke-width="1.0"/>
        <line x1="-5" y1="-7.5" x2="-5" y2="9" stroke="${dim}" stroke-width="0.9"/>
        <line x1="5" y1="-7.5" x2="5" y2="9" stroke="${dim}" stroke-width="0.9"/>
        <polygon points="${diamondPts(0, 1, 3.2, 4.4)}" fill="#08090b" stroke="${sec}" stroke-width="1.0"/>
        <circle cx="0" cy="1" r="1.1" fill="${pri}"/>`;

    case "dungeons": // Portão das Minas / Arco de Moria com Lâminas
      return `
        <path d="M-10 11 V-1 C-10 -9 0 -13 0 -13 C0 -13 10 -9 10 -1 V11" fill="#0b0c0e" stroke="${pri}" stroke-width="1.15"/>
        <path d="M-7 11 V0 C-7 -6 0 -9.5 0 -9.5 C0 -9.5 7 -6 7 0 V11" fill="none" stroke="${sec}" stroke-width="0.8"/>
        <line x1="-3.5" y1="-7" x2="-3.5" y2="11" stroke="${dim}" stroke-width="0.8"/>
        <line x1="3.5" y1="-7" x2="3.5" y2="11" stroke="${dim}" stroke-width="0.8"/>
        <line x1="-8" y1="2" x2="8" y2="2" stroke="${dim}" stroke-width="0.8"/>
        <!-- Espada / marca sombria central -->
        <polygon points="0,-6 1.8,1 0,8 -1.8,1" fill="${sec}" stroke="${pri}" stroke-width="0.6"/>`;

    case "achievements": // Estrela de Sete Pontas & Coroa de Ferro
      return `
        <circle cx="0" cy="1" r="9.5" fill="none" stroke="${sec}" stroke-width="0.8" stroke-dasharray="3 2"/>
        <polygon points="0,-10 2.1,-2.6 9.5,-2.4 3.6,2.1 5.8,9.2 0,4.9 -5.8,9.2 -3.6,2.1 -9.5,-2.4 -2.1,-2.6" fill="none" stroke="${pri}" stroke-width="1.1"/>
        <polygon points="${diamondPts(0, 1, 2.5, 2.5)}" fill="${sec}"/>`;

    case "quests": // Adaga / Pena Cravada em Contrato de Expedição
      return `
        <polygon points="-7,-10 7,-10 7,9 0,12 -7,9" fill="#0d0f12" stroke="${pri}" stroke-width="1.05"/>
        <line x1="-4" y1="-5" x2="4" y2="-5" stroke="${dim}" stroke-width="0.8"/>
        <line x1="-4" y1="-1" x2="4" y2="-1" stroke="${dim}" stroke-width="0.8"/>
        <line x1="-4" y1="3" x2="1" y2="3" stroke="${dim}" stroke-width="0.8"/>
        <!-- Adaga fina cravada em diagonal -->
        <line x1="9" y1="-11" x2="-3" y2="5" stroke="${pri}" stroke-width="1.4" stroke-linecap="round"/>
        <line x1="3.5" y1="-8.5" x2="7.5" y2="-4.5" stroke="${sec}" stroke-width="1.2"/>`;

    case "social": // Lâminas Cruzadas de Irmandade sob Anel
      return `
        <circle cx="0" cy="-2" r="7.5" fill="none" stroke="${dim}" stroke-width="0.85"/>
        <line x1="-9" y1="10" x2="9" y2="-10" stroke="${pri}" stroke-width="1.3" stroke-linecap="round"/>
        <line x1="9" y1="10" x2="-9" y2="-10" stroke="${pri}" stroke-width="1.3" stroke-linecap="round"/>
        <line x1="-8" y1="4.5" x2="-4.5" y2="8" stroke="${sec}" stroke-width="1.2"/>
        <line x1="8" y1="4.5" x2="4.5" y2="8" stroke="${sec}" stroke-width="1.2"/>
        <polygon points="${diamondPts(0, 0, 2.4, 2.4)}" fill="${sec}"/>`;

    case "guild": // Brasão Chanfrado com Estandarte Vertical
      return `
        <polygon points="-8,-10 8,-10 9,2 0,12 -9,2" fill="#0d0f12" stroke="${pri}" stroke-width="1.15"/>
        <polygon points="-5,-7 5,-7 6,1 0,8 -6,1" fill="none" stroke="${sec}" stroke-width="0.75"/>
        <line x1="0" y1="-7" x2="0" y2="8" stroke="${pri}" stroke-width="1.0"/>
        <polygon points="${diamondPts(0, -1, 3.2, 3.2)}" fill="none" stroke="${sec}" stroke-width="1.0"/>`;

    case "lfd": // Farol de Vigília / Pira de Gondor Acesa
      return `
        <polygon points="-7,11 -4,4 4,4 7,11" fill="#0d0f12" stroke="${pri}" stroke-width="1.05"/>
        <line x1="-9" y1="4" x2="9" y2="4" stroke="${sec}" stroke-width="1.2"/>
        <!-- Chama esculpida angular -->
        <path d="M0 -12 C3 -7 6 -3 4 3 C2 1 1 -1 0 -3 C-1 -1 -2 1 -4 3 C-6 -3 -3 -7 0 -12 Z" fill="none" stroke="${pri}" stroke-width="1.15"/>
        <polygon points="${diamondPts(0, -1, 2.2, 4.2)}" fill="${sec}"/>`;

    case "collections": // Perfil de Corcel de Rohan em Traço Fino
      return `
        <path d="M-5 11 L-4 2 L-8 -1 L-3 -9 L3 -11 L5 -7 L10 -5 L8 -1 L3 -2 L4 5 L6 11" fill="#0d0f12" stroke="${pri}" stroke-width="1.15" stroke-linejoin="round"/>
        <path d="M-3 -9 C-8 -6 -9 0 -6 6" fill="none" stroke="${sec}" stroke-width="1.1"/>
        <path d="M0 -7 L6 -4" stroke="${dim}" stroke-width="0.8"/>
        <circle cx="3.5" cy="-6.5" r="0.9" fill="${pri}"/>`;

    case "toggle": // Fecho de Astrolábio / Agulha Dupla
      return `
        <polygon points="${diamondPts(0, 0, 5.5, 9)}" fill="none" stroke="${AUL}" stroke-width="1.15"/>
        <line x1="-7" y1="0" x2="7" y2="0" stroke="${EMB}" stroke-width="1.0"/>
        <circle cx="0" cy="0" r="2.0" fill="${EMBL}"/>`;

    case "map": // Bússola / Astrolábio de 8 Agulhas (Assinatura New World)
      return `
        <circle cx="0" cy="0" r="10.5" fill="none" stroke="${sec}" stroke-width="0.85"/>
        <circle cx="0" cy="0" r="7.5" fill="none" stroke="${dim}" stroke-width="0.6" stroke-dasharray="1.5 2"/>
        <polygon points="0,-12 1.8,-1.8 12,0 1.8,1.8 0,12 -1.8,1.8 -12,0 -1.8,-1.8" fill="none" stroke="${pri}" stroke-width="1.05"/>
        <line x1="-6" y1="-6" x2="6" y2="6" stroke="${sec}" stroke-width="0.75"/>
        <line x1="6" y1="-6" x2="-6" y2="6" stroke="${sec}" stroke-width="0.75"/>
        <circle cx="0" cy="0" r="1.8" fill="${sec}"/>`;

    case "help": // Arco Ogival com Estrela-Guia
      return `
        <path d="M-7 10 V-1 C-7 -7 0 -11 0 -11 C0 -11 7 -7 7 -1 V10" fill="none" stroke="${sec}" stroke-width="1.0"/>
        <line x1="-9" y1="10" x2="9" y2="10" stroke="${pri}" stroke-width="1.1"/>
        <polygon points="0,-7 1.3,-1.3 6,0 1.3,1.3 0,6 -1.3,1.3 -6,0 -1.3,-1.3" fill="none" stroke="${pri}" stroke-width="1.0"/>`;

    case "menu": // Roda de Astrolábio & Engrenagem Fina
      return `
        <circle cx="0" cy="0" r="9.5" fill="none" stroke="${pri}" stroke-width="1.8" stroke-dasharray="2.4 2.2"/>
        <circle cx="0" cy="0" r="6.8" fill="#0b0d10" stroke="${sec}" stroke-width="1.0"/>
        <line x1="0" y1="-6.8" x2="0" y2="6.8" stroke="${dim}" stroke-width="0.8"/>
        <line x1="-6.8" y1="0" x2="6.8" y2="0" stroke="${dim}" stroke-width="0.8"/>
        <polygon points="${diamondPts(0, 0, 2.8, 2.8)}" fill="${pri}"/>`;
  }
  return "";
}

const MAIN_BTNS = [
  { key: "character",    name: "Personagem" },
  { key: "spellbook",    name: "Códice" },
  { key: "talents",      name: "Maestria", badge: "3", active: true },
  { key: "drops",        name: "Relicário" },
  { key: "dungeons",     name: "Masmorras" },
  { key: "achievements", name: "Feitos" },
  { key: "quests",       name: "Contratos", badge: "12" },
  { key: "social",       name: "Irmandade", badge: "4" },
  { key: "guild",        name: "Companhia", badge: "9" },
  { key: "lfd",          name: "Expedições" },
  { key: "collections",  name: "Montarias" },
];
const SYS_BTNS = [
  { key: "map",  name: "Mapa" },
  { key: "help", name: "Guia" },
  { key: "menu", name: "Sistema" },
];

// ------------------------------------------------------------------ Fundo Dark Cinematográfico
function drawBackground() {
  // Grande astrolábio cartográfico fantasma de New World ao fundo
  const astrolabe = (cx, cy, R, op) => {
    let s = `<g opacity="${op}" fill="none" stroke="${AU}">`;
    for (const [r, w, dash] of [[R, 1.0, ""], [R * 0.92, 0.5, "2 6"], [R * 0.72, 0.7, ""], [R * 0.45, 0.5, "4 6"]]) {
      s += `<circle cx="${cx}" cy="${cy}" r="${f(r)}" stroke-width="${w}" ${dash ? `stroke-dasharray="${dash}"` : ""}/>`;
    }
    for (let d = 0; d < 360; d += 5) {
      const len = d % 30 === 0 ? 14 : (d % 15 === 0 ? 8 : 4);
      const [x1, y1] = at(cx, cy, R, d), [x2, y2] = at(cx, cy, R - len, d);
      s += `<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke-width="${d % 30 === 0 ? 0.8 : 0.4}"/>`;
    }
    for (let i = 0; i < 16; i++) {
      const [rx, ry] = at(cx, cy, R * 0.82, i * 22.5);
      s += elvenRune(rx, ry, i, i * 22.5, AU, 0.85, 0.9);
    }
    return s + `</g>`;
  };

  return `
  <rect width="${W}" height="${H}" fill="url(#darkBg)"/>
  <rect width="${W}" height="${H}" filter="url(#slateGrain)" opacity="0.55"/>
  ${astrolabe(720, 560, 440, 0.075)}
  ${astrolabe(1280, 120, 240, 0.055)}
  <ellipse cx="720" cy="560" rx="580" ry="120" fill="url(#forgeAura)" opacity="0.20"/>
  <ellipse cx="385" cy="400" rx="280" ry="140" fill="url(#forgeAura)" opacity="0.14"/>
  <rect width="${W}" height="${H}" fill="url(#vignette)"/>`;
}

function drawHeader() {
  return `
  <g transform="translate(720, 36)">
    <text x="0" y="0" text-anchor="middle" font-family="Cinzel, Georgia, serif" font-size="11.5" letter-spacing="6" fill="${AU}" opacity="0.9">NEW WORLD  ×  TERRA-MÉDIA  ·  DIREÇÃO DE ARTE SOMBRIA</text>
    <text x="0" y="26" text-anchor="middle" font-family="Cinzel, Georgia, serif" font-size="22" font-weight="600" letter-spacing="4" fill="${TXT}">FORJA DE NÚMENOR &amp; ASTROLÁBIO</text>
    <line x1="-340" y1="38" x2="-22" y2="38" stroke="url(#goldHairH)" stroke-width="0.9"/>
    <line x1="22" y1="38" x2="340" y2="38" stroke="url(#goldHairH)" stroke-width="0.9"/>
    <polygon points="${diamondPts(0, 38, 12, 3.5)}" fill="none" stroke="${AUL}" stroke-width="0.8"/>
    <g filter="url(#glowEmber)">${emberShard(0, 38, 3.8, 3.8)}</g>
  </g>`;
}

// ------------------------------------------------------------------ Seção 1: Gravuras a Buril (Vitrine Close-up)
function drawEtchingShowcase() {
  const cy = 148;
  const items = [
    { key: "character",    title: "Guarda de Gondor" },
    { key: "spellbook",    title: "Códice Eärendil" },
    { key: "talents",      title: "Árvore Branca", active: true },
    { key: "dungeons",     title: "Arco de Moria" },
    { key: "quests",       title: "Contrato & Adaga" },
    { key: "lfd",          title: "Pira de Vigília" },
    { key: "collections",  title: "Corcel de Rohan" },
    { key: "map",          title: "Astrolábio" },
    { key: "menu",         title: "Roda de Precisão" },
  ];

  let s = `
  <g>
    <text x="80" y="${cy - 40}" font-family="Cinzel, Georgia, serif" font-size="11" letter-spacing="2.8" fill="${AUL}">1. GLIFOS GRAVADOS A BURIL — PRATA DE MITHRIL &amp; OURO OXIDADO</text>
    <line x1="80" y1="${cy - 32}" x2="640" y2="${cy - 32}" stroke="url(#goldHairH)" stroke-width="0.7" opacity="0.7"/>
    <polygon points="74,${cy - 24} 1366,${cy - 24} 1374,${cy - 16} 1374,${cy + 44} 1366,${cy + 52} 74,${cy + 52} 66,${cy + 44} 66,${cy - 16}"
             fill="#080a0c" fill-opacity="0.8" stroke="${AUD}" stroke-width="0.9"/>
  `;

  items.forEach((it, i) => {
    const cx = 142 + i * 144;
    s += `<polygon points="${octPts(cx, cy + 4, 21, 0.42)}" fill="${it.active ? "url(#emberWell)" : "#0d0f13"}" stroke="${it.active ? EMB : AUD}" stroke-width="${it.active ? 1.1 : 0.8}"/>`;
    s += `<g transform="translate(${cx} ${cy + 4}) scale(1.22)">${etchedIcon(it.key, it.active)}</g>`;
    s += `<text x="${cx}" y="${cy + 40}" text-anchor="middle" font-family="Cinzel, Georgia, serif" font-size="10" letter-spacing="0.6" fill="${it.active ? EMBL : SILVER}">${it.title}</text>`;
  });
  s += `</g>`;
  return s;
}

// ------------------------------------------------------------------ Engaste Chanfrado & Arco Ogival (Botão Individual)
function drawNumenorSocket(cx, cy, b, isSys = false) {
  const active = !!b.active;
  const r = 21;

  let s = `<g>`;

  // Foco ativo: Anel de Inscrição Élfica em Brasa + Lâmina Vertical de Luz (New World compass marker)
  if (active) {
    s += `<circle cx="${cx}" cy="${cy}" r="${r + 24}" fill="url(#emberHalo)" opacity="0.85"/>`;
    // Lâmina vertical atravessando o engaste
    s += `<line x1="${cx}" y1="${cy - 44}" x2="${cx}" y2="${cy + 36}" stroke="url(#emberBeamV)" stroke-width="1.3"/>`;
    // Inscrição circular fina estilo Anel de Fogo
    s += `<circle cx="${cx}" cy="${cy}" r="${r + 9}" fill="none" stroke="${EMB}" stroke-width="0.85" opacity="0.9"/>`;
    s += `<circle cx="${cx}" cy="${cy}" r="${r + 12}" fill="none" stroke="${EMBL}" stroke-width="0.5" stroke-dasharray="3 4" opacity="0.6"/>`;
    for (let i = 0; i < 10; i++) {
      const [rx, ry] = at(cx, cy, r + 9, i * 36 + 18);
      s += elvenRune(rx, ry, i, i * 36 + 18, EMBL, 0.48, 0.95);
    }
    // Micro-cinzas subindo
    s += `<circle cx="${cx - 16}" cy="${cy - 27}" r="1.0" fill="${EMBL}" filter="url(#glowEmber)"/>`;
    s += `<circle cx="${cx + 18}" cy="${cy - 23}" r="0.85" fill="${EMB}" filter="url(#glowEmber)"/>`;
  }

  // Arco ogival élfico sutil atrás do engaste
  s += `<path d="M${cx - 22} ${cy + 14} V${cy - 10} C${cx - 22} ${cy - 20} ${cx} ${cy - 28} ${cx} ${cy - 28} C${cx} ${cy - 28} ${cx + 22} ${cy - 20} ${cx + 22} ${cy - 10} V${cy + 14}"
        fill="none" stroke="${active ? EMB : AUD}" stroke-width="0.8" opacity="${active ? 0.85 : 0.55}"/>`;

  // Engaste octogonal chanfrado (ou losangular sutil para sistema)
  const framePts = isSys ? octPts(cx, cy, r, 0.52) : octPts(cx, cy, r, 0.36);
  const innerPts = isSys ? octPts(cx, cy, r - 3, 0.52) : octPts(cx, cy, r - 3, 0.36);

  s += `<polygon points="${framePts}" fill="${active ? "url(#emberWell)" : "#0b0d10"}" stroke="${active ? "url(#emberGold)" : "url(#antiqueGold)"}" stroke-width="${active ? 1.5 : 1.05}"/>`;
  s += `<polygon points="${innerPts}" fill="none" stroke="${active ? EMB : AUD}" stroke-width="0.65" opacity="0.85"/>`;

  // Glifo gravado
  s += `<g transform="translate(${cx} ${cy}) scale(0.98)" ${active ? 'filter="url(#glowEmber)"' : ""}>${etchedIcon(b.key, active)}</g>`;

  // Indicador de ativo na base: estilhaço de brasa vertical
  if (active) {
    s += `<g filter="url(#glowEmber)">${emberShard(cx, cy + r + 2, 3.8, 5.2)}</g>`;
  }

  // Badge numérica sóbria (losango escuro de bronze oxidado, zero cartoon!)
  if (b.badge) {
    const bx = cx + r * 0.78, by = cy + r * 0.74;
    s += `<polygon points="${diamondPts(bx, by, 9.5, 9.5)}" fill="#07080a" stroke="${AU}" stroke-width="0.95"/>`;
    s += `<polygon points="${diamondPts(bx, by, 7.2, 7.2)}" fill="none" stroke="${AUD}" stroke-width="0.5"/>`;
    s += `<text x="${bx}" y="${by + 3.1}" text-anchor="middle" font-family="Cinzel, Georgia, serif" font-size="8.8" font-weight="700" fill="${AUB}">${b.badge}</text>`;
  }

  s += `</g>`;
  return s;
}

// ------------------------------------------------------------------ Agulha de Astrolábio Central (Toggle)
function drawAstrolabeToggle(cx, cy, collapsed = false) {
  return `<g>
    <circle cx="${cx}" cy="${cy}" r="26" fill="url(#emberHalo)" opacity="0.28"/>
    <line x1="${cx}" y1="${cy - 34}" x2="${cx}" y2="${cy + 34}" stroke="url(#goldHairV)" stroke-width="1.0"/>
    <polygon points="${diamondPts(cx, cy, 17, 27)}" fill="#0a0c0f" stroke="url(#antiqueGold)" stroke-width="1.35"/>
    <polygon points="${diamondPts(cx, cy, 13, 21)}" fill="url(#emberWell)" stroke="${AUD}" stroke-width="0.8"/>
    <g transform="translate(${cx} ${cy}) rotate(${collapsed ? 90 : 0}) scale(0.95)">${etchedIcon("toggle", true)}</g>
    <polygon points="${diamondPts(cx, cy - 31, 2.5, 3.5)}" fill="${AUL}"/>
    <polygon points="${diamondPts(cx, cy + 31, 2.5, 3.5)}" fill="${AUL}"/>
  </g>`;
}

// ------------------------------------------------------------------ Régua Arquitetônica New World × Númenor
function drawDarkDock(cx, cy, mainList, sysList, collapsed = false) {
  const step = 58, gapToggle = 16;
  const mainW = mainList.length ? (mainList.length - 1) * step + 48 : 0;
  const sysW = (sysList.length - 1) * step + 48;
  const span = mainW + (mainList.length ? gapToggle * 2 : 0) + sysW;
  const leftX = cx - span / 2 - 24;
  const rightX = cx + span / 2 + 24;
  const dockW = rightX - leftX;
  const dockH = 48;

  let s = `<g>`;
  // Sombra profunda
  s += `<rect x="${leftX}" y="${cy - dockH / 2 + 6}" width="${dockW}" height="${dockH}" fill="#000" opacity="0.82" filter="url(#softBlur)"/>`;

  // Ponteiras afiadas em lança de New World (longas, finas e escuras)
  const spearTip = (edgeX, dir) => `
    <polygon points="${edgeX},${cy - 22} ${edgeX + dir * 24},${cy - 14} ${edgeX + dir * 74},${cy} ${edgeX + dir * 24},${cy + 14} ${edgeX},${cy + 22}"
             fill="#0a0c0e" stroke="url(#antiqueGold)" stroke-width="1.2"/>
    <polyline points="${edgeX + dir * 4},${cy - 12} ${edgeX + dir * 54},${cy} ${edgeX + dir * 4},${cy + 12}"
              fill="none" stroke="${AUD}" stroke-width="0.8"/>
    <line x1="${edgeX + dir * 24}" y1="${cy}" x2="${edgeX + dir * 82}" y2="${cy}" stroke="url(#goldHairH)" stroke-width="0.8"/>
    <g filter="url(#glowEmber)">${emberShard(edgeX + dir * 20, cy, 4.2, 4.2)}</g>
  `;
  s += spearTip(leftX + 2, -1);
  s += spearTip(rightX - 2, 1);

  // Lâmina de ardósia negra chanfrada
  s += `<polygon points="${leftX + 8},${cy - dockH / 2} ${rightX - 8},${cy - dockH / 2} ${rightX},${cy - dockH / 2 + 8} ${rightX},${cy + dockH / 2 - 8} ${rightX - 8},${cy + dockH / 2} ${leftX + 8},${cy + dockH / 2} ${leftX},${cy + dockH / 2 - 8} ${leftX},${cy - dockH / 2 + 8}"
        fill="url(#slateBar)" stroke="url(#antiqueGold)" stroke-width="1.35"/>`;
  s += `<rect x="${leftX + 10}" y="${cy - dockH / 2 + 3.5}" width="${dockW - 20}" height="${dockH - 7}" fill="none" stroke="${AUD}" stroke-width="0.7"/>`;

  // Régua de graduação cartográfica de New World na borda superior/inferior
  for (let tx = leftX + 24; tx < rightX - 24; tx += 12) {
    const big = ((tx - leftX) % 48) < 12;
    s += `<line x1="${tx}" y1="${cy - dockH / 2 + 1}" x2="${tx}" y2="${cy - dockH / 2 + (big ? 5 : 3)}" stroke="${AU}" stroke-width="0.6" opacity="0.55"/>`;
    s += `<line x1="${tx}" y1="${cy + dockH / 2 - 1}" x2="${tx}" y2="${cy + dockH / 2 - (big ? 5 : 3)}" stroke="${AU}" stroke-width="0.6" opacity="0.45"/>`;
  }

  let curX = leftX + 24 + 24;
  let activePos = null;

  if (mainList.length) {
    mainList.forEach((b) => {
      s += drawNumenorSocket(curX, cy, b, false);
      if (b.active) activePos = { x: curX, y: cy };
      curX += step;
    });
    curX = curX - step + 24 + gapToggle;
  }

  const toggleX = curX;
  s += drawAstrolabeToggle(toggleX, cy, collapsed);
  curX += gapToggle + 24;

  sysList.forEach((b) => {
    s += drawNumenorSocket(curX, cy, b, true);
    curX += step;
  });

  s += `</g>`;
  return { svg: s, activePos, leftX, rightX, toggleX };
}

// ------------------------------------------------------------------ Placar Sóbrio New World × Terra-média (Ardósia Negra)
function drawDarkPlacard(cx, bottomY, data) {
  const pw = data.w || 396, ph = data.h || 132;
  const x = cx - pw / 2, y = bottomY - ph;
  const beamX = data.beamX || cx;

  // Cantoneira fina chanfrada estilo Númenor
  const numenorCorner = (px, py, sx, sy) => `
    <g transform="translate(${px} ${py}) scale(${sx} ${sy})">
      <path d="M0 16 V6 L6 0 H16" fill="none" stroke="${AUL}" stroke-width="1.15"/>
      <path d="M4 13 V7 L7 4 H13" fill="none" stroke="${AUD}" stroke-width="0.7"/>
      <polygon points="${diamondPts(5.5, 5.5, 1.8, 1.8)}" fill="${AUL}"/>
    </g>`;

  return `<g>
    ${data.showBeam !== false ? `
    <line x1="${beamX}" y1="${bottomY + 18}" x2="${beamX}" y2="${bottomY}" stroke="url(#emberBeamV)" stroke-width="1.3"/>
    <g filter="url(#glowEmber)">${emberShard(beamX, bottomY + 1, 3.8, 3.8)}</g>` : ""}

    <!-- Sombra -->
    <rect x="${x + 4}" y="${y + 8}" width="${pw}" height="${ph}" fill="#000" opacity="0.88" filter="url(#softBlur)"/>

    <!-- Placa de ardósia fosca com cantos chanfrados -->
    <polygon points="${x + 9},${y} ${x + pw - 9},${y} ${x + pw},${y + 9} ${x + pw},${y + ph - 9} ${x + pw - 9},${y + ph} ${x + 9},${y + ph} ${x},${y + ph - 9} ${x},${y + 9}"
             fill="url(#slatePlacard)" stroke="url(#antiqueGold)" stroke-width="1.2"/>
    <rect x="${x + 4}" y="${y + 4}" width="${pw - 8}" height="${ph - 8}" fill="none" stroke="${AUD}" stroke-width="0.65"/>

    <!-- Crista / ponta de lança superior (Assinatura New World) -->
    <line x1="${x + 28}" y1="${y}" x2="${x + pw - 28}" y2="${y}" stroke="url(#goldHairH)" stroke-width="1.1"/>
    <polygon points="${diamondPts(x + pw / 2, y, 16, 4.5)}" fill="#0b0d10" stroke="${AUL}" stroke-width="0.9"/>
    <g filter="url(#glowEmber)">${emberShard(x + pw / 2, y, 3.5, 3.5)}</g>

    ${numenorCorner(x, y, 1, 1)}
    ${numenorCorner(x + pw, y, -1, 1)}
    ${numenorCorner(x, y + ph, 1, -1)}
    ${numenorCorner(x + pw, y + ph, -1, -1)}

    <!-- Cabeçalho -->
    <rect x="${x + 5}" y="${y + 5}" width="${pw - 10}" height="34" fill="url(#slateHeader)"/>
    <g transform="translate(${x + 26} ${y + 23}) scale(0.82)">${etchedIcon(data.icon, true)}</g>
    <text x="${x + 44}" y="${y + 27}" font-family="Cinzel, Georgia, serif" font-size="13" font-weight="600" letter-spacing="1.4" fill="${AUB}">${data.title}</text>

    <!-- Keycap em losango chanfrado -->
    <polygon points="${x + pw - 58},${y + 13} ${x + pw - 16},${y + 13} ${x + pw - 12},${y + 22} ${x + pw - 16},${y + 31} ${x + pw - 58},${y + 31} ${x + pw - 62},${y + 22}"
             fill="#0a0c0f" stroke="${AU}" stroke-width="0.9"/>
    <text x="${x + pw - 37}" y="${y + 26}" text-anchor="middle" font-family="Cinzel, Georgia, serif" font-size="10.5" font-weight="600" fill="${EMBL}">${data.key}</text>

    <!-- Divisor ultrafino com agulha central -->
    <line x1="${x + 18}" y1="${y + 41}" x2="${x + pw - 18}" y2="${y + 41}" stroke="url(#goldHairH)" stroke-width="0.8"/>
    <polygon points="${diamondPts(x + pw / 2, y + 41, 6, 2.2)}" fill="${AUL}"/>

    <!-- Descrição e status -->
    <text x="${x + 18}" y="${y + 62}" font-family="Segoe UI, sans-serif" font-size="12" fill="${SILVER}">${data.desc1}</text>
    <text x="${x + 18}" y="${y + 79}" font-family="Segoe UI, sans-serif" font-size="12" fill="${SILVER}">${data.desc2}</text>

    <text x="${x + 18}" y="${y + 103}" font-family="Cinzel, Georgia, serif" font-size="11.5" font-weight="600" letter-spacing="0.5" fill="${EMBL}">${data.status}</text>
    <text x="${x + 18}" y="${y + 119}" font-family="Segoe UI, sans-serif" font-size="10.5" fill="${MUTED}">${data.hint}</text>
  </g>`;
}

// ------------------------------------------------------------------ Seção 2: Barra Completa + Placar
function drawHeroSection() {
  const dockY = 556;
  const dock = drawDarkDock(720, dockY, MAIN_BTNS, SYS_BTNS, false);

  const placard = drawDarkPlacard(dock.activePos.x + 65, dockY - 70, {
    w: 404,
    h: 132,
    beamX: dock.activePos.x,
    icon: "talents",
    title: "MAESTRIA & TALENTOS",
    key: "[N]",
    desc1: "Forje sua maestria, distribua pontos de talento",
    desc2: "e desbloqueie caminhos no Crisol de Azaath.",
    status: "Pontos disponíveis: 3",
    hint: "Clique direito: Janela padrão do jogo",
  });

  const callout = (x1, y1, x2, y2, anchor, title, sub) => `
    <g opacity="0.92">
      <polyline points="${x1},${y1} ${x2},${y2}" fill="none" stroke="${AUD}" stroke-width="0.85" stroke-dasharray="2 3"/>
      <circle cx="${x1}" cy="${y1}" r="2.0" fill="${EMBL}"/>
      <text x="${x2 + (anchor === "start" ? 6 : -6)}" y="${y2 - 2}" text-anchor="${anchor}" font-family="Cinzel, Georgia, serif" font-size="10.5" font-weight="600" letter-spacing="0.8" fill="${AUL}">${title}</text>
      <text x="${x2 + (anchor === "start" ? 6 : -6)}" y="${y2 + 12}" text-anchor="${anchor}" font-family="Segoe UI, sans-serif" font-size="10.2" fill="${MUTED}">${sub}</text>
    </g>`;

  const talX = dock.activePos.x;
  const questsX = talX + 4 * 58;

  return `
  <g>
    <text x="80" y="252" font-family="Cinzel, Georgia, serif" font-size="11.5" letter-spacing="2.8" fill="${AUL}">2. RÉGUA DE ARDÓSIA, ARCOS ÉLFICOS &amp; FOCO EM BRASA (EXPANDIDA)</text>
    <line x1="80" y1="260" x2="720" y2="260" stroke="url(#goldHairH)" stroke-width="0.7" opacity="0.75"/>

    ${dock.svg}
    ${placard}

    ${callout(dock.leftX - 48, dockY, 80, 646, "start", "PONTEIRAS DE LANÇA", "Aço escuro, linhas de bronze e brasa contida")}
    ${callout(talX - 10, dockY + 26, 360, 646, "start", "INSCRIÇÃO DE FORJA", "Anel rúnico incandescente + agulha vertical")}
    ${callout(questsX + 16, dockY + 18, 665, 646, "start", "LOSANGOS DE BRONZE", "Badges sóbrias sem poluição de cor")}
    ${callout(dock.toggleX, dockY + 32, 955, 646, "start", "AGULHA DE ASTROLÁBIO", "Divisor cirúrgico para recolher os 11 atalhos")}
    ${callout(dock.rightX - 75, dockY - 24, 1020, 425, "start", "ENGASTES DE SISTEMA", "Mapa, Guia e Sistema em octógono duplo")}
    ${callout(dock.activePos.x + 271, dockY - 134, 725, 355, "start", "PLACAR DE ARDÓSIA NEGRA", "Crista New World, chanfros 45° e ouro oxidado")}
  </g>`;
}

// ------------------------------------------------------------------ Seção 3: Modo Recolhido + Placar de Sistema
function drawCollapsedSection() {
  const cy = 786;
  const dock = drawDarkDock(320, cy, [], SYS_BTNS, true);

  const sysPlacard = drawDarkPlacard(995, cy + 44, {
    w: 412,
    h: 130,
    showBeam: false,
    icon: "menu",
    title: "CONFIGURAR JOGO",
    key: "[ESC]",
    desc1: "Acesse as opções gráficas, áudio, mapeamento de teclas",
    desc2: "e ajustes da interface completa AzaathUI.",
    status: "FPS: 144    Latência: 18 ms",
    hint: "Clique direito: Opções AzaathUI (/azaath)",
  });

  return `
  <g>
    <text x="80" y="698" font-family="Cinzel, Georgia, serif" font-size="11" letter-spacing="2.8" fill="${AUL}">3. MODO RECOLHIDO &amp; PLACAR DE SISTEMA</text>
    <line x1="80" y1="706" x2="540" y2="706" stroke="url(#goldHairH)" stroke-width="0.7" opacity="0.65"/>
    ${dock.svg}
    <text x="320" y="${cy + 54}" text-anchor="middle" font-family="Segoe UI, sans-serif" font-size="10.5" fill="${MUTED}">Silhueta mínima no canto da tela quando recolhida</text>
    ${sysPlacard}
  </g>`;
}

// ------------------------------------------------------------------ Montagem SVG
const body = `
<defs>
  <linearGradient id="darkBg" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#0b0d10"/><stop offset="0.5" stop-color="#060708"/><stop offset="1" stop-color="#030405"/>
  </linearGradient>
  <filter id="slateGrain" x="0%" y="0%" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.03 0.05" numOctaves="4" seed="31"/>
    <feColorMatrix values="0 0 0 0 0.14  0 0 0 0 0.15  0 0 0 0 0.17  0 0 0 0.16 -0.03"/>
  </filter>
  <radialGradient id="forgeAura" cx=".5" cy=".5" r=".5">
    <stop offset="0" stop-color="${EMB}" stop-opacity="0.45"/><stop offset="1" stop-color="${EMB}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="emberHalo" cx=".5" cy=".5" r=".5">
    <stop offset="0" stop-color="${EMBL}" stop-opacity="0.55"/><stop offset=".45" stop-color="${EMB}" stop-opacity="0.22"/><stop offset="1" stop-color="${EMB}" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="vignette" cx=".5" cy=".5" r=".72">
    <stop offset=".5" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity="0.82"/>
  </radialGradient>
  <filter id="glowEmber" x="-60%" y="-60%" width="220%" height="220%">
    <feGaussianBlur stdDeviation="2.0" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="softBlur" x="-30%" y="-30%" width="160%" height="160%">
    <feGaussianBlur stdDeviation="6"/>
  </filter>
  <linearGradient id="antiqueGold" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${AUL}"/><stop offset="0.45" stop-color="${AU}"/><stop offset="1" stop-color="${AUD}"/>
  </linearGradient>
  <linearGradient id="emberGold" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${EMBL}"/><stop offset="0.5" stop-color="${EMB}"/><stop offset="1" stop-color="${AU}"/>
  </linearGradient>
  <linearGradient id="goldHairH" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="${AU}" stop-opacity="0"/><stop offset="0.5" stop-color="${AUL}" stop-opacity="1"/><stop offset="1" stop-color="${AU}" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="goldHairV" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${AU}" stop-opacity="0"/><stop offset="0.5" stop-color="${AUL}" stop-opacity="1"/><stop offset="1" stop-color="${AU}" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="emberBeamV" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="${EMBL}" stop-opacity="0"/><stop offset="0.5" stop-color="${EMB}" stop-opacity="0.85"/><stop offset="1" stop-color="${EMBL}" stop-opacity="0"/>
  </linearGradient>
  <linearGradient id="slateBar" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#14171c" stop-opacity="0.96"/><stop offset="0.5" stop-color="#0b0d10" stop-opacity="0.97"/><stop offset="1" stop-color="#060709" stop-opacity="0.98"/>
  </linearGradient>
  <linearGradient id="slatePlacard" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#121419" stop-opacity="0.97"/><stop offset="1" stop-color="#07080a" stop-opacity="0.98"/>
  </linearGradient>
  <linearGradient id="slateHeader" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="${AU}" stop-opacity="0.14"/><stop offset="1" stop-color="${AU}" stop-opacity="0.01"/>
  </linearGradient>
  <radialGradient id="emberWell" cx=".5" cy=".5" r=".58">
    <stop offset="0" stop-color="${EMB}" stop-opacity="0.28"/><stop offset="1" stop-color="#170b04" stop-opacity="0.96"/>
  </radialGradient>
</defs>
${drawBackground()}
${drawHeader()}
${drawEtchingShowcase()}
${drawHeroSection()}
${drawCollapsedSection()}
`;

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;padding:0;background:#060708;overflow:hidden;width:${W}px;height:${H}px}
</style></head><body><svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">${body}</svg></body></html>`;

const htmlFile = path.join(DIR, "concept-rpg.html");
const outFile = path.join(DIR, "concept-rpg.png");
fs.writeFileSync(htmlFile, html);
if (fs.existsSync(outFile)) fs.unlinkSync(outFile);

const profile = path.join(require("os").tmpdir(), "azaath_micromenu_dark_" + Date.now());
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
console.log("Arte Dark New World × LOTR gerada:", outFile, fs.statSync(outFile).size, "bytes");
