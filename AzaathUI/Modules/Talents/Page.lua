--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Talents/Page.lua
    Crisol de talentos: loop de animação, página na ficha e eventos.
    Símbolos comuns vêm de Azaath.TalentsUI (Modules/Talents/Core.lua).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.TalentsUI
local cos, ipairs, max, min = math.cos, ipairs, math.max, math.min
local pcall, pi, sin, tostring = pcall, math.pi, math.sin, tostring
local wipe = wipe
local ART_H, ART_W, BackOut, BuildAmbient = U.ART_H, U.ART_W, U.BackOut, U.BuildAmbient
local BuildBottom, BuildCrucible, BuildRight, BuildTop = U.BuildBottom, U.BuildCrucible, U.BuildRight, U.BuildTop
local CS, Clamp, Damp, EaseOut = U.CS, U.Clamp, U.Damp, U.EaseOut
local ICON_R, M, PlaceNode, ProcessApplyQueue = U.ICON_R, U.M, U.PlaceNode, U.ProcessApplyQueue
local SetSegUV, TAL, Tex, UpdateAmbient = U.SetSegUV, U.TAL, U.Tex, U.UpdateAmbient
local UpdateCueVisuals, UpdatePulses, anim, bottom = U.UpdateCueVisuals, U.UpdatePulses, U.anim, U.bottom
local buttonLights, nodeButtons, particles, pending = U.buttonLights, U.nodeButtons, U.particles, U.pending
local right, segs = U.right, U.segs

--------------------------------------------------------------------------------
-- Loop de animação
--------------------------------------------------------------------------------
local function Refresh()
    local ok, err = pcall(U.RebuildCrucible)
    if not ok then
        if Azaath.LogError then Azaath.LogError("Talentos: " .. tostring(err)) end
        U.treeData = nil
    end
    U.UpdateLabels()
    U.UpdateRight(false)
    U.UpdateTotals()
end

