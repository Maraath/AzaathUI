// Geometria da aba Santuário em px da arte (2000x1125). Copiada para Sheet/Sanctuary.lua
// (SANCT_*); preview.js desenha tudo sobre a arte para conferir o alinhamento.
const LEFT_SPINE = [[77, 249], [67, 367], [62, 480], [66, 593], [67, 712], [78, 827], [90, 940]];
const RIGHT_SPINE = [[1410, 247], [1417, 362], [1422, 477], [1422, 592], [1417, 710], [1409, 822], [1398, 940]];

// troncos: seguem os fios de energia pintados, do início do fio até a borda do altar
const TRUNKS = {
  A: [[150, 290], [262, 385], [335, 520], [440, 640], [585, 700]],
  B: [[205, 585], [350, 660], [462, 718], [545, 748]],
  C: [[200, 885], [340, 898], [462, 858], [578, 815]],
  D: [[1300, 310], [1222, 420], [1180, 545], [1080, 645], [945, 700]],
  E: [[1378, 582], [1240, 660], [1120, 712], [1030, 742]],
  F: [[1360, 910], [1180, 890], [1080, 850], [1000, 818]],
  G: [[668, 975], [672, 905], [700, 848]],
  H: [[868, 975], [880, 900], [862, 848]],
};
// slots de cada lado (8) -> tronco
const LEFT_TRUNK = ["A", "A", "A", "B", "B", "C", "C", "C"];
const RIGHT_TRUNK = ["D", "D", "D", "E", "E", "F", "F", "F"];
const WEAPONS = [[614, 1020], [705, 1020], [785, 1020], [862, 1020]];
const WEAPON_TRUNK = ["G", "G", "H", "H"];
const ALTAR = [790, 762];

function along(spine, n) {
  // n pontos com y igualmente espaçado entre o primeiro e o último ponto da linha
  const y0 = spine[0][1], y1 = spine[spine.length - 1][1], out = [];
  for (let i = 0; i < n; i++) {
    const y = y0 + (y1 - y0) * i / (n - 1);
    let k = 0; while (k < spine.length - 2 && spine[k + 1][1] < y) k++;
    const [ax, ay] = spine[k], [bx, by] = spine[k + 1];
    out.push([ax + (bx - ax) * (y - ay) / (by - ay), y]);
  }
  return out;
}
module.exports = { LEFT_SPINE, RIGHT_SPINE, TRUNKS, LEFT_TRUNK, RIGHT_TRUNK, WEAPONS, WEAPON_TRUNK, ALTAR, along };
