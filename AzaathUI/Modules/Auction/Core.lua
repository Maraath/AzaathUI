--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Auction/Core.lua
    Preços de leilão para o card de item (substitui o Auctionator). Sem janela
    própria: ao abrir a Casa de Leilões, todos os preços são atualizados.

    Como (leilão moderno do cliente Forever, C_AuctionHouse):
      * Varredura de navegação: SendBrowseQuery com texto vazio devolve um
        resumo por item (itemKey, menor preço, quantidade total). Os resultados
        chegam aos poucos (AUCTION_HOUSE_BROWSE_RESULTS_UPDATED / _ADDED) e são
        pedidos com RequestMoreBrowseResults até HasFullBrowseResults, sem ordenação
        (sorts = {}), como a IncrementalScan do Auctionator.
        Foi o que o Auctionator gravou neste cliente (TimeOfLastBrowseScan). Antes
        dela, os itens da bolsa saem numa consulta só (SearchForItemKeys).
        ReplicateItems não responde no Forever (testado em 23/11): não usar.
      * Coleta passiva: o que o jogador pesquisa na janela da Blizzard
        (navegação, mercadorias, itens) também atualiza o banco.
      * Banco: AzaathUIAuctionDB (conta, dentro de SavedVariables/AzaathUI.lua)
        .realms["Reino-Facção"].prices[chave] = { menor preço unitário (cobre),
        dia (time()/86400), quantidade à venda }
        chave = itemID (menor entre as variações) e "itemID:sufixo" para itens
        com sufixo aleatório.
      * /leilao mostra o estado; /leilao varrer refaz a varredura.

    Lido por Modules/ItemCard.lua (linha "Leilão:") e LootCelebration/Stats.lua.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local A = {}
Azaath.AuctionNS = A

local _G = _G
local type, pairs, ipairs, tonumber, tostring, floor, max, time, pcall =
      type, pairs, ipairs, tonumber, tostring, math.floor, math.max, time, pcall

A.MIN_GAP = 60     -- segundos mínimos entre duas varreduras automáticas
A.RETRY = 5        -- segundos sem leva nova antes de pedir de novo
A.RETRIES = 3      -- pedidos repetidos sem resposta antes de encerrar

local function AH() return _G.C_AuctionHouse end

function A.IsPT()
    local cfg = Azaath.ConfigUI
    if cfg and cfg.LangCode then return cfg.LangCode() == "ptBR" end
    return _G.GetLocale and _G.GetLocale() == "ptBR"
end
function A.L(pt, en) return A.IsPT() and pt or en end

local function Opt() return (Azaath.db and Azaath.db.auction) or {} end

--------------------------------------------------------------------------------
-- Banco de preços
--------------------------------------------------------------------------------
local function Today() return floor(time() / 86400) end

function A.DB()
    if type(_G.AzaathUIAuctionDB) ~= "table" then _G.AzaathUIAuctionDB = {} end
    local db = _G.AzaathUIAuctionDB
    db.lists, db.listSel = nil, nil -- sobras da 1ª versão (painel removido)
    db.realms = db.realms or {}
    local realm = (_G.GetRealmName and _G.GetRealmName()) or ""
    if realm == "" and _G.GetNormalizedRealmName then realm = _G.GetNormalizedRealmName() or "" end
    local faction = (_G.UnitFactionGroup and _G.UnitFactionGroup("player")) or "?"
    local key = realm .. "-" .. faction
    local r = db.realms[key]
    if not r then
        r = { prices = {} }
        db.realms[key] = r
    end
    r.prices = r.prices or {}
    r.diag, r.fullScanAsked = nil, nil -- sobras das versões anteriores
    return r
end

-- Chave do item a partir de um link ("item:id:enchant:g1:g2:g3:g4:suffix:...")
function A.KeyFromLink(link)
    if type(link) ~= "string" then return nil, nil end
    local body = link:match("item:([%-%d:]+)")
    if not body then return nil, nil end
    local f, i = {}, 0
    for v in (body .. ":"):gmatch("([%-%d]*):") do
        i = i + 1
        f[i] = tonumber(v) or 0
    end
    local id, suffix = f[1], f[7] or 0
    if not id or id == 0 then return nil, nil end
    if suffix ~= 0 then return id .. ":" .. suffix, id end
    return id, id
end

local function KeyFromItem(item)
    if type(item) == "number" then return item, item end
    if type(item) == "string" then
        if item:find("item:") then return A.KeyFromLink(item) end
        local n = tonumber(item)
        if n then return n, n end
    end
    return nil, nil
