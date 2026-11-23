--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Sheet/Attributes.lua
    Ficha do personagem: Códice de atributos e card Atributos & Combate.
    Símbolos comuns vêm de Azaath.SheetUI (Modules/Sheet/Core.lua).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.SheetUI
local _G, floor, format, ipairs = _G, math.floor, string.format, ipairs
local max, min, pcall, tostring = math.max, math.min, pcall, tostring
local type = type
local Call, Char, Display, M = U.Call, U.Char, U.Display, U.M
local MEDIA_ROOT, Num, Pct, SHEET_MEDIA = U.MEDIA_ROOT, U.Num, U.Pct, U.SHEET_MEDIA

--------------------------------------------------------------------------------
-- Códice Flutuante de Poder: Medalhões Circulares de Atributos & Orbes Elementais
--------------------------------------------------------------------------------
local function AP(fn)
    local base, pos, neg = Call(fn, "player")
    if Azaath.AnySecret(base, pos, neg) then return Num(base, "?") end
    return (base or 0) + (pos or 0) + (neg or 0)
end

local function DamageRange(lo, hi, sep)
    lo, hi = Num(lo, nil), Num(hi, nil)
    if not lo or not hi or hi <= 0 then return "—" end
    return format("%d%s%d", floor(lo + 0.5), sep or " – ", floor(hi + 0.5))
end

local function Rating(id)
    return Num(Call(_G.GetCombatRatingBonus, id), 0)
end

local function SpellPower()
    local best = 0
    for school = 2, 7 do
        local sp = Num(Call(_G.GetSpellBonusDamage, school), 0)
        if sp > best then best = sp end
    end
    return best
end

local ATTR_CARDS_DEF = {
    { name = "FORÇA",     stat = "STR", id = 1, icon = "Interface\\Icons\\Spell_Nature_Strength",     color = { 0.96, 0.42, 0.32 }, desc = "Aumenta o Poder de Ataque corpo a corpo e a mitigação com escudos." },
    { name = "AGILIDADE", stat = "AGI", id = 2, icon = "Interface\\Icons\\Ability_Rogue_Sprint",      color = { 0.35, 0.95, 0.58 }, desc = "Aumenta o Poder de Ataque à distância, Crítico, Armadura e Esquiva." },
    { name = "VIGOR",     stat = "STA", id = 3, icon = "Interface\\Icons\\Spell_Holy_WordFortitude",  color = { 0.98, 0.82, 0.38 }, desc = "Expande a vitalidade máxima e a resistência física do seu herói." },
    { name = "INTELECTO", stat = "INT", id = 4, icon = "Interface\\Icons\\Spell_Holy_MagicalSentry",  color = { 0.38, 0.86, 1.00 }, desc = "Aumenta o reservatório de Mana, o Crítico Mágico e o Poder Arcano." },
    { name = "ESPÍRITO",  stat = "SPI", id = 5, icon = "Interface\\Icons\\Spell_Holy_DivineSpirit",   color = { 0.82, 0.58, 1.00 }, desc = "Acelera a regeneração natural de Vida e Mana dentro e fora de combate." },
}

