--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Sheet/Core.lua
    A CONSTELAÇÃO DE AZAATH — Interface de Personagem Frameless 2026 (Tecla C)

    Design 2026 100% livre de caixas quadradas e molduras pesadas (inspirado em
    Chrono Odyssey, Black Myth: Wukong, Elden Ring e Azaath: Aeternum):
      * Zero cards quadrados e zero bordas retangulares pesadas (HUD flutuante,
        orgânica, radial e translúcida).
      * Nodos de Equipamento Circulares em Duplo Arco Orbital: todos os 16 slots
        de armadura/acessórios e 4 armas são medalhões circulares (máscara
        redonda + anéis concêntricos finos + halo de raridade + estrela de
        encantamento) dispostos em uma curva suave ao redor da silhueta do
        personagem, com tipografia flutuante sem caixas ao redor.
      * Palco Atmosférico em Tela Cheia com Geometria Sagrada: Astrolábio
        Celestial de linhas ultrafinas contrarrotativas, Rosa dos Ventos,
        Altar Rúnico no solo com ondas de choque concêntricas, feixes de luz
        volumétricos, dupla hélice 3D de orbes luminosos (passando pela frente
        e por trás do modelo 3D) e partículas estelares em 60 FPS.
      * Códice Flutuante à Direita: véu atmosférico em degradê suave sem bordas,
        4 medidores vitais em feixes luminosos ultrafinos (3px) com faísca
        estelar, 5 Medalhões Circulares de Geometria Sagrada para os Atributos
        Primários, telemetria de combate limpa sem caixas e 5 Orbes Elementais
        Circulares para resistências.
------------------------------------------------------------------------------]]

local ADDON_NAME, Azaath = ...
local U = {}
Azaath.SheetUI = U   -- símbolos compartilhados entre os arquivos de Modules/Sheet/
local M = Azaath:NewModule("Sheet")

local _G = _G
local ipairs, format, min, max, type, pcall, select, tostring, unpack =
    ipairs, string.format, math.min, math.max, type, pcall, select, tostring, unpack

local HEADER_H    = 82
-- Menu superior (arte tools/sheet-nav-concept/concept.png, ~0.85 unidade de UI por px da arte;
-- texturas NavFlare/NavLine/NavChevron saem de tools/sheet-nav-concept/gen.js)
local NAV_Y       = 7     -- centro do bloco do menu acima do centro do cabeçalho
local NAV_TEXT_Y  = 7     -- texto acima do centro do bloco (linha do horizonte fica 14.5 abaixo dele)
local NAV_LINE_Y  = -7.5  -- linha do horizonte / clarão em relação ao centro do bloco
local NAV_GAP     = 26    -- espaço entre os nomes das abas
local NAV_FONT    = 12
local PAD         = 28
local DETAIL_W    = 350
local FOOTER_H    = 38

local MEDIA_ROOT  = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local SHEET_MEDIA = MEDIA_ROOT .. "Sheet\\"
local MAP_MEDIA   = MEDIA_ROOT .. "Minimap\\"
local DLG_MEDIA   = MEDIA_ROOT .. "Dialog\\"
local INV_MEDIA   = MEDIA_ROOT .. "Inventory\\"
local UF_MEDIA    = MEDIA_ROOT .. "UnitFrames\\"

local SLOT_NAMES = {
    HeadSlot          = "Cabeça",
    NeckSlot          = "Amuleto",
    ShoulderSlot      = "Ombros",
    BackSlot          = "Manto",
    ChestSlot         = "Torso",
    ShirtSlot         = "Camisa",
    TabardSlot        = "Tabardo",
    WristSlot         = "Braçadeiras",
    HandsSlot         = "Manoplas",
    WaistSlot         = "Cinturão",
    LegsSlot          = "Grevas",
    FeetSlot          = "Botas",
    Finger0Slot       = "Anel I",
    Finger1Slot       = "Anel II",
    Trinket0Slot      = "Relíquia I",
    Trinket1Slot      = "Relíquia II",
    MainHandSlot      = "Mão Principal",
    SecondaryHandSlot = "Mão Secundária",
    RangedSlot        = "Alcance / Relíquia",
    AmmoSlot          = "Munição",
}

local LEFT_SLOTS   = { "HeadSlot", "NeckSlot", "ShoulderSlot", "BackSlot", "ChestSlot", "ShirtSlot", "TabardSlot", "WristSlot" }
local RIGHT_SLOTS  = { "HandsSlot", "WaistSlot", "LegsSlot", "FeetSlot", "Finger0Slot", "Finger1Slot", "Trinket0Slot", "Trinket1Slot" }
local WEAPON_SLOTS = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot", "AmmoSlot" }

local TABS = {
    { key = "character",   label = "Santuário" },
    { key = "spellbook",   label = "Grimório" },
    { key = "talents",     label = "Talentos" },
    { key = "professions", label = "Ofícios" },
    { key = "drops",       label = "Drops" },
    { key = "dungeons",    label = "Masmorras" },
    { key = "reputation",  label = "Reputação" },
    { key = "skills",      label = "Perícias" },
    { key = "pvp",         label = "Gladiador" },
    { key = "currency",    label = "Tesouro" },
    { key = "stats",       label = "Crônicas" },
}

local SUBTABS = {
    { key = "attributes", label = "Atributos & Combate" },
    { key = "sets",       label = "Arsenal Salvo" },
    { key = "titles",     label = "Títulos" },
}

local STANDING_COLORS = {
    [1] = { 0.85, 0.22, 0.18 }, [2] = { 0.85, 0.34, 0.22 }, [3] = { 0.82, 0.45, 0.22 },
    [4] = { 0.90, 0.75, 0.28 }, [5] = { 0.32, 0.75, 0.35 }, [6] = { 0.25, 0.82, 0.48 },
    [7] = { 0.22, 0.80, 0.68 }, [8] = { 0.28, 0.88, 0.98 },
}

