// Gera as texturas cartográficas transparentes dos mares do mapa-múndi (aprovadas em
// sea_cartography_concept_epic.png):
//   · SeaChartL.tga / SeaChartR.tga  (1357 x 1462 cada, 2x) — vinheta oceânica, batimetria
//     costeira, grade náutica, equador 0°, linhas loxodrômicas, rotas marítimas, rosa dos
//     ventos (N/E/S/W), escala náutica, A Voragem, Serpente Marinha, Baleia Abissal e 2 naus,
//     com alfa=0 sobre os continentes e ilhas.
//   · SeaLabelsL.tga / SeaLabelsR.tga (1357 x 1462 cada, 2x) — nomes dos 12 mares em
//     IMFell-Italic branco com sombra marítima.
// Uso: node tools/map-ui-concept/gen-sea.js
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const DIR = __dirname;
const ROOT = path.resolve(DIR, "../..");
const OUTS = [
  path.join(ROOT, "AzaathUI/Media/MapFrame"),
  "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame",
];
const BRAIN_DIR = "C:/Users/Novo Usuario/.gemini/antigravity/brain/69d5aa7a-b8d8-4d93-b667-31530cdd95d2";
const BASE_IMG = "file:///" + path.join(BRAIN_DIR, ".user_uploaded/media_1795000719968_fac2cd85.jpg").replace(/\\/g, "/");
const ART_IMG = "file:///" + path.join(BRAIN_DIR, "epic_ocean_backdrop_seamless_1795001672304.jpg").replace(/\\/g, "/");
const DIRECT_IMG = "file:///" + path.join(BRAIN_DIR, "epic_map_direct_1795001655684.jpg").replace(/\\/g, "/");
const FONTS_DIR = "file:///" + path.join(ROOT, "AzaathUI/Media/Fonts").replace(/\\/g, "/");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";

const W = 1365;
const H = 768;
const SCALE = 2;

// Retângulo da área visível do mapa (S.view) na captura 1365x768, em texels 2x:
const VX = 8, VY = 68, VW = 2714, VH = 1462;
const HALF_W = VW / 2; // 1357

function rhumbLines(cx, cy, dirs, maxLen, stroke, opacity) {
  const lines = [];
  for (let i = 0; i < dirs; i++) {
    const a = (i * 360 / dirs) * Math.PI / 180;
    const x1 = (cx + 26 * Math.cos(a)).toFixed(1);
    const y1 = (cy + 26 * Math.sin(a)).toFixed(1);
    const x2 = (cx + maxLen * Math.cos(a)).toFixed(1);
    const y2 = (cy + maxLen * Math.sin(a)).toFixed(1);
    const op = (i % (dirs / 4) === 0) ? (opacity * 1.4).toFixed(3) : opacity.toFixed(3);
    lines.push(`<line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}" stroke="${stroke}" stroke-width="0.75" opacity="${op}"/>`);
  }
  return lines.join("");
}

function nauticalGrid() {
  const out = [];
  for (let x = 100; x <= 1300; x += 150) {
    out.push(`<line x1="${x}" y1="30" x2="${x}" y2="742" stroke="#d4e6f8" stroke-width="0.55" stroke-dasharray="3 8" opacity="0.09"/>`);
  }
  for (let y = 110; y <= 690; y += 115) {
    out.push(`<line x1="48" y1="${y}" x2="1350" y2="${y}" stroke="#d4e6f8" stroke-width="0.55" stroke-dasharray="3 8" opacity="0.09"/>`);
  }
  out.push(`<line x1="48" y1="374" x2="1350" y2="374" stroke="#dfeeff" stroke-width="0.65" opacity="0.12"/>`);
  out.push(`<line x1="48" y1="378" x2="1350" y2="378" stroke="#dfeeff" stroke-width="0.65" stroke-dasharray="10 6" opacity="0.12"/>`);
  for (let x = 80; x <= 1330; x += 30) {
    out.push(`<line x1="${x}" y1="372" x2="${x}" y2="380" stroke="#e4f2ff" stroke-width="0.55" opacity="0.14"/>`);
  }
  out.push(`<text x="1336" y="370" text-anchor="end" font-family="CinzelR" font-size="8" fill="#d8ecff" opacity="0.34">0°</text>`);
  return out.join("");
}

