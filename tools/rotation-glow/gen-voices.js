// Sons de voz do assistente de rotação, sintetizados do zero (sem gravações):
//   Media/Rotation/ChoirRa.ogg  coral épico curto "RÁ!" (Ímpeto da Vitória, Subjugar)
//   Media/Rotation/WarCry.ogg   grito de batalha grave "HRAAH!" (Executar)
// Coral: choirNote/drum/reverb de tools/talents-concept/gen-sounds.js.
// Grito: fonte glotal aditiva com sub-harmônico (rouquidão), formantes de "a" gritado,
// "h" soprado + "r" vibrado no início, saturação e três camadas.
// Uso: node tools/rotation-glow/gen-voices.js   (precisa do ffmpeg). Depois: tools/Sync-Jogo.ps1
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");
const T = require("../talents-concept/gen-sounds.js");
const { buf, choirNote, drum, whoosh, reverb, NOTE, SR, TAU } = T;

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Rotation");
const TMP = path.join(__dirname, "preview");
fs.mkdirSync(OUT, { recursive: true }); fs.mkdirSync(TMP, { recursive: true });

let seed = 90210;
const rnd = () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
const gauss = () => (rnd() + rnd() + rnd() + rnd() - 2) * 0.866;

function finish(b, name, peak) {
  const a = Math.exp(-TAU * 60 / SR);
  for (let pass = 0; pass < 2; pass++)
    for (const ch of [b.L, b.R]) { let x1 = 0, y1 = 0; for (let i = 0; i < b.n; i++) { const x = ch[i]; const y = a * (y1 + x - x1); x1 = x; y1 = y; ch[i] = y; } }
  let m = 0; for (let i = 0; i < b.n; i++) m = Math.max(m, Math.abs(b.L[i]), Math.abs(b.R[i]));
  const g = peak / (m || 1), fade = Math.floor(0.15 * SR);
  const data = Buffer.alloc(44 + b.n * 4);
  data.write("RIFF", 0); data.writeUInt32LE(36 + b.n * 4, 4); data.write("WAVEfmt ", 8); data.writeUInt32LE(16, 16);
  data.writeUInt16LE(1, 20); data.writeUInt16LE(2, 22); data.writeUInt32LE(SR, 24); data.writeUInt32LE(SR * 4, 28);
  data.writeUInt16LE(4, 32); data.writeUInt16LE(16, 34); data.write("data", 36); data.writeUInt32LE(b.n * 4, 40);
  for (let i = 0; i < b.n; i++) {
    const f = Math.min(1, (b.n - i) / fade);
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, b.L[i] * g * f)) * 32767), 44 + i * 4);
    data.writeInt16LE(Math.round(Math.max(-1, Math.min(1, b.R[i] * g * f)) * 32767), 46 + i * 4);
  }
  const wav = path.join(TMP, name + ".wav");
  fs.writeFileSync(wav, data);
  execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", wav, "-af", "acompressor=threshold=-20dB:ratio=4:attack=3:release=150:makeup=2,loudnorm=I=-9:TP=-0.5:LRA=7", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "6", path.join(OUT, name + ".ogg")]);
  console.log("gerado", name + ".ogg", (b.n / SR).toFixed(2) + "s");
}

// "r" vibrado: 3 batidas de língua (~28 Hz) antes da vogal aberta
const RA = (att, hold, rel) => (t) => {
  if (t < 0) return 0;
  const trill = t < 0.1 ? 0.3 + 0.7 * Math.abs(Math.sin(Math.PI * 28 * t)) : 1;
  const e = t < att ? Math.pow(t / att, 1.3) : t < att + hold ? 1 : Math.exp(-(t - att - hold) / rel);
  return e * trill;
};

// =============================================================================
// 1. Coral "RÁ!": Ré menor aberto, ataque seco com subida de afinação, tambor
// =============================================================================
{
  const b = buf(1.9);
  const env = RA(0.03, 0.26, 0.2);
  const scoop = (t) => Math.pow(2, (-90 * Math.exp(-t / 0.05)) / 1200); // entra 90 cents abaixo e sobe
  for (const [n, v, a, p] of [["D2", "ah_m", 0.10, 0], ["D3", "ah_m", 0.11, -0.2], ["A3", "ah_m", 0.10, 0.2],
    ["D4", "ah_m", 0.08, 0], ["F4", "ah_f", 0.07, -0.4], ["A4", "ah_f", 0.08, 0.4], ["D5", "ah_f", 0.075, 0]])
    choirNote(b, { start: 0, dur: 1.0, f0: NOTE(n), vowel: v, voices: v.endsWith("m") ? 10 : 8, amp: a, pan: p,
      env, bend: scoop, breath: 0.05, vibDepth: 0.004 });
  whoosh(b, 0, 0.35, 0.8, 7000, 2500, (u) => Math.exp(-u * 5) * Math.min(1, u * 80));
  reverb(b, { room: 0.88, damp: 0.3, wet: 0.42, predelay: 0.02 });
  drum(b, 0.0, 0.9, 120, 52, 0.45);
  drum(b, 0.01, 0.4, 85, 45, 0.6);
  finish(b, "ChoirRa", 0.9);
}

