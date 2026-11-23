// Desenha a geometria (layout.js) sobre a arte de conceito: preview/paths.png
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");
const L = require("./layout");

const im = readPNG(path.join(__dirname, process.argv[2] === "bg" ? "preview/bg.png" : "concept.png"));
function dot(x, y, r, c) {
  for (let yy = Math.floor(y - r); yy <= y + r; yy++) for (let xx = Math.floor(x - r); xx <= x + r; xx++) {
    if (xx < 0 || yy < 0 || xx >= im.w || yy >= im.h || (xx - x) ** 2 + (yy - y) ** 2 > r * r) continue;
    const o = (yy * im.w + xx) * 4; im.px[o] = c[0]; im.px[o + 1] = c[1]; im.px[o + 2] = c[2];
  }
}
function line(a, b, c, r = 1.2) {
  const len = Math.hypot(b[0] - a[0], b[1] - a[1]);
  for (let s = 0; s <= len; s += 0.7) dot(a[0] + (b[0] - a[0]) * s / len, a[1] + (b[1] - a[1]) * s / len, r, c);
}
const RED = [255, 60, 60], YEL = [255, 230, 40], MAG = [255, 0, 255];
for (const pts of Object.values(L.TRUNKS)) { for (let i = 0; i < pts.length - 1; i++) line(pts[i], pts[i + 1], RED, 1.6); pts.forEach((p) => dot(p[0], p[1], 4, YEL)); }
const ls = L.along(L.LEFT_SPINE, 8), rs = L.along(L.RIGHT_SPINE, 8);
ls.forEach((p, i) => { dot(p[0], p[1], 22, MAG); line(p, L.TRUNKS[L.LEFT_TRUNK[i]][0], YEL); });
rs.forEach((p, i) => { dot(p[0], p[1], 22, MAG); line(p, L.TRUNKS[L.RIGHT_TRUNK[i]][0], YEL); });
L.WEAPONS.forEach((p, i) => { dot(p[0], p[1], 26, MAG); line(p, L.TRUNKS[L.WEAPON_TRUNK[i]][0], YEL); });
dot(L.ALTAR[0], L.ALTAR[1], 5, [0, 255, 0]);
I.writePNG(path.join(__dirname, "preview", "paths.png"), im);
