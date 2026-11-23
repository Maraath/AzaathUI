// Gera Data/Quests/DungeonQuests.lua: missões de cada masmorra/raide do catálogo do Azaath
// (aba Masmorras do Santuário), com cadeias, quem dá/recebe, recompensas e restrições.
// Fonte: Dungeon Master 2.x (MalkDev, GPL-3.0), arquivos Data.lua e Curated.lua copiados em
// thirdparty/dungeonmaster (VERSAO.txt = versão). Os dados do DM vêm do cMaNGOS classic-db
// (GPL-3.0) e, no Curated.lua, de correções do Forever (parte vinda do QuestieDB, GPL-3.0).
// Os arquivos são só LIDOS como texto (parseLua do oneforall.js), nunca executados.
// Uso: node tools/map-extract/dungeonquests.js
"use strict";
const fs = require("fs");
const path = require("path");
const { parseLua } = require("./oneforall.js");
const { readPtNames, questieNames, clientItemNames } = require("./names-ptbr.js");
const { readCache, cleanGameText } = require("./wdb-cache.js");
const { wowheadPt } = require("./wowhead-pt.js");

const DM_DIR = process.env.DM_DB || path.join(__dirname, "thirdparty/dungeonmaster");
const OUT_FILE = path.join(__dirname, "../../AzaathUI/Data/Quests/DungeonQuests.lua");
// Português: títulos e objetivos do ForeverLoremaster (GPL-3.0-or-later; textos do QuestieDB, GPL-3.0),
// NPCs pelos nomes do cliente (Polestar_ptBR) e do QuestieDB l10n; quem recebe a missão sai do endId do
// nosso QuestDB.lua (também do ForeverLoremaster). As dicas escritas à mão no DM são traduzidas aqui.
const FL_DIR = process.env.FL_DIR || "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/ForeverLoremaster/Data";
const QUESTDB = path.join(__dirname, "../../AzaathUI/Data/Quests/QuestDB.lua");
const NPC_DB = path.join(__dirname, "thirdparty/questiedb/classicNpcDB.lua");
const TIP_PT = { // nomes próprios ficam como no original (sem tradução oficial conferida)
  "Comes after Rot and Regret, a Maraudon quest: most players do it after Maraudon (to be confirmed).":
    "Vem depois de Rot and Regret, missão de Maraudon: a maioria faz depois de Maraudon (a confirmar).",
  "Don't kill The Questioner before Blazeroar, or the prisoner won't offer this quest. The chain that follows rewards a Fractured Insignia: collect 6 to make the Alcaz Operative Insignia toy (a Defias disguise).":
    "Não mate The Questioner antes de Blazeroar, senão o prisioneiro não oferece esta missão. A cadeia seguinte dá uma Fractured Insignia: junte 6 para fazer o brinquedo Alcaz Operative Insignia (um disfarce Defias).",
  "Mithera only offers this quest after you unlock Shen'dralas: first do the quest line that starts at the pylon (players mention What They've Done to My Peonies).":
    "Mithera só oferece esta missão depois que você desbloqueia os Shen'dralas: antes faça a sequência que começa no pilar (jogadores citam What They've Done to My Peonies).",
  "Repeatable, inside the dungeon: past Elder Shaman Bloodmane, take the north exit to the Flesh-Eating Lasher and trade it Fel-Tainted Flesh from the Legashi satyrs. The Regurgitated Seed Pod can hold the Wilted Lashling pet.":
    "Repetível, dentro da masmorra: depois de Elder Shaman Bloodmane, pegue a saída norte até o Flesh-Eating Lasher e troque com ele Fel-Tainted Flesh dos sátiros Legashi. A Regurgitated Seed Pod pode conter o mascote Wilted Lashling.",
  "Seems to be an escort that starts inside the dungeon (to be confirmed).":
    "Parece ser uma escolta que começa dentro da masmorra (a confirmar).",
  "Starts in Razorfen Kraul: the Small Scroll drops from the last boss, Charlga Razorflank.":
    "Começa em Razorfen Kraul: o Small Scroll cai do último chefe, Charlga Razorflank.",
  "The Ancient Gurubashi Idol drops from Deathless Marrow (Deathless Guardians).":
    "O Ancient Gurubashi Idol cai de Deathless Marrow (Deathless Guardians).",
  "The Damp Note drops from the Blackfathom Tide Priestesses in the ruins outside the dungeon entrance, only once you have picked up The Essence of Aku'Mai (in your log or already completed).":
    "A Damp Note cai das Blackfathom Tide Priestesses nas ruínas do lado de fora da entrada, só depois que você pegou The Essence of Aku'Mai (no diário ou já concluída).",
  "The four Tablets of I'lalai: down to the left after Zul'Alai, half inside a skull in the pirate area, by Var'Taka's room and by Min'loth the Serpent's room.":
    "As quatro Tablets of I'lalai: descendo à esquerda depois de Zul'Alai, meio dentro de uma caveira na área dos piratas, junto à sala de Var'Taka e junto à sala de Min'loth the Serpent.",
  "The mold drops from Tunk, at the blacksmith next to War Handler Ashka. Everyone in the group gets one.":
    "O molde cai de Tunk, na forja ao lado de War Handler Ashka. Todos do grupo ganham um.",
  "You need to be at least Friendly with Timbermaw Hold to talk to these NPCs and pick up the quest (to be confirmed).":
    "É preciso ser pelo menos Amistoso com Timbermaw Hold para falar com esses NPCs e pegar a missão (a confirmar).",
  "Zalfan Moonshadow is just past Tunk, on the way to the bridge.":
    "Zalfan Moonshadow fica logo depois de Tunk, no caminho para a ponte.",
};

