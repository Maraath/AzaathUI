// Olho de Azaath: gera as texturas próprias do efeito (tema alquímico do Azaath).
// Cada imagem mantém as medidas que o código usa (raio do anel, cantos, máscara, furo do anel do
// minimapa), então os efeitos continuam iguais; só o desenho muda.
//   node gen.js          -> gera em out/ e monta compare.png (antes x depois + ícones dos efeitos)
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

// ------------------------------------------------------------------ símbolos alquímicos (traços)
// cada um devolve a distância ao desenho, num quadro local de "raio" 1
const SYMBOLS = {
	fire: (x, y) => polyDist(x, y, ngon(3, 1), true),
	water: (x, y) => polyDist(x, y, ngon(3, 1, -Math.PI / 2), true),
	air: (x, y) => Math.min(polyDist(x, y, ngon(3, 1), true), segDist(x, y, -0.62, -0.05, 0.62, -0.05)),
	earth: (x, y) => Math.min(polyDist(x, y, ngon(3, 1, -Math.PI / 2), true), segDist(x, y, -0.62, 0.05, 0.62, 0.05)),
	sun: (x, y) => Math.min(Math.abs(Math.hypot(x, y) - 0.85), Math.max(0, Math.hypot(x, y) - 0.12)),
	moon: (x, y) => Math.max(Math.abs(Math.hypot(x, y) - 0.85) - 0.0, -(Math.hypot(x - 0.45, y) - 0.7)),
	salt: (x, y) => Math.min(Math.abs(Math.hypot(x, y) - 0.85), segDist(x, y, -0.85, 0, 0.85, 0)),
	sulfur: (x, y) => Math.min(polyDist(x, y, ngon(3, 0.6, Math.PI / 2).map(p => [p[0], p[1] + 0.35]), true),
		segDist(x, y, 0, 0.05, 0, -1), segDist(x, y, -0.4, -0.5, 0.4, -0.5)),
};

// ------------------------------------------------------------------ texturas
const TEX = {};

// anel fino (raio 0.37 da largura: RING_ORBIT em Effects.lua), com fio duplo e quatro losangos
TEX.ring = [256, 256, (u, v, px) => {
	const [r, a] = polar(u, v);
	const main = line(Math.abs(r - 0.37), 0.0055, px) + 0.55 * glow(r - 0.37, 0.025);
	const thin = 0.35 * line(Math.abs(r - 0.349), 0.0018, px);
	let studs = 0;
	for (let k = 0; k < 4; k++) {
		const ang = Math.PI / 4 + k * Math.PI / 2;
		const [x, y] = rot(u, v, -ang);
		studs = Math.max(studs, line(diamond(x, y, 0.37, 0, 0.022, 0.012), 0, px * 30));
	}
	return white(union(main, thin, studs, 0.25 * glow(r - 0.33, 0.05) * (r < 0.37)));
}];

// dois arcos-cometa no raio 0.44, cabeça em losango e cauda que afina
TEX.arcs = [256, 256, (u, v, px) => {
	const [r, a] = polar(u, v);
	let s = 0;
	for (const head of [Math.PI * 0.08, Math.PI * 1.08]) {
		let d = head - a; while (d < 0) d += 2 * Math.PI; while (d > 2 * Math.PI) d -= 2 * Math.PI;
		const len = Math.PI * 0.62;
		if (d < len) {
			const t = 1 - d / len;
			s = Math.max(s, line(Math.abs(r - 0.44), 0.002 + 0.007 * t, px) * (0.25 + 0.75 * t) + 0.4 * t * glow(r - 0.44, 0.02));
		}
		const hx = Math.cos(head) * 0.44, hy = Math.sin(head) * 0.44;
		const [x, y] = rot(u - hx, v - hy, -head);
		s = Math.max(s, line(diamond(x, y, 0, 0, 0.016, 0.03), 0, px * 30), 0.6 * glow(Math.hypot(x, y), 0.03));
	}
	return white(s);
}];

