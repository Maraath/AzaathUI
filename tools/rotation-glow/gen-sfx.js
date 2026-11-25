// Efeitos sonoros das habilidades do Guerreiro, sintetizados do zero (sem voz, sem gravação de terceiros).
// Cada som é montado em camadas, como em design de som de jogo:
//   HeroicStrike  corte de ar curto -> impacto grave + "carne" + estalo + tinido de lâmina
//   Execute       corte mais grave -> impacto pesado + estalos de osso + carne + metal escuro + baque com cauda
//   BattleShout   subida de ar -> explosão grave + onda de choque + trompas em acorde heroico (Ré-Lá-Ré)
//   Intimidating  subida -> explosão + rosnado grave áspero + trompas dissonantes caindo de tom
//   Demoralizing  baque abafado + sopro descendo + zumbido escuro caindo + coro grave "oh" descendo
// Os golpes têm só ~0,1 s de ar antes do impacto (a voz/som sai no envio do golpe e não pode atrasar).
// Saída: AzaathUI/Media/Rotation/SfxDemoralizing.ogg (só o Brado Desmoralizador). Golpe Heroico, Subjugar,
// Executar, Brado de Batalha e Brado Intimidador do jogo são
// sons escolhidos pelo usuário (prep-user-sfx.js); as versões sintetizadas daqui vão para preview/sfx-antigo.
// Uso: node tools/rotation-glow/gen-sfx.js   (precisa do ffmpeg)
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync, spawnSync } = require("child_process");
const { reverb, choirNote, NOTE } = require("../talents-concept/gen-sounds.js");

const SR = 44100, TAU = Math.PI * 2;
const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Rotation");
fs.mkdirSync(OUT, { recursive: true });

let seed = 20261124;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const noise = () => rnd() * 2 - 1;
const buf = (sec) => { const n = Math.ceil(sec * SR); return { n, L: new Float32Array(n), R: new Float32Array(n) }; };

// ---------------------------------------------------------------- filtros (RBJ)
function biquad() { return { b0: 1, b1: 0, b2: 0, a1: 0, a2: 0, x1: 0, x2: 0, y1: 0, y2: 0 }; }
function setF(fl, type, f, q = 0.707, gdb = 0) {
  f = Math.max(20, Math.min(SR * 0.45, f));
  const w = TAU * f / SR, c = Math.cos(w), s = Math.sin(w), a = s / (2 * q), A = Math.pow(10, gdb / 40);
  let b0, b1, b2, a0, a1, a2;
  if (type === "lp") { b0 = (1 - c) / 2; b1 = 1 - c; b2 = b0; a0 = 1 + a; a1 = -2 * c; a2 = 1 - a; }
  else if (type === "hp") { b0 = (1 + c) / 2; b1 = -(1 + c); b2 = b0; a0 = 1 + a; a1 = -2 * c; a2 = 1 - a; }
  else if (type === "bp") { b0 = a; b1 = 0; b2 = -a; a0 = 1 + a; a1 = -2 * c; a2 = 1 - a; }
  else { b0 = 1 + a * A; b1 = -2 * c; b2 = 1 - a * A; a0 = 1 + a / A; a1 = -2 * c; a2 = 1 - a / A; }
  fl.b0 = b0 / a0; fl.b1 = b1 / a0; fl.b2 = b2 / a0; fl.a1 = a1 / a0; fl.a2 = a2 / a0;
  return fl;
}
function run(fl, x) {
  const y = fl.b0 * x + fl.b1 * fl.x1 + fl.b2 * fl.x2 - fl.a1 * fl.y1 - fl.a2 * fl.y2;
  fl.x2 = fl.x1; fl.x1 = x; fl.y2 = fl.y1; fl.y1 = y;
  return y;
}
const filt = (type, f, q, g) => setF(biquad(), type, f, q, g);

// ---------------------------------------------------------------- camadas (cada uma num buffer mono próprio)
const layer = (sec) => new Float32Array(Math.ceil(sec * SR));