local function OnUpdate(_, dt)
    if dt > 0.05 then dt = 0.05 end
    U.clock = U.clock + dt
    local t = U.clock

    ProcessApplyQueue(dt)
    if U.dirty then
        U.dirty = false
        Refresh()
    end

    UpdateAmbient(dt, t)
    local cueKey, cueLv = UpdateCueVisuals(dt, t)
    -- pulsos (orbes que corriam pelas correntes) removidos a pedido

    -- correntes correm do núcleo para fora
    for i = 1, U.segCount do
        local s = segs[i]
        if s.style ~= "smoke" then SetSegUV(s, t * s.speed) end
    end

    local pulse = 0.5 + 0.5 * sin(t * 2.5)
    local ar = anim.reveal
    if ar then ar.t = ar.t + dt end
    for _, b in ipairs(nodeButtons) do
        if b:IsShown() and b.rec then
            local r = b.rec
            b.pop = ar and (0.01 + 0.99 * BackOut(Clamp((ar.t - b.order * 0.010) / 0.30, 0, 1))) or 1
            local isSel = (r.key == U.selKey)
            b.lift = Damp(b.lift, b.hover and 1.16 or (isSel and 1.07 or 1.0), 0.002, dt)
            PlaceNode(b)

            local st = b.state
            local want = (st == "buy") and 0.62 or (st == "max" and 0.50) or (st == "prog" and 0.38) or 0
            if b.hover then want = max(want, 0.75) end
            b.fx = Damp(b.fx, want, 0.003, dt)
            -- canto deste talento tocando: a aura cresce e acende com a música
            local cb = (cueKey and r.key == cueKey) and cueLv or 0
            local fx = max(b.fx, cb * 1.6)
            if fx > 0.01 then
                -- respiração lenta + tremulação irregular (soma de senos fora de fase)
                local s, ph, ir = t * b.sp, b.ph, b.ir or ICON_R.normal
                local breath = 0.5 + 0.5 * sin(s * 1.9 + ph)
                local flick = 0.5 + 0.5 * sin(s * 4.7 + ph * 1.7) * sin(s * 2.3 + ph * 0.6)
                local strong = ((st == "buy") and 1.25 or 1) * (1 + 0.55 * cb)
                local s1 = ir * (2.7 + 0.35 * breath) * strong
                local s2 = ir * (3.3 + 0.55 * flick) * strong
                b.aura:SetSize(s1, s1)
                b.aura2:SetSize(s2, s2)
                if b.aura.SetRotation then
                    b.aura:SetRotation(s * 0.45 * b.spin + ph)
                    b.aura2:SetRotation(-s * 0.30 * b.spin + ph * 2)
                end
                b.aura:SetAlpha(min(1, fx * (0.50 + 0.40 * breath)))
                b.aura2:SetAlpha(min(1, fx * (0.18 + 0.30 * flick) + cb * 0.25))
            else
                b.aura:SetAlpha(0)
                b.aura2:SetAlpha(0)
            end
            b.sel:SetAlpha(isSel and (0.50 + 0.25 * pulse) or 0)

            -- prévia não selada: anel ciano pulsando + onda saindo; ícone respira
            if b.staged then
                local ir = b.ir or ICON_R.normal
                local beat = 0.5 + 0.5 * sin(t * 4.2)
                local w = (t * 0.9) % 1
                b.stage:SetSize(ir * (2.75 + 0.12 * beat), ir * (2.75 + 0.12 * beat))
                b.stage:SetAlpha(0.55 + 0.40 * beat)
                b.stageWave:SetSize(ir * (2.8 + 1.4 * w), ir * (2.8 + 1.4 * w))
                b.stageWave:SetAlpha(0.75 * (1 - w) * (1 - w))
                local v = 0.72 + 0.28 * beat
                b.icon:SetVertexColor(v, v, v, 1)
                b.stagedLit = true
            elseif b.stagedLit then
                b.stagedLit = nil
                b.stage:SetAlpha(0); b.stageWave:SetAlpha(0) -- cor do ícone: ApplyNodeVisual
            end

            -- moldura de energia: fios correndo em volta do ícone
            -- apagado: moldura parada (girar devagar faz os pixels tremularem)
            if b.ring.SetRotation and not b.ringLocked then
                local sp = 0.7
                b.ring:SetRotation(t * sp * (b.sp or 1) * (b.spin or 1) + (b.ph or 0))
                b.ring2:SetRotation(-t * sp * 1.3 * (b.sp or 1) * (b.spin or 1) + (b.ph or 0) * 2)
            end
            if b.dormant and not b.hover then
                local br = 0.5 + 0.5 * sin(t * 1.6 * (b.sp or 1) + (b.ph or 0))
                b.ring:SetAlpha(0.22 + 0.28 * br)
                b.ring2:SetAlpha(0.08 + 0.14 * br)
            elseif not b.ringLocked then
                local sh = 0.5 + 0.5 * sin(t * 3.3 * (b.sp or 1) + (b.ph or 0))
                b.ring:SetAlpha(0.80 + 0.20 * sh)
                b.ring2:SetAlpha(0.45 + 0.40 * (1 - sh))
            else
                b.ring:SetAlpha(1); b.ring2:SetAlpha(1)
            end

            if (b.flashAlpha or 0) > 0 then
                b.flashAlpha = max(0, b.flashAlpha - dt * 2.4)
            end
            b.flash:SetAlpha(max(b.flashAlpha or 0, cb * 0.45))
        end
    end
    if ar and ar.t > 0.9 then anim.reveal = nil end

    local rr = anim.rightReveal
    if rr then
        rr.t = rr.t + dt
        local done = true
        for i, blk in ipairs(right.blocks) do
            local u = Clamp((rr.t - i * 0.025) / 0.30, 0, 1)
            blk:SetAlpha(EaseOut(u))
            if u < 1 then done = false end
        end
        if done then anim.rightReveal = nil end
    end

    local rf = anim.reqFlash
    if rf then
        rf.t = rf.t + dt
        local u = min(1, rf.t / 0.6)
        right.reqText:SetAlpha(0.35 + 0.65 * (0.5 + 0.5 * cos(u * pi * 4)))
        if u >= 1 then right.reqText:SetAlpha(1); anim.reqFlash = nil end
    end

    local ip = anim.iconPop
    if ip then
        ip.t = ip.t + dt
        local u = min(1, ip.t / 0.45)
        local s = 0.4 + 0.6 * BackOut(u)
        right.icon:SetSize(136 * CS * s, 136 * CS * s)
        right.flash:SetAlpha((1 - u) * 0.85)
        if u >= 1 then anim.iconPop = nil end
    end

    -- emblema do painel: raios girando, brilho e runas pulsando
    local dim = right.lockedGlow and 0.35 or 1
    if right.rays.SetRotation then right.rays:SetRotation(t * 0.22) end
    -- o canto do talento mostrado acende o ícone, os raios e as runas do card
    local cl = right.cueLv or 0
    right.rays:SetAlpha(min(1, (0.42 + 0.14 * sin(t * 1.7)) * dim + cl * 0.55))
    right.rays:SetSize(205 * CS * (1 + 0.30 * cl), 205 * CS * (1 + 0.30 * cl))
    right.glow:SetAlpha(min(1, (0.50 + 0.15 * sin(t * 2.2)) * dim + cl * 0.50))
    right.glow:SetSize(175 * CS * (1 + 0.35 * cl), 175 * CS * (1 + 0.35 * cl))
    right.iconSheen:SetAlpha((0.10 + 0.06 * sin(t * 2.6 + 1)) * dim + cl * 0.30)
    right.cardGlow:SetAlpha(min(1, 0.35 + 0.30 * (0.5 + 0.5 * sin(t * 1.8)) + cl * 0.45))
    if not anim.iconPop then right.flash:SetAlpha(cl * 0.28) end
    -- losangos acesos brilham de leve, cada um no seu tempo
    for _, g in ipairs(right.pipGlow) do g:Tick(t, g.lit and 0.75 or 0) end

    local selRec = U.treeData and U.selKey and U.treeData.byKey[U.selKey]
    local canImbue = selRec and selRec.canBuy
    local imbHov = right.imbuirBtn.hover and 1 or 0
    right.imbuirGlow:SetAlpha(Damp(right.imbuirGlow:GetAlpha() or 0,
        canImbue and min(1, imbHov * 0.45 + 0.45 + 0.20 * pulse) or (imbHov * 0.30), 0.004, dt))
    -- cristais das pontas do botão: acesos quando dá para infundir
    for _, g in ipairs(right.crystals) do g:Tick(t, canImbue and (0.85 + imbHov * 0.35) or 0.18) end

    local staged = U.treeData and (U.treeData.staged or 0) > 0
    local purgeHov = bottom.purgeBtn.hover and 1 or 0
    bottom.purgeGlow:SetAlpha(Damp(bottom.purgeGlow:GetAlpha() or 0, staged and min(1, 0.48 + purgeHov * 0.52) or purgeHov * 0.25, 0.004, dt))
    bottom.purgeTint:SetAlpha(Damp(bottom.purgeTint:GetAlpha() or 0, staged and min(1, 0.55 + 0.15 * pulse + purgeHov * 0.30) or purgeHov * 0.18, 0.004, dt))
    local sealHov = bottom.sealBtn.hover and 1 or 0
    bottom.sealGlow:SetAlpha(Damp(bottom.sealGlow:GetAlpha() or 0, staged and min(1, 0.78 + sealHov * 0.22) or sealHov * 0.25, 0.004, dt))
    bottom.sealTint:SetAlpha(Damp(bottom.sealTint:GetAlpha() or 0, staged and min(1, 0.75 + 0.20 * pulse + sealHov * 0.25) or sealHov * 0.18, 0.004, dt))
    for _, L in ipairs(buttonLights) do L:Tick(t, L.a) end
