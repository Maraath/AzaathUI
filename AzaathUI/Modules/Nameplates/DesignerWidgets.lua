--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/DesignerWidgets.lua
    Componentes de interface (UI) para o Designer Visual de Nameplates.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, tonumber, tostring, type = pairs, ipairs, pcall, tonumber, tostring, type
local floor, max, min, format = math.floor, math.max, math.min, string.format

local UI = {}
NP.UI = UI

local C = {
    bg     = { 0.04, 0.045, 0.055, 0.96 },
    panel  = { 0.07, 0.078, 0.095, 0.95 },
    raised = { 0.095, 0.105, 0.125, 0.96 },
    border = { 0.28, 0.24, 0.16, 0.75 },
    gold   = { 0.89, 0.78, 0.55, 1 },
    accent = { 0.95, 0.60, 0.18, 1 },
    text   = { 0.94, 0.93, 0.90, 1 },
    muted  = { 0.62, 0.62, 0.65, 1 },
    on     = { 0.25, 0.82, 0.45, 1 },
    danger = { 0.88, 0.30, 0.26, 1 },
}
UI.C = C

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}

function UI.Box(f, bg, bd)
    Azaath.SetBackdrop(f, BACKDROP)
    f:SetBackdropColor(NP.RGBA(bg or C.panel))
    f:SetBackdropBorderColor(NP.RGBA(bd or C.border))
    return f
end

function UI.SafeFont(fs, fontName, sz, flags)
    local path = NP.GetFontPath(fontName or "Noto Sans SemiBold")
    local ok = pcall(fs.SetFont, fs, path, sz or 12, flags or "")
    if not ok or not (fs.GetFont and fs:GetFont()) then
        pcall(fs.SetFont, fs, "Fonts\\ARIALN.TTF", sz or 12, flags or "")
    end
end

function UI.Panel(parent, bg, globalName)
    local f = _G.CreateFrame("Frame", globalName, parent)
    return UI.Box(f, bg or C.panel, C.border)
end

function UI.Text(parent, txt, sz, col)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    UI.SafeFont(fs, "Noto Sans SemiBold", sz or 12, "")
    fs:SetShadowOffset(1, -1); fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetTextColor(NP.RGBA(col or C.text))
    if txt then fs:SetText(txt) end
    return fs
end

function UI.Header(parent, txt)
    local f = _G.CreateFrame("Frame", nil, parent)
    f:SetHeight(24)
    local label = UI.Text(f, txt, 12, C.gold)
    label:SetPoint("LEFT", 2, 0)
    local line = f:CreateTexture(nil, "ARTWORK")
    line:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.28)
    line:SetHeight(1)
    line:SetPoint("LEFT", label, "RIGHT", 8, 0)
    line:SetPoint("RIGHT", f, "RIGHT", -2, 0)
    return f
end

function UI.Button(parent, label, w, h, onClick, bg)
    local b = _G.CreateFrame("Button", nil, parent)
    b:SetSize(w or 100, h or 24)
    UI.Box(b, bg or C.raised, C.border)
    b.label = UI.Text(b, label, 11, C.text)
    b.label:SetPoint("CENTER")
    b:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(NP.RGBA(C.gold)) end)
    b:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(NP.RGBA(C.border)) end)
    if onClick then b:SetScript("OnClick", onClick) end
    return b
end

function UI.Tooltip(f, title, body)
    if not (f and (title or body)) then return end
    f:HookScript("OnEnter", function(self)
        _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if title then _G.GameTooltip:AddLine(title, 1, 0.85, 0.45) end
        if body then _G.GameTooltip:AddLine(body, 0.86, 0.86, 0.88, true) end
        _G.GameTooltip:Show()
    end)
    f:HookScript("OnLeave", function() _G.GameTooltip:Hide() end)
end

