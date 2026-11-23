// Gera as texturas dos quadros de unidade (Media/UnitFrames/*.tga, TGA 32 bits).
// Arte de pintura a óleo / pincel seco ("painted brushstroke") do Azaath:
//   HealthFill   preenchimento da barra de vida (512x32, exibida em ~420x22):
//                degradê com pinceladas de alto contraste, veios diagonais "/"
//                na proporção real da tela, manchas de tela e bordas gastas
//   PowerFill    preenchimento da barra de raiva/recurso (512x16, exibida em ~420x9):
//                pinceladas marcadas, sulcos escuros de pincel seco e brilho
//                de tinta espessa (impasto)
//   BarBg        fundo escuro pintado da parte vazia com hachura "/" nítida
//   HealthBorder moldura pintada à mão da barra de vida com pontas em pincel
//   PowerBorder  moldura pintada à mão da barra de raiva/recurso com pontas em pincel
//   Flash        pedaço de vida/recurso perdido: branco quente granulado
// Uso: node tools/media/generate-unitframe-media.js
const fs = require("fs");
const path = require("path");

const OUT = path.join(__dirname, "..", "..", "AzaathUI", "Media", "UnitFrames");
fs.mkdirSync(OUT, { recursive: true });

const clamp01 = (v) => Math.max(0, Math.min(1, v));
const lerp = (a, b, t) => a + (b - a) * t;
const smooth = (e0, e1, x) => {
  const t = clamp01((x - e0) / (e1 - e0));
  return t * t * (3 - 2 * t);
};

function hash(x, y, seed) {
  let h = (x * 374761393 + y * 668265263 + seed * 2147483647) | 0;
  h = Math.imul(h ^ (h >>> 13), 1274126177);
  h ^= h >>> 16;
  return (h >>> 0) / 4294967295;
}

function vnoise(x, y, seed) {
  const xi = Math.floor(x), yi = Math.floor(y);
  const xf = x - xi, yf = y - yi;
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  const a = hash(xi, yi, seed), b = hash(xi + 1, yi, seed);
  const c = hash(xi, yi + 1, seed), d = hash(xi + 1, yi + 1, seed);
  return lerp(lerp(a, b, u), lerp(c, d, u), v);
}

function fbm(x, y, seed, oct = 4) {
  let sum = 0, amp = 0.5, norm = 0, f = 1;
  for (let i = 0; i < oct; i++) {
    sum += amp * vnoise(x * f, y * f, seed + i * 17);
    norm += amp;
    amp *= 0.5;
    f *= 2;
  }
  return sum / norm;
}

// fbm com contraste expandido para 0..1 (evita que a média de oitavas fique presa em 0.4..0.6)
function cfbm(x, y, seed, oct = 4) {
  return smooth(0.27, 0.73, fbm(x, y, seed, oct));
}

function writeTGA(file, w, h, fn, ss = 1) {
  const header = Buffer.alloc(18);
  header[2] = 2;
  header.writeUInt16LE(w, 12);
  header.writeUInt16LE(h, 14);
  header[16] = 32;
  header[17] = 8;
  const data = Buffer.alloc(w * h * 4);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      let r = 0, g = 0, b = 0, a = 0;
      for (let j = 0; j < ss; j++) {
        for (let i = 0; i < ss; i++) {
          const [sr, sg, sb, sa] = fn(x + (i + 0.5) / ss, y + (j + 0.5) / ss);
          r += sr * sa;
          g += sg * sa;
          b += sb * sa;
          a += sa;
        }
      }
      if (a > 0) {
        r /= a;
        g /= a;
        b /= a;
      }
      a /= ss * ss;
      const o = ((h - 1 - y) * w + x) * 4;
      data[o] = Math.round(Math.max(0, Math.min(255, b)));
      data[o + 1] = Math.round(Math.max(0, Math.min(255, g)));
      data[o + 2] = Math.round(Math.max(0, Math.min(255, r)));
      data[o + 3] = Math.round(clamp01(a) * 255);
    }
  }
  fs.writeFileSync(path.join(OUT, file), Buffer.concat([header, data]));
  console.log("gerado UnitFrames/" + file);
}

