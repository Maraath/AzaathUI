// Leitor do loot de masmorras/raides do OneForAll (https://github.com/smoergi/OneForAll_Forever),
// GPL-3.0 ou posterior, (c) Smoergi. Os arquivos ficam em thirdparty/oneforall e são só LIDOS como
// texto (um leitor mínimo de tabelas Lua), nunca executados. Fontes dos fatos: ver
// thirdparty/oneforall/DUNGEON_DATA_SOURCES.txt.
"use strict";
const fs = require("fs");
const path = require("path");

const OFA_DIR = process.env.OFA_DB || path.join(__dirname, "thirdparty/oneforall");

// Lê um literal Lua a partir de src[i]: tabelas, textos, números, booleanos. Comentários são pulados;
// expressões que não são literais (constantes, concatenações) viram null.
function parseLua(src, i) {
  const ws = () => {
    for (;;) {
      while (i < src.length && /\s/.test(src[i])) i++;
      if (src.startsWith("--", i)) {
        if (src.startsWith("--[[", i)) { const e = src.indexOf("]]", i); i = e < 0 ? src.length : e + 2; }
        else { const e = src.indexOf("\n", i); i = e < 0 ? src.length : e + 1; }
      } else return;
    }
  };
  const skipExpr = () => { // pula até a próxima , ; ou } do mesmo nível
    let depth = 0;
    while (i < src.length) {
      const c = src[i];
      if (c === '"' || c === "'") { value(); continue; }
      if (c === "{" || c === "(" || c === "[") depth++;
      else if (c === "}" || c === ")" || c === "]") { if (depth === 0) return; depth--; }
      else if ((c === "," || c === ";") && depth === 0) return;
      i++;
    }
  };
  function value() {
    ws();
    const ch = src[i];
    if (ch === "{") {
      i++;
      const arr = [];
      let n = 0;
      for (;;) {
        ws();
        if (src[i] === "}") { i++; return arr; }
        let key = null;
        if (src[i] === "[" && src[i + 1] !== "[") {
          i++; key = value(); ws(); i++; ws(); i++; // ] =
        } else {
          const m = /^[A-Za-z_]\w*\s*=(?!=)/.exec(src.slice(i, i + 64));
          if (m) { key = m[0].replace(/\s*=$/, ""); i += m[0].length; }
        }
        const v = value();
        if (key === null) arr[n++] = v; else arr[key] = v;
        ws();
        if (src[i] === "," || src[i] === ";") i++;
      }
    }
    if (ch === '"' || ch === "'") {
      const q = ch;
      i++;
      let s = "";
      while (i < src.length && src[i] !== q) {
        if (src[i] === "\\") { s += src[i + 1]; i += 2; } else s += src[i++];
      }
      i++;
      ws();
      if (src.startsWith("..", i)) { skipExpr(); return null; }
      return s;
    }
    const m = /^(nil|true|false|-?\d+(?:\.\d+)?(?:e-?\d+)?)(?![\w.])/.exec(src.slice(i, i + 32));
    if (m) { i += m[0].length; ws(); if (/^[-+*/.]/.test(src[i]) && src[i] !== "," ) { skipExpr(); return null; } return m[1] === "nil" ? null : m[1] === "true" ? true : m[1] === "false" ? false : Number(m[1]); }
    skipExpr();
    return null;
  }
  const v = value();
  return [v, i];
}

// Lê `ALVO = { ... }` de um arquivo (a primeira ocorrência de cada alvo encontrado pelo padrão).
function readAssigns(file, re) {
  const src = fs.readFileSync(file, "utf8");
  const out = [];
  let m;
  while ((m = re.exec(src))) {
    const [v] = parseLua(src, m.index + m[0].length);
    out.push([m[1], v]);
  }
  return out;
}

const ids = (list) => (Array.isArray(list) ? list : [])
  .filter((x) => Array.isArray(x) && Number(x[0]) > 0)
  .map((x) => ({ id: Number(x[0]), name: x[1] || "", slot: x[2] || "", quality: Number(x[3]) || 0 }));

