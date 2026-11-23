// Leitor do cache WDB do cliente (Cache/WDB/<locale>/*.wdb): o que o servidor do Forever já enviou
// ao cliente instalado, no idioma do cliente. Textos do jogo (Blizzard), só lidos.
//   questcache.wdb      -> título e objetivo (LogTitle / LogDescription) de cada missão vista
//   creaturecache.wdb   -> nome de cada criatura vista
//   gameobjectcache.wdb -> nome de cada objeto visto
// Formato (build 1.60.x): cabeçalho de 24 bytes; registros { id u32, tamanho u32, dados }.
// Missão: antes dos textos há um bloco de comprimentos em bits (MSB primeiro, 12 bytes):
// título 9, objetivo 12, descrição 12, ... e os textos vêm em seguida, sem separador.
// Criatura/objeto: os primeiros bytes trazem o tamanho do nome (com o zero final) e o nome.
"use strict";
const fs = require("fs");
const path = require("path");

const GAME = process.env.WOW_DIR || "C:/Program Files (x86)/World of Warcraft/_forever_";

function records(file) {
  const out = new Map();
  if (!fs.existsSync(file)) return out;
  const b = fs.readFileSync(file);
  let o = 24;
  while (o + 8 <= b.length) {
    const id = b.readUInt32LE(o), len = b.readUInt32LE(o + 4);
    if (!id && !len) break;
    out.set(id, b.subarray(o + 8, o + 8 + len));
    o += 8 + len;
  }
  return out;
}

// texto legível: UTF-8 válido, sem caracteres de controle (exceto quebra de linha)
function text(buf) {
  for (const c of buf) if (c < 32 && c !== 10 && c !== 13) return null;
  const s = buf.toString("utf8");
  if (s.includes("\uFFFD")) return null;
  return s;
}

function bits(d, pos, n) {
  let v = 0;
  for (let k = 0; k < n; k++) {
    const p = pos + k;
    v = (v << 1) | ((d[p >> 3] >> (7 - (p & 7))) & 1);
  }
  return v;
}

const LEN_BITS = [9, 12, 12, 9, 10, 8, 10, 8, 11]; // título, objetivo, descrição, área, retratos..., conclusão

// Testa cada byte como início do bloco de comprimentos; vale o candidato em que TODOS os textos são
// legíveis e o título começa com letra/número. Entre os válidos, fica o que lê mais texto (o bloco real
// cobre título, objetivo, descrição...; falsos começos acham só pedaços curtos).
function parseQuest(d) {
  let best = null, bestTotal = -1;
  for (let byte = 0; byte + 12 < d.length; byte++) {
    const lens = [];
    let q = byte * 8;
    for (const n of LEN_BITS) { lens.push(bits(d, q, n)); q += n; }
    const [T, D] = lens;
    if (T < 2 || T > 400) continue;
    const start = byte + 12;
    const total = lens.reduce((a, b) => a + b, 0);
    if (start + total > d.length || total <= bestTotal) continue;
    const title = text(d.subarray(start, start + T));
    if (!title || !/^[\p{L}\p{N}"'¡¿(]/u.test(title.trim())) continue;
    let ok = true, at = start;
    for (const n of lens) { if (text(d.subarray(at, at + n)) === null) { ok = false; break; } at += n; }
    if (!ok) continue;
    best = { title: title.trim(), objective: text(d.subarray(start + T, start + T + D)).trim() };
    bestTotal = total;
  }
  return best;
}

// criatura: tamanho do nome (com o zero final) no byte 4, nome a partir do byte 15
function parseCreature(d) {
  if (d.length < 16) return null;
  const n = d.readUInt32LE(4);
  if (n < 2 || 15 + n - 1 > d.length) return null;
  const s = text(d.subarray(15, 15 + n - 1));
  return s && /\p{L}/u.test(s) ? s.trim() : null;
}

// objeto: tipo u32, modelo u32 e o nome terminado em zero a partir do byte 8
function parseObject(d) {
  const end = d.indexOf(0, 8);
  if (end <= 9) return null;
  const s = text(d.subarray(8, end));
  return s && /\p{L}/u.test(s) ? s.trim() : null;
}

// marcas de texto do jogo: $B quebra de linha, $Gmasc:fem; gênero, $N/$C/$R nome/classe/raça
function cleanGameText(s) {
  return String(s || "")
    .replace(/\$[Bb]/g, " ")
    .replace(/\$[Gg]\s*([^:;]*):([^;]*);/g, "$1/$2")
    .replace(/\$\d+oa\s*/g, "") // quantidade do objetivo N (o número fica na lista de objetivos do jogo)
    .replace(/\$[Nn]/g, "{nome}").replace(/\$[Cc]/g, "{classe}").replace(/\$[Rr]/g, "{raça}")
    .replace(/\s+/g, " ").trim();
}

function readCache(locale = "ptBR") {
  const dir = path.join(GAME, "Cache/WDB", locale);
  const quests = new Map(), npcs = new Map(), objects = new Map();
  for (const [id, d] of records(path.join(dir, "questcache.wdb"))) {
    const q = parseQuest(d);
    if (q) quests.set(id, q);
  }
  for (const [id, d] of records(path.join(dir, "creaturecache.wdb"))) {
    const s = parseCreature(d);
    if (s) npcs.set(id, s);
  }
  for (const [id, d] of records(path.join(dir, "gameobjectcache.wdb"))) {
    const s = parseObject(d);
    if (s) objects.set(id, s);
  }
  return { quests, npcs, objects };
}

module.exports = { readCache, cleanGameText };

if (require.main === module) {
  const c = readCache(process.argv[2] || "ptBR");
  console.log(`missões ${c.quests.size}, criaturas ${c.npcs.size}, objetos ${c.objects.size}`);
  for (const id of [166, 96337, 95196]) console.log(id, c.quests.get(id));
}
