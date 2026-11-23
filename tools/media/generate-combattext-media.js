// tools/media/generate-combattext-media.js
// Gera as 13 texturas dos ícones de dano estilo Azaath (Media/CombatText/*.tga, TGA 32 bits, 64x64).
// Físicos (Slash, Thrust, Strike): luminância prata/branca para tingimento via SetVertexColor.
// Sangramento (Bleed) e escolas mágicas/híbridas: cores próprias em dois planos facetados.

const fs = require("fs");
const path = require("path");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "CombatText");
fs.mkdirSync(OUT, { recursive: true });

const SIZE = 64;

function clamp01(v) {
  return Math.max(0, Math.min(1, v));
}

// -----------------------------------------------------------------------------
// Mini motor vetorial 2D com supersampling e recortes booleanos
// -----------------------------------------------------------------------------
function createPath() {
  const contours = [];
  let cur = null;

  function ensure(x, y) {
    if (!cur) {
      cur = [[x, y]];
      contours.push(cur);
    }
  }

  return {
    moveTo(x, y) {
      cur = [[x, y]];
      contours.push(cur);
    },
    lineTo(x, y) {
      ensure(x, y);
      cur.push([x, y]);
    },
    quadraticCurveTo(cx, cy, x, y, steps = 20) {
      ensure(x, y);
      const [x0, y0] = cur[cur.length - 1];
      for (let i = 1; i <= steps; i++) {
        const t = i / steps, mt = 1 - t;
        cur.push([
          mt * mt * x0 + 2 * mt * t * cx + t * t * x,
          mt * mt * y0 + 2 * mt * t * cy + t * t * y,
        ]);
      }
    },
    bezierCurveTo(c1x, c1y, c2x, c2y, x, y, steps = 28) {
      ensure(x, y);
      const [x0, y0] = cur[cur.length - 1];
      for (let i = 1; i <= steps; i++) {
        const t = i / steps, mt = 1 - t;
        cur.push([
          mt * mt * mt * x0 + 3 * mt * mt * t * c1x + 3 * mt * t * t * c2x + t * t * t * x,
          mt * mt * mt * y0 + 3 * mt * mt * t * c1y + 3 * mt * t * t * c2y + t * t * t * y,
        ]);
      }
    },
    circle(cx, cy, r, steps = 48) {
      this.moveTo(cx + r, cy);
      for (let i = 1; i <= steps; i++) {
        const a = (i / steps) * Math.PI * 2;
        cur.push([cx + Math.cos(a) * r, cy + Math.sin(a) * r]);
      }
      this.closePath();
    },
    ellipse(cx, cy, rx, ry, rot = 0, steps = 56) {
      const c = Math.cos(rot), s = Math.sin(rot);
      for (let i = 0; i <= steps; i++) {
        const a = (i / steps) * Math.PI * 2;
        const lx = Math.cos(a) * rx, ly = Math.sin(a) * ry;
        const x = cx + lx * c - ly * s;
        const y = cy + lx * s + ly * c;
        if (i === 0) this.moveTo(x, y); else cur.push([x, y]);
      }
      this.closePath();
    },
    closePath() {
      if (cur && cur.length > 1) {
        const [x0, y0] = cur[0];
        const [xn, yn] = cur[cur.length - 1];
        if (Math.hypot(xn - x0, yn - y0) > 1e-6) cur.push([x0, y0]);
      }
      cur = null;
    },
    contours,
  };
}

function pointInContours(contours, x, y) {
  let inside = false;
  for (let c = 0; c < contours.length; c++) {
    const pts = contours[c];
    const n = pts.length;
    for (let i = 0, j = n - 1; i < n; j = i++) {
      const xi = pts[i][0], yi = pts[i][1];
      const xj = pts[j][0], yj = pts[j][1];
      const intersect = ((yi > y) !== (yj > y)) &&
        (x < (xj - xi) * (y - yi) / ((yj - yi) || 1e-12) + xi);
      if (intersect) inside = !inside;
    }
  }
  return inside;
}

function distToSeg(x, y, ax, ay, bx, by) {
  const vx = bx - ax, vy = by - ay;
  const wx = x - ax, wy = y - ay;
  const len2 = vx * vx + vy * vy;
  let t = len2 > 0 ? (wx * vx + wy * vy) / len2 : 0;
  t = Math.max(0, Math.min(1, t));
  return Math.hypot(x - (ax + t * vx), y - (ay + t * vy));
}

function distToContours(contours, x, y) {
  let best = 1e9;
  for (let c = 0; c < contours.length; c++) {
    const pts = contours[c];
    for (let i = 0; i < pts.length - 1; i++) {
      const d = distToSeg(x, y, pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1]);
      if (d < best) best = d;
    }
  }
  return best;
}

function rotPt(x, y, ang) {
  const c = Math.cos(ang), s = Math.sin(ang);
  return [x * c - y * s, x * s + y * c];
}

function addFacetedBlade(ops, ptsLit, ptsDark, litCol, darkCol) {
  const pLit = createPath();
  ptsLit.forEach(([x, y], i) => (i === 0 ? pLit.moveTo(x, y) : pLit.lineTo(x, y)));
  pLit.closePath();

  const pDark = createPath();
  ptsDark.forEach(([x, y], i) => (i === 0 ? pDark.moveTo(x, y) : pDark.lineTo(x, y)));
  pDark.closePath();

  ops.push({ kind: "fill", path: pDark, color: darkCol });
  ops.push({ kind: "fill", path: pLit, color: litCol });
}

