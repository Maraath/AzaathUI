// Arte do painel de configuração (/azaath) e do assistente Primeiros Passos (/azaath setup).
// Cada peça é desenhada em SVG, renderizada pelo Edge sem janela (fundo transparente, escala 2)
// e recortada para Media/ConfigUI/<nome>.tga (projeto e pasta do jogo) + preview.png.
//   node tools/configui-art/gen.js      (o Edge só grava fora do sandbox do Bash)
// Peças claras/cinzas (StepGem, StepRing, EmblemRing, NavSel) são tingidas no jogo com SetVertexColor.
"use strict";
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const DIR = __dirname;
const ROOT = path.resolve(DIR, "../..");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const OUTS = [path.join(ROOT, "AzaathUI/Media/ConfigUI"),
  "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/ConfigUI"];
const SCALE = 2;

// paleta Azaath (mesma do Azaath.colors)
const G = "#c9a86b", GL = "#f3dca6", GD = "#6e5630", AM = "#f5c761", AMD = "#a8741e", INK = "#07090c";

const P = [];
// half = grava com metade da resolução (fundos grandes, sem detalhe fino)
const piece = (name, w, h, body, half) => P.push({ name, w, h, half, html: svg(w, h, body) });
const svg = (w, h, body) => `<svg width="${w}" height="${h}" viewBox="0 0 ${w} ${h}" xmlns="http://www.w3.org/2000/svg">
<defs>
 <filter id="g1" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="1" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
 <filter id="g3" x="-80%" y="-80%" width="260%" height="260%"><feGaussianBlur stdDeviation="3" result="b"/><feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge></filter>
 <filter id="soft" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="14"/></filter>
 <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="${GL}"/><stop offset=".5" stop-color="${G}"/><stop offset="1" stop-color="${GD}"/></linearGradient>
 <linearGradient id="goldH" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="${G}" stop-opacity="0"/><stop offset=".5" stop-color="${GL}"/><stop offset="1" stop-color="${G}" stop-opacity="0"/></linearGradient>
 <linearGradient id="gem" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#fff3c8"/><stop offset=".45" stop-color="${AM}"/><stop offset="1" stop-color="${AMD}"/></linearGradient>
 <radialGradient id="haze" cx=".5" cy=".5" r=".5"><stop offset="0" stop-color="${AM}" stop-opacity=".55"/><stop offset="1" stop-color="${AM}" stop-opacity="0"/></radialGradient>
</defs>${body}</svg>`;

const rad = (d) => d * Math.PI / 180;
const at = (cx, cy, r, d) => [cx + r * Math.cos(rad(d)), cy + r * Math.sin(rad(d))];
const f = (n) => n.toFixed(2);
// losango facetado (4 faces com luz vinda de cima à esquerda)
const facet = (cx, cy, rx, ry, cols) => {
  const T = [cx, cy - ry], R = [cx + rx, cy], B = [cx, cy + ry], L = [cx - rx, cy], C = [cx, cy];
  const tri = (a, b, c, col) => `<polygon points="${a.map(f)} ${b.map(f)} ${c.map(f)}" fill="${col}"/>`;
  return tri(L, T, C, cols[0]) + tri(T, R, C, cols[1]) + tri(R, B, C, cols[2]) + tri(B, L, C, cols[3]);
};
const diamond = (cx, cy, r, attrs) => `<polygon points="${f(cx)},${f(cy - r)} ${f(cx + r)},${f(cy)} ${f(cx)},${f(cy + r)} ${f(cx - r)},${f(cy)}" ${attrs}/>`;
// runa geométrica (traços curtos dentro de uma caixa s x s, centrada em cx,cy, girada deg)
const RUNES = [
  "M0 -5 V5 M0 -5 L3 -2 M0 0 L-3 3", "M-3 -5 V5 M-3 -1 L3 -5 M-3 -1 L3 5", "M0 -5 L3 0 L0 5 L-3 0 Z",
  "M-3 -5 L3 5 M3 -5 L-3 5 M-3 0 H3", "M0 -5 V5 M-3 -2 L0 -5 L3 -2", "M-3 5 V-5 L3 -1 L-3 2",
  "M-3 -4 H3 M0 -4 V5 M-3 5 H3", "M-3 -5 L0 0 L3 -5 M0 0 V5",
];
const rune = (cx, cy, i, deg, col, op) =>
  `<path d="${RUNES[i % RUNES.length]}" transform="translate(${f(cx)} ${f(cy)}) rotate(${f(deg)})" fill="none" stroke="${col}" stroke-width="1" stroke-linecap="round" opacity="${op}"/>`;

