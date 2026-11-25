--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Resources.lua
    Recursos pessoais na placa do alvo (Combo Points, Holy Power, Runas, Chi,
    Arcane Charges, Soul Shards, Essence), barra de poder/vida do jogador,
    alvo da unidade (UnitTarget) e extras (M+ % e Energia de Boss).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, tonumber, type, wipe = pairs, ipairs, pcall, tonumber, type, wipe
local floor, max, min = math.floor, math.max, math.min

local PT = _G.Enum and _G.Enum.PowerType or {}
local MAX_PIPS = 10

local RESOURCES = {
    holyPower     = { type = PT.HolyPower,     max = 5 },
    comboPoints   = { type = PT.ComboPoints,   max = 5 },
    runes         = { type = PT.Runes,         max = 6 },
    chi           = { type = PT.Chi,           max = 5 },
    arcaneCharges = { type = PT.ArcaneCharges, max = 4 },
    soulShards    = { type = PT.SoulShards,    max = 5 },
    essence       = { type = PT.Essence,       max = 5 },
}
local GAME = {
    comboPoints      = { bg = "uf-roguecp-bg-dis", fill = "uf-roguecp-icon-red", charged = "uf-roguecp-icon-blue" },
    comboPointsDruid = { bg = "UF-DruidCP-BG-Dis", fill = "UF-DruidCP-Icon" },
    holyPower        = { bg = "uf-holypower-rune%d", fill = "uf-holypower-rune%d-active" },
    chi              = { bg = "uf-chi-bg", fill = "uf-chi-icon" },
    arcaneCharges    = { bg = "UF-Arcane-BG", fill = "UF-Arcane-Icon" },
    soulShards       = { bg = "UF-SoulShard-Holder", fill = "UF-SoulShard-Icon" },
    essence          = { bg = "UF-Essence-BG", fill = "UF-Essence-Icon" },
    runes            = { bg = "UF-DKRunes-BGDis", fill = "UF-DKRunes-%s-SkullActive" },
}
local RUNE_ART = { [250] = "Blood", [251] = "Frost", [252] = "Unholy" }
local RES_TEX = NP.MEDIA .. "res-"
local MF_ASPECT = { gems = 1, orbs = 1, diamonds = 1, hex = 1, shards = 1, capsules = 2, blades = 2, skull = 1, holy = 1 }
local THEMED = { holyPower = "hex", comboPoints = "gems", chi = "orbs", arcaneCharges = "orbs", soulShards = "shards", essence = "diamonds", runes = "orbs" }
local CLASSIC = { holyPower = "holy", comboPoints = "gems", chi = "orbs", arcaneCharges = "orbs", soulShards = "shards", essence = "diamonds", runes = "skull" }

NP.RESOURCE_STYLES = {
    game = "Estilo do Jogo (Blizzard)", bars = "Barras simples", classic = "Clássico (runas, crânios)",
    themed = "Temático por classe", gems = "Gemas", orbs = "Orbes", diamonds = "Diamantes",
    hex = "Hexágonos", shards = "Fragmentos", capsules = "Cápsulas", blades = "Lâminas",
}
NP.RESOURCE_STYLE_ORDER = { "game", "classic", "themed", "gems", "orbs", "diamonds", "hex", "shards", "capsules", "blades", "bars" }

local function ResShape(style, key)
    if style == "themed" then return THEMED[key] or "gems" end
    if style == "classic" then return CLASSIC[key] or "gems" end
    return MF_ASPECT[style] and style or nil
end

local function SpecID()
    local CS = _G.C_SpecializationInfo
    if not (CS and CS.GetSpecialization and CS.GetSpecializationInfo) then return nil end
    local ok, idx = pcall(CS.GetSpecialization)
    if not ok or type(idx) ~= "number" then return nil end
    local ok2, id = pcall(CS.GetSpecializationInfo, idx)
    return ok2 and type(id) == "number" and id or nil
