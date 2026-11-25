--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Auras.lua
    Sistema completo de auras: 5 contêineres (debuffs, buffs, CC, buffs/debuffs
    em aliados), Pandemic (formigas/glow + timer vermelho), destaque de purge/
    enrage, listas customizadas (incluir/excluir) e bordas por tipo de dispel.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, tonumber, type = pairs, ipairs, pcall, tonumber, type
local floor, max, min = math.floor, math.max, math.min

local C_UnitAuras = _G.C_UnitAuras
local GetUnitAuras = C_UnitAuras and C_UnitAuras.GetUnitAuras
local IsFilteredOut = C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID
local GetAuraDuration = C_UnitAuras and C_UnitAuras.GetAuraDuration
local GetCount = C_UnitAuras and C_UnitAuras.GetAuraApplicationDisplayCount
local SORT = _G.Enum and _G.Enum.UnitAuraSortRule and _G.Enum.UnitAuraSortRule.Default or 1

NP.HIGHLIGHT_BUFF_STYLES = {
    glow   = "Brilho",
    pulse  = "Brilho pulsante",
    ants   = "Formigas marchando",
    border = "Borda colorida",
    both   = "Brilho + borda",
}
NP.HIGHLIGHT_BUFF_ORDER = { "glow", "pulse", "ants", "border", "both" }
NP.PANDEMIC_STYLES = { ants = "Formigas marchando", glow = "Brilho pulsante" }
NP.PANDEMIC_ORDER  = { "ants", "glow" }

local dispelCurve, pandemicCurve, pandemicAlphaCurve
function NP.GetDispelCurve()
    if dispelCurve or not (_G.C_CurveUtil and _G.C_CurveUtil.CreateColorCurve) then return dispelCurve end
    local c = _G.C_CurveUtil.CreateColorCurve()
    c:SetType(_G.Enum.LuaCurveType.Step)
    c:AddPoint(0,  _G.CreateColor(0, 0, 0, 1))
    c:AddPoint(1,  _G.CreateColor(0, 0.5, 1, 1))
    c:AddPoint(2,  _G.CreateColor(0.62, 0.02, 0.9, 1))
    c:AddPoint(3,  _G.CreateColor(0.95, 0.4, 0.04, 1))
    c:AddPoint(4,  _G.CreateColor(0.48, 0.78, 0, 1))
    c:AddPoint(5,  _G.CreateColor(0, 0, 0, 1))
    c:AddPoint(9,  _G.CreateColor(0.85, 0.2, 0.1, 1))
    c:AddPoint(10, _G.CreateColor(0, 0, 0, 1))
    c:AddPoint(11, _G.CreateColor(0.72, 0, 0.06, 1))
    c:AddPoint(12, _G.CreateColor(0, 0, 0, 1))
    dispelCurve = c
    return c
end

function NP.GetPandemicCurve()
    if pandemicCurve or not (_G.C_CurveUtil and _G.C_CurveUtil.CreateColorCurve) then return pandemicCurve end
    local c = _G.C_CurveUtil.CreateColorCurve()
    c:SetType(_G.Enum.LuaCurveType.Step)
    c:AddPoint(0, _G.CreateColor(1, 0.25, 0.25, 1))
    c:AddPoint(0.3, _G.CreateColor(1, 1, 1, 1))
    pandemicCurve = c
    return c
end

local function GetPandemicAlphaCurve()
    if pandemicAlphaCurve or not (_G.C_CurveUtil and _G.C_CurveUtil.CreateColorCurve) then return pandemicAlphaCurve end
    local c = _G.C_CurveUtil.CreateColorCurve()
    c:SetType(_G.Enum.LuaCurveType.Step)
    c:AddPoint(0, _G.CreateColor(1, 1, 1, 1))
    c:AddPoint(0.3, _G.CreateColor(1, 1, 1, 0))
    pandemicAlphaCurve = c
    return c
end

