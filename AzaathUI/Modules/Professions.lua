--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Professions.lua
    Aba "Ofícios" da ficha (Tecla K / janelas de profissão): Oficina de Azaath.

    Interface frameless de tela cheia (1920x1080) alinhada às abas de arte
    (Santuário, Grimório, Talentos, Reputação, Perícias):
      * Fundo atmosférico ProfessionsBG (pedestal rúnico de transmutação)
      Layout "Mesa do Artesão" (tools/crafting-concept/mockup.html):
      * Coluna esquerda de medalhões com anel de progresso
        (overlay seguro em UIParent para abrir cada profissão fora de combate,
        sem colocar frames protegidos dentro de AzaathUISheet)
      * Trilhas rápidas (prontas / sobem perícia / falta pouco / favoritas),
        busca e legenda de dificuldade clicável
      * Categorias como baralhos de cartas (cor = chance de subir perícia,
        xN = quantas dá para criar, bolinhas = materiais)
      * Painel direito com abas ALTAR (materiais em círculo ao redor do
        resultado, sub-receitas + "< Voltar") e MOCHILA (bolsas e filtros)
      * Barra de criação segmentada, PARAR (/stopcasting seguro) e sons por
        tipo (Media/Sounds/Crafting, gerados por tools/crafting-concept/gen-sounds.js)
      * Unificação transparente de TradeSkill (Ferraria, Alquimia, etc.) e
        Craft (Encantamento), com cache de receitas por personagem
------------------------------------------------------------------------------]]

local ADDON_NAME, Azaath = ...
local M = Azaath:NewModule("Professions")
local API = Azaath.API
local SI  = _G.C_SkillInfo

local _G = _G
local ipairs, pairs, format, floor, ceil, min, max, tostring, type, pcall, wipe =
    ipairs, pairs, string.format, math.floor, math.ceil, math.min, math.max, tostring, type, pcall, wipe
local tinsert, tsort, tremove = table.insert, table.sort, table.remove

local ART_W, ART_H = 1920, 1080
local MEDIA_ROOT   = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local SHEET_MEDIA  = MEDIA_ROOT .. "Sheet\\"
local INV_MEDIA    = MEDIA_ROOT .. "Inventory\\"

-- Paleta Azaath / Oficina
local COL_GOLD     = { 0.92, 0.78, 0.44 }
local COL_CREAM    = { 0.94, 0.90, 0.82 }
local COL_MUTED    = { 0.62, 0.66, 0.72 }
local COL_DIM      = { 0.44, 0.48, 0.54 }
local COL_AZAATH    = { 0.28, 0.88, 0.84 }
local COL_OK       = { 0.34, 0.86, 0.62 }
local COL_BAD      = { 0.92, 0.36, 0.34 }
local COL_WARN     = { 0.94, 0.66, 0.28 }

local DIFF_COLORS = {
    optimal = { 1.00, 0.50, 0.25 },
    medium  = { 1.00, 0.82, 0.25 },
    easy    = { 0.32, 0.82, 0.40 },
    trivial = { 0.58, 0.60, 0.64 },
}

local DIFF_ORDER = { "optimal", "medium", "easy", "trivial" }

