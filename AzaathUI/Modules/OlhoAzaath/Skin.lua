--[[----------------------------------------------------------------------------
    AzaathUI - Olho de Azaath / Skin.lua
    Peças visuais da janela do Olho, no estilo do painel do AzaathUI (paleta,
    fontes, moldura e cartões de Azaath.ConfigUI). Nada aqui conhece ajustes:
    cada controle recebe funções para ler e gravar.

    Controles devolvidos têm :Refresh() (relê o valor) e :SetActive(bool).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local ns = Azaath.OlhoNS

local floor, max, min = math.floor, math.max, math.min
local K = {}
ns.Skin = K

local ART = "Interface\\AddOns\\AzaathUI\\Media\\"
K.PORTRAIT = ns.MEDIA .. "portrait.tga"

local function UI() return Azaath.ConfigUI end
local function C() return Azaath.ConfigUI.C end
local function Font(kind) local m = Azaath.media return (kind == "title" and m.fontTitleB) or (kind == "bold" and m.fontBold) or m.font end

function K.Text(parent, size, color, kind)
    return UI().Text(parent, size, color, Font(kind))
end

local function Tip(owner, title, body, extra)
    UI().Tooltip(owner, title, body, extra)
end
K.Tip = Tip
local function HideTip() GameTooltip:Hide() end

-- dica com textos relidos na hora (o idioma pode mudar com a janela aberta)
function K.HoverTip(frame, titleFn, bodyFn)
    frame:HookScript("OnEnter", function(self) Tip(self, titleFn(), bodyFn and bodyFn() or nil) end)
    frame:HookScript("OnLeave", HideTip)
end

--------------------------------------------------------------------------------
-- Janela e cartões
--------------------------------------------------------------------------------

function K.Window(name, width, height)
    local u, c = UI(), C()
    local f = CreateFrame("Frame", name, UIParent)
    f:SetSize(width, height)
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    u.Box(f, c.bg, 0.97, c.gold, 0.55)
    u.Chrome(f, 84)

    local emblem = f:CreateTexture(nil, "ARTWORK")
    emblem:SetTexture(K.PORTRAIT)
    emblem:SetSize(38, 38)
    emblem:SetPoint("TOPLEFT", 18, -14)
    f.title = K.Text(f, 17, c.accent, "title")
    f.title:SetPoint("LEFT", emblem, "RIGHT", 10, 2)
    f.subtitle = K.Text(f, 12, c.dim)
    f.subtitle:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)

    f.close = u.IconButton(f, 26, ART .. "MapUI\\Close", function() f:Hide() end)
    f.close:SetPoint("TOPRIGHT", -14, -14)
    f.close:SetFrameLevel(f:GetFrameLevel() + 40)
    if UISpecialFrames then tinsert(UISpecialFrames, name) end
    return f
end

function K.Card(parent, width, height)
    local u, c = UI(), C()
    local card = CreateFrame("Frame", nil, parent)
    card:SetSize(width, height)
    u.Box(card, c.card, 0.82, c.gold, 0.18)
    u.CardCorners(card, 0.7)
    return card
end

-- título de cartão com losango, como no painel do AzaathUI
function K.CardTitle(card, textFn)
    local c = C()
    local mark = card:CreateTexture(nil, "ARTWORK")
    mark:SetTexture(ART .. "Diamond")
    mark:SetVertexColor(c.accent[1], c.accent[2], c.accent[3])
    mark:SetSize(9, 9)
    mark:SetPoint("TOPLEFT", 14, -15)
    local t = K.Text(card, 13, c.accent, "title")
    t:SetPoint("LEFT", mark, "RIGHT", 7, 0)
    t:SetWordWrap(false)
    card.Retitle = function() t:SetText(Azaath.Upper and Azaath.Upper(textFn()) or textFn()) end
    card.Retitle()
    return t
end

function K.Button(parent, width, labelFn, onClick, kind)
    local b = UI().Button(parent, labelFn(), width, onClick, kind)
    b:SetHeight(24)
    b.Relabel = function() b.text:SetText(labelFn()) end
    return b
end

function K.Divider(parent, width)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(width, 10)
    UI().Divider(holder, 0.45)
    return holder
end

--------------------------------------------------------------------------------
-- Caixa de marcar com rótulo
--------------------------------------------------------------------------------

function K.Toggle(parent, width, labelFn, get, set, tipFn)
    local c = C()
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, 24)
    local box = CreateFrame("Frame", nil, row)
    box:SetSize(16, 16)
    box:SetPoint("LEFT", 0, 0)
    UI().Box(box, c.panel, 1, c.gold, 0.6)
    local mark = box:CreateTexture(nil, "OVERLAY")
    mark:SetTexture(ART .. "MapUI\\Check")
    mark:SetSize(14, 14)
    mark:SetPoint("CENTER")
    mark:SetVertexColor(c.accent[1], c.accent[2], c.accent[3])
    local label = K.Text(row, 12, c.cream)
    label:SetPoint("LEFT", box, "RIGHT", 8, 0)
    label:SetPoint("RIGHT", row, "RIGHT", 0, 0)
    label:SetWordWrap(false)
    local active = true
    row:SetScript("OnClick", function()
        if not active then return end
        Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        set(not get())
    end)
    K.HoverTip(row, labelFn, tipFn)
    function row:Refresh()
        mark:SetShown(get() and true or false)
        label:SetText(labelFn())
    end
    function row:SetActive(on)
        active = on and true or false
        local t = active and c.cream or c.off
        label:SetTextColor(t[1], t[2], t[3])
        box:SetAlpha(active and 1 or 0.45)
    end
    row:Refresh()
    return row
