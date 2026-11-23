--[[----------------------------------------------------------------------------
    AzaathUI - Modules/LootCelebration/Stats.lua
    Estatísticas persistentes (por personagem e consolidadas), Diário de Pesca,
    breakdown de saques, histórico de rolagens (Need/Greed) e preços opcionais
    de vendedor + Auctionator.
    Baseado em LootDopamine/Stats.lua e AHPrices.lua (MIT).
------------------------------------------------------------------------------]]

local _, Azaath = ...

local LC = Azaath.LootCel or {}
Azaath.LootCel = LC

local _G = _G
local ipairs, pairs, pcall, tostring, tonumber, type = ipairs, pairs, pcall, tostring, tonumber, type
local floor, max, format = math.floor, math.max, string.format
local tsort = table.sort

--------------------------------------------------------------------------------
-- Idioma & Utilidades
--------------------------------------------------------------------------------
function LC.IsPT()
    local cfg = Azaath.ConfigUI
    if cfg and cfg.LangCode then
        return cfg.LangCode() == "ptBR"
    end
    return _G.GetLocale and _G.GetLocale() == "ptBR"
end

function LC.L(pt, en)
    return LC.IsPT() and pt or en
end

local function Safe(v)
    return not Azaath.IsSecret(v)
end

local function FormatMoneyClean(copper)
    if not Safe(copper) or type(copper) ~= "number" or copper < 0 then return nil end
    copper = floor(copper)
    local g = floor(copper / 10000)
    local s = floor(copper / 100) % 100
    local c = copper % 100
    if g > 0 then
        return format("|cffffd700%s|r|cffe0c994g|r |cffc7c7cf%d|r|cffa6acb4s|r |cffeda55f%d|r|cffb88357c|r",
            Azaath.Thousands(g), s, c)
    elseif s > 0 then
        return format("|cffc7c7cf%d|r|cffa6acb4s|r |cffeda55f%d|r|cffb88357c|r", s, c)
    end
    return format("|cffeda55f%d|r|cffb88357c|r", c)
end
LC.FormatMoney = FormatMoneyClean

--------------------------------------------------------------------------------
-- Preços: Vendedor & Auctionator (opcional, somente leitura)
--------------------------------------------------------------------------------
local AH_CALLER = "AzaathUI"

local function AuctionatorV1()
    local a = _G.Auctionator
    return type(a) == "table" and type(a.API) == "table" and type(a.API.v1) == "table" and a.API.v1 or nil
end

-- leilão próprio (Modules/Auction) primeiro; Auctionator só se ele não tiver o preço
local AZ_AH = {
    GetAuctionPriceByItemLink = 1, GetAuctionPriceByItemID = 1,
    GetAuctionAgeByItemLink = 2, GetAuctionAgeByItemID = 2,
}
local function CallAH(method, arg)
    local AN = Azaath.AuctionNS
    if AN and AZ_AH[method] then
        local price, age = AN.GetPrice(arg)
        if price then return AZ_AH[method] == 1 and price or age end
    end
    local a = AuctionatorV1()
    if not a or type(a[method]) ~= "function" then return nil end
    local ok, res = pcall(a[method], AH_CALLER, arg)
    if ok and Safe(res) then return res end
    return nil
end

function LC.GetAHStatus()
    local a = AuctionatorV1()
    local connected = a and (type(a.GetAuctionPriceByItemLink) == "function" or type(a.GetAuctionPriceByItemID) == "function") or false
    local own = Azaath.AuctionNS ~= nil
    return {
        installed = own or type(_G.Auctionator) == "table",
        enabled = own or connected,
        ageSupported = own or (a and (type(a.GetAuctionAgeByItemLink) == "function" or type(a.GetAuctionAgeByItemID) == "function")) or false,
    }
end

