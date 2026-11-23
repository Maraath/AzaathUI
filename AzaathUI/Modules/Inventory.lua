--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Inventory.lua
    Inventário unificado (bolsas 0-4) reproduzindo o painel de inventário do
    Azaath, com as texturas de Media/Inventory (geradas por
    tools/media/generate-inventory-media.js a partir da captura de referência):

      * cabeçalho azul escovado com borda rasgada, título "I N V E N T Á R I O",
        busca escura com "?" dourado e "Ordenar" com relógio / estrela / triângulo
      * corpo quase preto com estrias, moldura escura e filete claro
      * seções em duas colunas (encaixe tipo "alvenaria", como no Azaath): título
        com hachura diagonal, contador, botão de seta (recolhe) e filete duplo
      * espaços: equipamento com fundo "de estúdio" e barra de durabilidade,
        materiais redondos, demais quadrados; raridade tinge o fundo;
        losango amarelo nos itens de missão
      * rodapé: dinheiro com os ícones de ouro, prata e cobre

    Diferenças propositais em relação ao Azaath (não existem no WoW): sem peso no
    cabeçalho, sem peso por seção e sem moedas extras no rodapé.

    Por que os cliques continuam seguros:
      * Cada botão fica dentro de um "suporte" com SetID(bolsa) e tem
        SetID(espaço); pegar, arrastar e dividir pilhas usam as funções de
        contêiner da Blizzard, como nas bolsas padrão.
      * Usar/equipar (clique direito) é protegido no cliente moderno: passa
        por um botão seguro sobreposto ("/use bolsa espaço"), ver secureUse.
      * Suporta tanto o cliente 3.3.5a quanto o motor 12.x / Camelot
        (C_Container e valores secretos).

    Como substitui as bolsas da Blizzard sem trocar funções globais:
      * Quando a Blizzard abre a janela de uma bolsa 0-4 ou a janela combinada,
        ela fica invisível e sem mouse (alpha 0) — continua "aberta" por baixo,
        então B, vendedor, botão de inventário etc. seguem funcionando.
        A nossa janela espelha esse estado (Sync / AnyBagOpen).
      * Bolsas do banco (5-11) e o chaveiro continuam com a janela padrão.

    Com o personagem aberto (módulo Character), a janela se encaixa à direita
    dele com altura fixa (M:Reposition). Bolsas abertas pelo jogo num
    vendedor/banco/correio abrem só o inventário, sem girar a câmera.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("Inventory")

local _G = _G
local ipairs, pairs, format, floor, min, max = ipairs, pairs, string.format, math.floor, math.min, math.max
-- Bolsas via Compat (C_Container no cliente moderno; globais na 3.3.5)
local API = Azaath.API
local GetContainerNumSlots, GetContainerItemInfo, GetContainerItemLink =
      API.GetContainerNumSlots, API.GetContainerItemInfo, API.GetContainerItemLink
local GetContainerItemCooldown, UseContainerItem = API.GetContainerItemCooldown, API.UseContainerItem
local PickupContainerItem, SplitContainerItem = API.PickupContainerItem, API.SplitContainerItem
local ShowContainerSellCursor = API.ShowContainerSellCursor
local GetContainerItemDurability = (_G.C_Container and C_Container.GetContainerItemDurability)
                                   or _G.GetContainerItemDurability

--------------------------------------------------------------------------------
-- Medidas do painel (unidades de UI)
--------------------------------------------------------------------------------
local PAD          = 26   -- recuo do conteúdo (a moldura rasgada ocupa ~12)
local HEADER_H     = 88   -- faixa azul até o filete
local BODY_TOP     = 12   -- respiro entre o filete e a primeira seção
local FOOTER_H     = 56   -- do filete do rodapé até a base do painel
local SECTION_HEAD = 24   -- título + filete duplo
local SECTION_GAP  = 14
local COL_GAP      = 16   -- entre as duas colunas de seções
local SPACING      = 4
local THROTTLE     = 0.1
local FIRST_BAG, LAST_BAG = 0, 4

-- Cores amostradas da referência
local COL = {
    title    = { 0.88, 0.85, 0.77 },
    section  = { 0.86, 0.84, 0.76 },
    number   = { 0.90, 0.88, 0.82 },
    sortText = { 0.78, 0.78, 0.76 },
    iconOff  = { 0.60, 0.60, 0.58 },
    iconHov  = { 0.85, 0.85, 0.83 },
    sepHead  = { 0.27, 0.285, 0.28 },
    sepFoot  = { 0.17, 0.157, 0.137 },
    line1    = { 0.27, 0.27, 0.26 },
    line2    = { 0.16, 0.16, 0.15 },
    btn      = { 0.25, 0.25, 0.245 },
    btnHov   = { 0.32, 0.32, 0.315 },
    btnOff   = { 0.16, 0.16, 0.155 },
    searchBg = { 0.02, 0.055, 0.09 },
    searchBd = { 0.17, 0.20, 0.24 },
    durab    = { 0.66, 0.65, 0.65 },
    tabOn    = { 0.95, 0.90, 0.78 },
    tabOff   = { 0.50, 0.50, 0.48 },
    gold     = { 0.89, 0.78, 0.55 },
    text     = { 0.90, 0.88, 0.82 },
}

-- Ordem e nomes das seções
local CATEGORIES = {
    { key = "weapons",    label = "Armas" },
    { key = "armor",      label = "Equipamento" },
    { key = "consumable", label = "Consumíveis" },
    { key = "materials",  label = "Materiais" },
    { key = "quest",      label = "Missão" },
    { key = "misc",       label = "Diversos" },
    { key = "junk",       label = "Lixo" },
    { key = "free",       label = "Espaço livre" },
}

-- Forma do espaço por seção (como no Azaath: equipamento com fundo claro,
-- recursos redondos, o resto quadrado escuro)
local SLOT_KIND = { weapons = "gear", armor = "gear", materials = "round" }

-- Botões de ordenação: relógio / estrela / triângulo (o peso do Azaath foi retirado)
local SORTS = {
    { key = "recent", tex = "SortClock", tip = "Mais recentes",
      desc = "Itens novos primeiro, depois a ordem das bolsas." },
    { key = "rarity", tex = "SortStar",  tip = "Raridade",
      desc = "Maior raridade primeiro, depois por nome." },
    { key = "level",  tex = "SortTier",  tip = "Nível do item",
      desc = "Maior nível de item primeiro." },
}

-- Índices de GetAuctionItemClasses() na 3.3.5a (nomes vêm localizados do cliente):
-- 1 Arma, 2 Armadura, 3 Recipiente, 4 Consumível, 5 Glifo, 6 Mercadorias,
-- 7 Projétil, 8 Aljava, 9 Receita, 10 Gema, 11 Diversos, 12 Missão
local CLASS_INDEX_TO_CAT = {
    "weapons", "armor", "misc", "consumable", "misc", "materials",
    "weapons", "weapons", "misc", "materials", "misc", "quest",
}
local classToCat = {}

-- Cliente moderno: classe do item por ID (Enum.ItemClass), independe do idioma.
-- 0 Consumível, 1 Recipiente, 2 Arma, 3 Gema, 4 Armadura, 5 Reagente,
-- 6 Projétil, 7 Mercadorias, 8 Aprimoramento, 9 Receita, 11 Aljava,
-- 12 Missão, 13 Chave, 15 Diversos, 16 Glifo
local CLASS_ID_TO_CAT = {
    [0] = "consumable", [1] = "misc", [2] = "weapons", [3] = "materials", [4] = "armor",
    [5] = "materials", [6] = "weapons", [7] = "materials", [8] = "consumable", [9] = "misc",
    [11] = "weapons", [12] = "quest", [13] = "misc", [15] = "misc", [16] = "misc",
}

local TEX                 -- caminho de Media\Inventory\ (definido no OnEnable)
local fontSection         -- Cinzel Regular (títulos), com fallback
local ROUND_OK = false    -- o cliente tem MaskTexture (ícones redondos)

local frame, scroll, child, searchBox, moneyBox
local headerTex, bodyTex, footerTex
local sortButtons = {}
local holders = {}     -- [bag] = frame com SetID(bag)
local buttons = {}     -- [bag][slot] = botão
local headers = {}     -- pool de títulos de seção
local filter = ""
local dirty = true
local docked, dockHeight = false, nil -- encaixado ao lado do personagem (ver M:Reposition)
local UpdateViewTabs, AnyBagOpen

-- Cliente moderno: usar/vender item da bolsa é ação PROTEGIDA (chamar
-- C_Container.UseContainerItem do addon gera "ação bloqueada"). Um único
-- botão seguro (secureUse) é posto por cima do item sob o mouse, fora de
-- combate, com a macro "/use bolsa espaço" no clique direito. Ele fica preso
-- ao UIParent com posição absoluta: a janela do inventário continua sem
-- proteção (Show/Hide/SetPoint livres). Na 3.3.5 a chamada direta funciona.
local USE_SECURE = false
local secureUse

local function IsAuctionOpen()
    return (_G.AuctionHouseFrame and _G.AuctionHouseFrame:IsShown())
        or (_G.AuctionFrame and _G.AuctionFrame:IsShown())
end
-- Igual à bolsa da Blizzard: clique direito com o leilão aberto põe o item no slot de venda.
local function SendToAuction(bag, slot)
    local ahf = _G.AuctionHouseFrame
    if ahf and ahf:IsShown() and ahf.SetPostItem and _G.ItemLocation then
        local loc = ItemLocation:CreateFromBagAndSlot(bag, slot)
        local AH = _G.C_AuctionHouse
        if not (AH and AH.IsSellItemValid) or AH.IsSellItemValid(loc, true) then
            ahf:SetPostItem(loc)
        end
        return
    end
    local af = _G.AuctionFrame
    if af and af:IsShown() then
        if _G.AuctionFrameAuctions and not AuctionFrameAuctions:IsVisible() and _G.AuctionFrameTab_OnClick
           and _G.AuctionFrameTab3 then
            AuctionFrameTab_OnClick(AuctionFrameTab3)
        end
        ClearCursor()
        if PickupContainerItem then PickupContainerItem(bag, slot) end
        if _G.ClickAuctionSellItemButton then
            pcall(ClickAuctionSellItemButton, _G.AuctionsItemButton, "LeftButton")
        end
        if _G.AuctionsFrameAuctions_ValidateAuction then pcall(AuctionsFrameAuctions_ValidateAuction) end
        ClearCursor()
    end
end
local function IsBankOpen()
    local bf = _G.BankFrame
    return bf and bf:IsShown()
end

local function SafeNumber(v, fallback)
    if v == nil or Azaath.IsSecret(v) then return fallback end
    return v
end

local function SetColor(obj, c, a)
    if obj.SetTextColor then
        obj:SetTextColor(c[1], c[2], c[3], a or 1)
    else
        obj:SetVertexColor(c[1], c[2], c[3], a or 1)
    end
end

local function Text(parent, font, size, color, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    local ok = pcall(fs.SetFont, fs, font or Azaath.media.fontTitleB, size, flags or "")
    if not ok or not fs:GetFont() then
        fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags or "")
    end
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetShadowOffset(1, -1)
    if color then SetColor(fs, color) end
    return fs
end

local function SlotSize() return M.db.slotSize or 44 end
local function PerColumn() return max(2, floor((M.db.columns or 8) / 2)) end
local function ColumnWidth()
    local size = SlotSize()
    return PerColumn() * (size + SPACING) - SPACING
end

--------------------------------------------------------------------------------
-- Classificação
--------------------------------------------------------------------------------
local function BuildClassMap()
    if not GetAuctionItemClasses then return end -- cliente moderno usa classID
    local classes = { GetAuctionItemClasses() }
    for i, name in ipairs(classes) do
        classToCat[name] = CLASS_INDEX_TO_CAT[i] or "misc"
    end
end

local function Categorize(quality, itemType, classID)
    local q = SafeNumber(quality, 1)
    if q == 0 then return "junk" end
    if classID then return CLASS_ID_TO_CAT[classID] or "misc" end
    return classToCat[itemType or ""] or "misc"
end

local function IsNewItem(bag, slot)
    local CN = _G.C_NewItems
    if CN and CN.IsNewItem then
        local ok, res = pcall(CN.IsNewItem, bag, slot)
        return ok and res == true
    end
    return false
end

-- Marca info de missão: questStart = item que inicia missão ainda não aceita
-- (o "!" da mochila da Blizzard); itens de missão vão para a seção Missão.
local function ApplyQuestInfo(info, bag, slot)
    local isQuest, questID, isActive = API.GetContainerItemQuestInfo(bag, slot)
    local hasQuest = type(questID) == "number" and questID > 0
    info.questStart = hasQuest and not isActive
    if (isQuest or hasQuest) and info.cat ~= "junk" then info.cat = "quest" end
