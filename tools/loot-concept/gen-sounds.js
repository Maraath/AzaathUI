// Sons corais epicos do Azaath para celebracoes de itens (Media/LootCelebration/).
// Cadencia solene de catedral baseada em tools/talents-concept/gen-sounds.js
// (formantes ah/oh/uu, vibracao natural, sinos espacados, taiko e Freeverb amplo).
//
//   green.ogg      incomum (~2.60s): acorde coral etereo Dm + sinos
//   rare.ogg       raro/coleta/bolsa/receita (~3.80s): Dm -> Re maior + sinos
//   treasure.ogg   tesouro/raro abatido/marco (~3.80s): Dm -> Re maior com brilho de sinos
//   epic.ogg       epico/reliquia/companheiro/jackpot (~5.00s): Dm -> Bb -> Re maior
//   legendary.ogg  lendario (~8.80s): apoteose coral de catedral i -> bVI -> bVII -> I
//
// Uso: node tools/loot-concept/gen-sounds.js   (precisa do ffmpeg no PATH)

const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const T = require(path.join(__dirname, "..", "talents-concept", "gen-sounds.js"));
const { buf, choirNote, drum, whoosh, bell, reverb, NOTE, SR, TAU } = T;

const OUT_WS = path.join(__dirname, "..", "..", "AzaathUI", "Media", "LootCelebration");
const TMP = path.join(__dirname, "preview");
for (const d of [OUT_WS, TMP]) fs.mkdirSync(d, { recursive: true });

const ASR = (att, hold, rel, curve = 2) => (t) => {
  if (t < 0) return 0;
  if (t < att) return Math.pow(t / att, curve);
  if (t < att + hold) return 1;
  return Math.max(0, Math.exp(-(t - att - hold) / rel));
};

const choirOn = (b, vMult = 1) => (chord, st, dur, env, vib = 0.007) => {
  for (const [n, v, a, p] of chord) {
    const baseVoices = v.endsWith("m") ? 10 : 8;
    choirNote(b, {
      start: st,
      dur,
      f0: NOTE(n),
      vowel: v,
      voices: Math.max(5, Math.round(baseVoices * vMult)),
      amp: a,
      pan: p,
      env,
      vibDepth: vib,
    });
  }
};

function finish(b, name, peak, fadeSec = 0.45, hpHz = 70) {
  // Passa-alta (2 passes) para manter o grave do tambor limpo sobre o reverb do coral
  const a = Math.exp(-TAU * hpHz / SR);
  for (let pass = 0; pass < 2; pass++) {
    for (const ch of [b.L, b.R]) {
      let x1 = 0, y1 = 0;
      for (let i = 0; i < b.n; i++) {
        const x = ch[i];
        const y = a * (y1 + x - x1);
        x1 = x; y1 = y;
        ch[i] = y;
      }
    }
  }
  let m = 0;
  for (let i = 0; i < b.n; i++) m = Math.max(m, Math.abs(b.L[i]), Math.abs(b.R[i]));
  const g = peak / (m || 1);
  const fade = Math.floor(fadeSec * SR);
  const data = Buffer.alloc(44 + b.n * 4);
  data.write("RIFF", 0); data.writeUInt32LE(36 + b.n * 4, 4); data.write("WAVEfmt ", 8);
  data.writeUInt32LE(16, 16); data.writeUInt16LE(1, 20); data.writeUInt16LE(2, 22);
  data.writeUInt32LE(SR, 24); data.writeUInt32LE(SR * 4, 28); data.writeUInt16LE(4, 32); data.writeUInt16LE(16, 34);
  data.write("data", 36); data.writeUInt32LE(b.n * 4, 40);
  const satNorm = Math.tanh(1.15);
  for (let i = 0; i < b.n; i++) {
    const f = Math.min(1, (b.n - i) / fade) * Math.min(1, i / 64);
    const l = (Math.tanh(b.L[i] * g * 1.15) / satNorm) * f;
    const r = (Math.tanh(b.R[i] * g * 1.15) / satNorm) * f;
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, l)) * 32767), 44 + i * 4);
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, r)) * 32767), 46 + i * 4);
  }
  const wav = path.join(TMP, name + ".wav");
  const ogg = path.join(OUT_WS, name + ".ogg");
  fs.writeFileSync(wav, data);
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "6", ogg]);
  console.log("gerado", name + ".ogg", (b.n / SR).toFixed(2) + "s");
}

