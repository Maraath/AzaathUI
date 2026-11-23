// lista as peças (componentes não pretos) de uma folha de referência
const { readPNG } = require("../grimoire-concept/png");
const img = readPNG(process.argv[2]); const T = +(process.argv[3] || 22);
const { w, h, px: data } = img; const lab = new Int32Array(w * h).fill(-1); const out = [];
const on = (i) => Math.max(data[i * 4], data[i * 4 + 1], data[i * 4 + 2]) > T;
for (let s = 0; s < w * h; s++) {
  if (lab[s] >= 0 || !on(s)) continue;
  let x0 = w, y0 = h, x1 = 0, y1 = 0, n = 0; const st = [s]; lab[s] = out.length;
  while (st.length) { const p = st.pop(), x = p % w, y = (p / w) | 0; n++;
    if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
    for (let dy = -2; dy <= 2; dy++) for (let dx = -2; dx <= 2; dx++) { const q = (y + dy) * w + x + dx;
      if (x + dx < 0 || x + dx >= w || y + dy < 0 || y + dy >= h || lab[q] >= 0 || !on(q)) continue; lab[q] = out.length; st.push(q); } }
  out.push({ x0, y0, x1, y1, n });
}
out.filter((o) => o.n > 150).sort((a, b) => a.y0 - b.y0 || a.x0 - b.x0).forEach((o) => console.log(`x ${o.x0}-${o.x1} (${o.x1 - o.x0 + 1})  y ${o.y0}-${o.y1} (${o.y1 - o.y0 + 1})  px ${o.n}`));
