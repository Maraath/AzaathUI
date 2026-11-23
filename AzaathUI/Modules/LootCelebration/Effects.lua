--[[----------------------------------------------------------------------------
    AzaathUI - Modules/LootCelebration/Effects.lua
    Banner de celebração no estilo Azaath (obsidiana, ouro, brasão, medalhão e
    tipografia Cinzel/IM Fell) com alto impacto visual ("dopamina"): ondas de
    choque, raios giratórios, explosão de partículas, faíscas ascendentes no
    medalhão, pulso luminoso na borda e fanfarras .ogg.
------------------------------------------------------------------------------]]

local _, Azaath = ...

local LC = Azaath.LootCel or {}
Azaath.LootCel = LC

local _G = _G
local ipairs, pairs, pcall, tostring, tonumber, type, unpack =
    ipairs, pairs, pcall, tostring, tonumber, type, unpack
local max, min, floor, ceil, sin, cos, exp, random, pi, huge =
    math.max, math.min, math.floor, math.ceil, math.sin, math.cos, math.exp, math.random, math.pi, math.huge
local CreateFrame, UIParent, C_Timer = CreateFrame, UIParent, C_Timer

local MEDIA_ROOT = Azaath.media.path
local LC_MEDIA   = MEDIA_ROOT .. "LootCelebration\\"
local CFG_MEDIA  = MEDIA_ROOT .. "ConfigUI\\"
local SHT_MEDIA  = MEDIA_ROOT .. "Sheet\\"
local INV_MEDIA  = MEDIA_ROOT .. "Inventory\\"
local UF_MEDIA   = MEDIA_ROOT .. "UnitFrames\\"
local Geometry   = LC.Geometry

local HEADER_TEXT_W = 390
local BASE_W        = 580

local FONT_TITLE = Azaath.media.fontTitleB or Azaath.media.fontBold or "Fonts\\FRIZQT__.TTF"
local FONT_NAME  = Azaath.media.fontTitle or Azaath.media.fontCinzel or FONT_TITLE
local FONT_UI    = Azaath.media.fontBold or Azaath.media.font or "Fonts\\ARIALN.TTF"

-- Tabelas compartilhadas (mantém upvalues por função bem abaixo do limite 60 do Lua 5.1)
local ui = {}
local S = {
    current = nil,
    tier = "rare",
    activeDuration = 6,
    elapsed = 0,
    active = false,
    baseScale = 1,
    liveMove = nil,
    queueHandoff = false,
    pinned = {},
    pinRows = {},
}
LC.queue = LC.queue or {}

--------------------------------------------------------------------------------
-- Durações & Temas (PT-BR / EN-US)
--------------------------------------------------------------------------------
LC.durationDefaults = {
    quiet = 7, green = 4, rare = 5.5, epic = 7, legendary = 12, bag = 8,
    fish = 8, bloated = 16, treasure = 8, special = 8, mining = 8, herb = 8, skinning = 8,
    recipe = 8, collectible = 9, companion = 10, rare_kill = 8, record = 10, jackpot = 12,
    skill_fishing = 13, skill_mining = 13, skill_herb = 13, skill_skinning = 13,
    skill_cooking = 13, skill_firstaid = 13, skill_alchemy = 13,
    skill_blacksmithing = 13, skill_enchanting = 13, skill_engineering = 13,
    skill_leatherworking = 13, skill_tailoring = 13, skill_other = 13,
}

local function DB()
    return (Azaath.db and Azaath.db.lootCelebration) or {}
end

function LC.GetAlertDuration(kind)
    local db = DB()
    local custom = type(db.durations) == "table" and db.durations[kind] or nil
    if custom == "manual" then return huge end
    if type(custom) == "number" and custom >= 2 and custom <= 30 then return custom end
    local base = LC.durationDefaults[kind] or 8
    local mult = tonumber(db.durationScale)
    if mult and mult > 0 then
        return max(2, min(30, base * mult))
    end
    return base
end

local THEMES = {
    fish        = { pt = "PEIXE RARO PESCADO!",       en = "LOOTED SPECIAL FISH!",      color = { 0.16, 0.96, 0.86 }, sound = "fish.ogg" },
    bloated     = { pt = "PEIXE INCHADO RARO!",       en = "BLOATED FISH JACKPOT!",     color = { 0.16, 0.90, 1.00 }, sound = "bloated.ogg" },
    treasure    = { pt = "TESOURO ENCONTRADO!",       en = "LOOTED TREASURE!",          color = { 1.00, 0.77, 0.25 }, sound = "treasure.ogg" },
    special     = { pt = "ITEM VIGIADO OBTIDO!",      en = "LOOTED SPECIAL ITEM!",      color = { 1.00, 0.82, 0.32 }, sound = "treasure.ogg" },
    rare        = { pt = "RARO SAQUEADO!",            en = "LOOTED RARE!",              color = { 0.20, 0.58, 1.00 }, sound = "rare.ogg" },
    green       = { pt = "INCOMUM SAQUEADO!",         en = "LOOTED UNCOMMON!",          color = { 0.28, 0.92, 0.38 }, sound = "green.ogg" },
    epic        = { pt = "ÉPICO SAQUEADO!",           en = "LOOTED EPIC!",              color = { 0.78, 0.34, 1.00 }, sound = "epic.ogg" },
    legendary   = { pt = "LENDÁRIO CONQUISTADO!",     en = "LOOTED LEGENDARY!",         color = { 1.00, 0.54, 0.12 }, sound = "legendary.ogg" },
    mining      = { pt = "MINÉRIO RARO EXTRAÍDO!",    en = "LOOTED MINING TREASURE!",   color = { 1.00, 0.72, 0.22 }, sound = "treasure.ogg" },
    herb        = { pt = "ERVA RARA COLHIDA!",        en = "LOOTED RARE HERB!",         color = { 0.24, 0.96, 0.48 }, sound = "rare.ogg" },
    skinning    = { pt = "COURO RARO OBTIDO!",        en = "LOOTED SKINNING TREASURE!", color = { 1.00, 0.54, 0.28 }, sound = "treasure.ogg" },
    quiet       = { pt = "ACHADO NA PESCARIA",        en = "LOOTED SOMETHING!",         color = { 0.92, 0.90, 0.84 }, quiet = true },
    recipe      = { pt = "RECEITA RARA OBTIDA!",      en = "LOOTED RARE RECIPE!",       color = { 0.36, 0.92, 0.44 }, sound = "rare.ogg" },
    collectible = { pt = "RELÍQUIA RARA OBTIDA!",     en = "LOOTED RARE COLLECTIBLE!",  color = { 1.00, 0.80, 0.30 }, sound = "epic.ogg" },
    companion   = { pt = "NOVO COMPANHEIRO!",         en = "NEW COMPANION!",            color = { 0.85, 0.58, 1.00 }, sound = "epic.ogg" },
    rare_kill   = { pt = "INIMIGO RARO ABATIDO!",     en = "RARE ENEMY DEFEATED!",      color = { 1.00, 0.48, 0.24 }, sound = "treasure.ogg" },
    record      = { pt = "NOVO RECORDE PESSOAL!",     en = "NEW PERSONAL RECORD!",      color = { 1.00, 0.82, 0.28 }, sound = "fish.ogg" },
    jackpot     = { pt = "JACKPOT DE SAQUE!",         en = "DOUBLE RARE JACKPOT!",      color = { 0.24, 0.62, 1.00 }, sound = "epic.ogg" },
    bag         = { pt = "BOLSA SAQUEADA!",           en = "LOOTED BAG!",               color = { 1.00, 0.76, 0.25 }, sound = "treasure.ogg" },
    skill_fishing        = { pt = "MARCO DE PESCA!",              en = "FISHING MILESTONE!",        color = { 0.20, 0.86, 0.97 }, sound = "fish.ogg" },
    skill_mining         = { pt = "MARCO DE MINERAÇÃO!",          en = "MINING MILESTONE!",         color = { 1.00, 0.72, 0.21 }, sound = "treasure.ogg" },
    skill_herb           = { pt = "MARCO DE HERBORISMO!",         en = "HERBALISM MILESTONE!",      color = { 0.31, 0.94, 0.48 }, sound = "fish.ogg" },
    skill_skinning       = { pt = "MARCO DE ESFOLAMENTO!",        en = "SKINNING MILESTONE!",       color = { 1.00, 0.58, 0.30 }, sound = "treasure.ogg" },
    skill_cooking        = { pt = "MARCO DE CULINÁRIA!",          en = "COOKING MILESTONE!",        color = { 1.00, 0.66, 0.25 }, sound = "treasure.ogg" },
    skill_firstaid       = { pt = "MARCO DE PRIMEIROS SOCORROS!", en = "FIRST AID MILESTONE!",      color = { 0.34, 0.87, 0.92 }, sound = "fish.ogg" },
    skill_alchemy        = { pt = "MARCO DE ALQUIMIA!",           en = "ALCHEMY MILESTONE!",        color = { 0.34, 0.93, 0.49 }, sound = "fish.ogg" },
    skill_blacksmithing  = { pt = "MARCO DE FERRARIA!",           en = "BLACKSMITHING MILESTONE!",  color = { 1.00, 0.63, 0.22 }, sound = "treasure.ogg" },
    skill_enchanting     = { pt = "MARCO DE ENCANTAMENTO!",       en = "ENCHANTING MILESTONE!",     color = { 0.75, 0.42, 1.00 }, sound = "epic.ogg" },
    skill_engineering    = { pt = "MARCO DE ENGENHARIA!",         en = "ENGINEERING MILESTONE!",    color = { 1.00, 0.84, 0.30 }, sound = "treasure.ogg" },
    skill_leatherworking = { pt = "MARCO DE COURARIA!",           en = "LEATHERWORKING MILESTONE!", color = { 0.94, 0.65, 0.37 }, sound = "treasure.ogg" },
    skill_tailoring      = { pt = "MARCO DE ALFAIATARIA!",        en = "TAILORING MILESTONE!",      color = { 0.45, 0.67, 1.00 }, sound = "fish.ogg" },
    skill_other          = { pt = "MARCO DE OFÍCIO!",             en = "PROFESSION MILESTONE!",     color = { 1.00, 0.80, 0.32 }, sound = "treasure.ogg" },
}

