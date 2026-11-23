// Gera as texturas do Grimório (aba da ficha) a partir da arte de conceito
// (tools/grimoire-concept/concept.webp, 1376x768).
//
//   1. Converte a .webp em PNG com o Edge sem janela (concept.png) — feito uma vez:
//        msedge --headless=new --window-size=1376,768 --screenshot=concept.png shot.html
//   2. node tools/grimoire-concept/gen.js
//
// Saída (AzaathUI/Media/Grimoire):
//   GrimBG        fundo inteiro (mesa, velas, cristais, livro) sem nenhum texto/ícone dinâmico
//   GrimPage      página esquerda limpa (folha que vira na animação)
//   GrimMedal     moldura de bronze dos medalhões (anel com miolo transparente)
//   GrimSeal      moldura dos selos de passiva
//   GrimTabRing   anel dourado do marcador ativo (ADD)
//   GrimTab       marcador de couro vazio (5ª aba: pet)
//   GrimTabsCut   os 4 marcadores recortados pelo contorno (puxados no hover/seleção)
//   GrimTabsGlow  brilho com o contorno de cada marcador (luz de fundo do selecionado)
//   GrimTabsEdge  filete de luz fino que acompanha a borda de cada marcador
//   GrimDiagram   diagrama alquímico da página direita (tinta com alfa; encolhe com texto longo)
//   GrimMesa      folha da Mesa de Runas (pergaminho, couro e bronze, 2x)
// Coordenadas no Lua = coordenadas desta arte (o quadro inteiro é escalado).
const fs = require("fs");
const path = require("path");
const I = require("../sheet-concept/img");
const { readPNG } = require("./png");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "Grimoire");
const PREV = path.join(__dirname, "preview");
fs.mkdirSync(OUT, { recursive: true });
fs.mkdirSync(PREV, { recursive: true });

const src = readPNG(path.join(__dirname, "concept.png"));
const W = src.w, H = src.h;
const clone = (im) => ({ w: im.w, h: im.h, px: Float32Array.from(im.px) });
const img = clone(src);
const get = (im, x, y) => { const o = (y * im.w + x) * 4; return [im.px[o], im.px[o + 1], im.px[o + 2]]; };
const set = (im, x, y, c) => { const o = (y * im.w + x) * 4; im.px[o] = c[0]; im.px[o + 1] = c[1]; im.px[o + 2] = c[2]; };
const lum = (im, x, y) => { const o = (y * im.w + x) * 4; return 0.3 * im.px[o] + 0.59 * im.px[o + 1] + 0.11 * im.px[o + 2]; };

// Máscara global (1 = apagar) e preenchimento por convolução normalizada + relaxamento
let MASK = new Uint8Array(W * H);
const M = (x, y) => MASK[y * W + x];
function markRect(x0, y0, x1, y1) { for (let y = Math.max(0, y0); y <= Math.min(H - 1, y1); y++) for (let x = Math.max(0, x0); x <= Math.min(W - 1, x1); x++) MASK[y * W + x] = 1; }
function markCircle(cx, cy, r) { for (let y = Math.floor(cy - r); y <= Math.ceil(cy + r); y++) for (let x = Math.floor(cx - r); x <= Math.ceil(cx + r); x++) if ((x - cx) ** 2 + (y - cy) ** 2 <= r * r) MASK[y * W + x] = 1; }
// pixels que fogem do fundo local (texto claro/escuro) dentro de uma caixa
function markDeviant(x0, y0, x1, y1, o = {}) {
  const thr = o.thr ?? 22, rad = o.rad ?? 10;
  const ref = boxBlurLum(x0 - rad, y0 - rad, x1 + rad, y1 + rad, rad);
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) {
    const d = lum(img, x, y) - ref(x, y);
    if ((o.dark !== false && d < -thr) || (o.light && d > thr)) MASK[y * W + x] = 1;
  }
}
function boxBlurLum(x0, y0, x1, y1, r) {
  x0 = Math.max(0, x0); y0 = Math.max(0, y0); x1 = Math.min(W - 1, x1); y1 = Math.min(H - 1, y1);
  const w = x1 - x0 + 1, h = y1 - y0 + 1, S = new Float64Array((w + 1) * (h + 1));
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) S[(y + 1) * (w + 1) + x + 1] = lum(img, x0 + x, y0 + y) + S[y * (w + 1) + x + 1] + S[(y + 1) * (w + 1) + x] - S[y * (w + 1) + x];
  return (x, y) => {
    const a = Math.max(0, x - x0 - r), b = Math.max(0, y - y0 - r), c = Math.min(w - 1, x - x0 + r), d = Math.min(h - 1, y - y0 + r);
    const s = S[(d + 1) * (w + 1) + c + 1] - S[b * (w + 1) + c + 1] - S[(d + 1) * (w + 1) + a] + S[b * (w + 1) + a];
    return s / ((c - a + 1) * (d - b + 1));
  };
}
function dilateMask(r) {
  for (let k = 0; k < r; k++) {
    const nx = Uint8Array.from(MASK);
    for (let y = 1; y < H - 1; y++) for (let x = 1; x < W - 1; x++) if (MASK[y * W + x]) {
      nx[y * W + x - 1] = nx[y * W + x + 1] = nx[(y - 1) * W + x] = nx[(y + 1) * W + x] = 1;
    }
    MASK = nx;
  }
}
// Preenche os pixels mascarados de uma caixa a partir dos não mascarados
function fill(x0, y0, x1, y1, grain = 0) {
  const pts = [];
  for (let y = y0; y <= y1; y++) for (let x = x0; x <= x1; x++) if (M(x, y)) pts.push(y * W + x);
  if (!pts.length) return;
  // 1) convolução normalizada em escalas crescentes (chute inicial)
  const known = new Uint8Array(W * H);
  for (let y = 0; y < H; y++) for (let x = 0; x < W; x++) known[y * W + x] = M(x, y) ? 0 : 1;
  for (const r of [4, 8, 16, 32, 64, 128, 256]) {
    for (const p of pts) {
      if (known[p] === 2) continue;
      const px = p % W, py = (p / W) | 0;
      let s0 = 0, s1 = 0, s2 = 0, n = 0;
      const st = Math.max(1, r >> 2);
      for (let dy = -r; dy <= r; dy += st) for (let dx = -r; dx <= r; dx += st) {
        const x = px + dx, y = py + dy;
        if (x < 0 || y < 0 || x >= W || y >= H || known[y * W + x] !== 1) continue;
        const wgt = 1 / (1 + dx * dx + dy * dy);
        const c = get(img, x, y); s0 += c[0] * wgt; s1 += c[1] * wgt; s2 += c[2] * wgt; n += wgt;
      }
      if (n > 0) { set(img, px, py, [s0 / n, s1 / n, s2 / n]); known[p] = 2; }
    }
  }
  // 2) relaxamento harmônico
  for (let it = 0; it < 220; it++) for (const p of pts) {
    const x = p % W, y = (p / W) | 0;
    if (x < 1 || y < 1 || x >= W - 1 || y >= H - 1) continue;
    const a = get(img, x - 1, y), b = get(img, x + 1, y), c = get(img, x, y - 1), d = get(img, x, y + 1);
    set(img, x, y, [0, 1, 2].map((k) => (a[k] + b[k] + c[k] + d[k]) / 4));
  }
  // 3) grão de papel
  if (grain) for (const p of pts) {
    const n = (Math.random() + Math.random() + Math.random() - 1.5) * grain;
    const x = p % W, y = (p / W) | 0, c = get(img, x, y);
    set(img, x, y, [c[0] + n, c[1] + n * 0.95, c[2] + n * 0.85]);
  }
  for (const p of pts) MASK[p] = 0;
}

