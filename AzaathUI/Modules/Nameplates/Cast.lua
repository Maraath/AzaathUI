--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Cast.lua
    Barra de conjuração completa: Kick + Tick (pronto/CD + marcador na barra),
    casts importantes, alerta "ON YOU!", spark, alvo/quem interrompeu,
    LastSpell (última magia) e CastWatch (mostra barra ao conjurar).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, tonumber, type = pairs, ipairs, pcall, tonumber, type
local max, GetTime = math.max, _G.GetTime

local UnitCastingInfo     = _G.UnitCastingInfo
local UnitChannelInfo     = _G.UnitChannelInfo
local UnitCastingDuration = _G.UnitCastingDuration
local UnitChannelDuration = _G.UnitChannelDuration
local EvalBool            = NP.EvalBool
local Interp              = _G.Enum and _G.Enum.StatusBarInterpolation
local TimerDir            = _G.Enum and _G.Enum.StatusBarTimerDirection

local INTERRUPTS = {
    [1]  = { 6552, 6554, 72, 1671, 1672 },
    [2]  = { 96231 },
    [3]  = { 187707, 147362 },
    [4]  = { 1766, 1767, 1768, 1769, 38768 },
    [5]  = { 15487 },
    [6]  = { 47528 },
    [7]  = { 57994, 8042, 8044, 8045, 8046, 10412, 10413, 10414 },
    [8]  = { 2139 },
    [9]  = { 89766, 119914, 19647, 19244, 119910, 132409 },
    [10] = { 116705 },
    [11] = { 78675, 106839 },
    [12] = { 183752 },
    [13] = { 351338 },
}
local PET_INTERRUPTS = { [89766] = true, [119914] = true, [19647] = true, [19244] = true, [119910] = true }

local function IsKnown(id)
    local SB = _G.C_SpellBook
    if PET_INTERRUPTS[id] and SB and SB.IsSpellKnown and _G.Enum and _G.Enum.SpellBookSpellBank then
        local ok, k = pcall(SB.IsSpellKnown, id, _G.Enum.SpellBookSpellBank.Pet)
        if ok and NP.Truthy(k, false) then return true end
    end
    if SB and SB.IsSpellKnownOrInSpellBook then
        local ok, k = pcall(SB.IsSpellKnownOrInSpellBook, id)
        if ok and NP.Truthy(k, false) then return true end
    end
    if SB and SB.IsSpellKnown then
        local ok, k = pcall(SB.IsSpellKnown, id)
        if ok and NP.Truthy(k, false) then return true end
    end
    if _G.IsPlayerSpell then
        local ok, k = pcall(_G.IsPlayerSpell, id)
        if ok and NP.Truthy(k, false) then return true end
    end
    return false
end
NP.IsSpellKnownNP = IsKnown

local cachedInterrupt, interruptDirty = nil, true
function NP.GetInterruptSpell()
    local custom = NP.db and NP.db.cast and NP.db.cast.kick and NP.db.cast.kick.customSpellID
    if custom and custom > 0 then return custom end
    if not interruptDirty then return cachedInterrupt end
    interruptDirty = false
    cachedInterrupt = nil
    local _, _, classID = _G.UnitClass("player")
    for _, id in ipairs(INTERRUPTS[classID] or {}) do
        if IsKnown(id) then cachedInterrupt = id; break end
    end
    return cachedInterrupt
end

local spellWatcher = _G.CreateFrame("Frame")
Azaath.SafeRegister(spellWatcher, "SPELLS_CHANGED")
Azaath.SafeRegister(spellWatcher, "PLAYER_ENTERING_WORLD")
spellWatcher:RegisterUnitEvent("UNIT_PET", "player")
spellWatcher:SetScript("OnEvent", function() interruptDirty = true end)

local function Pick(cond, ca, cb)
    local r1, g1, b1, a1 = NP.RGBA(ca)
    local r2, g2, b2, a2 = NP.RGBA(cb)
    return EvalBool(cond, r1, r2), EvalBool(cond, g1, g2), EvalBool(cond, b1, b2), EvalBool(cond, a1, a2)
end

local function KickModes(k)
    local m = k.mode
    if m == nil then m = (k.fullBarMode and not k.borderMode) and "bar" or "border" end
    return m ~= "bar", m ~= "border"
end

NP.SPARK_STYLES = { soft = "Brilho suave", line = "Linha fina", blizzard = "Blizzard" }
NP.SPARK_ORDER  = { "soft", "line", "blizzard" }

local function StyleSpark(t, bar, s, barHeight)
    t:ClearAllPoints()
    local st = s.style or "soft"
    if st == "blizzard" and t.SetAtlas and pcall(t.SetAtlas, t, "ui-castingbar-pip", false) and t:GetAtlas() then
        t:SetBlendMode("BLEND")
    elseif st == "line" then
        t:SetTexture("Interface\\Buttons\\WHITE8x8"); t:SetBlendMode("BLEND")
    else
        t:SetTexture(NP.MEDIA .. "spark.png"); t:SetBlendMode("ADD")
    end
    local h = barHeight * (s.height or 2.0)
    local w = (st == "line") and max(1, (s.width or 9) / 4) or (s.width or 9)
    t:SetSize(w, h)
    t:SetPoint("CENTER", bar:GetStatusBarTexture(), "RIGHT", s.offsetX or 0, 0)
    local r, g, b, a = NP.RGBA(s.color)
    t:SetVertexColor(r, g, b, a * (s.alpha or 1))
end

NP.ONYOU_TEXTS = { onyou = "EM VOCÊ!", onyou2 = "EM VOCÊ", you = ">> VOCÊ <<", targeting = "MIRANDO VOCÊ" }
NP.ONYOU_ORDER = { "onyou", "onyou2", "you", "targeting" }

local function OnYouValue(unit)
    if _G.PlayerIsSpellTarget then return _G.PlayerIsSpellTarget(unit) end
    if _G.UnitIsUnit then return _G.UnitIsUnit(unit .. "target", "player") end
end

