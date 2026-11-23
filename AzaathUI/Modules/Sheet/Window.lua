--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Sheet/Window.lua
    Ficha do personagem: montagem da janela, abas, atalho (tecla C), eventos e ciclo de vida.
    Símbolos comuns vêm de Azaath.SheetUI (Modules/Sheet/Core.lua).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.SheetUI
local _G, floor, format, ipairs = _G, math.floor, string.format, ipairs
local max, min, pcall, tostring = math.max, math.min, pcall, tostring
local unpack = unpack
local ApplyCircleMask, BuildCharacterPage, BuildPvPPage, BuildReputationPage = U.ApplyCircleMask, U.BuildCharacterPage, U.BuildPvPPage, U.BuildReputationPage
local Char, CollectCurrency, CollectReputation, CollectStatCategories = U.Char, U.CollectCurrency, U.CollectReputation, U.CollectStatCategories
local CollectStats, CreateText, CurrencyDetail, FOOTER_H = U.CollectStats, U.CreateText, U.CurrencyDetail, U.FOOTER_H
local HEADER_H, INV_MEDIA, ListPage, M = U.HEADER_H, U.INV_MEDIA, U.ListPage, U.M
local MAP_MEDIA, MEDIA_ROOT, MakeButton, NAV_FONT = U.MAP_MEDIA, U.MEDIA_ROOT, U.MakeButton, U.NAV_FONT
local NAV_GAP, NAV_LINE_Y, NAV_TEXT_Y, NAV_Y = U.NAV_GAP, U.NAV_LINE_Y, U.NAV_TEXT_Y, U.NAV_Y
local NewList, PAD, ReputationDetail, SHEET_MEDIA = U.NewList, U.PAD, U.ReputationDetail, U.SHEET_MEDIA
local SelectSub, Show, TABS, UF_MEDIA = U.SelectSub, U.Show, U.TABS, U.UF_MEDIA
local UpdateCharacterPage, UpdatePvPPage, UpdateVitals, pages = U.UpdateCharacterPage, U.UpdatePvPPage, U.UpdateVitals, U.pages
local selected = U.selected
local ORB_RIGHT = 76   -- distância do orbe de Poder de Item à borda (abre espaço para janela/fechar)

local function UpdateHeader()
    local name = UnitName("player") or ""
    U.nameText:SetText(Azaath.Upper(name))

    local race, class = UnitRace("player") or "", UnitClass("player") or ""
    local level = UnitLevel("player") or 0
    U.infoText:SetText(Azaath.Upper(format("NÍVEL %d %s %s", level, race, class)))

    if U.portraitTex and _G.SetPortraitTexture then
        pcall(SetPortraitTexture, U.portraitTex, "player")
    end

    local cm = Char()
    local gs = cm and cm.AverageItemLevel and cm.AverageItemLevel() or 0
    U.ilvlText:SetText(tostring(gs))

    -- Menu centrado no vão entre a identidade (retrato + nome) e o orbe de Poder de Item,
    -- com margens iguais dos dois lados, como na arte de conceito
    if U.navCluster and U.navHeader then
        local hw = U.navHeader:GetWidth() or 0
        local leftX = 6 + 64 + 16 + max(U.nameText:GetStringWidth() or 0, U.infoText:GetStringWidth() or 0)
        local rightX = hw - ORB_RIGHT - 66
        local az = U.navCluster:GetWidth() or 0
        local x = (leftX + rightX - az) / 2
        x = max(leftX + 16, min(x, rightX - 16 - az))
        U.navCluster:ClearAllPoints()
        U.navCluster:SetPoint("LEFT", U.navHeader, "LEFT", floor(x + 0.5), NAV_Y)
    end
end

local function Refresh()
    U.dirty = false
    UpdateHeader()
    local page = pages[U.current]
    if not page then return end
    if U.current == "character" then
        UpdateCharacterPage()
    elseif U.current == "pvp" then
        UpdatePvPPage()
    elseif U.current == "spellbook" then
        local G = Azaath:GetModule("Grimoire")
        if G and G.Refresh then G:Refresh() end
    elseif U.current == "talents" then
        local T = Azaath:GetModule("Talents")
        if T and T.Refresh then T:Refresh() end
    elseif U.current == "professions" then
        local P = Azaath:GetModule("Professions")
        if P and P.Refresh then P:Refresh() end
    elseif U.current == "drops" then
        local SD = Azaath:GetModule("SheetDrops")
        if SD and SD.Refresh then SD:Refresh() end
    elseif U.current == "dungeons" then
        local SDG = Azaath:GetModule("SheetDungeons")
        if SDG and SDG.Refresh then SDG:Refresh() end
    elseif U.current == "stats" then
        page.cats:SetEntries(CollectStatCategories())
        page.list:SetEntries(CollectStats())
    elseif U.current == "skills" and page.skills then
        page.skills:Refresh()
    elseif page.list then
        page.list:SetEntries(page.collect())
        if page.detail then page.detail:Set(page.detailFn()) end
    end
end

local function OpenTalents()
    local az = Azaath:GetModule("Talents")
    if az and az.Open and Azaath.db.talents and Azaath.db.talents.enabled then
        az:Open()
    elseif _G.ToggleTalentFrame then
        pcall(ToggleTalentFrame)
    elseif _G.PlayerSpellsUtil and PlayerSpellsUtil.ToggleClassTalentOrSpecFrame then
        pcall(PlayerSpellsUtil.ToggleClassTalentOrSpecFrame)
    elseif _G.ToggleTalentsWindow then
        pcall(ToggleTalentsWindow)
    end
