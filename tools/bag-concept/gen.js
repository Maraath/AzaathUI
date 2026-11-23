// Arte de conceito da Mochila (tecla B) no estilo Azaath.
// Gera nw.html (disposição Azaath) e bdo.html (estilo Black Desert, câmera parada)
// e renderiza as duas em 2560x1440 com o Edge sem janela.
//   node tools/bag-concept/gen.js
// Ícones e cenário saem dos prints do jogo copiados para esta pasta (ss_bag.jpg, ss_world.jpg).
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const I = require("./icons.js");

const DIR = __dirname;
const ROOT = path.resolve(DIR, "../..");
const FONTS = "file:///" + path.join(ROOT, "AzaathUI/Media/Fonts").replace(/\\/g, "/");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";

// ---------- peças comuns ----------
const CSS = `
@font-face{font-family:Cinzel;src:url(${FONTS}/Cinzel-Regular.ttf)}
@font-face{font-family:Cinzel;font-weight:700;src:url(${FONTS}/Cinzel-Bold.ttf)}
@font-face{font-family:PTS;src:url(${FONTS}/PTSans-Regular.ttf)}
@font-face{font-family:PTS;font-weight:700;src:url(${FONTS}/PTSans-Bold.ttf)}
@font-face{font-family:Fell;src:url(${FONTS}/IMFell-Regular.ttf)}
:root{--gold:#c9a463;--gold2:#7d6232;--gold3:#e9d29a;--cy:#5fe3e6;--cy2:#1b8f99;--cyD:#0d4d55;
--ink:#071017;--txt:#ddd6c4;--mut:#8d989c;--green:#3fcf5a;--blue:#3d8cff;--purple:#a65cff;--orange:#ff9a3c}
*{box-sizing:border-box}
html,body{margin:0;background:#000;overflow:hidden}
.stage{position:relative;width:1920px;height:1080px;overflow:hidden;font-family:PTS,sans-serif;color:var(--txt)}
.cz{font-family:Cinzel,serif}
.abs{position:absolute!important}
/* painel Azaath: ardósia escura, filete de bronze duplo, gemas ciano nos cantos */
.panel{position:absolute;background:
 radial-gradient(120% 60% at 50% 0%,#17303a66,transparent 60%),
 linear-gradient(180deg,#0d1820f4,#070e14f8);
 border:1px solid #8a6d3a;box-shadow:0 0 0 1px #000,0 0 0 4px #121c22,0 0 0 5px #5b4724,0 0 0 6px #000,
 inset 0 0 0 1px #00000099,inset 0 0 50px #000c,0 20px 60px #000c}
.panel:before{content:"";position:absolute;inset:6px;border:1px solid #c9a46322;pointer-events:none}
.gemc{position:absolute;width:14px;height:14px;transform:rotate(45deg);
 background:radial-gradient(circle at 35% 35%,#d8ffff,#5fe3e6 35%,#127580 75%);
 border:1px solid #d9bb78;box-shadow:0 0 10px #5fe3e6,0 0 22px #5fe3e655}
.gemc.tl{left:-9px;top:-9px}.gemc.tr{right:-9px;top:-9px}.gemc.bl{left:-9px;bottom:-9px}.gemc.br{right:-9px;bottom:-9px}
.crest{position:absolute;left:50%;top:-30px;width:120px;height:46px;transform:translateX(-50%)}
.hdr{font-family:Cinzel,serif;letter-spacing:4px;color:#efe6cf;text-shadow:0 0 12px #5fe3e644,0 2px 2px #000}
.rule{height:1px;background:linear-gradient(90deg,transparent,#c9a46399 15%,#c9a463 50%,#c9a46399 85%,transparent);position:relative}
.rule.cy{background:linear-gradient(90deg,transparent,#5fe3e6aa 30%,#bfffff 50%,#5fe3e6aa 70%,transparent);box-shadow:0 0 8px #5fe3e6}
.rule i{position:absolute;left:50%;top:-4px;width:8px;height:8px;margin-left:-4px;transform:rotate(45deg);background:#5fe3e6;box-shadow:0 0 8px #5fe3e6;border:1px solid #e9d29a}
/* seções de categoria */
.cat{display:flex;align-items:center;gap:10px;font-family:Cinzel,serif;font-size:13px;letter-spacing:3px;color:#d8cba8;margin:0 0 8px}
.cat .ln{flex:1;height:1px;background:linear-gradient(90deg,#c9a46388,#c9a46311)}
.cat .n{font-family:PTS;letter-spacing:0;color:#efe6cf;font-size:14px}
.cat .ar{width:16px;height:16px;border:1px solid #6b5630;background:#0b141a;position:relative}
.cat .ar:after{content:"";position:absolute;left:5px;top:4px;border-left:6px solid #c9a463;border-top:4px solid transparent;border-bottom:4px solid transparent}
/* espaço de item */
.slot{position:absolute;width:var(--s);height:var(--s);
 background:radial-gradient(circle at 50% 40%,#1c2b34,#0a1218 75%);
 border:1px solid #3a4a50;box-shadow:inset 0 0 0 1px #000,inset 0 0 12px #000,0 0 0 1px #00000088}
.slot:before,.slot:after{content:"";position:absolute;width:7px;height:7px;border:1px solid #c9a46388;pointer-events:none;z-index:2}
.slot:before{left:-1px;top:-1px;border-right:0;border-bottom:0}
.slot:after{right:-1px;bottom:-1px;border-left:0;border-top:0}
.slot .ic{position:absolute;inset:3px;background-repeat:no-repeat;filter:saturate(1.08) contrast(1.05)}
.slot.q2{border-color:#2f9a45;box-shadow:inset 0 0 0 1px #000,inset 0 0 10px #3fcf5a66,0 0 6px #3fcf5a55}
.slot.q3{border-color:#2f6fd0;box-shadow:inset 0 0 0 1px #000,inset 0 0 10px #3d8cff66,0 0 6px #3d8cff55}
.slot.q4{border-color:#8a49d6;box-shadow:inset 0 0 0 1px #000,inset 0 0 10px #a65cff66,0 0 8px #a65cff66}
.slot.round{border-radius:50%}
.slot.round:before,.slot.round:after{display:none}
.slot.new .ic:after{content:"";position:absolute;right:-2px;top:-2px;width:9px;height:9px;transform:rotate(45deg);background:#ffd76a;box-shadow:0 0 6px #ffd76a}
.slot.sel{border-color:#9ff;box-shadow:0 0 0 1px #5fe3e6,0 0 14px #5fe3e6,inset 0 0 14px #5fe3e688}
.slot.empty .sil{position:absolute;inset:8px;opacity:.16;border:2px solid #9bb;border-radius:4px}
.slot.lock{background:repeating-linear-gradient(135deg,#0a1015 0 6px,#0d151b 6px 12px);border-color:#26323a}
.lockic{position:absolute;left:50%;top:52%;width:14px;height:11px;margin:-3px 0 0 -7px;background:#4b5960;border-radius:2px}
.lockic:before{content:"";position:absolute;left:2px;top:-8px;width:6px;height:7px;border:2px solid #4b5960;border-bottom:0;border-radius:6px 6px 0 0}
.btn{position:absolute;height:36px;display:flex;align-items:center;justify-content:center;gap:8px;
 font-family:Cinzel,serif;font-size:14px;letter-spacing:2px;color:#efe6cf;
 background:linear-gradient(180deg,#1a2a33,#0b141a);border:1px solid #8a6d3a;
 box-shadow:0 0 0 1px #000,inset 0 1px 0 #ffffff14,inset 0 0 14px #000}
.btn.on{border-color:#5fe3e6;box-shadow:0 0 0 1px #000,0 0 14px #5fe3e655,inset 0 0 14px #1b8f9966}
.key{font-family:PTS;font-size:11px;letter-spacing:0;color:#9fe;border:1px solid #2c5a60;padding:1px 5px;background:#061015}
.coin{display:inline-block;width:13px;height:13px;border-radius:50%;vertical-align:-1px;margin-right:5px}
.coin.g{background:radial-gradient(circle at 35% 30%,#fff3b0,#e2b33e 45%,#8a5d12)}
.coin.s{background:radial-gradient(circle at 35% 30%,#fff,#b9c2c8 45%,#5d666c)}
.coin.c{background:radial-gradient(circle at 35% 30%,#ffd3a8,#c06a2d 45%,#6a3010)}
.bar{position:relative;height:6px;background:#050a0e;border:1px solid #2a3940}
.bar i{position:absolute;left:0;top:0;bottom:0;background:linear-gradient(90deg,#127580,#5fe3e6);box-shadow:0 0 8px #5fe3e6}
.search{position:absolute;height:28px;border:1px solid #3a4a50;background:#050b10;display:flex;align-items:center;padding:0 10px;font-size:13px;color:#6f7d82}
.search .lens{width:11px;height:11px;border:2px solid #7f8f94;border-radius:50%;margin-right:8px;position:relative}
.search .lens:after{content:"";position:absolute;right:-6px;bottom:-5px;width:6px;height:2px;background:#7f8f94;transform:rotate(45deg)}
.ico-btn{position:absolute;width:26px;height:26px;border:1px solid #3a4a50;background:#0a1318;display:flex;align-items:center;justify-content:center}
.ico-btn.on{border-color:#5fe3e6;box-shadow:0 0 8px #5fe3e655}
.clock{width:12px;height:12px;border:2px solid #cfd6d8;border-radius:50%;position:relative}
.clock:after{content:"";position:absolute;left:4px;top:1px;width:2px;height:5px;background:#cfd6d8;box-shadow:2px 3px 0 -0px #cfd6d8}
.stack{width:13px;height:3px;background:#cfd6d8;box-shadow:0 -5px 0 #cfd6d8,0 5px 0 #cfd6d8}
.xmark{position:absolute;width:24px;height:24px}
.xmark:before,.xmark:after{content:"";position:absolute;left:11px;top:2px;width:2px;height:20px;background:#c9a463;transform:rotate(45deg)}
.xmark:after{transform:rotate(-45deg)}
.spark{position:absolute;width:3px;height:3px;border-radius:50%;background:#bff;box-shadow:0 0 6px 2px #5fe3e6aa}
`;

