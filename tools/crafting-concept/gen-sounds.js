// Sons de criação da aba Ofícios (Mesa do Artesão), sintetizados do zero.
//
//   CraftFood.ogg     comidas: chiado de frigideira + estalos de fogo
//   CraftArmor.ogg    armaduras: batidas em couro + tilintar de cota de malha
//   CraftWeapon.ogg   armas: duas marteladas na bigorna + chiado da têmpera
//   CraftPotion.ogg   poções: bolhas subindo no frasco + tinido de vidro
//   CraftBandage.ogg  curativos: tecido rasgando
//   CraftGeneric.ogg  demais ofícios: brilho arcano curto
//   CraftUnitEpic.ogg unidade pronta com a fila ainda andando: estocada coral
//                     curta (~1,2 s) com tambor e sinos, irmã menor do CraftDone
//   CraftDone.ogg     receita concluída: fanfarra coral curta no estilo dos
//                     Talentos (prato invertido, tambor, "AH" Si bemol -> Ré
//                     maior, sinos subindo), usando as peças de
//                     tools/talents-concept/gen-sounds.js
//
// Uso: node tools/crafting-concept/gen-sounds.js   (precisa do ffmpeg no PATH)

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const SR = 44100;
const OUT_WS = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Sounds", "Crafting");
const OUT_GAME = "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Sounds/Crafting";
const TMP = path.join(__dirname, "preview");
for (const d of [OUT_WS, TMP]) fs.mkdirSync(d, { recursive: true });
let gameOk = true;
try { fs.mkdirSync(OUT_GAME, { recursive: true }); } catch (e) { gameOk = false; }

let seed = 777;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const TAU = Math.PI * 2;

function buf(sec) { const n = Math.ceil(sec * SR); return { n, L: new Float32Array(n), R: new Float32Array(n) }; }
function add(b, i, v, pan = 0) {
  if (i < 0 || i >= b.n) return;
  b.L[i] += v * Math.min(1, 1 - pan); b.R[i] += v * Math.min(1, 1 + pan);
}

// filtro passa-banda (biquad RBJ) com estado próprio
function bandpass(f, q) {
  const w = TAU * f / SR, al = Math.sin(w) / (2 * q), c = Math.cos(w), a0 = 1 + al;
  const b0 = al / a0, b2 = -al / a0, a1 = -2 * c / a0, a2 = (1 - al) / a0;
  let x1 = 0, x2 = 0, y1 = 0, y2 = 0;
  return (x) => { const y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2; x2 = x1; x1 = x; y2 = y1; y1 = y; return y; };
}
function lowpass(f) { let y = 0; const a = 1 - Math.exp(-TAU * f / SR); return (x) => (y += a * (x - y)); }

// sino/metal: modos inarmônicos com decaimento
function metal(b, t0, f0, amp, ratios, decay, pan = 0) {
  const i0 = Math.floor(t0 * SR);
  ratios.forEach(([r, g, d], k) => {
    const f = f0 * r, dd = decay * d, ph = rnd() * TAU, n = Math.floor(Math.min(dd * 6, 4) * SR);
    for (let i = 0; i < n; i++) {
      const t = i / SR, att = Math.min(1, t / 0.0015);
      add(b, i0 + i, amp * g * att * Math.exp(-t / dd) * Math.sin(TAU * f * t + ph), pan * (k % 2 ? 1 : -1));
    }
  });
}
// rajada de ruído filtrado
function noiseBurst(b, t0, dur, amp, f, q, env, pan = 0) {
  const bp = bandpass(f, q), i0 = Math.floor(t0 * SR), n = Math.floor(dur * SR);
  for (let i = 0; i < n; i++) add(b, i0 + i, amp * env(i / n) * bp(rnd() * 2 - 1), pan);
}
// reverb curto (combs + allpass) para dar ambiente de oficina
function room(b, wet = 0.22, size = 1) {
  const combs = [1116, 1188, 1277, 1356].map((d) => Math.floor(d * size));
  for (const ch of ["L", "R"]) {
    const x = b[ch], y = new Float32Array(b.n);
    combs.forEach((d, k) => {
      const line = new Float32Array(d + (ch === "R" ? 23 : 0)); let p = 0, lp = 0;
      for (let i = 0; i < b.n; i++) {
        const o = line[p]; lp = o * 0.7 + lp * 0.3; line[p] = x[i] + lp * 0.8; p = (p + 1) % line.length; y[i] += o / combs.length;
      }
    });
    for (let i = 0; i < b.n; i++) x[i] += y[i] * wet;
  }
}

