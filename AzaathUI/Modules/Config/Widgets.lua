--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Config/Widgets.lua
    Estilo Azoth do painel (paleta, fontes, painéis) e as linhas de opção:
    interruptor, slider (−/+ e valor digitável), escolha segmentada, botão e nota.

    Cada linha é um frame com:
      row:Localize()     textos no idioma atual
      row:Measure(w)     ajusta larguras e devolve a altura para a largura w
      row:Refresh()      valor atual + estado ativo/inativo
      row.search         texto (minúsculo) usado pela busca
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.ConfigUI

local type, ipairs, format, tostring, tonumber = type, ipairs, string.format, tostring, tonumber
local floor, max, min, abs = math.floor, math.max, math.min, math.abs

local MEDIA = "Interface\\AddOns\\AzaathUI\\Media\\"
U.MEDIA = MEDIA

--------------------------------------------------------------------------------
-- Estilo
--------------------------------------------------------------------------------
local S = {
    ctrlW   = 300,  -- coluna dos controles
    gap     = 24,   -- entre o texto e o controle
    rowPadY = 10,
    minRowH = 48,
    choiceH = 28,
    choiceGap = 6,
    choiceMinW = 118,
}
U.S = S

local C = {}
U.C = C
function U.InitColors()
    local c = Azaath.colors
    C.gold    = c.gold
    C.accent  = c.accent
    C.cream   = c.cream
    C.dim     = c.dim
    C.dark    = c.dark
    C.slate   = c.slate
    C.bg      = { 0.035, 0.040, 0.050 }
    C.panel   = { 0.060, 0.068, 0.082 }
    C.card    = { 0.078, 0.088, 0.104 }
    C.reload  = { 0.98, 0.58, 0.22 }
    C.danger  = { 0.88, 0.36, 0.28 }
    C.off     = { 0.42, 0.44, 0.46 }
end
U.InitColors() -- Azaath.colors já existe (Core.lua carrega antes)

local backdrop
function U.Backdrop()
    if not backdrop then
        local blank = Azaath.media.blank
        backdrop = { bgFile = blank, edgeFile = blank, edgeSize = 1,
                     insets = { left = 1, right = 1, top = 1, bottom = 1 } }
    end
    return backdrop
end

-- Painel com fundo e borda (cores em tabelas {r,g,b})
function U.Box(frame, bg, bgA, border, borderA)
    Azaath.SetBackdrop(frame, U.Backdrop())
    bg, border = bg or C.panel, border or C.gold
    frame:SetBackdropColor(bg[1], bg[2], bg[3], bgA or 0.95)
    frame:SetBackdropBorderColor(border[1], border[2], border[3], borderA or 0.35)
end

-- Compatível com o Config.lua antigo (Modo de Edição)
function U.Panel(frame, alpha, borderAlpha)
    U.Box(frame, Azaath.colors.dark, alpha or 0.9, Azaath.colors.gold, borderAlpha or 0.4)
end
U.GetBackdrop = U.Backdrop

function U.Text(parent, size, color, font, layer)
    local c = color or C.cream or Azaath.colors.cream
    local fs = parent:CreateFontString(nil, layer or "OVERLAY")
    fs:SetFont(font or Azaath.media.font, size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.85)
    fs:SetTextColor(c[1], c[2], c[3])
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(true)
    return fs
end
function U.CreateText(parent, size, color) return U.Text(parent, size, color) end

function U.Tex(parent, layer, path, r, g, b, a)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(path or Azaath.media.blank)
    if r then t:SetVertexColor(r, g, b, a or 1) end
    return t
end

--------------------------------------------------------------------------------
-- Arte do painel e do assistente (Media/ConfigUI, gerada por tools/configui-art/gen.js)
--------------------------------------------------------------------------------
local ART = MEDIA .. "ConfigUI\\"
U.ART = ART

-- coordenadas de textura para espelhar a peça do canto superior esquerdo
local FLIP = {
    TOPLEFT = { 0, 1, 0, 1 }, TOPRIGHT = { 1, 0, 0, 1 },
    BOTTOMLEFT = { 0, 1, 1, 0 }, BOTTOMRIGHT = { 1, 0, 1, 0 },
}
U.FLIP = FLIP