const snapshot = clone(src);

// ---------------------------------------------------------------------------
// Faixas do cabeçalho e do rodapé da ficha (o jogo desenha os próprios)
// ---------------------------------------------------------------------------
markDeviant(0, 0, W - 1, 64, { light: true, dark: false, thr: 14, rad: 14 });
markRect(8, 4, 76, 60);           // brasão
markRect(1272, 6, 1366, 62);      // poder de item + fechar
markRect(340, 30, 1040, 60);      // navegação
markDeviant(0, 744, W - 1, H - 1, { light: true, dark: false, thr: 12, rad: 12 });
markRect(1040, 744, 1376, 767);
dilateMask(2);
fill(0, 0, W - 1, 66);
fill(0, 742, W - 1, H - 1);

// ---------------------------------------------------------------------------
// Página esquerda: tudo o que é dinâmico (título, medalhões, nomes, linhas)
// ---------------------------------------------------------------------------
markRect(352, 176, 662, 220);                    // título + subtítulo + floreios
const MEDALS = [[432, 266, 40], [587, 284, 39], [408, 402, 39], [590, 400, 39], [492, 510, 39], [379, 522, 31], [595, 518, 32]];
for (const [x, y, r] of MEDALS) markCircle(x, y, r);
markCircle(432, 266, 58);                        // brilho do selecionado
markRect(370, 304, 476, 336); markRect(552, 314, 624, 334);          // nomes
markRect(345, 436, 465, 454); markRect(520, 437, 656, 456); markRect(455, 551, 528, 569);
markCircle(510, 399, 8); markCircle(501, 386, 5);
markDeviant(326, 214, 662, 590, { thr: 16, rad: 9 });               // linhas de tinta
dilateMask(2);
fill(300, 165, 690, 605, 2.2);

// ---------------------------------------------------------------------------
// Página direita: cabeçalho, nome, grau, textos das placas e descrição
// ---------------------------------------------------------------------------
markRect(780, 174, 935, 192);                    // "PROTEÇÃO · TÉCNICA" (mantém os floreios)
markRect(722, 194, 1000, 220);                   // nome
markRect(826, 218, 900, 233);                    // ◆ GRAU 1
markRect(730, 487, 1036, 543);                   // descrição
// placas escuras de custo/alcance/tempo: saem inteiras (o jogo escreve à tinta no pergaminho)
markRect(718, 434, 1038, 483);
// "Arraste a runa do livro..." sai da arte (ampliada ela borra); o jogo escreve nítido
markRect(736, 561, 1032, 580);
dilateMask(1);
fill(700, 165, 1050, 548, 2.0);
fill(728, 555, 1040, 584, 2.0);