function scaleBar(x, y) {
  const seg = 26;
  return `<g transform="translate(${x},${y})">
    <text x="${seg * 2.5}" y="-6" text-anchor="middle" font-family="CinzelR" font-size="8" letter-spacing="1.6" fill="#e8e1cc" opacity="0.68">LÉGUAS NÁUTICAS</text>
    <rect x="0" y="0" width="${seg * 5}" height="5" fill="none" stroke="#e8e1cc" stroke-width="0.85" opacity="0.58"/>
    <rect x="0" y="0" width="${seg}" height="5" fill="#e8e1cc" opacity="0.48"/>
    <rect x="${seg * 2}" y="0" width="${seg}" height="5" fill="#e8e1cc" opacity="0.48"/>
    <rect x="${seg * 4}" y="0" width="${seg}" height="5" fill="#e8e1cc" opacity="0.48"/>
    <line x1="0" y1="0" x2="0" y2="8" stroke="#e8e1cc" stroke-width="0.8" opacity="0.58"/>
    <line x1="${seg * 2}" y1="0" x2="${seg * 2}" y2="8" stroke="#e8e1cc" stroke-width="0.8" opacity="0.58"/>
    <line x1="${seg * 5}" y1="0" x2="${seg * 5}" y2="8" stroke="#e8e1cc" stroke-width="0.8" opacity="0.58"/>
    <text x="0" y="16" text-anchor="middle" font-family="CinzelR" font-size="7.5" fill="#e8e1cc" opacity="0.62">0</text>
    <text x="${seg * 2}" y="16" text-anchor="middle" font-family="CinzelR" font-size="7.5" fill="#e8e1cc" opacity="0.62">150</text>
    <text x="${seg * 5}" y="16" text-anchor="middle" font-family="CinzelR" font-size="7.5" fill="#e8e1cc" opacity="0.62">375</text>
  </g>`;
}

function seaLabel(text, x, y, size, opts = {}) {
  const op = opts.op || 0.95;
  const ls = opts.ls || (size >= 20 ? "2.0" : "1.0");
  const flourish = opts.flourish
    ? `<path d="M${x - 165} ${y - 8} Q${x - 135} ${y - 14} ${x - 110} ${y - 8}" fill="none" stroke="#ffffff" stroke-width="0.85" opacity="0.35"/>` +
      `<path d="M${x - 104} ${y - 8} l3 -3 l3 3 l-3 3 Z" fill="#ffffff" opacity="0.45"/>` +
      `<path d="M${x + 110} ${y - 8} Q${x + 135} ${y - 14} ${x + 165} ${y - 8}" fill="none" stroke="#ffffff" stroke-width="0.85" opacity="0.35"/>` +
      `<path d="M${x + 104} ${y - 8} l-3 -3 l-3 3 l3 3 Z" fill="#ffffff" opacity="0.45"/>`
    : "";
  return `${flourish}<text x="${x}" y="${y}" text-anchor="middle" font-family="IMFellI" font-style="italic" font-size="${size}" letter-spacing="${ls}" fill="#ffffff" fill-opacity="${op}" filter="url(#seaShadow)">${text}</text>`;
}

