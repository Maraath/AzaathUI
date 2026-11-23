// Troca "NÚCLEO PRIMORDIAL DE AZOTH" por "NÚCLEO PRIMORDIAL DE AZAATH" no arco em volta do
// núcleo de crucible.png, usando as próprias letras da arte (nada de fonte nova):
//   1. desenrola o anel do texto numa faixa reta (ângulo x raio);
//   2. separa letras e fundo (fundo = interpolação entre colunas sem letra, linha a linha);
//   3. remonta a frase com o "A" da própria palavra no lugar do "O" (A Z A A T H) e
//      a recentraliza no arco;
//   4. enrola de volta: fundo + (letras deslocadas).
// Uso: require("./rename-arc")(src) logo após ler crucible.png (gen.js).
//      node rename-arc.js -> preview/arc_before.png e preview/arc_after.png (faixa ampliada)

// geometria do anel em cada arte: centro, faixa entre os dois filetes, setor do texto (graus)
const GEO = {
  concept: { cx: 536, cy: 383.5, r0: 103.5, r1: 122.5, t0: -144, t1: -34 },   // crucible.png 1376x768
  game:    { cx: 797.8, cy: 570.8, r0: 148.5, r1: 168.5, t0: -144, t1: -36 }, // CrucibleBG.tga 2048 (anel redesenhado)
};
const A0 = -165, A1 = -15;             // setor (graus, y para baixo; topo = -90)
const DA = 0.05, DR = 0.25;            // passo da faixa

function renameArc(src, dbg, g = GEO.concept) {
  const CX = g.cx, CY = g.cy, R0 = g.r0, R1 = g.r1;
  const NW = Math.round((A1 - A0) / DA) + 1, NH = Math.round((R1 - R0) / DR) + 1;
  const px = src.px, W = src.w;
  const bil = (x, y, k) => {
    const xi = Math.floor(x), yi = Math.floor(y), tx = x - xi, ty = y - yi;
    const p = (a, b) => px[(b * W + a) * 4 + k];
    return (p(xi, yi) * (1 - tx) + p(xi + 1, yi) * tx) * (1 - ty) + (p(xi, yi + 1) * (1 - tx) + p(xi + 1, yi + 1) * tx) * ty;
  };
  // 1. faixa
  const S = new Float32Array(NW * NH * 3);
  for (let j = 0; j < NH; j++) for (let i = 0; i < NW; i++) {
    const t = (A0 + i * DA) * Math.PI / 180, r = R0 + j * DR;
    const x = CX + r * Math.cos(t), y = CY + r * Math.sin(t);
    for (let k = 0; k < 3; k++) S[(j * NW + i) * 3 + k] = bil(x, y, k);
  }
  const isText = (c) => { const m = Math.min(c[0], c[1], c[2]), M = Math.max(c[0], c[1], c[2]); return m > 130 && M - m < 75; };
  // colunas com letra (só dentro do trecho do texto: entre o feixe dourado e as runas)
  const T0 = Math.round((g.t0 - A0) / DA), T1 = Math.round((g.t1 - A0) / DA); // N .. H (fora: feixe dourado e runas)
  const col = new Uint8Array(NW);
  for (let i = T0; i <= T1; i++) for (let j = 0; j < NH; j++) {
    const o = (j * NW + i) * 3;
    if (isText([S[o], S[o + 1], S[o + 2]]) && ++col[i] >= 2) break;
  }
  // corridas = letras (junta buracos pequenos dentro da mesma letra)
  let runs = [];
  for (let i = 0; i < NW; i++) col[i] = col[i] >= 2 ? 1 : 0;
  for (let i = 0; i < NW; i++) if (col[i]) {
    let e = i; while (e + 1 < NW && col[e + 1]) e++;
    if (runs.length && i - runs[runs.length - 1][1] <= 6) runs[runs.length - 1][1] = e; else runs.push([i, e]);
    i = e;
  }
  runs = runs.filter((r) => r[1] - r[0] >= 6);
  if (dbg) console.log("letras:", runs.length, runs.map((r) => ((r[0] * DA + A0).toFixed(1)) + "/" + ((r[1] - r[0]) * DA).toFixed(1)).join(" "));
  // as 5 últimas corridas são A Z O T H (algumas letras de cima saem em 2 pedaços; não importa)
  if (runs.length < 20) throw new Error("rename-arc: letras não encontradas (" + runs.length + ")");
  const [rA, rZ, rO, rT, rH] = runs.slice(-5);
  // máscara dilatada das letras
  const PAD = 8;
  const mask = new Uint8Array(NW);
  for (const [a, b] of runs) for (let i = Math.max(0, a - PAD); i <= Math.min(NW - 1, b + PAD); i++) mask[i] = 1;
  // 2. fundo: linha a linha, interpolação entre colunas livres
  const B = Float32Array.from(S);
  for (let i = 0; i < NW; i++) if (mask[i]) {
    let a = i; while (a > 0 && mask[a]) a--;
    let b = i; while (b < NW - 1 && mask[b]) b++;
    const t = (i - a) / (b - a);
    for (let j = 0; j < NH; j++) for (let k = 0; k < 3; k++) {
      const o = j * NW, va = S[(o + a) * 3 + k], vb = S[(o + b) * 3 + k];
      B[(o + i) * 3 + k] = va * (1 - t) + vb * t;
    }
  }
  // camada das letras = faixa - fundo (preserva o antisserrilhado e o brilho originais)
  const D = new Float32Array(S.length);
  for (let i = 0; i < NW; i++) if (mask[i]) for (let j = 0; j < NH; j++) for (let k = 0; k < 3; k++) {
    const o = (j * NW + i) * 3 + k; D[o] = S[o] - B[o];
  }
  // 3. nova sequência de colunas: [início .. fim do Z] + vão + A + vão + A + [fim do O .. fim]
  const s0 = runs[0][0] - PAD, e0 = rH[1] + PAD;
  const gap = rO[0] - rZ[1];
  const seq = [];
  const push = (a, b) => { for (let i = a; i <= b; i++) seq.push(i); };
  const blank = (n) => { for (let i = 0; i < n; i++) seq.push(-1); };
  push(s0, rZ[1]); blank(gap - 1);
  push(rA[0], rA[1]); blank(gap - 1);
  push(rA[0], rA[1]); push(rO[1] + 1, e0);
  const shift = Math.round(((e0 - s0 + 1) - seq.length) / 2); // recentraliza
  const n0 = s0 + shift;
  const Dn = new Float32Array(S.length);
  for (let n = 0; n < seq.length; n++) {
    const si = seq[n], di = n0 + n; if (si < 0 || di < 0 || di >= NW) continue;
    for (let j = 0; j < NH; j++) for (let k = 0; k < 3; k++) Dn[(j * NW + di) * 3 + k] = D[(j * NW + si) * 3 + k];
  }
  // 4. enrola de volta (só no trecho mexido)
  const lo = Math.min(s0, n0), hi = Math.max(e0, n0 + seq.length);
  const sample = (arr, fi, fj, k) => {
    const i0 = Math.floor(fi), j0 = Math.floor(fj), ti = fi - i0, tj = fj - j0;
    const g = (i, j) => arr[(Math.min(NH - 1, j) * NW + Math.min(NW - 1, i)) * 3 + k];
    return (g(i0, j0) * (1 - ti) + g(i0 + 1, j0) * ti) * (1 - tj) + (g(i0, j0 + 1) * (1 - ti) + g(i0 + 1, j0 + 1) * ti) * tj;
  };
  const xmin = Math.floor(CX - R1 - 1), xmax = Math.ceil(CX + R1 + 1), ymin = Math.floor(CY - R1 - 1), ymax = Math.ceil(CY);
  for (let y = ymin; y <= ymax; y++) for (let x = xmin; x <= xmax; x++) {
    const r = Math.hypot(x - CX, y - CY); if (r < R0 + 0.5 || r > R1 - 0.5) continue;
    const a = Math.atan2(y - CY, x - CX) * 180 / Math.PI;
    const fi = (a - A0) / DA, fj = (r - R0) / DR;
    if (fi < lo || fi > hi) continue;
    const o = (y * W + x) * 4;
    for (let k = 0; k < 3; k++) {
      const v = sample(B, fi, fj, k) + sample(Dn, fi, fj, k);
      px[o + k] = Math.max(0, Math.min(255, v));
    }
  }
  if (dbg) return { S, NW, NH, Snew: (() => { const o = new Float32Array(S.length); for (let i = 0; i < o.length; i++) o[i] = B[i] + Dn[i]; return o; })() };
}