local pages, subPages = {}, {}; U.tabButtons = {}; U.subButtons = {}
U.slots = {}
U.current = "character"; U.currentSub = "attributes"
U.dirty = true

local selected = {}
U.vfxNodes = {}

--------------------------------------------------------------------------------
-- Utilitários Visuais 2026 (Frameless, Circular & Luminoso)
--------------------------------------------------------------------------------
local function Char() return Azaath:GetModule("Character") end

local function CreateText(parent, font, size, color, justify, flags)
    local c = color or Azaath.colors.cream
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or Azaath.media.font, size or 12, flags or "OUTLINE")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.95)
    fs:SetTextColor(c[1], c[2], c[3], c[4] or 1)
    fs:SetJustifyH(justify or "LEFT")
    return fs
end

local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    local res = { pcall(fn, ...) }
    if not res[1] then return nil end
    return select(2, unpack(res))
end

local function Num(v, fallback)
    if v == nil or Azaath.IsSecret(v) then return fallback end
    return v
end

local function Display(v)
    if v == nil then return "—" end
    if Azaath.IsSecret(v) then return v end
    if type(v) == "number" then return Azaath.Thousands(v) end
    return v
end

local function Pct(v)
    v = Num(v, nil)
    if not v then return "—" end
    return format("%.2f%%", v)
end

local function Show(region, on)
    if not region then return end
    if on then region:Show() else region:Hide() end
end

-- Máscara Circular Nativa (compatível com RoundMask.tga da Azaath e TempPortraitAlphaMask)
local function ApplyCircleMask(parent, tex)
    if not (parent and parent.CreateMaskTexture and tex and tex.AddMaskTexture) then return nil end
    local mask = parent:CreateMaskTexture()
    mask:SetAllPoints(tex)
    local ok = pcall(mask.SetTexture, mask, INV_MEDIA .. "RoundMask", "CLAMPTOBLACKADDITIONAL", "CLAMPTOBLACKADDITIONAL")
    if not ok then
        pcall(mask.SetTexture, mask, "Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    pcall(tex.AddMaskTexture, tex, mask)
    return mask
end

-- Feixe de Luz Horizontal Fino (substitui linhas duras e divisores pesados)
local function LightHorizon(parent, width, alpha, r, g, b)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width or 240, 10)

    local beam = holder:CreateTexture(nil, "ARTWORK")
    beam:SetTexture(UF_MEDIA .. "ClassicGlassH")
    beam:SetBlendMode("ADD")
    beam:SetPoint("LEFT", holder, "LEFT", 0, 0)
    beam:SetPoint("RIGHT", holder, "RIGHT", 0, 0)
    beam:SetHeight(3)
    beam:SetVertexColor(r or 0.45, g or 0.85, b or 1.0, alpha or 0.55)

    local gem = holder:CreateTexture(nil, "OVERLAY")
    gem:SetTexture(MEDIA_ROOT .. "Diamond")
    gem:SetSize(7, 7)
    gem:SetPoint("CENTER", holder, "CENTER", 0, 0)
    gem:SetVertexColor(r or 0.65, g or 0.92, b or 1.0, (alpha or 0.55) * 1.3)

    return holder
end

-- Medidor Luminoso Ultrafino 2026 (Sem moldura quadrada! Apenas feixe de luz + faísca estelar)
local function MakeBar(parent, width, height, r, g, b)
    local media = Azaath.media
    local barH = max(3, min(height or 4, 6))
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, max(height or 20, 18))

    local bar = CreateFrame("StatusBar", nil, holder)
    bar:SetSize(width, barH)
    bar:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 0, 2)
    bar:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", 0, 2)
    bar:SetStatusBarTexture(UF_MEDIA .. "HealthFill")
    bar:SetStatusBarColor(r or 0.28, g or 0.82, b or 1.0)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    holder.bar = bar

    -- Trilha escura quase invisível
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetAllPoints(bar)
    track:SetTexture(UF_MEDIA .. "HealthFill")
    track:SetVertexColor(0.08, 0.12, 0.18, 0.65)

    -- Halo difuso sob a barra
    local underGlow = bar:CreateTexture(nil, "BORDER")
    underGlow:SetPoint("TOPLEFT", bar, "TOPLEFT", -4, 3)
    underGlow:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 4, -3)
    underGlow:SetTexture(UF_MEDIA .. "ClassicGlassH")
    underGlow:SetBlendMode("ADD")
    underGlow:SetVertexColor(r or 0.28, g or 0.82, b or 1.0, 0.25)
    holder.underGlow = underGlow

    -- Estrela luminosa na ponta da barra
    local spark = bar:CreateTexture(nil, "OVERLAY")
    spark:SetTexture(MEDIA_ROOT .. "Star")
    spark:SetBlendMode("ADD")
    spark:SetSize(18, 18)
    spark:SetVertexColor(0.85, 0.96, 1.0, 0.90)
    spark:SetPoint("CENTER", bar, "LEFT", 0, 0)
    holder.spark = spark

    holder.left = CreateText(holder, media.font, 11, { 0.78, 0.86, 0.95 }, "LEFT", "OUTLINE")
    holder.left:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, 0)
    holder.right = CreateText(holder, media.fontTitleB, 11, { 1, 1, 1 }, "RIGHT", "OUTLINE")
    holder.right:SetPoint("TOPRIGHT", holder, "TOPRIGHT", 0, 0)

    function holder:SetStatusBarColor(cr, cg, cb)
        self.bar:SetStatusBarColor(cr, cg, cb)
        self.underGlow:SetVertexColor(cr, cg, cb, 0.28)
    end
    function holder:GetWidth()
        return self.bar:GetWidth()
    end
    return holder
end

