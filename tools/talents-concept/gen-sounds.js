// Sons corais da aba de Talentos (Crisol de Azaath), sintetizados do zero:
// coral por síntese aditiva com formantes de vogal (ah/oh/uu), vários cantores
// por nota (desafinação, vibrato e respiração próprios), sinos, tambor e um
// reverb de salão (Freeverb). Nada de música de terceiros.
//
//   TalentSelect.ogg   escolher um talento: "uu" etéreo das vozes agudas + sino
//   TalentInfuse.ogg   infundir Azaath: arpejo "ah" subindo + cristal
//   TalentPurify.ogg   purificar fluxo: "oh" descendo + sopro invertido
//   TalentSeal.ogg     selar infusão: coral completo "AH" com tambor e prato
//
// Uso: node tools/talents-concept/gen-sounds.js   (precisa do ffmpeg no PATH)

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const SR = 44100;
const ENV_FPS = 30;   // amostras por segundo da curva de brilho
const ENVS = {};
const OUT_WS = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Sounds", "Talents");
const OUT_GAME = "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Sounds/Talents";
const TMP = path.join(__dirname, "preview", "sounds");
for (const d of [OUT_WS, TMP]) fs.mkdirSync(d, { recursive: true });
try { fs.mkdirSync(OUT_GAME, { recursive: true }); } catch (e) {}

