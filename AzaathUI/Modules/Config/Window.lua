--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Config/Window.lua
    Janela do painel (/azaath): cabeçalho com idioma e Modo de Edição, navegação
    lateral com ícones e busca, páginas em cartões por seção com rolagem suave,
    rodapé com legenda e aviso de recarga. As páginas são montadas na primeira
    vez que são abertas (ou ao buscar) e remontam o layout ao trocar de idioma.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.ConfigUI

local ipairs, format, type = ipairs, string.format, type
local floor, max, min = math.floor, math.max, math.min
local C, S = U.C, U.S
local MEDIA = U.MEDIA
local L = U.L

local G = {
    W = 1100, H = 700,
    pad = 18,
    navW = 236,
    headerH = 80,
    footerH = 50,
    navBtnH = 34,
    pageHeadH = 62,
    cardGap = 14,
    cardPad = 16,
    wheelStep = 70,
}

local window, nav, content, scroll, scrollTrack, scrollThumb
local pageTitle, pageSub, noResults
local searchBox, footerLegend, pendingText, pendingBtn
local langButtons, header = {}, {}
U.pages, U.navButtons = {}, {}
U.filter = ""
U.pendingReload = false

--------------------------------------------------------------------------------
-- Recarga pendente
--------------------------------------------------------------------------------
function U.MarkReload()
    U.pendingReload = true
    if pendingBtn then pendingBtn:Show(); pendingText:Show() end
end