-- Fundo pintado, cantos com voluta e gema, brasão no topo (decoração acima do conteúdo, sem mouse)
function U.Chrome(win, cornerSize)
    local bg = win:CreateTexture(nil, "BACKGROUND", nil, 1)
    bg:SetTexture(ART .. "WindowBG")
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    local deco = CreateFrame("Frame", nil, win)
    deco:SetAllPoints()
    deco:SetFrameLevel(win:GetFrameLevel() + 30)
    local cs = cornerSize or 104
    for point, tc in pairs(FLIP) do
        local t = deco:CreateTexture(nil, "OVERLAY")
        t:SetTexture(ART .. "Corner")
        t:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        t:SetSize(cs, cs)
        t:SetPoint(point, win, point, 0, 0)
    end
    local crest = deco:CreateTexture(nil, "OVERLAY")
    crest:SetTexture(ART .. "Crest")
    crest:SetSize(340, 60)
    crest:SetPoint("CENTER", win, "TOP", 0, 0)
    win.chromeDeco = deco
    return deco
end

-- Cantoneiras douradas num cartão
function U.CardCorners(card, alpha, size)
    card.corners = card.corners or {}
    for point, tc in pairs(FLIP) do
        local t = card:CreateTexture(nil, "OVERLAY")
        t:SetTexture(ART .. "CardCorner")
        t:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        t:SetSize(size or 14, size or 14)
        t:SetPoint(point, card, point, 0, 0)
        t:SetAlpha(alpha or 0.8)
        card.corners[#card.corners + 1] = t
    end
end

-- Divisor: linhas que se apagam nas pontas + peça central com gema
function U.Divider(parent, a)
    local l, r = parent:CreateTexture(nil, "ARTWORK"), parent:CreateTexture(nil, "ARTWORK")
    for _, t in ipairs({ l, r }) do t:SetTexture(Azaath.media.blank); t:SetHeight(1) end
    l:SetPoint("LEFT", parent, "LEFT")
    l:SetPoint("RIGHT", parent, "CENTER", -60, 0)
    r:SetPoint("LEFT", parent, "CENTER", 60, 0)
    r:SetPoint("RIGHT", parent, "RIGHT")
    Azaath.Gradient(l, "HORIZONTAL", C.gold[1], C.gold[2], C.gold[3], 0, C.gold[1], C.gold[2], C.gold[3], a or 0.6)
    Azaath.Gradient(r, "HORIZONTAL", C.gold[1], C.gold[2], C.gold[3], a or 0.6, C.gold[1], C.gold[2], C.gold[3], 0)
    local c = parent:CreateTexture(nil, "OVERLAY")
    c:SetTexture(ART .. "DividerCenter")
    c:SetSize(150, 22)
    c:SetPoint("CENTER", parent, "CENTER")
end

-- Rotação contínua de uma textura (anéis de runas)
function U.Spin(tex, secs)
    local ag = tex:CreateAnimationGroup()
    local rot = ag:CreateAnimation("Rotation")
    rot:SetDegrees(-360)
    rot:SetDuration(secs or 30)
    ag:SetLooping("REPEAT")
    ag:Play()
    return ag
end

-- Losango laranja inline: marca opções que pedem /reload
U.RELOAD_ICON = "|T" .. MEDIA .. "Diamond:10:10:0:0:64:64:0:64:0:64:250:148:56|t"

--------------------------------------------------------------------------------
-- Tooltip didático
--------------------------------------------------------------------------------
function U.Tooltip(owner, title, body, extra)
    if not title then return end
    if (owner:GetWidth() or 0) > 320 then
        -- linhas largas: a dica fica acima da linha, alinhada à coluna dos controles
        GameTooltip:SetOwner(owner, "ANCHOR_NONE")
        GameTooltip:ClearAllPoints()
        GameTooltip:SetPoint("BOTTOMRIGHT", owner, "TOPRIGHT", -6, 2)
    else
        GameTooltip:SetOwner(owner, "ANCHOR_RIGHT", 8, 0)
    end
    GameTooltip:SetText(title, C.accent[1], C.accent[2], C.accent[3], 1, true)
    if body and body ~= "" then GameTooltip:AddLine(body, 1, 1, 1, true) end
    if extra then
        for _, line in ipairs(extra) do
            GameTooltip:AddLine(line[1], line[2], line[3], line[4], true)
        end
    end
    GameTooltip:SetMinimumWidth(260)
    GameTooltip:Show()
end
function U.ShowTooltip(owner, text)
    if not text then return end
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
end
local function HideTip() GameTooltip:Hide() end
U.HideTip = HideTip

--------------------------------------------------------------------------------
-- Botão estilizado
--   kind: nil (normal), "primary", "danger", "ghost"
--------------------------------------------------------------------------------
function U.Button(parent, label, width, onClick, kind, icon)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 28)
    b.kind = kind
    local function Paint(hover)
        local border = (kind == "danger" and C.danger) or C.accent
        if kind == "ghost" then
            b:SetBackdropColor(0, 0, 0, 0)
            b:SetBackdropBorderColor(0, 0, 0, 0)
            local t = hover and C.accent or C.dim
            b.text:SetTextColor(t[1], t[2], t[3])
            if b.icon then b.icon:SetVertexColor(t[1], t[2], t[3]) end
            return
        end
        if kind == "primary" then
            b:SetBackdropColor(C.accent[1] * 0.30, C.accent[2] * 0.24, C.accent[3] * 0.12, hover and 1 or 0.92)
            b:SetBackdropBorderColor(border[1], border[2], border[3], hover and 1 or 0.75)
            b.text:SetTextColor(hover and 1 or C.accent[1], hover and 1 or C.accent[2], hover and 1 or C.accent[3])
        else
            b:SetBackdropColor(C.panel[1] * 1.3, C.panel[2] * 1.3, C.panel[3] * 1.3, hover and 1 or 0.9)
            local bc = hover and border or (kind == "danger" and C.danger or C.gold)
            b:SetBackdropBorderColor(bc[1], bc[2], bc[3], hover and 0.95 or 0.45)
            local t = hover and { 1, 1, 1 } or (kind == "danger" and C.danger or C.cream)
            b.text:SetTextColor(t[1], t[2], t[3])
        end
        if b.icon then
            local t = hover and { 1, 1, 1 } or C.accent
            b.icon:SetVertexColor(t[1], t[2], t[3])
        end
    end
    Azaath.SetBackdrop(b, U.Backdrop())
    b.text = U.Text(b, 12, C.cream, Azaath.media.fontBold)
    b.text:SetWordWrap(false)
    b.text:SetJustifyH("CENTER")
    if icon then
        b.icon = U.Tex(b, "ARTWORK", icon)
        b.icon:SetSize(14, 14)
        b.icon:SetPoint("LEFT", b, "LEFT", 10, 0)
        b.text:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
        b.text:SetPoint("RIGHT", b, "RIGHT", -8, 0)
    else
        b.text:SetPoint("LEFT", b, "LEFT", 6, 0)
        b.text:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    end
    b.text:SetText(label or "")
    b.Paint = Paint
    b:SetScript("OnEnter", function(self)
        Paint(true)
        if self.tipTitle then U.Tooltip(self, self.tipTitle, self.tipBody) end
    end)
    b:SetScript("OnLeave", function() Paint(false); HideTip() end)
    b:SetScript("OnClick", function(self, ...)
        if self.disabled then return end
        Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        if onClick then onClick(self, ...) end
    end)
    Paint(false)
    return b
