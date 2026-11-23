// Gera AzaathUI/Data/Quests/QuestFix.lua: correções do QuestDB a partir do AzerothCore (GPL-2.0+).
//   zone[id]     = AreaTable do QuestSortID (masmorra/cidade) das missões com zona 0 no QuestDB
//   minLevel[id] = MinLevel do AzerothCore onde o QuestDB não tem nível mínimo
// Uso: node tools/map-extract/quest-fix.js   (lê tools/.cache/azerothcore/quest_template.sql)
const fs = require("fs");
const path = require("path");
const root = path.join(__dirname, "..", "..");
const sql = fs.readFileSync(path.join(root, "tools/.cache/azerothcore/quest_template.sql"), "utf8");
const ac = {};
for (const m of sql.matchAll(/^\((\d+),(\d+),(-?\d+),(\d+),(-?\d+),/gm)) ac[m[1]] = { min: +m[4], sort: +m[5] };

const db = fs.readFileSync(path.join(root, "AzaathUI/Data/Quests/QuestDB.lua"), "utf8").split(/\r?\n/);
const zone = [], minLevel = [];
for (const line of db) {
    const c = line.split("\t");
    if (c.length < 15 || !/^\d+$/.test(c[0])) continue;
    const a = ac[c[0]];
    if (!a) continue;
    if (c[7] === "0" && a.sort > 0) zone.push(`[${c[0]}]=${a.sort}`);
    if (c[2] === "0" && a.min > 0) minLevel.push(`[${c[0]}]=${a.min}`);
}
const out = [
    "-- GERADO por tools/map-extract/quest-fix.js. Não edite à mão.",
    "-- Fonte: AzerothCore quest_template (GPL-2.0+), ver QuestFix-NOTICE.txt",
    `-- Gerado em: ${new Date().toISOString().slice(0, 10)}`,
    "local _, Azaath = ...",
    "Azaath.QuestFix = {",
    `    zone = { ${zone.join(", ")} },`,
    `    minLevel = { ${minLevel.join(", ")} },`,
    "}",
    "",
].join("\n");
fs.writeFileSync(path.join(root, "AzaathUI/Data/Quests/QuestFix.lua"), out);
fs.writeFileSync(path.join(root, "AzaathUI/Data/Quests/QuestFix-NOTICE.txt"),
    "QuestFix.lua usa dados do AzerothCore (https://github.com/azerothcore/azerothcore-wotlk),\n" +
    "licenciado sob GPL-2.0 ou posterior: zona (QuestSortID) e nível mínimo (MinLevel) de missões.\n");
console.log(`zona: ${zone.length}  nível mínimo: ${minLevel.length}`);
