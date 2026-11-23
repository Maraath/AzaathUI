// Interface da aba Perícias (versão 2: páginas + cards), desenhada sobre o fundo de epic.js.
//   art.html?mode=full&page=arsenal|oficios|dominios
// As medidas daqui são as mesmas de SKL em BuildSkillsPage (Sheet/Skills.lua).
const PAGE = new URLSearchParams(location.search).get("page") || "arsenal";
const GOLD = "#d8b46a", GOLD2 = "#f1d79a", CYAN = "#7fe0ff", DIM = "#8fa3ad", TXT = "#e6eef2";
const TIERCOL = (r) => r >= 0.95 ? [241, 205, 130] : r >= 0.5 ? [110, 220, 255] : r > 0.02 ? [80, 170, 215] : [90, 105, 115];
const STATUS = (r, rank) => rank <= 1 ? ["NÃO TREINADA", "#8a9aa2"] : r >= 0.95 ? ["QUASE NO TETO", GOLD2] : r >= 0.5 ? ["TREINANDO", CYAN] : ["COMEÇANDO", "#78b8d6"];

function text(s, x, y, o = {}) {
  g.save(); g.font = o.font || "17px PT"; g.fillStyle = o.color || TXT; g.textAlign = o.align || "left"; g.textBaseline = o.base || "middle";
  if (o.ls) g.letterSpacing = o.ls + "px";
  g.shadowColor = "rgba(0,0,0,0.9)"; g.shadowOffsetX = 1.5; g.shadowOffsetY = 1.5;
  if (o.glow) { g.shadowColor = o.glow; g.shadowBlur = o.blur || 10; g.shadowOffsetX = 0; g.shadowOffsetY = 0; }
  g.fillText(s, x, y); const w = g.measureText(s).width; g.restore(); return w;
}
function tw(s, font, ls) { g.save(); g.font = font; if (ls) g.letterSpacing = ls + "px"; const w = g.measureText(s).width; g.restore(); return w; }
function box(x, y, w, h, o = {}) {
  g.save(); rr(x, y, w, h, o.r == null ? 6 : o.r);
  const gr = g.createLinearGradient(0, y, 0, y + h); gr.addColorStop(0, o.top || "rgba(12,28,40,0.92)"); gr.addColorStop(1, o.bot || "rgba(5,13,20,0.94)");
  g.fillStyle = gr; g.fill();
  g.lineWidth = o.lw || 1; g.strokeStyle = o.border || "rgba(120,195,220,0.25)"; g.stroke();
  if (o.glow) { g.shadowColor = o.glow; g.shadowBlur = 22; g.stroke(); }
  g.restore();
}
function bar(x, y, w, h, r, col) {
  const [cr, cg, cb] = col || TIERCOL(r);
  g.save(); rr(x, y, w, h, h / 2); g.fillStyle = "rgba(3,10,15,0.95)"; g.fill(); g.strokeStyle = "rgba(120,190,215,0.22)"; g.lineWidth = 1; g.stroke();
  if (r > 0) { rr(x + 1, y + 1, Math.max(h - 2, (w - 2) * r), h - 2, (h - 2) / 2);
    const gr = g.createLinearGradient(x, 0, x + w * r, 0); gr.addColorStop(0, `rgb(${cr * 0.35 | 0},${cg * 0.5 | 0},${cb * 0.6 | 0})`); gr.addColorStop(1, `rgb(${cr},${cg},${cb})`);
    g.fillStyle = gr; g.shadowColor = `rgba(${cr},${cg},${cb},0.7)`; g.shadowBlur = 10; g.fill(); }
  g.restore();
}
function emblem(x, y, R, kind, r, opts = {}) {
  const [cr, cg, cb] = TIERCOL(r);
  g.save(); g.globalCompositeOperation = "lighter"; glow(x, y, R * 1.9, `${cr},${cg},${cb}`, opts.halo == null ? 0.16 : opts.halo); g.restore();
  g.save(); g.beginPath(); g.arc(x, y, R, 0, 7); g.fillStyle = "rgba(3,10,16,0.96)"; g.fill();
  g.lineWidth = 2; g.strokeStyle = `rgba(${cr},${cg},${cb},${opts.dim ? 0.3 : 0.75})`; g.stroke(); g.restore();
  const ig = g.createLinearGradient(0, y - R, 0, y + R);
  if (opts.dim) { ig.addColorStop(0, "#7b8b93"); ig.addColorStop(1, "#4b5a62"); }
  else if (r >= 0.95) { ig.addColorStop(0, "#fff3d6"); ig.addColorStop(1, "#b88d45"); }
  else { ig.addColorStop(0, "#f0fbff"); ig.addColorStop(1, "#6aa6bd"); }
  const turn = { sword: 0.6, great: 0.6, dagger: 0.6, axe: 0.5, mace: 0.6, mace2: 0.5, spear: 0.6, pick: -0.6, gun: 0.5 };
  drawWeapon(kind, x, y + 1, R / 62, turn[kind] || 0, ig);
}
function pill(x, y, label, col, o = {}) {
  const w = tw(label, "13px PTB", 1.5) + 22, h = 24;
  g.save(); rr(x, y, w, h, 12); g.fillStyle = o.fill || "rgba(0,0,0,0.35)"; g.fill(); g.strokeStyle = col; g.globalAlpha = 0.85; g.lineWidth = 1; g.stroke(); g.restore();
  text(label, x + w / 2, y + h / 2 + 1, { font: "13px PTB", color: col, align: "center", ls: 1.5 });
  return w;
}

