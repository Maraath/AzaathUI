// Interiores (job "interiors" do extrator): cidades subterrâneas (Altaforja, Cidade Baixa), cavernas,
// minas e casas. O mapa de terreno (minimapa dos ADT) só mostra o mundo visto de cima; o que fica
// dentro das construções (WMO) tem minimapa próprio, o mesmo que o jogo mostra no minimapa quando
// você entra. Aqui montamos, para cada construção colocada nos continentes, uma imagem vista de cima
// no lugar e na escala do mundo, e a cortamos em quadros de 256 jardas.
//
// De onde vem cada coisa (tudo do cliente instalado):
//   - colocações: ADT _obj0 (MAID da WDT, 2ª entrada), chunk MODF: FileDataID do WMO, posição,
//     rotação (só o giro em torno do eixo vertical importa) e escala;
//   - WMO raiz: MOHD (wmoID) e MOGI (por grupo: flags e caixa local). Só grupos INTERNOS (0x2000);
//   - WMOMinimapTexture.db2 (FDID 1323241): GroupNum, BlockX, BlockY, FileDataID; pai = wmoID.
//     Cada quadro tem 2 pixels por jarda e cobre 128 jardas do grupo a partir do canto mínimo (x para a
//     direita, y para cima, imagem alinhada embaixo à esquerda; o resto da potência de 2 fica vazio).
//   - mundo = posição + giro(rot[1] + 180°) * local * escala  (conferido com as caixas do MODF em 301 de 301
//     colocações e com a arte oficial de Altaforja).
//
// Saída: AzaathUI/Data/Map/Interiors.lua e AzaathUI/Media/MapInterior/<inst>_<uid>_<col>_<row>.blp
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");
const { parseWDC5 } = require("./db2.js");
const { makeImage, readBLP, writeBLP } = require("./imagecodec.js");

const WMO_MINIMAP = 1323241;
const MID = 17066.666;
// pixels por jarda na saída (o jogo tem 2): 1 nos subterrâneos (cidades, cavernas, minas: sempre à vista) e nos
// pequenos; 0,5 nas construções grandes de superfície (só aparecem com você dentro); uma imagem só, do tamanho
// certo, quando cabe em 256 px
const RES_SMALL = 1, RES_BIG = 0.5, SMALL = 256;
// subterrâneo: a maior parte (por área) dos grupos internos tem o teto abaixo do chão do terreno (+ folga)
const UNDER_SLACK = 2, UNDER_SHARE = 0.5;
const CHUNK = 533.3333 / 16, NGRID = 1024;
const TILE = 256;           // pixels por quadro de saída
const INDOOR = 0x2000;
// cidades subterrâneas (sempre à vista): o interior que contém o ponto [instância, X, Y]
const CITY_POINTS = [[0, -4918, -958], [0, 1585, 240]];   // Altaforja (a Grande Forja), Cidade Baixa
const pow2 = (v) => { let p = 16; while (p < v) p *= 2; return p; };

const chunkList = (b) => {
  const o = [];
  let p = 0;
  while (p + 8 <= b.length) {
    const id = b.toString("ascii", p, p + 4).split("").reverse().join(""), sz = b.readUInt32LE(p + 4);
    o.push({ id, start: p + 8, size: sz });
    p += 8 + sz;
  }
  return o;
};