end

-- Usado pelo Modo de Edição (assinatura antiga)
function U.CreateStyledButton(parent, label, width, onClick)
    local b = U.Button(parent, label, width, onClick)
    b:SetHeight(24)
    return b
end

-- Botão só com ícone (fechar, limpar busca)
function U.IconButton(parent, size, path, onClick, tipTitle)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(size, size)
    b.tex = U.Tex(b, "ARTWORK", path, C.dim[1], C.dim[2], C.dim[3])
    b.tex:SetPoint("CENTER")
    b.tex:SetSize(size * 0.6, size * 0.6)
    b.tipTitle = tipTitle
    b:SetScript("OnEnter", function(self)
        self.tex:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
        if self.tipTitle then U.Tooltip(self, self.tipTitle) end
    end)
    b:SetScript("OnLeave", function(self)
        self.tex:SetVertexColor(C.dim[1], C.dim[2], C.dim[3])
        HideTip()
    end)
    b:SetScript("OnClick", function(self, ...) if onClick then onClick(self, ...) end end)
    return b
end

--------------------------------------------------------------------------------
-- Valor das opções
--------------------------------------------------------------------------------
function U.GetValue(def)
    if def.get then return def.get() end
    if not def.path then return nil end
    local t, k = U.Resolve(def.path)
    local v = t and t[k]
    if def.neg and type(v) == "number" then v = -v end
    return v
end