// ---------------------------------------------------------------- fundo da janela (opaco)
{
  const W = 1024, H = 672;
  let rings = "";
  // astrolábio apagado no canto superior direito e no inferior esquerdo
  const astro = (cx, cy, R, op) => {
    let s = `<g opacity="${op}" fill="none" stroke="${G}">`;
    for (const [r, w] of [[R, 1.2], [R * 0.86, 0.6], [R * 0.62, 0.8], [R * 0.4, 0.5]]) s += `<circle cx="${cx}" cy="${cy}" r="${f(r)}" stroke-width="${w}"/>`;
    for (let d = 0; d < 360; d += 5) {
      const l = d % 30 === 0 ? 14 : 6;
      const [x1, y1] = at(cx, cy, R, d), [x2, y2] = at(cx, cy, R - l, d);
      s += `<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke-width=".7"/>`;
    }
    for (let d = 0; d < 360; d += 45) {
      const [x1, y1] = at(cx, cy, R * 0.4, d), [x2, y2] = at(cx, cy, R * 0.86, d);
      s += `<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke-width=".5" stroke-dasharray="2 5"/>`;
    }
    for (let i = 0; i < 12; i++) { const [x, y] = at(cx, cy, R * 0.74, i * 30 + 15); s += rune(x, y, i, i * 30 + 105, G, 1); }
    return s + "</g>";
  };
  rings += astro(890, 120, 300, 0.07) + astro(90, 640, 220, 0.05);
  piece("WindowBG", W, H, `
   <linearGradient id="bgv" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#121722"/><stop offset=".35" stop-color="#0b0f16"/><stop offset="1" stop-color="#06080b"/></linearGradient>
   <filter id="noise"><feTurbulence type="fractalNoise" baseFrequency=".9" numOctaves="2" seed="7"/><feColorMatrix values="0 0 0 0 .8  0 0 0 0 .7  0 0 0 0 .5  0 0 0 .07 0"/></filter>
   <filter id="cloud"><feTurbulence type="fractalNoise" baseFrequency=".006 .012" numOctaves="4" seed="3"/><feColorMatrix values="0 0 0 0 .40  0 0 0 0 .42  0 0 0 0 .40  0 0 0 .16 -.03"/></filter>
   <radialGradient id="vig" cx=".5" cy=".42" r=".75"><stop offset=".55" stop-color="#000" stop-opacity="0"/><stop offset="1" stop-color="#000" stop-opacity=".65"/></radialGradient>
   <rect width="${W}" height="${H}" fill="url(#bgv)"/>
   <rect width="${W}" height="${H}" filter="url(#cloud)"/>
   <ellipse cx="${W / 2}" cy="-30" rx="${W * 0.55}" ry="190" fill="url(#haze)" opacity=".22"/>
   ${rings}
   <rect width="${W}" height="${H}" filter="url(#noise)"/>
   <rect width="${W}" height="${H}" fill="url(#vig)"/>`, true);
}

// ---------------------------------------------------------------- canto da moldura (superior esquerdo; o jogo espelha)
{
  const S = 128;
  const curl = (sx, sy) => { // voluta nas duas pernas (sy=1 horizontal, sx=1 vertical)
    const T = (x, y) => sx ? `${f(y)} ${f(x)}` : `${f(x)} ${f(y)}`;
    return `<path d="M${T(40, 14)} C${T(58, 14)} ${T(70, 22)} ${T(66, 31)} C${T(62, 39)} ${T(50, 36)} ${T(53, 29)} C${T(55, 25)} ${T(61, 26)} ${T(60, 30)}" fill="none" stroke="url(#gold)" stroke-width="1.3" stroke-linecap="round"/>
     <path d="M${T(66, 31)} C${T(74, 40)} ${T(90, 20)} ${T(104, 14)}" fill="none" stroke="${G}" stroke-width=".8" opacity=".8"/>
     ${(() => { const [a, b] = sx ? [96, 7] : [7, 96]; return diamond(a, b, 2.4, `fill="${GL}"`); })()}`;
  };
  piece("Corner", S, S, `
   <path d="M1.5 ${S} V30 L30 1.5 H${S}" fill="none" stroke="url(#gold)" stroke-width="2"/>
   <path d="M6.5 ${S} V36 L36 6.5 H${S}" fill="none" stroke="${G}" stroke-width=".9" opacity=".65"/>
   <path d="M12 ${S - 10} V42 L42 12 H${S - 10}" fill="none" stroke="${G}" stroke-width=".6" opacity=".35" stroke-dasharray="1 4"/>
   ${curl(0, 1)}${curl(1, 0)}
   <circle cx="20" cy="20" r="15" fill="url(#haze)" opacity=".7"/>
   <g filter="url(#g3)">${diamond(19, 19, 11, `fill="${GD}" stroke="${GL}" stroke-width="1.2"`)}</g>
   ${facet(19, 19, 7.5, 7.5, ["#fff1c2", AM, AMD, "#d39a3a"])}
   ${diamond(19, 19, 11, `fill="none" stroke="${GL}" stroke-width="1.1"`)}`);
}

