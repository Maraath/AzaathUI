--[[----------------------------------------------------------------------------
    AzaathUI - Modules/MicroMenu.lua
    Barra de utilidades (Micro Menu) estilo Black Desert Online com tema Azaath:

      * Visual minimalista BDO:
        - Ícones vetoriais brancos/prateados sobre disco translúcido sutil
        - Brilho radial em ciano Azaath no hover e quando a janela está aberta
        - Badges numéricas circulares (talentos disponíveis, missões, amigos, guilda)
        - Botão losango central para recolher/expandir os ícones principais
      * Placar de Informação (estilo BDO com paleta Azaath):
        - Painel flutuante próprio acima do ícone em foco (ou abaixo, se no topo)
        - Título, atalho de teclado, descrição da seção, status ao vivo e FPS/MS
      * Segurança de combate:
        - O botão do Livro de Feitiços usa SecureHandlerClickTemplate apontando
          para AzaathUISpellbook (permitindo abrir/fechar o grimório Azaath mesmo
          durante o combate, sem taint).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("MicroMenu")

local _G = _G
local ipairs, format, floor, pcall, max, min = ipairs, string.format, math.floor, pcall, math.max, math.min
local InCombatLockdown = InCombatLockdown

local MEDIA_DIR = Azaath.media.path .. "MicroMenu\\"

-- Paleta Azaath para o Micro Menu e Placares de Informação
local AZAATH = {
    cyan       = { 0.30, 0.85, 0.95 }, -- brilho principal Azaath
    cyanBright = { 0.55, 0.93, 1.00 }, -- destaque / título
    border     = { 0.22, 0.72, 0.86 }, -- borda do placar
    bg         = { 0.04, 0.065, 0.095 }, -- fundo obsidiana Azaath
    desc       = { 0.66, 0.76, 0.83 }, -- texto descritivo
    hint       = { 0.45, 0.78, 0.86 }, -- dica de clique direito
    badgeBg    = { 0.78, 0.58, 0.16 }, -- círculo dourado/âmbar estilo BDO
    discIdle   = { 0.05, 0.08, 0.12 }, -- disco sutil em repouso
}

local bar
local placard
local buttons = {}

--------------------------------------------------------------------------------
-- Ações de cada botão de utilidade
--------------------------------------------------------------------------------
local function ToggleCharacterAndInventory(mouseButton)
    if mouseButton == "RightButton" then
        if _G.ToggleCharacter then _G.ToggleCharacter("PaperDollFrame") end
        return
    end
    local sheet = Azaath:GetModule("Sheet")
    if sheet and sheet.Toggle and Azaath.db.sheet.enabled then
        sheet:Toggle()
    elseif _G.ToggleCharacter then
        _G.ToggleCharacter("PaperDollFrame")
    end
end

local function ToggleTalentsWindow(mouseButton)
    local az = Azaath:GetModule("Talents")
    if mouseButton ~= "RightButton" and az and az.Toggle and Azaath.db.talents and Azaath.db.talents.enabled then
        az:Toggle()
    elseif _G.ToggleTalentFrame then
        _G.ToggleTalentFrame()
    elseif _G.PlayerSpellsUtil and _G.PlayerSpellsUtil.ToggleClassTalentOrSpecFrame then
        _G.PlayerSpellsUtil.ToggleClassTalentOrSpecFrame()
    end
end

local function ToggleAchievementsWindow()
    if _G.ToggleAchievementFrame then
        _G.ToggleAchievementFrame()
    end
end

local function ToggleQuestLogWindow(mouseButton)
    if mouseButton == "RightButton" then
        local wm = Azaath:GetModule("WorldMap")
        if wm and wm.Toggle and Azaath.db.worldmap.enabled then
            wm:Toggle()
            return
        end
    end
    if _G.ToggleQuestLog then
        _G.ToggleQuestLog()
    else
        local wm = Azaath:GetModule("WorldMap")
        if wm and wm.Toggle and Azaath.db.worldmap.enabled then
            wm:Toggle()
        elseif _G.ToggleWorldMap then
            _G.ToggleWorldMap()
        end
    end
end

local function ToggleWorldMapWindow(mouseButton)
    local wm = Azaath:GetModule("WorldMap")
    if mouseButton ~= "RightButton" and wm and wm.Toggle and Azaath.db.worldmap.enabled then
        wm:Toggle()
    elseif wm and wm.OpenDefaultWorldMap then
        wm:OpenDefaultWorldMap()
    elseif _G.ToggleWorldMap then
        _G.ToggleWorldMap()
    end
end

local function ToggleSocialWindow()
    if _G.ToggleFriendsFrame then
        _G.ToggleFriendsFrame(1)
    end
end

local function ToggleGuildWindow()
    if _G.ToggleGuildFrame then
        _G.ToggleGuildFrame()
    elseif _G.ToggleFriendsFrame then
        _G.ToggleFriendsFrame(3)
    end
end

local function ToggleGroupFinderWindow(mouseButton)
    if mouseButton == "RightButton" then
        if _G.PVEFrame_ToggleFrame then
            _G.PVEFrame_ToggleFrame("PVPUIFrame")
        elseif _G.TogglePVPFrame then
            _G.TogglePVPFrame()
        end
        return
    end
    if _G.PVEFrame_ToggleFrame then
        _G.PVEFrame_ToggleFrame("GroupFinderFrame")
    elseif _G.ToggleLFDParentFrame then
        _G.ToggleLFDParentFrame()
    elseif _G.LFDMicroButton and _G.LFDMicroButton.Click then
        _G.LFDMicroButton:Click()
    elseif _G.LFGMicroButton and _G.LFGMicroButton.Click then
        _G.LFGMicroButton:Click()
    elseif _G.TogglePVPFrame then
        _G.TogglePVPFrame()
    end
end

local function ToggleCollectionsWindow()
    if _G.ToggleCollectionsJournal then
        _G.ToggleCollectionsJournal()
    elseif _G.ToggleCharacter then
        _G.ToggleCharacter("PetPaperDollFrame")
    end
end

local function ToggleHelpWindow()
    if _G.ToggleHelpFrame then
        _G.ToggleHelpFrame()
    end
end

local function ToggleMainMenuWindow(mouseButton)
    if mouseButton == "RightButton" then
        local cfg = Azaath:GetModule("Config")
        if cfg and cfg.Toggle then cfg:Toggle() end
        return
    end
    if _G.GameMenuFrame then
        if _G.GameMenuFrame:IsShown() then
            PlaySound(_G.SOUNDKIT and _G.SOUNDKIT.IG_MAINMENU_QUIT or "igMainMenuQuit")
            Azaath.HidePanel(_G.GameMenuFrame)
        else
            PlaySound(_G.SOUNDKIT and _G.SOUNDKIT.IG_MAINMENU_OPEN or "igMainMenuOpen")
            Azaath.ShowPanel(_G.GameMenuFrame)
        end
    end
end

--------------------------------------------------------------------------------
-- Contadores dinâmicos para Badges (estilo BDO)
--------------------------------------------------------------------------------
local function GetUnspentTalentsCount()
    if _G.GetUnspentTalentPoints then
        local ok, n = pcall(_G.GetUnspentTalentPoints, false, false)
        if ok and type(n) == "number" and n > 0 then return n end
    end
    if _G.UnitCharacterPoints then
        local ok, n = pcall(_G.UnitCharacterPoints, "player")
        if ok and type(n) == "number" and n > 0 then return n end
    end
    return 0
end

local function GetActiveQuestsCount()
    if _G.C_QuestLog and _G.C_QuestLog.GetNumQuestLogEntries then
        local ok, _, numQuests = pcall(_G.C_QuestLog.GetNumQuestLogEntries)
        if ok and type(numQuests) == "number" and numQuests > 0 then return numQuests end
    elseif _G.GetNumQuestLogEntries then
        local ok, _, numQuests = pcall(_G.GetNumQuestLogEntries)
        if ok and type(numQuests) == "number" and numQuests > 0 then return numQuests end
    end
    return 0
end

local function GetOnlineFriendsCount()
    if _G.C_FriendList and _G.C_FriendList.GetNumOnlineFriends then
        local ok, n = pcall(_G.C_FriendList.GetNumOnlineFriends)
        if ok and type(n) == "number" and n > 0 then return n end
    elseif _G.GetNumFriends then
        local ok, _, online = pcall(_G.GetNumFriends)
        if ok and type(online) == "number" and online > 0 then return online end
    end
    return 0
end

local function GetOnlineGuildCount()
    if _G.IsInGuild and not _G.IsInGuild() then return 0 end
    if _G.GetNumGuildMembers then
        local ok, _, online = pcall(_G.GetNumGuildMembers)
        if ok and type(online) == "number" and online > 0 then return online end
    end
    return 0
end

-- Abas do Santuário (Drops, Masmorras): abre na aba; se ela já estiver aberta, fecha
local function OpenSheetTab(tab)
    local s = Azaath:GetModule("Sheet")
    if s and s.Toggle then s:Toggle(tab) end
end

local function SheetTabOpen(tab)
    local s = Azaath:GetModule("Sheet")
    return s and s.IsOpen and s:IsOpen() and s.db and s.db.tab == tab or false
end

--------------------------------------------------------------------------------
-- Definição dos Botões (com descrições estilo BDO para os placares)
--------------------------------------------------------------------------------
local BUTTON_DEFS = {
    {
        key      = "character",
        label    = "Ficha do Personagem",
        desc     = "Inspecione atributos, equipamentos, reputação e inventário do seu personagem.",
        binding  = "TOGGLECHARACTER0",
        icon     = MEDIA_DIR .. "Character.tga",
        hint     = "Clique direito: Ficha padrão da Blizzard",
        group    = "main",
        onClick  = ToggleCharacterAndInventory,
        isOpen   = function()
            local s = Azaath:GetModule("Sheet")
            return (s and s.frame and s.frame:IsShown())
                or (_G.CharacterFrame and _G.CharacterFrame:IsShown())
        end,
    },
    {
        key      = "spellbook",
        label    = "Livro de Feitiços",
        desc     = "Consulte suas magias, habilidades de classe, profissões e passivas aprendidas.",
        binding  = "TOGGLESPELLBOOK",
        icon     = MEDIA_DIR .. "Spellbook.tga",
        hint     = "Clique direito: Livro padrão da Blizzard",
        group    = "main",
        secure   = true,
        grimoire = true,
        onClick  = function(mouseButton)
            if mouseButton == "RightButton" then
                if not InCombatLockdown() then Azaath.API.OpenDefaultSpellbook() end
                return
            end
            local g = Azaath:GetModule("Grimoire")
            if g and g.Toggle then g:Toggle() end
        end,
        isOpen   = function()
            local sb = Azaath:GetModule("Spellbook")
            local g = Azaath:GetModule("Grimoire")
            return (sb and sb.frame and sb.frame:IsShown())
                or (g and g.IsOpen and g:IsOpen())
                or (_G.SpellBookFrame and _G.SpellBookFrame:IsShown())
        end,
    },
    {
        key      = "talents",
        label    = "Talentos & Especialização",
        desc     = "Distribua pontos de talento, alterne especializações e personalize sua build.",
        binding  = "TOGGLETALENTS",
        icon     = MEDIA_DIR .. "Talents.tga",
        hint     = "Clique direito: Janela padrão do jogo",
        group    = "main",
        badge    = GetUnspentTalentsCount,
        statusFn = function()
            local n = GetUnspentTalentsCount()
            if n > 0 then
                return format("Pontos disponíveis: |cff5ce1e6%d|r", n)
            end
        end,
        onClick  = ToggleTalentsWindow,
        isOpen   = function()
            local az = Azaath:GetModule("Talents")
            return (az and az.IsOpen and az:IsOpen())
                or (az and az.frame and az.frame:IsShown())
                or (_G.PlayerTalentFrame and _G.PlayerTalentFrame:IsShown())
                or (_G.ClassTalentFrame and _G.ClassTalentFrame:IsShown())
                or (_G.PlayerSpellsFrame and _G.PlayerSpellsFrame:IsShown())
        end,
    },
    {
        key      = "drops",
        label    = "Relicário (Drops)",
        desc     = "Procure equipamentos, receitas e consumíveis por categoria, veja de onde caem e a chance de drop.",
        icon     = MEDIA_DIR .. "Drops.tga",
        group    = "main",
        onClick  = function() OpenSheetTab("drops") end,
        isOpen   = function() return SheetTabOpen("drops") end,
    },
    {
        key      = "dungeons",
        label    = "Masmorras & Raides",
        desc     = "Catálogo das masmorras e raides com os chefes e o espólio de cada um.",
        icon     = MEDIA_DIR .. "Dungeons.tga",
        group    = "main",
        onClick  = function() OpenSheetTab("dungeons") end,
        isOpen   = function() return SheetTabOpen("dungeons") end,
    },
    {
        key      = "achievements",
        label    = "Conquistas",
        desc     = "Acompanhe seus feitos, títulos, pontos de conquista e progresso de exploração.",
        binding  = "TOGGLEACHIEVEMENT",
        icon     = MEDIA_DIR .. "Achievements.tga",
        group    = "main",
        onClick  = ToggleAchievementsWindow,
        isOpen   = function()
            return _G.AchievementFrame and _G.AchievementFrame:IsShown()
        end,
    },
    {
        key      = "quests",
        label    = "Registro de Missões",
        desc     = "Veja todas as missões ativas, objetivos detalhados e recompensas da jornada.",
        binding  = "TOGGLEQUESTLOG",
        icon     = MEDIA_DIR .. "Quests.tga",
        hint     = "Clique direito: Mapa-Múndi Azaath",
        group    = "main",
        badge    = GetActiveQuestsCount,
        statusFn = function()
            local n = GetActiveQuestsCount()
            if n > 0 then
                return format("Missões no diário: |cff5ce1e6%d|r", n)
            end
        end,
        onClick  = ToggleQuestLogWindow,
        isOpen   = function()
            return _G.QuestLogFrame and _G.QuestLogFrame:IsShown()
        end,
    },
    {
        key      = "social",
        label    = "Social & Amigos",
        desc     = "Gerencie sua lista de amigos, jogadores próximos e convites de grupo.",
        binding  = "TOGGLESOCIAL",
        icon     = MEDIA_DIR .. "Social.tga",
        group    = "main",
        badge    = GetOnlineFriendsCount,
        statusFn = function()
            local n = GetOnlineFriendsCount()
            if n > 0 then
                return format("Amigos conectados: |cff5ce1e6%d|r", n)
            end
        end,
        onClick  = ToggleSocialWindow,
        isOpen   = function()
            return _G.FriendsFrame and _G.FriendsFrame:IsShown()
        end,
    },
    {
        key      = "guild",
        label    = "Guilda",
        desc     = "Acesse a lista de membros, notícias, banco e atividades da sua guilda.",
        binding  = "TOGGLEGUILDTAB",
        icon     = MEDIA_DIR .. "Guild.tga",
        group    = "main",
        badge    = GetOnlineGuildCount,
        statusFn = function()
            local n = GetOnlineGuildCount()
            if n > 0 then
                return format("Membros online: |cff5ce1e6%d|r", n)
            end
        end,
        onClick  = ToggleGuildWindow,
        isOpen   = function()
            return (_G.GuildFrame and _G.GuildFrame:IsShown())
                or (_G.CommunitiesFrame and _G.CommunitiesFrame:IsShown())
        end,
    },
    {
        key      = "lfd",
        label    = "Localizador de Grupos",
        desc     = "Entre na fila do Localizador de Grupos para masmorras, raides, campos de batalha e arenas.",
        binding  = { "TOGGLEGROUPFINDER", "TOGGLELFGPARENT" },
        icon     = MEDIA_DIR .. "GroupFinder.tga",
        hint     = "Clique esquerdo: Localizador de Grupos · Clique direito: JxJ",
        group    = "main",
        onClick  = ToggleGroupFinderWindow,
        isOpen   = function()
            return (_G.PVEFrame and _G.PVEFrame:IsShown())
                or (_G.LFDParentFrame and _G.LFDParentFrame:IsShown())
                or (_G.PVPFrame and _G.PVPFrame:IsShown())
        end,
    },
    {
        key      = "collections",
        label    = "Montarias & Mascotes",
        desc     = "Gerencie suas montarias, mascotes de companhia, brinquedos e aparências.",
        binding  = "TOGGLECOLLECTIONS",
        icon     = MEDIA_DIR .. "Collections.tga",
        group    = "main",
        onClick  = ToggleCollectionsWindow,
        isOpen   = function()
            return (_G.CollectionsJournal and _G.CollectionsJournal:IsShown())
                or (_G.PetPaperDollFrame and _G.PetPaperDollFrame:IsShown())
        end,
    },
    {
        key      = "toggle",
        label    = "Recolher / Expandir Menu",
        desc     = "Alterna a exibição dos atalhos principais da barra de utilidades.",
        isToggle = true,
        icon     = MEDIA_DIR .. "ToggleClose.tga",
        onClick  = function()
            M.db.collapsed = not M.db.collapsed
            M:ApplyLayout()
        end,
    },
    {
        key      = "map",
        label    = "Mapa-Múndi",
        desc     = "Explore o mapa de Azeroth, rotas de missão, pontos de coleta e mestres de voo.",
        binding  = "TOGGLEWORLDMAP",
        icon     = MEDIA_DIR .. "Map.tga",
        hint     = "Clique direito: Mapa padrão da Blizzard",
        group    = "sys",
        onClick  = ToggleWorldMapWindow,
        isOpen   = function()
            local wm = Azaath:GetModule("WorldMap")
            return (wm and wm.IsOpen and wm:IsOpen())
                or (_G.WorldMapFrame and _G.WorldMapFrame:IsShown())
        end,
    },
    {
        key      = "help",
        label    = "Ajuda & Suporte",
        desc     = "Abra a central de suporte, envie tickets de atendimento ou reporte problemas.",
        icon     = MEDIA_DIR .. "Help.tga",
        group    = "sys",
        onClick  = ToggleHelpWindow,
        isOpen   = function()
            return _G.HelpFrame and _G.HelpFrame:IsShown()
        end,
    },
    {
        key      = "menu",
        label    = "Configurar Jogo",
        desc     = "Veja o menu do jogo onde pode alterar gráficos, áudio, teclas e configurações AzaathUI.",
        binding  = "TOGGLEGAMEMENU",
        icon     = MEDIA_DIR .. "Menu.tga",
        hint     = "Clique direito: Opções AzaathUI",
        group    = "sys",
        isSys    = true,
        onClick  = ToggleMainMenuWindow,
        isOpen   = function()
            return _G.GameMenuFrame and _G.GameMenuFrame:IsShown()
        end,
    },
}

function M:GetButtonCount()
    if self.db and self.db.collapsed then
        local n = 0
        for _, def in ipairs(BUTTON_DEFS) do
            if def.group ~= "main" then n = n + 1 end
        end
        return n
    end
    return #BUTTON_DEFS
end

--------------------------------------------------------------------------------
-- Placar de Informação estilo Black Desert (com paleta Azaath)
--------------------------------------------------------------------------------
local function EnsurePlacard()
    if placard then return placard end

    local media = Azaath.media
    local f = CreateFrame("Frame", "AzaathUIMicroPlacard", Azaath.root)
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(50)
    f:SetClampedToScreen(true)
    f:SetWidth(272)
    f:SetHeight(92)
    f:Hide()
    f:SetAlpha(0)

    Azaath.SetBackdrop(f, {
        bgFile   = media.blank,
        edgeFile = media.blank,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f:SetBackdropColor(AZAATH.bg[1], AZAATH.bg[2], AZAATH.bg[3], 0.94)
    f:SetBackdropBorderColor(AZAATH.border[1], AZAATH.border[2], AZAATH.border[3], 0.65)

    -- Barra superior brilhante em ciano Azaath
    local topGlow = f:CreateTexture(nil, "OVERLAY")
    topGlow:SetTexture(media.blank)
    Azaath.Gradient(topGlow, "HORIZONTAL",
        AZAATH.cyan[1], AZAATH.cyan[2], AZAATH.cyan[3], 0.95,
        AZAATH.cyan[1], AZAATH.cyan[2], AZAATH.cyan[3], 0.15)
    topGlow:SetHeight(2)
    topGlow:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    topGlow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)

    -- Faixa sutil no cabeçalho
    local headerBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerBg:SetTexture(media.blank)
    Azaath.Gradient(headerBg, "HORIZONTAL",
        AZAATH.cyan[1], AZAATH.cyan[2], AZAATH.cyan[3], 0.14,
        AZAATH.cyan[1], AZAATH.cyan[2], AZAATH.cyan[3], 0.02)
    headerBg:SetHeight(28)
    headerBg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -3)
    headerBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -3)

    -- Ícone miniatura no cabeçalho
    f.icon = f:CreateTexture(nil, "ARTWORK")
    f.icon:SetSize(15, 15)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -9)
    f.icon:SetVertexColor(AZAATH.cyanBright[1], AZAATH.cyanBright[2], AZAATH.cyanBright[3])

    -- Título
    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetFont(media.fontTitleB or media.font, 12.5, "")
    f.title:SetPoint("LEFT", f.icon, "RIGHT", 7, 0)
    f.title:SetPoint("RIGHT", f, "RIGHT", -56, 0)
    f.title:SetJustifyH("LEFT")
    f.title:SetTextColor(0.92, 0.98, 1.0)
    f.title:SetShadowColor(0, 0, 0, 0.9)
    f.title:SetShadowOffset(1, -1)

    -- Atalho de teclado à direita
    f.key = f:CreateFontString(nil, "OVERLAY")
    f.key:SetFont(media.font, 11, "")
    f.key:SetPoint("TOPRIGHT", f, "TOPRIGHT", -11, -10)
    f.key:SetJustifyH("RIGHT")
    f.key:SetTextColor(AZAATH.cyanBright[1], AZAATH.cyanBright[2], AZAATH.cyanBright[3])

    -- Linha divisória em ciano Azaath
    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetTexture(media.blank)
    Azaath.Gradient(div, "HORIZONTAL",
        AZAATH.cyan[1], AZAATH.cyan[2], AZAATH.cyan[3], 0.50,
        AZAATH.cyan[1], AZAATH.cyan[2], AZAATH.cyan[3], 0.05)
    div:SetHeight(1)
    div:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -31)
    div:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -31)

    -- Descrição (estilo BDO)
    f.desc = f:CreateFontString(nil, "OVERLAY")
    f.desc:SetFont(media.font, 11, "")
    f.desc:SetPoint("TOPLEFT", div, "BOTTOMLEFT", 0, -7)
    f.desc:SetWidth(250)
    f.desc:SetJustifyH("LEFT")
    f.desc:SetTextColor(AZAATH.desc[1], AZAATH.desc[2], AZAATH.desc[3])
    if f.desc.SetSpacing then f.desc:SetSpacing(2) end

    -- Linha extra (status ao vivo / FPS & MS / dica de clique direito)
    f.extra = f:CreateFontString(nil, "OVERLAY")
    f.extra:SetFont(media.font, 10.5, "")
    f.extra:SetPoint("TOPLEFT", f.desc, "BOTTOMLEFT", 0, -6)
    f.extra:SetWidth(250)
    f.extra:SetJustifyH("LEFT")
    f.extra:SetTextColor(AZAATH.hint[1], AZAATH.hint[2], AZAATH.hint[3])
    if f.extra.SetSpacing then f.extra:SetSpacing(2) end

    -- Fade-in suave
    f:SetScript("OnUpdate", function(self, elapsed)
        local target = self.targetAlpha or 0
        local cur = self:GetAlpha()
        if cur ~= target then
            local step = elapsed * 10
            if cur < target then
                self:SetAlpha(min(target, cur + step))
            else
                local na = max(target, cur - step)
                self:SetAlpha(na)
                if na <= 0 then self:Hide() end
            end
        end
    end)

    placard = f
    return f
