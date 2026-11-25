--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Execute.lua
    Indicador de faixa de Execute (linha, zona, ícone deslizante e cooldown) +
    integração opcional com DoT Kill (DoesItDie / UsefulPlatesAndTooltips).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, tonumber, type = pairs, ipairs, pcall, tonumber, type
local floor, max, min = math.floor, math.max, math.min

local UnitHealth, UnitHealthMax, UnitHealthPercent = _G.UnitHealth, _G.UnitHealthMax, _G.UnitHealthPercent
local C_CurveUtil, Enum = _G.C_CurveUtil, _G.Enum

local EXECUTE_WINDOWS = {
    { "WARRIOR",     0.20, 5308, 20658, 20660, 20661, 20662, 25234, 25236, 47470, 47471, 163201, 280735 },
    { "WARRIOR",     0.35, 281001, 206315 },
    { "PALADIN",     0.20, 24275, 24239, 24274, 27180, 48805, 48806 },
    { "HUNTER",      0.20, 53351, 61005, 61006, 320976 },
    { "PRIEST",      0.20, 32379, 1309633 },
    { "DEATHKNIGHT", 0.35, 343294 },
    { "MONK",        0.15, 322109 },
    { "ROGUE",       0.35, 328085 },
    { "WARLOCK",     0.20, 17877, 388667 },
    { "WARLOCK",     0.35, 234876 },
    { "MAGE",        0.30, 269644 },
}

local knownExecute, knownExecuteSpell = 0, nil
local execOnCD = false

local function Learned(id)
    if _G.IsPlayerSpell then
        local ok, v = pcall(_G.IsPlayerSpell, id)
        if ok and v == true then return true end
    end
    local SB = _G.C_SpellBook
    if SB then
        for _, fn in ipairs({ SB.IsSpellKnown, SB.IsSpellKnownOrInSpellBook }) do
            if fn then
                local ok, v = pcall(fn, id)
                if ok and v == true then return true end
            end
        end
    end
    return false
end

local function KnownByName(id)
    local CS = _G.C_Spell
    if not (CS and CS.GetSpellName and CS.GetSpellInfo) then return false end
    local ok, name = pcall(CS.GetSpellName, id)
    if not ok or type(name) ~= "string" or name == "" then return false end
    local ok2, info = pcall(CS.GetSpellInfo, name)
    if not ok2 or type(info) ~= "table" or not info.spellID or info.spellID == id then return false end
    return Learned(info.spellID) and info.spellID or false
end

function NP.ScanExecute()
    local class = select(2, _G.UnitClass("player"))
    local best, spell = 0, nil
    for _, w in ipairs(EXECUTE_WINDOWS) do
        if w[1] == class then
            for i = 3, #w do
                local id = Learned(w[i]) and w[i] or KnownByName(w[i])
                if id then
                    if w[2] > best then best = w[2] end
                    spell = spell or id
                    break
                end
            end
        end
    end
    knownExecute, knownExecuteSpell = best, spell
    return best
end
function NP.GetKnownExecute() return knownExecute end

function NP.GetExecuteFraction(f)
    local e = NP.Prof(f).style.execute
    if not e or not e.enabled then return 0 end
    if e.auto and knownExecute > 0 then return knownExecute end
    if e.auto and e.onlyWithExecute then return 0 end
    return (e.percent or 20) / 100
end

local execCurves = setmetatable({}, { __mode = "k" })
local zoneCurves = setmetatable({}, { __mode = "k" })
local alphaCurves, dimCurves = {}, {}

local function ExecuteCurve(pct, e)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then return nil end
    local cached = execCurves[e]
    if cached and cached.pct == pct then return cached.curve end
    local c = C_CurveUtil.CreateColorCurve()
    c:SetType(Enum.LuaCurveType.Step)
    c:AddPoint(0, _G.CreateColor(NP.RGBA(e.executeColor)))
    c:AddPoint(pct + 0.0001, _G.CreateColor(NP.RGBA(e.color)))
    execCurves[e] = { pct = pct, curve = c }
    return c
end

local function ZoneCurve(pct, e)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve) then return nil end
    local z = e.zoneColor or { 1, 0.25, 0.25, 0.30 }
    local cached = zoneCurves[e]
    if cached and cached.pct == pct and cached.r == z[1] and cached.g == z[2] and cached.b == z[3] and cached.a == z[4] then
        return cached.curve
    end
    local a = z[4] or 0.3
    local c = C_CurveUtil.CreateColorCurve()
    c:SetType(Enum.LuaCurveType.Step)
    c:AddPoint(0, _G.CreateColor(z[1], z[2], z[3], min(1, a * 2.2)))
    c:AddPoint(pct + 0.0001, _G.CreateColor(z[1], z[2], z[3], a))
    zoneCurves[e] = { pct = pct, r = z[1], g = z[2], b = z[3], a = z[4], curve = c }
    return c