local function HideOnYou(cb)
    local oy = cb.onYou
    if oy.live then
        oy.live = false; oy.pulse:Stop()
        if oy.glowAnim then oy.glowAnim:Stop() end
        oy.fx:Hide(); oy:SetAlpha(0); oy:Hide()
    end
    if cb.targetDimmed then cb.targetDimmed = false; cb.target:SetAlpha(1) end
end

local function ShowOnYouParts(f, cb)
    local oy, oc = cb.onYou, f.cfg.castOnYou
    if oy.live then return end
    oy.live = true; oy:Show()
    if oy.glowOn then oy.fx:Show() else oy.fx:Hide() end
    if oy.glowPulse and oy.glowAnim then oy.glowAnim:Play() end
    oy.text:Show()
    if oc.pulse then oy.pulse:Play() else oy.pulse:Stop() end
end

local function UpdateOnYou(f)
    local cb = f.cast
    if not cb.onYouOn or cb.ended or not f.hostile or not f.unit then HideOnYou(cb); return end
    local v = OnYouValue(f.unit)
    if type(v) == "nil" then HideOnYou(cb); return end
    ShowOnYouParts(f, cb)
    cb.onYou:SetAlpha(EvalBool(v, 1, 0))
    if f.cfg.castOnYou.replaceTarget and not cb.showingInterrupter then
        cb.targetDimmed = true
        cb.target:SetAlpha(EvalBool(v, 0, 1))
    elseif cb.targetDimmed then
        cb.targetDimmed = false
        cb.target:SetAlpha(1)
    end
end

local function HideKickTint(f)
    local t = f.health and f.health.kickTint
    if t and t.live then t.live = false; t:Hide() end
end

local function UpdateKickTint(f, k, cdInfo, ni)
    local t = f.health and f.health.kickTint
    if not t then return end
    if not (k.healthBar and cdInfo and cdInfo.IsZero) then HideKickTint(f); return end
    local aInt = (type(ni) ~= "nil") and EvalBool(ni, 0, 1) or 1
    t:SetVertexColor(NP.RGBA(k.readyColor))
    t:SetAlpha(EvalBool(cdInfo:IsZero(), aInt, 0))
    if not t.live then t.live = true; t:Show() end
end

local kickTime, kickID, kickCD
function NP.GetKickCooldown(id)
    local CS = _G.C_Spell
    if not id or not (CS and CS.GetSpellCooldownDuration) then return nil end
    local now = GetTime()
    if now ~= kickTime or id ~= kickID then
        kickTime, kickID = now, id
        local ok, d = pcall(CS.GetSpellCooldownDuration, id)
        kickCD = ok and d or nil
    end
    return kickCD
end

local Cast = {}
local activeBars = {}
local castDriver = _G.CreateFrame("Frame"); castDriver:Hide()
local tickAcc, frameWork = 0, false

local function SetCastingState(f, casting)
    if f.isCasting ~= casting then
        f.isCasting = casting
        if NP.UpdateAlpha then NP.UpdateAlpha(f) end
        if NP.OnCastStateChanged then NP.OnCastStateChanged(f) end
    end
end

local function ApplyBarColor(f)
    local cb, c = f.cast, NP.Prof(f).cast
    local base = cb.channeling and c.colors.channel or c.colors.cast
    local r, g, b, a = NP.RGBA(base)
    if c.useImportantColor and type(cb.isImportant) ~= "nil" then
        local ir, ig, ib, ia = NP.RGBA(c.colors.important)
        r, g, b, a = EvalBool(cb.isImportant, ir, r), EvalBool(cb.isImportant, ig, g), EvalBool(cb.isImportant, ib, b), EvalBool(cb.isImportant, ia, a)
    end
    if type(cb.notInterruptible) ~= "nil" then
        local nr, ng, nb, na = NP.RGBA(c.colors.nointerrupt)
        r, g, b, a = EvalBool(cb.notInterruptible, nr, r), EvalBool(cb.notInterruptible, ng, g), EvalBool(cb.notInterruptible, nb, b), EvalBool(cb.notInterruptible, na, a)
    end
    cb:SetStatusBarColor(r, g, b, a)
    if cb.fillEdge then cb.fillEdge:SetVertexColor(r, g, b, a) end
end

local function UpdateKick(f)
    local cb = f.cast
    local k = NP.Prof(f).cast.kick
    if not k.enabled or not f.hostile or cb.ended then
        cb.marker:Hide(); cb.kickFrame:Hide(); HideKickTint(f); return
    end
    local borderMode, barMode = KickModes(k)
    local cdInfo = NP.GetKickCooldown(NP.GetInterruptSpell())
    local ni = cb.notInterruptible
    UpdateKickTint(f, k, cdInfo, ni)

    local cdOn = k.cooldownColorEnabled ~= false
    local cdColor = cdOn and k.cooldownColor or k.baseBorderColor
    local r, g, b, a
    if cdInfo and cdInfo.IsZero then
        r, g, b, a = Pick(cdInfo:IsZero(), k.readyColor, cdColor)
    else
        r, g, b, a = NP.RGBA(cdColor)
    end
    if type(ni) ~= "nil" then
        local nr, ng, nb, na = NP.RGBA(k.noInterruptColor)
        r, g, b, a = EvalBool(ni, nr, r), EvalBool(ni, ng, g), EvalBool(ni, nb, b), EvalBool(ni, na, a)
    end
    if borderMode then cb.border:SetBorderColor(r, g, b, a) end
    if barMode and cdInfo and cdInfo.IsZero then
        local aInt = (type(ni) ~= "nil") and EvalBool(ni, 0, 1) or 1
        if cdOn then
            cb.kickFrame:GetStatusBarTexture():SetVertexColor(Pick(cdInfo:IsZero(), k.readyColor, k.cooldownColor))
            if type(ni) ~= "nil" and cb.kickFrame.SetAlphaFromBoolean then cb.kickFrame:SetAlphaFromBoolean(ni, 0, 1) else cb.kickFrame:SetAlpha(1) end
        else
            cb.kickFrame:GetStatusBarTexture():SetVertexColor(NP.RGBA(k.readyColor))
            if cb.kickFrame.SetAlphaFromBoolean then cb.kickFrame:SetAlphaFromBoolean(cdInfo:IsZero(), aInt, 0) end
        end
        cb.kickFrame:Show()
    else
        cb.kickFrame:Hide()
    end

    local d = cb.duration
    if k.tick.enabled and d and cdInfo and cdInfo.GetEndTime and cdInfo.IsZero and cb.marker.SetAlphaFromBoolean then
        local aInt = (type(ni) ~= "nil") and EvalBool(ni, 0, 1) or 1
        cb.marker:SetAlphaFromBoolean(cdInfo:IsZero(), 0, aInt)
        cb.marker:SetMinMaxValues(d:GetStartTime(), d:GetEndTime())
        cb.marker:SetValue(cdInfo:GetEndTime())
        if cb.channeling ~= cb.marker.channelMode then
            cb.marker.channelMode = cb.channeling
            cb.marker:SetReverseFill(cb.channeling and true or false)
            cb.marker.tick:ClearAllPoints()
            if cb.channeling then cb.marker.tick:SetPoint("RIGHT", cb.marker:GetStatusBarTexture(), "LEFT")
            else cb.marker.tick:SetPoint("LEFT", cb.marker:GetStatusBarTexture(), "RIGHT") end
            cb.marker.tick:SetPoint("TOP", cb.marker, "TOP"); cb.marker.tick:SetPoint("BOTTOM", cb.marker, "BOTTOM")
        end
        cb.marker:Show()
    else
        cb.marker:Hide()
    end
