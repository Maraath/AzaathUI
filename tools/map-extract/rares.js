// Gerador dos raros do mapa (AzaathUI/Data/Map/Rares.lua), para o Rare Scanner (Modules/MapRares.lua).
// Fontes (só lidas como texto):
//   * pfQuest (MIT): quem é raro no Classic (rnk 2 = raro de elite, 4 = raro), nível e respawn.
//   * AzerothCore (GPL-2.0+): raros que o pfQuest não marca (rank 2/4), níveis, respawn e o loot.
//   * Polestar_QuestDB: onde cada criatura nasce NO FOREVER (só entra quem está lá). As coordenadas do
//     quadro "Era" (0) viram jardas do mundo aqui; as do quadro "live" (1) ficam em % do mapa e o addon
//     converte no jogo (C_Map.GetWorldPosFromMapPos).
//   * Polestar_ptBR/Names.lua: nome pt-BR; wago ItemSparse: nome pt-BR e qualidade dos itens.
// Uso: node tools/map-extract/rares.js
"use strict";
const fs = require("fs");
const path = require("path");
const { readSqlTable } = require("./azerothcore.js");
const { readPtNames } = require("./names-ptbr.js");

const CACHE = path.join(__dirname, "../.cache");
const QDB = path.join(CACHE, "polestar/Polestar_QuestDB");
const CONTS = new Set([0, 1, 530, 571]);   // só o mundo aberto (raros de masmorra ficam de fora)
const OUT = path.join(__dirname, "../../AzaathUI/Data/Map/Rares.lua");