// texto de verdade (o jogo usa "<SEM DESCRIÇÃO DE REGISTRO>" e afins como marcador de vazio)
const realText = (s) => !!s && !/^s*<[^>]*>s*$/.test(s);

// "NPCs" que no DM são descrições, não nomes do jogo; termos oficiais conferidos nos nomes pt do cliente
const DESCRIPTIVE_PT = {
  "Twilight's Hammer cultists": "cultistas do Martelo do Crepúsculo",
  "Ravasaurs (Hunter, Juvenile, Matriarch, Trapper)": "Ravassauros (Ravassauro Caçador, Matriarca Ravassauro e outros)",
};

// [id] = "texto" no primeiro nível de uma tabela Lua (uma tabulação de recuo)
function readLuaStrings(file) {
  const out = new Map();
  if (!fs.existsSync(file)) { console.warn("faltando: " + file); return out; }
  const src = fs.readFileSync(file, "utf8");
  for (const m of src.matchAll(/^\t\[(\d+)\] = "((?:\\.|[^"\\])*)"/gm)) {
    out.set(Number(m[1]), m[2].replace(/\\n/g, " ").replace(/\\(.)/g, "$1"));
  }
  return out;
}

// instância do DM (ID do mapa) -> nome da masmorra no catálogo do Azaath (Data/Quests/Dungeons.lua).
// Instâncias com alas (Monastério, Pico) usam a lista "wings" do próprio DM; Gládio Cruel (429)
// não é dividido no DM, então as missões valem para as três alas do catálogo.
const INSTANCE = {
  33: ["Shadowfang Keep"], 34: ["The Stockade"], 36: ["The Deadmines"], 43: ["Wailing Caverns"],
  47: ["Razorfen Kraul"], 48: ["Blackfathom Deeps"], 70: ["Uldaman"], 90: ["Gnomeregan"],
  109: ["The Temple of Atal'Hakkar"], 129: ["Razorfen Downs"], 209: ["Zul'Farrak"],
  230: ["Blackrock Depths"], 249: ["Onyxia's Lair"], 289: ["Scholomance"], 329: ["Stratholme"],
  349: ["Maraudon"], 389: ["Ragefire Chasm"],
  429: ["Dire Maul: East", "Dire Maul: North", "Dire Maul: West"],
  2959: ["City of Dalaran"], 2970: ["The Drowned City"], 2974: ["Blackmaw Hold"], 2981: ["Hyjal Summit"],
  2994: ["Alcaz Prison"], 2998: ["Excavation Site: Wetlands"], 2999: ["Ruins of Lordaeron"],
  3001: ["Shaper's Terrace"], 3039: ["Krol'dok Stronghold"], 3052: ["Barrow Deeps"], 3065: ["Hall of Thanes"],
};
const WINGS = {
  189: { Graveyard: "Scarlet Monastery: Graveyard", Library: "Scarlet Monastery: Library",
         Armory: "Scarlet Monastery: Armory", Cathedral: "Scarlet Monastery: Cathedral" },
  229: { Lower: "Lower Blackrock Spire", Upper: "Upper Blackrock Spire" },
};
// mesmas regras fixas do Harvest.lua do DM
const EXCLUDED = new Set([1654, 1740, 95036]);
const CLASS_ONLY = {};
for (const id of [96264, 94789, 79358, 96135, 96016, 79360, 79364, 79361, 79366, 79442, 7668]) CLASS_ONLY[id] = ["SHAMAN"];
CLASS_ONLY[82084] = ["MAGE"];
const OPTIONAL = new Set([95737]);