end

function Cast:Create(f)
    local cb = _G.CreateFrame("StatusBar", nil, f)
    cb:SetMinMaxValues(0, 1); cb:SetValue(0); cb:Hide()
    f.cast = cb
    cb.bg = cb:CreateTexture(nil, "BACKGROUND"); cb.bg:SetAllPoints()
    cb.icon = cb:CreateTexture(nil, "OVERLAY"); cb.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    cb.iconBorder = NP.CreateBorder(cb, "OVERLAY", 7); cb.iconBorder.owner = cb.icon
    cb.borderFrame = _G.CreateFrame("Frame", nil, cb); cb.borderFrame:SetAllPoints()
    cb.border = NP.CreateBorder(cb.borderFrame, "OVERLAY", 7); cb.border.owner = cb
    cb.spark = cb:CreateTexture(nil, "OVERLAY", nil, 2)

    local kb = _G.CreateFrame("StatusBar", nil, cb)
    kb:SetAllPoints(cb); kb:SetMinMaxValues(0, 1); kb.spark = kb:CreateTexture(nil, "OVERLAY", nil, 2); kb:Hide()
    cb.kickFrame = kb

    cb.marker = _G.CreateFrame("StatusBar", nil, cb)
    cb.marker:SetAllPoints(cb); cb.marker:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    cb.marker:SetStatusBarColor(1, 0, 1, 0); cb.marker:SetClipsChildren(true)
    cb.marker.tick = cb.marker:CreateTexture(nil, "OVERLAY"); cb.marker:Hide()

    cb.important = _G.CreateFrame("Frame", nil, cb); cb.important:SetAllPoints(cb)
    cb.importantFx = NP.CreateHighlight(cb.important, cb, 1); cb.important:SetAlpha(0)

    local oy = _G.CreateFrame("Frame", nil, cb); oy:SetAllPoints(cb)
    oy.fx = NP.CreateHighlight(oy, cb, 1)
    oy.textFrame = _G.CreateFrame("Frame", nil, oy); oy.textFrame:SetAllPoints(cb)
    oy.text = oy.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); oy.text:SetWordWrap(false)
    oy.pulse = oy.textFrame:CreateAnimationGroup(); oy.pulse:SetLooping("BOUNCE")
    local pa = oy.pulse:CreateAnimation("Alpha"); pa:SetFromAlpha(1); pa:SetToAlpha(0.35); pa:SetDuration(0.45)
    oy:SetAlpha(0); oy:Hide(); cb.onYou = oy

    cb.textFrame = _G.CreateFrame("Frame", nil, cb); cb.textFrame:SetAllPoints()
    cb.spellName = cb.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); cb.spellName:SetWordWrap(false)
    cb.timer = cb.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cb.target = cb.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); cb.target:SetWordWrap(false)

    cb.owner = f
    cb:HookScript("OnShow", function(self) activeBars[self] = true; if self.ended or self.previewAnim then frameWork = true end; castDriver:Show() end)
    cb:HookScript("OnHide", function(self) activeBars[self] = nil end)
end

function NP.NameOnlyCast(f)
    local cfg = f and f.cfg
    return f.kind == "friendlyplayer" and not f.profKind and cfg and cfg.mode == "nameOnly" and cfg.castOnName and true or false
end