--------------------------------------------------------------------------------
-- Restaurar seção
--------------------------------------------------------------------------------
local function CopyDeep(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = CopyDeep(x) end
    return t
end

local function ResetPath(path)
    local d = U.DefaultOf(path)
    local t, k = U.Resolve(path)
    if t then t[k] = CopyDeep(d) end
end

local function ResetSection(card)
    local name = L(card.sec.key)
    U.ShowPopup("AZAATHUI_SECTION_RESET", { run = function()
        for _, row in ipairs(card.rows) do
            local def = row.def
            if def.t == "toggle" or def.t == "slider" or def.t == "choice" then
                local old = U.GetValue(def)
                for _, p in ipairs(def.resetPaths or { def.path }) do ResetPath(p) end
                local new = U.GetValue(def)
                if old ~= new then
                    if def.reload then U.MarkReload() end
                    if def.apply then pcall(def.apply, new) end
                    if def.onChange then def.onChange(new) end
                end
            end
        end
        U.RefreshVisible()
        Azaath:Print(format(L("msg.sectionReset"), name))
    end }, name)
end

--------------------------------------------------------------------------------
-- Cartão de seção
--------------------------------------------------------------------------------
local function BuildCard(page, sec)
    local card = CreateFrame("Frame", nil, page.child)
    card.sec, card.rows = sec, {}
    U.Box(card, C.card, 0.82, C.gold, 0.16)
    U.CardCorners(card, 0.7)

    local glow = U.Tex(card, "BORDER")
    glow:SetHeight(1)
    glow:SetPoint("TOPLEFT", card, "TOPLEFT", 1, -1)
    glow:SetPoint("TOPRIGHT", card, "TOP", 0, -1)
    Azaath.Gradient(glow, "HORIZONTAL", C.accent[1], C.accent[2], C.accent[3], 0.7, C.accent[1], C.accent[2], C.accent[3], 0)

    local mark = U.Tex(card, "ARTWORK", MEDIA .. "Diamond", C.accent[1], C.accent[2], C.accent[3])
    mark:SetSize(9, 9)
    mark:SetPoint("TOPLEFT", card, "TOPLEFT", G.cardPad, -G.cardPad - 3)

    card.title = U.Text(card, 13, C.accent, Azaath.media.fontTitleB)
    card.title:SetWordWrap(false)
    card.title:SetPoint("TOPLEFT", mark, "TOPRIGHT", 8, 3)
    card.desc = U.Text(card, 11, C.dim)
    card.desc:SetPoint("TOPLEFT", card.title, "BOTTOMLEFT", 0, -4)

    if not sec.noReset then
        card.reset = U.Button(card, "", 150, function() ResetSection(card) end, "ghost", MEDIA .. "MapUI\\Restore")
        card.reset:SetHeight(22)
        card.reset:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -10)
    end

    for _, def in ipairs(sec.rows) do
        local build = U.BUILDERS[def.t]
        if build then
            local row = build(card, def, sec)
            row:Localize()
            card.rows[#card.rows + 1] = row
        end
    end

    function card:Localize()
        self.title:SetText(Azaath.Upper and Azaath.Upper(L(sec.key)) or L(sec.key))
        self.desc:SetText(L(sec.key, 2) or "")
        self.search = ((L(sec.key) or "") .. " " .. (L(sec.key, 2) or "")):lower()
        if self.reset then
            self.reset.text:SetText(L("ui.resetSection"))
            self.reset:SetWidth(self.reset.text:GetStringWidth() + 42)
            local tip = U.STR[U.LangCode()]["ui.resetSectionTip"]
            self.reset.tipTitle, self.reset.tipBody = tip[1], tip[2]
        end
        for _, row in ipairs(self.rows) do row:Localize() end
    end
    card:Localize()
    page.cards[#page.cards + 1] = card
    return card
end

--------------------------------------------------------------------------------
-- Layout de uma página (com o filtro da busca)
--------------------------------------------------------------------------------
local function Matches(text, filter)
    return filter == "" or (text and text:find(filter, 1, true) ~= nil)
end

local function CountMatches(page, filter)
    local n = 0
    for _, card in ipairs(page.cards) do
        local all = Matches(card.search, filter)
        for _, row in ipairs(card.rows) do
            if not row.isNote and (all or Matches(row.search, filter)) then n = n + 1 end
        end
    end
    return n
end

local function LayoutPage(page)
    local filter = U.filter
    local w = page.child:GetWidth()
    local y = 0
    local shown = 0
    for _, card in ipairs(page.cards) do
        local all = Matches(card.search, filter)
        local any = false
        for _, row in ipairs(card.rows) do
            row.visible = all or Matches(row.search, filter)
            if row.visible and not row.isNote then any = true end
            if filter == "" then row.visible = true; any = true end
        end
        if any then
            card:Show()
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", page.child, "TOPLEFT", 0, -y)
            card:SetPoint("TOPRIGHT", page.child, "TOPRIGHT", 0, -y)
            local textW = w - G.cardPad * 2 - 20 - (card.reset and (card.reset:GetWidth() + 10) or 0)
            card.title:SetWidth(textW)
            card.desc:SetWidth(textW)
            local iy = G.cardPad + card.title:GetStringHeight() + 4
            if (card.desc:GetText() or "") ~= "" then iy = iy + card.desc:GetStringHeight() end
            iy = floor(iy + 14)
            local first = true
            for _, row in ipairs(card.rows) do
                if row.visible then
                    row:Show()
                    row:ClearAllPoints()
                    row:SetPoint("TOPLEFT", card, "TOPLEFT", 6, -iy)
                    row:SetPoint("TOPRIGHT", card, "TOPRIGHT", -6, -iy)
                    local h = row:Measure(w - 12)
                    row:SetHeight(h)
                    if row.sep then row.sep:SetShown(not row.isNote) end
                    iy = iy + h
                    first = false
                    shown = shown + 1
                else
                    row:Hide()
                end
            end
            local ch = iy + 8
            card:SetHeight(ch)
            y = y + ch + G.cardGap
        else
            card:Hide()
        end
    end
    page.child:SetHeight(max(1, y))
    page.shown = shown
end

--------------------------------------------------------------------------------
-- Rolagem suave + barra arrastável
--------------------------------------------------------------------------------
local function MaxScroll()
    local child = scroll:GetScrollChild()
    if not child then return 0 end
    return max(0, child:GetHeight() - scroll:GetHeight())
end

local function UpdateThumb()
    local maxS = MaxScroll()
    if maxS <= 1 then scrollTrack:Hide(); return end
    scrollTrack:Show()
    local trackH = scrollTrack:GetHeight()
    local child = scroll:GetScrollChild()
    local ratio = min(1, scroll:GetHeight() / child:GetHeight())
    local th = max(36, floor(trackH * ratio))
    local off = floor((trackH - th) * (scroll:GetVerticalScroll() / maxS))
    scrollThumb:SetHeight(th)
    scrollThumb:ClearAllPoints()
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, -off)
end

local function ScrollStep(self, elapsed)
    local cur = scroll:GetVerticalScroll()
    local target = min(MaxScroll(), max(0, scroll.target or 0))
    scroll.target = target
    if math.abs(target - cur) < 0.5 then
        scroll:SetVerticalScroll(target)
        self:SetScript("OnUpdate", nil)
    else
        scroll:SetVerticalScroll(cur + (target - cur) * min(1, elapsed * 14))
    end
    UpdateThumb()
end

local function ScrollTo(v, instant)
    scroll.target = min(MaxScroll(), max(0, v))
    if instant then
        scroll:SetVerticalScroll(scroll.target)
        UpdateThumb()
    else
        scroll:SetScript("OnUpdate", ScrollStep)
    end
end

--------------------------------------------------------------------------------
-- Páginas
--------------------------------------------------------------------------------
local function BuildPage(i)
    if U.pages[i] then return U.pages[i] end
    local def = U.PAGES[i]
    local page = { def = def, cards = {} }
    page.child = CreateFrame("Frame", nil, scroll)
    -- antes do primeiro desenho a rolagem ainda pode medir 0: usa a largura prevista
    local sw = scroll:GetWidth() or 0
    if sw < 200 then sw = G.W - G.pad * 2 - G.navW - 18 - 16 end
    page.child:SetWidth(sw)
    page.child:Hide()
    for _, sec in ipairs(def.sections) do BuildCard(page, sec) end
    U.pages[i] = page
    LayoutPage(page)
    return page
end

local function PaintNav()
    for i, b in ipairs(U.navButtons) do
        local sel = (i == U.current)
        b.sel:SetShown(sel)
        b.bar:SetShown(sel)
        b.icon:SetDesaturated(not sel)
        b.icon:SetAlpha(sel and 1 or 0.7)
        local t = sel and { 1, 0.95, 0.85 } or C.cream
        b.text:SetTextColor(t[1], t[2], t[3])
        local dimmed = U.filter ~= "" and (b.count or 0) == 0
        b:SetAlpha(dimmed and 0.35 or 1)
        if U.filter ~= "" and (b.count or 0) > 0 then
            b.badge:SetText(b.count)
            b.badge:Show()
        else
            b.badge:Hide()
        end
    end
end

function U.SelectPage(i)
    if not U.PAGES[i] then i = 1 end
    local old = U.current and U.pages[U.current]
    if old then old.child:Hide() end
    local page = BuildPage(i)
    U.current = i
    page.child:Show()
    scroll:SetScrollChild(page.child)
    local sw = scroll:GetWidth() or 0
    if sw >= 200 and math.abs(sw - page.child:GetWidth()) > 1 then page.child:SetWidth(sw) end
    LayoutPage(page)
    pageTitle:SetText(Azaath.Upper and Azaath.Upper(L("page." .. page.def.key)) or L("page." .. page.def.key))
    pageSub:SetText(L("page." .. page.def.key, 2) or "")
    for _, card in ipairs(page.cards) do
        for _, row in ipairs(card.rows) do row:Refresh() end
    end
    noResults:SetShown(U.filter ~= "" and (page.shown or 0) == 0)
    ScrollTo(0, true)
    if Azaath.db and Azaath.db.config then Azaath.db.config.page = page.def.key end
    PaintNav()
end

function U.RefreshVisible()
    local page = U.current and U.pages[U.current]
    if not (page and window and window:IsShown()) then return end
    for _, card in ipairs(page.cards) do
        for _, row in ipairs(card.rows) do
            if row.Refresh then row:Refresh() end
        end
    end
end

--------------------------------------------------------------------------------
-- Busca
--------------------------------------------------------------------------------
local function ApplySearch(text)
    U.filter = (text or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    local firstHit
    for i = 1, #U.PAGES do
        local page = (U.filter ~= "") and BuildPage(i) or U.pages[i]
        if page then
            LayoutPage(page)
            U.navButtons[i].count = (U.filter ~= "") and CountMatches(page, U.filter) or nil
            if not firstHit and (U.navButtons[i].count or 0) > 0 then firstHit = i end
        end
    end
    local cur = U.navButtons[U.current]
    if U.filter ~= "" and firstHit and (cur.count or 0) == 0 then
        U.SelectPage(firstHit)
    else
        local page = U.pages[U.current]
        noResults:SetText(format(L("ui.noResults"), text or ""))
        noResults:SetShown(U.filter ~= "" and (page.shown or 0) == 0)
        ScrollTo(0, true)
        PaintNav()
    end
    noResults:SetText(format(L("ui.noResults"), text or ""))
end

--------------------------------------------------------------------------------
-- Idioma
--------------------------------------------------------------------------------
local function PaintLang()
    local code = U.LangCode()
    for lang, b in pairs(langButtons) do
        local on = (lang == code)
        b:SetBackdropColor(on and C.accent[1] * 0.3 or 0, on and C.accent[2] * 0.24 or 0, on and C.accent[3] * 0.1 or 0, on and 1 or 0.4)
        b:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], on and 0.9 or 0.2)
        local t = on and C.accent or C.dim
        b.text:SetTextColor(t[1], t[2], t[3])
    end
