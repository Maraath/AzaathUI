// Olho de Azaath: gera as texturas próprias do efeito (tema alquímico do Azaath).
// Cada imagem mantém as medidas que o código usa (raio do anel, cantos, máscara, furo do anel do
// minimapa), então os efeitos continuam iguais; só o desenho muda.
//   node gen.js          -> gera em out/ e monta compare.png (e efeitos.png, os ícones dos efeitos)
//   node gen.js apply    -> grava as texturas em AzaathUI/Media/OlhoAzaath
const fs = require("fs"), path = require("path");
const C = require("../map-extract/imagecodec.js");

const ROOT = path.resolve(__dirname, "../..");
const MEDIA = path.join(ROOT, "AzaathUI/Media/OlhoAzaath");
const OUT = path.join(__dirname, "out");
const APPLY = process.argv[2] === "apply";

// ------------------------------------------------------------------ utilidades
const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const smooth = (e0, e1, x) => { const t = clamp((x - e0) / (e1 - e0)); return t * t * (3 - 2 * t); };
const mix = (a, b, t) => a + (b - a) * t;
function segDist(px, py, ax, ay, bx, by) {
	const dx = bx - ax, dy = by - ay, l = dx * dx + dy * dy;
	const t = l ? clamp(((px - ax) * dx + (py - ay) * dy) / l) : 0;
	return Math.hypot(px - ax - dx * t, py - ay - dy * t);
}
function polyDist(px, py, pts, closed) {
	let d = Infinity;
	for (let i = 0; i < pts.length - (closed ? 0 : 1); i++) {
		const a = pts[i], b = pts[(i + 1) % pts.length];
		d = Math.min(d, segDist(px, py, a[0], a[1], b[0], b[1]));
	}
	return d;
}
// traço nítido de meia-largura w (unidades da imagem 0..1), com borda suave de um pixel
const line = (d, w, px) => clamp((w - d) / px + 0.5);
const glow = (d, s) => Math.exp(-(d * d) / (s * s));
const union = (...a) => 1 - a.reduce((p, v) => p * (1 - clamp(v)), 1);
// ruído de valor suave, repetível
function hash(x, y, s = 0) { const h = Math.sin(x * 127.1 + y * 311.7 + s * 74.7) * 43758.5453; return h - Math.floor(h); }
function vnoise(x, y, s) {
	const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
	const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
	return mix(mix(hash(xi, yi, s), hash(xi + 1, yi, s), u), mix(hash(xi, yi + 1, s), hash(xi + 1, yi + 1, s), u), v);
}
// ruído periódico no ângulo (para anéis sem emenda)
function ringNoise(ang, r, s, oct = 4) {
	let v = 0, amp = 0.5, f = 1;
	for (let o = 0; o < oct; o++) {
		const k = 6 * f;
		v += amp * vnoise(Math.cos(ang) * k + 50, Math.sin(ang) * k + r * 9 * f + 50, s + o);
		amp *= 0.5; f *= 2;
	}
	return v;
}
// ponto em coordenadas centradas: x para a direita, y para cima, em frações da largura
function render(w, h, fn, ss = 3) {
	const img = C.makeImage(w, h);
	const px = 1 / w;
	for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
		let r = 0, g = 0, b = 0, a = 0;
		for (let sy = 0; sy < ss; sy++) for (let sx = 0; sx < ss; sx++) {
			const u = (x + (sx + 0.5) / ss) / w - 0.5, v = (h / w) * 0.5 - (y + (sy + 0.5) / ss) / w;
			const c = fn(u, v, px);
			const al = clamp(c[3]);
			r += c[0] * al; g += c[1] * al; b += c[2] * al; a += al;
		}
		const i = (y * w + x) * 4, n = ss * ss;
		img.data[i + 3] = Math.round(a / n * 255);
		const k = a > 0 ? 1 / a : 0;
		img.data[i] = Math.round(clamp(r * k) * 255); img.data[i + 1] = Math.round(clamp(g * k) * 255); img.data[i + 2] = Math.round(clamp(b * k) * 255);
	}
	return img;
}
const white = (a) => [1, 1, 1, a];
const polar = (u, v) => [Math.hypot(u, v), Math.atan2(v, u)];
const rot = (x, y, a) => [x * Math.cos(a) - y * Math.sin(a), x * Math.sin(a) + y * Math.cos(a)];
const ngon = (n, r, a0 = Math.PI / 2) => Array.from({ length: n }, (_, i) => [Math.cos(a0 + i * 2 * Math.PI / n) * r, Math.sin(a0 + i * 2 * Math.PI / n) * r]);
// losango (diamante) centrado em (cx, cy): distância "dentro" negativa
const diamond = (u, v, cx, cy, rx, ry) => (Math.abs(u - cx) / rx + Math.abs(v - cy) / ry) - 1;

