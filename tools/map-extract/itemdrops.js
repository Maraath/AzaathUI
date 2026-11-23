// Gerador completo do banco de equipamentos e itens dropáveis/craftáveis
// (Data/Quests/ItemDrops.lua).
// Combina:
//   1) Polestar_QuestDB (itens de missão + spawns)
//   2) Polestar_ItemDB (atributos, qualidade, armadura/arma, drops e crafts do Forever)
//   3) pfQuest (MIT): drops do Classic com % por criatura, objetos, vendedores
//   4) AzerothCore (GPL-2.0+): recompensas de missão e tabelas de loot com chance exata.
//      Como ele é WotLK, só entra o que existe no Forever: missões do Polestar_QuestDB e
//      criaturas/objetos conhecidos pelo Polestar ou pelo pfQuest (base Classic).
// Os bancos ficam em tools/.cache/pfquest e tools/.cache/azerothcore.
// Uso: node tools/map-extract/itemdrops.js
"use strict";
const fs = require("fs");
const path = require("path");

const CACHE_ROOT = path.join(__dirname, "../.cache/polestar");
const WOW_ADDONS = "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns";

const QDB_DIR = process.env.POLESTAR_DB
  || (fs.existsSync(path.join(CACHE_ROOT, "Polestar_QuestDB")) ? path.join(CACHE_ROOT, "Polestar_QuestDB") : path.join(WOW_ADDONS, "Polestar_QuestDB"));
const IDB_DIR = fs.existsSync(path.join(CACHE_ROOT, "Polestar_ItemDB"))
  ? path.join(CACHE_ROOT, "Polestar_ItemDB")
  : path.join(WOW_ADDONS, "Polestar_ItemDB");
const PF_DB = process.env.PF_DB || path.join(__dirname, "../.cache/pfquest");
const { readAcQuestRewards, readAcLoot, readAcVendors } = require("./azerothcore.js");
const { readOneForAll, slotInfo } = require("./oneforall.js");
const { readClientItems, consumableTag } = require("./item-client.js");
const { makeTranslator, locationPt, questieNames, clientItemNames, readPtNames } = require("./names-ptbr.js");
const OUT_FILE = path.join(__dirname, "../../AzaathUI/Data/Quests/ItemDrops.lua");

function decode(s) {
  return s.split(";").map((f) => {
    if (f === "") return null;
    if (f[0] === "'") return f.slice(1).replace(/%([0-9a-fA-F]{2})/g, (_, h) => String.fromCharCode(parseInt(h, 16)));
    return Number(f);
  });
}

function readKind(dir, file, kind) {
  const fp = path.join(dir, file);
  if (!fs.existsSync(fp)) return new Map();
  const src = fs.readFileSync(fp, "utf8");
  const out = new Map();
  const re = new RegExp('R\\("' + kind + '",[^\\[]*\\[\\[([\\s\\S]*?)\\]\\]', "g");
  let m;
  while ((m = re.exec(src))) {
    for (const line of m[1].split(/\r?\n/)) {
      const t = line.indexOf("\t");
      if (t <= 0) continue;
      out.set(Number(line.slice(0, t)), decode(line.slice(t + 1)));
    }
  }
  return out;
}

function firstSpawn(entity) {
  if (!entity) return [null, null, null];
  let i = 1;
  while (i < entity.length) {
    const map = entity[i], n = entity[i + 2];
    if (map == null || n == null) break;
    if (n > 0) {
      const x = entity[i + 3], y = entity[i + 4];
      if (x != null && y != null) return [map, x, y];
    }
    i += 3 + 3 * n;
  }
  return [null, null, null];
}

function readItemMeta() {
  const meta = new Map();
  if (!fs.existsSync(IDB_DIR)) return meta;
  for (const file of ["Items.lua", "Forever.lua"]) {
    const fp = path.join(IDB_DIR, file);
    if (!fs.existsSync(fp)) continue;
    let src = fs.readFileSync(fp, "utf8");
    const lvlCut = src.indexOf("DB.RegisterLeveling");
    if (lvlCut >= 0) src = src.slice(0, lvlCut);
    for (const m of src.matchAll(/\[(\d+)\]="([^"]+)"/g)) {
      const parts = m[2].split(" ");
      if (parts.length >= 6 && /^\d+$/.test(parts[0]) && /^\d+$/.test(parts[1]) && /^\d+$/.test(parts[2])) {
        meta.set(Number(m[1]), {
          inv: Number(parts[0]) || 0,
          ilvl: Number(parts[1]) || 0,
          req: Number(parts[2]) || 0,
          quality: Number(parts[3]) || 1,
          classID: Number(parts[4]) || 0,
          subclassID: Number(parts[5]) || 0,
          stats: parts.slice(6).join(" "),
        });
      }
    }
  }
  return meta;
}