end

local function CurrentResource()
    local _, cls = _G.UnitClass("player")
    local key
    if cls == "PALADIN" then key = "holyPower"
    elseif cls == "ROGUE" then key = "comboPoints"
    elseif cls == "DRUID" then if _G.GetShapeshiftFormID and _G.GetShapeshiftFormID() == 1 then key = "comboPoints" end
    elseif cls == "DEATHKNIGHT" then key = "runes"
    elseif cls == "MONK" then local s = SpecID(); if s == nil or s == 269 then key = "chi" end
    elseif cls == "MAGE" then local s = SpecID(); if s == nil or s == 62 then key = "arcaneCharges" end
    elseif cls == "WARLOCK" then key = "soulShards"
    elseif cls == "EVOKER" then key = "essence" end
    local r = key and RESOURCES[key]
    if not r or r.type == nil then return nil end
    local mx = _G.UnitPowerMax("player", r.type)
    if NP.IsSecret(mx) then return key, r.max end
    if type(mx) ~= "number" or mx <= 0 then return nil end
    return key, min(mx, MAX_PIPS)
end

local function PipColor(c, key)
    if key == "comboPoints" and select(2, _G.UnitClass("player")) == "DRUID" then return c.colors.comboPointsDruid end
    if key == "runes" then
        local s = SpecID()
        if s == 250 then return c.colors.runesBlood elseif s == 251 then return c.colors.runesFrost elseif s == 252 then return c.colors.runesUnholy end
    end
    return c.colors[key] or c.colors.comboPoints
end

-- Elemento ClassResources
local Resources = {}
local function MakePip(bar, i)
    local p = _G.CreateFrame("StatusBar", nil, bar)
    p:SetMinMaxValues(i - 1, i); p:SetValue(0)
    p.bg = p:CreateTexture(nil, "BACKGROUND"); p.bg:SetAllPoints()
    p.border = NP.CreateBorder(p, "OVERLAY", 7)
    p.shadow = p:CreateTexture(nil, "BACKGROUND", nil, -8)
    p.shadow:SetTexture(NP.MEDIA .. "glow.png"); p.shadow:SetPoint("CENTER"); p.shadow:Hide()
    p.slot = p:CreateTexture(nil, "BACKGROUND", nil, 1); p.slot:SetAllPoints(); p.slot:Hide()
    p.index = i; p:Hide()
    return p
end

function Resources:Create(f)
    local bar = _G.CreateFrame("Frame", nil, f); bar:SetSize(1, 1)
    bar.pips = {}; for i = 1, MAX_PIPS do bar.pips[i] = MakePip(bar, i) end
    bar:Hide(); bar.owner = f; f.classBar = bar
end

local function MakeShapeParts(p)
    if p.shine then return end
    p.shine = _G.CreateFrame("StatusBar", nil, p); p.shine:SetAllPoints(); p.shine:SetMinMaxValues(p.index - 1, p.index)
    p.shine:SetFrameLevel(p:GetFrameLevel() + 1); p.shine:SetOrientation("VERTICAL")
    p.glow = p:CreateTexture(nil, "BACKGROUND", nil, -7); p.glow:SetTexture(NP.MEDIA .. "glow.png")
    p.glow:SetBlendMode("ADD"); p.glow:SetPoint("CENTER"); p.glow:Hide()
    local ag = p:CreateAnimationGroup()
    local g = ag:CreateAnimation("Scale"); g:SetScaleFrom(1, 1); g:SetScaleTo(1.2, 1.2); g:SetDuration(0.12); g:SetOrder(1); g:SetOrigin("CENTER", 0, 0)
    local s = ag:CreateAnimation("Scale"); s:SetScaleFrom(1.2, 1.2); s:SetScaleTo(1, 1); s:SetDuration(0.22); s:SetOrder(2); s:SetOrigin("CENTER", 0, 0)
    p.pop = ag
end

