// Efeitos escolhidos pelo usuário (24/11), arquivos dele em tools/rotation-glow/source/sfx/:
//   sugjulgar.ogg                         -> SfxOverpower.ogg    (Subjugar)
//   golpe heroico.ogg                     -> SfxHeroicStrike.ogg (Golpe Heroico, toca no acerto)
//   cast executar.ogg + impacto executar.ogg -> SfxExecute.ogg   (Executar: cast e, no fim dele, o impacto)
//   brado de batalha.ogg                  -> SfxBattleShout.ogg  (Brado de Batalha)
//   bardo intimidador.ogg                 -> SfxIntimidating.ogg (Brado Intimidador)
// Os brados são sons sustentados que já vinham sem estouro: só o limitador segura o pico, sem saturação.
// Tratamento mínimo para não mudar o som escolhido: corta só o silêncio real do começo (abaixo de -40 dB
// do pico), contém os picos (os originais passam de 0 dBFS: +1,3 a +2,2 dBTP; no jogo isso estouraria) com
// saturação suave só no topo (DRIVE) + limitador, ficando a ~1 dB do volume original (trecho de 50 ms mais
// forte; já é o nível dos outros efeitos). Só limitador não dá: nesses impactos ruidosos ele trava em -9 dB.
// Uso: node tools/rotation-glow/prep-user-sfx.js   (precisa do ffmpeg). Depois: tools/Sync-Jogo.ps1
"use strict";
const path = require("path");
const { execFileSync } = require("child_process");
const { SR, buf, finish } = require("./gen-sfx.js");

const SRC = path.join(__dirname, "source", "sfx");
const GAME_DIR = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Rotation");

function load(file) {
  const raw = execFileSync("ffmpeg", ["-loglevel", "error", "-i", path.join(SRC, file), "-ac", "1", "-ar", String(SR), "-f", "f32le", "-"], { maxBuffer: 1 << 28 });
  const x = new Float32Array(raw.length / 4);
  for (let i = 0; i < x.length; i++) x[i] = raw.readFloatLE(i * 4);
  return x;
}

// níveis em quadros de 10 ms (dB)
const FR = Math.round(SR * 0.01);
function levels(x) {
  const out = [];
  for (let f = 0; (f + 1) * FR <= x.length; f++) {
    let e = 0;
    for (let i = f * FR; i < (f + 1) * FR; i++) e += x[i] * x[i];
    out.push(10 * Math.log10(e / FR + 1e-12));
  }
  return out;
}

// corta o silêncio real do começo (deixa 5 ms antes do 1º quadro a menos de 40 dB do pico)
function trimStart(x) {
  const lev = levels(x), pk = Math.max(...lev);
  let on = 0;
  while (on < lev.length && lev[on] < pk - 40) on++;
  const s0 = Math.max(0, on * FR - Math.round(SR * 0.005));
  return { y: x.subarray(s0), cut: s0 / SR };
}

// trecho de 50 ms mais forte (dB RMS): o volume original que o tratamento preserva
function rms50(x) {
  const W = Math.round(SR * 0.05);
  let acc = 0, best = 0;
  for (let i = 0; i < x.length; i++) {
    acc += x[i] * x[i];
    if (i >= W) acc -= x[i - W] * x[i - W];
    if (i >= W - 1 && acc > best) best = acc;
  }
  return 10 * Math.log10(best / W + 1e-12);
}

function toBuf(x) {
  const b = buf(x.length / SR);
  for (let i = 0; i < x.length && i < b.n; i++) { b.L[i] = x[i]; b.R[i] = x[i]; }
  return b;
}

const DRIVE = 1.4;
const OPT = { dir: GAME_DIR, prefix: "Sfx", mono: true, drive: DRIVE };

// [arquivo, nome no jogo, saturação, quanto abaixo do volume original pode ficar (dB)]
for (const [file, name, drive, below] of [
  ["sugjulgar.ogg", "Overpower", DRIVE, 1],
  ["golpe heroico.ogg", "HeroicStrike", DRIVE, 1],
  ["brado de batalha.ogg", "BattleShout", 0, 0],
  ["bardo intimidador.ogg", "Intimidating", 0, 0],
]) {
  const { y, cut } = trimStart(load(file));
  console.log(`${file}: cortado ${(cut * 1000).toFixed(0)} ms de silêncio do começo, volume original ${rms50(y).toFixed(1)} dB`);
  finish(toBuf(y), name, { ...OPT, drive, peak50: rms50(y) - below });
}

// Executar encaixado na animação (24/11: a versão com o cast inteiro tinha 2,4 s e a cauda tocava depois
// da morte do alvo). O som sai no envio do golpe; o acerto da animação de golpe instantâneo vem ~0,3 s depois.
//   HIT_AT    impacto entra aqui; o cast (subida + pico, que ficam nos primeiros ~0,35 s) se funde nele
//   TAIL      quanto do impacto soa depois do acerto antes de sumir (FADE de saída)
const EXECUTE = { HIT_AT: 0.32, CAST_FADE: 0.12, TAIL: 0.55, FADE: 0.2 };

{ // Executar: começo do cast -> impacto em HIT_AT -> cauda curta
  const cast = trimStart(load("cast executar.ogg")).y, hit = trimStart(load("impacto executar.ogg")).y;
  const at = Math.round(EXECUTE.HIT_AT * SR), cf = Math.round(EXECUTE.CAST_FADE * SR);
  const end = at + Math.round((EXECUTE.TAIL + EXECUTE.FADE) * SR), fadeFrom = at + Math.round(EXECUTE.TAIL * SR);
  const mix = new Float32Array(end);
  for (let i = 0; i < Math.min(cast.length, at + cf); i++) {
    const g = i < at - cf / 3 ? 1 : 0.5 + 0.5 * Math.cos(Math.PI * Math.min(1, (i - (at - cf / 3)) / cf)); // cast some no impacto
    mix[i] = cast[i] * g;
  }
  for (let i = 0; at + i < end && i < hit.length; i++) {
    const j = at + i, g = j < fadeFrom ? 1 : 0.5 + 0.5 * Math.cos(Math.PI * (j - fadeFrom) / (end - fadeFrom));
    mix[j] += hit[i] * g;
  }
  console.log(`executar: impacto entra em ${(at / SR).toFixed(2)} s, total ${(mix.length / SR).toFixed(2)} s`);
  console.log(`executar: volume original ${rms50(mix).toFixed(1)} dB`);
  finish(toBuf(mix), "Execute", { ...OPT, peak50: rms50(mix) - 1 });
}