end

--------------------------------------------------------------------------------
-- Controle deslizante com - / + e valor
--------------------------------------------------------------------------------

function K.Slider(parent, width, labelFn, lo, hi, get, set, fmtFn, tipFn)
    local c = C()
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, 42)
    row:EnableMouse(true)
    local label = K.Text(row, 12, c.cream)
    label:SetPoint("TOPLEFT", 0, 0)
    local value = K.Text(row, 12, c.accent, "bold")
    value:SetPoint("TOPRIGHT", 0, 0)
    value:SetJustifyH("RIGHT")

    local minus = UI().IconButton(row, 18, ART .. "MapUI\\Minus")
    minus:SetPoint("BOTTOMLEFT", 0, 0)
    local plus = UI().IconButton(row, 18, ART .. "MapUI\\Plus")
    plus:SetPoint("BOTTOMRIGHT", 0, 0)

    local bar = CreateFrame("Frame", nil, row)
    bar:SetPoint("LEFT", minus, "RIGHT", 6, 0)
    bar:SetPoint("RIGHT", plus, "LEFT", -6, 0)
    bar:SetHeight(14)
    local track = bar:CreateTexture(nil, "BACKGROUND")
    track:SetTexture(Azaath.media.blank)
    track:SetVertexColor(c.panel[1] * 1.6, c.panel[2] * 1.6, c.panel[3] * 1.6, 1)
    track:SetHeight(4)
    track:SetPoint("LEFT")
    track:SetPoint("RIGHT")
    local fill = bar:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(Azaath.media.blank)
    fill:SetVertexColor(c.accent[1], c.accent[2], c.accent[3], 0.85)
    fill:SetHeight(4)
    fill:SetPoint("LEFT", track, "LEFT")
    local knob = bar:CreateTexture(nil, "OVERLAY")
    knob:SetTexture(ART .. "Diamond")
    knob:SetSize(14, 14)

    local active, dragging = true, false
    local function Place(v)
        local w = bar:GetWidth()
        if not w or w <= 0 then w = width - 48 end
        local t = (v - lo) / (hi - lo)
        fill:SetWidth(max(t * w, 0.01))
        knob:ClearAllPoints()
        knob:SetPoint("CENTER", track, "LEFT", t * w, 0)
        value:SetText(fmtFn and fmtFn(v) or tostring(v))
    end
    local function Write(v)
        v = floor(min(hi, max(lo, v)) + 0.5)
        if v ~= get() then set(v) end
        Place(get())
    end
    local function FromCursor()
        local scale = bar:GetEffectiveScale()
        local x = GetCursorPosition() / scale
        local left, w = bar:GetLeft(), bar:GetWidth()
        if not left or not w or w <= 0 then return end
        Write(lo + (hi - lo) * min(1, max(0, (x - left) / w)))
    end
    bar:EnableMouse(true)
    bar:SetScript("OnMouseDown", function() if active then dragging = true; FromCursor() end end)
    bar:SetScript("OnMouseUp", function() dragging = false end)
    bar:SetScript("OnUpdate", function() if dragging then FromCursor() end end)
    bar:EnableMouseWheel(true)
    bar:SetScript("OnMouseWheel", function(_, d) if active then Write(get() + d) end end)
    minus:SetScript("OnClick", function() if active then Write(get() - 1) end end)
    plus:SetScript("OnClick", function() if active then Write(get() + 1) end end)
    K.HoverTip(row, labelFn, tipFn)

    function row:Refresh()
        label:SetText(labelFn())
        Place(get())
    end
    function row:SetActive(on)
        active = on and true or false
        local t = active and c.cream or c.off
        label:SetTextColor(t[1], t[2], t[3])
        bar:SetAlpha(active and 1 or 0.4)
        minus:SetAlpha(active and 1 or 0.4)
        plus:SetAlpha(active and 1 or 0.4)
    end
    row:SetScript("OnShow", function() row:Refresh() end)
    row:Refresh()
    return row
