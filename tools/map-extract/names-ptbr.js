// Nomes pt-BR de masmorras e chefes para o catálogo da aba Masmorras.
//  * Nomes pt-BR: Polestar_ptBR/Names.lua (os textos do próprio cliente; ver LICENSE-DATA.txt de lá),
//    tipos "map" (instâncias), "encounter" (DungeonEncounter) e "npc".
//  * Ponte inglês -> ID: as tabelas Map e DungeonEncounter do cliente do Forever em inglês
//    (wago.tools, build 1.60.1.70532), em tools/.cache/wago/*-enUS.csv.
"use strict";
const fs = require("fs");
const path = require("path");

const CACHE = path.join(__dirname, "../.cache");
const PT_FILE = path.join(CACHE, "polestar/Polestar_ptBR/Names.lua");

function readPtNames() {
  const out = {};
  if (!fs.existsSync(PT_FILE)) return out;
  const src = fs.readFileSync(PT_FILE, "utf8");
  for (const m of src.matchAll(/R\("(\w+)",\s*\d+,\s*\d+,\s*\[\[([\s\S]*?)\]\]\)/g)) {
    const kind = (out[m[1]] = out[m[1]] || new Map());
    for (const line of m[2].split(/\r?\n/)) {
      const t = line.indexOf("\t");
      if (t <= 0) continue;
      const name = line.slice(t + 1).trim().replace(/%([0-9A-Fa-f]{2})/g, (_, h) => String.fromCharCode(parseInt(h, 16)));
      if (name) kind.set(Number(line.slice(0, t)), name);
    }
  }
  return out;
}

// CSV simples do wago (campos entre aspas podem ter vírgula)
function readCsv(file) {
  if (!fs.existsSync(file)) return [];
  const lines = fs.readFileSync(file, "utf8").split(/\r?\n/).filter(Boolean);
  const split = (l) => {
    const out = []; let cur = "", q = false;
    for (let i = 0; i < l.length; i++) {
      const c = l[i];
      if (q) { if (c === '"' && l[i + 1] === '"') { cur += '"'; i++; } else if (c === '"') q = false; else cur += c; }
      else if (c === '"') q = true; else if (c === ",") { out.push(cur); cur = ""; } else cur += c;
    }
    out.push(cur);
    return out;
  };
  const head = split(lines[0]);
  return lines.slice(1).map((l) => { const v = split(l); const o = {}; head.forEach((h, i) => { o[h] = v[i]; }); return o; });
}

const norm = (s) => String(s || "").toLowerCase().replace(/^the /, "").replace(/[^a-z0-9]/g, "");

// alas das masmorras divididas (o mapa é um só no cliente)
const WINGS = {
  east: "Leste", north: "Norte", west: "Oeste", armory: "Arsenal", cathedral: "Catedral",
  graveyard: "Cemitério", library: "Biblioteca", lower: "Inferior", upper: "Superior",
};

function makeTranslator() {
  const pt = readPtNames();
  const maps = readCsv(path.join(CACHE, "wago/Map-enUS.csv"));
  const encs = readCsv(path.join(CACHE, "wago/DungeonEncounter-enUS.csv"));
  const mapByName = new Map();
  for (const m of maps) if (m.MapName_lang && !mapByName.has(norm(m.MapName_lang))) mapByName.set(norm(m.MapName_lang), m);
  const ptMap = pt.map || new Map(), ptEnc = pt.encounter || new Map(), ptNpc = pt.npc || new Map();

  // masmorra -> { pt, mapID, area }
  function dungeon(name) {
    let base = name, wing = null;
    let m = /^(.*?):\s*(\w+)$/.exec(name);                    // "Dire Maul: East"
    if (m) { base = m[1]; wing = m[2].toLowerCase(); }
    m = /^(Lower|Upper)\s+(.*)$/i.exec(base);                  // "Lower Blackrock Spire"
    if (m) { base = m[2]; wing = m[1].toLowerCase(); }
    const alias = { stockade: "Stormwind Stockade", templeofatalhakkar: "Sunken Temple" }[norm(name)];
    const row = mapByName.get(norm(alias || name)) || mapByName.get(norm(base));
    if (!row) return { pt: "", mapID: 0, area: 0 };
    const exact = norm(row.MapName_lang) === norm(alias || name);
    const id = Number(row.ID);
    let ptName = ptMap.get(id) || "";
    if (ptName && !exact && wing && WINGS[wing]) ptName += (wing === "lower" || wing === "upper" ? " " : ": ") + WINGS[wing];
    return { pt: ptName, mapID: id, area: Number(row.AreaTableID) || 0 };
  }

  // chefe -> nome pt (encontro da mesma instância primeiro, depois o NPC)
  function boss(name, npcID, mapID) {
    const n = norm(name);
    let hit = encs.find((e) => norm(e.Name_lang) === n && (!mapID || Number(e.MapID) === mapID));
    if (!hit) hit = encs.find((e) => norm(e.Name_lang) === n);
    if (hit && ptEnc.get(Number(hit.ID))) return ptEnc.get(Number(hit.ID));
    if (npcID && ptNpc.get(npcID)) return ptNpc.get(npcID);
    return "";
  }

  return { dungeon, boss };
}

