--[[----------------------------------------------------------------------------
    AzaathUI - Modules/SheetDrops.lua
    Quinta aba do Santuário ("Drops"): O Relicário de Azaath
      * Interface 1920x1080 escalonada usando as molduras, filigranas douradas,
        aros de metal escuro (SlotBezel / SlotRimLine), feixes luminosos
        (ClassicGlassH), gemas de CraftRings e ícones de SkillsIcons.
      * Todos os filtros originais (Busca, Todo o Mundo / Zona Atual, Origens,
        Categorias, Nível e Raridade) + Filtro em cascata por Tipo de Peça
        (ex.: Placa > Capacete).
      * Catálogo expansível: por padrão o Provador 3D fica oculto e o catálogo
        ocupa todo o centro (3 colunas x 4 linhas = 12 cartas). Ao clicar em
        "PROVADOR 3D", o catálogo retrai (2 colunas x 4 linhas = 8 cartas) e
        exibe o modelo 3D no pedestal entre o catálogo e o códice.
      * Motor de animação suave em OnUpdate para hover de cartas, mini-cards
        de categorias, pílulas de filtro, fontes e botões de ação.
------------------------------------------------------------------------------]]

local ADDON_NAME, Azaath = ...
local M = Azaath:NewModule("SheetDrops")

local _G = _G
local ipairs, pairs, pcall, tonumber, tostring = ipairs, pairs, pcall, tonumber, tostring
local min, max, floor, ceil, abs, format = math.min, math.max, math.floor, math.ceil, math.abs, string.format

local ART_W, ART_H = 1920, 1080
local MEDIA_ROOT   = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local SHEET_MEDIA  = MEDIA_ROOT .. "Sheet\\"
local INV_MEDIA    = MEDIA_ROOT .. "Inventory\\"
local UF_MEDIA     = MEDIA_ROOT .. "UnitFrames\\"

local C = {
    CYAN    = { 0.38, 0.90, 0.98 },
    AZAATH   = { 0.30, 0.85, 1.00 },
    GOLD    = { 0.94, 0.78, 0.38 },
    GOLD_HI = { 1.00, 0.88, 0.56 },
    CREAM   = { 0.95, 0.93, 0.85 },
    TEXT_HI = { 0.82, 0.89, 0.94 },
    MUTED   = { 0.68, 0.76, 0.82 },
    DIM     = { 0.50, 0.58, 0.64 },
    GREEN   = { 0.32, 0.92, 0.48 },
}

local QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 0.95, 0.95, 0.95 },
    [2] = { 0.18, 0.96, 0.34 },
    [3] = { 0.22, 0.66, 1.00 },
    [4] = { 0.78, 0.44, 1.00 },
    [5] = { 1.00, 0.58, 0.12 },
}

local QUALITY_NAMES = {
    [0] = "Comum",
    [1] = "Comum",
    [2] = "Incomum",
    [3] = "Raro",
    [4] = "Épico",
    [5] = "Lendário",
}

local ORIGIN_FILTERS = {
    { key = 0, text = "Todas Origens" },
    { key = 1, text = "Mundo Aberto" },
    { key = 2, text = "Masmorra/Raide" },
    { key = 4, text = "Craftável" },
    { key = 8, text = "Quests" },
}

local LEVEL_FILTERS = {
    { key = "all",   text = "Nv: Todos" },
    { key = "1-20",  text = "1–20" },
    { key = "21-40", text = "21–40" },
    { key = "41-59", text = "41–59" },
    { key = "60",    text = "60" },
}

local QUALITY_FILTERS = {
    { q = 0, text = "Todas",    gem = "GemTrivial", col = { 0.78, 0.84, 0.88 } },
    { q = 2, text = "Incomum+", gem = "GemEasy",    col = { 0.28, 0.94, 0.44 } },
    { q = 3, text = "Raro+",    gem = "GemTrivial", col = { 0.28, 0.68, 1.00 }, tint = { 0.25, 0.68, 1.00 } },
    { q = 4, text = "Épico",    gem = "GemTrivial", col = { 0.80, 0.48, 1.00 }, tint = { 0.80, 0.42, 1.00 } },
}

-- Atlas de CraftFrames / CraftRings (idêntico a Professions.lua)
local ATLAS = {
    CardN      = { file = "CraftFrames", x = 290, y = 1,   w = 286, h = 366, pad = 10, m = { 40, 40, 40, 40 } },
    CardA      = { file = "CraftFrames", x = 1,   y = 1,   w = 287, h = 367, pad = 10, m = { 40, 40, 40, 40 } },
    CardAFlare = { file = "CraftFrames", x = 893, y = 1,   w = 123, h = 101, add = true, cy = 40 },
    WideN      = { file = "CraftFrames", x = 578, y = 1,   w = 312, h = 121, pad = 10, m = { 30, 26, 30, 26 } },
    WideA      = { file = "CraftFrames", x = 578, y = 124, w = 313, h = 121, pad = 10, m = { 30, 26, 30, 26 } },
    WideAFlare = { file = "CraftFrames", x = 1,   y = 370, w = 115, h = 83,  add = true, cy = 39 },
    Search     = { file = "CraftFrames", x = 533, y = 469, w = 432, h = 87,  pad = 6,  m = { 38, 0, 38, 0 } },
    PillN      = { file = "CraftFrames", x = 187, y = 470, w = 180, h = 54,  pad = 5,  m = { 22, 0, 22, 0 } },
    PillA      = { file = "CraftFrames", x = 1,   y = 455, w = 184, h = 60,  pad = 7,  m = { 24, 0, 24, 0 } },
    BtnGold    = { file = "CraftFrames", x = 578, y = 247, w = 301, h = 118, pad = 10, m = { 56, 0, 56, 0 } },
    BtnDark    = { file = "CraftFrames",   x = 578, y = 367, w = 240, h = 100, pad = 4,  m = { 24, 24, 24, 24 } },
    BtnSquare  = { file = "CraftFrames",   x = 893, y = 104, w = 100, h = 100, pad = 4,  m = { 24, 24, 24, 24 } },
    DropPanel  = { file = "DropAtlasOuro", x = 10,  y = 10,  w = 595, h = 205, pad = 4,  m = { 64, 44, 64, 44 } },
    DropWide   = { file = "DropAtlasOuro", x = 10,  y = 235, w = 595, h = 233, pad = 4,  m = { 62, 46, 62, 46 } },
    DropSquare = { file = "DropAtlasOuro", x = 10,  y = 490, w = 251, h = 251, pad = 4,  m = { 38, 38, 38, 38 } },
    DropBtn    = { file = "DropAtlasOuro", x = 285, y = 490, w = 305, h = 87,  pad = 4,  m = { 82, 0,  82, 0  } },
    Diamond    = { file = "CraftFrames", x = 995, y = 104, w = 25,  h = 26 },
    RingBronze = { file = "CraftRings",  x = 643, y = 1,   w = 350, h = 351 },
    RingDark   = { file = "CraftRings",  x = 643, y = 354, w = 280, h = 279 },
    RingSmall  = { file = "CraftRings",  x = 643, y = 635, w = 127, h = 130 },
    StarGold   = { file = "CraftRings",  x = 925, y = 354, w = 95,  h = 94 },
    GemEasy    = { file = "CraftRings",  x = 61,  y = 643, w = 57,  h = 67 },
    GemTrivial = { file = "CraftRings",  x = 831, y = 635, w = 56,  h = 68 },
}

-- Ordem das células em SkillsIcons.tga (8 por linha, 128 px)
local SKL_ICON = {}
for i, k in ipairs({
    "sword", "great", "dagger", "axe", "axe2", "mace", "mace2", "bow",
    "gun", "thrown", "fist", "shield", "spear", "staff", "crossbow", "wand",
    "claw", "pick", "pan", "hook", "cross", "flask", "hammer", "leaf",
    "needle", "gear", "crystal", "hide", "key", "horseshoe", "book", "armor", "star",
}) do
    SKL_ICON[k] = i - 1
end

local MAX_CARDS = 12 -- 3 cols x 4 rows (expandido) ou 2 cols x 4 rows (com Provador 3D)
local TREE_W, TREE_ROW_H, TREE_ROWS = 290, 30, 25 -- árvore de categorias (Azaath.ItemCats)
local MAX_SRCS  = 3  -- cartões de fonte visíveis por página no Códice (com rolagem)

local U = {
    offset      = 0,
    srcOffset   = 0,
    query       = "",
    zoneOnly    = false,
    armor       = "all",
    slot        = "all",
    cat         = "all",   -- ramo escolhido na árvore de categorias
    expanded    = {},      -- ramos abertos
    treeOff     = 0,
    counts      = {},      -- itens por ramo, com os outros filtros aplicados
    origin      = 0,
    level       = "all",
    minQuality  = 0,
    selectedID  = nil,
    showTryOn   = false,
    onlyPiece   = false,
    modelFacing = 0,
    lastList    = {},
    lastTotal   = 0,
    cards       = {},
    srcs        = {},
    btns        = {},
    fonts       = {},
    animWidgets = {},
}

local H = {}
local scanTip
local requestedIDs = {}

--------------------------------------------------------------------------------
-- Utilitários de Dados, Áudio & Interpolação
--------------------------------------------------------------------------------
local function Safe(fn, ...)
    if not fn then return end
    local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, ...)
    if ok then return a, b, c, d, e, f, g, h, i, j end
end

local function Damp(a, b, k, dt)
    return a + (b - a) * (1 - k ^ dt)
end

local function PlayClick()
    if Azaath.PlaySound then Safe(Azaath.PlaySound, "igMainMenuOptionCheckBoxOn") end
end

