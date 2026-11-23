// Texturas da janela do mapa-múndi (arte de conceito tools/map-ui-concept/concept.webp, 1376x768):
// barra superior, emblema Azaath, busca, botões, borda com cantos em arco, menu lateral (estandarte),
// painel e cartões de missões, ícones de missão, barra de progresso, barra de status inferior, linha
// azul de baixo, pinos de missão no mapa (losango, "?", "!"), anel de seleção e rota.
// Cada peça é desenhada em HTML/SVG, renderizada pelo Edge sem janela (fundo transparente, escala 2)
// e recortada para Media/MapFrame/<nome>.tga (projeto e pasta do jogo).
//   node tools/map-ui-concept/gen.js
"use strict";
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const DIR = __dirname;
const ROOT = path.resolve(DIR, "../..");
const FONTS = "file:///" + path.join(ROOT, "AzaathUI/Media/Fonts").replace(/\\/g, "/");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const OUTS = [path.join(ROOT, "AzaathUI/Media/MapFrame"),
  "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame"];
const SCALE = 2;                         // texels por pixel de interface

// cores da arte
const CY = "#5fe3e6", CY2 = "#2ab7c4", CYD = "#0f5560", GOLD = "#d9b46a", GOLD2 = "#9c7b3c";
const LINE = "#4d8f95", INK = "#0b1013";

// ---------------------------------------------------------------- peças: [nome, largura, altura, html]
const P = [];
const piece = (name, w, h, html) => P.push({ name, w, h, html });
const svg = (w, h, body) => `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg">
<defs>
 <filter id="g1" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="1.2" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
 <filter id="g2" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="2.5" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
 <filter id="g4" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="4" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
</defs>${body}</svg>`;