// 1. Incomum (Verde): coro Azaath suave e etereo em ritmo natural (~2.60s)
{
  const b = buf(2.60);
  const HIT = 0.20;
  const choir = choirOn(b, 0.75);
  whoosh(b, 0.0, HIT, 0.8, 1800, 7500, (u) => Math.pow(u, 2.2));
  whoosh(b, HIT, 1.0, 0.45, 7500, 2800, (u) => Math.exp(-u * 4.5) * Math.min(1, u * 50));
  choir(
    [["D3", "oh_m", 0.065, -0.2], ["A3", "ah_m", 0.060, 0.2],
     ["F4", "uu_f", 0.068, -0.35], ["A4", "ah_f", 0.072, 0.35], ["D5", "uu_f", 0.065, 0]],
    HIT - 0.02, 1.95, ASR(0.12, 0.55, 0.55, 1.4)
  );
  bell(b, HIT + 0.05, NOTE("A6"), 0.08, 1.15, -0.3);
  bell(b, HIT + 0.26, NOTE("D7"), 0.06, 1.00, 0.3);
  reverb(b, { room: 0.88, damp: 0.33, wet: 0.44, predelay: 0.025 });
  drum(b, HIT, 0.60, 125, 58, 0.48);
  finish(b, "green", 0.68, 0.40);
}

// 2. Raro / Tesouro / Coleta: progressao coral solene Dm -> Re maior (~3.80s)
function buildRareChoir(name, extraBells) {
  const b = buf(3.80);
  const HIT = 0.36;
  const choir = choirOn(b, 0.90);
  whoosh(b, 0.0, HIT, 1.15, 1600, 8800, (u) => Math.pow(u, 2.4));
  whoosh(b, HIT, 1.6, 0.65, 8800, 3000, (u) => Math.exp(-u * 4.2) * Math.min(1, u * 55));
  choir(
    [["D3", "ah_m", 0.085, -0.2], ["A3", "ah_m", 0.078, 0.2],
     ["F4", "ah_f", 0.070, -0.35], ["A4", "ah_f", 0.074, 0.35], ["D5", "ah_f", 0.070, 0]],
    HIT - 0.02, 1.45, ASR(0.08, 0.65, 0.36, 1.1)
  );
  const RES = HIT + 1.05;
  choir(
    [["A2", "ah_m", 0.072, -0.2], ["D3", "ah_m", 0.085, 0.2],
     ["F#4", "ah_f", 0.072, -0.4], ["A4", "ah_f", 0.076, 0.4], ["D5", "ah_f", 0.078, 0]],
    RES, 2.15, ASR(0.14, 0.72, 0.62, 1.3)
  );
  [["D6", 0.00, -0.35], ["F#6", 0.18, 0.35], ["A6", 0.36, 0]].forEach(([n, dt, p]) =>
    bell(b, RES + dt, NOTE(n), 0.085, 1.5, p));
  if (extraBells) {
    bell(b, RES + 0.54, NOTE("D7"), 0.075, 1.4, -0.25);
  }
  reverb(b, { room: 0.90, damp: 0.30, wet: 0.46, predelay: 0.025 });
  drum(b, HIT, 0.88, 132, 58, 0.52);
  drum(b, HIT + 0.015, 0.42, 90, 50, 0.60);
  drum(b, RES, 0.60, 122, 56, 0.55);
  finish(b, name, 0.80, 0.45);
}
buildRareChoir("rare", false);
buildRareChoir("treasure", true);

