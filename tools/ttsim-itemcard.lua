-- Simulador do piscar do card no leilão: frames/tooltips do WoW + código da Blizzard
-- (GameTooltip_OnHide/OnUpdate, TooltipComparisonManager, AuctionHouseUtil) + ItemCard.lua real.
-- arg[1] = ItemCard.lua; arg[2] = quando chega a comparação; arg[3] = "alpha" (SetOwner/Show nativos
-- devolvem opacidade 1); arg[4] = "rev" (OnUpdate dos cards antes do da GameTooltip); arg[5] = "scan"
local ITEMCARD, WHEN, ALPHA, REV, SCAN = arg[1], arg[2] or "inset", arg[3] == "alpha", arg[4] == "rev", arg[5] == "scan"
local MODE = arg[6] or "-"
DEBUG = arg[8] == "debug"
NOCOMPARE = false
local now = 0
function GetTime() return now end
local timers = {}
C_Timer = { After = function(d, f) timers[#timers + 1] = { t = now + d, f = f } end, NewTicker = function() end }
Enum = { TooltipDataType = { Item = 0 }, TooltipComparisonMethod = { Single = 0 } }
CURRENTLY_EQUIPPED, EQUIPPED, SELL_PRICE = "Equipado", "Equipado", "Preço de venda"
ITEM_DELTA_DESCRIPTION = "Se substituir esse item, haverá as alterações de atributos abaixo:"
function CreateColor(r, g, b, a) return { r = r, g = g, b = b, a = a } end
function GetInventoryItemLink() return nil end
function geterrorhandler() return function(e) print("ERRO: " .. tostring(e)) end end
local LOG = {}

--------------------------------------------------------------------------------
-- objetos
--------------------------------------------------------------------------------
local all = {}
local Obj = {}
local function stub(k)
    if k:find("^Get") or k:find("^Num") then return function() return 0 end end
    if k:find("^Is") or k:find("^Has") then return function() return false end end
    return function() return nil end
end
local mt = { __index = function(t, k) local v = Obj[k]; if v ~= nil then return v end; if type(k) == "string" and k:find("^%u") then return stub(k) end end }
local function New(kind, name, parent)
    local o = setmetatable({ kind = kind, name = name, parent = parent, shown = true, alpha = 1, points = {},
        scripts = {}, hooks = {}, level = 1, w = 0, h = 0 }, mt)
    all[#all + 1] = o
    if name then _G[name] = o end
    return o
end
local function Fire(o, s, ...)
    local f = o.scripts[s]; if f then f(o, ...) end
    for _, h in ipairs(o.hooks[s] or {}) do h(o, ...) end
end
function Obj:Show() if not self.shown then self.shown = true; Fire(self, "OnShow") end end
function Obj:Hide() if self.shown then self.shown = false; Fire(self, "OnHide") end end
function Obj:SetShown(v) if v then self:Show() else self:Hide() end end
function Obj:IsShown() return self.shown end
function Obj:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
function Obj:SetAlpha(a) self.alpha = a end
function Obj:GetAlpha() return self.alpha end
function Obj:SetScript(s, f) self.scripts[s] = f end
function Obj:GetScript(s) return self.scripts[s] end
function Obj:HookScript(s, f) self.hooks[s] = self.hooks[s] or {}; table.insert(self.hooks[s], f) end
function Obj:HasScript(s) return true end
function Obj:GetName() return self.name end
function Obj:GetParent() return self.parent end
function Obj:SetPoint(p, rel, rp, x, y) table.insert(self.points, { p, rel, rp, x, y }) end
function Obj:SetAllPoints(rel) self.points = { { "ALL", rel } } end
function Obj:ClearAllPoints() self.points = {} end
function Obj:GetPoint(i) local p = self.points[i or 1]; if p then return p[1], p[2], p[3], p[4], p[5] end end
function Obj:GetNumPoints() return #self.points end
local function Pos(o, v) if #o.points == 0 then return nil end return v end
function Obj:GetLeft() return Pos(self, self.x or 900) end
function Obj:GetRight() return Pos(self, (self.x or 900) + 300) end
function Obj:GetTop() return Pos(self, 700) end
function Obj:GetBottom() return Pos(self, 300) end
function Obj:GetWidth() return self.w end
function Obj:GetHeight() return self.h end
function Obj:SetWidth(w) self.w = w end
function Obj:SetHeight(h) self.h = h end
function Obj:SetSize(w, h) self.w, self.h = w, h end
function Obj:GetEffectiveScale() return 1 end
function Obj:GetScale() return 1 end
function Obj:SetFrameLevel(l) self.level = l end
function Obj:GetFrameLevel() return self.level end
function Obj:CreateTexture() return New("Texture", nil, self) end
function Obj:CreateMaskTexture() return New("Texture", nil, self) end
function Obj:CreateFontString() return New("FontString", nil, self) end
function Obj:SetText(s) self.text = s end
function Obj:GetText() return self.text end
function Obj:GetStringWidth() return #(self.text or "") * 6 end
function Obj:GetStringHeight() return 12 end
function Obj:SetTextColor(r, g, b, a) self.col = { r, g, b, a or 1 } end
function Obj:GetTextColor() local c = self.col or { 1, 1, 1, 1 }; return c[1], c[2], c[3], c[4] end
function CreateFrame(kind, name, parent) return New(kind or "Frame", name, parent) end
UIParent = New("Frame", "UIParent")
function UIParent:GetRight() return 1920 end
function UIParent:GetTop() return 1080 end

function hooksecurefunc(a, b, c)
    local tbl, name, fn = a, b, c
    if type(a) == "string" then tbl, name, fn = _G, a, b end
    local orig = tbl[name]
    tbl[name] = function(...) local r = table.pack(orig(...)); fn(...); return table.unpack(r, 1, r.n) end
end

--------------------------------------------------------------------------------
-- tooltips
--------------------------------------------------------------------------------
local postcalls = {}
TooltipDataProcessor = { AddTooltipPostCall = function(_, f) postcalls[#postcalls + 1] = f end }
local function Tooltip(name)
    local t = New("GameTooltip", name, UIParent)
    t.shown, t.n = false, 0
    for i = 1, 30 do
        New("FontString", name .. "TextLeft" .. i, t).shown = false
        New("FontString", name .. "TextRight" .. i, t).shown = false
    end
    t.CompareHeader = New("Frame", nil, t); t.CompareHeader.Label = New("FontString", nil, t)
    function t:ClearLines()
        for i = 1, 30 do _G[name .. "TextLeft" .. i].text = nil; _G[name .. "TextLeft" .. i].shown = false end
        self.n, self.item, self.data = 0, nil, nil
        Fire(self, "OnTooltipCleared")
    end
    function t:AddLine(s) self.n = self.n + 1; local fs = _G[name .. "TextLeft" .. self.n]; fs.text = s; fs.shown = true end
    function t:NumLines() return self.n end
    function t:SetOwner(owner, anchor)
        self.owner = owner
        if anchor == "ANCHOR_NONE" then self.points = {} else self.points = { { "BOTTOMLEFT", owner } } end
        if ALPHA then self.alpha = 1 end -- (nativo: não passa pelo SetAlpha do Lua)
    end
    function t:GetOwner() return self.owner end
    function t:GetItem() if self.item then return self.item[1], self.item[2] end end
    function t:GetTooltipData() return self.data end
    function t:GetPrimaryTooltipData() return self.data end
    function t:ProcessInfo(info)
        if not info.append then self:ClearLines() end
        local d = info.tooltipData
        self.data, self.item = d, { d.name, d.hyperlink }
        self:AddLine(d.name); self:AddLine("Armadura: 100"); self:AddLine("+10 Força")
        if FinalizeItemTooltip then FinalizeItemTooltip(self) end -- pós-chamada segura da Blizzard (vem antes)
        for _, f in ipairs(postcalls) do f(self, d) end           -- pós-chamadas do addon
        self:Show()
    end
    local show = Obj.Show
    function t:Show() show(self); if ALPHA then self.alpha = 1 end end
    return t
end
local function ItemData(id, name) return { type = 0, id = id, name = name, getterName = "GetItemKey",
    hyperlink = "|cff1eff00|Hitem:" .. id .. "::::::::80:::::|h[" .. name .. "]|h|r" } end

GameTooltip = Tooltip("GameTooltip")
ShoppingTooltip1, ShoppingTooltip2, ShoppingTooltip3 = Tooltip("ShoppingTooltip1"), Tooltip("ShoppingTooltip2"), Tooltip("ShoppingTooltip3")
ItemRefTooltip = Tooltip("ItemRefTooltip")
for i = 1, 3 do Tooltip("ItemRefShoppingTooltip" .. i) end
GameTooltip.shoppingTooltips = { ShoppingTooltip1, ShoppingTooltip2 }
GameTooltip.x, ShoppingTooltip1.x = 1000, 700

--------------------------------------------------------------------------------
-- Blizzard (forever): trechos de GameTooltip.lua, TooltipComparisonManager.lua, AuctionHouseUtil
--------------------------------------------------------------------------------
TOOLTIP_UPDATE_TIME = 0.2
GameTooltip.updateTooltipTimer = TOOLTIP_UPDATE_TIME
TooltipComparisonManager = {}
function TooltipComparisonManager:Initialize(tooltip, anchorFrame)
    self.tooltip = tooltip; self.anchorFrame = anchorFrame or self.tooltip
    for _, st in ipairs(self.tooltip.shoppingTooltips) do st:SetOwner(self.tooltip, "ANCHOR_NONE", 0, 0); st:ClearAllPoints() end
end
function TooltipComparisonManager:Clear(tooltip)
    if self.tooltip and (self.tooltip == tooltip or not tooltip) then
        self.comparisonItem, self.compareInfo, self.anchorFrame = nil, nil, nil
        for _, st in ipairs(self.tooltip.shoppingTooltips) do st:Hide() end
        self.tooltip = nil
    end
end
function TooltipComparisonManager:AnchorShoppingTooltips(primaryShown, secondaryShown)
    local p, s = self.tooltip.shoppingTooltips[1], self.tooltip.shoppingTooltips[2]
    p:SetShown(primaryShown); s:SetShown(secondaryShown)
    p:ClearAllPoints(); p:SetPoint("TOP", self.anchorFrame, 0, 0); p:SetPoint("RIGHT", self.anchorFrame, "LEFT")
end
function TooltipComparisonManager:CompareItem(comparisonItem, tooltip, anchorFrame)
    self:Initialize(tooltip, anchorFrame)
    self.comparisonItem = comparisonItem
    self.compareInfo = { item = { hyperlink = "eq" } }
    self:RefreshItems()
end
function TooltipComparisonManager:RefreshItems()
    if not self.compareInfo then return end
    local shown = self:SetItemTooltip(true)
    self:AnchorShoppingTooltips(shown, false)
end
function TooltipComparisonManager:SetItemTooltip(isPrimary)
    if not isPrimary then return false end
    local tooltip = self.tooltip.shoppingTooltips[1]
    tooltip:ClearLines()
    tooltip.CompareHeader:Show()
    tooltip:ProcessInfo({ tooltipData = ItemData(2222, "Elmo Equipado"), append = true })
    tooltip:AddLine(" "); tooltip:AddLine(ITEM_DELTA_DESCRIPTION); tooltip:AddLine("+5 Força"); tooltip:AddLine("-3 Vigor")
    return true
end
function CompareNow() if NOCOMPARE or LEFT or not GameTooltip:IsShown() and WHEN ~= "sync" then return end; TooltipComparisonManager:CompareItem({}, GameTooltip) end
function FinalizeItemTooltip(tooltip)
    if tooltip ~= GameTooltip then return end
    if not NOCOMPARE then GameTooltip_ShowCompareItem(tooltip) else TooltipComparisonManager:Clear(tooltip) end
end
function GameTooltip_ShowCompareItem(self)
    if WHEN == "sync" then CompareNow()
    elseif WHEN == "next" then C_Timer.After(0, CompareNow)
    else C_Timer.After(tonumber(WHEN:sub(2)) / 100, CompareNow) end
end
GameTooltip:SetScript("OnHide", function(self) TooltipComparisonManager:Clear(self) end)
GameTooltip:SetScript("OnUpdate", function(self, elapsed)
    self.updateTooltipTimer = self.updateTooltipTimer - elapsed
    if self.updateTooltipTimer > 0 then return end
    self.updateTooltipTimer = TOOLTIP_UPDATE_TIME
    local owner = self:GetOwner()
    if owner and owner.UpdateTooltip then owner:UpdateTooltip() end
end)
function GameTooltip_Hide() GameTooltip:Hide() end
function GameTooltip:SetItemKey(id)
    self:ProcessInfo({ tooltipData = ItemData(id, "Elmo do Leilão") })
end
local AuctionHouseUtil = {}
function AuctionHouseUtil.SetAuctionHouseTooltip(owner)
    GameTooltip_Hide()
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetItemKey(1111)
    GameTooltip:AddLine("Preço: 10 ouro")
    GameTooltip:Show()
end
function AuctionHouseUtil.LineOnEnterCallback(line)
    AuctionHouseUtil.SetAuctionHouseTooltip(line)
    line.UpdateTooltip = function(self) AuctionHouseUtil.LineOnEnterCallback(self) end
end
function AuctionHouseUtil.LineOnLeaveCallback(line) GameTooltip_Hide() end

--------------------------------------------------------------------------------
-- AzaathUI + ItemCard real
--------------------------------------------------------------------------------
local Azaath = { db = { skins = { itemCard = true, itemCardScale = 1 } }, API = {},
    media = { blank = "b", fontCard = "f", fontCardR = "f", fontTitleB = "f" } }
function Azaath:NewModule(n) self.M = { name = n }; return self.M end
function Azaath.IsSecret() return false end
function Azaath.LogError(m) LOG[#LOG + 1] = m; print("LOG: " .. m) end
function Azaath.API.GetItemInfo(x)
    local id = type(x) == "number" and x or tonumber(tostring(x):match("item:(%d+)"))
    return "Item " .. tostring(id), "|Hitem:" .. tostring(id) .. "|h", 3, 100, 60, "Armadura", "Placa", 1, "INVTYPE_HEAD", 1, 100, 4
end
Azaath.API.GetItemInfoInstant = Azaath.API.GetItemInfo
assert(loadfile(ITEMCARD))("AzaathUI", Azaath)
local M = Azaath.M
M:OnInitialize(); M:OnEnable()
local firstCard = #all

--------------------------------------------------------------------------------
-- execução: mouse parado numa linha do leilão por 3 s
--------------------------------------------------------------------------------
local line = New("Frame", "Linha", UIParent)
local function CardOf(tt) for _, o in ipairs(all) do if rawget(o, "tt") == tt then return o end end end
local bad, frames, lastT = {}, 0, {}
function TRACE() local cc = CardOf(ShoppingTooltip1); if DEBUG and now > 1.9 and now < 3 then print(("%.3f S=%s card=%s hold=%s"):format(now, tostring(ShoppingTooltip1.shown), tostring(cc and cc.shown), tostring(cc and cc.holdUntil))) end end
LASTH = {}
local function Check()
    TRACE()
    if now < 0.6 then return end
    local mc, cc = CardOf(GameTooltip), CardOf(ShoppingTooltip1)
    local problems = {}
    if MODE ~= "-" and now >= 2 then
        if MODE == "stop" and now > 2.85 then
            if cc and cc.shown then problems[#problems + 1] = "card Equipado ficou depois de parar" end
            if not (mc and mc.shown) then problems[#problems + 1] = "card principal sumiu" end
        elseif MODE == "shift" and now > 2.05 then
            if cc and cc.shown then problems[#problems + 1] = "card Equipado ficou depois do Shift" end
            if not (mc and mc.shown) then problems[#problems + 1] = "card principal sumiu" end
        elseif MODE == "leave" and now > 2.3 then
            if (cc and cc.shown) or (mc and mc.shown) then problems[#problems + 1] = "card ficou depois de sair" end
            if GameTooltip.shown or ShoppingTooltip1.shown then problems[#problems + 1] = "tooltip ficou" end
        end
        if (GameTooltip.shown and GameTooltip.alpha > 0 and mc and mc.shown) then problems[#problems + 1] = "tooltip Blizzard visível" end
        if (ShoppingTooltip1.shown and ShoppingTooltip1.alpha > 0) then problems[#problems + 1] = "tooltip Equipado Blizzard visível" end
        frames = frames + 1
        for _, p in ipairs(problems) do bad[p] = (bad[p] or 0) + 1 end
        return
    end
    if not (mc and mc.shown) then problems[#problems + 1] = "card principal sumiu" end
    if not (cc and cc.shown) then problems[#problems + 1] = "card Equipado sumiu" end
    if GameTooltip.shown and GameTooltip.alpha > 0 then problems[#problems + 1] = "tooltip Blizzard visível" end
    if ShoppingTooltip1.shown and ShoppingTooltip1.alpha > 0 then problems[#problems + 1] = "tooltip Equipado Blizzard visível" end
    for i, c in ipairs({ mc, cc }) do
        if c and c.shown then
            local key = (rawget(c, "link") or "") .. "#" .. i
            if LASTH[i] and LASTH[i][1] == key and LASTH[i][2] ~= c.h then problems[#problems + 1] = (i == 1 and "principal" or "Equipado") .. " mudou de tamanho" end
            LASTH[i] = { key, c.h }
        end
        if c and c.t and lastT[c] and c.t < lastT[c] then problems[#problems + 1] = "fagulhas reiniciaram" end
        if c then lastT[c] = c.t end
    end
    frames = frames + 1
    for _, p in ipairs(problems) do bad[p] = (bad[p] or 0) + 1 end
end
local LATE = arg[7] == "late"
local function Timers() local i = 1; while i <= #timers do if timers[i].t <= now then table.remove(timers, i).f() else i = i + 1 end end end
local function Step(dt)
    now = now + dt
    if not LATE then Timers() end
    local list = {}
    for _, o in ipairs(all) do if o.shown and o.scripts.OnUpdate then list[#list + 1] = o end end
    if REV then table.sort(list, function(a, b) return a ~= GameTooltip and b == GameTooltip end) end
    for _, o in ipairs(list) do if o.shown then o.scripts.OnUpdate(o, dt) end end
    if LATE then Timers() end
    Check()
end
AuctionHouseUtil.LineOnEnterCallback(line)
local nextScan = 1
local acted = false
while now < 3 do
    if MODE ~= "-" and not acted and now >= 2 then
        acted = true
        if MODE == "shift" then NOCOMPARE = true; line.UpdateTooltip = nil; GameTooltip:SetItemKey(1111)
        elseif MODE == "stop" then NOCOMPARE = true else LEFT = true; AuctionHouseUtil.LineOnLeaveCallback(line); line.UpdateTooltip = nil; GameTooltip.owner = nil end
    end
    Step(1 / 60)
    if SCAN and not LEFT and now >= nextScan then -- leva da varredura: a lista se redesenha (sai e entra na linha)
        nextScan = nextScan + 1
        AuctionHouseUtil.LineOnLeaveCallback(line)
        Step(1 / 60)
        AuctionHouseUtil.LineOnEnterCallback(line)
    end
end
local out = {}
for k, v in pairs(bad) do out[#out + 1] = k .. "=" .. v end
table.sort(out)
print(("%-6s %-5s %-3s %-4s | %d quadros | %s"):format(WHEN, ALPHA and "alpha" or "-", REV and "rev" or "-",
    (SCAN and "scan" or "-") .. " " .. MODE, frames, #out == 0 and "OK" or table.concat(out, ", ")))
