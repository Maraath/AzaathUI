--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Loot.lua
    Saque no estilo Azaath:
      * Saque automático: ao abrir um corpo/nó de coleta, tudo é pego na hora,
        sem janela. Shift (tecla de "alternar saque automático") inverte.
      * Notificações "+1 Madeira Verde": ícone redondo e quantidade, uma linha
        por item recebido, que aparecem, ficam alguns segundos e somem.
        Vale para saque, coleta, criação, recompensas e moedas/dinheiro.
      * Janela de saque (painel carvão com borda dourada): aparece quando o
        modo automático está desligado no painel (/azaath) ou quando sobrou
        item no corpo (inventário cheio) para você escolher o que pegar.
      * Desativa e substitui a janela clássica da Blizzard (LootFrame).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("Loot")

local _G = _G
local ipairs, pairs, format, min, max = ipairs, pairs, string.format, math.min, math.max
local tinsert, tremove = table.insert, table.remove
local API = Azaath.API

local PAD       = 14
local HEADER_H  = 40
local ROW_H     = 42
local FOOTER_H  = 34
local SPACING   = 4
local ICON_SIZE = 34

local frame, headerTitle, slotsContainer, lootAllBtn
local rows = {}

local function SafeNumber(v, fallback)
    if v == nil or Azaath.IsSecret(v) then return fallback end
    return v
end

local function Now() return GetTime() end

local function After(sec, fn)
    if _G.C_Timer and C_Timer.After then
        C_Timer.After(sec, fn)
    else
        -- 3.3.5: temporizador simples por OnUpdate
        local t = CreateFrame("Frame")
        local left = sec
        t:SetScript("OnUpdate", function(self, el)
            left = left - el
            if left <= 0 then self:SetScript("OnUpdate", nil); fn() end
        end)
    end
end

local GetItemCount = (_G.C_Item and C_Item.GetItemCount) or _G.GetItemCount

--------------------------------------------------------------------------------
-- Estado da sessão de saque
--------------------------------------------------------------------------------
local lootOpen      = false  -- há um saque aberto no servidor
local sessionHandled = false -- LOOT_READY/LOOT_OPENED já tratados nesta sessão
local autoSession   = false  -- esta sessão foi pega automaticamente (sem janela)
local invFullAt     = 0      -- última vez que o jogo avisou "inventário cheio"
local snapshot      = {}     -- slot -> { name, texture, quantity, link, color }

--------------------------------------------------------------------------------
-- Notificações de saque ("+1 Madeira Verde")
--------------------------------------------------------------------------------
local FEED_ICON  = 40
local FEED_H     = 44
local FEED_GAP   = 6
local FEED_W     = 300
local FADE_IN    = 0.25
local FADE_OUT   = 0.6

local QUESTION   = "Interface\\Icons\\INV_Misc_QuestionMark"

local feed
local feedPool, feedActive = {}, {}

local function FeedDB() return M.db or {} end

local function CreateFeedEntry()
    local c, media = Azaath.colors, Azaath.media
    local e = CreateFrame("Frame", nil, feed)
    e:SetWidth(FEED_W)
    e:SetHeight(FEED_H)

    -- espaço redondo escuro (mesma arte dos materiais no inventário)
    local slot = e:CreateTexture(nil, "BACKGROUND")
    slot:SetTexture(media.path .. "Inventory\\SlotRound")
    slot:SetWidth(FEED_ICON + 4)
    slot:SetHeight(FEED_ICON + 4)
    slot:SetPoint("LEFT", e, "LEFT", 0, 0)
    e.slot = slot

    local icon = e:CreateTexture(nil, "BORDER")
    icon:SetPoint("TOPLEFT", slot, "TOPLEFT", 6, -6)
    icon:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -6, 6)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    e.icon = icon

    if e.CreateMaskTexture then
        local mask = e:CreateMaskTexture()
        mask:SetTexture(media.path .. "Inventory\\RoundMask", "CLAMPTOBLACKADDITIONAL", "CLAMPTOBLACKADDITIONAL")
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end

    -- aro na cor da raridade
    local ring = e:CreateTexture(nil, "ARTWORK")
    ring:SetTexture(media.path .. "Ring")
    ring:SetPoint("TOPLEFT", slot, "TOPLEFT", 1, -1)
    ring:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -1, 1)
    e.ring = ring

    -- brilho suave extra para itens raros
    local glow = e:CreateTexture(nil, "OVERLAY")
    glow:SetTexture(media.path .. "Ring")
    glow:SetPoint("TOPLEFT", slot, "TOPLEFT", -2, 2)
    glow:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", 2, -2)
    glow:SetBlendMode("ADD")
    glow:Hide()
    e.glow = glow

    -- total que você tem nas bolsas (canto inferior do ícone)
    local total = e:CreateFontString(nil, "OVERLAY")
    total:SetFont(media.fontBold or media.font, 10, "OUTLINE")
    total:SetPoint("BOTTOM", slot, "BOTTOM", 0, 1)
    total:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    e.total = total

    local amount = e:CreateFontString(nil, "OVERLAY")
    amount:SetFont(media.fontBold or media.font, 17, "")
    amount:SetShadowOffset(1, -1)
    amount:SetShadowColor(0, 0, 0, 0.9)
    amount:SetPoint("LEFT", slot, "RIGHT", 10, 0)
    amount:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    e.amount = amount

    local name = e:CreateFontString(nil, "OVERLAY")
    name:SetFont(media.font, 17, "")
    name:SetShadowOffset(1, -1)
    name:SetShadowColor(0, 0, 0, 0.9)
    name:SetPoint("LEFT", amount, "RIGHT", 10, 0)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    e.name = name

    return e