end

--------------------------------------------------------------------------------
-- Botões de item
--------------------------------------------------------------------------------
local function GetHolder(bag)
    local h = holders[bag]
    if not h then
        h = CreateFrame("Frame", nil, child)
        h:SetID(bag)
        h.bagID = bag
        h.GetBagID = function() return bag end
        h:SetAllPoints(child)
        holders[bag] = h
    end
    return h
end

-- Aplica a forma do espaço: "slot" (quadrado escuro), "gear" ou "round"
local function SetSlotKind(b, kind)
    if kind == "round" and not ROUND_OK then kind = "slot" end
    if b.azKind == kind then return end
    b.azKind = kind

    -- a skin Azaath (InventorySkin.lua) troca textura e recuo do ícone
    local inset = (M.SlotInset and M.SlotInset(kind)) or (kind == "gear" and 4) or (kind == "round" and 5) or 3
    b.azBg:SetTexture((M.SlotTex and M.SlotTex(kind))
        or TEX .. ((kind == "gear" and "SlotGear") or (kind == "round" and "SlotRound") or "Slot"))
    b.icon:ClearAllPoints()
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", inset, -inset)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -inset, inset)

    if b.azMask then
        if kind == "round" and not b.azMasked then
            b.icon:AddMaskTexture(b.azMask)
            b.azHL:AddMaskTexture(b.azMask)
            b.azMasked = true
        elseif kind ~= "round" and b.azMasked then
            b.icon:RemoveMaskTexture(b.azMask)
            b.azHL:RemoveMaskTexture(b.azMask)
            b.azMasked = false
        end
    end
    if kind ~= "gear" then b.azDur:Hide() end
end

local function StyleItemButton(b)
    local media, size = Azaath.media, SlotSize()
    local name = b:GetName()
    b:SetWidth(size)
    b:SetHeight(size)

    -- remove a moldura clássica do template (se houver)
    local nt = b:GetNormalTexture()
    if nt then nt:SetTexture(nil) end

    -- fundo do espaço (textura Azaath, tingida pela raridade)
    b.azBg = b:CreateTexture(nil, "BACKGROUND")
    b.azBg:SetAllPoints(b)

    -- ícone
    local icon = b.icon or _G[name .. "IconTexture"]
    if not icon then
        icon = b:CreateTexture(name .. "IconTexture", "BORDER")
    end
    b.icon = icon
    _G[name .. "IconTexture"] = icon
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    -- realce ao passar o mouse (camada HIGHLIGHT aparece sozinha)
    b.azHL = b:CreateTexture(nil, "HIGHLIGHT")
    b.azHL:SetTexture(media.blank)
    b.azHL:SetVertexColor(1, 1, 1, 0.10)
    b.azHL:SetAllPoints(icon)

    -- máscara redonda (materiais)
    if ROUND_OK then
        b.azMask = b:CreateMaskTexture()
        b.azMask:SetTexture(TEX .. "RoundMask", "CLAMPTOBLACKADDITIONAL", "CLAMPTOBLACKADDITIONAL")
        b.azMask:SetAllPoints(icon)
    end

    -- recarga
    local cd = b.Cooldown or _G[name .. "Cooldown"]
    if not cd then
        cd = CreateFrame("Cooldown", name .. "Cooldown", b, "CooldownFrameTemplate")
    end
    b.Cooldown = cd
    _G[name .. "Cooldown"] = cd
    cd:ClearAllPoints()
    cd:SetAllPoints(icon)

    b:SetPushedTexture(media.blank)
    local pushed = b:GetPushedTexture()
    if pushed then
        pushed:SetVertexColor(0, 0, 0)
        pushed:SetAlpha(0.35)
        pushed:SetAllPoints(icon)
    end

    -- textos acima da recarga
    local top = CreateFrame("Frame", nil, b)
    top:SetAllPoints(b)
    top:SetFrameLevel(cd:GetFrameLevel() + 1)

    -- quantidade: numerais serifados limpos estilo Azaath (Cinzel Bold) no canto inferior direito
    local count = top:CreateFontString(name .. "Count", "OVERLAY", "GameFontNormal")
    b.Count = count
    _G[name .. "Count"] = count
    count:SetFont(media.fontTitleB, floor(size * 0.38 + 0.5), "")
    if not count:GetFont() then
        count:SetFont("Fonts\\FRIZQT__.TTF", floor(size * 0.38 + 0.5), "")
    end
    count:SetTextColor(1, 1, 1)
    count:SetShadowColor(0, 0, 0, 1)
    count:SetShadowOffset(1, -1)
    count:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -3, 2)

    -- nível do item (canto superior esquerdo, onde o Azaath mostra o "tier")
    b.azLevel = Text(top, media.fontTitleB, 11, COL.number)
    b.azLevel:SetPoint("TOPLEFT", b, "TOPLEFT", 5, -4)

    -- barra de durabilidade (equipamento), na base do fundo claro
    b.azDur = top:CreateTexture(nil, "OVERLAY")
    b.azDur:SetTexture(media.blank)
    b.azDur:SetHeight(2)
    b.azDur:SetPoint("BOTTOMLEFT", b, "BOTTOMLEFT", 4, 4)
    b.azDur:Hide()

    -- losango amarelo (item de missão)
    b.azBadge = top:CreateTexture(nil, "OVERLAY")
    b.azBadge:SetTexture(TEX .. "Badge")
    b.azBadge:SetWidth(floor(size * 0.42))
    b.azBadge:SetHeight(floor(size * 0.42))
    b.azBadge:SetPoint("CENTER", b, "TOPRIGHT", -4, -4)
    b.azBadge:Hide()

    -- cadeado: item trancado (Modules/InventoryLock.lua)
    b.azLock = top:CreateTexture(nil, "OVERLAY", nil, 3)
    b.azLock:SetTexture(Azaath.media.path .. "Inventory\\Lock")
    b.azLock:SetSize(floor(size * 0.34), floor(size * 0.34))
    b.azLock:SetPoint("TOPRIGHT", b, "TOPRIGHT", -3, -3)
    b.azLock:Hide()

    -- "!" sobre o ícone: item que inicia missão (igual à mochila da Blizzard)
    b.azQuestBang = top:CreateTexture(nil, "OVERLAY", nil, 2)
    b.azQuestBang:SetTexture("Interface\\ContainerFrame\\UI-Icon-QuestBang")
    b.azQuestBang:SetPoint("TOPLEFT", b.icon, "TOPLEFT", 0, 0)
    b.azQuestBang:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", 0, 0)
    b.azQuestBang:Hide()

    -- número do botão "espaço livre"
    b.azFree = Text(top, media.fontTitleB, 16, COL.iconOff)
    b.azFree:SetPoint("CENTER", b, "CENTER", 0, 0)

    SetSlotKind(b, "slot")
end

-- Tooltip do item (anchor = o botão ou o botão seguro por cima dele)
local function ShowItemTooltip(anchor, bag, slot)
    local link = GetContainerItemLink(bag, slot)
    if not link then return end
    GameTooltip:SetOwner(anchor, "ANCHOR_LEFT")
    GameTooltip:SetBagItem(bag, slot)
    if IsModifiedClick("COMPAREITEMS") or GetCVarBool("alwaysCompareItems") then
        GameTooltip_ShowCompareItem(GameTooltip)
    end
    if MerchantFrame and MerchantFrame:IsShown() then
        if ShowContainerSellCursor then
            pcall(ShowContainerSellCursor, bag, slot)
        elseif SetCursor then
            pcall(SetCursor, "BUY_CURSOR")
        end
    else
        if not (SpellIsTargeting and SpellIsTargeting()) then
            ResetCursor()
        end
    end
    GameTooltip:Show()
end

-- Clique esquerdo (nada protegido): link no chat, provador, dividir, pegar
local function ItemLeftClick(b)
    local IL = Azaath.InventoryLock
    if IL and IL.mode then -- modo "Trancar item": o clique tranca/destrava
        if GetContainerItemInfo(b.bag, b.slot) then
            IL.Toggle(b.bag, b.slot)
            dirty = true
        end
        return
    end
    local link = GetContainerItemLink(b.bag, b.slot)
    -- Shift serve para link no chat E para dividir (como na Blizzard): só vira
    -- link quando há uma caixa de chat aberta; senão, abre o divisor de pilha
    if IsModifiedClick("CHATLINK") and link and ChatEdit_InsertLink(link) then
        return
    elseif IsModifiedClick("DRESSUP") and link then
        DressUpItemLink(link)
    elseif IsModifiedClick("SPLITSTACK") then
        local _, count, locked = GetContainerItemInfo(b.bag, b.slot)
        local c = SafeNumber(count, 1)
        if locked or not c or c < 2 then return end
        local ssf = _G.StackSplitFrame
        if ssf and ssf.OpenStackSplitFrame then -- cliente moderno (método do quadro)
            ssf:OpenStackSplitFrame(c, b, "BOTTOMRIGHT", "TOPRIGHT")
        elseif _G.OpenStackSplitFrame then
            _G.OpenStackSplitFrame(c, b, "BOTTOMRIGHT", "TOPRIGHT")
        end
    elseif SpellIsTargeting and SpellIsTargeting() then
        if UseContainerItem then UseContainerItem(b.bag, b.slot) end
    elseif PickupContainerItem then
        PickupContainerItem(b.bag, b.slot)
    end
end

--------------------------------------------------------------------------------
-- Botão seguro sobreposto (cliente moderno)
--------------------------------------------------------------------------------
local function DetachSecure()
    if not secureUse or InCombatLockdown() then return end
    local owner = secureUse.owner
    secureUse.owner, secureUse.mode = nil, nil
    secureUse:Hide()
    secureUse:ClearAllPoints()
    secureUse:SetAttribute("type1", nil)
    secureUse:SetAttribute("type2", nil)
    secureUse:SetAttribute("macrotext", nil)
    secureUse:SetAttribute("macrotext1", nil)
    secureUse:SetAttribute("macrotext2", nil)
    if owner and owner.UnlockHighlight then owner:UnlockHighlight() end
end

-- mode "item": clique direito = /use bolsa espaço; clique esquerdo/arrastar
--              seguem o código normal (PostClick / OnDragStart)
local function AttachSecure(owner, mode)
    if not secureUse or InCombatLockdown() or not owner:IsVisible() then return end
    local l, t = owner:GetLeft(), owner:GetTop()
    if not (l and t) then return end
    local s = owner:GetEffectiveScale() / secureUse:GetEffectiveScale()
    secureUse:ClearAllPoints()
    secureUse:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * s, t * s)
    secureUse:SetWidth(owner:GetWidth() * s)
    secureUse:SetHeight(owner:GetHeight() * s)
    secureUse.owner, secureUse.mode = owner, mode
    local macro = format("/use %d %d", owner.bag, owner.slot)
    local IL = Azaath.InventoryLock
    local lockBlock = IL and (IL.mode or (IL.MerchantOpen() and IL.IsLocked(owner.bag, owner.slot)))
    if lockBlock then
        -- modo de trancar ou item trancado no vendedor: o direito não usa/vende
        secureUse:SetAttribute("type1", nil)
        secureUse:SetAttribute("type2", nil)
        secureUse:SetAttribute("macrotext1", nil)
        secureUse:SetAttribute("macrotext2", nil)
    elseif SpellIsTargeting and SpellIsTargeting() then
        -- Com feitiço/item aguardando alvo (kit de armadura, encantamento etc.),
        -- o clique esquerdo aplica no item e o direito cancela a mira.
        secureUse:SetAttribute("type1", "macro")
        secureUse:SetAttribute("macrotext1", macro)
        secureUse:SetAttribute("type2", nil)
        secureUse:SetAttribute("macrotext2", nil)
    elseif IsAuctionOpen() then
        -- Com leilão aberto, direito deve levantar o item (PostClick faz PickupContainerItem).
        secureUse:SetAttribute("type1", nil)
        secureUse:SetAttribute("type2", nil)
        secureUse:SetAttribute("macrotext1", nil)
        secureUse:SetAttribute("macrotext2", nil)
    else
        secureUse:SetAttribute("type1", nil)
        secureUse:SetAttribute("type2", "macro")
        secureUse:SetAttribute("macrotext1", nil)
        secureUse:SetAttribute("macrotext2", macro)
    end
    secureUse:SetAttribute("macrotext", macro)
    secureUse:Show()
end