let seed = 424242;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const gauss = () => (rnd() + rnd() + rnd() + rnd() - 2) * 0.866;
const TAU = Math.PI * 2;
const midi = (n) => 440 * Math.pow(2, (n - 69) / 12);
const NOTE = (s) => { // "D4", "F#3", "Bb2"
  const m = /^([A-G])([#b]?)(-?\d)$/.exec(s);
  const base = { C: 0, D: 2, E: 4, F: 5, G: 7, A: 9, B: 11 }[m[1]] + (m[2] === "#" ? 1 : m[2] === "b" ? -1 : 0);
  return midi(12 * (+m[3] + 1) + base);
};

// --- buffer estéreo ------------------------------------------------------------
function buf(sec) { const n = Math.ceil(sec * SR); return { n, L: new Float32Array(n), R: new Float32Array(n) }; }

// --- formantes (Hz, ganho, largura) ---------------------------------------------
const VOWELS = {
  ah_m: [[730, 1, 90], [1090, 0.55, 110], [2440, 0.25, 140], [2900, 0.22, 200]],
  ah_f: [[850, 1, 100], [1220, 0.6, 120], [2810, 0.28, 160], [3300, 0.18, 220]],
  oh_m: [[570, 1, 80], [840, 0.5, 100], [2410, 0.12, 140], [2900, 0.12, 200]],
  oh_f: [[600, 1, 90], [900, 0.5, 110], [2700, 0.14, 160], [3300, 0.10, 220]],
  uu_f: [[350, 1, 70], [800, 0.30, 100], [2700, 0.06, 160], [3300, 0.05, 220]],
  uu_m: [[300, 1, 60], [870, 0.28, 90], [2240, 0.05, 140], [2900, 0.05, 200]],
};
const formantGain = (f, v) => {
  let g = 0;
  for (const [F, A, B] of VOWELS[v]) g += A / (1 + Math.pow((f - F) / B, 2));
  return g + 0.015;
};

// Uma nota do coral: "voices" cantores na mesma nota.
// env(t) -> 0..1 (envelope de volume), bend(t) -> fator de frequência
function choirNote(out, o) {
  const { start, dur, f0, vowel, voices = 8, amp = 0.1, pan = 0, spread = 0.7, env, bend = () => 1, breath = 0.02, vibDepth = 0.006 } = o;
  const i0 = Math.floor(start * SR), n = Math.floor(dur * SR);
  for (let v = 0; v < voices; v++) {
    const det = Math.pow(2, (gauss() * 9) / 1200);          // ±9 cents
    const vibRate = 4.8 + rnd() * 1.4, vibPh = rnd() * TAU, vibDelay = 0.15 + rnd() * 0.25;
    const vp = Math.max(-1, Math.min(1, pan + (rnd() - 0.5) * 2 * spread));
    const gL = Math.cos((vp + 1) * Math.PI / 4), gR = Math.sin((vp + 1) * Math.PI / 4);
    const late = rnd() * 0.04;                               // cada cantor entra num instante
    const f = f0 * det;
    const H = Math.min(60, Math.floor(5200 / f));
    const hA = new Float32Array(H + 1), ph = new Float64Array(H + 1);
    for (let k = 1; k <= H; k++) { hA[k] = formantGain(k * f, vowel) * Math.pow(k, -0.55); ph[k] = rnd() * TAU; }
    let norm = 0; for (let k = 1; k <= H; k++) norm += hA[k] * hA[k]; norm = 1 / Math.sqrt(norm);
    const drift = rnd() * TAU;
    // respiração: ruído com um passa-faixa no 1º formante
    const F1 = VOWELS[vowel][0][0]; let b1 = 0, b2 = 0;
    const bw = 0.06, r = Math.exp(-TAU * bw * F1 / SR), cth = 2 * r * Math.cos(TAU * F1 / SR);
    for (let i = 0; i < n; i++) {
      const t = i / SR;
      if (t < late) continue;
      const e = env(t - late) * (0.9 + 0.1 * Math.sin(t * 0.7 + drift));
      if (e <= 0.0005) continue;
      const vib = 1 + vibDepth * Math.min(1, Math.max(0, (t - vibDelay) / 0.4)) * Math.sin(TAU * vibRate * t + vibPh)
        + 0.0015 * Math.sin(TAU * 0.37 * t + drift);
      const inc = TAU * f * vib * bend(t) / SR;
      let s = 0;
      for (let k = 1; k <= H; k++) { ph[k] += inc * k; s += hA[k] * Math.sin(ph[k]); }
      const nz = gauss(); const y = nz + cth * b1 - r * r * b2; b2 = b1; b1 = y;
      const val = (s * norm + y * breath) * e * amp;
      const j = i0 + i; if (j >= out.n) break;
      out.L[j] += val * gL; out.R[j] += val * gR;
    }
  }
}

// sino/cristal: parciais inarmônicas com decaimento
function bell(out, start, f0, amp, decay = 1.6, pan = 0) {
  const parts = [[1, 1], [2.0, 0.5], [2.76, 0.35], [4.07, 0.22], [5.4, 0.12], [6.8, 0.06]];
  const i0 = Math.floor(start * SR), n = Math.floor(decay * 4 * SR);
  const gL = Math.cos((pan + 1) * Math.PI / 4), gR = Math.sin((pan + 1) * Math.PI / 4);
  for (const [m, a] of parts) {
    const f = f0 * m, d = decay / Math.sqrt(m), ph = rnd() * TAU;
    for (let i = 0; i < n; i++) {
      const t = i / SR, v = Math.sin(TAU * f * t + ph) * a * Math.exp(-t / d) * Math.min(1, t / 0.002) * amp;
      const j = i0 + i; if (j >= out.n) break; out.L[j] += v * gL; out.R[j] += v * gR;
    }
  }
}

// tambor grave (taiko/tímpano): seno caindo de tom + estalo filtrado
function drum(out, start, amp, fHi = 95, fLo = 42, decay = 0.9) {
  const i0 = Math.floor(start * SR), n = Math.floor(decay * 4 * SR); let ph = 0, lp = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    const f = fLo + (fHi - fLo) * Math.exp(-t / 0.08);
    ph += TAU * f / SR;
    lp += (gauss() - lp) * 0.08;
    const v = (Math.sin(ph) * Math.exp(-t / decay) + lp * 2.2 * Math.exp(-t / 0.05)) * amp * Math.min(1, t / 0.003);
    const j = i0 + i; if (j >= out.n) break; out.L[j] += v; out.R[j] += v;
  }
}

// sopro de ruído com filtro varrendo (ataque invertido / prato)
function whoosh(out, start, dur, amp, fA, fB, env) {
  const i0 = Math.floor(start * SR), n = Math.floor(dur * SR);
  let b1L = 0, b2L = 0, b1R = 0, b2R = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR, u = t / dur, f = fA * Math.pow(fB / fA, u);
    const r = Math.exp(-TAU * 0.35 * f / SR), c = 2 * r * Math.cos(TAU * f / SR);
    const yL = gauss() + c * b1L - r * r * b2L; b2L = b1L; b1L = yL;
    const yR = gauss() + c * b1R - r * r * b2R; b2R = b1R; b1R = yR;
    const e = env(u) * amp * 0.05;
    const j = i0 + i; if (j >= out.n) break; out.L[j] += yL * e; out.R[j] += yR * e;
  }
}