// Local das masmorras (texto livre do OneForAll). Nomes de zona/subzona oficiais do cliente em pt-BR
// (AreaTable ptBR do Forever, tools/.cache/wago/AreaTable-*.csv; Distrito dos Magos pelas subzonas do
// Polestar_ptBR); só as ligações ("sob a cidade", "perto de"...) são escritas aqui.
const LOCATION_PT = {
  "Alcaz Island, Dustwallow Marsh": "Ilha Alcaz, Pântano Vadeoso",
  "Alterac Mountains": "Montanhas de Alterac",
  "Ashenvale, Zoram Strand": "Vale Gris, Praia de Zoram",
  "Badlands": "Ermos",
  "Behind the Furbolg gate, Azshara": "Azshara, atrás do portão dos furbolgs",
  "Blackrock Mountain": "Montanha Rocha Negra",
  "Caer Darrow, Western Plaguelands": "Castro das Flechas, Terras Pestilentas Ocidentais",
  "Desolace": "Desolação",
  "Dun Morogh": "Dun Morogh",
  "Dustwallow Marsh": "Pântano Vadeoso",
  "Eastern Plaguelands": "Terras Pestilentas Orientais",
  "Feralas": "Feralas",
  "Gillijim's Isle, off the coast of Stranglethorn Vale": "Ilha de Gillijim, na costa da Selva do Espinhaço",
  "Ironforge, under the city": "Altaforja, sob a cidade",
  "Mount Hyjal": "Monte Hyjal",
  "Orgrimmar, Cleft of Shadow": "Orgrimmar, Fenda das Sombras",
  "Riverglades": "Sendas do Rio",
  "Scarlet Monastery, Tirisfal Glades": "Monastério Escarlate, Clareiras de Tirisfal",
  "Silverpine Forest, above Pyrewood Village": "Floresta de Pinhaprata, acima do Vilarejo Lenhardente",
  "Southern Barrens": "Sertões Meridionais",
  "Southern Barrens, near Thousand Needles": "Sertões Meridionais, perto de Mil Agulhas",
  "Stormwind City, Mage Quarter": "Ventobravo, Distrito dos Magos",
  "Swamp of Sorrows": "Pântano das Mágoas",
  "Tanaris": "Tanaris",
  "The Barrens, north of the Crossroads": "Sertões, ao norte da Encruzilhada",
  "Tirisfal Glades, Ruins of Lordaeron": "Clareiras de Tirisfal, Ruínas de Lordaeron",
  "Tirisfal Glades, Scarlet Monastery": "Clareiras de Tirisfal, Monastério Escarlate",
  "Un'Goro Crater": "Cratera Un'Goro",
  "Westfall, Moonbrook": "Cerro Oeste, Arroio da Lua",
  "Wetlands": "Pantanal",
};
const locationPt = (s) => LOCATION_PT[s] || "";

// Nomes pt-BR do QuestieDB (GPL-3.0; https://github.com/Questie/QuestieDB, l10n/<Classic|Forever>/
// lookup<Items|Npcs|Objects>/ptBR.lua), em thirdparty/questiedb/l10n. O do Forever vence o do Classic.
// Só lidos como texto. kind: "Items" | "Npcs" | "Objects" -> Map(id -> nome)
const L10N_DIR = path.join(__dirname, "thirdparty/questiedb/l10n");
const l10nCache = {};
function questieNames(kind) {
  if (l10nCache[kind]) return l10nCache[kind];
  const out = new Map();
  // "Forever-traces" = textos do Forever registrados dentro do jogo (l10n/Forever/traces); vence os outros
  for (const v of ["Classic", "Forever", "Forever-traces"]) {
    const fp = path.join(L10N_DIR, `${v}-lookup${kind}-ptBR.lua`);
    if (!fs.existsSync(fp)) continue;
    const src = fs.readFileSync(fp, "utf8");
    for (const m of src.matchAll(/^\[(\d+)\] = \{?"((?:\\.|[^"\\])*)"/gm)) {
      const name = m[2].replace(/\\(.)/g, "$1");
      if (name) out.set(Number(m[1]), name);
    }
  }
  l10nCache[kind] = out;
  return out;
}

// Nomes oficiais do cliente (ItemSparse do Forever e, para o que falta, do Classic Era), em
// tools/.cache/wago/ItemSparse[-era]-<loc>.csv. -> Map(id -> nome)
function clientItemNames(loc) {
  const out = new Map();
  for (const f of [`ItemSparse-era-${loc}.csv`, `ItemSparse-${loc}.csv`]) {
    const fp = path.join(CACHE, "wago", f);
    if (!fs.existsSync(fp)) continue;
    for (const row of readCsv(fp)) if (row.Display_lang) out.set(Number(row.ID), row.Display_lang);
  }
  return out;
}

module.exports = { makeTranslator, locationPt, questieNames, clientItemNames, readPtNames };