// ---------------------------------------------------------------- brasão do topo (centro preso na borda superior, y = 30)
{
  const W = 340, H = 60, cx = W / 2, cy = 30;
  piece("Crest", W, H, `
   <ellipse cx="${cx}" cy="${cy}" rx="120" ry="22" fill="url(#haze)" opacity=".45"/>
   <path d="M0 ${cy} H${cx - 40}" stroke="url(#goldH)" stroke-width="1.6" transform="translate(${-cx / 2 + 20} 0) scale(1.5 1)" opacity=".0"/>
   <path d="M10 ${cy} H${cx - 34}" stroke="${G}" stroke-width="1.4" opacity=".9"/>
   <path d="M${cx + 34} ${cy} H${W - 10}" stroke="${G}" stroke-width="1.4" opacity=".9"/>
   <path d="M${cx - 34} ${cy} C${cx - 60} ${cy - 14} ${cx - 92} ${cy - 10} ${cx - 120} ${cy - 3}" fill="none" stroke="url(#gold)" stroke-width="1.4"/>
   <path d="M${cx + 34} ${cy} C${cx + 60} ${cy - 14} ${cx + 92} ${cy - 10} ${cx + 120} ${cy - 3}" fill="none" stroke="url(#gold)" stroke-width="1.4"/>
   <path d="M${cx - 34} ${cy} C${cx - 58} ${cy + 12} ${cx - 84} ${cy + 9} ${cx - 104} ${cy + 3}" fill="none" stroke="${G}" stroke-width=".9" opacity=".8"/>
   <path d="M${cx + 34} ${cy} C${cx + 58} ${cy + 12} ${cx + 84} ${cy + 9} ${cx + 104} ${cy + 3}" fill="none" stroke="${G}" stroke-width=".9" opacity=".8"/>
   ${diamond(cx - 128, cy - 2, 3, `fill="${GL}"`)}${diamond(cx + 128, cy - 2, 3, `fill="${GL}"`)}
   ${diamond(10, cy, 2.5, `fill="${G}"`)}${diamond(W - 10, cy, 2.5, `fill="${G}"`)}
   <g filter="url(#g3)">${diamond(cx, cy, 26, `fill="${INK}" stroke="${GL}" stroke-width="1.6"`)}</g>
   ${diamond(cx, cy, 21, `fill="none" stroke="${G}" stroke-width=".8" opacity=".8"`)}
   ${facet(cx, cy, 13, 16, ["#fff1c2", AM, AMD, "#d39a3a"])}
   ${diamond(cx - 30, cy, 4, `fill="${GL}"`)}${diamond(cx + 30, cy, 4, `fill="${GL}"`)}`);
}

// ---------------------------------------------------------------- centro do divisor (as linhas saem do código)
{
  const W = 150, H = 22, cx = W / 2, cy = H / 2;
  piece("DividerCenter", W, H, `
   <path d="M0 ${cy} H${cx - 18}" stroke="url(#goldH)" stroke-width="1"/>
   <path d="M${cx + 18} ${cy} H${W}" stroke="url(#goldH)" stroke-width="1"/>
   ${diamond(cx - 26, cy, 2.5, `fill="${G}"`)}${diamond(cx + 26, cy, 2.5, `fill="${G}"`)}
   <circle cx="${cx - 38}" cy="${cy}" r="1.2" fill="${G}"/><circle cx="${cx + 38}" cy="${cy}" r="1.2" fill="${G}"/>
   ${diamond(cx, cy, 9.5, `fill="${INK}" stroke="${GL}" stroke-width="1.2"`)}
   <g filter="url(#g1)">${facet(cx, cy, 5, 5, ["#fff1c2", AM, AMD, "#d39a3a"])}</g>`);
}