end

-- preço unitário (cobre), idade em dias e quantidade à venda; nil se não houver dado
function A.GetPrice(item)
    if type(_G.AzaathUIAuctionDB) ~= "table" then return nil end
    local key, id = KeyFromItem(item)
    if not key then return nil end
    local p = A.DB().prices
    local e = p[key] or (id and p[id])
    if type(e) ~= "table" or type(e[1]) ~= "number" then return nil end
    return e[1], Today() - (e[2] or Today()), e[3]
end

local function Store(found)
    local p, d = A.DB().prices, Today()
    for key, v in pairs(found) do p[key] = { v[1], d, v[2] } end
end

local function Add(found, key, unit, n)
    local e = found[key]
    if not e then
        found[key] = { unit, n or 1 }
    else
        if unit < e[1] then e[1] = unit end
        e[2] = e[2] + (n or 1)
    end
end

-- resumo de navegação -> found (itemID e, se houver sufixo, "itemID:sufixo")
local function AddBrowse(found, r)
    local k = r and r.itemKey
    if not (k and k.itemID and r.minPrice and r.minPrice > 0) or r.totalQuantity == 0 then return end
    local n = r.totalQuantity or 1
    Add(found, k.itemID, r.minPrice, n)
    if (k.itemSuffix or 0) ~= 0 then Add(found, k.itemID .. ":" .. k.itemSuffix, r.minPrice, n) end
end

--------------------------------------------------------------------------------
-- Atualização ao abrir o leilão, em duas etapas:
--   1) Rápida: SearchForItemKeys com os itens da bolsa numa consulta só. No
--      Forever a 1ª resposta costuma vir com tudo "nenhum disponível"; reenvia
--      enquanto melhorar (até 3 vezes). Os itens da bolsa ganham preço em ~2 s.
--   2) Completa: navegação vazia (todos os itens, ~24 mil resumos em levas de
--      ~500). O ritmo é o do servidor: todas as consultas dividem uma fila
--      (IsThrottledMessageSystemReady); a próxima leva é pedida no quadro em
--      que a fila libera, sem pausa fixa. Pedir com a fila ocupada atrapalha a
--      aba de venda da Blizzard.
--------------------------------------------------------------------------------
local scan = { state = nil }
A.scan = scan

local function Open()
    local f = _G.AuctionHouseFrame
    return (f and f:IsShown()) and true or false
end

local function Ready()
    local ah = AH()
    if not ah.IsThrottledMessageSystemReady then return true end
    local ok, r = pcall(ah.IsThrottledMessageSystemReady)
    return (not ok) or r
end

local function Now() return _G.GetTime() end

local function Stop()
    scan.state, scan.more = nil, false
    scan.driver:Hide()
end

local function Finish(complete)
    if not scan.state then return end
    local n = 0
    for _, x in ipairs(AH().GetBrowseResults and AH().GetBrowseResults() or {}) do
        if (x.totalQuantity or 0) > 0 then n = n + 1 end
    end
    local r = A.DB()
    r.lastScan, r.lastScanCount = time(), n
    if complete then
        Azaath:Print(A.L("Preços do leilão atualizados: %d itens (%.0f s).", "Auction prices updated: %d items (%.0f s)."),
            n, Now() - (scan.began or Now()))
    else
        Azaath:Print(A.L("Preços do leilão atualizados em parte: %d itens.", "Auction prices partly updated: %d items."), n)
    end
    Stop()
end

