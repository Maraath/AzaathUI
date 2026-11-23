// Leitor CASC local (somente leitura) para o cliente do WoW: acha um arquivo pelo FileDataID e
// devolve seus bytes. Formatos: build config, índices .idx (v7), BLTE, ENCODING e ROOT (MFST).
// Uso: const casc = await openCasc("C:/Program Files (x86)/World of Warcraft", "wowf");
//      casc.readFid(123456) -> Buffer | null
"use strict";
const fs = require("fs");
const path = require("path");
const zlib = require("zlib");

const LOCALE = { enUS: 0x2, koKR: 0x4, frFR: 0x10, deDE: 0x20, zhCN: 0x40, esES: 0x80, zhTW: 0x100,
  enGB: 0x200, esMX: 0x1000, ruRU: 0x2000, ptBR: 0x4000, itIT: 0x8000, ptPT: 0x10000 };

function readBuildInfo(root, product) {
  const lines = fs.readFileSync(path.join(root, ".build.info"), "utf8").split(/\r?\n/).filter(Boolean);
  const head = lines[0].split("|").map((h) => h.split("!")[0]);
  for (const l of lines.slice(1)) {
    const v = l.split("|"), o = {};
    head.forEach((h, i) => (o[h] = v[i]));
    if (!product || o.Product === product) return o;
  }
  throw new Error("produto não encontrado em .build.info: " + product);
}

function readConfig(dataDir, key) {
  const f = path.join(dataDir, "config", key.slice(0, 2), key.slice(2, 4), key);
  const o = {};
  for (const l of fs.readFileSync(f, "utf8").split(/\r?\n/)) {
    const m = l.match(/^([\w-]+) = (.*)$/);
    if (m) o[m[1]] = m[2].split(" ");
  }
  return o;
}

// ---------------------------------------------------------------- índices locais
function loadIndices(dataDir) {
  const dir = path.join(dataDir, "data");
  const best = {};
  for (const f of fs.readdirSync(dir)) {
    const m = f.match(/^([0-9a-f]{2})([0-9a-f]{8})\.idx$/i);
    if (!m) continue;
    const b = parseInt(m[1], 16), v = parseInt(m[2], 16);
    if (!best[b] || best[b].v < v) best[b] = { v, f };
  }
  const map = new Map();           // ekey (9 bytes, hex) -> { archive, offset, size }
  for (const b of Object.keys(best)) {
    const buf = fs.readFileSync(path.join(dir, best[b].f));
    const hdrLen = buf.readUInt32LE(0);
    const sizeLen = buf[12], offLen = buf[13], keyLen = buf[14], offBits = buf[15];
    let p = (8 + hdrLen + 15) & ~15;
    const entriesSize = buf.readUInt32LE(p);
    p += 8;
    const entLen = keyLen + offLen + sizeLen;
    const end = p + entriesSize;
    for (; p + entLen <= end; p += entLen) {
      const key = buf.toString("hex", p, p + keyLen);
      if (map.has(key)) continue;
      let off = 0;
      for (let i = 0; i < offLen; i++) off = off * 256 + buf[p + keyLen + i];
      const div = Math.pow(2, offBits);
      const archive = Math.floor(off / div), offset = off % div;
      const size = buf.readUInt32LE(p + keyLen + offLen);
      map.set(key, { archive, offset, size });
    }
  }
  return map;
}

// ---------------------------------------------------------------- BLTE
function decodeBLTE(buf) {
  if (buf.toString("ascii", 0, 4) !== "BLTE") throw new Error("não é BLTE");
  const headerSize = buf.readUInt32BE(4);
  const out = [];
  if (headerSize === 0) {
    out.push(decodeChunk(buf.subarray(8)));
  } else {
    const count = buf.readUIntBE(9, 3);
    let p = 12, data = headerSize;
    for (let i = 0; i < count; i++) {
      const comp = buf.readUInt32BE(p), decomp = buf.readUInt32BE(p + 4);
      p += 24;                                 // (tam. comprimido, descomprimido, md5)
      const chunk = buf.subarray(data, data + comp);
      // blocos criptografados (a Blizzard cifra partes de algumas tabelas, ex.: seções de mapas
      // ainda não lançados): viram zeros do mesmo tamanho; o resto do arquivo continua legível
      out.push(chunk[0] === 0x45 ? Buffer.alloc(decomp) : decodeChunk(chunk));
      data += comp;
    }
  }
  return Buffer.concat(out);
}
function decodeChunk(c) {
  const mode = String.fromCharCode(c[0]);
  if (mode === "N") return c.subarray(1);
  if (mode === "Z") return zlib.inflateSync(c.subarray(1));
  if (mode === "E") throw new Error("bloco criptografado");
  throw new Error("modo BLTE desconhecido: " + mode);
}