const seaOverlaySvg = `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">
<defs>
  <filter id="seaShadow" x="-25%" y="-35%" width="150%" height="170%">
    <feDropShadow dx="0" dy="1.8" stdDeviation="2.8" flood-color="#030a15" flood-opacity="0.96"/>
  </filter>
  <radialGradient id="oceanVignette" cx="50%" cy="50%" r="74%">
    <stop offset="35%" stop-color="#1c3b62" stop-opacity="0.14"/>
    <stop offset="100%" stop-color="#071222" stop-opacity="0.48"/>
  </radialGradient>
</defs>

<rect x="4" y="34" width="${W - 8}" height="${H - 37}" fill="url(#oceanVignette)"/>
${nauticalGrid()}
${rhumbLines(150, 392, 16, 1300, "#d8ecff", 0.105)}
${rhumbLines(1232, 412, 16, 1300, "#d8ecff", 0.095)}
${rhumbLines(688, 368, 16, 850, "#9ae2ef", 0.095)}

<path d="M362 224 Q555 162 746 286 T878 392" fill="none" stroke="#e4f2ff" stroke-width="1.15" stroke-dasharray="5 6" opacity="0.28"/>
<path d="M476 488 Q622 572 762 532 T882 622" fill="none" stroke="#e4f2ff" stroke-width="1.15" stroke-dasharray="5 6" opacity="0.28"/>
<path d="M165 268 Q202 315 268 348" fill="none" stroke="#e4f2ff" stroke-width="0.95" stroke-dasharray="4 5" opacity="0.22"/>

<text x="150" y="302" text-anchor="middle" font-family="CinzelB" font-size="11.5" fill="#e5c57e" opacity="0.92" filter="url(#seaShadow)">N</text>
<text x="232" y="396" text-anchor="middle" font-family="CinzelR" font-size="10.5" fill="#e8e2d0" opacity="0.80" filter="url(#seaShadow)">E</text>
<text x="150" y="487" text-anchor="middle" font-family="CinzelR" font-size="10.5" fill="#e8e2d0" opacity="0.80" filter="url(#seaShadow)">S</text>
<text x="68"  y="396" text-anchor="middle" font-family="CinzelR" font-size="10.5" fill="#e8e2d0" opacity="0.80" filter="url(#seaShadow)">W</text>

${scaleBar(82, 706)}
</svg>`;

const labelsSvg = `<svg width="${W}" height="${H}" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg">
<defs>
  <filter id="seaShadow" x="-25%" y="-35%" width="150%" height="170%">
    <feDropShadow dx="0" dy="1.8" stdDeviation="2.6" flood-color="#030a15" flood-opacity="0.96"/>
  </filter>
</defs>

${seaLabel("O Grande Mar", 690, 224, 28, { op: 0.97, ls: "2.3", flourish: true })}
${seaLabel("Mar Velado", 152, 114, 24, { op: 0.95, ls: "2.0" })}
${seaLabel("Mar Proibido", 1228, 128, 24, { op: 0.95, ls: "2.0" })}
${seaLabel("Mares do Sul", 688, 668, 24, { op: 0.95, ls: "2.0" })}
${seaLabel("Mar do Norte", 688, 64, 21, { op: 0.93, ls: "1.8" })}

${seaLabel("A Voragem", 688, 466, 16, { op: 0.93, ls: "1.3" })}
${seaLabel("Mar Gelado", 428, 108, 15, { op: 0.88 })}
${seaLabel("Golfo de Lordaeron", 776, 258, 14, { op: 0.88 })}
${seaLabel("Canal das Marés", 544, 434, 14, { op: 0.88 })}
${seaLabel("Mar das Brumas", 216, 680, 14, { op: 0.88 })}
${seaLabel("Baía da Tempestade", 1152, 492, 14, { op: 0.88 })}
${seaLabel("Enseada dos Mercadores", 764, 588, 14, { op: 0.88 })}
</svg>`;