end

local function OpenSpellbook()
    local az = Azaath:GetModule("Spellbook")
    if az and az.Open and Azaath.db.spellbook and Azaath.db.spellbook.enabled then
        az:Open()
    elseif _G.PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then
        pcall(PlayerSpellsUtil.ToggleSpellBookFrame)
    elseif _G.ToggleSpellBook then
        pcall(ToggleSpellBook, _G.BOOKTYPE_SPELL or "spell")
    end
end

local ACTION_TABS = {}
-- Modo janela: a ficha mantém o layout de tela cheia e é escalada por inteiro
-- (o cabeçalho, as listas e a arte usam medidas da tela; encolher o quadro os quebra)
local WIN_MIN, WIN_MAX, WIN_DEFAULT = 0.35, 0.95, 0.62

local function PlaceWindow(s, left, top)
    local f = U.frame
    local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
    s = max(WIN_MIN, min(WIN_MAX, s))
    left = max(0, min(left, pw - pw * s))
    top = max(ph * s, min(top, ph))
    f:SetScale(s)
    f:ClearAllPoints()
    f:SetSize(pw, ph)
    f:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left / s, top / s)
end

local function SaveWindow()
    local f = U.frame
    local s = f:GetScale()
    local l, t = f:GetLeft(), f:GetTop()
    if not (l and t) then return end
    M.db.window = { scale = s, left = l * s, top = t * s }
end

local function BuildWindowChrome()
    if U.winChrome then return U.winChrome end
    local media = Azaath.media
    local c = CreateFrame("Frame", nil, UIParent)
    c:SetFrameStrata("DIALOG")
    c:SetPoint("TOPLEFT", U.frame, "TOPLEFT", 0, 0)
    c:SetPoint("BOTTOMRIGHT", U.frame, "BOTTOMRIGHT", 0, 0)
    c:Hide()

    -- moldura em camadas, de fora para dentro: sombra, aro escuro, filete dourado, brilho ciano
    local function Edge(layer, sub, out, th, r, g, b, a, add)
        for _, side in ipairs({ "TOP", "BOTTOM", "LEFT", "RIGHT" }) do
            local t = c:CreateTexture(nil, layer, nil, sub)
            t:SetTexture(media.blank)
            if add then t:SetBlendMode("ADD") end
            t:SetVertexColor(r, g, b, a)
            if side == "TOP" or side == "BOTTOM" then
                local y = side == "TOP" and out or -out
                t:SetPoint(side .. "LEFT", c, side .. "LEFT", -out, y)
                t:SetPoint(side .. "RIGHT", c, side .. "RIGHT", out, y)
                t:SetHeight(th)
            else
                local x = side == "LEFT" and -out or out
                t:SetPoint("TOP" .. side, c, "TOP" .. side, x, out)
                t:SetPoint("BOTTOM" .. side, c, "BOTTOM" .. side, x, -out)
                t:SetWidth(th)
            end
        end
    end
    Edge("BACKGROUND", 0, 14, 8, 0, 0, 0, 0.22)
    Edge("BACKGROUND", 1, 7, 4, 0, 0, 0, 0.40)
    Edge("BORDER", 0, 4, 4, 0.02, 0.03, 0.05, 0.96)
    Edge("ARTWORK", 0, 2, 1.5, 0.80, 0.72, 0.52, 0.95)
    Edge("ARTWORK", 1, 0, 2, 0.38, 0.82, 1.0, 0.35, true)

    -- alça de redimensionar (canto inferior direito): mantém o canto superior esquerdo fixo
    local grip = CreateFrame("Button", nil, c)
    grip:SetSize(22, 22)
    grip:SetPoint("BOTTOMRIGHT", c, "BOTTOMRIGHT", -4, 4)
    grip:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    grip:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    grip:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    grip:SetScript("OnMouseDown", function(self)
        local f = U.frame
        local s = f:GetScale()
        self.left, self.top = f:GetLeft() * s, f:GetTop() * s
        self:SetScript("OnUpdate", function(g)
            local x = GetCursorPosition() / UIParent:GetEffectiveScale()
            PlaceWindow((x - g.left) / UIParent:GetWidth(), g.left, g.top)
            if U.SanctuaryFit then U.SanctuaryFit() end
        end)
    end)
    grip:SetScript("OnMouseUp", function(self)
        self:SetScript("OnUpdate", nil)
        SaveWindow()
    end)

    U.winChrome = c
    return c
end

local function ApplyWindowMode()
    local f = U.frame
    if not f then return end
    U.windowMode = M.db.windowMode and true or false
    if U.windowMode then
        local w = M.db.window or {}
        local pw, ph = UIParent:GetWidth(), UIParent:GetHeight()
        local s = w.scale or WIN_DEFAULT
        PlaceWindow(s, w.left or (pw - pw * s) / 2, w.top or (ph + ph * s) / 2)
        f:SetMovable(true)
        if U.navHeader then
            U.navHeader:EnableMouse(true)
            U.navHeader:RegisterForDrag("LeftButton")
            U.navHeader:SetScript("OnDragStart", function() f:StartMoving() end)
            U.navHeader:SetScript("OnDragStop", function()
                f:StopMovingOrSizing()
                f:SetUserPlaced(false)
                SaveWindow()
                local sw = M.db.window
                if sw then PlaceWindow(sw.scale, sw.left, sw.top) end
            end)
        end
        BuildWindowChrome():Show()
    else
        f:SetMovable(false)
        f:SetScale(1)
        f:ClearAllPoints()
        f:SetAllPoints(UIParent)
        if U.navHeader then
            U.navHeader:SetScript("OnDragStart", nil)
            U.navHeader:SetScript("OnDragStop", nil)
        end
        if U.winChrome then U.winChrome:Hide() end
    end
    if U.winToggle then
        U.winToggle.icon:SetTexture(MEDIA_ROOT .. (U.windowMode and "MapUI\\Maximize" or "MapUI\\Restore"))
        U.winToggle.tip = U.windowMode and "Tela cheia" or "Janela"
    end
    if U.SanctuaryFit then U.SanctuaryFit() end
