// Extrator do mapa próprio do Azaath: lê as tabelas do cliente instalado (CASC, somente leitura) e
// gera o que o jogo não entrega ao addon em tempo real. Tudo o mais o mapa pede ao jogo (C_Map).
//
//   node tools/map-extract/extract.js            -> gera todas as tabelas
//   node tools/map-extract/extract.js reveal     -> só as partes das zonas (zonas inexploradas)
//
// Rode de novo depois de cada patch do jogo. Os arquivos gerados não devem ser editados à mão.
"use strict";
const fs = require("fs");
const path = require("path");
const { openCasc } = require("./casc.js");
const { parseWDC5 } = require("./db2.js");

const WOW = process.env.WOW_DIR || "C:/Program Files (x86)/World of Warcraft";
const PRODUCT = process.env.WOW_PRODUCT || "wowf";
const ROOT = path.resolve(__dirname, "../..");
const OUT_DIRS = [
  path.join(ROOT, "AzaathUI/Data/Map"),
  path.join(WOW, "_forever_/Interface/AddOns/AzaathUI/Data/Map"),
];

// FileDataIDs das tabelas (DB2 não têm nome no ROOT do cliente)
const DB = {
  WorldMapOverlay: 1134579,     // ID, UiMapArtID, TextureWidth, TextureHeight, OffsetX, OffsetY, HitRect T/B/L/R, PlayerConditionID, Flags, AreaID[4]
  WorldMapOverlayTile: 1957212, // RowIndex, ColIndex, LayerIndex, FileDataID   (pai: WorldMapOverlayID)
};

function header(what, casc) {
  return [
    "-- " + what,
    "-- GERADO por tools/map-extract/extract.js a partir dos arquivos do cliente (build " + casc.build + ").",
    "-- Não edite à mão: rode o extrator de novo (depois de cada patch do jogo).",
    "",
    "local _, Azaath = ...",
    "Azaath.MapData = Azaath.MapData or {}",
  ].join("\n");
}

function write(name, text) {
  for (const dir of OUT_DIRS) {
    try {
      fs.mkdirSync(dir, { recursive: true });
      fs.writeFileSync(path.join(dir, name), text);
      console.log("  gravado", path.join(dir, name), text.length, "bytes");
    } catch (e) {
      console.warn("  AVISO: não gravou em", dir, "-", e.message);
    }
  }
}

// --- Zonas inexploradas ------------------------------------------------------------------------
// Para cada arte de zona (UiMapArtID, o mesmo que C_Map.GetMapArtID devolve no jogo), todas as
// partes que o jogo revela ao explorar: posição e tamanho em pixels da arte (1002 x 668), a
// sub-região (AreaID) e os quadros de 256 px, por linha. O jogo só informa as partes JÁ exploradas
// (C_MapExplorationInfo.GetExploredMapTextures); estas tabelas completam as que faltam.
function buildReveal(casc) {
  const rows = (fid) => parseWDC5(casc.readFid(fid)).rows;
  const overlays = rows(DB.WorldMapOverlay);
  const tiles = new Map();
  for (const t of rows(DB.WorldMapOverlayTile)) {
    const [row, col, layer, fid] = t.vals;
    if (layer !== 0) continue;
    if (!tiles.has(t.ref)) tiles.set(t.ref, []);
    tiles.get(t.ref).push({ row, col, fid });
  }
  const byArt = new Map();
  let pieces = 0, skipped = 0;
  for (const o of overlays) {
    const [, art, w, h, x, y, , , , , , , areas] = o.vals;
    const list = tiles.get(o.id);
    const cols = Math.ceil(w / 256), nrows = Math.ceil(h / 256);
    if (!list || list.length !== cols * nrows) { skipped++; continue; }
    list.sort((a, b) => a.row - b.row || a.col - b.col);
    const area = (Array.isArray(areas) ? areas : [areas]).find((a) => a) || 0;
    if (!byArt.has(art)) byArt.set(art, []);
    byArt.get(art).push({ x, y, w, h, area, fids: list.map((t) => t.fid) });
    pieces++;
  }
  const arts = [...byArt.keys()].sort((a, b) => a - b);
  const out = [header("Partes das zonas para mostrar as áreas inexploradas.", casc), "",
    "-- [UiMapArtID] = { { x, y, w, h, AreaID, quadro1, quadro2, ... }, ... }",
    "-- x, y, w, h: pixels da arte da zona (1002 x 668). Quadros de 256 px, por linha (esquerda->direita, cima->baixo);",
    "-- o último de cada linha/coluna é menor (w % 256), numa imagem de largura potência de 2.",
    "Azaath.MapData.Reveal = {"];
  for (const art of arts) {
    const ps = byArt.get(art).sort((a, b) => a.y - b.y || a.x - b.x);
    out.push("\t[" + art + "] = {");
    for (const p of ps) out.push("\t\t{ " + [p.x, p.y, p.w, p.h, p.area, ...p.fids].join(", ") + " },");
    out.push("\t},");
  }
  out.push("}", "");
  console.log("reveal:", arts.length, "artes de zona,", pieces, "partes (", skipped, "sem quadros, ignoradas )");
  write("Reveal.lua", out.join("\n"));
  return byArt;
}

