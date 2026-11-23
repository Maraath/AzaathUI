--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Config/Setup.lua
    Assistente "Primeiros Passos": janela modal em 6 etapas (boas-vindas,
    módulos Addon x Blizzard, recursos extras, Câmera Action, visual e
    conclusão). Arte em Media/ConfigUI (tools/configui-art/gen.js).

      * Abre sozinho só na primeira instalação (AzaathUIDB.setup.seen);
        manual por /azaath setup, /azaath tutorial e pelo painel (Geral).
      * As escolhas ficam em rascunho (staged) e só vão para o banco ao
        concluir, pelos mesmos caminhos e funções do painel (U.Apply);
        reabrir mostra o estado atual sem mexer no resto das opções.
      * Combate: nunca abre em combate; se o combate começar, esconde e
        volta na mesma etapa em PLAYER_REGEN_ENABLED. Gravar e aplicar só
        acontece fora de combate.
      * Textos: chaves setup.* em Locale.lua (as linhas das etapas 3-5 usam
        os textos das próprias opções do painel).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.ConfigUI
local M = Azaath:NewModule("Setup")

local ipairs, pairs, type, format, wipe, tostring = ipairs, pairs, type, string.format, wipe, tostring
local floor, max, min = math.floor, math.max, math.min
local C, MEDIA, L, A = U.C, U.MEDIA, U.L, U.Apply
local ART = U.ART
local ICON = "Interface\\Icons\\"

local G = { W = 920, H = 660, pad = 24, headerH = 76, stepsH = 72, footerH = 60 }
local NSTEPS = 6
local CONTENT_W = G.W - G.pad * 2

--------------------------------------------------------------------------------
-- Módulos substituíveis (o primeiro caminho decide o estado mostrado; os
-- quadros da Blizzard escondidos acompanham: Addon = esconde, Blizzard = mostra)
--------------------------------------------------------------------------------
local MODULES = {
    { key = "actionbars", icon = "Ability_DualWield",
      paths = { "actionbars.enabled", "actionbars.stance.enabled", "actionbars.pet.enabled", "hideBlizzard.actionBars" } },
    { key = "player",     icon = "INV_Misc_Head_Human_01", paths = { "unitframes.player.enabled", "hideBlizzard.playerFrame" } },
    { key = "target",     icon = "Ability_Hunter_SniperShot", paths = { "unitframes.target.enabled", "hideBlizzard.targetFrame" } },
    { key = "party",      icon = "Spell_Holy_PrayerOfHealing02", paths = { "party.enabled", "hideBlizzard.partyFrames" } },
    { key = "auras",      icon = "Spell_Holy_WordFortitude",
      paths = { "auras.playerBuffs.enabled", "auras.playerDebuffs.enabled", "hideBlizzard.buffs" } },
    { key = "castbar",    icon = "Spell_Fire_FlameBolt", paths = { "castbar.player.enabled", "castbar.target.enabled" } },
    { key = "nameplates", icon = "Ability_Rogue_FindWeakness", paths = { "nameplates.enabled" } },
    { key = "combattext", icon = "Ability_Warrior_Rampage", paths = { "combattext.enabled", "combattext.hideBlizzard" } },
    { key = "minimap",    icon = "INV_Misc_Spyglass_03", paths = { "minimap.enabled", "hideBlizzard.minimap" } },
    { key = "worldmap",   icon = "INV_Misc_Map_01", paths = { "worldmap.enabled" } },
    { key = "questtracker", icon = "INV_Misc_Book_08", paths = { "questtracker.enabled", "hideBlizzard.questTracker" } },
    { key = "inventory",  icon = "INV_Misc_Bag_08", paths = { "inventory.enabled" } },
    { key = "character",  icon = "INV_Chest_Chain_05", paths = { "character.enabled" } },
    { key = "sheet",      icon = "INV_Misc_Book_09", paths = { "sheet.enabled" } },
    { key = "talents",    icon = "Ability_Marksmanship", paths = { "talents.enabled" } },
    { key = "spellbook",  icon = "INV_Misc_Book_11", paths = { "spellbook.enabled" } },
    { key = "professions", icon = "Trade_BlackSmithing", paths = { "professions.enabled" } },
    { key = "dialog",     icon = "INV_Misc_Note_01", paths = { "dialog.enabled" } },
    { key = "loot",       icon = "INV_Misc_Coin_02", paths = { "loot.enabled" } },
    { key = "merchant",   icon = "INV_Misc_Coin_01", paths = { "merchant.enabled" } },
    { key = "chat",       icon = "INV_Scroll_08", paths = { "chat.enabled" } },
}

-- Gravados à parte no fim (troca de perfil de medidas e escala, como no painel)
local LIVE = { skin = true, ["actionbars.layout"] = true, scale = true }
-- Caminhos que só valem depois de recarregar (além dos módulos)
local RELOAD = { skin = true, ["actionbars.layout"] = true }
-- Função do painel chamada ao concluir quando o caminho muda
local ONCOMMIT = {}

-- Preset "Black Desert" da Câmera Action (os mesmos valores de U.Apply.BdoPreset)
local CAM_BDO = {
    ["actioncam.enabled"] = true, ["actioncam.shoulderOffset"] = 0.45, ["actioncam.shoulderFollowsMouseLook"] = false,
    ["actioncam.dynamicPitch"] = true, ["actioncam.dynamicPitchStrength"] = 0.45, ["actioncam.minCameraZoom"] = 3,
    ["actioncam.respectMotionSickness"] = false, ["actioncam.bdoEnabled"] = true, ["actioncam.bdoIntensity"] = 0.70,
    ["actioncam.bdoHitShake"] = true, ["actioncam.bdoCastFocus"] = true, ["actioncam.bdoSkillPunch"] = true,
    ["actioncam.bdoCritImpact"] = true, ["actioncam.bdoSpeedZoom"] = true, ["actioncam.bdoCameraInertia"] = true,
}

-- Experiência Completa: recursos extras ligados
local FULL_FEATURES = {
    "compass.enabled", "experience.enabled", "micromenu.enabled", "castbar.world.enabled", "questnav.magicPath",
    "questnav.worldMarker", "loot.feed", "lootBeam.enabled", "npcCamera.enabled", "olho.enabled",
}

--------------------------------------------------------------------------------
-- Rascunho
--------------------------------------------------------------------------------
local staged = {}
local win, shade
local step, mode, resumeAfterCombat, pendingOpen, combatHide = 1, "full", false, false, false
local W = {}            -- conteúdo de cada etapa
local pages = {}

local function DBGet(path)
    local t, k = U.Resolve(path, Azaath.db)
    if t then return t[k] end
end

local function Get(path)
    local v = staged[path]
    if v ~= nil then return v end
    return DBGet(path)
end

local RefreshAll -- adiante

local function Stage(path, v, quiet)
    if v == DBGet(path) then staged[path] = nil else staged[path] = v end
    if not quiet and RefreshAll then RefreshAll() end
end

local function IsAddon(m) return Get(m.paths[1]) and true or false end

local function SetModule(m, on, quiet)
    for _, p in ipairs(m.paths) do Stage(p, on and true or false, true) end
    if not quiet then RefreshAll() end
end

local function ModChanged(m)
    for _, p in ipairs(m.paths) do if staged[p] ~= nil then return true end end
    return false
end