function Cast:Layout(f)
    local db = NP.Prof(f)
    local cfg, c = f.cfg, db.cast
    local cb = f.cast
    local nameCast = NP.NameOnlyCast(f)
    cb.nameCast = nameCast
    cb.disabled = not c.enabled or (cfg.mode == "nameOnly" and not nameCast)
        or (not nameCast and c.hideFriendly and (f.kind == "friendlyplayer" or f.kind == "friendlynpc"))
    if cb.disabled then self:Clear(f); return end

    cb:SetSize(NP.PxSnap(f, cfg.castWidth, true), NP.PxSnap(f, cfg.castHeight, true))
    local cr = db.classResources
    local base = NP.DepthLevel(f, (cr and cr.castInFront) and 16 or 4, "cast")
    cb:SetFrameLevel(base)
    cb.kickFrame:SetFrameLevel(base + 1)
    cb.borderFrame:SetFrameLevel(base + 4)
    cb.marker:SetFrameLevel(base + 5)
    cb.important:SetFrameLevel(base + 6); cb.importantFx.frame:SetFrameLevel(base + 7)
    cb.textFrame:SetFrameLevel(base + 7)
    cb.onYou:SetFrameLevel(base + 8); cb.onYou.fx.frame:SetFrameLevel(base + 8); cb.onYou.textFrame:SetFrameLevel(base + 9)

    cb:ClearAllPoints()
    if nameCast then
        local gc = cfg.guild
        local stepsAside = gc and gc.hideWhileCasting and not (f.isPreview and f.azSelected == "guild")
        local under = (gc and gc.enabled and not stepsAside) and f.rpTitle or f.name
        cb:SetPoint("TOP", under, "BOTTOM", NP.PxSnap(f, cfg.castOffsetX or 0), NP.PxSnap(f, (cfg.castOffsetY or 0) - 3))
    else
        local extraY = 0
        if (db.style.barStyle == "azaath" or db.style.barStyle == "azaath_ink") and cfg.level and cfg.level.enabled then
            local bu = max(0.68, (cfg.healthWidth or 114) / 155)
            extraY = -math.floor(19 * bu + 0.5)
        end
        cb:SetPoint("TOP", f.health, "BOTTOM", NP.PxSnap(f, cfg.castOffsetX or 0), NP.PxSnap(f, (cfg.castOffsetY or 0) - (db.style.borderSize or 0) + extraY))
    end
    cb:SetStatusBarTexture(NP.GetStatusBarTexture(c.texture))
    cb.bg:SetColorTexture(NP.RGBA(c.bgColor))
    StyleSpark(cb.spark, cb, c.spark, cfg.castHeight)

    local ic, bs = c.icon, c.borderSize or 0
    local sz = (ic.size and ic.size > 0) and ic.size or cfg.castHeight
    if ic.tall then sz = cfg.healthHeight + cfg.castHeight + (db.style.borderSize or 0) end
    cb.icon:ClearAllPoints(); cb.icon:SetSize(sz, sz)
    local gap = (ic.border and bs or 0) + 1
    local ap = ic.tall and "BOTTOM" or ""
    if ic.side == "RIGHT" then cb.icon:SetPoint(ap .. "LEFT", cb, ap .. "RIGHT", gap + (ic.offsetX or 0), ic.offsetY or 0)
    elseif ic.side == "INSIDE_LEFT" then cb.icon:SetPoint("LEFT", cb, "LEFT", ic.offsetX or 0, ic.offsetY or 0)
    elseif ic.side == "INSIDE_RIGHT" then cb.icon:SetPoint("RIGHT", cb, "RIGHT", ic.offsetX or 0, ic.offsetY or 0)
    else cb.icon:SetPoint(ap .. "RIGHT", cb, ap .. "LEFT", -gap + (ic.offsetX or 0), ic.offsetY or 0) end
    cb.icon:SetShown(c.showIcon)
    cb.iconBorder:SetBorderSize(ic.border and max(bs, 1) or 0)
    cb.iconBorder:SetBorderColor(NP.RGBA(ic.borderColor or { 0, 0, 0, 1 }))
    cb.iconBorder:SetShown(c.showIcon and ic.border and true or false)

    local k = c.kick
    local kBorder = k.enabled and (KickModes(k))
    local corner = NP.CornerRadius("cast", f)
    cb.border.corner = corner
    cb.border:SetBorderStyle(db.style.borderStyle)
    cb.border:SetBorderSize(kBorder and k.borderSize or c.borderSize)
    cb.border:SetBorderColor(NP.RGBA(kBorder and k.baseBorderColor or c.borderColor))
    NP.SetBarUnderBorder(cb, NP.UnderBorderSize(kBorder and k.borderSize or c.borderSize, corner, f), { cb.bg })
    cb.kickFrame:SetStatusBarTexture(NP.GetStatusBarTexture(c.texture))
    cb.kickFrame:GetStatusBarTexture():SetVertexColor(NP.RGBA(k.readyColor))
    StyleSpark(cb.kickFrame.spark, cb.kickFrame, c.spark, cfg.castHeight)

    cb.marker.tick:ClearAllPoints()
    cb.marker.tick:SetPoint("LEFT", cb.marker:GetStatusBarTexture(), "RIGHT")
    cb.marker.tick:SetPoint("TOP", cb.marker, "TOP"); cb.marker.tick:SetPoint("BOTTOM", cb.marker, "BOTTOM")
    cb.marker.tick:SetColorTexture(NP.RGBA(k.tick.color)); cb.marker.tick:SetWidth(k.tick.width)

    if c.importantDots.enabled and (_G.C_Spell.IsSpellImportant or f.isPreview) then cb.importantFx:Apply(c.importantDots) end

    NP.StyleText(cb.spellName, cfg.castName); NP.SetAnchor(cb.spellName, cfg.castName.anchor, cb)
    cb.spellName:SetWidth(cfg.castWidth * 0.75); cb.spellName:SetShown(cfg.castName.enabled)
    NP.StyleText(cb.timer, cfg.castTimer); NP.SetAnchor(cb.timer, cfg.castTimer.anchor, cb)
    cb.timer:SetShown(cfg.castTimer.enabled)
    NP.StyleText(cb.target, cfg.castTarget, nil, true); NP.SetAnchor(cb.target, cfg.castTarget.anchor, cb)
    cb.target:SetWidth(cfg.castWidth * 0.5); cb.target:SetShown(cfg.castTarget.enabled)

    local oc = cfg.castOnYou
    cb.onYouOn = oc and oc.enabled and (f.kind == "enemynpc" or f.kind == "enemyplayer") and true or false
    if not cb.onYouOn then HideOnYou(cb) end
    if not c.kick.healthBar then HideKickTint(f) end
    if cb.onYouOn then
        local oy = cb.onYou
        oy.glowOn = oc.glow and oc.glow.enabled and true or false
        oy.glowPulse = oy.glowOn and oc.glow.style == "pulseGlow" or false
        if oy.glowOn then
            if oy.glowPulse then
                local g = NP.CopyTable(oc.glow); g.style = "glow"; oy.fx:Apply(g)
                if not oy.glowAnim then
                    oy.glowAnim = oy.fx.frame:CreateAnimationGroup(); oy.glowAnim:SetLooping("BOUNCE")
                    oy.glowAnimA = oy.glowAnim:CreateAnimation("Alpha"); oy.glowAnimA:SetFromAlpha(1); oy.glowAnimA:SetToAlpha(0.2)
                end
                oy.glowAnimA:SetDuration(0.5 / max(0.2, tonumber(oc.glow.speed) or 1))
            else
                oy.fx:Apply(oc.glow)
            end
        end
        if oy.glowAnim and not oy.glowPulse then oy.glowAnim:Stop() end
        NP.StyleText(oy.text, oc)
        NP.SetAnchor(oy.text, oc.sameAsTarget ~= false and cfg.castTarget.anchor or oc.anchor, cb)
        oy.text:SetText(NP.ONYOU_TEXTS[oc.text] or NP.ONYOU_TEXTS.onyou)
    end
    if corner > 0 or cb.cornerMask then
        NP.ApplyCorners(cb, corner, { cb.bg, cb:GetStatusBarTexture(), cb.fillEdge, cb.spark,
            cb.kickFrame:GetStatusBarTexture(), cb.kickFrame.spark, cb.marker:GetStatusBarTexture(), cb.marker.tick })
    end