function finish(b, name, peak = 0.8) {
  let m = 0;
  for (let i = 0; i < b.n; i++) m = Math.max(m, Math.abs(b.L[i]), Math.abs(b.R[i]));
  const g = peak / (m || 1), fade = Math.floor(0.03 * SR);
  const data = Buffer.alloc(44 + b.n * 4);
  data.write("RIFF", 0); data.writeUInt32LE(36 + b.n * 4, 4); data.write("WAVEfmt ", 8);
  data.writeUInt32LE(16, 16); data.writeUInt16LE(1, 20); data.writeUInt16LE(2, 22);
  data.writeUInt32LE(SR, 24); data.writeUInt32LE(SR * 4, 28); data.writeUInt16LE(4, 32); data.writeUInt16LE(16, 34);
  data.write("data", 36); data.writeUInt32LE(b.n * 4, 40);
  for (let i = 0; i < b.n; i++) {
    const f = i > b.n - fade ? (b.n - i) / fade : 1;
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, b.L[i] * g * f)) * 32767), 44 + i * 4);
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, b.R[i] * g * f)) * 32767), 46 + i * 4);
  }
  const wav = path.join(TMP, name + ".wav"), ogg = path.join(OUT_WS, name + ".ogg");
  fs.writeFileSync(wav, data);
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", ogg]);
  if (gameOk) { try { fs.copyFileSync(ogg, path.join(OUT_GAME, name + ".ogg")); } catch (e) { gameOk = false; } }
  console.log(name, (b.n / SR).toFixed(2) + "s");
}

// --- Comidas: frigideira -------------------------------------------------------
{
  const b = buf(2.2), hi = bandpass(5200, 0.7), mid = bandpass(2400, 0.9), rum = lowpass(180);
  for (let i = 0; i < b.n; i++) {
    const t = i / SR, env = Math.min(1, t / 0.25) * Math.min(1, (2.2 - t) / 0.6);
    const flick = 0.6 + 0.4 * Math.sin(TAU * 3.1 * t) * Math.sin(TAU * 0.7 * t + 1);
    const n = rnd() * 2 - 1;
    add(b, i, env * (0.5 * hi(n) * flick + 0.25 * mid(n) + 0.5 * rum(rnd() * 2 - 1)), Math.sin(t * 2) * 0.3);
  }
  for (let k = 0; k < 38; k++) { // estalos de gordura e brasa
    const t0 = 0.1 + rnd() * 1.9, a = 0.25 + rnd() * 0.5;
    noiseBurst(b, t0, 0.004 + rnd() * 0.01, a, 1800 + rnd() * 4000, 2, (x) => (1 - x) * (1 - x), rnd() * 1.4 - 0.7);
  }
  room(b, 0.12); finish(b, "CraftFood", 0.7);
}

// --- Armaduras: couro + cota de malha --------------------------------------------
{
  const b = buf(1.7);
  for (const t0 of [0.02, 0.42]) { // batidas abafadas no couro
    const lp = lowpass(260), i0 = Math.floor(t0 * SR);
    for (let i = 0; i < 0.22 * SR; i++) {
      const t = i / SR; add(b, i0 + i, 1.4 * Math.exp(-t / 0.05) * (lp(rnd() * 2 - 1) * 2 + 0.6 * Math.sin(TAU * (95 - 160 * t) * t)));
    }
  }
  for (let k = 0; k < 70; k++) { // elos tilintando
    const t0 = 0.7 + Math.pow(rnd(), 1.6) * 0.75, f = 2600 + rnd() * 3800;
    metal(b, t0, f, 0.05 + rnd() * 0.06, [[1, 1, 1], [1.47, 0.5, 0.7], [2.09, 0.3, 0.5]], 0.025 + rnd() * 0.03, rnd() - 0.5);
  }
  room(b, 0.2); finish(b, "CraftArmor", 0.75);
}

// --- Armas: bigorna + têmpera -----------------------------------------------------
{
  const b = buf(2.6);
  const anvil = [[1, 1, 1], [2.76, 0.6, 0.7], [5.4, 0.4, 0.45], [8.93, 0.25, 0.3], [13.3, 0.12, 0.2]];
  metal(b, 0.02, 520, 0.5, anvil, 0.35, 0.1);
  metal(b, 0.5, 528, 0.42, anvil, 0.3, -0.1);
  for (const t0 of [0.02, 0.5]) noiseBurst(b, t0, 0.02, 0.8, 3000, 1, (x) => 1 - x);
  noiseBurst(b, 1.0, 1.5, 0.55, 4200, 0.6, (x) => Math.min(1, x * 12) * Math.pow(1 - x, 1.5)); // água fervendo
  noiseBurst(b, 1.0, 1.2, 0.3, 900, 0.8, (x) => Math.min(1, x * 8) * (1 - x));
  room(b, 0.3, 1.2); finish(b, "CraftWeapon", 0.8);
}