-- Profissões reconhecidas (PT-BR e EN-US + skillLineID e spellID base)
local KNOWN_PROFESSIONS = {
    -- Primárias
    { id = "alchemy",        skillLineID = 171, spellID = 2259, primary = true,  verb = "TRANSMUTAR", keys = { "alquimia", "alchemy" },                   spells = { "Alquimia", "Alchemy" },                 icon = "Interface\\Icons\\Trade_Alchemy" },
    { id = "blacksmithing",  skillLineID = 164, spellID = 2018, primary = true,  verb = "FORJAR",     keys = { "ferraria", "blacksmithing" },               spells = { "Ferraria", "Blacksmithing" },         icon = "Interface\\Icons\\Trade_BlackSmithing" },
    { id = "enchanting",     skillLineID = 333, spellID = 7411, primary = true,  verb = "ENCANTAR",   keys = { "encantamento", "enchanting" },            spells = { "Encantamento", "Enchanting" },      icon = "Interface\\Icons\\Trade_Engraving" },
    { id = "engineering",    skillLineID = 202, spellID = 4036, primary = true,  verb = "MONTAR",     keys = { "engenharia", "engineering" },             spells = { "Engenharia", "Engineering" },       icon = "Interface\\Icons\\Trade_Engineering" },
    { id = "leatherworking", skillLineID = 165, spellID = 2108, primary = true,  verb = "COSTURAR",   keys = { "couraria", "leatherworking" },            spells = { "Couraria", "Leatherworking" },      icon = "Interface\\Icons\\Trade_LeatherWorking" },
    { id = "tailoring",      skillLineID = 197, spellID = 3908, primary = true,  verb = "TECER",      keys = { "alfaiataria", "tailoring" },              spells = { "Alfaiataria", "Tailoring" },        icon = "Interface\\Icons\\Trade_Tailoring" },
    { id = "mining",         skillLineID = 186, spellID = 2656, primary = true,  verb = "FUNDIR",     keys = { "mineração", "mineracao", "mining" },      spells = { "Fundição", "Fundir", "Smelting" },  icon = "Interface\\Icons\\Trade_Mining" },
    { id = "herbalism",      skillLineID = 182, spellID = nil,  primary = true,  verb = "COLETAR",    keys = { "herborismo", "herbalism" },               spells = {},                                      icon = "Interface\\Icons\\Trade_Herbalism" },
    { id = "skinning",       skillLineID = 393, spellID = nil,  primary = true,  verb = "ESFOLAR",    keys = { "esfolamento", "skinning" },               spells = {},                                      icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    -- Secundárias
    { id = "cooking",        skillLineID = 185, spellID = 2550, primary = false, verb = "COZINHAR",   keys = { "culinária", "culinaria", "cooking" },     spells = { "Culinária", "Cooking" },          icon = "Interface\\Icons\\INV_Misc_Food_15" },
    { id = "firstaid",       skillLineID = 129, spellID = 3273, primary = false, verb = "PREPARAR",   keys = { "primeiros socorros", "first aid" },       spells = { "Primeiros Socorros", "First Aid" }, icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
    { id = "fishing",        skillLineID = 356, spellID = nil,  primary = false, verb = "PESCAR",     keys = { "pesca", "fishing" },                      spells = {},                                      icon = "Interface\\Icons\\Trade_Fishing" },
    { id = "poisons",        skillLineID = 40,  spellID = 2842, primary = false, verb = "PREPARAR",   keys = { "venenos", "poisons" },                    spells = { "Venenos", "Poisons" },              icon = "Interface\\Icons\\Trade_BrewPoison" },
}

local state = {
    activeProf     = nil,      -- nome da profissão exibida
    activeMode     = nil,      -- "tradeskill" | "craft" | "cached" | nil
    selectedRecipe = nil,      -- nome da receita selecionada
    searchText     = "",
    onlyCraftable  = false,
    onlyFavorites  = false,
    diffFilter     = { optimal = true, medium = true, easy = true, trivial = true },
    collapsed      = {},       -- [headerName] = true
    history        = {},       -- pilha para navegação de reagentes fabricáveis
    craftQty       = 1,
    professions    = {},       -- lista descoberta do personagem
    liveRecipes    = {},       -- receitas ao vivo da janela aberta
    liveByName     = {},       -- lookup rápido por nome
}

local ui = {}
local toggleButton, bindOwner, lastBindingSignature
local events = CreateFrame("Frame")

--------------------------------------------------------------------------------
-- Utilitários
--------------------------------------------------------------------------------
local function CharKey()
    local name = UnitName("player") or "Jogador"
    local realm = GetRealmName() or "Reino"
    return name .. "-" .. realm
end

local function Lower(s)
    return s and string.lower(tostring(s)) or ""
end

local function MatchProfDef(skillName)
    local low = Lower(skillName)
    for _, def in ipairs(KNOWN_PROFESSIONS) do
        for _, k in ipairs(def.keys) do
            if low == k or low:find(k, 1, true) then
                return def
            end
        end
    end
    return nil
end

local function FindSpellInBook(spellNames)
    if not spellNames or #spellNames == 0 then return nil, nil end
    local numTabs = API and API.SpellTabCount and API.SpellTabCount() or (GetNumSpellTabs and GetNumSpellTabs() or 0)
    local total = 0
    for t = 1, numTabs do
        local _, offset, numSlots
        if API and API.SpellTabInfo then
            _, offset, numSlots = API.SpellTabInfo(t)
        elseif GetSpellTabInfo then
            local _, _, o, n = GetSpellTabInfo(t)
            offset, numSlots = o, n
        end
        total = max(total, (offset or 0) + (numSlots or 0))
    end
    for i = 1, total do
        local sName = API and API.SpellName and API.SpellName(i, "spell")
            or (GetSpellBookItemName and GetSpellBookItemName(i, BOOKTYPE_SPELL or "spell"))
        if sName then
            local low = Lower(sName)
            for _, target in ipairs(spellNames) do
                if low == Lower(target) then
                    local tex = API and API.SpellTexture and API.SpellTexture(i, "spell")
                        or (GetSpellTexture and GetSpellTexture(i, BOOKTYPE_SPELL or "spell"))
                    return sName, tex
                end
            end
        end
    end
    return nil, nil
end

local function GetCacheDB()
    if not (M.db and M.db.cache) then return nil end
    local ck = CharKey()
    M.db.cache[ck] = M.db.cache[ck] or {}
    return M.db.cache[ck]
end

local function IsFavorite(recipeName)
    return M.db and M.db.favorites and M.db.favorites[recipeName] == true
end

local function ToggleFavorite(recipeName)
    if not (M.db and M.db.favorites and recipeName) then return end
    if M.db.favorites[recipeName] then
        M.db.favorites[recipeName] = nil
    else
        M.db.favorites[recipeName] = true
    end
end

local function SafeGetItemInfo(item)
    if not item then return nil end
    local fn = (API and API.GetItemInfo) or (_G.C_Item and _G.C_Item.GetItemInfo) or _G.GetItemInfo
    if fn then
        local ok, a, b, c, d, e, f, g, h, i, j = pcall(fn, item)
        if ok then return a, b, c, d, e, f, g, h, i, j end
    end
    return nil
end

local function SafeGetItemIcon(item)
    if not item then return nil end
    if _G.C_Item and _G.C_Item.GetItemIconByID then
        local ok, tex = pcall(_G.C_Item.GetItemIconByID, item)
        if ok and tex then return tex end
    end
    local fn = (API and API.GetItemInfoInstant) or (_G.C_Item and _G.C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    if fn then
        local ok, _, _, _, _, tex = pcall(fn, item)
        if ok and tex then return tex end
    end
    return nil
end

local function SafeGetItemCount(item)
    if not item then return 0 end
    local fn = (_G.C_Item and _G.C_Item.GetItemCount) or _G.GetItemCount
    if fn then
        local ok, c = pcall(fn, item)
        if ok and type(c) == "number" then return c end
    end
    return 0
end

local function GetItemQualityColorSafe(link)
    if not link then return COL_CREAM[1], COL_CREAM[2], COL_CREAM[3] end
    local _, _, quality = SafeGetItemInfo(link)
    if quality and ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality] then
        local c = ITEM_QUALITY_COLORS[quality]
        return c.r, c.g, c.b
    end
    return COL_CREAM[1], COL_CREAM[2], COL_CREAM[3]
end

local function SuppressBlizzFrame(f)
    if not f then return end
    -- Apenas SetAlpha(0) para nunca causar ADDON_ACTION_BLOCKED em frames protegidos (ProfessionsFrame)
    pcall(f.SetAlpha, f, 0)
end

--------------------------------------------------------------------------------
-- Descoberta de Profissões do Personagem
--------------------------------------------------------------------------------
local function SkillCount()
    if SI and SI.GetNumSkillLines then return SI.GetNumSkillLines() or 0 end
    return GetNumSkillLines and GetNumSkillLines() or 0
end

local function SkillInfo(i)
    if SI and SI.GetSkillLineInfo then
        local d = SI.GetSkillLineInfo(i)
        if not d then return nil end
        return d.name, d.isHeader, d.isCollapsed, d.rank or 0, d.modifier or 0, d.maxRank or 0
    end
    if GetSkillLineInfo then
        local name, isHeader, isExpanded, rank, _, modifier, maxRank = GetSkillLineInfo(i)
        return name, isHeader, (not isExpanded), rank or 0, modifier or 0, maxRank or 0
    end
    return nil
end

local function ScanPlayerProfessions()
    wipe(state.professions)
    -- Expande cabeçalhos recolhidos para ler todas as profissões
    for i = 1, SkillCount() do
        local _, isHeader, collapsed = SkillInfo(i)
        if isHeader and collapsed then
            if SI and SI.ExpandSkillHeader then pcall(SI.ExpandSkillHeader, 0)
            elseif ExpandSkillHeader then pcall(ExpandSkillHeader, 0) end
            break
        end
    end

    local seen = {}
    local n = SkillCount()
    for i = 1, n do
        local name, isHeader, _, rank, modifier, maxRank = SkillInfo(i)
        if name and not isHeader then
            local def = MatchProfDef(name)
            if def and not seen[def.id] then
                seen[def.id] = true
                -- grimório varrido uma vez por profissão (subir perícia não muda o feitiço)
                state.spellCache = state.spellCache or {}
                local sc = state.spellCache[def.id]
                if not sc then
                    local n, tx = FindSpellInBook(def.spells)
                    sc = { name = n, tex = tx }
                    if n then state.spellCache[def.id] = sc end
                end
                local spellName, spellIcon = sc.name, sc.tex
                if not spellName and def.spellID and _G.C_Spell and _G.C_Spell.GetSpellName then
                    local ok, spName = pcall(_G.C_Spell.GetSpellName, def.spellID)
                    if ok and spName and spName ~= "" then spellName = spName end
                end
                if not spellName and def.spells and #def.spells > 0 then
                    spellName = def.spells[1]
                end
                tinsert(state.professions, {
                    id          = def.id,
                    skillLineID = def.skillLineID,
                    spellID     = def.spellID,
                    name        = name,
                    primary     = def.primary,
                    verb        = def.verb,
                    rank        = (rank or 0) + (modifier or 0),
                    maxRank     = maxRank or 0,
                    spellName   = spellName,
                    icon        = spellIcon or def.icon,
                    hasWindow   = (spellName ~= nil) or (def.spellID ~= nil),
                })
            end
        end
    end
    tsort(state.professions, function(a, b)
        if a.primary ~= b.primary then return a.primary end
        return a.name < b.name
    end)
end

--------------------------------------------------------------------------------
-- Leitura Unificada: TradeSkill & Craft
--------------------------------------------------------------------------------
local function SaveToCache(profName, rank, maxRank, mode, recipes)
    local cdb = GetCacheDB()
    if not (cdb and profName and profName ~= "" and profName ~= "UNKNOWN") then return end
    local snap = {
        rank = rank,
        maxRank = maxRank,
        mode = mode,
        updatedAt = time and time() or 0,
        recipes = {},
    }
    for _, r in ipairs(recipes) do
        local reagentsCopy = {}
        for _, rg in ipairs(r.reagents) do
            tinsert(reagentsCopy, {
                name = rg.name,
                texture = rg.texture,
                count = rg.count,
                link = rg.link,
            })
        end
        tinsert(snap.recipes, {
            name = r.name,
            header = r.header,
            diff = r.diff,
            icon = r.icon,
            link = r.link,
            recipeLink = r.recipeLink,
            minMade = r.minMade,
            maxMade = r.maxMade,
            tools = r.tools,
            desc = r.desc,
            reagents = reagentsCopy,
        })
    end
    cdb[profName] = snap
end

local function ScanTradeSkillModern()
    local TS = _G.C_TradeSkillUI
    if not (TS and TS.GetRecipeInfo) then return false end

    local info = (TS.GetChildProfessionInfo and TS.GetChildProfessionInfo())
              or (TS.GetBaseProfessionInfo and TS.GetBaseProfessionInfo())
    local profName = info and (info.professionName or info.parentProfessionName)
    local rank = (info and info.skillLevel) or 0
    local maxRank = (info and info.maxSkillLevel) or 0

    if (not profName or profName == "" or profName == "UNKNOWN") and TS.GetTradeSkillLine then
        local _, tsName, tsRank, tsMax = TS.GetTradeSkillLine()
        if tsName and tsName ~= "" and tsName ~= "UNKNOWN" then
            profName, rank, maxRank = tsName, tsRank or 0, tsMax or 0
        end
    end
    if not profName or profName == "" or profName == "UNKNOWN" then
        profName = state.activeProf
    end
    if not profName or profName == "" then return false end

    local ids = (TS.GetAllRecipeIDs and TS.GetAllRecipeIDs())
             or (TS.GetFilteredRecipeIDs and TS.GetFilteredRecipeIDs())
    if (not ids or #ids == 0) and TS.GetFilteredRecipeIDs then
        ids = TS.GetFilteredRecipeIDs()
    end
    if not ids or #ids == 0 then return false end

    wipe(state.liveRecipes)
    wipe(state.liveByName)

    local catCache = {}
    for _, recipeID in ipairs(ids) do
        local okR, rInfo = pcall(TS.GetRecipeInfo, recipeID)
        if okR and rInfo and rInfo.learned ~= false and not rInfo.isDummyRecipe and rInfo.type ~= "header" then
            local catName = "Geral"
            if rInfo.categoryID then
                if catCache[rInfo.categoryID] then
                    catName = catCache[rInfo.categoryID]
                elseif TS.GetCategoryInfo then
                    local okC, cInfo = pcall(TS.GetCategoryInfo, rInfo.categoryID)
                    if okC and cInfo and cInfo.name and cInfo.name ~= "" then
                        catName = cInfo.name
                        catCache[rInfo.categoryID] = catName
                    end
                end
            end

            local diff = "trivial"
            if rInfo.difficulty == "optimal" or rInfo.relativeDifficulty == 0 then diff = "optimal"
            elseif rInfo.difficulty == "medium" or rInfo.relativeDifficulty == 1 then diff = "medium"
            elseif rInfo.difficulty == "easy" or rInfo.relativeDifficulty == 2 then diff = "easy" end

            local reagents = {}
            local minCraftable = 9999
            local okS, schematic = false, nil
            if TS.GetRecipeSchematic then
                okS, schematic = pcall(TS.GetRecipeSchematic, recipeID, false)
            end
            if okS and schematic and schematic.reagentSlotSchematics then
                for _, slot in ipairs(schematic.reagentSlotSchematics) do
                    local rg = slot.required ~= false and slot.reagents and slot.reagents[1]
                    if rg and rg.itemID then
                        local rName, rLink, _, _, _, _, _, _, _, rTex = SafeGetItemInfo(rg.itemID)
                        if not rTex then rTex = SafeGetItemIcon(rg.itemID) end
                        if not rName and _G.C_Item and _G.C_Item.GetItemNameByID then
                            local okN, n = pcall(_G.C_Item.GetItemNameByID, rg.itemID)
                            if okN and n then rName = n end
                        end
                        local need = slot.quantityRequired or 1
                        local have = SafeGetItemCount(rg.itemID)
                        if need > 0 then
                            minCraftable = min(minCraftable, floor(have / need))
                        end
                        tinsert(reagents, {
                            name = rName or ("Item #" .. rg.itemID),
                            texture = rTex,
                            count = need,
                            playerCount = have,
                            link = rLink,
                        })
                    end
                end
            elseif TS.GetRecipeNumReagents and TS.GetRecipeReagentInfo then
                local okN, numR = pcall(TS.GetRecipeNumReagents, recipeID)
                for r = 1, (okN and numR or 0) do
                    local okI, rName, rTex, rCount, pCount = pcall(TS.GetRecipeReagentInfo, recipeID, r)
                    if okI then
                        local rLink = TS.GetRecipeReagentItemLink and select(2, pcall(TS.GetRecipeReagentItemLink, recipeID, r))
                        local need = rCount or 1
                        local have = pCount or 0
                        if need > 0 then
                            minCraftable = min(minCraftable, floor(have / need))
                        end
                        tinsert(reagents, {
                            name = rName or "Reagente",
                            texture = rTex,
                            count = need,
                            playerCount = have,
                            link = rLink,
                        })
                    end
                end
            end
            if #reagents == 0 then minCraftable = 1 end

            local link = TS.GetRecipeItemLink and select(2, pcall(TS.GetRecipeItemLink, recipeID))
            local recLink = TS.GetRecipeLink and select(2, pcall(TS.GetRecipeLink, recipeID))
            local minMade = (schematic and schematic.quantityMin) or 1
            local maxMade = (schematic and schematic.quantityMax) or minMade
            local numAvail = rInfo.numAvailable
            if numAvail == nil then numAvail = minCraftable end

            local rec = {
                index      = recipeID,
                recipeID   = recipeID,
                mode       = "modern",
                name       = rInfo.name or ("Receita #" .. recipeID),
                header     = catName,
                diff       = diff,
                numAvail   = numAvail,
                icon       = rInfo.icon or (schematic and schematic.icon) or SafeGetItemIcon(link),
                link       = link,
                recipeLink = recLink,
                minMade    = minMade,
                maxMade    = maxMade,
                tools      = nil,
                reagents   = reagents,
            }
            tinsert(state.liveRecipes, rec)
            state.liveByName[rec.name] = rec
        end
    end

    if #state.liveRecipes > 0 then
        state.activeProf = profName
        state.activeMode = "modern"
        SaveToCache(profName, rank, maxRank, "modern", state.liveRecipes)
        return true
    end
    return false
end

local function ScanTradeSkill()
    if ScanTradeSkillModern() then
        return true
    end
    if not (GetNumTradeSkills and GetTradeSkillInfo) then return false end
    local total = GetNumTradeSkills() or 0
    if total <= 0 then return false end

    local profName, rank, maxRank
    if GetTradeSkillLine then
        profName, rank, maxRank = GetTradeSkillLine()
    end
    if not profName or profName == "" or profName == "UNKNOWN" then
        profName = state.activeProf or "Ofício"
    end

    -- Expande cabeçalhos para enxergar todas as receitas no índice
    local total = GetNumTradeSkills() or 0
    for i = total, 1, -1 do
        local _, sType, _, isExpanded = GetTradeSkillInfo(i)
        if sType == "header" and not isExpanded and ExpandTradeSkillSubClass then
            ExpandTradeSkillSubClass(i)
        end
    end

    wipe(state.liveRecipes)
    wipe(state.liveByName)

    total = GetNumTradeSkills() or 0
    local curHeader = "Geral"
    for i = 1, total do
        local name, sType, numAvail = GetTradeSkillInfo(i)
        if sType == "header" then
            curHeader = name or "Geral"
        elseif name then
            local numR = GetTradeSkillNumReagents and GetTradeSkillNumReagents(i) or 0
            local reagents = {}
            for r = 1, numR do
                local rName, rTex, rCount, pCount = GetTradeSkillReagentInfo(i, r)
                local rLink = GetTradeSkillReagentItemLink and GetTradeSkillReagentItemLink(i, r)
                tinsert(reagents, {
                    name = rName or "Reagente",
                    texture = rTex,
                    count = rCount or 1,
                    playerCount = pCount or 0,
                    link = rLink,
                })
            end
            local minMade, maxMade = 1, 1
            if GetTradeSkillNumMade then
                minMade, maxMade = GetTradeSkillNumMade(i)
            end
            local tools = GetTradeSkillTools and GetTradeSkillTools(i)
            local rec = {
                index      = i,
                mode       = "tradeskill",
                name       = name,
                header     = curHeader,
                diff       = sType or "trivial",
                numAvail   = numAvail or 0,
                icon       = GetTradeSkillIcon and GetTradeSkillIcon(i),
                link       = GetTradeSkillItemLink and GetTradeSkillItemLink(i),
                recipeLink = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i),
                minMade    = minMade or 1,
                maxMade    = maxMade or 1,
                tools      = tools,
                cooldown   = GetTradeSkillCooldown and GetTradeSkillCooldown(i),
                reagents   = reagents,
            }
            tinsert(state.liveRecipes, rec)
            state.liveByName[name] = rec
        end
    end

    state.activeProf = profName
    state.activeMode = "tradeskill"
    SaveToCache(profName, rank or 0, maxRank or 0, "tradeskill", state.liveRecipes)
end

local function ScanCraft()
    if not GetCraftDisplaySkillLine then return end
    local profName, rank, maxRank = GetCraftDisplaySkillLine()
    if not profName or profName == "" or profName == "UNKNOWN" then return end

    wipe(state.liveRecipes)
    wipe(state.liveByName)

    local total = GetNumCrafts() or 0
    local curHeader = "Encantamentos"
    for i = 1, total do
        local name, subSpell, cType, numAvail = GetCraftInfo(i)
        if cType == "header" then
            curHeader = name or "Encantamentos"
        elseif name then
            local displayName = (subSpell and subSpell ~= "") and (name .. " (" .. subSpell .. ")") or name
            local numR = GetCraftNumReagents and GetCraftNumReagents(i) or 0
            local reagents = {}
            for r = 1, numR do
                local rName, rTex, rCount, pCount = GetCraftReagentInfo(i, r)
                local rLink = GetCraftReagentItemLink and GetCraftReagentItemLink(i, r)
                tinsert(reagents, {
                    name = rName or "Reagente",
                    texture = rTex,
                    count = rCount or 1,
                    playerCount = pCount or 0,
                    link = rLink,
                })
            end
            local rec = {
                index      = i,
                mode       = "craft",
                name       = displayName,
                header     = curHeader,
                diff       = cType or "trivial",
                numAvail   = numAvail or 0,
                icon       = GetCraftIcon and GetCraftIcon(i),
                link       = GetCraftItemLink and GetCraftItemLink(i),
                recipeLink = nil,
                minMade    = 1,
                maxMade    = 1,
                tools      = GetCraftSpellFocus and GetCraftSpellFocus(i),
                desc       = GetCraftDescription and GetCraftDescription(i),
                reagents   = reagents,
            }
            tinsert(state.liveRecipes, rec)
            state.liveByName[displayName] = rec
        end
    end

    state.activeProf = profName
    state.activeMode = "craft"
    SaveToCache(profName, rank or 0, maxRank or 0, "craft", state.liveRecipes)
end

local function LoadFromCache(profName)
    local cdb = GetCacheDB()
    if not (cdb and profName and cdb[profName]) then return false end
    local snap = cdb[profName]
    wipe(state.liveRecipes)
    wipe(state.liveByName)
    for _, r in ipairs(snap.recipes or {}) do
        local reagents = {}
        local minAvail = 9999
        for _, rg in ipairs(r.reagents or {}) do
            local pCount = 0
            if GetItemCount then
                pCount = GetItemCount(rg.link or rg.name) or 0
            end
            local need = rg.count or 1
            if need > 0 then
                minAvail = min(minAvail, floor(pCount / need))
            end
            tinsert(reagents, {
                name = rg.name,
                texture = rg.texture,
                count = need,
                playerCount = pCount,
                link = rg.link,
            })
        end
        if #reagents == 0 then minAvail = 1 end
        local rec = {
            index      = nil,
            mode       = "cached",
            name       = r.name,
            header     = r.header or "Geral",
            diff       = r.diff or "trivial",
            numAvail   = minAvail,
            icon       = r.icon,
            link       = r.link,
            recipeLink = r.recipeLink,
            minMade    = r.minMade or 1,
            maxMade    = r.maxMade or 1,
            tools      = r.tools,
            desc       = r.desc,
            reagents   = reagents,
        }
        tinsert(state.liveRecipes, rec)
        state.liveByName[r.name] = rec
    end
    state.activeProf = profName
    state.activeMode = "cached"
    return true
end

--------------------------------------------------------------------------------
-- Mesa do Artesão (layout de tools/crafting-concept/mockup.html)
--   * coluna de medalhões das profissões (anel de progresso)
--   * trilhas rápidas + busca + legenda de dificuldade
--   * categorias como baralhos de cartas (fluxo em linhas, rolagem)
--   * painel direito com abas ALTAR (materiais orbitando o resultado) e
--     MOCHILA (bolsas, filtros, materiais da receita destacados)
--   * barra de criação com um segmento por unidade, PARAR e sons por tipo
--------------------------------------------------------------------------------
local W_MAIN, X_MAIN = 1085, 180
local X_ALTAR, W_ALTAR = 1300, 585
local CARD_W, CARD_H, CARD_GAP = 260, 250, 14
local TILE_W, TILE_H, TILE_GAP = 160, 118, 10
local DIFF_RANK = { optimal = 1, medium = 2, easy = 3, trivial = 4 }

-- @@CRAFT ATLAS (gerado por tools/professions-ui-concept/gen.js)@@
-- x, y, w, h em px do atlas 1024; pad = brilho fora da moldura; m = margens do 9-slice (l, t, r, b)
local CRAFT_ATLAS = {
    CardN = { file = "CraftFrames", x = 290, y = 1, w = 286, h = 366, pad = 10, ow = 266, oh = 346, m = { 40, 40, 40, 40 } },
    CardA = { file = "CraftFrames", x = 1, y = 1, w = 287, h = 367, pad = 10, ow = 267, oh = 347, m = { 40, 40, 40, 40 } },
    CardAFlare = { file = "CraftFrames", x = 893, y = 1, w = 123, h = 101, add = true, cy = 40 },
    WideN = { file = "CraftFrames", x = 578, y = 1, w = 312, h = 121, pad = 10, ow = 292, oh = 101, m = { 30, 26, 30, 26 } },
    WideA = { file = "CraftFrames", x = 578, y = 124, w = 313, h = 121, pad = 10, ow = 293, oh = 101, m = { 30, 26, 30, 26 } },
    WideAFlare = { file = "CraftFrames", x = 1, y = 370, w = 115, h = 83, add = true, cy = 39 },
    Search = { file = "CraftFrames", x = 533, y = 469, w = 432, h = 87, pad = 6, ow = 420, oh = 75, m = { 38, 0, 38, 0 } },
    PillN = { file = "CraftFrames", x = 187, y = 470, w = 180, h = 54, pad = 5, ow = 170, oh = 44, m = { 22, 0, 22, 0 } },
    PillA = { file = "CraftFrames", x = 1, y = 455, w = 184, h = 60, pad = 7, ow = 170, oh = 46, m = { 24, 0, 24, 0 } },
    BtnGold = { file = "CraftFrames", x = 578, y = 247, w = 301, h = 118, pad = 10, ow = 281, oh = 98, m = { 56, 0, 56, 0 } },
    BtnDark = { file = "CraftFrames", x = 578, y = 367, w = 240, h = 100, pad = 4, ow = 232, oh = 92, m = { 24, 24, 24, 24 } },
    BtnRed = { file = "CraftFrames", x = 290, y = 369, w = 241, h = 99, pad = 4, ow = 233, oh = 91, m = { 16, 16, 16, 16 } },
    BtnSquare = { file = "CraftFrames", x = 893, y = 104, w = 100, h = 100, pad = 4, ow = 92, oh = 92, m = { 24, 24, 24, 24 } },
    BarEmpty = { file = "CraftFrames", x = 1, y = 526, w = 322, h = 45, pad = 3, ow = 316, oh = 39, m = { 10, 0, 10, 0 } },
    BarFill = { file = "CraftFrames", x = 325, y = 558, w = 322, h = 41, pad = 3, ow = 316, oh = 35, m = { 8, 0, 8, 0 } },
    Diamond = { file = "CraftFrames", x = 995, y = 104, w = 25, h = 26 },
    Runes = { file = "CraftRings", x = 1, y = 1, w = 640, h = 640 },
    RingBronze = { file = "CraftRings", x = 643, y = 1, w = 350, h = 351 },
    RingDark = { file = "CraftRings", x = 643, y = 354, w = 280, h = 279 },
    RingSmall = { file = "CraftRings", x = 643, y = 635, w = 127, h = 130 },
    StarGold = { file = "CraftRings", x = 925, y = 354, w = 95, h = 94 },
    StarGray = { file = "CraftRings", x = 925, y = 633, w = 90, h = 87 },
    GemOptimal = { file = "CraftRings", x = 772, y = 635, w = 57, h = 68 },
    GemMedium = { file = "CraftRings", x = 1, y = 643, w = 58, h = 67 },
    GemEasy = { file = "CraftRings", x = 61, y = 643, w = 57, h = 67 },
    GemTrivial = { file = "CraftRings", x = 831, y = 635, w = 56, h = 68 },
    ArrowL = { file = "CraftRings", x = 925, y = 542, w = 67, h = 89 },
    ArrowR = { file = "CraftRings", x = 925, y = 450, w = 67, h = 90 },
}
-- @@FIM DO CRAFT ATLAS@@
local SND = MEDIA_ROOT .. "Sounds\\Crafting\\"

local LANES = {
    { key = "ready",  title = "PRONTAS PARA CRIAR", desc = "Você tem todos os materiais" },
    { key = "skill",  title = "SOBEM SUA PERÍCIA",  desc = "Receitas laranja e amarelas" },
    { key = "almost", title = "FALTA POUCO",        desc = "Falta só 1 material" },
    { key = "fav",    title = "FAVORITAS",          desc = "Fixadas por você" },
}
local DIFF_LABEL = { optimal = "Sempre sobe", medium = "Provável", easy = "Raro", trivial = "Não sobe" }
local KIND_LABEL = {
    food = "frigideira", armor = "couro e cota", weapon = "bigorna",
    potion = "frasco borbulhando", bandage = "tecido rasgando", generic = "brilho arcano",
}
local KIND_FILE = {
    food = "CraftFood", armor = "CraftArmor", weapon = "CraftWeapon",
    potion = "CraftPotion", bandage = "CraftBandage", generic = "CraftGeneric",
}

state.lane      = nil
state.category  = nil   -- categoria aberta na estante (nil = Todas)
state.shelfOffset = 0
state.panel     = "altar"
state.bagOnly   = nil
state.bagFilter = "all"
state.bagScroll = 0
state.newItems  = {}
state.craft     = { active = false, total = 0, done = 0 }

-- Helpers visuais agrupados numa tabela (economiza locais e upvalues)
local H = {}
H.ACCENTS = { ["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê",
              ["í"] = "Í", ["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ú"] = "Ú", ["ç"] = "Ç" }

function H.Txt(parent, font, size, col, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, "")
    fs:SetShadowOffset(1.5, -1.5)
    fs:SetShadowColor(0, 0, 0, 0.92)
    fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- Peça do atlas da arte (CRAFT_ATLAS, gerado por tools/professions-ui-concept/gen.js)
function H.AtlasTex(tex, key)
    local a = CRAFT_ATLAS[key]
    if not a then return end
    tex:SetTexture(SHEET_MEDIA .. a.file)
    tex:SetTexCoord(a.x / 1024, (a.x + a.w) / 1024, a.y / 1024, (a.y + a.h) / 1024)
    tex:SetBlendMode(a.add and "ADD" or "BLEND")
end

-- Moldura 9-slice da arte (cantos chanfrados fixos, meio esticado) com os
-- ornamentos separados: losango de bronze em cima/embaixo (peças "N") e o
-- clarão turquesa no topo (peças "A"). s = escala px da tela / px da arte.
local SKIN_DIAMONDS = { CardN = true, WideN = true }
H.GEM = { optimal = "GemOptimal", medium = "GemMedium", easy = "GemEasy", trivial = "GemTrivial" }
function H.Skin(f, key, s)
    local sk = { f = f, s = s or 1, t = {} }
    for i = 1, 9 do sk.t[i] = f:CreateTexture(nil, "BACKGROUND", nil, 1) end
    sk.dTop = f:CreateTexture(nil, "BORDER", nil, 2)
    sk.dBot = f:CreateTexture(nil, "BORDER", nil, 2)
    sk.flare = f:CreateTexture(nil, "OVERLAY", nil, 3)
    H.AtlasTex(sk.dTop, "Diamond"); H.AtlasTex(sk.dBot, "Diamond")
    function sk:Apply(k)
        if self.key == k then return end
        self.key = k
        local a = CRAFT_ATLAS[k]
        if not a then return end
        local sc, t, F = self.s, self.t, self.f
        local pad = a.pad * sc
        local ml, mt, mr, mb = a.m[1] + a.pad, a.m[2] + a.pad, a.m[3] + a.pad, a.m[4] + a.pad
        local file = SHEET_MEDIA .. a.file
        local u = { a.x, a.x + ml, a.x + a.w - mr, a.x + a.w }
        local v = { a.y, a.y + mt, a.y + a.h - mb, a.y + a.h }
        for i = 1, 9 do
            local cx, cy = (i - 1) % 3 + 1, floor((i - 1) / 3) + 1
            t[i]:SetTexture(file)
            t[i]:SetTexCoord(u[cx] / 1024, u[cx + 1] / 1024, v[cy] / 1024, v[cy + 1] / 1024)
            t[i]:ClearAllPoints()
        end
        local dl, dt, dr, db = ml * sc, mt * sc, mr * sc, mb * sc
        t[1]:SetPoint("TOPLEFT", F, "TOPLEFT", -pad, pad); t[1]:SetSize(dl, dt)
        t[3]:SetPoint("TOPRIGHT", F, "TOPRIGHT", pad, pad); t[3]:SetSize(dr, dt)
        t[7]:SetPoint("BOTTOMLEFT", F, "BOTTOMLEFT", -pad, -pad); t[7]:SetSize(dl, db)
        t[9]:SetPoint("BOTTOMRIGHT", F, "BOTTOMRIGHT", pad, -pad); t[9]:SetSize(dr, db)
        t[2]:SetPoint("TOPLEFT", t[1], "TOPRIGHT"); t[2]:SetPoint("BOTTOMRIGHT", t[3], "BOTTOMLEFT")
        t[8]:SetPoint("TOPLEFT", t[7], "TOPRIGHT"); t[8]:SetPoint("BOTTOMRIGHT", t[9], "BOTTOMLEFT")
        t[4]:SetPoint("TOPLEFT", t[1], "BOTTOMLEFT"); t[4]:SetPoint("BOTTOMRIGHT", t[7], "TOPRIGHT")
        t[6]:SetPoint("TOPLEFT", t[3], "BOTTOMLEFT"); t[6]:SetPoint("BOTTOMRIGHT", t[9], "TOPRIGHT")
        t[5]:SetPoint("TOPLEFT", t[1], "BOTTOMRIGHT"); t[5]:SetPoint("BOTTOMRIGHT", t[9], "TOPLEFT")

        local dia = SKIN_DIAMONDS[k] and CRAFT_ATLAS.Diamond
        self.dTop:SetShown(dia and true or false)
        self.dBot:SetShown(dia and true or false)
        if dia then
            local ds = max(0.6, sc)
            self.dTop:SetSize(dia.w * ds, dia.h * ds); self.dTop:ClearAllPoints(); self.dTop:SetPoint("CENTER", F, "TOP", 0, 0)
            self.dBot:SetSize(dia.w * ds, dia.h * ds); self.dBot:ClearAllPoints(); self.dBot:SetPoint("CENTER", F, "BOTTOM", 0, 0)
        end
        local fl = CRAFT_ATLAS[k .. "Flare"]
        self.flare:SetShown(fl and true or false)
        if fl then
            H.AtlasTex(self.flare, k .. "Flare")
            local fs = max(0.7, sc)
            self.flare:SetSize(fl.w * fs, fl.h * fs)
            self.flare:ClearAllPoints()
            self.flare:SetPoint("CENTER", F, "TOP", 0, -(fl.h / 2 - fl.cy) * fs)
        end
    end
    function sk:SetAlpha(al) for i = 1, 9 do self.t[i]:SetAlpha(al) end end
    sk:Apply(key)
    return sk
end

-- barra de criação: largura + recorte da textura cheia (sem esticar)
function H.SetFill(frac)
    local a, w = CRAFT_ATLAS.BarFill, ui.progBg:GetWidth() - 4
    frac = max(0, min(1, frac or 0))
    ui.progFill:SetWidth(max(1, w * frac))
    local u0, u1 = a.x + a.pad, a.x + a.w - a.pad
    ui.progFill:SetTexCoord(u0 / 1024, (u0 + (u1 - u0) * max(0.01, frac)) / 1024, (a.y + a.pad) / 1024, (a.y + a.h - a.pad) / 1024)
end

function H.CircleIcon(parent, size, frameSize, ringKey)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(frameSize or size, frameSize or size)
    local icon = holder:CreateTexture(nil, "ARTWORK")
    icon:SetSize(size, size)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    local mask = holder:CreateMaskTexture()
    local ok = pcall(mask.SetTexture, mask, INV_MEDIA .. "RoundMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if not ok then mask:SetTexture(INV_MEDIA .. "RoundMask") end
    mask:SetAllPoints(icon)
    icon:AddMaskTexture(mask)
    local ring = holder:CreateTexture(nil, "OVERLAY")
    if ringKey then H.AtlasTex(ring, ringKey) else ring:SetTexture(SHEET_MEDIA .. "RoundSlotFrame") end
    ring:SetAllPoints(holder)
    holder.icon, holder.ring = icon, ring
    return holder
end

-- Moldura de 1px (4 linhas) recolorível
function H.Border(f, r, g, b, a)
    local t = {}
    for i = 1, 4 do
        local l = f:CreateTexture(nil, "BORDER")
        l:SetColorTexture(r, g, b, a)
        t[i] = l
    end
    t[1]:SetPoint("TOPLEFT"); t[1]:SetPoint("TOPRIGHT"); t[1]:SetHeight(1)
    t[2]:SetPoint("BOTTOMLEFT"); t[2]:SetPoint("BOTTOMRIGHT"); t[2]:SetHeight(1)
    t[3]:SetPoint("TOPLEFT"); t[3]:SetPoint("BOTTOMLEFT"); t[3]:SetWidth(1)
    t[4]:SetPoint("TOPRIGHT"); t[4]:SetPoint("BOTTOMRIGHT"); t[4]:SetWidth(1)
    function t:SetColor(r2, g2, b2, a2)
        for i = 1, 4 do self[i]:SetColorTexture(r2, g2, b2, a2) end
    end
    return t
end

-- Com skinKey, o painel usa a moldura da arte (f:SetSkin troca normal/ativo);
-- bg/border viram camadas invisíveis para o código de estado continuar valendo.
function H.Panel(parent, w, h, skinKey, scale)
    local f = CreateFrame("Button", nil, parent)
    f:SetSize(w, h)
    f.bg = f:CreateTexture(nil, "BACKGROUND")
    f.bg:SetAllPoints()
    f.bg:SetColorTexture(0.05, 0.08, 0.12, 0.80)
    f.border = H.Border(f, 0.85, 0.72, 0.42, 0.30)
    if skinKey then
        f.bg:SetAlpha(0)
        for i = 1, 4 do f.border[i]:SetAlpha(0) end
        f.border.SetColor = function() end
        f.skin = H.Skin(f, skinKey, scale)
        function f:SetSkin(k) self.skin:Apply(k) end
    end
    return f
end

function H.Pill(parent, w, h, text, font, size, col, skinKey, scale)
    local b = H.Panel(parent, w, h, skinKey, scale)
    b.label = H.Txt(b, font, size, col or COL_CREAM, "CENTER")
    b.label:SetPoint("CENTER")
    b.label:SetText(text or "")
    return b
end

function H.Tex(parent, layer, file, w, h)
    local t = parent:CreateTexture(nil, layer or "ARTWORK")
    t:SetTexture(MEDIA_ROOT .. file)
    if w then t:SetSize(w, h or w) end
    return t
end

function H.ItemName(link)
    if not link then return nil end
    local n = SafeGetItemInfo(link)
    return n or link:match("%[(.-)%]")
end

-- Tipo de som a partir da profissão e da classe do item criado
function H.CraftKind(rec)
    local def = MatchProfDef(state.activeProf)
    local id = def and def.id
    if id == "cooking" then return "food" end
    if id == "firstaid" then return "bandage" end
    if id == "alchemy" or id == "poisons" then return "potion" end
    if id == "enchanting" then return "generic" end
    local classID
    local fn = (API and API.GetItemInfoInstant) or (_G.C_Item and _G.C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    if fn and rec and rec.link then
        local ok, _, _, _, _, _, cID = pcall(fn, rec.link)
        if ok then classID = cID end
    end
    if classID == 2 then return "weapon" end
    if classID == 4 then return "armor" end
    if id == "blacksmithing" or id == "mining" then return "weapon" end
    if id == "leatherworking" or id == "tailoring" then return "armor" end
    return "generic"
end

function H.PlaySound(file)
    if not _G.PlaySoundFile then return nil end
    local ok, willPlay, handle = pcall(PlaySoundFile, SND .. file .. ".ogg", "SFX")
    return ok and willPlay and handle or nil
end

function H.StopSound()
    local c = state.craft
    if c.handle and _G.StopSound then pcall(StopSound, c.handle, 300) end
    c.handle = nil
end

function H.SelectedRec()
    return state.selectedRecipe and state.liveByName[state.selectedRecipe]
end

--------------------------------------------------------------------------------
-- Filtros: trilhas, busca e dificuldade
--------------------------------------------------------------------------------
local function MissingTypes(rec)
    local miss = 0
    for _, rg in ipairs(rec.reagents) do
        if (rg.playerCount or 0) < (rg.count or 1) then miss = miss + 1 end
    end
    return miss
end

local function LaneMatch(rec, lane)
    if lane == "ready" then return (rec.numAvail or 0) > 0 end
    if lane == "skill" then return rec.diff == "optimal" or rec.diff == "medium" end
    if lane == "almost" then return (rec.numAvail or 0) <= 0 and MissingTypes(rec) == 1 end
    if lane == "fav" then return IsFavorite(rec.name) end
    return true
end

local function RecipeMatches(rec)
    if state.lane and not LaneMatch(rec, state.lane) then return false end
    if state.diffFilter[rec.diff] == false then return false end
    local q = Lower(state.searchText)
    if q ~= "" then
        if Lower(rec.name):find(q, 1, true) then return true end
        if Lower(rec.header):find(q, 1, true) then return true end
        for _, rg in ipairs(rec.reagents) do
            if Lower(rg.name):find(q, 1, true) then return true end
        end
        return false
    end
    return true
end

local function SortList(list)
    tsort(list, function(a, b)
        local fa, fb = IsFavorite(a.name), IsFavorite(b.name)
        if fa ~= fb then return fa end
        local ra, rb = (a.numAvail or 0) > 0, (b.numAvail or 0) > 0
        if ra ~= rb then return ra end
        local da, db = DIFF_RANK[a.diff] or 9, DIFF_RANK[b.diff] or 9
        if da ~= db then return da < db end
        return (a.index or 0) < (b.index or 0)
    end)
    return list
end

local function BuildGroups()
    local groups, byHeader = {}, {}
    for _, rec in ipairs(state.liveRecipes) do
        if RecipeMatches(rec) then
            local h = rec.header or "Geral"
            if not byHeader[h] then
                byHeader[h] = { title = h, list = {} }
                tinsert(groups, byHeader[h])
            end
            tinsert(byHeader[h].list, rec)
        end
    end
    return groups
end

--------------------------------------------------------------------------------
-- Estante de categorias + cartas grandes (pools criados sob demanda)
--------------------------------------------------------------------------------
local function SelectRecipe(rec, keepHistory)
    if not keepHistory then wipe(state.history) end
    state.selectedRecipe = rec.name
    state.craftQty = 1
    if rec.mode == "tradeskill" and rec.index and SelectTradeSkill then
        pcall(SelectTradeSkill, rec.index)
    elseif rec.mode == "craft" and rec.index and SelectCraft then
        pcall(SelectCraft, rec.index)
    end
    M:RefreshView()
end

local function GetTile(i)
    ui.tiles = ui.tiles or {}
    if ui.tiles[i] then return ui.tiles[i] end
    local F = ui.fonts
    local t = H.Panel(ui.shelf, TILE_W, TILE_H, "CardN", 0.55)
    t.icon = H.CircleIcon(t, 40, 52, "RingSmall")
    t.icon:SetPoint("TOP", 0, -14)
    t.name = H.Txt(t, F.B, 12, COL_CREAM, "CENTER")
    t.name:SetPoint("TOP", t.icon, "BOTTOM", 0, -5)
    t.name:SetWidth(TILE_W - 12)
    t.name:SetWordWrap(true)
    if t.name.SetMaxLines then t.name:SetMaxLines(2) end
    t.count = H.Txt(t, F.CB, 12, COL_GOLD, "RIGHT")
    t.count:SetPoint("TOPRIGHT", -16, -10)
    t.readyBg = t:CreateTexture(nil, "ARTWORK")
    t.readyBg:SetPoint("TOPLEFT", 12, -9)
    t.readyBg:SetSize(56, 17)
    H.AtlasTex(t.readyBg, "PillA")
    t.ready = H.Txt(t, F.CB, 10, { 0.04, 0.08, 0.10 }, "CENTER")
    t.ready:SetShadowOffset(0, 0)
    t.ready:SetPoint("CENTER", t.readyBg, "CENTER", 0, 0)
    t.under = t:CreateTexture(nil, "OVERLAY")
    t.under:SetPoint("BOTTOM", 0, 0)
    t.under:SetSize(TILE_W * 0.6, 3)
    t.under:SetColorTexture(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3], 0)
    t.glow = H.Tex(t, "BACKGROUND", "Glow", TILE_W + 50, TILE_H + 50)
    t.glow:SetDrawLayer("BACKGROUND", -2)
    t.glow:SetPoint("CENTER")
    t.glow:SetVertexColor(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3], 0.16)
    t:SetScript("OnClick", function(self)
        state.category = self.category
        ui.deckScroll:SetVerticalScroll(0)
        M:RefreshView()
    end)
    t:EnableMouseWheel(true)
    t:SetScript("OnMouseWheel", function(_, delta) M:ScrollShelf(-delta) end)
    ui.tiles[i] = t
    return t
end

local function GetCard(i)
    ui.cards = ui.cards or {}
    if ui.cards[i] then return ui.cards[i] end
    local F = ui.fonts
    local c = H.Panel(ui.deckChild, CARD_W, CARD_H, "CardN", 0.85)
    c:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    c.glow = H.Tex(c, "BACKGROUND", "Glow", CARD_W + 70, CARD_H + 70)
    c.glow:SetDrawLayer("BACKGROUND", -2)
    c.glow:SetPoint("CENTER")
    c.glow:SetVertexColor(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3], 0.18)

    c.band = c:CreateTexture(nil, "ARTWORK")
    c.band:SetPoint("TOPLEFT"); c.band:SetPoint("TOPRIGHT"); c.band:SetHeight(3)
    c.band:Hide() -- a moldura da arte já marca a carta; dificuldade vai na gema

    c.icon = H.CircleIcon(c, 52, 70, "RingSmall")
    c.icon:SetPoint("TOPLEFT", 20, -20)

    c.name = H.Txt(c, F.CB, 15, COL_CREAM)
    c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 10, -6)
    c.name:SetWidth(CARD_W - 66 - 12 - 10 - 30)
    c.name:SetWordWrap(true)
    if c.name.SetMaxLines then c.name:SetMaxLines(2) end
    c.gem = c:CreateTexture(nil, "OVERLAY")
    c.gem:SetSize(12, 14)
    c.gem:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -4)
    c.diff = H.Txt(c, F.B, 11, COL_MUTED)
    c.diff:SetPoint("LEFT", c.gem, "RIGHT", 5, 0)

    c.star = c:CreateTexture(nil, "OVERLAY")
    H.AtlasTex(c.star, "StarGold")
    c.star:SetSize(24, 24)
    c.star:SetPoint("TOPRIGHT", -16, -14)

    c.mats = {}
    for m = 1, 4 do
        local row = CreateFrame("Frame", nil, c)
        row:SetSize(CARD_W - 40, 24)
        row:SetPoint("TOPLEFT", c, "TOPLEFT", 20, -100 - (m - 1) * 26)
        row.icon = row:CreateTexture(nil, "ARTWORK")
        row.icon:SetSize(16, 16)
        row.icon:SetPoint("LEFT", 2, 0)
        row.icon:SetTexCoord(0.1, 0.9, 0.1, 0.9)
        row.ring = H.Tex(row, "OVERLAY", "CastRingThin", 22)
        row.ring:SetPoint("CENTER", row.icon, "CENTER")
        row.name = H.Txt(row, F.B, 12, COL_CREAM)
        row.name:SetPoint("LEFT", row.icon, "RIGHT", 10, 0)
        row.name:SetWidth(CARD_W - 40 - 32 - 60)
        row.count = H.Txt(row, F.CB, 12, COL_OK, "RIGHT")
        row.count:SetPoint("RIGHT", 0, 0)
        c.mats[m] = row
    end

    local line = c:CreateTexture(nil, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", 20, 46)
    line:SetPoint("BOTTOMRIGHT", -20, 46)
    line:SetHeight(1)
    line:SetColorTexture(1, 1, 1, 0.08)
    c.footBg = c:CreateTexture(nil, "ARTWORK")
    c.footBg:SetPoint("BOTTOMLEFT", 18, 16)
    c.footBg:SetSize(110, 22)
    H.AtlasTex(c.footBg, "PillA")
    c.foot = H.Txt(c, F.CB, 12, COL_MUTED)
    c.foot:SetPoint("LEFT", c.footBg, "LEFT", 10, 0)
    c.tools = H.Txt(c, F.B, 11, COL_WARN, "RIGHT")
    c.tools:SetPoint("BOTTOMRIGHT", -22, 20)
    c.tools:SetWidth(110)

    c:SetScript("OnClick", function(self, button)
        local rec = self.rec
        if not rec then return end
        if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
            ChatEdit_InsertLink(rec.recipeLink or rec.link or rec.name)
            return
        end
        if button == "RightButton" then
            ToggleFavorite(rec.name)
            M:RefreshView()
            return
        end
        SelectRecipe(rec)
    end)
    c:SetScript("OnEnter", function(self)
        if not self.rec then return end
        self.glow:Show()
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.rec.link then
            pcall(GameTooltip.SetHyperlink, GameTooltip, self.rec.link)
        else
            GameTooltip:AddLine(self.rec.name, 1, 1, 1)
        end
        GameTooltip:AddLine("Clique direito: favoritar", COL_MUTED[1], COL_MUTED[2], COL_MUTED[3])
        GameTooltip:Show()
    end)
    c:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        M:PaintCard(self)
    end)
    ui.cards[i] = c
    return c