// --- Terreno do minimapa ----------------------------------------------------------------------
// O WDT de cada continente lista, por quadro de 533,33 jardas (grade 64 x 64), a imagem do minimapa.
// O addon não tem como pedir essa lista ao jogo; ela vai para Data/Map/Minimap.lua e o mapa desenha
// as imagens do PRÓPRIO jogo (por FileDataID). Para a vista de longe (centenas de quadros), o
// extrator monta cópias reduzidas: LOD n = n x n quadros numa imagem de 256 px (Media/MapTerrain).
const CONTINENTS = [
  { inst: 0, wdt: 775971 },   // Reinos do Leste (azeroth.wdt)
  { inst: 1, wdt: 782779 },   // Kalimdor (kalimdor.wdt)
];
const LODS = [4, 16];

// tira grupos pequenos de quadros isolados e longe do resto (ilhas de desenvolvimento do jogo,
// como a do canto de Kalimdor): até 9 quadros, a mais de 10 quadros de qualquer outro grupo
function dropStrayIslands(tiles) {
  const seen = new Set(), groups = [];
  for (const k of tiles.keys()) {
    if (seen.has(k)) continue;
    const g = [], st = [k];
    seen.add(k);
    while (st.length) {
      const q = st.pop();
      g.push(q);
      const c = q % 64, r = Math.floor(q / 64);
      for (let dr = -1; dr <= 1; dr++) for (let dc = -1; dc <= 1; dc++) {
        const nc = c + dc, nr = r + dr, n = nr * 64 + nc;
        if (nc < 0 || nr < 0 || nc > 63 || nr > 63 || seen.has(n) || !tiles.has(n)) continue;
        seen.add(n); st.push(n);
      }
    }
    groups.push(g);
  }
  for (const g of groups) {
    if (g.length > 9) continue;
    let near = Infinity;
    for (const o of groups) {
      if (o === g) continue;
      for (const a of g) for (const b of o) {
        near = Math.min(near, Math.max(Math.abs(a % 64 - b % 64), Math.abs(Math.floor(a / 64) - Math.floor(b / 64))));
      }
    }
    if (near > 10) { for (const q of g) tiles.delete(q); console.log("  ilha isolada removida:", g.length, "quadros"); }
  }
  return tiles;
}