function buildChartHtml() {
  return `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
@font-face { font-family: CinzelR; src: url("${FONTS_DIR}/Cinzel-Regular.ttf"); }
@font-face { font-family: CinzelB; src: url("${FONTS_DIR}/Cinzel-Bold.ttf"); }
html, body {
  margin: 0; padding: 0; width: ${W}px; height: ${H}px; overflow: hidden; background: transparent;
}
#chartStage {
  position: relative; width: ${W}px; height: ${H}px;
}
canvas, .svgLayer {
  position: absolute; left: 0; top: 0; width: ${W}px; height: ${H}px; pointer-events: none;
}
</style>
</head>
<body>
<div id="chartStage">
  <canvas id="coastCanvas" width="${W}" height="${H}"></canvas>
  <div class="svgLayer">${seaOverlaySvg}</div>
  <canvas id="artCanvas" width="${W}" height="${H}"></canvas>
</div>
<script>
const baseImg = new Image();
const artImg = new Image();
const directImg = new Image();
let loaded = 0;

function onAllLoaded() {
  if (++loaded < 3) return;
  const W = ${W}, H = ${H};
  const stage = document.getElementById("chartStage");
  const coast = document.getElementById("coastCanvas");
  const art = document.getElementById("artCanvas");
  const cctx = coast.getContext("2d");
  const actx = art.getContext("2d");

  // 1) Lê continentes a partir da captura (restrito exclusivamente às caixas de Kalimdor e Reinos do Leste)
  const ref = document.createElement("canvas");
  ref.width = W; ref.height = H;
  const rctx = ref.getContext("2d");
  rctx.drawImage(baseImg, 0, 0, W, H);
  const d = rctx.getImageData(0, 0, W, H).data;

  const landMask = new Uint8Array(W * H);
  const maskCanvas = document.createElement("canvas");
  maskCanvas.width = W; maskCanvas.height = H;
  const mctx = maskCanvas.getContext("2d");
  const maskImg = mctx.createImageData(W, H);
  const md = maskImg.data;

  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      const idx = y * W + x;
      const i = idx * 4;
      md[i] = 0; md[i + 1] = 0; md[i + 2] = 0; md[i + 3] = 255;

      const inKalimdor = (x >= 240 && x <= 555 && y >= 95 && y <= 700);
      const inEK = (x >= 820 && x <= 1125 && y >= 155 && y <= 675);
      if (!inKalimdor && !inEK) continue;

      const r = d[i], g = d[i + 1], b = d[i + 2];
      const dist = Math.hypot(r - 22, g - 43, b - 74);
      if (dist > 15) {
        const landAlpha = dist >= 28 ? 255 : Math.round(((dist - 15) / 13) * 255);
        md[i + 3] = 255 - landAlpha; // 0 na terra, 255 no mar
        if (landAlpha > 128) landMask[idx] = 1;
      }
    }
  }
  mctx.putImageData(maskImg, 0, 0);
  stage.style.webkitMaskImage = "url(" + maskCanvas.toDataURL("image/png") + ")";
  stage.style.webkitMaskSize = W + "px " + H + "px";
  stage.style.webkitMaskRepeat = "no-repeat";

  // 2) Batimetria costeira ao redor dos continentes
  const distField = new Uint8Array(W * H);
  distField.fill(255);
  const queue = new Int32Array(W * H);
  let head = 0, tail = 0;
  for (let idx = 0; idx < W * H; idx++) {
    if (landMask[idx]) { distField[idx] = 0; queue[tail++] = idx; }
  }
  const MAX_D = 24;
  while (head < tail) {
    const cur = queue[head++];
    const cd = distField[cur];
    if (cd >= MAX_D) continue;
    const x = cur % W, y = (cur / W) | 0;
    const nd = cd + 1;
    if (x > 0 && distField[cur - 1] > nd) { distField[cur - 1] = nd; queue[tail++] = cur - 1; }
    if (x < W - 1 && distField[cur + 1] > nd) { distField[cur + 1] = nd; queue[tail++] = cur + 1; }
    if (y > 0 && distField[cur - W] > nd) { distField[cur - W] = nd; queue[tail++] = cur - W; }
    if (y < H - 1 && distField[cur + W] > nd) { distField[cur + W] = nd; queue[tail++] = cur + W; }
  }
  const cImg = cctx.createImageData(W, H);
  const cd = cImg.data;
  for (let y = 34; y < 765; y++) {
    for (let x = 4; x < 1361; x++) {
      const idx = y * W + x;
      const dist = distField[idx];
      if (dist === 0 || dist > MAX_D) continue;
      const i = idx * 4;
      let a = Math.max(0, 22 - dist) * 1.15;
      if (dist === 4 || dist === 5) a += 28;
      if (dist === 10 && ((x + y) % 5 !== 0)) a += 18;
      if (dist === 16 && ((x * 2 + y) % 7 < 4)) a += 12;
      cd[i] = 148; cd[i + 1] = 208; cd[i + 2] = 242;
      cd[i + 3] = Math.min(95, Math.round(a));
    }
  }
  cctx.putImageData(cImg, 0, 0);

  // 3) Sprites épicos (Rosa dos Ventos, Serpente, Voragem, Baleia e 2 Embarcações)
  const sheet = document.createElement("canvas");
  sheet.width = artImg.naturalWidth; sheet.height = artImg.naturalHeight;
  const sctx = sheet.getContext("2d"); sctx.drawImage(artImg, 0, 0);

  const directSheet = document.createElement("canvas");
  directSheet.width = directImg.naturalWidth; directSheet.height = directImg.naturalHeight;
  const dctx = directSheet.getContext("2d"); dctx.drawImage(directImg, 0, 0);

  function placeSprite(sx, sy, sw, sh, dx, dy, dw, dh, opts = {}) {
    const patch = (opts.ctx || sctx).getImageData(sx, sy, sw, sh);
    const pd = patch.data;
    const rs = [], gs = [], bs = [];
    for (let x = 0; x < sw; x += 3) for (const y of [2, sh - 3]) {
      const k = (y * sw + x) * 4; rs.push(pd[k]); gs.push(pd[k + 1]); bs.push(pd[k + 2]);
    }
    for (let y = 0; y < sh; y += 3) for (const x of [2, sw - 3]) {
      const k = (y * sw + x) * 4; rs.push(pd[k]); gs.push(pd[k + 1]); bs.push(pd[k + 2]);
    }
    const med = (arr) => arr.slice().sort((a, b) => a - b)[Math.floor(arr.length * 0.42)];
    const br = med(rs), bgc = med(gs), bb = med(bs);
    const bLum = 0.3 * br + 0.59 * bgc + 0.11 * bb;

    const feather = opts.feather || 24;
    const minDist = opts.minDist || 12;
    const maxDist = opts.maxDist || 32;
    const keepDarkCenter = opts.keepDarkCenter || false;

    for (let y = 0; y < sh; y++) {
      for (let x = 0; x < sw; x++) {
        const k = (y * sw + x) * 4;
        const r = pd[k], g = pd[k + 1], b = pd[k + 2];
        const lum = 0.3 * r + 0.59 * g + 0.11 * b;
        const cdist = Math.hypot(r - br, g - bgc, b - bb);
        const ex = Math.min(x, sw - 1 - x) / feather;
        const ey = Math.min(y, sh - 1 - y) / feather;
        const edgeFade = Math.max(0, Math.min(1, Math.min(ex, ey)));
        const nx = (x - sw / 2) / (sw / 2), ny = (y - sh / 2) / (sh / 2);
        const rad = Math.hypot(nx, ny);

        let a = 0;
        if (cdist > minDist) a = cdist >= maxDist ? 1 : (cdist - minDist) / (maxDist - minDist);
        if (keepDarkCenter && rad < 0.50 && lum < bLum) {
          a = Math.max(a, Math.max(0, 1 - rad / 0.50) * 0.92);
        }
        if (opts.ellipseFade && rad > 0.68) {
          const ef = Math.max(0, Math.min(1, (0.98 - rad) / 0.30));
          a *= ef * ef;
        }
        if (edgeFade < 1) {
          const brightBoost = Math.max(0, (lum - (bLum + 10)) / 30);
          a *= edgeFade * (0.30 + 0.70 * Math.min(1, brightBoost));
        }
        if (opts.maskFn) a *= opts.maskFn(x, y, sw, sh);
        if (opts.softRight && x > sw - 28) a *= ((sw - 1 - x) / 28);
        pd[k + 3] = Math.max(0, Math.min(255, Math.round(a * 255 * (opts.opacity || 0.96))));
      }
    }
    const tmp = document.createElement("canvas");
    tmp.width = sw; tmp.height = sh;
    tmp.getContext("2d").putImageData(patch, 0, 0);
    actx.save();
    actx.imageSmoothingEnabled = true;
    actx.imageSmoothingQuality = "high";
    actx.drawImage(tmp, dx - dw / 2, dy - dh / 2, dw, dh);
    actx.restore();
  }

  const smooth = (t) => { const c = Math.max(0, Math.min(1, t)); return c * c * (3 - 2 * c); };

  placeSprite(42,  240, 214, 240, 150, 392, 136, 152, { feather: 16, minDist: 14, maxDist: 28 });
  placeSprite(60,  540, 180, 136, 148, 585, 154, 116, { ctx: dctx, feather: 16, minDist: 14, maxDist: 30, opacity: 0.88 });
  placeSprite(482, 210, 412, 336, 688, 366, 220, 180, { feather: 36, minDist: 22, maxDist: 40, keepDarkCenter: true, ellipseFade: true });
  placeSprite(792, 496, 126, 122, 800, 476,  74,  72, {
    feather: 16, minDist: 16, maxDist: 30, opacity: 0.84,
    maskFn: (x, y) => (x < 30 && y < 34) ? smooth((x + y) / 42) : 1
  });
  placeSprite(1070, 8,   304, 250, 1236, 265, 152, 124, { feather: 18, minDist: 15, maxDist: 32, softRight: true, opacity: 0.82 });
  placeSprite(1062, 476, 206, 172, 1222, 575, 108,  90, { feather: 16, minDist: 15, maxDist: 30, opacity: 0.82 });
}

baseImg.onload = onAllLoaded;
artImg.onload = onAllLoaded;
directImg.onload = onAllLoaded;
baseImg.src = "${BASE_IMG}";
artImg.src = "${ART_IMG}";
directImg.src = "${DIRECT_IMG}";
</script>
</body>
</html>`;
}