// ---------------------------------------------------------------------------
// Canto superior direito do livro (executado APÓS limpar os textos da esquerda):
// remove a dobra grande estática e o arco de faíscas, reconstruindo a borda
// reta da página e a mesa atrás dela.
// ---------------------------------------------------------------------------
{
  const SPINE = 688;
  const cleanSnap = clone(img);
  // 1) Mesa de madeira e ardósia acima da página (y 66..165, x 715..1075)
  for (let y = 66; y <= 165; y++) {
    for (let x = 715; x <= 1075; x++) {
      const mx = 2 * SPINE - x;
      const ax = Math.min((x - 715) / 30, (1075 - x) / 30, 1);
      const ay = y > 145 ? Math.max(0, (165 - y) / 20) : 1;
      const a = Math.max(0, Math.min(1, ax * ay));
      const s = get(cleanSnap, mx, y), d = get(img, x, y);
      set(img, x, y, [0, 1, 2].map((k) => s[k] * a + d[k] * (1 - a)));
    }
  }
  // 2) Borda superior e canto direito limpo da página (y 142..235, x 718..1055)
  for (let y = 142; y <= 235; y++) {
    for (let x = 718; x <= 1055; x++) {
      const mx = 2 * SPINE - x;
      const ax = Math.min((x - 718) / 28, (1055 - x) / 16, 1);
      const ay = Math.min((y - 142) / 6, (235 - y) / 30, 1);
      const a = Math.max(0, Math.min(1, ax * ay));
      const s = get(cleanSnap, mx, y), d = get(img, x, y);
      const shade = 1 - 0.07 * Math.max(0, (x - 900) / 155);
      set(img, x, y, [0, 1, 2].map((k) => (s[k] * shade) * a + d[k] * (1 - a)));
    }
  }
  // 3) Faíscas e faixa ciano residual na lateral direita da folha (y 215..345, x 925..1048)
  for (let y = 215; y <= 345; y++) {
    for (let x = 925; x <= 1048; x++) {
      const c = get(img, x, y);
      if ((x < 1038 && c[0] - c[2] < 24) || c[2] - c[0] > 4 || lum(img, x, y) > 205) MASK[y * W + x] = 1;
    }
  }
  dilateMask(2);
  fill(918, 210, 1052, 350, 2.0);
}

// ---------------------------------------------------------------------------
// Diagrama alquímico: sai do fundo e vira textura própria (tinta com alfa),
// para o jogo encolher/subir o diagrama quando a descrição é longa.
// Ícone + brilho do centro também saem (o jogo desenha os dele).
// ---------------------------------------------------------------------------
const DG = { x0: 755, y0: 230, x1: 980, y1: 436, icx: 867.5, icy: 328 };
const diagSnap = clone(img);
// a área inteira do diagrama (tinta + brilho) vira pergaminho refeito a partir da borda
for (let y = DG.y0 - 4; y <= DG.y1 + 4; y++) for (let x = DG.x0 - 4; x <= DG.x1 + 4; x++) {
  if (((x - 866) / 114) ** 2 + ((y - 333) / 108) ** 2 <= 1) MASK[y * W + x] = 1;
}
fill(DG.x0 - 12, DG.y0 - 12, DG.x1 + 12, DG.y1 + 12, 2.2);
const INKC = [44, 31, 22];
const diag = I.create(256, 256);
for (let y = DG.y0; y <= DG.y1; y++) for (let x = DG.x0; x <= DG.x1; x++) {
  const o = ((y - DG.y0) * 256 + (x - DG.x0)) * 4;
  const Lp = lum(img, x, y), Lo = lum(diagSnap, x, y), Li = 0.3 * INKC[0] + 0.59 * INKC[1] + 0.11 * INKC[2];
  let a = Math.max(0, Math.min(1, (Lp - Lo) / Math.max(1, Lp - Li)));
  const dc = Math.hypot(x - DG.icx, y - DG.icy);
  if (dc < 50) a *= Math.max(0, Math.min(1, (dc - 44) / 6));   // centro: o jogo põe ícone e brilho
  a = Math.min(1, a * 1.15);
  if (a < 0.04) a = 0;
  diag.px[o] = INKC[0]; diag.px[o + 1] = INKC[1]; diag.px[o + 2] = INKC[2]; diag.px[o + 3] = 255 * a;
}
// A estrela e o círculo interno ficavam dentro do brilho dourado (não dá para
// separar tinta de luz ali): redesenhados à tinta nas posições da arte.
function inkStroke(x1, y1, x2, y2, w, alpha) {
  const minX = Math.floor(Math.min(x1, x2) - w - 2), maxX = Math.ceil(Math.max(x1, x2) + w + 2);
  const minY = Math.floor(Math.min(y1, y2) - w - 2), maxY = Math.ceil(Math.max(y1, y2) + w + 2);
  const dx = x2 - x1, dy = y2 - y1, L2 = dx * dx + dy * dy || 1;
  for (let y = minY; y <= maxY; y++) for (let x = minX; x <= maxX; x++) {
    if (x < DG.x0 || y < DG.y0 || x > DG.x1 || y > DG.y1) continue;
    const t = Math.max(0, Math.min(1, ((x + 0.5 - x1) * dx + (y + 0.5 - y1) * dy) / L2));
    const d = Math.hypot(x + 0.5 - (x1 + t * dx), y + 0.5 - (y1 + t * dy));
    const a = alpha * Math.max(0, Math.min(1, w / 2 + 0.5 - d));
    const o = ((y - DG.y0) * 256 + (x - DG.x0)) * 4;
    diag.px[o + 3] = Math.max(diag.px[o + 3], 255 * a);
  }
}
{
  // símbolos do anel (centro de cada círculo pequeno) e centro do diagrama
  const P = { top: [861, 256], ur: [933, 295], dr: [937, 374], bot: [870, 410], dl: [795, 372], ul: [795, 292] };
  const C = [866, 333];
  const inward = (p, k) => [p[0] + (C[0] - p[0]) * k, p[1] + (C[1] - p[1]) * k];
  const tri = (a, b, c) => { for (const [p, q] of [[a, b], [b, c], [c, a]]) inkStroke(...p, ...q, 1.15, 0.85); };
  const k = 0.16;  // as pontas tocam a borda interna dos símbolos
  tri(inward(P.top, k), inward(P.dr, k), inward(P.dl, k));
  tri(inward(P.bot, k), inward(P.ul, k), inward(P.ur, k));
  // círculo interno
  for (let i = 0; i < 180; i++) {
    const a0 = (i / 180) * 2 * Math.PI, a1 = ((i + 1) / 180) * 2 * Math.PI;
    inkStroke(C[0] + 58 * Math.cos(a0), C[1] + 54 * Math.sin(a0), C[0] + 58 * Math.cos(a1), C[1] + 54 * Math.sin(a1), 1.0, 0.75);
  }
}
console.log("diagrama", DG.x1 - DG.x0 + 1, "x", DG.y1 - DG.y0 + 1);

