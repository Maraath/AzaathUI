--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Sheet/Sanctuary.lua
    Ficha do personagem: conjuntos, títulos, medalhões de equipamento e página do Santuário.
    Símbolos comuns vêm de Azaath.SheetUI (Modules/Sheet/Core.lua).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.SheetUI
local _G, abs, cos, floor = _G, math.abs, math.cos, math.floor
local format, ipairs, max, min = string.format, ipairs, math.max, math.min
local pairs, pcall, random, select = pairs, pcall, math.random, select
local sin, sqrt, type = math.sin, math.sqrt, type
local ApplyCircleMask, BuildAttributes, CARD_COL, CARD_H = U.ApplyCircleMask, U.BuildAttributes, U.CARD_COL, U.CARD_H
local CARD_TEX_H, CARD_TEX_W, CARD_W, CONSTELLATION = U.CARD_TEX_H, U.CARD_TEX_W, U.CARD_W, U.CONSTELLATION
local CX, CY, Call, CardText = U.CX, U.CY, U.Call, U.CardText
local Char, CreateText, FS, INV_MEDIA = U.Char, U.CreateText, U.FS, U.INV_MEDIA
local LEFT_SLOTS, M, MEDIA_ROOT, MakeButton = U.LEFT_SLOTS, U.M, U.MEDIA_ROOT, U.MakeButton
local NewList, Num, PlaceTabHighlight, RIGHT_SLOTS = U.NewList, U.Num, U.PlaceTabHighlight, U.RIGHT_SLOTS
local SHEET_MEDIA, SLOT_NAMES, SUBTABS, Show = U.SHEET_MEDIA, U.SLOT_NAMES, U.SUBTABS, U.Show
local TAB_CX, TAB_HIT, UF_MEDIA, UpdateAttributes = U.TAB_CX, U.TAB_HIT, U.UF_MEDIA, U.UpdateAttributes
local UpdateVitals, WEAPON_SLOTS, card, selected = U.UpdateVitals, U.WEAPON_SLOTS, U.card, U.selected
local subPages = U.subPages

--------------------------------------------------------------------------------
-- Conjuntos de Equipamento & Títulos
--------------------------------------------------------------------------------
local ES = _G.C_EquipmentSet

local function SetIDs()
    local ids = ES and Call(ES.GetEquipmentSetIDs)
    return type(ids) == "table" and ids or {}
end

local function CollectSets()
    local list = {}
    for _, id in ipairs(SetIDs()) do
        local name, icon, _, isEquipped, numItems, numEquipped, _, numLost = Call(ES.GetEquipmentSetInfo, id)
        if name then
            local sid = id
            list[#list + 1] = {
                name = name, icon = icon,
                value = isEquipped and "|cff34d399EQUIPADO|r"
                    or format("%d / %d", Num(numEquipped, 0), Num(numItems, 0)) .. ((Num(numLost, 0) > 0) and " |cffff6050(ausente)|r" or ""),
                selected = selected.sets == sid,
                onClick = function() selected.sets = sid; selected.deleteSet = nil; U.dirty = true end,
            }
        end
    end
    return list
end

local function BuildSets(page, x, w, h)
    local c, media = Azaath.colors, Azaath.media
    local sets = {}
    page.sets = sets
    sets.list = NewList(page, x, 0, w, h - 84, "Nenhum conjunto de arsenal registrado.\nEquipe seus itens e salve um novo conjunto abaixo.", 120)

    local inputWrap = CreateFrame("Frame", nil, page)
    inputWrap:SetSize(w - 134, 28)
    inputWrap:SetPoint("TOPLEFT", page, "TOPLEFT", x, -(h - 74))

    local inputLine = inputWrap:CreateTexture(nil, "ARTWORK")
    inputLine:SetTexture(UF_MEDIA .. "ClassicGlassH")
    inputLine:SetBlendMode("ADD")
    inputLine:SetPoint("BOTTOMLEFT", inputWrap, "BOTTOMLEFT", 0, 0)
    inputLine:SetPoint("BOTTOMRIGHT", inputWrap, "BOTTOMRIGHT", 0, 0)
    inputLine:SetHeight(2)
    inputLine:SetVertexColor(0.45, 0.85, 1.0, 0.65)

    sets.input = CreateFrame("EditBox", nil, inputWrap)
    sets.input:SetAllPoints(inputWrap)
    sets.input:SetAutoFocus(false)
    sets.input:SetFont(media.fontBold, 13, "OUTLINE")
    sets.input:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    sets.input:SetTextInsets(8, 8, 0, 0)
    sets.input:SetMaxLetters(32)

    local ph = CreateText(sets.input, media.font, 12, c.dim)
    ph:SetPoint("LEFT", sets.input, "LEFT", 8, 0)
    ph:SetText("Digite o nome do novo conjunto...")
    sets.input:SetScript("OnTextChanged", function(self) Show(ph, (self:GetText() or "") == "") end)
    sets.input:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)

    local function Create()
        local name = (sets.input:GetText() or ""):gsub("^%s+", ""):gsub("%s+$", "")
        if name == "" or not ES then return end
        local icon = GetInventoryItemTexture("player", 16) or 134400
        Call(ES.CreateEquipmentSet, name, icon)
        sets.input:SetText("")
        sets.input:ClearFocus()
        U.dirty = true
    end
    sets.input:SetScript("OnEnterPressed", Create)
    local create = MakeButton(page, "Criar", 122, Create)
    create:SetPoint("LEFT", inputWrap, "RIGHT", 12, 0)

    local btnW = floor((w - 16) / 3)
    sets.equip = MakeButton(page, "Equipar", btnW, function()
        if selected.sets and not InCombatLockdown() then Call(ES.UseEquipmentSet, selected.sets) end
    end)
    sets.equip:SetPoint("TOPLEFT", page, "TOPLEFT", x, -(h - 36))

    sets.save = MakeButton(page, "Salvar", btnW, function()
        if selected.sets then Call(ES.SaveEquipmentSet, selected.sets); U.dirty = true end
    end)
    sets.save:SetPoint("LEFT", sets.equip, "RIGHT", 8, 0)

    sets.delete = MakeButton(page, "Excluir", btnW, function()
        if not selected.sets then return end
        if selected.deleteSet == selected.sets then
            Call(ES.DeleteEquipmentSet, selected.sets)
            selected.sets, selected.deleteSet = nil, nil
        else
            selected.deleteSet = selected.sets
        end
        U.dirty = true
    end)
    sets.delete:SetPoint("LEFT", sets.save, "RIGHT", 8, 0)
end

local function UpdateSets()
    local sets = subPages.sets.sets
    local entries = CollectSets()
    sets.list:SetEntries(entries)
    local has = selected.sets ~= nil
    sets.equip:SetEnabledLook(has and not InCombatLockdown())
    sets.save:SetEnabledLook(has)
    sets.delete:SetEnabledLook(has)
    sets.delete.text:SetText(Azaath.Tracked(selected.deleteSet and selected.deleteSet == selected.sets and "Confirmar!" or "Excluir"))
end

local function CollectTitles()
    local list = {}
    local currentTitle = Call(_G.GetCurrentTitle) or -1
    list[1] = { name = "Sem título ativo", selected = currentTitle <= 0,
                onClick = function() Call(_G.SetCurrentTitle, -1); U.dirty = true end }
    for i = 1, Call(_G.GetNumTitles) or 0 do
        if Call(_G.IsTitleKnown, i) then
            local name = Call(_G.GetTitleName, i)
            if name then
                local id = i
                name = name:gsub("^%s+", ""):gsub("%s+$", "")
                list[#list + 1] = { name = name, selected = currentTitle == i,
                                    onClick = function() Call(_G.SetCurrentTitle, id); U.dirty = true end }
            end
        end
    end
    if #list == 1 then list[2] = { name = "Nenhum título conquistado ainda.", dim = true } end
    return list
end