local function BuildTypeCurve(h, other, strength)
    if not (_G.C_CurveUtil and _G.C_CurveUtil.CreateColorCurve) then return nil end
    local c = _G.C_CurveUtil.CreateColorCurve()
    c:SetType(_G.Enum.LuaCurveType.Step)
    local function col(t) local r, g, b, a = NP.RGBA(t); return _G.CreateColor(r, g, b, a * (strength or 1)) end
    local none = _G.CreateColor(NP.RGBA(other))
    c:AddPoint(0, none)
    c:AddPoint(1, h.purge.enabled and col(h.purge.color) or none)
    c:AddPoint(2, none)
    c:AddPoint(9, h.enrage.enabled and col(h.enrage.color) or none)
    c:AddPoint(10, none)
    return c
end

local hlCache = setmetatable({}, { __mode = "k" })
function NP.GetHighlightCurves(version, f)
    local a = NP.Prof(f).auras
    local c = hlCache[a]
    if not c or c.version ~= version then
        local h = a.buffs.highlight
        c = {
            version = version,
            glow   = BuildTypeCurve(h, { 0, 0, 0, 0 }, h.strength),
            border = BuildTypeCurve(h, a.borderColor, 1),
        }
        hlCache[a] = c
    end
    return c.glow, c.border
end

function NP.BuffHighlightStyle(h)
    if h.pulse and (h.style or "glow") == "glow" then return "pulse" end
    return h.style or "glow"
end

function NP.StackStyle(isBuff, f)
    local a = NP.Prof(f).auras
    if isBuff then
        local s = a.buffs and a.buffs.stacks
        if not s or s.sameAsDebuffs ~= false then
            local show = (not s or s.enabled ~= false) and a.stacks and a.stacks.enabled and true or false
            return a.stacks, show
        end
        return s, s.enabled ~= false
    end
    return a.stacks, a.stacks and a.stacks.enabled and true or false
end

local function PlainID(id) return type(id) ~= "nil" and not NP.IsSecret(id) end
local function PlateOf(b)
    local row = b and b:GetParent()
    local holder = row and row:GetParent()
    return holder and holder.owner
end

local function Icon_OnEnter(self)
    local id = self.auraInstanceID
    local f = PlateOf(self)
    if not (f and NP.Prof(f).auras.tooltips and self.unit) or type(id) == "nil" or NP.IsSecret(id) then return end
    _G.GameTooltip:SetOwner(self, "ANCHOR_BOTTOMRIGHT")
    if _G.GameTooltip.SetUnitAuraByAuraInstanceID then
        pcall(_G.GameTooltip.SetUnitAuraByAuraInstanceID, _G.GameTooltip, self.unit, id)
    end
    _G.GameTooltip:Show()
end
local function Icon_OnLeave() _G.GameTooltip:Hide() end

local function CreateIcon(row)
    local b = _G.CreateFrame("Frame", nil, row)
    b:SetMouseClickEnabled(false)
    b:SetScript("OnEnter", Icon_OnEnter)
    b:SetScript("OnLeave", Icon_OnLeave)

    b.border = b:CreateTexture(nil, "BACKGROUND"); b.border:SetAllPoints(); b.border:SetColorTexture(1, 1, 1, 1)
    b.icon = b:CreateTexture(nil, "ARTWORK")
    b.cd = _G.CreateFrame("Cooldown", nil, b, "CooldownFrameTemplate")
    b.cd:SetDrawEdge(false); b.cd:SetDrawBling(false); b.cd.noCooldownCount = true

    b.textFrame = _G.CreateFrame("Frame", nil, b); b.textFrame:SetAllPoints()
    b.textFrame:SetFrameLevel(b.cd:GetFrameLevel() + 2)
    b.count = b.textFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")

    b.hl = _G.CreateFrame("Frame", nil, b); b.hl:SetAllPoints(b)
    b.hl.glow = NP.CreateGlow(b.hl, b, "BACKGROUND", -7)
    b.hl.pulse = b.hl:CreateAnimationGroup(); b.hl.pulse:SetLooping("BOUNCE")
    local an = b.hl.pulse:CreateAnimation("Alpha"); an:SetFromAlpha(1); an:SetToAlpha(0.3); an:SetDuration(0.5)
    b.hl:Hide()

    b.pan = _G.CreateFrame("Frame", nil, b); b.pan:SetAllPoints(b)
    b.pan:SetFrameLevel(b.textFrame:GetFrameLevel() - 1)
    b.pan.glow = NP.CreateGlow(b.pan, b, "BACKGROUND", -7)
    b.pan.pulse = b.pan:CreateAnimationGroup(); b.pan.pulse:SetLooping("BOUNCE")
    local pa = b.pan.pulse:CreateAnimation("Alpha"); pa:SetFromAlpha(1); pa:SetToAlpha(0.3); pa:SetDuration(0.5)
    b.pan:Hide(); b:Hide()
    return b
