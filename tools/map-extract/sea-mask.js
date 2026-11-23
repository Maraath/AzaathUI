// Mar de papel (mapa "Expedição"): a arte do mar fica POR BAIXO do terreno e o terreno fica transparente
// sobre o mar aberto, com a costa tirada da própria imagem do minimapa (casa pixel a pixel com o chão).
// Lagos e rios (água que não chega ao mar aberto por um canal largo) continuam água azul-marinho.
//
//   node tools/map-extract/sea-mask.js          -> Media/MapLand, Media/MapLake, Media/MapTerrainS, Data/Map/MinimapSea.lua
//   node tools/map-extract/sea-mask.js preview  -> só out/sea-class-<inst>.png (mar x lago), sem gravar texturas
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");
const X = require("./extract.js");
const { makeImage, readBLP, writeBLP, writePNG } = require("./imagecodec.js");

const ROOT = X.ROOT, WOW = X.WOW;
const PREVIEW = process.argv.includes("preview");
const G = 64;                 // pixels por quadro na grade de classificação (8,3 jardas por pixel)
const ERODE = 3;              // canais mais estreitos que ~2*3+1 px (~58 jardas) não ligam lago ao mar
const MEDIA = (sub) => [path.join(ROOT, "AzaathUI/Media", sub), path.join(WOW, "_forever_/Interface/AddOns/AzaathUI/Media", sub)];
const DATA = [path.join(ROOT, "AzaathUI/Data/Map"), path.join(WOW, "_forever_/Interface/AddOns/AzaathUI/Data/Map")];
const OUTP = path.join(ROOT, "tools/map-extract/out");
fs.mkdirSync(OUTP, { recursive: true });

function cleanDir(dirs) {
  for (const d of dirs) {
    try { fs.mkdirSync(d, { recursive: true }); for (const f of fs.readdirSync(d)) if (f.endsWith(".blp")) fs.unlinkSync(path.join(d, f)); }
    catch (e) { console.warn("  AVISO:", d, e.message); }
  }
}
function writeAll(dirs, name, img, opts) {
  for (const d of dirs) { try { writeBLP(path.join(d, name), img, opts); } catch (e) { console.warn("  AVISO:", d, e.message); } }
}

// média por caixa de um mapa de alfa (w x w) para size x size
function boxDown(a, w, size) {
  const f = w / size, out = new Float32Array(size * size);
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    let s = 0;
    for (let sy = 0; sy < f; sy++) for (let sx = 0; sx < f; sx++) s += a[(y * f + sy) * w + x * f + sx];
    out[y * size + x] = s / (f * f);
  }
  return out;
}

// soma em janela (2r+1)^2 numa grade binária (para erosão/dilatação)
function boxCount(src, w, h, r) {
  const tmp = new Int32Array(w * h), out = new Int32Array(w * h);
  for (let y = 0; y < h; y++) { let s = 0;
    for (let x = -r; x < w; x++) { if (x + r < w) s += src[y * w + x + r]; if (x - r - 1 >= 0) s -= src[y * w + x - r - 1]; if (x >= 0) tmp[y * w + x] = s; } }
  for (let x = 0; x < w; x++) { let s = 0;
    for (let y = -r; y < h; y++) { if (y + r < h) s += tmp[(y + r) * w + x]; if (y - r - 1 >= 0) s -= tmp[(y - r - 1) * w + x]; if (y >= 0) out[y * w + x] = s; } }
  return out;
}

