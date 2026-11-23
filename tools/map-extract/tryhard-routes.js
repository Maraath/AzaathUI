// Extrai as rotas curadas de leveling (Forever + Classic) dos guias locais
// (Polestar_Guides* + Polestar_ptBR) para AzaathUI/Data/Quests/TryhardRoutes.lua
// Uso: node tools/map-extract/tryhard-routes.js

const fs = require("fs");
const path = require("path");

const WOW_ADDONS = "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns";
const PTBR_FILE = path.join(__dirname, "../.cache/polestar/Polestar_ptBR/Names.lua");
const OUT_FILE = path.join(__dirname, "../../AzaathUI/Data/Quests/TryhardRoutes.lua");
const NOTICE_FILE = path.join(__dirname, "../../AzaathUI/Data/Quests/TryhardRoutes-NOTICE.txt");

function loadPtBR() {
  const maps = { quest: new Map(), npc: new Map(), item: new Map(), map: new Map(), object: new Map() };
  const fp = fs.existsSync(PTBR_FILE)
    ? PTBR_FILE
    : path.join(WOW_ADDONS, "Polestar_ptBR/Names.lua");
  if (!fs.existsSync(fp)) return maps;
  const src = fs.readFileSync(fp, "utf8");
  const rx = /R\("([^"]+)",\s*\d+,\s*\d+,\s*\[\[([\s\S]*?)\]\]\)/g;
  let m;
  while ((m = rx.exec(src)) !== null) {
    const kind = m[1];
    const target = maps[kind];
    if (!target) continue;
    for (const line of m[2].split(/\r?\n/)) {
      if (!line) continue;
      const tab = line.indexOf("\t");
      if (tab <= 0) continue;
      const id = Number(line.slice(0, tab));
      const val = line.slice(tab + 1).trim();
      if (id > 0 && val) target.set(id, val);
    }
  }
  return maps;
}

// Parser leve de tabelas Lua para ler Polestar.RegisterGuide({ ... })
function parseLuaTable(src, startIdx) {
  let i = startIdx;
  const len = src.length;

  function skipWS() {
    while (i < len) {
      const ch = src[i];
      if (ch === " " || ch === "\t" || ch === "\r" || ch === "\n") {
        i++;
      } else if (ch === "-" && src[i + 1] === "-") {
        if (src[i + 2] === "[" && src[i + 3] === "[") {
          i += 4;
          while (i < len && !(src[i] === "]" && src[i + 1] === "]")) i++;
          i += 2;
        } else {
          while (i < len && src[i] !== "\n") i++;
        }
      } else break;
    }
  }

  function parseString() {
    const q = src[i++];
    let out = "";
    while (i < len && src[i] !== q) {
      if (src[i] === "\\") {
        i++;
        const esc = src[i++];
        if (esc === "n") out += " ";
        else if (esc === "t") out += " ";
        else out += esc || "";
      } else {
        out += src[i++];
      }
    }
    i++; // closing quote
    return out;
  }

  function parseLongString() {
    i += 2; // '[['
    let out = "";
    while (i < len && !(src[i] === "]" && src[i + 1] === "]")) {
      out += src[i++];
    }
    if (i < len) i += 2;
    return out.replace(/[\r\n\t]+/g, " ");
  }

  function parseValue() {
    skipWS();
    if (i >= len) return undefined;
    const ch = src[i];
    if (ch === "{") return parseTable();
    if (ch === "[" && src[i + 1] === "[") {
      let s = parseLongString();
      skipWS();
      while (src[i] === "." && src[i + 1] === ".") {
        i += 2;
        s += String(parseValue() || "");
        skipWS();
      }
      return s;
    }
    if (ch === '"' || ch === "'") {
      let s = parseString();
      skipWS();
      while (src[i] === "." && src[i + 1] === ".") {
        i += 2;
        s += String(parseValue() || "");
        skipWS();
      }
      return s;
    }
    if (ch === "-" || (ch >= "0" && ch <= "9")) {
      const m = src.slice(i).match(/^-?\d+(?:\.\d+)?/);
      if (m) {
        i += m[0].length;
        return Number(m[0]);
      }
    }
    const idm = src.slice(i).match(/^[A-Za-z_][A-Za-z0-9_]*/);
    if (idm) {
      i += idm[0].length;
      if (idm[0] === "true") return true;
      if (idm[0] === "false") return false;
      if (idm[0] === "nil") return null;
      while (i < len) {
        skipWS();
        if (src[i] === "[") {
          i++;
          parseValue();
          skipWS();
          if (src[i] === "]") i++;
        } else if (src[i] === "." && src[i + 1] === ".") {
          i += 2;
          parseValue();
        } else if (src[i] === ".") {
          i++;
          const fm = src.slice(i).match(/^[A-Za-z_][A-Za-z0-9_]*/);
          if (fm) i += fm[0].length;
        } else if (src[i] === "(") {
          i++;
          let depth = 1;
          while (i < len && depth > 0) {
            if (src[i] === '"' || src[i] === "'") parseString();
            else if (src[i] === "(") { depth++; i++; }
            else if (src[i] === ")") { depth--; i++; }
            else i++;
          }
        } else break;
      }
      return idm[0];
    }
    i++;
    return undefined;
  }

  function parseTable() {
    i++; // '{'
    const obj = {};
    const arr = [];
    let isArr = true;
    while (i < len) {
      skipWS();
      if (src[i] === "}") { i++; break; }
      if (src[i] === ",") { i++; continue; }

      if (src[i] === "[") {
        isArr = false;
        i++;
        const k = parseValue();
        skipWS();
        if (src[i] === "]") i++;
        skipWS();
        if (src[i] === "=") i++;
        const v = parseValue();
        if (k !== undefined) obj[k] = v;
      } else {
        const save = i;
        const idm = src.slice(i).match(/^([A-Za-z_][A-Za-z0-9_]*)\s*=/);
        if (idm) {
          isArr = false;
          i += idm[0].length;
          const v = parseValue();
          obj[idm[1]] = v;
        } else {
          i = save;
          const v = parseValue();
          arr.push(v);
        }
      }
    }
    return isArr ? arr : (arr.length ? Object.assign(obj, { _arr: arr }) : obj);
  }

  skipWS();
  if (src[i] !== "{") return null;
  return parseTable();
}

