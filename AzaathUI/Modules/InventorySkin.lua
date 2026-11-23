--[[----------------------------------------------------------------------------
    AzaathUI - Modules/InventorySkin.lua
    Skin "Azaath" da mochila (inventory.style = "azaath", vale após /reload).
    A skin padrão continua em Inventory.lua; esta reveste a mesma janela:
      * moldura: corpo azul-petróleo com trama de losangos, filete de ouro por
        fora e azul por dentro, cantoneiras, losangos de cristal nos cantos e o
        brasão com cristal no topo (também no painel Equipado)
      * cabeçalho: título grande, contador "usados / total", abas com brilho
        azul, botão fechar; faixa Mochilas, busca com lupa e ordenação em caixas
      * chips de categoria (Todos, Armas, Equip., ...): filtram a janela
      * espaços com aro tingido pela raridade (quadrado, equipamento, redondo)
      * títulos de seção com filete de ouro; rodapé com botões emoldurados
    Texturas: Media/Inventory/Az*.tga, de tools/inventory-azaath/gen.js.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local IS = {}
Azaath.InventorySkin = IS

local _G = _G
local max = math.max

local L = { -- medidas do cabeçalho (distância do topo da janela)
    titleY = 20, stripY = 58, searchY = 106, chipsY = 140, bodyTop = 166, rowH = 24, chipH = 22,
}
local COL = {
    gold = { 0.79, 0.66, 0.42 }, goldL = { 0.95, 0.86, 0.65 }, teal = { 0.37, 0.84, 0.82 },
    tealD = { 0.16, 0.34, 0.36 }, cream = { 0.93, 0.90, 0.83 }, dim = { 0.58, 0.62, 0.62 },
    box = { 0.025, 0.05, 0.06 },
}
-- chips: rótulo longo/curto (o curto entra quando a janela é estreita) e categorias
local CHIPS = {
    { "Todos", "Todos", nil },
    { "Armas", "Armas", { weapons = true } },
    { "Equip.", "Equip.", { armor = true } },
    { "Consumíveis", "Consum.", { consumable = true } },
    { "Materiais", "Mater.", { materials = true } },
    { "Missão", "Missão", { quest = true } },
    { "Diversos", "Div.", { misc = true, junk = true } },
}

local function T(name) return Azaath.media.path .. "Inventory\\" .. name end

function IS.Active()
    local inv = Azaath.db and Azaath.db.inventory
    return inv and inv.style == "azaath" or false
end

local function Line(f, layer, r, g, b, a)
    local t = f:CreateTexture(nil, layer or "BORDER")
    t:SetTexture(Azaath.media.blank)
    t:SetVertexColor(r, g, b, a)
    return t
end

local function Font(fs, file, size, c)
    if not pcall(fs.SetFont, fs, file, size, "") or not fs:GetFont() then fs:SetFont("Fonts\\FRIZQT__.TTF", size, "") end
    if c then fs:SetTextColor(c[1], c[2], c[3]) end
end

local function NewText(parent, file, size, c)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    Font(fs, file, size, c)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetShadowOffset(1, -1)
    return fs
end

local function Box(f, border, a)
    local media = Azaath.media
    Azaath.SetBackdrop(f, { bgFile = media.blank, edgeFile = media.blank, edgeSize = 1 })
    f:SetBackdropColor(COL.box[1], COL.box[2], COL.box[3], a or 0.9)
    local c = border or COL.tealD
    f:SetBackdropBorderColor(c[1], c[2], c[3], 1)
end

--------------------------------------------------------------------------------
-- Moldura (mochila e painel Equipado)
--------------------------------------------------------------------------------
function IS.Chrome(f, headerH)
    local bg = f:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetTexture(T("AzBody"))
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    local pat = f:CreateTexture(nil, "BACKGROUND", nil, -7)
    pat:SetTexture(T("AzPattern"), "REPEAT", "REPEAT")
    pat:SetHorizTile(true)
    pat:SetVertTile(true)
    pat:SetPoint("TOPLEFT", 3, -3)
    pat:SetPoint("BOTTOMRIGHT", -3, 3)
    pat:SetVertexColor(COL.teal[1], COL.teal[2], COL.teal[3], 0.045)

    -- filete de ouro (fora) e azul (dentro)
    local function Frame4(inset, r, g, b, a)
        local top, bot, lef, rig = Line(f, "BORDER", r, g, b, a), Line(f, "BORDER", r, g, b, a),
                                   Line(f, "BORDER", r, g, b, a), Line(f, "BORDER", r, g, b, a)
        top:SetHeight(1); bot:SetHeight(1); lef:SetWidth(1); rig:SetWidth(1)
        top:SetPoint("TOPLEFT", inset, -inset); top:SetPoint("TOPRIGHT", -inset, -inset)
        bot:SetPoint("BOTTOMLEFT", inset, inset); bot:SetPoint("BOTTOMRIGHT", -inset, inset)
        lef:SetPoint("TOPLEFT", inset, -inset); lef:SetPoint("BOTTOMLEFT", inset, inset)
        rig:SetPoint("TOPRIGHT", -inset, -inset); rig:SetPoint("BOTTOMRIGHT", -inset, inset)
    end
    Frame4(0, COL.gold[1], COL.gold[2], COL.gold[3], 0.7)
    Frame4(4, COL.tealD[1], COL.tealD[2], COL.tealD[3], 0.9)

    -- cantoneiras (a textura é o canto superior esquerdo; espelha nos outros)
    for _, c in ipairs({ { "TOPLEFT", 0, 1, 0, 1, 6, -6 }, { "TOPRIGHT", 1, 0, 0, 1, -6, -6 },
                         { "BOTTOMLEFT", 0, 1, 1, 0, 6, 6 }, { "BOTTOMRIGHT", 1, 0, 1, 0, -6, 6 } }) do
        local t = f:CreateTexture(nil, "ARTWORK")
        t:SetTexture(T("AzCorner"))
        t:SetSize(20, 20)
        t:SetTexCoord(c[2], c[3], c[4], c[5])
        t:SetPoint(c[1], c[6], c[7])
        local gem = f:CreateTexture(nil, "OVERLAY", nil, 2)
        gem:SetTexture(T("AzGem"))
        gem:SetSize(18, 18)
        gem:SetPoint("CENTER", f, c[1], 0, 0)
    end

    -- brasão com cristal: a base dele assenta no filete de cima
    local crest = f:CreateTexture(nil, "OVERLAY", nil, 3)
    crest:SetTexture(T("AzCrest"))
    crest:SetSize(220, 55)
    crest:SetPoint("BOTTOM", f, "TOP", 0, -55 * 12 / 64)

    if headerH and headerH > 0 then
        local sep = Line(f, "BORDER", COL.tealD[1], COL.tealD[2], COL.tealD[3], 0.9)
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", 12, -headerH)
        sep:SetPoint("TOPRIGHT", -12, -headerH)
    end
end

-- Botão emoldurado (rodapé, ficha): caixa escura, borda e brilho embaixo
function IS.Button(btn, text, border)
    Box(btn, border or COL.gold, 0.92)
    local glow = btn:CreateTexture(nil, "ARTWORK")
    glow:SetTexture(T("AzGlow"))
    glow:SetHeight(6)
    glow:SetPoint("BOTTOMLEFT", 6, -3)
    glow:SetPoint("BOTTOMRIGHT", -6, -3)
    glow:SetVertexColor(COL.teal[1], COL.teal[2], COL.teal[3], 0.55)
    if text then
        Font(text, Azaath.media.fontTitleB, 10, COL.cream)
        text:SetText(text:GetText():upper())
    end
end

--------------------------------------------------------------------------------
-- Chips de categoria
--------------------------------------------------------------------------------
local chips, chipRow = {}, nil

local function PaintChips(M)
    for _, c in ipairs(chips) do
        local on = (M.catFilter == c.keys)
        for _, t in ipairs(c.parts) do
            t:SetTexture(T(on and "AzChipOn" or "AzChip"))
            if on then t:SetVertexColor(COL.teal[1], COL.teal[2], COL.teal[3], 1) else t:SetVertexColor(1, 1, 1, 1) end
        end
        local tc = on and COL.cream or (c.hover and COL.cream or COL.dim)
        c.text:SetTextColor(tc[1], tc[2], tc[3])
    end
end

-- 3 fatias: pontas de 12 (de 64 na textura = 0.1875) e meio esticado
local function ChipParts(b)
    local l, m, r = b:CreateTexture(nil, "BACKGROUND"), b:CreateTexture(nil, "BACKGROUND"), b:CreateTexture(nil, "BACKGROUND")
    l:SetWidth(11); r:SetWidth(11)
    l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT")
    r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT")
    m:SetPoint("TOPLEFT", l, "TOPRIGHT"); m:SetPoint("BOTTOMRIGHT", r, "BOTTOMLEFT")
    l:SetTexCoord(0, 0.1875, 0, 1); m:SetTexCoord(0.1875, 0.8125, 0, 1); r:SetTexCoord(0.8125, 1, 0, 1)
    return { l, m, r }
end

local function LayoutChips(width)
    if not chipRow then return end
    local function Total(short, pad)
        local w = 0
        for _, c in ipairs(chips) do
            c.text:SetText(short and c.short or c.long)
            w = w + c.text:GetStringWidth() + pad * 2 + 5
        end
        return w - 5
    end
    local short, pad = false, 10
    if Total(false, 10) > width then
        pad = 7
        if Total(false, 7) > width then short = true end
    end
    Total(short, pad)
    local prev
    for _, c in ipairs(chips) do
        c:SetSize(c.text:GetStringWidth() + pad * 2, L.chipH)
        c:ClearAllPoints()
        if prev then c:SetPoint("LEFT", prev, "RIGHT", 5, 0) else c:SetPoint("LEFT", chipRow, "LEFT", 0, 0) end
        prev = c
    end
end

local function BuildChips(M, frame, pad)
    chipRow = CreateFrame("Frame", nil, frame)
    chipRow:SetHeight(L.chipH)
    chipRow:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -L.chipsY)
    chipRow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -L.chipsY)
    for _, def in ipairs(CHIPS) do
        local b = CreateFrame("Button", nil, chipRow)
        b.long, b.short, b.keys = def[1], def[2], def[3]
        b.parts = ChipParts(b)
        b.text = NewText(b, Azaath.media.fontBold, 10, COL.dim)
        b.text:SetPoint("CENTER", 0, 0)
        b:SetScript("OnClick", function(self)
            M.catFilter = self.keys
            PaintChips(M)
            if M.ui.scroll then M.ui.scroll:SetVerticalScroll(0) end
            M:Refresh()
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        end)
        b:SetScript("OnEnter", function(self) self.hover = true; PaintChips(M) end)
        b:SetScript("OnLeave", function(self) self.hover = nil; PaintChips(M) end)
        chips[#chips + 1] = b
    end
    -- o filtro de categoria vale só enquanto a mochila está aberta
    frame:HookScript("OnHide", function()
        if M.catFilter then M.catFilter = nil; PaintChips(M); M:Refresh() end
    end)
    PaintChips(M)
end

--------------------------------------------------------------------------------
-- Mini radial (G) com a arte do próprio menu radial (Media/Radial, desenhada
-- para um quadro de 480): pedra, runas girando, divisórias, núcleo com o nome
-- do consumível e a fatia acesa sobre o espaço sob o mouse.
--------------------------------------------------------------------------------
local RADIAL = { view = 210, art = 480, slotR = 159, slot = 30, core = 176, divR = 154 }

function IS.DressRadial(M)
    local mini = M.mini
    if not mini then return end
    local ART = Azaath.media.path .. "Radial\\"
    local k = RADIAL.view / RADIAL.art
    local host, f = mini.host, mini.frame
    f:SetSize(RADIAL.view, RADIAL.view)
    mini.disc:Hide(); mini.ring:Hide(); mini.key:Hide()

    local function Art(name, layer, sub, size, blend)
        local t = host:CreateTexture(nil, layer, nil, sub or 0)
        t:SetTexture(ART .. name)
        t:SetSize(size, size)
        t:SetPoint("CENTER")
        if blend then t:SetBlendMode(blend) end
        return t
    end
    Art("Base", "BACKGROUND", -2, RADIAL.view)
    local runes = Art("RuneBand", "BACKGROUND", -1, RADIAL.view)
    local ag = runes:CreateAnimationGroup()
    local rot = ag:CreateAnimation("Rotation")
    rot:SetDegrees(-360)
    rot:SetDuration(40) -- mesma volta do menu G (RadialMenu.lua RUNE_TURN)
    ag:SetLooping("REPEAT")
    ag:Play()
    f:HookScript("OnShow", function() if not ag:IsPlaying() then ag:Play() end end)

    local wedge = Art("Wedge8", "BORDER", 0, RADIAL.view, "ADD")
    wedge:SetVertexColor(0.50, 0.85, 0.54) -- verde dos consumíveis no menu G
    wedge:SetAlpha(0)

    local n, TAU = #mini.slots, math.pi * 2
    for i = 1, n do
        local a = TAU * (i - 1) / n + math.pi / n
        local d = host:CreateTexture(nil, "BORDER", nil, 1)
        d:SetTexture(ART .. "Divider")
        d:SetSize(16 * k, 96 * k)
        d:SetPoint("CENTER", host, "CENTER", math.sin(a) * RADIAL.divR * k, math.cos(a) * RADIAL.divR * k)
        d:SetRotation(-a)
    end

    -- núcleo: título da aba, nome do consumível sob o mouse e a dica
    local center = CreateFrame("Frame", nil, host)
    center:SetAllPoints()
    center:SetFrameLevel(host:GetFrameLevel() + 20)
    local core = center:CreateTexture(nil, "BACKGROUND")
    core:SetTexture(ART .. "Core")
    core:SetSize(RADIAL.core * k, RADIAL.core * k)
    core:SetPoint("CENTER")
    local media = Azaath.media
    local title = NewText(center, media.fontTitleB, 8, { 0.50, 0.85, 0.54 })
    title:SetPoint("CENTER", 0, 15)
    title:SetText("C O N S U M Í V E I S   G")
    local name = NewText(center, media.fontTitleB, 10, COL.cream)
    name:SetPoint("CENTER", 0, 1)
    name:SetWidth(RADIAL.core * k - 10)
    name:SetWordWrap(false)
    local line = center:CreateTexture(nil, "ARTWORK")
    line:SetTexture(media.blank)
    line:SetSize(40, 1)
    line:SetPoint("CENTER", 0, -8)
    line:SetVertexColor(COL.gold[1], COL.gold[2], COL.gold[3], 0.55)
    local hint = NewText(center, media.font, 8, COL.dim)
    hint:SetPoint("CENTER", 0, -17)
    local function Idle()
        name:SetText("Consumíveis")
        hint:SetText("arraste para fixar")
        wedge:SetAlpha(0)
    end
    Idle()

    local function Saved(i)
        local AC = Azaath.ActionCam
        local t = (AC and AC.GetRadialConsumables and AC.GetRadialConsumables())
            or (Azaath.db.actioncam and Azaath.db.actioncam.radialConsumables) or {}
        return tonumber(t[i])
    end

    local slot, R = RADIAL.slot, RADIAL.slotR * k
    for _, b in ipairs(mini.slots) do
        local a = TAU * (b.idx - 1) / n
        b:SetSize(slot, slot)
        b:ClearAllPoints()
        b:SetPoint("CENTER", host, "CENTER", math.sin(a) * R, math.cos(a) * R)
        b:SetFrameLevel(center:GetFrameLevel() + 1)
        b.bg:SetTexture(ART .. "SlotBack")
        b.bg:SetVertexColor(1, 1, 1, 1)
        b.icon:SetSize(slot * 0.82, slot * 0.82)
        b.mask:SetSize(slot * 0.82, slot * 0.82)
        b.rim:SetTexture(ART .. "SlotRim")
        b.rim:SetSize(slot * 1.1, slot * 1.1)
        b.count:ClearAllPoints()
        b.count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 1, 0)
        b:HookScript("OnEnter", function(self)
            wedge:SetRotation(-TAU * (self.idx - 1) / n)
            wedge:SetAlpha(0.85)
            local id = Saved(self.idx)
            local itemName = id and ((_G.C_Item and _G.C_Item.GetItemNameByID and _G.C_Item.GetItemNameByID(id))
                or (_G.GetItemInfo and _G.GetItemInfo(id)))
            name:SetText(itemName or "Espaço vazio")
            hint:SetText(id and "direito: remover" or "arraste para fixar")
        end)
        b:HookScript("OnLeave", Idle)
    end
    mini.refresh()
