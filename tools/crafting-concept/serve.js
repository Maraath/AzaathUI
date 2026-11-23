// Servidor estático mínimo para as prévias de tools/ (node tools/crafting-concept/serve.js)
// Abre em http://localhost:8766/crafting-concept/bar-preview.html
const http = require("http"), fs = require("fs"), path = require("path");
const dir = path.join(__dirname, "..");
const types = { ".html": "text/html", ".png": "image/png", ".js": "text/javascript", ".css": "text/css" };
http.createServer((q, r) => {
  const rel = decodeURIComponent(q.url.split("?")[0]).replace(/^\/+/, "") || "crafting-concept/bar-preview.html";
  const f = path.join(dir, rel);
  if (!f.startsWith(dir)) { r.writeHead(403); r.end(); return; }
  fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); r.end(); return; } r.writeHead(200, { "Content-Type": types[path.extname(f)] || "application/octet-stream", "Cache-Control": "no-store" }); r.end(d); });
}).listen(+process.env.PORT || 8766);
