const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const OUT_DIR = "C:/Users/Novo Usuario/.gemini/antigravity/brain/e07e647f-89c4-4312-b74a-8cc81619678e";
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const BASE_DIR = __dirname;

const ASSET_MAP = {
  c1: [path.join(OUT_DIR, "azoth_ui_sprite_sheet_1795024599352.jpg"), "image/jpeg"],
  c2: [path.join(OUT_DIR, "azoth_ui_spritesheet_royal_iron_1795024599462.jpg"), "image/jpeg"],
  c3: [path.join(OUT_DIR, "azoth_crystal_ui_sprite_sheet_v2_1795024623127.jpg"), "image/jpeg"],
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

const assetsJsPath = path.join(BASE_DIR, "assets_concepts.js");
fs.writeFileSync(assetsJsPath, `window.ASSETS = ${JSON.stringify(assets)};\n`, "utf8");
console.log(`Wrote ${assetsJsPath}`);

const htmlUrl = "file:///" + path.join(BASE_DIR, "concepts.html").replace(/\\/g, "/");
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
  throw new Error("Could not find <pre id=\"out\"> in rendered DOM");
}

const jsonStr = m[1].trim();
const payload = JSON.parse(jsonStr);

const FILES = {
  c1: "Drops_Conceito1_OuroAstral.png",
  c2: "Drops_Conceito2_FerroNegroFiligrana.png",
  c3: "Drops_Conceito3_CrisolCristal.png",
  cmp: "Drops_Comparativo_Cards.png",
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
