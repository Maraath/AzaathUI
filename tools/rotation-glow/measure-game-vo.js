// Mede as falas de personagem do próprio cliente (referência para tratar as vozes do usuário):
// VocalUISounds (FID 1343609) -> kits de som -> SoundKitEntry (FID 1237435) -> arquivos .ogg.
// Extrai para preview/gamevo e imprime formato, volume (LUFS) e o perfil de voice-profile.js
// (cole o resultado em GAME, lá, se o jogo mudar).
// Uso: node tools/rotation-glow/measure-game-vo.js [quantos=100]   (precisa do ffmpeg)
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync, spawnSync } = require("child_process");
const { openCasc } = require("../map-extract/extract.js");
const { parseWDC5 } = require("../map-extract/db2.js");
const { analyze, BANDS } = require("./voice-profile.js");

const OUT = path.join(__dirname, "preview", "gamevo");
const HOW_MANY = Number(process.argv[2]) || 100;
fs.mkdirSync(OUT, { recursive: true });

(async () => {
  const casc = await openCasc();
  const ske = parseWDC5(casc.readFid(1237435));
  const kitFiles = {};
  for (const r of ske.rows) (kitFiles[r.ref] ||= []).push(r.vals[1]);
  const vu = parseWDC5(casc.readFid(1343609));
  const fids = new Set();
  for (const r of vu.rows) for (const v of r.vals.flat()) for (const f of kitFiles[v] || []) fids.add(f);
  const files = [];
  for (const fid of fids) {
    const b = casc.readFid(fid);
    if (!b || b.toString("latin1", 0, 4) !== "OggS") continue;
    const f = path.join(OUT, fid + ".ogg");
    fs.writeFileSync(f, b);
    files.push(f);
  }
  const pick = files.filter((_, i) => i % Math.max(1, Math.floor(files.length / HOW_MANY)) === 0).slice(0, HOW_MANY);
  const lufs = [], sr = {}, res = [];
  for (const f of pick) {
    const p = execFileSync("ffprobe", ["-v", "error", "-show_entries", "stream=sample_rate,channels", "-of", "csv=p=0", f]).toString().trim();
    sr[p] = (sr[p] || 0) + 1;
    const raw = execFileSync("ffmpeg", ["-loglevel", "error", "-i", f, "-ac", "1", "-ar", "22050", "-f", "f32le", "-"], { maxBuffer: 1 << 28 });
    const x = new Float32Array(raw.length / 4);
    for (let i = 0; i < x.length; i++) x[i] = raw.readFloatLE(i * 4);
    const a = analyze(x, 22050);
    if (a && a.bands.every(Number.isFinite)) res.push(a);
    const e = spawnSync("ffmpeg", ["-hide_banner", "-nostats", "-i", f, "-af", "ebur128", "-f", "null", "-"]).stderr.toString();
    const mm = e.match(/I:\s+(-?[\d.]+) LUFS\s*\n\s*Threshold/);
    if (mm && Number(mm[1]) > -60) lufs.push(Number(mm[1]));
  }
  lufs.sort((a, b) => a - b);
  const bands = BANDS.map((_, i) => res.reduce((s, r) => s + r.bands[i], 0) / res.length);
  const crest = res.map((r) => r.crest).sort((a, b) => a - b);
  console.log("arquivos de voz no cliente:", files.length, "| medidos:", pick.length);
  console.log("formato (taxa,canais):", sr);
  console.log("LUFS: p25", lufs[Math.floor(lufs.length * 0.25)], "mediana", lufs[Math.floor(lufs.length / 2)], "p75", lufs[Math.floor(lufs.length * 0.75)]);
  console.log("GAME = { bands: [" + bands.map((b) => b.toFixed(1)).join(", ") + "], crest: " + crest[Math.floor(crest.length / 2)].toFixed(1) + " }");
})().catch((e) => { console.error(e); process.exit(1); });
