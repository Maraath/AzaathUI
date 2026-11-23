// Gera as texturas da barra de vida do alvo (Media/Target/*.tga, TGA 32 bits).
// Reproduz a barra de inimigos do Azaath, com medidas e cores amostradas
// das capturas de referência (barra de 155 x 10 px numa tela 1080p = "unidades"):
//   Fill      preenchimento em tons de cinza (tingido pela reação no jogo):
//             degradê horizontal escuro -> claro, manchas e sombreado vertical
//   Flash     pedaço de vida perdida: branco granulado
//   Empty     fundo da parte vazia: marrom quase preto com hachura "/" (ladrilho)
//   Frame     moldura de combate (3 fatias: ponta esquerda em pincel, meio,
//             ponta direita), tingida pela reação
//   Badge     losango do nível (pentágono com ponta para baixo), tingido
//   EliteSilver / EliteGold  asas metálicas + contorno do losango + filete
// Uso: node tools/media/generate-target-media.js
const fs = require("fs");
const path = require("path");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Target");
fs.mkdirSync(OUT, { recursive: true });

const clamp01 = (v) => Math.max(0, Math.min(1, v));
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = (e0, e1, x) => {
  const t = clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
};
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

// fn(x, y) -> [r, g, b, a] com r/g/b em 0..255 e a em 0..1 (y = 0 no topo).
// ss = superamostragem (ss x ss amostras por texel) para bordas suaves.
function writeTGA(file, w, h, fn, ss = 1) {
  const header = Buffer.alloc(18);
  header[2] = 2;
  header.writeUInt16LE(w, 12);
  header.writeUInt16LE(h, 14);
  header[16] = 32;
  header[17] = 8;
  const data = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let j = 0; j < ss; j++) {
        for (let i = 0; i < ss; i++) {
          const [sr, sg, sb, sa] = fn(x + (i + 0.5) / ss, y + (j + 0.5) / ss);
          r += sr * sa; g += sg * sa; b += sb * sa; a += sa;
        }
      }
      // média com alpha pré-multiplicado (evita franja escura nas bordas)
      if (a > 0) { r /= a; g /= a; b /= a; }
      a /= ss * ss;
      const o = ((h - 1 - y) * w + x) * 4;
      data[o] = Math.round(Math.max(0, Math.min(255, b)));
      data[o + 1] = Math.round(Math.max(0, Math.min(255, g)));
      data[o + 2] = Math.round(Math.max(0, Math.min(255, r)));
      data[o + 3] = Math.round(clamp01(a) * 255);
    }
  }
  fs.writeFileSync(path.join(OUT, file), Buffer.concat([header, data]));
  console.log("gerado Target/" + file);
}

//------------------------------------------------------------------------------
// Fill: 256 x 16, cinza (multiplicado no jogo pela cor da reação).
// Captura: esquerda ~65% do brilho da direita, leve vale no meio, manchas
// largas; linhas de cima/baixo um pouco mais escuras.
//------------------------------------------------------------------------------
writeTGA("Fill.tga", 256, 16, (x, y) => {
  const t = x / 256, ty = y / 16;
  let v = 0.66 + 0.34 * Math.pow(t, 1.15);
  v *= 0.93 + 0.12 * fbm(x / 22, y / 6, 3, 3);          // manchas largas
  v *= 0.97 + 0.05 * vnoise(x / 3, y / 2, 11);           // grão fino
  v *= 1 - 0.20 * Math.pow(Math.abs(ty - 0.45) / 0.55, 2); // sombreado vertical
  return [255 * v, 255 * v, 255 * v, 1];
}, 2);

//------------------------------------------------------------------------------
// Flash: 128 x 16, branco quente granulado (pedaço de dano recém-perdido)
//------------------------------------------------------------------------------
writeTGA("Flash.tga", 128, 16, (x, y) => {
  const ty = y / 16;
  let v = 0.86 + 0.12 * fbm(x / 9, y / 4, 21, 3);
  v -= 0.10 * smooth(0.6, 0.9, vnoise(x / 2.5, y / 2, 23)); // pintas cinza
  v *= 1 - 0.10 * Math.pow(Math.abs(ty - 0.45) / 0.55, 2);
  return [250 * v, 249 * v, 246 * v, 1];
}, 2);