local TELEMETRY_TABS = {
    {
        key = "offense",
        label = "OFENSIVA",
        header = "TELEMETRIA OFENSIVA",
        heroes = {
            {
                label = "DANO PRINCIPAL",
                fn = function() local lo, hi = Call(_G.UnitDamage, "player"); return DamageRange(lo, hi) end,
                desc = "Dano físico causado por cada golpe da arma principal.",
            },
            {
                label = "PODER DE ATAQUE",
                fn = function() return AP(_G.UnitAttackPower) end,
                desc = "Intensifica o dano físico de todas as armas corpo a corpo.",
            },
        },
        gauges = {
            {
                label = "CRÍTICO FÍSICO",
                fn = function()
                    local v = Num(Call(_G.GetCritChance), 0)
                    return Pct(v), min(1, max(0.03, v / 40))
                end,
                desc = "Probabilidade de desferir ataques corpo a corpo com dano crítico.",
            },
            {
                label = "VELOCIDADE",
                fn = function()
                    local s = Num(Call(_G.UnitAttackSpeed, "player"), nil)
                    if not s then return "—", 0.05 end
                    local ratio = min(1, max(0.08, (4.0 - min(3.8, s)) / 2.8))
                    return format("%.2fs", s), ratio
                end,
                desc = "Intervalo em segundos entre golpes consecutivos da arma.",
            },
            {
                label = "TAXA DE ACERTO",
                fn = function()
                    local v = Rating(_G.CR_HIT_MELEE or 6)
                    return Pct(v), v > 0 and min(1, max(0.04, v / 15)) or 0
                end,
                desc = "Reduz a chance de errar golpes contra inimigos de nível superior.",
            },
            {
                label = "PENETRAÇÃO",
                fn = function()
                    local v = Rating(_G.CR_ARMOR_PENETRATION or 25)
                    return Pct(v), v > 0 and min(1, max(0.04, v / 50)) or 0
                end,
                desc = "Ignora uma fração da armadura física do oponente.",
            },
        },
        chips = {
            {
                label = "MAESTRIA",
                fn = function() local ep = Call(_G.GetExpertise); return ep and tostring(ep) or "0" end,
                desc = "Reduz a chance de o alvo esquivar ou aparar seus golpes.",
            },
            {
                label = "LONGO ALCANCE",
                fn = function() local _, lo, hi = Call(_G.UnitRangedDamage, "player"); return DamageRange(lo, hi, "–") end,
                desc = "Dano causado por arcos, bestas, armas de fogo e varinhas.",
            },
        },
    },
    {
        key = "defense",
        label = "DEFESA & GUARDA",
        header = "TELEMETRIA DEFENSIVA",
        heroes = {
            {
                label = "ARMADURA",
                fn = function() local _, eff = UnitArmor("player"); return eff and tostring(eff) or "0" end,
                desc = "Mitiga diretamente todo o dano físico recebido.",
            },
            {
                label = "DEFESA",
                fn = function()
                    local base, mod = Call(_G.UnitDefense, "player")
                    base, mod = Num(base, nil), Num(mod, 0)
                    if base then return format("%d", base + mod) end
                    local d = _G.C_SkillInfo and Call(C_SkillInfo.GetSkillLineInfoByID, 95)
                    if type(d) == "table" and d.rank then
                        return format("%d", Num(d.rank, 0) + Num(d.modifier, 0))
                    end
                    return "—"
                end,
                desc = "Reduz a probabilidade de sofrer acertos críticos de chefes.",
            },
        },
        gauges = {
            {
                label = "ESQUIVA",
                fn = function()
                    local v = Num(Call(_G.GetDodgeChance), 0)
                    return Pct(v), v > 0 and min(1, max(0.04, v / 35)) or 0
                end,
                desc = "Probabilidade de evitar completamente um ataque físico.",
            },
            {
                label = "APARO",
                fn = function()
                    local v = Num(Call(_G.GetParryChance), 0)
                    return Pct(v), v > 0 and min(1, max(0.04, v / 30)) or 0
                end,
                desc = "Probabilidade de defletir um golpe frontal com sua arma.",
            },
            {
                label = "BLOQUEIO",
                fn = function()
                    local v = Num(Call(_G.GetBlockChance), 0)
                    return Pct(v), v > 0 and min(1, max(0.04, v / 35)) or 0
                end,
                desc = "Probabilidade de absorver dano com seu escudo.",
            },
            {
                label = "RESILIÊNCIA",
                fn = function()
                    local r = Num(Call(_G.GetCombatRating, _G.CR_RESILIENCE_CRIT_TAKEN or 15), 0)
                    return tostring(r), r > 0 and min(1, max(0.04, r / 800)) or 0
                end,
                desc = "Reduz o dano recebido de outros jogadores e seus acertos críticos.",
            },
        },
        chips = {
            {
                label = "MOBILIDADE",
                fn = function()
                    local _, run = Call(_G.GetUnitSpeed, "player")
                    run = Num(run, nil)
                    return run and format("%d%%", floor(run / 7 * 100 + 0.5)) or "100%"
                end,
                desc = "Velocidade atual de deslocamento do personagem.",
            },
            {
                label = "MITIGAÇÃO BLOQ.",
                fn = function()
                    local bv = Num(Call(_G.GetShieldBlock), 0)
                    return tostring(bv)
                end,
                desc = "Quantidade de dano físico absorvida ao bloquear com escudo.",
            },
        },
    },
    {
        key = "arcane",
        label = "ARCANO",
        header = "TELEMETRIA ARCANA",
        heroes = {
            {
                label = "PODER MÁGICO",
                fn = SpellPower,
                desc = "Aumenta o dano causado por todos os seus feitiços elementais e arcanos.",
            },
            {
                label = "PODER DE CURA",
                fn = function() return Num(Call(_G.GetSpellBonusHealing), 0) end,
                desc = "Amplifica a restauração de vida de todos os feitiços de cura.",
            },
        },
        gauges = {
            {
                label = "CRÍTICO MÁGICO",
                fn = function()
                    local v = Num(Call(_G.GetSpellCritChance, 2), 0)
                    return Pct(v), v > 0 and min(1, max(0.04, v / 40)) or 0
                end,
                desc = "Probabilidade de feitiços causarem efeito crítico devastador.",
            },
            {
                label = "ACERTO MÁGICO",
                fn = function()
                    local v = Rating(_G.CR_HIT_SPELL or 8)
                    return Pct(v), v > 0 and min(1, max(0.04, v / 17)) or 0
                end,
                desc = "Garante que seus feitiços não sejam resistidos pelo alvo.",
            },
            {
                label = "ACELERAÇÃO",
                fn = function()
                    local v = Rating(_G.CR_HASTE_SPELL or 20)
                    return Pct(v), v > 0 and min(1, max(0.04, v / 40)) or 0
                end,
                desc = "Reduz o tempo de conjuração e o tempo de recarga global.",
            },
            {
                label = "REGEN. DE MANA",
                fn = function()
                    local base = Num(Call(_G.GetManaRegen), nil)
                    if not base then return "0.0 / s", 0 end
                    return format("%.1f / s", base), base > 0 and min(1, max(0.04, base / 120)) or 0
                end,
                desc = "Mana restaurada por segundo fora de conjuração.",
            },
        },
        chips = {
            {
                label = "CRÍTICO DIST.",
                fn = function() return Pct(Call(_G.GetRangedCritChance)) end,
                desc = "Probabilidade de acerto crítico com armas de longo alcance.",
            },
            {
                label = "PODER DISTÂNCIA",
                fn = function() return AP(_G.UnitRangedAttackPower) end,
                desc = "Intensifica o dano de disparos de longo alcance.",
            },
        },
    },
}

