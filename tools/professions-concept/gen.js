const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const ROOT = path.join(__dirname, "..", "..");
const bg = readPNG(path.join(__dirname, "bg_1920x1080.png"));
const tex = I.create(2048, 2048, 0, 0, 0, 255);
I.blit(tex, bg, 0, 0);

const out = path.join(ROOT, "AzaathUI", "Media", "Sheet", "ProfessionsBG.tga");
I.writeTGA(out, tex);
console.log("ProfessionsBG.tga generated:", tex.w + "x" + tex.h, "->", out);
