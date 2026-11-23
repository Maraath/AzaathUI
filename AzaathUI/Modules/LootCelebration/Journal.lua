--[[----------------------------------------------------------------------------
    AzaathUI - Modules/LootCelebration/Journal.lua
    Crônicas de Saque & Pesca (/saques, /azaath saques):
      * Visual Azaath (WindowBG, Corner, Crest, painéis obsidiana e filetes ouro)
      * Alternância: Este Personagem / Todos os Personagens
      * Abas: Resumo, Diário de Pesca, Saques Obtidos (com breakdown), Rolagens
------------------------------------------------------------------------------]]

local _, Azaath = ...

local LC = Azaath.LootCel or {}
Azaath.LootCel = LC

local _G = _G
local ipairs, pairs, pcall, tostring, tonumber, type, unpack =
    ipairs, pairs, pcall, tostring, tonumber, type, unpack
local floor, max, min, format = math.floor, math.max, math.min, string.format
local CreateFrame, UIParent = CreateFrame, UIParent

local MEDIA     = Azaath.media.path
local CFG_MEDIA = MEDIA .. "ConfigUI\\"
local FONT_H    = Azaath.media.fontTitleB or "Fonts\\FRIZQT__.TTF"
local FONT_B    = Azaath.media.fontBold or "Fonts\\ARIALN.TTF"
local FONT_UI   = Azaath.media.font or "Fonts\\ARIALN.TTF"

local PAL = {
    gold   = { 0.85, 0.71, 0.42, 1 },
    pale   = { 0.96, 0.88, 0.64, 1 },
    cream  = { 0.94, 0.91, 0.84, 1 },
    dim    = { 0.62, 0.65, 0.70, 1 },
    cyan   = { 0.34, 0.88, 0.98, 1 },
    green  = { 0.28, 0.90, 0.42, 1 },
    blue   = { 0.28, 0.64, 1.00, 1 },
    purple = { 0.80, 0.42, 1.00, 1 },
    orange = { 1.00, 0.56, 0.16, 1 },
    card   = { 0.055, 0.068, 0.092, 0.92 },
    dark   = { 0.032, 0.040, 0.056, 0.95 },
}

local FLIP = {
    TOPLEFT = { 0, 1, 0, 1 }, TOPRIGHT = { 1, 0, 0, 1 },
    BOTTOMLEFT = { 0, 1, 1, 0 }, BOTTOMRIGHT = { 1, 0, 1, 0 },
}

local SLOT_ICONS = {
    Head = "INV_Helmet_22", Shoulders = "INV_Shoulder_09", Neck = "INV_Jewelry_Necklace_01",
    Chest = "INV_Chest_Cloth_17", Back = "INV_Misc_Cape_08", Wrists = "INV_Bracer_05",
    Hands = "INV_Gauntlets_05", Waist = "INV_Belt_03", Legs = "INV_Pants_12",
    Feet = "INV_Boots_03", Rings = "INV_Jewelry_Ring_01", Trinkets = "INV_Jewelry_Talisman_01",
    Shields = "INV_Shield_09", Weapons = "INV_Weapon_ShortBlade_01", Ranged = "INV_Weapon_Bow_01",
    ["Off-hand items"] = "INV_Misc_Book_09", Bags = "INV_Misc_Bag_10",
    Tabards = "INV_Shirt_GuildTabard_01", Shirts = "INV_Shirt_01",
    Materials = "INV_Misc_Gem_Emerald_02", Consumables = "INV_Potion_01",
    Recipes = "INV_Scroll_05", ["Other armor"] = "INV_Chest_Chain_04",
    ["Other items"] = "INV_Misc_QuestionMark", Unclassified = "INV_Misc_QuestionMark",
}

local state = {
    tab = "home",
    scope = "char",
    sort = "tier",
    dir = "desc",
    showUnknown = false,
    search = "",
    category = "all",
    expandedLoot = nil,
}

local root, views

--------------------------------------------------------------------------------
-- Primitivas Visuais Azaath
--------------------------------------------------------------------------------
local function FmtNum(v)
    return Azaath.Thousands(floor(tonumber(v) or 0))
end

local function AvgRoll(sum, count)
    if not count or count < 1 then return "—" end
    return format("%.1f", (sum or 0) / count)
end