// Escreve arquivo TGA 32-bit (BGRA) não comprimido com supersampling 5x5
function writeTGA(filename, ops, ss = 5) {
  const header = Buffer.alloc(18);
  header[2] = 2;
  header.writeUInt16LE(SIZE, 12);
  header.writeUInt16LE(SIZE, 14);
  header[16] = 32;
  header[17] = 8; // origem inferior esquerda

  const data = Buffer.alloc(SIZE * SIZE * 4);

  for (let py = 0; py < SIZE; py++) {
    for (let px = 0; px < SIZE; px++) {
      let r = 0, g = 0, b = 0, sumA = 0;

      for (let sy = 0; sy < ss; sy++) {
        for (let sx = 0; sx < ss; sx++) {
          const u = ((px + (sx + 0.5) / ss) / SIZE) * 2 - 1;
          // No TGA py=0 é a base da textura, então v=+1 na base e v=-1 no topo
          const v = (1 - (py + (sy + 0.5) / ss) / SIZE) * 2 - 1;

          let sa = 0, sr = 255, sg = 255, sb = 255;
          for (let k = 0; k < ops.length; k++) {
            const op = ops[k];
            let hit = false;
            if (op.kind === "fill" || op.kind === "cut") {
              hit = pointInContours(op.path.contours, u, v);
            } else if (op.kind === "stroke" || op.kind === "cutStroke") {
              hit = distToContours(op.path.contours, u, v) <= (op.width * 0.5);
            }
            if (hit) {
              if (op.kind === "cut" || op.kind === "cutStroke") {
                sa = 0;
              } else {
                sa = op.alpha !== undefined ? op.alpha : 1.0;
                const col = op.colorFn ? op.colorFn(u, v) : (op.color || [255, 255, 255]);
                sr = col[0]; sg = col[1]; sb = col[2];
              }
            }
          }
          r += sr * sa;
          g += sg * sa;
          b += sb * sa;
          sumA += sa;
        }
      }

      if (sumA > 0) {
        r /= sumA;
        g /= sumA;
        b /= sumA;
      }
      const avgA = sumA / (ss * ss);

      const idx = (py * SIZE + px) * 4;
      data[idx] = Math.round(Math.min(255, Math.max(0, b)));
      data[idx + 1] = Math.round(Math.min(255, Math.max(0, g)));
      data[idx + 2] = Math.round(Math.min(255, Math.max(0, r)));
      data[idx + 3] = Math.round(clamp01(avgA) * 255);
    }
  }

  fs.writeFileSync(path.join(OUT, filename), Buffer.concat([header, data]));
  console.log("Gerado CombatText/" + filename);
}

// Paletas
const GRAY_LIT  = [255, 255, 255];
const GRAY_MID  = [224, 224, 224];
const GRAY_DARK = [174, 174, 174];

const PAL = {
  bleedLit:   [235, 48, 48],
  bleedDark:  [148, 18, 18],
  fireCore:   [255, 209, 102],
  fireLit:    [255, 120, 31],
  fireDark:   [189, 40, 13],
  frostLit:   [112, 234, 255],
  frostMid:   [72, 195, 235],
  frostDark:  [35, 132, 184],
  natureLit:  [82, 230, 104],
  natureDark: [28, 138, 48],
  boltLit:    [168, 220, 255],
  boltDark:   [51, 120, 220],
  holyLit:    [255, 230, 120],
  holyDark:   [199, 146, 30],
  shadowLit:  [194, 107, 255],
  shadowDark: [99, 31, 168],
  arcaneLit:  [240, 133, 255],
  arcaneDark: [142, 52, 186],
  chaosLit:   [148, 255, 43],
  chaosDark:  [59, 143, 10],
};

// -----------------------------------------------------------------------------
// 1. Slash.tga — Cortante (Espadas, Machados, Alabardas)
// -----------------------------------------------------------------------------
{
  const ops = [];
  const bladeOuter = createPath();
  bladeOuter.moveTo(-0.82, 0.44);
  bladeOuter.bezierCurveTo(-0.56, -0.58, 0.34, -0.88, 0.86, -0.44);
  bladeOuter.bezierCurveTo(0.42, -0.68, -0.34, -0.42, -0.64, 0.42);
  bladeOuter.closePath();

  const bladeSpine = createPath();
  bladeSpine.moveTo(-0.66, 0.42);
  bladeSpine.bezierCurveTo(-0.36, -0.44, 0.40, -0.70, 0.84, -0.44);
  bladeSpine.bezierCurveTo(0.42, -0.54, -0.22, -0.28, -0.48, 0.44);
  bladeSpine.closePath();

  const fuller = createPath();
  fuller.moveTo(-0.56, 0.28);
  fuller.bezierCurveTo(-0.32, -0.42, 0.36, -0.64, 0.74, -0.44);

  const counterOuter = createPath();
  counterOuter.moveTo(-0.46, 0.76);
  counterOuter.bezierCurveTo(0.06, 0.82, 0.62, 0.48, 0.82, -0.06);
  counterOuter.bezierCurveTo(0.52, 0.36, 0.04, 0.60, -0.36, 0.64);
  counterOuter.closePath();

  const counterSpine = createPath();
  counterSpine.moveTo(-0.36, 0.64);
  counterSpine.bezierCurveTo(0.04, 0.60, 0.52, 0.36, 0.82, -0.06);
  counterSpine.bezierCurveTo(0.46, 0.26, 0.02, 0.46, -0.26, 0.52);
  counterSpine.closePath();

  const crossCut = createPath();
  crossCut.moveTo(-0.74, -0.28);
  crossCut.lineTo(0.32, 0.16);
  crossCut.lineTo(0.42, 0.12);
  crossCut.lineTo(-0.62, -0.34);
  crossCut.closePath();

  ops.push({ kind: "fill", path: bladeSpine, color: GRAY_DARK });
  ops.push({ kind: "fill", path: bladeOuter, color: GRAY_LIT });
  ops.push({ kind: "cutStroke", path: fuller, width: 0.024 });
  ops.push({ kind: "fill", path: counterSpine, color: GRAY_DARK });
  ops.push({ kind: "fill", path: counterOuter, color: [246, 246, 246] });
  ops.push({ kind: "fill", path: crossCut, color: [236, 236, 236] });
  writeTGA("Slash.tga", ops);
}