// sopro/corte de ar: ruído em passa-faixa varrendo fA -> fPeak -> fB
function whoosh(sec, { fA, fPeak, fB, q = 1.1, peakAt = 0.65, sub = 0.4 }) {
  const y = layer(sec), n = y.length, bp = biquad(), bp2 = biquad();
  for (let i = 0; i < n; i++) {
    const u = i / n;
    const f = u < peakAt ? fA * Math.pow(fPeak / fA, u / peakAt) : fPeak * Math.pow(fB / fPeak, (u - peakAt) / (1 - peakAt));
    if (i % 32 === 0) { setF(bp, "bp", f, q); setF(bp2, "bp", f * 0.45, 0.9); }
    const e = u < peakAt ? Math.pow(u / peakAt, 2.4) : Math.pow(1 - (u - peakAt) / (1 - peakAt), 1.8);
    const x = noise();
    y[i] = (run(bp, x) + sub * run(bp2, x)) * e;
  }
  return y;
}

// baque grave: seno caindo de tom + clique filtrado no ataque
function thump(sec, { f0 = 110, f1 = 42, sweep = 0.05, decay = 0.2, click = 0.25 }) {
  const y = layer(sec), lp = filt("lp", 3500, 0.7);
  let ph = 0;
  for (let i = 0; i < y.length; i++) {
    const t = i / SR;
    ph += TAU * (f1 + (f0 - f1) * Math.exp(-t / sweep)) / SR;
    y[i] = Math.sin(ph) * Math.exp(-t / decay) * Math.min(1, t / 0.0012) + run(lp, noise()) * click * Math.exp(-t / 0.003);
  }
  return y;
}

// estalos (osso/madeira): rajadas curtíssimas de ruído em passa-faixa médio-agudo
function cracks(sec, { count = 3, spread = 0.025, f = 2600, q = 2.2, decay = 0.006 }) {
  const y = layer(sec);
  for (let k = 0; k < count; k++) {
    const i0 = Math.floor((k ? rnd() * spread : 0) * SR), bp = filt("bp", f * (0.8 + rnd() * 0.5), q), a = k ? 0.4 + rnd() * 0.5 : 1;
    for (let i = 0; i < SR * decay * 6 && i0 + i < y.length; i++) y[i0 + i] += run(bp, noise()) * a * Math.exp(-i / (SR * decay));
  }
  return y;
}

// "carne": ruído em passa-faixa grave-médio descendo, saturado
function flesh(sec, { fA = 750, fB = 320, decay = 0.07, q = 1.4, drive = 2.5 }) {
  const y = layer(sec), bp = biquad();
  for (let i = 0; i < y.length; i++) {
    const t = i / SR;
    if (i % 32 === 0) setF(bp, "bp", fB + (fA - fB) * Math.exp(-t / 0.03), q);
    y[i] = Math.tanh(run(bp, noise()) * drive * 4) * Math.exp(-t / decay);
  }
  return y;
}

// metal: parciais inarmônicos com decaimento, pares levemente desafinados (batimento)
function metal(sec, { f0 = 950, ratios = [1, 2.41, 3.9, 5.33, 7.1], decays = [0.55, 0.38, 0.28, 0.18, 0.11], beat = 1.6 }) {
  const y = layer(sec);
  ratios.forEach((r, k) => {
    const f = f0 * r, d = decays[k], a = 1 / (k + 1), p1 = rnd() * TAU, p2 = rnd() * TAU;
    for (let i = 0; i < y.length; i++) {
      const t = i / SR;
      y[i] += a * (Math.sin(TAU * f * t + p1) + 0.6 * Math.sin(TAU * (f + beat * (k + 1)) * t + p2)) * Math.exp(-t / d) * Math.min(1, t / 0.0008);
    }
  });
  return y;
}

// onda de choque: ruído com passa-baixa fechando (estrondo que se espalha)
function shock(sec, { fA = 4000, fB = 140, decay = 0.5 }) {
  const y = layer(sec), lp = biquad(), lp2 = biquad();
  for (let i = 0; i < y.length; i++) {
    const t = i / SR, f = fB + (fA - fB) * Math.exp(-t / (decay * 0.35));
    if (i % 32 === 0) { setF(lp, "lp", f, 0.8); setF(lp2, "lp", f, 0.8); }
    y[i] = run(lp2, run(lp, noise())) * Math.exp(-t / decay) * Math.min(1, t / 0.004);
  }
  return y;
}