//------------------------------------------------------------------------------
// Empty: ladrilho 32 x 32 (exibido na altura da barra), hachura "/" com
// período de meio ladrilho para emendar sem costura. Cores da captura:
// fundo (40,18,6), faixas claras (50,28,15) e escuras (34,11,0).
//------------------------------------------------------------------------------
writeTGA("Empty.tga", 32, 32, (x, y) => {
  const p = (((x + (32 - y)) % 16) + 16) % 16 / 16; // 0..1 ao longo do período
  const s = Math.sin(p * Math.PI * 2);
  const v = 0.5 + 0.5 * s;
  const r = lerp(33, 52, v), g = lerp(11, 29, v), b = lerp(1, 15, v);
  return [r, g, b, 0.94];
}, 4);

//------------------------------------------------------------------------------
// Frame: 256 x 64 = 80 x 20 unidades (3,2 texels/unidade), em 3 fatias:
//   ponta esquerda u 0..20 (borda interna da barra em u = 16)
//   meio           u 20..60 (uniforme na horizontal: pode esticar)
//   ponta direita  u 60..80 (borda interna da barra em u = 64)
// Buraco da barra: v 5..15. Faixa: pico claro no meio, linha escura junto
// à barra, borda externa suave (perfil vertical amostrado da captura).
//------------------------------------------------------------------------------
{
  const R = 3.2;
  const IN_L = 16, IN_R = 64, TOP = 5, BOT = 15;
  // perfil de brilho da faixa por distância (unidades) a partir da barra
  function band(d) {
    // d = 0 na borda da barra, cresce para fora (0..5)
    if (d < 0.7) return lerp(0.55, 0.72, d / 0.7);         // separador escuro
    if (d < 2.2) return lerp(0.72, 1.0, (d - 0.7) / 1.5);
    if (d < 3.4) return 1.0;
    return lerp(1.0, 0.70, (d - 3.4) / 1.6);
  }
  function bandAlpha(d) {
    return 1 - smooth(4.0, 5.0, d);
  }
  writeTGA("Frame.tga", 256, 64, (px, py) => {
    const u = px / R, v = py / R;
    const vc = Math.abs(v - 10);           // distância ao centro vertical
    let lum, alpha;

    // dentro do buraco da barra (região do meio e junto às pontas)
    const inHoleY = v > TOP && v < BOT;
    if (u >= IN_L && u <= IN_R) {
      if (inHoleY) return [0, 0, 0, 0];
      const d = v <= TOP ? TOP - v : v - BOT;
      lum = band(d);
      alpha = bandAlpha(d);
    } else if (u < IN_L) {
      // ponta esquerda em pincel: o contorno de cima desce em diagonal até a
      // ponta (u ~ 1, v ~ 12); o de baixo sobe mais suave
      const k = (IN_L - u) / (IN_L - 1);          // 0 na barra .. 1 na ponta
      const topEdge = lerp(0.2, 11.0, Math.pow(k, 1.1));
      const botEdge = lerp(19.8, 13.5, Math.pow(k, 0.9));
      const edge = Math.min(v - topEdge, botEdge - v);
      if (edge < -0.6 || k > 1.02) return [0, 0, 0, 0];
      alpha = smooth(-0.6, 0.6, edge);
      // parede escura junto ao começo da barra
      const dWall = IN_L - u;
      lum = inHoleY ? lerp(0.55, 1.0, smooth(0, 1.6, dWall)) : 1.0;
      if (!inHoleY) {
        const d = v <= TOP ? TOP - v : v - BOT;
        lum = Math.min(lum, band(Math.max(d, 1.8)));
        if (k < 0.15) lum = band(d);
      }
      // traços de pincel "/" que vão abrindo em direção à ponta
      const s = ((u * 0.9 + v * 0.55) % 3.1) / 3.1;
      const streak = smooth(0.0, 0.25, s) * (1 - smooth(0.55, 0.8, s));
      const open = smooth(0.25, 0.95, k);
      alpha *= lerp(1, 0.25 + 0.75 * streak, open);
      lum *= lerp(1, 0.85 + 0.25 * streak, open);
    } else {
      // ponta direita: mais curta, termina em bico arredondado (u ~ 74, v ~ 10)
      const k = (u - IN_R) / 10;                   // 0 na barra .. 1 no bico
      if (k >= 1) return [0, 0, 0, 0];
      const half = 10 * (1 - Math.pow(clamp01(k), 1.6)) - 0.2;
      const edge = half - vc;
      if (edge < -0.6) return [0, 0, 0, 0];
      alpha = smooth(-0.6, 0.6, edge);
      const dWall = u - IN_R;
      if (inHoleY) {
        lum = lerp(0.55, 1.0, smooth(0, 1.6, dWall));
      } else {
        const d = v <= TOP ? TOP - v : v - BOT;
        lum = band(d);
        alpha *= k < 0.3 ? bandAlpha(d) : 1;
      }
      const s = ((u * 0.9 + v * 0.55) % 3.4) / 3.4;
      const streak = smooth(0.0, 0.25, s) * (1 - smooth(0.6, 0.85, s));
      alpha *= lerp(1, 0.45 + 0.55 * streak, smooth(0.35, 1, k));
      lum *= 1 - 0.12 * smooth(0.2, 1, k);
    }
    // escovado horizontal leve
    lum *= 0.93 + 0.1 * fbm(u / 6, v * 1.6, 41, 2);
    alpha *= 0.96;
    return [255 * lum, 255 * lum, 255 * lum, alpha];
  }, 3);
}