// --- Poções: bolhas + vidro ---------------------------------------------------------
{
  const b = buf(2.0);
  for (let k = 0; k < 34; k++) {
    const t0 = 0.05 + rnd() * 1.45, f0 = 260 + rnd() * 520, d = 0.03 + rnd() * 0.05, a = 0.15 + rnd() * 0.25;
    const i0 = Math.floor(t0 * SR), n = Math.floor(d * SR), pan = rnd() - 0.5;
    let ph = 0;
    for (let i = 0; i < n; i++) {
      const x = i / n, f = f0 * (1 + 1.6 * x * x); ph += TAU * f / SR;
      add(b, i0 + i, a * Math.sin(ph) * Math.sin(Math.PI * x) * (1 - 0.5 * x), pan);
    }
  }
  const lp = lowpass(400);
  for (let i = 0; i < b.n; i++) { const t = i / SR; add(b, i, 0.25 * Math.min(1, t / 0.2) * Math.max(0, 1 - t / 1.8) * lp(rnd() * 2 - 1)); }
  metal(b, 1.55, 2350, 0.18, [[1, 1, 1], [2.32, 0.5, 0.6], [4.25, 0.3, 0.4]], 0.18, 0.3);
  room(b, 0.25); finish(b, "CraftPotion", 0.7);
}

// --- Curativos: tecido rasgando ---------------------------------------------------
{
  const b = buf(1.3), bp = bandpass(2600, 0.9), bp2 = bandpass(5200, 1.2);
  for (const [s, d, pan] of [[0.03, 0.42, -0.2], [0.62, 0.5, 0.2]]) {
    const i0 = Math.floor(s * SR), n = Math.floor(d * SR);
    let grain = 0;
    for (let i = 0; i < n; i++) {
      const x = i / n; if (i % 90 === 0) grain = rnd() < 0.7 ? 0.4 + rnd() * 0.6 : 0.1;
      const env = Math.min(1, x * 10) * Math.pow(1 - x, 0.6);
      const nn = rnd() * 2 - 1;
      add(b, i0 + i, env * grain * (bp(nn) * 1.0 + bp2(nn) * 0.6), pan);
    }
  }
  room(b, 0.1); finish(b, "CraftBandage", 0.7);
}

// --- Genérico: brilho arcano --------------------------------------------------------
{
  const b = buf(1.6);
  [0, 0.09, 0.18, 0.27].forEach((t0, k) =>
    metal(b, t0, [880, 1109, 1319, 1760][k], 0.2, [[1, 1, 1], [2.01, 0.3, 0.6], [3.0, 0.12, 0.4]], 0.4, k % 2 ? 0.3 : -0.3));
  noiseBurst(b, 0, 1.0, 0.12, 7000, 0.7, (x) => Math.min(1, x * 6) * (1 - x));
  room(b, 0.35); finish(b, "CraftGeneric", 0.6);
}

// --- Peças épicas (coral, sino, tambor, reverb) do gerador dos Talentos ----------
const T = require(path.join(__dirname, "..", "talents-concept", "gen-sounds.js"));
const { choirNote, bell, drum, whoosh, reverb, NOTE } = T;
const ASR = (att, hold, rel, curve = 2) => (t) => {
  if (t < 0) return 0;
  if (t < att) return Math.pow(t / att, curve);
  if (t < att + hold) return 1;
  return Math.exp(-(t - att - hold) / rel);
};
const choirOn = (b) => (chord, st, dur, env) => {
  for (const [n, v, a, p] of chord)
    choirNote(b, { start: st, dur, f0: NOTE(n), vowel: v, voices: v.endsWith("m") ? 9 : 7, amp: a, pan: p, env, vibDepth: 0.006 });
};
// passa-alta + saturação leve + queda final, como no "Selar"
function epicFinish(b, name, peak, fadeSec) {
  const a = Math.exp(-TAU * 70 / SR);
  for (let pass = 0; pass < 2; pass++)
    for (const ch of [b.L, b.R]) { let x1 = 0, y1 = 0; for (let i = 0; i < b.n; i++) { const x = ch[i]; const y = a * (y1 + x - x1); x1 = x; y1 = y; ch[i] = y; } }
  let m = 0; for (let i = 0; i < b.n; i++) m = Math.max(m, Math.abs(b.L[i]), Math.abs(b.R[i]));
  const fade = Math.floor(fadeSec * SR);
  for (let i = 0; i < b.n; i++) {
    const f = Math.min(1, (b.n - i) / fade);
    b.L[i] = Math.tanh(b.L[i] / m * 1.15) * f; b.R[i] = Math.tanh(b.R[i] / m * 1.15) * f;
  }
  finish(b, name, peak);
}

