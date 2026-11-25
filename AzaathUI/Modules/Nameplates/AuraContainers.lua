--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/AuraContainers.lua
    Motor nativo com CustomAuraContainerTemplate (100% seguro contra secret
    values em combate) + DebuffColors (colorir barra de vida por debuffs).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, tonumber, tostring, type = pairs, ipairs, pcall, tonumber, tostring, type
local floor, max = math.floor, math.max

local AC = {}
NP.AuraContainers = AC
NP.AuraStyleVersion = NP.AuraStyleVersion or 1

AC.available = (_G.C_XMLUtil and _G.C_XMLUtil.GetTemplateInfo
    and _G.C_XMLUtil.GetTemplateInfo("CustomAuraContainerTemplate")) and true or false

local Flow = _G.AnchorUtil and _G.AnchorUtil.FlowDirection or { Left = -1, Right = 1, Up = 1, Down = -1 }
local PRESERVE = _G.Enum and _G.Enum.CustomAuraButtonDispelTypeTextureStyle and _G.Enum.CustomAuraButtonDispelTypeTextureStyle.PreserveAsset or 3
local REMAINING_PERCENT = _G.Enum and _G.Enum.DurationTextBindingProperty and _G.Enum.DurationTextBindingProperty.RemainingPercent or 1

local ROWS = {
    debuffs = { row = "debuffRow", groups = {
        custom = function(a)
            if not a.debuffs.enabled or not a.custom or not next(a.custom.include) then return nil end
            return a.custom.includeFromAnyone and "HARMFUL" or "HARMFUL|PLAYER"
        end,
        main = function(a)
            if not a.debuffs.enabled then return nil end
            local f = a.debuffs.onlyMine and "HARMFUL|PLAYER" or "HARMFUL"
            if a.cc.enabled then f = f .. "|!CROWD_CONTROL" end
            if a.debuffs.onlyImportant then f = f .. "|IMPORTANT" end
            return f
        end,
        nameplate = function(a)
            if not a.debuffs.enabled or not a.debuffs.onlyImportant then return nil end
            local f = a.debuffs.onlyMine and "HARMFUL|PLAYER" or "HARMFUL"
            if a.cc.enabled then f = f .. "|!CROWD_CONTROL" end
            return f .. "|!IMPORTANT"
        end,
    } },
    buffs = { row = "buffRow", groups = {
        dispel = function(a)
            if not a.buffs.enabled or a.buffs.showAll then return nil end
            if not (a.buffs.showDispellable or a.buffs.showEnrage) then return nil end
            return "HELPFUL|RAID_PLAYER_DISPELLABLE"
        end,
        important = function(a)
            if not a.buffs.enabled or a.buffs.showAll or not a.buffs.showImportant then return nil end
            return "HELPFUL|IMPORTANT|!RAID_PLAYER_DISPELLABLE"
        end,
        all = function(a)
            if not a.buffs.enabled or not a.buffs.showAll then return nil end
            return "HELPFUL"
        end,
    } },
    cc            = { row = "ccRow",           groups = { main = function(a) return a.cc.enabled and "HARMFUL|CROWD_CONTROL" or nil end } },
    friendBuffs   = { row = "friendRow",       groups = { main = function(a) return a.friendBuffs and a.friendBuffs.enabled and "HELPFUL|PLAYER" or nil end } },
    friendDebuffs = { row = "friendDebuffRow", groups = { main = function(a) return a.friendDebuffs and a.friendDebuffs.enabled and NP.FriendDebuffFilter(a) or nil end } },
}
local GROUP_ORDER = {
    debuffs = { "custom", "main", "nameplate" }, buffs = { "dispel", "important", "all" },
    cc = { "main" }, friendBuffs = { "main" }, friendDebuffs = { "main" },
}

local AURA_IDS = {
    [772] = { 388539 }, [262111] = { 262115 }, [1822] = { 155722 }, [106830] = { 405233, 192090 },
    [77758] = { 192090 }, [8921] = { 164812 }, [93402] = { 164815 }, [274837] = { 274838 },
    [172] = { 146739 }, [348] = { 157736 }, [259495] = { 269747 }, [49184] = { 55095 },
    [50842] = { 55078 }, [77575] = { 191587 }, [204197] = { 204213 }, [44457] = { 217694 },
    [11366] = { 12654 }, [20271] = { 197277 }, [231663] = { 197277 },
}
NP.AURA_IDS = AURA_IDS