function LC.GetAHPrice(item, previewPrices)
    local db = Azaath.db and Azaath.db.lootCelebration
    if (db and db.showAH == false and previewPrices ~= true) or type(item) ~= "table" then
        return nil
    end
    local id, link = item.id, item.link
    if type(link) ~= "string" or link == "" then link = nil end
    if type(id) ~= "number" and link then
        id = tonumber(link:match("item:(%d+)"))
    end
    local copper, ageDays
    if link then
        copper = CallAH("GetAuctionPriceByItemLink", link)
        ageDays = CallAH("GetAuctionAgeByItemLink", link)
    elseif type(id) == "number" then
        copper = CallAH("GetAuctionPriceByItemID", id)
        ageDays = CallAH("GetAuctionAgeByItemID", id)
    end
    if type(copper) ~= "number" or copper <= 0 then return nil end

    local ageText, ageColor = LC.L("Idade do preço indisponível", "Price age unavailable"), "unknown"
    if type(ageDays) == "number" and ageDays >= 0 then
        ageDays = floor(ageDays)
        if ageDays == 0 then
            ageText, ageColor = LC.L("Dados: Hoje", "Price data: Today"), "fresh"
        elseif ageDays == 1 then
            ageText, ageColor = LC.L("Dados: Ontem", "Price data: Yesterday"), "recent"
        elseif ageDays < 7 then
            ageText, ageColor = format(LC.L("Dados: %d dias atrás", "Price data: %d days old"), ageDays), "aging"
        else
            ageText, ageColor = format(LC.L("Dados: %d dias (antigo)", "Price data: %d days (stale)"), ageDays), "stale"
        end
    else
        ageDays = nil
    end

    return {
        price = FormatMoneyClean(copper),
        copper = copper,
        ageDays = ageDays,
        ageText = ageText,
        ageColor = ageColor,
        stale = ageColor == "stale",
    }
end

function LC.GetVendorValue(item)
    if type(item) ~= "table" then return nil end
    local key = item.link or item.id
    if not key then return nil end
    local info = (_G.C_Item and _G.C_Item.GetItemInfo) or _G.GetItemInfo
    if type(info) ~= "function" then return nil end
    local ok, _, _, _, _, _, _, _, _, _, _, vendor = pcall(info, key)
    if not ok or type(vendor) ~= "number" or not Safe(vendor) or vendor <= 0 then
        return nil
    end
    return { price = FormatMoneyClean(vendor), copper = vendor }
end

--------------------------------------------------------------------------------
-- Banco de Estatísticas (SavedVariables: AzaathUIDB.lootStats)
--------------------------------------------------------------------------------
local function CharKey()
    local name, realm
    if type(_G.UnitFullName) == "function" then
        name, realm = _G.UnitFullName("player")
    end
    if not Safe(name) or type(name) ~= "string" or name == "" then
        name = type(_G.UnitName) == "function" and _G.UnitName("player") or "Jogador"
    end
    if not Safe(name) or type(name) ~= "string" then name = "Jogador" end
    if not Safe(realm) or type(realm) ~= "string" or realm == "" then
        realm = type(_G.GetRealmName) == "function" and _G.GetRealmName() or "Realm"
    end
    if not Safe(realm) or type(realm) ~= "string" then realm = "Realm" end
    return name .. "-" .. realm, name, realm
end

local function BaseStats()
    return {
        name = "", realm = "",
        trackingSince = nil,
        fishing = { total = 0, entries = {}, records = {} },
        loot = { green = 0, rare = 0, epic = 0, legendary = 0, bags = 0, bagsOnly = 0, items = {} },
        rolls = { schema = 2, need = {}, greed = {} },
        rareKills = 0,
        companions = 0,
    }
end

local function StatsRoot()
    if not _G.AzaathUIDB then return nil end
    _G.AzaathUIDB.lootStats = _G.AzaathUIDB.lootStats or { characters = {} }
    local root = _G.AzaathUIDB.lootStats
    root.characters = root.characters or {}
    if not root.firstTrackingAt and type(_G.time) == "function" then
        local ok, stamp = pcall(_G.time)
        if ok and type(stamp) == "number" and stamp > 0 then
            root.firstTrackingAt = stamp
        end
    end
    return root
end

