// Renderiza a arte de conceito texturizada da aba Drops ("O Relicário de Azaath")
// Carrega as texturas reais do ecossistema Azaath (CraftFrames, CraftRings, card.png,
// bg_1920x1080.png, warrior_pedestal.jpg, helmets_grid.jpg) em assets.js (data URLs)
// para evitar qualquer bloqueio de canvas no Edge headless.
//
// Uso: node tools/drops-concept/render.js -> D:\ProjectAzaath\Drops_ConceptArt.png
"use strict";
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");

const ROOT = path.join(__dirname, "..", "..");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const html = "file:///" + path.join(__dirname, "art.html").split(path.sep).join("/");
const out = path.join(ROOT, "Drops_ConceptArt.png");

const ASSET_FILES = {
  CraftFrames: [path.join(ROOT, "tools", "professions-ui-concept", "preview", "CraftFrames.png"), "image/png"],
  CraftRings:  [path.join(ROOT, "tools", "professions-ui-concept", "preview", "CraftRings.png"),  "image/png"],
  CodexCard:   [path.join(ROOT, "tools", "card-concept", "preview", "card.png"),                 "image/png"],
  HallBG:      [path.join(ROOT, "tools", "professions-concept", "bg_1920x1080.png"),             "image/png"],
  Warrior:     [path.join(__dirname, "warrior_pedestal.jpg"),                                    "image/jpeg"],
  Helmets:     [path.join(__dirname, "helmets_grid.jpg"),                                        "image/jpeg"],
};

const assetLines = ["// Gerado por render.js", "const ASSETS = {"];
for (const [k, [fp, mime]] of Object.entries(ASSET_FILES)) {
  if (!fs.existsSync(fp)) {
    console.error("Asset ausente:", fp);
    process.exit(1);
  }
  const b64 = fs.readFileSync(fp).toString("base64");
  assetLines.push(`  ${k}: "data:${mime};base64,${b64}",`);
}
assetLines.push("};");
fs.writeFileSync(path.join(__dirname, "assets.js"), assetLines.join("\n"));

let m = null, r;
for (let tent = 0; tent < 4 && !m; tent++) {
  r = spawnSync(
    EDGE,
    [
      "--headless=new",
      "--disable-gpu",
      "--allow-file-access-from-files",
      "--virtual-time-budget=60000",
      "--dump-dom",
      html,
    ],
    { encoding: "utf8", maxBuffer: 1 << 28 }
  );
  m = /data:image\/png;base64,([A-Za-z0-9+/=]+)/.exec(r.stdout || "");
}

if (!m) {
  console.error("Falha ao gerar imagem:", r && r.status, (r && r.stderr || "").slice(0, 500));
  process.exit(1);
}

fs.writeFileSync(out, Buffer.from(m[1], "base64"));
const kb = (fs.statSync(out).size / 1024).toFixed(1);
console.log(`Gerado ${out} (${kb} KB)`);