// ---------------------------------------------------------------- dados
const WEAP = [
  ["mace", "Maças", 114], ["shield", "Defesa", 112], ["great", "Espadas de Duas Mãos", 97], ["thrown", "Arremesso", 96],
  ["bow", "Arcos", 75], ["sword", "Espadas", 65], ["fist", "Combate desarmado", 37]];
const UNTR = [["dagger", "Adagas"], ["gun", "Armas de Fogo"], ["axe", "Machados"], ["axe2", "Machados de Duas Mãos"], ["mace2", "Maças de Duas Mãos"]];
const CRAFT = [["pick", "Mineração", 89, 150, true], ["pan", "Culinária", 68, 150], ["cross", "Primeiros Socorros", 92, 150], ["hook", "Pesca", 19, 75]];
const DOMS = [["CLASSE", ["Armas", "Fúria", "Proteção"]], ["ARMADURAS", ["Couro", "Escudo", "Malha", "Tecido"]], ["LÍNGUAS", ["Língua: Comum  300/300", "Língua: Darnassiana  300/300"]]];
const TIERS = [[75, "Aprendiz"], [150, "Artífice"], [225, "Especialista"], [300, "Artesão"]];

function ui() {
  // ---------- cabeçalho (o do jogo) ----------
  g.save(); g.beginPath(); g.arc(70, 52, 36, 0, 7); g.fillStyle = "#16303e"; g.fill(); g.strokeStyle = "rgba(216,180,106,0.85)"; g.lineWidth = 3; g.stroke(); g.restore();
  g.save(); g.beginPath(); g.arc(70, 52, 32, 0, 7); g.clip(); const pg = g.createLinearGradient(0, 20, 0, 90); pg.addColorStop(0, "#9fb6c4"); pg.addColorStop(1, "#2a3c4a"); g.fillStyle = pg;
  g.beginPath(); g.arc(70, 48, 13, 0, 7); g.fill(); g.beginPath(); g.ellipse(70, 88, 27, 24, 0, 0, 7); g.fill(); g.restore();
  text("MARAATH", 120, 40, { font: "28px Cinzel", color: "#f0f4f6", ls: 1 });
  text("NÍVEL 23 ELFO NOTURNO GUERREIRO", 121, 66, { font: "12px Cinzel", color: "#b9c8d0", ls: 1 });
  const tabs = ["SANTUÁRIO", "GRIMÓRIO", "TALENTOS", "REPUTAÇÃO", "PERÍCIAS", "GLADIADOR", "TESOURO", "CRÔNICAS"];
  const ws = tabs.map((t) => tw(t, "15px Cinzel", 1)); let tx = 1000 - (ws.reduce((a, b) => a + b, 0) + 28 * 7) / 2;
  tabs.forEach((t, i) => { const act = t === "PERÍCIAS"; text(t, tx, 42, { font: "15px Cinzel", color: act ? "#fff" : "#b9c8d0", ls: 1, glow: act ? CYAN : null });
    if (act) { g.save(); g.globalCompositeOperation = "lighter"; glow(tx + ws[i] / 2, 58, 40, "120,220,255", 0.6); g.restore(); } tx += ws[i] + 28; });
  g.save(); g.beginPath(); g.arc(1912, 50, 26, 0, 7); g.fillStyle = "#0b1d28"; g.fill(); g.strokeStyle = "rgba(216,180,106,0.85)"; g.lineWidth = 3; g.stroke(); g.restore();
  text("15", 1912, 51, { font: "24px Cinzel", color: "#fff", align: "center" });

  // ---------- navegação: 3 cards grandes ----------
  const NAV = [
    { key: "arsenal", icon: "sword", title: "ARSENAL", sub: "7 em treino  ·  5 não treinadas", badge: "2 quase no teto" },
    { key: "oficios", icon: "pick", title: "OFÍCIOS", sub: "1 profissão  ·  3 secundárias", badge: null },
    { key: "dominios", icon: "star", title: "DOMÍNIOS", sub: "9 perícias completas", badge: null },
  ];
  const NW = 440, NH = 92, NG = 24, NX = 1000 - (NW * 3 + NG * 2) / 2, NY = 118;
  NAV.forEach((n, i) => {
    const x = NX + i * (NW + NG), on = n.key === PAGE;
    box(x, NY, NW, NH, { border: on ? "rgba(130,225,255,0.95)" : "rgba(120,195,220,0.22)", lw: on ? 2 : 1, glow: on ? "rgba(90,210,255,0.8)" : null,
      top: on ? "rgba(16,44,60,0.94)" : "rgba(10,24,34,0.88)", bot: on ? "rgba(6,18,28,0.95)" : "rgba(4,11,17,0.9)" });
    emblem(x + 50, NY + NH / 2, 30, n.icon, on ? 0.75 : 0.3, { dim: !on, halo: on ? 0.22 : 0 });
    text(n.title, x + 98, NY + 34, { font: "22px CinzelB", color: on ? GOLD2 : "#9fb0b8", ls: 3 });
    text(n.sub, x + 98, NY + 63, { font: "16px PT", color: on ? "#cfe2ea" : "#7d9099" });
    if (n.badge) pill(x + NW - tw(n.badge.toUpperCase(), "13px PTB", 1.5) - 22 - 16, NY + 22, n.badge.toUpperCase(), GOLD2, { fill: "rgba(216,180,106,0.12)" });
    if (on) { g.save(); g.globalCompositeOperation = "lighter"; const lg = g.createLinearGradient(x, 0, x + NW, 0);
      lg.addColorStop(0, "rgba(120,220,255,0)"); lg.addColorStop(0.5, "rgba(170,235,255,1)"); lg.addColorStop(1, "rgba(120,220,255,0)"); g.fillStyle = lg; g.fillRect(x + 20, NY + NH - 2, NW - 40, 2); g.restore(); }
  });

  // ---------- área da página + painel de detalhe ----------
  const PX = 40, PY = 236, PW = 1420, PH = 806;
  box(PX, PY, PW, PH, { top: "rgba(4,12,18,0.72)", bot: "rgba(3,8,13,0.80)", border: "rgba(120,195,220,0.14)", r: 8 });
  const DX0 = 1484, DW = 476;
  if (PAGE === "arsenal") arsenal(PX, PY, PW); else if (PAGE === "oficios") oficios(PX, PY, PW); else dominios(PX, PY, PW);
  detail(DX0, PY, DW, PH);

  // ---------- rodapé ----------
  text("INTEGRIDADE  97%", 40, 1098, { font: "12px Cinzel", color: "#b9c8d0", ls: 1 });
  text("BOLSAS  15 / 66 LIVRES", 260, 1098, { font: "12px Cinzel", color: "#b9c8d0", ls: 1 });
  text("FECHAR (ESC)", 1960, 1098, { font: "13px Cinzel", color: "#e8eef1", ls: 3, align: "right" });
}