// --- Unidade pronta (fila continua): estocada coral curta e épica ---------------
// prato invertido rápido -> golpe de tambor + "AH" em Ré maior curto + sinos
{
  const b = buf(1.25);
  const HIT = 0.09;
  const choir = choirOn(b);
  whoosh(b, 0.0, HIT, 1.1, 2500, 9500, (u) => Math.pow(u, 2));
  whoosh(b, HIT, 0.6, 0.6, 9000, 3500, (u) => Math.exp(-u * 7) * Math.min(1, u * 60));
  choir([["D3", "ah_m", 0.085, -0.2], ["A3", "ah_m", 0.075, 0.2], ["F#4", "ah_f", 0.07, -0.35],
         ["A4", "ah_f", 0.075, 0.35], ["D5", "ah_f", 0.08, 0]], HIT - 0.01, 0.75, ASR(0.025, 0.14, 0.16, 1));
  bell(b, HIT + 0.02, NOTE("A6"), 0.08, 0.6, -0.3);
  bell(b, HIT + 0.08, NOTE("D7"), 0.06, 0.5, 0.3);
  reverb(b, { room: 0.8, damp: 0.35, wet: 0.32, predelay: 0.02 });
  drum(b, HIT, 0.9, 140, 62, 0.3);
  drum(b, HIT + 0.01, 0.4, 95, 52, 0.35);
  epicFinish(b, "CraftUnitEpic", 0.8, 0.3);
}

// --- Receita concluída: fanfarra coral curta (estilo do "Selar" dos Talentos) -----
{
  const b = buf(2.6);
  const HIT = 0.30;
  const choir = choirOn(b);
  whoosh(b, 0.0, HIT, 1.3, 1800, 9500, (u) => Math.pow(u, 2.4));                // prato invertido
  whoosh(b, HIT, 1.4, 0.8, 9000, 3200, (u) => Math.exp(-u * 5) * Math.min(1, u * 60));
  // golpe: Si bemol maior curto (o "levantar")
  choir([["Bb2", "ah_m", 0.085, -0.2], ["F3", "ah_m", 0.08, 0.2], ["D4", "ah_f", 0.07, -0.3],
         ["F4", "ah_f", 0.075, 0.3], ["Bb4", "ah_f", 0.07, 0]], HIT - 0.02, 0.62, ASR(0.04, 0.28, 0.12, 1));
  // resolução: Ré maior aberto, brilhante
  const RES = HIT + 0.42;
  choir([["A2", "ah_m", 0.07, -0.2], ["D3", "ah_m", 0.085, 0.2], ["F#4", "ah_f", 0.07, -0.4],
         ["A4", "ah_f", 0.075, 0.4], ["D5", "ah_f", 0.08, 0], ["A5", "oh_f", 0.045, 0.1]], RES, 1.7, ASR(0.08, 0.5, 0.45, 1.2));
  // sinos subindo sobre a resolução
  [["D6", 0.00, -0.4], ["F#6", 0.06, 0.4], ["A6", 0.12, -0.2], ["D7", 0.18, 0.2]].forEach(([n, st, p], k) =>
    bell(b, RES + st, NOTE(n), 0.09 - k * 0.012, 1.3, p));
  reverb(b, { room: 0.88, damp: 0.3, wet: 0.42, predelay: 0.025 });
  // tambores depois do reverb: impacto seco
  drum(b, HIT, 0.95, 135, 58, 0.45);
  drum(b, HIT + 0.012, 0.45, 90, 50, 0.55);
  drum(b, RES, 0.6, 125, 56, 0.5);
  epicFinish(b, "CraftDone", 0.9, 0.35);
}

console.log(gameOk ? "copiado também para a pasta do jogo" : "AVISO: não copiou para a pasta do jogo");