end

local function SetPandemicFx(b, show)
    local f = PlateOf(b)
    local pc = f and NP.Prof(f).auras.debuffs.pandemic
    if not (show and pc and pc.enabled) then
        b.pan:Hide(); b.pan.pulse:Stop()
        if b.pan.ants then b.pan.ants:Stop() end
        return
    end
    b.pan:Show()
    if pc.style == "glow" then
        if b.pan.ants then b.pan.ants:Stop() end
        b.pan.glow:Setup(pc.color, pc.size or 3, 1, 0)
        b.pan.glow:SetShown(true); b.pan.pulse:Play()
    else
        b.pan.glow:SetShown(false); b.pan.pulse:Stop(); b.pan:SetAlpha(1)
        b.pan.ants = b.pan.ants or NP.CreateAnts(b.pan, b)
        b.pan.ants:Anchor(pc.padding or 0)
        b.pan.ants:Setup(pc.color, pc.thickness or 1, pc.padding or 0, 5, 3, pc.speed or 1)
        b.pan.ants:Start()
    end
end

function NP.ApplyBuffHighlight(b, getColor, version, f)
    local h = NP.Prof(f).auras.buffs.highlight
    local style = NP.BuffHighlightStyle(h)
    local glowCurve, borderCurve = NP.GetHighlightCurves(version, f)
    local useGlow = (style == "glow" or style == "pulse" or style == "both")
    local useAnts = (style == "ants")
    local useBorder = (style == "border" or style == "both")
    local gc = (useGlow or useAnts) and glowCurve and getColor(glowCurve)
    if gc then
        b.hl:Show(); b.hl.glow:SetShown(useGlow)
        if useGlow then b.hl.glow:SetColor(gc:GetRGBA()) end
        if style == "pulse" then b.hl.pulse:Play() else b.hl.pulse:Stop(); b.hl:SetAlpha(1) end
        if useAnts then
            b.hl.ants = b.hl.ants or NP.CreateAnts(b.hl, b)
            local r, g, bb, a = gc:GetRGBA()
            b.hl.ants:Anchor(h.antsPadding or 1)
            b.hl.ants:Setup({ r, g, bb, a }, h.antsThickness or 1.5, h.antsPadding or 1, 5, 3, h.antsSpeed or 1)
            b.hl.ants:Start()
        elseif b.hl.ants then
            b.hl.ants:Stop()
        end
    else
        b.hl:Hide(); b.hl.pulse:Stop()
        if b.hl.ants then b.hl.ants:Stop() end
    end
    local bc = useBorder and borderCurve and getColor(borderCurve)
    if bc then b.border:SetVertexColor(bc:GetRGBA()) else b.border:SetVertexColor(NP.RGBA(b.defaultBorder)) end
end

