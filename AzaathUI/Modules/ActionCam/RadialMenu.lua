--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ActionCam/RadialMenu.lua
    Menu radial do Azaath: astrolábio de pedra e ouro (arte de
    tools/radial-concept/gen.js em Media/Radial).

    Uso: segure a tecla do menu radial, aponte o mouse para um espaço e solte.
    A roda do mouse troca de aba (Menu, Gestos, Consumíveis); Esc ou o botão
    direito fecham sem escolher; soltar no centro também fecha.

    Partes:
      * Abas: o que cada aba contém (ações de janela, gestos, itens do jogador).
      * Núcleo seguro: o que roda em combate (abrir, mirar, usar, trocar aba)
        vive em trechos restritos do jogo (SecureHandlerWrapScript); o Lua comum
        só prepara os atributos fora de combate.
      * Vista: o desenho, animado a cada quadro (só leitura do estado seguro).
      * Editor de consumíveis e API pública (ActionCam, mochila, painel).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local AC = Azaath.ActionCam or {}
Azaath.ActionCam = AC

local CreateFrame, GetTime, InCombatLockdown = CreateFrame, GetTime, InCombatLockdown
local ipairs, pairs, pcall, tonumber, tostring, type = ipairs, pairs, pcall, tonumber, tostring, type
local sin, cos, min, max, abs, floor, ceil, pi = math.sin, math.cos, math.min, math.max, math.abs, math.floor, math.ceil, math.pi
local TAU = 2 * pi

local ART = "Interface\\AddOns\\AzaathUI\\Media\\Radial\\"
local MAX_TABS, MAX_SLOTS = 6, 8

-- geometria (unidades da interface; a arte foi desenhada para um quadro de 480)
local VIEW = 480
local R_SLOT, R_CORE, R_NEEDLE = 159, 82, 98
local SLOT = 58
local DEAD = 52            -- raio da zona morta no centro (soltar ali = fechar)

-- ritmo das animações (segundos ou velocidade de aproximação)
local T_OPEN, T_SWAP = 0.16, 0.18
local K_FOLLOW = 18        -- quão rápido a fatia, o ponteiro e os espaços seguem a mira
local RUNE_TURN = 40       -- segundos por volta do anel de runas (animação do motor, lisa)

local GOLD = { 0.79, 0.66, 0.42 }
local CREAM = { 0.95, 0.92, 0.85 }
local DIM = { 0.60, 0.62, 0.65 }

--------------------------------------------------------------------------------
-- Abas
--------------------------------------------------------------------------------

local function Module(name) return Azaath.GetModule and Azaath:GetModule(name) end
local function On(key) return Azaath.db and Azaath.db[key] and Azaath.db[key].enabled end

-- Ações da aba Menu. `micro`: botões da barra do jogo que abrem a mesma janela por
-- clique seguro (caminho preferido quando a janela do Azaath está desligada).
-- `open`: o que fazer em Lua quando a janela do Azaath cuida disso.
local MENU = {
    { id = "character", label = "Personagem", micro = { "CharacterMicroButton" }, azaath = "sheet",
      open = function()
          local m = Module("Sheet")
          if m and m.Toggle and On("sheet") then m:Toggle() elseif ToggleCharacter then ToggleCharacter("PaperDollFrame") end
      end },
    { id = "bags", label = "Mochilas", micro = { "MainMenuBarBackpackButton" }, azaath = "inventory",
      open = function()
          local inv, sheet = Module("Inventory"), Module("Sheet")
          if inv and inv.Toggle and On("inventory") then inv:Toggle()
          elseif sheet and sheet.Toggle and On("sheet") then sheet:Toggle()
          elseif ToggleAllBags then ToggleAllBags() end
      end },
    { id = "spellbook", label = "Grimório", micro = { "PlayerSpellsMicroButton", "SpellbookMicroButton" }, azaath = "spellbook",
      open = function()
          local g, sb = Module("Grimoire"), Module("Spellbook")
          if g and g.IsActive and g:IsActive() then g:Toggle()
          elseif sb and sb.Toggle and On("spellbook") then sb:Toggle()
          elseif PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then PlayerSpellsUtil.ToggleSpellBookFrame()
          elseif ToggleSpellBook then ToggleSpellBook(BOOKTYPE_SPELL or "spell") end
      end },
    { id = "talents", label = "Talentos", micro = { "PlayerSpellsMicroButton", "TalentMicroButton" }, azaath = "talents",
      open = function()
          local t = Module("Talents")
          if t and t.Toggle and On("talents") then t:Toggle()
          elseif PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentFrame then PlayerSpellsUtil.ToggleClassTalentFrame()
          elseif ToggleTalentFrame then ToggleTalentFrame() end
      end },
    { id = "quests", label = "Missões", micro = { "QuestLogMicroButton" },
      open = function()
          if ToggleQuestLog then ToggleQuestLog() return end
          local wm = Module("WorldMap")
          if wm and wm.Toggle and On("worldmap") then wm:Toggle() elseif ToggleWorldMap then ToggleWorldMap() end
      end },
    { id = "fullmap", label = "Mapa-Múndi", micro = { "WorldMapMicroButton" }, azaath = "worldmap",
      open = function()
          local wm = Module("WorldMap")
          if wm and wm.Toggle and On("worldmap") then wm:Toggle() elseif ToggleWorldMap then ToggleWorldMap() end
      end },
    { id = "groupfinder", label = "Localizador", micro = { "LFDMicroButton", "LFGMicroButton" },
      open = function()
          if PVEFrame_ToggleFrame then PVEFrame_ToggleFrame() elseif ToggleLFDParentFrame then ToggleLFDParentFrame() end
      end },
    { id = "gamemenu", label = "Menu do Jogo", micro = { "MainMenuMicroButton" },
      open = function()
          local gm = GameMenuFrame
          if gm then
              if gm:IsShown() then Azaath.HidePanel(gm) else Azaath.ShowPanel(gm) end
          end
      end },
}

-- clique seguro num botão da barra do jogo, quando a janela do Azaath não cuida da ação
local function MicroClick(act)
    if act.azaath and On(act.azaath) then return nil end
    if act.id == "bags" and On("sheet") then return nil end
    if act.id == "spellbook" then
        local g = Module("Grimoire")
        if g and g.IsActive and g:IsActive() then return nil end
    end
    for _, name in ipairs(act.micro or {}) do
        local b = _G[name]
        if b and b.Click then return "/click " .. name end
    end
end

local GESTURES = {
    { label = "Acenar", word = "OI", slash = "wave" }, { label = "Agradecer", word = "OBG", slash = "thank" },
    { label = "Despedir", word = "TCHAU", slash = "bye" }, { label = "Torcer", word = "VIVA", slash = "cheer" },
    { label = "Sentar", word = "SENTAR", slash = "sit" }, { label = "Dançar", word = "DANÇA", slash = "dance" },
    { label = "Rir", word = "RIR", slash = "laugh" }, { label = "Reverência", word = "CURVAR", slash = "bow" },
}

local TAB_COLOR = {
    { 0.96, 0.78, 0.38 }, -- Menu: âmbar
    { 0.37, 0.84, 0.82 }, -- Gestos: turquesa
    { 0.50, 0.85, 0.54 }, -- Consumíveis: verde
    { 0.72, 0.56, 0.98 }, -- Habilidades: violeta
}