local function SetBar(holder, cur, mx)
    local bar = holder.bar or holder
    if Azaath.AnySecret(cur, mx) then
        bar:SetMinMaxValues(0, mx)
        bar:SetValue(cur)
        if holder.spark then holder.spark:Hide() end
        return
    end
    mx = (mx and mx > 0) and mx or 1
    local val = max(0, min(cur or 0, mx))
    bar:SetMinMaxValues(0, mx)
    bar:SetValue(val)
    if holder.spark then
        local ratio = val / mx
        if ratio > 0.01 and ratio < 0.995 then
            holder.spark:ClearAllPoints()
            holder.spark:SetPoint("CENTER", bar, "LEFT", bar:GetWidth() * ratio, 0)
            holder.spark:Show()
        else
            holder.spark:Hide()
        end
    end
end

-- Botão Flutuante Minimalista 2026 (Sem caixa retangular; halo suave + feixe inferior)
local function MakeButton(parent, label, width, onClick)
    local c, media = Azaath.colors, Azaath.media
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 28)

    local aura = b:CreateTexture(nil, "BACKGROUND")
    aura:SetAllPoints(b)
    aura:SetTexture(UF_MEDIA .. "ClassicGlassH")
    aura:SetVertexColor(0.16, 0.24, 0.36, 0.55)
    b.aura = aura

    local line = b:CreateTexture(nil, "ARTWORK")
    line:SetTexture(UF_MEDIA .. "ClassicGlassH")
    line:SetBlendMode("ADD")
    line:SetHeight(2)
    line:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 6, 2)
    line:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -6, 2)
    line:SetVertexColor(0.45, 0.85, 1.0, 0.55)
    b.line = line

    local star = b:CreateTexture(nil, "OVERLAY")
    star:SetTexture(MEDIA_ROOT .. "Star")
    star:SetBlendMode("ADD")
    star:SetSize(16, 16)
    star:SetPoint("CENTER", line, "CENTER", 0, 0)
    star:SetVertexColor(0.55, 0.92, 1.0, 0.85)
    star:Hide()
    b.star = star

    b.text = CreateText(b, media.fontTitleB, 11, c.cream, "CENTER", "OUTLINE")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 1)
    b.text:SetText(Azaath.Tracked(label))

    b:SetScript("OnEnter", function(self)
        if self.disabled then return end
        self.aura:SetVertexColor(0.28, 0.65, 0.95, 0.45)
        self.line:SetVertexColor(0.65, 0.95, 1.0, 1.0)
        self.star:Show()
        self.text:SetTextColor(1, 1, 1)
    end)
    b:SetScript("OnLeave", function(self)
        self.aura:SetVertexColor(0.16, 0.24, 0.36, 0.55)
        self.line:SetVertexColor(0.45, 0.85, 1.0, 0.55)
        self.star:Hide()
        local col = self.disabled and c.dim or c.cream
        self.text:SetTextColor(col[1], col[2], col[3])
    end)
    b:SetScript("OnClick", function(self, button)
        if self.disabled then return end
        Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        onClick(self, button)
    end)
    function b:SetEnabledLook(on)
        self.disabled = not on
        local col = on and c.cream or c.dim
        self.text:SetTextColor(col[1], col[2], col[3])
        self:SetAlpha(on and 1.0 or 0.40)
    end
    return b
end

-- Seleção Circular Minimalista
local function MakeCheck(parent, label, onClick)
    local c, media = Azaath.colors, Azaath.media
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(DETAIL_W - 32, 22)

    b.ring = b:CreateTexture(nil, "ARTWORK")
    b.ring:SetSize(16, 16)
    b.ring:SetPoint("LEFT", b, "LEFT", 0, 0)
    b.ring:SetTexture(MEDIA_ROOT .. "Ring")
    b.ring:SetVertexColor(0.65, 0.78, 0.92, 0.85)

    b.dot = b:CreateTexture(nil, "OVERLAY")
    b.dot:SetSize(10, 10)
    b.dot:SetPoint("CENTER", b.ring, "CENTER", 0, 0)
    b.dot:SetTexture(MEDIA_ROOT .. "Glow")
    b.dot:SetBlendMode("ADD")
    b.dot:SetVertexColor(0.38, 0.92, 1.0, 1.0)

    b.text = CreateText(b, media.font, 12, c.cream)
    b.text:SetPoint("LEFT", b.ring, "RIGHT", 10, 0)
    b.text:SetText(label)

    b:SetScript("OnClick", function(self)
        if self.disabled then return end
        Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        onClick(self)
    end)
    function b:Set(checked, enabled)
        Show(self.dot, checked)
        self.disabled = not enabled
        local col = enabled and c.cream or c.dim
        self.text:SetTextColor(col[1], col[2], col[3])
    end
    return b
end

--------------------------------------------------------------------------------
-- Lista Flutuante 2026 (Sem Molduras Quadradas, Feixes Suaves)
--------------------------------------------------------------------------------
local LIST_HEADER_H, LIST_ROW_H = 32, 30

local ListMixin = {}

function ListMixin:UpdateThumb()
    local range = self.scroll:GetVerticalScrollRange()
    local h = self.scroll:GetHeight()
    if range <= 0 then self.thumb:Hide(); return end
    self.thumb:Show()
    local th = max(24, h * h / (h + range))
    self.thumb:SetHeight(th)
    self.thumb:ClearAllPoints()
    self.thumb:SetPoint("TOPRIGHT", self.track, "TOPRIGHT", 0, -(h - th) * (self.scroll:GetVerticalScroll() / range))
end

