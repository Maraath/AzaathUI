--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Designer.lua
    Designer Visual Interativo completo (/azplates): preview ao vivo com
    clique-para-editar e arraste-para-mover, busca global de configurações,
    Debuffs Customizados, Debuff Colors e Gerenciador de Perfis/Import/Export.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local UI = NP.UI
local C = UI.C
local _G = _G
local pairs, ipairs, pcall, tonumber, tostring, type = pairs, ipairs, pcall, tonumber, tostring, type
local floor, max, min = math.floor, math.max, math.min

local D = {}
NP.Designer = D

local st = {
    tab = "designer",
    unit = "enemynpc",
    look = "full",
    selected = "health",
    search = "",
    preview = {
        target = true, aggro = false, focus = false, casting = false, channel = false,
        important = false, notInterruptible = false, kickReady = true,
        boss = false, quest = true, absorb = false, dots = false, execute = false,
        colorMode = "reaction",
    },
}

local UNIT_TABS = {
    { key = "enemynpc",       label = "NPC Inimigo" },
    { key = "enemyplayer",    label = "Jog. Inimigo" },
    { key = "friendlyplayer", label = "Jog. Aliado" },
    { key = "friendlyplate",  label = "Aliado (Barra)" },
    { key = "friendlynpc",    label = "NPC Aliado" },
    { key = "npcplate",       label = "NPC (Barra)" },
}

local TOP_TABS = {
    { key = "designer",   label = "Designer Visual" },
    { key = "general",    label = "Geral & Estilo" },
    { key = "visibility", label = "Alpha & CVars" },
    { key = "colors",     label = "Cores & Ameaça" },
    { key = "custom",     label = "Debuffs Custom" },
    { key = "profiles",   label = "Perfis & Import" },
}

local function EffectiveUnit()
    if st.look == "ooc" and (st.unit == "enemynpc" or st.unit == "enemyplayer") then
        return NP.OOC_OF[st.unit]
    end
    return st.unit
end

