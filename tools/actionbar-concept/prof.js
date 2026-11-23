const { readPNG } = require("../grimoire-concept/png");
const s = readPNG(__dirname + "/concept.png");
const L = (x, y) => { const o = (y * s.w + x) * 4; return 0.3 * s.px[o] + 0.59 * s.px[o + 1] + 0.11 * s.px[o + 2]; };
const [mode, a0, a1, b0, b1] = process.argv.slice(2).map((v, i) => i ? +v : v);
// mode x: profile over x in [a0,a1], averaging y in [b0,b1]; mode y: inverse
const out = [];
for (let a = a0; a <= a1; a++) { let t = 0; for (let b = b0; b <= b1; b++) t += mode === "x" ? L(a, b) : L(b, a); out.push(a + ":" + Math.round(t / (b1 - b0 + 1))); }
console.log(out.join(" "));