function ListMixin:GetRow(i)
    local row = self.rows[i]
    if row then return row end
    local c, media = Azaath.colors, Azaath.media
    row = CreateFrame("Button", nil, self.child)
    row:SetWidth(self.width)
    row:RegisterForClicks("LeftButtonUp")

    row.sel = row:CreateTexture(nil, "BACKGROUND")
    row.sel:SetAllPoints(row)
    row.sel:SetTexture(DLG_MEDIA .. "OptionHover")
    row.sel:SetBlendMode("ADD")
    row.sel:SetVertexColor(0.28, 0.85, 1.0, 0.38)
    row.sel:Hide()

    row.hover = row:CreateTexture(nil, "BORDER")
    row.hover:SetAllPoints(row)
    row.hover:SetTexture(DLG_MEDIA .. "OptionHover")
    row.hover:SetBlendMode("ADD")
    row.hover:SetVertexColor(0.85, 0.92, 1.0, 0.18)
    row.hover:Hide()

    row.bottomBeam = row:CreateTexture(nil, "BORDER")
    row.bottomBeam:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 0)
    row.bottomBeam:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 0)
    row.bottomBeam:SetHeight(1)
    row.bottomBeam:SetTexture(UF_MEDIA .. "ClassicGlassH")
    row.bottomBeam:SetVertexColor(0.45, 0.72, 0.95, 0.18)

    row.pip = row:CreateTexture(nil, "ARTWORK")
    row.pip:SetSize(8, 8)
    row.pip:SetTexture(MEDIA_ROOT .. "Diamond")

    row.marker = CreateText(row, media.fontTitleB, 13, c.gold, "CENTER")
    row.marker:SetWidth(14)

    row.iconHolder = CreateFrame("Frame", nil, row)
    row.iconHolder:SetSize(22, 22)
    row.icon = row.iconHolder:CreateTexture(nil, "ARTWORK")
    row.icon:SetAllPoints(row.iconHolder)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ApplyCircleMask(row.iconHolder, row.icon)
    row.iconRing = row.iconHolder:CreateTexture(nil, "OVERLAY")
    row.iconRing:SetPoint("TOPLEFT", row.iconHolder, "TOPLEFT", -2, 2)
    row.iconRing:SetPoint("BOTTOMRIGHT", row.iconHolder, "BOTTOMRIGHT", 2, -2)
    row.iconRing:SetTexture(MEDIA_ROOT .. "Ring")
    row.iconRing:SetVertexColor(0.75, 0.85, 0.98, 0.85)

    row.name = CreateText(row, media.font, 13, c.cream)
    row.value = CreateText(row, media.fontTitleB, 12, { 0.95, 0.98, 1 }, "RIGHT")
    row.value:SetPoint("RIGHT", row, "RIGHT", -12, 0)

    row.bar = MakeBar(row, self.barW, 4, 0.3, 0.75, 0.95)
    row.bar:SetPoint("RIGHT", row, "RIGHT", -12, 0)

    row:SetScript("OnClick", function(r)
        if r.entry and r.entry.onClick then
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            r.entry.onClick()
        end
    end)
    row:SetScript("OnEnter", function(r)
        r.hover:Show()
        local e = r.entry
        if e and e.tooltip then
            GameTooltip:SetOwner(r, "ANCHOR_RIGHT")
            GameTooltip:SetText(e.name, 1, 1, 1)
            GameTooltip:AddLine(e.tooltip, c.cream[1], c.cream[2], c.cream[3], true)
            GameTooltip:Show()
        end
    end)
    row:SetScript("OnLeave", function(r)
        r.hover:Hide()
        GameTooltip:Hide()
    end)
    self.rows[i] = row
    return row
end