// borda da janela (9 partes, margem 56), medida na arte: filete ciano por fora e filete creme por
// dentro; nos cantos de baixo o ciano dobra para dentro (arco côncavo) e um arco grande de compasso,
// com um arco pontilhado por fora, liga os dois lados. Em cima não há linha (é a da barra superior).
const FR = 128, FO = 2.5, FI = 8.5;                    // tamanho, filete ciano, filete creme
const frameCorner = (mx, my) => {                      // canto de baixo (mx: 1 esquerda, -1 direita)
  const X = (v) => mx > 0 ? v : FR - v, Y = (v) => FR - v;
  const sweep = mx > 0 ? 1 : 0;      // (arcos com o centro no próprio canto: côncavos, como na arte)
  const dots = [];
  for (let a = 12; a <= 78; a += 5.5) {
    const r = 47, rad = a * Math.PI / 180;
    dots.push(`<circle cx="${X(FO + r * Math.cos(rad))}" cy="${Y(FO + r * Math.sin(rad))}" r=".9" fill="${CY}" opacity=".7"/>`);
  }
  return `<path d="M${X(FO)} 0 V${Y(FO + 19)} A19 19 0 0 ${sweep} ${X(FO + 19)} ${Y(FO)} H${mx > 0 ? FR / 2 : FR / 2}" fill="none" stroke="${CY2}" stroke-width="1.5" filter="url(#g1)"/>
  <path d="M${X(FI)} 0 V${Y(FI)} H${FR / 2}" fill="none" stroke="#d8cfae" stroke-width=".9" opacity=".75"/>
  <path d="M${X(FO)} ${Y(FO + 40)} A40 40 0 0 ${sweep} ${X(FO + 40)} ${Y(FO)}" fill="none" stroke="${CY}" stroke-width="1.1" filter="url(#g1)"/>
  ${dots.join("")}`;
};
piece("Frame", FR, FR, svg(FR, FR, `${frameCorner(1, 1)}${frameCorner(-1, 1)}`));
// compasso do canto superior direito (círculos, anel pontilhado, marcações e a diagonal da arte);
// o centro fica fora da janela, acima e à direita: (CX, CY) nas coordenadas da peça
const CW = 190, CH = 150, CCX = 214, CCY = -26;
const pt = (r, deg) => [CCX + r * Math.cos(deg * Math.PI / 180), CCY + r * Math.sin(deg * Math.PI / 180)];
piece("Compass", CW, CH, svg(CW, CH, `
 <circle cx="${CCX}" cy="${CCY}" r="88" fill="none" stroke="${CY}" stroke-width="1.2" filter="url(#g1)" opacity=".85"/>
 <circle cx="${CCX}" cy="${CCY}" r="80" fill="none" stroke="#bfeff0" stroke-width=".8" opacity=".55"/>
 ${Array.from({ length: 40 }, (_, i) => { const d = 90 + i * 2.6, [x, y] = pt(97, d); return `<circle cx="${x}" cy="${y}" r=".95" fill="${CY}" opacity=".75"/>`; }).join("")}
 ${Array.from({ length: 22 }, (_, i) => { const d = 92 + i * 4.5, a = pt(80, d), b = pt(i % 2 ? 76 : 73, d);
    return `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${CY}" stroke-width=".8" opacity=".6"/>`; }).join("")}
 ${(() => { const a = pt(30, 140), b = pt(130, 140); return `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${CY}" stroke-width=".8" opacity=".6"/>`; })()}
 ${(() => { const a = pt(30, 118), b = pt(120, 118); return `<line x1="${a[0]}" y1="${a[1]}" x2="${b[0]}" y2="${b[1]}" stroke="${CY}" stroke-width=".6" opacity=".35"/>`; })()}`));

// faixa da barra superior (esticada na horizontal): ardósia escura + filete ciano embaixo
piece("TopBar", 8, 46, `<div style="width:8px;height:46px;background:linear-gradient(180deg,#171c1f,#0f1315 70%,#0c1012);
 box-shadow:inset 0 -1px 0 #4fa3a6, 0 1px 6px #5fe3e655"></div>`);

// (o cristal Azaath da barra superior vem recortado da própria arte: extract.js)

// caixa da busca (9 partes, margem 8)
piece("Search", 48, 30, `<div style="width:46px;height:28px;margin:1px;border-radius:5px;border:1px solid #6b777c;
 background:linear-gradient(180deg,#0e1316ee,#0a0e10ee);box-shadow:inset 0 0 6px #000"></div>`);
const icon = (name, body, s = 18) => piece(name, s, s, svg(s, s, body));
icon("IcoSearch", `<circle cx="7.5" cy="7.5" r="5" fill="none" stroke="#a8b2b6" stroke-width="1.6"/><line x1="11.2" y1="11.2" x2="16" y2="16" stroke="#a8b2b6" stroke-width="1.8" stroke-linecap="round"/>`);
icon("IcoMax", `<rect x="3" y="3" width="12" height="12" fill="none" stroke="#dfe5e7" stroke-width="1.6"/>`);
icon("IcoRestore", `<rect x="2.5" y="6" width="9.5" height="9.5" fill="none" stroke="#dfe5e7" stroke-width="1.5"/><path d="M6 6 V2.5 H15.5 V12 H12" fill="none" stroke="#dfe5e7" stroke-width="1.5"/>`);
icon("IcoClose", `<path d="M3.5 3.5 L14.5 14.5 M14.5 3.5 L3.5 14.5" stroke="#dfe5e7" stroke-width="1.7" stroke-linecap="round"/>`);
icon("Dot", `<rect x="6" y="6" width="6" height="6" transform="rotate(45 9 9)" fill="#9aa3a6"/>`);
icon("Check", `<path d="M3 9.5 L7.2 13.5 L15 4.5" fill="none" stroke="${GOLD}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>`);
icon("CheckCyan", `<path d="M3 9.5 L7.2 13.5 L15 4.5" fill="none" stroke="${CY}" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" filter="url(#g1)"/>`);
icon("Box", `<rect x="2.5" y="2.5" width="13" height="13" rx="2" fill="#0b1114" stroke="#5f7c80" stroke-width="1.2"/>`);

// menu lateral (estandarte): topo com arcos de bússola, meio esticável, ponta em V embaixo
const railBody = (h, extra = "") => `<div style="position:relative;width:60px;height:${h}px;overflow:hidden">
 <div style="position:absolute;inset:0 2px 0 0;background:linear-gradient(90deg,#0b1013,#10171b);"></div>
 <div style="position:absolute;top:0;bottom:0;right:1px;width:1px;background:${LINE};box-shadow:0 0 4px #5fe3e688"></div>${extra}</div>`;
// topo do estandarte: o compasso da arte (dois arcos, anel pontilhado, marcações, diagonal e o "60")
piece("RailTop", 60, 96, railBody(96, `<svg style="position:absolute;left:0;top:0" width="60" height="96">
 <defs><filter id="rg" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="1" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>
 <circle cx="-8" cy="-6" r="56" fill="none" stroke="${CY}" stroke-width="1" opacity=".75" filter="url(#rg)"/>
 <circle cx="-8" cy="-6" r="49" fill="none" stroke="#bfeff0" stroke-width=".6" opacity=".4"/>
 ${Array.from({ length: 18 }, (_, i) => { const d = (4 + i * 5) * Math.PI / 180, x = -8 + 63 * Math.cos(d), y = -6 + 63 * Math.sin(d);
    return `<circle cx="${x}" cy="${y}" r=".8" fill="${CY}" opacity=".7"/>`; }).join("")}
 ${Array.from({ length: 16 }, (_, i) => { const d = (6 + i * 5.5) * Math.PI / 180, r1 = 56, r2 = i % 2 ? 53 : 51;
    return `<line x1="${-8 + r1 * Math.cos(d)}" y1="${-6 + r1 * Math.sin(d)}" x2="${-8 + r2 * Math.cos(d)}" y2="${-6 + r2 * Math.sin(d)}" stroke="${CY}" stroke-width=".7" opacity=".55"/>`; }).join("")}
 <line x1="2" y1="4" x2="34" y2="36" stroke="${CY}" stroke-width=".6" opacity=".45"/>
 <line x1="22" y1="0" x2="22" y2="96" stroke="${LINE}" stroke-width=".6" opacity=".35"/>
 <text x="34" y="66" font-family="Seg" font-size="7" fill="${CY}" opacity=".7">60</text>
</svg>`));
piece("RailMid", 60, 8, railBody(8));
piece("RailBot", 60, 60, svg(60, 60, `
 <path d="M0 0 H58 V34 L29 56 L0 34 Z" fill="#0e1519"/>
 <path d="M58.5 0 V34.5 L29 57" fill="none" stroke="${LINE}" stroke-width="1.1" filter="url(#g1)"/>
 <path d="M0 34.5 L29 57" fill="none" stroke="${LINE}" stroke-width="1.1" opacity=".7"/>`));
// item ativo do menu: barra ciano à esquerda e brilho
piece("RailActive", 60, 56, `<div style="position:relative;width:58px;height:56px">
 <div style="position:absolute;inset:0;background:linear-gradient(90deg,#5fe3e64d,#5fe3e614 60%,transparent)"></div>
 <div style="position:absolute;left:0;top:4px;bottom:4px;width:3px;background:#bffcff;box-shadow:0 0 8px ${CY},0 0 16px ${CY}"></div></div>`);
// (os ícones do menu vêm recortados da própria arte: extract.js)

// painel (missões, detalhes, menus): 9 partes, margem 14; levemente arredondado como na arte, com
// um pequeno arco ciano em cada canto
piece("Panel", 64, 64, `<div style="position:relative;width:62px;height:62px;margin:1px;border:1px solid #3f5c62;border-radius:9px;
 background:linear-gradient(180deg,#141c21f2,#0e1418f2);box-shadow:inset 0 0 0 1px #00000088,inset 0 0 18px #000a">
 ${[["left:3px;top:3px", "border-left", "border-top", "border-top-left-radius"], ["right:3px;top:3px", "border-right", "border-top", "border-top-right-radius"],
    ["left:3px;bottom:3px", "border-left", "border-bottom", "border-bottom-left-radius"], ["right:3px;bottom:3px", "border-right", "border-bottom", "border-bottom-right-radius"]]
    .map(([pos, b1, b2, rad]) => `<div style="position:absolute;${pos};width:9px;height:9px;${b1}:1px solid ${CY};${b2}:1px solid ${CY};${rad}:7px;opacity:.75;box-shadow:0 0 3px ${CY}66"></div>`).join("")}
</div>`);
piece("PanelGem", 20, 12, svg(20, 12, `<path d="M10 1 L15 6 L10 11 L5 6 Z" fill="#0e1418" stroke="${CY2}" stroke-width="1"/>
 <path d="M10 4 L12 6 L10 8 L8 6 Z" fill="${CY}" filter="url(#g1)"/><path d="M0 6 H5 M15 6 H20" stroke="${LINE}" stroke-width=".8"/>`));
// filete do título: ciano com ponto brilhante no meio
piece("Rule", 240, 10, svg(240, 10, `<defs><linearGradient id="lg" x1="0" x2="1"><stop offset="0" stop-color="${CY}" stop-opacity="0"/>
 <stop offset=".5" stop-color="${CY}" stop-opacity=".9"/><stop offset="1" stop-color="${CY}" stop-opacity="0"/></linearGradient></defs>
 <rect x="0" y="4.5" width="240" height="1.2" fill="url(#lg)" filter="url(#g1)"/><ellipse cx="120" cy="5" rx="7" ry="2.2" fill="#dffcff" filter="url(#g2)"/>`));
// cartão de missão (9 partes, margem 10): filete duplo bronze-cinza; selecionado: ciano
const card = (name, out, inn, glow) => piece(name, 48, 48, `<div style="width:46px;height:46px;margin:1px;border:1px solid ${out};border-radius:6px;
 background:linear-gradient(180deg,#1b252bf2,#141c21f2);box-shadow:inset 0 0 0 2px #0b1013,inset 0 0 0 3px ${inn}${glow ? ",0 0 6px " + CY + ",inset 0 0 10px #5fe3e644" : ""}"></div>`);
card("Card", "#6b6a58", "#2b3a3f", false);
card("CardHover", "#8c8a72", "#3b5257", false);
card("CardSel", CY, "#2a7f88", true);
// cartão novo (montado no jogo): fundo branco de cantos redondos (raio 6, em 9 partes de margem 6;
// o jogo tinge) e o arco de um canto do filete (desenhado em dobro: o jogo mostra em 6x6)
piece("CardFill", 12, 12, `<div style="width:12px;height:12px;border-radius:6px;background:#fff"></div>`);
piece("CardArc", 12, 12, svg(12, 12, `<path d="M1 12 A11 11 0 0 1 12 1" fill="none" stroke="#fff" stroke-width="2"/>`));
// janelas (missões, detalhes, menus): o mesmo jeito, raio 9 (o jogo mostra em 9x9)
piece("PanelFill", 18, 18, `<div style="width:18px;height:18px;border-radius:9px;background:#fff"></div>`);
piece("PanelArc", 18, 18, svg(18, 18, `<path d="M1 18 A17 17 0 0 1 18 1" fill="none" stroke="#fff" stroke-width="2"/>`));
// ícones de missão no cartão (36): "?" entregar, "!" iniciar, losango em andamento
const ring = (glyph) => svg(36, 36, `<circle cx="18" cy="18" r="13" fill="#0e1519" stroke="${GOLD2}" stroke-width="1.3"/>
 <circle cx="18" cy="18" r="10.5" fill="none" stroke="${GOLD}" stroke-width=".6" opacity=".5"/>
 <path d="M18 2.5 V6.5 M18 29.5 V33.5 M2.5 18 H6.5 M29.5 18 H33.5" stroke="${GOLD2}" stroke-width="1.3"/>
 <text x="18" y="24.2" text-anchor="middle" font-family="Seg" font-weight="700" font-size="17" fill="${GOLD}">${glyph}</text>`);
piece("QTurnIn", 36, 36, ring("?"));
piece("QNew", 36, 36, ring("!"));
const diamond = (s, k = 1) => svg(s, s, `<g transform="translate(${s / 2} ${s / 2}) scale(${k})">
 <path d="M0 -14 L14 0 L0 14 L-14 0 Z" fill="#0d3a42" stroke="${CY}" stroke-width="1.6" filter="url(#g2)"/>
 <path d="M0 -8.5 L8.5 0 L0 8.5 L-8.5 0 Z" fill="${CY}" filter="url(#g1)"/>
 <path d="M0 -5 L5 0 L0 5 L-5 0 Z" fill="#e8ffff"/></g>`);
piece("QProgress", 36, 36, diamond(36, 1));
// barra de progresso: trilho (9 partes, margem 5) e preenchimento ciano
piece("BarTrack", 40, 10, `<div style="width:38px;height:8px;margin:1px;border-radius:4px;border:1px solid #3c4c52;background:#0a0f12"></div>`);
piece("BarFill", 40, 10, `<div style="width:38px;height:6px;margin:2px 1px;border-radius:3px;background:linear-gradient(90deg,#1a8fa0,#4fe0ea 70%,#bffcff);
 box-shadow:0 0 6px ${CY}"></div>`);
piece("BarShine", 32, 10, `<div style="width:32px;height:10px;background:radial-gradient(50% 50% at 50% 50%,#ffffffcc,#bffcff44 50%,transparent)"></div>`);
// barra de status inferior (9 partes, margem 18): pontas em ângulo como na arte
piece("Pill", 96, 36, svg(96, 36, `<path d="M14 1.5 H82 L94.5 18 L82 34.5 H14 L1.5 18 Z" fill="#0d1215" fill-opacity=".92" stroke="#8a9496" stroke-width="1" stroke-opacity=".8"/>
 <path d="M16 4.5 H80 L90.5 18 L80 31.5 H16 L5.5 18 Z" fill="none" stroke="#ffffff" stroke-opacity=".06" stroke-width="1"/>`));
// linha azul de baixo (esticada) e a linha de cima da barra de status
piece("BottomLine", 8, 12, `<div style="width:8px;height:12px;position:relative"><div style="position:absolute;left:0;right:0;top:5px;height:1.5px;background:${CY2};box-shadow:0 0 5px ${CY},0 0 10px ${CY}88"></div></div>`);
// pinos no mapa
piece("PinProgress", 40, 40, diamond(40, 1.05));
piece("PinTurnIn", 32, 32, svg(32, 32, `<text x="16" y="25" text-anchor="middle" font-family="Seg" font-weight="700" font-size="24"
 fill="${GOLD}" stroke="#2a1d06" stroke-width="2.2" paint-order="stroke" filter="url(#g1)">?</text>`));
piece("PinNew", 32, 32, svg(32, 32, `<circle cx="16" cy="16" r="11" fill="#14212a" stroke="#0a0f12" stroke-width="1.5"/>
 <text x="16" y="23" text-anchor="middle" font-family="Seg" font-weight="700" font-size="18" fill="#f2c94c" filter="url(#g1)">!</text>`));
// o corpo do jogador (morto/fantasma): caveira creme num medalhão escuro de borda dourada, halo ciano
piece("PinCorpse", 40, 40, svg(40, 40, `<circle cx="20" cy="20" r="15" fill="none" stroke="${CY}" stroke-width="2.2" opacity=".85" filter="url(#g2)"/>
 <circle cx="20" cy="20" r="13" fill="#10181e" stroke="#0a0f12" stroke-width="2.5"/>
 <circle cx="20" cy="20" r="12.2" fill="none" stroke="${GOLD}" stroke-width="1.4"/>
 <path d="M20 9.5c-5.3 0-8.6 3.6-8.6 8.2 0 2.8 1.2 4.6 3 5.7v3.2c0 .9.7 1.6 1.6 1.6h8c.9 0 1.6-.7 1.6-1.6v-3.2c1.8-1.1 3-2.9 3-5.7 0-4.6-3.3-8.2-8.6-8.2z" fill="#efe6cf" stroke="#0a0f12" stroke-width="1"/>
 <ellipse cx="16.6" cy="18.6" rx="2.3" ry="2.6" fill="#10181e"/><ellipse cx="23.4" cy="18.6" rx="2.3" ry="2.6" fill="#10181e"/>
 <path d="M20 21.6l-1.4 2.4h2.8z" fill="#10181e"/>
 <path d="M17.6 25.6v2.6M20 25.6v2.6M22.4 25.6v2.6" stroke="#10181e" stroke-width="1"/>`));
piece("PinRing", 64, 64, svg(64, 64, `<circle cx="32" cy="32" r="22" fill="none" stroke="${CY}" stroke-width="2" filter="url(#g4)"/>
 <circle cx="32" cy="32" r="22" fill="none" stroke="#dffcff" stroke-width="1"/>`));
piece("Route", 32, 16, `<div style="width:32px;height:16px;position:relative"><div style="position:absolute;left:0;right:0;top:6px;height:4px;border-radius:2px;
 background:${CY};box-shadow:0 0 6px ${CY},0 0 12px ${CY}"></div><div style="position:absolute;left:0;right:0;top:7px;height:2px;background:#e9ffff"></div></div>`);
piece("RouteHead", 32, 32, svg(32, 32, `<path d="M4 6 L28 16 L4 26 L10 16 Z" fill="#e9ffff" stroke="${CY}" stroke-width="1.4" filter="url(#g2)"/>`));
// seta do jogador (escolhida pelo usuário em 18/11, protótipo D): azul-marinho com reflexo ciano na
// ponta e borda dourada sobre contorno escuro; aponta para cima, centrada (gira com SetRotation)
piece("PlayerArrow", 40, 40, svg(40, 40, `<defs>
 <linearGradient id="paO" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#FFF2C4"/><stop offset=".5" stop-color="#E0B65E"/><stop offset="1" stop-color="#7A5420"/></linearGradient>
 <linearGradient id="paB" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#6FE3EC"/><stop offset=".5" stop-color="#1E4FA8"/><stop offset="1" stop-color="#0E2660"/></linearGradient></defs>
 <g transform="translate(20,23)"><path d="M0 -19 L12.5 13 L0 6.5 L-12.5 13Z" fill="url(#paB)" stroke="#120C02" stroke-width="5.6" stroke-linejoin="round" paint-order="stroke"/>
 <path d="M0 -19 L12.5 13 L0 6.5 L-12.5 13Z" fill="none" stroke="url(#paO)" stroke-width="2.6" stroke-linejoin="round"/>
 <path d="M0 -15 L0 5 L-9 10Z" fill="#ffffff" fill-opacity=".18"/></g>`));
// botão (detalhes da missão): 9 partes, margem 6
piece("Button", 48, 26, `<div style="width:46px;height:24px;margin:1px;border-radius:3px;border:1px solid #3f7d84;
 background:linear-gradient(180deg,#14252b,#0c161a);box-shadow:inset 0 1px 0 #ffffff12,inset 0 0 8px #000"></div>`);

// ---------------------------------------------------------------- monta a página e renderiza
const GAP = 6;
let x = GAP, y = GAP, rowH = 0;
const PAGE_W = 520;
for (const p of P) {
  if (x + p.w + GAP > PAGE_W) { x = GAP; y += rowH + GAP; rowH = 0; }
  p.x = x; p.y = y;
  x += p.w + GAP;
  rowH = Math.max(rowH, p.h);
}
const PAGE_H = y + rowH + GAP;
const html = `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:Seg;src:url(${FONTS}/SegoeUI-Semibold.ttf)}
html,body{margin:0;background:transparent;overflow:hidden}
.p{position:absolute;overflow:hidden}
</style></head><body>${P.map((p) => `<div class="p" style="left:${p.x}px;top:${p.y}px;width:${p.w}px;height:${p.h}px">${p.html}</div>`).join("\n")}</body></html>`;
const htmlFile = path.join(DIR, "pieces.html"), pngFile = path.join(DIR, "pieces.png");
fs.writeFileSync(htmlFile, html);
if (fs.existsSync(pngFile)) fs.unlinkSync(pngFile);      // (para nunca ler o print da vez anterior)
// (um perfil novo a cada vez: com um Edge sem janela anterior aberto, ele reaproveitava o tamanho da janela)
const profile = path.join(require("os").tmpdir(), "azaath_edge_" + Date.now());
spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--user-data-dir=" + profile, "--no-first-run", "--hide-scrollbars", "--default-background-color=00000000",
  "--force-device-scale-factor=" + SCALE, "--window-size=" + PAGE_W + "," + PAGE_H, "--virtual-time-budget=2000",
  "--allow-file-access-from-files", "--screenshot=" + pngFile, "file:///" + htmlFile.replace(/\\/g, "/")], { stdio: "ignore" });