// --- Polestar: npcs e quadros Era ---
function decode(s) {
  return s.split(";").map((f) => {
    if (f === "") return null;
    if (f[0] === "'") return f.slice(1).replace(/%([0-9a-fA-F]{2})/g, (_, h) => String.fromCharCode(parseInt(h, 16)));
    return Number(f);
  });
}
function readPolestarNpcs() {
  const src = fs.readFileSync(path.join(QDB, "Npcs.lua"), "utf8");
  const out = new Map();
  for (const m of src.matchAll(/R\("npcs",[^\[]*\[\[([\s\S]*?)\]\]/g)) {
    for (const line of m[1].split(/\r?\n/)) {
      const t = line.indexOf("\t");
      if (t > 0) out.set(Number(line.slice(0, t)), decode(line.slice(t + 1)));
    }
  }
  return out;
}
function readEraFrames() {
  const src = fs.readFileSync(path.join(QDB, "MapFrames.lua"), "utf8");
  const out = new Map();
  for (const m of src.matchAll(/\[(\d+)\] = \{bottom=([-\d.]+),c=(\d+),left=([-\d.]+),right=([-\d.]+),top=([-\d.]+)\}/g)) {
    out.set(Number(m[1]), { bottom: +m[2], c: +m[3], left: +m[4], right: +m[5], top: +m[6] });
  }
  return out;
}

// --- pfQuest: raros, nível e respawn ---
function readPfUnits() {
  const src = fs.readFileSync(path.join(CACHE, "pfquest/units.lua"), "utf8");
  const out = new Map();
  let cur = null;
  for (const line of src.split(/\r?\n/)) {
    let m = line.match(/^  \[(\d+)\] = \{/);
    if (m) { cur = { id: +m[1], respawn: 0 }; out.set(cur.id, cur); continue; }
    if (!cur) continue;
    if ((m = line.match(/^      \[\d+\] = \{ ([\d.]+), ([\d.]+), (\d+), (\d+)/))) {
      (cur.coords = cur.coords || []).push([+m[1], +m[2], +m[3]]);
      if (!cur.respawn) cur.respawn = +m[4];
      continue;
    }
    if ((m = line.match(/^    \["lvl"\] = "([^"]+)"/))) { cur.lvl = m[1]; continue; }
    if ((m = line.match(/^    \["rnk"\] = "(\d)"/))) cur.rnk = +m[1];
  }
  return out;
}

// --- CSV simples (wago) ---
function readCsv(file, want) {
  const fp = path.join(CACHE, "wago", file);
  if (!fs.existsSync(fp)) return new Map();
  const lines = fs.readFileSync(fp, "utf8").split(/\r?\n/);
  const split = (l) => {
    const a = []; let cur = "", q = false;
    for (let i = 0; i < l.length; i++) {
      const c = l[i];
      if (q) { if (c === '"') { if (l[i + 1] === '"') { cur += '"'; i++; } else q = false; } else cur += c; }
      else if (c === '"') q = true;
      else if (c === ",") { a.push(cur); cur = ""; }
      else cur += c;
    }
    a.push(cur);
    return a;
  };
  const head = split(lines[0]);
  const idx = want.map((w) => head.indexOf(w));
  const out = new Map();
  for (let i = 1; i < lines.length; i++) {
    if (!lines[i]) continue;
    const v = split(lines[i]);
    out.set(Number(v[0]), idx.map((k) => v[k]));
  }
  return out;
}

function main() {
  const pst = readPolestarNpcs();
  const era = readEraFrames();
  const pf = readPfUnits();
  const pfName = new Map();
  for (const m of fs.readFileSync(path.join(CACHE, "pfquest/enUS/units.lua"), "utf8").matchAll(/^  \[(\d+)\] = "((?:[^"\\]|\\.)*)"/gm)) pfName.set(+m[1], m[2].replace(/\\(.)/g, "$1"));
  const pt = (readPtNames().npc) || new Map();
  const itemsPt = readCsv("ItemSparse-era-ptBR.csv", ["Display_lang", "OverallQualityID"]);
  const itemsPt2 = readCsv("ItemSparse-ptBR.csv", ["Display_lang", "OverallQualityID"]);
  const itemsEn = readCsv("ItemSparse-era-enUS.csv", ["Display_lang", "OverallQualityID"]);
  const itemName = (id) => { for (const m of [itemsPt2, itemsPt, itemsEn]) { const v = m.get(id); if (v && v[0]) return v[0]; } return ""; };
  // qualidade: a maior entre o cliente atual e o Era (o Era às vezes rebaixa itens verdes)
  const itemQuality = (id) => Math.max(...[itemsPt, itemsPt2, itemsEn].map((m) => (m.get(id) ? +m.get(id)[1] || 0 : 0)));

  // AzerothCore: rank, nível, loot e respawn
  const ac = new Map();
  for (const r of readSqlTable("creature_template")) {
    ac.set(+r.entry, { rank: +r.rank, min: +r.minlevel, max: +r.maxlevel, loot: +r.lootid, name: r.name });
  }
  const acRespawn = new Map();
  for (const r of readSqlTable("creature")) {
    const id = +r.id1;
    if (!acRespawn.has(id)) acRespawn.set(id, +r.spawntimesecs);
  }
  // modelo (displayID) de cada criatura: o de menor índice (creature_template_model)
  const display = new Map();
  for (const r of readSqlTable("creature_template_model")) {
    const id = +r.CreatureID, idx = +r.Idx;
    const cur = display.get(id);
    if (!cur || idx < cur.idx) display.set(id, { idx, d: +r.CreatureDisplayID });
  }
  const lootRows = new Map();
  for (const r of readSqlTable("creature_loot_template")) {
    const e = +r.Entry;
    if (!lootRows.has(e)) lootRows.set(e, []);
    lootRows.get(e).push({ item: +r.Item, ref: +r.Reference, chance: +r.Chance, group: +r.GroupId });
  }

  // zona do pfQuest (AreaTable) -> mapa da interface (quadro Era), votado por quem está nos dois bancos
  const votes = new Map();
  for (const [id, u] of pf) {
    const ent = pst.get(id);
    if (!ent || !u.coords || ent[2] !== 0 || !era.has(ent[1])) continue;
    const z = u.coords[0][2];
    const v = votes.get(z) || new Map();
    v.set(ent[1], (v.get(ent[1]) || 0) + 1);
    votes.set(z, v);
  }
  const zoneToUi = new Map();
  for (const [z, v] of votes) zoneToUi.set(z, [...v.entries()].sort((a, b) => b[1] - a[1])[0][0]);
  const acPos = new Map();
  for (const r of readSqlTable("creature")) {
    const id = +r.id1;
    if (!acPos.has(id)) acPos.set(id, []);
    acPos.get(id).push([+r.map, +r.position_x, +r.position_y]);
  }

  // quem é raro
  const rares = new Map();
  for (const [id, u] of pf) if (u.rnk === 2 || u.rnk === 4) rares.set(id, u.rnk === 2);
  for (const [id, t] of ac) if (!rares.has(id) && (t.rank === 2 || t.rank === 4) && !(pf.get(id) && pf.get(id).rnk)) rares.set(id, t.rank === 2);

  // pfQuest items.lua: [item] = { ["U"] = { [npc] = % } } -> npc -> [[item, %]] (só dos raros)
  const pfDrops = new Map();
  {
    let item = null, inU = false;
    for (const line of fs.readFileSync(path.join(CACHE, "pfquest/items.lua"), "utf8").split(/\r?\n/)) {
      let m = line.match(/^  \[(\d+)\] = \{/);
      if (m) { item = +m[1]; inU = false; continue; }
      if (/^    \["U"\] = \{/.test(line)) { inU = true; continue; }
      if (/^    \S/.test(line) || /^    \}/.test(line)) { inU = false; continue; }
      if (inU && (m = line.match(/^      \[(\d+)\] = ([\d.]+)/)) && rares.has(+m[1])) {
        if (!pfDrops.has(+m[1])) pfDrops.set(+m[1], []);
        pfDrops.get(+m[1]).push([item, +m[2]]);
      }
    }
  }

  const lines = [];
  let nSp = 0, nLive = 0, skipped = 0;
  const srcCount = {};
  for (const [id, elite] of [...rares].sort((a, b) => a[0] - b[0])) {
    const ent = pst.get(id) || [];
    // pontos: { "w", cont, X, Y } (jardas) ou { "m", uiMap, x, y } (% do mapa live)
    const pts = [];
    let i = 1;
    while (i < ent.length && ent[i] != null) {
      const map = ent[i], frame = ent[i + 1], n = ent[i + 2];
      for (let k = 0; k < n; k++) {
        const x = ent[i + 3 + 3 * k], y = ent[i + 4 + 3 * k];
        if (x == null || y == null) continue;
        const f = frame === 0 && era.get(map);
        if (f) {
          const Y = f.left - (x / 100) * (f.left - f.right);
          const X = f.top - (y / 100) * (f.top - f.bottom);
          pts.push(`${f.c},${X.toFixed(1)},${Y.toFixed(1)}`);
        } else {
          pts.push(`-${map},${x},${y}`);   // mapa da interface negativo = coordenada em % (live)
          nLive++;
        }
      }
      i += 3 + 3 * n;
    }
    let src = "pst";
    if (!pts.length) {                       // pfQuest (Classic), pelo quadro Era da zona
      src = "pf";
      for (const [x, y, z] of (pf.get(id) && pf.get(id).coords) || []) {
        const f = era.get(zoneToUi.get(z));
        if (!f) continue;
        pts.push(`${f.c},${(f.top - (y / 100) * (f.top - f.bottom)).toFixed(1)},${(f.left - (x / 100) * (f.left - f.right)).toFixed(1)}`);
      }
    }
    if (!pts.length) {                       // AzerothCore: jardas do mundo direto
      src = "ac";
      for (const [map, X, Y] of acPos.get(id) || []) if (CONTS.has(map)) pts.push(`${map},${X.toFixed(1)},${Y.toFixed(1)}`);
    }
    if (!pts.length) { skipped++; continue; }
    srcCount[src] = (srcCount[src] || 0) + 1;
    // pontos repetidos muito perto (menos de 25 jardas): um só
    const seen = [];
    for (let k = pts.length - 1; k >= 0; k--) {
      const [c, X, Y] = pts[k].split(",").map(Number);
      if (c >= 0 && seen.some((q) => q[0] === c && Math.abs(q[1] - X) + Math.abs(q[2] - Y) < 25)) pts.splice(k, 1);
      else seen.push([c, X, Y]);
    }
    nSp += pts.length;
    const t = ac.get(id);
    const u = pf.get(id);
    const name = pt.get(id) || ent[0] || (pfName.get(id)) || (t && t.name) || ("#" + id);
    const lvl = (u && u.lvl) || (t ? (t.min === t.max ? String(t.min) : `${t.min}-${t.max}`) : "?");
    const respawn = (u && u.respawn) || acRespawn.get(id) || 0;
    // loot: itens verdes ou melhores, e os do grupo próprio do raro (brancos inclusive); sem os de
    // referência (loot do mundo). Num grupo, chance 0 = o que sobra do grupo dividido entre eles.
    const drops = [];
    const rows = (t && t.loot && lootRows.get(t.loot)) || [];
    const grp = new Map();
    for (const r of rows) if (r.group > 0 && !(r.ref > 0)) {
      const g = grp.get(r.group) || { sum: 0, zero: 0 };
      if (r.chance > 0) g.sum += r.chance; else g.zero++;
      grp.set(r.group, g);
    }
    for (const r of rows) {
      if (!(r.item > 0) || r.ref > 0) continue;
      const q = itemQuality(r.item);
      if (q < 1 || (q < 2 && !(r.group > 0))) continue;
      let pct = r.chance;
      if (!(pct > 0)) {
        const g = r.group > 0 && grp.get(r.group);
        pct = g ? Math.max(0, 100 - g.sum) / g.zero : 100;
      }
      if (pct > 0) drops.push({ id: r.item, pct });
    }
    // sem loot próprio no AzerothCore: os drops que o pfQuest conhece (verdes ou melhores, 0,5% ou mais)
    if (!drops.length) {
      for (const [item, pct] of pfDrops.get(id) || []) {
        if (pct >= 0.5 && itemQuality(item) >= 2) drops.push({ id: item, pct });
      }
    }
    drops.sort((a, b) => b.pct - a.pct);
    const d = drops.slice(0, 24).map((x) => `${x.id},${Math.round(x.pct * 10) / 10},${itemQuality(x.id)},${JSON.stringify(itemName(x.id))}`).join(",");
    lines.push(`\t[${id}] = { ${JSON.stringify(name)}, "${lvl}", ${elite ? 1 : 0}, ${respawn}, { ${pts.join(", ")} }, { ${d} }, ${display.has(id) ? display.get(id).d : 0} },`);
  }

  const out = [
    "-- Raros do mapa (Rare Scanner). GERADO por tools/map-extract/rares.js: não edite à mão.",
    "-- Fontes: pfQuest (MIT), AzerothCore (GPL-2.0+), Polestar_QuestDB/ptBR (posições e nomes do Forever).",
    "-- [npcID] = { nome, nível, elite (1/0), respawn (s), pontos, drops, displayID (modelo 3D; 0 = sem) }",
    "--   pontos: trincas; continente (0/1), X, Y em jardas do mundo; ou -uiMapID, x, y (0..100 do mapa)",
    "--   drops: quádruplas itemID, chance (%), qualidade, nome pt-BR",
    "local _, Azaath = ...",
    "Azaath.MapData = Azaath.MapData or {}",
    "Azaath.MapData.Rares = {",
    ...lines,
    "}",
    "",
  ].join("\n");
  fs.writeFileSync(OUT, out, "utf8");
  console.log(JSON.stringify(srcCount)); console.log(`raros: ${lines.length} (fora do Forever: ${skipped}), pontos: ${nSp} (live: ${nLive}) -> ${OUT}`);
}

main();