end

function M:PaintCard(c)
    local rec = c.rec
    if not rec then return end
    local sel = state.selectedRecipe == rec.name
    c.glow:SetShown(sel)
    if sel then
        c:SetSkin("CardA")
    else
        c:SetSkin("CardN")
    end
    local ready = (rec.numAvail or 0) > 0
    c.icon:SetAlpha((ready or sel) and 1 or 0.55)
    c.name:SetAlpha((ready or sel) and 1 or 0.6)
end

local function FillCard(c, rec)
    c.rec = rec
    local dc = DIFF_COLORS[rec.diff] or DIFF_COLORS.trivial
    c.band:SetColorTexture(dc[1], dc[2], dc[3], 1)
    c.icon.icon:SetTexture(rec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    c.name:SetText(rec.name)
    H.AtlasTex(c.gem, H.GEM[rec.diff] or "GemTrivial")
    c.diff:SetText(DIFF_LABEL[rec.diff] or "Não sobe")
    c.diff:SetTextColor(dc[1], dc[2], dc[3])
    c.star:SetShown(IsFavorite(rec.name))

    local n = #rec.reagents
    for m, row in ipairs(c.mats) do
        local rg = rec.reagents[m]
        if m == 4 and n > 4 then
            row:Show()
            row.icon:Hide(); row.ring:Hide()
            row.name:SetText(format("+%d outros materiais", n - 3))
            row.name:SetTextColor(COL_MUTED[1], COL_MUTED[2], COL_MUTED[3])
            row.count:SetText("")
        elseif rg then
            row:Show()
            row.icon:Show(); row.ring:Show()
            row.icon:SetTexture(rg.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            local have, need = rg.playerCount or 0, rg.count or 1
            local ok = have >= need
            local col = ok and COL_OK or COL_BAD
            row.ring:SetVertexColor(col[1], col[2], col[3], 1)
            row.icon:SetDesaturated(not ok)
            row.name:SetText(rg.name)
            row.name:SetTextColor(COL_CREAM[1], COL_CREAM[2], COL_CREAM[3])
            row.count:SetText(format("%d / %d", have, need))
            row.count:SetTextColor(col[1], col[2], col[3])
        else
            row:Hide()
        end
    end

    local avail = rec.numAvail or 0
    if avail > 0 then
        c.foot:SetText(format("PODE CRIAR x%d", avail))
        c.foot:SetTextColor(0.04, 0.08, 0.10)
        c.foot:SetShadowOffset(0, 0)
        c.footBg:SetWidth(c.foot:GetStringWidth() + 22)
        c.footBg:Show()
    else
        c.foot:SetText("Faltam materiais")
        c.foot:SetTextColor(COL_MUTED[1], COL_MUTED[2], COL_MUTED[3])
        c.foot:SetShadowOffset(1.5, -1.5)
        c.footBg:Hide()
    end
    c.tools:SetText((rec.tools and rec.tools ~= "") and rec.tools or "")
    M:PaintCard(c)
end

function M:ScrollShelf(step)
    state.shelfOffset = (state.shelfOffset or 0) + step
    M:RefreshView()
end

-- Estante (categorias) no topo + grade de cartas da categoria escolhida
local function LayoutDecks()
    if not ui.deckChild then return end
    local groups = BuildGroups()
    local valid = state.category == nil
    for _, g in ipairs(groups) do if g.title == state.category then valid = true end end
    if not valid then state.category = nil end

    -- Estante: "Todas" + categorias, com rolagem lateral por setas/roda
    local entries = { { title = nil, list = {} } }
    for _, g in ipairs(groups) do
        for _, rec in ipairs(g.list) do tinsert(entries[1].list, rec) end
        tinsert(entries, g)
    end
    local visible = ui.shelfSlots
    local maxOff = max(0, #entries - visible)
    state.shelfOffset = max(0, min(state.shelfOffset or 0, maxOff))
    ui.shelfLeft:SetShown(state.shelfOffset > 0)
    ui.shelfRight:SetShown(state.shelfOffset < maxOff)

    local profIcon
    local def = MatchProfDef(state.activeProf)
    for _, p in ipairs(state.professions) do if def and p.id == def.id then profIcon = p.icon end end

    for i = 1, max(visible, #(ui.tiles or {})) do
        local e = entries[i + state.shelfOffset]
        local t = (i <= visible) and GetTile(i) or ui.tiles[i]
        if e and i <= visible then
            t.category = e.title
            t:ClearAllPoints()
            t:SetPoint("TOPLEFT", ui.shelf, "TOPLEFT", (i - 1) * (TILE_W + TILE_GAP), 0)
            t.name:SetText(e.title or "Todas")
            t.icon.icon:SetTexture(e.title and (e.list[1] and e.list[1].icon) or profIcon or "Interface\\Icons\\INV_Misc_Book_09")
            t.count:SetText(tostring(#e.list))
            local ready = 0
            for _, rec in ipairs(e.list) do if (rec.numAvail or 0) > 0 then ready = ready + 1 end end
            t.ready:SetText(ready == 1 and "1 PRONTA" or (ready .. " PRONTAS"))
            t.readyBg:SetWidth(t.ready:GetStringWidth() + 10)
            t.ready:SetShown(ready > 0)
            t.readyBg:SetShown(ready > 0)
            local on = state.category == e.title
            t.under:SetShown(on)
            t.glow:SetShown(on)
            if on then
                t:SetSkin("CardA")
            else
                t:SetSkin("CardN")
            end
            t:Show()
        elseif t then
            t:Hide()
        end
    end

    -- Cabeçalho da categoria
    local list
    if state.category then
        for _, g in ipairs(groups) do if g.title == state.category then list = g.list end end
    end
    list = SortList(list or entries[1].list)
    ui.catTitle:SetText(state.category or "Todas as receitas")
    ui.catSub:SetText(format("%d %s  ·  favoritas e prontas primeiro", #list, #list == 1 and "receita" or "receitas"))

    -- Cartas
    local cols = 4
    for k, rec in ipairs(list) do
        local c = GetCard(k)
        local col, row = (k - 1) % cols, floor((k - 1) / cols)
        c:ClearAllPoints()
        c:SetPoint("TOPLEFT", ui.deckChild, "TOPLEFT", col * (CARD_W + CARD_GAP), -row * (CARD_H + CARD_GAP))
        FillCard(c, rec)
        c:Show()
    end
    for i = #list + 1, #(ui.cards or {}) do ui.cards[i]:Hide(); ui.cards[i].rec = nil end

    local rows = ceil(#list / cols)
    local total = rows * (CARD_H + CARD_GAP)
    ui.deckChild:SetHeight(max(10, total))
    local maxS = max(0, total - ui.deckScroll:GetHeight())
    if ui.deckScroll:GetVerticalScroll() > maxS then ui.deckScroll:SetVerticalScroll(maxS) end

    local empty = #list == 0
    ui.deckEmpty:SetShown(empty)
    if empty then
        if #state.liveRecipes == 0 then
            ui.deckEmpty:SetText("Nenhuma receita carregada.\nClique no medalhão de um ofício à esquerda.")
        else
            ui.deckEmpty:SetText("Nenhuma receita neste filtro.")
        end
    end
end
--------------------------------------------------------------------------------
-- Cabeçalho, trilhas e legenda
--------------------------------------------------------------------------------
local function RefreshHeader()
    if not ui.profTitle then return end
    local prof
    for _, p in ipairs(state.professions) do
        if state.activeProf and (Lower(p.name) == Lower(state.activeProf) or (p.spellName and Lower(p.spellName) == Lower(state.activeProf))) then
            prof = p
        end
    end
    -- string.upper não converte letras acentuadas (UTF-8)
    local title = string.upper(state.activeProf or "Ofícios")
    for lo, hi in pairs(H.ACCENTS) do title = title:gsub(lo, hi) end
    ui.profTitle:SetText(title)
    if prof then
        local mode = state.activeMode == "cached" and "  ·  receitas salvas (abra o ofício para criar)" or ""
        ui.profRank:SetText(format("%d / %d%s", prof.rank, prof.maxRank, mode))
        local ratio = prof.maxRank > 0 and min(1, prof.rank / prof.maxRank) or 0
        ui.profBarFill:SetWidth(max(2, 420 * ratio))
        ui.profBarTick:SetPoint("LEFT", ui.profBarBg, "LEFT", 420 * ratio - 1, 0)
    else
        ui.profRank:SetText(#state.professions == 0 and "Nenhum ofício aprendido" or "")
        ui.profBarFill:SetWidth(2)
    end

    for _, lane in ipairs(ui.lanes) do
        local n = 0
        for _, rec in ipairs(state.liveRecipes) do
            if LaneMatch(rec, lane.key) then n = n + 1 end
        end
        lane.num:SetText(tostring(n))
        local on = state.lane == lane.key
        if on then
            lane:SetSkin("WideA")
            lane.num:SetTextColor(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3])
        else
            lane:SetSkin("WideN")
            lane.num:SetTextColor(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3])
        end
    end
    for d, b in pairs(ui.diffChips) do
        b:SetAlpha(state.diffFilter[d] and 1 or 0.3)
    end
end

--------------------------------------------------------------------------------
-- Altar
--------------------------------------------------------------------------------
local function SetTags(list)
    local x = 0
    for i, tag in ipairs(ui.tags) do
        local t = list[i]
        if t then
            tag.label:SetText(t[1])
            local c = t[2] or COL_MUTED
            tag.label:SetTextColor(c[1], c[2], c[3])
            tag.border:SetColor(c[1], c[2], c[3], 0.45)
            local w = tag.label:GetStringWidth() + 22
            tag:SetWidth(w)
            tag:ClearAllPoints()
            tag:SetPoint("TOPLEFT", ui.altarTitle, "BOTTOMLEFT", x, -34)
            x = x + w + 8
            tag:Show()
        else
            tag:Hide()
        end
    end
end

local function RefreshAltar()
    if not ui.altarView then return end
    local rec = H.SelectedRec()
    ui.altarBody:SetShown(rec ~= nil)
    ui.altarEmpty:SetShown(rec == nil)
    ui.backBtn:SetShown(rec ~= nil and #state.history > 0)
    if not rec then return end

    local qr, qg, qb = GetItemQualityColorSafe(rec.link)
    ui.altarTitle:SetText(rec.name)
    ui.altarTitle:SetTextColor(qr, qg, qb)
    ui.altarSub:SetText((rec.header or "Receita") .. ((rec.desc and rec.desc ~= "") and ("  ·  " .. rec.desc) or ""))

    local tags = {}
    local dc = DIFF_COLORS[rec.diff] or DIFF_COLORS.trivial
    tinsert(tags, { "Perícia: " .. string.lower(DIFF_LABEL[rec.diff] or "não sobe"), dc })
    if rec.maxMade and rec.maxMade > (rec.minMade or 1) then
        tinsert(tags, { format("Gera %d-%d", rec.minMade or 1, rec.maxMade) })
    else
        tinsert(tags, { format("Gera %d", rec.minMade or 1) })
    end
    if rec.tools and rec.tools ~= "" then tinsert(tags, { "Requer: " .. rec.tools, COL_WARN }) end
    tinsert(tags, { "Som: " .. KIND_LABEL[H.CraftKind(rec)], COL_GOLD })
    SetTags(tags)

    ui.core.icon:SetTexture(rec.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    local made = rec.minMade or 1
    ui.coreCount:SetText("x" .. (made * state.craftQty))

    local n = min(#ui.nodes, #rec.reagents)
    local R = 172
    for i, node in ipairs(ui.nodes) do
        local rg = rec.reagents[i]
        if rg and i <= n then
            local ang
            if n == 1 then ang = 90
            elseif n == 2 then ang = (i == 1) and 150 or 30
            else ang = 90 + 180 / n - 360 * (i - 1) / n end
            local rad = math.rad(ang)
            node:ClearAllPoints()
            node:SetPoint("CENTER", ui.ringCenter, "CENTER", math.cos(rad) * R, math.sin(rad) * R)
            node.reagent = rg
            node.icon.icon:SetTexture(rg.texture or "Interface\\Icons\\INV_Misc_QuestionMark")
            node.name:SetText(rg.name)
            local have = rg.playerCount or 0
            local need = (rg.count or 1) * state.craftQty
            local ok = have >= need
            node.count:SetText(format("%d / %d", have, need))
            local col = ok and COL_OK or COL_BAD
            node.count:SetTextColor(col[1], col[2], col[3])
            node.icon.icon:SetDesaturated(not ok)
            node.hint:SetShown(state.liveByName[rg.name] ~= nil)
            node:Show()
            if node.line then
                node.line:Show()
                node.line:SetColorTexture(ok and COL_AZAATH[1] or 0.45, ok and COL_AZAATH[2] or 0.50, ok and COL_AZAATH[3] or 0.56, ok and 0.85 or 0.35)
            end
        else
            node:Hide()
            node.reagent = nil
            if node.line then node.line:Hide() end
        end
    end

    local isFav = IsFavorite(rec.name)
    ui.favBtn.label:SetText(isFav and "FAVORITA" or "FAVORITAR")
    local fc = isFav and COL_GOLD or COL_MUTED
    ui.favBtn.label:SetTextColor(fc[1], fc[2], fc[3])
end

--------------------------------------------------------------------------------
-- Mochila
--------------------------------------------------------------------------------
local function BagInvID(bag)
    if bag == 0 then return nil end
    local fn = (_G.C_Container and _G.C_Container.ContainerIDToInventoryID) or _G.ContainerIDToInventoryID
    if fn then
        local ok, id = pcall(fn, bag)
        if ok then return id end
    end
    return nil
end

local function RefreshBag()
    if not ui.bagView then return end
    local usedAll, totalAll = 0, 0
    for bag = 0, 4 do
        local b = ui.bagBtns[bag]
        local slots = API.GetContainerNumSlots and API.GetContainerNumSlots(bag) or 0
        local free = API.GetContainerNumFreeSlots and API.GetContainerNumFreeSlots(bag) or 0
        if type(free) ~= "number" then free = 0 end
        totalAll = totalAll + slots
        usedAll = usedAll + (slots - free)
        local tex
        if bag == 0 then
            tex = "Interface\\Buttons\\Button-Backpack-Up"
        else
            local inv = BagInvID(bag)
            tex = inv and GetInventoryItemTexture("player", inv)
        end
        b.icon:SetTexture(tex or "Interface\\PaperDoll\\UI-PaperDoll-Slot-Bag")
        b.icon:SetDesaturated(slots == 0)
        b.count:SetText(slots > 0 and format("%d/%d", slots - free, slots) or "-")
        local on = state.bagOnly == bag
        b.border:SetColor(on and COL_AZAATH[1] or COL_GOLD[1], on and COL_AZAATH[2] or COL_GOLD[2], on and COL_AZAATH[3] or COL_GOLD[3], on and 1 or 0)
    end
    ui.tabBag.count:SetText(format("%d / %d", usedAll, totalAll))

    for key, chip in pairs(ui.bagChips) do
        local on = state.bagFilter == key
        chip:SetSkin(on and "PillA" or "PillN")
        chip.label:SetTextColor(on and 1 or COL_MUTED[1], on and 1 or COL_MUTED[2], on and 1 or COL_MUTED[3])
    end
    if not ui.bagView:IsShown() then return end

    -- Conjuntos para destacar: materiais da receita, de qualquer receita, criados
    local rec = H.SelectedRec()
    local useSet, matSet, madeSet = {}, {}, {}
    if rec then for _, rg in ipairs(rec.reagents) do useSet[Lower(rg.name)] = true end end
    for _, r in ipairs(state.liveRecipes) do
        for _, rg in ipairs(r.reagents) do matSet[Lower(rg.name)] = true end
        madeSet[Lower(H.ItemName(r.link) or r.name)] = true
    end

    local items = {}
    for bag = 0, 4 do
        if state.bagOnly == nil or state.bagOnly == bag then
            local slots = API.GetContainerNumSlots and API.GetContainerNumSlots(bag) or 0
            for slot = 1, slots do
                local tex, count = API.GetContainerItemInfo(bag, slot)
                local link = tex and API.GetContainerItemLink and API.GetContainerItemLink(bag, slot)
                tinsert(items, { bag = bag, slot = slot, tex = tex, count = count, link = link })
            end
        end
    end

    local cols, rows = 10, 10
    local maxScroll = max(0, ceil(#items / cols) - rows)
    state.bagScroll = max(0, min(state.bagScroll, maxScroll))
    local offset = state.bagScroll * cols
    for i, s in ipairs(ui.bagSlots) do
        local it = items[i + offset]
        if it then
            s:Show()
            s.bag, s.slot, s.link = it.bag, it.slot, it.link
            s.icon:SetTexture(it.tex)
            s.icon:SetShown(it.tex ~= nil)
            s.count:SetText((it.count and it.count > 1) and tostring(it.count) or "")
            local name = Lower(H.ItemName(it.link) or "")
            s.itemName = H.ItemName(it.link)
            local isUse = it.tex and useSet[name]
            local pass = true
            if state.bagFilter == "recipe" then pass = isUse
            elseif state.bagFilter == "mats" then pass = it.tex and matSet[name]
            elseif state.bagFilter == "made" then pass = it.tex and madeSet[name] end
            s:SetAlpha((pass or not it.tex) and 1 or 0.28)
            if isUse then
                s.border:SetColor(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3], 1)
                s.glow:Show()
            else
                s.border:SetColor(1, 1, 1, 0)
                s.glow:Hide()
            end
            local isNew = it.tex and state.newItems[name]
            s.newBg:SetShown(isNew and true or false)
            s.newTxt:SetShown(isNew and true or false)
        else
            s:Hide()
            s.link, s.itemName = nil, nil
        end
    end
    ui.bagMoney:SetText(GetCoinTextureString and GetCoinTextureString(GetMoney() or 0) or tostring(GetMoney() or 0))
end

local function ShowPanel(key)
    state.panel = key
    ui.altarView:SetShown(key == "altar")
    ui.bagView:SetShown(key == "bag")
    for _, t in ipairs({ ui.tabAltar, ui.tabBag }) do
        local on = t.key == key
        t.label:SetTextColor(on and 1 or COL_MUTED[1], on and 1 or COL_MUTED[2], on and 1 or COL_MUTED[3])
        t.underline:SetShown(on)
    end
    if key == "bag" then RefreshBag() else RefreshAltar() end
end

--------------------------------------------------------------------------------
-- Criação: botão, barra de progresso e PARAR
--------------------------------------------------------------------------------
local function RefreshCraftBar()
    if not ui.craftBtn then return end
    local c = state.craft
    local rec = H.SelectedRec()
    local def = MatchProfDef(state.activeProf)
    ui.qtyLabel:SetText(tostring(state.craftQty))

    if c.active then
        ui.craftBtn.label:SetText("CRIANDO...")
        ui.craftBtn:SetAlpha(0.7)
        ui.stopBtn:SetAlpha(1)
    else
        ui.stopBtn:SetAlpha(0.35)
        if state.activeMode == "cached" then
            ui.craftBtn.label:SetText("ABRIR OFÍCIO")
            ui.craftBtn:SetAlpha(0.95)
        else
            ui.craftBtn.label:SetText((def and def.verb) or "CRIAR")
            local can = rec and (rec.numAvail or 0) > 0
            ui.craftBtn:SetAlpha(can and 1 or 0.42)
        end
    end

    -- a fila aparece como losangos sob a barra; a barra enche a cada item
    H.UpdatePips()
    ui.prog:SetAlpha(c.active and 1 or 0.85)
    if not c.active then
        ui.progLeft:SetText(c.result or "PRONTO PARA CRIAR")
        ui.progRight:SetText(rec and format("%d na fila", state.craftQty) or "")
        local full = c.result and c.total and c.total > 0 and c.done >= c.total
        H.SetFill(full and 1 or 0)
    end
end

local function UpdateProgress()
    local c = state.craft
    if not c.active then return end
    local cast = 0
    local left = nil
    if c.castStart and c.castEnd and c.castEnd > c.castStart then
        local now = GetTime() * 1000
        cast = max(0, min(1, (now - c.castStart) / (c.castEnd - c.castStart)))
        left = max(0, (c.castEnd - now) / 1000)
    end
    -- barra = item atual (enche a cada unidade); a fila está nos losangos
    H.SetFill(cast)
    ui.progLeft:SetText("CRIANDO  ·  " .. (c.name or ""))
    local txt = format("%d de %d", min(c.total, c.done + 1), c.total)
    if left then txt = txt .. format("  ·  %.1f s", left):gsub("%.", ",") end
    ui.progRight:SetText(txt)
end

--------------------------------------------------------------------------------
-- Efeito vivo da barra (mesma linguagem da HUD Azaath: chama correndo pelo
-- preenchimento, fagulha na ponta, brilho pulsando e fagulhas soltas)
--------------------------------------------------------------------------------
local AZ = MEDIA_ROOT .. "Azaath\\"
function H.BuildFX(prog, pbg, base)
    local fx = { t = 0, flow = 0, emberT = 0, sweep = 0, flash = 0, flashMax = 1, embers = {} }
    ui.fx = fx
    local fill = ui.progFill
    -- halo atrás da barra (pulsa enquanto cria)
    fx.halo = H.Tex(base or prog, "BACKGROUND", "Glow", W_ALTAR + 80, 60)
    fx.halo:SetPoint("CENTER", pbg, "CENTER")
    fx.halo:SetVertexColor(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3], 1)
    fx.halo:SetBlendMode("ADD")
    -- duas camadas da chama da Azaath, em turquesa, correndo em velocidades diferentes
    local function Flow(sub, alpha)
        local t = prog:CreateTexture(nil, "ARTWORK", nil, sub)
        t:SetTexture(SHEET_MEDIA .. "CraftFlow", "REPEAT", "CLAMP") -- fios de energia sem emenda (gen-flow.js)
        if t.SetHorizTile then t:SetHorizTile(true) end
        t:SetAllPoints(fill)
        t:SetBlendMode("ADD")
        -- textura branca: a cor vem do vertex color
        t:SetVertexColor(0.40, 1, 0.95)
        t:SetAlpha(alpha)
        return t
    end
    -- energia "fantasma" correndo devagar pela barra inteira (o vazio também vive)
    fx.ghost = prog:CreateTexture(nil, "ARTWORK", nil, -2)
    fx.ghost:SetTexture(SHEET_MEDIA .. "CraftFlow", "REPEAT", "CLAMP")
    if fx.ghost.SetHorizTile then fx.ghost:SetHorizTile(true) end
    fx.ghost:SetPoint("TOPLEFT", pbg, "TOPLEFT", 3, -3)
    fx.ghost:SetPoint("BOTTOMRIGHT", pbg, "BOTTOMRIGHT", -3, 3)
    fx.ghost:SetBlendMode("ADD")
    fx.ghost:SetVertexColor(0.30, 0.85, 0.85)
    fx.flowA = Flow(2, 0.9)
    fx.flowB = Flow(3, 0.7)
    -- núcleo brilhante: faixa clara correndo no meio do preenchimento
    fx.core = prog:CreateTexture(nil, "ARTWORK", nil, 1)
    fx.core:SetTexture(MEDIA_ROOT .. "Glow")
    fx.core:SetBlendMode("ADD")
    fx.core:SetVertexColor(0.35, 0.95, 1)
    fx.core:SetPoint("TOPLEFT", fill, "TOPLEFT", 0, 6)
    fx.core:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", 0, -6)
    -- brilho que varre o trecho já cheio
    fx.sweepTex = H.Tex(prog, "ARTWORK", "Glow", 70, 26)
    fx.sweepTex:SetDrawLayer("ARTWORK", 4)
    fx.sweepTex:SetBlendMode("ADD")
    fx.sweepTex:SetVertexColor(0.75, 1, 1)
    -- clarão do segmento recém-concluído / da fila inteira
    fx.flashTex = prog:CreateTexture(nil, "ARTWORK", nil, 5)
    fx.flashTex:SetTexture(MEDIA_ROOT .. "Glow")
    fx.flashTex:SetBlendMode("ADD")
    fx.flashTex:SetVertexColor(0.8, 1, 1)
    fx.flashTex:Hide()
    -- ponta: fagulha da HUD + halo + estrela
    fx.tipGlow = H.Tex(prog, "OVERLAY", "Glow", 64, 64)
    fx.tipGlow:SetPoint("CENTER", fill, "RIGHT", 0, 0)
    fx.tipGlow:SetVertexColor(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3], 1)
    fx.tipGlow:SetBlendMode("ADD")
    fx.tip = prog:CreateTexture(nil, "OVERLAY", nil, 2)
    fx.tip:SetTexture(AZ .. "XPSpark")
    fx.tip:SetBlendMode("ADD")
    fx.tip:SetSize(40, 28)
    fx.tip:SetPoint("RIGHT", fill, "RIGHT", 8, 0)
    fx.star = H.Tex(prog, "OVERLAY", "Star", 34, 34)
    fx.star:SetDrawLayer("OVERLAY", 3)
    fx.star:SetPoint("CENTER", fill, "RIGHT", 0, 0)
    fx.star:SetBlendMode("ADD")
    fx.star:SetVertexColor(0.8, 1, 1)
    -- fagulhas soltas
    for i = 1, 16 do
        local e = prog:CreateTexture(nil, "OVERLAY", nil, 4)
        e:SetTexture(MEDIA_ROOT .. "Glow")
        e:SetBlendMode("ADD")
        e:SetVertexColor(0.55, 1, 0.95)
        e:Hide()
        fx.embers[i] = { tex = e, life = 0, max = 1 }
    end
    H.FXShow(false)
end

function H.UpdatePips()
    if not ui.pips then return end
    local c = state.craft
    local total = (c.active or c.result) and (c.total or 0) or max(1, state.craftQty)
    local n = (total <= #ui.pips) and total or 0
    local step = min(19, (W_ALTAR - 40) / max(1, n))
    for i, pip in ipairs(ui.pips) do
        if i <= n then
            pip.tex:ClearAllPoints()
            pip.tex:SetPoint("CENTER", ui.progBg, "BOTTOM", (i - (n + 1) / 2) * step, -10)
            local done = (c.active or c.result) and i <= (c.done or 0)
            if done then
                pip.tex:SetVertexColor(0.55, 1, 1); pip.tex:SetAlpha(1)
                pip.glow:Show(); pip.glow:SetAlpha(0.55)
            else
                pip.tex:SetVertexColor(0.22, 0.30, 0.34); pip.tex:SetAlpha(0.9)
                pip.glow:Hide()
            end
            pip.done = done
            pip.tex:Show()
        else
            pip.tex:Hide(); pip.glow:Hide()
        end
    end
end

function H.FXShow(on)
    local fx = ui.fx
    if not fx then return end
    for _, k in ipairs({ "flowA", "flowB", "core", "sweepTex", "tipGlow", "tip", "star" }) do fx[k]:SetShown(on) end
    if not on then fx.halo:SetAlpha(0) end
    fx.on = on
end

local function SpawnEmber(x, spread, speed)
    for _, e in ipairs(ui.fx.embers) do
        if e.life <= 0 then
            e.life = 0.5 + math.random() * 0.5
            e.max = e.life
            e.x, e.y = x - math.random() * spread, (math.random() - 0.5) * 6
            e.vx = -(10 + math.random() * 30) * speed
            e.vy = (12 + math.random() * 34) * speed * (math.random() < 0.5 and 1 or -1)
            e.size = 3 + math.random() * 5
            e.tex:Show()
            return
        end
    end
end

-- unidade pronta (idx = segmento) ou fila inteira concluída (final)
function H.FXFlash(idx, total, final)
    local fx = ui.fx
    if not fx then return end
    local w = ui.progBg:GetWidth() - 4
    fx.flashTex:ClearAllPoints()
    if final then
        fx.flashTex:SetPoint("TOPLEFT", ui.progBg, "TOPLEFT", -20, 14)
        fx.flashTex:SetPoint("BOTTOMRIGHT", ui.progBg, "BOTTOMRIGHT", 20, -14)
        for _ = 1, 16 do SpawnEmber(w * math.random(), 0, 2.2) end
    else
        -- item pronto: a barra (que acabou de encher) dá um clarão e solta fagulhas
        fx.flashTex:SetPoint("TOPLEFT", ui.progBg, "TOPLEFT", -12, 12)
        fx.flashTex:SetPoint("BOTTOMRIGHT", ui.progBg, "BOTTOMRIGHT", 12, -12)
        for _ = 1, 8 do SpawnEmber(w - math.random() * 40, 10, 1.8) end
        local pip = ui.pips and ui.pips[idx]
        if pip then pip.pop = 0.35 end
    end
    fx.flash = final and 0.9 or 0.4
    fx.flashMax = fx.flash
    fx.flashTex:Show()
end

function H.UpdateFX(elapsed)
    local fx = ui.fx
    if not fx then return end
    elapsed = elapsed or 0
    fx.t = fx.t + elapsed
    local active = state.craft.active and true or false
    if active ~= fx.on then H.FXShow(active) end
    local fw = ui.progFill:GetWidth()

    if active then
        -- chama correndo (duas camadas, velocidades e sentidos diferentes)
        fx.flow = (fx.flow + elapsed * 0.35) % 1
        local span = max(0.05, fw / 120)
        fx.flowA:SetTexCoord(-fx.flow * 2, -fx.flow * 2 + span, 0, 1)
        fx.flowB:SetTexCoord(fx.flow * 1.3 + span * 0.8, fx.flow * 1.3, 1, 0)
        -- halo e ponta pulsando / tremulando como chama
        local pulse = 0.5 + 0.5 * math.sin(fx.t * 3.2)
        fx.halo:SetAlpha(0.18 + 0.22 * pulse)
        fx.core:SetAlpha(0.35 + 0.25 * pulse)
        -- losango do item em andamento pulsa
        local cur = ui.pips and ui.pips[(state.craft.done or 0) + 1]
        if cur and cur.tex:IsShown() then
            -- item em andamento
            cur.tex:SetVertexColor(0.55, 1, 1)
            cur.tex:SetAlpha(0.5 + 0.5 * pulse)
            cur.glow:Show(); cur.glow:SetAlpha(0.25 + 0.35 * pulse)
        end
        local flick = 0.75 + 0.25 * math.sin(fx.t * 19) * math.sin(fx.t * 7.3)
        fx.tip:SetAlpha(flick)
        fx.tipGlow:SetAlpha(0.35 + 0.3 * pulse)
        fx.tipGlow:SetSize(38 + 10 * pulse, 38 + 10 * pulse)
        local st = 26 + 10 * pulse
        fx.star:SetSize(st, st)
        fx.star:SetAlpha(0.5 + 0.5 * flick)
        if fx.star.SetRotation then fx.star:SetRotation(fx.t * 0.8) end
        -- brilho varrendo o trecho cheio a cada 1,6 s
        fx.sweep = (fx.sweep + elapsed / 1.6) % 1
        if fw > 30 then
            fx.sweepTex:Show()
            fx.sweepTex:ClearAllPoints()
            fx.sweepTex:SetPoint("CENTER", ui.progFill, "LEFT", fw * fx.sweep, 0)
            fx.sweepTex:SetAlpha(math.sin(math.pi * fx.sweep) * 0.8)
        else
            fx.sweepTex:Hide()
        end
        -- fagulhas soltando da ponta
        fx.emberT = fx.emberT - elapsed
        if fx.emberT <= 0 and fw > 4 then
            fx.emberT = 0.07 + math.random() * 0.06
            SpawnEmber(fw, 4, 1)
        end
    end

    -- energia fantasma: sempre correndo, mais forte durante a criação
    fx.ghostOff = ((fx.ghostOff or 0) + elapsed * (active and 0.12 or 0.04)) % 1
    local gspan = (W_ALTAR - 6) / 120
    fx.ghost:SetTexCoord(fx.ghostOff, fx.ghostOff + gspan, 0, 1)
    fx.ghost:SetAlpha(active and 0.16 or 0.07)

    -- clarão (segue mesmo depois que a fila acaba)
    if fx.flash > 0 then
        fx.flash = fx.flash - elapsed
        local k = max(0, fx.flash / fx.flashMax)
        fx.flashTex:SetAlpha(k * k)
        if fx.flash <= 0 then fx.flashTex:Hide() end
    end

    -- losango recém-aceso "estoura"
    for _, pip in ipairs(ui.pips or {}) do
        if pip.pop > 0 then
            pip.pop = pip.pop - elapsed
            local k = max(0, pip.pop / 0.35)
            pip.tex:SetSize(11 + 9 * k, 11 + 9 * k)
            pip.glow:SetSize(24 + 26 * k, 24 + 26 * k)
            pip.glow:SetAlpha(0.55 + 0.45 * k)
        end
    end

    -- fagulhas
    for _, e in ipairs(fx.embers) do
        if e.life > 0 then
            e.life = e.life - elapsed
            if e.life <= 0 then
                e.tex:Hide()
            else
                e.x, e.y = e.x + e.vx * elapsed, e.y + e.vy * elapsed
                e.vy = e.vy * (1 - 1.5 * elapsed)
                local k = e.life / e.max
                local sz = e.size * (0.4 + 0.6 * k)
                e.tex:SetSize(sz, sz)
                e.tex:SetAlpha(k)
                e.tex:ClearAllPoints()
                e.tex:SetPoint("CENTER", ui.progBg, "LEFT", 2 + e.x, e.y)
            end
        end
    end
end

local function FinishCraft(result)
    local c = state.craft
    c.active = false
    c.castStart, c.castEnd = nil, nil
    c.result = result
    H.StopSound()
    RefreshCraftBar()
end

local function DoCraftSelected()
    local rec = H.SelectedRec()
    if not rec then return end
    if state.activeMode == "cached" then
        print("|cffe3c78b[AzaathUI]|r Clique no medalhão do ofício (à esquerda) para abri-lo e criar este item.")
        return
    end
    if (rec.numAvail or 0) <= 0 then
        print("|cffe3c78b[AzaathUI]|r Faltam materiais para " .. rec.name .. ".")
        return
    end
    local qty = max(1, min(state.craftQty, rec.numAvail or 1))
    if rec.mode == "craft" then qty = 1 end
    local c = state.craft
    c.active, c.total, c.done = true, qty, 0
    c.name, c.kind, c.link = rec.name, H.CraftKind(rec), rec.link
    c.result = nil
    c.castStart, c.castEnd = nil, nil
    if rec.mode == "modern" and rec.recipeID and _G.C_TradeSkillUI and _G.C_TradeSkillUI.CraftRecipe then
        pcall(_G.C_TradeSkillUI.CraftRecipe, rec.recipeID, qty)
    elseif rec.mode == "tradeskill" and rec.index and DoTradeSkill then
        pcall(DoTradeSkill, rec.index, qty)
    elseif rec.mode == "craft" and rec.index and DoCraft then
        pcall(DoCraft, rec.index)
    end
    RefreshCraftBar()
    -- Se nenhuma conjuração começar (ex.: sem fogueira), libera a barra
    if C_Timer and C_Timer.After then
        C_Timer.After(1.2, function()
            if c.active and c.done == 0 and not c.castStart then FinishCraft("NÃO FOI POSSÍVEL CRIAR") end
        end)
    end
end

-- Eventos de conjuração do jogador (chamado pelo frame de eventos)
function M:OnPlayerCast(event)
    local c = state.craft
    if event == "UNIT_SPELLCAST_START" then
        local ok, name, _, _, startMS, endMS = pcall(UnitCastingInfo, "player")
        if not ok or type(name) ~= "string" then return end
        if not c.active then
            local rec = state.liveByName[name]
            if not rec then return end
            c.active, c.total, c.done = true, 1, 0
            c.name, c.kind, c.link, c.result = rec.name, H.CraftKind(rec), rec.link, nil
        end
        if type(startMS) == "number" and type(endMS) == "number" then
            c.castStart, c.castEnd = startMS, endMS
        end
        H.StopSound()
        c.handle = H.PlaySound(KIND_FILE[c.kind or "generic"] or "CraftGeneric")
        RefreshCraftBar()
    elseif not c.active then
        return
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if not c.castStart then return end
        c.done = c.done + 1
        c.castStart, c.castEnd = nil, nil
        local nm = H.ItemName(c.link) or c.name
        if nm then state.newItems[Lower(nm)] = true end
        H.FXFlash(c.done, c.total, c.done >= c.total)
        H.UpdatePips()
        if c.done >= c.total then
            -- fila terminou: corta o som do ofício e toca a fanfarra coral
            FinishCraft(format("CONCLUÍDO  ·  %d de %d", c.done, c.total))
            H.PlaySound("CraftDone")
        else
            H.PlaySound("CraftUnitEpic") -- nome novo: o jogo guarda o som antigo até reiniciar
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        if c.castStart or c.done > 0 then
            FinishCraft(format("INTERROMPIDO  ·  %d de %d", c.done, c.total))
        end
    end
end

--------------------------------------------------------------------------------
-- Overlay seguro (em UIParent, nunca dentro de AzaathUISheet, para que o
-- Santuário possa abrir, trocar de aba e fechar em combate sem taint)
--------------------------------------------------------------------------------
local function ShowMedTooltip(med)
    if not (med and med.prof) then return end
    GameTooltip:SetOwner(med, "ANCHOR_RIGHT")
    GameTooltip:AddLine(med.prof.name, COL_GOLD[1], COL_GOLD[2], COL_GOLD[3])
    GameTooltip:AddLine(format("%d / %d", med.prof.rank, med.prof.maxRank), 0.85, 0.90, 0.95)
    if med.prof.hasWindow then
        GameTooltip:AddLine("Clique para abrir receitas", COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3])
    else
        GameTooltip:AddLine("Perícia de coleta (sem receitas)", COL_MUTED[1], COL_MUTED[2], COL_MUTED[3])
    end
    GameTooltip:Show()
end

local function StopCraftAction()
    if StopTradeSkillRepeat then pcall(StopTradeSkillRepeat) end
    local TS = _G.C_TradeSkillUI
    if TS and TS.StopRecipeRepeat then pcall(TS.StopRecipeRepeat) end
    local c = state.craft
    if c.active then FinishCraft(format("PARADO  ·  %d de %d", c.done, c.total)) end
end

local function DetachSecure()
    local o = ui.secureOverlay
    if not o or (InCombatLockdown and InCombatLockdown()) then return end
    o.owner, o.kind = nil, nil
    o:Hide()
    o:ClearAllPoints()
    o:SetAttribute("type", nil)
    o:SetAttribute("spell", nil)
    o:SetAttribute("macrotext", nil)
end

local AttachSecure
local function EnsureSecureOverlay()
    if ui.secureOverlay or (InCombatLockdown and InCombatLockdown()) then return ui.secureOverlay end
    local o = CreateFrame("Button", "AzaathUIProfSecureOverlay", UIParent, "SecureActionButtonTemplate")
    o:SetFrameStrata("DIALOG")
    o:SetFrameLevel(200)
    o:RegisterForClicks("AnyUp", "AnyDown")
    o:SetAttribute("useOnKeyDown", false)
    o:Hide()
    o:SetScript("OnEnter", function(self)
        if self.kind == "med" and self.owner then
            ShowMedTooltip(self.owner)
        end
    end)
    o:SetScript("OnLeave", function()
        GameTooltip:Hide()
        DetachSecure()
    end)
    o:SetScript("PostClick", function(self, _, down)
        if down then return end
        local owner, kind = self.owner, self.kind
        if kind == "med" and owner and ui.onMedClick then
            ui.onMedClick(owner)
        elseif kind == "stop" then
            StopCraftAction()
        end
        if self:IsShown() and owner and owner:IsVisible() and not (InCombatLockdown and InCombatLockdown()) then
            AttachSecure(owner, kind)
        end
    end)
    ui.secureOverlay = o
    return o
end

AttachSecure = function(owner, kind)
    if (InCombatLockdown and InCombatLockdown()) or not owner or not owner:IsVisible() then return end
    if kind == "med" and not (owner.prof and owner.prof.spellName) then
        DetachSecure()
        return
    end
    local o = EnsureSecureOverlay()
    if not o then return end
    local l, t = owner:GetLeft(), owner:GetTop()
    if not (l and t) then return end
    local s = owner:GetEffectiveScale() / o:GetEffectiveScale()
    o:ClearAllPoints()
    o:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * s, t * s)
    o:SetSize(owner:GetWidth() * s, owner:GetHeight() * s)
    o.owner, o.kind = owner, kind
    if kind == "med" then
        o:SetAttribute("type", "spell")
        o:SetAttribute("spell", owner.prof.spellName)
        o:SetAttribute("macrotext", nil)
    else
        o:SetAttribute("type", "macro")
        o:SetAttribute("macrotext", "/stopcasting")
        o:SetAttribute("spell", nil)
    end
    o:Show()
end

--------------------------------------------------------------------------------
-- Profissões (medalhões)
--------------------------------------------------------------------------------
local function RefreshSpine()
    if not ui.meds then return end
    -- varrer perícias/grimório é caro: só na abertura e quando a perícia muda
    if state.profScanDirty ~= false or #state.professions == 0 then
        ScanPlayerProfessions()
        state.profScanDirty = false
    end
    local inCombat = InCombatLockdown and InCombatLockdown()
    for i, med in ipairs(ui.meds) do
        local p = state.professions[i]
        if p then
            med:Show()
            med.prof = p
            med.icon.icon:SetTexture(p.icon)
            med.title:SetText(p.name)
            med.rank:SetText(format("%d / %d", p.rank, p.maxRank))
            local active = state.activeProf and (Lower(state.activeProf) == Lower(p.name)
                or (p.spellName and Lower(state.activeProf) == Lower(p.spellName)))
            local size = active and 70 or 50
            -- anel de bronze da arte: o furo tem ~70% do diâmetro
            med.icon:SetSize(size * 1.42, size * 1.42)
            med.icon.icon:SetSize(size, size)
            med.track:Hide()
            med.glow:SetShown(active and true or false)
            med.title:SetTextColor(active and 1 or COL_CREAM[1], active and 1 or COL_CREAM[2], active and 1 or COL_CREAM[3])
            if med.cd then med.cd:Hide() end -- a arte usa só o anel de bronze
            if not inCombat and ui.secureOverlay and ui.secureOverlay.owner == med then
                AttachSecure(med, "med")
            end
        else
            med:Hide()
            med.prof = nil
            if not inCombat and ui.secureOverlay and ui.secureOverlay.owner == med then
                DetachSecure()
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Atualização geral
--------------------------------------------------------------------------------
function M:RefreshView()
    RefreshHeader()
    LayoutDecks()
    if state.panel == "bag" then RefreshBag() else RefreshAltar(); RefreshBag() end
    RefreshCraftBar()
end

-- Agrupa atualizações: rescan = true (pelo modo atual), "tradeskill" ou "craft".
-- Com criação em andamento espera mais, para cair entre um item e outro.
local pending = { scheduled = false, rescan = nil }
local function FlushRefresh()
    pending.scheduled = false
    local what = pending.rescan
    pending.rescan = nil
    if what == "tradeskill" then
        ScanTradeSkill()
    elseif what == "craft" then
        ScanCraft()
    elseif what then
        if state.activeMode == "tradeskill" or state.activeMode == "modern" then ScanTradeSkill()
        elseif state.activeMode == "craft" then ScanCraft()
        elseif state.activeProf then LoadFromCache(state.activeProf) end
    end
    if ui.art and ui.art:IsVisible() then M:Refresh() end
end

function M:QueueRefresh(rescan)
    if rescan then pending.rescan = (type(rescan) == "string") and rescan or (pending.rescan or true) end
    if pending.scheduled then return end
    pending.scheduled = true
    local delay = state.craft.active and 0.25 or 0.08
    if C_Timer and C_Timer.After then C_Timer.After(delay, FlushRefresh) else FlushRefresh() end
end

function M:Refresh()
    if not ui.art then return end
    RefreshSpine()
    if not state.activeProf then
        for _, p in ipairs(state.professions) do
            if LoadFromCache(p.name) or (p.spellName and LoadFromCache(p.spellName)) then break end
        end
    end
    if not (state.selectedRecipe and state.liveByName[state.selectedRecipe]) then
        state.selectedRecipe = state.liveRecipes[1] and state.liveRecipes[1].name or nil
    end
    self:RefreshView()
end

--------------------------------------------------------------------------------
-- Construção (1920x1080, coordenadas da arte)
--------------------------------------------------------------------------------
local function OnMedPostClick(self)
    if not self.prof then return end
    state.activeProf = self.prof.name
    state.lane = nil
    if ui.deckScroll then ui.deckScroll:SetVerticalScroll(0) end
    state.category, state.shelfOffset = nil, 0
    if not self.prof.hasWindow then
        state.activeMode = "cached"
        wipe(state.liveRecipes)
        wipe(state.liveByName)
        state.selectedRecipe = nil
    elseif LoadFromCache(self.prof.name) or (self.prof.spellName and LoadFromCache(self.prof.spellName)) then
        state.selectedRecipe = state.liveRecipes[1] and state.liveRecipes[1].name or nil
    end
    M:Refresh()
    if not (self.prof.hasWindow and C_Timer and C_Timer.After) then return end
    local prof = self.prof
    local function TrySync()
        if not (ui.art and ui.art:IsVisible()) then return end
        SuppressBlizzFrame(_G.TradeSkillFrame)
        SuppressBlizzFrame(_G.ProfessionsFrame)
        SuppressBlizzFrame(_G.CraftFrame)
        if state.activeMode == "cached" or #state.liveRecipes == 0 then
            ScanTradeSkill()
            if (state.activeMode == "cached" or #state.liveRecipes == 0) and GetNumCrafts and (GetNumCrafts() or 0) > 0 then ScanCraft() end
            if #state.liveRecipes > 0 then M:Refresh() end
        end
    end
    C_Timer.After(0.06, function()
        TrySync()
        if #state.liveRecipes == 0 and prof.skillLineID and _G.C_TradeSkillUI and _G.C_TradeSkillUI.OpenTradeSkill
           and not (InCombatLockdown and InCombatLockdown()) then
            pcall(_G.C_TradeSkillUI.OpenTradeSkill, prof.skillLineID)
        end
    end)
    C_Timer.After(0.28, TrySync)
end

local function BuildSpine(art)
    ui.onMedClick = OnMedPostClick
    local F = ui.fonts
    local spineLine = art:CreateTexture(nil, "BACKGROUND", nil, 1)
    spineLine:SetPoint("TOPLEFT", art, "TOPLEFT", 94, -150)
    spineLine:SetSize(2, 760)
    spineLine:SetColorTexture(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 0.22)

    ui.meds = {}
    for i = 1, 6 do
        local med = CreateFrame("Button", "AzaathUIProfPill" .. i, art)
        med:SetSize(120, 136)
        med:SetPoint("TOP", art, "TOPLEFT", 95, -112 - (i - 1) * 144)
        med:RegisterForClicks("LeftButtonUp")

        local center = CreateFrame("Frame", nil, med)
        center:SetSize(110, 110)
        center:SetPoint("TOP", 0, 0)

        med.glow = H.Tex(center, "BACKGROUND", "Glow", 150)
        med.glow:SetPoint("CENTER")
        med.glow:SetVertexColor(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3], 0.35)

        med.track = H.Tex(center, "BORDER", "CastRingThin", 84)
        med.track:SetPoint("CENTER")
        med.track:SetVertexColor(1, 1, 1, 0.10)

        local ok, cd = pcall(CreateFrame, "Cooldown", nil, center, "CooldownFrameTemplate")
        if ok and cd and cd.SetSwipeTexture then
            cd:SetAllPoints(med.track)
            cd:SetSwipeTexture(MEDIA_ROOT .. "CastRingThin")
            cd:SetSwipeColor(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3], 1)
            if cd.SetDrawEdge then cd:SetDrawEdge(false) end
            if cd.SetDrawBling then cd:SetDrawBling(false) end
            if cd.SetHideCountdownNumbers then cd:SetHideCountdownNumbers(true) end
            if cd.SetUseCircularEdge then cd:SetUseCircularEdge(true) end
            cd.noCooldownCount = true
            cd:Hide()
            med.cd = cd
        end

        med.icon = H.CircleIcon(center, 58, 82, "RingBronze")
        med.icon:SetPoint("CENTER")
        med.icon:SetFrameLevel(center:GetFrameLevel() + 3)

        med.title = H.Txt(med, F.CB, 13, COL_CREAM, "CENTER")
        med.title:SetPoint("TOP", center, "BOTTOM", 0, -2)
        med.title:SetWidth(130)
        med.rank = H.Txt(med, F.B, 11, COL_AZAATH, "CENTER")
        med.rank:SetPoint("TOP", med.title, "BOTTOM", 0, -2)

        med:SetScript("OnEnter", function(self)
            ShowMedTooltip(self)
            AttachSecure(self, "med")
        end)
        med:SetScript("OnLeave", function() GameTooltip:Hide() end)
        med:SetScript("OnHide", function(self)
            if ui.secureOverlay and ui.secureOverlay.owner == self then DetachSecure() end
        end)
        med:SetScript("OnClick", OnMedPostClick)
        med:Hide()
        ui.meds[i] = med
    end
end

local function BuildMain(art)
    local F = ui.fonts
    -- véu suave: a arte de fundo continua visível atrás das cartas
    local veil = art:CreateTexture(nil, "BACKGROUND", nil, 0)
    veil:SetPoint("TOPLEFT", art, "TOPLEFT", X_MAIN - 16, -100)
    veil:SetSize(W_MAIN + 32, 960)
    veil:SetColorTexture(0.02, 0.04, 0.07, 0.42)

    ui.profTitle = H.Txt(art, F.C, 34, COL_CREAM)
    ui.profTitle:SetPoint("TOPLEFT", art, "TOPLEFT", X_MAIN, -112)
    ui.profRank = H.Txt(art, F.B, 14, COL_MUTED)
    ui.profRank:SetPoint("BOTTOMLEFT", ui.profTitle, "BOTTOMRIGHT", 18, 4)

    local barBg = art:CreateTexture(nil, "ARTWORK")
    barBg:SetPoint("TOPLEFT", ui.profTitle, "BOTTOMLEFT", 0, -10)
    barBg:SetSize(420, 6)
    barBg:SetColorTexture(1, 1, 1, 0.08)
    ui.profBarBg = barBg
    ui.profBarFill = art:CreateTexture(nil, "ARTWORK", nil, 1)
    ui.profBarFill:SetPoint("LEFT", barBg, "LEFT")
    ui.profBarFill:SetSize(2, 6)
    ui.profBarFill:SetColorTexture(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3], 0.95)
    ui.profBarTick = art:CreateTexture(nil, "OVERLAY")
    ui.profBarTick:SetSize(2, 14)
    ui.profBarTick:SetPoint("LEFT", barBg, "LEFT")
    ui.profBarTick:SetColorTexture(1, 1, 1, 0.9)

    -- Trilhas rápidas
    ui.lanes = {}
    local laneW = (W_MAIN - 3 * 12) / 4
    for i, def in ipairs(LANES) do
        local lane = H.Panel(art, laneW, 76, "WideN", 0.72)
        lane:SetPoint("TOPLEFT", art, "TOPLEFT", X_MAIN + (i - 1) * (laneW + 12), -184)
        lane.key = def.key
        lane.title = H.Txt(lane, F.CB, 14, COL_CREAM)
        lane.title:SetPoint("TOPLEFT", 16, -16)
        lane.desc = H.Txt(lane, F.B, 12, COL_MUTED)
        lane.desc:SetPoint("TOPLEFT", lane.title, "BOTTOMLEFT", 0, -8)
        lane.desc:SetText(def.desc)
        lane.title:SetText(def.title)
        lane.num = H.Txt(lane, F.C, 30, COL_GOLD, "RIGHT")
        lane.num:SetPoint("RIGHT", -18, 0)
        lane:SetScript("OnClick", function(self)
            state.lane = (state.lane ~= self.key) and self.key or nil
            ui.deckScroll:SetVerticalScroll(0)
            M:RefreshView()
        end)
        ui.lanes[i] = lane
    end

    -- Busca
    local sb = CreateFrame("EditBox", nil, art)
    sb:SetSize(560, 34)
    sb:SetPoint("TOPLEFT", art, "TOPLEFT", X_MAIN, -276)
    sb:SetAutoFocus(false)
    sb:SetFont(F.B, 14, "")
    sb:SetTextColor(1, 0.96, 0.88)
    sb:SetTextInsets(14, 14, 0, 0)
    H.Skin(sb, "Search", 0.47)
    sb:SetTextInsets(20, 20, 0, 0)
    local ph = H.Txt(sb, F.B, 13, COL_DIM)
    ph:SetPoint("LEFT", 20, 0)
    ph:SetText("Buscar receita, item ou reagente...")
    sb:SetScript("OnTextChanged", function(self)
        local txt = self:GetText() or ""
        ph:SetShown(txt == "")
        state.searchText = txt
        LayoutDecks()
    end)
    sb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    ui.searchBox = sb

    -- Legenda de dificuldade (clicável: liga/desliga)
    ui.diffChips = {}
    local prev
    for _, d in ipairs(DIFF_ORDER) do
        local b = CreateFrame("Button", nil, art)
        b:SetHeight(24)
        local gem = b:CreateTexture(nil, "ARTWORK")
        gem:SetSize(13, 15)
        H.AtlasTex(gem, H.GEM[d])
        gem:SetPoint("LEFT", 0, 0)

        local lbl = H.Txt(b, F.B, 12, COL_MUTED)
        lbl:SetPoint("LEFT", gem, "RIGHT", 6, 0)
        lbl:SetText(DIFF_LABEL[d])
        b:SetWidth(lbl:GetStringWidth() + 22)
        if prev then b:SetPoint("LEFT", prev, "RIGHT", 16, 0) else b:SetPoint("LEFT", sb, "RIGHT", 24, 0) end
        b:SetScript("OnClick", function()
            state.diffFilter[d] = not state.diffFilter[d]
            M:RefreshView()
        end)
        ui.diffChips[d] = b
        prev = b
    end

    -- Estante de categorias (setas + roda do mouse)
    local shelf = CreateFrame("Frame", nil, art)
    shelf:SetPoint("TOPLEFT", art, "TOPLEFT", X_MAIN + 32, -330)
    shelf:SetSize(W_MAIN - 64, TILE_H)
    shelf:EnableMouseWheel(true)
    shelf:SetScript("OnMouseWheel", function(_, delta) M:ScrollShelf(-delta) end)
    ui.shelf = shelf
    ui.shelfSlots = floor((W_MAIN - 64 + TILE_GAP) / (TILE_W + TILE_GAP))
    local function Arrow(key)
        local b = CreateFrame("Button", nil, art)
        b:SetSize(24, 34)
        local tx = b:CreateTexture(nil, "ARTWORK")
        tx:SetAllPoints()
        H.AtlasTex(tx, key)
        local hl = b:CreateTexture(nil, "HIGHLIGHT")
        hl:SetAllPoints()
        H.AtlasTex(hl, key)
        hl:SetBlendMode("ADD")
        hl:SetAlpha(0.5)
        return b
    end
    local left = Arrow("ArrowL")
    left:SetPoint("RIGHT", shelf, "LEFT", -6, 0)
    left:SetScript("OnClick", function() M:ScrollShelf(-1) end)
    local right = Arrow("ArrowR")
    right:SetPoint("LEFT", art, "TOPLEFT", X_MAIN + W_MAIN - 24, -330 - TILE_H / 2)
    right:SetScript("OnClick", function() M:ScrollShelf(1) end)
    ui.shelfLeft, ui.shelfRight = left, right

    -- Cabeçalho da categoria escolhida
    ui.catTitle = H.Txt(art, F.C, 22, COL_CREAM)
    ui.catTitle:SetPoint("TOPLEFT", art, "TOPLEFT", X_MAIN, -472)
    ui.catSub = H.Txt(art, F.B, 12, COL_MUTED)
    ui.catSub:SetPoint("BOTTOMLEFT", ui.catTitle, "BOTTOMRIGHT", 14, 3)
    local catLine = art:CreateTexture(nil, "ARTWORK")
    catLine:SetPoint("TOPLEFT", art, "TOPLEFT", X_MAIN, -506)
    catLine:SetSize(W_MAIN, 1)
    catLine:SetColorTexture(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 0.25)

    -- Grade de cartas grandes (rolagem vertical)
    local sf = CreateFrame("ScrollFrame", nil, art)
    sf:SetPoint("TOPLEFT", art, "TOPLEFT", X_MAIN, -520)
    sf:SetSize(W_MAIN, 530)
    sf:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(W_MAIN, 530)
    sf:SetScrollChild(child)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local maxS = max(0, child:GetHeight() - self:GetHeight())
        self:SetVerticalScroll(max(0, min(maxS, self:GetVerticalScroll() - delta * (CARD_H + CARD_GAP) / 2)))
    end)
    ui.deckScroll, ui.deckChild = sf, child
    ui.deckEmpty = H.Txt(sf, F.B, 15, COL_MUTED, "CENTER")
    ui.deckEmpty:SetPoint("TOP", sf, "TOP", 0, -100)
    ui.deckEmpty:SetWidth(600)
    ui.deckEmpty:SetWordWrap(true)
end

local function BuildAltarView(parent)
    local F = ui.fonts
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    ui.altarView = v

    ui.altarEmpty = H.Txt(v, F.C, 20, COL_MUTED, "CENTER")
    ui.altarEmpty:SetPoint("TOP", v, "TOP", 0, -260)
    ui.altarEmpty:SetWidth(500)
    ui.altarEmpty:SetWordWrap(true)
    ui.altarEmpty:SetText("Escolha uma carta para colocá-la no altar")

    local body = CreateFrame("Frame", nil, v)
    body:SetAllPoints()
    ui.altarBody = body

    ui.altarTitle = H.Txt(body, F.C, 28, COL_GOLD)
    ui.altarTitle:SetPoint("TOPLEFT", body, "TOPLEFT", 0, -6)
    ui.altarTitle:SetWidth(W_ALTAR - 110)
    ui.altarSub = H.Txt(body, F.B, 13, COL_MUTED)
    ui.altarSub:SetPoint("TOPLEFT", ui.altarTitle, "BOTTOMLEFT", 0, -6)
    ui.altarSub:SetWidth(W_ALTAR - 10)

    ui.tags = {}
    for i = 1, 5 do
        local t = H.Pill(body, 80, 24, "", F.B, 11, COL_MUTED, "PillN", 0.55)
        t:EnableMouse(false)
        ui.tags[i] = t
    end

    local back = H.Pill(body, 96, 26, "< VOLTAR", F.B, 11, COL_AZAATH, "PillN", 0.58)
    back:SetPoint("TOPRIGHT", body, "TOPRIGHT", 0, -6)
    back:SetScript("OnClick", function()
        local prev = tremove(state.history)
        if prev and state.liveByName[prev] then SelectRecipe(state.liveByName[prev], true) end
    end)
    ui.backBtn = back

    -- Círculo de transmutação
    local rc = CreateFrame("Frame", nil, body)
    rc:SetSize(10, 10)
    rc:SetPoint("CENTER", body, "TOP", 0, -470)
    ui.ringCenter = rc
    -- círculo rúnico da arte, girando devagar
    local runes = body:CreateTexture(nil, "BACKGROUND", nil, 2)
    H.AtlasTex(runes, "Runes")
    runes:SetSize(480, 480)
    runes:SetPoint("CENTER", rc)
    -- sem o encaixe na grade de pixels, o giro lento não anda "aos trancos"
    if runes.SetSnapToPixelGrid then runes:SetSnapToPixelGrid(false) end
    if runes.SetTexelSnappingBias then runes:SetTexelSnappingBias(0) end
    local runeAng = 0
    rc:SetScript("OnUpdate", function(_, elapsed)
        runeAng = (runeAng - elapsed * (2 * math.pi / 240)) % (2 * math.pi)
        runes:SetRotation(runeAng)
    end)
    local halo = H.Tex(body, "BACKGROUND", "Glow", 300)
    halo:SetPoint("CENTER", rc)
    halo:SetVertexColor(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3], 0.22)

    local core = H.CircleIcon(body, 106, 176, "RingDark")
    core:SetPoint("CENTER", rc)
    core:SetFrameLevel(body:GetFrameLevel() + 4)
    core:EnableMouse(true)
    core:SetScript("OnEnter", function(self)
        local rec = H.SelectedRec()
        if rec and rec.link then
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            pcall(GameTooltip.SetHyperlink, GameTooltip, rec.link)
            GameTooltip:Show()
        end
    end)
    core:SetScript("OnLeave", function() GameTooltip:Hide() end)
    ui.core = core
    ui.coreCount = H.Txt(core, F.CB, 15, COL_AZAATH, "CENTER")
    ui.coreCount:SetPoint("TOP", core, "BOTTOM", 0, -4)

    ui.nodes = {}
    for i = 1, 8 do
        local node = CreateFrame("Button", nil, body)
        node:SetSize(66, 66)
        node:SetFrameLevel(body:GetFrameLevel() + 5)
        node.icon = H.CircleIcon(node, 50, 70, "RingSmall")
        node.icon:SetPoint("CENTER")
        node.name = H.Txt(node, F.B, 12, COL_CREAM, "CENTER")
        node.name:SetPoint("TOP", node, "BOTTOM", 0, -2)
        node.name:SetWidth(130)
        node.count = H.Txt(node, F.CB, 14, COL_OK, "CENTER")
        node.count:SetPoint("TOP", node.name, "BOTTOM", 0, -2)
        node.hint = H.Txt(node, F.B, 10, COL_AZAATH, "CENTER")
        node.hint:SetPoint("TOP", node.count, "BOTTOM", 0, -1)
        node.hint:SetText("clique: ver receita")
        local okL, line = pcall(body.CreateLine, body, nil, "BORDER")
        if okL and line then
            line:SetThickness(2)
            line:SetStartPoint("CENTER", rc)
            line:SetEndPoint("CENTER", node)
            node.line = line
        end
        node:SetScript("OnEnter", function(self)
            if self.reagent and self.reagent.link then
                GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
                pcall(GameTooltip.SetHyperlink, GameTooltip, self.reagent.link)
                GameTooltip:Show()
            end
        end)
        node:SetScript("OnLeave", function() GameTooltip:Hide() end)
        node:SetScript("OnClick", function(self)
            local sub = self.reagent and state.liveByName[self.reagent.name]
            if sub then
                if state.selectedRecipe then tinsert(state.history, state.selectedRecipe) end
                SelectRecipe(sub, true)
            end
        end)
        node:Hide()
        ui.nodes[i] = node
    end
end

local function BuildBagView(parent)
    local F = ui.fonts
    local v = CreateFrame("Frame", nil, parent)
    v:SetAllPoints()
    v:Hide()
    ui.bagView = v

    ui.bagBtns = {}
    for bag = 0, 4 do
        local b = CreateFrame("Button", nil, v)
        b:SetSize(52, 52)
        b:SetPoint("TOPLEFT", v, "TOPLEFT", bag * 66, -6)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", 8, -8)
        b.icon:SetPoint("BOTTOMRIGHT", -8, 8)
        H.Skin(b, "BtnSquare", 0.57)
        b.border = H.Border(b, COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 0)
        b.count = H.Txt(b, F.B, 11, COL_MUTED, "CENTER")
        b.count:SetPoint("TOP", b, "BOTTOM", 0, -3)
        b:SetScript("OnClick", function()
            state.bagOnly = (state.bagOnly ~= bag) and bag or nil
            state.bagScroll = 0
            RefreshBag()
        end)
        b:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            local inv = BagInvID(bag)
            if inv then
                GameTooltip:SetInventoryItem("player", inv)
            else
                GameTooltip:AddLine(bag == 0 and "Mochila" or "Bolsa vazia", 1, 1, 1)
            end
            GameTooltip:AddLine("Clique: mostrar só esta bolsa", COL_MUTED[1], COL_MUTED[2], COL_MUTED[3])
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        ui.bagBtns[bag] = b
    end

    ui.bagChips = {}
    local chipDefs = {
        { "recipe", "Usados na receita" }, { "mats", "Materiais de ofício" },
        { "made", "Criados por você" }, { "all", "Tudo" },
    }
    local prev
    for _, cd in ipairs(chipDefs) do
        local chip = H.Pill(v, 10, 26, cd[2], F.B, 12, COL_MUTED, "PillN", 0.6)
        chip:SetWidth(chip.label:GetStringWidth() + 26)
        if prev then chip:SetPoint("LEFT", prev, "RIGHT", 8, 0) else chip:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -88) end
        chip:SetScript("OnClick", function()
            state.bagFilter = cd[1]
            RefreshBag()
        end)
        ui.bagChips[cd[1]] = chip
        prev = chip
    end

    local grid = CreateFrame("Frame", nil, v)
    grid:SetPoint("TOPLEFT", v, "TOPLEFT", 0, -128)
    grid:SetSize(W_ALTAR, 580)
    grid:EnableMouseWheel(true)
    grid:SetScript("OnMouseWheel", function(_, delta)
        state.bagScroll = state.bagScroll - delta
        RefreshBag()
    end)
    ui.bagSlots = {}
    for i = 1, 100 do
        local col, row = (i - 1) % 10, floor((i - 1) / 10)
        local s = CreateFrame("Button", nil, grid)
        s:SetSize(52, 52)
        s:SetPoint("TOPLEFT", grid, "TOPLEFT", col * 58, -row * 58)
        local bg = s:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0, 0, 0, 0)
        H.Skin(s, "BtnSquare", 0.56)
        s.glow = s:CreateTexture(nil, "BACKGROUND", nil, 1)
        s.glow:SetAllPoints()
        s.glow:SetColorTexture(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3], 0.18)
        s.icon = s:CreateTexture(nil, "ARTWORK")
        s.icon:SetPoint("TOPLEFT", 8, -8)
        s.icon:SetPoint("BOTTOMRIGHT", -8, 8)
        s.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
        s.border = H.Border(s, 1, 1, 1, 0)
        s.count = H.Txt(s, F.CB, 12, { 1, 1, 1 }, "RIGHT")
        s.count:SetPoint("BOTTOMRIGHT", -3, 3)
        s.newBg = s:CreateTexture(nil, "OVERLAY")
        s.newBg:SetPoint("TOPLEFT", 2, -2)
        s.newBg:SetSize(32, 12)
        s.newBg:SetColorTexture(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 1)
        s.newTxt = H.Txt(s, F.CB, 9, { 0.10, 0.07, 0.02 }, "CENTER")
        s.newTxt:SetShadowOffset(0, 0)
        s.newTxt:SetPoint("CENTER", s.newBg, "CENTER", 0, 0)
        s.newTxt:SetText("NOVO")
        s:SetScript("OnEnter", function(self)
            if not (self.bag and self.link) then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetBagItem(self.bag, self.slot)
            GameTooltip:AddLine("Clique: receitas que usam este item", COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3])
            GameTooltip:Show()
        end)
        s:SetScript("OnLeave", function() GameTooltip:Hide() end)
        s:SetScript("OnClick", function(self)
            if not self.link then return end
            if IsModifiedClick and IsModifiedClick("CHATLINK") and ChatEdit_InsertLink then
                ChatEdit_InsertLink(self.link)
            elseif self.itemName and ui.searchBox then
                state.lane = nil
                ui.searchBox:SetText(self.itemName)
            end
        end)
        s:Hide()
        ui.bagSlots[i] = s
    end

    local hint = H.Txt(v, F.B, 12, COL_MUTED)
    hint:SetPoint("TOPLEFT", grid, "BOTTOMLEFT", 0, -6)
    hint:SetText("Clique num item para ver as receitas que o usam")
    ui.bagMoney = H.Txt(v, F.CB, 14, COL_CREAM, "RIGHT")
    ui.bagMoney:SetPoint("TOPRIGHT", grid, "BOTTOMRIGHT", -10, -6)
end

local function BuildAltar(art)
    local F = ui.fonts
    local panel = CreateFrame("Frame", nil, art)
    panel:SetPoint("TOPLEFT", art, "TOPLEFT", X_ALTAR, -104)
    panel:SetSize(W_ALTAR, 950)
    local sep = panel:CreateTexture(nil, "BORDER")
    sep:SetPoint("TOPLEFT", panel, "TOPLEFT", -22, 0)
    sep:SetSize(1, 940)
    sep:SetColorTexture(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 0.20)

    -- Abas ALTAR / MOCHILA
    local tabLine = panel:CreateTexture(nil, "BORDER")
    tabLine:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -34)
    tabLine:SetSize(W_ALTAR, 1)
    tabLine:SetColorTexture(COL_GOLD[1], COL_GOLD[2], COL_GOLD[3], 0.22)
    local function Tab(key, text, x)
        local t = CreateFrame("Button", nil, panel)
        t.key = key
        t.label = H.Txt(t, F.CB, 15, COL_MUTED)
        t.label:SetPoint("LEFT")
        t.label:SetText(text)
        t.count = H.Txt(t, F.B, 11, COL_GOLD)
        t.count:SetPoint("LEFT", t.label, "RIGHT", 8, 0)
        t:SetSize(t.label:GetStringWidth() + 70, 30)
        t:SetPoint("TOPLEFT", panel, "TOPLEFT", x, -2)
        t.underline = t:CreateTexture(nil, "OVERLAY")
        t.underline:SetPoint("BOTTOMLEFT", t, "BOTTOMLEFT", 0, -3)
        t.underline:SetSize(t.label:GetStringWidth(), 2)
        t.underline:SetColorTexture(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3], 1)
        t:SetScript("OnClick", function() ShowPanel(key) end)
        return t
    end
    ui.tabAltar = Tab("altar", "ALTAR", 0)
    ui.tabBag = Tab("bag", "MOCHILA", 110)

    local content = CreateFrame("Frame", nil, panel)
    content:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -52)
    content:SetSize(W_ALTAR, 700)
    BuildAltarView(content)
    BuildBagView(content)

    -- Barra de criação
    local prog = CreateFrame("Frame", nil, panel)
    prog:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -792)
    prog:SetSize(W_ALTAR, 40)
    ui.prog = prog
    ui.progLeft = H.Txt(prog, F.CB, 13, COL_CREAM)
    ui.progLeft:SetPoint("TOPLEFT")
    ui.progLeft:SetWidth(W_ALTAR - 170)
    ui.progRight = H.Txt(prog, F.B, 13, COL_AZAATH, "RIGHT")
    ui.progRight:SetPoint("TOPRIGHT")
    local pbg = prog:CreateTexture(nil, "BACKGROUND")
    pbg:SetPoint("TOPLEFT", prog, "TOPLEFT", 0, -20)
    pbg:SetSize(W_ALTAR, 20)
    pbg:SetColorTexture(0, 0, 0, 0)
    ui.progBg = pbg
    local pFrame = CreateFrame("Frame", nil, prog)
    pFrame:SetAllPoints(pbg)
    -- calha escura e opaca por baixo da moldura (a arte de fundo não vaza)
    local trough = pFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
    trough:SetPoint("TOPLEFT", 3, -3)
    trough:SetPoint("BOTTOMRIGHT", -3, 3)
    trough:SetColorTexture(0.015, 0.035, 0.05, 1)
    H.Skin(pFrame, "BarEmpty", 0.46)
    -- preenchimento e efeitos numa camada ACIMA da moldura (antes ficavam por
    -- baixo dela e pareciam apagados/transparentes)
    local layer = CreateFrame("Frame", nil, prog)
    layer:SetAllPoints(prog)
    layer:SetFrameLevel(pFrame:GetFrameLevel() + 2)
    ui.progLayer = layer
    -- preenchimento da arte: revela a textura (não estica) conforme o progresso
    ui.progFill = layer:CreateTexture(nil, "ARTWORK")
    ui.progFill:SetPoint("TOPLEFT", pbg, "TOPLEFT", 2, -2)
    ui.progFill:SetPoint("BOTTOMLEFT", pbg, "BOTTOMLEFT", 2, 2)
    ui.progFill:SetWidth(1)
    H.AtlasTex(ui.progFill, "BarFill")
    H.BuildFX(layer, pbg, prog)
    -- fila: um losango por unidade (até 30), aceso quando fica pronto
    ui.pips = {}
    for i = 1, 30 do
        local glow = layer:CreateTexture(nil, "OVERLAY", nil, 1)
        glow:SetTexture(MEDIA_ROOT .. "Glow")
        glow:SetBlendMode("ADD")
        glow:SetVertexColor(COL_AZAATH[1], COL_AZAATH[2], COL_AZAATH[3])
        glow:SetSize(24, 24)
        local d = layer:CreateTexture(nil, "OVERLAY", nil, 2)
        d:SetTexture(MEDIA_ROOT .. "Diamond")
        d:SetSize(11, 11)
        glow:SetPoint("CENTER", d, "CENTER")
        d:Hide(); glow:Hide()
        ui.pips[i] = { tex = d, glow = glow, pop = 0 }
    end
    prog:SetScript("OnUpdate", function(_, elapsed)
        UpdateProgress()
        H.UpdateFX(elapsed)
    end)

    -- Linha de ações
    local act = CreateFrame("Frame", nil, panel)
    act:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -852)
    act:SetSize(W_ALTAR, 46)

    local minus = H.Pill(act, 38, 46, "-", F.CB, 18, COL_CREAM, "BtnDark", 0.5)
    minus:SetPoint("LEFT")
    minus:SetScript("OnClick", function()
        state.craftQty = max(1, state.craftQty - 1)
        RefreshAltar(); RefreshCraftBar()
    end)
    local qbox = H.Panel(act, 46, 46, "BtnSquare", 0.5)
    qbox:EnableMouse(false)
    qbox:SetPoint("LEFT", minus, "RIGHT", 0, 0)
    ui.qtyLabel = H.Txt(qbox, F.CB, 16, COL_GOLD, "CENTER")
    ui.qtyLabel:SetPoint("CENTER")
    local plus = H.Pill(act, 38, 46, "+", F.CB, 18, COL_CREAM, "BtnDark", 0.5)
    plus:SetPoint("LEFT", qbox, "RIGHT", 0, 0)
    plus:SetScript("OnClick", function()
        state.craftQty = min(999, state.craftQty + 1)
        RefreshAltar(); RefreshCraftBar()
    end)
    local maxB = H.Pill(act, 54, 46, "MÁX", F.B, 12, COL_AZAATH, "BtnDark", 0.5)
    maxB:SetPoint("LEFT", plus, "RIGHT", 8, 0)
    maxB:SetScript("OnClick", function()
        local rec = H.SelectedRec()
        if rec then
            state.craftQty = max(1, rec.numAvail or 1)
            RefreshAltar(); RefreshCraftBar()
        end
    end)

    local link = H.Pill(act, 58, 46, "LINK", F.B, 12, COL_CREAM, "BtnDark", 0.5)
    link:SetPoint("RIGHT")
    link:SetScript("OnClick", function()
        local rec = H.SelectedRec()
        local l = rec and (rec.recipeLink or rec.link)
        if l and ChatEdit_InsertLink then ChatEdit_InsertLink(l) end
    end)
    local fav = H.Pill(act, 96, 46, "FAVORITAR", F.B, 11, COL_MUTED, "BtnDark", 0.5)
    fav:SetPoint("RIGHT", link, "LEFT", -8, 0)
    fav:SetScript("OnClick", function()
        if state.selectedRecipe then
            ToggleFavorite(state.selectedRecipe)
            M:RefreshView()
        end
    end)
    ui.favBtn = fav

    -- PARAR: /stopcasting via overlay seguro em UIParent + fim da repetição do ofício
    local stop = CreateFrame("Button", "AzaathUIProfStop", act)
    stop:SetSize(92, 46)
    stop:SetPoint("RIGHT", fav, "LEFT", -8, 0)
    stop:RegisterForClicks("LeftButtonUp")
    H.Skin(stop, "BtnRed", 0.5)
    local sq = stop:CreateTexture(nil, "ARTWORK")
    sq:SetSize(9, 9)
    sq:SetPoint("LEFT", 14, 0)
    sq:SetColorTexture(1, 0.55, 0.48, 1)
    local stxt = H.Txt(stop, F.CB, 13, { 1, 0.62, 0.55 }, "LEFT")
    stxt:SetPoint("LEFT", sq, "RIGHT", 8, 0)
    stxt:SetText("PARAR")
    stop:SetScript("OnEnter", function(self) AttachSecure(self, "stop") end)
    stop:SetScript("OnHide", function(self)
        if ui.secureOverlay and ui.secureOverlay.owner == self then DetachSecure() end
    end)
    stop:SetScript("OnClick", function()
        if SpellStopCasting and not (InCombatLockdown and InCombatLockdown()) then pcall(SpellStopCasting) end
        StopCraftAction()
    end)
    ui.stopBtn = stop

    local craft = H.Pill(act, 10, 46, "CRIAR", F.C, 17, { 0.10, 0.07, 0.02 }, "BtnGold", 0.47)
    craft:SetPoint("LEFT", maxB, "RIGHT", 10, 0)
    craft:SetPoint("RIGHT", stop, "LEFT", -8, 0)
    craft.label:SetShadowOffset(0, 0)
    craft:SetScript("OnClick", function()
        if not state.craft.active then DoCraftSelected() end
    end)
    ui.craftBtn = craft
