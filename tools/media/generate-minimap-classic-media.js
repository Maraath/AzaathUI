// Gera as texturas do minimapa "Portulano" da skin Azaath Classic
// (Media/Minimap/*.tga, TGA 32 bits, cores próprias — não usam SetVertexColor).
//
//   PortolanCard  cartão de pergaminho atrás do mapa (512x512 exibido em
//                 CARD_W x CARD_H tamanhos de mapa): manchas, vinheta, borda
//                 gasta, filete duplo, rede de rumos (preto/verde/vermelho)
//                 saindo do centro do mapa e da rosa, régua sob o nome da zona
//   PortolanRing  anel de pergaminho com escala de graus por cima da borda do
//                 mapa (exibido com RING_D x tamanho do mapa)
//   PortolanRose  rosa dos ventos de 16 pontas (N em vermelho)
//   PortolanFleur lírio do norte (marcador que acompanha o minimapa giratório)
//
// A geometria (em "tamanhos de mapa", s = 1) precisa bater com
// Modules/Minimap.lua (bloco PORTOLAN).
// Uso: node tools/media/generate-minimap-classic-media.js
const fs = require("fs");
const path = require("path");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Minimap");
const GAME_OUT = "C:\\Program Files (x86)\\World of Warcraft\\_forever_\\Interface\\AddOns\\AzaathUI\\Media\\Minimap";
fs.mkdirSync(OUT, { recursive: true });
if (fs.existsSync(path.dirname(GAME_OUT))) fs.mkdirSync(GAME_OUT, { recursive: true });

// ---- geometria compartilhada com o Lua ----
const CARD_W = 1.36, CARD_H = 1.66;
const MAP_CX = 0.68, MAP_CY = 0.68;    // centro do mapa no cartão
const RING_R = 0.61;                    // raio exibido da textura do anel
const ROSE_CX = 1.14, ROSE_CY = 1.42;   // centro da rosa no cartão
const RULE_Y = 1.395, RULE_X0 = 0.09, RULE_X1 = 0.90; // régua sob a zona

// ---- utilitários ----
const clamp01 = (v) => Math.max(0, Math.min(1, v));
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = (e0, e1, x) => { const t = clamp01((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t); };
const hex = (h) => [parseInt(h.slice(1, 3), 16) / 255, parseInt(h.slice(3, 5), 16) / 255, parseInt(h.slice(5, 7), 16) / 255];
const mix = (a, b, t) => [lerp(a[0], b[0], t), lerp(a[1], b[1], t), lerp(a[2], b[2], t)];

function hash(x, y, seed) {
  let h = (x * 374761393 + y * 668265263 + seed * 2147483647) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967295;
}
function vnoise(x, y, seed) {
  const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  return lerp(lerp(hash(xi, yi, seed), hash(xi + 1, yi, seed), u),
              lerp(hash(xi, yi + 1, seed), hash(xi + 1, yi + 1, seed), u), v);
}
function fbm(x, y, seed, oct = 4) {
  let s = 0, a = 0.5, n = 0, f = 1;
  for (let i = 0; i < oct; i++) { s += a * vnoise(x * f, y * f, seed + i * 17); n += a; a *= 0.5; f *= 2; }
  return s / n;
}

// Escreve TGA; fn(x, y) recebe coordenadas com y para BAIXO (topo = 0) e
// devolve [r, g, b, a] em 0..1. Supersampling ss x ss.
function writeTGA(file, w, h, fn, ss = 2) {
  const header = Buffer.alloc(18);
  header[2] = 2; header.writeUInt16LE(w, 12); header.writeUInt16LE(h, 14);
  header[16] = 32; header[17] = 8; // origem inferior esquerda
  const data = Buffer.alloc(w * h * 4);
  for (let row = 0; row < h; row++) {
    const y = h - 1 - row;
    for (let x = 0; x < w; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let j = 0; j < ss; j++) for (let i = 0; i < ss; i++) {
        const [sr, sg, sb, sa] = fn(x + (i + 0.5) / ss, y + (j + 0.5) / ss);
        r += sr * sa; g += sg * sa; b += sb * sa; a += sa;
      }
      if (a > 0) { r /= a; g /= a; b /= a; }
      a /= ss * ss;
      const k = (row * w + x) * 4;
      data[k] = Math.round(clamp01(b) * 255);
      data[k + 1] = Math.round(clamp01(g) * 255);
      data[k + 2] = Math.round(clamp01(r) * 255);
      data[k + 3] = Math.round(clamp01(a) * 255);
    }
  }
  const buf = Buffer.concat([header, data]);
  fs.writeFileSync(path.join(OUT, file), buf);
  if (fs.existsSync(GAME_OUT)) fs.writeFileSync(path.join(GAME_OUT, file), buf);
  console.log("gerado", file);
}

