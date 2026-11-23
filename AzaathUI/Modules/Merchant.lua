--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Merchant.lua
    Janela própria de mercador (comprar, recomprar e consertar) no estilo do
    Azaath, com as mesmas texturas do inventário (Media/Inventory):

      * cabeçalho azul escovado: "M E R C A D O R", nome e função do NPC,
        busca e botão de fechar; abas Comprar / Recomprar / Consertar
        (a última só aparece nos mercadores que consertam)
      * Comprar / Recomprar: lista à esquerda (ícone com borda da raridade,
        nome, nível exigido e preço) e painel de detalhes à direita (atributos
        tirados do tooltip do jogo, quantidade, total e botão)
      * Consertar: peças equipadas com barra de durabilidade e custo de cada
        uma (clique conserta só a peça), durabilidade média, custo total,
        "Consertar tudo", banco da guilda e conserto automático ao abrir
      * rodapé com dica e o dinheiro do personagem

    Atalhos: clique direito numa linha compra 1 (ou recompra / conserta) na
    hora; Shift/Ctrl+clique faz o link/provador; roda do mouse na quantidade.
    Arrastar um item das bolsas para a janela vende o item.

    A janela da Blizzard (MerchantFrame) não é escondida com Hide: o OnHide
    dela encerra a interação. Ela fica presa num pai oculto ("aberta" para o
    jogo, invisível e sem clique), como GossipFrame/QuestFrame em Dialog.lua.
    Como o OnShow dela deixa de rodar, as bolsas são abertas aqui (e fechadas
    no fim, se fomos nós que abrimos). MerchantFrame:IsShown() continua
    verdadeiro, então o "Vender lixo" do inventário segue funcionando.

    Comprar, recomprar e consertar (BuyMerchantItem, BuybackItem,
    RepairAllItems, ShowRepairCursor + PickupInventoryItem) não são funções
    protegidas: funcionam sem frames seguros.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("Merchant")

local _G = _G
local ipairs, type, format, floor, min, max, pcall, tostring =
      ipairs, type, string.format, math.floor, math.min, math.max, pcall, tostring
local tconcat = table.concat
local wipe = _G.wipe or function(t) for k in pairs(t) do t[k] = nil end return t end
local API = Azaath.API

--------------------------------------------------------------------------------
-- Medidas (unidades de UI)
--------------------------------------------------------------------------------
local W, H        = 640, 584
local PAD         = 26     -- recuo do conteúdo (a moldura rasgada ocupa ~12)
local HEADER_H    = 100    -- título, NPC e abas
local FOOTER_H    = 56
local DETAIL_W    = 214    -- painel de detalhes / conserto
local COL_GAP     = 16
local LIST_TOP    = HEADER_H + 12
local LIST_W      = W - PAD * 2 - DETAIL_W - COL_GAP
local ROW_H       = 44
local ICON        = 36
local THROTTLE    = 0.1
local MAX_BUNDLES = 20     -- itens vendidos em pacote (x5, x200): até 20 pacotes

local REPAIR_SLOTS = { 1, 3, 5, 6, 7, 8, 9, 10, 16, 17, 18 }

local COL = {
    title    = { 0.88, 0.85, 0.77 },
    sub      = { 0.64, 0.68, 0.71 },
    text     = { 0.90, 0.88, 0.82 },
    dim      = { 0.55, 0.54, 0.50 },
    head     = { 0.44, 0.43, 0.40 },
    tabOn    = { 0.95, 0.90, 0.78 },
    tabOff   = { 0.50, 0.50, 0.48 },
    gold     = { 0.89, 0.78, 0.55 },
    sepHead  = { 0.27, 0.285, 0.28 },
    sepFoot  = { 0.17, 0.157, 0.137 },
    line     = { 0.12, 0.125, 0.13 },
    iconBg   = { 0.05, 0.06, 0.07 },
    btn      = { 0.25, 0.25, 0.245 },
    btnHov   = { 0.32, 0.32, 0.315 },
    btnOff   = { 0.16, 0.16, 0.155 },
    buy      = { 0.34, 0.47, 0.58 },
    buyHov   = { 0.44, 0.60, 0.74 },
    red      = { 0.88, 0.32, 0.26 },
    searchBg = { 0.02, 0.055, 0.09 },
    searchBd = { 0.17, 0.20, 0.24 },
    barBg    = { 0.13, 0.135, 0.14 },
}
local HEX_TEXT = "|cffe6e0d1"
local HEX_RED  = "|cffe05242"
local HEX_DIM  = "|cff8c8a80"

local QUALITY_FALLBACK = {
    [0] = { 0.62, 0.62, 0.62 }, [1] = { 1, 1, 1 }, [2] = { 0.12, 1, 0 },
    [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 },
    [6] = { 0.90, 0.80, 0.50 }, [7] = { 0, 0.8, 1 },
}

local COIN = {
    "Interface\\MoneyFrame\\UI-GoldIcon",
    "Interface\\MoneyFrame\\UI-SilverIcon",
    "Interface\\MoneyFrame\\UI-CopperIcon",
}
local REPAIR_ICON = "Interface\\Icons\\Trade_BlackSmithing"
local QUESTION    = "Interface\\Icons\\INV_Misc_QuestionMark"

local TEX, UITEX   -- Media\Inventory\ e Media\MapUI\ (definidos no OnEnable)

--------------------------------------------------------------------------------
-- Estado
--------------------------------------------------------------------------------
local frame, scroll, child, thumb, emptyText, searchBox, placeholder
local titleText, subText, hintText, moneyText, sellJunkBtn
local headName, headLevel, headPrice
local detail, repairPanel
local tabs = {}
local rows = {}
local entries = {}
local tab = "buy"          -- "buy" | "buyback" | "repair"
local selected             -- chave da linha escolhida (índice do mercador / recompra)
local qty = 1
local filter = ""
local dirty = true
local closingByEvent = false
local openedBags = false
local avgDurability = 100

--------------------------------------------------------------------------------
-- Utilitários
--------------------------------------------------------------------------------
local function SetColor(obj, c, a)
    if obj.SetTextColor then
        obj:SetTextColor(c[1], c[2], c[3], a or 1)
    else
        obj:SetVertexColor(c[1], c[2], c[3], a or 1)
    end
end

local function Solid(parent, layer, c, a)
    local t = parent:CreateTexture(nil, layer)
    t:SetTexture(Azaath.media.blank)
    SetColor(t, c, a)
    return t
end

local function Text(parent, font, size, color, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local ok = pcall(fs.SetFont, fs, font or Azaath.media.font, size, flags or "")
    if not ok or not fs:GetFont() then
        fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags or "")
    end
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetShadowOffset(1, -1)
    if color then SetColor(fs, color) end
    return fs
end

-- SetShown não existe na 3.3.5
local function Shown(obj, on)
    if on then obj:Show() else obj:Hide() end
end

local function NoWrap(fs)
    if fs.SetWordWrap then pcall(fs.SetWordWrap, fs, false) end
end

-- Quatro filetes ao redor de uma região (borda de raridade dos ícones)
local function MakeBorder(owner, region)
    local e = {}
    for i = 1, 4 do e[i] = Solid(owner, "OVERLAY", { 1, 1, 1 }) end
    e[1]:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
    e[1]:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, 0)
    e[1]:SetHeight(1)
    e[2]:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0)
    e[2]:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
    e[2]:SetHeight(1)
    e[3]:SetPoint("TOPLEFT", region, "TOPLEFT", 0, 0)
    e[3]:SetPoint("BOTTOMLEFT", region, "BOTTOMLEFT", 0, 0)
    e[3]:SetWidth(1)
    e[4]:SetPoint("TOPRIGHT", region, "TOPRIGHT", 0, 0)
    e[4]:SetPoint("BOTTOMRIGHT", region, "BOTTOMRIGHT", 0, 0)
    e[4]:SetWidth(1)
    return e
end

local function SetBorderColor(edges, r, g, b, a)
    for i = 1, 4 do edges[i]:SetVertexColor(r, g, b, a or 1) end
end

local function Hex(r, g, b)
    return format("|cff%02x%02x%02x", floor((r or 1) * 255 + 0.5), floor((g or 1) * 255 + 0.5),
        floor((b or 1) * 255 + 0.5))
end

local function Safe(v)
    if v == nil or Azaath.IsSecret(v) then return nil end
    return v
end

local function QualityColor(q)
    local c = q and _G.ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[q]
    if c and c.r then return c.r, c.g, c.b end
    local f = QUALITY_FALLBACK[q or 1] or QUALITY_FALLBACK[1]
    return f[1], f[2], f[3]
