--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Sheet/Reputation.lua
    Ficha do personagem: aba Reputação (arte de conceito).
    Símbolos comuns vêm de Azaath.SheetUI (Modules/Sheet/Core.lua).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.SheetUI
local cos, floor, ipairs, max = math.cos, math.floor, ipairs, math.max
local min, random, sin = math.min, math.random, math.sin
local MEDIA_ROOT, SHEET_MEDIA, STANDING_COLORS, Show = U.MEDIA_ROOT, U.SHEET_MEDIA, U.STANDING_COLORS, U.Show

--------------------------------------------------------------------------------
-- Aba Reputação: fundo = arte limpa tools/reputation-concept/clean.webp; linhas,
-- barra, caixas e painel recortados de concept.webp (a mesma cena com a interface)
-- por tools/reputation-concept/gen.js (as duas são 2000x1125); tudo aqui é em
-- px da arte (o quadro inteiro é escalado para cobrir a tela, como o Santuário).
-- Efeitos iguais aos do Santuário: selo da mesa respirando com ondas, fagulhas
-- subindo do selo, poeira de luz flutuando e pulsos correndo nas runas das colunas.
--------------------------------------------------------------------------------
local REP = {
    W = 2000, H = 1125,
    list = { x = 417, y = 148, w = 822, bottom = 652 },
    hdrH = 58, rowH = 52, gap = 4,
    seal = { 1020, 683 },
    runes = { x = 390, y = 70, w = 1240, h = 490, fw = 620, fh = 245, cellW = 1024, cellH = 256, atlasW = 2048, atlasH = 512, frames = 4, speed = 0.30 },
    panel = { x = 1590, y = 134, w = 398, h = 936 },     -- recorte ReputationPanel (512x1024)
    panelCX = 1788,
    bar = { x = 1622, y = 285, w = 333, h = 34, fx = 1631, fy = 291, fw = 307, fh = 22 },
    check = { x = 1625, y = 894, pitch = 37, label = 1660 },
}
local REP_ROWS = SHEET_MEDIA .. "ReputationRows"
local REP_PARTS = SHEET_MEDIA .. "ReputationParts"
local REP_PANEL = SHEET_MEDIA .. "ReputationPanel"
local REP_TEAL = { { 0.19, 0.37, 0.36 }, { 0.29, 0.59, 0.52 } }

local function RepText(parent, font, size, col, justify)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, "")
    fs:SetShadowOffset(1.5, -1.5)
    fs:SetShadowColor(0, 0, 0, 0.9)
    fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
    fs:SetJustifyH(justify or "LEFT")
    fs:SetWordWrap(false)
    return fs
end

-- cor do nível (tons apagados da arte; Honrado = verde suave)
local function RepStandingColor(id)
    local c = STANDING_COLORS[id] or STANDING_COLORS[4]
    local g = 0.38
    return { c[1] + (0.62 - c[1]) * g, c[2] + (0.68 - c[2]) * g, c[3] + (0.62 - c[3]) * g }
end

