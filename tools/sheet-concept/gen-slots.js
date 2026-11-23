// Texturas dos medalhões de equipamento da ficha (tecla C):
//   SlotAura      — halo macio em anel (branco, tingido pela raridade, ADD)
//   SlotAuraWisps — línguas de energia irregulares saindo do anel (gira, ADD)
//   SlotBezel     — aro metálico escuro com luz no topo (cores reais, BLEND)
//   SlotRimLine   — filete fino na borda interna do aro (tingido, ADD)
//   SlotVignette  — sombra na borda do ícone (funde o ícone ao aro)
// Uso: node tools/sheet-concept/gen-slots.js
const path = require("path");
const I = require("./img");
const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Sheet");

const clamp = (v) => Math.max(0, Math.min(1, v));
const smooth = (a, b, x) => { const t = clamp((x - a) / (b - a)); return t * t * (3 - 2 * t); };

// ruído angular periódico (soma de senos com fases fixas)
function angNoise(a, seed, octaves) {
  let v = 0, amp = 1, tot = 0;
  for (let o = 0; o < octaves; o++) {
    const f = [3, 5, 7, 11, 13, 17, 23][o];
    v += amp * Math.sin(a * f + seed * (o + 1) * 1.7 + o * 2.3);
    tot += amp; amp *= 0.62;
  }
  return v / tot; // -1..1
}

function gen(size, fn) {
  const im = I.create(size, size);
  const c = size / 2;
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const dx = (x + 0.5 - c) / c, dy = (y + 0.5 - c) / c;
    const r = Math.hypot(dx, dy), a = Math.atan2(dy, dx);
    const [R, G, B, A] = fn(r, a, dx, dy);
    const o = (y * size + x) * 4;
    im.px[o] = R * 255; im.px[o + 1] = G * 255; im.px[o + 2] = B * 255; im.px[o + 3] = clamp(A) * 255;
  }
  return im;
}

// Escala: no jogo a aura é desenhada com 2.2x o tamanho do botão.
// Raio do aro no espaço da aura ~ 0.5/2.2*... => o anel brilhante fica em r≈0.50
const aura = gen(256, (r) => {
  const ring = Math.exp(-((r - 0.50) ** 2) / (2 * 0.075 ** 2));
  const bloom = Math.exp(-((r - 0.48) ** 2) / (2 * 0.17 ** 2)) * 0.55;
  const a = (ring * 0.9 + bloom) * smooth(1.0, 0.86, r) * smooth(0.18, 0.40, r);
  return [1, 1, 1, a];
});

const wisps = gen(256, (r, a) => {
  const n1 = angNoise(a, 1.3, 6), n2 = angNoise(a * 1 + 0.7, 4.1, 5);
  // comprimento das línguas varia com o ângulo
  const reach = 0.64 + 0.26 * (0.5 + 0.5 * n1) + 0.10 * Math.max(0, n2);
  const base = smooth(0.40, 0.50, r);
  const fade = 1 - smooth(0.50, reach, r);
  // estrias finas (fios de energia)
  const strands = 0.55 + 0.45 * Math.abs(Math.sin(a * 19 + n2 * 3));
  const alpha = base * fade * strands * (0.65 + 0.35 * n1) * smooth(1.0, 0.9, r);
  return [1, 1, 1, alpha];
});

// Aro: o botão ocupa r<=0.80 deste quadro (aro desenhado com 1.25x o botão)
const bezel = gen(256, (r, a, dx, dy) => {
  const inner = 0.80, outer = 0.97;
  const inside = smooth(inner - 0.012, inner + 0.012, r) * (1 - smooth(outer - 0.015, outer + 0.01, r));
  if (inside <= 0) {
    // sombra projetada fora do aro
    const sh = Math.exp(-((r - 0.99) ** 2) / (2 * 0.03 ** 2)) * 0.45 * (r > outer ? 1 : 0);
    return [0, 0, 0, sh];
  }
  const t = (r - inner) / (outer - inner);            // 0 dentro .. 1 fora
  const light = 0.5 - 0.5 * dy / Math.max(r, 1e-3);   // 1 no topo, 0 embaixo
  // perfil chanfrado: brilho no meio do aro, bordas escuras
  const bevel = Math.sin(Math.PI * t);
  const groove = Math.exp(-((t - 0.5) ** 2) / (2 * 0.06 ** 2)) * 0.35; // sulco central
  let v = 0.07 + 0.26 * bevel * (0.45 + 0.55 * light) - groove * 0.25;
  // reflexo especular no topo-esquerdo
  const spec = Math.exp(-((Math.atan2(dy, dx) + 2.2) ** 2) / 0.18) * Math.exp(-((t - 0.35) ** 2) / 0.02) * 0.45;
  v += spec;
  // leve tom aço-azulado
  return [v * 0.92, v * 0.97, v * 1.06, inside];
});

const rim = gen(256, (r) => {
  const a = Math.exp(-((r - 0.80) ** 2) / (2 * 0.010 ** 2)) + Math.exp(-((r - 0.80) ** 2) / (2 * 0.035 ** 2)) * 0.35;
  return [1, 1, 1, a];
});

// Vinheta sobre o ícone (desenhada do tamanho do ícone)
const vignette = gen(128, (r) => [0, 0, 0, smooth(0.62, 1.0, r) * 0.85 * (r <= 1.02 ? 1 : 0)]);

for (const [n, im] of Object.entries({ SlotAura: aura, SlotAuraWisps: wisps, SlotBezel: bezel, SlotRimLine: rim, SlotVignette: vignette })) {
  I.writeTGA(path.join(OUT, n + ".tga"), im);
  console.log("gerado", n);
}

// Prévia: medalhão verde, azul e roxo sobre fundo escuro
const prev = I.create(600, 220, 8, 14, 22, 255);
function addOver(dst, src, cx, cy, size, col, mode) {
  const s = I.resize(src, size, size);
  for (let j = 0; j < size; j++) for (let i = 0; i < size; i++) {
    const x = Math.round(cx - size / 2 + i), y = Math.round(cy - size / 2 + j);
    if (x < 0 || y < 0 || x >= dst.w || y >= dst.h) continue;
    const o = (y * dst.w + x) * 4, q = (j * size + i) * 4, al = s.px[q + 3] / 255;
    for (let k = 0; k < 3; k++) {
      const v = s.px[q + k] * col[k];
      dst.px[o + k] = mode === "add" ? Math.min(255, dst.px[o + k] + v * al) : dst.px[o + k] * (1 - al) + v * al;
    }
  }
}
const cols = [[0.12, 1, 0], [0, 0.44, 0.87], [0.64, 0.21, 0.93]];
cols.forEach((q, k) => {
  const cx = 110 + k * 190, cy = 110, sz = 64;
  addOver(prev, aura, cx, cy, Math.round(sz * 2.2), q.map((v) => v * 0.8), "add");
  addOver(prev, wisps, cx, cy, Math.round(sz * 2.2), q.map((v) => v * 0.9), "add");
  // ícone fictício
  addOver(prev, I.create(8, 8, 150, 110, 70, 255), cx, cy, sz - 8, [1, 1, 1], "blend");
  addOver(prev, vignette, cx, cy, sz - 8, [1, 1, 1], "blend");
  addOver(prev, bezel, cx, cy, Math.round(sz * 1.25), [1, 1, 1], "blend");
  addOver(prev, rim, cx, cy, Math.round(sz * 1.25), q, "add");
});
I.writePNG(path.join(__dirname, "preview", "slots-preview.png"), I.resize(prev, 1200, 440));