end

-- 47530 -> "4[ouro] 75[prata] 30[cobre]" com as moedas como textura
local function Coins(copper, size, hex)
    copper = floor(copper or 0)
    size = size or 12
    hex = hex or HEX_TEXT
    local g, s, c = floor(copper / 10000), floor(copper % 10000 / 100), copper % 100
    local t = {}
    if g > 0 then t[#t + 1] = format("%s%s|r|T%s:%d:%d:2:0|t", hex, Azaath.Thousands(g), COIN[1], size, size) end
    if s > 0 then t[#t + 1] = format("%s%d|r|T%s:%d:%d:2:0|t", hex, s, COIN[2], size, size) end
    if c > 0 or #t == 0 then t[#t + 1] = format("%s%d|r|T%s:%d:%d:2:0|t", hex, c, COIN[3], size, size) end
    return tconcat(t, "  ")
end

local function Money()
    return GetMoney and GetMoney() or 0
end

local function ItemInfo(link)
    if not link then return end
    local ok, _, _, quality, _, reqLevel, class, subclass = pcall(API.GetItemInfo, link)
    if not ok then return end
    return quality, reqLevel, class, subclass
end

local function DurColor(pct)
    if pct <= 0 then return 0.78, 0.22, 0.17 end
    if pct < 25 then return 0.84, 0.36, 0.19 end
    if pct < 50 then return 0.84, 0.65, 0.19 end
    return 0.44, 0.68, 0.29
end

--------------------------------------------------------------------------------
-- Dados do mercador (cliente moderno: C_MerchantFrame; 3.3.5: globais)
--------------------------------------------------------------------------------
local function MerchantInfo(i)
    local CM = _G.C_MerchantFrame
    if CM and CM.GetItemInfo then
        local ok, t = pcall(CM.GetItemInfo, i)
        if ok and type(t) == "table" then
            return t.name, t.texture, t.price or 0, t.stackCount or 1, t.numAvailable or -1,
                   t.isUsable ~= false, t.hasExtendedCost
        end
    end
    if not _G.GetMerchantItemInfo then return end
    if Azaath.IS_MODERN then
        local name, tex, price, stack, avail, _, usable, ext = GetMerchantItemInfo(i)
        return name, tex, price, stack, avail, usable, ext
    end
    -- 3.3.5: name, texture, price, quantity, numAvailable, isUsable, extendedCost
    local name, tex, price, stack, avail, usable, ext = GetMerchantItemInfo(i)
    return name, tex, price, stack, avail, usable, ext
end

-- Moedas que não são dinheiro (honra, arena, fichas e itens)
local function ExtendedCost(index, mult, hex)
    local parts = {}
    if not _G.GetMerchantItemCostInfo then return parts end
    local ok, a, b, c = pcall(GetMerchantItemCostInfo, index)
    if not ok then return parts end
    local count = a
    if not Azaath.IS_MODERN then
        -- 3.3.5: honorPoints, arenaPoints, itemCount
        count = c
        local faction = UnitFactionGroup and UnitFactionGroup("player")
        if a and a > 0 and faction then
            parts[#parts + 1] = format("%s%d|r|TInterface\\PVPFrame\\PVP-Currency-%s:14:14:2:0|t", hex, a * mult, faction)
        end
        if b and b > 0 then
            parts[#parts + 1] = format("%s%d|r|TInterface\\PVPFrame\\PVP-ArenaPoints-Icon:14:14:2:0|t", hex, b * mult)
        end
    end
    for j = 1, (type(count) == "number" and count or 0) do
        local okItem, tex, value = pcall(GetMerchantItemCostItem, index, j)
        if okItem and tex and value and value > 0 then
            parts[#parts + 1] = format("%s%d|r|T%s:13:13:2:0|t", hex, value * mult, tostring(tex))
        end
    end
    return parts
end

local function PriceText(e, mult, hex)
    hex = hex or HEX_TEXT
    local parts = {}
    if e.price and e.price > 0 then parts[1] = Coins(e.price * mult, 12, hex) end
    if e.ext and tab == "buy" then
        for _, p in ipairs(ExtendedCost(e.key, mult, hex)) do parts[#parts + 1] = p end
    end
    if #parts == 0 then return HEX_DIM .. "Grátis|r" end
    return tconcat(parts, "  ")
end

local function Affordable(e, mult)
    return (e.price or 0) * (mult or 1) <= Money()
end

--------------------------------------------------------------------------------
-- Tooltip oculto: atributos do item e custo de conserto por peça
--------------------------------------------------------------------------------
local scanTip
local function ScanTip()
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "AzaathUIMerchantScan", nil, "GameTooltipTemplate")
    end
    scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
    scanTip:ClearLines()
    return scanTip
end

local function ScanLines(kind, key)
    local tip = ScanTip()
    if kind == "buy" then
        pcall(tip.SetMerchantItem, tip, key)
    elseif kind == "buyback" then
        pcall(tip.SetBuybackItem, tip, key)
    else
        pcall(tip.SetInventoryItem, tip, "player", key)
    end
    local lines = {}
    for i = 2, (tip:NumLines() or 0) do
        local L = _G["AzaathUIMerchantScanTextLeft" .. i]
        local R = _G["AzaathUIMerchantScanTextRight" .. i]
        local lt = L and Safe(L:GetText())
        if type(lt) == "string" and lt ~= "" and lt ~= " " then
            local s = Hex(L:GetTextColor()) .. lt .. "|r"
            local rt = R and R:IsShown() and Safe(R:GetText())
            if type(rt) == "string" and rt ~= "" then
                s = s .. "   " .. Hex(R:GetTextColor()) .. rt .. "|r"
            end
            lines[#lines + 1] = s
        end
    end
    tip:Hide()
    return lines
end

local function SlotRepairCost(slot)
    local TI = _G.C_TooltipInfo
    if TI and TI.GetInventoryItem then
        local ok, data = pcall(TI.GetInventoryItem, "player", slot)
        if ok and type(data) == "table" and type(data.repairCost) == "number" then
            return data.repairCost
        end
    end
    local tip = ScanTip()
    local ok, _, _, cost = pcall(tip.SetInventoryItem, tip, "player", slot)
    tip:Hide()
    if ok and type(cost) == "number" then return cost end
    return 0
end

--------------------------------------------------------------------------------
-- Ações
--------------------------------------------------------------------------------
local function MaxQty(e)
    if tab ~= "buy" or not e then return 1 end
    local cap
    if (e.stack or 1) > 1 then
        cap = MAX_BUNDLES
    else
        local ok, m = pcall(GetMerchantItemMaxStack, e.key)
        cap = (ok and type(m) == "number" and m > 0) and m or 1
    end
    if e.avail and e.avail > 0 then cap = min(cap, e.avail) end
    if e.price and e.price > 0 then cap = min(cap, max(1, floor(Money() / e.price))) end
    return max(1, cap)
end

local function Buy(e, n)
    if not e or e.avail == 0 then return end
    n = max(1, n or 1)
    if (e.stack or 1) > 1 then
        -- cada compra leva um pacote inteiro (preço do pacote)
        for _ = 1, n do BuyMerchantItem(e.key) end
    else
        BuyMerchantItem(e.key, n)
    end
end

local function RepairSlot(slot, cost)
    if cost and cost > Money() then
        Azaath:Print("dinheiro insuficiente para o conserto.")
        return
    end
    if not (ShowRepairCursor and PickupInventoryItem) then return end
    ShowRepairCursor()
    pcall(PickupInventoryItem, slot)
    if HideRepairCursor then HideRepairCursor() end
end

local function CanGuildRepair()
    return _G.CanGuildBankRepair and CanGuildBankRepair() and true or false
end

local function RepairAll(useGuild)
    local cost, can = GetRepairAllCost()
    if not can or not cost or cost <= 0 then return false end
    if useGuild then
        local limit = _G.GetGuildBankWithdrawMoney and GetGuildBankWithdrawMoney()
        if CanGuildRepair() and (not limit or limit < 0 or limit >= cost) then
            RepairAllItems(true)
            Azaath:Print("equipamento consertado pelo banco da guilda (%s).", Azaath.FormatMoney(cost))
            return true
        end
        return false
    end
    if Money() < cost then
        Azaath:Print("dinheiro insuficiente para o conserto (%s).", Azaath.FormatMoney(cost))
        return false
    end
    RepairAllItems()
    Azaath:Print("equipamento consertado por %s.", Azaath.FormatMoney(cost))
    return true
end

local function AutoRepair()
    if not M.db.autoRepair or not (CanMerchantRepair and CanMerchantRepair()) then return end
    if M.db.guildRepair ~= false and RepairAll(true) then return end
    RepairAll(false)
end

-- Item no cursor (arrastado das bolsas) é vendido ao soltar na janela
local function SellCursor()
    if CursorHasItem and CursorHasItem() and PickupMerchantItem then
        pcall(PickupMerchantItem, 1)
        return true
    end
end

local function DoAction(e, n)
    if not e then return end
    if tab == "buy" then
        Buy(e, n)
    elseif tab == "buyback" then
        BuybackItem(e.key)
    else
        RepairSlot(e.key, e.cost)
    end
end

--------------------------------------------------------------------------------
-- Coleta das linhas
--------------------------------------------------------------------------------
local function Matches(name)
    if filter == "" then return true end
    return type(name) == "string" and name:lower():find(filter, 1, true) ~= nil
end

local function CollectBuy()
    local n = GetMerchantNumItems and GetMerchantNumItems() or 0
    for i = 1, n do
        local name, tex, price, stack, avail, usable, ext = MerchantInfo(i)
        if name and Matches(name) then
            local link = GetMerchantItemLink and GetMerchantItemLink(i)
            local quality, req, class, subclass = ItemInfo(link)
            entries[#entries + 1] = {
                key = i, name = name, tex = tex, price = price or 0, stack = stack or 1,
                avail = avail or -1, usable = usable and true or false, ext = ext and true or false,
                link = link, quality = quality, req = req, class = class, subclass = subclass,
            }
        end
    end
end

local function CollectBuyback()
    local n = GetNumBuybackItems and GetNumBuybackItems() or 0
    for i = 1, n do
        local name, tex, price, stack, _, usable = GetBuybackItemInfo(i)
        if name and Matches(name) then
            local link = GetBuybackItemLink and GetBuybackItemLink(i)
            local quality, req, class, subclass = ItemInfo(link)
            entries[#entries + 1] = {
                key = i, name = name, tex = tex, price = price or 0, stack = stack or 1,
                avail = -1, usable = usable and true or false, link = link,
                quality = quality, req = req, class = class, subclass = subclass,
            }
        end
    end
end

local function CollectRepair()
    local sum, count = 0, 0
    for _, slot in ipairs(REPAIR_SLOTS) do
        local cur, mx = GetInventoryItemDurability(slot)
        cur, mx = Safe(cur), Safe(mx)
        if cur and mx and mx > 0 then
            local pct = cur / mx * 100
            sum, count = sum + pct, count + 1
            local link = GetInventoryItemLink("player", slot)
            local name = link and (API.GetItemInfo(link) or link:match("%[(.-)%]"))
            if name and Matches(name) then
                local quality = ItemInfo(link)
                entries[#entries + 1] = {
                    key = slot, name = name, tex = GetInventoryItemTexture("player", slot),
                    link = link, quality = quality, usable = true, stack = 1,
                    cur = cur, max = mx, pct = pct,
                    cost = (cur < mx) and SlotRepairCost(slot) or 0,
                }
            end
        end
    end
    avgDurability = count > 0 and (sum / count) or 100
end

--------------------------------------------------------------------------------
-- Linhas da lista
--------------------------------------------------------------------------------
local Refresh -- definida mais abaixo

-- Comparação com o equipado (ShoppingTooltip1/2): ocupa meia tela. Nas linhas
-- do mercador só aparece com Shift (comprar/recomprar); no conserto, nunca
-- (a peça já é a equipada). O jogo reabre a comparação sozinho (opção
-- "sempre comparar" e troca de modificador), então ela é fechada no OnShow.
local hoverRow
local function CompareAllowed()
    return tab ~= "repair" and IsShiftKeyDown()
end

local function HideCompare()
    for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3" }) do
        local t = _G[name]
        if t and t:IsShown() then t:Hide() end
    end
end

local function HookCompare()
    for _, name in ipairs({ "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3" }) do
        local t = _G[name]
        if t and not t.azaathMerchantHooked then
            t.azaathMerchantHooked = true
            t:HookScript("OnShow", function(self)
                if hoverRow and hoverRow:IsVisible() and GameTooltip:IsOwned(hoverRow)
                   and not CompareAllowed() then
                    self:Hide()
                end
            end)
        end
    end
end

local function Row_OnEnter(self)
    self.hl:SetAlpha(0.05)
    hoverRow = self
    HookCompare()
    local e = self.entry
    if not e then return end
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip:SetPoint("TOPRIGHT", self, "TOPLEFT", -(PAD + 4), 0)
    if tab == "buy" then
        GameTooltip:SetMerchantItem(e.key)
    elseif tab == "buyback" then
        GameTooltip:SetBuybackItem(e.key)
    else
        GameTooltip:SetInventoryItem("player", e.key)
    end
    GameTooltip:Show()
    if not CompareAllowed() then HideCompare() end
end

local function Row_OnLeave(self)
    self.hl:SetAlpha(0)
    if hoverRow == self then hoverRow = nil end
    GameTooltip:Hide()
end

local function Row_OnClick(self, button)
    local e = self.entry
    if not e then return end
    if SellCursor() then return end
    if e.link and (IsShiftKeyDown() or IsControlKeyDown()) and HandleModifiedItemClick then
        HandleModifiedItemClick(e.link)
        return
    end
    if button == "RightButton" then
        DoAction(e, 1)
        return
    end
    if selected ~= e.key then
        selected, qty = e.key, 1
        Refresh()
    end
end

local function GetRow(i)
    local row = rows[i]
    if row then return row end
    local media = Azaath.media

    row = CreateFrame("Button", nil, child)
    row:SetHeight(ROW_H)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    row.hl = Solid(row, "BACKGROUND", { 1, 1, 1 })
    row.hl:SetAllPoints(row)
    row.hl:SetAlpha(0)

    row.selBg = Solid(row, "BACKGROUND", { 0.42, 0.55, 0.66 }, 0.14)
    row.selBg:SetAllPoints(row)
    row.selBar = Solid(row, "BORDER", COL.gold)
    row.selBar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.selBar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.selBar:SetWidth(2)

    row.line = Solid(row, "BORDER", COL.line)
    row.line:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.line:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, 0)
    row.line:SetHeight(1)

    row.iconBg = Solid(row, "BORDER", COL.iconBg)
    row.iconBg:SetWidth(ICON)
    row.iconBg:SetHeight(ICON)
    row.iconBg:SetPoint("LEFT", row, "LEFT", 6, 0)
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetPoint("TOPLEFT", row.iconBg, "TOPLEFT", 2, -2)
    row.icon:SetPoint("BOTTOMRIGHT", row.iconBg, "BOTTOMRIGHT", -2, 2)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.border = MakeBorder(row, row.iconBg)

    row.count = Text(row, media.fontBold, 11, COL.text, "OUTLINE")
    row.count:SetPoint("BOTTOMRIGHT", row.iconBg, "BOTTOMRIGHT", -2, 2)

    row.name = Text(row, media.font, 14, COL.text)
    row.name:SetJustifyH("LEFT")
    row.name:SetHeight(16)
    NoWrap(row.name)

    row.sub = Text(row, media.font, 11, COL.dim)
    row.sub:SetJustifyH("LEFT")
    row.sub:SetPoint("TOPLEFT", row.name, "BOTTOMLEFT", 0, -1)
    NoWrap(row.sub)

    row.level = Text(row, media.fontBold, 13, COL.dim)
    row.level:SetJustifyH("CENTER")
    row.level:SetWidth(40)
    row.level:SetPoint("RIGHT", row, "RIGHT", -110, 0)

    row.price = Text(row, media.fontBold, 13, COL.text)
    row.price:SetJustifyH("RIGHT")
    row.price:SetWidth(104)
    row.price:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    NoWrap(row.price)

    -- Conserto: barra de durabilidade no lugar do nível
    row.barBg = Solid(row, "ARTWORK", COL.barBg)
    row.barBg:SetWidth(90)
    row.barBg:SetHeight(5)
    row.barBg:SetPoint("RIGHT", row, "RIGHT", -116, 5)
    row.bar = Solid(row, "OVERLAY", { 1, 1, 1 })
    row.bar:SetPoint("TOPLEFT", row.barBg, "TOPLEFT", 0, 0)
    row.bar:SetPoint("BOTTOMLEFT", row.barBg, "BOTTOMLEFT", 0, 0)
    row.durText = Text(row, media.font, 11, COL.dim)
    row.durText:SetPoint("TOPLEFT", row.barBg, "BOTTOMLEFT", 0, -3)

    row:SetScript("OnEnter", Row_OnEnter)
    row:SetScript("OnLeave", Row_OnLeave)
    row:SetScript("OnClick", Row_OnClick)
    row:SetScript("OnReceiveDrag", SellCursor)

    rows[i] = row
    return row
end

local function FillRow(row, e)
    row.entry = e
    local repair = (tab == "repair")
    local r, g, b = QualityColor(e.quality)

    row.icon:SetTexture(e.tex or QUESTION)
    if e.usable then row.icon:SetVertexColor(1, 1, 1) else row.icon:SetVertexColor(1, 0.35, 0.35) end
    SetBorderColor(row.border, r, g, b, 0.85)
    row.count:SetText((e.stack or 1) > 1 and e.stack or "")

    local sub = ""
    if tab == "buy" and e.avail and e.avail >= 0 then
        sub = (e.avail == 0) and (HEX_RED .. "Esgotado|r") or format("Restam %d", e.avail)
    elseif repair and e.cur == 0 then
        sub = HEX_RED .. "Quebrado · sem atributos|r"
    end
    row.sub:SetText(sub)

    row.name:ClearAllPoints()
    row.name:SetPoint("LEFT", row.iconBg, "RIGHT", 10, (sub ~= "") and 7 or 0)
    row.name:SetPoint("RIGHT", row, "RIGHT", repair and -214 or -156, (sub ~= "") and 7 or 0)
    row.name:SetText(e.name)
    row.name:SetTextColor(r, g, b)

    if repair then
        row.level:Hide()
        row.barBg:Show()
        row.durText:Show()
        local pct = max(0, min(100, e.pct or 0))
        if pct > 0 then
            row.bar:SetWidth(max(1, 90 * pct / 100))
            row.bar:SetVertexColor(DurColor(pct))
            row.bar:Show()
        else
            row.bar:Hide()
        end
        row.durText:SetText(format("%d / %d", e.cur, e.max))
        if e.cost and e.cost > 0 then
            row.price:SetText(Coins(e.cost, 12, (e.cost <= Money()) and HEX_TEXT or HEX_RED))
        else
            row.price:SetText(HEX_DIM .. "Inteiro|r")
        end
    else
        row.barBg:Hide()
        row.bar:Hide()
        row.durText:Hide()
        row.level:Show()
        local req = e.req and e.req > 1 and e.req
        row.level:SetText(req or "")
        if req and req > (UnitLevel("player") or 0) then SetColor(row.level, COL.red) else SetColor(row.level, COL.dim) end
        row.price:SetText(PriceText(e, 1, Affordable(e, 1) and HEX_TEXT or HEX_RED))
    end

    local isSel = (not repair) and e.key == selected
    Shown(row.selBg, isSel)
    Shown(row.selBar, isSel)
end

--------------------------------------------------------------------------------
-- Botões
--------------------------------------------------------------------------------
local function Button_Paint(b, hover)
    if not b.enabled then
        SetColor(b.bg, COL.btnOff)
        b.text:SetTextColor(0.45, 0.45, 0.44)
    else
        SetColor(b.bg, hover and b.colHov or b.col)
        b.text:SetTextColor(0.96, 0.96, 0.95)
    end
end

local function SetButtonEnabled(b, on)
    b.enabled = on and true or false
    Button_Paint(b, b.hover)
end

local function MakeButton(parent, label, height, col, colHov, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetHeight(height)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetTexture(TEX .. "ButtonWide")
    b.bg:SetAllPoints(b)
    b.text = Text(b, Azaath.media.fontTitleB, size or 12, nil)
    b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b.text:SetText(label)
    b.col, b.colHov = col or COL.btn, colHov or COL.btnHov
    b.enabled = true
    b:SetScript("OnEnter", function(self) self.hover = true; Button_Paint(self, true) end)
    b:SetScript("OnLeave", function(self) self.hover = false; Button_Paint(self, false); GameTooltip:Hide() end)
    Button_Paint(b, false)
    return b
end

-- Botãozinho de ícone (Media/MapUI): fechar, menos, mais
local function IconButton(parent, texName, size)
    local b = CreateFrame("Button", nil, parent)
    b:SetWidth(size)
    b:SetHeight(size)
    b.tex = b:CreateTexture(nil, "ARTWORK")
    b.tex:SetTexture(UITEX .. texName)
    b.tex:SetAllPoints(b)
    b.tex:SetVertexColor(0.62, 0.64, 0.64)
    b:SetScript("OnEnter", function(self) self.tex:SetVertexColor(0.95, 0.90, 0.78) end)
    b:SetScript("OnLeave", function(self) self.tex:SetVertexColor(0.62, 0.64, 0.64) end)
    return b
end

--------------------------------------------------------------------------------
-- Venda de lixo
--------------------------------------------------------------------------------
local function CollectJunk()
    local list, earned = {}, 0
    for bag = 0, 4 do
        local numSlots = (API.GetContainerNumSlots and API.GetContainerNumSlots(bag)) or 0
        for slot = 1, numSlots do
            local link = API.GetContainerItemLink and API.GetContainerItemLink(bag, slot)
            if link then
                local _, _, quality, _, _, _, _, _, _, _, price = API.GetItemInfo(link)
                local _, count, locked = API.GetContainerItemInfo(bag, slot)
                local IL = Azaath.InventoryLock -- item trancado nunca entra no "Vender lixo"
                if (quality or 1) == 0 and not locked and not (IL and IL.IsLocked(bag, slot)) then
                    local p = type(price) == "number" and price or 0
                    local c = type(count) == "number" and count or 1
                    local value = p * c
                    list[#list + 1] = { bag = bag, slot = slot, value = value }
                    earned = earned + value
                end
            end
        end
    end
    return list, earned
end

local function SellJunk()
    local list, earned = CollectJunk()
    for _, e in ipairs(list) do
        if API.UseContainerItem then
            API.UseContainerItem(e.bag, e.slot)
        end
    end
    if earned > 0 then
        Azaath:Print("lixo vendido por %s.", Azaath.FormatMoney(earned))
    end
end

local function UpdateSellJunkButton()
    if not sellJunkBtn then return end
    local list = CollectJunk()
    SetButtonEnabled(sellJunkBtn, #list > 0)
end

--------------------------------------------------------------------------------
-- Painel de detalhes (comprar / recomprar)
--------------------------------------------------------------------------------
local function BuildDetail()
    local media = Azaath.media
    local d = CreateFrame("Frame", nil, frame)
    d:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -LIST_TOP)
    d:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, FOOTER_H + 12)
    d:SetWidth(DETAIL_W)

    d.iconBg = Solid(d, "BORDER", COL.iconBg)
    d.iconBg:SetWidth(52)
    d.iconBg:SetHeight(52)
    d.iconBg:SetPoint("TOPLEFT", d, "TOPLEFT", 0, 0)
    d.icon = d:CreateTexture(nil, "ARTWORK")
    d.icon:SetPoint("TOPLEFT", d.iconBg, "TOPLEFT", 2, -2)
    d.icon:SetPoint("BOTTOMRIGHT", d.iconBg, "BOTTOMRIGHT", -2, 2)
    d.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    d.border = MakeBorder(d, d.iconBg)

    d.name = Text(d, media.fontBold, 15, COL.text)
    d.name:SetJustifyH("LEFT")
    d.name:SetJustifyV("TOP")
    d.name:SetPoint("TOPLEFT", d.iconBg, "TOPRIGHT", 10, -1)
    d.name:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, -1)
    d.name:SetHeight(36)

    d.kind = Text(d, media.font, 12, COL.dim)
    d.kind:SetJustifyH("LEFT")
    d.kind:SetPoint("BOTTOMLEFT", d.iconBg, "BOTTOMRIGHT", 10, 1)
    d.kind:SetPoint("RIGHT", d, "RIGHT", 0, 0)
    NoWrap(d.kind)

    local sep = Solid(d, "BORDER", COL.sepHead)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -64)
    sep:SetPoint("TOPRIGHT", d, "TOPRIGHT", 0, -64)

    d.stats = Text(d, media.font, 13, COL.text)
    d.stats:SetJustifyH("LEFT")
    d.stats:SetJustifyV("TOP")
    d.stats:SetPoint("TOPLEFT", d, "TOPLEFT", 0, -74)
    d.stats:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 0, 112)
    if d.stats.SetSpacing then d.stats:SetSpacing(3) end

    -- quantidade
    d.qtyRow = CreateFrame("Frame", nil, d)
    d.qtyRow:SetHeight(22)
    d.qtyRow:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, 74)
    d.qtyRow:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 0, 74)
    d.qtyRow:EnableMouseWheel(true)
    local qlabel = Text(d.qtyRow, media.font, 12, COL.dim)
    qlabel:SetPoint("LEFT", d.qtyRow, "LEFT", 0, 0)
    qlabel:SetText("Quantidade")
    d.plus = IconButton(d.qtyRow, "Plus", 16)
    d.plus:SetPoint("RIGHT", d.qtyRow, "RIGHT", 0, 0)
    d.qtyText = Text(d.qtyRow, media.fontBold, 14, COL.tabOn)
    d.qtyText:SetJustifyH("CENTER")
    d.qtyText:SetWidth(64)
    d.qtyText:SetPoint("RIGHT", d.plus, "LEFT", -4, 0)
    d.minus = IconButton(d.qtyRow, "Minus", 16)
    d.minus:SetPoint("RIGHT", d.qtyText, "LEFT", -4, 0)
    local function Step(delta)
        local e = d.entry
        if not e then return end
        local top = MaxQty(e)
        if IsShiftKeyDown() then
            qty = (delta > 0) and top or 1
        else
            qty = max(1, min(top, qty + delta))
        end
        Refresh()
    end
    d.plus:SetScript("OnClick", function() Step(1) end)
    d.minus:SetScript("OnClick", function() Step(-1) end)
    d.qtyRow:SetScript("OnMouseWheel", function(_, delta) Step(delta > 0 and 1 or -1) end)

    -- total
    local tlabel = Text(d, media.font, 12, COL.dim)
    tlabel:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, 46)
    tlabel:SetText("Total")
    d.total = Text(d, media.fontBold, 14, COL.text)
    d.total:SetJustifyH("RIGHT")
    d.total:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 0, 46)

    d.action = MakeButton(d, Azaath.Tracked("Comprar"), 32, COL.buy, COL.buyHov, 12)
    d.action:SetPoint("BOTTOMLEFT", d, "BOTTOMLEFT", 0, 0)
    d.action:SetPoint("BOTTOMRIGHT", d, "BOTTOMRIGHT", 0, 0)
    d.action:SetScript("OnClick", function(self)
        if not self.enabled or not d.entry then return end
        DoAction(d.entry, qty)
        qty = 1
    end)

    d.empty = Text(d, media.font, 13, COL.dim)
    d.empty:SetPoint("CENTER", d, "CENTER", 0, 40)
    d.empty:SetText("Escolha um item na lista.")

    d.parts = { d.iconBg, d.icon, d.name, d.kind, sep, d.stats, d.qtyRow, tlabel, d.total, d.action }
    for i = 1, 4 do d.parts[#d.parts + 1] = d.border[i] end
    return d
end

local function FillDetail(e)
    local d = detail
    d.entry = e
    for _, p in ipairs(d.parts) do Shown(p, e ~= nil) end
    Shown(d.empty, e == nil)
    if not e then return end

    local r, g, b = QualityColor(e.quality)
    d.icon:SetTexture(e.tex or QUESTION)
    if e.usable then d.icon:SetVertexColor(1, 1, 1) else d.icon:SetVertexColor(1, 0.35, 0.35) end
    SetBorderColor(d.border, r, g, b, 0.9)
    d.name:SetText(e.name)
    d.name:SetTextColor(r, g, b)

    local kind = e.class or ""
    if e.subclass and e.subclass ~= "" and e.subclass ~= e.class then
        kind = (kind ~= "") and (kind .. " · " .. e.subclass) or e.subclass
    end
    if (e.stack or 1) > 1 then
        kind = (kind ~= "") and format("%s · pacote com %d", kind, e.stack) or format("Pacote com %d", e.stack)
    end
    d.kind:SetText(kind)

    d.stats:SetText(tconcat(ScanLines(tab, e.key), "\n"))

    local top = MaxQty(e)
    qty = max(1, min(qty, top))
    Shown(d.qtyRow, tab == "buy" and top > 1)
    if (e.stack or 1) > 1 then
        d.qtyText:SetText(format("%d  (%d)", qty, qty * e.stack))
    else
        d.qtyText:SetText(qty)
    end

    local mult = (tab == "buy") and qty or 1
    local ok = Affordable(e, mult)
    d.total:SetText(PriceText(e, mult, ok and HEX_TEXT or HEX_RED))

    d.action.text:SetText(Azaath.Tracked(tab == "buy" and "Comprar" or "Recomprar"))
    SetButtonEnabled(d.action, ok and e.avail ~= 0)
end

--------------------------------------------------------------------------------
-- Painel de conserto
--------------------------------------------------------------------------------
local function UpdateCheck(cb)
    Shown(cb.check, M.db.autoRepair and true or false)
end

local function BuildRepairPanel()
    local media = Azaath.media
    local p = CreateFrame("Frame", nil, frame)
    p:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -PAD, -LIST_TOP)
    p:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, FOOTER_H + 12)
    p:SetWidth(DETAIL_W)

    local iconBg = Solid(p, "BORDER", COL.iconBg)
    iconBg:SetWidth(48)
    iconBg:SetHeight(48)
    iconBg:SetPoint("TOP", p, "TOP", 0, -4)
    local icon = p:CreateTexture(nil, "ARTWORK")
    icon:SetTexture(REPAIR_ICON)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    icon:SetPoint("TOPLEFT", iconBg, "TOPLEFT", 2, -2)
    icon:SetPoint("BOTTOMRIGHT", iconBg, "BOTTOMRIGHT", -2, 2)
    SetBorderColor(MakeBorder(p, iconBg), COL.gold[1], COL.gold[2], COL.gold[3], 0.9)

    local label = Text(p, media.font, 12, COL.dim)
    label:SetPoint("TOP", iconBg, "BOTTOM", 0, -14)
    label:SetText("Durabilidade média")

    p.avg = Text(p, media.fontTitleB, 28, COL.text)
    p.avg:SetPoint("TOP", label, "BOTTOM", 0, -4)

    p.barBg = Solid(p, "ARTWORK", COL.barBg)
    p.barBg:SetHeight(5)
    p.barBg:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -136)
    p.barBg:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -136)
    p.bar = Solid(p, "OVERLAY", { 1, 1, 1 })
    p.bar:SetPoint("TOPLEFT", p.barBg, "TOPLEFT", 0, 0)
    p.bar:SetPoint("BOTTOMLEFT", p.barBg, "BOTTOMLEFT", 0, 0)

    local costLabel = Text(p, media.font, 12, COL.dim)
    costLabel:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -158)
    costLabel:SetText("Custo total")
    p.cost = Text(p, media.fontBold, 14, COL.text)
    p.cost:SetJustifyH("RIGHT")
    p.cost:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -157)

    p.all = MakeButton(p, Azaath.Tracked("Consertar tudo"), 32, COL.buy, COL.buyHov, 11)
    p.all:SetPoint("TOPLEFT", p, "TOPLEFT", 0, -184)
    p.all:SetPoint("TOPRIGHT", p, "TOPRIGHT", 0, -184)
    p.all:SetScript("OnClick", function(self)
        if self.enabled then RepairAll(false) end
    end)

    p.guild = MakeButton(p, "Pagar com o banco da guilda", 24, COL.btn, COL.btnHov, 11)
    pcall(p.guild.text.SetFont, p.guild.text, media.fontBold, 12, "")
    p.guild:SetPoint("TOPLEFT", p.all, "BOTTOMLEFT", 0, -8)
    p.guild:SetPoint("TOPRIGHT", p.all, "BOTTOMRIGHT", 0, -8)
    p.guild:SetScript("OnClick", function(self)
        if self.enabled and not RepairAll(true) then
            Azaath:Print("o banco da guilda não cobre este conserto.")
        end
    end)

    local hint = Text(p, media.font, 11, COL.dim)
    hint:SetJustifyH("LEFT")
    hint:SetJustifyV("TOP")
    hint:SetPoint("TOPLEFT", p.guild, "BOTTOMLEFT", 0, -12)
    hint:SetPoint("TOPRIGHT", p.guild, "BOTTOMRIGHT", 0, -12)
    hint:SetText("Clique numa peça da lista para consertar só ela.")

    -- consertar sozinho ao abrir um mercador
    local cb = CreateFrame("Button", nil, p)
    cb:SetHeight(16)
    cb:SetPoint("BOTTOMLEFT", p, "BOTTOMLEFT", 0, 0)
    cb:SetPoint("BOTTOMRIGHT", p, "BOTTOMRIGHT", 0, 0)
    local box = Solid(cb, "BORDER", { 0.32, 0.33, 0.33 })
    box:SetWidth(14)
    box:SetHeight(14)
    box:SetPoint("LEFT", cb, "LEFT", 0, 0)
    local inner = Solid(cb, "ARTWORK", COL.iconBg)
    inner:SetPoint("TOPLEFT", box, "TOPLEFT", 1, -1)
    inner:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    cb.check = cb:CreateTexture(nil, "OVERLAY")
    cb.check:SetTexture(UITEX .. "Check")
    cb.check:SetVertexColor(COL.gold[1], COL.gold[2], COL.gold[3])
    cb.check:SetWidth(14)
    cb.check:SetHeight(14)
    cb.check:SetPoint("CENTER", box, "CENTER", 0, 0)
    local cbText = Text(cb, media.font, 12, COL.dim)
    cbText:SetPoint("LEFT", box, "RIGHT", 7, 0)
    cbText:SetText("Consertar sozinho ao abrir")
    cb:SetScript("OnClick", function(self)
        M.db.autoRepair = not M.db.autoRepair
        UpdateCheck(self)
        if M.db.autoRepair then AutoRepair() end
    end)
    cb:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Conserto automático")
        GameTooltip:AddLine("Ao abrir um mercador que conserta, todo o equipamento é consertado. "
            .. "Usa o banco da guilda quando ele cobre o valor.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", function() GameTooltip:Hide() end)
    p.check = cb
    UpdateCheck(cb)
    return p