end

function U.Relocalize()
    if not window then return end
    header.title:SetText(Azaath.Upper and Azaath.Upper(L("ui.title")) or L("ui.title"))
    header.sub:SetText(L("ui.subtitle") .. "   |cff6f6a5e·|r   v" .. tostring(Azaath.version))
    header.edit.text:SetText(L("ui.editMode"))
    local tip = U.STR[U.LangCode()]["ui.editModeTip"]
    header.edit.tipTitle, header.edit.tipBody = tip[1], tip[2]
    header.close.tipTitle = L("ui.close")
    local lt = U.STR[U.LangCode()]["ui.langTip"]
    for _, b in pairs(langButtons) do b.tipTitle, b.tipBody = lt[1], lt[2] end
    searchBox.placeholder:SetText(L("ui.search"))
    footerLegend:SetText(U.RELOAD_ICON .. "  " .. L("ui.legendReload") .. "     |cff6f6a5e·|r     " .. L("ui.legendHelp"))
    pendingText:SetText(L("ui.pending"))
    pendingBtn.text:SetText(L("ui.reloadNow"))
    for i, b in ipairs(U.navButtons) do b.text:SetText(L("page." .. U.PAGES[i].key)) end
    for _, page in pairs(U.pages) do
        for _, card in ipairs(page.cards) do card:Localize() end
        LayoutPage(page)
    end
    PaintLang()
    if U.stub and U.stub.Localize then U.stub:Localize() end
    if U.current then
        local keep = scroll:GetVerticalScroll()
        U.SelectPage(U.current)
        ScrollTo(keep, true)
    end
    if U.filter ~= "" then ApplySearch(searchBox:GetText()) end