// gema/cristal do topo dos painéis (mesmo motivo do medalhão da HUD Azaath)
const CREST = `<svg class="crest" viewBox="0 0 120 46"><defs>
<linearGradient id="cg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#e8ffff"/><stop offset=".45" stop-color="#5fe3e6"/><stop offset="1" stop-color="#0c5a63"/></linearGradient>
<radialGradient id="cgl"><stop offset="0" stop-color="#5fe3e6" stop-opacity=".8"/><stop offset="1" stop-color="#5fe3e6" stop-opacity="0"/></radialGradient></defs>
<ellipse cx="60" cy="26" rx="44" ry="20" fill="url(#cgl)"/>
<path d="M8 32 C 26 32, 34 22, 46 24 M112 32 C 94 32, 86 22, 74 24" stroke="#c9a463" stroke-width="1.6" fill="none"/>
<path d="M18 36 C 32 36, 40 30, 48 30 M102 36 C 88 36, 80 30, 72 30" stroke="#7d6232" stroke-width="1.2" fill="none"/>
<path d="M60 3 L72 22 L60 43 L48 22 Z" fill="url(#cg)" stroke="#e9d29a" stroke-width="1.5"/>
<path d="M60 3 L60 43 M48 22 L72 22" stroke="#ffffff66" stroke-width=".8"/>
<circle cx="40" cy="27" r="2.4" fill="#c9a463"/><circle cx="80" cy="27" r="2.4" fill="#c9a463"/></svg>`;