// ------------------------------------------------------------------ texturas
const TEX = {};

// brilho suave e máscara da silhueta: funções genéricas, mesmas curvas de antes (o código depende delas)
TEX.glow = [128, 128, (u, v) => white(Math.exp(-Math.pow(Math.hypot(u, v) / 0.155, 1.85)))];
TEX.hole = [128, 128, (u, v) => white(smooth(0.27, 0.475, Math.hypot(u, v)))];
TEX.empty = [32, 32, () => [0, 0, 0, 0]];

// v2: formas com a cara do Azaath (substituem as acima, menos glow/hole/empty)
require("./tex-v2.js")(TEX, { clamp, smooth, mix, segDist, polyDist, line, glow, union, vnoise, hash, white, polar, rot, ngon, diamond });

// ------------------------------------------------------------------ geração
fs.mkdirSync(OUT, { recursive: true });
const made = {};
for (const [name, [w, h, fn, ss]] of Object.entries(TEX)) {
	const img = render(w, h, fn, ss || 3);
	made[name] = img;
	C.writeTGA(path.join(APPLY ? MEDIA : OUT, name + ".tga"), img);
}
console.log((APPLY ? "gravadas em " + MEDIA : "geradas em " + OUT) + ": " + Object.keys(made).length + " texturas");
if (APPLY) return;

// ------------------------------------------------------------------ prévia: antes x depois
const font = require("./font.js");
function blankImg(w, h, c) { const m = C.makeImage(w, h); for (let i = 0; i < w * h; i++) { m.data[i * 4] = c[0]; m.data[i * 4 + 1] = c[1]; m.data[i * 4 + 2] = c[2]; m.data[i * 4 + 3] = 255; } return m; }
function blit(dst, src, ox, oy, size, tint) {
	const s = Math.min(size / src.w, size / src.h), W = src.w * s, H = src.h * s;
	const x0 = ox + (size - W) / 2, y0 = oy + (size - H) / 2;
	for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) {
		const i = (Math.floor(y / s) * src.w + Math.floor(x / s)) * 4, a = src.data[i + 3] / 255;
		const d = ((Math.floor(y0 + y)) * dst.w + Math.floor(x0 + x)) * 4;
		for (let c = 0; c < 3; c++) dst.data[d + c] = Math.round(dst.data[d + c] * (1 - a) + src.data[i + c] * (tint ? tint[c] : 1) * a);
	}
}
const names = Object.keys(TEX).filter(n => n !== "empty");
const cell = 150, gap = 10, label = 18, cols = 4;
const rows = Math.ceil(names.length / cols);
const sheet = blankImg(cols * (cell * 2 + gap * 3), rows * (cell + label + gap) + 40, [16, 18, 24]);
font.text(sheet, 10, 12, "TEXTURAS DO OLHO DE AZAATH", [230, 200, 120]);
names.forEach((n, k) => {
	const cx = (k % cols) * (cell * 2 + gap * 3) + gap, cy = Math.floor(k / cols) * (cell + label + gap) + 40;
	font.text(sheet, cx, cy, n, [200, 200, 210]);
	const old = path.join(ROOT, "tools/olho-azaath-media/antes", n + ".tga");
	if (fs.existsSync(old)) blit(sheet, C.readTGA(old), cx, cy + label, cell);
	blit(sheet, made[n], cx + cell + gap, cy + label, cell);
});
C.writePNG(path.join(__dirname, "compare.png"), sheet);