end

function M:BuildPage(pg, cw, ch)
    if pg.professions then return end
    local media = Azaath.media
    ui.fonts = {
        C  = media.fontCinzel or media.fontTitleB,
        CB = media.fontTitleB,
        B  = media.fontBody or media.font or GameFontNormal:GetFont(),
    }

    local root = pg:GetParent() and pg:GetParent():GetParent() or UIParent
    local art = CreateFrame("Frame", nil, pg)
    art:SetSize(ART_W, ART_H)
    art:SetPoint("CENTER", root, "CENTER", 0, 0)
    local function Fit()
        local w, h = root:GetWidth(), root:GetHeight()
        if not (w and h and w > 0 and h > 0) then w, h = UIParent:GetWidth(), UIParent:GetHeight() end
        art:SetScale(max(w / ART_W, h / ART_H))
    end
    Fit()
    pg:HookScript("OnShow", Fit)
    pg:HookScript("OnShow", function() state.profScanDirty = true end)

    -- Arte de fundo da oficina (pedestal rúnico) mantida
    local bg = art:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetTexture(SHEET_MEDIA .. "ProfessionsBG")
    bg:SetTexCoord(0, ART_W / 2048, 0, ART_H / 2048)
    bg:SetAllPoints(art)

    BuildSpine(art)
    BuildMain(art)
    BuildAltar(art)
    ShowPanel("altar")

    pg:HookScript("OnHide", function()
        DetachSecure()
        if state.craft.active or (InCombatLockdown and InCombatLockdown()) then return end
        if state.activeMode == "modern" and _G.C_TradeSkillUI and _G.C_TradeSkillUI.CloseTradeSkill then
            pcall(_G.C_TradeSkillUI.CloseTradeSkill)
        elseif state.activeMode == "tradeskill" and CloseTradeSkill then
            pcall(CloseTradeSkill)
        elseif state.activeMode == "craft" and CloseCraft then
            pcall(CloseCraft)
        end
    end)

    ui.art = art
    pg.professions = true