local function CreateSecureUse()
    local o = CreateFrame("Button", "AzaathUIInventoryUse", UIParent, "SecureActionButtonTemplate")
    o:SetFrameStrata("DIALOG")
    o:RegisterForClicks("AnyUp", "AnyDown")
    o:SetAttribute("useOnKeyDown", false) -- age só ao soltar o botão
    o:RegisterForDrag("LeftButton")
    o:Hide()

    o:SetScript("OnEnter", function(self)
        local owner = self.owner
        if not owner then return end
        if owner.LockHighlight then owner:LockHighlight() end
        ShowItemTooltip(self, owner.bag, owner.slot)
    end)
    o:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if not (SpellIsTargeting and SpellIsTargeting()) then
            ResetCursor()
        end
        DetachSecure()
    end)

    o:SetScript("PreClick", function(self, button, down)
        if down then return end
        self._hadType1 = (self:GetAttribute("type1") ~= nil)
        self._hadType2 = (self:GetAttribute("type2") ~= nil)
    end)

    o:SetScript("PostClick", function(self, button, down)
        if down then return end -- o RegisterForClicks também entrega o "apertar"
        local hadType1, hadType2 = self._hadType1, self._hadType2
        self._hadType1, self._hadType2 = nil, nil
        local owner = self.owner
        if not owner then return end
        if self.mode == "item" then
            if button == "LeftButton" and not hadType1 then
                ItemLeftClick(owner)
            elseif button == "RightButton" and not hadType2 then
                if IsAuctionOpen() then
                    SendToAuction(owner.bag, owner.slot)
                elseif SpellIsTargeting and SpellIsTargeting() then
                    if SpellStopTargeting then pcall(SpellStopTargeting) end
                end
            end
            if self:IsShown() and self.owner and not InCombatLockdown() then
                AttachSecure(self.owner, self.mode)
            end
        end
    end)

    pcall(o.RegisterEvent, o, "CURRENT_SPELL_CAST_CHANGED")
    o:SetScript("OnEvent", function(self)
        if self:IsShown() and self.owner and not InCombatLockdown() then
            AttachSecure(self.owner, self.mode)
        end
    end)

    o:SetScript("OnDragStart", function(self)
        local owner = self.owner
        if self.mode == "item" and owner and PickupContainerItem then
            PickupContainerItem(owner.bag, owner.slot)
        end
    end)
    o:SetScript("OnReceiveDrag", function(self)
        local owner = self.owner
        if self.mode == "item" and owner and PickupContainerItem then
            PickupContainerItem(owner.bag, owner.slot)
        end
    end)
    secureUse = o
end

local function GetButton(bag, slot)
    buttons[bag] = buttons[bag] or {}
    local b = buttons[bag][slot]
    if not b then
        b = CreateFrame("Button", format("AzaathUIInvBag%dSlot%d", bag, slot), GetHolder(bag))
        b:SetID(slot)
        b.bag = bag
        b.bagID = bag
        b.slot = slot
        b.slotID = slot
        b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        b:RegisterForDrag("LeftButton")
        b:SetScript("OnEnter", function(self)
            ShowItemTooltip(self, self.bag, self.slot)
            -- cliente moderno: o botão seguro assume este espaço (usar/vender)
            if USE_SECURE then AttachSecure(self, "item") end
        end)
        b:SetScript("OnLeave", function()
            GameTooltip:Hide()
            if not (SpellIsTargeting and SpellIsTargeting()) then
                ResetCursor()
            end
        end)
        b:SetScript("OnClick", function(self, mouseButton)
            if mouseButton ~= "RightButton" then
                ItemLeftClick(self)
            elseif Azaath.InventoryLock and (Azaath.InventoryLock.mode
                    or Azaath.InventoryLock.BlockSell(self.bag, self.slot)) then
                return
            elseif not USE_SECURE then
                if UseContainerItem then UseContainerItem(self.bag, self.slot) end
            elseif IsAuctionOpen() then
                SendToAuction(self.bag, self.slot)
            elseif IsBankOpen() then
                if PickupContainerItem then PickupContainerItem(self.bag, self.slot) end
            elseif InCombatLockdown() and UIErrorsFrame then
                -- em combate o botão seguro não pode ser reposicionado
                UIErrorsFrame:AddMessage("Em combate, use o item pela barra de ações.", 1, 0.3, 0.3)
            end
        end)
        b:SetScript("OnDragStart", function(self)
            if PickupContainerItem then
                PickupContainerItem(self.bag, self.slot)
            end
        end)
        b:SetScript("OnReceiveDrag", function(self)
            if PickupContainerItem then
                PickupContainerItem(self.bag, self.slot)
            end
        end)
        b.SplitStack = function(button, split)
            if SplitContainerItem then
                SplitContainerItem(button.bag, button.slot, split)
            end
        end
        StyleItemButton(b)
        buttons[bag][slot] = b
    end
    return b
end

local function UpdateCooldown(b, bag, slot)
    local cd = b.Cooldown or _G[b:GetName() .. "Cooldown"]
    if not cd then return end
    local start, duration, enable = GetContainerItemCooldown(bag, slot)
    if Azaath.AnySecret(start, duration, enable) then
        cd:Hide()
        return
    end
    if Azaath.IsOn(enable) and start and start > 0 and duration > 0 then
        cd:SetCooldown(start, duration)
        cd:Show()
    else
        cd:Hide()
    end
end

-- Raridade: tinge o fundo (forte no equipamento, suave no resto)
local function SetQualityLook(b, quality)
    local q = SafeNumber(quality, nil)
    if q and q >= 2 then
        local r, g, bl = Azaath.API.GetItemQualityColor(q)
        r, g, bl = r or 1, g or 1, bl or 1
        local k = (M.QualityK and M.QualityK(b.azKind)) or ((b.azKind == "gear") and 0.7 or 0.45)
        b.azBg:SetVertexColor(1 + (r - 1) * k, 1 + (g - 1) * k, 1 + (bl - 1) * k)
    elseif q == 0 then
        b.azBg:SetVertexColor(0.72, 0.72, 0.72)
    else
        b.azBg:SetVertexColor(1, 1, 1)
    end
end

local function UpdateDurability(b, bag, slot)
    if b.azKind ~= "gear" or not GetContainerItemDurability then
        b.azDur:Hide()
        return
    end
    local cur, maxDur = GetContainerItemDurability(bag, slot)
    cur, maxDur = SafeNumber(cur, nil), SafeNumber(maxDur, nil)
    if not (cur and maxDur and maxDur > 0) then
        b.azDur:Hide()
        return
    end
    local ratio = max(0, min(1, cur / maxDur))
    b.azDur:SetWidth(max(1, (SlotSize() - 8) * ratio))
    if ratio <= 0.25 then
        b.azDur:SetVertexColor(0.85, 0.22, 0.18)
    else
        SetColor(b.azDur, COL.durab)
    end
    b.azDur:Show()
end

-- Preenche um botão com o item do espaço (bag, slot) de forma segura contra
-- nil child regions e secret values.
local function FillButton(b, bag, slot, info)
    SetSlotKind(b, SLOT_KIND[info.cat] or "slot")

    if b.icon then
        if info.texture then
            b.icon:SetTexture(info.texture)
            b.icon:Show()
        else
            b.icon:SetTexture(nil)
        end
        b.icon:SetDesaturated(info.locked and true or false)
    end

    local count = info.count
    if count and (Azaath.IsSecret(count) or count > 1) then
        b.Count:SetText(count)
        b.Count:Show()
    else
        b.Count:Hide()
    end

    SetQualityLook(b, info.quality)
    UpdateDurability(b, bag, slot)

    local lvl = SafeNumber(info.level, 0)
    local showLevel = M.db.showItemLevel and lvl > 1
        and (info.cat == "weapons" or info.cat == "armor")
    b.azLevel:SetText(showLevel and lvl or "")
    b.azFree:SetText("")
    if info.questStart then
        b.azQuestBang:Show(); b.azBadge:Hide()
    else
        b.azQuestBang:Hide()
        if info.cat == "quest" then b.azBadge:Show() else b.azBadge:Hide() end
    end
    local IL = Azaath.InventoryLock
    b.azLock:SetShown(IL and IL.IsLocked(bag, slot) or false)
    UpdateCooldown(b, bag, slot)
    b.azName = info.name and info.name:lower() or ""
    b.azCat = info.cat
end

--------------------------------------------------------------------------------
-- Títulos de seção: NOME ////////  12 [>]  + filete duplo
--------------------------------------------------------------------------------
local function SetArrow(h, collapsed)
    if collapsed then
        -- gira a seta 90° (aponta para baixo) e apaga: seção recolhida
        h.arrow:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
        h.arrow:SetVertexColor(0.6, 0.6, 0.6)
    else
        h.arrow:SetTexCoord(0, 1, 0, 1)
        h.arrow:SetVertexColor(0.85, 0.85, 0.85)
    end
end

--------------------------------------------------------------------------------
-- Desequipar Bolsa (Modo Bolsas)
--------------------------------------------------------------------------------
local function GetBagInventorySlot(bag)
    if not bag or bag < 1 or bag > 4 then return nil end
    local toInv = (_G.C_Container and C_Container.ContainerIDToInventoryID) or _G.ContainerIDToInventoryID
    if toInv then
        local id = toInv(bag)
        if id then return id end
    end
    return 19 + bag
end

local function PickupBagSlot(invID)
    if _G.PickupBagFromSlot then
        _G.PickupBagFromSlot(invID)
    elseif _G.PickupInventoryItem then
        _G.PickupInventoryItem(invID)
    end
end

local function FindFreeSlot(excludeBag)
    local searchBags = { 0 }
    for b = 1, 4 do
        if b ~= excludeBag then
            searchBags[#searchBags + 1] = b
        end
    end
    for _, b in ipairs(searchBags) do
        local numSlots = GetContainerNumSlots(b) or 0
        for s = 1, numSlots do
            local texture = GetContainerItemInfo(b, s)
            if not texture then
                return b, s
            end
        end
    end
    return nil, nil
end

local function CountFreeSlotsExcept(excludeBag)
    local count = 0
    local searchBags = { 0 }
    for b = 1, 4 do
        if b ~= excludeBag then
            searchBags[#searchBags + 1] = b
        end
    end
    for _, b in ipairs(searchBags) do
        local numSlots = GetContainerNumSlots(b) or 0
        for s = 1, numSlots do
            local texture = GetContainerItemInfo(b, s)
            if not texture then
                count = count + 1
            end
        end
    end
    return count
end

local function UnequipBagNow(bag)
    local invID = GetBagInventorySlot(bag)
    if not invID then return false end
    local destBag, destSlot = FindFreeSlot(bag)
    if not destBag or not destSlot then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("Não há espaço livre em outra bolsa para desequipar.", 1.0, 0.25, 0.25)
        end
        return false
    end

    ClearCursor()
    PickupBagSlot(invID)

    if CursorHasItem() then
        if PickupContainerItem then
            PickupContainerItem(destBag, destSlot)
        end
    end
    if CursorHasItem() and _G.PutItemInBackpack then
        _G.PutItemInBackpack()
    end
    if CursorHasItem() then
        PickupBagSlot(invID)
        return false
    end

    if PlaySound then
        pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_BACKPACK_OPEN or 846)
    end
    dirty = true
    return true
end

local unequipWorker = CreateFrame("Frame")
unequipWorker:Hide()
local unequipTask = nil

unequipWorker:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + elapsed
    if self.elapsed < 0.08 then return end
    self.elapsed = 0

    if not unequipTask then
        self:Hide()
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self:Hide()
        unequipTask = nil
        return
    end

    if CursorHasItem() then return end

    local bag = unequipTask.bag
    local slots = GetContainerNumSlots(bag) or 0
    if slots == 0 then
        self:Hide()
        unequipTask = nil
        return
    end

    local itemSlot = nil
    for s = 1, slots do
        local _, _, locked = GetContainerItemInfo(bag, s)
        if locked then
            return
        end
        local tex = GetContainerItemInfo(bag, s)
        if tex and not itemSlot then
            itemSlot = s
        end
    end

    if itemSlot then
        if unequipTask.lastSlot == itemSlot then
            unequipTask.retries = unequipTask.retries + 1
            if unequipTask.retries > 25 then
                if UIErrorsFrame then
                    UIErrorsFrame:AddMessage("Não foi possível transferir todos os itens da bolsa.", 1.0, 0.25, 0.25)
                end
                self:Hide()
                unequipTask = nil
                return
            end
        else
            unequipTask.lastSlot = itemSlot
            unequipTask.retries = 0
        end

        local destB, destS = FindFreeSlot(bag)
        if destB and destS and PickupContainerItem then
            PickupContainerItem(bag, itemSlot)
            PickupContainerItem(destB, destS)
        else
            if UIErrorsFrame then
                UIErrorsFrame:AddMessage("Bolsas cheias durante a transferência.", 1.0, 0.25, 0.25)
            end
            self:Hide()
            unequipTask = nil
        end
        return
    end

    UnequipBagNow(bag)
    self:Hide()
    unequipTask = nil
end)