end

function U.ApplyWindowScale()
    if not (window and Azaath.db and Azaath.db.config) then return end
    local want = Azaath.db.config.scale or 1
    local pw, ph = UIParent:GetWidth() or G.W, UIParent:GetHeight() or G.H
    local fit = min((pw - 40) / G.W, (ph - 60) / G.H)
    window:SetScale(max(0.5, min(want, fit)))
    if Azaath.ClampToScreen then Azaath.ClampToScreen(window) end
end

--------------------------------------------------------------------------------
-- Construção da janela
--------------------------------------------------------------------------------
local function Ornament(parent, point, x, y, size, alpha)
    local d = U.Tex(parent, "OVERLAY", MEDIA .. "Diamond", C.gold[1], C.gold[2], C.gold[3], alpha or 0.9)
    d:SetSize(size or 10, size or 10)
    d:SetPoint("CENTER", parent, point, x or 0, y or 0)
    return d
end

local function FancyLine(parent, a)
    if U.Divider then return U.Divider(parent, a) end
    local l = U.Tex(parent, "ARTWORK")
    l:SetHeight(1)
    local r = U.Tex(parent, "ARTWORK")
    r:SetHeight(1)
    l:SetPoint("RIGHT", parent, "CENTER", -10, 0)
    r:SetPoint("LEFT", parent, "CENTER", 10, 0)
    l:SetPoint("LEFT", parent, "LEFT")
    r:SetPoint("RIGHT", parent, "RIGHT")
    Azaath.Gradient(l, "HORIZONTAL", C.gold[1], C.gold[2], C.gold[3], 0, C.gold[1], C.gold[2], C.gold[3], a or 0.6)
    Azaath.Gradient(r, "HORIZONTAL", C.gold[1], C.gold[2], C.gold[3], a or 0.6, C.gold[1], C.gold[2], C.gold[3], 0)
    local d = U.Tex(parent, "OVERLAY", MEDIA .. "Diamond", C.accent[1], C.accent[2], C.accent[3])
    d:SetSize(9, 9)
    d:SetPoint("CENTER", parent, "CENTER")
end

