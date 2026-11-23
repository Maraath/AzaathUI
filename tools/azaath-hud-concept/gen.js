// Gera as texturas da nova skin "Azaath" (arte de conceito 1024x571)
// em AzaathUI/Media/AzaathCrystal/*.tga e AzaathUI/Modules/AzaathCrystalLayoutData.lua.
// Uso: node tools/azaath-hud-concept/gen.js
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("../grimoire-concept/png");

const ROOT = path.join(__dirname, "..", "..", "AzaathUI");
const OUT = path.join(ROOT, "Media", "AzaathCrystal");
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(OUT, { recursive: true });
fs.mkdirSync(PREV, { recursive: true });

const src = readPNG(path.join(__dirname, "concept.png"));
const W = src.w, H = src.h;
const clone = (im) => ({ w: im.w, h: im.h, px: Float32Array.from(im.px) });
const C = clone(src);

const get = (im, x, y) => {
  x = Math.max(0, Math.min(im.w - 1, x));
  y = Math.max(0, Math.min(im.h - 1, y));
  const o = (y * im.w + x) * 4;
  return [im.px[o], im.px[o + 1], im.px[o + 2], im.px[o + 3]];
};
const set = (im, x, y, c) => {
  if (x < 0 || y < 0 || x >= im.w || y >= im.h) return;
  const o = (y * im.w + x) * 4;
  im.px[o] = c[0];
  im.px[o + 1] = c[1];
  im.px[o + 2] = c[2];
  if (c.length > 3) im.px[o + 3] = c[3];
};
const lum = (c) => 0.3 * c[0] + 0.59 * c[1] + 0.11 * c[2];
const clamp = (v, a = 0, b = 1) => Math.max(a, Math.min(b, v));
const smooth = (e0, e1, v) => {
  const t = clamp((v - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
};

function inpaint(im, x0, y0, x1, y1, maskFn, iters = 1200) {
  const w = x1 - x0 + 1, h = y1 - y0 + 1, m = new Uint8Array(w * h);
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) m[j * w + i] = maskFn(x0 + i, y0 + j) ? 1 : 0;
  const md = Uint8Array.from(m);
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (m[j * w + i])
    for (let dj = -1; dj <= 1; dj++) for (let di = -1; di <= 1; di++) {
      const ii = i + di, jj = j + dj;
      if (ii >= 0 && jj >= 0 && ii < w && jj < h) md[jj * w + ii] = 1;
    }
  let acc = [0, 0, 0], n = 0;
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (!md[j * w + i]) {
    const c = get(im, x0 + i, y0 + j);
    acc[0] += c[0]; acc[1] += c[1]; acc[2] += c[2]; n++;
  }
  const mean = n ? acc.map((v) => v / n) : [20, 18, 16];
  for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (md[j * w + i]) set(im, x0 + i, y0 + j, mean);
  for (let it = 0; it < iters; it++) for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
    if (!md[j * w + i]) continue;
    const x = x0 + i, y = y0 + j, s = [0, 0, 0];
    let c = 0;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const xx = x + dx, yy = y + dy;
      if (xx < x0 - 1 || yy < y0 - 1 || xx > x1 + 1 || yy > y1 + 1) continue;
      const p = get(im, xx, yy);
      s[0] += p[0]; s[1] += p[1]; s[2] += p[2]; c++;
    }
    set(im, x, y, s.map((v) => v / c));
  }
}

// ---------------------------------------------------------------------------
// Geometria exata medida no conceito (1024x571)
// ---------------------------------------------------------------------------
const HUD = { x: 24, y: 122, w: 976, h: 408 };
const LX = [0, 1, 2, 3, 4, 5].map((i) => Math.round(81 + 40.7 * i));
const LY = [273, 331];
const LR = 19; // raio interno da asa esquerda (diametro 38)
const RX = [0, 1, 2, 3, 4, 5].map((i) => Math.round(694 + 51.4 * i));
const RY = [254, 331];
const RR = 24; // raio interno da asa direita (diametro 48)
const TABS = [
  { x: 62, y: 215, w: 35, h: 31 },
  { x: 101, y: 215, w: 35, h: 31 },
];
const LEVEL = { cx: 508, cy: 350 };
const HEALTH = { x: 158, y: 370, w: 226, h: 66 };
const POWER = { x: 624, y: 370, w: 226, h: 66 };
const XP = { x: 366, y: 440, w: 278, h: 66 };

