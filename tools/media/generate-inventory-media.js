// Gera as texturas do inventário (Media/Inventory/*.tga, TGA 32 bits).
// Reproduz o painel de inventário do Azaath: cabeçalho azul escovado com
// borda "rasgada", corpo quase preto com estrias verticais, moldura com filete
// claro, espaços de item (quadrado, equipamento e redondo), hachura diagonal
// dos títulos de seção, ícones de ordenação e o losango amarelo de missão.
// As cores foram amostradas da captura de referência.
// Uso: node tools/media/generate-inventory-media.js
const fs = require("fs");
const path = require("path");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Inventory");
fs.mkdirSync(OUT, { recursive: true });

// ---------------------------------------------------------------------------
// utilidades
// ---------------------------------------------------------------------------
const clamp01 = (v) => Math.max(0, Math.min(1, v));
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = (e0, e1, x) => {
  const t = clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
};
const mix3 = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];

// ruído de valor determinístico + fbm
function hash(x, y, seed) {
  let h = (x * 374761393 + y * 668265263 + seed * 2147483647) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967295;
}
function vnoise(x, y, seed) {
  const xi = Math.floor(x), yi = Math.floor(y);
  const xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = hash(xi, yi, seed), b = hash(xi + 1, yi, seed);
  const c = hash(xi, yi + 1, seed), d = hash(xi + 1, yi + 1, seed);
  return lerp(lerp(a, b, u), lerp(c, d, u), v);
}
function fbm(x, y, seed, oct = 4) {
  let sum = 0, amp = 0.5, norm = 0, f = 1;
  for (let i = 0; i < oct; i++) {
    sum += amp * vnoise(x * f, y * f, seed + i * 17);
    norm += amp;
    amp *= 0.5;
    f *= 2;
  }
  return sum / norm; // 0..1
}

// fn(x, y) -> [r, g, b, a] com r/g/b em 0..255 e a em 0..1 (y = 0 no topo)
function writeTGA(file, w, h, fn) {
  const header = Buffer.alloc(18);
  header[2] = 2;
  header.writeUInt16LE(w, 12);
  header.writeUInt16LE(h, 14);
  header[16] = 32;
  header[17] = 8; // 8 bits de alpha, origem inferior esquerda
  const data = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const [r, g, b, a] = fn(x, y);
      const i = ((h - 1 - y) * w + x) * 4; // grava de baixo para cima
      data[i] = Math.round(Math.max(0, Math.min(255, b)));
      data[i + 1] = Math.round(Math.max(0, Math.min(255, g)));
      data[i + 2] = Math.round(Math.max(0, Math.min(255, r)));
      data[i + 3] = Math.round(clamp01(a) * 255);
    }
  }
  fs.writeFileSync(path.join(OUT, file), Buffer.concat([header, data]));
  console.log("gerado Inventory/" + file);
}

// cobertura com supersampling 4x4 de um predicado inside(x, y)
function coverage(px, py, inside) {
  let n = 0;
  for (let j = 0; j < 4; j++) {
    for (let i = 0; i < 4; i++) {
      if (inside(px + (i + 0.5) / 4, py + (j + 0.5) / 4)) n++;
    }
  }
  return n / 16;
}
const white = (inside) => (x, y) => [255, 255, 255, coverage(x, y, inside)];

function inRoundRect(x, y, x0, y0, x1, y1, r) {
  const cx = Math.max(x0 + r, Math.min(x1 - r, x));
  const cy = Math.max(y0 + r, Math.min(y1 - r, y));
  const dx = x - cx, dy = y - cy;
  return x >= x0 && x <= x1 && y >= y0 && y <= y1 && dx * dx + dy * dy <= r * r;
}
function inTriangle(x, y, a, b, c) {
  const s = (p, q, r) => (p[0] - r[0]) * (q[1] - r[1]) - (q[0] - r[0]) * (p[1] - r[1]);
  const pt = [x, y];
  const d1 = s(pt, a, b), d2 = s(pt, b, c), d3 = s(pt, c, a);
  const neg = d1 < 0 || d2 < 0 || d3 < 0, pos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(neg && pos);
}

// borda "rasgada" (pincel seco): deslocamento da borda ao longo de t
function frayOffset(t, seed, base, amp) {
  return base
    + amp * fbm(t / 16, 0.5, seed, 3)
    + amp * 0.45 * fbm(t / 4.5, 3.5, seed + 5, 2)
    + amp * 0.2 * vnoise(t / 1.4, 9.5, seed + 9);
}
// alpha da borda: d = distância para dentro a partir do limite rasgado
function frayAlpha(d, x, y, seed) {
  let a = clamp01(d + 0.5);
  // falhas de pincel perto da borda
  if (d < 5) {
    const n = fbm(x / 3, y / 3, seed + 31, 2);
    a *= lerp(smooth(0.2, 0.42, n), 1, clamp01(d / 5));
  }
  return a;
}

