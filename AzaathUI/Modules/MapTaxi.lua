--[[----------------------------------------------------------------------------
    AzaathUI - Modules/MapTaxi.lua
    Mestre de voo no mapa do Azaath: ao abrir o mapa de voo (TAXIMAP_OPENED), a janela da
    Blizzard (TaxiFrame / FlightMapFrame) vai para um pai oculto e o nosso mapa-múndi abre com os
    pontos de voo por cima. Passar o mouse mostra custo e rota (desenhada no mapa); clique voa.

    Dados do jogo, em tempo real:
      · mapa de voo ...... GetTaxiMapID
      · pontos ........... C_TaxiMap.GetAllTaxiNodes (estado, slot) ou NumTaxiNodes/TaxiNodePosition
      · custo e rota ..... TaxiNodeCost, GetNumRoutes, TaxiGetNodeSlot (ou TaxiGetSrcX/Y, TaxiGetDestX/Y)
      · voar / fechar .... TakeTaxiNode / CloseTaxiMap (nunca HideUIPanel: contamina os painéis)
    Desligar: AzaathUIDB.worldmap.taxiMap = false (volta a janela da Blizzard).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("MapTaxi")

local ipairs, pcall, min, max, abs = ipairs, pcall, math.min, math.max, math.abs

local UI = Azaath.media.path .. "MapUI\\"
local FRAME_TEX = Azaath.media.path .. "MapFrame\\"
local ICON = {
    CURRENT   = "Interface\\TaxiFrame\\UI-Taxi-Icon-Green",
    REACHABLE = "Interface\\TaxiFrame\\UI-Taxi-Icon-White",
    NONE      = "Interface\\TaxiFrame\\UI-Taxi-Icon-Gray",
}
local RIM = { CURRENT = { 0.20, 0.55, 0.25 }, REACHABLE = { 0.35, 0.62, 0.98 }, NONE = { 0.35, 0.35, 0.35 } }
local BLIZZ = { "TaxiFrame", "FlightMapFrame" }

-- active: o nosso mapa está servindo o mestre de voo; byEvent: fechando porque o jogo fechou
local U = { active = false, nodes = {}, bySlot = {}, btns = {}, lines = {}, used = 0 }
local hider = CreateFrame("Frame")
hider:Hide()

local function Safe(fn, ...)
    if not fn then return end
    local ok, a, b, c = pcall(fn, ...)
    if ok then return a, b, c end
end

local function WM() return Azaath:GetModule("WorldMap") end

local function Enabled()
    local wm = WM()
    local db = wm and wm.db
    return db and db.enabled and db.terrain ~= false and db.taxiMap ~= false and wm.api and true or false
end

---------------------------------------------------------------------------
-- Janela da Blizzard: presa num pai oculto enquanto o nosso mapa serve o voo
---------------------------------------------------------------------------
local function Silence(on)
    for _, name in ipairs(BLIZZ) do
        local f = _G[name]
        if f then
            if not f.azaathTaxiHook then
                f.azaathTaxiHook = true
                f.azaathTaxiParent = f:GetParent() or UIParent
                f:HookScript("OnShow", function(self)
                    if U.active and self:GetParent() ~= hider then self:SetParent(hider) end
                end)
            end
            local want = on and hider or f.azaathTaxiParent
            if f:GetParent() ~= want then f:SetParent(want) end
        end
    end
end

---------------------------------------------------------------------------
-- Pontos de voo e conversão para o plano do mapa
---------------------------------------------------------------------------
-- coordenadas 0..1 do mapa de voo -> pixels do plano (nil se o continente não está no plano)
local function Projector(mapID)
    local api = WM().api
    local p = api.Place(mapID)
    if p and p.x1 then
        return function(nx, ny) return p.x0 + nx * (p.x1 - p.x0), p.y0 + ny * (p.y1 - p.y0) end
    end
    if not (C_Map.GetWorldPosFromMapPos and CreateVector2D) then return end
    local i1, a = Safe(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(0, 0))
    local i2, b = Safe(C_Map.GetWorldPosFromMapPos, mapID, CreateVector2D(1, 1))
    if not (i1 and a and b) or i1 ~= i2 then return end
    local top, left = a:GetXY()
    local bottom, right = b:GetXY()
    for _, c in ipairs(api.Conts()) do
        if c.inst == i1 then
            return function(nx, ny)
                local X, Y = top + (bottom - top) * ny, left + (right - left) * nx
                return c.ax + c.bx * Y, c.ay + c.by * X
            end
        end
    end
end

local function StateKind(st)
    local E = _G.Enum and Enum.FlightPathState
    local cur, reach = E and E.Current or 0, E and E.Reachable or 1
    if st == cur then return "CURRENT" end
    if st == reach then return "REACHABLE" end
    return "NONE"
end

local function ReadNodes()
    local list = {}
    local mapID = Safe(_G.GetTaxiMapID)
    local CT = _G.C_TaxiMap
    if CT and CT.GetAllTaxiNodes and mapID then
        for _, n in ipairs(Safe(CT.GetAllTaxiNodes, mapID) or {}) do
            local pos, nx, ny = n.position, nil, nil
            if pos and pos.GetXY then nx, ny = pos:GetXY() elseif pos then nx, ny = pos.x, pos.y end
            if n.slotIndex and nx and ny then
                list[#list + 1] = { slot = n.slotIndex, name = n.name, nx = nx, ny = ny, kind = StateKind(n.state) }
            end
        end
        U.flipY = false
    end
    if #list == 0 and _G.NumTaxiNodes then
        -- API antiga: TaxiNodePosition conta y de baixo para cima
        for i = 1, (Safe(NumTaxiNodes) or 0) do
            local t = Safe(TaxiNodeGetType, i)
            local x, y = Safe(TaxiNodePosition, i)
            if x and y and t ~= "NONE" then
                list[#list + 1] = { slot = i, name = Safe(TaxiNodeName, i), nx = x, ny = 1 - y,
                                    kind = (t == "CURRENT" or t == "REACHABLE") and t or "NONE" }
            end
        end
        U.flipY = true
    end
    return mapID, list
end

-- a rota até um ponto: lista de slots (origem ... destino); nil se não houver
local function RouteSlots(n)
    local hops = Safe(GetNumRoutes, n.slot) or 0
    if hops < 1 then return end
    local slots = {}
    if _G.TaxiGetNodeSlot then
        for h = 1, hops do
            local s = Safe(TaxiGetNodeSlot, n.slot, h, true)
            if h == 1 and s then slots[1] = s end
            slots[#slots + 1] = Safe(TaxiGetNodeSlot, n.slot, h, false)
        end
        if #slots == hops + 1 then return slots end
    end
    -- sem TaxiGetNodeSlot: o ponto mais perto de cada fim de trecho (descobre se o y vem invertido)
    local function Nearest(x, y)
        local best, bd
        for _, o in ipairs(U.nodes) do
            local d = (o.nx - x) ^ 2 + (o.ny - y) ^ 2
            if not bd or d < bd then best, bd = o, d end
        end
        return best, bd or 1
    end
    local lx, ly = Safe(TaxiGetDestX, n.slot, hops), Safe(TaxiGetDestY, n.slot, hops)
    if not (lx and ly) then return end
    local flip = (lx - n.nx) ^ 2 + ((1 - ly) - n.ny) ^ 2 < (lx - n.nx) ^ 2 + (ly - n.ny) ^ 2
    local function Y(y) return flip and (1 - y) or y end
    slots = {}
    local o = Nearest(Safe(TaxiGetSrcX, n.slot, 1) or 0, Y(Safe(TaxiGetSrcY, n.slot, 1) or 0))
    slots[1] = o and o.slot
    for h = 1, hops do
        o = Nearest(Safe(TaxiGetDestX, n.slot, h) or 0, Y(Safe(TaxiGetDestY, n.slot, h) or 0))
        slots[#slots + 1] = o and o.slot
    end
    return slots
end

---------------------------------------------------------------------------
-- Desenho: botões dos pontos e a rota (linhas) por cima do mapa
---------------------------------------------------------------------------
local function ToView(x, y)
    local S = WM().api.S
    return S.ox + x * S.zoom, S.oy - y * S.zoom
end

local function LineGet(i)
    local l = U.lines[i]
    if not l then
        local L = U.layer
        l = { under = L:CreateLine(nil, "ARTWORK", nil, 1), top = L:CreateLine(nil, "ARTWORK", nil, 2) }
        l.under:SetColorTexture(0.03, 0.06, 0.09, 0.85)
        l.under:SetThickness(7)
        l.top:SetTexture(FRAME_TEX .. "Route")
        l.top:SetThickness(9)
        l.top:SetBlendMode("ADD")
        l.top:SetVertexColor(1, 0.86, 0.45, 1)
        U.lines[i] = l
    end
    return l
end

local function HideRoute()
    for _, l in ipairs(U.lines) do l.under:Hide(); l.top:Hide() end
    U.route = nil
end

local function PlaceRoute()
    local r = U.route
    if not r then return end
    local view = WM().api.S.view
    for i = 1, #r - 1 do
        local a, b = U.bySlot[r[i]], U.bySlot[r[i + 1]]
        local l = LineGet(i)
        if a and b then
            local ax, ay = ToView(a.x, a.y)
            local bx, by = ToView(b.x, b.y)
            for _, ln in ipairs({ l.under, l.top }) do
                ln:SetStartPoint("TOPLEFT", view, ax, ay)
                ln:SetEndPoint("TOPLEFT", view, bx, by)
                ln:Show()
            end
        else
            l.under:Hide(); l.top:Hide()
        end
    end
end

local function ShowRoute(slots)
    HideRoute()
    U.route = slots
    PlaceRoute()
end

local function NodeTip(btn)
    local n = btn.node
    local tt = GameTooltip
    tt:SetOwner(btn, "ANCHOR_RIGHT")
    tt:AddLine(n.name or "Mestre de voo", 1, 0.82, 0.45)
    if n.kind == "CURRENT" then
        tt:AddLine("Você está aqui", 0.5, 0.85, 0.5)
    elseif n.kind == "REACHABLE" then
        local cost = Safe(TaxiNodeCost, n.slot)
        if cost and cost > 0 then
            local money = _G.GetCoinTextureString and GetCoinTextureString(cost) or tostring(cost)
            tt:AddDoubleLine("Custo", money, 0.85, 0.85, 0.85, 1, 1, 1)
        end
        local slots = RouteSlots(n)
        if slots then
            local names = {}
            for _, s in ipairs(slots) do
                local o = U.bySlot[s]
                names[#names + 1] = o and o.name or "?"
            end
            local stops = #slots - 2
            tt:AddLine(stops > 0 and ("Rota com " .. stops .. (stops == 1 and " parada" or " paradas")) or "Voo direto",
                0.37, 0.89, 0.90)
            if stops > 0 then tt:AddLine(table.concat(names, "  >  "), 0.85, 0.85, 0.85, true) end
            ShowRoute(slots)
        end
        tt:AddLine("Clique: voar", 0.6, 0.6, 0.6)
    else
        tt:AddLine("Sem rota conhecida até aqui", 0.6, 0.6, 0.6)
    end
    tt:Show()
end

local function BtnGet(i)
    local b = U.btns[i]
    if not b then
        b = CreateFrame("Button", nil, U.layer)
        b:SetSize(24, 24)
        b:SetFrameLevel(U.layer:GetFrameLevel() + 2)
        b.rim = b:CreateTexture(nil, "ARTWORK", nil, 1)
        b.rim:SetTexture(UI .. "Disc.tga")
        b.rim:SetAllPoints()
        b.icon = b:CreateTexture(nil, "ARTWORK", nil, 2)
        b.icon:SetPoint("CENTER")
        b.icon:SetSize(18, 18)
        b.hl = b:CreateTexture(nil, "HIGHLIGHT")
        b.hl:SetTexture("Interface\\TaxiFrame\\UI-Taxi-Icon-Highlight")
        b.hl:SetPoint("CENTER")
        b.hl:SetSize(36, 36)
        b.hl:SetBlendMode("ADD")
        -- halo colorido atrás (destaca o ponto sobre o terreno) e anel que pulsa no ponto atual
        b.halo = b:CreateTexture(nil, "BACKGROUND", nil, 1)
        b.halo:SetTexture(FRAME_TEX .. "PinRing")
        b.halo:SetPoint("CENTER")
        b.halo:SetBlendMode("ADD")
        b.shade = b:CreateTexture(nil, "BACKGROUND", nil, 0)     -- disco escuro sob o halo (lê sobre papel claro)
        b.shade:SetTexture(UI .. "Disc.tga")
        b.shade:SetPoint("CENTER")
        b.shade:SetVertexColor(0, 0, 0, 0.55)
        b.pulse = b:CreateTexture(nil, "BACKGROUND", nil, 2)
        b.pulse:SetTexture(FRAME_TEX .. "PinRing")
        b.pulse:SetPoint("CENTER")
        b.pulse:SetBlendMode("ADD")
        local ag = b.pulse:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        local sc = ag:CreateAnimation("Scale")
        sc:SetScaleFrom(0.6, 0.6); sc:SetScaleTo(1.6, 1.6); sc:SetDuration(1.4)
        local al = ag:CreateAnimation("Alpha")
        al:SetFromAlpha(0.9); al:SetToAlpha(0); al:SetDuration(1.4)
        b.pulseAnim = ag
        b.label = b:CreateFontString(nil, "OVERLAY")
        b.label:SetPoint("TOP", b, "BOTTOM", 0, -1)
        local media = Azaath.media or {}
        if not pcall(b.label.SetFont, b.label, media.fontCinzel or media.fontTitleB or STANDARD_TEXT_FONT, 12, "OUTLINE") then
            b.label:SetFontObject(GameFontNormalSmall)
        end
        b.label:SetShadowColor(0, 0, 0, 1)
        b.label:SetShadowOffset(1, -1)
        b:RegisterForClicks("LeftButtonUp")
        b:SetScript("OnEnter", function(self)
            local S = WM().api.S
            S.taxiHover, S.tipPin = true, nil       -- (senão o mapa esconde a dica no próximo quadro)
            NodeTip(self)
        end)
        b:SetScript("OnLeave", function()
            WM().api.S.taxiHover = nil
            GameTooltip:Hide()
            HideRoute()
        end)
        b:SetScript("OnClick", function(self)
            local n = self.node
            if n and n.kind == "REACHABLE" and _G.TakeTaxiNode then
                GameTooltip:Hide()
                TakeTaxiNode(n.slot)
            end
        end)
        U.btns[i] = b
    end
    return b
end

local function PlaceNodes()
    local S = WM().api.S
    U.z, U.ox, U.oy = S.zoom, S.ox, S.oy
    for i = 1, U.used do
        local b = U.btns[i]
        local sx, sy = ToView(b.node.x, b.node.y)
        b:ClearAllPoints()
        b:SetPoint("CENTER", S.view, "TOPLEFT", sx, sy)
        b._sx, b._sy = sx, sy
    end
    -- nomes: o ponto atual e os destinos; um nome que cairia sobre outro já escrito fica oculto
    local placed = {}
    for i = 1, U.used do
        local b = U.btns[i]
        local fs = b.label
        local show = b.node.kind ~= "NONE"
        if show then
            local w, h = fs:GetStringWidth() + 6, 15
            local x0, y0 = b._sx - w / 2, b._sy - b:GetHeight() / 2 - 1 - h
            for _, r in ipairs(placed) do
                if x0 < r[3] and x0 + w > r[1] and y0 < r[4] and y0 + h > r[2] then show = false break end
            end
            if show then placed[#placed + 1] = { x0, y0, x0 + w, y0 + h } end
        end
        fs:SetShown(show)
    end
    PlaceRoute()
end

local function LayoutNodes()
    for _, b in ipairs(U.btns) do b:Hide() end
    U.used = 0
    local order = {}
    for _, n in ipairs(U.nodes) do order[#order + 1] = n end
    local rank = { CURRENT = 1, REACHABLE = 2, NONE = 3 }
    table.sort(order, function(a, b) return rank[a.kind] < rank[b.kind] end)
    for _, n in ipairs(order) do
        U.used = U.used + 1
        local b = BtnGet(U.used)
        b.node = n
        local rim = RIM[n.kind]
        b.rim:SetVertexColor(rim[1] * 0.4, rim[2] * 0.4, rim[3] * 0.4, 0.95)
        b.icon:SetTexture(ICON[n.kind])
        b.icon:SetDesaturated(n.kind == "NONE")
        -- atual: grande, verde, pulsando; destino: médio, dourado; sem rota: pequeno e apagado
        local LOOK = { CURRENT = { 38, 30, 64, 0.35, 1.0, 0.45 }, REACHABLE = { 30, 24, 50, 1.0, 0.82, 0.35 },
                       NONE = { 20, 15, 0, 0, 0, 0 } }
        local lk = LOOK[n.kind]
        b:SetSize(lk[1], lk[1])
        b.icon:SetSize(lk[2], lk[2])
        b.shade:SetSize(lk[1] + 10, lk[1] + 10)
        b.shade:SetShown(n.kind ~= "NONE")
        b.halo:SetSize(lk[3], lk[3])
        b.halo:SetVertexColor(lk[4], lk[5], lk[6], 0.95)
        b.halo:SetShown(n.kind ~= "NONE")
        b.pulse:SetSize(lk[3] + 8, lk[3] + 8)
        b.pulse:SetVertexColor(lk[4], lk[5], lk[6], 1)
        b.pulse:SetShown(n.kind == "CURRENT")
        if n.kind == "CURRENT" then b.pulseAnim:Play() else b.pulseAnim:Stop() end
        b:SetFrameLevel(U.layer:GetFrameLevel() + (n.kind == "CURRENT" and 4 or n.kind == "REACHABLE" and 3 or 2))
        if n.kind == "CURRENT" then
            b.label:SetText("VOCÊ ESTÁ AQUI")
            b.label:SetTextColor(0.55, 1, 0.55)
        else
            b.label:SetText(n.name or "")
            b.label:SetTextColor(1, 0.86, 0.5)
        end
        b:SetAlpha(n.kind == "NONE" and 0.5 or 1)
        b:Show()
    end
    PlaceNodes()
end

local function EnsureLayer()
    if U.layer then return end
    local S = WM().api.S
    local L = CreateFrame("Frame", nil, S.view)
    L:SetAllPoints()
    L:SetFrameLevel(S.view:GetFrameLevel() + 8)     -- acima do jogador e dos lugares
    local veil = L:CreateTexture(nil, "BACKGROUND", nil, -8)
    veil:SetAllPoints()
    veil:SetColorTexture(0, 0, 0, 0.32)
    L:SetScript("OnUpdate", function(self)
        if S.mode ~= "terrain" then
            if self.azaathShown ~= false then self.azaathShown = false; for i = 1, U.used do U.btns[i]:Hide() end; HideRoute() end
            return
        end
        if self.azaathShown == false then
            self.azaathShown = true
            for i = 1, U.used do U.btns[i]:Show() end
        end
        if S.zoom ~= U.z or S.ox ~= U.ox or S.oy ~= U.oy then PlaceNodes() end
    end)
    U.layer = L
    -- fechar o nosso mapa (Esc, botão, tecla M) encerra a conversa com o mestre de voo
    S.frame:HookScript("OnHide", function()
        if U.active and not U.byEvent then
            M:Stop()
            if _G.CloseTaxiMap then
                pcall(CloseTaxiMap)
            elseif _G.C_PlayerInteractionManager and C_PlayerInteractionManager.ClearInteraction then
                pcall(C_PlayerInteractionManager.ClearInteraction)
            end
        end
    end)
end

---------------------------------------------------------------------------
-- Abrir / fechar
---------------------------------------------------------------------------
function M:Stop()
    if not U.active then return end
    U.active = false
    local wm = WM()
    local S = wm.api.S
    S.taxiMode, S.taxiHover = nil, nil
    if U.layer then U.layer:Hide() end
    HideRoute()
    GameTooltip:Hide()
    wm.api.LayoutPOI()
    Silence(false)
end

local function OnTaxiOpened()
    if not Enabled() then return end
    local wm = WM()
    if not wm.api.S.P then wm:Open(); wm:Close() end        -- monta o plano (fica escondido)
    local mapID, list = ReadNodes()
    local proj = mapID and #list > 0 and Projector(mapID)
    if not proj then return end                              -- continente fora do plano: fica a da Blizzard
    U.nodes, U.bySlot = {}, {}
    local x0, y0, x1, y1
    for _, n in ipairs(list) do
        n.x, n.y = proj(n.nx, n.ny)
        U.nodes[#U.nodes + 1] = n
        U.bySlot[n.slot] = n
        if n.kind ~= "NONE" then
            x0, y0 = min(x0 or n.x, n.x), min(y0 or n.y, n.y)
            x1, y1 = max(x1 or n.x, n.x), max(y1 or n.y, n.y)
        end
    end
    U.active = true
    Silence(true)
    C_Timer.After(0, function() if U.active then Silence(true) end end)   -- (FlightMapFrame carrega sob demanda)
    U.wasOpen = wm:IsOpen()
    local S = wm.api.S
    S.taxiMode = true
    wm:Open(wm.api.Place(mapID) and mapID or nil)   -- (fora do plano, ShowMap iria para a página de arte)
    EnsureLayer()
    U.layer:Show()
    U.layer.azaathShown = nil
    LayoutNodes()
    wm.api.LayoutPOI()
    -- enquadra os destinos (com folga); um só ponto: um pedaço do continente em volta dele
    if x0 then
        local w, h = x1 - x0, y1 - y0
        local p = wm.api.Place(mapID)
        local minW = p and p.x1 and (p.x1 - p.x0) * 0.25 or 40
        if w < minW then x0, x1, w = x0 - (minW - w) / 2, x1 + (minW - w) / 2, minW end
        if h < minW * 0.6 then local d = (minW * 0.6 - h) / 2; y0, y1, h = y0 - d, y1 + d, minW * 0.6 end
        wm.api.Fit(x0 - w * 0.12, y0 - h * 0.12, x1 + w * 0.12, y1 + h * 0.12)
    end
end

local function OnTaxiClosed()
    if not U.active then return end
    M:Stop()
    if not U.wasOpen then
        U.byEvent = true
        WM():Close()
        U.byEvent = false
    end
end

function M:OnEnable()
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("TAXIMAP_OPENED")
    ev:RegisterEvent("TAXIMAP_CLOSED")
    ev:RegisterEvent("ADDON_LOADED")
    ev:SetScript("OnEvent", function(_, event, name)
        if event == "TAXIMAP_OPENED" then
            local ok, err = pcall(OnTaxiOpened)
            if not ok then
                if U.active then pcall(M.Stop, M) end
                if Azaath.LogError then Azaath.LogError("MapTaxi: " .. tostring(err)) end
            end
        elseif event == "TAXIMAP_CLOSED" then
            OnTaxiClosed()
        elseif name == "Blizzard_FlightMap" and U.active then
            Silence(true)
        end
    end)
end
