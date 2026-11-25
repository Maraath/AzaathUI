--[[----------------------------------------------------------------------------
    AzaathUI - Modules/MicroMenu.lua
    Barra de utilidades (Micro Menu) com 4 estilos selecionáveis (/azaath):
      * "bdo"      — Minimalista BDO (discos translúcidos, losango central)
      * "azaath"   — Azaath Arcano (doca obsidiana/ouro velho, cristais ciano, anel rúnico)
      * "numenor"  — Forja de Númenor (ardósia negra, bronze oxidado, ícones a buril, brasa)
      * "tabletop" — Mesa de RPG / WoW Clássico (pedra cinzelada, slots retrato 3D,
                     ícones coloridos, barra de latência e placar em pergaminho)
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("MicroMenu")

local _G = _G
local ipairs, format, floor, pcall, max, min = ipairs, string.format, math.floor, pcall, math.max, math.min
local InCombatLockdown = InCombatLockdown

local MEDIA_DIR = Azaath.media.path .. "MicroMenu\\"

-- Configuração visual dos 4 estilos
local STYLES = {
    bdo = {
        prefix    = "",
        accentHex = "5ce1e6",
        plBg      = { 0.04, 0.065, 0.095, 0.94 },
        plBorder  = { 0.22, 0.72, 0.86, 0.65 },
        plTop     = { 0.30, 0.85, 0.95 },
        plTitle   = { 0.92, 0.98, 1.00 },
        plKey     = { 0.55, 0.93, 1.00 },
        plDesc    = { 0.66, 0.76, 0.83 },
        plHint    = { 0.45, 0.78, 0.86 },
        badgeCol  = { 0.78, 0.58, 0.16, 0.96 },
        badgeTxt  = { 1.00, 0.98, 0.90 },
        iconIdle  = { 0.90, 0.92, 0.95, 0.88 },
        iconHover = { 1.00, 1.00, 1.00, 1.00 },
        iconOpen  = { 0.55, 0.93, 1.00, 1.00 },
        glowCol   = { 0.30, 0.85, 0.95 },
        discTex   = "Disc.tga",
        toggleTex = "Diamond.tga",
        glowTex   = "Glow.tga",
        badgeTex  = "Badge.tga",
    },
    azaath = {
        prefix    = "",
        accentHex = "7beeff",
        dockBg    = { 0.03, 0.045, 0.075, 0.95 },
        dockRim   = { 0.79, 0.66, 0.42, 0.88 },
        dockTrim  = { 0.30, 0.85, 0.95, 0.60 },
        wingL     = "AzWingL.tga",
        wingR     = "AzWingR.tga",
        wingW     = 34,
        plBg      = { 0.035, 0.055, 0.09, 0.96 },
        plBorder  = { 0.79, 0.66, 0.42, 0.92 },
        plTop     = { 0.30, 0.85, 0.95 },
        plTitle   = { 0.95, 0.98, 1.00 },
        plKey     = { 0.66, 0.97, 1.00 },
        plDesc    = { 0.74, 0.82, 0.88 },
        plHint    = { 0.79, 0.66, 0.42 },
        plCorner  = "AzCorner.tga",
        plGem     = "AzGem.tga",
        badgeCol  = { 1, 1, 1, 1 },
        badgeTxt  = { 1.00, 0.98, 0.92 },
        iconIdle  = { 0.86, 0.91, 0.95, 0.94 },
        iconHover = { 0.95, 0.99, 1.00, 1.00 },
        iconOpen  = { 0.66, 0.97, 1.00, 1.00 },
        glowCol   = { 1, 1, 1 },
        discTex   = "AzSocket.tga",
        toggleTex = "AzToggle.tga",
        glowTex   = "AzActiveRing.tga",
        badgeTex  = "AzBadge.tga",
        activeGem = "AzGem.tga",
    },
    numenor = {
        prefix    = "Num_",
        accentHex = "f7c77e",
        dockBg    = { 0.04, 0.045, 0.055, 0.96 },
        dockRim   = { 0.62, 0.51, 0.32, 0.88 },
        dockTrim  = { 0.62, 0.51, 0.32, 0.45 },
        wingL     = "NumWingL.tga",
        wingR     = "NumWingR.tga",
        wingW     = 38,
        plBg      = { 0.045, 0.05, 0.06, 0.97 },
        plBorder  = { 0.62, 0.51, 0.32, 0.90 },
        plTop     = { 0.85, 0.75, 0.57 },
        plTitle   = { 0.95, 0.85, 0.66 },
        plKey     = { 0.97, 0.78, 0.49 },
        plDesc    = { 0.72, 0.75, 0.78 },
        plHint    = { 0.55, 0.56, 0.58 },
        plCorner  = "NumCorner.tga",
        plCrest   = "NumCrest.tga",
        plGem     = "NumGem.tga",
        badgeCol  = { 1, 1, 1, 1 },
        badgeTxt  = { 0.95, 0.85, 0.66 },
        iconIdle  = { 1.00, 1.00, 1.00, 0.94 },
        iconHover = { 1.00, 0.89, 0.68, 1.00 },
        iconOpen  = { 1.00, 0.84, 0.55, 1.00 },
        glowCol   = { 1, 1, 1 },
        discTex   = "NumSocket.tga",
        toggleTex = "NumToggle.tga",
        glowTex   = "NumActiveRing.tga",
        badgeTex  = "NumBadge.tga",
        activeGem = "NumGem.tga",
    },
    tabletop = {
        prefix    = "Wow_",
        accentHex = "801319",
        portrait  = true,
        dockBg    = { 0.05, 0.04, 0.03, 0.94 },
        dockRim   = { 0.55, 0.45, 0.30, 0.95 },
        railTex   = "WowRail.tga",
        wingL     = "WowCapL.tga",
        wingR     = "WowCapR.tga",
        wingW     = 26,
        plBg      = { 0.16, 0.11, 0.07, 0.98 },
        plBorder  = { 0.24, 0.17, 0.11, 1.00 },
        plParch   = "WowParchment.tga",
        plPlaque  = "WowPlaque.tga",
        plTab     = "WowTab.tga",
        plSeal    = "WowSeal.tga",
        plMedal   = "WowMedal.tga",
        plCorner  = "WowCorner.tga",
        plTitle   = { 1.00, 0.82, 0.00 },
        plKey     = { 1.00, 0.82, 0.00 },
        plDesc    = { 0.17, 0.10, 0.04 },
        plHint    = { 0.34, 0.21, 0.10 },
        badgeCol  = { 1, 1, 1, 1 },
        badgeTxt  = { 1.00, 0.96, 0.86 },
        iconIdle  = { 1.00, 1.00, 1.00, 0.96 },
        iconHover = { 1.00, 1.00, 1.00, 1.00 },
        iconOpen  = { 1.00, 1.00, 1.00, 1.00 },
        glowCol   = { 1.00, 0.82, 0.00 },
        discTex   = "WowSlot.tga",
        activeTex = "WowSlotActive.tga",
        toggleTex = "WowToggle.tga",
        glowTex   = "Glow.tga",
        badgeTex  = "WowBadge.tga",
    },
}

local function GetStyle()
    local s = M.db and M.db.style
    return STYLES[s] and s or "bdo"
end

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

local function ResolveIconTex(def, style, cfg)
    if def.isToggle then
        local collapsed = M.db and M.db.collapsed
        if style == "tabletop" then
            return MEDIA_DIR .. "WowArrows.tga", collapsed
        elseif style == "numenor" then
            return MEDIA_DIR .. (collapsed and "Num_ToggleOpen.tga" or "Num_ToggleClose.tga"), false
        end
        return MEDIA_DIR .. (collapsed and "ToggleOpen.tga" or "ToggleClose.tga"), false
    end
    local name = def.icon:match("([^\\]+)$") or def.icon
    return MEDIA_DIR .. (cfg.prefix or "") .. name, false
end

local function SetCornerFlip(tex, idx)
    if idx == 1 then tex:SetTexCoord(0, 1, 0, 1)
    elseif idx == 2 then tex:SetTexCoord(1, 0, 0, 1)
    elseif idx == 3 then tex:SetTexCoord(0, 1, 1, 0)
    else tex:SetTexCoord(1, 0, 1, 0) end
end

local function ApplyPlacardTheme(f, style, cfg)
    if f.appliedStyle == style then return end
    f.appliedStyle = style
    local isTable = style == "tabletop"
    local isBDO = style == "bdo"

    if isTable then
        f:SetBackdropColor(0, 0, 0, 0)
    else
        f:SetBackdropColor(cfg.plBg[1], cfg.plBg[2], cfg.plBg[3], cfg.plBg[4])
    end
    f:SetBackdropBorderColor(cfg.plBorder[1], cfg.plBorder[2], cfg.plBorder[3], cfg.plBorder[4])

    f.parchmentBg:SetShown(isTable)
    f.plaqueTex:SetShown(isTable)
    f.tabFrame:SetShown(isTable)
    f.sealTex:SetShown(isTable)
    f.medalTex:SetShown(isTable)

    f.topGlow:SetShown(not isTable)
    f.headerBg:SetShown(not isTable)
    if not isTable and cfg.plTop then
        Azaath.Gradient(f.topGlow, "HORIZONTAL",
            cfg.plTop[1], cfg.plTop[2], cfg.plTop[3], 0.95,
            cfg.plTop[1], cfg.plTop[2], cfg.plTop[3], 0.15)
        Azaath.Gradient(f.headerBg, "HORIZONTAL",
            cfg.plTop[1], cfg.plTop[2], cfg.plTop[3], 0.14,
            cfg.plTop[1], cfg.plTop[2], cfg.plTop[3], 0.02)
    end

    if cfg.plCorner then
        local csz = isTable and 22 or 16
        local coff = isTable and 3 or 1
        for idx, c in ipairs(f.corners) do
            c:SetTexture(MEDIA_DIR .. cfg.plCorner)
            c:SetSize(csz, csz)
            SetCornerFlip(c, idx)
            c:ClearAllPoints()
            if idx == 1 then c:SetPoint("TOPLEFT", f, "TOPLEFT", -coff, coff)
            elseif idx == 2 then c:SetPoint("TOPRIGHT", f, "TOPRIGHT", coff, coff)
            elseif idx == 3 then c:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", -coff, -coff)
            else c:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", coff, -coff) end
            c:Show()
        end
    else
        for _, c in ipairs(f.corners) do c:Hide() end
    end

    if cfg.plCrest then
        f.crestTex:SetTexture(MEDIA_DIR .. cfg.plCrest)
        f.crestTex:Show()
    else
        f.crestTex:Hide()
    end

    if cfg.plGem then
        f.divGem:SetTexture(MEDIA_DIR .. cfg.plGem)
        f.divGem:Show()
    else
        f.divGem:Hide()
    end

    if isTable then
        Azaath.Gradient(f.div, "HORIZONTAL", 0.35, 0.20, 0.08, 0.55, 0.35, 0.20, 0.08, 0.15)
        f.title:ClearAllPoints()
        f.title:SetPoint("CENTER", f.plaqueTex, "CENTER", 0, 1)
        f.title:SetJustifyH("CENTER")
        f.title:SetShadowColor(0, 0, 0, 0.95)
        f.icon:ClearAllPoints()
        f.icon:SetSize(20, 20)
        f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 18, -42)
        f.div:ClearAllPoints()
        f.div:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -72)
        f.div:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, -72)
        f.desc:ClearAllPoints()
        f.desc:SetPoint("TOPLEFT", f, "TOPLEFT", 48, -40)
        f.desc:SetWidth(212)
        f.desc:SetShadowColor(0, 0, 0, 0)
        f.extra:SetShadowColor(0, 0, 0, 0)
    else
        local dc = cfg.plTop or { 0.30, 0.85, 0.95 }
        Azaath.Gradient(f.div, "HORIZONTAL", dc[1], dc[2], dc[3], 0.55, dc[1], dc[2], dc[3], 0.05)
        f.icon:ClearAllPoints()
        f.icon:SetSize(15, 15)
        f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -9)
        f.title:ClearAllPoints()
        f.title:SetPoint("LEFT", f.icon, "RIGHT", 7, 0)
        f.title:SetPoint("RIGHT", f, "RIGHT", -58, 0)
        f.title:SetJustifyH("LEFT")
        f.title:SetShadowColor(0, 0, 0, 0.9)
        f.div:ClearAllPoints()
        f.div:SetPoint("TOPLEFT", f, "TOPLEFT", 10, -31)
        f.div:SetPoint("TOPRIGHT", f, "TOPRIGHT", -10, -31)
        f.desc:ClearAllPoints()
        f.desc:SetPoint("TOPLEFT", f.div, "BOTTOMLEFT", 0, -7)
        f.desc:SetWidth(250)
        f.desc:SetShadowColor(0, 0, 0, 0.8)
        f.extra:SetShadowColor(0, 0, 0, 0.8)
    end

    f.keyBox:SetShown(not isBDO and not isTable)
    if not isBDO and not isTable then
        f.keyBox:SetBackdropBorderColor(cfg.plBorder[1], cfg.plBorder[2], cfg.plBorder[3], 0.85)
    end

    f.title:SetTextColor(cfg.plTitle[1], cfg.plTitle[2], cfg.plTitle[3])
    f.key:SetTextColor(cfg.plKey[1], cfg.plKey[2], cfg.plKey[3])
    f.desc:SetTextColor(cfg.plDesc[1], cfg.plDesc[2], cfg.plDesc[3])
    f.extra:SetTextColor(cfg.plHint[1], cfg.plHint[2], cfg.plHint[3])
