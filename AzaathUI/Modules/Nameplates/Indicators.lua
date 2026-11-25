--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Indicators.lua
    Marcadores e ícones: RaidMark, Quest + Progresso, Elite/Raro, Classe,
    Facção, Tipo de Unidade, Idle, Texto de Ameaça %, SoftTarget e Ícones de
    Utilidade/Quest preservados para NPCs amigáveis.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, tonumber, type = pairs, ipairs, pcall, tonumber, type
local max, min = math.max, math.min

local TEX = NP.MEDIA
local PIN_TEX = "Interface\\AddOns\\AzaathUI\\Media\\MapFrame\\"
local Indicators = {}

function Indicators:Create(f)
    local fr = _G.CreateFrame("Frame", nil, f)
    fr:SetAllPoints(f)
    f.indicatorFrame = fr

    f.raidMark = fr:CreateTexture(nil, "OVERLAY"); f.raidMark:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons"); f.raidMark:Hide()
    f.questIcon = fr:CreateTexture(nil, "OVERLAY"); f.questIcon:SetTexture(TEX .. "quest-exclamation.png"); f.questIcon:Hide()
    f.questProgress = fr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.questProgress:SetWordWrap(false); f.questProgress:Hide()
    f.eliteIcon = fr:CreateTexture(nil, "OVERLAY"); f.eliteIcon:Hide()
    f.factionIcon = fr:CreateTexture(nil, "OVERLAY"); f.factionIcon:Hide()
    f.classIcon = fr:CreateTexture(nil, "OVERLAY"); f.classIcon:Hide()
    f.classBorder = fr:CreateTexture(nil, "ARTWORK"); f.classBorder:SetPoint("CENTER", f.classIcon, "CENTER"); f.classBorder:Hide()
    f.typeIcon = fr:CreateTexture(nil, "OVERLAY"); f.typeIcon:Hide()
    f.idleIcon = fr:CreateTexture(nil, "OVERLAY"); f.idleIcon:SetTexture(TEX .. "type-idle.png"); f.idleIcon:Hide()
    f.softIcon = fr:CreateTexture(nil, "OVERLAY"); f.softIcon:Hide()
    f.threatText = fr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.threatText:SetWordWrap(false); f.threatText:Hide()
    f.threatLead = fr:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall"); f.threatLead:SetWordWrap(false); f.threatLead:Hide()

    -- Ícone de utilidade para NPCs amigáveis (moldura discreta ou pino de missão do AzaathUI)
    local sf = _G.CreateFrame("Frame", nil, fr)
    sf.bg = sf:CreateTexture(nil, "BACKGROUND"); sf.bg:SetAllPoints(); sf.bg:SetColorTexture(0, 0, 0, 0.65)
    sf.border = NP.CreateBorder(sf, "BORDER", 1); sf.border:SetBorderSize(1); sf.border:SetBorderColor(0.35, 0.32, 0.28, 0.9)
    sf.icon = sf:CreateTexture(nil, "ARTWORK"); sf.icon:SetPoint("TOPLEFT", 1, -1); sf.icon:SetPoint("BOTTOMRIGHT", -1, 1)
    sf:Hide()
    f.serviceFrame = sf
    f.serviceIcon = sf -- compatibilidade com Depth.lua e âncoras
end

-- Ícone de utilidade para NPCs amigáveis (mantém todos os ícones de serviço + pinos de quest do AzaathUI)
function NP.UpdateServiceIcon(f)
    if not f.active or not f.serviceFrame then return end
    local cfg = f.cfg.serviceIcon
    local sf = f.serviceFrame
    local want = (NP.db.general.utilityNPCs ~= false) and (cfg and cfg.enabled ~= false) and f.kind == "friendlynpc" and f.unit
    local util = want and NP.DetectNPCUtility and NP.DetectNPCUtility(f.unit) or nil
    if util and util.icon then
        local wm = util.pin and Azaath:GetModule("WorldMap")
        local pin = util.pin and not (wm and wm.db and wm.db.blizzQuestPins) and NP.NPC_QUEST_PIN[util.pin]
        if pin then
            sf.icon:SetTexture(PIN_TEX .. pin[1])
            sf.icon:SetTexCoord(0, 1, 0, 1)
            sf.bg:Hide(); sf.border:SetShown(false)
        else
            sf.icon:SetTexture(util.icon)
            sf.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            sf.bg:Show(); sf.border:SetShown(true)
        end
        sf:Show()
    else
        sf:Hide()
    end
