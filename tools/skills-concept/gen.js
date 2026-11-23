// Gera as texturas da aba Perícias e grava nas DUAS pastas (projeto e jogo):
//   SkillsBG     2048x2048 (2000x1125 úteis) = Pericias_ConceptArt_Fundo.png (rode render.js antes)
//   SkillsIcons / SkillsRing / SkillsParts  = gen.html (silhuetas de weapons.js)
//   node tools/skills-concept/gen.js
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const ROOT = path.join(__dirname, "..", "..");
const OUTS = [path.join(ROOT, "AzaathUI", "Media", "Sheet"),
  "C:/Program Files (x86)/World of Warcraft/_forever_/Interface/AddOns/AzaathUI/Media/Sheet"];
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(PREV, { recursive: true });

function save(name, img) {
  for (const dir of OUTS) I.writeTGA(path.join(dir, name + ".tga"), img);
  I.writePNG(path.join(PREV, name + ".png"), img);
  console.log(name, img.w + "x" + img.h);
}

// 1. fundo
const bg = readPNG(path.join(ROOT, "Pericias_ConceptArt_Fundo.png"));
const tex = I.create(2048, 2048, 0, 0, 0, 255);
I.blit(tex, bg, 0, 0);
save("SkillsBG", tex);

// 2. ícones, anel e peças
const url = "file:///" + path.join(__dirname, "gen.html").split(path.sep).join("/");
let dom = "";
for (let t = 0; t < 4 && !dom.includes("SkillsParts="); t++) {
  dom = spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--allow-file-access-from-files", "--virtual-time-budget=10000", "--dump-dom", url],
    { encoding: "utf8", maxBuffer: 1 << 28 }).stdout || "";
}
for (const name of ["SkillsIcons", "SkillsRing", "SkillsParts"]) {
  const m = new RegExp(name + "=data:image/png;base64,([A-Za-z0-9+/=]+)").exec(dom);
  if (!m) throw new Error("sem " + name);
  const tmp = path.join(PREV, name + "_raw.png");
  fs.writeFileSync(tmp, Buffer.from(m[1], "base64"));
  save(name, readPNG(tmp));
  fs.unlinkSync(tmp);
}
