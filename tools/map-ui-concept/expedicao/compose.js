// Prévia do mapa montado como no jogo: terreno (a própria arte), mar novo, nomes, moldura, título e botões.
// node compose.js [NOME DO LUGAR] -> out/compose.png
"use strict";
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const DIR = __dirname, OUT = path.join(DIR, "out"), ROOT = path.resolve(DIR, "../../..");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const T = JSON.parse(fs.readFileSync(path.join(OUT, "fit.json"), "utf8"));
const u = (f) => "file:///" + f.replace(/\\/g, "/");
const title = process.argv[2] || "AZEROTH";
const icons = ["ExpBtnQuests", "ExpBtnLore", "ExpBtnGather", "ExpBtnFilter", "ExpBtnSettings", "ExpBtnCenter", "ExpBtnMax", "ExpBtnClose"]
  .map((n) => n + ".png").filter((f) => fs.existsSync(path.join(OUT, "icons", f)));
// exemplos no mapa: [ícone, x, y, largura, altura, ponta embaixo?] (tamanho do jogo x 1.6)
const pins = [["ExpPlayerArrow", 1352, 742, 61, 61], ["ExpPinQuest", 1395, 690, 37, 54, 1], ["ExpPinTurnIn", 1318, 640, 30, 45],
  ["ExpPinNew", 1440, 770, 16, 48], ["ExpPinRepeat", 1295, 800, 16, 48]];

const html = `<!doctype html><html><head><meta charset="utf-8"><style>
@font-face{font-family:Cz;src:url('${u(path.join(ROOT, "AzaathUI/Media/Fonts/Cinzel-Bold.ttf"))}')}
html,body{margin:0;background:#000}</style></head><body><canvas id="c" width="2000" height="1116"></canvas>
<script>
const L=(s)=>new Promise(r=>{const i=new Image();i.onload=()=>r(i);i.onerror=()=>r(null);i.src=s;});
(async()=>{
 await document.fonts.load('52px Cz');
 const [con,sl,sr,ll,lr,ch,fl,slot]=await Promise.all([${["concept.png", "out/sea_L.png", "out/sea_R.png", "out/labels.png", "out/labels.png", "out/chrome_notitle.png", "out/flag_full.png", "out/slot.png"].map((f) => "L('" + u(path.join(DIR, f)) + "')").join(",")}]);
 const icons=await Promise.all(${JSON.stringify(icons.map((f) => u(path.join(OUT, "icons", f))))}.map(L));
 const pins=${JSON.stringify(pins)};
 const pinImg=await Promise.all(pins.map(p=>L(${JSON.stringify(u(path.join(OUT, "icons")) + "/")}+p[0]+'.png')));
 const c=document.getElementById('c'),x=c.getContext('2d');
 x.drawImage(con,0,0);
 x.save();x.beginPath();x.rect(76,65,1848,983);x.clip();
 x.setTransform(${T.ax},0,0,${T.ay},${T.bx},${T.by});
 x.drawImage(sl,0,0);x.drawImage(sr,sl.width,0);x.drawImage(ll,0,0);
 x.restore();
 pins.forEach((p,i)=>{const im=pinImg[i];if(!im)return;const [,px,py,pw,ph,tip]=p;
  if(i===0){x.save();x.translate(px,py);x.rotate(0.6);x.drawImage(im,-pw/2,-ph/2,pw,ph);x.restore();}
  else x.drawImage(im,px-pw/2,tip?py-ph:py-ph/2,pw,ph);});
 x.drawImage(ch,0,0);x.drawImage(fl,0,0);
 // título no estandarte
 let size=52;x.font=size+'px Cz';x.letterSpacing='3px';
 const t=${JSON.stringify(title.toUpperCase())};
 while(x.measureText(t).width>330&&size>22){size-=1;x.font=size+'px Cz';}
 x.textAlign='center';x.textBaseline='middle';
 x.fillStyle='rgba(0,0,0,.75)';x.fillText(t,1002,96);
 x.strokeStyle='rgba(40,28,16,.9)';x.lineWidth=3;x.strokeText(t,1000,93);
 const g=x.createLinearGradient(0,70,0,118);g.addColorStop(0,'#efe1c0');g.addColorStop(1,'#bfa77c');
 x.fillStyle=g;x.fillText(t,1000,93);
 // botões só com o ícone (mesmas medidas do MapChrome.lua): 6 no estandarte, 2 no alto à direita
 for(let i=0;i<8;i++){
  if(!icons[i])continue;
  let cx,cy,s;
  if(i<6){cx=198;cy=198+i*60;s=60;}else{cx=1756-(7-i)*56;cy=31;s=52;}
  x.drawImage(icons[i],cx-s/2,cy-s/2,s,s);
 }
 document.title='ok';
})();
</script></body></html>`;
const work = fs.mkdtempSync(path.join(os.tmpdir(), "azaath_cmp_"));
const hf = path.join(work, "c.html"), pf = path.join(OUT, "compose.png");
fs.writeFileSync(hf, html, "utf8");
if (fs.existsSync(pf)) fs.unlinkSync(pf);
spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--user-data-dir=" + path.join(work, "p"), "--no-first-run", "--hide-scrollbars",
  "--force-device-scale-factor=1", "--window-size=2000,1116", "--virtual-time-budget=6000", "--allow-file-access-from-files",
  "--screenshot=" + pf, u(hf)], { timeout: 120000 });
console.log(fs.existsSync(pf) ? "ok -> " + pf : "falhou");