module.exports = renameArc;

// node rename-arc.js --tga <entrada.tga> <saída.tga>: aplica direto no CrucibleBG.tga em uso
// (anel redesenhado, geometria GEO.game)
if (require.main === module && process.argv[2] === "--tga") {
  const fs = require("fs");
  const I = require("../sheet-concept/img");
  const b = fs.readFileSync(process.argv[3]);
  const w = b.readUInt16LE(12), h = b.readUInt16LE(14), bp = b[16] / 8, top = (b[17] & 0x20) !== 0;
  if (b[2] !== 2) throw new Error("TGA comprimido não suportado");
  const im = I.create(w, h), o0 = 18 + b[0];
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const yy = top ? y : h - 1 - y, i = (yy * w + x) * 4, s = o0 + (y * w + x) * bp;
    im.px[i] = b[s + 2]; im.px[i + 1] = b[s + 1]; im.px[i + 2] = b[s]; im.px[i + 3] = bp === 4 ? b[s + 3] : 255;
  }
  renameArc(im, true, GEO.game);
  I.writeTGA(process.argv[4], im);
  console.log("gravado", process.argv[4], w + "x" + h);
} else if (require.main === module) {
  const path = require("path");
  const I = require("../sheet-concept/img");
  const { readPNG } = require("../grimoire-concept/png");
  const src = readPNG(path.join(__dirname, "crucible.png"));
  const toImg = (arr, NW, NH) => {
    const im = I.create(NW, NH);
    for (let j = 0; j < NH; j++) for (let i = 0; i < NW; i++) for (let k = 0; k < 3; k++) {
      im.px[((NH - 1 - j) * NW + i) * 4 + k] = arr[(j * NW + i) * 3 + k]; im.px[((NH - 1 - j) * NW + i) * 4 + 3] = 255;
    }
    return im;
  };
  const r = renameArc(src, true);
  const PREV = path.join(__dirname, "preview");
  require("fs").mkdirSync(PREV, { recursive: true });
  I.writePNG(path.join(PREV, "arc_before.png"), I.resize(toImg(r.S, r.NW, r.NH), 1500, 120));
  I.writePNG(path.join(PREV, "arc_after.png"), I.resize(toImg(r.Snew, r.NW, r.NH), 1500, 120));
  I.writePNG(path.join(PREV, "arc_core.png"), I.resize(I.crop(src, 400, 250, 280, 110), 1120, 440));
}