function U.SetValue(def, v)
    if def.set then
        def.set(v)
    elseif def.path then
        local t, k = U.Resolve(def.path)
        if t then t[k] = (def.neg and type(v) == "number") and -v or v end
    end
    if def.reload then U.MarkReload() end
    if def.apply then
        local ok, err = pcall(def.apply, v)
        if not ok and Azaath.LogError then Azaath.LogError("AzaathUI config " .. tostring(err)) end
    end
    if def.onChange then def.onChange(v) end
    if U.RefreshVisible then U.RefreshVisible() end
end

local function PathOn(path)
    local t, k = U.Resolve(path)
    return t and t[k] and true or false
end

-- Ativo? (e por que não)
function U.IsActive(def, sec)
    local needs = def.needs or (sec and sec.needs)
    if needs and not PathOn(needs) then
        return false, format(U.L("ui.needs"), U.L(needs))
    end
    local when, why = def.when, def.why
    if not when and sec then when, why = sec.when, sec.why end
    if when and not when() then return false, why and U.L(why) end
    return true
end

local function FormatDefault(def)
    if not def.path and not def.resetPaths then return nil end
    local d
    if def.get then
        -- opções com acesso próprio: mostra o padrão lendo o banco de padrões
        local path = def.resetPaths and def.resetPaths[1]
        if def.key == "minimap.square" then d = U.DefaultOf("minimap.shape") == "square"
        elseif def.key == "chat.bold" then d = U.DefaultOf("chat.fontStyle") == "bold"
        elseif def.key == "experience.autoWidth" then d = (U.DefaultOf("experience.width") or 0) <= 0
        elseif path then d = U.DefaultOf(path) end
    else
        d = U.DefaultOf(def.path)
        if def.neg and type(d) == "number" then d = -d end
    end
    if d == nil then return nil end
    if def.t == "toggle" then
        return U.L(d and "ui.on" or "ui.off")
    elseif def.t == "slider" then
        return format(def.fmt or "%d", d)
    elseif def.t == "choice" then
        return U.L("o." .. def.path .. "=" .. tostring(d))
    end
    return tostring(d)
end

