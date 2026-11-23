// Prova visual do Reveal: monta a arte de uma zona e coloca por cima todas as partes reveladas.
//   node tools/map-extract/preview.js <UiMapArtID> <saida.png>
// A arte de baixo fica escurecida; as partes entram com a cor cheia. Se estiverem no lugar,
// as bordas das partes casam com o terreno de baixo sem degraus.
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");
const { openCasc } = require("./casc.js");
const { parseWDC5 } = require("./db2.js");
const { makeImage, readBLP, writePNG } = require("./imagecodec.js");

const WOW = process.env.WOW_DIR || "C:/Program Files (x86)/World of Warcraft";
const ART_TILE = 1957210; // UiMapArtTile: RowIndex, ColIndex, LayerIndex, FileDataID (pai: UiMapArtID)

(async () => {
  const art = Number(process.argv[2] || 2169);
  const out = process.argv[3] || path.join(os.tmpdir(), "reveal_" + art + ".png");
  const casc = await openCasc(WOW, "wowf");
  const tmp = path.join(os.tmpdir(), "azaath_prev.blp");
  const blp = (fid) => { const b = casc.readFid(fid); if (!b) return null; fs.writeFileSync(tmp, b); return readBLP(tmp); };

  const W = 1002, H = 668, img = makeImage(W, H);
  const put = (src, dx, dy, sw, sh, k) => {
    for (let y = 0; y < sh; y++) for (let x = 0; x < sw; x++) {
      const tx = dx + x, ty = dy + y;
      if (tx < 0 || ty < 0 || tx >= W || ty >= H || x >= src.w || y >= src.h) continue;
      const s = (y * src.w + x) * 4, d = (ty * W + tx) * 4, a = src.data[s + 3] / 255 * (k.alpha ?? 1);
      for (let c = 0; c < 3; c++) img.data[d + c] = img.data[d + c] * (1 - a) + src.data[s + c] * k.mul * a;
      img.data[d + 3] = 255;
    }
  };
  // arte da zona, escurecida (como "inexplorado")
  const tiles = parseWDC5(casc.readFid(ART_TILE)).rows.filter((r) => r.ref === art && r.vals[2] === 0);
  for (const t of tiles) { const im = blp(t.vals[3]); if (im) put(im, t.vals[1] * 256, t.vals[0] * 256, 256, 256, { mul: 0.35 }); }
  // partes reveladas por cima, cor cheia, a partir do Reveal.lua gerado
  const lua = fs.readFileSync(path.resolve(__dirname, "../../AzaathUI/Data/Map/Reveal.lua"), "utf8");
  const block = lua.split("\n\t[" + art + "] = {")[1];
  if (!block) throw new Error("arte " + art + " não está no Reveal.lua");
  let n = 0;
  for (const line of block.split("\n\t},")[0].split("\n")) {
    const m = line.match(/\{ ([\d, ]+) \}/); if (!m) continue;
    const [x, y, w, h, , ...fids] = m[1].split(",").map(Number);
    const cols = Math.ceil(w / 256);
    fids.forEach((fid, i) => {
      const r = Math.floor(i / cols), c = i % cols, im = blp(fid);
      if (im) put(im, x + c * 256, y + r * 256, Math.min(256, w - c * 256), Math.min(256, h - r * 256), { mul: 1 });
    });
    n++;
  }
  writePNG(out, img);
  console.log("arte", art, ":", tiles.length, "quadros de fundo,", n, "partes ->", out);
})().catch((e) => { console.error("ERRO:", e.stack || e.message); process.exit(1); });