// ---------------------------------------------------------------------------
// 1. Esvaziar os 12 slots circulares da asa esquerda (copia do slot 3 vazio)
// ---------------------------------------------------------------------------
{
  const snap = clone(C);
  const sx = LX[2], sy = LY[0];
  for (const y of LY) for (const x of LX) {
    for (let dy = -20; dy <= 20; dy++) for (let dx = -20; dx <= 20; dx++) {
      if (dx * dx + dy * dy <= 20 * 20) {
        set(C, x + dx, y + dy, get(snap, sx + dx, sy + dy));
      }
    }
  }
  // Apagar caixinhas de tecla da asa esquerda (abaixo de LY[1]) preservando o bronze
  for (let i = 0; i < 6; i++) {
    inpaint(C, LX[i] - 11, LY[1] + 21, LX[i] + 11, LY[1] + 38, (x, y) => lum(get(C, x, y)) > 85, 400);
  }
}

// ---------------------------------------------------------------------------
// 2. Esvaziar os 12 slots circulares da asa direita e extrair anel de Proc
// ---------------------------------------------------------------------------
{
  const snap = clone(C);
  const sx = RX[5], sy = RY[1];
  for (const y of RY) for (const x of RX) {
    for (let dy = -26; dy <= 26; dy++) for (let dx = -26; dx <= 26; dx++) {
      if (dx * dx + dy * dy <= 26 * 26) {
        set(C, x + dx, y + dy, get(snap, sx + dx, sy + dy));
      }
    }
  }

  // Limpar o brilho ciano do anel de Proc estático ao redor de (RX[2], RY[0]) e (RX[3], RY[1])
  // copiando a borda limpa de um slot adjacente sem proc (RX[1], RY[0] e RX[4], RY[1])
  const copyRingRim = (sx, sy, dx, dy, rIn, rOut) => {
    for (let j = -rOut; j <= rOut; j++) for (let i = -rOut; i <= rOut; i++) {
      const d = Math.hypot(i, j);
      if (d < rIn || d > rOut) continue;
      const p = get(C, dx + i, dy + j);
      const cyan = Math.min(p[1], p[2]) - p[0];
      if (cyan > 8 || lum(p) > 80) {
        const clean = get(C, sx + i, sy + j);
        const k = clamp((cyan - 8) / 40 + (lum(p) - 80) / 80);
        set(C, dx + i, dy + j, [
          p[0] * (1 - k) + clean[0] * k,
          p[1] * (1 - k) + clean[1] * k,
          p[2] * (1 - k) + clean[2] * k,
        ]);
      }
    }
  };
  copyRingRim(RX[1], RY[0], RX[2], RY[0], 24, 44);
  copyRingRim(RX[4], RY[1], RX[3], RY[1], 24, 44);

  // Apagar caixinhas de tecla da asa direita (1..6 entre fileiras, 7..= abaixo da 2ª fileira)
  for (let i = 0; i < 6; i++) {
    inpaint(C, RX[i] - 11, RY[0] + 25, RX[i] + 11, RY[0] + 42, (x, y) => lum(get(C, x, y)) > 85, 400);
    inpaint(C, RX[i] - 11, RY[1] + 25, RX[i] + 11, RY[1] + 42, (x, y) => lum(get(C, x, y)) > 85, 400);
  }
}

// ---------------------------------------------------------------------------
// 3. Extrair anel de Proc (128x128) a partir de src - C ao redor de (RX[2], RY[0])
// ---------------------------------------------------------------------------
{
  const n = 128, r = 64, im = I.create(n, n);
  const cx = RX[2], cy = RY[0];
  for (let j = 0; j < n; j++) for (let i = 0; i < n; i++) {
    const x = cx - r + i, y = cy - r + j;
    const d = Math.hypot(i - r, j - r);
    const fade = 1 - smooth(40, 62, d);
    const a = get(src, x, y), b = get(C, x, y);
    const dr = Math.max(0, a[0] - b[0]) * fade;
    const dg = Math.max(0, a[1] - b[1]) * fade;
    const db = Math.max(0, a[2] - b[2]) * fade;
    const al = clamp(Math.max(dr, dg, db) / 255);
    set(im, i, j, [dr, dg, db, al * 255]);
  }
  I.writeTGA(path.join(OUT, "Proc.tga"), im);
}