// -----------------------------------------------------------------------------
// 2. Thrust.tga — Perfurante (Lanças, Adagas, Arcos, Bestas, Armas de Fogo)
// -----------------------------------------------------------------------------
{
  const ops = [];
  const ang = -Math.PI * 0.25;
  const T = (x, y) => rotPt(x, y, ang);

  addFacetedBlade(
    ops,
    [T(0, -0.90), T(-0.26, 0.06), T(-0.07, -0.06), T(0, 0.08)],
    [T(0, -0.90), T(0, 0.08), T(0.07, -0.06), T(0.26, 0.06)],
    GRAY_LIT,
    GRAY_DARK
  );

  const collar = createPath();
  collar.moveTo(...T(-0.11, 0.08));
  collar.lineTo(...T(0.11, 0.08));
  collar.lineTo(...T(0.08, 0.19));
  collar.lineTo(...T(-0.08, 0.19));
  collar.closePath();

  const shaft = createPath();
  shaft.moveTo(...T(-0.045, 0.19));
  shaft.lineTo(...T(0.045, 0.19));
  shaft.lineTo(...T(0.035, 0.84));
  shaft.lineTo(...T(-0.035, 0.84));
  shaft.closePath();

  const ridge = createPath();
  ridge.moveTo(...T(0, -0.78));
  ridge.lineTo(...T(0, 0.04));

  const streak1 = createPath(); streak1.moveTo(...T(-0.28, 0.18)); streak1.lineTo(...T(-0.28, 0.70));
  const streak2 = createPath(); streak2.moveTo(...T(0.28, 0.18));  streak2.lineTo(...T(0.28, 0.70));
  const streak3 = createPath(); streak3.moveTo(...T(-0.42, 0.34)); streak3.lineTo(...T(-0.42, 0.62));
  const streak4 = createPath(); streak4.moveTo(...T(0.42, 0.34));  streak4.lineTo(...T(0.42, 0.62));

  ops.push({ kind: "cutStroke", path: ridge, width: 0.022 });
  ops.push({ kind: "fill", path: collar, color: [232, 232, 232] });
  ops.push({ kind: "fill", path: shaft, color: [200, 200, 200] });
  ops.push({ kind: "stroke", path: streak1, width: 0.045, color: [232, 232, 232] });
  ops.push({ kind: "stroke", path: streak2, width: 0.045, color: [192, 192, 192] });
  ops.push({ kind: "stroke", path: streak3, width: 0.032, color: GRAY_DARK });
  ops.push({ kind: "stroke", path: streak4, width: 0.032, color: [154, 154, 154] });
  writeTGA("Thrust.tga", ops);
}

// -----------------------------------------------------------------------------
// 3. Strike.tga — Contundente (Martelos, Maças, Escudos, Cajados, Punhos)
// -----------------------------------------------------------------------------
{
  const ops = [];
  const ang = -Math.PI * 0.22;
  const T = (x, y) => rotPt(x, y, ang);

  const shaft = createPath();
  shaft.moveTo(...T(-0.062, -0.62));
  shaft.lineTo(...T(0.062, -0.62));
  shaft.lineTo(...T(0.068, 0.74));
  shaft.lineTo(...T(0, 0.90));
  shaft.lineTo(...T(-0.068, 0.74));
  shaft.closePath();

  const crown = createPath();
  crown.moveTo(...T(0, -0.84));
  crown.lineTo(...T(0.11, -0.56));
  crown.lineTo(...T(-0.11, -0.56));
  crown.closePath();

  addFacetedBlade(
    ops,
    [T(-0.72, -0.44), T(-0.22, -0.54), T(0.48, -0.56), T(0.62, -0.43), T(0.62, -0.35), T(-0.22, -0.35)],
    [T(-0.72, -0.44), T(-0.22, -0.35), T(0.62, -0.35), T(0.62, -0.22), T(0.48, -0.10), T(-0.22, -0.13), T(-0.36, -0.24)],
    GRAY_LIT,
    GRAY_DARK
  );

  const facePlate = createPath();
  facePlate.moveTo(...T(0.52, -0.57));
  facePlate.lineTo(...T(0.65, -0.45));
  facePlate.lineTo(...T(0.65, -0.20));
  facePlate.lineTo(...T(0.52, -0.09));
  facePlate.closePath();

  const collar = createPath();
  collar.moveTo(...T(-0.14, -0.56));
  collar.lineTo(...T(0.14, -0.56));
  collar.lineTo(...T(0.14, -0.11));
  collar.lineTo(...T(-0.14, -0.11));
  collar.closePath();

  const grip = createPath();
  grip.moveTo(...T(-0.10, 0.54));
  grip.lineTo(...T(0.10, 0.54));
  grip.lineTo(...T(0.10, 0.64));
  grip.lineTo(...T(-0.10, 0.64));
  grip.closePath();

  const sh1 = createPath(); sh1.moveTo(...T(0.75, -0.48)); sh1.lineTo(...T(0.95, -0.60));
  const sh2 = createPath(); sh2.moveTo(...T(0.77, -0.33)); sh2.lineTo(...T(0.98, -0.33));
  const sh3 = createPath(); sh3.moveTo(...T(0.75, -0.18)); sh3.lineTo(...T(0.95, -0.06));

  ops.unshift({ kind: "fill", path: shaft, color: [198, 198, 198] });
  ops.push({ kind: "fill", path: crown, color: [240, 240, 240] });
  ops.push({ kind: "fill", path: facePlate, color: GRAY_LIT });
  ops.push({ kind: "fill", path: collar, color: [215, 215, 215] });
  ops.push({ kind: "fill", path: grip, color: [236, 236, 236] });
  ops.push({ kind: "stroke", path: sh1, width: 0.062, color: [240, 240, 240] });
  ops.push({ kind: "stroke", path: sh2, width: 0.066, color: GRAY_LIT });
  ops.push({ kind: "stroke", path: sh3, width: 0.062, color: [240, 240, 240] });
  writeTGA("Strike.tga", ops);
}