//------------------------------------------------------------------------------
// Geometria do losango do nível (unidades, origem no centro do topo):
// topo reto de -22 a +22, laterais retas até v = 4, depois "V" a 45° até a
// ponta em v = 26.
//------------------------------------------------------------------------------
const BADGE_HALF = 22, BADGE_SIDE = 4, BADGE_TIP = 26;
function badgeHalfAt(v) {
  if (v < 0) return -1;
  if (v <= BADGE_SIDE) return BADGE_HALF;
  return BADGE_HALF - (v - BADGE_SIDE) * (BADGE_HALF / (BADGE_TIP - BADGE_SIDE));
}
// distância (aprox., positiva = fora) do ponto à borda lateral/inferior
function badgeDist(u, v) {
  const au = Math.abs(u);
  if (v <= BADGE_SIDE) {
    if (v < 0) return Math.hypot(Math.max(0, au - BADGE_HALF), v);
    return au - BADGE_HALF;
  }
  // distância perpendicular à reta do "V" (45°)
  const k = BADGE_HALF / (BADGE_TIP - BADGE_SIDE);
  const line = au + k * (v - BADGE_SIDE) - BADGE_HALF;
  return line / Math.hypot(1, k);
}

//------------------------------------------------------------------------------
// Badge: 256 x 128 = 64 x 32 unidades (4 texels/unidade), centro em u = 32.
// Cinza claro (tingido no jogo): centro claro, escurece perto da ponta,
// aro um pouco mais claro e sombra escura por fora.
//------------------------------------------------------------------------------
writeTGA("Badge.tga", 256, 128, (px, py) => {
  const u = px / 4 - 32, v = py / 4;
  const d = badgeDist(u, v);
  if (d > 2.4) return [0, 0, 0, 0];
  if (d > 0.5) {
    // sombra externa
    const a = 0.55 * (1 - smooth(0.5, 2.4, d));
    return [10, 6, 6, a];
  }
  let lum = 1.0;
  lum *= 1 - 0.22 * smooth(BADGE_TIP - 12, BADGE_TIP, v);   // escurece na ponta
  lum *= 1 - 0.10 * smooth(4, 20, Math.abs(u));               // laterais
  lum *= 0.95 + 0.07 * fbm(u / 5, v / 5, 61, 2);
  // aro claro (1 unidade) junto à borda
  const rim = smooth(-1.6, -0.6, d) * (1 - smooth(-0.1, 0.5, d));
  lum = lerp(lum, 0.80, rim * 0.8);
  const a = 1 - smooth(0.0, 0.5, d);
  return [255 * lum, 255 * lum, 255 * lum, a];
}, 3);

