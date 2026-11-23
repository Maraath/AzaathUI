--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Talents/Crucible.lua
    Crisol de talentos: montagem do Crisol.
    Símbolos comuns vêm de Azaath.TalentsUI (Modules/Talents/Core.lua).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.TalentsUI
local ipairs, max, min, random = ipairs, math.max, math.min, math.random
local sqrt, tostring, type, wipe = math.sqrt, tostring, type, wipe
local ApplyNodeVisual, At, CORE_X, CORE_Y = U.ApplyNodeVisual, U.At, U.CORE_X, U.CORE_Y
local CreateNodeButton, Filament, Finalize, MEDIA = U.CreateNodeButton, U.Filament, U.Finalize, U.MEDIA
local PlaceNode, ReadClassicTree, ReadTraitsTree, SUB_COL = U.PlaceNode, U.ReadClassicTree, U.ReadTraitsTree, U.SUB_COL
local TREES, TREE_COLORS, Tex, Text = U.TREES, U.TREE_COLORS, U.Tex, U.Text
local WriteDiag, ambient, nodeButtons, pulses = U.WriteDiag, U.ambient, U.nodeButtons, U.pulses
local segs, traitsInfo = U.segs, U.traitsInfo

--------------------------------------------------------------------------------
-- Montagem do Crisol
--------------------------------------------------------------------------------
local links = {} -- correntes acesas (para os pulsos de luz)