function header(x, y, w, title, count, right) {
  diamond(x + 6, y, 5, GOLD);
  const t = text(title, x + 22, y, { font: "18px CinzelB", color: GOLD, ls: 3 });
  if (count != null) text(String(count), x + 22 + t + 12, y + 1, { font: "18px PTB", color: "#fff" });
  if (right) text(right, x + w, y, { font: "16px PT", color: DIM, align: "right" });
}
function diamond(x, y, r, col) { g.fillStyle = col; g.beginPath(); g.moveTo(x, y - r); g.lineTo(x + r, y); g.lineTo(x, y + r); g.lineTo(x - r, y); g.fill(); }

// ---------------------------------------------------------------- Arsenal
function arsenal(PX, PY, PW) {
  const x0 = PX + 30, w0 = PW - 60;
  header(x0, PY + 40, w0, "EM TREINO", 7, "Teto atual: 115 (5 × nível 23)   ·   no nível 24 sobe para 120");
  const CW = (w0 - 3 * 20) / 4, CH = 150;
  WEAP.forEach(([k, n, v], i) => {
    const col = i % 4, row = Math.floor(i / 4), x = x0 + col * (CW + 20), y = PY + 70 + row * (CH + 20), r = v / 115, sel = i === 0;
    box(x, y, CW, CH, { border: sel ? "rgba(130,225,255,0.95)" : "rgba(120,195,220,0.24)", lw: sel ? 2 : 1, glow: sel ? "rgba(90,210,255,0.7)" : null });
    emblem(x + 52, y + 56, 34, k, r);
    text(n, x + 100, y + 40, { font: n.length > 17 ? "18px PTB" : "21px PTB", color: "#fff" });
    const vw = text(String(v), x + 100, y + 75, { font: "28px Cinzel", color: r >= 0.95 ? GOLD2 : "#fff" });
    text("/ 115", x + 106 + vw, y + 78, { font: "17px PT", color: DIM });
    bar(x + 20, y + 106, CW - 40, 10, r);
    const [st, sc] = STATUS(r, v);
    text(st, x + 20, y + 134, { font: "13px PTB", color: sc, ls: 1.5 });
    text(115 - v > 0 ? `faltam ${115 - v}` : "no teto", x + CW - 20, y + 134, { font: "15px PT", color: r >= 0.95 ? GOLD2 : DIM, align: "right" });
  });
  const uy = PY + 70 + 2 * (CH + 20) + 30;
  header(x0, uy, w0, "NÃO TREINADAS", 5, "aprenda com um mestre de armas nas capitais");
  const UW = (w0 - 4 * 16) / 5, UH = 70;
  UNTR.forEach(([k, n], i) => {
    const x = x0 + i * (UW + 16), y = uy + 28;
    box(x, y, UW, UH, { top: "rgba(8,18,26,0.85)", bot: "rgba(4,10,15,0.9)", border: "rgba(110,150,165,0.18)" });
    emblem(x + 36, y + UH / 2, 22, k, 0, { dim: true, halo: 0 });
    text(n, x + 70, y + 26, { font: n.length > 18 ? "14px PT" : "16px PT", color: "#b4c2c8" });
    text("1 / 115", x + 70, y + 49, { font: "14px PT", color: "#6f828b" });
  });
  // como funciona
  const hy = uy + 28 + UH + 40;
  header(x0, hy, w0, "COMO FUNCIONA");
  const tips = [["mace", "Use a arma para treinar", "Cada golpe em inimigos do seu nível pode dar 1 ponto."],
    ["star", "O teto sobe com o nível", "Teto = 5 × seu nível. Ao subir de nível, ganha +5."],
    ["shield", "Defesa treina apanhando", "Receber golpes de inimigos do seu nível treina a Defesa."]];
  const TWd = (w0 - 2 * 20) / 3;
  tips.forEach(([k, t, d], i) => { const x = x0 + i * (TWd + 20), y = hy + 26;
    box(x, y, TWd, 96, { top: "rgba(10,22,30,0.7)", bot: "rgba(5,12,18,0.75)", border: "rgba(120,195,220,0.14)" });
    emblem(x + 44, y + 48, 26, k, 0.6, { halo: 0.08 });
    text(t, x + 84, y + 34, { font: "18px PTB", color: "#e4edf1" });
    text(d, x + 84, y + 62, { font: "15px PT", color: DIM }); });
}