function buildLabelsHtml() {
  return `<!doctype html>
<html>
<head>
<meta charset="utf-8">
<style>
@font-face { font-family: IMFellI; src: url("${FONTS_DIR}/IMFell-Italic.ttf"); font-style: italic; }
html, body { margin: 0; padding: 0; width: ${W}px; height: ${H}px; overflow: hidden; background: transparent; }
.svgLayer { position: absolute; left: 0; top: 0; width: ${W}px; height: ${H}px; }
</style>
</head>
<body><div class="svgLayer">${labelsSvg}</div></body>
</html>`;
}

function renderWithEdge(name, htmlContent) {
  const workDir = path.join(os.tmpdir(), "azaath_sea_render");
  fs.mkdirSync(workDir, { recursive: true });
  const htmlFile = path.join(workDir, name + ".html");
  const pngFile = path.join(workDir, name + ".png");
  fs.writeFileSync(htmlFile, htmlContent, "utf8");
  if (fs.existsSync(pngFile)) fs.unlinkSync(pngFile);

  const profile = path.join(os.tmpdir(), "azaath_edge_" + name + "_" + Date.now());
  spawnSync(
    EDGE,
    [
      "--headless=new",
      "--disable-gpu",
      "--user-data-dir=" + profile,
      "--no-first-run",
      "--hide-scrollbars",
      "--default-background-color=00000000",
      "--force-device-scale-factor=" + SCALE,
      "--window-size=" + W + "," + H,
      "--virtual-time-budget=3500",
      "--allow-file-access-from-files",
      "--screenshot=" + pngFile,
      "file:///" + htmlFile.replace(/\\/g, "/"),
    ],
    { stdio: "inherit" }
  );

  const t0 = Date.now();
  let last = -1;
  while (Date.now() - t0 < 25000) {
    const sz = fs.existsSync(pngFile) ? fs.statSync(pngFile).size : 0;
    if (sz > 0 && sz === last) break;
    last = sz;
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 300);
  }
  return readPNG(pngFile);
}

