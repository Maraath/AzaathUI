--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ItemCard.lua
    Card de item no estilo New World: ao passar o mouse num item, a tooltip da
    Blizzard fica invisível (alpha 0, mas continua viva e posicionada) e o card
    é desenhado por cima, ocupando o mesmo canto de ancoragem.

      cabeçalho  papel tingido na cor da raridade + ícone + nome/raridade/tipo,
                 fagulhas subindo (quantidade pela raridade)
      número     nível do item (ícone hexagonal)
      base       armadura, dano, velocidade, DPS, bloqueio
      atributos  +Força, +Vigor, resistências...
      efeitos    Equipar/Usar/Chance ao acertar, encantamento, engastes, conjunto
      descrição  texto entre aspas
      rodapé     vínculo, único, demais linhas, durabilidade, requisitos, venda

    Tudo é lido das linhas que o próprio jogo pôs na tooltip (texto e cor),
    classificado pelas strings globais do cliente (funciona em qualquer idioma).
    Linhas que não reconhecemos (outros addons) vão no fim, com a cor original.
    Só HookScript/hook de dados e SetAlpha: nada é gravado em frames da Blizzard.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("ItemCard")

local _G = _G
local math, string, ipairs, pairs, type, tonumber = math, string, ipairs, pairs, type, tonumber
local floor, random, sin, min, max = math.floor, math.random, math.sin, math.min, math.max