--------------------------------------------------------------------------------
-- Nodos Circulares Flutuantes de Equipamento 2026 (Zero Cards Quadrados!)
--------------------------------------------------------------------------------
local function SelectSub(key)
    U.currentSub = key
    M.db.sub = key
    for _, b in ipairs(U.subButtons) do
        local active = b.key == key
        Show(subPages[b.key], active)
        local col = active and CARD_COL.tabOn or CARD_COL.tabOff
        b.text:SetTextColor(col[1], col[2], col[3])
        if active then PlaceTabHighlight(b.index) end
    end
    if card.bg then
        if key == "attributes" then
            card.bg:SetTexture(SHEET_MEDIA .. "AttrCard")
            card.bg:SetTexCoord(0, CARD_W / CARD_TEX_W, 0, CARD_H / CARD_TEX_H)
        else
            card.bg:SetTexture(SHEET_MEDIA .. "AttrCardEmpty")
            card.bg:SetTexCoord(0, 1, 0, 1)
        end
    end
    U.dirty = true
end

local function BuildCircularOrbSlot(page, b, slotName, side, textMaxW, fontK)
    local c, media = Azaath.colors, Azaath.media
    fontK = fontK or 1
    local sz = b:GetWidth()

    -- Remove 100% do backdrop quadrado antigo
    b:SetBackdrop(nil)
    -- o UpdateSlot do Character reexibe o degradê quadrado: some de vez via alpha
    if b.tint then b.tint:Hide(); b.tint:SetAlpha(0) end
    if b.SetBackdropBorderColor then pcall(b.SetBackdropBorderColor, b, 0, 0, 0, 0) end
    if b.SetBackdropColor then pcall(b.SetBackdropColor, b, 0, 0, 0, 0) end
    if b.level then b.level:SetAlpha(0) end
    if b.duraBar then b.duraBar:SetAlpha(0) end
    if b.broken then b.broken:SetAlpha(0) end
    if b.gemPips then for i = 1, 4 do b.gemPips[i]:SetAlpha(0) end end
    if b.enchantPip then b.enchantPip:SetAlpha(0) end

    -- 1. Aura de raridade (verde ou acima): halo macio + línguas de energia girando
    local rarityGlow = b:CreateTexture(nil, "BACKGROUND", nil, -3)
    rarityGlow:SetTexture(SHEET_MEDIA .. "SlotAura")
    rarityGlow:SetBlendMode("ADD")
    rarityGlow:SetSize(sz * 2.2, sz * 2.2)
    rarityGlow:SetPoint("CENTER", b, "CENTER", 0, 0)
    rarityGlow:Hide()
    b.rarityGlow = rarityGlow

    local wisps = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    wisps:SetTexture(SHEET_MEDIA .. "SlotAuraWisps")
    wisps:SetBlendMode("ADD")
    wisps:SetSize(sz * 2.2, sz * 2.2)
    wisps:SetPoint("CENTER", b, "CENTER", 0, 0)
    wisps:Hide()
    b.auraWisps = wisps

    local wisps2 = b:CreateTexture(nil, "BACKGROUND", nil, -2)
    wisps2:SetTexture(SHEET_MEDIA .. "SlotAuraWisps")
    wisps2:SetBlendMode("ADD")
    wisps2:SetSize(sz * 2.05, sz * 2.05)
    wisps2:SetPoint("CENTER", b, "CENTER", 0, 0)
    wisps2:SetTexCoord(1, 0, 0, 1)
    wisps2:Hide()
    b.auraWisps2 = wisps2

    -- faíscas orbitando o aro (1 verde, 2 azul, 3 épico ou acima)
    b.auraSparks = {}
    for k = 1, 3 do
        local sp = b:CreateTexture(nil, "OVERLAY", nil, 6)
        sp:SetTexture(MEDIA_ROOT .. "Star")
        sp:SetBlendMode("ADD")
        sp:SetSize(sz * 0.42, sz * 0.42)
        sp:Hide()
        b.auraSparks[k] = sp
    end

    -- 2. Esfera Escura Circular de Fundo (SlotRound.tga)
    local sphereBg = b:CreateTexture(nil, "BACKGROUND", nil, -1)
    sphereBg:SetPoint("TOPLEFT", b, "TOPLEFT", 1, -1)
    sphereBg:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -1, 1)
    sphereBg:SetTexture(INV_MEDIA .. "SlotRound")
    sphereBg:SetVertexColor(0.30, 0.34, 0.40, 1)
    b.sphereBg = sphereBg

    -- 3. Máscara Circular Perfeita no Ícone do Item!
    if b.icon then
        b.icon:ClearAllPoints()
        b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", 2, -2)
        b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -2, 2)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        ApplyCircleMask(b, b.icon)

        -- sombra na borda do ícone (funde o ícone ao aro)
        local vig = b:CreateTexture(nil, "ARTWORK", nil, 2)
        vig:SetAllPoints(b.icon)
        vig:SetTexture(SHEET_MEDIA .. "SlotVignette")
        b.iconVignette = vig
    end

    -- 4. Filete de raridade na borda interna do aro
    local innerRing = b:CreateTexture(nil, "OVERLAY", nil, 2)
    innerRing:SetSize(sz * 1.25, sz * 1.25)
    innerRing:SetPoint("CENTER", b, "CENTER", 0, 0)
    innerRing:SetTexture(SHEET_MEDIA .. "SlotRimLine")
    innerRing:SetBlendMode("ADD")
    innerRing:SetVertexColor(0.45, 0.52, 0.62, 0.5)
    b.innerRing = innerRing

    -- 5. Aro metálico do medalhão
    local outerRing = b:CreateTexture(nil, "OVERLAY", nil, 1)
    outerRing:SetSize(sz * 1.25, sz * 1.25)
    outerRing:SetPoint("CENTER", b, "CENTER", 0, 0)
    outerRing:SetTexture(SHEET_MEDIA .. "SlotBezel")
    b.outerRing = outerRing
    b.rarityPhase = (#U.slots + 1) * 0.65

    -- 6. Halo de Foco no Hover (CastRingThin.tga)
    local hoverRing = b:CreateTexture(nil, "OVERLAY", nil, 4)
    hoverRing:SetPoint("TOPLEFT", b, "TOPLEFT", -8, 8)
    hoverRing:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 8, -8)
    hoverRing:SetTexture(MEDIA_ROOT .. "CastRingEdge")
    hoverRing:SetBlendMode("ADD")
    hoverRing:SetVertexColor(0.55, 0.95, 1.0, 0.90)
    hoverRing:Hide()
    b.hoverRing = hoverRing

    b:SetHighlightTexture(MEDIA_ROOT .. "Glow")
    local hl = b:GetHighlightTexture()
    if hl then
        hl:SetBlendMode("ADD")
        hl:SetVertexColor(0.55, 0.92, 1.0, 0.25)
    end

    -- 7. Estrela de Encantamento na Borda do Orbe
    local enchStar = b:CreateTexture(nil, "OVERLAY", nil, 5)
    enchStar:SetSize(18, 18)
    enchStar:SetTexture(MEDIA_ROOT .. "Star")
    enchStar:SetBlendMode("ADD")
    enchStar:SetVertexColor(0.42, 1.0, 0.72, 0.95)
    enchStar:SetPoint("TOPRIGHT", b, "TOPRIGHT", 3, 3)
    enchStar:Hide()
    b.enchStar = enchStar

    -- 8. Tipografia Flutuante no Espaço Aberto (Sem Caixa Quadrada!)
    if (side == "LEFT" or side == "RIGHT") and textMaxW and textMaxW > 40 then
        local textHolder = CreateFrame("Frame", nil, page)
        textHolder:SetFrameLevel(b:GetFrameLevel())   -- nome acima dos grilhões do Santuário
        textHolder:SetSize(textMaxW, sz)
        if side == "LEFT" then
            textHolder:SetPoint("LEFT", b, "RIGHT", 12, 0)
        else
            textHolder:SetPoint("RIGHT", b, "LEFT", -12, 0)
        end

        -- Véu luminoso suave apenas ao passar o mouse (sem borda)
        local hoverVeil = textHolder:CreateTexture(nil, "BACKGROUND")
        hoverVeil:SetPoint("TOPLEFT", textHolder, "TOPLEFT", -8, -4)
        hoverVeil:SetPoint("BOTTOMRIGHT", textHolder, "BOTTOMRIGHT", 8, 4)
        hoverVeil:SetTexture(UF_MEDIA .. "ClassicGlassH")
        hoverVeil:SetBlendMode("ADD")
        hoverVeil:SetVertexColor(0.38, 0.88, 1.0, 0.28)
        hoverVeil:Hide()
        b.hoverVeil = hoverVeil

        local align = side == "LEFT" and "LEFT" or "RIGHT"
        local itemText = CreateText(textHolder, media.fontBold, 12 * fontK, c.cream, align)
        local subText = CreateText(textHolder, media.fontTitleB, 9 * fontK, { 0.58, 0.74, 0.90 }, align)
        itemText:SetShadowOffset(1, -1)
        itemText:SetShadowColor(0, 0, 0, 0.95)
        subText:SetShadowOffset(1, -1)
        subText:SetShadowColor(0, 0, 0, 0.95)
        itemText:SetWidth(textMaxW)
        itemText:SetWordWrap(false)
        subText:SetWidth(textMaxW)
        subText:SetWordWrap(false)

        if side == "LEFT" then
            itemText:SetPoint("TOPLEFT", textHolder, "TOPLEFT", 0, -6)
            subText:SetPoint("TOPLEFT", itemText, "BOTTOMLEFT", 0, -2)
        else
            itemText:SetPoint("TOPRIGHT", textHolder, "TOPRIGHT", 0, -6)
            subText:SetPoint("TOPRIGHT", itemText, "BOTTOMRIGHT", 0, -2)
        end
        b.plaqueItemName = itemText
        b.plaqueSubText = subText

        -- Cristais de Gema (pequenos losangos luminosos flutuando abaixo do subtexto)
        b.SocketGems = {}
        for g = 1, 4 do
            local gemTex = textHolder:CreateTexture(nil, "OVERLAY")
            gemTex:SetSize(8, 8)
            gemTex:SetTexture(MEDIA_ROOT .. "Diamond")
            if side == "LEFT" then
                gemTex:SetPoint("BOTTOMLEFT", textHolder, "BOTTOMLEFT", (g - 1) * 11, 3)
            else
                gemTex:SetPoint("BOTTOMRIGHT", textHolder, "BOTTOMRIGHT", -(g - 1) * 11, 3)
            end
            gemTex:Hide()
            b.SocketGems[g] = gemTex
        end
    end

    b:HookScript("OnEnter", function(self)
        self.hoverRing:Show()
        if self.hoverVeil then self.hoverVeil:Show() end
    end)
    b:HookScript("OnLeave", function(self)
        self.hoverRing:Hide()
        if self.hoverVeil then self.hoverVeil:Hide() end
    end)