end

local function EnsurePlacard()
    if placard then return placard end

    local media = Azaath.media
    local f = CreateFrame("Frame", "AzaathUIMicroPlacard", Azaath.root)
    f:SetFrameStrata("TOOLTIP")
    f:SetFrameLevel(50)
    f:SetClampedToScreen(true)
    f:SetWidth(276)
    f:SetHeight(104)
    f:Hide()
    f:SetAlpha(0)

    Azaath.SetBackdrop(f, {
        bgFile   = media.blank,
        edgeFile = media.blank,
        edgeSize = 1,
        insets   = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    f.parchmentBg = f:CreateTexture(nil, "BACKGROUND", nil, 0)
    f.parchmentBg:SetTexture(MEDIA_DIR .. "WowParchment.tga")
    f.parchmentBg:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
    f.parchmentBg:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
    f.parchmentBg:Hide()

    local topGlow = f:CreateTexture(nil, "OVERLAY")
    topGlow:SetTexture(media.blank)
    topGlow:SetHeight(2)
    topGlow:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -1)
    topGlow:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -1)
    f.topGlow = topGlow

    local headerBg = f:CreateTexture(nil, "BACKGROUND", nil, 1)
    headerBg:SetTexture(media.blank)
    headerBg:SetHeight(28)
    headerBg:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -3)
    headerBg:SetPoint("TOPRIGHT", f, "TOPRIGHT", -1, -3)
    f.headerBg = headerBg

    f.crestTex = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.crestTex:SetSize(72, 16)
    f.crestTex:SetPoint("CENTER", f, "TOP", 0, -1)
    f.crestTex:Hide()

    f.plaqueTex = f:CreateTexture(nil, "ARTWORK", nil, 2)
    f.plaqueTex:SetTexture(MEDIA_DIR .. "WowPlaque.tga")
    f.plaqueTex:SetSize(224, 30)
    f.plaqueTex:SetPoint("CENTER", f, "TOP", 0, -4)
    f.plaqueTex:Hide()

    f.corners = {}
    for i = 1, 4 do
        f.corners[i] = f:CreateTexture(nil, "OVERLAY", nil, 3)
        f.corners[i]:Hide()
    end

    local tf = CreateFrame("Frame", nil, f)
    tf:SetSize(48, 24)
    tf:SetPoint("LEFT", f, "RIGHT", -8, 0)
    tf:SetPoint("TOP", f, "TOP", 0, -16)
    tf:SetFrameLevel(f:GetFrameLevel() + 1)
    local tabTex = tf:CreateTexture(nil, "ARTWORK")
    tabTex:SetTexture(MEDIA_DIR .. "WowTab.tga")
    tabTex:SetAllPoints(tf)
    tf:Hide()
    f.tabFrame = tf

    f.medalTex = f:CreateTexture(nil, "ARTWORK", nil, 1)
    f.medalTex:SetTexture(MEDIA_DIR .. "WowMedal.tga")
    f.medalTex:SetSize(32, 32)
    f.medalTex:Hide()

    f.sealTex = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.sealTex:SetTexture(MEDIA_DIR .. "WowSeal.tga")
    f.sealTex:SetSize(30, 30)
    f.sealTex:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -6, 6)
    f.sealTex:Hide()

    f.icon = f:CreateTexture(nil, "ARTWORK", nil, 3)
    f.icon:SetSize(15, 15)
    f.icon:SetPoint("TOPLEFT", f, "TOPLEFT", 11, -9)
    f.medalTex:SetPoint("CENTER", f.icon, "CENTER", 0, 0)

    f.title = f:CreateFontString(nil, "OVERLAY")
    f.title:SetFont(media.fontTitleB or media.font, 12, "")
    f.title:SetShadowOffset(1, -1)

    f.keyBox = CreateFrame("Frame", nil, f)
    f.keyBox:SetSize(42, 18)
    f.keyBox:SetPoint("TOPRIGHT", f, "TOPRIGHT", -9, -7)
    Azaath.SetBackdrop(f.keyBox, {
        bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    f.keyBox:SetBackdropColor(0.04, 0.06, 0.08, 0.90)
    f.keyBox:Hide()

    f.key = f:CreateFontString(nil, "OVERLAY")
    f.key:SetFont(media.font, 10.5, "")
    f.key:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -10)
    f.key:SetJustifyH("RIGHT")

    local div = f:CreateTexture(nil, "ARTWORK")
    div:SetTexture(media.blank)
    div:SetHeight(1)
    f.div = div

    f.divGem = f:CreateTexture(nil, "OVERLAY", nil, 2)
    f.divGem:SetSize(9, 9)
    f.divGem:SetPoint("CENTER", div, "CENTER", 0, 0)
    f.divGem:Hide()

    f.desc = f:CreateFontString(nil, "OVERLAY")
    f.desc:SetFont(media.font, 11, "")
    f.desc:SetJustifyH("LEFT")
    if f.desc.SetSpacing then f.desc:SetSpacing(2) end

    f.extra = f:CreateFontString(nil, "OVERLAY")
    f.extra:SetFont(media.font, 10.5, "")
    f.extra:SetPoint("TOPLEFT", f.desc, "BOTTOMLEFT", 0, -6)
    f.extra:SetWidth(244)
    f.extra:SetJustifyH("LEFT")
    if f.extra.SetSpacing then f.extra:SetSpacing(2) end

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
    local style = GetStyle()
    local cfg = STYLES[style]
    ApplyPlacardTheme(f, style, cfg)

    local titleText = def.label
    if def.isToggle then
        titleText = (M.db and M.db.collapsed) and "Expandir Micro Menu" or "Recolher Micro Menu"
    end

    local texPath, rot = ResolveIconTex(def, style, cfg)
    f.icon:SetTexture(texPath)
    if f.icon.SetRotation then f.icon:SetRotation(rot and math.pi or 0) end
    if style == "tabletop" or style == "numenor" then
        f.icon:SetVertexColor(1, 1, 1, 1)
    else
        f.icon:SetVertexColor(cfg.plKey[1], cfg.plKey[2], cfg.plKey[3], 1)
    end
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
        f.key:ClearAllPoints()
        if style == "tabletop" then
            f.key:SetPoint("CENTER", f.tabFrame, "CENTER", -1, 0)
            f.tabFrame:Show()
        elseif style ~= "bdo" then
            f.keyBox:SetWidth(max(30, (f.key:GetStringWidth() or 20) + 12))
            f.key:SetPoint("CENTER", f.keyBox, "CENTER", 0, 0)
            f.keyBox:Show()
        else
            f.key:SetPoint("TOPRIGHT", f, "TOPRIGHT", -12, -10)
        end
        f.key:Show()
    else
        f.key:SetText("")
        f.key:Hide()
        f.keyBox:Hide()
        f.tabFrame:Hide()
    end

    f.desc:SetText(def.desc or "")

    local accent = cfg.accentHex or "5ce1e6"
    local extraLines = {}
    if def.statusFn then
        local st = def.statusFn()
        if st and st ~= "" then
            extraLines[#extraLines + 1] = st:gsub("5ce1e6", accent)
        end
    end
    if def.isSys then
        local fps = floor((GetFramerate() or 0) + 0.5)
        local _, _, homeMS, worldMS = GetNetStats()
        local ms = worldMS or homeMS or 0
        extraLines[#extraLines + 1] = format("FPS: |cff%s%d|r    Latência: |cff%s%d|r ms", accent, fps, accent, ms)
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

    f.extra:ClearAllPoints()
    if style == "tabletop" then
        local descH = max(30, f.desc:GetStringHeight() or 30)
        local divY = -(42 + descH + 8)
        f.div:ClearAllPoints()
        f.div:SetPoint("TOPLEFT", f, "TOPLEFT", 14, divY)
        f.div:SetPoint("TOPRIGHT", f, "TOPRIGHT", -14, divY)
        f.extra:SetPoint("TOPLEFT", f.div, "BOTTOMLEFT", 4, -8)
        f.extra:SetWidth(214)
        local extraH = hasExtra and ((f.extra:GetStringHeight() or 14) + 12) or 8
        f:SetHeight(46 + descH + extraH + 14)
    else
        f.extra:SetPoint("TOPLEFT", f.desc, "BOTTOMLEFT", 0, -6)
        f.extra:SetWidth(250)
        local descH = f.desc:GetStringHeight() or 26
        local extraH = hasExtra and ((f.extra:GetStringHeight() or 14) + 8) or 0
        f:SetHeight(38 + descH + extraH + 10)
    end

    f:ClearAllPoints()
    local top = btn:GetTop() and btn:GetTop() * btn:GetEffectiveScale()
    local screenTop = UIParent:GetTop() * UIParent:GetEffectiveScale()
    if top and top > screenTop - 160 * UIParent:GetEffectiveScale() then
        f:SetPoint("TOP", btn, "BOTTOM", 0, style == "tabletop" and -22 or -12)
    else
        f:SetPoint("BOTTOM", btn, "TOP", 0, style == "tabletop" and 18 or 12)
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
-- Visual dos Botões, Badges e Barra de Latência
--------------------------------------------------------------------------------
local function UpdateLatencyBar()
    if not (bar and bar.latencyFrame) then return end
    if GetStyle() ~= "tabletop" then
        bar.latencyFrame:Hide()
        return
    end
    bar.latencyFrame:Show()
    local _, _, homeMS, worldMS = GetNetStats()
    local ms = max(homeMS or 0, worldMS or 0)
    local h = max(12, bar.latencyFrame:GetHeight() - 4)
    local pct = max(0.18, min(1.0, 1.0 - (ms / 350)))
    bar.latencyFill:SetHeight(floor(h * pct + 0.5))
    if ms < 80 then
        bar.latencyFill:SetVertexColor(0.20, 0.88, 0.25, 1)
    elseif ms < 180 then
        bar.latencyFill:SetVertexColor(0.95, 0.75, 0.12, 1)
    else
        bar.latencyFill:SetVertexColor(0.90, 0.18, 0.16, 1)
    end
end

local function UpdateButtonVisual(b)
    local def = b.def
    local style = GetStyle()
    local cfg = STYLES[style]
    local open = def.isOpen and def.isOpen()
    local hovered = b.isHovered

    local icoPath, rot = ResolveIconTex(def, style, cfg)
    b.icon:SetTexture(icoPath)
    if b.icon.SetRotation then b.icon:SetRotation(rot and math.pi or 0) end

    if def.isToggle then
        b.disc:SetTexture(MEDIA_DIR .. cfg.toggleTex)
        if style == "bdo" then
            b.diamondBorder:Show()
            if hovered then
                b.disc:SetVertexColor(0.10, 0.18, 0.24, 0.90)
                b.diamondBorder:SetVertexColor(0.55, 0.93, 1.00, 0.95)
                b.glow:SetTexture(MEDIA_DIR .. cfg.glowTex)
                b.glow:SetVertexColor(0.30, 0.85, 0.95, 0.50)
                b.glow:Show()
                b.icon:SetVertexColor(0.55, 0.93, 1.00, 1)
            else
                b.disc:SetVertexColor(0.06, 0.09, 0.13, 0.78)
                b.diamondBorder:SetVertexColor(0.30, 0.85, 0.95, 0.45)
                b.glow:Hide()
                b.icon:SetVertexColor(0.86, 0.92, 0.96, 0.90)
            end
        else
            b.diamondBorder:Hide()
            b.disc:SetVertexColor(1, 1, 1, hovered and 1 or 0.92)
            b.icon:SetVertexColor(1, 1, 1, hovered and 1 or 0.92)
            if hovered then
                b.glow:SetTexture(MEDIA_DIR .. cfg.glowTex)
                b.glow:SetVertexColor(cfg.glowCol[1], cfg.glowCol[2], cfg.glowCol[3], 0.55)
                b.glow:Show()
            else
                b.glow:Hide()
            end
        end
        if b.sysW then b.sysW:Hide() end
        if b.activeGem then b.activeGem:Hide() end
        b.activeDot:Hide()
        return
    end

    b.diamondBorder:Hide()
    if style == "tabletop" then
        b.disc:SetTexture(MEDIA_DIR .. ((open or hovered) and cfg.activeTex or cfg.discTex))
        b.disc:SetVertexColor(1, 1, 1, 1)
        b.glow:SetTexture(MEDIA_DIR .. cfg.glowTex)
        if open or hovered then
            b.glow:SetVertexColor(cfg.glowCol[1], cfg.glowCol[2], cfg.glowCol[3], open and 0.42 or 0.25)
            b.glow:Show()
        else
            b.glow:Hide()
        end
        b.icon:SetVertexColor(1, 1, 1, 1)
        b.activeDot:Hide()
        if b.activeGem then b.activeGem:Hide() end
        if b.sysW then b.sysW:SetShown(def.key == "menu") end
    else
        if b.sysW then b.sysW:Hide() end
        b.disc:SetTexture(MEDIA_DIR .. cfg.discTex)
        b.glow:SetTexture(MEDIA_DIR .. cfg.glowTex)
        if style == "bdo" then
            if open then
                b.disc:SetVertexColor(0.09, 0.17, 0.23, 0.88)
                b.glow:SetVertexColor(cfg.glowCol[1], cfg.glowCol[2], cfg.glowCol[3], 0.55)
                b.glow:Show()
                b.icon:SetVertexColor(cfg.iconOpen[1], cfg.iconOpen[2], cfg.iconOpen[3], cfg.iconOpen[4])
                b.activeDot:Show()
            elseif hovered then
                b.disc:SetVertexColor(0.10, 0.16, 0.22, 0.85)
                b.glow:SetVertexColor(cfg.glowCol[1], cfg.glowCol[2], cfg.glowCol[3], 0.42)
                b.glow:Show()
                b.icon:SetVertexColor(cfg.iconHover[1], cfg.iconHover[2], cfg.iconHover[3], cfg.iconHover[4])
                b.activeDot:Hide()
            else
                b.disc:SetVertexColor(0.05, 0.08, 0.12, 0.52)
                b.glow:Hide()
                b.icon:SetVertexColor(cfg.iconIdle[1], cfg.iconIdle[2], cfg.iconIdle[3], cfg.iconIdle[4])
                b.activeDot:Hide()
            end
            if b.activeGem then b.activeGem:Hide() end
        else
            b.disc:SetVertexColor(1, 1, 1, (open or hovered) and 1 or 0.94)
            b.activeDot:Hide()
            if open then
                b.glow:SetVertexColor(cfg.glowCol[1], cfg.glowCol[2], cfg.glowCol[3], 0.90)
                b.glow:Show()
                b.icon:SetVertexColor(cfg.iconOpen[1], cfg.iconOpen[2], cfg.iconOpen[3], cfg.iconOpen[4])
                if b.activeGem and cfg.activeGem then
                    b.activeGem:SetTexture(MEDIA_DIR .. cfg.activeGem)
                    b.activeGem:Show()
                end
            elseif hovered then
                b.glow:SetVertexColor(cfg.glowCol[1], cfg.glowCol[2], cfg.glowCol[3], 0.65)
                b.glow:Show()
                b.icon:SetVertexColor(cfg.iconHover[1], cfg.iconHover[2], cfg.iconHover[3], cfg.iconHover[4])
                if b.activeGem then b.activeGem:Hide() end
            else
                b.glow:Hide()
                b.icon:SetVertexColor(cfg.iconIdle[1], cfg.iconIdle[2], cfg.iconIdle[3], cfg.iconIdle[4])
                if b.activeGem then b.activeGem:Hide() end
            end
        end
    end

    if b.badgeFrame and def.badge then
        b.badgeBg:SetTexture(MEDIA_DIR .. cfg.badgeTex)
        b.badgeBg:SetVertexColor(cfg.badgeCol[1], cfg.badgeCol[2], cfg.badgeCol[3], cfg.badgeCol[4])
        b.badgeText:SetTextColor(cfg.badgeTxt[1], cfg.badgeTxt[2], cfg.badgeTxt[3])
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
    UpdateLatencyBar()
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
    if buttons[i] then return buttons[i] end
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

    -- Brilho / anel ativo atrás do ícone
    b.glow = b:CreateTexture(nil, "BACKGROUND", nil, 0)
    b.glow:SetTexture(MEDIA_DIR .. "Glow.tga")
    b.glow:SetPoint("TOPLEFT", b, "TOPLEFT", -6, 6)
    b.glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 6, -6)
    b.glow:SetBlendMode("ADD")
    b.glow:Hide()

    b.disc = b:CreateTexture(nil, "BACKGROUND", nil, 1)
    b.disc:SetAllPoints(b)

    b.diamondBorder = b:CreateTexture(nil, "BORDER")
    b.diamondBorder:SetTexture(MEDIA_DIR .. "DiamondBorder.tga")
    b.diamondBorder:SetAllPoints(b)
    b.diamondBorder:Hide()

    -- Ícone
    b.icon = b:CreateTexture(nil, "ARTWORK")
    local pad = def.isToggle and 6 or 4
    b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", pad, -pad)
    b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -pad, pad)

    -- Indicador na base quando a janela está aberta (traço bdo / gema azaath+numenor)
    b.activeDot = b:CreateTexture(nil, "OVERLAY")
    b.activeDot:SetTexture(media.blank)
    b.activeDot:SetVertexColor(0.55, 0.93, 1.00, 1)
    b.activeDot:SetSize(10, 2)
    b.activeDot:SetPoint("BOTTOM", b, "BOTTOM", 0, -2)
    b.activeDot:Hide()

    b.activeGem = b:CreateTexture(nil, "OVERLAY", nil, 2)
    b.activeGem:SetSize(9, 9)
    b.activeGem:SetPoint("CENTER", b, "BOTTOM", 0, 0)
    b.activeGem:Hide()

    -- Brasão [W] no topo do botão Menu no estilo Mesa de RPG (tabletop)
    if def.key == "menu" then
        local wBadge = CreateFrame("Frame", nil, b)
        wBadge:SetSize(13, 13)
        wBadge:SetPoint("TOP", b, "TOP", 0, -3)
        wBadge:SetFrameLevel(b:GetFrameLevel() + 2)
        local wBg = wBadge:CreateTexture(nil, "ARTWORK")
        wBg:SetTexture(MEDIA_DIR .. "Disc.tga")
        wBg:SetAllPoints(wBadge)
        wBg:SetVertexColor(0.08, 0.06, 0.04, 0.94)
        local wTxt = wBadge:CreateFontString(nil, "OVERLAY")
        wTxt:SetFont(media.fontTitleB or media.font, 8.5, "OUTLINE")
        wTxt:SetPoint("CENTER", wBadge, "CENTER", 0, 0)
        wTxt:SetText("W")
        wTxt:SetTextColor(1, 0.82, 0)
        wBadge:Hide()
        b.sysW = wBadge
    end

    -- Badge circular numérica
    if def.badge then
        local bf = CreateFrame("Frame", nil, b)
        bf:SetSize(14, 14)
        bf:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", 2, -2)
        bf:SetFrameLevel(b:GetFrameLevel() + 3)

        local bg = bf:CreateTexture(nil, "ARTWORK")
        bg:SetTexture(MEDIA_DIR .. "Badge.tga")
        bg:SetAllPoints(bf)

        local txt = bf:CreateFontString(nil, "OVERLAY")
        txt:SetFont(media.font, 9, "OUTLINE")
        txt:SetPoint("CENTER", bf, "CENTER", 0, 0)
        txt:SetTextColor(1, 0.98, 0.90)

        bf:Hide()
        b.badgeFrame = bf
        b.badgeBg = bg
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

local function ApplyDockChrome(style, cfg, totalW, barH)
    if not bar.chromeFrame then
        local cf = CreateFrame("Frame", nil, bar)
        cf:SetFrameLevel(max(1, bar:GetFrameLevel() - 1))
        Azaath.SetBackdrop(cf, {
            bgFile   = Azaath.media.blank,
            edgeFile = Azaath.media.blank,
            edgeSize = 1,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        cf.rail = cf:CreateTexture(nil, "BACKGROUND", nil, 1)
        cf.rail:SetAllPoints(cf)
        cf.topTrim = cf:CreateTexture(nil, "OVERLAY")
        cf.topTrim:SetTexture(Azaath.media.blank)
        cf.topTrim:SetHeight(1)
        cf.botTrim = cf:CreateTexture(nil, "OVERLAY")
        cf.botTrim:SetTexture(Azaath.media.blank)
        cf.botTrim:SetHeight(1)
        cf.wingL = cf:CreateTexture(nil, "ARTWORK")
        cf.wingR = cf:CreateTexture(nil, "ARTWORK")

        local lf = CreateFrame("Frame", nil, bar)
        Azaath.SetBackdrop(lf, {
            bgFile   = Azaath.media.blank,
            edgeFile = Azaath.media.blank,
            edgeSize = 1,
            insets   = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        lf:SetBackdropColor(0.08, 0.09, 0.11, 0.95)
        lf:SetBackdropBorderColor(0.55, 0.45, 0.30, 0.95)
        local fill = lf:CreateTexture(nil, "ARTWORK")
        fill:SetTexture(Azaath.media.blank)
        fill:SetPoint("BOTTOMLEFT", lf, "BOTTOMLEFT", 2, 2)
        fill:SetPoint("BOTTOMRIGHT", lf, "BOTTOMRIGHT", -2, 2)
        bar.latencyFrame = lf
        bar.latencyFill = fill
        bar.chromeFrame = cf
    end

    local cf = bar.chromeFrame
    if style == "bdo" then
        cf:Hide()
        bar.latencyFrame:Hide()
        return
    end

    local padX = (style == "tabletop") and 6 or 8
    local padY = (style == "tabletop") and 4 or 4
    cf:ClearAllPoints()
    cf:SetPoint("TOPLEFT", bar, "TOPLEFT", -padX, padY)
    cf:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", padX, -padY)
    cf:SetBackdropColor(cfg.dockBg[1], cfg.dockBg[2], cfg.dockBg[3], cfg.dockBg[4])
    cf:SetBackdropBorderColor(cfg.dockRim[1], cfg.dockRim[2], cfg.dockRim[3], cfg.dockRim[4])
    cf:Show()

    if cfg.railTex then
        cf.rail:SetTexture(MEDIA_DIR .. cfg.railTex)
        cf.rail:Show()
    else
        cf.rail:Hide()
    end

    if cfg.dockTrim then
        cf.topTrim:SetPoint("TOPLEFT", cf, "TOPLEFT", 2, -2)
        cf.topTrim:SetPoint("TOPRIGHT", cf, "TOPRIGHT", -2, -2)
        cf.topTrim:SetVertexColor(cfg.dockTrim[1], cfg.dockTrim[2], cfg.dockTrim[3], cfg.dockTrim[4])
        cf.botTrim:SetPoint("BOTTOMLEFT", cf, "BOTTOMLEFT", 2, 2)
        cf.botTrim:SetPoint("BOTTOMRIGHT", cf, "BOTTOMRIGHT", -2, 2)
        cf.botTrim:SetVertexColor(cfg.dockTrim[1], cfg.dockTrim[2], cfg.dockTrim[3], cfg.dockTrim[4] * 0.7)
        cf.topTrim:Show()
        cf.botTrim:Show()
    else
        cf.topTrim:Hide()
        cf.botTrim:Hide()
    end

    local wingH = (style == "tabletop") and (barH + 10) or (barH + 8)
    local wingW = cfg.wingW or 32
    cf.wingL:SetTexture(MEDIA_DIR .. cfg.wingL)
    cf.wingL:SetSize(wingW, wingH)
    cf.wingL:ClearAllPoints()
    cf.wingL:SetPoint("RIGHT", cf, "LEFT", style == "tabletop" and 8 or 2, 0)
    cf.wingL:Show()

    cf.wingR:SetTexture(MEDIA_DIR .. cfg.wingR)
    cf.wingR:SetSize(wingW, wingH)
    cf.wingR:ClearAllPoints()
    cf.wingR:SetPoint("LEFT", cf, "RIGHT", style == "tabletop" and -8 or -2, 0)
    cf.wingR:Show()

    if style == "tabletop" then
        bar.latencyFrame:SetSize(7, max(18, barH - 4))
        bar.latencyFrame:ClearAllPoints()
        bar.latencyFrame:SetPoint("RIGHT", bar, "RIGHT", 0, 0)
        bar.latencyFrame:Show()
    else
        bar.latencyFrame:Hide()
    end
end

local function PositionBarAndButtons()
    local db = M.db
    local style = GetStyle()
    local cfg = STYLES[style]
    local size = db.buttonSize or 26
    local spacing = (style == "tabletop") and max(2, min(4, db.spacing or 3)) or (db.spacing or 5)
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

    local btnH = cfg.portrait and floor(size * 1.36 + 0.5) or size
    local curX = 0
    for _, b in ipairs(buttons) do
        local show = not (collapsed and b.def.group == "main")
        if show then
            local bw = (cfg.portrait and b.def.isToggle) and max(12, floor(size * 0.62 + 0.5)) or size
            b:Show()
            b:SetSize(bw, btnH)

            local padX = b.def.isToggle and max(3, floor(bw * 0.22)) or max(3, floor(size * 0.16))
            local padY = cfg.portrait and max(4, floor((btnH - (bw - padX * 2)) * 0.52)) or padX
            b.icon:ClearAllPoints()
            b.icon:SetPoint("TOPLEFT", b, "TOPLEFT", padX, -padY)
            b.icon:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -padX, padY)

            if b.glow then
                b.glow:ClearAllPoints()
                local gPad = (style == "azaath" or style == "numenor") and -floor(size * 0.36) or -6
                b.glow:SetPoint("TOPLEFT", b, "TOPLEFT", gPad, -gPad)
                b.glow:SetPoint("BOTTOMRIGHT", b, "BOTTOMRIGHT", -gPad, gPad)
            end

            b:ClearAllPoints()
            b:SetPoint("LEFT", bar, "LEFT", curX, 0)
            curX = curX + bw + spacing
        else
            b:Hide()
        end
    end

    local latExtra = (style == "tabletop") and 11 or 0
    local totalW = max(size, curX - spacing + latExtra)
    bar:SetScale(scale)
    bar:SetWidth(totalW)
    bar:SetHeight(btnH)
    bar:ClearAllPoints()
    bar:SetPoint(anchor, Azaath.root, anchor, ox, oy)
    if Azaath.ClampToScreen then Azaath.ClampToScreen(bar) end
    bar:SetAlpha(M.editing and 1.0 or (db.idleAlpha or 0.80))

    ApplyDockChrome(style, cfg, totalW, btnH)
    UpdateAllVisuals()
end

-- barras da Blizzard (actionbars.layout "blizzard"): o micromenu dela já está lá; o nosso não monta
local function Wanted(db)
    return db and db.enabled and not Azaath.IsBlizzBars()
end

function M:ApplyLayout()
    if not bar then
        if Wanted(self.db) then
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
    -- uma vez só: ApplyLayout (chamado por outros módulos no login) pode já ter criado a barra;
    -- criar de novo deixaria a cópia antiga congelada na posição inicial ("barra fantasma")
    if bar then return self:ApplyLayout() end
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
    if not Wanted(self.db) then return end
    Azaath:RunOutOfCombat(function()
        self:Build()
    end)
end