const CORNERS = `<i class="gemc tl"></i><i class="gemc tr"></i><i class="gemc bl"></i><i class="gemc br"></i>`;

function icon(c, s) { // recorte do print escalado para s px
  const [x, y, w] = c, k = s / w;
  return `<div class="ic" style="background-image:url(ss_bag.jpg);background-size:${1920 * k}px ${1080 * k}px;background-position:-${x * k}px -${y * k}px"></div>`;
}
function rawIcon(c, s) {
  const [x, y, w] = c, k = s / w;
  return `<div style="width:${s}px;height:${s}px;flex:none;background:url(ss_bag.jpg) -${x * k}px -${y * k}px/${1920 * k}px ${1080 * k}px no-repeat;border:1px solid #3a4a50"></div>`;
}
function slot(x, y, s, c, cls = "") {
  const inner = c ? icon(c, s - 6) : `<div class="sil"></div>`;
  return `<div class="slot ${c ? "" : "empty"} ${cls}" style="--s:${s}px;left:${x}px;top:${y}px">${inner}</div>`;
}
function cat(name, n) {
  return `<div class="cat"><span>${name}</span><span class="ln"></span><span class="n">${n}</span><span class="ar"></span></div>`;
}
function grid(x, y, items, cols, s, gap, clsFn = () => "") {
  return items.map((c, i) => slot(x + (i % cols) * (s + gap), y + Math.floor(i / cols) * (s + gap), s, c, clsFn(i))).join("");
}
function sparks(n, x0, y0, w, h, seed) {
  let r = seed, out = "";
  const rnd = () => (r = (r * 9301 + 49297) % 233280) / 233280;
  for (let i = 0; i < n; i++) {
    const s = 1.5 + rnd() * 2.5;
    out += `<i class="spark" style="left:${x0 + rnd() * w}px;top:${y0 + rnd() * h}px;width:${s}px;height:${s}px;opacity:${.3 + rnd() * .7}"></i>`;
  }
  return out;
}
const page = (title, body) => `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><title>${title}</title><style>${CSS}</style></head><body><div class="stage">${body}</div></body></html>`;

// círculo rúnico sob os pés do personagem
function runeCircle(cx, cy, rx, ry) {
  let ticks = "";
  for (let i = 0; i < 72; i++) {
    const a = i / 72 * Math.PI * 2, l = i % 6 == 0 ? 10 : 4;
    const x1 = Math.cos(a) * 0.86, y1 = Math.sin(a) * 0.86, x2 = Math.cos(a) * (0.86 - l / 160), y2 = Math.sin(a) * (0.86 - l / 160);
    ticks += `<line x1="${x1 * 200}" y1="${y1 * 200}" x2="${x2 * 200}" y2="${y2 * 200}"/>`;
  }
  let glyph = "";
  for (let i = 0; i < 6; i++) {
    const a = i / 6 * Math.PI * 2 + Math.PI / 6, x = Math.cos(a) * 150, y = Math.sin(a) * 150;
    glyph += `<g transform="translate(${x} ${y}) rotate(${a * 180 / Math.PI + 90})"><path d="M-7 -8 L0 8 L7 -8 M-5 0 H5" /></g>`;
  }
  return `<svg class="abs" style="left:${cx - rx}px;top:${cy - ry}px;width:${rx * 2}px;height:${ry * 2}px;overflow:visible" viewBox="-200 -200 400 400" preserveAspectRatio="none">
  <defs><radialGradient id="rg"><stop offset="0" stop-color="#5fe3e6" stop-opacity=".55"/><stop offset=".5" stop-color="#1b8f99" stop-opacity=".18"/><stop offset="1" stop-color="#1b8f99" stop-opacity="0"/></radialGradient>
  <filter id="gl"><feGaussianBlur stdDeviation="2.5" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>
  <circle r="200" fill="url(#rg)"/>
  <g fill="none" stroke="#7ff2f2" filter="url(#gl)">
   <circle r="186" stroke-width="2.5" opacity=".9"/><circle r="172" stroke-width="1" stroke="#c9a463"/>
   <g stroke-width="2" opacity=".8">${ticks}</g>
   <circle r="128" stroke-width="1.5" opacity=".75"/>
   <path d="M0 -128 L111 64 L-111 64 Z M0 128 L111 -64 L-111 -64 Z" stroke-width="1.4" stroke="#c9a463" opacity=".8"/>
   <circle r="64" stroke-width="2" opacity=".9"/>
   <g stroke-width="2.2" stroke="#bfffff">${glyph}</g>
  </g></svg>`;
}