end

local function AlphaCurve(pct)
    if not (C_CurveUtil and C_CurveUtil.CreateCurve) then return nil end
    local key = floor(pct * 1000 + 0.5)
    local c = alphaCurves[key]
    if c then return c end
    c = C_CurveUtil.CreateCurve()
    if Enum and Enum.LuaCurveType and c.SetType then c:SetType(Enum.LuaCurveType.Step) end
    c:AddPoint(0, 1); c:AddPoint(pct + 0.0001, 0)
    alphaCurves[key] = c
    return c
end

local function DimCurve(pct)
    if not (C_CurveUtil and C_CurveUtil.CreateCurve) then return nil end
    local key = floor(pct * 1000 + 0.5)
    local c = dimCurves[key]
    if c then return c end
    c = C_CurveUtil.CreateCurve()
    if Enum and Enum.LuaCurveType and c.SetType then c:SetType(Enum.LuaCurveType.Step) end
    c:AddPoint(0, 1); c:AddPoint(pct + 0.0001, 0.35)
    dimCurves[key] = c
    return c
end

local EXEC_GLOWS = {
    soft   = { tex = NP.MEDIA .. "spark.png", k = 2.0 },
    ring   = { tex = NP.MEDIA .. "glow-round.png", k = 2.0 },
    square = { tex = NP.MEDIA .. "glow.png", k = 1.6 },
}
NP.EXEC_GLOW_STYLES = { soft = "Brilho suave", ring = "Anel", square = "Quadrado", none = "Sem brilho" }
NP.EXEC_GLOW_ORDER  = { "soft", "ring", "square", "none" }

local function ExecIconTexture(e)
    local CS = _G.C_Spell
    if e.iconSpell ~= false and knownExecuteSpell and CS and CS.GetSpellTexture then
        local ok, tex = pcall(CS.GetSpellTexture, knownExecuteSpell)
        if ok and tex then return tex, true end
    end
    return NP.MEDIA .. "type-boss.png", false
end

local function ExecIconParts(hb)
    if hb.execIcon then return hb.execIcon end
    local w = _G.CreateFrame("Frame", nil, hb)
    local inner = _G.CreateFrame("Frame", nil, w)
    inner:SetAllPoints()
    local glow = inner:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("CENTER"); glow:SetBlendMode("ADD")
    local border = inner:CreateTexture(nil, "BORDER")
    border:SetAllPoints(); border:SetColorTexture(0, 0, 0, 1)
    local tex = inner:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT", 1, -1); tex:SetPoint("BOTTOMRIGHT", -1, 1)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local cd = _G.CreateFrame("Cooldown", nil, w, "CooldownFrameTemplate")
    cd:SetAllPoints(tex); cd:SetDrawEdge(false); cd:SetDrawBling(false)
    cd.noCooldownCount = true

    local pulse = inner:CreateAnimationGroup(); pulse:SetLooping("BOUNCE")
    local sc = pulse:CreateAnimation("Scale")
    sc:SetScaleFrom(1, 1); sc:SetScaleTo(1.16, 1.16); sc:SetDuration(0.45); sc:SetSmoothing("IN_OUT")
    sc:SetOrigin("CENTER", 0, 0)

    local gPulse = glow:CreateAnimationGroup(); gPulse:SetLooping("BOUNCE")
    local ga = gPulse:CreateAnimation("Alpha")
    ga:SetFromAlpha(0.9); ga:SetToAlpha(0.25); ga:SetDuration(0.45)

    w.inner, w.glow, w.border, w.tex, w.cd = inner, glow, border, tex, cd
    w.pulse, w.glowPulse = pulse, gPulse
    w:Hide()
    hb.execIcon = w
    return w
end

function NP.KeepExecTimerOnTop(f)
    local w = f.health and f.health.execIcon
    if w and w.cd then w.cd:SetFrameLevel(w:GetFrameLevel() + 3) end
end

