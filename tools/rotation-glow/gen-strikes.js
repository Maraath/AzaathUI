// Conceitos novos para Golpe Heroico e Executar (pedido do usuário em 24/11: "completamente novos").
// Técnica mais orgânica que a de gen-sfx.js: impactos feitos de RUÍDO em filtro ressonante que desce
// (em vez de senoide caindo), metal com dezenas de modos de vibração aleatórios excitados por ruído
// (em vez de 4-5 parciais limpos), estalos de fogo/madeira por impulsos aleatórios.
//
//   Golpe Heroico
//     A  LaminaHeroica   corte limpo e brilhante: lâmina rápida + choque de aço realista + estalo de ar
//     B  ForcaBruta      sem lâmina: deslocamento de ar + soco grave de pressão + madeira/escudo
//     C  LaminaEmBrasa   arma em brasa: assobio com faíscas + chiado de fogo + estalos no impacto
//   Executar
//     A  GolpeFinal      cinematográfico: puxada curta + impacto enorme + estalo + aço grave + cauda
//     B  Cutelo          seco e brutal: talho de cutelo em carne e osso, quase sem eco
//     C  Sentenca        sombrio: impacto + grave distorcido descendo + sino escuro em trítono
//
// Saída de PRÉVIA: tools/rotation-glow/preview/strikes/*.ogg, todas no mesmo volume (comparação justa).
// Conceitos escolhidos vão também para o jogo, mais altos (GAME abaixo):
//   Executar A "Golpe final" -> SfxHeroicStrike.ogg (Golpe Heroico)
//   Executar C "Sentença"    -> SfxExecute.ogg      (Executar)
// Os 6 são sempre gerados na mesma ordem: as partes aleatórias (modos de metal, estalos) saem idênticas.
// Uso: node tools/rotation-glow/gen-strikes.js   (precisa do ffmpeg)
"use strict";
const path = require("path");
const L = require("./gen-sfx.js");
const { SR, rnd, noise, buf, layer, biquad, setF, run, filt, place, finish, reverb, whoosh, cracks, flesh, riser } = L;

const DIR = path.join(__dirname, "preview", "strikes");
const HIT = 0.1;

// soco de ruído: passa-baixa ressonante descendo de f0 a f1 (um "tum" com textura, não um seno)
function resoPunch(sec, { f0 = 800, f1 = 70, sweep = 0.03, q = 5, decay = 0.1 }) {
  const y = layer(sec), lp = biquad(), lp2 = biquad();
  for (let i = 0; i < y.length; i++) {
    const t = i / SR, f = f1 + (f0 - f1) * Math.exp(-t / sweep);
    if (i % 8 === 0) { setF(lp, "lp", f, q); setF(lp2, "lp", f * 1.5, 0.7); }
    y[i] = run(lp2, run(lp, noise())) * Math.exp(-t / decay) * Math.min(1, t / 0.0008);
  }
  return y;
}

// estalo de ar: rajada larga e curtíssima acima de "hp" Hz
function airBurst(sec, { hp = 1500, decay = 0.025 }) {
  const y = layer(sec), f1 = filt("hp", hp, 0.7);
  for (let i = 0; i < y.length; i++) y[i] = run(f1, noise()) * Math.exp(-i / (SR * decay));
  return y;
}

// corpo vibrando (metal, madeira, sino): muitos ressonadores estreitos excitados por um ruído curto.
// modes: [{f, decay, a}] ou gerados em aglomerados aleatórios entre fLo e fHi
function modal(sec, { modes, n = 24, fLo = 1500, fHi = 7000, dLo = 0.05, dHi = 0.3, excite = 0.004 }) {
  const y = layer(sec);
  const list = modes || Array.from({ length: n }, () => ({
    f: fLo * Math.pow(fHi / fLo, rnd()), decay: dLo + (dHi - dLo) * Math.pow(rnd(), 2), a: 0.3 + rnd() * 0.7 }));
  const ex = new Float32Array(Math.round(SR * excite * 6));
  for (let i = 0; i < ex.length; i++) ex[i] = noise() * Math.exp(-i / (SR * excite));
  for (const m of list) {
    const q = Math.max(2, Math.PI * m.f * m.decay * 0.5), bp = filt("bp", m.f, q), g = m.a * Math.sqrt(q);
    for (let i = 0; i < y.length; i++) {
      const v = run(bp, i < ex.length ? ex[i] : 0);
      y[i] += v * g;
      if (i > ex.length && i > SR * m.decay * 7) break;
    }
  }
  return y;
}

// faíscas/brasa: impulsos aleatórios curtos (2-6 kHz), densidade "rate" por segundo
function crackle(sec, { rate = 120, fLo = 2000, fHi = 6000, decay = 0.0015, env = () => 1 }) {
  const y = layer(sec);
  let t = 0;
  while (t < sec) {
    t += -Math.log(1 - rnd()) / rate;
    const i0 = Math.floor(t * SR), fl = filt("bp", fLo * Math.pow(fHi / fLo, rnd()), 4), a = (0.2 + rnd() * 0.8) * env(t / sec);
    for (let i = 0; i < SR * decay * 6 && i0 + i < y.length; i++) y[i0 + i] += run(fl, noise()) * a * Math.exp(-i / (SR * decay));
  }
  return y;
}

