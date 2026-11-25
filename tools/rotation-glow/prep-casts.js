// Vozes gravadas pelo usuário (tools/rotation-glow/source/*.ogg, Opus de celular) -> Media/Rotation/Cast*.ogg,
// casadas com as falas de personagem do próprio jogo (perfil medido em voice-profile.js / measure-game-vo.js).
//
// O que o jogo usa e o que fazemos igual:
//   - mono, 22050 Hz, Vorbis ~64 kbps (o WoW não toca Opus);
//   - timbre: EQ automático que leva o espectro da gravação ao perfil médio das vozes do jogo, por oitava
//     (a gravação de celular tinha ~15 dB a mais de grave profundo e ~5 dB a menos de presença);
//   - dinâmica natural: crista ~12-14 dB (a versão anterior estava esmagada em 6 dB e soava "colada");
//   - volume: TARGET_LUFS. As vozes do jogo ficam em -15,5 LUFS; usamos um pouco acima porque o grito
//     concorre com os golpes. Mais alto que isso só achatando (artificial): use o "Volume dos sons" no jogo.
//
// Etapas: limpeza (picos estourados, ronco, chiado, "s"), corte da inspiração antes do grito (até 0,8 s),
// expansor leve entre as palavras, EQ de casamento em 2 passadas, compressão leve, volume e pico.
// Saídas por voz: 3 tons (100%, -3,5%, +3,5%; o jogo sorteia) x 2 ambientes:
//   CastX.ogg, CastX2.ogg, CastX3.ogg      ao ar livre: seco, só reflexões curtíssimas de corpo
//   CastXIn.ogg, CastXIn2.ogg, CastXIn3.ogg  lugar fechado (IsIndoors/masmorra): sala curta. O som de
//   addon (PlaySoundFile) não recebe a acústica do lugar como os sons 3D do jogo, então vem pronta.
// Uso: node tools/rotation-glow/prep-casts.js   (precisa do ffmpeg). Depois: tools/Sync-Jogo.ps1
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync, spawnSync } = require("child_process");
const { reverb } = require("../talents-concept/gen-sounds.js");
const { CENTERS, GAME, analyze } = require("./voice-profile.js");

const SR = 44100, OUT_SR = 22050;
const TARGET_LUFS = -12;
const SRC = path.join(__dirname, "source");
const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Rotation");
const TMP = path.join(__dirname, "preview");
fs.mkdirSync(TMP, { recursive: true });

// [fonte, saída, opções]. cutAt (s no áudio original) corta a fala ali (sem uso no momento; ex.: a
// gravação do Executar tem pausa em 1,05-1,13 s entre "Executar!" e "bastardo imundo").
// Voz em uso (24/11): só a Luz de Elluna ("testemunhem o poder de Eluna"). As outras gravações ficam em
// source/ sem uso (as do Executar saíram a pedido do usuário).
const FILES = [
  ["luz de elluna.ogg", "CastElune"],
];
const PITCHES = [1, 0.965, 1.035];

const CLEAN = [
  "adeclip",                       // a gravação estourava (pico 0 dBFS cortado)
  "highpass=f=95:p=2", "highpass=f=95:p=2",
  "afftdn=nr=14:nf=-48:tn=1",      // chiado/ruído de fundo do celular
  "deesser=i=0.25",
].join(",");

const FR = Math.round(SR * 0.01);
const dB = (x) => 20 * Math.log10(Math.max(1e-9, x));

function pcm(args) {
  const raw = execFileSync("ffmpeg", ["-loglevel", "error", ...args, "-ar", String(SR), "-ac", "1", "-f", "f32le", "-"], { maxBuffer: 1 << 28 });
  const x = new Float32Array(raw.length / 4);
  for (let i = 0; i < x.length; i++) x[i] = raw.readFloatLE(i * 4);
  return x;
}

