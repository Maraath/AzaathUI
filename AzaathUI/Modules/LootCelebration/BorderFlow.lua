--[[----------------------------------------------------------------------------
    AzaathUI - Modules/LootCelebration/BorderFlow.lua
    Luz contínua percorrendo molduras arredondadas (modo "theme" com cor de
    raridade/ouro Azaath) e geometria de posicionamento em espaço lógico.
    Baseado em LootDopamine/WindowEffects.lua e Windowing.lua (MIT).
------------------------------------------------------------------------------]]

local _, Azaath = ...

local LC = Azaath.LootCel or {}
Azaath.LootCel = LC

local ipairs, pairs, setmetatable, tonumber, type = ipairs, pairs, setmetatable, tonumber, type
local abs, max, min, sin, floor, pi, huge = math.abs, math.max, math.min, math.sin, math.floor, math.pi, math.huge
local CreateFrame, UIParent = CreateFrame, UIParent

local MEDIA = Azaath.media.path .. "LootCelebration\\"

local function Clamp(v, a, b)
    return max(a, min(b, v))
end

--------------------------------------------------------------------------------
-- Geometria em espaço UIParent
--------------------------------------------------------------------------------
local G = {}
LC.Geometry = G

local function Num(v, fallback)
    v = tonumber(v)
    if not v or v ~= v or v == huge or v == -huge then return fallback end
    return v
end

local function Pos(v, fallback)
    v = Num(v, fallback)
    return v and v > 0 and v or fallback
end

local function RootScale()
    return Pos(UIParent:GetEffectiveScale(), 1)
end

local function RootOrigin()
    return (UIParent.GetLeft and UIParent:GetLeft()) or 0,
           (UIParent.GetBottom and UIParent:GetBottom()) or 0
end

local function Ratio(frame)
    return Pos(frame:GetEffectiveScale(), RootScale()) / RootScale()
end

function G.GetViewport()
    return Pos(UIParent:GetWidth(), 1), Pos(UIParent:GetHeight(), 1)
end

function G.GetCursor()
    if type(_G.GetCursorPosition) ~= "function" then return nil end
    local x, y = _G.GetCursorPosition()
    if not x or not y then return nil end
    local ox, oy = RootOrigin()
    local sc = RootScale()
    return x / sc - ox, y / sc - oy
end

function G.GetBounds(frame)
    local x, y = frame:GetCenter()
    if not x or not y then return nil end
    local sc = Ratio(frame)
    local w, h = frame:GetWidth() * sc, frame:GetHeight() * sc
    local ox, oy = RootOrigin()
    x, y = x * sc - ox, y * sc - oy
    return x - w * 0.5, y - h * 0.5, w, h
end

function G.Place(frame, cx, cy, scale, clampToScreen)
    scale = Pos(scale, Pos(frame:GetScale(), 1))
    frame:SetScale(scale)
    local rel = Ratio(frame)
    local sw, sh = G.GetViewport()
    cx, cy = Num(cx, sw * 0.5), Num(cy, sh * 0.5)
    if clampToScreen ~= false then
        local hw, hh = frame:GetWidth() * rel * 0.5, frame:GetHeight() * rel * 0.5
        cx = hw * 2 >= sw and sw * 0.5 or Clamp(cx, hw, sw - hw)
        cy = hh * 2 >= sh and sh * 0.5 or Clamp(cy, hh, sh - hh)
    end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", UIParent, "BOTTOMLEFT", cx / rel, cy / rel)
    return cx, cy, scale
end

function G.FitScale(baseW, baseH, wanted, minimum, maximum, margin)
    local sw, sh = G.GetViewport()
    margin = max(0, Num(margin, 0))
    baseW, baseH = Pos(baseW, 1), Pos(baseH, 1)
    local upper = min(Pos(maximum, huge),
        max(0.001, sw - 2 * margin) / baseW,
        max(0.001, sh - 2 * margin) / baseH)
    local lower = min(Pos(minimum, 0.001), upper)
    return Clamp(Pos(wanted, 1), lower, upper)
end

function G.BeginMove(frame)
    local x, y = G.GetCursor()
    local left, bottom, w, h = G.GetBounds(frame)
    if not x or not left then return nil end
    local sw, sh = G.GetViewport()
    return {
        frame = frame, mouseX = x, mouseY = y,
        cx = left + w * 0.5, cy = bottom + h * 0.5,
        scale = Pos(frame:GetScale(), 1), rootScale = RootScale(), sw = sw, sh = sh,
    }
end

