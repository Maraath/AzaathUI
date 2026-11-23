// Silhuetas das armas/ofícios (apontando para cima, ~100 de altura, origem no centro).
// Usadas pela arte de conceito (art.html) e pelas texturas do jogo (gen.html).
const WEAPON = {
  sword(p) { p.moveTo(0, -50); p.lineTo(-4.5, -42); p.lineTo(-4.5, 18); p.lineTo(4.5, 18); p.lineTo(4.5, -42); p.closePath();
    p.rect(-17, 18, 34, 5); p.rect(-2.6, 23, 5.2, 19); p.moveTo(4.5, 46); p.arc(0, 46, 4.5, 0, 7); },
  great(p) { p.moveTo(0, -56); p.lineTo(-6, -46); p.lineTo(-6, 22); p.lineTo(6, 22); p.lineTo(6, -46); p.closePath();
    p.moveTo(-24, 20); p.lineTo(-20, 28); p.lineTo(20, 28); p.lineTo(24, 20); p.closePath(); p.rect(-3, 28, 6, 22); p.moveTo(5, 54); p.arc(0, 54, 5, 0, 7); },
  dagger(p) { p.moveTo(0, -34); p.lineTo(-5, -24); p.lineTo(-4, 10); p.lineTo(4, 10); p.lineTo(5, -24); p.closePath();
    p.moveTo(-13, 10); p.quadraticCurveTo(0, 6, 13, 10); p.lineTo(13, 14); p.lineTo(-13, 14); p.closePath(); p.rect(-2.5, 14, 5, 16); p.moveTo(4, 33); p.arc(0, 33, 4, 0, 7); },
  axe(p) { p.rect(-2.5, -44, 5, 94); p.moveTo(2, -40); p.quadraticCurveTo(14, -36, 22, -48); p.quadraticCurveTo(34, -24, 22, 0); p.quadraticCurveTo(14, -12, 2, -10); p.closePath(); },
  axe2(p) { p.rect(-3, -50, 6, 104); p.moveTo(3, -42); p.quadraticCurveTo(16, -38, 26, -52); p.quadraticCurveTo(40, -24, 26, 4); p.quadraticCurveTo(16, -10, 3, -8); p.closePath();
    p.moveTo(-3, -42); p.quadraticCurveTo(-16, -38, -26, -52); p.quadraticCurveTo(-40, -24, -26, 4); p.quadraticCurveTo(-16, -10, -3, -8); p.closePath(); p.moveTo(0, -60); p.lineTo(4, -50); p.lineTo(-4, -50); p.closePath(); },
  mace(p) { p.rect(-2.5, -18, 5, 66); p.moveTo(12, -32); p.arc(0, -32, 12, 0, 7);
    for (let i = 0; i < 6; i++) { const a = i / 6 * Math.PI * 2; p.moveTo(Math.cos(a) * 10, -32 + Math.sin(a) * 10); p.lineTo(Math.cos(a + 0.25) * 19, -32 + Math.sin(a + 0.25) * 19); p.lineTo(Math.cos(a + 0.5) * 10, -32 + Math.sin(a + 0.5) * 10); } },
  mace2(p) { p.rect(-3, -30, 6, 86); p.moveTo(-24, -48); p.lineTo(24, -48); p.lineTo(28, -40); p.lineTo(28, -22); p.lineTo(24, -16); p.lineTo(-24, -16); p.lineTo(-28, -22); p.lineTo(-28, -40); p.closePath(); },
  bow(p) { p.moveTo(-4, -48); p.quadraticCurveTo(30, -26, 6, 0); p.quadraticCurveTo(30, 26, -4, 48); p.lineTo(-1, 48); p.quadraticCurveTo(24, 26, 2, 0); p.quadraticCurveTo(24, -26, -1, -48); p.closePath(); p.rect(-5, -48, 1.6, 96); },
  gun(p) { p.rect(-3, -54, 6, 66); p.rect(-4.5, -54, 9, 4); p.moveTo(-4, 12); p.lineTo(4, 12); p.lineTo(12, 48); p.lineTo(-2, 52); p.lineTo(-6, 24); p.closePath(); p.rect(3, 8, 8, 4); },
  thrown(p) { for (const a of [-0.45, 0, 0.45]) { const c = Math.cos(a), s = Math.sin(a); const T = (x, y) => [x * c - y * s, x * s + y * c + 8];
    const pts = [[0, -44], [-4, -34], [-3, -4], [3, -4], [4, -34]]; p.moveTo(...T(...pts[0])); for (const q of pts.slice(1)) p.lineTo(...T(...q)); p.closePath();
    const r = [[-2, -4], [2, -4], [2, 12], [-2, 12]]; p.moveTo(...T(...r[0])); for (const q of r.slice(1)) p.lineTo(...T(...q)); p.closePath(); } },
  fist(p) { p.moveTo(-20, -20); p.quadraticCurveTo(-22, -34, -10, -34); p.lineTo(16, -34); p.quadraticCurveTo(24, -34, 24, -24); p.lineTo(24, 4); p.quadraticCurveTo(24, 18, 12, 22);
    p.lineTo(12, 44); p.lineTo(-14, 44); p.lineTo(-14, 22); p.quadraticCurveTo(-26, 14, -24, 0); p.closePath(); },
  shield(p) { p.moveTo(-30, -38); p.quadraticCurveTo(0, -46, 30, -38); p.lineTo(30, -6); p.quadraticCurveTo(28, 26, 0, 46); p.quadraticCurveTo(-28, 26, -30, -6); p.closePath(); },
  spear(p) { p.rect(-2, -30, 4, 90); p.moveTo(0, -64); p.lineTo(-7, -42); p.lineTo(0, -30); p.lineTo(7, -42); p.closePath(); },
  pick(p) { p.rect(-2.5, -30, 5, 76); p.moveTo(-34, -22); p.quadraticCurveTo(0, -48, 34, -22); p.quadraticCurveTo(0, -38, -34, -22); p.closePath(); p.rect(-6, -40, 12, 12); },
  pan(p) { p.moveTo(18, -6); p.arc(0, -6, 18, 0, 7); p.rect(-3, 10, 6, 36); p.moveTo(-14, -44); p.quadraticCurveTo(-8, -36, -14, -30); p.moveTo(0, -48); p.quadraticCurveTo(6, -38, 0, -30); },
  hook(p) { p.rect(-1.5, -50, 3, 70); p.moveTo(1.5, 18); p.arc(-10, 18, 11.5, 0, Math.PI, false); p.lineTo(-18.5, 18); p.arc(-10, 18, 8.5, Math.PI, 0, true); p.closePath(); p.moveTo(-21.5, 18); p.lineTo(-26, 8); p.lineTo(-18.5, 14); },
  cross(p) { p.rect(-9, -36, 18, 72); p.rect(-36, -9, 72, 18); },
  // --- armas extras ---
  staff(p) { p.rect(-2.5, -34, 5, 88); p.moveTo(10, -44); p.arc(0, -44, 10, 0, 7); p.moveTo(-14, -30); p.quadraticCurveTo(0, -24, 14, -30); p.lineTo(12, -26); p.quadraticCurveTo(0, -20, -12, -26); p.closePath(); },
  crossbow(p) { p.rect(-3, -44, 6, 92); p.moveTo(-40, -14); p.quadraticCurveTo(0, -40, 40, -14); p.lineTo(40, -9); p.quadraticCurveTo(0, -34, -40, -9); p.closePath();
    p.moveTo(-39, -12); p.lineTo(-38, -10); p.lineTo(0, 8); p.lineTo(38, -10); p.lineTo(39, -12); p.lineTo(0, 5); p.closePath(); p.moveTo(0, -56); p.lineTo(-5, -44); p.lineTo(5, -44); p.closePath(); },
  wand(p) { p.moveTo(-2.5, -26); p.lineTo(2.5, -26); p.lineTo(4, 48); p.lineTo(-4, 48); p.closePath();
    p.moveTo(0, -50); p.lineTo(8, -38); p.lineTo(0, -26); p.lineTo(-8, -38); p.closePath(); },
  claw(p) { p.moveTo(-18, 10); p.lineTo(18, 10); p.lineTo(16, 44); p.lineTo(-16, 44); p.closePath(); p.rect(-20, 18, 40, 5);
    for (const x of [-12, 0, 12]) { p.moveTo(x - 4, 10); p.lineTo(x + 0.5 * x / 6, -42 - (x === 0 ? 8 : 0)); p.lineTo(x + 4, 10); p.closePath(); } },
  // --- ofícios ---
  flask(p) { p.rect(-6, -48, 12, 6); p.moveTo(-5, -42); p.lineTo(5, -42); p.lineTo(5, -14); p.lineTo(30, 34); p.quadraticCurveTo(32, 46, 20, 46); p.lineTo(-20, 46); p.quadraticCurveTo(-32, 46, -30, 34); p.lineTo(-5, -14); p.closePath(); },
  hammer(p) { p.rect(-3, -22, 6, 72); p.moveTo(-30, -44); p.lineTo(16, -44); p.lineTo(30, -38); p.lineTo(30, -26); p.lineTo(16, -20); p.lineTo(-30, -20); p.closePath(); },
  leaf(p) { p.moveTo(0, -50); p.bezierCurveTo(36, -26, 30, 24, 0, 40); p.bezierCurveTo(-30, 24, -36, -26, 0, -50); p.closePath(); p.rect(-1.5, 30, 3, 20); },
  needle(p) { p.moveTo(0, -52); p.lineTo(3.5, 30); p.quadraticCurveTo(0, 40, -3.5, 30); p.closePath();
    p.moveTo(14, 46); p.arc(0, 46, 14, 0, 7); p.moveTo(9, 46); p.arc(0, 46, 9, 0, 7, true); },
  gear(p) { const n = 9; for (let i = 0; i < n * 2; i++) { const a = i / (n * 2) * Math.PI * 2, r = i % 2 ? 30 : 40;
      const a1 = a - Math.PI / (n * 2) * 0.8, a2 = a + Math.PI / (n * 2) * 0.8;
      if (i === 0) p.moveTo(Math.cos(a1) * r, Math.sin(a1) * r); else p.lineTo(Math.cos(a1) * r, Math.sin(a1) * r); p.lineTo(Math.cos(a2) * r, Math.sin(a2) * r); }
    p.closePath(); p.moveTo(13, 0); p.arc(0, 0, 13, 0, 7, true); },
  crystal(p) { p.moveTo(0, -52); p.lineTo(16, -26); p.lineTo(10, 30); p.lineTo(0, 44); p.lineTo(-10, 30); p.lineTo(-16, -26); p.closePath(); },
  hide(p) { p.moveTo(-26, -40); p.quadraticCurveTo(-8, -32, 0, -46); p.quadraticCurveTo(8, -32, 26, -40); p.quadraticCurveTo(20, -18, 32, 0); p.quadraticCurveTo(20, 18, 26, 40);
    p.quadraticCurveTo(8, 32, 0, 46); p.quadraticCurveTo(-8, 32, -26, 40); p.quadraticCurveTo(-20, 18, -32, 0); p.quadraticCurveTo(-20, -18, -26, -40); p.closePath(); },
  key(p) { p.moveTo(17, -30); p.arc(0, -30, 17, 0, 7); p.moveTo(8, -30); p.arc(0, -30, 8, 0, 7, true); p.rect(-3.5, -14, 7, 62); p.rect(3, 26, 12, 6); p.rect(3, 38, 9, 6); },
  horseshoe(p) { p.moveTo(-34, 40); p.lineTo(-34, -6); p.arc(0, -6, 34, Math.PI, 0); p.lineTo(34, 40); p.lineTo(20, 40); p.lineTo(20, -6); p.arc(0, -6, 20, 0, Math.PI, true); p.lineTo(-20, 40); p.closePath(); },
  book(p) { p.moveTo(-40, -30); p.quadraticCurveTo(-20, -40, -2, -30); p.lineTo(-2, 40); p.quadraticCurveTo(-20, 30, -40, 40); p.closePath();
    p.moveTo(40, -30); p.quadraticCurveTo(20, -40, 2, -30); p.lineTo(2, 40); p.quadraticCurveTo(20, 30, 40, 40); p.closePath(); },
  armor(p) { p.moveTo(-34, -40); p.lineTo(-14, -44); p.quadraticCurveTo(0, -30, 14, -44); p.lineTo(34, -40); p.lineTo(38, -12); p.lineTo(26, -8); p.lineTo(24, 40); p.quadraticCurveTo(0, 50, -24, 40); p.lineTo(-26, -8); p.lineTo(-38, -12); p.closePath(); },
  star(p) { for (let i = 0; i < 8; i++) { const a = i / 8 * Math.PI * 2 - Math.PI / 2, r = i % 2 ? 16 : 46; i ? p.lineTo(Math.cos(a) * r, Math.sin(a) * r) : p.moveTo(Math.cos(a) * r, Math.sin(a) * r); } p.closePath(); },
};
// ordem das células do atlas SkillsIcons (8 por linha, 128 px, 1024x1024) — a mesma tabela ICON do Lua
const ICON_ORDER = ["sword", "great", "dagger", "axe", "axe2", "mace", "mace2", "bow",
  "gun", "thrown", "fist", "shield", "spear", "staff", "crossbow", "wand",
  "claw", "pick", "pan", "hook", "cross", "flask", "hammer", "leaf",
  "needle", "gear", "crystal", "hide", "key", "horseshoe", "book", "armor",
  "star"];
