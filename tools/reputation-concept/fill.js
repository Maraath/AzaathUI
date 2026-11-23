// Preenchimento multiescala (copiado de tools/sanctuary-concept/gen.js)
function fill(px, mask, w, h) {
  const levels = [{ w, h, px: Float32Array.from(px), m: Uint8Array.from(mask) }];
  while (levels[levels.length - 1].w > 8 && levels[levels.length - 1].h > 8) {
    const L = levels[levels.length - 1];
    const nw = Math.ceil(L.w / 2), nh = Math.ceil(L.h / 2);
    const npx = new Float32Array(nw * nh * 4), nm = new Uint8Array(nw * nh);
    for (let y = 0; y < nh; y++) for (let x = 0; x < nw; x++) {
      let s = [0, 0, 0], c = 0;
      for (let dy = 0; dy < 2; dy++) for (let dx = 0; dx < 2; dx++) {
        const xx = Math.min(L.w - 1, 2 * x + dx), yy = Math.min(L.h - 1, 2 * y + dy), i = yy * L.w + xx;
        if (!L.m[i]) { s[0] += L.px[i * 4]; s[1] += L.px[i * 4 + 1]; s[2] += L.px[i * 4 + 2]; c++; }
      }
      const o = y * nw + x;
      if (c) { npx[o * 4] = s[0] / c; npx[o * 4 + 1] = s[1] / c; npx[o * 4 + 2] = s[2] / c; } else nm[o] = 1;
      npx[o * 4 + 3] = 255;
    }
    levels.push({ w: nw, h: nh, px: npx, m: nm });
  }
  const relax = (L, iters) => {
    const idx = [];
    for (let i = 0; i < L.w * L.h; i++) if (L.m[i]) idx.push(i);
    for (let it = 0; it < iters; it++) for (const i of idx) {
      const x = i % L.w, y = (i / L.w) | 0;
      let s0 = 0, s1 = 0, s2 = 0, c = 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const xx = x + dx, yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= L.w || yy >= L.h) continue;
        const j = (yy * L.w + xx) * 4; s0 += L.px[j]; s1 += L.px[j + 1]; s2 += L.px[j + 2]; c++;
      }
      L.px[i * 4] = s0 / c; L.px[i * 4 + 1] = s1 / c; L.px[i * 4 + 2] = s2 / c;
    }
  };
  relax(levels[levels.length - 1], 400);
  for (let k = levels.length - 2; k >= 0; k--) {
    const L = levels[k], C = levels[k + 1];
    for (let i = 0; i < L.w * L.h; i++) if (L.m[i]) {
      const x = i % L.w, y = (i / L.w) | 0;
      const fx = Math.min(C.w - 1, Math.max(0, (x + 0.5) / 2 - 0.5)), fy = Math.min(C.h - 1, Math.max(0, (y + 0.5) / 2 - 0.5));
      const x0 = Math.floor(fx), y0 = Math.floor(fy), x1 = Math.min(C.w - 1, x0 + 1), y1 = Math.min(C.h - 1, y0 + 1), tx = fx - x0, ty = fy - y0;
      for (let ch = 0; ch < 3; ch++) {
        const v = (C.px[(y0 * C.w + x0) * 4 + ch] * (1 - tx) + C.px[(y0 * C.w + x1) * 4 + ch] * tx) * (1 - ty)
                + (C.px[(y1 * C.w + x0) * 4 + ch] * (1 - tx) + C.px[(y1 * C.w + x1) * 4 + ch] * tx) * ty;
        L.px[i * 4 + ch] = v;
      }
    }
    relax(L, k === 0 ? 60 : 30);
  }
  return levels[0].px;
}
module.exports = { fill };