local function ReloadCount()
    local n = 0
    for _, m in ipairs(MODULES) do if ModChanged(m) then n = n + 1 end end
    for p in pairs(RELOAD) do if staged[p] ~= nil then n = n + 1 end end
    return n
end

local function SetAll(on)
    for _, m in ipairs(MODULES) do SetModule(m, on, true) end
    RefreshAll()
end

local function CamPreset()
    if not Get("actioncam.enabled") then return "off" end
    return Get("actioncam.bdoEnabled") and "bdo" or "classic"
end

local function SetCamPreset(v, quiet)
    if v == "off" then
        Stage("actioncam.enabled", false, true)
    elseif v == "bdo" then
        for p, val in pairs(CAM_BDO) do Stage(p, val, true) end
    else -- clássica: os padrões do addon para os mesmos caminhos
        for p in pairs(CAM_BDO) do
            local d = U.DefaultOf(p)
            if d ~= nil then Stage(p, d, true) end
        end
        Stage("actioncam.enabled", true, true)
        Stage("actioncam.bdoEnabled", false, true)
    end
    if not quiet then RefreshAll() end
end

local function ApplyFull()
    for _, m in ipairs(MODULES) do SetModule(m, true, true) end
    for _, p in ipairs(FULL_FEATURES) do Stage(p, true, true) end
    if CamPreset() == "off" then SetCamPreset("classic", true) end
    RefreshAll()
end

local function Write(path, v)
    local t, k = U.Resolve(path)
    if t then t[k] = v end
end

local function SafeApply(fn, v)
    local ok, err = pcall(fn, v)
    if not ok and Azaath.LogError then Azaath.LogError("AzaathUI setup " .. tostring(err)) end
end

-- Grava o rascunho no banco e aplica ao vivo o que não pede recarga; devolve true se precisa recarregar
local function Commit()
    if InCombatLockdown() then return false end
    local needReload = ReloadCount() > 0
    local calls, called = {}, {}
    for path, v in pairs(staged) do
        if not LIVE[path] then
            Write(path, v)
            local fn = ONCOMMIT[path]
            if fn and not called[fn] then called[fn] = true; calls[#calls + 1] = { fn, v } end
        end
    end
    for _, c in ipairs(calls) do SafeApply(c[1], c[2]) end
    -- mesma ordem do painel: grava o valor e troca o perfil de medidas
    if staged.skin ~= nil then
        Write("skin", staged.skin)
        SafeApply(A.Layout)
    end
    if staged["actionbars.layout"] ~= nil then
        Write("actionbars.layout", staged["actionbars.layout"])
        SafeApply(A.Layout)
    end
    if staged.scale ~= nil then
        Write("scale", staged.scale)
        SafeApply(A.Scale)
    end
    wipe(staged)
    local s = Azaath.db.setup
    s.seen, s.done = true, true
    if U.RefreshVisible then U.RefreshVisible() end
    return needReload
end

--------------------------------------------------------------------------------
-- Utilidades visuais
--------------------------------------------------------------------------------
local function Fade(f, to, dur, done)
    f.fFrom, f.fTo, f.fT, f.fDur, f.fDone = f:GetAlpha(), to, 0, dur or 0.2, done
    f:SetScript("OnUpdate", function(self, e)
        self.fT = self.fT + e
        local p = min(1, self.fT / self.fDur)
        p = 1 - (1 - p) * (1 - p) -- desacelera no fim
        self:SetAlpha(self.fFrom + (self.fTo - self.fFrom) * p)
        if self.slideY then
            local y = self.slideY * (1 - p)
            self:ClearAllPoints()
            self:SetPoint("TOPLEFT", self.slideParent, "TOPLEFT", 0, -y)
            self:SetPoint("BOTTOMRIGHT", self.slideParent, "BOTTOMRIGHT", 0, -y)
        end
        if p >= 1 then
            self:SetScript("OnUpdate", nil)
            local d = self.fDone
            self.fDone = nil
            if d then d(self) end
        end
    end)
end

local function Upper(s) return Azaath.Upper and Azaath.Upper(s) or s end

-- Ícone quadrado com moldura fina
local function IconBox(parent, size, path)
    local f = CreateFrame("Frame", nil, parent)
    f:SetSize(size, size)
    U.Box(f, C.bg, 1, C.gold, 0.5)
    f.tex = U.Tex(f, "ARTWORK", path)
    f.tex:SetPoint("TOPLEFT", 2, -2)
    f.tex:SetPoint("BOTTOMRIGHT", -2, 2)
    f.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    return f
end

-- Cartão translúcido com cantoneiras e filete de luz no topo
local function Plate(parent, alpha)
    local card = CreateFrame("Frame", nil, parent)
    U.Box(card, C.card, alpha or 0.82, C.gold, 0.16)
    U.CardCorners(card, 0.75)
    local glow = U.Tex(card, "BORDER")
    glow:SetHeight(1)
    glow:SetPoint("TOPLEFT", 1, -1)
    glow:SetPoint("TOPRIGHT", card, "TOP", 0, -1)
    Azaath.Gradient(glow, "HORIZONTAL", C.accent[1], C.accent[2], C.accent[3], 0.7, C.accent[1], C.accent[2], C.accent[3], 0)
    return card
end

-- Título e descrição de uma etapa
local function PageHead(page)
    local t = U.Text(page, 17, C.cream, Azaath.media.fontTitleB)
    t:SetWordWrap(false)
    t:SetPoint("TOPLEFT", page, "TOPLEFT", 2, -2)
    local d = U.Text(page, 12, C.dim)
    d:SetPoint("TOPLEFT", t, "BOTTOMLEFT", 0, -5)
    d:SetWidth(CONTENT_W - 420)
    return t, d
end

-- Rolagem suave com trilho fino
local function ScrollArea(parent)
    local sf = CreateFrame("ScrollFrame", nil, parent)
    local child = CreateFrame("Frame", nil, sf)
    child:SetSize(10, 10)
    sf:SetScrollChild(child)
    sf.child, sf.target = child, 0
    local track = U.Tex(parent, "ARTWORK", nil, C.gold[1], C.gold[2], C.gold[3], 0.10)
    track:SetWidth(3)
    track:SetPoint("TOPLEFT", sf, "TOPRIGHT", 6, 0)
    track:SetPoint("BOTTOMLEFT", sf, "BOTTOMRIGHT", 6, 0)
    local thumb = U.Tex(parent, "OVERLAY", nil, C.accent[1], C.accent[2], C.accent[3], 0.75)
    thumb:SetWidth(3)
    local function MaxScroll() return max(0, child:GetHeight() - sf:GetHeight()) end
    function sf:UpdateThumb()
        local ms, h = MaxScroll(), self:GetHeight()
        if ms <= 0 or h <= 0 then thumb:Hide(); track:Hide(); return end
        thumb:Show(); track:Show()
        local th = max(30, h * h / child:GetHeight())
        thumb:SetHeight(th)
        thumb:ClearAllPoints()
        thumb:SetPoint("TOP", track, "TOP", 0, -(h - th) * (self:GetVerticalScroll() / ms))
    end
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        self.target = max(0, min(MaxScroll(), self.target - delta * 70))
        self:SetScript("OnUpdate", function(s, e)
            local cur = s:GetVerticalScroll()
            local nv = cur + (s.target - cur) * min(1, e * 14)
            if math.abs(nv - s.target) < 0.5 then nv = s.target; s:SetScript("OnUpdate", nil) end
            s:SetVerticalScroll(nv)
            s:UpdateThumb()
        end)
    end)
    sf:SetScript("OnSizeChanged", function(self) self:UpdateThumb() end)
    return sf
