// Assistente de rotação (Modules/RotationAssist.lua): brilho dos botões e som de aviso.
//   Media/Rotation/GlowOct.tga  halo + filete no octógono da barra NextGen (split-bar-concept, cantos 17%)
//   Media/Rotation/GlowSq.tga   o mesmo para os slots quadrados (demais layouts)
//   Media/Rotation/Alert.ogg    "tim" metálico curto e suave, sintetizado do zero
// Texturas brancas: o Lua tinge (dourado/vermelho) com SetVertexColor e blend ADD.
// O slot ocupa o meio da textura (metade do lado): no jogo o brilho tem 2x o botão.
// Uso: node tools/rotation-glow/gen.js   (precisa do Edge e do ffmpeg). Depois: tools/Sync-Jogo.ps1
"use strict";
const fs = require("fs");
const path = require("path");
const { spawnSync, execFileSync } = require("child_process");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const ROOT = path.resolve(__dirname, "../..");
const OUT = path.join(ROOT, "AzaathUI/Media/Rotation");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const SCALE = 2, C = 128, S = 64, O = (C - S) / 2;
fs.mkdirSync(OUT, { recursive: true });

const oct = (i) => { const c = S * 0.17, a = O + i, b = O + S - i;
  return `${a + c},${a} ${b - c},${a} ${b},${a + c} ${b},${b - c} ${b - c},${b} ${a + c},${b} ${a},${b - c} ${a},${a + c}`; };
const shape = (kind, i, attrs) => kind === "oct"
  ? `<polygon points="${oct(i)}" ${attrs} stroke-linejoin="round"/>`
  : `<rect x="${O + i}" y="${O + i}" width="${S - 2 * i}" height="${S - 2 * i}" rx="${6 - i * 0.3}" ${attrs}/>`;
const glow = (k) => `<svg width="${C}" height="${C}" viewBox="0 0 ${C} ${C}" xmlns="http://www.w3.org/2000/svg">
<defs><filter id="b1" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="9"/></filter>
<filter id="b2" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="3.5"/></filter>
<filter id="b3" x="-50%" y="-50%" width="200%" height="200%"><feGaussianBlur stdDeviation="1"/></filter></defs>
${shape(k, -2, 'fill="none" stroke="#fff" stroke-opacity="0.9" stroke-width="14" filter="url(#b1)"')}
${shape(k, 0, 'fill="none" stroke="#fff" stroke-width="7" filter="url(#b2)"')}
${shape(k, 4, 'fill="none" stroke="#fff" stroke-opacity="0.55" stroke-width="5" filter="url(#b2)"')}
${shape(k, 0.8, 'fill="none" stroke="#fff" stroke-width="2.2" filter="url(#b3)"')}
</svg>`;

const PIECES = [{ name: "GlowOct", x: 0, k: "oct" }, { name: "GlowSq", x: C, k: "sq" }];
const html = `<!doctype html><html><head><meta charset="utf-8"><style>html,body{margin:0;background:transparent;overflow:hidden}
.p{position:absolute;top:0}</style></head><body>${PIECES.map((p) => `<div class="p" style="left:${p.x}px">${glow(p.k)}</div>`).join("")}</body></html>`;
const TMP = path.join(__dirname, "preview");
fs.mkdirSync(TMP, { recursive: true });
const htmlFile = path.join(TMP, "pieces.html"), pngFile = path.join(TMP, "pieces.png");
fs.writeFileSync(htmlFile, html);
if (fs.existsSync(pngFile)) fs.unlinkSync(pngFile);
spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--user-data-dir=" + path.join(require("os").tmpdir(), "azaath_edge_" + Date.now()),
  "--no-first-run", "--hide-scrollbars", "--default-background-color=00000000", "--force-device-scale-factor=" + SCALE,
  "--window-size=" + 2 * C + "," + C, "--virtual-time-budget=2000", "--allow-file-access-from-files", "--screenshot=" + pngFile,
  "file:///" + htmlFile.split(String.fromCharCode(92)).join("/")], { stdio: "ignore" });
for (let t0 = Date.now(), last = -1; Date.now() - t0 < 30000;) {
  const sz = fs.existsSync(pngFile) ? fs.statSync(pngFile).size : 0;
  if (sz > 0 && sz === last) break;
  last = sz;
  Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, 400);
}
const page = readPNG(pngFile);
for (const p of PIECES) I.writeTGA(path.join(OUT, p.name + ".tga"), I.crop(page, p.x * SCALE, 0, C * SCALE, C * SCALE));

// --- som: dois sinos (quinta) + brilho de ruído agudo, ~0.9 s -------------------
const SR = 44100, N = Math.floor(SR * 0.9), L = new Float32Array(N), R = new Float32Array(N);
let seed = 7; const rnd = () => ((seed = (seed * 1664525 + 1013904223) >>> 0) / 4294967296) * 2 - 1;
const bell = (t0, f, amp, pan) => {
  const parts = [[1, 1, 0.55], [2.76, 0.35, 0.22], [5.4, 0.15, 0.1], [8.93, 0.06, 0.05]];
  for (let i = Math.floor(t0 * SR); i < N; i++) {
    const t = i / SR - t0; let v = 0;
    for (const [m, a, d] of parts) v += a * Math.sin(2 * Math.PI * f * m * t) * Math.exp(-t / d);
    v *= amp * Math.min(1, t / 0.004);
    L[i] += v * (1 - pan); R[i] += v * (1 + pan);
  }
};
bell(0, 1318.5, 0.22, -0.25); // E6
bell(0.07, 1975.5, 0.16, 0.25); // B6
for (let i = 0, lp = 0, hp = 0; i < Math.floor(SR * 0.25); i++) { // sopro metálico
  const x = rnd(); lp += (x - lp) * 0.6; hp = x - lp;
  const v = hp * 0.05 * Math.exp(-i / SR / 0.06); L[i] += v; R[i] += v;
}
const wav = Buffer.alloc(44 + N * 4);
wav.write("RIFF", 0); wav.writeUInt32LE(36 + N * 4, 4); wav.write("WAVEfmt ", 8); wav.writeUInt32LE(16, 16);
wav.writeUInt16LE(1, 20); wav.writeUInt16LE(2, 22); wav.writeUInt32LE(SR, 24); wav.writeUInt32LE(SR * 4, 28);
wav.writeUInt16LE(4, 32); wav.writeUInt16LE(16, 34); wav.write("data", 36); wav.writeUInt32LE(N * 4, 40);
for (let i = 0; i < N; i++) {
  const f = Math.min(1, (N - i) / (SR * 0.05));
  wav.writeInt16LE(Math.round(Math.max(-1, Math.min(1, L[i] * f)) * 32767), 44 + i * 4);
  wav.writeInt16LE(Math.round(Math.max(-1, Math.min(1, R[i] * f)) * 32767), 46 + i * 4);
}
const wavFile = path.join(TMP, "Alert.wav");
fs.writeFileSync(wavFile, wav);
execFileSync("ffmpeg", ["-y", "-loglevel", "error", "-i", wavFile, "-af", "acompressor=threshold=-20dB:ratio=4:attack=3:release=150:makeup=2,loudnorm=I=-9:TP=-0.5:LRA=7", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "6", path.join(OUT, "Alert.ogg")]);
console.log("ok: GlowOct.tga, GlowSq.tga, Alert.ogg");