function ListMixin:SetEntries(entries)
    local c, media = Azaath.colors, Azaath.media
    local y = 0
    for i, e in ipairs(entries) do
        local row = self:GetRow(i)
        row.entry = e
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -y)
        local x = 8 + (e.depth or 0) * 16
        Show(row.sel, e.selected)

        if e.header then
            row:SetHeight(LIST_HEADER_H)
            row.bottomBeam:SetVertexColor(0.95, 0.82, 0.45, 0.55)
            row.pip:ClearAllPoints()
            row.pip:SetPoint("LEFT", row, "LEFT", x, 0)
            row.pip:SetVertexColor(0.95, 0.82, 0.45, 0.95)
            row.pip:Show()

            row.marker:ClearAllPoints()
            row.marker:SetPoint("LEFT", row.pip, "RIGHT", 4, 0)
            row.marker:SetText(e.collapsed == nil and "" or (e.collapsed and "+" or "–"))
            row.marker:Show()

            row.name:SetFont(media.fontTitleB, 11, "OUTLINE")
            row.name:SetTextColor(0.96, 0.84, 0.48)
            row.name:SetText(Azaath.Tracked(e.name or ""))
            row.name:ClearAllPoints()
            row.name:SetPoint("LEFT", row.marker, "RIGHT", 4, 0)
            row.iconHolder:Hide()
            y = y + LIST_HEADER_H + 2
        else
            row:SetHeight(LIST_ROW_H)
            row.bottomBeam:SetVertexColor(0.45, 0.72, 0.95, 0.16)
            row.marker:Hide()
            row.pip:ClearAllPoints()
            row.pip:SetPoint("LEFT", row, "LEFT", x, 0)
            row.pip:SetVertexColor(e.selected and 0.38 or 0.55, e.selected and 0.92 or 0.68, e.selected and 1.0 or 0.82, e.selected and 1.0 or 0.45)
            row.pip:Show()

            row.name:SetFont(media.font, 13, "OUTLINE")
            local col = e.dim and c.dim or (e.selected and { 1, 1, 1 } or c.cream)
            row.name:SetTextColor(col[1], col[2], col[3])
            row.name:SetText(e.name or "")
            row.name:ClearAllPoints()
            if e.icon then
                row.icon:SetTexture(e.icon)
                row.iconHolder:ClearAllPoints()
                row.iconHolder:SetPoint("LEFT", row.pip, "RIGHT", 8, 0)
                row.iconHolder:Show()
                row.name:SetPoint("LEFT", row.iconHolder, "RIGHT", 8, 0)
            else
                row.iconHolder:Hide()
                row.name:SetPoint("LEFT", row.pip, "RIGHT", 8, 0)
            end
            y = y + LIST_ROW_H + 1
        end

        if e.bar then
            local b = e.bar
            row.bar:SetStatusBarColor(b.r or 0.3, b.g or 0.7, b.b or 0.95)
            SetBar(row.bar, b.cur, b.max)
            row.bar.left:SetText(b.label or "")
            row.bar.right:SetText(b.text or "")
            row.bar:Show()
            row.value:Hide()
        else
            row.bar:Hide()
            row.value:SetText(e.value or "")
            row.value:Show()
        end
        row:Show()
    end
    for i = #entries + 1, #self.rows do self.rows[i]:Hide() end
    Show(self.empty, #entries == 0)
    self.child:SetHeight(max(1, y))
    self.scroll:UpdateScrollChildRect()
    local range = self.scroll:GetVerticalScrollRange()
    if self.scroll:GetVerticalScroll() > range then self.scroll:SetVerticalScroll(range) end
    self:UpdateThumb()
end

local function List_Scroll(self, delta)
    local v = self:GetVerticalScroll() - delta * LIST_ROW_H * 3
    self:SetVerticalScroll(max(0, min(v, self:GetVerticalScrollRange())))
    self.list:UpdateThumb()
end

local function NewList(parent, x, y, width, height, emptyText, barW)
    local c, media = Azaath.colors, Azaath.media
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    holder:SetSize(width, height)

    local veil = holder:CreateTexture(nil, "BACKGROUND")
    veil:SetAllPoints(holder)
    veil:SetTexture(MEDIA_ROOT .. "Glow")
    veil:SetVertexColor(0.03, 0.06, 0.11, 0.45)

    local L = setmetatable({ rows = {}, width = width - 16, barW = barW or 230, vault = holder }, { __index = ListMixin })
    L.scroll = CreateFrame("ScrollFrame", nil, holder)
    L.scroll:SetPoint("TOPLEFT", holder, "TOPLEFT", 0, -4)
    L.scroll:SetSize(width - 14, height - 8)
    L.scroll:EnableMouseWheel(true)
    L.scroll.list = L
    L.scroll:SetScript("OnMouseWheel", List_Scroll)
    L.child = CreateFrame("Frame", nil, L.scroll)
    L.child:SetSize(width - 14, 1)
    L.scroll:SetScrollChild(L.child)

    L.track = holder:CreateTexture(nil, "BORDER")
    L.track:SetTexture(UF_MEDIA .. "HealthFill")
    L.track:SetVertexColor(0.15, 0.22, 0.32, 0.35)
    L.track:SetSize(2, height - 8)
    L.track:SetPoint("TOPRIGHT", holder, "TOPRIGHT", -2, -4)

    L.thumb = holder:CreateTexture(nil, "ARTWORK")
    L.thumb:SetTexture(UF_MEDIA .. "HealthFill")
    L.thumb:SetVertexColor(0.42, 0.88, 1.0, 0.85)
    L.thumb:SetWidth(2)

    L.empty = CreateText(holder, media.fontTitleB, 13, c.dim, "CENTER")
    L.empty:SetPoint("CENTER", holder, "CENTER", 0, 0)
    L.empty:SetWidth(width - 40)
    L.empty:SetText(emptyText or "Nenhum registro encontrado.")
    L.empty:Hide()
    return L
end

--------------------------------------------------------------------------------
-- Painel Flutuante de Detalhes (Sem Moldura Quadrada)
--------------------------------------------------------------------------------
local DetailMixin = {}

function DetailMixin:Set(data)
    local f = self.frame
    if not data then
        for _, r in ipairs({ self.title, self.subtitle, self.div, self.bar, self.text, self.extra }) do r:Hide() end
        for _, cb in ipairs(self.checks) do cb:Hide() end
        for _, b in ipairs(self.buttons) do b:Hide() end
        self.empty:SetText(self.emptyText)
        self.empty:Show()
        return
    end
    self.empty:Hide()
    local y = 18
    local function Place(region, h, gap)
        region:ClearAllPoints()
        region:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -y)
        region:Show()
        y = y + h + (gap or 10)
    end
    self.title:SetText(Azaath.Tracked(data.title or ""))
    Place(self.title, 22, 4)
    if data.subtitle then
        self.subtitle:SetText(data.subtitle)
        Place(self.subtitle, 16, 8)
    else
        self.subtitle:Hide()
    end
    Place(self.div, 10, 14)
    if data.bar then
        local b = data.bar
        self.bar:SetStatusBarColor(b.r or 0.3, b.g or 0.75, b.b or 0.95)
        SetBar(self.bar, b.cur, b.max)
        self.bar.left:SetText(b.label or "")
        self.bar.right:SetText(b.text or "")
        Place(self.bar, 22, 16)
    else
        self.bar:Hide()
    end
    for _, key in ipairs({ "text", "extra" }) do
        local fs = self[key]
        if data[key] and data[key] ~= "" then
            fs:SetText(data[key])
            Place(fs, fs:GetStringHeight(), 14)
        else
            fs:Hide()
        end
    end
    for i, cb in ipairs(self.checks) do
        local d = data.checks and data.checks[i]
        if d then
            cb.text:SetText(d.label)
            cb.onToggle = d.onClick
            cb:Set(d.checked, d.enabled ~= false)
            Place(cb, 22, 6)
        else
            cb:Hide()
        end
    end
    local bx = 18
    for i, b in ipairs(self.buttons) do
        local d = data.buttons and data.buttons[i]
        if d then
            b.text:SetText(Azaath.Tracked(d.label))
            b.handler = d.onClick
            b:SetEnabledLook(d.enabled ~= false)
            b:ClearAllPoints()
            b:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", bx, 16)
            b:Show()
            bx = bx + b:GetWidth() + 10
        else
            b:Hide()
        end
    end
end