// ---------------------------------------------------------------------------
// Marcadores: tira os nomes e o anel dourado do ativo
// ---------------------------------------------------------------------------
// Os três primeiros: só o texto. O couro tem costuras horizontais, então cada
// coluna do texto é refeita copiando a coluna logo à direita do nome (mesma faixa).
const TABS = [[236, 255, 314, 272], [224, 328, 304, 346], [213, 401, 297, 419]];
function retextureTab(x0, y0, x1, y1, srcX) {
  for (let y = y0; y <= y1; y++) {
    // cor média da linha no couro limpo + grão leve; bordas misturadas com o original
    const acc = [0, 0, 0];
    for (let k = 0; k < 10; k++) { const c = get(img, srcX + k, y); acc[0] += c[0]; acc[1] += c[1]; acc[2] += c[2]; }
    const base = acc.map((v) => v / 10);
    for (let x = x0; x <= x1; x++) {
      const e = Math.min(x - x0, x1 - x) / 5, a = Math.min(1, e);
      const n = (Math.random() - 0.5) * 3, o = get(img, x, y);
      set(img, x, y, [0, 1, 2].map((k) => (base[k] + n) * a + o[k] * (1 - a)));
    }
  }
}
// colunas de couro limpo à direita de cada nome
retextureTab(240, 254, 296, 274, 300);
retextureTab(228, 327, 288, 347, 292);
retextureTab(217, 400, 280, 420, 284);
const ringSnap = clone(img);
// PROTEÇÃO (com o anel): o marcador inteiro é o de FÚRIA, já limpo, deslocado (-12, +75)
{
  const dx = -12, dy = 75, X0 = 186, X1 = 300, Y0 = 372, Y1 = 446;
  const fur = clone(img);
  for (let y = Y0; y <= Y1; y++) for (let x = X0; x <= X1; x++) {
    const tx = x + dx, ty = y + dy;
    // mistura suave nas bordas do retângulo (direita longa: emenda com o couro original)
    const e = Math.min((x - X0) / 12, (X1 - x) / 14, (y - Y0) / 8, (Y1 - y) / 8);
    const a = Math.max(0, Math.min(1, e));
    const s = get(fur, x, y), d = get(img, tx, ty);
    set(img, tx, ty, [0, 1, 2].map((k) => s[k] * a + d[k] * (1 - a)));
  }
  // sobra do brilho do anel acima/abaixo do retângulo copiado
  for (let y = 426; y <= 546; y++) for (let x = 160; x <= 275; x++) {
    if (y >= Y0 + dy + 4 && y <= Y1 + dy - 4 && x >= X0 + dx + 4) continue;
    const d = Math.hypot(x - 232, y - 485), c = get(img, x, y);
    if (d > 24 && d < 52 && (c[0] + c[1] - 2 * c[2] > 50 || lum(img, x, y) > 85)) MASK[y * W + x] = 1;
  }
  dilateMask(2);
  fill(150, 420, 280, 552);
}
// restos de letras nas pontas direitas dos marcadores
for (const [x0, y0, x1, y1] of [[286, 252, 314, 276], [284, 325, 308, 350], [276, 398, 300, 422], [266, 472, 300, 498]]) {
  markDeviant(x0, y0, x1, y1, { light: true, dark: false, thr: 12, rad: 5 });
}
dilateMask(1);
for (const [x0, y0, x1, y1] of [[286, 252, 314, 276], [284, 325, 308, 350], [276, 398, 300, 422], [266, 472, 300, 498]]) fill(x0 - 2, y0 - 2, x1 + 2, y1 + 2);
// anel dourado (ADD) = original - marcador limpo, só na coroa do anel
const tabRing = I.create(128, 128);
for (let j = 0; j < 128; j++) for (let i = 0; i < 128; i++) {
  const x = 232 - 64 + i, y = 485 - 64 + j, o = (j * 128 + i) * 4, d = Math.hypot(i - 63.5, j - 63.5);
  const a = get(src, x, y), b = get(img, x, y);
  // só o dourado (letras creme e couro ficam de fora)
  const gold = Math.max(0, Math.min(1, (a[0] - a[2] - 60) / 50));
  const k = gold * Math.max(0, Math.min(1, (d - 24) / 4)) * Math.max(0, Math.min(1, (60 - d) / 8));
  for (let c = 0; c < 3; c++) tabRing.px[o + c] = Math.max(0, a[c] - b[c] - 6) * 1.15 * k;
  tabRing.px[o + 3] = 255;
}

