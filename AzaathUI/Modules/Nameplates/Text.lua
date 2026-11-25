--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Text.lua
    Textos das placas: nome (com preenchimento de vida opcional), guilda/título
    de NPC, texto de vida (%, valor, abreviado/completo) e nível + caixa.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, tonumber, tostring, type = pairs, ipairs, pcall, tonumber, tostring, type
local floor, ceil, max, min, format = math.floor, math.ceil, math.max, math.min, string.format

local UnitName          = _G.UnitName
local UnitHealth        = _G.UnitHealth
local UnitHealthMax     = _G.UnitHealthMax
local UnitHealthPercent = _G.UnitHealthPercent
local UnitLevel         = _G.UnitLevel
local Interp            = _G.Enum and _G.Enum.StatusBarInterpolation

local TEX = NP.MEDIA
local BOX_SHAPES = {
    square = true,
    rounded = TEX .. "box-rounded.png",
    bevel   = TEX .. "box-bevel.png",
    hex     = TEX .. "box-hex.png",
    circle  = TEX .. "box-circle.png",
}
NP.LEVEL_BOX_SHAPES = { square = "Quadrado", rounded = "Arredondado", bevel = "Chanfrado", hex = "Hexágono", circle = "Círculo" }
NP.LEVEL_BOX_SHAPE_ORDER = { "square", "rounded", "bevel", "hex", "circle" }

local Text = {}

function Text:Create(f)
    local tf = _G.CreateFrame("Frame", nil, f)
    tf:SetAllPoints(f)
    f.textFrame = tf

    f.name = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.name:SetWordWrap(false)

    f.rpTitle = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.rpTitle:SetWordWrap(false)
    f.rpTitle:Hide()

    f.healthText = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    f.levelText = tf:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

    local box = _G.CreateFrame("Frame", nil, f)
    box.bgFlat = box:CreateTexture(nil, "BACKGROUND", nil, -1)
    box.bgFlat:SetAllPoints(); box.bgFlat:SetColorTexture(1, 1, 1, 1)
    box.bg = box:CreateTexture(nil, "BACKGROUND")
    box.bg:SetAllPoints()
    box.border = NP.CreateBorder(box, "BORDER", 1)
    box.shapeBorder = box:CreateTexture(nil, "BACKGROUND", nil, 1)
    box.shapeBorder:SetAllPoints(); box.shapeBorder:Hide()
    box.shapeFill = box:CreateTexture(nil, "BACKGROUND", nil, 2)
    box.shapeFill:Hide()
    box:Hide()
    f.levelBox = box

    -- Insígnia triangular original do Azaath + Asas de Elite/Raro (Media/Target)
    local T_TEX = "Interface\\AddOns\\AzaathUI\\Media\\Target\\"
    local badge = _G.CreateFrame("Frame", nil, f)
    badge.tex = badge:CreateTexture(nil, "ARTWORK")
    badge.tex:SetAllPoints(badge)
    badge.tex:SetTexture(T_TEX .. "InkBadge.tga")
    badge.rare = badge:CreateTexture(nil, "ARTWORK", nil, 2)
    badge.rare:SetAllPoints(badge)
    badge.rare:Hide()
    badge.wings = badge:CreateTexture(nil, "BACKGROUND")
    badge.wings:SetPoint("TOP", badge, "TOP", 0, 0)
    badge.wings:Hide()
    badge.skull = badge:CreateTexture(nil, "OVERLAY")
    badge.skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    badge.skull:SetVertexColor(0.12, 0.04, 0.04, 1)
    badge.skull:Hide()
    badge:Hide()
    f.azBadge = badge
end

-- Preenchimento de vida dentro do próprio texto do nome
local function FillOn(f)
    local n = f.cfg and f.cfg.name
    return n and n.enabled and n.healthFill and true or false
end

local function FollowBar(f)
    local cfg = f.cfg
    return cfg and cfg.mode ~= "nameOnly" and cfg.name and cfg.name.fillFollowBar and f.health and true or false
end

local function FillParts(f)
    local p = f.nameFill
    if p then return p end
    p = {}
    p.bar = _G.CreateFrame("StatusBar", nil, f.textFrame)
    p.bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    p.bar:SetStatusBarColor(0, 0, 0, 0)
    p.bar:SetMinMaxValues(0, 1); p.bar:SetValue(1); p.bar:SetAllPoints(f.name)
    p.mask = _G.CreateFrame("Frame", nil, f.textFrame)
    p.mask:SetClipsChildren(true)
    p.mask:SetPoint("TOPLEFT", p.bar:GetStatusBarTexture(), "TOPLEFT", -4, 4)
    p.mask:SetPoint("BOTTOMRIGHT", p.bar:GetStatusBarTexture(), "BOTTOMRIGHT", 0, -4)
    p.text = p.mask:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.text:SetWordWrap(false); p.text:SetAllPoints(f.name)

    p.heal = _G.CreateFrame("StatusBar", nil, f.textFrame)
    p.heal:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    p.heal:SetStatusBarColor(0, 0, 0, 0)
    p.heal:SetMinMaxValues(0, 1); p.heal:SetValue(0)
    p.hmask = _G.CreateFrame("Frame", nil, f.textFrame)
    p.hmask:SetClipsChildren(true)
    p.hmask:SetPoint("TOPLEFT", p.heal:GetStatusBarTexture(), "TOPLEFT", 0, 4)
    p.hmask:SetPoint("BOTTOMRIGHT", p.heal:GetStatusBarTexture(), "BOTTOMRIGHT", 0, -4)
    p.htext = p.hmask:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    p.htext:SetWordWrap(false); p.htext:SetAllPoints(f.name)
    p.heal:Hide(); p.hmask:Hide(); p.follow = false
    f.nameFill = p
    return p
