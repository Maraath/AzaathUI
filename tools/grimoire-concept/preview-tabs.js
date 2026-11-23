// Prévia dos marcadores (efeito B + C): exporta as texturas usadas para PNG e
// escreve preview/tabs.html com as mesmas posições do Grimoire.lua.
// Uso: node preview-tabs.js  (depois renderizar o HTML com o Edge)
const fs = require("fs");
const I = require("../sheet-concept/img");
function readTGA(f) {
  const b = fs.readFileSync(f), idl = b[0], type = b[2], w = b.readUInt16LE(12), h = b.readUInt16LE(14), Bp = b[16] / 8, top = (b[17] & 0x20) !== 0;
  let p = 18 + idl; const raw = [];
  if (type === 10) { while (raw.length < w * h) { const c = b[p++], n = (c & 0x7f) + 1; if (c & 0x80) { const v = b.slice(p, p + Bp); p += Bp; for (let k = 0; k < n; k++) raw.push(v); } else for (let k = 0; k < n; k++) { raw.push(b.slice(p, p + Bp)); p += Bp; } } }
  else for (let i = 0; i < w * h; i++) { raw.push(b.slice(p, p + Bp)); p += Bp; }
  const px = new Float32Array(w * h * 4);
  for (let i = 0; i < w * h; i++) { const x = i % w, y = Math.floor(i / w), yy = top ? y : h - 1 - y, o = (yy * w + x) * 4, v = raw[i]; px[o] = v[2]; px[o + 1] = v[1]; px[o + 2] = v[0]; px[o + 3] = Bp === 4 ? v[3] : 255; }
  return { w, h, px };
}
const M = "../../AzaathUI/Media/";
for (const [n, f] of [["glow", "Glow"], ["diamond", "Diamond"], ["glassh", "UnitFrames/ClassicGlassH"], ["tabscut", "Grimoire/GrimTabsCut"], ["tabsglow", "Grimoire/GrimTabsGlow"], ["tabsedge", "Grimoire/GrimTabsEdge"]])
  I.writePNG(`preview/tx-${n}.png`, readTGA(M + f + ".tga"));

const TABS = [[275, 263, "GERAL"], [265, 337, "ARMAS"], [255, 410, "FÚRIA"], [245, 485, "PROTEÇÃO"]];
const CUT = [[215, 238, 103, 53], [204, 309, 107, 57], [193, 381, 108, 56], [181, 456, 121, 58]];
const FX = [[262, 309, 247.5, 283, 230, 266], [256, 302, 318, 355, 219, 339], [246, 292, 390.5, 426, 207, 410], [236, 294, 466.5, 501, 196, 486]];
const GLOW = [[197, 220, 139, 89], [186, 291, 143, 93], [175, 363, 144, 92], [163, 438, 157, 94]];
const STATE = [[0, 0], [4, 0.4], [0, 0], [9, 1]];   // pull, efeito (ARMAS = hover, PROTEÇÃO = selecionado)
let h = "";
const add = (x, y, w, hh, tex, alpha, tint) =>
  h += `<div class="a" style="left:${x - w / 2}px;top:${y - hh / 2}px;width:${w}px;height:${hh}px;opacity:${alpha};background:${tint};-webkit-mask:url(${tex}) 0 0/100% 100%"></div>`;
TABS.forEach(([tx, ty, name], i) => {
  const [p, a] = STATE[i], c = CUT[i], f = FX[i], on = i === 3, gb = GLOW[i];
  h += `<div class="a" style="left:${gb[0] - p}px;top:${gb[1]}px;width:${gb[2]}px;height:${gb[3]}px;opacity:${a * (on ? 0.5 : 0.32)};background:rgb(94,227,255);-webkit-mask:url(tx-tabsglow.png) ${-i * 160}px 0/1024px 128px"></div>`;
  h += `<div class="cut" style="left:${c[0] - p}px;top:${c[1]}px;width:${c[2]}px;height:${c[3]}px;background:url(tx-tabscut.png) ${-i * 128}px 0"></div>`;
  h += `<div class="a" style="left:${c[0] - p}px;top:${c[1]}px;width:${c[2]}px;height:${c[3]}px;opacity:${a * (on ? 0.9 : 0.6)};background:rgb(94,227,255);-webkit-mask:url(tx-tabsedge.png) ${-i * 128}px 0/512px 64px"></div>`;
  const g = on ? a : a * 0.5;
  add(f[4] - p, f[5], 16, 16, "tx-glow.png", g * 0.5, "rgb(94,227,255)");
  add(f[4] - p, f[5], 6, 8, "tx-diamond.png", g, "rgb(115,242,255)");
  add(f[4] - p, f[5], 3, 4, "tx-diamond.png", g, "rgb(242,255,255)");
  const col = on ? "rgb(255,224,153)" : (a > 0 ? "rgb(255,245,224)" : "rgb(237,224,199)");
  const x0 = f[4] + 12, x1 = c[0] + c[2] - 5;
  h += `<div class="t" data-max="${x1 - x0}" style="left:${(x0 + x1) / 2 - p}px;top:${ty}px;color:${col}">${name.split("").join("&#8202;")}</div>`;
});
fs.writeFileSync("preview/tabs.html", `<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Cinzel&display=swap" rel="stylesheet">
<style>*{margin:0;padding:0}body{background:#000;width:${170 * 3}px;height:${310 * 3}px;overflow:hidden}
.v{position:relative;width:170px;height:310px;transform:scale(3);transform-origin:0 0;overflow:hidden}
.in{position:absolute;left:-160px;top:-230px;width:1376px;height:768px}
.bg{position:absolute;inset:0;background:url(bg.png)}
.a{position:absolute;mix-blend-mode:screen}.cut{position:absolute}
.t{position:absolute;transform:translate(-50%,-50%);font:13px Cinzel,serif;letter-spacing:.15em;text-shadow:1px 1px 1px #000;white-space:nowrap}
</style></head><body><div class="v"><div class="in"><div class="bg"></div>${h}</div></div>
<script>document.fonts.ready.then(()=>document.querySelectorAll(".t").forEach(e=>{let s=13;while(s>9&&e.getBoundingClientRect().width/3>+e.dataset.max){s-=0.5;e.style.fontSize=s+"px"}}))</script>
</body></html>`);
console.log("ok");
