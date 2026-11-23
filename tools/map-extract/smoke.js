// Teste rápido: abre o CASC do cliente e lê as tabelas do mapa pelos FileDataIDs conhecidos.
const { openCasc } = require("./casc.js");
const { parseWDC5 } = require("./db2.js");
const FIDS = { WorldMapOverlay: 1134579, WorldMapOverlayTile: 1957212, UiMap: 1957206, UiMapArt: 1957202,
  UiMapArtTile: 1957210, UiMapXMapArt: 1957217, UiMapAssignment: 1957406, AreaTable: 1353545, Map: 1349477 };
(async () => {
  const casc = await openCasc("C:/Program Files (x86)/World of Warcraft", "wowf");
  for (const [n, fid] of Object.entries(FIDS)) {
    const buf = casc.readFid(fid);
    if (!buf) { console.log(n.padEnd(20), fid, "não achado"); continue; }
    try { const t = parseWDC5(buf); console.log(n.padEnd(20), fid, buf.slice(0, 4).toString(), t.rows.length, "linhas; ex:", JSON.stringify(t.rows[0].vals).slice(0, 90)); }
    catch (e) { console.log(n.padEnd(20), fid, buf.slice(0, 4).toString(), "parse:", e.message); }
  }
})().catch(e => console.error("ERRO", e.message));