// ---------------------------------------------------------------- Ofícios
function oficios(PX, PY, PW) {
  const x0 = PX + 30, w0 = PW - 60;
  header(x0, PY + 40, w0, "OFÍCIOS", 4, "suba a faixa com um treinador quando chegar perto do teto");
  const CW = (w0 - 24) / 2, CH = 300;
  CRAFT.forEach(([k, n, v, m, prim], i) => {
    const col = i % 2, row = Math.floor(i / 2), x = x0 + col * (CW + 24), y = PY + 70 + row * (CH + 24), r = v / m, sel = i === 0;
    box(x, y, CW, CH, { border: sel ? "rgba(130,225,255,0.95)" : prim ? "rgba(216,180,106,0.5)" : "rgba(120,195,220,0.24)", lw: sel ? 2 : 1, glow: sel ? "rgba(90,210,255,0.7)" : null });
    emblem(x + 76, y + 82, 52, k, r);
    text(prim ? "PROFISSÃO" : "SECUNDÁRIA", x + 150, y + 42, { font: "13px PTB", color: prim ? GOLD : "#8aa2ae", ls: 2 });
    text(n, x + 150, y + 76, { font: "28px PTB", color: "#fff" });
    const tierIdx = TIERS.findIndex((t) => m <= t[0]);
    text(TIERS[tierIdx][1], x + 150, y + 112, { font: "18px PT", color: CYAN });
    const vw = tw(String(v), "36px Cinzel");
    text(String(v), x + CW - 30 - tw(` / ${m}`, "19px PT") - 4, y + 82, { font: "36px Cinzel", color: "#fff", align: "right" });
    text(` / ${m}`, x + CW - 30, y + 86, { font: "19px PT", color: DIM, align: "right" });
    bar(x + 30, y + 160, CW - 60, 12, r);
    // escada das faixas
    const sw = (CW - 60) / TIERS.length;
    TIERS.forEach(([cap, nm], t) => { const sx = x + 30 + t * sw, done = t < tierIdx, cur = t === tierIdx;
      g.fillStyle = done ? "rgba(216,180,106,0.9)" : cur ? "rgba(127,224,255,0.9)" : "rgba(120,160,175,0.25)"; g.fillRect(sx, y + 196, sw - 8, 4);
      text(nm, sx, y + 220, { font: cur ? "16px PTB" : "15px PT", color: done ? GOLD2 : cur ? CYAN : "#5f7884" });
      text(String(cap), sx, y + 242, { font: "13px PT", color: "#5f7884" }); });
    const next = TIERS[tierIdx + 1];
    const canTrain = v >= m - 25;
    text(canTrain ? `Pronto para treinar ${next[1]}` : `Faltam ${m - v} pontos  ·  ${next[1]} a partir de ${m - 25}`, x + 30, y + 276, { font: "16px PT", color: canTrain ? GOLD2 : "#b9c9d0" });
  });
}