// selo: círculo cheio 0.33, fileira de traços triangulares 0.30, anel externo 0.45 e os quatro
// elementos (cardeais) e a tria prima + sol (diagonais) entre eles
TEX.sigil = [256, 256, (u, v, px) => {
	const [r, a] = polar(u, v);
	const c1 = line(Math.abs(r - 0.33), 0.004, px);
	const c2 = line(Math.abs(r - 0.455), 0.004, px);
	const c3 = 0.6 * line(Math.abs(r - 0.47), 0.0015, px);
	const seg = 2 * Math.PI / 48, la = ((a % seg) + seg) % seg - seg / 2;
	const tick = (Math.abs(la) < seg * 0.28) ? line(Math.abs(r - 0.302), 0.010 * (1 - Math.abs(la) / (seg * 0.28)) + 0.002, px) : 0;
	const names = ["fire", "sun", "air", "salt", "water", "moon", "earth", "sulfur"];
	let sym = 0;
	for (let k = 0; k < 8; k++) {
		const ang = Math.PI / 2 - k * Math.PI / 4;
		const cx = Math.cos(ang) * 0.392, cy = Math.sin(ang) * 0.392;
		const [x, y] = rot(u - cx, v - cy, -(ang - Math.PI / 2));
		const sc = 0.042;
		if (Math.abs(x) < sc * 1.5 && Math.abs(y) < sc * 1.5) sym = Math.max(sym, line(SYMBOLS[names[k]](x / sc, y / sc) * sc, 0.0035, px));
	}
	return white(union(c1, c2, c3, tick, sym));
}];

// figura: quadratura do círculo (quadrado, triângulo e círculo inscrito); vértices no raio 0.46
TEX.glyph = [256, 256, (u, v, px) => {
	const sq = ngon(4, 0.46, Math.PI / 4), tri = ngon(3, 0.46);
	const r = Math.hypot(u, v);
	const lines = Math.max(line(polyDist(u, v, sq, true), 0.0045, px), line(polyDist(u, v, tri, true), 0.0045, px));
	const inner = line(Math.abs(r - 0.23), 0.0045, px);
	let dots = 0;
	for (const p of [...sq, ...tri]) dots = Math.max(dots, line(Math.hypot(u - p[0], v - p[1]) - 0.014, 0, px));
	const star = Math.max(line(diamond(u, v, 0, 0, 0.012, 0.05), 0, px * 30), line(diamond(u, v, 0, 0, 0.05, 0.012), 0, px * 30));
	return white(union(lines, inner, dots, star, 0.5 * glow(r, 0.035)));
}];

// cantoneiras: cantos em 0.37 do centro (BRACKET_CORNER), em ponta de flecha com losango no vértice
TEX.brackets = [256, 256, (u, v, px) => {
	const C0 = 0.37, L = 0.13;
	let s = 0;
	for (const [sx, sy] of [[1, 1], [-1, 1], [1, -1], [-1, -1]]) {
		const x = u * sx, y = v * sy; // canto em (+C0, +C0)
		const arm = Math.min(segDist(x, y, C0, C0, C0 - L, C0), segDist(x, y, C0, C0, C0, C0 - L));
		const inner = Math.min(segDist(x, y, C0 - 0.03, C0 - 0.03, C0 - 0.03 - L * 0.55, C0 - 0.03), segDist(x, y, C0 - 0.03, C0 - 0.03, C0 - 0.03, C0 - 0.03 - L * 0.55));
		const tipX = C0 - L, notch = Math.min(segDist(x, y, tipX, C0, tipX - 0.012, C0 - 0.02), segDist(x, y, C0, tipX, C0 - 0.02, tipX - 0.012));
		s = Math.max(s, line(arm, 0.0075, px), 0.7 * line(inner, 0.003, px), line(notch, 0.004, px),
			line(diamond(x, y, C0 + 0.012, C0 + 0.012, 0.022, 0.022), 0, px * 30), 0.35 * glow(arm, 0.02));
	}
	// losangos no meio de cada lado
	for (const [cx, cy, rx, ry] of [[0, C0, 0.02, 0.011], [0, -C0, 0.02, 0.011], [C0, 0, 0.011, 0.02], [-C0, 0, 0.011, 0.02]])
		s = Math.max(s, line(diamond(u, v, cx, cy, rx, ry), 0, px * 30));
	return white(s);
}];

// clarão: estrela de oito raios em losango (quatro longos, quatro curtos) e núcleo
TEX.flare = [256, 256, (u, v, px) => {
	const r = Math.hypot(u, v);
	let s = glow(r, 0.03) + 0.35 * glow(r, 0.09);
	for (let k = 0; k < 8; k++) {
		const ang = k * Math.PI / 4, long = k % 2 === 0;
		const [x, y] = rot(u, v, -ang);
		if (x <= 0) continue;
		const len = long ? 0.46 : 0.2, wid = long ? 0.012 : 0.009;
		const t = x / len;
		if (t < 1) s += (1 - t) ** 1.6 * glow(y, wid * (1 - t) + 0.002);
	}
	return white(clamp(s));
}];