// ---- paleta (papel velho: amarelado, manchado, tinta ferrogálica desbotada) ----
const PAPER_HI = hex("#dccb9a"), PAPER_LO = hex("#b99c62");
const STAIN = hex("#9a7440"), EDGE = hex("#5a3a1c"), FOX = hex("#8a5426");
const INK = hex("#3a2814"), GREEN = hex("#4f6a38"), RED = hex("#8c3a22");
const LIGHT = hex("#e2d2a4"), MINOR = hex("#8f7a52"), INTER = hex("#5c4628");

// Manchas de mofo ("foxing"): pintinhas castanhas espalhadas em células
function foxing(u, v) {
  const S = 0.07;
  const cx = Math.floor(u / S), cy = Math.floor(v / S);
  let a = 0;
  for (let j = -1; j <= 1; j++) for (let i = -1; i <= 1; i++) {
    const x = cx + i, y = cy + j;
    if (hash(x, y, 41) > 0.3) continue;
    const px = (x + hash(x, y, 42)) * S, py = (y + hash(x, y, 43)) * S;
    const rad = 0.003 + hash(x, y, 44) * 0.011;
    const d = Math.hypot(u - px, v - py);
    a = Math.max(a, (1 - smooth(rad * 0.4, rad, d)) * (0.25 + hash(x, y, 45) * 0.35));
  }
  return a;
}

// Marcas d'água: borda escura (linha de maré) e miolo levemente tingido
const WATER = [[1.06, 0.22, 0.2], [0.2, 1.5, 0.15], [0.3, 0.3, 0.12]];
function waterStain(u, v) {
  let a = 0;
  for (const [x, y, r] of WATER) {
    const d = Math.hypot(u - x, v - y) + (fbm(u * 9, v * 9, 61) - 0.5) * 0.05;
    a = Math.max(a, (1 - smooth(0.004, 0.012, Math.abs(d - r))) * 0.35, d < r ? 0.1 : 0);
  }
  return a;
}

// Vincos de dobra (o papel foi dobrado em quatro): sulco escuro + brilho ao lado
function crease(u, v) {
  let dark = 0, light = 0;
  for (const [d, wob] of [[u - CARD_W * 0.5, v], [v - CARD_H * 0.47, u]]) {
    const dd = d + (fbm(wob * 6, 3, 71) - 0.5) * 0.01;
    const k = 0.5 + fbm(wob * 4, 9, 73) * 0.7;
    dark = Math.max(dark, (1 - smooth(0.0, 0.004, Math.abs(dd))) * 0.35 * k);
    light = Math.max(light, (1 - smooth(0.004, 0.012, Math.abs(dd - 0.007))) * 0.18 * k);
  }
  return [dark, light];
}

// Cor do pergaminho num ponto (u, v em tamanhos de mapa)
function paper(u, v) {
  const m = smooth(0.2, 0.8, fbm(u * 5, v * 5, 3));
  let c = mix(PAPER_HI, PAPER_LO, m * 0.85);
  const stain = smooth(0.55, 0.8, fbm(u * 2.2 + 7, v * 2.2, 11));
  c = mix(c, STAIN, stain * 0.45);
  c = mix(c, STAIN, waterStain(u, v));
  c = mix(c, FOX, foxing(u, v));
  const [cd, cl] = crease(u, v);
  c = mix(c, EDGE, cd);
  c = mix(c, PAPER_HI, cl);
  // fibras e grão
  const fiber = smooth(0.6, 0.9, fbm(u * 60, v * 9, 81)) * 0.05;
  const grain = (hash(Math.floor(u * 420), Math.floor(v * 420), 5) - 0.5) * 0.07 - fiber;
  return [c[0] + grain, c[1] + grain, c[2] + grain];
}