end

local function FeedTargets()
    for i, e in ipairs(feedActive) do
        e.targetY = -((i - 1) * (FEED_H + FEED_GAP))
    end
end

local function Feed_OnUpdate(self, elapsed)
    local db = FeedDB()
    local hold = db.feedDuration or 5
    local maxN = db.feedMax or 6
    local removed = false

    for i = #feedActive, 1, -1 do
        local e = feedActive[i]
        e.age = e.age + elapsed
        -- além do limite, a mais antiga começa a sumir logo
        if i > maxN and e.age < FADE_IN + hold then
            e.age = FADE_IN + hold
        end

        local alpha, dx
        if e.age < FADE_IN then
            local t = e.age / FADE_IN
            alpha, dx = t, (1 - t) * 24
        elseif e.age < FADE_IN + hold then
            alpha, dx = 1, 0
        else
            local t = (e.age - FADE_IN - hold) / FADE_OUT
            alpha, dx = 1 - t, 0
        end

        if alpha <= 0 then
            e:Hide()
            tremove(feedActive, i)
            feedPool[#feedPool + 1] = e
            removed = true
        else
            e.curY = e.curY + (e.targetY - e.curY) * min(1, elapsed * 12)
            e:SetAlpha(alpha)
            e:ClearAllPoints()
            e:SetPoint("TOPLEFT", feed, "TOPLEFT", dx, e.curY)
        end
    end

    if removed then FeedTargets() end
    if #feedActive == 0 then self:SetScript("OnUpdate", nil) end
end

local HEX_TO_QUALITY = {
    ["9d9d9d"] = 0, -- Pobre / Cinza
    ["ffffff"] = 1, -- Comum / Branco
    ["1eff00"] = 2, -- Incomum / Verde
    ["0070dd"] = 3, -- Raro / Azul
    ["0070ff"] = 3, -- Raro / Azul (alternativo)
    ["a335ee"] = 4, -- Épico / Roxo
    ["ff8000"] = 5, -- Lendário / Laranja
    ["e6cc80"] = 6, -- Artefato / Dourado
    ["00ccff"] = 7, -- Herança / Azul claro
    ["00cccc"] = 7,
}

local QUALITY_COLORS = {
    [0] = { 0.62, 0.62, 0.62 },
    [1] = { 1.00, 1.00, 1.00 },
    [2] = { 0.12, 1.00, 0.00 },
    [3] = { 0.00, 0.44, 0.87 },
    [4] = { 0.64, 0.21, 0.93 },
    [5] = { 1.00, 0.50, 0.00 },
    [6] = { 0.90, 0.80, 0.50 },
    [7] = { 0.00, 0.80, 1.00 },
}

local function GetQualityRGB(q)
    if type(q) == "number" then
        if API.GetItemQualityColor then
            local ok, qr, qg, qb = pcall(API.GetItemQualityColor, q)
            if ok then
                if type(qr) == "table" then
                    return qr.r or 1, qr.g or 1, qr.b or 1
                elseif type(qr) == "number" then
                    return qr, qg or 1, qb or 1
                end
            end
        end
        if QUALITY_COLORS[q] then
            return unpack(QUALITY_COLORS[q])
        end
    end
    return 1, 1, 1
end

local function HexToRGB(hex)
    if not hex or #hex < 6 then return nil end
    hex = hex:sub(-6)
    return tonumber(hex:sub(1, 2), 16) / 255, tonumber(hex:sub(3, 4), 16) / 255, tonumber(hex:sub(5, 6), 16) / 255
end

-- data = { texture, name, amount (number ou texto), r, g, b (cor do nome), link, quality, rare }
local function PushFeed(data)
    local db = FeedDB()
    if not feed or not db.feed then return end
    local c = Azaath.colors

    local e = tremove(feedPool) or CreateFeedEntry()
    e.icon:SetTexture(data.texture or QUESTION)
    if type(data.amount) == "number" then
        e.amount:SetText("+" .. data.amount)
    else
        e.amount:SetText(data.amount or "")
    end
    e.name:SetText(data.name or "")

    local r, g, b = data.r, data.g, data.b
    if type(r) == "table" then
        r, g, b = r.r, r.g, r.b
    end
    if not r or type(r) ~= "number" then
        if data.quality then
            r, g, b = GetQualityRGB(data.quality)
        elseif data.link then
            local q = QualityFromLink and QualityFromLink(data.link)
            if q then r, g, b = GetQualityRGB(q) end
        end
    end
    if not r or type(r) ~= "number" then r, g, b = c.cream[1], c.cream[2], c.cream[3] end

    local isRare = data.rare
    if isRare == nil and data.quality then
        isRare = (data.quality >= 2)
    end
    if isRare == nil and data.link and QualityFromLink then
        local q = QualityFromLink(data.link)
        if q and q >= 2 then isRare = true end
    end

    e.name:SetTextColor(r, g, b)
    if isRare then
        e.slot:SetVertexColor(1 + (r - 1) * 0.45, 1 + (g - 1) * 0.45, 1 + (b - 1) * 0.45, 1)
        e.ring:SetBlendMode("ADD")
        e.ring:SetVertexColor(r, g, b)
        e.ring:SetAlpha(0.95)
        if e.glow then
            e.glow:SetVertexColor(r, g, b)
            e.glow:SetAlpha(0.65)
            e.glow:Show()
        end
    else
        e.slot:SetVertexColor(1, 1, 1, 0.75)
        e.ring:SetBlendMode("BLEND")
        e.ring:SetVertexColor(c.slate[1], c.slate[2], c.slate[3])
        e.ring:SetAlpha(0.6)
        if e.glow then
            e.glow:Hide()
        end
    end

    e.total:SetText("")
    e.link = data.link
    if data.link and GetItemCount then
        -- as bolsas ainda não foram atualizadas quando o aviso chega
        After(0.4, function()
            if e.link == data.link and e:IsShown() then
                local ok, n = pcall(GetItemCount, data.link)
                if ok and type(n) == "number" and not Azaath.IsSecret(n) and n > 1 then
                    e.total:SetText(n)
                end
            end
        end)
    end

    e.age = 0
    e.curY = 0
    e.targetY = 0
    e:SetAlpha(0)
    e:ClearAllPoints()
    e:SetPoint("TOPLEFT", feed, "TOPLEFT", 24, 0)
    e:Show()

    tinsert(feedActive, 1, e) -- mais recente no topo
    -- as demais descem a partir de onde estavam
    FeedTargets()
    feed:SetScript("OnUpdate", Feed_OnUpdate)
end
M.PushFeed = PushFeed

local function BuildFeed()
    if feed then return end
    local db = M.db
    feed = CreateFrame("Frame", "AzaathUILootFeed", UIParent)
    feed:SetFrameStrata("MEDIUM")
    feed:SetWidth(FEED_W)
    feed:SetHeight((FEED_H + FEED_GAP) * 4)
    feed:EnableMouse(false)
    feed:SetScale((db.feedScale and db.feedScale > 0) and db.feedScale or 1)
    feed:SetPoint("CENTER", UIParent, "CENTER", db.feedX or 330, db.feedY or -60)
    if Azaath.ClampToScreen then Azaath.ClampToScreen(feed) end
end

--------------------------------------------------------------------------------
-- Leitura das mensagens de saque do chat
-- "Você recebe saque: [Madeira Verde]x2." -> link + quantidade
--------------------------------------------------------------------------------
local function FormatToPattern(fmt)
    local p = fmt:gsub("%%%d?%$?s", "\001"):gsub("%%%d?%$?d", "\002")
    p = p:gsub("[%(%)%.%%%+%-%*%?%[%]%^%$]", "%%%0")
    p = p:gsub("\001", "(.+)"):gsub("\002", "(%%d+)")
    return "^" .. p .. "$"
end

-- versões "MULTIPLE" primeiro: a simples também casaria "...x2."
local ITEM_STRINGS = {
    "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_SELF",
    "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF",
    "LOOT_ITEM_CREATED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF",
    "LOOT_ITEM_BONUS_ROLL_SELF_MULTIPLE", "LOOT_ITEM_BONUS_ROLL_SELF",
    "LOOT_ITEM_REFUND_MULTIPLE", "LOOT_ITEM_REFUND",
    "CURRENCY_GAINED_MULTIPLE_BONUS", "CURRENCY_GAINED_MULTIPLE", "CURRENCY_GAINED",
}
local patterns

local function BuildPatterns()
    patterns = {}
    for _, key in ipairs(ITEM_STRINGS) do
        local s = _G[key]
        if type(s) == "string" and s ~= "" then
            patterns[#patterns + 1] = FormatToPattern(s)
        end
    end
end

-- devolve link, quantidade (ou nil se a mensagem não é de algo que VOCÊ recebeu)
local function ParseSelfLoot(msg)
    if not patterns then BuildPatterns() end
    for _, pat in ipairs(patterns) do
        local a, b = msg:match(pat)
        if a then
            local link, qty
            for _, v in ipairs({ a, b }) do
                if v and v:find("|H", 1, true) then link = v
                elseif v and v:match("^%d+$") then qty = tonumber(v) end
            end
            if link then return link, qty or 1 end
        end
    end
end

local function CurrencyIcon(id)
    local CI = _G.C_CurrencyInfo
    if CI and CI.GetCurrencyInfo then
        local ok, info = pcall(CI.GetCurrencyInfo, id)
        if ok and type(info) == "table" then return info.iconFileID end
    end
    if _G.GetCurrencyInfo then
        local ok, _, _, tex = pcall(GetCurrencyInfo, id)
        if ok then return tex end
    end
end

-- Qualidade confiável do link de item:
-- 1º: verifica diretamente o código hexadecimal na cor do link (imediato e sem depender de cache)
-- 2º: APIs C_Item ou GetItemInfo se disponíveis
local function QualityFromLink(link)
    if not link or Azaath.IsSecret(link) or type(link) ~= "string" then return nil end
    local hex = link:match("|c%x%x(%x%x%x%x%x%x)") or link:match("|c(%x%x%x%x%x%x)")
    if hex then
        hex = hex:lower()
        if HEX_TO_QUALITY[hex] then return HEX_TO_QUALITY[hex] end
    end
    if _G.C_Item and C_Item.GetItemQualityByID then
        local ok, q = pcall(C_Item.GetItemQualityByID, link)
        if ok and type(q) == "number" and not Azaath.IsSecret(q) then return q end
    end
    if _G.GetItemInfo then
        local ok, _, _, q = pcall(GetItemInfo, link)
        if ok and type(q) == "number" and not Azaath.IsSecret(q) then return q end
    end
    -- último recurso: a cor do próprio link via ITEM_QUALITY_COLORS
    if hex and _G.ITEM_QUALITY_COLORS then
        for qi, col in pairs(ITEM_QUALITY_COLORS) do
            if type(col) == "table" then
                if col.GenerateHexColor then
                    local ok, h = pcall(col.GenerateHexColor, col)
                    if ok and h and h:lower():sub(-6) == hex then return qi end
                end
                local h = col.hex and col.hex:match("|c%x%x(%x%x%x%x%x%x)")
                if h and h:lower() == hex then return qi end
            end
        end
    end
    return nil
end

-- Constrói a notificação a partir de um link de item/moeda
local function FeedFromLink(link, qty)
    local name = link:match("|h%[(.-)%]|h") or link
    local texture
    local itemID = link:match("item:(%d+)")
    local currencyID = link:match("currency:(%d+)")

    if itemID then
        if API.GetItemInfoInstant then
            local ok, _, _, _, _, tex = pcall(API.GetItemInfoInstant, link)
            if ok then texture = tex end
        end
        if not texture and API.GetItemInfo then
            local ok, _, _, _, _, _, _, _, _, _, tex = pcall(API.GetItemInfo, link)
            if ok then texture = tex end
        end
    elseif currencyID then
        texture = CurrencyIcon(tonumber(currencyID))
    end

    local quality = QualityFromLink(link)
    local r, g, b
    if quality then
        r, g, b = GetQualityRGB(quality)
    else
        r, g, b = HexToRGB(link:match("|c(%x%x%x%x%x%x%x%x)"))
    end

    local rare = (type(quality) == "number" and quality >= 2)
    if not rare and quality == nil and r then
        -- sem cache: o link já traz a cor da raridade (branco = comum)
        rare = not (r > 0.95 and g > 0.95 and b > 0.95) and not (r < 0.7 and g < 0.7 and b < 0.7)
    end

    PushFeed({
        texture = texture, name = name, amount = qty or 1,
        r = r, g = g, b = b, link = itemID and link or nil, quality = quality, rare = rare,
    })
    return name
end

--------------------------------------------------------------------------------
-- Reserva: se a mensagem do chat vier secreta (cliente moderno em combate de
-- instância), usa o que estava no corpo quando o espaço foi esvaziado.
--------------------------------------------------------------------------------
local pendingSlots = {}   -- { name, data, at }
local lastSecretChat = 0
local recentChat = {}     -- nome -> hora em que o chat já mostrou o item

local function ConsumePending(name)
    for i, p in ipairs(pendingSlots) do
        if p.name == name then
            tremove(pendingSlots, i)
            return true
        end
    end
    return false
end

local function FlushPending()
    local t = Now()
    local solo = not ((_G.IsInGroup and IsInGroup()) or (_G.GetNumPartyMembers and GetNumPartyMembers() > 0))
    for i = #pendingSlots, 1, -1 do
        local p = pendingSlots[i]
        if t - p.at >= 1.0 then
            tremove(pendingSlots, i)
            -- no grupo, outro jogador pode ter pego; só mostra se o chat estava ilegível
            if solo or (t - lastSecretChat) < 3 then
                PushFeed(p.data)
            end
        end
    end
end

local function IsMoneySlot(i)
    if _G.GetLootSlotType then
        local ok, t = pcall(GetLootSlotType, i)
        if ok and type(t) == "number" and not Azaath.IsSecret(t) then
            local money = (_G.Enum and Enum.LootSlotType and Enum.LootSlotType.Money) or _G.LOOT_SLOT_MONEY or 2
            return t == money
        end
    end
    if _G.LootSlotIsCoin then
        local ok, coin = pcall(LootSlotIsCoin, i)
        if ok and not Azaath.IsSecret(coin) then return coin and true or false end
    end
    return false
end

local function SlotQuality(i, quality)
    local q = quality
    if type(q) ~= "number" or Azaath.IsSecret(q) then q = nil end
    local link = API.GetLootSlotLink and API.GetLootSlotLink(i)
    if link and not Azaath.IsSecret(link) then
        local lq = QualityFromLink(link)
        if lq then return lq end
    end
    return q or 1
end

local function SnapshotSlot(i)
    local texture, item, quantity, quality = API.GetLootSlotInfo(i)
    if Azaath.AnySecret(texture, item) or not texture or not item then
        snapshot[i] = nil
        return
    end
    local link = API.GetLootSlotLink and API.GetLootSlotLink(i)
    if link and Azaath.IsSecret(link) then link = nil end
    local isMoney = IsMoneySlot(i)
    local q = SlotQuality(i, quality)
    local r, g, b = GetQualityRGB(q)
    snapshot[i] = {
        isMoney = isMoney,
        name = item,
        data = {
            texture = texture, name = item, amount = SafeNumber(quantity, 1),
            r = r, g = g, b = b, link = link, quality = q, rare = (type(q) == "number" and q >= 2),
        },
    }
end

local function SnapshotAll()
    wipe(snapshot)
    local n = SafeNumber(API.GetNumLootItems and API.GetNumLootItems(), 0) or 0
    for i = 1, n do SnapshotSlot(i) end
end

--------------------------------------------------------------------------------
-- Dinheiro: diferença de GetMoney (sem depender do texto localizado)
--------------------------------------------------------------------------------
local lastMoney
local blockMoney = {}  -- janelas onde ganho de dinheiro não é "saque"

local function MoneyIcon(copper)
    if copper >= 10000 then return "Interface\\Icons\\INV_Misc_Coin_01" end
    if copper >= 100 then return "Interface\\Icons\\INV_Misc_Coin_03" end
    return "Interface\\Icons\\INV_Misc_Coin_05"
end

local function OnMoney()
    local cur = GetMoney and GetMoney()
    if type(cur) ~= "number" or Azaath.IsSecret(cur) then return end
    local prev = lastMoney
    lastMoney = cur
    if not prev or cur <= prev then return end
    for _ in pairs(blockMoney) do return end -- vendedor, correio, troca, leilão
    local gained = cur - prev
    PushFeed({
        texture = MoneyIcon(gained),
        amount = "+" .. Azaath.FormatMoney(gained),
        name = "",
    })
end

--------------------------------------------------------------------------------
-- Janela de saque: criação de linha de item
--------------------------------------------------------------------------------
local function CreateLootRow(index)
    local c, media = Azaath.colors, Azaath.media

    local row = CreateFrame("Button", "AzaathUILootRow" .. index, slotsContainer)
    row:SetHeight(ROW_H)
    row:SetWidth(slotsContainer:GetWidth() or 290)
    Azaath.ApplyPanel(row, 0.85)

    -- Fundo colorido pela raridade
    local tint = row:CreateTexture(nil, "BACKGROUND")
    tint:SetTexture(media.blank)
    tint:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    tint:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    pcall(Azaath.Gradient, tint, "VERTICAL", 1, 1, 1, 0.05, 1, 1, 1, 0.25)
    row.tint = tint

    -- Ícone do item (ARTWORK: por cima da moldura colorida, que fica em BORDER)
    local icon = row:CreateTexture(nil, "ARTWORK")
    icon:SetWidth(ICON_SIZE)
    icon:SetHeight(ICON_SIZE)
    icon:SetPoint("LEFT", row, "LEFT", 4, 0)
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    row.icon = icon

    -- Borda do ícone: quadrado 1px maior ATRÁS do ícone (se ficar na frente, cobre a imagem)
    local iconBorder = row:CreateTexture(nil, "BORDER")
    iconBorder:SetTexture(media.blank)
    iconBorder:SetPoint("TOPLEFT", icon, "TOPLEFT", -1, 1)
    iconBorder:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
    iconBorder:SetVertexColor(c.slate[1], c.slate[2], c.slate[3], 0.7)
    row.iconBorder = iconBorder
    icon:SetParent(row)

    -- Nome do item
    local name = row:CreateFontString(nil, "OVERLAY")
    name:SetFont(media.font, 13, "")
    name:SetPoint("LEFT", icon, "RIGHT", 8, 2)
    name:SetPoint("RIGHT", row, "RIGHT", -36, 2)
    name:SetJustifyH("LEFT")
    name:SetWordWrap(false)
    row.name = name

    -- Quantidade
    local count = row:CreateFontString(nil, "OVERLAY")
    count:SetFont(media.font, 12, "OUTLINE")
    count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", -2, 2)
    count:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    row.count = count

    -- Indicador de Missão
    local quest = row:CreateFontString(nil, "OVERLAY")
    quest:SetFont(media.fontTitleB, 11, "")
    quest:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    quest:SetTextColor(c.gold[1], c.gold[2], c.gold[3])
    quest:SetText("!")
    quest:Hide()
    row.quest = quest

    -- Destaque ao passar o mouse
    local hl = row:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(media.blank)
    hl:SetVertexColor(1, 1, 1)
    hl:SetAlpha(0.1)
    hl:SetAllPoints(row)

    row:SetScript("OnClick", function(self)
        if self.slotID then
            pcall(API.LootSlot, self.slotID)
        end
    end)

    row:SetScript("OnEnter", function(self)
        if not self.slotID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.isItem then
            pcall(GameTooltip.SetLootItem, GameTooltip, self.slotID)
        else
            GameTooltip:SetText(self.rawName or "Saque")
        end
        GameTooltip:Show()
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    rows[index] = row
    return row
end

--------------------------------------------------------------------------------
-- Atualização da Janela de Saque
--------------------------------------------------------------------------------
local function UpdateLoot()
    local numItems = SafeNumber(API.GetNumLootItems and API.GetNumLootItems(), 0) or 0

    if numItems == 0 then
        if frame and frame:IsShown() then frame:Hide() end
        return
    end

    if headerTitle then
        if Now() - invFullAt < 10 then
            headerTitle:SetText("|cffe06a5a" .. Azaath.Tracked("Inventário cheio") .. "|r")
        else
            headerTitle:SetText(Azaath.Tracked(format("Saque (%d)", numItems)))
        end
    end

    local width = (frame and frame:GetWidth() or 320) - PAD * 2
    if slotsContainer then
        slotsContainer:SetWidth(width)
    end

    local visibleCount = 0
    for i = 1, numItems do
        local texture, item, quantity, quality, _, isQuestItem = API.GetLootSlotInfo(i)
        if texture then
            visibleCount = visibleCount + 1
            local row = rows[visibleCount] or CreateLootRow(visibleCount)
            row.slotID = i
            row.rawName = item
            row:SetWidth(width)
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", slotsContainer, "TOPLEFT", 0, -((visibleCount - 1) * (ROW_H + SPACING)))
            row:Show()

            row.icon:SetTexture(texture)
            local qty = SafeNumber(quantity, 1)
            if qty and type(qty) == "number" and qty > 1 then
                row.count:SetText(qty)
                row.count:Show()
            else
                row.count:Hide()
            end

            -- Determina se é item ou moeda
            local link = API.GetLootSlotLink and API.GetLootSlotLink(i)
            row.isItem = (link ~= nil) or (_G.LootSlotIsItem and _G.LootSlotIsItem(i)) or (_G.LootSlotHasItem and _G.LootSlotHasItem(i))

            -- Cor de raridade
            local q = SlotQuality(i, quality)
            local r, g, bl = GetQualityRGB(q)
            if q == 0 then
                r, g, bl = 0.5, 0.5, 0.5
            elseif q == 1 then
                r, g, bl = 1, 1, 1
            end

            row.name:SetText(item or "Item")
            row.name:SetTextColor(r, g, bl)
            row:SetBackdropBorderColor(r, g, bl, (type(q) == "number" and q >= 2) and 0.95 or 0.5)
            row.iconBorder:SetVertexColor(r, g, bl, (type(q) == "number" and q >= 2) and 1.0 or 0.7)

            if type(q) == "number" and q >= 2 then
                pcall(Azaath.Gradient, row.tint, "VERTICAL", r, g, bl, 0.08, r, g, bl, 0.35)
                row.tint:Show()
            else
                row.tint:Hide()
            end

            if isQuestItem then
                row.quest:Show()
            else
                row.quest:Hide()
            end
        end
    end

    for i = visibleCount + 1, #rows do
        rows[i]:Hide()
    end

    if visibleCount == 0 then
        if frame and frame:IsShown() then frame:Hide() end
        return
    end

    local totalH = HEADER_H + 10 + (visibleCount * (ROW_H + SPACING)) + FOOTER_H + PAD
    slotsContainer:SetHeight(max(1, visibleCount * (ROW_H + SPACING)))
    frame:SetHeight(totalH)
    frame:Show()
end

local function LootAll()
    local n = SafeNumber(API.GetNumLootItems and API.GetNumLootItems(), 0) or 0
    -- de trás para frente: pegar um espaço não reordena os anteriores
    for i = n, 1, -1 do
        pcall(API.LootSlot, i)
    end
end

--------------------------------------------------------------------------------
-- Construção do Frame
--------------------------------------------------------------------------------
local function Build()
    if frame then return end
    local c, media = Azaath.colors, Azaath.media
    local w = M.db.width or 320

    frame = CreateFrame("Frame", "AzaathUILoot", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetScale((M.db.scale and M.db.scale > 0) and M.db.scale or 1)
    frame:SetWidth(w)
    frame:SetHeight(120)
    Azaath.ApplyPanel(frame, 0.95)
    frame:SetPoint("CENTER", UIParent, "CENTER", M.db.offsetX or 180, M.db.offsetY or 20)
    frame:Hide()
    tinsert(UISpecialFrames, "AzaathUILoot")

    -- Cabeçalho
    local header = CreateFrame("Frame", nil, frame)
    header:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    header:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    header:SetHeight(HEADER_H)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function() frame:StartMoving() end)
    header:SetScript("OnDragStop", function() frame:StopMovingOrSizing() end)

    local band = header:CreateTexture(nil, "BACKGROUND")
    band:SetTexture(media.blank)
    band:SetVertexColor(0.11, 0.135, 0.16)
    band:SetAlpha(0.95)
    band:SetAllPoints(header)

    headerTitle = header:CreateFontString(nil, "OVERLAY")
    headerTitle:SetFont(media.fontTitleB, 15, "")
    headerTitle:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    headerTitle:SetPoint("LEFT", header, "LEFT", PAD, 2)
    headerTitle:SetText(Azaath.Tracked("Saque"))

    local close = CreateFrame("Button", nil, header)
    close:SetWidth(20)
    close:SetHeight(20)
    close:SetPoint("RIGHT", header, "RIGHT", -10, 2)
    local x = close:CreateFontString(nil, "OVERLAY")
    x:SetFont(media.font, 16, "")
    x:SetTextColor(c.dim[1], c.dim[2], c.dim[3])
    x:SetPoint("CENTER", close, "CENTER", 0, 0)
    x:SetText("X")
    close:SetScript("OnClick", function()
        if API.CloseLoot then pcall(API.CloseLoot) end
        frame:Hide()
    end)
    close:SetScript("OnEnter", function() x:SetTextColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() x:SetTextColor(c.dim[1], c.dim[2], c.dim[3]) end)

    local line = frame:CreateTexture(nil, "ARTWORK")
    line:SetTexture(media.blank)
    pcall(Azaath.Gradient, line, "HORIZONTAL", c.gold[1], c.gold[2], c.gold[3], 0.8, c.gold[1], c.gold[2], c.gold[3], 0.1)
    line:SetHeight(2)
    line:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    line:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)

    -- Contêiner dos Itens
    slotsContainer = CreateFrame("Frame", nil, frame)
    slotsContainer:SetPoint("TOPLEFT", header, "BOTTOMLEFT", PAD, -8)
    slotsContainer:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", -PAD, -8)
    slotsContainer:SetHeight(ROW_H)

    -- Botão "Saquear Tudo"
    lootAllBtn = CreateFrame("Button", nil, frame)
    lootAllBtn:SetHeight(24)
    lootAllBtn:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", PAD, 8)
    lootAllBtn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -PAD, 8)
    Azaath.ApplyPanel(lootAllBtn, 0.9)

    local allText = lootAllBtn:CreateFontString(nil, "OVERLAY")
    allText:SetFont(media.fontTitleB, 11, "")
    allText:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    allText:SetPoint("CENTER", lootAllBtn, "CENTER", 0, 0)
    allText:SetText(Azaath.Tracked("Saquear Tudo"))

    lootAllBtn:SetScript("OnClick", LootAll)
    lootAllBtn:SetScript("OnEnter", function() allText:SetTextColor(1, 1, 1) end)
    lootAllBtn:SetScript("OnLeave", function() allText:SetTextColor(c.cream[1], c.cream[2], c.cream[3]) end)

    frame:SetScript("OnHide", function()
        if lootOpen and API.CloseLoot then pcall(API.CloseLoot) end
    end)
end

--------------------------------------------------------------------------------
-- Saque automático
--------------------------------------------------------------------------------
local function WantsAuto()
    local auto = M.db.autoLoot ~= false
    -- Shift (ou a tecla configurada) inverte, como no saque automático da Blizzard
    if _G.IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") then auto = not auto end
    return auto
end

local sessionStart, lastSlotActivity, retried = 0, 0, false

local function ShowLeftovers()
    if M.db.showWhenFull ~= false then
        Build()
        UpdateLoot()
    elseif API.CloseLoot then
        pcall(API.CloseLoot)
    end
end

-- Depois de tentar pegar tudo: sobrou algo que dá para pegar?
-- O servidor libera os espaços um a um; com vários itens isso leva mais que
-- alguns décimos de segundo. A janela só abre quando os espaços pararam de
-- sumir E há um motivo real (inventário cheio, item que não deu para pegar).
local CheckLeftovers
CheckLeftovers = function()
    if not lootOpen or not autoSession then return end
    if frame and frame:IsShown() then return end
    local n = SafeNumber(API.GetNumLootItems and API.GetNumLootItems(), 0) or 0
    local free = false
    for i = 1, n do
        local texture, _, _, _, isLocked = API.GetLootSlotInfo(i)
        if texture and not isLocked then free = true break end
    end
    if not free then
        -- só itens em rolagem do grupo: nada a escolher aqui
        if n > 0 and API.CloseLoot then pcall(API.CloseLoot) end
        return
    end

    if Now() - lastSlotActivity < 0.6 then
        After(0.3, CheckLeftovers) -- o servidor ainda está entregando os itens
        return
    end
    if invFullAt >= sessionStart then
        ShowLeftovers() -- o jogo avisou "inventário cheio"
        return
    end
    if not retried then
        retried = true          -- pedido perdido/lento: tenta mais uma vez
        LootAll()
        lastSlotActivity = Now()
        After(0.6, CheckLeftovers)
        return
    end
    if _G.StaticPopup_Visible and StaticPopup_Visible("LOOT_BIND") then
        After(0.5, CheckLeftovers) -- esperando você confirmar item vinculado
        return
    end
    ShowLeftovers()
end

local function OnLootStart()
    lootOpen = true
    SnapshotAll()
    if sessionHandled then
        -- LOOT_OPENED depois do LOOT_READY: só atualiza a janela se já aberta
        if frame and frame:IsShown() then UpdateLoot() end
        return
    end
    sessionHandled = true

    if WantsAuto() then
        autoSession = true
        sessionStart, lastSlotActivity, retried = Now(), Now(), false
        LootAll()
        After(0.5, CheckLeftovers)
    else
        autoSession = false
        Build()
        UpdateLoot()
    end
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local BLOCK_OPEN = {
    MERCHANT_SHOW = "merchant", MAIL_SHOW = "mail", TRADE_SHOW = "trade",
    AUCTION_HOUSE_SHOW = "auction",
}
local BLOCK_CLOSE = {
    MERCHANT_CLOSED = "merchant", MAIL_CLOSED = "mail", TRADE_CLOSED = "trade",
    AUCTION_HOUSE_CLOSED = "auction",
}

-- moderno: (tipo, mensagem); 3.3.5: (mensagem)
local function IsInvFullMessage(...)
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "string" and not Azaath.IsSecret(v)
            and (v == _G.ERR_INV_FULL or v == _G.ERR_ITEM_MAX_COUNT) then
            return true
        end
    end
    return false
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, arg1, ...)
    local windowOn = M.db.enabled
    if event == "LOOT_READY" or event == "LOOT_OPENED" then
        if windowOn then OnLootStart() end
    elseif event == "LOOT_SLOT_CLEARED" then
        lastSlotActivity = Now()
        local s = arg1 and snapshot[arg1]
        -- só itens com link (dinheiro vem pelo PLAYER_MONEY)
        if s and not s.isMoney and s.data.link and M.db.feed then
            local shown = recentChat[s.name]
            if shown and Now() - shown < 2 then
                -- o chat chegou antes e já mostrou este item
                recentChat[s.name] = nil
            else
                pendingSlots[#pendingSlots + 1] = { name = s.name, data = s.data, at = Now() }
                After(1.05, FlushPending)
            end
        end
        if arg1 then snapshot[arg1] = nil end
        if frame and frame:IsShown() then UpdateLoot() end
    elseif event == "LOOT_SLOT_CHANGED" then
        if arg1 then SnapshotSlot(arg1) end
        if frame and frame:IsShown() then UpdateLoot() end
    elseif event == "LOOT_CLOSED" then
        lootOpen, sessionHandled, autoSession = false, false, false
        if frame and frame:IsShown() then frame:Hide() end
    elseif event == "CHAT_MSG_LOOT" or event == "CHAT_MSG_CURRENCY" then
        if type(arg1) ~= "string" or Azaath.IsSecret(arg1) then
            lastSecretChat = Now()
            return
        end
        local link, qty = ParseSelfLoot(arg1)
        if link then
            local name = FeedFromLink(link, qty)
            if not ConsumePending(name) then
                recentChat[name] = Now()
            end
        end
    elseif event == "PLAYER_MONEY" then
        OnMoney()
    elseif event == "UI_ERROR_MESSAGE" then
        if IsInvFullMessage(arg1, ...) then
            invFullAt = Now()
            if frame and frame:IsShown() then
                UpdateLoot()
            elseif lootOpen and autoSession then
                -- espera os demais itens chegarem antes de mostrar o que sobrou
                After(0.3, CheckLeftovers)
            end
        end
    elseif BLOCK_OPEN[event] then
        blockMoney[BLOCK_OPEN[event]] = true
    elseif BLOCK_CLOSE[event] then
        local key = BLOCK_CLOSE[event]
        -- o dinheiro da venda/correio pode chegar logo depois de fechar
        After(0.5, function() blockMoney[key] = nil end)
    elseif event == "PLAYER_ENTERING_WORLD" then
        lastMoney = GetMoney and GetMoney()
        if Azaath.IsSecret(lastMoney) then lastMoney = nil end
    end
end)

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:ApplyLayout()
    local db = self.db
    if not db then return end
    if frame then
        frame:SetScale((db.scale and db.scale > 0) and db.scale or 1)
        frame:SetWidth(db.width or 320)
        frame:ClearAllPoints()
        frame:SetPoint("CENTER", UIParent, "CENTER", db.offsetX or 180, db.offsetY or 20)
        if Azaath.ClampToScreen then Azaath.ClampToScreen(frame) end
    end
    if feed then
        feed:SetScale((db.feedScale and db.feedScale > 0) and db.feedScale or 1)
        feed:ClearAllPoints()
        feed:SetPoint("CENTER", UIParent, "CENTER", db.feedX or 330, db.feedY or -60)
        if Azaath.ClampToScreen then Azaath.ClampToScreen(feed) end
    end
