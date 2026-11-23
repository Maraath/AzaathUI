const {readPNG}=require("../grimoire-concept/png");const s=readPNG(__dirname+"/concept.png");
const P=(x,y)=>{const o=(y*s.w+x)*4;return [s.px[o],s.px[o+1],s.px[o+2]].map(Math.round).join(",")};
const [mode,a,b,c]=process.argv.slice(2);
if(mode==="v"){for(let y=+b;y<=+c;y++)console.log(y,P(+a,y));}
else{for(let x=+b;x<=+c;x++)console.log(x,P(x,+a));}