//------------------------------------------------------------------------------
// Elite: 512 x 128 = 144 x 36 unidades (3,556 texels/unidade), centro u = 72,
// v = 0 no topo do losango. Medidas da captura de elite:
//   filete horizontal logo abaixo da barra (v 1,3..2,6), até ±66 esmaecendo
//   contorno metálico do losango (afastado 2,5..4,5 da borda), até a ponta
//   asas escovadas paralelas ao "V": de vline+8,5 a vline+18 (vline = 26 - v),
//   de v ~1,5 até sumir em v ~21
//------------------------------------------------------------------------------
function writeElite(file, pal) {
  const R = 512 / 144;
  const col = (t) => {
    // t 0..1 -> escuro, médio, claro
    if (t < 0.5) {
      const k = t / 0.5;
      return [lerp(pal.dark[0], pal.mid[0], k), lerp(pal.dark[1], pal.mid[1], k), lerp(pal.dark[2], pal.mid[2], k)];
    }
    const k = (t - 0.5) / 0.5;
    return [lerp(pal.mid[0], pal.hi[0], k), lerp(pal.mid[1], pal.hi[1], k), lerp(pal.mid[2], pal.hi[2], k)];
  };
  writeTGA(file, 512, 128, (px, py) => {
    const u = px / R - 72, v = py / R;
    const au = Math.abs(u);
    let best = null; // [t, alpha]
    const put = (t, a) => {
      if (a <= 0) return;
      if (!best || a > best[1]) best = [t, a];
    };

    // filete horizontal
    {
      const dv = Math.abs(v - 1.95);
      const a = (1 - smooth(0.45, 0.85, dv)) * (1 - smooth(34, 66, au)) * 0.85;
      put(0.62 + 0.15 * fbm(u / 4, 0, 81, 2), a);
    }

    // contorno do losango
    {
      const d = badgeDist(u, v);
      if (v > 0.6) {
        const a = smooth(2.2, 2.7, d) * (1 - smooth(4.3, 4.8, d));
        // mais claro na metade de baixo, como na captura
        put(0.70 + 0.30 * smooth(4, 20, v) - 0.1 * smooth(3.5, 4.6, d), a);
      }
    }

    // asas escovadas
    {
      const vline = BADGE_TIP - v;              // "V" estendido para cima
      const inner = vline + 8.5, outer = vline + 18 + 4 * (1 - smooth(1, 5, v));
      if (v > 1.0 && au > inner - 1 && au < outer + 1) {
        let a = smooth(inner - 0.6, inner + 0.6, au) * (1 - smooth(outer - 0.8, outer + 0.6, au));
        a *= smooth(1.0, 2.2, v) * (1 - smooth(13, 21.5, v));
        // coordenadas ao longo (s) e através (w) da asa
        const s = (v + au) / Math.SQRT2;
        const w = (au - vline) / (outer - inner + 1e-6);
        // fibras escovadas paralelas à asa + riscos escuros em diagonal
        const fiber = fbm(s / 7, (au - v) * 1.4, 91, 3);
        const scratch = smooth(0.72, 0.9, vnoise(s * 0.9, (au - v) * 0.35, 97));
        let t = 0.50 + 0.40 * fiber;
        t += 0.22 * (1 - smooth(0, 0.7, Math.abs(w - 0.35)));  // brilho perto do topo
        t -= 0.30 * scratch * smooth(0.3, 1, w);                // riscos na borda externa
        // borda de baixo esfiapada (some em fiapos, como pincel seco)
        a *= 1 - 0.6 * smooth(0.5, 0.9, fbm(s / 3, (au - v) * 0.8, 101, 2)) * smooth(8, 18, v);
        put(clamp01(t), a);
      }
    }

    if (!best) return [0, 0, 0, 0];
    const [r, g, b] = col(clamp01(best[0]));
    return [r, g, b, clamp01(best[1])];
  }, 3);
}

