--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Talents/Panel.lua
    Crisol de talentos: painel do talento, botões Purificar/Selar e seleção.
    Símbolos comuns vêm de Azaath.TalentsUI (Modules/Talents/Core.lua).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.TalentsUI
local _G, format, ipairs, min = _G, string.format, ipairs, math.min
local pairs, pcall, random, sin = pairs, pcall, math.random, math.sin
local tostring, tsort, wipe = tostring, table.sort, wipe
local AURA_TEX, AZ_BRIGHT, At, CORE_X = U.AURA_TEX, U.AZ_BRIGHT, U.At, U.CORE_X
local CORE_Y, CREAM, CYAN, CanRemovePoint = U.CORE_Y, U.CREAM, U.CYAN, U.CanRemovePoint
local CircleMask, DESC_COL, DescFor, EMBLEM_X = U.CircleMask, U.DESC_COL, U.DescFor, U.EMBLEM_X
local EMBLEM_Y, EmitBurst, FitText, GOLD = U.EMBLEM_Y, U.EmitBurst, U.FitText, U.GOLD
local LOCK_COL, M, MEDIA, NodeState = U.LOCK_COL, U.M, U.MEDIA, U.NodeState
local PANEL_X, PURGE_RED, PlayCue, Plural = U.PANEL_X, U.PURGE_RED, U.PlayCue, U.Plural
local TAL, TREE_COLORS, Tex, Text = U.TAL, U.TREE_COLORS, U.Tex, U.Text
local Tracked, Upper, WHITE, WHITE8 = U.Tracked, U.Upper, U.WHITE, U.WHITE8
local anim, applyQueue, bottom, nodeButtons = U.anim, U.applyQueue, U.bottom, U.nodeButtons
local pending, right, top = U.pending, U.right, U.top

--------------------------------------------------------------------------------
-- Painel do talento (direita)
--------------------------------------------------------------------------------
-- Aura viva (a mesma dos medalhões): duas camadas de halo de borda irregular
-- girando em sentidos opostos, respirando em tamanho, cada uma com fase própria.
--------------------------------------------------------------------------------
local function LiveAura(parent, layer, sub, w, h, col)
    local A = { w = w, h = h or w, ph = random() * 6.283, sp = 0.75 + random() * 0.5, strength = 0 }
    A.t1 = Tex(parent, layer, AURA_TEX, "ADD", sub)
    A.t2 = Tex(parent, layer, AURA_TEX, "ADD", sub)
    function A:SetColor(c)
        self.t1:SetVertexColor(c[1], c[2], c[3], 1)
        self.t2:SetVertexColor(0.55 + c[1] * 0.45, 0.55 + c[2] * 0.45, 0.55 + c[3] * 0.45, 1)
    end
    function A:Place(rel, x, y)
        At(self.t1, rel, x, y); At(self.t2, rel, x, y)
    end
    function A:Center(frame)
        self.t1:SetPoint("CENTER", frame, "CENTER"); self.t2:SetPoint("CENTER", frame, "CENTER")
    end
    -- e = intensidade (0 apaga); chamado a cada quadro
    function A:Tick(t, e)
        if e <= 0.01 then self.t1:SetAlpha(0); self.t2:SetAlpha(0); return end
        local s, ph = t * self.sp, self.ph
        local breath = 0.5 + 0.5 * sin(s * 1.9 + ph)
        local flick = 0.5 + 0.5 * sin(s * 4.7 + ph * 1.7) * sin(s * 2.3 + ph * 0.6)
        self.t1:SetSize(self.w * (0.90 + 0.12 * breath), self.h * (0.90 + 0.12 * breath))
        self.t2:SetSize(self.w * (1.05 + 0.18 * flick), self.h * (1.05 + 0.18 * flick))
        if self.t1.SetRotation and self.w == self.h then
            self.t1:SetRotation(s * 0.45 + ph)
            self.t2:SetRotation(-s * 0.30 + ph * 2)
        end
        self.t1:SetAlpha(min(1, e * (0.50 + 0.40 * breath)))
        self.t2:SetAlpha(min(1, e * (0.18 + 0.30 * flick)))
    end
    A:SetColor(col)
    A:Tick(0, 0)
    return A
end

