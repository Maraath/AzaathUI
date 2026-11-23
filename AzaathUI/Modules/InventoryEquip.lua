--[[----------------------------------------------------------------------------
    AzaathUI - Modules/InventoryEquip.lua
    Painel "Equipado" ao lado da mochila (3ª forma de abrir o inventário,
    inventory.openMode = "panel"): sem girar a câmera, os espaços de equipamento
    ficam num anel em volta de um astrolábio, com as armas ("Arsenal ativo"),
    poder de ataque / armadura / crítico e integridade (durabilidade).
    Mesma moldura do inventário (Media/Inventory: cabeçalho, corpo e rodapé);
    os espaços são os da tela do personagem (Character.CreateEquipSlot).
    O mini menu radial (G) do inventário fica preso logo abaixo do painel.
    Chamado por Inventory.lua: Azaath.InventoryEquip.Show(invFrame) / Hide().
------------------------------------------------------------------------------]]

local _, Azaath = ...
local EP = {}
Azaath.InventoryEquip = EP

local _G = _G
local floor, cos, sin, rad, max, min = math.floor, math.cos, math.sin, math.rad, math.max, math.min

local S = {
    scale = 0.8, -- painel menor que a mochila (pedido do usuário)
    w = 300, h = 566, header = 72, slot = 34, small = 24, weapon = 38,
    rx = 112, ry = 118, astro = 196, cy = -227, label = -382, weapons = -396,
    stats = -446, statH = 42, integ = -498, integH = 30,
}
local COL = {
    title = { 0.88, 0.85, 0.77 }, gold = { 0.89, 0.78, 0.55 }, text = { 0.90, 0.88, 0.82 },
    dim = { 0.58, 0.60, 0.60 }, sep = { 0.27, 0.285, 0.28 }, box = { 0.02, 0.055, 0.09 },
    boxBd = { 0.17, 0.20, 0.24 }, teal = { 0.36, 0.78, 0.74 }, green = { 0.45, 0.85, 0.45 },
}
-- Anel: 14 pontos (cabeça no topo; esquerda de cima para baixo; fundo; direita de baixo para cima)
local RING = { "HeadSlot", "NeckSlot", "BackSlot", "ChestSlot", "WristSlot", "HandsSlot", "Finger0Slot",
               "Trinket0Slot", "Trinket1Slot", "Finger1Slot", "FeetSlot", "LegsSlot", "WaistSlot", "ShoulderSlot" }
local WEAPONS = { "MainHandSlot", "SecondaryHandSlot", "RangedSlot" }

local panel, slots, ui = nil, {}, {}
local dirty = true