// Tinta desbotada em manchas (o traço some e volta como nas cartas antigas)
const inkFade = (u, v) => 0.6 + 0.4 * smooth(0.3, 0.7, fbm(u * 7, v * 7, 91));

// Distância a uma linha de rumo (feixe de n raios a partir de cx, cy)
function rhumb(u, v, cx, cy, n) {
  const dx = u - cx, dy = v - cy, r = Math.hypot(dx, dy);
  const step = (Math.PI * 2) / n;
  const th = Math.atan2(dx, -dy);
  const idx = Math.round(th / step);
  return { d: r * Math.abs(Math.sin(th - idx * step)), idx: ((idx % n) + n) % n, r };
}

// ---- cartão ----
const CW = 512, CH = 512;
writeTGA("PortolanCard.tga", CW, CH, (px, py) => {
  const u = (px / CW) * CARD_W, v = (py / CH) * CARD_H;
  const e = Math.min(u, CARD_W - u, v, CARD_H - v);
  // borda roída: ondulação larga + franjas finas + alguns rasgos em "V"
  let en = e - fbm(u * 9, v * 9, 21) * 0.03 - fbm(u * 40, v * 40, 23) * 0.012;
  const along = (u < 0.06 || u > CARD_W - 0.06) ? v : u;
  const nick = Math.max(0, 1 - Math.abs(((along * 4.3 + hash(Math.floor(along * 4.3), 7, 25)) % 1) - 0.5) / 0.13);
  if (hash(Math.floor(along * 4.3), u < 0.06 ? 1 : u > CARD_W - 0.06 ? 2 : v < 0.1 ? 3 : 4, 27) < 0.35) en -= nick * nick * 0.028;
  const alpha = smooth(0.003, 0.01, en);
  if (alpha <= 0) return [0, 0, 0, 0];

  let c = paper(u, v);
  // vinheta amarelada e borda queimada/encardida
  c = mix(c, STAIN, (1 - smooth(0, 0.28, e)) * 0.5);
  c = mix(c, EDGE, (1 - smooth(0.004, 0.06, en)) * 0.85);

  // Rede de rumos de portulano: rosa central oculta (o próprio mapa) cercada
  // por 16 nós num círculo, cada um irradiando 16 rumos; mais o feixe da rosa.
  const mapDist = Math.hypot(u - MAP_CX, v - MAP_CY);
  const inText = u < 0.95 && v > 1.27 && v < 1.53;
  const fade = (inText ? 0.2 : 1) * inkFade(u, v);
  const inside = e > 0.05 && mapDist > 0.50; // não desenha linhas de rumo dentro da área circular do minimapa
  const stroke = (d, w) => 1 - smooth(w * 0.5, w * 1.5, d);
  if (inside) {
    let best = 0, bestCol = INK;
    const put = (a, col) => { if (a > best) { best = a; bestCol = col; } };
    const a = rhumb(u, v, MAP_CX, MAP_CY, 32);
    if (a.r > 0.55) {
      const kind = a.idx % 4 === 0 ? 0 : a.idx % 2 === 0 ? 1 : 2;
      put(stroke(a.d, kind === 0 ? 0.0034 : 0.0026) * (kind === 0 ? 0.6 : 0.5),
          kind === 0 ? INK : kind === 1 ? GREEN : RED);
    }
    for (let k = 0; k < 16; k++) {
      const ang = (k * Math.PI) / 8;
      const nx = MAP_CX + Math.sin(ang) * 0.86, ny = MAP_CY - Math.cos(ang) * 0.86;
      const n = rhumb(u, v, nx, ny, 16);
      const j = n.idx * 2;
      const kind = j % 4 === 0 ? 0 : 1;
      put(stroke(n.d, 0.0024) * 0.32, kind === 0 ? INK : (k % 2 ? RED : GREEN));
      // marquinha do nó
      put((1 - smooth(0.006, 0.01, n.r)) * 0.7, INK);
    }
    const b = rhumb(u, v, ROSE_CX, ROSE_CY, 16);
    if (b.r > 0.12) {
      const kind = (b.idx * 2) % 4 === 0 ? 0 : 1;
      put(stroke(b.d, kind === 0 ? 0.0034 : 0.0026) * 0.45, kind === 0 ? INK : GREEN);
    }
    c = mix(c, bestCol, best * fade);
  }

  // filete duplo (tinta desbotada)
  const line = (d, w) => 1 - smooth(w * 0.5, w * 1.5, Math.abs(d));
  const f2 = inkFade(u, v);
  c = mix(c, INK, line(e - 0.042, 0.0045) * 0.85 * f2);
  c = mix(c, INK, line(e - 0.052, 0.0022) * 0.6 * f2);

  // régua sob o nome da zona
  if (u > RULE_X0 && u < RULE_X1) {
    const t = smooth(RULE_X0, RULE_X0 + 0.05, u) * (1 - smooth(RULE_X1 - 0.05, RULE_X1, u));
    c = mix(c, INK, line(v - RULE_Y, 0.003) * 0.75 * t);
  }
  return [c[0], c[1], c[2], alpha];
});