local function ApplyExecPulse(w, e)
    local want = (e.iconPulse ~= false) and not (e.iconPauseOnCD and execOnCD)
    w.glow:SetShown(want and not w.noGlow)
    if want then
        if not w.pulse:IsPlaying() then w.pulse:Play(); w.glowPulse:Play() end
    elseif w.pulse:IsPlaying() then
        w.pulse:Stop(); w.glowPulse:Stop()
    end
end

function NP.ExecIconCooldown(f)
    local w = f.health and f.health.execIcon
    if not (w and w.cd) then return end
    local e = NP.Prof(f).style.execute
    if not (e and e.icon and e.iconCooldown) or f.isPreview or not knownExecuteSpell then
        w.cd:Hide(); return
    end
    local CS = _G.C_Spell
    if CS and CS.GetSpellCooldownDuration and w.cd.SetCooldownFromDurationObject then
        local ok, dur = pcall(CS.GetSpellCooldownDuration, knownExecuteSpell, true)
        if ok and dur then
            local st = e.iconCooldownStyle or "both"
            if w.cd.SetDrawSwipe then w.cd:SetDrawSwipe(st ~= "numbers") end
            if w.cd.SetHideCountdownNumbers then w.cd:SetHideCountdownNumbers(st == "swipe") end
            w.cd:Show()
            pcall(w.cd.SetCooldownFromDurationObject, w.cd, dur, true)
            return
        end
    end
    w.cd:Hide()
end

function NP.LayoutExecute(f)
    local hb = f.health
    local e = NP.Prof(f).style.execute
    local pct = NP.GetExecuteFraction(f)
    local isEnemy = (f.kind == "enemynpc" or f.kind == "enemyplayer")
    if pct <= 0 or f.cfg.mode == "nameOnly" or (e.onlyEnemies ~= false and not isEnemy) then
        f.executePct = nil
        hb.execute:Hide(); hb.executeZone:Hide()
        if hb.execIcon then hb.execIcon:Hide() end
        return
    end
    f.executePct = pct
    local x = (f.cfg.healthWidth or 100) * pct
    hb.execute:ClearAllPoints()
    hb.execute:SetPoint("TOP", hb, "TOPLEFT", x, 0)
    hb.execute:SetPoint("BOTTOM", hb, "BOTTOMLEFT", x, 0)
    local w = max(1, tonumber(e.width) or 2)
    if e.soft then
        hb.execute:SetTexture(NP.MEDIA .. "spark.png")
        hb.execute:SetWidth(w * 3)
    else
        hb.execute:SetColorTexture(1, 1, 1, 1)
        hb.execute:SetWidth(w)
    end
    hb.execute:SetVertexColor(NP.RGBA(e.color))
    hb.execute:Show()

    if e.zone then
        hb.executeZone:ClearAllPoints()
        hb.executeZone:SetPoint("TOPLEFT", hb, "TOPLEFT", 0, 0)
        hb.executeZone:SetPoint("BOTTOMLEFT", hb, "BOTTOMLEFT", 0, 0)
        hb.executeZone:SetWidth(x)
        hb.executeZone:SetVertexColor(NP.RGBA(e.zoneColor or { 1, 0.25, 0.25, 0.30 }))
        hb.executeZone:Show()
    else
        hb.executeZone:Hide()
    end

    if e.icon then
        local ic = ExecIconParts(hb)
        local sz = tonumber(e.iconSize) or 20
        ic:SetSize(sz, sz)
        ic:SetFrameLevel(NP.DepthLevel(f, 8, "executeIcon"))
        NP.SetAnchor(ic, e.iconAnchor or { side = 6, x = 4, y = 0 }, hb)
        local tex = ExecIconTexture(e)
        ic.tex:SetTexture(tex)
        local g = EXEC_GLOWS[e.iconGlowStyle or "soft"]
        ic.noGlow = (g == nil)
        if g then
            ic.glow:SetTexture(g.tex)
            ic.glow:SetSize(sz * g.k, sz * g.k)
            ic.glow:SetVertexColor(NP.RGBA(e.iconGlowColor or { 1, 0.3, 0.15, 1 }))
        end
        ApplyExecPulse(ic, e)
        NP.ExecIconCooldown(f)
    elseif hb.execIcon then
        hb.execIcon:Hide()
    end
end