// -----------------------------------------------------------------------------
// 4. Bleed.tga — Sangramento (Carmesim / Sangue Vivo)
// -----------------------------------------------------------------------------
{
  const ops = [];
  const slashes = [
    { dx: -0.28, dy: -0.02, len: 0.54, w: 0.088 },
    { dx:  0.04, dy: -0.14, len: 0.68, w: 0.102 },
    { dx:  0.36, dy: -0.24, len: 0.52, w: 0.084 },
  ];
  for (const s of slashes) {
    const x1 = s.dx - s.len * 0.52, y1 = s.dy - s.len * 0.68;
    const x2 = s.dx + s.len * 0.52, y2 = s.dy + s.len * 0.68;
    const outer = createPath();
    outer.moveTo(x1, y1);
    outer.quadraticCurveTo(s.dx + s.w * 1.15, s.dy - s.w * 0.9, x2, y2);
    outer.quadraticCurveTo(s.dx - s.w * 1.15, s.dy + s.w * 0.9, x1, y1);
    outer.closePath();

    const slit = createPath();
    const sx1 = s.dx - s.len * 0.32, sy1 = s.dy - s.len * 0.42;
    const sx2 = s.dx + s.len * 0.32, sy2 = s.dy + s.len * 0.42;
    slit.moveTo(sx1, sy1);
    slit.quadraticCurveTo(s.dx + s.w * 0.24, s.dy - s.w * 0.20, sx2, sy2);
    slit.quadraticCurveTo(s.dx - s.w * 0.24, s.dy + s.w * 0.20, sx1, sy1);
    slit.closePath();

    ops.push({ kind: "fill", path: outer, color: PAL.bleedLit });
    ops.push({ kind: "cut", path: slit });
  }

  addFacetedBlade(
    ops,
    [[-0.36, 0.22], [-0.48, 0.56], [-0.47, 0.74], [-0.36, 0.84]],
    [[-0.36, 0.22], [-0.36, 0.84], [-0.25, 0.74], [-0.24, 0.56]],
    PAL.bleedLit,
    PAL.bleedDark
  );
  const trail = createPath();
  trail.moveTo(-0.36, 0.14); trail.lineTo(-0.36, 0.32);
  ops.push({ kind: "stroke", path: trail, width: 0.036, color: PAL.bleedDark });

  const drop2 = createPath();
  drop2.moveTo(0.24, 0.38);
  drop2.quadraticCurveTo(0.32, 0.56, 0.24, 0.68);
  drop2.quadraticCurveTo(0.16, 0.56, 0.24, 0.38);
  drop2.closePath();
  ops.push({ kind: "fill", path: drop2, color: PAL.bleedLit });
  writeTGA("Bleed.tga", ops);
}

