// Compõe card + destaques + preenchimentos (prévia, sem texto)
const I=require('./img');const fs=require('fs');
function readTGA(f){const b=fs.readFileSync(f);const w=b.readUInt16LE(12),h=b.readUInt16LE(14);const im=I.create(w,h);
for(let y=0;y<h;y++)for(let x=0;x<w;x++){const s=18+((h-1-y)*w+x)*4,o=(y*w+x)*4;im.px[o]=b[s+2];im.px[o+1]=b[s+1];im.px[o+2]=b[s];im.px[o+3]=b[s+3];}return im;}
const M='../../AzaathUI/Media/Sheet/';const OX=61,OY=62;
const card=I.crop(readTGA(M+'AttrCard.tga'),0,0,646,1254);
const add=(src,sw,sh,x,y)=>{const s=I.crop(src,0,0,sw,sh);for(let j=0;j<sh;j++)for(let i=0;i<sw;i++){const X=x-OX+i,Y=y-OY+j;if(X<0||Y<0||X>=646||Y>=1254)continue;const o=(Y*646+X)*4,q=(j*sw+i)*4;for(let k=0;k<3;k++)card.px[o+k]=Math.min(255,card.px[o+k]+s.px[q+k]);}};
const put=(src,x,y,w,h)=>{const s=I.resize(src,w,h);I.blit(card,s,x-OX,y-OY);};
add(readTGA(M+'AttrTabActive.tga'),639,73,64,66);add(readTGA(M+'AttrPillActive.tga'),220,80,84,696);
// vida 100%: corpo 265 + ponta 8 ; raiva 9%: (264*0.09) ; crit 9.11/40 ; vel
const hb=readTGA(M+'AttrFillHealth.tga'),hc=readTGA(M+'AttrFillHealthCap.tga'),pb=readTGA(M+'AttrFillPower.tga'),pc=readTGA(M+'AttrFillPowerCap.tga'),gb=readTGA(M+'AttrFillGauge.tga'),gc=readTGA(M+'AttrFillGaugeCap.tga');
const part=(body,ratio,x,y,w,h,cap,cw)=>{const pw=Math.max(1,Math.round(w*ratio));const full=I.resize(body,w,h);put(I.crop(full,0,0,pw,h),x,y,pw,h);put(cap,x+pw,y,cw,h);};
part(hb,1,105,199,265,21,hc,8);part(pb,0.12,391,199,264,21,pc,8);part(gb,0.05,110,963,252,16,gc,8);part(gb,0.27,397,963,253,16,gc,8);
I.writePNG('preview/composite.png',card);