// subida (ataque invertido): ruído agudo crescendo até o golpe
function riser(sec, { fA = 500, fB = 5000 }) {
  const y = layer(sec), bp = biquad();
  for (let i = 0; i < y.length; i++) {
    const u = i / y.length;
    if (i % 32 === 0) setF(bp, "bp", fA * Math.pow(fB / fA, u), 1.4);
    y[i] = run(bp, noise()) * Math.pow(u, 3);
  }
  return y;
}

// trompa de guerra: síntese aditiva de metal (mais harmônicos quanto mais forte), formante em "form" Hz,
// "colherada" de afinação no ataque, vibrato tardio. "players" músicos com desafinação, entrada, oscilação
// de volume (flutter) e vibrato próprios, mais sopro em passa-faixa: menos "eletrônico" que 3 vozes fixas.
function horn(sec, { f0, attack = 0.12, hold = 0.6, release = 0.35, bend = 0, bright = 1, players = 3, form = 900, breath = 0 }) {
  const y = layer(sec);
  const voices = players === 3 ? [[0, 0], [7, 0.013], [-6, 0.021]]
    : Array.from({ length: players }, (_, k) => [k ? (rnd() * 2 - 1) * 9 : 0, k ? rnd() * 0.035 : 0]);
  for (const [cents, late] of voices) {
    const ph = new Float64Array(40), det = Math.pow(2, cents / 1200);
    const vibR = 4.6 + rnd() * 1.2, vibP = rnd() * TAU, bp = filt("bp", form * 1.3, 1.2);
    let flut = 0;
    for (let i = 0; i < y.length; i++) {
      const t = i / SR - late;
      if (t < 0) continue;
      const env = t < attack ? Math.pow(t / attack, 1.5) : t < attack + hold ? 1 : Math.exp(-(t - attack - hold) / release);
      if (env < 1e-4 && t > attack) continue;
      flut += (noise() * 0.5 - flut) * 0.0008;
      const vib = 1 + 0.004 * Math.min(1, Math.max(0, (t - 0.3) / 0.3)) * Math.sin(TAU * vibR * t + vibP);
      const scoop = Math.pow(2, (-60 * Math.exp(-t / 0.05)) / 1200);
      const bendF = Math.pow(2, (bend * Math.min(1, t / (attack + hold + release))) / 12);
      const f = f0 * det * vib * scoop * bendF;
      const roll = 1.5 + 7 * env * bright;
      let s = 0;
      for (let k = 1; k < 40; k++) {
        const fk = f * k;
        if (fk > 8000) break;
        ph[k] += TAU * fk / SR;
        const fm = 1 + 1.8 / (1 + Math.pow((fk - form) / (form * 0.55), 2));
        s += Math.exp(-k / roll) * fm * Math.sin(ph[k]);
      }
      if (breath) s += run(bp, noise()) * breath * 6;
      y[i] += s * env * (1 + flut * 0.35) / voices.length;
    }
  }
  return y;
}

// rosnado: dente de serra grave com aspereza (modulação ~28 Hz), formantes de "ôh" e saturação
function growl(sec, { f0 = 68, rough = 28, drive = 3 }) {
  const y = layer(sec), n = y.length, fs1 = filt("bp", 420, 2.5), fs2 = filt("bp", 880, 3.5), fs3 = filt("bp", 2300, 5);
  const ph = new Float64Array(80);
  let jit = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR, u = i / n;
    jit += (noise() * 0.03 - jit) * 0.01;
    const f = f0 * (1 + jit) * (1 - 0.12 * u);
    let s = 0;
    for (let k = 1; k < 80 && f * k < 6000; k++) { ph[k] += TAU * f * k / SR; s += Math.sin(ph[k]) / k; }
    s = s * (0.6 + 0.4 * Math.sin(TAU * rough * t)) + noise() * 0.25;
    const env = Math.min(1, t / 0.05) * Math.pow(1 - u, 1.3);
    y[i] = Math.tanh((run(fs1, s) * 1.2 + run(fs2, s) * 0.8 + run(fs3, s) * 0.35) * drive) * env;
  }
  return y;
}