function readForeverLeveling(namesOut, extraSrcOut) {
  const fp = path.join(IDB_DIR, "Forever.lua");
  if (!fs.existsSync(fp)) return;
  const src = fs.readFileSync(fp, "utf8");

  const namesBlock = src.match(/names\s*=\s*\{([\s\S]*?)\n\}/);
  if (namesBlock) {
    for (const m of namesBlock[1].matchAll(/\[(\d+)\]="((?:\\.|[^"])*)"/g)) {
      namesOut.set(Number(m[1]), m[2].replace(/\\"/g, '"'));
    }
  }

  const srcBlock = src.match(/\bsrc\s*=\s*\{([\s\S]*?)\n\}/);
  if (srcBlock) {
    for (const m of srcBlock[1].matchAll(/\[(\d+)\]="([^"]+)"/g)) {
      const id = Number(m[1]);
      const list = [];
      for (const t of m[2].split(",")) {
        if (t[0] === "d") {
          const dm = t.match(/^d(\d+)x(\d+)z(\d+)$/);
          if (dm) list.push({ kind: "drop", npc: Number(dm[1]), pct: Number(dm[2]) / 10, zone: Number(dm[3]) });
        } else if (t[0] === "c") {
          const cm = t.match(/^c(\d+)p([^s]+)s(\d+)$/);
          if (cm) list.push({ kind: "craft", prof: cm[2], skill: Number(cm[3]) });
        } else if (t[0] === "q") {
          const qm = t.match(/^q(\d+)$/);
          if (qm) list.push({ kind: "quest", questId: Number(qm[1]) });
        }
      }
      if (list.length) extraSrcOut.set(id, list);
    }
  }
}

function readPtBRItemNames() {
  const ptItems = new Map();
  const fp = path.join(CACHE_ROOT, "Polestar_ptBR", "Names.lua");
  if (!fs.existsSync(fp)) return ptItems;
  const src = fs.readFileSync(fp, "utf8");
  const rx = /R\("item",\s*\d+,\s*\d+,\s*\[\[([\s\S]*?)\]\]\)/g;
  let m;
  while ((m = rx.exec(src)) !== null) {
    for (const line of m[1].split(/\r?\n/)) {
      if (!line) continue;
      const tab = line.indexOf("\t");
      if (tab <= 0) continue;
      const id = Number(line.slice(0, tab));
      const name = line.slice(tab + 1).trim();
      if (id > 0 && name) ptItems.set(id, name);
    }
  }
  return ptItems;
}

// --- pfQuest (MIT, (c) Shagu; https://github.com/shagu/pfQuest): itens -> fontes com % de drop ---
function pfLines(file) {
  const fp = path.join(PF_DB, file);
  if (!fs.existsSync(fp)) throw new Error("pfQuest: faltou " + fp);
  return fs.readFileSync(fp, "utf8").split(/\r?\n/);
}