function readTable(file, name) {
  const src = fs.readFileSync(path.join(DM_DIR, file), "utf8");
  const m = new RegExp("ns\\." + name + "\\s*=\\s*").exec(src);
  if (!m) throw new Error(`${file}: ns.${name} não encontrado`);
  return parseLua(src, m.index + m[0].length)[0];
}

// tabela Lua lida como array JS com chaves: copia só os campos
const entries = (t) => Object.keys(t || {}).filter((k) => t[k] != null).map((k) => [k, t[k]]);
const list = (v) => (v && typeof v === "object" ? Object.keys(v).map((k) => v[k]).filter((x) => x != null) : []);

async function main() {
  const data = readTable("Data.lua", "data");
  const dungeons = readTable("Data.lua", "dungeons");
  const questLevels = readTable("Data.lua", "questLevels") || {};
  const stepLevels = readTable("Data.lua", "stepLevels") || {};
  const curated = readTable("Curated.lua", "curated");

  // alas: missão -> ala; ala padrão = a primeira
  const questWing = {}, wingDefault = {};
  for (const inst of Object.keys(WINGS)) {
    const d = dungeons[inst];
    list(d && d.wings).forEach((w, i) => {
      const name = WINGS[inst][w.name];
      if (!name) throw new Error(`ala desconhecida ${inst}/${w.name}`);
      if (i === 0) wingDefault[inst] = name;
      for (const q of list(w.quests)) questWing[q] = name;
    });
  }
  const targets = (inst, id) => {
    if (inst == null) return null;
    if (WINGS[inst]) return [questWing[id] || wingDefault[inst]];
    return INSTANCE[inst] || null;
  };

  // 1) base (Data.lua) -> 2) correções (Curated.lua) -> 3) cadeias -> 4) regras fixas
  const quests = {};
  for (const [k, d] of entries(data)) {
    const id = Number(k), q = {};
    for (const [f, v] of entries(d)) q[f] = v;
    q.dungeons = targets(d.instance, id);
    quests[id] = q;
  }
  const overlay = (id, layer) => {
    const q = quests[id] || (quests[id] = {});
    for (const [f, v] of entries(layer)) if (f !== "chain") q[f] = v;
    return q;
  };
  for (const [k, c] of entries(curated)) {
    const id = Number(k);
    const q = overlay(id, c);
    if (c.instance != null) q.dungeons = targets(c.instance, id);
  }
  for (const [k, c] of entries(curated)) {
    if (!c.chain) continue;
    const id = Number(k), q = quests[id];
    let prev = null;
    for (const step of list(c.chain)) {
      const s = quests[step] || (quests[step] = { forever: step >= 90000 || undefined });
      s.prev = prev || s.prev;
      if (s.faction == null && s.chainFaction == null) { s.faction = q.faction; s.chainFaction = q.faction || "Both"; }
      else if (s.chainFaction && s.chainFaction !== (q.faction || "Both")) { s.faction = undefined; s.chainFaction = "Both"; }
      s.level = s.level || stepLevels[step];
      prev = step;
    }
    q.prev = prev;
  }
  for (const [k, q] of entries(quests)) {
    const id = Number(k);
    if (q.hide) q.dungeons = null;
    const fix = questLevels[id];
    if (fix) { if (fix[0] > 0) q.level = q.level || fix[0]; q.minLevel = fix[1]; }
    q.classes = q.classes || CLASS_ONLY[id];
    q.optional = q.optional || OPTIONAL.has(id);
  }
  for (const id of EXCLUDED) delete quests[id];
  // alternateID (missão com duas versões): o DM escolhe no jogo; aqui fica a principal com o ID
  // alternativo anotado para o addon conferir as duas.
  // ---------------------------------------------------------------------------------------

  // missões finais por masmorra + todos os passos anteriores da cadeia
  const byDungeon = {}, needed = new Set();
  for (const [k, q] of entries(quests)) {
    if (!q.dungeons) continue;
    const id = Number(k);
    for (const dn of q.dungeons) (byDungeon[dn] = byDungeon[dn] || []).push(id);
    for (let s = id, guard = 0; s && quests[s] && guard < 40; s = quests[s].prev, guard++) needed.add(s);
  }

  // checa nomes contra o catálogo do Azaath
  const catalog = fs.readFileSync(path.join(__dirname, "../../AzaathUI/Data/Quests/Dungeons.lua"), "utf8");
  const known = new Set(catalog.split(/\r?\n/).filter((l) => l.startsWith("D\t")).map((l) => l.split("\t")[1]));
  for (const dn of Object.keys(byDungeon)) if (!known.has(dn)) throw new Error(`masmorra fora do catálogo: ${dn}`);

  const clean = (s) => (s == null ? "" : String(s).replace(/[\t\r\n]+/g, " ").replace(/\]\]/g, "] ]"));
  const num = (v) => (v == null || v === "" ? "" : String(v));
  const ids = (v) => list(v).join(",");
  const faction = (f) => (f === "Alliance" ? "A" : f === "Horde" ? "H" : "");
  // ---- português ----
  // ordem: cache do cliente ptBR (o texto que o jogo mostra hoje) > ForeverLoremaster / nomes do Polestar >
  // QuestieDB l10n. Títulos/objetivos por ID da missão; NPCs e objetos por ID, achado pelo nome inglês.
  const cache = readCache("ptBR");
  // QuestieDB l10n/Forever: lookupQuests (base) e traces/lookupQuests (visto no jogo; vence)
  const qieTitle = new Map(), qieObj = new Map();
  for (const file of ["Forever-lookupQuests-ptBR.lua", "Forever-traces-lookupQuests-ptBR.lua"]) {
    const fp = path.join(__dirname, "thirdparty/questiedb/l10n", file);
    if (!fs.existsSync(fp)) continue;
    const unq = (s) => s.replace(/\\(.)/g, "$1");
    for (const m of fs.readFileSync(fp, "utf8").matchAll(/^\[(\d+)\] = \{"((?:\\.|[^"\\])*)"(?:,\s*\{((?:"(?:\\.|[^"\\])*",?\s*)*)\})?/gm)) {
      const id = Number(m[1]);
      if (m[2]) qieTitle.set(id, unq(m[2]));
      const objs = [...(m[3] || "").matchAll(/"((?:\\.|[^"\\])*)"/g)].map((x) => unq(x[1])).filter(Boolean);
      if (objs.length) qieObj.set(id, objs.join(" "));
    }
  }
  const flNames = readLuaStrings(path.join(FL_DIR, "QuestNames_ptBR.lua"));
  const flText = readLuaStrings(path.join(FL_DIR, "QuestText_ptBR.lua"));
  const ptNames = readPtNames();
  const ptNpcPolestar = ptNames.npc || new Map(), ptNpcQuestie = questieNames("Npcs");
  const ptObjPolestar = ptNames.object || new Map(), ptObjQuestie = questieNames("Objects");
  const whNpc = new Map(), whObj = new Map(), whQuest = new Map(); // Wowhead, preenchidos mais abaixo
  const npcPt = (id) => (id && (cache.npcs.get(id) || ptNpcPolestar.get(id) || ptNpcQuestie.get(id) || whNpc.get(id))) || "";
  const objPt = (id) => (id && (cache.objects.get(id) || ptObjPolestar.get(id) || ptObjQuestie.get(id) || whObj.get(id))) || "";
  const norm = (s) => String(s || "").toLowerCase().replace(/[^a-z0-9]/g, "");
  // nomes ingleses por ID: Polestar_QuestDB (inclui o conteúdo novo do Forever) + QuestieDB clássico + DM
  const mk = () => ({ byId: new Map(), byName: new Map() });
  const NPC = mk(), OBJ = mk();
  const addEn = (T, id, name) => {
    if (!id || !name) return;
    if (!T.byId.has(id)) T.byId.set(id, name);
    const k = norm(name), set = T.byName.get(k) || new Set();
    set.add(id);
    T.byName.set(k, set);
  };
  const PQ = process.env.POLESTAR_DB || path.join(__dirname, "../.cache/polestar/Polestar_QuestDB");
  for (const [file, kind, T] of [["Npcs.lua", "npcs", NPC], ["Objects.lua", "objects", OBJ]]) {
    const fp = path.join(PQ, file);
    if (!fs.existsSync(fp)) continue;
    const src = fs.readFileSync(fp, "utf8");
    for (const m of src.matchAll(new RegExp('R\\("' + kind + '",[^\\[]*\\[\\[([\\s\\S]*?)\\]\\]', "g"))) {
      for (const line of m[1].split(/\r?\n/)) {
        const mm = /^(\d+)\t'([^;]*)/.exec(line);
        if (mm) addEn(T, Number(mm[1]), mm[2].replace(/%([0-9a-fA-F]{2})/g, (_, h) => String.fromCharCode(parseInt(h, 16))));
      }
    }
  }
  for (const [file, T] of [[NPC_DB, NPC], [path.join(__dirname, "thirdparty/questiedb/classicObjectDB.lua"), OBJ]]) {
    if (!fs.existsSync(file)) continue;
    for (const m of fs.readFileSync(file, "utf8").matchAll(/^\[(\d+)\] = \{'((?:\\.|[^'\\])*)'/gm)) addEn(T, Number(m[1]), m[2].replace(/\\(.)/g, "$1"));
  }
  for (const [, q] of entries(quests)) if (q.npcID) addEn(NPC, Number(q.npcID), q.npc);
  // startId/endId do nosso QuestDB.lua (colunas 18 e 19)
  const qdbEnds = new Map(), qdbStarts = new Map();
  if (fs.existsSync(QUESTDB)) {
    for (const line of fs.readFileSync(QUESTDB, "utf8").split(/\r?\n/)) {
      const f = line.split("\t");
      if (f.length < 20 || !/^\d+$/.test(f[0])) continue;
      if (Number(f[17])) qdbStarts.set(Number(f[0]), Number(f[17]));
      if (Number(f[18])) qdbEnds.set(Number(f[0]), Number(f[18]));
    }
  }
  // nome pt de quem dá/recebe: pelo ID dica (QuestDB) se o nome inglês bate; senão o único NPC com
  // esse nome; senão o único objeto. "A, B e C" (vários NPCs) traduz cada um.
  const unique = (T, name) => { const set = T.byName.get(norm(name)); return set && set.size === 1 ? [...set][0] : 0; };
  // vários IDs com o mesmo nome inglês (cópias do mesmo objeto/NPC): vale se a tradução é uma só
  // (diferenças só de maiúsculas/pontuação contam como a mesma; fica a grafia mais comum)
  const normPt = (s) => s.toLowerCase().normalize("NFD").replace(/[^\p{L}\p{N}]/gu, "");
  const samePt = (T, name, ptFn) => {
    const set = T.byName.get(norm(name));
    if (!set) return "";
    const names = [...set].map(ptFn).filter(Boolean);
    if (!names.length || new Set(names.map(normPt)).size !== 1) return "";
    const count = new Map();
    for (const n of names) count.set(n, (count.get(n) || 0) + 1);
    return [...count].sort((a, b) => b[1] - a[1])[0][0];
  };
  // missão que começa com um item: quem "dá" é o item (nome pt do cliente, ItemSparse ptBR)
  const itemPtById = clientItemNames("ptBR");
  const itemIdsByEn = new Map();
  for (const [id, n] of clientItemNames("enUS")) {
    const k = norm(n), set = itemIdsByEn.get(k) || new Set();
    set.add(id);
    itemIdsByEn.set(k, set);
  }
  const itemPt = (name) => {
    const set = itemIdsByEn.get(norm(name));
    if (!set) return "";
    const names = new Set([...set].map((id) => itemPtById.get(id)).filter(Boolean));
    return names.size === 1 ? [...names][0] : "";
  };
  const ptOf = (name, hint) => {
    if (!name) return "";
    if (DESCRIPTIVE_PT[name]) return DESCRIPTIVE_PT[name];
    if (hint) {
      if (NPC.byId.has(hint) && norm(NPC.byId.get(hint)) === norm(name) && npcPt(hint)) return npcPt(hint);
      if (OBJ.byId.has(hint) && norm(OBJ.byId.get(hint)) === norm(name) && objPt(hint)) return objPt(hint);
    }
    const n = unique(NPC, name);
    if (n && npcPt(n)) return npcPt(n);
    const o = unique(OBJ, name);
    if (o && objPt(o)) return objPt(o);
    return samePt(NPC, name, npcPt) || samePt(OBJ, name, objPt) || itemPt(name);
  };
  const stat = { title: 0, obj: 0, npc: 0, npcAll: 0, ender: 0, enderAll: 0, tip: 0, tipAll: 0 };

  // ---- o que nenhuma fonte local traduz: pergunta ao Wowhead (seção Forever, pt) ----
  const wants = [];
  const candidates = (name, ...hints) => {
    const out = [];
    for (const h of hints) if (Number(h)) out.push({ kind: NPC.byId.has(Number(h)) || !OBJ.byId.has(Number(h)) ? "npc" : "object", id: Number(h) });
    for (const id of [...(NPC.byName.get(norm(name)) || [])].slice(0, 5)) out.push({ kind: "npc", id });
    for (const id of [...(OBJ.byName.get(norm(name)) || [])].slice(0, 5)) out.push({ kind: "object", id });
    return out;
  };
  for (const id of needed) {
    const q = quests[id];
    const cq = cache.quests.get(id);
    if (!((cq && cq.title) || qieTitle.get(id) || flNames.get(id)) || ![cq && cq.objective, qieObj.get(id), flText.get(id)].find(realText)) {
      wants.push({ kind: "quest", id });
    }
    if (q.npc && !((Number(q.npcID) && npcPt(Number(q.npcID))) || ptOf(q.npc, qdbStarts.get(id)))) wants.push(...candidates(q.npc, q.npcID, qdbStarts.get(id)));
    if (q.ender && !ptOf(q.ender, qdbEnds.get(id))) wants.push(...candidates(q.ender, qdbEnds.get(id)));
  }
  const wh = await wowheadPt(wants);
  for (const [k, v] of wh) {
    if (!v) continue;
    const [kind, sid] = k.split(":");
    if (kind === "npc") whNpc.set(Number(sid), v.name);
    else if (kind === "object") whObj.set(Number(sid), v.name);
    else whQuest.set(Number(sid), v);
  }

  const lines = [];
  for (const dn of Object.keys(byDungeon).sort()) {
    const arr = byDungeon[dn].sort((a, b) => (quests[a].level || 0) - (quests[b].level || 0) || a - b);
    lines.push(["D", dn, arr.join(",")].join("\t"));
  }
  for (const id of [...needed].sort((a, b) => a - b)) {
    const q = quests[id];
    const flags = (q.inside ? "i" : "") + (q.drop || q.item ? "d" : "") + (q.einside ? "e" : "") + (q.breadcrumb ? "b" : "")
      + (q.repeatable ? "r" : "") + (q.optional ? "o" : "") + (q.forever ? "f" : "");
    lines.push(["Q", id, clean(q.name), num(q.level), num(q.minLevel), faction(q.faction), num(q.prev), flags,
      clean(q.npc), num(q.npcID), num(q.map), num(q.x), num(q.y),
      clean(q.ender), num(q.emap), num(q.ex), num(q.ey),
      list(q.classes).join(","), ids(q.choices), ids(q.rewards), num(q.item), num(q.alternateID),
      clean(q.objective), clean(q.tip),
      ...(() => {
        const cq = cache.quests.get(id) || (q.alternateID && cache.quests.get(Number(q.alternateID)));
        const whq = whQuest.get(id) || {};
        const titlePt = (cq && cq.title) || qieTitle.get(id) || flNames.get(id) || whq.name || "";
        const objTxt = cleanGameText([cq && cq.objective, qieObj.get(id), flText.get(id), whq.objective].find(realText) || "");
        const nPt = q.npc ? ((Number(q.npcID) && npcPt(Number(q.npcID))) || ptOf(q.npc, qdbStarts.get(id))) : "";
        const ePt = q.ender ? ptOf(q.ender, qdbEnds.get(id)) : "";
        const tPt = q.tip ? TIP_PT[q.tip] || "" : "";
        if (titlePt) stat.title++;
        if (objTxt) stat.obj++;
        if (q.npc) { stat.npcAll++; if (nPt) stat.npc++; }
        if (q.ender) { stat.enderAll++; if (ePt) stat.ender++; }
        if (q.tip) { stat.tipAll++; if (tPt) stat.tip++; }
        return [clean(titlePt), clean(nPt), clean(ePt), clean(objTxt), clean(tPt)];
      })()].join("\t"));
  }
  const nQ = needed.size;
  console.log(`pt-BR: títulos ${stat.title}/${nQ}, objetivos ${stat.obj}/${nQ}, quem dá ${stat.npc}/${stat.npcAll}, ` +
    `quem recebe ${stat.ender}/${stat.enderAll}, dicas ${stat.tip}/${stat.tipAll}`);

  const version = (fs.readFileSync(path.join(DM_DIR, "VERSAO.txt"), "utf8").match(/[\d.]+/) || ["?"])[0];
  const out = [
    "-- GERADO por tools/map-extract/dungeonquests.js a partir do Dungeon Master " + version + " (MalkDev, GPL-3.0;",
    "-- dados do cMaNGOS classic-db e QuestieDB, GPL-3.0). Ver DungeonQuests-NOTICE.txt. Não edite à mão.",
    "-- D<TAB>masmorra<TAB>missões finais | Q<TAB>id nome nível nívelMín facção anterior flags(i dentro, d começa",
    "-- por item, e entrega dentro, b introdutória, r repetível, o opcional, f nova do Forever) npc npcID mapa x y",
    "-- quemRecebe mapa x y classes escolhas recompensas itemInicial idAlternativo objetivo dica",
    "-- + em pt-BR: título npc quemRecebe objetivo dica (ForeverLoremaster/QuestieDB e nomes do cliente)",
    "local _, Azaath = ...",
    "Azaath.DungeonQuestsRaw = [[",
    ...lines,
    "]]",
    "",
  ].join("\n");
  fs.writeFileSync(OUT_FILE, out, "utf8");
  const nq = lines.filter((l) => l[0] === "Q").length;
  console.log(`DungeonQuests.lua: ${Object.keys(byDungeon).length} masmorras, ${nq} missões (${(out.length / 1024).toFixed(0)} KB)`);
  for (const dn of Object.keys(byDungeon).sort()) console.log("  " + dn + ": " + byDungeon[dn].length);
  const missing = [...known].filter((dn) => !byDungeon[dn]);
  if (missing.length) console.log("sem missões: " + missing.join(", "));
}

main().catch((e) => { console.error(e); process.exit(1); });