// ---------------------------------------------------------------------------
// Mesa de Runas: abas e encaixes vazios (o jogo põe nomes, ícones e números)
// ---------------------------------------------------------------------------
const mesaTabSnap = clone(img);
markRect(1064, 612, 1340, 632);
fill(1060, 608, 1344, 636);
const SLOT_X = [1067, 1113, 1159, 1205, 1251, 1297], SLOT_Y = [637, 692], SLOT = 40;
// encaixe vazio de referência: 3ª coluna, 2ª linha (com "+"), "+" apagado
const ref = { x: 1159, y: 692 };
markDeviant(ref.x + 8, ref.y + 8, ref.x + SLOT - 8, ref.y + SLOT - 8, { light: true, dark: false, thr: 10, rad: 6 });
dilateMask(1); fill(ref.x + 4, ref.y + 4, ref.x + SLOT - 4, ref.y + SLOT - 4);
const emptySlot = I.crop(img, ref.x - 2, ref.y - 2, SLOT + 4, SLOT + 4);
for (const sy of SLOT_Y) for (const sx of SLOT_X) I.blit(img, emptySlot, sx - 2, sy - 2);
// números das teclas
for (const sy of SLOT_Y) { markRect(1062, sy + SLOT + 1, 1342, sy + SLOT + 9); }
fill(1060, 676, 1344, 691); fill(1060, 731, 1344, 742);
const mesaTab = I.crop(mesaTabSnap, 1066, 614, 70, 17);
{ // tira "BARRA 1" da pílula
  const m = mesaTab;
  for (let j = 2; j < m.h - 2; j++) for (let i = 4; i < m.w - 4; i++) {
    const c = get(m, i, j); if (c[2] < 150) set(m, i, j, get(m, 3, j));
  }
}

// Pílula dos totais
markRect(522, 721, 714, 733);
fill(518, 718, 718, 736);

// ---------------------------------------------------------------------------
// Peças recortadas
// ---------------------------------------------------------------------------
function annulus(im, cx, cy, rIn, rOut, size) {
  const out = I.create(size, size);
  const sc = (rOut + 2) * 2 / size;
  for (let j = 0; j < size; j++) for (let i = 0; i < size; i++) {
    const x = cx + (i + 0.5) * sc - (rOut + 2), y = cy + (j + 0.5) * sc - (rOut + 2);
    const d = Math.hypot(x - cx, y - cy);
    const xi = Math.min(W - 2, Math.max(0, Math.floor(x))), yi = Math.min(H - 2, Math.max(0, Math.floor(y)));
    const tx = x - xi, ty = y - yi;
    const c = [0, 1, 2].map((k) => {
      const p = (xx, yy) => im.px[(yy * W + xx) * 4 + k];
      return (p(xi, yi) * (1 - tx) + p(xi + 1, yi) * tx) * (1 - ty) + (p(xi, yi + 1) * (1 - tx) + p(xi + 1, yi + 1) * tx) * ty;
    });
    const o = (j * size + i) * 4;
    out.px[o] = c[0]; out.px[o + 1] = c[1]; out.px[o + 2] = c[2];
    out.px[o + 3] = 255 * Math.max(0, Math.min(1, (d - rIn + 0.8))) * Math.max(0, Math.min(1, rOut - d + 0.8));
  }
  return out;
}
const medal = annulus(snapshot, 587, 284, 24, 38, 128);
const seal = annulus(snapshot, 595, 518, 21.5, 29.5, 128);
const page = I.crop(img, 296, 160, 396, 452);
const tab = I.crop(img, 205, 310, 106, 54);