// --- reverb de salão (Freeverb) -------------------------------------------------
function reverb(b, { room = 0.86, damp = 0.35, wet = 0.4, width = 1, predelay = 0.02 } = {}) {
  const combs = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617], alls = [556, 441, 341, 225], spreadS = 23;
  const sc = SR / 44100;
  const run = (inp, off) => {
    const out = new Float32Array(inp.length);
    const pd = Math.floor(predelay * SR);
    for (const cl of combs) {
      const len = Math.floor((cl + off) * sc), line = new Float32Array(len); let idx = 0, store = 0;
      for (let i = 0; i < inp.length; i++) {
        const x = i >= pd ? inp[i - pd] * 0.015 : 0;
        const y = line[idx]; store = y * (1 - damp) + store * damp;
        line[idx] = x + store * room; idx = (idx + 1) % len; out[i] += y;
      }
    }
    for (const al of alls) {
      const len = Math.floor((al + off) * sc), line = new Float32Array(len); let idx = 0;
      for (let i = 0; i < out.length; i++) { const bo = line[idx], x = out[i]; out[i] = -x + bo; line[idx] = x + bo * 0.5; idx = (idx + 1) % len; }
    }
    return out;
  };
  const mono = new Float32Array(b.n); for (let i = 0; i < b.n; i++) mono[i] = (b.L[i] + b.R[i]) * 0.5;
  const wL = run(mono, 0), wR = run(mono, spreadS);
  const w1 = wet * (width / 2 + 0.5), w2 = wet * ((1 - width) / 2);
  for (let i = 0; i < b.n; i++) {
    const l = wL[i] * w1 + wR[i] * w2, r = wR[i] * w1 + wL[i] * w2;
    b.L[i] = b.L[i] * (1 - wet * 0.5) + l; b.R[i] = b.R[i] * (1 - wet * 0.5) + r;
  }
}

