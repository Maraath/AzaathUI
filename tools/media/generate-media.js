// Gera as texturas do AzaathUI (TGA 32 bits, 256x256, branco + alpha).
// Brancas de propósito: a cor é aplicada no jogo com SetVertexColor.
// Uso: node tools/media/generate-media.js
const fs = require("fs");
const path = require("path");

const SIZE = 256;
const C = SIZE / 2;
const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media");

const clamp01 = (v) => Math.max(0, Math.min(1, v));
// Faixa anelar com bordas suavizadas (anti-aliasing de ~1px)
const band = (r, inner, outer) => clamp01(0.5 + Math.min(r - inner, outer - r));

function writeTGA(file, alphaAt) {
  const header = Buffer.alloc(18);
  header[2] = 2;                 // true-color, sem compressão
  header.writeUInt16LE(SIZE, 12);
  header.writeUInt16LE(SIZE, 14);
  header[16] = 32;               // BGRA
  header[17] = 8;                // 8 bits de alpha, origem inferior esquerda
  const data = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const dx = x + 0.5 - C, dy = y + 0.5 - C;
      const a = clamp01(alphaAt(Math.sqrt(dx * dx + dy * dy)));
      const i = (y * SIZE + x) * 4;
      data[i] = 255; data[i + 1] = 255; data[i + 2] = 255;
      data[i + 3] = Math.round(a * 255);
    }
  }
  fs.writeFileSync(path.join(OUT, file), Buffer.concat([header, data]));
  console.log("gerado", file);
}

fs.mkdirSync(OUT, { recursive: true });

// Anel: faixa principal (fora da borda do mapa) + filete interno mais fraco.
// No jogo o anel é desenhado com 1.06x o tamanho do mapa: a borda do mapa cai em r≈121.
writeTGA("Ring.tga", (r) => Math.max(
  band(r, 121, 125.5),
  band(r, 116.3, 117.3) * 0.55,
));

// Halo: disco opaco que esmaece nas bordas (sombra atrás do mapa / fundo do "N").
writeTGA("Glow.tga", (r) => (r <= 100 ? 1 : clamp01((128 - r) / 28)) ** 1.6);

// Losango (selo de nível): preenchido, bordas suavizadas. Usa a distância
// "Manhattan" do pixel ao centro, então ignora o raio r recebido.
function writeDiamond(file, inset) {
  const header = Buffer.alloc(18);
  header[2] = 2; header.writeUInt16LE(SIZE, 12); header.writeUInt16LE(SIZE, 14);
  header[16] = 32; header[17] = 8;
  const data = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const d = Math.abs(x + 0.5 - C) + Math.abs(y + 0.5 - C);
      const a = clamp01((C - inset) - d + 0.5);
      const i = (y * SIZE + x) * 4;
      data[i] = 255; data[i + 1] = 255; data[i + 2] = 255; data[i + 3] = Math.round(a * 255);
    }
  }
  fs.writeFileSync(path.join(OUT, file), Buffer.concat([header, data]));
  console.log("gerado", file);
}
writeDiamond("Diamond.tga", 2);

// --- Conjuração em espiral (Modules/CastBar.lua) ---------------------------
// CastRing: faixa larga do anel (trilho escuro, preenchimento via swipe do
// Cooldown e anel cheio no fim). O meio da faixa fica em r=110 (0.859 do raio):
// o brilho da ponta usa essa medida.
writeTGA("CastRing.tga", (r) => band(r, 100, 120));
// CastRingEdge: dois filetes dourados finos (borda interna e externa do anel).
writeTGA("CastRingEdge.tga", (r) => Math.max(band(r, 96.5, 99), band(r, 121, 123.5)));
// Disc: disco cheio para máscara do ícone central.
writeTGA("Disc.tga", (r) => clamp01(126 - r));

// --- Anel moderno da interação com objetos (castbar.world) -------------------
// Linha fina (meio da faixa em r=112, 0.875 do raio) e um halo suave em volta
// dela para o brilho do arco cheio.
writeTGA("CastRingThin.tga", (r) => band(r, 105, 119));
writeTGA("CastRingHalo.tga", (r) => Math.exp(-(((r - 112) / 9) ** 2)));

// --- Efeitos da conjuração por escola (CastBar: FX) --------------------------
// Variante do writeTGA que recebe a posição (dx, dy) além do raio.
function writeTGAxy(file, alphaAt) {
  const header = Buffer.alloc(18);
  header[2] = 2; header.writeUInt16LE(SIZE, 12); header.writeUInt16LE(SIZE, 14);
  header[16] = 32; header[17] = 8;
  const data = Buffer.alloc(SIZE * SIZE * 4);
  for (let y = 0; y < SIZE; y++) {
    for (let x = 0; x < SIZE; x++) {
      const dx = x + 0.5 - C, dy = y + 0.5 - C;
      const a = clamp01(alphaAt(dx, dy, Math.sqrt(dx * dx + dy * dy)));
      const i = (y * SIZE + x) * 4;
      data[i] = 255; data[i + 1] = 255; data[i + 2] = 255; data[i + 3] = Math.round(a * 255);
    }
  }
  fs.writeFileSync(path.join(OUT, file), Buffer.concat([header, data]));
  console.log("gerado", file);
}

// Rays: leque de 16 raios de luz (alternando largos/finos), esmaece para fora
// e some no centro (o miolo fica por conta do brilho). Gira no jogo (SetRotation).
writeTGAxy("Rays.tga", (dx, dy, r) => {
  const t = Math.atan2(dy, dx);
  const wide = Math.pow(Math.max(0, Math.cos(t * 8)), 6);        // 8 raios largos
  const thin = Math.pow(Math.max(0, Math.cos(t * 8 + Math.PI)), 40) * 0.7; // 8 finos entre eles
  const radial = clamp01((128 - r) / 70) ** 1.4 * clamp01((r - 18) / 30);
  return Math.max(wide, thin) * radial;
});

// Star: brilho de 4 pontas (faísca de luz/gelo/arcano).
writeTGAxy("Star.tga", (dx, dy, r) => {
  const ax = Math.abs(dx) / 128, ay = Math.abs(dy) / 128;
  const cross = Math.max(
    Math.exp(-ay * 60) * clamp01(1 - ax * 1.05),
    Math.exp(-ax * 60) * clamp01(1 - ay * 1.05),
  );
  const core = Math.exp(-((r / 22) ** 2));
  return Math.max(cross ** 1.2, core);
});