local function Text(parent, font, size, color, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    if not pcall(fs.SetFont, fs, font or Azaath.media.fontTitleB, size, flags or "") or not fs:GetFont() then
        fs:SetFont("Fonts\\FRIZQT__.TTF", size, flags or "")
    end
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetShadowOffset(1, -1)
    if color then fs:SetTextColor(color[1], color[2], color[3]) end
    return fs
end

local function Num(v)
    if v == nil or Azaath.IsSecret(v) or type(v) ~= "number" then return nil end
    return v
end

local function Call(fn, ...)
    if not fn then return nil end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

local function Box(f, alpha)
    local media = Azaath.media
    Azaath.SetBackdrop(f, { bgFile = media.blank, edgeFile = media.blank, edgeSize = 1 })
    f:SetBackdropColor(COL.box[1], COL.box[2], COL.box[3], alpha or 0.85)
    f:SetBackdropBorderColor(COL.boxBd[1], COL.boxBd[2], COL.boxBd[3], 0.9)
end

local function CharMod() return Azaath:GetModule("Character") end

local function AddSlot(parent, name, size, x, y, side)
    local cm = CharMod()
    local b = cm and cm.CreateEquipSlot and cm.CreateEquipSlot(parent, name, size, side, "AzaathUIEquip")
    if not b then return nil end
    b:SetPoint("CENTER", parent, "TOPLEFT", x, y)
    slots[#slots + 1] = b
    return b
end

--------------------------------------------------------------------------------
-- Construção
--------------------------------------------------------------------------------
local function BuildChrome(f)
    local skin = Azaath.InventorySkin
    if skin and skin.Active() then -- mesma moldura da mochila na skin Azaath
        skin.Chrome(f, S.header)
        return
    end
    local tex = Azaath.media.path .. "Inventory\\"
    local head = f:CreateTexture(nil, "BACKGROUND")
    head:SetTexture(tex .. "Header")
    head:SetPoint("TOPLEFT")
    head:SetPoint("TOPRIGHT")
    head:SetHeight(S.header)
    local foot = f:CreateTexture(nil, "BACKGROUND")
    foot:SetTexture(tex .. "Footer")
    foot:SetPoint("BOTTOMLEFT")
    foot:SetPoint("BOTTOMRIGHT")
    foot:SetHeight(floor(S.w / 8 + 0.5))
    local body = f:CreateTexture(nil, "BACKGROUND")
    body:SetTexture(tex .. "Body")
    body:SetPoint("TOPLEFT", head, "BOTTOMLEFT")
    body:SetPoint("TOPRIGHT", head, "BOTTOMRIGHT")
    body:SetPoint("BOTTOMLEFT", foot, "TOPLEFT")
    body:SetPoint("BOTTOMRIGHT", foot, "TOPRIGHT")
    local sep = f:CreateTexture(nil, "BORDER")
    sep:SetTexture(Azaath.media.blank)
    sep:SetVertexColor(COL.sep[1], COL.sep[2], COL.sep[3])
    sep:SetHeight(1)
    sep:SetPoint("TOPLEFT", 12, -S.header)
    sep:SetPoint("TOPRIGHT", -12, -S.header)
end

local function BuildHeader(f)
    local media = Azaath.media
    local ring = f:CreateTexture(nil, "ARTWORK")
    ring:SetTexture(media.path .. "Ring.tga")
    ring:SetSize(44, 44)
    ring:SetPoint("TOPLEFT", 22, -14)
    ring:SetVertexColor(COL.teal[1], COL.teal[2], COL.teal[3], 0.95)
    local disc = f:CreateTexture(nil, "BORDER")
    disc:SetTexture(media.path .. "Disc.tga")
    disc:SetSize(38, 38)
    disc:SetPoint("CENTER", ring)
    disc:SetVertexColor(0.02, 0.05, 0.08, 0.9)
    ui.level = Text(f, media.fontBold, 15, COL.text)
    ui.level:SetPoint("CENTER", ring, "CENTER", 0, 0)

    local title = Text(f, media.fontTitleB, 14, COL.title)
    title:SetPoint("TOPLEFT", ring, "TOPRIGHT", 10, -6)
    title:SetText("EQUIPADO")
    ui.sub = Text(f, media.fontBold, 10, COL.green)
    ui.sub:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -4)

    local btn = CreateFrame("Button", nil, f)
    btn:SetSize(72, 22)
    btn:SetPoint("TOPRIGHT", -22, -24)
    Box(btn, 0.92)
    local bt = Text(btn, media.fontTitleB, 10, COL.title)
    bt:SetPoint("CENTER")
    bt:SetText("FICHA (C)")
    if Azaath.InventorySkin and Azaath.InventorySkin.Active() then Azaath.InventorySkin.Button(btn, bt) end
    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 0.9) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(COL.boxBd[1], COL.boxBd[2], COL.boxBd[3], 0.9) end)
    btn:SetScript("OnClick", function()
        local sheet = Azaath:GetModule("Sheet")
        if sheet and sheet.Toggle and Azaath.db.sheet and Azaath.db.sheet.enabled then
            sheet:Toggle()
        elseif _G.ToggleCharacter then
            pcall(_G.ToggleCharacter, "PaperDollFrame")
        end
    end)
end