local FLIP = {
    TOPLEFT = { 0, 1, 0, 1 }, TOPRIGHT = { 1, 0, 0, 1 },
    BOTTOMLEFT = { 0, 1, 1, 0 }, BOTTOMRIGHT = { 1, 0, 1, 0 },
}

local function TierFor(item)
    local k = item and item.kind or "special"
    if k == "quiet" or k == "green" then return "minimal" end
    if k == "legendary" or k == "bloated" or k == "jackpot" or k == "collectible" then return "mythic" end
    if k == "epic" or k == "record" or k == "companion" or (type(k) == "string" and k:sub(1, 6) == "skill_") then return "epic" end
    return "rare"
end

--------------------------------------------------------------------------------
-- Âncora do Modo de Edição (/azaath edit)
--------------------------------------------------------------------------------
ui.anchor = CreateFrame("Frame", "AzaathUILootCelebrationAnchor", Azaath.root or UIParent)
ui.anchor:SetSize(BASE_W, 250)
ui.anchor:SetPoint("CENTER", Azaath.root or UIParent, "CENTER", 0, 210)
ui.anchor:EnableMouse(false)

function LC.ApplyAnchorLayout()
    local db = DB()
    local sc = (db.scale and db.scale > 0) and db.scale or 1
    ui.anchor:SetScale(sc)
    ui.anchor:ClearAllPoints()
    ui.anchor:SetPoint("CENTER", Azaath.root or UIParent, "CENTER", db.offsetX or 0, db.offsetY or 210)
    if Azaath.ClampToScreen then Azaath.ClampToScreen(ui.anchor) end
end

--------------------------------------------------------------------------------
-- Camada de Efeitos de Tela & Banner Azaath
--------------------------------------------------------------------------------
ui.screen = CreateFrame("Frame", "AzaathUILootCelebration", UIParent)
ui.screen:SetAllPoints(UIParent)
ui.screen:SetFrameStrata("FULLSCREEN_DIALOG")
ui.screen:EnableMouse(false)
ui.screen:Hide()

ui.edgeGlow = ui.screen:CreateTexture(nil, "BACKGROUND")
ui.edgeGlow:SetTexture(LC_MEDIA .. "edgeglow.tga")
ui.edgeGlow:SetAllPoints(UIParent)
ui.edgeGlow:SetBlendMode("ADD")
ui.edgeGlow:SetAlpha(0)

ui.banner = CreateFrame("Frame", nil, ui.screen)
ui.banner:SetSize(BASE_W, 270)
ui.banner:SetMovable(true)
ui.banner:SetClampedToScreen(true)
ui.banner:RegisterForDrag("LeftButton")