end

--------------------------------------------------------------------------------
-- Construção da página na ficha (chamada pela ficha, Modules/Sheet/)
--------------------------------------------------------------------------------
local function FitArt()
    if not (U.art and U.root) then return end
    local w, h = U.root:GetWidth(), U.root:GetHeight()
    if not (w and h and w > 0 and h > 0) then return end
    U.art:SetScale(max(w / ART_W, h / ART_H))
end

function M:BuildPage(pg, cw, ch)
    U.page = pg
    self.db = Azaath.db.talents or {}
    pg.talents = true

    U.root = pg:GetParent() and pg:GetParent():GetParent() or UIParent

    U.art = CreateFrame("Frame", nil, pg)
    U.art:SetSize(ART_W, ART_H)
    U.art:SetPoint("CENTER", U.root, "CENTER", 0, 0)
    FitArt()

    local bg = Tex(U.art, "BACKGROUND", TAL .. "CrucibleBG")
    bg:SetAllPoints(U.art)
    bg:SetTexCoord(0, 1, 0, 1143 / 2048)

    BuildAmbient()
    BuildCrucible()
    BuildTop()
    BuildRight()
    BuildBottom()

    Refresh()

    pg:SetScript("OnShow", function()
        FitArt()
        U.dirty = true
        anim.reveal = { t = 0 }
        Azaath.PlaySound("igSpellBookOpen")
    end)
    pg:SetScript("OnHide", function()
        for _, p in ipairs(particles) do p.life = 0; p.tex:Hide() end
        U.hovKey = nil
    end)
    pg:SetScript("OnUpdate", OnUpdate)