//------------------------------------------------------------------------------
// 1. HealthFill.tga (512 x 32 -> ~420 x 22 px na tela)
// Pintura a óleo / pincel seco com contraste real (sem estourar em 255):
// - Coordenadas na proporção da tela (sx = x * 420/512, sy = y * 22/32)
// - Cerdas horizontais de pincel seco + manchas de tela + pinceladas "/" a 45°
// - Borda superior/inferior desgastada por cerdas e sulcos escuros
//------------------------------------------------------------------------------
{
  const W = 512, H = 32;
  writeTGA("HealthFill.tga", W, H, (x, y) => {
    const t = x / (W - 1), ty = y / (H - 1);
    const sx = x * (420 / W), sy = y * (22 / H); // pixels reais na tela

    // Base: degradê horizontal controlado (120 -> 215) para deixar margem aos brilhos de pincel
    let lum = lerp(0.48, 0.84, Math.pow(t, 0.72));

    // Cerdas longas horizontais de pincel (variação forte entre fios claros e sulcos escuros)
    const bristle = cfbm(sx / 26, sy / 1.15, 11, 4);
    const fineBristle = vnoise(sx / 6.5, sy / 0.65, 19);
    lum *= lerp(0.72, 1.18, bristle * 0.7 + fineBristle * 0.3);

    // Manchas largas de pintura a óleo na tela (claras e escuras)
    const oilPatch = cfbm(sx / 18, sy / 4.2, 29, 3);
    lum *= lerp(0.80, 1.16, oilPatch);

    // Pinceladas diagonais "/" na proporção 1:1 da tela (45 graus reais no jogo)
    const diagCoord = (sx + (22 - sy) * 1.15);
    const diagStroke = cfbm(diagCoord / 4.2, (sx - sy) / 14, 43, 3);
    const diagHatch = 0.5 + 0.5 * Math.sin((diagCoord / 6.0) * Math.PI * 2);
    lum *= lerp(0.82, 1.15, diagStroke * 0.65 + diagHatch * 0.35);

    // Riscos de pincel seco (sulcos escuros e cristas de tinta espessa)
    const dryScratch = vnoise(sx / 4.5, sy / 0.8, 73);
    if (dryScratch > 0.72) {
      lum += 0.14 * smooth(0.72, 0.92, dryScratch);
    } else if (dryScratch < 0.28) {
      lum *= 1 - 0.25 * smooth(0.28, 0.05, dryScratch);
    }

    // Relevo vertical pintado: crista iluminada no terço superior, base sombreada
    const ridge = 1 - smooth(0.0, 0.35, Math.abs(ty - 0.28));
    lum += 0.08 * ridge;
    lum *= 1 - 0.32 * smooth(0.62, 1.0, ty);
    lum *= 1 - 0.22 * smooth(0.18, 0.0, ty);

    // Bordas superior e inferior "rasgadas" em pincel seco
    const edgeDist = Math.min(sy, 22 - sy);
    const fray = cfbm(sx / 5.5, sy / 1.5, 89, 3);
    if (edgeDist < 2.8) {
      lum *= lerp(0.42 + 0.45 * fray, 1.0, clamp01(edgeDist / 2.8));
    }

    // Pontas esquerda e direita esfumadas em pinceladas irregulares
    const leftFray = 0.015 + 0.025 * cfbm(0, sy / 1.8, 97, 3);
    const rightFray = 0.012 + 0.020 * cfbm(10, sy / 1.8, 103, 3);
    let a = (0.30 + 0.70 * smooth(0, leftFray, t)) * (0.45 + 0.55 * smooth(0, rightFray, 1 - t));
    if (edgeDist < 1.3) {
      a *= lerp(0.35 + 0.65 * fray, 1.0, clamp01(edgeDist / 1.3));
    }

    const v = clamp01(lum) * 255;
    return [v, v * 0.98, v * 0.95, a];
  }, 2);
}