// -----------------------------------------------------------------------------
// 5. Fire.tga — Fogo (Âmbar / Brasa / Núcleo Dourado)
// -----------------------------------------------------------------------------
{
  const ops = [];
  const outer = createPath();
  outer.moveTo(0.00, -0.88);
  outer.bezierCurveTo(0.24, -0.54, 0.14, -0.26, 0.34, -0.08);
  outer.bezierCurveTo(0.46, -0.28, 0.52, -0.44, 0.52, -0.58);
  outer.bezierCurveTo(0.76, -0.22, 0.74, 0.26, 0.44, 0.62);
  outer.lineTo(0.16, 0.82);
  outer.lineTo(0.00, 0.74);
  outer.lineTo(-0.16, 0.82);
  outer.lineTo(-0.44, 0.62);
  outer.bezierCurveTo(-0.74, 0.26, -0.76, -0.22, -0.52, -0.58);
  outer.bezierCurveTo(-0.52, -0.44, -0.46, -0.28, -0.34, -0.08);
  outer.bezierCurveTo(-0.14, -0.26, -0.24, -0.54, 0.00, -0.88);
  outer.closePath();

  const innerCut = createPath();
  innerCut.moveTo(0.00, -0.36);
  innerCut.bezierCurveTo(0.22, -0.08, 0.34, 0.28, 0.14, 0.58);
  innerCut.lineTo(0.00, 0.64);
  innerCut.lineTo(-0.14, 0.58);
  innerCut.bezierCurveTo(-0.34, 0.28, -0.22, -0.08, 0.00, -0.36);
  innerCut.closePath();

  addFacetedBlade(
    ops,
    [[0.00, -0.22], [-0.14, 0.26], [0.00, 0.54]],
    [[0.00, -0.22], [0.00, 0.54], [0.14, 0.26]],
    PAL.fireCore,
    PAL.fireLit
  );

  for (const [sx, sy, r] of [[-0.30, -0.66, 0.08], [0.34, -0.70, 0.07]]) {
    const sp = createPath();
    sp.moveTo(sx, sy - r * 1.4);
    sp.lineTo(sx + r * 0.7, sy);
    sp.lineTo(sx, sy + r * 1.4);
    sp.lineTo(sx - r * 0.7, sy);
    sp.closePath();
    ops.push({ kind: "fill", path: sp, color: PAL.fireCore });
  }

  ops.unshift({ kind: "cut", path: innerCut });
  ops.unshift({
    kind: "fill",
    path: outer,
    colorFn: (u, v) => {
      const t = clamp01(1 - (v + 1) * 0.5);
      return [
        PAL.fireDark[0] + (PAL.fireLit[0] - PAL.fireDark[0]) * t,
        PAL.fireDark[1] + (PAL.fireLit[1] - PAL.fireDark[1]) * t,
        PAL.fireDark[2] + (PAL.fireLit[2] - PAL.fireDark[2]) * t,
      ];
    },
  });
  writeTGA("Fire.tga", ops);
}

// -----------------------------------------------------------------------------
// 6. Frost.tga — Gelo (Cristal Glacial Azul-Ciano)
// -----------------------------------------------------------------------------
{
  const ops = [];
  for (let i = 0; i < 6; i++) {
    const ang = (i / 6) * Math.PI * 2 - Math.PI / 2;
    const T = (x, y) => rotPt(x, y, ang);

    addFacetedBlade(
      ops,
      [T(0, -0.88), T(-0.08, -0.58), T(-0.045, -0.18), T(0, -0.18)],
      [T(0, -0.88), T(0, -0.18), T(0.045, -0.18), T(0.08, -0.58)],
      PAL.frostLit,
      PAL.frostDark
    );

    const ch = createPath();
    ch.moveTo(...T(-0.22, -0.54));
    ch.lineTo(...T(0, -0.40));
    ch.lineTo(...T(0.22, -0.54));
    ch.lineTo(...T(0.22, -0.46));
    ch.lineTo(...T(0, -0.31));
    ch.lineTo(...T(-0.22, -0.46));
    ch.closePath();
    ops.push({ kind: "fill", path: ch, color: PAL.frostMid });
  }

  const hex = createPath();
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2;
    const x = Math.cos(a) * 0.24, y = Math.sin(a) * 0.24;
    if (i === 0) hex.moveTo(x, y); else hex.lineTo(x, y);
  }
  hex.closePath();
  const hexCut = createPath();
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2;
    const x = Math.cos(a) * 0.14, y = Math.sin(a) * 0.14;
    if (i === 0) hexCut.moveTo(x, y); else hexCut.lineTo(x, y);
  }
  hexCut.closePath();
  const core = createPath();
  for (let i = 0; i < 6; i++) {
    const a = (i / 6) * Math.PI * 2 - Math.PI / 6;
    const x = Math.cos(a) * 0.075, y = Math.sin(a) * 0.075;
    if (i === 0) core.moveTo(x, y); else core.lineTo(x, y);
  }
  core.closePath();

  ops.push({ kind: "fill", path: hex, color: PAL.frostMid });
  ops.push({ kind: "cut", path: hexCut });
  ops.push({ kind: "fill", path: core, color: PAL.frostLit });
  writeTGA("Frost.tga", ops);
}

// -----------------------------------------------------------------------------
// 7. Nature.tga — Natureza / Veneno (Esmeralda / Peçonha)
// -----------------------------------------------------------------------------
{
  const ops = [];
  const ang = Math.PI * 0.24;
  const T = (x, y) => rotPt(x, y, ang);

  const leftHalf = createPath();
  leftHalf.moveTo(...T(0, -0.84));
  leftHalf.bezierCurveTo(...T(-0.46, -0.44), ...T(-0.44, 0.14), ...T(0, 0.44));
  leftHalf.closePath();

  const rightHalf = createPath();
  rightHalf.moveTo(...T(0, -0.84));
  rightHalf.bezierCurveTo(...T(0.46, -0.44), ...T(0.44, 0.14), ...T(0, 0.44));
  rightHalf.closePath();

  const midrib = createPath(); midrib.moveTo(...T(0, -0.68)); midrib.lineTo(...T(0, 0.40));
  const v1 = createPath(); v1.moveTo(...T(0, -0.32)); v1.lineTo(...T(-0.22, -0.48));
  const v2 = createPath(); v2.moveTo(...T(0, -0.10)); v2.lineTo(...T(0.24, -0.26));
  const v3 = createPath(); v3.moveTo(...T(0,  0.12)); v3.lineTo(...T(-0.22, -0.04));

  const stem = createPath();
  stem.moveTo(...T(0, 0.42));
  stem.quadraticCurveTo(...T(-0.04, 0.66), ...T(0.10, 0.84));

  const thorn1 = createPath();
  thorn1.moveTo(...T(-0.02, 0.56));
  thorn1.lineTo(...T(-0.26, 0.48));
  thorn1.lineTo(...T(-0.02, 0.66));
  thorn1.closePath();

  const dx = 0.50, dy = 0.24;
  addFacetedBlade(
    ops,
    [[dx, dy - 0.16], [dx - 0.17, dy + 0.24], [dx - 0.12, dy + 0.42], [dx, dy + 0.48]],
    [[dx, dy - 0.16], [dx, dy + 0.48], [dx + 0.12, dy + 0.42], [dx + 0.17, dy + 0.24]],
    PAL.natureLit,
    PAL.natureDark
  );

  ops.unshift({ kind: "cutStroke", path: v3, width: 0.032 });
  ops.unshift({ kind: "cutStroke", path: v2, width: 0.032 });
  ops.unshift({ kind: "cutStroke", path: v1, width: 0.032 });
  ops.unshift({ kind: "cutStroke", path: midrib, width: 0.036 });
  ops.unshift({ kind: "fill", path: thorn1, color: PAL.natureLit });
  ops.unshift({ kind: "stroke", path: stem, width: 0.072, color: PAL.natureDark });
  ops.unshift({ kind: "fill", path: leftHalf, color: PAL.natureLit });
  ops.unshift({ kind: "fill", path: rightHalf, color: PAL.natureDark });
  writeTGA("Nature.tga", ops);
}