// ---------------------------------------------------------------- emblema de boas-vindas + anel de runas (gira)
{
  const S = 220, c = S / 2;
  let s = `<circle cx="${c}" cy="${c}" r="104" fill="url(#haze)" opacity=".35"/>
   <circle cx="${c}" cy="${c}" r="98" fill="none" stroke="url(#gold)" stroke-width="1.6"/>
   <circle cx="${c}" cy="${c}" r="92" fill="none" stroke="${G}" stroke-width=".7" opacity=".7"/>`;
  for (let d = 0; d < 360; d += 7.5) {
    const l = d % 45 === 0 ? 9 : 4;
    const [x1, y1] = at(c, c, 92, d), [x2, y2] = at(c, c, 92 - l, d);
    s += `<line x1="${f(x1)}" y1="${f(y1)}" x2="${f(x2)}" y2="${f(y2)}" stroke="${G}" stroke-width=".8"/>`;
  }
  s += `<circle cx="${c}" cy="${c}" r="66" fill="${INK}" fill-opacity=".55" stroke="${G}" stroke-width=".9"/>`;
  // estrela de 8 pontas: faces clara/escura
  const ray = (d, len, w) => {
    const tip = at(c, c, len, d), l = at(c, c, w, d - 90), r = at(c, c, w, d + 90);
    return `<polygon points="${f(c)},${f(c)} ${tip.map(f)} ${l.map(f)}" fill="${GL}"/><polygon points="${f(c)},${f(c)} ${tip.map(f)} ${r.map(f)}" fill="${GD}"/>`;
  };
  for (let d = 45; d < 360; d += 90) s += ray(d - 90, 62, 9);
  for (let d = 0; d < 360; d += 90) s += ray(d - 90, 90, 13);
  s += `<circle cx="${c}" cy="${c}" r="22" fill="${INK}" stroke="${GL}" stroke-width="1.4"/>
   <g filter="url(#g3)">${facet(c, c, 12, 15, ["#fff1c2", AM, AMD, "#d39a3a"])}</g>`;
  piece("Emblem", S, S, s);

  const R = 256, rc = R / 2;
  let r = `<circle cx="${rc}" cy="${rc}" r="122" fill="none" stroke="#fff" stroke-width="1" opacity=".55"/>
   <circle cx="${rc}" cy="${rc}" r="108" fill="none" stroke="#fff" stroke-width=".6" opacity=".35" stroke-dasharray="1 6"/>`;
  for (let i = 0; i < 16; i++) { const [x, y] = at(rc, rc, 115, i * 22.5); r += rune(x, y, i, i * 22.5 + 90, "#fff", 0.8); }
  for (let i = 0; i < 4; i++) { const [x, y] = at(rc, rc, 122, i * 90 + 45); r += diamond(x, y, 4, `fill="#fff"`); }
  piece("EmblemRing", R, R, r);
}

// ---------------------------------------------------------------- etapas: engaste dourado, gema (tingida) e anel (gira)
{
  const S = 64, c = S / 2;
  piece("StepMount", S, S, `
   <g filter="url(#g1)">${diamond(c, c, 26, `fill="none" stroke="url(#gold)" stroke-width="2"`)}</g>
   ${diamond(c, c, 21, `fill="${INK}" fill-opacity=".85" stroke="${G}" stroke-width=".8"`)}
   ${diamond(c, c - 29, 2.5, `fill="${GL}"`)}${diamond(c, c + 29, 2.5, `fill="${GL}"`)}
   ${diamond(c - 29, c, 2.5, `fill="${GL}"`)}${diamond(c + 29, c, 2.5, `fill="${GL}"`)}`);
  piece("StepGem", 40, 40, facet(20, 20, 17, 17, ["#ffffff", "#c9c9c9", "#7a7a7a", "#a5a5a5"]) +
    `<polygon points="20,7 31,20 20,33 9,20" fill="none" stroke="#fff" stroke-width=".8" opacity=".6"/>`);
  const R = 110, rc = R / 2;
  let r = `<circle cx="${rc}" cy="${rc}" r="44" fill="none" stroke="#fff" stroke-width="1" opacity=".7" stroke-dasharray="10 4 2 4"/>
   <circle cx="${rc}" cy="${rc}" r="50" fill="none" stroke="#fff" stroke-width=".6" opacity=".35"/>`;
  for (let i = 0; i < 8; i++) { const [x, y] = at(rc, rc, 50, i * 45); r += diamond(x, y, i % 2 ? 1.8 : 3, `fill="#fff"`); }
  piece("StepRing", R, R, r);
}

// ---------------------------------------------------------------- cantoneira dos cartões (superior esquerdo)
piece("CardCorner", 18, 18, `
  <path d="M1.5 17 V5 L5 1.5 H17" fill="none" stroke="${GL}" stroke-width="1.4"/>
  ${diamond(4.5, 4.5, 1.8, `fill="${AM}"`)}`);