local function BuildHeader()
    local h = CreateFrame("Frame", nil, window)
    h:SetPoint("TOPLEFT", window, "TOPLEFT", G.pad, -G.pad + 4)
    h:SetPoint("TOPRIGHT", window, "TOPRIGHT", -G.pad, -G.pad + 4)
    h:SetHeight(G.headerH - G.pad)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() window:StartMoving() end)
    h:SetScript("OnDragStop", function() window:StopMovingOrSizing() end)

    local halo = U.Tex(h, "BACKGROUND", MEDIA .. "Glow", C.accent[1], C.accent[2], C.accent[3], 0.35)
    halo:SetSize(84, 84)
    halo:SetBlendMode("ADD")
    halo:SetPoint("LEFT", h, "LEFT", -18, 0)
    local gem = U.Tex(h, "ARTWORK", U.ART .. "Emblem")
    gem:SetSize(44, 44)
    gem:SetPoint("LEFT", h, "LEFT", 6, 0)

    header.title = U.Text(h, 22, C.gold, Azaath.media.fontTitleB)
    header.title:SetWordWrap(false)
    header.title:SetPoint("TOPLEFT", gem, "TOPRIGHT", 14, 4)
    header.sub = U.Text(h, 13, C.dim, Azaath.media.fontItalic or Azaath.media.font)
    header.sub:SetWordWrap(false)
    header.sub:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 1, -3)

    header.close = U.IconButton(h, 30, MEDIA .. "MapUI\\Close", function() window:Hide() end)
    header.close:SetPoint("RIGHT", h, "RIGHT", 4, 0)

    header.edit = U.Button(h, "", 176, function()
        Azaath:GetModule("Config"):ToggleEditMode(true)
    end, "primary", MEDIA .. "MapUI\\Layers")
    header.edit:SetHeight(32)
    header.edit:SetPoint("RIGHT", header.close, "LEFT", -12, 0)

    -- PT | EN
    local prev
    for _, lang in ipairs({ "enUS", "ptBR" }) do
        local b = U.Button(h, L("ui.langShort." .. lang), 40, function()
            Azaath.db.config.lang = lang
            U.Relocalize()
        end)
        b:SetHeight(26)
        b:SetScript("OnLeave", function() PaintLang(); U.HideTip() end)
        b:HookScript("OnEnter", function() end)
        if prev then b:SetPoint("RIGHT", prev, "LEFT", -4, 0)
        else b:SetPoint("RIGHT", header.edit, "LEFT", -18, 0) end
        langButtons[lang] = b
        prev = b
    end
    local globe = U.Tex(h, "ARTWORK", MEDIA .. "MapUI\\Compass", C.dim[1], C.dim[2], C.dim[3])
    globe:SetSize(16, 16)
    globe:SetPoint("RIGHT", prev, "LEFT", -8, 0)

    local div = CreateFrame("Frame", nil, window)
    div:SetHeight(10)
    div:SetPoint("TOPLEFT", window, "TOPLEFT", G.pad, -G.headerH + 4)
    div:SetPoint("TOPRIGHT", window, "TOPRIGHT", -G.pad, -G.headerH + 4)
    FancyLine(div, 0.55)
end

