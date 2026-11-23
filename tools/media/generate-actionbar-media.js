// Gera as texturas da barra de ação (Media/ActionBar/*.tga, TGA 32 bits).
// Reproduz os espaços de habilidade do Azaath: fundo quase preto com
// degradê vertical (mais claro embaixo) e hachura diagonal "/" que aparece na
// metade de baixo; hachura escura no canto inferior esquerdo por cima dos
// ícones; e a caixinha arredondada preta com filete cinza da tecla.
// Valores amostrados da captura de referência.
// Uso: node tools/media/generate-actionbar-media.js
const fs = require("fs");
const path = require("path");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "ActionBar");
fs.mkdirSync(OUT, { recursive: true });

const clamp01 = (v) => Math.max(0, Math.min(1, v));
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = (e0, e1, x) => {
  const t = clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
};

// ruído de valor determinístico + fbm (mesmo do gerador do inventário)
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
function fbm(x, y, seed, oct = 3) {
  let sum = 0, amp = 0.5, norm = 0, f = 1;
  for (let i = 0; i < oct; i++) {
    sum += amp * vnoise(x * f, y * f, seed + i * 17);
    norm += amp;
    amp *= 0.5;
    f *= 2;
  }
  return sum / norm;
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
      const i = ((h - 1 - y) * w + x) * 4;
      data[i] = Math.round(Math.max(0, Math.min(255, b)));
      data[i + 1] = Math.round(Math.max(0, Math.min(255, g)));
      data[i + 2] = Math.round(Math.max(0, Math.min(255, r)));
      data[i + 3] = Math.round(clamp01(a) * 255);
    }
  }
  fs.writeFileSync(path.join(OUT, file), Buffer.concat([header, data]));
  console.log("gerado ActionBar/" + file);
}

// Faixa diagonal "/" suave (período em px da textura), média com 4x4 amostras
// para não serrilhar ao reduzir no jogo.
function stripe(x, y, period, width) {
  let s = 0;
  for (let j = 0; j < 4; j++) {
    for (let i = 0; i < 4; i++) {
      const p = (x + (i + 0.5) / 4) + (y + (j + 0.5) / 4);
      const f = ((p % period) + period) % period;
      s += f < width ? 1 : 0;
    }
  }
  return s / 16;
}

// ---------------------------------------------------------------------------
// Fundo do espaço (só o preenchimento: a borda de 1px vem do backdrop)
// ---------------------------------------------------------------------------
const S = 64;
writeTGA("Slot.tga", S, S, (x, y) => {
  const t = y / (S - 1);
  // degradê: ~2 no topo -> ~36 embaixo (curva amostrada da referência)
  let v = lerp(4, 50, Math.pow(t, 1.1));
  // leve clareamento à direita na parte de baixo
  v += 6 * smooth(0.5, 1, x / (S - 1)) * t;
  // hachura clara que surge da metade para baixo
  const h = stripe(x, y, 8, 3.4);
  v += h * 26 * smooth(0.15, 0.9, t);
  return [v, v, v * 1.02, 1];
});

// ---------------------------------------------------------------------------
// Hachura escura por cima do ícone (canto inferior esquerdo, some para cima)
// ---------------------------------------------------------------------------
writeTGA("Hatch.tga", S, S, (x, y) => {
  const d = Math.hypot(x / (S - 1), (S - 1 - y) / (S - 1)); // 0 no canto inf. esq.
  const fade = 1 - smooth(0.15, 0.68, d);
  const h = stripe(x, y, 8, 3.4);
  return [0, 0, 0, h * fade * 0.42];
});