function G.UpdateMove(state)
    if not state then return nil end
    local sw, sh = G.GetViewport()
    if state.rootScale ~= RootScale() or state.sw ~= sw or state.sh ~= sh then
        return nil
    end
    local x, y = G.GetCursor()
    if not x then return nil end
    return G.Place(state.frame, state.cx + x - state.mouseX, state.cy + y - state.mouseY, state.scale, true)
end

--------------------------------------------------------------------------------
-- Pulso luminoso contínuo na moldura (modo theme: cor da raridade/ouro)
--------------------------------------------------------------------------------
local JOIN_RATIOS = {
    0, 0.0189423076923, 0.0378846153846, 0.0568269230769, 0.0757692307692, 0.0947115384615,
    0.113378684807, 0.113653846154, 0.119846596357, 0.132596153846, 0.151538461538, 0.155279503106,
    0.170480769231, 0.178571428571, 0.187969924812, 0.189423076923, 0.208365384615, 0.227307692308,
    0.238095238095, 0.24625, 0.265192307692, 0.284134615385, 0.286259541985, 0.303076923077,
    0.322019230769, 0.340961538462, 0.359903846154, 0.378846153846, 0.384615384615, 0.397788461538,
    0.416730769231, 0.431034482759, 0.435673076923, 0.454615384615, 0.473557692308, 0.4925,
    0.511442307692, 0.530384615385, 0.549326923077, 0.555555555556, 0.568269230769, 0.587211538462,
    0.606153846154, 0.625096153846, 0.644038461538, 0.662980769231, 0.681923076923, 0.700865384615,
    0.705882352941, 0.719807692308, 0.73875, 0.757692307692, 0.776634615385, 0.795576923077,
    0.814519230769, 0.833461538462, 0.852403846154, 0.871346153846, 0.890288461538, 0.909230769231,
    0.928173076923, 0.947115384615, 0.966057692308, 0.985,
}

local borderEffects = setmetatable({}, { __mode = "k" })

function LC.RefreshBorderEffects()
    for effect in pairs(borderEffects) do
        effect:Refresh(true)
    end
end

local function NewTex(parent, file, blend)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetTexture(MEDIA .. file)
    t:SetBlendMode(blend or "ADD")
    t:Hide()
    return t
end

local function CornerUV(t, index, u0, v0, u1, v1)
    if index == 1 then
        t:SetTexCoord(u0, u1, v0, v1)
    elseif index == 2 then
        t:SetTexCoord(u0, v1, u1, v1, u0, v0, u1, v0)
    elseif index == 3 then
        t:SetTexCoord(u1, u0, v1, v0)
    else
        t:SetTexCoord(u1, v0, u0, v0, u1, v1, u0, v1)
    end
end

