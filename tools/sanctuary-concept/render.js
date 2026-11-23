// Prévia do Santuário como o jogo monta (sem o modelo 3D e sem os textos):
// SanctuaryBG + grilhões (trança CrucibleStream + halo TalentBtnImbuir + orbes
// nas dobras, mesmos parâmetros do Sheet/Sanctuary.lua) + medalhões + card.
//   node tools/sanctuary-concept/render.js  ->  preview/render.png e preview/compare.png
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");
const L = require("./layout");
const MEDIA = path.join(__dirname, "..", "..", "AzaathUI", "Media");

function readTGA(file) {
  const b = fs.readFileSync(file);
  const w = b.readUInt16LE(12), h = b.readUInt16LE(14), bpp = b[16], top = (b[17] & 32) !== 0;
  const off = 18 + b[0], px = new Float32Array(w * h * 4), n = bpp / 8;
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const sy = top ? y : h - 1 - y, s = off + (sy * w + x) * n, d = (y * w + x) * 4;
    px[d] = b[s + 2]; px[d + 1] = b[s + 1]; px[d + 2] = b[s]; px[d + 3] = n === 4 ? b[s + 3] : 255;
  }
  return { w, h, px };
}
function sample(t, u, v, wrapU) {
  // u, v em 0..1 (bilinear)
  let x = u * t.w - 0.5, y = v * t.h - 0.5;
  const x0 = Math.floor(x), y0 = Math.floor(y), fx = x - x0, fy = y - y0, out = [0, 0, 0, 0];
  const px = (xx, yy) => {
    xx = wrapU ? ((xx % t.w) + t.w) % t.w : Math.max(0, Math.min(t.w - 1, xx));
    yy = Math.max(0, Math.min(t.h - 1, yy));
    return (yy * t.w + xx) * 4;
  };
  const a = px(x0, y0), b = px(x0 + 1, y0), c = px(x0, y0 + 1), d = px(x0 + 1, y0 + 1);
  for (let k = 0; k < 4; k++) out[k] = (t.px[a + k] * (1 - fx) + t.px[b + k] * fx) * (1 - fy) + (t.px[c + k] * (1 - fx) + t.px[d + k] * fx) * fy;
  return out;
}

const im = readPNG(path.join(__dirname, "preview", "bg.png"));
const STREAM = readTGA(path.join(MEDIA, "Talents", "CrucibleStream.tga"));
const DOT = readTGA(path.join(MEDIA, "Talents", "TalentBtnImbuir.tga"));
const BEZEL = readTGA(path.join(MEDIA, "Sheet", "SlotBezel.tga"));
const ROUND = readTGA(path.join(MEDIA, "Inventory", "SlotRound.tga"));
const CARD = readTGA(path.join(MEDIA, "Sheet", "AttrCard.tga"));

function add(x, y, c, a) {
  if (x < 0 || y < 0 || x >= im.w || y >= im.h) return;
  const o = (y * im.w + x) * 4;
  for (let k = 0; k < 3; k++) im.px[o + k] = Math.min(255, im.px[o + k] + c[k] * a);
}
function over(x, y, c, a) {
  if (x < 0 || y < 0 || x >= im.w || y >= im.h || a <= 0) return;
  const o = (y * im.w + x) * 4;
  for (let k = 0; k < 3; k++) im.px[o + k] = im.px[o + k] * (1 - a) + c[k] * a;
}
// quad de textura (centro, tamanho) com ADD ou BLEND
function quad(t, cx, cy, sw, sh, tint, alpha, mode) {
  for (let y = Math.floor(cy - sh / 2); y <= cy + sh / 2; y++) for (let x = Math.floor(cx - sw / 2); x <= cx + sw / 2; x++) {
    const u = (x + 0.5 - (cx - sw / 2)) / sw, v = (y + 0.5 - (cy - sh / 2)) / sh;
    if (u < 0 || v < 0 || u > 1 || v > 1) continue;
    const s = sample(t, u, v);
    const c = [s[0] * tint[0], s[1] * tint[1], s[2] * tint[2]], a = s[3] / 255 * alpha;
    if (mode === "ADD") add(x, y, c, a); else over(x, y, c, a);
  }
}
function chain(pts, w, col, lit, o = {}) {
  const tile = w * 4, size = w * (o.halo || 3), step = size * 0.4;
  let acc = 0, need = 0;
  const dotA = (lit ? 0.72 : 0.12) * 0.42;
  for (let i = 0; i < pts.length - 1; i++) {
    const [ax, ay] = pts[i], [bx, by] = pts[i + 1];
    const dx = bx - ax, dy = by - ay, len = Math.hypot(dx, dy);
    while (need <= len) { const u = need / len; quad(DOT, ax + dx * u, ay + dy * u, size, size, col, dotA, "ADD"); need += step; }
    need -= len;
    acc += len;
  }
  acc = 0;
  for (let i = 0; i < pts.length - 1; i++) {
    const [ax, ay] = pts[i], [bx, by] = pts[i + 1];
    const dx = bx - ax, dy = by - ay, len = Math.hypot(dx, dy), ux = dx / len, uy = dy / len;
    const x0 = Math.floor(Math.min(ax, bx) - w), x1 = Math.ceil(Math.max(ax, bx) + w), y0 = Math.floor(Math.min(ay, by) - w), y1 = Math.ceil(Math.max(ay, by) + w);
    for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
      const px = x + 0.5 - ax, py = y + 0.5 - ay, s = px * ux + py * uy, d = -px * uy + py * ux;
      if (s < 0 || s > len || Math.abs(d) > w / 2) continue;
      const t = sample(STREAM, (acc + s) / tile, d / w + 0.5, true);
      add(x, y, [t[0] * col[0], t[1] * col[1], t[2] * col[2]], t[3] / 255 * (lit ? 1 : 0.3));
    }
    acc += len;
  }
  const wv = 0.45, bc = col.map((v) => v + (1 - v) * wv);
  for (let i = o.capStart ? 0 : 1; i < pts.length - 1; i++) quad(DOT, pts[i][0], pts[i][1], w * (o.bend || 2.1), w * (o.bend || 2.1), bc, lit ? 1 : 0.35, "ADD");
}