local function StyleIcon(b, rowCfg, isCC)
    local f = PlateOf(b)
    local a = NP.Prof(f).auras
    local w, h = rowCfg.width, rowCfg.height
    b:SetSize(w, h)
    local bs = a.borderSize or 1
    b.icon:ClearAllPoints()
    b.icon:SetPoint("TOPLEFT", bs, -bs); b.icon:SetPoint("BOTTOMRIGHT", -bs, bs)
    local ratio = (h - 2 * bs) / max(1, (w - 2 * bs))
    local crop = max(0, (1 - ratio) / 2 * 0.84)
    b.icon:SetTexCoord(0.08, 0.92, 0.08 + crop, 0.92 - crop)
    b.cd:ClearAllPoints(); b.cd:SetAllPoints(b.icon)
    b.cd:SetDrawSwipe(a.swipe); b.cd:SetReverse(a.reverseSwipe)
    local ext = a.timer.externalTimers and true or false
    b.cd.noCooldownCount = (not ext) or nil
    b.cd:SetHideCountdownNumbers(ext or not a.timer.enabled)

    local fs = b.cd.GetCountdownFontString and b.cd:GetCountdownFontString()
    if fs then
        NP.StyleText(fs, { font = a.timer.font or a.font, size = a.timer.size * (w / 26), outline = a.timer.outline, shadow = true, color = a.timer.color })
        NP.SetAnchor(fs, a.timer.anchor, b); b.timerText = fs
    end
    local st, showStacks = NP.StackStyle(rowCfg == a.buffs, f)
    NP.StyleText(b.count, { font = st.font or a.font, size = st.size * (w / 26), outline = st.outline, shadow = true, color = st.color })
    NP.SetAnchor(b.count, st.anchor, b); b.count:SetShown(showStacks and not ext)
    b:SetMouseMotionEnabled(a.tooltips)

    local bc = isCC and rowCfg.borderColor or a.borderColor
    b.border:SetVertexColor(NP.RGBA(bc)); b.defaultBorder = bc
    if rowCfg.highlight then
        b.hl.glow:Setup({ 1, 1, 1, 1 }, rowCfg.highlight.size, 1, 0); b.hl.glow:SetShown(true)
    end
end

local function LayoutRow(row, rowCfg, anchorTo)
    NP.SetAnchor(row, rowCfg.anchor, anchorTo); row:SetSize(1, 1); row.cfg = rowCfg
end

local function PlaceIcon(row, b, i)
    local cfg = row.cfg
    local perRow = cfg.perRow or cfg.max or 10
    local col, line = (i - 1) % perRow, floor((i - 1) / perRow)
    local sp = cfg.spacing or 1
    local x, y = col * (cfg.width + sp), line * (cfg.height + sp)
    b:ClearAllPoints()
    if cfg.grow == "LEFT" then
        b:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -x, y)
    elseif cfg.grow == "CENTER" then
        local count = min(perRow, row.shown or perRow)
        local total = count * cfg.width + (count - 1) * sp
        b:SetPoint("BOTTOMLEFT", row, "BOTTOM", x - total / 2, y)
    else
        b:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x, y)
    end
end

local function GetIcon(row, i)
    local b = row.icons[i]
    if not b then b = CreateIcon(row); row.icons[i] = b; NP.PixelRound(b) end
    if b.styleVersion ~= row.styleVersion then StyleIcon(b, row.cfg, row.isCC); b.styleVersion = row.styleVersion end
    return b
end

local Auras = {}
local styleCounter = 0

function NP.FriendBuffsOn(f)
    local a = NP.Prof(f).auras
    return a.enabled and f.kind == "friendlyplayer" and a.friendBuffs and a.friendBuffs.enabled and true or false
end
function NP.FriendDebuffsOn(f)
    local a = NP.Prof(f).auras
    return a.enabled and f.kind == "friendlyplayer" and a.friendDebuffs and a.friendDebuffs.enabled and true or false
end
function NP.FriendDebuffFilter(a)
    return (a.friendDebuffs and a.friendDebuffs.onlyDispellable) and "HARMFUL|RAID_PLAYER_DISPELLABLE" or "HARMFUL"
end

