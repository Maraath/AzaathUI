// Atualiza a réplica (compare.html) com a Mesa de Runas no estilo do livro e
// gera os PNGs de prévia que ela usa (tab.png). Uso: node compare-mesa.js
const fs = require("fs");
const I = require("../sheet-concept/img");

const b = fs.readFileSync("../../AzaathUI/Media/Grimoire/GrimTab.tga");
const w = b.readUInt16LE(12), h = b.readUInt16LE(14), im = I.create(106, 54);
for (let y = 0; y < 54; y++) for (let x = 0; x < 106; x++) {
  const s = 18 + ((h - 1 - y) * w + x) * 4, o = (y * 106 + x) * 4;
  im.px[o] = b[s + 2]; im.px[o + 1] = b[s + 1]; im.px[o + 2] = b[s]; im.px[o + 3] = 255;
}
I.writePNG("preview/tab.png", im);

const MESA = String.raw`// mesa (estilo do livro)
D.insertAdjacentHTML('beforeend','<div style="position:absolute;left:1040px;top:574px;width:320px;height:174px;background:url(preview/mesa.png) 0 0/320px 174px"></div>');
T(1200,594,'MESA DE RUNAS','cz',11.5,'rgb(41,28,20)');
S.insertAdjacentHTML('beforeend','<line x1="1100" y1="594" x2="1136" y2="594"/><line x1="1264" y1="594" x2="1300" y2="594"/>');
[[1093,'BARRA 1',1],[1161,'BARRA 2'],[1229,'BARRA 3'],[1297,'LATERAL']].forEach(([x,t,on])=>{
  D.insertAdjacentHTML('beforeend','<div class="c" style="left:'+x+'px;top:616px;width:66px;height:26px;background:url(preview/tab.png) 0 0/66px 26px;filter:brightness('+(on?1:.62)+')'+(on?';box-shadow:0 0 14px rgba(255,199,92,.55)':'')+'"></div>');
  T(x+6,616,t,'cz',9,on?'rgb(255,235,189)':'rgb(150,140,125)','font-weight:400;text-shadow:1px 1px 1px #000');
});
const ic=[[1067,637],[1113,637],[1159,637],[1205,637],[1251,637],[1297,637],[1067,692],[1113,692]];
[1080,1128,1176,1224,1272,1320].forEach((x,c)=>[657,709].forEach((y,r)=>{
  const k=r*6+c, src=ic[k];
  const inner = src
    ? '<div class="ic" style="left:9px;top:9px;width:28px;height:28px;background-position:'+(-(src[0]+6))+'px '+(-(src[1]+6))+'px"></div>'
    : '<div style="position:absolute;left:18px;top:22px;width:10px;height:2px;background:rgba(219,189,133,.55)"></div><div style="position:absolute;left:22px;top:18px;width:2px;height:10px;background:rgba(219,189,133,.55)"></div>';
  D.insertAdjacentHTML('beforeend','<div class="medal" style="left:'+x+'px;top:'+y+'px;width:46px;height:46px"><div style="position:absolute;left:8px;top:8px;width:30px;height:30px;border-radius:50%;background:#2b1f14"></div>'+inner+'<div class="rg" style="background-size:46px 46px"></div><div style="position:absolute;right:-1px;bottom:0;width:15px;height:15px;border-radius:50%;background:#dbc499;border:1px solid #735229;font:600 8.5px Segoe UI;color:#291c14;text-align:center;line-height:14px">'+(k+1)+'</div></div>');
}));
`;
let s = fs.readFileSync("compare.html", "utf8");
const a = s.indexOf("// mesa"), e = s.indexOf("T(617,727");
s = s.slice(0, a) + MESA + s.slice(e);
fs.writeFileSync("compare.html", s);
console.log("ok");