end

--------------------------------------------------------------------------------
-- Atalho (Tecla K / TOGGLESKILLS / TOGGLECHARACTER4) e Eventos
--------------------------------------------------------------------------------
function M:Toggle()
    local sheet = Azaath:GetModule("Sheet")
    if sheet and sheet.Toggle then sheet:Toggle("professions") end
end

function M:Open()
    local sheet = Azaath:GetModule("Sheet")
    if sheet and sheet.Open then sheet:Open("professions") end
end

local function UpdateBinding()
    local k1, k2 = GetBindingKey("TOGGLESKILLS")
    local k3, k4 = GetBindingKey("TOGGLECHARACTER4")
    local keys = {}
    for _, k in ipairs({ k1, k2, k3, k4 }) do
        if k and k ~= "" then tinsert(keys, k) end
    end
    if #keys == 0 then tinsert(keys, "K") end
    local sig = table.concat(keys, ",")
    if sig == lastBindingSignature then return end
    Azaath:RunOutOfCombat(function()
        lastBindingSignature = sig
        ClearOverrideBindings(bindOwner)
        for _, k in ipairs(keys) do
            SetOverrideBindingClick(bindOwner, false, k, "AzaathUIProfessionsToggle", "LeftButton")
        end
    end)
end

local function HookBlizzProfFrames()
    if _G.ProfessionsFrame and not _G.ProfessionsFrame._azHooked then
        _G.ProfessionsFrame._azHooked = true
        _G.ProfessionsFrame:HookScript("OnShow", function(f)
            if M.db and M.db.enabled then
                SuppressBlizzFrame(f)
                ScanTradeSkill()
                M:Open()
            end
        end)
    end
    if _G.TradeSkillFrame and not _G.TradeSkillFrame._azHooked then
        _G.TradeSkillFrame._azHooked = true
        _G.TradeSkillFrame:HookScript("OnShow", function(f)
            if M.db and M.db.enabled then
                SuppressBlizzFrame(f)
                ScanTradeSkill()
                M:Open()
            end
        end)
    end