// zumbido escuro: serras graves desafinadas, passa-baixa, caindo de tom
function drone(sec, { f0 = 73.4, fall = -3, cutoff = 700 }) {
  const y = layer(sec), n = y.length, lp = filt("lp", cutoff, 0.9);
  const p = [0, 0, 0];
  for (let i = 0; i < n; i++) {
    const t = i / SR, u = i / n, f = f0 * Math.pow(2, (fall * u) / 12);
    let s = 0;
    [1, 1.009, 0.5].forEach((m, k) => { p[k] = (p[k] + f * m / SR) % 1; s += (2 * p[k] - 1) * (k === 2 ? 0.7 : 0.5); });
    y[i] = run(lp, s) * Math.min(1, t / 0.08) * Math.pow(1 - u, 1.2);
  }
  return y;
}

// ---------------------------------------------------------------- camadas de CORTE (lâmina na carne)
// lâmina cortando o ar: sopro rápido e agudo, sobe de fA a fB e corta seco no impacto
function slash(sec, { fA = 900, fB = 5500, q = 1.6, sub = 0.3 }) {
  const y = layer(sec), n = y.length, bp = biquad(), bp2 = biquad();
  for (let i = 0; i < n; i++) {
    const u = i / n, f = fA * Math.pow(fB / fA, Math.pow(u, 0.7));
    if (i % 16 === 0) { setF(bp, "bp", f, q); setF(bp2, "bp", f * 0.4, 1); }
    const x = noise(), e = Math.pow(u, 2.6) * (u > 0.94 ? (1 - u) / 0.06 : 1);
    y[i] = (run(bp, x) + sub * run(bp2, x)) * e;
  }
  return y;
}

// fio da lâmina raspando: ruído excitando ressonâncias metálicas estreitas que deslizam para baixo
// ("shhing" curto, não sino: decai rápido e é ruidoso)
function shing(sec, { f0 = 2900, decay = 0.09, glide = 0.85 }) {
  const y = layer(sec), n = y.length;
  const modes = [1, 1.43, 1.97, 2.61, 3.3].map((r) => ({ r, fl: biquad(), a: 0.5 + rnd() * 0.5 }));
  for (let i = 0; i < n; i++) {
    const t = i / SR, f = f0 * (glide + (1 - glide) * Math.exp(-t / 0.05));
    if (i % 16 === 0) for (const m of modes) setF(m.fl, "bp", f * m.r, 18);
    const x = noise() * Math.exp(-t / decay) * Math.min(1, t / 0.001);
    let v = 0;
    for (const m of modes) v += run(m.fl, x) * m.a;
    y[i] = v + x * 0.08;
  }
  return y;
}

// carne rasgando: muitos grãos curtíssimos de ruído (2-7 ms), cada um num passa-faixa aleatório
// 350-2600 Hz, densos no corte e rareando; saturado (textura molhada de rasgo)
function tear(sec, { dens = 900, decay = 0.08, fLo = 350, fHi = 2600, drive = 2.2 }) {
  const y = layer(sec), n = y.length;
  let t = 0;
  while (t < sec) {
    const rate = dens * Math.exp(-t / decay) + 25;
    t += -Math.log(1 - rnd()) / rate;
    const i0 = Math.floor(t * SR), len = Math.floor((0.002 + rnd() * 0.005) * SR);
    const fl = filt("bp", fLo * Math.pow(fHi / fLo, rnd()), 3 + rnd() * 4), a = (0.4 + rnd() * 0.6) * Math.exp(-t / (decay * 1.6));
    for (let k = 0; k < len && i0 + k < n; k++) y[i0 + k] += run(fl, noise()) * a * Math.sin(Math.PI * k / len);
  }
  for (let i = 0; i < n; i++) y[i] = Math.tanh(y[i] * drive * 3);
  return y;
}

// respingos: gotas esparsas (cliques curtos ressonantes 1,8-5 kHz) depois do corte
function splatter(sec, { count = 14, spread = 0.3, decay = 0.0025 }) {
  const y = layer(sec);
  for (let k = 0; k < count; k++) {
    const at = Math.pow(rnd(), 1.8) * spread, i0 = Math.floor(at * SR), fl = filt("bp", 1800 + rnd() * 3200, 6), a = (0.3 + rnd() * 0.7) * Math.exp(-at / 0.15);
    for (let i = 0; i < SR * decay * 6 && i0 + i < y.length; i++) y[i0 + i] += run(fl, noise()) * a * Math.exp(-i / (SR * decay));
  }
  return y;
}