// ---------------------------------------------------------------- seleção da navegação do painel (tingida)
{
  const W = 240, H = 36;
  piece("NavSel", W, H, `
   <linearGradient id="nf" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff" stop-opacity=".30"/><stop offset=".55" stop-color="#fff" stop-opacity=".08"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
   <linearGradient id="nl" x1="0" y1="0" x2="1" y2="0"><stop offset="0" stop-color="#fff" stop-opacity=".9"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></linearGradient>
   <rect x="0" y="1" width="${W}" height="${H - 2}" fill="url(#nf)"/>
   <rect x="0" y="0.5" width="${W * 0.8}" height=".8" fill="url(#nl)" opacity=".6"/>
   <rect x="0" y="${H - 1.3}" width="${W * 0.8}" height=".8" fill="url(#nl)" opacity=".6"/>
   <g filter="url(#g1)"><rect x="0" y="4" width="3" height="${H - 8}" fill="#fff"/></g>
   ${diamond(3, H / 2, 5, `fill="#fff"`)}`);
}

// ---------------------------------------------------------------- brilho do cartão escolhido (tingido; esticado)
piece("CardGlow", 256, 128, `
  <radialGradient id="cg" cx=".5" cy="0" r=".9"><stop offset="0" stop-color="#fff" stop-opacity=".35"/><stop offset="1" stop-color="#fff" stop-opacity="0"/></radialGradient>
  <rect width="256" height="128" fill="url(#cg)"/>`);

// ================================================================ página -> TGA
const GAP = 8, PAGE_W = 1100;
let x = GAP, y = GAP, rowH = 0;
for (const p of P) {
  if (x + p.w + GAP > PAGE_W) { x = GAP; y += rowH + GAP; rowH = 0; }
  p.x = x; p.y = y; x += p.w + GAP; rowH = Math.max(rowH, p.h);
}
const PAGE_H = y + rowH + GAP;
const html = `<!doctype html><html><head><meta charset="utf-8"><style>
html,body{margin:0;background:transparent;overflow:hidden}.p{position:absolute;overflow:hidden}
</style></head><body>${P.map((p) => `<div class="p" style="left:${p.x}px;top:${p.y}px;width:${p.w}px;height:${p.h}px">${p.html}</div>`).join("\n")}</body></html>`;
const htmlFile = path.join(DIR, "pieces.html"), pngFile = path.join(DIR, "pieces.png");
fs.writeFileSync(htmlFile, html);
if (fs.existsSync(pngFile)) fs.unlinkSync(pngFile);
const profile = path.join(require("os").tmpdir(), "azaath_edge_" + Date.now());
spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--user-data-dir=" + profile, "--no-first-run", "--hide-scrollbars", "--default-background-color=00000000",
  "--force-device-scale-factor=" + SCALE, "--window-size=" + PAGE_W + "," + PAGE_H, "--virtual-time-budget=2000",
  "--allow-file-access-from-files", "--screenshot=" + pngFile, "file:///" + htmlFile.replace(/\\/g, "/")], { stdio: "ignore" });
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
if (!fs.existsSync(pngFile)) { console.log("o Edge não gravou o print (rodar fora do sandbox)"); process.exit(1); }
const page = readPNG(pngFile);
console.log("página", page.w + "x" + page.h, "(esperado", PAGE_W * SCALE + "x" + PAGE_H * SCALE + ")");
for (const d of OUTS) { try { fs.mkdirSync(d, { recursive: true }); } catch (e) { /* pasta do jogo ausente */ } }
for (const p of P) {
  let im = I.crop(page, p.x * SCALE, p.y * SCALE, p.w * SCALE, p.h * SCALE);
  if (p.half) im = I.resize(im, p.w, p.h);
  for (const d of OUTS) { try { I.writeTGA(path.join(d, p.name + ".tga"), im); } catch (e) { console.log("falhou", d, e.message); } }
}
// prévia: peças sobre o fundo escuro do painel
const prev = I.create(page.w, page.h, 9, 12, 16, 255);
for (let i = 0; i < page.w * page.h; i++) {
  const a = page.px[i * 4 + 3] / 255;
  for (let k = 0; k < 3; k++) prev.px[i * 4 + k] = prev.px[i * 4 + k] * (1 - a) + page.px[i * 4 + k] * a;
}
I.writePNG(path.join(DIR, "preview.png"), prev);
console.log(P.length, "texturas gravadas em Media/ConfigUI");