function LC.EnsureCharacterStats()
    local root = StatsRoot()
    if not root then return nil end
    local key, name, realm = CharKey()
    local c = root.characters[key]
    if type(c) ~= "table" then
        c = BaseStats()
        if type(_G.time) == "function" then
            local ok, stamp = pcall(_G.time)
            if ok and type(stamp) == "number" and stamp > 0 then
                c.trackingSince = stamp
            end
        end
        root.characters[key] = c
    end
    c.name, c.realm = name, realm
    c.fishing = c.fishing or { total = 0, entries = {}, records = {} }
    c.fishing.entries = c.fishing.entries or {}
    c.fishing.records = c.fishing.records or {}
    c.loot = c.loot or { green = 0, rare = 0, epic = 0, legendary = 0, bags = 0, bagsOnly = 0, items = {} }
    c.loot.items = c.loot.items or {}
    c.loot.bags = c.loot.bags or 0
    c.loot.bagsOnly = c.loot.bagsOnly or 0
    if type(c.rolls) ~= "table" or c.rolls.schema ~= 2 then
        c.rolls = { schema = 2, need = {}, greed = {} }
    end
    c.rolls.need = c.rolls.need or {}
    c.rolls.greed = c.rolls.greed or {}
    c.rareKills = c.rareKills or 0
    c.companions = c.companions or 0
    LC.characterKey = key
    return c
end

local function NotifyJournal()
    if LC.RefreshJournal then LC.RefreshJournal() end
end

local function FishKey(id, name)
    return id and ("id:" .. tostring(id)) or ("name:" .. (name or "Unknown"):lower())
end

local function TrophyInfo(name, id)
    local cat = Azaath.LootCatalog
    local mapped = id and cat and cat.trophyByID and cat.trophyByID[id]
    if mapped then return mapped.weight, mapped.family end
    if type(name) ~= "string" then return nil end
    local pounds, family = name:match("^(%d+) [Pp]ound (.+)$")
    if pounds then return tonumber(pounds), family end
    local lb2, fam2 = name:match("^(.+) de (%d+) [Ll]ibras$")
    if lb2 then return tonumber(fam2), lb2 end
    return nil
end

function LC.RecordCatch(id, name, count)
    local c = LC.EnsureCharacterStats()
    if not c or type(name) ~= "string" then return nil end
    count = max(1, floor(tonumber(count) or 1))
    local key = FishKey(id, name)
    local entry = c.fishing.entries[key]
    if not entry then
        entry = { id = id, name = name, count = 0 }
        c.fishing.entries[key] = entry
    end
    entry.count = entry.count + count
    c.fishing.total = (c.fishing.total or 0) + count

    local weight, family = TrophyInfo(name, id)
    local best = nil
    if weight and family then
        local prev = c.fishing.records[family] or 0
        if weight > prev then
            c.fishing.records[family] = weight
            best = { weight = weight, family = family, previous = prev }
        end
    end
    NotifyJournal()
    return best
end

local QUALITY_KEYS = { [2] = "green", [3] = "rare", [4] = "epic", [5] = "legendary" }

local function ItemMetadata(id, quality)
    local meta = { quality = quality }
    local fn = _G.C_Item and _G.C_Item.GetItemInfo or _G.GetItemInfo
    if type(fn) == "function" then
        local ok, _, _, q, itemLevel, _, _, _, _, equipLoc, _, _, classID, subclassID, bindType = pcall(fn, id)
        if ok then
            if Safe(q) and type(q) == "number" then meta.quality = q end
            if Safe(itemLevel) and type(itemLevel) == "number" then meta.itemLevel = itemLevel end
            if Safe(classID) and type(classID) == "number" then meta.classID = classID end
            if Safe(subclassID) and type(subclassID) == "number" then meta.subclassID = subclassID end
            if Safe(equipLoc) and type(equipLoc) == "string" then meta.equipLoc = equipLoc end
            if Safe(bindType) and type(bindType) == "number" then meta.bindType = bindType end
        end
    end
    return meta
end

local function RecordItem(c, id, count, quality)
    if type(id) ~= "number" or id < 1 or id ~= floor(id) then return end
    local key = tostring(id)
    local r = c.loot.items[key]
    if type(r) ~= "table" then
        r = { id = id, count = 0 }
        c.loot.items[key] = r
    end
    r.count = (r.count or 0) + count
    for k, v in pairs(ItemMetadata(id, quality)) do
        r[k] = v
    end
    if type(_G.time) == "function" then
        local ok, stamp = pcall(_G.time)
        if ok and type(stamp) == "number" then r.lastSeen = stamp end
    end
