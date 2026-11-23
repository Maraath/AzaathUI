const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const SRC_JPG = "C:/Users/Novo Usuario/.gemini/antigravity/brain/e07e647f-89c4-4312-b74a-8cc81619678e/azoth_category_icons_3x3_1795045504781.jpg";
const OUT_TGA = "D:/ProjectAzaath/AzaathUI/Media/Sheet/DropCategoryIcons.tga";
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";

const b64 = fs.readFileSync(SRC_JPG).toString("base64");
const html = `<!doctype html><html><body><script>
const SRC = "data:image/jpeg;base64,${b64}";
function load(s){ return new Promise((ok,no)=>{ const i=new Image(); i.onload=()=>ok(i); i.onerror=no; i.src=s; }); }
function extractCell(img, col, row){
  const cw = Math.floor(img.width / 3), ch = Math.floor(img.height / 3);
  const cv = document.createElement("canvas"); cv.width = cw; cv.height = ch;
  const cx = cv.getContext("2d");
  cx.drawImage(img, col * cw, row * ch, cw, ch, 0, 0, cw, ch);
  const id = cx.getImageData(0, 0, cw, ch); const d = id.data;
  const vis = new Uint8Array(cw * ch); const stack = [];
  for(let x=0;x<cw;x++){ stack.push(x); stack.push((ch-1)*cw+x); }
  for(let y=0;y<ch;y++){ stack.push(y*cw); stack.push(y*cw+(cw-1)); }
  const isBg = (i)=>{ const o=i*4; return Math.max(d[o],d[o+1],d[o+2]) < 24; };
  while(stack.length){
    const p=stack.pop(); if(vis[p]||!isBg(p)) continue; vis[p]=1; d[p*4+3]=0;
    const x=p%cw, y=(p/cw)|0;
    if(x>0)stack.push(p-1); if(x<cw-1)stack.push(p+1);
    if(y>0)stack.push(p-cw); if(y<ch-1)stack.push(p+cw);
  }
  // 1px soft anti-alias edge
  for(let y=1;y<ch-1;y++)for(let x=1;x<cw-1;x++){
    const p=y*cw+x; if(vis[p]) continue;
    if(vis[p-1]||vis[p+1]||vis[p-cw]||vis[p+cw]){
      const lum=Math.max(d[p*4],d[p*4+1],d[p*4+2]);
      if(lum<64) d[p*4+3]=Math.round(d[p*4+3]*Math.max(0.25,lum/64));
    }
  }
  cx.putImageData(id, 0, 0);

  // Tight bounding box of non-transparent pixels
  let minX=cw, minY=ch, maxX=0, maxY=0;
  for(let y=0;y<ch;y++)for(let x=0;x<cw;x++){
    if(d[(y*cw+x)*4+3] > 20){
      if(x<minX)minX=x; if(x>maxX)maxX=x;
      if(y<minY)minY=y; if(y>maxY)maxY=y;
    }
  }
  return { cv, minX, minY, bw: Math.max(1, maxX-minX+1), bh: Math.max(1, maxY-minY+1) };
}
(async()=>{
  const img = await load(SRC);
  const out = document.createElement("canvas"); out.width = 512; out.height = 512;
  const g = out.getContext("2d");
  g.imageSmoothingQuality = "high";

  // Pack 9 icons into 4x4 grid of 128x128 cells (indices 0..8 -> col=i%4, row=floor(i/4))
  for(let i=0;i<9;i++){
    const srcCol = i % 3, srcRow = Math.floor(i / 3);
    const cell = extractCell(img, srcCol, srcRow);
    const dstCol = i % 4, dstRow = Math.floor(i / 4);
    const pad = 6, maxDim = 128 - pad * 2;
    const sc = Math.min(maxDim / cell.bw, maxDim / cell.bh);
    const dw = cell.bw * sc, dh = cell.bh * sc;
    const dx = dstCol * 128 + (128 - dw) / 2;
    const dy = dstRow * 128 + (128 - dh) / 2;
    g.drawImage(cell.cv, cell.minX, cell.minY, cell.bw, cell.bh, dx, dy, dw, dh);
  }

  const raw = g.getImageData(0, 0, 512, 512).data;
  const u8 = new Uint8Array(raw.buffer);
  let bin = "";
  const CHUNK = 0x8000;
  for(let i=0;i<u8.length;i+=CHUNK) bin += String.fromCharCode.apply(null, u8.subarray(i, i+CHUNK));
  const pre = document.createElement("pre");
  pre.id = "out";
  pre.textContent = btoa(bin);
  document.body.appendChild(pre);
})();
</script></body></html>`;

const tmpHtml = path.join(__dirname, "_export_icons.html");
fs.writeFileSync(tmpHtml, html, "utf8");
const res = spawnSync(
  EDGE,
  ["--headless=new", "--disable-gpu", "--allow-file-access-from-files", "--virtual-time-budget=30000", "--dump-dom", "file:///" + tmpHtml.replace(/\\/g, "/")],
  { encoding: "utf8", maxBuffer: 1 << 26 }
);
fs.unlinkSync(tmpHtml);

if (res.error) throw res.error;
if (res.status !== 0) throw new Error(`Edge failed: ${res.status}`);
const m = res.stdout.match(/<pre[^>]*id="out"[^>]*>([\s\S]*?)<\/pre>/i);
if (!m) throw new Error("No <pre id=\"out\"> found");

const rgba = Buffer.from(m[1].trim(), "base64");
const w = 512, h = 512;
const header = Buffer.alloc(18, 0);
header[2] = 2;
header.writeUInt16LE(w, 12);
header.writeUInt16LE(h, 14);
header[16] = 32;
header[17] = 0x08; // bottom-up, 8 alpha bits

const pixels = Buffer.allocUnsafe(w * h * 4);
for (let y = 0; y < h; y++) {
  const srcRow = (h - 1 - y) * w * 4;
  const dstRow = y * w * 4;
  for (let x = 0; x < w; x++) {
    const s = srcRow + x * 4;
    const d = dstRow + x * 4;
    pixels[d]     = rgba[s + 2];
    pixels[d + 1] = rgba[s + 1];
    pixels[d + 2] = rgba[s];
    pixels[d + 3] = rgba[s + 3];
  }
}
fs.writeFileSync(OUT_TGA, Buffer.concat([header, pixels]));
console.log(`Wrote ${OUT_TGA} (512x512, ${Math.round((18 + pixels.length) / 1024)} KB)`);