// ---------------------------------------------------------------------------
// 4. Apagar o nível "21" no medalhão central (cx=508, cy=350)
// ---------------------------------------------------------------------------
inpaint(C, LEVEL.cx - 18, LEVEL.cy - 18, LEVEL.cx + 18, LEVEL.cy + 18, (x, y) => {
  const d = Math.hypot(x - LEVEL.cx, y - LEVEL.cy);
  return d <= 14 && lum(get(C, x, y)) > 65;
}, 900);

// ---------------------------------------------------------------------------
// 5. Extrair abas CF1 / CF2 e limpar as letras das abas no fundo
// ---------------------------------------------------------------------------
{
  const writeTab = (tab, name) => {
    const im = I.crop(src, tab.x, tab.y, tab.w, tab.h);
    // arredonda levemente os cantos externos
    I.writeTGA(path.join(OUT, name), im);
  };
  writeTab(TABS[0], "Tab1.tga");
  writeTab(TABS[1], "Tab2.tga");
  // Versões ativa/inativa (dourada vs aço) a partir de Tab1/Tab2
  const t1 = I.crop(src, TABS[0].x, TABS[0].y, TABS[0].w, TABS[0].h);
  const t2 = I.crop(src, TABS[1].x, TABS[1].y, TABS[1].w, TABS[1].h);
  I.writeTGA(path.join(OUT, "TabGold.tga"), t1);
  I.writeTGA(path.join(OUT, "TabSteel.tga"), t2);
  // Apagar texto CF1 / CF2 do fundo da HUD
  for (const t of TABS) {
    inpaint(C, t.x + 5, t.y + 5, t.x + t.w - 6, t.y + t.h - 10, (x, y) => lum(get(C, x, y)) > 110, 500);
  }
}

// ---------------------------------------------------------------------------
// 6. Barra de Vida (HealthFill.tga) + limpar tubo de vidro na HUD
// ---------------------------------------------------------------------------
{
  const im = I.create(HEALTH.w, HEALTH.h);
  for (let j = 0; j < HEALTH.h; j++) for (let i = 0; i < HEALTH.w; i++) {
    const x = HEALTH.x + i, y = HEALTH.y + j;
    const p = get(src, x, y);
    // líquido carmim: R bem maior que G e B
    const red = p[0] - Math.max(p[1], p[2] * 0.9);
    const m = smooth(18, 55, red);
    if (m > 0.02) {
      set(im, i, j, [p[0], p[1], p[2], m * 255]);
      // esvazia o tubo no fundo preservando brilho de vidro sutil
      const bg = [18 + lum(p) * 0.08, 16 + lum(p) * 0.06, 20 + lum(p) * 0.08];
      set(C, x, y, [
        p[0] * (1 - m) + bg[0] * m,
        p[1] * (1 - m) + bg[1] * m,
        p[2] * (1 - m) + bg[2] * m,
      ]);
    }
  }
  I.writeTGA(path.join(OUT, "HealthFill.tga"), im);
  I.writePNG(path.join(PREV, "health_fill.png"), im);
}

// ---------------------------------------------------------------------------
// 7. Barra de Recurso (PowerFill.tga + Flame.tga + PowerSpark.tga)
// ---------------------------------------------------------------------------
{
  const im = I.create(POWER.w, POWER.h);
  for (let j = 0; j < POWER.h; j++) for (let i = 0; i < POWER.w; i++) {
    const x = POWER.x + i, y = POWER.y + j;
    const p = get(src, x, y);
    const fire = (p[0] - p[2]) * 0.7 + (p[1] - p[2]) * 0.3;
    const m = smooth(28, 78, fire);
    if (m > 0.02) {
      set(im, i, j, [p[0], p[1], p[2], m * 255]);
      const bg = [18 + lum(p) * 0.08, 16 + lum(p) * 0.07, 18 + lum(p) * 0.06];
      set(C, x, y, [
        p[0] * (1 - m) + bg[0] * m,
        p[1] * (1 - m) + bg[1] * m,
        p[2] * (1 - m) + bg[2] * m,
      ]);
    }
  }
  I.writeTGA(path.join(OUT, "PowerFill.tga"), im);
  I.writePNG(path.join(PREV, "power_fill.png"), im);

  // Flame.tga (128x32 faixa de chama horizontal repetível)
  const fl = I.create(128, 32);
  for (let j = 0; j < 32; j++) for (let i = 0; i < 128; i++) {
    const sx = POWER.x + 38 + (i % 128);
    const sy = POWER.y + 6 + Math.floor(j * 0.8);
    const p = get(src, sx, sy);
    const v = clamp((lum(p) - 60) / 180);
    set(fl, i, j, [255 * v, 175 * v, 65 * v, v * 255]);
  }
  I.writeTGA(path.join(OUT, "Flame.tga"), fl);

  // PowerSpark.tga (32x32 brilho circular suave)
  const sp = I.create(32, 32);
  for (let j = 0; j < 32; j++) for (let i = 0; i < 32; i++) {
    const d = Math.hypot(i - 15.5, j - 15.5) / 15.5;
    const v = Math.pow(clamp(1 - d), 2.2);
    set(sp, i, j, [255 * v, 210 * v, 110 * v, v * 255]);
  }
  I.writeTGA(path.join(OUT, "PowerSpark.tga"), sp);
}