function UI.Scroll(parent)
    local sf = _G.CreateFrame("ScrollFrame", nil, parent)
    sf:EnableMouseWheel(true)
    local content = _G.CreateFrame("Frame", nil, sf)
    content:SetSize(10, 10)
    sf:SetScrollChild(content)
    sf.content = content

    local track = _G.CreateFrame("Frame", nil, sf)
    track:SetWidth(6); track:SetPoint("TOPRIGHT", -2, -2); track:SetPoint("BOTTOMRIGHT", -2, 2)
    local tbg = track:CreateTexture(nil, "BACKGROUND"); tbg:SetAllPoints(); tbg:SetColorTexture(1, 1, 1, 0.06)
    local thumb = track:CreateTexture(nil, "OVERLAY"); thumb:SetWidth(6); thumb:SetColorTexture(C.gold[1], C.gold[2], C.gold[3], 0.5)
    thumb:SetPoint("TOP", track, "TOP")

    function sf:UpdateBar()
        local ch, sh = content:GetHeight() or 10, sf:GetHeight() or 10
        local maxScroll = max(0, ch - sh)
        if maxScroll <= 1 then track:Hide(); sf:SetVerticalScroll(0); return end
        track:Show()
        local cur = min(maxScroll, max(0, sf:GetVerticalScroll() or 0))
        sf:SetVerticalScroll(cur)
        local th = max(22, (sh / ch) * (track:GetHeight() or sh))
        thumb:SetHeight(th)
        local ratio = cur / maxScroll
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -ratio * max(0, (track:GetHeight() or sh) - th))
    end

    sf:SetScript("OnMouseWheel", function(self, delta)
        local ch, sh = content:GetHeight() or 10, self:GetHeight() or 10
        local mx = max(0, ch - sh)
        local cur = min(mx, max(0, (self:GetVerticalScroll() or 0) - delta * 38))
        self:SetVerticalScroll(cur)
        self:UpdateBar()
    end)
    sf:SetScript("OnSizeChanged", function(self, w)
        content:SetWidth(max(300, (w or self:GetWidth() or 330) - 10))
        self:UpdateBar()
    end)
    return sf
end

function UI.Toggle(parent, label, get, set, tip)
    local row = _G.CreateFrame("Button", nil, parent)
    row:SetHeight(24)
    local box = _G.CreateFrame("Frame", nil, row)
    box:SetSize(16, 16); box:SetPoint("LEFT", 2, 0)
    UI.Box(box, C.bg, C.border)
    local fill = box:CreateTexture(nil, "ARTWORK")
    fill:SetPoint("TOPLEFT", 3, -3); fill:SetPoint("BOTTOMRIGHT", -3, 3)
    fill:SetColorTexture(NP.RGBA(C.accent))
    local txt = UI.Text(row, label, 11, C.text)
    txt:SetPoint("LEFT", box, "RIGHT", 8, 0); txt:SetPoint("RIGHT", row, "RIGHT", -2, 0); txt:SetJustifyH("LEFT")
    function row:Refresh()
        local on = get() and true or false
        fill:SetShown(on)
        box:SetBackdropBorderColor(NP.RGBA(on and C.accent or C.border))
    end
    row:SetScript("OnClick", function()
        set(not (get() and true or false))
        row:Refresh()
    end)
    UI.Tooltip(row, label, tip)
    row:Refresh()
    return row
end

function UI.Range(parent, label, mn, mx, step, get, set, tip)
    local row = _G.CreateFrame("Frame", nil, parent)
    row:SetHeight(38)
    local txt = UI.Text(row, label, 11, C.text)
    txt:SetPoint("TOPLEFT", 2, 0)

    local eb = _G.CreateFrame("EditBox", nil, row)
    eb:SetSize(52, 18); eb:SetPoint("TOPRIGHT", -2, 1)
    eb:SetAutoFocus(false); eb:SetJustifyH("CENTER")
    UI.SafeFont(eb, "Noto Sans SemiBold", 10, "")
    eb:SetTextColor(NP.RGBA(C.gold))
    UI.Box(eb, C.bg, C.border)

    local sl = _G.CreateFrame("Slider", nil, row, "BackdropTemplate")
    sl:SetPoint("TOPLEFT", 4, -20); sl:SetPoint("TOPRIGHT", -4, -20); sl:SetHeight(12)
    sl:SetOrientation("HORIZONTAL")
    sl:SetMinMaxValues(mn, mx); sl:SetValueStep(step or 1)
    if sl.SetObeyStepOnDrag then sl:SetObeyStepOnDrag(true) end
    local bg = sl:CreateTexture(nil, "BACKGROUND"); bg:SetHeight(4); bg:SetPoint("LEFT"); bg:SetPoint("RIGHT")
    bg:SetColorTexture(0.18, 0.19, 0.22, 1)
    local thumb = sl:CreateTexture(nil, "OVERLAY"); thumb:SetSize(10, 14); thumb:SetColorTexture(NP.RGBA(C.gold))
    sl:SetThumbTexture(thumb)

    local fmtStr = (step and step < 0.1) and "%.2f" or ((step and step < 1) and "%.1f" or "%d")
    local lock = false
    function row:Refresh()
        lock = true
        local v = tonumber(get()) or mn
        v = max(mn, min(mx, v))
        sl:SetValue(v)
        eb:SetText(format(fmtStr, v))
        lock = false
    end
    sl:SetScript("OnValueChanged", function(_, v)
        if lock then return end
        local s = step or 1
        v = floor(v / s + 0.5) * s
        v = max(mn, min(mx, v))
        eb:SetText(format(fmtStr, v))
        set(v)
    end)
    eb:SetScript("OnEnterPressed", function(self)
        local v = tonumber(self:GetText())
        if v then
            v = max(mn, min(mx, v))
            set(v)
        end
        row:Refresh()
        self:ClearFocus()
    end)
    eb:SetScript("OnEscapePressed", function(self) row:Refresh(); self:ClearFocus() end)
    UI.Tooltip(row, label, tip)
    row:Refresh()
    return row
