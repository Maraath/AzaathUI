// Dados de itens do próprio cliente (wago.tools, tabelas em tools/.cache/wago):
//  * Item: classe, subclasse e encaixe; ItemSparse: qualidade, nível do item, nível exigido.
//  * ItemXItemEffect/ItemEffect + Spell (descrição): o efeito de uso, para classificar consumíveis
//    (comida por atributo, poções de vida/mana, elixires, frascos...).
// Build do Forever (1.60.1.70532) e, para o que ele não tem, do Classic Era (1.15.9.70576).
"use strict";
const fs = require("fs");
const path = require("path");

const DIR = path.join(__dirname, "../.cache/wago");

function readCsv(file) {
  const fp = path.join(DIR, file);
  if (!fs.existsSync(fp)) return [];
  const lines = fs.readFileSync(fp, "utf8").split(/\r?\n/).filter(Boolean);
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

// id -> { cid, scid, inv, q, ilvl, req, use }  (use = descrição do feitiço de uso, em inglês)
function readClientItems() {
  const out = new Map();
  const get = (id) => { let r = out.get(id); if (!r) out.set(id, r = {}); return r; };
  for (const suf of ["-era", ""]) {
    for (const r of readCsv(`Item${suf}-enUS.csv`)) {
      const o = get(Number(r.ID));
      o.cid = Number(r.ClassID) || 0; o.scid = Number(r.SubclassID) || 0; o.inv = Number(r.InventoryType) || 0;
    }
    for (const r of readCsv(`ItemSparse${suf}-enUS.csv`)) {
      const o = get(Number(r.ID));
      o.q = Number(r.OverallQualityID) || 0; o.ilvl = Number(r.ItemLevel) || 0; o.req = Number(r.RequiredLevel) || 0;
      if (!o.inv) o.inv = Number(r.InventoryType) || 0;
    }
  }
  // efeitos de uso -> descrição do feitiço
  const spellDesc = new Map();
  for (const suf of ["-era", ""]) {
    for (const r of readCsv(`Spell${suf}-enUS.csv`)) if (r.Description_lang) spellDesc.set(Number(r.ID), r.Description_lang);
  }
  const effSpell = new Map();
  for (const r of readCsv("ItemEffect-era-enUS.csv")) {
    if (Number(r.TriggerType) === 0 && Number(r.ParentItemID) > 0) effSpell.set("i" + r.ParentItemID, Number(r.SpellID));
  }
  const effById = new Map();
  for (const r of readCsv("ItemEffect-enUS.csv")) if (Number(r.TriggerType) === 0) effById.set(Number(r.ID), Number(r.SpellID));
  for (const r of readCsv("ItemXItemEffect-enUS.csv")) {
    const sp = effById.get(Number(r.ItemEffectID));
    if (sp) effSpell.set("i" + r.ItemID, sp);
  }
  for (const [k, sp] of effSpell) {
    const d = spellDesc.get(sp);
    if (d) get(Number(k.slice(1))).use = d;
  }
  return out;
}

// Etiqueta fina dos consumíveis, a partir do efeito de uso e do nome (inglês):
//   food:str|agi|sta|int|spi|regen|plain, drink, pot:hp|mana|other, elixir, flask, scroll, bandage, enh
const STAT = [["str", /strength/i], ["agi", /agility/i], ["sta", /stamina/i], ["int", /intellect/i], ["spi", /spirit/i]];
function consumableTag(name, use, cid, scid) {
  if (cid !== 0) return "";
  const u = use || "", n = name || "";
  if (/while drinking/i.test(u) && !/while eating/i.test(u)) return "drink";
  if (/while eating/i.test(u) || /well fed/i.test(u)) {
    if (/well fed/i.test(u)) {
      const tail = u.slice(u.search(/well fed/i));
      const hit = STAT.filter(([, re]) => re.test(tail)).map(([k]) => k);
      if (hit.length) return "food:" + hit.join("+");
      if (/mana|health|regenerat|every 5 sec/i.test(tail)) return "food:regen";
    }
    return "food:plain";
  }
  if (/^flask\b/i.test(n) || scid === 3) return "flask";
  if (/elixir/i.test(n) || scid === 2) return "elixir";
  if (/^scroll of/i.test(n) || scid === 4) return "scroll";
  if (/bandage/i.test(n) || scid === 7) return "bandage";
  if (/sharpening stone|weightstone|wizard oil|mana oil|poison|armor kit|spellstone|firestone/i.test(n) || scid === 6) return "enh";
  if (/potion/i.test(n) || scid === 1) {
    // a descrição usa marcadores ($o1, $s1); vale a palavra
    if (/restores?.*health/i.test(u) && !/mana/i.test(u)) return "pot:hp";
    if (/restores?.*mana/i.test(u) && !/health/i.test(u)) return "pot:mana";
    return "pot:other";
  }
  return "other";
}

module.exports = { readClientItems, consumableTag };
