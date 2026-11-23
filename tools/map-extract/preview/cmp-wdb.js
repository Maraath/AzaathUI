// descartável: confere o leitor do cache WDB contra as traduções já conhecidas
const M = "../";
const { readCache } = require(M + "wdb-cache.js");
const fs = require("fs");
const { readPtNames } = require(M + "names-ptbr.js");
const c = readCache();
const rd = (f) => {
  const m = new Map();
  for (const x of fs.readFileSync(f, "utf8").matchAll(/^\t\[(\d+)\] = "((?:\\.|[^"\\])*)"/gm)) m.set(+x[1], x[2].replace(/\\(.)/g, "$1"));
  return m;
};
const FL = "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/ForeverLoremaster/Data/";
const t = rd(FL + "QuestNames_ptBR.lua"), o = rd(FL + "QuestText_ptBR.lua");
const pt = readPtNames();
let a = 0, b = 0, ex = [];
for (const [id, q] of c.quests) if (t.has(id)) { a++; if (t.get(id).toLowerCase() === q.title.toLowerCase()) b++; else if (ex.length < 5) ex.push([id, t.get(id), q.title]); }
console.log("titulos iguais", b, "/", a, ex);
a = 0; b = 0; ex = [];
for (const [id, q] of c.quests) if (o.has(id)) { a++; if (o.get(id).trim() === q.objective) b++; else if (ex.length < 3) ex.push([id, o.get(id).slice(0, 70), q.objective.slice(0, 70)]); }
console.log("objetivos iguais", b, "/", a, ex);
for (const [k, m] of [["npc", c.npcs], ["object", c.objects]]) {
  a = 0; b = 0; ex = [];
  for (const [id, n] of m) { const p = pt[k] && pt[k].get(id); if (p) { a++; if (p === n) b++; else if (ex.length < 4) ex.push([id, p, n]); } }
  console.log(k, "iguais", b, "/", a, ex);
}