local function ResolvePath(pathStr)
    local out = {}
    local u = EffectiveUnit()
    for seg in pathStr:gmatch("[^%.]+") do
        out[#out + 1] = (seg == "$unit") and u or seg
    end
    return out
end

local function PerUnit(keys)
    return st.tab == "designer" and keys[1] ~= "units" and not NP.SHARED_KEYS[keys[1]]
end

local function GetVal(pathStr)
    local keys = ResolvePath(pathStr)
    local root = PerUnit(keys) and NP.UnitProfile(EffectiveUnit()) or NP.db
    local t = root
    for i = 1, #keys - 1 do
        t = t and t[keys[i]]
        if type(t) ~= "table" then return nil end
    end
    return t and t[keys[#keys]]
end

local refreshGen = 0
local function ScheduleRealRefresh()
    refreshGen = refreshGen + 1
    local mine = refreshGen
    _G.C_Timer.After(0.25, function()
        if mine ~= refreshGen then return end
        NP.RefreshAll()
    end)
end

local function SetVal(pathStr, value)
    if pathStr == "style.barStyle" then
        NP.ApplyBarStylePreset(value, false)
        D:RefreshAll()
        return
    end
    local keys = ResolvePath(pathStr)
    if type(value) == "table" then value = NP.CopyTable(value) end
    local targetRoot = NP.db
    if PerUnit(keys) then
        NP.db.unitOverrides = NP.db.unitOverrides or {}
        local u = EffectiveUnit()
        NP.db.unitOverrides[u] = NP.db.unitOverrides[u] or {}
        targetRoot = NP.db.unitOverrides[u]
    end
    local t = targetRoot
    for i = 1, #keys - 1 do
        if type(t[keys[i]]) ~= "table" then t[keys[i]] = {} end
        t = t[keys[i]]
    end
    t[keys[#keys]] = value
    if pathStr:find("^colors%.threat%.") then
        if NP.ComputePlayerRole then NP.ComputePlayerRole() end
        if not st.preview.aggro then
            st.preview.aggro = true
            D:RefreshChips()
        end
    end
    NP.InvalidateUnitProfiles()
    D:RefreshPreview()
    ScheduleRealRefresh()
end

-- Construtor de linhas de esquema no Inspetor e nas Abas Globais
local function BuildRows(scrollFrame, items)
    local content = scrollFrame.content
    for _, ch in ipairs({ content:GetChildren() }) do ch:Hide(); ch:SetParent(nil) end
    local y = -6
    local sw = scrollFrame:GetWidth() or 0
    local w = max(320, (sw > 40 and sw or 354) - 22)
    content:SetWidth(w + 16)
    local widgets = {}
    for _, it in ipairs(items) do
        local row
        if it.t == "header" then
            row = UI.Header(content, it.label)
        elseif it.t == "toggle" then
            row = UI.Toggle(content, it.label, function() return GetVal(it.path) end, function(v) SetVal(it.path, v) end, it.tip)
        elseif it.t == "range" then
            row = UI.Range(content, it.label, it.min, it.max, it.step, function() return GetVal(it.path) end, function(v) SetVal(it.path, v) end, it.tip)
        elseif it.t == "color" then
            row = UI.Color(content, it.label, function() return GetVal(it.path) end, function(v) SetVal(it.path, v) end, it.tip)
        elseif it.t == "select" then
            row = UI.Select(content, it.label, it.values, it.order, function() return GetVal(it.path) end, function(v) SetVal(it.path, v) end, it.tip)
        end
        if row then
            row:SetWidth(w)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", content, "TOPLEFT", 6, y)
            row:Show()
            y = y - (row:GetHeight() + 6)
            widgets[#widgets + 1] = row
        end
    end
    content:SetHeight(max(20, -y + 10))
    return widgets
end

-- Aba de Debuffs Customizados + Debuff Colors
local function BuildCustomDebuffsView(parent)
    local f = _G.CreateFrame("Frame", nil, parent); f:SetAllPoints()
    local hint = UI.Text(f, "Adicione magias por Nome ou Spell ID para forçar exibição, ocultar, ou colorir a barra de vida (até 5 debuffs seus).", 11, C.muted)
    hint:SetPoint("TOPLEFT", 14, -12); hint:SetPoint("TOPRIGHT", -14, -12); hint:SetJustifyH("LEFT"); hint:SetWordWrap(true)

    local eb = _G.CreateFrame("EditBox", nil, f)
    eb:SetSize(240, 26); eb:SetPoint("TOPLEFT", 14, -44); eb:SetAutoFocus(false)
    UI.SafeFont(eb, "Noto Sans", 11, ""); eb:SetTextColor(NP.RGBA(C.text)); eb:SetTextInsets(8, 8, 0, 0)
    UI.Box(eb, C.bg, C.border)

    local function Lookup(txt)
        txt = _G.strtrim(tostring(txt or ""))
        if txt == "" then return nil end
        local id = tonumber(txt:match("^%d+$") or txt:match("spell:(%d+)") or "")
        local CS = _G.C_Spell
        if not id and CS and CS.GetSpellInfo then
            local ok, info = pcall(CS.GetSpellInfo, txt)
            id = ok and type(info) == "table" and info.spellID or nil
        end
        if not id or id <= 0 then return nil end
        local name = CS and CS.GetSpellName and CS.GetSpellName(id)
        local icon = CS and CS.GetSpellTexture and CS.GetSpellTexture(id)
        return id, name or ("Spell " .. id), icon or 134400
    end

    local incBtn = UI.Button(f, "+ Sempre Mostrar", 130, 26)
    incBtn:SetPoint("LEFT", eb, "RIGHT", 8, 0)
    local excBtn = UI.Button(f, "- Ocultar Sempre", 130, 26)
    excBtn:SetPoint("LEFT", incBtn, "RIGHT", 8, 0)
    local dcBtn = UI.Button(f, "+ Colorir Barra", 130, 26)
    dcBtn:SetPoint("LEFT", excBtn, "RIGHT", 8, 0)

    local incBox = UI.Panel(f, C.panel); incBox:SetPoint("TOPLEFT", 14, -84); incBox:SetSize(300, 440)
    local incT = UI.Text(incBox, "Sempre Mostrar (Include)", 12, C.gold); incT:SetPoint("TOPLEFT", 10, -10)
    local incSc = UI.Scroll(incBox); incSc:SetPoint("TOPLEFT", 6, -34); incSc:SetPoint("BOTTOMRIGHT", -6, 8)

    local excBox = UI.Panel(f, C.panel); excBox:SetPoint("TOPLEFT", incBox, "TOPRIGHT", 12, 0); excBox:SetSize(300, 440)
    local excT = UI.Text(excBox, "Sempre Ocultar (Exclude)", 12, C.gold); excT:SetPoint("TOPLEFT", 10, -10)
    local excSc = UI.Scroll(excBox); excSc:SetPoint("TOPLEFT", 6, -34); excSc:SetPoint("BOTTOMRIGHT", -6, 8)

    local dcBox = UI.Panel(f, C.panel); dcBox:SetPoint("TOPLEFT", excBox, "TOPRIGHT", 12, 0); dcBox:SetPoint("BOTTOMRIGHT", -14, 14)
    local dcT = UI.Text(dcBox, "Colorir Barra por Debuff (máx. 5)", 12, C.gold); dcT:SetPoint("TOPLEFT", 10, -10)
    local dcTog = UI.Toggle(dcBox, "Ativar Debuff Colors", function() return NP.db.colors.debuffColors.enabled end, function(v)
        NP.db.colors.debuffColors.enabled = v; NP.InvalidateUnitProfiles(); NP.DebuffColors.Refresh()
    end)
    dcTog:SetPoint("TOPLEFT", 10, -32); dcTog:SetWidth(260)
    local dcSc = UI.Scroll(dcBox); dcSc:SetPoint("TOPLEFT", 6, -64); dcSc:SetPoint("BOTTOMRIGHT", -6, 8)

    local function RenderSet(sc, set, removeFn)
        local c = sc.content
        for _, ch in ipairs({ c:GetChildren() }) do ch:Hide(); ch:SetParent(nil) end
        local ids = {}
        for id, on in pairs(set or {}) do if on and tonumber(id) then ids[#ids + 1] = tonumber(id) end end
        table.sort(ids)
        for i, id in ipairs(ids) do
            local _, name, icon = Lookup(id)
            local r = UI.Panel(c, C.raised); r:SetSize(268, 28); r:SetPoint("TOPLEFT", 2, -(i - 1) * 30)
            local ic = r:CreateTexture(nil, "ARTWORK"); ic:SetSize(20, 20); ic:SetPoint("LEFT", 4, 0); ic:SetTexture(icon); ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local nm = UI.Text(r, name .. " (" .. id .. ")", 11, C.text); nm:SetPoint("LEFT", ic, "RIGHT", 6, 0); nm:SetPoint("RIGHT", -30, 0); nm:SetJustifyH("LEFT")
            local rm = UI.Button(r, "x", 22, 20, function() removeFn(id) end); rm:SetPoint("RIGHT", -4, 0)
        end
        c:SetHeight(max(20, #ids * 30 + 6)); sc:UpdateBar()
    end

    local function RefreshLists()
        local cu = NP.db.auras.custom
        RenderSet(incSc, cu.include, function(id) cu.include[id] = nil; NP.InvalidateUnitProfiles(); NP.RefreshAll(); RefreshLists() end)
        RenderSet(excSc, cu.exclude, function(id) cu.exclude[id] = nil; NP.InvalidateUnitProfiles(); NP.RefreshAll(); RefreshLists() end)

        local c = dcSc.content
        for _, ch in ipairs({ c:GetChildren() }) do ch:Hide(); ch:SetParent(nil) end
        local list = NP.db.colors.debuffColors.list or {}
        for i, e in ipairs(list) do
            local r = UI.Panel(c, C.raised); r:SetSize(300, 30); r:SetPoint("TOPLEFT", 2, -(i - 1) * 32)
            local _, nm, icTex = Lookup(e.id)
            local ic = r:CreateTexture(nil, "ARTWORK"); ic:SetSize(20, 20); ic:SetPoint("LEFT", 4, 0); ic:SetTexture(icTex); ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local lb = UI.Text(r, nm or tostring(e.id), 11, C.text); lb:SetPoint("LEFT", ic, "RIGHT", 6, 0); lb:SetWidth(150); lb:SetJustifyH("LEFT")
            local col = UI.Color(r, "", function() return e.color end, function(nv) e.color = nv; NP.DebuffColors.Refresh() end)
            col:SetSize(32, 22); col:SetPoint("RIGHT", -32, 0)
            local rm = UI.Button(r, "x", 22, 20, function() table.remove(list, i); NP.DebuffColors.Refresh(); RefreshLists() end)
            rm:SetPoint("RIGHT", -4, 0)
        end
        c:SetHeight(max(20, #list * 32 + 6)); dcSc:UpdateBar()
        dcTog:Refresh()
    end

    incBtn:SetScript("OnClick", function()
        local id = Lookup(eb:GetText()); if not id then return end
        NP.db.auras.custom.include[id] = true; NP.db.auras.custom.exclude[id] = nil
        eb:SetText(""); NP.InvalidateUnitProfiles(); NP.RefreshAll(); RefreshLists()
    end)
    excBtn:SetScript("OnClick", function()
        local id = Lookup(eb:GetText()); if not id then return end
        NP.db.auras.custom.exclude[id] = true; NP.db.auras.custom.include[id] = nil
        eb:SetText(""); NP.InvalidateUnitProfiles(); NP.RefreshAll(); RefreshLists()
    end)
    dcBtn:SetScript("OnClick", function()
        local id, nm = Lookup(eb:GetText()); if not id then return end
        local list = NP.db.colors.debuffColors.list
        if #list >= 5 then Azaath:Print("Máximo de 5 debuffs atingido."); return end
        list[#list + 1] = { id = id, name = nm, color = { 0.85, 0.2, 0.9, 1 } }
        NP.db.colors.debuffColors.enabled = true
        eb:SetText(""); NP.InvalidateUnitProfiles(); NP.DebuffColors.Refresh(); RefreshLists()
    end)

    f.Refresh = RefreshLists
    RefreshLists()
    return f
end

-- Aba de Perfis, Copiar, Resetar e Import/Export
local function BuildProfilesView(parent)
    local f = _G.CreateFrame("Frame", nil, parent); f:SetAllPoints()
    local card = UI.Panel(f, C.panel); card:SetPoint("TOPLEFT", 16, -16); card:SetPoint("BOTTOMRIGHT", -16, 16)

    local t1 = UI.Text(card, "Gerenciamento de Perfis & Compartilhamento", 15, C.gold)
    t1:SetPoint("TOPLEFT", 18, -16)

    local activeTxt = UI.Text(card, "", 12, C.text); activeTxt:SetPoint("TOPLEFT", 18, -48)

    local profNames = function()
        local m = {}
        for k in pairs(AzaathUIDB.npProfiles or {}) do m[k] = k end
        return m
    end
    local sel = UI.Select(card, "Perfil ativo", profNames, nil,
        function() return NP.activeProfileName end,
        function(name)
            if AzaathUIDB.npProfiles[name] then
                AzaathUIDB.npCharProfile[NP.charKey] = name
                NP.activeProfileName = name
                NP.db = AzaathUIDB.npProfiles[name]
                NP.InvalidateUnitProfiles()
                NP.RefreshAll()
                D:RefreshAll()
            end
        end)
    sel:SetSize(340, 28); sel:SetPoint("TOPLEFT", 18, -78)

    local newBtn = UI.Button(card, "Novo Perfil...", 130, 26, function()
        UI.ShowTextDialog("Nome do novo perfil", "", false, function(name)
            name = _G.strtrim(name)
            if name == "" or AzaathUIDB.npProfiles[name] then return end
            AzaathUIDB.npProfiles[name] = NP.CopyTable(NP.DEFAULTS)
            AzaathUIDB.npCharProfile[NP.charKey] = name
            NP.activeProfileName = name; NP.db = AzaathUIDB.npProfiles[name]
            NP.InvalidateUnitProfiles(); NP.RefreshAll(); D:RefreshAll()
        end)
    end)
    newBtn:SetPoint("TOPLEFT", 18, -120)

    local copyBtn = UI.Button(card, "Duplicar Atual...", 140, 26, function()
        UI.ShowTextDialog("Nome da cópia", NP.activeProfileName .. " Cópia", false, function(name)
            name = _G.strtrim(name)
            if name == "" or AzaathUIDB.npProfiles[name] then return end
            AzaathUIDB.npProfiles[name] = NP.CopyTable(NP.db)
            AzaathUIDB.npCharProfile[NP.charKey] = name
            NP.activeProfileName = name; NP.db = AzaathUIDB.npProfiles[name]
            NP.InvalidateUnitProfiles(); NP.RefreshAll(); D:RefreshAll()
        end)
    end)
    copyBtn:SetPoint("LEFT", newBtn, "RIGHT", 10, 0)

    local resetBtn = UI.Button(card, "Restaurar Padrão", 140, 26, function()
        AzaathUIDB.npProfiles[NP.activeProfileName] = NP.CopyTable(NP.DEFAULTS)
        NP.db = AzaathUIDB.npProfiles[NP.activeProfileName]
        NP.InvalidateUnitProfiles(); NP.RefreshAll(); D:RefreshAll()
        Azaath:Print("Perfil '" .. NP.activeProfileName .. "' restaurado ao padrão.")
    end, C.danger)
    resetBtn:SetPoint("LEFT", copyBtn, "RIGHT", 10, 0)

    local t2 = UI.Text(card, "Importar / Exportar String (!AZNP:1!...)", 14, C.gold)
    t2:SetPoint("TOPLEFT", 18, -175)

    local expBtn = UI.Button(card, "Exportar Perfil Atual", 180, 30, function()
        local str, err = NP.ExportProfile(NP.db, NP.activeProfileName)
        if str then
            UI.ShowTextDialog("Exportar Perfil (Ctrl+C para copiar)", str, true)
        else
            Azaath:Print(err or "Erro ao exportar.")
        end
    end)
    expBtn:SetPoint("TOPLEFT", 18, -208)

    local impBtn = UI.Button(card, "Importar String...", 180, 30, function()
        UI.ShowTextDialog("Colar string do perfil (!AZNP:1!...)", "", false, function(str)
            local tbl, nameOrErr = NP.ImportProfileString(str)
            if not tbl then Azaath:Print(nameOrErr or "String inválida."); return end
            local pName = nameOrErr or ("Importado " .. _G.date("%H:%M"))
            if AzaathUIDB.npProfiles[pName] then pName = pName .. " (" .. _G.date("%H:%M:%S") .. ")" end
            AzaathUIDB.npProfiles[pName] = tbl
            AzaathUIDB.npCharProfile[NP.charKey] = pName
            NP.activeProfileName = pName; NP.db = tbl
            NP.InvalidateUnitProfiles(); NP.RefreshAll(); D:RefreshAll()
            Azaath:Print("Perfil importado: " .. pName)
        end)
    end)
    impBtn:SetPoint("LEFT", expBtn, "RIGHT", 12, 0)

    function f:Refresh()
        activeTxt:SetText("Perfil em uso neste personagem: |cffe3c78b" .. tostring(NP.activeProfileName) .. "|r")
        sel:Refresh()
    end
    f:Refresh()
    return f
end

-- Janela principal do Designer
local win
local function BuildWindow()
    win = UI.Panel(_G.UIParent, C.bg, "AzaathNPDesignerFrame")
    win:SetSize(1080, 680); win:SetPoint("CENTER"); win:SetFrameStrata("DIALOG")
    win:SetToplevel(true); win:SetClampedToScreen(true)
    win:SetMovable(true); win:EnableMouse(true); win:RegisterForDrag("LeftButton")
    win:SetScript("OnDragStart", win.StartMoving); win:SetScript("OnDragStop", win.StopMovingOrSizing)
    win:SetScript("OnHide", UI.HideMenus)
    win:Hide()
    _G.tinsert(_G.UISpecialFrames, "AzaathNPDesignerFrame")

    -- Cabeçalho
    local title = UI.Text(win, "AzaathUI — Designer Completo de Nameplates", 15, C.gold)
    title:SetPoint("TOPLEFT", 16, -12)

    local close = UI.Button(win, "Fechar", 76, 24, function() win:Hide() end)
    close:SetPoint("TOPRIGHT", -12, -10)

    local search = _G.CreateFrame("EditBox", nil, win)
    search:SetSize(200, 24); search:SetPoint("RIGHT", close, "LEFT", -10, 0); search:SetAutoFocus(false)
    UI.SafeFont(search, "Noto Sans", 11, ""); search:SetTextColor(NP.RGBA(C.text)); search:SetTextInsets(8, 8, 0, 0)
    UI.Box(search, C.panel, C.border)
    local ph = UI.Text(search, "Buscar opção...", 10, C.muted); ph:SetPoint("LEFT", 8, 0)
    search:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    search:SetScript("OnTextChanged", function(self)
        st.search = (self:GetText() or ""):lower()
        ph:SetShown(st.search == "")
        if st.search ~= "" and st.tab ~= "designer" then
            st.tab = "designer"; D:RefreshAll()
        else
            D:RefreshInspector()
        end
    end)

    -- Abas superiores
    local topBar = _G.CreateFrame("Frame", nil, win); topBar:SetPoint("TOPLEFT", 12, -40); topBar:SetPoint("TOPRIGHT", -12, -40); topBar:SetHeight(28)
    win.topBtns = {}
    for i, tb in ipairs(TOP_TABS) do
        local b = UI.Button(topBar, tb.label, 146, 26, function()
            st.tab = tb.key; D:RefreshAll()
        end)
        b:SetPoint("LEFT", (i - 1) * 150, 0)
        win.topBtns[tb.key] = b
    end

    -- Área principal do Designer (Preview + Inspetor)
    local designerPane = _G.CreateFrame("Frame", nil, win)
    designerPane:SetPoint("TOPLEFT", 12, -74); designerPane:SetPoint("BOTTOMRIGHT", -12, 12)
    win.designerPane = designerPane

    -- Seletor de tipo de unidade + toggle Fora de Combate (OOC)
    local uBar = _G.CreateFrame("Frame", nil, designerPane)
    uBar:SetPoint("TOPLEFT", 0, 0); uBar:SetPoint("TOPRIGHT", -380, 0); uBar:SetHeight(28)
    win.unitBtns = {}
    for i, ut in ipairs(UNIT_TABS) do
        local b = UI.Button(uBar, ut.label, 90, 24, function()
            st.unit = ut.key; st.look = "full"; D:RefreshAll()
        end)
        b:SetPoint("LEFT", (i - 1) * 93, 0)
        win.unitBtns[ut.key] = b
    end
    win.oocBtn = UI.Button(uBar, "OOC", 66, 24, function()
        if st.unit ~= "enemynpc" and st.unit ~= "enemyplayer" then return end
        st.look = (st.look == "ooc") and "full" or "ooc"
        D:RefreshAll()
    end)
    win.oocBtn:SetPoint("LEFT", #UNIT_TABS * 93 + 6, 0)

    -- Canvas de Preview ao vivo
    local canvas = UI.Panel(designerPane, { 0.055, 0.06, 0.072, 1 })
    canvas:SetPoint("TOPLEFT", 0, -32); canvas:SetPoint("BOTTOMRIGHT", -384, 34)
    local cHint = UI.Text(canvas, "Estilo rápido da barra (clique e veja na prévia abaixo):", 10, C.muted)
    cHint:SetPoint("TOPLEFT", 12, -10)

    local styleBar = _G.CreateFrame("Frame", nil, canvas)
    styleBar:SetPoint("TOPLEFT", 10, -26); styleBar:SetPoint("TOPRIGHT", -10, -26); styleBar:SetHeight(24)
    local STYLE_BTNS = {
        { "modern", "Moderno" },
        { "azaath", "Azaath" },
        { "azaath_ink", "Azaath Tinta" },
        { "bdo", "Zerker BDO" },
        { "bdo_pill", "Minimalista BDO" },
    }
    win.styleBtns = {}
    for i, sb in ipairs(STYLE_BTNS) do
        local b = UI.Button(styleBar, sb[2], 124, 22, function()
            NP.ApplyBarStylePreset(sb[1], false)
            D:RefreshAll()
        end)
        b:SetPoint("LEFT", (i - 1) * 128, 0)
        win.styleBtns[sb[1]] = b
    end

    local previewAnchor = _G.CreateFrame("Frame", nil, canvas)
    previewAnchor:SetSize(220, 120); previewAnchor:SetPoint("CENTER", 0, 12)
    local pf = NP.CreatePreviewFrame(previewAnchor)
    pf:ClearAllPoints(); pf:SetPoint("CENTER", previewAnchor, "CENTER", 0, 0)
    pf:SetScale(2.0)
    win.previewFrame = pf

    -- Barra de botões de peças clicáveis (seleciona rapidamente qualquer parte da placa)
    local partsBar = _G.CreateFrame("Frame", nil, canvas)
    partsBar:SetPoint("BOTTOMLEFT", 10, 44); partsBar:SetPoint("BOTTOMRIGHT", -10, 44); partsBar:SetHeight(56)
    win.partBtns = {}
    for i, p in ipairs(NP.Schema.PARTS) do
        local b = UI.Button(partsBar, p.label, 104, 24, function()
            st.selected = p.key; D:RefreshInspector(); D:RefreshPreview()
        end)
        local col, row = (i - 1) % 6, floor((i - 1) / 6)
        b:SetPoint("TOPLEFT", col * 108, -row * 28)
        win.partBtns[p.key] = b
    end

    -- Chips de estado do preview
    local chipsBar = _G.CreateFrame("Frame", nil, canvas)
    chipsBar:SetPoint("BOTTOMLEFT", 10, 8); chipsBar:SetPoint("BOTTOMRIGHT", -10, 8); chipsBar:SetHeight(28)
    local chipDefs = {
        { "target", "Alvo" }, { "aggro", "Aggro" }, { "focus", "Foco" }, { "casting", "Cast" },
        { "channel", "Canal" }, { "important", "Importante" }, { "notInterruptible", "Escudo" },
        { "kickReady", "Kick" }, { "boss", "Chefe" }, { "quest", "Quest" },
        { "execute", "Execute" },
    }
    win.chips = {}
    for i, cd in ipairs(chipDefs) do
        local b = UI.Button(chipsBar, cd[2], 58, 22, function()
            st.preview[cd[1]] = not st.preview[cd[1]]
            D:RefreshPreview(); D:RefreshChips()
        end)
        b:SetPoint("LEFT", (i - 1) * 60, 0)
        win.chips[cd[1]] = b
    end

    -- Inspetor à direita
    local insp = UI.Panel(designerPane, C.panel)
    insp:SetPoint("TOPRIGHT", 0, 0); insp:SetPoint("BOTTOMRIGHT", 0, 0); insp:SetWidth(374)
    insp.title = UI.Text(insp, "", 13, C.gold); insp.title:SetPoint("TOPLEFT", 12, -10)
    insp.scroll = UI.Scroll(insp); insp.scroll:SetPoint("TOPLEFT", 6, -34); insp.scroll:SetPoint("BOTTOMRIGHT", -6, 8)
    win.insp = insp

    -- Painel para Abas Globais (Geral, Alpha/CVars, Cores, Custom Debuffs, Perfis)
    local fullPane = UI.Panel(win, C.panel)
    fullPane:SetPoint("TOPLEFT", 12, -74); fullPane:SetPoint("BOTTOMRIGHT", -12, 12)
    fullPane.scroll = UI.Scroll(fullPane); fullPane.scroll:SetPoint("TOPLEFT", 10, -10); fullPane.scroll:SetPoint("BOTTOMRIGHT", -10, 10)
    fullPane:Hide()
    win.fullPane = fullPane
    win.customView = BuildCustomDebuffsView(fullPane); win.customView:Hide()
    win.profilesView = BuildProfilesView(fullPane); win.profilesView:Hide()

    -- Arraste direto no preview + clique para selecionar peça na placa
    pf:EnableMouse(true)
    local function StartPreviewDrag()
        pf.dragX0, pf.dragY0 = _G.GetCursorPosition()
        pf.origX = GetVal("units.$unit.healthOffsetX") or 0
        pf.origY = GetVal("units.$unit.healthOffsetY") or 0
        pf.dragging = true
        pf.moved = false
    end
    local function StopPreviewDrag() pf.dragging = false end
    pf:SetScript("OnMouseDown", function(_, btn)
        if btn == "RightButton" then
            st.selected = "health"; D:RefreshInspector(); D:RefreshPreview(); return
        end
        if btn == "LeftButton" then StartPreviewDrag() end
    end)
    pf:SetScript("OnMouseUp", StopPreviewDrag)
    pf:SetScript("OnUpdate", function(self)
        if not self.dragging then return end
        local cx, cy = _G.GetCursorPosition()
        if math.abs(cx - self.dragX0) > 3 or math.abs(cy - self.dragY0) > 3 then self.moved = true end
        local sc = self:GetEffectiveScale() or 1
        local dx, dy = (cx - self.dragX0) / sc, (cy - self.dragY0) / sc
        SetVal("units.$unit.healthOffsetX", floor((self.origX + dx) * 2 + 0.5) / 2)
        SetVal("units.$unit.healthOffsetY", floor((self.origY + dy) * 2 + 0.5) / 2)
        D:RefreshInspectorValues()
    end)
    local function BindClickPart(target, key)
        if not target then return end
        target:EnableMouse(true)
        target:SetScript("OnMouseDown", function(_, b) if b == "LeftButton" then StartPreviewDrag() end end)
        target:SetScript("OnMouseUp", function(_, b)
            local wasMoved = pf.moved
            StopPreviewDrag()
            if b == "LeftButton" and not wasMoved then
                st.selected = key; D:RefreshInspector(); D:RefreshPreview()
            end
        end)
    end
    BindClickPart(pf.health, "health")
    BindClickPart(pf.cast, "cast")
    BindClickPart(pf.debuffRow, "debuffs")
    BindClickPart(pf.buffRow, "buffs")
    BindClickPart(pf.ccRow, "cc")

    -- Botão inferior de recarga rápida
    local applyBtn = UI.Button(designerPane, "Aplicar nas Placas", 150, 26, function()
        NP.RefreshAll(); Azaath:Print("Placas atualizadas.")
    end)
    applyBtn:SetPoint("BOTTOMLEFT", 0, 2)
end

function D:RefreshChips()
    if not win then return end
    for k, b in pairs(win.chips) do
        local on = st.preview[k]
        b:SetBackdropBorderColor(NP.RGBA(on and C.accent or C.border))
        b.label:SetTextColor(NP.RGBA(on and C.accent or C.muted))
    end
end

function D:RefreshPreview()
    if not (win and win:IsShown()) then return end
    NP.previewProfile = NP.UnitProfile(EffectiveUnit())
    st.preview.selected = st.selected
    st.preview.ooc = (st.look == "ooc")
    NP.PreviewFrame(win.previewFrame, EffectiveUnit(), st.preview)
    NP.previewProfile = nil
end

function D:RefreshInspectorValues()
    if not (win and win.inspWidgets) then return end
    for _, w in ipairs(win.inspWidgets) do
        if w.Refresh then w:Refresh() end
    end
end

function D:RefreshInspector()
    if not win then return end
    if st.search ~= "" then
        local results = {}
        local q = st.search
        local function Collect(items, prefix)
            for _, it in ipairs(items) do
                if it.t ~= "header" and it.label:lower():find(q, 1, true) then
                    local copy = NP.CopyTable(it)
                    copy.label = "[" .. prefix .. "] " .. copy.label
                    results[#results + 1] = copy
                end
            end
        end
        for _, p in ipairs(NP.Schema.PARTS) do Collect(p.schema(), p.label) end
        for _, g in ipairs(NP.Schema.GLOBAL_TABS) do Collect(g.schema(), g.label) end
        win.insp.title:SetText("Resultados da busca: \"" .. st.search .. "\"")
        win.inspWidgets = BuildRows(win.insp.scroll, results)
        win.insp.scroll:UpdateBar()
        return
    end

    local part
    for _, p in ipairs(NP.Schema.PARTS) do if p.key == st.selected then part = p; break end end
    if not part then part = NP.Schema.PARTS[1]; st.selected = part.key end
    win.insp.title:SetText(part.label)
    win.inspWidgets = BuildRows(win.insp.scroll, part.schema())
    win.insp.scroll:UpdateBar()

    for k, b in pairs(win.partBtns) do
        local on = (k == st.selected)
        b:SetBackdropBorderColor(NP.RGBA(on and C.accent or C.border))
        b.label:SetTextColor(NP.RGBA(on and C.gold or C.text))
    end
end

function D:RefreshAll()
    if not win then return end
    for k, b in pairs(win.topBtns) do
        local on = (k == st.tab)
        b:SetBackdropBorderColor(NP.RGBA(on and C.accent or C.border))
        b.label:SetTextColor(NP.RGBA(on and C.gold or C.text))
    end
    for k, b in pairs(win.unitBtns) do
        local on = (k == st.unit)
        b:SetBackdropBorderColor(NP.RGBA(on and C.accent or C.border))
        b.label:SetTextColor(NP.RGBA(on and C.gold or C.text))
    end
    if win.styleBtns and NP.db and NP.db.style then
        local curStyle = NP.db.style.barStyle or "modern"
        for k, b in pairs(win.styleBtns) do
            local on = (k == curStyle)
            b:SetBackdropBorderColor(NP.RGBA(on and C.accent or C.border))
            b.label:SetTextColor(NP.RGBA(on and C.gold or C.text))
        end
    end
    if win.oocBtn then
        local canOOC = (st.unit == "enemynpc" or st.unit == "enemyplayer")
        local oocOn = canOOC and (st.look == "ooc")
        win.oocBtn:SetShown(canOOC)
        win.oocBtn:SetBackdropBorderColor(NP.RGBA(oocOn and C.accent or C.border))
        win.oocBtn.label:SetTextColor(NP.RGBA(oocOn and C.gold or C.muted))
    end

    if st.tab == "designer" then
        win.designerPane:Show(); win.fullPane:Hide()
        D:RefreshChips(); D:RefreshPreview(); D:RefreshInspector()
    else
        win.designerPane:Hide(); win.fullPane:Show()
        win.fullPane.scroll:SetShown(st.tab ~= "custom" and st.tab ~= "profiles")
        win.customView:SetShown(st.tab == "custom")
        win.profilesView:SetShown(st.tab == "profiles")
        if st.tab == "custom" then
            win.customView:Refresh()
        elseif st.tab == "profiles" then
            win.profilesView:Refresh()
        else
            for _, g in ipairs(NP.Schema.GLOBAL_TABS) do
                if g.key == st.tab then
                    BuildRows(win.fullPane.scroll, g.schema())
                    win.fullPane.scroll:UpdateBar()
                    break
                end
            end
        end
    end
end

function NP.OpenDesigner()
    if not NP.db and NP.InitDatabase then NP.InitDatabase() end
    if not win then BuildWindow() end
    if win:IsShown() then
        win:Hide()
    else
        win:Show()
        win:Raise()
        D:RefreshAll()
    end
end