function readMinimapTiles(casc, wdtFid) {
  const b = casc.readFid(wdtFid);
  const tiles = new Map();          // row * 64 + col -> FileDataID
  let o = 0;
  while (o + 8 <= b.length) {
    const id = b.toString("ascii", o, o + 4).split("").reverse().join(""), sz = b.readUInt32LE(o + 4);
    if (id === "MAID") {
      for (let i = 0; i < 4096; i++) {
        const mini = b.readUInt32LE(o + 8 + i * 32 + 28);   // 8º campo: minimapTexture
        if (mini) tiles.set(i, mini);
      }
    }
    o += 8 + sz;
  }
  return tiles;
}

function shrink(img, size) {         // média por caixa até size x size
  const { makeImage } = require("./imagecodec.js");
  const out = makeImage(size, size), f = img.w / size;
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    const acc = [0, 0, 0, 0];
    let n = 0;
    for (let sy = Math.floor(y * f); sy < Math.floor((y + 1) * f); sy++)
      for (let sx = Math.floor(x * f); sx < Math.floor((x + 1) * f); sx++) {
        const s = (sy * img.w + sx) * 4;
        for (let c = 0; c < 4; c++) acc[c] += img.data[s + c];
        n++;
      }
    const d = (y * size + x) * 4;
    for (let c = 0; c < 4; c++) out.data[d + c] = Math.round(acc[c] / n);
  }
  return out;
}

// cor do mar: azul-marinho (pedido do usuário em 2026-11-17)
const SEA_RGB = [22, 44, 78];
// água: o minimapa desenha a água funda quase preta (max(R,G,B) ~7-8) e a costa escurecendo até ela.
// Mistura simples pelo escuro (aprovada pelo usuário na prévia de 2026-11-17): até 18 é água; de 18
// a 34, mistura. Sem filtros de forma (eles deixavam a costa quadrada).
const WATER_DARK = 34, WATER_RAMP = 16;

// quanto de cada pixel é água (0..1). Também cobre as faixas de terreno solto que o jogo deixa na
// borda com o mar aberto (fileira de blocos acima da água, como a leste de Hibérnia): num lado sem
// quadro vizinho, uma faixa clara de até 40 px vira água.
function waterAlpha(img, k, tiles) {
  const w = img.w, h = img.h, a = new Float32Array(w * h);
  for (let i = 0; i < w * h; i++) {
    const m = Math.max(img.data[i * 4], img.data[i * 4 + 1], img.data[i * 4 + 2]);
    a[i] = Math.min(1, Math.max(0, (WATER_DARK - m) / WATER_RAMP));
  }
  const sides = { top: !tiles.has(k - 64), bottom: !tiles.has(k + 64), left: !tiles.has(k - 1), right: !tiles.has(k + 1) };
  const at = (side, i, j) => side === "top" ? j + i * w : side === "bottom" ? j + (h - 1 - i) * w
    : side === "left" ? i + j * w : (w - 1 - i) + j * w;
  for (const [side, open] of Object.entries(sides)) {
    if (!open) continue;
    let band = 0;
    for (let i = 0; i < 48; i++) {
      let lit = 0;
      for (let j = 0; j < w; j += 4) if (a[at(side, i, j)] < 0.5) lit++;
      if (lit > w / 32) band = i + 1; else break;
    }
    if (band > 0 && band <= 40) {
      for (let i = 0; i < band + 2; i++) for (let j = 0; j < w; j++) a[at(side, i, j)] = 1;
    }
  }
  return a;
}

// a cor do mar como o jogo a desenha depois da compressão das imagens (DXT arredonda para 5/6/5 bits):
// o fundo do mapa usa exatamente esta, senão o mar das imagens e o fundo diferem um tom e aparecem
// retângulos em volta dos continentes
function seaAsStored(makeImage, writeBLP, readBLP) {
  const os = require("os"), f = path.join(os.tmpdir(), "azaath_sea.blp");
  const img = makeImage(4, 4);
  for (let i = 0; i < 16; i++) { img.data[i * 4] = SEA_RGB[0]; img.data[i * 4 + 1] = SEA_RGB[1]; img.data[i * 4 + 2] = SEA_RGB[2]; img.data[i * 4 + 3] = 255; }
  writeBLP(f, img, { alpha: false, mips: false });
  const back = readBLP(f);
  return [back.data[0], back.data[1], back.data[2]];
}

