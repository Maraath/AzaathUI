--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Sheet/PvP.lua
    Ficha do personagem: aba Gladiador (JxJ).
    Símbolos comuns vêm de Azaath.SheetUI (Modules/Sheet/Core.lua).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.SheetUI
local _G, floor, format, ipairs = _G, math.floor, string.format, ipairs
local min, pcall, sin = math.min, pcall, math.sin
local Call, CreateText, DETAIL_W, Display = U.Call, U.CreateText, U.DETAIL_W, U.Display
local INV_MEDIA, MEDIA_ROOT, MakeBar, NewDetail = U.INV_MEDIA, U.MEDIA_ROOT, U.MakeBar, U.NewDetail
local Num, SHEET_MEDIA, SetBar, pages = U.Num, U.SHEET_MEDIA, U.SetBar, U.pages

--------------------------------------------------------------------------------
-- Aba Gladiador (JxJ) — Astrolábio de Guerra & Medalhões Circulares de Honra
--------------------------------------------------------------------------------
local function FrameTexts(f, out)
    if not f then return out end
    local items = {}
    for _, r in ipairs({ f:GetRegions() }) do
        if r.GetText and r:IsShown() then
            local t = r:GetText()
            if t and t ~= "" then items[#items + 1] = { top = r:GetTop() or 0, text = t } end
        end
    end
    for _, kid in ipairs({ f:GetChildren() }) do
        if kid:IsShown() then FrameTexts(kid, items) end
    end
    if out then
        for _, it in ipairs(items) do out[#out + 1] = it end
        return out
    end
    table.sort(items, function(a, b) return a.top > b.top end)
    local texts = {}
    for _, it in ipairs(items) do texts[#texts + 1] = it.text end
    return texts
end

local function RankInfo()
    local prf = _G.PVPRankFrame
    if not prf then return nil end
    if prf.Update then pcall(prf.Update, prf) end
    local main = prf.MainInfoFrame
    local info = {}
    local function txt(region) return region and region.GetText and region:GetText() or nil end
    if main then
        info.season = txt(main.CurrentSeasonField)
        info.rank = txt(main.CurrentRankField)
        info.progress = txt(main.CurrentRankProgressField)
    end
    local detail = prf.DetailFrame
    if detail then
        info.title = txt(detail.Title)
        info.description = table.concat(FrameTexts(detail.Description), "\n")
        info.content = FrameTexts(detail.Content)
    end
    info.timer = prf.SeasonTimerField and txt(prf.SeasonTimerField)
    if info.progress then
        local plain = info.progress:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|cn[%w_]+:", ""):gsub("|r", "")
        local cur, mx = plain:match("(%d+)%s*/%s*(%d+)")
        info.cur, info.max = tonumber(cur), tonumber(mx)
    end
    return info
end

local function BuildPvPPage(page, cw, ch)
    local c, media = Azaath.colors, Azaath.media
    local lw = cw - DETAIL_W - 24
    local pvp = {}
    page.pvp = pvp

    local arenaStage = CreateFrame("Frame", nil, page)
    arenaStage:SetPoint("TOPLEFT", page, "TOPLEFT", 0, 0)
    arenaStage:SetSize(lw, ch)

    pvp.season = CreateText(arenaStage, media.fontTitleB, 12, { 0.96, 0.80, 0.42 }, "CENTER")
    pvp.season:SetPoint("TOP", arenaStage, "TOP", 0, -18)
    pvp.rank = CreateText(arenaStage, media.fontTitleB, 28, { 1, 0.98, 0.92 }, "CENTER")
    pvp.rank:SetPoint("TOP", pvp.season, "BOTTOM", 0, -6)

    local crestAnchor = CreateFrame("Frame", nil, arenaStage)
    crestAnchor:SetSize(190, 190)
    crestAnchor:SetPoint("TOP", pvp.rank, "BOTTOM", 0, -12)

    local warHalo = crestAnchor:CreateTexture(nil, "BACKGROUND")
    warHalo:SetTexture(MEDIA_ROOT .. "CastRingHalo")
    warHalo:SetBlendMode("ADD")
    warHalo:SetSize(230, 230)
    warHalo:SetPoint("CENTER")
    warHalo:SetVertexColor(0.92, 0.26, 0.18, 0.55)

    local warAstro = crestAnchor:CreateTexture(nil, "BORDER")
    warAstro:SetTexture(SHEET_MEDIA .. "AstrolabeRing")
    warAstro:SetBlendMode("ADD")
    warAstro:SetSize(195, 195)
    warAstro:SetPoint("CENTER")
    warAstro:SetVertexColor(0.96, 0.78, 0.42, 0.75)

    local warEdge = crestAnchor:CreateTexture(nil, "ARTWORK", nil, 0)
    warEdge:SetTexture(MEDIA_ROOT .. "CastRingEdge")
    warEdge:SetSize(156, 156)
    warEdge:SetPoint("CENTER")
    warEdge:SetVertexColor(0.38, 0.88, 1.0, 0.65)

    local emblem = crestAnchor:CreateTexture(nil, "ARTWORK", nil, 2)
    emblem:SetSize(110, 110)
    emblem:SetPoint("CENTER", crestAnchor, "CENTER", 0, 0)
    local faction = UnitFactionGroup("player")
    emblem:SetTexture(faction == "Alliance" and "Interface\\TargetingFrame\\UI-PVP-Alliance" or "Interface\\TargetingFrame\\UI-PVP-Horde")
    emblem:SetTexCoord(0, 0.625, 0, 0.625)

    U.vfxNodes[#U.vfxNodes + 1] = function(_, totalT)
        if warAstro.SetRotation then pcall(warAstro.SetRotation, warAstro, totalT * 0.22) end
        if warEdge.SetRotation then pcall(warEdge.SetRotation, warEdge, -totalT * 0.35) end
        warHalo:SetAlpha(0.38 + 0.22 * sin(totalT * 2.2))
    end

    pvp.bar = MakeBar(arenaStage, min(420, lw - 80), 4, 0.90, 0.28, 0.22)
    pvp.bar:SetPoint("TOP", crestAnchor, "BOTTOM", 0, -14)
    pvp.timer = CreateText(arenaStage, media.font, 12, c.dim, "CENTER")
    pvp.timer:SetPoint("TOP", pvp.bar, "BOTTOM", 0, -8)

    -- 6 Medalhões Circulares Flutuantes de Honra (Zero Cards Quadrados!)
    local labels = {
        { title = "ABATES HOJE",      sub = "Diário" },
        { title = "ABATES ONTEM",     sub = "Anterior" },
        { title = "TOTAL DE ABATES",  sub = "Carreira" },
        { title = "HONRA HOJE",       sub = "Diário" },
        { title = "HONRA ONTEM",      sub = "Anterior" },
        { title = "NÍVEL DE HONRA",   sub = "Patente" },
    }
    pvp.rows = {}
    local cols = 3
    local colStep = floor((lw - 60) / cols)
    local startY = 340
    for i, def in ipairs(labels) do
        local col = (i - 1) % cols
        local rIdx = floor((i - 1) / cols)
        local node = CreateFrame("Frame", nil, arenaStage)
        node:SetSize(110, 110)
        node:SetPoint("TOP", arenaStage, "TOPLEFT", 30 + col * colStep + colStep * 0.5, -(startY + rIdx * 124))

        local disc = node:CreateTexture(nil, "BACKGROUND")
        disc:SetSize(78, 78)
        disc:SetPoint("TOP", node, "TOP", 0, -4)
        disc:SetTexture(INV_MEDIA .. "SlotRound")
        disc:SetAlpha(0.85)

        local ring = node:CreateTexture(nil, "BORDER")
        ring:SetSize(84, 84)
        ring:SetPoint("CENTER", disc, "CENTER", 0, 0)
        ring:SetTexture(SHEET_MEDIA .. "RoundSlotFrame")
        ring:SetVertexColor(0.95, 0.80, 0.45, 0.85)

        local v = CreateText(node, media.fontTitleB, 20, { 1, 1, 1 }, "CENTER")
        v:SetPoint("CENTER", disc, "CENTER", 0, 0)

        local t = CreateText(node, media.fontTitleB, 10, { 0.96, 0.82, 0.48 }, "CENTER")
        t:SetPoint("TOP", disc, "BOTTOM", 0, -6)
        t:SetText(def.title)

        pvp.rows[i] = v
    end

    pvp.detail = NewDetail(page, cw - DETAIL_W, 0, DETAIL_W, ch, "Sem dados de ranque de temporada.")
end

local function UpdatePvPPage()
    local pvp = pages.pvp.pvp
    local info = RankInfo()
    if info then
        pvp.season:SetText(Azaath.Tracked(info.season or "TEMPORADA DE ARENA"))
        pvp.rank:SetText(info.rank or "Combatente")
        SetBar(pvp.bar, info.cur or 0, info.max or 1)
        pvp.bar.left:SetText("Pontos de Ranque")
        pvp.bar.right:SetText(info.cur and format("%s / %s", Azaath.Thousands(info.cur), Azaath.Thousands(info.max)) or "")
        pvp.timer:SetText(info.timer or "")
        local contentList = {}
        for _, t in ipairs(info.content or {}) do contentList[#contentList + 1] = t end
        pvp.detail:Set({ title = info.title or info.rank, text = info.description,
                         extra = table.concat(contentList, "\n\n") })
    else
        pvp.season:SetText(Azaath.Tracked("ARENA DE AETERNUM"))
        pvp.rank:SetText("Gladiador")
        pvp.detail:Set(nil)
    end
    local sessionHK, sessionHonor = Call(_G.GetPVPSessionStats)
    local yHK, yHonor = Call(_G.GetPVPYesterdayStats)
    local lifeHK = Call(_G.GetPVPLifetimeStats)
    local honorLevel = Call(_G.UnitHonorLevel, "player")
    local values = { sessionHK, yHK, lifeHK, sessionHonor, yHonor, honorLevel }
    for i, v in ipairs(pvp.rows) do v:SetText(Display(Num(values[i], 0))) end
end

-- compartilhado com os outros arquivos da ficha
U.BuildPvPPage, U.UpdatePvPPage = BuildPvPPage, UpdatePvPPage