end

--------------------------------------------------------------------------------
-- Santuário — réplica da arte de conceito (tools/sanctuary-concept)
--   A arte (templo, altar, fios de energia pintados) é SanctuaryBG, gerada por
--   tools/sanctuary-concept/gen.js sem nada do que o jogo desenha por cima.
--   Tudo aqui está em px da arte (2000x1125); o quadro inteiro é escalado para
--   cobrir a tela, como o Grimório. Geometria = tools/sanctuary-concept/layout.js
--   (preview.js desenha os caminhos sobre a arte para conferir).
--------------------------------------------------------------------------------
local SANCT = {
    W = 2000, H = 1125,
    leftSpine  = { { 77, 249 }, { 67, 367 }, { 62, 480 }, { 66, 593 }, { 67, 712 }, { 78, 827 }, { 90, 940 } },
    rightSpine = { { 1410, 247 }, { 1417, 362 }, { 1422, 477 }, { 1422, 592 }, { 1417, 710 }, { 1409, 822 }, { 1398, 940 } },
    -- fios de energia pintados (do lado do item até a borda do altar): caminho
    -- dos pulsos de energia (gen.js)
    trunks = {
        A = { { 150, 290 }, { 262, 385 }, { 335, 520 }, { 440, 640 }, { 585, 700 } },
        B = { { 205, 585 }, { 350, 660 }, { 462, 718 }, { 545, 748 } },
        C = { { 200, 885 }, { 340, 898 }, { 462, 858 }, { 578, 815 } },
        D = { { 1300, 310 }, { 1222, 420 }, { 1180, 545 }, { 1080, 645 }, { 945, 700 } },
        E = { { 1378, 582 }, { 1240, 660 }, { 1120, 712 }, { 1030, 742 } },
        F = { { 1360, 910 }, { 1180, 890 }, { 1080, 850 }, { 1000, 818 } },
        G = { { 668, 975 }, { 672, 905 }, { 700, 848 } },
        H = { { 868, 975 }, { 880, 900 }, { 862, 848 } },
    },
    leftTrunk   = { "A", "A", "A", "B", "B", "C", "C", "C" },
    rightTrunk  = { "D", "D", "D", "E", "E", "F", "F", "F" },
    weapons     = { { 614, 1020 }, { 705, 1020 }, { 785, 1020 }, { 862, 1020 } },
    weaponTrunk = { "G", "G", "H", "H" },
    altar = { 790, 762 },
    feet  = 772,                                          -- y onde o herói pisa (centro do altar)
    card  = { x = 1480, y = 100, w = 492, h = 963 },      -- caixa do card na arte
    -- quadros de SanctuaryFlow (gen.js): caixa na arte, 8 quadros de 670x375 em
    -- células de 680x376 (3 por linha); um ciclo = um comprimento de onda (190 px)
    flow  = { x = 100, y = 260, w = 1340, h = 750, fw = 670, fh = 375, cellW = 680, cellH = 376, cols = 3, frames = 8, speed = 0.55 },
    pose  = { cx = 742, cy = 970, w = 330, h = 25 },
    slotSize = 46, weaponSize = 50,
    cyan = { 0.42, 0.90, 1.0 }, gold = { 1.0, 0.78, 0.36 },
}

-- Grilhões de energia: mesmo desenho da aba de Talentos (Modules/Talents/Visuals.lua, Filament):
-- trechos RETOS com a trança CrucibleStream correndo (textura repetida), halo de
-- pontos de luz carimbados ao longo da linha e um orbe de luz em cada dobra (no
-- jogo toda emenda entre linhas deixa marca; o orbe a cobre).
local SanctFX = { chains = {}, tiling = true }
SanctFX.STREAM = MEDIA_ROOT .. "Talents\\CrucibleStream"
SanctFX.DOT    = MEDIA_ROOT .. "Talents\\TalentBtnImbuir"

function SanctFX.Line(parent, layer, sub)
    if parent.CreateLine then return parent:CreateLine(nil, layer, nil, sub) end
    return parent:CreateTexture(nil, layer, nil, sub)
end

-- pontos em coordenadas do pai (TOPLEFT, y para baixo)
function SanctFX.Place(ln, parent, x1, y1, x2, y2, w)
    if ln.SetStartPoint then
        ln:SetStartPoint("TOPLEFT", parent, x1, -y1)
        ln:SetEndPoint("TOPLEFT", parent, x2, -y2)
        ln:SetThickness(w)
        return
    end
    local dx, dy = x2 - x1, y2 - y1
    ln:ClearAllPoints()
    ln:SetSize(max(1, sqrt(dx * dx + dy * dy)), w)
    ln:SetPoint("CENTER", parent, "TOPLEFT", (x1 + x2) * 0.5, -(y1 + y2) * 0.5)
    if ln.SetRotation then pcall(ln.SetRotation, ln, math.atan2(-dy, dx)) end
end