// o Edge pode devolver antes de gravar o print: espera o arquivo novo aparecer e parar de crescer
{
  const t0 = Date.now();
  let last = -1;
  while (Date.now() - t0 < 30000) {
    const sz = fs.existsSync(pngFile) ? fs.statSync(pngFile).size : 0;
    if (sz > 0 && sz === last) break;
    last = sz;
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
  }
}
const page = readPNG(pngFile);
console.log("página", page.w + "x" + page.h, "(esperado", PAGE_W * SCALE + "x" + PAGE_H * SCALE + ")");

for (const d of OUTS) fs.mkdirSync(d, { recursive: true });
const lua = ["-- GERADO por tools/map-ui-concept/gen.js: tamanho (pixels de interface) de cada textura de Media/MapFrame.",
  "local _, Azaath = ...", "Azaath.MapFrameTex = {"];
for (const p of P) {
  const im = I.crop(page, p.x * SCALE, p.y * SCALE, p.w * SCALE, p.h * SCALE);
  for (const d of OUTS) I.writeTGA(path.join(d, p.name + ".tga"), im);
  lua.push(`\t${p.name} = { ${p.w}, ${p.h} },`);
}
lua.push("}", "");
const luaOut = ["AzaathUI/Data/MapFrameTex.lua", "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Data/MapFrameTex.lua"];
fs.writeFileSync(path.join(ROOT, luaOut[0]), lua.join("\n"));
fs.writeFileSync(luaOut[1], lua.join("\n"));
// prévia sobre um fundo de terreno escuro
const prev = I.create(page.w, page.h, 40, 52, 34, 255);
for (let i = 0; i < page.w * page.h; i++) {
  const a = page.px[i * 4 + 3] / 255;
  for (let k = 0; k < 3; k++) prev.px[i * 4 + k] = prev.px[i * 4 + k] * (1 - a) + page.px[i * 4 + k] * a;
}
I.writePNG(path.join(DIR, "preview.png"), prev);
console.log(P.length, "texturas gravadas");