end

local function IsProfessionInteraction(interactionType)
    local PT = _G.Enum and _G.Enum.PlayerInteractionType
    if not (PT and interactionType) then return false end
    return (PT.Professions and interactionType == PT.Professions)
        or (PT.TradeSkill and interactionType == PT.TradeSkill)
end

events:SetScript("OnEvent", function(_, event, arg1)
    if event == "UPDATE_BINDINGS" then
        UpdateBinding()
        return
    elseif event == "PLAYER_REGEN_DISABLED" then
        DetachSecure()
        return
    elseif event == "PLAYER_REGEN_ENABLED" then
        local o = ui.secureOverlay
        if o and o:IsShown() and (not o.owner or not o.owner:IsVisible() or not o:IsMouseOver()) then
            DetachSecure()
        end
        return
    end
    if not (M.db and M.db.enabled) then return end

    if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_SUCCEEDED"
       or event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        if arg1 == "player" and ui.art then M:OnPlayerCast(event) end
        return
    end

    -- Durante a criação o jogo dispara vários BAG_UPDATE/TRADE_SKILL_UPDATE por item;
    -- tratar cada um na hora relia o ofício e remontava a aba várias vezes no mesmo
    -- quadro (trava a cada item). Agora viram uma única atualização agrupada.
    if event == "TRADE_SKILL_UPDATE" or event == "TRADE_SKILL_LIST_UPDATE"
       or event == "TRADE_SKILL_DATA_SOURCE_CHANGED" or event == "CRAFT_UPDATE" then
        SuppressBlizzFrame(_G.TradeSkillFrame)
        SuppressBlizzFrame(_G.ProfessionsFrame)
        SuppressBlizzFrame(_G.CraftFrame)
        M:QueueRefresh(event == "CRAFT_UPDATE" and "craft" or "tradeskill")
        return
    elseif event == "BAG_UPDATE" or event == "SKILL_LINES_CHANGED" then
        if event == "SKILL_LINES_CHANGED" then state.profScanDirty = true end
        if ui.art and ui.art:IsVisible() then M:QueueRefresh(true) end
        return
    end

    if event == "TRADE_SKILL_SHOW" then
        SuppressBlizzFrame(_G.TradeSkillFrame)
        SuppressBlizzFrame(_G.ProfessionsFrame)
        ScanTradeSkill()
        if #state.liveRecipes == 0 then
            local tsLine = GetTradeSkillLine and (GetTradeSkillLine()) or "nil"
            local tsNum = GetNumTradeSkills and (GetNumTradeSkills()) or "nil"
            local ctsIds = (_G.C_TradeSkillUI and _G.C_TradeSkillUI.GetAllRecipeIDs) and #(_G.C_TradeSkillUI.GetAllRecipeIDs() or {}) or "nil"
            print(format("|cffe3c78b[Azaath Ofícios]|r %s: GetTradeSkillLine=%s, GetNumTradeSkills=%s, C_TradeSkillUI=%s",
                tostring(event), tostring(tsLine), tostring(tsNum), tostring(ctsIds)))
        end
        if event == "TRADE_SKILL_SHOW" then
            M:Open()
        else
            M:Refresh()
        end
    elseif event == "CRAFT_SHOW" then
        SuppressBlizzFrame(_G.CraftFrame)
        ScanCraft()
        if event == "CRAFT_SHOW" then
            M:Open()
        else
            M:Refresh()
        end
    elseif event == "PLAYER_INTERACTION_MANAGER_FRAME_SHOW" then
        if not IsProfessionInteraction(arg1) then return end
        SuppressBlizzFrame(_G.TradeSkillFrame)
        SuppressBlizzFrame(_G.ProfessionsFrame)
        if ScanTradeSkill() then
            M:Open()
        end
    elseif event == "ADDON_LOADED" then
        HookBlizzProfFrames()
    elseif event == "TRADE_SKILL_CLOSE" or event == "CRAFT_CLOSE"
       or (event == "PLAYER_INTERACTION_MANAGER_FRAME_HIDE" and IsProfessionInteraction(arg1)) then
        if state.activeProf then
            LoadFromCache(state.activeProf)
            M:Refresh()
        end
    end
end)