// Pontinha discreta dobrada para o canto superior direito da página direita
const pageTip = (() => {
  const S = 128, out = I.create(S, S);
  // Triângulo de dobra no canto superior direito (vértice da folha em ~ (92, 34))
  // Pontos: A = (58, 30) topo, B = (96, 68) borda direita, C = (54, 62) dobra interna
  const Ax = 58, Ay = 30, Bx = 96, By = 68, Cx = 56, Cy = 64;
  const area = (px, py, qx, qy, rx, ry) => (qx - px) * (ry - py) - (qy - py) * (rx - px);
  const inTri = (x, y) => {
    const d1 = area(Ax, Ay, Bx, By, x, y);
    const d2 = area(Bx, By, Cx, Cy, x, y);
    const d3 = area(Cx, Cy, Ax, Ay, x, y);
    return !((d1 < 0 || d2 < 0 || d3 < 0) && (d1 > 0 || d2 > 0 || d3 > 0));
  };
  for (let y = 0; y < S; y++) for (let x = 0; x < S; x++) {
    const o = (y * S + x) * 4;
    // sombra projetada embaixo da pontinha dobrada
    const ds = Math.hypot((x - 70) / 22, (y - 54) / 18);
    if (ds < 1.35 && y > 32 && x < 98) {
      const sa = Math.max(0, (1.35 - ds) * 0.28);
      out.px[o] = 28; out.px[o + 1] = 20; out.px[o + 2] = 14; out.px[o + 3] = 255 * sa;
    }
    // cobertura do triângulo dobrado com anti-aliasing 3x3
    let cov = 0;
    for (let sy = 0; sy < 3; sy++) for (let sx = 0; sx < 3; sx++) {
      if (inTri(x + (sx + 0.5) / 3, y + (sy + 0.5) / 3)) cov++;
    }
    if (cov > 0) {
      const a = cov / 9;
      // gradiente de pergaminho claro na dobra, levemente mais quente na borda
      const t = Math.max(0, Math.min(1, ((x - Cx) + (Cy - y)) / 36));
      const r = 228 - 22 * t, g = 212 - 26 * t, b = 180 - 30 * t;
      const bgA = out.px[o + 3] / 255;
      const finA = a + bgA * (1 - a);
      out.px[o]     = (r * a + out.px[o] * bgA * (1 - a)) / (finA || 1);
      out.px[o + 1] = (g * a + out.px[o + 1] * bgA * (1 - a)) / (finA || 1);
      out.px[o + 2] = (b * a + out.px[o + 2] * bgA * (1 - a)) / (finA || 1);
      out.px[o + 3] = 255 * finA;
    }
  }
  return out;
})();

function padTo(im, w, h) { const out = I.create(w, h); I.blit(out, im, 0, 0); return out; }

// ---------------------------------------------------------------------------
// Marcadores recortados (contorno medido na arte, sem os nomes) para o jogo
// "puxar" o marcador para fora do livro no hover/seleção. Atlas 512x64:
// marcador i na coluna i*128. Imprime as caixas para o Lua (TAB_CUT).
// ---------------------------------------------------------------------------
const TAB_POLYS = [
  [[229, 244], [256, 243], [315.5, 240], [311.5, 289], [224, 289], [217, 266]],
  [[220, 315.5], [250, 313], [308.5, 311], [302.5, 360], [256, 361], [215, 363.5], [206, 338.5]],
  [[208.5, 386.5], [240, 385], [299, 383], [292.5, 431], [201, 435], [195, 410]],
  [[197.5, 462], [240, 460], [297, 458], [300, 506], [191, 511.5], [183.5, 486]],
];
function inPoly(x, y, poly) {
  let c = false;
  for (let i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    const [xi, yi] = poly[i], [xj, yj] = poly[j];
    if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) c = !c;
  }
  return c;
}
const tabAtlas = I.create(512, 64);
const tabBoxes = [];
TAB_POLYS.forEach((poly, i) => {
  const xs = poly.map((p) => p[0]), ys = poly.map((p) => p[1]);
  const x0 = Math.floor(Math.min(...xs)) - 2, y0 = Math.floor(Math.min(...ys)) - 2;
  const w = Math.ceil(Math.max(...xs)) + 2 - x0, h = Math.ceil(Math.max(...ys)) + 2 - y0;
  tabBoxes.push([x0, y0, w, h]);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    let a = 0;
    for (let sy = 0; sy < 4; sy++) for (let sx = 0; sx < 4; sx++) if (inPoly(x0 + x + (sx + 0.5) / 4, y0 + y + (sy + 0.5) / 4, poly)) a++;
    const c = get(img, x0 + x, y0 + y), o = (y * 512 + i * 128 + x) * 4;
    tabAtlas.px[o] = c[0]; tabAtlas.px[o + 1] = c[1]; tabAtlas.px[o + 2] = c[2]; tabAtlas.px[o + 3] = 255 * a / 16;
  }
});
console.log("TAB_CUT", JSON.stringify(tabBoxes));