//------------------------------------------------------------------------------
// 2. PowerFill.tga (512 x 16 -> ~420 x 9 px na tela)
// Preenchimento da barra de raiva/recurso: pinceladas de alto contraste na
// proporção 420x9 para que a textura pintada fique bem visível mesmo na barra fina.
//------------------------------------------------------------------------------
{
  const W = 512, H = 16;
  writeTGA("PowerFill.tga", W, H, (x, y) => {
    const t = x / (W - 1), ty = y / (H - 1);
    const sx = x * (420 / W), sy = y * (9 / H);

    // Degradê horizontal: esquerda mais densa/escura -> direita luminosa
    let lum = lerp(0.50, 0.88, Math.pow(t, 0.75));

    // Cerdas horizontais fortes + manchas de óleo
    const bristle = cfbm(sx / 18, sy / 0.85, 131, 4);
    const mottle = cfbm(sx / 11, sy / 2.2, 149, 3);
    lum *= lerp(0.68, 1.22, bristle * 0.65 + mottle * 0.35);

    // Pinceladas diagonais "/" na proporção 1:1 da tela
    const diagCoord = sx + (9 - sy) * 1.25;
    const diagWave = 0.5 + 0.5 * Math.sin((diagCoord / 4.8) * Math.PI * 2);
    const diagNoise = cfbm(diagCoord / 3.2, sy / 1.5, 163, 2);
    lum *= lerp(0.76, 1.20, diagWave * 0.5 + diagNoise * 0.5);

    // Sulcos escuros de pincel seco
    const scratch = vnoise(sx / 3.5, sy / 0.65, 173);
    if (scratch < 0.30) {
      lum *= 1 - 0.30 * smooth(0.30, 0.05, scratch);
    } else if (scratch > 0.72) {
      lum += 0.14 * smooth(0.72, 0.95, scratch);
    }

    // Relevo vertical: crista clara no meio-topo, bordas escuras
    const ridge = 1 - smooth(0.0, 0.40, Math.abs(ty - 0.32));
    lum += 0.10 * ridge;
    lum *= 1 - 0.36 * smooth(0.58, 1.0, ty);
    lum *= 1 - 0.25 * smooth(0.22, 0.0, ty);

    const leftFray = 0.015 + 0.025 * cfbm(0, sy / 1.2, 179, 2);
    const a = 0.35 + 0.65 * smooth(0, leftFray, t);
    const v = clamp01(lum) * 255;
    return [v, v * 0.98, v * 0.94, a];
  }, 2);
}

//------------------------------------------------------------------------------
// 3. Flash.tga (256 x 32)
// Pedaço de dano/recurso recém-perdido: branco quente granulado com pinceladas.
//------------------------------------------------------------------------------
{
  const W = 256, H = 32;
  writeTGA("Flash.tga", W, H, (x, y) => {
    const ty = y / (H - 1);
    const sx = x * (420 / W), sy = y * (22 / H);
    let v = 0.78 + 0.22 * cfbm(sx / 10, sy / 1.4, 211, 3);
    v -= 0.20 * smooth(0.50, 0.85, vnoise(sx / 2.5, sy / 1.1, 223));
    v *= 1 - 0.18 * Math.pow(Math.abs(ty - 0.45) / 0.55, 2);
    v = clamp01(v);
    return [252 * v, 246 * v, 232 * v, 1];
  }, 2);
}