end

-- Ícone de tipo de unidade (boss / miniboss / caster / elite)
local function SetTypeArt(tex, key, cfg)
    if tex.azArt ~= key then tex.azArt = key; tex:SetTexture(TEX .. "type-" .. key .. ".png") end
    local own = cfg and cfg.ownColors and true or false
    local col = own and cfg.colors and cfg.colors[key] or { 1, 1, 1, 1 }
    if tex.azOwn ~= own then tex.azOwn = own; tex:SetDesaturated(own) end
    tex:SetVertexColor(NP.RGBA(col))
end

function NP.UpdateTypeIcon(f)
    if not f.active or not f.typeIcon then return end
    local cfg = NP.Prof(f).indicators.typeIcon
    local t = f.unitTypeKey
    local key
    if cfg and cfg.enabled and f.kind == "enemynpc" and f.cfg.mode ~= "nameOnly" and (not cfg.instancesOnly or NP.inInstance) then
        if (t == "boss" or t == "miniboss") and cfg[t] then key = t
        elseif cfg.caster and NP.IsCasterHere(f) then key = "caster"
        elseif t == "elite" and cfg.elite then key = "elite" end
    end
    if key then SetTypeArt(f.typeIcon, key, cfg); f.typeIcon:Show() else f.typeIcon:Hide() end
end