local function Atlas(pat, i, art)
    if pat:find("%%d") then return pat:format(i) end
    if pat:find("%%s") then return pat:format(art) end
    return pat
end

function Resources:Layout(f)
    local c = NP.Prof(f).classResources
    local bar = f.classBar
    local key, count = CurrentResource()
    if not (c and c.enabled and key and count) or f.cfg.mode == "nameOnly" then
        bar.key = nil; bar:Hide(); return
    end
    bar:SetFrameLevel(NP.DepthLevel(f, 10, "resources"))
    local sp = c.spacing
    local shape = ResShape(c.style, key)
    local game = (c.style == "game" or (not shape and c.style ~= "bars")) and GAME[(key == "comboPoints" and select(2, _G.UnitClass("player")) == "DRUID") and "comboPointsDruid" or key]
    local w, h = c.width, c.height
    local runeArt = RUNE_ART[SpecID() or 0] or "Blood"
    if shape then
        h = c.mfSize or 14; w = h * MF_ASPECT[shape] * (c.mfWidth or 1); sp = c.mfSpacing or 2
    elseif game then
        h = c.gameSize; w = h; sp = c.gameSpacing
    elseif c.matchHealthWidth and f.cfg and f.cfg.healthWidth then
        w = (f.cfg.healthWidth - sp * (count - 1)) / count
    end
    bar:SetSize(count * w + (count - 1) * sp, h)
    NP.SetAnchor(bar, c.anchor, f.health)
    local col, tex = PipColor(c, key), NP.GetStatusBarTexture(c.texture)
    for i = 1, MAX_PIPS do
        local p = bar.pips[i]
        if i <= count then
            p:ClearAllPoints(); p:SetPoint("LEFT", bar, "LEFT", (i - 1) * (w + sp), 0); p:SetSize(w, h)
            if p.shine then p.shine:Hide(); p.glow:Hide() end
            p:SetOrientation(shape and "VERTICAL" or "HORIZONTAL")
            if shape then
                MakeShapeParts(p)
                local art = (shape == "holy") and ("holy" .. ((i - 1) % 5 + 1)) or shape
                p:SetStatusBarTexture(RES_TEX .. art .. "-body.png"); p:SetStatusBarColor(NP.RGBA(col))
                p.bg:SetColorTexture(0, 0, 0, 0)
                p.slot:SetTexture(RES_TEX .. art .. "-slot.png"); p.slot:SetVertexColor(NP.RGBA(c.mfSlotColor or { 1, 1, 1, 1 })); p.slot:Show()
                p.border:SetBorderSize(0)
                p.shine:SetStatusBarTexture(RES_TEX .. art .. "-shine.png"); p.shine:SetShown(c.mfShine ~= false)
                local gs = max(w, h) * 2.2; p.glow:SetSize(gs, gs); p.glow:SetVertexColor(col[1], col[2], col[3], c.mfGlowStrength or 0.7)
                p.fillAtlas = nil
            elseif game then
                local fill, slot = Atlas(game.fill, i, runeArt), Atlas(game.bg, i, runeArt)
                p:SetStatusBarTexture(fill)
                if c.gameTint then p:SetStatusBarColor(NP.RGBA(col)) else p:SetStatusBarColor(1, 1, 1, 1) end
                p.fillAtlas = fill; p.bg:SetColorTexture(0, 0, 0, 0); p.slot:SetAtlas(slot); p.slot:Show(); p.border:SetBorderSize(0)
            else
                p:SetStatusBarTexture(tex); p:SetStatusBarColor(NP.RGBA(col))
                p.bg:SetColorTexture(NP.RGBA(c.emptyColor)); p.slot:Hide()
                p.border:SetBorderSize(c.border and c.borderSize or 0); p.border:SetBorderColor(NP.RGBA(c.borderColor))
            end
            if c.shadow then
                local ss = max(w, h) * (c.shadowSize or 1.8)
                p.shadow:SetSize(ss, ss); p.shadow:SetVertexColor(0, 0, 0, c.shadowAlpha or 0.8); p.shadow:Show()
            else p.shadow:Hide() end
            p:Show()
        else p:Hide() end
    end
    bar.key, bar.count, bar.game, bar.shape, bar.lastLit = key, count, (not shape) and game or nil, shape, nil
