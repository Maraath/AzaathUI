// Áreas dos objetivos de missão (job "questareas" do extrator): a pedido do usuário (2026-11-17), as
// regiões onde ficam os monstros/objetos de cada missão, como as do Polestar. Os dados vêm do banco de
// missões que o Polestar instala (Interface/AddOns/Polestar_QuestDB: missões, onde nascem os monstros
// e os objetos, de onde caem os itens), gerado por ele a partir do pfQuest (MIT; ver o aviso em
// AzaathUI/Data/Map/QuestAreas-NOTICE.txt). O Azaath fica com a sua cópia compacta e não precisa do
// Polestar ligado. O agrupamento em regiões é feito no jogo (Modules/MapRegions.lua).
//
// Saída: AzaathUI/Data/Map/QuestAreas.lua
//   Azaath.QuestAreaData.frames[uiMapID] = { instância, topo, base, esquerda, direita }   (mapas "era")
//   Azaath.QuestAreaData.quests[questID] = { "n36 n38", "o55", "" ... }   um texto por objetivo, na ordem
//       do jogo: os monstros (nID) e objetos (oID) onde ele se cumpre ("" = sem lugar: evento, conversa)
//   Azaath.QuestAreaData.spawns["n36"] = "1436,0:56.9,35.2,31:34.9,46.8,48|..."  por mapa:
//       mapa,quadro(0 era, 1 atual) : x,y,raio(jardas) : ...   (x, y em % do mapa)
"use strict";
const fs = require("fs");
const path = require("path");

const DB_DIR = process.env.POLESTAR_DB || "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/Polestar_QuestDB";

// um registro: campos por ";" (vazio = nil), "'" texto, "{" lista de números por ",", senão número
function decode(s) {
  return s.split(";").map((f) => {
    if (f === "") return null;
    if (f[0] === "'") return f.slice(1).replace(/%([0-9a-fA-F]{2})/g, (_, h) => String.fromCharCode(parseInt(h, 16)));
    if (f[0] === "{") return f.slice(1).split(",").map((e) => (e === "" ? null : Number(e)));
    return Number(f);
  });
}

function readKind(file, kind) {
  const src = fs.readFileSync(path.join(DB_DIR, file), "utf8");
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

function readFrames() {
  const src = fs.readFileSync(path.join(DB_DIR, "MapFrames.lua"), "utf8");
  const out = new Map();
  for (const m of src.matchAll(/\[(\d+)\] = \{bottom=([-\d.]+),c=(\d+),left=([-\d.]+),right=([-\d.]+),top=([-\d.]+)\}/g)) {
    out.set(Number(m[1]), [Number(m[3]), Number(m[6]), Number(m[2]), Number(m[4]), Number(m[5])]);
  }
  return out;
}

// os lugares de um monstro/objeto: "mapa,quadro:x,y,r:...|..."
function spawnText(rec) {
  const parts = [];
  let i = 1;
  while (i < rec.length) {
    const map = rec[i], f = rec[i + 1], n = rec[i + 2];
    if (map == null || n == null) break;
    const pts = [];
    for (let k = 0; k < n; k++) {
      const x = rec[i + 3 + 3 * k], y = rec[i + 4 + 3 * k], r = rec[i + 5 + 3 * k];
      if (x != null && y != null) pts.push(x + "," + y + "," + (r || 0));
    }
    if (pts.length) parts.push(map + "," + (f || 0) + ":" + pts.join(":"));
    i += 3 + 3 * n;
  }
  return parts.join("|");
}

function buildQuestAreas(write, header, casc) {
  if (!fs.existsSync(DB_DIR)) { console.warn("questareas: banco do Polestar não encontrado em", DB_DIR); return; }
  const quests = readKind("Quests.lua", "quests");
  const npcs = readKind("Npcs.lua", "npcs");
  const objects = readKind("Objects.lua", "objects");
  const items = readKind("Items.lua", "items");
  const frames = readFrames();
  console.log("questareas:", quests.size, "missões,", npcs.size, "monstros,", objects.size, "objetos,", items.size, "itens");
  const used = new Map();
  const useEntity = (key) => {
    if (used.has(key)) return used.get(key) !== "";
    const id = Number(key.slice(1));
    const rec = key[0] === "n" ? npcs.get(id) : objects.get(id);
    const txt = rec ? spawnText(rec) : "";
    used.set(key, txt);
    return txt !== "";
  };
  const qLines = [], zLines = [];   // zLines: a zona (uiMap) da missão
  for (const [qid, r] of [...quests].sort((a, b) => a[0] - b[0])) {
    const obj = r[11];                       // OBJ: { kind, id, count, ... }
    if (!Array.isArray(obj)) continue;
    const per = [];
    let any = false;
    for (let i = 0; i + 1 < obj.length; i += 3) {
      const kind = obj[i], id = obj[i + 1];
      const keys = [];
      if (kind === 1 && id) keys.push("n" + id);                 // matar
      else if (kind === 3 && id) keys.push("o" + id);            // usar objeto
      else if (kind === 2 && id) {                               // item: quem deixa cair e onde se pega
        const ir = items.get(id);
        if (ir) {
          const nd = ir[1] || 0;
          // registro: nome; nº de monstros; (monstro, chance)...; nº de objetos; (objeto, chance)...
          for (let k = 1; k <= nd; k++) if (ir[2 * k]) keys.push("n" + ir[2 * k]);
          const j = 2 + 2 * nd;
          const no = ir[j] || 0;
          for (let k = 1; k <= no; k++) if (ir[j + 2 * k - 1]) keys.push("o" + ir[j + 2 * k - 1]);
        }
      }
      const ok = keys.filter(useEntity);
      if (ok.length) any = true;
      per.push(ok.join(" "));
    }
    if (any && r[12]) zLines.push("	[" + qid + "] = " + r[12] + ",");
    if (any) qLines.push("\t[" + qid + "] = { " + per.map((s) => '"' + s + '"').join(", ") + " },");
  }
  const sLines = [];
  for (const [k, txt] of [...used].sort()) if (txt) sLines.push('\t["' + k + '"] = "' + txt + '",');
  const fLines = [...frames].sort((a, b) => a[0] - b[0]).map(([id, f]) => "\t[" + id + "] = { " + f.join(", ") + " },");
  const out = [header("Áreas dos objetivos de missão (dados do banco do Polestar, de origem pfQuest/MIT).", casc), "",
    "-- frames[uiMapID] = { instância, topo, base, esquerda, direita } (jardas) dos mapas de quadro \"era\"",
    "-- quests[questID] = { um texto por objetivo: monstros nID / objetos oID onde ele se cumpre }",
    "-- zones[questID] = uiMap da zona da missão (os lugares de um objetivo nessa zona têm preferência)",
    "-- spawns[nID|oID] = \"mapa,quadro:x,y,raio:...|...\" (x, y em % do mapa; quadro 0 era, 1 atual)",
    "Azaath.QuestAreaData = { frames = {", ...fLines, "}, quests = {", ...qLines, "}, zones = {", ...zLines, "}, spawns = {", ...sLines, "} }", ""];
  write("QuestAreas.lua", out.join("\n"));
  console.log("questareas:", qLines.length, "missões com lugar,", sLines.length, "monstros/objetos");
}

module.exports = { buildQuestAreas };