// Brilho com o contorno de cada marcador (luz de fundo do conceito C): máscara do
// polígono desfocada, branca; o jogo tinge de ciano. Atlas 1024x128, coluna i*160,
// caixa = recorte + 18 px de cada lado (caixas impressas em TAB_GLOW).
const tabGlow = I.create(1024, 128);
const glowBoxes = [];
TAB_POLYS.forEach((poly, i) => {
  const [cx0, cy0, cw, ch] = tabBoxes[i], M = 18;
  const x0 = cx0 - M, y0 = cy0 - M, w = cw + 2 * M, h = ch + 2 * M;
  glowBoxes.push([x0, y0, w, h]);
  let m = new Float32Array(w * h);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    let a = 0;
    for (let sy = 0; sy < 3; sy++) for (let sx = 0; sx < 3; sx++) if (inPoly(x0 + x + (sx + 0.5) / 3, y0 + y + (sy + 0.5) / 3, poly)) a++;
    m[y * w + x] = a / 9;
  }
  const blur = (src, r) => {   // caixa separável
    const t = new Float32Array(w * h), o = new Float32Array(w * h);
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { let s = 0, n = 0; for (let k = -r; k <= r; k++) { const xx = x + k; if (xx >= 0 && xx < w) { s += src[y * w + xx]; n++; } } t[y * w + x] = s / n; }
    for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) { let s = 0, n = 0; for (let k = -r; k <= r; k++) { const yy = y + k; if (yy >= 0 && yy < h) { s += t[yy * w + x]; n++; } } o[y * w + x] = s / n; }
    return o;
  };
  m = blur(blur(blur(m, 4), 4), 4);
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    const o = (y * 1024 + i * 160 + x) * 4, a = Math.min(1, m[y * w + x] * 1.7);
    tabGlow.px[o] = 255; tabGlow.px[o + 1] = 255; tabGlow.px[o + 2] = 255; tabGlow.px[o + 3] = 255 * a;
  }
});
console.log("TAB_GLOW", JSON.stringify(glowBoxes));

// Contorno de luz de cada marcador (filete que acompanha as bordas inclinadas e a
// ponteira; a ponta direita, que entra no livro, fica sem linha). Mesmo atlas e
// mesmas caixas do recorte (GrimTabsCut): o jogo desenha por cima do recorte.
const tabEdge = I.create(512, 64);
function segDist(px, py, ax, ay, bx, by) {
  const dx = bx - ax, dy = by - ay, L2 = dx * dx + dy * dy || 1;
  const t = Math.max(0, Math.min(1, ((px - ax) * dx + (py - ay) * dy) / L2));
  return Math.hypot(px - (ax + t * dx), py - (ay + t * dy));
}
TAB_POLYS.forEach((poly, i) => {
  const [x0, y0, w, h] = tabBoxes[i];
  const maxX = Math.max(...poly.map((p) => p[0]));
  const edges = [];
  for (let k = 0; k < poly.length; k++) {
    const a = poly[k], b = poly[(k + 1) % poly.length];
    if (a[0] > maxX - 8 && b[0] > maxX - 8) continue;      // borda direita: entra no livro
    edges.push([a, b]);
  }
  for (let y = 0; y < h; y++) for (let x = 0; x < w; x++) {
    let acc = 0;
    for (let sy = 0; sy < 3; sy++) for (let sx = 0; sx < 3; sx++) {
      const px = x0 + x + (sx + 0.5) / 3, py = y0 + y + (sy + 0.5) / 3;
      if (!inPoly(px, py, poly)) continue;
      let d = 1e9;
      for (const [a, b] of edges) d = Math.min(d, segDist(px, py, a[0], a[1], b[0], b[1]));
      // linha fina 1,6 px para dentro da borda + brilho curto para o lado de dentro
      const line = Math.max(0, 1 - Math.abs(d - 1.6) / 0.9);
      const inner = Math.max(0, 1 - d / 5) * 0.35;
      acc += Math.max(line, inner);
    }
    const o = (y * 512 + i * 128 + x) * 4;
    tabEdge.px[o] = 255; tabEdge.px[o + 1] = 255; tabEdge.px[o + 2] = 255; tabEdge.px[o + 3] = 255 * Math.min(1, acc / 9);
  }
});

