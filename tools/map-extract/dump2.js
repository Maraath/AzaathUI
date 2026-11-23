const { openCasc } = require("./casc.js");
const { parseWDC5 } = require("./db2.js");
(async () => {
  const casc = await openCasc("C:/Program Files (x86)/World of Warcraft", "wowf");
  const T = (f) => parseWDC5(casc.readFid(f)).rows;
  const ov = T(1134579), ot = T(1957212), xa = T(1957217), at = T(1957210);
  const ovArts = new Set(ov.map(r => r.vals[1]));
  const zoneArt = new Map(xa.map(r => [r.ref, r.vals[1]]));
  let withOv = 0, without = [];
  for (const [ui, art] of zoneArt) (ovArts.has(art) ? withOv++ : without.push(ui + ":" + art));
  console.log("mapas", zoneArt.size, "com partes", withOv, "sem:", without.join(" "));
  const artsNotInX = [...ovArts].filter(a => ![...zoneArt.values()].includes(a));
  console.log("artes com partes mas sem mapa ligado:", artsNotInX.join(" "));
  const tilesPerOv = new Map(); for (const r of ot) tilesPerOv.set(r.ref, (tilesPerOv.get(r.ref) || 0) + 1);
  console.log("partes sem quadro:", ov.filter(r => !tilesPerOv.has(r.id)).length, "camadas>0:", ot.filter(r => r.vals[2] > 0).length);
  const d = ov.filter(r => r.vals[1] === 2169); console.log("Durotar(2169) partes:", d.length, JSON.stringify(d.slice(0, 3).map(r => r.vals)));
  // tamanho das imagens BLP dos quadros
  const { readBLP } = require("./imagecodec.js");
  const fs = require("fs"); const tmp = process.env.TEMP + "/t.blp";
  for (const r of ot.slice(0, 4)) { fs.writeFileSync(tmp, casc.readFid(r.vals[3])); const im = readBLP(tmp); console.log("quadro", r.vals[3], im.w + "x" + im.h); }
})();