// 3. Epico / Companheiro / Reliquia / Jackpot: hino coral Dm -> Bb -> Re maior (~5.00s)
{
  const b = buf(5.00);
  const HIT = 0.46;
  const choir = choirOn(b, 1.0);
  whoosh(b, 0.0, HIT, 1.35, 1500, 9000, (u) => Math.pow(u, 2.5));
  whoosh(b, HIT, 2.2, 0.85, 9000, 3000, (u) => Math.exp(-u * 4.0) * Math.min(1, u * 60));
  choir(
    [["D3", "ah_m", 0.088, -0.2], ["A3", "ah_m", 0.080, 0.2], ["D4", "ah_m", 0.070, 0],
     ["F4", "ah_f", 0.070, -0.4], ["A4", "ah_f", 0.074, 0.4], ["D5", "ah_f", 0.070, 0]],
    HIT - 0.02, 1.55, ASR(0.06, 0.80, 0.35, 1.0)
  );
  const LIFT = HIT + 1.18;
  choir(
    [["Bb2", "ah_m", 0.085, -0.2], ["F3", "ah_m", 0.080, 0.2],
     ["D4", "ah_f", 0.070, -0.3], ["F4", "ah_f", 0.075, 0.3], ["Bb4", "ah_f", 0.072, 0], ["D5", "ah_f", 0.052, 0.1]],
    LIFT, 1.35, ASR(0.12, 0.55, 0.36, 1.3)
  );
  const RES = HIT + 2.18;
  choir(
    [["A2", "ah_m", 0.074, -0.2], ["D3", "ah_m", 0.088, 0.2], ["F#4", "ah_f", 0.072, -0.4],
     ["A4", "ah_f", 0.076, 0.4], ["D5", "ah_f", 0.078, 0], ["A5", "oh_f", 0.044, 0.1]],
    RES, 2.40, ASR(0.15, 0.85, 0.70, 1.2)
  );
  [["D6", 0.00, -0.35], ["A6", 0.16, 0.35], ["D7", 0.34, 0]].forEach(([n, dt, p], k) =>
    bell(b, RES + dt, NOTE(n), 0.095 - k * 0.014, 1.85, p));
  reverb(b, { room: 0.92, damp: 0.30, wet: 0.48, predelay: 0.03 });
  drum(b, HIT, 0.92, 130, 58, 0.55);
  drum(b, HIT + 0.015, 0.45, 90, 50, 0.68);
  drum(b, LIFT, 0.52, 125, 60, 0.48);
  drum(b, RES, 0.68, 120, 55, 0.68);
  finish(b, "epic", 0.88, 0.50);
}