local function RegHover(w, kind)
    w.hoverKind = kind
    w.hoverT = 0
    w.isHovered = false
    w.forceAnimDirty = true
    U.animWidgets[#U.animWidgets + 1] = w
    return w
end

local function GetItemMeta(itemID, fallbackQuality)
    local name, link, quality, iLevel, reqLevel, itemType, itemSubType, _, equipLoc, icon
    if _G.C_Item and _G.C_Item.GetItemInfo then
        name, link, quality, iLevel, reqLevel, itemType, itemSubType, _, equipLoc, icon = Safe(_G.C_Item.GetItemInfo, itemID)
    elseif _G.GetItemInfo then
        name, link, quality, iLevel, reqLevel, itemType, itemSubType, _, equipLoc, icon = Safe(_G.GetItemInfo, itemID)
    end
    if not icon then
        if _G.C_Item and _G.C_Item.GetItemIconByID then
            icon = Safe(_G.C_Item.GetItemIconByID, itemID)
        elseif _G.GetItemIcon then
            icon = Safe(_G.GetItemIcon, itemID)
        end
    end
    if not name and not requestedIDs[itemID] and _G.C_Item and _G.C_Item.RequestLoadItemDataByID then
        requestedIDs[itemID] = true
        Safe(_G.C_Item.RequestLoadItemDataByID, itemID)
    end
    return {
        name     = name,
        link     = link,
        quality  = quality or fallbackQuality or 1,
        iLevel   = iLevel,
        reqLevel = reqLevel,
        type     = itemType,
        subType  = itemSubType,
        slot     = equipLoc and _G[equipLoc] or nil,
        equipLoc = equipLoc,
        icon     = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
    }
end

-- Shift+clique: põe o link do item no chat. Sem item em cache monta o link
-- pelo ID; com a caixa do chat fechada, abre a caixa já com o link.
local function LinkItemToChat(entry)
    if not entry or not entry.id then return end
    local meta = GetItemMeta(entry.id, entry.quality)
    local link = meta.link
    if not link then
        local q = QUALITY_COLORS[meta.quality] or QUALITY_COLORS[1]
        local hex = q and format("%02x%02x%02x", floor(q[1] * 255), floor(q[2] * 255), floor(q[3] * 255)) or "ffffff"
        link = format("|cff%s|Hitem:%d::::::::|h[%s]|h|r", hex, entry.id, meta.name or entry.name or ("item " .. entry.id))
    end
    local active = _G.ChatEdit_GetActiveWindow and _G.ChatEdit_GetActiveWindow()
    if active and _G.ChatEdit_InsertLink and _G.ChatEdit_InsertLink(link) then return end
    if _G.ChatFrame_OpenChat then
        _G.ChatFrame_OpenChat(link)
    elseif _G.ChatFrameUtil and _G.ChatFrameUtil.OpenChat then
        _G.ChatFrameUtil.OpenChat(link)
    elseif _G.ChatEdit_InsertLink then
        _G.ChatEdit_InsertLink(link)
    end
end

-- Nome do item no idioma do Azaath: o nome do próprio cliente quando o cliente está nesse idioma
-- (sempre o mais atual); senão o do banco (pt-BR ou inglês, escolhido pelo ItemDrops).
local function ItemName(entry, meta)
    local idr = Azaath:GetModule("ItemDrops")
    local pt = idr and idr.IsPt and idr.IsPt()
    local loc = GetLocale and GetLocale() or ""
    if meta and meta.name and ((pt and loc == "ptBR") or (not pt and loc == "enUS")) then return meta.name end
    if entry and idr and idr.DisplayName then return idr:DisplayName(entry) end
    return (entry and entry.name) or (meta and meta.name) or ""
end

local function ScanItemStats(itemID)
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "AzaathUIDropsScanTip", nil, "GameTooltipTemplate")
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    end
    scanTip:ClearLines()
    if scanTip.SetItemByID then
        Safe(scanTip.SetItemByID, scanTip, itemID)
    else
        Safe(scanTip.SetHyperlink, scanTip, "item:" .. itemID)
    end
    local lines = {}
    local n = scanTip:NumLines() or 0
    for i = 2, min(n, 10) do
        local fs = _G["AzaathUIDropsScanTipTextLeft" .. i]
        local txt = fs and fs:GetText()
        if txt and txt ~= "" then
            local r, g, b = fs:GetTextColor()
            lines[#lines + 1] = { text = txt, r = r or 0.9, g = g or 0.9, b = b or 0.9 }
        end
    end
    return lines
end

-- fonte sem posição: nome da masmorra/raide (zona do AreaTable, traduzida pelo cliente) quando conhecido
local function SourcePlace(src)
    if src.area and _G.C_Map and _G.C_Map.GetAreaInfo then
        local name = Safe(_G.C_Map.GetAreaInfo, src.area)
        if type(name) == "string" and name ~= "" then return "Masmorra / Raide  ·  " .. name end
    end
    return "Masmorra / Raide"
end

local function MapName(mapID)
    if not mapID or mapID == 0 then return "Masmorra / Raide" end
    if _G.C_Map and _G.C_Map.GetMapInfo then
        local info = Safe(_G.C_Map.GetMapInfo, mapID)
        if info and info.name then return info.name end
    end
    return "Mapa " .. mapID
end

local STAT_NAMES = {
    armor = "Armadura", str = "Força", agi = "Agilidade", sta = "Vigor",
    int = "Intelecto", spi = "Espírito", ap = "Poder de Ataque", rap = "Atq. Distância",
    sp = "Poder Mágico", heal = "Cura", crit = "% Crítico", scrit = "% Crít. Mágico",
    hit = "% Acerto", shit = "% Ac. Mágico", dodge = "% Esquiva", parry = "% Aparo",
    block = "% Bloqueio", def = "Defesa", mpr = "Mana/5s", hpr = "Vida/5s",
}

local function FormatFallbackStats(statsStr, inline)
    if not statsStr or statsStr == "" then return nil end
    local out = {}
    local dmin, dmax, spd
    for tok in statsStr:gmatch("%S+") do
        local k, v = tok:match("^([a-z]+)(%d+)$")
        if k == "dmin" then dmin = tonumber(v)
        elseif k == "dmax" then dmax = tonumber(v)
        elseif k == "speed" then spd = tonumber(v)
        elseif k == "armor" then
            out[#out + 1] = inline and (v .. " Armadura") or ("|cffffffff" .. v .. " de Armadura|r")
        elseif k and STAT_NAMES[k] then
            local txt = "+" .. v .. " " .. STAT_NAMES[k]
            out[#out + 1] = inline and txt or ("|cff32e66a" .. txt .. "|r")
        end
    end
    if dmin and dmax then
        local sStr = spd and format(" (Vel. %.2fs)", spd / 1000) or ""
        local dmg = (inline and "" or "|cffffffff") .. "Dano: " .. dmin .. "–" .. dmax .. sStr .. (inline and "" or "|r")
        table.insert(out, 1, dmg)
    end
    if #out == 0 then return nil end
    return table.concat(out, inline and " · " or "\n")
end

local INV_TO_SLOT = {
    [1] = 1, [2] = 2, [3] = 3, [5] = 5, [20] = 5, [6] = 6, [7] = 7, [8] = 8,
    [9] = 9, [10] = 10, [11] = 11, [12] = 13, [14] = 17, [16] = 15,
    [13] = 16, [17] = 16, [21] = 16, [22] = 17, [23] = 17, [15] = 18, [25] = 18, [26] = 18,
}

local function GetEquippedInSlot(entry)
    local slotID = entry and INV_TO_SLOT[entry.invType or 0]
    if not slotID or not _G.GetInventoryItemLink then return nil end
    local link = Safe(_G.GetInventoryItemLink, "player", slotID)
    if not link then return nil, slotID end
    local eqName, _, _, eqIlvl = Safe((_G.C_Item and _G.C_Item.GetItemInfo) or _G.GetItemInfo, link)
    return { link = link, name = eqName, iLvl = eqIlvl or 0 }, slotID
end

local function IsEquippable(entry)
    if not entry then return false end
    return (entry.classID == 2 or entry.classID == 4) and (entry.invType or 0) > 0
end

local function ShowItemTooltip(owner, entry)
    if not entry then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    local meta = GetItemMeta(entry.id, entry.quality)
    if meta.link then
        Safe(GameTooltip.SetHyperlink, GameTooltip, meta.link)
    else
        local qc = QUALITY_COLORS[meta.quality] or QUALITY_COLORS[1]
        GameTooltip:AddLine(ItemName(entry, meta), qc[1], qc[2], qc[3])
        if (entry.iLvl or 0) > 0 or (entry.reqLevel or 0) > 0 then
            GameTooltip:AddLine(format("iLvl %d · Req. Nível %d", entry.iLvl or 0, entry.reqLevel or 0), 0.94, 0.78, 0.38)
        end
        local fb = FormatFallbackStats(entry.stats, false)
        if fb then
            for line in fb:gmatch("[^\n]+") do
                GameTooltip:AddLine(line, 1, 1, 1, true)
            end
        end
        for k, s in ipairs(entry.list or {}) do
            if k > 3 then break end
            local ch = s.vendor and "Loja" or (s.chance and s.chance > 0 and format("%.1f%%", s.chance) or "?")
            GameTooltip:AddLine(format("%s (%s)", s.name, ch), 0.68, 0.74, 0.80)
        end
    end
    GameTooltip:Show()
end

--------------------------------------------------------------------------------
-- Helpers Visuais Azaath (9-Slice Esculpido, Medalhões SlotBezel & Pílulas)
--------------------------------------------------------------------------------
function H.Txt(parent, font, size, col, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or U.fonts.B, size or 12, "")
    fs:SetShadowOffset(1.5, -1.5)
    fs:SetShadowColor(0, 0, 0, 0.94)
    fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

function H.AtlasTex(tex, key)
    local a = ATLAS[key]
    if not a then return end
    tex:SetTexture(SHEET_MEDIA .. a.file)
    tex:SetTexCoord(a.x / 1024, (a.x + a.w) / 1024, a.y / 1024, (a.y + a.h) / 1024)
    tex:SetBlendMode(a.add and "ADD" or "BLEND")
end

function H.SkillIconTex(tex, key, padPx)
    local idx = SKL_ICON[key] or SKL_ICON.star
    local u = (idx % 8) * 128 / 1024
    local v = floor(idx / 8) * 128 / 1024
    local p = (padPx or 2) / 1024
    tex:SetTexture(SHEET_MEDIA .. "SkillsIcons")
    tex:SetTexCoord(u + p, u + 128 / 1024 - p, v + p, v + 128 / 1024 - p)
end

function H.DropCatIconTex(tex, idx)
    local i = (idx or 1) - 1
    local col = i % 4
    local row = floor(i / 4)
    local p = 2 / 512
    tex:SetTexture(SHEET_MEDIA .. "DropCategoryIcons")
    tex:SetTexCoord(col * 0.25 + p, (col + 1) * 0.25 - p, row * 0.25 + p, (row + 1) * 0.25 - p)
end

local SKIN_DIAMONDS = { CardN = true, WideN = true }
function H.Skin(f, key, s, layer, sub)
    local L, SL = layer or "BACKGROUND", sub or 1
    local sk = { f = f, s = s or 1, t = {}, centerAlpha = 1 }
    for i = 1, 9 do sk.t[i] = f:CreateTexture(nil, L, nil, SL) end
    sk.dTop = f:CreateTexture(nil, "BORDER", nil, SL + 1)
    sk.dBot = f:CreateTexture(nil, "BORDER", nil, SL + 1)
    sk.flare = f:CreateTexture(nil, "OVERLAY", nil, 3)
    H.AtlasTex(sk.dTop, "Diamond"); H.AtlasTex(sk.dBot, "Diamond")

    function sk:Apply(k, noDiamonds, noFlare)
        if self.key == k and self.noDiamonds == noDiamonds and self.noFlare == noFlare then return end
        self.key, self.noDiamonds, self.noFlare = k, noDiamonds, noFlare
        local a = ATLAS[k]
        if not a then return end
        local sc, t, F = self.s, self.t, self.f
        local pad = a.pad * sc
        local ml, mt, mr, mb = a.m[1] + a.pad, a.m[2] + a.pad, a.m[3] + a.pad, a.m[4] + a.pad
        local file = SHEET_MEDIA .. a.file
        local u = { a.x, a.x + ml, a.x + a.w - mr, a.x + a.w }
        local v = { a.y, a.y + mt, a.y + a.h - mb, a.y + a.h }
        for i = 1, 9 do
            local cx, cy = (i - 1) % 3 + 1, floor((i - 1) / 3) + 1
            t[i]:SetTexture(file)
            t[i]:SetTexCoord(u[cx] / 1024, u[cx + 1] / 1024, v[cy] / 1024, v[cy + 1] / 1024)
            t[i]:ClearAllPoints()
        end
        local dl, dt, dr, db = ml * sc, mt * sc, mr * sc, mb * sc
        t[1]:SetPoint("TOPLEFT", F, "TOPLEFT", -pad, pad); t[1]:SetSize(dl, dt)
        t[3]:SetPoint("TOPRIGHT", F, "TOPRIGHT", pad, pad); t[3]:SetSize(dr, dt)
        t[7]:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", -pad, -pad); t[7]:SetSize(dl, db)
        t[9]:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", pad, -pad); t[9]:SetSize(dr, db)
        t[2]:SetPoint("TOPLEFT", t[1], "TOPRIGHT"); t[2]:SetPoint("BOTTOMRIGHT", t[3], "BOTTOMLEFT")
        t[8]:SetPoint("TOPLEFT", t[7], "TOPRIGHT"); t[8]:SetPoint("BOTTOMRIGHT", t[9], "BOTTOMLEFT")
        t[4]:SetPoint("TOPLEFT", t[1], "BOTTOMLEFT"); t[4]:SetPoint("BOTTOMRIGHT", t[7], "TOPRIGHT")
        t[6]:SetPoint("TOPLEFT", t[3], "BOTTOMLEFT"); t[6]:SetPoint("BOTTOMRIGHT", t[9], "TOPRIGHT")
        t[5]:SetPoint("TOPLEFT", t[1], "BOTTOMRIGHT"); t[5]:SetPoint("BOTTOMRIGHT", t[9], "TOPLEFT")
        if self.alpha then
            for i = 1, 9 do t[i]:SetAlpha(i == 5 and (self.alpha * self.centerAlpha) or self.alpha) end
        elseif self.centerAlpha < 1 then
            t[5]:SetAlpha(self.centerAlpha)
        end

        local dia = (not noDiamonds) and SKIN_DIAMONDS[k] and ATLAS.Diamond
        self.dTop:SetShown(dia and true or false)
        self.dBot:SetShown(dia and true or false)
        if dia then
            local ds = max(0.55, sc)
            self.dTop:SetSize(dia.w * ds, dia.h * ds); self.dTop:ClearAllPoints(); self.dTop:SetPoint("CENTER", F, "TOP", 0, 0)
            self.dBot:SetSize(dia.w * ds, dia.h * ds); self.dBot:ClearAllPoints(); self.dBot:SetPoint("CENTER", F, "BOTTOM", 0, 0)
        end
        local fl = (not noFlare) and ATLAS[k .. "Flare"]
        self.flare:SetShown(fl and true or false)
        if fl then
            H.AtlasTex(self.flare, k .. "Flare")
            local fs = max(0.60, sc)
            self.flare:SetSize(fl.w * fs, fl.h * fs)
            self.flare:ClearAllPoints()
            self.flare:SetPoint("CENTER", F, "TOP", 0, -(fl.h / 2 - fl.cy) * fs)
        end
    end

    function sk:SetCenterAlpha(ca)
        self.centerAlpha = ca
        local baseA = self.alpha or 1
        self.t[5]:SetAlpha(baseA * ca)
    end

    function sk:SetAlpha(al)
        self.alpha = al
        for i = 1, 9 do
            self.t[i]:SetAlpha(i == 5 and (al * self.centerAlpha) or al)
        end
        if self.dTop:IsShown() then self.dTop:SetAlpha(al); self.dBot:SetAlpha(al) end
        if self.flare:IsShown() then self.flare:SetAlpha(al) end
    end

    function sk:SetColor(r, g, b, a)
        for i = 1, 9 do self.t[i]:SetVertexColor(r, g, b, a or 1) end
    end

    sk:Apply(key)
    return sk
end

function H.CircleIcon(parent, size, frameSize, ringMode, withAura)
    local fs = frameSize or size
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(fs, fs)
    holder.baseIconSize = size

    if withAura then
        holder.aura = holder:CreateTexture(nil, "BACKGROUND", nil, -1)
        holder.aura:SetTexture(SHEET_MEDIA .. "SlotAura")
        holder.aura:SetBlendMode("ADD")
        holder.aura:SetSize(fs * 1.65, fs * 1.65)
        holder.aura:SetPoint("CENTER")
        holder.aura:Hide()

        holder.wisps = holder:CreateTexture(nil, "BACKGROUND", nil, 0)
        holder.wisps:SetTexture(SHEET_MEDIA .. "SlotAuraWisps")
        holder.wisps:SetBlendMode("ADD")
        holder.wisps:SetSize(fs * 1.55, fs * 1.55)
        holder.wisps:SetPoint("CENTER")
        holder.wisps:Hide()
    end

    local sphere = holder:CreateTexture(nil, "BACKGROUND", nil, 1)
    sphere:SetTexture(INV_MEDIA .. "SlotRound")
    sphere:SetSize(size + 2, size + 2)
    sphere:SetPoint("CENTER")
    sphere:SetVertexColor(0.24, 0.30, 0.38, 1)

    local icon = holder:CreateTexture(nil, "ARTWORK", nil, 0)
    icon:SetSize(size, size)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = holder:CreateMaskTexture()
    local ok = pcall(mask.SetTexture, mask, INV_MEDIA .. "RoundMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if not ok then mask:SetTexture(INV_MEDIA .. "RoundMask") end
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)

    local vig = holder:CreateTexture(nil, "ARTWORK", nil, 1)
    vig:SetTexture(SHEET_MEDIA .. "SlotVignette")
    vig:SetAllPoints(icon)

    if ringMode == "bezel" then
        local bezelSz = floor(size * 1.26)
        holder.rim = holder:CreateTexture(nil, "OVERLAY", nil, 1)
        holder.rim:SetTexture(SHEET_MEDIA .. "SlotRimLine")
        holder.rim:SetBlendMode("ADD")
        holder.rim:SetSize(bezelSz, bezelSz)
        holder.rim:SetPoint("CENTER")
        holder.rim:SetVertexColor(0.45, 0.72, 0.92, 0.65)
        holder.baseRimSize = bezelSz

        local ring = holder:CreateTexture(nil, "OVERLAY", nil, 0)
        ring:SetTexture(SHEET_MEDIA .. "SlotBezel")
        ring:SetSize(bezelSz, bezelSz)
        ring:SetPoint("CENTER")
        holder.ring = ring
    else
        holder.rim = holder:CreateTexture(nil, "OVERLAY", nil, 0)
        holder.rim:SetTexture(MEDIA_ROOT .. "CastRingThin")
        holder.rim:SetSize(size + 8, size + 8)
        holder.rim:SetPoint("CENTER")
        holder.baseRimSize = size + 8
        holder.rim:Hide()

        local ring = holder:CreateTexture(nil, "OVERLAY", nil, 1)
        if ringMode then H.AtlasTex(ring, ringMode) else ring:SetTexture(SHEET_MEDIA .. "RoundSlotFrame") end
        ring:SetAllPoints(holder)
        holder.ring = ring
    end

    holder.icon = icon
    return holder
end

function H.Pill(parent, w, h, text, size, col, skinKey, scale, hoverKind)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, h)
    b.baseCol = col or C.TEXT_HI

    b.skin = H.Skin(b, skinKey or "PillN", scale or (h / 44), "BACKGROUND", 1)
    if not skinKey or skinKey == "PillN" then
        b.skin:SetColor(0.70, 0.88, 1.0, 0.95)
    end

    b.hoverAura = b:CreateTexture(nil, "BORDER", nil, 1)
    b.hoverAura:SetTexture(UF_MEDIA .. "ClassicGlassH")
    b.hoverAura:SetBlendMode("ADD")
    b.hoverAura:SetPoint("TOPLEFT", 6, -3)
    b.hoverAura:SetPoint("BOTTOMRIGHT", -6, 3)
    b.hoverAura:SetVertexColor(0.35, 0.88, 1.0, 1)
    b.hoverAura:SetAlpha(0)

    b.bottomBeam = b:CreateTexture(nil, "OVERLAY", nil, 1)
    b.bottomBeam:SetTexture(UF_MEDIA .. "ClassicGlassH")
    b.bottomBeam:SetBlendMode("ADD")
    b.bottomBeam:SetHeight(2)
    b.bottomBeam:SetWidth(max(12, w * 0.25))
    b.bottomBeam:SetPoint("CENTER", b, "BOTTOM", 0, 1)
    b.bottomBeam:SetVertexColor(0.50, 0.95, 1.0, 1)
    b.bottomBeam:SetAlpha(0)

    b.star = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.star:SetTexture(MEDIA_ROOT .. "Star")
    b.star:SetBlendMode("ADD")
    b.star:SetSize(12, 12)
    b.star:SetPoint("CENTER", b.bottomBeam, "CENTER", 0, 0)
    b.star:SetVertexColor(0.65, 0.96, 1.0, 1)
    b.star:SetAlpha(0)

    b.label = H.Txt(b, U.fonts.B, size or 12, b.baseCol, "CENTER")
    b.label:SetPoint("CENTER", 0, 0)
    b.label:SetText(text or "")

    function b:SetSkin(k, nd, nf)
        self.skin:Apply(k, nd, nf)
        if k == "PillN" then
            self.skin:SetColor(0.70, 0.88, 1.0, 0.95)
        else
            self.skin:SetColor(1, 1, 1, 1)
        end
    end

    function b:SetActiveState(on, tint)
        self.isActive = on and true or false
        self.accent = tint
        self:SetSkin(self.isActive and "PillA" or "PillN")
        if not self.isActive and tint then
            self.skin:SetColor(0.55 + 0.45 * tint[1], 0.55 + 0.45 * tint[2], 0.55 + 0.45 * tint[3], 0.95)
        end
        local bc = tint or C.CYAN
        self.hoverAura:SetVertexColor(bc[1], bc[2], bc[3], 1)
        self.hoverAura:SetAlpha(self.isActive and 0.22 or 0)
        self.bottomBeam:SetVertexColor(bc[1], bc[2], bc[3], 1)
        self.bottomBeam:SetAlpha(self.isActive and 0.85 or 0)
        self.star:SetVertexColor(min(1, bc[1] + 0.25), min(1, bc[2] + 0.25), min(1, bc[3] + 0.25), 1)
        self.star:SetAlpha(0)
        self.forceAnimDirty = true
    end

    RegHover(b, hoverKind or "pill")
    b:SetScript("OnEnter", function(self) self.isHovered = true end)
    b:SetScript("OnLeave", function(self) self.isHovered = false end)
    return b
end

--------------------------------------------------------------------------------
-- Atualização do Provador 3D & Códice da Relíquia
--------------------------------------------------------------------------------
local function UpdateTryOn(entry, meta)
    local st = U.tryOnStage
    if not st then return end
    if not (U.showTryOn and entry) then return end

    local qc = QUALITY_COLORS[(meta and meta.quality) or entry.quality] or QUALITY_COLORS[1]
    st.itemSub:SetText(ItemName(entry, meta))
    st.itemSub:SetTextColor(qc[1], qc[2], qc[3])
    st.aura:SetVertexColor(qc[1], qc[2], qc[3], 0.30)

    local eq = GetEquippedInSlot(entry)
    if eq and eq.name then
        st.cmpText:SetText("Equipado no slot: " .. eq.name .. ((eq.iLvl and eq.iLvl > 0) and (" (iLvl " .. eq.iLvl .. ")") or ""))
    elseif IsEquippable(entry) then
        st.cmpText:SetText("Equipado no slot: Nenhum item equipado")
    else
        st.cmpText:SetText("Item não equipável no modelo 3D")
    end

    st.onlyBtn:SetActiveState(U.onlyPiece, C.CYAN)
    st.onlyBtn.label:SetTextColor(U.onlyPiece and 1 or C.CREAM[1], U.onlyPiece and 1 or C.CREAM[2], U.onlyPiece and 1 or C.CREAM[3])

    local m = st.model
    if not m then return end
    local equippable = IsEquippable(entry)
    st.noEquip:SetShown(not equippable)

    local id = entry.id
    local key = tostring(id) .. (U.onlyPiece and ":o" or ":f")
    if st.unitDirty then
        st.unitDirty = false
        st._dressKey, st._appliedKey = nil, nil
        pcall(m.SetUnit, m, "player")
    end
    if st._dressKey ~= key then
        st._dressKey, st._appliedKey = key, nil
        if U.onlyPiece then
            if m.Undress then pcall(m.Undress, m) end
        else
            if m.Dress then pcall(m.Dress, m) elseif m.SetUnit then pcall(m.SetUnit, m, "player") end
        end
    end
    if equippable and id and m.TryOn and st._appliedKey ~= key then
        local function Request()
            if _G.C_Item and _G.C_Item.RequestLoadItemDataByID then
                pcall(_G.C_Item.RequestLoadItemDataByID, id)
            end
        end
        local function Apply()
            local lk = GetItemMeta(id).link
            local okT, r = pcall(m.TryOn, m, lk or ("item:" .. id))
            if okT and r and r ~= 0 then
                st._appliedKey = key
                return true
            end
            return false
        end
        if not Apply() then
            Request()
            local rf = st._retryFrame
            if not rf then
                rf = CreateFrame("Frame")
                st._retryFrame = rf
            end
            local acc, tries = 0, 0
            rf:SetScript("OnUpdate", function(self, dt)
                acc = acc + dt
                if acc < 2 then return end
                acc = 0
                tries = tries + 1
                local cur = U.codex and U.codex.entry
                if st._dressKey ~= key or st._appliedKey == key or not (cur and cur.id == id) or not st:IsShown() then
                    self:SetScript("OnUpdate", nil)
                    return
                end
                if Apply() then
                    self:SetScript("OnUpdate", nil)
                elseif tries >= 10 then
                    self:SetScript("OnUpdate", nil)
                    if GetItemMeta(id).name then
                        st.cmpText:SetText("O jogo não consegue vestir este item no modelo 3D")
                    else
                        st.cmpText:SetText("Item indisponível no cliente: não dá para provar no modelo 3D")
                    end
                else
                    Request()
                end
            end)
        end
    end
    if m.SetFacing then pcall(m.SetFacing, m, U.modelFacing) end
end

SLASH_AZTRY1 = "/aztry"
SlashCmdList["AZTRY"] = function()
    local cod, st = U.codex, U.tryOnStage
    local e = cod and cod.entry
    local function say(s) DEFAULT_CHAT_FRAME:AddMessage("|cffff9900AZtry|r " .. s) end
    if not (e and st and st.model) then say("selecione um item e abra o provador 3D") return end
    local mt = GetItemMeta(e.id)
    say(format("id=%s inv=%s cls=%s sub=%s", tostring(e.id), tostring(e.invType), tostring(e.classID), tostring(e.subclassID)))
    say(format("nome=%s equipLoc=%s link=%s", tostring(mt.name), tostring(mt.equipLoc), tostring(mt.link ~= nil)))
    local m = st.model
    local ok1, r1 = pcall(m.TryOn, m, mt.link or ("item:" .. e.id))
    local ok2, r2 = pcall(m.TryOn, m, "item:" .. e.id)
    say(format("TryOn(link)=%s/%s TryOn(item:id)=%s/%s", tostring(ok1), tostring(r1), tostring(ok2), tostring(r2)))
end

local function PaintSourceRow(row, src)
    row.src = src
    local ch = src.kind == "craft" and "100%" or src.vendor and "Loja"
        or (src.chance and src.chance > 0 and format("%.1f%%", src.chance) or "?")
    local hasMap = (src.kind ~= "craft") and src.map and src.map > 0 and (src.x or 0) > 0
    row.hasMap = hasMap and true or false
    row.activeSkin:SetAlpha(hasMap and 0.65 or 0)
    row.forceAnimDirty = true

    row.name:SetText(src.name or "")
    row.pctText:SetText(ch)
    if ch == "100%" then
        row.pctPill:Apply("PillN")
        row.pctPill:SetColor(0.95, 0.80, 0.45, 0.95)
        row.pctText:SetTextColor(C.GOLD_HI[1], C.GOLD_HI[2], C.GOLD_HI[3])
    else
        row.pctPill:Apply("PillA")
        row.pctPill:SetColor(1, 1, 1, 1)
        row.pctText:SetTextColor(0.62, 0.98, 0.95)
    end

    if src.kind == "craft" then
        H.SkillIconTex(row.icon, "hammer")
        row.icon:SetVertexColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])
        row.med.rim:SetVertexColor(C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.85)
        row.loc:SetWidth((row:GetWidth() or 430) - 74)
        row.loc:SetText(src.sub or "Item Craftável (Profissão)")
        row.loc:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])
        row.mapBtn:Hide()
    elseif hasMap then
        H.SkillIconTex(row.icon, "star")
        row.icon:SetVertexColor(C.CYAN[1], C.CYAN[2], C.CYAN[3])
        row.med.rim:SetVertexColor(C.CYAN[1], C.CYAN[2], C.CYAN[3], 0.92)
        row.loc:SetWidth((row:GetWidth() or 430) - 208)
        row.loc:SetText(format("%s  ·  (%.1f, %.1f)", MapName(src.map), src.x, src.y))
        row.loc:SetTextColor(C.CYAN[1], C.CYAN[2], C.CYAN[3])
        row.mapBtn.label:SetText("MARCAR NO MAPA")
        row.mapBtn:Show()
    else
        H.SkillIconTex(row.icon, src.kind == "quest" and "book" or "great")
        local col = src.kind == "quest" and C.GREEN or QUALITY_COLORS[4]
        row.icon:SetVertexColor(col[1], col[2], col[3])
        row.med.rim:SetVertexColor(col[1], col[2], col[3], 0.85)
        row.loc:SetWidth((row:GetWidth() or 430) - 74)
        -- vendedor sem posição conhecida não é masmorra
        row.loc:SetText(src.vendor and "Vendedor  ·  local não registrado" or SourcePlace(src))
        row.loc:SetTextColor(C.TEXT_HI[1], C.TEXT_HI[2], C.TEXT_HI[3])
        -- chefe do catálogo de masmorras: o mesmo botão leva à aba Masmorras
        local dg = Azaath:GetModule("SheetDungeons")
        if not src.vendor and src.key and dg and dg:HasBoss(src.key) then
            row.loc:SetWidth((row:GetWidth() or 430) - 208)
            row.mapBtn.label:SetText("VER CHEFE")
            row.mapBtn:Show()
        else
            row.mapBtn:Hide()
        end
    end
