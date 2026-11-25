// Leitor mínimo de tabelas DB2 (WDC5) do cliente: linhas com id, valores dos campos e a chave
// estrangeira do "relationship map". Suporta campos sem compressão, bitpacked, comuns e de paleta.
"use strict";

function readBits(buf, base, bitOffset, bitSize) {
  let v = 0, mul = 1;
  for (let i = 0; i < bitSize; i++) {
    const bit = bitOffset + i;
    if ((buf[base + (bit >> 3)] >> (bit & 7)) & 1) v += mul;
    mul *= 2;
  }
  return v;
}

function parseWDC5(buf) {
  if (buf.toString("latin1", 0, 4) !== "WDC5") throw new Error("não é WDC5");
  let o = 136;
  const H = {};
  for (const k of ["recordCount", "fieldCount", "recordSize", "stringTableSize", "tableHash", "layoutHash", "minId", "maxId", "locale"]) { H[k] = buf.readUInt32LE(o); o += 4; }
  H.flags = buf.readUInt16LE(o); H.idIndex = buf.readUInt16LE(o + 2); o += 4;
  for (const k of ["totalFieldCount", "bitpackedDataOffset", "lookupColumnCount", "fieldStorageInfoSize", "commonDataSize", "palletDataSize", "sectionCount"]) { H[k] = buf.readUInt32LE(o); o += 4; }
  const sections = [];
  for (let s = 0; s < H.sectionCount; s++) {
    const sec = { tactKey: buf.readBigUInt64LE(o) };
    o += 8;
    for (const k of ["fileOffset", "recordCount", "stringTableSize", "offsetRecordsEnd", "idListSize", "relationshipDataSize", "offsetMapIdCount", "copyTableCount"]) { sec[k] = buf.readUInt32LE(o); o += 4; }
    sections.push(sec);
  }
  o += H.fieldCount * 4;                         // (field_structure)
  const info = [];
  for (let i = 0; i < H.fieldCount; i++) {
    info.push({ offBits: buf.readUInt16LE(o), sizeBits: buf.readUInt16LE(o + 2), addSize: buf.readUInt32LE(o + 4),
      type: buf.readUInt32LE(o + 8), v1: buf.readUInt32LE(o + 12), v2: buf.readUInt32LE(o + 16), v3: buf.readUInt32LE(o + 20) });
    o += 24;
  }
  const palletStart = o;
  o += H.palletDataSize;
  const commonStart = o;
  o += H.commonDataSize;
  // posições na paleta e nos dados comuns de cada campo
  let pOff = 0, cOff = 0;
  for (const f of info) {
    f.palletOff = pOff; f.commonOff = cOff;
    if (f.type === 3 || f.type === 4) pOff += f.addSize;
    if (f.type === 2) cOff += f.addSize;
  }
  // dados comuns: por campo, mapa id -> valor
  for (const f of info) {
    if (f.type !== 2) continue;
    f.common = new Map();
    for (let q = commonStart + f.commonOff; q < commonStart + f.commonOff + f.addSize; q += 8) f.common.set(buf.readUInt32LE(q), buf.readUInt32LE(q + 4));
  }
  const rows = [];
  for (const sec of sections) {
    if (sec.tactKey !== 0n) continue;               // seção cifrada (o CASC entrega zeros): sem dados
    let q = sec.fileOffset;
    const recStart = q;
    q += sec.recordCount * H.recordSize + sec.stringTableSize;
    const ids = [];
    for (let i = 0; i < sec.idListSize / 4; i++) ids.push(buf.readUInt32LE(q + i * 4));
    q += sec.idListSize;
    q += sec.copyTableCount * 8;
    q += sec.offsetMapIdCount * 6;
    const rel = new Map();
    if (sec.relationshipDataSize > 0) {
      const n = buf.readUInt32LE(q);
      for (let i = 0; i < n; i++) rel.set(buf.readUInt32LE(q + 12 + i * 8 + 4), buf.readUInt32LE(q + 12 + i * 8));
    }
    for (let r = 0; r < sec.recordCount; r++) {
      const base = recStart + r * H.recordSize;
      const id = ids.length ? ids[r] : null;
      const vals = info.map((f) => {
        if (f.type === 0) {
          // campos largos (ex.: vetor de 2 floats em 64 bits): palavras de 32 bits, sem perder precisão
          if (f.sizeBits > 32) {
            const words = [];
            for (let b = 0; b < f.sizeBits; b += 32) words.push(buf.readUInt32LE(base + (f.offBits + b) / 8));
            return words;
          }
          return readBits(buf, base, f.offBits, f.sizeBits);
        }
        if (f.type === 1 || f.type === 5) {
          let v = readBits(buf, base, f.v1, f.v2);
          if (f.type === 5 && v >= Math.pow(2, f.v2 - 1)) v -= Math.pow(2, f.v2);
          return v;
        }
        if (f.type === 2) return f.common.has(id) ? f.common.get(id) : f.v1;
        if (f.type === 3) return buf.readUInt32LE(palletStart + f.palletOff + readBits(buf, base, f.v1, f.v2) * 4);
        if (f.type === 4) {
          const idx = readBits(buf, base, f.v1, f.v2), arr = [];
          for (let k = 0; k < f.v3; k++) arr.push(buf.readUInt32LE(palletStart + f.palletOff + (idx * f.v3 + k) * 4));
          return arr;
        }
        return null;
      });
      rows.push({ id: id !== null ? id : vals[H.idIndex], vals, ref: rel.get(r), base });
    }
  }
  // texto de um campo de string. O valor é a distância do próprio campo até o texto, contada como se
  // os registros de todas as seções viessem juntos, seguidos de todas as tabelas de texto juntas
  // (com uma seção só, é a distância direta no arquivo).
  const secRec = (s) => s.recordCount * H.recordSize;
  const totalRec = sections.reduce((a, s) => a + secRec(s), 0);
  const str = (row, fi) => {
    if (!row.vals[fi]) return "";
    let before = 0, sec = null;
    for (const s of sections) {
      if (row.base >= s.fileOffset && row.base < s.fileOffset + secRec(s)) { sec = s; break; }
      before += secRec(s);
    }
    if (!sec) return "";
    let v = before + (row.base - sec.fileOffset) + info[fi].offBits / 8 + row.vals[fi] - totalRec;
    let p = -1;
    for (const s of sections) {
      if (v < s.stringTableSize) { p = s.fileOffset + secRec(s) + v; break; }
      v -= s.stringTableSize;
    }
    if (p < 0 || p >= buf.length) return "";
    let e = p;
    while (e < buf.length && buf[e] !== 0) e++;
    return buf.toString("utf8", p, e);
  };
  // float guardado em 32 bits
  const float = (u) => { const b = Buffer.alloc(4); b.writeUInt32LE(u >>> 0); return b.readFloatLE(0); };
  return { header: H, rows, info, str, float };
}

module.exports = { parseWDC5 };