function NP.UpdateExecute(f)
    local pct = f.executePct
    if not pct or not f.unit or f.isPreview then return end
    local hb = f.health
    local e = NP.Prof(f).style.execute
    local ec = ExecuteCurve(pct, e)
    local zc = e.zone and ZoneCurve(pct, e)
    local ac = e.icon and (e.iconAlways and DimCurve(pct) or AlphaCurve(pct))

    if UnitHealthPercent and ec then
        local ok, col = pcall(UnitHealthPercent, f.unit, true, ec)
        if ok and col and col.GetRGBA then hb.execute:SetVertexColor(col:GetRGBA()) end
        if zc then
            local ok2, zcol = pcall(UnitHealthPercent, f.unit, true, zc)
            if ok2 and zcol and zcol.GetRGBA then hb.executeZone:SetVertexColor(zcol:GetRGBA()) end
        end
        if hb.execIcon and ac then
            local ok3, alpha = pcall(UnitHealthPercent, f.unit, true, ac)
            if ok3 and alpha ~= nil then
                hb.execIcon:SetAlpha(alpha)
                hb.execIcon:Show()
            end
        end
    else
        local cur, mx = UnitHealth(f.unit), UnitHealthMax(f.unit)
        if not NP.IsSecret(cur) and not NP.IsSecret(mx) and type(mx) == "number" and mx > 0 then
            local inExec = (cur / mx) <= pct
            hb.execute:SetVertexColor(NP.RGBA(inExec and e.executeColor or e.color))
            if hb.execIcon then
                if e.iconAlways then
                    hb.execIcon:SetAlpha(inExec and 1 or 0.35); hb.execIcon:Show()
                else
                    hb.execIcon:SetAlpha(1); hb.execIcon:SetShown(inExec)
                end
            end
        end
    end
end

function NP.ClearExecute(f)
    local hb = f.health
    if hb.execute then hb.execute:Hide() end
    if hb.executeZone then hb.executeZone:Hide() end
    if hb.execIcon then
        hb.execIcon.pulse:Stop(); hb.execIcon.glowPulse:Stop()
        hb.execIcon:Hide()
    end
end

function NP.PreviewExecute(f, st)
    local pct = f.executePct
    if not pct then return end
    local hb = f.health
    local e = NP.Prof(f).style.execute
    local inExec = st.execute or false
    hb.execute:SetVertexColor(NP.RGBA(inExec and e.executeColor or e.color))
    if e.icon and hb.execIcon then
        hb.execIcon:SetAlpha(inExec and 1 or (e.iconAlways and 0.35 or 0))
        hb.execIcon:SetShown(inExec or e.iconAlways or st.selected == "executeIcon")
    end
end

-- DoT Kill (integração opcional com DoesItDie / UsefulPlatesAndTooltips_DoTAPI)
local DK = {}
NP.DotKill = DK
local ENEMY_KIND = { enemynpc = true, enemyplayer = true }

local function DotAPI()
    local d1, d2 = _G.DoesItDie, _G.UsefulPlatesAndTooltips_DoTAPI
    for _, d in ipairs({ d1 or false, d2 or false }) do
        if type(d) == "table" and type(d.GetRemainingDamage) == "function" and (tonumber(d.API_VERSION) or 0) >= 1 then
            return d
        end
    end
    return nil
end

local function DotParts(hb)
    if hb.dotMarker then return end
    local m = _G.CreateFrame("StatusBar", nil, hb)
    m:SetAllPoints(hb); m:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    m:SetMinMaxValues(0, 1); m:SetValue(0)
    m.edge = m:CreateTexture(nil, "OVERLAY")
    m.edge:SetColorTexture(1, 1, 1, 0.9); m.edge:SetWidth(1)
    m.edge:SetPoint("TOPRIGHT", m:GetStatusBarTexture(), "TOPRIGHT")
    m.edge:SetPoint("BOTTOMRIGHT", m:GetStatusBarTexture(), "BOTTOMRIGHT")
    m:Hide()
    hb.dotMarker = m

    local w = _G.CreateFrame("Frame", nil, hb)
    w:SetClipsChildren(true)
    if w.SetIgnoringChildrenForBounds then pcall(w.SetIgnoringChildrenForBounds, w, true) end
    local bar = _G.CreateFrame("StatusBar", nil, w)
    bar:SetPoint("RIGHT", w, "RIGHT"); bar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    bar:SetStatusBarColor(0, 0, 0, 0); bar:SetMinMaxValues(0, 1); bar:SetValue(0)
    local icon = bar:CreateTexture(nil, "OVERLAY")
    icon:SetPoint("RIGHT", bar:GetStatusBarTexture(), "RIGHT")
    icon:SetTexture(NP.MEDIA .. "type-boss.png")
    w.bar, w.icon = bar, icon
    w:Hide()
    hb.dotKill = w
end