console.log("1/3 Renderizando camada cartográfica (SeaChart)...");
const chartFull = renderWithEdge("sea_chart", buildChartHtml());
console.log("   -> tamanho:", chartFull.w + "x" + chartFull.h);

console.log("2/3 Renderizando nomes dos mares (SeaLabels)...");
const labelsFull = renderWithEdge("sea_labels", buildLabelsHtml());
console.log("   -> tamanho:", labelsFull.w + "x" + labelsFull.h);

const pieces = [
  ["SeaChartL", I.crop(chartFull, VX, VY, HALF_W, VH)],
  ["SeaChartR", I.crop(chartFull, VX + HALF_W, VY, HALF_W, VH)],
  ["SeaLabelsL", I.crop(labelsFull, VX, VY, HALF_W, VH)],
  ["SeaLabelsR", I.crop(labelsFull, VX + HALF_W, VY, HALF_W, VH)],
];

for (const dir of OUTS) {
  try {
    fs.mkdirSync(dir, { recursive: true });
    for (const [name, im] of pieces) {
      const p = path.join(dir, name + ".tga");
      I.writeTGA(p, im);
      console.log("   gravado", p, fs.statSync(p).size, "bytes");
    }
  } catch (e) {
    console.warn("   AVISO ao gravar em", dir, ":", e.message);
  }
}

