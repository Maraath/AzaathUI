const path=require("path");const {readPNG}=require("../grimoire-concept/png");
const s=readPNG(path.join(__dirname,"concept.png"));
const P=(x,y)=>{const o=(y*s.w+x)*4;return [s.px[o],s.px[o+1],s.px[o+2]];};
const lum=c=>0.3*c[0]+0.59*c[1]+0.11*c[2];
const CX=498,CY=50,pts=[];
for(let y=43;y<=57;y++)for(let x=370;x<=630;x+=2){if(Math.abs(x-CX)<40&&y<44)continue;pts.push([x-CX,y-CY,lum(P(x,y))-lum(P(x,72))]);}
const base=dx=>45*Math.max(0,1-0) ; // linha
function model(p,dx,dy){const [A1,a,b,A2,c,d,A3,e,f]=p;
 let v=A1*Math.exp(-(dx*dx/(2*a*a)+dy*dy/(2*b*b)))+A2*Math.exp(-dx*dx/(2*c*c))*Math.exp(-dy*dy/(2*d*d))+A3*Math.exp(-(dx*dx/(2*e*e)+dy*dy/(2*f*f)));
 v+= (Math.abs(dy)<0.5?40:0); return Math.min(240,v);}
const err=p=>pts.reduce((s,[dx,dy,v])=>s+(model(p,dx,dy)-v)**2,0);
let p=[250,10,4.5,170,50,1.3,60,25,6],e=err(p);
for(let it=0;it<60000;it++){const q=p.map(v=>v*(1+(Math.random()-0.5)*0.1));if(q.some(v=>v<=0.3))continue;const eq=err(q);if(eq<e){p=q;e=eq;}}
console.log(p.map(v=>+v.toFixed(2)).join(","),Math.sqrt(e/pts.length).toFixed(1));
