// Gera as texturas da janela de diálogo/missões (Media/Dialog/*.tga, TGA 32 bits).
// Reproduz o painel de conversa do Azaath ("NORA LINCH / Watcher of First
// Light"): cabeçalho azul escovado com topo rasgado, corpo marrom-carvão,
// rodapé rasgado, fundo das opções (normal e destaque dourado), caixinhas de
// tecla (E / ESC) e os ícones das opções (losango de missão, agulha verde de
// conversa e porta de "Sair").
//
// As cores e medidas foram amostradas das capturas de referência (1886x1060).
// Tudo é desenhado em "pixels de referência" (rx, ry) e reamostrado para o
// tamanho da textura, então a textura esticada no jogo mantém a proporção.
// Uso: node tools/media/generate-dialog-media.js
const fs = require("fs");
const path = require("path");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Dialog");
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
  return sum / norm;
}

// fn(x, y) -> [r, g, b, a] (0..255, a 0..1; y = 0 no topo)
function writeTGA(file, w, h, fn) {
  const header = Buffer.alloc(18);
  header[2] = 2;
  header.writeUInt16LE(w, 12);
  header.writeUInt16LE(h, 14);
  header[16] = 32;
  header[17] = 8;
  const data = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      const [r, g, b, a] = fn(x, y);
      const i = ((h - 1 - y) * w + x) * 4;
      data[i] = Math.round(Math.max(0, Math.min(255, b)));
      data[i + 1] = Math.round(Math.max(0, Math.min(255, g)));
      data[i + 2] = Math.round(Math.max(0, Math.min(255, r)));
      data[i + 3] = Math.round(clamp01(a) * 255);
    }
  }
  fs.writeFileSync(path.join(OUT, file), Buffer.concat([header, data]));
  console.log("gerado Dialog/" + file);
}

// textura w x h que representa uma área de referência RW x RH
function writeRef(file, w, h, RW, RH, fn) {
  const sx = RW / w, sy = RH / h;
  writeTGA(file, w, h, (x, y) => fn((x + 0.5) * sx, (y + 0.5) * sy, sx, sy));
}

// supersampling 4x4 de inside(x, y) -> 0..1
function coverage(px, py, inside) {
  let n = 0;
  for (let j = 0; j < 4; j++) {
    for (let i = 0; i < 4; i++) {
      if (inside(px + (i + 0.5) / 4, py + (j + 0.5) / 4)) n++;
    }
  }
  return n / 16;
}

// deslocamento de uma borda rasgada (pincel seco) ao longo de t
function fray(t, seed, base, amp) {
  return base
    + amp * fbm(t / 18, 0.5, seed, 3)
    + amp * 0.5 * fbm(t / 5, 3.5, seed + 5, 2)
    + amp * 0.25 * vnoise(t / 1.5, 9.5, seed + 9);
}
// alpha a partir da distância d (px de referência) para dentro do limite
function frayAlpha(d, x, y, seed) {
  let a = clamp01(d + 0.5);
  if (d < 6) {
    const n = fbm(x / 3, y / 3, seed + 31, 2);
    a *= lerp(smooth(0.22, 0.45, n), 1, clamp01(d / 6));
  }
  return a;
}

// ---------------------------------------------------------------------------
// Painel (referência: 698 px de largura)
// ---------------------------------------------------------------------------
const PW = 698;

// vinheta horizontal do cabeçalho (amostrada: laterais ~45-60% do centro)
function headerVignette(u) {
  const left = 1 - 0.5 * smooth(0.16, 0.0, u);
  const right = 1 - 0.62 * smooth(0.82, 1.0, u);
  return left * right;
}