local function BuildNav()
    nav = CreateFrame("Frame", nil, window)
    nav:SetWidth(G.navW)
    nav:SetPoint("TOPLEFT", window, "TOPLEFT", G.pad, -G.headerH - 8)
    nav:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", G.pad, G.footerH)
    U.Box(nav, C.panel, 0.62, C.gold, 0.14)
    U.CardCorners(nav, 0.6)

    -- busca
    searchBox = CreateFrame("EditBox", nil, nav)
    searchBox:SetHeight(30)
    searchBox:SetPoint("TOPLEFT", nav, "TOPLEFT", 8, -8)
    searchBox:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -8, -8)
    searchBox:SetAutoFocus(false)
    searchBox:SetFont(Azaath.media.font, 12, "")
    searchBox:SetTextInsets(28, 24, 0, 0)
    searchBox:SetTextColor(C.cream[1], C.cream[2], C.cream[3])
    U.Box(searchBox, C.bg, 1, C.gold, 0.25)
    local sIcon = U.Tex(searchBox, "ARTWORK", MEDIA .. "MapUI\\Search", C.dim[1], C.dim[2], C.dim[3])
    sIcon:SetSize(14, 14)
    sIcon:SetPoint("LEFT", searchBox, "LEFT", 9, 0)
    searchBox.placeholder = U.Text(searchBox, 12, C.off)
    searchBox.placeholder:SetPoint("LEFT", searchBox, "LEFT", 28, 0)
    local clear = U.IconButton(searchBox, 20, MEDIA .. "MapUI\\Close", function()
        searchBox:SetText("")
        searchBox:ClearFocus()
    end)
    clear:SetPoint("RIGHT", searchBox, "RIGHT", -4, 0)
    clear:Hide()
    searchBox:SetScript("OnTextChanged", function(self)
        local t = self:GetText() or ""
        self.placeholder:SetShown(t == "")
        clear:SetShown(t ~= "")
        ApplySearch(t)
    end)
    searchBox:SetScript("OnEditFocusGained", function(self) self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 0.8) end)
    searchBox:SetScript("OnEditFocusLost", function(self) self:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 0.25) end)
    searchBox:SetScript("OnEscapePressed", function(self)
        if (self:GetText() or "") ~= "" then self:SetText("") end
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    for i, def in ipairs(U.PAGES) do
        local b = CreateFrame("Button", nil, nav)
        b:SetHeight(G.navBtnH)
        local y = -46 - (i - 1) * (G.navBtnH + 2)
        b:SetPoint("TOPLEFT", nav, "TOPLEFT", 6, y)
        b:SetPoint("TOPRIGHT", nav, "TOPRIGHT", -6, y)

        b.hov = U.Tex(b, "BACKGROUND")
        b.hov:SetAllPoints()
        Azaath.Gradient(b.hov, "HORIZONTAL", C.gold[1], C.gold[2], C.gold[3], 0.10, C.gold[1], C.gold[2], C.gold[3], 0)
        b.hov:Hide()
        b.sel = U.Tex(b, "BACKGROUND", U.ART .. "NavSel", C.accent[1], C.accent[2], C.accent[3])
        b.sel:SetAllPoints()
        b.bar = U.Tex(b, "ARTWORK", MEDIA .. "Glow", C.accent[1], C.accent[2], C.accent[3], 0.35)
        b.bar:SetBlendMode("ADD")
        b.bar:SetSize(40, 40)
        b.bar:SetPoint("CENTER", b, "LEFT", 2, 0)

        local frame = CreateFrame("Frame", nil, b)
        frame:SetSize(24, 24)
        frame:SetPoint("LEFT", b, "LEFT", 12, 0)
        U.Box(frame, C.bg, 1, C.gold, 0.45)
        b.icon = U.Tex(frame, "ARTWORK", def.icon)
        b.icon:SetPoint("TOPLEFT", 1, -1)
        b.icon:SetPoint("BOTTOMRIGHT", -1, 1)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        b.text = U.Text(b, 13, C.cream, Azaath.media.fontBold)
        b.text:SetWordWrap(false)
        b.text:SetPoint("LEFT", frame, "RIGHT", 10, 0)
        b.text:SetPoint("RIGHT", b, "RIGHT", -30, 0)
        b.badge = U.Text(b, 11, C.accent, Azaath.media.fontBold)
        b.badge:SetPoint("RIGHT", b, "RIGHT", -10, 0)
        b.badge:Hide()

        b:SetScript("OnClick", function()
            if U.current == i then return end
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            U.SelectPage(i)
        end)
        b:SetScript("OnEnter", function(self)
            if U.current ~= i then self.hov:Show() end
            U.Tooltip(self, L("page." .. def.key), L("page." .. def.key, 2))
        end)
        b:SetScript("OnLeave", function(self) self.hov:Hide(); U.HideTip() end)
        U.navButtons[i] = b
    end
end

local function BuildContent()
    content = CreateFrame("Frame", nil, window)
    content:SetPoint("TOPLEFT", nav, "TOPRIGHT", 18, 0)
    content:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -G.pad, G.footerH)

    pageTitle = U.Text(content, 19, C.cream, Azaath.media.fontTitleB)
    pageTitle:SetWordWrap(false)
    pageTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 2, -4)
    pageSub = U.Text(content, 12, C.dim)
    pageSub:SetWordWrap(false)
    pageSub:SetPoint("TOPLEFT", pageTitle, "BOTTOMLEFT", 0, -5)
    pageSub:SetPoint("RIGHT", content, "RIGHT", -10, 0)

    local line = U.Tex(content, "ARTWORK")
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -G.pageHeadH + 10)
    line:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, -G.pageHeadH + 10)
    Azaath.Gradient(line, "HORIZONTAL", C.gold[1], C.gold[2], C.gold[3], 0.45, C.gold[1], C.gold[2], C.gold[3], 0)

    scroll = CreateFrame("ScrollFrame", nil, content)
    scroll:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -G.pageHeadH)
    scroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -16, 6)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(_, delta)
        ScrollTo((scroll.target or scroll:GetVerticalScroll()) - delta * G.wheelStep)
    end)
    scroll:SetScript("OnSizeChanged", function(self, w)
        if not w or w < 200 then return end
        for _, page in pairs(U.pages) do
            page.child:SetWidth(w)
            LayoutPage(page)
        end
        UpdateThumb()
    end)

    -- fades nas bordas da rolagem
    local fadeTop = U.Tex(content, "OVERLAY")
    fadeTop:SetHeight(12)
    fadeTop:SetPoint("TOPLEFT", scroll, "TOPLEFT")
    fadeTop:SetPoint("TOPRIGHT", scroll, "TOPRIGHT")
    Azaath.Gradient(fadeTop, "VERTICAL", C.bg[1], C.bg[2], C.bg[3], 0, C.bg[1], C.bg[2], C.bg[3], 0.9)
    local fadeBot = U.Tex(content, "OVERLAY")
    fadeBot:SetHeight(16)
    fadeBot:SetPoint("BOTTOMLEFT", scroll, "BOTTOMLEFT")
    fadeBot:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT")
    Azaath.Gradient(fadeBot, "VERTICAL", C.bg[1], C.bg[2], C.bg[3], 0.95, C.bg[1], C.bg[2], C.bg[3], 0)

    scrollTrack = CreateFrame("Button", nil, content)
    scrollTrack:SetWidth(6)
    scrollTrack:SetPoint("TOPRIGHT", content, "TOPRIGHT", -2, -G.pageHeadH)
    scrollTrack:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -2, 6)
    U.Box(scrollTrack, C.bg, 1, C.gold, 0.12)
    scrollTrack:SetScript("OnClick", function(self)
        local _, cy = GetCursorPosition()
        cy = cy / self:GetEffectiveScale()
        local frac = (self:GetTop() - cy) / self:GetHeight()
        ScrollTo(frac * MaxScroll())
    end)

    scrollThumb = CreateFrame("Button", nil, scrollTrack)
    scrollThumb:SetWidth(6)
    scrollThumb.tex = U.Tex(scrollThumb, "ARTWORK", nil, C.gold[1], C.gold[2], C.gold[3], 0.75)
    scrollThumb.tex:SetAllPoints()
    scrollThumb:SetScript("OnEnter", function(self) self.tex:SetVertexColor(C.accent[1], C.accent[2], C.accent[3], 1) end)
    scrollThumb:SetScript("OnLeave", function(self)
        if not self.drag then self.tex:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.75) end
    end)
    scrollThumb:SetScript("OnMouseDown", function(self)
        local _, cy = GetCursorPosition()
        self.drag = { y = cy / self:GetEffectiveScale(), s = scroll:GetVerticalScroll() }
        self:SetScript("OnUpdate", function(me)
            local _, y = GetCursorPosition()
            y = y / me:GetEffectiveScale()
            local free = scrollTrack:GetHeight() - me:GetHeight()
            if free > 0 then ScrollTo(me.drag.s + (me.drag.y - y) / free * MaxScroll(), true) end
        end)
    end)
    scrollThumb:SetScript("OnMouseUp", function(self)
        self.drag = nil
        self:SetScript("OnUpdate", nil)
        if not self:IsMouseOver() then self.tex:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.75) end
    end)

    noResults = U.Text(content, 13, C.dim, Azaath.media.fontItalic or Azaath.media.font)
    noResults:SetJustifyH("CENTER")
    noResults:SetPoint("TOP", scroll, "TOP", 0, -60)
    noResults:SetWidth(500)
    noResults:Hide()
