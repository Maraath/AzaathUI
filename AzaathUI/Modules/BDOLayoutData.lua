-- GERADO por tools/bdo-hud-concept/gen.js: não editar à mão.
-- HUD "bdo" em unidades da UI, relativas ao canto superior esquerdo da HUD.
local _, Azaath = ...
Azaath.BDO = {
    hud = { w = 470, h = 137 },
    diamond = { x = 0, y = 0, size = 136.2 },
    ringEdge = 0.0565, -- vértice do filete de XP (fração da caixa a partir da borda)
    hp = { x = 100, y = 31, w = 368, h = 32 },
    res = { x = 117, y = 66, w = 348, h = 22 },
    hpPoly = { { 101.5, 32.4 }, { 437, 32.4 }, { 466.4, 61.8 }, { 130.9, 61.8 } },
    resPoly = { { 137.9, 67.4 }, { 463.6, 67.4 }, { 444, 87 }, { 118.3, 87 } },
    levelText = { 69.5, 49.9 },
    pctText = { 70.2, 79.9 },
    hpText = { 284, 47 },
    resText = { 291, 77 },
    -- Noto Sans Medium: algarismos = 0.714 do tamanho -> 15 px (nível) e 8.5 px (%) do print
    fonts = { level = 29.4, pct = 16.7, bar = 14, res = 13 },
    flow = { { tile = 150, speed = 0.045, vScale = 1, alpha = 0.17 }, { tile = 230, speed = -0.028, vScale = 0.7, alpha = 0.12 } },
}