// ---------------------------------------------------------------------------
// Mesa de Runas no estilo do livro: folha de pergaminho (da própria página
// limpa) com borda queimada, moldura de couro escuro, filete de bronze e
// cantoneiras de bronze. Cobre o painel escuro original (x 1040..1360,
// y 574..748). Gerada em 2x para ficar nítida.
// ---------------------------------------------------------------------------
const MESA = { x: 1040, y: 574, w: 320, h: 174 }, MS = 2;
function mesaPanel() {
  const W2 = MESA.w * MS, H2 = MESA.h * MS, out = I.create(W2, H2);
  // miolo da página esquerda limpa, longe da sombra da lombada (direita da página)
  const parch = I.resize(I.crop(page, 34, 60, 240, 330), W2, H2);
  for (let i = 0; i < parch.w * parch.h; i++) for (let k = 0; k < 3; k++) parch.px[i * 4 + k] *= 0.9;
  const LEATHER = 14 * MS / 2, BRONZE = 3.5 * MS / 2;      // larguras (px da textura)
  const R = 9 * MS;                                          // raio dos cantos
  const bronze = (t) => { // t 0..1 através do filete: escuro -> claro -> escuro
    const k = Math.sin(Math.PI * t);
    return [70 + 150 * k, 50 + 125 * k, 28 + 78 * k];
  };
  const rnd = (x, y) => { const s = Math.sin(x * 12.9898 + y * 78.233) * 43758.5453; return s - Math.floor(s); };
  for (let y = 0; y < H2; y++) for (let x = 0; x < W2; x++) {
    const o = (y * W2 + x) * 4;
    // distância à borda (com cantos arredondados)
    const cx = Math.min(Math.max(x + 0.5, R), W2 - R), cy = Math.min(Math.max(y + 0.5, R), H2 - R);
    const dc = Math.hypot(x + 0.5 - cx, y + 0.5 - cy);
    const d = (cx !== x + 0.5 || cy !== y + 0.5) && (Math.abs(cx - (x + 0.5)) > 0 && Math.abs(cy - (y + 0.5)) > 0)
      ? R - dc : Math.min(x + 0.5, y + 0.5, W2 - x - 0.5, H2 - y - 0.5);
    const alpha = Math.max(0, Math.min(1, d + 0.5));
    let c;
    if (d < LEATHER) {
      // couro escuro com grão e costura pontilhada
      const n = (rnd(x, y) - 0.5) * 10 + (rnd(x >> 2, y >> 2) - 0.5) * 8;
      const shade = 0.75 + 0.25 * Math.min(1, d / LEATHER);
      c = [(56 + n) * shade, (37 + n * 0.8) * shade, (25 + n * 0.6) * shade];
      const st = Math.abs(d - LEATHER * 0.5) < 0.9 && ((x + y) % 10 < 5);
      if (st) c = c.map((v) => v * 0.55 + 70);
    } else if (d < LEATHER + BRONZE) {
      c = bronze((d - LEATHER) / BRONZE);
    } else {
      // pergaminho com borda queimada
      const p = get(parch, x, y);
      const e = d - LEATHER - BRONZE;
      const burn = Math.exp(-e / (10 * MS / 2));
      const v = 1 - 0.18 * Math.exp(-e / (40 * MS / 2));
      c = [p[0] * v * (1 - 0.55 * burn) + 40 * burn, p[1] * v * (1 - 0.62 * burn) + 22 * burn, p[2] * v * (1 - 0.7 * burn) + 10 * burn];
    }
    out.px[o] = c[0]; out.px[o + 1] = c[1]; out.px[o + 2] = c[2]; out.px[o + 3] = 255 * alpha;
  }
  // cantoneiras de bronze (losangos com brilho)
  const corner = (px, py) => {
    const s = 13 * MS / 2;
    for (let y = -s; y <= s; y++) for (let x = -s; x <= s; x++) {
      const m = Math.abs(x) + Math.abs(y);
      if (m > s) continue;
      const X = Math.round(px + x), Y = Math.round(py + y);
      if (X < 0 || Y < 0 || X >= W2 || Y >= H2) continue;
      const o = (Y * W2 + X) * 4;
      const lit = 0.55 + 0.45 * Math.max(0, (-x - y) / s);       // luz vinda de cima/esquerda
      const edge = m > s - 1.6 ? 0.55 : 1;
      const rivet = Math.hypot(x, y) < 2.4 * MS / 2;
      const b = bronze(0.5);
      const k = rivet ? 1.25 : lit * edge;
      out.px[o] = Math.min(255, b[0] * k); out.px[o + 1] = Math.min(255, b[1] * k); out.px[o + 2] = Math.min(255, b[2] * k);
      out.px[o + 3] = Math.max(out.px[o + 3], 255);
    }
  };
  const ci = LEATHER * 0.55;
  corner(ci, ci); corner(W2 - ci, ci); corner(ci, H2 - ci); corner(W2 - ci, H2 - ci);
  return out;
}
const mesaTex = mesaPanel();

const OUTS = {
  GrimBG: padTo(img, 2048, 1024),
  GrimPage: padTo(page, 512, 512),
  GrimMedal: medal,
  GrimSeal: seal,
  GrimTabRing: tabRing,
  GrimTab: padTo(tab, 128, 64),
  GrimTabsCut: tabAtlas,
  GrimTabsGlow: tabGlow,
  GrimTabsEdge: tabEdge,
  GrimMesa: padTo(mesaTex, 1024, 512),
  GrimDiagram: diag,
  GrimPageTip: pageTip,
};
I.writePNG(path.join(PREV, "mesa.png"), mesaTex);
for (const [name, im] of Object.entries(OUTS)) {
  I.writeTGA(path.join(OUT, name + ".tga"), im);
  console.log("gerado", name, im.w + "x" + im.h);
}
I.writePNG(path.join(PREV, "bg.png"), img);
I.writePNG(path.join(PREV, "medal.png"), medal);
I.writePNG(path.join(PREV, "seal.png"), seal);
I.writePNG(path.join(PREV, "tabring.png"), tabRing);
I.writePNG(path.join(PREV, "page.png"), page);
I.writePNG(path.join(PREV, "tabscut.png"), tabAtlas);
I.writePNG(path.join(PREV, "tabsedge.png"), tabEdge);

// prévia do diagrama sobre pergaminho
{ const p = I.create(256, 256, 214, 196, 160, 255); for (let i = 0; i < 256 * 256; i++) { const a = diag.px[i * 4 + 3] / 255; for (let k = 0; k < 3; k++) p.px[i * 4 + k] = p.px[i * 4 + k] * (1 - a) + diag.px[i * 4 + k] * a; } I.writePNG(path.join(PREV, "diagram.png"), p); }