end

local function UpdateSources(entry)
    local d = U.codex
    if not (d and entry) then return end
    local list = entry.list or {}
    local maxOff = max(0, #list - MAX_SRCS)
    U.srcOffset = min(maxOff, max(0, U.srcOffset))

    d.srcCount:SetText(#list == 1 and "1 fonte" or (#list .. " fontes" .. (#list > MAX_SRCS and " (role)" or "")))
    for i = 1, MAX_SRCS do
        local row = U.srcs[i]
        local src = list[U.srcOffset + i]
        if src then
            PaintSourceRow(row, src)
            row:Show()
        else
            row.src = nil
            row:Hide()
        end
    end
end

local function UpdateDetail(entry)
    local d = U.codex
    if not d then return end
    if not entry then
        d.entry, d.meta = nil, nil
        d.empty:Show()
        d.body:Hide()
        return
    end
    d.empty:Hide()
    d.body:Show()

    local meta = GetItemMeta(entry.id, entry.quality)
    local qc = QUALITY_COLORS[meta.quality] or QUALITY_COLORS[1]
    d.entry = entry
    d.meta = meta

    local plaque = (meta.subType and meta.subType ~= "" and meta.slot and meta.slot ~= "")
        and (Azaath.Upper(meta.subType) .. "  ·  " .. Azaath.Upper(meta.slot))
        or (meta.slot and Azaath.Upper(meta.slot))
        or (meta.type and Azaath.Upper(meta.type))
        or ("RELÍQUIA #" .. entry.id)
    d.plaque:SetText(plaque)

    local dispName = ItemName(entry, meta)
    d.name:SetText(dispName)
    d.name:SetTextColor(qc[1], qc[2], qc[3])

    if d.favBtn then
        local idr = Azaath:GetModule("ItemDrops")
        local fav = idr and idr:IsFavorite(entry.id)
        d.favBtn.itemID = entry.id
        d.favBtn.label:SetText(fav and "SALVO" or "SALVAR")
        d.favBtn:SetActiveState(fav, C.GOLD)
        d.favBtn.favIcon:SetVertexColor(fav and C.GOLD_HI[1] or 0.7, fav and C.GOLD_HI[2] or 0.78, fav and C.GOLD_HI[3] or 0.85)
    end

    d.medallion.icon:SetTexture(meta.icon)
    local rimA = (meta.quality >= 2) and 0.95 or 0.65
    d.medallion.rim:SetVertexColor(qc[1], qc[2], qc[3], rimA)
    d.medallion.rim:Show()
    d.medallion.hoverRing:SetVertexColor(min(1, qc[1] + 0.25), min(1, qc[2] + 0.25), min(1, qc[3] + 0.25), 1)

    local ilvl = meta.iLevel or entry.iLvl or 0
    local req  = meta.reqLevel or entry.reqLevel or 0
    d.tagQual.baseCol = qc
    d.tagQual.label:SetText(Azaath.Upper(QUALITY_NAMES[meta.quality] or "Comum"))
    d.tagQual.label:SetTextColor(qc[1], qc[2], qc[3])
    d.tagQual:SetActiveState(false, qc)
    d.tagIlvl.baseCol = C.GOLD_HI
    d.tagIlvl.label:SetText(ilvl > 0 and ("iLvl " .. ilvl) or ("ID " .. entry.id))
    d.tagIlvl:SetActiveState(false, C.GOLD)
    d.tagReq.baseCol = C.CYAN
    d.tagReq.label:SetText(req > 1 and ("REQ. NÍVEL " .. req) or "SEM REQ.")
    d.tagReq:SetActiveState(true, C.CYAN)

    local eq = GetEquippedInSlot(entry)
    if eq and eq.iLvl and eq.iLvl > 0 and ilvl > 0 then
        local diff = ilvl - eq.iLvl
        if diff > 0 then
            d.cmpDelta:SetText(format("▲ +%d iLvl vs. equipado", diff))
            d.cmpDelta:SetTextColor(C.GREEN[1], C.GREEN[2], C.GREEN[3])
        elseif diff < 0 then
            d.cmpDelta:SetText(format("▼ %d iLvl vs. equipado", diff))
            d.cmpDelta:SetTextColor(0.94, 0.46, 0.40)
        else
            d.cmpDelta:SetText("= Mesmo iLvl equipado")
            d.cmpDelta:SetTextColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])
        end
    else
        d.cmpDelta:SetText("")
    end

    local statLines = meta.name and ScanItemStats(entry.id) or {}
    local buf = {}
    local loading = false
    local retrieving = _G.RETRIEVING_ITEM_INFO or "Recuperando"
    for _, sl in ipairs(statLines) do
        if sl.text:find(retrieving, 1, true) then
            loading = true
        else
            local hex = format("|cff%02x%02x%02x", floor(sl.r * 255), floor(sl.g * 255), floor(sl.b * 255))
            buf[#buf + 1] = hex .. sl.text .. "|r"
        end
    end
    if loading and not requestedIDs[entry.id] and _G.C_Item and _G.C_Item.RequestLoadItemDataByID then
        requestedIDs[entry.id] = true
        Safe(_G.C_Item.RequestLoadItemDataByID, entry.id)
    end
    local fb = (#buf == 0) and FormatFallbackStats(entry.stats, false) or nil
    local bodyText = (#buf > 0 and table.concat(buf, "\n"))
        or fb
        or (loading and "|cff5edee6Carregando atributos do servidor...|r"
            or "|cff9aa0a6Passe o mouse no medalhão para ver o tooltip.|r")
    if entry.craft then
        local c = entry.craft
        local craftHdr = format("|cff5edee6Profissão: %s · Nível %d|r\n%s",
            c.prof or "Ofício", c.skill or 0,
            c.recipeName and ("|cffe8c25bReceita: " .. c.recipeName .. "|r")
                or ("|cff9aa0a6Aprendido no Treinador de " .. (c.prof or "Ofício") .. "|r"))
        bodyText = craftHdr .. "\n\n" .. bodyText
    end
    d.statsText:SetText(bodyText)

    d.tryOnBtnText:SetText(U.showTryOn and "FECHAR 3D" or (IsEquippable(entry) and "PROVADOR 3D" or "MODELO 3D"))
    d.tryOnBtnText:SetTextColor(U.showTryOn and C.CYAN[1] or C.GOLD_HI[1], U.showTryOn and C.CYAN[2] or C.GOLD_HI[2], U.showTryOn and C.CYAN[3] or C.GOLD_HI[3])

    UpdateSources(entry)
    UpdateTryOn(entry, meta)
end

--------------------------------------------------------------------------------
-- Layout Dinâmico do Catálogo & Pintura das Cartas
--------------------------------------------------------------------------------
local function RelayoutCatalog()
    local cat = U.catPanel
    if not cat then return end

    local tryOn = U.showTryOn
    local W_CAT = tryOn and 946 or 1346
    local W0    = W_CAT - 52
    local X0    = 26

    cat:SetSize(W_CAT, 950)
    if U.breadcrumb then U.breadcrumb:SetWidth(max(120, W_CAT - 540)) end
    if U.tryOnStage then U.tryOnStage:SetShown(tryOn) end

    -- Nível 1: Busca + Zona + 5 Origens
    local searchW = tryOn and 262 or 458
    local zoneW   = tryOn and 130 or 168
    local origWs  = tryOn and { 94, 92, 114, 76, 68 } or { 114, 112, 134, 96, 86 }
    U.searchBox:SetSize(searchW, 34)
    U.zoneBtn:SetSize(zoneW, 32)
    U.zoneBtn.label:SetWidth(zoneW - 14)

    local ox = X0 + searchW + 10 + zoneW + 12
    local availO = X0 + W0 - ox
    local sumO = 0
    for _, w in ipairs(origWs) do sumO = sumO + w end
    local gapO = floor((availO - sumO) / (#origWs - 1))
    for i, b in ipairs(U.btns.origin) do
        b:SetSize(origWs[i], 30)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", cat, "TOPLEFT", ox, -63)
        ox = ox + origWs[i] + gapO
    end

    -- Nível 2: Nível (esquerda) + Raridade (direita); as categorias ficam na árvore à esquerda
    local lx = X0 + 54
    for _, b in ipairs(U.btns.level) do
        local bw = b.baseW + (tryOn and 0 or 10)
        b:SetSize(bw, 26)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", cat, "TOPLEFT", lx, -106)
        lx = lx + bw + (tryOn and 5 or 8)
    end

    local qx = X0 + W0
    for i = #U.btns.qual, 1, -1 do
        local b = U.btns.qual[i]
        local bw = b.baseW + (tryOn and 0 or 10)
        qx = qx - bw
        b:SetSize(bw, 26)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", cat, "TOPLEFT", qx, -106)
        qx = qx - (tryOn and 6 or 8)
    end
    U.qualLabel:ClearAllPoints()
    U.qualLabel:SetPoint("RIGHT", U.btns.qual[1], "LEFT", -8, 0)

    -- Árvore de categorias (esquerda) + grade de cartas (direita):
    -- 3 colunas x 4 linhas, ou 2 x 4 com o Provador 3D aberto
    local gy = -160
    U.tree:ClearAllPoints()
    U.tree:SetPoint("TOPLEFT", cat, "TOPLEFT", X0, gy)
    local GX = X0 + TREE_W + 16
    local cols = tryOn and 2 or 3
    U.cols = cols
    U.visibleCards = cols * 4
    local gridW = X0 + W0 - GX - 14
    local gapX, gapY = 12, 12
    local cardW = floor((gridW - (cols - 1) * gapX) / cols)
    local cardH = 166

    for i = 1, MAX_CARDS do
        local c = U.cards[i]
        if i <= U.visibleCards then
            local col, row = (i - 1) % cols, floor((i - 1) / cols)
            c:SetSize(cardW, cardH)
            c:ClearAllPoints()
            c:SetPoint("TOPLEFT", cat, "TOPLEFT", GX + col * (cardW + gapX), gy - row * (cardH + gapY))
            c.title:SetWidth(cardW - 100)
            c.sub:SetWidth(cardW - 100)
            c.stats:SetWidth(cardW - 100)
            c.forceAnimDirty = true
        else
            c:Hide()
        end
    end

    U.scrollTrack:ClearAllPoints()
    U.scrollTrack:SetPoint("TOPLEFT", cat, "TOPLEFT", X0 + W0 - 6, gy)
    U.scrollTrack:SetSize(5, 4 * cardH + 3 * gapY)
end

local function PaintCards()
    local list = U.lastList
    local vis = U.visibleCards or 8
    local maxOff = max(0, #list - vis)
    U.offset = min(maxOff, max(0, U.offset))

    local selectedEntry
    if #list > 0 then
        for i = 1, #list do
            if list[i].entry.id == U.selectedID then
                selectedEntry = list[i].entry
                break
            end
        end
        if not selectedEntry then
            selectedEntry = list[1].entry
            U.selectedID = selectedEntry.id
            U.srcOffset = 0
        end
    end

    local visibleIDs = {}

    for i = 1, MAX_CARDS do
        local c = U.cards[i]
        local rec = (i <= vis) and list[U.offset + i] or nil
        if rec then
            local it, src = rec.entry, rec.best
            visibleIDs[it.id] = true
            local meta = GetItemMeta(it.id, it.quality)
            local qc = QUALITY_COLORS[meta.quality] or QUALITY_COLORS[1]
            local isRare = (meta.quality or 1) >= 2
            c.rec = rec
            c.qc = qc

            c.med.icon:SetTexture(meta.icon)
            c.med.rim:SetVertexColor(qc[1], qc[2], qc[3], isRare and 0.95 or 0.55)
            c.med.rim:Show()
            if c.med.aura then
                c.med.aura:SetVertexColor(qc[1], qc[2], qc[3], isRare and 0.34 or 0.14)
                c.med.aura:SetShown(isRare)
            end
            if c.med.wisps then
                c.med.wisps:SetVertexColor(qc[1], qc[2], qc[3], 0.32)
            end

            c.rarityBar:SetVertexColor(qc[1], qc[2], qc[3], isRare and 0.92 or 0.45)
            c.rarityGlow:SetVertexColor(qc[1], qc[2], qc[3], isRare and 0.34 or 0.14)

            c.title:SetText(ItemName(it, meta))
            c.title:SetTextColor(qc[1], qc[2], qc[3])

            -- linha 2: tipo/encaixe, depois iLvl e nível exigido (o nome fica com a linha inteira)
            local ilvl = meta.iLevel or it.iLvl or 0
            local req  = meta.reqLevel or it.reqLevel or 0
            c.badgePill:Hide()
            local slotStr = (meta.slot and meta.slot ~= "") and (meta.slot .. (meta.subType and (" · " .. meta.subType) or ""))
                or (meta.subType and meta.subType ~= "" and meta.subType)
                or meta.type or ""
            local parts = {}
            if slotStr ~= "" then parts[#parts + 1] = slotStr end
            if ilvl > 0 then parts[#parts + 1] = "|cffe6c785iLvl " .. ilvl .. "|r" end
            if req > 1 then parts[#parts + 1] = "|cffe6c785Nível " .. req .. "|r" end
            c.sub:SetText(table.concat(parts, "  ·  "))

            local fb = FormatFallbackStats(it.stats, true)
            if not fb and it.craft then
                fb = format("Ofício: %s (%d)", it.craft.prof or "Ofício", it.craft.skill or 0)
            end
            c.stats:SetText(fb or "Passe o mouse para ver atributos")

            local tagTxt, tagCol = "MUNDO", C.CYAN
            if src then
                if src.kind == "craft" then tagTxt, tagCol = "OFÍCIO", C.GOLD
                elseif src.kind == "quest" then tagTxt, tagCol = "MISSÃO", C.GREEN
                elseif src.vendor then tagTxt, tagCol = "LOJA", C.CYAN
                elseif src.kind == "instance" then tagTxt, tagCol = "MASMORRA", QUALITY_COLORS[4]
                elseif src.kind == "recipe" then tagTxt, tagCol = "RECEITA", C.GOLD end
            end
            c.tag:SetText(tagTxt)
            c.tag:SetTextColor(tagCol[1], tagCol[2], tagCol[3])

            local srcLoc = (src and src.map and src.map > 0 and src.x and src.x > 0)
                and format("%s · %s (%.1f, %.1f)", src.name, MapName(src.map), src.x, src.y)
                or (src and src.name or "")
            c.src:SetText("· " .. srcLoc)

            local ch = (src and src.kind == "craft" and "100%") or (src and src.vendor and "Loja")
                or (src and src.chance and src.chance > 0 and format("%.1f%%", src.chance) or "?")
            c.pctText:SetText(ch)
            if ch == "100%" then
                c.pctPill:Apply("PillN")
                c.pctPill:SetColor(0.95, 0.80, 0.45, 0.95)
                c.pctText:SetTextColor(C.GOLD_HI[1], C.GOLD_HI[2], C.GOLD_HI[3])
            else
                c.pctPill:Apply("PillA")
                c.pctPill:SetColor(1, 1, 1, 1)
                c.pctText:SetTextColor(0.62, 0.98, 0.95)
            end

            local idr = Azaath:GetModule("ItemDrops")
            local fav = idr and idr:IsFavorite(it.id)
            c.favBtn.icon:SetVertexColor(fav and C.GOLD_HI[1] or 0.7, fav and C.GOLD_HI[2] or 0.78, fav and C.GOLD_HI[3] or 0.85)
            c.favBtn.icon:SetAlpha(fav and 1 or 0.35)

            local sel = U.selectedID == it.id
            c.sel = sel
            if sel then
                Azaath.Gradient(c.bg, "VERTICAL", 0.024, 0.068, 0.112, 0.98, 0.072, 0.184, 0.258, 0.98)
            else
                Azaath.Gradient(c.bg, "VERTICAL", 0.015, 0.036, 0.062, 0.96, 0.044, 0.102, 0.158, 0.96)
            end
            c.bottomBeam:SetVertexColor(qc[1], qc[2], qc[3], 1)
            c.forceAnimDirty = true
            c:Show()
        else
            c.rec = nil
            c.sel = false
            c.isHovered = false
            c:Hide()
        end
    end

    -- Barra de rolagem proporcional
    local trackH = U.scrollTrack:GetHeight() or 600
    if #list > vis then
        local ratio = min(1, vis / #list)
        local th = max(36, floor(trackH * ratio))
        local prog = maxOff > 0 and (U.offset / maxOff) or 0
        U.scrollThumb:SetHeight(th)
        U.scrollThumb:ClearAllPoints()
        U.scrollThumb:SetPoint("TOP", U.scrollTrack, "TOP", 0, -floor((trackH - th) * prog))
        U.scrollTrack:Show()
        U.scrollThumb:Show()
    else
        U.scrollTrack:Hide()
        U.scrollThumb:Hide()
    end

    if selectedEntry then visibleIDs[selectedEntry.id] = true end
    U.visibleIDs = visibleIDs

    U.emptyList:SetText(U.cat == "fav"
        and "Nenhum item salvo ainda.\nClique na estrela de um card (ou em SALVAR no códice) para guardar o item aqui."
        or "Nenhuma relíquia encontrada com estes filtros.")
    U.emptyList:SetShown(#list == 0)

    local pageCur = floor(U.offset / max(1, vis)) + 1
    local pageMax = max(1, ceil(#list / vis))
    local totTxt = (U.lastTotal > #list) and format("%d+ de %d itens", #list, U.lastTotal)
        or format("%d %s", #list, #list == 1 and "item" or "itens")
    U.countText:SetText(format("%s  ·  Pág. %d / %d", totTxt, pageCur, pageMax))

    UpdateDetail(selectedEntry)
end

local function UpdateFilterVisuals()
    local mapID = 0
    if U.zoneOnly and _G.C_Map and _G.C_Map.GetBestMapForUnit then
        mapID = Safe(_G.C_Map.GetBestMapForUnit, "player") or 0
    end
    U.zoneBtn:SetActiveState(U.zoneOnly, C.CYAN)
    U.zoneBtn.label:SetText(U.zoneOnly and ("Zona: " .. MapName(mapID)) or "Todo o Mundo")

    for _, b in ipairs(U.btns.origin) do
        b:SetActiveState(b.val == U.origin, C.CYAN)
    end

    for _, b in ipairs(U.btns.level) do
        b:SetActiveState(b.val == U.level, C.CYAN)
    end

    for _, b in ipairs(U.btns.qual) do
        b:SetActiveState(b.val == U.minQuality, b.col)
    end

    -- trilha do ramo escolhido: "Armaduras  >  Placa  >  Cabeça"
    local Cats = Azaath.ItemCats
    local idr = Azaath:GetModule("ItemDrops")
    local pt = not (idr and idr.IsPt) or idr.IsPt()
    local node = Cats and Cats.byKey[U.cat]
    local path = {}
    while node do table.insert(path, 1, Cats.Label(node, pt)); node = node.parent end
    if U.cat == "fav" then path = { pt and "Itens salvos" or "Saved items" } end
    U.breadcrumb:SetText(#path > 0 and table.concat(path, "  >  ") or (pt and "Todas as categorias" or "All categories"))
    return mapID
end

--------------------------------------------------------------------------------
-- Árvore de categorias (como a Casa de Leilões): ramos abrem e fecham, cada um com a contagem
--------------------------------------------------------------------------------
local function TreeRowsVisible()
    local Cats = Azaath.ItemCats
    local onPath = {}
    local s = Cats and Cats.byKey[U.cat]
    while s do onPath[s.key] = true; s = s.parent end
    local rows = { { key = "fav", depth = 0 }, { key = "all", depth = 0 } } -- itens salvos sempre no topo
    local function add(list)
        for _, n in ipairs(list) do
            if (U.counts[n.key] or 0) > 0 or onPath[n.key] then
                rows[#rows + 1] = n
                if n.kids and U.expanded[n.key] then add(n.kids) end
            end
        end
    end
    if Cats then add(Cats.TREE) end
    return rows
end

local function PaintTree()
    if not U.tree then return end
    local Cats = Azaath.ItemCats
    local idr = Azaath:GetModule("ItemDrops")
    local pt = not (idr and idr.IsPt) or idr.IsPt()
    local rows = TreeRowsVisible()
    U.treeRows = rows
    U.treeOff = min(max(0, #rows - TREE_ROWS), max(0, U.treeOff))
    for i = 1, TREE_ROWS do
        local r, n = U.treeBtns[i], rows[i + U.treeOff]
        r.node = n
        if n then
            local special = n.key == "all" or n.key == "fav"
            local d = special and 0 or (n.depth + 1)
            local label = n.key == "fav" and (pt and "Itens salvos" or "Saved items")
                or n.key == "all" and (pt and "Todas as categorias" or "All categories") or Cats.Label(n, pt)
            r.label:SetText(label)
            r.label:ClearAllPoints()
            r.label:SetPoint("LEFT", 30 + (d - 1 < 0 and 0 or d - 1) * 16, 0)
            local cnt = special and (U.counts[n.key] or 0) or (U.counts[n.key] or 0)
            r.icon:SetShown(n.key == "fav")
            r.count:SetText(cnt > 0 and tostring(cnt) or "")
            -- sinal de abrir/fechar só em quem tem filhos
            if n.kids then
                r.arrow:SetText(U.expanded[n.key] and "-" or "+")
                r.arrow:ClearAllPoints()
                r.arrow:SetPoint("RIGHT", r.label, "LEFT", -6, 0)
                r.arrow:Show()
            else
                r.arrow:Hide()
            end
            local sel = U.cat == n.key
            local top = special or n.depth == 0
            -- pai da seleção? (destaque leve no caminho até ela)
            local onPath = false
            local s = Cats and Cats.byKey[U.cat]
            s = s and s.parent
            while s do if s == n then onPath = true break end s = s.parent end
            r.card:SetShown(top)
            for _, tx in ipairs(r.cardSkin.t) do tx:SetShown(top) end
            -- subcategoria: faixa recuada até o nível dela, com a guia do ramo à esquerda
            local indent = 14 + (d - 1) * 16
            r.subBg:SetShown(not top)
            r.subLine:SetShown(not top)
            r.subBg:ClearAllPoints()
            r.subBg:SetPoint("TOPLEFT", indent, 0)
            r.subBg:SetPoint("BOTTOMRIGHT", 0, 0)
            r.guide:SetShown(not top)
            r.guide:ClearAllPoints()
            r.guide:SetPoint("TOPLEFT", indent - 4, 1)
            r.guide:SetPoint("BOTTOMLEFT", indent - 4, -1)
            r.sel:ClearAllPoints()
            r.sel:SetPoint("TOPLEFT", top and 0 or indent, 0)
            r.sel:SetPoint("BOTTOMRIGHT", 0, 0)
            r.selBar:ClearAllPoints()
            r.selBar:SetPoint("TOPLEFT", top and 0 or indent, -2)
            r.selBar:SetPoint("BOTTOMLEFT", top and 0 or indent, 2)
            r.cardSkin.dTop:Hide(); r.cardSkin.dBot:Hide(); r.cardSkin.flare:Hide()
            r.path:SetShown(onPath and not sel)
            r.selBar:SetShown(sel)
            r.selBeam:SetShown(sel)
            r.arrow:SetTextColor((onPath or sel) and C.GOLD_HI[1] or C.CYAN[1], (onPath or sel) and C.GOLD_HI[2] or C.CYAN[2], (onPath or sel) and C.GOLD_HI[3] or C.CYAN[3])
            r.label:SetFont(top and U.fonts.CB or U.fonts.B, top and 13.5 or 12.5, "")
            local col = sel and C.GOLD_HI or (top and C.CREAM or C.TEXT_HI)
            r.label:SetTextColor(col[1], col[2], col[3])
            r.sel:SetShown(sel)
            r:Show()
        else
            r:Hide()
        end
    end
end

local function BuildCategoryTree(cat, F)
    local t = CreateFrame("Frame", nil, cat)
    t:SetSize(TREE_W, TREE_ROWS * TREE_ROW_H + 12)
    U.tree = t
    local bg = t:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetAllPoints()
    bg:SetColorTexture(1, 1, 1, 1)
    Azaath.Gradient(bg, "VERTICAL", 0.010, 0.026, 0.060, 0.82, 0.020, 0.050, 0.105, 0.82)
    local edge = t:CreateTexture(nil, "BORDER", nil, 1)
    edge:SetTexture(UF_MEDIA .. "ClassicGlassH")
    edge:SetBlendMode("ADD")
    edge:SetPoint("TOPRIGHT", 0, 0)
    edge:SetPoint("BOTTOMRIGHT", 0, 0)
    edge:SetWidth(2)
    edge:SetVertexColor(0.42, 0.90, 1.0, 0.30)

    U.treeBtns = {}
    for i = 1, TREE_ROWS do
        local r = CreateFrame("Button", nil, t)
        r:SetSize(TREE_W - 12, TREE_ROW_H - 2)
        r:SetPoint("TOPLEFT", 4, -6 - (i - 1) * TREE_ROW_H)
        -- card das categorias principais (Armas, Armaduras...): fundo e moldura fina
        r.card = r:CreateTexture(nil, "BACKGROUND", nil, 1)
        r.card:SetAllPoints()
        r.card:SetColorTexture(1, 1, 1, 1) -- base para o gradiente aparecer
        Azaath.Gradient(r.card, "VERTICAL", 0.030, 0.070, 0.130, 0.92, 0.050, 0.110, 0.190, 0.92)
        -- subcategorias: faixa discreta, filete embaixo e guia vertical do recuo
        r.subBg = r:CreateTexture(nil, "BACKGROUND", nil, 1)
        r.subBg:SetPoint("TOPLEFT", 14, 0)
        r.subBg:SetPoint("BOTTOMRIGHT", 0, 0)
        r.subBg:SetColorTexture(0.06, 0.12, 0.20, 0.45)
        r.subLine = r:CreateTexture(nil, "BORDER", nil, 1)
        r.subLine:SetPoint("BOTTOMLEFT", r.subBg, "BOTTOMLEFT", 0, 0)
        r.subLine:SetPoint("BOTTOMRIGHT", r.subBg, "BOTTOMRIGHT", 0, 0)
        r.subLine:SetHeight(1)
        r.subLine:SetColorTexture(0.40, 0.70, 0.90, 0.16)
        r.guide = r:CreateTexture(nil, "BORDER", nil, 2)
        r.guide:SetWidth(1.5)
        r.guide:SetPoint("TOP", 0, 1)
        r.guide:SetPoint("BOTTOM", 0, -1)
        r.guide:SetColorTexture(0.45, 0.80, 1.0, 0.30)
        r.cardSkin = H.Skin(r, "WideN", 0.30, "BORDER", 1)
        r.cardSkin:SetCenterAlpha(0)
        -- ramo do caminho escolhido (pais da seleção): leve
        r.path = r:CreateTexture(nil, "BACKGROUND", nil, 2)
        r.path:SetAllPoints()
        r.path:SetColorTexture(0.40, 0.80, 1.0, 0.07)
        r.path:Hide()
        -- seleção: faixa ciano + barra à esquerda + feixe embaixo
        r.sel = r:CreateTexture(nil, "BACKGROUND", nil, 3)
        r.sel:SetAllPoints()
        r.sel:SetColorTexture(1, 1, 1, 1)
        Azaath.Gradient(r.sel, "HORIZONTAL", 0.12, 0.46, 0.62, 0.85, 0.04, 0.16, 0.26, 0.35)
        r.sel:Hide()
        r.selBar = r:CreateTexture(nil, "ARTWORK", nil, 1)
        r.selBar:SetPoint("TOPLEFT", 0, -2)
        r.selBar:SetPoint("BOTTOMLEFT", 0, 2)
        r.selBar:SetWidth(3)
        r.selBar:SetColorTexture(C.CYAN[1], C.CYAN[2], C.CYAN[3], 1)
        r.selBar:Hide()
        r.selBeam = r:CreateTexture(nil, "ARTWORK", nil, 2)
        r.selBeam:SetTexture(UF_MEDIA .. "ClassicGlassH")
        r.selBeam:SetBlendMode("ADD")
        r.selBeam:SetPoint("BOTTOMLEFT", 6, 0)
        r.selBeam:SetPoint("BOTTOMRIGHT", -6, 0)
        r.selBeam:SetHeight(2)
        r.selBeam:SetVertexColor(C.CYAN[1], C.CYAN[2], C.CYAN[3], 0.9)
        r.selBeam:Hide()
        r.hover = r:CreateTexture(nil, "BACKGROUND", nil, 3)
        r.hover:SetAllPoints()
        r.hover:SetColorTexture(0.45, 0.85, 1.0, 0.07)
        r.hover:Hide()
        r.arrow = H.Txt(r, F.CB, 14, C.CYAN, "CENTER")
        r.label = H.Txt(r, F.B, 12.5, C.TEXT_HI)
        r.label:SetPoint("LEFT", 30, 0)
        r.count = H.Txt(r, F.B, 11.5, C.MUTED, "RIGHT")
        r.icon = r:CreateTexture(nil, "ARTWORK", nil, 3)
        r.icon:SetSize(16, 16)
        r.icon:SetPoint("LEFT", 9, 0)
        H.SkillIconTex(r.icon, "star", 10)
        r.icon:SetVertexColor(C.GOLD_HI[1], C.GOLD_HI[2], C.GOLD_HI[3])
        r.icon:Hide()
        r.count:SetPoint("RIGHT", -8, 0)
        r:SetScript("OnEnter", function(self) self.hover:Show() end)
        r:SetScript("OnLeave", function(self) self.hover:Hide() end)
        r:SetScript("OnClick", function(self)
            local n = self.node
            if not n then return end
            PlayClick()
            if n.kids then
                -- clicar num ramo já escolhido abre/fecha; num ramo novo, escolhe e abre
                if U.cat == n.key then U.expanded[n.key] = not U.expanded[n.key] else U.expanded[n.key] = true end
            end
            U.cat = n.key
            U.offset = 0
            M:Refresh()
        end)
        U.treeBtns[i] = r
    end
    t:EnableMouseWheel(true)
    t:SetScript("OnMouseWheel", function(_, delta)
        U.treeOff = max(0, U.treeOff - delta * 2)
        PaintTree()
    end)
end

function M:Refresh()
    if not (U.page and U.page:IsShown()) then return end
    local idrops = Azaath:GetModule("ItemDrops")
    if not idrops then return end

    local mapID = UpdateFilterVisuals()
    RelayoutCatalog()

    U.counts = {}
    local list, total = idrops:Query({
        mapID      = mapID,
        query      = U.query,
        cat        = U.cat ~= "fav" and U.cat or nil,
        favOnly    = U.cat == "fav",
        counts     = U.counts,
        origin     = U.origin,
        level      = U.level,
        minQuality = U.minQuality,
        limit      = 0,
    })
    PaintTree()
    U.lastList = list or {}
    U.lastTotal = total or #U.lastList

    PaintCards()
end

--------------------------------------------------------------------------------
-- Construtores dos Cartões & Zonas (Catálogo, Provador 3D, Códice)
--------------------------------------------------------------------------------
local function CreateItemCard(cat, F)
    local c = CreateFrame("Button", nil, cat)
    c:SetSize(416, 152)

    c.bg = c:CreateTexture(nil, "BACKGROUND", nil, 0)
    c.bg:SetPoint("TOPLEFT", 4, -4)
    c.bg:SetPoint("BOTTOMRIGHT", -4, 4)
    Azaath.Gradient(c.bg, "VERTICAL", 0.024, 0.054, 0.118, 0.96, 0.048, 0.104, 0.205, 0.96)

    c.footBg = c:CreateTexture(nil, "BACKGROUND", nil, 1)
    c.footBg:SetPoint("BOTTOMLEFT", 6, 5)
    c.footBg:SetPoint("BOTTOMRIGHT", -6, 5)
    c.footBg:SetHeight(38)
    c.footBg:SetColorTexture(0.014, 0.032, 0.072, 0.80)

    c.sheen = c:CreateTexture(nil, "BACKGROUND", nil, 2)
    c.sheen:SetTexture(UF_MEDIA .. "ClassicGlassH")
    c.sheen:SetBlendMode("ADD")
    c.sheen:SetPoint("TOPLEFT", 10, -5)
    c.sheen:SetPoint("TOPRIGHT", -10, -5)
    c.sheen:SetHeight(24)
    c.sheen:SetVertexColor(0.55, 0.90, 1.0, 0.14)

    c.rarityGlow = c:CreateTexture(nil, "BACKGROUND", nil, 2)
    c.rarityGlow:SetTexture(MEDIA_ROOT .. "Glow")
    c.rarityGlow:SetBlendMode("ADD")
    c.rarityGlow:SetSize(130, 130)
    c.rarityGlow:SetPoint("TOPLEFT", -18, 12)

    c.hoverGlow = c:CreateTexture(nil, "BORDER", nil, 0)
    c.hoverGlow:SetPoint("TOPLEFT", 4, -4)
    c.hoverGlow:SetPoint("BOTTOMRIGHT", -4, 4)
    c.hoverGlow:SetTexture(MEDIA_ROOT .. "Glow")
    c.hoverGlow:SetBlendMode("ADD")
    c.hoverGlow:SetVertexColor(C.CYAN[1], C.CYAN[2], C.CYAN[3], 1)
    c.hoverGlow:SetAlpha(0)

    c.skin = H.Skin(c, "DropWide", 0.48, "BORDER", 1)
    c.skin:SetCenterAlpha(0)
    c.skin:SetColor(1, 1, 1, 0.96)

    c.activeSkin = H.Skin(c, "WideA", 0.56, "BORDER", 2)
    c.activeSkin:SetCenterAlpha(0.10)
    c.activeSkin:SetAlpha(0)

    c.rarityBar = c:CreateTexture(nil, "ARTWORK", nil, 0)
    c.rarityBar:SetWidth(3.5)
    c.rarityBar:SetPoint("TOPLEFT", 6, -12)
    c.rarityBar:SetPoint("BOTTOMLEFT", 6, 12)
    c.rarityBar:SetTexture(UF_MEDIA .. "HealthFill")

    c.med = H.CircleIcon(c, 46, 62, "bezel", true)
    c.med:SetPoint("TOPLEFT", 16, -18)

    c.badgePill = CreateFrame("Frame", nil, c)
    c.badgePill:SetSize(84, 20)
    c.badgePill:SetPoint("TOPRIGHT", -14, -17)
    H.Skin(c.badgePill, "PillN", 20 / 44, "BACKGROUND", 1):SetColor(0.88, 0.76, 0.48, 0.90)
    c.badge = H.Txt(c.badgePill, F.CB, 10.5, C.GOLD_HI, "CENTER")
    c.badge:SetPoint("CENTER")

    -- nome (até 2 linhas) / tipo · iLvl · nível / atributos (até 2 linhas) / rodapé com a origem
    c.title = H.Txt(c, F.CB, 15, C.CREAM)
    c.title:SetPoint("TOPLEFT", 86, -16)
    c.title:SetWordWrap(true)
    if c.title.SetMaxLines then c.title:SetMaxLines(2) end

    c.sub = H.Txt(c, F.B, 11.5, { 0.80, 0.78, 0.70 })
    c.sub:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -5)

    c.stats = H.Txt(c, F.B, 12, C.GREEN)
    c.stats:SetPoint("TOPLEFT", c.sub, "BOTTOMLEFT", 0, -6)
    c.stats:SetWordWrap(true)
    if c.stats.SetMaxLines then c.stats:SetMaxLines(2) end

    local sep = c:CreateTexture(nil, "ARTWORK", nil, 1)
    sep:SetPoint("BOTTOMLEFT", 14, 43)
    sep:SetPoint("BOTTOMRIGHT", -14, 43)
    sep:SetHeight(1.5)
    sep:SetTexture(UF_MEDIA .. "ClassicGlassH")
    sep:SetBlendMode("ADD")
    sep:SetVertexColor(0.45, 0.82, 0.96, 0.25)

    c.pctFrame = CreateFrame("Frame", nil, c)
    c.pctFrame:SetSize(56, 22)
    c.pctFrame:SetPoint("BOTTOMRIGHT", -14, 11)
    c.pctPill = H.Skin(c.pctFrame, "PillA", 22 / 46, "BACKGROUND", 2)
    c.pctText = H.Txt(c.pctFrame, F.CB, 11, { 0.62, 0.98, 0.95 }, "CENTER")
    c.pctText:SetPoint("CENTER")

    c.tag = H.Txt(c, F.CB, 10.5, C.CYAN)
    c.tag:SetPoint("BOTTOMLEFT", 18, 16)

    c.src = H.Txt(c, F.B, 11.5, C.TEXT_HI)
    c.src:SetPoint("LEFT", c.tag, "RIGHT", 6, 0)
    c.src:SetPoint("RIGHT", c.pctFrame, "LEFT", -8, 0)

    -- estrela de salvar (canto do card): acesa = item salvo em "Itens salvos"
    c.favBtn = CreateFrame("Button", nil, c)
    c.favBtn:SetSize(24, 24)
    c.favBtn:SetPoint("TOPRIGHT", -10, -10)
    c.favBtn:SetFrameLevel(c:GetFrameLevel() + 3)
    c.favBtn.icon = c.favBtn:CreateTexture(nil, "OVERLAY", nil, 4)
    c.favBtn.icon:SetAllPoints()
    H.SkillIconTex(c.favBtn.icon, "star", 10)
    c.favBtn:SetScript("OnClick", function(self)
        local rec = self:GetParent().rec
        local idr = Azaath:GetModule("ItemDrops")
        if not (rec and idr) then return end
        PlayClick()
        idr:ToggleFavorite(rec.entry.id)
        M:Refresh()
    end)
    c.favBtn:SetScript("OnEnter", function(self)
        local rec = self:GetParent().rec
        local idr = Azaath:GetModule("ItemDrops")
        local on = rec and idr and idr:IsFavorite(rec.entry.id)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:AddLine(on and "Remover dos itens salvos" or "Salvar item", 1, 0.86, 0.5)
        GameTooltip:AddLine("Os itens salvos ficam em \"Itens salvos\", no topo das categorias.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
        self.icon:SetAlpha(1)
    end)
    c.favBtn:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        local rec = self:GetParent().rec
        local idr = Azaath:GetModule("ItemDrops")
        self.icon:SetAlpha(rec and idr and idr:IsFavorite(rec.entry.id) and 1 or 0.35)
    end)

    c.bottomBeam = c:CreateTexture(nil, "OVERLAY", nil, 2)
    c.bottomBeam:SetTexture(UF_MEDIA .. "ClassicGlassH")
    c.bottomBeam:SetBlendMode("ADD")
    c.bottomBeam:SetHeight(3)
    c.bottomBeam:SetWidth(120)
    c.bottomBeam:SetPoint("CENTER", c, "BOTTOM", 0, 2)
    c.bottomBeam:SetVertexColor(C.CYAN[1], C.CYAN[2], C.CYAN[3], 1)
    c.bottomBeam:SetAlpha(0)

    c.bottomStar = c:CreateTexture(nil, "OVERLAY", nil, 3)
    c.bottomStar:SetTexture(MEDIA_ROOT .. "Star")
    c.bottomStar:SetBlendMode("ADD")
    c.bottomStar:SetSize(16, 16)
    c.bottomStar:SetPoint("CENTER", c.bottomBeam, "CENTER", 0, 0)
    c.bottomStar:SetVertexColor(0.75, 0.98, 1.0, 1)
    c.bottomStar:SetAlpha(0)

    RegHover(c, "item")
    c:SetScript("OnEnter", function(self)
        self.isHovered = true
        if self.rec then ShowItemTooltip(self, self.rec.entry) end
    end)
    c:SetScript("OnLeave", function(self)
        self.isHovered = false
        GameTooltip:Hide()
    end)
    c:SetScript("OnClick", function(self)
        if not self.rec then return end
        PlayClick()
        if _G.IsModifiedClick and _G.IsModifiedClick("CHATLINK") then
            LinkItemToChat(self.rec.entry)
            return
        end
        U.selectedID = self.rec.entry.id
        U.srcOffset = 0
        PaintCards()
    end)
    c:Hide()
    return c
end

local function BuildCatalogPanel(art)
    local F = U.fonts
    local cat = CreateFrame("Frame", nil, art)
    cat:SetPoint("TOPLEFT", art, "TOPLEFT", 34, -104)
    cat:SetSize(1346, 950)
    cat:SetFrameLevel(art:GetFrameLevel() + 2)
    U.catPanel = cat

    -- Fundo azul marinho moderno limpo (sem textura borrada/esticada no miolo)
    local bgGrad = cat:CreateTexture(nil, "BACKGROUND", nil, 0)
    bgGrad:SetPoint("TOPLEFT", 6, -6)
    bgGrad:SetPoint("BOTTOMRIGHT", -6, 6)
    Azaath.Gradient(bgGrad, "VERTICAL", 0.018, 0.040, 0.090, 0.97, 0.038, 0.082, 0.165, 0.97)

    local filterWell = cat:CreateTexture(nil, "BACKGROUND", nil, 1)
    filterWell:SetPoint("TOPLEFT", 12, -52)
    filterWell:SetPoint("TOPRIGHT", -12, -52)
    filterWell:SetHeight(90)
    Azaath.Gradient(filterWell, "VERTICAL", 0.012, 0.028, 0.068, 0.72, 0.024, 0.056, 0.120, 0.76)

    local topGlow = cat:CreateTexture(nil, "BACKGROUND", nil, 2)
    topGlow:SetTexture(UF_MEDIA .. "ClassicGlassH")
    topGlow:SetBlendMode("ADD")
    topGlow:SetPoint("TOPLEFT", 18, -6)
    topGlow:SetPoint("TOPRIGHT", -18, -6)
    topGlow:SetHeight(42)
    topGlow:SetVertexColor(0.35, 0.85, 1.0, 0.18)

    local titleAura = cat:CreateTexture(nil, "BACKGROUND", nil, 2)
    titleAura:SetTexture(MEDIA_ROOT .. "Glow")
    titleAura:SetBlendMode("ADD")
    titleAura:SetSize(320, 72)
    titleAura:SetPoint("TOPLEFT", -10, 6)
    titleAura:SetVertexColor(0.25, 0.78, 1.0, 0.22)

    local catFrame = H.Skin(cat, "DropPanel", 0.72, "BORDER", 1)
    catFrame:SetCenterAlpha(0)
    catFrame:SetColor(1, 1, 1, 0.98)

    local title = H.Txt(cat, F.C, 24, C.GOLD_HI)
    title:SetPoint("TOPLEFT", 26, -16)
    title:SetText("RELICÁRIO DE AZAATH")

    U.breadcrumb = H.Txt(cat, F.CB, 14, C.CYAN)
    U.breadcrumb:SetPoint("LEFT", title, "RIGHT", 16, -3)

    U.countText = H.Txt(cat, F.CB, 13, C.GOLD, "RIGHT")
    U.countText:SetPoint("TOPRIGHT", -44, -24)

    local divTop = cat:CreateTexture(nil, "ARTWORK", nil, 1)
    divTop:SetTexture(UF_MEDIA .. "ClassicGlassH")
    divTop:SetBlendMode("ADD")
    divTop:SetPoint("TOPLEFT", 20, -50)
    divTop:SetPoint("TOPRIGHT", -20, -50)
    divTop:SetHeight(2)
    divTop:SetVertexColor(0.42, 0.90, 1.0, 0.60)

    local divBot = cat:CreateTexture(nil, "ARTWORK", nil, 1)
    divBot:SetTexture(UF_MEDIA .. "ClassicGlassH")
    divBot:SetBlendMode("ADD")
    divBot:SetPoint("TOPLEFT", 20, -146)
    divBot:SetPoint("TOPRIGHT", -20, -146)
    divBot:SetHeight(2)
    divBot:SetVertexColor(0.94, 0.78, 0.38, 0.55)

    local divGem = cat:CreateTexture(nil, "OVERLAY", nil, 2)
    H.AtlasTex(divGem, "Diamond")
    divGem:SetSize(14, 15)
    divGem:SetPoint("CENTER", divBot, "CENTER", 0, 0)

    -- Nível 1: Busca + Zona + Origens
    local sb = CreateFrame("EditBox", nil, cat)
    sb:SetSize(458, 34)
    sb:SetPoint("TOPLEFT", 26, -61)
    sb:SetAutoFocus(false)
    sb:SetFont(F.B, 13, "")
    sb:SetTextColor(1, 0.97, 0.90)
    sb:SetTextInsets(34, 14, 0, 0)
    local sbSkin = H.Skin(sb, "Search", 34 / 75, "BACKGROUND", 1)
    sbSkin:SetColor(0.75, 0.90, 1.0, 0.95)
    local sbSheen = sb:CreateTexture(nil, "BORDER", nil, 1)
    sbSheen:SetTexture(UF_MEDIA .. "ClassicGlassH")
    sbSheen:SetBlendMode("ADD")
    sbSheen:SetPoint("TOPLEFT", 14, -2)
    sbSheen:SetPoint("TOPRIGHT", -14, -2)
    sbSheen:SetHeight(12)
    sbSheen:SetVertexColor(0.45, 0.88, 1.0, 0.16)
    local glass = sb:CreateTexture(nil, "OVERLAY")
    glass:SetSize(14, 14)
    glass:SetPoint("LEFT", 12, 0)
    H.SkillIconTex(glass, "crystal")
    glass:SetVertexColor(C.GOLD_HI[1], C.GOLD_HI[2], C.GOLD_HI[3], 0.92)
    local ph = H.Txt(sb, F.B, 12, C.MUTED)
    ph:SetPoint("LEFT", 34, 0)
    ph:SetText("Buscar equipamento, chefe, zona ou receita...")
    sb:SetScript("OnTextChanged", function(self)
        local txt = self:GetText() or ""
        ph:SetShown(txt == "")
        U.query = txt
        U.offset = 0
        U.searchDirty = true
    end)
    sb:SetScript("OnEditFocusGained", function()
        sbSkin:SetColor(0.55, 0.95, 1.0, 1.0)
        sbSheen:SetVertexColor(0.45, 0.92, 1.0, 0.35)
    end)
    sb:SetScript("OnEditFocusLost", function()
        sbSkin:SetColor(0.75, 0.90, 1.0, 0.95)
        sbSheen:SetVertexColor(0.45, 0.88, 1.0, 0.16)
    end)
    sb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    U.searchBox = sb

    local zBtn = H.Pill(cat, 168, 32, "Todo o Mundo", 12, C.CREAM, "PillN")
    zBtn:SetPoint("LEFT", sb, "RIGHT", 10, 0)
    zBtn:SetScript("OnClick", function()
        PlayClick()
        U.zoneOnly = not U.zoneOnly
        U.offset = 0
        M:Refresh()
    end)
    U.zoneBtn = zBtn

    U.btns.origin = {}
    for i, d in ipairs(ORIGIN_FILTERS) do
        local b = H.Pill(cat, 90, 30, d.text, 11.5, C.TEXT_HI, "PillN")
        b.val = d.key
        b:SetScript("OnClick", function()
            PlayClick()
            U.origin = b.val
            U.offset = 0
            M:Refresh()
        end)
        U.btns.origin[i] = b
    end

    -- Árvore de categorias (substitui os cartões de categoria e a linha de peças)
    BuildCategoryTree(cat, F)

    -- Nível 3B: Nível + Raridade
    local lvlLbl = H.Txt(cat, F.CB, 11.5, C.GOLD_HI)
    lvlLbl:SetPoint("TOPLEFT", 26, -112)
    lvlLbl:SetText("NÍVEL:")

    U.btns.level = {}
    for i, d in ipairs(LEVEL_FILTERS) do
        local b = H.Pill(cat, 64, 26, d.text, 11.5, C.TEXT_HI, "PillN")
        b.val = d.key
        local sw = b.label:GetStringWidth()
        if not sw or sw <= 0 then sw = 40 end
        b.baseW = max(46, floor(sw + 20))
        b:SetScript("OnClick", function()
            PlayClick()
            U.level = b.val
            U.offset = 0
            M:Refresh()
        end)
        U.btns.level[i] = b
    end

    U.qualLabel = H.Txt(cat, F.CB, 11.5, C.GOLD_HI, "RIGHT")
    U.qualLabel:SetText("RARIDADE:")

    U.btns.qual = {}
    for i, d in ipairs(QUALITY_FILTERS) do
        local b = H.Pill(cat, 84, 26, d.text, 11.5, d.col, "PillN")
        b.val = d.q
        b.col = d.col
        b.gem = b:CreateTexture(nil, "OVERLAY")
        b.gem:SetSize(13, 15)
        b.gem:SetPoint("LEFT", 9, 0)
        H.AtlasTex(b.gem, d.gem)
        if d.tint then b.gem:SetVertexColor(d.tint[1], d.tint[2], d.tint[3]) end
        b.label:ClearAllPoints()
        b.label:SetPoint("LEFT", b.gem, "RIGHT", 5, 0)
        local sw = b.label:GetStringWidth()
        if not sw or sw <= 0 then sw = 48 end
        b.baseW = max(72, floor(sw + 34))
        b:SetScript("OnClick", function()
            PlayClick()
            U.minQuality = b.val
            U.offset = 0
            M:Refresh()
        end)
        U.btns.qual[i] = b
    end

    -- Grade de Cartas (pool de 12 Cards Azaath)
    for i = 1, MAX_CARDS do
        U.cards[i] = CreateItemCard(cat, F)
    end

    U.emptyList = H.Txt(cat, F.C, 18, C.MUTED, "CENTER")
    U.emptyList:SetPoint("CENTER", 0, -100)
    U.emptyList:SetWidth(600)
    U.emptyList:SetWordWrap(true)
    U.emptyList:SetText("Nenhuma relíquia encontrada com estes filtros.")
    U.emptyList:Hide()

    U.scrollTrack = cat:CreateTexture(nil, "BORDER")
    U.scrollTrack:SetColorTexture(1, 1, 1, 0.08)
    U.scrollThumb = cat:CreateTexture(nil, "ARTWORK")
    U.scrollThumb:SetColorTexture(C.CYAN[1], C.CYAN[2], C.CYAN[3], 0.90)
    U.scrollThumb:SetWidth(5)

    cat:EnableMouseWheel(true)
    cat:SetScript("OnMouseWheel", function(_, delta)
        local step = U.cols or 3
        U.offset = max(0, U.offset - delta * step)
        PaintCards()
    end)
end

local function BuildTryOnStage(art)
    local F = U.fonts
    local st = CreateFrame("Frame", nil, art)
    st:SetPoint("TOPLEFT", art, "TOPLEFT", 994, -104)
    st:SetSize(392, 950)
    st:SetFrameLevel(art:GetFrameLevel() + 2)
    st:Hide()
    U.tryOnStage = st

    local stBg = st:CreateTexture(nil, "BORDER", nil, 0)
    stBg:SetPoint("TOPLEFT", 4, -4)
    stBg:SetPoint("BOTTOMRIGHT", -4, 4)
    stBg:SetTexture(SHEET_MEDIA .. "DropCodexOuro")
    stBg:SetTexCoord(40 / 512, 472 / 512, 324 / 1024, 843 / 1024)
    H.Skin(st, "DropPanel", 0.62, "BORDER", 1):SetCenterAlpha(0)

    local hdr = H.Pill(st, 240, 30, "PROVADOR 3D  ·  AO VIVO", 11.5, C.CYAN, "PillA")
    hdr:EnableMouse(false)
    hdr:SetPoint("TOP", 0, -14)

    st.itemSub = H.Txt(st, F.CB, 12.5, C.GOLD_HI, "CENTER")
    st.itemSub:SetPoint("TOP", hdr, "BOTTOM", 0, -8)
    st.itemSub:SetWidth(360)

    st.aura = st:CreateTexture(nil, "BACKGROUND", nil, 1)
    st.aura:SetTexture(MEDIA_ROOT .. "Glow")
    st.aura:SetBlendMode("ADD")
    st.aura:SetSize(400, 400)
    st.aura:SetPoint("CENTER", 0, 20)
    st.aura:SetVertexColor(C.CYAN[1], C.CYAN[2], C.CYAN[3], 0.25)
    st.aura:Hide()

    -- CreateFrame("DressUpModel") cria um frame com TryOn nativo (C) em _forever_.
    -- _G.DressUpModel nesse servidor não tem TryOn como método Lua.
    local okM, model = pcall(CreateFrame, "DressUpModel", nil, st)
    if not okM or not model or not model.TryOn then
        if model and model.Hide then pcall(model.Hide, model) end
        okM, model = pcall(CreateFrame, "PlayerModel", nil, st)
    end
    local isGlobalModel = okM and (model == _G.DressUpModel)
    if okM and model then
        model:EnableMouse(true)
        model:EnableMouseWheel(true)
        -- Salva scripts originais do vestiário para restaurar ao fechar o provador
        local origScripts = {}
        if isGlobalModel and model.GetScript then
            for _, ev in ipairs({ "OnMouseDown", "OnMouseUp", "OnUpdate", "OnMouseWheel" }) do
                origScripts[ev] = model:GetScript(ev)
            end
        end
        model:SetScript("OnMouseDown", function(self)
            self.dragX = _G.GetCursorPosition and _G.GetCursorPosition() or nil
        end)
        model:SetScript("OnMouseUp", function(self) self.dragX = nil end)
        model:SetScript("OnUpdate", function(self)
            if not (self.dragX and _G.GetCursorPosition) then return end
            local x = _G.GetCursorPosition()
            U.modelFacing = U.modelFacing + (x - self.dragX) * 0.018
            self.dragX = x
            if self.SetFacing then pcall(self.SetFacing, self, U.modelFacing) end
        end)
        model:SetScript("OnMouseWheel", function(self, delta)
            U.modelZoom = max(0.6, min(1.5, (U.modelZoom or 1.0) - delta * 0.08))
            if self.SetCamDistanceScale then pcall(self.SetCamDistanceScale, self, U.modelZoom) end
        end)
        st.model = model
        st.unitDirty = true
        if isGlobalModel then
            local savedParent = model:GetParent()
            st:HookScript("OnShow", function()
                model:SetParent(st)
                model:ClearAllPoints()
                model:SetSize(370, 680)
                model:SetPoint("TOP", st, "TOP", 0, -90)
                model:SetFrameLevel(st:GetFrameLevel() + 2)
                model:Show()
                st.unitDirty = true
                UpdateTryOn(U.codex and U.codex.entry, U.codex and U.codex.meta)
            end)
            st:HookScript("OnHide", function()
                if model:GetParent() == st then
                    for ev, fn in pairs(origScripts) do model:SetScript(ev, fn) end
                    model:SetParent(savedParent or UIParent)
                    model:ClearAllPoints()
                    model:SetAllPoints()
                end
            end)
        else
            model:SetSize(370, 680)
            model:SetPoint("TOP", st, "TOP", 0, -90)
            model:SetFrameLevel(st:GetFrameLevel() + 2)
            model:Show()
            st:HookScript("OnShow", function()
                model:Show()
                st.unitDirty = true
                UpdateTryOn(U.codex and U.codex.entry, U.codex and U.codex.meta)
            end)
            st:HookScript("OnHide", function()
                model:Hide()
            end)
        end
    end

    st.noEquip = H.Txt(st, F.B, 12, C.MUTED, "CENTER")
    st.noEquip:SetPoint("TOP", st.itemSub, "BOTTOM", 0, -10)
    st.noEquip:SetText("Visualização disponível apenas para armas e armaduras")
    st.noEquip:Hide()

    local cmpPill = H.Pill(st, 356, 26, "", 11, C.TEXT_HI, "PillN")
    cmpPill:EnableMouse(false)
    cmpPill:SetPoint("BOTTOM", 0, 66)
    st.cmpText = cmpPill.label

    local by = 16
    local rotL = H.Pill(st, 38, 36, "<", 14, C.CREAM, "BtnSquare", 0.44)
    rotL:SetPoint("BOTTOMLEFT", 16, by)
    rotL:SetScript("OnClick", function()
        PlayClick()
        U.modelFacing = U.modelFacing - 0.55
        if st.model and st.model.SetFacing then pcall(st.model.SetFacing, st.model, U.modelFacing) end
    end)

    local spinBtn = H.Pill(st, 74, 36, "GIRAR", 11, C.CREAM, "BtnDark", 0.44)
    spinBtn:SetPoint("LEFT", rotL, "RIGHT", 6, 0)
    spinBtn:SetScript("OnClick", function()
        PlayClick()
        U.modelFacing = U.modelFacing + math.pi
        if st.model and st.model.SetFacing then pcall(st.model.SetFacing, st.model, U.modelFacing) end
    end)

    local rotR = H.Pill(st, 38, 36, ">", 14, C.CREAM, "BtnSquare", 0.44)
    rotR:SetPoint("LEFT", spinBtn, "RIGHT", 6, 0)
    rotR:SetScript("OnClick", function()
        PlayClick()
        U.modelFacing = U.modelFacing + 0.55
        if st.model and st.model.SetFacing then pcall(st.model.SetFacing, st.model, U.modelFacing) end
    end)

    local onlyBtn = H.Pill(st, 90, 36, "SÓ PEÇA", 11, C.CREAM, "PillN", 0.44)
    onlyBtn:SetPoint("LEFT", rotR, "RIGHT", 8, 0)
    onlyBtn:SetScript("OnClick", function()
        PlayClick()
        U.onlyPiece = not U.onlyPiece
        UpdateTryOn(U.codex and U.codex.entry, U.codex and U.codex.meta)
    end)
    st.onlyBtn = onlyBtn

    local closeBtn = H.Pill(st, 86, 36, "FECHAR 3D", 10.5, C.GOLD_HI, "BtnDark", 0.44)
    closeBtn:SetPoint("LEFT", onlyBtn, "RIGHT", 6, 0)
    closeBtn:SetScript("OnClick", function()
        PlayClick()
        U.showTryOn = false
        M:Refresh()
    end)
end

local function CreateSourceRow(srcWrap, W0, i, F)
    local sr = CreateFrame("Button", nil, srcWrap)
    sr:SetSize(W0, 68)
    sr:SetPoint("TOPLEFT", 0, -(i - 1) * 74)

    sr.bg = sr:CreateTexture(nil, "BACKGROUND", nil, 0)
    sr.bg:SetPoint("TOPLEFT", 3, -3)
    sr.bg:SetPoint("BOTTOMRIGHT", -3, 3)
    Azaath.Gradient(sr.bg, "VERTICAL", 0.024, 0.054, 0.118, 0.94, 0.048, 0.104, 0.205, 0.94)

    sr.sheen = sr:CreateTexture(nil, "BACKGROUND", nil, 1)
    sr.sheen:SetTexture(UF_MEDIA .. "ClassicGlassH")
    sr.sheen:SetBlendMode("ADD")
    sr.sheen:SetPoint("TOPLEFT", 8, -4)
    sr.sheen:SetPoint("TOPRIGHT", -8, -4)
    sr.sheen:SetHeight(16)
    sr.sheen:SetVertexColor(0.50, 0.90, 1.0, 0.14)

    sr.skin = H.Skin(sr, "DropWide", 0.34, "BORDER", 1)
    sr.skin:SetCenterAlpha(0)
    sr.skin:SetColor(1, 1, 1, 0.96)

    sr.activeSkin = H.Skin(sr, "WideA", 0.44, "BORDER", 2)
    sr.activeSkin:SetCenterAlpha(0.10)
    sr.activeSkin:SetAlpha(0)

    sr.med = H.CircleIcon(sr, 24, 38, "bezel")
    sr.med:SetPoint("LEFT", 12, 0)
    sr.icon = sr.med.icon

    sr.name = H.Txt(sr, F.CB, 13, C.CREAM)
    sr.name:SetPoint("TOPLEFT", 58, -14)
    sr.name:SetWidth(W0 - 134)

    sr.loc = H.Txt(sr, F.B, 11.5, C.TEXT_HI)
    sr.loc:SetPoint("BOTTOMLEFT", 58, 13)
    sr.loc:SetWidth(W0 - 210)

    local pf = CreateFrame("Frame", nil, sr)
    pf:SetSize(52, 20)
    pf:SetPoint("TOPRIGHT", -12, -8)
    sr.pctPill = H.Skin(pf, "PillN", 20 / 44, "BACKGROUND", 2)
    sr.pctText = H.Txt(pf, F.CB, 10.5, C.GOLD_HI, "CENTER")
    sr.pctText:SetPoint("CENTER")

    local mapBtn = H.Pill(sr, 122, 22, "MARCAR NO MAPA", 9.5, { 1, 1, 1 }, "PillA")
    mapBtn:SetPoint("BOTTOMRIGHT", -12, 10)
    mapBtn.keepBaseColor = true
    mapBtn.accent = C.CYAN
    sr.mapBtn = mapBtn

    sr.bottomBeam = sr:CreateTexture(nil, "OVERLAY", nil, 2)
    sr.bottomBeam:SetTexture(UF_MEDIA .. "ClassicGlassH")
    sr.bottomBeam:SetBlendMode("ADD")
    sr.bottomBeam:SetHeight(2.5)
    sr.bottomBeam:SetWidth(120)
    sr.bottomBeam:SetPoint("CENTER", sr, "BOTTOM", 0, 1)
    sr.bottomBeam:SetVertexColor(C.CYAN[1], C.CYAN[2], C.CYAN[3], 1)
    sr.bottomBeam:SetAlpha(0)

    RegHover(sr, "source")
    sr:SetScript("OnEnter", function(self) self.isHovered = true end)
    sr:SetScript("OnLeave", function(self) self.isHovered = false end)
    sr:Hide()
    return sr
end

local function BuildCodexPanel(art)
    local F = U.fonts
    local AX, AY, AW, AH = 1400, -52, 486, 1002
    local scX = AW / 512

    local codex = CreateFrame("Frame", nil, art)
    codex:SetPoint("TOPLEFT", art, "TOPLEFT", AX, AY)
    codex:SetSize(AW, AH)
    codex:SetFrameLevel(art:GetFrameLevel() + 2)

    -- Moldura completa pintada DropCodexOuro (512x1024): coroa + placa bronze, corpo limpo e borda inferior fechada
    local topSrcH = 324
    local topDstH = topSrcH * scX
    local botSrcY = 976
    local botSrcH = 1024 - botSrcY
    local botDstH = botSrcH * scX
    local midH = AH - topDstH - botDstH + 4

    local tTop = codex:CreateTexture(nil, "BORDER", nil, 1)
    tTop:SetTexture(SHEET_MEDIA .. "DropCodexOuro")
    tTop:SetTexCoord(0, 1, 0, topSrcH / 1024)
    tTop:SetPoint("TOPLEFT")
    tTop:SetSize(AW, topDstH)

    local tMid = codex:CreateTexture(nil, "BORDER", nil, 1)
    tMid:SetTexture(SHEET_MEDIA .. "DropCodexOuro")
    tMid:SetTexCoord(0, 1, topSrcH / 1024, 843 / 1024)
    tMid:SetPoint("TOPLEFT", 0, -topDstH + 2)
    tMid:SetSize(AW, midH)

    local tBot = codex:CreateTexture(nil, "BORDER", nil, 1)
    tBot:SetTexture(SHEET_MEDIA .. "DropCodexOuro")
    tBot:SetTexCoord(0, 1, botSrcY / 1024, 1)
    tBot:SetPoint("BOTTOMLEFT")
    tBot:SetSize(AW, botDstH)

    local empty = H.Txt(codex, F.C, 16, C.MUTED, "CENTER")
    empty:SetPoint("CENTER", 0, 20)
    empty:SetWidth(AW - 80)
    empty:SetWordWrap(true)
    empty:SetText("Selecione um item no Relicário para inspecionar.")

    local body = CreateFrame("Frame", nil, codex)
    body:SetAllPoints()
    body:SetFrameLevel(codex:GetFrameLevel() + 3)

    local d = { empty = empty, body = body }
    U.codex = d

    local plaqueBox = CreateFrame("Frame", nil, body)
    plaqueBox:SetSize(306, 26)
    plaqueBox:SetPoint("TOP", codex, "TOP", 0, -246)
    d.plaque = H.Txt(plaqueBox, F.CB, 11.5, C.GOLD_HI, "CENTER")
    d.plaque:SetPoint("CENTER")
    d.plaque:SetWidth(284)

    d.name = H.Txt(body, F.CB, 18, C.CREAM, "CENTER")
    d.name:SetPoint("TOP", codex, "TOP", 0, -290)
    d.name:SetWidth(AW - 72)
    d.name:SetWordWrap(true)
    if d.name.SetMaxLines then d.name:SetMaxLines(2) end

    -- Medalhão limpo do item escolhido (sem textura rúnica nem rotação atrás)
    local rcy = -362
    local medBtn = CreateFrame("Button", nil, body)
    medBtn:SetSize(112, 112)
    medBtn:SetPoint("CENTER", codex, "TOP", 0, rcy)
    d.medallion = H.CircleIcon(medBtn, 84, 112, "bezel", false)
    d.medallion:SetPoint("CENTER")

    -- SALVAR / SALVO: guarda o item em "Itens salvos" (topo da árvore de categorias)
    d.favBtn = H.Pill(body, 96, 28, "SALVAR", 11, C.GOLD_HI, "PillN")
    d.favBtn:SetPoint("LEFT", medBtn, "RIGHT", 14, 0)
    d.favBtn.favIcon = d.favBtn:CreateTexture(nil, "OVERLAY", nil, 4)
    d.favBtn.favIcon:SetSize(14, 14)
    d.favBtn.favIcon:SetPoint("LEFT", 10, 0)
    H.SkillIconTex(d.favBtn.favIcon, "star", 10)
    d.favBtn.label:ClearAllPoints()
    d.favBtn.label:SetPoint("LEFT", d.favBtn.favIcon, "RIGHT", 5, 0)
    d.favBtn:SetScript("OnClick", function(self)
        local idr = Azaath:GetModule("ItemDrops")
        if not (idr and self.itemID) then return end
        PlayClick()
        idr:ToggleFavorite(self.itemID)
        M:Refresh()
    end)
    d.medallion.hoverRing = d.medallion:CreateTexture(nil, "OVERLAY", nil, 3)
    d.medallion.hoverRing:SetTexture(MEDIA_ROOT .. "CastRingEdge")
    d.medallion.hoverRing:SetBlendMode("ADD")
    d.medallion.hoverRing:SetSize(124, 124)
    d.medallion.hoverRing:SetPoint("CENTER")
    d.medallion.hoverRing:SetVertexColor(C.CYAN[1], C.CYAN[2], C.CYAN[3], 1)
    d.medallion.hoverRing:SetAlpha(0)
    d.medallion.baseRingSize = 124

    RegHover(medBtn, "medallion")
    medBtn:SetScript("OnEnter", function(self)
        self.isHovered = true
        if d.entry then ShowItemTooltip(self, d.entry) end
    end)
    medBtn:SetScript("OnLeave", function(self)
        self.isHovered = false
        GameTooltip:Hide()
    end)
    medBtn:SetScript("OnClick", function()
        if d.entry and _G.IsModifiedClick and _G.IsModifiedClick("CHATLINK") then LinkItemToChat(d.entry) end
    end)
    d.medBtn = medBtn

    -- 3 Tags: Raridade, iLvl, Req. Nível
    local tagY = -420
    d.tagQual = H.Pill(body, 96, 25, "", 11, C.CREAM, "PillN"); d.tagQual:EnableMouse(false)
    d.tagIlvl = H.Pill(body, 90, 25, "", 11, C.GOLD_HI, "PillN"); d.tagIlvl:EnableMouse(false)
    d.tagReq  = H.Pill(body, 118, 25, "", 11, C.CYAN, "PillA"); d.tagReq:EnableMouse(false)
    d.tagIlvl:SetPoint("TOP", codex, "TOP", 0, tagY)
    d.tagQual:SetPoint("RIGHT", d.tagIlvl, "LEFT", -8, 0)
    d.tagReq:SetPoint("LEFT", d.tagIlvl, "RIGHT", 8, 0)

    -- Bloco de Atributos
    local X0, W0 = 32, AW - 64
    local stY = -462
    local dia1 = body:CreateTexture(nil, "ARTWORK"); H.AtlasTex(dia1, "Diamond")
    dia1:SetSize(13, 14); dia1:SetPoint("TOPLEFT", X0, stY)
    local stHdr = H.Txt(body, F.CB, 12, C.GOLD_HI)
    stHdr:SetPoint("LEFT", dia1, "RIGHT", 6, 0)
    stHdr:SetText("ATRIBUTOS DA RELÍQUIA")

    d.cmpDelta = H.Txt(body, F.CB, 11.5, C.GREEN, "RIGHT")
    d.cmpDelta:SetPoint("TOPRIGHT", -X0, stY - 1)

    local statBox = CreateFrame("Frame", nil, body)
    statBox:SetSize(W0, 148)
    statBox:SetPoint("TOPLEFT", X0, stY - 20)
    pcall(statBox.SetClipsChildren, statBox, true)
    local sbBg = statBox:CreateTexture(nil, "BACKGROUND", nil, 0)
    sbBg:SetPoint("TOPLEFT", 3, -3)
    sbBg:SetPoint("BOTTOMRIGHT", -3, 3)
    Azaath.Gradient(sbBg, "VERTICAL", 0.020, 0.046, 0.102, 0.94, 0.042, 0.092, 0.185, 0.94)
    local sbSkin = H.Skin(statBox, "DropWide", 0.36, "BORDER", 1)
    sbSkin:SetCenterAlpha(0)
    sbSkin:SetColor(1, 1, 1, 0.96)

    d.statsText = H.Txt(statBox, F.B, 12, C.CREAM)
    d.statsText:SetPoint("TOPLEFT", 18, -14)
    d.statsText:SetPoint("BOTTOMRIGHT", -18, 12)
    d.statsText:SetJustifyV("TOP")
    d.statsText:SetWordWrap(true)
    if d.statsText.SetSpacing then d.statsText:SetSpacing(2.5) end

    -- Seção ONDE DROPAR / OBTER
    local srY = -636
    local dia2 = body:CreateTexture(nil, "ARTWORK"); H.AtlasTex(dia2, "Diamond")
    dia2:SetSize(13, 14); dia2:SetPoint("TOPLEFT", X0, srY)
    local srHdr = H.Txt(body, F.CB, 12, C.CYAN)
    srHdr:SetPoint("LEFT", dia2, "RIGHT", 6, 0)
    srHdr:SetText("ONDE DROPAR / OBTER")

    d.srcCount = H.Txt(body, F.B, 11.5, C.MUTED, "RIGHT")
    d.srcCount:SetPoint("TOPRIGHT", -X0, srY - 1)

    local srcWrap = CreateFrame("Frame", nil, body)
    srcWrap:SetPoint("TOPLEFT", X0, srY - 20)
    srcWrap:SetSize(W0, MAX_SRCS * 74)
    srcWrap:EnableMouseWheel(true)
    srcWrap:SetScript("OnMouseWheel", function(_, delta)
        U.srcOffset = max(0, U.srcOffset - delta)
        UpdateSources(d.entry)
    end)

    for i = 1, MAX_SRCS do
        local sr = CreateSourceRow(srcWrap, W0, i, F)
        sr.mapBtn:SetScript("OnClick", function()
            local s = sr.src
            if s and not (s.map and s.map > 0) and s.key then
                local dg = Azaath:GetModule("SheetDungeons")
                if dg and dg:HasBoss(s.key) then
                    PlayClick()
                    dg:ShowBoss(s.key)
                    return
                end
            end
            if not (s and s.map and s.x and s.y) then return end
            PlayClick()
            local label = (d.entry and ItemName(d.entry, d.meta) or "Drop") .. " — " .. (s.name or "")
            local qn = Azaath:GetModule("QuestNav")
            if qn and qn.SetCustomWaypoint then qn:SetCustomWaypoint(s.map, s.x, s.y, label) end
            local wm = Azaath:GetModule("WorldMap")
            if wm and wm.Open then
                wm:Open()
                if wm.api and wm.api.FocusMapXY then wm.api.FocusMapXY(s.map, s.x, s.y, nil, label) end
            end
        end)
        U.srcs[i] = sr
    end

    -- Botões gêmeos inferiores com gema ciano (DropBtn): PROVADOR 3D | LINK NO CHAT
    local btnH = 44
    local btnY = 24
    local btnW = 204

    local function MakeCodexFooterBtn(pt, ox, labelTxt, txtCol, beamCol)
        local b = CreateFrame("Button", nil, body)
        b:SetSize(btnW, btnH)
        b:SetPoint(pt, codex, pt, ox, btnY)
        b.skin = H.Skin(b, "DropBtn", btnH / 87, "BACKGROUND", 1)
        b.aura = b:CreateTexture(nil, "BACKGROUND", nil, 2)
        b.aura:SetTexture(UF_MEDIA .. "ClassicGlassH")
        b.aura:SetBlendMode("ADD")
        b.aura:SetPoint("TOPLEFT", 18, -4)
        b.aura:SetPoint("BOTTOMRIGHT", -18, 4)
        b.aura:SetVertexColor(beamCol[1], beamCol[2], beamCol[3], 1)
        b.aura:SetAlpha(0)
        b.beam = b:CreateTexture(nil, "OVERLAY", nil, 2)
        b.beam:SetTexture(UF_MEDIA .. "ClassicGlassH")
        b.beam:SetBlendMode("ADD")
        b.beam:SetHeight(2.5)
        b.beam:SetWidth(btnW * 0.4)
        b.beam:SetPoint("CENTER", b, "BOTTOM", 0, 3)
        b.beam:SetVertexColor(beamCol[1], beamCol[2], beamCol[3], 1)
        b.beam:SetAlpha(0)
        b.star = b:CreateTexture(nil, "OVERLAY", nil, 3)
        b.star:SetTexture(MEDIA_ROOT .. "Star")
        b.star:SetBlendMode("ADD")
        b.star:SetSize(14, 14)
        b.star:SetPoint("CENTER", b.beam, "CENTER", 0, 0)
        b.star:SetVertexColor(min(1, beamCol[1] + 0.2), min(1, beamCol[2] + 0.2), min(1, beamCol[3] + 0.2), 1)
        b.star:SetAlpha(0)
        b.label = H.Txt(b, F.CB, 11.5, txtCol, "CENTER")
        b.label:SetPoint("CENTER", 3, -5)
        b.label:SetText(labelTxt)
        b.beamCol = beamCol
        RegHover(b, "codexBtn")
        b:SetScript("OnEnter", function(self) self.isHovered = true end)
        b:SetScript("OnLeave", function(self) self.isHovered = false end)
        return b
    end

    local tryBtn = MakeCodexFooterBtn("BOTTOMLEFT", 26, "PROVADOR 3D", C.GOLD_HI, C.GOLD)
    d.tryOnBtnText = tryBtn.label
    tryBtn:SetScript("OnClick", function()
        PlayClick()
        U.showTryOn = not U.showTryOn
        if U.showTryOn and U.tryOnStage then U.tryOnStage.unitDirty = true end
        M:Refresh()
    end)

    local linkBtn = MakeCodexFooterBtn("BOTTOMRIGHT", -26, "LINK NO CHAT", { 0.88, 0.96, 1.0 }, C.CYAN)
    linkBtn:SetScript("OnClick", function()
        if not d.entry then return end
        PlayClick()
        LinkItemToChat(d.entry)
    end)
end

--------------------------------------------------------------------------------
-- Motor de Animação Suave de Hover
--------------------------------------------------------------------------------
local function StepWidgetAnim(w, elapsed, clockT)
    local t = Damp(w.hoverT or 0, w.isHovered and 1 or 0, 0.0005, elapsed)
    if abs(t - (w.isHovered and 1 or 0)) < 0.002 then t = w.isHovered and 1 or 0 end
    w.hoverT = t
    w.forceAnimDirty = false

    local k = w.hoverKind
    if k == "item" then
        local sel = w.sel and true or false
        local u = max(sel and 1 or 0, t * 0.78)
        w.activeSkin:SetAlpha(sel and 1 or (t * 0.76))
        w.sheen:SetAlpha(0.14 + 0.24 * max(sel and 0.65 or 0, t))
        w.hoverGlow:SetAlpha(t * 0.24)
        w.bottomBeam:SetAlpha(max(sel and 0.88 or 0, t * 0.92))
        w.bottomBeam:SetWidth(max(44, (w:GetWidth() or 380) * (0.28 + 0.64 * u)))
        w.bottomStar:SetAlpha(max(sel and 0.75 or 0, t * 0.95))
        local iz = w.med.baseIconSize * (1 + 0.07 * t)
        local rz = w.med.baseRimSize * (1 + 0.07 * t)
        w.med.icon:SetSize(iz, iz)
        w.med.rim:SetSize(rz, rz)
        w.med.ring:SetSize(rz, rz)
        if w.med.wisps then
            local wa = sel and 0.42 or (t * 0.48)
            w.med.wisps:SetShown(wa > 0.02)
            if wa > 0.02 then
                w.med.wisps:SetAlpha(wa)
                if w.med.wisps.SetRotation then pcall(w.med.wisps.SetRotation, w.med.wisps, clockT * 0.55) end
            end
        end
        if w.isHovered or sel then return true end
        return t > 0
    elseif k == "armor" then
        local on = w.isActive and true or false
        local u = max(on and 1 or 0, t * 0.75)
        w.activeSkin:SetAlpha(on and 1 or (t * 0.76))
        w.sheen:SetAlpha(on and 0.38 or (0.16 + 0.24 * t))
        w.underBeam:SetAlpha(max(on and 0.92 or 0, t * 0.88))
        w.underBeam:SetWidth(max(24, (w:GetWidth() or 92) * (0.34 + 0.54 * u)))
        w.underStar:SetAlpha(max(on and 0.80 or 0, t * 0.90))
        w.med:ClearAllPoints()
        w.med:SetPoint("TOP", 0, -6 + 2.5 * t)
        local iz = w.med.baseIconSize * (1 + 0.09 * t)
        local rz = w.med.baseRimSize * (1 + 0.07 * t)
        w.med.icon:SetSize(iz, iz)
        w.med.rim:SetSize(rz, rz)
        w.med.ring:SetSize(rz, rz)
        if on then
            w.txt:SetTextColor(1, 1, 1)
        else
            local br = t * 0.25
            w.txt:SetTextColor(min(1, C.CREAM[1] + br), min(1, C.CREAM[2] + br), min(1, C.CREAM[3] + br))
        end
        return t > 0
    elseif k == "pill" then
        local on = w.isActive and true or false
        local bc = w.accent or C.CYAN
        local u = max(on and 1 or 0, t * 0.85)
        w.hoverAura:SetAlpha(on and (0.22 + 0.16 * t) or (t * 0.34))
        w.bottomBeam:SetAlpha(max(on and 0.85 or 0, t * 0.88))
        w.bottomBeam:SetWidth(max(16, (w:GetWidth() or 80) * (0.26 + 0.62 * u)))
        w.star:SetAlpha(t * 0.88)
        if on then
            if not w.keepBaseColor then w.label:SetTextColor(1, 1, 1) end
        elseif not w.keepBaseColor then
            local rc = w.baseCol or C.TEXT_HI
            w.label:SetTextColor(
                rc[1] + (min(1, bc[1] + 0.15) - rc[1]) * t,
                rc[2] + (min(1, bc[2] + 0.15) - rc[2]) * t,
                rc[3] + (min(1, bc[3] + 0.15) - rc[3]) * t
            )
        end
        return t > 0
    elseif k == "source" then
        local baseA = w.hasMap and 0.65 or 0
        w.activeSkin:SetAlpha(max(baseA, t * 0.88))
        w.sheen:SetAlpha(0.14 + 0.24 * t)
        w.bottomBeam:SetAlpha(t * 0.85)
        w.bottomBeam:SetWidth(max(40, (w:GetWidth() or 430) * (0.25 + 0.65 * t)))
        local iz = w.med.baseIconSize * (1 + 0.08 * t)
        w.med.icon:SetSize(iz, iz)
        return t > 0
    elseif k == "medallion" then
        local m = U.codex and U.codex.medallion
        if m then
            local iz = m.baseIconSize * (1 + 0.05 * t)
            local rz = m.baseRimSize * (1 + 0.05 * t)
            local hr = m.baseRingSize * (1 + 0.05 * t)
            m.icon:SetSize(iz, iz)
            m.rim:SetSize(rz, rz)
            m.ring:SetSize(rz, rz)
            m.hoverRing:SetSize(hr, hr)
            m.hoverRing:SetAlpha(t * 0.72)
        end
        return t > 0
    elseif k == "codexBtn" then
        w.aura:SetAlpha(t * 0.30)
        w.beam:SetAlpha(t * 0.90)
        w.beam:SetWidth(max(30, (w:GetWidth() or 200) * (0.35 + 0.55 * t)))
        w.star:SetAlpha(t * 0.95)
        return t > 0
    end
    return false
end

--------------------------------------------------------------------------------
-- Ponto de Entrada (BuildPage)
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Compartilhado com a aba Masmorras (SheetDungeons.lua): mesmas peças visuais e utilitários
--------------------------------------------------------------------------------
M.H, M.C, M.QUALITY_COLORS = H, C, QUALITY_COLORS
M.GetItemMeta, M.PlayClick, M.ItemName, M.LinkItemToChat = GetItemMeta, PlayClick, ItemName, LinkItemToChat
function M:GetFonts() return U.fonts end

function M:BuildPage(parent, cw, ch)
    if not parent or parent.drops then return end
    local media = Azaath.media
    U.page = parent
    parent.drops = true

    U.fonts = {
        C  = media.fontCinzel or media.fontTitleB,
        CB = media.fontTitleB,
        B  = media.fontBody or media.font or GameFontNormal:GetFont(),
    }

    local root = parent:GetParent() and parent:GetParent():GetParent() or UIParent
    local art = CreateFrame("Frame", nil, parent)
    art:SetSize(ART_W, ART_H)
    art:SetPoint("CENTER", root, "CENTER", 0, 0)
    art:SetFrameLevel(parent:GetFrameLevel())

    local function Fit()
        local w, h = root:GetWidth(), root:GetHeight()
        if not (w and h and w > 0 and h > 0) then w, h = UIParent:GetWidth(), UIParent:GetHeight() end
        art:SetScale(max(w / ART_W, h / ART_H))
    end
    Fit()
    parent:HookScript("OnShow", function()
        Fit()
        for _, w in ipairs(U.animWidgets) do w.forceAnimDirty = true end
        if U.showTryOn and U.tryOnStage then U.tryOnStage.unitDirty = true end
    end)

    local bg = art:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetTexture(SHEET_MEDIA .. "ProfessionsBG")
    bg:SetTexCoord(0, ART_W / 2048, 0, ART_H / 2048)
    bg:SetAllPoints(art)

    local bgVeil = art:CreateTexture(nil, "BACKGROUND", nil, 0)
    bgVeil:SetAllPoints(art)
    bgVeil:SetColorTexture(0.01, 0.024, 0.042, 0.24)

    BuildCatalogPanel(art)
    BuildTryOnStage(art)
    BuildCodexPanel(art)

    local ev = CreateFrame("Frame", nil, parent)
    local pendingRefresh, pendingPaint, wait, searchWait, clockT = false, false, 0, 0, 0
    local refreshedIDs = {}
    pcall(ev.RegisterEvent, ev, "GET_ITEM_INFO_RECEIVED")
    pcall(ev.RegisterEvent, ev, "ITEM_DATA_LOAD_RESULT")
    ev:SetScript("OnEvent", function(_, _, itemID, success)
        if itemID and success == false then
            local idr = Azaath:GetModule("ItemDrops")
            if idr and idr:MarkMissing(itemID, true) then pendingRefresh = true end
            return
        end
        if not parent:IsShown() then return end
        if itemID and U.visibleIDs and U.visibleIDs[itemID] and success ~= false and not refreshedIDs[itemID] then
            refreshedIDs[itemID] = true
            pendingPaint = true
        end
    end)
    ev:SetScript("OnUpdate", function(_, elapsed)
        if not parent:IsShown() then return end
        elapsed = min(elapsed or 0, 0.05)
        clockT = clockT + elapsed

        for _, w in ipairs(U.animWidgets) do
            if w:IsShown() and (w.isHovered or (w.hoverT or 0) > 0 or w.forceAnimDirty or w.sel) then
                StepWidgetAnim(w, elapsed, clockT)
            end
        end

        if U.searchDirty then
            searchWait = searchWait + elapsed
            if searchWait >= 0.14 then
                searchWait = 0
                U.searchDirty = false
                M:Refresh()
            end
        end
        if pendingRefresh or pendingPaint then
            wait = wait + elapsed
            if wait >= 0.25 then
                local needFull = pendingRefresh
                wait, pendingRefresh, pendingPaint = 0, false, false
                if needFull then M:Refresh() else PaintCards() end
            end
        end
    end)
end