end

local function PlaceFill(f, p)
    local follow = FollowBar(f)
    if p.follow == follow then return end
    p.follow = follow
    local tex = p.bar:GetStatusBarTexture()
    p.bar:ClearAllPoints(); p.mask:ClearAllPoints()
    if follow then
        p.bar:SetPoint("LEFT", f.health, "LEFT"); p.bar:SetPoint("RIGHT", f.health, "RIGHT")
        p.bar:SetPoint("TOP", f.name, "TOP");    p.bar:SetPoint("BOTTOM", f.name, "BOTTOM")
        p.mask:SetPoint("TOPLEFT", tex, "TOPLEFT", -400, 4)
    else
        p.bar:SetAllPoints(f.name)
        p.mask:SetPoint("TOPLEFT", tex, "TOPLEFT", -4, 4)
    end
    p.mask:SetPoint("BOTTOMRIGHT", tex, "BOTTOMRIGHT", 0, -4)
end

function NP.NameHealOn(f)
    if not f or f.kind ~= "friendlyplayer" or not f.cfg then return false end
    if f.profKind and f.profKind ~= "friendlyplate" then return false end
    if not f.profKind and f.cfg.mode ~= "nameOnly" then return false end
    local n = f.cfg.name
    if not (n and n.enabled and n.healthFill) then return false end
    local hp = NP.Prof(f).style.healPrediction
    return hp and hp.enabled and true or false
end

local function SyncNameHeal(f)
    local p = f.nameFill
    if not p then return end
    if not NP.NameHealOn(f) or not f.name:IsShown() then p.heal:Hide(); p.hmask:Hide(); return end
    local w = p.follow and f.health and f.health:GetWidth() or f.name:GetWidth()
    local h = f.name:GetHeight()
    if NP.IsSecret(w) or NP.IsSecret(h) or type(w) ~= "number" or type(h) ~= "number" or w <= 0 then
        p.heal:Hide(); p.hmask:Hide(); return
    end
    p.heal:ClearAllPoints(); p.heal:SetPoint("TOPLEFT", p.bar:GetStatusBarTexture(), "TOPRIGHT")
    p.heal:SetSize(w, h)
    p.htext:SetText(f.name:GetText())
    p.htext:SetTextColor(NP.RGBA(NP.Prof(f).style.healPrediction.color or { 0.3, 1, 0.4, 0.55 }))
    p.heal:Show(); p.hmask:Show()
end

local function HideFill(f)
    local p = f.nameFill
    if p then p.mask:Hide(); p.bar:Hide(); p.heal:Hide(); p.hmask:Hide() end
end

local function SyncFill(f)
    if not FillOn(f) or not f.name:IsShown() then HideFill(f); return end
    local p = FillParts(f)
    p.text:SetText(f.name:GetText())
    if f.azNameColor then p.text:SetTextColor(NP.RGBA(f.azNameColor)) end
    f.name:SetTextColor(NP.RGBA(f.cfg.name.lostColor or { 0.42, 0.42, 0.42, 1 }))
    p.bar:Show(); p.mask:Show()
    SyncNameHeal(f)
end

local function UpdateFillValue(f, animate)
    if not FillOn(f) or not f.unit or not f.nameFill then return end
    local bar = f.nameFill.bar
    local interp = (animate and NP.Prof(f).style.animateHealth and Interp) and Interp.ExponentialEaseOut or (Interp and Interp.Immediate)
    local maxH, curH = UnitHealthMax(f.unit), UnitHealth(f.unit)
    if interp then bar:SetMinMaxValues(0, maxH, interp); bar:SetValue(curH, interp)
    else bar:SetMinMaxValues(0, maxH); bar:SetValue(curH) end
    local p = f.nameFill
    if NP.NameHealOn(f) and _G.UnitGetIncomingHeals then
        p.heal:SetMinMaxValues(0, maxH)
        local v = _G.UnitGetIncomingHeals(f.unit)
        if NP.IsSecret(v) or type(v) == "number" then p.heal:SetValue(v) else p.heal:SetValue(0) end
    else
        p.heal:SetValue(0)
    end
end

-- Utilitários de nível & subtítulo de NPC
function NP.LevelOnName(f)
    local cfg = f and f.cfg
    if f and f.azCombatOwn then return cfg and cfg.level and cfg.level.enabled and true or false end
    return (f.kind == "friendlyplayer" or f.kind == "friendlynpc") and not f.profKind and cfg and cfg.mode == "nameOnly"
        and cfg.level and cfg.level.enabled and cfg.level.onName and true or false
