--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ItemCategories.lua
    Árvore de categorias dos itens (como a Casa de Leilões): Armas > Uma mão > Espadas,
    Armaduras > Placa > Cabeça, Consumíveis > Comida > Força...
      * Classify(e) devolve as folhas de um item a partir de classe/subclasse/encaixe do cliente
        e da etiqueta de consumível gerada (e.tag: "food:sta+spi", "pot:hp"...).
      * Cada nó tem chave em caminho ("weapon.1h.sword"); um item conta em todos os ancestrais.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local C = {}
Azaath.ItemCats = C

local function N(key, pt, en, kids) return { key = key, pt = pt, en = en, kids = kids } end

local SLOTS = function(p)
    return {
        N(p .. ".head", "Cabeça", "Head"), N(p .. ".shoulder", "Ombros", "Shoulder"),
        N(p .. ".chest", "Torso", "Chest"), N(p .. ".wrist", "Pulsos", "Wrist"),
        N(p .. ".hands", "Mãos", "Hands"), N(p .. ".waist", "Cintura", "Waist"),
        N(p .. ".legs", "Pernas", "Legs"), N(p .. ".feet", "Pés", "Feet"),
    }
end

C.TREE = {
    N("weapon", "Armas", "Weapons", {
        N("weapon.1h", "Uma mão", "One-Handed", {
            N("weapon.1h.sword", "Espadas", "Swords"), N("weapon.1h.axe", "Machados", "Axes"),
            N("weapon.1h.mace", "Maças", "Maces"), N("weapon.1h.dagger", "Adagas", "Daggers"),
            N("weapon.1h.fist", "Armas de punho", "Fist Weapons"),
        }),
        N("weapon.2h", "Duas mãos", "Two-Handed", {
            N("weapon.2h.sword", "Espadas", "Swords"), N("weapon.2h.axe", "Machados", "Axes"),
            N("weapon.2h.mace", "Maças", "Maces"), N("weapon.2h.staff", "Cajados", "Staves"),
            N("weapon.2h.polearm", "Armas de haste", "Polearms"),
        }),
        N("weapon.ranged", "À distância", "Ranged", {
            N("weapon.ranged.bow", "Arcos", "Bows"), N("weapon.ranged.gun", "Armas de fogo", "Guns"),
            N("weapon.ranged.crossbow", "Bestas", "Crossbows"), N("weapon.ranged.wand", "Varinhas", "Wands"),
            N("weapon.ranged.thrown", "Arremesso", "Thrown"),
        }),
        N("weapon.other", "Outras", "Other", {
            N("weapon.other.fishing", "Varas de pescar", "Fishing Poles"), N("weapon.other.misc", "Diversas", "Miscellaneous"),
        }),
    }),
    N("armor", "Armaduras", "Armor", {
        N("armor.plate", "Placa", "Plate", SLOTS("armor.plate")),
        N("armor.mail", "Malha", "Mail", SLOTS("armor.mail")),
        N("armor.leather", "Couro", "Leather", SLOTS("armor.leather")),
        N("armor.cloth", "Tecido", "Cloth", SLOTS("armor.cloth")),
    }),
    N("acc", "Acessórios", "Accessories", {
        N("acc.neck", "Pescoço", "Neck"), N("acc.finger", "Anéis", "Rings"),
        N("acc.trinket", "Berloques", "Trinkets"), N("acc.back", "Capas", "Cloaks"),
        N("acc.offhand", "Mão secundária", "Off Hand"), N("acc.shield", "Escudos", "Shields"),
        N("acc.relic", "Relíquias", "Relics"), N("acc.cosmetic", "Camisas e tabardos", "Shirts & Tabards"),
    }),
    N("cons", "Consumíveis", "Consumables", {
        N("cons.food", "Comida", "Food", {
            N("cons.food.str", "Força", "Strength"), N("cons.food.agi", "Agilidade", "Agility"),
            N("cons.food.sta", "Vigor", "Stamina"), N("cons.food.int", "Intelecto", "Intellect"),
            N("cons.food.spi", "Espírito", "Spirit"), N("cons.food.regen", "Regeneração", "Regeneration"),
            N("cons.food.plain", "Sem bônus", "No Bonus"),
        }),
        N("cons.drink", "Bebida", "Drink"),
        N("cons.pot", "Poções", "Potions", {
            N("cons.pot.hp", "Vida", "Health"), N("cons.pot.mana", "Mana", "Mana"), N("cons.pot.other", "Outras", "Other"),
        }),
        N("cons.elixir", "Elixires", "Elixirs"), N("cons.flask", "Frascos", "Flasks"),
        N("cons.scroll", "Pergaminhos", "Scrolls"), N("cons.bandage", "Ataduras", "Bandages"),
        N("cons.enh", "Melhorias de item", "Item Enhancements"), N("cons.other", "Outros", "Other"),
    }),
    N("recipe", "Receitas", "Recipes", {
        N("recipe.tailoring", "Alfaiataria", "Tailoring"), N("recipe.leather", "Couraria", "Leatherworking"),
        N("recipe.blacksmith", "Ferraria", "Blacksmithing"), N("recipe.engineering", "Engenharia", "Engineering"),
        N("recipe.alchemy", "Alquimia", "Alchemy"), N("recipe.enchanting", "Encantamento", "Enchanting"),
        N("recipe.cooking", "Culinária", "Cooking"), N("recipe.firstaid", "Primeiros Socorros", "First Aid"),
        N("recipe.fishing", "Pesca", "Fishing"), N("recipe.book", "Livros", "Books"),
    }),
    N("mats", "Materiais", "Trade Goods", {
        N("mats.cloth", "Tecido", "Cloth"), N("mats.leather", "Couro", "Leather"),
        N("mats.metal", "Metal e pedra", "Metal & Stone"), N("mats.herb", "Ervas", "Herbs"),
        N("mats.meat", "Carnes", "Meat"), N("mats.elemental", "Elementais", "Elemental"),
        N("mats.enchanting", "Encantamento", "Enchanting"), N("mats.parts", "Peças e engenhocas", "Parts & Devices"),
        N("mats.other", "Outros", "Other"),
    }),
    N("container", "Bolsas", "Containers"),
    N("quest", "Missão", "Quest"),
    N("key", "Chaves", "Keys"),
    N("misc", "Diversos", "Miscellaneous", {
        N("misc.mount", "Montarias", "Mounts"), N("misc.pet", "Mascotes", "Pets"),
        N("misc.reagent", "Reagentes", "Reagents"), N("misc.ammo", "Munição", "Projectiles"),
        N("misc.holiday", "Eventos", "Holiday"), N("misc.junk", "Sucata", "Junk"), N("misc.other", "Outros", "Other"),
    }),
}

