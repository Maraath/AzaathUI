// Prévia da página direita com o diagrama adaptável (texto curto x longo).
// Uso: node compare-right.js  -> preview/right-fit.html (renderizar com o Edge)
const fs = require("fs");
const I = require("../sheet-concept/img");

// diagrama com alfa -> PNG
const b = fs.readFileSync("../../AzaathUI/Media/Grimoire/GrimDiagram.tga");
const w = b.readUInt16LE(12), h = b.readUInt16LE(14), im = I.create(w, h);
for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
  const s = 18 + ((h - 1 - y) * w + x) * 4, o = (y * w + x) * 4;
  im.px[o] = b[s + 2]; im.px[o + 1] = b[s + 1]; im.px[o + 2] = b[s]; im.px[o + 3] = b[s + 3];
}
I.writePNG("preview/diagram-alpha.png", im);

const BOX = [755, 230, 226, 207], ICON = [112.5, 98], INK_H = 197;
function page(scale, stats, req, desc, descSize) {
  const ww = BOX[2] * scale, hh = BOX[3] * scale, left = BOX[0] + BOX[2] / 2 - ww / 2, top = BOX[1] + 6 * (1 - scale);
  const ix = left + ICON[0] * scale, iy = top + ICON[1] * scale, ty = top + INK_H * scale + 8;
  return `<div class="art"><div class="bg"></div>
  <div class="c cz" style="left:858px;top:184px;font-size:12.5px;color:#423021">ARMAS · TÉCNICA</div>
  <div class="c czb" style="left:860px;top:207px;font-size:24px;letter-spacing:.3em;color:#291c14">SUBJUGAR</div>
  <div class="c cz" style="left:868px;top:226px;font-size:11px;color:#423021">GRAU 1</div>
  <div style="position:absolute;left:${left}px;top:${top}px;width:${ww}px;height:${hh}px;background:url(diagram-alpha.png) 0 0/${256 * scale}px ${256 * scale}px"></div>
  <div class="c" style="left:${ix}px;top:${iy}px;width:${160 * scale}px;height:${160 * scale}px;border-radius:50%;background:radial-gradient(circle,rgba(255,199,92,.6),rgba(255,199,92,0) 65%)"></div>
  <div class="c" style="left:${ix}px;top:${iy}px;width:${62 * scale}px;height:${62 * scale}px;border-radius:50%;background:radial-gradient(circle at 40% 35%,#cfe3f5,#3a5a8a 60%,#0d1a2c);box-shadow:0 0 0 ${2 * scale}px #291c14"></div>
  <div class="t" style="top:${ty}px">
    <div class="st">${stats}</div>
    ${req ? `<div class="rq">${req}</div>` : ""}
    <div class="ds" style="font-size:${descSize}px">${desc}</div>
  </div></div>`;
}
const longDesc = "Subjuga instantaneamente o inimigo, causando dano da arma mais 5. Só pode ser usado após o alvo se esquivar. Subjugar não pode ser bloqueado, esquivado nem aparado. Gera uma pequena quantidade de ameaça adicional e reduz a velocidade de movimento do alvo por 3 s.";
const html = `<!doctype html><html><head><meta charset="utf-8">
<link href="https://fonts.googleapis.com/css2?family=Cinzel:wght@400;700&family=IM+Fell+English&display=swap" rel="stylesheet">
<style>*{margin:0;padding:0}body{display:flex;gap:8px;background:#000;width:${2 * 380 + 8}px;height:440px;overflow:hidden}
.art{position:relative;width:380px;height:440px;overflow:hidden}
.art>*{transform-origin:0 0}
.bg{position:absolute;left:-690px;top:-160px;width:1376px;height:768px;background:url(bg.png)}
.art>div:not(.bg){margin-left:-690px;margin-top:-160px}
.c{position:absolute;transform:translate(-50%,-50%);white-space:nowrap}
.cz{font-family:Cinzel}.czb{font-family:Cinzel;font-weight:700}
.t{position:absolute;left:884px;transform:translateX(-50%);width:330px;text-align:center}
.st{font:15px "IM Fell English",serif;color:#423021;line-height:17px;margin-bottom:6px}
.rq{font:12.5px "Segoe UI";color:#7a2418;margin-bottom:6px}
.ds{font-family:"Segoe UI";font-weight:600;color:#291c14;line-height:1.2;width:310px;margin:0 auto}
</style></head><body>
${page(1, "15 de Raiva &nbsp;·&nbsp; Alcance corpo a corpo &nbsp;·&nbsp; Instantâneo", "", "Fende a armadura do alvo, reduzindo-a em 90 a cada aplicação. Acumula até 5 vezes.", 13)}
${page(0.62, "5 de Raiva &nbsp;·&nbsp; Alcance de ataques corpo a corpo &nbsp;·&nbsp; Instantâneo &nbsp;·&nbsp; Recarga de 5 s", "Requer Postura de Batalha", longDesc, 13)}
</body></html>`;
fs.writeFileSync("preview/right-fit.html", html);
console.log("ok");
