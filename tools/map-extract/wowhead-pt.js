// Textos pt-BR do WoW Forever no Wowhead (seção /forever/pt), pela API pública de dicas:
//   https://nether.wowhead.com/forever/pt/tooltip/<quest|npc|object>/<id>
// Só o nome (e, nas missões, o objetivo) — textos do jogo, da Blizzard. Usado apenas para o que
// nenhuma fonte local tem. Respostas ficam em tools/.cache/wowhead-forever-ptBR.json; um ID sem
// tradução é consultado de novo depois de 7 dias. Pedidos em série, com pausa entre eles.
"use strict";
const fs = require("fs");
const path = require("path");

const CACHE_FILE = path.join(__dirname, "../.cache/wowhead-forever-ptBR.json");
const BASE = "https://nether.wowhead.com/forever/pt/tooltip/";
const RETRY_MS = 7 * 24 * 3600 * 1000;
const PAUSE_MS = 700;

function load() {
  try { return JSON.parse(fs.readFileSync(CACHE_FILE, "utf8")); } catch { return {}; }
}
function save(c) {
  fs.mkdirSync(path.dirname(CACHE_FILE), { recursive: true });
  fs.writeFileSync(CACHE_FILE, JSON.stringify(c, null, 1));
}

const strip = (html) => html.replace(/<br\s*\/?>/gi, "\n").replace(/<[^>]+>/g, "")
  .replace(/&nbsp;/g, " ").replace(/&amp;/g, "&").replace(/&quot;/g, "\"").replace(/&#39;/g, "'")
  .replace(/&lt;/g, "<").replace(/&gt;/g, ">");

// nome entre colchetes = o Wowhead ainda não tem a tradução (mostra o inglês)
function parse(kind, json) {
  if (!json || !json.name || /^\[.*\]$/.test(json.name)) return null;
  const out = { name: json.name.trim() };
  if (kind === "quest" && json.tooltip) {
    // segunda tabela: "<br />objetivo<br /><br />Requirements..."
    const parts = json.tooltip.split("</table>");
    const body = parts.slice(1).join("</table>");
    const m = /<td>\s*<br\s*\/?>([\s\S]*?)(?:<br\s*\/?>\s*<br\s*\/?>|<\/td>)/i.exec(body);
    if (m) {
      const t = strip(m[1]).replace(/\s+/g, " ").trim();
      if (t && !/^\[.*\]$/.test(t)) out.objective = t;
    }
  }
  return out;
}

async function fetchOne(kind, id) {
  const res = await fetch(BASE + kind + "/" + id, { headers: { "User-Agent": "Mozilla/5.0 (map-extract)" } });
  if (res.status === 404) return { miss: true };
  if (!res.ok) throw new Error(`${kind} ${id}: HTTP ${res.status}`);
  return { data: parse(kind, await res.json()) };
}

// wants: [{ kind, id }] -> Map("kind:id" -> { name, objective? } | null)
async function wowheadPt(wants, { offline = process.env.AZAATH_OFFLINE === "1" } = {}) {
  const cache = load();
  const now = Date.now();
  const todo = [];
  const seen = new Set();
  for (const w of wants) {
    const k = `${w.kind}:${w.id}`;
    if (seen.has(k) || !w.id) continue;
    seen.add(k);
    const c = cache[k];
    if (c && (c.data || now - (c.at || 0) < RETRY_MS)) continue;
    todo.push(w);
  }
  if (todo.length && !offline) {
    process.stdout.write(`Wowhead (pt): consultando ${todo.length}... `);
    let ok = 0;
    for (const w of todo) {
      const k = `${w.kind}:${w.id}`;
      try {
        const r = await fetchOne(w.kind, w.id);
        cache[k] = { at: now, data: r.data || null };
        if (r.data) ok++;
      } catch (e) {
        console.warn("\n  " + e.message);
        if (/HTTP (403|429)/.test(e.message)) break; // bloqueado: para e tenta outro dia
      }
      await new Promise((r) => setTimeout(r, PAUSE_MS));
    }
    console.log(`${ok} traduções novas`);
    save(cache);
  }
  const out = new Map();
  for (const k of seen) out.set(k, (cache[k] && cache[k].data) || null);
  return out;
}

module.exports = { wowheadPt };