local MEDIA = "Interface\\AddOns\\AzaathUI\\Media\\ItemCard\\"
local K = {                       -- medidas do card (unidades de UI, escala 1)
    W = 300, PAD = 12, HEAD = 84, ICON = 68,
    PERK = 24, PERKGAP = 8, LINE = 3, SECTION = 7,
}
local TOOLTIPS = {
    "GameTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3",
    "ItemRefTooltip", "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "ItemRefShoppingTooltip3",
}
local WATCHED = {}
for _, n in ipairs(TOOLTIPS) do WATCHED[n] = true end
local COMPARE_PARENT = {
    ShoppingTooltip1 = "GameTooltip",
    ShoppingTooltip2 = "GameTooltip",
    ShoppingTooltip3 = "GameTooltip",
    ItemRefShoppingTooltip1 = "ItemRefTooltip",
    ItemRefShoppingTooltip2 = "ItemRefTooltip",
    ItemRefShoppingTooltip3 = "ItemRefTooltip",
}
local COMPARE_PREV = {
    ShoppingTooltip2 = { "ShoppingTooltip1" },
    ShoppingTooltip3 = { "ShoppingTooltip2", "ShoppingTooltip1" },
    ItemRefShoppingTooltip2 = { "ItemRefShoppingTooltip1" },
    ItemRefShoppingTooltip3 = { "ItemRefShoppingTooltip2", "ItemRefShoppingTooltip1" },
}
local COMPARE_CHILDREN = {
    GameTooltip = { "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3" },
    ItemRefTooltip = { "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "ItemRefShoppingTooltip3" },
}

-- Raridade: tinta do papel do cabeçalho, cor do texto e das fagulhas, fagulhas por segundo
local RARITY = {
    [0] = { head = { 0.55, 0.55, 0.58 }, text = { 0.62, 0.62, 0.62 }, rate = 0 },   -- pobre
    [1] = { head = { 0.62, 0.62, 0.66 }, text = { 0.92, 0.92, 0.92 }, rate = 0 },   -- comum
    [2] = { head = { 0.26, 0.88, 0.26 }, text = { 0.38, 0.95, 0.30 }, rate = 6 },   -- incomum
    [3] = { head = { 0.16, 0.77, 0.99 }, text = { 0.30, 0.72, 1.00 }, rate = 9 },   -- raro
    [4] = { head = { 0.83, 0.22, 0.99 }, text = { 0.86, 0.42, 1.00 }, rate = 14 },  -- épico
    [5] = { head = { 1.00, 0.64, 0.16 }, text = { 1.00, 0.62, 0.20 }, rate = 22 },  -- lendário
    [6] = { head = { 1.00, 0.35, 0.13 }, text = { 1.00, 0.50, 0.28 }, rate = 26 },  -- artefato
    [7] = { head = { 0.95, 0.80, 0.45 }, text = { 0.98, 0.84, 0.50 }, rate = 12 },  -- herança
}
local C_WHITE  = { 1, 1, 1 }
local C_LABEL  = { 0.86, 0.86, 0.86 }
local C_PERK   = { 0.42, 0.66, 1.00 }  -- texto dos efeitos (azul do jogo)
local C_PERKB  = { 0.62, 0.80, 1.00 }  -- prefixo "Equipar:" etc.
local C_GREEN  = { 0.24, 0.80, 0.42 }  -- vínculo
local C_FLAVOR = { 0.80, 0.80, 0.80 }
local C_GRAY   = { 0.55, 0.55, 0.55 }
local C_GOLD   = { 1.00, 0.82, 0.25 }

-- Ícones dos efeitos por palavra-chave (inglês e português)
local PERK_ICONS = {
    { "attack power", "Ability_Warrior_BattleShout" }, { "poder de ataque", "Ability_Warrior_BattleShout" },
    { "critical", "Ability_CriticalStrike" }, { "crític", "Ability_CriticalStrike" },
    { "hit", "Ability_Marksmanship" }, { "acerto", "Ability_Marksmanship" },
    { "heal", "Spell_Holy_Heal" }, { "cura", "Spell_Holy_Heal" },
    { "spell", "Spell_Fire_FlameBolt" }, { "feitiç", "Spell_Fire_FlameBolt" }, { "mágic", "Spell_Fire_FlameBolt" },
    { "mana", "Spell_Nature_ManaRegenTotem" },
    { "defense", "Ability_Defend" }, { "defesa", "Ability_Defend" }, { "block", "Ability_Defend" }, { "bloque", "Ability_Defend" },
    { "dodge", "Ability_Rogue_Feint" }, { "esquiv", "Ability_Rogue_Feint" },
    { "parry", "Ability_Parry" }, { "aparar", "Ability_Parry" },
    { "haste", "Spell_Nature_Bloodlust" }, { "acelera", "Spell_Nature_Bloodlust" },
    { "armor", "INV_Shield_06" }, { "armadura", "INV_Shield_06" },
    { "health", "Spell_Holy_SealOfSacrifice" }, { "vida", "Spell_Holy_SealOfSacrifice" },
    { "stealth", "Ability_Stealth" }, { "furtiv", "Ability_Stealth" },
    { "speed", "Ability_Rogue_Sprint" }, { "velocidade", "Ability_Rogue_Sprint" },
}
local ICON = "Interface\\Icons\\"
local ICON_EQUIP   = ICON .. "INV_Enchant_ShardBrilliantLarge"
local ICON_USE     = ICON .. "INV_Misc_Gear_01"
local ICON_PROC    = ICON .. "Spell_Lightning_LightningBolt01"
local ICON_ENCHANT = ICON .. "Trade_Engraving"
local ICON_SET     = ICON .. "INV_Misc_Book_09"
local ICON_SOCKET  = "Interface\\ItemSocketingFrame\\UI-EmptySocket-Prismatic"

--------------------------------------------------------------------------------
-- Padrões das strings globais
--------------------------------------------------------------------------------
-- "Durability %d / %d" -> "^Durability (%d+) / (%d+)$"
local function ToPattern(fmt)
    if type(fmt) ~= "string" or fmt == "" then return nil end
    fmt = fmt:gsub("%%%d%$", "%%")                         -- %1$s -> %s
    fmt = fmt:gsub("%%[%d%.]*([dsf])", function(c)          -- marcadores provisórios
        return c == "s" and "\001" or "\002"
    end)
    fmt = fmt:gsub("([%%%(%)%.%[%]%*%+%-%?%^%$])", "%%%1")  -- escapa mágicos
    fmt = fmt:gsub("\001", "(.+)"):gsub("\002", "([%%d%%.,]+)")
    return "^" .. fmt .. "$"
end
local function P(name) return ToPattern(_G[name]) end

local PAT = {}
local EXACT = {}   -- texto exato -> categoria
local SELL_LOW     -- "preço de venda" em minúsculas (o jogo varia a caixa)
local function AddExact(k, cat)
    local v = _G[k]
    if type(v) == "string" then
        v = v:gsub("^%s+", ""):gsub("%s+$", "")
        if v ~= "" then EXACT[v] = cat end
    end
end
local function BuildPatterns()
    SELL_LOW = type(_G.SELL_PRICE) == "string" and (_G.SELL_PRICE:lower():gsub("[:：]%s*$", "")) or nil
    PAT.ilvl     = { P("ITEM_LEVEL"), P("ITEM_LEVEL_ALT") }
    PAT.dura     = { P("DURABILITY_TEMPLATE") }
    PAT.req      = { P("ITEM_MIN_LEVEL"), P("ITEM_REQ_SKILL"), P("ITEM_REQ_REPUTATION"), P("ITEM_REQ_SPECIALIZATION"),
                     P("ITEM_CLASSES_ALLOWED"), P("ITEM_RACES_ALLOWED"), P("ITEM_LEVEL_RANGE"), P("ITEM_REQ_PURCHASE_GROUP") }
    PAT.base     = { P("ARMOR_TEMPLATE"), P("DAMAGE_TEMPLATE"), P("SINGLE_DAMAGE_TEMPLATE"), P("DAMAGE_TEMPLATE_WITH_SCHOOL"),
                     P("SINGLE_DAMAGE_TEMPLATE_WITH_SCHOOL"), P("PLUS_DAMAGE_TEMPLATE"), P("PLUS_DAMAGE_TEMPLATE_WITH_SCHOOL"),
                     P("DPS_TEMPLATE"), P("SHIELD_BLOCK_TEMPLATE") }
    PAT.bag      = { P("CONTAINER_SLOTS") }
    PAT.setName  = { P("ITEM_SET_NAME") }
    PAT.setBonus = { P("ITEM_SET_BONUS"), P("ITEM_SET_BONUS_GRAY"), P("ITEM_SET_BONUS_NO_VALID_SPEC") }
    PAT.sockBonus = { P("ITEM_SOCKET_BONUS") }
    PAT.unique   = { P("ITEM_UNIQUE_MULTIPLE"), P("ITEM_LIMIT_CATEGORY_MULTIPLE"), P("ITEM_LIMIT_CATEGORY") }
    PAT.made     = { P("ITEM_CREATED_BY"), P("ITEM_WRAPPED_BY") }
    PAT.enchant  = { P("ENCHANTED_TOOLTIP_LINE") }
    for _, k in ipairs({ "ITEM_SOULBOUND", "ITEM_BIND_ON_EQUIP", "ITEM_BIND_ON_PICKUP", "ITEM_BIND_ON_USE",
                         "ITEM_BIND_QUEST", "ITEM_BIND_TO_ACCOUNT", "ITEM_BIND_TO_BNETACCOUNT", "ITEM_ACCOUNTBOUND",
                         "ITEM_BNETACCOUNTBOUND", "ITEM_BIND_TO_ACCOUNT_UNTIL_EQUIP", "ITEM_ACCOUNTBOUND_UNTIL_EQUIP" }) do
        AddExact(k, "bind")
    end
    for _, k in ipairs({ "ITEM_UNIQUE", "ITEM_UNIQUE_EQUIPPABLE", "ITEM_CONJURED", "ITEM_HEROIC", "ITEM_HEROIC_EPIC" }) do
        AddExact(k, "unique")
    end
    for _, k in ipairs({ "CURRENTLY_EQUIPPED", "EQUIPPED_ITEM_TOOLTIP_HEADER", "ITEM_COMPARISON_EQUIPPED_HEADER" }) do
        AddExact(k, "equipped")
    end
    for _, k in ipairs({ "EMPTY_SOCKET_RED", "EMPTY_SOCKET_BLUE", "EMPTY_SOCKET_YELLOW", "EMPTY_SOCKET_META",
                         "EMPTY_SOCKET_PRISMATIC", "EMPTY_SOCKET_NO_COLOR", "EMPTY_SOCKET_COGWHEEL" }) do
        AddExact(k, "socket")
    end
    AddExact("ITEM_DELTA_DESCRIPTION", "delta")
    AddExact("ITEM_DELTA_MULTIPLE_COMPARISON_DESCRIPTION", "delta")
    AddExact("ITEM_DELTA_DUAL_WIELD_COMPARISON_DESCRIPTION", "delta")
end

local function Match(list, s)
    if not list then return nil end
    for i = 1, 12 do                       -- a lista tem buracos (strings que o cliente não tem)
        local p = list[i]
        if p and s:find(p) then return true end
    end
    return nil
end

local function StartsWith(s, prefix)
    return type(prefix) == "string" and prefix ~= "" and s:sub(1, #prefix) == prefix
end

-- "41 - 77 Dano" -> "41 - 77", "Dano";  "Velocidade 2.60" -> "2.60", "Velocidade"
local function SplitNum(s)
    s = s:gsub("^%((.*)%)$", "%1")
    local n, rest = s:match("^([%+%-]?%s*[%d%.,]+%s*[%-/]%s*[%d%.,]+)%s+(.+)$")
    if not n then n, rest = s:match("^([%+%-]?%s*[%d%.,]+%%?)%s+(.+)$") end
    if not n then rest, n = s:match("^(.-)%s+([%+%-]?[%d%.,]+%%?)$") end
    if n and rest and rest ~= "" then
        rest = rest:gsub("^de ", "")
        return n, rest:sub(1, 1):upper() .. rest:sub(2)
    end
    return nil, s
end

local function IsColor(r, g, b, R, G, B)
    return r and math.abs(r - R) < 0.06 and math.abs(g - G) < 0.06 and math.abs(b - B) < 0.06
end

--------------------------------------------------------------------------------
-- Leitura da tooltip
--------------------------------------------------------------------------------
-- Ícones (gemas/engastes) que o jogo pôs ao lado das linhas: textura -> linha
local function LineTextures(tt, name)
    local map = {}
    for i = 1, 10 do
        local tex = _G[name .. "Texture" .. i]
        if tex and tex:IsShown() and tex:GetTexture() then
            local _, rel = tex:GetPoint(1)
            if rel then map[rel] = tex:GetTexture() end
        end
    end
    return map
end

local lastData = {} -- [tooltip] = último TooltipData recebido pelo TooltipDataProcessor

local function CleanText(s)
    if type(s) ~= "string" then return "" end
    return s:gsub("|cn[^:]+:", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        :gsub("|T.-|t", ""):gsub("|A.-|a", ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function ExtractLinkFromData(data)
    if type(data) ~= "table" then return nil end
    local itemType = Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item
    local dtype = not Azaath.IsSecret(data.type) and data.type or nil
    if type(data.hyperlink) == "string" and not Azaath.IsSecret(data.hyperlink) and data.hyperlink ~= ""
       and (not itemType or dtype == itemType or data.hyperlink:find("item:", 1, true)) then
        return data.hyperlink
    end
    if type(data.guid) == "string" and not Azaath.IsSecret(data.guid) and _G.C_Item and C_Item.GetItemLinkByGUID then
        local ok, l = pcall(C_Item.GetItemLinkByGUID, data.guid)
        if ok and type(l) == "string" and not Azaath.IsSecret(l) and l ~= "" then return l end
    end
    if data.id and not Azaath.IsSecret(data.id) and (not itemType or dtype == itemType) then
        local l = select(2, Azaath.API.GetItemInfo(data.id))
        if l then return l end
    end
    return nil
end

local function FindEquippedLink(tt, name)
    local nth = tonumber(name:match("(%d+)$")) or 1
    local title
    for i = 1, 2 do
        local L = _G[name .. "TextLeft" .. i]
        local s = L and L:IsShown() and L:GetText()
        if s and not Azaath.IsSecret(s) then
            local p = CleanText(s)
            if p ~= "" and EXACT[p] ~= "equipped" then
                title = p
                break
            end
        end
    end
    if not title then return nil end
    local first, seen = nil, 0
    for slot = 1, 19 do
        local eq = GetInventoryItemLink("player", slot)
        if eq then
            local eqName = Azaath.API.GetItemInfo(eq)
            if eqName == title then
                seen = seen + 1
                if not first then first = eq end
                if seen == nth then return eq end
            end
        end
    end
    return first
end

local function GetTooltipLink(tt, name)
    if tt.GetItem then
        local ok, _, l = pcall(tt.GetItem, tt)
        if ok and type(l) == "string" and l ~= "" then return l end
    end
    if _G.TooltipUtil and TooltipUtil.GetDisplayedItem then
        local ok, _, l, id = pcall(TooltipUtil.GetDisplayedItem, tt)
        if ok then
            if type(l) == "string" and l ~= "" then return l end
            if id then
                local il = select(2, Azaath.API.GetItemInfo(id))
                if il then return il end
            end
        end
    end
    if tt.GetTooltipData then
        local ok, data = pcall(tt.GetTooltipData, tt)
        local l = ok and ExtractLinkFromData(data)
        if l then return l end
    end
    local l = ExtractLinkFromData(lastData[tt])
    if l then return l end
    if COMPARE_PARENT[name] then
        return FindEquippedLink(tt, name)
    end
    return nil
end

local function ReadTooltip(tt)
    local name = tt:GetName()
    if not name then return nil end
    local link = GetTooltipLink(tt, name)
    if not link then return nil end

    local d = {
        link = link, base = {}, attrs = {}, perks = {}, flavor = {}, bind = {}, foot = {},
        req = {}, extra = {}, delta = {},
    }
    local iname, _, quality, ilvl, _, itemType, itemSub, _, equipLoc, icon, sellPrice, classID =
        Azaath.API.GetItemInfo(link)
    d.name, d.quality, d.icon, d.equipLoc, d.classID = iname, quality or 1, icon, equipLoc, classID
    d.itemType, d.itemSub = itemType, itemSub
    d.ilvl = ilvl
    local detailed = (_G.C_Item and C_Item.GetDetailedItemLevelInfo) or _G.GetDetailedItemLevelInfo
    if detailed then
        local ok, eff = pcall(detailed, link)
        if ok and type(eff) == "number" and eff > 0 then d.ilvl = eff end
    end
    if not d.icon then
        local inst = Azaath.API.GetItemInfoInstant
        if inst then d.icon = select(5, inst(link)) end
    end
    local slotName = equipLoc and equipLoc ~= "" and _G[equipLoc]

    local useSpellIcon
    local getSpell = (_G.C_Item and C_Item.GetItemSpell) or _G.GetItemSpell
    if getSpell then
        local ok, _, spellID = pcall(getSpell, link)
        if ok and spellID then
            local tex = (_G.C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(spellID))
                or (_G.GetSpellTexture and _G.GetSpellTexture(spellID))
            useSpellIcon = tex
        end
    end

    local texOf = LineTextures(tt, name)
    local n = tt:NumLines() or 0
    local start, deltaMode, nameSeen = 1, false, false
    local afterSet = false
    for i = start, n do
        local L, R = _G[name .. "TextLeft" .. i], _G[name .. "TextRight" .. i]
        local s = L and L:IsShown() and L:GetText()
        if s ~= nil and Azaath.IsSecret(s) then return nil end
        local rs = R and R:IsShown() and R:GetText()
        if rs ~= nil and Azaath.IsSecret(rs) then return nil end
        if rs == "" then rs = nil end
        if s and s ~= "" then
            local r, g, b = L:GetTextColor()
            local plain = CleanText(s)
            local exact = EXACT[plain]

            if plain == "" and not rs then
                -- linha em branco separadora: ignora
            elseif not nameSeen and (exact == "equipped" or (i == 1 and d.name and plain ~= d.name and _G.CURRENTLY_EQUIPPED and plain:find(_G.CURRENTLY_EQUIPPED, 1, true))) then
                d.equipped = plain
            elseif not nameSeen then
                nameSeen = true                                    -- a linha do nome
                if not d.name then d.name = plain end
            elseif deltaMode or exact == "delta" then
                deltaMode = true
                d.delta[#d.delta + 1] = { s, r, g, b }
            elseif exact == "bind" then
                d.bind[#d.bind + 1] = plain
            elseif exact == "unique" or Match(PAT.unique, plain) then
                d.unique = d.unique or plain
                d.bind[#d.bind + 1] = plain
            elseif exact == "socket" then
                d.perks[#d.perks + 1] = { icon = texOf[L] or ICON_SOCKET, body = plain, color = C_GRAY }
            elseif Match(PAT.ilvl, plain) then
                -- vira o número grande
            elseif Match(PAT.dura, plain) then
                local a, z = plain:match("([%d]+)%s*/%s*([%d]+)")
                d.dura = a and (a .. " / " .. z) or plain
                d.duraLabel = _G.DURABILITY or plain:match("^(%a+)") or ""
                d.duraLow = a and tonumber(a) and tonumber(z) and tonumber(a) / max(1, tonumber(z)) < 0.25
            elseif Match(PAT.req, plain) then
                d.req[#d.req + 1] = { plain, r, g, b }
            elseif slotName and (plain == slotName) or (rs and itemSub and rs == itemSub) then
                d.slot, d.sub = plain, rs                         -- "Duas Mãos" | "Espada"
            elseif Match(PAT.base, plain) or Match(PAT.bag, plain) then
                d.base[#d.base + 1] = plain
                if rs then d.base[#d.base + 1] = rs end            -- "Velocidade 2.60"
            elseif Match(PAT.setName, plain) then
                afterSet = true
                d.perks[#d.perks + 1] = { header = plain }
            elseif Match(PAT.setBonus, plain) then
                local active = not IsColor(r, g, b, 0.5, 0.5, 0.5)
                d.perks[#d.perks + 1] = { icon = ICON_SET, body = plain, color = active and C_PERK or C_GRAY }
            elseif Match(PAT.sockBonus, plain) then
                local active = not IsColor(r, g, b, 0.5, 0.5, 0.5)
                d.perks[#d.perks + 1] = { icon = ICON_SOCKET, body = plain, color = active and C_PERK or C_GRAY }
            elseif SELL_LOW and plain:lower():sub(1, #SELL_LOW) == SELL_LOW then
                -- linha de venda do jogo (já com o desconto da durabilidade): vai para o fim do card
                local raw = s:gsub("|cn[^:]+:", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
                local coins = raw:match("^[^:]*:%s*(.+)$")
                if coins and coins ~= "" then d.sellLine = coins end
            elseif Match(PAT.made, plain) then
                d.foot[#d.foot + 1] = { plain, r, g, b }
            elseif plain:sub(1, 1) == "\"" and IsColor(r, g, b, 1, 0.82, 0) then
                d.flavor[#d.flavor + 1] = plain
            elseif StartsWith(plain, _G.ITEM_SPELL_TRIGGER_ONEQUIP) or StartsWith(plain, _G.ITEM_SPELL_TRIGGER_ONUSE)
                or StartsWith(plain, _G.ITEM_SPELL_TRIGGER_ONPROC) then
                local prefix = StartsWith(plain, _G.ITEM_SPELL_TRIGGER_ONEQUIP) and _G.ITEM_SPELL_TRIGGER_ONEQUIP
                    or StartsWith(plain, _G.ITEM_SPELL_TRIGGER_ONUSE) and _G.ITEM_SPELL_TRIGGER_ONUSE
                    or _G.ITEM_SPELL_TRIGGER_ONPROC
                local body = plain:sub(#prefix + 1):gsub("^%s+", "")
                local ico = prefix == _G.ITEM_SPELL_TRIGGER_ONUSE and (useSpellIcon and useSpellIcon or ICON_USE)
                    or prefix == _G.ITEM_SPELL_TRIGGER_ONPROC and ICON_PROC
                if not ico then
                    local low = body:lower()
                    for _, kv in ipairs(PERK_ICONS) do
                        if low:find(kv[1], 1, true) then ico = ICON .. kv[2]; break end
                    end
                end
                local gray = IsColor(r, g, b, 0.5, 0.5, 0.5)
                d.perks[#d.perks + 1] = { icon = ico or ICON_EQUIP, prefix = prefix, body = body,
                    color = gray and C_GRAY or C_PERK }
            elseif afterSet and (plain:sub(1, 1) ~= "+" ) and not IsColor(r, g, b, 1, 1, 1) and
                   not IsColor(r, g, b, 0, 1, 0) and i > 2 and (IsColor(r, g, b, 0.5, 0.5, 0.5) or IsColor(r, g, b, 1, 1, 0.6)) then
                d.perks[#d.perks + 1] = { sub = plain, color = IsColor(r, g, b, 0.5, 0.5, 0.5) and C_GRAY or C_GOLD }
            elseif plain:find("^[%+%-]%s*[%d]") and (IsColor(r, g, b, 1, 1, 1) or IsColor(r, g, b, 0, 1, 0)) then
                if texOf[L] then                                  -- gema encaixada
                    d.perks[#d.perks + 1] = { icon = texOf[L], body = plain, color = C_PERK }
                else
                    d.attrs[#d.attrs + 1] = plain
                end
            elseif IsColor(r, g, b, 0, 1, 0) and not afterSet then
                local body = plain
                if Match(PAT.enchant, plain) then body = plain:match(PAT.enchant[1]) or plain end
                d.perks[#d.perks + 1] = { icon = texOf[L] or ICON_ENCHANT, body = body, color = C_PERK }
            elseif IsColor(r, g, b, 1, 0.125, 0.125) then
                d.req[#d.req + 1] = { plain, r, g, b }               -- requisito não atendido
            elseif IsColor(r, g, b, 1, 1, 1) and i <= 6 and not d.slot and not rs
                   and equipLoc ~= "INVTYPE_BAG" and #d.base == 0 and #d.attrs == 0 and #d.perks == 0
                   and not s:find("|c", 1, true) then
                d.slot = plain                                     -- tipo de item sem encaixe
            elseif IsColor(r, g, b, 1, 1, 1) then
                d.foot[#d.foot + 1] = { plain .. (rs and ("  " .. rs) or ""), 1, 1, 1 }
            else
                d.extra[#d.extra + 1] = { s .. (rs and ("  " .. rs) or ""), r, g, b }
            end
        end
    end

    -- valor de venda: o do quadro de dinheiro da tooltip (já multiplicado pela pilha)
    local mf = _G[name .. "MoneyFrame1"]
    local money = mf and mf:IsShown() and mf.staticMoney
    if type(money) ~= "number" then money = nil end
    d.money = money or (sellPrice and sellPrice > 0 and sellPrice) or nil
    d.noSell = (sellPrice == 0)
    -- preço do leilão (banco do Modules/Auction): menor preço unitário da última varredura
    local adb = Azaath.db and Azaath.db.auction
    if Azaath.AuctionNS and adb and adb.cardPrice ~= false then
        d.ahPrice, d.ahAge = Azaath.AuctionNS.GetPrice(link)
    end
    return d
end

--------------------------------------------------------------------------------
-- Card
--------------------------------------------------------------------------------
local function Font(fs, bold, size)
    fs:SetFont(bold and Azaath.media.fontCard or Azaath.media.fontCardR, size, "")
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetShadowOffset(1, -1)
end

local function AddFrameBorder(parent, sides, level)
    local bf = CreateFrame("Frame", nil, parent)
    bf:SetAllPoints()
    bf:SetFrameLevel(level)
    for _, s in ipairs(sides) do
        local p1, p2, vert, closed = s[1], s[2], s[3], s[4]
        for layer = 0, 1 do
            local t = bf:CreateTexture(nil, "OVERLAY", nil, layer)
            if t.SetSnapToPixelGrid then t:SetSnapToPixelGrid(false) end
            if t.SetTexelSnappingBias then t:SetTexelSnappingBias(0) end
            if layer == 0 then
                t:SetColorTexture(0.02, 0.02, 0.025, 0.95)
            else
                t:SetColorTexture(0.25, 0.26, 0.28, 0.92)
            end
            local ins = layer
            local ox1 = (p1:find("LEFT") and ins) or (p1:find("RIGHT") and -ins) or 0
            local oy1 = (p1:find("TOP") and -ins) or (p1:find("BOTTOM") and ins) or 0
            local ox2 = (p2:find("LEFT") and ins) or (p2:find("RIGHT") and -ins) or 0
            local oy2 = (p2:find("TOP") and -ins) or (p2:find("BOTTOM") and ins) or 0
            if not closed then
                if p1 == "TOPLEFT" and p2 == "BOTTOMLEFT" then oy2 = 0 end
                if p1 == "TOPRIGHT" and p2 == "BOTTOMRIGHT" then oy2 = 0 end
            end
            t:SetPoint(p1, bf, p1, ox1, oy1)
            t:SetPoint(p2, bf, p2, ox2, oy2)
            if vert == 1 then t:SetWidth(1) else t:SetHeight(1) end
        end
    end
    return bf
end

local function NewCard()
    local c = CreateFrame("Frame", nil, UIParent)
    c:SetFrameStrata("TOOLTIP")
    c:SetFrameLevel(50)
    c:SetClampedToScreen(true)
    c:SetWidth(K.W)
    c:Hide()

    local bg = c:CreateTexture(nil, "BACKGROUND", nil, -8)
    bg:SetPoint("TOPLEFT", 1, -1)
    bg:SetPoint("BOTTOMRIGHT", -1, 1)
    bg:SetColorTexture(0.075, 0.075, 0.08, 1)
    AddFrameBorder(c, {
        { "TOPLEFT", "TOPRIGHT", 0, true }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0, true },
        { "TOPLEFT", "BOTTOMLEFT", 1, true }, { "TOPRIGHT", "BOTTOMRIGHT", 1, true },
    }, 55)

    -- faixa "Equipado no momento" (comparação)
    -- aba presa no topo do card, mesma pele do corpo, com filete dourado embaixo do texto
    local tab = CreateFrame("Frame", nil, c)
    tab:SetPoint("BOTTOMLEFT", c, "TOPLEFT", 0, -1)
    tab:SetFrameLevel(56)
    tab:SetHeight(20)
    local tbg = tab:CreateTexture(nil, "BACKGROUND")
    tbg:SetPoint("TOPLEFT", 1, -1)
    tbg:SetPoint("BOTTOMRIGHT", -1, 0)
    tbg:SetColorTexture(0.075, 0.075, 0.08, 1)
    AddFrameBorder(tab, {
        { "TOPLEFT", "TOPRIGHT", 0, false }, { "TOPLEFT", "BOTTOMLEFT", 1, false },
        { "TOPRIGHT", "BOTTOMRIGHT", 1, false },
    }, 57)
    local eq = tab:CreateFontString(nil, "OVERLAY")
    Font(eq, true, 12)
    eq:SetPoint("CENTER", 0, 0)
    eq:SetTextColor(C_GOLD[1], C_GOLD[2], C_GOLD[3])
    local gl = tab:CreateTexture(nil, "ARTWORK")
    gl:SetColorTexture(C_GOLD[1], C_GOLD[2], C_GOLD[3], 0.7)
    gl:SetHeight(1)
    gl:SetPoint("TOPLEFT", eq, "BOTTOMLEFT", 0, -1)
    gl:SetPoint("TOPRIGHT", eq, "BOTTOMRIGHT", 0, -1)
    c.eqText, c.eqTab = eq, tab

    -- cabeçalho
    local h = CreateFrame("Frame", nil, c)
    h:SetPoint("TOPLEFT", 2, -2)
    h:SetPoint("TOPRIGHT", -2, -2)
    h:SetHeight(K.HEAD)
    if h.SetClipsChildren then h:SetClipsChildren(true) end
    c.head = h
    local paper = h:CreateTexture(nil, "BACKGROUND", nil, -6)
    paper:SetAllPoints()
    paper:SetTexture(MEDIA .. "HeaderGrunge")
    paper:SetTexCoord(0, 1, 0.06, 0.94)
    c.paper = paper
    local flare = h:CreateTexture(nil, "BACKGROUND", nil, -4)
    flare:SetPoint("BOTTOMLEFT"); flare:SetPoint("BOTTOMRIGHT")
    flare:SetHeight(K.HEAD * 0.8)
    flare:SetTexture(MEDIA .. "HeaderFlare")
    flare:SetBlendMode("ADD")
    c.flare = flare
    -- fumaça: duas camadas que rolam em velocidades e direções diferentes (textura repete)
    c.smoke = {}
    for i, def in ipairs({ { "Smoke1", 1.15, 0.33, -0.018, 0.030 }, { "Smoke2", 0.80, 0.23, 0.011, 0.045 } }) do
        local s = h:CreateTexture(nil, "BACKGROUND", nil, -5 + i)
        s:SetAllPoints()
        s:SetTexture(MEDIA .. def[1], "REPEAT", "REPEAT")
        s:SetBlendMode("ADD")
        s.su, s.sv, s.du, s.dv = def[2], def[3], def[4], def[5]
        s.u, s.v = random(), random()
        c.smoke[i] = s
    end
    local line = h:CreateTexture(nil, "ARTWORK", nil, 2)
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT")
    line:SetHeight(1)
    c.headLine = line

    -- partículas por cima do papel, abaixo do texto
    local fx = CreateFrame("Frame", nil, h)
    fx:SetAllPoints()
    fx:SetFrameLevel(h:GetFrameLevel() + 1)
    c.fx = fx
    local txt = CreateFrame("Frame", nil, h)
    txt:SetAllPoints()
    txt:SetFrameLevel(h:GetFrameLevel() + 2)

    -- ícone
    local ib = txt:CreateTexture(nil, "ARTWORK", nil, 0)
    ib:SetSize(K.ICON, K.ICON)
    ib:SetPoint("LEFT", h, "LEFT", 8, 0)
    ib:SetTexture(Azaath.media.blank)
    c.iconBG = ib
    local icon = txt:CreateTexture(nil, "ARTWORK", nil, 2)
    icon:SetPoint("TOPLEFT", ib, 3, -3)
    icon:SetPoint("BOTTOMRIGHT", ib, -3, 3)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    c.icon = icon
    c.iconEdge = {}
    for i, p in ipairs({ { "TOPLEFT", "TOPRIGHT", 0 }, { "BOTTOMLEFT", "BOTTOMRIGHT", 0 },
                         { "TOPLEFT", "BOTTOMLEFT", 1 }, { "TOPRIGHT", "BOTTOMRIGHT", 1 } }) do
        local t = txt:CreateTexture(nil, "ARTWORK", nil, 3)
        t:SetTexture(Azaath.media.blank)
        t:SetPoint(p[1], ib); t:SetPoint(p[2], ib)
        if p[3] == 1 then t:SetWidth(1) else t:SetHeight(1) end
        c.iconEdge[i] = t
    end

    local nm = txt:CreateFontString(nil, "OVERLAY")
    Font(nm, true, 16)
    nm:SetPoint("TOPLEFT", ib, "TOPRIGHT", 9, -1)
    nm:SetPoint("RIGHT", h, "RIGHT", -8, 0)
    nm:SetJustifyH("LEFT")
    nm:SetWordWrap(true)
    nm:SetMaxLines(2)
    c.nameFS = nm
    local rar = txt:CreateFontString(nil, "OVERLAY")
    Font(rar, true, 12)
    rar:SetPoint("BOTTOMLEFT", ib, "BOTTOMRIGHT", 9, 17)
    rar:SetJustifyH("LEFT")
    c.rarFS = rar
    local ty = txt:CreateFontString(nil, "OVERLAY")
    Font(ty, true, 12)
    ty:SetPoint("BOTTOMLEFT", ib, "BOTTOMRIGHT", 9, 2)
    ty:SetJustifyH("LEFT")
    ty:SetTextColor(1, 1, 1)
    c.typeFS = ty
    local sl = txt:CreateFontString(nil, "OVERLAY")
    Font(sl, true, 12)
    sl:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -8, 7)
    sl:SetJustifyH("RIGHT")
    sl:SetTextColor(1, 1, 1)
    c.slotFS = sl

    -- botão fechar (usado apenas no ItemRefTooltip de links do chat)
    local close = CreateFrame("Button", nil, txt)
    close:SetSize(16, 16)
    close:SetPoint("TOPRIGHT", h, "TOPRIGHT", -4, -4)
    local closeFS = close:CreateFontString(nil, "OVERLAY")
    closeFS:SetFont(Azaath.media.fontTitleB, 14, "")
    closeFS:SetShadowColor(0, 0, 0, 0.9)
    closeFS:SetShadowOffset(1, -1)
    closeFS:SetPoint("CENTER", 0, 0)
    closeFS:SetText("×")
    closeFS:SetTextColor(0.75, 0.75, 0.75)
    close:SetScript("OnEnter", function() closeFS:SetTextColor(C_GOLD[1], C_GOLD[2], C_GOLD[3]) end)
    close:SetScript("OnLeave", function() closeFS:SetTextColor(0.75, 0.75, 0.75) end)
    close:SetScript("OnClick", function() if c.tt then c.tt:Hide() end end)
    close:Hide()
    c.closeBtn = close

    -- corpo: regiões reaproveitadas a cada montagem
    c.fs, c.tex, c.nfs, c.ntex = {}, {}, 0, 0
    c.parts = {}
    c.t = 0
    return c
end

local function GetFS(c)
    c.nfs = c.nfs + 1
    local fs = c.fs[c.nfs]
    if not fs then
        fs = c:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(true)
        c.fs[c.nfs] = fs
    end
    fs:ClearAllPoints()
    fs:SetWidth(0)
    fs:Show()
    return fs
end

local function GetTex(c, layer)
    c.ntex = c.ntex + 1
    local t = c.tex[c.ntex]
    if not t then
        t = c:CreateTexture(nil, "ARTWORK")
        c.tex[c.ntex] = t
    end
    t:ClearAllPoints()
    t:SetDrawLayer(layer or "ARTWORK", 0)
    t:SetTexCoord(0, 1, 0, 1)
    t:SetVertexColor(1, 1, 1, 1)
    t:SetBlendMode("BLEND")
    t:SetDesaturated(false)
    if t.azMask then t:RemoveMaskTexture(t.azMask) t.azMask = nil end
    t:Show()
    return t
end

-- Texto com quebra: devolve a altura
local function Text(c, y, x, w, s, col, bold, size, justify)
    local fs = GetFS(c)
    Font(fs, bold, size or 12)
    fs:SetTextColor(col[1], col[2], col[3])
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWidth(w)
    fs:SetPoint("TOPLEFT", c, "TOPLEFT", x, -y)
    fs:SetText(s)
    return fs:GetStringHeight(), fs
end

-- Divisor: linha fina com o losango vazado no meio
local function Divider(c, y)
    local mid = K.W / 2
    local d = GetTex(c)
    d:SetTexture(MEDIA .. "Diamond")
    d:SetSize(11, 11)
    d:SetPoint("CENTER", c, "TOPLEFT", mid, -y)
    d:SetVertexColor(0.55, 0.55, 0.55, 1)
    for side = -1, 1, 2 do
        local l = GetTex(c, "BORDER")
        l:SetTexture(Azaath.media.blank)
        l:SetVertexColor(0.32, 0.32, 0.33, 0.9)
        l:SetHeight(1)
        if side < 0 then
            l:SetPoint("LEFT", c, "TOPLEFT", K.PAD, -y)
            l:SetPoint("RIGHT", d, "LEFT", 1, 0)
        else
            l:SetPoint("LEFT", d, "RIGHT", -1, 0)
            l:SetPoint("RIGHT", c, "TOPRIGHT", -K.PAD, -y)
        end
    end
end

-- Linha "77 Dano Base" ou "Bolsa de 8 espaços": número em negrito + rótulo
local function NumLine(c, y, s, col)
    local num, label = SplitNum(s)
    if not num then
        local pre, mid, post = s:match("^(.-)%s+(%d[%d%.,]*)%s+(.+)$")
        if pre and mid and post then
            local _, a = Text(c, y, K.PAD, 0, pre, col or C_LABEL, false, 12)
            a:SetWidth(0)
            local wa = a:GetStringWidth()
            local _, b = Text(c, y, K.PAD + wa + 4, 0, mid, col or C_WHITE, true, 12)
            b:SetWidth(0)
            local wb = b:GetStringWidth()
            local rem = K.W - 2 * K.PAD - wa - wb - 8
            if rem > 30 then
                local _, d = Text(c, y, K.PAD + wa + 4 + wb + 4, rem, post, col or C_LABEL, false, 12)
                return max(a:GetStringHeight(), b:GetStringHeight(), d:GetStringHeight())
            end
            a:Hide(); b:Hide()
            c.nfs = c.nfs - 2
            s = pre .. " |cffffffff" .. mid .. "|r " .. post
        end
        return Text(c, y, K.PAD, K.W - 2 * K.PAD, s, col or C_LABEL, false, 12)
    end
    local _, a = Text(c, y, K.PAD, 0, num, col or C_WHITE, true, 12)
    a:SetWidth(0)
    local w = a:GetStringWidth()
    local _, b = Text(c, y, K.PAD + w + 4, K.W - 2 * K.PAD - w - 4, label, col or C_LABEL, false, 12)
    return max(a:GetStringHeight(), b:GetStringHeight())
end

local function CoinText(money)
    if _G.GetCoinTextureString then
        local ok, s = pcall(_G.GetCoinTextureString, money, 12)
        if ok and s then return s end
    end
    local g, s, c = floor(money / 10000), floor(money / 100) % 100, money % 100
    local out = ""
    if g > 0 then out = out .. g .. "|TInterface\\MoneyFrame\\UI-GoldIcon:12:12:2:0|t " end
    if s > 0 or g > 0 then out = out .. s .. "|TInterface\\MoneyFrame\\UI-SilverIcon:12:12:2:0|t " end
    return out .. c .. "|TInterface\\MoneyFrame\\UI-CopperIcon:12:12:2:0|t"
end

local function Layout(c, d)
    c.nfs, c.ntex = 0, 0
    local q = RARITY[d.quality] or RARITY[1]
    local W, PAD = K.W, K.PAD

    -- cabeçalho
    c.paper:SetVertexColor(q.head[1] * 0.7, q.head[2] * 0.7, q.head[3] * 0.7)   -- base; a fumaça acende por cima
    c.flare:SetVertexColor(q.head[1], q.head[2], q.head[3], 0.35)
    -- fumaça densa embaixo, sumindo em cima (cor da raridade)
    for i, s in ipairs(c.smoke) do
        local a = i == 1 and 0.55 or 0.40
        s:SetGradient("VERTICAL", CreateColor(q.text[1], q.text[2], q.text[3], a),
            CreateColor(q.text[1], q.text[2], q.text[3], a * 0.12))
    end
    c.headLine:SetColorTexture(q.text[1], q.text[2], q.text[3], 0.55)
    c.iconBG:SetGradient("VERTICAL", CreateColor(q.head[1] * 0.55, q.head[2] * 0.55, q.head[3] * 0.55, 1),
        CreateColor(0.03, 0.03, 0.03, 1))
    for _, t in ipairs(c.iconEdge) do t:SetVertexColor(q.text[1], q.text[2], q.text[3], 0.9) end
    c.icon:SetTexture(d.icon or 134400)
    c.nameFS:SetText(d.name or "")
    c.nameFS:SetTextColor(q.text[1], q.text[2], q.text[3])
    local rarName = _G["ITEM_QUALITY" .. (d.quality or 1) .. "_DESC"] or ""
    if d.unique then rarName = rarName .. "  \226\128\162  " .. d.unique end   -- U+2022 (bolinha), existe na fonte
    c.rarFS:SetText(rarName)
    c.rarFS:SetTextColor(q.text[1], q.text[2], q.text[3])
    c.rarFS:SetWidth(W - K.ICON - 30)
    c.typeFS:SetText(d.sub or (d.slot and d.itemType) or d.itemSub or d.itemType or "")
    c.slotFS:SetText(d.sub and d.slot or "")
    c.eqText:SetText(d.equipped or "")
    c.eqTab:SetWidth((c.eqText:GetStringWidth() or 40) + 22)
    c.eqTab:SetShown(d.equipped ~= nil)
    c.typeFS:SetWidth(max(40, W - K.ICON - 30 - (c.slotFS:GetStringWidth() or 0) - 10))

    local y = K.HEAD + 2 + 10

    -- nível do item
    local gear = d.equipLoc and d.equipLoc ~= "" and d.equipLoc ~= "INVTYPE_BAG" and d.equipLoc ~= "INVTYPE_NON_EQUIP_IGNORE"
    if gear and d.ilvl and d.ilvl > 0 then
        local ic = GetTex(c)
        ic:SetTexture(MEDIA .. "ItemLevel")
        ic:SetSize(30, 30)
        ic:SetPoint("TOPLEFT", c, "TOPLEFT", PAD, -(y + 2))
        local _, fs = Text(c, y - 4, PAD + 38, 0, floor(d.ilvl + 0.5), C_WHITE, true, 32)
        fs:SetWidth(0)
        y = y + 40
    end
    -- base
    for _, s in ipairs(d.base) do y = y + NumLine(c, y, s) + K.LINE end
    -- atributos
    if #d.attrs > 0 then
        if #d.base > 0 or gear then y = y + K.SECTION; Divider(c, y); y = y + K.SECTION + 2 end
        for _, s in ipairs(d.attrs) do y = y + NumLine(c, y, s) + K.LINE end
    end
    -- efeitos
    if #d.perks > 0 then
        y = y + K.SECTION; Divider(c, y); y = y + K.SECTION + 3
        local tx = PAD + K.PERK + K.PERKGAP
        local tw = W - tx - PAD
        for _, p in ipairs(d.perks) do
            if p.header then
                y = y + 2 + Text(c, y, PAD, W - 2 * PAD, p.header, C_GOLD, true, 12) + K.LINE
            elseif p.sub then
                y = y + Text(c, y, tx, tw, p.sub, p.color, false, 11) + 1
            else
                local col = p.color or C_PERK
                local s = p.body
                if p.prefix then
                    local pc = (col == C_GRAY) and C_GRAY or C_PERKB
                    s = ("|cff%02x%02x%02x%s|r %s"):format(floor(pc[1] * 255), floor(pc[2] * 255), floor(pc[3] * 255), p.prefix, p.body)
                end
                local hgt = Text(c, y + 1, tx, tw, s, col, true, 12)
                local ic = GetTex(c)
                ic:SetTexture(p.icon)
                ic:SetSize(K.PERK - 2, K.PERK - 2)
                ic:SetPoint("TOPLEFT", c, "TOPLEFT", PAD + 1, -(y + 1))
                ic:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                if c.CreateMaskTexture then
                    c.azMasks = c.azMasks or {}
                    local mk = c.azMasks[ic]
                    if not mk then
                        mk = c:CreateMaskTexture()
                        mk:SetTexture(MEDIA .. "PerkMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
                        c.azMasks[ic] = mk
                    end
                    mk:ClearAllPoints()
                    mk:SetAllPoints(ic)
                    ic:AddMaskTexture(mk)
                    ic.azMask = mk
                end
                if col == C_GRAY then ic:SetDesaturated(true) else ic:SetDesaturated(false) end
                local ring = GetTex(c, "OVERLAY")
                ring:SetTexture(MEDIA .. "PerkRing")
                ring:SetSize(K.PERK + 2, K.PERK + 2)
                ring:SetPoint("CENTER", ic, "CENTER")
                ring:SetVertexColor(0.70, 0.70, 0.72, 0.9)
                y = y + max(hgt, K.PERK) + 5
            end
        end
    end
    -- descrição
    if #d.flavor > 0 then
        y = y + K.SECTION - 2; Divider(c, y); y = y + K.SECTION + 2
        for _, s in ipairs(d.flavor) do
            y = y + Text(c, y, PAD, W - 2 * PAD, (s:gsub("^\"(.*)\"$", "%1")), C_FLAVOR, false, 12) + K.LINE
        end
    end
    -- rodapé
    y = y + K.SECTION - 2; Divider(c, y); y = y + K.SECTION + 3
    for _, s in ipairs(d.bind) do y = y + Text(c, y, PAD, W - 2 * PAD, s, C_GREEN, true, 12) + 1 end
    for _, f in ipairs(d.foot) do y = y + Text(c, y, PAD, W - 2 * PAD, f[1], { f[2], f[3], f[4] }, false, 12) + 1 end
    if d.dura then
        local col = d.duraLow and { 1, 0.3, 0.25 } or C_WHITE
        y = y + NumLine(c, y, d.dura .. " " .. d.duraLabel, col) + 1
    end
    for _, f in ipairs(d.req) do y = y + Text(c, y, PAD, W - 2 * PAD, f[1], { f[2], f[3], f[4] }, false, 12) + 1 end
    for _, f in ipairs(d.extra) do y = y + Text(c, y, PAD, W - 2 * PAD, f[1], { f[2], f[3], f[4] }, false, 12) + 1 end
    if d.sellLine or (d.money and d.money > 0) then
        y = y + 4
        local label = (_G.SELL_PRICE or "Sell Price"):gsub("[:：]%s*$", "") .. ":"
        local _, a = Text(c, y, PAD, 0, label, C_LABEL, false, 12)
        a:SetWidth(0)
        Text(c, y, PAD + a:GetStringWidth() + 6, W - 2 * PAD, d.sellLine or CoinText(d.money), C_WHITE, true, 12)
        y = y + 15
    elseif d.noSell and _G.ITEM_UNSELLABLE then
        y = y + 4 + Text(c, y + 4, PAD, W - 2 * PAD, _G.ITEM_UNSELLABLE, C_GRAY, false, 12)
    end
    if d.ahPrice then
        local AN = Azaath.AuctionNS
        local _, a = Text(c, y, PAD, 0, AN.L("Leilão:", "Auction:"), C_LABEL, false, 12)
        a:SetWidth(0)
        local age = (d.ahAge and d.ahAge > 0) and ("  |cff8a8f94(" .. AN.AgeText(d.ahAge) .. ")|r") or ""
        Text(c, y, PAD + a:GetStringWidth() + 6, W - 2 * PAD, AN.Money(d.ahPrice) .. age, C_WHITE, true, 12)
        y = y + 15
    end
    if #d.delta > 0 then
        y = y + K.SECTION; Divider(c, y); y = y + K.SECTION + 2
        for _, f in ipairs(d.delta) do y = y + Text(c, y, PAD, W - 2 * PAD, f[1], { f[2], f[3], f[4] }, false, 11) + 1 end
    end
    c:SetHeight(y + 11)

    for i = c.nfs + 1, #c.fs do c.fs[i]:Hide() end
    for i = c.ntex + 1, #c.tex do c.tex[i]:Hide() end
end

--------------------------------------------------------------------------------
-- Fagulhas
--------------------------------------------------------------------------------
local MAXP = 32
local function Spawn(c, p, q)
    local hw, hh = c.head:GetWidth(), K.HEAD
    if not hw or hw <= 0 then hw = K.W - 2 end
    p.life = 1.1 + random() * 1.7
    p.age = 0
    p.x = random() * hw
    p.y = random() * hh * 0.25                       -- nasce na base do cabeçalho
    p.vy = 14 + random() * 26
    p.vx = (random() - 0.5) * 10
    p.wob = 0.8 + random() * 2.2
    p.ph = random() * 6.28
    p.size = 2 + random() * 3.5
    p.ember = random() < 0.35
    local t = p.tex
    t:SetTexture(MEDIA .. (p.ember and "Ember" or "Spark"))
    local hot = random() * 0.55                     -- mistura com branco: núcleo quente
    t:SetVertexColor(q.text[1] + (1 - q.text[1]) * hot, q.text[2] + (1 - q.text[2]) * hot,
        q.text[3] + (1 - q.text[3]) * hot)
    if p.ember then t:SetSize(p.size * 1.1, p.size * 3.4) else t:SetSize(p.size * 2.2, p.size * 2.2) end
    t:Show()
end

local function UpdateFX(c, dt)
    local q = c.q
    c.t = c.t + dt
    c.flare:SetAlpha(0.28 + 0.10 * sin(c.t * 1.7) + 0.05 * sin(c.t * 4.3))
    for _, s in ipairs(c.smoke) do                  -- sobe e deriva para o lado
        s.u = (s.u + s.du * dt) % 1
        s.v = (s.v + s.dv * dt) % 1
        s:SetTexCoord(s.u, s.u + s.su, s.v, s.v + s.sv)
    end
    if not q or q.rate == 0 or not M.db.itemCardSparks then
        for _, p in ipairs(c.parts) do p.tex:Hide(); p.alive = false end
        return
    end
    c.acc = (c.acc or 0) + dt * q.rate
    while c.acc >= 1 do
        c.acc = c.acc - 1
        for i = 1, MAXP do
            local p = c.parts[i]
            if not p then
                local t = c.fx:CreateTexture(nil, "OVERLAY")
                t:SetBlendMode("ADD")
                p = { tex = t }
                c.parts[i] = p
            end
            if not p.alive then p.alive = true; Spawn(c, p, q); break end
        end
    end
    for _, p in ipairs(c.parts) do
        if p.alive then
            p.age = p.age + dt
            local k = p.age / p.life
            if k >= 1 then
                p.alive = false; p.tex:Hide()
            else
                p.y = p.y + p.vy * dt
                p.x = p.x + (p.vx + sin(p.ph + p.age * p.wob * 3) * 6) * dt
                local a = (k < 0.15 and k / 0.15 or 1) * (1 - k) * (0.75 + 0.25 * sin(p.age * 22 + p.ph))
                p.tex:SetAlpha(a)
                p.tex:ClearAllPoints()
                p.tex:SetPoint("CENTER", c.head, "BOTTOMLEFT", p.x, p.y)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Ligação com as tooltips
--------------------------------------------------------------------------------
local cards = {}           -- [tooltip] = card
local hidden = {}          -- [tooltip] = true enquanto a tooltip está invisível por nossa causa
local equippedOwner = {}   -- [tooltip] = true quando a tooltip principal mostra item equipado do jogador

local equippedLoc
if _G.ItemLocation and _G.ItemLocation.CreateFromEquipmentSlot then
    local ok, loc = pcall(_G.ItemLocation.CreateFromEquipmentSlot, _G.ItemLocation, 1)
    if ok and loc then equippedLoc = loc end
end

local function IsEquippedGUID(guid)
    if type(guid) ~= "string" or Azaath.IsSecret(guid) or guid == "" then return false end
    if not (equippedLoc and _G.C_Item and C_Item.GetItemGUID) then return false end
    for slot = 1, 19 do
        equippedLoc:SetEquipmentSlot(slot)
        local ok, g = pcall(C_Item.GetItemGUID, equippedLoc)
        if ok and g == guid then return true end
    end
    return false
end

local function IsShowingEquipped(tt)
    if not tt then return false end
    if equippedOwner[tt] then return true end
    local data = lastData[tt]
    if not data and tt.GetTooltipData then
        local ok, d = pcall(tt.GetTooltipData, tt)
        if ok then data = d end
    end
    if type(data) == "table" then
        if not Azaath.IsSecret(data.getterName) and data.getterName == "GetInventoryItem"
           and type(data.getterArgs) == "table" then
            local u, s = data.getterArgs[1], data.getterArgs[2]
            local slot = not Azaath.IsSecret(s) and tonumber(s) or nil
            if not Azaath.IsSecret(u) and u == "player" and slot and slot >= 1 and slot <= 19 then
                return true
            end
        end
        if IsEquippedGUID(data.guid) then return true end
    end
    return false
end

local function IsCompareSuppressed(tt)
    local ttName = tt and tt.GetName and tt:GetName()
    local pName = ttName and COMPARE_PARENT[ttName]
    local parentTT = pName and _G[pName]
    return parentTT and IsShowingEquipped(parentTT) or false
end

local Build

-- Limpeza (a tooltip é refeita a cada ~0,2 s em bolsas): esconde, mas mantém as fagulhas
local function Restore(tt)
    local c = cards[tt]
    if c then c:Hide(); c.cleared = nil; c.graceUntil = nil; c.holdUntil = nil end
    if hidden[tt] then hidden[tt] = nil; tt:SetAlpha(1) end
    -- o card principal saiu: as comparações que esperavam a tooltip voltar saem junto
    local children = COMPARE_CHILDREN[tt.GetName and tt:GetName() or ""]
    if children then
        for _, cn in ipairs(children) do
            local ctt = _G[cn]
            local cc = ctt and cards[ctt]
            if cc and cc:IsShown() and not ctt:IsShown() then Restore(ctt) end
        end
    end
end

-- Comparação fechada por um instante: a GameTooltip_Hide do leilão (a cada 0,2 s) fecha as
-- comparações no OnHide e o jogo só as reabre quando chega a comparação do item, às vezes
-- depois da carência de 0,12 s. Enquanto o card principal mostra o mesmo item, o card
-- "Equipado" espera até HOLD s pela tooltip em vez de sumir e reaparecer.
local HOLD = 0.45
local function HoldCompare(c)
    local pName = COMPARE_PARENT[c.tt:GetName() or ""]
    local main = pName and cards[_G[pName]]
    if not (main and main:IsShown()) or (c.parentLink and main.link ~= c.parentLink) then return false end
    local t = GetTime()
    if not c.holdUntil then c.holdUntil = t + HOLD end
    return t < c.holdUntil
end

local function HideCompareOf(main)
    local children = main and COMPARE_CHILDREN[main.GetName and main:GetName() or ""]
    if not children then return end
    for _, cn in ipairs(children) do
        local ctt = _G[cn]
        if ctt then
            Restore(ctt)
            if ctt:IsShown() then ctt:Hide() end
        end
    end
end

local function OnTooltipHide(tt)
    lastData[tt] = nil
    equippedOwner[tt] = nil
    local c = cards[tt]
    if c and c:IsShown() and M.db and M.db.itemCard and GetTime then
        -- carência curta: addons como o Auctionator fecham e reabrem a tooltip (SetOwner+Show)
        -- a cada passada; o card fica parado e invisível-por-baixo até ela voltar ou a carência acabar
        c.cleared = true
        c.graceUntil = GetTime() + 0.12
        return
    end
    Restore(tt)
    if c then c.hiddenAt = GetTime and GetTime() or nil end
end

local function OnTooltipCleared(tt)
    lastData[tt] = nil
    equippedOwner[tt] = nil
    local c = cards[tt]
    -- Mantém o card visível até o fim da reconstrução no mesmo quadro para evitar
    -- piscar ou perder a âncora durante o refresh periódico (~0,2 s) da tooltip.
    if c and c:IsShown() then
        c.cleared = true
    else
        Restore(tt)
    end
end

-- Mesmo canto de ancoragem da tooltip: se ela cresce para cima, o card também
local function Anchor(c, tt)
    local p = tt:GetPoint(1)
    local v = (type(p) == "string" and p:find("BOTTOM")) and "BOTTOM" or "TOP"
    local hz = (type(p) == "string" and p:find("RIGHT")) and "RIGHT" or "LEFT"
    if c.anchor ~= v .. hz then
        c.anchor = v .. hz
        c:ClearAllPoints()
        c:SetPoint(c.anchor, tt, c.anchor)
    end
end

local function DetectCompareSide(c, tt, parentTT, main)
    local ts, ps = tt:GetEffectiveScale() or 1, parentTT:GetEffectiveScale() or 1
    local l, ml = tt:GetLeft(), parentTT:GetLeft()
    if l and ml then
        return (l * ts < ml * ps)
    end
    local pt, rel, relPt = tt:GetPoint(1)
    if rel == parentTT or (rel and COMPARE_PARENT[rel.GetName and rel:GetName() or ""]) then
        if type(pt) == "string" and type(relPt) == "string" then
            if pt:find("RIGHT") and relPt:find("LEFT") then return true end
            if pt:find("LEFT") and relPt:find("RIGHT") then return false end
        end
    end
    if c.side ~= nil then return c.side end
    if main and UIParent then
        local mr = main:GetRight()
        local uiR = UIParent:GetRight()
        if mr and uiR then
            local ms = main:GetEffectiveScale() or 1
            local cs = c:GetEffectiveScale() or 1
            local uis = UIParent:GetEffectiveScale() or 1
            return (mr * ms + (K.W + 8) * cs) > (uiR * uis)
        end
    end
    return false
end

-- Comparações: ao lado do card principal, do mesmo lado em que o jogo pôs a tooltip
local function AnchorShopping(c, tt)
    local ttName = tt:GetName() or ""
    local pName = COMPARE_PARENT[ttName]
    local parentTT = pName and _G[pName]
    if not parentTT then
        Anchor(c, tt)
        return true
    end
    if not parentTT:IsShown() then
        -- o pai some por um instante (ex.: Auctionator faz SetOwner+Show a cada passada no leilão):
        -- não cola na posição da tooltip crua; mantém ao lado do card ou espera o pai voltar
        return c.anchor ~= nil and (c.anchor:sub(1, 1) == "L" or c.anchor:sub(1, 1) == "R")
    end

    local main = cards[parentTT]
    if not (main and main:IsShown() and not main.cleared) then
        if M.db and M.db.itemCard and parentTT.NumLines and (parentTT:NumLines() or 0) > 0 then
            Build(parentTT)
            main = cards[parentTT]
        end
    end
    if not (main and main:IsShown()) then
        if not hidden[parentTT] and not main then
            Anchor(c, tt)
            return true
        end
        if main and c.anchor and (c.anchor:sub(1, 1) == "L" or c.anchor:sub(1, 1) == "R") then
            return true
        end
        return false
    end

    local ts, ps = tt:GetEffectiveScale() or 1, parentTT:GetEffectiveScale() or 1
    local ml = parentTT:GetLeft()
    local left = DetectCompareSide(c, tt, parentTT, main)
    c.side = left

    local prev = main
    local prevList = COMPARE_PREV[ttName]
    if prevList then
        for _, pn in ipairs(prevList) do
            local ptt = _G[pn]
            local pc = ptt and cards[ptt]
            if pc and pc:IsShown() then
                local pLeft = pc.side
                if pLeft == nil then
                    local pl = ptt:GetLeft()
                    local pts = ptt:GetEffectiveScale() or 1
                    pLeft = (pl and ml and (pl * pts < ml * ps)) and true or false
                end
                if pLeft == left then
                    prev = pc
                    break
                end
            end
        end
    end

    local yOff = 0
    if prev == main and c.eqTab and c.eqTab:IsShown() then
        local mTop, uiTop = main:GetTop(), UIParent:GetTop()
        if mTop and uiTop then
            local mScale = main:GetEffectiveScale() or 1
            local cScale = c:GetEffectiveScale() or 1
            local uiScale = UIParent:GetEffectiveScale() or 1
            local tabTopPx = mTop * mScale + 20 * cScale
            local uiTopPx = uiTop * uiScale
            if tabTopPx > uiTopPx then
                yOff = -math.ceil((tabTopPx - uiTopPx) / cScale)
            end
        end
    end

    local key = (left and "L" or "R") .. tostring(prev) .. ":" .. yOff
    if c.anchor ~= key then
        c.anchor = key
        c:ClearAllPoints()
        if left then c:SetPoint("TOPRIGHT", prev, "TOPLEFT", -6, yOff)
        else c:SetPoint("TOPLEFT", prev, "TOPRIGHT", 6, yOff) end
    end
    return true
end

-- erro do card vai para AzaathUIDB.errorLog (uma vez por mensagem, para não lotar)
local logged = {}
local function LogOnce(msg)
    msg = "ItemCard: " .. tostring(msg)
    if logged[msg] or not Azaath.LogError then return end
    logged[msg] = true
    pcall(Azaath.LogError, msg)
end

local pending = {}
local driver = CreateFrame("Frame")
driver:Hide()
driver.wait = 0

local function ReanchorCompare(main)
    local children = main and COMPARE_CHILDREN[main.GetName and main:GetName() or ""]
    if not children then return end
    for _, cn in ipairs(children) do
        local ctt = _G[cn]
        local cc = ctt and cards[ctt]
        if ctt and ctt:IsShown() then
            if cc and cc:IsShown() then
                AnchorShopping(cc, ctt)
            elseif pending[ctt] then
                Build(ctt)
            end
        end
    end
end

-- true só durante o OnUpdate de um card (ali a tooltip já está completa)
local inUpdate = false
local function BuildNow(tt)
    inUpdate = true
    local ok, err = pcall(Build, tt)
    inUpdate = false
    if not ok then LogOnce(err) end
end

Build = function(tt)
    if not M.db or not M.db.itemCard then return end
    if IsCompareSuppressed(tt) then
        Restore(tt)
        if tt:IsShown() then tt:Hide() end
        return
    end
    -- Mesma tooltip sendo reprocessada com o MESMO item (ciclo de 0,2 s do leilão, refresh das
    -- bolsas): as pós-chamadas do ProcessInfo rodam antes de a Blizzard terminar a tooltip (as
    -- linhas "Se substituir esse item..." da comparação e as do leilão vêm DEPOIS). Montar aqui
    -- desenhava o card pela metade por um quadro (encolhia e voltava). O card fica como está e é
    -- refeito uma vez no OnUpdate do quadro seguinte, já com a tooltip completa.
    local cur = cards[tt]
    if not inUpdate and cur and cur:IsShown() and cur.link then
        local name = tt:GetName()
        local ok0, link = pcall(GetTooltipLink, tt, name or "")
        if ok0 and link and link == cur.link then
            cur.rebuild = true
            if hidden[tt] and tt:GetAlpha() > 0 then tt:SetAlpha(0) end
            return
        end
    end
    local ok, d = pcall(ReadTooltip, tt)
    if not ok then LogOnce(d) end
    if not ok or not d then Restore(tt); return end
    local c = cards[tt]
    if not c then
        c = NewCard()
        c.tt = tt
        c:SetScript("OnUpdate", function(self, dt)
            if not self.tt:IsShown() then
                if self.graceUntil and GetTime() < self.graceUntil then return end
                if HoldCompare(self) then return end
                self.graceUntil, self.holdUntil = nil, nil
                Restore(self.tt)
                self.hiddenAt = GetTime()
                return
            end
            self.graceUntil, self.holdUntil = nil, nil
            if self.cleared then
                if M.db and M.db.itemCard and self.tt.NumLines and (self.tt:NumLines() or 0) > 0 then
                    BuildNow(self.tt)
                else
                    Restore(self.tt)
                end
                if not self:IsShown() then return end
            end
            if self.rebuild then self.rebuild = nil; BuildNow(self.tt) end
            if not self:IsShown() then return end
            -- o jogo pode devolver a opacidade da tooltip (esmaecer/atualizar): mantém invisível
            if hidden[self.tt] and self.tt:GetAlpha() > 0 then self.tt:SetAlpha(0) end
            if self:GetFrameLevel() <= self.tt:GetFrameLevel() then
                self:SetFrameLevel(self.tt:GetFrameLevel() + 20)
            end
            if COMPARE_PARENT[self.tt:GetName() or ""] then
                AnchorShopping(self, self.tt)
            else
                Anchor(self, self.tt)
            end
            UpdateFX(self, dt)
        end)
        cards[tt] = c
    end
    c.cleared = nil
    local stale = c.hiddenAt and GetTime and (GetTime() - c.hiddenAt) > 0.05
    if c.link ~= d.link or stale then                 -- item novo (ou reaberto): zera as fagulhas
        for _, p in ipairs(c.parts) do p.alive = false; p.tex:Hide() end
        c.acc, c.t = 0, 0
    end
    c.hiddenAt = nil
    c.link = d.link
    c.q = RARITY[d.quality] or RARITY[1]
    -- comparação: menor e com a aba "Equipado" (o jogo desenha a dele fora das linhas)
    local ttName = tt:GetName() or ""
    local compare = COMPARE_PARENT[ttName] ~= nil
    if compare then d.equipped = d.equipped or _G.CURRENTLY_EQUIPPED or "Equipado" end
    if c.closeBtn then
        local isRef = (tt == _G.ItemRefTooltip)
        c.closeBtn:SetShown(isRef)
        c.nameFS:ClearAllPoints()
        c.nameFS:SetPoint("TOPLEFT", c.iconBG, "TOPRIGHT", 9, -1)
        c.nameFS:SetPoint("RIGHT", c.head, "RIGHT", isRef and -26 or -8, 0)
    end
    c:SetScale((M.db.itemCardScale or 1) * (compare and 0.8 or 1))
    local ok2, err = pcall(Layout, c, d)
    if not ok2 then LogOnce(err); Restore(tt); return end
    c.anchor = nil
    hidden[tt] = true
    tt:SetAlpha(0)
    if compare then
        local main = cards[_G[COMPARE_PARENT[ttName]]]
        c.parentLink = main and main.link
        c.holdUntil = nil
        if IsCompareSuppressed(tt) then
            Restore(tt)
            return
        end
        if not AnchorShopping(c, tt) then
            pending[tt] = true
            driver.wait = 0
            driver:Show()
            return
        end
        if not tt:IsShown() then
            -- O TooltipComparisonManager preenche a comparação (ProcessInfo) antes de mostrá-la
            -- (AnchorShoppingTooltips): um card que já está na tela fica e espera o OnShow; apagá-lo
            -- aqui fazia o card "Equipado" piscar a cada atualização da tooltip no leilão.
            if not c:IsShown() then Restore(tt) end
            pending[tt] = true
            driver.wait = 0
            driver:Show()
            return
        end
    else
        Anchor(c, tt)
    end
    c:Show()
    if COMPARE_CHILDREN[ttName] then
        if IsShowingEquipped(tt) then
            HideCompareOf(tt)
        else
            ReanchorCompare(tt)
        end
    end
end

local HookTooltip

local function OnItem(tt)
    if not tt then return end
    local name = tt.GetName and tt:GetName()
    if not (name and WATCHED[name]) then return end
    HookTooltip(tt)
    Build(tt)
    local c = cards[tt]
    if c and c:IsShown() then c.rebuild = true end   -- pega linhas de outros addons no próximo quadro
end

-- Rede de segurança: as comparações podem ser preenchidas/limpas por caminhos que não passam
-- pelos ganchos acima. Enquanto uma tooltip vigiada está aberta sem card, tenta de novo (0,1 s).
driver:SetScript("OnUpdate", function(self, dt)
    self.wait = self.wait - dt
    if self.wait > 0 then return end
    self.wait = 0.1
    local any = false
    for tt in pairs(pending) do
        if not tt:IsShown() then
            pending[tt] = nil
        elseif M.db and M.db.itemCard and IsCompareSuppressed(tt) then
            Restore(tt)
            tt:Hide()
            pending[tt] = nil
        else
            any = true
            local c = cards[tt]
            if M.db.itemCard and not (c and c:IsShown()) then Build(tt) end
        end
    end
    if not any then self:Hide() end
end)

local function OnTooltipShow(tt)
    if M.db and M.db.itemCard and IsCompareSuppressed(tt) then
        Restore(tt)
        tt:Hide()
        return
    end
    local c = cards[tt]
    if c and c.cleared then
        if M.db and M.db.itemCard and tt.NumLines and (tt:NumLines() or 0) > 0 then
            Build(tt)
        else
            Restore(tt)
        end
    end
    pending[tt] = true
    driver.wait = 0
    driver:Show()
    c = cards[tt]
    if M.db and M.db.itemCard and not (c and c:IsShown()) and tt.NumLines and (tt:NumLines() or 0) > 0 then
        Build(tt)
    end
end

local function SyncCompare(main)
    if M.db and M.db.itemCard and IsShowingEquipped(main) then
        HideCompareOf(main)
        return
    end
    local children = main and COMPARE_CHILDREN[main.GetName and main:GetName() or ""]
    if not children then return end
    for _, cn in ipairs(children) do
        local ctt = _G[cn]
        if ctt then
            HookTooltip(ctt)
            if ctt:IsShown() then
                local cc = cards[ctt]
                local link = cc and cc:IsShown() and not cc.cleared and GetTooltipLink(ctt, cn)
                if link and link == cc.link then
                    AnchorShopping(cc, ctt)
                else
                    OnItem(ctt)
                end
            elseif cards[ctt] then
                -- GameTooltip_ShowCompareItem só PEDE a comparação (C_TooltipComparison.CompareItem);
                -- ela chega depois, por evento. Neste gancho a tooltip "Equipado" ainda está fechada
                -- (a GameTooltip_Hide do leilão a fecha a cada 0,2 s): apagar o card aqui o fazia
                -- piscar. Card na tela com o mesmo item no principal espera (HoldCompare); o
                -- OnUpdate dele o tira se a comparação não voltar.
                local cc = cards[ctt]
                if not (cc:IsShown() and HoldCompare(cc)) then Restore(ctt) end
            end
        end
    end
end

local hooked = {}
HookTooltip = function(tt)
    if not tt or hooked[tt] then return end
    hooked[tt] = true
    tt:HookScript("OnHide", OnTooltipHide)
    tt:HookScript("OnShow", OnTooltipShow)
    -- Enquanto o card cobre a tooltip, ela fica invisível já na mesma chamada que a
    -- reexibe: a lista do leilão refaz a tooltip (SetOwner/Show) a cada 0,2 s e a cada
    -- leva da varredura; se a opacidade voltasse e só fosse zerada no OnUpdate do card,
    -- o quadro intermediário desenharia a tooltip da Blizzard piscando atrás do card.
    local guard = false
    local function KeepHidden(self)
        if guard or not hidden[self] or self:GetAlpha() == 0 then return end
        guard = true
        self:SetAlpha(0)
        guard = false
    end
    hooksecurefunc(tt, "SetAlpha", KeepHidden)
    if tt.Show then hooksecurefunc(tt, "Show", KeepHidden) end
    if tt.SetOwner then hooksecurefunc(tt, "SetOwner", KeepHidden) end
    if tt:HasScript("OnTooltipCleared") then tt:HookScript("OnTooltipCleared", OnTooltipCleared) end
    if tt:HasScript("OnTooltipSetItem") then tt:HookScript("OnTooltipSetItem", OnItem) end
    if COMPARE_CHILDREN[tt:GetName() or ""] and tt.SetInventoryItem then
        hooksecurefunc(tt, "SetInventoryItem", function(self, unit, slot)
            if Azaath.IsSecret(unit) or Azaath.IsSecret(slot) then return end
            local n = tonumber(slot)
            if unit == "player" and n and n >= 1 and n <= 19 then
                equippedOwner[self] = true
                if M.db and M.db.itemCard then HideCompareOf(self) end
            end
        end)
    end
    if tt.ShowCompareItem then
        hooksecurefunc(tt, "ShowCompareItem", SyncCompare)
    end
end

function M:ApplyConfig()
    if not self.db.itemCard then
        for tt in pairs(cards) do Restore(tt) end
    end
end

function M:OnInitialize()
    self.db = Azaath.db.skins
end

function M:OnEnable()
    BuildPatterns()
    for _, n in ipairs(TOOLTIPS) do
        HookTooltip(_G[n])
    end
    if _G.GameTooltip_ShowCompareItem then
        hooksecurefunc("GameTooltip_ShowCompareItem", function(tt)
            SyncCompare(tt or _G.GameTooltip)
        end)
    end
    if _G.TooltipComparisonManager then
        if TooltipComparisonManager.CompareItem then
            hooksecurefunc(TooltipComparisonManager, "CompareItem", function(_, _, tt)
                SyncCompare(tt or _G.GameTooltip)
            end)
        end
        -- comparação desligada com a tooltip principal aberta (ex.: soltou o Shift): o card
        -- "Equipado" sai já, sem a espera do HoldCompare. Vindo do OnHide (tooltip fechando,
        -- como no ciclo de 0,2 s do leilão), a principal já está fechada e nada muda aqui.
        if TooltipComparisonManager.Clear then
            hooksecurefunc(TooltipComparisonManager, "Clear", function(_, tt)
                if not (tt and tt.IsShown and tt:IsShown()) then return end
                local children = COMPARE_CHILDREN[tt.GetName and tt:GetName() or ""]
                for _, cn in ipairs(children or {}) do
                    local ctt = _G[cn]
                    if ctt and cards[ctt] and not ctt:IsShown() then Restore(ctt) end
                end
            end)
        end
        if TooltipComparisonManager.AnchorShoppingTooltips then
            hooksecurefunc(TooltipComparisonManager, "AnchorShoppingTooltips", function(mgr)
                ReanchorCompare(mgr and mgr.tooltip or _G.GameTooltip)
            end)
        end
    end
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt, data)
            if not tt then return end
            local name = tt.GetName and tt:GetName()
            if name and WATCHED[name] then
                lastData[tt] = data
                OnItem(tt)
            end
        end)
    end
end