-- Aura externa na borda no estilo Azaath (camadas suaves ao redor do card)
local function MakeBorderAura(outset, thickness, alpha)
    local strips = {}
    for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
        local t = ui.banner:CreateTexture(nil, "BACKGROUND", nil, -1)
        t:SetTexture(Azaath.media.blank)
        t:SetBlendMode("ADD")
        if side == "TOP" or side == "BOTTOM" then
            local y = (side == "TOP") and (-10 + outset) or (10 - outset)
            t:SetPoint(side .. "LEFT", ui.banner, side .. "LEFT", 10 - outset, y)
            t:SetPoint(side .. "RIGHT", ui.banner, side .. "RIGHT", -10 + outset, y)
            t:SetHeight(thickness)
        else
            local x = (side == "LEFT") and (10 - outset) or (-10 + outset)
            t:SetPoint("TOP" .. side, ui.banner, "TOP" .. side, x, -10 + outset)
            t:SetPoint("BOTTOM" .. side, ui.banner, "BOTTOM" .. side, x, 10 - outset)
            t:SetWidth(thickness)
        end
        strips[#strips + 1] = t
    end
    return { strips = strips, baseAlpha = alpha }
end

ui.outerAuraWide = MakeBorderAura(7, 8, 0.14)
ui.outerAuraCore = MakeBorderAura(3, 4, 0.30)

-- Fundo 9-slice translúcido em azul-carvão/obsidiana Azaath
local BG_INSET, BG_CORNER, BG_ALPHA = 10, 56, 0.93
local function BgSlice(r, g, b, a)
    local t = ui.banner:CreateTexture(nil, "BACKGROUND", nil, 0)
    t:SetColorTexture(r or 0.026, g or 0.034, b or 0.052, a or 0.96)
    t:SetAlpha(BG_ALPHA)
    return t
end

local bgCenter = BgSlice()
bgCenter:SetPoint("TOPLEFT", ui.banner, "TOPLEFT", BG_INSET, -(BG_INSET + BG_CORNER))
bgCenter:SetPoint("BOTTOMRIGHT", ui.banner, "BOTTOMRIGHT", -BG_INSET, BG_INSET + BG_CORNER)

local bgTop = BgSlice()
bgTop:SetPoint("TOPLEFT", ui.banner, "TOPLEFT", BG_INSET + BG_CORNER, -BG_INSET)
bgTop:SetPoint("TOPRIGHT", ui.banner, "TOPRIGHT", -(BG_INSET + BG_CORNER), -BG_INSET)
bgTop:SetHeight(BG_CORNER)

local bgBottom = BgSlice()
bgBottom:SetPoint("BOTTOMLEFT", ui.banner, "BOTTOMLEFT", BG_INSET + BG_CORNER, BG_INSET)
bgBottom:SetPoint("BOTTOMRIGHT", ui.banner, "BOTTOMRIGHT", -(BG_INSET + BG_CORNER), BG_INSET)
bgBottom:SetHeight(BG_CORNER)

for point, tc in pairs(FLIP) do
    local corner = ui.banner:CreateTexture(nil, "BACKGROUND", nil, 0)
    corner:SetTexture(LC_MEDIA .. "popup_bg_corner.tga")
    corner:SetAlpha(BG_ALPHA)
    corner:SetSize(BG_CORNER, BG_CORNER)
    corner:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
    local sx = point:find("RIGHT") and -BG_INSET or BG_INSET
    local sy = point:find("BOTTOM") and BG_INSET or -BG_INSET
    corner:SetPoint(point, ui.banner, point, sx, sy)
end

ui.bgTex = ui.banner:CreateTexture(nil, "BACKGROUND", nil, 1)
ui.bgTex:SetTexture(CFG_MEDIA .. "WindowBG.tga")
ui.bgTex:SetPoint("TOPLEFT", ui.banner, "TOPLEFT", 12, -12)
ui.bgTex:SetPoint("BOTTOMRIGHT", ui.banner, "BOTTOMRIGHT", -12, 12)
ui.bgTex:SetVertexColor(0.75, 0.78, 0.88, 1)
ui.bgTex:SetAlpha(0.36)

ui.rarityWash = ui.banner:CreateTexture(nil, "BACKGROUND", nil, 2)
ui.rarityWash:SetTexture(Azaath.media.blank)
ui.rarityWash:SetPoint("TOPLEFT", ui.banner, "TOPLEFT", 12, -12)
ui.rarityWash:SetPoint("BOTTOMRIGHT", ui.banner, "BOTTOMRIGHT", -12, 12)

-- Varredura de luz (sheen) na abertura + brilho estelar atrás do título
ui.sheen = ui.banner:CreateTexture(nil, "BORDER", nil, -1)
ui.sheen:SetTexture(UF_MEDIA .. "ClassicGlassH")
ui.sheen:SetBlendMode("ADD")
ui.sheen:SetWidth(116)
ui.sheen:SetAlpha(0)
ui.sheen:Hide()

ui.navFlare = ui.banner:CreateTexture(nil, "BORDER", nil, 1)
ui.navFlare:SetTexture(SHT_MEDIA .. "NavFlare.tga")
ui.navFlare:SetBlendMode("ADD")
ui.navFlare:SetSize(340, 44)
ui.navFlare:Hide()

-- Aura interna de cartão (ConfigUI\CardGlow) + feixes luminosos nas 4 bordas (ClassicGlassH)
ui.cardGlow = ui.banner:CreateTexture(nil, "BORDER", nil, 0)
ui.cardGlow:SetTexture(CFG_MEDIA .. "CardGlow.tga")
ui.cardGlow:SetBlendMode("ADD")
ui.cardGlow:SetPoint("TOPLEFT", ui.banner, "TOPLEFT", 11, -11)
ui.cardGlow:SetPoint("BOTTOMRIGHT", ui.banner, "BOTTOMRIGHT", -11, 11)
ui.cardGlow:SetAlpha(0.32)

ui.beamTop = ui.banner:CreateTexture(nil, "BORDER", nil, 2)
ui.beamTop:SetTexture(UF_MEDIA .. "ClassicGlassH")
ui.beamTop:SetBlendMode("ADD")
ui.beamTop:SetPoint("TOPLEFT", ui.banner, "TOPLEFT", 28, -9)
ui.beamTop:SetPoint("TOPRIGHT", ui.banner, "TOPRIGHT", -28, -9)
ui.beamTop:SetHeight(6)

ui.beamBot = ui.banner:CreateTexture(nil, "BORDER", nil, 2)
ui.beamBot:SetTexture(UF_MEDIA .. "ClassicGlassH")
ui.beamBot:SetBlendMode("ADD")
ui.beamBot:SetPoint("BOTTOMLEFT", ui.banner, "BOTTOMLEFT", 28, 9)
ui.beamBot:SetPoint("BOTTOMRIGHT", ui.banner, "BOTTOMRIGHT", -28, 9)
ui.beamBot:SetHeight(6)

ui.beamLeft = ui.banner:CreateTexture(nil, "BORDER", nil, 2)
ui.beamLeft:SetTexture(UF_MEDIA .. "ClassicGlassH")
ui.beamLeft:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
ui.beamLeft:SetBlendMode("ADD")
ui.beamLeft:SetPoint("TOPLEFT", ui.banner, "TOPLEFT", 9, -28)
ui.beamLeft:SetPoint("BOTTOMLEFT", ui.banner, "BOTTOMLEFT", 9, 28)
ui.beamLeft:SetWidth(5)

ui.beamRight = ui.banner:CreateTexture(nil, "BORDER", nil, 2)
ui.beamRight:SetTexture(UF_MEDIA .. "ClassicGlassH")
ui.beamRight:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
ui.beamRight:SetBlendMode("ADD")
ui.beamRight:SetPoint("TOPRIGHT", ui.banner, "TOPRIGHT", -9, -28)
ui.beamRight:SetPoint("BOTTOMRIGHT", ui.banner, "BOTTOMRIGHT", -9, 28)
ui.beamRight:SetWidth(5)

local function FrameLine(p1, p2, x1, y1, x2, y2, horiz)
    local line = ui.banner:CreateTexture(nil, "BORDER", nil, 1)
    line:SetColorTexture(0.79, 0.66, 0.42, 0.95)
    line:SetPoint(p1, ui.banner, p1, x1, y1)
    line:SetPoint(p2, ui.banner, p2, x2, y2)
    if horiz then line:SetHeight(2.5) else line:SetWidth(2.5) end
    return line
end

ui.frameTop    = FrameLine("TOPLEFT", "TOPRIGHT", 48, -10, -48, -10, true)
ui.frameBottom = FrameLine("BOTTOMLEFT", "BOTTOMRIGHT", 48, 10, -48, 10, true)
ui.frameLeft   = FrameLine("TOPLEFT", "BOTTOMLEFT", 10, -48, 10, 48, false)
ui.frameRight  = FrameLine("TOPRIGHT", "BOTTOMRIGHT", -10, -48, -10, 48, false)

ui.azCorners, ui.cornerGems = {}, {}
for point, tc in pairs(FLIP) do
    local c = ui.banner:CreateTexture(nil, "ARTWORK", nil, 2)
    c:SetTexture(CFG_MEDIA .. "Corner.tga")
    c:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
    c:SetSize(52, 52)
    local sx = point:find("RIGHT") and -4 or 4
    local sy = point:find("BOTTOM") and 4 or -4
    c:SetPoint(point, ui.banner, point, sx, sy)
    ui.azCorners[#ui.azCorners + 1] = c

    local gem = ui.banner:CreateTexture(nil, "ARTWORK", nil, 3)
    gem:SetTexture(LC_MEDIA .. "frame_corner.tga")
    gem:SetBlendMode("ADD")
    gem:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
    gem:SetSize(56, 56)
    gem:SetPoint(point, ui.banner, point, sx, sy)
    ui.cornerGems[#ui.cornerGems + 1] = gem
end

ui.topCrest = ui.banner:CreateTexture(nil, "ARTWORK", nil, 4)
ui.topCrest:SetTexture(CFG_MEDIA .. "Crest.tga")
ui.topCrest:SetSize(230, 40)
ui.topCrest:SetPoint("CENTER", ui.banner, "TOP", 0, -6)

ui.crestGem = ui.banner:CreateTexture(nil, "OVERLAY", nil, 2)
ui.crestGem:SetTexture(CFG_MEDIA .. "StepGem.tga")
ui.crestGem:SetBlendMode("ADD")
ui.crestGem:SetSize(20, 20)
ui.crestGem:SetPoint("CENTER", ui.banner, "TOP", 0, -10)

ui.dividerTex = ui.banner:CreateTexture(nil, "ARTWORK", nil, 1)
ui.dividerTex:SetTexture(CFG_MEDIA .. "DividerCenter.tga")
ui.dividerTex:SetSize(320, 14)

ui.alertFlow = LC.CreateBorderFlow(ui.banner, {
    inset = 10, radius = 12, thickness = 2.8, glowWidth = 18.5, speed = 0.11,
    enabled = function()
        return DB().borderPulse ~= false
    end,
})

--------------------------------------------------------------------------------
-- Botões Circulares Azaath (Diário / Config / Fechar)
--------------------------------------------------------------------------------
local function MakeHeaderBtn(iconPath, tipPT, tipEN, onClick, desat)
    local b = CreateFrame("Button", nil, ui.banner)
    b:SetSize(24, 24)
    b:SetFrameLevel(ui.banner:GetFrameLevel() + 25)
    local bg = b:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetTexture(INV_MEDIA .. "SlotRound")
    bg:SetAllPoints(b)
    bg:SetVertexColor(0.08, 0.10, 0.14, 0.92)
    local rim = b:CreateTexture(nil, "BORDER", nil, 1)
    rim:SetTexture(MEDIA_ROOT .. "MapUI\\Rim")
    rim:SetPoint("TOPLEFT", -1, 1); rim:SetPoint("BOTTOMRIGHT", 1, -1)
    rim:SetVertexColor(0.79, 0.66, 0.42, 0.78)
    local tex = b:CreateTexture(nil, "ARTWORK")
    tex:SetTexture(iconPath); tex:SetSize(13, 13); tex:SetPoint("CENTER")
    if desat then tex:SetDesaturated(true) end
    tex:SetVertexColor(0.86, 0.80, 0.66)
    b:SetScript("OnEnter", function(self)
        tex:SetVertexColor(1, 0.94, 0.68)
        rim:SetVertexColor(1, 0.86, 0.50, 1)
        bg:SetVertexColor(0.16, 0.19, 0.26, 0.98)
        if _G.GameTooltip then
            _G.GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            _G.GameTooltip:SetText(LC.L(tipPT, tipEN), 1, 1, 1)
            _G.GameTooltip:Show()
        end
    end)
    b:SetScript("OnLeave", function()
        tex:SetVertexColor(0.86, 0.80, 0.66)
        rim:SetVertexColor(0.79, 0.66, 0.42, 0.78)
        bg:SetVertexColor(0.08, 0.10, 0.14, 0.92)
        if _G.GameTooltip then _G.GameTooltip:Hide() end
    end)
    b:SetScript("OnClick", onClick)
    return b
end

local closeBtn = MakeHeaderBtn(MEDIA_ROOT .. "MapUI\\Close", "Fechar", "Close", function()
    if LC.DismissAlert then LC.DismissAlert() end
end)
closeBtn:SetPoint("TOPRIGHT", ui.banner, "TOPRIGHT", -24, -22)

local gearBtn = MakeHeaderBtn("Interface\\Buttons\\UI-OptionsButton", "Configurar celebrações (/azaath)", "Configure celebrations (/azaath)", function()
    local cfg = Azaath.ConfigUI
    if cfg and cfg.Open then
        cfg.Open()
        if cfg.SelectPage then
            for i, p in ipairs(cfg.PAGES or {}) do
                if p.key == "loot" then cfg.SelectPage(i); break end
            end
        end
    end
end, true)
gearBtn:SetPoint("RIGHT", closeBtn, "LEFT", -5, 0)

local journalBtn = MakeHeaderBtn(MEDIA_ROOT .. "MapUI\\Book", "Abrir Diário de Saques e Pesca", "Open Loot & Fishing Journal", function()
    if LC.ToggleJournal then LC.ToggleJournal(true) end
end)
journalBtn:SetPoint("RIGHT", gearBtn, "LEFT", -5, 0)

--------------------------------------------------------------------------------
-- Medalhões de Item & Faíscas
--------------------------------------------------------------------------------
local function BuildMedallion(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(82, 82)

    local astro = holder:CreateTexture(nil, "BACKGROUND", nil, 0)
    astro:SetTexture(MEDIA_ROOT .. "CastRing")
    astro:SetBlendMode("ADD")
    astro:SetSize(88, 88)
    astro:SetPoint("CENTER")
    astro:Hide()

    local aura = holder:CreateTexture(nil, "BACKGROUND", nil, 1)
    aura:SetTexture(SHT_MEDIA .. "SlotAura")
    aura:SetBlendMode("ADD")
    aura:SetSize(134, 134)
    aura:SetPoint("CENTER")

    local wisps = holder:CreateTexture(nil, "BACKGROUND", nil, 2)
    wisps:SetTexture(SHT_MEDIA .. "SlotAuraWisps")
    wisps:SetBlendMode("ADD")
    wisps:SetSize(124, 124)
    wisps:SetPoint("CENTER")

    local sphere = holder:CreateTexture(nil, "ARTWORK", nil, 0)
    sphere:SetTexture(INV_MEDIA .. "SlotRound")
    sphere:SetSize(68, 68)
    sphere:SetPoint("CENTER")
    sphere:SetVertexColor(0.14, 0.18, 0.24, 1)

    local icon = holder:CreateTexture(nil, "ARTWORK", nil, 1)
    icon:SetSize(64, 64)
    icon:SetPoint("CENTER")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    if holder.CreateMaskTexture then
        local mask = holder:CreateMaskTexture()
        local ok = pcall(mask.SetTexture, mask, INV_MEDIA .. "RoundMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if not ok then mask:SetTexture(INV_MEDIA .. "RoundMask") end
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
    end

    local vig = holder:CreateTexture(nil, "ARTWORK", nil, 2)
    vig:SetTexture(SHT_MEDIA .. "SlotVignette")
    vig:SetAllPoints(icon)

    local roundFrame = holder:CreateTexture(nil, "OVERLAY", nil, 1)
    roundFrame:SetTexture(SHT_MEDIA .. "RoundSlotFrame")
    roundFrame:SetSize(78, 78)
    roundFrame:SetPoint("CENTER")

    local rim = holder:CreateTexture(nil, "OVERLAY", nil, 2)
    rim:SetTexture(MEDIA_ROOT .. "CastRingThin")
    rim:SetBlendMode("ADD")
    rim:SetSize(76, 76)
    rim:SetPoint("CENTER")

    local outerRim = holder:CreateTexture(nil, "OVERLAY", nil, 3)
    outerRim:SetTexture(MEDIA_ROOT .. "CastRingThin")
    outerRim:SetBlendMode("ADD")
    outerRim:SetSize(86, 86)
    outerRim:SetPoint("CENTER")
    outerRim:Hide()

    holder.astro, holder.aura, holder.wisps, holder.icon = astro, aura, wisps, icon
    holder.roundFrame, holder.rim, holder.outerRim = roundFrame, rim, outerRim
    return holder
end

ui.medMain = BuildMedallion(ui.banner)
ui.medSecond = BuildMedallion(ui.banner)
ui.medSecond:Hide()

ui.embers = {}
for i = 1, 18 do
    local tx = ui.banner:CreateTexture(nil, "OVERLAY", nil, 4)
    tx:SetTexture(LC_MEDIA .. "spark.tga")
    tx:SetBlendMode("ADD"); tx:SetSize(10, 10); tx:Hide()
    ui.embers[i] = { tex = tx, age = 0, life = 1, delay = 0, x = 0, y = 0, vy = 35, sway = 8 }
end

--------------------------------------------------------------------------------
-- Textos & Rodapé de Valores
--------------------------------------------------------------------------------
local function MakeFS(font, size)
    local fs = ui.banner:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, "OUTLINE")
    fs:SetJustifyH("CENTER")
    fs:SetShadowColor(0, 0, 0, 1)
    fs:SetShadowOffset(2, -2)
    return fs
end

ui.kickerText   = MakeFS(FONT_TITLE, 12); ui.kickerText:Hide()
ui.headlineText = MakeFS(FONT_TITLE, 24)
ui.itemNameText = MakeFS(FONT_NAME, 22)
ui.itemMetaText = MakeFS(FONT_UI, 11); ui.itemMetaText:Hide()
ui.detailsText  = MakeFS(FONT_UI, 13)

ui.valuesBox = CreateFrame("Frame", nil, ui.banner)
ui.valuesBox:SetSize(514, 66)

local vWash = ui.valuesBox:CreateTexture(nil, "BACKGROUND", nil, 0)
vWash:SetAllPoints(ui.valuesBox)
vWash:SetColorTexture(0.03, 0.042, 0.065, 0.40)

for point, tc in pairs(FLIP) do
    local vc = ui.valuesBox:CreateTexture(nil, "BORDER", nil, 1)
    vc:SetTexture(CFG_MEDIA .. "CardCorner.tga")
    vc:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
    vc:SetSize(14, 14)
    vc:SetPoint(point, ui.valuesBox, point, 0, 0)
    vc:SetVertexColor(0.79, 0.66, 0.42, 0.72)
end

ui.valuesTopBeam = ui.valuesBox:CreateTexture(nil, "BORDER", nil, 2)
ui.valuesTopBeam:SetTexture(UF_MEDIA .. "ClassicGlassH")
ui.valuesTopBeam:SetBlendMode("ADD")
ui.valuesTopBeam:SetPoint("TOPLEFT", ui.valuesBox, "TOPLEFT", 18, 0)
ui.valuesTopBeam:SetPoint("TOPRIGHT", ui.valuesBox, "TOPRIGHT", -18, 0)
ui.valuesTopBeam:SetHeight(2)
ui.valuesTopBeam:SetVertexColor(0.92, 0.76, 0.44, 0.85)

ui.valuesSep = ui.valuesBox:CreateTexture(nil, "BORDER", nil, 2)
ui.valuesSep:SetTexture(UF_MEDIA .. "ClassicGlassH")
ui.valuesSep:SetTexCoord(0, 1, 1, 1, 0, 0, 1, 0)
ui.valuesSep:SetBlendMode("ADD")
ui.valuesSep:SetSize(2, 46)
ui.valuesSep:SetPoint("CENTER", ui.valuesBox, "CENTER", 0, -1)
ui.valuesSep:SetVertexColor(0.79, 0.66, 0.42, 0.62)

local function MakeValueCard(iconPath)
    local box = CreateFrame("Frame", nil, ui.valuesBox)
    local hiGlow = box:CreateTexture(nil, "BACKGROUND", nil, 1)
    hiGlow:SetTexture(UF_MEDIA .. "ClassicGlassH")
    hiGlow:SetBlendMode("ADD")
    hiGlow:SetAllPoints(box)
    hiGlow:SetVertexColor(1.0, 0.84, 0.34)
    hiGlow:SetAlpha(0)
    hiGlow:Hide()

    local ico = box:CreateTexture(nil, "ARTWORK")
    ico:SetTexture(iconPath)
    ico:SetSize(13, 13)
    ico:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ico:SetPoint("TOP", box, "TOP", 0, -6)
    ico:Hide()

    local title = box:CreateFontString(nil, "OVERLAY")
    title:SetFont(FONT_TITLE, 10, "OUTLINE")
    title:SetPoint("TOP", box, "TOP", 8, -6); title:SetHeight(14)
    title:SetTextColor(0.82, 0.74, 0.56)

    local amount = box:CreateFontString(nil, "OVERLAY")
    amount:SetFont(FONT_UI, 15, "OUTLINE")
    amount:SetPoint("TOP", box, "TOP", 0, -23); amount:SetHeight(20)
    amount:SetTextColor(1, 0.93, 0.74)

    local age = box:CreateFontString(nil, "OVERLAY")
    age:SetFont(FONT_UI, 11, "")
    age:SetPoint("TOP", box, "TOP", 0, -44); age:SetHeight(16)
    age:SetTextColor(0.68, 0.74, 0.82)

    return { frame = box, hiGlow = hiGlow, ico = ico, title = title, amount = amount, age = age }
end

ui.vendorCard  = MakeValueCard("Interface\\Icons\\INV_Misc_Coin_01")
ui.auctionCard = MakeValueCard("Interface\\Icons\\INV_Hammer_01")

local function LayoutValueCards()
    local showV = ui.vendorCard.frame:IsShown()
    local showA = ui.auctionCard.frame:IsShown()
    local both  = showV and showA
    ui.valuesSep:SetShown(both)
    local w = both and 254 or 514
    for _, c in ipairs({ ui.vendorCard, ui.auctionCard }) do
        c.frame:ClearAllPoints()
        c.frame:SetSize(w, 64)
        c.title:SetWidth(w - 30); c.amount:SetWidth(w - 12); c.age:SetWidth(w - 12)
        c.ico:ClearAllPoints()
        c.ico:SetPoint("RIGHT", c.title, "LEFT", -5, 0)
        local tw = c.title.GetStringWidth and c.title:GetStringWidth() or 80
        c.title:ClearAllPoints()
        c.title:SetWidth(min(w - 30, tw + 6))
        c.title:SetPoint("TOP", c.frame, "TOP", 8, -7)
        c.ico:Show()
    end
    if both then
        ui.vendorCard.frame:SetPoint("TOPLEFT", ui.valuesBox, "TOPLEFT", 0, -1)
        ui.auctionCard.frame:SetPoint("TOPRIGHT", ui.valuesBox, "TOPRIGHT", 0, -1)
    elseif showV then
        ui.vendorCard.frame:SetPoint("TOP", ui.valuesBox, "TOP", 0, -1)
    elseif showA then
        ui.auctionCard.frame:SetPoint("TOP", ui.valuesBox, "TOP", 0, -1)
    end
end

--------------------------------------------------------------------------------
-- Medição e Quebra UTF-8 Segura
--------------------------------------------------------------------------------
local function MeasureWidth(fs, font, value, size)
    fs:SetFont(font, size, "OUTLINE")
    fs:SetWidth(2400)
    fs:SetText(value)
    local w = fs.GetStringWidth and fs:GetStringWidth()
    if type(w) == "number" and w > 0 then return w end
    return #value * size * 0.62
end

local function WrapUTF8(fs, font, value, size, maxW)
    local lines, line = {}, ""
    for word in value:gmatch("%S+") do
        local cand = line == "" and word or (line .. " " .. word)
        if line ~= "" and MeasureWidth(fs, font, cand, size) > maxW then
            lines[#lines + 1] = line
            line = word
        else
            line = cand
        end
        if MeasureWidth(fs, font, line, size) > maxW then
            local rem, pos = "", 1
            while pos <= #line do
                local b = line:byte(pos)
                local len = (b < 0x80) and 1 or ((b < 0xE0) and 2 or ((b < 0xF0) and 3 or 4))
                local ch = line:sub(pos, pos + len - 1)
                pos = pos + len
                local nxt = rem .. ch
                if rem ~= "" and MeasureWidth(fs, font, nxt, size) > maxW then
                    lines[#lines + 1] = rem; rem = ch
                else
                    rem = nxt
                end
            end
            line = rem
        end
    end
    if line ~= "" then lines[#lines + 1] = line end
    if #lines == 0 then return value, 1 end
    return table.concat(lines, "\n"), #lines
end

local function FitText(fs, font, value, baseSize, minSize, maxW)
    if MeasureWidth(fs, font, value, baseSize) <= maxW then
        fs:SetWidth(maxW); fs:SetText(value)
        return 1, baseSize
    end
    for sz = baseSize - 1, minSize, -1 do
        if MeasureWidth(fs, font, value, sz) <= maxW then
            fs:SetWidth(maxW); fs:SetText(value)
            return 1, sz
        end
    end
    for sz = baseSize, minSize, -1 do
        local wrapped, n = WrapUTF8(fs, font, value, sz, maxW)
        if n <= 2 then
            fs:SetWidth(maxW); fs:SetText(wrapped)
            return n, sz
        end
    end
    local wrapped, n = WrapUTF8(fs, font, value, minSize, maxW)
    fs:SetWidth(maxW); fs:SetText(wrapped)
    return n, minSize
end

--------------------------------------------------------------------------------
-- Ondas & Bolhas (exclusivas para Peixe Inchado)
--------------------------------------------------------------------------------
ui.waterRings, ui.bubbles = {}, {}

for i = 1, 4 do
    local t = ui.screen:CreateTexture(nil, "ARTWORK", nil, -1)
    t:SetTexture(MEDIA_ROOT .. "Ring.tga"); t:SetBlendMode("ADD")
    t:SetVertexColor(0.14, 0.90, 1.0, 0.9); t:Hide()
    ui.waterRings[i] = t
end

for i = 1, 32 do
    local t = ui.screen:CreateTexture(nil, "ARTWORK", nil, -1)
    t:SetTexture(MEDIA_ROOT .. "Ring.tga"); t:SetBlendMode("ADD")
    t:SetVertexColor(0.30, 0.86, 1.0, 1); t:Hide()
    ui.bubbles[i] = { texture = t }
end

--------------------------------------------------------------------------------
-- Pilha Fixada (Pinned)
--------------------------------------------------------------------------------
local pinnedLayer = CreateFrame("Frame", nil, UIParent)
pinnedLayer:SetSize(460, 165)
pinnedLayer:SetPoint("TOP", UIParent, "TOP", 0, -18)
pinnedLayer:SetFrameStrata("FULLSCREEN_DIALOG")
pinnedLayer:SetFrameLevel(20)
pinnedLayer:Hide()

local pinScroll = CreateFrame("ScrollFrame", nil, pinnedLayer, "UIPanelScrollFrameTemplate")
pinScroll:SetPoint("TOPLEFT", 2, -2); pinScroll:SetPoint("BOTTOMRIGHT", -24, 2)
local pinCanvas = CreateFrame("Frame", nil, pinScroll)
pinCanvas:SetSize(430, 40)
pinScroll:SetScrollChild(pinCanvas)

local function RenderPinned()
    local pinned, pinRows = S.pinned, S.pinRows
    pinnedLayer:SetShown(#pinned > 0)
    local nextY = 0
    for i, item in ipairs(pinned) do
        if not pinRows[i] then
            local f = CreateFrame("Frame", nil, pinCanvas)
            f:SetSize(426, 44)
            local bg = f:CreateTexture(nil, "BACKGROUND")
            bg:SetAllPoints(f); bg:SetColorTexture(0.035, 0.045, 0.068, 0.94)
            local edge = f:CreateTexture(nil, "BORDER")
            edge:SetPoint("TOPLEFT"); edge:SetPoint("TOPRIGHT"); edge:SetHeight(1)
            edge:SetColorTexture(0.79, 0.66, 0.42, 0.5)
            local icon = f:CreateTexture(nil, "ARTWORK")
            icon:SetPoint("LEFT", f, "LEFT", 7, 0); icon:SetSize(32, 32)
            icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            local title = f:CreateFontString(nil, "OVERLAY")
            title:SetFont(FONT_UI, 12, "OUTLINE")
            title:SetPoint("TOPLEFT", f, "TOPLEFT", 46, -5); title:SetSize(330, 18); title:SetJustifyH("LEFT")
            local sub = f:CreateFontString(nil, "OVERLAY")
            sub:SetFont(FONT_UI, 11, "")
            sub:SetPoint("TOPLEFT", f, "TOPLEFT", 46, -24); sub:SetSize(330, 16); sub:SetJustifyH("LEFT")
            sub:SetTextColor(1, 0.82, 0.32)
            local x = CreateFrame("Button", nil, f)
            x:SetSize(22, 22); x:SetPoint("RIGHT", f, "RIGHT", -6, 0)
            local xt = x:CreateTexture(nil, "ARTWORK")
            xt:SetTexture(MEDIA_ROOT .. "MapUI\\Close"); xt:SetSize(12, 12); xt:SetPoint("CENTER")
            xt:SetVertexColor(0.85, 0.80, 0.70)
            x:SetScript("OnClick", function()
                if f.index and S.pinned[f.index] then
                    table.remove(S.pinned, f.index)
                    RenderPinned()
                end
            end)
            pinRows[i] = { f = f, icon = icon, title = title, sub = sub }
        end
        local r = pinRows[i]
        r.f.index = i
        r.f:ClearAllPoints(); r.f:SetPoint("TOPLEFT", pinCanvas, "TOPLEFT", 0, -nextY)
        nextY = nextY + 47
        r.title:SetText((item.headline or "") .. "  " .. (item.name or ""))
        r.sub:SetText(item.ahPrice and ("AH: " .. item.ahPrice) or "")
        if LC.RarePortraits then LC.RarePortraits.Clear(r.icon) end
        r.icon:SetTexture(item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
        if item.kind == "rare_kill" and LC.RarePortraits and not LC.RarePortraits.Apply(r.icon, item) then
            r.icon:SetTexture(item.icon or "Interface\\Icons\\Ability_Warrior_BattleShout")
        end
        r.f:Show()
    end
    for i = #pinned + 1, #pinRows do
        if LC.RarePortraits then LC.RarePortraits.Clear(pinRows[i].icon) end
        pinRows[i].f:Hide()
    end
    pinCanvas:SetHeight(max(44, nextY))
end

local function PinCurrent()
    local cur = S.current
    if not cur then return end
    local a = LC.GetAHPrice and LC.GetAHPrice(cur) or nil
    table.insert(S.pinned, 1, {
        name = cur.name, headline = cur.headline, icon = cur.icon,
        ahPrice = a and a.price, kind = cur.kind,
        portrait = cur.portrait, portraitGUID = cur.portraitGUID,
        portraitDisplayID = cur.portraitDisplayID, portraitUnit = cur.portraitUnit,
    })
    RenderPinned()
end

--------------------------------------------------------------------------------
-- Posicionamento & Drag Temporário
--------------------------------------------------------------------------------
local function PlaceBanner()
    local db = DB()
    local wanted = (db.scale and db.scale > 0) and db.scale or 1
    S.baseScale = Geometry.FitScale(BASE_W, ui.banner:GetHeight(), wanted, 0.55, 1.8, 14)
    ui.banner:SetScale(S.baseScale)
    local ax, ay = ui.anchor:GetCenter()
    if ax and ay then
        local rel = ui.anchor:GetEffectiveScale() / UIParent:GetEffectiveScale()
        Geometry.Place(ui.banner, ax * rel, ay * rel, S.baseScale, true)
    else
        local sw, sh = Geometry.GetViewport()
        Geometry.Place(ui.banner, sw * 0.5, sh * 0.72, S.baseScale, true)
    end
    for _, wr in ipairs(ui.waterRings) do
        wr:ClearAllPoints(); wr:SetPoint("CENTER", ui.banner, "CENTER", 0, 0)
    end
end

ui.banner:SetScript("OnDragStart", function(self)
    if DB().movableAlerts ~= false then
        S.liveMove = Geometry.BeginMove(self)
    end
end)
ui.banner:SetScript("OnDragStop", function()
    S.liveMove = nil
end)

function LC.ApplyAlertMovement()
    local on = DB().movableAlerts ~= false
    if not on then S.liveMove = nil end
    ui.banner:EnableMouse(on)
end

--------------------------------------------------------------------------------
-- Ciclo de Vida & Animação 60 FPS
--------------------------------------------------------------------------------
local StartCelebration

local function ClearDisplay()
    local completed = S.current
    if LC.RarePortraits then LC.RarePortraits.Clear(ui.medMain.icon) end
    S.current = nil
    S.active = false
    ui.screen:SetScript("OnUpdate", nil)
    S.liveMove = nil
    ui.alertFlow:SetEnabled(false)
    ui.sheen:Hide()
    ui.navFlare:Hide()
    ui.itemMetaText:Hide()
    ui.medMain:SetScale(1)
    ui.screen:Hide()
    for _, e in ipairs(ui.embers) do e.tex:Hide() end
    for _, w in ipairs(ui.waterRings) do w:Hide() end
    for _, b in ipairs(ui.bubbles) do b.texture:Hide() end
    if completed and type(completed.onComplete) == "function" then
        completed.onComplete()
    end
end

local function BeginNext()
    if S.active or S.queueHandoff or #LC.queue == 0 then return end
    S.queueHandoff = true
    C_Timer.After(0.18, function()
        S.queueHandoff = false
        if not S.active and #LC.queue > 0 then
            local nextItem = table.remove(LC.queue, 1)
            StartCelebration(nextItem)
        end
    end)
end

function LC.DismissAlert()
    if not S.active then return end
    ClearDisplay()
    BeginNext()
end

local function Clamp01(v) return max(0, min(1, v)) end
local function Smoothstep(v) v = Clamp01(v); return v * v * (3 - 2 * v) end
local function EaseOutCubic(v) v = 1 - Clamp01(v); return 1 - v * v * v end

local function Update(_, dt)
    if S.liveMove then
        if type(_G.IsMouseButtonDown) == "function" and not _G.IsMouseButtonDown("LeftButton") then
            S.liveMove = nil
        elseif not Geometry.UpdateMove(S.liveMove) then
            S.liveMove = nil
        end
    end

    S.elapsed = S.elapsed + dt
    local t = S.elapsed
    if t >= S.activeDuration then
        ClearDisplay(); BeginNext(); return
    end

    local kind = S.current and S.current.kind
    local tier = S.tier or "rare"
    local bloated, quiet, green = (kind == "bloated"), (kind == "quiet"), (kind == "green")
    local isMinimal, isEpicPlus, isMythic = (tier == "minimal"), (tier == "epic" or tier == "mythic"), (tier == "mythic")

    -- Entrada orgânica suave (0.28s) sem salto exagerado
    if t < 0.28 and not S.liveMove then
        local p = t / 0.28
        local punch = (p < 0.65) and (0.93 + 0.085 * Smoothstep(p / 0.65)) or (1.015 - 0.015 * Smoothstep((p - 0.65) / 0.35))
        ui.banner:SetScale(S.baseScale * punch)
    elseif not S.liveMove and ui.banner:GetScale() ~= S.baseScale then
        ui.banner:SetScale(S.baseScale)
    end

    local intro = Smoothstep(t / (bloated and 0.42 or 0.22))
    local outro = (S.activeDuration == huge) and 1 or Smoothstep((S.activeDuration - t) / (bloated and 1.25 or 0.75))
    local opacity = intro * outro
    ui.banner:SetAlpha(opacity)

    -- Varredura única de brilho na abertura (Épico+)
    if isEpicPlus and t >= 0.06 and t <= 0.86 then
        local p = (t - 0.06) / 0.80
        local x = 16 + (BASE_W - 148) * Smoothstep(p)
        ui.sheen:ClearAllPoints()
        ui.sheen:SetPoint("TOPLEFT", ui.banner, "TOPLEFT", x, -12)
        ui.sheen:SetPoint("BOTTOMLEFT", ui.banner, "BOTTOMLEFT", x, 12)
        ui.sheen:SetAlpha((sin(pi * p) ^ 1.3) * (isMythic and 0.40 or 0.26) * opacity)
        ui.sheen:Show()
    elseif ui.sheen:IsShown() then
        ui.sheen:Hide()
    end

    local shimmer = 0.5 + 0.5 * sin(t * 1.6)
    local auraBreath = 0.5 + 0.5 * sin(t * 2.1)
    if not isMinimal then
        local ea = (isMythic and 0.90 or 0.84) + 0.10 * shimmer
        ui.frameTop:SetAlpha(ea); ui.frameBottom:SetAlpha(ea)
        ui.frameLeft:SetAlpha(ea); ui.frameRight:SetAlpha(ea)
        for idx, g in ipairs(ui.cornerGems) do
            local wave = isMythic and (0.5 + 0.5 * sin(t * 2.1 + idx * 0.9)) or auraBreath
            g:SetAlpha((isMythic and (0.72 + 0.28 * wave) or (0.64 + 0.24 * wave)) * opacity)
        end
        ui.crestGem:SetAlpha((isMythic and (0.84 + 0.16 * shimmer) or (0.72 + 0.22 * shimmer)) * opacity)

        local glowBase = isMythic and 0.26 or (isEpicPlus and 0.20 or 0.14)
        local glowAmp  = isMythic and 0.22 or (isEpicPlus and 0.18 or 0.12)
        ui.cardGlow:SetAlpha((glowBase + glowAmp * auraBreath) * opacity)

        local beamTopA = (isMythic and (0.60 + 0.34 * auraBreath) or (isEpicPlus and (0.48 + 0.30 * auraBreath) or (0.36 + 0.22 * auraBreath))) * opacity
        local beamSideA = beamTopA * 0.72
        ui.beamTop:SetAlpha(beamTopA); ui.beamBot:SetAlpha(beamTopA * 0.85)
        ui.beamLeft:SetAlpha(beamSideA); ui.beamRight:SetAlpha(beamSideA)

        local coreMult = isMythic and 1.35 or (isEpicPlus and 1.05 or 0.82)
        local wideMult = isMythic and 1.30 or (isEpicPlus and 0.92 or 0)
        for _, s in ipairs(ui.outerAuraWide.strips) do
            s:SetAlpha(ui.outerAuraWide.baseAlpha * wideMult * (0.75 + 0.50 * auraBreath) * opacity)
        end
        for _, s in ipairs(ui.outerAuraCore.strips) do
            s:SetAlpha(ui.outerAuraCore.baseAlpha * coreMult * (0.78 + 0.42 * auraBreath) * opacity)
        end
        if isEpicPlus then
            ui.navFlare:SetAlpha(((isMythic and 0.40 or 0.28) + 0.16 * shimmer) * opacity)
            ui.navFlare:Show()
        else
            ui.navFlare:Hide()
        end
    else
        local frameA = quiet and 0.55 or 0.78
        ui.frameTop:SetAlpha(frameA); ui.frameBottom:SetAlpha(frameA)
        ui.frameLeft:SetAlpha(frameA); ui.frameRight:SetAlpha(frameA)
        for _, g in ipairs(ui.cornerGems) do g:SetAlpha((quiet and 0.20 or 0.45) * opacity) end
        ui.crestGem:SetAlpha((quiet and 0.25 or 0.55) * opacity)
        ui.cardGlow:SetAlpha((quiet and 0.05 or 0.09) * opacity)
        ui.beamTop:SetAlpha((quiet and 0.10 or 0.22) * opacity)
        ui.beamBot:SetAlpha((quiet and 0.08 or 0.16) * opacity)
        ui.beamLeft:SetAlpha(0); ui.beamRight:SetAlpha(0)
        ui.navFlare:Hide()
        for _, s in ipairs(ui.outerAuraWide.strips) do s:SetAlpha(0) end
        for _, s in ipairs(ui.outerAuraCore.strips) do s:SetAlpha(0) end
    end

    -- Despertar e rotação das auras no medalhão redondo
    if t < 0.42 then
        local ms = (t < 0.24) and (0.86 + 0.19 * Smoothstep(t / 0.24)) or (1.05 - 0.05 * Smoothstep((t - 0.24) / 0.18))
        ui.medMain:SetScale(ms)
    elseif ui.medMain:GetScale() ~= 1 then
        ui.medMain:SetScale(1)
    end
    local awaken = Clamp01(t / 0.36)
    ui.medMain.wisps:SetRotation(t * 0.45)
    ui.medMain.aura:SetAlpha((isMinimal and 0.22 or (0.58 + 0.25 * auraBreath)) * awaken * opacity)
    ui.medMain.wisps:SetAlpha((isMinimal and 0 or (0.44 + 0.24 * shimmer)) * awaken * opacity)
    ui.medMain.rim:SetAlpha((isMinimal and 0.42 or (0.78 + 0.20 * auraBreath)) * awaken * opacity)
    if isEpicPlus then
        ui.medMain.astro:SetRotation(-t * 0.22)
        ui.medMain.astro:SetAlpha((isMythic and 0.26 or 0.18) * awaken * opacity)
        ui.medMain.astro:Show()
    else
        ui.medMain.astro:Hide()
    end
    if isMythic then
        ui.medMain.outerRim:SetRotation(t * 0.15)
        ui.medMain.outerRim:SetAlpha((0.52 + 0.26 * auraBreath) * awaken * opacity)
        ui.medMain.outerRim:Show()
    else
        ui.medMain.outerRim:Hide()
    end

    if ui.medSecond:IsShown() then
        ui.medSecond.wisps:SetRotation(-t * 0.45)
        ui.medSecond.aura:SetAlpha((0.58 + 0.25 * auraBreath) * awaken * opacity)
        ui.medSecond.wisps:SetAlpha((0.44 + 0.24 * shimmer) * awaken * opacity)
        ui.medSecond.rim:SetAlpha((0.78 + 0.20 * auraBreath) * awaken * opacity)
        ui.medSecond.astro:SetShown(isEpicPlus)
        if isEpicPlus then
            ui.medSecond.astro:SetRotation(t * 0.22)
            ui.medSecond.astro:SetAlpha(0.22 * awaken * opacity)
        end
        ui.medSecond.outerRim:SetShown(isMythic)
        if isMythic then
            ui.medSecond.outerRim:SetRotation(-t * 0.15)
            ui.medSecond.outerRim:SetAlpha((0.52 + 0.26 * auraBreath) * awaken * opacity)
        end
    end

    local bx, by, bw, bh = Geometry.GetBounds(ui.banner)
    local bcX = bx and (bx + bw * 0.5) or (UIParent:GetWidth() * 0.5)
    local bcY = by and (by + bh * 0.5) or (UIParent:GetHeight() * 0.5)
    local sw, sh = UIParent:GetWidth(), UIParent:GetHeight()
    local cxOff, cyOff = bcX - sw * 0.5, bcY - sh * 0.5

    for i, wave in ipairs(ui.waterRings) do
        if bloated then
            local age = t - (i - 1) * 0.55
            if age >= 0 then
                local phase = (age % 3.2) / 3.2
                local ease = EaseOutCubic(phase)
                local sz = 180 + 760 * ease
                wave:SetSize(sz, sz)
                wave:SetAlpha((1 - Smoothstep(phase)) * 0.40 * opacity)
                wave:Show()
            else wave:Hide() end
        else wave:Hide() end
    end

    for _, b in ipairs(ui.bubbles) do
        if bloated and t >= b.delay then
            local age = (t - b.delay) % b.life
            local phase = age / b.life
            local drift = sin(age * 1.8 + b.phase) * 14
            b.texture:ClearAllPoints()
            b.texture:SetPoint("CENTER", UIParent, "CENTER", cxOff + b.x + drift, cyOff + b.y + b.speed * age)
            b.texture:SetAlpha((sin(pi * phase) ^ 2) * 0.36 * opacity)
            b.texture:Show()
        else b.texture:Hide() end
    end

    -- Vinheta nas bordas da tela mais sutil e envolvente
    local edgeA = 0
    if bloated then
        if t < 1.10 then edgeA = 0.24 * Smoothstep(t / 1.10)
        elseif t < 4.9 then edgeA = 0.24 * (1 - Smoothstep((t - 1.10) / 3.80)) end
    elseif t < 0.65 then edgeA = 0.16 * Smoothstep(t / 0.65)
    elseif t < 2.65 then edgeA = 0.16 * (1 - Smoothstep((t - 0.65) / 2.00)) end
    local db = DB()
    local glowMult = (db.glowIntensity == "soft") and 0.50 or 1.0
    local showEdge = (not quiet) and (not green) and (db.edgeGlow ~= false)
    ui.edgeGlow:SetAlpha(showEdge and (edgeA * glowMult * outro) or 0)

    local maxEmbers = isMinimal and 0 or (isEpicPlus and #ui.embers or 6)
    for idx, em in ipairs(ui.embers) do
        if idx > maxEmbers then
            em.tex:Hide()
        else
            local age = t - em.delay
            if age > 0 then
                local cyc = age % em.life
                local p = cyc / em.life
                em.tex:ClearAllPoints()
                em.tex:SetPoint("CENTER", ui.medMain, "CENTER", em.x + sin(cyc * 4.2 + em.phase) * em.sway, em.y + em.vy * cyc)
                em.tex:SetAlpha((sin(p * pi) ^ 1.4) * 0.68 * opacity)
                em.tex:Show()
            else em.tex:Hide() end
        end
    end
end

--------------------------------------------------------------------------------
-- Montagem Visual de cada Celebração
--------------------------------------------------------------------------------
local function ResolveTint(item, theme)
    local tint = theme.color
    if item.kind == "jackpot" and type(item.items) == "table" then
        local best, imp = 0, { green = 2, rare = 3, epic = 4, legendary = 5 }
        for _, piece in ipairs(item.items) do
            local lvl = imp[piece.kind] or (piece.quality or 0)
            local ref = THEMES[piece.kind]
            if lvl > best and ref then best = lvl; tint = ref.color end
        end
    elseif item.kind == "bag" and type(item.bagSlots) == "number" then
        if item.bagSlots <= 8 then tint = { 0.39, 0.92, 0.40 }
        elseif item.bagSlots >= 16 then tint = { 0.78, 0.34, 1.00 } end
    end
    return unpack(tint)
end

local function PopulatePrices(item, first, db)
    ui.vendorCard.frame:Hide()
    ui.auctionCard.frame:Hide()
    local preview = (item.test == true and item.previewPrices == true)
    if not first then return end

    if db.showVendor ~= false or preview then
        local vendor = LC.GetVendorValue and LC.GetVendorValue(first) or nil
        if vendor or preview then
            ui.vendorCard.title:SetText(LC.L("VALOR DE VENDA", "VENDOR VALUE"))
            ui.vendorCard.amount:SetText(vendor and vendor.price or LC.FormatMoney(14520))
            ui.vendorCard.age:SetText(LC.L("Mercador NPC", "NPC Merchant"))
            ui.vendorCard.frame:Show()
        end
    end

    if db.showAH ~= false or preview then
        local data = LC.GetAHPrice and LC.GetAHPrice(first, preview) or nil
        ui.auctionCard.title:SetText(LC.L("CASA DE LEILÕES", "AUCTIONATOR VALUE"))
        ui.auctionCard.hiGlow:Hide()
        ui.auctionCard.title:SetTextColor(0.82, 0.74, 0.56)
        if data then
            local pal = {
                fresh = { 0.34, 0.96, 0.42 }, recent = { 0.64, 0.93, 0.44 },
                aging = { 1, 0.75, 0.32 }, stale = { 1, 0.34, 0.32 }, unknown = { 0.71, 0.74, 0.79 },
            }
            ui.auctionCard.amount:SetText(data.price)
            ui.auctionCard.age:SetText(data.ageText or "")
            ui.auctionCard.age:SetTextColor(unpack(pal[data.ageColor] or pal.unknown))
            if type(data.copper) == "number" and data.copper >= 500000 then
                ui.auctionCard.hiGlow:SetAlpha(0.22); ui.auctionCard.hiGlow:Show()
                ui.auctionCard.title:SetTextColor(1.0, 0.86, 0.36)
            end
            ui.auctionCard.frame:Show()
        elseif preview then
            ui.auctionCard.amount:SetText(LC.FormatMoney(845000))
            ui.auctionCard.age:SetText(LC.L("Dados: Hoje", "Price data: Today"))
            ui.auctionCard.age:SetTextColor(0.34, 0.96, 0.42)
            ui.auctionCard.hiGlow:SetAlpha(0.22); ui.auctionCard.hiGlow:Show()
            ui.auctionCard.title:SetTextColor(1.0, 0.86, 0.36)
            ui.auctionCard.frame:Show()
        else
            local st = LC.GetAHStatus and LC.GetAHStatus() or {}
            if st.enabled then
                ui.auctionCard.amount:SetText("|cff9098a8—|r")
                ui.auctionCard.age:SetText(LC.L("Sem dados — faça a varredura no leilão", "No data — run a full scan at the AH"))
                ui.auctionCard.age:SetTextColor(0.85, 0.71, 0.45)
                ui.auctionCard.frame:Show()
            end
        end
    end
end

local function ItemMetaLine(first)
    if type(first) ~= "table" then return nil end
    local key = first.link or first.id
    if not key then return nil end
    local info = (_G.C_Item and _G.C_Item.GetItemInfo) or _G.GetItemInfo
    if type(info) ~= "function" then return nil end
    local ok, _, _, _, ilvl, _, itemType, subType = pcall(info, key)
    if not ok or type(subType) ~= "string" then return nil end
    local parts = {}
    if type(itemType) == "string" and itemType ~= "" and itemType ~= subType then
        parts[#parts + 1] = subType
    elseif subType ~= "" then
        parts[#parts + 1] = subType
    end
    if type(ilvl) == "number" and ilvl > 1 then
        parts[#parts + 1] = LC.L("Nv. ", "iLvl ") .. tostring(ilvl)
    end
    if #parts == 0 then return nil end
    return table.concat(parts, "  ·  ")
end

local function SeedParticles(r, g, b, isBloated)
    for _, em in ipairs(ui.embers) do
        em.delay = random() * 0.9; em.life = 1.1 + random() * 1.0
        em.x = (random() - 0.5) * 58; em.y = -26 + random() * 20
        em.vy = 26 + random() * 34; em.sway = 5 + random() * 7; em.phase = random() * 6.28
        local sz = 6 + random() * 7
        em.tex:SetSize(sz, sz)
        em.tex:SetVertexColor(min(1, r + 0.25), min(1, g + 0.25), min(1, b + 0.25), 1)
    end
    for i, bbl in ipairs(ui.bubbles) do
        bbl.delay = random() * 2.2; bbl.life = 3.4 + random() * 3.6; bbl.speed = 32 + random() * 52
        bbl.phase = random() * 6.28
        bbl.x = (i % 2 == 0 and 1 or -1) * (310 + random() * 270); bbl.y = -260 + random() * 340
        local sz = 12 + random() * 22
        bbl.texture:SetSize(sz, sz); bbl.texture:SetVertexColor(0.22 + random() * 0.12, 0.82, 1, 1)
        bbl.texture:SetShown(isBloated)
    end
    for _, w in ipairs(ui.waterRings) do w:SetShown(isBloated) end
end

StartCelebration = function(item)
    S.current = item
    if item.kind == "green" then
        ui.edgeGlow:SetAlpha(0)
    end
    LC.ApplyAlertMovement()

    local theme = THEMES[item.kind] or THEMES.special
    S.tier = TierFor(item)
    local isSkill = type(item.kind) == "string" and item.kind:sub(1, 6) == "skill_"
    local isBloated = item.kind == "bloated"
    S.activeDuration = LC.GetAlertDuration(item.kind or "special")
    if type(item.durationOverride) == "number" and item.durationOverride >= 1 and item.durationOverride <= 30 then
        S.activeDuration = item.durationOverride
    end

    local r, g, b = ResolveTint(item, theme)
    ui.alertFlow:SetColor(r, g, b)
    ui.alertFlow:SetDualPulse(S.tier == "epic" or S.tier == "mythic")
    ui.alertFlow:SetEnabled(true)
    S.elapsed = 0; S.active = true

    pcall(Azaath.Gradient, ui.rarityWash, "VERTICAL", r, g, b, 0.02, r, g, b, item.kind == "quiet" and 0.05 or 0.16)
    local gr, gg, gb = 0.79 * 0.4 + r * 0.6, 0.66 * 0.4 + g * 0.6, 0.42 * 0.4 + b * 0.6
    ui.frameTop:SetColorTexture(gr, gg, gb, 0.96); ui.frameBottom:SetColorTexture(gr, gg, gb, 0.96)
    ui.frameLeft:SetColorTexture(gr, gg, gb, 0.96); ui.frameRight:SetColorTexture(gr, gg, gb, 0.96)
    for _, c in ipairs(ui.azCorners) do c:SetVertexColor(0.92, 0.78, 0.48, 0.95) end
    for _, cg in ipairs(ui.cornerGems) do cg:SetVertexColor(r, g, b, 0.85) end
    ui.topCrest:SetVertexColor(S.tier == "mythic" and 1.0 or 0.94, S.tier == "mythic" and 0.88 or 0.82, S.tier == "mythic" and 0.62 or 0.56, 0.98)
    ui.crestGem:SetVertexColor(r, g, b, 1)
    ui.dividerTex:SetVertexColor(gr, gg, gb, 0.85)
    ui.cardGlow:SetVertexColor(r, g, b)
    ui.sheen:SetVertexColor(min(1, r * 0.5 + 0.5), min(1, g * 0.5 + 0.5), min(1, b * 0.5 + 0.5))
    ui.navFlare:SetVertexColor(r, g, b)
    ui.beamTop:SetVertexColor(r, g, b); ui.beamBot:SetVertexColor(r, g, b)
    ui.beamLeft:SetVertexColor(r, g, b); ui.beamRight:SetVertexColor(r, g, b)
    for _, s in ipairs(ui.outerAuraWide.strips) do s:SetColorTexture(r, g, b, 1) end
    for _, s in ipairs(ui.outerAuraCore.strips) do s:SetColorTexture(r, g, b, 1) end

    local trackedHeading = Azaath.Tracked(item.headline or (LC.IsPT() and theme.pt or theme.en))
    local headLines, headFont = FitText(ui.headlineText, FONT_TITLE, trackedHeading, isBloated and 19 or (#trackedHeading > 42 and 17 or 21), 13, HEADER_TEXT_W)
    ui.headlineText:SetTextColor(r, g, b)

    ui.kickerText:SetShown(isBloated)
    if isBloated then
        ui.kickerText:SetText(Azaath.Tracked(LC.L("TESOURO DAS PROFUNDEZAS", "TREASURE FROM THE DEEP")))
        ui.kickerText:SetTextColor(0.95, 0.84, 0.46)
    end

    local jackpot = item.kind == "jackpot" and type(item.items) == "table" and #item.items >= 2
    local shownName = jackpot and ((item.items[1].name or "Item 1") .. "  +  " .. (item.items[2].name or "Item 2"))
                      or (item.name or LC.L("Item desconhecido", "Unknown item"))
    local nameLines, nameFont = FitText(ui.itemNameText, FONT_NAME, shownName, (#shownName > 50) and 15 or ((#shownName > 32) and 18 or 21), 13, 520)
    ui.itemNameText:SetTextColor(0.96, 0.94, 0.88)

    local msg = type(item.subtitle) == "string" and item.subtitle or ""
    if jackpot and #item.items > 2 then msg = "+" .. (#item.items - 2) .. LC.L(" outros itens", " more items") end
    local showDetail = (msg ~= "") and (isSkill or isBloated or item.kind == "record" or item.kind == "rare_kill" or (jackpot and #item.items > 2))
    ui.detailsText:SetShown(showDetail)
    local detLines, detFont = 1, 13
    if showDetail then
        detLines, detFont = FitText(ui.detailsText, FONT_UI, msg, 13, 11, 500)
        ui.detailsText:SetTextColor(0.84, 0.88, 0.94)
    else ui.detailsText:SetText("") end

    local isItem = not isSkill and item.kind ~= "rare_kill" and item.kind ~= "record"
    local first = jackpot and item.items[1] or ((isItem and (item.id or item.link)) and item or nil)
    local db = DB()
    PopulatePrices(item, first, db)

    local metaLine = isItem and not showDetail and ItemMetaLine(first) or nil
    if metaLine and metaLine ~= "" then
        ui.itemMetaText:SetWidth(500)
        ui.itemMetaText:SetText(metaLine)
        ui.itemMetaText:SetTextColor(0.76, 0.72, 0.60)
        ui.itemMetaText:Show()
    else
        ui.itemMetaText:Hide()
    end

    if LC.RarePortraits then LC.RarePortraits.Clear(ui.medMain.icon) end
    local isRareKill = item.kind == "rare_kill"
    ui.medMain.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    ui.medMain.icon:SetTexture((jackpot and item.items[1].icon) or item.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
    if isRareKill then
        if LC.RarePortraits and LC.RarePortraits.Apply(ui.medMain.icon, item) then
            ui.medMain.icon:SetTexCoord(0, 1, 0, 1)
        else
            ui.medMain.icon:SetTexture(item.icon or "Interface\\Icons\\Ability_Warrior_BattleShout")
        end
    end
    for _, m in ipairs({ ui.medMain, ui.medSecond }) do
        m.aura:SetVertexColor(r, g, b)
        m.wisps:SetVertexColor(r, g, b)
        m.astro:SetVertexColor(gr, gg, gb)
        m.rim:SetVertexColor(r, g, b)
        m.outerRim:SetVertexColor(1.0, 0.84, 0.42)
        m.roundFrame:SetVertexColor(0.84, 0.75, 0.56, 0.98)
    end
    ui.medSecond:SetShown(jackpot)
    if jackpot then ui.medSecond.icon:SetTexture(item.items[2].icon or "Interface\\Icons\\INV_Misc_QuestionMark") end

    local y = 26
    if isBloated then
        ui.kickerText:ClearAllPoints(); ui.kickerText:SetPoint("TOP", ui.banner, "TOP", 0, -y)
        ui.kickerText:SetSize(HEADER_TEXT_W, 18); y = y + 20
    end
    local headH = max(28, headLines * ceil(headFont * 1.25) + 4)
    ui.headlineText:ClearAllPoints(); ui.headlineText:SetPoint("TOP", ui.banner, "TOP", 0, -y)
    ui.headlineText:SetSize(HEADER_TEXT_W, headH)
    ui.navFlare:ClearAllPoints(); ui.navFlare:SetPoint("CENTER", ui.headlineText, "CENTER", 0, 0)
    y = y + headH + 4
    ui.dividerTex:ClearAllPoints(); ui.dividerTex:SetPoint("TOP", ui.banner, "TOP", 0, -y); y = y + 16
    ui.medMain:ClearAllPoints(); ui.medMain:SetPoint("TOP", ui.banner, "TOP", jackpot and -50 or 0, -y)
    if jackpot then ui.medSecond:ClearAllPoints(); ui.medSecond:SetPoint("TOP", ui.banner, "TOP", 50, -y) end
    y = y + 84
    local nameH = max(26, nameLines * ceil(nameFont * 1.28) + 4)
    ui.itemNameText:ClearAllPoints(); ui.itemNameText:SetPoint("TOP", ui.banner, "TOP", 0, -y)
    ui.itemNameText:SetSize(520, nameH); y = y + nameH + 3
    if metaLine and metaLine ~= "" then
        ui.itemMetaText:ClearAllPoints(); ui.itemMetaText:SetPoint("TOP", ui.banner, "TOP", 0, -y)
        ui.itemMetaText:SetSize(500, 16); y = y + 18
    end
    if showDetail then
        local detH = max(20, detLines * ceil(detFont * 1.25) + 2)
        ui.detailsText:ClearAllPoints(); ui.detailsText:SetPoint("TOP", ui.banner, "TOP", 0, -y)
        ui.detailsText:SetSize(500, detH); y = y + detH + 6
    end
    ui.valuesBox:Hide()
    if ui.vendorCard.frame:IsShown() or ui.auctionCard.frame:IsShown() then
        LayoutValueCards(); ui.valuesBox:ClearAllPoints()
        ui.valuesBox:SetPoint("TOP", ui.banner, "TOP", 0, -(y + 3)); ui.valuesBox:Show(); y = y + 69
    end

    ui.banner:SetSize(BASE_W, max(225, y + 18))
    PlaceBanner(); ui.alertFlow:Refresh(true)

    ui.edgeGlow:SetVertexColor(r, g, b, 1)
    SeedParticles(r, g, b, isBloated)

    ui.screen:Show(); ui.screen:SetScript("OnUpdate", Update)

    if db.sound ~= false and not theme.quiet and theme.sound and _G.PlaySoundFile then
        if S.soundHandle and _G.StopSound then
            pcall(_G.StopSound, S.soundHandle, 250)
            S.soundHandle = nil
        end
        local sndFile = theme.sound
        if item.kind == "jackpot" and type(item.items) == "table" then
            for _, p in ipairs(item.items) do
                if p.kind == "legendary" then sndFile = "legendary.ogg"; break end
            end
        end
        local ok, willPlay, handle = pcall(_G.PlaySoundFile, LC_MEDIA .. sndFile, "SFX")
        if (not ok or not willPlay) and sndFile == "legendary.ogg" then
            ok, willPlay, handle = pcall(_G.PlaySoundFile, LC_MEDIA .. "epic.ogg", "SFX")
        end
        if ok and willPlay then
            S.soundHandle = handle
        elseif type(_G.PlaySound) == "function" and _G.SOUNDKIT then
            pcall(_G.PlaySound, _G.SOUNDKIT.UI_EPICLOOT_TOAST or _G.SOUNDKIT.RAID_WARNING or 8959, "SFX")
        end
    end
end

--------------------------------------------------------------------------------
-- API Pública de Celebração com Fila Priorizada
--------------------------------------------------------------------------------
local QUEUE_RANK = {
    quiet = 0, green = 1, rare = 3, epic = 5, legendary = 7,
    rare_kill = 3, companion = 5, collectible = 6, bloated = 8, jackpot = 8,
}

function LC.Celebrate(item)
    if not item or not item.kind then return end
    local db = DB()
    if db.enabled == false and not item.test then return end

    if S.active and S.activeDuration == huge then
        PinCurrent(); ClearDisplay()
    end

    if S.active or S.queueHandoff or #LC.queue > 0 then
        if #LC.queue >= 64 then
            local lowest, lowestIdx = huge, nil
            for i, waiting in ipairs(LC.queue) do
                local score = QUEUE_RANK[waiting.kind] or 2
                if score < lowest then lowest, lowestIdx = score, i end
            end
            if (QUEUE_RANK[item.kind] or 2) > lowest and lowestIdx then
                table.remove(LC.queue, lowestIdx)
            else return end
        end
        LC.queue[#LC.queue + 1] = item
        if not S.active and not S.queueHandoff then BeginNext() end
    else
        StartCelebration(item)
    end
end