end

local function FillRepairPanel()
    local p = repairPanel
    local pct = max(0, min(100, avgDurability))
    p.avg:SetText(format("%d%%", floor(pct + 0.5)))
    p.avg:SetTextColor(DurColor(pct))
    if pct > 0 then
        p.bar:SetWidth(max(1, DETAIL_W * pct / 100))
        p.bar:SetVertexColor(DurColor(pct))
        p.bar:Show()
    else
        p.bar:Hide()
    end
    local cost, can = GetRepairAllCost()
    cost = (can and cost) or 0
    if cost > 0 then
        p.cost:SetText(Coins(cost, 13, cost <= Money() and HEX_TEXT or HEX_RED))
    else
        p.cost:SetText(HEX_DIM .. "Nada a consertar|r")
    end
    SetButtonEnabled(p.all, cost > 0 and cost <= Money())
    Shown(p.guild, CanGuildRepair())
    SetButtonEnabled(p.guild, cost > 0)
    UpdateCheck(p.check)
end

--------------------------------------------------------------------------------
-- Abas, rolagem e atualização
--------------------------------------------------------------------------------
local TABS = {
    { key = "buy",     label = "Comprar" },
    { key = "buyback", label = "Recomprar" },
    { key = "repair",  label = "Consertar" },
}
local HINTS = {
    buy     = "Clique direito compra 1   ·   Shift+clique: link   ·   Arraste um item aqui para vender",
    buyback = "Itens vendidos neste mercador   ·   Clique direito recompra",
    repair  = "Clique numa peça para consertá-la",
}
local HEADS = {
    buy     = { "Item", "Nível", "Preço" },
    buyback = { "Item", "Nível", "Preço" },
    repair  = { "Peça", "Durabilidade", "Custo" },
}

