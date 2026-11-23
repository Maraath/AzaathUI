const path=require("path");const {readPNG}=require("../grimoire-concept/png");
const s=readPNG(path.join(__dirname,"concept.png"));
const P=(x,y)=>{const o=(y*s.w+x)*4;return [s.px[o],s.px[o+1],s.px[o+2]];};
const lum=c=>0.3*c[0]+0.59*c[1]+0.11*c[2];
function brightest(x0,x1,y0,y1){let b=[0,0,0];for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){const c=P(x,y);if(lum(c)>lum(b))b=c;}return b.map(Math.round);}
console.log("active",brightest(467,528,26,42),"inactive",brightest(545,615,26,42),brightest(380,452,26,42));
// text vertical extent
for(const [n,x0,x1] of [["TAL",467,528],["REP",545,615]]){let rows=[];for(let y=20;y<46;y++){let m=0;for(let x=x0;x<=x1;x++)m=Math.max(m,lum(P(x,y)));rows.push(y+":"+Math.round(m));}console.log(n,rows.join(" "));}
// tab x extents at y 34 row
let row="";for(let x=300;x<930;x++){let m=0;for(let y=27;y<42;y++)m=Math.max(m,lum(P(x,y)));row+=m>90?"#":".";}console.log(row);
// horizontal flare profile y=50 & vertical
let h=[];for(let dx=-140;dx<=140;dx+=4)h.push(dx+":"+Math.round(lum(P(498+dx,50))-15));console.log(h.join(" "));
for(const dx of [0,12,24,40]){let v=[];for(let y=42;y<58;y++)v.push(Math.round(lum(P(498+dx,y))-15));console.log("dx"+dx,v.join(","));}
