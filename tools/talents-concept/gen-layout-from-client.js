// Gera AzaathUI/Modules/TalentLayoutData.lua a partir das tabelas do PRÓPRIO cliente do
// WoW Forever (TraitNode, TraitEdge, TraitNodeXTraitNodeEntry, TraitNodeEntry), sem nenhum addon.
//
// O jogo tem uma árvore única por classe (C_Traits); as três sendas clássicas estão lado a lado
// numa grade de 600 unidades. Daqui sai, para cada talento: senda, fileira, coluna, pontos e
// pré-requisito. Nome, ícone e descrição o Crisol continua lendo do jogo em tempo real.
//
// Regras (conferidas em 21/11/2026: 467 de 467 talentos iguais ao mapa usado antes):
//   * nós fora da grade são descartados: X sem vizinho a 450..3000 e sozinho na coluna, ou Y
//     a mais de 1500 de todos os outros (restos invisíveis no jogo);
//   * sendas = 3 grupos separados pelas 2 maiores lacunas em X; fileira e coluna = níveis de Y e X
//     (tolerância 150);
//   * pré-requisito = ligação TraitEdge de tipo 2 ou 3 (tipo 0 é só desenho).
//
// Uso: node tools/talents-concept/gen-layout-from-client.js

const fs = require("fs");
const path = require("path");
const { openCasc } = require("../map-extract/casc.js");
const { parseWDC5 } = require("../map-extract/db2.js");

const WOW = "C:/Program Files (x86)/World of Warcraft";
const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Modules", "TalentLayoutData.lua");
const DB = { node: 4420297, edge: 4420308, nodeXEntry: 4420304, entry: 4420298 }; // fileDataIDs (wow-listfile)

// árvore do jogo e sendas (esquerda para a direita) de cada classe
const CLASSES = [
  ["WARRIOR", 1117, ["WarriorArms", "WarriorFury", "WarriorProtection"]],
  ["PALADIN", 1100, ["PaladinHoly", "PaladinProtection", "PaladinCombat"]],
  ["HUNTER", 1091, ["HunterBeastMastery", "HunterMarksmanship", "HunterSurvival"]],
  ["ROGUE", 1111, ["RogueAssassination", "RogueCombat", "RogueSubtlety"]],
  ["PRIEST", 1114, ["PriestDiscipline", "PriestHoly", "PriestShadow"]],
  ["SHAMAN", 1082, ["ShamanElementalCombat", "ShamanEnhancement", "ShamanRestoration"]],
  ["MAGE", 1112, ["MageArcane", "MageFire", "MageFrost"]],
  ["WARLOCK", 1116, ["WarlockCurses", "WarlockSummoning", "WarlockDestruction"]],
  ["DRUID", 1089, ["DruidBalance", "DruidFeralCombat", "DruidRestoration"]],
];

function levels(values, tol) {
  const v = [...values].sort((a, b) => a - b), lv = [];
  for (const x of v) if (!lv.length || x - lv[lv.length - 1] > tol) lv.push(x);
  return x => {
    let best = 1, bd = Infinity;
    lv.forEach((l, i) => { const d = Math.abs(x - l); if (d < bd) { bd = d; best = i + 1; } });
    return best;
  };
}

function clientBuild() {
  try {
    const lines = fs.readFileSync(path.join(WOW, ".build.info"), "utf8").split(/\r?\n/);
    const head = lines[0].split("|").map(h => h.split("!")[0]);
    for (const l of lines.slice(1)) {
      const cols = l.split("|");
      const row = Object.fromEntries(head.map((h, i) => [h, cols[i]]));
      if (row.Product === "wowf" && row.Version) return row.Version;
    }
  } catch (e) { /* sem .build.info */ }
  return "?";
}