local function StartUnequipBag(bag)
    if InCombatLockdown and InCombatLockdown() then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage("Não é possível desequipar bolsas em combate.", 1.0, 0.25, 0.25)
        end
        return
    end

    local slots = GetContainerNumSlots(bag) or 0
    if slots == 0 then return end

    local occupied = 0
    for s = 1, slots do
        if GetContainerItemInfo(bag, s) then occupied = occupied + 1 end
    end

    local freeOther = CountFreeSlotsExcept(bag)
    if freeOther < (occupied + 1) then
        if UIErrorsFrame then
            UIErrorsFrame:AddMessage(format("Espaço insuficiente nas outras bolsas (precisa de %d espaços).", occupied + 1), 1.0, 0.25, 0.25)
        end
        if PlaySound then pcall(PlaySound, SOUNDKIT and SOUNDKIT.IG_BACKPACK_CLOSE or 847) end
        return
    end

    if occupied == 0 then
        UnequipBagNow(bag)
        return
    end

    unequipTask = {
        bag = bag,
        retries = 0,
        lastSlot = nil,
    }
    unequipWorker.elapsed = 0
    unequipWorker:Show()
end
M.StartUnequipBag = StartUnequipBag -- clique direito na faixa Mochilas (InventoryBags.lua)

local function GetHeader(i)
    local h = headers[i]
    if h then return h end
    local media = Azaath.media

    h = CreateFrame("Frame", nil, child)
    h:SetHeight(SECTION_HEAD)

    h.text = Text(h, fontSection, 12, COL.section)
    h.text:SetPoint("TOPLEFT", h, "TOPLEFT", 0, -1)

    -- botão para desequipar bolsa (modo bolsas, bolsas 1..4)
    h.unequipBtn = CreateFrame("Button", nil, h)
    h.unequipBtn:SetWidth(15)
    h.unequipBtn:SetHeight(15)
    h.unequipBtn:SetPoint("LEFT", h.text, "RIGHT", 6, 0)

    h.unequipBtnBg = h.unequipBtn:CreateTexture(nil, "BACKGROUND")
    h.unequipBtnBg:SetTexture(TEX .. "RoundRect")
    h.unequipBtnBg:SetAllPoints(h.unequipBtn)
    SetColor(h.unequipBtnBg, COL.btn, 0.95)

    h.unequipIcon = h.unequipBtn:CreateTexture(nil, "ARTWORK")
    h.unequipIcon:SetTexture(media.path .. "MapUI\\Minus")
    h.unequipIcon:SetSize(11, 11)
    h.unequipIcon:SetPoint("CENTER", h.unequipBtn, "CENTER", 0, 0)
    h.unequipIcon:SetVertexColor(COL.iconOff[1], COL.iconOff[2], COL.iconOff[3])

    h.unequipBtn:SetScript("OnEnter", function(self)
        SetColor(h.unequipBtnBg, COL.btnHov, 0.95)
        h.unequipIcon:SetVertexColor(COL.gold[1], COL.gold[2], COL.gold[3])
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Desequipar Bolsa")
        if (self.occupied or 0) == 0 then
            GameTooltip:AddLine("Clique para desequipar esta bolsa e guardá-la no inventário.", 0.85, 0.85, 0.85, true)
        else
            GameTooltip:AddLine(format("A bolsa contém %d %s.", self.occupied, self.occupied == 1 and "item" or "itens"), 1.0, 0.82, 0.40, true)
            GameTooltip:AddLine("Clique para transferir os itens automaticamente e desequipá-la.", 0.70, 0.70, 0.70, true)
        end
        GameTooltip:Show()
    end)
    h.unequipBtn:SetScript("OnLeave", function(self)
        SetColor(h.unequipBtnBg, COL.btn, 0.95)
        local c = ((self.occupied or 0) == 0) and COL.iconOff or { 0.45, 0.45, 0.45 }
        h.unequipIcon:SetVertexColor(c[1], c[2], c[3])
        GameTooltip:Hide()
    end)
    h.unequipBtn:SetScript("OnClick", function(self)
        if self.bagID then
            StartUnequipBag(self.bagID)
        end
    end)
    h.unequipBtn:Hide()

    h.hatch = h:CreateTexture(nil, "ARTWORK")
    h.hatch:SetTexture(TEX .. "Hatch")
    h.hatch:SetHeight(12)
    h.hatch:SetVertexColor(COL.title[1], COL.title[2], COL.title[3], 0.17)
    h.hatch:SetPoint("LEFT", h.text, "RIGHT", 6, 0)

    -- botão de seta (recolhe/expande a seção)
    h.btn = CreateFrame("Button", nil, h)
    h.btn:SetWidth(15)
    h.btn:SetHeight(15)
    h.btn:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, 0)
    h.btnBg = h.btn:CreateTexture(nil, "BACKGROUND")
    h.btnBg:SetTexture(TEX .. "RoundRect")
    h.btnBg:SetAllPoints(h.btn)
    SetColor(h.btnBg, COL.btn, 0.95)
    h.arrow = h.btn:CreateTexture(nil, "ARTWORK")
    h.arrow:SetTexture(TEX .. "Arrow")
    h.arrow:SetAllPoints(h.btn)
    h.btn:SetScript("OnEnter", function(self)
        SetColor(h.btnBg, COL.btnHov, 0.95)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(M.db.collapsed[h.key] and "Expandir seção" or "Recolher seção")
        GameTooltip:Show()
    end)
    h.btn:SetScript("OnLeave", function()
        SetColor(h.btnBg, COL.btn, 0.95)
        GameTooltip:Hide()
    end)
    h.btn:SetScript("OnClick", function()
        if not h.key then return end
        M.db.collapsed[h.key] = not M.db.collapsed[h.key] or nil
        dirty = true
    end)

    h.count = Text(h, media.fontTitleB, 14, COL.number)
    h.count:SetPoint("RIGHT", h.btn, "LEFT", -8, 0)

    h.line1 = h:CreateTexture(nil, "ARTWORK")
    h.line1:SetTexture(media.blank)
    SetColor(h.line1, COL.line1)
    h.line1:SetHeight(1)
    h.line1:SetPoint("TOPLEFT", h, "TOPLEFT", 0, -18)
    h.line1:SetPoint("TOPRIGHT", h, "TOPRIGHT", 0, -18)
    h.line2 = h:CreateTexture(nil, "ARTWORK")
    h.line2:SetTexture(media.blank)
    SetColor(h.line2, COL.line2)
    h.line2:SetHeight(1)
    h.line2:SetPoint("TOPLEFT", h.line1, "BOTTOMLEFT", 0, 0)
    h.line2:SetPoint("TOPRIGHT", h.line1, "BOTTOMRIGHT", 0, 0)

    if M.StyleHeader then M.StyleHeader(h) end -- skin Azaath
    headers[i] = h
    return h
end

local function ApplyFilter()
    for _, list in pairs(buttons) do
        for _, b in pairs(list) do
            if b:IsShown() then
                local match = filter == "" or (b.azName and b.azName:find(filter, 1, true))
                    and (not M.catFilter or not b.azCat or M.catFilter[b.azCat] or false)
                b:SetAlpha(match and 1 or 0.2)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Dinheiro: [ouro] 12  [prata] 34  [cobre] 56
--------------------------------------------------------------------------------
local COIN_TEX = {
    "Interface\\MoneyFrame\\UI-GoldIcon",
    "Interface\\MoneyFrame\\UI-SilverIcon",
    "Interface\\MoneyFrame\\UI-CopperIcon",
}

local function UpdateMoney()
    if not moneyBox then return end
    local copper = GetMoney() or 0
    local g, s, c = floor(copper / 10000), floor(copper % 10000 / 100), copper % 100
    local values = {
        g > 0 and Azaath.Thousands(g) or nil,
        (g > 0 or s > 0) and tostring(s) or nil,
        tostring(c),
    }
    local prev
    for i = 1, 3 do
        local coin = moneyBox.coins[i]
        if values[i] then
            coin.icon:ClearAllPoints()
            if prev then
                coin.icon:SetPoint("LEFT", prev, "RIGHT", 10, 0)
            else
                coin.icon:SetPoint("LEFT", moneyBox, "LEFT", 0, 0)
            end
            coin.text:SetText(values[i])
            coin.icon:Show()
            coin.text:Show()
            prev = coin.text
        else
            coin.icon:Hide()
            coin.text:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- Montagem
--------------------------------------------------------------------------------
local SORTERS = {
    recent = function(a, b)
        if a.new ~= b.new then return a.new end
        if a.bag ~= b.bag then return a.bag < b.bag end
        return a.slot < b.slot
    end,
    rarity = function(a, b)
        local qa, qb = SafeNumber(a.quality, 0), SafeNumber(b.quality, 0)
        if qa ~= qb then return qa > qb end
        return (a.name or "") < (b.name or "")
    end,
    level = function(a, b)
        local la, lb = SafeNumber(a.level, 0), SafeNumber(b.level, 0)
        if la ~= lb then return la > lb end
        local qa, qb = SafeNumber(a.quality, 0), SafeNumber(b.quality, 0)
        if qa ~= qb then return qa > qb end
        return (a.name or "") < (b.name or "")
    end,
}

local function UpdateSortButtons()
    for _, sb in ipairs(sortButtons) do
        local active = M.db.sort == sb.key
        if active then
            sb.icon:SetVertexColor(1, 1, 1)
            sb.under:Show()
        else
            SetColor(sb.icon, sb.hover and COL.iconHov or COL.iconOff)
            sb.under:Hide()
        end
    end
end

local function GetBagDisplayName(bag)
    if bag == 0 then return "Mochila" end
    local invID = (ContainerIDToInventoryID and ContainerIDToInventoryID(bag)) or (19 + bag)
    local link = GetInventoryItemLink and GetInventoryItemLink("player", invID)
    if link then
        local name = Azaath.API.GetItemInfo(link)
        if name and name ~= "" then
            return format("[%d] %s", bag, name)
        end
    end
    return format("Bolsa %d", bag)
end