end

--------------------------------------------------------------------------------
-- Aplicação na mochila (chamada no fim do Build de Inventory.lua)
--------------------------------------------------------------------------------
-- Título, contador e abas na mesma linha: diminui o título até caber entre a
-- borda esquerda e as abas; se nem assim couber, esconde o contador.
function IS.FitTitle(M)
    local ui, pad = M.ui, M.ui.pad
    local tabsW = 0
    for i, t in ipairs(ui.viewTabs) do tabsW = tabsW + t:GetWidth() + (i > 1 and 6 or 0) end
    local room = (M.frame:GetWidth() or 400) - (pad + 2) - pad - tabsW - 14
    local countW = IS.count:GetWidth() + 12
    local size = 21
    while size > 13 do
        Font(ui.title, Azaath.media.fontTitleB, size)
        if ui.title:GetStringWidth() + countW <= room then break end
        size = size - 1
    end
    IS.count:SetShown(ui.title:GetStringWidth() + countW <= room)
end

function IS.Apply(M)
    local ui, frame, media = M.ui, M.frame, Azaath.media
    local pad = ui.pad

    -- moldura padrão fora; a nossa no lugar
    for _, t in ipairs({ ui.headerTex, ui.bodyTex, ui.footerTex }) do t:Hide() end
    for _, t in ipairs(M.chromeExtra or {}) do t:Hide() end
    IS.Chrome(frame, 0)
    local foot = Line(frame, "BORDER", COL.tealD[1], COL.tealD[2], COL.tealD[3], 0.9)
    foot:SetHeight(1)
    foot:SetPoint("BOTTOMLEFT", 12, ui.footerH)
    foot:SetPoint("BOTTOMRIGHT", -12, ui.footerH)

    -- título + contador usados/total
    Font(ui.title, media.fontTitleB, 21, COL.cream)
    ui.title:ClearAllPoints()
    ui.title:SetPoint("TOPLEFT", frame, "TOPLEFT", pad + 2, -L.titleY)
    local count = CreateFrame("Frame", nil, frame)
    count:SetSize(64, 20)
    count:SetPoint("LEFT", ui.title, "RIGHT", 12, -1)
    Box(count, COL.tealD, 0.9)
    count.text = NewText(count, media.fontBold, 11, COL.teal)
    count.text:SetPoint("CENTER", 0, 0)
    IS.count = count

    -- abas: no canto superior direito, sublinhado com brilho azul
    local tabs = ui.viewTabs
    if tabs[1] then
        tabs[1]:ClearAllPoints()
        tabs[1]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -pad, -17)
    end
    for _, t in ipairs(tabs) do
        -- abas um pouco menores: dividem a linha com o título e o contador
        local fnt = t.text:GetFont()
        if fnt then pcall(t.text.SetFont, t.text, fnt, 11, "") end
        t:SetWidth((t.text:GetStringWidth() or 50) + 12)
        t.under:SetTexture(T("AzGlow"))
        t.under:SetVertexColor(COL.teal[1], COL.teal[2], COL.teal[3], 1)
        t.under:SetHeight(6)
        t.under:ClearAllPoints()
        t.under:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", -4, -4)
        t.under:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", 4, -4)
    end

    -- faixa Mochilas logo abaixo do título
    local IB = Azaath.InventoryBags
    if IB and IB.strip then
        IB.strip:ClearAllPoints()
        IB.strip:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -L.stripY)
    end

    -- ordenação em caixas, alinhada com a busca
    local sb = ui.sortButtons
    if sb[#sb] then
        sb[#sb]:ClearAllPoints()
        sb[#sb]:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(pad + 5), -(L.searchY + (L.rowH - 15) / 2))
    end
    for i = 1, #sb - 1 do
        sb[i]:ClearAllPoints()
        sb[i]:SetPoint("RIGHT", sb[i + 1], "LEFT", -14, 0)
    end
    for _, b in ipairs(sb) do
        local box = CreateFrame("Frame", nil, b)
        box:SetSize(24, 24)
        box:SetPoint("CENTER")
        box:SetFrameLevel(max(0, b:GetFrameLevel() - 1))
        Box(box, COL.tealD, 0.9)
        b.under:SetTexture(T("AzGlow"))
        b.under:SetVertexColor(COL.teal[1], COL.teal[2], COL.teal[3], 1)
        b.under:SetHeight(5)
        b.under:ClearAllPoints()
        b.under:SetPoint("TOPLEFT", b, "BOTTOMLEFT", -6, -4)
        b.under:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", 6, -4)
    end

    -- busca com lupa
    local s = ui.search
    s:ClearAllPoints()
    s:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -L.searchY)
    s:SetPoint("RIGHT", ui.sortLabel, "LEFT", -14, 0)
    s:SetHeight(L.rowH)
    s:SetBackdropColor(COL.box[1], COL.box[2], COL.box[3], 0.95)
    s:SetBackdropBorderColor(COL.tealD[1], COL.tealD[2], COL.tealD[3], 1)
    s:SetTextInsets(26, 24, 0, 0)
    local lupa = s:CreateTexture(nil, "OVERLAY")
    lupa:SetTexture(T("AzSearch"))
    lupa:SetSize(13, 13)
    lupa:SetPoint("LEFT", 8, 0)
    lupa:SetVertexColor(COL.dim[1], COL.dim[2], COL.dim[3])
    ui.placeholder:ClearAllPoints()
    ui.placeholder:SetPoint("LEFT", s, "LEFT", 26, 0)
    ui.placeholder:SetText("Buscar item...")

    BuildChips(M, frame, pad)

    -- corpo começa abaixo dos chips
    M.bodyTop = L.bodyTop
    ui.scroll:ClearAllPoints()
    ui.scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", pad, -(L.bodyTop + 12))

    -- rodapé
    local rb = ui.radialBtn
    rb:SetSize(104, 24)
    IS.Button(rb, ui.radialText, COL.teal)
    if M.lockBtn then
        M.lockBtn:SetSize(122, 24)
        IS.Button(M.lockBtn, M.lockText, COL.gold)
    end

    -- títulos de seção: dourados, com filete que esmaece para a direita
    M.StyleHeader = function(h)
        Font(h.text, media.fontTitleB, 12, COL.goldL)
        h.hatch:SetTexture(T("AzLine"))
        h.hatch:SetHeight(2)
        h.hatch:SetVertexColor(COL.gold[1], COL.gold[2], COL.gold[3], 0.55)
        h.line1:Hide()
        h.line2:Hide()
        h.btnBg:SetVertexColor(COL.tealD[1] * 0.6, COL.tealD[2] * 0.6, COL.tealD[3] * 0.6, 1)
        Font(h.count, media.fontTitleB, 13, COL.cream)
    end

    -- espaços: textura com aro tingido pela raridade (tinta cheia)
    M.SlotTex = function(kind)
        return T((kind == "gear" and "AzSlotGear") or (kind == "round" and "AzSlotRound") or "AzSlot")
    end
    M.SlotInset = function(kind) return (kind == "round") and 6 or 5 end
    M.QualityK = function() return 1 end

    IS.DressRadial(M)

    M.SkinUpdate = function()
        local used, total = 0, 0
        local API = Azaath.API
        for bag = 0, (Azaath.IS_MODERN and 5 or 4) do
            local n = API.GetContainerNumSlots(bag) or 0
            if not Azaath.IsSecret(n) then
                for slot = 1, n do
                    total = total + 1
                    if API.GetContainerItemInfo(bag, slot) then used = used + 1 end
                end
            end
        end
        IS.count.text:SetText(used .. " / " .. total)
        IS.count:SetWidth(IS.count.text:GetStringWidth() + 18)
        IS.FitTitle(M)
        LayoutChips((M.frame:GetWidth() or 400) - 2 * M.ui.pad)
    end
end