// ---------------------------------------------------------------------------
// Painel
// ---------------------------------------------------------------------------
const W = 512;
const RIM = 13;      // moldura escura externa (px da textura)
const LINE = 3;      // filete claro entre moldura e corpo
const RIM_COL = [15, 13, 9];
const LINE_COL = [34, 33, 29];
const BODY_COL = [20, 17, 13];

// Cabeçalho azul: topo/laterais rasgados, degradê escuro->claro para baixo
writeTGA("Header.tga", W, 128, (x, y) => {
  const top = frayOffset(x, 11, 5, 7);
  const left = frayOffset(y + 40, 12, 3, 4);
  const right = frayOffset(y + 90, 13, 3, 4);
  const d = Math.min(y - top, x - left, (W - 1 - x) - right);
  const a = frayAlpha(d, x, y, 14);
  if (a <= 0) return [0, 0, 0, 0];

  const t = Math.pow(y / 127, 1.1);
  let col = mix3([12, 27, 43], [25, 55, 85], smooth(0, 1, t));
  // vinheta horizontal: mais escuro à direita e um pouco à esquerda
  const vig = 1 - 0.42 * smooth(0.72, 1, x / (W - 1)) - 0.18 * smooth(0.22, 0, x / (W - 1));
  // escovado horizontal + manchas
  const brush = 0.84 + 0.32 * fbm(x / 34, y / 2.2, 21, 4);
  const mottle = 0.82 + 0.36 * fbm(x / 70, y / 26, 22, 3);
  const scratch = fbm(x / 3, y / 0.8, 23, 2) > 0.78 ? 1.08 : 1;
  let k = vig * brush * mottle * scratch;
  // contorno escuro junto ao rasgo
  k *= lerp(0.45, 1, smooth(0, 5, d));
  col = col.map((c) => c * k);
  return [col[0], col[1], col[2], a];
});

// Corpo: colunas idênticas às do rodapé (moldura, filete, corpo com estrias)
function panelColumn(x, y, dRaw, dFray, seed) {
  const a0 = frayAlpha(dFray, x, y, seed);
  if (a0 <= 0) return [0, 0, 0, 0];
  let col, a = a0;
  const grain = 0.88 + 0.24 * fbm(x / 1.5, y / 1.5, seed + 3, 2);
  if (dRaw < RIM) {
    col = RIM_COL.map((c) => c * grain * (0.9 + 0.2 * fbm(x / 6, y / 14, seed + 4, 2)));
  } else if (dRaw < RIM + LINE) {
    const mid = 1 - Math.abs((dRaw - RIM) - (LINE - 1) / 2) / LINE;
    col = mix3(RIM_COL, LINE_COL, 0.55 + 0.45 * mid).map((c) => c * grain);
  } else {
    const inner = dRaw - RIM - LINE;
    // estrias verticais + manchas suaves
    const streak = 0.86 + 0.28 * fbm(x / 2.2, y / 55, seed + 5, 3);
    const mottle = 0.86 + 0.28 * fbm(x / 90, y / 90, seed + 6, 3);
    // sombra interna junto ao filete
    const shade = lerp(0.6, 1, smooth(0, 12, inner));
    col = BODY_COL.map((c) => c * streak * mottle * shade);
    a = a0 * 0.97;
  }
  return [col[0], col[1], col[2], a];
}

writeTGA("Body.tga", W, 512, (x, y) => {
  const dx = Math.min(x, W - 1 - x);
  const side = x < W / 2 ? 41 : 42;
  const off = frayOffset(y, side, 2, 5);
  return panelColumn(x, y, dx, dx - off, 40);
});

// Rodapé (512x64): mesmas colunas + borda inferior rasgada e cantos
writeTGA("Footer.tga", W, 64, (x, y) => {
  const dx = Math.min(x, W - 1 - x);
  const dy = 63 - y;
  const side = x < W / 2 ? 41 : 42;
  // continua o rasgo lateral do corpo (y deslocado para não repetir)
  const offX = frayOffset(y + 512, side, 2, 5);
  const offY = frayOffset(x, 43, 2, 6);
  const dRaw = Math.min(dx, dy);
  const dFray = Math.min(dx - offX, dy - offY);
  return panelColumn(x, y, dRaw, dFray, 40);
});

// ---------------------------------------------------------------------------
// Espaços de item (tons de cinza: a raridade tinge com SetVertexColor)
// ---------------------------------------------------------------------------
// Quadrado escuro (consumíveis, munição, diversos)
writeTGA("Slot.tga", 64, 64, (x, y) => {
  const corner = (x === 0 || x === 63) && (y === 0 || y === 63);
  if (corner) return [0, 0, 0, 0];
  const edge = x === 0 || y === 0 || x === 63 || y === 63;
  const t = y / 63;
  let v = lerp(46, 35, t) + 6 * (fbm(x / 9, y / 9, 51, 3) - 0.5);
  // leve brilho no canto superior esquerdo
  v += 5 * clamp01(1 - Math.hypot(x - 12, y - 10) / 50);
  if (edge) v = 52;
  return [v, v, v * 0.98, 0.96];
});