--------------------------------------------------------------------------------
-- Card "Atributos & Combate" — réplica da arte de conceito
--   A arte (moldura, constelação, trilhas, esferas, selo elemental) vem do
--   próprio conceito (tools/sheet-concept/gen.js). Tudo é posicionado em
--   coordenadas do conceito (768x1376); o card ocupa x 61..706 / y 62..1315
--   e é escalado inteiro (SetScale) para caber na altura da tela.
--------------------------------------------------------------------------------
local CARD_W, CARD_H = 646, 1254
local CARD_OX, CARD_OY = 61, 62
local CARD_TEX_W, CARD_TEX_H = 1024, 2048

local CARD_COL = {
    head   = { 0.82, 0.84, 0.80 },
    label  = { 0.80, 0.82, 0.80 },
    gray   = { 0.62, 0.66, 0.69 },
    white  = { 0.97, 0.99, 1.00 },
    cyan   = { 0.62, 0.87, 0.89 },
    tabOn  = { 0.89, 1.00, 1.00 },
    tabOff = { 0.60, 0.64, 0.67 },
    dark   = { 0.12, 0.07, 0.00 },
    gold   = { 0.94, 0.90, 0.76 },
    pillOn = { 0.00, 0.15, 0.17 },
}
local HEX_WHITE, HEX_CYAN = "|cfff7fcff", "|cff9edee3"

-- Tamanhos (unidades do conceito; a fonte do card é 6% mais larga que a Segoe)
local FS = { tab = 20, head = 21, label = 19, sub = 16.5, orb = 28, orbTop = 30, hero = 50, pill = 17.5, chip = 19 }

local card = {}          -- referências do card (frame, texturas, textos)
local cardTelemetry = "offense"

-- Converte coordenadas do conceito para o card
local function CX(x) return x - CARD_OX end
local function CY(y) return -(y - CARD_OY) end

local function CardText(parent, x, y, size, col, anchor, regular)
    local media = Azaath.media
    local fs = parent:CreateFontString(nil, "OVERLAY")
    -- tenta a Segoe direto (a sonda do Core pode falhar cedo demais) e só então cai no fallback
    local want = MEDIA_ROOT .. "Fonts\\" .. (regular and "SegoeUI-Regular.ttf" or "SegoeUI-Semibold.ttf")
    local ok = pcall(fs.SetFont, fs, want, size, "")
    local got = ok and fs:GetFont()
    if not (got and got:lower():find("segoeui", 1, true)) then
        fs:SetFont(regular and media.fontCardR or media.fontCard or media.font, size, "")
    end
    if AzaathUIDB then AzaathUIDB.cardFont = fs:GetFont() end
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.55)
    fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
    fs:SetWordWrap(false)
    -- o miolo das maiúsculas fica ~6% da altura abaixo do centro da caixa da fonte
    local oy = CY(y) + size * 0.06
    if anchor == "L" then
        fs:SetJustifyH("LEFT")
        fs:SetPoint("LEFT", parent, "TOPLEFT", CX(x), oy)
    elseif anchor == "R" then
        fs:SetJustifyH("RIGHT")
        fs:SetPoint("RIGHT", parent, "TOPLEFT", CX(x), oy)
    else
        fs:SetJustifyH("CENTER")
        fs:SetPoint("CENTER", parent, "TOPLEFT", CX(x), oy)
    end
    return fs
end