end

-- trocar escala/posição com o quadro aberto deixa o recorte e a escala dos filhos
-- presos ao estado anterior: fecha e reabre para o jogo refazer o layout
local function ToggleSanctuaryWindow()
    M.db.windowMode = not M.db.windowMode
    U.quietReopen = true
    U.frame:Hide()
    U.frame:Show()
    U.quietReopen = nil
end
U.ToggleSanctuaryWindow = ToggleSanctuaryWindow

local function SelectTab(key)
    if ACTION_TABS[key] then ACTION_TABS[key]() return end
    -- Grimório sem o módulo carregado (ex.: arquivo novo antes de reiniciar o jogo): abre o livro antigo
    if key == "spellbook" and not (pages.spellbook and pages.spellbook.grimoire) then OpenSpellbook() return end
    if key == "talents" and not (pages.talents and pages.talents.talents) then OpenTalents() return end
    if not pages[key] then key = "character" end
    U.current = key
    M.db.tab = key
    for _, t in ipairs(U.tabButtons) do
        local active = t.key == key
        if pages[t.key] then Show(pages[t.key], active) end
        Show(t.activeFlare, active)
        Show(t.activeChevron, active)
        if active then
            t.text:SetTextColor(0.86, 0.96, 1.0)
        else
            t.text:SetTextColor(0.60, 0.64, 0.68)
        end
    end
    -- Grimório, Talentos e Ofícios ocupam a tela inteira: sem o rodapé do Santuário por cima da arte
    if U.frame and U.frame.modernFooter and U.frame.modernFooter.frame then
        Show(U.frame.modernFooter.frame, key ~= "spellbook" and key ~= "talents" and key ~= "professions" and key ~= "drops" and key ~= "dungeons")
        -- no Santuário a linha do rodapé já vem pintada na arte
        Show(U.frame.modernFooter.beam, key ~= "character")
    end
    if U.frame and U.frame.oldBackdrop then
        local ownArt = key == "character"
            or key == "reputation"
            or (key == "skills" and pages.skills and pages.skills.skills)
            or (key == "spellbook" and pages.spellbook and pages.spellbook.grimoire)
            or (key == "talents" and pages.talents and pages.talents.talents)
            or (key == "professions" and pages.professions and pages.professions.professions)
            or (key == "drops" and pages.drops and pages.drops.drops)
            or (key == "dungeons" and pages.dungeons and pages.dungeons.dungeons)
        for _, t in ipairs(U.frame.oldBackdrop) do Show(t, not ownArt) end
    end
    if key == "character" and U.model then
        U.model:SetUnit("player")
        U.model:SetFacing(U.model.facing or 0)
        if U.model.ApplyPose then U.model:ApplyPose(U.model.poseIdx or 1) end
    end
    Refresh()
end

