const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const OUT_DIR = "C:/Users/Novo Usuario/.gemini/antigravity/brain/e07e647f-89c4-4312-b74a-8cc81619678e";
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const BASE_DIR = __dirname;

const ASSET_MAP = {
  obs: [path.join(OUT_DIR, "azoth_obsidian_ui_frames_dark_bg_1795029146254.jpg"), "image/jpeg"],
  pla: [path.join(OUT_DIR, "azoth_ui_sprite_sheet_final_1795029132142.jpg"), "image/jpeg"],
  CraftRings: ["D:/ProjectAzaath/tools/professions-ui-concept/preview/CraftRings.png", "image/png"],
  HallBG: ["D:/ProjectAzaath/tools/professions-concept/bg_1920x1080.png", "image/png"],
  Helmets: [path.join(BASE_DIR, "helmets_grid.jpg"), "image/jpeg"],
};

const assets = {};
for (const [key, [filePath, mime]] of Object.entries(ASSET_MAP)) {
  if (!fs.existsSync(filePath)) {
    throw new Error(`Missing asset ${key}: ${filePath}`);
  }
  const b64 = fs.readFileSync(filePath).toString("base64");
  assets[key] = `data:${mime};base64,${b64}`;
  console.log(`Packed ${key} (${Math.round(b64.length / 1024)} KB b64)`);
}

const assetsJsPath = path.join(BASE_DIR, "assets_new_azaath.js");
fs.writeFileSync(assetsJsPath, `window.ASSETS = ${JSON.stringify(assets)};\n`, "utf8");
console.log(`Wrote ${assetsJsPath}`);

const htmlUrl = "file:///" + path.join(BASE_DIR, "concepts_azaath.html").replace(/\\/g, "/");
console.log(`Rendering via Edge: ${htmlUrl}`);
const res = spawnSync(
  EDGE,
  [
    "--headless=new",
    "--disable-gpu",
    "--allow-file-access-from-files",
    "--virtual-time-budget=60000",
    "--dump-dom",
    htmlUrl,
  ],
  { encoding: "utf8", maxBuffer: 1 << 28 }
);

if (res.error) throw res.error;
if (res.status !== 0) {
  console.error("Edge stderr:", res.stderr);
  throw new Error(`Edge exited with status ${res.status}`);
}

const m = res.stdout.match(/<pre[^>]*id="out"[^>]*>([\s\S]*?)<\/pre>/i);
if (!m) {
  console.error("STDOUT tail:", res.stdout.slice(-1000));
  console.error("STDERR:", res.stderr);
  throw new Error('Could not find <pre id="out"> in rendered DOM');
}

const payload = JSON.parse(m[1].trim());
const FILES = {
  obs: "Drops_Novo1_ObsidianaAzaath.png",
  pla: "Drops_Novo2_PlatinaPlasma.png",
  cmp: "Drops_Novos_Comparativo.png",
};

for (const [key, outName] of Object.entries(FILES)) {
  const dataUrl = payload[key];
  if (!dataUrl || !dataUrl.startsWith("data:image/png;base64,")) {
    throw new Error(`Missing or invalid PNG payload for key: ${key}`);
  }
  const outPath = path.join(OUT_DIR, outName);
  const buf = Buffer.from(dataUrl.slice("data:image/png;base64,".length), "base64");
  fs.writeFileSync(outPath, buf);
  console.log(`Saved ${outPath} (${Math.round(buf.length / 1024)} KB)`);
}
