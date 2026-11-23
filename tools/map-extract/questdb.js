#!/usr/bin/env node
// tools/map-extract/questdb.js
// Converte ForeverLoremaster/Data/Quests.lua + QuestNames_ptBR.lua
// para o formato TSV de Azaath.QuestDBRaw em Data/Quests/QuestDB.lua.
// A profissão exigida ("SkillLine:nível") vem do QuestieDB (questie-skills.js).
//
// Uso: node tools/map-extract/questdb.js
//
// Formato de saída (colunas separadas por TAB):
// id  level  minLevel  races  raceHigh  classes  faction  zone
// sMap  sX  sY  eMap  eX  eY  preAll  preAny  excl  startId  endId
// title  skill  qflags

'use strict';
const fs   = require('fs');
const path = require('path');

const FL_DIR = 'C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/ForeverLoremaster/Data';
const OUT    = path.resolve(__dirname, '../../AzaathUI/Data/Quests/QuestDB.lua');
const { readQuestieMeta } = require('./questie-skills.js');   // GPL-3.0, só profissão/nível
const qmeta = readQuestieMeta();

// Bitmasks de raça (WotLK padrão)
const ALLIANCE_RACES = 1 + 4 + 8 + 64 + 1024;   // Human+Dwarf+NightElf+Gnome+Draenei
const HORDE_RACES    = 2 + 16 + 32 + 128 + 512;  // Orc+Undead+Tauren+Troll+BloodElf
const POW32          = 4294967296;                 // 2^32

function deriveFaction(races) {
    if (races === 0) return 0;
    const a = (races & ALLIANCE_RACES) !== 0;
    const h = (races & HORDE_RACES) !== 0;
    if (a && !h) return 1;
    if (h && !a) return 2;
    return 0;
}

// Coord no formato "x,y,mapID" → [x, y, mapID]
function parseCoord(s) {
    if (!s) return [0, 0, 0];
    const p = s.split(',');
    if (p.length < 3) return [0, 0, 0];
    return [
        parseFloat(p[0]) || 0,
        parseFloat(p[1]) || 0,
        parseInt(p[2])   || 0,
    ];
}

// --- QuestNames_ptBR.lua ---
process.stdout.write('Lendo QuestNames_ptBR.lua... ');
const namesText = fs.readFileSync(path.join(FL_DIR, 'QuestNames_ptBR.lua'), 'utf8');
const ptbrNames = {};
const nameRe = /^\s*\[(\d+)\] = "([^"]*)",?/gm;
let m;
while ((m = nameRe.exec(namesText)) !== null) {
    ptbrNames[parseInt(m[1])] = m[2];
}
console.log(`${Object.keys(ptbrNames).length} nomes PT-BR`);

// --- Quests.lua ---
process.stdout.write('Lendo Quests.lua... ');
const questsText = fs.readFileSync(path.join(FL_DIR, 'Quests.lua'), 'utf8');
const questRe    = /^\s*\[(\d+)\] = "([^"]*)",?/gm;
const rows       = [];
let   skipped    = 0;

while ((m = questRe.exec(questsText)) !== null) {
    const qid = parseInt(m[1]);
    const raw = m[2];
    const f   = raw.split(';');

    if (f.length < 21) { skipped++; continue; }

    const minLevel  = parseInt(f[0])  || 0;
    const level     = parseInt(f[1])  || 0;
    const raceMaskN = Number(f[2])    || 0;
    const classes   = parseInt(f[3])  || 0;
    const zone      = parseInt(f[4])  || 0;
    // f[5] = sort (não usado)
    const preAll    = f[6]  || '';
    const preAny    = f[7]  || '';
    const excl      = f[8]  || '';
    // f[9]=next, f[10]=breadcrumbFor (não usados)
    const startId   = parseInt(f[11]) || 0;
    const coordS    = f[12] || '';
    // f[13]=xp, f[14]=xpKind (não usados)
    const flags     = parseInt(f[15]) || 0;
    // f[16]=rewards (não usado)
    const nameEn    = f[17] || '';
    // f[18]=origin (não usado)
    const endId     = parseInt(f[19]) || 0;
    const coordE    = f[20] || '';
    // f[21]=starterItem, f[22]=drops (não usados)
    const event     = (f.length >= 27) ? (parseInt(f[26]) || 0) : 0;

    // Separa raceMask em dois campos de 32 bits
    const raceHigh = Math.floor(raceMaskN / POW32);
    const races    = raceMaskN % POW32;
    const faction  = deriveFaction(races);

    const [sX, sY, sMap] = parseCoord(coordS);
    const [eX, eY, eMap] = parseCoord(coordE);

    let qflags = '';
    if (flags & 1) qflags += 'R';
    if (event)     qflags += 'E';

    const title = ptbrNames[qid] || nameEn;
    const qs    = qmeta.get(qid) && qmeta.get(qid).skill;

    rows.push([
        qid, level, minLevel,
        races, raceHigh, classes, faction, zone,
        sMap, sX, sY,
        eMap, eX, eY,
        preAll, preAny, excl,
        startId, endId,
        title,
        qs ? qs[0] + ':' + qs[1] : '',
        qflags,
    ].join('\t'));
}

rows.sort((a, b) => parseInt(a.split('\t')[0]) - parseInt(b.split('\t')[0]));
console.log(`${rows.length} quests (${skipped} ignoradas por dados insuficientes)`);

// --- Spot-check ---
const SPOT = [2, 5, 26, 1, 8578];
console.log('\nSpot-check:');
for (const id of SPOT) {
    const r = rows.find(r => r.startsWith(id + '\t'));
    if (r) {
        const f = r.split('\t');
        console.log(`  [${id}] level=${f[1]} minLv=${f[2]} races=${f[3]} raceHi=${f[4]} zone=${f[7]} title="${f[19]}"`);
    } else {
        console.log(`  [${id}] NÃO ENCONTRADO`);
    }
}

// --- QuestDB.lua ---
const header = `-- GERADO por tools/map-extract/questdb.js. Não edite à mão.
-- Fonte: ForeverLoremaster/Data/Quests.lua + QuestNames_ptBR.lua; profissão do QuestieDB (GPL-3.0)
-- Gerado em: ${new Date().toISOString().slice(0, 10)}
-- ${rows.length} quests
-- Colunas (TAB): id level minLevel races raceHigh classes faction zone sMap sX sY eMap eX eY preAll preAny excl startId endId title skill qflags

local _, Azaath = ...
Azaath.QuestDBRaw = [=[
`;

const footer = '\n]=]\n';

fs.writeFileSync(OUT, header + rows.join('\n') + footer, 'utf8');
console.log(`\nEscrito: ${OUT}`);
console.log(`Total: ${rows.length} quests, ${(fs.statSync(OUT).size / 1024).toFixed(1)} KB`);
