--[[----------------------------------------------------------------------------
    AzaathUI - Modules/LootCelebration/Tracker.lua
    Motor de detecção confiável de saques, peixes, tesouros, coletas raras,
    marcos de profissão, raros abatidos e rolagens Need/Greed (WoW Forever).
    Baseado em LootDopamine/Core.lua e Tracker.lua (MIT).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("LootCelebration")

local LC = Azaath.LootCel or {}
Azaath.LootCel = LC

local _G = _G
local ipairs, pairs, pcall, select, tostring, tonumber, type =
    ipairs, pairs, pcall, select, tostring, tonumber, type
local floor, max, min, format = math.floor, math.max, math.min, string.format
local CreateFrame, C_Timer = CreateFrame, C_Timer

local function Safe(v)
    return not Azaath.IsSecret(v)
end

local function Valid(v, kind)
    return Safe(v) and type(v) == kind
end

local function ClockNow()
    if type(_G.GetTime) ~= "function" then return 0 end
    local t = _G.GetTime()
    return Valid(t, "number") and t or 0
end

local function DB()
    return (Azaath.db and Azaath.db.lootCelebration) or {}
end

local function Cat()
    return Azaath.LootCatalog or {}
end

local function ExtractItemID(link)
    if not Valid(link, "string") then return nil end
    return tonumber(link:match("item:(%d+)"))
end

--------------------------------------------------------------------------------
-- Estado de Fonte, Aquisições Pendentes & Deferidos
--------------------------------------------------------------------------------
local SOURCE = {
    merchantOpen = false, merchantUntil = 0,
    questOpen = false,    questUntil = 0,
    mailOpen = false,     mailUntil = 0,
    tradeOpen = false,    tradeUntil = 0,
    auctionOpen = false,  auctionUntil = 0,
    rewardIDs = {},
    lootSignals = {},
    pendingAcquisitions = {},
    lastConfirmedAt = {},
    deferred = {},
    recoveryScheduled = false,
}

local state = {
    ready = false,
    bootstrapPending = false,
    scanQueued = false,
    skillsReady = false,
    skillTicker = nil,
    zoneGuardUntil = 0,
    fishingActive = false,
    fishingStartedAt = nil,
    fishingEndedAt = nil,
    previousBags = {},
    previousOwned = {},
    skillLevels = {},
}

local function NotFromMerchantOrQuest(id)
    local now = ClockNow()
    if SOURCE.merchantOpen or now < SOURCE.merchantUntil then return false end
    if SOURCE.questOpen    or now < SOURCE.questUntil    then return false end
    if SOURCE.mailOpen     or now < SOURCE.mailUntil     then return false end
    if SOURCE.tradeOpen    or now < SOURCE.tradeUntil    then return false end
    if SOURCE.auctionOpen  or now < SOURCE.auctionUntil  then return false end
    if id and SOURCE.rewardIDs[id] and now < SOURCE.rewardIDs[id] then return false end
    return true
end

local function MarkLootSignal(id, how, ttl, sourceGUID, isFishing)
    if type(id) ~= "number" then return end
    local now = ClockNow()
    local exp = now + ttl
    local existing = SOURCE.lootSignals[id]
    local strong = (how == "won-roll" or how == "self-loot-chat" or how == "loot-history-win" or how == "self-win-chat")
    local contextSafe = not (SOURCE.merchantOpen or SOURCE.tradeOpen or SOURCE.mailOpen or SOURCE.questOpen or
                             SOURCE.auctionOpen or (SOURCE.rewardIDs[id] and now < SOURCE.rewardIDs[id]))
    if not existing then
        existing = { untilTime = exp, via = how, sourceGUID = sourceGUID, isFishing = isFishing or false }
        SOURCE.lootSignals[id] = existing
    else
        existing.untilTime = max(existing.untilTime, exp)
        if sourceGUID then existing.sourceGUID = sourceGUID end
        if isFishing then existing.isFishing = true end
        if strong then existing.via = how end
    end
    if strong and contextSafe then
        existing.strongAt = now
        existing.strongUntil = exp
    end
end

local function HasLootSignal(id)
    local s = SOURCE.lootSignals[id]
    return s and s.untilTime >= ClockNow()
end

local function HasStrongLootSignal(id)
    local s = SOURCE.lootSignals[id]
    return s and s.strongAt and s.strongUntil and s.strongUntil >= ClockNow()
end

--------------------------------------------------------------------------------
-- Reconhecimento Localizado de Chat de Saque
--------------------------------------------------------------------------------
local SELF_LOOT_KEYS = { "LOOT_ITEM_SELF", "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_PUSHED_SELF_MULTIPLE" }
local SELF_WIN_KEYS  = { "LOOT_ROLL_YOU_WON", "LOOT_ROLL_WON_NO_SPAM_SELF", "LOOT_ROLL_WON_SELF" }

local function StartsWithClientFormat(message, keys)
    if not Valid(message, "string") then return false end
    for _, key in ipairs(keys) do
        local fmt = _G[key]
        if Valid(fmt, "string") then
            local before = fmt:match("^(.-)%%")
            if before and #before >= 3 and message:sub(1, #before) == before then
                return true
            end
        end
    end
    return false
end

local function IsSelfLootMsg(msg)
    if StartsWithClientFormat(msg, SELF_LOOT_KEYS) then return true end
    return Valid(msg, "string") and (msg:find("^You receive loot:", 1) ~= nil or msg:find("^You receive item:", 1) ~= nil or
           msg:find("^Você recebe saque:", 1) ~= nil or msg:find("^Você recebe o item:", 1) ~= nil)
end

local function IsSelfWinMsg(msg)
    if StartsWithClientFormat(msg, SELF_WIN_KEYS) then return true end
    return Valid(msg, "string") and (msg:find("^You won:", 1) ~= nil or msg:find("^Você ganhou:", 1) ~= nil)
end

local function RememberVisibleLoot()
    if type(_G.GetNumLootItems) ~= "function" or type(_G.GetLootSlotLink) ~= "function" then return end
    local ok, n = pcall(_G.GetNumLootItems)
    if not ok or not Valid(n, "number") then return end
    local fishing = false
    if type(_G.IsFishingLoot) == "function" then
        local okF, v = pcall(_G.IsFishingLoot)
        fishing = okF and Safe(v) and v == true
    end
    for slot = 1, min(n, 35) do
        local okL, link = pcall(_G.GetLootSlotLink, slot)
        if okL then
            local sourceGUID
            if type(_G.GetLootSourceInfo) == "function" then
                local okS, guid = pcall(_G.GetLootSourceInfo, slot)
                if okS and Valid(guid, "string") then sourceGUID = guid end
            end
            MarkLootSignal(ExtractItemID(link), "loot-window", 14, sourceGUID, fishing)
        end
    end
end

local function RememberQuestRewardIDs()
    if type(_G.GetQuestItemInfo) ~= "function" then return end
    local now = ClockNow()
    for _, category in ipairs({ "choice", "reward" }) do
        local getter = (category == "choice") and _G.GetNumQuestChoices or _G.GetNumQuestRewards
        if type(getter) == "function" then
            local ok, n = pcall(getter)
            if ok and Valid(n, "number") then
                for i = 1, min(n, 20) do
                    local worked, _, _, _, _, _, id = pcall(_G.GetQuestItemInfo, category, i)
                    if worked and Valid(id, "number") then
                        SOURCE.rewardIDs[id] = now + 120
                    end
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Classificação de Itens & Leitura de Bolsas/Equipamentos
--------------------------------------------------------------------------------
local function SafeItemDetails(id, existingName, existingLink)
    local name, link, quality, icon = existingName, existingLink, nil, nil
    local fnInfo = (_G.C_Item and _G.C_Item.GetItemInfo) or _G.GetItemInfo
    if type(fnInfo) == "function" then
        local ok, n, l, q, _, _, _, _, _, _, tex = pcall(fnInfo, id)
        if ok then
            if Safe(n) and n then name = name or n end
            if Safe(l) and l then link = link or l end
            if Valid(q, "number") then quality = q end
            if Safe(tex) and tex then icon = icon or tex end
        end
    end
    if quality == nil and _G.C_Item and type(_G.C_Item.GetItemQualityByID) == "function" then
        local ok, q = pcall(_G.C_Item.GetItemQualityByID, id)
        if ok and Valid(q, "number") then quality = q end
    end
    if _G.C_Item and type(_G.C_Item.GetItemIconByID) == "function" then
        local ok, tex = pcall(_G.C_Item.GetItemIconByID, id)
        if ok and Safe(tex) and tex then icon = tex end
    end
    if not name and type(link) == "string" then name = link:match("%[([^%]]+)%]") end
    return name, link, quality, icon
end

local function IsEquippableBag(id)
    local fn = (_G.C_Item and _G.C_Item.GetItemInfo) or _G.GetItemInfo
    if type(fn) ~= "function" then return false end
    local ok, _, _, _, _, _, _, _, _, loc, _, _, classID = pcall(fn, id)
    return ok and Safe(loc) and (loc == "INVTYPE_BAG" or loc == "INVTYPE_REAGENTBAG") and Safe(classID) and classID == 1
end

local function GreenBoEStatus(id)
    local fn = (_G.C_Item and _G.C_Item.GetItemInfo) or _G.GetItemInfo
    if type(fn) ~= "function" then return nil end
    local ok, _, _, q, _, _, _, _, _, loc, _, _, classID, _, bindType = pcall(fn, id)
    if not ok or not Valid(q, "number") or not Valid(classID, "number") or not Valid(bindType, "number") or not Valid(loc, "string") then
        return nil
    end
    return q == 2 and bindType == 2 and (classID == 2 or classID == 4) and loc ~= ""
end

local function ScanBags()
    local result = {}
    local C_Cont = _G.C_Container
    if not C_Cont or type(C_Cont.GetContainerNumSlots) ~= "function" then return result, false end
    local validScan = true
    local ids = {}
    local maximum = _G.NUM_BAG_SLOTS or 4
    for bag = 0, maximum do ids[#ids + 1] = bag end
    local reagent = _G.Enum and _G.Enum.BagIndex and _G.Enum.BagIndex.ReagentBag
    if type(reagent) == "number" and reagent > maximum and reagent < 20 then
        ids[#ids + 1] = reagent
    end
    for _, bag in ipairs(ids) do
        local okS, slots = pcall(C_Cont.GetContainerNumSlots, bag)
        if bag == 0 and (not okS or not Valid(slots, "number") or slots < 1) then
            validScan = false
        end
        if okS and Valid(slots, "number") then
            for slot = 1, slots do
                local info
                if type(C_Cont.GetContainerItemInfo) == "function" then
                    local ok, val = pcall(C_Cont.GetContainerItemInfo, bag, slot)
                    if ok and Valid(val, "table") then info = val end
                end
                local id = info and info.itemID
                if not Valid(id, "number") then id = nil end
                if not id and type(C_Cont.GetContainerItemID) == "function" then
                    local ok, val = pcall(C_Cont.GetContainerItemID, bag, slot)
                    if ok and Valid(val, "number") then id = val end
                end
                if id and id > 0 then
                    local amt = info and info.stackCount
                    local provisional = not Valid(amt, "number") or amt < 1
                    if provisional then amt = 1 end
                    local row = result[id]
                    if not row then
                        row = { count = 0, partial = false }
                        result[id] = row
                    end
                    row.count = row.count + amt
                    if provisional then row.partial = true end
                    if info then
                        if Valid(info.quality, "number") then row.quality = info.quality end
                        if Valid(info.hyperlink, "string") then row.link = info.hyperlink end
                        if Valid(info.itemName, "string") then row.name = info.itemName end
                        if Safe(info.iconFileID) then row.icon = info.iconFileID or row.icon end
                    end
                    if not row.link and type(C_Cont.GetContainerItemLink) == "function" then
                        local ok, link = pcall(C_Cont.GetContainerItemLink, bag, slot)
                        if ok and Valid(link, "string") then row.link = link end
                    end
                end
            end
        end
    end
    return result, validScan
end

local function ScanOwned(bags)
    local owned = {}
    for id, row in pairs(bags) do owned[id] = row.count end
    if type(_G.GetInventoryItemID) == "function" then
        for slot = 1, 30 do
            local ok, id = pcall(_G.GetInventoryItemID, "player", slot)
            if ok and Valid(id, "number") then
                owned[id] = (owned[id] or 0) + 1
            end
        end
    end
    return owned
end

local function OwnedCount(id, bags, owned)
    local count = owned[id] or 0
    if _G.C_Item and type(_G.C_Item.GetItemCount) == "function" then
        local ok, val = pcall(_G.C_Item.GetItemCount, id, false, false, false)
        if ok and Valid(val, "number") and val >= 0 then
            count = max(count, val)
        end
    end
    return count
end

local function FishingRecently()
    local now = ClockNow()
    if state.fishingActive and state.fishingStartedAt and now >= state.fishingStartedAt and (now - state.fishingStartedAt) <= 36 then
        return true
    end
    if state.fishingEndedAt and now >= state.fishingEndedAt and (now - state.fishingEndedAt) <= 5 then
        return true
    end
    return false
end

local function Classify(id, row)
    local db, cat = DB(), Cat()
    if db.ignore and db.ignore[id] then return nil end
    if cat.bloatedFish and cat.bloatedFish[id] then return "bloated" end
    if db.watch and db.watch[id] then return "special" end
    if IsEquippableBag(id) then return "bag" end
    if cat.rareRecipes and cat.rareRecipes[id] and HasLootSignal(id) then return "recipe" end
    if HasLootSignal(id) then
        if cat.companionItems and cat.companionItems[id] then return "companion" end
        local fn = (_G.C_Item and _G.C_Item.GetItemInfo) or _G.GetItemInfo
        if type(fn) == "function" then
            local ok, _, _, _, _, _, _, _, _, _, _, _, classID, subclassID = pcall(fn, id)
            if ok and Safe(classID) and Safe(subclassID) and classID == 15 and subclassID == 2 then
                return "companion"
            end
        end
    end
    if cat.rareCollectibles and cat.rareCollectibles[id] and HasLootSignal(id) then return "collectible" end
    if (cat.specialFish and cat.specialFish[id]) or (cat.trophyByID and cat.trophyByID[id]) then return "fish" end
    if cat.specialTreasure and cat.specialTreasure[id] then return "treasure" end
    if cat.specialMining and cat.specialMining[id] then return "mining" end
    if cat.specialHerbs and cat.specialHerbs[id] then return "herb" end
    if cat.specialSkinning and cat.specialSkinning[id] then return "skinning" end
    if db.quietFishing ~= false and cat.fishingPotions and cat.fishingPotions[id] and FishingRecently() then
        return "quiet"
    end

    local q = row.quality
    if q == nil then
        local n, l, qual, icon = SafeItemDetails(id, row.name, row.link)
        row.name = row.name or n
        row.link = row.link or l
        row.quality = qual
        row.icon = row.icon or icon
        q = qual
    end
    if q and q >= 5 then return "legendary" end
    if q and q >= 4 then return "epic" end
    if q and q >= 3 then return "rare" end
    if db.greenBoE ~= false and q == 2 and GreenBoEStatus(id) == true then return "green" end

    if type(row.name) == "string" then
        local lower = row.name:lower()
        if lower:find("^%d+ pound ") or lower:find(" de %d+ libras$") then return "fish" end
        if lower:find("trunk", 1, true) or lower:find("lockbox", 1, true) then return "treasure" end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Pipeline de Aquisição, Recuperação & Entrega (Jackpot + Celebração)
--------------------------------------------------------------------------------
local PRIORITY = {
    legendary = 5, epic = 4, rare = 3, green = 1, bag = 2,
    recipe = 3, collectible = 4, companion = 4, record = 4, rare_kill = 3, jackpot = 5,
    bloated = 8, fish = 2, treasure = 2, special = 2,
    mining = 2, herb = 2, skinning = 2, quiet = 1,
}

local ResolveAcquisition, RequestScan

local function RequestItemData(id)
    if _G.C_Item and type(_G.C_Item.RequestLoadItemDataByID) == "function" then
        pcall(_G.C_Item.RequestLoadItemDataByID, id)
    end
end

local function DeferBlockedDelta(id, row, quantity, priorOwned)
    if quantity <= 0 then return end
    local now = ClockNow()
    local p = SOURCE.deferred[id]
    if not p then
        p = { id = id, count = 0, baselineOwned = priorOwned, minimumOwned = priorOwned,
              firstSeen = now, untilTime = now + 26, row = {} }
        SOURCE.deferred[id] = p
    end
    p.count = p.count + quantity
    p.minimumOwned = max(p.minimumOwned, priorOwned + quantity)
    p.untilTime = max(p.untilTime, now + 26)
    p.row.count = row.count
    for _, key in ipairs({ "name", "link", "quality", "icon" }) do
        if row[key] ~= nil then p.row[key] = row[key] end
    end
    if not SOURCE.recoveryScheduled then
        SOURCE.recoveryScheduled = true
        local delays = { 1, 3.5, 7.5, 13, 21, 27 }
        for n, delay in ipairs(delays) do
            C_Timer.After(delay, function()
                if state.ready and RequestScan then RequestScan() end
                if n == #delays then SOURCE.recoveryScheduled = false end
            end)
        end
    end
end

local function CaptureAcquisition(id, row, quantity, priorOwned)
    if quantity <= 0 or not NotFromMerchantOrQuest(id) then return end
    local p = SOURCE.pendingAcquisitions[id]
    if not p then
        p = {
            id = id, count = 0, minimumOwned = priorOwned, baselineOwned = priorOwned,
            created = ClockNow(), untilTime = ClockNow() + 150,
            row = {}, fishingAtCapture = FishingRecently(),
        }
        SOURCE.pendingAcquisitions[id] = p
    end
    p.count = p.count + quantity
    p.minimumOwned = max(p.minimumOwned, priorOwned + quantity)
    p.untilTime = ClockNow() + 150
    p.fishingAtCapture = p.fishingAtCapture or FishingRecently()
    for _, key in ipairs({ "name", "link", "quality", "icon" }) do
        if row[key] ~= nil then p.row[key] = row[key] end
    end
    RequestItemData(id)
    if not p.retryScheduled then
        p.retryScheduled = true
        local intervals = { 0.55, 1.05, 2.4, 8, 23, 45, 70 }
        local step = 1
        local function Retry()
            if SOURCE.pendingAcquisitions[id] ~= p then return end
            if ResolveAcquisition then ResolveAcquisition(id) end
            if SOURCE.pendingAcquisitions[id] == p and step < #intervals then
                step = step + 1
                C_Timer.After(intervals[step], Retry)
            end
        end
        C_Timer.After(intervals[step], Retry)
    end
end

local function RecoverDeferred(bags, owned)
    local now = ClockNow()
    for id, p in pairs(SOURCE.deferred) do
        if now > p.untilTime then
            SOURCE.deferred[id] = nil
        elseif NotFromMerchantOrQuest(id) then
            local signal = SOURCE.lootSignals[id]
            local row = bags[id]
            local strong = HasStrongLootSignal(id)
            local matched = strong and signal.strongAt >= (p.firstSeen - 22) and signal.strongAt <= p.untilTime
            if matched and row and row.count >= min(p.row.count or 1, p.count) and OwnedCount(id, bags, owned) >= p.minimumOwned then
                SOURCE.deferred[id] = nil
                CaptureAcquisition(id, row, min(1, p.count), p.baselineOwned)
            end
        end
    end
end

local function DeliverAcquisitions(found)
    table.sort(found, function(a, b)
        local pa, pb = PRIORITY[a.kind] or 0, PRIORITY[b.kind] or 0
        return pa == pb and a.id < b.id or pa > pb
    end)
    local groups, grouped = {}, {}
    for _, item in ipairs(found) do
        if item.sourceGUID and item.confirmedLoot and
           (item.kind == "green" or item.kind == "rare" or item.kind == "epic" or item.kind == "legendary") then
            local grp = groups[item.sourceGUID]
            if not grp then grp = {}; groups[item.sourceGUID] = grp end
            grp[#grp + 1] = item
        end
    end
    for _, grp in pairs(groups) do
        if #grp >= 2 then
            table.sort(grp, function(a, b) return (PRIORITY[a.kind] or 0) > (PRIORITY[b.kind] or 0) end)
            for _, item in ipairs(grp) do
                grouped[item.id] = true
                if LC.RecordLoot then LC.RecordLoot(item.quality, item.count, item) end
            end
            local head = (#grp == 2 and LC.L("JACKPOT DUPLO!", "DOUBLE JACKPOT!") or (tostring(#grp) .. "x JACKPOT!"))
            LC.Celebrate({
                kind = "jackpot", name = grp[1].name, icon = grp[1].icon,
                items = grp, headline = head,
            })
        end
    end
    for _, item in ipairs(found) do
        if not grouped[item.id] then
            if item.confirmedLoot then
                if item.kind == "bag" and LC.RecordBag then
                    LC.RecordBag(item.quality, item.count, item)
                elseif item.kind == "companion" and LC.RecordCompanion then
                    LC.RecordCompanion(item.quality, item.count, item)
                elseif item.kind ~= "bloated" and LC.RecordLoot then
                    LC.RecordLoot(item.quality, item.count, item)
                end
            end
            LC.Celebrate(item)
        end
    end
end

local function InspectAcquisition(id, bags, owned)
    local p = SOURCE.pendingAcquisitions[id]
    if not p then return nil end
    if ClockNow() > p.untilTime then SOURCE.pendingAcquisitions[id] = nil; return nil end
    if not NotFromMerchantOrQuest(id) then return nil end

    local row = bags[id] or p.row
    for _, key in ipairs({ "name", "link", "quality", "icon" }) do
        if row[key] == nil then row[key] = p.row[key] end
    end
    if OwnedCount(id, bags, owned) < p.minimumOwned then return nil end

    local signal = SOURCE.lootSignals[id]
    local hasSignal = signal and signal.untilTime >= ClockNow()
    local kind = Classify(id, row)
    if (kind == "green" or kind == "bag") and not hasSignal then return nil end

    local cat = Cat()
    local namedFish = row.name or (cat.fishByID and cat.fishByID[id] and cat.fishByID[id].name)
    local trophy = cat.trophyByID and cat.trophyByID[id]
    local mapped = namedFish and cat.fishByName and cat.fishByName[namedFish:lower()]
    local confirmedFishing = hasSignal and signal.isFishing
    local trophyFromCast = (trophy or (mapped and mapped.weight)) and p.fishingAtCapture
    local bloatedFromCast = cat.bloatedFish and cat.bloatedFish[id] and p.fishingAtCapture
    local fishingEvidence = confirmedFishing or trophyFromCast or bloatedFromCast

    if kind == "bloated" and not fishingEvidence then return nil end
    if not kind and row.quality == nil then RequestItemData(id); return nil end
    if not kind and row.quality == 2 and GreenBoEStatus(id) == nil then RequestItemData(id); return nil end
    if not kind and not (p.fishingAtCapture and not hasSignal and namedFish) then
        SOURCE.pendingAcquisitions[id] = nil
        return nil
    end
    if not kind and p.fishingAtCapture and not hasSignal then return nil end

    local best = nil
    if fishingEvidence and LC.RecordCatch then
        local resolved = namedFish or select(1, SafeItemDetails(id, row.name, row.link))
        if not resolved and trophy then
            resolved = tostring(trophy.weight) .. " Pound " .. trophy.family
        end
        if resolved then best = LC.RecordCatch(id, resolved, p.count) end
    end
    if not kind then
        SOURCE.pendingAcquisitions[id] = nil
        return nil
    end

    local fallback = (cat.specialFish and cat.specialFish[id]) or (cat.specialTreasure and cat.specialTreasure[id]) or
                     (cat.specialMining and cat.specialMining[id]) or (cat.specialHerbs and cat.specialHerbs[id]) or
                     (cat.specialSkinning and cat.specialSkinning[id]) or (cat.fishingPotions and cat.fishingPotions[id]) or
                     (cat.fishByID and cat.fishByID[id] and cat.fishByID[id].name)
    local name, link, quality, icon = SafeItemDetails(id, row.name or fallback, row.link)
    local item = {
        id = id, kind = kind, name = name or ("Item #" .. id),
        link = link, icon = row.icon or icon, quality = row.quality or quality,
        count = p.count, confirmedLoot = not not hasSignal,
        sourceGUID = hasSignal and signal.sourceGUID,
        bagSlots = (kind == "bag" and cat.bagSlots) and cat.bagSlots[id] or nil,
    }
    if kind == "bloated" and LC.GetBloatedStats then
        local summary = LC.GetBloatedStats("char")
        local perSpecies = (summary.byID and summary.byID[id]) or 0
        local firstSpecies = (perSpecies == p.count)
        item.headline = firstSpecies and LC.L("NOVO PEIXE INCHADO!", "NEW BLOATED FISH JACKPOT!")
            or LC.L("PEIXE INCHADO RARO!", "BLOATED FISH JACKPOT!")
        item.subtitle = (firstSpecies and LC.L("NOVA ESPÉCIE!  ", "NEW SPECIES!  ") or LC.L("TROFÉU ABISSAL!  ", "DEEP-WATER TROPHY!  ")) ..
            format("%d/%d %s  ·  %d %s", summary.discovered, summary.species,
                LC.L("DESCOBERTOS", "DISCOVERED"), summary.total, LC.L("PESCADOS", "CAUGHT"))
    elseif best and kind == "fish" then
        item.headline = LC.L("NOVO RECORDE PESSOAL!", "NEW PERSONAL RECORD!")
        item.subtitle = (best.previous and best.previous > 0) and
            (LC.L("Recorde anterior: ", "Previous best: ") .. best.previous .. " lb") or nil
    end

    SOURCE.pendingAcquisitions[id] = nil
    SOURCE.lootSignals[id] = nil
    SOURCE.lastConfirmedAt[id] = ClockNow()
    return item
end

ResolveAcquisition = function(id)
    if not state.ready or not Azaath.db then return end
    local bags = ScanBags()
    local owned = ScanOwned(bags)
    RecoverDeferred(bags, owned)
    local item = InspectAcquisition(id, bags, owned)
    if item then DeliverAcquisitions({ item }) end
end

local function ResolveAllAcquisitions()
    if not state.ready or not Azaath.db then return end
    local bags = ScanBags()
    local owned = ScanOwned(bags)
    RecoverDeferred(bags, owned)
    local found = {}
    for id in pairs(SOURCE.pendingAcquisitions) do
        local item = InspectAcquisition(id, bags, owned)
        if item then found[#found + 1] = item end
    end
    if #found > 0 then DeliverAcquisitions(found) end
end

local function ProcessChanges()
    state.scanQueued = false
    local bags, validScan = ScanBags()
    if not validScan then
        C_Timer.After(0.75, function() if RequestScan then RequestScan() end end)
        return
    end
    local owned = ScanOwned(bags)
    if state.ready and state.zoneGuardUntil and ClockNow() < state.zoneGuardUntil then
        local prevTotal, curTotal = 0, 0
        for _, r in pairs(state.previousBags) do prevTotal = prevTotal + r.count end
        for _, r in pairs(bags) do curTotal = curTotal + r.count end
        if prevTotal > 0 and curTotal < prevTotal then
            C_Timer.After(0.85, function() if RequestScan then RequestScan() end end)
            return
        end
    end
    if not state.ready then
        state.previousBags = bags
        state.previousOwned = owned
        return
    end

    for id, row in pairs(bags) do
        local priorBag = (state.previousBags[id] or {}).count or 0
        local priorOwned = state.previousOwned[id] or 0
        local deltaBag = row.count - priorBag
        local deltaOwned = (owned[id] or 0) - priorOwned
        if deltaBag > 0 or (deltaOwned > 0 and HasLootSignal(id)) then
            local amount = (deltaBag > 0) and deltaBag or deltaOwned
            if deltaBag > 0 and deltaOwned > 0 then amount = min(deltaBag, deltaOwned) end
            if NotFromMerchantOrQuest(id) then
                CaptureAcquisition(id, row, amount, priorOwned)
            elseif deltaBag > 0 then
                DeferBlockedDelta(id, row, deltaBag, priorOwned)
            end
        end
    end

    for id, row in pairs(bags) do
        if row.partial then
            local prev = state.previousBags[id]
            if prev and prev.count > row.count then
                bags[id] = prev
                if (state.previousOwned[id] or 0) > (owned[id] or 0) then
                    owned[id] = state.previousOwned[id]
                end
            end
        end
    end
    state.previousBags = bags
    state.previousOwned = owned

    RecoverDeferred(bags, owned)
    local found = {}
    for id in pairs(SOURCE.pendingAcquisitions) do
        local item = InspectAcquisition(id, bags, owned)
        if item then found[#found + 1] = item end
    end
    if #found > 0 then DeliverAcquisitions(found) end
end

RequestScan = function()
    if state.scanQueued then return end
    state.scanQueued = true
    C_Timer.After(0.24, ProcessChanges)
end

--------------------------------------------------------------------------------
-- Marcos de Profissão (75 / 150 / 225 / 300)
--------------------------------------------------------------------------------
local function ReadProfessions()
    local readings = {}
    if type(_G.GetProfessions) ~= "function" or type(_G.GetProfessionInfo) ~= "function" then
        return readings
    end
    local cat = Cat()
    local p1, p2, arch, fish, cook, aid = _G.GetProfessions()
    for _, index in ipairs({ p1 or 0, p2 or 0, arch or 0, fish or 0, cook or 0, aid or 0 }) do
        if Valid(index, "number") and index > 0 then
            local ok, name, icon, level, maxLevel, _, _, skillLine = pcall(_G.GetProfessionInfo, index)
            if ok and Valid(level, "number") and Valid(skillLine, "number") then
                local def = (cat.skillTypes and cat.skillTypes[skillLine]) or {
                    pt = Valid(name, "string") and name or "Ofício",
                    en = Valid(name, "string") and name or "Profession",
                    kind = "skill_other",
                    icon = "Interface\\Icons\\INV_Misc_Book_06",
                }
                readings[skillLine] = {
                    level = level,
                    maximum = Valid(maxLevel, "number") and maxLevel or 300,
                    name = Valid(name, "string") and name or (LC.IsPT() and def.pt or def.en),
                    icon = Safe(icon) and icon or def.icon,
                    def = def,
                }
            end
        end
    end
    return readings
end

local function CelebrateSkill(skillLine, milestone, row, isTest)
    local cat = Cat()
    local def = (cat.skillTypes and cat.skillTypes[skillLine]) or (row and row.def)
    if not def then return end
    local cap = (row and row.maximum) or 300
    local profLabel = LC.IsPT() and def.pt or def.en
    local rankInfo = cat.milestoneRanks and cat.milestoneRanks[milestone]
    local rankName = rankInfo and (LC.IsPT() and rankInfo.pt or rankInfo.en) or LC.L("Ofício", "Profession")
    LC.Celebrate({
        kind = def.kind,
        name = format("%s  %d / %d", (row and row.name or profLabel), milestone, cap),
        icon = (row and row.icon) or def.icon,
        headline = format(LC.L("MARCO DE %s (%d)!", "%s %d REACHED!"), profLabel:upper(), milestone),
        subtitle = format(LC.L("Patamar %s alcançado!", "%s rank reached!"), rankName),
        test = isTest or nil,
    })
end

local function CheckSkillLevels()
    local readings = ReadProfessions()
    if not state.skillsReady then
        for skillLine, row in pairs(readings) do
            state.skillLevels[skillLine] = row.level
        end
        state.skillsReady = true
        return
    end
    local db = DB()
    for skillLine, row in pairs(readings) do
        local oldLevel = state.skillLevels[skillLine]
        if oldLevel and row.level > oldLevel and db.milestones ~= false then
            for _, target in ipairs((Cat().milestones) or { 75, 150, 225, 300 }) do
                if oldLevel < target and row.level >= target then
                    CelebrateSkill(skillLine, target, row, false)
                end
            end
        end
        state.skillLevels[skillLine] = row.level
    end
end

--------------------------------------------------------------------------------
-- Rastreadores de Rolagens (Need/Greed) & Inimigos Raros Abatidos
--------------------------------------------------------------------------------
local rollSeen, rareTargets, rareSeen = {}, {}, {}

local function RecordLootHistory(encounterID, lootKey)
    if not Valid(encounterID, "number") or not Valid(lootKey, "number") then return end
    local H = _G.C_LootHistory
    if not H or type(H.GetSortedInfoForDrop) ~= "function" then return end
    local key = tostring(encounterID) .. ":" .. tostring(lootKey)
    if rollSeen[key] then return end
    local ok, drop = pcall(H.GetSortedInfoForDrop, encounterID, lootKey)
    if not ok or not Valid(drop, "table") then return end
    if not drop.winner and not drop.allPassed then return end
    local rolls = drop.rollInfos
    if not Valid(rolls, "table") then return end

    for _, r in ipairs(rolls) do
        if Valid(r, "table") and Safe(r.isSelf) and r.isSelf == true and Valid(r.state, "number") then
            local choice = (r.state == 0 or r.state == 1) and "need" or (r.state == 3 and "greed" or nil)
            if not choice then rollSeen[key] = true; return end
            if Safe(r.isWinner) and r.isWinner == true and Valid(drop.itemHyperlink, "string") then
                local wonID = ExtractItemID(drop.itemHyperlink)
                if wonID then
                    MarkLootSignal(wonID, "loot-history-win", 150)
                    if ResolveAcquisition then ResolveAcquisition(wonID) end
                    if state.ready then RequestScan() end
                end
            end
            local quality = nil
            local link = drop.itemHyperlink
            if Valid(link, "string") then
                local itemID = ExtractItemID(link)
                if itemID and _G.C_Item and type(_G.C_Item.GetItemQualityByID) == "function" then
                    local okQ, qv = pcall(_G.C_Item.GetItemQualityByID, itemID)
                    if okQ and Valid(qv, "number") then quality = qv end
                end
                if quality == nil and type(_G.GetItemInfo) == "function" then
                    local okQ, _, _, qv = pcall(_G.GetItemInfo, link)
                    if okQ and Valid(qv, "number") then quality = qv end
                end
            end
            if quality == nil then return end
            local rolled = Valid(r.roll, "number") and r.roll or nil
            local won = Safe(r.isWinner) and r.isWinner == true
            rollSeen[key] = true
            if LC.RecordGroupRoll then LC.RecordGroupRoll(quality, rolled, won, choice) end
            return
        end
    end
end

local function GroupUnits()
    local units = { "player", "pet" }
    local n = type(_G.GetNumGroupMembers) == "function" and (_G.GetNumGroupMembers() or 0) or 0
    if type(_G.IsInRaid) == "function" and _G.IsInRaid() and n > 0 then
        for i = 1, min(n, 40) do
            units[#units + 1] = "raid" .. i
            units[#units + 1] = "raidpet" .. i
        end
    else
        for i = 1, 4 do
            units[#units + 1] = "party" .. i
            units[#units + 1] = "partypet" .. i
        end
    end
    return units
end

local function RememberRare(unit)
    if type(_G.UnitGUID) ~= "function" or type(_G.UnitClassification) ~= "function" then return end
    local ok, guid = pcall(_G.UnitGUID, unit)
    if not ok or not Valid(guid, "string") or rareSeen[guid] then return end
    local okC, cls = pcall(_G.UnitClassification, unit)
    if not okC or not Valid(cls, "string") or (cls ~= "rare" and cls ~= "rareelite") then return end
    local name = type(_G.UnitName) == "function" and _G.UnitName(unit) or nil
    if not Valid(name, "string") then return end

    local now = ClockNow()
    local rec = rareTargets[guid] or { name = name }
    rec.name, rec.seen, rec.unit = name, now, unit
    if LC.RarePortraits then
        rec.portrait = LC.RarePortraits.Capture(unit, guid, rec.portrait)
        rec.displayID = rec.portrait.displayID or rec.displayID
    end
    rareTargets[guid] = rec

    local cnt = 0
    for k, info in pairs(rareTargets) do
        if now - (info.seen or 0) > 120 then rareTargets[k] = nil else cnt = cnt + 1 end
    end
    if cnt > 350 then rareTargets = { [guid] = rec } end
end

local function IsOurGroupAttacker(attacker)
    if not Valid(attacker, "string") or type(_G.UnitGUID) ~= "function" then return false end
    for _, unit in ipairs(GroupUnits()) do
        local ok, guid = pcall(_G.UnitGUID, unit)
        if ok and Valid(guid, "string") and guid == attacker then return true end
    end
    return false
end

local function OnRareKill(attacker, victim)
    if DB().rareKills == false then return end
    if not Valid(victim, "string") or rareSeen[victim] or not IsOurGroupAttacker(attacker) then return end
    local rec = rareTargets[victim]
    if not rec or (ClockNow() - rec.seen) > 120 then return end
    if LC.RarePortraits then
        for _, unit in ipairs({ "target", "focus", "mouseover", rec.unit }) do
            rec.portrait = LC.RarePortraits.Capture(unit, victim, rec.portrait)
        end
        rec.displayID = rec.portrait.displayID or rec.displayID
    end
    rareTargets[victim] = nil
    rareSeen[victim] = ClockNow()
    local cnt = 0
    for guid, at in pairs(rareSeen) do
        if (ClockNow() - at) > 600 then rareSeen[guid] = nil else cnt = cnt + 1 end
    end
    if cnt > 300 then rareSeen = { [victim] = ClockNow() } end
    if LC.RecordRareKill then LC.RecordRareKill() end
    LC.Celebrate({
        kind = "rare_kill",
        name = rec.name,
        subtitle = LC.L("Inimigo raro eliminado em combate", "Rare enemy defeated in combat"),
        portrait = rec.portrait,
        portraitDisplayID = rec.displayID,
        portraitUnit = rec.unit,
        portraitGUID = victim,
        icon = "Interface\\Icons\\Ability_Warrior_BattleShout",
    })
end

--------------------------------------------------------------------------------
-- Ciclo de Vida & API do Módulo
--------------------------------------------------------------------------------
function M:ApplyLayout()
    if LC.ApplyAnchorLayout then LC.ApplyAnchorLayout() end
    if LC.ApplyAlertMovement then LC.ApplyAlertMovement() end
    if LC.RefreshBorderEffects then LC.RefreshBorderEffects() end
end

function M:Test(kind)
    kind = (type(kind) == "string" and kind ~= "") and kind:lower() or "showcase"
    if kind == "green" then
        LC.Celebrate({ kind = "green", id = 4726, name = "Manto do Brigadeiro-Chefe (Teste)", icon = "Interface\\Icons\\INV_Misc_Cape_02", test = true, previewPrices = true })
    elseif kind == "rare" then
        LC.Celebrate({ kind = "rare", id = 7717, name = "Assoladora / Ravager (Teste)", icon = "Interface\\Icons\\INV_Weapon_Halberd_05", test = true, previewPrices = true })
    elseif kind == "epic" then
        LC.Celebrate({ kind = "epic", id = 19364, name = "Ashkandi, Espada Larga da Irmandade (Teste)", icon = "Interface\\Icons\\INV_Sword_50", test = true, previewPrices = true })
    elseif kind == "legendary" then
        LC.Celebrate({ kind = "legendary", id = 19019, name = "Trovofúria, Lâmina Abençoada do Vento (Teste)", icon = "Interface\\Icons\\INV_Sword_39", test = true, previewPrices = true })
    elseif kind == "bloated" then
        LC.Celebrate({
            kind = "bloated", id = 13881,
            name = "Guelra-Rubra Inchado (Teste)", icon = "Interface\\Icons\\INV_Misc_Fish_02",
            headline = LC.L("NOVO PEIXE INCHADO!", "NEW BLOATED FISH JACKPOT!"),
            subtitle = LC.L("NOVA ESPÉCIE!  3/10 DESCOBERTOS  ·  5 PESCADOS", "NEW SPECIES!  3/10 DISCOVERED  ·  5 CAUGHT"),
            test = true,
        })
    elseif kind == "jackpot" then
        LC.Celebrate({
            kind = "jackpot", headline = LC.L("JACKPOT DUPLO ÉPICO!", "DOUBLE EPIC JACKPOT!"), test = true,
            items = {
                { id = 19364, name = "Lâmina Épica (Teste)", icon = "Interface\\Icons\\INV_Sword_50", kind = "epic" },
                { id = 7717,  name = "Elmo Raro (Teste)",    icon = "Interface\\Icons\\INV_Helmet_06", kind = "rare" },
            },
        })
    elseif kind == "rarekill" then
        LC.Celebrate({ kind = "rare_kill", name = "Lorde Sombrio de Azaath (Teste)", subtitle = LC.L("Inimigo raro eliminado", "Rare enemy defeated"), icon = "Interface\\Icons\\Ability_Warrior_BattleShout", test = true })
    elseif kind == "skill" then
        CelebrateSkill(186, 300, nil, true)
    elseif kind == "record" then
        LC.Celebrate({ kind = "fish", headline = LC.L("NOVO RECORDE PESSOAL!", "NEW PERSONAL RECORD!"), name = "40 Pound Redgill (Teste)", subtitle = LC.L("Recorde anterior: 37 lb", "Previous best: 37 lb"), icon = "Interface\\Icons\\INV_Misc_MonsterHead_02", test = true })
    else
        M:Test("epic")
        M:Test("bloated")
    end
end

function M:OnInitialize()
    self.db = Azaath.db.lootCelebration
    if LC.EnsureCharacterStats then LC.EnsureCharacterStats() end
end

function M:OnEnable()
    self:ApplyLayout()

    local ev = CreateFrame("Frame")
    local EVENTS = {
        "PLAYER_ENTERING_WORLD", "BAG_UPDATE", "BAG_UPDATE_DELAYED", "ITEM_COUNT_CHANGED",
        "GET_ITEM_INFO_RECEIVED", "ITEM_DATA_LOAD_RESULT", "PLAYER_EQUIPMENT_CHANGED",
        "LOOT_OPENED", "LOOT_READY", "CHAT_MSG_LOOT", "LOOT_ITEM_ROLL_WON",
        "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_CLEAR_HISTORY",
        "MAIL_SHOW", "MAIL_CLOSED", "MAIL_INBOX_UPDATE", "MAIL_SUCCESS",
        "TRADE_SHOW", "TRADE_CLOSED", "TRADE_ACCEPT_UPDATE",
        "MERCHANT_SHOW", "MERCHANT_CLOSED",
        "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED",
        "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_TURNED_IN", "QUEST_LOOT_RECEIVED",
        "CHAT_MSG_SKILL", "SKILL_LINES_CHANGED",
        "UNIT_SPELLCAST_CHANNEL_START", "UNIT_SPELLCAST_CHANNEL_STOP", "UNIT_SPELLCAST_SUCCEEDED",
        "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED",
        "PARTY_KILL", "UNIT_PORTRAIT_UPDATE", "UNIT_MODEL_CHANGED", "PORTRAITS_UPDATED",
    }
    for _, name in ipairs(EVENTS) do
        Azaath.SafeRegister(ev, name)
    end

    ev:SetScript("OnEvent", function(_, event, a, b, c)
        if event == "PLAYER_ENTERING_WORLD" then
            SOURCE.merchantOpen, SOURCE.merchantUntil = false, 0
            SOURCE.mailOpen,     SOURCE.mailUntil     = false, 0
            SOURCE.tradeOpen,    SOURCE.tradeUntil    = false, 0
            SOURCE.questOpen,    SOURCE.questUntil    = false, 0
            SOURCE.auctionOpen,  SOURCE.auctionUntil  = false, 0
            if state.ready then
                state.zoneGuardUntil = ClockNow() + 4
                C_Timer.After(0.7, function() if state.ready then RequestScan() end end)
                C_Timer.After(2.0, function() if state.ready then RequestScan() end end)
                C_Timer.After(4.2, function() if state.ready then RequestScan() end end)
            elseif not state.bootstrapPending then
                state.bootstrapPending = true
                local function InitializeBags()
                    local bags, okScan = ScanBags()
                    if not okScan then
                        C_Timer.After(0.6, InitializeBags)
                        return
                    end
                    state.previousBags = bags
                    state.previousOwned = ScanOwned(bags)
                    state.ready = true
                    state.bootstrapPending = false
                    CheckSkillLevels()
                end
                C_Timer.After(2.0, InitializeBags)
            end
            if not state.skillTicker and type(C_Timer.NewTicker) == "function" then
                state.skillTicker = C_Timer.NewTicker(2.5, function()
                    if state.ready and Azaath.db then CheckSkillLevels() end
                end)
            end
        elseif event == "TRADE_SHOW" then
            SOURCE.tradeOpen = true
        elseif event == "TRADE_ACCEPT_UPDATE" then
            SOURCE.tradeUntil = ClockNow() + 8
        elseif event == "TRADE_CLOSED" then
            SOURCE.tradeOpen = false; SOURCE.tradeUntil = ClockNow() + 8
        elseif event == "MAIL_SHOW" then
            SOURCE.mailOpen = true
        elseif event == "MAIL_CLOSED" then
            SOURCE.mailOpen = false; SOURCE.mailUntil = ClockNow() + 8
        elseif event == "MAIL_INBOX_UPDATE" or event == "MAIL_SUCCESS" then
            SOURCE.mailUntil = ClockNow() + 8
        elseif event == "MERCHANT_SHOW" then
            SOURCE.merchantOpen = true
        elseif event == "MERCHANT_CLOSED" then
            SOURCE.merchantOpen = false; SOURCE.merchantUntil = ClockNow() + 3
        elseif event == "AUCTION_HOUSE_SHOW" then
            SOURCE.auctionOpen = true
        elseif event == "AUCTION_HOUSE_CLOSED" then
            SOURCE.auctionOpen = false; SOURCE.auctionUntil = ClockNow() + 3
        elseif event == "QUEST_COMPLETE" then
            SOURCE.questOpen = true; RememberQuestRewardIDs()
        elseif event == "QUEST_TURNED_IN" then
            SOURCE.questOpen = false; SOURCE.questUntil = ClockNow() + 5
        elseif event == "QUEST_FINISHED" then
            SOURCE.questOpen = false
        elseif event == "QUEST_LOOT_RECEIVED" then
            SOURCE.questUntil = ClockNow() + 5
            local id = ExtractItemID(b)
            if id then SOURCE.rewardIDs[id] = ClockNow() + 120 end
        elseif event == "LOOT_OPENED" or event == "LOOT_READY" then
            RememberVisibleLoot()
            ResolveAllAcquisitions()
        elseif event == "CHAT_MSG_LOOT" then
            local selfLoot = IsSelfLootMsg(a)
            local selfWon = IsSelfWinMsg(a)
            if selfLoot or selfWon then
                local id = ExtractItemID(a)
                if id then
                    local via = selfWon and "self-win-chat" or "self-loot-chat"
                    MarkLootSignal(id, via, selfWon and 150 or 90)
                    ResolveAcquisition(id)
                    if state.ready then
                        RequestScan()
                        C_Timer.After(0.8, RequestScan)
                        C_Timer.After(3.5, RequestScan)
                    end
                end
            end
        elseif event == "LOOT_ITEM_ROLL_WON" then
            local id = ExtractItemID(a)
            MarkLootSignal(id, "won-roll", 150)
            if id then
                ResolveAcquisition(id)
                if state.ready then RequestScan(); C_Timer.After(0.9, RequestScan) end
            end
        elseif event == "LOOT_HISTORY_UPDATE_DROP" then
            RecordLootHistory(a, b)
        elseif event == "LOOT_HISTORY_CLEAR_HISTORY" then
            rollSeen = {}
        elseif event == "GET_ITEM_INFO_RECEIVED" or event == "ITEM_DATA_LOAD_RESULT" then
            if Valid(a, "number") then
                ResolveAcquisition(a)
                if state.ready and (SOURCE.pendingAcquisitions[a] or HasLootSignal(a)) then RequestScan() end
            end
        elseif event == "CHAT_MSG_SKILL" or event == "SKILL_LINES_CHANGED" then
            if state.skillsReady then
                C_Timer.After(0.15, CheckSkillLevels)
                C_Timer.After(0.80, CheckSkillLevels)
            end
        elseif (event == "UNIT_SPELLCAST_CHANNEL_START" or event == "UNIT_SPELLCAST_CHANNEL_STOP" or event == "UNIT_SPELLCAST_SUCCEEDED")
               and Valid(a, "string") and a == "player" and Valid(c, "number") and (Cat().fishingCasts and Cat().fishingCasts[c]) then
            local now = ClockNow()
            if event == "UNIT_SPELLCAST_CHANNEL_STOP" then
                state.fishingActive = false
                state.fishingEndedAt = now
            else
                state.fishingActive = true
                state.fishingStartedAt = now
                state.fishingEndedAt = nil
            end
        elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" or event == "PLAYER_EQUIPMENT_CHANGED" or event == "ITEM_COUNT_CHANGED" then
            if state.ready then RequestScan() end
        elseif event == "PLAYER_TARGET_CHANGED" then
            RememberRare("target")
        elseif event == "UPDATE_MOUSEOVER_UNIT" then
            RememberRare("mouseover")
        elseif event == "NAME_PLATE_UNIT_ADDED" and Valid(a, "string") then
            RememberRare(a)
        elseif (event == "UNIT_PORTRAIT_UPDATE" or event == "UNIT_MODEL_CHANGED") and Valid(a, "string") then
            RememberRare(a)
        elseif event == "PORTRAITS_UPDATED" then
            RememberRare("target"); RememberRare("focus"); RememberRare("mouseover")
        elseif event == "PARTY_KILL" then
            OnRareKill(a, b)
        end
    end)
end