// ---------------------------------------------------------------------------
// 8. Barra de XP (XPFill.tga + XPSpark.tga)
// ---------------------------------------------------------------------------
{
  const im = I.create(XP.w, XP.h);
  for (let j = 0; j < XP.h; j++) for (let i = 0; i < XP.w; i++) {
    const x = XP.x + i, y = XP.y + j;
    const p = get(src, x, y);
    const cyan = Math.min(p[1], p[2]) - p[0];
    // arco inferior de XP: ciano brilhante ao longo da curva
    const m = smooth(18, 60, cyan) * smooth(40, 120, p[2]);
    if (m > 0.02) {
      set(im, i, j, [p[0], p[1], p[2], m * 255]);
      const bg = [14, 18, 22];
      set(C, x, y, [
        p[0] * (1 - m) + bg[0] * m,
        p[1] * (1 - m) + bg[1] * m,
        p[2] * (1 - m) + bg[2] * m,
      ]);
    }
  }
  I.writeTGA(path.join(OUT, "XPFill.tga"), im);
  I.writePNG(path.join(PREV, "xp_fill.png"), im);

  const xsp = I.create(32, 32);
  for (let j = 0; j < 32; j++) for (let i = 0; i < 32; i++) {
    const d = Math.hypot(i - 15.5, j - 15.5) / 15.5;
    const v = Math.pow(clamp(1 - d), 2.2);
    set(xsp, i, j, [120 * v, 235 * v, 255 * v, v * 255]);
  }
  I.writeTGA(path.join(OUT, "XPSpark.tga"), xsp);
}

// ---------------------------------------------------------------------------
// 9. Máscara circular para ícones dos botões (64x64) + Key.tga (44x24)
// ---------------------------------------------------------------------------
{
  const mask = I.create(64, 64);
  for (let j = 0; j < 64; j++) for (let i = 0; i < 64; i++) {
    const d = Math.hypot(i - 31.5, j - 31.5);
    const a = 1 - smooth(29.5, 31.5, d);
    set(mask, i, j, [255, 255, 255, a * 255]);
  }
  I.writeTGA(path.join(OUT, "CircleMask.tga"), mask);

  // Key.tga (caixinha escura com borda bronze discreta para atalhos)
  const kw = 44, kh = 24, key = I.create(kw, kh);
  for (let j = 0; j < kh; j++) for (let i = 0; i < kw; i++) {
    const border = i === 0 || j === 0 || i === kw - 1 || j === kh - 1;
    const inner = i === 1 || j === 1 || i === kw - 2 || j === kh - 2;
    if (border) set(key, i, j, [78, 62, 42, 235]);
    else if (inner) set(key, i, j, [36, 28, 22, 240]);
    else set(key, i, j, [14, 13, 15, 225]);
  }
  I.writeTGA(path.join(OUT, "Key.tga"), key);
}