local function Rebuild()
    dirty = false
    local IBar = Azaath.InventoryBags
    local function BagVisible(bag) return not IBar or IBar.Visible(bag) end
    local db = M.db
    local size, perCol = SlotSize(), PerColumn()
    local step = size + SPACING
    local colW = ColumnWidth()
    local innerW = colW * 2 + COL_GAP
    local collapsed = db.collapsed
    local viewMode = db.viewMode or "az"

    -- Layout: cada seção vai para a coluna mais curta (como no Azaath)
    local colY, hIndex = { 0, 0 }, 0
    local function Section(cat, n, bagID, occupied)
        local col = (colY[1] <= colY[2]) and 1 or 2
        local x, y = (col - 1) * (colW + COL_GAP), colY[col]
        hIndex = hIndex + 1
        local h = GetHeader(hIndex)
        h.key = cat.key
        h:ClearAllPoints()
        h:SetPoint("TOPLEFT", child, "TOPLEFT", x, -y)
        h:SetWidth(colW)
        h.text:SetText(Azaath.Tracked(cat.label))
        h.count:SetText(n)
        SetArrow(h, collapsed[cat.key])

        if viewMode == "bags" and bagID and bagID >= 1 and bagID <= 4 then
            h.unequipBtn.bagID = bagID
            h.unequipBtn.occupied = occupied or 0
            local c = ((occupied or 0) == 0) and COL.iconOff or { 0.45, 0.45, 0.45 }
            h.unequipIcon:SetVertexColor(c[1], c[2], c[3])
            h.unequipBtn:Show()
            h.hatch:ClearAllPoints()
            h.hatch:SetPoint("LEFT", h.unequipBtn, "RIGHT", 6, 0)
        else
            h.unequipBtn.bagID = nil
            h.unequipBtn:Hide()
            h.hatch:ClearAllPoints()
            h.hatch:SetPoint("LEFT", h.text, "RIGHT", 6, 0)
        end

        -- hachura entre o título/botão e o contador (some se não couber)
        local extraBtn = h.unequipBtn:IsShown() and 21 or 0
        local room = colW - h.text:GetStringWidth() - 6 - extraBtn - (h.count:GetStringWidth() + 8 + 15) - 6
        if room >= 16 then
            h.hatch:SetWidth(min(110, room))
            h.hatch:Show()
        else
            h.hatch:Hide()
        end
        h:Show()
        return col, x, y + SECTION_HEAD
    end

    local function Finish(col, top, rows)
        colY[col] = top + max(0, rows * step - SPACING) + SECTION_GAP
    end

    local function Place(b, x, top, i)
        local c, r = (i - 1) % perCol, floor((i - 1) / perCol)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", child, "TOPLEFT", x + c * step, -(top + r * step))
        b:Show()
    end

    local sorter = SORTERS[db.sort] or SORTERS.recent

    if viewMode == "bags" then
        ------------------------------------------------------------------------
        -- Modo Bolsas Separadas: cada bolsa tem sua própria seção
        ------------------------------------------------------------------------
        for bag = FIRST_BAG, LAST_BAG do
            local slots = BagVisible(bag) and GetContainerNumSlots(bag) or 0
            if (bag == 0 and BagVisible(0)) or slots > 0 then
                local bagItems = {}
                local occupied = 0
                for slot = 1, slots do
                    local b = GetButton(bag, slot)
                    local texture, count, locked, quality = GetContainerItemInfo(bag, slot)
                    if texture then
                        occupied = occupied + 1
                        local link = GetContainerItemLink(bag, slot)
                        local name, _, q, level, _, itemType = Azaath.API.GetItemInfo(link or "")
                        if Azaath.IsSecret(quality) or not quality or quality < 0 then
                            quality = q
                        end
                        local classID = API.GetItemInfoInstant and link and select(6, API.GetItemInfoInstant(link))
                        bagItems[slot] = {
                            bag = bag, slot = slot, button = b, texture = texture, count = count,
                            locked = locked, quality = quality, level = level, name = name,
                            new = IsNewItem(bag, slot),
                            cat = Categorize(quality, itemType, classID),
                        }
                        ApplyQuestInfo(bagItems[slot], bag, slot)
                    else
                        bagItems[slot] = false
                    end
                end

                local cat = {
                    key = "bag_" .. bag,
                    label = GetBagDisplayName(bag),
                }
                local isCollapsed = collapsed[cat.key]
                local countText = format("%d/%d", occupied, slots)
                local col, x, top = Section(cat, countText, bag, occupied)
                if isCollapsed then
                    for slot = 1, slots do
                        local b = GetButton(bag, slot)
                        b:Hide()
                    end
                    Finish(col, top - 6, 0)
                else
                    local order = {}
                    if db.sort == "recent" then
                        for slot = 1, slots do order[slot] = slot end
                    else
                        local occupiedList, emptyList = {}, {}
                        for slot = 1, slots do
                            if bagItems[slot] then
                                occupiedList[#occupiedList + 1] = bagItems[slot]
                            else
                                emptyList[#emptyList + 1] = slot
                            end
                        end
                        table.sort(occupiedList, sorter)
                        for _, info in ipairs(occupiedList) do
                            order[#order + 1] = info.slot
                        end
                        for _, slot in ipairs(emptyList) do
                            order[#order + 1] = slot
                        end
                    end

                    for i, slot in ipairs(order) do
                        local b = GetButton(bag, slot)
                        local info = bagItems[slot]
                        if info then
                            FillButton(b, bag, slot, info)
                        else
                            SetSlotKind(b, "slot")
                            b.azBg:SetVertexColor(1, 1, 1)
                            b.azLevel:SetText("")
                            b.azBadge:Hide()
                            b.azLock:Hide()
                            b.azCat = nil
                            b.azQuestBang:Hide()
                            b.azDur:Hide()
                            b.azFree:SetText("")
                            b.azName = ""
                            if b.icon then
                                b.icon:SetTexture(nil)
                                b.icon:Hide()
                            end
                            if b.Count then b.Count:Hide() end
                            if b.Cooldown then b.Cooldown:Hide() end
                        end
                        Place(b, x, top, i)
                        b:Show()
                    end
                    Finish(col, top, math.ceil(slots / perCol))
                end

                local list = buttons[bag]
                if list then
                    for slot = slots + 1, #list do list[slot]:Hide() end
                end
            else
                local list = buttons[bag]
                if list then
                    for slot = 1, #list do list[slot]:Hide() end
                end
            end
        end
    else
        ------------------------------------------------------------------------
        -- Modo Estilo Azaath: agrupamento por categorias
        ------------------------------------------------------------------------
        local groups = {}
        for _, cat in ipairs(CATEGORIES) do groups[cat.key] = {} end
        local firstFree, freeCount = nil, 0

        for bag = FIRST_BAG, LAST_BAG do
            local slots = BagVisible(bag) and GetContainerNumSlots(bag) or 0
            for slot = 1, slots do
                local b = GetButton(bag, slot)
                local texture, count, locked, quality = GetContainerItemInfo(bag, slot)
                if texture then
                    local link = GetContainerItemLink(bag, slot)
                    local name, _, q, level, _, itemType = Azaath.API.GetItemInfo(link or "")
                    if Azaath.IsSecret(quality) or not quality or quality < 0 then
                        quality = q
                    end
                    local info = {
                        bag = bag, slot = slot, button = b, texture = texture, count = count,
                        locked = locked, quality = quality, level = level, name = name,
                        new = IsNewItem(bag, slot),
                    }
                    local classID = API.GetItemInfoInstant and link and select(6, API.GetItemInfoInstant(link))
                    info.cat = Categorize(quality, itemType, classID)
                    ApplyQuestInfo(info, bag, slot)
                    local g = groups[info.cat]
                    g[#g + 1] = info
                else
                    freeCount = freeCount + 1
                    if not firstFree then firstFree = b end
                    b:Hide()
                end
            end
            local list = buttons[bag]
            if list then
                for slot = slots + 1, #list do list[slot]:Hide() end
            end
        end

        local catF = M.catFilter -- chips de categoria (skin Azaath)
        for _, cat in ipairs(CATEGORIES) do
            local g = groups[cat.key]
            local isCollapsed = collapsed[cat.key]
            if catF and not catF[cat.key] then
                for _, info in ipairs(g) do info.button:Hide() end
                if cat.key == "free" and firstFree then firstFree:Hide() end
            elseif cat.key == "free" then
                if firstFree then
                    local col, x, top = Section(cat, freeCount)
                    if isCollapsed then
                        firstFree:Hide()
                        Finish(col, top - 6, 0)
                    else
                        SetSlotKind(firstFree, "slot")
                        firstFree.azBg:SetVertexColor(1, 1, 1)
                        firstFree.azLevel:SetText("")
                        firstFree.azBadge:Hide()
                        firstFree.azLock:Hide()
                        firstFree.azCat = nil
                        firstFree.azQuestBang:Hide()
                        firstFree.azDur:Hide()
                        firstFree.azFree:SetText(freeCount)
                        firstFree.azName = nil
                        if firstFree.icon then firstFree.icon:SetTexture(nil) end
                        if firstFree.Count then firstFree.Count:Hide() end
                        if firstFree.Cooldown then firstFree.Cooldown:Hide() end
                        Place(firstFree, x, top, 1)
                        firstFree:SetAlpha(1)
                        Finish(col, top, 1)
                    end
                end
            elseif #g > 0 then
                local col, x, top = Section(cat, #g)
                if isCollapsed then
                    for _, info in ipairs(g) do info.button:Hide() end
                    Finish(col, top - 6, 0)
                else
                    table.sort(g, sorter)
                    for i, info in ipairs(g) do
                        FillButton(info.button, info.bag, info.slot, info)
                        Place(info.button, x, top, i)
                    end
                    Finish(col, top, math.ceil(#g / perCol))
                end
            end
        end
    end

    for i = hIndex + 1, #headers do headers[i]:Hide() end
    if IBar then IBar.SetWidth(innerW); IBar.Update() end
    if UpdateViewTabs then UpdateViewTabs() end

    -- 3) tamanhos
    local contentH = max(1, max(colY[1], colY[2]) - SECTION_GAP)
    child:SetWidth(innerW)
    child:SetHeight(contentH)
    local bodyH = min(contentH, db.maxHeight)
    local chrome = (M.bodyTop or (HEADER_H + (M.bagBarH or 0))) + BODY_TOP + 10 + FOOTER_H
    if docked and dockHeight then
        -- encaixado ao personagem: painel de altura fixa, como no Azaath
        bodyH = max(160, dockHeight - chrome, bodyH)
    else
        bodyH = max(160, bodyH)
    end
    scroll:SetWidth(innerW)
    scroll:SetHeight(bodyH)
    scroll:UpdateScrollChildRect()
    if scroll:GetVerticalScroll() > scroll:GetVerticalScrollRange() then
        scroll:SetVerticalScroll(scroll:GetVerticalScrollRange())
    end

    local width = innerW + PAD * 2
    frame:SetWidth(width)
    frame:SetHeight(chrome + bodyH)
    -- o rodapé mantém a proporção da textura (512x64) para a moldura casar
    footerTex:SetHeight(floor(width / 8 + 0.5))

    if M.SkinUpdate then M.SkinUpdate() end
    UpdateMoney()
    ApplyFilter()
    -- os botões mudaram de lugar: solta o botão seguro (o item sob o mouse
    -- recebe OnEnter de novo e o reposiciona)
    DetachSecure()
end

--------------------------------------------------------------------------------
-- Encaixe ao lado do personagem (a câmera fica a cargo do módulo Character)
--------------------------------------------------------------------------------
local DOCK_GAP = 50

local function GetCharacter()
    local charMod = Azaath:GetModule("Character")
    if charMod and Azaath.db.character.enabled and charMod.frame then return charMod end
end

-- Bolsas abertas pelo jogo (vendedor, banco, correio, troca, leilão): o
-- inventário abre sozinho, sem girar a câmera para o personagem.
local INTERACTION_FRAMES = { "AzaathUIMerchant", "MerchantFrame", "BankFrame", "MailFrame", "TradeFrame",
                             "AuctionFrame", "AuctionHouseFrame", "GuildBankFrame" }
local function IsInteracting()
    for _, name in ipairs(INTERACTION_FRAMES) do
        local f = _G[name]
        if f and f:IsShown() then return true end
    end
    return false
end

--------------------------------------------------------------------------------
-- Janela
--------------------------------------------------------------------------------
local function IsMerchantActive()
    local mf = _G.MerchantFrame
    local nm = _G.AzaathUIMerchant
    return (nm and nm:IsShown()) or (mf and mf:IsShown())
end

local function SavePosition()
    if IsMerchantActive() then return end
    local right, top = frame:GetRight(), frame:GetTop()
    if not (right and top) then return end
    M.db.pos = { x = right - UIParent:GetRight(), y = top - UIParent:GetTop() }
end
M.SavePosition = SavePosition

local function LoadFonts()
    local media = Azaath.media
    local probe = UIParent:CreateFontString(nil, "BACKGROUND")
    local path = media.path .. "Fonts\\Cinzel-Regular.ttf"
    local ok = pcall(probe.SetFont, probe, path, 12, "")
    fontSection = (ok and probe:GetFont()) and path or media.fontTitleB
    probe:Hide()
end

local function BuildPanelTextures()
    -- cabeçalho azul (borda rasgada no topo e nas laterais)
    headerTex = frame:CreateTexture(nil, "BACKGROUND")
    headerTex:SetTexture(TEX .. "Header")
    headerTex:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    headerTex:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    headerTex:SetHeight(HEADER_H)

    -- rodapé (borda rasgada embaixo); altura definida no Rebuild
    footerTex = frame:CreateTexture(nil, "BACKGROUND")
    footerTex:SetTexture(TEX .. "Footer")
    footerTex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    footerTex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    footerTex:SetHeight(56)

    -- corpo entre os dois
    bodyTex = frame:CreateTexture(nil, "BACKGROUND")
    bodyTex:SetTexture(TEX .. "Body")
    bodyTex:SetPoint("TOPLEFT", headerTex, "BOTTOMLEFT", 0, 0)
    bodyTex:SetPoint("TOPRIGHT", headerTex, "BOTTOMRIGHT", 0, 0)
    bodyTex:SetPoint("BOTTOMLEFT", footerTex, "TOPLEFT", 0, 0)
    bodyTex:SetPoint("BOTTOMRIGHT", footerTex, "TOPRIGHT", 0, 0)

    -- filete claro sob o cabeçalho
    local sep = frame:CreateTexture(nil, "BORDER")
    sep:SetTexture(Azaath.media.blank)
    SetColor(sep, COL.sepHead)
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -HEADER_H)
    sep:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -HEADER_H)
    M.chromeExtra = { sep }

    -- filete do rodapé
    local foot = frame:CreateTexture(nil, "BORDER")
    foot:SetTexture(Azaath.media.blank)
    SetColor(foot, COL.sepFoot)
    foot:SetHeight(1)
    foot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD - 10, FOOTER_H)
    foot:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(PAD - 10), FOOTER_H)
    M.chromeExtra[2] = foot
end

local function BuildSort(header)
    local media = Azaath.media
    local ICON, GAP = 15, 10
    local prev
    for i = #SORTS, 1, -1 do
        local s = SORTS[i]
        local sb = CreateFrame("Button", nil, header)
        sb.key = s.key
        sb:SetWidth(ICON)
        sb:SetHeight(ICON)
        if prev then
            sb:SetPoint("RIGHT", prev, "LEFT", -GAP, 0)
        else
            -- alinhado verticalmente com a busca (y -52, altura 20)
            sb:SetPoint("TOPRIGHT", header, "TOPRIGHT", -(PAD + 2), -54.5)
        end
        sb.icon = sb:CreateTexture(nil, "ARTWORK")
        sb.icon:SetTexture(TEX .. s.tex)
        sb.icon:SetAllPoints(sb)
        -- sublinhado branco do modo ativo
        sb.under = sb:CreateTexture(nil, "ARTWORK")
        sb.under:SetTexture(media.blank)
        sb.under:SetVertexColor(1, 1, 1, 0.95)
        sb.under:SetHeight(2)
        sb.under:SetPoint("TOPLEFT", sb, "BOTTOMLEFT", -2, -3)
        sb.under:SetPoint("TOPRIGHT", sb, "BOTTOMRIGHT", 2, -3)
        sb:SetScript("OnClick", function(self)
            M.db.sort = self.key
            UpdateSortButtons()
            dirty = true
        end)
        sb:SetScript("OnEnter", function(self)
            self.hover = true
            UpdateSortButtons()
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(s.tip)
            GameTooltip:AddLine(s.desc, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        sb:SetScript("OnLeave", function(self)
            self.hover = nil
            UpdateSortButtons()
            GameTooltip:Hide()
        end)
        sortButtons[i] = sb
        prev = sb
    end

    local label = Text(header, media.font, 13, COL.sortText)
    label:SetShadowOffset(0, 0)
    label:SetPoint("RIGHT", prev, "LEFT", -9, 0)
    label:SetText("Ordenar")
    UpdateSortButtons()
    return label
end

local viewTabs = {}
function UpdateViewTabs()
    local mode = M.db and (M.db.viewMode or "az") or "az"
    for _, t in ipairs(viewTabs) do
        local on = (t.key == mode)
        if on then
            t.text:SetTextColor(COL.tabOn[1], COL.tabOn[2], COL.tabOn[3])
            t.under:Show()
        else
            t.under:Hide()
            local c = t.hover and COL.text or COL.tabOff
            t.text:SetTextColor(c[1], c[2], c[3])
        end
    end
end

local VIEW_MODES = {
    { key = "az",   label = "Categorias", tip = "Estilo Azaath",
      desc = "Agrupa os itens por categorias (armas, consumíveis, materiais...)." },
    { key = "bags", label = "Bolsas",     tip = "Bolsas separadas",
      desc = "Exibe cada bolsa em uma seção individual." },
}

local function BuildViewTabs(header)
    local media = Azaath.media
    local prev
    for i = #VIEW_MODES, 1, -1 do
        local def = VIEW_MODES[i]
        local t = CreateFrame("Button", nil, header)
        t.key = def.key
        t:SetHeight(22)
        t.text = Text(t, fontSection, 12, COL.tabOff)
        t.text:SetPoint("CENTER", t, "CENTER", 0, 1)
        t.text:SetText(Azaath.Tracked(def.label))
        local tw = t.text:GetStringWidth() or 50
        t:SetWidth(tw + 14)

        t.under = t:CreateTexture(nil, "ARTWORK")
        t.under:SetTexture(media.blank)
        SetColor(t.under, COL.gold)
        t.under:SetHeight(2)
        t.under:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 2, -1)
        t.under:SetPoint("BOTTOMRIGHT", t, "BOTTOMRIGHT", -2, -1)

        if prev then
            t:SetPoint("RIGHT", prev, "LEFT", -6, 0)
        else
            t:SetPoint("TOPRIGHT", header, "TOPRIGHT", -(PAD + 2), -22)
        end

        t:SetScript("OnClick", function(self)
            if M.db.viewMode ~= self.key then
                M.db.viewMode = self.key
                UpdateViewTabs()
                dirty = true
            end
        end)
        t:SetScript("OnEnter", function(self)
            self.hover = true
            UpdateViewTabs()
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(def.tip)
            GameTooltip:AddLine(def.desc, 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        t:SetScript("OnLeave", function(self)
            self.hover = nil
            UpdateViewTabs()
            GameTooltip:Hide()
        end)
        viewTabs[#viewTabs + 1] = t
        prev = t
    end
    UpdateViewTabs()
    return prev
end

local function Build()
    local media = Azaath.media

    frame = CreateFrame("Frame", "AzaathUIInventory", UIParent)
    M.frame = frame
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetWidth(ColumnWidth() * 2 + COL_GAP + PAD * 2)
    frame:SetHeight(400)
    frame:Hide()
    tinsert(UISpecialFrames, "AzaathUIInventory")

    BuildPanelTextures()

    -- Cabeçalho (arrastável fora do personagem)
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_H)
    header:EnableMouse(true)
    -- arrastar pelo cabeçalho ou por qualquer parte vazia da janela (os botões de item têm o próprio arrasto).
    -- Junto do personagem (encaixada) também move: a posição fica salva à parte (db.dockPos), mantendo a
    -- altura do personagem; sozinha, vale db.pos. Se o personagem já fechou e ficou o estado velho, solta antes.
    local function DragStart()
        if docked then
            local charMod = GetCharacter()
            if not (charMod and charMod.frame and charMod.frame:IsShown()) then docked, dockHeight = false, nil end
        end
        if InCombatLockdown() and frame:IsProtected() then return end
        frame.azMoving = true
        frame:StartMoving()
    end
    local function DragStop()
        if not frame.azMoving then return end
        frame.azMoving = nil
        frame:StopMovingOrSizing()
        if docked then
            local right, top = frame:GetRight(), frame:GetTop()
            if right and top then M.db.dockPos = { x = right - UIParent:GetRight(), y = top - UIParent:GetTop() } end
        else
            SavePosition()
        end
    end
    for _, w in ipairs({ header, frame }) do
        w:RegisterForDrag("LeftButton")
        w:SetScript("OnDragStart", DragStart)
        w:SetScript("OnDragStop", DragStop)
    end

    local title = Text(header, fontSection, 19, COL.title)
    title:SetPoint("TOPLEFT", header, "TOPLEFT", PAD + 2, -22)
    title:SetText(Azaath.Tracked("Inventário"))

    BuildViewTabs(header)

    -- Busca
    searchBox = CreateFrame("EditBox", "AzaathUIInventorySearch", header)
    searchBox:SetHeight(20)
    searchBox:SetAutoFocus(false)
    searchBox:SetFont(media.font, 13, "")
    searchBox:SetTextColor(0.90, 0.90, 0.88)
    searchBox:SetTextInsets(8, 24, 0, 0)
    Azaath.SetBackdrop(searchBox, { bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 } })
    searchBox:SetBackdropColor(COL.searchBg[1], COL.searchBg[2], COL.searchBg[3], 0.96)
    searchBox:SetBackdropBorderColor(COL.searchBd[1], COL.searchBd[2], COL.searchBd[3], 1)

    local sortLabel = BuildSort(header)
    searchBox:SetPoint("TOPLEFT", header, "TOPLEFT", PAD, -52)
    searchBox:SetPoint("RIGHT", sortLabel, "LEFT", -22, 0)

    local placeholder = searchBox:CreateFontString(nil, "OVERLAY")
    placeholder:SetFont(media.font, 13, "")
    placeholder:SetTextColor(0.46, 0.49, 0.53)
    placeholder:SetPoint("LEFT", searchBox, "LEFT", 9, 0)
    placeholder:SetText("Buscar")

    -- "?" dourado
    local help = CreateFrame("Frame", nil, searchBox)
    help:SetWidth(14)
    help:SetHeight(14)
    help:SetPoint("RIGHT", searchBox, "RIGHT", -5, 0)
    help:EnableMouse(true)
    local helpTex = help:CreateTexture(nil, "ARTWORK")
    helpTex:SetTexture(TEX .. "Help")
    helpTex:SetAllPoints(help)
    local helpQ = help:CreateFontString(nil, "OVERLAY")
    helpQ:SetFont(media.fontBold, 11, "")
    helpQ:SetTextColor(0.10, 0.07, 0.02)
    helpQ:SetPoint("CENTER", help, "CENTER", 0.5, 0)
    helpQ:SetText("?")
    help:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
        GameTooltip:SetText("Busca")
        GameTooltip:AddLine("Digite parte do nome do item: os demais ficam apagados. Esc limpa a busca.",
            0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    help:SetScript("OnLeave", function() GameTooltip:Hide() end)

    searchBox:SetScript("OnTextChanged", function(self)
        local text = self:GetText() or ""
        if text == "" then placeholder:Show() else placeholder:Hide() end
        filter = text:lower()
        ApplyFilter()
    end)
    searchBox:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
    searchBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- Faixa "Mochilas" (Modules/InventoryBags.lua): bolsas equipadas, card ao passar
    -- o mouse, clique mostra só aquela bolsa; espaço livre à direita
    local IB = Azaath.InventoryBags
    if IB then
        M.bagBarH = IB.HEIGHT
        IB.Build(frame, PAD, HEADER_H + 8, ColumnWidth() * 2 + COL_GAP, FIRST_BAG, LAST_BAG, function()
            DetachSecure()
            scroll:SetVerticalScroll(0)
            dirty = true
        end)
    end

    -- Corpo rolável
    scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", PAD, -((M.bodyTop or (HEADER_H + (M.bagBarH or 0))) + BODY_TOP))
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        DetachSecure() -- o item sob o mouse muda ao rolar
        local v = self:GetVerticalScroll() - delta * (SlotSize() + SPACING) * 2
        self:SetVerticalScroll(max(0, min(v, self:GetVerticalScrollRange())))
    end)
    child = CreateFrame("Frame", nil, scroll)
    child:SetWidth(1)
    child:SetHeight(1)
    scroll:SetScrollChild(child)

    -- Rodapé: dinheiro
    local footY = floor(FOOTER_H / 2 + 5) -- centro vertical entre o filete e a moldura

    moneyBox = CreateFrame("Frame", nil, frame)
    moneyBox:SetWidth(200)
    moneyBox:SetHeight(20)
    moneyBox:SetPoint("LEFT", frame, "BOTTOMLEFT", PAD + 2, footY)
    moneyBox.coins = {}
    for i = 1, 3 do
        local icon = moneyBox:CreateTexture(nil, "ARTWORK")
        icon:SetTexture(COIN_TEX[i])
        icon:SetWidth(14)
        icon:SetHeight(14)
        local text = Text(moneyBox, media.fontTitleB, 17, COL.number)
        text:SetPoint("LEFT", icon, "RIGHT", 4, 0)
        moneyBox.coins[i] = { icon = icon, text = text }
    end
    moneyBox:EnableMouse(true)
    moneyBox:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Dinheiro")
        GameTooltip:AddLine(Azaath.FormatMoney(GetMoney()), 1, 1, 1)
        GameTooltip:Show()
    end)
    moneyBox:SetScript("OnLeave", function() GameTooltip:Hide() end)

    -- Mini Menu Radial de Consumíveis (arrastar da mochila para configurar o menu G)
    local miniRadialBtn = CreateFrame("Button", nil, frame)
    miniRadialBtn:SetSize(96, 22)
    miniRadialBtn:SetPoint("RIGHT", frame, "BOTTOMRIGHT", -PAD, footY)
    Azaath.SetBackdrop(miniRadialBtn, { bgFile = media.blank, edgeFile = media.blank, edgeSize = 1 })
    miniRadialBtn:SetBackdropColor(COL.searchBg[1], COL.searchBg[2], COL.searchBg[3], 0.92)
    miniRadialBtn:SetBackdropBorderColor(COL.sepHead[1], COL.sepHead[2], COL.sepHead[3], 0.9)

    local mrBtnIcon = miniRadialBtn:CreateTexture(nil, "ARTWORK")
    mrBtnIcon:SetSize(13, 13)
    mrBtnIcon:SetPoint("LEFT", 7, 0)
    mrBtnIcon:SetTexture(media.path .. "Ring.tga")
    mrBtnIcon:SetVertexColor(COL.gold[1], COL.gold[2], COL.gold[3], 0.9)

    local mrBtnText = Text(miniRadialBtn, media.fontBold, 11, COL.title)
    mrBtnText:SetPoint("LEFT", mrBtnIcon, "RIGHT", 5, 0)
    mrBtnText:SetText("Radial (G)")

    -- "Trancar item" (Modules/InventoryLock.lua): liga o modo em que o clique tranca/destrava
    local IL = Azaath.InventoryLock
    if IL then
        local lockBtn = CreateFrame("Button", nil, frame)
        lockBtn:SetSize(104, 22)
        lockBtn:SetPoint("RIGHT", miniRadialBtn, "LEFT", -8, 0)
        Azaath.SetBackdrop(lockBtn, { bgFile = media.blank, edgeFile = media.blank, edgeSize = 1 })
        local lkIcon = lockBtn:CreateTexture(nil, "ARTWORK")
        lkIcon:SetSize(12, 12)
        lkIcon:SetPoint("LEFT", 7, 0)
        lkIcon:SetTexture(media.path .. IL.ICON)
        local lkText = Text(lockBtn, media.fontBold, 11, COL.title)
        lkText:SetPoint("LEFT", lkIcon, "RIGHT", 5, 0)
        lkText:SetText("Trancar item")
        local function Paint(on)
            local bd = on and COL.gold or COL.sepHead
            lockBtn:SetBackdropColor(COL.searchBg[1], COL.searchBg[2], COL.searchBg[3], 0.92)
            lockBtn:SetBackdropBorderColor(bd[1], bd[2], bd[3], on and 1 or 0.9)
            lkIcon:SetVertexColor(on and 1 or 0.8, on and 0.92 or 0.8, on and 0.7 or 0.8)
            lkText:SetTextColor((on and COL.gold or COL.title)[1], (on and COL.gold or COL.title)[2],
                (on and COL.gold or COL.title)[3])
        end
        Paint(false)
        IL.onModeChanged = function(on)
            Paint(on)
            DetachSecure() -- o botão seguro sob o mouse refaz o clique direito
        end
        lockBtn:SetScript("OnClick", function() IL.SetMode(not IL.mode) end)
        lockBtn:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText("Trancar item")
            GameTooltip:AddLine("Ligado, clicar num item tranca ou destrava. Item trancado não é vendido "
                .. "nem destruído (cadeado no canto). Clique de novo ou feche a mochila para sair.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
        end)
        lockBtn:SetScript("OnLeave", function() GameTooltip:Hide() end)
        frame:HookScript("OnHide", function() if IL.mode then IL.SetMode(false) end end)
        M.lockBtn, M.lockText, M.lockIcon = lockBtn, lkText, lkIcon
    end

    local miniRadial = CreateFrame("Frame", "AzaathUIInventoryMiniRadial", frame)
    miniRadial:SetSize(120, 120)
    miniRadial:SetPoint("RIGHT", frame, "LEFT", -14, -64)
    miniRadial:SetFrameStrata("HIGH")
    miniRadial:EnableMouse(false)
    miniRadial:Hide()
    M.miniRadial = miniRadial -- no modo "painel" fica preso embaixo do painel Equipado (M:SyncEquipPanel)

    local wheelHost = CreateFrame("Frame", nil, miniRadial)
    wheelHost:SetAllPoints(miniRadial)

    local wheelDisc = wheelHost:CreateTexture(nil, "BACKGROUND")
    wheelDisc:SetSize(116, 116)
    wheelDisc:SetPoint("CENTER")
    wheelDisc:SetTexture(media.path .. "Disc.tga")
    wheelDisc:SetVertexColor(0.03, 0.04, 0.05, 0.85)

    local wheelRing = wheelHost:CreateTexture(nil, "BORDER")
    wheelRing:SetSize(118, 118)
    wheelRing:SetPoint("CENTER")
    wheelRing:SetTexture(media.path .. "Ring.tga")
    wheelRing:SetVertexColor(COL.gold[1], COL.gold[2], COL.gold[3], 0.45)

    local wheelCenterKey = Text(wheelHost, fontSection, 13, COL.gold)
    wheelCenterKey:SetPoint("CENTER", 0, 0)
    wheelCenterKey:SetAlpha(0.70)
    wheelCenterKey:SetText("G")

    local mrSlots = {}
    local draggingSlot, draggingItemID
    local dragGhost = CreateFrame("Frame", nil, UIParent)
    dragGhost:SetSize(24, 24)
    dragGhost:SetFrameStrata("TOOLTIP")
    dragGhost:EnableMouse(false)
    dragGhost:Hide()
    dragGhost.tex = dragGhost:CreateTexture(nil, "OVERLAY")
    dragGhost.tex:SetAllPoints()
    dragGhost.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    dragGhost:SetScript("OnUpdate", function(self)
        local x, y = _G.GetCursorPosition()
        local s = UIParent:GetEffectiveScale() or 1
        self:ClearAllPoints()
        self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x / s, y / s)
    end)

    local function GetRadialSaved()
        local AC = Azaath.ActionCam
        return (AC and AC.GetRadialConsumables and AC.GetRadialConsumables())
            or (Azaath.db and Azaath.db.actioncam and Azaath.db.actioncam.radialConsumables)
            or {}
    end

    local function SetRadialSlot(slotIdx, itemID)
        if Azaath.ActionCam and Azaath.ActionCam.SetRadialConsumableSlot then
            Azaath.ActionCam.SetRadialConsumableSlot(slotIdx, itemID)
        elseif Azaath.db and Azaath.db.actioncam then
            Azaath.db.actioncam.radialConsumables = Azaath.db.actioncam.radialConsumables or {}
            Azaath.db.actioncam.radialConsumables[slotIdx] = itemID
        end
    end

    local function RefreshMiniRadial()
        local saved = GetRadialSaved()
        for i = 1, 8 do
            local btn = mrSlots[i]
            local id = tonumber(saved[i])
            if id and id > 0 then
                local icon = (_G.C_Item and _G.C_Item.GetItemIconByID and _G.C_Item.GetItemIconByID(id))
                    or (_G.GetItemIcon and _G.GetItemIcon(id))
                    or 134400
                btn.icon:SetTexture(icon)
                btn.icon:Show()
                btn.plus:Hide()
                local count = (_G.C_Item and _G.C_Item.GetItemCount and _G.C_Item.GetItemCount(id, false, true))
                    or (_G.GetItemCount and _G.GetItemCount(id, false, true))
                    or 0
                btn.count:SetText(count > 0 and tostring(count) or "0")
                btn.count:SetTextColor(count > 0 and COL.number[1] or 0.85, count > 0 and COL.number[2] or 0.30, count > 0 and COL.number[3] or 0.28)
                btn.rim:SetVertexColor(COL.gold[1], COL.gold[2], COL.gold[3], 0.80)
            else
                btn.icon:Hide()
                btn.plus:Show()
                btn.count:SetText("")
                btn.rim:SetVertexColor(COL.line1[1], COL.line1[2], COL.line1[3], 0.85)
            end
        end
    end

    local function PlaceRadialItem(slotIdx)
        local kind, itemID = _G.GetCursorInfo()
        if kind == "item" and itemID then
            _G.ClearCursor()
            SetRadialSlot(slotIdx, itemID)
            RefreshMiniRadial()
            return true
        end
        return false
    end

    for i = 1, 8 do
        local angle = 2 * math.pi * (i - 1) / 8
        local rx = 39 * math.sin(angle)
        local ry = 39 * math.cos(angle)

        local btn = CreateFrame("Button", nil, wheelHost)
        btn:SetSize(26, 26)
        btn:SetPoint("CENTER", wheelHost, "CENTER", rx, ry)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        btn:RegisterForDrag("LeftButton")

        local bg = btn:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetTexture(media.path .. "Inventory\\SlotRound.tga")
        bg:SetVertexColor(0.14, 0.14, 0.16, 0.95)

        local mask = btn:CreateMaskTexture()
        mask:SetSize(22, 22)
        mask:SetPoint("CENTER")
        mask:SetTexture(media.path .. "Inventory\\RoundMask.tga", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")

        btn.icon = btn:CreateTexture(nil, "ARTWORK")
        btn.icon:SetSize(22, 22)
        btn.icon:SetPoint("CENTER")
        btn.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        btn.icon:AddMaskTexture(mask)
        btn.icon:Hide()

        btn.rim = btn:CreateTexture(nil, "OVERLAY")
        btn.rim:SetSize(28, 28)
        btn.rim:SetPoint("CENTER")
        btn.rim:SetTexture(media.path .. "MapUI\\Rim.tga")

        btn.plus = Text(btn, media.fontBold, 11, COL.dim)
        btn.plus:SetPoint("CENTER", 0, 0)
        btn.plus:SetText("+")

        btn.count = btn:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
        btn.count:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", 2, -2)

        btn:SetScript("OnClick", function(_, mouseBtn)
            if PlaceRadialItem(i) then return end
            if mouseBtn == "RightButton" then
                SetRadialSlot(i, nil)
                RefreshMiniRadial()
            end
        end)
        btn:SetScript("OnReceiveDrag", function()
            PlaceRadialItem(i)
        end)
        btn:SetScript("OnDragStart", function()
            local saved = GetRadialSaved()
            local id = tonumber(saved[i])
            if not id or id <= 0 then return end
            draggingSlot = i
            draggingItemID = id
            local icon = (_G.C_Item and _G.C_Item.GetItemIconByID and _G.C_Item.GetItemIconByID(id))
                or (_G.GetItemIcon and _G.GetItemIcon(id))
                or 134400
            dragGhost.tex:SetTexture(icon)
            dragGhost:Show()
            btn.icon:SetAlpha(0.35)
        end)
        btn:SetScript("OnDragStop", function()
            btn.icon:SetAlpha(1)
            dragGhost:Hide()
            if not draggingSlot then return end
            local srcSlot, srcID = draggingSlot, draggingItemID
            draggingSlot, draggingItemID = nil, nil

            local targetSlot = nil
            for j = 1, 8 do
                if mrSlots[j]:IsMouseOver() then
                    targetSlot = j
                    break
                end
            end
            if targetSlot == srcSlot then
                return
            elseif targetSlot then
                local saved = GetRadialSaved()
                local dstID = tonumber(saved[targetSlot])
                SetRadialSlot(targetSlot, srcID)
                SetRadialSlot(srcSlot, (dstID and dstID > 0) and dstID or nil)
            else
                -- Arrastado para fora: remove o item (inclusive itens zerados)
                SetRadialSlot(srcSlot, nil)
            end
            RefreshMiniRadial()
        end)
        btn:SetScript("OnEnter", function(self)
            local saved = GetRadialSaved()
            local id = tonumber(saved[i])
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            if id and id > 0 then
                GameTooltip:SetItemByID(id)
                GameTooltip:AddLine(" ")
                GameTooltip:AddLine("Arraste outro item para substituir", 0.7, 0.85, 0.7)
                GameTooltip:AddLine("Arraste para fora ou clique direito para remover", 0.9, 0.45, 0.45)
            else
                GameTooltip:SetText("Slot Radial " .. i .. " (Vazio)")
                GameTooltip:AddLine("Arraste um consumível da mochila para cá", 0.8, 0.8, 0.8, true)
            end
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function() GameTooltip:Hide() end)

        btn.idx, btn.bg, btn.mask = i, bg, mask
        mrSlots[i] = btn
    end
    -- a skin Azaath (InventorySkin.lua) veste o mini radial com a arte do menu G
    M.mini = { frame = miniRadial, host = wheelHost, disc = wheelDisc, ring = wheelRing, key = wheelCenterKey,
               slots = mrSlots, refresh = function() RefreshMiniRadial() end }

    miniRadialBtn:SetScript("OnClick", function()
        local EP = Azaath.InventoryEquip
        if M:OpenMode() == "panel" and not (EP and EP.IsShown()) then
            miniRadial:Hide()
            return
        end
        if miniRadial:IsShown() then
            miniRadial:Hide()
        else
            RefreshMiniRadial()
            miniRadial:Show()
        end
    end)
    miniRadialBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 0.95)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Mini Menu Radial (G)")
        GameTooltip:AddLine("Clique para mostrar/ocultar os 8 slots de consumíveis.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    miniRadialBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(COL.sepHead[1], COL.sepHead[2], COL.sepHead[3], 0.9)
        GameTooltip:Hide()
    end)

    -- peças que a skin Azaath (Modules/InventorySkin.lua) reveste e reposiciona
    M.ui = { header = header, title = title, search = searchBox, placeholder = placeholder, sortLabel = sortLabel,
             sortButtons = sortButtons, viewTabs = viewTabs, scroll = scroll, money = moneyBox,
             radialBtn = miniRadialBtn, radialText = mrBtnText, radialIcon = mrBtnIcon,
             headerTex = headerTex, bodyTex = bodyTex, footerTex = footerTex, pad = PAD, footerH = FOOTER_H }
    local skin = Azaath.InventorySkin
    if skin and skin.Active() then skin.Apply(M) end

    if Azaath.ActionCam and Azaath.ActionCam.OnRadialConsumablesChanged then
        Azaath.ActionCam.OnRadialConsumablesChanged(RefreshMiniRadial)
    end
    RefreshMiniRadial()

    frame:SetScript("OnShow", function()
        RefreshMiniRadial()
        -- abre o personagem junto (exceto quando o jogo abriu as bolsas num vendedor etc.)
        local charMod = GetCharacter()
        if M.db.unified ~= false and charMod and not charMod.frame:IsShown()
            and not IsInteracting() and not InCombatLockdown() then
            charMod:Open(true) -- o OnShow do personagem chama M:Reposition()
        else
            M:Reposition()
        end
    end)
    -- fechar a nossa janela fecha as bolsas da Blizzard e o personagem
    frame:SetScript("OnHide", function()
        searchBox:ClearFocus()
        -- a escolha de uma bolsa só vale enquanto a mochila está aberta
        if Azaath.InventoryBags and Azaath.InventoryBags.selected then
            Azaath.InventoryBags.selected = nil
            dirty = true
        end
        DetachSecure()
        if M.db.unified ~= false then
            local charMod = GetCharacter()
            if charMod and charMod.frame:IsShown() then
                charMod:Close(true)
            end
        end
        if not frame.azClosing then
            frame.azClosing = true
            local ok, err = pcall(function()
                if _G.CloseAllBags then
                    _G.CloseAllBags()
                elseif _G.CloseBackpack then
                    _G.CloseBackpack()
                end
                if AnyBagOpen() then
                    if _G.CloseBackpack then _G.CloseBackpack() end
                    if _G.CloseBag then
                        for bag = FIRST_BAG, LAST_BAG do
                            _G.CloseBag(bag)
                        end
                    end
                    local combined = _G.ContainerFrameCombinedBags
                    if combined and combined:IsShown()
                        and not (combined.IsProtected and combined:IsProtected() and InCombatLockdown()) then
                        combined:Hide()
                    end
                end
            end)
            frame.azClosing = nil
            if not ok and _G.geterrorhandler then _G.geterrorhandler()(err) end
        end
    end)
    frame:SetScript("OnUpdate", function(self, elapsed)
        if not dirty then return end
        self.elapsed = (self.elapsed or 0) + elapsed
        if self.elapsed < THROTTLE then return end
        self.elapsed = 0
        Rebuild()
    end)
end

-- Encaixa à direita do personagem (tela de personagem aberta) ou volta para a
-- posição salva/padrão. Também refaz o layout, pois a altura muda.
function M:Reposition()
    if not frame then return end
    frame:ClearAllPoints()
    if IsMerchantActive() then
        docked, dockHeight = false, nil
        frame:SetScale(0.80)
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -28, 20)
        if frame:IsShown() then Rebuild() else dirty = true end
        return
    end
    frame:SetScale(1)
    local charMod = GetCharacter()
    local doll = charMod and charMod.frame:IsShown() and charMod.doll
    if doll then
        docked = true
        local scale = doll:GetEffectiveScale() / frame:GetEffectiveScale()
        dockHeight = doll:GetHeight() * scale
        local dp = M.db.dockPos
        if dp then
            frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", dp.x, dp.y)
        else
            frame:SetPoint("TOPLEFT", doll, "TOPRIGHT", DOCK_GAP * scale, 0)
        end
    else
        docked, dockHeight = false, nil
        local pos = M.db.pos
        if pos then
            frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", pos.x, pos.y)
        elseif M:OpenMode() == "panel" then
            frame:SetPoint("TOPRIGHT", UIParent, "TOPRIGHT", -40, -60) -- painel + radial cabem na altura
        else
            frame:SetPoint("RIGHT", UIParent, "RIGHT", -40, 20)
        end
    end
    if frame:IsShown() then Rebuild() else dirty = true end
    M:SyncEquipPanel()
end

-- Forma de abrir: "camera" (personagem no mundo), "panel" (painel Equipado ao
-- lado) ou "bags" (só a mochila). "unified" continua valendo para a câmera.
function M:OpenMode()
    if self.db.unified ~= false then return "camera" end
    return self.db.openMode == "panel" and "panel" or "bags"
end

function M:SyncEquipPanel()
    local EP, radial = Azaath.InventoryEquip, M.miniRadial
    if not (EP and frame) then return end
    local panelMode = frame:IsShown() and M:OpenMode() == "panel" and not IsMerchantActive()
    EP.SetToggle(frame, panelMode, not M.db.equipHidden)
    if panelMode and not M.db.equipHidden then
        EP.Show(frame, radial)
        M.radialOnPanel = true
    else
        EP.Hide()
        if radial and (M:OpenMode() == "panel" or M.radialOnPanel) then
            M.radialOnPanel = nil
            radial:ClearAllPoints()
            radial:SetPoint("RIGHT", frame, "LEFT", -14, -64)
            radial:Hide()
        end
    end
end

--------------------------------------------------------------------------------
-- Espelho das bolsas da Blizzard
--------------------------------------------------------------------------------
AnyBagOpen = function()
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined:IsShown() then return true end

    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local f = _G["ContainerFrame" .. i]
        if f and f:IsShown() then
            local id = f.GetBagID and f:GetBagID() or f:GetID()
            if id and id >= FIRST_BAG and id <= LAST_BAG then
                return true
            end
        end
    end

    local CC = _G.C_Container
    for bag = FIRST_BAG, LAST_BAG do
        if CC and CC.IsBagOpen and CC.IsBagOpen(bag) then return true end
        if _G.IsBagOpen and _G.IsBagOpen(bag) then return true end
    end
    return false
end

local function Sync()
    if frame and frame.azClosing then return end
    if AnyBagOpen() then
        if not frame:IsShown() then frame:Show() end
    elseif frame:IsShown() then
        frame:Hide()
    end
end

-- Liga/desliga o mouse da árvore inteira: além dos itens, a janela tem
-- retrato, botão de fechar e o quadro de dinheiro (com botões filhos), que
-- invisíveis ainda capturariam cliques.
local function SetMouseTree(f, enabled)
    if f.EnableMouse then
        if not (f.IsProtected and f:IsProtected() and InCombatLockdown()) then
            pcall(f.EnableMouse, f, enabled)
        end
    end
    for _, kid in ipairs({ f:GetChildren() }) do
        SetMouseTree(kid, enabled)
    end
end

-- Janela da Blizzard para uma bolsa 0-4: invisível e sem mouse (continua aberta
-- por baixo). Reutilizada para o banco (5-11): volta ao normal.
local function OnGenerateFrame(containerFrame, size, id)
    local hide = id and id >= FIRST_BAG and id <= LAST_BAG
    containerFrame:SetAlpha(hide and 0 or 1)
    SetMouseTree(containerFrame, not hide)
    Sync()
end

-- Varredura genérica (cliente moderno, onde ContainerFrame_GenerateFrame pode
-- não existir): depois de qualquer abrir/fechar de bolsa, aplica a mesma regra
-- às janelas de bolsa visíveis e à janela combinada (se houver).
local function ScanBagFrames()
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local f = _G["ContainerFrame" .. i]
        if f and f:IsShown() then
            local id = f.GetBagID and f:GetBagID() or f:GetID()
            OnGenerateFrame(f, 0, id)
        end
    end
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined:IsShown() then
        combined:SetAlpha(0)
        SetMouseTree(combined, false)
    end
    Sync()
end

local BAG_FUNCTIONS = {
    "ToggleBackpack", "OpenBackpack", "CloseBackpack", "ToggleBag", "OpenBag", "CloseBag",
    "OpenAllBags", "CloseAllBags", "ToggleAllBags",
}

--------------------------------------------------------------------------------
-- Métodos públicos de abertura/fechamento
--------------------------------------------------------------------------------
-- refaz o layout no próximo quadro (chips da skin Azaath etc.)
function M:Refresh()
    dirty = true
end

function M:IsOpen()
    return frame and frame:IsShown()
end

function M:Toggle()
    local charMod = (M.db.unified ~= false) and GetCharacter()
    local charShown = charMod and charMod.frame:IsShown()
    local invShown = frame and frame:IsShown()

    if invShown or charShown then
        self:Close()
    else
        self:Open()
    end
end

function M:Open(fromChar)
    if not frame then return end
    if not frame:IsShown() then
        if not AnyBagOpen() then
            if _G.OpenAllBags then
                _G.OpenAllBags()
            elseif _G.ToggleBackpack then
                _G.ToggleBackpack()
            end
        end
        frame:Show() -- o OnShow abre o personagem (modo unificado)
    end
    -- aberto pelo jogador (botão/atalho): fora de mercador, mostra o personagem
    if not fromChar and M.db.unified ~= false and not IsMerchantActive() then
        local charMod = GetCharacter()
        if charMod and not charMod.frame:IsShown() then
            charMod:Open(true)
        end
    end
end

function M:Close(fromChar)
    if not frame then return end
    if frame:IsShown() then
        frame:Hide() -- o OnHide fecha as bolsas da Blizzard e o personagem
    end
    if not fromChar and M.db.unified ~= false then
        local charMod = GetCharacter()
        if charMod and charMod.frame:IsShown() then
            charMod:Close(true)
        end
    end
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1, arg2)
    if event == "ITEM_LOCK_CHANGED" then
        -- só o estado de "travado" (arrastando): atualiza o botão direto
        local list = arg1 and buttons[arg1]
        local b = list and arg2 and list[arg2]
        if b and b:IsShown() then
            local _, _, locked = GetContainerItemInfo(arg1, arg2)
            if b.icon then
                b.icon:SetDesaturated(locked and true or false)
            end
        end
    elseif event == "BAG_UPDATE_COOLDOWN" then
        for bag, list in pairs(buttons) do
            for slot, b in pairs(list) do
                if b:IsShown() then UpdateCooldown(b, bag, slot) end
            end
        end
    elseif event == "PLAYER_MONEY" then
        UpdateMoney()
    elseif event == "PLAYER_STARTED_MOVING" and M.db.keepOnMove ~= false then
        -- andar com as bolsas abertas: só o personagem fecha (Character.lua),
        -- e o OnHide dele devolve o inventário para a posição solta
        return
    elseif event == "PLAYER_STARTED_MOVING" or event == "PLAYER_REGEN_DISABLED" then
        -- PLAYER_REGEN_DISABLED chega antes do bloqueio de combate: última
        -- chance de esconder o botão seguro
        DetachSecure()
        if frame and frame:IsShown() then
            M:Close()
        end
    else
        dirty = true -- BAG_UPDATE, PLAYER_ENTERING_WORLD, UPDATE_INVENTORY_DURABILITY
    end
end)

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:OnInitialize()
    self.db = Azaath.db.inventory
    if type(self.db.collapsed) ~= "table" then self.db.collapsed = {} end
    if not SORTERS[self.db.sort or ""] then self.db.sort = "recent" end
    if not self.db.viewMode then self.db.viewMode = "az" end
    self.db.openMode = self:OpenMode() -- "unified" manda (assistente e bancos antigos só conhecem ele)