local HEARTHSTONE = 6948

local function ItemInfo(id)
    if not id then return end
    local name, quality, icon
    if C_Item and C_Item.GetItemInfo then
        local n, _, q, _, _, _, _, _, _, ic = C_Item.GetItemInfo(id)
        name, quality, icon = n, q, ic
    elseif GetItemInfo then
        local n, _, q, _, _, _, _, _, _, ic = GetItemInfo(id)
        name, quality, icon = n, q, ic
    end
    if not icon and C_Item and C_Item.GetItemIconByID then icon = C_Item.GetItemIconByID(id) end
    return name, icon, quality
end

local function ItemCount(id)
    if not id then return 0 end
    local fn = (C_Item and C_Item.GetItemCount) or GetItemCount
    local ok, n = pcall(fn, id, false, true)
    return ok and type(n) == "number" and n or 0
end

local function ItemCooldown(id)
    local fn = (C_Item and C_Item.GetItemCooldown) or GetItemCooldown
    if not fn then return 0, 0 end
    local ok, s, d = pcall(fn, id)
    if not ok then return 0, 0 end
    return s, d
end

local function SpellInfo(id)
    if not id then return end
    local CS = C_Spell
    if CS and CS.GetSpellInfo then
        local ok, info = pcall(CS.GetSpellInfo, id)
        if ok and type(info) == "table" then return info.name, info.iconID end
    end
    if GetSpellInfo then
        local ok, name, _, icon = pcall(GetSpellInfo, id)
        if ok then return name, icon end
    end
end

local function SpellCooldown(id)
    local CS = C_Spell
    if CS and CS.GetSpellCooldown then
        local ok, info = pcall(CS.GetSpellCooldown, id)
        if ok and type(info) == "table" then return info.startTime, info.duration end
    elseif GetSpellCooldown then
        local ok, st, du = pcall(GetSpellCooldown, id)
        if ok then return st, du end
    end
    return 0, 0
end

-- lista salva: "items" (radialConsumables) ou "spells" (radialSpells)
local function SavedList(mode)
    local db = AC.DB()
    if not db then return {} end
    if mode == "spells" then
        if type(db.radialSpells) ~= "table" then db.radialSpells = {} end
        return db.radialSpells
    end
    if type(db.radialConsumables) ~= "table" then db.radialConsumables = { HEARTHSTONE } end
    return db.radialConsumables
end

local function Saved()
    local db = AC.DB()
    if not db then return {} end
    if type(db.radialConsumables) ~= "table" then db.radialConsumables = { HEARTHSTONE } end
    return db.radialConsumables
end