// Cabeçalho (698 x 107 ref -> 512 x 128): degradê azul, topo rasgado
writeRef("Header.tga", 512, 128, PW, 107, (rx, ry) => {
  const top = fray(rx, 11, 1.5, 6);
  const left = fray(ry + 40, 12, 0.5, 2.5);
  const right = fray(ry + 90, 13, 0.5, 2.5);
  const d = Math.min(ry - top, rx - left, (PW - rx) - right);
  const a = frayAlpha(d, rx, ry, 14);
  if (a <= 0) return [0, 0, 0, 0];

  // centro: (14,34,53) no topo -> (25,56,86) embaixo
  const t = clamp01((ry - 4) / 100);
  let col = mix3([12, 30, 47], [25, 56, 86], smooth(0, 1, t));
  const u = rx / PW;
  const vig = headerVignette(u);
  // laterais perdem saturação além de escurecer
  const grey = (col[0] + col[1] + col[2]) / 3;
  col = mix3(col, [grey * 0.8, grey * 0.95, grey * 1.1], (1 - vig) * 0.6);
  const brush = 0.86 + 0.28 * fbm(rx / 40, ry / 2.6, 21, 4);
  const mottle = 0.86 + 0.28 * fbm(rx / 80, ry / 30, 22, 3);
  const scratch = fbm(rx / 3.5, ry / 0.9, 23, 2) > 0.8 ? 1.07 : 1;
  let k = vig * brush * mottle * scratch;
  k *= lerp(0.5, 1, smooth(0, 6, d)); // contorno escuro no rasgo
  col = col.map((c) => c * k);
  return [col[0], col[1], col[2], a];
});

// cor do corpo (marrom-carvão manchado, lado direito um pouco mais escuro)
function bodyColor(rx, ry, seed) {
  const u = rx / PW;
  let col = mix3([25, 21, 16], [25, 17, 11], smooth(0.2, 1, (ry % 700) / 700));
  col = col.map((c) => c * (1 - 0.22 * smooth(0.65, 0.95, u)));
  const streak = 0.9 + 0.2 * fbm(rx / 2.5, ry / 60, seed + 5, 3);
  const mottle = 0.84 + 0.32 * fbm(rx / 110, ry / 110, seed + 6, 3);
  return col.map((c) => c * streak * mottle);
}

// Corpo (698 x 600 ref -> 512 x 512): laterais quase retas
writeRef("Body.tga", 512, 512, PW, 600, (rx, ry) => {
  const left = fray(ry, 41, 0.4, 1.8);
  const right = fray(ry, 42, 0.4, 1.8);
  const d = Math.min(rx - left, (PW - rx) - right);
  const a = frayAlpha(d, rx, ry, 40);
  if (a <= 0) return [0, 0, 0, 0];
  const col = bodyColor(rx, ry, 40).map((c) => c * lerp(0.7, 1, smooth(0, 4, d)));
  return [col[0], col[1], col[2], a * 0.96];
});

// Rodapé (698 x 64 ref -> 512 x 64): mesmas laterais + base rasgada
writeRef("Footer.tga", 512, 64, PW, 64, (rx, ry) => {
  const left = fray(ry + 600, 41, 0.4, 1.8);
  const right = fray(ry + 600, 42, 0.4, 1.8);
  const bottom = fray(rx, 43, 1.5, 7);
  const d = Math.min(rx - left, (PW - rx) - right, (64 - ry) - bottom);
  const a = frayAlpha(d, rx, ry, 44);
  if (a <= 0) return [0, 0, 0, 0];
  const col = bodyColor(rx, ry + 600, 40).map((c) => c * lerp(0.7, 1, smooth(0, 4, d)));
  return [col[0], col[1], col[2], a * 0.96];
});

// ---------------------------------------------------------------------------
// Fundo das opções (582 x 51 ref -> 512 x 64), sem a moldura (feita no Lua)
// ---------------------------------------------------------------------------
const OW = 582, OH = 51;

// normal: marrom muito escuro, pontas um pouco mais escuras
writeRef("OptionFill.tga", 512, 64, OW, OH, (rx, ry) => {
  const u = rx / OW;
  let col = [20, 14, 8];
  const ends = 1 - 0.3 * smooth(0.9, 1, u) - 0.12 * smooth(0.06, 0, u);
  const grain = 0.9 + 0.2 * fbm((rx + ry) / 2.2, (rx - ry) / 16, 61, 3);
  col = col.map((c) => c * ends * grain);
  return [col[0], col[1], col[2], 0.97];
});