local function BuildAstrolabe(f)
    local media, cx, cy = Azaath.media, S.w / 2, S.cy
    local g = COL.gold
    local function Circle(size, a, layer, file)
        local t = f:CreateTexture(nil, layer or "BORDER")
        t:SetTexture(media.path .. (file or "Ring.tga"))
        t:SetSize(size, size)
        t:SetPoint("CENTER", f, "TOPLEFT", cx, cy)
        t:SetVertexColor(g[1], g[2], g[3], a)
        return t
    end
    -- Astrolábio (tools/equip-astrolabe/gen.js): camadas que giram em sentidos
    -- opostos + brilho pulsando; animado no OnUpdate do painel (EP.Animate)
    local inv = "Inventory\\"
    local function Layer(file, sub, a, size)
        local t = Circle(size or S.astro, a, "BORDER", inv .. file)
        t:SetDrawLayer("BORDER", sub)
        t:SetVertexColor(1, 1, 1, a)
        return t
    end
    ui.astroBase = Layer("AstroBase", 0, 0.95)
    ui.astroGlow = Layer("AstroGlow", 1, 0.16)
    ui.astroGlow:SetVertexColor(COL.teal[1], COL.teal[2], COL.teal[3], 1)
    ui.astroGlow:SetBlendMode("ADD")
    ui.astroRete = Layer("AstroRete", 2, 0.85)
    ui.astroInner = Layer("AstroInner", 3, 0.9)
    ui.astroRunes = Layer("AstroRunes", 4, 0.95)
    local disc = Circle(50, 0.95, "ARTWORK", "Disc.tga")
    disc:SetVertexColor(0.02, 0.05, 0.08, 0.95)
    Circle(52, 0.8, "ARTWORK")
    local gem = Circle(14, 0.95, "OVERLAY", "Diamond.tga")
    gem:SetVertexColor(COL.teal[1], COL.teal[2], COL.teal[3], 0.95)
    gem:SetVertexColor(COL.teal[1], COL.teal[2], COL.teal[3], 1)
    ui.astroGem = gem

    -- filetes curtos: da faixa de runas até cada espaço
    local r0 = S.astro / 2 - 4
    local n = #RING
    for k = 0, n - 1 do
        local a = rad(90 + k * 360 / n)
        local x, y = cos(a), sin(a)
        if f.CreateLine then
            local l = f:CreateLine(nil, "BORDER", nil, 6)
            l:SetThickness(1)
            l:SetColorTexture(g[1], g[2], g[3], 0.3)
            l:SetStartPoint("TOPLEFT", f, cx + x * r0, cy + y * r0)
            l:SetEndPoint("TOPLEFT", f, cx + x * (S.rx - 18), cy + y * (S.ry - 18))
        end
        AddSlot(f, RING[k + 1], S.slot, cx + x * S.rx, cy + y * S.ry, (k >= 1 and k <= 7) and "LEFT" or "RIGHT")
    end
    AddSlot(f, "ShirtSlot", S.small, cx - 15, cy + 50, "LEFT")
    AddSlot(f, "TabardSlot", S.small, cx + 15, cy + 50, "RIGHT")
end

local function BuildArsenal(f)
    local media, cx = Azaath.media, S.w / 2
    local lbl = Text(f, media.fontTitleB, 10, COL.dim)
    lbl:SetPoint("CENTER", f, "TOPLEFT", cx, S.label)
    lbl:SetText("ARSENAL ATIVO")
    for side = -1, 1, 2 do
        local l = f:CreateTexture(nil, "BORDER")
        l:SetTexture(media.blank)
        l:SetVertexColor(COL.sep[1], COL.sep[2], COL.sep[3], 0.9)
        l:SetSize(60, 1)
        l:SetPoint(side < 0 and "RIGHT" or "LEFT", lbl, side < 0 and "LEFT" or "RIGHT", side * 10, 0)
    end
    local step = S.weapon + 10
    for i, name in ipairs(WEAPONS) do
        AddSlot(f, name, S.weapon, cx + (i - 2) * step, S.weapons - S.weapon / 2, i == 1 and "LEFT" or "RIGHT")
    end
end

local function BuildStats(f)
    local media = Azaath.media
    local gap, inner = 6, S.w - 44
    local bw = floor((inner - gap * 2) / 3)
    ui.stats = {}
    for i, label in ipairs({ "PODER ATQ", "ARMADURA", "CRÍTICO" }) do
        local b = CreateFrame("Frame", nil, f)
        b:SetSize(bw, S.statH)
        b:SetPoint("TOPLEFT", 22 + (i - 1) * (bw + gap), S.stats)
        Box(b, 0.8)
        local t = Text(b, media.fontTitleB, 8, COL.dim)
        t:SetPoint("TOP", 0, -6)
        t:SetText(label)
        local v = Text(b, media.fontBold, 14, COL.text)
        v:SetPoint("BOTTOM", 0, 6)
        ui.stats[i] = v
    end

    -- Integridade (durabilidade média), largura toda
    local row = CreateFrame("Frame", nil, f)
    row:SetSize(inner, S.integH)
    row:SetPoint("TOPLEFT", 22, S.integ)
    Box(row, 0.8)
    local t = Text(row, media.fontTitleB, 8, COL.dim)
    t:SetPoint("TOPLEFT", 8, -5)
    t:SetText("INTEGRIDADE")
    ui.integPct = Text(row, media.fontBold, 10, COL.teal)
    ui.integPct:SetPoint("TOPRIGHT", -8, -4)
    local bg = row:CreateTexture(nil, "ARTWORK")
    bg:SetTexture(media.blank)
    bg:SetVertexColor(0, 0, 0, 0.6)
    bg:SetHeight(4)
    bg:SetPoint("BOTTOMLEFT", 8, 6)
    bg:SetPoint("BOTTOMRIGHT", -8, 6)
    ui.integBar = row:CreateTexture(nil, "OVERLAY")
    ui.integBar:SetTexture(media.blank)
    ui.integBar:SetHeight(4)
    ui.integBar:SetPoint("LEFT", bg, "LEFT")
    ui.integW = row:GetWidth() - 16