end

local slotMeasurer, slotCache = nil, {}
function NP.LevelSlotWidth(l)
    local key = tostring(l.font) .. "|" .. tostring(l.size) .. "|" .. tostring(l.outline) .. "|" .. NP.FontOverrideKey()
    if slotCache[key] then return slotCache[key] end
    if not slotMeasurer then
        local holder = _G.CreateFrame("Frame"); holder:Hide()
        slotMeasurer = holder:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    end
    NP.StyleText(slotMeasurer, l)
    local w = 0
    for _, sample in ipairs({ "88", "??", "60", "90" }) do
        slotMeasurer:SetText(sample)
        local sw = slotMeasurer:GetStringWidth()
        if NP.IsSecret(sw) or type(sw) ~= "number" then return nil end
        if sw > w then w = sw end
    end
    local fl = ceil((tonumber(l.size) or 12) * 1.5)
    if w >= fl * 0.6 then slotCache[key] = max(ceil(w + 1), fl) end
    return max(ceil(w + 1), fl)
end
function NP.ResetLevelSlots() wipe(slotCache) end

function NP.IsPet(unit)
    if not unit or NP.Truthy(_G.UnitIsPlayer(unit), true) then return false end
    local pc = _G.UnitPlayerControlled and _G.UnitPlayerControlled(unit)
    if pc == nil or NP.IsSecret(pc) then return false end
    return pc and true or false
end

