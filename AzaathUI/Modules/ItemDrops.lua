--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ItemDrops.lua
    Motor de Equipamentos, Itens Dropáveis e Craftáveis (Fase 4):
      * Lê Azaath.ItemDropsSrcRaw e Azaath.ItemDropsRaw sob demanda.
      * Cada item traz: quality, reqLevel, iLvl, classID (2=Arma, 4=Armadura),
        subclassID (1=Tecido, 2=Couro, 3=Malha, 4=Placa, 6=Escudo, 0=Acessório),
        invType e kindMask (1=Mundo Aberto, 2=Masmorra/Raide, 4=Craftável).
      * Aprende novos drops em tempo real via LOOT_OPENED.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("ItemDrops")

local _G = _G
local pcall, type, ipairs, pairs, tonumber = pcall, type, ipairs, pairs, tonumber
local band = bit.band

local parsed = false
local sources = {}     -- [key] = { key, name, map, x, y }
local items = {}       -- [itemID] = entry
local sortedItems = {} -- ordenado em ordem alfabética (NormSearch)
local byZone = {}      -- [uiMapID] = { entry, ... }

local function Safe(fn, ...)
    if not fn then return end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

local function DecodeURI(s)
    if not s or s == "" or not s:find("%", 1, true) then return s end
    return (s:gsub("%%(%x%x)", function(h)
        return string.char(tonumber(h, 16))
    end))
end

local function EffectiveLevel(e)
    local r = e.reqLevel or 0
    if r > 0 then return r end
    return e.iLvl or 0
end

local function CompareEntries(a, b)
    local sa, sb = a.sortName or a.searchKey or "", b.sortName or b.searchKey or ""
    if sa ~= sb then return sa < sb end
    local na, nb = a.name or "", b.name or ""
    if na ~= nb then return na < nb end
    return (a.id or 0) < (b.id or 0)
end

local function CompareByLevelAsc(ra, rb)
    local a, b = ra.entry, rb.entry
    local la, lb = EffectiveLevel(a), EffectiveLevel(b)
    if la ~= lb then return la < lb end
    local raHas, rbHas = (a.reqLevel or 0) > 0, (b.reqLevel or 0) > 0
    if raHas ~= rbHas then return raHas end
    local ia, ib = a.iLvl or 0, b.iLvl or 0
    if ia ~= ib then return ia < ib end
    return CompareEntries(a, b)
end

local FOLD = {
    ["á"]="a", ["à"]="a", ["â"]="a", ["ã"]="a", ["ä"]="a",
    ["Á"]="a", ["À"]="a", ["Â"]="a", ["Ã"]="a", ["Ä"]="a",
    ["é"]="e", ["è"]="e", ["ê"]="e", ["ë"]="e",
    ["É"]="e", ["È"]="e", ["Ê"]="e", ["Ë"]="e",
    ["í"]="i", ["ì"]="i", ["î"]="i", ["ï"]="i",
    ["Í"]="i", ["Ì"]="i", ["Î"]="i", ["Ï"]="i",
    ["ó"]="o", ["ò"]="o", ["ô"]="o", ["õ"]="o", ["ö"]="o",
    ["Ó"]="o", ["Ò"]="o", ["Ô"]="o", ["Õ"]="o", ["Ö"]="o",
    ["ú"]="u", ["ù"]="u", ["û"]="u", ["ü"]="u",
    ["Ú"]="u", ["Ù"]="u", ["Û"]="u", ["Ü"]="u",
    ["ç"]="c", ["Ç"]="c",
}
local function NormSearch(s)
    if not s or s == "" then return "" end
    return s:gsub("[\194-\244][\128-\191]*", FOLD):lower()
end

local PROF_NAMES = {
    [1]  = "Alquimia",
    [2]  = "Ferraria",
    [3]  = "Encantamento",
    [4]  = "Engenharia",
    [5]  = "Couraria",
    [6]  = "Alfaiataria",
    [7]  = "Joalheria",
    [8]  = "Mineração",
    [9]  = "Herborismo",
    [10] = "Esfolamento",
    [11] = "Culinária",
    [12] = "Primeiros Socorros",
    [13] = "Pesca",
}