// -----------------------------------------------------------------------------
// 8. Lightning.tga — Raio / Trovão (Azul Elétrico / Núcleo Branco-Ciano)
// -----------------------------------------------------------------------------
{
  const ops = [];
  const boltOuter = createPath();
  boltOuter.moveTo(0.28, -0.88);
  boltOuter.lineTo(-0.44, -0.02);
  boltOuter.lineTo(-0.02, -0.02);
  boltOuter.lineTo(-0.36, 0.88);
  boltOuter.lineTo(0.46, -0.14);
  boltOuter.lineTo(0.06, -0.14);
  boltOuter.closePath();

  const boltCore = createPath();
  boltCore.moveTo(0.24, -0.78);
  boltCore.lineTo(-0.28, -0.08);
  boltCore.lineTo(0.10, -0.08);
  boltCore.lineTo(-0.28, 0.74);
  boltCore.lineTo(0.22, -0.08);
  boltCore.lineTo(-0.14, -0.08);
  boltCore.closePath();

  const fork1 = createPath();
  fork1.moveTo(-0.20, -0.28);
  fork1.lineTo(-0.56, -0.44);
  fork1.lineTo(-0.38, -0.60);
  fork1.lineTo(-0.66, -0.66);

  const fork2 = createPath();
  fork2.moveTo(0.16, 0.22);
  fork2.lineTo(0.54, 0.34);
  fork2.lineTo(0.36, 0.52);
  fork2.lineTo(0.66, 0.60);

  ops.push({ kind: "fill", path: boltOuter, color: PAL.boltDark });
  ops.push({ kind: "fill", path: boltCore, color: PAL.boltLit });
  ops.push({ kind: "stroke", path: fork1, width: 0.048, color: PAL.boltLit });
  ops.push({ kind: "stroke", path: fork2, width: 0.048, color: PAL.boltLit });
  writeTGA("Lightning.tga", ops);
}

// -----------------------------------------------------------------------------
// 9. Holy.tga — Sagrado (Ouro Solar Radiante)
// -----------------------------------------------------------------------------
{
  const ops = [];
  const ring = createPath();
  ring.circle(0, -0.10, 0.44);
  const ringCut = createPath();
  ringCut.circle(0, -0.10, 0.36);

  ops.push({ kind: "fill", path: ring, color: PAL.holyDark });
  ops.push({ kind: "cut", path: ringCut });

  for (const a of [Math.PI * 0.25, Math.PI * 0.75, -Math.PI * 0.25, -Math.PI * 0.75]) {
    const rx = Math.cos(a), ry = Math.sin(a);
    const ray = createPath();
    ray.moveTo(rx * 0.44, -0.10 + ry * 0.44);
    ray.lineTo(rx * 0.66 - ry * 0.03, -0.10 + ry * 0.66 + rx * 0.03);
    ray.lineTo(rx * 0.74, -0.10 + ry * 0.74);
    ray.lineTo(rx * 0.66 + ry * 0.03, -0.10 + ry * 0.66 - rx * 0.03);
    ray.closePath();
    ops.push({ kind: "fill", path: ray, color: PAL.holyDark });
  }

  addFacetedBlade(ops, [[0, -0.90], [-0.14, -0.66], [-0.08, -0.10], [0, -0.10]], [[0, -0.90], [0, -0.10], [0.08, -0.10], [0.14, -0.66]], PAL.holyLit, PAL.holyDark);
  addFacetedBlade(ops, [[0, -0.10], [-0.08, -0.10], [-0.13, 0.64], [0, 0.90]], [[0, -0.10], [0, 0.90], [0.13, 0.64], [0.08, -0.10]], PAL.holyLit, PAL.holyDark);
  addFacetedBlade(ops, [[-0.78, -0.10], [-0.56, -0.22], [-0.02, -0.18], [-0.02, -0.10]], [[-0.78, -0.10], [-0.02, -0.10], [-0.02, -0.02], [-0.56, 0.02]], PAL.holyLit, PAL.holyDark);
  addFacetedBlade(ops, [[0.02, -0.10], [0.02, -0.18], [0.56, -0.22], [0.78, -0.10]], [[0.02, -0.10], [0.78, -0.10], [0.56, 0.02], [0.02, -0.02]], PAL.holyLit, PAL.holyDark);

  const cCut = createPath();
  cCut.moveTo(0, -0.24); cCut.lineTo(0.14, -0.10); cCut.lineTo(0, 0.04); cCut.lineTo(-0.14, -0.10); cCut.closePath();
  const gem = createPath();
  gem.moveTo(0, -0.18); gem.lineTo(0.08, -0.10); gem.lineTo(0, -0.02); gem.lineTo(-0.08, -0.10); gem.closePath();
  ops.push({ kind: "cut", path: cCut });
  ops.push({ kind: "fill", path: gem, color: [255, 248, 195] });
  writeTGA("Holy.tga", ops);
}