local function MakeBox(parent, x, y, w, h, borderCol, fillCol)
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    f:SetSize(w, h)
    local fill = f:CreateTexture(nil, "BACKGROUND")
    fill:SetAllPoints(f)
    local fc = fillCol or PAL.card
    fill:SetColorTexture(fc[1], fc[2], fc[3], fc[4] or 0.92)
    f.fill = fill

    local bc = borderCol or PAL.gold
    local ba = borderCol and (borderCol[4] or 0.75) or 0.35
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local e = f:CreateTexture(nil, "BORDER")
        e:SetColorTexture(bc[1], bc[2], bc[3], ba)
        if side == "TOP" then e:SetPoint("TOPLEFT"); e:SetPoint("TOPRIGHT"); e:SetHeight(1)
        elseif side == "BOTTOM" then e:SetPoint("BOTTOMLEFT"); e:SetPoint("BOTTOMRIGHT"); e:SetHeight(1)
        elseif side == "LEFT" then e:SetPoint("TOPLEFT"); e:SetPoint("BOTTOMLEFT"); e:SetWidth(1)
        else e:SetPoint("TOPRIGHT"); e:SetPoint("BOTTOMRIGHT"); e:SetWidth(1) end
    end
    return f
end

local function MakeLabel(parent, txt, size, x, y, w, h, col, align, font)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or FONT_UI, size or 12, "")
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    fs:SetSize(w or 200, h or 20)
    fs:SetJustifyH(align or "LEFT")
    fs:SetJustifyV("MIDDLE")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    local c = col or PAL.cream
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    fs:SetText(txt or "")
    return fs
end

local function MakeBtn(parent, txt, x, y, w, h, onClick)
    local b = CreateFrame("Button", nil, parent)
    b:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    b:SetSize(w, h)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(b)
    bg:SetColorTexture(0.08, 0.10, 0.14, 0.95)
    local edge = b:CreateTexture(nil, "BORDER")
    edge:SetAllPoints(b)
    edge:SetColorTexture(0.79, 0.66, 0.42, 0.40)
    local inner = b:CreateTexture(nil, "ARTWORK")
    inner:SetPoint("TOPLEFT", 1, -1); inner:SetPoint("BOTTOMRIGHT", -1, 1)
    inner:SetColorTexture(0.08, 0.10, 0.14, 0.96)
    b.text = MakeLabel(b, txt, 11, 4, 0, w - 8, h, PAL.cream, "CENTER", FONT_B)

    local function Paint(self)
        if self.selected then
            edge:SetColorTexture(0.96, 0.78, 0.38, 0.95)
            inner:SetColorTexture(0.22, 0.17, 0.08, 0.96)
            self.text:SetTextColor(1, 0.90, 0.62)
        elseif self.hovered then
            edge:SetColorTexture(0.85, 0.71, 0.42, 0.80)
            inner:SetColorTexture(0.13, 0.17, 0.24, 0.96)
            self.text:SetTextColor(1, 0.95, 0.82)
        else
            edge:SetColorTexture(0.79, 0.66, 0.42, 0.38)
            inner:SetColorTexture(0.08, 0.10, 0.14, 0.96)
            self.text:SetTextColor(0.92, 0.89, 0.82)
        end
    end
    b:SetScript("OnEnter", function(self) self.hovered = true; Paint(self) end)
    b:SetScript("OnLeave", function(self) self.hovered = false; Paint(self) end)
    b:SetScript("OnClick", onClick)
    function b:SetSelected(on) self.selected = (on == true); Paint(self) end
    Paint(b)
    return b
end