end

--------------------------------------------------------------------------------
-- Atualização
--------------------------------------------------------------------------------
local function Refresh()
    dirty = false
    local cm = CharMod()
    if cm and cm.UpdateSlot then
        for _, b in ipairs(slots) do pcall(cm.UpdateSlot, b) end
    end
    ui.level:SetText(Num(UnitLevel("player")) or "")

    local ilvl = cm and cm.AverageItemLevel and Call(cm.AverageItemLevel) or 0
    local dura = cm and cm.Durability and Call(cm.Durability) or 1
    local pct = floor((Num(dura) or 1) * 100 + 0.5)
    ui.sub:SetText(string.format("Nível de item %d  -  %d%% íntegro", Num(ilvl) or 0, pct))

    local base, pos, neg = Call(UnitAttackPower, "player")
    base, pos, neg = Num(base), Num(pos), Num(neg)
    ui.stats[1]:SetText(base and tostring(max(0, base + (pos or 0) + (neg or 0))) or "-")
    local _, armor = Call(UnitArmor, "player")
    armor = Num(armor)
    ui.stats[2]:SetText(armor and (_G.BreakUpLargeNumbers and BreakUpLargeNumbers(armor) or armor) or "-")
    local crit = Num(Call(_G.GetCritChance)) or 0
    crit = max(crit, Num(Call(_G.GetRangedCritChance)) or 0)
    if _G.GetSpellCritChance then
        for school = 2, 7 do crit = max(crit, Num(Call(GetSpellCritChance, school)) or 0) end
    end
    ui.stats[3]:SetText(string.format("%.1f%%", crit))

    ui.integPct:SetText(pct .. "%")
    local r = min(1, max(0, pct / 100))
    ui.integBar:SetWidth(max(1, ui.integW * r))
    if r <= 0.25 then
        ui.integBar:SetVertexColor(0.85, 0.22, 0.18)
    elseif r <= 0.6 then
        ui.integBar:SetVertexColor(0.95, 0.75, 0.2)
    else
        ui.integBar:SetVertexColor(COL.teal[1], COL.teal[2], COL.teal[3])
    end

end