-- monta as abas: { name, color, slots = { { kind, label, ... } } }
local function BuildTabs()
    local tabs = {}
    local menu = {}
    for _, act in ipairs(MENU) do
        menu[#menu + 1] = { kind = "menu", id = act.id, label = act.label, glyph = ART .. "Icon_" .. act.id,
            macro = MicroClick(act), open = act.open }
    end
    tabs[1] = { name = "Menu", color = TAB_COLOR[1], slots = menu }

    local gest = {}
    for _, g in ipairs(GESTURES) do
        gest[#gest + 1] = { kind = "emote", id = g.slash, label = g.label, word = g.word, macro = "/" .. g.slash }
    end
    tabs[2] = { name = "Gestos", color = TAB_COLOR[2], slots = gest }

    local items = {}
    local saved = Saved()
    for i = 1, MAX_SLOTS do
        local id = tonumber(saved[i])
        if id and id > 0 then
            local name, icon, q = ItemInfo(id)
            items[#items + 1] = { kind = "item", id = id, label = name or ("Item #" .. id), icon = icon or 134400, quality = q }
        end
    end
    if #items == 0 then
        local name, icon, q = ItemInfo(HEARTHSTONE)
        items[1] = { kind = "item", id = HEARTHSTONE, label = name or "Pedra de Regresso", icon = icon or 134400, quality = q }
    end
    tabs[3] = { name = "Consumíveis", color = TAB_COLOR[3], slots = items }

    local spells = {}
    local ss = SavedList("spells")
    for i = 1, MAX_SLOTS do
        local id = tonumber(ss[i])
        if id and id > 0 then
            local name, icon = SpellInfo(id)
            spells[#spells + 1] = { kind = "spell", id = id, label = name or ("Feitiço #" .. id), icon = icon or 134400 }
        end
    end
    tabs[4] = { name = "Habilidades", color = TAB_COLOR[4], slots = spells }
    return tabs
end

--------------------------------------------------------------------------------
-- Núcleo seguro
--------------------------------------------------------------------------------
-- Atributos do quadro seguro `Wheel`:
--   tabs (total), tab (atual), count (espaços da aba atual), dead (zona morta)
--   n<t>            espaços da aba t
--   k<t>_<i>, v<t>_<i>  tipo e valor da ação do espaço i da aba t
--   dx<n>_<i>, dy<n>_<i> direção do espaço i quando a roda tem n espaços

local Wheel, Trigger, Pager
local Buttons = {}
local tabs = {}
local storePending = false
local bindOwner = CreateFrame("Frame", "AzaathUIRadialBindingOwner", UIParent)

local function Direction(i, n)
    local a = TAU * (i - 1) / n
    return sin(a), cos(a), a
end

-- trecho restrito: copia as ações da aba atual para os botões
local LOAD_TAB = [=[
    local t = owner:GetAttribute("tab") or 1
    local n = owner:GetAttribute("n" .. t) or 0
    owner:SetAttribute("count", n)
    for i = 1, 8 do
        local b = owner:GetFrameRef("b" .. i)
        local k, v
        if i <= n then
            k = owner:GetAttribute("k" .. t .. "_" .. i)
            v = owner:GetAttribute("v" .. t .. "_" .. i)
        end
        b:SetAttribute("type", k == "macrotext" and "macro" or k)
        b:SetAttribute("spell", k == "spell" and v or nil)
        b:SetAttribute("item", k == "item" and v or nil)
        b:SetAttribute("macro", k == "macro" and v or nil)
        b:SetAttribute("macrotext", k == "macrotext" and v or nil)
    end
]=]

local CLOSE = [=[
    owner:Hide()
    owner:ClearBindings()
]=]

-- trecho restrito: qual espaço está na direção do mouse (0 = centro)
local PICK = [=[
    local pick = 0
    local n = owner:GetAttribute("count") or 0
    local mx, my = owner:GetMousePosition()
    if n > 0 and mx then
        local x = (mx - 0.5) * owner:GetWidth()
        local y = (my - 0.5) * owner:GetHeight()
        local dead = owner:GetAttribute("dead") or 50
        if x * x + y * y > dead * dead then
            local best
            for i = 1, n do
                local d = x * owner:GetAttribute("dx" .. n .. "_" .. i) + y * owner:GetAttribute("dy" .. n .. "_" .. i)
                if not best or d > best then best, pick = d, i end
            end
        end
    end
]=]

-- tecla do menu: apertar abre, soltar usa o espaço mirado
local ON_TRIGGER = [=[
    local owner = owner or self
    if button == "ESC" then
        if owner:IsShown() then ]=] .. CLOSE .. [=[ end
        return false
    end
    if down then
        self:SetAttribute("useOnKeyDown", true)
        if (owner:GetAttribute("tabs") or 0) < 1 then return false end
        owner:ClearAllPoints()
        owner:SetPoint("CENTER", "$parent", "CENTER", 0, 0)
        ]=] .. LOAD_TAB .. [=[
        owner:Show()
        owner:SetBindingClick(true, "MOUSEWHEELUP", "AzaathUIRadialPage", "UP")
        owner:SetBindingClick(true, "MOUSEWHEELDOWN", "AzaathUIRadialPage", "DOWN")
        owner:SetBindingClick(true, "ESCAPE", "AzaathUIRadialKey", "ESC")
        owner:SetBindingClick(true, "BUTTON2", "AzaathUIRadialKey", "ESC")
        owner:CallMethod("OnRadialState")
        return false
    end
    if not owner:IsShown() then return false end
    ]=] .. PICK .. [=[
    if pick < 1 then ]=] .. CLOSE .. [=[ return false end
    self:SetAttribute("useOnKeyDown", false)
    return "slot" .. pick, true
]=]

-- roda do mouse: aba anterior / seguinte (uma vez por giro)
local ON_PAGE = [=[
    local owner = owner or self
    if not owner:IsShown() then return false end
    if down then
        self:SetAttribute("held", true)
    elseif self:GetAttribute("held") then
        self:SetAttribute("held", nil)
        return false
    end
    local total = owner:GetAttribute("tabs") or 0
    if total < 2 then return false end
    local t = (owner:GetAttribute("tab") or 1) + (button == "UP" and -1 or 1)
    if t < 1 then t = total elseif t > total then t = 1 end
    owner:SetAttribute("tab", t)
    ]=] .. LOAD_TAB .. [=[
    owner:CallMethod("OnRadialState")
    return false
]=]

local View -- definida na seção Vista

local function Sound(kind)
    local db = AC.DB()
    if db and db.soundRadialMenu == false then return end
    local K = SOUNDKIT or {}
    local id = ({
        open = K.IG_MINIMAP_OPEN or 891, close = K.IG_MINIMAP_CLOSE or 892, aim = K.U_CHAT_SCROLL_BUTTON or 1115,
        page = K.IG_CHARACTER_INFO_TAB or 841, use = K.IG_MAINMENU_OPTION_CHECKBOX_ON or 856,
    })[kind]
    if id and PlaySound then pcall(PlaySound, id, "SFX") end
end

local function BuildSecure()
    if Wheel then return end
    Wheel = CreateFrame("Frame", "AzaathUIRadialWheel", UIParent, "SecureHandlerBaseTemplate")
    Wheel:SetSize(VIEW, VIEW)
    Wheel:SetPoint("CENTER")
    Wheel:SetFrameStrata("DIALOG")
    Wheel:EnableMouse(false)
    Wheel:Hide()
    Wheel:SetAttribute("tab", 1)
    Wheel:SetAttribute("tabs", 0)
    Wheel:SetAttribute("dead", DEAD)
    for n = 1, MAX_SLOTS do
        for i = 1, n do
            local x, y = Direction(i, n)
            Wheel:SetAttribute("dx" .. n .. "_" .. i, x)
            Wheel:SetAttribute("dy" .. n .. "_" .. i, y)
        end
    end

    Trigger = CreateFrame("Button", "AzaathUIRadialKey", UIParent, "SecureActionButtonTemplate")
    Trigger:RegisterForClicks("AnyDown", "AnyUp")
    Trigger:SetAttribute("useOnKeyDown", true)
    Trigger:SetAttribute("type", "click")
    Trigger:Hide()

    Pager = CreateFrame("Button", "AzaathUIRadialPage", UIParent, "SecureActionButtonTemplate")
    Pager:RegisterForClicks("AnyDown", "AnyUp")
    Pager:Hide()

    for i = 1, MAX_SLOTS do
        local b = CreateFrame("Button", "AzaathUIRadialSlot" .. i, Wheel, "SecureActionButtonTemplate")
        b:SetSize(1, 1)
        b:SetPoint("CENTER")
        b:RegisterForClicks("AnyUp")
        b:EnableMouse(false)
        b:SetAttribute("useOnKeyDown", false)
        b:SetAttribute("checkselfcast", false)
        b:SetAttribute("checkfocuscast", false)
        b:SetAttribute("checkmouseovercast", false)
        SecureHandlerWrapScript(b, "OnClick", Wheel, "return nil, true", CLOSE)
        SecureHandlerSetFrameRef(Wheel, "b" .. i, b)
        Trigger:SetAttribute("*clickbutton-slot" .. i, b)
        -- depois do clique seguro: som e, para janelas do Azaath, a abertura em Lua
        b:HookScript("PostClick", function()
            local t = tabs[Wheel:GetAttribute("tab") or 1]
            local s = t and t.slots[i]
            Sound("use")
            if s and s.kind == "menu" and not s.macro and s.open then pcall(s.open) end
        end)
        Buttons[i] = b
    end

    SecureHandlerWrapScript(Trigger, "OnClick", Wheel, ON_TRIGGER)
    SecureHandlerWrapScript(Pager, "OnClick", Wheel, ON_PAGE)
end

-- grava as abas nos atributos seguros (só fora de combate)
local function Store()
    if InCombatLockdown() then storePending = true return end
    BuildSecure()
    tabs = BuildTabs()
    local total = min(#tabs, MAX_TABS)
    Wheel:SetAttribute("tabs", total)
    if (Wheel:GetAttribute("tab") or 1) > total then Wheel:SetAttribute("tab", 1) end
    for t = 1, total do
        local list = tabs[t].slots
        local n = min(#list, MAX_SLOTS)
        Wheel:SetAttribute("n" .. t, n)
        for i = 1, MAX_SLOTS do
            local s = i <= n and list[i]
            local k, v
            if s then
                if s.kind == "item" then k, v = "item", "item:" .. s.id
                elseif s.macro then k, v = "macrotext", s.macro
                elseif s.kind == "spell" then k, v = "spell", s.id end
            end
            Wheel:SetAttribute("k" .. t .. "_" .. i, k)
            Wheel:SetAttribute("v" .. t .. "_" .. i, v)
        end
    end
end

-- espaço mirado agora (para o desenho; o seguro decide por conta própria ao soltar)
local function Aim()
    if not (Wheel and Wheel:IsShown()) then return 0 end
    local t = tabs[Wheel:GetAttribute("tab") or 1]
    local n = t and min(#t.slots, MAX_SLOTS) or 0
    if n < 1 then return 0 end
    local cx, cy = Wheel:GetCenter()
    if not cx then return 0 end
    local k = Wheel:GetEffectiveScale() or 1
    local mx, my = GetCursorPosition()
    local x, y = mx / k - cx, my / k - cy
    if x * x + y * y <= DEAD * DEAD then return 0 end
    local best, pick
    for i = 1, n do
        local dx, dy = Direction(i, n)
        local d = x * dx + y * dy
        if not best or d > best then best, pick = d, i end
    end
    return pick
end

--------------------------------------------------------------------------------
-- Vista
--------------------------------------------------------------------------------

local function Tex(parent, layer, file, sub, blend)
    local t = parent:CreateTexture(nil, layer, nil, sub or 0)
    t:SetTexture(ART .. file)
    if blend then t:SetBlendMode(blend) end
    if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false); t:SetTexelSnappingBias(0) end
    return t
end

local function Font(fs, file, size, flags)
    fs:SetFont(file or STANDARD_TEXT_FONT, size, flags or "")
    if not fs:GetFont() then fs:SetFont(STANDARD_TEXT_FONT, size, flags or "") end
end

local function Spaced(text)
    return Azaath.Tracked and Azaath.Tracked(text) or text
end

local function Mix(a, b, k) return a + (b - a) * k end
local function Ease(t) local u = 1 - t return 1 - u * u * u end

local V = {
    open = 1, swap = 1, swapEase = 1, tab = nil, n = 0, aim = -1, lastAimSound = 0,
    wedgeAngle = nil, wedgeAlpha = 0, needleAngle = nil, closeMix = 0, runes = 0,
}

local function CircleMask(frame, tex)
    local ok, mask = pcall(frame.CreateMaskTexture, frame)
    if not ok or not mask then return end
    if not (mask.SetAtlas and pcall(mask.SetAtlas, mask, "CircleMaskScalable", false)) then
        mask:SetTexture(Azaath.media.path .. "Inventory\\RoundMask.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    mask:SetAllPoints(tex)
    tex:AddMaskTexture(mask)
end

local function MakeSlot(parent)
    local s = CreateFrame("Frame", nil, parent)
    s:SetSize(SLOT, SLOT)
    s.halo = Tex(s, "BACKGROUND", "Halo", 0, "ADD")
    s.halo:SetSize(SLOT * 2.1, SLOT * 2.1)
    s.halo:SetPoint("CENTER")
    s.halo:SetAlpha(0)
    s.back = Tex(s, "BORDER", "SlotBack")
    s.back:SetAllPoints()
    s.icon = s:CreateTexture(nil, "ARTWORK")
    s.icon:SetPoint("TOPLEFT", SLOT * 0.09, -SLOT * 0.09)
    s.icon:SetPoint("BOTTOMRIGHT", -SLOT * 0.09, SLOT * 0.09)
    s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    CircleMask(s, s.icon)
    s.glyph = s:CreateTexture(nil, "ARTWORK", nil, 1)
    s.glyph:SetPoint("CENTER")
    s.glyph:SetSize(SLOT * 0.64, SLOT * 0.64)
    s.cd = CreateFrame("Cooldown", nil, s, "CooldownFrameTemplate")
    s.cd:SetAllPoints(s.icon)
    s.cd:SetDrawEdge(false)
    s.cd:SetDrawBling(false)
    s.cd:SetHideCountdownNumbers(false)
    if s.cd.SetSwipeTexture then
        local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo("CircleMaskScalable")
        s.cd:SetSwipeTexture(info and info.file or (Azaath.media.path .. "Inventory\\RoundMask.tga"))
    end
    local top = CreateFrame("Frame", nil, s)
    top:SetAllPoints()
    top:SetFrameLevel(s.cd:GetFrameLevel() + 2)
    s.rim = Tex(top, "OVERLAY", "SlotRim")
    s.rim:SetPoint("CENTER")
    s.rim:SetSize(SLOT * 1.1, SLOT * 1.1)
    s.word = top:CreateFontString(nil, "OVERLAY")
    Font(s.word, Azaath.media.fontTitleB, 11)
    s.word:SetPoint("CENTER", 0, -1)
    s.word:SetShadowOffset(1, -1)
    s.count = top:CreateFontString(nil, "OVERLAY")
    Font(s.count, Azaath.media.fontBold, 12, "OUTLINE")
    s.count:SetPoint("BOTTOMRIGHT", -2, 3)
    s.scale, s.goal, s.x, s.y = 1, 1, 0, 0
    return s
end

local function PlaceSlot(s)
    local k = s.scale * (0.86 + 0.14 * V.swapEase)
    s:SetScale(k)
    s:ClearAllPoints()
    s:SetPoint("CENTER", View.frame, "CENTER", s.x / k, s.y / k)
end

local function BuildView()
    if View or not Wheel then return end
    View = {}
    local f = CreateFrame("Frame", "AzaathUIRadialView", Wheel)
    View.frame = f
    f:SetSize(VIEW, VIEW)
    f:SetPoint("CENTER")
    f:SetFrameLevel(Wheel:GetFrameLevel() + 1)

    View.base = Tex(f, "BACKGROUND", "Base")
    View.base:SetSize(VIEW, VIEW)
    View.base:SetPoint("CENTER")
    View.rings = Tex(f, "BACKGROUND", "Rings") -- sem fundo: só os aros de ouro
    View.rings:SetSize(VIEW, VIEW)
    View.rings:SetPoint("CENTER")
    View.rings:Hide()
    View.runes = Tex(f, "BACKGROUND", "RuneBand", 1)
    View.runes:SetSize(VIEW, VIEW)
    View.runes:SetPoint("CENTER")
    -- giro pelo motor (AnimationGroup): o SetRotation por quadro no Lua engasgava
    do
        local ag = View.runes:CreateAnimationGroup()
        local r = ag:CreateAnimation("Rotation")
        r:SetDegrees(-360)
        r:SetDuration(RUNE_TURN)
        ag:SetLooping("REPEAT")
        ag:Play()
        f:HookScript("OnShow", function() if not ag:IsPlaying() then ag:Play() end end)
    end
    View.wedge = Tex(f, "BORDER", "Wedge8", 0, "ADD")
    View.wedge:SetSize(VIEW, VIEW)
    View.wedge:SetPoint("CENTER")
    View.wedge:SetAlpha(0)
    View.dividers = {}
    for i = 1, MAX_SLOTS do
        local d = Tex(f, "BORDER", "Divider", 1)
        d:SetSize(16, 96)
        d:Hide()
        View.dividers[i] = d
    end
    View.slots = {}
    for i = 1, MAX_SLOTS do
        View.slots[i] = MakeSlot(f)
        View.slots[i]:Hide()
    end

    local center = CreateFrame("Frame", nil, f)
    center:SetAllPoints()
    center:SetFrameLevel(f:GetFrameLevel() + 20)
    View.core = Tex(center, "BACKGROUND", "Core")
    View.core:SetSize(176, 176)
    View.core:SetPoint("CENTER")
    View.needle = Tex(center, "ARTWORK", "Needle")
    View.needle:SetSize(30, 30)
    View.close = Tex(center, "ARTWORK", "Close", 1)
    View.close:SetSize(44, 44)
    View.close:SetPoint("CENTER", 0, 4)
    View.close:SetAlpha(0)

    View.title = center:CreateFontString(nil, "OVERLAY")
    Font(View.title, Azaath.media.fontCinzel or Azaath.media.fontTitleB, 10)
    View.title:SetPoint("CENTER", 0, 26)
    View.name = center:CreateFontString(nil, "OVERLAY")
    Font(View.name, Azaath.media.fontTitleB, 16)
    View.name:SetPoint("CENTER", 0, -2)
    View.name:SetWidth(150)
    View.name:SetWordWrap(false)
    View.name:SetShadowOffset(0, -1)
    View.line = center:CreateTexture(nil, "ARTWORK")
    View.line:SetTexture(Azaath.media.blank)
    View.line:SetSize(80, 1)
    View.line:SetPoint("CENTER", 0, -15)
    View.line:SetVertexColor(GOLD[1], GOLD[2], GOLD[3], 0.55)
    View.hint = center:CreateFontString(nil, "OVERLAY")
    Font(View.hint, Azaath.media.font, 10)
    View.hint:SetPoint("CENTER", 0, -30)
    View.hint:SetTextColor(DIM[1], DIM[2], DIM[3])

    View.tabs = {}
    for i = 1, MAX_TABS do
        local gem = Tex(f, "ARTWORK", "TabGem")
        gem:SetSize(22, 22)
        local label = f:CreateFontString(nil, "OVERLAY")
        Font(label, Azaath.media.fontTitleB, 11)
        View.tabs[i] = { gem = gem, label = label }
    end

    Wheel.OnRadialState = function() if View.Paint then View.Paint() end end
end

-- algo atrapalha o uso agora? (sem o item, em recarga, inutilizável)
local function Unusable(s)
    if not s then return false end
    if s.kind == "spell" then
        local st, du = SpellCooldown(s.id)
        if type(st) == "number" and type(du) == "number" and not Azaath.IsSecret(st) and not Azaath.IsSecret(du)
            and st > 0 and du > 1.5 and st + du > GetTime() then
            return true
        end
        if C_Spell and C_Spell.IsSpellUsable then
            local ok, usable = pcall(C_Spell.IsSpellUsable, s.id)
            if ok and usable == false and not Azaath.IsSecret(usable) then return true end
        end
        return false
    end
    if s.kind ~= "item" then return false end
    if ItemCount(s.id) < 1 then return true end
    local st, du = ItemCooldown(s.id)
    if type(st) == "number" and type(du) == "number" and not Azaath.IsSecret(st) and not Azaath.IsSecret(du)
        and st > 0 and du > 1.5 and st + du > GetTime() then
        return true
    end
    if C_Item and C_Item.IsUsableItem then
        local ok, usable = pcall(C_Item.IsUsableItem, s.id)
        if ok and usable == false and not Azaath.IsSecret(usable) then return true end
    end
    return false
end

local function Tabs(current, total)
    local width = 150
    local x0 = -width * (total - 1) / 2
    for i, t in ipairs(View.tabs) do
        local tab = tabs[i]
        if tab and i <= total and total > 1 then
            local on = i == current
            local c = on and tab.color or DIM
            t.gem:ClearAllPoints()
            t.gem:SetPoint("CENTER", View.frame, "BOTTOM", x0 + (i - 1) * width, -6)
            t.gem:SetVertexColor(c[1], c[2], c[3], on and 1 or 0.6)
            t.gem:SetSize(on and 24 or 18, on and 24 or 18)
            t.label:ClearAllPoints()
            t.label:SetPoint("TOP", t.gem, "BOTTOM", 0, -4)
            t.label:SetText(Spaced(tab.name:upper()))
            t.label:SetTextColor(c[1], c[2], c[3], on and 1 or 0.7)
            t.gem:Show(); t.label:Show()
        else
            t.gem:Hide(); t.label:Hide()
        end
    end
end

-- desenha a aba atual (ao abrir, ao trocar de aba, quando bolsas/recargas mudam)
local function Paint()
    if not (View and Wheel and Wheel:IsShown()) then return end
    local cur = Wheel:GetAttribute("tab") or 1
    local tab = tabs[cur]
    local list = tab and tab.slots or {}
    local n = min(#list, MAX_SLOTS)
    local col = tab and tab.color or TAB_COLOR[1]
    V.n, V.color = n, col

    if V.tab and V.tab ~= cur then
        Sound("page")
        V.swap = 0
    end
    V.tab = cur

    -- fundo de pedra ou transparente (só os aros), conforme o ajuste
    local db = AC.DB()
    local solid = not (db and db.radialBackdrop == false)
    View.base:SetShown(solid)
    View.rings:SetShown(not solid)

    View.wedge:SetTexture(ART .. "Wedge" .. max(2, min(n, 8)))
    View.wedge:SetVertexColor(col[1], col[2], col[3])
    View.title:SetText(Spaced((tab and tab.name or ""):upper()))
    View.title:SetTextColor(col[1], col[2], col[3])
    View.needle:SetVertexColor(1, 1, 1)
    Tabs(cur, min(#tabs, MAX_TABS))

    for i = 1, MAX_SLOTS do
        local d = View.dividers[i]
        if n > 1 and i <= n then
            local a = TAU * (i - 1) / n + pi / n
            local r = 154
            d:ClearAllPoints()
            d:SetPoint("CENTER", View.frame, "CENTER", sin(a) * r, cos(a) * r)
            d:SetRotation(-a)
            d:Show()
        else
            d:Hide()
        end
    end

    for i = 1, MAX_SLOTS do
        local s, e = View.slots[i], list[i]
        if e and i <= n then
            local dx, dy = Direction(i, n)
            s.x, s.y = dx * R_SLOT, dy * R_SLOT
            s.icon:Hide(); s.glyph:Hide(); s.word:SetText(""); s.count:SetText(""); s.cd:Clear()
            if e.kind == "menu" then
                s.glyph:SetTexture(e.glyph)
                s.glyph:Show()
            elseif e.kind == "emote" then
                s.word:SetText(e.word or e.label)
                s.word:SetTextColor(0.96, 0.87, 0.65)
            elseif e.kind == "spell" then
                local _, icon = SpellInfo(e.id)
                s.icon:SetTexture(icon or e.icon or 134400)
                s.icon:Show()
                local st, du = SpellCooldown(e.id)
                if type(st) == "number" and type(du) == "number" and not Azaath.IsSecret(st) and not Azaath.IsSecret(du) then
                    s.cd:SetCooldown(st, du)
                end
            else
                local _, icon = ItemInfo(e.id)
                s.icon:SetTexture(icon or e.icon or 134400)
                s.icon:Show()
                local count = ItemCount(e.id)
                s.count:SetText(count)
                s.count:SetTextColor(count > 0 and 1 or 0.95, count > 0 and 1 or 0.35, count > 0 and 1 or 0.3)
                local st, du = ItemCooldown(e.id)
                if type(st) == "number" and type(du) == "number" and not Azaath.IsSecret(st) and not Azaath.IsSecret(du) then
                    s.cd:SetCooldown(st, du)
                end
            end
            local bad = Unusable(e)
            s.icon:SetDesaturated(bad)
            s.icon:SetAlpha(bad and 0.6 or 1)
            s.halo:SetVertexColor(col[1], col[2], col[3])
            s:Show()
        else
            s:Hide()
        end
    end
    V.aim = -1 -- força o realce a se refazer
end

-- realce da mira (chamado quando o espaço mirado muda)
local function Highlight(aim)
    local first = V.aim == -1
    if not first and aim ~= V.aim and aim > 0 then
        local now = GetTime()
        if now - V.lastAimSound > 0.05 then V.lastAimSound = now; Sound("aim") end
    end
    V.aim = aim
    local tab = tabs[Wheel:GetAttribute("tab") or 1]
    local e = tab and tab.slots[aim]
    if aim > 0 and e then
        View.name:SetText(e.label)
        local q = e.quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[e.quality]
        if q and e.quality > 1 then View.name:SetTextColor(q.r, q.g, q.b) else View.name:SetTextColor(1, 1, 1) end
        View.hint:SetText((e.kind == "item" or e.kind == "spell") and Unusable(e) and "indisponível agora" or "solte para usar")
        local _, _, a = Direction(aim, V.n)
        V.goalAngle = a
        if not V.wedgeAngle then V.wedgeAngle, V.needleAngle = a, a end
    else
        local empty = V.n == 0
        View.name:SetText(empty and "Aba vazia" or "")
        View.hint:SetText(empty and "vincule em /azaath > Câmera" or (#tabs > 1 and "roda do mouse: trocar aba" or ""))
    end
    for i = 1, V.n do
        local s = View.slots[i]
        s.goal = (i == aim) and 1.14 or 1
        if first then s.scale = s.goal end
    end
end

local function Animate(_, dt)
    if not Wheel:IsShown() then return end
    if dt > 0.1 then dt = 0.1 end
    local f = View.frame

    if V.open < 1 then
        V.open = min(1, V.open + dt / T_OPEN)
        local e = Ease(V.open)
        f:SetAlpha(e)
        f:SetScale(0.9 + 0.1 * e)
    end
    if V.swap < 1 then V.swap = min(1, V.swap + dt / T_SWAP) end
    V.swapEase = Ease(V.swap)

    local aim = Aim()
    if aim ~= V.aim then Highlight(aim) end

    -- anel de runas girando devagar

    local k = min(1, dt * K_FOLLOW)
    -- fatia acesa e ponteiro seguem a mira pelo caminho mais curto
    local want = aim > 0 and 1 or 0
    V.wedgeAlpha = Mix(V.wedgeAlpha, want, k)
    if V.goalAngle and V.wedgeAngle then
        local diff = (V.goalAngle - V.wedgeAngle + pi) % TAU - pi
        V.wedgeAngle = V.wedgeAngle + diff * k
        local nd = (V.goalAngle - V.needleAngle + pi) % TAU - pi
        V.needleAngle = V.needleAngle + nd * min(1, k * 1.4)
    end
    if V.wedgeAngle then View.wedge:SetRotation(-V.wedgeAngle) end
    View.wedge:SetAlpha(V.wedgeAlpha * (0.85 + 0.1 * sin(GetTime() * 3)))
    if V.needleAngle then
        View.needle:ClearAllPoints()
        View.needle:SetPoint("CENTER", f, "CENTER", sin(V.needleAngle) * R_NEEDLE, cos(V.needleAngle) * R_NEEDLE)
        View.needle:SetRotation(-V.needleAngle)
    end
    View.needle:SetAlpha(V.wedgeAlpha)

    -- centro: nome do mirado, ou o "fechar" na zona morta
    V.closeMix = Mix(V.closeMix, (aim > 0 or V.n == 0) and 0 or 1, k)
    View.close:SetAlpha(V.closeMix)
    View.name:SetAlpha(1 - V.closeMix)
    View.line:SetAlpha(0.55 * (1 - V.closeMix))
    View.title:SetAlpha(V.swapEase)

    for i = 1, V.n do
        local s = View.slots[i]
        if abs(s.scale - s.goal) > 0.001 then s.scale = Mix(s.scale, s.goal, k) end
        local lit = (s.goal > 1) and 1 or 0
        s.halo:SetAlpha(Mix(s.halo:GetAlpha(), lit * 0.8, k))
        s.rim:SetVertexColor(1, 1, 1)
        if lit == 1 then s.rim:SetVertexColor(1.0, 0.96, 0.85) else s.rim:SetVertexColor(0.85, 0.82, 0.76) end
        s:SetAlpha(V.swapEase)
        PlaceSlot(s)
    end
end

local function HookView()
    View.Paint = Paint
    View.frame:SetScript("OnUpdate", Animate)
    Wheel:SetScript("OnShow", function()
        V.open, V.swap, V.swapEase, V.tab, V.aim = 0, 1, 1, nil, -1
        V.wedgeAngle, V.needleAngle, V.goalAngle, V.wedgeAlpha, V.closeMix = nil, nil, nil, 0, 1
        Sound("open")
        Paint()
        if AC.ReconcileFreeLook then AC.ReconcileFreeLook() end
    end)
    Wheel:SetScript("OnHide", function()
        Sound("close")
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function() if AC.ReconcileFreeLook then AC.ReconcileFreeLook() end end)
        elseif AC.ReconcileFreeLook then
            AC.ReconcileFreeLook()
        end
    end)
end

--------------------------------------------------------------------------------
-- Editor (oito espaços das abas Consumíveis e Habilidades)
--------------------------------------------------------------------------------

local editor
local changeListeners = {}

local function Changed()
    Store()
    Paint()
    if editor and editor:IsShown() and editor.Refresh then editor.Refresh() end
    for _, fn in ipairs(changeListeners) do pcall(fn) end
end

local function SetSlotIn(mode, i, id)
    SavedList(mode)[i] = id
    Changed()
end

local function SetSlot(i, id) SetSlotIn("items", i, id) end

-- consumíveis nas mochilas (um por item), em ordem alfabética
local function BagConsumables()
    local seen, out = {}, {}
    local CC = C_Container
    for bag = 0, 4 do
        local n = (CC and CC.GetContainerNumSlots and CC.GetContainerNumSlots(bag)) or (GetContainerNumSlots and GetContainerNumSlots(bag)) or 0
        for slot = 1, n do
            local id = (CC and CC.GetContainerItemID and CC.GetContainerItemID(bag, slot)) or (GetContainerItemID and GetContainerItemID(bag, slot))
            if id and not seen[id] then
                seen[id] = true
                local info = { (C_Item and C_Item.GetItemInfo and C_Item.GetItemInfo(id)) }
                if not info[1] and GetItemInfo then info = { GetItemInfo(id) } end
                local name, class, icon = info[1], info[12], info[10]
                local useful = class == 0 or id == HEARTHSTONE or (C_Item and C_Item.GetItemSpell and C_Item.GetItemSpell(id))
                if useful then
                    out[#out + 1] = { id = id, name = name or ("Item #" .. id),
                        icon = icon or (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)) or 134400,
                        extra = "x" .. ItemCount(id) }
                end
            end
        end
    end
    table.sort(out, function(a, b) return a.name < b.name end)
    return out
end

-- feitiços ativos do grimório (sem passivos), por grupo e nome
local function KnownSpells()
    local out, seen = {}, {}
    local function Add(id, name, icon, group)
        if not id or seen[id] then return end
        seen[id] = true
        if not name then name, icon = SpellInfo(id) end
        out[#out + 1] = { id = id, name = name or ("Feitiço #" .. id), icon = icon or 134400, extra = group or "" }
    end
    local SB = C_SpellBook
    if SB and SB.GetNumSpellBookSkillLines and SB.GetSpellBookItemInfo then
        local bank = Enum and Enum.SpellBookSpellBank and Enum.SpellBookSpellBank.Player or 0
        local spellType = Enum and Enum.SpellBookItemType and Enum.SpellBookItemType.Spell
        for line = 1, SB.GetNumSpellBookSkillLines() or 0 do
            local info = SB.GetSpellBookSkillLineInfo(line)
            if info and not info.shouldHide and not info.offSpecID then
                for k = 1, info.numSpellBookItems or 0 do
                    local ok, it = pcall(SB.GetSpellBookItemInfo, (info.itemIndexOffset or 0) + k, bank)
                    if ok and it and it.spellID and not it.isPassive and (not spellType or it.itemType == spellType) then
                        Add(it.spellID, it.name, it.iconID, info.name)
                    end
                end
            end
        end
    elseif GetNumSpellTabs and GetSpellTabInfo and GetSpellBookItemInfo then
        for t = 1, GetNumSpellTabs() do
            local group, _, offset, count = GetSpellTabInfo(t)
            for i = (offset or 0) + 1, (offset or 0) + (count or 0) do
                local kind, id = GetSpellBookItemInfo(i, "spell")
                local passive = IsPassiveSpell and IsPassiveSpell(i, "spell")
                if kind == "SPELL" and id and not passive then Add(id, nil, nil, group) end
            end
        end
    end
    table.sort(out, function(a, b)
        if a.extra ~= b.extra then return a.extra < b.extra end
        return a.name < b.name
    end)
    return out
end

local MODES = {
    items = {
        title = "CONSUMÍVEIS DO MENU RADIAL", list = "NAS SUAS MOCHILAS", color = TAB_COLOR[3],
        help = "Escolha um espaço e clique num item da lista, arraste um item da mochila ou digite o número.",
        idLabel = "número do item (6948 = Pedra de Regresso)",
        info = function(id) return ItemInfo(id) end, source = BagConsumables,
        tip = function(id) GameTooltip:SetItemByID(id) end,
        drop = function(kind, a) if kind == "item" then return a end end,
    },
    spells = {
        title = "HABILIDADES DO MENU RADIAL", list = "NO SEU GRIMÓRIO", color = TAB_COLOR[4],
        help = "Escolha um espaço e clique numa habilidade da lista (bênçãos, buffs, formas...), arraste do grimório ou digite o número.",
        idLabel = "número do feitiço",
        info = function(id) return SpellInfo(id) end, source = KnownSpells,
        tip = function(id) if GameTooltip.SetSpellByID then GameTooltip:SetSpellByID(id) end end,
        drop = function(kind, a, _, c) if kind == "spell" then return c or a end end,
    },
}

local function BuildEditor()
    local U = Azaath.ConfigUI
    local C = U and U.C or { gold = GOLD, accent = TAB_COLOR[1], cream = CREAM, dim = DIM, panel = { 0.06, 0.07, 0.08 }, card = { 0.08, 0.09, 0.1 }, bg = { 0.035, 0.04, 0.05 } }
    local function Box(fr, bg, a, border, ba)
        if U then U.Box(fr, bg, a, border, ba) end
    end
    local function Text(parent, size, color, bold)
        local fs = parent:CreateFontString(nil, "OVERLAY")
        Font(fs, bold and Azaath.media.fontTitleB or Azaath.media.font, size)
        fs:SetTextColor(color[1], color[2], color[3])
        fs:SetShadowOffset(1, -1)
        fs:SetJustifyH("LEFT")
        return fs
    end

    local e = CreateFrame("Frame", "AzaathUIRadialConsumablesEditor", UIParent)
    editor = e
    e.mode, e.selected = "items", 1
    e:SetSize(520, 500)
    e:SetPoint("CENTER", 0, 20)
    e:SetFrameStrata("FULLSCREEN_DIALOG") -- acima do painel /azaath (DIALOG), de onde ele é aberto
    e:SetToplevel(true)
    e:SetClampedToScreen(true)
    e:SetMovable(true)
    e:EnableMouse(true)
    e:RegisterForDrag("LeftButton")
    e:SetScript("OnDragStart", e.StartMoving)
    e:SetScript("OnDragStop", e.StopMovingOrSizing)
    Box(e, C.bg, 0.97, C.gold, 0.55)
    if U and U.Chrome then U.Chrome(e, 70) end
    if UISpecialFrames then tinsert(UISpecialFrames, "AzaathUIRadialConsumablesEditor") end

    local title = Text(e, 15, C.accent, true)
    title:SetPoint("TOPLEFT", 24, -20)
    local sub = Text(e, 11, C.dim)
    sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
    sub:SetWidth(470)
    local close = CreateFrame("Button", nil, e)
    close:SetSize(24, 24)
    close:SetPoint("TOPRIGHT", -14, -14)
    close:SetFrameLevel(e:GetFrameLevel() + 40)
    local cx = close:CreateTexture(nil, "ARTWORK")
    cx:SetAllPoints()
    cx:SetTexture(Azaath.media.path .. "MapUI\\Close.tga")
    cx:SetVertexColor(C.dim[1], C.dim[2], C.dim[3])
    close:SetScript("OnClick", function() e:Hide() end)

    -- modos: Consumíveis / Habilidades
    local modeButtons = {}
    local function ModeButton(mode, label, x)
        local b
        if U then
            b = U.Button(e, label, 150, function() e.mode, e.selected = mode, 1; e.Refresh() end)
        else
            b = CreateFrame("Button", nil, e)
            b:SetSize(150, 24)
            b:SetScript("OnClick", function() e.mode, e.selected = mode, 1; e.Refresh() end)
        end
        b:SetHeight(24)
        b:SetPoint("TOPLEFT", x, -78)
        modeButtons[mode] = b
    end
    ModeButton("items", "Consumíveis", 24)
    ModeButton("spells", "Habilidades", 182)

    local slotsF = {}
    for i = 1, MAX_SLOTS do
        local b = CreateFrame("Button", nil, e)
        b:SetSize(110, 50)
        b:SetPoint("TOPLEFT", 24 + ((i - 1) % 4) * 118, -114 - floor((i - 1) / 4) * 58)
        Box(b, C.card, 0.9, C.gold, 0.35)
        b.ring = Tex(b, "ARTWORK", "SlotRim", 1)
        b.ring:SetSize(42, 42)
        b.ring:SetPoint("LEFT", 2, 0)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetSize(32, 32)
        b.icon:SetPoint("CENTER", b.ring, "CENTER")
        b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        CircleMask(b, b.icon)
        b.text = Text(b, 10, C.cream)
        b.text:SetPoint("LEFT", b.ring, "RIGHT", 2, 0)
        b.text:SetPoint("RIGHT", -4, 0)
        b.text:SetMaxLines(2)
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        local function Drop()
            local id = MODES[e.mode].drop(GetCursorInfo())
            if id then ClearCursor(); SetSlotIn(e.mode, i, id) return true end
        end
        b:SetScript("OnClick", function(_, mb)
            if Drop() then return end
            if mb == "RightButton" then SetSlotIn(e.mode, i, nil) return end
            e.selected = i
            e.Refresh()
        end)
        b:SetScript("OnReceiveDrag", Drop)
        b:SetScript("OnEnter", function(self)
            local id = tonumber(SavedList(e.mode)[i])
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if id then MODES[e.mode].tip(id) else GameTooltip:SetText("Espaço " .. i .. " vazio") end
            GameTooltip:AddLine("Clique: escolher este espaço  |  botão direito: esvaziar", 0.7, 0.85, 1)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        slotsF[i] = b
    end

    local idBox = CreateFrame("EditBox", nil, e, "InputBoxTemplate")
    idBox:SetSize(110, 24)
    idBox:SetPoint("TOPLEFT", 30, -240)
    idBox:SetAutoFocus(false)
    idBox:SetNumeric(true)
    local idLabel = Text(e, 11, C.dim)
    idLabel:SetPoint("LEFT", idBox, "RIGHT", 10, 0)
    local function BindTyped()
        local id = tonumber(idBox:GetText())
        if id and id > 0 then SetSlotIn(e.mode, e.selected, id); idBox:SetText("") end
        idBox:ClearFocus()
    end
    local bind = U and U.Button(e, "Vincular", 100, BindTyped, "primary")
    if bind then bind:SetHeight(24); bind:SetPoint("TOPRIGHT", -24, -240) end
    idBox:SetScript("OnEnterPressed", BindTyped)

    local listTitle = Text(e, 12, C.accent, true)
    listTitle:SetPoint("TOPLEFT", 24, -280)
    local search = CreateFrame("EditBox", nil, e, "InputBoxTemplate")
    search:SetSize(170, 22)
    search:SetPoint("TOPRIGHT", -28, -276)
    search:SetAutoFocus(false)
    local searchHint = Text(search, 11, C.dim)
    searchHint:SetPoint("LEFT", 4, 0)
    searchHint:SetText("buscar...")
    search:SetScript("OnTextChanged", function(self)
        searchHint:SetShown((self:GetText() or "") == "")
        if e.Refresh then e.Refresh() end
    end)
    search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)

    local scroll = CreateFrame("ScrollFrame", nil, e, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", 24, -304)
    scroll:SetPoint("BOTTOMRIGHT", -40, 20)
    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(450, 200)
    scroll:SetScrollChild(content)
    local rows = {}

    function e.Refresh()
        local M = MODES[e.mode]
        local col = M.color
        title:SetText(Spaced(M.title))
        title:SetTextColor(col[1], col[2], col[3])
        sub:SetText(M.help)
        idLabel:SetText(M.idLabel)
        listTitle:SetText(Spaced(M.list))
        listTitle:SetTextColor(col[1], col[2], col[3])
        for mode, b in pairs(modeButtons) do
            local on = mode == e.mode
            local c = on and MODES[mode].color or C.gold
            if b.SetBackdropBorderColor then b:SetBackdropBorderColor(c[1], c[2], c[3], on and 1 or 0.4) end
            if b.text then b.text:SetTextColor(on and 1 or C.cream[1], on and 1 or C.cream[2], on and 1 or C.cream[3]) end
        end

        local saved = SavedList(e.mode)
        for i, b in ipairs(slotsF) do
            local id = tonumber(saved[i])
            if id and id > 0 then
                local name, icon = M.info(id)
                b.icon:SetTexture(icon or 134400)
                b.icon:Show()
                b.text:SetText(name or ("#" .. id))
                b.text:SetTextColor(C.cream[1], C.cream[2], C.cream[3])
            else
                b.icon:Hide()
                b.text:SetText("Espaço " .. i .. "\nvazio")
                b.text:SetTextColor(C.dim[1], C.dim[2], C.dim[3])
            end
            local on = i == e.selected
            local bc = on and col or C.gold
            if b.SetBackdropBorderColor then b:SetBackdropBorderColor(bc[1], bc[2], bc[3], on and 1 or 0.35) end
        end

        for _, r in ipairs(rows) do r:Hide() end
        local filter = (search:GetText() or ""):lower()
        local list = {}
        for _, it in ipairs(M.source()) do
            if filter == "" or it.name:lower():find(filter, 1, true) then list[#list + 1] = it end
        end
        local w, h = 218, 30
        for idx, it in ipairs(list) do
            local r = rows[idx]
            if not r then
                r = CreateFrame("Button", nil, content)
                r:SetSize(w, h)
                Box(r, C.panel, 0.85, C.gold, 0.18)
                r.icon = r:CreateTexture(nil, "ARTWORK")
                r.icon:SetSize(22, 22)
                r.icon:SetPoint("LEFT", 5, 0)
                r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
                r.label = Text(r, 11, C.cream)
                r.label:SetPoint("LEFT", r.icon, "RIGHT", 6, 0)
                r.label:SetPoint("RIGHT", -4, 0)
                r.label:SetWordWrap(false)
                local hl = r:CreateTexture(nil, "HIGHLIGHT")
                hl:SetTexture(Azaath.media.blank)
                hl:SetAllPoints()
                hl:SetVertexColor(1, 1, 1, 0.06)
                rows[idx] = r
            end
            r:ClearAllPoints()
            r:SetPoint("TOPLEFT", ((idx - 1) % 2) * (w + 8), -floor((idx - 1) / 2) * (h + 4))
            r.icon:SetTexture(it.icon)
            r.label:SetText(it.name .. ((it.extra ~= "") and ("  |cff999999" .. it.extra .. "|r") or ""))
            r:SetScript("OnClick", function()
                SetSlotIn(e.mode, e.selected, it.id)
                e.selected = e.selected % MAX_SLOTS + 1
                e.Refresh()
            end)
            r:SetScript("OnEnter", function(self)
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                M.tip(it.id)
                GameTooltip:Show()
            end)
            r:SetScript("OnLeave", function() GameTooltip:Hide() end)
            r:Show()
        end
        content:SetHeight(max(160, ceil(#list / 2) * (h + 4)))
    end
end

--------------------------------------------------------------------------------
-- API pública e eventos
--------------------------------------------------------------------------------

function AC.IsRadialMenuOpen() return Wheel ~= nil and Wheel:IsShown() end

function AC.GetRadialConsumables() return Saved() end
AC.SetRadialConsumableSlot = SetSlot

function AC.OnRadialConsumablesChanged(fn)
    if type(fn) == "function" then changeListeners[#changeListeners + 1] = fn end
end

-- mode: "items" (padrão) ou "spells"
function AC.OpenRadialConsumablesEditor(mode)
    if not editor then BuildEditor() end
    if mode == "spells" or mode == "items" then editor.mode, editor.selected = mode, 1 end
    editor.Refresh()
    editor:Show()
    editor:Raise()
end

function AC.RefreshRadialStore()
    Store()
    Paint()
end

function AC.RefreshRadialBindings()
    if InCombatLockdown() then return end
    BuildSecure()
    if not View then BuildView(); HookView() end
    Store()
    ClearOverrideBindings(bindOwner)
    local db = AC.DB()
    if not db or not db.enabled or db.radialEnabled == false then return end
    local k1, k2 = GetBindingKey("AZAATH_RADIALMENU")
    if k1 then SetOverrideBindingClick(bindOwner, false, k1, Trigger:GetName(), "LeftButton") end
    if k2 then SetOverrideBindingClick(bindOwner, false, k2, Trigger:GetName(), "LeftButton") end
end

function AC.InitRadialMenu()
    BuildSecure()
    if not View then BuildView(); HookView() end
    Store()
    AC.RefreshRadialBindings()
end

local events = CreateFrame("Frame")
Azaath.SafeRegister(events, "BAG_UPDATE_DELAYED", "SPELL_UPDATE_COOLDOWN", "PLAYER_REGEN_ENABLED", "GET_ITEM_INFO_RECEIVED", "SPELLS_CHANGED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_ENABLED" and storePending then
        storePending = false
        Store()
    elseif (event == "GET_ITEM_INFO_RECEIVED" or event == "SPELLS_CHANGED") and not InCombatLockdown() then
        Store() -- nomes e ícones que ainda não tinham chegado
    end
    Paint()
    if editor and editor:IsShown() then editor.Refresh() end
end)
