// Perfil de voz: energia por oitava (dB em relação ao total) e fator de crista (pico/RMS) dos
// trechos com voz. Usado para casar as gravações do usuário com as vozes do próprio jogo.
//
// GAME = média de 100 falas de personagem do cliente (tabela VocalUISounds -> SoundKitEntry,
// lidas por tools/rotation-glow/measure-game-vo.js). Formato delas: mono, 22050 Hz, Vorbis
// ~64 kbps, -15,5 LUFS (mediana; p25 -18, p75 -13,7), pico perto de 0 dBFS, crista ~14 dB.
"use strict";

const BANDS = [[60, 125], [125, 250], [250, 500], [500, 1000], [1000, 2000], [2000, 4000], [4000, 8000], [8000, 11000]];
const CENTERS = BANDS.map(([a, b]) => Math.round(Math.sqrt(a * b)));
const GAME = { bands: [-22.0, -13.1, -10.0, -10.8, -11.8, -14.1, -17.9, -26.4], crest: 13.9, lufs: -15.5 };

function fft(re, im) {
  const n = re.length;
  for (let i = 1, j = 0; i < n; i++) {
    let b = n >> 1;
    for (; j & b; b >>= 1) j ^= b;
    j ^= b;
    if (i < j) { [re[i], re[j]] = [re[j], re[i]]; [im[i], im[j]] = [im[j], im[i]]; }
  }
  for (let len = 2; len <= n; len <<= 1) {
    const a = -2 * Math.PI / len;
    for (let i = 0; i < n; i += len) for (let k = 0; k < len / 2; k++) {
      const c = Math.cos(a * k), s = Math.sin(a * k), h = i + k + len / 2;
      const vr = re[h] * c - im[h] * s, vi = re[h] * s + im[h] * c;
      re[h] = re[i + k] - vr; im[h] = im[i + k] - vi; re[i + k] += vr; im[i + k] += vi;
    }
  }
}

// x: Float32Array mono; sr: taxa. Só entram quadros a menos de 20 dB do quadro mais forte.
function analyze(x, sr) {
  const N = sr > 30000 ? 2048 : 1024;
  const fr = [];
  for (let i = 0; i + N <= x.length; i += N / 2) { let e = 0; for (let k = 0; k < N; k++) e += x[i + k] * x[i + k]; fr.push([i, e / N]); }
  if (!fr.length) return null;
  const emax = Math.max(...fr.map((f) => f[1]));
  const P = new Float64Array(N / 2);
  let pk = 0, rms = 0, cnt = 0;
  for (const [i, e] of fr) {
    if (e < emax / 100) continue;
    const re = new Float64Array(N), im = new Float64Array(N);
    for (let k = 0; k < N; k++) {
      const v = x[i + k];
      re[k] = v * (0.5 - 0.5 * Math.cos(2 * Math.PI * k / N));
      pk = Math.max(pk, Math.abs(v)); rms += v * v; cnt++;
    }
    fft(re, im);
    for (let k = 0; k < N / 2; k++) P[k] += re[k] * re[k] + im[k] * im[k];
  }
  const bands = BANDS.map(([a, b]) => {
    let s = 0;
    for (let k = Math.ceil(a * N / sr); k < Math.min(N / 2, b * N / sr); k++) s += P[k];
    return s;
  });
  const tot = bands.reduce((a, b) => a + b, 0);
  return { bands: bands.map((b) => 10 * Math.log10(b / tot)), crest: 20 * Math.log10(pk / Math.sqrt(rms / cnt)) };
}

module.exports = { BANDS, CENTERS, GAME, analyze };
