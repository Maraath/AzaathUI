const { openCasc } = require("./casc.js");
const { readBLP } = require("./imagecodec.js");
const fs = require("fs");
(async () => {
  const casc = await openCasc("C:/Program Files (x86)/World of Warcraft", "wowf");
  for (const fid of [775971, 782779]) {
    const b = casc.readFid(fid);
    let o = 0, chunks = [];
    while (o + 8 <= b.length) { const id = b.toString("ascii", o, o + 4).split("").reverse().join(""), sz = b.readUInt32LE(o + 4); chunks.push(id + ":" + sz); if (id === "MAID") {
      let mm = 0, c0 = 64, c1 = 0, r0 = 64, r1 = 0, sample; for (let i = 0; i < 4096; i++) { const mini = b.readUInt32LE(o + 8 + i * 32 + 28); if (mini) { mm++; const c = i % 64, r = Math.floor(i / 64); c0 = Math.min(c0, c); c1 = Math.max(c1, c); r0 = Math.min(r0, r); r1 = Math.max(r1, r); sample = sample || [c, r, mini]; } }
      console.log("  minimapas", mm, "cols", c0, c1, "rows", r0, r1, "ex", sample);
      fs.writeFileSync(process.env.TEMP + "/m.blp", casc.readFid(sample[2])); const im = readBLP(process.env.TEMP + "/m.blp"); console.log("  tamanho", im.w, im.h); }
      o += 8 + sz; }
    console.log(fid, chunks.join(" "));
  }
})();