end

function UI.Color(parent, label, get, set, tip)
    local row = _G.CreateFrame("Button", nil, parent)
    row:SetHeight(24)
    local sw = _G.CreateFrame("Frame", nil, row)
    sw:SetSize(24, 15); sw:SetPoint("RIGHT", -2, 0)
    UI.Box(sw, { 0, 0, 0, 1 }, C.border)
    local tex = sw:CreateTexture(nil, "ARTWORK"); tex:SetPoint("TOPLEFT", 2, -2); tex:SetPoint("BOTTOMRIGHT", -2, 2)
    local txt = UI.Text(row, label, 11, C.text)
    txt:SetPoint("LEFT", 2, 0); txt:SetPoint("RIGHT", sw, "LEFT", -6, 0); txt:SetJustifyH("LEFT")

    function row:Refresh()
        local r, g, b, a = NP.RGBA(get())
        tex:SetColorTexture(r, g, b, a)
    end
    row:SetScript("OnClick", function()
        local r, g, b, a = NP.RGBA(get())
        if a < 0.2 then a = 1 end
        local cp = _G.ColorPickerFrame
        if not cp then return end
        local function Apply()
            local nr, ng, nb = cp:GetColorRGB()
            set({ nr, ng, nb, 1 })
            row:Refresh()
        end
        if cp.SetupColorPickerAndShow then
            cp:SetupColorPickerAndShow({
                r = r, g = g, b = b, opacity = 1, hasOpacity = false,
                swatchFunc = Apply, opacityFunc = Apply,
                cancelFunc = function(prev)
                    if type(prev) == "table" then set({ prev.r or r, prev.g or g, prev.b or b, 1 })
                    else set({ r, g, b, 1 }) end
                    row:Refresh()
                end,
            })
        else
            cp.hasOpacity = false
            cp.func = Apply
            cp.cancelFunc = function() set({ r, g, b, 1 }); row:Refresh() end
            cp:SetColorRGB(r, g, b); cp:Show()
        end
    end)
    UI.Tooltip(row, label, tip)
    row:Refresh()
    return row
end