// Equipamento: moldura cinza clara + fundo "de estúdio" (centro claro)
writeTGA("SlotGear.tga", 64, 64, (x, y) => {
  const d = Math.min(x, y, 63 - x, 63 - y);
  if (d < 2) return [116, 116, 114, 1];
  if (d < 3) return [34, 34, 33, 1];
  const r = Math.hypot((x - 32) / 34, (y - 24) / 40);
  let v = lerp(112, 52, smooth(0, 1, r)) + 5 * (fbm(x / 8, y / 8, 61, 3) - 0.5);
  return [v, v, v * 0.97, 1];
});

// Redondo (materiais/recursos)
writeTGA("SlotRound.tga", 64, 64, (x, y) => {
  const a = coverage(x, y, (px, py) => Math.hypot(px - 32, py - 32) <= 31);
  if (a <= 0) return [0, 0, 0, 0];
  const r = Math.hypot(x + 0.5 - 32, y + 0.5 - 32) / 31;
  let v = lerp(58, 34, smooth(0.1, 1, r)) + 10 * clamp01(1 - Math.hypot(x - 20, y - 18) / 30);
  v += 4 * (fbm(x / 8, y / 8, 71, 3) - 0.5);
  return [v, v, v * 0.98, a * 0.97];
});

// Máscara redonda do ícone (MaskTexture / SetMask)
writeTGA("RoundMask.tga", 64, 64, white((px, py) => Math.hypot(px - 32, py - 32) <= 30));

// Hachura diagonal à direita dos títulos de seção (some para a direita)
writeTGA("Hatch.tga", 128, 16, (x, y) => {
  const s = ((x + (15 - y)) % 5 + 5) % 5;
  const stripe = clamp01(1.4 - Math.abs(s - 1.2));
  const fade = smooth(0, 10, x) * Math.pow(1 - x / 127, 1.3);
  const band = smooth(1, 3, y) * smooth(15, 13, y);
  return [255, 255, 255, stripe * fade * band];
});

// ---------------------------------------------------------------------------
// Botões e ícones (brancos: cor via SetVertexColor)
// ---------------------------------------------------------------------------
writeTGA("RoundRect.tga", 32, 32, white((x, y) => inRoundRect(x, y, 0, 0, 32, 32, 4)));
writeTGA("ButtonWide.tga", 128, 32, white((x, y) => inRoundRect(x, y, 0, 0, 128, 32, 5)));
writeTGA("Arrow.tga", 32, 32, white((x, y) => inTriangle(x, y, [11, 8], [11, 24], [23, 16])));

// Relógio (mais recentes)
writeTGA("SortClock.tga", 32, 32, white((x, y) => {
  const r = Math.hypot(x - 16, y - 16);
  if (r >= 10.6 && r <= 13.2) return true;
  if (Math.abs(x - 16) <= 1.2 && y >= 8.5 && y <= 17) return true;      // ponteiro vertical
  if (Math.abs(y - 16) <= 1.2 && x >= 15 && x <= 22.5) return true;     // ponteiro horizontal
  return false;
}));

// Estrela (raridade)
const STAR = [];
for (let i = 0; i < 10; i++) {
  const ang = -Math.PI / 2 + (i * Math.PI) / 5;
  const r = i % 2 === 0 ? 13 : 5.4;
  STAR.push([16 + r * Math.cos(ang), 17 + r * Math.sin(ang)]);
}
function inPolygon(x, y, poly) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
  }
  return inside;
}
writeTGA("SortStar.tga", 32, 32, white((x, y) => inPolygon(x, y, STAR)));

// Triângulo em faixas (nível do item)
writeTGA("SortTier.tga", 32, 32, white((x, y) => {
  if (!inTriangle(x, y, [16, 4], [3, 28], [29, 28])) return false;
  return !((y > 12.5 && y < 15) || (y > 20 && y < 22.5));
}));

// Círculo dourado da ajuda da busca (o "?" é um texto por cima)
writeTGA("Help.tga", 32, 32, (x, y) => {
  const a = coverage(x, y, (px, py) => Math.hypot(px - 16, py - 16) <= 14);
  const shade = 1 - 0.18 * clamp01((y - 8) / 22);
  return [205 * shade, 145 * shade, 28 * shade, a];
});

// Losango amarelo empilhado (item de missão)
writeTGA("Badge.tga", 64, 64, (x, y) => {
  const md = (cx, cy) => Math.abs(x + 0.5 - cx) + Math.abs(y + 0.5 - cy);
  const front = md(32, 27), back = md(32, 36);
  const aFront = clamp01(23 - front + 0.5);
  const aBack = clamp01(21 - back + 0.5);
  // contorno escuro em volta de tudo
  const aOut = Math.max(clamp01(25 - front + 0.5), clamp01(23 - back + 0.5));
  let col = [40, 30, 6], a = aOut;
  if (aBack > 0) col = mix3(col, [190, 150, 18], aBack);
  if (aFront > 0) {
    let f;
    if (front < 11) f = [255, 236, 120];          // miolo claro
    else if (front < 14) f = [92, 70, 12];        // anel escuro
    else f = [246, 208, 40];                       // losango externo
    col = mix3(col, f, aFront);
  }
  return [col[0], col[1], col[2], a];
});