local function CanRepairHere()
    return CanMerchantRepair and CanMerchantRepair() and true or false
end

local function UpdateTabs()
    for _, t in ipairs(tabs) do
        local on = (t.key == tab)
        SetColor(t.text, on and COL.tabOn or COL.tabOff)
        Shown(t.under, on)
        if t.key == "repair" then Shown(t, CanRepairHere()) end
    end
end

local function SelectTab(key)
    if key == "repair" and not CanRepairHere() then key = "buy" end
    if tab ~= key then
        tab, selected, qty = key, nil, 1
        scroll:SetVerticalScroll(0)
    end
    Refresh()
end

local function UpdateThumb()
    local range = scroll:GetVerticalScrollRange() or 0
    if range <= 0 then
        thumb:Hide()
        return
    end
    local h = scroll:GetHeight()
    local th = max(24, h * h / (h + range))
    local pos = (scroll:GetVerticalScroll() / range) * (h - th)
    thumb:SetHeight(th)
    thumb:ClearAllPoints()
    thumb:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 6, -pos)
    thumb:Show()
end

local function UpdateMoney()
    if moneyText then moneyText:SetText(Coins(Money(), 14)) end
end

function Refresh()
    dirty = false
    if not frame or not frame:IsShown() then return end
    if tab == "repair" and not CanRepairHere() then tab = "buy" end

    wipe(entries)
    if tab == "buy" then
        CollectBuy()
    elseif tab == "buyback" then
        CollectBuyback()
    else
        CollectRepair()
    end

    -- seleção: mantém a escolhida, senão a primeira da lista
    local selEntry
    if tab ~= "repair" then
        for _, e in ipairs(entries) do
            if e.key == selected then selEntry = e break end
        end
        if not selEntry and entries[1] then
            selEntry = entries[1]
            selected, qty = selEntry.key, 1
        end
    end

    for i, e in ipairs(entries) do
        local row = GetRow(i)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -(i - 1) * ROW_H)
        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, -(i - 1) * ROW_H)
        FillRow(row, e)
        row:Show()
        if row.hl:GetAlpha() > 0 and GameTooltip:IsOwned(row) then Row_OnEnter(row) end
    end
    for i = #entries + 1, #rows do
        rows[i].entry = nil
        rows[i]:Hide()
    end
    child:SetHeight(max(1, #entries * ROW_H))

    if #entries == 0 then
        local msg
        if filter ~= "" then msg = "Nenhum item com esse nome."
        elseif tab == "buyback" then msg = "Nada para recomprar."
        elseif tab == "repair" then msg = "Nenhuma peça com durabilidade."
        else msg = "Este mercador não tem itens." end
        emptyText:SetText(msg)
        emptyText:Show()
    else
        emptyText:Hide()
    end

    local h = HEADS[tab]
    headName:SetText(Azaath.Upper(h[1]))
    headLevel:SetText(Azaath.Upper(h[2]))
    headPrice:SetText(Azaath.Upper(h[3]))
    headLevel:ClearAllPoints()
    if tab == "repair" then
        headLevel:SetPoint("BOTTOMLEFT", scroll, "TOPRIGHT", -206, 5) -- início da barra
    else
        headLevel:SetPoint("BOTTOM", scroll, "TOPRIGHT", -130, 5)     -- centro da coluna de nível
    end

    if tab == "repair" then
        detail:Hide()
        repairPanel:Show()
        FillRepairPanel()
    else
        repairPanel:Hide()
        detail:Show()
        FillDetail(selEntry)
    end

    hintText:SetText(HINTS[tab])
    UpdateTabs()
    UpdateMoney()
    UpdateSellJunkButton()
    UpdateThumb()
end

local function MarkDirty() dirty = true end

--------------------------------------------------------------------------------
-- Janela
--------------------------------------------------------------------------------
local function NPCSubtitle()
    local ok, result = pcall(function()
        if not UnitExists("npc") or UnitIsPlayer("npc") then return nil end
        local TI = _G.C_TooltipInfo
        if TI and TI.GetUnit then
            local ok2, data = pcall(TI.GetUnit, "npc")
            if ok2 and type(data) == "table" and type(data.lines) == "table" then
                for i = 2, math.min(5, #data.lines) do
                    local line = data.lines[i]
                    if line then
                        if line.args and _G.TooltipUtil and TooltipUtil.SurfaceArgs then
                            pcall(TooltipUtil.SurfaceArgs, line)
                        end
                        local t = line.leftText or (line.args and line.args[2] and line.args[2].stringVal)
                        if type(t) == "string" and t ~= "" and not Azaath.IsSecret(t) then
                            local low = t:lower()
                            if not t:find("%d") and not t:find("%?%?") and not low:find("nivel") and not low:find("nível") and not low:find("level") then
                                return t
                            end
                        end
                    end
                end
            end
            return nil
        end

        local tip = ScanTip()
        local sb = tip and (tip.StatusBar or _G["AzaathUIMerchantScanStatusBar"])
        if sb then sb:SetScript("OnValueChanged", nil) end
        tip:SetUnit("npc")
        local line = _G["AzaathUIMerchantScanTextLeft2"]
        local text = line and Safe(line:GetText())
        tip:Hide()
        if type(text) ~= "string" or text == "" then return nil end
        if text:find("%d") or text:find("%?%?") then return nil end
        return text
    end)
    return ok and result or nil
end

local function SetHeader()
    local name = Safe(UnitName("npc"))
    local role = NPCSubtitle()
    if name and role then
        subText:SetText(name .. "  ·  " .. role)
    else
        subText:SetText(name or "")
    end
end

local function Reposition()
    if not frame then return end
    local baseScale = (M.db.scale and M.db.scale > 0) and M.db.scale or 1
    frame:SetScale(baseScale * 0.80)
    frame:ClearAllPoints()
    frame:SetPoint("LEFT", UIParent, "LEFT", 28, 20)
end

local function SyncInventoryLayout()
    local invMod = Azaath:GetModule("Inventory")
    if invMod and invMod.Reposition then
        invMod:Reposition()
    end
end

local function HookInventory()
    local inv = _G.AzaathUIInventory
    if not inv or inv.azaathMerchantHooked then return end
    inv.azaathMerchantHooked = true
    local function follow() if frame and frame:IsShown() then Reposition() end end
    inv:HookScript("OnShow", follow)
    inv:HookScript("OnHide", follow)
end

local function BuildPanelTextures()
    local header = frame:CreateTexture(nil, "BACKGROUND")
    header:SetTexture(TEX .. "Header")
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_H)

    local footer = frame:CreateTexture(nil, "BACKGROUND")
    footer:SetTexture(TEX .. "Footer")
    footer:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    footer:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    footer:SetHeight(FOOTER_H)

    local body = frame:CreateTexture(nil, "BACKGROUND")
    body:SetTexture(TEX .. "Body")
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    body:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    body:SetPoint("BOTTOMLEFT", footer, "TOPLEFT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", footer, "TOPRIGHT", 0, 0)

    local sep = Solid(frame, "BORDER", COL.sepHead)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -HEADER_H)
    sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -HEADER_H)

    local foot = Solid(frame, "BORDER", COL.sepFoot)
    foot:SetHeight(1)
    foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD - 10, FOOTER_H)
    foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAD - 10), FOOTER_H)

    -- filete vertical entre a lista e o painel da direita
    local div = Solid(frame, "BORDER", COL.line)
    div:SetWidth(1)
    div:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -(PAD + DETAIL_W + COL_GAP / 2), -LIST_TOP)
    div:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAD + DETAIL_W + COL_GAP / 2), FOOTER_H + 12)