local function Build(invFrame)
    panel = CreateFrame("Frame", "AzaathUIInventoryEquip", invFrame)
    panel:SetSize(S.w, S.h)
    panel:SetScale(S.scale)
    panel:EnableMouse(true)
    panel:Hide()
    BuildChrome(panel)
    BuildHeader(panel)
    BuildAstrolabe(panel)
    BuildArsenal(panel)
    BuildStats(panel)

    -- Giro e pulso por AnimationGroup (roda no motor, liso a qualquer FPS; o
    -- SetRotation por quadro no Lua engasgava). Runas 1 volta/40 s (horário),
    -- rete 1/60 s (anti-horário), anel interno 1/24 s (horário).
    ui.anims = {}
    local function Spin(tex, degrees, seconds)
        local ag = tex:CreateAnimationGroup()
        local r = ag:CreateAnimation("Rotation")
        r:SetDegrees(degrees)
        r:SetDuration(seconds)
        if r.SetOrigin then r:SetOrigin("CENTER", 0, 0) end
        ag:SetLooping("REPEAT")
        ag:Play()
        ui.anims[#ui.anims + 1] = ag
    end
    local function Pulse(tex, from, to, seconds)
        tex:SetAlpha(from)
        local ag = tex:CreateAnimationGroup()
        local a = ag:CreateAnimation("Alpha")
        if a.SetFromAlpha then a:SetFromAlpha(from); a:SetToAlpha(to) else a:SetChange(to - from) end
        a:SetDuration(seconds)
        if a.SetSmoothing then a:SetSmoothing("IN_OUT") end
        ag:SetLooping("BOUNCE")
        ag:Play()
        ui.anims[#ui.anims + 1] = ag
    end
    Spin(ui.astroRunes, -360, 40)
    Spin(ui.astroRete, 360, 60)
    Spin(ui.astroInner, -360, 24)
    Pulse(ui.astroGlow, 0.10, 0.30, 2)
    Pulse(ui.astroGem, 0.65, 1, 2)

    -- atualização dos dados fora do quadro a quadro: no máximo 5x por segundo
    local wait = 0
    panel:SetScript("OnUpdate", function(_, elapsed)
        if not dirty then return end
        wait = wait + elapsed
        if wait < 0.2 then return end
        wait = 0
        Refresh()
    end)
    -- esconder para as animações: recomeça ao abrir e já mostra os dados
    panel:HookScript("OnShow", function()
        for _, ag in ipairs(ui.anims) do if not ag:IsPlaying() then ag:Play() end end
        Refresh()
    end)
    panel:SetScript("OnEvent", function(_, event, unit)
        if event:sub(1, 5) == "UNIT_" and unit ~= "player" then return end
        dirty = true
    end)
    for _, e in ipairs({ "PLAYER_EQUIPMENT_CHANGED", "UNIT_INVENTORY_CHANGED", "UPDATE_INVENTORY_DURABILITY",
                         "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER", "UNIT_RESISTANCES", "UNIT_STATS",
                         "COMBAT_RATING_UPDATE", "PLAYER_LEVEL_UP" }) do
        Azaath.SafeRegister(panel, e)
    end
end

--------------------------------------------------------------------------------
-- API para Inventory.lua
--------------------------------------------------------------------------------
-- Mostra o painel à esquerda da mochila e prende o radial (G) embaixo dele.
function EP.Show(invFrame, radial)
    if not invFrame then return end
    if not panel then Build(invFrame) end
    panel:ClearAllPoints()
    panel:SetPoint("TOPRIGHT", invFrame, "TOPLEFT", -18 / S.scale, 0) -- a aba de esconder fica no vão
    dirty = true
    panel:Show()
    if radial then
        radial:ClearAllPoints()
        radial:SetPoint("TOP", panel, "BOTTOM", 0, -6)
        radial:Show()
    end
end

-- Aba presa à borda esquerda da mochila: esconde/mostra o painel. A escolha
-- fica salva (inventory.equipHidden) e vale nas próximas aberturas.
local toggle
function EP.SetToggle(invFrame, visible, panelOn)
    if not toggle then
        if not visible then return end
        toggle = CreateFrame("Button", nil, invFrame)
        toggle:SetSize(16, 46)
        toggle:SetPoint("TOPRIGHT", invFrame, "TOPLEFT", 0, -96)
        toggle:SetFrameLevel(invFrame:GetFrameLevel() + 20)
        Box(toggle, 0.92)
        toggle.arrow = toggle:CreateTexture(nil, "ARTWORK")
        toggle.arrow:SetTexture(Azaath.media.path .. "Inventory\\Arrow")
        toggle.arrow:SetSize(10, 10)
        toggle.arrow:SetPoint("CENTER")
        toggle:SetScript("OnClick", function()
            local db = Azaath.db.inventory
            db.equipHidden = not db.equipHidden
            local inv = Azaath:GetModule("Inventory")
            if inv and inv.SyncEquipPanel then inv:SyncEquipPanel() end
            Azaath.PlaySound(db.equipHidden and "igCharacterInfoClose" or "igCharacterInfoOpen")
        end)
        toggle:SetScript("OnEnter", function(self)
            self:SetBackdropBorderColor(COL.gold[1], COL.gold[2], COL.gold[3], 0.9)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:SetText(Azaath.db.inventory.equipHidden and "Mostrar equipamento" or "Esconder equipamento")
            GameTooltip:Show()
        end)
        toggle:SetScript("OnLeave", function(self)
            self:SetBackdropBorderColor(COL.boxBd[1], COL.boxBd[2], COL.boxBd[3], 0.9)
            GameTooltip:Hide()
        end)
    end
    toggle:SetShown(visible and true or false)
    -- seta para a direita = recolher na mochila; para a esquerda = abrir o painel
    if panelOn then
        toggle.arrow:SetTexCoord(0, 1, 0, 1)
    else
        toggle.arrow:SetTexCoord(1, 0, 0, 1)
    end
end

function EP.Hide()
    if panel then panel:Hide() end
end

function EP.IsShown()
    return panel and panel:IsShown() or false
end
