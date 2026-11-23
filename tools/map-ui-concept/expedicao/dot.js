// Ponto redondo de borda macia para o caminho mágico: Media/MapFrame/ExpPathDotS.tga (branco; o jogo tinge)
const fs=require("fs"),path=require("path"),I=require("../../sheet-concept/img");
const S=32,img=I.create(S,S),R=S/2;
for(let y=0;y<S;y++)for(let x=0;x<S;x++){
  const d=Math.hypot(x+.5-R,y+.5-R)/R, t=Math.max(0,Math.min(1,(1-d)/0.65)), a=t*t*(3-2*t), i=(y*S+x)*4;
  img.px[i]=255;img.px[i+1]=255;img.px[i+2]=255;img.px[i+3]=a*255;
}
const ROOT=path.resolve(__dirname,"../../..");
for(const d of [path.join(ROOT,"AzaathUI/Media/MapFrame"),"C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/MapFrame"])
  I.writeTGA(path.join(d,"ExpPathDotS.tga"),img);
console.log("ok");