console.log("3/3 Gerando pré-visualização (preview-sea.png) a partir das texturas geradas...");
const tmpPrevDir = path.join(os.tmpdir(), "azaath_sea_render");
const chartViewPng = path.join(tmpPrevDir, "view_chart.png");
const labelsViewPng = path.join(tmpPrevDir, "view_labels.png");
I.writePNG(chartViewPng, I.crop(chartFull, VX, VY, VW, VH));
I.writePNG(labelsViewPng, I.crop(labelsFull, VX, VY, VW, VH));

const previewHtml = `<!doctype html>
<html>
<head><meta charset="utf-8"><style>
html, body { margin:0; padding:0; width:${W}px; height:${H}px; overflow:hidden; background:#162B4A; }
.wrap { position:relative; width:${W}px; height:${H}px; }
#base { position:absolute; left:0; top:0; width:${W}px; height:${H}px; }
#chart, #labels, #uiChrome { position:absolute; left:4px; top:34px; width:${VW / SCALE}px; height:${VH / SCALE}px; }
#uiChrome { left:0; top:0; width:${W}px; height:${H}px; }
</style></head>
<body><div class="wrap">
  <canvas id="base" width="${W}" height="${H}"></canvas>
  <img id="chart" src="file:///${chartViewPng.replace(/\\/g, "/")}"/>
  <img id="labels" src="file:///${labelsViewPng.replace(/\\/g, "/")}"/>
  <canvas id="uiChrome" width="${W}" height="${H}"></canvas>
</div><script>
const img = new Image();
img.onload = function() {
  const b = document.getElementById("base").getContext("2d");
  b.drawImage(img, 0, 0, ${W}, ${H});
  b.fillStyle = "#162B4A";
  b.fillRect(630, 366, 108, 36);
  // Preserva SOMENTE a moldura da UI (não os continentes!) para provar que o recorte de terra nos TGAs funciona
  const d = b.getImageData(0, 0, ${W}, ${H}).data;
  const u = document.getElementById("uiChrome").getContext("2d");
  const out = u.createImageData(${W}, ${H});
  const od = out.data;
  for (let y = 0; y < ${H}; y++) for (let x = 0; x < ${W}; x++) {
    const isChrome = y <= 32 || y >= 746 || x <= 14 || x >= 1351 ||
      (x <= 50 && y <= 440) || (x >= 1250 && y <= 112) || (x >= 460 && x <= 905 && y >= 705);
    if (!isChrome) continue;
    const i = (y * ${W} + x) * 4;
    od[i] = d[i]; od[i+1] = d[i+1]; od[i+2] = d[i+2]; od[i+3] = 255;
  }
  u.putImageData(out, 0, 0);
};
img.src = "${BASE_IMG}";
</script></body></html>`;

const prevFile = path.join(DIR, "preview-sea.png");
const prevPng = renderWithEdge("sea_preview", previewHtml);
I.writePNG(prevFile, prevPng);
console.log("Concluído:", prevFile, fs.statSync(prevFile).size, "bytes");
