--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Spellbook.lua
    Livro de feitiços no estilo Azaath (3.3.5a): abas (escolas/
    especializações + Pet), cartões com ícone, nome e posto/"Passiva",
    recarga, 14 feitiços por página. Mostra só o posto mais alto de cada
    feitiço (como o livro padrão com "mostrar todos os postos" desligado).

    Por que partes são seguras:
      * Cada cartão é um SecureActionButtonTemplate (type "spell", spell = nome)
        para lançar ao clicar, inclusive em combate. Atributos só podem mudar
        FORA de combate, então em combate não dá para trocar de aba/página
        (aviso na tela); lançar pela página aberta funciona normalmente.
      * A janela, por conter botões seguros, fica protegida: o código comum do
        addon não pode mostrá-la/escondê-la em combate. A tecla do livro (P) e
        o X usam um SecureHandlerClickTemplate (snippet seguro) para alternar a
        janela inclusive em combate.
      * ESC (UISpecialFrames) só fora de combate: CloseSpecialWindows chamaria
        :Hide() de forma insegura. A janela sai da lista ao entrar em combate e
        volta ao sair.

    Arrastar para a barra: PickupSpell, só fora de combate.
    Shift+clique: link no chat (o clique seguro com Shift não lança nada).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("Spellbook")

local _G = _G
local ipairs, format, floor, max, min = ipairs, string.format, math.floor, math.max, math.min
-- Livro de feitiços via Compat (C_SpellBook / GetSpellBookItem* / GetSpellName)
local API = Azaath.API

local PAD, HEADER_H, TABS_H, FOOTER_H = 16, 46, 30, 40
local COLS, ROWS = 2, 7
local PER_PAGE = COLS * ROWS
local CARD_W, CARD_H, GAP = 236, 40, 6

local frame, toggleButton, bindOwner, notice, pageText, prevButton, nextButton
local cards = {}
local tabButtons = {}
local currentTab, currentPage = 1, 1
local list = {}
local lastBindingSignature

--------------------------------------------------------------------------------
-- Dados
--------------------------------------------------------------------------------
-- Abas: 1..N = abas do livro do jogador; "pet" = livro do pet (se houver)
local function TabCount()
    return API.SpellTabCount() or 0
end

local function HasPetBook()
    local n = API.NumPetSpells()
    return n and n > 0
end

-- Lista de feitiços da aba, só o posto mais alto de cada um.
-- Na 3.3.5 os postos ficam em sequência (crescente) no livro.
local function BuildList(tab)
    local result = {}
    local book, first, last
    if tab == "pet" then
        book, first, last = "pet", 1, API.NumPetSpells() or 0
    else
        local _, offset, num = API.SpellTabInfo(tab)
        book, first, last = "spell", (offset or 0) + 1, (offset or 0) + (num or 0)
    end
    for i = first, last do
        local name, rank = API.SpellName(i, book)
        local nextName = (i < last) and API.SpellName(i + 1, book) or nil
        if name and name ~= nextName then
            result[#result + 1] = {
                index = i, book = book, name = name, rank = rank or "",
                passive = API.SpellIsPassive(i, book),
            }
        end
    end
    return result
end

--------------------------------------------------------------------------------
-- Cartões
--------------------------------------------------------------------------------
local function Card_OnEnter(self)
    if not self.azIndex then return end
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    API.SetSpellTooltip(GameTooltip, self.azIndex, self.azBook)
    GameTooltip:Show()
end

local function Card_PostClick(self)
    if self.azIndex and IsModifiedClick("CHATLINK") then
        local link = API.SpellLink(self.azIndex, self.azBook)
        if link then ChatEdit_InsertLink(link) end
    end
end

local function Card_OnDragStart(self)
    if self.azIndex and not InCombatLockdown() then
        API.PickupSpell(self.azIndex, self.azBook)
    end
end