//------------------------------------------------------------------------------
// 4. BarBg.tga (512 x 32)
// Fundo escuro pintado da parte vazia: hachura diagonal "/" na proporção 1:1
// da tela (420x22), manchas de tinta sépia/carvão e cavidade sombreada.
//------------------------------------------------------------------------------
{
  const W = 512, H = 32;
  writeTGA("BarBg.tga", W, H, (x, y) => {
    const t = x / (W - 1), ty = y / (H - 1);
    const sx = x * (420 / W), sy = y * (22 / H);

    // Hachura diagonal "/" na proporção real da tela (período ~7px)
    const p = (((sx + (22 - sy)) % 7.0) + 7.0) % 7.0 / 7.0;
    const hatch = 0.5 + 0.5 * Math.sin(p * Math.PI * 2);

    // Manchas de tela e cerdas horizontais
    const canvas = cfbm(sx / 16, sy / 3.2, 307, 3);
    const bristle = cfbm(sx / 28, sy / 1.1, 317, 3);
    const v = clamp01(0.45 * hatch + 0.35 * canvas + 0.20 * bristle);

    let r = lerp(8, 44, v);
    let g = lerp(6, 31, v);
    let b = lerp(5, 23, v);

    // Sombra interna nas bordas superior e inferior
    const edgeY = Math.min(ty, 1 - ty) * 2;
    const innerShadow = lerp(0.45, 1.0, smooth(0.0, 0.45, edgeY));
    r *= innerShadow;
    g *= innerShadow;
    b *= innerShadow;

    // Borda externa levemente esfiapada em pincel
    const edgeX = Math.min(sx, 420 - sx);
    const fray = cfbm(sx / 6, sy / 2, 331, 2);
    const alpha = 0.88 * smooth(0.0, 2.5 + 2.0 * fray, edgeX);
    return [r, g, b, alpha];
  }, 2);
}

//------------------------------------------------------------------------------
// 5. HealthBorder.tga (512 x 32) e PowerBorder.tga (512 x 16)
// Moldura pintada fina e discreta no estilo Azaath:
// - Filete sutil de 1px com leve micro-textura de pincel
// - Sem projeções exageradas ou sombras pesadas
// - Tons neutros de ferro/ardósia escuro com leve brilho bronze
//------------------------------------------------------------------------------
function generatePaintedBorder(file, W, H, screenH, strokeW, seedBase) {
  writeTGA(file, W, H, (px, py) => {
    const sx = px * (420 / W);
    const sy = py * (screenH / H);

    const dTop = sy;
    const dBot = screenH - sy;
    const dLeft = sx;
    const dRight = 420 - sx;

    // Levíssima oscilação orgânica do traço
    const jitterY = (vnoise(sx / 12, sy / 2, seedBase + 1) - 0.5) * 0.25;
    const jitterX = (vnoise(sy / 2, sx / 12, seedBase + 2) - 0.5) * 0.35;

    const dV = Math.min(dTop + jitterY, dBot - jitterY);
    const dH = Math.min(dLeft + jitterX, dRight - jitterX);
    const d = Math.min(dV, dH);

    const maxReach = strokeW + 0.9;
    if (d > maxReach || d < -0.2) return [0, 0, 0, 0];

    const isHoriz = dV <= dH;
    const coord = isHoriz ? sx : sy * 2.5 + (dLeft < dRight ? 100 : 300);
    const sideSeed = seedBase + (dTop < dBot ? 10 : 20);

    // Variação suave de pressão de pincel
    const k = 0.82 + 0.28 * (vnoise(coord / 16, 2.5, sideSeed) - 0.5);

    // Perfil do filete fino (1 pixel suave)
    const coreCenter = strokeW * 0.50;
    const core = Math.max(0, 1 - Math.abs(d - coreCenter) / (strokeW * 0.65));
    const shadow = Math.max(0, 1 - Math.abs(d - 0.15) / 0.55) * 0.35;

    const line = clamp01(core * k);
    const alpha = clamp01(line * 0.62 + shadow * 0.25);
    if (alpha <= 0.01) return [0, 0, 0, 0];

    // Tom ferro/ardósia discreto com topo levemente iluminado
    const topLight = dTop < dBot ? 1.15 : 0.85;
    const r = Math.round(lerp(28, 120 * topLight, line));
    const g = Math.round(lerp(26, 114 * topLight, line));
    const b = Math.round(lerp(25, 106 * topLight, line));
    return [r, g, b, alpha];
  }, 2);
}

generatePaintedBorder("HealthBorder.tga", 512, 32, 22, 1.0, 400);
generatePaintedBorder("PowerBorder.tga", 512, 16, 9, 0.9, 500);