local npcTitles, LEVEL_PATTERNS = {}, nil
local function IsLevelLine(s)
    if not LEVEL_PATTERNS then
        LEVEL_PATTERNS = {}
        for _, tmpl in ipairs({ _G.TOOLTIP_UNIT_LEVEL, _G.TOOLTIP_UNIT_LEVEL_TYPE, _G.TOOLTIP_UNIT_LEVEL_CLASS, _G.TOOLTIP_UNIT_LEVEL_RACE_CLASS, _G.UNIT_LEVEL_TEMPLATE }) do
            if type(tmpl) == "string" then
                local p = tmpl:gsub("%%%d*%$?[sd]", "\1"):gsub("[%%%(%)%.%+%-%*%?%[%]%^%$]", "%%%0")
                p = "^" .. p:gsub("\1", ".+") .. "$"
                if pcall(string.find, "", p) then LEVEL_PATTERNS[#LEVEL_PATTERNS + 1] = p end
            end
        end
    end
    for _, p in ipairs(LEVEL_PATTERNS) do
        local ok, hit = pcall(string.find, s, p)
        if ok and hit then return true end
    end
    return s:find("%d") ~= nil and #s < 40 and (s:find("%?%?") or s:find("^%S+ %d+")) ~= nil
end

function NP.NPCTitle(unit)
    local name = UnitName(unit)
    if NP.IsSecret(name) or NP.IsPet(unit) then name = nil end
    local known = name and npcTitles[name]
    if known ~= nil then return known or nil end
    local TI = _G.C_TooltipInfo
    if not (TI and TI.GetUnit) then return nil end
    local ok, info = pcall(TI.GetUnit, unit)
    if not ok or type(info) ~= "table" or type(info.lines) ~= "table" then return nil end
    local first = (_G.GetCVarBool and _G.GetCVarBool("colorblindmode")) and 3 or 2
    local line = info.lines[first]
    local text = line and line.leftText
    if text == nil or NP.IsSecret(text) then return nil end
    local title = false
    if type(text) == "string" and text ~= "" and not IsLevelLine(text) then title = text end
    if name then npcTitles[name] = title end
    return title or nil
end

function NP.SocialNameColor(f, n)
    if not (f and f.unit and n) then return nil end
    if f.kind == "friendlynpc" and n.petColorOn and NP.IsPet(f.unit) then return n.petColor end
    if f.kind ~= "friendlyplayer" then return nil end
    if n.partyColorOn and NP.IsGroupMate(f.unit) then return n.partyColor end
    if n.guildColorOn and NP.IsGuildMate(f.unit) then return n.guildColor end
    if n.friendColorOn and _G.C_FriendList and _G.C_FriendList.IsFriend then
        local guid = _G.UnitGUID(f.unit)
        if guid and not NP.IsSecret(guid) then
            local ok, fr = pcall(_G.C_FriendList.IsFriend, guid)
            if ok and fr then return n.friendColor end
        end
    end
    return nil
end

local function SetNameColor(f, r, g, b, a)
    local c = f.azNameColor or {}
    f.azNameColor = c
    c[1], c[2], c[3], c[4] = r, g, b, a or 1
    f.name:SetTextColor(r, g, b, a or 1)
end

local function SetSub(fs, t)
    if NP.db.general.plainTitles then fs:SetText(t) else fs:SetFormattedText("<%s>", t) end
end

local function ShowGuild(f)
    local gc = f.cfg.guild
    if not (gc and gc.enabled) then return false end
    if f.kind == "friendlynpc" then
        if gc.hidePets and f.unit and NP.IsPet(f.unit) then return false end
        local t = f.unit and NP.NPCTitle(f.unit)
        if not t then return false end
        SetSub(f.rpTitle, t)
        f.rpTitle:SetTextColor(NP.RGBA(gc.color))
        f.rpTitle:Show()
        return true
    end
    if not (f.kind == "friendlyplayer" or f.kind == "enemyplayer") or not _G.GetGuildInfo then return false end
    local g = _G.GetGuildInfo(f.unit)
    if g == nil or (not NP.IsSecret(g) and g == "") then return false end
    SetSub(f.rpTitle, g)
    local col = gc.color
    if gc.myGuildColorOn and f.kind == "friendlyplayer" and NP.IsGuildMate(f.unit) then col = gc.myGuildColor or col end
    f.rpTitle:SetTextColor(NP.RGBA(col))
    f.rpTitle:Show()
    return true
end

local function AttackingYou(unit)
    local t = _G.UnitThreatSituation and _G.UnitThreatSituation("player", unit)
    if not NP.IsSecret(t) then return type(t) == "number" and t >= 2 end
    local onYou = _G.UnitIsUnit(unit .. "target", "player")
    if NP.IsSecret(onYou) then return false end
    return onYou and true or false
end

function NP.NameReactionColor(f)
    if f.kind ~= "enemynpc" and f.kind ~= "enemyplayer" then return nil end
    if AttackingYou(f.unit) then return f.cfg.name.attackColor or NP.db.colors.reaction.hostile end
    return nil
end

function NP.NameThreatColor(f)
    if not f or (f.kind ~= "enemynpc" and f.kind ~= "enemyplayer") or f.isPreview or not f.unit then return nil end
    local th = NP.Prof(f).colors.threat
    if th.showOn ~= "name" then return nil end
    local ok, c = pcall(NP.GetThreatColor, f.unit, th)
    return ok and c or nil
end

local function PlaceName(f, hasSub)
    local cfg, gc = f.cfg, f.cfg.guild
    if cfg.mode == "nameOnly" then return end
    local want = "own"
    if (f.kind == "friendlyplayer" or f.kind == "enemyplayer") and gc and gc.enabled and ((gc.anchor or {}).side or 8) == 8 then
        want = hasSub and "above" or "guild"
    end
    if want == (f.azNamePlace or "own") then return end
    f.azNamePlace = want
    if want == "guild" then
        NP.SetAnchor(f.name, gc.anchor or { side = 8, x = 0, y = 2 }, f.health)
    elseif want == "above" then
        f.name:ClearAllPoints()
        f.name:SetPoint("BOTTOM", f.rpTitle, "TOP", 0, 1)
    else
        NP.SetAnchor(f.name, cfg.name.anchor, f.health)
    end
end

local function FormatPlayerName(first, second, mode)
    if NP.IsSecret(first) or NP.IsSecret(second) or type(second) ~= "string" or second == "" or mode == "first" then
        return first
    end
    if mode == "second" then return second end
    local sep = (_G.Constants and _G.Constants.CharacterNameSeparatorConsts and _G.Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR) or " "
    return first .. sep .. second
end

function NP.UpdateNameText(f)
    local n = f.cfg.name
    if not n.enabled then f.rpTitle:Hide(); return end
    local gc = f.cfg.guild
    local hideForCast = gc and gc.hideWhileCasting and f.isCasting and (f.kind == "enemyplayer" or f.kind == "friendlyplayer")
    local rpName, rr, rg, rb, rpSub
    if NP.RP then rpName, rr, rg, rb, rpSub = NP.RP.Get(f) end
    if rpName then
        f.name:SetText(rpName)
        local sc = NP.SocialNameColor(f, n)
        if sc then SetNameColor(f, NP.RGBA(sc))
        elseif rr then SetNameColor(f, rr, rg, rb, 1)
        else SetNameColor(f, NP.RGBA((n.useClassColor and NP.GetClassColor(f.unit)) or n.color)) end
        local has = false
        if rpSub ~= nil and rpSub ~= "" and not hideForCast then
            f.rpTitle:SetText(rpSub)
            f.rpTitle:SetTextColor(NP.RGBA((gc or {}).color or { 0.85, 0.85, 0.85, 1 }))
            f.rpTitle:Show(); has = true
        else
            f.rpTitle:Hide()
        end
        PlaceName(f, has); SyncFill(f)
        return
    end

    local first, second = UnitName(f.unit)
    local rawName = FormatPlayerName(first, second, n.playerNames)
    if n.tracked and not NP.IsSecret(rawName) and type(rawName) == "string" and Azaath.Tracked then
        rawName = Azaath.Tracked(rawName)
    end
    f.name:SetText(rawName)
    local bs = NP.Prof(f).style.barStyle or "modern"
    local threatNameCol = NP.NameThreatColor(f)
    local col
    if threatNameCol then
        col = threatNameCol
    elseif NP.Targeted(f) and bs ~= "modern" then
        col = { 1, 0.84, 0.43, 1 }
    else
        col = NP.SocialNameColor(f, n)
            or (n.reactionColor and NP.NameReactionColor(f))
            or (n.reputationTint and NP.NameReputationColor(f.unit))
            or (n.reactionTint and NP.NameReactionColor2(f.unit))
            or (n.useClassColor and NP.GetClassColor(f.unit))
            or n.color
    end
    SetNameColor(f, NP.RGBA(col))

    local has = not hideForCast and ShowGuild(f) or false
    if not has then f.rpTitle:Hide() end
    PlaceName(f, has)
    SyncFill(f)
end

function NP.UpdateGuildForCast(f)
    if not (f and f.active and f.cfg and f.cfg.guild and f.cfg.guild.hideWhileCasting) then return end
    NP.UpdateNameText(f)
end

local function FormatHealth(f)
    local h = f.cfg.healthText
    if not h.enabled or f.cfg.mode == "nameOnly" then return end
    local unit = f.unit
    local cur, mx = UnitHealth(unit), UnitHealthMax(unit)

    if NP.IsSecret(cur) or NP.IsSecret(mx) then
        if h.showPercent and h.showValue then
            local p = UnitHealthPercent and _G.CurveConstants and UnitHealthPercent(unit, true, _G.CurveConstants.ScaleTo100)
            if p ~= nil and _G.AbbreviateNumbers then
                f.healthText:SetFormattedText(h.decimals and "%s (%.1f%%)" or "%s (%.0f%%)", _G.AbbreviateNumbers(cur), p)
            else
                f.healthText:SetText(_G.AbbreviateNumbers and _G.AbbreviateNumbers(cur) or cur)
            end
        elseif h.showPercent then
            local p = UnitHealthPercent and _G.CurveConstants and UnitHealthPercent(unit, true, _G.CurveConstants.ScaleTo100)
            if p ~= nil then f.healthText:SetFormattedText(h.decimals and "%.1f%%" or "%.0f%%", p) else f.healthText:SetText("") end
        elseif h.showValue then
            f.healthText:SetText((not h.fullNumbers and _G.AbbreviateNumbers) and _G.AbbreviateNumbers(cur) or cur)
        else
            f.healthText:SetText("")
        end
        return
    end

    if type(mx) ~= "number" or mx <= 0 then f.healthText:SetText(""); return end
    local pct = (cur / mx) * 100
    local valStr = h.fullNumbers and tostring(floor(cur + 0.5)) or ((_G.AbbreviateNumbers and _G.AbbreviateNumbers(cur)) or tostring(floor(cur + 0.5)))
    if h.showPercent and h.showValue then
        f.healthText:SetFormattedText(h.decimals and "%s (%.1f%%)" or "%s (%.0f%%)", valStr, pct)
    elseif h.showPercent then
        f.healthText:SetFormattedText(h.decimals and "%.1f%%" or "%.0f%%", pct)
    elseif h.showValue then
        f.healthText:SetText(valStr)
    else
        f.healthText:SetText("")
    end
end

local AZ_ELITE_TEX = {
    rare = "EliteSilver", rareelite = "EliteSilver",
    elite = "EliteGold", worldboss = "EliteGold",
}
local TARGET_MEDIA = "Interface\\AddOns\\AzaathUI\\Media\\Target\\"

local function IsAzBadgeStyle(f)
    local st = NP.Prof(f).style
    return (st.barStyle == "azaath" or st.barStyle == "azaath_ink")
        and f.cfg and f.cfg.mode ~= "nameOnly" and not NP.LevelOnName(f)
end

local function UpdateAzBadgeWings(f, forceStyle)
    local badge = f.azBadge
    if not (badge and badge:IsShown()) then return end
    local style = forceStyle
    if not style and f.unit then
        local c = _G.UnitClassification and _G.UnitClassification(f.unit)
        style = (c and not NP.IsSecret(c)) and AZ_ELITE_TEX[c] or nil
    end
    if style then
        badge.wings:SetTexture(TARGET_MEDIA .. style .. ".tga")
        badge.wings:Show()
        badge.rare:SetTexture(TARGET_MEDIA .. (style == "EliteGold" and "RareTriGold.tga" or "RareTriSilver.tga"))
        badge.rare:Show()
    else
        badge.wings:Hide()
        badge.rare:Hide()
    end
end

local function UpdateLevel(f)
    local l = f.cfg.level
    if not l.enabled or (f.cfg.mode == "nameOnly" and not NP.LevelOnName(f)) then return end
    local azOn = IsAzBadgeStyle(f)
    local lvl = _G.UnitEffectiveLevel and _G.UnitEffectiveLevel(f.unit) or UnitLevel(f.unit)
    if azOn and f.azBadge then
        UpdateAzBadgeWings(f)
        if NP.IsSecret(lvl) then
            f.azBadge.skull:Hide()
            f.levelText:SetText(lvl)
            f.levelText:SetTextColor(0.09, 0.03, 0.03, 1)
            f.levelText:Show()
        elseif lvl and lvl > 0 then
            f.azBadge.skull:Hide()
            f.levelText:SetText(lvl)
            f.levelText:SetTextColor(0.09, 0.03, 0.03, 1)
            f.levelText:Show()
        else
            f.levelText:SetText("")
            f.azBadge.skull:Show()
        end
        return
    end
    if NP.IsSecret(lvl) then
        f.levelText:SetText(lvl)
        f.levelText:SetTextColor(NP.RGBA(l.color))
    elseif lvl and lvl > 0 then
        f.levelText:SetText(lvl)
        if l.plainColor then
            f.levelText:SetTextColor(NP.RGBA(l.color))
        else
            local diff = _G.GetQuestDifficultyColor and _G.GetQuestDifficultyColor(lvl)
            if diff then f.levelText:SetTextColor(diff.r, diff.g, diff.b, 1) else f.levelText:SetTextColor(NP.RGBA(l.color)) end
        end
    else
        f.levelText:SetText("??")
        f.levelText:SetTextColor(1, 0.2, 0.2, 1)
    end
    if l.box and (l.boxClassBorder or l.boxClassFill) and f.unit and NP.Truthy(_G.UnitIsPlayer(f.unit), false) then
        local cc = NP.GetClassColor(f.unit)
        if cc then
            local box = f.levelBox
            if l.boxClassFill then
                if box.azShape == "square" then box.bgFlat:SetVertexColor(NP.RGBA(cc)); box.bgFlat:Show()
                else box.shapeFill:SetVertexColor(NP.RGBA(cc)) end
            end
            if l.boxClassBorder then
                if box.azShape == "square" then box.border:SetBorderColor(NP.RGBA(cc))
                else box.shapeBorder:SetVertexColor(NP.RGBA(cc)) end
            end
        end
    end
end

function Text:Layout(f)
    local cfg = f.cfg
    local tf = f.textFrame
    tf:SetFrameLevel(f.health:GetFrameLevel() + 5)

    local n = cfg.name
    NP.StyleText(f.name, n, nil, true)
    if cfg.mode == "nameOnly" then
        f.name:ClearAllPoints()
        local cx, cy = n.anchor.x or 0, n.anchor.y or 0
        if f.azCombatName and not f.azCombatOwn then cx, cy = 0, 0 end
        f.name:SetPoint("CENTER", f, "CENTER", NP.PxSnap(f, cx), NP.PxSnap(f, cy))
        f.name:SetJustifyH("CENTER"); f.name:SetWidth(0); f.azNameWidth = 0
    else
        NP.SetAnchor(f.name, n.anchor, f.health)
        f.azNamePlace = nil
        local w = n.maxWidth or 0
        if w <= 0 and (n.anchor.side == 10 or n.anchor.side == 11) then
            w = cfg.healthWidth - (cfg.healthText.enabled and 34 or 6)
        end
        f.name:SetWidth(w > 0 and w or 0); f.azNameWidth = w > 0 and w or 0
    end
    f.name:SetWordWrap(n.wrap and true or false)
    f.name:SetShown(n.enabled)

    if FillOn(f) then
        local p = FillParts(f)
        PlaceFill(f, p)
        p.bar:SetFrameLevel(tf:GetFrameLevel()); p.mask:SetFrameLevel(tf:GetFrameLevel() + 1)
        p.heal:SetFrameLevel(tf:GetFrameLevel()); p.hmask:SetFrameLevel(tf:GetFrameLevel() + 1)
        NP.StyleText(p.text, n, nil, true); p.text:SetJustifyH(f.name:GetJustifyH()); p.text:SetWordWrap(n.wrap and true or false)
        NP.StyleText(p.htext, n, nil, true); p.htext:SetJustifyH(f.name:GetJustifyH()); p.htext:SetWordWrap(n.wrap and true or false)
        for _, fs in ipairs({ p.text, p.htext }) do
            fs:ClearAllPoints()
            if (f.azNameWidth or 0) <= 0 then
                local j = f.name:GetJustifyH()
                local pt = (j == "LEFT" and "LEFT") or (j == "RIGHT" and "RIGHT") or "CENTER"
                fs:SetPoint(pt, f.name, pt, 0, 0); fs:SetWidth(0)
            else
                fs:SetAllPoints(f.name)
            end
        end
    else
        HideFill(f)
    end

    local gc = cfg.guild or {}
    NP.StyleText(f.rpTitle, gc, nil, true)
    f.rpTitle:ClearAllPoints()
    local ga = gc.anchor or { side = 8, x = 0, y = 2 }
    if cfg.mode == "nameOnly" then
        f.rpTitle:SetPoint("TOP", f.name, "BOTTOM", ga.x or 0, (ga.y or 0) - 1); f.rpTitle:SetJustifyH("CENTER")
    else
        NP.SetAnchor(f.rpTitle, ga, f.health)
    end
    f.rpTitle:SetWidth((gc.maxWidth or 0) > 0 and gc.maxWidth or 0)
    if NP.RP then NP.RP.Sync() end

    local h = cfg.healthText
    NP.StyleText(f.healthText, h)
    NP.SetAnchor(f.healthText, h.anchor, f.health)
    f.healthText:SetShown(h.enabled and cfg.mode ~= "nameOnly")

    local l = cfg.level
    NP.StyleText(f.levelText, l)
    local onName = NP.LevelOnName(f)
    local showLevel = l.enabled and (cfg.mode ~= "nameOnly" or onName)
    local box = f.levelBox
    local azOn = showLevel and IsAzBadgeStyle(f)
    if azOn and f.azBadge then
        box:Hide()
        local st = NP.Prof(f).style
        local bu = max(0.68, min(1.35, (cfg.healthWidth or 114) / 155))
        local badge = f.azBadge
        badge:SetFrameLevel(f.health:GetFrameLevel() + 3)
        badge:SetSize(64 * bu, 32 * bu)
        badge:ClearAllPoints()
        badge:SetPoint("TOP", f.health, "BOTTOM", 0, 0)
        badge.tex:SetTexture(TARGET_MEDIA .. (st.barStyle == "azaath" and "Badge.tga" or "InkBadge.tga"))
        if f.health.lastColor then
            local r, g, b = f.health.lastColor[1] or 0.85, f.health.lastColor[2] or 0.2, f.health.lastColor[3] or 0.18
            badge.tex:SetVertexColor(min(1, r * 1.24), min(1, g * 1.55), min(1, b * 1.55), 1)
        end
        badge.wings:SetSize(144 * bu, 36 * bu)
        badge.skull:SetSize(13 * bu, 13 * bu)
        badge.skull:ClearAllPoints()
        badge.skull:SetPoint("CENTER", badge, "TOP", 0, -9 * bu)
        NP.StyleText(f.levelText, { font = "PT Sans Bold", size = floor(12 * bu + 0.5), outline = "NONE", shadow = false, color = { 0.09, 0.03, 0.03, 1 } }, { 0.09, 0.03, 0.03, 1 }, false)
        f.levelText:ClearAllPoints()
        f.levelText:SetPoint("CENTER", badge, "TOP", 0, -9 * bu)
        f.levelText:SetWidth(0)
        f.levelText:SetJustifyH("CENTER")
        badge:Show()
    elseif showLevel then
        if f.azBadge then f.azBadge:Hide() end
        local an = onName and (l.nameAnchor or { side = 2, x = -2, y = 0 }) or l.anchor
        NP.SetAnchor(f.levelText, an, onName and f.name or f.health)
        local slot = NP.LevelSlotWidth(l)
        if slot and slot > 0 then
            f.levelText:SetWidth(slot)
            local side = (an and an.side) or (onName and 2 or 9)
            local j = (side == 2 or side == 11) and "RIGHT" or ((side == 4 or side == 8 or side == 9 or side == 12 or side == 13) and "CENTER" or "LEFT")
            if l.box then j = "CENTER" end
            f.levelText:SetJustifyH(j); f.levelText:SetWordWrap(false)
        end
        if l.box then
            local bh = tonumber(l.boxHeight) or 0
            if bh <= 0 then bh = onName and max(12, floor((tonumber(l.size) or 12) + 4)) or (tonumber(cfg.healthHeight) or 14) end
            box:SetSize(l.boxWidth or 22, bh)
            box:ClearAllPoints()
            box:SetPoint("CENTER", f.levelText, "CENTER", tonumber(l.boxX) or 0, tonumber(l.boxY) or 0)
            box:SetFrameLevel(max(0, tf:GetFrameLevel() - 1))
            local st = NP.Prof(f).style
            local own = l.boxColors == "own"
            local bgc = own and l.boxBgColor or st.healthBgColor
            local bdc = own and l.boxBorderColor or st.borderColor
            local bsz = own and (tonumber(l.boxBorderSize) or 1) or (tonumber(st.borderSize) or 1)
            local shape = BOX_SHAPES[l.boxShape or "square"] and l.boxShape or "square"
            local r, g, b, a = NP.RGBA(bgc)
            if shape == "square" then
                box.shapeBorder:Hide(); box.shapeFill:Hide()
                local k = own and 0 or max(0, min(1, tonumber(st.healthBgTextureAlpha) or 1))
                box.bg:SetTexture(NP.GetStatusBarTexture(st.healthBgTexture))
                box.bg:SetVertexColor(r, g, b, a * k); box.bg:SetShown(k > 0)
                box.bgFlat:SetVertexColor(r, g, b, a * (1 - k)); box.bgFlat:SetShown(k < 1)
                box.border:SetBorderStyle(own and "pixel" or st.borderStyle)
                box.border:SetBorderSize(bsz); box.border:SetBorderColor(NP.RGBA(bdc))
            else
                box.bg:Hide(); box.bgFlat:Hide()
                box.border:SetBorderStyle("pixel"); box.border:SetBorderSize(0)
                if shape == "circle" then box:SetWidth(bh) end
                local tex = BOX_SHAPES[shape]
                for _, t in ipairs({ box.shapeBorder, box.shapeFill }) do
                    t:SetTexture(tex)
                    if t.SetTextureSliceMargins then
                        if shape == "rounded" or shape == "bevel" then t:SetTextureSliceMargins(8, 8, 8, 8)
                        else t:SetTextureSliceMargins(0, 0, 0, 0) end
                    end
                end
                box.shapeBorder:SetVertexColor(NP.RGBA(bdc)); box.shapeBorder:SetShown(bsz > 0)
                box.shapeFill:ClearAllPoints()
                box.shapeFill:SetPoint("TOPLEFT", box, "TOPLEFT", bsz, -bsz)
                box.shapeFill:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", -bsz, bsz)
                box.shapeFill:SetVertexColor(r, g, b, a); box.shapeFill:Show()
            end
            box.azShape = shape
            box:Show()
        else
            box:Hide()
        end
    else
        box:Hide()
        if f.azBadge then f.azBadge:Hide() end
    end
    f.levelText:SetShown(showLevel)
end

function Text:Update(f)
    NP.UpdateNameText(f)
    FormatHealth(f)
    UpdateFillValue(f, false)
    UpdateLevel(f)
end

function Text:OnHealth(f)
    FormatHealth(f)
    UpdateFillValue(f, true)
end
function Text:OnName(f) NP.UpdateNameText(f) end
function Text:OnLevel(f) UpdateLevel(f) end
function Text:OnThreat(f) NP.UpdateNameText(f) end
function Text:OnTargetChanged(f) NP.UpdateNameText(f) end
function Text:Clear(f)
    f.rpTitle:Hide(); f.levelBox:Hide(); if f.azBadge then f.azBadge:Hide() end; HideFill(f)
end

Text.unitEvents = {
    UNIT_HEALTH                  = "OnHealth",
    UNIT_MAXHEALTH               = "OnHealth",
    UNIT_HEAL_PREDICTION         = "OnHealth",
    UNIT_NAME_UPDATE             = "OnName",
    UNIT_LEVEL                   = "OnLevel",
    UNIT_THREAT_LIST_UPDATE      = "OnThreat",
    UNIT_THREAT_SITUATION_UPDATE = "OnThreat",
    UNIT_TARGET                  = "OnThreat",
}

function Text:Preview(f, st)
    local cfg = f.cfg
    local n = cfg.name
    if n.enabled then
        local sample = f.kind == "enemynpc" and (st.boss and "Chefe de Masmorra" or "Guardião Sombrio")
            or f.kind == "enemyplayer" and "Arthas"
            or f.kind == "friendlyplayer" and "Jaina"
            or "Ferreiro Aldric"
        if n.tracked and Azaath.Tracked then sample = Azaath.Tracked(sample) end
        f.name:SetText(sample)
        local bs = NP.Prof(f).style.barStyle or "modern"
        local th = NP.Prof(f).colors and NP.Prof(f).colors.threat
        local col
        if st.aggro and th and th.enabled and th.showOn == "name" and f.kind == "enemynpc" then
            col = (th.role == "tank" and th.tank and th.tank.noaggro) or (th.dps and th.dps.aggro)
        elseif st.target and bs ~= "modern" then
            col = { 1, 0.84, 0.43, 1 }
        else
            col = (n.useClassColor and (f.kind == "enemyplayer" or f.kind == "friendlyplayer")) and (NP.CLASS_COLORS.MAGE or n.color) or n.color
        end
        SetNameColor(f, NP.RGBA(col))
        f.name:Show()
        if cfg.guild and cfg.guild.enabled then
            SetSub(f.rpTitle, f.kind:find("npc") and "Reparos e Armaduras" or "Ordem de Azaath")
            f.rpTitle:SetTextColor(NP.RGBA(cfg.guild.color))
            f.rpTitle:Show()
        else
            f.rpTitle:Hide()
        end
        PlaceName(f, cfg.guild and cfg.guild.enabled)
        SyncFill(f)
        if FillOn(f) and f.nameFill then
            f.nameFill.bar:SetMinMaxValues(0, 100)
            f.nameFill.bar:SetValue(st.execute and 18 or 72)
        end
    else
        f.rpTitle:Hide(); HideFill(f)
    end

    if cfg.healthText.enabled and cfg.mode ~= "nameOnly" then
        local pct = st.execute and 18 or 72
        if cfg.healthText.showPercent and cfg.healthText.showValue then
            f.healthText:SetText(cfg.healthText.decimals and format("14.2k (%.1f%%)", pct) or format("14.2k (%d%%)", pct))
        elseif cfg.healthText.showPercent then
            f.healthText:SetText(cfg.healthText.decimals and format("%.1f%%", pct) or format("%d%%", pct))
        elseif cfg.healthText.showValue then
            f.healthText:SetText(cfg.healthText.fullNumbers and "14200" or "14.2k")
        else
            f.healthText:SetText("")
        end
    end

    if cfg.level.enabled and (cfg.mode ~= "nameOnly" or NP.LevelOnName(f)) then
        if IsAzBadgeStyle(f) and f.azBadge then
            UpdateAzBadgeWings(f, (st.boss or (cfg.eliteIcon and cfg.eliteIcon.enabled)) and "EliteGold" or nil)
            if st.boss then
                f.levelText:SetText("")
                f.azBadge.skull:Show()
            else
                f.azBadge.skull:Hide()
                f.levelText:SetText("80")
                f.levelText:SetTextColor(0.09, 0.03, 0.03, 1)
                f.levelText:Show()
            end
        else
            f.levelText:SetText(st.boss and "??" or "80")
            f.levelText:SetTextColor(NP.RGBA(st.boss and { 1, 0.2, 0.2, 1 } or cfg.level.color))
        end
    end
end

NP.RegisterElement("Text", Text)