--------------------------------------------------------------------------------
-- Construção da Janela Principal (/saques)
--------------------------------------------------------------------------------
local function BuildJournal()
    if root then return end
    local W, H = 900, 610
    root = CreateFrame("Frame", "AzaathUILootJournal", UIParent)
    root:SetSize(W, H)
    root:SetPoint("CENTER", UIParent, "CENTER", 0, 20)
    root:SetFrameStrata("DIALOG")
    root:EnableMouse(true)
    root:SetMovable(true)
    root:SetClampedToScreen(true)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function(self) self:StartMoving() end)
    root:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    root:Hide()
    table.insert(_G.UISpecialFrames, "AzaathUILootJournal")

    -- Fundo e moldura Azaath
    local bg = root:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetTexture(CFG_MEDIA .. "WindowBG.tga")
    bg:SetAllPoints(root)
    local border = MakeBox(root, 0, 0, W, H, PAL.gold, { 0.02, 0.025, 0.035, 0.35 })
    border:SetFrameLevel(root:GetFrameLevel())

    local deco = CreateFrame("Frame", nil, root)
    deco:SetAllPoints(root); deco:SetFrameLevel(root:GetFrameLevel() + 25)
    for point, tc in pairs(FLIP) do
        local c = deco:CreateTexture(nil, "OVERLAY")
        c:SetTexture(CFG_MEDIA .. "Corner.tga")
        c:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        c:SetSize(82, 82)
        c:SetPoint(point, root, point, 0, 0)
    end
    local crest = deco:CreateTexture(nil, "OVERLAY")
    crest:SetTexture(CFG_MEDIA .. "Crest.tga")
    crest:SetSize(280, 48)
    crest:SetPoint("CENTER", root, "TOP", 0, -2)

    -- Cabeçalho
    local head = MakeBox(root, 18, 28, W - 36, 70, PAL.gold, PAL.dark)
    local logo = head:CreateTexture(nil, "ARTWORK")
    logo:SetTexture("Interface\\Icons\\INV_Misc_Coin_02")
    logo:SetSize(42, 42); logo:SetPoint("LEFT", head, "LEFT", 14, 0)
    logo:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    views = {}
    views.title = MakeLabel(head, Azaath.Tracked(LC.L("CRÔNICAS DE SAQUE", "LOOT CHRONICLES")), 18, 68, 10, 440, 26, PAL.pale, "LEFT", FONT_H)
    views.sub   = MakeLabel(head, "", 11, 68, 38, 440, 18, PAL.dim, "LEFT", FONT_UI)

    views.btnChar = MakeBtn(head, LC.L("Este Personagem", "This Char"), 555, 22, 130, 28, function()
        state.scope = "char"; LC.RefreshJournal()
    end)
    views.btnAll = MakeBtn(head, LC.L("Todos", "All Chars"), 692, 22, 120, 28, function()
        state.scope = "all"; LC.RefreshJournal()
    end)

    local close = MakeBtn(head, "X", W - 70, 22, 26, 26, function() root:Hide() end)
    close:SetFrameLevel(head:GetFrameLevel() + 10)

    -- Navegação Superior (4 Abas)
    local tabDefs = {
        { key = "home",    pt = "Resumo",          en = "Overview" },
        { key = "fishing", pt = "Diário de Pesca", en = "Fishing Journal" },
        { key = "loot",    pt = "Saques Obtidos",  en = "Loot Obtained" },
        { key = "rolls",   pt = "Rolagens (Sorte)", en = "Roll Tracker" },
    }
    views.tabBtns, views.panels = {}, {}
    local content = CreateFrame("Frame", nil, root)
    content:SetPoint("TOPLEFT", root, "TOPLEFT", 20, -148)
    content:SetSize(W - 40, H - 168)

    for i, def in ipairs(tabDefs) do
        local b = MakeBtn(root, LC.L(def.pt, def.en), 20 + (i - 1) * 182, 108, 174, 30, function()
            state.tab = def.key; LC.RefreshJournal()
        end)
        views.tabBtns[def.key] = b
        local p = CreateFrame("Frame", nil, content)
        p:SetAllPoints(content); p:Hide()
        views.panels[def.key] = p
    end

    -- 1. RESUMO
    local home = views.panels.home
    local hero = MakeBox(home, 0, 0, 480, 426, PAL.gold, PAL.dark)
    local hGlow = hero:CreateTexture(nil, "ARTWORK")
    hGlow:SetTexture(MEDIA .. "Glow.tga"); hGlow:SetBlendMode("ADD")
    hGlow:SetPoint("TOP", hero, "TOP", 0, -16); hGlow:SetSize(240, 200)
    hGlow:SetVertexColor(0.96, 0.78, 0.38, 0.45)
    local hIcon = hero:CreateTexture(nil, "OVERLAY")
    hIcon:SetTexture("Interface\\Icons\\INV_Misc_TreasureChest_01")
    hIcon:SetPoint("TOP", hero, "TOP", 0, -54); hIcon:SetSize(84, 84)
    MakeLabel(hero, Azaath.Tracked(LC.L("CELEBRAÇÃO & REGISTRO", "CELEBRATION & TRACKER")), 16, 20, 165, 440, 28, PAL.pale, "CENTER", FONT_H)
    MakeLabel(hero, LC.L("Saques raros, Peixes Inchados, recordes de pesca,\nmarcos de ofício, raros abatidos e sorte em rolagens.",
        "Rare loot, Bloated fish, fishing records,\nprofession milestones, rare kills and roll luck."), 12, 24, 202, 432, 44, PAL.cream, "CENTER", FONT_UI)

    views.homeExtra = MakeLabel(hero, "", 12, 24, 260, 432, 28, PAL.cyan, "CENTER", FONT_B)
    MakeLabel(hero, LC.L("Prévia rápida das celebrações:", "Quick celebration previews:"), 11, 24, 306, 432, 20, PAL.dim, "CENTER")
    local tests = {
        { LC.L("Épico", "Epic"), "epic" },
        { LC.L("Lendário", "Legendary"), "legendary" },
        { LC.L("Inchado", "Bloated"), "bloated" },
        { LC.L("Jackpot", "Jackpot"), "jackpot" },
        { LC.L("Raro Abatido", "Rare Kill"), "rarekill" },
        { LC.L("Ofício 300", "Skill 300"), "skill" },
    }
    for i, t in ipairs(tests) do
        local col, row = (i - 1) % 3, floor((i - 1) / 3)
        MakeBtn(hero, t[1], 24 + col * 146, 332 + row * 38, 138, 30, function()
            local mod = Azaath:GetModule("LootCelebration")
            if mod and mod.Test then mod:Test(t[2]) end
        end)
    end

    views.homeCards = {}
    local cardSpecs = {
        { tab = "fishing", pt = "Total Pescado",      en = "Fishing Catches",   col = PAL.cyan,   icon = "Interface\\Icons\\Trade_Fishing" },
        { tab = "loot",    pt = "Saques Verificados", en = "Tracked Loot",      col = PAL.gold,   icon = "Interface\\Icons\\INV_Misc_Bag_10" },
        { tab = "rolls",   pt = "Rolagens Vencidas",  en = "Group Rolls Won",   col = PAL.purple, icon = "Interface\\Icons\\INV_Misc_Dice_01" },
    }
    for i, sp in ipairs(cardSpecs) do
        local c = MakeBox(home, 496, (i - 1) * 145, 364, 134, sp.col, PAL.dark)
        local ic = c:CreateTexture(nil, "ARTWORK")
        ic:SetTexture(sp.icon); ic:SetSize(52, 52); ic:SetPoint("LEFT", c, "LEFT", 18, 0)
        ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        MakeLabel(c, LC.L(sp.pt, sp.en), 13, 86, 20, 260, 22, PAL.pale, "LEFT", FONT_B)
        views.homeCards[i] = MakeLabel(c, "0", 28, 86, 48, 220, 44, sp.col, "LEFT", FONT_H)
        MakeLabel(c, LC.L("Clique para abrir >", "Click to open >"), 11, 86, 98, 220, 18, PAL.dim, "LEFT")
        c:EnableMouse(true)
        c:SetScript("OnMouseUp", function(_, btn)
            if btn == "LeftButton" then state.tab = sp.tab; LC.RefreshJournal() end
        end)
    end

    -- 2. DIÁRIO DE PESCA
    local fish = views.panels.fishing
    local fSum = MakeBox(fish, 0, 0, 860, 82, PAL.gold, PAL.dark)
    views.fishMetrics = {}
    local fSpecs = {
        { pt = "Total Pescado", en = "Catches", x = 20, col = PAL.cyan },
        { pt = "Espécies Únicas", en = "Unique Finds", x = 235, col = PAL.pale },
        { pt = "Maior Troféu", en = "Best Trophy", x = 450, col = PAL.gold },
        { pt = "Peixes Inchados", en = "Bloated Caught", x = 665, col = PAL.purple },
    }
    for i, m in ipairs(fSpecs) do
        views.fishMetrics[i] = MakeLabel(fSum, "0", 24, m.x, 12, 185, 36, m.col, "LEFT", FONT_H)
        MakeLabel(fSum, LC.L(m.pt, m.en), 11, m.x, 50, 185, 18, PAL.dim, "LEFT")
    end

    local fCats = {
        { key = "all",     pt = "Todos",     en = "All" },
        { key = "fish",    pt = "Peixes",    en = "Fish" },
        { key = "bloated", pt = "Inchados",  en = "Bloated" },
        { key = "trophy",  pt = "Troféus",   en = "Trophies" },
        { key = "find",    pt = "Tesouros",  en = "Treasures" },
    }
    views.fishCatBtns = {}
    for i, c in ipairs(fCats) do
        views.fishCatBtns[c.key] = MakeBtn(fish, LC.L(c.pt, c.en), (i - 1) * 102, 94, 96, 28, function()
            state.category = c.key; LC.RefreshJournal()
        end)
    end

    local searchWrap = MakeBox(fish, 515, 94, 190, 28, PAL.gold, PAL.dark)
    local searchBox = CreateFrame("EditBox", nil, searchWrap)
    searchBox:SetPoint("TOPLEFT", 8, -2); searchBox:SetPoint("BOTTOMRIGHT", -8, 2)
    searchBox:SetFont(FONT_UI, 12, ""); searchBox:SetAutoFocus(false); searchBox:SetTextColor(1, 1, 1)
    local sPh = MakeLabel(searchWrap, LC.L("Buscar peixe...", "Search..."), 11, 8, 4, 170, 20, PAL.dim)
    searchBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    searchBox:SetScript("OnTextChanged", function(self)
        state.search = self:GetText() or ""
        sPh:SetShown(state.search == "")
        LC.RefreshJournal()
    end)

    views.unknownBtn = MakeBtn(fish, "", 712, 94, 148, 28, function()
        state.showUnknown = not state.showUnknown; LC.RefreshJournal()
    end)

    local tHead = MakeBox(fish, 0, 130, 860, 26, PAL.gold, PAL.dark)
    local function SortBtn(txt, key, x, w, align)
        local b = CreateFrame("Button", nil, tHead)
        b:SetPoint("TOPLEFT", x, 0); b:SetSize(w, 26)
        b.text = MakeLabel(b, txt, 11, 8, 0, w - 16, 26, PAL.pale, align, FONT_B)
        b:SetScript("OnClick", function()
            if state.sort == key then state.dir = (state.dir == "desc") and "asc" or "desc"
            else state.sort = key; state.dir = (key == "name") and "asc" or "desc" end
            LC.RefreshJournal()
        end)
        return b
    end
    SortBtn(LC.L("PEIXE / ACHADO", "FISH / FIND"), "name", 0, 560, "LEFT")
    SortBtn(LC.L("NÍVEL", "TIER"), "tier", 560, 140, "CENTER")
    SortBtn(LC.L("PESCADOS", "CAUGHT"), "count", 700, 150, "RIGHT")

    local fListBox = MakeBox(fish, 0, 158, 860, 268, PAL.gold, PAL.dark)
    local fScroll = CreateFrame("ScrollFrame", nil, fListBox, "UIPanelScrollFrameTemplate")
    fScroll:SetPoint("TOPLEFT", 4, -4); fScroll:SetPoint("BOTTOMRIGHT", -26, 4)
    local fCanvas = CreateFrame("Frame", nil, fScroll)
    fCanvas:SetSize(826, 40)
    fScroll:SetScrollChild(fCanvas)
    views.fishCanvas, views.fishRows = fCanvas, {}

    -- 3. SAQUES OBTIDOS
    local loot = views.panels.loot
    views.lootCount = {}
    views.lootCards = {}
    local lootDefs = {
        { pt = "Incomum",  en = "Uncommon",  key = "green",     col = PAL.green,  icon = "Interface\\Icons\\INV_Chest_Leather_10" },
        { pt = "Raro",     en = "Rare",      key = "rare",      col = PAL.blue,   icon = "Interface\\Icons\\INV_Weapon_Halberd_05" },
        { pt = "Épico",    en = "Epic",      key = "epic",      col = PAL.purple, icon = "Interface\\Icons\\INV_Sword_50" },
        { pt = "Lendário", en = "Legendary", key = "legendary", col = PAL.orange, icon = "Interface\\Icons\\INV_Sword_39" },
    }
    for i, d in ipairs(lootDefs) do
        local c = MakeBox(loot, (i - 1) * 217, 0, 208, 112, d.col, PAL.dark)
        local ic = c:CreateTexture(nil, "ARTWORK")
        ic:SetTexture(d.icon); ic:SetPoint("TOPLEFT", 14, -18); ic:SetSize(44, 44)
        ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        MakeLabel(c, LC.L(d.pt, d.en), 13, 68, 12, 130, 22, d.col, "LEFT", FONT_B)
        views.lootCount[d.key] = MakeLabel(c, "0", 26, 68, 38, 130, 34, PAL.pale, "LEFT", FONT_H)
        if i < 4 then
            local btn = MakeBtn(c, LC.L("Detalhes", "Breakdown"), 14, 76, 180, 24, function()
                state.expandedLoot = (state.expandedLoot == d.key) and nil or d.key
                LC.RefreshJournal()
            end)
            views.lootCards[d.key] = btn
        else
            MakeLabel(c, LC.L("Resumo geral", "Summary only"), 10, 14, 80, 180, 20, PAL.dim, "CENTER")
        end
    end
    views.lootExtra = MakeLabel(loot, "", 12, 4, 122, 850, 22, PAL.cream, "LEFT", FONT_B)
    local bdBox = MakeBox(loot, 0, 152, 860, 274, PAL.gold, PAL.dark)
    views.bdTitle = MakeLabel(bdBox, "", 13, 16, 12, 820, 24, PAL.pale, "LEFT", FONT_B)
    views.bdRows = {}
    for i = 1, 14 do
        local col, row = (i <= 7) and 0 or 1, (i - 1) % 7
        local rx, ry = 18 + col * 425, 48 + row * 30
        local ic = bdBox:CreateTexture(nil, "ARTWORK")
        ic:SetPoint("TOPLEFT", rx, -ry); ic:SetSize(22, 22); ic:Hide()
        local nm = MakeLabel(bdBox, "", 12, rx + 30, ry, 280, 22, PAL.cream)
        local ct = MakeLabel(bdBox, "", 12, rx + 320, ry, 70, 22, PAL.pale, "RIGHT", FONT_B)
        views.bdRows[i] = { icon = ic, name = nm, count = ct }
    end

    -- 4. ROLAGENS (SORTE)
    local rolls = views.panels.rolls
    views.rollCards, views.rollCells = {}, {}
    local qRows = {
        { pt = "Incomum", en = "Uncommon", key = "green", col = PAL.green },
        { pt = "Raro",    en = "Rare",     key = "rare",  col = PAL.blue },
        { pt = "Épico",   en = "Epic",     key = "epic",  col = PAL.purple },
        { pt = "Outro",   en = "Other",    key = "other", col = PAL.cream },
    }
    for i, kind in ipairs({ "greed", "need" }) do
        local x = (i == 1) and 0 or 438
        local tint = (kind == "need") and PAL.blue or PAL.green
        local card = MakeBox(rolls, x, 0, 422, 114, tint, PAL.dark)
        MakeLabel(card, kind == "need" and LC.L("NECESSIDADE (NEED)", "NEED") or LC.L("GANÂNCIA (GREED)", "GREED"), 14, 16, 10, 220, 22, tint, "LEFT", FONT_B)
        local avg = MakeLabel(card, "—", 32, 16, 40, 120, 48, PAL.pale, "LEFT", FONT_H)
        MakeLabel(card, LC.L("Média", "Avg roll"), 11, 130, 58, 80, 20, PAL.dim)
        local cnt  = MakeLabel(card, "0 / 0", 13, 215, 36, 190, 24, PAL.cream, "RIGHT", FONT_B)
        local rate = MakeLabel(card, "—", 13, 215, 66, 190, 24, PAL.pale, "RIGHT", FONT_B)
        views.rollCards[kind] = { avg = avg, cnt = cnt, rate = rate }

        local tbl = MakeBox(rolls, x, 126, 422, 298, PAL.gold, PAL.dark)
        MakeLabel(tbl, LC.L("Qualidade", "Quality"), 11, 14, 12, 110, 20, PAL.dim)
        MakeLabel(tbl, LC.L("Rolls", "Rolls"), 11, 130, 12, 60, 20, PAL.dim, "RIGHT")
        MakeLabel(tbl, LC.L("Média", "Avg"), 11, 200, 12, 60, 20, PAL.dim, "RIGHT")
        MakeLabel(tbl, LC.L("Venc.", "Won"), 11, 270, 12, 60, 20, PAL.dim, "RIGHT")
        MakeLabel(tbl, "Win %", 11, 340, 12, 68, 20, PAL.dim, "RIGHT")
        views.rollCells[kind] = {}
        for idx, qr in ipairs(qRows) do
            local ry = 46 + (idx - 1) * 58
            MakeLabel(tbl, LC.L(qr.pt, qr.en), 13, 14, ry, 110, 26, qr.col, "LEFT", FONT_B)
            views.rollCells[kind][qr.key] = {
                count = MakeLabel(tbl, "0", 13, 130, ry, 60, 26, PAL.cream, "RIGHT"),
                avg   = MakeLabel(tbl, "—", 13, 200, ry, 60, 26, PAL.cream, "RIGHT"),
                won   = MakeLabel(tbl, "0", 13, 270, ry, 60, 26, PAL.pale, "RIGHT", FONT_B),
                pct   = MakeLabel(tbl, "—", 13, 340, ry, 68, 26, PAL.pale, "RIGHT", FONT_B),
            }
        end
    end
