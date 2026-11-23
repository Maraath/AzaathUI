// Servidor estático mínimo para a prévia (node tools/bdo-hud-concept/serve.js)
const http = require("http"), fs = require("fs"), path = require("path");
const dir = path.join(__dirname, "preview");
const types = { ".html": "text/html", ".png": "image/png", ".js": "text/javascript", ".ttf": "font/ttf" };
http.createServer((q, r) => {
  const f = path.join(dir, decodeURIComponent(q.url.split("?")[0]).replace(/^\/+/, "") || "fonts/cmp.html");
  fs.readFile(f, (e, d) => { if (e) { r.writeHead(404); r.end(); return; } r.writeHead(200, { "Content-Type": types[path.extname(f)] || "application/octet-stream", "Cache-Control": "no-store" }); r.end(d); });
}).listen(+process.env.PORT || 8767);