// chiado: ruído agudo com envelope (fogo/vapor)
function hiss(sec, { hp = 3000, attack = 0.005, decay = 0.2 }) {
  const y = layer(sec), f1 = filt("hp", hp, 0.7), f2 = filt("lp", 11000, 0.7);
  let wob = 0;
  for (let i = 0; i < y.length; i++) {
    const t = i / SR;
    wob += (noise() - wob) * 0.002;
    y[i] = run(f2, run(f1, noise())) * Math.min(1, t / attack) * Math.exp(-t / decay) * (0.7 + 0.6 * wob);
  }
  return y;
}

// grave distorcido descendo (serra filtrada, saturada): "bwaam" sombrio
function subDrop(sec, { f0 = 110, f1 = 34, cut = 500, drive = 3 }) {
  const y = layer(sec), n = y.length, lp = filt("lp", cut, 1.2);
  let ph = 0;
  for (let i = 0; i < n; i++) {
    const u = i / n, f = f0 * Math.pow(f1 / f0, Math.pow(u, 0.6));
    ph = (ph + f / SR) % 1;
    y[i] = Math.tanh(run(lp, 2 * ph - 1) * drive) * Math.min(1, i / (SR * 0.004)) * Math.pow(1 - u, 1.4);
  }
  return y;
}

// subida invertida curta (antecipação): ruído escurecido crescendo até o impacto
function suck(sec, { fA = 400, fB = 2600 }) {
  const y = riser(sec, { fA, fB });
  for (let i = 0; i < y.length; i++) y[i] *= Math.pow(i / y.length, 1.5);
  return y;
}

const OPT = { dir: DIR, prefix: "", mono: true };
const GAME_DIR = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Rotation");
// Em uso no jogo: "Golpe final" (Executar A) -> SfxSlam (Batida), pedido do usuário em 24/11.
// (Golpe Heroico e Executar passaram a usar sons do usuário, em prep-user-sfx.js.)
const GAME = {
  Executar_A_GolpeFinal: { name: "Slam", peak50: -3 },
};
// grava a prévia e, se o conceito foi escolhido, uma cópia mais alta na pasta do jogo
function out(b, name, opts) {
  const g = GAME[name];
  if (g) {
    const c = { n: b.n, L: Float32Array.from(b.L), R: Float32Array.from(b.R) };
    finish(c, g.name, { ...opts, dir: GAME_DIR, prefix: "Sfx", peak50: g.peak50 });
  }
  finish(b, name, opts);
}

// ================================================================ Golpe Heroico
{ // A: lâmina heroica
  const b = buf(0.9);
  place(b, whoosh(0.1, { fA: 1200, fPeak: 6000, fB: 4000, q: 1.6, peakAt: 0.9, sub: 0.2 }), HIT - 0.095, -7);
  place(b, resoPunch(0.3, { f0: 1200, f1: 130, sweep: 0.015, q: 4, decay: 0.06 }), HIT, 0);
  place(b, modal(0.75, { n: 26, fLo: 1800, fHi: 7500, dLo: 0.04, dHi: 0.22 }), HIT + 0.002, -8, 0.1);
  place(b, airBurst(0.15, { hp: 2500, decay: 0.012 }), HIT, -5);
  reverb(b, { room: 0.55, damp: 0.45, wet: 0.1, width: 0.3, predelay: 0.006 });
  out(b, "GolpeHeroico_A_LaminaHeroica", { ...OPT, peak50: -8.5, drive: 5 });
}
{ // B: força bruta
  const b = buf(0.9);
  place(b, whoosh(0.14, { fA: 250, fPeak: 1300, fB: 600, q: 0.9, peakAt: 0.85, sub: 0.9 }), HIT - 0.13, -6);
  place(b, resoPunch(0.45, { f0: 700, f1: 55, sweep: 0.03, q: 7, decay: 0.11 }), HIT, 0);
  place(b, modal(0.4, { modes: [{ f: 165, decay: 0.07, a: 1 }, { f: 310, decay: 0.05, a: 0.8 }, { f: 520, decay: 0.04, a: 0.6 }, { f: 890, decay: 0.03, a: 0.4 }] }), HIT, -7);
  place(b, airBurst(0.2, { hp: 700, decay: 0.04 }), HIT, -8);
  reverb(b, { room: 0.62, damp: 0.5, wet: 0.13, width: 0.3, predelay: 0.008 });
  out(b, "GolpeHeroico_B_ForcaBruta", { ...OPT, peak50: -8.5, drive: 5 });
}
{ // C: lâmina em brasa
  const b = buf(1.1);
  place(b, whoosh(0.12, { fA: 600, fPeak: 3500, fB: 2500, q: 1.2, peakAt: 0.9, sub: 0.4 }), HIT - 0.115, -8);
  place(b, crackle(0.14, { rate: 260, env: (u) => u }), HIT - 0.12, -16);
  place(b, resoPunch(0.3, { f0: 900, f1: 100, sweep: 0.02, q: 4, decay: 0.07 }), HIT, -1);
  place(b, hiss(0.9, { hp: 2800, attack: 0.004, decay: 0.18 }), HIT, -6);
  place(b, crackle(0.6, { rate: 180, env: (u) => Math.pow(1 - u, 2) }), HIT, -9);
  place(b, resoPunch(0.4, { f0: 300, f1: 80, sweep: 0.08, q: 1.5, decay: 0.12 }), HIT + 0.01, -7);
  reverb(b, { room: 0.6, damp: 0.5, wet: 0.12, width: 0.3, predelay: 0.006 });
  out(b, "GolpeHeroico_C_LaminaEmBrasa", { ...OPT, peak50: -8.5, drive: 5 });
}

