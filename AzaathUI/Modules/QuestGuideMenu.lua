--[[----------------------------------------------------------------------------
    AzaathUI - Modules/QuestGuideMenu.lua
    Painel Loremaster (substitui a antiga central de guias Tryhard/Rush):
      * à esquerda, um cartão por zona (nível, progresso, disponíveis/ativas),
        com filtros de região e de situação e busca pelo nome;
      * à direita, as missões da zona escolhida com filtros de situação;
        clique guia até a missão (ou o doador), botão direito mostra no mapa.
    Dados: Modules/QuestDB.lua (Data/Quests/QuestDB.lua, filtrado para o
    personagem) e a faixa de nível de MapChrome.MapLevels.
    Arte: a mesma do painel do AzaathUI e do Olho (Azaath.ConfigUI + Skin do Olho).
    Comandos: /lore, /azguia, /azroute (e a barra de zona acima do rastreador).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("QuestGuideMenu")

local _G = _G
local ipairs, pairs, pcall, type = ipairs, pairs, pcall, type
local floor, ceil, max, min, format = math.floor, math.ceil, math.max, math.min, string.format

local W, H = 1060, 660
local MARGIN, TOP, BOTTOM, GAP = 20, 92, 20, 12
local LEFT_W = 640
local COLS, ZCARD_H, ZGAP = 3, 96, 10
local QROW_H = 40
local MEDIA = "Interface\\AddOns\\AzaathUI\\Media\\"
local UIM = MEDIA .. "MapUI\\"
local EK, KAL = 1415, 1414

local GREEN = { 0.45, 0.86, 0.42 }
local BLUE  = { 0.45, 0.80, 0.95 }

local U, K, C
local win, pageW, pageH
local zones, totals = {}, {}
local zoneCards, questRows, chips = {}, {}, {}
local st = { region = "all", zfilter = "all", search = "", zone = nil, qfilter = "open", zoff = 0, qoff = 0 }
local L = {}            -- referências da interface (detalhe, grade, textos)

local function Safe(fn, ...)
    if not fn then return end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end
local function Up(s) return Azaath.Upper and Azaath.Upper(s) or s:upper() end

local STATUS = {
    available = { label = "Disponível",   col = function() return C.accent end },
    active    = { label = "Em andamento", col = function() return BLUE end },
    locked    = { label = "Bloqueada",    col = function() return C.off end },
    completed = { label = "Concluída",    col = function() return GREEN end },
}

--------------------------------------------------------------------------------
-- Dados
--------------------------------------------------------------------------------
local function Continent(id)
    local info = Safe(C_Map.GetMapInfo, id)
    for _ = 1, 6 do
        if not (info and info.parentMapID and info.parentMapID > 0) then break end
        if info.parentMapID == EK or info.parentMapID == KAL then return info.parentMapID end
        info = Safe(C_Map.GetMapInfo, info.parentMapID)
    end
    return 0
end

-- conquistas de Loremaster do jogo (por facção): continente e a geral
local ACH_IDS = { Alliance = { [EK] = 1676, [KAL] = 1678, all = 1681 }, Horde = { [EK] = 1677, [KAL] = 1680, all = 1682 } }
local ach = {}
local function ReadAchievement(id)
    if not (id and GetAchievementInfo) then return end
    local ok, aid, name, _, completed = pcall(GetAchievementInfo, id)
    if not (ok and aid and name) then return end
    local a = { name = name, done = completed and true or false, crit = {}, q = 0, req = 0 }
    local okN, n = pcall(GetAchievementNumCriteria, id)
    n = okN and n or 0
    for i = 1, n do
        local okC, s, _, cdone, qty, req = pcall(GetAchievementCriteriaInfo, id, i)
        if okC then
            if n == 1 then
                a.q, a.req = qty or 0, req or 0            -- "complete N missões no continente"
            else
                a.req = a.req + 1                          -- um critério por zona
                if cdone then a.q = a.q + 1 end
                if s and s ~= "" then a.crit[#a.crit + 1] = { s = s:lower(), done = cdone, q = qty, req = req } end
            end
        end
    end
    if a.done and a.req > 0 then a.q = a.req end
    return a
end
local function ReadAchievements()
    local ids = ACH_IDS[UnitFactionGroup("player") or ""] or {}
    ach = { [EK] = ReadAchievement(ids[EK]), [KAL] = ReadAchievement(ids[KAL]), all = ReadAchievement(ids.all) }
end
-- critério da conquista que cita a zona (conquista com um critério por zona)
local function ZoneCriterion(z)
    local a = ach[z.cont]
    if not a then return end
    local nm = z.name:lower()
    for _, c in ipairs(a.crit) do
        if c.s:find(nm, 1, true) then return c end
    end
end

local function Collect()
    local qdb = Azaath:GetModule("QuestDB")
    local ch = Azaath:GetModule("MapChrome")
    zones = {}
    totals = { total = 0, completed = 0, done = 0 }
    ReadAchievements()
    if not (qdb and qdb.GetZoneIDs) then return end
    for _, id in ipairs(qdb:GetZoneIDs()) do
        -- negativos (QuestDB): -1 = diversas; -areaID = masmorra/área sem mapa próprio
        local name, cont
        if id == (qdb.MISC_ZONE or -1) then
            name, cont = "Diversas", "misc"
        elseif id < 0 then
            name, cont = Safe(C_Map.GetAreaInfo, -id) or ("Área " .. -id), "dungeon"
        else
            local info = Safe(C_Map.GetMapInfo, id)
            name, cont = info and info.name, Continent(id)
        end
        if name and name ~= "" then
            local list, counts = qdb:GetZoneQuests(id)
            if counts.total > 0 then
                local lo, hi
                if id > 0 and ch and ch.MapLevels then lo, hi = ch.MapLevels(id) end
                if not lo then
                    -- sem faixa (masmorra, diversas): a das próprias missões
                    for _, it in ipairs(list) do
                        local l = it.quest.level or 0
                        if l > 0 then lo, hi = min(lo or l, l), max(hi or l, l) end
                    end
                end
                zones[#zones + 1] = { id = id, name = name, cont = cont, lo = lo, hi = hi or lo,
                    counts = counts, list = list }
                totals.total = totals.total + counts.total
                totals.completed = totals.completed + counts.completed
                if counts.completed >= counts.total then totals.done = totals.done + 1 end
            end
        end
    end
    table.sort(zones, function(a, b)
        local la, lb = a.lo or 99, b.lo or 99
        if la ~= lb then return la < lb end
        return a.name < b.name
    end)
end

local function ZoneByID(id)
    for _, z in ipairs(zones) do if z.id == id then return z end end
end

-- a zona do jogador (sobe pelos mapas-pai até achar uma da lista)
local function PlayerZone()
    local id = Safe(C_Map.GetBestMapForUnit, "player")
    for _ = 1, 6 do
        if not id then return end
        if ZoneByID(id) then return id end
        local info = Safe(C_Map.GetMapInfo, id)
        id = info and info.parentMapID
    end
end

local function ZoneVisible(z)
    if st.region == "ek" and z.cont ~= EK then return false end
    if st.region == "kal" and z.cont ~= KAL then return false end
    if st.region == "dungeon" and z.cont ~= "dungeon" then return false end
    if st.region == "other" and (z.cont == EK or z.cont == KAL or z.cont == "dungeon") then return false end
    local c = z.counts
    if st.zfilter == "open" and c.completed >= c.total then return false end
    if st.zfilter == "done" and c.completed < c.total then return false end
    if st.zfilter == "mine" then
        local me = UnitLevel("player") or 1
        if not z.lo or me < z.lo - 3 or me > (z.hi or z.lo) + 2 then return false end
    end
    if st.search ~= "" and not z.name:lower():find(st.search, 1, true) then return false end
    return true
end

local function QuestVisible(item)
    local s = item.status
    if st.qfilter == "open" then return s == "available" or s == "active" end
    if st.qfilter == "all" then return true end
    -- "Feitas" inclui as repetíveis já entregues (o jogo nunca as marca como concluídas;
    -- continuam também em Abertas/Disponíveis, porque dá para fazer de novo)
    if st.qfilter == "completed" and item.quest.repeatable then
        local qdb = Azaath:GetModule("QuestDB")
        if qdb and qdb.RepeatDoneCount and qdb:RepeatDoneCount(item.quest.id) > 0 then return true end
    end
    return s == st.qfilter
end

--------------------------------------------------------------------------------
-- Ações
--------------------------------------------------------------------------------
local function GiverPos(q)
    if q.sMap and q.sMap > 0 and q.sX and q.sX > 0 and q.sY and q.sY > 0 then return q.sMap, q.sX, q.sY end
    if q.eMap and q.eMap > 0 and q.eX and q.eX > 0 and q.eY and q.eY > 0 then return q.eMap, q.eX, q.eY end
end

-- porta da masmorra de um cartão de masmorra (zona -areaID): zona, x, y (0-100), nome
local function Door(z)
    if not (z and z.id < -1) then return end
    local wm = Azaath:GetModule("WorldMap")
    if wm and wm.api and wm.api.DungeonDoor then return wm.api.DungeonDoor(-z.id) end
end

-- clique: guia até a missão (ativa) ou até quem a entrega (disponível); missão de masmorra
-- em andamento (ou sem doador conhecido) guia até a porta da masmorra
local function GuideTo(item, z)
    local q = item.quest
    local qn = Azaath:GetModule("QuestNav")
    if not qn then return end
    local dm, dx, dy, dname = Door(z)
    if item.status == "active" then
        if dm and qn.SetCustomWaypoint then
            qn:SetCustomWaypoint(dm, dx, dy, dname or item.title)
        elseif qn.SetFocusedQuest then
            qn:SetFocusedQuest(q.id)
        end
        return
    end
    local m, x, y = GiverPos(q)
    if m and qn.SetCustomWaypoint then
        qn:SetCustomWaypoint(m, x, y, item.title)
    elseif dm and qn.SetCustomWaypoint then
        qn:SetCustomWaypoint(dm, dx, dy, dname or item.title)
    elseif qn.SetFocusedQuest then
        qn:SetFocusedQuest(q.id)
    end
end

local function ShowOnMap(mapID, x, y, qid, label)
    local wm = Azaath:GetModule("WorldMap")
    if not (wm and wm.Open and mapID and mapID > 0) then return end   -- masmorra/diversas: sem mapa
    wm:Open(mapID)
    if x and wm.api and wm.api.FocusMapXY then wm.api.FocusMapXY(mapID, x, y, qid, label) end
end

--------------------------------------------------------------------------------
-- Peças
--------------------------------------------------------------------------------
local function Chip(parent, label, width, onClick)
    local b = U.Button(parent, label, width, function() onClick(); M:Refresh() end)
    b:SetHeight(24)
    function b:SetOn(on)
        local bc = on and C.accent or C.gold
        self:SetBackdropBorderColor(bc[1], bc[2], bc[3], on and 1 or 0.4)
        local t = on and { 1, 1, 1 } or C.cream
        self.text:SetTextColor(t[1], t[2], t[3])
    end
    b:HookScript("OnLeave", function(self) self:SetOn(self.isOn) end)
    chips[#chips + 1] = b
    return b
end

local function Bar(parent, width, height)
    local bar = CreateFrame("Frame", nil, parent)
    bar:SetSize(width, height)
    local bg = bar:CreateTexture(nil, "ARTWORK")
    bg:SetTexture(Azaath.media.blank)
    bg:SetAllPoints()
    bg:SetVertexColor(0, 0, 0, 0.6)
    local fill = bar:CreateTexture(nil, "ARTWORK", nil, 1)
    fill:SetTexture(Azaath.media.blank)
    fill:SetPoint("TOPLEFT"); fill:SetPoint("BOTTOMLEFT")
    function bar:Set(p, col)
        fill:SetWidth(max(0.5, (self:GetWidth() or width) * min(1, max(0, p))))
        fill:SetVertexColor(col[1], col[2], col[3], 0.9)
    end
    return bar
end

local function Icon(parent, path, size, col)
    local t = parent:CreateTexture(nil, "OVERLAY")
    t:SetTexture(path)
    t:SetSize(size, size)
    if col then t:SetVertexColor(col[1], col[2], col[3]) end
    return t
end

--------------------------------------------------------------------------------
-- Grade de zonas
--------------------------------------------------------------------------------
local function ZoneCard(parent, w)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, ZCARD_H)
    U.Box(b, C.card, 0.9, C.gold, 0.22)
    U.CardCorners(b, 0.6, 12)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(Azaath.media.blank)
    hl:SetAllPoints()
    hl:SetVertexColor(1, 1, 1, 0.05)
    b.name = K.Text(b, 12, C.cream, "title")
    b.name:SetPoint("TOPLEFT", 12, -12); b.name:SetPoint("RIGHT", -44, 0)
    b.name:SetWordWrap(false)
    b.here = Icon(b, UIM .. "Pin", 14, C.accent)
    b.here:SetPoint("TOPRIGHT", -9, -10)
    b.ach = Icon(b, UIM .. "Check", 14, GREEN)       -- critério da conquista de Loremaster cumprido
    b.ach:SetPoint("TOPRIGHT", -27, -10)
    b.lvl = K.Text(b, 11, C.dim, "bold")
    b.lvl:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -4)
    b.info = K.Text(b, 11, C.dim)
    b.info:SetPoint("TOPLEFT", b.lvl, "BOTTOMLEFT", 0, -3); b.info:SetPoint("RIGHT", -10, 0)
    b.info:SetWordWrap(false)
    b.bar = Bar(b, w - 64, 5)
    b.bar:SetPoint("BOTTOMLEFT", 12, 12)
    b.pct = K.Text(b, 11, C.cream, "bold")
    b.pct:SetPoint("LEFT", b.bar, "RIGHT", 8, 0)
    b:SetScript("OnClick", function(self)
        if not self.zone then return end
        Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        st.zone, st.qoff = self.zone.id, 0
        M:Refresh()
    end)
    return b
end

local function PaintZoneCard(b, z, here)
    b.zone = z
    local c = z.counts
    b.name:SetText(Up(z.name))
    local ch = Azaath:GetModule("MapChrome")
    if z.lo then
        local col = ch and ch.LevelColor and ch.LevelColor(z.lo, z.hi) or C.dim
        b.lvl:SetText("Nível " .. (z.lo == z.hi and z.lo or (z.lo .. " - " .. z.hi)))
        b.lvl:SetTextColor(col[1], col[2], col[3])
    else
        b.lvl:SetText("Nível ?")
        b.lvl:SetTextColor(C.off[1], C.off[2], C.off[3])
    end
    b.info:SetText(format("%d/%d  ·  %d disp.  ·  %d ativas", c.completed, c.total, c.available or 0, c.active or 0))
    local p = c.total > 0 and c.completed / c.total or 0
    b.bar:Set(p, p >= 1 and GREEN or C.accent)
    b.pct:SetText(floor(p * 100 + 0.5) .. "%")
    b.here:SetShown(here)
    local crit = ZoneCriterion(z)
    b.ach:SetShown(crit and crit.done and true or false)
    local sel = st.zone == z.id
    local bc = sel and C.accent or C.gold
    b:SetBackdropBorderColor(bc[1], bc[2], bc[3], sel and 1 or 0.22)
    b:Show()
end

local function RefreshZones()
    local list = {}
    for _, z in ipairs(zones) do if ZoneVisible(z) then list[#list + 1] = z end end
    local rows = ceil(#list / COLS)
    local maxOff = max(0, rows - L.zoneRows)
    st.zoff = min(maxOff, max(0, st.zoff))
    local hereID = L.hereID
    for i, b in ipairs(zoneCards) do
        local z = list[st.zoff * COLS + i]
        if z then PaintZoneCard(b, z, z.id == hereID) else b.zone = nil; b:Hide() end
    end
    L.zoneEmpty:SetShown(#list == 0)
    L.zoneMore:SetText(maxOff > 0 and format("%d zonas  ·  role para ver mais", #list) or format("%d zonas", #list))
end

--------------------------------------------------------------------------------
-- Detalhe da zona
--------------------------------------------------------------------------------
local function QuestRow(parent, w)
    local r = CreateFrame("Button", nil, parent)
    r:SetSize(w, QROW_H)
    r:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetTexture(Azaath.media.blank)
    hl:SetAllPoints()
    hl:SetVertexColor(1, 1, 1, 0.06)
    local line = r:CreateTexture(nil, "ARTWORK")
    line:SetTexture(Azaath.media.blank)
    line:SetHeight(1)
    line:SetPoint("BOTTOMLEFT", 6, 0); line:SetPoint("BOTTOMRIGHT", -6, 0)
    line:SetVertexColor(C.gold[1], C.gold[2], C.gold[3], 0.12)
    r.mark = Icon(r, MEDIA .. "Diamond", 10)
    r.mark:SetPoint("LEFT", 10, 0)
    r.done = Icon(r, UIM .. "Check", 16, GREEN)        -- repetível que você já entregou
    r.done:SetPoint("RIGHT", -10, 0)
    r.title = K.Text(r, 12, C.cream, "bold")
    r.title:SetPoint("TOPLEFT", 28, -5); r.title:SetPoint("RIGHT", -30, 0)
    r.title:SetWordWrap(false)
    r.sub = K.Text(r, 11, C.dim)
    r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -2); r.sub:SetPoint("RIGHT", -10, 0)
    r.sub:SetWordWrap(false)
    r:SetScript("OnClick", function(self, button)
        local item = self.item
        if not item then return end
        Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        local z = ZoneByID(st.zone)
        if IsShiftKeyDown() and item.quest.repeatable then
            local qdb = Azaath:GetModule("QuestDB")
            if qdb and qdb.ToggleRepeatDone then qdb:ToggleRepeatDone(item.quest.id) end
            M:Refresh()
            return
        end
        if button == "RightButton" then
            local m, x, y = GiverPos(item.quest)
            local label = item.title
            if not m then m, x, y, label = Door(z) end
            ShowOnMap(m or st.zone, x, y, item.quest.id, label or item.title)
        else
            GuideTo(item, z)
        end
    end)
    r:SetScript("OnEnter", function(self)
        local item = self.item
        if not item then return end
        local s = STATUS[item.status] or STATUS.locked
        local extra = {}
        if item.status == "available" then extra[#extra + 1] = { "Clique: guiar até quem entrega", 0.6, 0.85, 1 }
        elseif item.status == "active" then extra[#extra + 1] = { "Clique: guiar até a missão", 0.6, 0.85, 1 } end
        extra[#extra + 1] = { "Botão direito: ver no mapa", 0.6, 0.85, 1 }
        if item.quest.repeatable then
            if (self.repeats or 0) > 0 then
                table.insert(extra, 1, { format("Repetível: já entregue %d vez(es)", self.repeats), GREEN[1], GREEN[2], GREEN[3] })
            end
            extra[#extra + 1] = { "Shift+clique: marcar/desmarcar como já feita", 0.6, 0.85, 1 }
        end
        U.Tooltip(self, item.title, s.label .. "  ·  Nível " .. (item.quest.level or 0), extra)
    end)
    r:SetScript("OnLeave", U.HideTip)
    return r
end

local REASON = { level = "nível baixo", prereq = "pré-requisito", skill = "profissão" }

local function RefreshDetail()
    local z = ZoneByID(st.zone)
    local D = L.detail
    for _, b in ipairs(L.qchips) do b.isOn = b.key == st.qfilter; b:SetOn(b.isOn) end
    if not z then
        D.title:SetText("ESCOLHA UMA ZONA")
        D.lvl:SetText("")
        D.prog:SetText("")
        D.bar:Set(0, C.accent)
        for _, r in ipairs(questRows) do r.item = nil; r:Hide() end
        D.empty:SetText("Clique em um cartão de zona para ver as missões.")
        D.empty:Show()
        D.mapBtn:Hide()
        D.ach:SetText("")
        return
    end
    local door = z.id < -1 and Door(z)
    D.mapBtn:SetShown(z.id > 0 or door and true or false)
    D.mapBtn.text:SetText(door and "Ver entrada no mapa" or "Ver zona no mapa")
    -- conquista de Loremaster do jogo: o critério da zona ou, sem ele, o do continente
    local a, crit = ach[z.cont], ZoneCriterion(z)
    if crit then
        D.ach:SetText(crit.done and "|cff73db6bConquista: zona concluída|r"
            or format("Conquista: %d de %d", crit.q or 0, crit.req or 0))
    elseif a and a.req > 0 then
        D.ach:SetText(format("%s: %d de %d%s", a.name, a.q, a.req, a.done and "  |cff73db6b(concluída)|r" or ""))
    else
        D.ach:SetText("")
    end
    local c = z.counts
    D.title:SetText(Up(z.name))
    local ch = Azaath:GetModule("MapChrome")
    if z.lo then
        local col = ch and ch.LevelColor and ch.LevelColor(z.lo, z.hi) or C.dim
        D.lvl:SetText("Nível " .. (z.lo == z.hi and z.lo or (z.lo .. " - " .. z.hi)))
        D.lvl:SetTextColor(col[1], col[2], col[3])
    else
        D.lvl:SetText("")
    end
    local p = c.total > 0 and c.completed / c.total or 0
    D.bar:Set(p, p >= 1 and GREEN or C.accent)
    D.prog:SetText(format("%d%% concluído  ·  %d de %d  ·  %d disponíveis  ·  %d ativas  ·  %d bloqueadas",
        floor(p * 100 + 0.5), c.completed, c.total, c.available or 0, c.active or 0, c.locked or 0))

    local list = {}
    for _, item in ipairs(z.list) do if QuestVisible(item) then list[#list + 1] = item end end
    local maxOff = max(0, #list - #questRows)
    st.qoff = min(maxOff, max(0, st.qoff))
    for i, r in ipairs(questRows) do
        local item = list[st.qoff + i]
        if item then
            local s = STATUS[item.status] or STATUS.locked
            local q = item.quest
            -- repetível: marca e rótulo em azul; ok verde se você já entregou alguma vez
            local rep = q.repeatable and item.status ~= "locked"
            local col = rep and BLUE or s.col()
            local qdb = Azaath:GetModule("QuestDB")
            r.repeats = q.repeatable and qdb and qdb.RepeatDoneCount and qdb:RepeatDoneCount(q.id) or 0
            r.done:SetShown(r.repeats > 0)
            r.item = item
            r.mark:SetVertexColor(col[1], col[2], col[3])
            r.title:SetText(item.title)
            local tc = item.status == "completed" and C.dim or (item.status == "locked" and C.off or C.cream)
            r.title:SetTextColor(tc[1], tc[2], tc[3])
            local sub = format("Nv. %d  ·  |cff%02x%02x%02x%s|r", q.level or 0, floor(col[1] * 255), floor(col[2] * 255), floor(col[3] * 255),
                rep and (item.status == "active" and "Repetível em andamento" or "Repetível") or s.label)
            if item.status == "locked" then
                sub = sub .. "  ·  " .. (item.reason == "level" and format("requer nível %d",
                    (q.minLevel or 0) > 0 and q.minLevel or ((q.level or 0) - 8))
                    or REASON[item.reason] or "pré-requisito")
            elseif q.sX and q.sX > 0 and q.sMap == z.id then
                sub = sub .. format("  ·  %.1f, %.1f", q.sX, q.sY)
            end
            r.sub:SetText(sub)
            r:Show()
        else
            r.item = nil
            r:Hide()
        end
    end
    D.empty:SetText("Nenhuma missão neste filtro.")
    D.empty:SetShown(#list == 0)
    D.more:SetText(maxOff > 0 and format("%d missões  ·  role para ver mais", #list) or format("%d missões", #list))
end

--------------------------------------------------------------------------------
-- Janela
--------------------------------------------------------------------------------
local function Window()
    local f = CreateFrame("Frame", "AzaathLoremaster", UIParent)
    f:SetSize(W, H)
    f:SetPoint("CENTER")
    f:SetFrameStrata("HIGH")
    f:SetToplevel(true)
    f:SetClampedToScreen(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()
    U.Box(f, C.bg, 0.97, C.gold, 0.55)
    U.Chrome(f, 84)
    local emblem = Icon(f, UIM .. "Book", 34, C.accent)
    emblem:SetPoint("TOPLEFT", 20, -16)
    f.title = K.Text(f, 17, C.accent, "title")
    f.title:SetPoint("LEFT", emblem, "RIGHT", 10, 2)
    f.title:SetText("LOREMASTER")
    f.subtitle = K.Text(f, 12, C.dim)
    f.subtitle:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -3)
    f.close = U.IconButton(f, 26, UIM .. "Close", function() f:Hide() end)
    f.close:SetPoint("TOPRIGHT", -14, -14)
    f.close:SetFrameLevel(f:GetFrameLevel() + 40)
    if UISpecialFrames then tinsert(UISpecialFrames, "AzaathLoremaster") end
    return f
end

local function BuildZonesCard(card, w, h)
    K.CardTitle(card, function() return "Zonas" end)
    local x, y = 14, -38
    local function Row(defs, key, width)
        for _, d in ipairs(defs) do
            local b = Chip(card, d[2], width, function() st[key] = d[1]; st.zoff = 0 end)
            b:SetPoint("TOPLEFT", x, y)
            b.key, b.group = d[1], key
            x = x + width + 6
        end
    end
    Row({ { "all", "Todas" }, { "ek", "Reinos do Leste" }, { "kal", "Kalimdor" }, { "dungeon", "Masmorras" },
        { "other", "Outras" } }, "region", 114)
    x, y = 14, -68
    Row({ { "all", "Todas" }, { "mine", "Meu nível" }, { "open", "Incompletas" }, { "done", "Completas" } }, "zfilter", 92)

    -- busca pelo nome
    local box = CreateFrame("EditBox", nil, card)
    box:SetSize(w - x - 14, 24)
    box:SetPoint("TOPLEFT", x + 4, y)
    U.Box(box, C.bg, 0.9, C.gold, 0.35)
    box:SetFont(Azaath.media.font, 12, "")
    box:SetTextColor(C.cream[1], C.cream[2], C.cream[3])
    box:SetAutoFocus(false)
    box:SetTextInsets(24, 6, 0, 0)
    local ic = Icon(box, UIM .. "Search", 12, C.dim)
    ic:SetPoint("LEFT", 7, 0)
    local hint = K.Text(box, 11, C.off)
    hint:SetPoint("LEFT", 24, 0)
    hint:SetText("Buscar zona")
    box:SetScript("OnTextChanged", function(self)
        st.search = (self:GetText() or ""):lower()
        hint:SetShown(st.search == "")
        st.zoff = 0
        RefreshZones()
    end)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)

    -- grade
    local gy = -104
    local cw = floor((w - 28 - (COLS - 1) * ZGAP) / COLS)
    L.zoneRows = max(1, floor((h + gy - 30 + ZGAP) / (ZCARD_H + ZGAP)))
    for i = 1, L.zoneRows * COLS do
        local b = ZoneCard(card, cw)
        local col, row = (i - 1) % COLS, floor((i - 1) / COLS)
        b:SetPoint("TOPLEFT", 14 + col * (cw + ZGAP), gy - row * (ZCARD_H + ZGAP))
        zoneCards[i] = b
    end
    L.zoneEmpty = K.Text(card, 13, C.dim)
    L.zoneEmpty:SetPoint("TOP", card, "TOP", 0, gy - 30)
    L.zoneEmpty:SetText("Nenhuma zona com estes filtros.")
    L.zoneMore = K.Text(card, 11, C.dim)
    L.zoneMore:SetPoint("BOTTOM", card, "BOTTOM", 0, 10)
    card:EnableMouseWheel(true)
    card:SetScript("OnMouseWheel", function(_, d) st.zoff = st.zoff - d; RefreshZones() end)
end

local function BuildDetailCard(card, w, h)
    local D = {}
    L.detail = D
    D.title = K.Text(card, 16, C.accent, "title")
    D.title:SetPoint("TOPLEFT", 16, -16); D.title:SetPoint("RIGHT", -16, 0)
    D.title:SetWordWrap(false)
    D.lvl = K.Text(card, 12, C.dim, "bold")
    D.lvl:SetPoint("TOPLEFT", D.title, "BOTTOMLEFT", 0, -4)
    D.bar = Bar(card, w - 32, 7)
    D.bar:SetPoint("TOPLEFT", 16, -64)
    D.prog = K.Text(card, 11, C.cream)
    D.prog:SetPoint("TOPLEFT", D.bar, "BOTTOMLEFT", 0, -6); D.prog:SetPoint("RIGHT", -16, 0)
    D.prog:SetWordWrap(false)
    D.ach = K.Text(card, 11, C.dim)
    D.ach:SetPoint("TOPLEFT", D.prog, "BOTTOMLEFT", 0, -5); D.ach:SetPoint("RIGHT", -16, 0)
    D.ach:SetWordWrap(false)

    local div = K.Divider(card, w - 32)
    div:SetPoint("TOPLEFT", 16, -112)

    L.qchips = {}
    local defs = { { "open", "Abertas" }, { "available", "Disponíveis" }, { "active", "Ativas" },
        { "locked", "Bloqueadas" }, { "completed", "Feitas" }, { "all", "Todas" } }
    local cw = floor((w - 32 - 2 * 6) / 3)          -- duas linhas de três
    for i, d in ipairs(defs) do
        local b = Chip(card, d[2], cw, function() st.qfilter = d[1]; st.qoff = 0 end)
        b:SetPoint("TOPLEFT", 16 + ((i - 1) % 3) * (cw + 6), -126 - floor((i - 1) / 3) * 28)
        b.key = d[1]
        L.qchips[#L.qchips + 1] = b
    end

    local ly = -190
    local n = max(1, floor((h + ly - 70) / QROW_H))
    for i = 1, n do
        local r = QuestRow(card, w - 24)
        r:SetPoint("TOPLEFT", 12, ly - (i - 1) * QROW_H)
        questRows[i] = r
    end
    D.empty = K.Text(card, 12, C.dim)
    D.empty:SetPoint("TOP", card, "TOP", 0, ly - 20)
    D.empty:SetJustifyH("CENTER")
    D.more = K.Text(card, 11, C.dim)
    D.more:SetPoint("BOTTOMLEFT", 16, 46)

    D.mapBtn = U.Button(card, "Ver zona no mapa", 170, function()
        local z = ZoneByID(st.zone)
        local dm, dx, dy, dname = Door(z)
        if dm then ShowOnMap(dm, dx, dy, nil, dname)
        elseif st.zone then ShowOnMap(st.zone) end
    end, nil, UIM .. "Compass")
    D.mapBtn:SetPoint("BOTTOMRIGHT", -14, 12)
    local hint = K.Text(card, 10, C.off)
    hint:SetPoint("BOTTOMLEFT", 16, 18)
    hint:SetPoint("RIGHT", D.mapBtn, "LEFT", -8, 0)
    hint:SetText("Clique: guiar  ·  Botão direito: ver no mapa")
    hint:SetWordWrap(false)

    card:EnableMouseWheel(true)
    card:SetScript("OnMouseWheel", function(_, d) st.qoff = st.qoff - d * 3; RefreshDetail() end)
end

local function Build()
    if win then return true end
    U = Azaath.ConfigUI
    K = Azaath.OlhoNS and Azaath.OlhoNS.Skin
    if not (U and U.Chrome and K and K.Card) then
        Azaath:Print("Loremaster: arte do painel indisponível.")
        return false
    end
    C = U.C
    win = Window()
    pageW, pageH = W - 2 * MARGIN, H - TOP - BOTTOM
    local left = K.Card(win, LEFT_W, pageH)
    left:SetPoint("TOPLEFT", MARGIN, -TOP)
    BuildZonesCard(left, LEFT_W, pageH)
    local rw = pageW - LEFT_W - GAP
    local right = K.Card(win, rw, pageH)
    right:SetPoint("TOPLEFT", MARGIN + LEFT_W + GAP, -TOP)
    BuildDetailCard(right, rw, pageH)

    -- atualiza sozinho com a janela aberta (missão aceita/entregue)
    local pending = false
    win:SetScript("OnEvent", function()
        if pending then return end
        pending = true
        C_Timer.After(0.5, function()
            pending = false
            if win:IsShown() then Collect(); M:Refresh() end
        end)
    end)
    win:SetScript("OnShow", function(self)
        for _, ev in ipairs({ "QUEST_TURNED_IN", "QUEST_ACCEPTED", "QUEST_REMOVED", "QUEST_LOG_UPDATE" }) do
            Azaath.SafeRegister(self, ev)
        end
    end)
    win:SetScript("OnHide", function(self) self:UnregisterAllEvents() end)
    return true
end

function M:Refresh()
    if not (win and win:IsShown()) then return end
    for _, b in ipairs(chips) do
        if b.group then b.isOn = st[b.group] == b.key; b:SetOn(b.isOn) end
    end
    local sub = format("%d de %d missões concluídas  ·  %d zonas completas",
        totals.completed or 0, totals.total or 0, totals.done or 0)
    local a = ach.all
    if a and a.req > 0 then
        sub = sub .. format("  ·  %s: %d de %d%s", a.name, a.q, a.req, a.done and " (concluída)" or "")
    end
    win.subtitle:SetText(sub)
    RefreshZones()
    RefreshDetail()
end

--------------------------------------------------------------------------------
-- API pública & comandos
--------------------------------------------------------------------------------
function M:Open(zoneID)
    if not Build() then return end
    Collect()
    L.hereID = PlayerZone()
    if zoneID or not ZoneByID(st.zone) then st.zone = zoneID or L.hereID end
    -- abre na página da zona escolhida
    if st.zone then
        local idx, n = nil, 0
        for _, z in ipairs(zones) do
            if ZoneVisible(z) then
                n = n + 1
                if z.id == st.zone then idx = n end
            end
        end
        if idx then st.zoff = floor((idx - 1) / COLS) end
    end
    win:Show()
    M:Refresh()
end

function M:Close()
    if win then win:Hide() end
end

function M:Toggle()
    if win and win:IsShown() then self:Close() else self:Open() end
end

function M:OnInitialize()
    _G.SLASH_AZAATHGUIDE1 = "/lore"
    _G.SLASH_AZAATHGUIDE2 = "/azguia"
    _G.SLASH_AZAATHGUIDE3 = "/azroute"
    _G.SlashCmdList["AZAATHGUIDE"] = function() M:Toggle() end
end