// ---------------------------------------------------------------- hash de nomes (lookup3 hashlittle2)
function hashlittle2(k) {
  const rot = (x, s) => ((x << s) | (x >>> (32 - s))) >>> 0;
  let len = k.length, a, b, c;
  a = b = c = (0xdeadbeef + len) >>> 0;
  let i = 0;
  const mix = () => {
    a = (a - c) >>> 0; a = (a ^ rot(c, 4)) >>> 0; c = (c + b) >>> 0;
    b = (b - a) >>> 0; b = (b ^ rot(a, 6)) >>> 0; a = (a + c) >>> 0;
    c = (c - b) >>> 0; c = (c ^ rot(b, 8)) >>> 0; b = (b + a) >>> 0;
    a = (a - c) >>> 0; a = (a ^ rot(c, 16)) >>> 0; c = (c + b) >>> 0;
    b = (b - a) >>> 0; b = (b ^ rot(a, 19)) >>> 0; a = (a + c) >>> 0;
    c = (c - b) >>> 0; c = (c ^ rot(b, 4)) >>> 0; b = (b + a) >>> 0;
  };
  const fin = () => {
    c = (c ^ b) >>> 0; c = (c - rot(b, 14)) >>> 0; a = (a ^ c) >>> 0; a = (a - rot(c, 11)) >>> 0;
    b = (b ^ a) >>> 0; b = (b - rot(a, 25)) >>> 0; c = (c ^ b) >>> 0; c = (c - rot(b, 16)) >>> 0;
    a = (a ^ c) >>> 0; a = (a - rot(c, 4)) >>> 0; b = (b ^ a) >>> 0; b = (b - rot(a, 14)) >>> 0;
    c = (c ^ b) >>> 0; c = (c - rot(b, 24)) >>> 0;
  };
  const w = (j) => (k[j] | 0) | ((k[j + 1] | 0) << 8) | ((k[j + 2] | 0) << 16) | ((k[j + 3] | 0) << 24);
  while (len > 12) {
    a = (a + (w(i) >>> 0)) >>> 0; b = (b + (w(i + 4) >>> 0)) >>> 0; c = (c + (w(i + 8) >>> 0)) >>> 0;
    mix(); len -= 12; i += 12;
  }
  if (len === 0) return [c, b];
  const tail = Buffer.alloc(12);
  for (let j = 0; j < len; j++) tail[j] = k[i + j];
  a = (a + tail.readUInt32LE(0)) >>> 0; b = (b + tail.readUInt32LE(4)) >>> 0; c = (c + tail.readUInt32LE(8)) >>> 0;
  fin();
  return [c, b];
}
function nameHash(p) {
  const [c, b] = hashlittle2(Buffer.from(p.toUpperCase().split("/").join("\\"), "ascii"));
  const out = Buffer.alloc(8);
  out.writeUInt32LE(b, 0); out.writeUInt32LE(c, 4);
  return out.toString("hex");
}