end

function M:Refresh()
    if U.page and U.page:IsShown() then U.dirty = true end
end

function M:IsActive()
    return (U.page and U.page.talents and Azaath.db.sheet and Azaath.db.sheet.enabled) and true or false
end

function M:IsOpen()
    local sheet = Azaath:GetModule("Sheet")
    return (U.page and U.page:IsVisible() and sheet and sheet.IsOpen and sheet:IsOpen()) and true or false
end

function M:Open()
    local sheet = Azaath:GetModule("Sheet")
    if sheet and sheet.Open then sheet:Open("talents") end
end

function M:Close()
    local sheet = Azaath:GetModule("Sheet")
    if sheet and sheet.Close then sheet:Close() end
end

function M:Toggle()
    local sheet = Azaath:GetModule("Sheet")
    if sheet and sheet.Toggle then sheet:Toggle("talents") end
end

local function UpdateBinding()
    if not U.bindOwner then return end
    local key1, key2 = GetBindingKey("TOGGLETALENTS")
    local signature = (key1 or "") .. "," .. (key2 or "")
    if signature == U.lastBindingSignature then return end
    Azaath:RunOutOfCombat(function()
        U.lastBindingSignature = signature
        ClearOverrideBindings(U.bindOwner)
        for _, key in ipairs({ key1, key2 }) do
            if key and key ~= "" then
                SetOverrideBindingClick(U.bindOwner, false, key, "AzaathUITalentsToggle", "LeftButton")
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    if event == "UPDATE_BINDINGS" then
        UpdateBinding()
        return
    elseif event == "DISPLAY_SIZE_CHANGED" or event == "UI_SCALE_CHANGED" then
        FitArt()
        return
    elseif event == "ACTIVE_TALENT_GROUP_CHANGED" then
        wipe(pending)
    end
    U.dirty = true
end)

function M:OnInitialize()
    self.db = Azaath.db.talents
end

function M:OnEnable()
    if not (self.db and self.db.enabled) then return end
    U.toggleButton = CreateFrame("Button", "AzaathUITalentsToggle", UIParent)
    U.toggleButton:RegisterForClicks("LeftButtonUp")
    U.toggleButton:SetScript("OnClick", function() M:Toggle() end)
    U.bindOwner = CreateFrame("Frame")
    UpdateBinding()
    for _, e in ipairs({
        "UPDATE_BINDINGS", "PLAYER_TALENT_UPDATE", "PREVIEW_TALENT_POINTS_CHANGED",
        "ACTIVE_TALENT_GROUP_CHANGED", "CHARACTER_POINTS_CHANGED", "TALENT_GROUP_ROLE_CHANGED",
        "TRAIT_CONFIG_UPDATED", "TRAIT_NODE_CHANGED", "TRAIT_TREE_CURRENCY_INFO_UPDATED",
        "TRAIT_CONFIG_LIST_UPDATED", "CONFIG_COMMIT_FAILED", "ACTIVE_COMBAT_CONFIG_CHANGED",
        "PLAYER_LEVEL_UP", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED",
        "SPELLS_CHANGED",
        "DISPLAY_SIZE_CHANGED", "UI_SCALE_CHANGED",
    }) do
        Azaath.SafeRegister(events, e)
    end
end