// ---- anel graduado ----
const RS = 512;
writeTGA("PortolanRing.tga", RS, RS, (px, py) => {
  const dx = px - RS / 2, dy = py - RS / 2;
  const r = (Math.hypot(dx, dy) / (RS / 2)) * RING_R; // em tamanhos de mapa
  const u = (dx / (RS / 2)) * RING_R + MAP_CX, v = (dy / (RS / 2)) * RING_R + MAP_CY;
  const line = (d, w) => 1 - smooth(w * 0.5, w * 1.5, Math.abs(d));

  if (r < 0.497) {
    // sombra interna sobre a borda do mapa
    const s = smooth(0.455, 0.497, r);
    return [INK[0], INK[1], INK[2], s * s * 0.45];
  }
  if (r > 0.588) {
    // sombra do anel sobre o cartão
    const s = 1 - smooth(0.588, 0.61, r);
    return [EDGE[0], EDGE[1], EDGE[2], s * 0.3];
  }
  let c = paper(u, v);
  c = mix(c, STAIN, smooth(0.52, 0.5, r) * 0.25);
  // graduação
  const th = Math.atan2(dx, -dy);
  const step = Math.PI / 36; // 5°
  const idx = Math.round(th / step);
  const k = ((idx % 72) + 72) % 72;
  const len = k % 6 === 0 ? 0.064 : k % 2 === 0 ? 0.036 : 0.02;
  const w = k % 6 === 0 ? 0.0042 : 0.0028;
  if (r < 0.504 + len) {
    const d = r * Math.abs(Math.sin(th - idx * step));
    c = mix(c, INK, (1 - smooth(w * 0.5, w * 1.5, d)) * 0.9);
  }
  // losangos nos pontos colaterais
  if (k % 9 === 0 && k % 18 !== 0) {
    const along = Math.abs(r - 0.578), across = r * Math.abs(Math.sin(th - idx * step));
    if (along / 0.008 + across / 0.006 < 1) c = mix(c, RED, 0.85);
  }
  // filetes
  c = mix(c, INK, line(r - 0.5, 0.0075));
  c = mix(c, INK, line(r - 0.568, 0.0042));
  c = mix(c, INK, line(r - 0.584, 0.0025) * 0.8);
  const a = 1 - smooth(0.584, 0.589, r);
  return [c[0], c[1], c[2], Math.max(a, 0)];
});

// ---- rosa dos ventos ----
// Envelhece cores chapadas (rosa, lírio) com manchas do mesmo papel
const aged = (col, x, y) => mix(col, STAIN, smooth(0.35, 0.75, fbm(x * 0.06, y * 0.06, 101)) * 0.3);

function triPoint(cx, cy, ang, len, w) {
  const dx = Math.sin(ang), dy = -Math.cos(ang), px = Math.cos(ang), py = Math.sin(ang);
  const tip = [cx + dx * len, cy + dy * len];
  return [
    [[cx, cy], tip, [cx + px * w, cy + py * w]],  // metade esquerda (escura)
    [[cx, cy], tip, [cx - px * w, cy - py * w]],  // metade direita (clara)
  ];
}
function inTri(p, t) {
  const s = (a, b, c) => (a[0] - c[0]) * (b[1] - c[1]) - (b[0] - c[0]) * (a[1] - c[1]);
  const d1 = s(p, t[0], t[1]), d2 = s(p, t[1], t[2]), d3 = s(p, t[2], t[0]);
  const neg = d1 < 0 || d2 < 0 || d3 < 0, pos = d1 > 0 || d2 > 0 || d3 > 0;
  return !(neg && pos);
}
function segDist(p, a, b) {
  const vx = b[0] - a[0], vy = b[1] - a[1];
  const t = clamp01(((p[0] - a[0]) * vx + (p[1] - a[1]) * vy) / (vx * vx + vy * vy || 1));
  return Math.hypot(p[0] - a[0] - vx * t, p[1] - a[1] - vy * t);
}
function polyEdgeDist(p, poly) {
  let d = Infinity;
  for (let i = 0; i < poly.length; i++) d = Math.min(d, segDist(p, poly[i], poly[(i + 1) % poly.length]));
  return d;
}

