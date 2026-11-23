--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Sheet/Skills.lua
    Ficha do personagem: aba Perícias (arte de conceito).
    Símbolos comuns vêm de Azaath.SheetUI (Modules/Sheet/Core.lua).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.SheetUI
local _G, floor, format, ipairs = _G, math.floor, string.format, ipairs
local max, min, pairs, pcall = math.max, math.min, pairs, pcall
local random, sin, tostring = math.random, math.sin, tostring
local Call, CollectSkills, ListPage, M = U.Call, U.CollectSkills, U.ListPage, U.M
local MEDIA_ROOT, MakeButton, Num, SHEET_MEDIA = U.MEDIA_ROOT, U.MakeButton, U.Num, U.SHEET_MEDIA
local SI, Show, SkillCount, SkillData = U.SI, U.Show, U.SkillCount, U.SkillData
local SkillDetail, selected = U.SkillDetail, U.selected

--------------------------------------------------------------------------------
-- Aba Perícias: arte de conceito tools/skills-concept (Pericias_ConceptArt*.png,
-- desenho da interface em ui.js). Fundo SkillsBG = o salão rúnico com o vórtice de
-- lâminas (epic.js); ícones e cápsulas = SkillsIcons/SkillsParts (gen.js). Tudo em
-- px da arte 2000x1125 (o quadro é escalado para cobrir a tela, como a Reputação).
--   3 cartões no topo escolhem a página: Arsenal (armas em treino em cartões com
--   barra, não treinadas, "como funciona") | Ofícios (cartões com a escada de
--   faixas) | Domínios (grupos completos com selos). Detalhe da escolhida à direita.
--------------------------------------------------------------------------------
M.BuildSkillsPage = (function()
local SKL = {
    W = 2000, H = 1125,
    nav = { y = 118, w = 440, h = 92, gap = 24 },          -- 3 cartões de navegação
    page = { x = 40, y = 236, w = 1420, h = 806 },         -- área da página
    detail = { x = 1484, y = 236, w = 476, h = 806 },      -- painel de detalhe
    acard = { w = 325, h = 150, gap = 20 },                -- arma em treino
    ucard = { h = 70 },                                    -- arma não treinada
    ocard = { w = 668, h = 300, gap = 24 },                -- ofício
    anvil = { 1000, 784 },
}
local SKL_ICONS = SHEET_MEDIA .. "SkillsIcons"
local SKL_PARTS = SHEET_MEDIA .. "SkillsParts"
local SKL_GOLD, SKL_GOLD2 = { 0.85, 0.71, 0.42 }, { 0.95, 0.84, 0.60 }
local SKL_CYAN, SKL_DIM = { 0.50, 0.88, 1.0 }, { 0.50, 0.59, 0.64 }

-- mesma ordem de ICON_ORDER em tools/skills-concept/weapons.js (8 por linha, 128 px)
local SKL_ICON = {}
for i, k in ipairs({ "sword", "great", "dagger", "axe", "axe2", "mace", "mace2", "bow",
    "gun", "thrown", "fist", "shield", "spear", "staff", "crossbow", "wand",
    "claw", "pick", "pan", "hook", "cross", "flask", "hammer", "leaf",
    "needle", "gear", "crystal", "hide", "key", "horseshoe", "book", "armor", "star" }) do
    SKL_ICON[k] = i - 1
end

-- nome da perícia (pt-BR ou inglês) -> ícone; a ordem importa (duas mãos antes)
local SKL_ICON_RULES = {
    { { "duas mãos", "two%-hand" }, { "espada", "sword" }, "great" },
    { { "duas mãos", "two%-hand" }, { "machado", "axe" }, "axe2" },
    { { "duas mãos", "two%-hand" }, { "maça", "mace" }, "mace2" },
    { { "punho", "fist weapon" }, nil, "claw" },
    { { "adaga", "dagger" }, nil, "dagger" },
    { { "espada", "sword" }, nil, "sword" },
    { { "machado", "axe" }, nil, "axe" },
    { { "maça", "mace" }, nil, "mace" },
    { { "besta", "crossbow" }, nil, "crossbow" },
    { { "arco", "bow" }, nil, "bow" },
    { { "fogo", "gun" }, nil, "gun" },
    { { "arremess", "thrown" }, nil, "thrown" },
    { { "desarmad", "unarmed" }, nil, "fist" },
    { { "defesa", "defense" }, nil, "shield" },
    { { "haste", "polearm" }, nil, "spear" },
    { { "cajado", "staff", "staves" }, nil, "staff" },
    { { "varinha", "wand" }, nil, "wand" },
    { { "minera", "mining" }, nil, "pick" },
    { { "culin", "cooking" }, nil, "pan" },
    { { "pesca", "fishing" }, nil, "hook" },
    { { "socorro", "first aid" }, nil, "cross" },
    { { "alquim", "alchemy" }, nil, "flask" },
    { { "ferraria", "blacksmith" }, nil, "hammer" },
    { { "herbor", "herbalism" }, nil, "leaf" },
    { { "alfaiat", "tailor" }, nil, "needle" },
    { { "engenhar", "engineer" }, nil, "gear" },
    { { "encanta", "enchant" }, nil, "crystal" },
    { { "courar", "couro", "leather" }, nil, "hide" },
    { { "esfola", "skinning" }, nil, "dagger" },
    { { "arromba", "lockpick" }, nil, "key" },
    { { "montaria", "riding" }, nil, "horseshoe" },
}
local function SkillHas(s, list)
    for _, w in ipairs(list) do if s:find(w) then return true end end
    return false
end
local function SkillIcon(name)
    local s = (name or ""):lower()
    for _, r in ipairs(SKL_ICON_RULES) do
        if SkillHas(s, r[1]) and (not r[2] or SkillHas(s, r[2])) then return r[3] end
    end
    return "star"
end

-- cabeçalho do jogo -> grupo da página
local function SkillGroup(header)
    local s = (header or ""):lower()
    if s:find("arma") and not s:find("armadura") or s:find("weapon") then return "weapon" end
    if s:find("secund") or s:find("secondary") then return "secondary" end
    if s:find("profiss") or s:find("profession") then return "profession" end
    if s:find("armadura") or s:find("armor") then return "ARMADURAS" end
    if s:find("classe") or s:find("class") then return "CLASSE" end
    if s:find("ngua") or s:find("language") then return "LÍNGUAS" end
    return Azaath.Upper(header or "OUTRAS")
end

local SKL_TIERS = { { 75, "Aprendiz" }, { 150, "Artífice" }, { 225, "Especialista" }, { 300, "Artesão" }, { 375, "Mestre" }, { 450, "Grão-Mestre" } }
local function SkillTier(maxRank)
    for i, t in ipairs(SKL_TIERS) do if maxRank <= t[1] then return i end end
    return #SKL_TIERS
end

local function SkillTierColor(r)
    if r >= 0.95 then return 0.95, 0.80, 0.51 end
    if r >= 0.5 then return 0.43, 0.86, 1.0 end
    if r > 0.02 then return 0.31, 0.63, 0.78 end
    return 0.35, 0.41, 0.45
end

local function WeaponCap(level) return 5 * level end

-- Lê o painel de perícias inteiro e separa nos grupos da página.
local function CollectSkillModel()
    local m = { weapons = {}, untrained = {}, crafts = {}, domains = {}, domainOrder = {}, all = {}, total = 0 }
    -- cabeçalhos recolhidos escondem as perícias: abre todos (0 = todos)
    for i = 1, SkillCount() do
        local d = SkillData(i)
        if d and d.isHeader and d.collapsed then
            Call((SI and SI.ExpandSkillHeader) or _G.ExpandSkillHeader, 0)
            break
        end
    end
    local group = "CLASSE"
    for i = 1, SkillCount() do
        local d = SkillData(i)
        if d and d.name then
            if d.isHeader then
                group = SkillGroup(d.name)
            elseif not (d.parent and Num(d.parent, 0) ~= 0) then
                local e = { idx = i, name = d.name, rank = Num(d.rank, 0), max = Num(d.maxRank, 0), mod = Num(d.modifier, 0),
                            desc = (d.desc and d.desc ~= "") and d.desc or nil, abandonable = d.abandonable, group = group,
                            icon = SkillIcon(d.name) }
                e.ratio = e.max > 1 and max(0, min(1, e.rank / e.max)) or 1
                m.total = m.total + 1
                m.all[#m.all + 1] = e
                if group == "weapon" then
                    e.kind = "weapon"
                    if e.rank <= 1 and e.max > 1 then m.untrained[#m.untrained + 1] = e else m.weapons[#m.weapons + 1] = e end
                elseif group == "profession" or group == "secondary" then
                    e.kind = "craft"
                    e.primary = group == "profession"
                    m.crafts[#m.crafts + 1] = e
                else
                    e.kind = "domain"
                    if not m.domains[group] then m.domains[group] = {}; m.domainOrder[#m.domainOrder + 1] = group end
                    local g = m.domains[group]
                    g[#g + 1] = e
                end
            end
        end
    end
    table.sort(m.weapons, function(a, b)
        if a.ratio ~= b.ratio then return a.ratio > b.ratio end
        return a.name < b.name
    end)
    -- profissões primeiro, depois as secundárias
    local crafts = {}
    for _, e in ipairs(m.crafts) do if e.primary then crafts[#crafts + 1] = e end end
    for _, e in ipairs(m.crafts) do if not e.primary then crafts[#crafts + 1] = e end end
    m.crafts = crafts
    local nd = 0
    for _, g in pairs(m.domains) do nd = nd + #g end
    m.mastered = nd
    local cap = 0
    for _, e in ipairs(m.weapons) do cap = max(cap, e.max) end
    for _, e in ipairs(m.untrained) do cap = max(cap, e.max) end
    m.cap = cap
    return m
end

local function BuildPage(page)
    local media = Azaath.media
    local fontC = media.fontCinzel or media.fontTitleB
    local fontCB = media.fontTitleB
    local R = SKL
    local root = page:GetParent() and page:GetParent():GetParent() or UIParent

    local art = CreateFrame("Frame", nil, page)
    art:SetSize(R.W, R.H)
    art:SetPoint("CENTER", root, "CENTER", 0, 0)
    local function Fit()
        local w, h = root:GetWidth(), root:GetHeight()
        if not (w and h and w > 0 and h > 0) then w, h = UIParent:GetWidth(), UIParent:GetHeight() end
        art:SetScale(max(w / R.W, h / R.H))
    end
    Fit()
    page:HookScript("OnShow", Fit)

    local bg = art:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetTexture(SHEET_MEDIA .. "SkillsBG")
    bg:SetTexCoord(0, R.W / 2048, 0, R.H / 2048)
    bg:SetAllPoints(art)

    local function At(region, x, y, point, rel)
        region:ClearAllPoints()
        region:SetPoint(point or "CENTER", rel or art, "TOPLEFT", x, -y)
    end
    local function Txt(parent, font, size, col, justify)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        fs:SetFont(font, size, "")
        fs:SetShadowOffset(1.5, -1.5)
        fs:SetShadowColor(0, 0, 0, 0.9)
        fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
        fs:SetJustifyH(justify or "LEFT")
        fs:SetWordWrap(false)
        return fs
    end
    local function Tex(parent, layer, sub, file, r, g, b, a)
        local t = parent:CreateTexture(nil, layer, nil, sub)
        t:SetTexture(file or media.blank)
        if r then t:SetVertexColor(r, g, b, a or 1) end
        return t
    end
    local function Color(fs, c) fs:SetTextColor(c[1], c[2], c[3], c[4] or 1) end

    -- caixa: degradê escuro + borda de 1 px (ou 2 quando selecionada)
    local function Box(parent, top, bot)
        local f = CreateFrame("Frame", nil, parent)
        f.fill = Tex(f, "BACKGROUND", 0)
        f.fill:SetAllPoints(f)
        f.edges = {}
        for i = 1, 4 do
            local e = Tex(f, "BORDER", 0)
            if i == 1 then e:SetPoint("TOPLEFT") e:SetPoint("TOPRIGHT")
            elseif i == 2 then e:SetPoint("BOTTOMLEFT") e:SetPoint("BOTTOMRIGHT")
            elseif i == 3 then e:SetPoint("TOPLEFT") e:SetPoint("BOTTOMLEFT")
            else e:SetPoint("TOPRIGHT") e:SetPoint("BOTTOMRIGHT") end
            e.horiz = i <= 2
            f.edges[i] = e
        end
        function f:Paint(tp, bt) Azaath.Gradient(self.fill, "VERTICAL", bt[1], bt[2], bt[3], bt[4], tp[1], tp[2], tp[3], tp[4]) end
        function f:SetBorder(r, g, b, a, wid)
            for _, e in ipairs(self.edges) do
                e:SetVertexColor(r, g, b, a)
                if e.horiz then e:SetHeight(wid or 1) else e:SetWidth(wid or 1) end
            end
        end
        f:Paint(top or { 0.047, 0.11, 0.157, 0.92 }, bot or { 0.02, 0.05, 0.08, 0.94 })
        f:SetBorder(0.47, 0.76, 0.86, 0.24)
        return f
    end

    -- cápsula em 3 partes (pontas redondas não esticam): fill + contorno
    local function Capsule(parent, layer)
        local c = { parts = {} }
        for row = 0, 1 do
            for p = 1, 3 do
                local t = Tex(parent, layer or "BORDER", row, SKL_PARTS)
                local u0, u1 = (p == 1 and 0 or p == 2 and 16 or 112) / 256, (p == 1 and 16 or p == 2 and 112 or 128) / 256
                t:SetTexCoord(u0, u1, row * 32 / 128, (row + 1) * 32 / 128)
                c.parts[row * 3 + p] = t
            end
        end
        function c:Place(rel, x, y, w, h)
            local cap = h * 0.5
            for row = 0, 1 do
                local l, m, r = self.parts[row * 3 + 1], self.parts[row * 3 + 2], self.parts[row * 3 + 3]
                l:SetSize(cap, h) m:SetSize(max(1, w - cap * 2), h) r:SetSize(cap, h)
                l:ClearAllPoints() l:SetPoint("TOPLEFT", rel, "TOPLEFT", x, -y)
                m:ClearAllPoints() m:SetPoint("TOPLEFT", l, "TOPRIGHT", 0, 0)
                r:ClearAllPoints() r:SetPoint("TOPLEFT", m, "TOPRIGHT", 0, 0)
            end
        end
        function c:Color(fr, fg, fb, fa, br, bg2, bb, ba)
            for p = 1, 3 do self.parts[p]:SetVertexColor(fr, fg, fb, fa) end
            for p = 4, 6 do self.parts[p]:SetVertexColor(br, bg2, bb, ba) end
        end
        function c:Show(on) for _, t in ipairs(self.parts) do Show(t, on) end end
        return c
    end

    local function IconCoords(t, key)
        local i = SKL_ICON[key] or SKL_ICON.star
        local u, v = (i % 8) * 128 / 1024, floor(i / 8) * 128 / 1024
        t:SetTexCoord(u + 2 / 1024, u + 126 / 1024, v + 2 / 1024, v + 126 / 1024)
    end

    -- emblema: halo + disco escuro + aro fino na cor do progresso + ícone
    local function Emblem(parent, cx, cy, Rr)
        local e = {}
        e.halo = Tex(parent, "BACKGROUND", 2, MEDIA_ROOT .. "Glow")
        e.halo:SetBlendMode("ADD")
        e.halo:SetSize(Rr * 3.6, Rr * 3.6)
        e.disc = Tex(parent, "BORDER", 2, MEDIA_ROOT .. "Disc", 0.012, 0.04, 0.063, 0.97)
        e.disc:SetSize(Rr * 2, Rr * 2)
        e.rim = Tex(parent, "BORDER", 3, MEDIA_ROOT .. "CastRingThin")
        e.rim:SetSize(Rr * 2.08, Rr * 2.08)
        e.icon = Tex(parent, "ARTWORK", 1, SKL_ICONS)
        e.icon:SetSize(Rr * 1.9, Rr * 1.9)
        function e:Move(x, y)
            for _, t in ipairs({ self.halo, self.disc, self.rim, self.icon }) do t:ClearAllPoints() t:SetPoint("CENTER", parent, "TOPLEFT", x, -y) end
        end
        function e:Set(key, ratio, dim, haloA)
            local r, g, b = SkillTierColor(dim and 0 or ratio)
            IconCoords(self.icon, key)
            if dim then self.icon:SetVertexColor(0.48, 0.55, 0.58)
            elseif ratio >= 0.95 then self.icon:SetVertexColor(1.0, 0.90, 0.70)
            else self.icon:SetVertexColor(0.90, 0.97, 1.0) end
            self.rim:SetVertexColor(r, g, b, dim and 0.35 or 0.85)
            self.halo:SetVertexColor(r, g, b, haloA or (dim and 0 or 0.16))
        end
        function e:Show(on) for _, t in ipairs({ self.halo, self.disc, self.rim, self.icon }) do Show(t, on) end end
        e:Move(cx, cy)
        return e
    end

    -- barra com degradê e ponta clara
    local function Bar(parent)
        local b = {}
        b.track = Tex(parent, "BORDER", 4, nil, 0.012, 0.04, 0.06, 0.95)
        b.fill = Tex(parent, "ARTWORK", 0)
        b.tip = Tex(parent, "ARTWORK", 1, nil, 1, 1, 1, 0.9)
        function b:Place(x, y, w, h)
            self.w = w
            self.track:SetSize(w, h)
            self.track:ClearAllPoints()
            self.track:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
            self.fill:SetHeight(h - 2)
            self.fill:ClearAllPoints()
            self.fill:SetPoint("LEFT", self.track, "LEFT", 1, 0)
            self.tip:SetSize(2, h - 2)
        end
        function b:Set(ratio)
            local r, g, bb = SkillTierColor(ratio)
            local fw = max(1, (self.w - 2) * ratio)
            self.fill:SetWidth(fw)
            Azaath.Gradient(self.fill, "HORIZONTAL", r * 0.35, g * 0.5, bb * 0.6, 1, r, g, bb, 1)
            self.tip:ClearAllPoints()
            self.tip:SetPoint("CENTER", self.track, "LEFT", 1 + fw, 0)
            Show(self.fill, ratio > 0) Show(self.tip, ratio > 0 and ratio < 1)
        end
        function b:Show(on) Show(self.track, on) if not on then self.fill:Hide() self.tip:Hide() end end
        return b
    end

    -- cabeçalho de seção: losango + título dourado + número + nota à direita
    local function Heading(parent)
        local h = {}
        h.d = Tex(parent, "ARTWORK", 1, MEDIA_ROOT .. "Diamond", SKL_GOLD[1], SKL_GOLD[2], SKL_GOLD[3])
        h.d:SetSize(12, 12)
        h.t = Txt(parent, fontCB, 18, SKL_GOLD)
        h.n = Txt(parent, media.fontBold, 18, { 1, 1, 1 })
        h.r = Txt(parent, media.font, 16, SKL_DIM, "RIGHT")
        function h:Set(x, y, w, title, count, right)
            At(self.d, x + 6, y, "CENTER", parent)
            self.t:SetText(Azaath.Tracked(title))
            At(self.t, x + 22, y, "LEFT", parent)
            self.n:SetText(count and tostring(count) or "")
            self.n:ClearAllPoints()
            self.n:SetPoint("LEFT", self.t, "RIGHT", 12, 0)
            self.r:SetText(right or "")
            At(self.r, x + w, y, "RIGHT", parent)
            for _, r in ipairs({ self.d, self.t, self.n, self.r }) do r:Show() end
        end
        function h:Hide() for _, r in ipairs({ self.d, self.t, self.n, self.r }) do r:Hide() end end
        return h
    end

    local state = { page = (M.db and M.db.skillsPage) or "arsenal" }
    local S = {}
    page.skills = S

    local function Select(name)
        selected.skills, selected.abandon = name, nil
        Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        U.dirty = true
    end
    local function Hover(card)
        card:SetScript("OnEnter", function(self) if not self.sel then self.box:SetBorder(0.55, 0.88, 1.0, 0.6) end end)
        card:SetScript("OnLeave", function(self) if not self.sel then self.box:SetBorder(self.b0[1], self.b0[2], self.b0[3], self.b0[4]) end end)
    end
    -- botão-cartão: caixa por trás, conteúdo por cima
    local function Card(parent, w, h, top, bot)
        local c = CreateFrame("Button", nil, parent)
        c:SetSize(w, h)
        c.box = Box(c, top, bot)
        c.box:SetAllPoints(c)
        c.box:SetFrameLevel(c:GetFrameLevel())
        c.ct = CreateFrame("Frame", nil, c)
        c.ct:SetAllPoints(c)
        c.ct:SetFrameLevel(c:GetFrameLevel() + 1)
        c.b0 = { 0.47, 0.76, 0.86, 0.24 }
        c:SetScript("OnClick", function(self) if self.entry then Select(self.entry.name) end end)
        Hover(c)
        return c
    end
    local function MarkSel(c, isSel, base)
        c.sel = isSel
        c.b0 = base or c.b0
        for _, e in ipairs(c.box.edges) do e:SetAlpha(1) end
        if isSel then c.box:SetBorder(0.51, 0.88, 1.0, 0.95, 2)
        else c.box:SetBorder(c.b0[1], c.b0[2], c.b0[3], c.b0[4], 1) end
    end

    --==========================================================================
    -- Efeitos: brasas da bigorna e poeira de luz (abaixo dos painéis)
    --==========================================================================
    local fx = CreateFrame("Frame", nil, art)
    fx:SetAllPoints(art)
    fx:SetFrameLevel(art:GetFrameLevel() + 1)
    local forge = Tex(fx, "BORDER", 3, MEDIA_ROOT .. "Glow", 1.0, 0.55, 0.22, 0.3)
    forge:SetBlendMode("ADD")
    At(forge, R.anvil[1] - 30, R.anvil[2])
    local function Rand(a, b) return a + random() * (b - a) end
    local embers = {}
    local function SpawnEmber(p, initial)
        p.life = Rand(1.6, 3.2)
        p.t = initial and random() * p.life or 0
        p.x0 = R.anvil[1] - 30 + Rand(-70, 70)
        p.vx = Rand(-40, 40)
        p.h = Rand(160, 420)
        p.size = Rand(2.5, 5)
        p.amax = Rand(0.5, 1)
        local warm = random() < 0.75
        p.tex:SetVertexColor(warm and 1 or 0.55, warm and Rand(0.55, 0.8) or 0.9, warm and 0.3 or 1)
    end
    for i = 1, 30 do
        local p = { tex = Tex(fx, "ARTWORK", 3, MEDIA_ROOT .. "Glow") }
        p.tex:SetBlendMode("ADD")
        p.tex:SetAlpha(0)
        SpawnEmber(p, true)
        embers[i] = p
    end

    local ui = CreateFrame("Frame", nil, art)
    ui:SetAllPoints(art)
    ui:SetFrameLevel(art:GetFrameLevel() + 6)

    --==========================================================================
    -- Navegação: 3 cartões grandes (Arsenal, Ofícios, Domínios)
    --==========================================================================
    local NV = R.nav
    S.nav = {}
    local NAVDEF = { { "arsenal", "sword", "Arsenal" }, { "oficios", "pick", "Ofícios" }, { "dominios", "star", "Domínios" } }
    local nx0 = R.W / 2 - (NV.w * 3 + NV.gap * 2) / 2
    for i, def in ipairs(NAVDEF) do
        local c = Card(ui, NV.w, NV.h)
        At(c, nx0 + (i - 1) * (NV.w + NV.gap), NV.y, "TOPLEFT")
        c.key = def[1]
        c.em = Emblem(c.ct, 50, NV.h / 2, 30)
        c.title = Txt(c.ct, fontCB, 22, SKL_GOLD2)
        c.title:SetText(Azaath.Tracked(def[3]))
        c.title:SetPoint("LEFT", c, "TOPLEFT", 98, -34)
        c.sub = Txt(c.ct, media.font, 16, { 0.81, 0.89, 0.92 })
        c.sub:SetPoint("LEFT", c, "TOPLEFT", 98, -63)
        c.badge = Capsule(c.ct, "ARTWORK")
        c.badgeText = Txt(c.ct, media.fontBold, 13, SKL_GOLD2, "CENTER")
        c.line = Tex(c.ct, "ARTWORK", 2, MEDIA_ROOT .. "Glow", 0.67, 0.92, 1.0, 0.9)
        c.line:SetBlendMode("ADD")
        c.line:SetSize(NV.w - 40, 6)
        c.line:SetPoint("CENTER", c, "BOTTOM", 0, 1)
        c.icon = def[2]
        c:SetScript("OnClick", function(self)
            if state.page ~= self.key then
                state.page = self.key
                if M.db then M.db.skillsPage = self.key end
                selected.abandon = nil
                Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
                U.dirty = true
            end
        end)
        S.nav[i] = c
    end

    --==========================================================================
    -- Área da página e painel de detalhe
    --==========================================================================
    local P = R.page
    local pageBox = Box(ui, { 0.016, 0.047, 0.07, 0.72 }, { 0.012, 0.03, 0.05, 0.80 })
    pageBox:SetSize(P.w, P.h)
    At(pageBox, P.x, P.y, "TOPLEFT")
    pageBox:SetBorder(0.47, 0.76, 0.86, 0.14)
    local x0, w0 = P.x + 30, P.w - 60
    local PB = P.y + P.h - 14   -- nada passa daqui

    -- Arsenal --------------------------------------------------------------
    local A = { cards = {}, un = {}, tips = {} }
    A.h1, A.h2, A.h3 = Heading(ui), Heading(ui), Heading(ui)
    local AC = R.acard
    local function ArsenalCard(i)
        local c = A.cards[i]
        if c then return c end
        c = Card(ui, AC.w, AC.h)
        c.em = Emblem(c.ct, 52, 56, 34)
        c.name = Txt(c.ct, media.fontBold, 21, { 1, 1, 1 })
        c.name:SetPoint("LEFT", c, "TOPLEFT", 100, -40)
        c.name:SetWidth(AC.w - 112)
        c.val = Txt(c.ct, fontC, 28, { 1, 1, 1 })
        c.val:SetPoint("LEFT", c, "TOPLEFT", 100, -75)
        c.maxv = Txt(c.ct, media.font, 17, SKL_DIM)
        c.maxv:SetPoint("LEFT", c.val, "RIGHT", 6, -2)
        c.bar = Bar(c.ct)
        c.bar:Place(20, 101, AC.w - 40, 10)
        c.status = Txt(c.ct, media.fontBold, 13, SKL_CYAN)
        c.status:SetPoint("LEFT", c, "TOPLEFT", 20, -134)
        c.left = Txt(c.ct, media.font, 15, SKL_DIM, "RIGHT")
        c.left:SetPoint("RIGHT", c, "TOPLEFT", AC.w - 20, -134)
        A.cards[i] = c
        return c
    end
    local UC = R.ucard
    local function UnCard(i)
        local c = A.un[i]
        if c then return c end
        c = Card(ui, 100, UC.h, { 0.03, 0.07, 0.10, 0.85 }, { 0.016, 0.04, 0.06, 0.9 })
        c.b0 = { 0.43, 0.59, 0.65, 0.18 }
        c.em = Emblem(c.ct, 36, UC.h / 2, 22)
        c.name = Txt(c.ct, media.font, 16, { 0.71, 0.76, 0.78 })
        c.name:SetPoint("LEFT", c, "TOPLEFT", 70, -26)
        c.val = Txt(c.ct, media.font, 14, { 0.44, 0.51, 0.55 })
        c.val:SetPoint("LEFT", c, "TOPLEFT", 70, -49)
        A.un[i] = c
        return c
    end
    local TIPS = {
        { "mace", "Use a arma para treinar", "Golpes em inimigos do seu nível dão pontos." },
        { "star", "O teto sobe com o nível", "Teto = 5 × seu nível: +5 a cada nível." },
        { "shield", "Defesa treina apanhando", "Receber golpes de inimigos do seu nível treina a Defesa." },
    }
    local tipW = (w0 - 40) / 3
    for i, tip in ipairs(TIPS) do
        local b = Box(ui, { 0.04, 0.086, 0.118, 0.70 }, { 0.02, 0.047, 0.07, 0.75 })
        b:SetSize(tipW, 96)
        b:SetBorder(0.47, 0.76, 0.86, 0.14)
        local ct = CreateFrame("Frame", nil, b)
        ct:SetAllPoints(b)
        ct:SetFrameLevel(b:GetFrameLevel() + 1)
        local em = Emblem(ct, 44, 48, 26)
        em:Set(tip[1], 0.6, false, 0.08)
        local t = Txt(ct, media.fontBold, 18, { 0.89, 0.93, 0.95 })
        t:SetText(tip[2])
        t:SetPoint("LEFT", b, "TOPLEFT", 84, -34)
        local d = Txt(ct, media.font, 15, SKL_DIM)
        d:SetText(tip[3])
        d:SetPoint("LEFT", b, "TOPLEFT", 84, -62)
        d:SetWidth(tipW - 96)
        A.tips[i] = b
    end

    -- Ofícios ---------------------------------------------------------------
    local O = { cards = {} }
    O.h1 = Heading(ui)
    local OC = R.ocard
    local function CraftCard(i)
        local c = O.cards[i]
        if c then return c end
        c = Card(ui, OC.w, OC.h)
        c.em = Emblem(c.ct, 76, 82, 52)
        c.tag = Txt(c.ct, media.fontBold, 13, SKL_GOLD)
        c.tag:SetPoint("LEFT", c, "TOPLEFT", 150, -42)
        c.name = Txt(c.ct, media.fontBold, 28, { 1, 1, 1 })
        c.name:SetPoint("LEFT", c, "TOPLEFT", 150, -76)
        c.name:SetWidth(OC.w - 330)
        c.tier = Txt(c.ct, media.font, 18, SKL_CYAN)
        c.tier:SetPoint("LEFT", c, "TOPLEFT", 150, -112)
        c.maxv = Txt(c.ct, media.font, 19, SKL_DIM, "RIGHT")
        c.maxv:SetPoint("RIGHT", c, "TOPLEFT", OC.w - 30, -86)
        c.val = Txt(c.ct, fontC, 36, { 1, 1, 1 }, "RIGHT")
        c.val:SetPoint("RIGHT", c.maxv, "LEFT", -6, 3)
        c.bar = Bar(c.ct)
        c.bar:Place(30, 154, OC.w - 60, 12)
        c.steps = {}
        local sw = (OC.w - 60) / 4
        for k = 1, 4 do
            local st = {}
            st.line = Tex(c.ct, "ARTWORK", 0)
            st.line:SetSize(sw - 8, 4)
            st.line:SetPoint("TOPLEFT", c, "TOPLEFT", 30 + (k - 1) * sw, -196)
            st.name = Txt(c.ct, media.font, 15, SKL_DIM)
            st.name:SetPoint("LEFT", c, "TOPLEFT", 30 + (k - 1) * sw, -220)
            st.cap = Txt(c.ct, media.font, 13, { 0.37, 0.47, 0.52 })
            st.cap:SetPoint("LEFT", c, "TOPLEFT", 30 + (k - 1) * sw, -242)
            c.steps[k] = st
        end
        c.next = Txt(c.ct, media.font, 16, { 0.73, 0.79, 0.82 })
        c.next:SetPoint("LEFT", c, "TOPLEFT", 30, -276)
        O.cards[i] = c
        return c
    end

    -- Domínios --------------------------------------------------------------
    local Dm = { groups = {}, items = {} }
    Dm.h1 = Heading(ui)
    local DCW = (w0 - 48) / 3
    local function GroupCard(i)
        local g = Dm.groups[i]
        if g then return g end
        g = Box(ui)
        g:SetWidth(DCW)
        g:SetBorder(0.85, 0.71, 0.42, 0.4)
        g.ct = CreateFrame("Frame", nil, g)
        g.ct:SetAllPoints(g)
        g.ct:SetFrameLevel(g:GetFrameLevel() + 1)
        g.em = Emblem(g.ct, 50, 54, 30)
        g.title = Txt(g.ct, fontCB, 20, SKL_GOLD2)
        g.title:SetPoint("LEFT", g, "TOPLEFT", 96, -46)
        g.count = Txt(g.ct, media.font, 15, SKL_DIM)
        g.count:SetPoint("LEFT", g, "TOPLEFT", 96, -72)
        Dm.groups[i] = g
        return g
    end
    local function DomItem(i)
        local c = Dm.items[i]
        if c then return c end
        c = Card(ui, DCW - 40, 52, { 0.157, 0.133, 0.078, 0.6 }, { 0.04, 0.035, 0.024, 0.7 })
        c.b0 = { 0.85, 0.71, 0.42, 0.3 }
        c.seal = Tex(c.ct, "ARTWORK", 0, SKL_PARTS)
        c.seal:SetTexCoord(128 / 256, 160 / 256, 0, 32 / 128)
        c.seal:SetSize(26, 26)
        c.seal:SetPoint("CENTER", c, "LEFT", 28, 0)
        c.text = Txt(c.ct, media.font, 18, { 0.94, 0.90, 0.81 })
        c.text:SetPoint("LEFT", c, "LEFT", 52, 0)
        c.text:SetWidth(DCW - 110)
        Dm.items[i] = c
        return c
    end

    -- Detalhe ---------------------------------------------------------------
    local DP = R.detail
    local D = Box(ui, { 0.04, 0.10, 0.14, 0.92 }, { 0.016, 0.047, 0.07, 0.95 })
    D:SetSize(DP.w, DP.h)
    At(D, DP.x, DP.y, "TOPLEFT")
    D:SetBorder(0.47, 0.78, 0.88, 0.30)
    D.ct = CreateFrame("Frame", nil, D)
    D.ct:SetAllPoints(D)
    D.ct:SetFrameLevel(D:GetFrameLevel() + 1)
    local dcx = DP.w / 2
    D.em = Emblem(D.ct, dcx, 130, 82)
    D.kind = Txt(D.ct, media.fontBold, 14, SKL_GOLD, "CENTER")
    D.kind:SetPoint("CENTER", D, "TOPLEFT", dcx, -248)
    D.name = Txt(D.ct, fontC, 36, { 1, 1, 1 }, "CENTER")
    D.name:SetPoint("CENTER", D, "TOPLEFT", dcx, -290)
    D.name:SetWidth(DP.w - 40)
    D.val = Txt(D.ct, fontC, 34, SKL_GOLD2, "RIGHT")
    D.maxv = Txt(D.ct, media.font, 20, SKL_DIM)
    D.bar = Bar(D.ct)
    D.bar:Place(36, 366, DP.w - 72, 12)
    D.line = Txt(D.ct, media.font, 17, { 0.84, 0.89, 0.91 }, "CENTER")
    D.line:SetPoint("CENTER", D, "TOPLEFT", dcx, -412)
    D.line:SetWidth(DP.w - 40)
    D.facts = {}
    for k = 1, 4 do
        local y = 470 + (k - 1) * 46
        local f = {}
        f.sep = Tex(D.ct, "ARTWORK", 0, nil, 0.47, 0.75, 0.84, 0.14)
        f.sep:SetSize(DP.w - 60, 1)
        f.sep:SetPoint("TOPLEFT", D, "TOPLEFT", 30, -(y - 24))
        f.l = Txt(D.ct, media.font, 17, SKL_DIM)
        f.l:SetPoint("LEFT", D, "TOPLEFT", 36, -y)
        f.r = Txt(D.ct, media.font, 17, { 0.93, 0.96, 0.97 }, "RIGHT")
        f.r:SetPoint("RIGHT", D, "TOPLEFT", DP.w - 36, -y)
        D.facts[k] = f
    end
    D.desc = Txt(D.ct, media.font, 16, { 0.62, 0.70, 0.74 }, "CENTER")
    D.desc:SetWordWrap(true)
    D.desc:SetWidth(DP.w - 70)
    D.desc:SetPoint("TOP", D, "TOPLEFT", dcx, -650)
    D.empty = Txt(D.ct, media.font, 18, SKL_DIM, "CENTER")
    D.empty:SetWordWrap(true)
    D.empty:SetWidth(DP.w - 80)
    D.empty:SetPoint("CENTER", D, "TOPLEFT", dcx, -320)
    D.empty:SetText("Selecione uma perícia para ver os detalhes.")
    D.btns = {}
    for k = 1, 2 do
        local b = MakeButton(D.ct, "Abandonar", 160, function(self) if self.onAct then self.onAct() end end)
        b:Hide()
        D.btns[k] = b
    end
    S.D = D

    --==========================================================================
    -- Preenchimento
    --==========================================================================
    local function FillDetail(e)
        local has = e ~= nil
        for _, r in ipairs({ D.kind, D.name, D.val, D.maxv, D.line, D.desc }) do Show(r, has) end
        D.em:Show(has)
        D.bar:Show(has)
        Show(D.empty, not has)
        for _, f in ipairs(D.facts) do f.sep:Hide() f.l:Hide() f.r:Hide() end
        for _, b in ipairs(D.btns) do b:Hide() end
        if not has then return end
        local L = Num(UnitLevel("player"), 1)
        local maxL = (Azaath.API and Azaath.API.MaxLevel and Azaath.API.MaxLevel()) or 60
        local ranked = e.max > 1
        D.em:Set(e.icon, ranked and e.ratio or 1, e.kind == "weapon" and e.rank <= 1, 0.25)
        local kind = e.kind == "weapon" and "Perícia com armas" or e.kind == "craft" and (e.primary and "Profissão" or "Perícia secundária")
            or ("Domínio  ·  " .. (e.group or ""))
        D.kind:SetText(Azaath.Tracked(kind))
        D.name:SetText(e.name)
        if ranked then
            D.val:SetText(tostring(e.rank))
            D.maxv:SetText("/ " .. e.max)
            local vw, mw = D.val:GetStringWidth() or 40, D.maxv:GetStringWidth() or 50
            D.val:ClearAllPoints()
            D.val:SetPoint("LEFT", D, "TOPLEFT", dcx - (vw + mw + 6) / 2, -336)
            D.maxv:ClearAllPoints()
            D.maxv:SetPoint("LEFT", D.val, "RIGHT", 6, -3)
            D.val:SetTextColor(e.ratio >= 0.95 and SKL_GOLD2[1] or 1, e.ratio >= 0.95 and SKL_GOLD2[2] or 1, e.ratio >= 0.95 and SKL_GOLD2[3] or 1)
            D.bar:Set(e.ratio)
        else
            D.val:SetText("")
            D.maxv:SetText("")
            D.bar:Show(false)
        end
        local facts, line = {}, ""
        local left = e.max - e.rank
        if e.kind == "weapon" then
            line = e.rank <= 1 and "Ainda não treinada: aprenda com um mestre de armas."
                or left == 1 and format("Falta 1 ponto para o teto do nível %d", L)
                or left > 0 and format("Faltam %d pontos para o teto do nível %d", left, L)
                or format("No teto do nível %d: suba de nível para avançar", L)
            facts[#facts + 1] = { "Teto atual", format("%d  (nível %d)", e.max, L) }
            if L < maxL then facts[#facts + 1] = { "Próximo teto", format("%d no nível %d", WeaponCap(L + 1), L + 1) } end
            if e.mod ~= 0 then facts[#facts + 1] = { "Bônus", format("%+d de equipamento e talentos", e.mod) } end
        elseif e.kind == "craft" then
            local ti = SkillTier(e.max)
            local nt = SKL_TIERS[ti + 1]
            line = left > 0 and format("Faltam %d pontos para o teto de %s", left, SKL_TIERS[ti][2])
                or (nt and format("No teto de %s: procure um treinador", SKL_TIERS[ti][2]) or "Domínio máximo deste ofício")
            facts[#facts + 1] = { "Faixa", SKL_TIERS[ti][2] .. format("  (até %d)", e.max) }
            if nt then
                facts[#facts + 1] = { "Próxima faixa", format("%s  (até %d)", nt[2], nt[1]) }
                facts[#facts + 1] = { "Treinar", e.rank >= e.max - 25 and "Disponível agora" or format("a partir de %d", e.max - 25) }
            end
            if e.mod ~= 0 then facts[#facts + 1] = { "Bônus", format("%+d", e.mod) } end
        else
            line = (not ranked or left <= 0) and "Completa: nada a treinar" or format("Faltam %d pontos", left)
            facts[#facts + 1] = { "Estado", (not ranked or left <= 0) and "Dominada" or "Em progresso" }
        end
        D.line:SetText(line)
        for k, f in ipairs(D.facts) do
            local v = facts[k]
            if v then f.l:SetText(v[1]) f.r:SetText(v[2]) f.sep:Show() f.l:Show() f.r:Show() end
        end
        D.desc:SetText(e.desc or "")
        if e.abandonable then
            local confirming = selected.abandon == e.name
            local b1, b2 = D.btns[1], D.btns[2]
            b1.text:SetText(Azaath.Tracked(confirming and "Confirmar" or "Abandonar"))
            b1.onAct = function()
                if confirming then
                    Call((SI and SI.AbandonSkill) or _G.AbandonSkill, e.idx)
                    selected.skills, selected.abandon = nil, nil
                else
                    selected.abandon = e.name
                end
                U.dirty = true
            end
            b1:ClearAllPoints()
            b1:SetPoint("CENTER", D, "BOTTOMLEFT", dcx + (confirming and -88 or 0), 50)
            b1:Show()
            if confirming then
                b2.text:SetText(Azaath.Tracked("Cancelar"))
                b2.onAct = function() selected.abandon = nil; U.dirty = true end
                b2:ClearAllPoints()
                b2:SetPoint("CENTER", D, "BOTTOMLEFT", dcx + 88, 50)
                b2:Show()
                D.desc:SetText("|cffff6050Confirmar desaprende " .. e.name .. ". Todo o progresso será perdido.|r")
            end
        end
    end

    local function HideAll()
        A.h1:Hide() A.h2:Hide() A.h3:Hide() O.h1:Hide() Dm.h1:Hide()
        for _, list in ipairs({ A.cards, A.un, A.tips, O.cards, Dm.groups, Dm.items }) do
            for _, f in ipairs(list) do f:Hide() end
        end
    end

    local function FillArsenal(m, selName)
        local L = Num(UnitLevel("player"), 1)
        local maxL = (Azaath.API and Azaath.API.MaxLevel and Azaath.API.MaxLevel()) or 60
        local capNote = m.cap > 0 and (format("Teto atual: %d (5 × nível %d)", m.cap, L)
            .. (L < maxL and format("   ·   no nível %d sobe para %d", L + 1, WeaponCap(L + 1)) or "")) or ""
        local y = P.y + 40
        A.h1:Set(x0, y, w0, "Em treino", #m.weapons, capNote)
        local cy = y + 30
        for i, e in ipairs(m.weapons) do
            local c = ArsenalCard(i)
            local col, row = (i - 1) % 4, floor((i - 1) / 4)
            local yy = cy + row * (AC.h + AC.gap)
            At(c, x0 + col * (AC.w + AC.gap), yy, "TOPLEFT")
            c.entry = e
            c.em:Set(e.icon, e.ratio, false, e.name == selName and 0.28 or 0.14)
            c.name:SetFont(media.fontBold, #e.name > 17 and 18 or 21, "")
            c.name:SetText(e.name)
            c.val:SetText(tostring(e.rank))
            Color(c.val, e.ratio >= 0.95 and SKL_GOLD2 or { 1, 1, 1 })
            c.maxv:SetText("/ " .. e.max)
            c.bar:Set(e.ratio)
            local st, sc = "TREINANDO", SKL_CYAN
            if e.ratio >= 0.95 then st, sc = "QUASE NO TETO", SKL_GOLD2
            elseif e.ratio < 0.5 then st, sc = "COMEÇANDO", { 0.47, 0.72, 0.84 } end
            local left = e.max - e.rank
            if left <= 0 then st, sc = "NO TETO", SKL_GOLD2 end
            c.status:SetText(Azaath.Tracked(st))
            Color(c.status, sc)
            c.left:SetText(left <= 0 and "suba de nível" or left == 1 and "falta 1" or ("faltam " .. left))
            Color(c.left, e.ratio >= 0.95 and SKL_GOLD2 or SKL_DIM)
            MarkSel(c, e.name == selName)
            Show(c, yy + AC.h <= PB)
        end
        local rows = math.ceil(#m.weapons / 4)
        y = cy + rows * (AC.h + AC.gap) - AC.gap + 50
        if #m.weapons == 0 then
            y = cy + 40
        end
        if #m.untrained > 0 and y + 28 + UC.h <= PB then
            A.h2:Set(x0, y, w0, "Não treinadas", #m.untrained, "aprenda com um mestre de armas nas capitais")
            local per = 5
            local uw = (w0 - (per - 1) * 16) / per
            for i, e in ipairs(m.untrained) do
                local c = UnCard(i)
                local col, row = (i - 1) % per, floor((i - 1) / per)
                local yy = y + 28 + row * (UC.h + 16)
                c:SetWidth(uw)
                At(c, x0 + col * (uw + 16), yy, "TOPLEFT")
                c.entry = e
                c.em:Set(e.icon, 0, true)
                c.name:SetFont(media.font, #e.name > 18 and 14 or 16, "")
                c.name:SetText(e.name)
                c.name:SetWidth(uw - 80)
                c.val:SetText(format("%d / %d", e.rank, e.max))
                MarkSel(c, e.name == selName)
                Show(c, yy + UC.h <= PB)
            end
            y = y + 28 + math.ceil(#m.untrained / per) * (UC.h + 16) - 16 + 40
        end
        if y + 26 + 96 <= PB then
            A.h3:Set(x0, y, w0, "Como funciona")
            for i, b in ipairs(A.tips) do
                At(b, x0 + (i - 1) * (tipW + 20), y + 26, "TOPLEFT")
                b:Show()
            end
        end
    end

    local function FillCrafts(m, selName)
        local n = #m.crafts
        O.h1:Set(x0, P.y + 40, w0, "Ofícios", n, "suba a faixa com um treinador quando chegar perto do teto")
        local rows = max(1, math.ceil(n / 2))
        local avail = PB - (P.y + 70)
        local s = min(1, (avail - (rows - 1) * OC.gap) / rows / OC.h)
        local cw, ch = OC.w * s, OC.h * s
        local gx0 = x0 + (w0 - (2 * cw + OC.gap)) / 2
        for i, e in ipairs(m.crafts) do
            local c = CraftCard(i)
            c:SetScale(s)
            local col, row = (i - 1) % 2, floor((i - 1) / 2)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", art, "TOPLEFT", (gx0 + col * (cw + OC.gap)) / s, -(P.y + 70 + row * (ch + OC.gap)) / s)
            c.entry = e
            c.em:Set(e.icon, e.ratio, false, e.name == selName and 0.28 or 0.16)
            c.tag:SetText(Azaath.Tracked(e.primary and "Profissão" or "Secundária"))
            Color(c.tag, e.primary and SKL_GOLD or { 0.54, 0.64, 0.68 })
            c.name:SetText(e.name)
            local ti = SkillTier(e.max)
            c.tier:SetText(SKL_TIERS[ti][2])
            c.val:SetText(tostring(e.rank))
            c.maxv:SetText("/ " .. e.max)
            c.bar:Set(e.ratio)
            -- escada: 4 faixas a partir da primeira que cabe (Aprendiz..Artesão, ou mais altas)
            local first = max(1, min(ti - 1, #SKL_TIERS - 3))
            for k, st in ipairs(c.steps) do
                local t = first + k - 1
                local tier = SKL_TIERS[t]
                local done, cur = t < ti, t == ti
                st.line:SetVertexColor(done and 0.85 or cur and 0.5 or 0.47, done and 0.71 or cur and 0.88 or 0.63, done and 0.42 or cur and 1 or 0.69, (done or cur) and 0.9 or 0.25)
                st.name:SetText(tier[2])
                st.name:SetFont(cur and media.fontBold or media.font, cur and 16 or 15, "")
                Color(st.name, done and SKL_GOLD2 or cur and SKL_CYAN or { 0.37, 0.47, 0.52 })
                st.cap:SetText(tostring(tier[1]))
            end
            local nt = SKL_TIERS[ti + 1]
            local left = e.max - e.rank
            if nt and e.rank >= e.max - 25 then
                c.next:SetText("Pronto para treinar " .. nt[2] .. " com um treinador")
                Color(c.next, SKL_GOLD2)
            elseif nt then
                c.next:SetText(format("Faltam %d pontos  ·  %s a partir de %d", left, nt[2], e.max - 25))
                Color(c.next, { 0.73, 0.79, 0.82 })
            else
                c.next:SetText(left > 0 and format("Faltam %d pontos", left) or "Domínio máximo")
                Color(c.next, { 0.73, 0.79, 0.82 })
            end
            MarkSel(c, e.name == selName, e.primary and { 0.85, 0.71, 0.42, 0.5 } or { 0.47, 0.76, 0.86, 0.24 })
            c:Show()
        end
        if n == 0 then O.h1:Set(x0, P.y + 40, w0, "Ofícios", 0, "nenhum ofício aprendido: procure um treinador nas cidades") end
    end

    local function FillDomains(m, selName)
        Dm.h1:Set(x0, P.y + 40, w0, "Domínios", m.mastered, "perícias já completas: não precisam de treino")
        local colH = { 0, 0, 0 }
        local ii = 0
        local EMB = { CLASSE = "star", ARMADURAS = "armor", ["LÍNGUAS"] = "book" }
        for gi, gname in ipairs(m.domainOrder) do
            local list = m.domains[gname]
            local g = GroupCard(gi)
            local col = 1
            for k = 2, 3 do if colH[k] < colH[col] then col = k end end
            local gx, gy = x0 + (col - 1) * (DCW + 24), P.y + 70 + colH[col]
            local h = 120 + #list * 64
            g:SetHeight(h)
            At(g, gx, gy, "TOPLEFT")
            g.em:Set(EMB[gname] or "star", 0.97, false, 0.12)
            g.title:SetText(Azaath.Tracked(gname))
            g.count:SetText(#list == 1 and "1 completa" or (#list .. " completas"))
            Show(g, gy + 120 <= PB)
            for k, e in ipairs(list) do
                ii = ii + 1
                local c = DomItem(ii)
                local iy = gy + 116 + (k - 1) * 64
                At(c, gx + 20, iy, "TOPLEFT")
                c.entry = e
                c.text:SetText(e.max > 1 and format("%s  %d/%d", e.name, e.rank, e.max) or e.name)
                local done = e.max <= 1 or e.rank >= e.max
                Show(c.seal, done)
                c.text:SetPoint("LEFT", c, "LEFT", done and 52 or 20, 0)
                MarkSel(c, e.name == selName)
                if e.name == selName then c.box:Paint({ 0.157, 0.133, 0.078, 0.9 }, { 0.10, 0.086, 0.047, 0.9 }) else c.box:Paint({ 0.08, 0.07, 0.047, 0.6 }, { 0.04, 0.035, 0.024, 0.7 }) end
                Show(c, iy + 52 <= PB)
            end
            colH[col] = colH[col] + h + 24
        end
    end

    local function PageList(m, key)
        if key == "arsenal" then
            local l = {}
            for _, e in ipairs(m.weapons) do l[#l + 1] = e end
            for _, e in ipairs(m.untrained) do l[#l + 1] = e end
            return l
        elseif key == "oficios" then return m.crafts end
        local l = {}
        for _, gname in ipairs(m.domainOrder) do for _, e in ipairs(m.domains[gname]) do l[#l + 1] = e end end
        return l
    end

    function S:Refresh()
        local m = CollectSkillModel()
        S.model = m
        if state.page ~= "arsenal" and state.page ~= "oficios" and state.page ~= "dominios" then state.page = "arsenal" end
        local list = PageList(m, state.page)
        local sel
        for _, e in ipairs(list) do if e.name == selected.skills then sel = e end end
        sel = sel or list[1]
        local selName = sel and sel.name

        -- navegação
        local near, ready, prim = 0, 0, 0
        for _, e in ipairs(m.weapons) do if e.ratio >= 0.95 and e.rank < e.max then near = near + 1 end end
        for _, e in ipairs(m.crafts) do
            if e.primary then prim = prim + 1 end
            if SKL_TIERS[SkillTier(e.max) + 1] and e.rank >= e.max - 25 then ready = ready + 1 end
        end
        local subs = {
            format("%d em treino  ·  %d não treinadas", #m.weapons, #m.untrained),
            format("%d %s  ·  %d %s", prim, prim == 1 and "profissão" or "profissões", #m.crafts - prim, (#m.crafts - prim) == 1 and "secundária" or "secundárias"),
            format("%d %s", m.mastered, m.mastered == 1 and "perícia completa" or "perícias completas"),
        }
        local badges = { near > 0 and format("%d quase no teto", near) or nil, ready > 0 and format("%d pode treinar", ready) or nil, nil }
        for i, c in ipairs(S.nav) do
            local on = c.key == state.page
            c.em:Set(c.icon, on and 0.75 or 0.3, not on, on and 0.22 or 0)
            Color(c.title, on and SKL_GOLD2 or { 0.62, 0.69, 0.72 })
            c.sub:SetText(subs[i])
            Color(c.sub, on and { 0.81, 0.89, 0.92 } or { 0.49, 0.56, 0.60 })
            c.box:Paint(on and { 0.063, 0.172, 0.235, 0.94 } or { 0.04, 0.094, 0.133, 0.88 }, on and { 0.024, 0.07, 0.11, 0.95 } or { 0.016, 0.043, 0.067, 0.9 })
            MarkSel(c, on)
            Show(c.line, on)
            local b = badges[i]
            c.badge:Show(b ~= nil)
            Show(c.badgeText, b ~= nil)
            if b then
                c.badgeText:SetText(Azaath.Upper(b))
                local bw = (c.badgeText:GetStringWidth() or 100) + 24
                c.badge:Place(c, NV.w - bw - 16, 22, bw, 24)
                c.badge:Color(0.85, 0.71, 0.42, 0.14, 0.95, 0.84, 0.6, 0.85)
                c.badgeText:ClearAllPoints()
                c.badgeText:SetPoint("CENTER", c, "TOPLEFT", NV.w - 16 - bw / 2, -34)
            end
        end

        HideAll()
        if state.page == "arsenal" then FillArsenal(m, selName)
        elseif state.page == "oficios" then FillCrafts(m, selName)
        else FillDomains(m, selName) end
        FillDetail(sel)
    end

    --==========================================================================
    -- Animação: brasas da bigorna e o contorno do cartão selecionado pulsando
    --==========================================================================
    local T = 0
    local anim = CreateFrame("Frame", nil, page)
    anim:SetScript("OnUpdate", function(_, elapsed)
        if elapsed > 0.05 then elapsed = 0.05 end
        T = T + elapsed
        local t = T
        local flick = 0.5 + 0.5 * sin(t * 7.3) * sin(t * 3.1)
        forge:SetSize(300 + flick * 40, 150 + flick * 20)
        forge:SetAlpha(0.10 + flick * 0.08)
        for _, p in ipairs(embers) do
            p.t = p.t + elapsed
            if p.t >= p.life then SpawnEmber(p, false) end
            local q = p.t / p.life
            local x = p.x0 + p.vx * q + sin(t * 3 + p.x0) * 6
            local y = R.anvil[2] - q * p.h
            local env = min(1, q * 8) * (1 - q)
            p.tex:SetSize(p.size, p.size)
            p.tex:SetPoint("CENTER", art, "TOPLEFT", x, -y)
            p.tex:SetAlpha(p.amax * env * 0.6)
        end
        local a = 0.70 + 0.30 * (sin(t * 2.6) + 1) * 0.5
        for _, list in ipairs({ A.cards, A.un, O.cards, Dm.items }) do
            for _, c in ipairs(list) do
                if c.sel and c:IsShown() then for _, e in ipairs(c.box.edges) do e:SetAlpha(a) end end
            end
        end
    end)
end

return BuildPage
end)()

-- Perícias: página da arte de conceito; se algo falhar, volta para a lista simples.
function M.BuildSkillsTab(page, cw, ch)
    local ok, err = pcall(M.BuildSkillsPage, page)
    if not ok then
        page.skills = nil
        if Azaath.LogError then Azaath.LogError("Perícias: " .. tostring(err)) end
        ListPage(page, cw, ch, CollectSkills, SkillDetail,
            "Nenhuma perícia registrada.", "Selecione uma perícia para inspecionar seu domínio.")
    end
end