end

function M:OnEnable()
    if not self.db.enabled then return end
    -- Reagent bag é slot 5 no cliente moderno; banco começa em 6+, então é seguro.
    if Azaath.IS_MODERN then LAST_BAG = 5 end
    TEX = Azaath.media.path .. "Inventory\\"
    ROUND_OK = UIParent.CreateMaskTexture ~= nil
    USE_SECURE = Azaath.IS_MODERN and true or false
    LoadFonts()
    BuildClassMap()
    if USE_SECURE then CreateSecureUse() end
    Build()

    if ContainerFrame_GenerateFrame then
        hooksecurefunc("ContainerFrame_GenerateFrame", OnGenerateFrame)
    end
    if ContainerFrame_OnHide then
        hooksecurefunc("ContainerFrame_OnHide", Sync)
    end
    -- No cliente moderno (ContainerFrameMixin), as funções globais acima não existem:
    -- monitoramos diretamente OnShow/OnHide das janelas de bolsa para evitar dessincronia.
    for i = 1, (NUM_CONTAINER_FRAMES or 13) do
        local cf = _G["ContainerFrame" .. i]
        if cf and cf.HookScript then
            cf:HookScript("OnShow", function(self)
                local id = self.GetBagID and self:GetBagID() or self:GetID()
                OnGenerateFrame(self, 0, id)
            end)
            cf:HookScript("OnHide", Sync)
        end
    end
    local combined = _G.ContainerFrameCombinedBags
    if combined and combined.HookScript then
        combined:HookScript("OnShow", function(self)
            self:SetAlpha(0)
            SetMouseTree(self, false)
            Sync()
        end)
        combined:HookScript("OnHide", Sync)
    end
    for _, fn in ipairs(BAG_FUNCTIONS) do
        if _G[fn] then hooksecurefunc(fn, ScanBagFrames) end
    end

    for _, e in ipairs({ "BAG_UPDATE", "ITEM_LOCK_CHANGED", "BAG_UPDATE_COOLDOWN", "PLAYER_MONEY",
                         "PLAYER_ENTERING_WORLD", "UPDATE_INVENTORY_DURABILITY", "QUEST_ACCEPTED", "QUEST_REMOVED",
                         "PLAYER_STARTED_MOVING", "PLAYER_REGEN_DISABLED" }) do
        Azaath.SafeRegister(events, e)
    end
end