end

function LC.RecordLoot(quality, count, item)
    local kind = QUALITY_KEYS[quality]
    local c = LC.EnsureCharacterStats()
    if not c or not kind then return end
    count = max(1, floor(tonumber(count) or 1))
    c.loot[kind] = (c.loot[kind] or 0) + count
    RecordItem(c, type(item) == "table" and item.id or nil, count, quality)
    NotifyJournal()
end

function LC.RecordBag(quality, count, item)
    local c = LC.EnsureCharacterStats()
    if not c then return end
    count = max(1, floor(tonumber(count) or 1))
    c.loot.bags = (c.loot.bags or 0) + count
    if quality and quality >= 2 and quality <= 5 then
        LC.RecordLoot(quality, count, item)
    else
        c.loot.bagsOnly = (c.loot.bagsOnly or 0) + count
        RecordItem(c, type(item) == "table" and item.id or nil, count, quality or 1)
        NotifyJournal()
    end
end

function LC.RecordCompanion(quality, count, item)
    local c = LC.EnsureCharacterStats()
    if not c then return end
    count = max(1, floor(tonumber(count) or 1))
    c.companions = (c.companions or 0) + count
    RecordItem(c, type(item) == "table" and item.id or nil, count, quality or 1)
    NotifyJournal()
end

function LC.RecordRareKill()
    local c = LC.EnsureCharacterStats()
    if not c then return end
    c.rareKills = (c.rareKills or 0) + 1
    NotifyJournal()
end

function LC.RecordGroupRoll(quality, roll, won, choice)
    if choice ~= "need" and choice ~= "greed" then return end
    local c = LC.EnsureCharacterStats()
    if not c then return end
    local kind = QUALITY_KEYS[quality] or "other"
    local bucket = c.rolls[choice]
    local g = bucket[kind]
    if not g then
        g = { count = 0, sum = 0, known = 0, won = 0 }
        bucket[kind] = g
    end
    g.count = g.count + 1
    if type(roll) == "number" and roll >= 1 and roll <= 100 then
        g.sum = g.sum + roll
        g.known = g.known + 1
    end
    if won == true then
        g.won = g.won + 1
    end
    NotifyJournal()
end

--------------------------------------------------------------------------------
-- Consultas Consolidadas ("char" | "all")
--------------------------------------------------------------------------------
local function MergeStats(target, src)
    local f = src.fishing or {}
    target.fishing.total = target.fishing.total + (f.total or 0)
    for k, v in pairs(f.entries or {}) do
        if type(v) == "table" then
            local to = target.fishing.entries[k]
            if not to then
                to = { id = v.id, name = v.name, count = 0 }
                target.fishing.entries[k] = to
            end
            to.count = to.count + (v.count or 0)
        end
    end
    for family, value in pairs(f.records or {}) do
        target.fishing.records[family] = max(value, target.fishing.records[family] or 0)
    end
    local sl = src.loot or {}
    for _, k in ipairs({ "green", "rare", "epic", "legendary", "bags", "bagsOnly" }) do
        target.loot[k] = (target.loot[k] or 0) + (sl[k] or 0)
    end
    for key, item in pairs(sl.items or {}) do
        if type(item) == "table" then
            local to = target.loot.items[key]
            if not to then
                to = {}
                target.loot.items[key] = to
            end
            for field, value in pairs(item) do
                if field == "count" then
                    to.count = (to.count or 0) + (value or 0)
                elseif field == "lastSeen" then
                    to.lastSeen = max(to.lastSeen or 0, value or 0)
                elseif to[field] == nil then
                    to[field] = value
                end
            end
        end
    end
    if type(src.rolls) == "table" and src.rolls.schema == 2 then
        for _, choice in ipairs({ "need", "greed" }) do
            for kind, g in pairs(src.rolls[choice] or {}) do
                local to = target.rolls[choice][kind]
                if not to then
                    to = { count = 0, sum = 0, known = 0, won = 0 }
                    target.rolls[choice][kind] = to
                end
                for _, k in ipairs({ "count", "sum", "known", "won" }) do
                    to[k] = (to[k] or 0) + (g[k] or 0)
                end
            end
        end
    end
    target.rareKills = target.rareKills + (src.rareKills or 0)
    target.companions = (target.companions or 0) + (src.companions or 0)
    if type(src.trackingSince) == "number" and src.trackingSince > 0 then
        if not target.trackingSince or src.trackingSince < target.trackingSince then
            target.trackingSince = src.trackingSince
        end
    end
