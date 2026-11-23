// Prévia do conceito da barra de ação BDO (node tools/bdo-actionbar-concept/serve.js)
// GET serve os arquivos desta pasta; POST /save?name=x.png grava a imagem enviada (data URL).
const http = require("http"), fs = require("fs"), path = require("path");
const dir = __dirname;
const types = { ".html": "text/html", ".png": "image/png", ".js": "text/javascript", ".ttf": "font/ttf" };
http.createServer((q, r) => {
  const url = new URL(q.url, "http://x");
  if (q.method === "POST" && url.pathname === "/save") {
    const name = path.basename(url.searchParams.get("name") || "concept.png");
    let body = "";
    q.on("data", (c) => (body += c));
    q.on("end", () => {
      fs.writeFileSync(path.join(dir, name), Buffer.from(body.replace(/^data:image\/png;base64,/, ""), "base64"));
      r.writeHead(200); r.end("ok");
    });
    return;
  }
  const f = path.join(dir, decodeURIComponent(url.pathname).replace(/^\/+/, "") || "concept.html");
  fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); r.end(); return; } r.writeHead(200, { "Content-Type": types[path.extname(f)] || "application/octet-stream", "Cache-Control": "no-store" }); r.end(d); });
}).listen(+process.env.PORT || 8768);
