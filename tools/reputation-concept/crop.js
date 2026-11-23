// node crop.js x y w h scale out
const I=require("../sheet-concept/img");const {readPNG}=require("../grimoire-concept/png");
const [x,y,w,h,s,out]=process.argv.slice(2);const src=readPNG(__dirname+"/concept.png");
let c=I.crop(src,+x,+y,+w,+h);if(+s!==1)c=I.resize(c,Math.round(w*s),Math.round(h*s));I.writePNG(__dirname+"/insp/"+out+".png",c);