function NP.AddAuraIDs(set, id)
    id = tonumber(id); if not id then return end
    set[id] = true
    for _, extra in ipairs(AURA_IDS[id] or {}) do set[extra] = true end
end

local function SpellSet(t)
    local out = {}
    for id, on in pairs(t or {}) do if on then NP.AddAuraIDs(out, id) end end
    return out
end

local function CandidateFilters(key, gk, a)
    local c = a.custom
    if not c then return nil end
    if key == "debuffs" and gk == "custom" then
        return { includeSpellIDs = SpellSet(c.include) }
    elseif key == "debuffs" then
        local ex = SpellSet(c.exclude)
        for id in pairs(SpellSet(c.include)) do ex[id] = true end
        if gk == "nameplate" then return { excludeSpellIDs = ex, nameplateShowPersonal = true } end
        return { excludeSpellIDs = ex }
    elseif key == "cc" then
        return { excludeSpellIDs = SpellSet(c.exclude) }
    end
    return nil
end

local timeFormatter
local function TimeFormatter()
    if timeFormatter ~= nil then return timeFormatter or nil end
    timeFormatter = false
    if _G.C_StringUtil and _G.C_StringUtil.CreateNumericRuleFormatter then
        local ok, fmt = pcall(_G.C_StringUtil.CreateNumericRuleFormatter)
        if ok and fmt and pcall(function()
            fmt:AddBreakpoint({ threshold = 0, format = "" })
            fmt:AddBreakpoint({ threshold = 1, step = 1, format = "%d" })
            fmt:AddBreakpoint({ threshold = 60, format = "%dm", components = { { div = 60, step = 1 } } })
            fmt:AddBreakpoint({ threshold = 3600, format = "%dh", components = { { div = 3600, step = 1 } } })
        end) then timeFormatter = fmt end
    end
    return timeFormatter or nil
end

local function AurasSecretNow()
    if _G.InCombatLockdown() then return true end
    if _G.C_Secrets and _G.C_Secrets.ShouldAurasBeSecret then
        local ok, secret = pcall(_G.C_Secrets.ShouldAurasBeSecret)
        return ok and secret == true
    end
    return false
end

local function SetupAnts(host, w, h, hl)
    host.ants = host.ants or NP.CreateAnts(host, host)
    host.ants:Anchor(hl.antsPadding or 1)
    host.ants:Setup({ 1, 1, 1, 1 }, hl.antsThickness or 1.5, hl.antsPadding or 1, 5, 3, hl.antsSpeed or 1)
    host.ants:Start()
    return host.ants.pool
end

local function SetupPandemic(b, w, h, pc)
    local native = b.AddPandemicRegion and b.ClearPandemicRegions
    if native then
        b:ClearPandemicRegions()
        if b.ClearPandemicActiveAnimations then b:ClearPandemicActiveAnimations() end
    end
    if b.PandemicGlow then b.PandemicGlow:SetShown(false) end
    b.PandemicPulse:Stop()
    if b.PandemicAnts.ants then b.PandemicAnts.ants:Stop() end
    b.PandemicAnts:Hide()
    if not (pc and pc.enabled and native) then b.PandemicHost:Hide(); return end
    b.PandemicHost:Show()
    local addAnim = b.AddPandemicActiveAnimation
    if pc.style == "glow" then
        b.PandemicGlow = b.PandemicGlow or NP.CreateGlow(b.PandemicHost, b, "BACKGROUND", -7)
        b.PandemicGlow:Setup(pc.color, pc.size or 3, 1, 0)
        b.PandemicGlow:SetShown(true)
        for _, t in pairs(b.PandemicGlow.pieces) do b:AddPandemicRegion(t) end
        for _, t in pairs(b.PandemicGlow.fill) do b:AddPandemicRegion(t) end
        if addAnim then b:AddPandemicActiveAnimation(b.PandemicPulse) end
    else
        b.PandemicAnts:Show()
        b.PandemicAnts.ants = b.PandemicAnts.ants or NP.CreateAnts(b.PandemicAnts, b)
        b.PandemicAnts.ants:Anchor(pc.padding or 0)
        b.PandemicAnts.ants:Setup(pc.color, pc.thickness or 1, pc.padding or 0, 5, 3, pc.speed or 1)
        b.PandemicAnts.ants:Start()
        for _, t in ipairs(b.PandemicAnts.ants.pool) do b:AddPandemicRegion(t) end
        if addAnim then
            for _, side in ipairs(b.PandemicAnts.ants.sides) do b:AddPandemicActiveAnimation(side.ag) end
        end
    end