(async () => {
  const casc = await X.openCasc();
  if (!PREVIEW) { cleanDir(MEDIA("MapLand")); cleanDir(MEDIA("MapLake")); cleanDir(MEDIA("MapTerrainS")); }
  const tmp = path.join(os.tmpdir(), "azaath_seamask.blp");
  const lines = ["-- Mar de papel: quadros do minimapa que tocam o mar aberto e os lagos/rios.",
    "-- GERADO por tools/map-extract/sea-mask.js (build " + casc.build + "). Não edite à mão.", "",
    "local _, Azaath = ...", "Azaath.MapData = Azaath.MapData or {}", "",
    "-- Sea[instância][chave] = 1: costa, Media/MapLand/<instância>_<chave>.blp recorta o mar do quadro (alfa = terra);",
    "-- 2: quadro só de mar (não é desenhado: a arte do mar fica à vista por baixo).",
    "-- Lake[instância][chave] = 1: Media/MapLake/<instância>_<chave>.blp, a água dos lagos e rios por cima do quadro.",
    "-- As cópias de longe ficam em Media/MapTerrainS (mesmos nomes de MapTerrain, mar transparente)."];
  const seaLines = ["Azaath.MapData.MinimapSea = {"], lakeLines = ["Azaath.MapData.MinimapLake = {"];

  for (const { inst, wdt } of X.CONTINENTS) {
    const tiles = X.dropStrayIslands(X.readMinimapTiles(casc, wdt));
    const keys = [...tiles.keys()].sort((a, b) => a - b);
    console.log("instância", inst, "-", keys.length, "quadros");
    // 1) água de cada quadro: 256 px (camadas) e 64 px (grade), e a cópia pequena de cor
    const a256 = new Map(), small = new Map();
    const N = 64 * G, grid = new Uint8Array(N * N).fill(1);     // 1 = água; sem quadro = mar aberto
    let done = 0;
    for (const k of keys) {
      const buf = casc.readFid(tiles.get(k));
      if (!buf) continue;
      fs.writeFileSync(tmp, buf);
      let img;
      try { img = readBLP(tmp); } catch (e) { console.warn("  quadro ilegível", tiles.get(k)); continue; }
      const a = X.waterAlpha(img, k, tiles);
      const q = boxDown(a, img.w, 256);
      a256.set(k, q);
      const g = boxDown(q, 256, G), c = k % 64, r = Math.floor(k / 64);
      for (let y = 0; y < G; y++) for (let x = 0; x < G; x++) grid[(r * G + y) * N + c * G + x] = g[y * G + x] >= 0.5 ? 1 : 0;
      small.set(k, PREVIEW ? null : X.shrink(img, 64));
      if (++done % 300 === 0) console.log("  lidos", done, "/", keys.length);
    }
    // 2) mar aberto: inunda a partir da borda pela água "larga" (erodida), depois devolve a margem erodida
    // (fora da grade também é mar: a janela conta só as casas dentro dela)
    const cnt = boxCount(grid, N, N, ERODE);
    const wide = new Uint8Array(N * N);
    for (let y = 0; y < N; y++) {
      const hy = Math.min(N - 1, y + ERODE) - Math.max(0, y - ERODE) + 1;
      for (let x = 0; x < N; x++) {
        const hx = Math.min(N - 1, x + ERODE) - Math.max(0, x - ERODE) + 1;
        wide[y * N + x] = cnt[y * N + x] === hx * hy ? 1 : 0;
      }
    }
    const sea = new Uint8Array(N * N), st = [];
    for (let i = 0; i < N; i++) for (const j of [i, (N - 1) * N + i, i * N, i * N + N - 1]) if (wide[j] && !sea[j]) { sea[j] = 1; st.push(j); }
    while (st.length) {
      const i = st.pop(), x = i % N, y = (i / N) | 0;
      if (x > 0 && wide[i - 1] && !sea[i - 1]) { sea[i - 1] = 1; st.push(i - 1); }
      if (x < N - 1 && wide[i + 1] && !sea[i + 1]) { sea[i + 1] = 1; st.push(i + 1); }
      if (y > 0 && wide[i - N] && !sea[i - N]) { sea[i - N] = 1; st.push(i - N); }
      if (y < N - 1 && wide[i + N] && !sea[i + N]) { sea[i + N] = 1; st.push(i + N); }
    }
    // devolve a margem: a partir do mar largo, anda pela água (sem erosão) até REACH px — enseadas e bocas
    // de rio viram mar; lagos ligados por rio comprido continuam lago
    const REACH = 8;
    const dist = new Uint8Array(N * N).fill(255), q = [];
    for (let i = 0; i < N * N; i++) if (sea[i]) { dist[i] = 0; q.push(i); }
    for (let h = 0; h < q.length; h++) {
      const i = q[h], d = dist[i] + 1; if (d > REACH) continue;
      const x = i % N;
      for (const j of [x > 0 ? i - 1 : -1, x < N - 1 ? i + 1 : -1, i - N, i + N]) {
        if (j < 0 || j >= N * N || !grid[j] || dist[j] <= d) continue;
        dist[j] = d; q.push(j);
      }
    }
    const isSea = new Uint8Array(N * N);
    for (let i = 0; i < N * N; i++) isSea[i] = grid[i] && dist[i] !== 255 ? 1 : 0;

    // conferência: terra cinza, mar claro, lago azul
    {
      const S = 1024, f = N / S, im = makeImage(S, S);
      for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
        let w = 0, s = 0;
        for (let sy = 0; sy < f; sy++) for (let sx = 0; sx < f; sx++) { const i = (y * f + sy) * N + x * f + sx; w += grid[i]; s += isSea[i]; }
        const d = (y * S + x) * 4, n = f * f, lake = (w - s) / n, sea_ = s / n, land = 1 - w / n;
        im.data[d] = 70 * land + 225 * sea_ + 30 * lake; im.data[d + 1] = 70 * land + 205 * sea_ + 70 * lake; im.data[d + 2] = 70 * land + 160 * sea_ + 200 * lake; im.data[d + 3] = 255;
      }
      writePNG(path.join(OUTP, "sea-class-" + inst + ".png"), im);
    }
    if (PREVIEW) continue;

    // 3) por quadro: máscara de terra (costa), camada de lago, cópia pequena sem o mar
    const seaT = new Map(), lakeT = new Map(), seaA64 = new Map();
    for (const k of keys) {
      const q = a256.get(k);
      if (!q) continue;
      const c = k % 64, r = Math.floor(k / 64);
      const sA = new Float32Array(256 * 256), lA = new Float32Array(256 * 256);
      let ss = 0, ls = 0;
      for (let y = 0; y < 256; y++) for (let x = 0; x < 256; x++) {
        const gi = (r * G + (y >> 2)) * N + c * G + (x >> 2), i = y * 256 + x;
        if (isSea[gi]) { sA[i] = q[i]; ss += q[i]; } else { lA[i] = q[i]; ls += q[i]; }
      }
      const sf = ss / 65536, lf = ls / 65536;
      if (sf > 0.995) seaT.set(k, 2);
      else if (sf > 0.002) {
        seaT.set(k, 1);
        const m = makeImage(256, 256);
        for (let i = 0; i < 65536; i++) { m.data[i * 4] = 255; m.data[i * 4 + 1] = 255; m.data[i * 4 + 2] = 255; m.data[i * 4 + 3] = Math.round((1 - sA[i]) * 255); }
        writeAll(MEDIA("MapLand"), inst + "_" + k + ".blp", m, { alpha: true });
      }
      if (lf > 0.002) {
        lakeT.set(k, 1);
        const m = makeImage(256, 256);
        for (let i = 0; i < 65536; i++) { m.data[i * 4] = X.SEA_RGB[0]; m.data[i * 4 + 1] = X.SEA_RGB[1]; m.data[i * 4 + 2] = X.SEA_RGB[2]; m.data[i * 4 + 3] = Math.round(lA[i] * 255); }
        writeAll(MEDIA("MapLake"), inst + "_" + k + ".blp", m, { alpha: true });
      }
      // cópia pequena (64 px): lago pintado, mar vira alfa
      const s64 = boxDown(sA, 256, 64), l64 = boxDown(lA, 256, 64), im = small.get(k);
      for (let i = 0; i < 64 * 64; i++) {
        for (let ch = 0; ch < 3; ch++) im.data[i * 4 + ch] = Math.round(im.data[i * 4 + ch] * (1 - l64[i]) + X.SEA_RGB[ch] * l64[i]);
        im.data[i * 4 + 3] = Math.round((1 - s64[i]) * 255);
      }
      seaA64.set(k, true);
    }
    // 4) cópias de longe com alfa (o mar e os buracos sem quadro ficam transparentes)
    const lodLines = [];
    for (const n of X.LODS) {
      const px = 256 / n, groups = new Map();
      for (const k of small.keys()) {
        const g = Math.floor(Math.floor(k / 64) / n) * 64 + Math.floor((k % 64) / n);
        if (!groups.has(g)) groups.set(g, []);
        groups.get(g).push(k);
      }
      for (const [g, ks] of groups) {
        const img = makeImage(256, 256);     // tudo transparente
        for (const k of ks) {
          const t = px === 64 ? small.get(k) : X.shrink(small.get(k), px);
          const ox = ((k % 64) % n) * px, oy = (Math.floor(k / 64) % n) * px;
          for (let y = 0; y < px; y++) for (let x = 0; x < px; x++) {
            const s = (y * px + x) * 4, d = ((oy + y) * 256 + ox + x) * 4;
            for (let ch = 0; ch < 4; ch++) img.data[d + ch] = t.data[s + ch];
          }
        }
        writeAll(MEDIA("MapTerrainS"), inst + "_" + n + "_" + (g % 64) + "_" + Math.floor(g / 64) + ".blp", img, { alpha: true });
      }
      console.log("  LOD", n, ":", groups.size, "imagens");
    }
    seaLines.push("\t[" + inst + "] = { " + [...seaT.keys()].sort((a, b) => a - b).map((k) => "[" + k + "] = " + seaT.get(k)).join(", ") + " },");
    lakeLines.push("\t[" + inst + "] = { " + [...lakeT.keys()].sort((a, b) => a - b).map((k) => "[" + k + "] = 1").join(", ") + " },");
    console.log("  costa:", [...seaT.values()].filter((v) => v === 1).length, "| só mar:", [...seaT.values()].filter((v) => v === 2).length, "| lagos:", lakeT.size);
  }
  if (PREVIEW) return;
  const text = [...lines, ...seaLines, "}", "", ...lakeLines, "}", ""].join("\n");
  for (const d of DATA) { try { fs.mkdirSync(d, { recursive: true }); fs.writeFileSync(path.join(d, "MinimapSea.lua"), text); console.log("  gravado", d); } catch (e) { console.warn("  AVISO:", d, e.message); } }
})().catch((e) => { console.error("ERRO:", e.stack || e.message); process.exit(1); });