-- 1) itens da bolsa -----------------------------------------------------------
local function BagKeys()
    local CC, ah, keys, seen = _G.C_Container, AH(), {}, {}
    if not (CC and CC.GetContainerNumSlots and CC.GetContainerItemInfo and ah.MakeItemKey) then return keys end
    for b = 0, (_G.NUM_BAG_SLOTS or 4) do
        for s = 1, CC.GetContainerNumSlots(b) or 0 do
            local info = CC.GetContainerItemInfo(b, s)
            local id = info and info.itemID
            if id and not seen[id] and not info.isBound and (info.quality or 1) > 0 then
                seen[id] = true
                local ok, key = pcall(ah.MakeItemKey, id)
                if ok and key then keys[#keys + 1] = key end
            end
        end
    end
    return keys
end

local function SendQuick()
    scan.tries = (scan.tries or 0) + 1
    scan.state, scan.last = "quick", Now()
    local ok, err = pcall(AH().SearchForItemKeys, scan.keys, {})
    if not ok then
        geterrorhandler()(err)
        scan.state, scan.last = "waiting", Now() -- segue para a completa
    end
end

local function QuickDone()
    if scan.best and scan.best > 0 then
        Azaath:Print(A.L("Preços da bolsa: %d de %d itens à venda (%.0f s). Atualizando o resto...",
            "Bag prices: %d of %d items listed (%.0f s). Updating the rest..."),
            scan.best, #scan.keys, Now() - scan.quickBegan)
    end
    scan.state, scan.last = "waiting", Now()
end

local function OnQuickResults()
    local found, priced = {}, 0
    for _, r in ipairs(AH().GetBrowseResults and AH().GetBrowseResults() or {}) do
        if r.totalQuantity and r.totalQuantity > 0 and r.minPrice and r.minPrice > 0 then
            priced = priced + 1
            AddBrowse(found, r)
        end
    end
    Store(found)
    local prev = scan.best or 0
    scan.best = max(prev, priced)
    -- 1ª resposta zerada (ou ainda melhorando): pede de novo
    if scan.tries < 3 and priced < #scan.keys and (priced == 0 or priced > prev) then
        scan.state, scan.last = "quickWait", Now()
    else
        QuickDone()
    end
end

-- 2) navegação completa --------------------------------------------------------
local function SendScan()
    scan.state, scan.last, scan.retries, scan.began, scan.more = "reading", Now(), 0, Now(), false
    local ok, err = pcall(AH().SendBrowseQuery, {
        -- sem ordenação: ordenar o leilão inteiro deixa cada leva mais lenta no servidor
        searchString = "", sorts = {}, filters = {}, itemClassFilters = {},
    })
    if not ok then
        geterrorhandler()(err)
        Stop()
    end
end

-- grava a leva que chegou (os preços já valem no card) e marca a próxima
local function OnResults(added)
    local found = {}
    local list = added or (AH().GetBrowseResults and AH().GetBrowseResults()) or {}
    for _, r in ipairs(list) do AddBrowse(found, r) end
    Store(found)
    scan.last, scan.retries = Now(), 0
    local ah = AH()
    if ah.HasFullBrowseResults and ah.HasFullBrowseResults() then
        Finish(true)
    else
        scan.more = true
        if Ready() then scan.more = false; pcall(ah.RequestMoreBrowseResults) end
    end
end

function A.StartScan(manual)
    local ah = AH()
    if not (ah and ah.SendBrowseQuery) or not Open() then return false end
    if scan.state then return false end
    local r = A.DB()
    if not manual and r.lastScan and time() - r.lastScan < A.MIN_GAP then return false end
    scan.keys, scan.tries, scan.best, scan.quickBegan = (not manual) and BagKeys() or {}, 0, 0, Now()
    if #scan.keys > 0 and ah.SearchForItemKeys then
        scan.state = "quickWait"
    else
        scan.state = "waiting"
    end
    scan.last = Now()
    scan.driver:Show()
    if manual then Azaath:Print(A.L("Atualizando os preços do leilão...", "Updating auction prices...")) end
    return true
end

-- a cada quadro, só enquanto atualiza: envia no instante em que a fila libera
scan.driver = CreateFrame("Frame")
scan.driver:Hide()
scan.driver:SetScript("OnUpdate", function()
    local st = scan.state
    if not st then scan.driver:Hide(); return end
    if not Open() then Stop(); return end
    local wait = Now() - (scan.last or 0)
    if st == "quickWait" then
        if Ready() then SendQuick() end
    elseif st == "quick" then
        if wait > 4 then QuickDone() end -- sem resposta: segue para a completa
    elseif st == "waiting" then
        if Ready() then SendScan() end
    elseif st == "reading" then
        if scan.more then
            if Ready() then
                scan.more, scan.last = false, Now()
                pcall(AH().RequestMoreBrowseResults)
            end
        elseif wait > A.RETRY then
            if scan.retries >= A.RETRIES then
                Finish(false)
            elseif Ready() then
                scan.retries, scan.last = scan.retries + 1, Now()
                pcall(AH().RequestMoreBrowseResults)
            end
        end
    end
end)

--------------------------------------------------------------------------------
-- Coleta passiva das pesquisas feitas na janela da Blizzard
--------------------------------------------------------------------------------
local function FromBrowse()
    local found = {}
    local list = AH().GetBrowseResults and AH().GetBrowseResults() or {}
    for _, r in ipairs(list) do AddBrowse(found, r) end
    Store(found)
end

local function FromCommodity(itemID)
    local ah = AH()
    local n = ah.GetNumCommoditySearchResults and ah.GetNumCommoditySearchResults(itemID) or 0
    local low, qty = nil, 0
    for i = 1, n do
        local r = ah.GetCommoditySearchResultInfo(itemID, i)
        if r and r.unitPrice then
            if not low or r.unitPrice < low then low = r.unitPrice end
            qty = qty + (r.quantity or 0)
        end
    end
    if low then Store({ [itemID] = { low, qty } }) end
end

local function FromItems(itemKey)
    local ah, found = AH(), {}
    local n = ah.GetNumItemSearchResults and ah.GetNumItemSearchResults(itemKey) or 0
    for i = 1, n do
        local r = ah.GetItemSearchResultInfo(itemKey, i)
        if r and r.buyoutAmount and r.buyoutAmount > 0 then
            local q = max(1, r.quantity or 1)
            local unit = floor(r.buyoutAmount / q)
            local key = r.itemLink and A.KeyFromLink(r.itemLink)
            Add(found, itemKey.itemID, unit, q)
            if key and key ~= itemKey.itemID then Add(found, key, unit, q) end
        end
    end
    Store(found)
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local function Safe(fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok then geterrorhandler()(err) end
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(_, event, arg)
    if event == "AUCTION_HOUSE_SHOW" then
        -- a janela da Blizzard faz a própria consulta inicial; a varredura sai quando o servidor liberar
        if Opt().autoScan ~= false then
            C_Timer.After(0, function() A.StartScan(false) end)
        end
    elseif event == "AUCTION_HOUSE_CLOSED" then
        if scan.state == "reading" then Finish(false) else Stop() end
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED" then
        if scan.state == "reading" then Safe(OnResults, nil)
        elseif scan.state == "quick" then Safe(OnQuickResults)
        else Safe(FromBrowse) end
    elseif event == "AUCTION_HOUSE_BROWSE_RESULTS_ADDED" then
        -- arg = só os resultados novos desta leva
        local added = type(arg) == "table" and arg or nil
        if scan.state == "reading" then Safe(OnResults, added) else Safe(FromBrowse) end
    elseif event == "COMMODITY_SEARCH_RESULTS_UPDATED" then
        Safe(FromCommodity, arg)
    elseif event == "ITEM_SEARCH_RESULTS_UPDATED" then
        if type(arg) == "table" then Safe(FromItems, arg) end
    end
end)

for _, e in ipairs({ "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
                     "AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", "AUCTION_HOUSE_BROWSE_RESULTS_ADDED",
                     "COMMODITY_SEARCH_RESULTS_UPDATED", "ITEM_SEARCH_RESULTS_UPDATED" }) do
    Azaath.SafeRegister(ev, e)
end

--------------------------------------------------------------------------------
-- Texto (card de item)
--------------------------------------------------------------------------------
function A.Money(copper)
    copper = floor(copper or 0)
    if _G.GetCoinTextureString then
        local ok, s = pcall(_G.GetCoinTextureString, copper, 12)
        if ok and s then return s end
    end
    local g, s, c = floor(copper / 10000), floor(copper / 100) % 100, copper % 100
    local out = ""
    if g > 0 then out = out .. g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t " end
    if s > 0 or g > 0 then out = out .. s .. "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t " end
    return out .. c .. "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"
end

function A.AgeText(days)
    if not days then return "" end
    if days <= 0 then return A.L("hoje", "today") end
    if days == 1 then return A.L("ontem", "yesterday") end
    return A.L("há %d dias", "%d days ago"):format(days)
end

--------------------------------------------------------------------------------
-- /leilao
--------------------------------------------------------------------------------
SLASH_AZAATHLEILAO1 = "/leilao"
SlashCmdList.AZAATHLEILAO = function(msg)
    msg = (msg or ""):lower()
    if msg:find("varr") or msg:find("scan") then
        if not Open() then
            Azaath:Print(A.L("Abra a Casa de Leilões primeiro.", "Open the Auction House first."))
        elseif not A.StartScan(true) then
            Azaath:Print(A.L("Já há uma atualização em andamento.", "An update is already running."))
        end
        return
    end
    local r, n = A.DB(), 0
    for _ in pairs(r.prices) do n = n + 1 end
    Azaath:Print(A.L("Leilão: %d itens com preço; última atualização: %s.", "Auction: %d items priced; last update: %s."),
        n, r.lastScan and date("%d/%m %H:%M", r.lastScan) or A.L("nunca", "never"))
end