// Prata amostrada da captura (181,174,172 / 165,161,160 / sombras ~90)
writeElite("EliteSilver.tga", { hi: [232, 228, 224], mid: [168, 162, 158], dark: [78, 72, 70] });
// Ouro: mesmo desenho, paleta dourada
writeElite("EliteGold.tga", { hi: [255, 228, 150], mid: [212, 162, 74], dark: [104, 70, 26] });

//------------------------------------------------------------------------------
// Placa de ALIADOS (capturas do Azaath: aliado fora de combate e em combate)
// AllyDiamond: losango preto 22 x 22 px com aro cinza-claro fino e sombra
//   suave por fora (64 x 64 texels = 22 unidades + margem).
// AllyFill: barra branca de 3 px — linha de cima clara (~0.90), meio um pouco
//   mais escuro (~0.78), linha de baixo ~0.86, clareando para a direita.
//------------------------------------------------------------------------------
writeTGA("AllyDiamond.tga", 64, 64, (px, py) => {
  // 64 texels cobrem 26 unidades (losango de 22 + 2 de margem em cada lado)
  const u = (px / 64) * 26 - 13, v = (py / 64) * 26 - 13;
  const d = Math.abs(u) + Math.abs(v);           // "raio" do losango (norma L1)
  const R = 11;                                   // meia-diagonal do losango
  const edge = (d - R) / Math.SQRT2;              // distância perpendicular à borda
  if (edge > 2.2) return [0, 0, 0, 0];
  if (edge > 0.45) {
    // sombra externa
    return [0, 0, 0, 0.45 * (1 - smooth(0.45, 2.2, edge))];
  }
  // aro claro de ~1 unidade junto à borda, interior preto
  const rim = smooth(-1.3, -0.6, edge) * (1 - smooth(-0.1, 0.45, edge));
  const lum = lerp(4, 118, rim * 0.9);
  const a = 1 - smooth(0.0, 0.45, edge);
  return [lum, lum, lum * 0.98, a];
}, 4);

writeTGA("AllyFill.tga", 128, 8, (x, y) => {
  const t = x / 127;
  const rows = [0.90, 0.90, 0.80, 0.78, 0.80, 0.86, 0.86, 0.86];
  let v = rows[Math.min(7, Math.floor(y))] * (0.95 + 0.05 * t);
  v *= 0.985 + 0.03 * vnoise(x / 6, y / 2, 131);
  return [255 * v, 255 * v, 252 * v, 1];
}, 2);

//------------------------------------------------------------------------------
// Marcadores de estado das placas de inimigo (conceito B)
// TargetArrow: ponta de flecha dourada apontando para baixo (acima do nome do
//   alvo selecionado), contorno escuro e sombra suave.
// AggroEye: medalhão vermelho-escuro com aro vermelho e um olho aceso
//   (ao lado da barra quando o inimigo está em você).
//------------------------------------------------------------------------------
function segDist(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay;
  const t = clamp01(((px - ax) * dx + (py - ay) * dy) / (dx * dx + dy * dy));
  return Math.hypot(px - (ax + dx * t), py - (ay + dy * t));
}
function polySigned(px, py, pts) {
  let inside = false, d = Infinity;
  for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
    const [xi, yi] = pts[i], [xj, yj] = pts[j];
    if ((yi > py) !== (yj > py) && px < ((xj - xi) * (py - yi)) / (yj - yi) + xi) inside = !inside;
    d = Math.min(d, segDist(px, py, xi, yi, xj, yj));
  }
  return inside ? -d : d;
}