function Auras:Create(f)
    local holder = _G.CreateFrame("Frame", nil, f); holder:SetAllPoints(f); f.auraHolder = holder
    f.debuffRow       = _G.CreateFrame("Frame", nil, holder); f.debuffRow.icons = {}
    f.buffRow         = _G.CreateFrame("Frame", nil, holder); f.buffRow.icons = {}
    f.ccRow           = _G.CreateFrame("Frame", nil, holder); f.ccRow.icons = {}; f.ccRow.isCC = true
    f.friendRow       = _G.CreateFrame("Frame", nil, holder); f.friendRow.icons = {}
    f.friendDebuffRow = _G.CreateFrame("Frame", nil, holder); f.friendDebuffRow.icons = {}
    holder.owner = f
    f.auraRows = { f.debuffRow, f.buffRow, f.ccRow, f.friendRow, f.friendDebuffRow }
end

local function UseContainers(f)
    return NP.AuraContainers and NP.AuraContainers.available and not f.isPreview
end

function Auras:Layout(f)
    local a = NP.Prof(f).auras
    local friendly = (f.kind == "friendlyplayer" or f.kind == "friendlynpc")
    f.friendAurasOnly = friendly and (a.hideForFriendly or f.cfg.mode == "nameOnly")
    if NP.FriendBuffsOn(f) or NP.FriendDebuffsOn(f) then
        f.aurasDisabled = false; f.friendAurasOnly = true
    else
        f.aurasDisabled = not a.enabled or f.cfg.mode == "nameOnly" or (friendly and a.hideForFriendly)
    end
    f.friendCC = f.kind == "friendlyplayer" and f.cfg.mode ~= "nameOnly" and a.enabled and a.cc and a.cc.enabled and true or false
    if f.friendCC and f.aurasDisabled then f.aurasDisabled = false; f.friendAurasOnly = true end
    if a.timer and a.timer.external then f.aurasDisabled = true; f.friendAurasOnly = false end
    if f.aurasDisabled then f.auraHolder:Hide(); return end

    f.auraHolder:Show()
    f.auraHolder:SetFrameLevel(f.health:GetFrameLevel() + 8)
    styleCounter = styleCounter + 1
    LayoutRow(f.debuffRow, a.debuffs, f.health)
    LayoutRow(f.buffRow, a.buffs, f.health)
    LayoutRow(f.ccRow, a.cc, f.health)
    if a.friendBuffs then
        local to = (f.cfg.mode == "nameOnly") and f.name or f.health
        LayoutRow(f.friendRow, a.friendBuffs, to)
        if a.friendDebuffs then LayoutRow(f.friendDebuffRow, a.friendDebuffs, to) end
    end
    for _, r in ipairs(f.auraRows) do r.styleVersion = styleCounter end
end

local function SafeGet(unit, filter, mx)
    if not GetUnitAuras then return {} end
    local ok, list = pcall(GetUnitAuras, unit, filter, mx, SORT)
    if ok and type(list) == "table" then return list end
    ok, list = pcall(GetUnitAuras, unit, filter, mx)
    return (ok and type(list) == "table") and list or {}
end

local function SortByDuration(list, rowCfg)
    if rowCfg.sort ~= "duration" or #list < 2 then return list end
    for _, aura in ipairs(list) do
        if NP.IsSecret(aura.expirationTime) or type(aura.expirationTime) ~= "number" then return list end
    end
    table.sort(list, function(x, y)
        local ex = x.expirationTime == 0 and math.huge or x.expirationTime
        local ey = y.expirationTime == 0 and math.huge or y.expirationTime
        if ex ~= ey then return ex < ey end
        return (PlainID(x.auraInstanceID) and x.auraInstanceID or 0) < (PlainID(y.auraInstanceID) and y.auraInstanceID or 0)
    end)
    return list
end

