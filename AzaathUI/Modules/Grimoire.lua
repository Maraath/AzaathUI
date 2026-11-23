--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Grimoire.lua
    Aba "Grimório" da ficha (tecla C / tecla P): o GRIMÓRIO de verdade.

    Réplica da arte de conceito (tools/grimoire-concept/concept.webp, 1376x768):
    mesa arcana com velas e cristais, livro aberto, marcadores de couro por
    escola, página esquerda = capítulo da escola (medalhões ligados por linhas
    de tinta + selos de passivas), página direita = inscrição do feitiço
    escolhido (diagrama alquímico que encolhe com texto longo, custo/alcance/
    tempo à tinta, requisitos, descrição) e
    a Mesa de Runas (barras de ação reais).

    Arte: tools/grimoire-concept/gen.js recorta e limpa a imagem e gera
    Media/Grimoire/*.tga. Todo o resto é posicionado em COORDENADAS DA ARTE: um
    quadro de 1376x768 escalado para cobrir a tela (SetScale).

    Trocar de capítulo (marcador) ou de página vira a folha com animação, som
    de página e partículas. Clique só seleciona (nenhum botão seguro: a ficha
    abre/fecha em combate); arrastar para a barra só fora de combate.
------------------------------------------------------------------------------]]

local ADDON_NAME, Azaath = ...
local M = Azaath:NewModule("Grimoire")

local _G = _G
local ipairs, pairs, format, floor, min, max, abs, sin, cos, sqrt, pi, random, type, pcall, tonumber, tostring, wipe =
    ipairs, pairs, string.format, math.floor, math.min, math.max, math.abs, math.sin, math.cos, math.sqrt, math.pi, math.random, type, pcall, tonumber, tostring, wipe
local API = Azaath.API

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local GRIM  = MEDIA .. "Grimoire\\"
local INV   = MEDIA .. "Inventory\\"

-- Arte de conceito
local ART_W, ART_H = 1376, 768
local INK      = { 0.16, 0.11, 0.08 }
local INK_SOFT = { 0.26, 0.19, 0.13 }
local CREAM    = { 0.93, 0.88, 0.78 }
local CYAN     = { 0.37, 0.89, 1.00 }
local AZ_TEAL  = { 0.10, 0.56, 0.80 }   -- tinta azul luminosa (sobre o papel: mistura, não soma)

-- Marcadores: centro do nome e área clicável (x0, y0, x1, y1)
local TABS = {
    { 275, 263, 218, 243, 316, 292 },
    { 265, 337, 207, 312, 308, 362 },
    { 255, 410, 195, 383, 298, 433 },
    { 245, 485, 183, 458, 298, 510 },
    { 234, 558, 181, 531, 287, 585 },   -- 5º (pet): marcador desenhado por cima
}
-- Marcadores recortados da arte (GrimTabsCut; o 5º usa GrimTab): x0, y0, largura, altura
local TAB_CUT = { { 215, 238, 103, 53 }, { 204, 309, 107, 57 }, { 193, 381, 108, 56 }, { 181, 456, 121, 58 }, { 181, 531, 106, 54 } }
-- Efeitos por marcador: filetes de x0 a x1 nas alturas top/base do couro; mini-sinete (x, y) na ponteira
local TAB_FX = {
    { 262, 309, 247.5, 283, 230, 266 },
    { 256, 302, 318, 355, 219, 339 },
    { 246, 292, 390.5, 426, 207, 410 },
    { 236, 294, 466.5, 501, 196, 486 },
    { 232, 278, 539, 576, 195, 560 },
}
local TAB_PULL_SEL, TAB_PULL_HOVER = 9, 4   -- quanto o marcador sai do livro

-- Página esquerda: medalhões (centro x, y; nome x, y) e selos de passivas
local SLOTS = {
    { 432, 266, 423, 316 },
    { 587, 284, 587, 324 },
    { 408, 402, 405, 445 },
    { 590, 400, 588, 446 },
    { 492, 510, 491, 560 },
}
local SEALS = { { 379, 522 }, { 595, 518 } }
local PER_PAGE, SEALS_PER_PAGE = #SLOTS, #SEALS
-- Linhas de tinta: {de x, de y, até x, até y, seta, medalhões necessários...}
local EDGES = {
    { 464, 271, 552, 276, false, 1, 2 },
    { 557, 302, 445, 380, true, 2, 3 },
    { 422, 339, 415, 365, true, 1, 3 },
    { 589, 337, 591, 360, true, 2, 4 },
    { 450, 399, 506, 399, false, 3, 4 },
    { 514, 399, 555, 398, false, 3, 4 },
    { 510, 404, 497, 480, true, 3, 4, 5 },
    { 425, 456, 460, 485, true, 3, 5 },
    { 552, 456, 525, 484, true, 4, 5 },
    { 501, 386, 507, 395, false, 3, 4 },
}
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII" }

-- Página direita
-- custo, alcance, tempo... escritos à tinta entre o diagrama e a descrição
local MAX_STATS = 4
local IMFELL = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Fonts\\IMFell-Regular.ttf"
-- Diagrama (textura própria, GrimDiagram): caixa na arte e centro do ícone dentro dela
local DIAG_BOX = { 755, 230, 226, 207 }   -- x0, y0, largura, altura
local DIAG_ICON = { 112.5, 98 }           -- centro do ícone relativo à caixa
local DIAG_INK_H = 197                    -- fundo do anel de tinta (relativo à caixa)
local DIAG_MIN = 0.55                     -- menor escala do diagrama com texto longo
local PAGE_BOTTOM = 543                   -- acima do floreio da arte
-- Efeitos do selecionado (tools/grimoire-concept/gen-fx.js): selo rúnico = 1,62x o
-- medalhão (justo no aro de bronze, sem cobrir os nomes); aro do ícone = 105 px
local ICON_RING_K = 105
-- Dica no pé da página (textura GrimHint): caixa na arte, x 735..1035, y 553..585
local HINT_BOX = { 735, 553, 300, 32 }

-- Folha que vira (página esquerda limpa: x 296..692, y 160..612)
local SPINE, PTOP, PW, PH = 692, 160, 396, 452
local FLIP_TIME = 0.8

-- Mesa de Runas
local BARS = {
    { label = "BARRA 1", bind = "ACTIONBUTTON%d" },
    { label = "BARRA 2", bind = "MULTIACTIONBAR1BUTTON%d", base = 60 },
    { label = "BARRA 3", bind = "MULTIACTIONBAR2BUTTON%d", base = 48 },
    { label = "LATERAL", bind = "MULTIACTIONBAR3BUTTON%d", base = 24 },
}
-- Mesa no estilo do livro: folha (GrimMesa) em x 1040..1360, y 574..748
local MESA_BOX = { 1040, 574, 320, 174 }
local MESA_TAB_X, MESA_TAB_Y, MESA_TAB_W, MESA_TAB_H = { 1093, 1161, 1229, 1297 }, 616, 66, 26
local SLOT_X, SLOT_Y, SLOT, SLOT_ICON = { 1080, 1128, 1176, 1224, 1272, 1320 }, { 657, 709 }, 46, 28

local page, root, art, leftF, rightF, tabsF, mesaF, flipF
local schools = {}
local selSchool, selSpell
local subPage = {}
local needData, needBinds = true, true
local bindMap = {}
local clock = 0
local anim = {}
local mesaBar = 1
local tabWidgets, medals, seals, edgeLines = {}, {}, {}, {}
local left, right, mesa, flip, ambient = {}, {}, {}, {}, {}
local particles = {}

--------------------------------------------------------------------------------
-- Utilitários
--------------------------------------------------------------------------------
local function Text(parent, font, size, col, justify, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or Azaath.media.font, size or 12, flags or "")
    col = col or { 1, 1, 1 }
    fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
    fs:SetJustifyH(justify or "CENTER")
    return fs
end

local function Tex(parent, layer, path, blend, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    if path then t:SetTexture(path) end
    if blend then t:SetBlendMode(blend) end
    return t
end

-- posição em coordenadas da arte (y para baixo)
local function At(region, rel, x, y, point)
    region:ClearAllPoints()
    region:SetPoint(point or "CENTER", rel, "TOPLEFT", x, -y)
end

local function CircleMask(owner, tex)
    if not (owner.CreateMaskTexture and tex.AddMaskTexture) then return end
    local m = owner:CreateMaskTexture()
    m:SetAllPoints(tex)
    local ok = pcall(m.SetTexture, m, INV .. "RoundMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if not ok then
        pcall(m.SetTexture, m, "Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    pcall(tex.AddMaskTexture, tex, m)
end

local function Clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function Damp(a, b, k, dt) return a + (b - a) * (1 - k ^ dt) end
local function EaseOut(u) return 1 - (1 - u) ^ 3 end
local function Smooth(u) return u * u * (3 - 2 * u) end
local function BackOut(u)
    local c1 = 1.70158
    return 1 + (c1 + 1) * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
end

local function Tracked(s) return Azaath.Tracked and Azaath.Tracked(s) or s end
local function Upper(s) s = s or ""; return Azaath.Upper and Azaath.Upper(s) or s:upper() end

local function SpellNameByID(id)
    if not id or Azaath.IsSecret(id) then return nil end
    if C_Spell and C_Spell.GetSpellName then
        local ok, n = pcall(C_Spell.GetSpellName, id)
        if ok and n then return n end
    end
    if _G.GetSpellInfo then
        local ok, n = pcall(GetSpellInfo, id)
        if ok then return n end
    end
end

local function ShortKey(k)
    if not k or k == "" then return nil end
    if Azaath.ShortKey then return Azaath.ShortKey(k) end
    return k
end

local function RankNumber(rank)
    return tonumber((rank or ""):match("%d+"))
end

--------------------------------------------------------------------------------
-- Dados: escolas (capítulos), feitiços, atalhos, tooltip
--------------------------------------------------------------------------------
local function SpellID(i, book)
    local SB = _G.C_SpellBook
    if SB and SB.GetSpellBookItemInfo then
        local bank = book
        local E = _G.Enum and Enum.SpellBookSpellBank
        if E then bank = (book == "pet") and E.Pet or E.Player end
        local ok, info = pcall(SB.GetSpellBookItemInfo, i, bank)
        if ok and type(info) == "table" then return info.spellID or info.actionID end
    end
    if _G.GetSpellBookItemInfo then
        local ok, _, id = pcall(GetSpellBookItemInfo, i, book)
        if ok then return id end
    end
end

local function Collect(book, first, last)
    local actives, passives = {}, {}
    for i = first, last do
        local name, rank = API.SpellName(i, book)
        local nextName = (i < last) and API.SpellName(i + 1, book) or nil
        if name and not Azaath.IsSecret(name) and name ~= nextName then
            local p = API.SpellIsPassive(i, book)
            local sp = {
                index = i, book = book, name = name,
                rank = (type(rank) == "string") and rank or "",
                passive = (not Azaath.IsSecret(p)) and p and true or false,
                icon = API.SpellTexture(i, book),
                id = SpellID(i, book),
            }
            if sp.passive then passives[#passives + 1] = sp else actives[#actives + 1] = sp end
        end
    end
    return actives, passives
end

local function BuildSchools()
    wipe(schools)
    for t = 1, (API.SpellTabCount() or 0) do
        local name, offset, num = API.SpellTabInfo(t)
        if num and num > 0 then
            local a, p = Collect("spell", offset + 1, offset + num)
            if #a + #p > 0 then schools[#schools + 1] = { key = "tab" .. t, name = name or "?", actives = a, passives = p } end
        end
    end
    local np = API.NumPetSpells() or 0
    if np > 0 then
        local a, p = Collect("pet", 1, np)
        if #a + #p > 0 then schools[#schools + 1] = { key = "pet", name = UnitName("pet") or "Pet", actives = a, passives = p } end
    end
    while #schools > #TABS do table.remove(schools) end
    for _, s in ipairs(schools) do
        -- páginas: técnicas nos medalhões, passivas nos selos; medalhão que sobrar
        -- recebe passiva (nada de página só com uma ou duas passivas)
        s.layout = {}
        local ai, qi = 1, 1
        repeat
            local pg = { medals = {}, seals = {} }
            for k = 1, PER_PAGE do
                if s.actives[ai] then pg.medals[k] = s.actives[ai]; ai = ai + 1 end
            end
            for k = 1, SEALS_PER_PAGE do
                if s.passives[qi] then pg.seals[k] = s.passives[qi]; qi = qi + 1 end
            end
            for k = 1, PER_PAGE do
                if not pg.medals[k] and s.passives[qi] then pg.medals[k] = s.passives[qi]; qi = qi + 1 end
            end
            s.layout[#s.layout + 1] = pg
        until not s.actives[ai] and not s.passives[qi]
        s.pages = #s.layout
    end
end

local function ActionSpellName(slot)
    if not (HasAction and HasAction(slot)) then return nil end
    local t, id = GetActionInfo(slot)
    if Azaath.AnySecret(t, id) then return nil end
    if t == "spell" then return SpellNameByID(id) end
    if t == "macro" and id and _G.GetMacroSpell then
        local ms = GetMacroSpell(id)
        if type(ms) == "number" then return SpellNameByID(ms) end
        return ms
    end
end

local function BarBase(bar)
    if bar.base then return bar.base end
    local p = (_G.GetActionBarPage and GetActionBarPage()) or 1
    local off = (_G.GetBonusBarOffset and GetBonusBarOffset()) or 0
    if Azaath.AnySecret(p, off) then return 0 end
    if p == 1 and off > 0 then p = 6 + off end
    return (p - 1) * 12
end

local function Remember(name, key)
    if not name then return end
    local e = bindMap[name]
    if not e then bindMap[name] = { key = key }
    elseif not e.key and key then e.key = key end
end

local function BuildBindMap()
    wipe(bindMap)
    for _, bar in ipairs(BARS) do
        local base = BarBase(bar)
        for i = 1, 12 do Remember(ActionSpellName(base + i), ShortKey(GetBindingKey(format(bar.bind, i)))) end
    end
    for p = 7, 10 do
        for i = 1, 12 do Remember(ActionSpellName((p - 1) * 12 + i), ShortKey(GetBindingKey(format("ACTIONBUTTON%d", i)))) end
    end
    if _G.GetNumShapeshiftForms and GetShapeshiftFormInfo then
        for i = 1, (GetNumShapeshiftForms() or 0) do
            local _, _, _, sid = GetShapeshiftFormInfo(i)
            Remember(SpellNameByID(sid), ShortKey(GetBindingKey("SHAPESHIFTBUTTON" .. i)))
        end
    end
end

local scanTip
local function ParseTooltip(sp)
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "AzaathGrimoireScanTip", UIParent, "GameTooltipTemplate")
    end
    local stats, req, desc = {}, {}, {}
    scanTip:SetOwner(UIParent, "ANCHOR_NONE")
    scanTip:ClearLines()
    if pcall(API.SetSpellTooltip, scanTip, sp.index, sp.book) then
        for i = 2, (scanTip:NumLines() or 0) do
            local L = _G["AzaathGrimoireScanTipTextLeft" .. i]
            local R = _G["AzaathGrimoireScanTipTextRight" .. i]
            local lt = L and L:GetText()
            local rt = R and R:IsShown() and R:GetText()
            if Azaath.IsSecret(lt) then lt = nil end
            if Azaath.IsSecret(rt) then rt = nil end
            if lt and lt ~= "" then
                local r, g, b = L:GetTextColor()
                if Azaath.AnySecret(r, g, b) then r, g, b = 1, 1, 1 end
                local isReq = lt:match("^Requer") or lt:match("^Requires") or lt:match("^Requiere")
                if r > 0.9 and g < 0.4 and b < 0.4 then
                    req[#req + 1] = { text = lt, met = false }
                elseif isReq then
                    req[#req + 1] = { text = lt, met = true }
                elseif r > 0.9 and g > 0.7 and b < 0.35 then
                    desc[#desc + 1] = lt
                else
                    stats[#stats + 1] = lt
                end
            end
            if rt and rt ~= "" then stats[#stats + 1] = rt end
        end
    end
    scanTip:Hide()
    while #stats > MAX_STATS do table.insert(desc, 1, table.remove(stats)) end
    if #desc == 0 and #stats == 1 and #stats[1] > 40 then desc[1] = table.remove(stats) end
    sp.stats, sp.req, sp.desc = stats, req, table.concat(desc, " ")
end

--------------------------------------------------------------------------------
-- Marcadores (capítulos)
--------------------------------------------------------------------------------
local ChangeChapter -- adiante

local function BuildTabs()
    tabsF = CreateFrame("Frame", nil, art)
    tabsF:SetAllPoints(art)
    tabsF:SetFrameLevel(art:GetFrameLevel() + 4)

    for i, d in ipairs(TABS) do
        local b = CreateFrame("Button", nil, tabsF)
        local bw, bh = d[5] - d[3], d[6] - d[4]
        b:SetSize(bw, bh)
        At(b, tabsF, d[3], d[4], "TOPLEFT")
        local box, fx = TAB_CUT[i], TAB_FX[i]
        b.box, b.fxd, b.pull = box, fx, 0

        -- o marcador recortado da arte (desliza para fora do livro)
        b.cut = Tex(tabsF, "ARTWORK", GRIM .. (i <= 4 and "GrimTabsCut" or "GrimTab"))
        b.cut:SetSize(box[3], box[4])
        if i <= 4 then
            b.cut:SetTexCoord((i - 1) * 128 / 512, ((i - 1) * 128 + box[3]) / 512, 0, box[4] / 64)
        else
            b.cut:SetTexCoord(0, 106 / 128, 0, 54 / 64)
        end
        -- cristal (mini-sinete) na ponteira de metal: o único brilho do marcador
        b.gemGlow = Tex(tabsF, "OVERLAY", MEDIA .. "Glow", "ADD", 2)
        b.gemGlow:SetSize(16, 16); b.gemGlow:SetVertexColor(CYAN[1], CYAN[2], CYAN[3], 1); b.gemGlow:SetAlpha(0)
        b.gem = Tex(tabsF, "OVERLAY", MEDIA .. "Diamond", "ADD", 3)
        b.gem:SetSize(6, 8); b.gem:SetVertexColor(0.45, 0.95, 1.0, 1); b.gem:SetAlpha(0)
        b.gemCore = Tex(tabsF, "OVERLAY", MEDIA .. "Diamond", "ADD", 4)
        b.gemCore:SetSize(3, 4); b.gemCore:SetVertexColor(0.95, 1.0, 1.0, 1); b.gemCore:SetAlpha(0)

        b.fxAlpha = 0
        b.text = Text(tabsF, Azaath.media.fontCinzel or Azaath.media.fontTitleB, 13, CREAM)
        b.text:SetShadowOffset(1, -1)
        b.text:SetShadowColor(0, 0, 0, 0.85)
        b.idx = i
        b:SetScript("OnClick", function(self) ChangeChapter(self.idx) end)
        b:SetScript("OnEnter", function(self) self.hover = true end)
        b:SetScript("OnLeave", function(self) self.hover = false end)
        tabWidgets[i] = b
    end
end

-- Coloca as peças do marcador i deslocadas "pull" para fora do livro (esquerda)
local function PlaceTab(b, i)
    local d, box, fx, p = TABS[i], b.box, b.fxd, b.pull
    At(b.cut, tabsF, box[1] - p, box[2], "TOPLEFT")
    At(b.text, tabsF, (b.tcx or d[1]) - p, d[2])
    At(b.gemGlow, tabsF, fx[5] - p, fx[6])
    At(b.gem, tabsF, fx[5] - p, fx[6])
    At(b.gemCore, tabsF, fx[5] - p, fx[6])
end

local function LayoutTabs(instant)
    for i, b in ipairs(tabWidgets) do
        local s = schools[i]
        local show = s and true or false
        b:SetShown(show); b.text:SetShown(show); b.cut:SetShown(show)
        b.gem:SetShown(show); b.gemGlow:SetShown(show); b.gemCore:SetShown(show)
        if s then
            -- o nome cabe entre o mini-sinete e a ponta do couro
            local box, fx = b.box, b.fxd
            local x0, x1 = fx[5] + 12, box[1] + box[3] - 5
            local font, size = Azaath.media.fontCinzel or Azaath.media.fontTitleB, 13
            b.text:SetFont(font, size, "")
            b.text:SetText(Tracked(Upper(s.name)))
            while size > 9 and (b.text:GetStringWidth() or 0) > (x1 - x0) do
                size = size - 0.5
                b.text:SetFont(font, size, "")
            end
            b.tcx = (x0 + x1) / 2
            if instant then
                b.fxAlpha = (i == selSchool) and 1 or 0
                b.pull = (i == selSchool) and TAB_PULL_SEL or 0
            end
            PlaceTab(b, i)
        end
    end
end

--------------------------------------------------------------------------------
-- Página esquerda: capítulo
--------------------------------------------------------------------------------
local SelectSpell -- adiante

local function Medal_OnEnter(self)
    self.hover = true
    if self.sp then
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        pcall(API.SetSpellTooltip, GameTooltip, self.sp.index, self.sp.book)
        GameTooltip:Show()
    end
end
local function Medal_OnLeave(self) self.hover = false; GameTooltip:Hide() end
local function Medal_OnClick(self)
    local sp = self.sp
    if not sp then return end
    if IsModifiedClick and IsModifiedClick("CHATLINK") then
        local link = API.SpellLink(sp.index, sp.book)
        if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
        return
    end
    SelectSpell(sp)
end
local function Medal_OnDrag(self)
    local sp = self.sp
    if sp and not sp.passive and not InCombatLockdown() then API.PickupSpell(sp.index, sp.book) end
end

local function NewMedal(isSeal, x, y)
    local tex, size, icon = GRIM .. "GrimMedal", 80, 48
    if isSeal then tex, size, icon = GRIM .. "GrimSeal", 63, 42 end
    local b = CreateFrame("Button", nil, leftF)
    b:SetSize(size, size)
    b:RegisterForClicks("LeftButtonUp")
    b:RegisterForDrag("LeftButton")
    b.x, b.y, b.size = x, y, size
    -- seleção / hover: aura Azaath discreta e viva rente ao medalhão
    b.aura = Tex(b, "BACKGROUND", MEDIA .. "CastRingHalo", "BLEND")
    b.aura:SetPoint("CENTER"); b.aura:SetSize(size * 1.10, size * 1.10)
    b.aura:SetVertexColor(CYAN[1], CYAN[2], CYAN[3], 1); b.aura:SetAlpha(0)
    b.auraCore = Tex(b, "BACKGROUND", MEDIA .. "CastRingHalo", "ADD", 1)
    b.auraCore:SetPoint("CENTER"); b.auraCore:SetSize(size * 1.05, size * 1.05)
    b.auraCore:SetVertexColor(CYAN[1], CYAN[2], CYAN[3], 1); b.auraCore:SetAlpha(0)
    b.fx = 0
    b.icon = Tex(b, "ARTWORK")
    b.icon:SetPoint("CENTER"); b.icon:SetSize(icon, icon)
    b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    CircleMask(b, b.icon)
    b.ring = Tex(b, "OVERLAY", tex)
    b.ring:SetAllPoints(b)
    b.pop, b.lift = 1, 1
    b:SetScript("OnEnter", Medal_OnEnter)
    b:SetScript("OnLeave", Medal_OnLeave)
    b:SetScript("OnClick", Medal_OnClick)
    b:SetScript("OnDragStart", Medal_OnDrag)
    return b
end

local function PlaceMedal(b)
    local sc = max(0.05, b.pop * b.lift)
    b:SetScale(sc)
    b:ClearAllPoints()
    b:SetPoint("CENTER", leftF, "TOPLEFT", b.x / sc, -b.y / sc)
end

local function InkLine(parent)
    local ln = parent:CreateLine(nil, "ARTWORK", nil, 1)
    ln:SetTexture(Azaath.media.blank)
    ln:SetVertexColor(INK[1], INK[2], INK[3], 0.82)
    ln:SetThickness(1.25)
    return ln
end

local function SetLine(ln, x1, y1, x2, y2, rel)
    rel = rel or leftF
    ln:SetStartPoint("TOPLEFT", rel, x1, -y1)
    ln:SetEndPoint("TOPLEFT", rel, x2, -y2)
    ln:Show()
end

local function BuildLeft()
    leftF = CreateFrame("Frame", nil, art)
    leftF:SetAllPoints(art)
    leftF:SetFrameLevel(art:GetFrameLevel() + 3)
    -- camada de textos acima dos medalhões: o selo rúnico passa por baixo dos nomes
    left.labels = CreateFrame("Frame", nil, leftF)
    left.labels:SetAllPoints(leftF)
    left.labels:SetFrameLevel(leftF:GetFrameLevel() + 30)
    local media = Azaath.media

    left.title = Text(left.labels, media.fontTitleB, 18, INK)
    At(left.title, leftF, 507, 190)
    left.sub = Text(left.labels, media.fontCard, 11, INK_SOFT)
    At(left.sub, leftF, 506, 210)
    if leftF.CreateLine then
        left.flL, left.flR = InkLine(leftF), InkLine(leftF)
        left.flL2, left.flR2 = InkLine(leftF), InkLine(leftF)
        for i, e in ipairs(EDGES) do
            local g = { main = InkLine(leftF) }
            if e[5] then g.a1, g.a2 = InkLine(leftF), InkLine(leftF) end
            edgeLines[i] = g
        end
    end
    left.junction = Tex(leftF, "ARTWORK", MEDIA .. "Ring", nil, 2)
    left.junction:SetSize(11, 11); left.junction:SetVertexColor(INK[1], INK[2], INK[3], 0.9)
    At(left.junction, leftF, 510, 399)
    left.dot = Tex(leftF, "ARTWORK", MEDIA .. "Disc", nil, 2)
    left.dot:SetSize(4, 4); left.dot:SetVertexColor(INK[1], INK[2], INK[3], 0.9)
    At(left.dot, leftF, 501, 386)

    for i, s in ipairs(SLOTS) do
        local b = NewMedal(false, s[1], s[2])
        b.label = Text(left.labels, media.fontCard, 13.5, INK)
        At(b.label, leftF, s[3], s[4])
        b.rank = Text(left.labels, media.fontCard, 13, INK)
        At(b.rank, leftF, s[3], s[4] + 14)
        medals[i] = b
    end
    for i, s in ipairs(SEALS) do seals[i] = NewMedal(true, s[1], s[2]) end

    left.pageText = Text(leftF, media.fontTitleB, 10, INK_SOFT)
    At(left.pageText, leftF, 492, 590)
    left.prev = CreateFrame("Button", nil, leftF)
    left.prev:SetSize(26, 20); At(left.prev, leftF, 452, 590)
    left.prev.text = Text(left.prev, media.fontTitleB, 16, INK); left.prev.text:SetPoint("CENTER"); left.prev.text:SetText("‹")
    left.next = CreateFrame("Button", nil, leftF)
    left.next:SetSize(26, 20); At(left.next, leftF, 532, 590)
    left.next.text = Text(left.next, media.fontTitleB, 16, INK); left.next.text:SetPoint("CENTER"); left.next.text:SetText("›")

    leftF:EnableMouseWheel(true)
end

local function CurrentPage(s)
    local p = subPage[s.key] or 1
    if p > s.pages then p = s.pages end
    return p
end

local function RenderLeft(reveal)
    local s = schools[selSchool]
    if not s then
        left.title:SetText(""); left.sub:SetText("")
        for _, b in ipairs(medals) do b:Hide(); b.label:SetText(""); b.rank:SetText("") end
        for _, b in ipairs(seals) do b:Hide() end
        return
    end
    local p = CurrentPage(s)
    left.title:SetText(format("CAPÍTULO %s · %s", ROMAN[selSchool] or tostring(selSchool), Upper(s.name)))
    left.sub:SetText(format("%d Feitiços  ·  Técnicas de %s", #s.actives, s.name or ""))

    -- floreios do título acompanham a largura do texto
    if left.flL then
        local w = left.title:GetStringWidth() or 200
        local x0, x1 = 507 - w / 2 - 8, 507 + w / 2 + 8
        SetLine(left.flL, x0 - 36, 191, x0, 191); SetLine(left.flL2, x0 - 30, 193.5, x0 - 4, 193.5)
        SetLine(left.flR, x1, 191, x1 + 36, 191); SetLine(left.flR2, x1 + 4, 193.5, x1 + 30, 193.5)
    end

    local filled = {}
    for i, b in ipairs(medals) do
        local sp = s.layout[p].medals[i]
        b.sp = sp
        if sp then
            filled[i] = true
            b.icon:SetTexture(sp.icon)
            -- passiva num medalhão: mesmo tom dos selos
            b.icon:SetDesaturated(sp.passive)
            if sp.passive then b.icon:SetVertexColor(0.78, 0.74, 0.92) else b.icon:SetVertexColor(1, 1, 1) end
            b.label:SetText(sp.name)
            b:Show()
        else
            b:Hide(); b.label:SetText(""); b.rank:SetText("")
        end
        if reveal then b.pop = 0.01 end
        PlaceMedal(b)
    end
    for i, b in ipairs(seals) do
        local sp = s.layout[p].seals[i]
        b.sp = sp
        if sp then
            b.icon:SetTexture(sp.icon)
            b.icon:SetDesaturated(true)
            b.icon:SetVertexColor(0.78, 0.74, 0.92)
            b:Show()
        else
            b:Hide()
        end
        if reveal then b.pop = 0.01 end
        PlaceMedal(b)
    end

    -- linhas de tinta só entre medalhões ocupados
    for i, e in ipairs(EDGES) do
        local g = edgeLines[i]
        if g then
            local ok = true
            for k = 6, #e do if not filled[e[k]] then ok = false end end
            if ok then
                SetLine(g.main, e[1], e[2], e[3], e[4])
                if g.a1 then
                    local dx, dy = e[3] - e[1], e[4] - e[2]
                    local len = sqrt(dx * dx + dy * dy)
                    dx, dy = dx / len, dy / len
                    for side, ln in ipairs({ g.a1, g.a2 }) do
                        local a = (side == 1) and 0.45 or -0.45
                        local rx, ry = dx * cos(a) - dy * sin(a), dx * sin(a) + dy * cos(a)
                        SetLine(ln, e[3], e[4], e[3] - rx * 7, e[4] - ry * 7)
                    end
                end
            else
                g.main:Hide()
                if g.a1 then g.a1:Hide(); g.a2:Hide() end
            end
        end
    end
    local junction = filled[3] and filled[4]
    left.junction:SetShown(junction and true or false)
    left.dot:SetShown(junction and true or false)

    local multi = s.pages > 1
    left.pageText:SetShown(multi); left.prev:SetShown(multi); left.next:SetShown(multi)
    if multi then left.pageText:SetText(format("%s / %s", ROMAN[p] or p, ROMAN[s.pages] or s.pages)) end
    left.prev:SetAlpha(p > 1 and 1 or 0.3); left.next:SetAlpha(p < s.pages and 1 or 0.3)

    if reveal then anim.leftReveal = { t = 0 } end
end

local function UpdateSelectionMarks()
    for _, b in ipairs(medals) do
        local on = b:IsShown() and b.sp == selSpell
        local n = on and RankNumber(b.sp.rank)
        b.rank:SetText(n and format("(Grau %d)", n) or "")
    end
end

--------------------------------------------------------------------------------
-- Página direita: inscrição do feitiço
--------------------------------------------------------------------------------
local function BuildRight()
    rightF = CreateFrame("Frame", nil, art)
    rightF:SetAllPoints(art)
    rightF:SetFrameLevel(art:GetFrameLevel() + 3)
    local media = Azaath.media
    local blocks = {}
    local function Block(fs) blocks[#blocks + 1] = fs; return fs end

    right.kind = Block(Text(rightF, media.fontCinzel or media.fontTitleB, 12.5, INK_SOFT))
    At(right.kind, rightF, 858, 184)
    right.name = Block(Text(rightF, media.fontTitleB, 24, INK))
    At(right.name, rightF, 860, 207)
    right.grau = Block(Text(rightF, media.fontCinzel or media.fontTitleB, 11, INK_SOFT))
    At(right.grau, rightF, 868, 226)
    right.gem = Tex(rightF, "OVERLAY", MEDIA .. "Diamond")
    right.gem:SetSize(7, 7); right.gem:SetVertexColor(0.85, 0.66, 0.28, 1)
    blocks[#blocks + 1] = right.gem

    -- diagrama alquímico (textura própria): encolhe e sobe quando o texto é longo
    right.diag = Tex(rightF, "BORDER", GRIM .. "GrimDiagram")
    right.diag:SetTexCoord(0, DIAG_BOX[3] / 256, 0, DIAG_BOX[4] / 256)
    -- o diagrama aceso em ciano no feitiço selecionado (GrimDiagramGlow, mesma caixa)
    right.diagGlow = Tex(rightF, "BORDER", GRIM .. "GrimDiagramGlow", "BLEND", 1)
    right.diagGlow:SetTexCoord(0, DIAG_BOX[3] / 256, 0, DIAG_BOX[4] / 256)
    right.scale, right.target = 1, 1

    -- ícone no centro do diagrama, com brilho Azaath e aro de tinta
    right.iconHolder = CreateFrame("Frame", nil, rightF)
    right.iconHolder:SetSize(62, 62)
    -- anel rúnico fino girando em volta do ícone (tinta azul) + aura em anel
    -- aro incandescente em volta do ícone (GrimIconRing, tirado da arte)
    right.iconRing = Tex(right.iconHolder, "OVERLAY", GRIM .. "GrimIconRing", "BLEND", 2)
    right.iconRing:SetPoint("CENTER")
    right.icon = Tex(right.iconHolder, "ARTWORK")
    right.icon:SetPoint("CENTER"); right.icon:SetSize(62, 62)
    right.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    CircleMask(right.iconHolder, right.icon)
    right.rim = Tex(right.iconHolder, "OVERLAY", MEDIA .. "Ring")
    right.rim:SetPoint("CENTER"); right.rim:SetVertexColor(INK[1], INK[2], INK[3], 0.9)
    right.flash = Tex(right.iconHolder, "OVERLAY", MEDIA .. "Glow", "ADD", 1)
    right.flash:SetPoint("CENTER")
    right.flash:SetVertexColor(0.70, 0.96, 1.0, 1); right.flash:SetAlpha(0)

    -- custo, alcance, tempo... à tinta (IM Fell direto pelo arquivo: não depende da opção de fonte)
    right.stats = Block(Text(rightF, media.fontCard, 13, INK_SOFT))
    if not right.stats:SetFont(IMFELL, 15, "") then right.stats:SetFont(media.fontCard, 13, "") end
    right.stats:SetWidth(330); right.stats:SetWordWrap(true)
    -- requisitos em linha própria (vermelho-tinta quando não cumpridos)
    right.req = Block(Text(rightF, media.fontCard, 12.5, INK_SOFT))
    right.req:SetWidth(320); right.req:SetWordWrap(true)
    right.desc = Block(Text(rightF, media.fontCard, 13, INK))
    right.desc:SetWidth(310); right.desc:SetWordWrap(true)
    if right.desc.SetSpacing then right.desc:SetSpacing(0.5) end

    -- passar o mouse no texto mostra a dica completa do feitiço
    right.hover = CreateFrame("Frame", nil, rightF)
    right.hover:EnableMouse(true)
    right.hover:SetScript("OnEnter", function(self)
        if selSpell then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(API.SetSpellTooltip, GameTooltip, selSpell.index, selSpell.book)
            GameTooltip:Show()
        end
    end)
    right.hover:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- dica fixa no pé da página: textura gerada (tools/grimoire-concept/gen-hint.js)
    -- com as letras giradas sobre a curva da folha, em 4x para ficar nítida
    right.hint = Tex(rightF, "ARTWORK", GRIM .. "GrimHint")
    right.hint:SetSize(HINT_BOX[3], HINT_BOX[4])
    right.hint:SetTexCoord(0, 1200 / 2048, 0, 1)
    right.hint:SetVertexColor(1, 1, 1, 0.92)
    At(right.hint, rightF, HINT_BOX[1], HINT_BOX[2], "TOPLEFT")

    right.blocks = blocks
end

local function FitName(fs, text, maxW)
    local size = 24
    fs:SetFont(Azaath.media.fontTitleB, size, "")
    fs:SetText(text)
    while size > 14 and (fs:GetStringWidth() or 0) > maxW do
        size = size - 1
        fs:SetFont(Azaath.media.fontTitleB, size, "")
        fs:SetText(text)
    end
end

-- Topo do texto logo abaixo do diagrama na escala s; espaço que sobra até o floreio
local function TextTop(s) return DIAG_BOX[2] + 6 * (1 - s) + DIAG_INK_H * s + 8 end
local function Room(s) return PAGE_BOTTOM - TextTop(s) end

local function Measure(fs, text)
    if fs.SetMaxLines then fs:SetMaxLines(0) end
    fs:SetText(text or "")
    fs.h = (text and text ~= "") and (fs:GetStringHeight() or 0) or 0
    return fs.h
end

-- Escolhe a escala do diagrama (1 = arte original) para o texto caber inteiro;
-- no mínimo, reduz a letra da descrição e, por último, corta em linhas inteiras.
local function FitRight(sp)
    local reqParts = {}
    for _, r in ipairs(sp.req or {}) do
        reqParts[#reqParts + 1] = r.met and r.text or ("|cff7a2418" .. r.text .. "|r")
    end
    local stTxt, reqTxt, dTxt = table.concat(sp.stats or {}, "   ·   "), table.concat(reqParts, "  ·  "), sp.desc or ""
    local s, total
    for _, size in ipairs({ 13, 12.5, 12, 11.5 }) do
        right.desc:SetFont(Azaath.media.fontCard, size, "")
        total = 0
        for fs, txt in pairs({ [right.stats] = stTxt, [right.req] = reqTxt, [right.desc] = dTxt }) do
            local h = Measure(fs, txt)
            if h > 0 then total = total + h + 6 end
        end
        s = Clamp((Room(0) - total) / (Room(0) - Room(1)), DIAG_MIN, 1)
        if Room(s) >= total then break end
    end
    local over = total - Room(s)
    if over > 0 and right.desc.SetMaxLines and right.desc.h > 0 then
        local _, size = right.desc:GetFont()
        local lineH = (size or 13) + 1.5
        right.desc:SetMaxLines(max(1, floor((right.desc.h - over) / lineH)))
        right.desc.h = right.desc:GetStringHeight() or right.desc.h
    end
    right.target = s
end

local function LayoutRight()
    local s = right.scale
    local w, h = DIAG_BOX[3] * s, DIAG_BOX[4] * s
    local left = DIAG_BOX[1] + DIAG_BOX[3] / 2 - w / 2
    local top = DIAG_BOX[2] + 6 * (1 - s)
    right.diag:SetSize(w, h)
    At(right.diag, rightF, left, top, "TOPLEFT")
    At(right.iconHolder, rightF, left + DIAG_ICON[1] * s, top + DIAG_ICON[2] * s)
    right.diagGlow:SetSize(w, h)
    At(right.diagGlow, rightF, left, top, "TOPLEFT")
    right.iconRing:SetSize(ICON_RING_K * s, ICON_RING_K * s)
    right.rim:SetSize(66 * s, 66 * s)
    right.flash:SetSize(110 * s, 110 * s)
    if not anim.iconPop then right.icon:SetSize(62 * s, 62 * s) end
    local y0 = TextTop(s)
    local y = y0
    for _, fs in ipairs({ right.stats, right.req, right.desc }) do
        if (fs.h or 0) > 0 then
            At(fs, rightF, 884, y, "TOP")
            y = y + fs.h + 6
        end
    end
    right.hover:SetSize(330, max(1, y - y0))
    At(right.hover, rightF, 884, y0, "TOP")
end

local function RenderRight(reveal)
    local sp, s = selSpell, schools[selSchool]
    if not (sp and s) then
        for _, b in ipairs(right.blocks) do b:Hide() end
        right.iconHolder:Hide()
        return
    end
    ParseTooltip(sp)
    right.kind:SetText(format("%s · %s", Upper(s.name), sp.passive and "PASSIVA" or "TÉCNICA"))
    FitName(right.name, Tracked(Upper(sp.name)), 268)
    local n = RankNumber(sp.rank)
    right.grau:SetText(n and format("GRAU %d", n) or (sp.passive and "SEMPRE ATIVA" or Upper((sp.rank ~= "" and sp.rank) or "SEM GRAUS")))
    local gw = right.grau:GetStringWidth() or 40
    At(right.gem, rightF, 868 - gw / 2 - 9, 225.5)
    right.icon:SetTexture(sp.icon)
    right.iconHolder:Show()

    FitRight(sp)
    if not reveal then right.scale = right.target end
    LayoutRight()

    for _, b in ipairs(right.blocks) do b:Show() end
    if reveal then
        anim.rightReveal = { t = 0 }
        anim.iconPop = { t = 0 }
        for _, b in ipairs(right.blocks) do b:SetAlpha(0) end
    else
        for _, b in ipairs(right.blocks) do b:SetAlpha(1) end
    end
end

--------------------------------------------------------------------------------
-- Mesa de Runas
--------------------------------------------------------------------------------
local function BuildMesa()
    mesaF = CreateFrame("Frame", nil, art)
    mesaF:SetAllPoints(art)
    mesaF:SetFrameLevel(art:GetFrameLevel() + 3)
    local media = Azaath.media

    -- folha de pergaminho com moldura de couro e bronze (cobre o painel antigo da arte)
    mesa.panel = Tex(mesaF, "BORDER", GRIM .. "GrimMesa")
    mesa.panel:SetSize(MESA_BOX[3], MESA_BOX[4])
    mesa.panel:SetTexCoord(0, 640 / 1024, 0, 348 / 512)
    At(mesa.panel, mesaF, MESA_BOX[1], MESA_BOX[2], "TOPLEFT")

    -- título em tinta com floreios, como os capítulos
    mesa.title = Text(mesaF, media.fontTitleB, 11.5, INK)
    mesa.title:SetText("MESA DE RUNAS")
    At(mesa.title, mesaF, 1200, 594)
    if mesaF.CreateLine then
        local w = mesa.title:GetStringWidth() or 110
        local x0, x1 = 1200 - w / 2 - 8, 1200 + w / 2 + 8
        for _, seg in ipairs({ { x0 - 44, 594, x0, 594 }, { x0 - 36, 596.5, x0 - 6, 596.5 },
                               { x1, 594, x1 + 44, 594 }, { x1 + 6, 596.5, x1 + 36, 596.5 } }) do
            SetLine(InkLine(mesaF), seg[1], seg[2], seg[3], seg[4], mesaF)
        end
    end

    -- abas: marcadores de couro iguais aos do livro, em miniatura
    mesa.tabs = {}
    for i, bar in ipairs(BARS) do
        local t = CreateFrame("Button", nil, mesaF)
        t:SetSize(MESA_TAB_W, MESA_TAB_H)
        At(t, mesaF, MESA_TAB_X[i], MESA_TAB_Y)
        t.glow = Tex(t, "BACKGROUND", MEDIA .. "Glow", "BLEND")
        t.glow:SetPoint("CENTER"); t.glow:SetSize(MESA_TAB_W * 1.5, MESA_TAB_H * 2.0)
        t.glow:SetVertexColor(AZ_TEAL[1], AZ_TEAL[2], AZ_TEAL[3], 1); t.glow:SetAlpha(0)
        t.leather = Tex(t, "ARTWORK", GRIM .. "GrimTab")
        t.leather:SetAllPoints(t)
        t.leather:SetTexCoord(0, 106 / 128, 0, 54 / 64)
        t.text = Text(t, media.fontCinzel or media.fontTitleB, 9, CREAM)
        t.text:SetShadowOffset(1, -1); t.text:SetShadowColor(0, 0, 0, 0.85)
        t.text:SetPoint("CENTER", t, "CENTER", 6, 0)
        t.text:SetText(bar.label)
        t.lit = (i == mesaBar) and 1 or 0
        t:SetScript("OnClick", function()
            if mesaBar == i then return end
            mesaBar = i
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            M:UpdateMesa()
        end)
        t:SetScript("OnEnter", function(self) self.hover = true end)
        t:SetScript("OnLeave", function(self) self.hover = false end)
        mesa.tabs[i] = t
    end

    -- encaixes: medalhões de bronze, como os da página
    mesa.slots = {}
    for _, sy in ipairs(SLOT_Y) do
        for _, sx in ipairs(SLOT_X) do
            local s = CreateFrame("Button", nil, mesaF)
            s:SetSize(SLOT, SLOT)
            s.x, s.y, s.lift = sx, sy, 1
            s:RegisterForDrag("LeftButton")
            s:RegisterForClicks("LeftButtonUp")
            s.glow = Tex(s, "BACKGROUND", MEDIA .. "CastRingHalo", "BLEND")
            s.glow:SetPoint("CENTER"); s.glow:SetSize(SLOT * 1.4, SLOT * 1.4)
            s.glow:SetVertexColor(AZ_TEAL[1], AZ_TEAL[2], AZ_TEAL[3], 1); s.glow:SetAlpha(0)
            s.well = Tex(s, "BORDER", MEDIA .. "Disc")
            s.well:SetPoint("CENTER"); s.well:SetSize(SLOT_ICON + 2, SLOT_ICON + 2)
            s.well:SetVertexColor(0.17, 0.12, 0.08, 1)
            s.icon = Tex(s, "ARTWORK")
            s.icon:SetPoint("CENTER"); s.icon:SetSize(SLOT_ICON, SLOT_ICON)
            s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
            CircleMask(s, s.icon)
            s.plus = Tex(s, "ARTWORK", MEDIA .. "MapUI\\Plus", nil, 1)
            s.plus:SetSize(10, 10); s.plus:SetPoint("CENTER"); s.plus:SetVertexColor(0.86, 0.74, 0.52, 0.55)
            s.ring = Tex(s, "OVERLAY", GRIM .. "GrimMedal")
            s.ring:SetAllPoints(s)
            -- número da tecla num pequeno selo de pergaminho
            s.keyBg = Tex(s, "OVERLAY", MEDIA .. "Disc", nil, 2)
            s.keyBg:SetSize(15, 15); s.keyBg:SetPoint("CENTER", s, "BOTTOMRIGHT", -6, 7)
            s.keyBg:SetVertexColor(0.86, 0.77, 0.6, 1)
            s.keyRim = Tex(s, "OVERLAY", MEDIA .. "Ring", nil, 3)
            s.keyRim:SetSize(16, 16); s.keyRim:SetPoint("CENTER", s.keyBg)
            s.keyRim:SetVertexColor(0.45, 0.32, 0.16, 1)
            s.key = Text(s, media.fontCard, 8.5, INK)
            s.key:SetPoint("CENTER", s.keyBg, "CENTER", 0, 0)
            s:SetScript("OnEnter", function(self)
                self.hover = true
                if self.slot and HasAction(self.slot) then
                    GameTooltip:SetOwner(self, "ANCHOR_TOP")
                    GameTooltip:SetAction(self.slot)
                    GameTooltip:Show()
                end
            end)
            s:SetScript("OnLeave", function(self) self.hover = false; GameTooltip:Hide() end)
            local function Drop(self)
                if InCombatLockdown() or not self.slot then return end
                if GetCursorInfo() then PlaceAction(self.slot) end
            end
            s:SetScript("OnReceiveDrag", Drop)
            s:SetScript("OnClick", Drop)
            s:SetScript("OnDragStart", function(self)
                if not InCombatLockdown() and self.slot then PickupAction(self.slot) end
            end)
            mesa.slots[#mesa.slots + 1] = s
        end
    end
    -- totais (pílula escura abaixo do livro)
    mesa.totals = Text(mesaF, media.fontTitleB, 9, { 0.62, 0.63, 0.66 })
    At(mesa.totals, mesaF, 617, 727)
end

local function PlaceSlot(s)
    local sc = max(0.05, s.lift)
    s:SetScale(sc)
    s:ClearAllPoints()
    s:SetPoint("CENTER", mesaF, "TOPLEFT", s.x / sc, -s.y / sc)
end

function M:UpdateMesa()
    if not mesaF then return end
    local bar = BARS[mesaBar]
    local base = BarBase(bar)
    local selName = selSpell and selSpell.name
    for i, s in ipairs(mesa.slots) do
        local slot = base + i
        s.slot = slot
        local has = HasAction(slot)
        if has then
            s.icon:SetTexture(GetActionTexture(slot)); s.icon:Show(); s.plus:Hide()
        else
            s.icon:Hide(); s.plus:Show()
        end
        s.key:SetText(ShortKey(GetBindingKey(format(bar.bind, i))) or tostring(i))
        s.hit = has and selName and (ActionSpellName(slot) == selName) or false
        PlaceSlot(s)
    end
end

local function UpdateTotals()
    local act, pas, nokey = 0, 0, 0
    for _, s in ipairs(schools) do
        pas = pas + #s.passives
        for _, sp in ipairs(s.actives) do
            act = act + 1
            if not (bindMap[sp.name] and bindMap[sp.name].key) then nokey = nokey + 1 end
        end
    end
    mesa.totals:SetText(format("FEITIÇOS  %d        PASSIVAS  %d        |cffc09068SEM ATALHO  %d|r", act, pas, nokey))
end

--------------------------------------------------------------------------------
-- Folha virando
--------------------------------------------------------------------------------
local function BuildFlip()
    flipF = CreateFrame("Frame", nil, art)
    flipF:SetAllPoints(art)
    flipF:SetFrameLevel(art:GetFrameLevel() + 60)   -- acima dos textos das páginas
    flip.sheet = Tex(flipF, "ARTWORK", GRIM .. "GrimPage")
    flip.sheet:Hide()
    flip.shade = Tex(flipF, "ARTWORK", Azaath.media.blank, nil, 1)
    flip.shade:Hide()
    flip.cast = Tex(flipF, "BORDER", Azaath.media.blank)   -- sombra projetada na página de baixo
    flip.cast:Hide()
    flip.edge = Tex(flipF, "OVERLAY", MEDIA .. "Glow", "ADD")
    flip.edge:SetVertexColor(CYAN[1], CYAN[2], CYAN[3], 0.5); flip.edge:Hide()
    for i = 1, 44 do
        local t = Tex(flipF, "OVERLAY", (i % 5 == 0) and (MEDIA .. "Star") or (MEDIA .. "Glow"), "ADD", 2)
        t:Hide()
        particles[i] = { tex = t, life = 0 }
    end
end

local partIdx = 0
local function EmitParticle(x, y)
    partIdx = partIdx % #particles + 1
    local p = particles[partIdx]
    p.x, p.y = x + (random() - 0.5) * 6, y
    p.vx, p.vy = (random() - 0.5) * 45, -(16 + random() * 38)
    p.life = 0.7 + random() * 0.5
    p.size = 1.8 + random() * 3.2
    local ice = random() < 0.35
    p.tex:SetVertexColor(ice and 0.72 or CYAN[1], ice and 0.96 or CYAN[2], ice and 1.0 or CYAN[3], 1)
    p.L = p.life
    p.tex:Show()
end

-- dir = 1: folha da direita vai para a esquerda (avança); -1: volta
local function StartFlip(dir, applyStart, applyEnd)
    if flip.active and flip.applyEnd then flip.applyEnd() end
    flip.active, flip.t, flip.dir = true, 0, dir
    flip.applyEnd = applyEnd
    if applyStart then applyStart() end
    flip.sheet:Show(); flip.shade:Show(); flip.cast:Show(); flip.edge:Show()
    Azaath.PlaySound("igAbiliityPageTurn")
end

local function UpdateFlip(dt)
    if not flip.active then return end
    flip.t = flip.t + dt
    local u = min(1, flip.t / FLIP_TIME)
    local e = Smooth(u)
    local lift = sin(pi * e)
    local firstHalf = e < 0.5
    local w = max(1, PW * abs(1 - 2 * e))
    local h = PH * (1 + 0.035 * lift)
    local top = PTOP - 10 * lift
    local onRight = (flip.dir == 1) == firstHalf   -- folha sobre a página direita?
    local sheet = flip.sheet
    sheet:ClearAllPoints()
    sheet:SetSize(w, h)
    if onRight then
        sheet:SetPoint("TOPLEFT", flipF, "TOPLEFT", SPINE, -top)
        sheet:SetTexCoord(PW / 512, 0, 0, PH / 512)      -- espelhada: frente da página direita
    else
        sheet:SetPoint("TOPRIGHT", flipF, "TOPLEFT", SPINE, -top)
        sheet:SetTexCoord(0, PW / 512, 0, PH / 512)
    end
    local light = 0.62 + 0.38 * (w / PW)
    sheet:SetVertexColor(light, light * 0.97, light * 0.92)

    -- sombreado da dobra (escurece perto da lombada)
    local shade = flip.shade
    shade:ClearAllPoints()
    shade:SetSize(min(w, 60), h)
    if onRight then
        shade:SetPoint("TOPLEFT", sheet, "TOPLEFT", 0, 0)
        Azaath.Gradient(shade, "HORIZONTAL", 0, 0, 0, 0.35 * lift, 0, 0, 0, 0)
    else
        shade:SetPoint("TOPRIGHT", sheet, "TOPRIGHT", 0, 0)
        Azaath.Gradient(shade, "HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, 0.35 * lift)
    end
    -- sombra projetada além da borda livre
    local cast = flip.cast
    cast:ClearAllPoints()
    cast:SetSize(40 * lift + 1, PH)
    local edgeX
    if onRight then
        edgeX = SPINE + w
        cast:SetPoint("TOPLEFT", flipF, "TOPLEFT", edgeX, -PTOP)
        Azaath.Gradient(cast, "HORIZONTAL", 0, 0, 0, 0.3 * lift, 0, 0, 0, 0)
    else
        edgeX = SPINE - w
        cast:SetPoint("TOPRIGHT", flipF, "TOPLEFT", edgeX, -PTOP)
        Azaath.Gradient(cast, "HORIZONTAL", 0, 0, 0, 0, 0, 0, 0, 0.3 * lift)
    end
    flip.edge:ClearAllPoints()
    flip.edge:SetSize(18, h * 0.9)
    flip.edge:SetPoint("CENTER", flipF, "TOPLEFT", edgeX, -(top + h / 2))
    flip.edge:SetAlpha(0.38 * lift)

    -- poeira fina de Azaath saindo da borda da folha
    EmitParticle(edgeX, top + 20 + random() * (h - 40))
    if random() < 0.65 then EmitParticle(edgeX, top + 20 + random() * (h - 40)) end

    if u >= 1 then
        flip.active = false
        sheet:Hide(); flip.shade:Hide(); flip.cast:Hide(); flip.edge:Hide()
        local fn = flip.applyEnd
        flip.applyEnd = nil
        if fn then fn() end
    end
end

--------------------------------------------------------------------------------
-- Navegação
--------------------------------------------------------------------------------
local function FirstSpell(s, p)
    p = p or CurrentPage(s)
    local L = s.layout[p] or s.layout[1]
    return L.medals[1] or L.seals[1]
end

SelectSpell = function(sp)
    if sp == selSpell then return end
    selSpell = sp
    M.db.grimoireSpell = sp.name
    Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
    UpdateSelectionMarks()
    RenderRight(true)
    M:UpdateMesa()
end

-- Vira para outro capítulo e/ou página. A página que fica por baixo da folha
-- recebe o conteúdo novo na hora; a outra, quando a folha assenta.
local function TurnTo(schoolIdx, pageNum)
    local s = schools[schoolIdx]
    if not s then return end
    local oldS, oldP = selSchool, schools[selSchool] and CurrentPage(schools[selSchool]) or 1
    pageNum = Clamp(pageNum or CurrentPage(s), 1, s.pages)
    if schoolIdx == oldS and pageNum == oldP then return end
    local dir = (schoolIdx > oldS or (schoolIdx == oldS and pageNum > oldP)) and 1 or -1
    local function apply(which)
        return function()
            selSchool = schoolIdx
            subPage[s.key] = pageNum
            M.db.grimoireSchool = s.key
            local keep = false
            for _, x in ipairs(s.actives) do if x == selSpell then keep = true end end
            for _, x in ipairs(s.passives) do if x == selSpell then keep = true end end
            if not keep or schoolIdx ~= oldS then selSpell = FirstSpell(s, pageNum) end
            if selSpell then M.db.grimoireSpell = selSpell.name end
            if which == "left" then
                RenderLeft(true)
                UpdateSelectionMarks()
            else
                RenderRight(true)
                M:UpdateMesa()
            end
        end
    end
    -- avança: a página direita (por baixo) muda já; a esquerda ao assentar
    if dir == 1 then
        StartFlip(1, apply("right"), apply("left"))
    else
        StartFlip(-1, apply("left"), apply("right"))
    end
end

ChangeChapter = function(i)
    if i == selSchool or not schools[i] then return end
    TurnTo(i, CurrentPage(schools[i]))
end

--------------------------------------------------------------------------------
-- Ambiente: velas, cristais, runas e faíscas da página
--------------------------------------------------------------------------------
local function BuildAmbient()
    local function G(x, y, w, h, r, g, b, layer)
        local t = Tex(art, layer or "ARTWORK", MEDIA .. "Glow", "ADD")
        t:SetSize(w, h); t:SetVertexColor(r, g, b, 1)
        At(t, art, x, y)
        return t
    end
    ambient.flames = { G(128, 96, 70, 90, 1, 0.72, 0.35), G(82, 192, 60, 78, 1, 0.72, 0.35) }
    ambient.candleLight = G(110, 170, 300, 280, 1, 0.62, 0.28, "BORDER")
    ambient.crystal = G(1272, 168, 170, 200, CYAN[1], CYAN[2], CYAN[3])
    ambient.runes = { G(1176, 282, 60, 50, CYAN[1], CYAN[2], CYAN[3]), G(1248, 306, 60, 50, CYAN[1], CYAN[2], CYAN[3]),
                      G(1220, 522, 70, 70, CYAN[1], CYAN[2], CYAN[3]), G(1215, 432, 80, 40, CYAN[1], CYAN[2], CYAN[3]) }
end

local function UpdateAmbient(dt, t)
    for i, f in ipairs(ambient.flames) do
        local flick = 0.55 + 0.2 * sin(t * 9.3 + i * 2) + 0.12 * sin(t * 23.7 + i)
        f:SetAlpha(Clamp(flick, 0.2, 1) * 0.6)
    end
    ambient.candleLight:SetAlpha(0.10 + 0.04 * sin(t * 7.1))
    ambient.crystal:SetAlpha(0.22 + 0.12 * sin(t * 1.6))
    for i, r in ipairs(ambient.runes) do r:SetAlpha(0.18 + 0.14 * sin(t * 1.3 + i * 1.7)) end
end

--------------------------------------------------------------------------------
-- Montagem a partir dos dados
--------------------------------------------------------------------------------
local function Rebuild()
    needData = false
    BuildSchools()
    BuildBindMap()
    needBinds = false
    local wantSchool, wantSpell = M.db.grimoireSchool, selSpell and selSpell.name or M.db.grimoireSpell
    selSchool, selSpell = nil, nil
    for i, s in ipairs(schools) do
        if s.key == wantSchool then selSchool = i end
    end
    selSchool = selSchool or (schools[2] and 2) or (schools[1] and 1)
    local s = schools[selSchool]
    if s then
        for pn, pg in ipairs(s.layout) do
            for _, list in ipairs({ pg.medals, pg.seals }) do
                for k = 1, PER_PAGE do
                    local sp = list[k]
                    if sp and sp.name == wantSpell then
                        selSpell = sp
                        subPage[s.key] = pn
                    end
                end
            end
        end
        selSpell = selSpell or FirstSpell(s)
    end
    LayoutTabs(true)
    RenderLeft(false)
    UpdateSelectionMarks()
    RenderRight(false)
    M:UpdateMesa()
    UpdateTotals()
end

local function RefreshBinds()
    needBinds = false
    BuildBindMap()
    M:UpdateMesa()
    UpdateTotals()
end

--------------------------------------------------------------------------------
-- Animação (um único OnUpdate, só com a aba visível)
--------------------------------------------------------------------------------
local function OnUpdate(_, dt)
    if dt > 0.05 then dt = 0.05 end
    clock = clock + dt
    local t = clock
    if needData then Rebuild() elseif needBinds then RefreshBinds() end

    UpdateAmbient(dt, t)
    UpdateFlip(dt)

    -- poeira de Azaath da folha
    for _, p in ipairs(particles) do
        if p.life > 0 then
            p.life = p.life - dt
            p.x, p.y = p.x + p.vx * dt, p.y + p.vy * dt
            p.vy = p.vy + 8 * dt
            At(p.tex, flipF, p.x, p.y)
            local k = max(0, p.life / p.L)
            p.tex:SetSize(p.size * (0.35 + 0.65 * k), p.size * (0.35 + 0.65 * k))
            p.tex:SetAlpha(k * 0.78)
            if p.life <= 0 then p.tex:Hide() end
        end
    end

    -- marcadores: o selecionado sai do livro (9 px) com luz de fundo ciano, filetes
    -- de luz no couro e o mini-sinete aceso; o hover é a versão leve (4 px)
    local pulse = 0.5 + 0.5 * sin(t * 2.4)
    for i, b in ipairs(tabWidgets) do
        if b:IsShown() then
            local on = (i == selSchool)
            local wantPull = on and TAB_PULL_SEL or (b.hover and TAB_PULL_HOVER or 0)
            local wantFx = on and 1 or (b.hover and 0.4 or 0)
            b.pull = Damp(b.pull, wantPull, 0.002, dt)
            b.fxAlpha = Damp(b.fxAlpha or 0, wantFx, 0.003, dt)
            PlaceTab(b, i)
            local a = b.fxAlpha
            local gemA = on and a or a * 0.5
            b.gemGlow:SetAlpha(gemA * (0.35 + 0.2 * pulse))
            b.gem:SetAlpha(gemA)
            b.gemCore:SetAlpha(gemA * (0.7 + 0.3 * pulse))
            if on then
                b.text:SetTextColor(1.0, 0.88, 0.6)
            elseif b.hover then
                b.text:SetTextColor(1.0, 0.96, 0.88)
            else
                b.text:SetTextColor(CREAM[1], CREAM[2], CREAM[3])
            end
        end
    end

    -- medalhões: surgimento em cascata, hover e brilho do selecionado
    local lr = anim.leftReveal
    if lr then lr.t = lr.t + dt end
    local order = 0
    for _, list in ipairs({ medals, seals }) do
        for _, b in ipairs(list) do
            if b:IsShown() then
                order = order + 1
                if lr then b.pop = 0.01 + 0.99 * BackOut(Clamp((lr.t - order * 0.06) / 0.4, 0, 1)) end
                b.lift = Damp(b.lift, b.hover and 1.08 or 1, 0.002, dt)
                PlaceMedal(b)
                local sel = (b.sp == selSpell)
                b.fx = Damp(b.fx, sel and 1 or (b.hover and 0.45 or 0), 0.003, dt)
                b.aura:SetAlpha(b.fx * (sel and (0.88 + 0.12 * sin(t * 2.2)) or 0.65))
                b.auraCore:SetAlpha(b.fx * (sel and (0.55 + 0.15 * sin(t * 2.2)) or 0.25))
                if b.label then b.label:SetAlpha(lr and Clamp((lr.t - order * 0.06) / 0.3, 0, 1) or 1) end
            end
        end
    end
    if lr and lr.t > 1.2 then anim.leftReveal = nil end

    -- página direita: revelação e ícone surgindo no diagrama
    local rr = anim.rightReveal
    if rr then
        rr.t = rr.t + dt
        local done = true
        for i, b in ipairs(right.blocks) do
            local u = Clamp((rr.t - i * 0.05) / 0.45, 0, 1)
            b:SetAlpha(EaseOut(u))
            if u < 1 then done = false end
        end
        if done then anim.rightReveal = nil end
    end
    local ip = anim.iconPop
    if ip then
        ip.t = ip.t + dt
        local u = min(1, ip.t / 0.55)
        local s = (0.3 + 0.7 * BackOut(u)) * right.scale
        right.icon:SetSize(62 * s, 62 * s)
        right.flash:SetAlpha(1 - u)
        if u >= 1 then anim.iconPop = nil end
    end
    -- diagrama e aro reacendem a cada feitiço novo (junto com o ícone) e pulsam leve
    local gk = ip and Clamp(ip.t / 0.6, 0, 1) or 1
    right.diagGlow:SetAlpha(gk * (0.84 + 0.16 * sin(t * 2)))
    right.iconRing:SetAlpha(gk * (0.9 + 0.1 * sin(t * 2.6)))
    -- diagrama encolhe/cresce suavemente até a escala que faz o texto caber
    if abs(right.scale - right.target) > 0.001 then
        right.scale = Damp(right.scale, right.target, 0.004, dt)
        LayoutRight()
    end

    -- Mesa: marcador ativo aceso, encaixes que sobem no hover e pulso do feitiço escolhido
    for i, tb2 in ipairs(mesa.tabs) do
        tb2.lit = Damp(tb2.lit, (i == mesaBar) and 1 or (tb2.hover and 0.5 or 0), 0.003, dt)
        local k = 0.62 + 0.38 * tb2.lit
        tb2.leather:SetVertexColor(k, k, k)
        tb2.glow:SetAlpha(tb2.lit * (0.45 + 0.12 * sin(t * 2.4)))
        tb2.text:SetTextColor(CREAM[1] * k + (1 - k) * 0.2 + 0.07 * tb2.lit, CREAM[2] * k + 0.04 * tb2.lit, CREAM[3] * k - 0.04 * tb2.lit)
    end
    for _, s in ipairs(mesa.slots) do
        s.lift = Damp(s.lift, s.hover and 1.1 or 1, 0.002, dt)
        PlaceSlot(s)
        s.glow:SetAlpha(s.hit and (0.5 + 0.25 * (0.5 + 0.5 * sin(t * 4))) or (s.hover and 0.3 or 0))
    end
end

--------------------------------------------------------------------------------
-- Construção da página (chamada pela ficha, Modules/Sheet/)
--------------------------------------------------------------------------------
local function FitArt()
    if not (art and root) then return end
    local w, h = root:GetWidth(), root:GetHeight()
    if not (w and h and w > 0 and h > 0) then return end
    art:SetScale(max(w / ART_W, h / ART_H))
end

function M:BuildPage(pg, cw, ch)
    page = pg
    self.db = Azaath.db.sheet
    pg.grimoire = true
    -- a arte cobre a tela inteira (atrás do cabeçalho e do rodapé da ficha)
    root = pg:GetParent() and pg:GetParent():GetParent() or UIParent

    art = CreateFrame("Frame", nil, pg)
    art:SetSize(ART_W, ART_H)
    art:SetPoint("CENTER", root, "CENTER", 0, 0)
    FitArt()
    local bg = Tex(art, "BACKGROUND", GRIM .. "GrimBG")
    bg:SetAllPoints(art)
    bg:SetTexCoord(0, (ART_W * 2) / 4096, 0, (ART_H * 2) / 2048)

    BuildAmbient()
    BuildTabs()
    BuildLeft()
    BuildRight()
    BuildMesa()
    BuildFlip()

    left.prev:SetScript("OnClick", function()
        local s = schools[selSchool]
        if s then TurnTo(selSchool, CurrentPage(s) - 1) end
    end)
    left.next:SetScript("OnClick", function()
        local s = schools[selSchool]
        if s then TurnTo(selSchool, CurrentPage(s) + 1) end
    end)
    leftF:SetScript("OnMouseWheel", function(_, delta)
        local s = schools[selSchool]
        if s and s.pages > 1 then TurnTo(selSchool, CurrentPage(s) - delta) end
    end)

    pg:SetScript("OnShow", function()
        FitArt()
        if needData then Rebuild() else
            RefreshBinds()
            RenderLeft(true)
            UpdateSelectionMarks()
            RenderRight(true)
        end
        Azaath.PlaySound("igSpellBookOpen")
    end)
    pg:SetScript("OnHide", function()
        if flip.active then
            flip.t = FLIP_TIME
            UpdateFlip(0)
        end
        for _, p in ipairs(particles) do p.life = 0; p.tex:Hide() end
    end)
    pg:SetScript("OnUpdate", OnUpdate)
end

function M:Refresh()
    if page and page:IsShown() then needBinds = true end
end

-- Ativo = a página foi montada na ficha (aí a tecla do livro, o micromenu e o
-- menu radial abrem a ficha no Grimório em vez do livro antigo)
function M:IsActive()
    return (page and page.grimoire and Azaath.db.sheet and Azaath.db.sheet.enabled) and true or false
end

function M:IsOpen()
    local sheet = Azaath:GetModule("Sheet")
    return (page and page:IsVisible() and sheet and sheet.IsOpen and sheet:IsOpen()) and true or false
end

function M:Toggle()
    local sheet = Azaath:GetModule("Sheet")
    if sheet and sheet.Toggle then sheet:Toggle("spellbook") end
end

-- Tecla do livro de feitiços (P): botão comum (a ficha não é protegida, abre em combate)
local keyOwner, keySignature
local function UpdateKeyBinding()
    if not (keyOwner and M:IsActive()) then return end
    local k1, k2 = GetBindingKey("TOGGLESPELLBOOK")
    local sig = (k1 or "") .. "," .. (k2 or "")
    if sig == keySignature then return end
    Azaath:RunOutOfCombat(function()
        keySignature = sig
        ClearOverrideBindings(keyOwner)
        for _, k in ipairs({ k1, k2 }) do
            if k and k ~= "" then SetOverrideBindingClick(keyOwner, false, k, "AzaathUIGrimoireToggle", "LeftButton") end
        end
    end)
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_PET" then
        if unit == "player" then needData = true end
    elseif event == "UPDATE_BINDINGS" then
        needBinds = true
        UpdateKeyBinding()
    elseif event == "ACTIONBAR_SLOT_CHANGED" or event == "UPDATE_SHAPESHIFT_FORMS"
        or event == "ACTIONBAR_PAGE_CHANGED" or event == "UPDATE_BONUS_ACTIONBAR" then
        needBinds = true
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        FitArt()
    else
        needData = true
    end
end)

function M:OnEnable()
    for _, e in ipairs({ "SPELLS_CHANGED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "PET_BAR_UPDATE",
                         "UNIT_PET", "ACTIONBAR_SLOT_CHANGED", "UPDATE_BINDINGS", "UPDATE_SHAPESHIFT_FORMS",
                         "ACTIONBAR_PAGE_CHANGED", "UPDATE_BONUS_ACTIONBAR", "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED" }) do
        Azaath.SafeRegister(events, e)
    end
    if self:IsActive() then
        local b = CreateFrame("Button", "AzaathUIGrimoireToggle", UIParent)
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnClick", function() M:Toggle() end)
        keyOwner = CreateFrame("Frame")
        UpdateKeyBinding()
    end
end