// ---------------------------------------------------------------------------
// 10. Remoção do fundo escuro (flood-fill a partir das bordas do recorte HUD)
//     + apagamento de "XP 85.3%" fora da moldura
// ---------------------------------------------------------------------------
const hudIm = I.crop(C, HUD.x, HUD.y, HUD.w, HUD.h);
{
  const hw = hudIm.w, hh = hudIm.h;
  // Apagar região do texto "XP 85.3%" na base
  for (let y = 380; y < hh; y++) for (let x = 440; x < 530; x++) {
    const p = get(hudIm, x, y);
    if (lum(p) > 45) set(hudIm, x, y, [14, 16, 18, 255]);
  }
  // Flood fill das bordas para identificar o fundo escuro
  const bg = new Uint8Array(hw * hh);
  const q = [];
  const isBgPixel = (x, y) => {
    const p = get(hudIm, x, y);
    const l = lum(p);
    const sat = Math.max(p[0], p[1], p[2]) - Math.min(p[0], p[1], p[2]);
    if (l < 36 && sat < 24) return true;
    // Não remove o interior dos 24 slots circulares nem o miolo da asa direita
    if (x >= 590 && x <= 940 && y >= 115 && y <= 255) return false;
    for (const sy of LY) for (const sx of LX) {
      if (Math.hypot(x - (sx - HUD.x), y - (sy - HUD.y)) <= LR + 2) return false;
    }
    // Remove neblina borrada acima do medalhão central (halo antigo) e ao redor das asas
    const cx = LEVEL.cx - HUD.x, cy = LEVEL.cy - HUD.y;
    if (y < cy - 108 && x > 320 && x < 590) {
      // acima do medalhão, só mantém bronze quente
      if (p[0] < 65 || p[2] > p[0] * 0.9) return true;
    }
    return p[0] < 50 && p[2] < 105 && l < 76;
  };
  for (let x = 0; x < hw; x++) {
    if (isBgPixel(x, 0)) { bg[x] = 1; q.push(x); }
    if (isBgPixel(x, hh - 1)) { const id = (hh - 1) * hw + x; bg[id] = 1; q.push(id); }
  }
  for (let y = 0; y < hh; y++) {
    if (isBgPixel(0, y)) { const id = y * hw; bg[id] = 1; q.push(id); }
    if (isBgPixel(hw - 1, y)) { const id = y * hw + hw - 1; bg[id] = 1; q.push(id); }
  }
  let head = 0;
  while (head < q.length) {
    const cur = q[head++], cx = cur % hw, cy = (cur / hw) | 0;
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = cx + dx, ny = cy + dy;
      if (nx < 0 || ny < 0 || nx >= hw || ny >= hh) continue;
      const nid = ny * hw + nx;
      if (bg[nid]) continue;
      if (isBgPixel(nx, ny)) { bg[nid] = 1; q.push(nid); }
    }
  }
  // Manter apenas o maior componente conexo (elimina runas/poções soltas no fundo)
  const comp = new Int32Array(hw * hh).fill(-1);
  let bestId = -1, bestSize = 0, cid = 0;
  for (let idx = 0; idx < hw * hh; idx++) {
    if (bg[idx] || comp[idx] >= 0) continue;
    const cq = [idx];
    comp[idx] = cid;
    let ch = 0;
    while (ch < cq.length) {
      const cur = cq[ch++], cx = cur % hw, cy = (cur / hw) | 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const nx = cx + dx, ny = cy + dy;
        if (nx < 0 || ny < 0 || nx >= hw || ny >= hh) continue;
        const nid = ny * hw + nx;
        if (!bg[nid] && comp[nid] < 0) { comp[nid] = cid; cq.push(nid); }
      }
    }
    if (cq.length > bestSize) { bestSize = cq.length; bestId = cid; }
    cid++;
  }
  for (let idx = 0; idx < hw * hh; idx++) {
    if (!bg[idx] && comp[idx] !== bestId) bg[idx] = 1;
  }
  // Suavizar 2px na fronteira
  for (let y = 0; y < hh; y++) for (let x = 0; x < hw; x++) {
    const id = y * hw + x;
    if (bg[id]) {
      hudIm.px[id * 4 + 3] = 0;
    } else {
      let nBg = 0;
      for (let dy = -1; dy <= 1; dy++) for (let dx = -1; dx <= 1; dx++) {
        const nx = x + dx, ny = y + dy;
        if (nx >= 0 && ny >= 0 && nx < hw && ny < hh && bg[ny * hw + nx]) nBg++;
      }
      hudIm.px[id * 4 + 3] = nBg > 0 ? Math.round(255 * (1 - nBg / 10)) : 255;
    }
  }
}
I.writePNG(path.join(PREV, "clean.png"), hudIm);