local function NewDetail(parent, x, y, w, h, emptyText)
    local c, media = Azaath.colors, Azaath.media
    local D = setmetatable({ checks = {}, buttons = {}, emptyText = emptyText or "Selecione um item para inspecionar." },
        { __index = DetailMixin })
    local f = CreateFrame("Frame", nil, parent)
    f:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -y)
    f:SetSize(w, h)

    local aura = f:CreateTexture(nil, "BACKGROUND")
    aura:SetAllPoints(f)
    aura:SetTexture(MEDIA_ROOT .. "Glow")
    aura:SetVertexColor(0.04, 0.08, 0.14, 0.60)

    local ringBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    ringBg:SetSize(w * 0.85, w * 0.85)
    ringBg:SetPoint("CENTER", f, "CENTER", 0, 0)
    ringBg:SetTexture(SHEET_MEDIA .. "AstrolabeRing")
    ringBg:SetBlendMode("ADD")
    ringBg:SetVertexColor(0.28, 0.75, 1.0, 0.12)

    D.frame = f
    D.title = CreateText(f, media.fontTitleB, 16, { 0.98, 0.92, 0.72 })
    D.title:SetWidth(w - 36)
    D.subtitle = CreateText(f, media.fontBold, 13, { 0.42, 0.90, 1.0 })
    D.subtitle:SetWidth(w - 36)
    D.div = LightHorizon(f, w - 36, 0.65)
    D.bar = MakeBar(f, w - 36, 4, 0.3, 0.75, 0.95)
    D.text = CreateText(f, media.font, 13, c.cream)
    D.text:SetWidth(w - 36)
    D.text:SetSpacing(3)
    D.extra = CreateText(f, media.font, 12, c.dim)
    D.extra:SetWidth(w - 36)
    D.extra:SetSpacing(3)
    for i = 1, 3 do
        local cb = MakeCheck(f, "", function(self) if self.onToggle then self.onToggle() end end)
        cb:Hide()
        D.checks[i] = cb
    end
    for i = 1, 3 do
        local b = MakeButton(f, "", 115, function(self) if self.handler then self.handler(self) end end)
        b:Hide()
        D.buttons[i] = b
    end
    D.empty = CreateText(f, media.fontTitleB, 13, c.dim, "CENTER")
    D.empty:SetPoint("CENTER", f, "CENTER", 0, 0)
    D.empty:SetWidth(w - 48)
    D:Set(nil)
    return D
end

--------------------------------------------------------------------------------
-- Dados: Reputação, Perícias, Moedas, Estatísticas e JxJ
--------------------------------------------------------------------------------
local CR = _G.C_Reputation

local function FactionCount()
    if CR and CR.GetNumFactions then return CR.GetNumFactions() or 0 end
    return Call(_G.GetNumFactions) or 0
end

local function FactionData(i)
    if CR and CR.GetFactionDataByIndex then
        local d = CR.GetFactionDataByIndex(i)
        if not d then return nil end
        local inactive = CR.IsFactionActive and not CR.IsFactionActive(i)
        return {
            name = d.name, desc = d.description, standing = d.reaction,
            min = d.currentReactionThreshold, max = d.nextReactionThreshold, value = d.currentStanding,
            isHeader = d.isHeader, collapsed = d.isCollapsed, hasRep = d.isHeaderWithRep, isChild = d.isChild,
            atWar = d.atWarWith, canWar = d.canToggleAtWar, watched = d.isWatched,
            canInactive = d.canSetInactive, inactive = inactive,
        }
    end
    if not _G.GetFactionInfo then return nil end
    local name, desc, standing, barMin, barMax, barValue, atWar, canWar, isHeader, collapsed, hasRep, watched, isChild = GetFactionInfo(i)
    if not name then return nil end
    return { name = name, desc = desc, standing = standing, min = barMin, max = barMax, value = barValue,
             isHeader = isHeader, collapsed = collapsed, hasRep = hasRep, isChild = isChild,
             atWar = atWar, canWar = canWar, watched = watched, canInactive = not isHeader,
             inactive = Call(_G.IsFactionInactive, i) }
end

local function StandingLabel(id)
    return _G["FACTION_STANDING_LABEL" .. tostring(id)] or ""
end

local function StandingBar(d)
    if not (d.max and d.min) or Azaath.AnySecret(d.min, d.max, d.value) then return nil end
    local col = STANDING_COLORS[d.standing] or STANDING_COLORS[4]
    if _G.FACTION_BAR_COLORS and FACTION_BAR_COLORS[d.standing] then
        local fc = FACTION_BAR_COLORS[d.standing]
        col = { fc.r, fc.g, fc.b }
    end
    local span = max(1, d.max - d.min)
    return { cur = (d.value or 0) - d.min, max = span, r = col[1], g = col[2], b = col[3], standing = d.standing,
             label = StandingLabel(d.standing),
             text = format("%s / %s", Azaath.Thousands((d.value or 0) - d.min), Azaath.Thousands(span)) }
end