local function RowTooltip(row)
    local def = row.def
    local key = def.key or def.path
    local extra = {}
    local d = FormatDefault(def)
    if d then extra[#extra + 1] = { format(U.L("ui.default"), d), C.dim[1], C.dim[2], C.dim[3] } end
    if def.reload then extra[#extra + 1] = { U.L("ui.reloadTip"), C.reload[1], C.reload[2], C.reload[3] } end
    if def.t == "slider" then extra[#extra + 1] = { U.L("ui.wheelTip"), C.dim[1], C.dim[2], C.dim[3] } end
    if not row.active and row.reason then
        extra[#extra + 1] = { row.reason, C.danger[1], C.danger[2], C.danger[3] }
    end
    U.Tooltip(row, U.L(key), U.L(key, 2), extra)
end

--------------------------------------------------------------------------------
-- Base das linhas
--------------------------------------------------------------------------------
local function NewRow(parent, def, sec, frameType)
    local row = CreateFrame(frameType or "Frame", nil, parent)
    row.def, row.sec = def, sec
    row.active = true

    row.hl = U.Tex(row, "BACKGROUND")
    row.hl:SetAllPoints()
    Azaath.Gradient(row.hl, "HORIZONTAL", C.accent[1], C.accent[2], C.accent[3], 0.07, C.accent[1], C.accent[2], C.accent[3], 0)
    row.hl:Hide()

    row.sep = U.Tex(row, "BORDER", nil, C.gold[1], C.gold[2], C.gold[3], 0.08)
    row.sep:SetHeight(1)
    row.sep:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.sep:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)

    row.label = U.Text(row, 13, C.cream, Azaath.media.fontBold)
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -S.rowPadY)
    row.desc = U.Text(row, 11, C.dim)
    row.desc:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -3)
    row.desc:SetSpacing(1)

    row:EnableMouse(true)
    row:SetScript("OnEnter", function(self)
        self.hl:Show()
        RowTooltip(self)
    end)
    row:SetScript("OnLeave", function(self)
        self.hl:Hide()
        HideTip()
    end)

    function row:Localize()
        local key = self.def.key or self.def.path
        local label = U.L(key)
        if self.def.reload then label = label .. "  " .. U.RELOAD_ICON end
        self.label:SetText(label)
        self.desc:SetText(U.L(key, 2) or "")
        self.search = ((U.L(key) or "") .. " " .. (U.L(key, 2) or "")):lower()
        if self.LocalizeExtra then self:LocalizeExtra() end
    end

    -- texto à esquerda, controle à direita
    function row:MeasureText(textW)
        textW = max(120, textW)
        self.label:SetWidth(textW)
        self.desc:SetWidth(textW)
        local h = self.label:GetStringHeight()
        local d = self.desc:GetText()
        if d and d ~= "" then h = h + 3 + self.desc:GetStringHeight() end
        return floor(h + 0.5)
    end

    function row:Measure(w)
        local th = self:MeasureText(w - S.ctrlW - S.gap - 10)
        return max(S.minRowH, th + S.rowPadY * 2)
    end

    function row:SetActiveState(on, reason)
        self.active, self.reason = on, reason
        local a = on and 1 or 0.4
        self.label:SetAlpha(a)
        self.desc:SetAlpha(on and 1 or 0.55)
        if self.ctrl then self.ctrl:SetAlpha(on and 1 or 0.35) end
    end

    function row:RefreshActive()
        local on, reason = U.IsActive(self.def, self.sec)
        self:SetActiveState(on, reason)
        return on
    end
    return row
end

--------------------------------------------------------------------------------
-- Interruptor
--------------------------------------------------------------------------------
local function KnobUpdate(sw, elapsed)
    local cur, target = sw.pos, sw.target
    if abs(cur - target) < 0.01 then
        sw.pos = target
        sw:SetScript("OnUpdate", nil)
    else
        sw.pos = cur + (target - cur) * min(1, elapsed * 16)
    end
    sw.knob:SetPoint("CENTER", sw, "LEFT", 11 + sw.pos * 24, 0)
end

local function BuildToggle(parent, def, sec)
    local row = NewRow(parent, def, sec, "Button")

    local ctrl = CreateFrame("Frame", nil, row)
    ctrl:SetSize(S.ctrlW, 24)
    ctrl:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -S.rowPadY + 2)
    row.ctrl = ctrl

    local sw = CreateFrame("Frame", nil, ctrl)
    sw:SetSize(46, 22)
    sw:SetPoint("RIGHT", ctrl, "RIGHT", 0, 0)
    Azaath.SetBackdrop(sw, U.Backdrop())
    sw.knob = U.Tex(sw, "OVERLAY", MEDIA .. "Diamond")
    sw.knob:SetSize(18, 18)
    sw.pos, sw.target = 0, 0
    sw.knob:SetPoint("CENTER", sw, "LEFT", 11, 0)

    local state = U.Text(ctrl, 11, C.dim, Azaath.media.fontBold)
    state:SetPoint("RIGHT", sw, "LEFT", -10, 0)
    state:SetWordWrap(false)

    local function Paint(on, animate, hover)
        sw.target = on and 1 or 0
        if animate then sw:SetScript("OnUpdate", KnobUpdate) else sw.pos = sw.target; KnobUpdate(sw, 0) end
        if on then
            sw:SetBackdropColor(C.accent[1] * 0.32, C.accent[2] * 0.25, C.accent[3] * 0.10, 1)
            sw:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], hover and 1 or 0.8)
            sw.knob:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
            state:SetTextColor(C.accent[1], C.accent[2], C.accent[3])
            state:SetText(U.L("ui.on"))
        else
            sw:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 1)
            local b = hover and C.gold or C.slate
            sw:SetBackdropBorderColor(b[1], b[2], b[3], hover and 0.9 or 0.8)
            sw.knob:SetVertexColor(C.off[1], C.off[2], C.off[3])
            state:SetTextColor(C.off[1], C.off[2], C.off[3])
            state:SetText(U.L("ui.off"))
        end
    end

    function row:Refresh(animate)
        self:RefreshActive()
        Paint(U.GetValue(def) and true or false, animate, self.hl:IsShown())
    end
    row:SetScript("OnClick", function(self)
        if not self.active then return end
        local v = not U.GetValue(def)
        U.SetValue(def, v)
        Azaath.PlaySound(v and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
        self:Refresh(true)
    end)
    row:HookScript("OnEnter", function(self) Paint(U.GetValue(def) and true or false, false, true) end)
    row:HookScript("OnLeave", function(self) Paint(U.GetValue(def) and true or false, false, false) end)
    return row
end

--------------------------------------------------------------------------------
-- Slider
--------------------------------------------------------------------------------
local function BuildSlider(parent, def, sec)
    local row = NewRow(parent, def, sec)
    local fmt = def.fmt or "%d"

    local ctrl = CreateFrame("Frame", nil, row)
    ctrl:SetSize(S.ctrlW, 26)
    ctrl:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -S.rowPadY + 2)
    row.ctrl = ctrl

    local function Snap(v)
        v = floor((v - def.min) / def.step + 0.5) * def.step + def.min
        if v < def.min then v = def.min elseif v > def.max then v = def.max end
        -- tira lixo de ponto flutuante (0.1 + 0.2)
        return tonumber(format("%.4f", v))
    end

    -- caixa do valor (clicar permite digitar)
    local box = CreateFrame("EditBox", nil, ctrl)
    box:SetSize(76, 24)
    box:SetPoint("RIGHT", ctrl, "RIGHT", 0, 0)
    box:SetAutoFocus(false)
    box:SetFont(Azaath.media.fontBold, 12, "")
    box:SetJustifyH("CENTER")
    box:SetTextInsets(4, 4, 0, 0)
    box:SetMaxLetters(10)
    U.Box(box, C.bg, 1, C.gold, 0.35)
    box:SetTextColor(C.accent[1], C.accent[2], C.accent[3])

    local plus = U.IconButton(ctrl, 22, MEDIA .. "MapUI\\Plus")
    plus:SetPoint("RIGHT", box, "LEFT", -6, 0)
    local minus = U.IconButton(ctrl, 22, MEDIA .. "MapUI\\Minus")
    minus:SetPoint("LEFT", ctrl, "LEFT", 0, 0)

    local track = CreateFrame("Frame", nil, ctrl)
    track:SetHeight(6)
    track:SetPoint("LEFT", minus, "RIGHT", 8, 0)
    track:SetPoint("RIGHT", plus, "LEFT", -8, 0)
    U.Box(track, C.bg, 1, C.slate, 0.7)
    local fill = U.Tex(track, "ARTWORK")
    fill:SetPoint("TOPLEFT", track, "TOPLEFT", 1, -1)
    fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT", 1, 1)
    Azaath.Gradient(fill, "HORIZONTAL", C.gold[1], C.gold[2], C.gold[3], 0.55, C.accent[1], C.accent[2], C.accent[3], 1)

    local slider = CreateFrame("Slider", nil, ctrl)
    slider:SetOrientation("HORIZONTAL")
    slider:SetHeight(20)
    slider:SetPoint("LEFT", track, "LEFT", -1, 0)
    slider:SetPoint("RIGHT", track, "RIGHT", 1, 0)
    slider:SetThumbTexture(MEDIA .. "Diamond")
    local thumb = slider:GetThumbTexture()
    thumb:SetSize(16, 16)
    thumb:SetVertexColor(C.accent[1], C.accent[2], C.accent[3])
    slider:SetMinMaxValues(def.min, def.max)
    slider:SetValueStep(def.step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    slider:EnableMouseWheel(false)

    local function PaintFill(v)
        local w = slider:GetWidth()
        if not w or w <= 0 then return end
        local frac = (v - def.min) / (def.max - def.min)
        fill:SetWidth(max(1, 8 + frac * (w - 16) - 1))
    end

    local function Show(v)
        if not box:HasFocus() then box:SetText(format(fmt, v)) end
        PaintFill(v)
    end

    local function Commit(v)
        if not row.active then return end
        v = Snap(v)
        Show(v)
        if v ~= U.GetValue(def) then U.SetValue(def, v) end
    end

    slider:SetScript("OnValueChanged", function(_, v)
        if row.updating then return end
        Commit(v)
    end)
    slider:SetScript("OnSizeChanged", function(self) PaintFill(Snap(self:GetValue())) end)
    slider:SetScript("OnEnter", function() row:GetScript("OnEnter")(row) end)
    slider:SetScript("OnLeave", function() row:GetScript("OnLeave")(row) end)
    thumb:SetDrawLayer("OVERLAY")

    local function Nudge(dir)
        if not row.active then return end
        local v = Snap((U.GetValue(def) or def.min) + dir * def.step)
        row.updating = true
        slider:SetValue(v)
        row.updating = false
        Commit(v)
    end
    plus:SetScript("OnClick", function() Nudge(1) end)
    minus:SetScript("OnClick", function() Nudge(-1) end)

    box:SetScript("OnEditFocusGained", function(self)
        if not row.active then self:ClearFocus(); return end
        self:SetText(tostring(U.GetValue(def) or def.min))
        self:HighlightText()
        self:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
    end)
    box:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 0.35)
        self:SetText(format(fmt, Snap(U.GetValue(def) or def.min)))
    end)
    box:SetScript("OnEnterPressed", function(self)
        local n = tonumber((self:GetText() or ""):gsub(",", "."):match("%-?[%d%.]+") or "")
        if n then
            n = Snap(n)
            row.updating = true
            slider:SetValue(n)
            row.updating = false
            self:ClearFocus()
            Commit(n)
        else
            self:ClearFocus()
        end
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnter", function() row:GetScript("OnEnter")(row) end)
    box:SetScript("OnLeave", function() row:GetScript("OnLeave")(row) end)

    function row:Refresh()
        local on = self:RefreshActive()
        slider:EnableMouse(on)
        box:EnableMouse(on)
        local v = U.GetValue(def)
        if type(v) ~= "number" then v = def.min end
        v = Snap(v)
        self.updating = true
        slider:SetValue(v)
        self.updating = false
        Show(v)
    end
    return row
end

--------------------------------------------------------------------------------
-- Escolha segmentada (os botões ficam abaixo do texto, em quantas linhas couber)
--------------------------------------------------------------------------------
local function OptKey(def, v) return "o." .. def.path .. "=" .. tostring(v) end

local function BuildChoice(parent, def, sec)
    local row = NewRow(parent, def, sec)
    local buttons = {}
    local ctrl = CreateFrame("Frame", nil, row)
    row.ctrl = ctrl

    local function PaintButton(b, hover)
        local cur = U.GetValue(def)
        local active = (b.value == cur)
        local enabled = not (b.opt.enabled and not b.opt.enabled())
        if active then
            b:SetBackdropColor(C.accent[1] * 0.28, C.accent[2] * 0.22, C.accent[3] * 0.10, 1)
            b:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
            b.text:SetTextColor(1, 0.92, 0.72)
            b.mark:Show()
        else
            b:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.95)
            local bc = hover and C.accent or C.gold
            b:SetBackdropBorderColor(bc[1], bc[2], bc[3], hover and 0.8 or 0.28)
            local t = hover and C.cream or C.dim
            b.text:SetTextColor(t[1], t[2], t[3])
            b.mark:Hide()
        end
        b:SetAlpha(enabled and 1 or 0.35)
    end

    for i, opt in ipairs(def.options) do
        local b = CreateFrame("Button", nil, ctrl)
        b:SetHeight(S.choiceH)
        Azaath.SetBackdrop(b, U.Backdrop())
        b.opt, b.value = opt, opt.v
        b.mark = U.Tex(b, "OVERLAY", MEDIA .. "Diamond", C.accent[1], C.accent[2], C.accent[3])
        b.mark:SetSize(9, 9)
        b.mark:SetPoint("LEFT", b, "LEFT", 9, 0)
        b.text = U.Text(b, 12, C.dim, Azaath.media.fontBold)
        b.text:SetWordWrap(false)
        b.text:SetJustifyH("CENTER")
        b.text:SetPoint("LEFT", b, "LEFT", 20, 0)
        b.text:SetPoint("RIGHT", b, "RIGHT", -8, 0)
        b:SetScript("OnClick", function(self)
            if not row.active then return end
            if self.opt.enabled and not self.opt.enabled() then return end
            if U.GetValue(def) == self.value then return end
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            U.SetValue(def, self.value)
            row:Refresh()
        end)
        b:SetScript("OnEnter", function(self)
            row.hl:Show()
            PaintButton(self, true)
            local k = OptKey(def, self.value)
            local extra
            if self.opt.enabled and not self.opt.enabled() and def.why then
                extra = { { U.L(def.why), C.danger[1], C.danger[2], C.danger[3] } }
            end
            U.Tooltip(self, U.L(k), U.L(k, 2), extra)
        end)
        b:SetScript("OnLeave", function(self)
            row.hl:Hide()
            PaintButton(self, false)
            HideTip()
        end)
        buttons[i] = b
    end

    function row:LocalizeExtra()
        local words = {}
        for _, b in ipairs(buttons) do
            local t = U.L(OptKey(def, b.value))
            b.text:SetText(t)
            words[#words + 1] = t
        end
        self.search = self.search .. " " .. table.concat(words, " "):lower()
    end

    function row:Measure(w)
        local th = self:MeasureText(w - 20)
        local n = #buttons
        local inner = w - 20
        local perLine = max(1, min(n, floor((inner + S.choiceGap) / (S.choiceMinW + S.choiceGap))))
        -- botões com texto longo pedem mais espaço
        local need = 0
        for _, b in ipairs(buttons) do need = max(need, b.text:GetStringWidth() + 40) end
        while perLine > 1 and (inner - (perLine - 1) * S.choiceGap) / perLine < need do perLine = perLine - 1 end
        local bw = floor((inner - (perLine - 1) * S.choiceGap) / perLine)
        if perLine == n then bw = min(bw, max(160, need)) end
        local lines = math.ceil(n / perLine)
        local top = S.rowPadY + th + 10
        ctrl:ClearAllPoints()
        ctrl:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -top)
        ctrl:SetSize(inner, lines * S.choiceH + (lines - 1) * S.choiceGap)
        for i, b in ipairs(buttons) do
            local li = floor((i - 1) / perLine)
            local ci = (i - 1) % perLine
            b:SetWidth(bw)
            b:ClearAllPoints()
            b:SetPoint("TOPLEFT", ctrl, "TOPLEFT", ci * (bw + S.choiceGap), -li * (S.choiceH + S.choiceGap))
        end
        return top + ctrl:GetHeight() + S.rowPadY + 2
    end

    function row:Refresh()
        self:RefreshActive()
        for _, b in ipairs(buttons) do PaintButton(b, false) end
    end
    return row