function LC.CreateBorderFlow(parent, options)
    local opts = options or {}
    local layer = CreateFrame("Frame", nil, parent)
    layer:SetAllPoints(parent)
    layer:SetFrameLevel(parent:GetFrameLevel() + 12)
    layer:EnableMouse(false)

    local effect = { frame = layer, enabled = true, dualPulse = false, opacity = 1, color = { 0.79, 0.66, 0.42 }, clock = 0, elapsed = 0 }
    local coreW = opts.thickness or 3.0
    local haloW = opts.glowWidth or 18.0
    local bands, allTextures = {}, {}

    local function Tex(file, blend)
        local t = NewTex(layer, file, blend)
        allTextures[#allTextures + 1] = t
        return t
    end

    local function AddBand(thickness, alpha, counter)
        local b = { requestedWidth = thickness, alpha = alpha, counter = counter == true, sides = {}, corners = {} }
        for i = 1, 4 do
            b.sides[i] = { Tex("border_trail.tga", "ADD"), Tex("border_trail.tga", "ADD") }
            b.corners[i] = {
                weights = {
                    Tex("border_join_start.tga", "ADD"),
                    Tex("border_join_middle.tga", "ADD"),
                    Tex("border_join_end.tga", "ADD"),
                },
            }
        end
        bands[#bands + 1] = b
    end

    AddBand(haloW * 1.7, 0.74, false)
    AddBand(max(coreW * 1.65, 5), 0.96, false)
    AddBand(max(coreW * 1.25, 3.6), 0.64, true)

    local width, height, left, top, right, bottom, perimeter, radius, arcLength
    local sides, corners = {}, {}

    local function Layout()
        local w, h = parent:GetWidth(), parent:GetHeight()
        if w == width and h == height then return end
        width, height = w, h
        local inset = opts.inset or 8
        left, top, right, bottom = inset, inset, w - inset, h - inset
        right = max(left + 1, right)
        bottom = max(top + 1, bottom)
        local horizontal, vertical = right - left, bottom - top
        radius = Clamp(tonumber(opts.radius) or 10, 0, max(0, min(horizontal, vertical) * 0.45))
        arcLength = pi * radius * 0.5
        local straightW, straightH = horizontal - 2 * radius, vertical - 2 * radius
        perimeter = 2 * (straightW + straightH) + 4 * arcLength

        sides[1] = { length = straightW, start = 0 }
        corners[1] = { start = straightW, cx = right - radius * 0.5, cy = top + radius * 0.5 }
        sides[2] = { length = straightH, start = straightW + arcLength }
        corners[2] = { start = sides[2].start + straightH, cx = right - radius * 0.5, cy = bottom - radius * 0.5 }
        sides[3] = { length = straightW, start = corners[2].start + arcLength }
        corners[3] = { start = sides[3].start + straightW, cx = left + radius * 0.5, cy = bottom - radius * 0.5 }
        sides[4] = { length = straightH, start = corners[3].start + arcLength }
        corners[4] = { start = sides[4].start + straightH, cx = left + radius * 0.5, cy = top + radius * 0.5 }

        for _, b in ipairs(bands) do
            b.width = min(b.requestedWidth, max(0.2, min(straightW, straightH) * 0.98))
            b.margin = b.width * 0.5
            local q = radius + b.width
            local ratio = radius / q
            local tile, best = 0, huge
            for i, value in ipairs(JOIN_RATIOS) do
                local delta = abs(value - ratio)
                if delta < best then tile, best = i - 1, delta end
            end
            local col, row = tile % 8, floor(tile / 8)
            local u0, v0 = (col * 64 + 2.5) / 512, (row * 64 + 2.5) / 512
            local u1, v1 = (col * 64 + 61.5) / 512, (row * 64 + 61.5) / 512
            for index, c in ipairs(b.corners) do
                for _, t in ipairs(c.weights) do
                    t:ClearAllPoints()
                    t:SetPoint("CENTER", layer, "TOPLEFT", corners[index].cx, -corners[index].cy)
                    t:SetSize(q, q)
                    CornerUV(t, index, u0, v0, u1, v1)
                end
            end
        end
    end

    local function Strip(t, index, a, b, u0, u1, thickness, alpha, r, g, blue)
        local length = b - a
        if length < 0.01 or alpha < 0.002 then t:Hide(); return end
        local mid = (a + b) * 0.5
        t:ClearAllPoints()
        if index == 1 then
            t:SetPoint("CENTER", layer, "TOPLEFT", left + radius + mid, -top)
            t:SetSize(length, thickness)
            t:SetTexCoord(u0, u1, 0, 1)
        elseif index == 2 then
            t:SetPoint("CENTER", layer, "TOPLEFT", right, -top - radius - mid)
            t:SetSize(thickness, length)
            t:SetTexCoord(u0, 0, u1, 0, u0, 1, u1, 1)
        elseif index == 3 then
            t:SetPoint("CENTER", layer, "TOPLEFT", right - radius - mid, -bottom)
            t:SetSize(length, thickness)
            t:SetTexCoord(u1, u0, 0, 1)
        else
            t:SetPoint("CENTER", layer, "TOPLEFT", left, -bottom + radius + mid)
            t:SetSize(thickness, length)
            t:SetTexCoord(u1, 0, u0, 0, u1, 1, u0, 1)
        end
        t:SetVertexColor(r or 1, g or 1, blue or 1, 1)
        t:SetAlpha(alpha)
        t:Show()
    end

    local function HidePieces()
        for _, t in ipairs(allTextures) do t:Hide() end
    end

    local function Desired()
        if not effect.enabled then return false end
        if type(opts.enabled) == "function" and not opts.enabled() then return false end
        return true
    end

    local function Envelope(distance, start, length, reverse)
        local u = ((distance - start) % perimeter) / length
        if u < 0 or u > 1 then return 0 end
        if reverse then u = 1 - u end
        local v = (u <= 0.73) and (u / 0.73) or ((1 - u) / 0.27)
        return v * v * (3 - 2 * v)
    end

    local function Draw()
        if not Desired() then
            HidePieces()
            effect.visible = false
            layer:Hide()
            return
        end
        Layout()
        if not perimeter or perimeter <= 0 then return end
        effect.visible = true

        local alpha = effect.opacity
        local trailLen = perimeter * (opts.trailFraction or 0.26)
        local headFwd = ((effect.clock * (opts.speed or 0.11)) % 1) * perimeter
        local startFwd = headFwd - trailLen * 0.73
        local headRev = ((-effect.clock * (opts.counterSpeed or 0.085) + 0.5) % 1) * perimeter
        local startRev = headRev - trailLen * 0.27

        local c = effect.color
        local drift = 0.18 + 0.06 * sin(effect.clock * 0.65)
        local r = Clamp(c[1] * (1 - drift) + drift + 0.03 * sin(effect.clock * 0.4), 0, 1)
        local g = Clamp(c[2] * (1 - drift) + drift + 0.03 * sin(effect.clock * 0.4 + 2.1), 0, 1)
        local b = Clamp(c[3] * (1 - drift) + drift + 0.03 * sin(effect.clock * 0.4 + 4.2), 0, 1)
        local cr = Clamp(0.92 * 0.55 + r * 0.45, 0, 1)
        local cg = Clamp(0.76 * 0.55 + g * 0.45, 0, 1)
        local cb = Clamp(0.42 * 0.55 + b * 0.45, 0, 1)

        for _, band in ipairs(bands) do
            if band.counter and not effect.dualPulse then
                for _, p in ipairs(band.sides) do p[1]:Hide(); p[2]:Hide() end
                for _, cn in ipairs(band.corners) do
                    for _, t in ipairs(cn.weights) do t:Hide() end
                end
            else
                local rev = band.counter
                local trailStart = rev and startRev or startFwd
                local br, bgC, bb = rev and cr or r, rev and cg or g, rev and cb or b
                local margin = band.margin
                local bandAlpha = alpha * band.alpha
                for index, side in ipairs(sides) do
                    local a, bEnd = margin, side.length - margin
                    local length = max(0, bEnd - a)
                    local start = side.start + a
                    local pieces = band.sides[index]
                    local slot = 0
                    for wrap = -1, 1 do
                        local beginning = trailStart + wrap * perimeter
                        local first = max(start, beginning)
                        local ending = min(start + length, beginning + trailLen)
                        if ending > first and slot < 2 then
                            slot = slot + 1
                            local u0, u1 = (first - beginning) / trailLen, (ending - beginning) / trailLen
                            if rev then u0, u1 = 1 - u0, 1 - u1 end
                            Strip(pieces[slot], index, first - side.start, ending - side.start, u0, u1, band.width, bandAlpha, br, bgC, bb)
                        end
                    end
                    for part = slot + 1, 2 do
                        pieces[part]:Hide()
                    end
                end

                for index, corner in ipairs(band.corners) do
                    local beginning = corners[index].start - margin
                    local span = arcLength + 2 * margin
                    for node, t in ipairs(corner.weights) do
                        local distance = beginning + (node - 1) * 0.5 * span
                        local intensity = Envelope(distance, trailStart, trailLen, rev)
                        if intensity < 0.001 then
                            t:Hide()
                        else
                            t:SetVertexColor(br, bgC, bb, 1)
                            t:SetAlpha(bandAlpha * intensity)
                            t:Show()
                        end
                    end
                end
            end
        end
    end

    function effect:SetDualPulse(on)
        self.dualPulse = on == true
        Draw()
    end

    function effect:SetEnabled(on)
        self.enabled = on == true
        if Desired() and not layer:IsShown() then layer:Show() end
        Draw()
    end

    function effect:SetColor(r, g, b)
        self.color[1], self.color[2], self.color[3] = r or 1, g or 1, b or 1
        Draw()
    end

    function effect:SetOpacity(value)
        self.opacity = Clamp(tonumber(value) or 1, 0, 1)
        Draw()
    end

    function effect:Refresh(force)
        local level = parent:GetFrameLevel() + 12
        local geomChanged = width ~= parent:GetWidth() or height ~= parent:GetHeight()
        local enabled = Desired()
        if layer:GetFrameLevel() ~= level then layer:SetFrameLevel(level) end
        if enabled and not layer:IsShown() then layer:Show() end
        if force or geomChanged or enabled ~= effect.visible then Draw() end
    end

    layer:SetScript("OnShow", Draw)
    layer:SetScript("OnHide", function()
        HidePieces()
        effect.visible = false
        effect.elapsed = 0
    end)
    layer:SetScript("OnUpdate", function(_, dt)
        if not Desired() then
            HidePieces()
            effect.visible = false
            layer:Hide()
            effect.elapsed = 0
            return
        end
        effect.elapsed = effect.elapsed + dt
        if effect.elapsed < (1 / 60 - 0.0001) then return end
        effect.clock = effect.clock + effect.elapsed
        effect.elapsed = 0
        Draw()
    end)

    borderEffects[effect] = true
    Draw()
    return effect
end