// ------------------------------------------------------------------ prévia: ícones dos efeitos (como no menu)
const src = fs.readFileSync(path.join(ROOT, "AzaathUI/Modules/OlhoAzaath/Effects.lua"), "utf8");
function iconTables() {
	const out = {};
	const re = /EFFECTS\.(\w+)(?:\.icon)?\s*=\s*\{/g; let m;
	while ((m = re.exec(src))) {
		const name = m[1];
		let i = m.index + m[0].length - 1;
		if (!m[0].includes(".icon")) { const j = src.indexOf("icon = {", i); const next = src.indexOf("\nEFFECTS.", i + 1); if (j < 0 || (next > 0 && j > next)) continue; i = j + 7; }
		let depth = 0, k = i;
		for (; k < src.length; k++) { if (src[k] === "{") depth++; else if (src[k] === "}") { depth--; if (!depth) break; } }
		const body = src.slice(i, k + 1).replace(/--[^\n]*/g, "").replace(/\{/g, "[").replace(/\}/g, "]").replace(/,\s*\]/g, "]");
		try { out[name] = JSON.parse(body); } catch (e) { }
	}
	return out;
}
const icons = iconTables();
const order = ["aura", "subtle", "sigil", "brackets", "vortex", "rift", "flame", "storm", "beam", "geyser", "beacon", "orbit", "spirit", "ripple", "sparkle"].filter(n => icons[n]);
const tint = [1.0, 0.6, 0.18];
function drawIcon(dst, layers, dir, ox, oy, size, loader) {
	for (const [img, w, h, x, y, alpha, wh] of layers) {
		const t = loader(img); if (!t) continue;
		const W = w * size, H = h * size, x0 = ox + size / 2 + x * size - W / 2, y0 = oy + size / 2 - y * size - H / 2;
		for (let yy = 0; yy < H; yy++) for (let xx = 0; xx < W; xx++) {
			const sx = Math.floor(xx / W * t.w), sy = Math.floor(yy / H * t.h), i = (sy * t.w + sx) * 4;
			const a = t.data[i + 3] / 255 * alpha;
			const d = (Math.floor(y0 + yy) * dst.w + Math.floor(x0 + xx)) * 4;
			if (d < 0 || d >= dst.data.length) continue;
			for (let c = 0; c < 3; c++) { const col = (wh ? mix(tint[c], 1, 0.7) : tint[c]) * t.data[i + c]; dst.data[d + c] = Math.min(255, dst.data[d + c] + col * a); }
		}
	}
}
const cache = {};
const loadOld = n => cache["o" + n] ??= (fs.existsSync(path.join(__dirname, "antes", n + ".tga")) ? C.readTGA(path.join(__dirname, "antes", n + ".tga")) : null);
const loadNew = n => made[n];
const isz = 110, icols = 5;
const fx = blankImg(icols * (isz * 2 + 30), Math.ceil(order.length / icols) * (isz + 30) + 40, [16, 18, 24]);
font.text(fx, 10, 12, "EFEITOS COMO NO MENU (antes | depois), cor de minerio", [230, 200, 120]);
order.forEach((n, k) => {
	const ox = (k % icols) * (isz * 2 + 30) + 10, oy = Math.floor(k / icols) * (isz + 30) + 40;
	font.text(fx, ox, oy, n, [200, 200, 210]);
	drawIcon(fx, icons[n], 0, ox, oy + 16, isz, loadOld);
	drawIcon(fx, icons[n], 0, ox + isz + 8, oy + 16, isz, loadNew);
});
C.writePNG(path.join(__dirname, "efeitos.png"), fx);
console.log("prévias: compare.png e efeitos.png");