// ======================= 1) DISPOSIÇÃO NEW WORLD =======================
function buildNW() {
  const E = I.eq;
  // cenário: o próprio print desfocado e escurecido; o personagem nítido por cima, com máscara suave
  let b = `
  <div class="abs" style="inset:-30px;background:url(ss_bag.jpg) 30px 30px/1920px 1080px;filter:blur(16px) brightness(.42) saturate(.8)"></div>
  <div class="abs" style="inset:0;background:radial-gradient(42% 60% at 50% 58%,#0f2a3022,#050a0edd 70%,#020507 100%)"></div>
  ${runeCircle(960, 860, 230, 62)}
  <div class="abs" style="left:780px;top:420px;width:360px;height:470px;background:url(ss_bag.jpg) -780px -420px/1920px 1080px;
     -webkit-mask-image:radial-gradient(50% 54% at 50% 50%,#000 62%,transparent 100%);filter:brightness(1.75) contrast(1.08) saturate(1.1)"></div>
  <div class="abs" style="left:700px;top:300px;width:520px;height:620px;background:radial-gradient(40% 50% at 50% 60%,#5fe3e622,transparent 70%)"></div>
  ${sparks(70, 640, 220, 640, 700, 7)}
  `;

  // ---- barra superior ----
  b += `
  <div class="abs hdr" style="left:64px;top:34px;font-size:30px">MOCHILA</div>
  <div class="abs" style="left:64px;top:76px;font-size:13px;letter-spacing:2px;color:var(--mut)" class="cz">MARAATH &nbsp;·&nbsp; ELFO NOTURNO GUERREIRO &nbsp;·&nbsp; NÍVEL 24</div>
  <div class="abs rule" style="left:40px;right:40px;top:104px"></div>
  <div class="abs" style="right:64px;top:40px;display:flex;gap:22px;font-family:Cinzel;font-size:13px;letter-spacing:2px;color:#b8b09b">
    <span style="color:#fff;text-shadow:0 0 10px #5fe3e6">INVENTÁRIO</span><span>FICHA (C)</span><span>GRIMÓRIO (P)</span><span>OFÍCIOS (K)</span>
    <span style="display:flex;align-items:center;gap:6px"><span class="key">ESC</span>FECHAR</span></div>`;

  // ---- medalhão do nível de item sobre o personagem ----
  b += `
  <svg class="abs" style="left:885px;top:128px;width:150px;height:150px" viewBox="0 0 150 150">
   <defs><radialGradient id="md"><stop offset="0" stop-color="#16323a"/><stop offset="1" stop-color="#060c10"/></radialGradient>
   <filter id="mg"><feGaussianBlur stdDeviation="3" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter></defs>
   <circle cx="75" cy="75" r="58" fill="url(#md)" stroke="#7d6232" stroke-width="5"/>
   <circle cx="75" cy="75" r="58" fill="none" stroke="#c9a463" stroke-width="1.5"/>
   <circle cx="75" cy="75" r="49" fill="none" stroke="#5fe3e6" stroke-width="2" filter="url(#mg)" stroke-dasharray="3 5"/>
   <circle cx="75" cy="75" r="44" fill="none" stroke="#5fe3e6" stroke-width="1" opacity=".6"/>
   <path d="M75 4 L83 17 L75 24 L67 17Z M75 146 L83 133 L75 126 L67 133Z" fill="#5fe3e6" stroke="#e9d29a" filter="url(#mg)"/>
   <path d="M4 75 L16 69 L22 75 L16 81Z M146 75 L134 69 L128 75 L134 81Z" fill="#c9a463"/>
  </svg>
  <div class="abs cz" style="left:885px;top:160px;width:150px;text-align:center;font-size:46px;color:#f4ecd6;text-shadow:0 0 16px #5fe3e6">15</div>
  <div class="abs cz" style="left:810px;top:282px;width:300px;text-align:center;font-size:12px;letter-spacing:3px;color:#c9bfa5">NÍVEL DE ITEM</div>
  <div class="abs" style="left:860px;top:304px;width:200px">
    <div style="display:flex;justify-content:space-between;font-size:11px;letter-spacing:1px;color:#8d989c;margin-bottom:4px"><span>INTEGRIDADE</span><span style="color:#9ff">100%</span></div>
    <div class="bar"><i style="width:100%"></i></div></div>`;

  // ---- equipamento em volta do personagem ----
  const S = 56, P = 66;
  const left = [["Cabeça", E.head, "q3"], ["Pescoço", E.neck, "q2"], ["Ombros", E.shoulder, "q3"], ["Costas", E.back, "q2"],
    ["Peito", E.chest, "q2"], ["Pulsos", E.wrist, "q2"], ["Mãos", E.hands, "q2"], ["Cintura", E.waist, "q2"]];
  const right = [["Pernas", E.legs, "q2"], ["Pés", E.feet, "q2"], ["Anel", null], ["Anel", null],
    ["Berloque", E.trinket, "q3"], ["Berloque", null], ["Camisa", null], ["Tabardo", null]];
  // trilho dourado das colunas
  b += `<div class="abs" style="left:${700 + S / 2}px;top:350px;width:1px;height:${P * 8 - 10}px;background:linear-gradient(#c9a46300,#c9a46366 10%,#c9a46366 90%,#c9a46300)"></div>
        <div class="abs" style="left:${1164 + S / 2}px;top:350px;width:1px;height:${P * 8 - 10}px;background:linear-gradient(#c9a46300,#c9a46366 10%,#c9a46366 90%,#c9a46300)"></div>`;
  left.forEach(([n, c, q], i) => {
    b += slot(700, 350 + i * P, S, c, q);
  });
  right.forEach(([n, c, q], i) => {
    b += slot(1164, 350 + i * P, S, c, q || "");
  });
  // armas sob o círculo
  b += `<div class="abs cz" style="left:760px;top:932px;width:400px;text-align:center;font-size:11px;letter-spacing:3px;color:#8d989c">ARMAS</div>`;
  b += slot(860, 954, 60, I.weap[0], "q2") + slot(930, 954, 60, I.gear[0], "q2 sel") + slot(1000, 954, 60, I.gear[1], "q2");
  // nome do item em foco
  b += `<div class="abs" style="left:1236px;top:946px;width:220px">
    <div class="cz" style="font-size:14px;color:#5fdc6c;letter-spacing:1px">Tocha de Vigia</div>
    <div style="font-size:12px;color:#8d989c">Mão secundária · nível 21</div></div>`;

  // ---- painel de atributos (esquerda) ----
  const sec = (t) => `<div class="cat" style="margin:16px 0 8px">${t}<span class="ln"></span></div>`;
  const row = (n, base, v, pct) => `<div style="display:flex;align-items:baseline;font-size:15px;line-height:25px">
    <span style="flex:1;color:#ddd6c4">${n}</span><span style="font-size:12px;color:#6f7d82;margin-right:12px">${base || ""}</span>
    <span style="color:#f4ecd6;min-width:54px;text-align:right">${v}</span></div>${pct != null ? `<div class="bar" style="height:3px;margin:-1px 0 3px;border:0;background:#0d171c"><i style="width:${pct}%"></i></div>` : ""}`;
  b += `<div class="panel" style="left:64px;top:150px;width:380px;height:760px;padding:26px 30px">${CREST}${CORNERS}
    <div class="hdr" style="text-align:center;font-size:20px;margin-top:4px">ATRIBUTOS</div>
    <div class="rule cy" style="margin:12px 30px 4px"><i></i></div>
    ${sec("PRIMÁRIOS")}
    ${row("Força", "(49 + 55)", 104, 80)}${row("Agilidade", "(43 + 15)", 58, 45)}${row("Vigor", "(48 + 36)", 84, 65)}
    ${row("Intelecto", "(23 + 2)", 25, 20)}${row("Espírito", "(28 + 9)", 37, 28)}
    ${sec("ATAQUE")}${row("Poder de ataque", "", 266)}${row("Crítico", "", "11.71%")}${row("Acerto", "", "0.00%")}${row("Aceleração", "", "0.00%")}
    ${sec("MAGIA")}${row("Poder mágico", "", 0)}${row("Crítico mágico", "", "0.00%")}${row("Regeneração", "", "0.0 / s")}
    ${sec("DEFESA")}${row("Armadura", "", "1.102")}${row("Esquiva", "", "7.67%")}${row("Aparar", "", "4.92%")}${row("Bloqueio", "", "4.92%")}
  </div>`;

  // ---- inventário (direita) ----
  const X = 1356, Y = 150, W = 500, H = 780;
  b += `<div class="panel" style="left:${X}px;top:${Y}px;width:${W}px;height:${H}px">${CREST}${CORNERS}
    <div class="abs hdr" style="left:30px;top:30px;font-size:24px">INVENTÁRIO</div>
    <div class="abs cz" style="left:258px;top:38px;font-size:13px;letter-spacing:3px;color:#fff;text-shadow:0 0 10px #5fe3e6">CATEGORIAS</div>
    <div class="abs rule cy" style="left:252px;top:60px;width:118px"><i></i></div>
    <div class="abs cz" style="left:392px;top:38px;font-size:13px;letter-spacing:3px;color:#7f8a8e">BOLSAS</div>
    <div class="abs rule" style="left:24px;right:24px;top:76px"></div>
    <div class="search" style="left:28px;top:92px;width:290px"><span class="lens"></span>Buscar item...</div>
    <div class="abs" style="left:334px;top:97px;font-size:13px;color:#8d989c">Ordenar</div>
    <div class="ico-btn on" style="left:392px;top:93px"><span class="clock"></span></div>
    <div class="ico-btn" style="left:422px;top:93px"><svg width="14" height="14" viewBox="0 0 20 20"><path d="M10 1l2.6 6 6.4.6-4.9 4.3 1.5 6.3L10 15l-5.6 3.2 1.5-6.3L1 7.6 7.4 7z" fill="#cfd6d8"/></svg></div>
    <div class="ico-btn" style="left:452px;top:93px"><span class="stack"></span></div>
  </div>`;
  const cx1 = X + 28, cx2 = X + 262, s = 44, g = 8;
  const secAt = (x, y, w, t, n) => `<div class="abs" style="left:${x}px;top:${y}px;width:${w}px">${cat(t, n)}</div>`;
  b += secAt(cx1, Y + 140, 212, "ARMAS", 2) + grid(cx1, Y + 166, I.weap, 4, s, g, () => "q2");
  b += secAt(cx2, Y + 140, 212, "EQUIPAMENTO", 2) + grid(cx2, Y + 166, I.gear, 4, s, g, () => "q2");
  b += secAt(cx1, Y + 236, 212, "CONSUMÍVEIS", 27) + grid(cx1, Y + 262, I.cons, 4, s, g, (i) => i == 1 ? "q2" : "");
  b += secAt(cx2, Y + 236, 212, "MATERIAIS", 7) + grid(cx2, Y + 262, I.mat, 4, s, g, () => "round");
  b += secAt(cx2, Y + 384, 212, "MISSÃO", 7) + grid(cx2, Y + 410, I.quest, 4, s, g, (i) => i < 2 ? "new" : "");
  b += secAt(cx2, Y + 532, 212, "DIVERSOS", 1) + grid(cx2, Y + 558, I.misc, 4, s, g, () => "q3");
  b += secAt(cx1, Y + 640, 212, "ESPAÇO LIVRE", 20) + `<div class="slot" style="--s:44px;left:${cx1}px;top:${Y + 666}px"><div class="cz" style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center;font-size:16px;color:#8d989c">20</div></div>`;
  // bolsas equipadas (rodapé direito)
  b += secAt(cx2, Y + 640, 212, "BOLSAS", "46/66") + grid(cx2, Y + 666, I.bag, 4, s, g, () => "");
  // rodapé
  b += `<div class="abs rule" style="left:${X + 24}px;width:${W - 48}px;top:${Y + H - 62}px"></div>
   <div class="abs" style="left:${X + 30}px;top:${Y + H - 44}px;font-size:16px;color:#f4ecd6"><span class="coin g"></span>5 &nbsp;&nbsp;<span class="coin s"></span>35 &nbsp;&nbsp;<span class="coin c"></span>8</div>
   <div class="btn" style="left:${X + W - 170}px;top:${Y + H - 50}px;width:140px;height:30px;font-size:12px">RADIAL <span class="key">G</span></div>`;

  // ---- botões de baixo ----
  b += `<div class="btn" style="left:64px;top:968px;width:182px">REPARAR TUDO</div>
        <div class="btn on" style="left:262px;top:968px;width:182px">FICHA COMPLETA</div>
        <div class="abs" style="left:1356px;top:976px;width:500px;text-align:right;font-size:12px;color:#6f7d82">
        <span class="key">Clique dir.</span> usar &nbsp; <span class="key">Shift</span> dividir &nbsp; <span class="key">Ctrl</span> comparar</div>`;
  return page("Mochila Azaath — Azaath", b);
}