end

local function BuildFooter()
    local f = CreateFrame("Frame", nil, window)
    f:SetPoint("BOTTOMLEFT", window, "BOTTOMLEFT", G.pad, 8)
    f:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -G.pad, 8)
    f:SetHeight(G.footerH - 12)
    local line = CreateFrame("Frame", nil, f)
    line:SetHeight(10)
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 6)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 6)
    local l = U.Tex(line, "ARTWORK")
    l:SetHeight(1)
    l:SetPoint("LEFT")
    l:SetPoint("RIGHT")
    Azaath.Gradient(l, "HORIZONTAL", C.gold[1], C.gold[2], C.gold[3], 0.05, C.gold[1], C.gold[2], C.gold[3], 0.3)

    footerLegend = U.Text(f, 11, C.dim)
    footerLegend:SetWordWrap(false)
    footerLegend:SetPoint("LEFT", f, "LEFT", 4, -2)

    pendingBtn = U.Button(f, "", 160, function() ReloadUI() end, "primary")
    pendingBtn:SetPoint("RIGHT", f, "RIGHT", 0, -2)
    pendingText = U.Text(f, 12, C.reload, Azaath.media.fontBold)
    pendingText:SetWordWrap(false)
    pendingText:SetPoint("RIGHT", pendingBtn, "LEFT", -12, 0)
    if not U.pendingReload then pendingBtn:Hide(); pendingText:Hide() end