// =============================================================================
// 2. Grito de batalha "HRAAH!": voz masculina grave, rouca e saturada
// =============================================================================
const SHOUT_F = [[780, 1, 110], [1180, 0.6, 130], [2450, 0.32, 180], [3300, 0.18, 260], [4200, 0.08, 320]];
const shoutGain = (f) => { let g = 0; for (const [F, A, B] of SHOUT_F) g += A / (1 + Math.pow((f - F) / B, 2)); return g + 0.02; };

function shout(out, o) {
  const { start, dur, f0, amp, pan = 0, sub = 0.35 } = o;
  const i0 = Math.floor(start * SR), n = Math.floor(dur * SR);
  const gL = Math.cos((pan + 1) * Math.PI / 4), gR = Math.sin((pan + 1) * Math.PI / 4);
  const H = 70, ph = new Float64Array(H + 1); let phSub = 0;
  for (let k = 1; k <= H; k++) ph[k] = rnd() * TAU;
  let jit = 0, nb1 = 0, nb2 = 0;
  for (let i = 0; i < n; i++) {
    const t = i / SR;
    // contorno: sobe no ataque e cai no fim (grito de esforço)
    const c = t < 0.09 ? 0.86 + 0.18 * (t / 0.09) : 1.04 - 0.30 * Math.min(1, (t - 0.09) / (dur - 0.12));
    jit += (gauss() * 0.012 - jit) * 0.02;
    const f = f0 * c * (1 + jit);
    // "h" soprado (0-0.05), "r" vibrado (0.05-0.12), "aah" cheio, queda rápida
    let e;
    if (t < 0.05) e = 0;
    else if (t < 0.12) e = (0.35 + 0.65 * Math.abs(Math.sin(Math.PI * 30 * (t - 0.05)))) * ((t - 0.05) / 0.07);
    else if (t < dur - 0.22) e = 1;
    else e = Math.max(0, Math.pow((dur - t) / 0.22, 1.6));
    const shimmer = 1 + gauss() * 0.06;
    let s = 0; const inc = TAU * f / SR;
    for (let k = 1; k <= H; k++) {
      const fk = f * k; if (fk > 7000) break;
      ph[k] += inc * k;
      s += shoutGain(fk) * Math.pow(k, -0.25) * Math.sin(ph[k]);
    }
    phSub += inc * 0.5;
    s += sub * shoutGain(f * 0.5) * Math.sin(phSub) * 2.2 + sub * 0.4 * Math.sin(phSub * 3);
    // ar: ruído no formante 1 (forte no "h", leve depois)
    const r = Math.exp(-TAU * 0.25 * 900 / SR), cth = 2 * r * Math.cos(TAU * 900 / SR);
    const y = gauss() + cth * nb1 - r * r * nb2; nb2 = nb1; nb1 = y;
    const air = t < 0.06 ? Math.sin(Math.PI * t / 0.06) * 0.9 : 0.12;
    let v = s * 0.09 * e * shimmer + y * air * 0.05;
    v = Math.tanh(v * 2.4) * amp;            // rouquidão/saturação
    const j = i0 + i; if (j >= out.n) break;
    out.L[j] += v * gL; out.R[j] += v * gR;
  }
}

{
  const b = buf(1.5);
  shout(b, { start: 0, dur: 0.82, f0: 118, amp: 0.55, pan: 0 });
  shout(b, { start: 0.012, dur: 0.8, f0: 121, amp: 0.30, pan: -0.35, sub: 0.25 });
  shout(b, { start: 0.02, dur: 0.79, f0: 59.5, amp: 0.22, pan: 0.35, sub: 0.1 }); // oitava abaixo: peso
  reverb(b, { room: 0.78, damp: 0.45, wet: 0.22, predelay: 0.015 });
  drum(b, 0.06, 0.55, 110, 48, 0.35);
  finish(b, "WarCry", 0.92);
}