end

local sigCache = setmetatable({}, { __mode = "k" })
local function Ser(v, out)
    if type(v) == "table" then
        local keys = {}
        for k in pairs(v) do keys[#keys + 1] = k end
        table.sort(keys, function(x, y) return type(x) ~= type(y) and type(x) < type(y) or tostring(x) < tostring(y) end)
        out[#out + 1] = "{"
        for _, k in ipairs(keys) do out[#out + 1] = tostring(k) .. "="; Ser(v[k], out); out[#out + 1] = ";" end
        out[#out + 1] = "}"
    else out[#out + 1] = tostring(v) end
end
local function AuraSig(f)
    local a = NP.Prof(f).auras
    local e = sigCache[a]
    local ver = NP.AuraStyleVersion
    if e and e.ver == ver then return e.sig end
    local out = { tostring(ver), ":" }; Ser(a, out)
    local sig = table.concat(out); sigCache[a] = { ver = ver, sig = sig }
    return sig
end

local function StyleButton(b, key, f)
    local a = NP.Prof(f).auras
    local rowCfg = a[key]
    local w, h = rowCfg.width, rowCfg.height
    local bs = a.borderSize or 1
    b:SetSize(w, h)
    b:SetMouseMotionEnabled(a.tooltips)

    if not b.azStyled then
        b.azStyled = true
        b.Border = b:CreateTexture(nil, "BACKGROUND"); b.Border:SetAllPoints(); b.Border:SetColorTexture(1, 1, 1, 1)
        b.Icon = b:CreateTexture(nil, "ARTWORK"); b:SetIcon(b.Icon)
        b.Cooldown = _G.CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
        b.Cooldown:SetDrawEdge(false); b.Cooldown:SetDrawBling(false); b.Cooldown:SetHideCountdownNumbers(true)
        b.Cooldown.noCooldownCount = true; b.Cooldown:EnableMouse(false)
        b:SetDurationCooldown(b.Cooldown)
        b.TextFrame = _G.CreateFrame("Frame", nil, b); b.TextFrame:SetAllPoints()
        b.TextFrame:SetFrameLevel(b.Cooldown:GetFrameLevel() + 2)
        b.Timer = b.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        b.Count = b.TextFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        if key == "buffs" then
            b.GlowHost = _G.CreateFrame("Frame", nil, b); b.GlowHost:SetAllPoints(b); b.GlowHost:EnableMouse(false)
            local ag = b.GlowHost:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
            local fd = ag:CreateAnimation("Alpha"); fd:SetFromAlpha(1); fd:SetToAlpha(0.25); fd:SetDuration(0.6)
            b.GlowPulse = ag
            b.AntsHost = _G.CreateFrame("Frame", nil, b); b.AntsHost:SetAllPoints(b); b.AntsHost:EnableMouse(false)
            b.AntsHost:SetFrameLevel(b.TextFrame:GetFrameLevel() - 1); b.AntsHost:Hide()
        elseif key == "debuffs" then
            b.PandemicHost = _G.CreateFrame("Frame", nil, b); b.PandemicHost:SetAllPoints(b); b.PandemicHost:EnableMouse(false)
            b.PandemicHost:SetFrameLevel(b.TextFrame:GetFrameLevel() - 1)
            local ag = b.PandemicHost:CreateAnimationGroup(); ag:SetLooping("BOUNCE")
            local fd = ag:CreateAnimation("Alpha"); fd:SetFromAlpha(1); fd:SetToAlpha(0.3); fd:SetDuration(0.5)
            b.PandemicPulse = ag
            b.PandemicAnts = _G.CreateFrame("Frame", nil, b.PandemicHost); b.PandemicAnts:SetAllPoints(b); b.PandemicAnts:Hide()
        end
    end

    b.Icon:ClearAllPoints(); b.Icon:SetPoint("TOPLEFT", bs, -bs); b.Icon:SetPoint("BOTTOMRIGHT", -bs, bs)
    local ratio = (h - 2 * bs) / max(1, (w - 2 * bs))
    local crop = max(0, (1 - ratio) / 2 * 0.84)
    b.Icon:SetTexCoord(0.08, 0.92, 0.08 + crop, 0.92 - crop)
    b.Cooldown:ClearAllPoints(); b.Cooldown:SetAllPoints(b.Icon)
    b.Cooldown:SetDrawSwipe(a.swipe); b.Cooldown:SetReverse(a.reverseSwipe)

    NP.StyleText(b.Timer, { font = a.timer.font or a.font, size = a.timer.size * (w / 26), outline = a.timer.outline, shadow = true, color = a.timer.color })
    NP.SetAnchor(b.Timer, a.timer.anchor, b)
    local st, showStacks = NP.StackStyle(key == "buffs", f)
    NP.StyleText(b.Count, { font = st.font or a.font, size = st.size * (w / 26), outline = st.outline, shadow = true, color = st.color })
    NP.SetAnchor(b.Count, st.anchor, b)

    local ext = a.timer.externalTimers and true or false
    b.Cooldown.noCooldownCount = (not ext) or nil
    if a.timer.enabled and not ext then
        local opts = { textFormatter = TimeFormatter() }
        local pc = rowCfg.pandemic
        if key == "debuffs" and (not pc or pc.colorTimer ~= false) and NP.GetPandemicCurve() then
            opts.textColor = { curve = NP.GetPandemicCurve(), property = REMAINING_PERCENT }
        end
        b:SetDurationText(b.Timer, opts)
        b.Timer:SetAlpha(1); b.Timer:Show()
    else
        if b.ClearDurationText then pcall(b.ClearDurationText, b) end
        b.Timer:SetAlpha(0); b.Timer:Hide()
    end
    if showStacks and not ext then b:SetApplicationCount(b.Count); b.Count:Show()
    else if b.ClearApplicationCount then pcall(b.ClearApplicationCount, b) end; b.Count:Hide() end

    b:ClearDispelTypeTextures()
    local baseBorder = (key == "cc") and rowCfg.borderColor or a.borderColor
    b.Border:SetVertexColor(NP.RGBA(baseBorder))
    if ((key == "debuffs" and a.borderByDispelType) or key == "friendDebuffs") and NP.GetDispelCurve() then
        b:AddDispelTypeTexture(b.Border, { showWhenHarmful = true, showWithoutDispelType = true, style = PRESERVE, customDispelColorCurve = NP.GetDispelCurve() })
    elseif key == "buffs" then
        local hl = rowCfg.highlight
        local style = NP.BuffHighlightStyle(hl)
        local glowCurve, borderCurve = NP.GetHighlightCurves(NP.AuraStyleVersion or 0, f)
        local function reg(t, curve)
            b:AddDispelTypeTexture(t, { showWhenHarmful = false, showWhenHelpful = true, showWithoutDispelType = true, style = PRESERVE, customDispelColorCurve = curve })
        end
        if (style == "border" or style == "both") and borderCurve then reg(b.Border, borderCurve) end
        if (style == "glow" or style == "pulse" or style == "both") and glowCurve then
            b.Glow = b.Glow or NP.CreateGlow(b.GlowHost, b, "BACKGROUND", -7)
            b.Glow:Setup({ 1, 1, 1, 1 }, hl.size, 1, 0); b.Glow:SetShown(true); b.GlowHost:Show()
            if style == "pulse" then b.GlowPulse:Play() else b.GlowPulse:Stop(); b.GlowHost:SetAlpha(1) end
            for _, t in pairs(b.Glow.pieces) do reg(t, glowCurve) end
        else
            b.GlowPulse:Stop(); b.GlowHost:Hide()
        end
        if style == "ants" and glowCurve then
            for _, t in ipairs(SetupAnts(b.AntsHost, w, h, hl)) do reg(t, glowCurve) end
            b.AntsHost:Show()
        else
            b.AntsHost:Hide(); if b.AntsHost.ants then b.AntsHost.ants:Stop() end
        end
    end
    if key == "debuffs" then SetupPandemic(b, w, h, rowCfg.pandemic) end
    b.azSig = f and AuraSig(f)
end

local function SortMethod(key, rowCfg)
    local M = _G.AuraContainerSortMethod
    if not M then return 0 end
    if rowCfg.sort == "duration" and M.ExpirationOnly then return M.ExpirationOnly end
    if key == "debuffs" then return M.AuraInstanceIDOnly or M.Default end
    return M.Default
end
local SORT_NORMAL = _G.AuraContainerSortDirection and _G.AuraContainerSortDirection.Normal or 0

local function GroupOptions(key, maxCount, gk, f)
    local a = NP.Prof(f).auras
    local rowCfg = a[key]
    local sp = rowCfg.spacing or 1
    return {
        candidateFilters = CandidateFilters(key, gk, a),
        maxFrameCount = max(0, floor(maxCount or rowCfg.max or 10)),
        sortMethod = SortMethod(key, rowCfg),
        sortDirection = SORT_NORMAL,
        initializeFrame = function(b)
            if b.azSig ~= AuraSig(f) then StyleButton(b, key, f) end
        end,
        layout = { elementSpacing = sp, lineSpacing = sp, groupSpacing = sp, groupLineSpacing = sp, elementWidth = rowCfg.width, elementHeight = rowCfg.height },
    }
end

local function Configure(f)
    local a = NP.Prof(f).auras
    for key, c in pairs(f.auraContainers) do
        local rowCfg, any = a[key], false
        local row = f[ROWS[key].row]
        c:ClearAllPoints()
        local pt = rowCfg.grow == "LEFT" and "BOTTOMRIGHT" or (rowCfg.grow == "CENTER" and "BOTTOM" or "BOTTOMLEFT")
        c:SetPoint(pt, row, pt, 0, 0)
        for _, gk in ipairs(GROUP_ORDER[key]) do
            local filter = ROWS[key].groups[gk](a)
            if filter then
                if not c.groups[gk] then
                    c:AddAuraGroup(gk, filter, GroupOptions(key, rowCfg.max, gk, f))
                    c.groups[gk] = filter
                else
                    local cf = CandidateFilters(key, gk, a)
                    if cf and c.SetAuraGroupCandidateFilters then pcall(c.SetAuraGroupCandidateFilters, c, gk, cf) end
                    if c.groups[gk] ~= filter then c:SetAuraGroupFilterString(gk, filter); c.groups[gk] = filter end
                    c:SetAuraGroupMaxFrameCount(gk, max(0, floor(rowCfg.max)))
                    c:SetAuraGroupLayout(gk, GroupOptions(key, rowCfg.max, nil, f).layout)
                    if c.SetAuraGroupSortMethod then pcall(c.SetAuraGroupSortMethod, c, gk, SortMethod(key, rowCfg), SORT_NORMAL) end
                end
                c:SetAuraGroupEnabled(gk, true); any = true
            elseif c.groups[gk] then c:SetAuraGroupEnabled(gk, false) end
        end
        c.azEmpty = not any
        local perRow, sp = rowCfg.perRow or rowCfg.max or 10, rowCfg.spacing or 1
        if rowCfg.grow == "LEFT" then c:SetFlowLayoutAnchorPoint("BOTTOMRIGHT"); c:SetFlowLayoutGrowthDirection(Flow.Left, Flow.Up)
        else c:SetFlowLayoutAnchorPoint("BOTTOMLEFT"); c:SetFlowLayoutGrowthDirection(Flow.Right, Flow.Up) end
        c:SetFlowLayoutMaximumLineSize(perRow * (rowCfg.width + sp) + 1)
    end
    f.auraContainersSig = AuraSig(f)
end

function AC.RestylePlate(f)
    if AurasSecretNow() then return false end
    local sig = AuraSig(f)
    for key, c in pairs(f.auraContainers or {}) do
        for gk in pairs(c.groups) do
            local ok, n = pcall(c.GetAuraGroupFrameCount, c, gk)
            for i = 1, (ok and n or 0) do
                local ok2, b = pcall(c.GetAuraGroupFrame, c, gk, i)
                if ok2 and b and b.azSig ~= sig then pcall(StyleButton, b, key, f) end
            end
        end
    end
    return true
end

local pendingRestyle = false
function AC.OnSettingsChanged()
    if AurasSecretNow() then
        if not pendingRestyle then
            pendingRestyle = true
            _G.C_Timer.After(1, function() pendingRestyle = false; AC.OnSettingsChanged() end)
        end
        return
    end
    for _, f in pairs(NP.ActivePlates) do AC.RestylePlate(f) end
end

function AC.Update(f)
    if not f.auraContainers then
        f.auraContainers = {}
        for key, def in pairs(ROWS) do
            local c = _G.CreateFrame("AuraContainer", nil, f.auraHolder, "CustomAuraContainerTemplate")
            c:SetSize(1, 1); c.key = key; c.azRow = def.row; c.groups = {}
            f.auraContainers[key] = c
        end
        if NP.ApplyDepths then NP.ApplyDepths(f) end
    end
    if f.auraContainersSig ~= AuraSig(f) then
        Configure(f); AC.RestylePlate(f)
    end
    for _, row in ipairs(f.auraRows) do
        if row.shown ~= 0 then row.shown = 0; for _, b in ipairs(row.icons) do b:Hide() end end
    end
    for key, c in pairs(f.auraContainers) do
        local on
        if key == "friendBuffs" then on = not c.azEmpty and NP.FriendBuffsOn(f)
        elseif key == "friendDebuffs" then on = not c.azEmpty and NP.FriendDebuffsOn(f)
        else on = not c.azEmpty and (not f.friendAurasOnly or (key == "cc" and f.friendCC)) and (key ~= "buffs" or f.hostile) and true or false end
        if on then c:SetUnit(f.unit); c:SetEnabled(true) else c:SetEnabled(false) end
        c:SetShown(on)
    end
end

function AC.Clear(f)
    for _, c in pairs(f.auraContainers or {}) do c:SetEnabled(false) end
end

-- DebuffColors (colorir barra de vida do inimigo quando um dos seus até 5 debuffs está ativo)
local DC = {}
NP.DebuffColors = DC
DC.MAX = 5
local ENEMY = { enemynpc = true, enemyplayer = true }
local dcCache = {}

function DC.Available() return AC.available end
function DC.IsMine(e)
    if type(e) ~= "table" then return false end
    local myCls = select(2, _G.UnitClass("player"))
    if e.class then return e.class == myCls end
    local id = tonumber(e.id)
    if id and ((_G.IsPlayerSpell and _G.IsPlayerSpell(id)) or (_G.C_SpellBook and _G.C_SpellBook.IsSpellKnown and _G.C_SpellBook.IsSpellKnown(id))) then
        e.class = myCls; return true
    end
    return false
end
function DC.Mine(list)
    list = list or {}
    local out = {}
    for _, e in ipairs(list) do if DC.IsMine(e) then out[#out + 1] = e end end
    return out
end
local function DCIDs(e)
    local set, keys = {}, {}
    local function add(id)
        id = tonumber(id); if id and id > 0 and not set[id] then set[id] = true; keys[#keys + 1] = id end
        for _, extra in ipairs((id and AURA_IDS[id]) or {}) do if not set[extra] then set[extra] = true; keys[#keys + 1] = extra end end
    end
    add(e.id)
    local CS = _G.C_Spell
    local name = e.name or (CS and CS.GetSpellName and CS.GetSpellName(tonumber(e.id) or 0))
    if name and CS and CS.GetSpellInfo then
        local ok, info = pcall(CS.GetSpellInfo, name)
        if ok and type(info) == "table" then add(info.spellID) end
    end
    table.sort(keys)
    return set, table.concat(keys, "+")
end
function DC.Update(f)
    local c = NP.Prof(f).colors and NP.Prof(f).colors.debuffColors
    local mine = c and c.enabled and DC.Mine(c.list)
    if not (mine and #mine > 0 and DC.Available() and ENEMY[f.kind] and f.unit and f.health and f.health:IsShown() and not f.isPreview) then
        DC.Clear(f); return
    end
    local k = f.dcKit
    if not k then
        local hb = f.health
        local cont = _G.CreateFrame("AuraContainer", nil, hb, "CustomAuraContainerTemplate")
        cont:SetSize(1, 1); cont:SetPoint("CENTER", hb, "CENTER"); cont:SetFrameLevel(hb:GetFrameLevel() + 1); cont:SetEnabled(false)
        k = { cont = cont, tints = {}, keys = {} }; f.dcKit = k
    end
    local sigTab = {}
    for i, e in ipairs(mine) do local _, s = DCIDs(e); sigTab[i] = s end
    local sig = table.concat(sigTab, ",")
    if k.sig ~= sig and not _G.InCombatLockdown() then
        local fill = f.health:GetStatusBarTexture()
        for i = DC.MAX, 1, -1 do
            local e, key = mine[i], "azdc" .. i
            if e and tonumber(e.id) then
                local cf = { includeSpellIDs = (DCIDs(e)) }
                if not k.keys[key] then
                    local ok = pcall(k.cont.AddAuraSlot, k.cont, key, "HARMFUL|PLAYER", {
                        initializeFrame = function(af)
                            af:SetSize(1, 1); af:ClearAllPoints(); af:SetPoint("CENTER", k.cont, "CENTER")
                            if af.EnableMouse then af:EnableMouse(false) end
                            for _, r in ipairs({ af:GetRegions() }) do if r.SetAlpha then r:SetAlpha(0) end end
                            for _, ch in ipairs({ af:GetChildren() }) do if ch.SetAlpha then ch:SetAlpha(0) end end
                            af:SetFrameLevel(k.cont:GetFrameLevel())
                            local t = af:CreateTexture(nil, "ARTWORK"); t:SetAllPoints(fill); k.tints[i] = t
                            local cur = DC.Mine(NP.Prof(f).colors.debuffColors.list)[i]
                            if cur then t:SetTexture(NP.GetStatusBarTexture(NP.Prof(f).style.healthTexture)); t:SetVertexColor(NP.RGBA(cur.color)) end
                        end,
                        candidateFilters = cf,
                    })
                    if ok then k.keys[key] = true end
                else
                    pcall(k.cont.SetAuraSlotCandidateFilters, k.cont, key, cf)
                end
                if k.keys[key] then pcall(k.cont.SetAuraSlotEnabled, k.cont, key, true) end
                if k.tints[i] then k.tints[i]:SetTexture(NP.GetStatusBarTexture(NP.Prof(f).style.healthTexture)); k.tints[i]:SetVertexColor(NP.RGBA(e.color)) end
            elseif k.keys[key] then pcall(k.cont.SetAuraSlotEnabled, k.cont, key, false) end
        end
        k.sig = sig
    end
    k.cont:SetUnit(f.unit); k.cont:SetEnabled(true); k.cont:Show()
end
function DC.Clear(f)
    if f.dcKit then f.dcKit.cont:SetEnabled(false); f.dcKit.cont:Hide() end
end
function DC.Refresh()
    wipe(dcCache)
    for _, f in pairs(NP.ActivePlates) do if f.dcKit then f.dcKit.sig = nil end; DC.Update(f) end
end
local dcWatch = _G.CreateFrame("Frame")
Azaath.SafeRegister(dcWatch, "SPELLS_CHANGED"); Azaath.SafeRegister(dcWatch, "PLAYER_REGEN_ENABLED")
dcWatch:SetScript("OnEvent", function() if NP.db then DC.Refresh() end end)