const CYAN = [0.42, 0.90, 1.0], GOLD = [1.0, 0.78, 0.36];
const equipped = (i) => i % 3 !== 1; // prévia: alguns slots vazios
const left = L.along(L.LEFT_SPINE, 8), right = L.along(L.RIGHT_SPINE, 8);
const trunkLit = {};
const branches = [];
left.forEach((p, i) => { branches.push([p, L.LEFT_TRUNK[i], equipped(i)]); });
right.forEach((p, i) => { branches.push([p, L.RIGHT_TRUNK[i], equipped(i + 1)]); });
L.WEAPONS.forEach((p, i) => { branches.push([p, L.WEAPON_TRUNK[i], equipped(i + 2)]); });
for (const [, k, lit] of branches) trunkLit[k] = trunkLit[k] || lit;
// linha dos medalhões
for (const list of [left, right]) for (let i = 0; i < list.length - 1; i++) {
  const [ax, ay] = list[i], [bx, by] = list[i + 1], len = Math.hypot(bx - ax, by - ay);
  for (let s = 0; s <= len; s += 0.5) { const x = ax + (bx - ax) * s / len, y = ay + (by - ay) * s / len; for (let d = -1.2; d <= 1.2; d += 0.6) over(Math.round(x + d), Math.round(y), [128, 143, 158], 0.5); }
}
// fios da arte: quadro 0 do SanctuaryFlow (ADD), esticado de volta à escala da arte
const FL = JSON.parse(fs.readFileSync(path.join(__dirname, "preview", "flow.json"), "utf8"));
const FLOWT = readTGA(path.join(MEDIA, "Sheet", "SanctuaryFlow.tga"));
for (let y = 0; y < FL.h; y++) for (let x = 0; x < FL.w; x++) {
  const s = sample(FLOWT, ((x + 0.5) * FL.scale) / 2048, ((y + 0.5) * FL.scale) / 2048);
  add(FL.x + x, FL.y + y, s, 1);
}
// medalhões
const slotsAll = [...left.map((p) => [p, 46]), ...right.map((p) => [p, 46]), ...L.WEAPONS.map((p) => [p, 50])];
for (const [[x, y], s] of slotsAll) {
  quad(ROUND, x, y, s - 2, s - 2, [0.30, 0.34, 0.40], 1, "BLEND");
  quad(BEZEL, x, y, s * 1.25, s * 1.25, [1, 1, 1], 1, "BLEND");
}
// card (mesma conta do Lua)
const CW = 646, CH = 1254, box = { x: 1480, y: 100, w: 492, h: 963 };
const cs = Math.min(box.w / CW, box.h / CH), cx0 = box.x + (box.w - CW * cs) / 2, cy0 = box.y + (box.h - CH * cs) / 2;
for (let y = 0; y < Math.round(CH * cs); y++) for (let x = 0; x < Math.round(CW * cs); x++) {
  const s = sample(CARD, ((x + 0.5) / cs) / CARD.w, ((y + 0.5) / cs) / CARD.h);
  over(Math.round(cx0 + x), Math.round(cy0 + y), s, s[3] / 255);
}
const V = [[384, 352.5, 34], [528, 454.5, 30], [477.5, 622.5, 30], [289, 622.5, 30], [238.5, 454, 30]];
const EDGES = [[0, 1, 1], [0, 2, 1], [1, 2, 1], [1, 3, 1], [0, 4], [0, 3], [4, 1], [4, 3], [4, 2], [3, 2]];
for (const [a, b, g] of EDGES) {
  const A = V[a], B = V[b];
  const ax = A[0] - 61, ay = A[1] - 62, bx = B[0] - 61, by = B[1] - 62, len = Math.hypot(bx - ax, by - ay), ux = (bx - ax) / len, uy = (by - ay) / len;
  const n = EDGES.indexOf(EDGES.find((e) => e[0] === a && e[1] === b)) + 1;
  const q0 = [ax + ux * (A[2] + 2), ay + uy * (A[2] + 2)], q2 = [bx - ux * (B[2] + 2), by - uy * (B[2] + 2)];
  const T = (q) => [cx0 + q[0] * cs, cy0 + q[1] * cs];
  chain([T(q0), T(q2)], 20 * cs, g ? GOLD : CYAN, true, { halo: 2.4 });
}
I.writePNG(path.join(__dirname, "preview", "render.png"), im);

// lado a lado (metade da resolução)
const con = readPNG(path.join(__dirname, "concept.png"));
const half = (s) => I.resize(s, 1000, 563);
const cmp = I.create(2000, 563, 0, 0, 0, 255);
I.blit(cmp, half(con), 0, 0);
I.blit(cmp, half(im), 1000, 0);
I.writePNG(path.join(__dirname, "preview", "compare.png"), cmp);
console.log("prévia: preview/render.png, preview/compare.png");