end

--------------------------------------------------------------------------------
-- Etapa 1: boas-vindas
--------------------------------------------------------------------------------
local function PaintModeCard(c, hover)
    local sel = (mode == c.mode)
    local bc = (sel or hover) and C.accent or C.gold
    c:SetBackdropColor(C.card[1], C.card[2], C.card[3], sel and 0.95 or 0.8)
    c:SetBackdropBorderColor(bc[1], bc[2], bc[3], sel and 1 or (hover and 0.7 or 0.22))
    c.glow:SetShown(sel or hover)
    c.glow:SetAlpha(sel and 1 or 0.45)
    c.check:SetShown(sel)
    local t = (sel or hover) and C.accent or C.cream
    c.title:SetTextColor(t[1], t[2], t[3])
    for _, k in ipairs(c.corners) do k:SetAlpha(sel and 1 or 0.55) end
end

local function BuildWelcome(page, p)
    local halo = U.Tex(page, "BACKGROUND", MEDIA .. "Glow", C.accent[1], C.accent[2], C.accent[3], 0.32)
    halo:SetBlendMode("ADD")
    halo:SetSize(230, 230)
    halo:SetPoint("CENTER", page, "TOP", 0, -62)
    local ring = U.Tex(page, "ARTWORK", ART .. "EmblemRing", C.accent[1], C.accent[2], C.accent[3], 0.55)
    ring:SetSize(124, 124)
    ring:SetPoint("CENTER", page, "TOP", 0, -62)
    U.Spin(ring, 60)
    local emblem = U.Tex(page, "OVERLAY", ART .. "Emblem")
    emblem:SetSize(94, 94)
    emblem:SetPoint("CENTER", ring, "CENTER")

    p.title = U.Text(page, 27, C.cream, Azaath.media.fontTitle)
    p.title:SetJustifyH("CENTER")
    p.title:SetPoint("TOP", page, "TOP", 0, -124)
    p.title:SetWidth(760)
    p.body = U.Text(page, 13, C.dim)
    p.body:SetJustifyH("CENTER")
    p.body:SetSpacing(3)
    p.body:SetPoint("TOP", p.title, "BOTTOM", 0, -8)
    p.body:SetWidth(700)

    p.cards = {}
    local cw, ch, gap = 392, 170, 24
    for i, info in ipairs({ { m = "full", icon = "Spell_Holy_SurgeOfLight" }, { m = "custom", icon = "Trade_Engineering" } }) do
        local c = CreateFrame("Button", nil, page)
        c.mode = info.m
        c:SetSize(cw, ch)
        c:SetPoint("TOP", page, "TOP", (i == 1 and -1 or 1) * (cw + gap) / 2, -210)
        U.Box(c, C.card, 0.8, C.gold, 0.22)
        U.CardCorners(c, 0.6, 16)
        c.glow = U.Tex(c, "BORDER", ART .. "CardGlow", C.accent[1], C.accent[2], C.accent[3])
        c.glow:SetPoint("TOPLEFT", 1, -1)
        c.glow:SetPoint("BOTTOMRIGHT", -1, 1)
        local top = U.Tex(c, "BORDER")
        top:SetHeight(1)
        top:SetPoint("TOPLEFT", 1, -1)
        top:SetPoint("TOPRIGHT", -1, -1)
        Azaath.Gradient(top, "HORIZONTAL", C.accent[1], C.accent[2], C.accent[3], 0, C.accent[1], C.accent[2], C.accent[3], 0.7)
        c.icon = IconBox(c, 48, ICON .. info.icon)
        c.icon:SetPoint("TOPLEFT", c, "TOPLEFT", 18, -18)
        c.check = U.Tex(c, "OVERLAY", MEDIA .. "MapUI\\Check", C.accent[1], C.accent[2], C.accent[3])
        c.check:SetSize(22, 22)
        c.check:SetPoint("TOPRIGHT", c, "TOPRIGHT", -14, -14)
        c.title = U.Text(c, 15, C.cream, Azaath.media.fontTitleB)
        c.title:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 14, -2)
        c.title:SetPoint("RIGHT", c, "RIGHT", -44, 0)
        if info.m == "full" then
            c.badge = CreateFrame("Frame", nil, c)
            U.Box(c.badge, { C.accent[1] * 0.3, C.accent[2] * 0.24, C.accent[3] * 0.1 }, 1, C.accent, 0.8)
            c.badge.text = U.Text(c.badge, 10, C.accent, Azaath.media.fontBold)
            c.badge.text:SetPoint("CENTER")
            c.badge:SetPoint("TOPLEFT", c.title, "BOTTOMLEFT", 0, -6)
        end
        c.desc = U.Text(c, 12, C.dim)
        c.desc:SetSpacing(2)
        c.desc:SetPoint("TOPLEFT", c.icon, "BOTTOMLEFT", 0, -12)
        c.desc:SetPoint("RIGHT", c, "RIGHT", -18, 0)
        c:SetScript("OnEnter", function(self) PaintModeCard(self, true) end)
        c:SetScript("OnLeave", function(self) PaintModeCard(self, false) end)
        c:SetScript("OnClick", function(self)
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            mode = self.mode
            for _, o in ipairs(p.cards) do PaintModeCard(o, o == self) end
        end)
        c:SetScript("OnDoubleClick", function(self) mode = self.mode; M.Next() end)
        p.cards[i] = c
    end

    p.foot = U.Text(page, 12, C.dim, Azaath.media.fontItalic or Azaath.media.font)
    p.foot:SetJustifyH("CENTER")
    p.foot:SetPoint("TOP", page, "TOP", 0, -210 - ch - 16)
    p.foot:SetWidth(760)

    function p.Localize()
        p.title:SetText(L("setup.welcome.title"))
        p.body:SetText(L("setup.welcome.body"))
        for _, c in ipairs(p.cards) do
            c.title:SetText(Upper(L("setup.mode." .. c.mode)))
            c.desc:SetText(L("setup.mode." .. c.mode, 2))
            if c.badge then
                c.badge.text:SetText(Upper(L("setup.recommended")))
                c.badge:SetSize(c.badge.text:GetStringWidth() + 16, 18)
            end
        end
        p.foot:SetText(L("setup.welcome.foot"))
    end
    function p.Refresh()
        for _, c in ipairs(p.cards) do PaintModeCard(c, false) end
    end
end

--------------------------------------------------------------------------------
-- Etapa 2: módulos Addon x Blizzard
--------------------------------------------------------------------------------
local function PaintSeg(b, sel, hover)
    if sel then
        b:SetBackdropColor(C.accent[1] * 0.30, C.accent[2] * 0.24, C.accent[3] * 0.10, 1)
        b:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], 1)
        b.text:SetTextColor(1, 0.92, 0.72)
        b.mark:Show()
    else
        b:SetBackdropColor(C.bg[1], C.bg[2], C.bg[3], 0.95)
        local bc = hover and C.accent or C.gold
        b:SetBackdropBorderColor(bc[1], bc[2], bc[3], hover and 0.8 or 0.22)
        local t = hover and C.cream or C.dim
        b.text:SetTextColor(t[1], t[2], t[3])
        b.mark:Hide()
    end
end