end

local function StartCast(f, channeling, known)
    local cb = f.cast
    if cb.disabled then return false end
    local unit, c = f.unit, NP.Prof(f).cast
    local duration = known or (channeling and (UnitChannelDuration and UnitChannelDuration(unit)) or (UnitCastingDuration and UnitCastingDuration(unit)))
    local name, texture, startMS, endMS, notInterruptible, spellID
    if channeling then
        local n, _, tex, s, e, _, ni, sid = UnitChannelInfo(unit)
        name, texture, startMS, endMS, notInterruptible, spellID = n, tex, s, e, ni, sid
    else
        local n, _, tex, s, e, _, _, ni, sid = UnitCastingInfo(unit)
        name, texture, startMS, endMS, notInterruptible, spellID = n, tex, s, e, ni, sid
    end
    if not duration and not name then return false end

    cb.channeling, cb.ended, cb.endTime, cb.duration = channeling, false, nil, duration
    cb.notInterruptible = notInterruptible
    cb.isImportant = (_G.C_Spell.IsSpellImportant and type(spellID) ~= "nil") and _G.C_Spell.IsSpellImportant(spellID) or nil
    cb:SetAlpha(1)

    if duration and cb.SetTimerDuration then
        local dir = channeling and (TimerDir and TimerDir.RemainingTime or 1) or (TimerDir and TimerDir.ElapsedTime or 0)
        local interp = Interp and Interp.Immediate or 0
        cb:SetTimerDuration(duration, interp, dir)
        cb.kickFrame:SetTimerDuration(duration, interp, dir)
        cb.startTime, cb.endTimeVal, cb.durVal = nil, nil, nil
    elseif startMS and endMS and not NP.IsSecret(startMS) and not NP.IsSecret(endMS) then
        cb.startTime, cb.endTimeVal = startMS / 1000, endMS / 1000
        cb.durVal = max(cb.endTimeVal - cb.startTime, 0.001)
        cb:SetMinMaxValues(0, cb.durVal); cb:SetValue(channeling and cb.durVal or 0)
        cb.kickFrame:SetMinMaxValues(0, cb.durVal); cb.kickFrame:SetValue(channeling and cb.durVal or 0)
    else
        cb:SetMinMaxValues(0, 1); cb:SetValue(0.5)
    end

    cb.kickFrame.spark:SetShown(c.spark.enabled); cb.spark:SetShown(c.spark.enabled)
    ApplyBarColor(f)
    cb.spellName:SetText(name or "")
    if c.showIcon then cb.icon:SetTexture(texture or "Interface\\Icons\\INV_Misc_QuestionMark") end

    if cb.showingInterrupter then
        cb.showingInterrupter = false
        cb.target:SetShown(f.cfg.castTarget.enabled)
        if not f.cfg.castTarget.enabled then cb.target:SetText("") end
    end
    if f.cfg.castTarget.enabled and _G.UnitSpellTargetName then
        cb.target:SetText((_G.UnitSpellTargetName(unit)))
        local color
        if f.cfg.castTarget.useClassColor and _G.UnitSpellTargetClass then
            local cls = _G.UnitSpellTargetClass(unit)
            if NP.IsSecret(cls) or (type(cls) == "string" and cls ~= "") then color = NP.ClassColorObj(cls) end
        end
        if type(color) == "table" and color.GetRGB then cb.target:SetTextColor(color:GetRGB())
        else cb.target:SetTextColor(NP.RGBA(f.cfg.castTarget.color)) end
    end

    if c.importantDots.enabled and type(cb.isImportant) ~= "nil" and cb.important.SetAlphaFromBoolean then
        cb.important:SetAlphaFromBoolean(cb.isImportant, 1, 0); cb.importantFx:Show()
    else
        cb.important:SetAlpha(0); cb.importantFx:Hide()
    end

    if NP.db.colors.caster.detectByCast and f.kind == "enemynpc" and not f.isCaster then
        f.isCaster = true; NP.UpdateHealthColor(f)
    end

    local k = c.kick
    if not (k.enabled and f.hostile and (KickModes(k))) then
        cb.border:SetBorderColor(NP.RGBA((k.enabled and (KickModes(k))) and k.baseBorderColor or c.borderColor))
    end
    UpdateKick(f); UpdateOnYou(f)
    if f.cfg.castTimer.enabled and cb.duration and cb.duration.GetRemainingDuration then
        cb.timer:SetFormattedText("%.1f", cb.duration:GetRemainingDuration())
    end
    cb:Show()
    SetCastingState(f, true)
    if NP.Prof(f).extras.castHighlight.importantOnly and NP.UpdateAlpha then NP.UpdateAlpha(f) end
    return true
end