end

--------------------------------------------------------------------------------
-- Escolha segmentada (botões lado a lado)
--------------------------------------------------------------------------------

-- options: { { value = v, label = fn, tip = fn } ... }
function K.Choice(parent, width, labelFn, options, get, set, tipFn)
    local c = C()
    local row = CreateFrame("Frame", nil, parent)
    row:SetSize(width, 46)
    local label = K.Text(row, 12, c.cream)
    label:SetPoint("TOPLEFT", 0, 0)
    local n = #options
    local gap = 4
    local bw = (width - gap * (n - 1)) / n
    local buttons = {}
    for i, o in ipairs(options) do
        local b = CreateFrame("Button", nil, row)
        b:SetSize(bw, 22)
        b:SetPoint("BOTTOMLEFT", (i - 1) * (bw + gap), 0)
        UI().Box(b, c.panel, 0.9, c.gold, 0.35)
        b.text = K.Text(b, 11, c.cream)
        b.text:SetPoint("CENTER")
        b.text:SetJustifyH("CENTER")
        b.text:SetWordWrap(false)
        b:SetScript("OnClick", function()
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            set(o.value)
        end)
        K.HoverTip(b, o.label, o.tip)
        buttons[i] = b
    end
    K.HoverTip(row, labelFn, tipFn)
    function row:Refresh()
        label:SetText(labelFn())
        local cur = get()
        for i, o in ipairs(options) do
            local b, on = buttons[i], cur == o.value
            b.text:SetText(o.label())
            local border = on and c.accent or c.gold
            b:SetBackdropBorderColor(border[1], border[2], border[3], on and 0.95 or 0.35)
            if on then
                b:SetBackdropColor(c.accent[1] * 0.3, c.accent[2] * 0.24, c.accent[3] * 0.12, 1)
                b.text:SetTextColor(1, 1, 1)
            else
                b:SetBackdropColor(c.panel[1], c.panel[2], c.panel[3], 0.9)
                b.text:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
            end
        end
    end
    function row:SetActive() end
    row:Refresh()
    return row
end

--------------------------------------------------------------------------------
-- Botão quadrado com desenho (efeitos, categorias)
--------------------------------------------------------------------------------

function K.Tile(parent, size)
    local c = C()
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    UI().Box(b, { 0.02, 0.02, 0.03 }, 0.95, c.gold, 0.35)
    b.glow = b:CreateTexture(nil, "BACKGROUND", nil, 2)
    b.glow:SetTexture(ns.MEDIA .. "glow.tga")
    b.glow:SetBlendMode("ADD")
    b.glow:SetPoint("CENTER")
    b.glow:SetSize(size * 1.9, size * 1.9)
    b.glow:SetVertexColor(c.accent[1], c.accent[2], c.accent[3], 0.6)
    b.glow:Hide()
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(Azaath.media.blank)
    hl:SetAllPoints()
    hl:SetVertexColor(1, 1, 1, 0.08)
    function b:SetSelected(on)
        self.glow:SetShown(on and true or false)
        local border = on and c.accent or c.gold
        self:SetBackdropBorderColor(border[1], border[2], border[3], on and 1 or 0.35)
    end
    return b
end

-- amostra de cor: clique abre o seletor do jogo, botão direito volta ao original
function K.Swatch(parent, get, pick, reset, tipTitleFn, tipBodyFn, extraFn)
    local c = C()
    local s = CreateFrame("Button", nil, parent)
    s:SetSize(16, 16)
    s:RegisterForClicks("AnyUp")
    UI().Box(s, { 0, 0, 0 }, 1, c.gold, 0.8)
    local fill = s:CreateTexture(nil, "ARTWORK")
    fill:SetTexture(Azaath.media.blank)
    fill:SetPoint("TOPLEFT", 2, -2)
    fill:SetPoint("BOTTOMRIGHT", -2, 2)
    s:SetScript("OnClick", function(_, button)
        Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        if button == "RightButton" then reset() else pick() end
    end)
    s:SetScript("OnEnter", function(self) Tip(self, tipTitleFn(), tipBodyFn(), extraFn and extraFn()) end)
    s:SetScript("OnLeave", HideTip)
    function s:Refresh() fill:SetVertexColor(get()) end
    s:Refresh()
    return s
end