function extractGuidesFromFile(fp) {
  if (!fs.existsSync(fp)) return [];
  const src = fs.readFileSync(fp, "utf8");
  const guides = [];
  const marker = "Polestar.RegisterGuide(";
  let pos = 0;
  while (true) {
    const idx = src.indexOf(marker, pos);
    if (idx < 0) break;
    const tbl = parseLuaTable(src, idx + marker.length);
    if (tbl && tbl.id) guides.push(tbl);
    pos = idx + marker.length;
  }
  return guides;
}

function cleanText(s, pt, names) {
  if (!s) return "";
  return String(s)
    .replace(/\{([a-z]+):(\d+)\}/g, (_, kind, idStr) => {
      const id = Number(idStr);
      if (kind === "zone") return pt.map.get(id) || (names && names[`zone:${id}`]) || `Zona ${id}`;
      if (kind === "quest") return pt.quest.get(id) || (names && names[`quest:${id}`]) || `Missão #${id}`;
      if (kind === "npc") return pt.npc.get(id) || (names && names[`npc:${id}`]) || `NPC #${id}`;
      if (kind === "item") return pt.item.get(id) || (names && names[`item:${id}`]) || `Item #${id}`;
      if (kind === "object") return pt.object.get(id) || (names && names[`object:${id}`]) || `Objeto #${id}`;
      return (names && names[`${kind}:${id}`]) || `#${id}`;
    })
    .replace(/[\r\n\t]+/g, " ")
    .trim();
}