// ---------------------------------------------------------------------------
// 11. Dividir em 2 peças de 512x512 (Left.tga, Right.tga) + Glow.tga (512x256)
// ---------------------------------------------------------------------------
{
  const half = Math.floor(HUD.w / 2); // 488
  const left = I.create(512, 512);
  I.blit(left, I.crop(hudIm, 0, 0, half, HUD.h), 0, 0);
  I.writeTGA(path.join(OUT, "Left.tga"), left);

  const right = I.create(512, 512);
  I.blit(right, I.crop(hudIm, half, 0, HUD.w - half, HUD.h), 0, 0);
  I.writeTGA(path.join(OUT, "Right.tga"), right);

  // Glow.tga (meia resolução: 512x256) SOMENTE no cristal central e nos fluxos de azaath do arco direito
  const gw = 512, gh = 256, glow = I.create(gw, gh);
  const cx = (LEVEL.cx - HUD.x) / 2, cy = (LEVEL.cy - HUD.y) / 2;
  for (let j = 0; j < Math.floor(HUD.h / 2); j++) for (let i = 0; i < Math.floor(HUD.w / 2); i++) {
    const p = get(hudIm, i * 2, j * 2);
    if (p[3] < 40) continue;
    const inCrystal = Math.hypot(i - cx, j - cy) <= 48;
    const inRightFlow = i >= 285 && i <= 465 && j >= 25 && j <= 135;
    if (!inCrystal && !inRightFlow) continue;
    const cyan = Math.min(p[1], p[2]) - p[0];
    const g = smooth(24, 95, cyan) * (p[3] / 255);
    if (g > 0.02) {
      set(glow, i, j, [p[0] * g, p[1] * g, p[2] * g, g * 255]);
    }
  }
  I.writeTGA(path.join(OUT, "Glow.tga"), glow);
  I.writePNG(path.join(PREV, "glow.png"), glow);
}

// ---------------------------------------------------------------------------
// 12. Gravar Modules/AzaathCrystalLayoutData.lua (coordenadas relativas à HUD)
// ---------------------------------------------------------------------------
{
  const relX = (v) => v - HUD.x;
  const relY = (v) => v - HUD.y;
  const lSize = LR * 2; // 38
  const rSize = RR * 2; // 48
  const lua = `-- GERADO por tools/azaath-hud-concept/gen.js: não editar à mão.
-- Coordenadas da HUD Azaath (nova skin) relativas ao canto superior esquerdo da HUD.
local _, Azaath = ...
Azaath.AZAATH_CRYSTAL = {
    hud = { w = ${HUD.w}, h = ${HUD.h} },
    pieces = { { x = 0, w = 488 }, { x = 488, w = 488 } },
    left = {
        x = { ${LX.map((v) => relX(v) - LR).join(", ")} },
        y = { ${LY.map((v) => relY(v) - LR).join(", ")} },
        size = ${lSize},
        inset = 2,
        circular = true,
    },
    right = {
        x = { ${RX.map((v) => relX(v) - RR).join(", ")} },
        y = { ${RY.map((v) => relY(v) - RR).join(", ")} },
        size = ${rSize},
        inset = 3,
        circular = true,
    },
    tabs = {
        { x = ${relX(TABS[0].x)}, y = ${relY(TABS[0].y)}, w = ${TABS[0].w}, h = ${TABS[0].h} },
        { x = ${relX(TABS[1].x)}, y = ${relY(TABS[1].y)}, w = ${TABS[1].w}, h = ${TABS[1].h} },
    },
    power = { x = ${relX(POWER.x)}, y = ${relY(POWER.y)}, w = ${POWER.w}, h = ${POWER.h} },
    powerSpark = { x = 0, y = 0, w = 32, h = 32 },
    powerTip = 190,
    health = { x = ${relX(HEALTH.x)}, y = ${relY(HEALTH.y)}, w = ${HEALTH.w}, h = ${HEALTH.h} },
    healthText = { ${relX(282)}, ${relY(403)} },
    xp = { x = ${relX(XP.x)}, y = ${relY(XP.y)}, w = ${XP.w}, h = ${XP.h} },
    xpSpark = { x = 0, y = 0, w = 32, h = 32 },
    xpTip = 250,
    xpText = { ${relX(505)}, ${relY(513)} },
    level = { ${relX(LEVEL.cx)}, ${relY(LEVEL.cy)} },
    proc = { size = 128 },
    buffs = { x = 320, y = 62, size = 34, spacing = 6 },
    key = { w = 44, h = 24 },
}
`;
  fs.writeFileSync(path.join(ROOT, "Modules", "AzaathCrystalLayoutData.lua"), lua, "utf8");
}

console.log("Generated Media/AzaathCrystal/*.tga and Modules/AzaathCrystalLayoutData.lua");
