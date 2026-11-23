--[[----------------------------------------------------------------------------
    AzaathUI - Data/LootCatalog.lua
    Catálogo curado de itens especiais, peixes, tesouros, coletas raras e
    marcos de profissão para o WoW Forever (16001).
    Baseado no catálogo MIT do LootDopamine (Dopamine v0.7.4).
------------------------------------------------------------------------------]]

local _, Azaath = ...

local C = {}
Azaath.LootCatalog = C

local ipairs, pairs = ipairs, pairs

--------------------------------------------------------------------------------
-- Catálogo semente de Pesca
--------------------------------------------------------------------------------
local catalogue, fishByID, fishByName = {}, {}, {}

local function AddFish(name, tier, id, weight, family, category)
    local entry = {
        name = name,
        tier = tier or 1,
        id = id,
        weight = weight,
        family = family,
        category = category or "fish",
    }
    catalogue[#catalogue + 1] = entry
    fishByName[name:lower()] = entry
    if id then fishByID[id] = entry end
end

local BASICS = {
    { "Raw Brilliant Smallfish", 1, 6291 },   { "Raw Longjaw Mud Snapper", 1, 6289 },
    { "Raw Slitherskin Mackerel", 1, 6303 },  { "Raw Loch Frenzy", 1, 6317 },
    { "Raw Rainbow Fin Albacore", 2, 6361 },  { "Raw Bristle Whisker Catfish", 2, 6308 },
    { "Oily Blackmouth", 2, 6358 },           { "Firefin Snapper", 2, 6359 },
    { "Raw Rockscale Cod", 3, 6362 },         { "Raw Mithril Head Trout", 3, 8365 },
    { "Raw Spotted Yellowtail", 3, 4603 },    { "Stonescale Eel", 4, 13422 },
    { "Raw Redgill", 4, 13758 },              { "Raw Nightfin Snapper", 4, 13759 },
    { "Raw Sunscale Salmon", 4, 13760 },      { "Winter Squid", 4, 13755 },
    { "Raw Summer Bass", 4, 13756 },          { "Lightning Eel", 5, 13757 },
    { "Raw Whitescale Salmon", 5, 13889 },    { "Darkclaw Lobster", 5, 13888 },
    { "Large Raw Mightfish", 5, 13893 },      { "Raw Glossy Mightfish", 5, 13754 },
    { "Raw Spinefin Halibut", 5, 8959 },      { "Plated Armorfish", 5, 248780 },
}
for _, item in ipairs(BASICS) do
    AddFish(item[1], item[2], item[3])
end

local TROPHIES = {
    { "Mud Snapper", 1, { 10, 12, 15 } },
    { "Catfish", 2, { 17, 19, 22, 26, 32 } },
    { "Redgill", 4, { 34, 37, 42, 45, 49, 52 } },
    { "Grouper", 4, { 40, 47, 53, 59, 68 } },
    { "Salmon", 5, { 15, 18, 22, 25, 29, 32 } },
    { "Mightfish", 5, { 70, 85, 92, 103 } },
    { "Lobster", 5, { 7, 9, 22 } },
}

local TROPHY_IDS = {
    [6311]  = { weight = 22, family = "Catfish" },
    [13885] = { weight = 34, family = "Redgill" },
    [13886] = { weight = 37, family = "Redgill" },
    [6295]  = { weight = 15, family = "Mud Snapper" },
}
C.trophyByID = TROPHY_IDS

for _, row in ipairs(TROPHIES) do
    for _, lb in ipairs(row[3]) do
        local id = nil
        for itemID, info in pairs(TROPHY_IDS) do
            if info.family == row[1] and info.weight == lb then
                id = itemID
                break
            end
        end
        AddFish(lb .. " Pound " .. row[1], row[2] + (lb / 1000), id, lb, row[1], "trophy")
    end
end

local SPECIAL = {
    { "Deviate Fish", 2, 6522 },
    { "Whimsyfin", 4, 251524 },
    { "Brownell's Blue Striped Racer", 4, 19803 },
    { "Pale Ghoulfish", 4, 19804 },
    { "Keefer's Angelfish", 4, 19805 },
    { "Dezian Queenfish", 4, 19806 },
}
for _, item in ipairs(SPECIAL) do
    AddFish(item[1], item[2], item[3])
end

local BLOATED = {
    { "Bloated Brilliant Smallfish", 1, 6643 },
    { "Bloated Mud Snapper", 1, 6645 },
    { "Bloated Bristle Whisker Catfish", 2, 6647 },
    { "Bloated Mithril Head Trout", 3, 8366 },
    { "Bloated Redgill", 4, 13881 },
    { "Bloated Whitescale Salmon", 5, 13891 },
    { "Bloated Oily Blackmouth", 2, 21162 },
    { "Bloated Firefin Snapper", 2, 21163 },
    { "Bloated Rockscale Cod", 3, 21164 },
    { "Bloated Glossy Mightfish", 5, 21243 },
}
C.bloatedFish = {}
C.bloatedSpeciesCount = #BLOATED
for _, item in ipairs(BLOATED) do
    AddFish(item[1], item[2], item[3], nil, nil, "bloated")
    C.bloatedFish[item[3]] = item[1]
end

C.fishCatalogue = catalogue
C.fishByID = fishByID
C.fishByName = fishByName

C.specialFish = {
    [6522]   = "Deviate Fish",
    [251524] = "Whimsyfin",
    [19803]  = "Brownell's Blue Striped Racer",
    [19804]  = "Pale Ghoulfish",
    [19805]  = "Keefer's Angelfish",
    [19806]  = "Dezian Queenfish",
}
for itemID, fishName in pairs(C.bloatedFish) do
    C.specialFish[itemID] = fishName
end

C.specialTreasure = {
    [20708] = "Tightly Sealed Trunk",
    [21113] = "Watertight Trunk",
    [21150] = "Iron Bound Trunk",
    [21228] = "Mithril Bound Trunk",
    [6351]  = "Dented Crate",
    [6352]  = "Waterlogged Crate",
    [6353]  = "Small Chest",
    [6357]  = "Sealed Crate",
    [13874] = "Heavy Crate",
}

C.fishingPotions = {
    [929]  = "Healing Potion",
    [1710] = "Greater Healing Potion",
    [3827] = "Mana Potion",
}

C.fishingCasts = { [7620] = true, [7731] = true, [7732] = true, [18248] = true }

--------------------------------------------------------------------------------
-- Descobertas raras de coleta (Clássico + WoW Forever)
--------------------------------------------------------------------------------
C.specialMining = {
    [12363]  = "Arcane Crystal",
    [11382]  = "Blood of the Mountain",
    [12361]  = "Blue Sapphire",
    [12364]  = "Huge Emerald",
    [12799]  = "Large Opal",
    [12800]  = "Azerothian Diamond",
    [248819] = "Fel Crystal",
    [248820] = "Torbernite",
    [249391] = "Pyrite",
    [249425] = "Bauxite",
    [249426] = "Pitchblende",
}

C.specialHerbs = {
    [13468]  = "Black Lotus",
    [8845]   = "Ghost Mushroom",
    [8153]   = "Wildvine",
    [19726]  = "Bloodvine",
    [248822] = "Death Lotus",
    [249399] = "Frilled Lichen",
    [249424] = "Rosecap",
    [249274] = "Stranglevine",
    [268418] = "Scarce Herb Seeds",
}

C.specialSkinning = {
    [8171]   = "Rugged Hide",
    [15417]  = "Devilsaur Leather",
    [17012]  = "Core Leather",
    [12607]  = "Brilliant Chromatic Scale",
    [12731]  = "Pristine Hide of the Beast",
    [19767]  = "Primal Bat Leather",
    [19768]  = "Primal Tiger Leather",
    [248824] = "Fel Hide",
    [249427] = "Pristine Leather",
    [249428] = "Pristine Hide",
    [249429] = "Pristine Scale",
}

C.rareRecipes = {
    [6661]  = "Recipe: Savory Deviate Delight",
    [16044] = "Schematic: Lifelike Mechanical Toad",
}

C.rareCollectibles = {
    [13335] = "Deathcharger's Reins",
    [8494]  = "Parrot Cage (Hyacinth Macaw)",
    [8498]  = "Tiny Emerald Whelpling",
    [8499]  = "Tiny Crimson Whelpling",
    [10822] = "Dark Whelpling",
    [11474] = "Sprite Darter Egg",
    [20769] = "Disgusting Oozeling",
    [19872] = "Swift Razzashi Raptor",
    [19902] = "Swift Zulian Tiger",
}

C.companionItems = {
    [8494] = true, [8498] = true, [8499] = true,
    [10822] = true, [11474] = true, [20769] = true,
}

C.bagSlots = {
    [4238]  = 6,
    [4240]  = 8,
    [4245]  = 10,
    [10050] = 12,
    [14046] = 14,
    [14156] = 20,
}

--------------------------------------------------------------------------------
-- Marcos de Profissão (75 / 150 / 225 / 300)
--------------------------------------------------------------------------------
C.milestones = { 75, 150, 225, 300 }

C.milestoneRanks = {
    [75]  = { pt = "Aprendiz",     en = "Apprentice" },
    [150] = { pt = "Artífice",     en = "Journeyman" },
    [225] = { pt = "Especialista", en = "Expert" },
    [300] = { pt = "Artesão",      en = "Artisan" },
}

C.skillTypes = {
    [356] = { pt = "Pesca",              en = "Fishing",        kind = "skill_fishing",        icon = "Interface\\Icons\\Trade_Fishing" },
    [186] = { pt = "Mineração",          en = "Mining",         kind = "skill_mining",         icon = "Interface\\Icons\\Trade_Mining" },
    [182] = { pt = "Herborismo",         en = "Herbalism",      kind = "skill_herb",           icon = "Interface\\Icons\\Trade_Herbalism" },
    [393] = { pt = "Esfolamento",        en = "Skinning",       kind = "skill_skinning",       icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01" },
    [185] = { pt = "Culinária",          en = "Cooking",        kind = "skill_cooking",        icon = "Interface\\Icons\\INV_Misc_Food_15" },
    [129] = { pt = "Primeiros Socorros", en = "First Aid",      kind = "skill_firstaid",       icon = "Interface\\Icons\\Spell_Holy_SealOfSacrifice" },
    [171] = { pt = "Alquimia",           en = "Alchemy",        kind = "skill_alchemy",        icon = "Interface\\Icons\\Trade_Alchemy" },
    [164] = { pt = "Ferraria",           en = "Blacksmithing",  kind = "skill_blacksmithing",  icon = "Interface\\Icons\\Trade_BlackSmithing" },
    [333] = { pt = "Encantamento",       en = "Enchanting",     kind = "skill_enchanting",     icon = "Interface\\Icons\\Trade_Engraving" },
    [202] = { pt = "Engenharia",         en = "Engineering",    kind = "skill_engineering",    icon = "Interface\\Icons\\Trade_Engineering" },
    [165] = { pt = "Couraria",           en = "Leatherworking", kind = "skill_leatherworking", icon = "Interface\\Icons\\Trade_LeatherWorking" },
    [197] = { pt = "Alfaiataria",        en = "Tailoring",      kind = "skill_tailoring",      icon = "Interface\\Icons\\Trade_Tailoring" },
}