end

local function BuildHeader()
    local media = Azaath.media
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_H)
    header:EnableMouse(true)

    titleText = Text(header, media.fontCinzel, 19, COL.title)
    titleText:SetPoint("TOPLEFT", header, "TOPLEFT", PAD + 2, -20)
    titleText:SetText(Azaath.Tracked("Mercador"))

    subText = Text(header, media.fontBold, 13, COL.sub)
    subText:SetJustifyH("LEFT")
    subText:SetPoint("TOPLEFT", titleText, "BOTTOMLEFT", 0, -5)
    subText:SetPoint("RIGHT", header, "RIGHT", -PAD - 210, 0)
    NoWrap(subText)

    -- fechar
    local close = IconButton(header, "Close", 18)
    close:SetPoint("TOPRIGHT", header, "TOPRIGHT", -PAD + 2, -22)
    close:SetScript("OnClick", function() frame:Hide() end)

    -- busca
    searchBox = CreateFrame("EditBox", "AzaathUIMerchantSearch", header)
    searchBox:SetWidth(176)
    searchBox:SetHeight(22)
    searchBox:SetAutoFocus(false)
    searchBox:SetFont(media.font, 13, "")
    searchBox:SetTextColor(0.90, 0.90, 0.88)
    searchBox:SetTextInsets(24, 8, 0, 0)
    Azaath.SetBackdrop(searchBox, { bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    searchBox:SetBackdropColor(COL.searchBg[1], COL.searchBg[2], COL.searchBg[3], 0.96)
    searchBox:SetBackdropBorderColor(COL.searchBd[1], COL.searchBd[2], COL.searchBd[3], 1)
    searchBox:SetPoint("RIGHT", close, "LEFT", -12, 0)

    local glass = searchBox:CreateTexture(nil, "OVERLAY")
    glass:SetTexture(UITEX .. "Search")
    glass:SetVertexColor(0.46, 0.49, 0.53)
    glass:SetWidth(14)
    glass:SetHeight(14)
    glass:SetPoint("LEFT", searchBox, "LEFT", 6, 0)

    placeholder = searchBox:CreateFontString(nil, "OVERLAY")
    placeholder:SetFont(media.font, 13, "")
    placeholder:SetTextColor(0.46, 0.49, 0.53)
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 25, 0)
    placeholder:SetText("Buscar")

    searchBox:SetScript("OnTextChanged", function(self)
        local t = self:GetText() or ""
        Shown(placeholder, t == "")
        t = t:lower()
        if t ~= filter then
            filter = t
            scroll:SetVerticalScroll(0)
            MarkDirty()
        end
    end)
    searchBox:SetScript("OnEscapePressed", function(self)
        self:SetText("")
        self:ClearFocus()
    end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- abas
    local prev
    for _, def in ipairs(TABS) do
        local t = CreateFrame("Button", nil, header)
        t.key = def.key
        t:SetHeight(28)
        t.text = Text(t, media.fontCinzel, 12, COL.tabOff)
        t.text:SetPoint("CENTER", t, "CENTER", 0, 1)
        t.text:SetText(Azaath.Tracked(def.label))
        t:SetWidth(max(60, (t.text:GetStringWidth() or 60) + 26))
        t.under = Solid(t, "ARTWORK", COL.gold)
        t.under:SetHeight(2)
        t.under:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 6, 0)
        t.under:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -6, 0)
        if prev then
            t:SetPoint("BOTTOMLEFT", prev, "BOTTOMRIGHT", 4, 0)
        else
            t:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", PAD - 6, 1)
        end
        t:SetScript("OnClick", function(self) SelectTab(self.key) end)
        t:SetScript("OnEnter", function(self)
            if self.key ~= tab then SetColor(self.text, COL.text) end
        end)
        t:SetScript("OnLeave", function() UpdateTabs() end)
        tabs[#tabs + 1] = t
        prev = t
    end
end

local function BuildList()
    local media = Azaath.media
    scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -(LIST_TOP + 20))
    scroll:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, FOOTER_H + 12)
    scroll:SetWidth(LIST_W)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local v = self:GetVerticalScroll() - delta * ROW_H * 2
        self:SetVerticalScroll(max(0, min(v, self:GetVerticalScrollRange())))
        UpdateThumb()
    end)
    scroll:SetScript("OnScrollRangeChanged", function(self)
        local range = self:GetVerticalScrollRange() or 0
        if self:GetVerticalScroll() > range then self:SetVerticalScroll(range) end
        UpdateThumb()
    end)
    child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(LIST_W)
    child:SetHeight(1)
    scroll:SetScrollChild(child)

    thumb = Solid(frame, "ARTWORK", { 0.40, 0.42, 0.43 }, 0.8)
    thumb:SetWidth(3)
    thumb:Hide()

    -- títulos das colunas
    headName = Text(frame, media.fontBold, 11, COL.head)
    headName:SetPoint("BOTTOMLEFT", scroll, "TOPLEFT", 6, 5)
    headLevel = Text(frame, media.fontBold, 11, COL.head)
    headPrice = Text(frame, media.fontBold, 11, COL.head)
    headPrice:SetPoint("BOTTOMRIGHT", scroll, "TOPRIGHT", -6, 5)
    local line = Solid(frame, "BORDER", COL.line)
    line:SetHeight(1)
    line:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, 1)
    line:SetPoint("TOPRIGHT", scroll, "TOPRIGHT", 0, 1)

    emptyText = Text(frame, media.font, 13, COL.dim)
    emptyText:SetPoint("TOP", scroll, "TOP", 0, -60)
    emptyText:Hide()