-- Área de passar o mouse (retângulo do conceito) com dica
-- Título de seção: texto centrado + filetes dos dois lados que vão da borda
-- (x 103 / 665 do conceito) até 16 px do texto, seja qual for o tamanho dele
local HEADER_LINE_X0, HEADER_LINE_X1, HEADER_GAP = 103, 665, 16
local function CardHeader(parent, cx, cy, text)
    local fs = CardText(parent, cx, cy, FS.head, CARD_COL.head, "C")
    local function Line(flip)
        local t = parent:CreateTexture(nil, "ARTWORK")
        t:SetTexture(SHEET_MEDIA .. "AttrHeaderLine")
        t:SetBlendMode("ADD")
        t:SetHeight(10)
        if flip then t:SetTexCoord(203 / 256, 0, 0, 10 / 16) else t:SetTexCoord(0, 203 / 256, 0, 10 / 16) end
        return t
    end
    local left, right = Line(false), Line(true)
    local function Fit()
        local half = (fs:GetStringWidth() or 0) * 0.5
        local lx1 = cx - half - HEADER_GAP
        local rx0 = cx + half + HEADER_GAP
        left:ClearAllPoints()
        left:SetPoint("LEFT", parent, "TOPLEFT", CX(HEADER_LINE_X0), CY(cy))
        left:SetWidth(max(1, lx1 - HEADER_LINE_X0))
        right:ClearAllPoints()
        right:SetPoint("LEFT", parent, "TOPLEFT", CX(rx0), CY(cy))
        right:SetWidth(max(1, HEADER_LINE_X1 - rx0))
    end
    function fs:SetHeader(txt)
        self:SetText(txt)
        Fit()
    end
    if text then fs:SetHeader(text) end
    -- a largura do texto só é confiável depois que a fonte foi desenhada: reajusta ao mostrar
    if parent.HookScript then parent:HookScript("OnShow", Fit) end
    return fs
end

local function CardHover(parent, x0, y0, x1, y1, onEnter, onLeave)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", CX(x0), CY(y0))
    f:SetSize(x1 - x0, y1 - y0)
    f:EnableMouse(true)
    f:SetScript("OnEnter", onEnter)
    f:SetScript("OnLeave", onLeave or function() GameTooltip:Hide() end)
    return f
end

local function SimpleTip(owner, title, text, r, g, b)
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText(title, r or 1, g or 0.88, b or 0.45)
    if text then GameTooltip:AddLine(text, 0.9, 0.92, 0.96, true) end
    GameTooltip:Show()
end

-- Preenchimento com ponta arredondada (corpo recortado por texcoord + ponta)
local function MakeFill(parent, x, y, bodyW, h, capW, bodyTex, capTex)
    local f = {}
    f.body = parent:CreateTexture(nil, "ARTWORK")
    f.body:SetTexture(bodyTex)
    f.body:SetPoint("TOPLEFT", parent, "TOPLEFT", CX(x), CY(y))
    f.body:SetHeight(h)
    f.cap = parent:CreateTexture(nil, "ARTWORK")
    f.cap:SetTexture(capTex)
    f.cap:SetSize(capW, h)
    f.cap:SetPoint("TOPLEFT", f.body, "TOPRIGHT", 0, 0)
    f.bodyW = bodyW
    function f:SetRatio(ratio)
        ratio = max(0, min(1, ratio or 0))
        if ratio <= 0 then
            self.body:Hide(); self.cap:Hide()
            return
        end
        local w = max(1, ratio * self.bodyW)
        self.body:SetWidth(w)
        self.body:SetTexCoord(0, w / self.bodyW, 0, 1)
        self.body:Show(); self.cap:Show()
    end
    function f:SetColor(r, g, b)
        self.body:SetVertexColor(r, g, b); self.cap:SetVertexColor(r, g, b)
    end
    function f:SetTextures(bt, ct)
        self.body:SetTexture(bt); self.cap:SetTexture(ct)
    end
    f:SetRatio(0)
    return f
end

-- Barra vital (aceita valores secretos em combate: StatusBar nativo)
local function MakeVitalBar(parent, x, y, bodyW, h, capW, bodyTex, capTex)
    local sb = CreateFrame("StatusBar", nil, parent)
    sb:SetPoint("TOPLEFT", parent, "TOPLEFT", CX(x), CY(y))
    sb:SetSize(bodyW, h)
    sb:SetStatusBarTexture(bodyTex)
    sb:SetMinMaxValues(0, 1)
    sb:SetValue(0)
    local cap = sb:CreateTexture(nil, "ARTWORK")
    cap:SetTexture(capTex)
    cap:SetSize(capW, h)
    local fill = sb:GetStatusBarTexture()
    cap:SetPoint("TOPLEFT", fill, "TOPRIGHT", 0, 0)
    sb.cap = cap
    function sb:SetFillTextures(bt, ct)
        self:SetStatusBarTexture(bt)
        local ft = self:GetStatusBarTexture()
        self.cap:ClearAllPoints()
        self.cap:SetPoint("TOPLEFT", ft, "TOPRIGHT", 0, 0)
        self.cap:SetTexture(ct)
    end
    function sb:SetFillColor(r, g, b)
        self:SetStatusBarColor(r, g, b)
        self.cap:SetVertexColor(r, g, b)
    end
    return sb
end

local function SetVital(sb, cur, mx)
    if Azaath.AnySecret(cur, mx) then
        sb:SetMinMaxValues(0, mx)
        sb:SetValue(cur)
        return
    end
    mx = (mx and mx > 0) and mx or 1
    sb:SetMinMaxValues(0, mx)
    sb:SetValue(max(0, min(cur or 0, mx)))
end

-- Abas: centro do texto de cada sub-aba no conceito e o recorte do destaque
local TAB_CX = { 209, 447.5, 623.5 }
local TAB_HIT = { { 66, 340 }, { 340, 560 }, { 560, 704 } }
local TABACT = { x0 = 64, x1 = 702, y = 66, w = 639, h = 73 }