// ---------------------------------------------------------------------------
// Caixinha da tecla: preta, cantos arredondados, filete cinza (~1px no jogo)
// 32x32 desenhada para ser usada em 3 fatias (cantos não esticam).
// ---------------------------------------------------------------------------
const K = 32, R = 7, LINE = 2.1;
function sdRoundRect(px, py, x0, y0, x1, y1, r) {
  const cx = (x0 + x1) / 2, cy = (y0 + y1) / 2;
  const hx = (x1 - x0) / 2 - r, hy = (y1 - y0) / 2 - r;
  const qx = Math.abs(px - cx) - hx, qy = Math.abs(py - cy) - hy;
  const ox = Math.max(qx, 0), oy = Math.max(qy, 0);
  return Math.hypot(ox, oy) + Math.min(Math.max(qx, qy), 0) - r;
}
writeTGA("KeyBox.tga", K, K, (x, y) => {
  let rgb = [0, 0, 0], a = 0;
  let cov = 0, line = 0;
  for (let j = 0; j < 4; j++) {
    for (let i = 0; i < 4; i++) {
      const px = x + (i + 0.5) / 4, py = y + (j + 0.5) / 4;
      const d = sdRoundRect(px, py, 0.5, 0.5, K - 0.5, K - 0.5, R);
      if (d <= 0) {
        cov++;
        if (d > -LINE) line++;
      }
    }
  }
  if (cov === 0) return [0, 0, 0, 0];
  // filete um pouco mais claro em cima (~88) do que embaixo (~78)
  const lineV = lerp(86, 74, y / (K - 1));
  const fl = line / cov;
  const v = lerp(2, lineV, fl);
  rgb = [v, v, v * 1.02];
  a = cov / 16;
  return [rgb[0], rgb[1], rgb[2], a];
});

// ---------------------------------------------------------------------------
// Moldura do espaço: filete claro "pintado à mão" (intensidade irregular ao
// longo de cada lado, falhas leves, cantos mais acesos) com um halo suave por
// fora. Branca + alpha; no jogo cobre o botão com 1px de sobra para fora
// (64 px da textura ~ 44 px na tela, então ~1,5 px de textura = 1 px de tela).
// ---------------------------------------------------------------------------
const B = 64;
const HALO_C = 0.9, CORE_C = 2.3; // centros (px da textura a partir da borda)
function edgeIntensity(t, seed) {
  // variação lenta + grão fino + falhas ocasionais (como na arte do Azaath)
  let k = 0.9 + 0.42 * (fbm(t / 7, 0.5, seed, 3) - 0.5) * 2 * 0.5
        + 0.16 * (vnoise(t / 1.3, 4.5, seed + 3) - 0.5);
  const gap = fbm(t / 3.5, 8.5, seed + 7, 2);
  k *= lerp(0.68, 1, smooth(0.28, 0.4, gap));
  return clamp01(k);
}
writeTGA("SlotBorder.tga", B, B, (x, y) => {
  let acc = 0;
  for (let j = 0; j < 4; j++) {
    for (let i = 0; i < 4; i++) {
      const px = x + (i + 0.5) / 4, py = y + (j + 0.5) / 4;
      const sides = [
        [py, px, 101],          // topo
        [B - py, px + 64, 102], // base
        [px, py + 128, 103],    // esquerda
        [B - px, py + 192, 104] // direita
      ];
      let best = 0;
      for (const [d, t, seed] of sides) {
        if (d > 4.5) continue;
        const k = edgeIntensity(t, seed);
        const core = Math.max(0, 1 - Math.abs(d - CORE_C) / 1.4);
        const halo = Math.max(0, 1 - Math.abs(d - HALO_C) / 1.0) * 0.5;
        best = Math.max(best, Math.max(core, halo) * k);
      }
      // cantos um pouco mais acesos (pontinhos claros da referência)
      const dc = Math.min(
        Math.hypot(px - CORE_C, py - CORE_C), Math.hypot(B - px - CORE_C, py - CORE_C),
        Math.hypot(px - CORE_C, B - py - CORE_C), Math.hypot(B - px - CORE_C, B - py - CORE_C));
      best = Math.min(1, best + 0.35 * Math.max(0, 1 - dc / 2.2));
      acc += best;
    }
  }
  const a = (acc / 16) * 1.0; // pico = branco quase puro (bem visível no tamanho do jogo)
  return [232, 234, 234, a];
});