end

local function UpdateResourceValues(f)
    local bar = f.classBar
    local key = bar.key
    if not key then return end
    local r = RESOURCES[key]
    local c = NP.Prof(f).classResources
    if key == "runes" and _G.GetRuneCooldown then
        local now, list = _G.GetTime(), {}
        for i = 1, bar.count do
            local s, d, ready = _G.GetRuneCooldown(i)
            local p = 1
            if not NP.IsSecret(ready) and not ready and type(s) == "number" and type(d) == "number" and d > 0 then
                p = max(0, min(1, (now - s) / d))
            end
            list[i] = p
        end
        table.sort(list, function(a, b) return a > b end)
        for i = 1, bar.count do
            local v = list[i] or 1
            bar.pips[i]:SetValue(i - 1 + v)
            bar.pips[i]:SetAlpha(v >= 1 and 1 or c.rechargeAlpha)
        end
        return
    end
    local cur = (key == "comboPoints" and _G.GetComboPoints) and _G.GetComboPoints("player", "target") or _G.UnitPower("player", r.type)
    local secret = NP.IsSecret(cur)
    for i = 1, bar.count do
        local p = bar.pips[i]
        p:SetValue(cur)
        p:SetAlpha(1)
        if p.shine then p.shine:SetValue(p:GetValue()) end
    end
    if not secret and type(cur) == "number" and bar.shape then
        local lit = floor(cur)
        local full = lit >= bar.count and c.mfGlow ~= false
        for i = 1, bar.count do if bar.pips[i].glow then bar.pips[i].glow:SetShown(full) end end
        if bar.lastLit and lit > bar.lastLit and c.mfPop ~= false and bar:IsVisible() then
            for i = bar.lastLit + 1, min(lit, bar.count) do
                if bar.pips[i].pop then bar.pips[i].pop:Stop(); bar.pips[i].pop:Play() end
            end
        end
        bar.lastLit = lit
    end
end
NP.UpdateResourceValues = UpdateResourceValues

local function RefreshResourceBar(f)
    local bar = f.classBar
    if not bar or f.isPreview then return end
    local c = NP.Prof(f).classResources
    local show = c and c.enabled and bar.key and f.active and f.isTarget and f.cfg.mode ~= "nameOnly" and f.health:IsShown()
    if show and c.onlyAttackable and not (f.unit and NP.Truthy(_G.UnitCanAttack("player", f.unit), false)) then show = false end
    if show and c.onlyInCombat and not NP.Truthy(_G.UnitAffectingCombat("player"), false) then show = false end
    if show then UpdateResourceValues(f); bar:Show() else bar:Hide() end
end

function Resources:Update(f) RefreshResourceBar(f) end
function Resources:OnTargetChanged(f) RefreshResourceBar(f) end
function Resources:Clear(f) if f.classBar then f.classBar:Hide() end end
function Resources:Preview(f, st)
    local bar, c = f.classBar, NP.Prof(f).classResources
    local editing = st.selected == "resources"
    if not (c and (c.enabled or editing)) or f.cfg.mode == "nameOnly" or not (st.target or editing) then bar:Hide(); return end
    if not bar.key then Resources:Layout(f) end
    if not bar.key then bar:Hide(); return end
    local lit = max(1, bar.count - 1)
    for i = 1, bar.count do bar.pips[i]:SetValue(lit); if bar.pips[i].shine then bar.pips[i].shine:SetValue(lit) end end
    bar:SetAlpha(c.enabled and 1 or 0.4); bar:Show()
end
NP.RegisterElement("Resources", Resources)

