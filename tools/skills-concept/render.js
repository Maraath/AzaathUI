// Pinta a arte de conceito da aba Perícias no Edge sem janela (canvas -> PNG).
//   node tools/skills-concept/render.js -> Pericias_ConceptArt_Fundo.png e Pericias_ConceptArt.png (raiz do projeto)
// O fundo vem de epic.js sobre stage.js (StageBackdrop ampliado 4x: stage_hd.png).
const fs = require("fs");
const path = require("path");
const { spawnSync } = require("child_process");
const EDGE = "C:/Program Files (x86)/Microsoft/Edge/Application/msedge.exe";
const html = "file:///" + path.join(__dirname, "art.html").split(path.sep).join("/");
const root = path.join(__dirname, "..", "..");

// stage.js = stage_hd.png embutida como data URL (não suja o canvas, toDataURL funciona)
const hd = path.join(__dirname, "stage_hd.png"), js = path.join(__dirname, "stage.js");
if (!fs.existsSync(js) || fs.statSync(js).mtimeMs < fs.statSync(hd).mtimeMs)
  fs.writeFileSync(js, "// gerado por render.js a partir de stage_hd.png\nconst STAGE = \"data:image/png;base64," + fs.readFileSync(hd).toString("base64") + "\";\n");

for (const [mode, out] of [["bg", "Pericias_ConceptArt_Fundo.png"], ["full&page=arsenal", "Pericias_ConceptArt.png"],
  ["full&page=oficios", "Pericias_ConceptArt_Oficios.png"], ["full&page=dominios", "Pericias_ConceptArt_Dominios.png"]]) {
  let m = null, r;
  // o Edge às vezes devolve a página antes de o canvas terminar: tenta de novo
  for (let tent = 0; tent < 4 && !m; tent++) {
    r = spawnSync(EDGE, ["--headless=new", "--disable-gpu", "--allow-file-access-from-files", "--virtual-time-budget=60000",
      "--dump-dom", html + "?mode=" + mode], { encoding: "utf8", maxBuffer: 1 << 28 });
    m = /data:image\/png;base64,([A-Za-z0-9+/=]+)/.exec(r.stdout || "");
  }
  if (!m) { console.error(mode, "sem imagem", r.status, (r.stderr || "").slice(0, 400)); continue; }
  fs.writeFileSync(path.join(root, out), Buffer.from(m[1], "base64"));
  console.log(mode, "->", out);
}