// --- finalização: corta graves inúteis, normaliza, suaviza o fim, grava ---------
function finish(b, name, peak) {
  // passa-alta (2 passes de 1ª ordem em 70 Hz): o grave somado ao reverb embolava o coral
  const a = Math.exp(-TAU * 70 / SR);
  for (let pass = 0; pass < 2; pass++)
    for (const ch of [b.L, b.R]) { let x1 = 0, y1 = 0; for (let i = 0; i < b.n; i++) { const x = ch[i]; const y = a * (y1 + x - x1); x1 = x; y1 = y; ch[i] = y; } }
  let m = 0; for (let i = 0; i < b.n; i++) m = Math.max(m, Math.abs(b.L[i]), Math.abs(b.R[i]));
  const g = peak / (m || 1), fade = Math.floor(0.25 * SR);
  const data = Buffer.alloc(44 + b.n * 4);
  data.write("RIFF", 0); data.writeUInt32LE(36 + b.n * 4, 4); data.write("WAVE", 8); data.write("fmt ", 12);
  data.writeUInt32LE(16, 16); data.writeUInt16LE(1, 20); data.writeUInt16LE(2, 22); data.writeUInt32LE(SR, 24);
  data.writeUInt32LE(SR * 4, 28); data.writeUInt16LE(4, 32); data.writeUInt16LE(16, 34); data.write("data", 36); data.writeUInt32LE(b.n * 4, 40);
  for (let i = 0; i < b.n; i++) {
    const f = Math.min(1, (b.n - i) / fade) * Math.min(1, i / 64);
    // leve saturação suave para colar o coral
    const sat = (v) => Math.tanh(v * 1.15) / Math.tanh(1.15);
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sat(b.L[i] * g) * f)) * 32767), 44 + i * 4);
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, sat(b.R[i] * g) * f)) * 32767), 46 + i * 4);
  }
  // curva de volume para o brilho acompanhar o canto: RMS em quadros de 1/30 s,
  // normalizada pelo próprio pico e levemente "aberta" (raiz) para o brilho aparecer
  {
    const fr = Math.floor(SR / ENV_FPS), env = [];
    for (let i0 = 0; i0 < b.n; i0 += fr) {
      let e = 0, c = 0;
      for (let i = i0; i < Math.min(b.n, i0 + fr); i++) { const v = (b.L[i] + b.R[i]) * 0.5 * g; e += v * v; c++; }
      env.push(Math.sqrt(e / Math.max(1, c)));
    }
    // ataque rápido, queda lenta (como um medidor de VU): o brilho não treme
    for (let i = 1, y = env[0]; i < env.length; i++) { y += (env[i] - y) * (env[i] > y ? 0.55 : 0.18); env[i] = y; }
    const pk = Math.max(...env) || 1;
    ENVS[name] = env.map((v) => Math.pow(v / pk, 0.7));
  }
  const wav = path.join(TMP, name + ".wav");
  fs.writeFileSync(wav, data);
  const ogg = path.join(OUT_WS, name + ".ogg");
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", ogg]);
  try { fs.copyFileSync(ogg, path.join(OUT_GAME, name + ".ogg")); } catch (e) { console.log("sem acesso à pasta do jogo:", e.code); }
  console.log("gerado", name + ".ogg", (b.n / SR).toFixed(2) + "s");
}

// envelope ataque/sustentação/queda
const ASR = (att, hold, rel, curve = 2) => (t) => {
  if (t < 0) return 0;
  if (t < att) return Math.pow(t / att, curve);
  if (t < att + hold) return 1;
  return Math.max(0, Math.exp(-(t - att - hold) / rel));
};

// usado como biblioteca (testes): só exporta as peças
if (require.main !== module) { module.exports = { buf, choirNote, drum, whoosh, bell, reverb, NOTE, SR, TAU }; return; }

// =============================================================================
// 1. Selecionar talento: "uu" etéreo (Ré menor aberto, vozes agudas) + sino
// =============================================================================
{
  const b = buf(2.6);
  const env = ASR(0.22, 0.25, 0.45, 1.6);
  for (const [n, p] of [["D5", -0.4], ["A5", 0.4], ["F5", 0], ["D6", 0.1]])
    choirNote(b, { start: 0, dur: 2.0, f0: NOTE(n), vowel: "uu_f", voices: 6, amp: 0.10, pan: p, env, breath: 0.035 });
  choirNote(b, { start: 0, dur: 2.0, f0: NOTE("D4"), vowel: "oh_f", voices: 5, amp: 0.07, env });
  bell(b, 0.02, NOTE("A6"), 0.10, 0.9, 0.3);
  bell(b, 0.10, NOTE("D7"), 0.06, 0.7, -0.3);
  reverb(b, { room: 0.88, wet: 0.5, predelay: 0.03 });
  finish(b, "TalentSelect", 0.45);
}