local function EndCast(f, state)
    local cb = f.cast
    if not cb:IsShown() or cb.disabled then return end
    local c = NP.Prof(f).cast
    if state == "interrupted" or state == "failed" then
        cb.ended = "interrupted"
        cb:SetStatusBarColor(NP.RGBA(c.colors.interrupted))
        if cb.fillEdge then cb.fillEdge:SetVertexColor(NP.RGBA(c.colors.interrupted)) end
        cb:SetMinMaxValues(0, 1); cb:SetValue(1)
        cb.spellName:SetText(state == "interrupted" and (_G.INTERRUPTED or "Interrompido") or (_G.FAILED or "Falhou"))
        cb.endTime = GetTime() + (c.interruptedHold or 0.4)
    elseif not cb.ended then
        cb.ended = "finished"
        cb:SetMinMaxValues(0, 1); cb:SetValue(1)
        cb.endTime = GetTime()
    end
    cb.spark:Hide(); cb.marker:Hide(); cb.kickFrame:Hide(); cb.timer:SetText("")
    cb.important:SetAlpha(0); cb.importantFx:Hide()
    HideOnYou(cb); HideKickTint(f)
    local k = c.kick
    cb.border:SetBorderColor(NP.RGBA((k.enabled and (KickModes(k))) and k.baseBorderColor or c.borderColor))
    frameWork = true
    SetCastingState(f, false)
end

local function OnTick(cb)
    local f = cb.owner
    if f.isPreview or cb.ended then return end
    cb.checkTicks = (cb.checkTicks or 0) + 1
    if cb.checkTicks >= 3 or cb.missedTicks then
        cb.checkTicks = 0
        local alive = f.unit and ((UnitCastingDuration and type((UnitCastingDuration(f.unit))) ~= "nil")
            or (UnitChannelDuration and type((UnitChannelDuration(f.unit))) ~= "nil")
            or UnitCastingInfo(f.unit) ~= nil or UnitChannelInfo(f.unit) ~= nil)
        if not alive then
            cb.missedTicks = (cb.missedTicks or 0) + 1
            if cb.missedTicks >= 2 then cb.missedTicks = nil; EndCast(f, "finished"); return end
        else
            cb.missedTicks = nil
        end
    end
    if f.cfg.castTimer.enabled then
        if cb.duration and cb.duration.GetRemainingDuration then
            cb.timer:SetFormattedText("%.1f", cb.duration:GetRemainingDuration())
        elseif cb.endTimeVal then
            local rem = max(0, cb.endTimeVal - GetTime())
            local val = cb.channeling and rem or max(0, cb.durVal - rem)
            cb:SetValue(val); cb.kickFrame:SetValue(val)
            cb.timer:SetFormattedText("%.1f", rem)
        end
    end
    UpdateKick(f); UpdateOnYou(f)
end

castDriver:SetScript("OnUpdate", NP.Perf.Wrap("cast bars", function(self, elapsed)
    tickAcc = tickAcc + elapsed
    local tick = tickAcc >= 0.1
    if not tick and not frameWork then return end
    if tick then tickAcc = 0 end
    frameWork = false
    local any = false
    for cb in pairs(activeBars) do
        any = true
        local f = cb.owner
        if cb.previewAnim then
            frameWork = true
            cb.previewT = ((cb.previewT or 0) + elapsed) % 3.0
            local p = math.min(cb.previewT / 2.5, 1)
            cb:SetValue(cb.channeling and (1 - p) or p)
            cb.kickFrame:SetValue(cb.channeling and (1 - p) or p)
            if f.cfg.castTimer.enabled then cb.timer:SetFormattedText("%.1f", max(2.5 - cb.previewT, 0)) end
        elseif cb.ended then
            frameWork = true
            if cb:IsVisible() then
                local t = GetTime() - (cb.endTime or 0)
                local fade = NP.Prof(f).cast.fadeOutTime or 0.3
                if t >= fade then cb:Hide(); cb.ended = false
                elseif t >= 0 then cb:SetAlpha(1 - t / fade) end
            end
        elseif tick and cb:IsVisible() then
            OnTick(cb)
        end
    end
    if not any then self:Hide() end
end))

function Cast:Update(f)
    f.hostile = NP.Truthy(_G.UnitCanAttack("player", f.unit), false)
    f.cast.ended = false; f.cast:Hide()
    if f.cast.disabled then return end
    if not StartCast(f, false) then StartCast(f, true) end
end
function Cast:Clear(f)
    local cb = f.cast
    cb:Hide(); cb.ended = false; cb.duration = nil; cb.notInterruptible = nil; cb.isImportant = nil
    cb.marker:Hide(); cb.kickFrame:Hide(); cb.previewAnim = false
    cb.important:SetAlpha(0); cb.importantFx:Hide()
    HideOnYou(cb); HideKickTint(f); f.isCasting = false
end
function Cast:OnStart(f) StartCast(f, false) end
function Cast:OnChannelStart(f) StartCast(f, true) end
function Cast:OnStop(f)
    if UnitCastingDuration and type((UnitCastingDuration(f.unit))) ~= "nil" then StartCast(f, false); return end
    if UnitChannelDuration and type((UnitChannelDuration(f.unit))) ~= "nil" then StartCast(f, true); return end
    EndCast(f, "finished")
end
function Cast:OnInterrupted(f, _, _, _, _, interruptedBy)
    EndCast(f, "interrupted")
    local c, cb = NP.Prof(f).cast, f.cast
    if not c.showInterrupter or cb.ended ~= "interrupted" or not _G.UnitNameFromGUID then return end
    if not NP.IsSecret(interruptedBy) and (interruptedBy == nil or interruptedBy == "") then return end
    local ok, name = pcall(_G.UnitNameFromGUID, interruptedBy)
    if not ok or (not NP.IsSecret(name) and (name == nil or name == "")) then return end
    cb.target:SetText(name); cb.target:SetAlpha(1)
    local color
    if c.interrupterClassColor and _G.GetPlayerInfoByGUID then
        local ok2, _, cls = pcall(_G.GetPlayerInfoByGUID, interruptedBy)
        if ok2 and (NP.IsSecret(cls) or (type(cls) == "string" and cls ~= "")) then color = NP.ClassColorObj(cls) end
    end
    if not (type(color) == "table" and color.GetRGB and pcall(cb.target.SetTextColor, cb.target, color:GetRGB())) then
        cb.target:SetTextColor(NP.RGBA(f.cfg.castTarget.color))
    end
    cb.target:Show(); cb.showingInterrupter = true
