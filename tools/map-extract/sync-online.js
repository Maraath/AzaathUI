// Baixa e mantém em cache local (tools/.cache/) apenas os dados de missões/itens
// da release mais recente do repositório público fitzforge/polestar no GitHub.
// Se a tag já estiver em cache, termina em <1s sem baixar nada.
// Assim o AzaathUI atualiza mesmo sem nenhum outro addon instalado no WoW.
"use strict";
const fs = require("fs");
const path = require("path");
const { execFileSync } = require("child_process");

const CACHE_DIR = path.join(__dirname, "../.cache");
const TAG_FILE = path.join(CACHE_DIR, "polestar-tag.txt");
const ZIP_FILE = path.join(CACHE_DIR, "polestar-latest.zip");
const EXTRACT_DIR = path.join(CACHE_DIR, "polestar");
const API_URL = "https://api.github.com/repos/fitzforge/polestar/releases/latest";

async function main() {
  fs.mkdirSync(CACHE_DIR, { recursive: true });
  const currentTag = fs.existsSync(TAG_FILE) ? fs.readFileSync(TAG_FILE, "utf8").trim() : "";

  let rel;
  try {
    const res = await fetch(API_URL, { headers: { "User-Agent": "AzaathUI-Updater" } });
    if (!res.ok) throw new Error("HTTP " + res.status);
    rel = await res.json();
  } catch (err) {
    console.warn("[Azaath] Aviso: falha ao checar GitHub online (" + err.message + "), usando cache/local.");
    return;
  }

  const tag = rel.tag_name || "";
  if (tag && tag === currentTag && fs.existsSync(path.join(EXTRACT_DIR, "Polestar_QuestDB", "Quests.lua"))) {
    console.log("[Azaath] Dados online ja atualizados (" + tag + ").");
    return;
  }

  const asset = (rel.assets || []).find((a) => /^Polestar-[\d.]+\.zip$/i.test(a.name));
  if (!asset) {
    console.warn("[Azaath] Asset zip nao encontrado na release", tag);
    return;
  }

  console.log("[Azaath] Baixando atualizacao online:", tag, "(" + Math.round(asset.size / 1024) + " KB)...");
  const dl = await fetch(asset.browser_download_url, { headers: { "User-Agent": "AzaathUI-Updater" } });
  if (!dl.ok) throw new Error("Download falhou: HTTP " + dl.status);
  const buf = Buffer.from(await dl.arrayBuffer());
  fs.writeFileSync(ZIP_FILE, buf);

  if (fs.existsSync(EXTRACT_DIR)) fs.rmSync(EXTRACT_DIR, { recursive: true, force: true });
  fs.mkdirSync(EXTRACT_DIR, { recursive: true });

  // Extrai usando tar (nativo do Windows 10/11) apenas as pastas de dados
  execFileSync("tar", [
    "-xf", ZIP_FILE,
    "-C", EXTRACT_DIR,
    "Polestar_QuestDB",
    "Polestar_ItemDB",
    "Polestar_ptBR"
  ], { stdio: "inherit" });

  fs.unlinkSync(ZIP_FILE);
  fs.writeFileSync(TAG_FILE, tag, "utf8");
  console.log("[Azaath] Cache online atualizado para", tag);
}

main().catch((e) => {
  console.error("[Azaath] Erro em sync-online:", e.message);
  process.exitCode = 1;
});
