--[[----------------------------------------------------------------------------
    AzaathUI - Modules/LootRolls.lua
    Painel de rolagens do grupo: para cada item disputado (Necessidade/Ganância/Passar)
    mostra quem escolheu o quê, o número tirado, quem está na frente e o vencedor.
      * Dados: histórico de saque do próprio cliente (C_LootHistory), atualizado pelos
        eventos LOOT_HISTORY_UPDATE_ENCOUNTER / LOOT_HISTORY_UPDATE_DROP.
      * Lixo (encontro 0) só entra a partir de raro (azul).
      * Arrastar o cabeçalho move; o X fecha até o próximo saque; some sozinho depois
        que todos os itens forem decididos.
      * /azaath rolls mostra um exemplo.
    Ideia inspirada no Dungeon Master (MalkDev); código escrito do zero.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("LootRolls")

local _G = _G
local ipairs, format, max, min, sort, tonumber = ipairs, string.format, math.max, math.min, table.sort, tonumber

local W, PAD, HEAD_H, ITEM_H, LINE_H, GAP = 320, 10, 30, 42, 17, 8
local MAX_DROPS, MAX_LINES = 4, 8
local LINGER = 12 -- segundos depois de tudo decidido

-- estado da rolagem (Enum.EncounterLootDropRollState): 0/1 necessidade, 2 transmog, 3 ganância, 4 sem escolha, 5 passou
local CHOICE = {
    [0] = { "lootroll-icon-need", "Necessidade", 3 },
    [1] = { "lootroll-icon-need", "Necessidade", 3 },
    [2] = { "lootroll-icon-transmog", "Transmog", 2 },
    [3] = { "lootroll-icon-greed", "Ganância", 2 },
    [5] = { "lootroll-icon-pass", "Passou", 1 },
}

local frame, cards = nil, {}
local current       -- { key, title, drops }
local dismissedKey  -- encontro fechado pelo X
local decidedAt

local function DB() return M.db or {} end

-- valores secretos (motor novo) viram nil
local function V(v)
    if v == nil or Azaath.IsSecret(v) then return nil end
    return v
end

local function ClassHex(class)
    local c = class and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]
    if not c then return "ffe0d8c8" end
    return format("ff%02x%02x%02x", c.r * 255 + 0.5, c.g * 255 + 0.5, c.b * 255 + 0.5)
end

local function ItemID(link) return link and tonumber(link:match("item:(%d+)")) end

local function Quality(link)
    local id = ItemID(link)
    local q = id and _G.C_Item and _G.C_Item.GetItemQualityByID and _G.C_Item.GetItemQualityByID(id)
    return q or 1
end

local function Rank(state) return CHOICE[state] and CHOICE[state][3] or 0 end

-- quem está na frente: maior escolha, depois maior número
local function Leader(drop)
    local w = drop.winner
    if w and V(w.playerName) then return w, true end
    local lead = drop.currentLeader
    if lead and V(lead.playerName) and V(lead.roll) then return lead, false end
    lead = nil
    for _, r in ipairs(drop.rollInfos or {}) do
        local n = V(r.roll)
        if V(r.playerName) and n and (not lead or Rank(r.state) > Rank(lead.state)
            or (Rank(r.state) == Rank(lead.state) and n > (V(lead.roll) or 0))) then
            lead = r
        end
    end
    return lead, false
end

local function Decided(drop) return (drop.winner ~= nil and V(drop.winner.playerName) ~= nil) or V(drop.allPassed) == true end

--------------------------------------------------------------------------------
-- Visual
--------------------------------------------------------------------------------
local function Edge(parent, layer)
    local c = Azaath.colors.gold
    local t = parent:CreateTexture(nil, layer or "BORDER")
    t:SetColorTexture(c[1], c[2], c[3], 0.55)
    return t
end

local function Frame1px(f)
    local top, bot, l, r = Edge(f), Edge(f), Edge(f), Edge(f)
    top:SetPoint("TOPLEFT"); top:SetPoint("TOPRIGHT"); top:SetHeight(1)
    bot:SetPoint("BOTTOMLEFT"); bot:SetPoint("BOTTOMRIGHT"); bot:SetHeight(1)
    l:SetPoint("TOPLEFT"); l:SetPoint("BOTTOMLEFT"); l:SetWidth(1)
    r:SetPoint("TOPRIGHT"); r:SetPoint("BOTTOMRIGHT"); r:SetWidth(1)
end

local function Text(parent, font, size, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, flags or "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetJustifyH("LEFT")
    fs:SetWordWrap(false)
    return fs
end

local function SavePos()
    local x, y = frame:GetCenter()
    if x and y then DB().pos = { x, y } end
end

local function PlaceFrame()
    frame:ClearAllPoints()
    local pos = DB().pos
    if pos then
        frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", pos[1], pos[2])
    else
        frame:SetPoint("RIGHT", UIParent, "RIGHT", -60, 120)
    end
end

local function NewCard(i)
    local media, c = Azaath.media, Azaath.colors
    local card = CreateFrame("Frame", nil, frame)
    card:SetWidth(W - PAD * 2)

    card.bg = card:CreateTexture(nil, "BACKGROUND", nil, 1)
    card.bg:SetAllPoints(card)
    card.bg:SetColorTexture(1, 1, 1, 0.035)

    local btn = CreateFrame("Button", nil, card)
    btn:SetSize(34, 34)
    btn:SetPoint("TOPLEFT", 4, -4)
    card.icon = btn:CreateTexture(nil, "ARTWORK")
    card.icon:SetAllPoints(btn)
    card.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    card.border = btn:CreateTexture(nil, "OVERLAY")
    card.border:SetTexture(media.path .. "Ring")
    card.border:SetPoint("TOPLEFT", -3, 3)
    card.border:SetPoint("BOTTOMRIGHT", 3, -3)
    btn:SetScript("OnEnter", function(self)
        if not card.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        pcall(GameTooltip.SetHyperlink, GameTooltip, card.link)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function() GameTooltip:Hide() end)
    btn:SetScript("OnClick", function()
        if card.link and _G.IsModifiedClick and _G.IsModifiedClick("CHATLINK") and _G.ChatEdit_InsertLink then
            _G.ChatEdit_InsertLink(card.link)
        end
    end)

    card.name = Text(card, media.fontBold or media.font, 13)
    card.name:SetPoint("TOPLEFT", 46, -6)
    card.name:SetPoint("RIGHT", -6, 0)
    card.status = Text(card, media.font, 12)
    card.status:SetPoint("TOPLEFT", 46, -23)
    card.status:SetPoint("RIGHT", -6, 0)
    card.status:SetTextColor(c.dim[1], c.dim[2], c.dim[3])

    card.lines = {}
    for j = 1, MAX_LINES do
        local y = -ITEM_H - (j - 1) * LINE_H
        local l = {}
        l.hl = card:CreateTexture(nil, "BACKGROUND", nil, 2)
        l.hl:SetPoint("TOPLEFT", 2, y + 1)
        l.hl:SetPoint("TOPRIGHT", -2, y + 1)
        l.hl:SetHeight(LINE_H)
        l.hl:SetColorTexture(c.accent[1], c.accent[2], c.accent[3], 0.14)
        l.icon = card:CreateTexture(nil, "ARTWORK")
        l.icon:SetSize(14, 14)
        l.icon:SetPoint("TOPLEFT", 12, y - 1)
        l.name = Text(card, media.font, 12)
        l.name:SetPoint("TOPLEFT", 32, y - 2)
        l.name:SetPoint("RIGHT", -96, 0)
        l.choice = Text(card, media.font, 11)
        l.choice:SetPoint("TOPRIGHT", -40, y - 2)
        l.choice:SetJustifyH("RIGHT")
        l.choice:SetTextColor(c.dim[1], c.dim[2], c.dim[3])
        l.roll = Text(card, media.fontBold or media.font, 12)
        l.roll:SetPoint("TOPRIGHT", -8, y - 2)
        l.roll:SetJustifyH("RIGHT")
        card.lines[j] = l
    end
    cards[i] = card
    return card
end

local function Build()
    if frame then return end
    local media, c = Azaath.media, Azaath.colors
    frame = CreateFrame("Frame", nil, UIParent)
    frame:SetSize(W, 100)
    frame:SetFrameStrata("MEDIUM")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()

    local bg = frame:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(frame)
    bg:SetColorTexture(c.dark[1], c.dark[2], c.dark[3], 0.92)
    Frame1px(frame)

    local head = CreateFrame("Frame", nil, frame)
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(HEAD_H)
    head:EnableMouse(true)
    head:RegisterForDrag("LeftButton")
    head:SetScript("OnDragStart", function() frame:StartMoving() end)
    head:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SavePos() end)
    local line = Edge(head, "ARTWORK")
    line:SetPoint("BOTTOMLEFT", PAD, 0)
    line:SetPoint("BOTTOMRIGHT", -PAD, 0)
    line:SetHeight(1)

    frame.title = Text(head, media.fontTitleB or media.fontBold, 13)
    frame.title:SetPoint("LEFT", PAD, 0)
    frame.title:SetTextColor(c.gold[1], c.gold[2], c.gold[3])
    frame.sub = Text(head, media.font, 11)
    frame.sub:SetPoint("RIGHT", -34, 0)
    frame.sub:SetJustifyH("RIGHT")
    frame.sub:SetTextColor(c.dim[1], c.dim[2], c.dim[3])

    local close = CreateFrame("Button", nil, head)
    close:SetSize(18, 18)
    close:SetPoint("RIGHT", -8, 0)
    local ct = close:CreateTexture(nil, "ARTWORK")
    ct:SetAllPoints(close)
    ct:SetTexture("Interface\\Buttons\\UI-StopButton")
    ct:SetVertexColor(c.gold[1], c.gold[2], c.gold[3])
    close:SetScript("OnEnter", function() ct:SetVertexColor(1, 1, 1) end)
    close:SetScript("OnLeave", function() ct:SetVertexColor(c.gold[1], c.gold[2], c.gold[3]) end)
    close:SetScript("OnClick", function()
        dismissedKey = current and current.key
        frame:Hide()
    end)

    frame:SetScript("OnUpdate", function(self)
        if decidedAt and GetTime() - decidedAt > LINGER and not self:IsMouseOver() then
            decidedAt = nil
            self:Hide()
        end
    end)
    PlaceFrame()
end

local function PaintCard(card, drop)
    local c = Azaath.colors
    local link = V(drop.itemHyperlink)
    card.link = link
    local id = ItemID(link)
    local icon = id and _G.C_Item and _G.C_Item.GetItemIconByID and _G.C_Item.GetItemIconByID(id)
    card.icon:SetTexture(icon or 134400)
    local q = Quality(link)
    local qc = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[q]
    if qc then card.border:SetVertexColor(qc.r, qc.g, qc.b, 1) else card.border:SetVertexColor(1, 1, 1, 1) end
    local name = link and link:match("%[(.-)%]") or "?"
    card.name:SetText(name)
    if qc then card.name:SetTextColor(qc.r, qc.g, qc.b) end

    -- linhas: quem rolou, ordenadas por escolha e número; vencedor no topo
    local list, chose, total = {}, 0, 0
    for _, r in ipairs(drop.rollInfos or {}) do
        if V(r.playerName) then
            total = total + 1
            if r.state ~= 4 then chose = chose + 1 end
            list[#list + 1] = r
        end
    end
    sort(list, function(a, b)
        local wa, wb = V(a.isWinner) == true, V(b.isWinner) == true
        if wa ~= wb then return wa end
        if Rank(a.state) ~= Rank(b.state) then return Rank(a.state) > Rank(b.state) end
        return (V(a.roll) or 0) > (V(b.roll) or 0)
    end)

    local lead, final = Leader(drop)
    if final then
        local ch = CHOICE[lead.state]
        card.status:SetText(format("|cff6fe06fVencedor:|r |c%s%s|r%s", ClassHex(V(lead.playerClass)), lead.playerName,
            V(lead.roll) and format("  (%s %d)", ch and ch[2] or "", lead.roll) or ""))
    elseif V(drop.allPassed) then
        card.status:SetText("Todos passaram")
    elseif lead then
        card.status:SetText(format("Rolando %d/%d  ·  na frente: |c%s%s|r %d", chose, total,
            ClassHex(V(lead.playerClass)), lead.playerName, V(lead.roll) or 0))
    else
        card.status:SetText(total > 0 and format("Escolhendo %d/%d", chose, total) or "Aguardando rolagens")
    end

    local shown = min(#list, MAX_LINES)
    for j = 1, MAX_LINES do
        local l, r = card.lines[j], list[j]
        local on = j <= shown
        l.hl:SetShown(on and V(r.isWinner) == true)
        l.icon:SetShown(on)
        l.name:SetShown(on)
        l.choice:SetShown(on)
        l.roll:SetShown(on)
        if on then
            local ch = CHOICE[r.state]
            if ch then
                l.icon:SetAtlas(ch[1])
                l.icon:SetDesaturated(false)
                l.icon:SetAlpha(1)
            else
                l.icon:SetAtlas("lootroll-pendingdot")
                l.icon:SetAlpha(0.7)
            end
            l.name:SetText(format("|c%s%s|r", ClassHex(V(r.playerClass)), r.playerName))
            l.choice:SetText(ch and ch[2] or "escolhendo...")
            local roll = V(r.roll)
            l.roll:SetText(roll and tostring(roll) or "")
            if V(r.isWinner) then l.roll:SetTextColor(c.accent[1], c.accent[2], c.accent[3])
            else l.roll:SetTextColor(c.cream[1], c.cream[2], c.cream[3]) end
        end
    end
    local h = ITEM_H + shown * LINE_H + (shown > 0 and 4 or 0)
    card:SetHeight(h)
    return h
end

local function Paint()
    if not (current and #current.drops > 0) then
        if frame then frame:Hide() end
        return
    end
    Build()
    frame.title:SetText(Azaath.Upper(current.title or "Rolagens"))
    local y, done = HEAD_H + 6, 0
    for i = 1, max(#cards, MAX_DROPS) do
        local drop = current.drops[i]
        if i <= MAX_DROPS and drop then
            local card = cards[i] or NewCard(i)
            card:ClearAllPoints()
            card:SetPoint("TOPLEFT", PAD, -y)
            y = y + PaintCard(card, drop) + GAP
            card:Show()
        elseif cards[i] then
            cards[i]:Hide()
        end
    end
    for _, d in ipairs(current.drops) do if Decided(d) then done = done + 1 end end
    local extra = #current.drops - MAX_DROPS
    frame.sub:SetText(format("%d/%d decididos%s", done, #current.drops, extra > 0 and format("  ·  +%d", extra) or ""))
    frame:SetHeight(y + PAD - GAP + 4)
    if done == #current.drops then
        decidedAt = decidedAt or GetTime()
    else
        decidedAt = nil
    end
    if current.key ~= dismissedKey then frame:Show() end
end

--------------------------------------------------------------------------------
-- Dados do cliente
--------------------------------------------------------------------------------
local function FromHistory(encounterID)
    local H = _G.C_LootHistory
    if not (H and H.GetSortedDropsForEncounter and encounterID) then return end
    local ok, drops = pcall(H.GetSortedDropsForEncounter, encounterID)
    if not ok or type(drops) ~= "table" then return end
    local list, seen, newest = {}, {}, 0
    for _, d in ipairs(drops) do
        local key = V(d.lootListID) or V(d.itemHyperlink)
        if key and not seen[key] and d.rollInfos and #d.rollInfos > 0 then
            seen[key] = true
            list[#list + 1] = d
            newest = max(newest, V(d.startTime) or 0)
        end
    end
    local key = encounterID
    if encounterID == 0 then
        -- lixo: só a leva mais recente (5 s) e de raro para cima
        local keep = {}
        for _, d in ipairs(list) do
            if (V(d.startTime) or 0) >= newest - 5000 and Quality(V(d.itemHyperlink)) >= 3 then keep[#keep + 1] = d end
        end
        list, key = keep, "trash" .. newest
    end
    if #list == 0 then return end
    local title
    if encounterID ~= 0 and H.GetInfoForEncounter then
        local ok2, info = pcall(H.GetInfoForEncounter, encounterID)
        title = ok2 and type(info) == "table" and V(info.encounterName) or nil
    end
    if not (current and current.key == key) then decidedAt = nil end
    current = { key = key, title = title or "Rolagens", drops = list }
    Paint()
end

-- exemplo para conferir o visual (/azaath rolls)
function M:Preview()
    local function link(id, name, q)
        local _, l = _G.C_Item and _G.C_Item.GetItemInfo and _G.C_Item.GetItemInfo(id)
        if not l and _G.C_Item and _G.C_Item.RequestLoadItemDataByID then pcall(_G.C_Item.RequestLoadItemDataByID, id) end
        return l or format("|c%s|Hitem:%d::::::::::::::|h[%s]|h|r", q == 4 and "ffa335ee" or "ff0070dd", id, name)
    end
    local me, cls = UnitName("player"), select(2, UnitClass("player"))
    local function r(n, c, s, roll, win) return { playerName = n, playerClass = c, state = s, roll = roll, isWinner = win } end
    current = { key = "preview", title = "Exemplo de rolagens", drops = {
        { itemHyperlink = link(7717, "Ravager", 4), winner = r(me, cls, 0, 87, true),
          rollInfos = { r(me, cls, 0, 87, true), r("Thalia", "PRIEST", 0, 23), r("Borgar", "WARRIOR", 3, 64), r("Nimi", "MAGE", 5) } },
        { itemHyperlink = link(10330, "Scarlet Leggings", 3),
          rollInfos = { r("Thalia", "PRIEST", 3, 41), r("Borgar", "WARRIOR", 3, 77), r(me, cls, 4), r("Nimi", "MAGE", 5) } },
    } }
    dismissedKey, decidedAt = nil, nil
    Paint()
end

function M:Reposition()
    if frame then PlaceFrame() end
end

function M:OnInitialize()
    Azaath.db.lootRolls = Azaath.db.lootRolls or { enabled = true }
    self.db = Azaath.db.lootRolls
end

function M:OnEnable()
    local ev = CreateFrame("Frame")
    for _, e in ipairs({ "LOOT_HISTORY_UPDATE_ENCOUNTER", "LOOT_HISTORY_UPDATE_DROP", "LOOT_HISTORY_CLEAR_HISTORY" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function(_, event, encounterID)
        if DB().enabled == false then return end
        if event == "LOOT_HISTORY_CLEAR_HISTORY" then
            current = nil
            if frame then frame:Hide() end
            return
        end
        if not (IsInGroup and IsInGroup()) then return end
        FromHistory(encounterID)
    end)
end