end

local function BuildFooter()
    local media = Azaath.media
    local footY = floor(FOOTER_H / 2 + 5)

    sellJunkBtn = MakeButton(frame, "Vender lixo", 24, COL.btn, COL.btnHov, 12)
    sellJunkBtn:SetWidth(84)
    sellJunkBtn:SetPoint("LEFT", frame, "BOTTOMLEFT", PAD + 2, footY)
    pcall(sellJunkBtn.text.SetFont, sellJunkBtn.text, media.fontBold, 12, "")
    sellJunkBtn:SetScript("OnClick", function(self)
        if not self.enabled then return end
        if not Azaath.IS_MODERN then
            SellJunk()
            UpdateSellJunkButton()
        end
    end)
    sellJunkBtn:SetScript("OnEnter", function(self)
        self.hover = true
        Button_Paint(self, true)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Vender lixo")
        local list, earned = CollectJunk()
        if #list == 0 then
            GameTooltip:AddLine("Nenhum item cinzento nas bolsas.", 0.7, 0.7, 0.7, true)
        else
            GameTooltip:AddLine(format("Vende %d %s por %s.", #list, #list == 1 and "item cinzento" or "itens cinzentos", Azaath.FormatMoney(earned)), 0.8, 0.8, 0.8, true)
        end
        GameTooltip:Show()
    end)
    sellJunkBtn:SetScript("OnLeave", function(self)
        self.hover = false
        Button_Paint(self, false)
        GameTooltip:Hide()
    end)

    if Azaath.IS_MODERN then
        local sec = CreateFrame("Button", "AzaathUIMerchantSellJunkSecure", sellJunkBtn, "SecureActionButtonTemplate")
        sec:SetAllPoints(sellJunkBtn)
        sec:RegisterForClicks("AnyUp", "AnyDown")
        sec:SetAttribute("useOnKeyDown", false)
        sec:SetAttribute("type1", "macro")
        sec:SetScript("OnEnter", function(self)
            local p = self:GetParent()
            local onEnter = p and p:GetScript("OnEnter")
            if onEnter then onEnter(p) end
        end)
        sec:SetScript("OnLeave", function(self)
            local p = self:GetParent()
            local onLeave = p and p:GetScript("OnLeave")
            if onLeave then onLeave(p) end
        end)
        sec:SetScript("PreClick", function(self, button, down)
            if InCombatLockdown() then return end
            self.earned = nil
            local list = CollectJunk()
            local lines, len, earned = {}, 0, 0
            for _, e in ipairs(list) do
                local line = format("/use %d %d", e.bag, e.slot)
                if len + #line + 1 > 255 then break end
                lines[#lines + 1] = line
                len = len + #line + 1
                earned = earned + e.value
            end
            self.more = #lines < #list or nil
            local macro = #lines > 0 and tconcat(lines, "\n") or nil
            self:SetAttribute("macrotext1", macro)
            self:SetAttribute("macrotext", macro)
            self.earned = #lines > 0 and earned or nil
        end)
        sec:SetScript("PostClick", function(self, button, down)
            if down then return end
            if self.earned and self.earned > 0 then
                Azaath:Print("lixo vendido por %s.", Azaath.FormatMoney(self.earned))
                if self.more then Azaath:Print("ainda há lixo: clique de novo para vender o resto.") end
                self.earned, self.more = nil, nil
            end
            UpdateSellJunkButton()
        end)
    end

    hintText = Text(frame, media.font, 12, COL.dim)
    hintText:SetJustifyH("LEFT")
    hintText:SetPoint("LEFT", sellJunkBtn, "RIGHT", 14, 0)
    hintText:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -PAD - 180, footY)
    NoWrap(hintText)

    moneyText = Text(frame, media.fontTitleB, 16, COL.text)
    moneyText:SetJustifyH("RIGHT")
    moneyText:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -PAD - 2, footY)

    local moneyHit = CreateFrame("Frame", nil, frame)
    moneyHit:SetPoint("TOPLEFT", moneyText, "TOPLEFT", 0, 0)
    moneyHit:SetPoint("BOTTOMRIGHT", moneyText, "BOTTOMRIGHT", 0, 0)
    moneyHit:EnableMouse(true)
    moneyHit:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Dinheiro")
        GameTooltip:AddLine(Azaath.FormatMoney(Money()), 1, 1, 1)
        GameTooltip:Show()
    end)
    moneyHit:SetScript("OnLeave", function() GameTooltip:Hide() end)

    UpdateSellJunkButton()