function luaStr(s) {
  return '"' + String(s || "").replace(/\\/g, "\\\\").replace(/"/g, '\\"') + '"';
}

function guessContinent(zone, id) {
  const ek = new Set([1416,1417,1418,1419,1420,1421,1422,1423,1424,1425,1426,1427,1428,1429,1430,1431,1432,1433,1434,1435,1436,1437,1453,1455,1458]);
  const kal = new Set([1411,1412,1413,1438,1439,1440,1441,1442,1443,1444,1445,1446,1447,1448,1449,1450,1451,1452,1454,1456,1457,2652]);
  if (ek.has(zone)) return "EK";
  if (kal.has(zone)) return "Kalimdor";
  if (id.includes("human") || id.includes("dwarf") || id.includes("gnome") || id.includes("scourge") || id.includes("elwynn") || id.includes("westfall") || id.includes("duskwood") || id.includes("redridge") || id.includes("loch-modan") || id.includes("wetlands") || id.includes("stranglethorn") || id.includes("hillsbrad") || id.includes("arathi") || id.includes("badlands") || id.includes("plaguelands") || id.includes("tirisfal") || id.includes("silverpine")) return "EK";
  if (id.includes("nightelf") || id.includes("orc") || id.includes("tauren") || id.includes("troll") || id.includes("durotar") || id.includes("barrens") || id.includes("ashenvale") || id.includes("darkshore") || id.includes("stonetalon") || id.includes("desolace") || id.includes("feralas") || id.includes("tanaris") || id.includes("felwood") || id.includes("ungoro") || id.includes("winterspring") || id.includes("shendralas")) return "Kalimdor";
  return "Outro";
}

function main() {
  const pt = loadPtBR();
  const guideFiles = [
    path.join(WOW_ADDONS, "Polestar_Guides/Guides.lua"),
    path.join(WOW_ADDONS, "Polestar_Guides_Alliance/Guides.lua"),
    path.join(WOW_ADDONS, "Polestar_Guides_Horde/Guides.lua"),
    ...["Human", "Dwarf", "Gnome", "NightElf", "Orc", "Tauren", "Troll", "Scourge", "Skyborne"]
      .map((r) => path.join(WOW_ADDONS, `Polestar_Guides_${r}/Legs.lua`)),
  ];

  const ALLOWED_CATS = new Set(["Leveling", "Class", "Professions", "Reputation", "Collectibles", "Exploration", "Miscellaneous", "Legacy"]);
  const allRaw = [];
  for (const fp of guideFiles) {
    for (const g of extractGuidesFromFile(fp)) {
      if (ALLOWED_CATS.has(g.category) && Array.isArray(g.steps) && g.steps.length > 0) {
        allRaw.push(g);
      }
    }
  }

  const byId = new Map();
  for (const g of allRaw) byId.set(g.id, g);

  const outLines = [];
  let totalSteps = 0;

  for (const g of allRaw) {
    let faction = "AH";
    if (g.id.includes("/alliance/") || (g.only && Array.isArray(g.only.factions) && g.only.factions.join("") === "Alliance")) {
      faction = "A";
    } else if (g.id.includes("/horde/") || (g.only && Array.isArray(g.only.factions) && g.only.factions.join("") === "Horde")) {
      faction = "H";
    }
    const races = (g.only && Array.isArray(g.only.races)) ? g.only.races.join(",") : "";
    const classes = (g.only && Array.isArray(g.only.classes)) ? g.only.classes.join(",") : "";
    const cat = (g.category === "Legacy") ? "Miscellaneous" : (g.category || "Leveling");
    const zone = Number(g.zone) || 0;
    const zoneName = (zone && pt.map.get(zone)) || cleanText(g.zoneName || g.title, pt, g.names) || cleanText(g.title, pt, g.names);
    const cont = guessContinent(zone, g.id);
    const why = cleanText(g.why || "", pt, g.names).slice(0, 220);

    let nextId = g.next || (Array.isArray(g.nextChoices) ? g.nextChoices[0] : "") || "";
    const nextG = nextId ? byId.get(nextId) : null;
    const nextZone = nextG ? ((Number(nextG.zone) && pt.map.get(Number(nextG.zone))) || nextG.zoneName || "") : "";
    const nextZoneId = nextG ? (Number(nextG.zone) || 0) : 0;
    const nextMin = nextG ? (Number(nextG.minLevel) || 0) : 0;

    const stepLines = [];
    for (const st of g.steps) {
      if (!st || !Array.isArray(st.goals)) continue;
      let stFaction = "";
      if (st.only && Array.isArray(st.only.factions)) {
        const f = st.only.factions.join(",");
        if (f === "Alliance") stFaction = "A";
        else if (f === "Horde") stFaction = "H";
      }
      const stRaces = (st.only && Array.isArray(st.only.races)) ? st.only.races.join(",") : "";
      const stClasses = (st.only && Array.isArray(st.only.classes)) ? st.only.classes.join(",") : "";
      const stepTitle = cleanText(st.title || "", pt, g.names);
      const stepNote = cleanText(st.note || "", pt, g.names).slice(0, 140);

      const VALID_T = new Set([
        "accept", "turnin", "complete", "collect", "kill", "goto", "fly", "getfp",
        "enter", "sethome", "use", "talk", "interact", "train", "vendor", "buy",
        "craft", "learn", "explore", "level", "die", "note", "auction"
      ]);
      for (const gl of st.goals) {
        if (!gl || !gl.t) continue;
        const t = gl.t;
        if (!VALID_T.has(t)) continue;
        const qid = Number(gl.quest) || 0;
        const itemId = Number(gl.item) || 0;
        const reqLvl = Number(gl.lvl) || 0;
        const map = Number(gl.map) || zone || 0;
        const x = Number(gl.x) || 0;
        const y = Number(gl.y) || 0;
        if (map <= 0 && qid <= 0 && t !== "fly" && t !== "level" && t !== "use" && t !== "die" && t !== "note") continue;

        let gFaction = stFaction;
        if (!gFaction && gl.only && Array.isArray(gl.only.factions)) {
          const f = gl.only.factions.join(",");
          if (f === "Alliance") gFaction = "A";
          else if (f === "Horde") gFaction = "H";
        }
        const gRaces = (gl.only && Array.isArray(gl.only.races)) ? gl.only.races.join(",") : stRaces;
        const gClasses = (gl.only && Array.isArray(gl.only.classes)) ? gl.only.classes.join(",") : stClasses;

        let label = "";
        if (qid > 0) {
          label = pt.quest.get(qid) || cleanText(gl.title || "", pt, g.names) || stepTitle;
        } else if (t === "fly") {
          label = "Voar: " + cleanText(gl.location || stepTitle, pt, g.names);
        } else if (t === "getfp") {
          label = "Pegar ponto de voo: " + cleanText(gl.location || stepTitle, pt, g.names);
        } else if (t === "sethome") {
          label = "Definir Pedra de Regresso: " + cleanText(gl.location || stepTitle, pt, g.names);
        } else if (t === "use" && itemId > 0) {
          label = "Usar: " + (pt.item.get(itemId) || gl.itemName || stepTitle);
        } else if (t === "level" && reqLvl > 0) {
          label = `Alcance o Nível ${reqLvl}`;
        } else if (t === "die") {
          label = "Death Skip: " + cleanText(gl.text || gl.location || stepTitle || "Morra para renascer no cemitério", pt, g.names);
        } else {
          label = cleanText(gl.text || gl.location || stepTitle, pt, g.names);
        }

        const npcRaw = gl.npc ? (pt.npc.get(Number(gl.npc)) || gl.npcName || "") : (gl.from ? (pt.npc.get(Number(gl.fromId)) || gl.from) : "");
        const npc = String(npcRaw).replace(/%2C/gi, ",");
        const glNote = cleanText(gl.note || "", pt, g.names).slice(0, 140);
        const noteOut = glNote || stepNote || "";
        stepLines.push(
          `    { t=${luaStr(t)}, q=${qid}, it=${itemId}, lv=${reqLvl}, m=${map}, x=${x}, y=${y}, l=${luaStr(label)}, n=${luaStr(npc)}, nt=${luaStr(noteOut)}, f=${luaStr(gFaction)}, r=${luaStr(gRaces)}, c=${luaStr(gClasses)} },`
        );
        totalSteps++;
      }
    }

    if (stepLines.length === 0) continue;
    outLines.push(`  {`);
    outLines.push(`    id=${luaStr(g.id)}, cat=${luaStr(cat)}, cls=${luaStr(classes)}, f=${luaStr(faction)}, r=${luaStr(races)}, min=${Number(g.minLevel) || 1}, max=${Number(g.maxLevel) || 60}, z=${zone}, zn=${luaStr(zoneName)}, k=${luaStr(cont)}, why=${luaStr(why)}, nx=${luaStr(nextId)}, nzx=${nextZoneId}, nzn=${luaStr(nextZone)}, nmin=${nextMin},`);
    outLines.push(`    steps={`);
    outLines.push(stepLines.join("\n"));
    outLines.push(`    }`);
    outLines.push(`  },`);
  }

  fs.mkdirSync(path.dirname(OUT_FILE), { recursive: true });
  fs.writeFileSync(OUT_FILE, [
    "-- GERADO por tools/map-extract/tryhard-routes.js. Não edite à mão.",
    "local _, Azaath = ...",
    "Azaath.TryhardRoutes = {",
    outLines.join("\n"),
    "}",
    "",
  ].join("\n"), "utf8");

  fs.writeFileSync(NOTICE_FILE, [
    "Data/Quests/TryhardRoutes.lua",
    "Generated by tools/map-extract/tryhard-routes.js from Polestar_Guides (github.com/fitzforge/polestar, GPL-3.0) with pt-BR localization from Polestar_ptBR.",
    "Used with explicit user authorization (2026-11-18) for 100% native Tryhard leveling routes inside AzaathUI.",
    "",
  ].join("\n"), "utf8");

  const kb = (fs.statSync(OUT_FILE).size / 1024).toFixed(1);
  console.log(`Gerado ${OUT_FILE}: ${allRaw.length} guias, ${totalSteps} passos (${kb} KB)`);
}

main();
