const path=require("path");const {readPNG}=require("../grimoire-concept/png");
const s=readPNG(path.join(__dirname,"concept.png"));
const L=(x,y)=>{const o=(y*s.w+x)*4;return [s.px[o],s.px[o+1],s.px[o+2]].map(v=>Math.round(v));};
// vertical profile through flare
for(let y=38;y<72;y++){let r=[];for(const x of [380,440,470,490,496,498,500,506,530,560,640,760,880,920,940])r.push(L(x,y).join(","));console.log(y,r.join(" | "));}