end

local function BuildWindow()
    window = CreateFrame("Frame", "AzaathUIConfig", UIParent)
    U.window = window
    window:SetSize(G.W, G.H)
    window:SetPoint("CENTER", UIParent, "CENTER", 0, 10)
    window:SetFrameStrata("DIALOG")
    window:SetToplevel(true)
    window:EnableMouse(true)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    U.Box(window, C.bg, 0.97, C.gold, 0.55)
    window:Hide()
    tinsert(UISpecialFrames, "AzaathUIConfig")

    -- moldura dupla, brilho no topo e losangos nos cantos
    local inner = CreateFrame("Frame", nil, window)
    inner:SetPoint("TOPLEFT", 5, -5)
    inner:SetPoint("BOTTOMRIGHT", -5, 5)
    Azaath.SetBackdrop(inner, { edgeFile = Azaath.media.blank, edgeSize = 1 })
    inner:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 0.14)
    local topGlow = U.Tex(window, "BACKGROUND")
    topGlow:SetPoint("TOPLEFT", 1, -1)
    topGlow:SetPoint("TOPRIGHT", -1, -1)
    topGlow:SetHeight(170)
    Azaath.Gradient(topGlow, "VERTICAL", C.accent[1], C.accent[2], C.accent[3], 0, C.accent[1], C.accent[2], C.accent[3], 0.07)
    U.Chrome(window, 112)

    BuildHeader()
    BuildNav()
    BuildContent()
    BuildFooter()

    window:SetScript("OnShow", function()
        Azaath.PlaySound("igCharacterInfoOpen")
        U.ApplyWindowScale()
        PaintLang()
        U.RefreshVisible()
    end)
    window:SetScript("OnHide", function()
        Azaath.PlaySound("igCharacterInfoClose")
        if searchBox:HasFocus() then searchBox:ClearFocus() end
        U.HideTip()
    end)

    U.Relocalize()
    local saved = Azaath.db and Azaath.db.config and Azaath.db.config.page
    local start = 1
    for i, p in ipairs(U.PAGES) do if p.key == saved then start = i end end
    U.SelectPage(start)
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------
function U.Open()
    if not window then BuildWindow() end
    window:Show()
    if U.current then U.SelectPage(U.current) end
end

function U.Toggle()
    if window and window:IsShown() then window:Hide() else U.Open() end
end

function U.IsShown() return window and window:IsShown() end
function U.Hide() if window then window:Hide() end end

--------------------------------------------------------------------------------
-- Atalho nas Opções da Blizzard (Esc > Opções > AddOns)
--------------------------------------------------------------------------------
function U.CreateOptionsStub()
    local hasSettings = Settings and Settings.RegisterCanvasLayoutCategory
    if not (hasSettings or InterfaceOptions_AddCategory) or U.stub then return end
    local stub = CreateFrame("Frame", "AzaathUIOptionsStub", UIParent)
    U.stub = stub
    stub.name = "AzaathUI"
    stub:Hide()

    local title = U.Text(stub, 20, C.gold, Azaath.media.fontTitleB)
    title:SetPoint("TOPLEFT", stub, "TOPLEFT", 16, -16)
    title:SetText("AZAATHUI")
    local info = U.Text(stub, 13, C.cream)
    info:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)

    local function Leave()
        Azaath.HidePanel(_G.SettingsPanel)
        Azaath.HidePanel(_G.InterfaceOptionsFrame)
        Azaath.HidePanel(_G.GameMenuFrame)
    end
    local open = U.Button(stub, "", 200, function() Leave(); U.Open() end, "primary")
    open:SetPoint("TOPLEFT", info, "BOTTOMLEFT", 0, -14)
    local edit = U.Button(stub, "", 200, function() Leave(); Azaath:GetModule("Config"):ToggleEditMode(true) end)
    edit:SetPoint("LEFT", open, "RIGHT", 10, 0)

    function stub:Localize()
        info:SetText(L("ui.stubInfo"))
        open.text:SetText(L("ui.stubOpen"))
        edit.text:SetText(L("ui.stubEdit"))
    end
    stub:Localize()

    if hasSettings then
        local category = Settings.RegisterCanvasLayoutCategory(stub, stub.name)
        Settings.RegisterAddOnCategory(category)
    else
        InterfaceOptions_AddCategory(stub)
    end
end