// destaque (mouse): degradê dourado, mais claro embaixo e no meio, hachura diagonal
writeRef("OptionHover.tga", 512, 64, OW, OH, (rx, ry) => {
  const u = rx / OW, v = ry / OH;
  let col = mix3([36, 29, 11], [100, 77, 28], Math.pow(v, 1.3));
  const center = lerp(0.45, 1, smooth(0, 0.35, u)) * lerp(1, 0.45, smooth(0.62, 1, u));
  const hatch = 0.9 + 0.2 * fbm((rx + ry) / 1.6, (rx - ry) / 22, 71, 3);
  const mottle = 0.9 + 0.2 * fbm(rx / 60, ry / 20, 72, 3);
  const k = center * hatch * mottle;
  col = col.map((c) => c * k);
  return [col[0], col[1], col[2], 0.98];
});

// ---------------------------------------------------------------------------
// Caixinhas de tecla (fundo preto, filete cinza, cantos arredondados)
// ---------------------------------------------------------------------------
function sdRoundRect(px, py, x0, y0, x1, y1, r) {
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  const hx = (x1 - x0) / 2 - r, hy = (y1 - y0) / 2 - r;
  const qx = Math.abs(px - cx) - hx, qy = Math.abs(py - cy) - hy;
  const ox = Math.max(qx, 0), oy = Math.max(qy, 0);
  return Math.hypot(ox, oy) + Math.min(Math.max(qx, qy), 0) - r;
}
function keyBox(file, W, H) {
  const R = 6.5, LINE = 2.2;
  writeTGA(file, W, H, (x, y) => {
    let cov = 0, line = 0;
    for (let j = 0; j < 4; j++) {
      for (let i = 0; i < 4; i++) {
        const d = sdRoundRect(x + (i + 0.5) / 4, y + (j + 0.5) / 4, 0.5, 0.5, W - 0.5, H - 0.5, R);
        if (d <= 0) {
          cov++;
          if (d > -LINE) line++;
        }
      }
    }
    if (cov === 0) return [0, 0, 0, 0];
    const lineV = lerp(132, 104, y / (H - 1));
    const v = lerp(4, lineV, line / cov);
    return [v, v * 0.985, v * 0.94, cov / 16];
  });
}
keyBox("KeyBox.tga", 32, 32);
keyBox("KeyBoxWide.tga", 64, 32);

// ---------------------------------------------------------------------------
// Ícones das opções (64 x 64)
// ---------------------------------------------------------------------------
// Missão: losango dourado com uma divisa (chevron) logo abaixo
writeTGA("IconQuest.tga", 64, 64, (x, y) => {
  const H = 17;                       // meio-tamanho do losango
  const DX = 32, DY = 22;             // centro do losango
  const CY = DY + 15;                 // centro do contorno da divisa
  const md = (px, py, cx, cy) => Math.abs(px - cx) + Math.abs(py - cy);
  const aD = coverage(x, y, (px, py) => md(px, py, DX, DY) <= H);
  const aC = coverage(x, y, (px, py) => {
    const m = md(px, py, DX, CY);
    return py > CY && m <= H && m >= H - 4.2 && md(px, py, DX, DY) > H + 3;
  });
  if (aD <= 0 && aC <= 0) return [0, 0, 0, 0];
  if (aD > 0) {
    // leve degradê: mais claro em cima
    const t = clamp01((y - (DY - H)) / (2 * H));
    const c = mix3([255, 214, 112], [236, 184, 74], t);
    return [c[0], c[1], c[2], aD];
  }
  return [238, 208, 140, aC];
});