// camada de água (size x size): cor do mar, alfa = quanto é água
function waterLayer(w, a, size, makeImage) {
  const out = makeImage(size, size), f = w / size;
  for (let y = 0; y < size; y++) for (let x = 0; x < size; x++) {
    let s = 0;
    for (let sy = 0; sy < f; sy++) for (let sx = 0; sx < f; sx++) s += a[(y * f + sy) * w + x * f + sx];
    const d = (y * size + x) * 4;
    out.data[d] = SEA_RGB[0]; out.data[d + 1] = SEA_RGB[1]; out.data[d + 2] = SEA_RGB[2];
    out.data[d + 3] = Math.round(s / (f * f) * 255);
  }
  return out;
}

function buildMinimap(casc, opts = {}) {
  const os = require("os");
  const { makeImage, readBLP, writeBLP } = require("./imagecodec.js");
  const mediaDirs = [path.join(ROOT, "AzaathUI/Media/MapTerrain"),
    path.join(WOW, "_forever_/Interface/AddOns/AzaathUI/Media/MapTerrain")];
  for (const d of mediaDirs) {
    try { fs.mkdirSync(d, { recursive: true }); for (const f of fs.readdirSync(d)) if (f.endsWith(".blp")) fs.unlinkSync(path.join(d, f)); }
    catch (e) { console.warn("  AVISO:", d, e.message); }
  }
  const tmp = path.join(os.tmpdir(), "azaath_mini.blp");
  const lines = [header("Terreno do minimapa: as imagens do jogo por quadro e as cópias reduzidas para a vista de longe.", casc), "",
    "-- Tiles[instância][linha * 64 + coluna] = FileDataID da imagem do minimapa (512 px, 533,33 jardas).",
    "-- Quadro (coluna c, linha r): canto noroeste no mundo em X = (32 - r) * 533,33 (norte) e Y = (32 - c) * 533,33 (oeste).",
    "-- LOD[instância][n][linhaG * 64 + colunaG] = true: existe Media/MapTerrain/<instância>_<n>_<colunaG>_<linhaG>.blp,",
    "-- n x n quadros (colunas colunaG*n .. +n-1) numa imagem de 256 px.",
    "Azaath.MapData.MinimapTiles = {"];
  const lodLines = ["Azaath.MapData.MinimapLOD = {"];
  const waterLines = ["Azaath.MapData.MinimapWater = {"];
  const waterDirs = [path.join(ROOT, "AzaathUI/Media/MapWater"),
    path.join(WOW, "_forever_/Interface/AddOns/AzaathUI/Media/MapWater")];
  for (const d of waterDirs) {
    try { fs.mkdirSync(d, { recursive: true }); for (const f of fs.readdirSync(d)) if (f.endsWith(".blp")) fs.unlinkSync(path.join(d, f)); }
    catch (e) { console.warn("  AVISO:", d, e.message); }
  }
  for (const { inst, wdt } of CONTINENTS) {
    const tiles = dropStrayIslands(readMinimapTiles(casc, wdt));
    const keys = [...tiles.keys()].sort((a, b) => a - b);
    lines.push("\t[" + inst + "] = {");
    for (let i = 0; i < keys.length; i += 8) lines.push("\t\t" + keys.slice(i, i + 8).map((k) => "[" + k + "] = " + tiles.get(k) + ",").join(" "));
    lines.push("\t},");
    console.log("minimap: instância", inst, "-", keys.length, "quadros");
    if (opts.noLod) continue;
    // água e cópias reduzidas
    const small = new Map();          // chave -> imagem 64 px (base para os LODs)
    const water = new Map();          // chave -> 1 (camada de água) | 2 (só mar: não desenhar)
    let done = 0;
    for (const k of keys) {
      const buf = casc.readFid(tiles.get(k));
      if (!buf) continue;
      fs.writeFileSync(tmp, buf);
      try {
        const img = readBLP(tmp);
        const a = waterAlpha(img, k, tiles);
        let sum = 0;
        for (let i = 0; i < a.length; i++) sum += a[i];
        const frac = sum / a.length;
        if (frac > 0.995) {
          water.set(k, 2);
        } else if (frac > 0.003) {
          water.set(k, 1);
          const layer = waterLayer(img.w, a, 256, makeImage);
          const name = inst + "_" + k + ".blp";
          for (const d of waterDirs) { try { writeBLP(path.join(d, name), layer, { alpha: true }); } catch (e) { /* aviso já dado */ } }
        }
        // a cópia reduzida já sai com a água pintada
        for (let i = 0; i < a.length; i++) {
          if (a[i] > 0) for (let c = 0; c < 3; c++) img.data[i * 4 + c] = Math.round(img.data[i * 4 + c] * (1 - a[i]) + SEA_RGB[c] * a[i]);
        }
        small.set(k, shrink(img, 64));
      } catch (e) { console.warn("  quadro ilegível", tiles.get(k), e.message); }
      if (++done % 200 === 0) console.log("  lidos", done, "/", keys.length);
    }
    waterLines.push("\t[" + inst + "] = { " + [...water.keys()].sort((x, y) => x - y).map((k) => "[" + k + "] = " + water.get(k)).join(", ") + " },");
    console.log("  água:", [...water.values()].filter((v) => v === 1).length, "camadas,", [...water.values()].filter((v) => v === 2).length, "quadros só de mar");
    lodLines.push("\t[" + inst + "] = {");
    for (const n of LODS) {
      const px = 256 / n, groups = new Map();
      for (const k of small.keys()) {
        const g = Math.floor(Math.floor(k / 64) / n) * 64 + Math.floor((k % 64) / n);
        if (!groups.has(g)) groups.set(g, []);
        groups.get(g).push(k);
      }
      for (const [g, ks] of groups) {
        const img = makeImage(256, 256);   // opaca: onde não há quadro, o próprio mar (borda transparente vira linha escura no jogo)
        for (let i = 0; i < 256 * 256; i++) { img.data[i * 4] = SEA_RGB[0]; img.data[i * 4 + 1] = SEA_RGB[1]; img.data[i * 4 + 2] = SEA_RGB[2]; img.data[i * 4 + 3] = 255; }
        for (const k of ks) {
          const t = px === 64 ? small.get(k) : shrink(small.get(k), px);
          const ox = ((k % 64) % n) * px, oy = (Math.floor(k / 64) % n) * px;
          for (let y = 0; y < px; y++) for (let x = 0; x < px; x++) {
            const s = (y * px + x) * 4, d = ((oy + y) * 256 + ox + x) * 4;
            for (let c = 0; c < 4; c++) img.data[d + c] = t.data[s + c];
          }
        }
        const name = inst + "_" + n + "_" + (g % 64) + "_" + Math.floor(g / 64) + ".blp";
        for (const d of mediaDirs) { try { writeBLP(path.join(d, name), img, { alpha: false }); } catch (e) { /* aviso já dado */ } }
      }
      const gk = [...groups.keys()].sort((a, b) => a - b);
      lodLines.push("\t\t[" + n + "] = { " + gk.map((g) => "[" + g + "] = true").join(", ") + " },");
      console.log("  LOD", n, ":", gk.length, "imagens");
    }
    lodLines.push("\t},");
  }
  lines.push("}", "", ...lodLines, "}", "",
    "-- Água: Water[instância][chave] = 1: Media/MapWater/<instância>_<chave>.blp vai por cima da imagem do jogo",
    "-- (a água funda, quase preta no minimapa, no tom do mapa); 2: quadro só de mar, não é desenhado (o fundo é o mar).",
    ...waterLines, "}", "",
    "-- cor do mar (azul-marinho, como o jogo a desenha depois da compressão): fundo, água das camadas e das cópias reduzidas",
    "Azaath.MapData.MinimapSea = { " + seaAsStored(makeImage, writeBLP, readBLP).map((v) => (v / 255).toFixed(5)).join(", ") + " }", "");
  write("Minimap.lua", lines.join("\n"));
}