-- Acendimento de botão: aura viva achatada atrás do texto, sem linhas nem
-- caixas (os filetes antigos cortavam o texto). SetAlpha/GetAlpha guardam a
-- intensidade; o pulso é dado pelo relógio do módulo.
local buttonLights = {}
local function ButtonLight(btn, w, h, col)
    local A = LiveAura(btn, "BACKGROUND", 1, w * 0.92, h * 1.15, col)
    A.Center(A, btn)
    A.a = 0
    function A:SetAlpha(a) self.a = a end
    function A:GetAlpha() return self.a end
    buttonLights[#buttonLights + 1] = A
    return A
end

-- Realce interno de botão (preenchimento suave + borda luminosa de 1px) para
-- destacar estados acionáveis como Purificar (vermelho leve) e Selar (azul azaath).
local function ButtonTint(btn, w, h, col)
    local T = { a = 0 }
    local fill = Tex(btn, "BACKGROUND", WHITE8, "ADD", 0)
    fill:SetSize(w, h)
    fill:SetPoint("CENTER", btn, "CENTER")
    fill:SetVertexColor(col[1], col[2], col[3], 1)
    fill:SetAlpha(0)
    local edges = {}
    local function edge(p1, p2, ew, eh)
        local e = Tex(btn, "BORDER", WHITE8, "ADD", 0)
        e:SetSize(ew, eh)
        e:SetPoint(p1, fill, p1)
        e:SetPoint(p2, fill, p2)
        e:SetVertexColor(col[1], col[2], col[3], 1)
        e:SetAlpha(0)
        edges[#edges + 1] = e
    end
    edge("TOPLEFT", "TOPRIGHT", w, 1)
    edge("BOTTOMLEFT", "BOTTOMRIGHT", w, 1)
    edge("TOPLEFT", "BOTTOMLEFT", 1, h)
    edge("TOPRIGHT", "BOTTOMRIGHT", 1, h)
    function T:SetAlpha(a)
        self.a = a
        fill:SetAlpha(a * 0.22)
        for _, e in ipairs(edges) do e:SetAlpha(a * 0.55) end
    end
    function T:GetAlpha() return self.a end
    return T
end

-- Texto de botão: Cinzel sem o espaçamento largo, sombra macia logo abaixo
local function ButtonText(parent, size, col)
    local fs = Text(parent, Azaath.media.fontCinzel or Azaath.media.fontTitleB, size, col, "CENTER")
    fs:SetShadowOffset(0, -1)
    fs:SetShadowColor(0, 0, 0, 0.95)
    fs:SetPoint("CENTER", parent, "CENTER", 0, 0)
    return fs
end

-- Card do talento: arte de tools/card-concept (896x1200) escalada para 300px de
-- largura na arte do Crisol. CX/CY convertem coordenadas da arte do card.
local CS = 300 / 540
local function CX(x) return 1040 + (x - 180) * CS end
local function CY(y) return 100 + y * CS end
local CARD_TEX, CARD_GLOW_TEX, PIP_TEX = TAL .. "TalentBG", TAL .. "TalentArtIcons", TAL .. "TalentBtnApply"
local PLAQUE_COL = { 0.88, 0.80, 0.60 }
local DESC_BOX = { top = CY(786), bottom = CY(886), w = 420 * CS }
local MAX_RANK_PIPS = 5

local function BuildRight()
    U.rightF = CreateFrame("Frame", nil, U.art)
    U.rightF:SetAllPoints(U.art)
    U.rightF:SetFrameLevel(U.art:GetFrameLevel() + 5)

    local fontCinzel = Azaath.media.fontCinzel or Azaath.media.fontTitleB
    local fontBody   = Azaath.media.fontCard or Azaath.media.font
    local blocks = {}
    local function Block(r) blocks[#blocks + 1] = r; return r end

    -- o card (coroa, moldura, placa, círculo rúnico, pílulas, caixa, botões)
    right.card = Tex(U.rightF, "BACKGROUND", CARD_TEX, "BLEND", 1)
    right.card:SetSize(560 * CS, 1090 * CS)
    right.card:SetTexCoord(0, 1, 0, 997 / 1024)
    At(right.card, U.rightF, CX(170), CY(40), "TOPLEFT")
    -- brilho das runas (coroa e círculo) por cima, pulsando
    right.cardGlow = Tex(U.rightF, "BORDER", CARD_GLOW_TEX, "ADD", 1)
    right.cardGlow:SetSize(560 * CS, 1090 * CS)
    right.cardGlow:SetTexCoord(0, 1, 0, 997 / 1024)
    At(right.cardGlow, U.rightF, CX(170), CY(40), "TOPLEFT")

    -- placa: "ARMAS • CÍRCULO 1"
    right.kindL = Block(Text(U.rightF, fontCinzel, 12, PLAQUE_COL, "RIGHT"))
    right.kindR = Block(Text(U.rightF, fontCinzel, 12, PLAQUE_COL, "LEFT"))
    right.kindDot = Block(Tex(U.rightF, "OVERLAY", MEDIA .. "Disc"))
    right.kindDot:SetSize(3.5, 3.5)
    right.kindDot:SetVertexColor(PLAQUE_COL[1], PLAQUE_COL[2], PLAQUE_COL[3], 1)

    right.name = Block(Text(U.rightF, fontCinzel, 14, { 0.90, 0.93, 0.96 }, "CENTER"))
    At(right.name, U.rightF, PANEL_X, CY(326))

    -- emblema: ícone no poço do círculo rúnico, com raios e brilho da árvore
    right.iconHolder = CreateFrame("Frame", nil, U.rightF)
    right.iconHolder:SetSize(140, 140)
    At(right.iconHolder, U.rightF, EMBLEM_X, EMBLEM_Y)
    right.rays = Tex(right.iconHolder, "BACKGROUND", MEDIA .. "Rays", "ADD", 1)
    right.rays:SetPoint("CENTER")
    right.rays:SetSize(205 * CS, 205 * CS)
    right.glow = Tex(right.iconHolder, "BACKGROUND", MEDIA .. "Glow", "ADD", 2)
    right.glow:SetPoint("CENTER")
    right.glow:SetSize(175 * CS, 175 * CS)
    right.icon = Tex(right.iconHolder, "ARTWORK", nil)
    right.icon:SetPoint("CENTER")
    right.icon:SetSize(136 * CS, 136 * CS)
    right.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    CircleMask(right.iconHolder, right.icon)
    -- véu quente/da árvore por cima do ícone (o da arte é banhado de luz)
    right.iconSheen = Tex(right.iconHolder, "ARTWORK", MEDIA .. "Glow", "ADD", 2)
    right.iconSheen:SetPoint("CENTER")
    right.iconSheen:SetSize(150 * CS, 150 * CS)
    right.flash = Tex(right.iconHolder, "OVERLAY", MEDIA .. "Glow", "ADD", 3)
    right.flash:SetPoint("CENTER")
    right.flash:SetSize(160, 160)
    right.flash:SetVertexColor(0.65, 0.98, 1.00, 1)
    right.flash:SetAlpha(0)

    -- losangos de grau sobre o círculo (acesos = pontos)
    right.pips = {}
    for i = 1, MAX_RANK_PIPS do
        local p = Block(Tex(U.rightF, "OVERLAY", PIP_TEX, "BLEND", 3))
        p:SetSize(44 * CS, 44 * CS)
        right.pips[i] = p
    end
    right.pipGlow = {}
    for i = 1, MAX_RANK_PIPS do
        right.pipGlow[i] = LiveAura(U.rightF, "OVERLAY", 2, 64 * CS, 64 * CS, { 1, 0.78, 0.32 })
    end

    right.rankLine = Block(Text(U.rightF, fontCinzel, 11.5, { 0.74, 0.77, 0.80 }, "CENTER"))
    At(right.rankLine, U.rightF, PANEL_X, CY(670))

    -- pílulas pintadas: a dourada leva Passiva/Ativa, a ciano o estado
    right.pillKind = Block(Text(U.rightF, fontCinzel, 10, { 0.96, 0.90, 0.72 }, "CENTER"))
    At(right.pillKind, U.rightF, CX(310), CY(729.5))
    right.pillState = Block(Text(U.rightF, fontCinzel, 10, { 0.88, 0.96, 1.00 }, "CENTER"))
    At(right.pillState, U.rightF, CX(515), CY(729.5))

    -- caixa da descrição: motivo do bloqueio (vermelho) + efeito, centrados
    right.reqText = Block(Text(U.rightF, fontBody, 11, LOCK_COL, "CENTER"))
    right.reqText:SetWidth(DESC_BOX.w)
    right.reqText:SetWordWrap(true)
    right.desc = Block(Text(U.rightF, fontBody, 11, DESC_COL, "CENTER"))
    right.desc:SetWidth(DESC_BOX.w)
    right.desc:SetWordWrap(true)
    if right.desc.SetSpacing then right.desc:SetSpacing(1.5) end

    -- INFUNDIR AZAATH (+1), com os cristais das pontas acendendo
    right.imbuirBtn = CreateFrame("Button", nil, U.rightF)
    right.imbuirBtn:SetSize(370 * CS, 60 * CS)
    right.imbuirBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    At(right.imbuirBtn, U.rightF, PANEL_X, CY(955))
    right.imbuirGlow = ButtonLight(right.imbuirBtn, 290 * CS, 38 * CS, CYAN)
    right.imbuirText = ButtonText(right.imbuirBtn, 13, CREAM)
    right.crystals = {}
    for i, x in ipairs({ 272, 628 }) do
        local g = LiveAura(U.rightF, "OVERLAY", 4, 62 * CS, 62 * CS, CYAN)
        g:Place(U.rightF, CX(x), CY(955))
        right.crystals[i] = g
    end
    right.imbuirBtn:SetScript("OnEnter", function(self) self.hover = true end)
    right.imbuirBtn:SetScript("OnLeave", function(self) self.hover = false end)
    right.imbuirBtn:SetScript("OnClick", function(_, button)
        if not U.selKey then return end
        if button == "RightButton" then U.RefundNode(U.selKey) else U.ImbueNode(U.selKey) end
    end)

    right.removeBtn = CreateFrame("Button", nil, U.rightF)
    right.removeBtn:SetSize(120, 12)
    At(right.removeBtn, U.rightF, PANEL_X, CY(1008))
    right.removeText = Text(right.removeBtn, fontBody, 9, { 0.95, 0.65, 0.32 }, "CENTER")
    right.removeText:SetPoint("CENTER")
    right.removeText:SetText("Retirar 1 ponto")
    right.removeBtn:SetScript("OnEnter", function() right.removeText:SetTextColor(1, 0.82, 0.55) end)
    right.removeBtn:SetScript("OnLeave", function() right.removeText:SetTextColor(0.95, 0.65, 0.32) end)
    right.removeBtn:SetScript("OnClick", function() if U.selKey then U.RefundNode(U.selKey) end end)

    right.blocks = blocks
end

local function LayoutKind(l, r)
    local maxW = 250 * CS
    local size = 12
    repeat
        right.kindL:SetFont(right.kindL.baseFont, size, "")
        right.kindR:SetFont(right.kindR.baseFont, size, "")
        right.kindL:SetText(l)
        right.kindR:SetText(r)
        local total = (right.kindL:GetStringWidth() or 0) + 14 + (right.kindR:GetStringWidth() or 0)
        size = size - 0.5
    until total <= maxW or size < 8
    local wl = right.kindL:GetStringWidth() or 0
    local total = wl + 14 + (right.kindR:GetStringWidth() or 0)
    local x0 = PANEL_X - total / 2
    local y = CY(267)
    At(right.kindL, U.rightF, x0 + wl, y, "RIGHT")
    At(right.kindDot, U.rightF, x0 + wl + 7, y + 0.5)
    At(right.kindR, U.rightF, x0 + wl + 14, y, "LEFT")
end

-- losangos: tantos quantos o grau máximo, acesos até o grau atual
local function LayoutPips(r, col)
    local n = r and min(MAX_RANK_PIPS, r.max) or 0
    for i = 1, MAX_RANK_PIPS do
        local p, g = right.pips[i], right.pipGlow[i]
        if i <= n then
            local x = PANEL_X + (i - (n + 1) / 2) * 45 * CS
            At(p, U.rightF, x, CY(625))
            g:Place(U.rightF, x, CY(625))
            local lit = i <= r.rank
            p:SetTexCoord(lit and 0 or 0.5, lit and 0.5 or 1, 0, 1)
            if lit and i > r.baseRank then
                p:SetVertexColor(0.55, 0.95, 1.00, 1) -- ponto na prévia
                g:SetColor(AZ_BRIGHT)
            else
                p:SetVertexColor(1, 1, 1, 1)
                g:SetColor({ 1, 0.78, 0.32 })
            end
            g.lit = lit
            p:Show()
        else
            p:Hide()
            g.lit = false
        end
    end
end

local function LockReason(r)
    local tabInfo = U.treeData.tabs[r.tab]
    local tabName = tabInfo and tabInfo.name or ("Senda " .. r.tab)
    local reasons = {}
    if not r.tierUnlocked then
        local falta = r.reqPoints - r.pointsBelow
        reasons[#reasons + 1] = format("Gaste mais %d %s em %s nos círculos anteriores (precisa de %d, tem %d).",
            falta, Plural(falta, "ponto", "pontos"), tabName, r.reqPoints, r.pointsBelow)
    end
    for _, pr in ipairs(r.prereqs) do
        local p = pr.parentKey and U.treeData.byKey[pr.parentKey]
        if p and not pr.ok then
            reasons[#reasons + 1] = format("Precisa de %s no grau máximo (%d/%d).", p.name, p.rank, p.max)
        end
    end
    if #reasons == 0 then
        reasons[1] = "O jogo ainda não libera este talento."
    end
    return table.concat(reasons, "\n")
end

-- motivo + descrição centrados na caixa; encolhem juntos até caber
local function LayoutDesc(reason, text)
    local avail = DESC_BOX.bottom - DESC_BOX.top - 8
    local size = right.desc.baseSize
    local function apply()
        right.reqText:SetFont(right.reqText.baseFont, size, "")
        right.desc:SetFont(right.desc.baseFont, size, "")
        right.reqText:SetText(reason)
        right.desc:SetText(text)
        local h = (right.desc:GetStringHeight() or 0)
        if reason ~= "" then h = h + (right.reqText:GetStringHeight() or 0) + 3 end
        return h
    end
    local h = apply()
    while size > 7.5 and h > avail do
        size = size - 0.5
        h = apply()
    end
    local top = (DESC_BOX.top + DESC_BOX.bottom) / 2 - h / 2
    right.reqText:ClearAllPoints()
    right.desc:ClearAllPoints()
    if reason ~= "" then
        right.reqText:SetPoint("TOP", U.rightF, "TOPLEFT", PANEL_X, -top)
        right.desc:SetPoint("TOP", right.reqText, "BOTTOM", 0, -3)
    else
        right.desc:SetPoint("TOP", U.rightF, "TOPLEFT", PANEL_X, -top)
    end
end

U.UpdateRight = function(reveal)
    local key = U.hovKey or U.selKey
    local r = U.treeData and key and U.treeData.byKey[key]
    right.removeBtn:Hide()
    if not r then
        LayoutKind("CRISOL DE AZAATH", "TALENTOS")
        FitText(right.name, "NÚCLEO PRIMORDIAL", 440 * CS, 10)
        LayoutPips(nil)
        right.rankLine:SetText("")
        right.pillKind:SetText("")
        right.pillState:SetText("")
        right.icon:SetTexture(nil)
        LayoutDesc("", "Passe o mouse sobre um medalhão para ver o que ele faz.")
        right.imbuirText:SetText("")
        return
    end

    local tabInfo = U.treeData.tabs[r.tab]
    local tabName = tabInfo and tabInfo.name or ("Senda " .. r.tab)
    local col = TREE_COLORS[r.tab] or CYAN
    local curDesc, nextDesc = DescFor(r)

    LayoutKind(Upper(tabName), r.cap and "TALENTO PRIMORDIAL" or format("CÍRCULO %d", r.tier))
    FitText(right.name, Upper(r.name), 440 * CS, 10)
    local staged = r.rank - r.baseRank
    if staged > 0 then
        right.rankLine:SetText(format("GRAU %d / %d  |cff52e6ff(+%d)|r", r.rank, r.max, staged))
    else
        right.rankLine:SetText(format("GRAU %d / %d", r.rank, r.max))
    end

    local st = NodeState(r)
    LayoutPips(r, col)
    right.icon:SetTexture(r.icon)
    right.icon:SetDesaturated(st == "locked")
    right.icon:SetVertexColor(st == "locked" and 0.55 or 1, st == "locked" and 0.55 or 1, st == "locked" and 0.58 or 1, 1)
    right.glow:SetVertexColor(col[1], col[2], col[3], 1)
    right.rays:SetVertexColor(col[1], col[2], col[3], 1)
    right.iconSheen:SetVertexColor(col[1], col[2], col[3], 1)
    right.lockedGlow = (st == "locked")

    if r.passive == true then
        FitText(right.pillKind, "PASSIVA", 92 * CS, 7)
    elseif r.passive == false then
        FitText(right.pillKind, "ATIVA", 92 * CS, 7)
    else
        FitText(right.pillKind, "TALENTO", 92 * CS, 7)
    end
    local stTxt
    if st == "max" then stTxt = "GRAU MÁXIMO"
    elseif st == "buy" then stTxt = "PRONTO PARA INFUNDIR"
    elseif st == "locked" then stTxt = "BLOQUEADO"
    else stTxt = "SEM ESSÊNCIAS LIVRES" end
    FitText(right.pillState, stTxt, 235 * CS, 7)
    if st == "locked" then
        right.pillState:SetTextColor(1.00, 0.62, 0.55)
    elseif st == "max" then
        right.pillState:SetTextColor(GOLD[1], GOLD[2], GOLD[3])
    else
        right.pillState:SetTextColor(0.88, 0.96, 1.00)
    end

    local reason = (st == "locked") and LockReason(r) or ""
    local text
    if r.rank == 0 then
        text = "Ao infundir: " .. (curDesc ~= "" and curDesc or "-")
    else
        text = curDesc
        if nextDesc and nextDesc ~= "" and r.rank < r.max then
            text = text .. "\n|cff66e6ffPróximo grau:|r " .. nextDesc
        end
    end
    LayoutDesc(reason, text)

    local sel = U.treeData.byKey[U.selKey or ""] or r
    local sst = NodeState(sel)
    if sst == "buy" then
        FitText(right.imbuirText, "INFUNDIR AZAATH (+1)", 280 * CS, 9)
        right.imbuirText:SetTextColor(CREAM[1], CREAM[2], CREAM[3])
    elseif sst == "max" then
        FitText(right.imbuirText, "GRAU MÁXIMO", 280 * CS, 9)
        right.imbuirText:SetTextColor(GOLD[1], GOLD[2], GOLD[3], 0.9)
    elseif sst == "locked" then
        FitText(right.imbuirText, "BLOQUEADO", 280 * CS, 9)
        right.imbuirText:SetTextColor(0.62, 0.66, 0.70, 0.9)
    else
        FitText(right.imbuirText, "SEM ESSÊNCIAS", 280 * CS, 9)
        right.imbuirText:SetTextColor(0.62, 0.66, 0.70, 0.9)
    end
    if sel.canRefund and CanRemovePoint(sel) then right.removeBtn:Show() end

    if reveal then
        anim.rightReveal = { t = 0 }
        anim.iconPop = { t = 0 }
        for _, blk in ipairs(right.blocks) do blk:SetAlpha(0) end
    elseif not anim.rightReveal then
        for _, blk in ipairs(right.blocks) do blk:SetAlpha(1) end
    end
end

--------------------------------------------------------------------------------
-- PURIFICAR FLUXO / SELAR INFUSÃO e rodapé
--------------------------------------------------------------------------------

U.UpdateTotals = function()
    if not U.topF then return end
    local unspent = U.treeData and U.treeData.unspent or 0
    local staged = U.treeData and U.treeData.staged or 0
    FitText(top.points, Tracked(format("%d %s DE AZAATH", unspent, Plural(unspent, "ESSÊNCIA", "ESSÊNCIAS"))), 190, 9)
    FitText(top.spec, Tracked(U.specMode == 1 and "ESPECIALIZAÇÃO PRINCIPAL" or "ESPECIALIZAÇÃO SECUNDÁRIA"), 170, 7)

    FitText(bottom.sealText, staged > 0 and format("SELAR INFUSÃO (%d)", staged) or "SELAR INFUSÃO", 126, 9)
    bottom.sealText:SetTextColor(staged > 0 and 0.90 or 0.62, staged > 0 and 0.98 or 0.66, staged > 0 and 1 or 0.70)
    bottom.purgeText:SetTextColor(staged > 0 and 0.98 or 0.62, staged > 0 and 0.82 or 0.66, staged > 0 and 0.82 or 0.70)
    bottom.stagedText:SetText(staged > 0 and format("%d %s na prévia, ainda não %s", staged,
        Plural(staged, "ponto", "pontos"), Plural(staged, "selado", "selados")) or "")
end

local function UndoAll()
    if InCombatLockdown() then return end
    if U.treeData and U.treeData.mode == "traits" then
        local CT = _G.C_Traits
        if CT.RollbackConfig then
            pcall(CT.RollbackConfig, U.treeData.configID)
        else
            local list = {}
            for _, r in ipairs(U.treeData.nodes) do
                for _ = 1, r.rank - r.baseRank do list[#list + 1] = r end
            end
            tsort(list, function(a, b) return a.tier > b.tier end)
            for _, r in ipairs(list) do pcall(CT.RefundRank, U.treeData.configID, r.node) end
        end
    elseif U.treeData and U.treeData.hasPreviewAPI then
        if _G.ResetGroupPreviewTalentPoints then pcall(ResetGroupPreviewTalentPoints, false, U.specMode) end
    else
        wipe(pending)
    end
    if U.treeData and (U.treeData.staged or 0) > 0 then
        PlayCue("Purify", U.selKey)
    else
        Azaath.PlaySound("igMainMenuOptionCheckBoxOff")
    end
    U.dirty = true
end

local function ApplyAll()
    if InCombatLockdown() or not (U.treeData and (U.treeData.staged or 0) > 0) then return end
    if U.treeData.mode == "traits" then
        -- o jogo aplica conjurando por alguns segundos (como a janela dele)
        local CT, CCT = _G.C_Traits, _G.C_ClassTalents
        local commit = CT.CommitConfig or (CCT and CCT.CommitConfig)
        local ok, res = false, nil
        if commit then ok, res = pcall(commit, U.treeData.configID) end
        if not ok or res == false then
            Azaath.PlaySound("igMainMenuOptionCheckBoxOff")
            bottom.stagedText:SetText(ok and "O jogo não aceitou as mudanças." or ("O jogo recusou: " .. tostring(res)))
            return
        end
        if _G.C_Timer then
            C_Timer.After(1.5, function() U.dirty = true end)
            C_Timer.After(5, function() U.dirty = true end)
        end
    elseif U.treeData.hasPreviewAPI then
        pcall(LearnPreviewTalents, false)
    else
        wipe(applyQueue)
        for key, n in pairs(pending) do
            local r = U.treeData.byKey[key]
            if r then
                for _ = 1, n do applyQueue[#applyQueue + 1] = { tab = r.tab, idx = r.idx, tier = r.tier } end
            end
        end
        tsort(applyQueue, function(a, b) return a.tier < b.tier end)
        wipe(pending)
        U.applyWait = 0
    end
    PlayCue("Seal")
    EmitBurst(CORE_X, CORE_Y, CYAN, 26)
    EmitBurst(EMBLEM_X, EMBLEM_Y, AZ_BRIGHT, 16)
    U.dirty = true
end

local function ProcessApplyQueue(dt)
    if #applyQueue == 0 then return end
    U.applyWait = U.applyWait - dt
    if U.applyWait > 0 or InCombatLockdown() then return end
    local q = table.remove(applyQueue, 1)
    pcall(LearnTalent, q.tab, q.idx)
    U.applyWait = 0.3
    U.dirty = true
end

local function BuildBottom()
    U.bottomF = CreateFrame("Frame", nil, U.art)
    U.bottomF:SetAllPoints(U.art)
    U.bottomF:SetFrameLevel(U.art:GetFrameLevel() + 5)

    bottom.purgeBtn = CreateFrame("Button", nil, U.bottomF)
    bottom.purgeBtn:SetSize(258 * CS, 58 * CS)
    At(bottom.purgeBtn, U.bottomF, CX(311.5), CY(1089))
    bottom.purgeTint = ButtonTint(bottom.purgeBtn, 242 * CS, 44 * CS, PURGE_RED)
    bottom.purgeGlow = ButtonLight(bottom.purgeBtn, 240 * CS, 46 * CS, PURGE_RED)
    bottom.purgeText = ButtonText(bottom.purgeBtn, 12, { 0.80, 0.81, 0.84 })
    FitText(bottom.purgeText, "PURIFICAR FLUXO", 225 * CS, 9)
    bottom.purgeBtn:SetScript("OnEnter", function(self)
        self.hover = true
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Purificar fluxo", 1, 0.85, 0.35)
        GameTooltip:AddLine("Desfaz a prévia: devolve todos os pontos ainda não selados.", 0.85, 0.90, 0.95, true)
        GameTooltip:Show()
    end)
    bottom.purgeBtn:SetScript("OnLeave", function(self) self.hover = false; GameTooltip:Hide() end)
    bottom.purgeBtn:SetScript("OnClick", UndoAll)

    bottom.sealBtn = CreateFrame("Button", nil, U.bottomF)
    bottom.sealBtn:SetSize(258 * CS, 58 * CS)
    At(bottom.sealBtn, U.bottomF, CX(588.5), CY(1089))
    bottom.sealTint = ButtonTint(bottom.sealBtn, 242 * CS, 44 * CS, CYAN)
    bottom.sealGlow = ButtonLight(bottom.sealBtn, 240 * CS, 46 * CS, CYAN)
    bottom.sealText = ButtonText(bottom.sealBtn, 12, WHITE)
    bottom.sealBtn:SetScript("OnEnter", function(self)
        self.hover = true
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Selar infusão", 1, 0.85, 0.35)
        GameTooltip:AddLine("Aprende de vez os pontos da prévia.", 0.85, 0.90, 0.95, true)
        GameTooltip:Show()
    end)
    bottom.sealBtn:SetScript("OnLeave", function(self) self.hover = false; GameTooltip:Hide() end)
    bottom.sealBtn:SetScript("OnClick", ApplyAll)

    bottom.stagedText = Text(U.bottomF, Azaath.media.fontCard or Azaath.media.font, 9.5, CYAN, "RIGHT")
    At(bottom.stagedText, U.bottomF, 1338, 734, "RIGHT")

    bottom.closeBtn = CreateFrame("Button", nil, U.bottomF)
    bottom.closeBtn:SetSize(110, 22)
    At(bottom.closeBtn, U.bottomF, 1340, 749, "RIGHT")
    bottom.closeText = Text(bottom.closeBtn, Azaath.media.fontTitleB, 9.5, { 0.74, 0.78, 0.82 }, "RIGHT")
    bottom.closeText:SetPoint("RIGHT")
    bottom.closeText:SetText(Tracked("FECHAR (ESC)"))
    bottom.closeBtn:SetScript("OnEnter", function() bottom.closeText:SetTextColor(1, 1, 1) end)
    bottom.closeBtn:SetScript("OnLeave", function() bottom.closeText:SetTextColor(0.74, 0.78, 0.82) end)
    bottom.closeBtn:SetScript("OnClick", function() M:Close() end)
end

--------------------------------------------------------------------------------
-- Seleção, Infundir e Retirar
--------------------------------------------------------------------------------
local function FlashNode(key)
    for _, b in ipairs(nodeButtons) do
        if b.rec and b.rec.key == key then b.flashAlpha = 1; break end
    end
end

U.SelectNode = function(key)
    if not (U.treeData and U.treeData.byKey[key]) then return end
    local changed = (U.selKey ~= key)
    U.selKey = key
    if changed then U.UpdateRight(true) end
end

-- quiet: o clique só escolheu o talento (o som de escolher toca no lugar do "não")
U.ImbueNode = function(key, quiet)
    local r = U.treeData and U.treeData.byKey[key or U.selKey]
    if not r then return end
    if InCombatLockdown() then
        if not quiet then Azaath.PlaySound("igMainMenuOptionCheckBoxOff") end
        return
    end
    if not r.canBuy then
        if not quiet then Azaath.PlaySound("igMainMenuOptionCheckBoxOff") end
        anim.reqFlash = { t = 0 }
        return
    end
    if U.treeData.mode == "traits" then
        local CT = _G.C_Traits
        local ok, res = pcall(CT.PurchaseRank, U.treeData.configID, r.node)
        if not ok or res == false then
            Azaath.PlaySound("igMainMenuOptionCheckBoxOff")
            right.reqText:SetText(ok and "O jogo não aceitou este ponto agora." or ("O jogo recusou: " .. tostring(res)))
            anim.reqFlash = { t = 0 }
            return
        end
    elseif U.treeData.hasPreviewAPI then
        pcall(AddPreviewTalentPoints, r.tab, r.idx, 1, false, U.specMode)
    else
        pending[r.key] = (pending[r.key] or 0) + 1
    end
    PlayCue("Infuse", r.key)
    FlashNode(r.key)
    anim.iconPop = { t = 0 }
    EmitBurst(r.cx, r.cy, TREE_COLORS[r.tab] or CYAN, 14)
    U.dirty = true
    return true
end

U.RefundNode = function(key, quiet)
    local r = U.treeData and U.treeData.byKey[key or U.selKey]
    if not r or InCombatLockdown() then return end
    local ok, why = CanRemovePoint(r)
    if not ok then
        if not (quiet and not why) then Azaath.PlaySound("igMainMenuOptionCheckBoxOff") end
        if why then
            right.reqText:SetText(why)
            right.reqText:SetAlpha(1)
            anim.reqFlash = { t = 0 }
        end
        return
    end
    if U.treeData.mode == "traits" then
        local ok2, res = pcall(_G.C_Traits.RefundRank, U.treeData.configID, r.node)
        if not ok2 or res == false then
            Azaath.PlaySound("igMainMenuOptionCheckBoxOff")
            right.reqText:SetText("O jogo não devolveu este ponto.")
            anim.reqFlash = { t = 0 }
            return
        end
    elseif U.treeData.hasPreviewAPI then
        pcall(AddPreviewTalentPoints, r.tab, r.idx, -1, false, U.specMode)
    else
        local n = (pending[r.key] or 0) - 1
        pending[r.key] = (n > 0) and n or nil
    end
    PlayCue("Purify", r.key)
    U.dirty = true
    return true
end

-- compartilhado com os outros arquivos de Modules/Talents/
U.BuildBottom, U.BuildRight, U.CS, U.ProcessApplyQueue = BuildBottom, BuildRight, CS, ProcessApplyQueue
U.buttonLights = buttonLights
