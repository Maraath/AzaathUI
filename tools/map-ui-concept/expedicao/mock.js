// Montagem conceitual "Expedição": print real do mapa + mar em papel envelhecido,
// moldura de pedra com runas azaath e estandarte gasto. Saída: mock-vN.png
const fs = require("fs");
const os = require("os");
const path = require("path");
const { spawnSync } = require("child_process");

const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const SRC = process.argv[2];
const OUT = process.argv[3] || path.join(__dirname, "mock-v1.png");
const b64 = (f) => fs.readFileSync(f).toString("base64");
const FONTS = path.join(__dirname, "../../../AzaathUI/Media/Fonts");

const page = String.raw`<!doctype html><html><head><meta charset="utf-8"></head><body style="margin:0;background:#000">
<canvas id="c" width="1920" height="1080"></canvas><pre id="out"></pre>
<script>
const W=1920,H=1080,N=W*H;
const c=document.getElementById('c'),x=c.getContext('2d');
function hash(i,j){let h=Math.imul(i|0,374761393)+Math.imul(j|0,668265263)|0;h=Math.imul(h^(h>>>13),1274126177);h^=h>>>16;return (h>>>0)/4294967296;}
function vn(px,py){const xi=Math.floor(px),yi=Math.floor(py),xf=px-xi,yf=py-yi,u=xf*xf*(3-2*xf),v=yf*yf*(3-2*yf);
 const a=hash(xi,yi),b=hash(xi+1,yi),cc=hash(xi,yi+1),d=hash(xi+1,yi+1);return a+(b-a)*u+(cc-a)*v+(a-b-cc+d)*u*v;}
function fbm(px,py,o){let s=0,a=.5,f=1,n=0;for(let k=0;k<o;k++){s+=a*vn(px*f+k*17.3,py*f+k*9.1);n+=a;a*=.5;f*=2;}return s/n;}
const sm=(a,b,t)=>{t=Math.min(1,Math.max(0,(t-a)/(b-a)));return t*t*(3-2*t);};
const cl=(v,a,b)=>v<a?a:v>b?b:v;

// moldura
const FL=74,FR=1876,FT=46,FB=1054;
const inFrame=(px,py)=>px<FL||px>=FR||py<FT||py>=FB;

function integral(src){const I=new Float64Array((W+1)*(H+1));
 for(let y=0;y<H;y++){let row=0;for(let xx=0;xx<W;xx++){row+=src[y*W+xx];I[(y+1)*(W+1)+xx+1]=I[y*(W+1)+xx+1]+row;}}return I;}
function boxSum(I,x0,y0,x1,y1){x0=Math.max(0,x0);y0=Math.max(0,y0);x1=Math.min(W,x1);y1=Math.min(H,y1);
 return I[y1*(W+1)+x1]-I[y0*(W+1)+x1]-I[y1*(W+1)+x0]+I[y0*(W+1)+x0];}

async function main(){
 await new FontFace('CinzelB','url(data:font/ttf;base64,${b64(path.join(FONTS, "Cinzel-Bold.ttf"))})').load().then(f=>document.fonts.add(f));
 await new FontFace('Runic','url(data:font/ttf;base64,${b64("C:/Windows/Fonts/seguihis.ttf")})').load().then(f=>document.fonts.add(f));
 const img=new Image();img.src='data:image/webp;base64,${b64(SRC)}';await img.decode();
 x.drawImage(img,0,0,W,H);
 const id=x.getImageData(0,0,W,H),d=id.data;
 const orig=new Uint8ClampedArray(d);

 // ---------- 1. mar -> papel cartográfico ----------
 const L=new Float32Array(N),blue=new Float32Array(N),bdark=new Float32Array(N),bL=new Float32Array(N);
 for(let i=0;i<N;i++){const r=d[i*4],g=d[i*4+1],b=d[i*4+2];L[i]=(.299*r+.587*g+.114*b)/255;
  if(b>r+22&&b>=g-8){blue[i]=1;if(L[i]<.3){bdark[i]=1;bL[i]=L[i];}}}
 const Ib=integral(blue),Id=integral(bdark),IL=integral(bL);
 const protect=(px,py)=>(px>612&&px<1308&&py>1008&&py<1058);
 for(let py=0;py<H;py++)for(let px=0;px<W;px++){
  if(inFrame(px,py)||protect(px,py))continue;
  const i=py*W+px,r=d[i*4],g=d[i*4+1],b=d[i*4+2];
  const mx=Math.max(r,g,b),mn=Math.min(r,g,b);
  let sea=blue[i]===1;
  if(!sea&&mx-mn<40&&L[i]>.38&&boxSum(Ib,px-8,py-8,px+9,py+9)>0)sea=true;
  if(!sea)continue;
  const cnt=boxSum(Id,px-50,py-50,px+51,py+51);
  const base=cnt>20?boxSum(IL,px-50,py-50,px+51,py+51)/cnt:.2;
  // papel
  const nx=px/W-.5,ny=py/H-.5,e=(nx*nx)/.36+(ny*ny)/.30;
  const vig=sm(.08,1.05,e);
  let pr=146-80*vig,pg=160-76*vig,pb=154-62*vig;
  const m=.86+.3*fbm(px/230,py/230,4);
  const st=sm(.55,.75,fbm(px/380+40,py/380+11,3));
  pr=pr*m;pg=pg*m;pb=pb*m;
  pr+= (128-pr)*st*.35; pg+=(112-pg)*st*.35; pb+=(84-pb)*st*.45;
  const gr=(hash(px,py)-.5)*9+(fbm(px/3,py/3,2)-.5)*10;
  pr+=gr;pg+=gr;pb+=gr;
  // tinta: o que era claro no mar vira traço escuro
  const a=cl((L[i]-base)*1.9,0,.9);
  d[i*4]=pr*(1-a)+30*a; d[i*4+1]=pg*(1-a)+26*a; d[i*4+2]=pb*(1-a)+22*a;
 }
 x.putImageData(id,0,0);

 // sombra interna da moldura sobre o mapa
 const sh=(g)=>{x.fillStyle=g;};
 let g=x.createLinearGradient(FL,0,FL+40,0);g.addColorStop(0,'rgba(8,6,4,.75)');g.addColorStop(1,'rgba(8,6,4,0)');sh(g);x.fillRect(FL,FT,40,FB-FT);
 g=x.createLinearGradient(FR,0,FR-40,0);g.addColorStop(0,'rgba(8,6,4,.75)');g.addColorStop(1,'rgba(8,6,4,0)');sh(g);x.fillRect(FR-40,FT,40,FB-FT);
 g=x.createLinearGradient(0,FT,0,FT+40);g.addColorStop(0,'rgba(8,6,4,.8)');g.addColorStop(1,'rgba(8,6,4,0)');sh(g);x.fillRect(FL,FT,FR-FL,40);
 g=x.createLinearGradient(0,FB,0,FB-36);g.addColorStop(0,'rgba(8,6,4,.75)');g.addColorStop(1,'rgba(8,6,4,0)');sh(g);x.fillRect(FL,FB-36,FR-FL,36);

 // ---------- 2. pedra ----------
 const sid=x.getImageData(0,0,W,H),s=sid.data;
 for(let py=0;py<H;py++)for(let px=0;px<W;px++){
  if(!inFrame(px,py))continue;const i=(py*W+px)*4;
  const n=fbm(px/26,py/26,4),n2=fbm(px/5,py/5,2);
  let v=34+40*n+12*(n2-.5);
  let ly,lx;
  if(px<FL||px>=FR){const off=(px<FL?0:48);ly=(py+off)%104;lx=0;}
  else {lx=(px+((py<FT?0:30)))%150;ly=99;}
  if(ly<2||lx===1||lx===2)v*=.45;else if(ly===2||lx===3)v*=1.3;
  // rachaduras
  const cr=Math.abs(fbm(px/60+3,py/60+7,3)-.5);if(cr<.012)v*=.55;
  s[i]=v;s[i+1]=v*1.02;s[i+2]=v*1.07;s[i+3]=255;
 }
 x.putImageData(sid,0,0);

 // friso de ferro na borda interna
 function ironStrip(x0,y0,w,h){const gg=x.createLinearGradient(x0,y0,w>h?x0:x0+w,w>h?y0+h:y0);
  gg.addColorStop(0,'#5a5e63');gg.addColorStop(.35,'#2a2d31');gg.addColorStop(1,'#141619');x.fillStyle=gg;x.fillRect(x0,y0,w,h);}
 ironStrip(FL-7,FT-7,7,FB-FT+14);ironStrip(FR,FT-7,7,FB-FT+14);ironStrip(FL-7,FT-7,FR-FL+14,7);ironStrip(FL-7,FB,FR-FL+14,7);
 x.strokeStyle='rgba(200,170,110,.35)';x.lineWidth=1;x.strokeRect(FL+.5,FT+.5,FR-FL-1,FB-FT-1);
 function rivet(cx,cy,r){const rg=x.createRadialGradient(cx-r*.35,cy-r*.35,0,cx,cy,r);rg.addColorStop(0,'#9aa0a6');rg.addColorStop(.5,'#45494e');rg.addColorStop(1,'#141518');
  x.fillStyle=rg;x.beginPath();x.arc(cx,cy,r,0,7);x.fill();}
 for(let yy=FT+60;yy<FB-40;yy+=120){rivet(FL-3.5,yy,2.6);rivet(FR+3.5,yy,2.6);}
 for(let xx=FL+80;xx<FR-40;xx+=140){rivet(xx,FT-3.5,2.6);rivet(xx,FB+3.5,2.6);}

 // cantoneiras
 function bracket(cx,cy,sx,sy){x.save();x.translate(cx,cy);x.scale(sx,sy);
  x.beginPath();x.moveTo(-10,-10);x.lineTo(78,-10);x.lineTo(64,8);x.lineTo(8,8);x.lineTo(8,64);x.lineTo(-10,78);x.closePath();
  const gg=x.createLinearGradient(-10,-10,40,40);gg.addColorStop(0,'#6b6f74');gg.addColorStop(.4,'#33363a');gg.addColorStop(1,'#1a1c1f');
  x.fillStyle=gg;x.shadowColor='rgba(0,0,0,.7)';x.shadowBlur=8;x.shadowOffsetY=3;x.fill();x.shadowColor='transparent';
  x.strokeStyle='rgba(160,165,170,.35)';x.lineWidth=1;x.stroke();
  x.restore();rivet(cx,cy,3.4);rivet(cx+sx*44,cy-sy*1,2.6);rivet(cx-sx*1,cy+sy*44,2.6);}
 bracket(FL,FT,1,1);bracket(FR,FT,-1,1);bracket(FL,FB,1,-1);bracket(FR,FB,-1,-1);

 // ---------- 3. runas azaath ----------
 const RUNES='ᚠᚢᚦᚨᚱᚲᚷᚹᚺᚾᛁᛃᛇᛈᛉᛊᛏᛒᛖᛗᛚᛜᛞᛟ';
 function groove(x0,y0,w,h){x.fillStyle='rgba(6,8,10,.75)';x.fillRect(x0,y0,w,h);
  x.strokeStyle='rgba(0,0,0,.9)';x.lineWidth=2;x.strokeRect(x0+1,y0+1,w-2,h-2);
  x.strokeStyle='rgba(120,125,130,.35)';x.lineWidth=1;x.beginPath();x.moveTo(x0,y0+h+.5);x.lineTo(x0+w,y0+h+.5);x.moveTo(x0+w+.5,y0);x.lineTo(x0+w+.5,y0+h);x.stroke();}
 function runeColumn(cx,y0,y1,seed){x.font='22px Runic';x.textAlign='center';x.textBaseline='middle';let k=seed;
  for(let yy=y0;yy<y1;yy+=36){const ch=[...RUNES][k++%24];
   x.fillStyle='rgba(0,0,0,.9)';x.fillText(ch,cx+1,yy+1);
   x.save();x.shadowColor='rgba(95,227,230,.95)';x.shadowBlur=12;x.fillStyle='rgba(95,227,230,.92)';x.fillText(ch,cx,yy);
   x.shadowBlur=4;x.fillStyle='rgba(200,250,252,.55)';x.fillText(ch,cx,yy);x.restore();}}
 groove(FR+12,86,26,FB-86-30);runeColumn(FR+25,104,FB-40,3);
 groove(22,600,28,FB-600-30);runeColumn(36,618,FB-40,11);

 // ícones do trilho esquerdo (do print), em encaixes
 const icons=[160,216,272,328,390,532];
 icons.forEach((iy,n)=>{const cx=36,cy=iy+(iy>500?14:0);
  const rg=x.createRadialGradient(cx,cy,4,cx,cy,22);rg.addColorStop(0,'#0b0f13');rg.addColorStop(.8,'#121619');rg.addColorStop(1,'#3b3f44');
  x.fillStyle=rg;x.beginPath();x.arc(cx,cy,21,0,7);x.fill();
  x.strokeStyle=n===0?'rgba(95,227,230,.8)':'rgba(150,155,160,.45)';x.lineWidth=n===0?1.6:1.2;x.beginPath();x.arc(cx,cy,21,0,7);x.stroke();
  x.save();x.globalCompositeOperation='lighten';x.drawImage(img,16*img.width/W,(iy-20)*img.height/H,40*img.width/W,40*img.height/H,cx-20,cy-20,40,40);x.restore();});

 // busca e botões (do print)
 x.save();x.globalCompositeOperation='lighten';
 x.drawImage(img,1515*img.width/W,4*img.height/H,400*img.width/W,38*img.height/H,1468,6,400,38);x.restore();

 // ---------- 4. estandarte gasto ----------
 const bx0=772,bx1=1148,by0=50,byB=176,notch=30,cx=(bx0+bx1)/2,hw=(bx1-bx0)/2;
 const holes=[[cx-120,150,5],[cx+70,158,3.5],[bx0+30,120,2.5],[cx+132,96,3]];
 const bc=document.createElement('canvas');bc.width=W;bc.height=H;const bx=bc.getContext('2d');
 const bid=bx.createImageData(W,H),bd=bid.data;
 const bottom=(px)=>{const t=Math.abs(px-cx)/hw;let b=byB-notch*(1-t)+(vn(px*.3,3.3)-.5)*9+(hash(px,77)-.5)*4;
  const tr=Math.abs(px-(cx+96));if(tr<9)b-=(9-tr)*2.4;const tr2=Math.abs(px-(bx0+46));if(tr2<6)b-=(6-tr2)*1.8;return b;};
 for(let py=by0;py<byB+10;py++)for(let px=bx0-4;px<bx1+4;px++){
  const fy=py-by0,jag=(vn(py*.4,9)-.5)*2+fy*.012;
  const dl=px-(bx0+jag),dr=(bx1-jag)-px,db=bottom(px)-py;
  if(dl<0||dr<0||db<0)continue;
  let al=1;for(const h of holes){const dd=Math.hypot(px-h[0],py-h[1]);if(dd<h[2]){al=0;break;}}
  const de=Math.min(dl,dr,db);if(de<2.2&&hash(px,py*3)>.55)al=0;
  if(!al)continue;
  const fx=px-bx0;
  const fold=.55*Math.sin(fx*.047+.7)+.3*Math.sin(fx*.113+2.1)+.15*Math.sin(fx*.27+.3);
  let shade=.8+.24*fold*(.5+.5*Math.min(1,fy/70));
  shade*=((px+py)&1?1:.93)*(py%3===0?.94:1);
  shade*=.82+.36*fbm(px/34,py/34,3);
  if(fy<10)shade*=.7+.03*fy;
  let r=34*shade,gg=56*shade,b=94*shade;
  const grime=sm(.45,1,fy/(byB-by0))*.45+sm(.6,.9,fbm(px/50+9,py/50,3))*.3;
  r+=(64-r)*grime;gg+=(52-gg)*grime;b+=(40-b)*grime;
  if(de<5){const k=.55+.09*de;r*=k;gg*=k;b*=k;}
  for(const h of holes){const dd=Math.hypot(px-h[0],py-h[1]);if(dd<h[2]+2.5){r*=.5;gg*=.5;b*=.5;}}
  const trim=(de>9&&de<14)||(fy>12&&fy<17);
  if(trim){const w=fbm(px/7,py/7,2);if(w>.36){const k=.7+.4*shade;r=196*k;gg=156*k;b=80*k;}else{r+=(150-r)*.25;gg+=(120-gg)*.25;b+=(70-b)*.25;}}
  const i=(py*W+px)*4;bd[i]=r;bd[i+1]=gg;bd[i+2]=b;bd[i+3]=255;
 }
 bx.putImageData(bid,0,0);
 // título bordado
 bx.save();bx.globalCompositeOperation='source-atop';
 bx.font='34px CinzelB';bx.letterSpacing='7px';bx.textAlign='center';bx.textBaseline='middle';
 bx.fillStyle='rgba(0,0,0,.75)';bx.fillText('AZEROTH',cx+2,108+2);
 const tg=bx.createLinearGradient(0,92,0,124);tg.addColorStop(0,'#f1d9a0');tg.addColorStop(.5,'#c99a4e');tg.addColorStop(1,'#8a6430');
 bx.fillStyle=tg;bx.fillText('AZEROTH',cx,108);
 bx.strokeStyle='rgba(201,154,78,.8)';bx.lineWidth=1.2;bx.beginPath();bx.moveTo(cx-110,134);bx.lineTo(cx-14,134);bx.moveTo(cx+14,134);bx.lineTo(cx+110,134);bx.stroke();
 bx.fillStyle='#5fe3e6';bx.shadowColor='#5fe3e6';bx.shadowBlur=8;bx.beginPath();bx.moveTo(cx,127);bx.lineTo(cx+7,134);bx.lineTo(cx,141);bx.lineTo(cx-7,134);bx.closePath();bx.fill();
 bx.restore();
 // desgaste sobre o bordado
 const wid=bx.getImageData(bx0,90,bx1-bx0,56),wd=wid.data;
 for(let p=0;p<wd.length;p+=4){const px=bx0+(p/4)%(bx1-bx0),py=90+Math.floor(p/4/(bx1-bx0));
  if(fbm(px/5,py/5,2)<.3){wd[p]*=.8;wd[p+1]*=.8;wd[p+2]*=.85;}}
 bx.putImageData(wid,bx0,90);
 x.save();x.shadowColor='rgba(0,0,0,.7)';x.shadowBlur=14;x.shadowOffsetX=6;x.shadowOffsetY=10;x.drawImage(bc,0,0);x.restore();
 // varão de ferro
 const rg2=x.createLinearGradient(0,40,0,54);rg2.addColorStop(0,'#8d9297');rg2.addColorStop(.4,'#3c4045');rg2.addColorStop(1,'#15171a');
 x.fillStyle=rg2;x.fillRect(bx0-26,42,bx1-bx0+52,10);
 [bx0-30,bx1+30].forEach(fx=>{const fg=x.createRadialGradient(fx-3,44,1,fx,47,10);fg.addColorStop(0,'#b4b8bc');fg.addColorStop(.5,'#4a4e53');fg.addColorStop(1,'#111');
  x.fillStyle=fg;x.beginPath();x.arc(fx,47,9,0,7);x.fill();});
 [bx0+16,cx,bx1-16].forEach(fx=>{x.strokeStyle='#202326';x.lineWidth=4;x.beginPath();x.ellipse(fx,50,6,8,0,0,7);x.stroke();
  x.strokeStyle='rgba(170,175,180,.5)';x.lineWidth=1;x.beginPath();x.ellipse(fx,49,6,8,0,Math.PI,2*Math.PI);x.stroke();});

 document.getElementById('out').textContent=c.toDataURL('image/png');
}
main().catch(e=>{document.getElementById('out').textContent='ERR '+e;});
</script></body></html>`;

const work = fs.mkdtempSync(path.join(os.tmpdir(), "azaath_mock_"));
const html = path.join(work, "mock.html");
fs.writeFileSync(html, page, "utf8");
const r = spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--user-data-dir=" + path.join(work, "p"), "--no-first-run",
  "--virtual-time-budget=60000", "--allow-file-access-from-files", "--dump-dom", "file:///" + html.replace(/\\/g, "/")],
  { maxBuffer: 200 * 1024 * 1024, encoding: "utf8", timeout: 240000 });
const m = /<pre id="out">([^<]*)<\/pre>/.exec(r.stdout || "");
if (!m || !m[1].startsWith("data:image/png")) { console.error("falhou:", r.status, r.error, (r.stdout || "").length, m ? m[1].slice(0, 300) : (r.stderr || "").slice(0, 800), html); process.exit(1); }
fs.writeFileSync(OUT, Buffer.from(m[1].split(",")[1], "base64"));
console.log("ok ->", OUT);