// ================================================================ Executar
{ // A: golpe final cinematográfico
  const b = buf(1.8);
  place(b, suck(0.14, { fA: 350, fB: 2200 }), HIT - 0.14, -11);
  place(b, resoPunch(0.8, { f0: 600, f1: 42, sweep: 0.05, q: 6, decay: 0.2 }), HIT, 0);
  place(b, cracks(0.15, { count: 4, spread: 0.02, f: 2200, q: 2.5, decay: 0.005 }), HIT, -5);
  place(b, airBurst(0.2, { hp: 1200, decay: 0.03 }), HIT, -4);
  place(b, modal(1.0, { n: 22, fLo: 900, fHi: 3500, dLo: 0.08, dHi: 0.35 }), HIT + 0.003, -12, -0.1);
  place(b, resoPunch(1.4, { f0: 160, f1: 45, sweep: 0.2, q: 3, decay: 0.45 }), HIT + 0.01, -6);
  reverb(b, { room: 0.82, damp: 0.5, wet: 0.2, width: 0.4, predelay: 0.012 });
  out(b, "Executar_A_GolpeFinal", { ...OPT, peak50: -8.5, drive: 5 });
}
{ // B: cutelo (seco e brutal)
  const b = buf(0.7);
  place(b, whoosh(0.08, { fA: 700, fPeak: 2800, fB: 2000, q: 1.3, peakAt: 0.92, sub: 0.5 }), HIT - 0.075, -10);
  place(b, airBurst(0.08, { hp: 900, decay: 0.008 }), HIT, 0);
  place(b, modal(0.3, { modes: [{ f: 190, decay: 0.045, a: 1 }, { f: 430, decay: 0.035, a: 0.9 }, { f: 960, decay: 0.025, a: 0.6 }, { f: 1750, decay: 0.018, a: 0.4 }] }), HIT, -3);
  place(b, resoPunch(0.25, { f0: 900, f1: 90, sweep: 0.012, q: 3, decay: 0.045 }), HIT, -2);
  place(b, flesh(0.15, { fA: 650, fB: 250, decay: 0.04, drive: 3 }), HIT + 0.003, -7);
  place(b, cracks(0.1, { count: 3, spread: 0.012, f: 2600, q: 3, decay: 0.004 }), HIT + 0.002, -7);
  reverb(b, { room: 0.4, damp: 0.6, wet: 0.04, width: 0.2, predelay: 0.004 });
  out(b, "Executar_B_Cutelo", { ...OPT, peak50: -8.5, drive: 5 });
}
{ // C: sentença sombria
  const b = buf(2.0);
  place(b, whoosh(0.13, { fA: 300, fPeak: 1400, fB: 700, q: 1, peakAt: 0.88, sub: 0.8 }), HIT - 0.12, -9);
  place(b, resoPunch(0.6, { f0: 650, f1: 48, sweep: 0.04, q: 6, decay: 0.15 }), HIT, 0);
  place(b, subDrop(0.9, { f0: 120, f1: 32, cut: 450, drive: 3.5 }), HIT + 0.005, -4);
  place(b, cracks(0.12, { count: 3, spread: 0.02, f: 2000, q: 2.5, decay: 0.005 }), HIT, -8);
  const T = 196; // sino escuro: Sol + Dó# (trítono), parciais inarmônicos
  place(b, modal(1.6, { modes: [1, 2.32, 3.1, 4.2].flatMap((r, k) => [
    { f: T * r, decay: 1.1 / (k + 1), a: 1 / (k + 1) }, { f: T * Math.SQRT2 * r, decay: 0.9 / (k + 1), a: 0.8 / (k + 1) }]), excite: 0.002 }), HIT + 0.01, -11, 0.1);
  reverb(b, { room: 0.88, damp: 0.6, wet: 0.25, width: 0.5, predelay: 0.015 });
  out(b, "Executar_C_Sentenca", { ...OPT, peak50: -8.5, drive: 5 });
}