// -----------------------------------------------------------------------------
// 10. Shadow.tga — Sombra (Violeta Abissal / Ametista)
// -----------------------------------------------------------------------------
{
  const ops = [];
  const crescentLit = createPath();
  crescentLit.moveTo(0.28, -0.86);
  crescentLit.bezierCurveTo(-0.84, -0.82, -0.92, 0.76, 0.28, 0.86);
  crescentLit.bezierCurveTo(-0.48, 0.62, -0.50, -0.60, 0.28, -0.86);
  crescentLit.closePath();

  const crescentBevel = createPath();
  crescentBevel.moveTo(0.28, -0.86);
  crescentBevel.bezierCurveTo(-0.50, -0.60, -0.48, 0.62, 0.28, 0.86);
  crescentBevel.bezierCurveTo(-0.28, 0.54, -0.30, -0.50, 0.28, -0.86);
  crescentBevel.closePath();

  addFacetedBlade(
    ops,
    [[0.26, -0.52], [-0.02, 0.00], [0.26, 0.52]],
    [[0.26, -0.52], [0.54, 0.00], [0.26, 0.52]],
    PAL.shadowLit,
    PAL.shadowDark
  );

  const slit = createPath();
  slit.moveTo(0.26, -0.30);
  slit.lineTo(0.34, 0.00);
  slit.lineTo(0.26, 0.30);
  slit.lineTo(0.18, 0.00);
  slit.closePath();

  const w1 = createPath();
  w1.moveTo(0.42, -0.68);
  w1.bezierCurveTo(0.84, -0.54, 0.84, -0.20, 0.68, -0.04);
  w1.bezierCurveTo(0.72, -0.24, 0.62, -0.46, 0.42, -0.68);
  w1.closePath();

  const w2 = createPath();
  w2.moveTo(0.42, 0.68);
  w2.bezierCurveTo(0.84, 0.54, 0.84, 0.20, 0.68, 0.04);
  w2.bezierCurveTo(0.72, 0.24, 0.62, 0.46, 0.42, 0.68);
  w2.closePath();

  ops.unshift({ kind: "fill", path: crescentBevel, color: PAL.shadowDark });
  ops.unshift({ kind: "fill", path: crescentLit, color: PAL.shadowLit });
  ops.push({ kind: "cut", path: slit });
  ops.push({ kind: "fill", path: w1, color: PAL.shadowDark });
  ops.push({ kind: "fill", path: w2, color: PAL.shadowDark });
  writeTGA("Shadow.tga", ops);
}

// -----------------------------------------------------------------------------
// 11. Arcane.tga — Arcano (Magenta Astral / Runa Estelar)
// -----------------------------------------------------------------------------
{
  const ops = [];
  const outerCircle = createPath();
  outerCircle.circle(0, 0, 0.58);
  const orbit = createPath();
  orbit.ellipse(0, 0, 0.80, 0.28, -0.52);

  ops.push({ kind: "stroke", path: outerCircle, width: 0.050, color: PAL.arcaneDark });
  ops.push({ kind: "stroke", path: orbit, width: 0.068, color: PAL.arcaneDark });

  for (const a of [Math.PI * 0.25, Math.PI * 0.75, -Math.PI * 0.25, -Math.PI * 0.75]) {
    const tick = createPath();
    tick.moveTo(Math.cos(a) * 0.50, Math.sin(a) * 0.50);
    tick.lineTo(Math.cos(a) * 0.66, Math.sin(a) * 0.66);
    ops.push({ kind: "stroke", path: tick, width: 0.042, color: PAL.arcaneLit });
  }

  addFacetedBlade(ops, [[0, -0.88], [-0.14, -0.14], [0, 0]], [[0, -0.88], [0, 0], [0.14, -0.14]], PAL.arcaneLit, PAL.arcaneDark);
  addFacetedBlade(ops, [[0, 0], [-0.14, 0.14], [0, 0.88]], [[0, 0], [0, 0.88], [0.14, 0.14]], PAL.arcaneLit, PAL.arcaneDark);
  addFacetedBlade(ops, [[-0.88, 0], [-0.14, -0.14], [0, 0]], [[-0.88, 0], [0, 0], [-0.14, 0.14]], PAL.arcaneLit, PAL.arcaneDark);
  addFacetedBlade(ops, [[0, 0], [0.14, -0.14], [0.88, 0]], [[0, 0], [0.88, 0], [0.14, 0.14]], PAL.arcaneLit, PAL.arcaneDark);

  const cut = createPath();
  cut.moveTo(0, -0.19); cut.lineTo(0.19, 0); cut.lineTo(0, 0.19); cut.lineTo(-0.19, 0); cut.closePath();
  const core = createPath();
  core.moveTo(0, -0.09); core.lineTo(0.09, 0); core.lineTo(0, 0.09); core.lineTo(-0.09, 0); core.closePath();

  const [sx, sy] = rotPt(0.72, -0.14, -0.52);
  const sat = createPath();
  sat.moveTo(sx, sy - 0.08); sat.lineTo(sx + 0.08, sy); sat.lineTo(sx, sy + 0.08); sat.lineTo(sx - 0.08, sy); sat.closePath();

  ops.push({ kind: "cut", path: cut });
  ops.push({ kind: "fill", path: core, color: [255, 220, 255] });
  ops.push({ kind: "fill", path: sat, color: [255, 220, 255] });
  writeTGA("Arcane.tga", ops);
}