end

local function Build()
    frame = CreateFrame("Frame", "AzaathUIMerchant", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:SetWidth(W)
    frame:SetHeight(H)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    tinsert(UISpecialFrames, "AzaathUIMerchant") -- ESC fecha (e encerra a interação)

    BuildPanelTextures()
    BuildHeader()
    BuildList()
    BuildFooter()
    detail = BuildDetail()
    repairPanel = BuildRepairPanel()
    repairPanel:Hide()

    frame:SetScript("OnReceiveDrag", SellCursor)
    frame:SetScript("OnMouseUp", function() SellCursor() end)
    frame:SetScript("OnHide", function()
        searchBox:ClearFocus()
        GameTooltip:Hide()
        if not closingByEvent and CloseMerchant then pcall(CloseMerchant) end
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        if not dirty then return end
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < THROTTLE then return end
        self.elapsed = 0
        Refresh()
    end)
end

--------------------------------------------------------------------------------
-- Janela da Blizzard e bolsas
--------------------------------------------------------------------------------
local hider = CreateFrame("Frame")
hider:Hide()

local function Silence()
    local f = _G.MerchantFrame
    if f and not f.azaathSilenced then
        f.azaathSilenced = true
        f:SetParent(hider)
        f:HookScript("OnShow", function(self)
            if self:GetParent() ~= hider then self:SetParent(hider) end
        end)
    end
end

local function CloseBlizzardMerchant()
    -- Moderno: o gerenciador de interações fecha a janela; HideUIPanel do addon contamina o gerenciador de painéis.
    if Azaath.IS_MODERN then return end
    local f = _G.MerchantFrame
    if f and f.azaathSilenced and f:IsShown() then
        if _G.HideUIPanel then pcall(HideUIPanel, f) end
        if f:IsShown() then f:Hide() end
    end
end

local function InventoryShown()
    local inv = _G.AzaathUIInventory
    return inv and inv:IsShown()
end

-- O OnShow da MerchantFrame (que abre as bolsas) não roda com ela oculta
local function OpenBags()
    openedBags = false
    if InventoryShown() or not _G.OpenAllBags then return end
    openedBags = true
    if Azaath.IS_MODERN then
        pcall(OpenAllBags, _G.MerchantFrame)
    else
        pcall(OpenAllBags, true)
    end
end

local function CloseBags()
    if not openedBags then return end
    openedBags = false
    if not _G.CloseAllBags then return end
    if Azaath.IS_MODERN then
        pcall(CloseAllBags, _G.MerchantFrame)
    else
        pcall(CloseAllBags)
    end
end

local function Open()
    Silence()
    if not frame then Build() end
    tab, selected, qty = "buy", nil, 1
    filter = ""
    searchBox:SetText("")
    AutoRepair()
    SetHeader()
    -- Fecha equipamentos/status se estiverem abertos; no mercador abre só o inventário
    local charMod = Azaath:GetModule("Character")
    if charMod and charMod.frame and charMod.frame:IsShown() and charMod.Close then
        charMod:Close(true)
    end
    frame:Show()
    OpenBags()
    HookInventory()
    Reposition()
    SyncInventoryLayout()
    scroll:SetVerticalScroll(0)
    Refresh()
end

local function CloseByEvent()
    closingByEvent = true
    frame:Hide()
    closingByEvent = false
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local REFRESH_EVENTS = {
    "MERCHANT_UPDATE", "MERCHANT_FILTER_ITEM_UPDATE", "GET_ITEM_INFO_RECEIVED",
    "PLAYER_MONEY", "UPDATE_INVENTORY_DURABILITY", "PLAYER_EQUIPMENT_CHANGED",
    "BAG_UPDATE", "GUILDBANK_UPDATE_WITHDRAWMONEY",
}

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "MERCHANT_SHOW" then
        Open()
    elseif event == "MERCHANT_CLOSED" then
        if frame and frame:IsShown() then CloseByEvent() end
        CloseBlizzardMerchant()
        CloseBags()
        SyncInventoryLayout()
    elseif frame and frame:IsShown() then
        MarkDirty()
    end
end)

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:ApplyLayout()
    if frame and frame:IsShown() then Reposition() end
end

function M:OnInitialize()
    self.db = Azaath.db.merchant
end

function M:OnEnable()
    if not self.db or not self.db.enabled then return end
    TEX = Azaath.media.path .. "Inventory\\"
    UITEX = Azaath.media.path .. "MapUI\\"

    local f = _G.MerchantFrame
    if f and f:IsShown() then f:Hide() end
    Silence()

    Azaath.SafeRegister(events, "MERCHANT_SHOW")
    Azaath.SafeRegister(events, "MERCHANT_CLOSED")
    for _, e in ipairs(REFRESH_EVENTS) do
        Azaath.SafeRegister(events, e)
    end
end