// 4. Lendario: apoteose coral ultra-epica i(Dm) -> bVI(Bb) -> bVII(C) -> I(Re maior) (~8.80s)
{
  const b = buf(8.80);
  const HIT = 0.85;
  const choir = choirOn(b, 1.45);

  whoosh(b, 0.0, HIT, 1.15, 110, 680, (u) => Math.pow(u, 1.8));
  whoosh(b, 0.10, HIT - 0.10, 1.55, 1400, 9600, (u) => Math.pow(u, 2.7));
  choir(
    [["D2", "uu_m", 0.065, 0], ["D3", "oh_m", 0.055, -0.25], ["A3", "oh_m", 0.050, 0.25]],
    0.05, 0.90, ASR(0.55, 0.25, 0.12, 2.2), 0.005
  );

  whoosh(b, HIT, 2.4, 0.95, 9200, 2600, (u) => Math.exp(-u * 3.8) * Math.min(1, u * 60));
  choir(
    [["D2", "oh_m", 0.070, 0], ["D3", "ah_m", 0.095, -0.25], ["A3", "ah_m", 0.085, 0.25],
     ["D4", "ah_m", 0.075, 0], ["F4", "ah_f", 0.075, -0.45], ["A4", "ah_f", 0.080, 0.45],
     ["D5", "ah_f", 0.075, -0.15], ["F5", "ah_f", 0.048, 0.2]],
    HIT - 0.02, 1.90, ASR(0.06, 1.05, 0.42, 1.0), 0.0075
  );
  bell(b, HIT + 0.02, NOTE("D5"), 0.075, 1.8, -0.35);
  bell(b, HIT + 0.08, NOTE("A5"), 0.070, 1.7, 0.35);

  const T2 = 2.45;
  choir(
    [["Bb2", "ah_m", 0.092, -0.25], ["F3", "ah_m", 0.085, 0.25], ["Bb3", "ah_m", 0.074, 0],
     ["D4", "ah_f", 0.074, -0.35], ["F4", "ah_f", 0.078, 0.35], ["Bb4", "ah_f", 0.075, 0],
     ["D5", "ah_f", 0.058, 0.15]],
    T2, 1.50, ASR(0.11, 0.65, 0.38, 1.25), 0.0075
  );
  bell(b, T2 + 0.02, NOTE("Bb5"), 0.072, 1.4, -0.25);

  const T3 = 3.70;
  whoosh(b, 4.45, 0.65, 1.25, 1800, 9400, (u) => Math.pow(u, 2.2));
  choir(
    [["C3", "ah_m", 0.094, -0.25], ["G3", "ah_m", 0.086, 0.25], ["C4", "ah_m", 0.075, 0],
     ["E4", "ah_f", 0.075, -0.4], ["G4", "ah_f", 0.080, 0.4], ["C5", "ah_f", 0.078, -0.1],
     ["E5", "ah_f", 0.062, 0.15]],
    T3, 1.65, ASR(0.12, 0.72, 0.40, 1.2), 0.008
  );
  bell(b, T3 + 0.04, NOTE("C6"), 0.078, 1.4, 0.3);

  const RES = 5.10;
  whoosh(b, RES, 3.0, 1.00, 9500, 2800, (u) => Math.exp(-u * 3.5) * Math.min(1, u * 65));
  choir(
    [["D2", "oh_m", 0.075, 0], ["A2", "ah_m", 0.082, -0.25], ["D3", "ah_m", 0.098, 0.25],
     ["A3", "ah_m", 0.086, -0.15], ["F#4", "ah_f", 0.082, -0.45], ["A4", "ah_f", 0.084, 0.45],
     ["D5", "ah_f", 0.088, 0], ["F#5", "ah_f", 0.056, -0.25], ["A5", "oh_f", 0.052, 0.25]],
    RES, 3.35, ASR(0.15, 1.35, 0.92, 1.15), 0.0085
  );
  [["D6", 0.00, -0.35], ["F#6", 0.20, 0.35], ["A6", 0.42, -0.2], ["D7", 0.66, 0.2], ["A7", 0.96, 0]].forEach(([n, dt, p], k) =>
    bell(b, RES + dt, NOTE(n), 0.105 - k * 0.012, 2.6, p));

  reverb(b, { room: 0.95, damp: 0.24, wet: 0.54, predelay: 0.035 });

  drum(b, HIT - 0.14, 0.45, 110, 52, 0.25);
  drum(b, HIT,        1.05, 138, 48, 0.72);
  drum(b, HIT + 0.016, 0.55, 92, 42, 0.82);
  drum(b, T2,         0.68, 128, 54, 0.52);
  drum(b, T3,         0.74, 132, 54, 0.55);
  drum(b, RES - 0.14, 0.52, 115, 52, 0.28);
  drum(b, RES,        1.00, 136, 46, 0.85);
  drum(b, RES + 0.018, 0.50, 88, 40, 0.92);
  finish(b, "legendary", 0.95, 0.75, 50);
}
