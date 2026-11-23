// Olho de Azaath, texturas v2: a cara do Azaath (astrolábio graduado, constelações, cacho de cristais,
// fumaça em fitas, filigrana, runas próprias). Substitui as formas da v1 mantendo as medidas que o
// código usa: anel em 0.37, cometas em 0.44, fileira do selo em 0.30, vértices da figura em 0.46,
// cantos em 0.37, furo do anel do minimapa 17.5/32. glow, hole e empty continuam os da v1.
module.exports = function (TEX, H) {
	const { clamp, smooth, mix, segDist, polyDist, line, glow, union, vnoise, white, polar, rot, ngon, diamond } = H;
	const TAU = Math.PI * 2;
	let seed = 1;
	const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
	const fbm = (x, y, s, o = 5) => { let v = 0, a = 0.5; for (let i = 0; i < o; i++) { v += a * vnoise(x, y, s + i); x *= 2.03; y *= 2.03; a *= 0.5; } return v; };
	// distância angular -> distância em arco no raio r
	const arcDist = (a, step, r) => { const k = Math.round(a / step); return Math.abs(a - k * step) * r; };
	// estrela pequena de constelação: núcleo + cruz fina
	const star = (u, v, x, y, s) => { const dx = u - x, dy = v - y; return clamp(glow(Math.hypot(dx, dy), s) + 0.8 * glow(dx, s * 0.18) * glow(dy, s * 3) + 0.8 * glow(dy, s * 0.18) * glow(dx, s * 3)); };
	// polilinha amostrada de uma curva paramétrica
	const curve = (f, n) => Array.from({ length: n + 1 }, (_, i) => f(i / n));

	// runas do Azaath: alfabeto próprio, 2 a 4 traços numa grade 2x3, com haste
	seed = 4242;
	const GRID = [[-0.5, 1], [0.5, 1], [-0.5, 0], [0.5, 0], [-0.5, -1], [0.5, -1], [0, 1], [0, -1]];
	const RUNES = Array.from({ length: 16 }, () => {
		const segs = [[[0, 1], [0, -1]]];
		const n = 2 + Math.floor(rnd() * 3);
		for (let i = 0; i < n; i++) { const a = GRID[Math.floor(rnd() * GRID.length)], b = GRID[Math.floor(rnd() * GRID.length)]; if (a !== b) segs.push([a, b]); }
		return segs;
	});
	const runeDist = (k, x, y) => Math.min(...RUNES[k % RUNES.length].map(([a, b]) => segDist(x, y, a[0], a[1], b[0], b[1])));

	// ---------------------------------------------------------------- anel: aro de astrolábio graduado
	TEX.ring = [256, 256, (u, v, px) => {
		const [r, a] = polar(u, v);
		const R = 0.37;
		const rim = line(Math.abs(r - R), 0.004, px) + 0.5 * glow(r - R, 0.022);
		const minor = (r < R && r > R - 0.016) ? 0.65 * line(arcDist(a, TAU / 72, r), 0.0016, px) : 0;
		const major = (r < R && r > R - 0.038) ? line(arcDist(a, TAU / 12, r), 0.0032, px) : 0;
		let pip = 0;
		for (let k = 0; k < 12; k++) { const [x, y] = rot(u, v, -k * TAU / 12); pip = Math.max(pip, line(diamond(x, y, R + 0.018, 0, 0.012, 0.007), 0, px * 30)); }
		return white(union(rim, minor, major, pip, 0.18 * glow(r - (R - 0.02), 0.03)));
	}];

	// ---------------------------------------------------------------- cometas: constelações no arco 0.44
	TEX.arcs = [256, 256, (u, v, px) => {
		let s = 0;
		for (const head of [0.25, 0.25 + Math.PI]) {
			const pts = [];
			for (let i = 0; i < 7; i++) { const ang = head - i * 0.17, rr = 0.44 + 0.012 * Math.sin(i * 2.1); pts.push([Math.cos(ang) * rr, Math.sin(ang) * rr, 1 - i / 7]); }
			for (let i = 0; i < pts.length - 1; i++) s = Math.max(s, 0.7 * pts[i][2] * line(segDist(u, v, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]), 0.0028, px));
			pts.forEach(([x, y, w], i) => { s = Math.max(s, (0.4 + 0.6 * w) * star(u, v, x, y, i === 0 ? 0.024 : 0.014)); });
		}
		return white(s);
	}];

	// ---------------------------------------------------------------- selo: mostrador de astrolábio com runas próprias
	TEX.sigil = [256, 256, (u, v, px) => {
		const [r, a] = polar(u, v);
		const rings = union(line(Math.abs(r - 0.33), 0.004, px), line(Math.abs(r - 0.455), 0.0045, px), 0.55 * line(Math.abs(r - 0.472), 0.0015, px),
			0.4 * line(Math.abs(r - 0.355), 0.0012, px));
		// fileira de graduação em 0.30 (os vértices da figura correm sobre ela): longas e curtas alternadas
		const step = TAU / 48, k = Math.round(a / step), long = k % 4 === 0;
		const tick = (r > 0.29 - (long ? 0.012 : 0) && r < 0.315) ? line(Math.abs(a - k * step) * r, long ? 0.003 : 0.0018, px) : 0;
		// runas tangentes entre 0.36 e 0.44, com um ponto entre elas
		let rune = 0;
		const rs = TAU / 16, j = Math.round(a / rs), ang = j * rs;
		const [x, y] = rot(u, v, -(ang - Math.PI / 2));
		const sc = 0.03;
		if (Math.abs(x) < sc && Math.abs(y - 0.405) < sc * 1.6) rune = line(runeDist((j + 16) % 16, x / (sc * 0.7), (y - 0.405) / (sc * 1.15)) * sc * 0.8, 0.0045, px);
		const dot = line(Math.hypot(...rot(u, v, -(ang + rs / 2 - Math.PI / 2)).map((c, i) => i ? c - 0.405 : c)) - 0.004, 0, px);
		return white(union(rings, tick, rune, dot));
	}];

	// ---------------------------------------------------------------- figura: constelação alquímica (pentagrama de estrelas)
	TEX.glyph = [256, 256, (u, v, px) => {
		const P = ngon(5, 0.46);
		const star5 = [P[0], P[2], P[4], P[1], P[3]];
		const lines = Math.max(line(polyDist(u, v, star5, true), 0.004, px), 0.45 * line(polyDist(u, v, P, true), 0.0018, px));
		let nodes = 0;
		for (const p of P) { const d = Math.hypot(u - p[0], v - p[1]); nodes = Math.max(nodes, line(Math.abs(d - 0.032), 0.003, px), star(u, v, p[0], p[1], 0.012)); }
		const r = Math.hypot(u, v);
		const core = Math.max(line(Math.abs(r - 0.075), 0.003, px), star(u, v, 0, 0, 0.016));
		return white(union(lines, nodes, core));
	}];

	// ---------------------------------------------------------------- cantoneiras: filigrana em voluta (cantos em 0.37)
	const C0 = 0.37;
	const VOLUTE = [[C0, C0], [C0 - 0.12, C0], ...curve(t => { const ang = Math.PI / 2 + t * Math.PI * 3, rr = 0.032 * (1 - t * 0.75); return [C0 - 0.12 + Math.cos(ang) * rr - 0, C0 - 0.032 + Math.sin(ang) * rr]; }, 60)];
	TEX.brackets = [256, 256, (u, v, px) => {
		let x = Math.abs(u), y = Math.abs(v);
		const d = Math.min(polyDist(x, y, VOLUTE, false), polyDist(y, x, VOLUTE, false));
		const leaf = Math.min(diamond(x, y, C0 + 0.014, C0 + 0.014, 0.024, 0.024), 0.5);
		const mid = Math.min(Math.hypot(x, y - C0), Math.hypot(x - C0, y));
		return white(union(line(d, 0.0055, px), 0.35 * glow(d, 0.018), line(leaf, 0, px * 30), star(x, y, 0, C0, 0.009) * (x < 0.03 ? 1 : 0), star(x, y, C0, 0, 0.009) * (y < 0.03 ? 1 : 0), 0 * mid));
	}];

	// ---------------------------------------------------------------- clarão: estrela astroide (lados côncavos) com aro
	TEX.flare = [256, 256, (u, v, px) => {
		const p = (Math.pow(Math.abs(u), 2 / 3) + Math.pow(Math.abs(v), 2 / 3));
		const ast = Math.exp(-Math.pow(p / 0.34, 4));
		const [x, y] = rot(u, v, Math.PI / 4);
		const p2 = (Math.pow(Math.abs(x), 2 / 3) + Math.pow(Math.abs(y), 2 / 3));
		const ast2 = 0.5 * Math.exp(-Math.pow(p2 / 0.2, 4));
		const r = Math.hypot(u, v);
		return white(union(ast, ast2, glow(r, 0.04), 0.3 * glow(r - 0.13, 0.008), 0.25 * glow(r, 0.12)));
	}];

	// ---------------------------------------------------------------- cristal: cacho (como o da HUD Azaath)
	function shard(u, v, cx, cy, ang, W, Hh, dark) {
		const [x, y] = rot(u - cx, v - cy, -ang);
		const top = Hh * 0.55, bot = -Hh * 0.7;
		if (y > Hh || y < -Hh) return null;
		const w = y > top ? W * (Hh - y) / (Hh - top) : y < bot ? W * (y + Hh) / (Hh + bot) : W;
		if (Math.abs(x) > w) return null;
		const f = x / Math.max(w, 1e-4);
		let sh = f < -0.3 ? 0.55 : f > 0.3 ? 0.78 : 0.98;
		if (y > top) sh *= f < 0 ? 0.9 : 1.08;
		sh -= 0.25 * Math.abs(Math.abs(f) - 0.3) < 0.03 ? -0.2 : 0;
		return [clamp(sh * dark), clamp((w - Math.abs(x)) / 0.006)];
	}
	TEX.gem = [128, 128, (u, v) => {
		for (const s of [[0, -0.02, 0, 0.12, 0.45, 1], [-0.16, -0.14, 0.5, 0.075, 0.27, 0.8], [0.16, -0.12, -0.45, 0.08, 0.29, 0.85], [-0.07, -0.25, 0.2, 0.05, 0.16, 0.7], [0.08, -0.27, -0.25, 0.05, 0.15, 0.7]]) {
			const c = shard(u, v, ...s); if (c) return [c[0], c[0], c[0], c[1]];
		}
		return [0, 0, 0, 0];
	}];
	// ordem de desenho: o central por cima — refaz com prioridade
	TEX.gem[2] = (u, v) => {
		const list = [[0.16, -0.12, -0.45, 0.08, 0.29, 0.8], [-0.16, -0.14, 0.5, 0.075, 0.27, 0.75], [-0.08, -0.26, 0.25, 0.05, 0.16, 0.65], [0.085, -0.28, -0.3, 0.05, 0.15, 0.65], [0, -0.02, 0, 0.12, 0.45, 1]];
		let out = [0, 0, 0, 0];
		for (const s of list) { const c = shard(u, v, ...s); if (c) { const a = c[1]; out = [mix(out[0], c[0], a), mix(out[1], c[0], a), mix(out[2], c[0], a), Math.max(out[3], a)]; } }
		return out;
	};

	// ---------------------------------------------------------------- halo: nebulosa com poeira de estrelas
	TEX.halo = [256, 256, (u, v) => {
		const [r] = polar(u, v);
		const wu = u + 0.08 * (fbm(u * 4 + 1, v * 4, 7) - 0.5), wv = v + 0.08 * (fbm(u * 4, v * 4 + 3, 9) - 0.5);
		const wr = Math.hypot(wu, wv);
		const smoke = fbm(wu * 7, wv * 7, 21);
		const base = glow(wr - 0.285, 0.09);
		const cell = 48, cx = Math.floor((u + 0.5) * cell), cy = Math.floor((v + 0.5) * cell);
		const h = H.hash(cx, cy, 5);
		const dust = h > 0.86 ? glow(Math.hypot((u + 0.5) * cell - cx - 0.5, (v + 0.5) * cell - cy - 0.5), 0.18) * glow(r - 0.29, 0.12) : 0;
		return white(clamp(base * (0.3 + 1.1 * smoke * smoke * 1.6) + dust));
	}];

	// ---------------------------------------------------------------- fiapos: fitas de fumaça que saem do anel (como no Santuário)
	const RIBBONS = Array.from({ length: 7 }, (_, k) => curve(t => { const a0 = k * TAU / 7; const ang = a0 + t * 1.9 + 0.25 * Math.sin(t * 7 + k); const rr = 0.2 + 0.24 * t; return [Math.cos(ang) * rr, Math.sin(ang) * rr]; }, 48));
	TEX.wisp = [256, 256, (u, v, px) => {
		let s = 0;
		RIBBONS.forEach((pts, k) => {
			let best = 1, bt = 0;
			for (let i = 0; i < pts.length - 1; i++) { const d = segDist(u, v, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]); if (d < best) { best = d; bt = i / (pts.length - 1); } }
			const w = 0.004 + 0.016 * Math.sin(Math.PI * bt);
			const fade = Math.sin(Math.PI * bt);
			s = Math.max(s, fade * (0.55 * glow(best, w) + 0.6 * line(Math.abs(best - w * 0.8), 0.0012, px)));
		});
		const r = Math.hypot(u, v);
		return white(clamp(s + 0.18 * glow(r - 0.3, 0.07) * fbm(u * 9, v * 9, 33)));
	}];

	// ---------------------------------------------------------------- redemoinho: vórtice de fumaça com olho claro
	TEX.swirl = [256, 256, (u, v) => {
		const [r, a] = polar(u, v);
		if (r < 0.005) return white(1);
		const turb = fbm(u * 6, v * 6, 51);
		const phase = a * 2 - Math.log(r / 0.04) * 2.4 + 1.6 * (turb - 0.5);
		const arm = Math.pow(clamp(0.5 + 0.5 * Math.cos(phase)), 2.5);
		const streak = 0.6 + 0.4 * Math.sin(Math.log(r) * 30 + a * 2 + turb * 4);
		const fall = smooth(0.0, 0.08, r) * (1 - smooth(0.3, 0.48, r));
		return white(clamp(arm * streak * fall + 0.9 * glow(r, 0.035)));
	}];

	// ---------------------------------------------------------------- facho: pilar com hélice dupla
	TEX.beam = [64, 256, (u, v) => {
		const t = (v + 2) / 4;
		const along = smooth(0, 0.1, t) * (1 - smooth(0.6, 1, t));
		const ph = t * 26, x1 = 0.17 * Math.sin(ph), depth = 0.5 + 0.5 * Math.cos(ph);
		const strands = (0.35 + 0.65 * depth) * glow(u - x1, 0.022) + (0.35 + 0.65 * (1 - depth)) * glow(u + x1, 0.022);
		const core = glow(u, 0.045) + 0.3 * glow(u, 0.16);
		return white(clamp((core + 0.8 * strands) * along));
	}];

	// ---------------------------------------------------------------- raio: descarga arcana em árvore, com nós acesos
	seed = 99;
	function bolt(x0, y0, x1, y1, depth) {
		let pts = [[x0, y0], [x1, y1]];
		for (let d = 0; d < 5; d++) {
			const n = [pts[0]];
			for (let i = 1; i < pts.length; i++) { const a = pts[i - 1], b = pts[i]; const len = Math.hypot(b[0] - a[0], b[1] - a[1]); n.push([(a[0] + b[0]) / 2 + (rnd() - 0.5) * len * 0.45, (a[1] + b[1]) / 2 + (rnd() - 0.5) * len * 0.1], b); }
			pts = n;
		}
		return pts;
	}
	const MAIN = bolt(0, 0.97, 0.02, -0.97);
	const BR = [];
	for (const [i, dx, dy] of [[8, 0.22, -0.4], [14, -0.2, -0.35], [20, 0.16, -0.3], [24, -0.12, -0.28]]) { const p = MAIN[i]; BR.push(bolt(p[0], p[1], clamp(p[0] + dx, -0.4, 0.4), p[1] + dy)); }
	TEX.bolt = [128, 256, (u, v, px) => {
		let s = 0;
		const dm = polyDist(u, v, MAIN, false);
		s = Math.max(s, line(dm, 0.009, px), 0.55 * glow(dm, 0.045));
		BR.forEach((b, i) => { const d = polyDist(u, v, b, false); s = Math.max(s, (0.8 - i * 0.1) * line(d, 0.004, px), 0.3 * glow(d, 0.03)); });
		for (const i of [8, 14, 20, 24]) s = Math.max(s, star(u, v, MAIN[i][0], MAIN[i][1], 0.022));
		return white(s);
	}];

	// ---------------------------------------------------------------- chama: pincelada com gancho e veio claro
	TEX.flame = [128, 256, (u, v, px) => {
		const t = (v + 1) / 2;
		const curl = 0.16 * Math.pow(t, 2.2) * Math.sin(t * 3.4 + 0.4);
		const half = 0.28 * Math.pow(Math.sin(Math.PI * clamp(Math.pow(t, 0.55))), 1.3) * (1 - t * 0.2);
		const x = u - curl;
		const body = 1 - smooth(half * 0.6, half + 0.015, Math.abs(x));
		const lick = (1 - smooth(0.0, 0.05, Math.hypot(u + 0.16 + 0.04 * t, (t - 0.38) * 0.5))) * 0.7;
		const vein = (t > 0.06 && t < 0.82) ? glow(x, 0.02) * (1 - t) : 0;
		const n = 0.8 + 0.2 * fbm(u * 6, v * 5 - 2, 61, 3);
		return white(clamp((body * 0.7 * n + vein * 0.7 + lick * (1 - smooth(0.2, 0.55, t))) * smooth(0, 0.07, t)));
	}];

	// ---------------------------------------------------------------- anel do minimapa: aro graduado (mesmo furo)
	TEX.node = [32, 32, (u, v, px) => {
		const r = Math.hypot(u, v), hole = 17.5 / 64, outer = 0.445;
		if (r > outer + px * 1.5) return [0, 0, 0, 0];
		const a = clamp((outer - r) / px + 0.5) * clamp((r - hole) / px + 0.5);
		const t = (r - hole) / (outer - hole);
		let g = 0.55 + 0.4 * (v > 0 ? 1 : 0.75) * Math.sin(Math.PI * t);
		if (t < 0.12 || t > 0.88) g = 0.07;
		const ang = Math.atan2(v, u);
		if (t > 0.55 && t < 0.88 && Math.abs(ang - Math.round(ang / (TAU / 8)) * (TAU / 8)) * r < px * 0.6) g = 0.15;
		return [g, g, g, a];
	}];

	// ---------------------------------------------------------------- ícone e retrato: olho com íris de cristal turquesa num astrolábio
	function eye(u, v, px, ticks) {
		const r = Math.hypot(u, v);
		const bg = clamp((0.5 - r) / px + 0.5);
		const gold = [0.93, 0.74, 0.34], teal = [0.25, 0.95, 0.95];
		let col = [0.03, 0.06, 0.08];
		const R = 0.40, off = 0.25;
		const inEye = Math.max(Math.hypot(u, v - off) - R, Math.hypot(u, v + off) - R);
		const inside = clamp(-inEye / px + 0.5);
		col = col.map((c, i) => mix(c, [0.08, 0.12, 0.14][i], inside));
		const ir = Math.hypot(u, v);
		const irisA = clamp((0.135 - ir) / px + 0.5) * inside;
		const facet = 0.75 + 0.25 * Math.cos(Math.atan2(v, u) * 6);
		col = col.map((c, i) => mix(c, teal[i] * (0.55 + 0.6 * (1 - ir / 0.135)) * facet, irisA));
		const pupil = clamp(-diamond(u, v, 0, 0, 0.028, 0.095) / (px * 5) + 0.5);
		col = col.map(c => mix(c, 0.02, pupil));
		col = col.map((c, i) => mix(c, gold[i], line(Math.abs(inEye), 0.016, px)));
		const ring = line(Math.abs(r - 0.465), 0.014, px);
		let tk = 0;
		if (ticks && r > 0.4 && r < 0.45) tk = line(Math.abs(Math.atan2(v, u) - Math.round(Math.atan2(v, u) / (TAU / 24)) * (TAU / 24)) * r, 0.006, px);
		col = col.map((c, i) => mix(c, gold[i] * 0.85, Math.max(ring, tk)));
		const glint = glow(Math.hypot(u + 0.04, v - 0.045), 0.018);
		col = col.map((c, i) => clamp(c + glint * 0.9 + 0.25 * glow(r, 0.2) * teal[i] * inside * (1 - irisA)));
		return [col[0], col[1], col[2], bg];
	}
	TEX.icon = [32, 32, (u, v, px) => eye(u * 1.06, v * 1.06, px * 1.06, false), 4];
	TEX.portrait = [64, 64, (u, v, px) => { const c = eye(u * 1.03, v * 1.03, px * 1.03, true); return [c[0], c[1], c[2], 1]; }, 4];
};