local function FillRow(f, row, list, maxCount, opts)
    local unit, n = f.unit, 0
    for _, aura in ipairs(list) do
        if n >= maxCount then break end
        local id = aura.auraInstanceID
        if PlainID(id) then
            n = n + 1
            local b = GetIcon(row, n)
            b.unit, b.auraInstanceID = unit, id
            b.icon:SetTexture(aura.icon)
            local d = GetAuraDuration and GetAuraDuration(unit, id)
            if d and b.cd.SetCooldownFromDurationObject then b.cd:SetCooldownFromDurationObject(d, true) else b.cd:Clear() end
            b.duration = d; b.pandemic = opts and opts.pandemic
            if b.timerText and not b.pandemic then b.timerText:SetTextColor(NP.RGBA(NP.Prof(f).auras.timer.color)) end
            if GetCount then b.count:SetText(GetCount(unit, id, 2)) else b.count:SetText(aura.applications and aura.applications > 1 and aura.applications or "") end
            if opts and opts.buffHighlight and C_UnitAuras.GetAuraDispelTypeColor then
                NP.ApplyBuffHighlight(b, function(curve) return C_UnitAuras.GetAuraDispelTypeColor(unit, id, curve) end, row.styleVersion, f)
            elseif opts and opts.dispelBorder and C_UnitAuras.GetAuraDispelTypeColor then
                local curve = NP.GetDispelCurve()
                local c = curve and C_UnitAuras.GetAuraDispelTypeColor(unit, id, curve)
                if c then b.border:SetVertexColor(c:GetRGBA()) else b.border:SetVertexColor(NP.RGBA(b.defaultBorder)) end
            else
                b.border:SetVertexColor(NP.RGBA(b.defaultBorder))
            end
            b:Show()
        end
    end
    row.shown = n
    for i = 1, n do PlaceIcon(row, row.icons[i], i) end
    for i = n + 1, #row.icons do
        local b = row.icons[i]; b:Hide(); b.unit = nil; b.auraInstanceID = nil; b.duration = nil; b.hl:Hide(); b.hl.pulse:Stop()
    end
end