const RO = 256, RC = RO / 2, RR = 120;
const roseShapes = []; // ordem de pintura: de trás para frente
for (let i = 1; i < 16; i += 2) {
  const [l, r] = triPoint(RC, RC, (i * Math.PI) / 8, RR * 0.56, RR * 0.065);
  roseShapes.push({ t: l, c: MINOR }, { t: r, c: LIGHT });
}
for (let i = 2; i < 16; i += 4) {
  const [l, r] = triPoint(RC, RC, (i * Math.PI) / 8, RR * 0.76, RR * 0.1);
  roseShapes.push({ t: l, c: INTER }, { t: r, c: LIGHT });
}
for (let i = 0; i < 16; i += 4) {
  const [l, r] = triPoint(RC, RC, (i * Math.PI) / 8, RR, RR * 0.13);
  roseShapes.push({ t: l, c: i === 0 ? RED : INK }, { t: r, c: LIGHT });
}
writeTGA("PortolanRose.tga", RO, RO, (x, y) => {
  const p = [x, y];
  const r = Math.hypot(x - RC, y - RC);
  // miolo
  if (r < RR * 0.12) {
    if (r < RR * 0.05) return [...INK, 1];
    const edge = 1 - smooth(RR * 0.12 - 2.2, RR * 0.12 - 0.8, r);
    const col = mix(INK, LIGHT, edge);
    return [...col, 1];
  }
  for (let i = roseShapes.length - 1; i >= 0; i--) {
    const s = roseShapes[i];
    if (inTri(p, s.t)) {
      const d = polyEdgeDist(p, s.t);
      const col = d < 0.9 ? INK : s.c;
      return [...aged(col, x, y), 1];
    }
  }
  // círculos atrás das pontas
  const c1 = 1 - smooth(0.6, 1.4, Math.abs(r - RR * 0.42));
  const c2 = 1 - smooth(0.4, 1.0, Math.abs(r - RR * 0.47));
  const a = Math.max(c1, c2 * 0.7);
  return a > 0 ? [...INK, a] : [0, 0, 0, 0];
}, 4);

// ---- lírio do norte ----
function cubic(p0, p1, p2, p3, n = 16) {
  const pts = [];
  for (let i = 1; i <= n; i++) {
    const t = i / n, m = 1 - t;
    pts.push([
      m * m * m * p0[0] + 3 * m * m * t * p1[0] + 3 * m * t * t * p2[0] + t * t * t * p3[0],
      m * m * m * p0[1] + 3 * m * m * t * p1[1] + 3 * m * t * t * p2[1] + t * t * t * p3[1],
    ]);
  }
  return pts;
}
function pathPoly(start, segs) {
  let pts = [start], cur = start;
  for (const s of segs) {
    if (s.length === 1) { pts.push(s[0]); cur = s[0]; }
    else { pts = pts.concat(cubic(cur, s[0], s[1], s[2])); cur = s[2]; }
  }
  return pts;
}
function inPoly(p, poly) {
  let inside = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const a = poly[i], b = poly[j];
    if ((a[1] > p[1]) !== (b[1] > p[1]) && p[0] < ((b[0] - a[0]) * (p[1] - a[1])) / (b[1] - a[1]) + a[0]) inside = !inside;
  }
  return inside;
}
// desenho em unidades do conceito (x -13..13, y -15..7)
const fleur = [
  pathPoly([0, -15], [[[5, -9], [5, -4], [0, 1]], [[-5, -4], [-5, -9], [0, -15]]]),
  pathPoly([1, -3], [[[6, -11], [13, -7], [10, -1]], [[9, -4], [5, -4], [2, 1]]]),
  pathPoly([-1, -3], [[[-6, -11], [-13, -7], [-10, -1]], [[-9, -4], [-5, -4], [-2, 1]]]),
  [[-6, 0], [6, 0], [6, 2.6], [-6, 2.6]],
  [[0, 2.6], [2.6, 7.5], [-2.6, 7.5]],
];
const FS = 128, FSC = 3.9; // 1 unidade = 3.9 px
writeTGA("PortolanFleur.tga", FS, FS, (x, y) => {
  const p = [(x - FS / 2) / FSC, (y - FS / 2) / FSC - 4];
  const ink = 1.5 / FSC;
  for (let i = fleur.length - 1; i >= 0; i--) {
    if (inPoly(p, fleur[i])) {
      const d = polyEdgeDist(p, fleur[i]);
      const hl = clamp01(0.5 - p[1] / 30) * 0.25;
      return [...(d < ink ? INK : aged(mix(RED, LIGHT, hl), x * 2, y * 2)), 1];
    }
  }
  // contorno por fora (engrossa a silhueta para ler em tamanho pequeno)
  let d = Infinity;
  for (const poly of fleur) d = Math.min(d, polyEdgeDist(p, poly));
  const a = 1 - smooth(ink * 0.4, ink * 0.9, d);
  return a > 0 ? [...INK, a] : [0, 0, 0, 0];
}, 4);