writeTGA("TargetArrow.tga", 64, 64, (px, py) => {
  const u = (px / 64) * 2 - 1, v = (py / 64) * 2 - 1;
  // dardo: duas abas em cima, entalhe no meio, ponta embaixo
  const sd = polySigned(u, v, [[-0.78, -0.62], [0, -0.18], [0.78, -0.62], [0, 0.72]]);
  if (sd > 0.04) {
    const a = 0.45 * (1 - smooth(0.04, 0.2, sd));
    return [0, 0, 0, a];
  }
  if (sd > -0.09) return [58, 38, 10, 1 - smooth(0.0, 0.04, sd)];
  const t = clamp01((v + 0.62) / 1.34);
  const hi = [255, 230, 150], lo = [196, 140, 52];
  return [lerp(hi[0], lo[0], t), lerp(hi[1], lo[1], t), lerp(hi[2], lo[2], t), 1];
}, 4);

//------------------------------------------------------------------------------
// Estilo "pincel e tinta" das placas de inimigo (mesmas medidas das texturas
// clássicas, para encaixar sem mudar posições):
//   InkFill   preenchimento cinza (tingido) com bordas de pincel em cima/embaixo,
//             estrias horizontais e a parte de baixo mais escura
//   InkBack   mancha de tinta cor de carvão atrás da barra (fica maior que
//             ela), bordas irregulares e ponta direita em pincel seco
//   InkBadge  losango do nível: contorno de tinta preta irregular e miolo
//             claro com estrias (tingido pela reação)
//   InkFrame  moldura do aggro em traço de pincel, pontas em bico (3 fatias,
//             mesma geometria do Frame: buraco u 16..64, v 5..15)
//------------------------------------------------------------------------------
// bordas de pincel do preenchimento (as mesmas no InkFlash, para o flash de
// dano ficar escondido atrás da vida e só aparecer no pedaço perdido)
function inkFillAlpha(x, y) {
  const ty = y / 16;
  const top = 0.08 + 0.10 * fbm(x / 14, 0.5, 71, 2);
  const bot = 0.92 - 0.10 * fbm(x / 14, 3.5, 72, 2);
  return smooth(top - 0.05, top + 0.05, ty) * (1 - smooth(bot - 0.05, bot + 0.05, ty));
}
writeTGA("InkFill.tga", 256, 16, (x, y) => {
  const t = x / 256, ty = y / 16;
  const a = inkFillAlpha(x, y);
  let v = 0.80 + 0.20 * Math.pow(t, 1.2);
  v *= 0.86 + 0.20 * fbm(x / 30, y / 1.2, 73, 3);      // estrias do pincel
  v *= 1 - 0.35 * smooth(0.62, 0.95, ty);              // base mais escura
  v *= 1 + 0.12 * (1 - smooth(0.1, 0.3, ty));          // realce em cima
  v = Math.min(1, v);
  return [255 * v, 255 * v, 255 * v, a];
}, 2);

// InkFlash: pedaço de vida perdida, branco granulado com as bordas do InkFill
writeTGA("InkFlash.tga", 256, 16, (x, y) => {
  const ty = y / 16;
  let v = 0.86 + 0.12 * fbm(x / 9, y / 4, 21, 3);
  v -= 0.10 * smooth(0.6, 0.9, vnoise(x / 2.5, y / 2, 23));
  v *= 1 - 0.10 * Math.pow(Math.abs(ty - 0.45) / 0.55, 2);
  return [250 * v, 249 * v, 246 * v, inkFillAlpha(x, y)];
}, 2);

