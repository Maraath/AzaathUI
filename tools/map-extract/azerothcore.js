// Leitor do banco do AzerothCore (GPL-2.0 ou posterior; https://github.com/azerothcore/azerothcore-wotlk).
// Usa só as tabelas de recompensa de missão e de loot (criaturas, objetos, referências), baixadas em
// tools/.cache/azerothcore. O chamador filtra pelo que existe no Forever (missões/criaturas/objetos).
"use strict";
const fs = require("fs");
const path = require("path");

const AC_DIR = process.env.AC_DB || path.join(__dirname, "../.cache/azerothcore");

// Lê um dump do mysqldump: devolve as linhas como objetos { coluna: texto }.
function readSqlTable(name) {
  const fp = path.join(AC_DIR, name + ".sql");
  if (!fs.existsSync(fp)) throw new Error("AzerothCore: faltou " + fp);
  const s = fs.readFileSync(fp, "utf8");
  const head = s.match(new RegExp("CREATE TABLE `" + name + "` \\(([\\s\\S]*?)\\n\\)"));
  const cols = [...head[1].matchAll(/^\s*`(\w+)`/gm)].map((m) => m[1]);
  const rows = [];
  const re = new RegExp("INSERT INTO `" + name + "` VALUES\\s*", "g");
  let ins;
  while ((ins = re.exec(s))) {
    let row = null, val = "", inStr = false;
    for (let i = ins.index + ins[0].length; i < s.length; i++) {
      const c = s[i];
      if (inStr) {
        if (c === "\\") { val += s[++i]; continue; }
        if (c === "'") { inStr = false; continue; }
        val += c; continue;
      }
      if (c === "'") { inStr = true; continue; }
      if (c === "(" && !row) { row = []; val = ""; continue; }
      if (c === "," && row) { row.push(val); val = ""; continue; }
      if (c === ")" && row) {
        row.push(val);
        const o = {};
        for (let k = 0; k < cols.length; k++) o[cols[k]] = row[k];
        rows.push(o);
        row = null; continue;
      }
      if (row) val += c; else if (c === ";") break;
    }
  }
  return rows;
}

