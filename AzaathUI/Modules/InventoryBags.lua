--[[----------------------------------------------------------------------------
    AzaathUI - Modules/InventoryBags.lua
    Faixa "Mochilas" logo abaixo do cabeçalho do inventário:
      * um botão por bolsa equipada (mochila + 4 bolsas + bolsa de reagentes no
        cliente moderno), com o número de espaços no canto e a raridade na borda
      * passar o mouse mostra o card da bolsa (tooltip do item -> ItemCard.lua);
        a mochila (bolsa 0) não é item: mostra nome e espaços
      * clique seleciona só aquela bolsa (o inventário mostra apenas os itens
        dela); clicar de novo volta a mostrar todas
      * clique direito desequipa a bolsa (os itens dela vão para as outras)
      * com um item no cursor, o clique/soltar guarda o item na bolsa;
        arrastar a bolsa a pega do espaço (fora de combate)
      * à direita: espaço livre (das bolsas mostradas) com barra
    Chamado por Inventory.lua: Build(frame, header, y, width, onSelect) e Update().
------------------------------------------------------------------------------]]

local _, Azaath = ...
local IB = {}
Azaath.InventoryBags = IB

local _G = _G
local max, format = math.max, string.format

local H = 46            -- altura da faixa (Inventory.lua soma no layout)
IB.HEIGHT = H
local BTN, GAP = 30, 5
local COL = {
    title = { 0.88, 0.85, 0.77 }, dim = { 0.60, 0.60, 0.58 }, text = { 0.90, 0.88, 0.82 },
    box = { 0.02, 0.055, 0.09 }, boxBd = { 0.17, 0.20, 0.24 }, gold = { 0.89, 0.78, 0.55 },
    teal = { 0.36, 0.78, 0.74 }, slot = { 0.27, 0.285, 0.28 },
}
local BACKPACK_TEX = "Interface\\Buttons\\Button-Backpack-Up"
local EMPTY_TEX = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag"

local strip, buttons, freeText, freeBar, freeW = nil, {}, nil, nil, 1
local onSelect
IB.selected = nil       -- bolsa escolhida (nil = todas)

local function Num(v)
    if v == nil or Azaath.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

local function NumSlots(bag)
    return Num(Azaath.API.GetContainerNumSlots(bag)) or 0
end

local function FreeSlots(bag)
    local CC = _G.C_Container
    local fn = (CC and CC.GetContainerNumFreeSlots) or _G.GetContainerNumFreeSlots
    if fn then
        local ok, n = pcall(fn, bag)
        if ok and Num(n) then return n end
    end
    local free = 0
    for slot = 1, NumSlots(bag) do
        if not Azaath.API.GetContainerItemInfo(bag, slot) then free = free + 1 end
    end
    return free
end

local function InvID(bag)
    if bag == 0 then return nil end
    local CC = _G.C_Container
    local fn = (CC and CC.ContainerIDToInventoryID) or _G.ContainerIDToInventoryID
    if not fn then return nil end
    local ok, id = pcall(fn, bag)
    return ok and id or nil
end

local function Text(parent, font, size, color)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if not pcall(fs.SetFont, fs, font, size, "") or not fs:GetFont() then fs:SetFont("Fonts\\FRIZQT__.TTF", size, "") end
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetShadowOffset(1, -1)
    fs:SetTextColor(color[1], color[2], color[3])
    return fs
end

local function Box(f, a)
    local media = Azaath.media
    Azaath.SetBackdrop(f, { bgFile = media.blank, edgeFile = media.blank, edgeSize = 1 })
    f:SetBackdropColor(COL.box[1], COL.box[2], COL.box[3], a or 0.85)
    f:SetBackdropBorderColor(COL.boxBd[1], COL.boxBd[2], COL.boxBd[3], 0.9)
end

--------------------------------------------------------------------------------
-- Botões das bolsas
--------------------------------------------------------------------------------
local function Select(bag)
    if IB.selected == bag then bag = nil end
    IB.selected = bag
    IB.Update()
    if onSelect then onSelect(bag) end
end