end

--------------------------------------------------------------------------------
-- Botão de ação
--------------------------------------------------------------------------------
local function BuildAction(parent, def, sec)
    local row = NewRow(parent, def, sec)
    local kind = def.danger and "danger" or (def.primary and "primary") or nil
    local btn = U.Button(row, "", 170, function()
        if row.active and def.run then def.run() end
    end, kind)
    btn:SetHeight(30)
    btn:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, -S.rowPadY + 1)
    btn:HookScript("OnEnter", function() row.hl:Show(); RowTooltip(row) end)
    btn:HookScript("OnLeave", function() row.hl:Hide() end)
    row.ctrl = btn

    function row:LocalizeExtra()
        btn.text:SetText(U.L(def.key, 3) or U.L(def.key))
        btn:SetWidth(max(150, min(S.ctrlW, btn.text:GetStringWidth() + 44)))
    end
    function row:Refresh()
        local on = self:RefreshActive()
        btn.disabled = not on
    end
    return row
end

--------------------------------------------------------------------------------
-- Nota explicativa
--------------------------------------------------------------------------------
local function BuildNote(parent, def, sec)
    local row = CreateFrame("Frame", nil, parent)
    row.def, row.sec, row.isNote = def, sec, true
    local bg = U.Tex(row, "BACKGROUND")
    bg:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -8)
    bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 8)
    Azaath.Gradient(bg, "HORIZONTAL", C.accent[1], C.accent[2], C.accent[3], 0.09, C.accent[1], C.accent[2], C.accent[3], 0.01)
    local bar = U.Tex(row, "BORDER", nil, C.accent[1], C.accent[2], C.accent[3], 0.85)
    bar:SetWidth(2)
    bar:SetPoint("TOPLEFT", bg, "TOPLEFT")
    bar:SetPoint("BOTTOMLEFT", bg, "BOTTOMLEFT")
    local icon = U.Tex(row, "ARTWORK", MEDIA .. "MapUI\\Quill", C.accent[1], C.accent[2], C.accent[3], 0.9)
    icon:SetSize(16, 16)
    icon:SetPoint("TOPLEFT", bg, "TOPLEFT", 12, -9)
    local text = U.Text(row, 12, C.cream)
    text:SetPoint("TOPLEFT", icon, "TOPRIGHT", 10, 1)
    text:SetSpacing(2)
    text:SetAlpha(0.88)

    function row:Localize()
        text:SetText(U.L(def.key))
        self.search = (U.L(def.key) or ""):lower()
    end
    function row:Measure(w)
        text:SetWidth(w - 50)
        return floor(text:GetStringHeight() + 0.5) + 18 + 16
    end
    function row:Refresh() end
    function row:RefreshActive() return true end
    return row
end

U.BUILDERS = {
    toggle = BuildToggle,
    slider = BuildSlider,
    choice = BuildChoice,
    button = BuildAction,
    note   = BuildNote,
}