-- Ícone de elite/raro
local ELITE_ART = {
    elite = { atlas = "nameplates-icon-elite-gold", file = "Interface\\Tooltips\\EliteNameplateIcon" },
    rare  = { atlas = "nameplates-icon-elite-silver", file = "Interface\\Tooltips\\RareEliteNameplateIcon" },
    star  = { atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star", file = "Interface\\Tooltips\\RareEliteNameplateIcon" },
}
local ELITE_KIND = { elite = "elite", worldboss = "elite", rareelite = "rare", rare = "star" }

local function SetEliteArt(tex, kind, flip)
    local key = flip and (kind .. ":flip") or kind
    if tex.azArt == key then return end
    tex.azArt = key
    local art = ELITE_ART[kind]
    if tex.GetAtlas and tex:GetAtlas() == art.atlas then tex:SetTexture(nil) end
    local ok = tex.SetAtlas and pcall(tex.SetAtlas, tex, art.atlas, false)
    if not ok or (tex.GetAtlas and not tex:GetAtlas()) then
        tex:SetTexture(art.file)
        if flip then tex:SetTexCoord(1, 0, 0, 1) else tex:SetTexCoord(0, 1, 0, 1) end
    elseif flip and tex.GetTexCoord then
        local ulx, uly, llx, lly, urx, ury, lrx, lry = tex:GetTexCoord()
        if lry then tex:SetTexCoord(urx, ury, lrx, lry, ulx, uly, llx, lly) end
    end
end

function NP.UpdateEliteIcon(f)
    if not f.active then return end
    local st = NP.Prof(f).style
    if (st.barStyle == "azaath" or st.barStyle == "azaath_ink") and f.cfg.level and f.cfg.level.enabled and f.cfg.mode ~= "nameOnly" then
        f.eliteIcon:Hide()
        return
    end
    local cfg = f.cfg.eliteIcon
    local c = cfg and cfg.enabled and (f.kind == "enemynpc" or f.kind == "friendlynpc") and _G.UnitClassification(f.unit)
    local kind = c and not NP.IsSecret(c) and ELITE_KIND[c] or nil
    if (kind == "rare" or kind == "star") and cfg and cfg.showRare == false then
        kind = (c == "rareelite") and "elite" or nil
    end
    if kind then SetEliteArt(f.eliteIcon, kind, cfg.flip); f.eliteIcon:Show() else f.eliteIcon:Hide() end
end

-- Facção & Classe
function NP.UpdateFactionIcon(f)
    if not f.active then return end
    local cfg = f.cfg.factionIcon
    local faction = cfg and cfg.enabled and _G.UnitFactionGroup(f.unit)
    if NP.IsSecret(faction) or (faction ~= "Alliance" and faction ~= "Horde") then faction = nil end
    if faction then
        if cfg.style == "game" then
            f.factionIcon:SetTexture("Interface\\TargetingFrame\\UI-PVP-" .. faction)
            f.factionIcon:SetTexCoord(0, 0.625, 0, 0.625)
        else
            f.factionIcon:SetTexture(TEX .. "faction-" .. faction .. ".png")
            f.factionIcon:SetTexCoord(0, 1, 0, 1)
        end
        f.factionIcon:Show()
    else
        f.factionIcon:Hide()
    end
end

local CLASS_COORDS = _G.CLASS_ICON_TCOORDS
function NP.UpdateClassIcon(f)
    if not f.active then return end
    local cfg = f.cfg.classIcon
    local shown = false
    local cls
    if cfg and cfg.enabled and (f.kind == "enemyplayer" or f.kind == "friendlyplayer") then
        cls = select(2, _G.UnitClass(f.unit))
        local tc = cls and not NP.IsSecret(cls) and CLASS_COORDS and CLASS_COORDS[cls]
        if tc then
            f.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            f.classIcon:SetTexCoord(tc[1] + 0.015, tc[2] - 0.015, tc[3] + 0.015, tc[4] - 0.015)
            shown = true
        end
    end
    f.classIcon:SetShown(shown)
    local bStyle = cfg and cfg.border or "none"
    if shown and bStyle ~= "none" then
        local c = (cfg.borderClassColor and NP.ClassColorFromToken(cls)) or cfg.borderColor or { 0, 0, 0, 1 }
        f.classBorder:SetVertexColor(NP.RGBA(c))
        f.classBorder:Show()
    else
        f.classBorder:Hide()
    end
end

-- Texto de ameaça (%)
local THREAT_COLORS = { [0] = { 0.69, 0.69, 0.69, 1 }, { 1, 1, 0.47, 1 }, { 1, 0.6, 0, 1 }, { 1, 0, 0, 1 } }
local GRADIENT = { { 0, 0.2, 0.85, 0.35 }, { 0.5, 1, 0.95, 0.3 }, { 0.8, 1, 0.6, 0 }, { 1, 1, 0.12, 0.1 } }

local function ThreatGradient(t)
    t = max(0, min(1, tonumber(t) or 0))
    for i = 2, #GRADIENT do
        local a, b = GRADIENT[i - 1], GRADIENT[i]
        if t <= b[1] then
            local k = (t - a[1]) / (b[1] - a[1])
            return a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k, a[4] + (b[4] - a[4]) * k, 1
        end
    end
    local z = GRADIENT[#GRADIENT]
    return z[2], z[3], z[4], 1
end

function NP.UpdateThreatText(f)
    if not f.active or not f.threatText then return end
    local cfg = NP.Prof(f).indicators.threatText
    local fs = f.threatText
    if not (cfg and cfg.enabled and f.kind == "enemynpc" and f.cfg.mode ~= "nameOnly") then fs:Hide(); return end
    local isTanking, status, scaled, raw = _G.UnitDetailedThreatSituation("player", f.unit)
    if type(status) == "nil" then fs:Hide(); return end

    if NP.IsSecret(status) or NP.IsSecret(isTanking) or NP.IsSecret(raw) or NP.IsSecret(scaled) then
        fs:SetFormattedText("%.0f%%", scaled)
        if cfg.colorByThreat and _G.GetThreatStatusColor then
            local ok, r, g, b = pcall(_G.GetThreatStatusColor, status)
            if ok and r then fs:SetTextColor(r, g, b, 1) else fs:SetTextColor(NP.RGBA(cfg.color)) end
        else
            fs:SetTextColor(NP.RGBA(cfg.color))
        end
        fs:Show(); return
    end

    local v = (cfg.mode == "scaled") and scaled or raw
    if cfg.mode ~= "scaled" and isTanking and _G.UnitThreatPercentageOfLead then
        local lead = _G.UnitThreatPercentageOfLead("player", f.unit)
        if lead ~= nil and not NP.IsSecret(lead) then v = lead end
    end
    if not v or v == 0 then fs:Hide(); return end
    if v > 999 then v = 999 end
    if cfg.colorByThreat and cfg.colorStyle == "smooth" and not isTanking then
        fs:SetTextColor(ThreatGradient(v / 100))
    elseif cfg.colorByThreat then
        local st = (not isTanking and NP.playerIsTank) and 2 or status
        fs:SetTextColor(NP.RGBA(THREAT_COLORS[st] or THREAT_COLORS[0]))
    else
        fs:SetTextColor(NP.RGBA(cfg.color))
    end
    fs:SetFormattedText("%.0f%%", v)
    fs:Show()
end

function NP.UpdateIdleIcon(f)
    if not f.active or not f.idleIcon then return end
    local cfg = NP.Prof(f).indicators.idleIcon
    f.idleIcon:SetShown(cfg and cfg.enabled and f.cfg.mode ~= "nameOnly" and NP.IdleRuleOn(cfg) and NP.IsIdleMob(f) and true or false)
end

function NP.UpdateSoftIcon(f)
    if not f.active or not f.softIcon then return end
    local on = NP.db and NP.db.general.softTarget and f.isSoftTarget and not f.isTarget and f.unit and _G.SetUnitCursorTexture
    if on then
        local ok, shown = pcall(_G.SetUnitCursorTexture, f.softIcon, f.unit)
        local hasTex = ok and (shown ~= false) and (f.softIcon:GetTexture() ~= nil or (f.softIcon.GetAtlas and f.softIcon:GetAtlas() ~= nil))
        f.softIcon:SetShown(hasTex and true or false)
    else
        f.softIcon:Hide()
    end
end

function NP.UpdateRaidMark(f)
    if not f.active then return end
    local cfg = f.cfg.raidMark or NP.Prof(f).indicators.raidMark
    local idx = cfg.enabled and _G.GetRaidTargetIndex(f.unit)
    if NP.IsSecret(idx) or (idx and idx > 0) then
        f.raidMark:SetSpriteSheetCell(idx, 4, 4)
        f.raidMark:Show()
    else
        f.raidMark:Hide()
    end
end

local QUEST_TEX = { default = TEX .. "quest-exclamation.png", kill = TEX .. "quest-kill.png", item = TEX .. "quest-loot.png" }
function NP.UpdateQuestIcon(f)
    if not f.active then return end
    local ind = NP.Prof(f).indicators
    local isQuest = f.isQuest and f.kind == "enemynpc"
    local tex = QUEST_TEX.default
    if isQuest and ind.quest.byType then
        tex = QUEST_TEX[f.questKind or "default"] or QUEST_TEX.default
    end
    if f.questTex ~= tex then f.questTex = tex; f.questIcon:SetTexture(tex) end
    f.questIcon:SetShown(ind.quest.enabled and isQuest and true or false)
    local qt = ind.questText
    local text = isQuest and qt and qt.enabled and f.questText or nil
    f.questProgress:SetText(text or "")
    f.questProgress:SetShown(text ~= nil)
end

function Indicators:Layout(f)
    local ind = NP.Prof(f).indicators
    f.indicatorFrame:SetFrameLevel(f.health:GetFrameLevel() + 9)
    local anchorTo = (f.cfg.mode == "nameOnly") and f.name or f.health

    local rm = f.cfg.raidMark or ind.raidMark
    local sz = (rm.size or 20) * (rm.scale or 1)
    f.raidMark:SetSize(sz, sz)
    NP.SetAnchor(f.raidMark, rm.anchor, anchorTo)

    f.questIcon:SetSize(ind.quest.size, ind.quest.size)
    NP.SetAnchor(f.questIcon, ind.quest.anchor, anchorTo)
    if ind.questText then
        NP.StyleText(f.questProgress, ind.questText)
        NP.SetAnchor(f.questProgress, ind.questText.anchor, f.questIcon)
    end

    if f.cfg.eliteIcon then
        f.eliteIcon:SetSize(f.cfg.eliteIcon.size * 1.15, f.cfg.eliteIcon.size)
        NP.SetAnchor(f.eliteIcon, f.cfg.eliteIcon.anchor, anchorTo)
    end
    if f.cfg.serviceIcon then
        local sv = f.cfg.serviceIcon
        local s = sv.size or 18
        f.serviceFrame:SetSize(s, s)
        NP.SetAnchor(f.serviceFrame, sv.anchor or { side = 2, x = -4, y = 0 }, f.name)
    end
    if f.cfg.factionIcon then
        f.factionIcon:SetSize(f.cfg.factionIcon.size, f.cfg.factionIcon.size)
        NP.SetAnchor(f.factionIcon, f.cfg.factionIcon.anchor, anchorTo)
    end
    if f.cfg.classIcon then
        local ci = f.cfg.classIcon
        f.classIcon:SetSize(ci.size, ci.size)
        local bs = ci.borderSize or 2
        if ci.border == "solid" then f.classBorder:SetTexture(TEX .. "class-disc.png"); f.classBorder:SetSize(ci.size + 2 * bs, ci.size + 2 * bs)
        elseif ci.border == "soft" then f.classBorder:SetTexture(TEX .. "class-disc-soft.png"); f.classBorder:SetSize((ci.size + 2 * bs) / 0.6, (ci.size + 2 * bs) / 0.6) end
        NP.SetAnchor(f.classIcon, ci.anchor, anchorTo)
    end
    if ind.idleIcon then f.idleIcon:SetSize(ind.idleIcon.size or 18, ind.idleIcon.size or 18); NP.SetAnchor(f.idleIcon, ind.idleIcon.anchor, anchorTo) end
    f.softIcon:SetSize(18, 18); f.softIcon:ClearAllPoints(); f.softIcon:SetPoint("BOTTOM", anchorTo, "TOP", 0, 14)
    if ind.threatText then NP.StyleText(f.threatText, ind.threatText); NP.SetAnchor(f.threatText, ind.threatText.anchor, f.health) end
    if ind.typeIcon then f.typeIcon:SetSize(ind.typeIcon.size or 18, ind.typeIcon.size or 18); NP.SetAnchor(f.typeIcon, ind.typeIcon.anchor, f.health) end
end

function Indicators:Update(f)
    NP.UpdateRaidMark(f)
    NP.UpdateQuestIcon(f)
    NP.UpdateEliteIcon(f)
    NP.UpdateServiceIcon(f)
    NP.UpdateFactionIcon(f)
    NP.UpdateClassIcon(f)
    NP.UpdateTypeIcon(f)
    NP.UpdateThreatText(f)
    NP.UpdateIdleIcon(f)
    NP.UpdateSoftIcon(f)
end

function Indicators:Clear(f)
    f.raidMark:Hide(); f.questIcon:Hide(); f.questProgress:Hide()
    f.eliteIcon:Hide(); f.serviceFrame:Hide(); f.factionIcon:Hide()
    f.classIcon:Hide(); f.classBorder:Hide(); f.typeIcon:Hide()
    f.threatText:Hide(); f.idleIcon:Hide(); f.softIcon:Hide()
end

function Indicators:OnTargetChanged(f) NP.UpdateSoftIcon(f) end

function Indicators:OnRaidMark(f) NP.UpdateRaidMark(f) end
function Indicators:OnThreat(f) NP.UpdateThreatText(f) end
function Indicators:OnClassification(f) NP.UpdateEliteIcon(f) end
Indicators.unitEvents = {
    RAID_TARGET_UPDATE           = "OnRaidMark",
    UNIT_THREAT_LIST_UPDATE      = "OnThreat",
    UNIT_THREAT_SITUATION_UPDATE = "OnThreat",
    UNIT_CLASSIFICATION_CHANGED  = "OnClassification",
}

function Indicators:Preview(f, st)
    Indicators:Clear(f)
    local ind = NP.Prof(f).indicators
    if (f.cfg.raidMark or ind.raidMark).enabled and st.selected == "indicators" then
        f.raidMark:SetSpriteSheetCell(8, 4, 4); f.raidMark:Show()
    end
    if st.quest and f.kind == "enemynpc" and ind.quest.enabled then
        f.questIcon:SetTexture(QUEST_TEX.default); f.questIcon:Show()
        if ind.questText.enabled then f.questProgress:SetText("3/8"); f.questProgress:Show() end
    end
    local isAzBadge = (NP.Prof(f).style.barStyle == "azaath" or NP.Prof(f).style.barStyle == "azaath_ink")
        and f.cfg.level and f.cfg.level.enabled and f.cfg.mode ~= "nameOnly"
    if not isAzBadge and f.cfg.eliteIcon and f.cfg.eliteIcon.enabled and (f.kind == "enemynpc" or f.kind == "friendlynpc") then
        SetEliteArt(f.eliteIcon, "elite", f.cfg.eliteIcon.flip); f.eliteIcon:Show()
    end
    if f.kind == "friendlynpc" and f.cfg.serviceIcon and f.cfg.serviceIcon.enabled then
        f.serviceFrame.icon:SetTexture(NP.UTILITY_ICONS.repair); f.serviceFrame.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        f.serviceFrame.bg:Show(); f.serviceFrame.border:SetShown(true); f.serviceFrame:Show()
    end
    if f.cfg.classIcon and f.cfg.classIcon.enabled and (f.kind == "enemyplayer" or f.kind == "friendlyplayer") then
        local tc = CLASS_COORDS and CLASS_COORDS.MAGE
        if tc then
            f.classIcon:SetTexture("Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES")
            f.classIcon:SetTexCoord(tc[1] + 0.015, tc[2] - 0.015, tc[3] + 0.015, tc[4] - 0.015)
            f.classIcon:Show()
            if (f.cfg.classIcon.border or "none") ~= "none" then
                f.classBorder:SetVertexColor(NP.RGBA(f.cfg.classIcon.borderColor or { 0, 0, 0, 1 })); f.classBorder:Show()
            end
        end
    end
    if f.cfg.factionIcon and f.cfg.factionIcon.enabled then
        f.factionIcon:SetTexture(TEX .. "faction-Alliance.png"); f.factionIcon:SetTexCoord(0, 1, 0, 1); f.factionIcon:Show()
    end
    if ind.typeIcon.enabled and f.kind == "enemynpc" and f.cfg.mode ~= "nameOnly" then
        SetTypeArt(f.typeIcon, st.boss and "boss" or "elite", ind.typeIcon); f.typeIcon:Show()
    end
    if ind.threatText.enabled and f.kind == "enemynpc" and f.cfg.mode ~= "nameOnly" then
        f.threatText:SetText("112%"); f.threatText:SetTextColor(1, 0.85, 0.15, 1); f.threatText:Show()
    end
end

NP.RegisterElement("Indicators", Indicators)