local function Bag_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    local invID = InvID(self.bag)
    if invID and GetInventoryItemTexture("player", invID) then
        GameTooltip:SetInventoryItem("player", invID) -- vira o card da bolsa (ItemCard.lua)
    else
        GameTooltip:SetText(self.bag == 0 and (_G.BACKPACK_TOOLTIP or "Mochila") or (_G.BAGSLOT or "Bolsa"))
        local n = NumSlots(self.bag)
        if n > 0 then
            GameTooltip:AddLine(format("%d espaços  -  %d livres", n, FreeSlots(self.bag)), 1, 1, 1)
        else
            GameTooltip:AddLine("Espaço vazio: solte uma bolsa aqui.", 0.7, 0.7, 0.7, true)
        end
    end
    GameTooltip:AddLine(IB.selected == self.bag and "Clique: mostrar todas as bolsas" or "Clique: mostrar só esta bolsa",
        COL.gold[1], COL.gold[2], COL.gold[3])
    if self.bag >= 1 and self.bag <= 4 and NumSlots(self.bag) > 0 then
        GameTooltip:AddLine("Clique direito: desequipar", COL.gold[1], COL.gold[2], COL.gold[3])
    end
    GameTooltip:Show()
end

-- Item no cursor: guarda na bolsa (como as bolsas da Blizzard)
local function PutCursorIn(bag)
    if not CursorHasItem() or InCombatLockdown() then return false end
    if bag == 0 then
        if _G.PutItemInBackpack then _G.PutItemInBackpack() end
    else
        local invID = InvID(bag)
        if invID and _G.PutItemInBag then _G.PutItemInBag(invID) end
    end
    return true
end

local function Bag_OnClick(self, button)
    if PutCursorIn(self.bag) then return end
    local invID = InvID(self.bag)
    local link = invID and GetInventoryItemLink("player", invID)
    if link and IsModifiedClick("CHATLINK") then
        ChatEdit_InsertLink(link)
        return
    end
    -- direito: esvazia a bolsa nas outras e a desequipa (Inventory.lua)
    if button == "RightButton" then
        local inv = Azaath:GetModule("Inventory")
        if self.bag >= 1 and self.bag <= 4 and NumSlots(self.bag) > 0 and inv and inv.StartUnequipBag then
            if IB.selected == self.bag then Select(self.bag) end
            GameTooltip:Hide()
            inv.StartUnequipBag(self.bag)
        end
        return
    end
    if self.bag ~= 0 and NumSlots(self.bag) == 0 then return end
    Select(self.bag)
end

local function Bag_OnDrag(self)
    if InCombatLockdown() or self.bag == 0 then return end
    local invID = InvID(self.bag)
    if invID and _G.PickupBagFromSlot then _G.PickupBagFromSlot(invID) end
end