// ---------------------------------------------------------------- Domínios
function dominios(PX, PY, PW) {
  const x0 = PX + 30, w0 = PW - 60;
  header(x0, PY + 40, w0, "DOMÍNIOS", 9, "perícias já completas: não precisam de treino");
  const CW = (w0 - 2 * 24) / 3;
  DOMS.forEach(([t, list], i) => {
    const x = x0 + i * (CW + 24), y = PY + 70, h = 120 + list.length * 64;
    box(x, y, CW, h, { border: "rgba(216,180,106,0.4)" });
    emblem(x + 50, y + 54, 30, ["star", "armor", "book"][i], 0.97, { halo: 0.12 });
    text(t, x + 96, y + 46, { font: "20px CinzelB", color: GOLD2, ls: 3 });
    text(`${list.length} completa${list.length > 1 ? "s" : ""}`, x + 96, y + 72, { font: "15px PT", color: DIM });
    list.forEach((n, k) => { const yy = y + 116 + k * 64, sel = i === 2 && k === 0;
      box(x + 20, yy, CW - 40, 52, { top: sel ? "rgba(40,34,20,0.9)" : "rgba(20,18,12,0.6)", bot: sel ? "rgba(26,22,12,0.9)" : "rgba(10,9,6,0.7)", border: sel ? "rgba(241,215,154,0.95)" : "rgba(216,180,106,0.3)", lw: sel ? 2 : 1 });
      g.save(); g.beginPath(); g.arc(x + 48, yy + 26, 12, 0, 7); g.fillStyle = "#d8b46a"; g.fill(); g.strokeStyle = "#1a1408"; g.lineWidth = 2.6; g.lineCap = "round";
      g.beginPath(); g.moveTo(x + 42, yy + 26); g.lineTo(x + 46.5, yy + 30.5); g.lineTo(x + 54, yy + 21); g.stroke(); g.restore();
      text(n, x + 72, yy + 27, { font: "18px PT", color: "#f0e6cf" }); });
  });
}