// limitador com antecipação (3 ms), estéreo ligado: deixa subir o volume sem estourar o pico
function limit(b, ceil) {
  const look = Math.round(SR * 0.003), n = b.n, tg = new Float32Array(n);
  for (let i = 0; i < n; i++) { const a = Math.max(Math.abs(b.L[i]), Math.abs(b.R[i])); tg[i] = a > ceil ? ceil / a : 1; }
  const rel = Math.exp(-1 / (SR * 0.06));
  let g = 1;
  for (let i = 0; i < n; i++) {
    let m = 1;
    for (let k = i; k < Math.min(n, i + look); k++) if (tg[k] < m) m = tg[k];
    g = m < g ? m : m + (g - m) * rel;
    b.L[i] *= g; b.R[i] *= g;
  }
}

// ---------------------------------------------------------------- mixagem
// põe a camada no mix com pico em gdb (dBFS relativo), a partir de "at" segundos, com pan
function place(b, y, at, gdb, pan = 0) {
  let pk = 0;
  for (let i = 0; i < y.length; i++) pk = Math.max(pk, Math.abs(y[i]));
  const g = Math.pow(10, gdb / 20) / (pk || 1), i0 = Math.floor(at * SR);
  const gL = Math.cos((pan + 1) * Math.PI / 4) * Math.SQRT2, gR = Math.sin((pan + 1) * Math.PI / 4) * Math.SQRT2;
  // último quarto da camada some em cosseno: cauda que ainda soa não termina num corte seco
  const fadeFrom = Math.floor(y.length * 0.75), fadeLen = y.length - fadeFrom;
  for (let i = 0; i < y.length && i0 + i < b.n; i++) {
    const f = i < fadeFrom ? 1 : 0.5 + 0.5 * Math.cos(Math.PI * (i - fadeFrom) / fadeLen);
    b.L[i0 + i] += y[i] * g * gL * f; b.R[i0 + i] += y[i] * g * gR * f;
  }
}

function writeWav(file, b, mono) {
  const ch = mono ? 1 : 2, w = Buffer.alloc(44 + b.n * 4 * ch);
  w.write("RIFF", 0); w.writeUInt32LE(36 + b.n * 4 * ch, 4); w.write("WAVEfmt ", 8); w.writeUInt32LE(16, 16);
  w.writeUInt16LE(3, 20); w.writeUInt16LE(ch, 22); w.writeUInt32LE(SR, 24); w.writeUInt32LE(SR * 4 * ch, 28);
  w.writeUInt16LE(4 * ch, 32); w.writeUInt16LE(32, 34); w.write("data", 36); w.writeUInt32LE(b.n * 4 * ch, 40);
  for (let i = 0; i < b.n; i++) {
    if (mono) w.writeFloatLE((b.L[i] + b.R[i]) * 0.5, 44 + i * 4);
    else { w.writeFloatLE(b.L[i], 44 + i * 8); w.writeFloatLE(b.R[i], 48 + i * 8); }
  }
  fs.writeFileSync(file, w);
}

const lufs = (file) => {
  const e = spawnSync("ffmpeg", ["-hide_banner", "-nostats", "-i", file, "-af", "ebur128=peak=true", "-f", "null", "-"]).stderr.toString();
  const I = e.match(/I:\s+(-?[\d.]+) LUFS\s*\n\s*Threshold/), P = e.match(/Peak:\s+(-?[\d.]+) dBFS/g);
  return { I: I ? Number(I[1]) : -70, peak: P ? Number(P[P.length - 1].match(/-?[\d.]+/)[0]) : 0 };
};

// final: tira DC/subgrave inútil, saturação leve opcional, volume alvo com limitador (pico -1 dBTP)
// trecho de 50 ms mais forte (dB RMS): para golpes curtos é o que o ouvido percebe como volume; o LUFS
// mede médias de 400 ms e subestima um impacto de 50 ms
function rms50(b) {
  const W = Math.round(SR * 0.05);
  let acc = 0, best = 0;
  for (let i = 0; i < b.n; i++) {
    const v = (b.L[i] + b.R[i]) * 0.5;
    acc += v * v;
    if (i >= W) { const o = (b.L[i - W] + b.R[i - W]) * 0.5; acc -= o * o; }
    if (i >= W - 1 && acc > best) best = acc;
  }
  return 10 * Math.log10(best / W + 1e-12);
}

