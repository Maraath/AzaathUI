const path=require("path");const {readPNG}=require("../grimoire-concept/png");
const s=readPNG(path.join(__dirname,"concept.png"));
const L=(x,y)=>{const o=(y*s.w+x)*4;return 0.3*s.px[o]+0.59*s.px[o+1]+0.11*s.px[o+2];};
let out=[];for(let x=330;x<960;x+=10){let best=0,by=0;for(let y=46;y<55;y++){const d=L(x,y)-Math.min(L(x,42),L(x,58));if(d>best){best=d;by=y;}}out.push(x+":"+Math.round(best)+"@"+by);}console.log(out.join(" "));
// chevron detail 490-506, 56-66
for(let y=55;y<67;y++){let r="";for(let x=488;x<=508;x++)r+=String(Math.round(L(x,y)/26)).padStart(2);console.log(y,r);}