// ---------------------------------------------------------------- detalhe
function detail(x, y, w, h) {
  box(x, y, w, h, { top: "rgba(10,26,36,0.92)", bot: "rgba(4,12,18,0.95)", border: "rgba(120,200,225,0.3)", r: 8 });
  const cx = x + w / 2;
  let d;
  if (PAGE === "arsenal") d = { k: "mace", kind: "PERÍCIA COM ARMAS", n: "Maças", v: 114, m: 115, line: "Falta 1 ponto para o teto do nível 23",
    facts: [["Teto atual", "115  (nível 23)"], ["Próximo teto", "120 no nível 24"], ["Como treinar", "Lute usando maças"]], desc: "Perícia com maças de uma mão." };
  else if (PAGE === "oficios") d = { k: "pick", kind: "PROFISSÃO", n: "Mineração", v: 89, m: 150, line: "Faltam 61 pontos para o teto de Artífice",
    facts: [["Faixa", "Artífice  (até 150)"], ["Próxima faixa", "Especialista  (até 225)"], ["Treinar", "a partir de 125"]], desc: "Extraia minérios e pedras de veios pelo mundo.", btn: "ABANDONAR" };
  else d = { k: "book", kind: "DOMÍNIO  ·  LÍNGUAS", n: "Língua: Comum", v: 300, m: 300, line: "Completa: nada a treinar",
    facts: [["Estado", "Dominada"]], desc: "Permite falar e entender a língua Comum." };
  const r = d.v / d.m;
  emblem(cx, y + 130, 82, d.k, r, { halo: 0.25 });
  text(d.kind, cx, y + 248, { font: "14px PTB", color: GOLD, align: "center", ls: 3 });
  text(d.n, cx, y + 290, { font: "36px Cinzel", color: "#fff", align: "center" });
  const vw = tw(String(d.v), "34px Cinzel"), mw = tw(` / ${d.m}`, "20px PT");
  text(String(d.v), cx - (vw + mw) / 2, y + 340, { font: "34px Cinzel", color: r >= 0.95 ? GOLD2 : "#fff" });
  text(` / ${d.m}`, cx - (vw + mw) / 2 + vw, y + 344, { font: "20px PT", color: DIM });
  bar(x + 36, y + 372, w - 72, 12, r);
  text(d.line, cx, y + 412, { font: "17px PT", color: "#d6e2e8", align: "center" });
  d.facts.forEach(([a, b], i) => { const yy = y + 470 + i * 46; g.fillStyle = "rgba(120,190,215,0.14)"; g.fillRect(x + 30, yy - 24, w - 60, 1);
    text(a, x + 36, yy, { font: "17px PT", color: DIM }); text(b, x + w - 36, yy, { font: "17px PT", color: "#eef4f6", align: "right" }); });
  text(d.desc, cx, y + 640, { font: "16px PT", color: "#9fb3bc", align: "center" });
  if (d.btn) { box(cx - 90, y + h - 70, 180, 40, { top: "rgba(40,20,18,0.8)", bot: "rgba(20,10,8,0.85)", border: "rgba(220,120,100,0.6)" });
    text(d.btn, cx, y + h - 50, { font: "14px PTB", color: "#f0b0a0", align: "center", ls: 2 }); }
}
