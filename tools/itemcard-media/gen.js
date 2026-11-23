// Card de item no estilo New World: texturas procedurais (nenhuma arte de terceiros).
//   node gen.js        -> gera em out/ + previa.png (cabeçalho tingido nas raridades)
//   node gen.js apply  -> grava em AzaathUI/Media/ItemCard
// HeaderGrunge é cinza: o Lua tinge com a cor da raridade (SetVertexColor), como os
// cabeçalhos do jogo (papel amassado escuro em cima, mais claro embaixo).
const fs = require("fs"), path = require("path");
const C = require("../map-extract/imagecodec.js");

const ROOT = path.resolve(__dirname, "../..");
const MEDIA = path.join(ROOT, "AzaathUI/Media/ItemCard");
const OUT = path.join(__dirname, "out");
const APPLY = process.argv[2] === "apply";

const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const smooth = (e0, e1, x) => { const t = clamp((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t); };
const mix = (a, b, t) => a + (b - a) * t;
function hash(x, y, s = 0) { const h = Math.sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453; return h - Math.floor(h); }
// ruído de valor periódico (px, py = período) para a textura repetir sem emenda
function vnoise(x, y, s, px = 1e9, py = 1e9) {
	const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
	const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
	const H = (a, b) => hash(((a % px) + px) % px, ((b % py) + py) % py, s);
	return mix(mix(H(xi, yi), H(xi + 1, yi), u), mix(H(xi, yi + 1), H(xi + 1, yi + 1), u), v);
}
function fbm(x, y, s, o, px, py) {
	let v = 0, a = 0.5;
	for (let i = 0; i < o; i++) { v += a * vnoise(x, y, s + i, px, py); x *= 2; y *= 2; px *= 2; py *= 2; a *= 0.5; }
	return v / (1 - Math.pow(0.5, o));
}
const segDist = (px, py, ax, ay, bx, by) => {
	const dx = bx - ax, dy = by - ay, l = dx * dx + dy * dy, t = l ? clamp(((px - ax) * dx + (py - ay) * dy) / l) : 0;
	return Math.hypot(px - ax - dx * t, py - ay - dy * t);
};
const polyDist = (px, py, pts) => { let d = 1e9; for (let i = 0; i < pts.length; i++) { const a = pts[i], b = pts[(i + 1) % pts.length]; d = Math.min(d, segDist(px, py, a[0], a[1], b[0], b[1])); } return d; };
function inside(px, py, pts) { let c = false; for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) { const [xi, yi] = pts[i], [xj, yj] = pts[j]; if ((yi > py) !== (yj > py) && px < (xj - xi) * (py - yi) / (yj - yi) + xi) c = !c; } return c; }
const sdPoly = (x, y, pts) => (inside(x, y, pts) ? -1 : 1) * polyDist(x, y, pts);

// fn(x, y) em pixels -> [r,g,b,a] 0..1, com supersampling
function render(w, h, fn, ss = 3) {
	const img = C.makeImage(w, h);
	for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
		let r = 0, g = 0, b = 0, a = 0;
		for (let sy = 0; sy < ss; sy++) for (let sx = 0; sx < ss; sx++) {
			const c = fn(x + (sx + 0.5) / ss, y + (sy + 0.5) / ss), al = clamp(c[3]);
			r += c[0] * al; g += c[1] * al; b += c[2] * al; a += al;
		}
		const i = (y * w + x) * 4, k = a > 0 ? 1 / a : 0;
		img.data[i] = Math.round(clamp(r * k) * 255); img.data[i + 1] = Math.round(clamp(g * k) * 255);
		img.data[i + 2] = Math.round(clamp(b * k) * 255); img.data[i + 3] = Math.round(a / (ss * ss) * 255);
	}
	return img;
}
const W = (a) => [1, 1, 1, a];
const TEX = {};

// Cabeçalho: papel amassado (vincos = cristas do ruído), fibras verticais, mais escuro em cima,
// borda inferior acesa e cantos com vinheta. Proporção do cabeçalho do jogo (448x100).
TEX.HeaderGrunge = [512, 128, (x, y) => {
	const u = x / 512, v = y / 128;
	const base = fbm(u * 6, v * 1.6, 3, 5, 6, 1e9);
	const ridge = 1 - Math.abs(fbm(u * 9 + 3, v * 2.4, 11, 4, 9, 1e9) * 2 - 1);      // vincos
	const crease = Math.pow(ridge, 5);
	const fibre = fbm(u * 90, v * 1.2, 21, 2, 90, 1e9);                                 // listras verticais
	const speck = fbm(u * 40, v * 10, 31, 3, 40, 1e9);
	let l = 0.50 + 0.22 * (base - 0.5) + 0.06 * crease - 0.05 * (fibre - 0.5) + 0.14 * (speck - 0.5);
	l *= mix(0.55, 1.0, smooth(0.0, 0.95, v));                                          // escuro em cima
	l += 0.12 * smooth(0.80, 1.0, v);                                                   // borda inferior acesa
	l *= 1 - 0.30 * Math.pow(Math.abs(u - 0.5) * 2, 3);                                 // vinheta lateral
	return [l, l, l, 1];
}, 2];

// Fumaça do cabeçalho: ruído com deformação de domínio (fios e volutas), repete sem emenda nos dois
// eixos para rolar com SetTexCoord. Branca; a densidade vai no alfa. Duas camadas no Lua.
function smoke(seed, warp) {
	return (x, y) => {
		const u = x / 256 * 4, v = y / 256 * 4;                                   // período 4 células
		// a deformação é periódica também, então a emenda continua fechada
		const qx = fbm(u, v, seed, 4, 4, 4), qy = fbm(u + 1.7, v + 9.2, seed + 7, 4, 4, 4);
		const n = fbm(u + warp * qx * 4, v + warp * qy * 4, seed + 13, 4, 4, 4);
		const a = smooth(0.30, 0.92, n);
		return W(Math.pow(a, 1.7));
	};
}
TEX.Smoke1 = [256, 256, smoke(41, 0.45), 2];
TEX.Smoke2 = [256, 256, smoke(77, 0.7), 2];