local function MakeButton(parent, bag)
    local media = Azaath.media
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(BTN, BTN)
    b.bag = bag
    b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    b:RegisterForDrag("LeftButton")
    Azaath.SetBackdrop(b, { bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    b:SetBackdropColor(0.03, 0.04, 0.05, 0.9)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.icon:SetPoint("TOPLEFT", 2, -2)
    b.icon:SetPoint("BOTTOMRIGHT", -2, 2)
    b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.count = Text(b, media.fontBold, 10, COL.text)
    b.count:SetPoint("BOTTOMRIGHT", -2, 2)
    -- moldura dourada da bolsa escolhida
    b.sel = b:CreateTexture(nil, "OVERLAY")
    b.sel:SetTexture(media.blank)
    b.sel:SetVertexColor(COL.gold[1], COL.gold[2], COL.gold[3], 0.22)
    b.sel:SetAllPoints(b.icon)
    b.sel:Hide()
    b:SetHighlightTexture(media.blank)
    local hl = b:GetHighlightTexture()
    hl:SetAllPoints(b.icon)
    hl:SetAlpha(0.15)
    b:SetScript("OnEnter", Bag_OnEnter)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", Bag_OnClick)
    b:SetScript("OnDragStart", Bag_OnDrag)
    b:SetScript("OnReceiveDrag", function(self) PutCursorIn(self.bag) end)
    return b
end

--------------------------------------------------------------------------------
-- API para Inventory.lua
--------------------------------------------------------------------------------
-- y: distância do topo da janela até a faixa; width: largura útil (sem recuos)
function IB.Build(frame, x, y, width, firstBag, lastBag, selectFn)
    onSelect = selectFn
    local media = Azaath.media
    strip = CreateFrame("Frame", nil, frame)
    strip:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
    strip:SetSize(width, H - 6)
    Box(strip, 0.8)
    IB.strip = strip -- a skin Azaath reposiciona

    local label = Text(strip, media.fontTitleB, 9, COL.dim)
    label:SetPoint("LEFT", 10, 0)
    label:SetText("MOCHILAS")

    local prev
    for bag = firstBag, lastBag do
        if bag <= 4 or InvID(bag) then -- bolsa de reagentes só onde o cliente tem o espaço
            local b = MakeButton(strip, bag)
            if prev then
                b:SetPoint("LEFT", prev, "RIGHT", GAP, 0)
            else
                b:SetPoint("LEFT", label, "RIGHT", 10, 0)
            end
            buttons[#buttons + 1] = b
            prev = b
        end
    end

    -- espaço livre: rótulo à esquerda, números à direita, barra embaixo
    local free = CreateFrame("Frame", nil, strip)
    free:SetPoint("LEFT", prev, "RIGHT", 14, 0)
    free:SetPoint("RIGHT", strip, "RIGHT", -10, 0)
    free:SetHeight(BTN)
    local fl = Text(free, media.fontTitleB, 8, COL.dim)
    fl:SetPoint("TOPLEFT", 0, -3)
    fl:SetText("ESPAÇO LIVRE")
    freeText = Text(free, media.fontBold, 10, COL.text)
    freeText:SetPoint("TOPRIGHT", 0, -2)
    local bg = free:CreateTexture(nil, "ARTWORK")
    bg:SetTexture(media.blank)
    bg:SetVertexColor(0, 0, 0, 0.6)
    bg:SetHeight(4)
    bg:SetPoint("BOTTOMLEFT", 0, 5)
    bg:SetPoint("BOTTOMRIGHT", 0, 5)
    freeBar = free:CreateTexture(nil, "OVERLAY")
    freeBar:SetTexture(media.blank)
    freeBar:SetHeight(4)
    freeBar:SetPoint("LEFT", bg, "LEFT")
    -- estreito (mochila com poucas colunas): textos curtos para não se sobreporem
    free:SetScript("OnSizeChanged", function(self, w)
        freeW = max(1, w or self:GetWidth())
        IB.compact = freeW < 150
        fl:SetText(IB.compact and "LIVRE" or "ESPAÇO LIVRE")
        IB.Update()
    end)
    IB.Update()
end

-- Ajusta a largura quando o inventário muda de tamanho
function IB.SetWidth(width)
    if strip then strip:SetWidth(width) end
end

function IB.Update()
    if not strip then return end
    local total, free = 0, 0
    for _, b in ipairs(buttons) do
        local bag, n = b.bag, NumSlots(b.bag)
        local invID = InvID(bag)
        local tex = (bag == 0) and BACKPACK_TEX or (invID and GetInventoryItemTexture("player", invID))
        b.icon:SetTexture(tex or EMPTY_TEX)
        b.icon:SetDesaturated(not tex)
        b.icon:SetAlpha(tex and 1 or 0.35)
        b.count:SetText(n > 0 and n or "")
        local q = invID and Num(GetInventoryItemQuality("player", invID))
        if IB.selected == bag then
            b:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 1)
            b.sel:Show()
        elseif q and q >= 2 then
            local r, g, bl = Azaath.API.GetItemQualityColor(q)
            b:SetBackdropBorderColor(r or 1, g or 1, bl or 1, 0.85)
            b.sel:Hide()
        else
            b:SetBackdropBorderColor(COL.slot[1], COL.slot[2], COL.slot[3], 0.9)
            b.sel:Hide()
        end
        -- outras bolsas apagadas quando uma está escolhida
        b.icon:SetVertexColor(1, 1, 1)
        if IB.selected and IB.selected ~= bag then b.icon:SetVertexColor(0.45, 0.45, 0.45) end
        if n > 0 and (not IB.selected or IB.selected == bag) then
            total, free = total + n, free + FreeSlots(bag)
        end
    end
    freeText:SetText(format(IB.compact and "%d / %d" or "%d / %d livres", free, total))
    local r = total > 0 and free / total or 0
    freeBar:SetWidth(max(1, freeW * r))
    if r <= 0.1 then
        freeBar:SetVertexColor(0.85, 0.22, 0.18)
    elseif r <= 0.25 then
        freeBar:SetVertexColor(0.95, 0.75, 0.2)
    else
        freeBar:SetVertexColor(COL.teal[1], COL.teal[2], COL.teal[3])
    end
end

-- A bolsa escolhida sumiu (desequipada): volta a mostrar todas
function IB.Visible(bag)
    local sel = IB.selected
    if sel and sel ~= 0 and NumSlots(sel) == 0 then IB.selected, sel = nil, nil end
    return not sel or sel == bag
end