function M:OnInitialize()
    self.db = Azaath.db and Azaath.db.professions
end

function M:OnEnable()
    if not (self.db and self.db.enabled) then return end
    toggleButton = CreateFrame("Button", "AzaathUIProfessionsToggle", UIParent)
    toggleButton:RegisterForClicks("LeftButtonUp")
    toggleButton:SetScript("OnClick", function() M:Toggle() end)
    bindOwner = CreateFrame("Frame")
    UpdateBinding()
    HookBlizzProfFrames()

    for _, e in ipairs({
        "UPDATE_BINDINGS",
        "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "TRADE_SKILL_SHOW", "TRADE_SKILL_UPDATE", "TRADE_SKILL_CLOSE",
        "TRADE_SKILL_DATA_SOURCE_CHANGED", "TRADE_SKILL_LIST_UPDATE",
        "PLAYER_INTERACTION_MANAGER_FRAME_SHOW", "PLAYER_INTERACTION_MANAGER_FRAME_HIDE",
        "ADDON_LOADED",
        "CRAFT_SHOW", "CRAFT_UPDATE", "CRAFT_CLOSE",
        "BAG_UPDATE", "SKILL_LINES_CHANGED",
        "UNIT_SPELLCAST_START", "UNIT_SPELLCAST_SUCCEEDED",
        "UNIT_SPELLCAST_INTERRUPTED", "UNIT_SPELLCAST_FAILED",
    }) do
        Azaath.SafeRegister(events, e)
    end
end
