const path=require("path");const I=require("../sheet-concept/img");const {readPNG}=require("../grimoire-concept/png");
const [,,file,x,y,w,h,s,out]=process.argv;const src=readPNG(path.join(__dirname,file));
console.log(src.w,src.h);const c=I.crop(src,+x,+y,+w,+h);
const z=I.create(c.w*s,c.h*s);for(let j=0;j<z.h;j++)for(let i=0;i<z.w;i++){const a=(j*z.w+i)*4,b=((j/s|0)*c.w+(i/s|0))*4;for(let k=0;k<4;k++)z.px[a+k]=c.px[b+k];}
I.writePNG(path.join(__dirname,"preview",out),z);