end
function Cast:OnFailed(f)
    if (UnitCastingDuration and type((UnitCastingDuration(f.unit))) ~= "nil") or (UnitChannelDuration and type((UnitChannelDuration(f.unit))) ~= "nil") then return end
    EndCast(f, "failed")
end
function Cast:OnDelayed(f)
    local cb = f.cast
    if not cb:IsShown() or cb.ended then return end
    local d = cb.channeling and (UnitChannelDuration and UnitChannelDuration(f.unit)) or (UnitCastingDuration and UnitCastingDuration(f.unit))
    if d and cb.SetTimerDuration then
        cb.duration = d
        local dir = cb.channeling and (TimerDir and TimerDir.RemainingTime or 1) or (TimerDir and TimerDir.ElapsedTime or 0)
        cb:SetTimerDuration(d, Interp and Interp.Immediate or 0, dir)
        cb.kickFrame:SetTimerDuration(d, Interp and Interp.Immediate or 0, dir)
    end
end
function Cast:OnInterruptible(f, event)
    local cb = f.cast
    if not cb:IsShown() or cb.ended then return end
    cb.notInterruptible = (event == "UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
    ApplyBarColor(f); UpdateKick(f)
end
function Cast:WantsEvent(f) return not f.cast.disabled end
Cast.unitEvents = {
    UNIT_SPELLCAST_START             = "OnStart",
    UNIT_SPELLCAST_CHANNEL_START     = "OnChannelStart",
    UNIT_SPELLCAST_EMPOWER_START     = "OnChannelStart",
    UNIT_SPELLCAST_STOP              = "OnStop",
    UNIT_SPELLCAST_CHANNEL_STOP      = "OnStop",
    UNIT_SPELLCAST_EMPOWER_STOP      = "OnStop",
    UNIT_SPELLCAST_INTERRUPTED       = "OnInterrupted",
    UNIT_SPELLCAST_FAILED            = "OnFailed",
    UNIT_SPELLCAST_DELAYED           = "OnDelayed",
    UNIT_SPELLCAST_CHANNEL_UPDATE    = "OnDelayed",
    UNIT_SPELLCAST_EMPOWER_UPDATE    = "OnDelayed",
    UNIT_SPELLCAST_INTERRUPTIBLE     = "OnInterruptible",
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE = "OnInterruptible",
}

function Cast:Preview(f, st)
    local cb = f.cast
    if cb.disabled or not (st.casting or st.selected == "cast") then
        cb.previewAnim = false; HideOnYou(cb); HideKickTint(f); cb:Hide(); return
    end
    local c = NP.Prof(f).cast
    cb.ended = false; cb.duration = nil
    cb.channeling = st.channel and true or false
    cb.isImportant = st.important and true or false
    cb.notInterruptible = st.notInterruptible and true or false
    cb:SetAlpha(1); cb:SetMinMaxValues(0, 1); cb.kickFrame:SetMinMaxValues(0, 1)
    cb.kickFrame.spark:SetShown(c.spark.enabled); cb.spark:SetShown(c.spark.enabled)
    cb.previewAnim = true; frameWork = true; cb.previewT = cb.previewT or 1.5
    ApplyBarColor(f)
    cb.spellName:SetText(cb.channeling and "Drenar Vida" or "Seta de Gelo")
    cb.target:SetText(f.kind == "enemyplayer" and "Kaelen" or "Tanque")
    cb.target:SetTextColor(NP.RGBA(f.cfg.castTarget.useClassColor and (NP.CLASS_COLORS.WARRIOR or f.cfg.castTarget.color) or f.cfg.castTarget.color))
    cb.icon:SetTexture(cb.channeling and "Interface\\Icons\\Spell_Shadow_LifeDrain02" or "Interface\\Icons\\Spell_Frost_FrostBolt02")

    local k = c.kick
    local borderMode, barMode = KickModes(k)
    local base = k.enabled and borderMode and k.baseBorderColor or c.borderColor
    cb.kickFrame:Hide()
    if k.enabled then
        local cdOn = k.cooldownColorEnabled ~= false
        local col = st.notInterruptible and k.noInterruptColor or (st.kickReady and k.readyColor or (cdOn and k.cooldownColor or k.baseBorderColor))
        cb.border:SetBorderColor(NP.RGBA(borderMode and col or base))
        if barMode and (st.kickReady or cdOn) and not st.notInterruptible then
            cb.kickFrame:GetStatusBarTexture():SetVertexColor(NP.RGBA(st.kickReady and k.readyColor or k.cooldownColor))
            cb.kickFrame:SetAlpha(1); cb.kickFrame:Show()
        end
        if k.tick.enabled and not st.kickReady and not st.notInterruptible then
            cb.marker:SetMinMaxValues(0, 1); cb.marker:SetValue(0.75); cb.marker:SetAlpha(1); cb.marker:Show()
        else cb.marker:Hide() end
    else
        cb.border:SetBorderColor(NP.RGBA(base)); cb.marker:Hide()
    end

    if c.importantDots.enabled and st.important then cb.important:SetAlpha(1); cb.importantFx:Show()
    else cb.important:SetAlpha(0); cb.importantFx:Hide() end

    HideOnYou(cb)
    if cb.onYouOn and (st.onYou or st.selected == "castOnYou") then
        ShowOnYouParts(f, cb); cb.onYou:SetAlpha(1)
        if f.cfg.castOnYou.replaceTarget then cb.targetDimmed = true; cb.target:SetAlpha(0) end
    end
    HideKickTint(f)
    if f.health and f.health.kickTint and k.enabled and k.healthBar and st.kickReady and not st.notInterruptible then
        f.health.kickTint:SetVertexColor(NP.RGBA(k.readyColor)); f.health.kickTint:SetAlpha(1); f.health.kickTint.live = true; f.health.kickTint:Show()
    end
    cb:Show()
end

NP.RegisterElement("Cast", Cast)

-- LastSpell (ícone da última magia / GCD) + CastWatch (mostra barra ao conjurar fora de combate)
local LS = {}
local function LSCfg(f)
    local c = f.cfg and f.cfg.lastSpell
    return (c and c.enabled and (f.kind == "enemyplayer" or f.kind == "enemynpc") and f.cfg.mode ~= "nameOnly") and c or nil
end
function LS:Create(f)
    local b = _G.CreateFrame("Frame", nil, f); b:Hide()
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetAllPoints(); b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    b.cd = _G.CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate"); b.cd:SetAllPoints()
    b.cd:SetDrawEdge(false); b.cd:SetDrawBling(false); b.cd:SetHideCountdownNumbers(true); b.cd.noCooldownCount = true
    b.border = NP.CreateBorder(b, "OVERLAY", 7)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    b.label:SetPoint("TOP", b, "BOTTOM", 0, -2); b.label:SetWordWrap(false)
    f.lastSpell = b
end
function LS:Layout(f)
    local b, c = f.lastSpell, LSCfg(f)
    if not c then b:Hide(); return end
    local s = tonumber(c.size) or 24
    b:SetSize(s, s); b:SetFrameLevel(NP.DepthLevel(f, 6, "lastSpell"))
    NP.SetAnchor(b, c.anchor, f.health)
    b.border:SetBorderSize(tonumber(c.borderSize) or 1.5); b.border:SetBorderColor(NP.RGBA(c.borderColor))
    NP.StyleText(b.label, { font = "Noto Sans SemiBold", size = tonumber(c.nameSize) or 10, outline = "OUTLINE", shadow = true })
    b.label:SetTextColor(NP.RGBA(c.borderColor)); b.label:SetWidth(s + 40); b.label:SetShown(c.showName ~= false)
end
local function LSHideLater(f, delay)
    local b = f.lastSpell; b.token = (b.token or 0) + 1
    local mine, unit = b.token, f.unit
    _G.C_Timer.After(delay, function() if b.token == mine and f.unit == unit then b:Hide() end end)
end
local function LSShow(f, spellID, casting)
    local c, b = LSCfg(f), f.lastSpell
    if not c or (not NP.IsSecret(spellID) and spellID == nil) then return end
    local CS = _G.C_Spell
    local tex = CS and CS.GetSpellTexture and CS.GetSpellTexture(spellID)
    if not NP.IsSecret(tex) and tex == nil then return end
    b.icon:SetTexture(tex or "Interface\\Icons\\INV_Misc_QuestionMark")
    if c.showName ~= false and CS and CS.GetSpellName then b.label:SetText(CS.GetSpellName(spellID)) end
    local gcd = tonumber(c.gcd) or 1.5
    b.cd:SetCooldown(GetTime(), gcd); b.casting = casting or nil; b:Show()
    b.token = (b.token or 0) + 1
    if not casting then LSHideLater(f, gcd + (tonumber(c.linger) or 0.5)) end
end
function LS:OnStart(f, _, _, _, spellID) LSShow(f, spellID, true) end
function LS:OnSucceeded(f, _, _, _, spellID)
    local b = f.lastSpell
    if b.casting and b:IsShown() then
        b.casting = nil; local c = LSCfg(f); LSHideLater(f, c and (tonumber(c.linger) or 0.5) or 0); return
    end
    LSShow(f, spellID, false)
end
function LS:OnStop(f)
    if not f.lastSpell.casting then return end
    f.lastSpell.casting = nil; local c = LSCfg(f); LSHideLater(f, c and (tonumber(c.linger) or 0.5) or 0)
end
function LS:OnBroken(f)
    if not f.lastSpell.casting then return end
    f.lastSpell.casting = nil; f.lastSpell.token = (f.lastSpell.token or 0) + 1; f.lastSpell:Hide()
end
function LS:Update(f) if not LSCfg(f) then f.lastSpell:Hide() end end
function LS:Clear(f) f.lastSpell.token = (f.lastSpell.token or 0) + 1; f.lastSpell.casting = nil; f.lastSpell:Hide() end
function LS:WantsEvent(f) return LSCfg(f) ~= nil end
LS.unitEvents = {
    UNIT_SPELLCAST_SUCCEEDED = "OnSucceeded", UNIT_SPELLCAST_START = "OnStart",
    UNIT_SPELLCAST_CHANNEL_START = "OnStart", UNIT_SPELLCAST_CHANNEL_STOP = "OnStop",
    UNIT_SPELLCAST_INTERRUPTED = "OnBroken", UNIT_SPELLCAST_FAILED = "OnBroken",
}
function LS:Preview(f)
    local b = f.lastSpell
    if not LSCfg(f) then b:Hide(); return end
    LS:Layout(f)
    b.icon:SetTexture("Interface\\Icons\\Spell_Arcane_Blink"); b.label:SetText("Lampejo")
    b.cd:SetCooldown(GetTime() - 0.55, 1.5); b:Show()
end
NP.RegisterElement("LastSpell", LS)

-- CastWatch
function NP.CastFullWanted(f)
    if not f or f.isPreview or not f.unit then return false end
    local cfg = (f.kind == "enemynpc" or f.kind == "enemyplayer") and NP.db.units[f.kind]
    if not (cfg and cfg.mode == "full" and cfg.nameOnlyUntilCombat and cfg.castFullPlate) then return false end
    if cfg.castFullNotResting ~= false and _G.IsResting and _G.IsResting() then return false end
    if UnitCastingDuration and type((UnitCastingDuration(f.unit))) ~= "nil" then return true end
    if UnitChannelDuration and type((UnitChannelDuration(f.unit))) ~= "nil" then return true end
    return UnitCastingInfo(f.unit) ~= nil or UnitChannelInfo(f.unit) ~= nil
end