local function CreateCard(i)
    local c, media = Azaath.colors, Azaath.media
    local col, row = (i - 1) % COLS, floor((i - 1) / COLS)
    local b = CreateFrame("Button", "AzaathUISpellCard" .. i, frame, "SecureActionButtonTemplate")
    b:SetWidth(CARD_W)
    b:SetHeight(CARD_H)
    b:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD + col * (CARD_W + GAP + 2),
        -(HEADER_H + TABS_H + 10 + row * (CARD_H + GAP)))
    b:RegisterForClicks("AnyUp", "AnyDown")
    b:SetAttribute("useOnKeyDown", false)
    b:RegisterForDrag("LeftButton")
    b:SetAttribute("shift-type1", "") -- Shift+clique: só link no chat (PostClick)

    Azaath.SetBackdrop(b, { bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    b:SetBackdropColor(0.05, 0.06, 0.075, 0.7)
    b:SetBackdropBorderColor(c.slate[1], c.slate[2], c.slate[3], 0.5)

    b.iconBorder = CreateFrame("Frame", nil, b)
    b.iconBorder:SetWidth(CARD_H - 4)
    b.iconBorder:SetHeight(CARD_H - 4)
    b.iconBorder:SetPoint("LEFT", b, "LEFT", 2, 0)
    Azaath.SetBackdrop(b.iconBorder, { edgeFile = media.blank, edgeSize = 1 })
    b.iconBorder:SetBackdropBorderColor(c.slate[1], c.slate[2], c.slate[3], 0.9)

    b.icon = b.iconBorder:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", b.iconBorder, "TOPLEFT", 1, -1)
    b.icon:SetPoint("BOTTOMRIGHT", b.iconBorder, "BOTTOMRIGHT", -1, 1)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    b.cooldown = CreateFrame("Cooldown", nil, b.iconBorder, "CooldownFrameTemplate")
    b.cooldown:SetAllPoints(b.icon)

    b.name = b:CreateFontString(nil, "OVERLAY")
    b.name:SetFont(media.font, 14, "")
    b.name:SetShadowOffset(1, -1)
    b.name:SetShadowColor(0, 0, 0, 0.9)
    b.name:SetJustifyH("LEFT")
    b.name:SetPoint("TOPLEFT", b.iconBorder, "TOPRIGHT", 8, -3)
    b.name:SetPoint("RIGHT", b, "RIGHT", -6, 0)
    b.name:SetHeight(16)

    b.sub = b:CreateFontString(nil, "OVERLAY")
    b.sub:SetFont(media.font, 12, "")
    b.sub:SetTextColor(c.dim[1], c.dim[2], c.dim[3])
    b.sub:SetJustifyH("LEFT")
    b.sub:SetPoint("BOTTOMLEFT", b.iconBorder, "BOTTOMRIGHT", 8, 3)

    -- destaque dourado ao passar o mouse (caminho + ajuste: forma garantida na 3.3.5)
    b:SetHighlightTexture(media.blank)
    local hl = b:GetHighlightTexture()
    hl:SetAllPoints(b)
    Azaath.Gradient(hl, "HORIZONTAL", c.gold[1], c.gold[2], c.gold[3], 0.3, c.gold[1], c.gold[2], c.gold[3], 0)

    b:SetScript("OnEnter", Card_OnEnter)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("PostClick", Card_PostClick)
    b:SetScript("OnDragStart", Card_OnDragStart)
    cards[i] = b
    return b
end

local function UpdateCooldowns()
    for _, b in ipairs(cards) do
        if b.azIndex then
            local start, duration, enable = API.SpellCooldown(b.azIndex, b.azBook)
            if Azaath.IsOn(enable) and start and not Azaath.AnySecret(start, duration, enable) and start > 0 and duration > 1.5 then
                b.cooldown:SetCooldown(start, duration)
                b.cooldown:Show()
            else
                b.cooldown:Hide()
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Montagem da página (SÓ fora de combate: muda atributos seguros)
--------------------------------------------------------------------------------
local function UpdateTabs()
    local c = Azaath.colors
    for _, t in ipairs(tabButtons) do
        local active = (t.tab == currentTab)
        t.text:SetTextColor(active and 1 or c.dim[1], active and 1 or c.dim[2], active and 1 or c.dim[3])
        if active then t.line:Show() else t.line:Hide() end
    end
end

local function Render()
    if InCombatLockdown() then
        Azaath:RunOutOfCombat(Render)
        notice:Show()
        return
    end
    notice:Hide()

    -- aba que deixou de existir (pet dispensado, etc.)
    if currentTab == "pet" and not HasPetBook() then currentTab = 1 end
    if currentTab ~= "pet" and currentTab > TabCount() then currentTab = 1 end

    list = BuildList(currentTab)
    local pages = max(1, math.ceil(#list / PER_PAGE))
    currentPage = min(currentPage, pages)

    local c = Azaath.colors
    for i = 1, PER_PAGE do
        local b = cards[i]
        local e = list[(currentPage - 1) * PER_PAGE + i]
        if e then
            b.azIndex, b.azBook = e.index, e.book
            if e.passive then
                b:SetAttribute("type", nil)
                b:SetAttribute("spell", nil)
            else
                b:SetAttribute("type", "spell")
                b:SetAttribute("spell", e.name)
            end
            b.icon:SetTexture(API.SpellTexture(e.index, e.book))
            b.icon:SetDesaturated(e.passive and true or false)
            b.name:SetText(e.name)
            local tc = e.passive and c.dim or c.cream
            b.name:SetTextColor(tc[1], tc[2], tc[3])
            b.sub:SetText(e.passive and "Passiva" or (e.rank ~= "" and e.rank or ""))
            b:Show()
        else
            b.azIndex, b.azBook = nil, nil
            b:SetAttribute("type", nil)
            b:SetAttribute("spell", nil)
            b:Hide()
        end
    end

    pageText:SetText(format("%d / %d", currentPage, pages))
    if currentPage > 1 then prevButton:Enable() else prevButton:Disable() end
    if currentPage < pages then nextButton:Enable() else nextButton:Disable() end
    UpdateTabs()
    UpdateCooldowns()
end

local function Navigate(tab, page)
    if InCombatLockdown() then
        UIErrorsFrame:AddMessage("Troca de aba/página indisponível em combate.", 1, 0.3, 0.25)
        return
    end
    currentTab, currentPage = tab or currentTab, page or 1
    Azaath.PlaySound("igAbiliityPageTurn")
    Render()
end

--------------------------------------------------------------------------------
-- Abas
--------------------------------------------------------------------------------
local function CreateTabButton(i)
    local c, media = Azaath.colors, Azaath.media
    local t = CreateFrame("Button", nil, frame)
    t:SetHeight(TABS_H - 6)
    t.text = t:CreateFontString(nil, "OVERLAY")
    t.text:SetFont(media.font, 14, "")
    t.text:SetPoint("CENTER", t, "CENTER", 0, 0)
    t.line = t:CreateTexture(nil, "ARTWORK")
    t.line:SetTexture(media.blank)
    t.line:SetVertexColor(c.gold[1], c.gold[2], c.gold[3])
    t.line:SetHeight(2)
    t.line:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 4, 0)
    t.line:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -4, 0)
    t:SetScript("OnClick", function(self) Navigate(self.tab, 1) end)
    tabButtons[i] = t
    return t
end

-- Abas mudam com novas especializações/pet; reposiciona lado a lado
local function LayoutTabs()
    local defs = {}
    for i = 1, TabCount() do
        defs[#defs + 1] = { tab = i, label = (API.SpellTabInfo(i)) }
    end
    if HasPetBook() then defs[#defs + 1] = { tab = "pet", label = "Pet" } end

    local x = PAD
    for i, d in ipairs(defs) do
        local t = tabButtons[i] or CreateTabButton(i)
        t.tab = d.tab
        t.text:SetText(d.label or "?")
        t:SetWidth(t.text:GetStringWidth() + 20)
        t:ClearAllPoints()
        t:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -(HEADER_H + 4))
        t:Show()
        x = x + t:GetWidth() + 4
    end
    for i = #defs + 1, #tabButtons do tabButtons[i]:Hide(); tabButtons[i].tab = nil end
end

--------------------------------------------------------------------------------
-- Janela
--------------------------------------------------------------------------------
local TOGGLE_SNIPPET = [[
    local book = self:GetFrameRef("book")
    if book:IsShown() then book:Hide() else book:Show() end
]]

local function SavePosition()
    local left, top = frame:GetLeft(), frame:GetTop()
    if left and top then M.db.pos = { x = left, y = top - UIParent:GetTop() } end
end

local function CreateFooterButton(label, width, func)
    local c = Azaath.colors
    local b = CreateFrame("Button", nil, frame)
    b:SetWidth(width)
    b:SetHeight(22)
    Azaath.ApplyPanel(b, 0.9)
    b.text = b:CreateFontString(nil, "OVERLAY")
    b.text:SetFont(Azaath.media.font, 13, "")
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b:SetScript("OnClick", func)
    b:SetScript("OnEnable", function(self) self.text:SetTextColor(c.cream[1], c.cream[2], c.cream[3]) end)
    b:SetScript("OnDisable", function(self) self.text:SetTextColor(c.dim[1], c.dim[2], c.dim[3]) end)
    b.text:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    return b
end

local function Build()
    local c, media = Azaath.colors, Azaath.media
    local width = PAD * 2 + COLS * CARD_W + (COLS - 1) * (GAP + 2)
    local height = HEADER_H + TABS_H + 10 + ROWS * (CARD_H + GAP) + FOOTER_H

    -- Protegida explicitamente: pode ser alternada pelo snippet seguro em combate
    frame = CreateFrame("Frame", "AzaathUISpellbook", UIParent, "SecureFrameTemplate")
    M.frame = frame
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetWidth(width)
    frame:SetHeight(height)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    Azaath.ApplyPanel(frame, 0.95)
    local pos = M.db.pos
    if pos then
        frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", pos.x, pos.y)
    else
        frame:SetPoint("LEFT", UIParent, "LEFT", 60, 20)
    end
    frame:Hide()

    -- Cabeçalho
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_H)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        if not InCombatLockdown() then frame:StartMoving() end
    end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SavePosition() end)
    local band = header:CreateTexture(nil, "BACKGROUND")
    band:SetTexture(media.blank)
    band:SetVertexColor(0.11, 0.135, 0.16)
    band:SetAlpha(0.95)
    band:SetAllPoints(header)
    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont(media.fontTitleB, 15, "")
    title:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    title:SetPoint("LEFT", header, "LEFT", PAD, 0)
    title:SetText(Azaath.Tracked("Livro de feitiços"))

    -- X seguro (funciona em combate)
    local close = CreateFrame("Button", "AzaathUISpellbookClose", header, "SecureHandlerClickTemplate")
    close:SetWidth(20)
    close:SetHeight(20)
    close:SetPoint("RIGHT", header, "RIGHT", -10, 0)
    close:SetFrameRef("book", frame)
    close:SetAttribute("_onclick", TOGGLE_SNIPPET)
    local x = close:CreateFontString(nil, "OVERLAY")
    x:SetFont(media.font, 16, "")
    x:SetTextColor(c.dim[1], c.dim[2], c.dim[3])
    x:SetPoint("CENTER", close, "CENTER", 0, 0)
    x:SetText("X")

    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetTexture(media.blank)
    Azaath.Gradient(line, "HORIZONTAL", c.gold[1], c.gold[2], c.gold[3], 0.8, c.gold[1], c.gold[2], c.gold[3], 0.1)
    line:SetHeight(2)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)

    for i = 1, PER_PAGE do CreateCard(i) end

    -- Rodapé: páginas + livro padrão
    prevButton = CreateFooterButton("<", 28, function() Navigate(nil, currentPage - 1) end)
    prevButton:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 10)
    pageText = frame:CreateFontString(nil, "OVERLAY")
    pageText:SetFont(media.font, 13, "")
    pageText:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    pageText:SetPoint("LEFT", prevButton, "RIGHT", 10, 0)
    nextButton = CreateFooterButton(">", 28, function() Navigate(nil, currentPage + 1) end)
    nextButton:SetPoint("LEFT", pageText, "RIGHT", 10, 0)

    local default = CreateFooterButton("Livro padrão", 110, function()
        if InCombatLockdown() then return end
        API.OpenDefaultSpellbook()
    end)
    default:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 10)

    notice = frame:CreateFontString(nil, "OVERLAY")
    notice:SetFont(media.font, 12, "")
    notice:SetTextColor(1, 0.45, 0.35)
    notice:SetPoint("BOTTOM", frame, "BOTTOM", 0, 14)
    notice:SetText("Atualiza ao sair do combate")
    notice:Hide()

    frame:SetScript("OnShow", function()
        Azaath.PlaySound("igSpellBookOpen")
        if not InCombatLockdown() then
            LayoutTabs()
            Render()
        else
            UpdateCooldowns()
        end
    end)
    frame:SetScript("OnHide", function() Azaath.PlaySound("igSpellBookClose") end)

    -- Botão-alvo da tecla do livro: snippet seguro alterna a janela em combate
    toggleButton = CreateFrame("Button", "AzaathUISpellbookToggle", UIParent, "SecureHandlerClickTemplate")
    toggleButton:SetFrameRef("book", frame)
    toggleButton:SetAttribute("_onclick", TOGGLE_SNIPPET)
    toggleButton:RegisterForClicks("AnyUp")
    bindOwner = CreateFrame("Frame")
