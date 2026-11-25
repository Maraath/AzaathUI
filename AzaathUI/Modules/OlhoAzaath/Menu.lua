--[[----------------------------------------------------------------------------
    AzaathUI - Olho de Azaath / Menu.lua
    Janela de ajustes do Olho (/olho), botão no minimapa e entrada em
    Opções > AddOns. Duas páginas:
      * Aparência: categorias à esquerda (escolher, mostrar/esconder, cor),
        vitrine 3D no meio (Preview.lua) e efeito/tamanho/nome à direita;
      * Ajustes: detecção, geral, quando esconder, recorte do personagem e coleta.
    Tudo passa pela API de Base.lua (ns.GetOption / ns.SetOption...), a mesma
    dos comandos, e a janela se atualiza por ns.Refresh.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local ns = Azaath.OlhoNS
local L = ns.L
local K = ns.Skin

local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min

local W, H = 900, 640
local MARGIN, TOP, FOOT, GAP = 20, 92, 48, 10
local ICONS = "Interface\\Icons\\"
local CAT_ICON = {
    ore = "Trade_Mining", herb = "Trade_Herbalism", quest = "INV_Misc_Note_01",
    chest = "INV_Box_01", bobber = "Trade_Fishing", other = "INV_Misc_Gear_01",
}
local CONFIRM_SECONDS = 4

local win, minimapButton
local page = "look"
local scope -- nil = todos os objetos; senão, a categoria ajustada
local controls = {}  -- tudo que tem :Refresh()
local pages = {}

local function C() return Azaath.ConfigUI.C end
local function Track(ctrl) controls[#controls + 1] = ctrl; return ctrl end
local function T(key) return function() return L[key] end end
local function Tip(key) return function() return L[key .. "_TIP"] end end

local function RefreshAll()
    if not win then return end
    for _, c in ipairs(controls) do c:Refresh() end
end

-- leitura e escrita para os controles; `scoped`: ajuste de aparência da categoria escolhida
local function Get(key, scoped) return function() return ns.GetOption(key, scoped and scope or nil) end end
local function Put(key, scoped) return function(v) ns.SetOption(key, v, scoped and scope or nil) end end

-- coluna simples: cada controle entra abaixo do anterior
local function Column(card, x, y, width)
    return { card = card, x = x, y = y, w = width }
end
local function Add(col, ctrl, height)
    ctrl:SetPoint("TOPLEFT", col.card, "TOPLEFT", col.x, col.y)
    col.y = col.y - (height or ctrl:GetHeight()) - 4
    return Track(ctrl)
end

local function NewCard(parent, x, y, w, h, titleKey)
    local card = K.Card(parent, w, h)
    card:SetPoint("TOPLEFT", x, y)
    if titleKey then
        K.CardTitle(card, T(titleKey))
        Track({ Refresh = card.Retitle })
    end
    return card
end

--------------------------------------------------------------------------------
-- Página Aparência
--------------------------------------------------------------------------------

local function TintColor()
    if scope then return ns.GetColor(scope) end
    local c = C().accent
    return c[1], c[2], c[3]
end

local function CategoryRow(parent, cat, y, width)
    local c = C()
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(width, 44)
    row:SetPoint("TOPLEFT", 10, y)
    local tile = K.Tile(row, 34)
    tile:SetPoint("LEFT", 0, 0)
    tile:EnableMouse(false)
    local icon = tile:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("TOPLEFT", 3, -3)
    icon:SetPoint("BOTTOMRIGHT", -3, 3)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetTexture(cat and (ICONS .. CAT_ICON[cat]) or K.PORTRAIT)
    local name = K.Text(row, 12, c.cream, "bold")
    name:SetPoint("LEFT", tile, "RIGHT", 8, 0)
    name:SetWordWrap(false)
    local select = function()
        scope = cat
        if cat and ns.ShowPreviewCategory then ns.ShowPreviewCategory(cat) end
        RefreshAll()
    end
    row:SetScript("OnClick", function() Azaath.PlaySound("igMainMenuOptionCheckBoxOn"); select() end)
    K.HoverTip(row, function() return cat and L["CATEGORY_" .. cat:upper()] or L.SCOPE_ALL end,
        function() return cat and (L["CATEGORY_" .. cat:upper() .. "_TIP"] .. "\n\n" .. L.SCOPE_ONE_TIP) or L.SCOPE_ALL_TIP end)

    local show, swatch
    if cat then
        show = K.Toggle(row, 18, function() return "" end,
            function() return ns.IsCategoryShown(cat) end,
            function(v) ns.SetCategory(cat, v) end,
            function() return L.SHOW_CATEGORY_TIP end)
        show:SetPoint("RIGHT", row, "RIGHT", -26, 0)
        swatch = K.Swatch(row, function() return ns.GetColor(cat) end,
            function()
                local CPF = ColorPickerFrame
                if not (CPF and CPF.SetupColorPickerAndShow) then ns.Print(L.MSG_NO_PICKER) return end
                local r, g, b = ns.GetColor(cat)
                CPF:SetupColorPickerAndShow({
                    r = r, g = g, b = b, hasOpacity = false,
                    swatchFunc = function() ns.SetColor(cat, CPF:GetColorRGB()) end,
                    cancelFunc = function(old) ns.SetColor(cat, old.r, old.g, old.b) end,
                })
            end,
            function() ns.SetColor(cat) end,
            T("COLOR"), Tip("COLOR"),
            function() return { { L.TIP_COLOR_SET, 0.6, 0.85, 1 }, { L.TIP_COLOR_RESET, 0.6, 0.85, 1 } } end)
        swatch:SetPoint("RIGHT", row, "RIGHT", -2, 0)
        Track(swatch)
        Track(show)
    end
    Track({ Refresh = function()
        local chosen = scope == cat
        tile:SetSelected(chosen)
        local on = not cat or ns.IsCategoryShown(cat)
        icon:SetDesaturated(not on)
        name:SetText(cat and L["CATEGORY_" .. cat:upper()] or L.SCOPE_ALL)
        local t = chosen and c.accent or (on and c.cream or c.off)
        name:SetTextColor(t[1], t[2], t[3])
    end })
end

local function EffectGrid(card, x, y, width)
    local per, size, gap = 5, 36, 6
    local holder = CreateFrame("Frame", nil, card)
    holder:SetPoint("TOPLEFT", x, y)
    local rows = ceil(#ns.EFFECT_ORDER / per)
    holder:SetSize(width, rows * (size + gap) + 16)
    local step = (width - size) / (per - 1)
    local tiles, art = {}, {}
    for i, key in ipairs(ns.EFFECT_ORDER) do
        local t = K.Tile(holder, size)
        t:SetPoint("TOPLEFT", ((i - 1) % per) * step, -floor((i - 1) / per) * (size + gap))
        local inner = size - 8
        for depth, layer in ipairs(ns.EFFECTS[key].icon or {}) do
            local tex = t:CreateTexture(nil, "ARTWORK", nil, min(depth, 7))
            if tex:SetTexture(ns.MEDIA .. layer[1] .. ".tga") == false then tex:Hide() end
            tex:SetBlendMode("ADD")
            tex:SetSize(layer[2] * inner, layer[3] * inner)
            tex:SetPoint("CENTER", layer[4] * inner, layer[5] * inner)
            art[#art + 1] = { tex = tex, a = layer[6], hot = layer[7] }
        end
        t:SetScript("OnClick", function()
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            ns.SetOption("effect", key, scope)
        end)
        K.HoverTip(t, T("EFFECT_" .. key:upper()), Tip("EFFECT_" .. key:upper()))
        tiles[key] = t
    end
    local current = K.Text(holder, 11, C().dim)
    current:SetPoint("BOTTOMLEFT", 0, 0)
    Track({ Refresh = function()
        local now = ns.GetOption("effect", scope)
        for key, t in pairs(tiles) do t:SetSelected(key == now) end
        local r, g, b = TintColor()
        for _, l in ipairs(art) do
            if l.hot then l.tex:SetVertexColor(0.5 + 0.5 * r, 0.5 + 0.5 * g, 0.5 + 0.5 * b, l.a)
            else l.tex:SetVertexColor(r, g, b, l.a) end
        end
        current:SetText(L.EFFECT .. ": |cffffffff" .. L["EFFECT_" .. now:upper()] .. "|r")
    end })
    return holder:GetHeight()
end

local function BuildLook(p)
    local h = p:GetHeight()
    local leftW, midW = 214, 296
    local rightW = p:GetWidth() - leftW - midW - 2 * GAP

    -- categorias
    local list = NewCard(p, 0, 0, leftW, h)
    CategoryRow(list, nil, -12, leftW - 20)
    for i, cat in ipairs(ns.CATEGORY_ORDER) do CategoryRow(list, cat, -12 - i * 50, leftW - 20) end

    -- vitrine
    local stage = NewCard(p, leftW + GAP, 0, midW, h)
    if ns.PreviewPane then ns.PreviewPane(stage, midW - 16, h - 46):SetPoint("TOPLEFT", 8, -8) end

    -- aparência
    local card = NewCard(p, leftW + midW + 2 * GAP, 0, rightW, h, "EFFECT")
    local x, w = 16, rightW - 32
    local col = Column(card, x, -40, w)
    col.y = col.y - EffectGrid(card, x, col.y, w) - 6
    local function Pct(v) return L.FORMAT_PERCENT:format(v) end
    local lim = ns.LIMITS
    Add(col, K.Slider(card, w, T("SIZE"), lim.size[1], lim.size[2], Get("size", true), Put("size", true), nil, Tip("SIZE")))
    Add(col, K.Slider(card, w, T("INTENSITY"), lim.intensity[1], lim.intensity[2], Get("intensity", true), Put("intensity", true), Pct, Tip("INTENSITY")))
    Add(col, K.Slider(card, w, T("OFFSET"), lim.offsetY[1], lim.offsetY[2], Get("offsetY", true), Put("offsetY", true), nil, Tip("OFFSET")))
    local half = (w - 8) / 2
    local sil = K.Toggle(card, half, T("SILHOUETTE"), Get("silhouette", true), function(v)
        ns.SetOption("silhouette", v, scope)
        local fail = ns.SilhouetteFailure()
        if v and fail then ns.Print(L.MSG_CUTOUT_UNAVAILABLE:format(fail)) end
    end, Tip("SILHOUETTE"))
    sil:SetPoint("TOPLEFT", card, "TOPLEFT", x, col.y)
    local fade = K.Toggle(card, half, T("FADE"), Get("followAlpha", true), Put("followAlpha", true), Tip("FADE"))
    fade:SetPoint("TOPLEFT", card, "TOPLEFT", x + half + 8, col.y)
    Track(sil); Track(fade)
    col.y = col.y - 26
    local nameT = K.Toggle(card, half, T("SHOW_NAME"), Get("showName", true), Put("showName", true), Tip("SHOW_NAME"))
    nameT:SetPoint("TOPLEFT", card, "TOPLEFT", x, col.y)
    local iconT = K.Toggle(card, half, T("SHOW_ICON"), Get("showIcon", true), Put("showIcon", true), Tip("SHOW_ICON"))
    iconT:SetPoint("TOPLEFT", card, "TOPLEFT", x + half + 8, col.y)
    Track(nameT); Track(iconT)
    col.y = col.y - 28
    local textS = Add(col, K.Slider(card, w, T("TEXT_SIZE"), lim.textSize[1], lim.textSize[2], Get("textSize", true), Put("textSize", true), Pct, Tip("TEXT_SIZE")))
    local fonts = {}
    for _, key in ipairs(ns.FontChoices()) do
        fonts[#fonts + 1] = { value = key, label = function() return ns.FontName(key) or L.FONT_GAME end }
    end
    local fontC = Add(col, K.Choice(card, w, T("FONT"), fonts, Get("textFont", true), Put("textFont", true), Tip("FONT")))
    Track({ Refresh = function()
        local bare = ns.GlowBare()
        local named = ns.GetOption("showName", scope)
        nameT:SetActive(not bare)
        iconT:SetActive(not bare)
        textS:SetActive(not bare and named)
        fontC:SetActive(not bare and named)
    end })
end

--------------------------------------------------------------------------------
-- Página Ajustes
--------------------------------------------------------------------------------

local MODIFIERS = { LSHIFT = 1, RSHIFT = 1, SHIFT = 1, LCTRL = 1, RCTRL = 1, CTRL = 1, LALT = 1, RALT = 1, ALT = 1,
    LMETA = 1, RMETA = 1, META = 1, UNKNOWN = 1 }

local function Chord(key)
    if MODIFIERS[key] then return nil end
    local s = ""
    if IsAltKeyDown() then s = s .. "ALT-" end
    if IsControlKeyDown() then s = s .. "CTRL-" end
    if IsShiftKeyDown() then s = s .. "SHIFT-" end
    if IsMetaKeyDown and IsMetaKeyDown() then s = s .. "META-" end
    return s .. key
end

local stopListening = function() end

-- linha "Tecla de interação": clique escuta a próxima tecla, botão direito tira
local function KeyRow(card, x, y, w)
    local c = C()
    local row = CreateFrame("Frame", nil, card)
    row:SetSize(w, 26)
    row:SetPoint("TOPLEFT", x, y)
    local label = K.Text(row, 12, c.cream)
    label:SetPoint("LEFT")
    local listening, contested = false, nil
    local button
    local function Label()
        if contested then return L.CONFIRM end
        if listening then return L.KEY_LISTEN end
        local k = ns.GetInteractKey()
        return k and ns.KeyText(k) or L.KEY_NONE
    end
    button = K.Button(row, 130, Label, nil)
    button:SetPoint("RIGHT")
    button:RegisterForClicks("AnyUp")
    local function Listen(on)
        listening, contested = on, nil
        button:EnableKeyboard(on)
        button:EnableMouseWheel(on)
        button.Relabel()
    end
    stopListening = function() if listening then Listen(false) end end
    local function Assign(k)
        local owner = k and ns.KeyOwner(k)
        local ok, why = ns.SetInteractKey(k)
        if not ok then ns.Print(why) elseif owner then ns.Print(L.MSG_KEY_REPLACED:format(ns.KeyText(k), owner)) end
    end
    local function Press(k)
        if k == "ESCAPE" then Listen(false) return end
        local chord = Chord(k)
        if not chord then return end
        if chord ~= contested and ns.KeyOwner(chord) then
            contested = chord
            ns.Print(L.KEY_TAKEN:format(ns.KeyText(chord), ns.KeyOwner(chord)))
            button.Relabel()
            return
        end
        Listen(false)
        Assign(chord)
    end
    button:EnableKeyboard(false)
    button:SetScript("OnKeyDown", function(_, k) Press(k) end)
    button:SetScript("OnMouseWheel", function(_, d) Press(d > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN") end)
    button:SetScript("OnClick", function(_, mb)
        Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        local mouse = mb == "MiddleButton" and "BUTTON3" or (mb:match("^Button(%d+)$") and "BUTTON" .. mb:match("^Button(%d+)$"))
        if listening then
            if mouse then Press(mouse) else Listen(false) end
        elseif mb == "RightButton" then
            Assign(nil)
        elseif InCombatLockdown() then
            ns.Print(L.MSG_KEY_COMBAT)
        else
            Listen(true)
        end
    end)
    button:SetScript("OnEnter", function(self)
        K.Tip(self, L.KEY, listening and L.KEY_LISTEN_TIP or L.KEY_TIP,
            not listening and { { L.TIP_KEY_SET, 0.6, 0.85, 1 }, { L.TIP_KEY_CLEAR, 0.6, 0.85, 1 } } or nil)
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)
    button:RegisterEvent("UPDATE_BINDINGS")
    button:SetScript("OnEvent", function() button.Relabel() end)
    Track({ Refresh = function() label:SetText(L.KEY); button.Relabel() end })
end

local function IgnoreRow(card, x, y, w)
    local c = C()
    local row = CreateFrame("Frame", nil, card)
    row:SetSize(w, 26)
    row:SetPoint("TOPLEFT", x, y)
    row:EnableMouse(true)
    local label = K.Text(row, 12, c.cream)
    label:SetPoint("LEFT")
    row:SetScript("OnEnter", function(self)
        local names, extra = ns.IgnoredNames(), {}
        for i = 1, min(#names, 12) do extra[i] = { names[i], 0.8, 0.8, 0.8 } end
        K.Tip(self, L.IGNORED:format(#names), L.IGNORED_TIP, extra)
    end)
    row:SetScript("OnLeave", function() GameTooltip:Hide() end)
    local b = K.Button(row, 130, T("IGNORE_TARGET"), function() ns.IgnoreTarget() end)
    b:SetPoint("RIGHT")
    b.tipTitle, b.tipBody = L.IGNORE_TARGET, L.IGNORE_TARGET_TIP
    Track({ Refresh = function()
        label:SetText(L.IGNORED:format(#ns.IgnoredNames()))
        b.Relabel()
        b.tipTitle, b.tipBody = L.IGNORE_TARGET, L.IGNORE_TARGET_TIP
    end })
end

local function BuildSettings(p)
    local pw, ph = p:GetWidth(), p:GetHeight()
    local cw = (pw - 2 * GAP) / 3
    local lim = ns.LIMITS
    local function Yd(v) return L.FORMAT_RANGE:format(v) end
    local function Pct(v) return L.FORMAT_PERCENT:format(v) end
    local inner = cw - 32

    -- coluna 1: detecção
    local det = NewCard(p, 0, 0, cw, ph, "HEADER_DETECTION")
    local col = Column(det, 16, -42, inner)
    Add(col, K.Slider(det, inner, T("RANGE"), lim.range[1], lim.range[2], Get("range"), Put("range"), Yd, Tip("RANGE")))
    local arcs = {}
    for i = 0, 2 do arcs[#arcs + 1] = { value = i, label = T("ARC_" .. i), tip = Tip("ARC_" .. i) } end
    Add(col, K.Choice(det, inner, T("DIRECTION"), arcs, Get("arc"), Put("arc"), Tip("DIRECTION")))
    Add(col, K.Toggle(det, inner, T("EXCLUSIVE"), Get("exclusive"), Put("exclusive"), Tip("EXCLUSIVE")))
    Add(col, K.Toggle(det, inner, T("NATIVE_SPARKLE"), Get("nativeSparkle"), Put("nativeSparkle"), Tip("NATIVE_SPARKLE")))
    col.y = col.y - 6
    KeyRow(det, 16, col.y, inner)
    col.y = col.y - 34
    IgnoreRow(det, 16, col.y, inner)

    -- coluna 2: geral + coleta
    local genH = 250
    local gen = NewCard(p, cw + GAP, 0, cw, genH, "HEADER_GENERAL")
    col = Column(gen, 16, -42, inner)
    Add(col, K.Toggle(gen, inner, T("ENABLE"), Get("enabled"), function(v) ns.Toggle(v) end, Tip("ENABLE")))
    Add(col, K.Toggle(gen, inner, T("GLOW_ONLY"), Get("glowOnly"), Put("glowOnly"), Tip("GLOW_ONLY")))
    Add(col, K.Toggle(gen, inner, T("MINIMAP"), function() return not ns.db.minimap.hide end,
        function(v) ns.ShowMinimapButton(v) end, Tip("MINIMAP")))
    Add(col, K.Toggle(gen, inner, T("DEBUG"), Get("debug"), Put("debug"), Tip("DEBUG")))
    local langs = { { value = "auto", label = T("LANGUAGE_AUTO"), tip = Tip("LANGUAGE_AUTO") } }
    local codes = {}
    for code in pairs(ns.LOCALES) do codes[#codes + 1] = code end
    table.sort(codes)
    for _, code in ipairs(codes) do
        langs[#langs + 1] = { value = code, label = function() return ns.LOCALES[code].LANGUAGE_NAME end }
    end
    Add(col, K.Choice(gen, inner, T("LANGUAGE"), langs, Get("language"), Put("language"), Tip("LANGUAGE")))

    local gat = NewCard(p, cw + GAP, -(genH + GAP), cw, ph - genH - GAP, "HEADER_GATHER")
    col = Column(gat, 16, -42, inner)
    local sw = Add(col, K.Toggle(gat, inner, T("NODE_SWITCH"), Get("nodeSwitch"), Put("nodeSwitch"), Tip("NODE_SWITCH")))
    local yards = Add(col, K.Slider(gat, inner, T("NODE_SWITCH_YARDS"), lim.nodeSwitchYards[1], lim.nodeSwitchYards[2],
        Get("nodeSwitchYards"), Put("nodeSwitchYards"), Yd, Tip("NODE_SWITCH_YARDS")))
    Track({ Refresh = function() yards:SetActive(ns.GetOption("nodeSwitch")) end })

    -- coluna 3: esconder + recorte
    local hideH = 160
    local hid = NewCard(p, 2 * (cw + GAP), 0, cw, hideH, "HEADER_HIDE")
    col = Column(hid, 16, -42, inner)
    Add(col, K.Toggle(hid, inner, T("HIDE_COMBAT"), Get("hideInCombat"), Put("hideInCombat"), Tip("HIDE_COMBAT")))
    Add(col, K.Toggle(hid, inner, T("HIDE_INSTANCE"), Get("hideInInstance"), Put("hideInInstance"), Tip("HIDE_INSTANCE")))
    Add(col, K.Toggle(hid, inner, T("HIDE_LOCKED"), Get("hideLocked"), Put("hideLocked"), Tip("HIDE_LOCKED")))
    Add(col, K.Toggle(hid, inner, T("HIDE_UNTRAINED"), Get("hideUntrained"), Put("hideUntrained"), Tip("HIDE_UNTRAINED")))

    local cut = NewCard(p, 2 * (cw + GAP), -(hideH + GAP), cw, ph - hideH - GAP, "HEADER_SILHOUETTE")
    col = Column(cut, 16, -42, inner)
    local s1 = Add(col, K.Slider(cut, inner, T("ZONE_SIZE"), lim.bodyScale[1], lim.bodyScale[2], Get("bodyScale"), Put("bodyScale"), Pct, Tip("ZONE_SIZE")))
    local s2 = Add(col, K.Slider(cut, inner, T("ZONE_HEIGHT"), lim.bodyShift[1], lim.bodyShift[2], Get("bodyShift"), Put("bodyShift"), Pct, Tip("ZONE_HEIGHT")))
    local s3 = Add(col, K.Toggle(cut, inner, T("ZONE_SHOW"), ns.IsZoneShown, ns.ShowZone, Tip("ZONE_SHOW")))
    Track({ Refresh = function()
        local ok = not ns.SilhouetteFailure()
        s1:SetActive(ok); s2:SetActive(ok); s3:SetActive(ok)
    end })
end

--------------------------------------------------------------------------------
-- Janela
--------------------------------------------------------------------------------

local function ShowPage(name)
    page = name
    for k, f in pairs(pages) do f:SetShown(k == name) end
    RefreshAll()
end

local function Build()
    win = K.Window("OlhoAzaathMenu", W, H)
    win.title:SetText("OLHO DE AZAATH")
    local saved = ns.db.menuPoint
    win:ClearAllPoints()
    if type(saved) == "table" and saved[1] then
        win:SetPoint(saved[1], UIParent, saved[2], saved[3], saved[4])
    else
        win:SetPoint("LEFT", UIParent, "LEFT", 40, 20) -- à esquerda: o personagem fica visível
    end
    win:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local p1, _, p2, x, y = self:GetPoint(1)
        ns.db.menuPoint = { p1, p2, floor(x + 0.5), floor(y + 0.5) }
    end)

    -- abas
    local tabs = {}
    local function Tab(name, key, x)
        local b = K.Button(win, 150, T(key), function() ShowPage(name) end)
        b:SetPoint("TOPRIGHT", win, "TOPRIGHT", x, -54)
        tabs[name] = b
    end
    Tab("settings", "TAB_SETTINGS", -MARGIN)
    Tab("look", "TAB_LOOK", -MARGIN - 158)
    Track({ Refresh = function()
        local c = C()
        for name, b in pairs(tabs) do
            b.Relabel()
            local on = name == page
            local bc = on and c.accent or c.gold
            b:SetBackdropBorderColor(bc[1], bc[2], bc[3], on and 1 or 0.45)
            b.text:SetTextColor(on and 1 or c.cream[1], on and 1 or c.cream[2], on and 1 or c.cream[3])
        end
        if page == "look" then
            win.subtitle:SetText(scope and L.LOOK_OF:format(L["CATEGORY_" .. scope:upper()]) or L.LOOK_OF_ALL)
        else
            win.subtitle:SetText(L.TAB_SETTINGS)
        end
    end })

    for _, name in ipairs({ "look", "settings" }) do
        local f = CreateFrame("Frame", nil, win)
        f:SetSize(W - 2 * MARGIN, H - TOP - FOOT)
        f:SetPoint("TOPLEFT", MARGIN, -TOP)
        pages[name] = f
    end
    BuildLook(pages.look)
    BuildSettings(pages.settings)

    -- "usar aparência geral": só com uma categoria que tem aparência própria
    local shared = K.Button(win, 190, T("SHARED"), function() if scope then ns.ClearOwnSettings(scope) end end)
    shared:SetPoint("BOTTOMLEFT", MARGIN, 14)
    shared.tipTitle, shared.tipBody = L.SHARED, L.SHARED_TIP
    Track({ Refresh = function()
        shared.Relabel()
        shared:SetShown(page == "look" and scope ~= nil and ns.HasOwnSettings(scope))
    end })

    -- padrões (dois cliques)
    local confirmLeft
    local reset = K.Button(win, 130, function() return confirmLeft and L.CONFIRM or L.DEFAULTS end, function()
        if confirmLeft then
            confirmLeft = nil
            ns.ResetOptions()
        else
            confirmLeft = CONFIRM_SECONDS
        end
    end, "danger")
    reset:SetPoint("BOTTOMRIGHT", -MARGIN, 14)
    reset.tipTitle, reset.tipBody = L.DEFAULTS, L.DEFAULTS_TIP
    local foot = K.Text(win, 11, C().dim)
    foot:SetPoint("BOTTOM", 0, 20)
    foot:SetJustifyH("CENTER")
    Track({ Refresh = function()
        foot:SetText(L.FOOTER)
        reset.Relabel()
        reset.tipTitle, reset.tipBody = L.DEFAULTS, L.DEFAULTS_TIP
    end })

    win:SetScript("OnUpdate", function(_, dt)
        if confirmLeft then
            confirmLeft = confirmLeft - dt
            if confirmLeft <= 0 then confirmLeft = nil end
            reset.Relabel()
        end
    end)
    win:SetScript("OnShow", function()
        Azaath.PlaySound("igCharacterInfoOpen")
        ShowPage(page)
    end)
    win:SetScript("OnHide", function()
        Azaath.PlaySound("igCharacterInfoClose")
        confirmLeft = nil
        stopListening()
        if ns.IsZoneShown() then ns.ShowZone(false) end
    end)
    ShowPage(page)
end

function ns.ToggleMenu()
    if not win then Build() end
    win:SetShown(not win:IsShown())
end

-- /olho previa: abre na página de aparência (fecha se já estava nela)
function ns.TogglePreview()
    if win and win:IsShown() and page == "look" then win:Hide() return end
    if not win then Build() end
    win:Show()
    ShowPage("look")
end

--------------------------------------------------------------------------------
-- Botão no minimapa
--------------------------------------------------------------------------------

local function PlaceButton()
    if not minimapButton then return end
    local a = math.rad(ns.db.minimap.angle or 205)
    local r = Minimap:GetWidth() / 2 + 5
    local x, y
    if Azaath.MinimapButtonOffset then
        x, y = Azaath.MinimapButtonOffset(a, r)
    elseif _G.GetMinimapShape and GetMinimapShape() == "SQUARE" then
        local dx, dy = math.cos(a), math.sin(a)
        local m = max(math.abs(dx), math.abs(dy))
        local s = m > 0.001 and (r / m) or r
        x, y = dx * s, dy * s
    else
        x, y = math.cos(a) * r, math.sin(a) * r
    end
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", x, y)
end
ns.PlaceMinimapButton = PlaceButton

local function ButtonTip(self)
    K.Tip(self, "Olho de Azaath", ns.db.enabled and L.TIP_ENABLED or L.TIP_DISABLED, {
        { L.TIP_LEFT_CLICK, 0.6, 0.85, 1 }, { L.TIP_RIGHT_CLICK, 0.6, 0.85, 1 }, { L.TIP_DRAG, 0.6, 0.85, 1 },
    })
end

local function MakeMinimapButton()
    local b = CreateFrame("Button", "OlhoAzaathMinimapButton", Minimap)
    minimapButton = b
    b:SetSize(31, 31)
    b:SetFrameStrata("MEDIUM")
    b:SetFrameLevel(8)
    b:RegisterForClicks("AnyUp")
    b:RegisterForDrag("LeftButton")
    b:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
    bg:SetSize(20, 20)
    bg:SetPoint("TOPLEFT", 7, -5)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    if b.icon:SetTexture(ns.MEDIA .. "icon.tga") == false then b.icon:SetTexture("Interface\\Icons\\Spell_Holy_MindVision") end
    b.icon:SetSize(17, 17)
    b.icon:SetPoint("TOPLEFT", 7, -6)
    local ring = b:CreateTexture(nil, "OVERLAY")
    ring:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    ring:SetSize(53, 53)
    ring:SetPoint("TOPLEFT")
    b:SetScript("OnClick", function(self, mb)
        if mb == "RightButton" then
            ns.Toggle(not ns.db.enabled)
            if self:IsMouseOver() then ButtonTip(self) end
        else
            ns.ToggleMenu()
        end
    end)
    b:SetScript("OnEnter", ButtonTip)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnDragStart", function(self)
        GameTooltip:Hide()
        self:SetScript("OnUpdate", function()
            local cx, cy = Minimap:GetCenter()
            local x, y = GetCursorPosition()
            local k = Minimap:GetEffectiveScale()
            ns.db.minimap.angle = math.deg(math.atan2(y / k - cy, x / k - cx)) % 360
            PlaceButton()
        end)
    end)
    b:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
    PlaceButton()
end

function ns.ShowMinimapButton(on)
    ns.db.minimap.hide = not on
    ns.Refresh()
end

--------------------------------------------------------------------------------
-- Opções > AddOns: uma página que abre a janela do Olho
--------------------------------------------------------------------------------

local function OptionsEntry()
    if not (Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory) then return end
    local f = CreateFrame("Frame", nil, UIParent)
    f:Hide()
    local title = f:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Olho de Azaath")
    local note = f:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    note:SetPoint("TOPLEFT", 16, -44)
    note:SetText(L.OPTIONS_NOTE)
    local open = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    open:SetSize(240, 22)
    open:SetPoint("TOPLEFT", 16, -72)
    open:SetText(L.OPTIONS_OPEN)
    open:SetScript("OnClick", function()
        if SettingsPanel and Azaath.HidePanel then pcall(Azaath.HidePanel, SettingsPanel) end
        if not (win and win:IsShown()) then ns.ToggleMenu() end
    end)
    local ok, cat = pcall(Settings.RegisterCanvasLayoutCategory, f, "Olho de Azaath")
    if ok and cat then pcall(Settings.RegisterAddOnCategory, cat) end
end

--------------------------------------------------------------------------------
-- Ligações
--------------------------------------------------------------------------------

function ns.Refresh()
    if minimapButton then
        minimapButton:SetShown(not ns.db.minimap.hide)
        minimapButton.icon:SetDesaturated(not ns.db.enabled)
    end
    if win and win:IsShown() then RefreshAll() end
end

function ns.Retext()
    if win and win:IsShown() then RefreshAll() end
end

function ns.SetupInterface()
    MakeMinimapButton()
    OptionsEntry()
    ns.Refresh()
end