function SanctFX.Chain(parent, pts, w, col, opts)
    opts = opts or {}
    local ch = { segs = {}, dots = {}, bends = {}, col = col, w = w, speed = 0.55 }
    local tile, acc = w * 4, 0
    local size = w * (opts.halo or 3)
    local step = size * 0.40
    local need = 0
    for i = 1, #pts - 1 do
        local a, b = pts[i], pts[i + 1]
        local dx, dy = b[1] - a[1], b[2] - a[2]
        local len = sqrt(dx * dx + dy * dy)
        if len > 0.5 then
            local ln = SanctFX.Line(parent, "BORDER", 3)
            if not (SanctFX.tiling and pcall(ln.SetTexture, ln, SanctFX.STREAM, "REPEAT", "CLAMP")) then
                SanctFX.tiling = false
                ln:SetTexture(SanctFX.STREAM)
            end
            ln:SetBlendMode("ADD")
            SanctFX.Place(ln, parent, a[1], a[2], b[1], b[2], w)
            ln.u0, ln.u1 = acc / tile, (acc + len) / tile
            ch.segs[#ch.segs + 1] = ln
            -- halo: pontos de luz redondos ao longo do trecho
            while need <= len do
                local u = need / len
                local d = parent:CreateTexture(nil, "BORDER", nil, 0)
                d:SetTexture(SanctFX.DOT)
                d:SetBlendMode("ADD")
                d:SetSize(size, size)
                d:SetPoint("CENTER", parent, "TOPLEFT", a[1] + dx * u, -(a[2] + dy * u))
                ch.dots[#ch.dots + 1] = d
                need = need + step
            end
            need = need - len
        end
        acc = acc + len
    end
    -- orbe de luz em cada dobra interna (e nas pontas pedidas: junção com o tronco)
    local first = opts.capStart and 1 or 2
    local last = opts.capEnd and #pts or #pts - 1
    for i = first, last do
        local d = parent:CreateTexture(nil, "ARTWORK", nil, 1)
        d:SetTexture(SanctFX.DOT)
        d:SetBlendMode("ADD")
        d:SetSize(w * (opts.bend or 2.1), w * (opts.bend or 2.1))
        d:SetPoint("CENTER", parent, "TOPLEFT", pts[i][1], -pts[i][2])
        ch.bends[#ch.bends + 1] = d
    end
    SanctFX.chains[#SanctFX.chains + 1] = ch
    SanctFX.Style(ch, opts.lit ~= false)
    return ch
end

-- aceso (item equipado: corre forte) ou apagado (corre fraco, quase só o halo)
function SanctFX.Style(ch, lit)
    if ch.lit == lit then return end
    ch.lit = lit
    local c = ch.col
    ch.speed = lit and 0.55 or 0.18
    for _, ln in ipairs(ch.segs) do ln:SetVertexColor(c[1], c[2], c[3], lit and 1 or 0.30) end
    local al = (lit and 0.72 or 0.12) * 0.42
    for _, d in ipairs(ch.dots) do d:SetVertexColor(c[1], c[2], c[3], al) end
    local wv = 0.45
    for _, d in ipairs(ch.bends) do
        d:SetVertexColor(c[1] + (1 - c[1]) * wv, c[2] + (1 - c[2]) * wv, c[3] + (1 - c[3]) * wv, lit and 1 or 0.35)
    end
end

-- a trança corre do primeiro ponto para o último
function SanctFX.Step(t)
    if not SanctFX.tiling then return end
    for _, ch in ipairs(SanctFX.chains) do
        local off = t * ch.speed
        for _, ln in ipairs(ch.segs) do
            if not pcall(ln.SetTexCoord, ln, ln.u0 - off, ln.u1 - off, 0, 1) then SanctFX.tiling = false return end
        end
    end
end

-- y igualmente espaçado ao longo da linha dos medalhões
function SANCT.Along(spine, n)
    local y0, y1, out = spine[1][2], spine[#spine][2], {}
    for i = 1, n do
        local y = y0 + (y1 - y0) * (i - 1) / (n - 1)
        local k = 1
        while k < #spine - 1 and spine[k + 1][2] < y do k = k + 1 end
        local a, b = spine[k], spine[k + 1]
        out[i] = { a[1] + (b[1] - a[1]) * (y - a[2]) / (b[2] - a[2]), y }
    end
    return out
end

--------------------------------------------------------------------------------
-- Construção da Página do Santuário
--------------------------------------------------------------------------------
local function BuildCharacterPage(page, cw, ch)
    local media = Azaath.media
    local charMod = Char()
    local S = SANCT

    -- quadro da arte cobrindo a tela inteira (atrás do cabeçalho e do rodapé da ficha)
    local root = page:GetParent() and page:GetParent():GetParent() or UIParent
    local art = CreateFrame("Frame", nil, page)
    art:SetSize(S.W, S.H)
    art:SetPoint("CENTER", root, "CENTER", 0, 0)
    S.art, S.root = art, root
    function S.Fit()
        local w, h = root:GetWidth(), root:GetHeight()
        if not (w and h and w > 0 and h > 0) then w, h = UIParent:GetWidth(), UIParent:GetHeight() end
        S.scale = max(w / S.W, h / S.H)
        art:SetScale(S.scale)
    end
    S.Fit()
    page:HookScript("OnShow", S.Fit)

    local bg = art:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetTexture(SHEET_MEDIA .. "SanctuaryBG")
    bg:SetTexCoord(0, S.W / 2048, 0, S.H / 2048)
    bg:SetAllPoints(art)

    local function At(region, x, y, point)
        region:ClearAllPoints()
        region:SetPoint(point or "CENTER", art, "TOPLEFT", x, -y)
    end

    local heroCenterX = S.altar[1]
    local daisY = -S.feet
    local modelW, modelH = 600, 700

    --==========================================================================
    -- 1. ALTAR: brilho do vórtice respirando + ondas que se abrem no tampo
    --==========================================================================
    local fxLayer = CreateFrame("Frame", nil, art)
    fxLayer:SetAllPoints(art)
    fxLayer:SetFrameLevel(art:GetFrameLevel() + 1)

    local altarGlow = fxLayer:CreateTexture(nil, "BORDER", nil, 1)
    altarGlow:SetTexture(MEDIA_ROOT .. "Glow")
    altarGlow:SetBlendMode("ADD")
    altarGlow:SetVertexColor(0.20, 0.85, 1.0)
    At(altarGlow, S.altar[1], S.altar[2])
    local altarCore = fxLayer:CreateTexture(nil, "BORDER", nil, 2)
    altarCore:SetTexture(MEDIA_ROOT .. "Glow")
    altarCore:SetBlendMode("ADD")
    altarCore:SetVertexColor(0.70, 0.98, 1.0)
    At(altarCore, S.altar[1], S.altar[2])
    local shockwaves = {}
    for w = 1, 2 do
        local ring = fxLayer:CreateTexture(nil, "BORDER", nil, 3)
        ring:SetTexture(MEDIA_ROOT .. "CastRingThin")
        ring:SetBlendMode("ADD")
        At(ring, S.altar[1], S.altar[2])
        shockwaves[w] = ring
    end

    --==========================================================================
    -- 2. MODELO 3D DO HERÓI (pisa no centro do altar)
    --==========================================================================
    local HERO_POSES = {
        { id = 0,   label = "GUARDIÃO" },
        { id = 26,  label = "COMBATE" },
        { id = 52,  label = "CONJURAÇÃO" },
        { id = 74,  label = "GRITO DE GUERRA" },
        { id = 66,  label = "SAUDAÇÃO" },
        { id = 69,  label = "VITÓRIA" },
    }

    U.model = CreateFrame("PlayerModel", nil, art)
    U.model:SetSize(modelW, modelH)
    -- a sola das botas fica a 82,4% da altura do quadro do modelo
    U.model:SetPoint("TOPLEFT", art, "TOPLEFT", heroCenterX - modelW * 0.5, daisY + modelH * 0.824)
    U.model:SetFrameLevel(art:GetFrameLevel() + 6)
    U.model:EnableMouse(true)
    U.model:EnableMouseWheel(true)
    U.model.facing = 0
    U.model.poseIdx = 1
    U.model.zoomLevel = 1.0

    function U.model:ApplyPose(idx)
        local p = HERO_POSES[idx or self.poseIdx or 1] or HERO_POSES[1]
        self.poseIdx = idx or self.poseIdx or 1
        if self.SetAnimation then pcall(self.SetAnimation, self, p.id) end
    end

    function U.model:ApplyZoom(delta)
        self.zoomLevel = max(0.65, min(1.55, (self.zoomLevel or 1.0) - delta * 0.08))
        if self.SetCamDistanceScale then
            pcall(self.SetCamDistanceScale, self, self.zoomLevel)
        elseif self.SetPosition then
            pcall(self.SetPosition, self, (1.0 - self.zoomLevel) * 1.2, 0, 0)
        end
    end

    U.model:SetScript("OnMouseWheel", function(self, delta) self:ApplyZoom(delta) end)
    U.model:SetScript("OnMouseDown", function(self)
        local x = GetCursorPosition()
        self.dragX, self.downX = x, x
    end)
    U.model:SetScript("OnMouseUp", function(self)
        local x = GetCursorPosition()
        if self.downX and abs(x - self.downX) < 3 then
            self:ApplyPose(self.poseIdx)
        end
        self.dragX, self.downX = nil, nil
    end)
    U.model:SetScript("OnUpdate", function(self)
        if not self.dragX then return end
        local x = GetCursorPosition()
        self.facing = self.facing + (x - self.dragX) * 0.02
        self.dragX = x
        self:SetFacing(self.facing)
    end)

    -- Camada frontal de efeitos (passa NA FRENTE do modelo 3D)
    local fxFrontLayer = CreateFrame("Frame", nil, art)
    fxFrontLayer:SetAllPoints(art)
    fxFrontLayer:SetFrameLevel(U.model:GetFrameLevel() + 2)

    -- Aura de Poder de Azaath: manto de luz atrás do corpo + vórtice de línguas,
    -- riscos e fagulhas que sobem do altar girando EM VOLTA do herói (cada
    -- partícula tem uma cópia atrás e outra na frente do modelo).
    local auraBody = fxLayer:CreateTexture(nil, "BORDER", nil, 4)
    auraBody:SetTexture(MEDIA_ROOT .. "Glow")
    auraBody:SetBlendMode("ADD")
    auraBody:SetVertexColor(0.16, 0.66, 1.0)
    local auraInner = fxLayer:CreateTexture(nil, "BORDER", nil, 5)
    auraInner:SetTexture(MEDIA_ROOT .. "Glow")
    auraInner:SetBlendMode("ADD")
    auraInner:SetVertexColor(0.45, 0.90, 1.0)
    local auraCX, auraCY = heroCenterX, daisY + modelH * 0.36
    auraBody:SetPoint("CENTER", art, "TOPLEFT", auraCX, auraCY)
    auraInner:SetPoint("CENTER", art, "TOPLEFT", auraCX, auraCY - modelH * 0.04)

    local AURA_KINDS = {
        --          qtd  largura      alt/larg  raio(x modelW)  vida(s)      alpha        giro(rad/s)  subida
        flame  = { n = 40, w = { 2.2, 4.2 }, hr = 1, r = { 0.11, 0.19 }, life = { 2.2, 3.4 }, a = { 0.55, 0.90 }, om = { 0.55, 1.05 }, h = 0.80 },
        streak = { n = 14, w = { 2.0, 3.3 }, hr = 1, r = { 0.07, 0.15 }, life = { 0.9, 1.5 }, a = { 0.45, 0.75 }, om = { 0.30, 0.60 }, h = 0.90 },
        ember  = { n = 44, w = { 2.2, 4.8 }, hr = 1, r = { 0.06, 0.22 }, life = { 2.4, 4.0 }, a = { 0.55, 0.95 }, om = { 0.45, 1.30 }, h = 0.95 },
    }
    local AURA_COLORS = { { 0.20, 0.78, 1.0 }, { 0.42, 0.92, 1.0 }, { 0.78, 0.98, 1.0 }, { 0.12, 0.52, 1.0 } }
    local auraParts = {}
    local function Rand(r) return r[1] + random() * (r[2] - r[1]) end
    local function SpawnAura(p, initial)
        local k = p.kind
        p.life = Rand(k.life)
        p.t = initial and random() * p.life or 0
        p.theta = random() * 6.28318
        p.omega = Rand(k.om) * (random() < 0.82 and 1 or -1)
        p.R = Rand(k.r) * modelW * 0.75
        p.amax = Rand(k.a)
        p.wob, p.wf, p.wp = 3 + random() * 7, 1.5 + random() * 2.5, random() * 6.28
        p.tw = 6 + random() * 8
        local w = Rand(k.w)
        p.w, p.h = w, w * k.hr
        local col = AURA_COLORS[1 + floor(random() * #AURA_COLORS)]
        p.back:SetVertexColor(col[1], col[2], col[3])
        p.front:SetVertexColor(col[1], col[2], col[3])
    end
    for _, kindName in ipairs({ "flame", "streak", "ember" }) do
        local k = AURA_KINDS[kindName]
        for i = 1, k.n do
            local p = { kind = k, isEmber = (kindName == "ember") }
            p.back = fxLayer:CreateTexture(nil, "ARTWORK", nil, 3)
            p.front = fxFrontLayer:CreateTexture(nil, "ARTWORK", nil, 3)
            for _, t in ipairs({ p.back, p.front }) do
                t:SetTexture(MEDIA_ROOT .. "Glow")
                t:SetBlendMode("ADD")
                t:SetAlpha(0)
            end
            SpawnAura(p, true)
            auraParts[#auraParts + 1] = p
        end
    end

    --==========================================================================
    -- 3. MEDALHÕES (8 de cada lado ao longo da linha da arte + 4 armas na pose)
    --==========================================================================
    local chainLayer = CreateFrame("Frame", nil, art)
    chainLayer:SetAllPoints(art)
    chainLayer:SetFrameLevel(art:GetFrameLevel() + 2)
    -- Fios de energia DA PRÓPRIA ARTE: a arte vem com os fios mais fracos e
    -- SanctuaryFlow (8 quadros, tools/sanctuary-concept/gen.js) põe por cima, em
    -- ADD, os mesmos fios com pulsos de luz que escorrem rumo ao altar; dois
    -- quadros vizinhos se cruzam para o movimento ficar contínuo.
    local F = S.flow
    S.flowTex = {}
    for i = 1, 2 do
        local tx = chainLayer:CreateTexture(nil, "BACKGROUND", nil, 1)
        tx:SetTexture(SHEET_MEDIA .. "SanctuaryFlow")
        tx:SetBlendMode("ADD")
        tx:SetSize(F.w, F.h)
        tx:SetPoint("TOPLEFT", art, "TOPLEFT", F.x, -F.y)
        S.flowTex[i] = tx
    end
    function S.FlowFrame(tx, f)
        local col, row = f % F.cols, floor(f / F.cols)
        local u0, v0 = col * F.cellW / 2048, row * F.cellH / 2048
        tx:SetTexCoord(u0, u0 + F.fw / 2048, v0, v0 + F.fh / 2048)
    end

    local spineCol = { 0.50, 0.56, 0.62, 0.85 }
    local function Spine(list)
        for i = 1, #list - 1 do
            local a, b = list[i], list[i + 1]
            local ln = SanctFX.Line(chainLayer, "BACKGROUND", 2)
            ln:SetTexture(media.blank)
            ln:SetVertexColor(spineCol[1], spineCol[2], spineCol[3], spineCol[4])
            SanctFX.Place(ln, chainLayer, a[1], a[2], b[1], b[2], 2.4)
        end
    end

    if charMod and charMod.CreateEquipSlot then
        local textMaxW = 175
        local leftPos = SANCT.Along(S.leftSpine, #LEFT_SLOTS)
        local rightPos = SANCT.Along(S.rightSpine, #RIGHT_SLOTS)
        Spine(leftPos)
        Spine(rightPos)

        for i, name in ipairs(LEFT_SLOTS) do
            local b = charMod.CreateEquipSlot(art, name, S.slotSize, "LEFT")
            if b then
                local p = leftPos[i]
                b:ClearAllPoints()
                b:SetPoint("CENTER", art, "TOPLEFT", p[1], -p[2])
                b:SetFrameLevel(art:GetFrameLevel() + 8)
                BuildCircularOrbSlot(art, b, name, "LEFT", textMaxW, 1.12)
                U.slots[#U.slots + 1] = b
            end
        end

        for i, name in ipairs(RIGHT_SLOTS) do
            local b = charMod.CreateEquipSlot(art, name, S.slotSize, "RIGHT")
            if b then
                local p = rightPos[i]
                b:ClearAllPoints()
                b:SetPoint("CENTER", art, "TOPLEFT", p[1], -p[2])
                b:SetFrameLevel(art:GetFrameLevel() + 8)
                BuildCircularOrbSlot(art, b, name, "RIGHT", textMaxW, 1.12)
                U.slots[#U.slots + 1] = b
            end
        end

        -- Barra de pose (faixa escura com setas) + as 4 armas logo abaixo
        local P = S.pose
        local poseBar = CreateFrame("Frame", nil, art)
        poseBar:SetSize(P.w, P.h)
        poseBar:SetPoint("CENTER", art, "TOPLEFT", P.cx, -P.cy)
        poseBar:SetFrameLevel(art:GetFrameLevel() + 8)
        local half = P.w * 0.5
        local bandL = poseBar:CreateTexture(nil, "BACKGROUND")
        bandL:SetTexture(media.blank)
        bandL:SetPoint("TOPLEFT"); bandL:SetPoint("BOTTOMRIGHT", poseBar, "BOTTOM", 0, 0)
        Azaath.Gradient(bandL, "HORIZONTAL", 0.02, 0.04, 0.06, 0.15, 0.02, 0.04, 0.06, 0.72)
        local bandR = poseBar:CreateTexture(nil, "BACKGROUND")
        bandR:SetTexture(media.blank)
        bandR:SetPoint("TOPLEFT", poseBar, "TOP", 0, 0); bandR:SetPoint("BOTTOMRIGHT")
        Azaath.Gradient(bandR, "HORIZONTAL", 0.02, 0.04, 0.06, 0.72, 0.02, 0.04, 0.06, 0.15)
        local bandLine = poseBar:CreateTexture(nil, "BORDER")
        bandLine:SetTexture(UF_MEDIA .. "ClassicGlassH")
        bandLine:SetBlendMode("ADD")
        bandLine:SetVertexColor(0.45, 0.70, 0.85, 0.18)
        bandLine:SetPoint("TOPLEFT", poseBar, "TOPLEFT", half * 0.25, 0)
        bandLine:SetPoint("TOPRIGHT", poseBar, "TOPRIGHT", -half * 0.25, 0)
        bandLine:SetHeight(1.2)

        local poseText = CreateText(poseBar, media.fontTitleB, 13, { 0.62, 0.70, 0.76 }, "CENTER")
        poseText:SetPoint("CENTER", poseBar, "CENTER", 0, 0)
        local function UpdatePoseLabel()
            local p = HERO_POSES[U.model.poseIdx or 1] or HERO_POSES[1]
            poseText:SetText(Azaath.Tracked("POSE: " .. p.label))
        end
        UpdatePoseLabel()
        local function CyclePose(dir)
            local n = #HERO_POSES
            U.model:ApplyPose(((U.model.poseIdx or 1) - 1 + dir) % n + 1)
            UpdatePoseLabel()
        end
        local function Arrow(side, dir)
            local a = CreateFrame("Button", nil, poseBar)
            a:SetSize(26, P.h)
            a:SetPoint(side, poseBar, side, side == "LEFT" and 8 or -8, 0)
            a.t = a:CreateTexture(nil, "OVERLAY")
            a.t:SetTexture(INV_MEDIA .. "Arrow")
            a.t:SetSize(10, 10)
            a.t:SetPoint("CENTER")
            a.t:SetVertexColor(0.62, 0.70, 0.76)
            if dir < 0 then a.t:SetTexCoord(1, 0, 0, 1) end
            a:SetScript("OnClick", function() Azaath.PlaySound("igMainMenuOptionCheckBoxOn"); CyclePose(dir) end)
            a:SetScript("OnEnter", function(self) self.t:SetVertexColor(0.70, 0.95, 1.0) end)
            a:SetScript("OnLeave", function(self) self.t:SetVertexColor(0.62, 0.70, 0.76) end)
        end
        Arrow("LEFT", -1)
        Arrow("RIGHT", 1)
        local poseBtn = CreateFrame("Button", nil, poseBar)
        poseBtn:SetPoint("TOPLEFT", poseBar, "TOPLEFT", 40, 0)
        poseBtn:SetPoint("BOTTOMRIGHT", poseBar, "BOTTOMRIGHT", -40, 0)
        poseBtn:SetScript("OnClick", function() Azaath.PlaySound("igMainMenuOptionCheckBoxOn"); CyclePose(1) end)
        poseBtn:SetScript("OnEnter", function() poseText:SetTextColor(0.86, 0.96, 1.0) end)
        poseBtn:SetScript("OnLeave", function() poseText:SetTextColor(0.62, 0.70, 0.76) end)

        for i, name in ipairs(WEAPON_SLOTS) do
            local b = charMod.CreateEquipSlot(art, name, S.weaponSize, "RIGHT")
            if b then
                local p = S.weapons[i]
                BuildCircularOrbSlot(art, b, name, "BOTTOM", 0)
                b:ClearAllPoints()
                b:SetPoint("CENTER", art, "TOPLEFT", p[1], -p[2])
                b:SetFrameLevel(art:GetFrameLevel() + 8)
                local wl = CreateText(art, media.fontTitleB, 11, { 0.66, 0.72, 0.78 }, "CENTER")
                wl:SetShadowOffset(1, -1)
                wl:SetShadowColor(0, 0, 0, 0.95)
                wl:SetPoint("TOP", b, "BOTTOM", 0, -6)
                wl:SetWidth(78)
                wl:SetWordWrap(false)
                wl:SetText(SLOT_NAMES[b.slotName] or b.slotName)
                b.weaponLabel = wl
                U.slots[#U.slots + 1] = b
            end
        end
    end

    --==========================================================================
    -- 4. LOOP DE ANIMAÇÃO
    --==========================================================================
    local animElapsed = 0
    local animFrame = CreateFrame("Frame", nil, page)
    animFrame:SetScript("OnUpdate", function(_, elapsed)
        if elapsed > 0.05 then elapsed = 0.05 end
        animElapsed = animElapsed + elapsed
        local t = animElapsed

        -- grilhões da constelação do card (trança correndo)
        SanctFX.Step(t)

        -- fios da arte: pulsos escorrendo para o altar (cruzamento entre 2 quadros)
        local ph = (t * S.flow.speed) % 1 * S.flow.frames
        local f0 = floor(ph)
        local fr = ph - f0
        S.FlowFrame(S.flowTex[1], f0)
        S.FlowFrame(S.flowTex[2], (f0 + 1) % S.flow.frames)
        S.flowTex[1]:SetAlpha(1 - fr)
        S.flowTex[2]:SetAlpha(fr)

        -- altar: vórtice respirando e ondas que se abrem no tampo
        local breath = (sin(t * 2.2) + 1) * 0.5
        local ignite = 0.45 + breath * 0.35
        altarGlow:SetSize(330 + breath * 30, 92 + breath * 8)
        altarGlow:SetAlpha(0.16 + ignite * 0.18)
        altarCore:SetSize(170 + breath * 18, 44 + breath * 5)
        altarCore:SetAlpha(0.14 + ignite * 0.20)
        for wIdx, ring in ipairs(shockwaves) do
            local prog = (t * 0.36 + (wIdx - 1) * 0.5) % 1
            local ease = 1 - (1 - prog) * (1 - prog)
            local rw = 180 + ease * 300
            ring:SetSize(rw, rw * 0.25)
            ring:SetVertexColor(0.38, 0.92, 1.0, (1 - prog) * (0.16 + ignite * 0.16))
        end

        -- aura de poder: manto respirando + vórtice subindo em volta do herói
        local powerBoost = 0.75 + ignite * 0.40
        local breathA = 0.5 + 0.5 * sin(t * 1.7)
        local flick = 0.9 + 0.1 * sin(t * 11.0) * sin(t * 7.3)
        auraBody:SetSize(modelW * (0.40 + breathA * 0.04), modelH * (0.62 + breathA * 0.04))
        auraBody:SetAlpha((0.08 + breathA * 0.05) * powerBoost * flick)
        auraInner:SetSize(modelW * 0.20, modelH * (0.46 + breathA * 0.05))
        auraInner:SetAlpha((0.06 + breathA * 0.05) * powerBoost * flick)

        local riseH = modelH * 0.85
        for _, p in ipairs(auraParts) do
            p.t = p.t + elapsed
            if p.t >= p.life then SpawnAura(p, false) end
            local q = p.t / p.life
            local k = p.kind
            local theta = p.theta + p.omega * p.t
            local R = p.R * (1 - q * 0.45) + sin(t * p.wf + p.wp) * p.wob
            local depth = sin(theta)                       -- >0 atrás do herói
            local x = heroCenterX + cos(theta) * R
            local y = daisY + 4 + q * riseH * k.h + depth * R * 0.16
            local env = min(1, q * 6) * (1 - q) ^ 1.3
            local tw = p.isEmber and (0.55 + 0.45 * sin(t * p.tw + p.wp)) or (0.8 + 0.2 * sin(t * p.tw + p.wp))
            local alpha = p.amax * env * tw * powerBoost
            local front = 1 - min(1, max(0, depth * 2.5 + 0.5))
            local scale = 1 + (1 - depth) * 0.08
            local w, h = p.w * scale * (1 - q * 0.35), p.h * scale * (1 - q * 0.2)
            p.back:SetSize(w, h); p.front:SetSize(w, h)
            p.back:SetPoint("CENTER", art, "TOPLEFT", x, y)
            p.front:SetPoint("CENTER", art, "TOPLEFT", x, y)
            p.back:SetAlpha(alpha * (1 - front))
            p.front:SetAlpha(alpha * front * 0.85)
        end

        -- aura de raridade dos medalhões: respira, línguas giram, faíscas orbitam
        for idx, sb in ipairs(U.slots) do
            if sb.hasRarity and sb.auraWisps then
                local ph = (sb.rarityPhase or idx * 0.5) + t * 1.6
                local sw = (sin(ph) + 1) * 0.5
                local pw = sb.auraPower or 1
                sb.rarityGlow:SetAlpha(min(1, (0.55 + sw * 0.30) * min(1, 0.7 + pw * 0.15)))
                sb.auraWisps:SetAlpha(0.55 + 0.35 * sin(ph * 1.3 + 1.1))
                sb.auraWisps2:SetAlpha(0.40 + 0.30 * sin(ph * 0.9 + 2.4))
                if sb.auraWisps.SetRotation then
                    pcall(sb.auraWisps.SetRotation, sb.auraWisps, t * 0.55 + (sb.rarityPhase or 0))
                    pcall(sb.auraWisps2.SetRotation, sb.auraWisps2, -t * 0.38 - (sb.rarityPhase or 0))
                end
                local orbit = sb:GetWidth() * 0.60
                for k, sp in ipairs(sb.auraSparks) do
                    if k <= (sb.auraSparkCount or 0) then
                        local ang = t * (1.1 + k * 0.17) * (k % 2 == 0 and -1 or 1) + k * 2.1 + (sb.rarityPhase or 0)
                        sp:ClearAllPoints()
                        sp:SetPoint("CENTER", sb, "CENTER", cos(ang) * orbit, sin(ang) * orbit)
                        sp:SetAlpha(0.45 + 0.55 * ((sin(t * 3.1 + k * 1.7) + 1) * 0.5))
                    end
                end
            end
        end

        for _, fn in ipairs(U.vfxNodes) do
            fn(elapsed, t)
        end
    end)

    --==========================================================================
    -- 5. O CARD DE ATRIBUTOS (na caixa do card da arte)
    --==========================================================================
    local cardScale = min(S.card.w / CARD_W, S.card.h / CARD_H)
    local codexW, codexH = CARD_W * cardScale, CARD_H * cardScale
    local codexPanel = CreateFrame("Frame", nil, art)
    codexPanel:SetSize(codexW, codexH)
    codexPanel:SetPoint("TOPLEFT", art, "TOPLEFT", S.card.x + (S.card.w - codexW) * 0.5, -(S.card.y + (S.card.h - codexH) * 0.5))
    codexPanel:SetFrameLevel(art:GetFrameLevel() + 10)
    codexPanel:EnableMouse(true)

    local cardFrame = CreateFrame("Frame", nil, codexPanel)
    cardFrame:SetSize(CARD_W, CARD_H)
    cardFrame:SetScale(cardScale)
    cardFrame:SetPoint("TOPLEFT", codexPanel, "TOPLEFT", 0, 0)
    card.frame = cardFrame

    card.bg = cardFrame:CreateTexture(nil, "BACKGROUND")
    card.bg:SetAllPoints(cardFrame)
    card.tabActive = cardFrame:CreateTexture(nil, "BORDER")
    card.tabActive:SetTexture(SHEET_MEDIA .. "AttrTabActive")
    card.tabActive:SetBlendMode("ADD")

    -- Sub-Abas (ATRIBUTOS & COMBATE · ARSENAL SALVO · TÍTULOS)
    U.subButtons = {}
    for i, def in ipairs(SUBTABS) do
        local b = CreateFrame("Button", nil, cardFrame)
        b.key = def.key
        b.index = i
        b:SetPoint("TOPLEFT", cardFrame, "TOPLEFT", CX(TAB_HIT[i][1]), CY(72))
        b:SetSize(TAB_HIT[i][2] - TAB_HIT[i][1], 48)
        b.text = CardText(cardFrame, TAB_CX[i], i == 1 and 95 or 95.5, FS.tab, CARD_COL.tabOff, "C")
        b.text:SetText(Azaath.Upper(def.label))
        b:SetScript("OnClick", function() Azaath.PlaySound("igMainMenuOptionCheckBoxOn"); SelectSub(def.key) end)
        b:SetScript("OnEnter", function(self)
            if U.currentSub ~= self.key then self.text:SetTextColor(0.86, 0.90, 0.92) end
        end)
        b:SetScript("OnLeave", function(self)
            if U.currentSub ~= self.key then
                local o = CARD_COL.tabOff
                self.text:SetTextColor(o[1], o[2], o[3])
            end
        end)
        U.subButtons[#U.subButtons + 1] = b
    end

    -- Arsenal Salvo e Títulos: listas em unidades da tela (fora do quadro escalado,
    -- senão a letra encolhe junto com a arte), presas à mesma caixa do card
    local k = S.scale or 1
    local subHolder = CreateFrame("Frame", nil, page)
    subHolder:SetPoint("TOPLEFT", codexPanel, "TOPLEFT", 0, 0)
    subHolder:SetPoint("BOTTOMRIGHT", codexPanel, "BOTTOMRIGHT", 0, 0)
    subHolder:SetFrameLevel(codexPanel:GetFrameLevel() + 4)
    local scrW = codexW * k
    local subTop = floor(140 * cardScale * k)
    local innerX = floor(44 * cardScale * k)
    local innerW = scrW - innerX * 2
    local innerH = floor(codexH * k) - subTop - floor(40 * cardScale * k)

    for _, def in ipairs(SUBTABS) do
        local sp
        if def.key == "attributes" then
            sp = CreateFrame("Frame", nil, cardFrame)
            sp:SetAllPoints(cardFrame)
            sp:SetFrameLevel(cardFrame:GetFrameLevel() + 2)
        else
            sp = CreateFrame("Frame", nil, subHolder)
            sp:SetPoint("TOPLEFT", subHolder, "TOPLEFT", 0, -subTop)
            sp:SetSize(scrW, innerH)
        end
        sp:Hide()
        subPages[def.key] = sp
    end

    BuildAttributes(subPages.attributes)
    BuildSets(subPages.sets, innerX, innerW, innerH)
    subPages.titles.list = NewList(subPages.titles, innerX, 0, innerW, innerH - 8, "Nenhum título conquistado.")

    -- Grilhões da Constelação Alquímica (mesmos da aba de Talentos): ligam as
    -- esferas por fora da borda de cada uma; ouro em volta do Vigor, ciano no resto
    local cl = CreateFrame("Frame", nil, subPages.attributes)
    cl:SetAllPoints(subPages.attributes)
    cl:SetFrameLevel(subPages.attributes:GetFrameLevel())
    local V = CONSTELLATION                 -- 1 Força, 2 Vigor, 3 Intelecto, 4 Espírito, 5 Agilidade
    local EDGES = {
        { 1, 2, true }, { 1, 3, true }, { 2, 3, true }, { 2, 4, true },
        { 1, 5 }, { 1, 4 }, { 5, 2 }, { 5, 4 }, { 5, 3 }, { 4, 3 },
    }
    -- espessura na proporção da aba de Talentos (trança larga + halo); cada
    -- ligação é UMA linha reta de esfera a esfera: pentágono + estrela
    for n, e in ipairs(EDGES) do
        local a, b = V[e[1]], V[e[2]]
        local ax, ay, bx, by = CX(a.cx), -CY(a.cy), CX(b.cx), -CY(b.cy)
        local dx, dy = bx - ax, by - ay
        local len = sqrt(dx * dx + dy * dy)
        local ux, uy = dx / len, dy / len
        local ra, rb = a.r + 2, b.r + 2
        local p0 = { ax + ux * ra, ay + uy * ra }
        local p2 = { bx - ux * rb, by - uy * rb }
        SanctFX.Chain(cl, { p0, p2 }, 20, e[3] and S.gold or S.cyan, { lit = true, halo = 2.4 })
    end
    U.SanctuaryFit = S.Fit
end

--------------------------------------------------------------------------------
-- Atualização Dinâmica dos Medalhões Circulares de Equipamento
--------------------------------------------------------------------------------
local function UpdateCharacterPage()
    local charMod = Char()
    local equippedCount = 0

    if charMod and charMod.UpdateSlot then
        for _, b in ipairs(U.slots) do
            charMod.UpdateSlot(b)
            if b.level then b.level:SetText("") end
            if b.duraBar then b.duraBar:Hide() end
            if b.broken then b.broken:Hide() end
            if b.gemPips then for i = 1, 4 do b.gemPips[i]:Hide() end end
            if b.enchantPip then b.enchantPip:Hide() end

            local link = GetInventoryItemLink("player", b.slotID)
            if link then
                equippedCount = equippedCount + 1
                local itemName, _, quality, itemLevel = Azaath.API.GetItemInfo(link)
                quality = quality or 1
                local r, g, bl = Azaath.API.GetItemQualityColor(quality)
                r, g, bl = r or 1, g or 1, bl or 1

                b.hasRarity = (quality >= 2)
                b.auraPower = quality
                b.auraR, b.auraG, b.auraB = r, g, bl
                b.auraSparkCount = quality >= 4 and 3 or (quality >= 3 and 2 or (quality >= 2 and 1 or 0))
                if b.rarityGlow then
                    b.rarityGlow:SetVertexColor(r, g, bl)
                    b.auraWisps:SetVertexColor(r, g, bl)
                    b.auraWisps2:SetVertexColor(min(1, r * 0.8 + 0.2), min(1, g * 0.8 + 0.2), min(1, bl * 0.8 + 0.2))
                    Show(b.rarityGlow, b.hasRarity)
                    Show(b.auraWisps, b.hasRarity)
                    Show(b.auraWisps2, b.hasRarity)
                    for k, sp in ipairs(b.auraSparks) do
                        sp:SetVertexColor(min(1, r * 0.6 + 0.45), min(1, g * 0.6 + 0.45), min(1, bl * 0.6 + 0.45))
                        Show(sp, k <= b.auraSparkCount)
                    end
                end
                if b.innerRing then
                    if b.hasRarity then
                        b.innerRing:SetVertexColor(r, g, bl, 1)
                    else
                        b.innerRing:SetVertexColor(0.62, 0.66, 0.72, 0.55)
                    end
                end
                if b.outerRing then b.outerRing:SetVertexColor(1, 1, 1, 1) end
                if b.plaqueItemName then
                    b.plaqueItemName:SetText(itemName or (SLOT_NAMES[b.slotName] or b.slotName))
                    b.plaqueItemName:SetTextColor(r, g, bl)
                end
                if b.plaqueSubText then
                    local slotLabel = SLOT_NAMES[b.slotName] or b.slotName
                    if itemLevel and itemLevel > 1 then
                        b.plaqueSubText:SetText(format("|cff38bdf8%d|r  ·  %s", itemLevel, slotLabel))
                    else
                        b.plaqueSubText:SetText(slotLabel)
                    end
                    b.plaqueSubText:SetTextColor(0.62, 0.76, 0.90)
                end

                if b.SocketGems then
                    local _, enchantID, gem1, gem2, gem3, gem4 = link:match("item:(%d+):(%d+):(%d+):(%d+):(%d+):(%d+)")
                    local gems = { gem1, gem2, gem3, gem4 }
                    local socketTypes = {}
                    local okStats, stats = pcall(GetItemStats, link)
                    if okStats and type(stats) == "table" then
                        for k, v in pairs(stats) do
                            if type(k) == "string" and k:find("EMPTY_SOCKET") then
                                local count = type(v) == "number" and v or 1
                                local sType = k:match("EMPTY_SOCKET_(%w+)") or "PRISMATIC"
                                for _ = 1, count do socketTypes[#socketTypes + 1] = sType end
                            end
                        end
                    end
                    local filledCount = 0
                    for i = 1, 4 do
                        local gid = tonumber(gems[i])
                        if gid and gid > 0 then filledCount = filledCount + 1 end
                    end
                    local totalSockets = min(4, max(#socketTypes, filledCount))
                    for i = 1, 4 do
                        local gTex = b.SocketGems[i]
                        if i <= totalSockets then
                            local gid = tonumber(gems[i])
                            local isFilled = gid and gid > 0
                            local sType = socketTypes[i] or "PRISMATIC"
                            local cr, cg, cb = 0.85, 0.85, 0.90
                            if sType == "RED" then cr, cg, cb = 1.0, 0.32, 0.32
                            elseif sType == "BLUE" then cr, cg, cb = 0.32, 0.78, 1.0
                            elseif sType == "YELLOW" then cr, cg, cb = 1.0, 0.88, 0.28
                            elseif sType == "META" then cr, cg, cb = 0.90, 0.95, 1.0
                            elseif sType == "PRISMATIC" then cr, cg, cb = 0.85, 0.48, 1.0
                            end
                            gTex:SetVertexColor(cr, cg, cb, isFilled and 1.0 or 0.28)
                            gTex:Show()
                        else
                            gTex:Hide()
                        end
                    end
                    if b.enchStar then
                        local eid = enchantID and tonumber(enchantID)
                        Show(b.enchStar, eid and eid > 0)
                    end
                end

                if b.weaponLabel then
                    b.weaponLabel:SetText(itemName or (SLOT_NAMES[b.slotName] or b.slotName))
                    b.weaponLabel:SetTextColor(r, g, bl)
                end
                if b.icon then b.icon:SetVertexColor(1, 1, 1, 1) end
            else
                b.hasRarity = false
                b.auraSparkCount = 0
                if b.rarityGlow then
                    b.rarityGlow:Hide(); b.auraWisps:Hide(); b.auraWisps2:Hide()
                    for _, sp in ipairs(b.auraSparks) do sp:Hide() end
                end
                if b.innerRing then b.innerRing:SetVertexColor(0.38, 0.48, 0.62, 0.30) end
                if b.outerRing then b.outerRing:SetVertexColor(0.75, 0.78, 0.85, 0.80) end
                if b.plaqueItemName then
                    b.plaqueItemName:SetText(SLOT_NAMES[b.slotName] or b.slotName)
                    b.plaqueItemName:SetTextColor(0.42, 0.50, 0.60)
                end
                if b.plaqueSubText then
                    b.plaqueSubText:SetText("")
                end
                if b.SocketGems then for i = 1, 4 do b.SocketGems[i]:Hide() end end
                if b.enchStar then b.enchStar:Hide() end
                if b.weaponLabel then
                    b.weaponLabel:SetText(SLOT_NAMES[b.slotName] or b.slotName)
                    b.weaponLabel:SetTextColor(0.66, 0.72, 0.78)
                end
                if b.icon and b.emptyTexture then
                    b.icon:SetTexture(b.emptyTexture)
                    b.icon:SetVertexColor(0.32, 0.52, 0.75, 0.32)
                end
            end
        end
    end

    local d = charMod and charMod.Durability and charMod.Durability() or 1
    local duraPct = floor(d * 100 + 0.5)

    local free, total = 0, 0
    for bag = 0, 4 do
        local numSlots = (_G.GetContainerNumSlots and GetContainerNumSlots(bag))
            or (_G.C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerNumSlots(bag)) or 0
        if numSlots > 0 then
            total = total + numSlots
            local numFree = (_G.GetContainerNumFreeSlots and GetContainerNumFreeSlots(bag))
                or (_G.C_Container and C_Container.GetContainerNumFreeSlots and select(1, C_Container.GetContainerNumFreeSlots(bag))) or 0
            free = free + numFree
        end
    end

    local footer = U.frame and U.frame.modernFooter
    if footer then
        footer.duraLabel:SetText(format("INTEGRIDADE  |cffffffff%d%%|r", duraPct))
        local cost = _G.GetRepairAllCost and GetRepairAllCost() or 0
        if cost and cost > 0 then
            footer.repairLabel:SetText("REPARO  " .. Azaath.FormatMoney(cost))
        else
            footer.repairLabel:SetText("ARSENAL INTACTO")
        end
        footer.bagLabel:SetText(format("BOLSAS  |cff38bdf8%d / %d|r LIVRES", free, total))
    end

    if U.currentSub == "attributes" then
        UpdateAttributes()
        UpdateVitals()
    elseif U.currentSub == "sets" then
        UpdateSets()
    elseif U.currentSub == "titles" then
        subPages.titles.list:SetEntries(CollectTitles())
    end
end

-- compartilhado com os outros arquivos da ficha
U.BuildCharacterPage, U.SelectSub, U.UpdateCharacterPage = BuildCharacterPage, SelectSub, UpdateCharacterPage