// cristal: lasca hexagonal com ponta em cima e embaixo, três faces visíveis
TEX.gem = [128, 128, (u, v, px) => {
	const H = 0.47, W = 0.19, top = 0.2, bot = -0.24;
	const w = v > top ? W * (H - v) / (H - top) : v < bot ? W * (v + H) / (H - Math.abs(bot)) : W;
	if (Math.abs(u) > w + px || v > H || v < -H) return [0, 0, 0, 0];
	const edge = clamp((w - Math.abs(u)) / px + 0.5);
	const f = u / Math.max(w, 1e-4);
	let shade = f < -0.35 ? 0.58 : f > 0.35 ? 0.78 : 0.97;
	if (v > top) shade *= f < 0 ? 0.92 : 1.05; if (v < bot) shade *= 0.8;
	const ridge = 0.25 * (line(Math.abs(f + 0.35) * w, 0.003, px) + line(Math.abs(f - 0.35) * w, 0.003, px));
	const sh = clamp(shade + ridge);
	return [sh, sh, sh, edge];
}];

// brilho suave e máscara da silhueta: funções genéricas, mesmas curvas de antes (o código depende delas)
TEX.glow = [128, 128, (u, v) => white(Math.exp(-Math.pow(Math.hypot(u, v) / 0.155, 1.85)))];
TEX.hole = [128, 128, (u, v) => white(smooth(0.27, 0.475, Math.hypot(u, v)))];
TEX.empty = [32, 32, () => [0, 0, 0, 0]];

// halo: coroa de raios finos e ruído, pico em 0.28
TEX.halo = [256, 256, (u, v) => {
	const [r, a] = polar(u, v);
	const base = glow(r - 0.285, 0.085);
	const n = ringNoise(a, r, 3);
	const rays = 0.5 + 0.5 * Math.cos(a * 36 + 3 * Math.sin(a * 5));
	return white(clamp(base * (0.55 + 0.45 * n) * (0.7 + 0.3 * rays) * 1.1));
}];

// fiapos: fios entrelaçados em volta de 0.30
TEX.wisp = [256, 256, (u, v, px) => {
	const [r, a] = polar(u, v);
	let s = 0;
	for (let k = 0; k < 5; k++) {
		const rr = 0.3 + 0.045 * Math.sin(a * (3 + k) + k * 1.7) + 0.02 * Math.sin(a * (7 + 2 * k) + k);
		s = Math.max(s, (0.5 + 0.5 * ringNoise(a, k, 11 + k, 3)) * glow(r - rr, 0.006 + 0.004 * (k % 2)));
	}
	return white(clamp(s * 0.85 + 0.25 * glow(r - 0.3, 0.08)));
}];

// redemoinho: três braços em espiral logarítmica que afinam
TEX.swirl = [256, 256, (u, v) => {
	const [r, a] = polar(u, v);
	if (r < 0.01) return white(0);
	let s = 0;
	for (let k = 0; k < 3; k++) {
		const phase = a + k * 2 * Math.PI / 3 - Math.log(r / 0.05) * 1.35;
		const d = Math.cos(phase);
		const arm = Math.pow(clamp(d), 6);
		s = Math.max(s, arm);
	}
	const fall = smooth(0.02, 0.1, r) * (1 - smooth(0.33, 0.48, r));
	return white(clamp(s * fall * 0.95 + 0.12 * fall));
}];

// facho: coluna em fuso, núcleo, dois fios laterais
TEX.beam = [64, 256, (u, v, px) => {
	const t = (v + 2) / 4; // 0 embaixo, 1 em cima
	const along = smooth(0, 0.12, t) * (1 - smooth(0.55, 1, t));
	const half = 0.05 + 0.1 * Math.sin(Math.PI * clamp(t * 1.1));
	const core = glow(u, 0.035) + 0.5 * glow(u, half);
	const side = 0.35 * (glow(Math.abs(u) - half * 1.6, 0.012));
	return white(clamp((core + side) * along));
}];

// raio: caminho anguloso do topo ao pé, com dois galhos (semente fixa)
const BOLT = (() => {
	let seed = 7; const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
	const main = [[0.02, 0.98]]; let x = 0.02;
	for (let i = 1; i <= 11; i++) { x = clamp(x + (rnd() - 0.5) * 0.22, -0.28, 0.28); main.push([x, 0.98 - i * 0.176]); }
	const branch = (from, dir, n) => { const p = [main[from]]; let [bx, by] = main[from]; for (let i = 0; i < n; i++) { bx += dir * (0.05 + rnd() * 0.06); by -= 0.1 + rnd() * 0.05; p.push([bx, by]); } return p; };
	return [main, branch(3, 1, 4), branch(6, -1, 3)];
})();
TEX.bolt = [128, 256, (u, v, px) => {
	const y = v; // -1..1 em altura (largura 1)
	let s = 0;
	BOLT.forEach((p, i) => {
		const d = polyDist(u, y, p, false);
		const w = i === 0 ? 0.012 : 0.006;
		s = Math.max(s, line(d, w, px), (i === 0 ? 0.6 : 0.4) * glow(d, 0.05));
	});
	return white(s);
}];