-- Power + PlayerHealth acoplados ao alvo
local POWER_COLORS = {
    MANA = { 0.18, 0.48, 1, 1 }, RAGE = { 1, 0.15, 0.15, 1 }, FOCUS = { 1, 0.5, 0.25, 1 },
    ENERGY = { 1, 0.88, 0.2, 1 }, RUNIC_POWER = { 0, 0.82, 1, 1 }, LUNAR_POWER = { 0.3, 0.52, 0.9, 1 },
    MAELSTROM = { 0, 0.5, 1, 1 }, INSANITY = { 0.55, 0.2, 0.9, 1 }, FURY = { 0.79, 0.26, 0.99, 1 }, PAIN = { 1, 0.61, 0, 1 },
}

local PlayerBars = {}
local function MakeMiniBar(f)
    local b = _G.CreateFrame("StatusBar", nil, f)
    b:SetMinMaxValues(0, 1); b:SetValue(0)
    b.bg = b:CreateTexture(nil, "BACKGROUND"); b.bg:SetAllPoints()
    b.border = NP.CreateBorder(b, "OVERLAY", 7)
    b.text = b:CreateFontString(nil, "OVERLAY"); b.text:SetPoint("CENTER", b, "CENTER", 0, 0)
    b:Hide()
    return b
end
function PlayerBars:Create(f)
    f.powerBar = MakeMiniBar(f)
    f.playerHealthBar = MakeMiniBar(f)
end
local function StyleMini(b, c, rel, f, key)
    b:SetFrameLevel(NP.DepthLevel(f, 1, key))
    local w = tonumber(c.width) or 0
    if w <= 0 then w = (f.cfg and tonumber(f.cfg.healthWidth)) or 100 end
    b:SetSize(w, tonumber(c.height) or 6)
    NP.SetAnchor(b, c.anchor, rel)
    b:SetStatusBarTexture(NP.GetStatusBarTexture(c.texture))
    b.bg:SetColorTexture(NP.RGBA(c.bgColor))
    b.border:SetBorderSize(c.border and (tonumber(c.borderSize) or 1) or 0)
    b.border:SetBorderColor(NP.RGBA(c.borderColor))
    NP.StyleText(b.text, { font = c.textFont or "Noto Sans SemiBold", size = tonumber(c.textSize) or 8, outline = "OUTLINE", shadow = true, color = c.textColor or { 1, 1, 1, 1 } })
end
function PlayerBars:Layout(f)
    local p = NP.Prof(f)
    StyleMini(f.powerBar, p.playerPower, f.health, f, "playerPower")
    local rel = f.health
    if p.playerHealth.attach ~= "health" and f.cast and not f.cast.disabled and not f.cast.nameCast and f.cast:GetNumPoints() > 0 then rel = f.cast end
    StyleMini(f.playerHealthBar, p.playerHealth, rel, f, "playerHealth")
