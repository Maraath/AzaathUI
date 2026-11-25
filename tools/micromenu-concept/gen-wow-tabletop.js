// Arte conceitual 3 do Micro Menu — "Mesa de RPG & MicroBar Clássica do World of Warcraft".
// Usa texturas pintadas reais do projeto (mesa de madeira/velas, cantaria de pedra e ferro,
// pergaminho envelhecido, tiras de couro costurado, ícones 3D pintados e barra de latência).
// Uso: node tools/micromenu-concept/gen-wow-tabletop.js
"use strict";
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");
const { spawnSync } = require("child_process");
const { readTGA } = require("../map-extract/imagecodec.js");

const DIR = __dirname;
const ROOT = path.resolve(DIR, "../..");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const OUT_PNG = path.join(DIR, "concept-wow-tabletop.png");
const HTML_FILE = path.join(DIR, "concept-wow-tabletop.html");

// ------------------------------------------------------------------ Empacotadores de Assets
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
  icoExcl:    fileToUri(ICONS_DIR + "ExpPinNew.png", "image/png"),
};

const FONTS = "file:///" + path.join(ROOT, "AzaathUI/Media/Fonts").replace(/\\/g, "/");

const html = `<!doctype html>
<html lang="pt-BR"><head><meta charset="utf-8">
<style>
@font-face{font-family:Cinzel;src:url('${FONTS}/Cinzel-Regular.ttf')}
@font-face{font-family:CinzelB;src:url('${FONTS}/Cinzel-Bold.ttf')}
@font-face{font-family:PT;src:url('${FONTS}/PTSans-Regular.ttf')}
@font-face{font-family:PTB;src:url('${FONTS}/PTSans-Bold.ttf')}
@font-face{font-family:Fell;src:url('${FONTS}/IMFell-Italic.ttf')}
html,body{margin:0;padding:0;width:1920px;height:1080px;overflow:hidden;background:#0a0806}
canvas{display:block;width:1920px;height:1080px}
</style></head><body>
<canvas id="c" width="1920" height="1080"></canvas>
<script>
"use strict";
const ASSETS = ${JSON.stringify(ASSETS)};
const W = 1920, H = 1080;
const cv = document.getElementById("c");
const g = cv.getContext("2d");

function loadImg(src) {
  return new Promise((ok, no) => {
    const im = new Image();
    im.onload = () => ok(im);
    im.onerror = no;
    im.src = src;
  });
}

// Remove fundo preto externo via flood-fill preservando sombras internas
function cleanDarkBg(img, sx, sy, sw, sh, thresh = 26) {
  const c = document.createElement("canvas");
  c.width = sw; c.height = sh;
  const cx = c.getContext("2d");
  cx.drawImage(img, sx, sy, sw, sh, 0, 0, sw, sh);
  const id = cx.getImageData(0, 0, sw, sh);
  const d = id.data;
  const vis = new Uint8Array(sw * sh);
  const stack = [];
  for (let x = 0; x < sw; x++) { stack.push(x); stack.push((sh - 1) * sw + x); }
  for (let y = 0; y < sh; y++) { stack.push(y * sw); stack.push(y * sw + (sw - 1)); }
  const isBg = (i) => Math.max(d[i * 4], d[i * 4 + 1], d[i * 4 + 2]) < thresh;
  while (stack.length) {
    const p = stack.pop();
    if (vis[p] || !isBg(p)) continue;
    vis[p] = 1;
    d[p * 4 + 3] = 0;
    const x = p % sw, y = (p / sw) | 0;
    if (x > 0) stack.push(p - 1);
    if (x < sw - 1) stack.push(p + 1);
    if (y > 0) stack.push(p - sw);
    if (y < sh - 1) stack.push(p + sw);
  }
  for (let y = 1; y < sh - 1; y++) {
    for (let x = 1; x < sw - 1; x++) {
      const p = y * sw + x;
      if (vis[p]) continue;
      if (vis[p - 1] || vis[p + 1] || vis[p - sw] || vis[p + sw]) {
        const lum = Math.max(d[p * 4], d[p * 4 + 1], d[p * 4 + 2]);
        if (lum < thresh * 2.5) d[p * 4 + 3] = Math.round(d[p * 4 + 3] * Math.max(0.2, lum / (thresh * 2.5)));
      }
    }
  }
  cx.putImageData(id, 0, 0);
  return c;
}

function cropCanvas(img, sx, sy, sw, sh) {
  const c = document.createElement("canvas");
  c.width = sw; c.height = sh;
  c.getContext("2d").drawImage(img, sx, sy, sw, sh, 0, 0, sw, sh);
  return c;
}

function txt(str, x, y, o = {}) {
  g.save();
  g.font = o.font || "15px PT";
  g.fillStyle = o.color || "#f0e6d2";
  g.textAlign = o.align || "left";
  g.textBaseline = o.base || "middle";
  if (o.ls) g.letterSpacing = o.ls + "px";
  if (o.shadow !== false) {
    g.shadowColor = o.shadowCol || "rgba(0,0,0,0.92)";
    g.shadowOffsetX = o.sx ?? 1.5;
    g.shadowOffsetY = o.sy ?? 1.5;
    g.shadowBlur = o.blur || 2;
  }
  g.fillText(str, x, y);
  g.restore();
}

function rrPath(x, y, w, h, r) {
  g.beginPath();
  g.moveTo(x + r, y);
  g.arcTo(x + w, y, x + w, y + h, r);
  g.arcTo(x + w, y + h, x, y + h, r);
  g.arcTo(x, y + h, x, y, r);
  g.arcTo(x, y, x + w, y, r);
  g.closePath();
}

// Desenha dado de 20 lados (d20) de RPG de mesa em relevo realista
function drawD20(cx, cy, r, num = "20") {
  g.save();
  g.translate(cx, cy);
  // Sombra na mesa
  g.save();
  g.fillStyle = "rgba(0,0,0,0.65)";
  g.filter = "blur(6px)";
  g.beginPath(); g.ellipse(4, 10, r * 0.95, r * 0.65, 0, 0, Math.PI * 2); g.fill();
  g.restore();

  const pts = [];
  for (let i = 0; i < 6; i++) {
    const a = (i * 60 - 90) * Math.PI / 180;
    pts.push([Math.cos(a) * r, Math.sin(a) * r]);
  }
  const inner = [
    [0, -r * 0.44],
    [r * 0.40, r * 0.25],
    [-r * 0.40, r * 0.25],
  ];
  const tri = (a, b, c, col) => {
    g.beginPath();
    g.moveTo(a[0], a[1]); g.lineTo(b[0], b[1]); g.lineTo(c[0], c[1]);
    g.closePath();
    g.fillStyle = col; g.fill();
    g.strokeStyle = "#e7c072"; g.lineWidth = 1.1; g.stroke();
  };
  // Facetas externas sombreadas
  tri(pts[0], pts[1], inner[0], "#94232d");
  tri(pts[1], pts[2], inner[1], "#6b111b");
  tri(pts[1], inner[1], inner[0], "#b32d39");
  tri(pts[2], pts[3], inner[1], "#4a0b12");
  tri(pts[3], pts[4], inner[2], "#3d080d");
  tri(pts[3], inner[2], inner[1], "#751721");
  tri(pts[4], pts[5], inner[2], "#63131c");
  tri(pts[5], pts[0], inner[0], "#ab2d3a");
  tri(pts[5], inner[0], inner[2], "#8f212d");
  // Face central iluminada com número
  tri(inner[0], inner[1], inner[2], "#c93845");
  txt(num, 0, r * 0.06, { font: Math.round(r * 0.42) + "px CinzelB", color: "#ffe7a8", align: "center", shadowCol: "#2b0508", sx: 1, sy: 1, blur: 1 });
  g.restore();
}

// Slot vertical retrato estilo World of Warcraft (topo arqueado + chanfro 3D)
function drawWowSlot(x, y, w, h, sprite, opts = {}) {
  const { state = "idle", badge = null, isSysW = false, iconScale = 0.78 } = opts;
  const pressed = state === "active";
  const hovered = state === "hover";
  const r = Math.max(4, Math.round(w * 0.14));
  const arch = Math.max(4, Math.round(w * 0.13));

  const slotPath = (px, py, pw, ph) => {
    g.beginPath();
    g.moveTo(px + r, py + arch);
    g.quadraticCurveTo(px + pw / 2, py - arch * 0.35, px + pw - r, py + arch);
    g.lineTo(px + pw, py + arch + r);
    g.lineTo(px + pw, py + ph - r);
    g.arcTo(px + pw, py + ph, px + pw - r, py + ph, r);
    g.lineTo(px + r, py + ph);
    g.arcTo(px, py + ph, px, py + ph - r, r);
    g.lineTo(px, py + arch + r);
    g.closePath();
  };

  g.save();
  // Halo dourado WoW quando ativo ou hover
  if (pressed || hovered) {
    g.save();
    g.globalCompositeOperation = "lighter";
    const gr = g.createRadialGradient(x + w / 2, y + h / 2, 4, x + w / 2, y + h / 2, w * 1.15);
    gr.addColorStop(0, pressed ? "rgba(255,209,0,0.45)" : "rgba(255,200,90,0.25)");
    gr.addColorStop(1, "rgba(255,180,0,0)");
    g.fillStyle = gr;
    g.fillRect(x - w, y - h, w * 3, h * 3);
    g.restore();
  }

  // Sombra ou recuo físico
  if (!pressed) {
    g.save();
    slotPath(x + 1, y + 3, w, h);
    g.fillStyle = "rgba(0,0,0,0.75)";
    g.fill();
    g.restore();
  }

  // Fundo interno (couro/pedra escura ou poço aceso WoW)
  slotPath(x, y, w, h);
  const bg = g.createLinearGradient(0, y, 0, y + h);
  if (pressed) {
    bg.addColorStop(0, "#1c1306");
    bg.addColorStop(0.4, "#3b270b");
    bg.addColorStop(1, "#5c3b0e");
  } else if (hovered) {
    bg.addColorStop(0, "#332a20");
    bg.addColorStop(1, "#17130f");
  } else {
    bg.addColorStop(0, "#24211e");
    bg.addColorStop(0.55, "#151413");
    bg.addColorStop(1, "#0d0c0b");
  }
  g.fillStyle = bg;
  g.fill();

  // Clip interno para luz de topo / sombra de botão pressionado + ícone
  g.save();
  slotPath(x + 2, y + 2, w - 4, h - 4);
  g.clip();

  if (pressed) {
    // Sombra interna no topo (efeito afundado de botão pressionado do WoW)
    const sh = g.createLinearGradient(0, y, 0, y + h * 0.45);
    sh.addColorStop(0, "rgba(0,0,0,0.82)");
    sh.addColorStop(1, "rgba(0,0,0,0)");
    g.fillStyle = sh;
    g.fillRect(x, y, w, h * 0.45);
  } else {
    // Bisel iluminado superior (efeito botão saltado 3D do WoW)
    const hi = g.createLinearGradient(0, y, 0, y + h * 0.35);
    hi.addColorStop(0, "rgba(255,235,190,0.22)");
    hi.addColorStop(1, "rgba(255,235,190,0)");
    g.fillStyle = hi;
    g.fillRect(x, y, w, h * 0.35);
  }

  // Ícone pintado 3D
  const off = pressed ? 1.5 : 0;
  const maxS = Math.min(w, h) * iconScale;
  const sc = Math.min(maxS / sprite.width, maxS / sprite.height);
  const dw = sprite.width * sc, dh = sprite.height * sc;
  g.imageSmoothingQuality = "high";
  g.drawImage(sprite, x + (w - dw) / 2, y + arch * 0.35 + (h - dh) / 2 + off, dw, dh);

  // Selo [W] clássico do menu do WoW no canto superior
  if (isSysW) {
    const bw = Math.round(w * 0.42);
    g.fillStyle = "rgba(18,14,10,0.9)";
    g.beginPath(); g.arc(x + w / 2, y + h * 0.24, bw * 0.55, 0, Math.PI * 2); g.fill();
    g.strokeStyle = "#ffd100"; g.lineWidth = 1.2; g.stroke();
    txt("W", x + w / 2, y + h * 0.24 + 1, { font: Math.round(w * 0.27) + "px CinzelB", color: "#ffd100", align: "center" });
  }
  g.restore();

  // Moldura dupla metálica (ouro WoW no ativo/hover, bronze/ferro no normal)
  slotPath(x, y, w, h);
  const rim = g.createLinearGradient(0, y, 0, y + h);
  if (pressed) {
    rim.addColorStop(0, "#ffe97a"); rim.addColorStop(0.5, "#ffd100"); rim.addColorStop(1, "#a67114");
  } else if (hovered) {
    rim.addColorStop(0, "#ffe7a8"); rim.addColorStop(1, "#9c7432");
  } else {
    rim.addColorStop(0, "#b89b6a"); rim.addColorStop(0.45, "#6b5941"); rim.addColorStop(1, "#332c24");
  }
  g.strokeStyle = rim;
  g.lineWidth = pressed ? 2.8 : 2.0;
  g.stroke();

  // Rebite de bronze no topo do arco
  g.fillStyle = pressed ? "#ffd100" : "#cfa966";
  g.beginPath(); g.arc(x + w / 2, y + arch * 0.32, Math.max(1.8, w * 0.045), 0, Math.PI * 2); g.fill();

  // Badge numérica (moeda de latão & cera carmesim)
  if (badge) {
    const br = Math.max(9, Math.round(w * 0.21));
    const bx = x + w - 2, by = y + h - 4;
    g.fillStyle = "rgba(0,0,0,0.75)";
    g.beginPath(); g.arc(bx + 1, by + 2, br, 0, Math.PI * 2); g.fill();
    const bgB = g.createRadialGradient(bx - br * 0.3, by - br * 0.3, 1, bx, by, br);
    bgB.addColorStop(0, "#e33946"); bgB.addColorStop(1, "#6b0e17");
    g.fillStyle = bgB;
    g.beginPath(); g.arc(bx, by, br, 0, Math.PI * 2); g.fill();
    g.strokeStyle = "#f2cf7e"; g.lineWidth = 1.6; g.stroke();
    txt(badge, bx, by + 0.5, { font: Math.round(br * 1.15) + "px PTB", color: "#fff6db", align: "center" });
  }
  g.restore();
}

// Barra vertical de latência do WoW (MainMenuBarPerformanceBar)
function drawLatencyBar(x, y, w, h, ratio = 0.85) {
  g.save();
  rrPath(x, y, w, h, 3);
  g.fillStyle = "#16181c"; g.fill();
  g.strokeStyle = "#8a7553"; g.lineWidth = 1.5; g.stroke();
  const ih = Math.round((h - 6) * ratio);
  const gr = g.createLinearGradient(x, y + h - 3 - ih, x, y + h - 3);
  gr.addColorStop(0, "#8cff70");
  gr.addColorStop(0.5, "#36d936");
  gr.addColorStop(1, "#137a1b");
  g.fillStyle = gr;
  g.fillRect(x + 3, y + h - 3 - ih, w - 6, ih);
  // Reflexo vítreo vertical
  g.fillStyle = "rgba(255,255,255,0.28)";
  g.fillRect(x + 3, y + 3, Math.max(2, (w - 6) * 0.35), h - 6);
  g.restore();
}

// Calha completa da MicroBar estilo WoW (Pedra Cinzelada + Cantoneiras de Ferro + Couro)
function drawWowMicroBar(cx, cy, P, mainDefs, sysDefs, opts = {}) {
  const { collapsed = false, slotW = 50, slotH = 68, gap = 4 } = opts;
  const toggleW = 30;
  const latW = 14;
  const mainCount = collapsed ? 0 : mainDefs.length;
  const mainW = mainCount ? mainCount * slotW + (mainCount - 1) * gap : 0;
  const sysW = sysDefs.length * slotW + (sysDefs.length - 1) * gap;
  const innerW = (mainCount ? mainW + 10 : 0) + toggleW + 10 + sysW + 8 + latW;
  const barW = innerW + 36;
  const barH = slotH + 22;
  const x0 = cx - barW / 2, y0 = cy - barH / 2;

  g.save();
  // Sombra física projetada sobre a mesa
  g.save();
  g.fillStyle = "rgba(0,0,0,0.85)";
  g.filter = "blur(10px)";
  rrPath(x0 + 4, y0 + 8, barW, barH, 8);
  g.fill();
  g.restore();

  // Base em pedra escura com textura real do trilho de chrome_notitle.png
  g.save();
  rrPath(x0, y0, barW, barH, 6);
  g.clip();
  // Repetir a faixa de pedra cinzelada rebitada do chrome_notitle
  const patW = 360;
  for (let px = x0; px < x0 + barW; px += patW) {
    g.drawImage(P.stoneRail, 0, 0, P.stoneRail.width, P.stoneRail.height, px, y0, patW, barH);
  }
  // Escurecimento interno do poço onde os slots encaixam
  g.fillStyle = "rgba(8,7,6,0.55)";
  g.fillRect(x0 + 10, y0 + 7, barW - 20, barH - 14);
  g.restore();

  // Moldura externa em ferro & bronze
  rrPath(x0, y0, barW, barH, 6);
  g.strokeStyle = "#8c744c"; g.lineWidth = 2.2; g.stroke();
  rrPath(x0 + 3, y0 + 3, barW - 6, barH - 6, 4);
  g.strokeStyle = "#2b251f"; g.lineWidth = 1.4; g.stroke();

  // Cantoneiras esculpidas de ferro/pedra nas pontas esquerda e direita (de chrome_notitle)
  const capH = barH + 10, capW = 46;
  g.drawImage(P.cornerTL, x0 - 12, y0 - 6, capW, capH * 0.65);
  g.drawImage(P.cornerTR, x0 + barW - capW + 12, y0 - 6, capW, capH * 0.65);

  // Posicionar slots
  let curX = x0 + 18;
  const slotY = cy - slotH / 2 + 1;
  let activePos = null;

  if (!collapsed) {
    mainDefs.forEach((d) => {
      drawWowSlot(curX, slotY, slotW, slotH, d.sprite, {
        state: d.active ? "active" : "idle",
        badge: d.badge,
      });
      if (d.active) activePos = { x: curX + slotW / 2, y: slotY };
      curX += slotW + gap;
    });
    curX += 6;
  }

  // Fivela de couro costurado + setas de ferro (Toggle)
  const togX = curX;
  g.save();
  rrPath(togX, slotY + 4, toggleW, slotH - 8, 5);
  g.clip();
  g.drawImage(P.leatherTab, 0, 0, P.leatherTab.width, P.leatherTab.height, togX - 8, slotY, toggleW + 30, slotH);
  g.restore();
  rrPath(togX, slotY + 4, toggleW, slotH - 8, 5);
  g.strokeStyle = "#b89050"; g.lineWidth = 1.6; g.stroke();
  // Setas duplas (giradas conforme estado)
  g.save();
  g.translate(togX + toggleW / 2, cy);
  if (collapsed) g.rotate(Math.PI);
  g.drawImage(P.icoMax, -11, -11, 22, 22);
  g.restore();

  curX += toggleW + 10;

  // 3 slots de sistema
  sysDefs.forEach((d) => {
    drawWowSlot(curX, slotY, slotW, slotH, d.sprite, {
      state: "idle",
      isSysW: d.key === "menu",
    });
    curX += slotW + gap;
  });

  // Barra vertical de latência do WoW
  drawLatencyBar(curX + 4, slotY + 4, latW, slotH - 8, 0.86);

  g.restore();
  return { x0, y0, barW, barH, activePos, togX: togX + toggleW / 2 };
}

// Placar em Pergaminho Real Pintado + Cantoneiras de Pedra + Aba de Couro
function drawWowParchmentPlacard(cx, bottomY, P, data) {
  const pw = data.w || 430, ph = data.h || 176;
  const x = Math.round(cx - pw / 2), y = Math.round(bottomY - ph);

  g.save();
  // Sombra da folha de pergaminho sobre a mesa
  g.save();
  g.fillStyle = "rgba(0,0,0,0.82)";
  g.filter = "blur(12px)";
  rrPath(x + 4, y + 8, pw, ph, 8);
  g.fill();
  g.restore();

  // Aba de couro costurado espelhada para a direita com a tecla de atalho ([N] / [ESC])
  const tabW = 92, tabH = 42;
  const tabX = x + pw - 22, tabY = y + 22;
  g.save();
  g.translate(tabX + tabW, tabY);
  g.scale(-1, 1);
  g.drawImage(P.leatherTab, 0, 0, tabW, tabH);
  g.restore();
  txt(data.key, tabX + tabW * 0.48, tabY + tabH / 2 + 1, { font: "14px CinzelB", color: "#ffd100", align: "center" });

  // Pergaminho pintado real recortado de bg_hd.png
  g.save();
  rrPath(x, y, pw, ph, 6);
  g.clip();
  g.drawImage(P.parchment, 0, 0, P.parchment.width, P.parchment.height, x, y, pw, ph);
  // Vinheta suave de borda envelhecida
  const pv = g.createRadialGradient(x + pw / 2, y + ph / 2, pw * 0.25, x + pw / 2, y + ph / 2, pw * 0.72);
  pv.addColorStop(0, "rgba(255,244,214,0.08)");
  pv.addColorStop(1, "rgba(42,24,10,0.42)");
  g.fillStyle = pv;
  g.fillRect(x, y, pw, ph);
  g.restore();

  // Moldura de ferro & bronze + 4 cantoneiras de pedra de chrome_notitle
  rrPath(x, y, pw, ph, 6);
  g.strokeStyle = "#3b2c1d"; g.lineWidth = 3.2; g.stroke();
  rrPath(x + 3, y + 3, pw - 6, ph - 6, 4);
  g.strokeStyle = "#a3824c"; g.lineWidth = 1.2; g.stroke();

  const cw = 42, ch = 42;
  g.drawImage(P.cornerTL, x - 6, y - 6, cw, ch);
  g.drawImage(P.cornerTR, x + pw - cw + 6, y - 6, cw, ch);
  g.save(); g.translate(x - 6, y + ph + 6); g.scale(1, -1); g.drawImage(P.cornerTL, 0, 0, cw, ch); g.restore();
  g.save(); g.translate(x + pw + 6, y + ph + 6); g.scale(-1, -1); g.drawImage(P.cornerTL, 0, 0, cw, ch); g.restore();

  // Placa de bronze pintada no topo (de ref-frames.png) para o título estilo WoW
  const plW = pw - 64, plH = 44, plX = x + 32, plY = y - 16;
  g.drawImage(P.bronzePlaque, plX, plY, plW, plH);
  txt(data.title, cx, plY + plH / 2 + 1, { font: "14px CinzelB", color: "#ffd100", align: "center", ls: 0.8 });

  // Medalhão 3D do ícone à esquerda
  const mx = x + 46, my = y + 66;
  g.drawImage(P.grimMedal, mx - 28, my - 28, 56, 56);
  const sc = Math.min(34 / data.sprite.width, 34 / data.sprite.height);
  g.drawImage(data.sprite, mx - (data.sprite.width * sc) / 2, my - (data.sprite.height * sc) / 2, data.sprite.width * sc, data.sprite.height * sc);

  // Texto caligráfico em tinta escura sobre pergaminho
  txt(data.desc1, x + 84, y + 52, { font: "15.5px PT", color: "#2b190b", shadow: false });
  txt(data.desc2, x + 84, y + 73, { font: "15.5px PT", color: "#2b190b", shadow: false });

  // Linha de separação a tinta
  g.strokeStyle = "rgba(84,48,20,0.45)";
  g.lineWidth = 1.2;
  g.beginPath(); g.moveTo(x + 24, y + 104); g.lineTo(x + pw - 24, y + 104); g.stroke();

  // Status + Dica
  txt(data.status, x + 26, y + 125, { font: "14.5px PTB", color: "#801319", shadow: false });
  txt(data.hint, x + 26, y + 148, { font: "14.5px Fell", color: "#543418", shadow: false });

  // Selo de cera carmesim com aro metálico no canto inferior direito
  const sx = x + pw - 35, sy = y + ph - 29;
  const wgr = g.createRadialGradient(sx - 4, sy - 4, 2, sx, sy, 18);
  wgr.addColorStop(0, "#d9303e"); wgr.addColorStop(0.65, "#87111c"); wgr.addColorStop(1, "#45060c");
  g.fillStyle = wgr;
  g.beginPath(); g.arc(sx, sy, 15, 0, Math.PI * 2); g.fill();
  g.drawImage(P.grimSeal, sx - 22, sy - 22, 44, 44);
  g.drawImage(P.goldStar, sx - 9, sy - 9, 18, 18);

  g.restore();
}

(async () => {
  await Promise.all([
    document.fonts.load("24px CinzelB"),
    document.fonts.load("16px Cinzel"),
    document.fonts.load("15px PT"),
    document.fonts.load("15px PTB"),
    document.fonts.load("15px Fell"),
  ]);

  const raw = {};
  for (const [k, v] of Object.entries(ASSETS)) raw[k] = await loadImg(v);

  // Preparar recortes pintados reais
  const P = {
    parchment:    cropCanvas(raw.bgTable, 690, 350, 560, 740),
    cornerTL:     cropCanvas(raw.chrome, 0, 0, 155, 155),
    cornerTR:     cropCanvas(raw.chrome, 1845, 0, 155, 155),
    stoneRail:    cropCanvas(raw.chrome, 460, 1052, 560, 64),
    clothBanner:  cropCanvas(raw.chrome, 670, 0, 660, 165),
    bronzePlaque: cleanDarkBg(raw.refFrames, 36, 632, 300, 92, 26),
    goldStar:     cleanDarkBg(raw.refRings, 1044, 500, 112, 108, 22),
    leatherTab:   cropCanvas(raw.leatherTab, 0, 0, 128, 64),
    grimMedal:    raw.grimMedal,
    grimSeal:     raw.grimSeal,
    icoMax:       raw.icoMax,
  };

  // Extrair 15 sprites pintados reais
  const dropCell = (idx) => cropCanvas(raw.dropCats, (idx % 4) * 128, Math.floor(idx / 4) * 128, 128, 128);
  const hw = Math.floor(raw.helmets.width / 4), hh = Math.floor(raw.helmets.height / 2);
  const helmCell = (idx) => cleanDarkBg(raw.helmets, (idx % 4) * hw, Math.floor(idx / 4) * hh, hw, hh, 24);

  const SPR = {
    character:    dropCell(1),
    spellbook:    raw.icoLore,
    talents:      dropCell(0),
    drops:        dropCell(5),
    dungeons:     raw.icoClose,
    achievements: helmCell(4),
    quests:       raw.icoQuests,
    social:       dropCell(6),
    guild:        dropCell(4),
    lfd:          raw.icoGather,
    collections:  helmCell(0),
    map:          raw.icoCenter,
    help:         raw.icoHelp,
    menu:         raw.icoGear,
  };

  const MAIN_DEFS = [
    { key: "character",    sprite: SPR.character },
    { key: "spellbook",    sprite: SPR.spellbook },
    { key: "talents",      sprite: SPR.talents, badge: "3", active: true },
    { key: "drops",        sprite: SPR.drops },
    { key: "dungeons",     sprite: SPR.dungeons },
    { key: "achievements", sprite: SPR.achievements },
    { key: "quests",       sprite: SPR.quests, badge: "12" },
    { key: "social",       sprite: SPR.social, badge: "4" },
    { key: "guild",        sprite: SPR.guild, badge: "9" },
    { key: "lfd",          sprite: SPR.lfd },
    { key: "collections",  sprite: SPR.collections },
  ];
  const SYS_DEFS = [
    { key: "map",  sprite: SPR.map },
    { key: "help", sprite: SPR.help },
    { key: "menu", sprite: SPR.menu },
  ];

  // 1. Fundo real da mesa de RPG (bg_hd.png) + vinheta quente de taverna
  g.imageSmoothingQuality = "high";
  g.drawImage(raw.bgTable, 0, 0, W, H);
  g.fillStyle = "rgba(10,7,4,0.62)";
  g.fillRect(0, 0, W, H);
  const vig = g.createRadialGradient(W / 2, H / 2, 260, W / 2, H / 2, 1080);
  vig.addColorStop(0, "rgba(38,24,10,0.06)");
  vig.addColorStop(1, "rgba(4,3,2,0.78)");
  g.fillStyle = vig; g.fillRect(0, 0, W, H);

  // 2. Estandarte de pano rasgado do topo (chrome_notitle) com título clássico WoW
  g.drawImage(P.clothBanner, W / 2 - 330, -4, 660, 140);
  txt("MICRO MENU", W / 2, 46, { font: "28px CinzelB", color: "#ffd100", align: "center", ls: 3.5 });
  txt("MESA DE RPG  ×  WOW CLÁSSICO", W / 2, 76, { font: "12.5px CinzelB", color: "#e8dcc4", align: "center", ls: 2.5 });

  // 3. Seção 1: Slots 3D Close-up + Dado d20 na mesa
  const s1Y = 210;
  txt("1. SLOTS RETRATO 3D ESTILO WOW (REPOUSO · HOVER · PRESSIONADO · LATÊNCIA)", 120, 134, { font: "14px CinzelB", color: "#ffd100", ls: 1.5 });
  // Tapete de couro escuro atrás dos close-ups
  g.save();
  rrPath(112, 152, 1696, 146, 8);
  g.fillStyle = "rgba(14,10,7,0.72)"; g.fill();
  g.strokeStyle = "#6e5534"; g.lineWidth = 1.6; g.stroke();
  g.restore();

  const states = [
    { label: "REPOUSO",    sprite: SPR.character,    state: "idle" },
    { label: "EM FOCO",    sprite: SPR.spellbook,    state: "hover" },
    { label: "ABERTO + BADGE", sprite: SPR.talents,  state: "active", badge: "3" },
    { label: "MENU [W] + PING", sprite: SPR.menu,    state: "idle", isSysW: true, ping: true },
  ];
  states.forEach((st, i) => {
    const sx = 160 + i * 260;
    drawWowSlot(sx, 164, 72, 98, st.sprite, { state: st.state, badge: st.badge, isSysW: st.isSysW });
    if (st.ping) drawLatencyBar(sx + 80, 168, 18, 90, 0.86);
    txt(st.label, sx + (st.ping ? 46 : 36), 278, { font: "12px CinzelB", color: st.state === "active" ? "#ffd100" : "#d9cbb0", align: "center", ls: 0.8 });
  });

  // Cluster tátil de RPG de mesa à direita da faixa 1: Aba de couro + Selo com estrela + Dados
  g.drawImage(P.leatherTab, 1230, 194, 150, 66);
  const csx = 1377, csy = 227;
  const cgr = g.createRadialGradient(csx - 4, csy - 4, 2, csx, csy, 24);
  cgr.addColorStop(0, "#d9303e"); cgr.addColorStop(0.7, "#7d0f19"); cgr.addColorStop(1, "#3b0509");
  g.fillStyle = cgr; g.beginPath(); g.arc(csx, csy, 21, 0, Math.PI * 2); g.fill();
  g.drawImage(P.grimSeal, csx - 31, csy - 31, 62, 62);
  g.drawImage(P.goldStar, csx - 13, csy - 13, 26, 26);
  drawD20(1476, 224, 34, "20");
  drawD20(1548, 232, 26, "12");
  txt("RPG DE MESA", 1642, 214, { font: "14px CinzelB", color: "#ffd100", ls: 1.2 });
  txt("Couro, pedra, pergaminho", 1642, 234, { font: "13px PT", color: "#d6c8ad" });
  txt("e ícones 3D coloridos", 1642, 251, { font: "13px PT", color: "#d6c8ad" });

  // 4. Seção 2 (Herói): MicroBar Clássica Estilo WoW + Ficha em Pergaminho & Pedra
  txt("2. MICROBAR DE PEDRA & FERRO ESTILO WOW + FICHA EM PERGAMINHO", 120, 336, { font: "14px CinzelB", color: "#ffd100", ls: 1.5 });

  const barY = 666;
  const dock = drawWowMicroBar(960, barY, P, MAIN_DEFS, SYS_DEFS, { collapsed: false, slotW: 52, slotH: 72, gap: 4 });

  // Ficha em pergaminho real acima do slot ativo de Talentos
  drawWowParchmentPlacard(dock.activePos.x + 110, barY - 72, P, {
    w: 446,
    h: 174,
    sprite: SPR.talents,
    title: "TALENTOS & ESPECIALIZAÇÃO",
    key: "(N)",
    desc1: "Distribua pontos de talento, alterne especializações",
    desc2: "e personalize sua build no Crisol de Azaath.",
    status: "Pontos disponíveis: 3",
    hint: "Clique direito: Janela padrão da Blizzard",
  });

  // Anotações rápidas e limpas abaixo da barra
  const note = (x1, y1, x2, y2, title, sub) => {
    g.save();
    g.strokeStyle = "rgba(218,180,108,0.65)";
    g.setLineDash([3, 4]);
    g.lineWidth = 1.2;
    g.beginPath(); g.moveTo(x1, y1); g.lineTo(x2, y2); g.stroke();
    g.setLineDash([]);
    g.fillStyle = "#ffd100";
    g.beginPath(); g.arc(x1, y1, 3, 0, Math.PI * 2); g.fill();
    txt(title, x2, y2 + 14, { font: "12px CinzelB", color: "#ffd100", align: "center", ls: 0.6 });
    txt(sub, x2, y2 + 30, { font: "12.5px PT", color: "#d8cbb0", align: "center" });
    g.restore();
  };

  note(dock.x0 + 26, barY + 34, 420, 746, "CANTARIA & FERRO WOW", "Trilho esculpido com rebites");
  note(dock.activePos.x, barY + 40, 690, 746, "SLOT RETRATO PRESSIONADO", "Poço afundado + ouro #ffd100");
  note(dock.togX, barY + 38, 1110, 746, "FIVELA DE COURO", "Recolhe os 11 slots principais");
  note(dock.x0 + dock.barW - 25, barY + 34, 1440, 746, "BARRA DE LATÊNCIA", "Cristal verde (MainMenuBar)");

  // 5. Seção 3: Modo Recolhido + Pergaminho de Sistema
  txt("3. MODO RECOLHIDO & FICHA DE SISTEMA (TELEMETRIA WOW)", 120, 818, { font: "14px CinzelB", color: "#ffd100", ls: 1.5 });
  drawWowMicroBar(420, 926, P, MAIN_DEFS, SYS_DEFS, { collapsed: true, slotW: 52, slotH: 72, gap: 4 });
  txt("Gaveta compacta no canto inferior direito quando recolhida", 420, 996, { font: "13px PT", color: "#cfc1a5", align: "center" });

  drawWowParchmentPlacard(1340, 1022, P, {
    w: 470,
    h: 174,
    sprite: SPR.menu,
    title: "MENU DO JOGO",
    key: "(ESC)",
    desc1: "Opções de vídeo, som, interface e atalhos",
    desc2: "do jogo e configurações AzaathUI.",
    status: "FPS: 144   |   Casa: 16 ms   |   Mundo: 18 ms",
    hint: "Clique direito: Abrir opções AzaathUI (/azaath)",
  });

  window.__DONE = true;
})();
</script></body></html>`;