(async () => {
  const casc = await openCasc(WOW, "wowf");
  const rows = fid => parseWDC5(casc.readFid(fid)).rows;
  const nodes = rows(DB.node), edges = rows(DB.edge), nxe = rows(DB.nodeXEntry), entries = rows(DB.entry);

  const entryRanks = new Map(entries.map(r => [r.id, r.vals[2]]));
  const ranks = new Map();
  for (const r of nxe) ranks.set(r.vals[1], Math.max(ranks.get(r.vals[1]) || 0, entryRanks.get(r.vals[2]) || 0));
  const parents = new Map(); // filho -> pais
  for (const e of edges) {
    const [, , from, to, type] = e.vals;
    if (type !== 2 && type !== 3) continue;
    if (!parents.has(to)) parents.set(to, []);
    parents.get(to).push(from);
  }

  const out = [];
  out.push("--[[----------------------------------------------------------------------------");
  out.push("    AzaathUI - Modules/TalentLayoutData.lua  (GERADO, não editar à mão)");
  out.push("    Mapa das árvores de talentos tirado do próprio cliente do WoW Forever");
  out.push("    (tabelas TraitNode/TraitEdge), build " + clientBuild() + ".");
  out.push("    Gerado por tools/talents-concept/gen-layout-from-client.js.");
  out.push("");
  out.push("    Só a estrutura: senda, fileira (row), coluna (col), pontos (max), nó do jogo e");
  out.push("    pré-requisito (req = índice do talento na mesma senda). Nome, ícone e descrição");
  out.push("    vêm do jogo em tempo real.");
  out.push("------------------------------------------------------------------------------]]");
  out.push("");
  out.push("local _, Azaath = ...");
  out.push("");
  out.push("Azaath.TalentLayoutData = {");
  out.push(`    build = "${clientBuild()}",`);
  out.push("    classes = {");

  let total = 0;
  for (const [cls, treeID, bgs] of CLASSES) {
    let list = nodes.filter(r => r.vals[1] === treeID && (ranks.get(r.id) || 0) > 0)
      .map(r => ({ id: r.id, x: r.vals[2], y: r.vals[3], max: ranks.get(r.id) }));
    list = list.filter(n => {
      const shareX = list.some(o => o !== n && Math.abs(o.x - n.x) <= 150);
      let near = Infinity;
      for (const o of list) if (o.x !== n.x) near = Math.min(near, Math.abs(o.x - n.x));
      const offGrid = !shareX && (near < 450 || near > 3000);
      const lonelyY = list.every(o => o === n || Math.abs(o.y - n.y) > 1500);
      return !offGrid && !lonelyY;
    });
    list.sort((a, b) => a.x - b.x);
    const gaps = [];
    for (let i = 1; i < list.length; i++) gaps.push({ i, d: list[i].x - list[i - 1].x });
    gaps.sort((a, b) => b.d - a.d);
    const cuts = gaps.slice(0, 2).map(g => g.i).sort((a, b) => a - b);
    let g = 0;
    list.forEach((n, i) => { while (cuts[g] !== undefined && i >= cuts[g]) g++; n.tab = g + 1; });

    out.push(`        ${cls} = {`);
    out.push(`            tree = ${treeID},`);
    out.push("            trees = {");
    for (let t = 1; t <= 3; t++) {
      const m = list.filter(n => n.tab === t);
      const colOf = levels(m.map(n => n.x), 150), rowOf = levels(m.map(n => n.y), 150);
      m.forEach(n => { n.col = colOf(n.x); n.row = rowOf(n.y); });
      m.sort((a, b) => a.row - b.row || a.col - b.col);
      const index = new Map(m.map((n, i) => [n.id, i + 1]));
      out.push(`                { bg = "${bgs[t - 1]}", talents = {`);
      for (const n of m) {
        const req = (parents.get(n.id) || []).map(p => index.get(p)).find(Boolean);
        out.push(`                    { row = ${n.row}, col = ${n.col}, max = ${n.max}, node = ${n.id}${req ? `, req = ${req}` : ""} },`);
        total++;
      }
      out.push("                } },");
    }
    out.push("            },");
    out.push("        },");
  }
  out.push("    },");
  out.push("}");
  fs.writeFileSync(OUT, out.join("\n") + "\n");
  console.log(`gravado ${OUT}: ${total} talentos, 9 classes`);
})().catch(e => { console.error("ERRO", e.stack); process.exit(1); });