function DK.Layout(f)
    local hb = f.health
    local c = NP.Prof(f).extras and NP.Prof(f).extras.dotKill
    if not (c and c.enabled and ENEMY_KIND[f.kind]) then DK.Clear(f); return end
    DotParts(hb)
    local m, w = hb.dotMarker, hb.dotKill
    m:SetFrameLevel(hb:GetFrameLevel() + 1)
    m:SetStatusBarColor(NP.RGBA(c.color))
    local s = tonumber(c.iconSize) or 16
    w:SetSize(s, s); w:SetFrameLevel(hb:GetFrameLevel() + 6)
    w.bar:SetSize(10000, s); w.icon:SetSize(s, s)
    w:ClearAllPoints()
    if c.iconPos == "left" then w:SetPoint("RIGHT", hb, "LEFT", -3, 0)
    elseif c.iconPos == "above" then w:SetPoint("BOTTOM", hb, "TOP", 0, 3)
    else w:SetPoint("LEFT", hb, "RIGHT", 3, 0) end
end

function DK.Update(f)
    local hb = f.health
    if not hb.dotMarker then return end
    local c = NP.Prof(f).extras and NP.Prof(f).extras.dotKill
    local d = DotAPI()
    if not (d and c and c.enabled and ENEMY_KIND[f.kind] and f.unit and hb:IsShown()) then DK.Clear(f); return end
    local ok, dmg = pcall(d.GetRemainingDamage, f.unit)
    dmg = ok and tonumber(dmg) or 0
    if dmg <= 0 then DK.Clear(f); return end
    hb.dotMarker:SetMinMaxValues(0, UnitHealthMax(f.unit))
    hb.dotMarker:SetValue(dmg)
    hb.dotMarker:Show()
    if c.icon then
        hb.dotKill.bar:SetMinMaxValues(0, UnitHealth(f.unit))
        hb.dotKill.bar:SetValue(dmg)
        hb.dotKill:Show()
    else
        hb.dotKill:Hide()
    end
end

function DK.Clear(f)
    local hb = f.health
    if hb and hb.dotMarker then hb.dotMarker:Hide(); hb.dotKill:Hide() end
end

function DK.Preview(f, on)
    local hb = f.health
    local c = NP.Prof(f).extras and NP.Prof(f).extras.dotKill
    if not (on and c and c.enabled and ENEMY_KIND[f.kind] and hb:IsShown()) then DK.Clear(f); return end
    DK.Layout(f)
    hb.dotMarker:SetMinMaxValues(0, 100); hb.dotMarker:SetValue(80); hb.dotMarker:Show()
    hb.dotKill.bar:SetMinMaxValues(0, 71); hb.dotKill.bar:SetValue(80)
    hb.dotKill:SetShown(c.icon and true or false)
end

-- Eventos de execute e DoT Kill
local ev = _G.CreateFrame("Frame")
Azaath.SafeRegister(ev, "PLAYER_LOGIN")
Azaath.SafeRegister(ev, "SPELLS_CHANGED")
Azaath.SafeRegister(ev, "PLAYER_TALENT_UPDATE")
Azaath.SafeRegister(ev, "PLAYER_SPECIALIZATION_CHANGED")
Azaath.SafeRegister(ev, "SPELL_UPDATE_COOLDOWN")
ev:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player")
ev:SetScript("OnEvent", function(_, event, _, _, spellID)
    if event == "SPELL_UPDATE_COOLDOWN" then
        if not NP.db then return end
        for _, f in pairs(NP.ActivePlates) do
            if f.executePct and f.health and f.health.execIcon then NP.ExecIconCooldown(f) end
        end
        return
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        if knownExecuteSpell and not NP.IsSecret(spellID) and spellID == knownExecuteSpell then
            execOnCD = true
            local base = _G.GetSpellBaseCooldown and _G.GetSpellBaseCooldown(knownExecuteSpell)
            base = (type(base) == "number" and not NP.IsSecret(base) and base > 0) and base / 1000 or 6
            _G.C_Timer.After(base, function()
                execOnCD = false
                for _, f in pairs(NP.ActivePlates) do
                    if f.executePct and f.health and f.health.execIcon then
                        ApplyExecPulse(f.health.execIcon, NP.Prof(f).style.execute)
                    end
                end
            end)
        end
        return
    end
    NP.ScanExecute()
    if NP.db then
        for _, f in pairs(NP.ActivePlates) do
            if f.active then NP.LayoutExecute(f); NP.UpdateExecute(f) end
        end
    end
end)
