const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const SRC_JPG = "C:/Users/Novo Usuario/.gemini/antigravity/brain/e07e647f-89c4-4312-b74a-8cc81619678e/azoth_ui_sprite_sheet_1795024599352.jpg";
const OUT_SHEET_DIR = "D:/ProjectAzaath/AzaathUI/Media/Sheet";
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";

const b64 = fs.readFileSync(SRC_JPG).toString("base64");
const html = `<!doctype html><html><body><script>
const SRC = "data:image/jpeg;base64,${b64}";
function load(s){ return new Promise((ok,no)=>{ const i=new Image(); i.onload=()=>ok(i); i.onerror=no; i.src=s; }); }
function makeCleanPiece(srcImg, box, pad){
  const sx = Math.max(0, box.x - pad), sy = Math.max(0, box.y - pad);
  const sw = Math.min(srcImg.width - sx, box.w + pad * 2);
  const sh = Math.min(srcImg.height - sy, box.h + pad * 2);
  const cv = document.createElement("canvas"); cv.width = sw; cv.height = sh;
  const cx = cv.getContext("2d"); cx.drawImage(srcImg, sx, sy, sw, sh, 0, 0, sw, sh);
  const id = cx.getImageData(0, 0, sw, sh); const d = id.data;
  const vis = new Uint8Array(sw * sh); const stack = [];
  for(let x=0;x<sw;x++){ stack.push(x); stack.push((sh-1)*sw+x); }
  for(let y=0;y<sh;y++){ stack.push(y*sw); stack.push(y*sw+(sw-1)); }
  const isBg = (i)=>{ const o=i*4; return Math.max(d[o],d[o+1],d[o+2]) < 28; };
  while(stack.length){
    const p=stack.pop(); if(vis[p]||!isBg(p)) continue; vis[p]=1; d[p*4+3]=0;
    const x=p%sw, y=(p/sw)|0;
    if(x>0)stack.push(p-1); if(x<sw-1)stack.push(p+1);
    if(y>0)stack.push(p-sw); if(y<sh-1)stack.push(p+sw);
  }
  for(let y=1;y<sh-1;y++)for(let x=1;x<sw-1;x++){
    const p=y*sw+x; if(vis[p]) continue;
    if(vis[p-1]||vis[p+1]||vis[p-sw]||vis[p+sw]){
      const lum=Math.max(d[p*4],d[p*4+1],d[p*4+2]);
      if(lum<72) d[p*4+3]=Math.round(d[p*4+3]*Math.max(0.25,lum/72));
    }
  }
  cx.putImageData(id,0,0);
  return { cv, pad, w: sw, h: sh };
}
(async()=>{
  const img = await load(SRC);

  // 1. DropCodexOuro (512 x 1024)
  const codexP = makeCleanPiece(img, { x: 128, y: 22, w: 373, h: 791 }, 6);
  const codexCv = document.createElement("canvas"); codexCv.width = 512; codexCv.height = 1024;
  const cg = codexCv.getContext("2d");
  cg.imageSmoothingQuality = "high";
  // Top crown + bronze plaque: srcY 0..238 -> dstY 0..324
  cg.drawImage(codexP.cv, 6, 0, 373, 238, 0, 0, 512, 324);
  // Clean middle pillars: srcY 238..616 (378px) -> dstY 324..843 (519px)
  cg.drawImage(codexP.cv, 6, 238, 373, 378, 0, 324, 512, 519);
  // Closed bottom rim: srcY 762..797 (35px) -> dstY 976..1024 (48px)
  cg.drawImage(codexP.cv, 6, 762, 373, 35, 0, 976, 512, 48);

  // 2. DropAtlasOuro (1024 x 1024)
  const atlasCv = document.createElement("canvas"); atlasCv.width = 1024; atlasCv.height = 1024;
  const ag = atlasCv.getContext("2d");
  ag.imageSmoothingQuality = "high";
  const panelP = makeCleanPiece(img, { x: 628, y: 588, w: 595, h: 205 }, 4);
  const wideP  = makeCleanPiece(img, { x: 628, y: 40,  w: 595, h: 233 }, 4);
  const sqP    = makeCleanPiece(img, { x: 800, y: 302, w: 251, h: 251 }, 4);
  const btnP   = makeCleanPiece(img, { x: 162, y: 694, w: 305, h: 87  }, 4);
  // Placed at exact padded offsets: box(x=10,y=10) -> image drawn at x-4, y-4
  ag.drawImage(panelP.cv, 6, 6);
  ag.drawImage(wideP.cv,  6, 231);
  ag.drawImage(sqP.cv,    6, 486);
  ag.drawImage(btnP.cv,   281, 486);

  const packB64 = (cv) => {
    const raw = cv.getContext("2d").getImageData(0, 0, cv.width, cv.height).data;
    const u8 = new Uint8Array(raw.buffer);
    let bin = "";
    const CHUNK = 0x8000;
    for(let i=0;i<u8.length;i+=CHUNK) bin += String.fromCharCode.apply(null, u8.subarray(i, i+CHUNK));
    return { w: cv.width, h: cv.height, rgbaB64: btoa(bin), png: cv.toDataURL("image/png") };
  };

  const pre = document.createElement("pre");
  pre.id = "out";
  pre.textContent = JSON.stringify({ codex: packB64(codexCv), atlas: packB64(atlasCv) });
  document.body.appendChild(pre);
})();
</script></body></html>`;