// peak50: alvo em dB do trecho de 50 ms mais forte (no lugar do LUFS), para golpes curtos
function finish(b, name, { target = -10, mono = false, drive = 0, dir = OUT, prefix = "Sfx", peak50 = null } = {}) {
  for (const ch of [b.L, b.R]) {
    const hp = filt("hp", 32, 0.7);
    for (let i = 0; i < b.n; i++) { let v = run(hp, ch[i]); if (drive) v = Math.tanh(v * drive) / drive; ch[i] = v; }
  }
  const fade = SR * 0.08;
  for (let i = 0; i < b.n; i++) { const f = Math.min(1, (b.n - i) / fade); b.L[i] *= f; b.R[i] *= f; }
  fs.mkdirSync(dir, { recursive: true });
  const tmp = path.join(dir, "_" + name + ".wav");
  // ganho até o alvo + limitador; até 3 passadas (o limitador come um pouco do volume)
  const src = { L: Float32Array.from(b.L), R: Float32Array.from(b.R) };
  writeWav(tmp, b, mono);
  const want = peak50 !== null ? peak50 : target;
  const measure = () => (peak50 !== null ? rms50(b) : lufs(tmp).I);
  let gdb = want - measure();
  for (let pass = 0; pass < 6; pass++) {
    const k = Math.pow(10, gdb / 20);
    for (let i = 0; i < b.n; i++) { b.L[i] = src.L[i] * k; b.R[i] = src.R[i] * k; }
    limit(b, 0.82);
    writeWav(tmp, b, mono);
    const got = measure();
    if (Math.abs(want - got) < 0.3) break;
    gdb += (want - got) * 1.5; // o limitador come parte do ganho: corrige com folga
  }
  // o Vorbis passa um pouco do pico: mede o arquivo final e abaixa se passar de -0,6 dBTP
  const ogg = path.join(dir, prefix + name + ".ogg");
  let vol = 0;
  for (let t = 0; t < 4; t++) {
    execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", tmp, "-af", `volume=${vol.toFixed(2)}dB`, "-c:a", "libvorbis", "-q:a", "9", ogg]);
    const pk = lufs(ogg).peak;
    if (pk <= -0.6) break;
    vol -= pk + 0.8;
  }
  const r = lufs(ogg);
  console.log(`${name.padEnd(14)} ${(b.n / SR).toFixed(2)} s  ${mono ? "mono  " : "estéreo"}  ${r.I.toFixed(1)} LUFS  50 ms ${rms50(b).toFixed(1)} dB  pico ${r.peak.toFixed(1)} dBTP`);
  fs.unlinkSync(tmp);
}

module.exports = { SR, TAU, rnd, noise, buf, layer, biquad, setF, run, filt, place, finish, limit, reverb,
  whoosh, thump, cracks, flesh, metal, shock, riser, horn, growl, drone, slash, shing, tear, splatter };