local function PaintModCard(c, hover)
    local on = IsAddon(c.m)
    local bc = hover and C.accent or (on and C.gold or C.off)
    c:SetBackdropBorderColor(bc[1], bc[2], bc[3], hover and 0.7 or (on and 0.3 or 0.18))
    c.hl:SetShown(hover and true or false)
    local s = on and C.accent or C.off
    c.stripe:SetVertexColor(s[1], s[2], s[3], on and 0.95 or 0.5)
    c.icon.tex:SetDesaturated(not on)
    c.icon.tex:SetAlpha(on and 1 or 0.7)
    for _, k in ipairs(c.corners) do k:SetAlpha(on and 0.85 or 0.3) end
    PaintSeg(c.segA, on, c.segA.hover)
    PaintSeg(c.segB, not on, c.segB.hover)
    local name = L("setup.m." .. c.m.key)
    if ModChanged(c.m) then name = name .. "  " .. U.RELOAD_ICON end
    c.name:SetText(name)
end

local function ModTooltip(c)
    local extra = {}
    if ModChanged(c.m) then extra[#extra + 1] = { L("ui.reloadTip"), C.reload[1], C.reload[2], C.reload[3] } end
    extra[#extra + 1] = { L(IsAddon(c.m) and "setup.state.addon" or "setup.state.blizz"), C.dim[1], C.dim[2], C.dim[3] }
    U.Tooltip(c, L("setup.m." .. c.m.key), L("setup.m." .. c.m.key, 2), extra)
end

local function BuildModules(page, p)
    p.title, p.desc = PageHead(page)
    p.allBlizz = U.Button(page, "", 190, function() SetAll(false) end)
    p.allBlizz:SetPoint("TOPRIGHT", page, "TOPRIGHT", 0, -2)
    p.allAddon = U.Button(page, "", 190, function() SetAll(true) end, "primary", MEDIA .. "MapUI\\Check")
    p.allAddon:SetPoint("RIGHT", p.allBlizz, "LEFT", -8, 0)
    p.count = U.Text(page, 11, C.dim)
    p.count:SetJustifyH("RIGHT")
    p.count:SetPoint("TOPRIGHT", p.allBlizz, "BOTTOMRIGHT", 0, -8)

    local sf = ScrollArea(page)
    sf:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -64)
    sf:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 0)
    p.scroll = sf
    local child = sf.child

    local contentW = CONTENT_W - 12
    local gap, ch = 10, 68
    local cw = floor((contentW - gap) / 2)
    child:SetSize(contentW, 10)
    p.cards = {}
    for i, m in ipairs(MODULES) do
        local c = CreateFrame("Button", nil, child)
        c.m = m
        c:SetSize(cw, ch)
        local col, row = (i - 1) % 2, floor((i - 1) / 2)
        c:SetPoint("TOPLEFT", child, "TOPLEFT", col * (cw + gap), -row * (ch + gap))
        U.Box(c, C.card, 0.82, C.gold, 0.16)
        U.CardCorners(c, 0.8, 12)
        c.hl = U.Tex(c, "BORDER")
        c.hl:SetPoint("TOPLEFT", 1, -1)
        c.hl:SetPoint("BOTTOMRIGHT", -1, 1)
        Azaath.Gradient(c.hl, "HORIZONTAL", C.accent[1], C.accent[2], C.accent[3], 0.10, C.accent[1], C.accent[2], C.accent[3], 0)
        c.stripe = U.Tex(c, "ARTWORK")
        c.stripe:SetWidth(3)
        c.stripe:SetPoint("TOPLEFT", 1, -6)
        c.stripe:SetPoint("BOTTOMLEFT", 1, 6)
        c.icon = IconBox(c, 40, ICON .. m.icon)
        c.icon:SetPoint("LEFT", c, "LEFT", 14, 0)

        local seg = CreateFrame("Frame", nil, c)
        seg:SetSize(160, 26)
        seg:SetPoint("RIGHT", c, "RIGHT", -12, 0)
        for j, on in ipairs({ true, false }) do
            local b = CreateFrame("Button", nil, seg)
            b:SetSize(79, 26)
            b:SetPoint("LEFT", seg, "LEFT", (j - 1) * 81, 0)
            Azaath.SetBackdrop(b, U.Backdrop())
            b.mark = U.Tex(b, "OVERLAY", MEDIA .. "Diamond", C.accent[1], C.accent[2], C.accent[3])
            b.mark:SetSize(7, 7)
            b.mark:SetPoint("LEFT", b, "LEFT", 7, 0)
            b.text = U.Text(b, 11, C.dim, Azaath.media.fontBold)
            b.text:SetWordWrap(false)
            b.text:SetJustifyH("CENTER")
            b.text:SetPoint("LEFT", 12, 0)
            b.text:SetPoint("RIGHT", -4, 0)
            b:SetScript("OnEnter", function(self) self.hover = true; PaintModCard(c, true); ModTooltip(c) end)
            b:SetScript("OnLeave", function(self) self.hover = false; PaintModCard(c, false); U.HideTip() end)
            b:SetScript("OnClick", function()
                if IsAddon(m) == on then return end
                Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
                SetModule(m, on)
                ModTooltip(c)
            end)
            if on then c.segA = b else c.segB = b end
        end

        c.name = U.Text(c, 13, C.cream, Azaath.media.fontBold)
        c.name:SetWordWrap(false)
        c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 12, -1)
        c.name:SetPoint("RIGHT", seg, "LEFT", -10, 0)
        c.desc = U.Text(c, 11, C.dim)
        c.desc:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -4)
        c.desc:SetPoint("RIGHT", seg, "LEFT", -10, 0)
        c.desc:SetHeight(28)
        c.desc:SetJustifyV("TOP")

        c:SetScript("OnEnter", function(self) PaintModCard(self, true); ModTooltip(self) end)
        c:SetScript("OnLeave", function(self) PaintModCard(self, false); U.HideTip() end)
        c:SetScript("OnClick", function(self) -- clicar no cartão alterna
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            SetModule(m, not IsAddon(m))
            ModTooltip(self)
        end)
        p.cards[i] = c
    end
    local rows = math.ceil(#MODULES / 2)
    child:SetHeight(rows * ch + (rows - 1) * gap + 4)

    function p.Localize()
        p.title:SetText(Upper(L("setup.step2.title")))
        p.desc:SetText(L("setup.step2.desc"))
        p.allAddon.text:SetText(L("setup.allAddon"))
        p.allBlizz.text:SetText(L("setup.allBlizz"))
        p.allAddon.tipTitle, p.allAddon.tipBody = L("setup.allAddon"), L("setup.allAddon", 2)
        p.allBlizz.tipTitle, p.allBlizz.tipBody = L("setup.allBlizz"), L("setup.allBlizz", 2)
        for _, c in ipairs(p.cards) do
            c.desc:SetText(L("setup.m." .. c.m.key, 2) or "")
            c.segA.text:SetText(L("setup.addon"))
            c.segB.text:SetText(L("setup.blizz"))
        end
    end
    function p.Refresh()
        local n = 0
        for _, c in ipairs(p.cards) do
            PaintModCard(c, c:IsMouseOver() and true or false)
            if IsAddon(c.m) then n = n + 1 end
        end
        p.count:SetText(format(L("setup.count"), n, #MODULES))
        sf:UpdateThumb()
    end
end

--------------------------------------------------------------------------------
-- Etapas 3-5: linhas do próprio painel (interruptor, escolha, slider)
-- gravando no rascunho. onCommit = função do painel chamada ao concluir;
-- needsReload = só vale após recarregar; when = condição lida do rascunho.
--------------------------------------------------------------------------------
local function D(t, path, extra)
    local def = { t = t, path = path,
        get = function() return Get(path) end,
        set = function(v) Stage(path, v) end }
    for k, v in pairs(extra or {}) do def[k] = v end
    if def.onCommit then ONCOMMIT[path] = def.onCommit end
    if def.needsReload then RELOAD[path] = true end
    return def
end

local function CamOn() return Get("actioncam.enabled") and true or false end
local function Cam(t, path, extra)
    extra = extra or {}
    extra.onCommit = A.ActionCam
    extra.when = extra.when or CamOn
    extra.why = extra.why or "setup.why.cam"
    return D(t, path, extra)
end

local function FeatureDefs()
    return {
        D("toggle", "compass.enabled", { onCommit = A.CompassEnabled }),
        D("toggle", "experience.enabled", { onCommit = A.ExperienceEnabled }),
        D("toggle", "micromenu.enabled", { onCommit = A.MicroMenu }),
        D("toggle", "castbar.world.enabled", { onCommit = A.CastBar }),
        D("toggle", "questnav.magicPath", { onCommit = A.MagicPath }),
        D("toggle", "questnav.worldMarker"),
        D("toggle", "questroute.autoQuest"),
        D("toggle", "loot.autoLoot"),
        D("toggle", "loot.feed"),
        D("toggle", "lootBeam.enabled", { onCommit = A.LootBeam }),
        D("toggle", "npcCamera.enabled", { onCommit = A.NpcCamera }),
        D("toggle", "merchant.autoRepair"),
        D("toggle", "inventory.unified", { onCommit = A.InventoryUnified }),
        D("toggle", "olho.enabled", { onCommit = A.Olho }),
        D("toggle", "skins.tooltips", { needsReload = true }),
        D("toggle", "skins.popups", { needsReload = true }),
    }
end

local function CameraDefs()
    for p in pairs(CAM_BDO) do ONCOMMIT[p] = A.ActionCam end
    local function Crosshair() return CamOn() and Get("actioncam.crosshair") and true or false end
    return {
        { t = "choice", path = "setup.camPreset",
          options = { { v = "off" }, { v = "classic" }, { v = "bdo" } },
          get = CamPreset, set = function(v) SetCamPreset(v) end },
        Cam("slider", "actioncam.mouseLookSpeed", { min = 20, max = 200, step = 5, fmt = "%d%%" }),
        Cam("slider", "actioncam.shoulderOffset", { min = -3.0, max = 3.0, step = 0.1, fmt = "%.1f" }),
        Cam("toggle", "actioncam.crosshair"),
        Cam("choice", "actioncam.crosshairStyle", { when = Crosshair,
            options = { { v = "diamond" }, { v = "ring" }, { v = "dot" }, { v = "cross" }, { v = "star" } } }),
        Cam("toggle", "actioncam.reticleTargeting"),
        Cam("toggle", "actioncam.interactionHUD"),
        Cam("toggle", "actioncam.crosshairTargetPreview"),
        Cam("toggle", "actioncam.autoTargetLockOnAttack"),
        Cam("choice", "actioncam.bindings.button1.value",
            { options = { { v = "ACTIONBUTTON1" }, { v = "STARTATTACK" }, { v = "TARGETMOUSEOVER" } } }),
        Cam("choice", "actioncam.bindings.button2.value",
            { options = { { v = "ACTIONBUTTON2" }, { v = "INTERACTMOUSEOVER" }, { v = "CLEARTARGET" } } }),
        Cam("toggle", "actioncam.radialEnabled"),
    }
end

local function VisualDefs()
    return {
        D("choice", "skin", { options = { { v = "modern" }, { v = "azaath" }, { v = "bdo" } } }),
        D("choice", "actionbars.layout", { options = { { v = "bdo" }, { v = "split" }, { v = "az" } },
            when = function() return Get("skin") ~= "azaath" end, why = "why.notAzaath" }),
        D("slider", "scale", { min = 0.6, max = 1.5, step = 0.05, fmt = "%.2fx" }),
    }
end

local function BuildRows(key, icon, defs)
    return function(page, p)
        p.title, p.desc = PageHead(page)
        local badge = IconBox(page, 34, ICON .. icon)
        badge:SetPoint("TOPRIGHT", page, "TOPRIGHT", -14, -4)

        local sf = ScrollArea(page)
        sf:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -56)
        sf:SetPoint("BOTTOMRIGHT", page, "BOTTOMRIGHT", -12, 0)
        local child = sf.child
        local w = CONTENT_W - 12
        child:SetWidth(w)
        local card = Plate(child)
        card:SetPoint("TOPLEFT", child, "TOPLEFT", 0, 0)
        card:SetWidth(w)
        p.note = U.Text(child, 12, C.dim, Azaath.media.fontItalic or Azaath.media.font)
        p.note:SetPoint("TOPLEFT", card, "BOTTOMLEFT", 4, -12)
        p.note:SetWidth(w - 8)

        p.rows = {}
        for i, def in ipairs(defs) do
            local row = U.BUILDERS[def.t](card, def)
            -- losango de recarga no rótulo quando a escolha pede /reload
            local base = row.LocalizeExtra
            row.LocalizeExtra = function(self)
                if base then base(self) end
                if RELOAD[def.path] then self.label:SetText(L(def.path) .. "  " .. U.RELOAD_ICON) end
            end
            p.rows[i] = row
        end

        function p.Layout()
            local y = 8
            for i, row in ipairs(p.rows) do
                local h = row:Measure(w - 16)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", card, "TOPLEFT", 8, -y)
                row:SetSize(w - 16, h)
                row.sep:SetShown(i > 1)
                y = y + h
            end
            card:SetHeight(y + 8)
            child:SetHeight(y + 8 + 12 + (p.note:GetStringHeight() or 14) + 8)
            sf:UpdateThumb()
        end
        function p.Localize()
            p.title:SetText(Upper(L("setup." .. key .. ".title")))
            p.desc:SetText(L("setup." .. key .. ".desc"))
            p.note:SetText(L("setup." .. key .. ".note"))
            for _, row in ipairs(p.rows) do row:Localize() end
            p.Layout()
        end
        function p.Refresh()
            for _, row in ipairs(p.rows) do row:Refresh() end
        end
    end
end

--------------------------------------------------------------------------------
-- Etapa 6: dicas e conclusão
--------------------------------------------------------------------------------
local TIPS = { "/azaath", "/azaath edit", "/azaath setup", "/azaath toggle", "/olho", "/azaath help" }
local FEATURE_DEFS, CAMERA_DEFS, VISUAL_DEFS

local function SmallCard(page)
    local card = Plate(page)
    local mark = U.Tex(card, "ARTWORK", MEDIA .. "Diamond", C.accent[1], C.accent[2], C.accent[3])
    mark:SetSize(9, 9)
    mark:SetPoint("TOPLEFT", card, "TOPLEFT", 16, -19)
    card.title = U.Text(card, 13, C.accent, Azaath.media.fontTitleB)
    card.title:SetWordWrap(false)
    card.title:SetPoint("TOPLEFT", mark, "TOPRIGHT", 8, 3)
    return card
end

local function BuildFinish(page, p)
    p.title, p.desc = PageHead(page)
    local seal = U.Tex(page, "ARTWORK", ART .. "Emblem")
    seal:SetSize(46, 46)
    seal:SetPoint("TOPRIGHT", page, "TOPRIGHT", -8, 4)

    local half = floor((CONTENT_W - 16) / 2)
    local NL = 8
    local tips = SmallCard(page)
    tips:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -58)
    tips:SetSize(half, 48 + NL * 30)
    p.tips = tips
    p.tipRows = {}
    for i, cmd in ipairs(TIPS) do
        local c = U.Text(tips, 12, C.accent, Azaath.media.fontBold)
        c:SetWordWrap(false)
        c:SetPoint("TOPLEFT", tips, "TOPLEFT", 18, -46 - (i - 1) * 38)
        c:SetText(cmd)
        local d = U.Text(tips, 11, C.dim)
        d:SetPoint("TOPLEFT", c, "BOTTOMLEFT", 0, -3)
        d:SetWidth(half - 36)
        d:SetWordWrap(false)
        p.tipRows[i] = d
    end

    local sum = SmallCard(page)
    sum:SetPoint("TOPLEFT", tips, "TOPRIGHT", 16, 0)
    sum:SetSize(half, 48 + NL * 30)
    p.sum = sum
    p.lines = {}
    for i = 1, NL do
        local k = U.Text(sum, 12, C.dim)
        k:SetWordWrap(false)
        k:SetPoint("TOPLEFT", sum, "TOPLEFT", 18, -48 - (i - 1) * 30)
        local v = U.Text(sum, 12, C.cream, Azaath.media.fontBold)
        v:SetWordWrap(false)
        v:SetJustifyH("RIGHT")
        v:SetPoint("TOPRIGHT", sum, "TOPRIGHT", -18, -48 - (i - 1) * 30)
        v:SetPoint("LEFT", k, "RIGHT", 8, 0)
        local sep = U.Tex(sum, "BORDER", nil, C.gold[1], C.gold[2], C.gold[3], 0.08)
        sep:SetHeight(1)
        sep:SetPoint("TOPLEFT", sum, "TOPLEFT", 16, -40 - (i - 1) * 30)
        sep:SetPoint("TOPRIGHT", sum, "TOPRIGHT", -16, -40 - (i - 1) * 30)
        p.lines[i] = { k = k, v = v }
    end

    p.where = U.Text(page, 12, C.dim, Azaath.media.fontItalic or Azaath.media.font)
    p.where:SetJustifyH("CENTER")
    p.where:SetPoint("TOP", page, "TOP", 0, -58 - (48 + NL * 30) - 14)
    p.where:SetWidth(CONTENT_W)

    function p.Localize()
        p.title:SetText(Upper(L("setup.step6.title")))
        p.desc:SetText(L("setup.step6.desc"))
        tips.title:SetText(Upper(L("setup.tips")))
        sum.title:SetText(Upper(L("setup.summary")))
        for i, d in ipairs(p.tipRows) do d:SetText(L("setup.tip." .. i)) end
        p.where:SetText(L("setup.where"))
    end
    function p.Refresh()
        local nA = 0
        for _, m in ipairs(MODULES) do if IsAddon(m) then nA = nA + 1 end end
        local nF = 0
        for _, def in ipairs(FEATURE_DEFS) do if Get(def.path) then nF = nF + 1 end end
        local skin = Get("skin") or "modern"
        local layout = Get("actionbars.layout") or "az"
        local n = ReloadCount()
        local data = {
            { "setup.sum.addon", format("%d / %d", nA, #MODULES) },
            { "setup.sum.blizz", format("%d / %d", #MODULES - nA, #MODULES) },
            { "setup.sum.features", format("%d / %d", nF, #FEATURE_DEFS) },
            { "setup.sum.camera", L("o.setup.camPreset=" .. CamPreset()) },
            { "skin", L("o.skin=" .. skin) },
            { "actionbars.layout", skin == "azaath" and L("setup.sum.hud") or L("o.actionbars.layout=" .. layout) },
            { "scale", format("%.2fx", Get("scale") or 1) },
            { "setup.sum.reload", n > 0 and ("|cfffa9438" .. format(L("setup.sum.reloadN"), n) .. "|r") or L("setup.sum.none") },
        }
        for i, l in ipairs(p.lines) do
            l.k:SetText(L(data[i][1]))
            l.v:SetText(data[i][2])
        end
    end
end

--------------------------------------------------------------------------------
-- Janela
--------------------------------------------------------------------------------
local stepBtns, stepSegs, header, footer = {}, {}, {}, {}

local function PaintSteps()
    for i, b in ipairs(stepBtns) do
        local cur, done = (i == step), (i < step)
        local c = (cur or b.hover) and C.accent or (done and C.gold or C.off)
        b.gem:SetVertexColor(c[1], c[2], c[3], (cur or done or b.hover) and 1 or 0.55)
        local s = (cur and 26) or (b.hover and 24) or 21
        b.gem:SetSize(s, s)
        b.mount:SetAlpha((cur or done or b.hover) and 1 or 0.55)
        b.ring:SetShown(cur)
        b.halo:SetShown(cur)
        b.num:SetTextColor(cur and 0.10 or 0.92, cur and 0.08 or 0.88, cur and 0.04 or 0.80)
        b.num:SetAlpha((cur or done or b.hover) and 1 or 0.6)
        local t = (cur or b.hover) and C.accent or (done and C.cream or C.dim)
        b.label:SetTextColor(t[1], t[2], t[3])
    end
    for i, s in ipairs(stepSegs) do
        local on = i < step
        local c = on and C.accent or C.gold
        s:SetVertexColor(c[1], c[2], c[3], on and 0.8 or 0.18)
    end
end

local function UpdateFooter()
    local n = ReloadCount()
    footer.back:SetShown(step > 1)
    footer.skip:SetShown(step < NSTEPS)
    if n > 0 then
        footer.pending:SetText(U.RELOAD_ICON .. "  " .. format(L("setup.pending"), n))
        footer.pending:Show()
    else
        footer.pending:Hide()
    end
    local key
    if step < NSTEPS then key = "setup.next"
    elseif n > 0 then key = "setup.applyReload"
    else key = "setup.finish" end
    footer.next.text:SetText(L(key))
    footer.next:SetWidth(max(150, footer.next.text:GetStringWidth() + 44))
    footer.next.tipTitle = (key == "setup.applyReload") and L(key) or nil
    footer.next.tipBody = (key == "setup.applyReload") and L("setup.applyReloadTip") or nil
end

function RefreshAll()
    if not win then return end
    local p = W[step]
    if p and p.Refresh then p.Refresh() end
    PaintSteps()
    UpdateFooter()
end

local function ShowStep(i, instant)
    i = max(1, min(NSTEPS, i))
    local prev = step
    step = i
    for j, pg in ipairs(pages) do
        if j ~= i then pg:Hide() end
    end
    local pg = pages[i]
    pg:Show()
    if instant or prev == i then
        pg:SetScript("OnUpdate", nil)
        pg:SetAlpha(1)
        pg:ClearAllPoints()
        pg:SetAllPoints(pg.slideParent)
    else
        pg:SetAlpha(0)
        pg.slideY = (i > prev) and 10 or -10
        Fade(pg, 1, 0.22, function(self) self.slideY = nil end)
    end
    if W[i] and W[i].Refresh then W[i].Refresh() end
    PaintSteps()
    UpdateFooter()
end

local VISUAL_STEP = 5

function M.Next()
    if step == 1 then
        Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        if mode == "full" then
            ApplyFull()
            ShowStep(VISUAL_STEP)
        else
            ShowStep(2)
        end
    elseif step < NSTEPS then
        ShowStep(step + 1)
    else
        M.Finish()
    end
end

local function Localize()
    if not win then return end
    header.title:SetText(Upper(L("setup.title")))
    header.sub:SetText(L("setup.subtitle"))
    header.close.tipTitle = L("ui.close")
    for i, b in ipairs(stepBtns) do
        b.label:SetText(Upper(L("setup.step." .. i)))
    end
    footer.back.text:SetText(L("setup.back"))
    footer.skip.text:SetText(L("setup.skip"))
    footer.skip.tipTitle, footer.skip.tipBody = L("setup.skip"), L("setup.skipTip")
    for i = 1, NSTEPS do if W[i] and W[i].Localize then W[i].Localize() end end
    for lang, b in pairs(header.lang) do
        local on = (lang == U.LangCode())
        b:SetBackdropColor(on and C.accent[1] * 0.3 or 0, on and C.accent[2] * 0.24 or 0, on and C.accent[3] * 0.1 or 0, on and 1 or 0.4)
        b:SetBackdropBorderColor(C.accent[1], C.accent[2], C.accent[3], on and 0.9 or 0.2)
        local t = on and C.accent or C.dim
        b.text:SetTextColor(t[1], t[2], t[3])
    end
    RefreshAll()
end

-- Cabe na tela com qualquer UIScale (e respeita o tamanho escolhido para o painel)
local function FitScale()
    local cfg = Azaath.db and Azaath.db.config
    local want = cfg and cfg.scale or 1
    local pw, ph = UIParent:GetWidth() or G.W, UIParent:GetHeight() or G.H
    local fit = min((pw - 40) / G.W, (ph - 60) / G.H)
    win:SetScale(max(0.5, min(want, fit)))
end

local function BuildHeader()
    local h = CreateFrame("Frame", nil, win)
    h:SetPoint("TOPLEFT", win, "TOPLEFT", G.pad, -G.pad + 6)
    h:SetPoint("TOPRIGHT", win, "TOPRIGHT", -G.pad, -G.pad + 6)
    h:SetHeight(G.headerH - G.pad)
    h:EnableMouse(true)
    h:RegisterForDrag("LeftButton")
    h:SetScript("OnDragStart", function() win:StartMoving() end)
    h:SetScript("OnDragStop", function() win:StopMovingOrSizing() end)

    local halo = U.Tex(h, "BACKGROUND", MEDIA .. "Glow", C.accent[1], C.accent[2], C.accent[3], 0.35)
    halo:SetSize(96, 96)
    halo:SetBlendMode("ADD")
    halo:SetPoint("CENTER", h, "LEFT", 26, 0)
    local emblem = U.Tex(h, "ARTWORK", ART .. "Emblem")
    emblem:SetSize(48, 48)
    emblem:SetPoint("CENTER", h, "LEFT", 26, 0)
    header.title = U.Text(h, 22, C.gold, Azaath.media.fontTitleB)
    header.title:SetWordWrap(false)
    header.title:SetPoint("TOPLEFT", h, "LEFT", 62, 16)
    header.sub = U.Text(h, 13, C.dim, Azaath.media.fontItalic or Azaath.media.font)
    header.sub:SetWordWrap(false)
    header.sub:SetPoint("TOPLEFT", header.title, "BOTTOMLEFT", 1, -3)

    header.close = U.IconButton(h, 30, MEDIA .. "MapUI\\Close", function() M.Close() end)
    header.close:SetPoint("RIGHT", h, "RIGHT", 4, 0)

    header.lang = {}
    local prev
    for _, lang in ipairs({ "enUS", "ptBR" }) do
        local b = U.Button(h, L("ui.langShort." .. lang), 40, function()
            Azaath.db.config.lang = lang
            if U.Relocalize then U.Relocalize() end
            Localize()
        end)
        b:SetHeight(26)
        b:SetScript("OnLeave", function() Localize(); U.HideTip() end)
        if prev then b:SetPoint("RIGHT", prev, "LEFT", -4, 0)
        else b:SetPoint("RIGHT", header.close, "LEFT", -14, 0) end
        header.lang[lang] = b
        prev = b
    end

    local div = CreateFrame("Frame", nil, win)
    div:SetHeight(22)
    div:SetPoint("TOPLEFT", win, "TOPLEFT", G.pad, -G.headerH + 12)
    div:SetPoint("TOPRIGHT", win, "TOPRIGHT", -G.pad, -G.headerH + 12)
    U.Divider(div, 0.55)
end

local function BuildSteps()
    local bar = CreateFrame("Frame", nil, win)
    bar:SetPoint("TOPLEFT", win, "TOPLEFT", G.pad, -G.headerH - 6)
    bar:SetPoint("TOPRIGHT", win, "TOPRIGHT", -G.pad, -G.headerH - 6)
    bar:SetHeight(G.stepsH)
    local slot = CONTENT_W / NSTEPS
    local GY = -20 -- centro das gemas
    for i = 1, NSTEPS do
        local b = CreateFrame("Button", nil, bar)
        b:SetSize(slot, G.stepsH - 6)
        b:SetPoint("TOPLEFT", bar, "TOPLEFT", (i - 1) * slot, 0)
        b.halo = U.Tex(b, "BACKGROUND", MEDIA .. "Glow", C.accent[1], C.accent[2], C.accent[3], 0.45)
        b.halo:SetBlendMode("ADD")
        b.halo:SetSize(76, 76)
        b.halo:SetPoint("CENTER", b, "TOP", 0, GY)
        b.ring = U.Tex(b, "BORDER", ART .. "StepRing", C.accent[1], C.accent[2], C.accent[3], 0.8)
        b.ring:SetSize(62, 62)
        b.ring:SetPoint("CENTER", b, "TOP", 0, GY)
        U.Spin(b.ring, 14)
        b.mount = U.Tex(b, "ARTWORK", ART .. "StepMount")
        b.mount:SetSize(42, 42)
        b.mount:SetPoint("CENTER", b, "TOP", 0, GY)
        b.gem = U.Tex(b, "OVERLAY", ART .. "StepGem")
        b.gem:SetPoint("CENTER", b, "TOP", 0, GY)
        b.num = U.Text(b, 11, C.bg, Azaath.media.fontBold, "OVERLAY")
        b.num:SetJustifyH("CENTER")
        b.num:SetPoint("CENTER", b, "TOP", 0, GY)
        b.num:SetText(tostring(i))
        b.label = U.Text(b, 10, C.dim, Azaath.media.fontTitleB)
        b.label:SetWordWrap(false)
        b.label:SetJustifyH("CENTER")
        b.label:SetPoint("TOP", b, "TOP", 0, -46)
        b:SetScript("OnEnter", function(self) self.hover = true; PaintSteps() end)
        b:SetScript("OnLeave", function(self) self.hover = false; PaintSteps() end)
        b:SetScript("OnClick", function()
            if step == i then return end
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            ShowStep(i)
        end)
        stepBtns[i] = b
        if i > 1 then
            local s = U.Tex(bar, "BORDER")
            s:SetHeight(1)
            s:SetPoint("LEFT", bar, "TOPLEFT", (i - 1.5) * slot + 26, GY)
            s:SetPoint("RIGHT", bar, "TOPLEFT", (i - 0.5) * slot - 26, GY)
            stepSegs[i - 1] = s
        end
    end
end

local function BuildFooter()
    local f = CreateFrame("Frame", nil, win)
    f:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", G.pad, 14)
    f:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -G.pad, 14)
    f:SetHeight(G.footerH - 18)
    local line = CreateFrame("Frame", nil, f)
    line:SetHeight(22)
    line:SetPoint("TOPLEFT", f, "TOPLEFT", 0, 16)
    line:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, 16)
    U.Divider(line, 0.35)

    footer.skip = U.Button(f, "", 150, function() M.Close() end, "ghost")
    footer.skip:SetPoint("LEFT", f, "LEFT", -6, -4)
    footer.next = U.Button(f, "", 150, function() M.Next() end, "primary")
    footer.next:SetHeight(32)
    footer.next:SetPoint("RIGHT", f, "RIGHT", 0, -4)
    footer.back = U.Button(f, "", 110, function() ShowStep(step - 1) end)
    footer.back:SetHeight(32)
    footer.back:SetPoint("RIGHT", footer.next, "LEFT", -10, 0)
    footer.pending = U.Text(f, 12, C.reload, Azaath.media.fontBold)
    footer.pending:SetWordWrap(false)
    footer.pending:SetPoint("RIGHT", footer.back, "LEFT", -16, 0)
end

local function Build()
    shade = CreateFrame("Frame", nil, UIParent)
    shade:SetAllPoints(UIParent)
    shade:SetFrameStrata("FULLSCREEN_DIALOG")
    shade:SetFrameLevel(1)
    shade:EnableMouse(true) -- modal: bloqueia cliques no resto da interface
    local dark = U.Tex(shade, "BACKGROUND", nil, 0, 0, 0, 0.6)
    dark:SetAllPoints()
    shade:Hide()

    win = CreateFrame("Frame", "AzaathUISetup", UIParent)
    win:SetSize(G.W, G.H)
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    win:SetFrameStrata("FULLSCREEN_DIALOG")
    win:SetFrameLevel(20)
    win:SetToplevel(true)
    win:EnableMouse(true)
    win:SetMovable(true)
    win:SetClampedToScreen(true)
    U.Box(win, C.bg, 1, C.gold, 0.6)
    win:Hide()
    tinsert(UISpecialFrames, "AzaathUISetup")

    local inner = CreateFrame("Frame", nil, win)
    inner:SetPoint("TOPLEFT", 6, -6)
    inner:SetPoint("BOTTOMRIGHT", -6, 6)
    Azaath.SetBackdrop(inner, { edgeFile = Azaath.media.blank, edgeSize = 1 })
    inner:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 0.18)
    local topGlow = U.Tex(win, "BACKGROUND", nil)
    topGlow:SetDrawLayer("BACKGROUND", 2)
    topGlow:SetPoint("TOPLEFT", 1, -1)
    topGlow:SetPoint("TOPRIGHT", -1, -1)
    topGlow:SetHeight(200)
    Azaath.Gradient(topGlow, "VERTICAL", C.accent[1], C.accent[2], C.accent[3], 0, C.accent[1], C.accent[2], C.accent[3], 0.06)
    U.Chrome(win, 104)

    BuildHeader()
    BuildSteps()
    BuildFooter()

    FEATURE_DEFS, CAMERA_DEFS, VISUAL_DEFS = FeatureDefs(), CameraDefs(), VisualDefs()
    local body = CreateFrame("Frame", nil, win)
    body:SetPoint("TOPLEFT", win, "TOPLEFT", G.pad, -G.headerH - G.stepsH - 4)
    body:SetPoint("BOTTOMRIGHT", win, "BOTTOMRIGHT", -G.pad, G.footerH + 8)
    local builders = {
        BuildWelcome,
        BuildModules,
        BuildRows("step3", "INV_Misc_Gem_Variety_01", FEATURE_DEFS),
        BuildRows("step4", "Ability_EyeOfTheOwl", CAMERA_DEFS),
        BuildRows("step5", "INV_Misc_Head_Human_01", VISUAL_DEFS),
        BuildFinish,
    }
    for i, fn in ipairs(builders) do
        local pg = CreateFrame("Frame", nil, body)
        pg:SetAllPoints(body)
        pg.slideParent = body
        pg:Hide()
        W[i] = {}
        fn(pg, W[i])
        pages[i] = pg
    end

    win:SetScript("OnShow", function()
        win.closing = nil
        Azaath.PlaySound("igCharacterInfoOpen")
        FitScale()
        shade:Show()
    end)
    win:SetScript("OnHide", function()
        U.HideTip()
        shade:Hide()
        if combatHide then return end
        Azaath.PlaySound("igCharacterInfoClose")
        if Azaath.db and Azaath.db.setup then Azaath.db.setup.seen = true end
    end)
end

--------------------------------------------------------------------------------
-- API
--------------------------------------------------------------------------------
function M.Open(isAuto)
    if InCombatLockdown() then
        pendingOpen = true
        if not isAuto then Azaath:Print(L("setup.msg.combat")) end
        return
    end
    if not win then Build() end
    if win:IsShown() then return end
    if not resumeAfterCombat then
        wipe(staged)
        mode = (Azaath.db.setup and Azaath.db.setup.done) and "custom" or "full"
        step = 1
    end
    resumeAfterCombat, pendingOpen = false, false
    if U.IsShown and U.IsShown() then U.Hide() end
    Localize()
    win:SetAlpha(0)
    shade:SetAlpha(0)
    win:Show()
    ShowStep(step, true)
    Fade(win, 1, 0.25)
    Fade(shade, 1, 0.25)
end
U.OpenSetup = M.Open

function M.Close()
    if not (win and win:IsShown()) then return end
    win.closing = true
    Fade(shade, 0, 0.18)
    Fade(win, 0, 0.18, function(self) self:Hide() end)
end

function M.Finish()
    if InCombatLockdown() then return end
    local needReload = Commit()
    if needReload then
        ReloadUI()
        return
    end
    Azaath:Print(L("setup.msg.done"))
    M.Close()
end

--------------------------------------------------------------------------------
-- Combate: esconde e retoma na mesma etapa
--------------------------------------------------------------------------------
local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_REGEN_DISABLED" then
        if win and win:IsShown() and win.closing then
            win:SetScript("OnUpdate", nil)
            win:Hide()
        elseif win and win:IsShown() then
            resumeAfterCombat = true
            combatHide = true
            win:SetScript("OnUpdate", nil)
            win:Hide()
            combatHide = false
        end
    elseif resumeAfterCombat or pendingOpen then
        M.Open(true)
    end
end)

--------------------------------------------------------------------------------
-- Ciclo de vida e comandos
--------------------------------------------------------------------------------
function M:OnInitialize()
    local db = Azaath.db
    if type(db.setup) ~= "table" then
        -- instalação nova: abre sozinho; quem já usava o addon só recebe a dica
        db.setup = { seen = not Azaath.freshDB, done = false, hinted = Azaath.freshDB and true or false }
    end
end

function M:OnEnable()
    local s = Azaath.db.setup
    if not s.seen then
        C_Timer.After(2.5, function()
            if not Azaath.db.setup.seen then M.Open(true) end
        end)
    elseif not s.hinted then
        s.hinted = true
        Azaath:Print(L("setup.msg.hint"))
    end
end

if Azaath.commands then
    Azaath.commands.setup = function() M.Open() end
    Azaath.commands.tutorial = Azaath.commands.setup
end