local function CollectReputation()
    local list = {}
    for i = 1, FactionCount() do
        local d = FactionData(i)
        if d and d.name then
            local idx = i
            local e = { name = d.name, depth = d.isChild and 1 or 0 }
            if d.isHeader then
                e.header = true
                e.collapsed = d.collapsed and true or false
                local col = d.collapsed
                e.onClick = function()
                    local fn = col and ((CR and CR.ExpandFactionHeader) or _G.ExpandFactionHeader)
                        or ((CR and CR.CollapseFactionHeader) or _G.CollapseFactionHeader)
                    Call(fn, idx)
                    U.dirty = true
                end
            else
                e.selected = selected.reputation == d.name
                e.dim = d.inactive
                e.onClick = function() selected.reputation = d.name; U.dirty = true end
            end
            if not d.isHeader or d.hasRep then e.bar = StandingBar(d) end
            list[#list + 1] = e
        end
    end
    return list
end

local function ReputationDetail()
    if not selected.reputation then return nil end
    for i = 1, FactionCount() do
        local d = FactionData(i)
        if d and d.name == selected.reputation and not d.isHeader then
            local idx = i
            return {
                title = d.name,
                subtitle = StandingLabel(d.standing),
                standing = d.standing,
                bar = StandingBar(d),
                text = d.desc,
                checks = {
                    { label = "Declarar Guerra", checked = d.atWar, enabled = d.canWar, onClick = function()
                        Call((CR and CR.ToggleFactionAtWar) or _G.FactionToggleAtWar, idx); U.dirty = true end },
                    { label = "Mover para Inativos", checked = d.inactive, enabled = d.canInactive ~= false, onClick = function()
                        if CR and CR.SetFactionActive then
                            Call(CR.SetFactionActive, idx, d.inactive and true or false)
                        elseif d.inactive then Call(_G.SetFactionActive, idx) else Call(_G.SetFactionInactive, idx) end
                        U.dirty = true end },
                    { label = "Acompanhar na Barra de Experiência", checked = d.watched, onClick = function()
                        local target = d.watched and 0 or idx
                        Call((CR and CR.SetWatchedFactionByIndex) or _G.SetWatchedFactionIndex, target); U.dirty = true end },
                },
            }
        end
    end
    return nil
end

local SI = _G.C_SkillInfo

local function SkillCount()
    if SI and SI.GetNumSkillLines then return SI.GetNumSkillLines() or 0 end
    return Call(_G.GetNumSkillLines) or 0
end

local function SkillData(i)
    if SI and SI.GetSkillLineInfo then
        local d = SI.GetSkillLineInfo(i)
        if not d then return nil end
        return { name = d.name, isHeader = d.isHeader, collapsed = d.isCollapsed, rank = d.rank,
                 temp = d.tempPoints, modifier = d.modifier, maxRank = d.maxRank, abandonable = d.isAbandonable,
                 desc = d.description, parent = d.parentSkillLineID }
    end
    if not _G.GetSkillLineInfo then return nil end
    local name, isHeader, isExpanded, rank, temp, modifier, maxRank, abandonable, _, _, _, _, desc = GetSkillLineInfo(i)
    if not name then return nil end
    return { name = name, isHeader = isHeader, collapsed = not isExpanded, rank = rank, temp = temp,
             modifier = modifier, maxRank = maxRank, abandonable = abandonable, desc = desc }
end

local function SkillBar(d)
    local rank, maxRank, mod = Num(d.rank, 0), Num(d.maxRank, 0), Num(d.modifier, 0)
    if maxRank <= 1 then return nil end
    local text = format("%d / %d", rank, maxRank)
    if mod ~= 0 then text = format("%d (%+d) / %d", rank, mod, maxRank) end
    return { cur = rank, max = maxRank, r = 0.28, g = 0.80, b = 1.0, text = text }
end

local function CollectSkills()
    local list = {}
    for i = 1, SkillCount() do
        local d = SkillData(i)
        if d and d.name and not (d.parent and Num(d.parent, 0) ~= 0) then
            local idx = i
            local e = { name = d.name }
            if d.isHeader then
                e.header = true
                e.collapsed = d.collapsed and true or false
                local col = d.collapsed
                e.onClick = function()
                    if col then
                        Call((SI and SI.ExpandSkillHeader) or _G.ExpandSkillHeader, idx)
                    else
                        Call((SI and SI.CollapseSkillHeader) or _G.CollapseSkillHeader, idx)
                    end
                    U.dirty = true
                end
            else
                e.bar = SkillBar(d)
                if not e.bar then e.value = Num(d.rank, 0) > 0 and "Dominada" or "" end
                e.selected = selected.skills == d.name
                e.onClick = function() selected.skills = d.name; selected.abandon = nil; U.dirty = true end
            end
            list[#list + 1] = e
        end
    end
    return list
end

local function SkillDetail()
    if not selected.skills then return nil end
    for i = 1, SkillCount() do
        local d = SkillData(i)
        if d and d.name == selected.skills and not d.isHeader and not (d.parent and Num(d.parent, 0) ~= 0) then
            local idx = i
            local data = { title = d.name, bar = SkillBar(d), text = d.desc ~= "" and d.desc or nil }
            if d.abandonable then
                local confirming = selected.abandon == d.name
                data.extra = confirming and "|cffff6050Clique em \"Confirmar\" para desaprender. Todo o progresso nesta perícia será perdido.|r" or nil
                data.buttons = {
                    { label = confirming and "Confirmar" or "Abandonar", onClick = function()
                        if confirming then
                            Call((SI and SI.AbandonSkill) or _G.AbandonSkill, idx)
                            selected.skills, selected.abandon = nil, nil
                        else
                            selected.abandon = d.name
                        end
                        U.dirty = true
                    end },
                    confirming and { label = "Cancelar", onClick = function() selected.abandon = nil; U.dirty = true end } or nil,
                }
            end
            return data
        end
    end
    return nil
end

local CC = _G.C_CurrencyInfo

local function CurrencyData(i)
    if CC and CC.GetCurrencyListInfo then
        local d = CC.GetCurrencyListInfo(i)
        if not d then return nil end
        return { name = d.name, isHeader = d.isHeader, expanded = d.isHeaderExpanded, count = d.quantity,
                 icon = d.iconFileID, maxQ = d.maxQuantity, desc = d.description }
    end
    if not _G.GetCurrencyListInfo then return nil end
    local name, isHeader, expanded, _, _, count, _, icon = GetCurrencyListInfo(i)
    if not name then return nil end
    return { name = name, isHeader = isHeader, expanded = expanded, count = count, icon = icon }
end

local function CurrencyCount()
    return (CC and CC.GetCurrencyListSize and CC.GetCurrencyListSize()) or Call(_G.GetCurrencyListSize) or 0
end

local function CurrencyValue(d)
    local q, mq = Num(d.count, 0), Num(d.maxQ, 0)
    return (mq > 0) and format("%s / %s", Azaath.Thousands(q), Azaath.Thousands(mq)) or Azaath.Thousands(q)
end

local function CollectCurrency()
    local list = {
        { header = true, name = "Tesouro Real" },
        { name = "Ouro do Império", icon = "Interface\\Icons\\INV_Misc_Coin_01", value = Azaath.FormatMoney(GetMoney()),
          selected = selected.currency == "__gold", onClick = function() selected.currency = "__gold"; U.dirty = true end },
    }
    for i = 1, CurrencyCount() do
        local d = CurrencyData(i)
        if d and d.name then
            local idx = i
            local e = { name = d.name }
            if d.isHeader then
                e.header = true
                e.collapsed = not d.expanded
                local open = d.expanded
                e.onClick = function()
                    if CC and CC.ExpandCurrencyList then Call(CC.ExpandCurrencyList, idx, not open)
                    else Call(_G.ExpandCurrencyList, idx, open and 0 or 1) end
                    U.dirty = true
                end
            else
                e.icon = d.icon
                e.value = CurrencyValue(d)
                e.selected = selected.currency == d.name
                e.onClick = function() selected.currency = d.name; U.dirty = true end
            end
            list[#list + 1] = e
        end
    end
    return list
end

local function CurrencyDetail()
    if selected.currency == "__gold" then
        return { title = "Ouro do Império", subtitle = Azaath.FormatMoney(GetMoney()),
                 text = "Moeda soberana utilizada com mercadores, mestres de forja, instrutores e na Casa de Leilões." }
    end
    if not selected.currency then return nil end
    for i = 1, CurrencyCount() do
        local d = CurrencyData(i)
        if d and d.name == selected.currency and not d.isHeader then
            return { title = d.name, subtitle = "Reserva: " .. CurrencyValue(d), text = d.desc }
        end
    end
    return nil
end

local function StatCategories()
    local r = Call(_G.GetStatisticsCategoryList)
    local ids = type(r) == "table" and r or { Call(_G.GetStatisticsCategoryList) }
    local cats, byId = {}, {}
    for _, id in ipairs(ids) do
        local name, parent = Call(_G.GetCategoryInfo, id)
        if name then
            local c = { id = id, name = name, parent = parent, kids = {} }
            cats[#cats + 1] = c
            byId[id] = c
        end
    end
    local top = {}
    for _, c in ipairs(cats) do
        local p = c.parent and byId[c.parent]
        if p then p.kids[#p.kids + 1] = c else top[#top + 1] = c end
    end
    return top
end

local function CollectStatCategories()
    local list = {}
    local top = StatCategories()
    if not selected.statsCat and top[1] then selected.statsCat = top[1].id end
    for _, c in ipairs(top) do
        local id = c.id
        list[#list + 1] = { name = c.name, selected = selected.statsCat == id,
                            onClick = function() selected.statsCat = id; U.dirty = true end }
    end
    return list
end

local function StatRowsFor(cat, list, depth)
    local n = Call(_G.GetCategoryNumAchievements, cat.id) or 0
    for i = 1, n do
        local id, name = Call(_G.GetAchievementInfo, cat.id, i)
        if id and name then
            local v = Call(_G.GetStatistic, id)
            list[#list + 1] = { name = name, value = (v and v ~= "") and v or "—", depth = depth }
        end
    end
end

local function CollectStats()
    local list = {}
    for _, c in ipairs(StatCategories()) do
        if c.id == selected.statsCat then
            list[#list + 1] = { header = true, name = c.name }
            StatRowsFor(c, list, 0)
            for _, kid in ipairs(c.kids) do
                list[#list + 1] = { header = true, name = kid.name, depth = 1 }
                StatRowsFor(kid, list, 1)
            end
        end
    end
    return list
end

local function ListPage(page, cw, ch, collect, detailFn, emptyText, detailEmpty)
    local lw = cw - DETAIL_W - 24
    page.list = NewList(page, 0, 0, lw, ch, emptyText, 240)
    page.collect = collect
    page.detail = NewDetail(page, cw - DETAIL_W, 0, DETAIL_W, ch, detailEmpty)
    page.detailFn = detailFn
end

-- compartilhado com os outros arquivos da ficha
U.ApplyCircleMask, U.Call, U.Char, U.CollectCurrency = ApplyCircleMask, Call, Char, CollectCurrency
U.CollectReputation, U.CollectSkills, U.CollectStatCategories, U.CollectStats = CollectReputation, CollectSkills, CollectStatCategories, CollectStats
U.CreateText, U.CurrencyDetail, U.DETAIL_W, U.Display = CreateText, CurrencyDetail, DETAIL_W, Display
U.FOOTER_H, U.HEADER_H, U.INV_MEDIA, U.LEFT_SLOTS = FOOTER_H, HEADER_H, INV_MEDIA, LEFT_SLOTS
U.ListPage, U.M, U.MAP_MEDIA, U.MEDIA_ROOT = ListPage, M, MAP_MEDIA, MEDIA_ROOT
U.MakeBar, U.MakeButton, U.NAV_FONT, U.NAV_GAP = MakeBar, MakeButton, NAV_FONT, NAV_GAP
U.NAV_LINE_Y, U.NAV_TEXT_Y, U.NAV_Y, U.NewDetail = NAV_LINE_Y, NAV_TEXT_Y, NAV_Y, NewDetail
U.NewList, U.Num, U.PAD, U.Pct = NewList, Num, PAD, Pct
U.RIGHT_SLOTS, U.ReputationDetail, U.SHEET_MEDIA, U.SI = RIGHT_SLOTS, ReputationDetail, SHEET_MEDIA, SI
U.SLOT_NAMES, U.STANDING_COLORS, U.SUBTABS, U.SetBar = SLOT_NAMES, STANDING_COLORS, SUBTABS, SetBar
U.Show, U.SkillCount, U.SkillData, U.SkillDetail = Show, SkillCount, SkillData, SkillDetail
U.TABS, U.UF_MEDIA, U.WEAPON_SLOTS, U.pages = TABS, UF_MEDIA, WEAPON_SLOTS, pages
U.selected, U.subPages = selected, subPages