-- índice por chave e pai de cada nó
C.byKey = {}
local function Index(list, parent, depth)
    for _, n in ipairs(list) do
        n.parent, n.depth = parent, depth
        C.byKey[n.key] = n
        if n.kids then Index(n.kids, n, depth + 1) end
    end
end
Index(C.TREE, nil, 0)

local W1 = { [0] = "axe", [4] = "mace", [7] = "sword", [15] = "dagger", [13] = "fist" }
local W2 = { [1] = "axe", [5] = "mace", [8] = "sword", [10] = "staff", [6] = "polearm" }
local WR = { [2] = "bow", [3] = "gun", [18] = "crossbow", [19] = "wand", [16] = "thrown" }
local ARMOR = { [1] = "cloth", [2] = "leather", [3] = "mail", [4] = "plate" }
local SLOT = { [1] = "head", [3] = "shoulder", [5] = "chest", [20] = "chest", [9] = "wrist", [10] = "hands",
    [6] = "waist", [7] = "legs", [8] = "feet" }
local RECIPE = { [1] = "leather", [2] = "tailoring", [3] = "engineering", [4] = "blacksmith", [5] = "cooking",
    [6] = "alchemy", [7] = "firstaid", [8] = "enchanting", [9] = "fishing", [0] = "book" }
local MATS = { [5] = "cloth", [6] = "leather", [7] = "metal", [9] = "herb", [8] = "meat", [10] = "elemental",
    [12] = "enchanting", [1] = "parts", [2] = "parts", [3] = "parts" }
local MISC = { [5] = "mount", [2] = "pet", [1] = "reagent", [3] = "holiday", [0] = "junk" }

-- folhas (chaves) de um item; vazio = sem categoria
function C.Classify(e)
    local cid, sc, inv, tag = e.classID or 0, e.subclassID or 0, e.invType or 0, e.tag or ""
    if cid == 2 then
        if W1[sc] then return { "weapon.1h." .. W1[sc] } end
        if W2[sc] then return { "weapon.2h." .. W2[sc] } end
        if WR[sc] then return { "weapon.ranged." .. WR[sc] } end
        return { sc == 20 and "weapon.other.fishing" or "weapon.other.misc" }
    elseif cid == 4 then
        if inv == 2 then return { "acc.neck" } end
        if inv == 11 then return { "acc.finger" } end
        if inv == 12 then return { "acc.trinket" } end
        if inv == 16 then return { "acc.back" } end
        if inv == 14 or sc == 6 then return { "acc.shield" } end
        if inv == 23 or inv == 22 then return { "acc.offhand" } end
        if inv == 28 or sc == 7 or sc == 8 or sc == 9 then return { "acc.relic" } end
        if inv == 4 or inv == 19 then return { "acc.cosmetic" } end
        if ARMOR[sc] and SLOT[inv] then return { "armor." .. ARMOR[sc] .. "." .. SLOT[inv] } end
        if ARMOR[sc] then return { "armor." .. ARMOR[sc] } end
        return { "acc.cosmetic" }
    elseif cid == 0 then
        local food = tag:match("^food:(.+)$")
        if food then
            local out = {}
            for k in food:gmatch("[^+]+") do out[#out + 1] = "cons.food." .. k end
            return out
        end
        if tag == "drink" then return { "cons.drink" } end
        local pot = tag:match("^pot:(.+)$")
        if pot then return { "cons.pot." .. pot } end
        if tag ~= "" and C.byKey["cons." .. tag] then return { "cons." .. tag } end
        return { "cons.other" }
    elseif cid == 9 then
        return { "recipe." .. (RECIPE[sc] or "book") }
    elseif cid == 7 then
        return { "mats." .. (MATS[sc] or "other") }
    elseif cid == 1 or cid == 11 then
        return { "container" }
    elseif cid == 12 then
        return { "quest" }
    elseif cid == 13 then
        return { "key" }
    elseif cid == 5 then
        return { "misc.reagent" }
    elseif cid == 6 then
        return { "misc.ammo" }
    elseif cid == 15 then
        return { "misc." .. (MISC[sc] or "other") }
    end
    return { "misc.other" }
end

-- conjunto de chaves do item (folhas + todos os ancestrais), guardado no item
function C.Keys(e)
    if e.catKeys then return e.catKeys end
    local set = {}
    for _, leaf in ipairs(C.Classify(e)) do
        local n = C.byKey[leaf]
        while n do set[n.key] = true; n = n.parent end
    end
    e.catKeys = set
    return set
end

function C.Label(node, pt)
    if not node then return "" end
    return pt and node.pt or node.en
end
