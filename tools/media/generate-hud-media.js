// Gera as texturas da HUD central do jogador no estilo Azaath
// (Media/UnitFrames/Hud*.tga, TGA 32 bits), a partir da captura de referência
// (barra de recurso + vida no centro inferior, entre as barras de ação):
//   HudFill.tga   - preenchimento em tons de cinza (claro em cima, mais escuro
//                   embaixo, com pinceladas horizontais suaves). O jogo tinge
//                   com SetVertexColor: branco = vida cheia, vermelho = dano,
//                   vermelho vivo / azul-marinho / amarelo = raiva / mana / energia.
//   HudEmpty.tga  - parte vazia da barra: quase preta com leve degradê.
//   HudDiamond.tga - losango do nível (abaixo da HUD, junto da XP).
//   HudXPTab.tga  - aba trapezoidal sob a linha de XP que segura o losango.
// Uso: node tools/media/generate-hud-media.js
const fs = require("fs");
const path = require("path");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "UnitFrames");
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

// fn(x, y) -> [r, g, b, a] com r/g/b em 0..255 e a em 0..1 (y = 0 no topo)
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
  console.log("gerado UnitFrames/" + file);
}

// Visual "clean": cores lisas, degradês suaves, sem ruído nem pinceladas.

// Aba sob a linha de XP onde fica o losango do nível: trapézio escuro
// (largo em cima, estreito embaixo) com filete cinza nas laterais e na base
{
  const W = 128, H = 32, ss = 4;
  const topHalf = 60, botHalf = 30, cx = (W - 1) / 2;
  writeTGA("HudXPTab.tga", W, H, (x, y) => {
    let fill = 0, line = 0;
    for (let j = 0; j < ss; j++) {
      for (let i = 0; i < ss; i++) {
        const px = x + (i + 0.5) / ss - 0.5, py = y + (j + 0.5) / ss - 0.5;
        const t = py / (H - 1);
        const half = lerp(topHalf, botHalf, t);
        const dx = Math.abs(px - cx);
        if (dx <= half && py <= H - 1) {
          fill++;
          // distância até a lateral inclinada e até a base
          const slope = (topHalf - botHalf) / (H - 1);
          const dSide = (half - dx) / Math.sqrt(1 + slope * slope);
          const dBot = H - 1 - py;
          if (Math.min(dSide, dBot) < 1.2 && py > 0.5) line++;
        }
      }
    }
    const n = ss * ss;
    fill /= n; line /= n;
    const v = lerp(14, 150, line);
    return [v, v + 1, v + 3, Math.max(fill * 0.82, line * 0.9)];
  });
}

// Preenchimento em cinza: realce de 1 px no topo, degradê suave, base levemente
// mais escura. Tingido no jogo (branco = vida cheia).
{
  const W = 8, H = 64;
  writeTGA("HudFill.tga", W, H, (x, y) => {
    const t = y / (H - 1);
    let v = lerp(246, 214, smooth(0, 1, t));
    if (y <= 1) v = 255;
    if (y >= H - 3) v = 190;
    return [v, v, v, 1];
  });
}

// Parte vazia: cinza-chumbo liso
{
  const W = 8, H = 32;
  writeTGA("HudEmpty.tga", W, H, (x, y) => {
    const v = lerp(30, 38, y / (H - 1));
    return [v, v, v + 2, 0.85];
  });
}

// Losango do nível: miolo escuro, aro claro de 2 px e filete interno fino
{
  const S = 64, ss = 4, c = (S - 1) / 2;
  writeTGA("HudDiamond.tga", S, S, (x, y) => {
    let fill = 0, ring = 0, inner = 0;
    for (let j = 0; j < ss; j++) {
      for (let i = 0; i < ss; i++) {
        const px = x + (i + 0.5) / ss - 0.5, py = y + (j + 0.5) / ss - 0.5;
        const d = (Math.abs(px - c) + Math.abs(py - c)) / Math.SQRT2; // distância "losango"
        const R = 21.5;
        if (d <= R) fill++;
        if (d <= R && d > R - 2.2) ring++;
        if (d <= R - 4.5 && d > R - 5.5) inner++;
      }
    }
    const n = ss * ss;
    fill /= n; ring /= n; inner /= n;
    let r = 12, g = 13, b = 16, a = fill * 0.9;
    const mix = (v, t, k) => v + (t - v) * k;
    r = mix(r, 205, ring); g = mix(g, 206, ring); b = mix(b, 208, ring);
    r = mix(r, 120, inner * 0.8); g = mix(g, 122, inner * 0.8); b = mix(b, 126, inner * 0.8);
    a = Math.max(a, ring);
    return [r, g, b, a];
  });
}

// Ponta afunilada da linha de XP (lado esquerdo; o direito usa TexCoord
// espelhado): cunha escura de metal com filete claro, apontando para fora
{
  const W = 32, H = 16, ss = 4;
  writeTGA("HudXPCap.tga", W, H, (x, y) => {
    let fill = 0, line = 0;
    const cy = (H - 1) / 2;
    for (let j = 0; j < ss; j++) {
      for (let i = 0; i < ss; i++) {
        const px = x + (i + 0.5) / ss - 0.5, py = y + (j + 0.5) / ss - 0.5;
        // meia-altura cresce da ponta (x = 0) até a base (x = W - 1)
        const half = cy * clamp01(px / (W - 1));
        const d = half - Math.abs(py - cy);
        if (d >= 0) {
          fill++;
          if (d < 1.1) line++;
        }
      }
    }
    const n = ss * ss;
    fill /= n; line /= n;
    const v = lerp(16, 120, line);
    return [v, v + 1, v + 3, Math.max(fill * 0.95, line)];
  });
}

// Seta dourada para cima (bônus de XP descansada ao lado do texto)
{
  const S = 32, ss = 4;
  writeTGA("HudArrow.tga", S, S, (x, y) => {
    let a = 0;
    for (let j = 0; j < ss; j++) {
      for (let i = 0; i < ss; i++) {
        const px = x + (i + 0.5) / ss, py = y + (j + 0.5) / ss;
        const head = py >= 3 && py <= 17 && Math.abs(px - 16) <= (py - 3) * 0.95;
        const stem = py > 16 && py <= 29 && Math.abs(px - 16) <= 4;
        if (head || stem) a++;
      }
    }
    a /= ss * ss;
    const t = y / (S - 1);
    return [lerp(255, 222, t), lerp(214, 150, t), lerp(110, 40, t), a];
  });
}