end

local function ShowPlacard(btn)
    local f = EnsurePlacard()
    local def = btn.def

    local titleText = def.label
    if def.isToggle then
        titleText = (M.db and M.db.collapsed) and "Expandir Micro Menu" or "Recolher Micro Menu"
    end

    f.icon:SetTexture(def.isToggle and (M.db.collapsed and (MEDIA_DIR .. "ToggleOpen.tga") or (MEDIA_DIR .. "ToggleClose.tga")) or def.icon)
    f.title:SetText(titleText)

    local key
    if type(def.binding) == "table" then
        for _, bName in ipairs(def.binding) do
            key = GetBindingKey(bName)
            if key and key ~= "" then break end
        end
    elseif def.binding then
        key = GetBindingKey(def.binding)
    end
    local keyText = key and Azaath.ShortKey and Azaath.ShortKey(key) or key
    if keyText and keyText ~= "" then
        f.key:SetText("[" .. keyText .. "]")
        f.key:Show()
    else
        f.key:SetText("")
        f.key:Hide()
    end

    f.desc:SetText(def.desc or "")

    local extraLines = {}
    if def.statusFn then
        local st = def.statusFn()
        if st and st ~= "" then extraLines[#extraLines + 1] = st end
    end
    if def.isSys then
        local fps = floor((GetFramerate() or 0) + 0.5)
        local _, _, homeMS, worldMS = GetNetStats()
        local ms = worldMS or homeMS or 0
        extraLines[#extraLines + 1] = format("FPS: |cff5ce1e6%d|r    Latência: |cff5ce1e6%d|r ms", fps, ms)
    end
    if def.hint then
        extraLines[#extraLines + 1] = def.hint
    end

    local hasExtra = #extraLines > 0
    if hasExtra then
        f.extra:SetText(table.concat(extraLines, "\n"))
        f.extra:Show()
    else
        f.extra:SetText("")
        f.extra:Hide()
    end

    -- Altura dinâmica conforme conteúdo
    local descH = f.desc:GetStringHeight() or 26
    local extraH = hasExtra and ((f.extra:GetStringHeight() or 14) + 8) or 0
    f:SetHeight(38 + descH + extraH + 10)

    -- Posiciona acima do botão (ou abaixo se estiver perto do topo da tela)
    f:ClearAllPoints()
    local top = btn:GetTop() and btn:GetTop() * btn:GetEffectiveScale()
    local screenTop = UIParent:GetTop() * UIParent:GetEffectiveScale()
    if top and top > screenTop - 160 * UIParent:GetEffectiveScale() then
        f:SetPoint("TOP", btn, "BOTTOM", 0, -10)
    else
        f:SetPoint("BOTTOM", btn, "TOP", 0, 10)
    end

    f.targetAlpha = 1
    f:Show()
end

local function HidePlacard()
    if placard then
        placard.targetAlpha = 0
    end
end

--------------------------------------------------------------------------------
-- Visual dos Botões e Badges
--------------------------------------------------------------------------------
local function UpdateButtonVisual(b)
    local def = b.def
    local open = def.isOpen and def.isOpen()
    local hovered = b.isHovered

    if def.isToggle then
        local collapsed = M.db and M.db.collapsed
        b.icon:SetTexture(collapsed and (MEDIA_DIR .. "ToggleOpen.tga") or (MEDIA_DIR .. "ToggleClose.tga"))
        if hovered then
            b.disc:SetVertexColor(0.10, 0.18, 0.24, 0.90)
            b.diamondBorder:SetVertexColor(AZAATH.cyanBright[1], AZAATH.cyanBright[2], AZAATH.cyanBright[3], 0.95)
            b.glow:SetVertexColor(AZAATH.cyan[1], AZAATH.cyan[2], AZAATH.cyan[3], 0.50)
            b.glow:Show()
            b.icon:SetVertexColor(AZAATH.cyanBright[1], AZAATH.cyanBright[2], AZAATH.cyanBright[3], 1)
        else
            b.disc:SetVertexColor(0.06, 0.09, 0.13, 0.78)
            b.diamondBorder:SetVertexColor(AZAATH.cyan[1], AZAATH.cyan[2], AZAATH.cyan[3], 0.45)
            b.glow:Hide()
            b.icon:SetVertexColor(0.86, 0.92, 0.96, 0.90)
        end
        return
    end

    if open then
        b.disc:SetVertexColor(0.09, 0.17, 0.23, 0.88)
        b.glow:SetVertexColor(AZAATH.cyan[1], AZAATH.cyan[2], AZAATH.cyan[3], 0.55)
        b.glow:Show()
        b.icon:SetVertexColor(AZAATH.cyanBright[1], AZAATH.cyanBright[2], AZAATH.cyanBright[3], 1)
        b.activeDot:Show()
    elseif hovered then
        b.disc:SetVertexColor(0.10, 0.16, 0.22, 0.85)
        b.glow:SetVertexColor(AZAATH.cyan[1], AZAATH.cyan[2], AZAATH.cyan[3], 0.42)
        b.glow:Show()
        b.icon:SetVertexColor(1, 1, 1, 1)
        b.activeDot:Hide()
    else
        b.disc:SetVertexColor(AZAATH.discIdle[1], AZAATH.discIdle[2], AZAATH.discIdle[3], 0.52)
        b.glow:Hide()
        b.icon:SetVertexColor(0.90, 0.92, 0.95, 0.88)
        b.activeDot:Hide()
    end

    -- Atualiza badge numérica
    if b.badgeFrame and def.badge then
        local count = def.badge()
        if count and count > 0 then
            b.badgeText:SetText(count > 99 and "99+" or tostring(count))
            b.badgeFrame:Show()
        else
            b.badgeFrame:Hide()
        end
    end
end

local function UpdateAllVisuals()
    for _, b in ipairs(buttons) do
        if b:IsShown() then
            UpdateButtonVisual(b)
        end
    end
end

local function Button_OnEnter(self)
    self.isHovered = true
    UpdateButtonVisual(self)
    ShowPlacard(self)
end

local function Button_OnLeave(self)
    self.isHovered = false
    UpdateButtonVisual(self)
    HidePlacard()
end

--------------------------------------------------------------------------------
-- Construção
--------------------------------------------------------------------------------
local SPELLBOOK_SNIPPET = [[
    if button == "RightButton" then
        control:CallMethod("OpenDefaultSpellbook")
        return
    end
    local book = self:GetFrameRef("book")
    if book then
        if book:IsShown() then book:Hide() else book:Show() end
    else
        control:CallMethod("OpenDefaultSpellbook")
    end
]]

local function IsFrameMouseOver(f)
    if not f then return false end
    if f.IsMouseOver then return f:IsMouseOver() end
    if _G.MouseIsOver then return _G.MouseIsOver(f) end
    return false
end

local function IsMouseOverBar()
    if not bar then return false end
    if IsFrameMouseOver(bar) then return true end
    for _, b in ipairs(buttons) do
        if b:IsShown() and (b.isHovered or IsFrameMouseOver(b)) then return true end
    end
    return false
end

local elapsedAcc = 0
local function Bar_OnUpdate(self, elapsed)
    local idle = M.db.idleAlpha or 0.80
    local target = (M.editing or IsMouseOverBar()) and 1.0 or idle
    local cur = self:GetAlpha()
    if cur ~= target then
        local step = elapsed * 5
        if cur < target then
            self:SetAlpha(min(target, cur + step))
        else
            self:SetAlpha(max(target, cur - step))
        end
    end

    elapsedAcc = elapsedAcc + elapsed
    if elapsedAcc >= 0.35 then
        elapsedAcc = 0
        UpdateAllVisuals()
    end
end

-- Janelas da Blizzard abertas pelo addon (ShowUIPanel / Toggle*) contaminam o
-- gerenciador de painéis: a próxima janela aberta por ele herda o taint (ex.: compra
-- de espaço no banco bloqueada; Sair/Deslogar no menu do jogo). Por isso cada botão
-- aciona o micro botão equivalente da Blizzard por clique seguro ("/click").
-- leftModule/rightModule: com esse módulo Azaath ligado, o clique abre a janela própria.
local SAME = {}
local BLIZZ_CLICK = {
    character    = { left = { "CharacterMicroButton" }, leftModule = "sheet", right = SAME },
    talents      = { left = { "PlayerSpellsMicroButton", "TalentMicroButton" }, leftModule = "talents", right = SAME },
    achievements = { left = { "AchievementMicroButton" }, right = SAME },
    quests       = { left = { "QuestLogMicroButton" }, right = SAME, rightModule = "worldmap" },
    social       = { left = { "SocialsMicroButton", "FriendsMicroButton", "QuickJoinToastButton" }, right = SAME },
    guild        = { left = { "GuildMicroButton" }, right = SAME },
    lfd          = { left = { "LFDMicroButton", "LFGMicroButton" }, right = { "PVPMicroButton" } },
    collections  = { left = { "CollectionsMicroButton" }, right = SAME },
    help         = { left = { "HelpMicroButton" }, right = SAME },
    map          = { left = { "WorldMapMicroButton" }, leftModule = "worldmap", right = SAME },
    menu         = { left = { "MainMenuMicroButton" } },
}

local function ResolveBlizzButton(list, module)
    if module and Azaath.db[module] and Azaath.db[module].enabled then return nil end
    for _, name in ipairs(list or {}) do
        local btn = _G[name]
        if btn and btn.Click then return name end
    end
end

local function ApplyBlizzClick(b, spec)
    local right = spec.right == SAME and spec.left or spec.right
    local targets = {
        ResolveBlizzButton(spec.left, spec.leftModule),
        ResolveBlizzButton(right, spec.rightModule),
    }
    for slot = 1, 2 do
        local name = targets[slot]
        b:SetAttribute("type" .. slot, name and "macro" or nil)
        b:SetAttribute("macrotext" .. slot, name and ("/click " .. name) or nil)
    end
end

local function CreateMicroButton(i, def, size)
    local media = Azaath.media
    local name = "AzaathUIMicroButton_" .. def.key

    local grimoire = def.grimoire and Azaath:GetModule("Grimoire")
    local secure = def.secure and not (grimoire and grimoire.IsActive and grimoire:IsActive())
    local proxy = not secure and Azaath.IS_MODERN and BLIZZ_CLICK[def.key]
    -- Livro: esquerdo abre o grimório Azaath (trecho seguro), direito o livro da Blizzard por clique seguro
    local sbBlizz = secure and Azaath.IS_MODERN
        and ResolveBlizzButton({ "PlayerSpellsMicroButton", "SpellbookMicroButton" })
    local template = ((proxy or sbBlizz) and "SecureActionButtonTemplate")
        or (secure and "SecureHandlerClickTemplate") or nil
    local b = CreateFrame("Button", name, bar, template)
    b:SetSize(size, size)
    b:RegisterForClicks("AnyUp")
    b.def = def

    -- Brilho radial Azaath atrás do ícone (hover / ativo)
    b.glow = b:CreateTexture(nil, "BACKGROUND", nil, 0)
    b.glow:SetTexture(MEDIA_DIR .. "Glow.tga")
    b.glow:SetPoint("TOPLEFT", b, "TOPLEFT", -6, 6)
    b.glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 6, -6)
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()

    if def.isToggle then
        -- Botão losango estilo BDO
        b.disc = b:CreateTexture(nil, "BACKGROUND", nil, 1)
        b.disc:SetTexture(MEDIA_DIR .. "Diamond.tga")
        b.disc:SetAllPoints(b)

        b.diamondBorder = b:CreateTexture(nil, "BORDER")
        b.diamondBorder:SetTexture(MEDIA_DIR .. "DiamondBorder.tga")
        b.diamondBorder:SetAllPoints(b)
    else
        -- Disco translúcido circular estilo BDO
        b.disc = b:CreateTexture(nil, "BACKGROUND", nil, 1)
        b.disc:SetTexture(MEDIA_DIR .. "Disc.tga")
        b.disc:SetAllPoints(b)
    end

    -- Ícone minimalista vetorial
    b.icon = b:CreateTexture(nil, "ARTWORK")
    local pad = def.isToggle and 6 or 4
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", pad, -pad)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -pad, pad)
    b.icon:SetTexture(def.icon)

    -- Indicador ciano Azaath na base quando a janela está aberta
    b.activeDot = b:CreateTexture(nil, "OVERLAY")
    b.activeDot:SetTexture(media.blank)
    b.activeDot:SetVertexColor(AZAATH.cyanBright[1], AZAATH.cyanBright[2], AZAATH.cyanBright[3], 1)
    b.activeDot:SetSize(10, 2)
    b.activeDot:SetPoint("BOTTOM", b, "BOTTOM", 0, -2)
    b.activeDot:Hide()

    -- Badge circular numérica (estilo BDO)
    if def.badge then
        local bf = CreateFrame("Frame", nil, b)
        bf:SetSize(14, 14)
        bf:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
        bf:SetFrameLevel(b:GetFrameLevel() + 3)

        local bg = bf:CreateTexture(nil, "ARTWORK")
        bg:SetTexture(MEDIA_DIR .. "Badge.tga")
        bg:SetAllPoints(bf)
        bg:SetVertexColor(AZAATH.badgeBg[1], AZAATH.badgeBg[2], AZAATH.badgeBg[3], 0.96)

        local txt = bf:CreateFontString(nil, "OVERLAY")
        txt:SetFont(media.font, 9, "OUTLINE")
        txt:SetPoint("CENTER", bf, "CENTER", 0, 0)
        txt:SetTextColor(1, 0.98, 0.90)

        bf:Hide()
        b.badgeFrame = bf
        b.badgeText = txt
    end

    if sbBlizz then
        b:SetAttribute("useOnKeyDown", false)
        b:SetAttribute("type2", "macro")
        b:SetAttribute("macrotext2", "/click " .. sbBlizz)
        local sbFrame = _G.AzaathUISpellbook
        if sbFrame then
            local header = CreateFrame("Frame", nil, UIParent, "SecureHandlerBaseTemplate")
            SecureHandlerSetFrameRef(header, "book", sbFrame)
            SecureHandlerWrapScript(b, "OnClick", header, [[
                if button == "LeftButton" then
                    local book = owner:GetFrameRef("book")
                    if book:IsShown() then book:Hide() else book:Show() end
                    return false
                end
            ]])
        else
            b:SetAttribute("type1", "macro")
            b:SetAttribute("macrotext1", "/click " .. sbBlizz)
        end
    elseif secure then
        b.OpenDefaultSpellbook = function()
            if not InCombatLockdown() then
                Azaath.API.OpenDefaultSpellbook()
            end
        end
        local sbFrame = _G.AzaathUISpellbook
        if sbFrame then
            b:SetFrameRef("book", sbFrame)
        end
        b:SetAttribute("_onclick", SPELLBOOK_SNIPPET)
    elseif proxy then
        b:SetAttribute("useOnKeyDown", false)
        ApplyBlizzClick(b, proxy)
        b:SetScript("PreClick", function(self, mouseButton)
            if not InCombatLockdown() then ApplyBlizzClick(self, proxy) end
            local slot = (mouseButton == "RightButton") and 2 or 1
            self.azViaBlizz = self:GetAttribute("type" .. slot) ~= nil
        end)
        b:HookScript("OnClick", function(self, mouseButton)
            if not self.azViaBlizz and def.onClick then def.onClick(mouseButton) end
            UpdateAllVisuals()
            if self.isHovered then ShowPlacard(self) end
        end)
    else
        b:SetScript("OnClick", function(self, mouseButton)
            if def.onClick then def.onClick(mouseButton) end
            UpdateAllVisuals()
            if self.isHovered then ShowPlacard(self) end
        end)
    end

    b:SetScript("OnEnter", Button_OnEnter)
    b:SetScript("OnLeave", Button_OnLeave)

    UpdateButtonVisual(b)
    buttons[i] = b
    return b
end

local function PositionBarAndButtons()
    local db = M.db
    local size = db.buttonSize or 26
    local spacing = db.spacing or 5
    local collapsed = db.collapsed and true or false
    local scale = (db.scale and db.scale > 0) and db.scale or 1
    local anchor = db.anchor or "BOTTOMRIGHT"
    local ox = db.offsetX ~= nil and db.offsetX or -16
    local oy = db.offsetY ~= nil and db.offsetY or 14

    local last = M.lastApplied
    if last and last.scale ~= scale and last.x == ox and last.y == oy and ox and oy then
        db.offsetX = floor(ox * last.scale / scale + 0.5)
        db.offsetY = floor(oy * last.scale / scale + 0.5)
        ox, oy = db.offsetX, db.offsetY
    end
    M.lastApplied = { scale = scale, x = ox, y = oy }

    local visibleIndex = 0
    for _, b in ipairs(buttons) do
        local show = not (collapsed and b.def.group == "main")
        if show then
            visibleIndex = visibleIndex + 1
            b:Show()
            b:SetSize(size, size)
            local pad = b.def.isToggle and max(4, floor(size * 0.23)) or max(3, floor(size * 0.16))
            b.icon:ClearAllPoints()
            b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", pad, -pad)
            b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -pad, pad)
            b:ClearAllPoints()
            b:SetPoint("LEFT", bar, "LEFT", (visibleIndex - 1) * (size + spacing), 0)
        else
            b:Hide()
        end
    end

    local count = max(1, visibleIndex)
    bar:SetScale(scale)
    bar:SetWidth(count * size + (count - 1) * spacing)
    bar:SetHeight(size)
    bar:ClearAllPoints()
    bar:SetPoint(anchor, Azaath.root, anchor, ox, oy)
    if Azaath.ClampToScreen then Azaath.ClampToScreen(bar) end
    bar:SetAlpha(M.editing and 1.0 or (db.idleAlpha or 0.80))

    UpdateAllVisuals()
end

function M:ApplyLayout()
    if not bar then
        if self.db and self.db.enabled then
            Azaath:RunOutOfCombat(function() self:Build() end)
        end
        return
    end
    Azaath:RunOutOfCombat(function()
        if not self.db.enabled then
            bar:Hide()
            HidePlacard()
            return
        end
        bar:Show()
        PositionBarAndButtons()
    end)
end

function M:Build()
    local db = self.db
    local size = db.buttonSize or 26

    bar = CreateFrame("Frame", "AzaathUIMicroMenu", Azaath.root)
    bar:SetFrameStrata("MEDIUM")
    bar:SetFrameLevel(15)
    bar:SetClampedToScreen(true)

    for i, def in ipairs(BUTTON_DEFS) do
        CreateMicroButton(i, def, size)
    end

    PositionBarAndButtons()
    bar:SetScript("OnUpdate", Bar_OnUpdate)
end

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:SetEditing(editing)
    self.editing = editing and true or false
    if bar then
        bar:SetAlpha(self.editing and 1.0 or (self.db and self.db.idleAlpha or 0.80))
    end
end

function M:OnInitialize()
    self.db = Azaath.db.micromenu
end

function M:OnEnable()
    if not self.db or not self.db.enabled then return end
    Azaath:RunOutOfCombat(function()
        self:Build()
    end)
end