writeTGA("InkBack.tga", 256, 32, (x, y) => {
  const t = x / 256, ty = y / 32;
  const top = 0.12 + 0.12 * fbm(x / 18, 1, 81, 3);
  const bot = 0.88 - 0.12 * fbm(x / 18, 5, 82, 3);
  let a = smooth(top - 0.05, top + 0.05, ty) * (1 - smooth(bot - 0.05, bot + 0.05, ty));
  const left = smooth(0.0, 0.05, t + 0.03 * fbm(1, y / 5, 83, 2));   // começo cheio
  const dry = smooth(0.86, 1.0, t);                                    // fim seco
  const streak = smooth(0.35, 0.65, fbm(x / 40, y / 1.5, 84, 3));
  a *= left * (1 - dry * (1 - streak)) * (1 - smooth(0.97, 1.0, t));
  const v = 13 + 10 * fbm(x / 25, y / 2, 85, 3);
  return [v, v, v * 1.05, a * 0.88];
}, 2);

writeTGA("InkBadge.tga", 256, 128, (px, py) => {
  const u = px / 4 - 32, v = py / 4;
  const n = 1.3 * (fbm(u / 3, v / 3, 91, 2) - 0.5);
  const d = badgeDist(u, v) + n;                    // borda irregular
  if (d > 2.6) return [0, 0, 0, 0];
  if (d > -0.4) {                                   // contorno de tinta preta
    const a = 1 - smooth(1.8, 2.6, d);
    return [14, 12, 12, a * 0.95];
  }
  let lum = 0.95 * (0.85 + 0.2 * fbm(u / 8, v / 1.5, 92, 3));   // estrias
  lum *= 1 - 0.25 * smooth(BADGE_TIP - 12, BADGE_TIP, v);
  lum = Math.min(1, lum);
  return [255 * lum, 255 * lum, 255 * lum, 1];
}, 3);

{
  const R = 3.2;
  const outer = [[0.5, 10], [12, 2], [68, 2], [79.5, 10], [68, 18], [12, 18]];
  const inner = [[6.5, 10], [14, 4.6], [66, 4.6], [73.5, 10], [66, 15.4], [14, 15.4]];
  writeTGA("InkFrame.tga", 256, 64, (px, py) => {
    const u = px / R, v = py / R;
    const n1 = 0.8 * (fbm(u / 2.5, v / 2.5, 101, 2) - 0.5);
    const n2 = 0.6 * (fbm(u / 2.5, v / 2.5, 103, 2) - 0.5);
    const so = polySigned(u, v, outer) + n1;
    const si = polySigned(u, v, inner) - n2;
    let a = (1 - smooth(-0.3, 0.3, so)) * smooth(-0.3, 0.3, si);
    if (a <= 0) return [0, 0, 0, 0];
    // pincel seco perto dos bicos
    const tipK = Math.max(smooth(10, 2, u), smooth(70, 78, u));
    const streak = smooth(0.3, 0.6, fbm(u / 1.5, v * 1.8, 104, 2));
    a *= 1 - tipK * (1 - streak) * 0.8;
    const lum = Math.min(1, 0.88 + 0.16 * fbm(u / 10, v * 1.5, 102, 2));
    return [255 * lum, 255 * lum, 255 * lum, a];
  }, 3);
}

writeTGA("AggroEye.tga", 64, 64, (px, py) => {
  const u = (px / 64) * 2 - 1, v = (py / 64) * 2 - 1;
  const r = Math.hypot(u, v);
  if (r > 0.94) return [0, 0, 0, 0.45 * (1 - smooth(0.94, 1.0, r))];
  let col = [52, 10, 8], a = 0.94;
  if (r > 0.76) col = [226, 74, 58];                        // aro
  // olho amendoado
  const w = 0.6;
  if (Math.abs(u) < w) {
    const half = 0.36 * (1 - (u / w) * (u / w));
    if (Math.abs(v) < half) col = [255, 140, 120];
  }
  const pr = Math.hypot(u, v);
  if (pr < 0.17) col = [60, 8, 6];                           // pupila
  if (Math.hypot(u + 0.07, v + 0.07) < 0.05) col = [255, 230, 220]; // brilho
  return [col[0], col[1], col[2], a];
}, 4);