local function PlaceTabHighlight(i)
    local t = card.tabActive
    if not t then return end
    local dx = TAB_CX[i] - TAB_CX[1]
    local left = max(TABACT.x0, TABACT.x0 + dx)
    local right = min(TABACT.x1, TABACT.x1 + dx)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", card.frame, "TOPLEFT", CX(left), CY(TABACT.y))
    t:SetSize(right - left, TABACT.h)
    local u0 = (left - (TABACT.x0 + dx)) / CARD_TEX_W
    local u1 = (right - (TABACT.x0 + dx)) / CARD_TEX_W
    t:SetTexCoord(u0, u1, 0, TABACT.h / 128)
end

-- Seletor: início de cada pílula ativa (171 px) e centro dos rótulos
local PILL_LEFT = { 107, 299, 491 }
local PILL_TXT = { 192.5, 384, 575 }
local TELE_HEADERS = { offense = "TELEMETRIA DE COMBATE OFENSIVA", defense = "TELEMETRIA DE COMBATE DEFENSIVA", arcane = "TELEMETRIA DE COMBATE ARCANA" }

-- Vértices da constelação (ordem e cores do conceito: Força no topo)
local CONSTELLATION = {
    { id = 1, label = "FORÇA",     cx = 384,   cy = 352.5, r = 34, valCol = "dark",  size = "orbTop", lx = 425, ly = 351,   la = "L", gold = true },
    { id = 3, label = "VIGOR",     cx = 528,   cy = 454.5, r = 30, valCol = "gold",  size = "orb",    lx = 570, ly = 454.5, la = "L", gold = true },
    { id = 4, label = "INTELECTO", cx = 477.5, cy = 622.5, r = 30, valCol = "white", size = "orb",    lx = 478, ly = 670.5, la = "C" },
    { id = 5, label = "ESPÍRITO",  cx = 289,   cy = 622.5, r = 30, valCol = "white", size = "orb",    lx = 289, ly = 670.5, la = "C" },
    { id = 2, label = "AGILIDADE", cx = 238.5, cy = 454,   r = 30, valCol = "white", size = "orb",    lx = 197, ly = 454.5, la = "R" },
}

local RESIST_ORBS = {
    { id = 3, label = "Natureza", cx = 197, cy = 1232, color = { 0.32, 0.95, 0.50 } },
    { id = 2, label = "Fogo",     cx = 290, cy = 1248, color = { 0.98, 0.55, 0.22 } },
    { id = 6, label = "Arcano",   cx = 384, cy = 1253, color = { 0.55, 0.56, 1.00 } },
    { id = 4, label = "Gelo",     cx = 477, cy = 1248, color = { 0.45, 0.88, 1.00 } },
    { id = 5, label = "Sombra",   cx = 571, cy = 1232, color = { 0.78, 0.48, 1.00 } },
}

local function RefreshTelemetry()
    local layer = card.attr
    if not layer then return end
    local def = TELEMETRY_TABS[1]
    for i, t in ipairs(TELEMETRY_TABS) do
        if t.key == cardTelemetry then def = t end
        local on = t.key == cardTelemetry
        local col = on and CARD_COL.pillOn or CARD_COL.gray
        card.pillText[i]:SetTextColor(col[1], col[2], col[3])
        card.pillText[i]:SetShadowColor(0, 0, 0, on and 0 or 0.55)
        if on then
            local left = PILL_LEFT[i]
            card.pillActive:ClearAllPoints()
            card.pillActive:SetPoint("TOPLEFT", layer, "TOPLEFT", CX(84 + (left - 107)), CY(696))
        end
    end
    card.teleHeader:SetHeader(TELE_HEADERS[def.key] or def.header)
    for i, hw in ipairs(card.heroes) do
        local d = def.heroes[i]
        hw.def = d
        hw.label:SetText(d.label)
        local ok, v = pcall(d.fn)
        hw.value:SetText(Display(ok and v or nil))
    end
    for i, gw in ipairs(card.gauges) do
        local d = def.gauges[i]
        gw.def = d
        gw.label:SetText(d.label)
        local ok, v, ratio = pcall(d.fn)
        gw.value:SetText(Display(ok and v or nil))
        gw.fill:SetRatio(ok and ratio or 0)
    end
    for i, cw in ipairs(card.chips) do
        local d = def.chips[i]
        cw.def = d
        local ok, v = pcall(d.fn)
        cw.text:SetText(d.label .. "  " .. HEX_CYAN .. Display(ok and v or nil) .. "|r")
    end
end

