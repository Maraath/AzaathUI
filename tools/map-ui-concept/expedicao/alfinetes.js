// Marcadores de missão como no conceito do Azaath (medidos das capturas 5/6/7):
//   pegar     = losango dourado vazado (anel amarelo, contorno dourado-escuro, furo escuro) numa agulha reta
//   repetível = o mesmo em azul
//   entregar  = lâmina verde-água alongada com espigão em cima, furo escuro
//   andamento = losango dourado liso com contorno escuro e dois chevrons (V) por baixo
//   node alfinetes.js -> PinGetJ / PinGetK / PinDoneJ / PinProgJ (tga nas duas pastas + png de conferência)
"use strict";
const path = require("path"), I = require("../../sheet-concept/img");
const SS = 4, SHADOW = [30, 20, 10], CX = 32;
const inPoly = (x, y, p) => { let c = false; for (let i = 0, j = p.length - 1; i < p.length; j = i++) if (((p[i][1] > y) !== (p[j][1] > y)) && (x < (p[j][0] - p[i][0]) * (y - p[i][1]) / (p[j][1] - p[i][1]) + p[i][0])) c = !c; return c; };
const lerp = (a, b, t) => a.map((v, k) => v + (b[k] - v) * t);
const clamp = (t) => Math.min(1, Math.max(0, t));
const mirror = (r) => r.map(([x, y]) => [CX + x, y]).concat(r.slice().reverse().map(([x, y]) => [CX - x, y]));
// lâmina verde: metade direita (x relativo ao centro)
const BLADE = mirror([[0, 3], [1.3, 12], [1.9, 24], [3, 29], [8, 33], [16.5, 39], [12, 46], [8, 56], [4, 66], [1.5, 74], [0, 80]]);
const HOLE = [[CX, 36], [CX + 7, 46], [CX, 62], [CX - 7, 46]];
const dist2 = (x, y, ax, ay, bx, by) => { const dx = bx - ax, dy = by - ay, t = clamp(((x - ax) * dx + (y - ay) * dy) / (dx * dx + dy * dy)); return Math.hypot(x - (ax + t * dx), y - (ay + t * dy)); };
const SHAPES = {
  get: (T) => (x, y) => {                      // losango (centro 32,26), meia-diagonal 19
    const dd = Math.abs(x - CX) + Math.abs(y - 26);
    if (dd <= 19) { if (dd >= 17.4) return T.edge; return dd <= 8.4 ? T.hole : lerp(T.hi, T.lo, clamp((y - 8) / 36)); }
    if (y >= 44 && y <= 82) { const hw = 1.9; if (Math.abs(x - CX) <= hw) return Math.abs(x - CX) >= hw - 0.7 ? T.edge : T.needle; }
    return null;
  },
  done: (T) => (x, y) => {
    if (!inPoly(x, y, BLADE)) return null;
    if (inPoly(x, y, HOLE)) return T.hole;
    return lerp(T.hi, T.lo, clamp((y - 28) / 46));
  },
  prog: (T) => (x, y) => {                     // losango liso + 2 chevrons; centro do losango (32,22)
    const dd = Math.abs(x - CX) + Math.abs(y - 22);
    if (dd <= 19) return dd >= 17.2 ? T.edge : lerp(T.hi, T.lo, clamp((y - 3) / 38));
    // chevrons: V de ápice (32, 22+19*k), braços a 45° até |dx| <= 14
    for (const k of [1.18, 1.62]) {
      const ay = 22 + 19 * k, dx = Math.abs(x - CX);
      if (dx <= 14.5) { const d = Math.abs(y - (ay - dx)) * Math.SQRT1_2; if (d <= 1.5) return d >= 0.85 ? T.edge : T.needle; }
    }
    return null;
  },
};
const THEME = {
  gold: { hi: [253, 232, 96], lo: [243, 212, 70], hole: [88, 66, 34], needle: [252, 232, 130], edge: [176, 130, 24] },
  blue: { hi: [150, 212, 255], lo: [100, 170, 245], hole: [28, 40, 72], needle: [180, 222, 255], edge: [40, 90, 170] },
  green: { hi: [150, 248, 208], lo: [104, 226, 176], hole: [52, 70, 62] },
  prog: { hi: [255, 208, 70], lo: [250, 190, 50], needle: [253, 228, 120], edge: [150, 100, 14] },
};
function make(name, shape, th, W, H) {
  const f = SHAPES[shape](THEME[th]), out = I.create(W, H), cov = new Float32Array(W * H), col = new Array(W * H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    let n = 0, r = 0, g = 0, b = 0;
    for (let j = 0; j < SS; j++) for (let i = 0; i < SS; i++) { const c = f(x + (i + .5) / SS, y + (j + .5) / SS); if (c) { n++; r += c[0]; g += c[1]; b += c[2]; } }
    cov[y * W + x] = n / (SS * SS); col[y * W + x] = n ? [r / n, g / n, b / n] : null;
  }
  const span = 2;
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
    let dmin = 99;
    for (let dy = -span; dy <= span; dy++) for (let dx = -span; dx <= span; dx++) { const xx = x + dx, yy = y + dy; if (xx < 0 || yy < 0 || xx >= W || yy >= H) continue; if (cov[yy * W + xx] >= 0.5) dmin = Math.min(dmin, Math.hypot(dx, dy)); }
    const sa = cov[y * W + x], ba = 0.42 * Math.max(0, Math.min(1, 1.6 + 0.5 - dmin)), a = sa + ba * (1 - sa), o = (y * W + x) * 4;
    const c = col[y * W + x] || SHADOW;
    for (let k = 0; k < 3; k++) out.px[o + k] = a > 0 ? (c[k] * sa + SHADOW[k] * ba * (1 - sa)) / a : 0;
    out.px[o + 3] = Math.round(a * 255);
  }
  for (const d of ["D:/ProjectAzaath/AzaathUI/Media/MapFrame", "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame"]) I.writeTGA(d + "/" + name + ".tga", out);
  I.writePNG(path.join(__dirname, "out", "icons", name + ".png"), out);
}
make("PinGetJ", "get", "gold", 64, 96); make("PinGetK", "get", "blue", 64, 96);
make("PinDoneJ", "done", "green", 64, 96); make("PinProgJ", "prog", "prog", 64, 64);