function buildInteriors(write, header, casc, continents, root, wowDir) {
  const tmp = path.join(os.tmpdir(), "azaath_int.blp");
  const blp = (fid) => { const b = casc.readFid(fid); if (!b) return null; fs.writeFileSync(tmp, b); return readBLP(tmp); };
  const dirs = [path.join(root, "AzaathUI/Media/MapInterior"), path.join(wowDir, "_forever_/Interface/AddOns/AzaathUI/Media/MapInterior")];
  for (const d of dirs) {
    try {
      fs.mkdirSync(d, { recursive: true });
      for (const f of fs.readdirSync(d)) if (f.endsWith(".blp")) fs.unlinkSync(path.join(d, f));
    } catch (e) { console.warn("  AVISO: pasta", d, "-", e.message); }
  }

  // quadros por wmoID -> grupo -> [{ bx, by, fid }]
  const byWmo = new Map();
  for (const r of parseWDC5(casc.readFid(WMO_MINIMAP)).rows) {
    const [g, bx, by, fid] = r.vals;
    if (!byWmo.has(r.ref)) byWmo.set(r.ref, new Map());
    const m = byWmo.get(r.ref);
    if (!m.has(g)) m.set(g, []);
    m.get(g).push({ bx, by: by & 255, fid });
  }

  const roots = new Map();   // FileDataID do WMO -> { id, groups: [{ flags, bb }] }
  const wmoRoot = (fid) => {
    if (roots.has(fid)) return roots.get(fid);
    let v = null;
    const w = casc.readFid(fid);
    if (w) {
      const cs = chunkList(w);
      const mohd = cs.find((c) => c.id === "MOHD"), mogi = cs.find((c) => c.id === "MOGI");
      if (mohd && mogi) {
        const groups = [];
        for (let o = mogi.start; o + 32 <= mogi.start + mogi.size; o += 32) {
          groups.push({ flags: w.readUInt32LE(o), bb: [4, 8, 12, 16, 20, 24].map((k) => w.readFloatLE(o + k)) });
        }
        v = { id: w.readUInt32LE(mohd.start + 32), groups };
      }
    }
    roots.set(fid, v);
    return v;
  };

  const lines = [];
  let nTiles = 0, bytes = 0;
  for (const { inst, wdt } of continents) {
    const b = casc.readFid(wdt);
    const maid = chunkList(b).find((c) => c.id === "MAID");
    const placed = new Map();
    for (let i = 0; i < 4096; i++) {
      const obj0 = b.readUInt32LE(maid.start + i * 32 + 4);
      if (!obj0) continue;
      const a = casc.readFid(obj0);
      if (!a) continue;
      for (const c of chunkList(a)) {
        if (c.id !== "MODF") continue;
        for (let k = 0; k + 64 <= c.size; k += 64) {
          const o = c.start + k, uid = a.readUInt32LE(o + 4);
          if (placed.has(uid)) continue;
          const f = (n) => a.readFloatLE(o + n);
          placed.set(uid, { uid, fid: a.readUInt32LE(o), pos: [f(8), f(12), f(16)], yaw: f(24), scale: (a.readUInt16LE(o + 62) || 1024) / 1024 });
        }
      }
    }
    // altura média do chão em cada pedaço de 33,3 jardas (ADT raiz: posição do MCNK + média do MCVT)
    const ground = new Float32Array(NGRID * NGRID).fill(NaN);
    for (let i = 0; i < 4096; i++) {
      const rootFid = b.readUInt32LE(maid.start + i * 32);
      if (!rootFid) continue;
      const a = casc.readFid(rootFid);
      if (!a) continue;
      const row = Math.floor(i / 64), col = i % 64;
      for (const c of chunkList(a)) {
        if (c.id !== "MCNK") continue;
        const ix = a.readUInt32LE(c.start + 4), iy = a.readUInt32LE(c.start + 8);
        if (ix > 15 || iy > 15) continue;
        let p = c.start + 128, h = null;
        while (p + 8 <= c.start + c.size) {
          const id = a.toString("ascii", p, p + 4), sz = a.readUInt32LE(p + 4);
          if (id === "TVCM") {        // MCVT invertido
            let m = 0;
            for (let k = 0; k < 145; k++) m += a.readFloatLE(p + 8 + k * 4);
            h = a.readFloatLE(c.start + 0x68 + 8) + m / 145;
            break;
          }
          p += 8 + sz;
        }
        if (h !== null) ground[(row * 16 + iy) * NGRID + col * 16 + ix] = h;
      }
    }
    const groundAt = (X, Y) => {
      const gx = Math.floor((MID - Y) / CHUNK), gy = Math.floor((MID - X) / CHUNK);
      if (gx < 0 || gy < 0 || gx >= NGRID || gy >= NGRID) return NaN;
      return ground[gy * NGRID + gx];
    };
    let made = 0, under = 0;
    for (const p of [...placed.values()].sort((x, y) => x.uid - y.uid)) {
      const w = wmoRoot(p.fid);
      const tiles = w && byWmo.get(w.id);
      if (!tiles) continue;
      const pX = MID - p.pos[2], pY = MID - p.pos[0];
      const t = (p.yaw + 180) * Math.PI / 180, C = Math.cos(t), S = Math.sin(t), k = p.scale;
      const toWorld = (lx, ly) => [pX + (lx * C - ly * S) * k, pY + (lx * S + ly * C) * k];
      // grupos internos com quadros, de baixo para cima
      const gs = [];
      for (const [g, list] of tiles) {
        const gr = w.groups[g];
        if (!gr || !(gr.flags & INDOOR)) continue;
        gs.push({ g, bb: gr.bb, list });
      }
      if (!gs.length) continue;
      gs.sort((x, y) => x.bb[2] - y.bb[2]);
      // caixa no mundo (X norte, Y oeste)
      let X0 = Infinity, X1 = -Infinity, Y0 = Infinity, Y1 = -Infinity;
      for (const q of gs) {
        q.wb = [Infinity, -Infinity, Infinity, -Infinity];
        for (const lx of [q.bb[0], q.bb[3]]) for (const ly of [q.bb[1], q.bb[4]]) {
          const [wx, wy] = toWorld(lx, ly);
          q.wb = [Math.min(q.wb[0], wx), Math.max(q.wb[1], wx), Math.min(q.wb[2], wy), Math.max(q.wb[3], wy)];
        }
        X0 = Math.min(X0, q.wb[0]); X1 = Math.max(X1, q.wb[1]); Y0 = Math.min(Y0, q.wb[2]); Y1 = Math.max(Y1, q.wb[3]);
      }
      const Xn = Math.ceil(X1), Yw = Math.ceil(Y1);              // canto noroeste
      // tipo: 1 cidade (Altaforja, Cidade Baixa), 2 subterrâneo (caverna, mina, cripta), 0 construção de superfície
      let below = 0, total = 0;
      for (const q of gs) {
        const area = (q.bb[3] - q.bb[0]) * (q.bb[4] - q.bb[1]);
        const [wx, wy] = toWorld((q.bb[0] + q.bb[3]) / 2, (q.bb[1] + q.bb[4]) / 2);
        const h = groundAt(wx, wy), top = p.pos[1] + q.bb[5] * k;
        total += area;
        if (!Number.isNaN(h) && top < h + UNDER_SLACK) below += area;
      }
      const city = CITY_POINTS.some(([ci, cx, cy]) => ci === inst && cx <= X1 && cx >= X0 && cy <= Y1 && cy >= Y0);
      const kind = city ? 1 : (total > 0 && below / total >= UNDER_SHARE ? 2 : 0);
      if (kind === 2) under++;
      const RES = kind > 0 || Math.max(X1 - X0, Y1 - Y0) <= SMALL ? RES_SMALL : RES_BIG;
      const Wpx = Math.ceil((Yw - Math.floor(Y0)) * RES), Hpx = Math.ceil((Xn - Math.floor(X0)) * RES);
      const img = makeImage(Wpx, Hpx);                            // (transparente)
      for (const q of gs) {
        const blocks = new Map();
        for (const e of q.list) { const im = blp(e.fid); if (im) blocks.set(e.bx + ":" + e.by, im); }
        const [minX, minY] = q.bb;
        const texel = (u, v) => {                                 // u, v em pixels do jogo a partir do canto mínimo
          if (u < 0 || v < 0) return null;
          const bx = Math.floor(u / 256), by = Math.floor(v / 256);
          const im = blocks.get(bx + ":" + by);
          if (!im) return null;
          const c = Math.floor(u - bx * 256), r = im.h - 1 - Math.floor(v - by * 256);
          if (c >= im.w || r < 0) return null;
          return [im, (r * im.w + c) * 4];
        };
        const i0 = Math.max(0, Math.floor((Yw - q.wb[3]) * RES)), i1 = Math.min(Wpx - 1, Math.ceil((Yw - q.wb[2]) * RES));
        const j0 = Math.max(0, Math.floor((Xn - q.wb[1]) * RES)), j1 = Math.min(Hpx - 1, Math.ceil((Xn - q.wb[0]) * RES));
        for (let j = j0; j <= j1; j++) {
          for (let i = i0; i <= i1; i++) {
            const wx = Xn - (j + 0.5) / RES, wy = Yw - (i + 0.5) / RES;
            // mundo -> local
            const dx = (wx - pX) / k, dy = (wy - pY) / k;
            const lx = dx * C + dy * S, ly = -dx * S + dy * C;
            if (lx < q.bb[0] || lx > q.bb[3] || ly < q.bb[1] || ly > q.bb[4]) continue;
            const u = (lx - minX) * 2, v = (ly - minY) * 2;
            let r = 0, g = 0, bl = 0, al = 0;
            for (const [ou, ov] of [[-0.5, -0.5], [0.5, -0.5], [-0.5, 0.5], [0.5, 0.5]]) {
              const s = texel(u + ou, v + ov);
              if (!s) continue;
              const [im, o] = s, a = im.data[o + 3];
              r += im.data[o] * a; g += im.data[o + 1] * a; bl += im.data[o + 2] * a; al += a;
            }
            if (al <= 0) continue;
            const sa = al / 4 / 255, d = (j * Wpx + i) * 4, da = img.data[d + 3] / 255;
            const oa = sa + da * (1 - sa);
            for (const [ch, val] of [[0, r / al], [1, g / al], [2, bl / al]]) {
              img.data[d + ch] = oa > 0 ? (val * sa + img.data[d + ch] * da * (1 - sa)) / oa : 0;
            }
            img.data[d + 3] = Math.round(oa * 255);
          }
        }
      }
      // quadros com conteúdo: uma imagem só (potência de 2) se cabe em 256 px, senão quadros de 256
      const single = Wpx <= TILE && Hpx <= TILE;
      const TW = single ? pow2(Wpx) : TILE, TH = single ? pow2(Hpx) : TILE;
      const cols = Math.ceil(Wpx / TW), rows = Math.ceil(Hpx / TH), keep = [];
      let opaque = 0;
      for (let r = 0; r < rows; r++) {
        for (let c = 0; c < cols; c++) {
          const tile = makeImage(TW, TH);
          let any = 0;
          for (let y = 0; y < TH; y++) {
            const sy = r * TH + y;
            if (sy >= Hpx) break;
            for (let x = 0; x < TW; x++) {
              const sx = c * TW + x;
              if (sx >= Wpx) break;
              const s = (sy * Wpx + sx) * 4, d = (y * TW + x) * 4;
              if (img.data[s + 3] > 0) any++;
              for (let ch = 0; ch < 4; ch++) tile.data[d + ch] = img.data[s + ch];
            }
          }
          if (any < 16) continue;
          opaque += any;
          const name = inst + "_" + p.uid + "_" + c + "_" + r + ".blp";
          for (const d of dirs) { try { writeBLP(path.join(d, name), tile, { alpha: true }); } catch (e) { /* aviso já dado */ } }
          keep.push(c + "," + r);
          nTiles++;
          bytes += TW * TH * 1.33;
        }
      }
      if (!keep.length) continue;
      if (kind === 1) console.log("  cidade: instância", inst, "wmo", w.id, "uid", p.uid, "em", Math.round(pX), Math.round(pY));
      lines.push("\t{ " + [inst, Xn, Yw, kind, p.uid, RES, TW, TH, '"' + keep.join(" ") + '"'].join(", ") + " },");
      made++;
    }
    console.log("interiors: instância", inst, "-", placed.size, "construções,", made, "com interior,", under, "subterrâneos");
  }
  const out = [header("Interiores das construções (cidades subterrâneas, cavernas, minas, casas) vistos de cima.", casc), "",
    "-- { instância, X norte, Y oeste (jardas do mundo, canto noroeste da imagem), tipo (1 cidade: sempre à vista;",
    "--   2: subterrâneo (caverna, mina), à vista de perto; 0: construção de superfície, só com você dentro), uid da colocação, pixels por jarda, largura e altura de cada quadro (px), quadros \"col,lin ...\" }",
    "-- O quadro (col, lin) começa em col * largura / pxPorJarda jardas para leste e lin * altura / pxPorJarda para o sul.",
    "-- Imagens: Media/MapInterior/<instância>_<uid>_<col>_<lin>.blp",
    "Azaath.MapData.Interiors = {", ...lines, "}", ""];
  write("Interiors.lua", out.join("\n"));
  console.log("interiors:", lines.length, "interiores,", nTiles, "imagens, ~" + (bytes / 1e6).toFixed(1) + " MB");
}

module.exports = { buildInteriors };
