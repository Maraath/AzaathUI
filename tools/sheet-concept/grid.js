const I=require('./img');const c=I.readBMP('concept.bmp');
const [x,y,w,h,s,name]=process.argv.slice(2).map((v,i)=>i<5?+v:v);
let im=I.resize(I.crop(c,x,y,w,h),w*s,h*s);
for(let j=0;j<im.h;j++)for(let i=0;i<im.w;i++){const X=x+i/s,Y=y+j/s;const o=(j*im.w+i)*4;
 const gx=Math.abs(X-Math.round(X/10)*10)<0.5/s*1.01, gy=Math.abs(Y-Math.round(Y/10)*10)<0.5/s*1.01;
 const major=(gx&&Math.round(X)%50==0)||(gy&&Math.round(Y)%50==0);
 if(gx||gy){const a=major?0.6:0.25;im.px[o]=im.px[o]*(1-a)+255*a;im.px[o+1]*=1-a;im.px[o+2]*=1-a;}}
I.writePNG(name,im);