// =============================================================================
// 2. Infundir: arpejo "ah" subindo (Ré-Fá-Lá-Ré) sobre o grave + cristal
// =============================================================================
{
  const b = buf(3.4);
  choirNote(b, { start: 0, dur: 2.6, f0: NOTE("D3"), vowel: "ah_m", voices: 8, amp: 0.09, env: ASR(0.18, 0.7, 0.5) });
  choirNote(b, { start: 0, dur: 2.6, f0: NOTE("A3"), vowel: "ah_m", voices: 6, amp: 0.07, pan: 0.3, env: ASR(0.18, 0.7, 0.5) });
  [["D5", 0.00, -0.5], ["F5", 0.11, 0.5], ["A5", 0.22, -0.2], ["D6", 0.33, 0.2]].forEach(([n, st, p], k) => {
    choirNote(b, { start: st, dur: 2.4 - st, f0: NOTE(n), vowel: "ah_f", voices: 6, amp: 0.085, pan: p,
      env: ASR(0.07, 0.55 - k * 0.05, 0.55, 1.2), bend: (t) => 1 + 0.012 * Math.exp(-t / 0.05) * -1 });
  });
  [["A6", 0.33], ["D7", 0.40], ["F7", 0.47]].forEach(([n, st], k) => bell(b, st, NOTE(n), 0.07, 0.8, k - 1));
  whoosh(b, 0.0, 0.45, 0.6, 600, 5000, (u) => Math.sin(Math.PI * u) * u);
  reverb(b, { room: 0.88, wet: 0.45 });
  finish(b, "TalentInfuse", 0.50);
}

// =============================================================================
// 3. Purificar: "oh" descendo (Lá menor -> Ré menor), afinação caindo + sopro
// =============================================================================
{
  const b = buf(3.0);
  const bendDown = (t) => Math.pow(2, (-60 * Math.min(1, t / 1.2)) / 1200);
  for (const [n, p, v] of [["A4", -0.4, "oh_f"], ["E5", 0.4, "oh_f"], ["C5", 0, "oh_f"], ["A3", 0, "oh_m"]])
    choirNote(b, { start: 0, dur: 1.0, f0: NOTE(n), vowel: v, voices: 6, amp: 0.085, pan: p, env: ASR(0.10, 0.35, 0.25), bend: bendDown });
  for (const [n, p, v] of [["F4", -0.3, "uu_f"], ["D5", 0.3, "uu_f"], ["A4", 0, "uu_f"], ["D3", 0, "uu_m"]])
    choirNote(b, { start: 0.55, dur: 1.8, f0: NOTE(n), vowel: v, voices: 6, amp: 0.08, pan: p, env: ASR(0.25, 0.3, 0.45) });
  whoosh(b, 0.0, 1.1, 0.8, 6000, 400, (u) => Math.pow(1 - u, 1.5) * Math.min(1, u * 8));
  bell(b, 0.6, NOTE("D6"), 0.05, 1.2, 0);
  reverb(b, { room: 0.9, wet: 0.5 });
  finish(b, "TalentPurify", 0.55);
}