local function BuildAttributes(layer)
    local c = Azaath.colors
    card.attr = layer

    -- 1) SINAIS VITAIS -------------------------------------------------------
    CardHeader(layer, 384, 154.5, "SINAIS VITAIS")
    card.healthLabel = CardText(layer, 110, 183.5, FS.label, CARD_COL.label, "L")
    card.healthLabel:SetText("VITALIDADE")
    card.healthValue = CardText(layer, 370, 183, FS.label, CARD_COL.white, "R")
    card.powerLabel = CardText(layer, 397, 183.5, FS.label, CARD_COL.label, "L")
    card.powerValue = CardText(layer, 656, 183, FS.label, CARD_COL.white, "R")

    card.health = MakeVitalBar(layer, 105, 199, 265, 21, 8, SHEET_MEDIA .. "AttrFillHealth", SHEET_MEDIA .. "AttrFillHealthCap")
    card.power = MakeVitalBar(layer, 391, 199, 264, 21, 8, SHEET_MEDIA .. "AttrFillPower", SHEET_MEDIA .. "AttrFillPowerCap")

    card.journey = CardText(layer, 384, 239.5, FS.sub, CARD_COL.gray, "C")
    local jHover = CardHover(layer, 200, 228, 568, 251, function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Jornada", 0.38, 0.92, 1.0)
        if self.xpTip then GameTooltip:AddLine(self.xpTip, 0.92, 0.95, 1.0, true) end
        if self.duraTip then GameTooltip:AddLine(self.duraTip, 0.45, 0.95, 0.68, true) end
        GameTooltip:Show()
    end)
    card.journeyHover = jHover

    -- 2) CONSTELAÇÃO ALQUÍMICA -----------------------------------------------
    CardHeader(layer, 384, 289.5, "CONSTELAÇÃO ALQUÍMICA")
    card.attrNodes = {}
    for _, v in ipairs(CONSTELLATION) do
        local def
        for _, d in ipairs(ATTR_CARDS_DEF) do if d.id == v.id then def = d end end
        local node = CreateFrame("Frame", nil, layer)
        node:SetSize(v.r * 2, v.r * 2)
        node:SetPoint("CENTER", layer, "TOPLEFT", CX(v.cx), CY(v.cy))
        node:EnableMouse(true)

        local glow = node:CreateTexture(nil, "OVERLAY")
        glow:SetTexture(MEDIA_ROOT .. "Glow")
        glow:SetBlendMode("ADD")
        glow:SetSize(v.r * 3.2, v.r * 3.2)
        glow:SetPoint("CENTER")
        if v.gold then glow:SetVertexColor(1.0, 0.82, 0.38, 0.35) else glow:SetVertexColor(0.30, 0.88, 1.0, 0.35) end
        glow:Hide()

        node.value = CardText(layer, v.cx, v.cy, FS[v.size], CARD_COL[v.valCol], "C")
        local lbl = CardText(layer, v.lx, v.ly, FS.label, CARD_COL.label, v.la)
        lbl:SetText(v.label)
        node.def = def

        node:SetScript("OnEnter", function(self)
            glow:Show()
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(v.label, 1, 1, 1)
            if def then GameTooltip:AddLine(def.desc, c.cream[1], c.cream[2], c.cream[3], true) end
            if self.tooltipBonus then
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine(self.tooltipBonus, 0.38, 0.90, 1.0, true)
            end
            GameTooltip:Show()
        end)
        node:SetScript("OnLeave", function() glow:Hide(); GameTooltip:Hide() end)
        card.attrNodes[#card.attrNodes + 1] = node
    end

    -- 3) Seletor OFENSIVA / DEFESA & GUARDA / ARCANO --------------------------
    card.pillActive = layer:CreateTexture(nil, "ARTWORK")
    card.pillActive:SetTexture(SHEET_MEDIA .. "AttrPillActive")
    card.pillActive:SetBlendMode("ADD")
    card.pillActive:SetSize(220, 80)
    card.pillActive:SetTexCoord(0, 220 / 256, 0, 80 / 128)
    card.pillText = {}
    for i, t in ipairs(TELEMETRY_TABS) do
        local b = CreateFrame("Button", nil, layer)
        local x0 = (i == 1) and 107 or PILL_LEFT[i]
        local x1 = (i == 3) and 662 or PILL_LEFT[i + 1]
        b:SetPoint("TOPLEFT", layer, "TOPLEFT", CX(x0), CY(715))
        b:SetSize(x1 - x0, 42)
        card.pillText[i] = CardText(layer, PILL_TXT[i], 737, FS.pill, CARD_COL.gray, "C")
        card.pillText[i]:SetText(t.label)
        b:SetScript("OnClick", function()
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            cardTelemetry = t.key
            M.db.telemetry = t.key
            RefreshTelemetry()
        end)
        b:SetScript("OnEnter", function()
            if cardTelemetry ~= t.key then card.pillText[i]:SetTextColor(1, 1, 1) end
        end)
        b:SetScript("OnLeave", function()
            if cardTelemetry ~= t.key then
                local g = CARD_COL.gray
                card.pillText[i]:SetTextColor(g[1], g[2], g[3])
            end
        end)
    end

    -- 4) COMBAT TELEMETRY -----------------------------------------------------
    card.teleHeader = CardHeader(layer, 384, 794)
    card.heroes = {}
    local HERO = { { 240.5, 241, 100, 380 }, { 525.5, 526.5, 388, 668 } }
    for i, h in ipairs(HERO) do
        local hw = {}
        hw.value = CardText(layer, h[1], 843.5, FS.hero, CARD_COL.white, "C")
        hw.label = CardText(layer, h[2], 881.5, FS.label, CARD_COL.gray, "C")
        CardHover(layer, h[3], 815, h[4], 895, function(self)
            hw.value:SetTextColor(0.62, 0.95, 1.0)
            if hw.def then SimpleTip(self, hw.def.label, hw.def.desc) end
        end, function()
            local w = CARD_COL.white
            hw.value:SetTextColor(w[1], w[2], w[3])
            GameTooltip:Hide()
        end)
        card.heroes[i] = hw
    end

    card.gauges = {}
    local GAUGE = {
        { lx = 112, vx = 367, ty = 946,    bx = 110, by = 963,  bw = 252 },
        { lx = 399, vx = 655, ty = 946,    bx = 397, by = 963,  bw = 253 },
        { lx = 111, vx = 367, ty = 1009.5, bx = 110, by = 1026, bw = 252 },
        { lx = 400, vx = 655, ty = 1009.5, bx = 397, by = 1026, bw = 253 },
    }
    for i, g in ipairs(GAUGE) do
        local gw = {}
        gw.label = CardText(layer, g.lx, g.ty, FS.label, CARD_COL.label, "L")
        gw.value = CardText(layer, g.vx, g.ty, FS.label, CARD_COL.cyan, "R")
        gw.fill = MakeFill(layer, g.bx, g.by, g.bw, 16, 8, SHEET_MEDIA .. "AttrFillGauge", SHEET_MEDIA .. "AttrFillGaugeCap")
        CardHover(layer, g.bx, g.ty - 12, g.bx + g.bw + 8, g.by + 18, function(self)
            gw.label:SetTextColor(1, 1, 1)
            if gw.def then SimpleTip(self, gw.def.label, gw.def.desc) end
        end, function()
            local l = CARD_COL.label
            gw.label:SetTextColor(l[1], l[2], l[3])
            GameTooltip:Hide()
        end)
        card.gauges[i] = gw
    end

    card.chips = {}
    local CHIP = { { 240.5, 105, 376 }, { 526.5, 391, 662 } }
    for i, ch in ipairs(CHIP) do
        local cw = {}
        cw.text = CardText(layer, ch[1], 1087.5, FS.chip, CARD_COL.gray, "C")
        local hl = layer:CreateTexture(nil, "ARTWORK")
        hl:SetTexture("Interface\\Buttons\\WHITE8X8")
        hl:SetBlendMode("ADD")
        hl:SetVertexColor(0.30, 0.75, 0.95, 0.06)
        hl:SetPoint("TOPLEFT", layer, "TOPLEFT", CX(ch[2] + 2), CY(1068))
        hl:SetSize(ch[3] - ch[2] - 4, 38)
        hl:Hide()
        CardHover(layer, ch[2], 1066, ch[3], 1108, function(self)
            hl:Show()
            if cw.def then SimpleTip(self, cw.def.label, cw.def.desc) end
        end, function() hl:Hide(); GameTooltip:Hide() end)
        card.chips[i] = cw
    end

    -- 5) SELO ELEMENTAL --------------------------------------------------------
    CardHeader(layer, 384, 1150, "SELO ELEMENTAL")
    CardText(layer, 383.5, 1184, FS.label, CARD_COL.gray, "C"):SetText("RESISTÊNCIAS ELEMENTAIS")
    card.resists = {}
    for _, r in ipairs(RESIST_ORBS) do
        local node = CreateFrame("Frame", nil, layer)
        node:SetSize(60, 60)
        node:SetPoint("CENTER", layer, "TOPLEFT", CX(r.cx), CY(r.cy))
        node:EnableMouse(true)
        local glow = node:CreateTexture(nil, "OVERLAY")
        glow:SetTexture(MEDIA_ROOT .. "Glow")
        glow:SetBlendMode("ADD")
        glow:SetSize(100, 100)
        glow:SetPoint("CENTER")
        glow:SetVertexColor(r.color[1], r.color[2], r.color[3], 0.30)
        glow:Hide()
        node.def = r
        node:SetScript("OnEnter", function(self)
            glow:Show()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Resistência a " .. r.label .. ": " .. (self.total or 0), r.color[1], r.color[2], r.color[3])
            GameTooltip:AddLine("Mitiga o dano mágico recebido de feitiços e efeitos de " .. r.label .. ".", 0.9, 0.9, 0.95, true)
            GameTooltip:Show()
        end)
        node:SetScript("OnLeave", function() glow:Hide(); GameTooltip:Hide() end)
        card.resists[#card.resists + 1] = node
    end

    local _, playerClass = UnitClass("player")
    local casters = { MAGE = true, WARLOCK = true, PRIEST = true }
    cardTelemetry = (M.db and M.db.telemetry) or (casters[playerClass] and "arcane" or "offense")
    RefreshTelemetry()
end

local function UpdateAttributes()
    if not card.attrNodes then return end
    for _, node in ipairs(card.attrNodes) do
        local id = node.def and node.def.id
        local _, stat, pos, neg = UnitStat("player", id or 1)
        if Azaath.AnySecret(stat, pos, neg) then
            node.value:SetText(stat or "0")
            node.tooltipBonus = nil
        else
            stat = stat or 0
            local bonus = (pos or 0) + (neg or 0)
            node.value:SetText(floor(stat + 0.5))
            local base = floor(stat - bonus + 0.5)
            if bonus ~= 0 then
                node.tooltipBonus = format("Base: %d   ·   Bônus: %s%d", base, bonus > 0 and "+" or "", floor(bonus + 0.5))
            else
                node.tooltipBonus = format("Base: %d", base)
            end
        end
    end
    RefreshTelemetry()
    for _, node in ipairs(card.resists or {}) do
        local _, total = Call(_G.UnitResistance, "player", node.def.id)
        node.total = Num(total, 0)
    end
end

-- Recursos com preenchimento laranja do conceito; os demais usam a versão cinza tingida
local WARM_POWER = { [1] = true, [2] = true, [3] = true, [6] = true }

local function UpdateVitals()
    if not card.health then return end
    local cur, mx = UnitHealth("player"), UnitHealthMax("player")
    SetVital(card.health, cur, mx)
    card.healthValue:SetText(Azaath.IsSecret(cur) and cur or Azaath.Thousands(cur or 0))

    local ptype, ptoken = UnitPowerType("player")
    local pcur, pmax = UnitPower("player"), UnitPowerMax("player")
    local secretType = Azaath.IsSecret(ptype)
    if not secretType and WARM_POWER[ptype] then
        card.power:SetFillTextures(SHEET_MEDIA .. "AttrFillPower", SHEET_MEDIA .. "AttrFillPowerCap")
        card.power:SetFillColor(1, 1, 1)
    else
        local cm = Char()
        local col = (cm and cm.POWER_COLORS and not secretType and cm.POWER_COLORS[ptype]) or { 0.24, 0.47, 0.85 }
        card.power:SetFillTextures(SHEET_MEDIA .. "AttrFillPowerGray", SHEET_MEDIA .. "AttrFillPowerGrayCap")
        card.power:SetFillColor(min(1, col[1] * 1.25), min(1, col[2] * 1.25), min(1, col[3] * 1.25))
    end
    SetVital(card.power, pcur, pmax)
    local pname = (not Azaath.IsSecret(ptoken) and ptoken and _G[ptoken]) or "Recurso"
    card.powerLabel:SetText(Azaath.Upper(pname))
    card.powerValue:SetText(Azaath.IsSecret(pcur) and pcur or Azaath.Thousands(pcur or 0))

    local level = UnitLevel("player") or 0
    local xmax = UnitXPMax("player")
    local xpLabel, xpVal, xpTip
    if Azaath.API.MaxLevel() <= level or not xmax or Azaath.IsSecret(xmax) or xmax <= 0 then
        xpLabel, xpVal, xpTip = "NÍVEL", "MÁX", "Experiência: nível máximo alcançado"
    else
        local xp = UnitXP("player") or 0
        if Azaath.IsSecret(xp) then
            xpLabel, xpVal, xpTip = "EXP", "", "Experiência atual"
        else
            local rested = Num(Call(_G.GetXPExhaustion), 0)
            local pct = floor(xp / xmax * 100)
            xpLabel = rested > 0 and "DESCANSADO" or "EXP"
            xpVal = format("%d%%", rested > 0 and min(150, floor(rested / xmax * 100 + 0.5)) or pct)
            xpTip = format("Experiência: %s / %s (%d%%)%s", Azaath.Thousands(xp), Azaath.Thousands(xmax), pct,
                rested > 0 and ("  ·  Descansado: " .. Azaath.Thousands(rested)) or "")
        end
    end
    local cm = Char()
    local d = (cm and cm.Durability and cm.Durability()) or 1
    local dPct = floor(d * 100 + 0.5)
    card.journey:SetText(format("%s %s%s|r  •  INTEGRIDADE %s%d%%|r", xpLabel, HEX_WHITE, xpVal, HEX_WHITE, dPct))
    card.journeyHover.xpTip = xpTip
    card.journeyHover.duraTip = format("Integridade do equipamento: %d%%", dPct)
end

-- compartilhado com os outros arquivos da ficha
U.BuildAttributes, U.CARD_COL, U.CARD_H, U.CARD_TEX_H = BuildAttributes, CARD_COL, CARD_H, CARD_TEX_H
U.CARD_TEX_W, U.CARD_W, U.CONSTELLATION, U.CX = CARD_TEX_W, CARD_W, CONSTELLATION, CX
U.CY, U.CardText, U.FS, U.PlaceTabHighlight = CY, CardText, FS, PlaceTabHighlight
U.TAB_CX, U.TAB_HIT, U.UpdateAttributes, U.UpdateVitals = TAB_CX, TAB_HIT, UpdateAttributes, UpdateVitals
U.card = card