function writeWav(file, x) {
  const n = x.length, w = Buffer.alloc(44 + n * 4);
  w.write("RIFF", 0); w.writeUInt32LE(36 + n * 4, 4); w.write("WAVEfmt ", 8); w.writeUInt32LE(16, 16);
  w.writeUInt16LE(3, 20); w.writeUInt16LE(1, 22); w.writeUInt32LE(SR, 24); w.writeUInt32LE(SR * 4, 28);
  w.writeUInt16LE(4, 32); w.writeUInt16LE(32, 34); w.write("data", 36); w.writeUInt32LE(n * 4, 40);
  for (let i = 0; i < n; i++) w.writeFloatLE(x[i], 44 + i * 4);
  fs.writeFileSync(file, w);
}

const levels = (x) => {
  const nf = Math.floor(x.length / FR), lev = new Float32Array(nf);
  for (let f = 0; f < nf; f++) { let e = 0; for (let i = f * FR; i < (f + 1) * FR; i++) e += x[i] * x[i]; lev[f] = dB(Math.sqrt(e / FR)); }
  return lev;
};

// início do grito no áudio ORIGINAL: 1º quadro de 10 ms a menos de 15 dB do pico
// (a inspiração/ruído antes do grito fica 23-35 dB abaixo)
function voiceOnset(src) {
  const lev = levels(pcm(["-i", path.join(SRC, src)]));
  const peak = Math.max(...lev);
  let on = 0;
  while (on < lev.length && lev[on] < peak - 15) on++;
  return on;
}

function lufsOf(x) {
  const f = path.join(TMP, "_lufs.wav");
  writeWav(f, x);
  const e = spawnSync("ffmpeg", ["-hide_banner", "-nostats", "-i", f, "-af", "ebur128", "-f", "null", "-"]).stderr.toString();
  const m = e.match(/I:\s+(-?[\d.]+) LUFS\s*\n\s*Threshold/);
  return m ? Number(m[1]) : -70;
}

// EQ que leva o perfil de x ao do jogo (ganhos por oitava, limitados a -14..+9 dB)
function matchEq(x, label) {
  for (let pass = 0; pass < 2; pass++) {
    const prof = analyze(x, SR);
    const g = prof.bands.map((b, i) => Math.max(-14, Math.min(9, GAME.bands[i] - b)));
    const entries = [`entry(20,${g[0].toFixed(1)})`, ...CENTERS.map((c, i) => `entry(${c},${g[i].toFixed(1)})`), `entry(16000,${g[g.length - 1].toFixed(1)})`];
    const f = path.join(TMP, "_eq.wav");
    writeWav(f, x);
    x = pcm(["-i", f, "-af", `firequalizer=gain_entry='${entries.join(";")}'`]);
    if (pass === 0) console.log(`  ${label} EQ: ` + g.map((v, i) => `${CENTERS[i]}Hz ${v >= 0 ? "+" : ""}${v.toFixed(1)}`).join("  "));
  }
  return x;
}

