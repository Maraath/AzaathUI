const { openCasc } = require("./casc.js");
const { parseWDC5 } = require("./db2.js");
(async () => {
  const casc = await openCasc("C:/Program Files (x86)/World of Warcraft", "wowf");
  for (const [n, fid] of Object.entries({ WorldMapOverlay: 1134579, WorldMapOverlayTile: 1957212, UiMapArtTile: 1957210, UiMapXMapArt: 1957217, UiMapArt: 1957202, UiMap: 1957206 })) {
    const t = parseWDC5(casc.readFid(fid));
    console.log("==", n, t.rows.length, "idIndex", t.header.idIndex);
    for (const r of t.rows.slice(0, 4)) console.log(r.id, r.ref, JSON.stringify(r.vals));
  }
})();
