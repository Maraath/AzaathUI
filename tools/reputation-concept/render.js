// Prévia da aba Reputação como o jogo monta (mesmas medidas do REP no Sheet/Reputation.lua),
// com as texturas geradas e as fontes do addon, fotografada pelo Edge sem janela.
//   node tools/reputation-concept/render.js -> preview/render.png e preview/compare.png
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const FONTS = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Fonts").replace(/\\/g, "/");
const P = (f) => "file:///" + path.join(__dirname, "preview", f).replace(/\\/g, "/");

const LIST = { x: 417, y: 148 };
const entries = [
  { h: true, name: "ALIANÇA" },
  { name: "Altaforja", label: "Respeitado", v: "2.382 / 6.000", r: 2382 / 6000 },
  { name: "Darnassus", label: "Honrado", v: "5.296 / 12.000", r: 5296 / 12000 },
  { name: "Exilados de Gnomeregan", label: "Respeitado", v: "2.420 / 6.000", r: 2420 / 6000 },
  { name: "Ventobravo", label: "Honrado", v: "1.508 / 12.000", r: 1508 / 12000, sel: true },
];
let y = LIST.y, rows = "";
for (const e of entries) {
  if (e.h) {
    rows += `<div class="sp" style="left:${LIST.x}px;top:${y}px;width:822px;height:59px;background-position:0 0"></div>
      <div class="t cz" style="left:${LIST.x + 20}px;top:${y + 29}px">–</div>
      <div class="t cz" style="left:${LIST.x + 44}px;top:${y + 29}px;letter-spacing:3px">${e.name}</div>`;
    y += 62; continue;
  }
  rows += e.sel
    ? `<div class="sp" style="left:${LIST.x - 6}px;top:${y - 6}px;width:834px;height:65px;background-position:0 -128px"></div>`
    : `<div class="sp" style="left:${LIST.x}px;top:${y}px;width:822px;height:53px;background-position:0 -64px"></div>`;
  rows += `<div class="t" style="left:${LIST.x + 20}px;top:${y + 26}px;font-size:21px">${e.name}</div>
    <div class="t" style="left:${LIST.x + 448}px;top:${y + 22}px;font-size:17px">${e.label}</div>
    <div class="t r" style="left:${LIST.x + 794}px;top:${y + 22}px;font-size:19px">${e.v}</div>
    <div style="position:absolute;left:${LIST.x + 448}px;top:${y + 34}px;width:346px;height:4px;background:rgba(5,23,31,.85)"></div>
    <div style="position:absolute;left:${LIST.x + 448}px;top:${y + 33.5}px;width:${346 * e.r}px;height:5px;background:linear-gradient(90deg,rgb(48,94,92),rgb(74,150,133))"></div>`;
  y += 56;
}
const fw = 307 * (1508 / 12000);
const html = `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:pts;src:url("file:///${FONTS}/PTSans-Regular.ttf")}
@font-face{font-family:cz;src:url("file:///${FONTS}/Cinzel-Regular.ttf")}
body{margin:0;width:2000px;height:1125px;overflow:hidden;background:#000;position:relative}
.sp{position:absolute;background-image:url("${P("rows.png")}")}
.t{position:absolute;font-family:pts;color:#e0e2ea;transform:translateY(-50%);white-space:nowrap;text-shadow:1.5px 1.5px 1px #000}
.r{transform:translate(-100%,-50%)}
.c{transform:translate(-50%,-50%);text-align:center}
.cz{font-family:cz;font-size:22px;color:#dbc79e}
.runes{position:absolute;left:390px;top:70px;width:1240px;height:490px;background-image:url("${P("runes0.png")}");background-size:1240px 490px;mix-blend-mode:screen}
</style></head><body>
<img src="${P("bg.png")}" style="position:absolute;left:0;top:0">
<div class="runes"></div>
<img src="${P("panel.png")}" style="position:absolute;left:1590px;top:134px">
${rows}
<div class="t c" style="left:1788px;top:208px;font-size:34px;color:#edede8">Ventobravo</div>
<div class="t c" style="left:1788px;top:255px;font-size:24px;color:${"rgb(" + [0.39, 0.77, 0.53].map((v, i) => Math.round(255 * (v + ([0.62, 0.68, 0.62][i] - v) * 0.38))).join(",") + ")"}">Honrado</div>
<div style="position:absolute;left:1622px;top:285px;width:333px;height:34px;background:url('${P("parts.png")}') 0 0"></div>
<div style="position:absolute;left:1631px;top:291px;width:${fw}px;height:22px;background:url('${P("parts.png")}') -${(1 - fw / 128) * 0.6 * 128}px -40px;background-size:512px 128px"></div>
<div class="t c" style="left:1788px;top:302px;font-size:19px">1.508 / 12.000</div>
<div class="t" style="left:1788px;top:576px;width:345px;font-size:18px;white-space:normal;text-align:center;transform:translateX(-50%)">A capital da Aliança, bastião da humanidade nos Reinos do Leste.</div>
${["Declarar Guerra", "Mover para Inativos", "Acompanhar na Barra de Experiência"].map((l, i) => `
<div style="position:absolute;left:1625px;top:${894 + 37 * i}px;width:28px;height:28px;background:url('${P("parts.png")}') -340px 0"></div>
${i === 2 ? `<div style="position:absolute;left:1622px;top:${894 + 37 * i - 7}px;width:40px;height:40px;background:url('${P("parts.png")}') -380px 0;mix-blend-mode:screen"></div>` : ""}
<div class="t" style="left:1660px;top:${908 + 37 * i}px;font-size:20px">${l}</div>`).join("")}
</body></html>`;
const htmlFile = path.join(__dirname, "preview", "shot.html");
fs.writeFileSync(htmlFile, html);
// runas: quadro 0 do atlas em PNG separado para o CSS
const out = path.join(__dirname, "preview", "render.png");
spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--hide-scrollbars", "--force-device-scale-factor=1",
  "--allow-file-access-from-files", "--window-size=2000,1125", "--screenshot=" + out, "file:///" + htmlFile.replace(/\\/g, "/")]);
const a = readPNG(path.join(__dirname, "concept.png")), b = readPNG(out);
const cmp = I.create(2000, 2250, 0, 0, 0, 255);
I.blit(cmp, a, 0, 0); I.blit(cmp, b, 0, 1125);
I.writePNG(path.join(__dirname, "preview", "compare.png"), I.resize(cmp, 1000, 1125));
console.log("ok", out);
