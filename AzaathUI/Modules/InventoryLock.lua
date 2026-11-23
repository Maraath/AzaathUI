--[[----------------------------------------------------------------------------
    AzaathUI - Modules/InventoryLock.lua
    "Trancar item" da mochila: itens trancados (por ID do item, salvos no banco
    do personagem em inventory.locked) ganham um cadeado e ficam protegidos:
      * não são vendidos: clique direito no vendedor, arrastar para o vendedor
        e o "Vender lixo" do Merchant.lua ignoram o item
      * não são destruídos: soltar o item fora da janela não abre a confirmação
        de destruir (o item volta para a bolsa)
    O botão "Trancar item" do rodapé liga o modo de trancar: enquanto ligado,
    clicar num item tranca/destrava. Esc, fechar a mochila ou o botão desligam.
    Chamado por Inventory.lua (IL.mode, IL.Toggle, IL.IsLocked, IL.BlockSell).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local IL = {}
Azaath.InventoryLock = IL

local _G = _G
IL.mode = false
IL.ICON = "Inventory\\Lock" -- Media/Inventory/Lock.tga (tools/inventory-lock/gen.js)

local function DB()
    local inv = Azaath.db and Azaath.db.inventory
    if not inv then return nil end
    if type(inv.locked) ~= "table" then inv.locked = {} end
    return inv.locked
end

local function IDFromLink(link)
    if type(link) ~= "string" or Azaath.IsSecret(link) then return nil end
    return tonumber(link:match("item:(%d+)"))
end

local function ItemID(bag, slot)
    local CC = _G.C_Container
    if CC and CC.GetContainerItemID then
        local ok, id = pcall(CC.GetContainerItemID, bag, slot)
        if ok and type(id) == "number" and not Azaath.IsSecret(id) then return id end
    end
    return IDFromLink(Azaath.API.GetContainerItemLink(bag, slot))
end

function IL.IsLockedID(id)
    local db = id and DB()
    return db and db[id] and true or false
end

function IL.IsLocked(bag, slot)
    return IL.IsLockedID(ItemID(bag, slot))
end

function IL.Toggle(bag, slot)
    local id, db = ItemID(bag, slot), DB()
    if not (id and db) then return end
    db[id] = (not db[id]) or nil
    local name = Azaath.API.GetContainerItemLink(bag, slot) or ("#" .. id)
    Azaath:Print((db[id] and "Trancado: " or "Destrancado: ") .. name)
    Azaath.PlaySound(db[id] and "igMainMenuOptionCheckBoxOn" or "igMainMenuOptionCheckBoxOff")
end

local function Warn(msg)
    if UIErrorsFrame then UIErrorsFrame:AddMessage(msg, 1.0, 0.3, 0.25) end
end

function IL.MerchantOpen()
    local mf, nm = _G.MerchantFrame, _G.AzaathUIMerchant
    return (mf and mf:IsShown()) or (nm and nm:IsShown()) or false
end

-- true = ação bloqueada (vender/pegar o item trancado com o vendedor aberto)
function IL.BlockSell(bag, slot)
    if IL.MerchantOpen() and IL.IsLocked(bag, slot) then
        Warn("Item trancado: destranque para vender.")
        return true
    end
    return false
end

function IL.SetMode(on)
    IL.mode = on and true or false
    if IL.onModeChanged then IL.onModeChanged(IL.mode) end
end

--------------------------------------------------------------------------------
-- Proteção contra destruir: a confirmação some e o item volta à bolsa
--------------------------------------------------------------------------------
local DELETE_POPUPS = { DELETE_ITEM = true, DELETE_GOOD_ITEM = true,
                        DELETE_QUEST_ITEM = true, DELETE_GOOD_QUEST_ITEM = true }

local guard = CreateFrame("Frame")
guard:RegisterEvent("PLAYER_LOGIN")
guard:SetScript("OnEvent", function()
    if not _G.StaticPopup_Show then return end
    hooksecurefunc("StaticPopup_Show", function(which)
        if not DELETE_POPUPS[which] then return end
        local kind, id = GetCursorInfo()
        if kind ~= "item" or not IL.IsLockedID(id) then return end
        if _G.StaticPopup_Hide then pcall(_G.StaticPopup_Hide, which) end
        ClearCursor()
        Warn("Item trancado: não pode ser destruído.")
    end)
end)

-- Arrastar um item trancado para a janela do vendedor: ele é solto de volta
-- antes do clique chegar ao vendedor (MERCHANT_* não avisa; checa o cursor)
local watch = CreateFrame("Frame")
Azaath.SafeRegister(watch, "CURSOR_CHANGED")
watch:SetScript("OnEvent", function()
    if not IL.MerchantOpen() then return end
    local kind, id = GetCursorInfo()
    if kind == "item" and IL.IsLockedID(id) then
        ClearCursor()
        Warn("Item trancado: destranque para vender.")
    end
end)