end
local function RefreshMini(f)
    if f.isPreview then return end
    local p = NP.Prof(f)
    local baseOk = f.active and f.isTarget and f.cfg.mode ~= "nameOnly" and f.health:IsShown()
    local hostile = f.unit and NP.Truthy(_G.UnitCanAttack("player", f.unit), false) or false
    local inCbt = NP.Truthy(_G.UnitAffectingCombat("player"), false)

    local pc, pb = p.playerPower, f.powerBar
    if baseOk and pc.enabled and (not pc.onlyAttackable or hostile) and (not pc.onlyInCombat or inCbt) then
        local pt, tok = _G.UnitPowerType("player")
        pb:SetStatusBarColor(NP.RGBA((pc.typeColor ~= false and tok and POWER_COLORS[tok]) or pc.color))
        local mx, v = _G.UnitPowerMax("player", pt), _G.UnitPower("player", pt)
        pb:SetMinMaxValues(0, mx); pb:SetValue(v)
        if pc.text == "value" then pb.text:SetText(v); pb.text:Show()
        elseif pc.text == "percent" and not NP.IsSecret(v) and not NP.IsSecret(mx) and mx > 0 then pb.text:SetFormattedText("%d%%", floor(v / mx * 100 + 0.5)); pb.text:Show()
        else pb.text:Hide() end
        pb:Show()
    else pb:Hide() end

    local hc, hb = p.playerHealth, f.playerHealthBar
    if baseOk and hc.enabled and (not hc.onlyAttackable or hostile) and (not hc.onlyInCombat or inCbt) then
        local col = (hc.colorMode == "class" and NP.MyClassColor(hc.color, true)) or hc.color
        hb:SetStatusBarColor(NP.RGBA(col))
        local mx, v = _G.UnitHealthMax("player"), _G.UnitHealth("player")
        hb:SetMinMaxValues(0, mx); hb:SetValue(v)
        if hc.text == "value" then hb.text:SetText(_G.AbbreviateNumbers and _G.AbbreviateNumbers(v) or v); hb.text:Show()
        elseif hc.text == "percent" and not NP.IsSecret(v) and not NP.IsSecret(mx) and mx > 0 then hb.text:SetFormattedText("%d%%", floor(v / mx * 100 + 0.5)); hb.text:Show()
        else hb.text:Hide() end
        hb:Show()
    else hb:Hide() end
end
function PlayerBars:Update(f) RefreshMini(f) end
function PlayerBars:OnTargetChanged(f) RefreshMini(f) end
function PlayerBars:Clear(f) f.powerBar:Hide(); f.playerHealthBar:Hide() end
function PlayerBars:Preview(f, st)
    local p = NP.Prof(f)
    local function prev(b, c, key, defCol)
        if not (c and (c.enabled or st.selected == key)) or f.cfg.mode == "nameOnly" or not (st.target or st.selected == key) then b:Hide(); return end
        b:SetStatusBarColor(NP.RGBA(defCol)); b:SetMinMaxValues(0, 100); b:SetValue(70)
        b.text:SetText(c.text == "value" and "7000" or "70%"); b.text:SetShown(c.text ~= "none")
        b:SetAlpha(c.enabled and 1 or 0.4); b:Show()
    end
    prev(f.powerBar, p.playerPower, "playerPower", p.playerPower.color)
    prev(f.playerHealthBar, p.playerHealth, "playerHealth", p.playerHealth.color)
end
NP.RegisterElement("PlayerBars", PlayerBars)

-- UnitTarget + Extras (M+ % e Boss Energy)
local Extras = {}
function Extras:Create(f)
    local ut = f.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); ut:SetWordWrap(false); ut:Hide(); f.unitTarget = ut
    local fr = _G.CreateFrame("Frame", nil, f); fr:SetAllPoints(f); f.extrasFrame = fr
    f.mplus = fr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.mplus:Hide()
    local eb = _G.CreateFrame("StatusBar", nil, fr); eb:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
    eb.bg = eb:CreateTexture(nil, "BACKGROUND", nil, -8); eb.bg:SetAllPoints()
    eb.border = NP.CreateBorder(eb, "OVERLAY", 6)
    eb.text = eb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); eb.text:SetPoint("CENTER"); eb:Hide()
    f.energy = eb