// =============================================================================
// 4. Selar: coral completo "AH" em Ré menor -> Si bemol maior -> Ré, tambor e prato
// =============================================================================
{
  const b = buf(6.2);
  // prato invertido subindo até o golpe
  whoosh(b, 0.0, 0.55, 1.4, 1500, 9000, (u) => Math.pow(u, 2.5));
  const HIT = 0.55;
  whoosh(b, HIT, 2.5, 0.9, 9000, 3000, (u) => Math.exp(-u * 4) * Math.min(1, u * 60));
  const choir = (chord, st, dur, env, ampM = 1) => {
    for (const [n, v, a, p] of chord)
      choirNote(b, { start: st, dur, f0: NOTE(n), vowel: v, voices: v.endsWith("m") ? 10 : 8, amp: a * ampM, pan: p, env, vibDepth: 0.007 });
  };
  // golpe: Ré menor cheio
  const Dm = [["D3", "ah_m", 0.09, -0.2], ["A3", "ah_m", 0.08, 0.2], ["D4", "ah_m", 0.07, 0],
              ["F4", "ah_f", 0.07, -0.4], ["A4", "ah_f", 0.075, 0.4], ["D5", "ah_f", 0.07, 0], ["F5", "ah_f", 0.04, 0.2]];
  choir(Dm, HIT - 0.02, 1.7, ASR(0.05, 0.9, 0.35, 1));
  // Si bemol maior (o "levantar" épico)
  const Bb = [["Bb2", "ah_m", 0.085, -0.2], ["F3", "ah_m", 0.08, 0.2], ["D4", "ah_f", 0.07, -0.3],
              ["F4", "ah_f", 0.075, 0.3], ["Bb4", "ah_f", 0.07, 0], ["D5", "ah_f", 0.05, 0.1]];
  choir(Bb, HIT + 1.5, 1.3, ASR(0.12, 0.55, 0.35, 1.3));
  // resolução: Ré maior aberto (terça picarda), longa
  const D = [["A2", "ah_m", 0.07, -0.2], ["D3", "ah_m", 0.085, 0.2], ["F#4", "ah_f", 0.07, -0.4],
             ["A4", "ah_f", 0.075, 0.4], ["D5", "ah_f", 0.075, 0], ["A5", "oh_f", 0.04, 0.1]];
  choir(D, HIT + 2.6, 2.6, ASR(0.15, 0.9, 0.7, 1.2));
  bell(b, HIT + 2.6, NOTE("D6"), 0.10, 2.0, -0.3);
  bell(b, HIT + 2.65, NOTE("A6"), 0.08, 1.8, 0.3);
  reverb(b, { room: 0.92, damp: 0.3, wet: 0.48, predelay: 0.03 });
  // tambores depois do reverb: impacto seco, sem cauda grave embolando o coral
  drum(b, HIT, 0.9, 130, 58, 0.55);
  drum(b, HIT + 0.012, 0.45, 90, 50, 0.7);
  drum(b, HIT + 1.5, 0.5, 125, 60, 0.45);
  drum(b, HIT + 2.6, 0.65, 120, 55, 0.7);
  finish(b, "TalentSeal", 0.93);
}

// =============================================================================
// Curvas de brilho -> bloco gerado dentro de Modules/Talents/Visuals.lua (entre marcas),
// para o talento e o núcleo acenderem junto com cada canto
// =============================================================================
{
  const LUA = path.join(__dirname, "..", "..", "AzaathUI", "Modules", "Talents", "Visuals.lua");
  const BEGIN = "-- @@CURVAS DOS CANTOS (gerado por tools/talents-concept/gen-sounds.js)@@";
  const END = "-- @@FIM DAS CURVAS@@";
  const body = [BEGIN, "local CUE_FPS = " + ENV_FPS, "local CUE_ENV = {"];
  for (const [name, env] of Object.entries(ENVS)) {
    const short = name.replace(/^Talent/, "");
    const vals = env.map((v) => (Math.round(v * 100) / 100).toString());
    const lines = [];
    for (let i = 0; i < vals.length; i += 30) lines.push("        " + vals.slice(i, i + 30).join(", ") + ",");
    body.push("    " + short + " = {", ...lines, "    },");
  }
  body.push("}", END);
  let lua = fs.readFileSync(LUA, "utf8");
  const i = lua.indexOf(BEGIN), j = lua.indexOf(END);
  if (i < 0 || j < 0) { console.log("marcas das curvas não achadas em Talents/Visuals.lua"); }
  else {
    lua = lua.slice(0, i) + body.join(String.fromCharCode(10)) + lua.slice(j + END.length);
    fs.writeFileSync(LUA, lua);
    console.log("curvas gravadas em Talents/Visuals.lua:", Object.keys(ENVS).map((k) => k + "=" + ENVS[k].length).join(" "));
  }
}