// usado como biblioteca (gen-strikes.js): só exporta as camadas
if (require.main === module) {
// ================================================================ os sons
const HIT = 0.1; // instante do impacto nos golpes

{ // Golpe Heroico: corte rápido na carne (lâmina no ar -> fio raspando + rasgo + carne + corpo curto)
  const b = buf(0.9);
  place(b, slash(0.11, { fA: 900, fB: 5200, q: 1.5 }), HIT - 0.105, -6);
  place(b, shing(0.35, { f0: 3100, decay: 0.07 }), HIT, -10, 0.1);
  place(b, tear(0.3, { dens: 1100, decay: 0.07, fLo: 450, fHi: 3000 }), HIT, -2);
  place(b, flesh(0.2, { fA: 1100, fB: 420, decay: 0.045, drive: 2.5 }), HIT, -6);
  place(b, thump(0.25, { f0: 180, f1: 95, sweep: 0.02, decay: 0.05, click: 0.5 }), HIT, -7);
  place(b, splatter(0.4, { count: 10, spread: 0.25 }), HIT + 0.02, -15);
  reverb(b, { room: 0.5, damp: 0.5, wet: 0.08, width: 0.4, predelay: 0.005 });
  finish(b, "HeroicStrike", { target: -10, mono: true, drive: 3, dir: path.join(__dirname, "preview", "sfx-antigo") }); // substituído (gen-strikes.js)
}

{ // Subjugar: o antigo som do Executar (golpe pesado com estalos e baque grave), pedido do usuário em 24/11
  const b = buf(1.6);
  place(b, whoosh(0.2, { fA: 220, fPeak: 900, fB: 400, q: 0.9, peakAt: 0.8, sub: 0.8 }), HIT - 0.15, -7);
  place(b, thump(0.9, { f0: 120, f1: 38, sweep: 0.06, decay: 0.28, click: 0.45 }), HIT, 0);
  place(b, flesh(0.35, { fA: 700, fB: 260, decay: 0.1, drive: 3.5 }), HIT, -4);
  place(b, cracks(0.2, { count: 5, spread: 0.035, f: 2300, q: 2.8, decay: 0.006 }), HIT + 0.004, -4);
  place(b, metal(1.2, { f0: 620, ratios: [1, 2.2, 3.47, 5.1], decays: [0.3, 0.2, 0.14, 0.09], beat: 1.1 }), HIT + 0.002, -19, -0.1);
  place(b, thump(1.2, { f0: 70, f1: 30, sweep: 0.12, decay: 0.45, click: 0 }), HIT + 0.02, -5);
  reverb(b, { room: 0.72, damp: 0.5, wet: 0.17, width: 0.5, predelay: 0.01 });
  finish(b, "Overpower", { target: -10, mono: true, drive: 3, dir: path.join(__dirname, "preview", "sfx-antigo") }); // substituído (prep-user-sfx.js)
}

{ // Executar: talho brutal (lâmina pesada -> rasgo longo e forte + carne + osso partindo + respingos)
  const b = buf(1.2);
  place(b, slash(0.15, { fA: 500, fB: 3800, q: 1.2, sub: 0.7 }), HIT - 0.145, -5);
  place(b, shing(0.4, { f0: 2300, decay: 0.08, glide: 0.8 }), HIT, -12, -0.1);
  place(b, tear(0.5, { dens: 1400, decay: 0.12, fLo: 300, fHi: 2400, drive: 2.8 }), HIT, 0);
  place(b, flesh(0.4, { fA: 800, fB: 240, decay: 0.11, drive: 3.5 }), HIT, -3);
  place(b, cracks(0.2, { count: 4, spread: 0.05, f: 2000, q: 2.5, decay: 0.007 }), HIT + 0.03, -6);
  place(b, thump(0.35, { f0: 150, f1: 70, sweep: 0.03, decay: 0.08, click: 0.5 }), HIT, -6);
  place(b, splatter(0.6, { count: 20, spread: 0.45 }), HIT + 0.03, -12);
  reverb(b, { room: 0.6, damp: 0.5, wet: 0.1, width: 0.4, predelay: 0.006 });
  finish(b, "Execute", { target: -10, mono: true, drive: 3, dir: path.join(__dirname, "preview", "sfx-antigo") }); // substituído (gen-strikes.js)
}

{ // Brado de Batalha (sério: sem subida nem acorde maior, que soavam "de desenho")
  // tambor grave seco + onda de choque escura + trompa de guerra grave (quinta aberta Ré-Lá, 5 músicos,
  // sopro, pouco brilho) + coro masculino grave em uníssono "ah" (peso de exército) + salão escuro
  const b = buf(2.4), H = 0.04;
  place(b, whoosh(0.14, { fA: 180, fPeak: 520, fB: 300, q: 0.8, peakAt: 0.85, sub: 1 }), 0, -16);
  place(b, thump(1.2, { f0: 78, f1: 32, sweep: 0.07, decay: 0.42, click: 0.3 }), H, 0);
  place(b, thump(0.9, { f0: 160, f1: 70, sweep: 0.02, decay: 0.09, click: 0.6 }), H, -7);
  place(b, shock(1.0, { fA: 2200, fB: 110, decay: 0.42 }), H, -9);
  place(b, horn(1.9, { f0: NOTE("D2"), attack: 0.16, hold: 0.62, release: 0.45, bend: -0.4, bright: 0.45, players: 5, form: 620, breath: 0.25 }), H + 0.01, -4, -0.15);
  place(b, horn(1.9, { f0: NOTE("A2"), attack: 0.2, hold: 0.55, release: 0.45, bend: -0.4, bright: 0.4, players: 5, form: 620, breath: 0.2 }), H + 0.03, -9, 0.2);
  const ch = buf(1.6);
  for (const [n, p] of [["D2", -0.2], ["D3", 0.2]])
    choirNote(ch, { start: 0, dur: 1.2, f0: NOTE(n), vowel: "ah_m", voices: 10, amp: 0.1, pan: p,
      env: (t) => (t < 0.06 ? t / 0.06 : t < 0.45 ? 1 : Math.exp(-(t - 0.45) / 0.3)), breath: 0.05, vibDepth: 0.003 });
  const chm = new Float32Array(ch.n);
  for (let i = 0; i < ch.n; i++) chm[i] = (ch.L[i] + ch.R[i]) * 0.5;
  place(b, chm, H, -9);
  reverb(b, { room: 0.84, damp: 0.6, wet: 0.28, width: 0.6, predelay: 0.02 });
  finish(b, "BattleShout", { target: -11, drive: 1.15, dir: path.join(__dirname, "preview", "sfx-antigo") }); // substituído (prep-user-sfx.js)
}

{ // Brado Intimidador (ameaçador)
  const b = buf(2.4), H = 0.24;
  place(b, riser(H, { fA: 400, fB: 3000 }), 0, -13);
  place(b, thump(1.2, { f0: 80, f1: 30, sweep: 0.1, decay: 0.45, click: 0.25 }), H, 0);
  place(b, shock(0.9, { fA: 3500, fB: 120, decay: 0.4 }), H, -8);
  place(b, growl(1.1, { f0: 64, rough: 30, drive: 3.5 }), H - 0.02, -3);
  for (const [n, p, g] of [["D2", -0.3, -6], ["G#2", 0.3, -7]])
    place(b, horn(1.5, { f0: NOTE(n), attack: 0.08, hold: 0.45, release: 0.45, bend: -2, bright: 1.3 }), H, g, p);
  reverb(b, { room: 0.85, damp: 0.6, wet: 0.3, width: 0.7, predelay: 0.02 });
  finish(b, "Intimidating", { target: -11, drive: 1.2, dir: path.join(__dirname, "preview", "sfx-antigo") }); // substituído (prep-user-sfx.js)
}

{ // Brado Desmoralizador (sombrio, drena)
  const b = buf(2.6), H = 0.12;
  place(b, thump(1.0, { f0: 75, f1: 32, sweep: 0.1, decay: 0.35, click: 0.05 }), H, -2);
  place(b, whoosh(1.2, { fA: 5000, fPeak: 2500, fB: 180, q: 0.8, peakAt: 0.12, sub: 0.6 }), H - 0.05, -8);
  place(b, drone(1.7, { f0: NOTE("D2"), fall: -4, cutoff: 650 }), H, -6);
  place(b, thump(1.4, { f0: 95, f1: 28, sweep: 0.5, decay: 0.6, click: 0 }), H + 0.05, -5);
  const ch = buf(1.8);
  for (const [n, v, p] of [["D3", "oh_m", -0.3], ["F3", "oh_m", 0.3], ["A2", "oh_m", 0]])
    choirNote(ch, { start: 0, dur: 1.5, f0: NOTE(n), vowel: v, voices: 6, amp: 0.1, pan: p,
      env: (t) => (t < 0.25 ? t / 0.25 : Math.exp(-(t - 0.25) / 0.5)), bend: (t) => Math.pow(2, (-3 * Math.min(1, t / 1.4)) / 12) });
  const chm = new Float32Array(ch.n);
  for (let i = 0; i < ch.n; i++) chm[i] = (ch.L[i] + ch.R[i]) * 0.5;
  place(b, chm, H + 0.05, -11);
  reverb(b, { room: 0.9, damp: 0.55, wet: 0.36, width: 0.8, predelay: 0.025 });
  finish(b, "Demoralizing", { target: -12 });
}
} // fim do "if (require.main === module)"