end
function Extras:Layout(f)
    local c = f.cfg.unitTarget
    if not (c and c.enabled) or f.cfg.mode == "nameOnly" then f.unitTarget:Hide() else
        NP.StyleText(f.unitTarget, c, nil, true); NP.SetAnchor(f.unitTarget, c.anchor, f.health)
        f.unitTarget:SetWidth((c.maxWidth or 0) > 0 and c.maxWidth or 0)
    end
    local x = NP.Prof(f).extras
    f.extrasFrame:SetFrameLevel(f.health:GetFrameLevel() + 6)
    local m = x.mplus
    NP.StyleText(f.mplus, { font = m.font, size = m.size, outline = m.outline, shadow = true, color = m.color })
    f.mplus:ClearAllPoints()
    if f.cfg.mode ~= "nameOnly" and f.name:IsShown() then f.mplus:SetPoint("TOPLEFT", f.name, "BOTTOMLEFT", m.offsetX, m.offsetY)
    else f.mplus:SetPoint("BOTTOMLEFT", f.health, "TOPLEFT", m.offsetX, m.offsetY) end
    local e, eb = x.bossEnergy, f.energy
    eb:ClearAllPoints()
    eb:SetPoint("TOPLEFT", f.health, "BOTTOMLEFT", e.insetX, e.offsetY); eb:SetPoint("TOPRIGHT", f.health, "BOTTOMRIGHT", -e.insetX, e.offsetY)
    eb:SetHeight(e.height); eb:SetStatusBarTexture(NP.GetStatusBarTexture(e.texture))
    eb:SetStatusBarColor(NP.RGBA(e.fillColor)); eb.bg:SetColorTexture(NP.RGBA(e.bgColor))
    eb.border:SetBorderSize(e.borderSize or 1); eb.border:SetBorderColor(NP.RGBA(e.borderColor))
    NP.StyleText(eb.text, { font = e.font, size = e.textSize, outline = e.textOutline, shadow = true, color = e.textColor })
    eb.text:ClearAllPoints(); eb.text:SetPoint("CENTER", eb, "CENTER", e.textOffsetX or 0, e.textOffsetY or 0); eb.text:SetShown(e.text)
end

local function UpdateExtras(f)
    local c, t = f.cfg.unitTarget, f.unitTarget
    if t and c and c.enabled and f.cfg.mode ~= "nameOnly" and f.unit and not (c.hideWhileCasting and f.isCasting) and NP.Truthy(_G.UnitExists(f.unit .. "target"), true) then
        local name = _G.UnitName(f.unit .. "target")
        if name ~= nil then
            t:SetText(name)
            local cc = c.useClassColor and NP.Truthy(_G.UnitIsPlayer(f.unit .. "target"), false) and NP.ClassColorObj(select(2, _G.UnitClass(f.unit .. "target")))
            if cc then t:SetTextColor(cc:GetRGB()) else t:SetTextColor(NP.RGBA(c.color)) end
            t:Show()
        else t:Hide() end
    elseif t then t:Hide() end

    local m = NP.Prof(f).extras.mplus
    local cm = _G.C_ChallengeMode and _G.C_ChallengeMode.IsChallengeModeActive and NP.Truthy(_G.C_ChallengeMode.IsChallengeModeActive(), false)
    if m.enabled and f.kind == "enemynpc" and f.cfg.mode ~= "nameOnly" and not (m.hideWhileCasting and f.isCasting) then
        if cm and _G.C_ScenarioInfo and _G.C_ScenarioInfo.GetUnitCriteriaProgressValues then
            local abs, _, pctText = _G.C_ScenarioInfo.GetUnitCriteriaProgressValues(f.unit)
            if type(abs) ~= "nil" then
                f.mplus:SetFormattedText(m.mode == "absolute" and "%s" or (m.mode == "both" and "%s • %s" or "%s"), m.mode == "percent" and pctText or abs, pctText)
                f.mplus:Show()
            else f.mplus:Hide() end
        elseif m.preview then
            f.mplus:SetText(m.mode == "absolute" and "10" or (m.mode == "both" and "10 • 1.7%" or "1.7%")); f.mplus:Show()
        else f.mplus:Hide() end
    else f.mplus:Hide() end

    local e, eb = NP.Prof(f).extras.bossEnergy, f.energy
    local isBoss = (f.unitTypeKey == "boss" or (f.unitTypeKey == "miniboss" and e.miniboss))
    local pt = f.unit and _G.UnitPowerType(f.unit)
    local hasE = not NP.IsSecret(pt) and (pt == 1 or pt == 3)
    if e.enabled and f.cfg.mode ~= "nameOnly" and f.hostile and not (e.hideWhileCasting and f.isCasting) and ((isBoss and hasE) or e.preview) then
        if isBoss and hasE then
            local mx, v = _G.UnitPowerMax(f.unit), _G.UnitPower(f.unit)
            eb:SetMinMaxValues(0, mx); eb:SetValue(v)
            eb.text:SetFormattedText(e.textFormat == "current" and "%s" or "%s / %s", v, mx)
            eb:Show()
        else eb:SetMinMaxValues(0, 100); eb:SetValue(65); eb.text:SetText("65 / 100"); eb:Show() end
    else eb:Hide() end