end

-- Exemplo para posicionar as notificações (/azaath loottest e Modo de Edição)
function M:HasFeedEntries() return #feedActive > 0 end

function M:TestFeed()
    if not feed then BuildFeed() end
    local was = self.db.feed
    self.db.feed = true
    PushFeed({ texture = "Interface\\Icons\\INV_TradeskillItem_01", name = "Madeira Verde", amount = 1 })
    PushFeed({ texture = "Interface\\Icons\\INV_Misc_Food_15", name = "Isca de Tatuzinho", amount = 2, quality = 2 })
    PushFeed({ texture = "Interface\\Icons\\INV_Chest_Cloth_23", name = "Manto do Feiticeiro", amount = 1, quality = 3 })
    PushFeed({ texture = "Interface\\Icons\\INV_Sword_39", name = "Lâmina do Massacre", amount = 1, quality = 4 })
    PushFeed({ texture = "Interface\\Icons\\INV_Misc_Coin_03", amount = "+" .. Azaath.FormatMoney(1234), name = "" })
    self.db.feed = was
end

function M:OnInitialize()
    self.db = Azaath.db.loot or { enabled = true, width = 320 }
end

function M:OnEnable()
    local db = self.db

    -- notificações valem mesmo com a janela da Blizzard
    BuildFeed()
    for _, e in ipairs({ "CHAT_MSG_LOOT", "CHAT_MSG_CURRENCY", "PLAYER_MONEY", "PLAYER_ENTERING_WORLD",
                         "MERCHANT_SHOW", "MERCHANT_CLOSED", "MAIL_SHOW", "MAIL_CLOSED",
                         "TRADE_SHOW", "TRADE_CLOSED", "AUCTION_HOUSE_SHOW", "AUCTION_HOUSE_CLOSED" }) do
        Azaath.SafeRegister(events, e)
    end
    lastMoney = GetMoney and GetMoney()
    if Azaath.IsSecret(lastMoney) then lastMoney = nil end

    if not db.enabled then return end

    -- Desativa o frame clássico de loot da Blizzard para evitar sobreposição ou bugs
    Azaath.DisableBlizzardFrame("LootFrame")

    for _, e in ipairs({ "LOOT_READY", "LOOT_OPENED", "LOOT_SLOT_CLEARED", "LOOT_SLOT_CHANGED",
                         "LOOT_CLOSED", "UI_ERROR_MESSAGE" }) do
        Azaath.SafeRegister(events, e)
    end
end