-- Idioma dos nomes: o escolhido nas configurações do Azaath (padrão = idioma do cliente).
-- Português: nome pt-BR do banco; inglês: o original. Mudar o idioma pede /reload.
local function IsPt()
    local cfg = Azaath.ConfigUI
    if cfg and cfg.LangCode then return cfg.LangCode() == "ptBR" end
    return GetLocale and GetLocale() == "ptBR"
end
M.IsPt = IsPt

-- Nome do item para mostrar. Sem tradução no banco (ptMissing), o cliente em português dá o nome
-- localizado assim que o item estiver carregado.
function M:DisplayName(e)
    if not e then return "" end
    if e.ptMissing and IsPt() and GetLocale and GetLocale() == "ptBR" then
        local CI = _G.C_Item
        local n = CI and CI.GetItemNameByID and Safe(CI.GetItemNameByID, e.id)
        if type(n) == "string" and n ~= "" then return n end
    end
    return e.name
end

local function EnsureParsed()
    if parsed then return end
    parsed = true
    local pt = IsPt()

    local recipes = {}
    if type(Azaath.ItemDropsRecipesRaw) == "string" then
        for line in Azaath.ItemDropsRecipesRaw:gmatch("[^\r\n]+") do
            local rid, rname = line:match("^(%d+)\t(.+)$")
            if rid then recipes[tonumber(rid)] = DecodeURI(rname) end
        end
        Azaath.ItemDropsRecipesRaw = nil
    end

    if type(Azaath.ItemDropsSrcRaw) == "string" then
        for line in Azaath.ItemDropsSrcRaw:gmatch("[^\r\n]+") do
            -- 6º campo: zona (AreaTable) da masmorra/raide (0 = nenhuma); 7º: nome em pt-BR
            local key, name, map, x, y, area, ptName = line:match("^([^\t]+)\t([^\t]+)\t(%d+)\t([%d%.%-]+)\t([%d%.%-]+)\t?(%d*)\t?(.*)$")
            if key then
                area = tonumber(area)
                local dispName = (pt and ptName and ptName ~= "") and ptName or name
                local normName = NormSearch(dispName)
                if pt and ptName and ptName ~= "" and ptName ~= name then
                    normName = normName .. "\0" .. NormSearch(name)
                end
                sources[key] = {
                    key      = key,
                    name     = dispName,
                    normName = normName,
                    map      = tonumber(map) or 0,
                    x        = tonumber(x) or 0,
                    y        = tonumber(y) or 0,
                    area     = (area and area > 0) and area or nil,
                }
            end
        end
        Azaath.ItemDropsSrcRaw = nil
    end

    local function ParseSources(srcStr)
        local list, zoneSeen, craftInfo = {}, {}, nil
        for tok in srcStr:gmatch("[^,]+") do
            local kind, p1, p2 = tok:match("^([a-z])([^:]*):(.*)$")
            if kind == "c" then
                local profStr, skillStr, recStr = p2:match("^(%d+):(%d+):?(%d*)$")
                local profID = tonumber(profStr) or tonumber(p1) or 0
                local skill = tonumber(skillStr) or tonumber(p2) or 0
                local recID = tonumber(recStr)
                local profName = PROF_NAMES[profID] or ("Profissão #" .. profID)
                local recName = recID and recipes[recID] or nil
                craftInfo = {
                    prof       = profName,
                    skill      = skill,
                    recipeID   = recID,
                    recipeName = recName,
                    searchKey  = NormSearch(profName .. (recName and (" " .. recName) or "")),
                }
                list[#list + 1] = {
                    kind     = "craft",
                    name     = profName .. " (Nível " .. skill .. ")",
                    normName = craftInfo.searchKey,
                    sub      = recName and ("Receita: " .. recName) or ("Aprendido no Treinador de " .. profName),
                    map      = 0, x = 0, y = 0,
                    chance   = 100,
                }
            elseif kind == "r" then
                local key, ch = p2:match("^([^:]+):([%d%.v]+)$")
                if key and key:sub(1, 1) == "q" then
                    local qid = tonumber(key:sub(2)) or 0
                    local qdb = Azaath:GetModule("QuestDB")
                    local q = qdb and qdb.GetQuest and qdb:GetQuest(qid)
                    local qTitle = (q and qdb:GetTitle(q)) or ("Missão #" .. qid)
                    local qMap = q and (q.sMap or q.eMap) or 0
                    local qX = q and (q.sX or q.eX) or 0
                    local qY = q and (q.sY or q.eY) or 0
                    local rName = "[Receita] Missão: " .. qTitle
                    list[#list + 1] = {
                        kind     = "recipe",
                        name     = rName,
                        normName = NormSearch(rName),
                        map      = qMap, x = qX, y = qY,
                        chance   = 100,
                    }
                    if qMap > 0 then zoneSeen[qMap] = true end
                else
                    local s = key and sources[key]
                    if s then
                        list[#list + 1] = {
                            kind     = "recipe",
                            key      = key,
                            name     = "[Receita] " .. s.name,
                            normName = s.normName,
                            map      = s.map,
                            x        = s.x,
                            y        = s.y,
                            area     = s.area,
                            chance   = tonumber(ch) or 0,
                            vendor   = ch == "v" or nil,
                        }
                        if s.map and s.map > 0 then zoneSeen[s.map] = true end
                    end
                end
            elseif kind == "q" then
                local qid = tonumber(p2) or tonumber(p1) or 0
                local qdb = Azaath:GetModule("QuestDB")
                local q = qdb and qdb.GetQuest and qdb:GetQuest(qid)
                local qTitle = (q and qdb:GetTitle(q)) or ("Missão #" .. qid)
                local qMap = q and (q.sMap or q.eMap) or 0
                local qX = q and (q.sX or q.eX) or 0
                local qY = q and (q.sY or q.eY) or 0
                local qName = "Missão: " .. qTitle
                list[#list + 1] = {
                    kind     = "quest",
                    name     = qName,
                    normName = NormSearch(qName),
                    map      = qMap, x = qX, y = qY,
                    chance   = 100,
                }
                if qMap > 0 then zoneSeen[qMap] = true end
            elseif kind == "i" then
                local zoneID = tonumber(p1) or 0
                local ch = tonumber(p2) or 0
                list[#list + 1] = {
                    kind   = "instance",
                    name   = "Masmorra / Raide",
                    map    = zoneID, x = 0, y = 0,
                    chance = ch,
                }
                if zoneID > 0 then zoneSeen[zoneID] = true end
            else
                local key, ch = tok:match("^([^:]+):([%d%.v]+)$")
                local s = key and sources[key]
                if s then
                    list[#list + 1] = {
                        kind     = (s.map and s.map > 0) and "world" or "instance",
                        key      = key,
                        name     = s.name,
                        normName = s.normName,
                        map      = s.map,
                        x        = s.x,
                        y        = s.y,
                        area     = s.area,
                        chance   = tonumber(ch) or 0,
                        vendor   = ch == "v" or nil, -- vende o item (sem chance de drop)
                    }
                    if s.map and s.map > 0 then zoneSeen[s.map] = true end
                end
            end
        end
        return list, zoneSeen, craftInfo
    end

    if type(Azaath.ItemDropsRaw) == "string" then
        for line in Azaath.ItemDropsRaw:gmatch("[^\r\n]+") do
            local id, q, req, ilvl, cid, scid, inv, mask, name, stats, srcStr, altName =
                line:match("^(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t(%d+)\t([^\t]+)\t([^\t]*)\t([^\t]*)\t?(.*)$")
            if id then
                id = tonumber(id)
                local list, zoneSeen, craftInfo = ParseSources(srcStr)
                if #list > 0 then
                    name = DecodeURI(name)
                    -- 12º campo = nome original (inglês); 13º = etiqueta de consumível ("food:str", "pot:hp"...)
                    local tag
                    altName, tag = (altName or ""):match("^([^\t]*)\t?(.*)$")
                    altName = (altName and altName ~= "") and DecodeURI(altName) or ""
                    -- name = pt-BR (ou o original, se não houver tradução); altName = original em inglês
                    local ptMissing = altName == ""
                    if not pt and altName ~= "" then name, altName = altName, name end
                    table.sort(list, function(a, b) return (a.chance or 0) > (b.chance or 0) end)
                    local normName = NormSearch(name)
                    local sk = (altName ~= "") and (normName .. "\0" .. NormSearch(altName)) or normName
                    local entry = {
                        id         = id,
                        quality    = tonumber(q) or 1,
                        reqLevel   = tonumber(req) or 0,
                        iLvl       = tonumber(ilvl) or 0,
                        classID    = tonumber(cid) or 0,
                        subclassID = tonumber(scid) or 0,
                        invType    = tonumber(inv) or 0,
                        kindMask   = tonumber(mask) or 1,
                        name       = name,
                        altName    = (altName ~= "") and altName or nil,
                        ptMissing  = ptMissing or nil,
                        tag        = (tag and tag ~= "") and tag or nil,
                        sortName   = normName,
                        searchKey  = sk,
                        stats      = stats ~= "" and stats or nil,
                        craft      = craftInfo,
                        list       = list,
                    }
                    items[id] = entry
                    sortedItems[#sortedItems + 1] = entry
                    for m in pairs(zoneSeen) do
                        local zl = byZone[m]
                        if not zl then zl = {}; byZone[m] = zl end
                        zl[#zl + 1] = entry
                    end
                end
            end
        end
        Azaath.ItemDropsRaw = nil
    end

    local learned = _G.AzaathUIDB and _G.AzaathUIDB.learnedDrops
    if type(learned) == "table" then
        for id, rec in pairs(learned) do
            if type(rec) == "table" and rec.name and rec.src and not items[id] then
                if rec.src.name and not rec.src.normName then rec.src.normName = NormSearch(rec.src.name) end
                local normName = NormSearch(rec.name)
                local entry = {
                    id = id, quality = rec.quality or 1, reqLevel = rec.reqLevel or 0, iLvl = rec.iLvl or 0,
                    classID = rec.classID or 0, subclassID = rec.subclassID or 0, invType = rec.invType or 0, kindMask = 1,
                    name = rec.name, sortName = normName, searchKey = normName, list = { rec.src },
                }
                items[id] = entry
                sortedItems[#sortedItems + 1] = entry
                if rec.src.map and rec.src.map > 0 then
                    local zl = byZone[rec.src.map]
                    if not zl then zl = {}; byZone[rec.src.map] = zl end
                    zl[#zl + 1] = entry
                end
            end
        end
    end

    table.sort(sortedItems, CompareEntries)
    for _, zl in pairs(byZone) do
        table.sort(zl, CompareEntries)
    end
end

function M:GetItem(itemID)
    EnsureParsed()
    return items[itemID]
end

local function MatchArmorFilter(e, armorKey)
    if not armorKey or armorKey == "all" then return true end
    if armorKey == "plate"   then return e.classID == 4 and e.subclassID == 4 end
    if armorKey == "mail"    then return e.classID == 4 and e.subclassID == 3 end
    if armorKey == "leather" then return e.classID == 4 and e.subclassID == 2 end
    if armorKey == "cloth"   then return e.classID == 4 and e.subclassID == 1 and e.invType ~= 16 end
    if armorKey == "weapon"  then return e.classID == 2 end
    if armorKey == "acc"     then return (e.classID == 4 and (e.subclassID == 0 or e.subclassID == 6)) or e.invType == 16 end
    if armorKey == "mats" then
        return e.classID == 7 or e.classID == 0 or e.classID == 5 or e.classID == 9 or e.classID == 1 or e.classID == 3 or e.classID == 15
    end
    if armorKey == "quest" then return e.classID == 12 end
    return true
end

local SLOT_INV = {
    head     = 1,
    shoulder = 3,
    waist    = 6,
    legs     = 7,
    feet     = 8,
    wrist    = 9,
    hand     = 10,
    neck     = 2,
    finger   = 11,
    trinket  = 12,
    cloak    = 16,
    offhand  = 23,
}

local function MatchSlotFilter(e, slotKey)
    if not slotKey or slotKey == "all" then return true end
    if slotKey == "chest" then return e.invType == 5 or e.invType == 20 end
    if SLOT_INV[slotKey] then return e.invType == SLOT_INV[slotKey] end
    if slotKey == "shield" then return e.invType == 14 or (e.classID == 4 and e.subclassID == 6) end
    if e.classID == 2 then
        if slotKey == "sword1h" then return e.subclassID == 7 end
        if slotKey == "sword2h" then return e.subclassID == 8 end
        if slotKey == "axe"     then return e.subclassID == 0 or e.subclassID == 1 end
        if slotKey == "mace"    then return e.subclassID == 4 or e.subclassID == 5 end
        if slotKey == "dagger"  then return e.subclassID == 15 end
        if slotKey == "staff"   then return e.subclassID == 10 or e.subclassID == 6 end
        if slotKey == "ranged"  then return e.subclassID == 2 or e.subclassID == 3 or e.subclassID == 18 or e.subclassID == 19 or e.subclassID == 16 end
        if slotKey == "fist"    then return e.subclassID == 13 end
    end
    return false
end

local function MatchLevelFilter(e, lvlKey)
    if not lvlKey or lvlKey == "all" then return true end
    local lvl = EffectiveLevel(e)
    if lvlKey == "1-20"  then return lvl >= 1 and lvl <= 20 end
    if lvlKey == "21-40" then return lvl >= 21 and lvl <= 40 end
    if lvlKey == "41-59" then return lvl >= 41 and lvl <= 59 end
    if lvlKey == "60"    then return lvl >= 60 end
    return true
end

local mapNormCache, areaNormCache = {}, {}

local function MapNorm(mapID)
    if not mapID or mapID <= 0 then return "" end
    local v = mapNormCache[mapID]
    if v ~= nil then return v end
    local info = _G.C_Map and _G.C_Map.GetMapInfo and Safe(_G.C_Map.GetMapInfo, mapID)
    v = (info and info.name) and NormSearch(info.name) or ""
    mapNormCache[mapID] = v
    return v
end

local function AreaNorm(areaID)
    if not areaID or areaID <= 0 then return "" end
    local v = areaNormCache[areaID]
    if v ~= nil then return v end
    local name = _G.C_Map and _G.C_Map.GetAreaInfo and Safe(_G.C_Map.GetAreaInfo, areaID)
    v = (type(name) == "string" and name ~= "") and NormSearch(name) or ""
    areaNormCache[areaID] = v
    return v
end

local function MatchQuery(self, entry, q)
    if q == "" then return true end
    if entry.searchKey and entry.searchKey:find(q, 1, true) then return true end
    if entry.ptMissing then
        local dn = self:DisplayName(entry)
        if dn ~= "" and NormSearch(dn):find(q, 1, true) then return true end
    end
    if entry.craft and entry.craft.searchKey and entry.craft.searchKey:find(q, 1, true) then
        return true
    end
    for _, s in ipairs(entry.list or {}) do
        if s.normName and s.normName:find(q, 1, true) then return true end
        if s.map and s.map > 0 and MapNorm(s.map):find(q, 1, true) then return true end
        if s.area and s.area > 0 and AreaNorm(s.area):find(q, 1, true) then return true end
    end
    return false
end

-- Itens que o servidor não possui: persistidos (confirmados pelo cliente) ou só da sessão (timeout)
local sessionMissing = {}

function M:IsMissing(id)
    if sessionMissing[id] then return true end
    if Azaath.MissingItemIDs and Azaath.MissingItemIDs[id] then return true end
    local db = _G.AzaathUIDB
    return db and db.missingItems and db.missingItems[id] and true or false
end

function M:MarkMissing(id, persist)
    if not id or self:IsMissing(id) then return false end
    if persist and _G.AzaathUIDB then
        _G.AzaathUIDB.missingItems = _G.AzaathUIDB.missingItems or {}
        _G.AzaathUIDB.missingItems[id] = true
    else
        sessionMissing[id] = true
    end
    return true
end

-- opts: { mapID, query, armor, slot, origin (0=all,1=world,2=instance,4=craft,8=quest), level, minQuality, limit }
function M:Query(opts)
    EnsureParsed()
    opts = opts or {}
    local q = opts.query and NormSearch(opts.query:match("^%s*(.-)%s*$")) or ""
    local mapID = opts.mapID or 0
    local origin = opts.origin or 0
    local minQ = opts.minQuality or 0
    local limit = opts.limit
    if limit == nil then limit = 240 end
    local sortByLevel = (opts.level and opts.level ~= "all") and true or false
    local pool = (mapID > 0 and q == "") and (byZone[mapID] or {}) or sortedItems
    local out = {}
    local total = 0
    -- opts.cat = chave da árvore (Azaath.ItemCats); opts.counts = tabela que recebe a contagem por ramo
    local Cats = Azaath.ItemCats
    local cat = Cats and opts.cat and opts.cat ~= "all" and opts.cat or nil
    local counts = Cats and opts.counts or nil
    local favs = _G.AzaathUIDB and type(_G.AzaathUIDB.dropFavorites) == "table" and _G.AzaathUIDB.dropFavorites or nil

    for _, entry in ipairs(pool) do
        local ok = not self:IsMissing(entry.id)
        if ok and mapID > 0 and q ~= "" then
            local inZone = false
            for _, s in ipairs(entry.list) do
                if s.map == mapID then inZone = true; break end
            end
            if not inZone then ok = false end
        end
        if ok and not MatchQuery(self, entry, q) then
            ok = false
        end
        if ok and minQ > 0 and (entry.quality or 1) < minQ then ok = false end
        if ok and origin > 0 and band(entry.kindMask or 1, origin) == 0 then ok = false end
        if ok and not MatchArmorFilter(entry, opts.armor) then ok = false end
        if ok and not MatchSlotFilter(entry, opts.slot) then ok = false end
        if ok and not MatchLevelFilter(entry, opts.level) then ok = false end

        -- árvore de categorias: conta o item em cada ramo (antes do filtro de categoria) e filtra
        if ok and (counts or cat) then
            local keys = Cats.Keys(entry)
            if counts then
                for k in pairs(keys) do counts[k] = (counts[k] or 0) + 1 end
                counts.all = (counts.all or 0) + 1
                if favs and favs[entry.id] then counts.fav = (counts.fav or 0) + 1 end
            end
            if cat and not keys[cat] then ok = false end
        end
        -- só os itens salvos
        if ok and opts.favOnly and not (favs and favs[entry.id]) then ok = false end

        if ok then
            total = total + 1
            if sortByLevel or limit <= 0 or #out < limit then
                local best = entry.list[1]
                if mapID > 0 then
                    for _, s in ipairs(entry.list) do
                        if s.map == mapID then best = s; break end
                    end
                end
                out[#out + 1] = { entry = entry, best = best }
            end
        end
    end

    if sortByLevel and #out > 1 then
        table.sort(out, CompareByLevelAsc)
        if limit > 0 then
            for i = #out, limit + 1, -1 do
                out[i] = nil
            end
        end
    end

    return out, total
end

--------------------------------------------------------------------------------
-- Itens salvos ("favoritos") do personagem: AzaathUIDB.dropFavorites[itemID] = hora em que salvou
--------------------------------------------------------------------------------
local function Favs(create)
    local db = _G.AzaathUIDB
    if not db then return nil end
    if create and type(db.dropFavorites) ~= "table" then db.dropFavorites = {} end
    return type(db.dropFavorites) == "table" and db.dropFavorites or nil
end

function M:IsFavorite(id)
    local f = Favs()
    return f and id and f[id] ~= nil or false
end

-- devolve o novo estado (true = salvo)
function M:ToggleFavorite(id)
    local f = Favs(true)
    if not (f and id) then return false end
    if f[id] then f[id] = nil return false end
    f[id] = (_G.time and _G.time()) or true
    return true
end

function M:FavoriteCount()
    local f, n = Favs(), 0
    if f then for _ in pairs(f) do n = n + 1 end end
    return n
end

function M:GetZoneDrops(uiMapID, query)
    return self:Query({ mapID = uiMapID, query = query })
end

-- Auto-aprendizado de drops ao saquear
local lootFrame = CreateFrame("Frame")
lootFrame:SetScript("OnEvent", function()
    if not (_G.GetNumLootItems and _G.GetLootSlotInfo and _G.GetLootSlotLink) then return end
    local srcName = (_G.UnitExists and _G.UnitExists("target") and _G.UnitName("target")) or "Saque"
    local CMap = _G.C_Map
    local mapID = CMap and CMap.GetBestMapForUnit and Safe(CMap.GetBestMapForUnit, "player")
    local pos = mapID and CMap.GetPlayerMapPosition and Safe(CMap.GetPlayerMapPosition, mapID, "player")
    local px, py = pos and pos:GetXY()
    if not (mapID and px and py) then return end

    EnsureParsed()
    local n = Safe(_G.GetNumLootItems) or 0
    for i = 1, n do
        local _, itemName, _, _, lootQ = Safe(_G.GetLootSlotInfo, i)
        local link = Safe(_G.GetLootSlotLink, i)
        local itemID = link and tonumber(link:match("item:(%d+)"))
        if itemID and itemName and not items[itemID] then
            local _, _, iq, ilvl, req, _, _, _, _, _, _, cid, scid = Safe((_G.C_Item and _G.C_Item.GetItemInfo) or _G.GetItemInfo, link or itemID)
            local src = {
                kind     = "world",
                name     = srcName,
                normName = NormSearch(srcName),
                map      = mapID,
                x        = math.floor(px * 1000 + 0.5) / 10,
                y        = math.floor(py * 1000 + 0.5) / 10,
                chance   = 100,
            }
            local normName = NormSearch(itemName)
            local entry = {
                id = itemID, quality = iq or lootQ or 1, reqLevel = req or 0, iLvl = ilvl or 0,
                classID = cid or 0, subclassID = scid or 0, invType = 0, kindMask = 1,
                name = itemName, sortName = normName, searchKey = normName, list = { src },
            }
            items[itemID] = entry
            sortedItems[#sortedItems + 1] = entry
            table.sort(sortedItems, CompareEntries)
            local zl = byZone[mapID]
            if not zl then zl = {}; byZone[mapID] = zl end
            zl[#zl + 1] = entry
            table.sort(zl, CompareEntries)
            if _G.AzaathUIDB then
                _G.AzaathUIDB.learnedDrops = _G.AzaathUIDB.learnedDrops or {}
                _G.AzaathUIDB.learnedDrops[itemID] = {
                    name = itemName, quality = entry.quality, reqLevel = entry.reqLevel, iLvl = entry.iLvl,
                    classID = entry.classID, subclassID = entry.subclassID, src = src,
                }
            end
        end
    end
end)
Azaath.SafeRegister(lootFrame, "LOOT_OPENED")

--------------------------------------------------------------------------------
-- /azscan: pergunta ao cliente quais itens do banco existem no Forever
--------------------------------------------------------------------------------
local scan
local scanFrame = CreateFrame("Frame")

local function ScanSay(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffff9900AZscan|r " .. msg)
end

local function ScanResolve(id, state)
    if not scan or scan.state[id] ~= "pending" then return end
    scan.state[id] = state
    scan.pending = scan.pending - 1
    scan.done = scan.done + 1
    if state == "ok" then scan.alive = true end
end

local function ScanFinish()
    local found, miss, tmo = 0, {}, {}
    for id, st in pairs(scan.state) do
        if st == "ok" then found = found + 1
        elseif st == "miss" then miss[#miss + 1] = id
        elseif st == "timeout" then tmo[#tmo + 1] = id end
    end
    table.sort(miss); table.sort(tmo)
    local db = _G.AzaathUIDB
    if db then
        db.scanReport = {
            date = date and date("%Y-%m-%d %H:%M") or "",
            total = scan.total,
            found = found,
            missingExplicit = table.concat(miss, ","),
            missingTimeout = table.concat(tmo, ","),
        }
        for _, id in ipairs(miss) do M:MarkMissing(id, true) end
        for _, id in ipairs(tmo) do M:MarkMissing(id, true) end
    end
    ScanSay(format("Fim: %d itens | existem: %d | inexistentes (confirmado): %d | sem resposta: %d. Faca /reload para gravar.", scan.total, found, #miss, #tmo))
    scanFrame:SetScript("OnUpdate", nil)
    scan = nil
end

scanFrame:SetScript("OnEvent", function(_, _, id, success)
    if not (scan and id) then return end
    if success == false then ScanResolve(id, "miss") else ScanResolve(id, "ok") end
end)
pcall(scanFrame.RegisterEvent, scanFrame, "GET_ITEM_INFO_RECEIVED")
pcall(scanFrame.RegisterEvent, scanFrame, "ITEM_DATA_LOAD_RESULT")

local function ScanStart()
    EnsureParsed()
    local ids, seen = {}, {}
    for _, e in ipairs(sortedItems) do
        if e.id and not seen[e.id] then seen[e.id] = true; ids[#ids + 1] = e.id end
    end
    scan = { ids = ids, pos = 1, state = {}, sentAt = {}, pending = 0, done = 0, total = #ids, alive = false, clock = 0, shown = 0 }
    ScanSay("Verificando " .. #ids .. " itens... pode levar alguns minutos.")
    scanFrame:SetScript("OnUpdate", function(_, dt)
        scan.clock = scan.clock + dt
        if scan.clock < 0.2 then return end
        scan.clock = 0
        local now = GetTime()
        local sent = 0
        while scan.pos <= #scan.ids and sent < 15 do
            local id = scan.ids[scan.pos]
            scan.pos = scan.pos + 1
            local okI, nm = pcall(GetItemInfo, id)
            scan.state[id] = "pending"
            scan.pending = scan.pending + 1
            if okI and nm then
                ScanResolve(id, "ok")
            else
                scan.sentAt[id] = now
                sent = sent + 1
                if _G.C_Item and _G.C_Item.RequestLoadItemDataByID then pcall(_G.C_Item.RequestLoadItemDataByID, id) end
            end
        end
        for id, t in pairs(scan.sentAt) do
            if scan.state[id] == "pending" and now - t > 20 then
                local okI, nm = pcall(GetItemInfo, id)
                if okI and nm then ScanResolve(id, "ok")
                elseif scan.alive then ScanResolve(id, "timeout") end
            end
            if scan.state[id] ~= "pending" then scan.sentAt[id] = nil end
        end
        if scan.done - scan.shown >= 1000 then
            scan.shown = scan.done
            ScanSay(format("%d / %d", scan.done, scan.total))
        end
        if scan.pos > #scan.ids and scan.pending == 0 then ScanFinish() end
    end)
end

SLASH_AZSCAN1 = "/azscan"
SlashCmdList["AZSCAN"] = function(msg)
    msg = (msg or ""):lower()
    if msg == "reset" then
        if _G.AzaathUIDB then _G.AzaathUIDB.missingItems = nil; _G.AzaathUIDB.scanReport = nil end
        ScanSay("Lista de itens inexistentes apagada. Faca /reload.")
    elseif scan then
        ScanSay(format("Em andamento: %d / %d", scan.done, scan.total))
    else
        ScanStart()
    end
end