--------------------------------------------------------------------------------
-- Construção Mestre da Janela Frameless em Tela Cheia (Build)
--------------------------------------------------------------------------------
local function Build()
    local media = Azaath.media
    local scrW, scrH = UIParent:GetWidth(), UIParent:GetHeight()
    U.vfxNodes = {}
    U.slots = {}
    U.tabButtons = {}

    U.frame = CreateFrame("Frame", "AzaathUISheet", UIParent)
    M.frame = U.frame
    U.frame:SetFrameStrata("HIGH")
    U.frame:SetToplevel(true)
    U.frame:SetAllPoints(UIParent)
    U.frame:EnableMouse(true)
    U.frame:SetClampedToScreen(true)
    U.frame:Hide()
    tinsert(UISpecialFrames, "AzaathUISheet")
    -- sempre recorta: em tela cheia o quadro é a tela; na janela segura a arte que sobra
    U.frame:SetClipsChildren(true)

    --==========================================================================
    -- 1. FUNDO ATMOSFÉRICO EM TELA CHEIA (Sem Caixas, Véu Lateral Suave)
    --==========================================================================
    local abyssBg = U.frame:CreateTexture(nil, "BACKGROUND", nil, -3)
    abyssBg:SetAllPoints(U.frame)
    abyssBg:SetTexture(Azaath.media.blank)
    abyssBg:SetVertexColor(0.01, 0.02, 0.04, 0.98)

    local sanctuaryBackdrop = U.frame:CreateTexture(nil, "BACKGROUND", nil, -2)
    sanctuaryBackdrop:SetAllPoints(U.frame)
    sanctuaryBackdrop:SetTexture(SHEET_MEDIA .. "StageBackdrop")
    sanctuaryBackdrop:SetTexCoord(0.06, 0.94, 0.04, 0.98)
    sanctuaryBackdrop:SetVertexColor(0.75, 0.85, 1.0, 0.88)
    U.frame.sanctuaryBackdrop = sanctuaryBackdrop

    -- Véu em degradê suave na metade direita para leitura perfeita sem caixa!
    local rightVeil = U.frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    rightVeil:SetPoint("TOPRIGHT", U.frame, "TOPRIGHT", 0, 0)
    rightVeil:SetPoint("BOTTOMRIGHT", U.frame, "BOTTOMRIGHT", 0, 0)
    rightVeil:SetWidth(scrW * 0.52)
    rightVeil:SetTexture(Azaath.media.blank)
    Azaath.Gradient(rightVeil, "HORIZONTAL", 0.01, 0.02, 0.04, 0.0, 0.01, 0.02, 0.04, 0.92)

    local vignette = U.frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    vignette:SetAllPoints(U.frame)
    vignette:SetTexture(MAP_MEDIA .. "MinimapVignette")
    vignette:SetVertexColor(0.01, 0.02, 0.05, 0.82)
    -- o Santuário tem a arte própria em tela cheia: o fundo antigo não pode
    -- aparecer por trás enquanto a arte nova carrega (ver SelectTab)
    U.frame.oldBackdrop = { sanctuaryBackdrop, rightVeil, vignette }

    -- pré-carrega e mantém residentes na VRAM as texturas grandes das abas
    -- (16-32 MB cada) em 1x1 px quase invisível, evitando piscar ao trocar de aba
    if not M.preload then
        M.preload = {}
        local paths = {
            SHEET_MEDIA .. "SanctuaryBG",
            SHEET_MEDIA .. "SanctuaryFlow",
            SHEET_MEDIA .. "AttrCard",
            SHEET_MEDIA .. "ReputationBG",
            SHEET_MEDIA .. "ReputationRunes",
            SHEET_MEDIA .. "ReputationPanel",
            SHEET_MEDIA .. "SkillsBG",
            SHEET_MEDIA .. "ProfessionsBG",
            MEDIA_ROOT .. "Grimoire\\GrimBG",
            MEDIA_ROOT .. "Talents\\CrucibleBG",
        }
        for i, path in ipairs(paths) do
            local t = UIParent:CreateTexture(nil, "BACKGROUND", nil, -8)
            t:SetTexture(path)
            t:SetSize(1, 1)
            t:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", i, 0)
            t:SetAlpha(0.01)
            M.preload[i] = t
        end
    end

    --==========================================================================
    -- 2. CABEÇALHO E NAVEGAÇÃO FLUTUANTES (Zero Caixas!)
    --==========================================================================
    local header = CreateFrame("Frame", nil, U.frame)
    header:SetPoint("TOPLEFT", U.frame, "TOPLEFT", PAD, -14)
    header:SetPoint("TOPRIGHT", U.frame, "TOPRIGHT", -PAD, -14)
    header:SetHeight(HEADER_H)
    header:SetFrameLevel(U.frame:GetFrameLevel() + 5)

    local fontCinzel = media.fontCinzel or media.fontTitleB

    -- 2A. Retrato Circular do Personagem + Brasão da Classe Inferior + Identidade (Esquerda)
    local _, classToken = UnitClass("player")

    local portraitFrame = CreateFrame("Frame", nil, header)
    portraitFrame:SetSize(64, 64)
    portraitFrame:SetPoint("LEFT", header, "LEFT", 6, 2)

    local portraitHalo = portraitFrame:CreateTexture(nil, "BACKGROUND", nil, 0)
    portraitHalo:SetTexture(MEDIA_ROOT .. "CastRingHalo")
    portraitHalo:SetBlendMode("ADD")
    portraitHalo:SetSize(84, 84)
    portraitHalo:SetPoint("CENTER")
    portraitHalo:SetVertexColor(0.32, 0.78, 0.96, 0.38)

    local portraitSphere = portraitFrame:CreateTexture(nil, "BACKGROUND", nil, 1)
    portraitSphere:SetSize(56, 56)
    portraitSphere:SetPoint("CENTER")
    portraitSphere:SetTexture(INV_MEDIA .. "SlotRound")
    portraitSphere:SetVertexColor(0.06, 0.08, 0.12, 0.96)

    U.portraitTex = portraitFrame:CreateTexture(nil, "ARTWORK", nil, 1)
    U.portraitTex:SetSize(54, 54)
    U.portraitTex:SetPoint("CENTER")
    if _G.SetPortraitTexture then pcall(SetPortraitTexture, U.portraitTex, "player") end
    ApplyCircleMask(portraitFrame, U.portraitTex)

    local portraitRim = portraitFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    portraitRim:SetSize(58, 58)
    portraitRim:SetPoint("CENTER")
    portraitRim:SetTexture(MEDIA_ROOT .. "CastRingThin")
    portraitRim:SetBlendMode("ADD")
    portraitRim:SetVertexColor(0.35, 0.82, 0.96, 0.40)

    local portraitRing = portraitFrame:CreateTexture(nil, "OVERLAY", nil, 2)
    portraitRing:SetSize(66, 66)
    portraitRing:SetPoint("CENTER")
    portraitRing:SetTexture(SHEET_MEDIA .. "RoundSlotFrame")
    portraitRing:SetVertexColor(0.80, 0.75, 0.62, 0.96)

    local portraitTopGem = portraitFrame:CreateTexture(nil, "OVERLAY", nil, 3)
    portraitTopGem:SetSize(8, 8)
    portraitTopGem:SetPoint("TOP", portraitFrame, "TOP", 0, 3)
    portraitTopGem:SetTexture(MEDIA_ROOT .. "Diamond")
    portraitTopGem:SetVertexColor(0.86, 0.82, 0.68, 0.96)

    -- Pequeno medalhão circular da classe sobreposto à base do retrato
    local classBadge = CreateFrame("Frame", nil, portraitFrame)
    classBadge:SetSize(22, 22)
    classBadge:SetPoint("CENTER", portraitFrame, "BOTTOM", 0, 2)
    classBadge:SetFrameLevel(portraitFrame:GetFrameLevel() + 3)

    local badgeGlow = classBadge:CreateTexture(nil, "BACKGROUND", nil, 0)
    badgeGlow:SetSize(30, 30)
    badgeGlow:SetPoint("CENTER")
    badgeGlow:SetTexture(MEDIA_ROOT .. "Glow")
    badgeGlow:SetBlendMode("ADD")
    badgeGlow:SetVertexColor(0.28, 0.84, 1.0, 0.65)

    local badgeBg = classBadge:CreateTexture(nil, "BACKGROUND", nil, 1)
    badgeBg:SetSize(20, 20)
    badgeBg:SetPoint("CENTER")
    badgeBg:SetTexture(INV_MEDIA .. "SlotRound")
    badgeBg:SetVertexColor(0.05, 0.08, 0.14, 0.98)

    local badgeIcon = classBadge:CreateTexture(nil, "ARTWORK", nil, 1)
    badgeIcon:SetSize(14, 14)
    badgeIcon:SetPoint("CENTER")
    if classToken and _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[classToken] then
        badgeIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
        badgeIcon:SetTexCoord(unpack(_G.CLASS_ICON_TCOORDS[classToken]))
    else
        badgeIcon:SetTexture("Interface\\Icons\\INV_Helmet_06")
    end
    badgeIcon:SetVertexColor(0.55, 0.92, 1.0)
    ApplyCircleMask(classBadge, badgeIcon)

    local badgeRing = classBadge:CreateTexture(nil, "OVERLAY", nil, 2)
    badgeRing:SetSize(23, 23)
    badgeRing:SetPoint("CENTER")
    badgeRing:SetTexture(SHEET_MEDIA .. "RoundSlotFrame")
    badgeRing:SetVertexColor(0.82, 0.76, 0.58, 0.96)

    U.nameText = CreateText(header, fontCinzel, 22, { 0.95, 0.93, 0.88 }, "LEFT", "")
    U.nameText:SetShadowOffset(1, -1)
    U.nameText:SetShadowColor(0, 0, 0, 0.85)
    U.nameText:SetPoint("BOTTOMLEFT", portraitFrame, "RIGHT", 16, 2)

    U.infoText = CreateText(header, fontCinzel, 10.5, { 0.72, 0.76, 0.82 }, "LEFT", "")
    U.infoText:SetShadowOffset(1, -1)
    U.infoText:SetShadowColor(0, 0, 0, 0.85)
    U.infoText:SetPoint("TOPLEFT", portraitFrame, "RIGHT", 16, -4)

    -- 2B. Orbe de Poder de Item (Direita): moldura de 4 pontas, anel ciano/ouro e disco
    --     recortados da arte de conceito (tools/sheet-nav-concept/gen-orb.js, 77 px -> 65.5 de UI).
    --     Centro na altura do retrato; ponta direita na mesma margem da moldura do retrato.
    U.gsOrb = CreateFrame("Frame", nil, header)
    U.gsOrb:SetSize(66, 66)
    U.gsOrb:SetPoint("CENTER", header, "RIGHT", -ORB_RIGHT - 33, 1)

    -- Botões padrão no canto superior direito: janela/tela cheia e fechar
    local function HeaderIcon(tex, tip, onClick)
        local b = CreateFrame("Button", nil, header)
        b:SetSize(26, 26)
        b:SetFrameLevel(header:GetFrameLevel() + 3)
        local bg = b:CreateTexture(nil, "BACKGROUND")
        bg:SetTexture(INV_MEDIA .. "SlotRound")
        bg:SetAllPoints(b)
        bg:SetVertexColor(0.05, 0.08, 0.12, 0.92)
        local rim = b:CreateTexture(nil, "BORDER")
        rim:SetTexture(MEDIA_ROOT .. "MapUI\\Rim")
        rim:SetAllPoints(b)
        rim:SetVertexColor(0.80, 0.75, 0.62, 0.90)
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetTexture(tex)
        b.icon:SetSize(14, 14)
        b.icon:SetPoint("CENTER")
        b.icon:SetVertexColor(0.72, 0.80, 0.86)
        b.tip = tip
        b:SetScript("OnEnter", function(self)
            self.icon:SetVertexColor(0.86, 0.96, 1.0)
            GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
            GameTooltip:SetText(self.tip)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            self.icon:SetVertexColor(0.72, 0.80, 0.86)
            GameTooltip:Hide()
        end)
        b:SetScript("OnClick", function()
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            onClick()
        end)
        return b
    end
    local btnX = HeaderIcon(MEDIA_ROOT .. "MapUI\\Close", "Fechar", function() M:Close() end)
    btnX:SetPoint("CENTER", header, "RIGHT", -4 - 13, 1)
    U.winToggle = HeaderIcon(MEDIA_ROOT .. "MapUI\\Restore", "Janela", function() U.ToggleSanctuaryWindow() end)
    U.winToggle:SetPoint("RIGHT", btnX, "LEFT", -6, 0)

    local gsRingHolder = U.gsOrb
    local gsArt = U.gsOrb:CreateTexture(nil, "ARTWORK", nil, 1)
    gsArt:SetTexture(SHEET_MEDIA .. "ItemPowerOrb")
    gsArt:SetSize(65.5, 65.5)
    gsArt:SetPoint("CENTER")

    U.ilvlText = CreateText(gsRingHolder, fontCinzel, 19, { 0.80, 0.94, 0.97 }, "CENTER", "")
    U.ilvlText:SetShadowOffset(1, -1)
    U.ilvlText:SetShadowColor(0, 0, 0, 0.9)
    U.ilvlText:SetPoint("CENTER", gsRingHolder, "CENTER", 0, 0)
    U.ilvlText:SetText("0")

    local gsTitle = CreateText(U.gsOrb, fontCinzel, 9, { 0.70, 0.71, 0.72 }, "CENTER", "")
    gsTitle:SetShadowOffset(1, -1)
    gsTitle:SetShadowColor(0, 0, 0, 0.85)
    gsTitle:SetPoint("CENTER", U.gsOrb, "CENTER", 0, -38)
    gsTitle:SetText(Azaath.Upper("PODER DE ITEM"))

    -- 2C. Menu Superior: abas em serifa, linha do horizonte fina sob todas elas,
    --     clarão estelar (núcleo + risco + halo) e seta "^" sob a aba ativa (arte de conceito)
    U.navHeader = header
    U.navCluster = CreateFrame("Frame", nil, header)
    U.navCluster:SetSize(680, 44)
    U.navCluster:SetPoint("CENTER", header, "CENTER", 36, NAV_Y)

    local navHorizon = U.navCluster:CreateTexture(nil, "BORDER")
    navHorizon:SetTexture(SHEET_MEDIA .. "NavLine")
    navHorizon:SetBlendMode("ADD")
    navHorizon:SetHeight(3.4)
    navHorizon:SetPoint("LEFT", U.navCluster, "LEFT", 0, NAV_LINE_Y)
    navHorizon:SetPoint("RIGHT", U.navCluster, "RIGHT", 0, NAV_LINE_Y)
    navHorizon:SetVertexColor(1, 1, 1, 0.20)

    local navX = 0
    for i, def in ipairs(TABS) do
        local t = CreateFrame("Button", nil, U.navCluster)
        t.key = def.key
        t.label = def.label
        t.action = def.action

        t.text = CreateText(t, fontCinzel, NAV_FONT, { 0.60, 0.64, 0.68 }, "CENTER", "")
        t.text:SetShadowOffset(1, -1)
        t.text:SetShadowColor(0, 0, 0, 0.85)
        t.text:SetPoint("CENTER", t, "CENTER", 0, NAV_TEXT_Y)
        t.text:SetText(Azaath.Upper(def.label))
        local tabW = floor((t.text:GetStringWidth() or 70) + NAV_GAP + 0.5)
        t:SetSize(tabW, 44)
        t:SetPoint("LEFT", U.navCluster, "LEFT", navX, 0)
        navX = navX + tabW

        -- Clarão: 384x48 px da arte -> 326x41 de UI, centrado na linha do horizonte
        t.activeFlare = t:CreateTexture(nil, "ARTWORK", nil, 1)
        t.activeFlare:SetTexture(SHEET_MEDIA .. "NavFlare")
        t.activeFlare:SetBlendMode("ADD")
        t.activeFlare:SetSize(326, 41)
        t.activeFlare:SetPoint("CENTER", t, "CENTER", 0, NAV_LINE_Y)
        t.activeFlare:Hide()

        -- Seta "^": 16x16 px da arte -> 13.6 de UI, centro 11.8 px abaixo da linha
        t.activeChevron = t:CreateTexture(nil, "ARTWORK", nil, 2)
        t.activeChevron:SetTexture(SHEET_MEDIA .. "NavChevron")
        t.activeChevron:SetBlendMode("ADD")
        t.activeChevron:SetSize(13.6, 13.6)
        t.activeChevron:SetPoint("CENTER", t, "CENTER", 0, NAV_LINE_Y - 10)
        t.activeChevron:Hide()

        t:SetScript("OnClick", function()
            Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
            SelectTab(def.key)
        end)
        t:SetScript("OnEnter", function(self)
            if U.current ~= self.key then
                self.text:SetTextColor(0.86, 0.90, 0.94)
            end
        end)
        t:SetScript("OnLeave", function(self)
            if U.current ~= self.key then
                self.text:SetTextColor(0.60, 0.64, 0.68)
            end
        end)
        U.tabButtons[#U.tabButtons + 1] = t
    end
    U.navCluster:SetWidth(max(1, navX))
    -- a linha começa/termina nas bordas dos nomes (as pontas da textura já esmaecem)
    navHorizon:ClearAllPoints()
    navHorizon:SetPoint("LEFT", U.navCluster, "LEFT", NAV_GAP / 2, NAV_LINE_Y)
    navHorizon:SetPoint("RIGHT", U.navCluster, "RIGHT", -NAV_GAP / 2, NAV_LINE_Y)

    --==========================================================================
    -- 3. ÁREA DE CONTEÚDO PRINCIPAL
    --==========================================================================
    local topOffset = 14 + HEADER_H + 10
    local bottomOffset = FOOTER_H + 12
    local cw, ch = scrW - PAD * 2, scrH - topOffset - bottomOffset

    U.content = CreateFrame("Frame", nil, U.frame)
    U.content:SetPoint("TOPLEFT", U.frame, "TOPLEFT", PAD, -topOffset)
    U.content:SetPoint("BOTTOMRIGHT", U.frame, "BOTTOMRIGHT", -PAD, bottomOffset)

    for _, def in ipairs(TABS) do
        if not def.action then
            local page = CreateFrame("Frame", nil, U.content)
            page:SetAllPoints(U.content)
            page:Hide()
            pages[def.key] = page
        end
    end

    BuildCharacterPage(pages.character, cw, ch)
    BuildReputationPage(pages.reputation)
    pages.reputation.collect = CollectReputation
    pages.reputation.detailFn = ReputationDetail
    M.BuildSkillsTab(pages.skills, cw, ch)
    ListPage(pages.currency, cw, ch, CollectCurrency, CurrencyDetail,
        "Nenhuma moeda registrada.", "Selecione uma moeda para ver os detalhes.")
    BuildPvPPage(pages.pvp, cw, ch)
    local grimoire = Azaath:GetModule("Grimoire")
    if grimoire and grimoire.BuildPage then
        local ok, err = pcall(grimoire.BuildPage, grimoire, pages.spellbook, cw, ch)
        if not ok then
            pages.spellbook.grimoire = nil
            if Azaath.LogError then Azaath.LogError("Grimório: " .. tostring(err)) end
        end
    end
    local talents = Azaath:GetModule("Talents")
    if talents and talents.BuildPage then
        local ok, err = pcall(talents.BuildPage, talents, pages.talents, cw, ch)
        if not ok then
            pages.talents.talents = nil
            if Azaath.LogError then Azaath.LogError("Talentos: " .. tostring(err)) end
        end
    end
    local professions = Azaath:GetModule("Professions")
    if professions and professions.BuildPage then
        local ok, err = pcall(professions.BuildPage, professions, pages.professions, cw, ch)
        if not ok then
            pages.professions.professions = nil
            if Azaath.LogError then Azaath.LogError("Ofícios: " .. tostring(err)) end
        end
    end
    local sdrops = Azaath:GetModule("SheetDrops")
    if sdrops and sdrops.BuildPage then
        local ok, err = pcall(sdrops.BuildPage, sdrops, pages.drops, cw, ch)
        if not ok then
            pages.drops.drops = nil
            if Azaath.LogError then Azaath.LogError("Drops: " .. tostring(err)) end
        end
    end
    local sdungeons = Azaath:GetModule("SheetDungeons")
    if sdungeons and sdungeons.BuildPage then
        local ok, err = pcall(sdungeons.BuildPage, sdungeons, pages.dungeons, cw, ch)
        if not ok then
            pages.dungeons.dungeons = nil
            if Azaath.LogError then Azaath.LogError("Masmorras: " .. tostring(err)) end
        end
    end
    pages.stats.cats = NewList(pages.stats, 0, 0, 300, ch, "Sem categorias.")
    pages.stats.list = NewList(pages.stats, 320, 0, cw - 320, ch, "Sem estatísticas.")

    --==========================================================================
    -- 4. RODAPÉ FLUTUANTE MINIMALISTA (Sem Caixa!)
    --==========================================================================
    local footer = CreateFrame("Frame", nil, U.frame)
    footer:SetPoint("BOTTOMLEFT", U.frame, "BOTTOMLEFT", PAD, 8)
    footer:SetPoint("BOTTOMRIGHT", U.frame, "BOTTOMRIGHT", -PAD, 8)
    footer:SetHeight(FOOTER_H)
    footer:SetFrameLevel(U.frame:GetFrameLevel() + 5)

    local footerBeam = footer:CreateTexture(nil, "BORDER")
    footerBeam:SetTexture(UF_MEDIA .. "ClassicGlassH")
    footerBeam:SetBlendMode("ADD")
    footerBeam:SetPoint("TOPLEFT", footer, "TOPLEFT", 0, 0)
    footerBeam:SetPoint("TOPRIGHT", footer, "TOPRIGHT", 0, 0)
    footerBeam:SetHeight(2)
    footerBeam:SetVertexColor(0.38, 0.82, 1.0, 0.28)

    local duraLabel = CreateText(footer, media.fontTitleB, 10, { 0.68, 0.82, 0.95 }, "LEFT")
    duraLabel:SetPoint("LEFT", footer, "LEFT", 6, 0)

    local repairLabel = CreateText(footer, media.fontTitleB, 10, { 0.96, 0.84, 0.48 }, "LEFT")
    repairLabel:SetPoint("LEFT", duraLabel, "RIGHT", 36, 0)

    local bagLabel = CreateText(footer, media.fontTitleB, 10, { 0.68, 0.82, 0.95 }, "LEFT")
    bagLabel:SetPoint("LEFT", repairLabel, "RIGHT", 36, 0)

    U.frame.modernFooter = {
        frame = footer,
        beam = footerBeam,
        duraLabel = duraLabel,
        repairLabel = repairLabel,
        bagLabel = bagLabel,
    }

    --==========================================================================
    -- 5. TRANSIÇÃO CINEMATOGRÁFICA DE ABERTURA E ATUALIZAÇÃO
    --==========================================================================
    U.frame:SetScript("OnShow", function()
        ApplyWindowMode()
        U.frame:SetAlpha(0)
        local fadeElapsed = 0
        local fader = CreateFrame("Frame", nil, U.frame)
        fader:SetScript("OnUpdate", function(self, e)
            fadeElapsed = fadeElapsed + e
            local a = min(1, fadeElapsed / 0.18)
            U.frame:SetAlpha(a * (2 - a))
            if a >= 1 then self:SetScript("OnUpdate", nil) end
        end)
        if not U.quietReopen then Azaath.PlaySound("igCharacterInfoOpen") end
        SelectSub(M.db.sub or "attributes")
        SelectTab(M.db.tab or "character")
    end)

    U.frame:SetScript("OnHide", function()
        if not U.quietReopen then Azaath.PlaySound("igCharacterInfoClose") end
        selected.abandon, selected.deleteSet = nil, nil
        if U.winChrome then U.winChrome:Hide() end
    end)

    local elapsed = 0
    U.frame:SetScript("OnUpdate", function(_, e)
        elapsed = elapsed + e
        if elapsed < 0.20 then return end
        elapsed = 0
        if U.dirty then Refresh()
        elseif U.current == "character" and U.currentSub == "attributes" then UpdateVitals() end
    end)
end

--------------------------------------------------------------------------------
-- Métodos Públicos e Atalhos (Tecla C)
--------------------------------------------------------------------------------
function M:IsOpen() return U.frame and U.frame:IsShown() end

function M:Open(tab)
    if not U.frame then return end
    if ACTION_TABS[tab] then ACTION_TABS[tab]() return end
    if tab == "spellbook" and not (pages.spellbook and pages.spellbook.grimoire) then OpenSpellbook() return end
    if tab == "talents" and not (pages.talents and pages.talents.talents) then OpenTalents() return end
    if tab then M.db.tab = tab end
    if U.frame:IsShown() then SelectTab(M.db.tab) else U.frame:Show() end
end

function M:Close()
    if U.frame and U.frame:IsShown() then U.frame:Hide() end
end

function M:Toggle(tab)
    if U.frame and U.frame:IsShown() and (not tab or tab == U.current) then
        self:Close()
    else
        self:Open(tab)
    end
end

local function UpdateBinding()
    local key1, key2 = GetBindingKey("TOGGLECHARACTER0")
    local signature = (key1 or "") .. "," .. (key2 or "")
    if signature == U.lastBindingSignature then return end
    Azaath:RunOutOfCombat(function()
        U.lastBindingSignature = signature
        ClearOverrideBindings(U.bindOwner)
        for _, key in ipairs({ key1, key2 }) do
            if key and key ~= "" then
                SetOverrideBindingClick(U.bindOwner, false, key, "AzaathUISheetToggle", "LeftButton")
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UPDATE_BINDINGS" then
        UpdateBinding()
        return
    end
    if event == "UNIT_MODEL_CHANGED" then
        if unit == "player" and U.model and U.frame and U.frame:IsShown() then
            U.model:SetUnit("player")
            U.model:SetFacing(U.model.facing or 0)
            if U.model.ApplyPose then U.model:ApplyPose(U.model.poseIdx or 1) end
        end
        return
    end
    if event:sub(1, 5) == "UNIT_" and unit ~= "player" then return end
    U.dirty = true
end)

--------------------------------------------------------------------------------
-- Ciclo de Vida
--------------------------------------------------------------------------------
function M:OnInitialize()
    self.db = Azaath.db.sheet
end

function M:OnEnable()
    if not self.db.enabled then return end
    Build()

    U.toggleButton = CreateFrame("Button", "AzaathUISheetToggle", UIParent)
    U.toggleButton:RegisterForClicks("LeftButtonUp")
    U.toggleButton:SetScript("OnClick", function() M:Toggle() end)
    U.bindOwner = CreateFrame("Frame")
    UpdateBinding()

    for _, e in ipairs({ "UNIT_INVENTORY_CHANGED", "PLAYER_EQUIPMENT_CHANGED", "UPDATE_INVENTORY_DURABILITY",
                         "UNIT_STATS", "UNIT_RESISTANCES", "UNIT_ATTACK_POWER", "UNIT_RANGED_ATTACK_POWER",
                         "UNIT_DAMAGE", "UNIT_ATTACK_SPEED", "UNIT_MAXHEALTH", "UNIT_MAXPOWER",
                         "COMBAT_RATING_UPDATE", "PLAYER_DAMAGE_DONE_MODS", "PLAYER_LEVEL_UP", "PLAYER_XP_UPDATE",
                         "UNIT_MODEL_CHANGED", "UNIT_PORTRAIT_UPDATE", "UPDATE_BINDINGS", "PLAYER_GUILD_UPDATE",
                         "UPDATE_FACTION", "SKILL_LINES_CHANGED", "CURRENCY_DISPLAY_UPDATE", "PLAYER_MONEY",
                         "EQUIPMENT_SETS_CHANGED", "EQUIPMENT_SWAP_FINISHED", "KNOWN_TITLES_UPDATE",
                         "PLAYER_PVP_KILLS_CHANGED", "PLAYER_PVP_RANK_CHANGED", "HONOR_XP_UPDATE",
                         "CRITERIA_UPDATE", "BAG_UPDATE_COOLDOWN" }) do
        Azaath.SafeRegister(events, e)
    end
end