const tmpHtml = path.join(__dirname, "_export_tga.html");
fs.writeFileSync(tmpHtml, html, "utf8");
const res = spawnSync(
  EDGE,
  ["--headless=new", "--disable-gpu", "--allow-file-access-from-files", "--virtual-time-budget=30000", "--dump-dom", "file:///" + tmpHtml.replace(/\\/g, "/")],
  { encoding: "utf8", maxBuffer: 1 << 28 }
);
fs.unlinkSync(tmpHtml);

if (res.error) throw res.error;
if (res.status !== 0) throw new Error(`Edge failed: ${res.status} ${res.stderr}`);
const m = res.stdout.match(/<pre[^>]*id="out"[^>]*>([\s\S]*?)<\/pre>/i);
if (!m) throw new Error("No <pre id=\"out\"> found");

const payload = JSON.parse(m[1].trim());

function writeBottomUpTGA(outPath, w, h, rgbaBuf) {
  const header = Buffer.alloc(18, 0);
  header[2] = 2; // Uncompressed RGBA
  header.writeUInt16LE(w, 12);
  header.writeUInt16LE(h, 14);
  header[16] = 32; // 32bpp
  header[17] = 0x08; // bottom-up, 8 alpha bits (matches CraftFrames.tga)

  const pixels = Buffer.allocUnsafe(w * h * 4);
  for (let y = 0; y < h; y++) {
    const srcRow = (h - 1 - y) * w * 4;
    const dstRow = y * w * 4;
    for (let x = 0; x < w; x++) {
      const s = srcRow + x * 4;
      const d = dstRow + x * 4;
      pixels[d]     = rgbaBuf[s + 2]; // B
      pixels[d + 1] = rgbaBuf[s + 1]; // G
      pixels[d + 2] = rgbaBuf[s];     // R
      pixels[d + 3] = rgbaBuf[s + 3]; // A
    }
  }
  fs.writeFileSync(outPath, Buffer.concat([header, pixels]));
  console.log(`Wrote ${outPath} (${w}x${h}, ${Math.round((18 + pixels.length) / 1024)} KB)`);
}

writeBottomUpTGA(
  path.join(OUT_SHEET_DIR, "DropCodexOuro.tga"),
  payload.codex.w,
  payload.codex.h,
  Buffer.from(payload.codex.rgbaB64, "base64")
);
writeBottomUpTGA(
  path.join(OUT_SHEET_DIR, "DropAtlasOuro.tga"),
  payload.atlas.w,
  payload.atlas.h,
  Buffer.from(payload.atlas.rgbaB64, "base64")
);