async function openCasc(root, product = "wowf") {
  const dataDir = path.join(root, "Data");
  const info = readBuildInfo(root, product);
  const build = readConfig(dataDir, info["Build Key"]);
  const index = loadIndices(dataDir);
  const handles = {};
  const fd = (n) => handles[n] || (handles[n] = fs.openSync(path.join(dataDir, "data", "data." + String(n).padStart(3, "0")), "r"));

  function readEKey(ekeyHex) {
    const e = index.get(ekeyHex.slice(0, 18));
    if (!e) return null;
    const buf = Buffer.alloc(e.size);
    fs.readSync(fd(e.archive), buf, 0, e.size, e.offset);
    return decodeBLTE(buf.subarray(30));       // (cabeçalho de 30 bytes do arquivo de dados)
  }

  // ENCODING: ckey -> ekey
  const encBuf = readEKey(build.encoding[1]);
  const ckeyLen = encBuf[3], ekeyLen = encBuf[4];
  const cePage = encBuf.readUInt16BE(5) * 1024;
  const ceCount = encBuf.readUInt32BE(9);
  const especSize = encBuf.readUInt32BE(18);
  let p = 22 + especSize;
  const pageIndex = [];
  for (let i = 0; i < ceCount; i++) { pageIndex.push(encBuf.toString("hex", p, p + ckeyLen)); p += ckeyLen + 16; }
  const pagesStart = p;
  function ekeyOf(ckeyHex) {
    // a página cuja primeira chave é <= ckey
    let lo = 0, hi = ceCount - 1, pg = 0;
    while (lo <= hi) { const mid = (lo + hi) >> 1; if (pageIndex[mid] <= ckeyHex) { pg = mid; lo = mid + 1; } else hi = mid - 1; }
    let q = pagesStart + pg * cePage;
    const end = q + cePage;
    while (q < end) {
      const n = encBuf[q];
      if (n === 0) break;
      const ck = encBuf.toString("hex", q + 6, q + 6 + ckeyLen);
      if (ck === ckeyHex) return encBuf.toString("hex", q + 6 + ckeyLen, q + 6 + ckeyLen + ekeyLen);
      q += 6 + ckeyLen + n * ekeyLen;
    }
    return null;
  }

  // ROOT (MFST): fid -> ckey, preferindo o idioma pedido
  const rootBuf = readEKey(ekeyOf(build.root[0]));
  const fidMap = new Map();
  const nameMap = new Map();      // hash do caminho (hex, LE) -> fid
  {
    let q = 0, version = 1, hdr = 0;
    if (rootBuf.toString("ascii", 0, 4) === "TSFM") {
      hdr = rootBuf.readUInt32LE(4);
      version = rootBuf.readUInt32LE(8);
      q = hdr > 1000 ? 12 : hdr;               // (formato antigo: o 2º campo é a contagem)
      if (hdr > 1000) version = 1;
    }
    const want = LOCALE.ptBR | LOCALE.enUS;
    while (q < rootBuf.length) {
      const n = rootBuf.readUInt32LE(q);
      let content, locale;
      if (version >= 2) {
        locale = rootBuf.readUInt32LE(q + 4);
        const u1 = rootBuf.readUInt32LE(q + 8), u2 = rootBuf.readUInt32LE(q + 12), u3 = rootBuf[q + 16];
        content = u1 | u2 | (u3 << 17);
        q += 17;
      } else {
        content = rootBuf.readUInt32LE(q + 4);
        locale = rootBuf.readUInt32LE(q + 8);
        q += 12;
      }
      const ids = new Array(n);
      let fid = -1;
      for (let i = 0; i < n; i++) { fid = fid + 1 + rootBuf.readInt32LE(q + i * 4); ids[i] = fid; }
      q += n * 4;
      const ckeys = q;
      q += n * 16;
      if (!(content & 0x10000000)) {            // (hashes de nome: Jenkins lookup3 do caminho)
        for (let i = 0; i < n; i++) nameMap.set(rootBuf.toString("hex", q + i * 8, q + i * 8 + 8), ids[i]);
        q += n * 8;
      }
      const pt = (locale & LOCALE.ptBR) !== 0, en = (locale & LOCALE.enUS) !== 0;
      if (!(locale & want) && locale !== 0xffffffff) continue;
      if (content & 0x8000000 /* criptografado/baixa violência etc: ignorar? */) { /* mantém */ }
      for (let i = 0; i < n; i++) {
        const prev = fidMap.get(ids[i]);
        const rank = pt ? 2 : (en ? 1 : 0);
        if (prev && prev.rank >= rank) continue;
        fidMap.set(ids[i], { ck: rootBuf.toString("hex", ckeys + i * 16, ckeys + i * 16 + 16), rank });
      }
    }
  }

  return {
    build: info.Version,
    fileCount: fidMap.size,
    readFid(fid) {
      const r = fidMap.get(fid);
      if (!r) return null;
      const ek = ekeyOf(r.ck);
      if (!ek) return null;
      try { return readEKey(ek); } catch (e) { return null; }
    },
    has(fid) { return fidMap.has(fid); },
    fidOf(p) { return nameMap.get(nameHash(p)); },
  };
}

module.exports = { openCasc };