// --- Nomes: as áreas do terreno -----------------------------------------------------------------
// Cada ADT (quadro de 533,33 jardas) tem 16 x 16 blocos de terreno (33,3 jardas), e cada bloco guarda
// o ID da área (AreaTable) a que pertence. Cada pedaço contínuo de uma área vira um rótulo, posto no
// bloco da área mais perto do centro do pedaço (cai dentro mesmo em formas côncavas), com o tamanho
// em blocos para o mapa decidir de que zoom o nome aparece. O nome em si o mapa pede ao jogo
// (C_Map.GetAreaInfo), no idioma do cliente. Áreas com o nome de uma zona são o nome da zona.
const MIN_CELLS = 6;               // pedaços menores não ganham nome
const YARDS = 1600 / 3;            // jardas por ADT

function chunkList(buf) {
  const out = [];
  let p = 0;
  while (p + 8 <= buf.length) {
    const id = buf.toString("ascii", p, p + 4).split("").reverse().join("");
    const size = buf.readUInt32LE(p + 4);
    out.push({ id, start: p + 8, size });
    p += 8 + size;
  }
  return out;
}

function buildAreas(casc) {
  const CHUNK = YARDS / 16, MID = 32 * YARDS, N = 1024;
  const labels = [];
  for (const { inst, wdt } of CONTINENTS) {
    const b = casc.readFid(wdt);
    const maid = chunkList(b).find((c) => c.id === "MAID");
    const area = new Uint32Array(N * N);
    let read = 0;
    for (let i = 0; i < 4096; i++) {
      const root = b.readUInt32LE(maid.start + i * 32);
      if (!root) continue;
      const adt = casc.readFid(root);
      if (!adt) continue;
      const row = Math.floor(i / 64), col = i % 64;
      for (const c of chunkList(adt)) {
        if (c.id !== "MCNK") continue;
        const ix = adt.readUInt32LE(c.start + 4), iy = adt.readUInt32LE(c.start + 8);
        if (ix < 16 && iy < 16) area[(row * 16 + iy) * N + col * 16 + ix] = adt.readUInt32LE(c.start + 0x34);
      }
      read++;
    }
    // pedaços contínuos (vizinhança 4)
    const seen = new Uint8Array(N * N);
    let n = 0;
    for (let s = 0; s < area.length; s++) {
      if (!area[s] || seen[s]) continue;
      const id = area[s], stack = [s], cells = [];
      seen[s] = 1;
      while (stack.length) {
        const q = stack.pop();
        cells.push(q);
        const x = q % N, y = (q / N) | 0;
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const nx = x + dx, ny = y + dy;
          if (nx < 0 || ny < 0 || nx >= N || ny >= N) continue;
          const k = ny * N + nx;
          if (!seen[k] && area[k] === id) { seen[k] = 1; stack.push(k); }
        }
      }
      if (cells.length < MIN_CELLS) continue;
      let sx = 0, sy = 0;
      for (const q of cells) { sx += q % N; sy += (q / N) | 0; }
      const cx = sx / cells.length, cy = sy / cells.length;
      let pick = cells[0], bd = Infinity;
      for (const q of cells) { const d = (q % N - cx) ** 2 + (((q / N) | 0) - cy) ** 2; if (d < bd) { bd = d; pick = q; } }
      const gx = pick % N + 0.5, gy = ((pick / N) | 0) + 0.5;
      // jardas do mundo: X (norte) desce com a linha, Y (oeste) desce com a coluna
      labels.push([inst, Math.round((MID - gy * CHUNK) * 10) / 10, Math.round((MID - gx * CHUNK) * 10) / 10, id, cells.length]);
      n++;
    }
    console.log("areas: instância", inst, "-", read, "ADT lidos,", n, "pedaços com nome");
  }
  labels.sort((a, b) => b[4] - a[4]);
  const out = [header("Áreas do terreno para os nomes do mapa (sub-regiões e zonas).", casc), "",
    "-- { instância, X, Y (jardas do mundo: X norte, Y oeste), AreaID, tamanho (blocos de 33,3 jardas) }, maiores primeiro.",
    "-- Um rótulo por pedaço contínuo da área, no bloco dela mais perto do centro. O nome vem do jogo (C_Map.GetAreaInfo).",
    "Azaath.MapData.Areas = {"];
  for (const l of labels) out.push("\t{ " + l.join(", ") + " },");
  out.push("}", "");
  write("Areas.lua", out.join("\n"));
}