end

--------------------------------------------------------------------------------
-- Atualização dos Dados na Tela
--------------------------------------------------------------------------------
function LC.RefreshJournal()
    if not (root and root:IsShown() and views) then return end
    local stats = LC.GetStats and LC.GetStats(state.scope) or {}
    views.btnChar:SetSelected(state.scope == "char")
    views.btnAll:SetSelected(state.scope == "all")
    if state.scope == "char" then
        views.sub:SetText(format("%s - %s", stats.name or "", stats.realm or ""))
    else
        views.sub:SetText(LC.L("Todos os personagens salvos", "All saved characters"))
    end

    for k, b in pairs(views.tabBtns) do b:SetSelected(state.tab == k) end
    for k, p in pairs(views.panels) do p:SetShown(state.tab == k) end

    local f, l, roll = stats.fishing or {}, stats.loot or {}, stats.rolls or {}
    local totalLoot = (l.green or 0) + (l.rare or 0) + (l.epic or 0) + (l.legendary or 0) + (l.bagsOnly or 0)
    local totalWins = 0
    for _, kind in ipairs({ "need", "greed" }) do
        for _, g in pairs(roll[kind] or {}) do totalWins = totalWins + (g.won or 0) end
    end

    if state.tab == "home" then
        views.homeCards[1]:SetText(FmtNum(f.total))
        views.homeCards[2]:SetText(FmtNum(totalLoot))
        views.homeCards[3]:SetText(FmtNum(totalWins))
        views.homeExtra:SetText(format(LC.L("Inimigos Raros Abatidos: %s   ·   Companheiros: %s",
            "Rare Enemies Defeated: %s   ·   Companions: %s"),
            FmtNum(stats.rareKills or 0), FmtNum(stats.companions or 0)))
    elseif state.tab == "fishing" then
        local unique = 0
        for _, v in pairs(f.entries or {}) do
            if type(v) == "table" and (v.count or 0) > 0 then unique = unique + 1 end
        end
        local bloated = LC.GetBloatedStats and LC.GetBloatedStats(state.scope) or { total = 0 }
        local best = 0
        for _, w in pairs(f.records or {}) do if type(w) == "number" and w > best then best = w end end
        views.fishMetrics[1]:SetText(FmtNum(f.total))
        views.fishMetrics[2]:SetText(FmtNum(unique))
        views.fishMetrics[3]:SetText(best > 0 and (best .. " lb") or "—")
        views.fishMetrics[4]:SetText(FmtNum(bloated.total))
        for k, b in pairs(views.fishCatBtns) do b:SetSelected(state.category == k) end
        views.unknownBtn:SetSelected(state.showUnknown)
        views.unknownBtn.text:SetText(LC.L("Não descobertos: ", "Undiscovered: ") .. (state.showUnknown and "ON" or "OFF"))

        local rows = LC.BuildFishRows and LC.BuildFishRows(state.scope, state.sort, state.showUnknown, state.search, state.dir, state.category) or {}
        local canvas, pool = views.fishCanvas, views.fishRows
        for i, r in ipairs(rows) do
            if not pool[i] then
                local row = CreateFrame("Button", nil, canvas)
                row:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
                row:SetSize(822, 25)
                local bg = row:CreateTexture(nil, "BACKGROUND")
                bg:SetAllPoints(row)
                bg:SetColorTexture((i % 2 == 0) and 0.065 or 0.042, (i % 2 == 0) and 0.082 or 0.055, (i % 2 == 0) and 0.115 or 0.08, 0.9)
                local ic = row:CreateTexture(nil, "ARTWORK")
                ic:SetPoint("LEFT", 8, 0); ic:SetSize(20, 20); ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                local nm = MakeLabel(row, "", 12, 36, 0, 520, 25, PAL.cream)
                local tr = MakeLabel(row, "", 12, 560, 0, 130, 25, PAL.dim, "CENTER")
                local ct = MakeLabel(row, "", 12, 700, 0, 110, 25, PAL.pale, "RIGHT", FONT_B)
                row:SetScript("OnEnter", function(self)
                    if self.itemID and _G.GameTooltip then
                        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                        pcall(_G.GameTooltip.SetItemByID, _G.GameTooltip, self.itemID)
                        _G.GameTooltip:Show()
                    end
                end)
                row:SetScript("OnLeave", function() if _G.GameTooltip then _G.GameTooltip:Hide() end end)
                pool[i] = { f = row, icon = ic, name = nm, tier = tr, count = ct }
            end
            local p = pool[i]
            p.f.itemID = r.id
            p.name:SetText(r.name or "?")
            p.tier:SetText((r.tier and r.tier > 0) and tostring(floor(r.tier)) or "—")
            p.count:SetText(FmtNum(r.count or 0))
            local known = (r.count or 0) > 0
            p.name:SetTextColor(known and (r.category == "bloated" and 0.35 or 0.95) or 0.55,
                                known and (r.category == "bloated" and 0.92 or 0.92) or 0.58,
                                known and (r.category == "bloated" and 1.00 or 0.85) or 0.62, known and 1 or 0.6)
            local tex = (r.id and _G.C_Item and _G.C_Item.GetItemIconByID and _G.C_Item.GetItemIconByID(r.id)) or "Interface\\Icons\\Trade_Fishing"
            p.icon:SetTexture(tex)
            p.icon:SetAlpha(known and 1 or 0.35)
            p.f:Show()
        end
        for i = #rows + 1, #pool do pool[i].f:Hide() end
        canvas:SetHeight(max(26, #rows * 26))
    elseif state.tab == "loot" then
        for k, fs in pairs(views.lootCount) do fs:SetText(FmtNum(l[k] or 0)) end
        for k, b in pairs(views.lootCards) do b:SetSelected(state.expandedLoot == k) end
        views.lootExtra:SetText(format(LC.L("Bolsas saqueadas: %s   ·   Companheiros: %s   ·   Raros abatidos: %s",
            "Bags looted: %s   ·   Companions: %s   ·   Rare kills: %s"),
            FmtNum(l.bags or 0), FmtNum(stats.companions or 0), FmtNum(stats.rareKills or 0)))
        for _, r in ipairs(views.bdRows) do r.name:SetText(""); r.count:SetText(""); r.icon:Hide() end
        if state.expandedLoot and LC.GetLootBreakdown then
            local list = LC.GetLootBreakdown(state.scope, state.expandedLoot)
            views.bdTitle:SetText(LC.L("Detalhamento por tipo / equipamento", "Breakdown by slot / item type"))
            if #list == 0 then
                views.bdRows[1].name:SetText(LC.L("Nenhum dado detalhado ainda.", "No detailed data yet."))
            else
                for i, e in ipairs(list) do
                    if i <= #views.bdRows then
                        views.bdRows[i].name:SetText(e.name)
                        views.bdRows[i].count:SetText(FmtNum(e.count))
                        views.bdRows[i].icon:SetTexture("Interface\\Icons\\" .. (SLOT_ICONS[e.key] or "INV_Misc_QuestionMark"))
                        views.bdRows[i].icon:Show()
                    end
                end
            end
        else
            views.bdTitle:SetText(LC.L("Clique em 'Detalhes' em Incomum, Raro ou Épico para ver por slot.",
                "Click 'Breakdown' on Uncommon, Rare or Epic to inspect by slot."))
        end
    elseif state.tab == "rolls" then
        for _, kind in ipairs({ "need", "greed" }) do
            local col = roll[kind] or {}
            local count, sum, known, won = 0, 0, 0, 0
            for key, cells in pairs(views.rollCells[kind]) do
                local g = col[key] or {}
                local n, w = g.count or 0, g.won or 0
                count = count + n; won = won + w
                sum = sum + (g.sum or 0); known = known + (g.known or 0)
                cells.count:SetText(FmtNum(n))
                cells.avg:SetText(AvgRoll(g.sum, g.known))
                cells.won:SetText(FmtNum(w))
                cells.pct:SetText(n > 0 and format("%.1f%%", 100 * w / n) or "—")
            end
            local card = views.rollCards[kind]
            card.avg:SetText(AvgRoll(sum, known))
            card.cnt:SetText(format("%s %s / %s %s", FmtNum(count), LC.L("rolls", "rolls"), FmtNum(won), LC.L("vitórias", "wins")))
            card.rate:SetText(count > 0 and format("%.1f%% %s", 100 * won / count, LC.L("de vitória", "win rate")) or "—")
        end
    end
end

function LC.ToggleJournal(forceOpen)
    BuildJournal()
    if root:IsShown() and not forceOpen then
        root:Hide()
    else
        root:Show()
        LC.RefreshJournal()
    end
end

_G.SLASH_AZAATHSAQUES1 = "/saques"
_G.SlashCmdList["AZAATHSAQUES"] = function()
    LC.ToggleJournal()
end
