// Nível mínimo de profissão das missões (autorizado pelo usuário em 2026-11-18): o banco do Polestar/pfQuest só
// diz QUAL profissão a missão exige; o QuestieDB (github.com/Questie/QuestieDB, GPL-3.0) traz também o nível
// ("requiredSkill" = { profissão, nível }). O arquivo fica só nas ferramentas
// (tools/map-extract/thirdparty/questiedb/classicQuestDB.lua, baixado de data/Classic/classicQuestDB.lua);
// daqui sai apenas o par profissão/nível de cada missão, com crédito em Data/Quests/QuestDB-NOTICE.txt.
// O arquivo é só LIDO como dados (um leitor de tabelas Lua mínimo), nunca executado.
"use strict";
const fs = require("fs");
const path = require("path");

const FILE = path.join(__dirname, "thirdparty/questiedb/classicQuestDB.lua");
const ZONE_OR_SORT = 17;             // QuestieDB.questKeys.zoneOrSort
const REQUIRED_SKILL = 18;           // QuestieDB.questKeys.requiredSkill
const SPECIAL_FLAGS = 24;            // QuestieDB.questKeys.specialFlags (1=Repeatable, 2=Needs event)

// lê um literal de tabela Lua (números, textos, nil, true/false, { ... } com ou sem [chave] =)
function parseLua(src, i) {
  const ws = () => { while (i < src.length && /\s/.test(src[i])) i++; };
  function value() {
    ws();
    const ch = src[i];
    if (ch === "{") {
      i++;
      const arr = [];
      let n = 1;
      for (;;) {
        ws();
        if (src[i] === "}") { i++; return arr; }
        let key = null;
        if (src[i] === "[") {
          i++;
          key = value();
          ws(); i++;            // ]
          ws(); i++;            // =
        } else {
          const m = /^[A-Za-z_]\w*\s*=(?!=)/.exec(src.slice(i, i + 64));
          if (m) { key = m[0].replace(/\s*=$/, ""); i += m[0].length; }
        }
        const v = value();
        if (key === null) arr[n++ - 1] = v; else arr[key] = v;
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
      return s;
    }
    const m = /^(nil|true|false|-?[\d.]+(?:e-?\d+)?)/.exec(src.slice(i, i + 32));
    if (!m) throw new Error("literal Lua inesperado em " + i + ": " + src.slice(i, i + 20));
    i += m[0].length;
    if (m[0] === "nil") return null;
    if (m[0] === "true") return true;
    if (m[0] === "false") return false;
    return Number(m[0]);
  }
  const v = value();
  return [v, i];
}

// Map questID -> { skill: [SkillLine, nível]|null, rep: boolean, event: boolean, sort: number }
function readQuestieMeta() {
  const out = new Map();
  if (!fs.existsSync(FILE)) { console.warn("questdb: QuestieDB não encontrado em", FILE, "- sem metadados"); return out; }
  const src = fs.readFileSync(FILE, "utf8");
  const re = /^\[(\d+)\] = (?=\{)/gm;
  let m, bad = 0;
  while ((m = re.exec(src))) {
    try {
      const [rec] = parseLua(src, m.index + m[0].length);
      const sk = rec[REQUIRED_SKILL - 1];
      const sf = rec[SPECIAL_FLAGS - 1] || 0;
      const zs = rec[ZONE_OR_SORT - 1] || 0;
      const skill = (Array.isArray(sk) && sk[0]) ? [sk[0], sk[1] || 0] : null;
      const rep = (sf & 1) !== 0;
      const evt = (sf & 2) !== 0;
      if (skill || rep || evt || zs < 0) {
        out.set(Number(m[1]), { skill, rep, evt, sort: zs });
      }
    } catch (e) { bad++; }
  }
  if (bad) console.warn("questdb: QuestieDB -", bad, "registros não lidos");
  return out;
}

function readQuestieSkills() {
  const out = new Map();
  for (const [id, meta] of readQuestieMeta()) {
    if (meta.skill) out.set(id, meta.skill);
  }
  return out;
}

module.exports = { readQuestieSkills, readQuestieMeta };