// --- Entradas de masmorras e raides ----------------------------------------------------------------
// A tabela Map do cliente guarda, para cada instância, onde o fantasma reaparece (Corpse: X norte, Y
// oeste, em jardas do mundo) — é a porta da instância. O jogo do Forever não entrega as entradas ao
// addon (C_EncounterJournal.GetDungeonEntrancesForMap volta vazio). Nome, níveis e se é raide o mapa
// pede ao jogo (GetLFGDungeonInfo, o localizador de grupo); o continente ele acha pelo ponto.
const DB_MAP = 1349477;

function buildInstances(casc) {
  const t = parseWDC5(casc.readFid(DB_MAP));
  const out = [header("Entradas de masmorras e raides (onde o fantasma reaparece, da tabela Map do cliente).", casc), "",
    "-- { ID da instância (mapa), X, Y (jardas do mundo: X norte, Y oeste) }",
    "Azaath.MapData.Instances = {"];
  let n = 0;
  for (const r of t.rows.sort((a, b) => a.id - b.id)) {
    const c = r.vals[6];
    if (!Array.isArray(c)) continue;
    const x = t.float(c[0]), y = t.float(c[1]);
    if (!isFinite(x) || !isFinite(y) || (x === 0 && y === 0)) continue;
    out.push("\t{ " + r.id + ", " + Math.round(x * 10) / 10 + ", " + Math.round(y * 10) / 10 + " },");
    n++;
  }
  out.push("}", "");
  console.log("instances:", n, "instâncias com entrada");
  write("Instances.lua", out.join("\n"));
}

// áreas dos objetivos de missão: tools/map-extract/questareas.js
const { buildQuestAreas } = require("./questareas.js");
// interiores das construções (cidades subterrâneas, cavernas): tools/map-extract/interiors.js
const { buildInteriors } = require("./interiors.js");
const JOBS = { reveal: buildReveal, minimap: buildMinimap, areas: buildAreas, instances: buildInstances,
  questareas: (casc) => buildQuestAreas(write, header, casc),
  interiors: (casc) => buildInteriors(write, header, casc, CONTINENTS, ROOT, WOW) };

if (require.main === module) {
  (async () => {
    const casc = await openCasc(WOW, PRODUCT);
    const wanted = process.argv.slice(2);
    for (const [name, fn] of Object.entries(JOBS)) if (!wanted.length || wanted.includes(name)) fn(casc);
  })().catch((e) => { console.error("ERRO:", e.stack || e.message); process.exit(1); });
}

module.exports = { openCasc: () => openCasc(WOW, PRODUCT), buildReveal, DB,
  CONTINENTS, LODS, readMinimapTiles, dropStrayIslands, waterAlpha, shrink, SEA_RGB, WOW, ROOT };