// chama: língua em gota com ponta em S e núcleo mais claro
TEX.flame = [128, 256, (u, v) => {
	const t = (v + 1) / 2; // 0 no pé, 1 no topo
	const sway = 0.07 * Math.sin(t * 5.2) * t;
	const half = 0.3 * Math.pow(Math.sin(Math.PI * clamp(Math.pow(t, 0.62))), 1.1) * (1 - t * 0.35);
	const x = u - sway;
	const body = 1 - smooth(half * 0.55, half + 0.02, Math.abs(x));
	const n = 0.75 + 0.25 * vnoise(u * 8 + 3, v * 6, 4);
	const core = (1 - smooth(half * 0.15, half * 0.55, Math.abs(x))) * (1 - smooth(0.25, 0.7, t));
	const foot = smooth(0, 0.08, t);
	return white(clamp((body * 0.75 * n + core * 0.5) * foot));
}];

// anel do minimapa: furo de 17.5/32 (RING_HOLE), borda escura, relevo e quatro cravos
TEX.node = [32, 32, (u, v, px) => {
	const r = Math.hypot(u, v), hole = 17.5 / 64, outer = 0.445;
	if (r > outer + px * 1.5) return [0, 0, 0, 0];
	const a = clamp((outer - r) / px + 0.5) * clamp((r - hole) / px + 0.5);
	const mid = (hole + outer) / 2, t = (r - hole) / (outer - hole);
	let g = 0.62 + 0.32 * Math.cos((t - 0.35) * Math.PI) * (v > 0 ? 1 : 0.8);
	if (t < 0.12 || t > 0.86) g = 0.08; // contorno escuro (fica preto mesmo tingido)
	let stud = 0;
	for (let k = 0; k < 4; k++) { const [x, y] = rot(u, v, -(Math.PI / 4 + k * Math.PI / 2)); stud = Math.max(stud, line(diamond(x, y, mid, 0, 0.06, 0.04), 0, px * 1.2)); }
	g = mix(g, 1, stud * 0.8);
	return [g, g, g, a];
}];

// ícone e retrato: o Olho de Azaath (amêndoa dourada, íris âmbar, pupila em losango) sobre fundo escuro
function eye(u, v, px, dark) {
	const r = Math.hypot(u, v);
	const bg = dark ? clamp((0.5 - r) / px + 0.5) : 1;
	let col = [0.06, 0.05, 0.07];
	// amêndoa: interseção de dois círculos
	const R = 0.42, off = 0.28;
	const inEye = Math.max(Math.hypot(u, v - off) - R, Math.hypot(u, v + off) - R);
	const edge = line(Math.abs(inEye), dark ? 0.016 : 0.03, px);
	const iris = Math.hypot(u, v) - 0.13;
	const inside = clamp(-inEye / px + 0.5);
	const gold = [0.95, 0.76, 0.32], amber = [1.0, 0.55, 0.12];
	if (inside > 0) col = [mix(col[0], 0.16, inside), mix(col[1], 0.13, inside), mix(col[2], 0.1, inside)];
	const irisA = clamp(-iris / px + 0.5);
	const ig = 1 - r / 0.13;
	col = col.map((c, i) => mix(c, amber[i] * (0.7 + 0.5 * ig), irisA));
	const pupil = clamp(-diamond(u, v, 0, 0, 0.035, 0.1) / (px * 6) + 0.5);
	col = col.map(c => mix(c, 0.02, pupil));
	col = col.map((c, i) => mix(c, gold[i], edge));
	const spark = glow(Math.hypot(u + 0.045, v - 0.05), 0.02);
	col = col.map(c => clamp(c + spark * 0.8));
	if (dark) { const ringD = Math.abs(r - 0.47); col = col.map((c, i) => mix(c, gold[i] * 0.8, line(ringD, 0.012, px))); }
	return [col[0], col[1], col[2], bg];
}
TEX.icon = [32, 32, (u, v, px) => eye(u * 1.08, v * 1.08, px * 1.08, true), 4];
TEX.portrait = [64, 64, (u, v, px) => { const c = eye(u * 1.04, v * 1.04, px * 1.04, true); return [c[0], c[1], c[2], 1]; }, 4];

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
font.text(sheet, 10, 12, "ANTES (Lueur)  x  DEPOIS (Olho de Azaath)", [230, 200, 120]);
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
