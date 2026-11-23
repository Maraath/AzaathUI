const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const OUT = "C:/Users/Novo Usuario/.gemini/antigravity/brain/e07e647f-89c4-4312-b74a-8cc81619678e";
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const imgs = {
  obs: ["azoth_obsidian_ui_frames_dark_bg_1795029146254.jpg", "white"],
  pla: ["azoth_ui_sprite_sheet_final_1795029132142.jpg", "black"],
};

const data = {};
for (const [k, [fn, bg]] of Object.entries(imgs)) {
  data[k] = { src: "data:image/jpeg;base64," + fs.readFileSync(path.join(OUT, fn)).toString("base64"), bg };
}

const html = `<!doctype html><html><body><script>
const DATA = ${JSON.stringify(data)};
function load(s){return new Promise(r=>{const i=new Image();i.onload=()=>r(i);i.src=s;});}
(async()=>{
  const out={};
  for(const [k,info] of Object.entries(DATA)){
    const im=await load(info.src);
    const cv=document.createElement("canvas"); cv.width=im.width; cv.height=im.height;
    const cx=cv.getContext("2d"); cx.drawImage(im,0,0);
    const d=cx.getImageData(0,0,im.width,im.height).data;
    const W=im.width, H=im.height;
    const isBg=(x,y)=>{
      const i=(y*W+x)*4;
      return info.bg==="white" ? (Math.min(d[i],d[i+1],d[i+2])>230) : (Math.max(d[i],d[i+1],d[i+2])<24);
    };
    const box=(x0,y0,x1,y1)=>{
      let minX=x1,minY=y1,maxX=x0,maxY=y0;
      for(let y=y0;y<y1;y++)for(let x=x0;x<x1;x++){
        if(!isBg(x,y)){ if(x<minX)minX=x; if(x>maxX)maxX=x; if(y<minY)minY=y; if(y>maxY)maxY=y; }
      }
      return {x:minX,y:minY,w:maxX-minX+1,h:maxY-minY+1};
    };
    const codex = box(0,0,Math.floor(W*0.50),H);
    const wide  = box(Math.floor(W*0.49),0,W,Math.floor(H*0.35));
    const sq    = box(Math.floor(W*0.49),Math.floor(H*0.33),W,Math.floor(H*0.67));
    const panel = box(Math.floor(W*0.49),Math.floor(H*0.65),W,H);
    out[k]={W,H,codex,wide,sq,panel};
  }
  const p=document.createElement("pre"); p.id="p"; p.textContent=JSON.stringify(out); document.body.appendChild(p);
})();
</script></body></html>`;

const tmp = path.join(__dirname, "_probe_new.html");
fs.writeFileSync(tmp, html);
const res = spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--allow-file-access-from-files", "--virtual-time-budget=15000", "--dump-dom", "file:///" + tmp.replace(/\\/g, "/")], { encoding: "utf8", maxBuffer: 1 << 26 });
fs.unlinkSync(tmp);
const m = res.stdout.match(/<pre id="p">([\s\S]*?)<\/pre>/);
console.log(m ? m[1] : "NO_PRE: " + res.stdout.slice(-300));
