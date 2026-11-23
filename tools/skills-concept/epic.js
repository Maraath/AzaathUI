// Fundo épico da aba Perícias: "O Vórtice do Arsenal" sobre o salão rúnico
// (fundo atual de Perícias, StageBackdrop, ampliado 4x pelo Real-ESRGAN -> stage.js).
// Usa os utilitários de art.html (g, W, H, glow, rune, drawWeapon, noiseLayer...).
function background() {
  // 1. a sala pintada
  const S = 2250 / STAGE_IMG.width, OX = -125;
  g.imageSmoothingQuality = "high";
  g.drawImage(STAGE_IMG, OX, 0, STAGE_IMG.width * S, STAGE_IMG.height * S);
  let gr = g.createRadialGradient(1000, 560, 200, 1000, 600, 1150);
  gr.addColorStop(0, "rgba(0,0,0,0)"); gr.addColorStop(0.6, "rgba(0,4,10,0.35)"); gr.addColorStop(1, "rgba(0,2,6,0.85)");
  g.fillStyle = gr; g.fillRect(0, 0, W, H);

  const DX = 1000, DY = 868; // centro do estrado
  const add = (fn) => { g.save(); g.globalCompositeOperation = "lighter"; fn(); g.restore(); };

  // 2. coluna de luz subindo do estrado
  add(() => {
    for (const [w, a] of [[520, 0.08], [300, 0.12], [150, 0.2], [60, 0.35], [18, 0.5]]) {
      gr = g.createLinearGradient(DX - w / 2, 0, DX + w / 2, 0);
      gr.addColorStop(0, "rgba(90,200,255,0)"); gr.addColorStop(0.5, `rgba(150,230,255,${a})`); gr.addColorStop(1, "rgba(90,200,255,0)");
      g.fillStyle = gr; g.beginPath(); g.moveTo(DX - w * 0.35, 0); g.lineTo(DX + w * 0.35, 0); g.lineTo(DX + w / 2, DY); g.lineTo(DX - w / 2, DY); g.fill(); }
  });
  gr = g.createLinearGradient(0, 0, 0, 420); gr.addColorStop(0, "rgba(2,6,12,0.75)"); gr.addColorStop(1, "rgba(2,6,12,0)"); g.fillStyle = gr; g.fillRect(0, 0, W, 420);

  // 3. veios de energia rachando o chão a partir do estrado
  seed = 77;
  add(() => {
    for (let i = 0; i < 11; i++) {
      let a = Math.PI * (0.04 + 0.92 * (i / 10)) + (rnd() - 0.5) * 0.1;
      let x = DX + Math.cos(a) * 360, y = DY + Math.sin(a) * 58 + 10;
      const pts = [[x, y]]; const L = 3 + rnd() * 5;
      for (let k = 0; k < L; k++) { a += (rnd() - 0.5) * 0.7; const st = 30 + rnd() * 40; x += Math.cos(a) * st; y += Math.sin(a) * st * 0.3 + 3; pts.push([x, y]); }
      for (const [lw, al, bl] of [[6, 0.06, 18], [2.5, 0.2, 10], [1.1, 0.5, 4]]) {
        g.strokeStyle = `rgba(110,220,255,${al})`; g.lineWidth = lw; g.shadowColor = "rgba(90,210,255,1)"; g.shadowBlur = bl; g.lineJoin = "round";
        g.beginPath(); pts.forEach((p, j) => j ? g.lineTo(p[0], p[1]) : g.moveTo(p[0], p[1])); g.stroke(); }
    }
  });

  // 4. bigorna no estrado, recortada contra a luz, com metal em brasa
  const AY = DY + 8;
  g.save(); g.translate(DX, AY); g.scale(0.72, 0.72); g.translate(-DX, -AY);
  g.save(); g.shadowColor = "rgba(0,0,0,0.8)"; g.shadowBlur = 30;
  gr = g.createLinearGradient(DX - 150, 0, DX + 150, 0); gr.addColorStop(0, "#03070b"); gr.addColorStop(0.5, "#0e1a24"); gr.addColorStop(1, "#02050a");
  g.fillStyle = gr; g.beginPath();
  g.moveTo(DX - 70, AY); g.lineTo(DX - 46, AY - 62); g.lineTo(DX - 58, AY - 74); g.lineTo(DX - 168, AY - 80); g.quadraticCurveTo(DX - 226, AY - 92, DX - 246, AY - 118);
  g.lineTo(DX + 140, AY - 118); g.lineTo(DX + 150, AY - 78); g.lineTo(DX + 60, AY - 72); g.lineTo(DX + 48, AY - 62); g.lineTo(DX + 74, AY); g.closePath(); g.fill(); g.restore();
  add(() => { g.strokeStyle = "rgba(255,170,110,0.6)"; g.lineWidth = 3; g.beginPath(); g.moveTo(DX - 246, AY - 118); g.lineTo(DX + 140, AY - 118); g.lineTo(DX + 150, AY - 78); g.stroke(); });
  add(() => {
    glow(DX - 40, AY - 124, 330, "255,130,50", 0.30); glow(DX - 40, AY - 122, 90, "255,200,120", 0.8);
    g.fillStyle = "rgba(255,200,120,1)"; g.beginPath(); g.moveTo(DX - 150, AY - 122); g.lineTo(DX + 50, AY - 130); g.lineTo(DX + 66, AY - 122); g.lineTo(DX - 150, AY - 117); g.fill();
    seed = 8; for (let i = 0; i < 90; i++) { const t = rnd(), ang = -Math.PI / 2 + (rnd() - 0.5) * 1.6, d = 40 + t * 380;
      const x = DX - 40 + Math.cos(ang) * d, y = AY - 124 + Math.sin(ang) * d * 0.9, al = (1 - t) * 0.95;
      glow(x, y, 7, "255,150,60", al * 0.6); g.strokeStyle = `rgba(255,215,160,${al})`; g.lineWidth = 1.6;
      g.beginPath(); g.moveTo(x, y); g.lineTo(x - Math.cos(ang) * 9, y - Math.sin(ang) * 9); g.stroke(); }
  });
  g.restore();

  // 5. o vórtice de lâminas espectrais
  const kinds = ["sword", "axe", "mace", "great", "bow", "dagger", "spear", "axe2", "shield", "mace2", "sword", "gun", "thrown", "great", "axe", "spear", "dagger", "sword", "mace", "axe2", "bow", "great", "sword", "spear"];
  const N = kinds.length, TURNS = 2.6;
  const spiral = (u, off) => { const t = u * TURNS * Math.PI * 2 + 0.6 + (off || 0); const R = lerp(420, 140, Math.pow(u, 0.9)), y0 = lerp(DY - 290, 185, u);
    return { t, R, x: DX + Math.cos(t) * R, y: y0 + Math.sin(t) * R * 0.22, d: Math.sin(t) }; };
  const blades = kinds.map((k, i) => ({ k, u: i / (N - 1), ...spiral(i / (N - 1)) }));
  function ribbons(front) {
    add(() => {
      for (const [off, al, lw] of [[0, 0.5, 2.2], [0.25, 0.25, 1.2], [-0.3, 0.2, 1], [0.6, 0.14, 4]]) {
        g.strokeStyle = `rgba(130,225,255,${al * (front ? 1 : 0.5)})`; g.lineWidth = lw; g.shadowColor = "rgba(90,210,255,1)"; g.shadowBlur = 14;
        g.beginPath(); let started = false;
        for (let s = 0; s <= 700; s++) { const p = spiral(s / 700, off);
          if ((p.d > 0) === front) { started ? g.lineTo(p.x, p.y) : g.moveTo(p.x, p.y); started = true; } else started = false; }
        g.stroke(); }
    });
  }
  function bladesPass(front) {
    for (const b of blades) { if ((b.d > 0) !== front) continue;
      const s = lerp(1.35, 0.85, b.u) * (1 + b.d * 0.18);
      const ang = Math.PI / 2 + Math.cos(b.t) * 0.55 + (b.d > 0 ? 0.25 : -0.25); // lâminas deitadas, apontando no sentido do giro
      const vis = lerp(1, 0.6, b.u) * (front ? 1 : 0.6);
      add(() => { g.filter = "blur(10px)"; drawWeapon(b.k, b.x, b.y, s * 1.08, ang, `rgba(80,200,255,${0.55 * vis})`); g.filter = "none";
        g.filter = "blur(3px)"; drawWeapon(b.k, b.x, b.y, s, ang, `rgba(140,230,255,${0.45 * vis})`); g.filter = "none"; });
      const mg = g.createLinearGradient(-25, 0, 25, 0); mg.addColorStop(0, `rgba(10,24,34,${0.85 * vis})`); mg.addColorStop(0.5, `rgba(60,110,135,${0.9 * vis})`); mg.addColorStop(1, `rgba(6,14,22,${0.85 * vis})`);
      drawWeapon(b.k, b.x, b.y, s, ang, mg, `rgba(190,245,255,${0.9 * vis})`, 1.3);
      add(() => { g.strokeStyle = `rgba(150,230,255,${0.22 * vis})`; g.lineWidth = 12 * s; g.lineCap = "round"; g.filter = "blur(7px)";
        g.beginPath(); for (let k = 0; k <= 14; k++) { const p = spiral(b.u - k * 0.006); k ? g.lineTo(p.x, p.y) : g.moveTo(p.x, p.y); }
        g.stroke(); g.filter = "none"; });
    }
  }
  ribbons(false); bladesPass(false);

  // 6. (a auréola rúnica do topo foi retirada: ficava por cima da barra de informações)

  bladesPass(true); ribbons(true);

  // 7. lâminas cravadas no chão em primeiro plano (moldura)
  const planted = [[120, 1150, -0.22, 3.3, "great"], [250, 1180, 0.14, 2.8, "sword"], [40, 1120, 0.05, 3.6, "spear"], [1880, 1150, 0.2, 3.3, "great"], [1760, 1185, -0.12, 2.9, "axe2"], [1965, 1125, -0.05, 3.6, "spear"]];
  for (const [x, y, a, s, k] of planted) {
    g.save(); g.filter = "blur(2px)";
    const pg = g.createLinearGradient(-30, 0, 30, 0); pg.addColorStop(0, "#010305"); pg.addColorStop(0.6, "#0a1620"); pg.addColorStop(1, "#010305");
    drawWeapon(k, x, y - 52 * s, s, a + Math.PI, pg, "rgba(110,200,230,0.25)", 2); g.restore();
  }

  // 8. névoa baixa, poeira de luz, vinheta
  const fog = noiseLayer(500, 282, (i, j) => { const x = i / 500, y = j / 282, n = fbm(x * 5, y * 9, 4, 5), n2 = fbm(x * 11 + 7, y * 16, 9, 4);
    const band = sstep(0.62, 0.95, y) * 0.9; const a = clamp((n * 0.75 + n2 * 0.35 - 0.38) * 2.4, 0, 1) * band; return [80, 180, 215, a * 140]; });
  g.save(); g.globalCompositeOperation = "screen"; g.drawImage(fog, 0, 0, W, H); g.restore();
  seed = 5;
  add(() => { for (let i = 0; i < 260; i++) { const x = rnd() * W, y = rnd() * H, r = rnd() < 0.08 ? 2 + rnd() * 3 : 0.6 + rnd() * 1.5, a = 0.2 + rnd() * 0.7;
    const near = 1 - Math.min(1, Math.hypot(x - DX, (y - 520) * 1.3) / 800); if (rnd() > 0.25 + near * 0.75) continue;
    glow(x, y, r * 5, "120,220,255", a * 0.5); g.fillStyle = `rgba(215,245,255,${a})`; g.beginPath(); g.arc(x, y, r * 0.6, 0, 7); g.fill(); } });
  gr = g.createRadialGradient(DX, 560, 500, DX, 560, 1250); gr.addColorStop(0, "rgba(0,0,0,0)"); gr.addColorStop(1, "rgba(0,2,5,0.8)"); g.fillStyle = gr; g.fillRect(0, 0, W, H);
  // faixa do topo calma: cabeçalho e cards de navegação ficam sobre fundo escuro
  gr = g.createLinearGradient(0, 0, 0, 300); gr.addColorStop(0, "rgba(1,4,8,0.92)"); gr.addColorStop(0.7, "rgba(1,4,8,0.55)"); gr.addColorStop(1, "rgba(1,4,8,0)");
  g.fillStyle = gr; g.fillRect(0, 0, W, 300);
}