function pfNames(file) {
  const out = new Map();
  for (const line of pfLines(file)) {
    const m = line.match(/^  \[(\d+)\] = "((?:\\.|[^"])*)",?$/);
    if (m) out.set(Number(m[1]), m[2].replace(/\\(['"\\])/g, "$1"));
  }
  return out;
}

// { [id] = { ["K"] = { [n] = v, ... }, ... } } -> Map(id -> { K: Map(n -> v) })
function pfKeyed(file) {
  const out = new Map();
  let cur = null, key = null;
  for (const line of pfLines(file)) {
    let m = line.match(/^  \[(\d+)\] = \{/);
    if (m) { cur = {}; out.set(Number(m[1]), cur); key = null; continue; }
    if (!cur) continue;
    m = line.match(/^    \["(\w+)"\] = \{/);
    if (m) { key = m[1]; cur[key] = new Map(); continue; }
    m = line.match(/^      \[(\d+)\] = (-?[\d.]+),/);
    if (m && key) cur[key].set(Number(m[1]), Number(m[2]));
  }
  return out;
}

// primeira posição de cada criatura/objeto: { x, y, zona (AreaTable) }
function pfFirstPos(file) {
  const pos = new Map();
  let cur = null;
  for (const line of pfLines(file)) {
    let m = line.match(/^  \[(\d+)\] = \{/);
    if (m) { cur = Number(m[1]); continue; }
    m = cur != null && line.match(/^      \[1\] = \{ ([\d.]+), ([\d.]+), (\d+)/);
    if (m) { pos.set(cur, { x: Number(m[1]), y: Number(m[2]), zone: Number(m[3]) }); cur = null; }
  }
  return pos;
}

function readPfQuest(pstNpcs) {
  const items = pfKeyed("items.lua");
  const refloot = pfKeyed("refloot.lua");
  const itemNames = pfNames("enUS/items.lua");
  const unitNames = pfNames("enUS/units.lua");
  const objNames = pfNames("enUS/objects.lua");
  const unitPos = pfFirstPos("units.lua");
  const objPos = pfFirstPos("objects.lua");

  // zona -> mapa da interface: votado pelas criaturas que existem nos dois bancos
  const votes = new Map();
  for (const [id, p] of unitPos) {
    const ent = pstNpcs.get(id);
    if (!ent) continue;
    const [map] = firstSpawn(ent);
    if (!map) continue;
    const v = votes.get(p.zone) || new Map();
    v.set(map, (v.get(map) || 0) + 1);
    votes.set(p.zone, v);
  }
  const zoneToUi = new Map();
  for (const [z, v] of votes) zoneToUi.set(z, [...v.entries()].sort((a, b) => b[1] - a[1])[0][0]);
  const place = (names, pos) => {
    const out = new Map();
    for (const [id, name] of names) {
      const p = pos.get(id);
      const ui = p && zoneToUi.get(p.zone);
      out.set(id, ui ? { name, map: ui, x: p.x, y: p.y } : { name, map: 0, x: 0, y: 0 });
    }
    return out;
  };

  const rates = new Map(), out = new Map();
  for (const [id, e] of items) {
    const rate = new Map();
    const drops = [], objs = [], vendors = [];
    for (const [n, v] of e.U || []) { drops.push(n); if (v > 0) rate.set(n, v); }
    for (const [o] of e.O || []) objs.push(o);
    for (const [n] of e.V || []) vendors.push(n);
    for (const [r, v] of e.R || []) { // loot de referência (tabelas compartilhadas)
      const ref = refloot.get(r);
      if (!ref) continue;
      for (const [n] of ref.U || []) if (!drops.includes(n)) { drops.push(n); if (v > 0) rate.set(n, v); }
      for (const [o] of ref.O || []) if (!objs.includes(o)) objs.push(o);
    }
    drops.sort((a, b) => (rate.get(b) || 0) - (rate.get(a) || 0));
    if (!drops.length && !objs.length && !vendors.length) continue;
    if (rate.size) rates.set(id, rate);
    out.set(id, pfItem(id, itemNames.get(id) || "", drops, objs, vendors));
  }
  console.log(`pfQuest: ${out.size} itens com fonte, ${rates.size} com %, ${zoneToUi.size} zonas mapeadas`);
  return { rates, npcs: place(unitNames, unitPos), objs: place(objNames, objPos), items: out, itemNames, zoneToUi };
}

// --- QuestieDB Classic (GPL-3.0; https://github.com/Questie/QuestieDB): spawns de NPCs e objetos ---
// "n<id>"/"o<id>" -> [[zona (AreaTable), x, y], ...]; dentro de instâncias x/y vêm -1 (só a zona vale).
// Os arquivos ficam em thirdparty/questiedb e são só LIDOS como texto, nunca executados.
function readQuestieSpawns() {
  const out = new Map();
  for (const [file, pre] of [["classicNpcDB.lua", "n"], ["classicObjectDB.lua", "o"]]) {
    const fp = path.join(__dirname, "thirdparty/questiedb", file);
    if (!fs.existsSync(fp)) throw new Error("QuestieDB: faltou " + fp);
    for (const line of fs.readFileSync(fp, "utf8").split(/\r?\n/)) {
      const m = line.match(/^\[(\d+)\] = \{/);
      if (!m) continue;
      const sp = [...line.matchAll(/\[(\d+)\]=\{\{([\d.-]+),([\d.-]+)\}/g)].map((z) => [Number(z[1]), Number(z[2]), Number(z[3])]);
      if (sp.length) out.set(pre + m[1], sp);
    }
  }
  return out;
}

// Arte da masmorra no próprio cliente (FileDataID): botão do Diário de Masmorras ("ej", 256x128) ou
// fundo do Localizador de Grupos ("lfg", 512x256). Tabela de tools/map-extract/dungeon-art.json, montada do
// listfile do wowdev conferindo no CASC do Forever quais arquivos existem. Sem arte própria: botão padrão.
const DUNGEON_ART = JSON.parse(fs.readFileSync(path.join(__dirname, "dungeon-art.json"), "utf8"));
const ART_ALIAS = [
  [/^scarletmonastery/, "scarletmonastery"], [/^diremaul/, "diremaul"], [/blackrockspire$/, "blackrockspire"],
  [/^templeofatalhakkar$/, "sunkentemple"], [/^stockade$/, "thestockade"], [/^onyxiaslair$/, "onyxia"],
  [/^hyjalsummit$/, "hyjalpast"],
];
function dungeonArt(name) {
  let k = String(name).toLowerCase().replace(/^the /, "").replace(/[^a-z0-9]/g, "");
  for (const [re, to] of ART_ALIAS) if (re.test(k)) { k = to; break; }
  const find = (tab) => Object.keys(tab).find((x) => x === k || (k.length > 5 && x.startsWith(k)));
  const ej = find(DUNGEON_ART.ej);
  if (ej) return "ej" + DUNGEON_ART.ej[ej];
  const lfg = find(DUNGEON_ART.lfg);
  if (lfg) return "lfg" + DUNGEON_ART.lfg[lfg];
  return "ej" + DUNGEON_ART.ej.default;
}

function pfItem(id, name, drops, objs, vendors) {
  const recipe = /^(?:Pattern|Plans|Schematic|Recipe|Formula|Design|Manual):/i.test(name);
  return { id, name, drops, objs, vendors, qRewards: [], ilvl: 0, req: 0, cid: recipe ? 9 : 0, scid: 0 };
}

function main() {
  const qItems = readKind(QDB_DIR, "Items.lua", "items");
  const npcs = readKind(QDB_DIR, "Npcs.lua", "npcs");
  const objects = readKind(QDB_DIR, "Objects.lua", "objects");
  const metaMap = readItemMeta();
  const extraNames = new Map();
  const extraSrc = new Map();
  readForeverLeveling(extraNames, extraSrc);

  const pf = readPfQuest(npcs);
  const qmRates = pf.rates;
  const qmNpcs = pf.npcs;
  const qmItems = pf.items;

  // AzerothCore: recompensas só de missões que existem no Forever
  const foreverQuests = readKind(QDB_DIR, "Quests.lua", "quests");
  let acRw = 0;
  for (const [it, qs] of readAcQuestRewards()) {
    const list = [...qs].filter((q) => foreverQuests.has(q));
    if (!list.length) continue;
    let rec = qmItems.get(it);
    if (!rec) qmItems.set(it, rec = pfItem(it, pf.itemNames.get(it) || "", [], [], []));
    rec.qRewards = list;
    acRw++;
  }
  const acLoot = readAcLoot();
  const acVendors = readAcVendors();
  // vendedor do item (pfQuest V ou npc_vendor do AzerothCore): a fonte sai como "n<id>:v" (Loja)
  const sells = (item, npc) => !!((qmItems.get(item) && qmItems.get(item).vendors.includes(npc))
    || (acVendors.get(item) && acVendors.get(item).has(npc)));
  console.log(`AzerothCore: ${acRw} itens com recompensa no Forever, ${acLoot.size} itens com loot`);
  const ptItemNames = readPtBRItemNames();
  // nomes que faltarem: pt-BR do QuestieDB (Forever/Classic) e da tabela do cliente; inglês do cliente
  for (const src of [questieNames("Items"), clientItemNames("ptBR")]) {
    for (const [id, n] of src) if (!ptItemNames.has(id)) ptItemNames.set(id, n);
  }
  const enItemNames = clientItemNames("enUS");
  const clientItems = readClientItems();
  const pst = readPtNames();
  const ptSrcNames = {
    n: new Map([...(pst.npc || []), ...questieNames("Npcs")]),
    o: new Map([...(pst.object || []), ...questieNames("Objects")]),
  };

  const recipeByProduct = new Map(); // lowercase enName -> qmItem
  for (const rqm of qmItems.values()) {
    if (rqm.cid === 9 && rqm.name) {
      const m = rqm.name.match(/^(?:Pattern|Plans|Schematic|Recipe|Formula|Design|Manual):\s*(.+)$/i);
      if (m) {
        const prod = m[1].trim().toLowerCase();
        if (!recipeByProduct.has(prod)) recipeByProduct.set(prod, rqm);
      }
    }
  }
  const usedRecipes = new Map(); // recipeID -> pt/en name

  const usedSrc = new Map(); // key -> { name, map, x, y, area? }
  // fonte sem posição: completa pelo QuestieDB (posição no mundo aberto, ou a zona da masmorra em "area")
  const qSpawns = readQuestieSpawns();
  let qPos = 0, qArea = 0;
  const rawSet = usedSrc.set.bind(usedSrc);
  usedSrc.set = (key, rec) => {
    const sp = !(rec.map > 0) && qSpawns.get(key);
    if (sp) {
      const open = sp.find((c) => c[1] > 0 && c[2] > 0 && pf.zoneToUi.has(c[0]));
      if (open) { rec.map = pf.zoneToUi.get(open[0]); rec.x = open[1]; rec.y = open[2]; qPos++; }
      else { rec.area = sp[0][0]; qArea++; }
    }
    return rawSet(key, rec);
  };
  const ensureNpc = (nid) => {
    const key = "n" + nid;
    if (usedSrc.has(key)) return key;
    if (npcs.has(nid)) {
      const ent = npcs.get(nid);
      const [map, x, y] = firstSpawn(ent);
      usedSrc.set(key, { name: (ent[0] || ("NPC " + nid)).replace(/[\r\n\t;]/g, " "), map: map || 0, x: x || 0, y: y || 0 });
      return key;
    }
    if (qmNpcs.has(nid)) {
      const qn = qmNpcs.get(nid);
      usedSrc.set(key, { name: qn.name.replace(/[\r\n\t;]/g, " "), map: qn.map || 0, x: qn.x || 0, y: qn.y || 0 });
      return key;
    }
    return null;
  };

  const ensureObj = (oid) => {
    const key = "o" + oid;
    if (usedSrc.has(key)) return key;
    const ent = objects.get(oid);
    if (ent) {
      const [map, x, y] = firstSpawn(ent);
      usedSrc.set(key, { name: (ent[0] || ("Objeto " + oid)).replace(/[\r\n\t;]/g, " "), map: map || 0, x: x || 0, y: y || 0 });
      return key;
    }
    const po = pf.objs.get(oid);
    if (po) {
      usedSrc.set(key, { name: po.name.replace(/[\r\n\t;]/g, " "), map: po.map || 0, x: po.x || 0, y: po.y || 0 });
      return key;
    }
    return null;
  };

  const itemLines = [];
  const emitted = new Set();    // itens que entraram no ItemDrops
  const finalPct = new Map();   // "chave|item" -> % final (OneForAll, AzerothCore ou pfQuest)
  // OneForAll (GPL-3.0+): loot dos chefes e dos inimigos comuns de masmorras/raides do Forever, com %.
  // Chefe conhecido pelo Polestar/pfQuest usa a fonte dele ("n<id>"); chefe novo do Forever vira "b<m>_<c>";
  // o loot de inimigos comuns de cada masmorra vira "t<m>". A zona da masmorra vem do QuestieDB.
  const ofa = readOneForAll();
  const ofaSrc = new Map();  // item -> [{ key, pct }]
  const ofaMeta = new Map(); // item -> { name, slot, quality }
  const putOfa = (it, key, pct) => {
    if (!ofaSrc.has(it.id)) ofaSrc.set(it.id, []);
    if (!ofaSrc.get(it.id).some((o) => o.key === key)) ofaSrc.get(it.id).push({ key, pct });
    if (!ofaMeta.has(it.id)) ofaMeta.set(it.id, it);
  };
  const clean = (s) => String(s).replace(/[\r\n\t;,:]/g, " ");
  const bossKey = new Map(); // npcID do chefe -> chave da fonte
  // catálogo da aba Masmorras (Data/Quests/Dungeons.lua): masmorra -> chefes -> itens
  const catalog = [];
  const tr = makeTranslator(); // nomes pt-BR de masmorras e chefes
  const catBoss = new Map(); // chave da fonte -> chefe do catálogo
  ofa.dungeons.forEach((d, di) => {
    const nm = tr.dungeon(d.name);
    const cd = { name: d.name, pt: nm.pt, level: d.level, location: d.location, raid: d.raid, area: 0, bosses: [] };
    catalog.push(cd);
    let area = 0;
    for (const b of d.bosses) {
      const sp = b.npcID && qSpawns.get("n" + b.npcID);
      if (sp) { area = sp[0][0]; break; }
    }
    d.bosses.forEach((b, bi) => {
      let key = b.npcID ? ensureNpc(b.npcID) : null;
      if (!key) {
        key = "b" + di + "_" + bi;
        // sem zona conhecida (masmorra nova do Forever): o nome da masmorra vai junto do chefe
        const bPt = tr.boss(b.name, b.npcID, nm.mapID) || b.name;
        usedSrc.set(key, {
          name: clean(area ? b.name : b.name + " (" + d.name + ")"),
          pt: clean(area ? bPt : bPt + " (" + (nm.pt || d.name) + ")"),
          map: 0, x: 0, y: 0, area: area || undefined,
        });
      }
      if (b.npcID) bossKey.set(b.npcID, key);
      for (const it of b.loot) putOfa(it, key, ofa.chance(d.name, b.name, it.id));
      if (!catBoss.has(key)) {
        const cb = { key, name: b.name, pt: tr.boss(b.name, b.npcID, nm.mapID), display: b.displayID, items: b.loot.map((it) => it.id) };
        cd.bosses.push(cb);
        catBoss.set(key, cb);
      }
    });
    if (d.trash.length) {
      const key = "t" + di;
      usedSrc.set(key, {
        name: clean(area ? "Common enemies" : "Common enemies (" + d.name + ")"),
        pt: clean(area ? "Inimigos comuns" : "Inimigos comuns (" + (nm.pt || d.name) + ")"),
        map: 0, x: 0, y: 0, area: area || undefined,
      });
      for (const it of d.trash) putOfa(it, key, 0);
      const cb = { key, name: "Common enemies", pt: "Inimigos comuns", display: 0, items: d.trash.map((it) => it.id) };
      cd.bosses.push(cb);
      catBoss.set(key, cb);
    }
    cd.area = area || nm.area;
  });
  // receitas dropadas por chefes (sem %: vêm de um pool compartilhado de chance baixa)
  for (const [npc, list] of ofa.recipeDrops) {
    const key = bossKey.get(npc) || ensureNpc(npc);
    if (!key) continue;
    for (const rid of list) {
      const makes = ofa.recipeMakes.get(rid);
      putOfa({ id: rid, name: makes ? "Receita: " + makes : "", slot: "", quality: 2 }, key, 0);
      const cb = catBoss.get(key);
      if (cb && !cb.items.includes(rid)) cb.items.push(rid);
    }
  }
  console.log(`OneForAll: ${ofa.dungeons.length} masmorras, ${ofaSrc.size} itens`);

  const allIDs = new Set([...qItems.keys(), ...extraSrc.keys(), ...qmItems.keys(), ...acLoot.keys(), ...ofaSrc.keys()]);

  for (const id of allIDs) {
    const rec = qItems.get(id);
    const meta = metaMap.get(id);
    const qm = qmItems.get(id);
    const om = ofaMeta.get(id);
    const enName = ((rec && rec[0]) || extraNames.get(id) || (qm && qm.name) || (om && om.name) || enItemNames.get(id) || "").replace(/[\r\n\t;]/g, " ");
    const ptName = (ptItemNames.get(id) || "").replace(/[\r\n\t;]/g, " ");
    const name = ptName || enName;
    if (!name) continue;
    const altName = (ptName && enName && ptName !== enName) ? enName : "";

    const sources = [];
    const seenKeys = new Set();
    let kindMask = 0;

    if (rec) {
      let idx = 1;
      const npcCount = rec[idx++] || 0;
      for (let k = 0; k < npcCount; k++) {
        const nid = rec[idx++], chance = rec[idx++];
        const key = nid && ensureNpc(nid);
        if (key && !seenKeys.has(key)) {
          seenKeys.add(key);
          const s = usedSrc.get(key);
          kindMask |= (s.map > 0) ? 1 : 2;
          sources.push(key + ":" + (chance || 0));
        }
      }
      const objCount = rec[idx++] || 0;
      for (let k = 0; k < objCount; k++) {
        const oid = rec[idx++], chance = rec[idx++];
        if (oid && objects.has(oid)) {
          const key = "o" + oid;
          if (!seenKeys.has(key)) {
            seenKeys.add(key);
            const ent = objects.get(oid);
            const [map, x, y] = firstSpawn(ent);
            usedSrc.set(key, { name: (ent[0] || ("Objeto " + oid)).replace(/[\r\n\t;]/g, " "), map: map || 0, x: x || 0, y: y || 0 });
            kindMask |= 1;
            sources.push(key + ":" + (chance || 0));
          }
        }
      }
    }

    const ex = extraSrc.get(id);
    if (ex) {
      for (const s of ex) {
        if (s.kind === "craft") {
          kindMask |= 4;
          const rqm = enName ? recipeByProduct.get(enName.toLowerCase()) : null;
          if (rqm) {
            usedRecipes.set(rqm.id, (ptItemNames.get(rqm.id) || rqm.name).replace(/[\r\n\t;]/g, " "));
            sources.push("c:" + s.prof + ":" + s.skill + ":" + rqm.id);
            const rRateMap = qmRates.get(rqm.id);
            let rAdded = 0;
            for (const nid of rqm.vendors || []) {
              if (rAdded >= 3 || sources.length >= 6) break;
              const key = ensureNpc(nid);
              if (key && !seenKeys.has("r" + key)) {
                seenKeys.add("r" + key);
                sources.push("r:" + key + ":v");
                rAdded++;
              }
            }
            for (const nid of rqm.drops || []) {
              if (rAdded >= 3 || sources.length >= 6) break;
              const key = ensureNpc(nid);
              if (key && !seenKeys.has("r" + key)) {
                seenKeys.add("r" + key);
                const pct = (rRateMap && rRateMap.get(nid)) || 0;
                sources.push("r:" + key + ":" + pct);
                rAdded++;
              }
            }
            for (const qid of rqm.qRewards || []) {
              if (rAdded >= 3 || sources.length >= 6) break;
              sources.push("r:q" + qid + ":100");
              rAdded++;
            }
          } else {
            sources.push("c:" + s.prof + ":" + s.skill);
          }
        } else if (s.kind === "quest") {
          kindMask |= 8;
          sources.push("q:" + s.questId);
        } else if (s.kind === "drop") {
          const key = s.npc > 0 && ensureNpc(s.npc);
          if (key && !seenKeys.has(key)) {
            seenKeys.add(key);
            const info = usedSrc.get(key);
            kindMask |= (info.map > 0) ? 1 : 2;
            sources.push(key + ":" + (s.pct || 0));
          } else if (s.zone > 0) {
            kindMask |= 2;
            sources.push("i" + s.zone + ":" + (s.pct || 0));
          }
        }
      }
    }

    if (qm) {
      const rateMap = qmRates.get(id);
      for (const nid of qm.drops) {
        if (sources.length >= 6) break;
        const key = ensureNpc(nid);
        if (key && !seenKeys.has(key)) {
          seenKeys.add(key);
          const info = usedSrc.get(key);
          kindMask |= (info.map > 0) ? 1 : 2;
          const pct = (rateMap && rateMap.get(nid)) || 0;
          sources.push(key + ":" + pct);
        }
      }
      for (const nid of qm.vendors || []) {
        if (sources.length >= 6) break;
        const key = ensureNpc(nid);
        if (key && !seenKeys.has(key)) {
          seenKeys.add(key);
          const info = usedSrc.get(key);
          kindMask |= (info.map > 0) ? 1 : 2;
          sources.push(key + ":0");
        }
      }
      for (const oid of qm.objs || []) {
        if (sources.length >= 6) break;
        const key = ensureObj(oid);
        if (key && !seenKeys.has(key)) {
          seenKeys.add(key);
          kindMask |= usedSrc.get(key).map > 0 ? 1 : 2;
          sources.push(key + ":0");
        }
      }
      for (const qid of qm.qRewards || []) {
        if (sources.length >= 6) break;
        kindMask |= 8;
        if (!sources.some((x) => x === "q:" + qid)) sources.push("q:" + qid);
      }
    }

    const acl = acLoot.get(id);
    if (acl) {
      for (const a of acl) {
        const at = sources.findIndex((x) => x.startsWith(a.key + ":"));
        if (at >= 0) { if (/:0$/.test(sources[at])) sources[at] = a.key + ":" + a.pct; continue; }
        if (sources.length >= 6) continue;
        const key = a.key[0] === "n" ? ensureNpc(Number(a.key.slice(1))) : ensureObj(Number(a.key.slice(1)));
        if (!key || seenKeys.has(key)) continue;
        seenKeys.add(key);
        kindMask |= usedSrc.get(key).map > 0 ? 1 : 2;
        sources.push(key + ":" + a.pct);
      }
    }

    // OneForAll: o chefe da masmorra entra na frente (é a fonte mais útil); se já existe, completa a %
    const ofl = ofaSrc.get(id);
    if (ofl) {
      for (const o of ofl.slice().reverse()) {
        const at = sources.findIndex((x) => x.startsWith(o.key + ":"));
        if (at >= 0) {
          if (/:0$/.test(sources[at]) && o.pct > 0) sources[at] = o.key + ":" + o.pct;
          continue;
        }
        seenKeys.add(o.key);
        sources.unshift(o.key + ":" + o.pct);
      }
    }

    // fontes sem chance: chance exata do AzerothCore para essa criatura/objeto, ou "v" se ela vende o item
    for (let i = 0; i < sources.length; i++) {
      const m = sources[i].match(/^([no])(\d+):0$/);
      if (!m) continue;
      const pct = acLoot.chance(id, m[1] + m[2]);
      if (pct > 0) sources[i] = m[1] + m[2] + ":" + pct;
      else if (m[1] === "n" && sells(id, Number(m[2]))) sources[i] = "n" + m[2] + ":v";
    }
    // mundo (1) / masmorra (2) recalculados: vendedor conta como mundo, mesmo sem posição
    kindMask &= ~3;
    for (const x of sources) {
      const m = x.match(/^([no]\d+|i\d+|b\d+_\d+|t\d+):(.*)$/);
      if (!m) continue;
      if ("ibt".includes(m[1][0])) { kindMask |= 2; continue; }
      const info = usedSrc.get(m[1]);
      kindMask |= (m[2] === "v" || (info && info.map > 0)) ? 1 : 2;
    }

    if (sources.length === 0) continue;

    const os = om ? (/^Receita: /.test(om.name) ? { cid: 9, scid: 0, inv: 0 } : slotInfo(om.slot)) : null; // fatia pelo texto do OneForAll, se o ItemDB não souber
    // o próprio cliente manda na classe/subclasse/encaixe (o ItemDB do Polestar só classifica equipamento)
    const ci = clientItems.get(id);
    const hasCi = ci && ci.cid !== undefined;
    const q = (ci && ci.q) || (meta ? meta.quality : ((om && om.quality) || 1));
    const req = (meta && meta.req) || (ci && ci.req) || (qm && qm.req) || 0;
    const ilvl = (meta && meta.ilvl) || (ci && ci.ilvl) || (qm && qm.ilvl) || 0;
    const cid = hasCi ? ci.cid : ((meta && meta.classID) || (qm && qm.cid) || (os && os.cid) || 0);
    const scid = hasCi ? ci.scid : ((meta && meta.subclassID) || (qm && qm.scid) || (os && os.scid) || 0);
    const inv = (hasCi && ci.inv) || (meta && meta.inv) || (os && os.inv) || 0;
    const stats = (meta && meta.stats) || "";
    // 13º campo: etiqueta fina dos consumíveis (comida por atributo, poção de vida/mana...)
    const tag = consumableTag(enName, ci && ci.use, cid, scid);

    emitted.add(id);
    for (const x of sources) {
      const m = x.match(/^([no]\d+|b\d+_\d+|t\d+):([\d.]+)$/);
      if (m && catBoss.has(m[1])) finalPct.set(m[1] + "|" + id, Number(m[2]));
    }
    itemLines.push([
      id, q, req, ilvl, cid, scid, inv, kindMask || 1, name, stats, sources.slice(0, 6).join(","), altName, tag
    ].join("\t"));
  }

  console.log(`QuestieDB: ${qPos} fontes ganharam posição, ${qArea} ganharam a zona da masmorra`);
  const srcLines = [];
  for (const [key, s] of usedSrc.entries()) {
    // 6º campo: zona da masmorra (0 = nenhuma); 7º: nome em pt-BR (vazio = igual ao inglês)
    const pt = s.pt || ((key[0] === "n" || key[0] === "o") && ptSrcNames[key[0]].get(Number(key.slice(1)))) || "";
    srcLines.push([key, s.name, s.map, s.x, s.y, s.area || 0, pt !== s.name ? String(pt).replace(/[\r\n\t]/g, " ") : ""].join("\t"));
  }
  const recLines = [];
  for (const [rid, rname] of usedRecipes.entries()) {
    recLines.push(rid + "\t" + rname);
  }

  fs.mkdirSync(path.dirname(OUT_FILE), { recursive: true });
  const content = [
    "-- GERADO por tools/map-extract/itemdrops.js. Não edite à mão.",
    "local _, Azaath = ...",
    "Azaath.ItemDropsRecipesRaw = [[",
    recLines.join("\n"),
    "]]",
    "Azaath.ItemDropsSrcRaw = [[",
    srcLines.join("\n"),
    "]]",
    "Azaath.ItemDropsRaw = [[",
    itemLines.join("\n"),
    "]]",
    "",
  ].join("\n");

  fs.writeFileSync(OUT_FILE, content, "utf8");
  const kb = (fs.statSync(OUT_FILE).size / 1024).toFixed(1);
  console.log(`Gerado ${OUT_FILE}: ${itemLines.length} itens, ${srcLines.length} fontes (${kb} KB)`);

  // Catálogo da aba Masmorras: D = masmorra (nome, nível, local, raide 0/1, zona AreaTable),
  // B = chefe (chave da fonte em ItemDropsSrcRaw, nome, itens "id:%"; % 0 = desconhecida)
  const catLines = [];
  let nb = 0, ni = 0;
  for (const d of catalog) {
    const bosses = d.bosses.map((b) => ({ b, items: b.items.filter((it) => emitted.has(it)) }));
    const txt = (s) => String(s).replace(/[\r\n\t]/g, " "); // no catálogo só tab e quebra de linha atrapalham
    catLines.push(["D", txt(d.name), txt(d.level), txt(d.location), d.raid ? 1 : 0, d.area || 0, dungeonArt(d.name), txt(d.pt || ""), txt(locationPt(d.location))].join("\t"));
    for (const { b, items } of bosses) {
      catLines.push(["B", b.key, txt(b.name), items.map((it) => it + ":" + (finalPct.get(b.key + "|" + it) || 0)).join(","), b.display || 0, txt(b.pt || "")].join("\t"));
      nb++; ni += items.length;
    }
  }
  const CAT_FILE = path.join(path.dirname(OUT_FILE), "Dungeons.lua");
  fs.writeFileSync(CAT_FILE, [
    "-- GERADO por tools/map-extract/itemdrops.js a partir do OneForAll (GPL-3.0+; ver ItemDrops-NOTICE.txt). Não edite à mão.",
    "local _, Azaath = ...",
    "Azaath.DungeonCatalogRaw = [[",
    catLines.join("\n"),
    "]]",
    "",
  ].join("\n"), "utf8");
  console.log(`Gerado ${CAT_FILE}: ${catalog.length} masmorras, ${nb} chefes, ${ni} itens`);
}

main();
