--[[----------------------------------------------------------------------------
    AzaathUI - Modules/MapChrome.lua
    A moldura do mapa-múndi "Expedição" (arte tools/map-ui-concept/expedicao/concept.png):
      · moldura de pedra com colunas de runas azaath, estandarte gasto no alto com o nome do lugar
        (clique sobe um nível) e o estandarte pendurado à esquerda
      · 8 botões nos encaixes de pedra dos cantos de baixo: Missões, Loremaster, Coleta, Filtros |
        Centralizar, Configurações, Tela cheia, Fechar
      · Filtros = lugares no mapa + Nomes/Terreno/Inexploradas (a antiga barra de status)
    Texturas: Media/MapFrame/Exp* (tools/map-ui-concept/expedicao/gen.js); painéis ainda usam as de gen.js.
    O mapa em si (Modules/WorldMap.lua) chama: SetBreadcrumb, SetHover, OnWindowMode.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("MapChrome")

local TEX = Azaath.media.path .. "MapFrame\\"
local floor, min, max, sin = math.floor, math.min, math.max, math.sin
local ipairs, pairs = ipairs, pairs

local CYAN = { 0.37, 0.89, 0.90 }

local api                 -- funções do mapa (WorldMap: M.api)
local U = {}              -- peças da moldura

local function Font(fs, size, bold)
    local m = Azaath.media or {}
    local file = bold and (m.fontCard or m.fontCardR) or (m.fontCardR or m.fontCard)
    if not (file and pcall(fs.SetFont, fs, file, size, "")) then fs:SetFontObject(GameFontHighlight) end
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.8)
end

local function Upper(t) return Azaath.Upper and Azaath.Upper(t) or (t or ""):upper() end

-- textura em 9 partes (mx, my: margens em pixels de interface; my = altura/2 vira 3 partes)
local function Nine(parent, name, mx, my, layer, sub)
    local sz = Azaath.MapFrameTex and Azaath.MapFrameTex[name] or { 64, 64 }
    local u, v = mx / sz[1], my / sz[2]
    local cells = {
        { 0, u, 0, v }, { u, 1 - u, 0, v }, { 1 - u, 1, 0, v },
        { 0, u, v, 1 - v }, { u, 1 - u, v, 1 - v }, { 1 - u, 1, v, 1 - v },
        { 0, u, 1 - v, 1 }, { u, 1 - u, 1 - v, 1 }, { 1 - u, 1, 1 - v, 1 },
    }
    local t = {}
    for i, c in ipairs(cells) do
        local x = parent:CreateTexture(nil, layer or "BACKGROUND", nil, sub or 0)
        x:SetTexture(TEX .. name)
        x:SetTexCoord(c[1], c[2], c[3], c[4])
        t[i] = x
    end
    t[1]:SetPoint("TOPLEFT"); t[1]:SetSize(mx, my)
    t[3]:SetPoint("TOPRIGHT"); t[3]:SetSize(mx, my)
    t[7]:SetPoint("BOTTOMLEFT"); t[7]:SetSize(mx, my)
    t[9]:SetPoint("BOTTOMRIGHT"); t[9]:SetSize(mx, my)
    t[2]:SetPoint("TOPLEFT", t[1], "TOPRIGHT"); t[2]:SetPoint("BOTTOMRIGHT", t[3], "BOTTOMLEFT")
    t[8]:SetPoint("TOPLEFT", t[7], "TOPRIGHT"); t[8]:SetPoint("BOTTOMRIGHT", t[9], "BOTTOMLEFT")
    t[4]:SetPoint("TOPLEFT", t[1], "BOTTOMLEFT"); t[4]:SetPoint("BOTTOMRIGHT", t[7], "TOPRIGHT")
    t[6]:SetPoint("TOPLEFT", t[3], "BOTTOMLEFT"); t[6]:SetPoint("BOTTOMRIGHT", t[9], "TOPRIGHT")
    t[5]:SetPoint("TOPLEFT", t[1], "BOTTOMRIGHT"); t[5]:SetPoint("BOTTOMRIGHT", t[9], "TOPLEFT")
    local obj = { tex = t }
    function obj:SetTexture(n) for _, x in ipairs(self.tex) do x:SetTexture(TEX .. n) end end
    function obj:SetVertexColor(r, g, b, a) for _, x in ipairs(self.tex) do x:SetVertexColor(r, g, b, a or 1) end end
    function obj:SetShown(on) for _, x in ipairs(self.tex) do x:SetShown(on) end end
    return obj
end
M.Nine = Nine
M.Font = Font

-- um pixel da tela em unidades de interface do quadro (linhas nítidas em qualquer escala)
local function Pixel(frame)
    local f = (PixelUtil and PixelUtil.GetPixelToUIUnitFactor and PixelUtil.GetPixelToUIUnitFactor()) or 1
    local s = frame:GetEffectiveScale() or 1
    return f / (s > 0 and s or 1)
end
M.Pixel = Pixel

-- caixa arredondada da arte: fundo de cantos redondos e UM filete com arcos lisos nos cantos.
-- As retas são linhas de exatamente 1 pixel da tela; os arcos têm a mesma espessura.
-- radius (em pixels da tela): 6 = cartões (CardFill/CardArc), 9 = janelas (PanelFill/PanelArc).
-- fill, edge: { r, g, b, a }
function M.RoundBox(parent, radius, fill, edge, layer)
    local p = Pixel(parent)
    local R = radius * p
    local big = radius >= 9
    local box = { edge = {} }
    box.fill = Nine(parent, big and "PanelFill" or "CardFill", R, R, layer or "BACKGROUND", -4)
    box.fill:SetVertexColor(fill[1], fill[2], fill[3], fill[4] or 1)
    local function Edge(a1, x1, y1, a2, x2, y2, w, h)
        local t = parent:CreateTexture(nil, "BORDER", nil, 1)
        t:SetColorTexture(1, 1, 1, 1)
        t:SetPoint(a1, x1, y1); t:SetPoint(a2, x2, y2)
        if w then t:SetWidth(w) else t:SetHeight(h) end
        box.edge[#box.edge + 1] = t
    end
    Edge("TOPLEFT", R, 0, "TOPRIGHT", -R, 0, nil, p)
    Edge("BOTTOMLEFT", R, 0, "BOTTOMRIGHT", -R, 0, nil, p)
    Edge("TOPLEFT", 0, -R, "BOTTOMLEFT", 0, R, p, nil)
    Edge("TOPRIGHT", 0, -R, "BOTTOMRIGHT", 0, R, p, nil)
    for _, c in ipairs({ { "TOPLEFT", 0, 1, 0, 1 }, { "TOPRIGHT", 1, 0, 0, 1 },
                         { "BOTTOMLEFT", 0, 1, 1, 0 }, { "BOTTOMRIGHT", 1, 0, 1, 0 } }) do
        local t = parent:CreateTexture(nil, "BORDER", nil, 1)
        t:SetTexture(TEX .. (big and "PanelArc" or "CardArc"))
        t:SetTexCoord(c[2], c[3], c[4], c[5])
        t:SetSize(R, R)
        t:SetPoint(c[1])
        box.edge[#box.edge + 1] = t
    end
    function box:SetEdgeColor(r, g, b, a) for _, t in ipairs(self.edge) do t:SetVertexColor(r, g, b, a or 1) end end
    function box:SetEdgeAlpha(a) for _, t in ipairs(self.edge) do t:SetAlpha(a) end end
    box:SetEdgeColor(edge[1], edge[2], edge[3], edge[4] or 1)
    box.R, box.p = R, p
    return box
end

-- as janelas (missões, detalhes, menus, busca): ardósia translúcida e filete verde-acinzentado
local PANEL_FILL, PANEL_EDGE = { 0.055, 0.078, 0.092, 0.95 }, { 0.27, 0.40, 0.43, 1 }
function M.PanelBox(parent)
    local box = M.RoundBox(parent, 9, PANEL_FILL, PANEL_EDGE)
    -- luz fina no alto, por dentro
    local hi = parent:CreateTexture(nil, "BORDER", nil, 0)
    hi:SetColorTexture(1, 1, 1, 0.04)
    hi:SetPoint("TOPLEFT", box.R, -2 * box.p); hi:SetPoint("TOPRIGHT", -box.R, -2 * box.p); hi:SetHeight(box.p)
    return box
end

local function Tex(parent, name, w, h, layer, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    t:SetTexture(TEX .. name)
    if w then t:SetSize(w, h or w) end
    return t
end
M.Tex = Tex

-- X no canto superior direito de um painel do estandarte: fecha pelo menu lateral (o ícone apaga junto)
function M.PanelClose(panel)
    local b = CreateFrame("Button", nil, panel)
    b:SetSize(24, 24)
    b:SetPoint("TOPRIGHT", -8, -8)
    b:SetFrameLevel(panel:GetFrameLevel() + 5)
    local i = Tex(b, "IcoClose", 14, 14)
    i:SetPoint("CENTER")
    b:SetScript("OnEnter", function() i:SetVertexColor(CYAN[1], CYAN[2], CYAN[3]) end)
    b:SetScript("OnLeave", function() i:SetVertexColor(1, 1, 1) end)
    b:SetScript("OnClick", function() M:SetActive(nil) end)
    return b
end

local function DB() return Azaath.db.worldmap end

-- faixa de nível de um mapa: tenta a do jogo (C_Map.GetMapLevels; no Forever devolve 0)
-- e, senão, a das missões que começam na zona (QuestDB:ZoneLevelRange).
function M.MapLevels(mapID)
    if C_Map and C_Map.GetMapLevels then
        local ok, lo, hi = pcall(C_Map.GetMapLevels, mapID)
        if ok and lo and hi and lo > 0 and hi > 0 then return lo, hi end
    end
    local Q = Azaath:GetModule("QuestDB")
    if Q and Q.ZoneLevelRange then
        local lo, hi = Q:ZoneLevelRange(mapID)
        if lo and hi then return lo, hi end
    end
end

-- cor da dificuldade da faixa para o nível do jogador (vermelho > laranja > amarelo > verde > cinza)
function M.LevelColor(lo, hi)
    local me = UnitLevel and UnitLevel("player") or 0
    if me < lo - 2 then return { 0.95, 0.38, 0.28 }
    elseif me < lo then return { 1, 0.62, 0.25 }
    elseif me <= hi then return { 1, 0.84, 0.3 }
    elseif me <= hi + 5 then return { 0.5, 0.86, 0.42 } end
    return { 0.62, 0.62, 0.62 }
end

---------------------------------------------------------------------------
-- Moldura "Expedição": peças recortadas da arte 2000x1116 (tools/map-ui-concept/expedicao/gen.js),
-- escaladas pela largura da janela (k = largura / 2000). As vigas e as colunas de runas esticam;
-- cantos, estandarte de cima (com as cordas) e estandarte pendurado ficam no tamanho da arte.
---------------------------------------------------------------------------
local ART_W = 2000
local PAPER_L, PAPER_T, PAPER_R, PAPER_B = 76, 65, 76, 68     -- o papel do mapa dentro da moldura
local SIDE_W_WIN, SIDE_W_MAX, SIDE_GAP = 340, 360, 6          -- gaveta lateral direita (fora do mapa)
-- botões (pixels da arte): o menu desce pelo pano do estandarte à direita do mapa; fechar e tela cheia no alto à direita
local MENU_STEP, MENU_SIZE = 60, 60
-- tela cheia e fechar: medalhões na pedra do canto superior direito (50 px da borda direita em 2000 px)
local WIN_Y, WIN_RIGHT, WIN_STEP, WIN_SIZE = 34, 50, 56, 48
local TITLE_Y, TITLE_SIZE, TITLE_W = 93, 52, 330               -- nome do lugar no estandarte

local function SideOpen() return U.active == "quests" or U.active == "loremaster" end
function M:GetSideWidth(h)
    if not SideOpen() then return 0 end
    if api and api.IsMaximized and api.IsMaximized() then return SIDE_W_MAX end
    h = h or (U.f and U.f:GetHeight()) or 692
    return max(280, min(380, floor(h * 0.5)))
end
function M.GetSideDock() return U.sideDock end

local function Piece(parent, name, sub)
    local t = parent:CreateTexture(nil, "ARTWORK", nil, sub or 0)
    t:SetTexture(TEX .. name)
    return t
end

local function TitleFit()
    local fs, k = U.title, U.k or 0.6
    local file = Azaath.media and Azaath.media.fontTitleB or STANDARD_TEXT_FONT
    local size = floor(TITLE_SIZE * k + 0.5)
    repeat
        fs:SetFont(file, size, "")
        fs:SetText(U.titleText or "")
        if fs:GetStringWidth() <= TITLE_W * k or size <= 11 then break end
        size = size - 1
    until false
    fs:SetShadowOffset(2 * k, -2 * k)
    local lv = U.titleLv
    if lv then
        local lf = Azaath.media and (Azaath.media.fontCinzel or Azaath.media.fontTitleB) or STANDARD_TEXT_FONT
        if not pcall(lv.SetFont, lv, lf, max(9, floor(24 * k + 0.5)), "") then lv:SetFontObject(GameFontNormal) end
        lv:SetShadowOffset(1.5 * k, -1.5 * k)
        lv:ClearAllPoints()
        lv:SetPoint("TOP", fs, "BOTTOM", 0, -3 * k)
        lv:SetText(U.titleLvText or "")
        local c = U.titleLvColor
        if c then lv:SetTextColor(c[1], c[2], c[3]) end
    end
    U.titleBtn:SetSize(max(fs:GetStringWidth(), 60 * k) + 24 * k, 64 * k)
end

local function BuildFrame(f)
    local fr = CreateFrame("Frame", nil, f)
    fr:SetAllPoints()
    fr:SetFrameLevel(f:GetFrameLevel() + 28)
    U.fr = fr
    local P = {}
    for _, n in ipairs({ "ExpTopL", "ExpTopMidL", "ExpTopMidR", "ExpTopR", "ExpLeft", "ExpRight", "ExpBotL", "ExpBotMid", "ExpBotR" }) do
        P[n] = Piece(fr, n, 0)
    end
    P.ExpBanner = Piece(fr, "ExpBanner", 2)     -- estandarte e cordas por cima das vigas
    P.ExpFlag = Piece(fr, "ExpFlag", 3)         -- o estandarte do menu, à direita do mapa
    P.ExpFlag:SetTexCoord(1, 0, 0, 1)
    U.P = P

    -- gaveta lateral direita (Missões / Loremaster), lado a lado com o mapa
    local dock = CreateFrame("Frame", nil, f)
    dock:SetFrameLevel(f:GetFrameLevel() + 25)
    dock:EnableMouse(true)
    M.PanelBox(dock)
    dock:Hide()
    U.sideDock = dock

    -- botão de recolher/expandir no canto inferior direito do mapa (estilo Blizzard)
    local db = CreateFrame("Button", nil, fr)
    db:SetSize(32, 32)
    db:SetFrameLevel(fr:GetFrameLevel() + 6)
    M.RoundBox(db, 6, { 0.08, 0.11, 0.13, 0.96 }, { 0.72, 0.60, 0.36 })
    local dhl = db:CreateTexture(nil, "HIGHLIGHT")
    dhl:SetAllPoints()
    dhl:SetColorTexture(0.95, 0.82, 0.45, 0.18)
    db.ico = db:CreateTexture(nil, "OVERLAY")
    db.ico:SetSize(16, 16)
    db.ico:SetPoint("CENTER")
    db.ico:SetTexture((Azaath.media.path .. "MapUI\\") .. "ChevronRight.tga")
    db.ico:SetVertexColor(0.95, 0.82, 0.42)
    db:SetScript("OnClick", function()
        M:SetActive(SideOpen() and nil or "quests")
    end)
    db:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(SideOpen() and "Recolher painel" or "Abrir Registro de Missões")
        GameTooltip:Show()
    end)
    db:SetScript("OnLeave", function() GameTooltip:Hide() end)
    U.dockBtn = db

    -- alça de redimensionar a janela inteira do mapa (canto inferior direito, modo janela)
    local rg = CreateFrame("Button", nil, fr)
    rg:SetSize(20, 20)
    rg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
    rg:SetFrameLevel(fr:GetFrameLevel() + 10)
    rg:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    rg:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    rg:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    rg:RegisterForClicks("RightButtonUp")
    rg:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOPLEFT")
        GameTooltip:SetText("Arraste para redimensionar o mapa")
        GameTooltip:AddLine("Clique direito: tamanho padrão", 0.7, 0.7, 0.7)
        GameTooltip:Show()
    end)
    rg:SetScript("OnLeave", function() GameTooltip:Hide() end)
    rg:SetScript("OnClick", function()
        if api and api.SetWindowHeight then api.SetWindowHeight(nil) end
    end)
    rg:SetScript("OnMouseDown", function(self, btn)
        if btn ~= "LeftButton" or (api and api.IsMaximized and api.IsMaximized()) then return end
        local left, top = f:GetLeft(), f:GetTop()
        local uiTop = UIParent:GetTop()
        if left and top and uiTop and api and api.SaveWindowPos then
            api.SaveWindowPos("TOPLEFT", left, top - uiTop)
        end
        local ui = UIParent:GetEffectiveScale()
        local cx, cy = GetCursorPosition()
        self.drag = { x = cx / ui, y = cy / ui, w = f:GetWidth(), h = f:GetHeight() }
        self:SetScript("OnUpdate", function(me)
            local st = me.drag
            if not st then return end
            local x, y = GetCursorPosition()
            x, y = x / ui, y / ui
            local dx, dy = x - st.x, st.y - y
            local nh = math.abs(dx) > math.abs(dy) and (st.h + dx * 1116 / 2000) or (st.h + dy)
            if math.abs(nh - f:GetHeight()) > 2 and api and api.SetWindowHeight then
                api.SetWindowHeight(nh)
            end
        end)
    end)
    rg:SetScript("OnMouseUp", function(self)
        self.drag = nil
        self:SetScript("OnUpdate", nil)
    end)
    rg:SetScript("OnHide", function(self)
        self.drag = nil
        self:SetScript("OnUpdate", nil)
    end)
    U.resizeGrip = rg

    -- faixa de cima: arrasta a janela; dois cliques alternam janela/tela cheia
    local drag = CreateFrame("Frame", nil, fr)
    drag:SetPoint("TOPLEFT"); drag:SetPoint("TOPRIGHT")
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() api.StartMoving() end)
    drag:SetScript("OnDragStop", function() api.StopMoving() end)
    drag:SetScript("OnMouseUp", function(_, b)
        local now = GetTime()
        if b == "LeftButton" and U.lastBarClick and now - U.lastBarClick < 0.35 then
            api.SetMaximized(not api.IsMaximized())
            U.lastBarClick = nil
        else
            U.lastBarClick = now
        end
    end)
    U.drag = drag

    -- nome do lugar bordado no estandarte; clique sobe um nível (zona -> continente -> Azeroth)
    local tb = CreateFrame("Button", nil, fr)
    tb:SetFrameLevel(fr:GetFrameLevel() + 4)
    local title = tb:CreateFontString(nil, "OVERLAY")
    title:SetPoint("CENTER")
    title:SetShadowColor(0, 0, 0, 0.85)
    U.title, U.titleBtn = title, tb
    local lv = tb:CreateFontString(nil, "OVERLAY")       -- faixa de nível embaixo do nome
    lv:SetShadowColor(0, 0, 0, 0.85)
    U.titleLv = lv
    local function Color(hover)
        if hover and U.parentMap then title:SetTextColor(1, 0.95, 0.82) else title:SetTextColor(0.93, 0.87, 0.73) end
    end
    Color(false)
    tb:SetScript("OnClick", function() if U.parentMap then api.ShowMap(U.parentMap) end end)
    tb:SetScript("OnEnter", function(self)
        Color(true)
        local chain = U.chain
        if not chain or #chain == 0 then return end
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        local names = {}
        for i, item in ipairs(chain) do names[i] = item.name or "" end
        GameTooltip:SetText(table.concat(names, "  •  "), 0.95, 0.9, 0.78)
        local last = chain[#chain]
        local lo, hi
        if last and last.mapID then lo, hi = M.MapLevels(last.mapID) end
        if lo then GameTooltip:AddLine("Nível " .. (lo == hi and lo or (lo .. " - " .. hi)), 0.85, 0.71, 0.42) end
        if U.parentMap then GameTooltip:AddLine("Clique para voltar a " .. (chain[#chain - 1].name or ""), 0.7, 0.72, 0.72) end
        GameTooltip:Show()
    end)
    tb:SetScript("OnLeave", function() Color(false); GameTooltip:Hide() end)
    U.titleText = "AZEROTH"
end

function M:SetBreadcrumb(chain)
    if not U.title then return end
    U.chain = chain or {}
    local last = U.chain[#U.chain]
    U.titleText = Upper(last and last.name or "")
    local parent = U.chain[#U.chain - 1]
    U.parentMap = parent and parent.mapID or nil
    -- só zonas (e abaixo): continentes e Azeroth ficam sem faixa
    local lo, hi
    local info = last and last.mapID and C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(last.mapID)
    local ZONE = Enum and Enum.UIMapType and Enum.UIMapType.Zone or 3
    if info and info.mapType and info.mapType >= ZONE then lo, hi = M.MapLevels(last.mapID) end
    if lo then
        U.titleLvText = "NÍVEL " .. (lo == hi and lo or (lo .. " - " .. hi))
        U.titleLvColor = M.LevelColor(lo, hi)
    else
        U.titleLvText, U.titleLvColor = nil, nil
    end
    TitleFit()
end

-- a barra de status saiu (arte): o lugar sob o cursor fica guardado para quem quiser usar
function M:SetHover(text, cx, cy)
    U.hoverText = text
    U.hoverCoords = cx and cy and string.format("%.1f, %.1f", cx, cy) or nil
end

---------------------------------------------------------------------------
-- Menus: Filtros (lugares + o que era a barra de status), Coleta e Configurações
---------------------------------------------------------------------------
local function UnexploredState()
    local db = DB()
    if db.revealAll then return "Coloridas" end
    return db.showUnexplored and "Escuras" or "Ocultas"
end

local function CheckRow(panel, i)
    local r = panel.rows[i]
    if not r then
        r = CreateFrame("Button", nil, panel)
        r:SetHeight(22)
        r.box = Tex(r, "Box", 16, 16)
        r.box:SetPoint("LEFT", 0, 0)
        r.mark = Tex(r, "CheckCyan", 16, 16, "OVERLAY")
        r.mark:SetPoint("CENTER", r.box)
        r.icon = r:CreateTexture(nil, "ARTWORK")
        r.icon:SetSize(15, 15)
        r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        r.fs = r:CreateFontString(nil, "OVERLAY"); Font(r.fs, 14)
        local hl = r:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(CYAN[1], CYAN[2], CYAN[3], 0.08)
        panel.rows[i] = r
    end
    r:Show()
    return r
end

-- items: { label, get, set, icon?, gap?, cycle? (get devolve o texto) }
local function FillMenu(panel, title, items)
    for _, r in ipairs(panel.rows) do r:Hide() end
    panel.title:SetText(Upper(title))
    local n, line, col = 0, 0, 0
    local perCol = 16
    for _, it in ipairs(items) do
        if it.gap then
            line = line + 0.45
        else
            if line >= perCol then col, line = col + 1, 0 end
            n = n + 1
            local r = CheckRow(panel, n)
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", panel, "TOPLEFT", 16 + col * 210, -48 - line * 24)
            r:SetWidth(196)
            r.fs:ClearAllPoints()
            if it.cycle then
                r.box:Hide(); r.mark:Hide(); r.icon:Hide()
                r.fs:SetPoint("LEFT", 0, 0)
                r.fs:SetText(it.label .. ": |cffd9b46a" .. it.get() .. "|r")
            else
                r.box:Show()
                r.mark:SetShown(it.get() and true or false)
                if it.icon then
                    r.icon:SetTexture(it.icon); r.icon:Show()
                    r.icon:ClearAllPoints(); r.icon:SetPoint("LEFT", r.box, "RIGHT", 6, 0)
                    r.fs:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
                else
                    r.icon:Hide()
                    r.fs:SetPoint("LEFT", r.box, "RIGHT", 8, 0)
                end
                r.fs:SetText(it.label)
            end
            r.fs:SetTextColor(0.86, 0.86, 0.84)
            r:SetScript("OnClick", function()
                if it.cycle then it.set() else it.set(not it.get()) end
                FillMenu(panel, title, items)
                api.Redraw()
            end)
            line = line + 1
        end
    end
    local cols = col + 1
    panel:SetSize(32 + cols * 210 - 14, 62 + (cols > 1 and perCol or line) * 24)
end

local function MenuItems(which)
    local db = DB()
    if which == "filters" then
        return {
            { label = "Mestres de voo", get = function() return db.poiTaxi ~= false end, set = function(on) db.poiTaxi = on end },
            { label = "Masmorras e raides", get = function() return db.poiDungeons ~= false end, set = function(on) db.poiDungeons = on end },
            { label = "Missões", get = function() return db.poiQuests ~= false end, set = function(on) db.poiQuests = on end },
            { label = "Pins de quest", get = function() return db.blizzQuestPins and true or false end, set = function(on) db.blizzQuestPins = on end },
            { label = "Áreas das missões", get = function() return db.questAreas ~= false end, set = function(on) db.questAreas = on end },
            { label = "Caminho mágico",
              get = function()
                  local qn = Azaath:GetModule("QuestNav")
                  return not (qn and qn.db and qn.db.magicPath == false)
              end,
              set = function(on)
                  local qn = Azaath:GetModule("QuestNav")
                  if qn and qn.SetMagicPathEnabled then qn:SetMagicPathEnabled(on) end
              end },
            { label = "Grupo", get = function() return db.poiGroup ~= false end, set = function(on) db.poiGroup = on end },
            { label = "Raros", get = function() return db.poiRares ~= false end, set = function(on) db.poiRares = on end },
            { label = "Aviso de raros", get = function() return db.rareAlert ~= false end, set = function(on) db.rareAlert = on end },
            { label = "Mostrar raros escondidos", get = function()
                local h = db.rares and db.rares.hide
                return not (h and next(h))
            end, set = function() if db.rares then db.rares.hide = {} end end },
            { gap = true },
            { label = "Nomes", get = function() return db.showNames ~= false end, set = function(on) db.showNames = on; api.Labels() end },
            { label = "Terreno", get = function() return db.terrain and true or false end,
              set = function(on) db.terrain = on; api.ShowMap(api.PlayerMap() or api.WORLD) end },
            { label = "Inexploradas", cycle = true, get = UnexploredState, set = function()
                if db.revealAll then db.showUnexplored, db.revealAll = true, false
                elseif db.showUnexplored then db.showUnexplored, db.revealAll = false, false
                else db.showUnexplored, db.revealAll = true, true end
            end },
        }, "Filtros do mapa"
    elseif which == "gather" then
        local G = Azaath:GetModule("MapGather")
        local items = {
            { label = "Ervas", get = function() return db.gatherHerb ~= false end, set = function(on) db.gatherHerb = on end },
            { label = "Minérios", get = function() return db.gatherOre ~= false end, set = function(on) db.gatherOre = on end },
            { label = "Só o que sei colher", get = function() return db.gatherOnlyKnown and true end, set = function(on) db.gatherOnlyKnown = on end },
            { label = "Usar dados do GatherLite", get = function() return db.gatherLite ~= false end,
              set = function(on) db.gatherLite = on; if G then G:Invalidate() end end },
            { gap = true },
        }
        if G then
            for _, t in ipairs(G:Types()) do
                items[#items + 1] = { label = t.name, icon = t.icon,
                    get = function() return not db.gatherHide[t.name] end,
                    set = function(on) db.gatherHide[t.name] = (not on) or nil end }
            end
        end
        return items, "Coleta"
    else
        return {
            -- interiores: automático = subterrâneos (cidades, cavernas, minas) + a construção onde você está
            { label = "Interiores", cycle = true,
              get = function()
                  local m = db.interiors or "auto"
                  return m == "all" and "Todos" or m == "off" and "Nenhum" or "Automático"
              end,
              set = function()
                  local m = db.interiors or "auto"
                  db.interiors = m == "auto" and "all" or m == "all" and "off" or "auto"
              end },
            { label = "Rota entre as missões", get = function() return db.multiRoute ~= false end, set = function(on) db.multiRoute = on end },
        }, "Configurações do mapa"
    end
end

-- qual botão está ativo: "quests", "loremaster", "gather", "filters", "settings" ou nil
function M:SetActive(key)
    local wasOpen = SideOpen()
    U.active = key
    if key == "quests" or key == "loremaster" or key == nil then
        DB().sidePanel = key or false
    end
    for k, b in pairs(U.btnByKey or {}) do b.glow:SetShown(k == key) end
    local Q = Azaath:GetModule("MapQuests")
    if Q and Q.SetShown then Q:SetShown(key == "quests") end
    local LM = Azaath:GetModule("MapLoremaster")
    if LM and LM.SetShown then LM:SetShown(key == "loremaster") end
    local menu = U.menu
    if key == "gather" or key == "filters" or key == "settings" then
        local items, title = MenuItems(key)
        menu.key = key
        FillMenu(menu, title, items)
        M.PanelAnchor(menu)
        menu:Show()
    else
        menu:Hide()
    end
    if U.dockBtn and U.dockBtn.ico then
        if SideOpen() then
            U.dockBtn.ico:SetTexCoord(0, 1, 0, 1)
        else
            U.dockBtn.ico:SetTexCoord(1, 0, 0, 1)
        end
    end
    if SideOpen() ~= wasOpen and U.f and U.f:IsShown() then
        if api and api.ApplyWindowMode and not (api.IsMaximized and api.IsMaximized()) then
            api.ApplyWindowMode()
        elseif U.Layout then
            U.Layout()
        end
    end
end

-- menus compactos (Coleta, Filtros, Config): abrem à esquerda do estandarte da direita
function M.PanelAnchor(p)
    p:ClearAllPoints()
    local s = p:GetScale() or 1
    if U.flagEdge then
        p:SetPoint("TOPRIGHT", U.flagEdge, "TOPLEFT", -4 / s, -10 / s)
    else
        p:SetPoint("TOPRIGHT", U.P.ExpFlag, "TOPLEFT", 0, -10 / s)
    end
end

---------------------------------------------------------------------------
-- Botões (só o ícone): menu no pano do estandarte da esquerda; janela no canto de cima à direita
---------------------------------------------------------------------------
local function BuildButtons(f)
    local function Toggle(key) M:SetActive(U.active == key and nil or key) end
    local list = {
        { key = "quests", icon = "ExpBtnQuests", tip = "Missões ativas" },
        { key = "loremaster", icon = "ExpBtnLore", tip = "Loremaster da zona (todas as missões)" },
        { key = "gather", icon = "ExpBtnGather", tip = "Coleta: ervas e minérios" },
        { key = "filters", icon = "ExpBtnFilter", tip = "Filtros do mapa" },
        { key = "settings", icon = "ExpBtnSettings", tip = "Configurações do mapa" },
        { icon = "ExpBtnCenter", tip = "Centralizar em mim", click = function() api.FocusPlayer() end },
        { win = true, icon = "ExpWinMax", tip = function() return api.IsMaximized() and "Janela" or "Tela cheia" end,
          click = function() api.SetMaximized(not api.IsMaximized()) end },
        { win = true, icon = "ExpWinClose", tip = "Fechar", click = function() api.Close() end },
    }
    U.buttons, U.btnByKey = {}, {}
    for i, it in ipairs(list) do
        local b = CreateFrame("Button", nil, U.fr)
        b:SetFrameLevel(U.fr:GetFrameLevel() + 6)
        b.win = it.win
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetTexture(TEX .. it.icon)
        b.icon:SetAllPoints()
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetTexture(TEX .. it.icon)
        b.hl:SetAllPoints()
        b.hl:SetBlendMode("ADD")
        b.hl:SetAlpha(0.35)
        -- ativo: o próprio ícone somado em azul azaath, respirando
        b.glow = b:CreateTexture(nil, "OVERLAY")
        b.glow:SetTexture(TEX .. it.icon)
        b.glow:SetAllPoints()
        b.glow:SetBlendMode("ADD")
        b.glow:SetVertexColor(CYAN[1], CYAN[2], CYAN[3])
        b.glow:Hide()
        b:SetScript("OnClick", it.click or function() Toggle(it.key) end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, it.win and "ANCHOR_BOTTOMLEFT" or "ANCHOR_LEFT")
            GameTooltip:SetText(type(it.tip) == "function" and it.tip() or it.tip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        b:SetScript("OnMouseDown", function(self) self.icon:SetAlpha(0.8) end)
        b:SetScript("OnMouseUp", function(self) self.icon:SetAlpha(1) end)
        U.buttons[i] = b
        if it.key then U.btnByKey[it.key] = b end
        if it.icon == "ExpWinMax" then U.maxBtn = b end
    end

    -- o painel dos menus (abre ao lado do estandarte)
    local menu = CreateFrame("Frame", nil, f)
    menu:SetFrameLevel(f:GetFrameLevel() + 32)
    menu:EnableMouse(true)
    M.PanelBox(menu)
    local gem = Tex(menu, "PanelGem", 20, 12, "OVERLAY")
    gem:SetPoint("CENTER", menu, "TOP", 0, 0)
    menu.title = menu:CreateFontString(nil, "OVERLAY"); Font(menu.title, 16)
    menu.title:SetPoint("TOPLEFT", 16, -14)
    menu.title:SetTextColor(0.88, 0.9, 0.9)
    local rule = Tex(menu, "Rule", nil, 10, "OVERLAY")
    rule:SetPoint("TOPLEFT", 10, -36); rule:SetPoint("TOPRIGHT", -10, -36)
    rule:SetBlendMode("ADD")
    menu.rows = {}
    M.PanelClose(menu)
    menu:Hide()
    U.menu = menu
end

---------------------------------------------------------------------------
-- Disposição: tudo em função da largura da janela
---------------------------------------------------------------------------
local function Layout()
    local f, v, P = U.f, U.v, U.P
    local w = f:GetWidth()
    if not w or w < 200 then return end
    local sideW = M:GetSideWidth(f:GetHeight())
    local maxed = api and api.IsMaximized and api.IsMaximized()
    if U.resizeGrip then U.resizeGrip:SetShown(not maxed) end
    local k = maxed and (w / ART_W) or ((w - sideW) / ART_W)
    U.k = k
    local function Size(t, pw, ph) t:SetSize(pw * k, ph * k) end
    for _, t in pairs(P) do t:ClearAllPoints() end

    local rightPad = sideW > 0 and (sideW + SIDE_GAP) or 0
    local mapW = max(200, w - PAPER_L * k - PAPER_R * k - rightPad)
    local mapCenterX = PAPER_L * k + mapW / 2

    P.ExpTopL:SetPoint("TOPLEFT"); Size(P.ExpTopL, 340, 180)
    P.ExpTopR:SetPoint("TOPRIGHT"); Size(P.ExpTopR, 340, 180)
    P.ExpBanner:SetPoint("TOP", f, "TOPLEFT", mapCenterX, 0); Size(P.ExpBanner, 880, 180)
    P.ExpTopMidL:SetPoint("TOPLEFT", P.ExpTopL, "TOPRIGHT"); P.ExpTopMidL:SetPoint("BOTTOMRIGHT", P.ExpBanner, "BOTTOMLEFT")
    P.ExpTopMidR:SetPoint("TOPLEFT", P.ExpBanner, "TOPRIGHT"); P.ExpTopMidR:SetPoint("BOTTOMRIGHT", P.ExpTopR, "BOTTOMLEFT")
    P.ExpBotL:SetPoint("BOTTOMLEFT"); Size(P.ExpBotL, 340, 186)
    P.ExpBotR:SetPoint("BOTTOMRIGHT"); Size(P.ExpBotR, 340, 186)
    P.ExpBotMid:SetPoint("TOPLEFT", P.ExpBotL, "TOPRIGHT"); P.ExpBotMid:SetPoint("BOTTOMRIGHT", P.ExpBotR, "BOTTOMLEFT")
    P.ExpLeft:SetPoint("TOPLEFT", P.ExpTopL, "BOTTOMLEFT"); P.ExpLeft:SetPoint("BOTTOMLEFT", P.ExpBotL, "TOPLEFT")
    P.ExpLeft:SetWidth(150 * k)
    P.ExpRight:SetPoint("TOPRIGHT", P.ExpTopR, "BOTTOMRIGHT"); P.ExpRight:SetPoint("BOTTOMRIGHT", P.ExpBotR, "TOPRIGHT")
    P.ExpRight:SetWidth(150 * k)

    v:ClearAllPoints()
    v:SetPoint("TOPLEFT", f, "TOPLEFT", PAPER_L * k, -PAPER_T * k)
    v:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -(PAPER_R * k + rightPad), PAPER_B * k)
    U.drag:SetHeight(PAPER_T * k)

    if U.sideDock then
        if sideW > 0 then
            U.sideDock:ClearAllPoints()
            U.sideDock:SetPoint("TOPLEFT", v, "TOPRIGHT", SIDE_GAP, 0)
            U.sideDock:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -PAPER_R * k, PAPER_B * k)
            U.sideDock:Show()
        else
            U.sideDock:Hide()
        end
    end

    if U.dockBtn then
        U.dockBtn:ClearAllPoints()
        U.dockBtn:SetPoint("BOTTOMRIGHT", v, "BOTTOMRIGHT", -10, 10)
    end

    -- estandarte do menu à direita do mapa (acompanha a borda direita de v)
    P.ExpFlag:SetPoint("TOPRIGHT", v, "TOPRIGHT", -6 * k, -15 * k); Size(P.ExpFlag, 260, 580)
    if not U.flagEdge then U.flagEdge = U.fr:CreateTexture(nil, "BACKGROUND"); U.flagEdge:SetSize(1, 1) end
    U.flagEdge:ClearAllPoints()
    U.flagEdge:SetPoint("TOPRIGHT", P.ExpFlag, "TOPRIGHT", -232 * k, 0)

    U.titleBtn:ClearAllPoints()
    U.titleBtn:SetPoint("CENTER", f, "TOPLEFT", mapCenterX, -TITLE_Y * k)
    TitleFit()

    -- tela cheia: cantos para fora; já maximizado: cantos para dentro (voltar à janela)
    if U.maxBtn then
        local ico = TEX .. (maxed and "ExpWinRestore" or "ExpWinMax")
        U.maxBtn.icon:SetTexture(ico); U.maxBtn.hl:SetTexture(ico); U.maxBtn.glow:SetTexture(ico)
    end
    local m, winIdx = 0, 0
    for _, b in ipairs(U.buttons) do
        b:ClearAllPoints()
        if b.win then
            -- tela cheia e fechar, da direita para a esquerda a partir da borda direita
            b:SetSize(WIN_SIZE * k, WIN_SIZE * k)
            b:SetPoint("CENTER", f, "TOPRIGHT", -(WIN_RIGHT + (1 - winIdx) * WIN_STEP) * k, -WIN_Y * k)
            winIdx = winIdx + 1
        else
            b:SetSize(MENU_SIZE * k, MENU_SIZE * k)
            b:SetPoint("CENTER", P.ExpFlag, "TOPRIGHT", -118 * k, -(118 + m * MENU_STEP) * k)
            m = m + 1
        end
    end
end
U.Layout = Layout

-- o botão ativo respira em azul azaath
local function Effects()
    if not U.active then return end
    local b = U.btnByKey and U.btnByKey[U.active]
    if b then b.glow:SetAlpha(0.35 + 0.35 * (0.5 + 0.5 * sin(GetTime() * 2.2))) end
end

---------------------------------------------------------------------------
function M:Build(f, v, mapApi)
    api = mapApi
    U.f, U.v = f, v
    local saved = DB().sidePanel
    if saved == nil then saved = "quests" end
    U.active = saved or nil
    BuildFrame(f)
    BuildButtons(f)
    f:HookScript("OnSizeChanged", Layout)
    Layout()
    U.fx = CreateFrame("Frame", nil, f)
    U.fx:SetScript("OnUpdate", Effects)
    f:HookScript("OnShow", function()
        local sp = DB().sidePanel
        if sp == nil then sp = "quests" end
        M:SetActive(sp or nil)
        Layout()
    end)
end

function M:OnWindowMode()
    Layout()
end