fs.writeFileSync(HTML_FILE, html, "utf8");
if (fs.existsSync(OUT_PNG)) fs.unlinkSync(OUT_PNG);

const prof = path.join(require("os").tmpdir(), "azaath_wow_tabletop_" + Date.now());
spawnSync(EDGE, [
  "--headless=new",
  "--disable-gpu",
  "--user-data-dir=" + prof,
  "--no-first-run",
  "--hide-scrollbars",
  "--force-device-scale-factor=1",
  "--window-size=1920,1080",
  "--virtual-time-budget=4000",
  "--allow-file-access-from-files",
  "--screenshot=" + OUT_PNG,
  "file:///" + HTML_FILE.replace(/\\/g, "/"),
], { stdio: "ignore" });

const t0 = Date.now();
let last = -1;
while (Date.now() - t0 < 30000) {
  const sz = fs.existsSync(OUT_PNG) ? fs.statSync(OUT_PNG).size : 0;
  if (sz > 0 && sz === last) break;
  last = sz;
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
}
if (!fs.existsSync(OUT_PNG)) {
  console.error("O Edge não gravou o screenshot (rode fora do sandbox).");
  process.exit(1);
}
console.log("Arte WoW Tabletop gerada:", OUT_PNG, fs.statSync(OUT_PNG).size, "bytes");