// ---- Vinheta Suave estilo Guild Wars 2 (MinimapVignette.tga) ----
// 512x512 TGA 32 bits:
// - Centro transparente para o minimapa
// - Vinheta painterly (aquarela/pincelada) nas 4 bordas (e < 0.12)
// - Gradiente inferior suave (v > 0.74) para zona, coordenadas e relógio
// - Filete de 1px em ouro velho acetinado com contorno escuro
const VS = 512;
writeTGA("MinimapVignette.tga", VS, VS, (px, py) => {
  const u = px / VS, v = py / VS;
  const eu = Math.min(u, 1 - u), ev = Math.min(v, 1 - v);
  const e = Math.min(eu, ev);

  const DARK = [14 / 255, 17 / 255, 23 / 255]; // #0e1117 carvão escuro
  const GOLD = [197 / 255, 155 / 255, 39 / 255]; // #c59b27 ouro velho

  // Ruído orgânico de aquarela/pincelada na borda
  const noise = (fbm(u * 18, v * 18, 55) - 0.5) * 0.025;
  const en = Math.max(0, e + noise);

  // 1. Vinheta suave nas 4 bordas
  const edgeAlpha = (1 - smooth(0.01, 0.12, en)) * 0.70;

  // 2. Gradiente inferior para legibilidade de textos
  const bottomGradient = smooth(0.74, 0.92, v) * 0.82;

  let alpha = Math.max(edgeAlpha, bottomGradient);
  let color = DARK;

  // 3. Filete duplo sutil de 1px em ouro velho na borda extrema
  const lineDist = Math.abs(e - 0.014);
  const goldStroke = 1 - smooth(0.001, 0.004, lineDist);
  if (goldStroke > 0) {
    color = mix(color, GOLD, goldStroke * 0.75);
    alpha = Math.max(alpha, goldStroke * 0.85);
  }

  // 4. Borda externa preta cortante no perímetro
  if (e < 0.006) {
    const blackEdge = 1 - smooth(0.001, 0.006, e);
    color = mix(color, [0, 0, 0], blackEdge);
    alpha = Math.max(alpha, blackEdge * 0.95);
  }

  return [color[0], color[1], color[2], Math.min(1, alpha)];
}, 2);

// Copia também para PortolanCard.tga para garantir que clientes WoW já em execução
// recarreguem a nova vinheta instantaneamente via /reload (o arquivo já estava indexado)
fs.copyFileSync(path.join(OUT, "MinimapVignette.tga"), path.join(OUT, "PortolanCard.tga"));
if (fs.existsSync(GAME_OUT)) {
  fs.copyFileSync(path.join(OUT, "MinimapVignette.tga"), path.join(GAME_OUT, "PortolanCard.tga"));
}
console.log("copiado para PortolanCard.tga (suporte a /reload em tempo real)");