local activeMenu
function UI.Select(parent, label, valuesOrFn, orderOrNil, get, set, tip)
    local row = _G.CreateFrame("Frame", nil, parent)
    row:SetHeight(26)
    local txt = UI.Text(row, label, 11, C.text)
    txt:SetPoint("LEFT", 2, 0); txt:SetWidth(128); txt:SetJustifyH("LEFT")

    local btn = UI.Button(row, "", 160, 22)
    btn:SetPoint("RIGHT", -2, 0); btn:SetPoint("LEFT", txt, "RIGHT", 6, 0)
    btn.label:SetPoint("LEFT", 8, 0); btn.label:SetPoint("RIGHT", -16, 0); btn.label:SetJustifyH("LEFT")
    local arr = UI.Text(btn, "v", 9, C.gold); arr:SetPoint("RIGHT", -6, 0)

    local function ResolveOpts()
        local raw = type(valuesOrFn) == "function" and valuesOrFn() or valuesOrFn
        local ord = type(orderOrNil) == "function" and orderOrNil() or orderOrNil
        if not ord then
            ord = {}
            if #raw > 0 then
                local map = {}
                for _, v in ipairs(raw) do map[v] = v; ord[#ord + 1] = v end
                return map, ord
            end
            for k in pairs(raw) do ord[#ord + 1] = k end
            table.sort(ord)
        end
        return raw, ord
    end

    function row:Refresh()
        local map = ResolveOpts()
        local cur = get()
        btn.label:SetText(tostring(map[cur] or cur or ""))
    end

    btn:SetScript("OnClick", function(self)
        if activeMenu and activeMenu:IsShown() and activeMenu.owner == self then
            activeMenu:Hide(); return
        end
        if not activeMenu then
            activeMenu = UI.Panel(_G.UIParent, C.bg)
            activeMenu:SetFrameStrata("FULLSCREEN_DIALOG")
            activeMenu.scroll = UI.Scroll(activeMenu)
            activeMenu.scroll:SetPoint("TOPLEFT", 4, -4); activeMenu.scroll:SetPoint("BOTTOMRIGHT", -4, 4)
            activeMenu.rows = {}
        end
        activeMenu.owner = self
        local map, ord = ResolveOpts()
        local cur = get()
        local content = activeMenu.scroll.content
        for _, r in ipairs(activeMenu.rows) do r:Hide() end
        for i, k in ipairs(ord) do
            local item = activeMenu.rows[i]
            if not item then
                item = UI.Button(content, "", 180, 20)
                item.label:SetJustifyH("LEFT"); item.label:SetPoint("LEFT", 6, 0)
                activeMenu.rows[i] = item
            end
            item.label:SetText(tostring(map[k] or k))
            item.label:SetTextColor(NP.RGBA(k == cur and C.accent or C.text))
            item:SetWidth(max(150, (self:GetWidth() or 160) - 16))
            item:ClearAllPoints(); item:SetPoint("TOPLEFT", 2, -(i - 1) * 21)
            item:SetScript("OnClick", function()
                set(k); row:Refresh(); activeMenu:Hide()
            end)
            item:Show()
        end
        content:SetHeight(max(24, #ord * 21 + 4))
        activeMenu:SetSize(max(168, self:GetWidth() or 160), min(240, #ord * 21 + 10))
        activeMenu:ClearAllPoints(); activeMenu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        activeMenu:Show()
        activeMenu.scroll:UpdateBar()
    end)
    UI.Tooltip(row, label, tip)
    row:Refresh()
    return row
end

function UI.HideMenus()
    if activeMenu then activeMenu:Hide() end
end

-- Diálogo simples para Importar / Exportar / Criar Perfil
function UI.ShowTextDialog(title, initialText, readOnly, onConfirm)
    local d = UI.textDialog
    if not d then
        d = UI.Panel(_G.UIParent, C.bg)
        d:SetSize(520, 320); d:SetPoint("CENTER"); d:SetFrameStrata("FULLSCREEN_DIALOG")
        d:EnableMouse(true)
        d.title = UI.Text(d, "", 14, C.gold); d.title:SetPoint("TOPLEFT", 14, -12)
        d.box = UI.Panel(d, C.panel); d.box:SetPoint("TOPLEFT", 14, -38); d.box:SetPoint("BOTTOMRIGHT", -14, 46)
        d.sc = UI.Scroll(d.box); d.sc:SetPoint("TOPLEFT", 6, -6); d.sc:SetPoint("BOTTOMRIGHT", -6, 6)
        d.eb = _G.CreateFrame("EditBox", nil, d.sc.content)
        d.eb:SetMultiLine(true); d.eb:SetAutoFocus(false); d.eb:SetWidth(466)
        UI.SafeFont(d.eb, "Noto Sans", 11, ""); d.eb:SetTextColor(NP.RGBA(C.text))
        d.sc:SetScrollChild(d.eb)
        d.eb:SetScript("OnEscapePressed", function() d:Hide() end)
        d.ok = UI.Button(d, "Confirmar", 110, 26); d.ok:SetPoint("BOTTOMRIGHT", -14, 12)
        d.cancel = UI.Button(d, "Fechar", 90, 26, function() d:Hide() end); d.cancel:SetPoint("BOTTOMRIGHT", d.ok, "BOTTOMLEFT", -8, 0)
        UI.textDialog = d
    end
    d.title:SetText(title or "")
    d.eb:SetText(initialText or "")
    d.sc.content:SetHeight(max(200, d.eb:GetHeight() or 200))
    d.sc:UpdateBar()
    if readOnly then
        d.ok:Hide()
        d.eb:HighlightText()
    else
        d.ok:Show()
        d.ok:SetScript("OnClick", function()
            if onConfirm then onConfirm(d.eb:GetText() or "") end
            d:Hide()
        end)
    end
    d.eb:SetFocus()
    d:Show()
end