end

function NP.OnCastStateChanged(f) UpdateExtras(f); NP.UpdateGuildForCast(f) end
function Extras:Update(f) f.hostile = NP.Truthy(_G.UnitCanAttack("player", f.unit), false); UpdateExtras(f) end
function Extras:OnEvent(f) UpdateExtras(f) end
function Extras:Clear(f) f.unitTarget:Hide(); f.mplus:Hide(); f.energy:Hide() end
Extras.unitEvents = { UNIT_TARGET = "OnEvent", UNIT_POWER_UPDATE = "OnEvent", UNIT_MAXPOWER = "OnEvent", UNIT_DISPLAYPOWER = "OnEvent" }
function Extras:Preview(f, st)
    local c = f.cfg.unitTarget
    if c and c.enabled and f.cfg.mode ~= "nameOnly" and not (c.hideWhileCasting and st.casting and st.selected ~= "unitTarget") then
        f.unitTarget:SetText("Tanque"); f.unitTarget:SetTextColor(NP.RGBA(c.useClassColor and (NP.CLASS_COLORS.WARRIOR or c.color) or c.color)); f.unitTarget:Show()
    else f.unitTarget:Hide() end
    local x = NP.Prof(f).extras
    if x.mplus.enabled and f.kind == "enemynpc" and f.cfg.mode ~= "nameOnly" and not (x.mplus.hideWhileCasting and st.casting and st.selected ~= "mplus") then
        f.mplus:SetText(x.mplus.mode == "absolute" and "4" or (x.mplus.mode == "both" and "4 • 0.9%" or "0.9%")); f.mplus:Show()
    else f.mplus:Hide() end
    local e = x.bossEnergy
    if (st.boss and (e.enabled or st.selected == "energy")) and f.cfg.mode ~= "nameOnly" and not (e.hideWhileCasting and st.casting and st.selected ~= "energy") then
        f.energy:SetMinMaxValues(0, 100); f.energy:SetValue(65); f.energy.text:SetText("65 / 100"); f.energy:Show()
    else f.energy:Hide() end
end
NP.RegisterElement("Extras", Extras)

local resWatcher = _G.CreateFrame("Frame")
resWatcher:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
resWatcher:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
resWatcher:RegisterUnitEvent("UNIT_MAXPOWER", "player")
resWatcher:RegisterUnitEvent("UNIT_HEALTH", "player")
resWatcher:RegisterUnitEvent("UNIT_MAXHEALTH", "player")
Azaath.SafeRegister(resWatcher, "RUNE_POWER_UPDATE")
Azaath.SafeRegister(resWatcher, "UPDATE_SHAPESHIFT_FORM")
Azaath.SafeRegister(resWatcher, "PLAYER_REGEN_DISABLED")
Azaath.SafeRegister(resWatcher, "PLAYER_REGEN_ENABLED")
resWatcher:SetScript("OnEvent", function(_, event)
    if not NP.db then return end
    local f = NP.targetPlate and NP.targetPlate.AzNPFrame
    if not (f and f.active and f.isTarget) then return end
    if event == "UPDATE_SHAPESHIFT_FORM" then Resources:Layout(f) end
    RefreshResourceBar(f); RefreshMini(f)
end)