// item -> Set(missão)
function readAcQuestRewards() {
  const out = new Map();
  const KEYS = ["RewardItem1", "RewardItem2", "RewardItem3", "RewardItem4",
    "RewardChoiceItemID1", "RewardChoiceItemID2", "RewardChoiceItemID3",
    "RewardChoiceItemID4", "RewardChoiceItemID5", "RewardChoiceItemID6"];
  for (const q of readSqlTable("quest_template")) {
    const title = q.LogTitle || "";
    if (/^\s*[<[]|\(123\)|UNUSED|DEPRECATED|\bTEST\b/i.test(title)) continue;
    for (const k of KEYS) {
      const it = Number(q[k]);
      if (it > 0) {
        if (!out.has(it)) out.set(it, new Set());
        out.get(it).add(Number(q.ID));
      }
    }
  }
  return out;
}

// Agrupa as linhas de uma tabela de loot por entrada.
function byEntry(rows) {
  const m = new Map();
  for (const r of rows) {
    const e = Number(r.Entry);
    if (!m.has(e)) m.set(e, []);
    m.get(e).push({ item: Number(r.Item), ref: Number(r.Reference), chance: Math.abs(Number(r.Chance)) || 0, group: Number(r.GroupId) || 0 });
  }
  return m;
}

// Chance efetiva (%) de cada linha: grupos dividem o que sobra entre as linhas de chance 0.
function rowChances(list) {
  const groups = new Map();
  for (const r of list) if (r.group > 0) {
    const g = groups.get(r.group) || { sum: 0, zero: 0 };
    if (r.chance > 0) g.sum += r.chance; else g.zero++;
    groups.set(r.group, g);
  }
  return list.map((r) => {
    if (r.group > 0 && r.chance === 0) {
      const g = groups.get(r.group);
      return Math.max(0, 100 - g.sum) / g.zero;
    }
    return r.group === 0 && r.chance === 0 ? 100 : r.chance;
  });
}

// item -> [{ key: "n<id>"|"o<id>", pct }] (as maiores chances primeiro, no máximo `keep` por item)
function readAcLoot(keep = 12) {
  const refs = byEntry(readSqlTable("reference_loot_template"));
  const refCache = new Map();
  const expandRef = (id, depth) => { // ref -> Map(item -> %)
    if (refCache.has(id)) return refCache.get(id);
    const out = new Map();
    refCache.set(id, out);
    const list = refs.get(id) || [];
    const ch = rowChances(list);
    list.forEach((r, i) => {
      if (r.ref > 0 && depth < 4) {
        for (const [it, p] of expandRef(r.ref, depth + 1)) out.set(it, Math.max(out.get(it) || 0, p * ch[i] / 100));
      } else if (r.item > 0) out.set(r.item, Math.max(out.get(r.item) || 0, ch[i]));
    });
    return out;
  };

  const best = new Map();
  const add = (item, key, pct) => {
    if (!(pct > 0)) return;
    let arr = best.get(item);
    if (!arr) best.set(item, arr = []);
    const old = arr.find((x) => x.key === key);
    if (old) { if (pct > old.pct) old.pct = pct; }
    else if (arr.length < keep) arr.push({ key, pct });
    else {
      let lo = 0;
      for (let i = 1; i < arr.length; i++) if (arr[i].pct < arr[lo].pct) lo = i;
      if (pct > arr[lo].pct) arr[lo] = { key, pct };
    }
  };
  // o loot é indexado pelo ID do loot; criaturas (lootid) e baús/cardumes (Data1) apontam para ele
  const owners = (rows, idCol, lootOf) => {
    const m = new Map();
    for (const r of rows) {
      const loot = lootOf(r);
      if (!(loot > 0)) continue;
      if (!m.has(loot)) m.set(loot, []);
      m.get(loot).push(Number(r[idCol]));
    }
    return m;
  };
  const npcOwners = owners(readSqlTable("creature_template"), "entry", (r) => Number(r.lootid));
  const objOwners = owners(readSqlTable("gameobject_template"), "entry",
    (r) => (r.type === "3" || r.type === "25") ? Number(r.Data1) : 0);

  // dono (n<id>/o<id>) -> ID do loot, e ID do loot -> linhas; para a consulta pontual best.chance()
  const lootOfKey = new Map(), lootRows = { n: null, o: null }, lootPct = new Map();
  for (const [own, pre] of [[npcOwners, "n"], [objOwners, "o"]]) {
    for (const [loot, ids] of own) for (const id of ids) lootOfKey.set(pre + id, loot);
  }

  for (const [table, pre, own] of [["creature_loot_template", "n", npcOwners], ["gameobject_loot_template", "o", objOwners]]) {
    lootRows[pre] = byEntry(readSqlTable(table));
    for (const [entry, list] of lootRows[pre]) {
      const ids = own.get(entry);
      if (!ids) continue;
      const ch = rowChances(list);
      list.forEach((r, i) => {
        const put = (it, p) => { for (const id of ids) add(it, pre + id, p); };
        if (r.ref > 0) for (const [it, p] of expandRef(r.ref, 1)) put(it, p * ch[i] / 100);
        else if (r.item > 0) put(r.item, ch[i]);
      });
    }
  }
  for (const arr of best.values()) {
    arr.sort((a, b) => b.pct - a.pct);
    for (const x of arr) x.pct = Math.round(x.pct * 100) / 100;
  }

  // chance (%) do item no loot de uma criatura/objeto específico (0 = não consta)
  best.chance = (item, key) => {
    const loot = lootOfKey.get(key);
    if (!loot) return 0;
    const ck = key[0] + loot;
    let m = lootPct.get(ck);
    if (!m) {
      m = new Map();
      const list = lootRows[key[0]].get(loot) || [];
      const ch = rowChances(list);
      list.forEach((r, i) => {
        if (r.ref > 0) for (const [it, p] of expandRef(r.ref, 1)) m.set(it, Math.max(m.get(it) || 0, p * ch[i] / 100));
        else if (r.item > 0) m.set(r.item, Math.max(m.get(r.item) || 0, ch[i]));
      });
      lootPct.set(ck, m);
    }
    return Math.round((m.get(item) || 0) * 100) / 100;
  };
  return best;
}

// item -> Set(npc) que vende (referências negativas apontam para a lista de outro vendedor)
function readAcVendors() {
  const lists = new Map();
  for (const r of readSqlTable("npc_vendor")) {
    const e = Number(r.entry), it = Number(r.item);
    if (!lists.has(e)) lists.set(e, []);
    lists.get(e).push(it);
  }
  const out = new Map();
  const walk = (npc, e, depth) => {
    for (const it of lists.get(e) || []) {
      if (it < 0) { if (depth < 3) walk(npc, -it, depth + 1); continue; }
      if (!out.has(it)) out.set(it, new Set());
      out.get(it).add(npc);
    }
  };
  for (const e of lists.keys()) walk(e, e, 0);
  return out;
}

module.exports = { readSqlTable, readAcQuestRewards, readAcLoot, readAcVendors, AC_DIR };