// Clarão aditivo na base do cabeçalho (brasa por baixo do papel)
TEX.HeaderFlare = [256, 64, (x, y) => {
	const u = x / 256 - 0.5, v = 1 - y / 64;
	const a = Math.exp(-Math.pow(u / 0.42, 2)) * Math.exp(-v / 0.32);
	return W(a);
}];

// Ícone do nível do item: escudo hexagonal com a divisa para cima (como o do Gear Score)
TEX.ItemLevel = [64, 64, (x, y) => {
	const cx = 32, cy = 32, R = 27;
	const hex = Array.from({ length: 6 }, (_, i) => { const a = -Math.PI / 2 + i * Math.PI / 3; return [cx + Math.cos(a) * R, cy + Math.sin(a) * R]; });
	const d = sdPoly(x, y, hex);
	const ring = clamp(0.5 - (Math.abs(d + 3.2) - 3.2));                                 // aro de 6.4 px
	const chev = [[32, 17], [46, 30], [46, 44], [32, 32], [18, 44], [18, 30]];          // divisa cheia
	const c = clamp(0.5 - sdPoly(x, y, chev));
	return W(Math.max(ring, c));
}, 4];

// Losango vazado no meio do divisor
TEX.Diamond = [16, 16, (x, y) => {
	const d = (Math.abs(x - 8) + Math.abs(y - 8)) / Math.SQRT2 - 4.3;
	return W(clamp(0.5 - (Math.abs(d) - 0.75)));
}, 4];

// Fagulha: núcleo quente + halo
TEX.Spark = [32, 32, (x, y) => {
	const r = Math.hypot(x - 16, y - 16) / 16;
	return W(clamp(Math.exp(-Math.pow(r / 0.16, 2)) + 0.55 * Math.exp(-Math.pow(r / 0.45, 2))));
}];
// Brasa alongada (rastro vertical, ponta brilhante em cima)
TEX.Ember = [16, 48, (x, y) => {
	const u = (x - 8) / 8, v = y / 48;
	const tail = Math.exp(-Math.pow(u / (0.18 + 0.25 * v), 2)) * Math.pow(1 - v, 1.4);
	const head = Math.exp(-(Math.pow(u / 0.35, 2) + Math.pow((v - 0.12) / 0.09, 2)));
	return W(clamp(0.7 * tail + head));
}];

// Aro dos ícones de efeito (círculo fino)
TEX.PerkRing = [64, 64, (x, y) => {
	const r = Math.hypot(x - 32, y - 32);
	return W(clamp(0.5 - (Math.abs(r - 29.5) - 1.4)));
}, 4];
// Máscara circular dos ícones de efeito
TEX.PerkMask = [64, 64, (x, y) => W(clamp(0.5 - (Math.hypot(x - 32, y - 32) - 28.5))), 4];

// ------------------------------------------------------------------ geração
fs.mkdirSync(APPLY ? MEDIA : OUT, { recursive: true });
const made = {};
for (const [name, [w, h, fn, ss]] of Object.entries(TEX)) {
	made[name] = render(w, h, fn, ss || 3);
	C.writeTGA(path.join(APPLY ? MEDIA : OUT, name + ".tga"), made[name]);
}
console.log((APPLY ? "gravadas em " + MEDIA : "geradas em " + OUT) + ": " + Object.keys(made).length + " texturas");
if (APPLY) return;

// prévia: o cabeçalho nas cores de raridade (mesmas do Lua) + ícones
const RAR = [[0.36, 0.36, 0.38], [0.42, 0.42, 0.45], [0.16, 0.55, 0.16], [0.10, 0.48, 0.62], [0.52, 0.14, 0.62], [0.80, 0.40, 0.10], [0.80, 0.22, 0.08]];
const P = C.makeImage(512, RAR.length * 132 + 70);
P.data.fill(30);
for (let i = 3; i < P.data.length; i += 4) P.data[i] = 255;
const hg = made.HeaderGrunge, fl = made.HeaderFlare;
RAR.forEach((c, k) => {
	for (let y = 0; y < 128; y++) for (let x = 0; x < 512; x++) {
		const s = (y * 512 + x) * 4, d = ((k * 132 + y) * 512 + x) * 4;
		const f = fl.data[(Math.floor(y / 2) * 256 + Math.floor(x / 2)) * 4 + 3] / 255 * 0.35;
		for (let ch = 0; ch < 3; ch++) P.data[d + ch] = Math.round(clamp(hg.data[s + ch] / 255 * c[ch] * 1.6 + f * c[ch]) * 255);
	}
});
let ox = 4;
for (const n of ["ItemLevel", "Diamond", "Spark", "Ember", "PerkRing"]) {
	const m = made[n];
	for (let y = 0; y < m.h; y++) for (let x = 0; x < m.w; x++) {
		const s = (y * m.w + x) * 4, d = ((RAR.length * 132 + 4 + y) * 512 + ox + x) * 4, a = m.data[s + 3] / 255;
		for (let ch = 0; ch < 3; ch++) P.data[d + ch] = Math.round(P.data[d + ch] * (1 - a) + 255 * a);
	}
	ox += m.w + 8;
}
C.writePNG(path.join(OUT, "previa.png"), P);
console.log("prévia: " + path.join(OUT, "previa.png"));