// ======================= 2) ESTILO BLACK DESERT =======================
function buildBDO() {
  const E = I.eq;
  // mundo intacto (câmera não gira); só um leve escurecer à direita sob as janelas
  let b = `
  <div class="abs" style="inset:0;background:url(ss_world.jpg) 0 0/1920px 1080px"></div>
  <div class="abs" style="left:66px;top:928px;width:130px;height:46px;background:url(ss_world.jpg) -206px -928px/1920px 1080px"></div>
  <div class="abs" style="left:1160px;top:0;right:0;bottom:0;background:linear-gradient(90deg,transparent,#02060a88 30%,#02060acc)"></div>`;

  // ---- janela da mochila ----
  const X = 1452, Y = 176, W = 424, H = 744;
  const s = 44, g = 6, cols = 8;
  const items = [...I.weap, ...I.gear, ...I.cons, ...I.mat, ...I.quest, ...I.misc]; // 46
  const all = [];
  for (let i = 0; i < 72; i++) all.push(i < items.length ? items[i] : null);
  b += `<div class="panel" style="left:${X}px;top:${Y}px;width:${W}px;height:${H}px">${CREST}${CORNERS}
    <div class="abs hdr" style="left:26px;top:26px;font-size:20px">MOCHILA</div>
    <div class="abs" style="left:164px;top:30px;font-size:12px;color:#8d989c;letter-spacing:1px"><span class="key">B</span></div>
    <i class="xmark" style="right:18px;top:24px"></i>
    <div class="abs rule" style="left:20px;right:20px;top:62px"></div>
    <div class="search" style="left:22px;top:76px;width:254px"><span class="lens"></span>Buscar...</div>
    <div class="ico-btn on" style="left:288px;top:77px"><span class="clock"></span></div>
    <div class="ico-btn" style="left:318px;top:77px"><svg width="14" height="14" viewBox="0 0 20 20"><path d="M10 1l2.6 6 6.4.6-4.9 4.3 1.5 6.3L10 15l-5.6 3.2 1.5-6.3L1 7.6 7.4 7z" fill="#cfd6d8"/></svg></div>
    <div class="ico-btn" style="left:348px;top:77px"><span class="stack"></span></div>
    <div class="ico-btn" style="left:378px;top:77px"><svg width="14" height="14" viewBox="0 0 20 20"><path d="M2 3h16l-6 7v6l-4 2v-8z" fill="none" stroke="#cfd6d8" stroke-width="2"/></svg></div>
  </div>`;
  // abas de filtro (ícones)
  const tabs = [["TUDO", null], ["ARMAS", I.weap[0]], ["CONSUM.", I.cons[4]], ["MATER.", I.mat[1]], ["MISSÃO", I.quest[1]]];
  tabs.forEach(([t, c], i) => {
    const x = X + 22 + i * 78, on = i == 0;
    b += `<div class="btn ${on ? "on" : ""}" style="left:${x}px;top:${Y + 116}px;width:72px;height:30px;font-size:10px;letter-spacing:1px;gap:5px">
      ${c ? rawIcon(c, 18) : ""}${t}</div>`;
  });
  const gx = X + 22, gy = Y + 162;
  b += grid(gx, gy, all.slice(0, 66), cols, s, g, (i) => {
    let c = "";
    if (i < 4) c = "q2"; if (i == 5) c = "q2"; if (i == 46 - 1) c = "q3";
    if ([40, 41].includes(i)) c = "new"; if (i == 8) c = "sel";
    if (i >= 34 && i <= 40) c += " round";
    return c;
  });
  // espaços bloqueados (expandir com bolsas)
  for (let i = 66; i < 72; i++) {
    const x = gx + (i % cols) * (s + g), y = gy + Math.floor(i / cols) * (s + g);
    b += `<div class="slot lock" style="--s:${s}px;left:${x}px;top:${y}px"><i class="lockic"></i></div>`;
  }
  const gyEnd = gy + 9 * (s + g);
  b += `
  <div class="abs" style="left:${X + 22}px;top:${gyEnd + 8}px;width:${W - 44}px">
    <div style="display:flex;justify-content:space-between;font-size:12px;letter-spacing:1px;color:#8d989c;margin-bottom:5px"><span class="cz">ESPAÇO</span><span style="color:#efe6cf">46 / 66</span></div>
    <div class="bar"><i style="width:70%"></i></div></div>
  <div class="abs" style="left:${X + 22}px;top:${gyEnd + 44}px;font-size:16px;color:#f4ecd6"><span class="coin g"></span>5 &nbsp;&nbsp;<span class="coin s"></span>35 &nbsp;&nbsp;<span class="coin c"></span>8</div>
  <div class="abs" style="left:${X + 220}px;top:${gyEnd + 40}px;display:flex;gap:6px">${I.bag.map((c) => `<div style="position:relative;width:32px;height:32px"><div class="slot" style="--s:32px;left:0;top:0">${icon(c, 26)}</div></div>`).join("")}<div class="slot" style="--s:32px;position:relative"><div class="sil"></div></div></div>
  <div class="btn" style="left:${X + 22}px;top:${Y + H - 52}px;width:124px;height:32px;font-size:12px">ORGANIZAR</div>
  <div class="btn" style="left:${X + 152}px;top:${Y + H - 52}px;width:124px;height:32px;font-size:12px">REPARAR</div>
  <div class="btn" style="left:${X + 282}px;top:${Y + H - 52}px;width:120px;height:32px;font-size:12px">VENDER LIXO</div>`;

  // ---- aba pequena de equipados, presa à esquerda da mochila ----
  const EX = 1238, EY = 236, EW = 196, EH = 560, es = 50, eg = 8;
  b += `<div class="panel" style="left:${EX}px;top:${EY}px;width:${EW}px;height:${EH}px">
    <i class="gemc tl"></i><i class="gemc bl"></i>
    <div class="abs hdr" style="left:0;right:0;top:18px;text-align:center;font-size:14px;letter-spacing:3px">EQUIPADO</div>
    <div class="abs rule cy" style="left:30px;right:30px;top:44px"><i></i></div>
    <div class="abs" style="left:0;right:0;top:56px;text-align:center"><span class="cz" style="font-size:30px;color:#f4ecd6;text-shadow:0 0 12px #5fe3e6">15</span>
      <div style="font-size:10px;letter-spacing:2px;color:#8d989c;margin-top:-2px">NÍVEL DE ITEM</div></div>
  </div>
  <!-- dobradiça entre as janelas -->
  <div class="abs" style="left:${EX + EW}px;top:${EY + 40}px;width:${X - EX - EW}px;height:${EH - 80}px;background:linear-gradient(90deg,#0b141a,#101b22);border-top:1px solid #7d6232;border-bottom:1px solid #7d6232"></div>
  <div class="abs" style="left:${EX + EW + 1}px;top:${EY + EH / 2 - 26}px;width:16px;height:52px;background:#0b141a;border:1px solid #c9a463;display:flex;align-items:center;justify-content:center">
    <i style="border-right:6px solid #5fe3e6;border-top:6px solid transparent;border-bottom:6px solid transparent;filter:drop-shadow(0 0 4px #5fe3e6)"></i></div>`;
  const eqL = [[E.head, "q3"], [E.shoulder, "q3"], [E.back, "q2"], [E.chest, "q2"], [E.wrist, "q2"], [E.hands, "q2"]];
  const eqR = [[E.neck, "q2"], [E.waist, "q2"], [E.legs, "q2"], [E.feet, "q2"], [E.trinket, "q3"], [null, ""]];
  const ex1 = EX + 30, ex2 = EX + EW - 30 - es, ey0 = EY + 112;
  eqL.forEach(([c, q], i) => b += slot(ex1, ey0 + i * (es + eg), es, c, q));
  eqR.forEach(([c, q], i) => b += slot(ex2, ey0 + i * (es + eg), es, c, q));
  // silhueta do herói entre as colunas (sem girar câmera: só um ícone heráldico)
  b += `<svg class="abs" style="left:${EX + 84}px;top:${ey0 + 30}px;width:28px;height:260px" viewBox="0 0 28 260">
    <line x1="14" y1="0" x2="14" y2="260" stroke="#c9a46355"/><path d="M14 40 l8 14 -8 14 -8 -14z M14 190 l8 14 -8 14 -8 -14z" fill="#5fe3e6aa"/>
    <circle cx="14" cy="130" r="6" fill="none" stroke="#c9a463"/></svg>`;
  const wy = ey0 + 6 * (es + eg) + 6;
  b += `<div class="abs cz" style="left:${EX}px;width:${EW}px;top:${wy - 2}px;text-align:center;font-size:10px;letter-spacing:3px;color:#8d989c">ARMAS</div>`;
  b += slot(EX + 22, wy + 14, 46, I.weap[0], "q2") + slot(EX + 75, wy + 14, 46, I.gear[0], "q2") + slot(EX + 128, wy + 14, 46, I.gear[1], "q2");
  b += `<div class="abs" style="left:${EX + 24}px;top:${EY + EH - 24}px;width:${EW - 48}px"><div class="bar" style="height:4px"><i style="width:100%"></i></div>
        <div style="text-align:center;font-size:10px;letter-spacing:1px;color:#8d989c;margin-top:3px">INTEGRIDADE 100%</div></div>`;

  // ---- dica do item selecionado (à esquerda da aba de equipados) ----
  const TX = 920, TY = 300;
  b += `<div class="panel" style="left:${TX}px;top:${TY}px;width:296px;height:206px;padding:18px 20px">
    <i class="gemc tl"></i><i class="gemc tr"></i>
    <div style="display:flex;gap:12px;align-items:center">
      <div style="position:relative;width:52px;height:52px">${slot(0, 0, 52, I.cons[4], "q2")}</div>
      <div><div class="cz" style="font-size:16px;color:#5fdc6c">Poção de Cura Menor</div>
      <div style="font-size:12px;color:#8d989c">Consumível · Pilha 5 / 20</div></div></div>
    <div class="rule" style="margin:14px 0 10px"></div>
    <div style="font-size:13px;line-height:20px;color:#ddd6c4">Usar: <span style="color:#5fdc6c">Restaura 140 a 180 de vida.</span></div>
    <div style="font-size:12px;line-height:19px;color:#8d989c">Recarga compartilhada de 2 min.</div>
    <div class="rule" style="margin:12px 0 10px"></div>
    <div style="display:flex;justify-content:space-between;font-size:12px;color:#8d989c"><span>Vende por <span class="coin s" style="margin-left:4px"></span>1</span>
      <span><span class="key">Clique dir.</span> usar</span></div>
  </div>`;
  b += sparks(24, 1240, 150, 640, 780, 3);
  return page("Mochila Azaath — Black Desert", b);
}

// ---------- gravar e renderizar ----------
const out = [
  ["nw.html", buildNW(), "Mochila_Azaath_Azaath_ConceptArt.png"],
  ["bdo.html", buildBDO(), "Mochila_Azaath_BlackDesert_ConceptArt_V2.png"],
];
for (const [html, src, png] of out) {
  fs.writeFileSync(path.join(DIR, html), src);
  const r = spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1.3333334",
    "--window-size=1920,1080", "--virtual-time-budget=3000", "--allow-file-access-from-files",
    "--screenshot=" + path.join(ROOT, png), "file:///" + path.join(DIR, html).replace(/\\/g, "/")], { stdio: "ignore" });
  console.log(png, r.status, fs.existsSync(path.join(ROOT, png)) ? fs.statSync(path.join(ROOT, png)).size : "faltou");
}