function prep(src, name, opt = {}) {
  const x = pcm(["-i", path.join(SRC, src), "-af", CLEAN]);
  const lev = levels(x), nf = lev.length, peak = Math.max(...lev);
  const on = voiceOnset(src);
  let off = nf - 1;
  while (off > on && lev[off] < peak - 40) off--;
  const s0 = Math.max(0, on * FR - Math.round(SR * 0.015));
  const s1 = Math.min(x.length, (off + 1) * FR, opt.cutAt ? Math.round(opt.cutAt * SR) : Infinity);

  // expansor leve: abaixo de pico-30 dB, abaixa até 12 dB (mantém o ar natural, some o ruído)
  const thr = peak - 30, aA = Math.exp(-1 / (SR * 0.005)), aR = Math.exp(-1 / (SR * 0.09));
  let y = new Float32Array(s1 - s0), g = 1;
  for (let i = s0; i < s1; i++) {
    const l = lev[Math.min(nf - 1, Math.floor(i / FR))];
    const want = l >= thr ? 1 : Math.pow(10, -Math.min(12, thr - l) / 20);
    g = want > g ? want + (g - want) * aA : want + (g - want) * aR;
    let v = x[i] * g;
    const k = i - s0;
    if (k < SR * 0.005) v *= k / (SR * 0.005);
    if (s1 - i < SR * 0.08) v *= (s1 - i) / (SR * 0.08);
    y[k] = v;
  }

  y = matchEq(y, name);
  // compressão leve (sem achatar): segura os picos do grito, crista fica perto da do jogo
  const cf = path.join(TMP, "_c.wav");
  writeWav(cf, y);
  y = pcm(["-i", cf, "-af", "acompressor=threshold=-20dB:ratio=2.2:attack=8:release=160:knee=6"]);

  const pad = (a, n) => { const o = new Float32Array(a.length + n); o.set(a); return o; };
  // ao ar livre: 4 reflexões curtíssimas e escuras (corpo, sem cauda)
  const dry = pad(y, Math.round(SR * 0.05));
  {
    let lp = 0;
    const a = Math.exp(-2 * Math.PI * 3000 / SR), dark = new Float32Array(dry.length);
    for (let i = 0; i < dry.length; i++) { lp = dry[i] + (lp - dry[i]) * a; dark[i] = lp; }
    for (const [ms, gn] of [[7, 0.07], [12, 0.05], [18, 0.04], [26, 0.03]]) {
      const d = Math.round(SR * ms / 1000);
      for (let i = dry.length - 1; i >= d; i--) dry[i] += dark[i - d] * gn;
    }
  }
  // lugar fechado: sala de pedra curta (mono)
  const room = pad(y, Math.round(SR * 0.6));
  {
    const b = { n: room.length, L: Float32Array.from(room), R: Float32Array.from(room) };
    reverb(b, { room: 0.62, damp: 0.55, wet: 0.24, width: 0, predelay: 0.01 });
    for (let i = 0; i < room.length; i++) room[i] = (b.L[i] + b.R[i]) * 0.5;
  }

  for (const [suffix, sig] of [["", dry], ["In", room]]) {
    const gain = Math.pow(10, (TARGET_LUFS - lufsOf(sig)) / 20);
    // pico: limitador suave só nos topos acima de -3 dBFS, teto -1,2 dBFS
    const KNEE = 0.7, CEIL = 0.87;
    const z = sig.map((v) => { const a = Math.abs(v * gain); return Math.sign(v) * (a <= KNEE ? a : KNEE + (CEIL - KNEE) * Math.tanh((a - KNEE) / (CEIL - KNEE))); });
    for (let i = 0; i < z.length; i++) z[i] *= Math.min(1, (z.length - i) / (SR * 0.04));
    const wav = path.join(TMP, name + suffix + ".wav");
    writeWav(wav, z);
    const a = analyze(z, SR);
    console.log(`  ${(name + suffix).padEnd(20)} ${(z.length / SR).toFixed(2)} s  crista ${a.crest.toFixed(1)} dB  bandas ${a.bands.map((v) => v.toFixed(0)).join(" ")}`);
    PITCHES.forEach((p, k) => encode(wav, path.join(OUT, name + suffix + (k ? k + 1 : "") + ".ogg"), p));
  }
}

// mono 22050 Hz Vorbis q5 (~64 kbps, como as vozes do jogo); variação de tom por reamostragem.
// O Vorbis pode passar do pico do WAV: mede com 4x de sobreamostragem e abaixa se passar de -0,3 dB.
function encode(wav, ogg, pitch) {
  let vol = 1;
  for (let t = 0; t < 5; t++) {
    const af = (pitch !== 1 ? `asetrate=${Math.round(SR * pitch)},aresample=${SR},` : "") + `volume=${vol.toFixed(4)}`;
    execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", wav, "-af", af, "-ar", String(OUT_SR), "-ac", "1", "-c:a", "libvorbis", "-q:a", "5", ogg]);
    const dec = execFileSync("ffmpeg", ["-loglevel", "error", "-i", ogg, "-ar", "88200", "-f", "f32le", "-"], { maxBuffer: 1 << 28 });
    let m = 0;
    for (let i = 0; i < dec.length; i += 4) m = Math.max(m, Math.abs(dec.readFloatLE(i)));
    if (m <= 0.966) return;
    vol *= 0.95 / m;
  }
}

console.log("alvo (vozes do jogo):  crista " + GAME.crest + " dB  bandas " + GAME.bands.map((v) => v.toFixed(0)).join(" "));
for (const [src, name, opt] of FILES) prep(src, name, opt);