end

function LC.GetStats(scope)
    local current = LC.EnsureCharacterStats()
    if not current then return BaseStats() end
    if scope == "char" then return current end
    local root = StatsRoot()
    local total = BaseStats()
    total.name = LC.L("Todos os personagens", "All characters")
    for _, v in pairs((root and root.characters) or {}) do
        if type(v) == "table" then
            MergeStats(total, v)
        end
    end
    return total
end

function LC.GetBloatedStats(scope)
    local cat = Azaath.LootCatalog or {}
    local stats = LC.GetStats(scope)
    local byID = {}
    local defs = cat.bloatedFish or {}
    local species = cat.bloatedSpeciesCount or 0
    for id in pairs(defs) do byID[id] = 0 end
    for key, entry in pairs((stats.fishing and stats.fishing.entries) or {}) do
        if type(entry) == "table" and type(entry.count) == "number" and entry.count > 0 then
            local id = tonumber(entry.id)
            if not id and type(key) == "string" then
                id = tonumber(key:match("^id:(%d+)$"))
            end
            if not id and type(entry.name) == "string" and cat.fishByName then
                local known = cat.fishByName[entry.name:lower()]
                id = known and known.id
            end
            if id and defs[id] then
                byID[id] = byID[id] + entry.count
            end
        end
    end
    local total, discovered, list = 0, 0, {}
    for id, name in pairs(defs) do
        local count = byID[id] or 0
        total = total + count
        if count > 0 then discovered = discovered + 1 end
        list[#list + 1] = { id = id, name = name, count = count }
    end
    tsort(list, function(a, b)
        if a.count ~= b.count then return a.count > b.count end
        return a.name < b.name
    end)
    return { total = total, discovered = discovered, species = species, byID = byID, entries = list }
end

function LC.BuildFishRows(scope, sortMode, showUnknown, query, sortDirection, category)
    local cat = Azaath.LootCatalog or {}
    local stats = LC.GetStats(scope)
    local map, rows = {}, {}
    for _, f in ipairs(cat.fishCatalogue or {}) do
        local key = FishKey(f.id, f.name)
        map[key] = {
            id = f.id, name = f.name, tier = f.tier or 1, count = 0,
            weight = f.weight, family = f.family, category = f.category or "fish",
        }
    end
    for k, v in pairs((stats.fishing and stats.fishing.entries) or {}) do
        local found = (v.id and cat.fishByID and cat.fishByID[v.id]) or
                      (cat.fishByName and v.name and cat.fishByName[v.name:lower()])
        local key = found and FishKey(found.id, found.name) or k
        local dest = map[key]
        if not dest then
            dest = {
                name = v.name, id = v.id, count = 0,
                tier = found and found.tier or 0,
                category = found and found.category or "find",
            }
            map[key] = dest
        end
        dest.count = dest.count + (v.count or 0)
    end
    query = (query or ""):lower()
    for _, r in pairs(map) do
        if (not category or category == "all" or r.category == category)
           and (showUnknown or r.count > 0)
           and (query == "" or (r.name or ""):lower():find(query, 1, true)) then
            rows[#rows + 1] = r
        end
    end
    local desc = (sortDirection ~= "asc")
    tsort(rows, function(a, b)
        local cmp = 0
        if sortMode == "count" then
            if a.count ~= b.count then cmp = a.count > b.count and 1 or -1 end
            if cmp == 0 and a.tier ~= b.tier then cmp = a.tier > b.tier and 1 or -1 end
        elseif sortMode == "name" then
            local an, bn = (a.name or ""):lower(), (b.name or ""):lower()
            if an ~= bn then cmp = an > bn and 1 or -1 end
        else
            if a.tier ~= b.tier then cmp = a.tier > b.tier and 1 or -1 end
            if cmp == 0 and a.count ~= b.count then cmp = a.count > b.count and 1 or -1 end
        end
        if cmp == 0 then return (a.name or "") < (b.name or "") end
        return desc and cmp > 0 or (not desc and cmp < 0)
    end)
    return rows
end

local SLOT_KEYS = {
    INVTYPE_HEAD = "Head", INVTYPE_SHOULDER = "Shoulders", INVTYPE_NECK = "Neck",
    INVTYPE_CHEST = "Chest", INVTYPE_ROBE = "Chest", INVTYPE_CLOAK = "Back",
    INVTYPE_WRIST = "Wrists", INVTYPE_HAND = "Hands", INVTYPE_WAIST = "Waist",
    INVTYPE_LEGS = "Legs", INVTYPE_FEET = "Feet", INVTYPE_FINGER = "Rings",
    INVTYPE_TRINKET = "Trinkets", INVTYPE_SHIELD = "Shields",
    INVTYPE_WEAPON = "Weapons", INVTYPE_2HWEAPON = "Weapons",
    INVTYPE_WEAPONMAINHAND = "Weapons", INVTYPE_WEAPONOFFHAND = "Weapons",
    INVTYPE_RANGED = "Ranged", INVTYPE_RANGEDRIGHT = "Ranged",
    INVTYPE_THROWN = "Ranged", INVTYPE_HOLDABLE = "Off-hand items",
    INVTYPE_BAG = "Bags", INVTYPE_REAGENTBAG = "Bags", INVTYPE_TABARD = "Tabards", INVTYPE_BODY = "Shirts",
}

local SLOT_LABELS_PT = {
    Head = "Cabeça", Shoulders = "Ombros", Neck = "Colar", Chest = "Torso",
    Back = "Capa", Wrists = "Pulsos", Hands = "Mãos", Waist = "Cintura",
    Legs = "Pernas", Feet = "Pés", Rings = "Anéis", Trinkets = "Berloques",
    Shields = "Escudos", Weapons = "Armas", Ranged = "Alcance",
    ["Off-hand items"] = "Mão Secundária", Bags = "Bolsas", Tabards = "Tabardos",
    Shirts = "Camisas", Recipes = "Receitas", Materials = "Materiais",
    Consumables = "Consumíveis", ["Other armor"] = "Outras Armaduras",
    ["Other items"] = "Outros Itens", Unclassified = "Não Classificado",
}

local function ItemCategory(item)
    local loc = item.equipLoc
    if type(loc) == "string" and SLOT_KEYS[loc] then return SLOT_KEYS[loc] end
    local class = item.classID
    if class == 1 then return "Bags" end
    if class == 2 then return "Weapons" end
    if class == 9 then return "Recipes" end
    if class == 7 then return "Materials" end
    if class == 0 then return "Consumables" end
    if class == 4 then return "Other armor" end
    if type(class) == "number" then return "Other items" end
    return "Unclassified"
end

function LC.GetLootBreakdown(scope, rarity)
    local stats = LC.GetStats(scope)
    local l = stats.loot or {}
    local quality = ({ green = 2, rare = 3, epic = 4 })[rarity]
    if not quality then return {} end
    local counts, assigned = {}, 0
    for _, entry in pairs(l.items or {}) do
        if type(entry) == "table" and entry.quality == quality then
            local n = max(0, tonumber(entry.count) or 0)
            local key = ItemCategory(entry)
            counts[key] = (counts[key] or 0) + n
            assigned = assigned + n
        end
    end
    local historic = max(0, (l[rarity] or 0) - assigned)
    if historic > 0 then
        counts["Unclassified"] = (counts["Unclassified"] or 0) + historic
    end
    local pt = LC.IsPT()
    local rows = {}
    for key, count in pairs(counts) do
        rows[#rows + 1] = { key = key, name = pt and (SLOT_LABELS_PT[key] or key) or key, count = count }
    end
    tsort(rows, function(a, b)
        if a.count == b.count then return a.name < b.name end
        return a.count > b.count
    end)
    return rows
end