// Missão com símbolo: losango dourado com contorno escuro e "!" (disponível)
// ou "?" (entregar / em andamento; o Lua dessatura as incompletas)
const QD = { CX: 32, CY: 32, H: 29, RIM: 3 };
const md = (px, py, cx, cy) => Math.abs(px - cx) + Math.abs(py - cy);
// "!": haste afinando para baixo + ponto
function glyphBang(px, py) {
  if (py >= 15 && py <= 37) {
    const w = lerp(4.2, 2.6, (py - 15) / 22);
    if (Math.abs(px - 32) <= w) return true;
  }
  return Math.hypot(px - 32, py - 45) <= 3.6;
}
// "?": arco (anel aberto embaixo à esquerda) + gancho + haste + ponto
function glyphQuestion(px, py) {
  const cx = 32, cy = 22, R = 9, T = 4;
  const r = Math.hypot(px - cx, py - cy);
  const ang = Math.atan2(py - cy, px - cx); // 0 = direita, +pi/2 = baixo
  // arco: anel sem o trecho de baixo à esquerda
  if (r >= R - T && r <= R && !(ang > Math.PI * 0.5 && ang < Math.PI * 0.85)) return true;
  // haste: desce do fim do arco
  if (py >= 26 && py <= 37 && Math.abs(px - 32) <= 2.1) return true;
  return Math.hypot(px - 32, py - 45) <= 3.4;
}
function questGlyphIcon(file, glyph) {
  writeTGA(file, 64, 64, (x, y) => {
    const aD = coverage(x, y, (px, py) => md(px, py, QD.CX, QD.CY) <= QD.H);
    if (aD <= 0) return [0, 0, 0, 0];
    const aIn = coverage(x, y, (px, py) => md(px, py, QD.CX, QD.CY) <= QD.H - QD.RIM);
    const aG = coverage(x, y, glyph);
    const t = clamp01((y - (QD.CY - QD.H)) / (2 * QD.H));
    let c = mix3([255, 220, 120], [226, 168, 58], t);
    c = mix3([58, 36, 10], c, aIn);          // contorno escuro
    c = mix3(c, [46, 26, 6], aG);            // símbolo marrom-escuro
    return [c[0], c[1], c[2], aD];
  });
}
questGlyphIcon("IconQuestAvailable.tga", glyphBang);
questGlyphIcon("IconQuestTurnIn.tga", glyphQuestion);

// Conversa: balão de fala creme com contorno escuro, rabicho e três pontos
writeTGA("IconTalk.tga", 64, 64, (x, y) => {
  const CX = 32, CY = 27, RX = 26, RY = 19;
  const ell = (px, py, k) => ((px - CX) / (RX - k)) ** 2 + ((py - CY) / (RY - k)) ** 2 <= 1;
  // rabicho: triângulo saindo da base esquerda
  const tail = (px, py, k) => {
    const ax = 17, ay = 40, bx = 29, by = 43, tx = 11, ty = 57 - k;
    const s = (x1, y1, x2, y2) => (px - x2) * (y1 - y2) - (x1 - x2) * (py - y2);
    const d1 = s(ax, ay, bx, by), d2 = s(bx, by, tx, ty), d3 = s(tx, ty, ax, ay);
    const neg = d1 < 0 || d2 < 0 || d3 < 0, pos = d1 > 0 || d2 > 0 || d3 > 0;
    return !(neg && pos) && py <= ty;
  };
  const aO = coverage(x, y, (px, py) => ell(px, py, 0) || tail(px, py, 0));
  if (aO <= 0) return [0, 0, 0, 0];
  const aI = coverage(x, y, (px, py) => ell(px, py, 3) || (tail(px, py, 3) && px > 13.5 && py < 52));
  const aDots = coverage(x, y, (px, py) =>
    [20, 32, 44].some((dx) => Math.hypot(px - dx, py - CY) <= 3.6));
  const t = clamp01((y - (CY - RY)) / (2 * RY));
  let c = mix3([250, 244, 226], [214, 202, 172], t);
  c = mix3([40, 30, 18], c, aI);
  c = mix3(c, [70, 54, 30], aDots);
  return [c[0], c[1], c[2], aO];
});

// Sair: seta para a esquerda entrando numa porta (branco; cor via vértice)
writeTGA("IconLeave.tga", 64, 64, (x, y) => {
  const inside = (px, py) => {
    // batente: topo, lado direito, base e tocos à esquerda
    const T = 4;
    const top = py >= 12 && py <= 12 + T && px >= 27 && px <= 54;
    const bot = py >= 48 - T && py <= 48 && px >= 27 && px <= 54;
    const rgt = px >= 54 - T && px <= 54 && py >= 12 && py <= 48;
    const stubT = px >= 27 && px <= 27 + T && py >= 12 && py <= 22;
    const stubB = px >= 27 && px <= 27 + T && py >= 38 && py <= 48;
    // seta: haste + ponta triangular
    const shaft = py >= 26 && py <= 34 && px >= 20 && px <= 44;
    const head = px >= 6 && px <= 22 && Math.abs(py - 30) <= (px - 6) * 0.85;
    return top || bot || rgt || stubT || stubB || shaft || head;
  };
  return [255, 255, 255, coverage(x, y, inside)];
});