// -> { dungeons: [{ name, bosses: [{ name, npcID, loot }], trash }], chance(dungeon, boss, item) }
function readOneForAll() {
  const dir = path.join(OFA_DIR, "Dungeons");
  if (!fs.existsSync(dir)) throw new Error("OneForAll: faltou " + dir);
  const dungeons = [];
  for (const f of fs.readdirSync(dir).filter((x) => x.endsWith(".lua")).sort()) {
    for (const [name, d] of readAssigns(path.join(dir, f), /FLT\.DUNGEON_REGISTRY\["([^"]+)"\]\s*=\s*/g)) {
      if (!d) continue;
      dungeons.push({
        name,
        level: typeof d.level === "string" ? d.level : (d.level ? String(d.level) : ""),
        location: d.location || "",
        raid: /\braid for \d+ players/i.test(d.description || ""),
        bosses: (Array.isArray(d.bosses) ? d.bosses : []).filter(Boolean).map((b) => ({
          name: b.name || "", npcID: Number(b.npcID) || 0, displayID: Number(b.displayID) || 0, loot: ids(b.loot),
        })),
        trash: ids(d.trashLoot),
      });
    }
  }
  const chances = {};
  const cf = path.join(OFA_DIR, "DungeonDropChance.lua");
  if (fs.existsSync(cf)) {
    for (const [, v] of readAssigns(cf, /FLT\.(DUNGEON_DROP_CHANCE)\s*=\s*/g)) Object.assign(chances, v || {});
  }
  // receitas que os chefes dropam (pool compartilhado de chance baixa, sem %): npcID -> [recipeItemID]
  const recipeDrops = new Map();
  const bf = path.join(OFA_DIR, "BossDrops.lua");
  if (fs.existsSync(bf)) {
    for (const [, v] of readAssigns(bf, /FLT\.(RECIPE_BOSS_DROPS)\s*=\s*/g)) {
      for (const k of Object.keys(v || {})) if (Number(k) > 0) recipeDrops.set(Number(k), (v[k] || []).map(Number).filter((x) => x > 0));
    }
  }
  // nome do que a receita fabrica: recipeItemID -> "Wisdom's Leather Gloves"
  const recipeMakes = new Map();
  const pf = path.join(OFA_DIR, "ProfessionData.lua");
  if (fs.existsSync(pf)) {
    for (const m of fs.readFileSync(pf, "utf8").matchAll(/\["((?:\\.|[^"])+)"\]\s*=\s*\{[^}]*?recipeItemID\s*=\s*(\d+)/g)) {
      if (!recipeMakes.has(Number(m[2]))) recipeMakes.set(Number(m[2]), m[1].replace(/\\(.)/g, "$1"));
    }
  }

  const chance = (dungeon, boss, item) => {
    const b = chances[dungeon] && chances[dungeon][boss];
    return b && Number(b[item]) > 0 ? Number(b[item]) : 0;
  };
  return { dungeons, chance, recipeDrops, recipeMakes };
}

// Fatia de equipamento a partir do texto "Legs, Cloth" / "Two-Hand, Axe" (só quando o ItemDB não sabe)
const INV = { Head: 1, Neck: 2, Shoulder: 3, Chest: 5, Waist: 6, Legs: 7, Feet: 8, Wrist: 9, Hands: 10,
  Finger: 11, Trinket: 12, Back: 16, "Off Hand": 23, "Held In Off-hand": 23, Shield: 14 };
const ARMOR = { Cloth: 1, Leather: 2, Mail: 3, Plate: 4 };
const WEAPON = { Axe: [0, 1], Mace: [4, 5], Sword: [7, 8], Dagger: [15, 15], Staff: [10, 10], Polearm: [6, 6],
  Bow: [2, 2], Gun: [3, 3], Crossbow: [18, 18], Wand: [19, 19], "Fist Weapon": [13, 13], Fist: [13, 13] };
function slotInfo(slot) {
  const [a, b] = String(slot).split(",").map((s) => s.trim());
  if (WEAPON[b]) return { cid: 2, scid: WEAPON[b][a === "Two-Hand" ? 1 : 0], inv: a === "Two-Hand" ? 17 : (a === "Ranged" ? 15 : 13) };
  if (a === "Shield" || b === "Shield") return { cid: 4, scid: 6, inv: 14 };
  if (INV[a]) return { cid: 4, scid: ARMOR[b] || 0, inv: INV[a] };
  return { cid: 0, scid: 0, inv: 0 };
}

module.exports = { readOneForAll, slotInfo, OFA_DIR, parseLua };
