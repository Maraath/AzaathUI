--[[----------------------------------------------------------------------------
    AzaathUI - Modules/MapLoremaster.lua
    Painel Loremaster por zona no mapa-múndi (Fase 2):
      * Lista TODAS as missões da zona atual filtradas estritamente para a
        facção, raça e classe do personagem (via Modules/QuestDB.lua).
      * Mostra progresso total da zona (concluídas / total + barra %).
      * Filtros rápidos: Abertas (disponíveis+ativas), Disponíveis,
        Bloqueadas e Concluídas.
      * Clicar em uma missão disponível/ativa marca o doador/entregador no
        mapa e foca na navegação (QuestNav).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("MapLoremaster")

local min, max, floor = math.min, math.max, math.floor
local ipairs, format = ipairs, string.format

local CYAN  = { 0.37, 0.89, 0.90 }
local CREAM = { 0.95, 0.92, 0.82 }
local GOLD  = { 0.92, 0.76, 0.36 }
local GREEN = { 0.38, 0.92, 0.58 }
local MUTED = { 0.58, 0.62, 0.64 }

local PANEL_W = 340
local ROW_H   = 46
local MAX_ROWS = 18

local api, C
local U = { rows = {}, filter = "open", offset = 0, lastMap = nil }

local STATUS_INFO = {
    available = { tag = "!",   col = GOLD,  label = "Disponível" },
    active    = { tag = "?",   col = CYAN,  label = "Em andamento" },
    locked    = { tag = "•",   col = MUTED, label = "Bloqueada" },
    completed = { tag = "✓",   col = GREEN, label = "Concluída" },
}

local FILTERS = {
    { key = "open",      text = "Abertas" },
    { key = "available", text = "Disp." },
    { key = "locked",    text = "Bloq." },
    { key = "completed", text = "Feitas" },
}

local function CurrentMapID()
    local S = api and api.S
    if S and S.place and S.place.id and S.place.id ~= api.WORLD then
        return S.place.id, S.place.name
    end
    if _G.C_Map and _G.C_Map.GetBestMapForUnit then
        local ok, id = pcall(_G.C_Map.GetBestMapForUnit, "player")
        if ok and id then
            local info = _G.C_Map.GetMapInfo and _G.C_Map.GetMapInfo(id)
            return id, info and info.name
        end
    end
end

local function FilteredList(list)
    local out = {}
    for _, item in ipairs(list) do
        local st = item.status
        if U.filter == "open" and (st == "available" or st == "active") then
            out[#out + 1] = item
        elseif U.filter == st then
            out[#out + 1] = item
        end
    end
    return out
end

function M:Refresh()
    if not (U.panel and U.panel:IsShown()) then return end
    local qdb = Azaath:GetModule("QuestDB")
    if not qdb then return end

    local mapID, mapName = CurrentMapID()
    if mapID ~= U.lastMap then
        U.lastMap = mapID
        U.offset = 0
    end

    local all, counts = qdb:GetZoneQuests(mapID or 0)
    U.zoneTitle:SetText((mapName or "Zona") .. format("  (%d/%d)", counts.completed, counts.total))

    local pw = (U.panel and U.panel:GetWidth()) or PANEL_W
    local ph = (U.panel and U.panel:GetHeight()) or 610
    local pct = counts.total > 0 and (counts.completed / counts.total) or 0
    U.progFill:SetWidth(max(1, floor((pw - 36) * pct)))
    U.progText:SetText(format("%d%% concluído · %d disp. · %d ativas",
        floor(pct * 100 + 0.5), counts.available, counts.active))

    for _, fb in ipairs(U.filterBtns) do
        local on = fb.key == U.filter
        fb.bg:SetColorTexture(on and 0.16 or 0.06, on and 0.34 or 0.10, on and 0.38 or 0.12, 0.9)
        fb.txt:SetTextColor(on and CYAN[1] or MUTED[1], on and CYAN[2] or MUTED[2], on and CYAN[3] or MUTED[3])
    end

    local visRows = min(MAX_ROWS, max(1, floor((ph - 124) / ROW_H)))
    local shownList = FilteredList(all)
    local maxOff = max(0, #shownList - visRows)
    U.offset = min(maxOff, max(0, U.offset))

    for i = 1, MAX_ROWS do
        local row = U.rows[i]
        local item = (i <= visRows) and shownList[U.offset + i] or nil
        if item then
            local st = STATUS_INFO[item.status] or STATUS_INFO.locked
            local q = item.quest
            local isRep = item.status == "available" and q.repeatable
            local col = isRep and CYAN or st.col
            row.item = item
            row.badge:SetText(st.tag)
            row.badge:SetTextColor(col[1], col[2], col[3])
            row.title:SetText(item.title)
            row.title:SetTextColor(col[1], col[2], col[3])

            local label = isRep and "Repetível" or st.label
            local sub = format("Nv. %d · %s", q.level or 0, label)
            if item.status == "locked" then
                sub = sub .. (item.reason == "level" and format(" (Req. %d)", q.minLevel) or " (Pré-req.)")
            elseif q.sX and q.sX > 0 and q.sY and q.sY > 0 then
                sub = sub .. format(" · (%.1f, %.1f)", q.sX, q.sY)
            end
            row.sub:SetText(sub)
            row:Show()
        else
            row.item = nil
            row:Hide()
        end
    end

    U.empty:SetShown(#shownList == 0)
    if #shownList == 0 then
        U.empty:SetText(counts.total == 0
            and "Nenhuma missão registrada para esta zona."
            or "Nenhuma missão neste filtro.")
    end
end

function M:SetShown(on)
    if not U.panel then return end
    U.panel:SetShown(on)
    if on then self:Refresh() end
end

function M:Build(f, v, mapApi)
    api = mapApi
    C = Azaath:GetModule("MapChrome")
    if not C then return end
    local side = (C.GetSideDock and C.GetSideDock()) or f

    local p = CreateFrame("Frame", nil, side)
    p:SetAllPoints(side)
    p:SetFrameLevel(side:GetFrameLevel() + 2)
    p:EnableMouse(true)
    p:EnableMouseWheel(true)
    p:Hide()

    local hdr = p:CreateFontString(nil, "OVERLAY"); C.Font(hdr, 15)
    hdr:SetPoint("TOPLEFT", 16, -14)
    hdr:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    hdr:SetText("LOREMASTER DA ZONA")
    if C.PanelClose then C.PanelClose(p) end   -- X no canto, como nos outros painéis

    U.zoneTitle = p:CreateFontString(nil, "OVERLAY"); C.Font(U.zoneTitle, 13)
    U.zoneTitle:SetPoint("TOPLEFT", 16, -34)
    U.zoneTitle:SetPoint("RIGHT", -16, 0)
    U.zoneTitle:SetJustifyH("LEFT")
    U.zoneTitle:SetTextColor(CREAM[1], CREAM[2], CREAM[3])

    local progBg = p:CreateTexture(nil, "ARTWORK")
    progBg:SetPoint("TOPLEFT", 16, -54)
    progBg:SetPoint("TOPRIGHT", -16, -54)
    progBg:SetHeight(8)
    progBg:SetColorTexture(0.05, 0.08, 0.10, 0.95)

    U.progFill = p:CreateTexture(nil, "OVERLAY")
    U.progFill:SetPoint("TOPLEFT", progBg, "TOPLEFT", 0, 0)
    U.progFill:SetHeight(8)
    U.progFill:SetColorTexture(GREEN[1], GREEN[2], GREEN[3], 0.9)

    U.progText = p:CreateFontString(nil, "OVERLAY"); C.Font(U.progText, 11)
    U.progText:SetPoint("TOPLEFT", 16, -66)
    U.progText:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

    U.filterBtns = {}
    local fw = floor((PANEL_W - 32 - 12) / #FILTERS)
    for idx, fd in ipairs(FILTERS) do
        local b = CreateFrame("Button", nil, p)
        b:SetSize(fw, 22)
        b:SetPoint("TOPLEFT", 16 + (idx - 1) * (fw + 4), -84)
        b.key = fd.key
        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetAllPoints()
        b.txt = b:CreateFontString(nil, "OVERLAY"); C.Font(b.txt, 11)
        b.txt:SetPoint("CENTER")
        b.txt:SetText(fd.text)
        b:SetScript("OnClick", function()
            U.filter = fd.key
            U.offset = 0
            M:Refresh()
        end)
        U.filterBtns[idx] = b
    end

    for i = 1, MAX_ROWS do
        local row = CreateFrame("Button", nil, p)
        row:SetHeight(ROW_H - 2)
        row:SetPoint("TOPLEFT", 16, -114 - (i - 1) * ROW_H)
        row:SetPoint("RIGHT", -16, 0)

        local bg = row:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints()
        bg:SetColorTexture(0.06, 0.09, 0.11, 0.72)
        row.bg = bg

        row.badge = row:CreateFontString(nil, "OVERLAY"); C.Font(row.badge, 15)
        row.badge:SetPoint("LEFT", 8, 0)
        row.badge:SetWidth(18)
        row.badge:SetJustifyH("CENTER")

        row.title = row:CreateFontString(nil, "OVERLAY"); C.Font(row.title, 12)
        row.title:SetPoint("TOPLEFT", 30, -6)
        row.title:SetWidth(PANEL_W - 70)
        row.title:SetJustifyH("LEFT")
        row.title:SetWordWrap(false)

        row.sub = row:CreateFontString(nil, "OVERLAY"); C.Font(row.sub, 10)
        row.sub:SetPoint("BOTTOMLEFT", 30, 6)
        row.sub:SetWidth(PANEL_W - 70)
        row.sub:SetJustifyH("LEFT")
        row.sub:SetTextColor(MUTED[1], MUTED[2], MUTED[3])

        row:SetScript("OnEnter", function(self)
            self.bg:SetColorTexture(0.12, 0.20, 0.24, 0.88)
        end)
        row:SetScript("OnLeave", function(self)
            self.bg:SetColorTexture(0.06, 0.09, 0.11, 0.72)
        end)
        row:SetScript("OnClick", function(self)
            if not self.item then return end
            local q = self.item.quest
            local qn = Azaath:GetModule("QuestNav")
            if qn and qn.SetFocusedQuest then qn:SetFocusedQuest(q.id, true) end
            local tm, tx, ty
            if q.sMap and q.sMap > 0 and q.sX and q.sX > 0 and q.sY and q.sY > 0 then
                tm, tx, ty = q.sMap, q.sX, q.sY
            elseif q.eMap and q.eMap > 0 and q.eX and q.eX > 0 and q.eY and q.eY > 0 then
                tm, tx, ty = q.eMap, q.eX, q.eY
            end
            if tm and tx and ty then
                if _G.C_Map and _G.C_Map.SetUserWaypoint and _G.UiMapPoint then
                    local pt = _G.UiMapPoint.CreateFromCoordinates(tm, tx / 100, ty / 100)
                    if pt then
                        pcall(_G.C_Map.SetUserWaypoint, pt)
                        if _G.C_SuperTrack and _G.C_SuperTrack.SetSuperTrackedUserWaypoint then
                            pcall(_G.C_SuperTrack.SetSuperTrackedUserWaypoint, true)
                        end
                    end
                end
                if api and api.FocusMapXY then
                    api.FocusMapXY(tm, tx, ty, q.id)
                end
            elseif api and api.FocusQuest then
                api.FocusQuest(q.id)
            end
        end)

        row:Hide()
        U.rows[i] = row
    end

    U.empty = p:CreateFontString(nil, "OVERLAY"); C.Font(U.empty, 12)
    U.empty:SetPoint("CENTER", 0, -40)
    U.empty:SetWidth(PANEL_W - 48)
    U.empty:SetTextColor(MUTED[1], MUTED[2], MUTED[3])
    U.empty:Hide()

    p:SetScript("OnMouseWheel", function(_, delta)
        U.offset = max(0, U.offset - delta * 2)
        M:Refresh()
    end)

    U.panel = p
    side:HookScript("OnSizeChanged", function() if p:IsShown() then M:Refresh() end end)
end