end

--------------------------------------------------------------------------------
-- Tecla, ESC e eventos
--------------------------------------------------------------------------------
local function UpdateBinding()
    -- Com o Grimório da ficha ativo, a tecla do livro é dele (Modules/Grimoire.lua)
    local grimoire = Azaath:GetModule("Grimoire")
    if grimoire and grimoire.IsActive and grimoire:IsActive() then
        if lastBindingSignature ~= "grimoire" then
            Azaath:RunOutOfCombat(function()
                lastBindingSignature = "grimoire"
                ClearOverrideBindings(bindOwner)
            end)
        end
        return
    end
    local key1, key2 = GetBindingKey("TOGGLESPELLBOOK")
    local signature = (key1 or "") .. "," .. (key2 or "")
    if signature == lastBindingSignature then return end
    Azaath:RunOutOfCombat(function()
        lastBindingSignature = signature
        ClearOverrideBindings(bindOwner)
        for _, key in ipairs({ key1, key2 }) do
            if key and key ~= "" then
                SetOverrideBindingClick(bindOwner, false, key, "AzaathUISpellbookToggle", "LeftButton")
            end
        end
    end)
end

local function SetEscCloses(enabled)
    for i = #UISpecialFrames, 1, -1 do
        if UISpecialFrames[i] == "AzaathUISpellbook" then table.remove(UISpecialFrames, i) end
    end
    if enabled then tinsert(UISpecialFrames, "AzaathUISpellbook") end
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "SPELL_UPDATE_COOLDOWN" then
        if frame:IsShown() then UpdateCooldowns() end
    elseif event == "UPDATE_BINDINGS" then
        UpdateBinding()
    elseif event == "PLAYER_REGEN_DISABLED" then
        SetEscCloses(false)
    elseif event == "PLAYER_REGEN_ENABLED" then
        SetEscCloses(true)
    elseif frame:IsShown() and not InCombatLockdown() then
        -- feitiço aprendido, nova especialização, pet chamado/dispensado
        LayoutTabs()
        Render()
    end
end)

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:Toggle()
    if InCombatLockdown() then return end
    if not frame then Build() end
    if frame:IsShown() then
        frame:Hide()
    else
        frame:Show()
    end
end

function M:Open()
    if InCombatLockdown() then return end
    if not frame then Build() end
    if not frame:IsShown() then frame:Show() end
end

function M:OnInitialize()
    self.db = Azaath.db.spellbook
end

function M:OnEnable()
    if not self.db.enabled then return end
    -- Cria frames seguros: só fora de combate
    Azaath:RunOutOfCombat(function()
        Build()
        UpdateBinding()
        SetEscCloses(true)
        for _, e in ipairs({ "SPELL_UPDATE_COOLDOWN", "UPDATE_BINDINGS", "PLAYER_REGEN_DISABLED",
                             "PLAYER_REGEN_ENABLED", "LEARNED_SPELL_IN_TAB", "LEARNED_SPELL_IN_SKILL_LINE", "SPELLS_CHANGED",
                             "PET_BAR_UPDATE", "UNIT_PET" }) do
            Azaath.SafeRegister(events, e)
        end
    end)
end