local function Link(pts, style, col, w)
    Filament(pts, style, col, w)
    if style == "lit" then
        local s = 0
        for i, p in ipairs(pts) do
            if i > 1 then s = s + sqrt((p[1] - pts[i - 1][1]) ^ 2 + (p[2] - pts[i - 1][2]) ^ 2) end
            p.s = p.s or s
        end
        links[#links + 1] = { pts = pts, len = pts[#pts].s, col = col }
    end
end

local function NodeStyle(r)
    if r.rank > 0 then return "lit" end
    if r.available or r.tierUnlocked then return "open" end
    return "smoke"
end

-- Como na arte: uma corrente grossa sai do núcleo até o primeiro círculo e dali
-- as correntes se trançam de medalhão em medalhão até o talento final.
local function DrawTree(tabIdx, info)
    local L = TREES[tabIdx]
    local col = TREE_COLORS[tabIdx]
    local dx, dy = L.anchor[1] - CORE_X, L.anchor[2] - CORE_Y
    local d = max(1, sqrt(dx * dx + dy * dy))
    local ctrl = {
        { CORE_X + (dx / d) * 36, CORE_Y + (dy / d) * 36 },
        { L.anchor[1], L.anchor[2] },
    }
    for _, v in ipairs(L.via or {}) do ctrl[#ctrl + 1] = { v[1], v[2] } end
    local hub = info.axis[1]
    ctrl[#ctrl + 1] = { hub[1], hub[2] }
    Link(ctrl, (info.spent > 0) and "lit" or "open", col, 26)

    local minTier = math.huge
    for _, r in ipairs(info.nodes) do minTier = min(minTier, r.tier) end
    for _, r in ipairs(info.nodes) do
        local hasPrereq = false
        for _, pr in ipairs(r.prereqs) do
            if pr.parentKey and U.treeData.byKey[pr.parentKey] then hasPrereq = true end
        end
        if not hasPrereq then
            local fx, fy
            if r.tier == minTier then
                fx, fy = hub[1], hub[2]
            else
                -- vem do medalhão mais próximo do círculo anterior que existir
                local bestTier, best, bd = -1, nil, math.huge
                for _, q in ipairs(info.nodes) do
                    if q.tier < r.tier then
                        local d = (q.cx - r.cx) ^ 2 + (q.cy - r.cy) ^ 2
                        if q.tier > bestTier or (q.tier == bestTier and d < bd) then
                            bestTier, best, bd = q.tier, q, d
                        end
                    end
                end
                if best then fx, fy = best.cx, best.cy end
            end
            if fx and (fx - r.cx) ^ 2 + (fy - r.cy) ^ 2 > 16 then
                Link({ { fx, fy }, { r.cx, r.cy } }, NodeStyle(r), col, 15)
            end
        end
    end

    -- pré-requisitos: corrente mais grossa entre os dois medalhões
    for _, r in ipairs(info.nodes) do
        for _, pr in ipairs(r.prereqs) do
            local p = pr.parentKey and U.treeData.byKey[pr.parentKey]
            if p then
                local style = (pr.ok and r.rank > 0) and "lit" or (pr.ok and "open" or "smoke")
                Link({ { p.cx, p.cy }, { r.cx, r.cy } }, style, col, 19)
            end
        end
    end
end

U.RebuildCrucible = function()
    U.treeData = ReadTraitsTree() or ReadClassicTree()
    if U.treeData and #U.treeData.nodes > 0 then Finalize(U.treeData) end
    WriteDiag()

    for _, b in ipairs(nodeButtons) do b:Hide(); b.rec = nil end
    for i = 1, U.segCount do segs[i].core:Hide() end
    for i = 1, (ambient.dotCount or 0) do ambient.dots[i]:Hide() end
    ambient.dotCount = 0
    U.segCount = 0
    wipe(links)

    if not (U.treeData and #U.treeData.nodes > 0) then
        local d = type(AzaathUIDB) == "table" and AzaathUIDB.talentDiag or {}
        local keys = { "C_ClassTalents.GetActiveConfigID()", "GetNumTalentTabs()", "GetTalentInfo(1,1)" }
        local lines = { "A árvore de talentos não respondeu. Resposta do jogo:" }
        for _, k in ipairs(keys) do
            local v = tostring(d[k] or "-")
            if #v > 70 then v = v:sub(1, 70) .. "..." end
            lines[#lines + 1] = k .. " = " .. v
        end
        lines[#lines + 1] = "C_Traits = " .. tostring(d.C_Traits)
        for _, k in ipairs({ "treeID", "configID", "data", "visibleNodes", "mapped", "read" }) do
            lines[#lines + 1] = "traits." .. k .. " = " .. tostring(traitsInfo[k])
        end
        U.astroF.empty:SetText(table.concat(lines, "\n"))
        U.astroF.empty:Show()
        return
    end
    U.astroF.empty:Hide()

    for t = 1, 3 do
        local info = U.treeData.tabs[t]
        if info and #info.nodes > 0 then DrawTree(t, info) end
    end

    local n = 0
    for t = 1, 3 do
        local info = U.treeData.tabs[t]
        for _, r in ipairs(info and info.nodes or {}) do
            n = n + 1
            local b = nodeButtons[n]
            if not b then
                b = CreateNodeButton()
                nodeButtons[n] = b
            end
            b.rec = r
            b.order = n
            b.cx, b.cy = r.cx, r.cy
            ApplyNodeVisual(b)
            PlaceNode(b)
            b:Show()
        end
    end

    -- seleção válida: a anterior, senão o primeiro talento que pode receber ponto
    if not (U.selKey and U.treeData.byKey[U.selKey]) then
        U.selKey = nil
        for _, r in ipairs(U.treeData.nodes) do
            if r.canBuy then U.selKey = r.key; break end
        end
        if not U.selKey then
            for _, r in ipairs(U.treeData.nodes) do
                if r.rank > 0 then U.selKey = r.key end
            end
        end
        U.selKey = U.selKey or (U.treeData.nodes[1] and U.treeData.nodes[1].key)
    end
    if U.hovKey and not U.treeData.byKey[U.hovKey] then U.hovKey = nil end
end

local function BuildCrucible()
    U.astroF = CreateFrame("Frame", nil, U.art)
    U.astroF:SetAllPoints(U.art)
    U.astroF:SetFrameLevel(U.art:GetFrameLevel() + 4)
    -- sem linhas nativas as correntes viram texturas giradas: sem emenda corrida
    if not U.astroF.CreateLine then U.lineTiling = false end
    U.astroF.empty = Text(U.astroF, Azaath.media.fontCard or Azaath.media.font, 12, SUB_COL, "LEFT")
    U.astroF.empty:SetWidth(470)
    At(U.astroF.empty, U.astroF, 700, 600)
    U.astroF.empty:SetText("A árvore de talentos não respondeu.\nO diagnóstico fica salvo em AzaathUIDB.talentDiag após /reload.")
    U.astroF.empty:Hide()

    -- pulsos de luz que correm pelo eixo aceso de cada árvore
    for i = 1, 9 do
        local t = Tex(U.astroF, "ARTWORK", MEDIA .. "Glow", "ADD", 5)
        t:SetSize(20, 20)
        t:Hide()
        pulses[i] = { tex = t, s = 0, speed = 80 }
    end
end

local function PointAt(pts, s)
    for i = 2, #pts do
        if pts[i].s >= s then
            local a, b = pts[i - 1], pts[i]
            local u = (s - a.s) / max(0.001, b.s - a.s)
            return a[1] + (b[1] - a[1]) * u, a[2] + (b[2] - a[2]) * u
        end
    end
    local p = pts[#pts]
    return p[1], p[2]
end

-- pulsos de luz que correm pelas correntes acesas
local function UpdatePulses(dt)
    for _, p in ipairs(pulses) do
        local lk = p.link
        if not (lk and p.gen == U.segCount) then
            lk = (#links > 0) and links[random(#links)] or nil
            p.link, p.s, p.gen = lk, 0, U.segCount
            p.speed = 60 + random() * 50
        end
        if lk and lk.len > 12 then
            p.s = p.s + p.speed * dt
            if p.s > lk.len then p.link = nil; p.tex:Hide() else
                local x, y = PointAt(lk.pts, p.s)
                local fade = min(1, p.s / 18, (lk.len - p.s) / 18)
                p.tex:SetVertexColor(lk.col[1], lk.col[2], lk.col[3], 1)
                p.tex:SetAlpha(max(0, fade) * 0.9)
                At(p.tex, U.astroF, x, y)
                p.tex:Show()
            end
        else
            p.tex:Hide()
        end
    end
end

-- compartilhado com os outros arquivos de Modules/Talents/
U.BuildCrucible, U.UpdatePulses = BuildCrucible, UpdatePulses