local function BuildReputationPage(page)
    local media = Azaath.media
    local fontT = media.fontCinzel or media.fontTitleB
    local R = REP
    local root = page:GetParent() and page:GetParent():GetParent() or UIParent

    local art = CreateFrame("Frame", nil, page)
    art:SetSize(R.W, R.H)
    art:SetPoint("CENTER", root, "CENTER", 0, 0)
    local function Fit()
        local w, h = root:GetWidth(), root:GetHeight()
        if not (w and h and w > 0 and h > 0) then w, h = UIParent:GetWidth(), UIParent:GetHeight() end
        art:SetScale(max(w / R.W, h / R.H))
    end
    Fit()
    page:HookScript("OnShow", Fit)

    local bg = art:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetTexture(SHEET_MEDIA .. "ReputationBG")
    bg:SetTexCoord(0, R.W / 2048, 0, R.H / 2048)
    bg:SetAllPoints(art)

    local function At(region, x, y, point)
        region:ClearAllPoints()
        region:SetPoint(point or "CENTER", art, "TOPLEFT", x, -y)
    end

    --==========================================================================
    -- Efeitos (camada abaixo da lista e do painel)
    --==========================================================================
    local fx = CreateFrame("Frame", nil, art)
    fx:SetAllPoints(art)
    fx:SetFrameLevel(art:GetFrameLevel() + 1)

    -- runas das colunas: 4 quadros de pulso subindo, 2 vizinhos cruzados em ADD
    local RU = R.runes
    local runeTex = {}
    for i = 1, 2 do
        local t = fx:CreateTexture(nil, "BACKGROUND", nil, 1)
        t:SetTexture(SHEET_MEDIA .. "ReputationRunes")
        t:SetBlendMode("ADD")
        t:SetSize(RU.w, RU.h)
        At(t, RU.x, RU.y, "TOPLEFT")
        runeTex[i] = t
    end
    local function RuneFrame(t, f)
        local u0, v0 = (f % 2) * RU.cellW / RU.atlasW, floor(f / 2) * RU.cellH / RU.atlasH
        t:SetTexCoord(u0, u0 + RU.fw / RU.atlasW, v0, v0 + RU.fh / RU.atlasH)
    end

    -- selo da mesa: brilho respirando + núcleo + ondas que se abrem no tampo
    local sx, sy = R.seal[1], R.seal[2]
    local sealGlow = fx:CreateTexture(nil, "BORDER", nil, 1)
    sealGlow:SetTexture(MEDIA_ROOT .. "Glow")
    sealGlow:SetBlendMode("ADD")
    sealGlow:SetVertexColor(0.10, 0.60, 1.0)
    At(sealGlow, sx, sy)
    local sealCore = fx:CreateTexture(nil, "BORDER", nil, 2)
    sealCore:SetTexture(MEDIA_ROOT .. "Glow")
    sealCore:SetBlendMode("ADD")
    sealCore:SetVertexColor(0.35, 0.90, 1.0)
    At(sealCore, sx, sy)
    local waves = {}
    for w = 1, 2 do
        local ring = fx:CreateTexture(nil, "BORDER", nil, 3)
        ring:SetTexture(MEDIA_ROOT .. "CastRingThin")
        ring:SetBlendMode("ADD")
        At(ring, sx, sy)
        waves[w] = ring
    end

    -- fagulhas subindo do selo em espiral (mesmo vórtice da aura do Santuário)
    local function Rand(a, b) return a + random() * (b - a) end
    local EMBER_COLORS = { { 0.20, 0.78, 1.0 }, { 0.42, 0.92, 1.0 }, { 0.78, 0.98, 1.0 }, { 0.12, 0.52, 1.0 } }
    local embers = {}
    local function SpawnEmber(p, initial)
        p.life = Rand(2.4, 4.2)
        p.t = initial and random() * p.life or 0
        p.theta = random() * 6.28318
        p.omega = Rand(0.4, 1.1) * (random() < 0.8 and 1 or -1)
        p.R = Rand(14, 66)
        p.amax = Rand(0.45, 0.9)
        p.size = Rand(2.6, 5.6)
        p.wp, p.tw = random() * 6.28, 5 + random() * 8
        local c = EMBER_COLORS[1 + floor(random() * #EMBER_COLORS)]
        p.tex:SetVertexColor(c[1], c[2], c[3])
    end
    for i = 1, 46 do
        local p = { tex = fx:CreateTexture(nil, "ARTWORK", nil, 3) }
        p.tex:SetTexture(MEDIA_ROOT .. "Glow")
        p.tex:SetBlendMode("ADD")
        p.tex:SetAlpha(0)
        SpawnEmber(p, true)
        embers[i] = p
    end

    -- poeira de luz flutuando pelo salão (os pontos azuis da arte)
    local motes = {}
    local function SpawnMote(p, initial)
        p.x = Rand(240, 1580)
        p.y = initial and Rand(240, 1060) or Rand(900, 1080)
        p.vy = Rand(6, 16)
        p.sw, p.sf, p.sp = Rand(4, 14), Rand(0.3, 0.8), random() * 6.28
        p.size = Rand(3, 8)
        p.amax = Rand(0.35, 0.85)
        p.tw = Rand(1.2, 3.2)
    end
    for i = 1, 34 do
        local p = { tex = fx:CreateTexture(nil, "ARTWORK", nil, 2) }
        p.tex:SetTexture(MEDIA_ROOT .. "Glow")
        p.tex:SetBlendMode("ADD")
        p.tex:SetVertexColor(0.45, 0.88, 1.0)
        SpawnMote(p, true)
        motes[i] = p
    end

    --==========================================================================
    -- Lista (cabeçalhos dourados + linhas recortadas da arte)
    --==========================================================================
    local LS = R.list
    local listH = LS.bottom - LS.y
    local scroll = CreateFrame("ScrollFrame", nil, art)
    scroll:SetPoint("TOPLEFT", art, "TOPLEFT", LS.x - 8, -(LS.y - 8))
    scroll:SetSize(LS.w + 16, listH + 8)
    scroll:SetFrameLevel(art:GetFrameLevel() + 6)
    scroll:EnableMouseWheel(true)
    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(LS.w + 16, 1)
    scroll:SetScrollChild(child)

    local track = art:CreateTexture(nil, "ARTWORK")
    track:SetTexture(media.blank)
    track:SetVertexColor(0.30, 0.45, 0.55, 0.25)
    track:SetSize(2, listH - 8)
    At(track, LS.x + LS.w + 12, LS.y + 4, "TOPLEFT")
    local thumb = art:CreateTexture(nil, "OVERLAY")
    thumb:SetTexture(media.blank)
    thumb:SetVertexColor(0.45, 0.88, 1.0, 0.85)
    thumb:SetWidth(2)

    local L = { rows = {}, sel = nil }
    page.list = L

    function L:UpdateThumb()
        local range = scroll:GetVerticalScrollRange()
        if range <= 0 then thumb:Hide() track:Hide() return end
        local th = track:GetHeight()
        local vis = scroll:GetHeight()
        local h = max(30, th * vis / (vis + range))
        thumb:SetHeight(h)
        At(thumb, LS.x + LS.w + 12, LS.y + 4 + (th - h) * (scroll:GetVerticalScroll() / range), "TOPLEFT")
        thumb:Show() track:Show()
    end
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local v = self:GetVerticalScroll() - delta * (R.rowH + R.gap) * 2
        self:SetVerticalScroll(max(0, min(v, self:GetVerticalScrollRange())))
        L:UpdateThumb()
    end)

    local function RowTex(parent, layer, sub, y0, w, h)
        local t = parent:CreateTexture(nil, layer, nil, sub)
        t:SetTexture(REP_ROWS)
        t:SetTexCoord(0, w / 1024, y0 / 256, (y0 + h) / 256)
        return t
    end

    local function GetRow(i)
        local row = L.rows[i]
        if row then return row end
        row = CreateFrame("Button", nil, child)
        row:SetWidth(LS.w)
        row:RegisterForClicks("LeftButtonUp")
        row.hdr = RowTex(row, "BACKGROUND", 0, 0, 822, 59)
        row.hdr:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.hdr:SetSize(822, 59)
        row.base = RowTex(row, "BACKGROUND", 0, 64, 822, 53)
        row.base:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.base:SetSize(822, 53)
        row.sel = RowTex(row, "BACKGROUND", 1, 128, 834, 65)
        row.sel:SetPoint("TOPLEFT", row, "TOPLEFT", -6, 6)
        row.sel:SetSize(834, 65)
        row.selGlow = RowTex(row, "BORDER", 0, 128, 834, 65)
        row.selGlow:SetBlendMode("ADD")
        row.selGlow:SetAllPoints(row.sel)
        row.hover = RowTex(row, "BORDER", 1, 128, 834, 65)
        row.hover:SetBlendMode("ADD")
        row.hover:SetAllPoints(row.sel)
        row.hover:SetAlpha(0.22)
        row.hover:Hide()

        row.name = RepText(row, media.font, 21, { 0.88, 0.89, 0.92 })
        row.marker = RepText(row, fontT, 22, { 0.86, 0.78, 0.62 })
        row.label = RepText(row, media.font, 17, { 0.86, 0.88, 0.90 })
        row.label:SetPoint("LEFT", row, "TOPLEFT", 448, -22)
        row.value = RepText(row, media.font, 19, { 0.92, 0.93, 0.95 }, "RIGHT")
        row.value:SetPoint("RIGHT", row, "TOPLEFT", 794, -22)
        row.track = row:CreateTexture(nil, "ARTWORK", nil, 0)
        row.track:SetTexture(media.blank)
        row.track:SetVertexColor(0.02, 0.09, 0.12, 0.85)
        row.track:SetSize(346, 4)
        row.track:SetPoint("LEFT", row, "TOPLEFT", 448, -36)
        row.fill = row:CreateTexture(nil, "ARTWORK", nil, 1)
        row.fill:SetTexture(media.blank)
        row.fill:SetHeight(5)
        row.fill:SetPoint("LEFT", row.track, "LEFT", 0, 0)

        row:SetScript("OnClick", function(r)
            if r.entry and r.entry.onClick then
                Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
                r.entry.onClick()
            end
        end)
        row:SetScript("OnEnter", function(r) if not (r.entry and r.entry.selected) then r.hover:Show() end end)
        row:SetScript("OnLeave", function(r) r.hover:Hide() end)
        L.rows[i] = row
        return row
    end

    function L:SetEntries(entries)
        local y = 8
        L.sel = nil
        for i, e in ipairs(entries) do
            local row = GetRow(i)
            row.entry = e
            row:ClearAllPoints()
            row:SetPoint("TOPLEFT", child, "TOPLEFT", 8, -y)
            local indent = (e.depth or 0) * 22
            Show(row.hdr, e.header)
            Show(row.base, not e.header and not e.selected)
            Show(row.sel, e.selected)
            Show(row.selGlow, e.selected)
            if e.selected then L.sel = row end
            row.name:ClearAllPoints()
            if e.header then
                row:SetHeight(R.hdrH)
                row.marker:ClearAllPoints()
                row.marker:SetPoint("LEFT", row, "LEFT", 20 + indent, 0)
                row.marker:SetText(e.collapsed and "+" or "–")
                row.marker:Show()
                row.name:SetFont(fontT, 22, "")
                row.name:SetTextColor(0.86, 0.78, 0.62)
                row.name:SetText(Azaath.Tracked(Azaath.Upper(e.name or "")))
                row.name:SetPoint("LEFT", row, "LEFT", 44 + indent, 0)
                y = y + R.hdrH + R.gap
            else
                row:SetHeight(R.rowH)
                row.marker:Hide()
                row.name:SetFont(media.font, 21, "")
                local col = e.dim and { 0.52, 0.55, 0.58 } or { 0.88, 0.89, 0.92 }
                row.name:SetTextColor(col[1], col[2], col[3])
                row.name:SetText(e.name or "")
                row.name:SetPoint("LEFT", row, "TOPLEFT", 20 + indent, -26)
                y = y + R.rowH + R.gap
            end
            row.name:SetWidth(400 - indent)
            local b = e.bar
            if b then
                local cr = (b.standing and b.standing <= 3) and STANDING_COLORS[b.standing] or nil
                local ratio = (b.max and b.max > 0) and max(0, min(1, (b.cur or 0) / b.max)) or 0
                row.fill:SetWidth(max(0.5, 346 * ratio))
                if cr then
                    row.fill:SetVertexColor(cr[1] * 0.7, cr[2] * 0.7, cr[3] * 0.7)
                else
                    Azaath.Gradient(row.fill, "HORIZONTAL", REP_TEAL[1][1], REP_TEAL[1][2], REP_TEAL[1][3], 1,
                        REP_TEAL[2][1], REP_TEAL[2][2], REP_TEAL[2][3], 1)
                end
                Show(row.fill, ratio > 0)
                row.label:SetText(b.label or "")
                row.value:SetText(b.text or "")
                local top = e.header and -25 or -22
                row.label:SetPoint("LEFT", row, "TOPLEFT", 448, top)
                row.value:SetPoint("RIGHT", row, "TOPLEFT", 794, top)
                row.track:SetPoint("LEFT", row, "TOPLEFT", 448, top - 14)
                row.label:Show() row.value:Show() row.track:Show()
            else
                row.label:Hide() row.value:Hide() row.track:Hide() row.fill:Hide()
            end
            row:Show()
        end
        for i = #entries + 1, #L.rows do L.rows[i]:Hide() end
        Show(L.empty, #entries == 0)
        child:SetHeight(max(1, y))
        scroll:UpdateScrollChildRect()
        local range = scroll:GetVerticalScrollRange()
        if scroll:GetVerticalScroll() > range then scroll:SetVerticalScroll(range) end
        L:UpdateThumb()
    end
    L.empty = RepText(art, media.font, 20, { 0.55, 0.60, 0.66 }, "CENTER")
    At(L.empty, LS.x + LS.w * 0.5, LS.y + 40)
    L.empty:SetText("Nenhuma facção conhecida.")
    L.empty:Hide()

    --==========================================================================
    -- Painel da direita (a moldura e o selo já estão na arte)
    --==========================================================================
    local D = {}
    page.detail = D
    local pnl = CreateFrame("Frame", nil, art)
    pnl:SetAllPoints(art)
    pnl:SetFrameLevel(art:GetFrameLevel() + 7)
    -- moldura, selo e divisória do painel (arte de conceito, conteúdo apagado)
    local PN = R.panel
    local panelBg = pnl:CreateTexture(nil, "BACKGROUND")
    panelBg:SetTexture(REP_PANEL)
    panelBg:SetTexCoord(0, PN.w / 512, 0, PN.h / 1024)
    panelBg:SetSize(PN.w, PN.h)
    At(panelBg, PN.x, PN.y, "TOPLEFT")
    local cx = R.panelCX

    D.title = RepText(pnl, media.font, 34, { 0.93, 0.93, 0.91 }, "CENTER")
    D.title:SetWidth(360)
    At(D.title, cx, 208)
    D.sub = RepText(pnl, media.font, 24, { 0.50, 0.70, 0.55 }, "CENTER")
    At(D.sub, cx, 255)

    local B = R.bar
    D.barFrame = pnl:CreateTexture(nil, "ARTWORK", nil, 0)
    D.barFrame:SetTexture(REP_PARTS)
    D.barFrame:SetTexCoord(0, B.w / 512, 0, B.h / 128)
    D.barFrame:SetSize(B.w, B.h)
    At(D.barFrame, B.x, B.y, "TOPLEFT")
    D.barFill = pnl:CreateTexture(nil, "ARTWORK", nil, 1)
    D.barFill:SetTexture(REP_PARTS)
    D.barFill:SetHeight(B.fh)
    At(D.barFill, B.fx, B.fy, "TOPLEFT")
    D.barText = RepText(pnl, media.font, 19, { 0.92, 0.94, 0.96 }, "CENTER")
    At(D.barText, cx, B.y + B.h * 0.5)

    D.text = RepText(pnl, media.font, 18, { 0.88, 0.90, 0.92 }, "CENTER")
    D.text:SetWordWrap(true)
    D.text:SetWidth(345)
    D.text:SetSpacing(2)
    At(D.text, cx, 576, "TOP")

    D.empty = RepText(pnl, media.font, 19, { 0.55, 0.60, 0.66 }, "CENTER")
    D.empty:SetWordWrap(true)
    D.empty:SetWidth(320)
    At(D.empty, cx, 595)
    D.empty:SetText("Selecione uma facção para inspecionar seus tratados.")

    D.checks = {}
    local C = R.check
    for i = 1, 3 do
        local cb = CreateFrame("Button", nil, pnl)
        cb:SetSize(330, 30)
        At(cb, C.x - 2, C.y + (i - 1) * C.pitch - 1, "TOPLEFT")
        cb.box = cb:CreateTexture(nil, "ARTWORK", nil, 0)
        cb.box:SetTexture(REP_PARTS)
        cb.box:SetTexCoord(340 / 512, 368 / 512, 0, 28 / 128)
        cb.box:SetSize(28, 28)
        cb.box:SetPoint("TOPLEFT", cb, "TOPLEFT", 2, -1)
        cb.mark = cb:CreateTexture(nil, "ARTWORK", nil, 1)
        cb.mark:SetTexture(REP_PARTS)
        cb.mark:SetTexCoord(380 / 512, 420 / 512, 0, 40 / 128)
        cb.mark:SetBlendMode("ADD")
        cb.mark:SetSize(40, 40)
        cb.mark:SetPoint("TOPLEFT", cb.box, "TOPLEFT", -3, 7)
        cb.text = RepText(cb, media.font, 20, { 0.88, 0.89, 0.92 })
        cb.text:SetPoint("LEFT", cb, "TOPLEFT", C.label - C.x + 2, -15)
        cb:SetScript("OnClick", function(self)
            if self.disabled then return end
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            if self.onToggle then self.onToggle() end
        end)
        cb:SetScript("OnEnter", function(self) if not self.disabled then self.text:SetTextColor(1, 1, 1) end end)
        cb:SetScript("OnLeave", function(self)
            local v = self.disabled and 0.48 or 0.88
            self.text:SetTextColor(v, v + 0.01, v + 0.04)
        end)
        D.checks[i] = cb
    end

    function D:Set(data)
        local has = data ~= nil
        for _, r in ipairs({ self.title, self.sub, self.barFrame, self.barFill, self.barText, self.text }) do Show(r, has) end
        Show(self.empty, not has)
        if not has then
            for _, cb in ipairs(self.checks) do cb:Hide() end
            return
        end
        self.title:SetText(data.title or "")
        self.sub:SetText(data.subtitle or "")
        local sc = RepStandingColor(data.standing)
        self.sub:SetTextColor(sc[1], sc[2], sc[3])
        local b = data.bar
        if b then
            local ratio = (b.max and b.max > 0) and max(0, min(1, (b.cur or 0) / b.max)) or 0
            local fw = max(1, B.fw * ratio)
            self.barFill:SetWidth(fw)
            -- a ponta clara da textura fica sempre na ponta do preenchimento
            local u0 = max(0, 1 - fw / 128) * 0.6
            self.barFill:SetTexCoord(u0 * 128 / 512, 128 / 512, 40 / 128, 62 / 128)
            Show(self.barFill, ratio > 0)
            self.barText:SetText(b.text or "")
        else
            self.barFill:Hide()
            self.barText:SetText("")
        end
        self.text:SetText(data.text or "")
        for i, cb in ipairs(self.checks) do
            local d = data.checks and data.checks[i]
            if d then
                cb.text:SetText(d.label)
                cb.onToggle = d.onClick
                cb.disabled = d.enabled == false
                Show(cb.mark, d.checked)
                local v = cb.disabled and 0.48 or 0.88
                cb.text:SetTextColor(v, v + 0.01, v + 0.04)
                cb:SetAlpha(cb.disabled and 0.6 or 1)
                cb:Show()
            else
                cb:Hide()
            end
        end
    end

    --==========================================================================
    -- Animação
    --==========================================================================
    local T = 0
    local anim = CreateFrame("Frame", nil, page)
    anim:SetScript("OnUpdate", function(_, elapsed)
        if elapsed > 0.05 then elapsed = 0.05 end
        T = T + elapsed
        local t = T

        local ph = (t * RU.speed) % 1 * RU.frames
        local f0 = floor(ph)
        local fr = ph - f0
        RuneFrame(runeTex[1], f0)
        RuneFrame(runeTex[2], (f0 + 1) % RU.frames)
        runeTex[1]:SetAlpha(1 - fr)
        runeTex[2]:SetAlpha(fr)

        local breath = (sin(t * 2.2) + 1) * 0.5
        local ignite = 0.45 + breath * 0.35
        sealGlow:SetSize(340 + breath * 28, 104 + breath * 8)
        sealGlow:SetAlpha(0.05 + ignite * 0.07)   -- suave: o desenho do selo tem que aparecer
        sealCore:SetSize(180 + breath * 14, 50 + breath * 4)
        sealCore:SetAlpha(0.03 + ignite * 0.05)
        for wIdx, ring in ipairs(waves) do
            local prog = (t * 0.36 + (wIdx - 1) * 0.5) % 1
            local ease = 1 - (1 - prog) * (1 - prog)
            local rw = 175 + ease * 300
            ring:SetSize(rw, rw * 0.29)
            ring:SetVertexColor(0.38, 0.92, 1.0, (1 - prog) * (0.10 + ignite * 0.12))
        end

        for _, p in ipairs(embers) do
            p.t = p.t + elapsed
            if p.t >= p.life then SpawnEmber(p, false) end
            local q = p.t / p.life
            local th = p.theta + p.omega * p.t
            local rr = p.R * (1 - q * 0.5)
            local x = sx + cos(th) * rr
            local y = sy - 6 - q * 250 + sin(th) * rr * 0.28
            local env = min(1, q * 6) * (1 - q) ^ 1.3
            local tw = 0.6 + 0.4 * sin(t * p.tw + p.wp)
            local s = p.size * (1 - q * 0.35)
            p.tex:SetSize(s, s)
            p.tex:SetPoint("CENTER", art, "TOPLEFT", x, -y)
            p.tex:SetAlpha(p.amax * env * tw * (0.8 + ignite * 0.3))
        end

        for _, p in ipairs(motes) do
            p.y = p.y - p.vy * elapsed
            if p.y < 200 then SpawnMote(p, false) end
            local x = p.x + sin(t * p.sf + p.sp) * p.sw
            local edge = min(1, (p.y - 200) / 120)
            p.tex:SetSize(p.size, p.size)
            p.tex:SetPoint("CENTER", art, "TOPLEFT", x, -p.y)
            p.tex:SetAlpha(p.amax * edge * (0.55 + 0.45 * sin(t * p.tw + p.sp)))
        end

        if L.sel then L.sel.selGlow:SetAlpha(0.10 + 0.22 * (sin(t * 2.4) + 1) * 0.5) end
    end)
end

-- compartilhado com os outros arquivos da ficha
U.BuildReputationPage = BuildReputationPage