// -----------------------------------------------------------------------------
// 12. Frostfire.tga — Fogo-Gelo (Bicolor Real: Chama Laranja + Cristal Ciano)
// -----------------------------------------------------------------------------
{
  const ops = [];
  const fireOuter = createPath();
  fireOuter.moveTo(-0.05, -0.86);
  fireOuter.bezierCurveTo(-0.34, -0.54, -0.20, -0.26, -0.36, -0.10);
  fireOuter.bezierCurveTo(-0.48, -0.28, -0.54, -0.44, -0.52, -0.58);
  fireOuter.bezierCurveTo(-0.78, -0.20, -0.72, 0.34, -0.36, 0.68);
  fireOuter.lineTo(-0.05, 0.84);
  fireOuter.lineTo(-0.05, 0.18);
  fireOuter.lineTo(-0.20, 0.00);
  fireOuter.lineTo(-0.05, -0.18);
  fireOuter.closePath();

  const fireInner = createPath();
  fireInner.moveTo(-0.12, -0.42);
  fireInner.bezierCurveTo(-0.42, -0.10, -0.42, 0.36, -0.12, 0.62);
  fireInner.lineTo(-0.12, 0.18);
  fireInner.lineTo(-0.26, 0.00);
  fireInner.lineTo(-0.12, -0.18);
  fireInner.closePath();

  const frostDark = createPath();
  frostDark.moveTo(0.05, -0.84);
  frostDark.lineTo(0.18, -0.54);
  frostDark.lineTo(0.10, -0.38);
  frostDark.lineTo(0.54, -0.58);
  frostDark.lineTo(0.42, -0.22);
  frostDark.lineTo(0.84, 0.00);
  frostDark.lineTo(0.42, 0.22);
  frostDark.lineTo(0.54, 0.58);
  frostDark.lineTo(0.10, 0.38);
  frostDark.lineTo(0.18, 0.54);
  frostDark.lineTo(0.05, 0.84);
  frostDark.lineTo(0.05, 0.18);
  frostDark.lineTo(0.20, 0.00);
  frostDark.lineTo(0.05, -0.18);
  frostDark.closePath();

  const frostLit = createPath();
  frostLit.moveTo(0.05, -0.84);
  frostLit.lineTo(0.18, -0.54);
  frostLit.lineTo(0.10, -0.38);
  frostLit.lineTo(0.54, -0.58);
  frostLit.lineTo(0.42, -0.22);
  frostLit.lineTo(0.84, 0.00);
  frostLit.lineTo(0.20, 0.00);
  frostLit.lineTo(0.05, -0.18);
  frostLit.closePath();

  const nexus = createPath();
  nexus.moveTo(0, -0.14); nexus.lineTo(0.12, 0); nexus.lineTo(0, 0.14); nexus.lineTo(-0.12, 0); nexus.closePath();

  ops.push({ kind: "fill", path: fireOuter, color: PAL.fireDark });
  ops.push({ kind: "fill", path: fireInner, color: PAL.fireLit });
  ops.push({ kind: "fill", path: frostDark, color: PAL.frostDark });
  ops.push({ kind: "fill", path: frostLit, color: PAL.frostLit });
  ops.push({ kind: "fill", path: nexus, color: [230, 249, 255] });
  writeTGA("Frostfire.tga", ops);
}

// -----------------------------------------------------------------------------
// 13. Chaos.tga — Caos / Vil (Verde Vil Incandescente)
// -----------------------------------------------------------------------------
{
  const ops = [];
  const ring = createPath();
  ring.circle(0, 0, 0.44);
  const ringCut = createPath();
  ringCut.circle(0, 0, 0.34);
  ops.push({ kind: "fill", path: ring, color: PAL.chaosDark });
  ops.push({ kind: "cut", path: ringCut });

  for (let i = 0; i < 8; i++) {
    const ang = (i / 8) * Math.PI * 2 - Math.PI / 2;
    const T = (x, y) => rotPt(x, y, ang);
    const len = (i % 2 === 0) ? 0.88 : 0.68;
    const w = (i % 2 === 0) ? 0.115 : 0.082;
    const base = 0.24;
    addFacetedBlade(
      ops,
      [T(0, -len), T(-w, -len * 0.56), T(-w * 0.55, -base), T(0, -base)],
      [T(0, -len), T(0, -base), T(w * 0.55, -base), T(w, -len * 0.56)],
      PAL.chaosLit,
      PAL.chaosDark
    );
  }

  const core = createPath();
  core.moveTo(0, -0.22); core.lineTo(0.18, 0); core.lineTo(0, 0.22); core.lineTo(-0.18, 0); core.closePath();
  const slit = createPath();
  slit.moveTo(0, -0.14); slit.lineTo(0.05, 0); slit.lineTo(0, 0.14); slit.lineTo(-0.05, 0); slit.closePath();

  ops.push({ kind: "fill", path: core, color: PAL.chaosLit });
  ops.push({ kind: "cut", path: slit });
  writeTGA("Chaos.tga", ops);
}