function Auras:Refresh(f)
    if f.aurasDisabled or not f.active or UseContainers(f) then return end
    local a, unit = NP.Prof(f).auras, f.unit

    if NP.FriendBuffsOn(f) then
        local fb = a.friendBuffs
        FillRow(f, f.friendRow, SortByDuration(SafeGet(unit, "HELPFUL|PLAYER", fb.max + 4), fb), fb.max)
    else FillRow(f, f.friendRow, {}, 0) end

    if NP.FriendDebuffsOn(f) then
        local fd = a.friendDebuffs
        FillRow(f, f.friendDebuffRow, SortByDuration(SafeGet(unit, NP.FriendDebuffFilter(a), fd.max + 4), fd), fd.max, { dispelBorder = true })
    else FillRow(f, f.friendDebuffRow, {}, 0) end

    if f.friendAurasOnly then
        FillRow(f, f.debuffRow, {}, 0); FillRow(f, f.buffRow, {}, 0)
        if f.friendCC then FillRow(f, f.ccRow, SortByDuration(SafeGet(unit, "HARMFUL|CROWD_CONTROL", a.cc.max), a.cc), a.cc.max)
        else FillRow(f, f.ccRow, {}, 0) end
        return
    end

    if a.debuffs.enabled then
        local base = a.debuffs.onlyMine and "HARMFUL|PLAYER" or "HARMFUL"
        local filter = a.debuffs.onlyImportant and (base .. "|IMPORTANT") or base
        local list = SafeGet(unit, filter, a.debuffs.max + 4)
        if a.cc.enabled and IsFilteredOut then
            local filtered = {}
            for _, aura in ipairs(list) do
                local id = aura.auraInstanceID
                if PlainID(id) and NP.Truthy(IsFilteredOut(unit, id, "HARMFUL|CROWD_CONTROL"), true) then filtered[#filtered + 1] = aura end
            end
            list = filtered
        end
        list = SortByDuration(list, a.debuffs)
        FillRow(f, f.debuffRow, list, a.debuffs.max, { pandemic = true, dispelBorder = a.borderByDispelType })
    else FillRow(f, f.debuffRow, {}, 0) end

    if a.buffs.enabled and f.hostile then
        local list, seen = {}, {}
        local function add(flt)
            for _, aura in ipairs(SafeGet(unit, flt, a.buffs.max + 4)) do
                local id = aura.auraInstanceID
                if PlainID(id) and not seen[id] then seen[id] = true; list[#list + 1] = aura end
            end
        end
        if a.buffs.showAll then add("HELPFUL")
        else
            if a.buffs.showDispellable or a.buffs.showEnrage then add("HELPFUL|RAID_PLAYER_DISPELLABLE") end
            if a.buffs.showImportant then add("HELPFUL|IMPORTANT") end
        end
        FillRow(f, f.buffRow, SortByDuration(list, a.buffs), a.buffs.max, { buffHighlight = true })
    else FillRow(f, f.buffRow, {}, 0) end

    if a.cc.enabled then FillRow(f, f.ccRow, SortByDuration(SafeGet(unit, "HARMFUL|CROWD_CONTROL", a.cc.max), a.cc), a.cc.max)
    else FillRow(f, f.ccRow, {}, 0) end
end

local auraPlates, auraAcc = {}, 0
local auraDriver = _G.CreateFrame("Frame"); auraDriver:Hide()
auraDriver:SetScript("OnUpdate", function(self, elapsed)
    auraAcc = auraAcc + elapsed
    if auraAcc < 0.2 then return end
    auraAcc = 0
    if not next(auraPlates) then self:Hide(); return end
    for holder in pairs(auraPlates) do
        local f = holder.owner
        if holder:IsVisible() and f and not f.isPreview then
            if f.dirtyAuras then f.dirtyAuras = false; Auras:Refresh(f) end
            local curve, acurve = NP.GetPandemicCurve(), GetPandemicAlphaCurve()
            local pc = NP.Prof(f).auras.debuffs.pandemic
            for _, b in ipairs(f.debuffRow.icons) do
                if b:IsShown() and b.pandemic and b.duration and b.duration.EvaluateRemainingPercent then
                    if b.timerText and (not pc or pc.colorTimer ~= false) and curve then
                        local c = b.duration:EvaluateRemainingPercent(curve)
                        if c then b.timerText:SetTextColor(c:GetRGBA()) end
                    end
                    if pc and pc.enabled and acurve then
                        if not b.pan:IsShown() then SetPandemicFx(b, true) end
                        local c = b.duration:EvaluateRemainingPercent(acurve)
                        if c then b.pan:SetAlpha(c.a) end
                    end
                elseif b.pan:IsShown() then SetPandemicFx(b, false) end
            end
        end
    end
end)

function Auras:Update(f)
    f.hostile = NP.Truthy(_G.UnitCanAttack("player", f.unit), false)
    if NP.DebuffColors then NP.DebuffColors.Update(f) end
    local on = not f.aurasDisabled and not UseContainers(f) and not f.isPreview
    auraPlates[f.auraHolder] = on or nil
    if on then auraDriver:Show() end
    if UseContainers(f) and not f.aurasDisabled then NP.AuraContainers.Update(f); return end
    self:Refresh(f)
end

function Auras:Clear(f)
    auraPlates[f.auraHolder] = nil
    if NP.DebuffColors then NP.DebuffColors.Clear(f) end
    if NP.AuraContainers and NP.AuraContainers.available then NP.AuraContainers.Clear(f) end
    for _, row in ipairs(f.auraRows) do
        for _, b in ipairs(row.icons) do b:Hide(); b.unit = nil; b.auraInstanceID = nil; b.duration = nil end
    end
end
function Auras:OnAura(f) f.dirtyAuras = true end
function Auras:WantsEvent(f) return not f.aurasDisabled and not UseContainers(f) end
Auras.unitEvents = { UNIT_AURA = "OnAura" }

local PREVIEW_ICONS = {
    debuffs       = { "Interface\\Icons\\Spell_Shadow_ShadowWordPain", "Interface\\Icons\\Spell_Fire_FlameBolt", "Interface\\Icons\\Spell_Frost_FrostBolt02" },
    buffs         = { "Interface\\Icons\\Spell_Holy_PowerWordShield", "Interface\\Icons\\Ability_Druid_Enrage" },
    cc            = { "Interface\\Icons\\Spell_Nature_Polymorph" },
    friendDebuffs = { "Interface\\Icons\\Spell_Shadow_ShadowWordPain" },
    friendBuffs   = { "Interface\\Icons\\Spell_Nature_Rejuvenation", "Interface\\Icons\\Spell_Holy_Renew" },
}

local function PreviewRow(f, row, cfg, icons, count)
    if not cfg.enabled then count = 0 end
    count = min(count, cfg.max or count); row.shown = count
    for i = 1, count do
        local b = GetIcon(row, i)
        b.unit, b.auraInstanceID, b.duration = nil, nil, nil
        b.icon:SetTexture(icons[(i - 1) % #icons + 1])
        b.cd:SetCooldown(_G.GetTime() - 4 * i, 12 + 6 * i)
        b.count:SetText((i == 1 and row == f.debuffRow) and "2" or "")
        if b.timerText then b.timerText:SetTextColor(NP.RGBA(NP.Prof(f).auras.timer.color)) end
        b.hl:Hide(); b.hl.pulse:Stop()
        local pan = (row == f.debuffRow and i == 2)
        SetPandemicFx(b, pan)
        if pan and b.timerText and NP.Prof(f).auras.debuffs.pandemic.colorTimer then b.timerText:SetTextColor(1, 0.25, 0.25, 1) end
        if row == f.buffRow then
            local h = NP.Prof(f).auras.buffs.highlight
            local kind = (i % 2 == 1) and h.purge or h.enrage
            local sample = { GetRGBA = function() local r, g, bb, al = NP.RGBA(kind.color); return r, g, bb, al * (h.strength or 1) end }
            NP.ApplyBuffHighlight(b, function() return sample end, row.styleVersion, f)
        end
        PlaceIcon(row, b, i); b:Show()
    end
    for i = count + 1, #row.icons do row.icons[i]:Hide() end
end

function Auras:Preview(f)
    if f.aurasDisabled then return end
    local a = NP.Prof(f).auras
    if f.friendAurasOnly then
        PreviewRow(f, f.debuffRow, a.debuffs, PREVIEW_ICONS.debuffs, 0)
        PreviewRow(f, f.buffRow, a.buffs, PREVIEW_ICONS.buffs, 0)
        PreviewRow(f, f.ccRow, a.cc, PREVIEW_ICONS.cc, f.friendCC and 1 or 0)
        PreviewRow(f, f.friendRow, a.friendBuffs, PREVIEW_ICONS.friendBuffs, NP.FriendBuffsOn(f) and 2 or 0)
        PreviewRow(f, f.friendDebuffRow, a.friendDebuffs, PREVIEW_ICONS.friendDebuffs, NP.FriendDebuffsOn(f) and 1 or 0)
        return
    end
    PreviewRow(f, f.debuffRow, a.debuffs, PREVIEW_ICONS.debuffs, 3)
    PreviewRow(f, f.buffRow, a.buffs, PREVIEW_ICONS.buffs, (f.azSelected == "buffs") and 2 or 0)
    PreviewRow(f, f.ccRow, a.cc, PREVIEW_ICONS.cc, (f.azSelected == "cc") and 1 or 0)
    PreviewRow(f, f.friendRow, a.friendBuffs, PREVIEW_ICONS.friendBuffs, 0)
    PreviewRow(f, f.friendDebuffRow, a.friendDebuffs, PREVIEW_ICONS.friendDebuffs, 0)
end

NP.RegisterElement("Auras", Auras)
