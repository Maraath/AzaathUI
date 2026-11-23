--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Chat.lua
    Chat imersivo e fiel à interface de Azaath (Aeternum):
      * Painel escuro obsidian/slate com borda fina ardósia e fundo translúcido.
      * Em repouso (fora de uso): o fundo, moldura, barra lateral e barra de digitação
        desaparecem 100% (alpha 0), enquanto as mensagens de texto continuam
        sempre visíveis e nítidas diretamente sobre o mundo.
      * Ao passar o mouse sobre a área do chat ou abrir para digitar (Enter):
        o fundo obsidian, as abas de canais e controles surgem com fade suave imediato.
      * Barra lateral vertical esquerda com ícones dedicados e opções nativas do WoW:
          - Feed Geral (ícone de balões no topo)
          - Geral (/1)
          - Combate (Registro de combate / ChatFrame2 integrado)
          - Dizer / Local (/s, /y)
          - Sussurro (/w)
          - Guilda (/g, /o)
          - Grupo (/p)
          - Raide (/ra, /rw)
          - Comércio (/2)
          - Procurando Grupo (/4, LFG)
          - Contatos & Amigos (O) no rodapé da barra
      * Indicador de canal ativo: pílula com brilho ciano suave estilo Azaath.
      * Cabeçalho com tipografia serifada espaçada Azaath (G E R A L, C O M B A T E, etc.)
        e botão de recolher/expandir (▲ / ▼).
      * Menu de Opções da Blizzard integrado (Configurações do Bate-papo, canais, emotes,
        tamanho de fonte) via clique na engrenagem ou botão direito no cabeçalho/abas.
      * Formatação de mensagens Azaath:
          [NomeDoAutor]
          (ícone do canal) Texto da mensagem em branco nítido
      * Filtro dinâmico por canal ou visão consolidada em Feed.
      * Barra de digitação (EditBox) moderna integrada com pílula de canal ativo,
        engrenagem de configurações, placeholder "*Enter message*" e
        contador numérico de caracteres (200).
      * Rolagem suave com roda do mouse e botão flutuante "▼ RECENTE".
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("Chat")

local _G = _G
local type, ipairs, pairs, pcall, math, string, table = type, ipairs, pairs, pcall, math, string, table
local max, min = math.max, math.min
local IsShiftKeyDown, IsControlKeyDown = IsShiftKeyDown, IsControlKeyDown
local InCombatLockdown = InCombatLockdown
local hooksecurefunc = hooksecurefunc
local ToggleFriendsFrame = ToggleFriendsFrame or function() end
local EasyMenu = EasyMenu
local GetCursorPosition = GetCursorPosition

--------------------------------------------------------------------------------
-- Constantes e Mídias
--------------------------------------------------------------------------------
local MEDIA_CHAT = Azaath.media.path .. "Chat\\"

local ICONS = {
    FEED        = MEDIA_CHAT .. "ChatFeed",
    GLOBAL      = MEDIA_CHAT .. "ChatGlobal",
    COMBAT      = MEDIA_CHAT .. "ChatCombat",
    AREA        = MEDIA_CHAT .. "ChatArea",
    HELP        = MEDIA_CHAT .. "ChatHelp",
    GROUP       = MEDIA_CHAT .. "ChatGroup",
    TRADE       = MEDIA_CHAT .. "ChatTrade",
    WHISPER     = MEDIA_CHAT .. "ChatWhisper",
    FACTION     = MEDIA_CHAT .. "ChatFaction",
    GUILD       = MEDIA_CHAT .. "ChatGuild",
    RAID        = MEDIA_CHAT .. "ChatRaid",
    LFG         = MEDIA_CHAT .. "ChatLFG",
    SOCIAL      = MEDIA_CHAT .. "ChatSocial",
    GEAR        = MEDIA_CHAT .. "ChatGear",
    COLLAPSE    = MEDIA_CHAT .. "ChatCollapse",
    ACTIVE_PILL = MEDIA_CHAT .. "ActivePill",
}

-- Ordem dos canais exibidos na barra lateral
local CHANNEL_ORDER = {
    "GERAL",
    "COMBAT",
    "SAY",
    "WHISPER",
    "GUILD",
    "PARTY",
    "RAID",
    "TRADE",
    "LFG",
}

-- Mapeamento retrocompatível para perfis anteriores
local CHANNEL_ALIASES = {
    GLOBAL  = "GERAL",
    AREA    = "SAY",
    HELP    = "LFG",
    FACTION = "GUILD",
    GROUP   = "PARTY",
    TODOS   = "FEED",
    ALL     = "FEED",
}

local CHANNEL_INFO = {
    FEED = {
        title = "F E E D",
        label = "Feed",
        icon  = ICONS.FEED,
        tip   = "Feed Completo (Todas as Mensagens)",
    },
    GERAL = {
        title = "G E R A L",
        label = "Geral",
        icon  = ICONS.GLOBAL,
        tip   = "Canal Geral (/1)",
        chatType = "CHANNEL",
        chatTarget = 1,
    },
    COMBAT = {
        title = "C O M B A T E",
        label = "Combate",
        icon  = ICONS.COMBAT,
        tip   = "Registro de Combate (Log)",
        isCombatLog = true,
    },
    SAY = {
        title = "D I Z E R",
        label = "Dizer",
        icon  = ICONS.AREA,
        tip   = "Dizer & Gritar (/s, /y)",
        chatType = "SAY",
    },
    WHISPER = {
        title = "S U S S U R R O",
        label = "Sussurro",
        icon  = ICONS.WHISPER,
        tip   = "Sussurros Diretos (/w)",
        chatType = "WHISPER",
    },
    GUILD = {
        title = "G U I L D A",
        label = "Guilda",
        icon  = ICONS.GUILD,
        tip   = "Guilda & Oficiais (/g, /o)",
        chatType = "GUILD",
    },
    PARTY = {
        title = "G R U P O",
        label = "Grupo",
        icon  = ICONS.GROUP,
        tip   = "Grupo & Masmorra (/p)",
        chatType = "PARTY",
    },
    RAID = {
        title = "R A I D E",
        label = "Raide",
        icon  = ICONS.RAID,
        tip   = "Raide & Aviso de Raide (/ra, /rw)",
        chatType = "RAID",
    },
    TRADE = {
        title = "C O M \195\137 R C I O",
        label = "Comércio",
        icon  = ICONS.TRADE,
        tip   = "Canal de Comércio (/2)",
        chatType = "CHANNEL",
        chatTarget = 2,
    },
    LFG = {
        title = "P R O C U R A N D O   G R U P O",
        label = "LFG",
        icon  = ICONS.LFG,
        tip   = "Procurando Grupo (/4, LFG)",
        chatType = "CHANNEL",
        chatTarget = 4,
    },
}

-- Estado do módulo
local skinnedEditBoxes = {}
local LockChatFramePoints
local LockEditBoxPoints
local IsChatActive
local UpdateInputPillFromEditBox

M.activeChannel = "FEED"
M.isCollapsed = false
M.messageHistory = {}
local MAX_HISTORY = 400

--------------------------------------------------------------------------------
-- Helpers Visuais e Resolução de Fontes
--------------------------------------------------------------------------------
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if LSM then
    pcall(LSM.Register, LSM, "font", "PT Sans", Azaath.media.font)
    pcall(LSM.Register, LSM, "font", "PT Sans Bold", Azaath.media.fontBold)
    pcall(LSM.Register, LSM, "font", "IM Fell DW Pica", Azaath.media.fontTitle)
    pcall(LSM.Register, LSM, "font", "Cinzel Bold", Azaath.media.fontTitleB)
end

local function GetChatFont()
    local media = Azaath.media
    if M.db.fontStyle == "bold" or M.db.fontStyle == "ptsans_bold" then
        return media.fontBold or media.font
    elseif M.db.fontStyle == "serif" or M.db.fontStyle == "imfell" then
        return media.fontTitle
    elseif M.db.fontStyle == "cinzel" then
        return media.fontTitleB
    end
    return media.font
end

local function ApplyChatFont(frame)
    if not frame or not frame.SetFont then return end
    local fontFile = GetChatFont()
    local fontSize = M.db.fontSize or 13
    local flags = M.db.fontOutline or "OUTLINE"

    frame.azApplyingFont = true
    pcall(frame.SetFont, frame, fontFile, fontSize, flags)
    frame.azApplyingFont = false
end

local function ApplyEditBoxFont(editBox)
    if not editBox or not editBox.SetFont then return end
    local fontFile = GetChatFont()
    local fontSize = M.db.fontSize or 13

    editBox.azApplyingFont = true
    pcall(editBox.SetFont, editBox, fontFile, fontSize, "")
    editBox.azApplyingFont = false
end

local function StripTextures(frame)
    if not frame or not frame.GetRegions then return end
    for _, region in ipairs({ frame:GetRegions() }) do
        if region:IsObjectType("Texture") then
            region:SetTexture(nil)
            region:SetAlpha(0)
        end
    end
    if frame.NineSlice then
        frame.NineSlice:SetAlpha(0)
        frame.NineSlice:Hide()
    end
end

--------------------------------------------------------------------------------
-- Menu de Opções da Blizzard & AzaathUI
--------------------------------------------------------------------------------
local chatMenuFrame
local function GetChatMenuFrame()
    if not chatMenuFrame then
        chatMenuFrame = CreateFrame("Frame", "AzaathChatContextMenu", UIParent, "UIDropDownMenuTemplate")
    end
    return chatMenuFrame
end

-- Converte a lista no formato antigo (EasyMenu) para o menu novo (MenuUtil).
local function BuildModernMenu(root, list)
    for _, e in ipairs(list) do
        if e.isTitle then
            root:CreateTitle(e.text)
        elseif e.text == "" then
            root:CreateDivider()
        elseif e.menuList then
            BuildModernMenu(root:CreateButton(e.text), e.menuList)
        elseif type(e.checked) == "function" then
            root:CreateRadio(e.text, function() return e.checked() end, function() e.func() end)
        else
            root:CreateButton(e.text, function() if e.func then e.func() end end)
        end
    end
end

local function OpenChatOptionsMenu(anchorFrame)
    local menuList = {
        {
            text = "Opções do Chat (Blizzard)",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Configurações da Janela...",
            notCheckable = true,
            func = function()
                local cf = (M.activeChannel == "COMBAT" and _G.ChatFrame2) or _G.ChatFrame1
                if _G.ChatConfigFrame then
                    if _G.ChatConfigFrame:IsShown() then
                        Azaath.HidePanel(_G.ChatConfigFrame)
                    else
                        Azaath.ShowPanel(_G.ChatConfigFrame)
                        if _G.ChatConfigFrame_OpenChatConfig and cf then
                            _G.ChatConfigFrame_OpenChatConfig(cf)
                        end
                    end
                elseif _G.FCF_OpenChatConfig and cf then
                    _G.FCF_OpenChatConfig(cf)
                end
            end,
        },
        {
            text = "Canais de Conversa...",
            notCheckable = true,
            func = function()
                if _G.ToggleChannelFrame then
                    _G.ToggleChannelFrame()
                end
            end,
        },
        {
            text = "Menu de Emotes / Ações...",
            notCheckable = true,
            func = function()
                if _G.ToggleChatMenu then
                    _G.ToggleChatMenu()
                elseif _G.ChatFrameMenu_Toggle then
                    _G.ChatFrameMenu_Toggle()
                end
            end,
        },
        {
            text = "Tamanho da Fonte",
            hasArrow = true,
            notCheckable = true,
            menuList = {
                {
                    text = "11 pt",
                    checked = function() return (M.db.fontSize or 13) == 11 end,
                    func = function() M.db.fontSize = 11; M:RefreshStyle() end,
                },
                {
                    text = "12 pt",
                    checked = function() return (M.db.fontSize or 13) == 12 end,
                    func = function() M.db.fontSize = 12; M:RefreshStyle() end,
                },
                {
                    text = "13 pt (Padrão)",
                    checked = function() return (M.db.fontSize or 13) == 13 end,
                    func = function() M.db.fontSize = 13; M:RefreshStyle() end,
                },
                {
                    text = "14 pt",
                    checked = function() return (M.db.fontSize or 13) == 14 end,
                    func = function() M.db.fontSize = 14; M:RefreshStyle() end,
                },
                {
                    text = "16 pt",
                    checked = function() return (M.db.fontSize or 13) == 16 end,
                    func = function() M.db.fontSize = 16; M:RefreshStyle() end,
                },
                {
                    text = "18 pt",
                    checked = function() return (M.db.fontSize or 13) == 18 end,
                    func = function() M.db.fontSize = 18; M:RefreshStyle() end,
                },
            },
        },
        {
            text = "Opacidade do Texto em Repouso",
            hasArrow = true,
            notCheckable = true,
            menuList = {
                {
                    text = "50% (Mais transparente)",
                    checked = function() return (M.db.idleTextAlpha or 0.65) == 0.50 end,
                    func = function() M.db.idleTextAlpha = 0.50 end,
                },
                {
                    text = "65% (Padrão Recomendado)",
                    checked = function() return (M.db.idleTextAlpha or 0.65) == 0.65 end,
                    func = function() M.db.idleTextAlpha = 0.65 end,
                },
                {
                    text = "80% (Levemente translúcido)",
                    checked = function() return (M.db.idleTextAlpha or 0.65) == 0.80 end,
                    func = function() M.db.idleTextAlpha = 0.80 end,
                },
                {
                    text = "100% (Totalmente opaco)",
                    checked = function() return (M.db.idleTextAlpha or 0.65) == 1.0 end,
                    func = function() M.db.idleTextAlpha = 1.0 end,
                },
            },
        },
        {
            text = "",
            notCheckable = true,
            disabled = true,
        },
        {
            text = "AzaathUI",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = "Configurações do Addon (/azaath)",
            notCheckable = true,
            func = function()
                local config = Azaath:GetModule("Config")
                if config and config.Open then config:Open() end
            end,
        },
        {
            text = "Modo de Edição Visual (/azaath edit)",
            notCheckable = true,
            func = function()
                if Azaath.commands and Azaath.commands.edit then
                    Azaath.commands.edit()
                end
            end,
        },
        {
            text = "Limpar Janela Atual",
            notCheckable = true,
            func = function()
                local cf = (M.activeChannel == "COMBAT" and _G.ChatFrame2) or _G.ChatFrame1
                if cf and cf.Clear then
                    cf:Clear()
                end
            end,
        },
    }

    -- O cliente novo não tem EasyMenu/UIDropDownMenu; usa o MenuUtil.
    if MenuUtil and MenuUtil.CreateContextMenu then
        MenuUtil.CreateContextMenu(anchorFrame or UIParent, function(_, root)
            BuildModernMenu(root, menuList)
        end)
    elseif EasyMenu then
        EasyMenu(menuList, GetChatMenuFrame(), anchorFrame or "cursor", 0, 0, "MENU")
    end
end

--------------------------------------------------------------------------------
-- Ocultação de Botões Poluídos da Blizzard
--------------------------------------------------------------------------------
local CLUTTER_BUTTONS = {
    "ChatFrameMenuButton",
    "ChatFrameChannelButton",
    "FriendsMicroButton",
    "QuickJoinToastButton",
    "ChatAlertFrame",
}

local function HideClutterElement(btn)
    if type(btn) == "string" then btn = _G[btn] end
    if not btn then return end
    if btn.IsForbidden and btn:IsForbidden() then return end

    if btn.SetParent and Azaath.hider then
        btn:SetParent(Azaath.hider)
    end
    if btn.UnregisterAllEvents then
        btn:UnregisterAllEvents()
    end
    if btn.Hide then btn:Hide() end
    if btn.SetAlpha then btn:SetAlpha(0) end
    if btn.EnableMouse then btn:EnableMouse(false) end
end

local TEXTURE_NAMES = {
    "Background", "TopLeftTexture", "BottomLeftTexture", "TopRightTexture", "BottomRightTexture",
    "LeftTexture", "RightTexture", "BottomTexture", "TopTexture"
}

local function NeutralizeTab(tab)
    if not tab then return end
    if tab.UnregisterAllEvents then tab:UnregisterAllEvents() end
    tab:SetAlpha(0)
    tab:EnableMouse(false)
    if Azaath.hider and tab.SetParent then
        tab:SetParent(Azaath.hider)
    end
    tab:ClearAllPoints()
    tab:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -9999, -9999)

    if not tab.azNeutralized then
        tab.azNeutralized = true
        hooksecurefunc(tab, "Show", function(self)
            if M.db.enabled and not self.azAllow then
                self:Hide()
                self:SetAlpha(0)
                self:ClearAllPoints()
                self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -9999, -9999)
            end
        end)
        hooksecurefunc(tab, "SetAlpha", function(self, a)
            if M.db.enabled and a > 0 and not self.azAllow then
                self.azAllow = true
                self:SetAlpha(0)
                self.azAllow = false
            end
        end)
    end
    tab:Hide()
end

local function NeutralizeBlizzardChat()
    -- 1. Desativa abas e dock nativos (Geral, Registro de Combate, etc.)
    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local tab = _G["ChatFrame" .. i .. "Tab"]
        if tab then
            NeutralizeTab(tab)
        end

        local cf = _G["ChatFrame" .. i]
        if cf then
            StripTextures(cf)
            if cf.Background then cf.Background:Hide() end
            for _, tName in ipairs(TEXTURE_NAMES) do
                local tex = _G["ChatFrame" .. i .. tName]
                if tex then
                    tex:SetTexture(nil)
                    tex:SetAlpha(0)
                    tex:Hide()
                end
            end

            -- Alterna exibição apenas entre o frame ativo
            local textAlpha = (IsChatActive and IsChatActive()) and 1.0 or (M.db.idleTextAlpha or 0.65)
            if i == 1 then
                if M.activeChannel == "COMBAT" or M.isCollapsed then
                    cf:SetAlpha(0)
                    cf:Hide()
                else
                    cf:Show()
                    cf:SetAlpha(textAlpha)
                    if LockChatFramePoints then LockChatFramePoints(cf) end
                end
            elseif i == 2 then
                if M.activeChannel == "COMBAT" and not M.isCollapsed then
                    cf:Show()
                    cf:SetAlpha(textAlpha)
                    if LockChatFramePoints then LockChatFramePoints(cf) end
                else
                    cf:SetAlpha(0)
                    cf:Hide()
                end
            else
                cf:SetAlpha(0)
                cf:Hide()
            end
        end
    end

    local dock = _G.GENERAL_CHAT_DOCK
    if dock then
        dock:SetAlpha(0)
        dock:EnableMouse(false)
        if Azaath.hider and dock.SetParent then
            dock:SetParent(Azaath.hider)
        end
        dock:ClearAllPoints()
        dock:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -9999, -9999)
        if not dock.azNeutralized then
            dock.azNeutralized = true
            hooksecurefunc(dock, "Show", function(self)
                if M.db.enabled and not self.azAllow then
                    self:Hide()
                    self:SetAlpha(0)
                end
            end)
        end
        dock:Hide()
    end

    -- Botões de atalho do Combat Log (caso existam)
    local clQuick = _G.CombatLogQuickButtonFrame_Custom
    if clQuick then
        clQuick:Hide()
        clQuick:SetAlpha(0)
        clQuick:EnableMouse(false)
        if Azaath.hider and clQuick.SetParent then clQuick:SetParent(Azaath.hider) end
    end

    -- Sincroniza BetterForeverChat para desativar abas e reposicionamentos invasivos
    if _G.BetterForeverChatDB then
        _G.BetterForeverChatDB.fontFace = "lsm:PT Sans"
        _G.BetterForeverChatDB.outline = true
        _G.BetterForeverChatDB.hoverChatTabs = false
        _G.BetterForeverChatDB.editBoxTop = false
        _G.BetterForeverChatDB.tabsAboveInput = false
        _G.BetterForeverChatDB.tabsAtBottom = false
    end
end

local function HideChatClutter()
    if not M.db.hideButtons then return end

    for _, name in ipairs(CLUTTER_BUTTONS) do
        HideClutterElement(name)
    end

    for i = 1, (NUM_CHAT_WINDOWS or 10) do
        local btnFrame = _G["ChatFrame" .. i .. "ButtonFrame"] or (_G["ChatFrame" .. i] and _G["ChatFrame" .. i].buttonFrame)
        if btnFrame then HideClutterElement(btnFrame) end
        local up = _G["ChatFrame" .. i .. "UpButton"]
        local down = _G["ChatFrame" .. i .. "DownButton"]
        local btm = _G["ChatFrame" .. i .. "BottomButton"]
        if up then HideClutterElement(up) end
        if down then HideClutterElement(down) end
        if btm then HideClutterElement(btm) end
    end

    NeutralizeBlizzardChat()

    if _G.BetterForeverChatDB then
        _G.BetterForeverChatDB.fontFace = "lsm:PT Sans"
        _G.BetterForeverChatDB.outline = true
        _G.BetterForeverChatDB.hoverChatTabs = false
    end
end

--------------------------------------------------------------------------------
-- Parser e Classificador de Mensagens Azaath com Cores Autênticas
--------------------------------------------------------------------------------
local function MatchChatTypeByColor(r, g, b)
    if not r or not g or not b or not _G.ChatTypeInfo then return nil end

    local function NearColor(info)
        if not info then return false end
        return math.abs(r - (info.r or 0)) < 0.04
           and math.abs(g - (info.g or 0)) < 0.04
           and math.abs(b - (info.b or 0)) < 0.04
    end

    if NearColor(ChatTypeInfo.WHISPER) or NearColor(ChatTypeInfo.WHISPER_INFORM)
       or NearColor(ChatTypeInfo.BN_WHISPER) or NearColor(ChatTypeInfo.BN_WHISPER_INFORM) then
        return "WHISPER"
    end
    if NearColor(ChatTypeInfo.PARTY) or NearColor(ChatTypeInfo.PARTY_LEADER)
       or NearColor(ChatTypeInfo.INSTANCE_CHAT) or NearColor(ChatTypeInfo.INSTANCE_CHAT_LEADER) then
        return "PARTY"
    end
    if NearColor(ChatTypeInfo.RAID) or NearColor(ChatTypeInfo.RAID_LEADER)
       or NearColor(ChatTypeInfo.RAID_WARNING) then
        return "RAID"
    end
    if NearColor(ChatTypeInfo.GUILD) or NearColor(ChatTypeInfo.OFFICER) then
        return "GUILD"
    end
    if NearColor(ChatTypeInfo.YELL) or NearColor(ChatTypeInfo.SAY) or NearColor(ChatTypeInfo.EMOTE) then
        return "SAY"
    end
    return nil
end

local function DetectChannelType(text, r, g, b)
    if type(text) ~= "string" then return "GERAL" end
    local lower = text:lower()

    -- 1. Canais numerados e públicos específicos têm prioridade por texto
    if lower:find("%[%d+%.%s*trade") or lower:find("%[%d+%.%s*com[e\195\169]rcio") then
        return "TRADE"
    elseif lower:find("%[%d+%.%s*lookingforgroup") or lower:find("%[%d+%.%s*procurandogrupo")
        or lower:find("%[%d+%.%s*recrutamento") or lower:find("%[%d+%.%s*lfg")
        or lower:find("%[%d+%.%s*ajuda") or lower:find("%[%d+%.%s*help") then
        return "LFG"
    elseif lower:find("%[%d+%.%s*general") or lower:find("%[%d+%.%s*geral")
        or lower:find("%[%d+%.%s*world") or lower:find("%[%d+%.%s*global")
        or lower:find("%[%d+%.%s*localdefense") or lower:find("%[%d+%.%s*defesalocal") then
        return "GERAL"
    elseif lower:find("%[%d+%.") then
        return "GERAL"
    end

    -- 2. Detecção por texto para canais sociais
    if lower:find("%[party%]") or lower:find("%[grupo%]")
       or lower:find("%[party leader%]") or lower:find("%[l[\195\173i]der do grupo%]")
       or lower:find("%[dungeon guide%]") or lower:find("%[guia da masmorra%]")
       or lower:find("%[instance%]") or lower:find("%[inst[\195\162a]ncia%]")
       or lower:find("%[instance leader%]") or lower:find("%[l[\195\173i]der da inst[\195\162a]ncia%]") then
        return "PARTY"
    elseif lower:find("%[raid%]") or lower:find("%[raide%]")
        or lower:find("%[raid warning%]") or lower:find("%[aviso de raide%]")
        or lower:find("%[raid leader%]") or lower:find("%[l[\195\173i]der da raide%]") then
        return "RAID"
    elseif lower:find("%[guild%]") or lower:find("%[guilda%]")
        or lower:find("%[officer%]") or lower:find("%[oficia[il]s?%]") then
        return "GUILD"
    elseif lower:find("whispers:") or lower:find("sussurra:")
        or lower:find("to%s+|h") or lower:find("para%s+|h")
        or lower:find("%f[%a]to%s+%[") or lower:find("%f[%a]para%s+%[") then
        return "WHISPER"
    elseif lower:find("says:") or lower:find("diz:")
        or lower:find("yells:") or lower:find("grita:") then
        return "SAY"
    end

    -- 3. Identificação exata via cor Blizzard (ChatTypeInfo)
    local colorChan = MatchChatTypeByColor(r, g, b)
    if colorChan then
        return colorChan
    end

    return "GERAL"
end

local CHANNEL_DEFAULT_COLORS = {
    WHISPER = "ff80ff",   -- Rosa / Magenta clássico de sussurro
    PARTY   = "aaaaff",   -- Azul claro clássico de grupo
    GUILD   = "40ff40",   -- Verde clássico de guilda
    RAID    = "ff7f00",   -- Laranja clássico de raide
    SAY     = "ffffff",   -- Branco de dizer
    TRADE   = "ffc0c0",   -- Pêssego/Salmão de comércio
    LFG     = "80d0ff",   -- Ciano de LFG
    GERAL   = "d0d0d0",   -- Cinza claro de canal geral
    COMBAT  = "ffd200",   -- Amarelo de combate
}

local function GetChatColorHex(chan, r, g, b, isYell)
    if isYell then
        return "ff4040"
    end
    if r and g and b then
        local hr = math.floor(math.min(1, math.max(0, r)) * 255 + 0.5)
        local hg = math.floor(math.min(1, math.max(0, g)) * 255 + 0.5)
        local hb = math.floor(math.min(1, math.max(0, b)) * 255 + 0.5)
        return string.format("%02x%02x%02x", hr, hg, hb)
    end
    if chan and _G.ChatTypeInfo and _G.ChatTypeInfo[chan] then
        local info = _G.ChatTypeInfo[chan]
        local hr = math.floor((info.r or 1) * 255 + 0.5)
        local hg = math.floor((info.g or 1) * 255 + 0.5)
        local hb = math.floor((info.b or 1) * 255 + 0.5)
        return string.format("%02x%02x%02x", hr, hg, hb)
    end
    return CHANNEL_DEFAULT_COLORS[chan] or "f1f5f9"
end

local function ParseAndFormatMessage(text, r, g, b)
    if (Azaath.IsSecret and Azaath.IsSecret(text)) or type(text) ~= "string" or text == "" then return text, "GERAL" end

    -- Não reformatar mensagens que já estejam no formato Azaath
    if text:find(MEDIA_CHAT, 1, true) then
        local chan = text:match("azchan:(%u+)") or "GERAL"
        return text, chan
    end

    local chan = DetectChannelType(text, r, g, b)
    local info = CHANNEL_INFO[chan] or CHANNEL_INFO.GERAL
    local iconFile = (info and info.icon) or ICONS.GLOBAL
    local iconTag = ("|T%s:14:14:0:0|t"):format(iconFile)

    local lower = text:lower()
    local isYell = lower:find("yells:") or lower:find("grita:")
    local isWhisperInform = (chan == "WHISPER") and (lower:find("to%s+|h") or lower:find("para%s+|h") or lower:find("%f[%a]to%s+%[") or lower:find("%f[%a]para%s+%["))

    -- Obtém a cor hexadecimal autêntica do canal para a mensagem
    local msgColorHex = GetChatColorHex(chan, r, g, b, isYell)

    -- Tenta capturar autor com link de jogador (|Hplayer:...|h[Nome]|h ou |HBNplayer:...|h[Nome]|h)
    local pStart, pEnd, pLink, pName = text:find("(|HBN?player:[^|]+|h%[(.-)%]|h)")
    if pLink and pName then
        local prefix = text:sub(1, pStart - 1)
        local timestamp = prefix:match("(%d+:%d+[:%d+]*)")
        local rest = text:sub(pEnd + 1)
        local body = rest:gsub("^%s*:%s*", "")
                         :gsub("^%s*says:%s*", "")
                         :gsub("^%s*diz:%s*", "")
                         :gsub("^%s*yells:%s*", "")
                         :gsub("^%s*grita:%s*", "")
                         :gsub("^%s*whispers:%s*", "")
                         :gsub("^%s*sussurra:%s*", "")
                         :gsub("^%s*", "")

        -- Determina a cor do autor:
        -- 1. Se já havia cor de classe no prefixo (ex: |cfffff569)
        local classColorCode = prefix:match("(|c%x%x%x%x%x%x%x%x)%s*$")
        local authorColor = classColorCode

        -- 2. Se não tinha cor explícita, consulta a classe real do jogador
        if not authorColor and pName and not pName:find("%s") then
            local cleanName = pName:match("^[^-]+") or pName
            local _, class = UnitClass(cleanName)
            if class and (_G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS) then
                local cc = (_G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS)[class]
                if cc then
                    authorColor = string.format("|cff%02x%02x%02x", math.floor(cc.r * 255 + 0.5), math.floor(cc.g * 255 + 0.5), math.floor(cc.b * 255 + 0.5))
                end
            end
        end

        -- 3. Fallback da cor do autor: usa a cor do próprio canal
        if not authorColor then
            authorColor = "|cff" .. msgColorHex
        end

        local displayAuthorName = pName
        if isWhisperInform then
            displayAuthorName = "Para: " .. pName
        end

        local formattedAuthor = pLink:gsub("%[.-%]", authorColor .. ("[%s]|r"):format(displayAuthorName))
        if timestamp then
            formattedAuthor = ("|cff64748b[%s]|r "):format(timestamp) .. formattedAuthor
        end

        local formatted = formattedAuthor .. "\n" .. iconTag .. " " .. "|cff" .. msgColorHex .. body .. "|r"
        return formatted, chan
    end

    -- Fallback sem link: [Nome]: texto
    local rawName, rawBody = text:match("^%s*(?:%[[^%]]+%]%s*)?%[([^%]]+)%]:%s*(.*)$")
    if rawName and rawBody then
        local formatted = ("|cff%s[%s]|r\n%s |cff%s%s|r"):format(msgColorHex, rawName, iconTag, msgColorHex, rawBody)
        return formatted, chan
    end

    -- Mensagem de sistema / genérica: preserva cor original do WoW
    return text, chan or "FEED"
end

--------------------------------------------------------------------------------
-- Layout da Barra Lateral (Distribuição Dinâmica dos Botões)
--------------------------------------------------------------------------------
local function UpdateSidebarButtonsLayout()
    local container = M.container
    if not container or not container.chanButtons then return end
    local h = container:GetHeight() or 290
    local availableH = h - 38 - 38 -- desconta botão Feed no topo e Social no rodapé
    local numButtons = #CHANNEL_ORDER
    local step = min(25, max(18, math.floor(availableH / numButtons)))
    local btnH = min(24, max(17, step - 1))
    local startY = -38

    for idx, chanKey in ipairs(CHANNEL_ORDER) do
        local btn = container.chanButtons[chanKey]
        if btn then
            btn:SetSize(28, btnH)
            btn:ClearAllPoints()
            btn:SetPoint("TOP", container.sidebar, "TOP", 0, startY - (idx - 1) * step)
        end
    end
end

--------------------------------------------------------------------------------
-- Detecção Precisa de Cursor (Baseada em Coordenadas Matemáticas Reais)
--------------------------------------------------------------------------------
local function IsCursorOverFrame(frame, pad)
    if not frame or not frame:IsVisible() then return false end
    local x, y = GetCursorPosition()
    local s = frame:GetEffectiveScale() or 1
    x, y = x / s, y / s

    local left = frame:GetLeft()
    local right = frame:GetRight()
    local bottom = frame:GetBottom()
    local top = frame:GetTop()

    if not left or not right or not bottom or not top then return false end

    pad = pad or 0
    return (x >= left - pad) and (x <= right + pad) and (y >= bottom - pad) and (y <= top + pad)
end

IsChatActive = function()
    local container = M.container
    if not container or not container:IsShown() then return false end

    -- 1. Verifica se o cursor está dentro dos limites da janela de chat
    if IsCursorOverFrame(container, 4) then
        return true
    end

    -- 2. Verifica se a barra de digitação está ativa com foco (digitando)
    for box in pairs(skinnedEditBoxes) do
        if box:IsShown() and box:HasFocus() then
            return true
        end
    end

    -- 3. Menu de contexto aberto
    if _G.AzaathChatContextMenu and _G.AzaathChatContextMenu:IsShown() then
        return true
    end

    return false
end

--------------------------------------------------------------------------------
-- Resolução e Ciclo Dinâmico de Canais de Envio (Pill & EditBox)
--------------------------------------------------------------------------------
local function GetAvailableSendChannels()
    local channels = {}

    -- 1. Sussurro recente (se houver alvo salvo ou último tell)
    local lastTell = (ChatEdit_GetLastTellTarget and ChatEdit_GetLastTellTarget())
        or (_G.ChatEdit_LastTell and _G.ChatEdit_LastTell[1])
    if lastTell and lastTell ~= "" then
        table.insert(channels, {
            chatType = "WHISPER",
            target   = lastTell,
            label    = "Sussurro: " .. lastTell,
            icon     = ICONS.WHISPER,
            color    = { 1.0, 0.5, 0.8 },
        })
    end

    -- 2. Dizer (sempre disponível)
    table.insert(channels, {
        chatType = "SAY",
        label    = "Dizer",
        icon     = ICONS.AREA,
        color    = { 1.0, 1.0, 1.0 },
    })

    -- 3. Grupo (se estiver em grupo/party)
    if (IsInGroup and IsInGroup()) or (GetNumPartyMembers and GetNumPartyMembers() > 0) or (GetNumSubgroupMembers and GetNumSubgroupMembers() > 0) then
        table.insert(channels, {
            chatType = "PARTY",
            label    = "Grupo",
            icon     = ICONS.GROUP,
            color    = { 0.4, 0.75, 1.0 },
        })
    end

    -- 4. Raide (se estiver em raide)
    if (IsInRaid and IsInRaid()) or (GetNumRaidMembers and GetNumRaidMembers() > 0) then
        table.insert(channels, {
            chatType = "RAID",
            label    = "Raide",
            icon     = ICONS.RAID,
            color    = { 1.0, 0.5, 0.1 },
        })
    end

    -- 5. Guilda (se estiver em guilda)
    if IsInGuild and IsInGuild() then
        table.insert(channels, {
            chatType = "GUILD",
            label    = "Guilda",
            icon     = ICONS.GUILD,
            color    = { 0.3, 0.9, 0.3 },
        })
    end

    -- 6. Canais Públicos Nativos (Geral /1, Comércio /2, LFG /4)
    if GetChannelName then
        local id1, name1 = GetChannelName(1)
        if id1 and id1 > 0 then
            table.insert(channels, {
                chatType = "CHANNEL",
                target   = id1,
                label    = (name1 and name1 ~= "") and name1 or "Geral (/1)",
                icon     = ICONS.GLOBAL,
                color    = { 0.8, 0.8, 0.8 },
            })
        end
        local id2, name2 = GetChannelName(2)
        if id2 and id2 > 0 then
            table.insert(channels, {
                chatType = "CHANNEL",
                target   = id2,
                label    = (name2 and name2 ~= "") and name2 or "Comércio (/2)",
                icon     = ICONS.TRADE,
                color    = { 0.85, 0.75, 0.55 },
            })
        end
        local id4, name4 = GetChannelName(4)
        if id4 and id4 > 0 then
            table.insert(channels, {
                chatType = "CHANNEL",
                target   = id4,
                label    = (name4 and name4 ~= "") and name4 or "LFG (/4)",
                icon     = ICONS.SEARCH,
                color    = { 0.5, 0.85, 0.9 },
            })
        end
    end

    return channels
end

UpdateInputPillFromEditBox = function(editBox)
    local container = M.container
    if not container or not container.chanPill then return end
    local pill = container.chanPill

    if not editBox then
        editBox = _G.ChatFrame1EditBox or (_G.ChatFrame1 and _G.ChatFrame1.editBox)
    end
    if not editBox then return end

    local chatType = editBox:GetAttribute("chatType")
    local tellTarget = editBox:GetAttribute("tellTarget")
    local chanTarget = editBox:GetAttribute("channelTarget")

    local icon = ICONS.FEED or ICONS.GLOBAL
    local label = "Feed"
    local color = { 0.85, 0.88, 0.92 }

    if chatType == "WHISPER" then
        icon = ICONS.WHISPER
        color = { 1.0, 0.5, 0.8 }
        if tellTarget and tellTarget ~= "" then
            label = "Sussurro: " .. tellTarget
        else
            label = "Sussurro"
        end
    elseif chatType == "BN_WHISPER" then
        icon = ICONS.WHISPER
        color = { 0.4, 0.78, 1.0 }
        local bnetName = tellTarget
        if tonumber(tellTarget) and BNet_GetAccountInfoByID then
            local info = BNet_GetAccountInfoByID(tonumber(tellTarget))
            if info and info.accountName then
                bnetName = info.accountName
            end
        end
        if bnetName and bnetName ~= "" then
            label = "BNet: " .. bnetName
        else
            label = "BNet"
        end
    elseif chatType == "PARTY" then
        icon = ICONS.GROUP
        color = { 0.4, 0.75, 1.0 }
        label = "Grupo"
    elseif chatType == "RAID" then
        icon = ICONS.RAID
        color = { 1.0, 0.5, 0.1 }
        label = "Raide"
    elseif chatType == "RAID_WARNING" then
        icon = ICONS.RAID
        color = { 1.0, 0.3, 0.1 }
        label = "Aviso de Raide"
    elseif chatType == "GUILD" then
        icon = ICONS.GUILD
        color = { 0.3, 0.9, 0.3 }
        label = "Guilda"
    elseif chatType == "OFFICER" then
        icon = ICONS.GUILD
        color = { 0.2, 0.75, 0.2 }
        label = "Oficiais"
    elseif chatType == "SAY" then
        icon = ICONS.AREA
        color = { 1.0, 1.0, 1.0 }
        label = "Dizer"
    elseif chatType == "YELL" then
        icon = ICONS.AREA
        color = { 1.0, 0.3, 0.3 }
        label = "Gritar"
    elseif chatType == "EMOTE" then
        icon = ICONS.AREA
        color = { 1.0, 0.5, 0.2 }
        label = "Emote"
    elseif chatType == "CHANNEL" then
        icon = ICONS.GLOBAL
        color = { 0.8, 0.8, 0.8 }
        local cNum = tonumber(chanTarget)
        if cNum then
            local _, cName = (GetChannelName and GetChannelName(cNum))
            if cName and cName ~= "" then
                label = string.format("%s (/%d)", cName, cNum)
            else
                label = string.format("Canal /%d", cNum)
            end
            if cNum == 2 then
                icon = ICONS.TRADE
                color = { 0.85, 0.75, 0.55 }
            elseif cNum == 4 then
                icon = ICONS.SEARCH
                color = { 0.5, 0.85, 0.9 }
            end
        else
            label = "Canal"
        end
    else
        -- Sem chatType explícito no EditBox: reflete o canal ativo na barra lateral
        local info = CHANNEL_INFO[M.activeChannel]
        if info then
            icon = info.icon or ICONS.FEED
            label = info.label or "Feed"
        end
    end

    if pill.icon then
        pill.icon:SetTexture(icon)
        pill.icon:SetVertexColor(color[1], color[2], color[3], 1.0)
    end
    if pill.text then
        pill.text:SetText(label)
        pill.text:SetTextColor(color[1], color[2], color[3], 1.0)
        local textW = pill.text:GetStringWidth() or 40
        local pillW = math.max(76, math.min(180, textW + 28))
        pill:SetWidth(pillW)
    end
end

function M:CycleInputChannel()
    local editBox = _G.ChatFrame1EditBox or (_G.ChatFrame1 and _G.ChatFrame1.editBox)
    if not editBox then return end

    local available = GetAvailableSendChannels()
    if #available == 0 then return end

    local curType = editBox:GetAttribute("chatType")
    local curChan = editBox:GetAttribute("channelTarget")
    local curTell = editBox:GetAttribute("tellTarget")

    local curIdx = 0
    for i, c in ipairs(available) do
        if c.chatType == curType then
            if c.chatType == "CHANNEL" then
                if tonumber(c.target) == tonumber(curChan) then
                    curIdx = i
                    break
                end
            elseif c.chatType == "WHISPER" or c.chatType == "BN_WHISPER" then
                if c.target == curTell then
                    curIdx = i
                    break
                end
            else
                curIdx = i
                break
            end
        end
    end

    local nextIdx = (curIdx % #available) + 1
    local nextChan = available[nextIdx]

    pcall(editBox.SetAttribute, editBox, "chatType", nextChan.chatType)
    if nextChan.target then
        if nextChan.chatType == "CHANNEL" then
            pcall(editBox.SetAttribute, editBox, "channelTarget", nextChan.target)
        elseif nextChan.chatType == "WHISPER" or nextChan.chatType == "BN_WHISPER" then
            pcall(editBox.SetAttribute, editBox, "tellTarget", nextChan.target)
        end
    else
        pcall(editBox.SetAttribute, editBox, "channelTarget", nil)
        pcall(editBox.SetAttribute, editBox, "tellTarget", nil)
    end

    UpdateInputPillFromEditBox(editBox)

    if not editBox:IsShown() then
        editBox:Show()
    end
    editBox:SetFocus()
end

--------------------------------------------------------------------------------
-- Container Azaath (Painel Principal, Barra Lateral e Cabeçalho)
--------------------------------------------------------------------------------
local function CreateAzaathChatUI()
    if M.container then return M.container end

    local c, media = Azaath.colors, Azaath.media
    local chatFrame = _G.ChatFrame1
    if not chatFrame then return end

    -- Frame Container Mestre (Invisível, âncora matemática de posicionamento)
    local container = CreateFrame("Frame", "AzaathChatContainer", UIParent)
    container:SetSize(M.db.width or 420, M.db.height or 290)
    container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", M.db.offsetX or 28, M.db.offsetY or 48)
    container:SetScale(M.db.scale or 1)
    container:SetFrameStrata("LOW")
    container:SetFrameLevel(10)
    container:SetClampedToScreen(true)
    container:EnableMouse(false)
    M.container = container

    -- Painel Visual e Moldura (Chrome) Azaath:
    -- Em repouso, sofre fade out total (alpha 0) deixando o fundo 100% invisível.
    -- As mensagens de texto continuam sempre visíveis com alpha 1.
    local chrome = CreateFrame("Frame", nil, container)
    chrome:SetAllPoints(container)
    chrome:SetFrameLevel(container:GetFrameLevel() + 1)
    chrome:SetAlpha(0.0)
    chrome:EnableMouse(false)
    container.chrome = chrome

    -- Fundo escuro obsidiana
    Azaath.SetBackdrop(chrome, {
        bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    chrome:SetBackdropColor(0.04, 0.05, 0.07, M.db.activeAlpha or 0.88)
    chrome:SetBackdropBorderColor(c.slate[1] * 0.7, c.slate[2] * 0.7, c.slate[3] * 0.7, 0.85)

    -- Sombra suave interna
    local innerGlow = chrome:CreateTexture(nil, "BACKGROUND", nil, 1)
    innerGlow:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
    innerGlow:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -1, 1)
    innerGlow:SetTexture(media.blank)
    innerGlow:SetVertexColor(0.02, 0.03, 0.04, 0.60)
    chrome.innerGlow = innerGlow

    ----------------------------------------------------------------------------
    -- 1. Barra Lateral Esquerda (Navegação & Canais)
    ----------------------------------------------------------------------------
    local sidebar = CreateFrame("Frame", nil, chrome)
    sidebar:SetPoint("TOPLEFT", chrome, "TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", chrome, "BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(36)
    sidebar:SetFrameLevel(chrome:GetFrameLevel() + 15)
    container.sidebar = sidebar

    local sideBg = sidebar:CreateTexture(nil, "BACKGROUND")
    sideBg:SetAllPoints()
    sideBg:SetTexture(media.blank)
    sideBg:SetVertexColor(0.035, 0.045, 0.06, 0.96)

    -- Divisor vertical direito
    local sideDiv = sidebar:CreateTexture(nil, "BORDER")
    sideDiv:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
    sideDiv:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
    sideDiv:SetWidth(1)
    sideDiv:SetTexture(media.blank)
    sideDiv:SetVertexColor(0.12, 0.16, 0.20, 0.9)

    -- Pílula Ciano de Destaque da Aba Ativa (ActivePill)
    local activePill = sidebar:CreateTexture(nil, "ARTWORK")
    activePill:SetTexture(ICONS.ACTIVE_PILL)
    activePill:SetSize(32, 26)
    activePill:SetVertexColor(1, 1, 1, 0.95)
    container.activePill = activePill

    -- Botão FEED no Topo (Balões de conversa)
    local feedBtn = CreateFrame("Button", nil, sidebar)
    feedBtn:SetSize(28, 26)
    feedBtn:SetPoint("TOP", sidebar, "TOP", 0, -5)
    feedBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local feedIcon = feedBtn:CreateTexture(nil, "OVERLAY")
    feedIcon:SetSize(18, 18)
    feedIcon:SetPoint("CENTER", feedBtn, "CENTER", 0, 0)
    feedIcon:SetTexture(ICONS.FEED)
    feedIcon:SetVertexColor(0.65, 0.72, 0.80, 0.9)
    feedBtn.icon = feedIcon
    feedBtn.channel = "FEED"

    feedBtn:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            OpenChatOptionsMenu(self)
        else
            M:SelectChannel("FEED")
        end
    end)
    feedBtn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(CHANNEL_INFO.FEED.tip, 1, 1, 1)
        GameTooltip:Show()
    end)
    feedBtn:SetScript("OnLeave", function(self)
        if M.activeChannel ~= "FEED" then
            self.icon:SetVertexColor(0.65, 0.72, 0.80, 0.9)
        end
        GameTooltip:Hide()
    end)
    container.feedBtn = feedBtn

    -- Divisor horizontal abaixo do FEED
    local feedDiv = sidebar:CreateTexture(nil, "BORDER")
    feedDiv:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 4, -34)
    feedDiv:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", -4, -34)
    feedDiv:SetHeight(1)
    feedDiv:SetTexture(media.blank)
    feedDiv:SetVertexColor(0.12, 0.16, 0.20, 0.85)

    -- Botões de Canais Verticais
    container.chanButtons = {}

    for _, chanKey in ipairs(CHANNEL_ORDER) do
        local info = CHANNEL_INFO[chanKey]
        local btn = CreateFrame("Button", nil, sidebar)
        btn:SetSize(28, 22)
        btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

        local icon = btn:CreateTexture(nil, "OVERLAY")
        icon:SetSize(16, 16)
        icon:SetPoint("CENTER", btn, "CENTER", 0, 0)
        icon:SetTexture(info.icon)
        icon:SetVertexColor(0.60, 0.68, 0.76, 0.85)
        btn.icon = icon
        btn.channel = chanKey

        -- Ponto de notificação de mensagens não lidas
        local dot = btn:CreateTexture(nil, "OVERLAY", nil, 7)
        dot:SetSize(5, 5)
        dot:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -2, -2)
        dot:SetTexture(media.blank)
        dot:SetVertexColor(0.0, 0.75, 1.0, 1.0)
        dot:Hide()
        btn.unreadDot = dot

        btn:SetScript("OnClick", function(self, button)
            if button == "RightButton" then
                OpenChatOptionsMenu(self)
            else
                M:SelectChannel(chanKey)
            end
        end)
        btn:SetScript("OnEnter", function(self)
            self.icon:SetVertexColor(1, 1, 1, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(info.tip, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            if M.activeChannel ~= chanKey then
                self.icon:SetVertexColor(0.60, 0.68, 0.76, 0.85)
            end
            GameTooltip:Hide()
        end)

        container.chanButtons[chanKey] = btn
    end

    UpdateSidebarButtonsLayout()

    -- Botão Social no Rodapé da Barra Lateral
    local socialBtn = CreateFrame("Button", nil, sidebar)
    socialBtn:SetSize(26, 26)
    socialBtn:SetPoint("BOTTOM", sidebar, "BOTTOM", 0, 6)

    local socialIcon = socialBtn:CreateTexture(nil, "OVERLAY")
    socialIcon:SetSize(16, 16)
    socialIcon:SetPoint("CENTER", socialBtn, "CENTER", 0, 0)
    socialIcon:SetTexture(ICONS.SOCIAL)
    socialIcon:SetVertexColor(0.45, 0.78, 0.95, 0.9)
    socialBtn.icon = socialIcon

    socialBtn:SetScript("OnClick", function()
        ToggleFriendsFrame(1)
    end)
    -- ToggleFriendsFrame chamado pelo addon abre a janela via ShowUIPanel com taint, e o
    -- gerenciador de painéis passa o taint adiante (ex.: compra no banco bloqueada).
    -- Um botão seguro solto cobre o ícone ao passar o mouse e aciona o botão da
    -- Blizzard; solto (não filho) para a barra lateral seguir livre em combate.
    local friendsBlizz
    if Azaath.IS_MODERN then
        for _, n in ipairs({ "SocialsMicroButton", "FriendsMicroButton", "QuickJoinToastButton" }) do
            if _G[n] and _G[n].Click then friendsBlizz = n break end
        end
    end
    if friendsBlizz then
        local ov = CreateFrame("Button", "AzaathUIChatSocialSecure", UIParent, "SecureActionButtonTemplate")
        ov:SetFrameStrata("DIALOG")
        ov:RegisterForClicks("AnyUp")
        ov:SetAttribute("useOnKeyDown", false)
        ov:SetAttribute("type", "macro")
        ov:SetAttribute("macrotext", "/click " .. friendsBlizz)
        ov:Hide()
        ov:SetScript("OnEnter", function() socialBtn:GetScript("OnEnter")(socialBtn) end)
        ov:SetScript("OnLeave", function(self)
            socialBtn:GetScript("OnLeave")(socialBtn)
            if not InCombatLockdown() then self:Hide() end
        end)
        socialBtn.azSecureAttach = function(self)
            if InCombatLockdown() or ov:IsShown() then return end
            local l, t = self:GetLeft(), self:GetTop()
            if not (l and t) then return end
            local s = self:GetEffectiveScale() / ov:GetEffectiveScale()
            ov:ClearAllPoints()
            ov:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", l * s, t * s)
            ov:SetSize(self:GetWidth() * s, self:GetHeight() * s)
            ov:Show()
        end
    end
    socialBtn:SetScript("OnEnter", function(self)
        if self.azSecureAttach then self.azSecureAttach(self) end
        self.icon:SetVertexColor(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Contatos & Amigos (O)", 1, 1, 1)
        GameTooltip:Show()
    end)
    socialBtn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.45, 0.78, 0.95, 0.9)
        GameTooltip:Hide()
    end)

    ----------------------------------------------------------------------------
    -- 2. Cabeçalho Superior (Header Bar)
    ----------------------------------------------------------------------------
    local header = CreateFrame("Button", nil, chrome)
    header:SetPoint("TOPLEFT", sidebar, "TOPRIGHT", 0, 0)
    header:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", 0, 0)
    header:SetHeight(32)
    header:SetFrameLevel(chrome:GetFrameLevel() + 15)
    header:EnableMouse(true)
    header:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    header:SetScript("OnClick", function(self, button)
        if button == "RightButton" then
            OpenChatOptionsMenu(self)
        else
            M:ToggleCollapse()
        end
    end)
    header:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Clique esquerdo: Recolher/Expandir\nClique direito: Opções do Chat", 0.9, 0.9, 0.9)
        GameTooltip:Show()
    end)
    header:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    container.header = header

    -- Título Serifado Espaçado Azaath (G E R A L)
    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont(media.fontTitle, 13, "")
    title:SetTextColor(c.parchment[1] or 0.88, c.parchment[2] or 0.85, c.parchment[3] or 0.78, 1.0)
    title:SetShadowColor(0, 0, 0, 0.95)
    title:SetShadowOffset(1, -1)
    title:SetPoint("LEFT", header, "LEFT", 12, 0)
    title:SetText("G E R A L")
    container.title = title

    -- Botão de Recolher / Expandir no Canto Superior Direito (▲ / ▼)
    local collapseBtn = CreateFrame("Button", nil, header)
    collapseBtn:SetSize(20, 20)
    collapseBtn:SetPoint("RIGHT", header, "RIGHT", -7, 0)
    collapseBtn:SetFrameLevel(header:GetFrameLevel() + 5)

    Azaath.SetBackdrop(collapseBtn, {
        bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    collapseBtn:SetBackdropColor(0.08, 0.10, 0.13, 0.9)
    collapseBtn:SetBackdropBorderColor(c.slate[1] * 0.8, c.slate[2] * 0.8, c.slate[3] * 0.8, 0.85)

    local collapseIcon = collapseBtn:CreateTexture(nil, "OVERLAY")
    collapseIcon:SetSize(12, 12)
    collapseIcon:SetPoint("CENTER", collapseBtn, "CENTER", 0, 0)
    collapseIcon:SetTexture(ICONS.COLLAPSE)
    collapseIcon:SetVertexColor(0.85, 0.85, 0.85, 1.0)
    collapseBtn.icon = collapseIcon

    collapseBtn:SetScript("OnClick", function() M:ToggleCollapse() end)
    collapseBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.9, 0.5, 1)
        self.icon:SetVertexColor(1, 1, 1, 1)
    end)
    collapseBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(c.slate[1] * 0.8, c.slate[2] * 0.8, c.slate[3] * 0.8, 0.85)
        self.icon:SetVertexColor(0.85, 0.85, 0.85, 1.0)
    end)
    container.collapseBtn = collapseBtn

    -- Divisor horizontal abaixo do cabeçalho
    local headDiv = header:CreateTexture(nil, "BORDER")
    headDiv:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    headDiv:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    headDiv:SetHeight(1)
    headDiv:SetTexture(media.blank)
    headDiv:SetVertexColor(0.12, 0.16, 0.20, 0.9)

    ----------------------------------------------------------------------------
    -- 3. Barra de Digitação e Controles Inferiores (EditBox & Pill)
    ----------------------------------------------------------------------------
    local inputBar = CreateFrame("Frame", nil, chrome)
    inputBar:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMRIGHT", 8, 8)
    inputBar:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -8, 8)
    inputBar:SetHeight(52)
    inputBar:SetFrameLevel(chrome:GetFrameLevel() + 15)
    container.inputBar = inputBar

    -- Pílula de Canal Ativo ([ 🌐 Geral ])
    local chanPill = CreateFrame("Button", nil, inputBar)
    chanPill:SetSize(82, 18)
    chanPill:SetPoint("TOPLEFT", inputBar, "TOPLEFT", 0, 0)

    Azaath.SetBackdrop(chanPill, {
        bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    chanPill:SetBackdropColor(0.06, 0.08, 0.11, 0.95)
    chanPill:SetBackdropBorderColor(0.20, 0.26, 0.32, 0.85)

    local chanPillIcon = chanPill:CreateTexture(nil, "OVERLAY")
    chanPillIcon:SetSize(12, 12)
    chanPillIcon:SetPoint("LEFT", chanPill, "LEFT", 4, 0)
    chanPillIcon:SetTexture(ICONS.GLOBAL)
    chanPill.icon = chanPillIcon

    local chanPillText = chanPill:CreateFontString(nil, "OVERLAY")
    chanPillText:SetFont(media.font, 10, "")
    chanPillText:SetTextColor(0.85, 0.88, 0.92, 1.0)
    chanPillText:SetPoint("LEFT", chanPillIcon, "RIGHT", 4, 0)
    chanPillText:SetPoint("RIGHT", chanPill, "RIGHT", -4, 0)
    chanPillText:SetJustifyH("LEFT")
    chanPillText:SetWordWrap(false)
    chanPillText:SetText("Geral")
    chanPill.text = chanPillText

    chanPill:SetScript("OnClick", function() M:CycleInputChannel() end)
    chanPill:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 1.0)
        GameTooltip:SetOwner(self, "ANCHOR_TOP")
        GameTooltip:SetText("Destino da Mensagem", 1, 1, 1)
        GameTooltip:AddLine("Clique para alternar o canal de envio.\nComandos como /p, /g, /ra, /s, /w, /1 também alteram o destino.", 0.8, 0.8, 0.8, true)
        GameTooltip:Show()
    end)
    chanPill:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.20, 0.26, 0.32, 0.85)
        GameTooltip:Hide()
    end)
    container.chanPill = chanPill

    -- Engrenagem de Configurações no Canto Direito (Abre Menu Blizzard & Azaath)
    local gearBtn = CreateFrame("Button", nil, inputBar)
    gearBtn:SetSize(18, 18)
    gearBtn:SetPoint("TOPRIGHT", inputBar, "TOPRIGHT", 0, 0)
    gearBtn:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    local gearIcon = gearBtn:CreateTexture(nil, "OVERLAY")
    gearIcon:SetSize(14, 14)
    gearIcon:SetPoint("CENTER", gearBtn, "CENTER", 0, 0)
    gearIcon:SetTexture(ICONS.GEAR)
    gearIcon:SetVertexColor(0.80, 0.78, 0.72, 0.85)
    gearBtn.icon = gearIcon

    gearBtn:SetScript("OnClick", function(self)
        OpenChatOptionsMenu(self)
    end)
    gearBtn:SetScript("OnEnter", function(self)
        self.icon:SetVertexColor(1, 1, 1, 1)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Opções do Chat (Blizzard & AzaathUI)", 1, 1, 1)
        GameTooltip:Show()
    end)
    gearBtn:SetScript("OnLeave", function(self)
        self.icon:SetVertexColor(0.80, 0.78, 0.72, 0.85)
        GameTooltip:Hide()
    end)

    ----------------------------------------------------------------------------
    -- 4. Barra de Rolagem Moderna (Scrollbar)
    ----------------------------------------------------------------------------
    local scrollTrack = CreateFrame("Frame", nil, chrome)
    scrollTrack:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -4, -36)
    scrollTrack:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -4, 64)
    scrollTrack:SetWidth(4)

    local trackBg = scrollTrack:CreateTexture(nil, "BACKGROUND")
    trackBg:SetAllPoints()
    trackBg:SetTexture(media.blank)
    trackBg:SetVertexColor(0.08, 0.10, 0.14, 0.6)

    local scrollThumb = scrollTrack:CreateTexture(nil, "ARTWORK")
    scrollThumb:SetSize(4, 24)
    scrollThumb:SetPoint("TOP", scrollTrack, "TOP", 0, 0)
    scrollThumb:SetTexture(media.blank)
    scrollThumb:SetVertexColor(0.35, 0.42, 0.50, 0.85)
    container.scrollThumb = scrollThumb
    container.scrollTrack = scrollTrack

    return container
end

--------------------------------------------------------------------------------
-- Travamento Rígido e Posicionamento dos ChatFrames (ChatFrame1 & ChatFrame2)
--------------------------------------------------------------------------------
LockChatFramePoints = function(cf)
    if not cf or not M.container or not M.db or not M.db.enabled then return end
    if cf.azLockingPoints then return end
    cf.azLockingPoints = true

    if not InCombatLockdown() then
        if cf:GetParent() ~= M.container then
            cf:SetParent(M.container)
        end
        cf:SetFrameStrata(M.container:GetFrameStrata())
        cf:SetFrameLevel(M.container:GetFrameLevel() + 5)

        cf:ClearAllPoints()
        cf:SetPoint("TOPLEFT", M.container, "TOPLEFT", 44, -36)
        cf:SetPoint("BOTTOMRIGHT", M.container, "BOTTOMRIGHT", -16, 64)

        if cf.SetMovable then pcall(cf.SetMovable, cf, true) end
        if cf.SetUserPlaced then pcall(cf.SetUserPlaced, cf, true) end
        if cf.SetClampedToScreen then pcall(cf.SetClampedToScreen, cf, false) end
        if cf.SetClampRectInsets then
            pcall(cf.SetClampRectInsets, cf, 0, 0, 0, 0)
        end
        if cf.SetClipsChildren then
            pcall(cf.SetClipsChildren, cf, true)
        end
    end

    cf.azLockingPoints = false
end

local function SecureLockChatFrame(cf)
    if not cf or cf.azSecureHooked then return end
    cf.azSecureHooked = true

    local function OnExternalResizeOrMove(self)
        if M.db and M.db.enabled and not self.azLockingPoints then
            LockChatFramePoints(self)
        end
    end

    hooksecurefunc(cf, "SetPoint", OnExternalResizeOrMove)
    hooksecurefunc(cf, "SetAllPoints", OnExternalResizeOrMove)
    hooksecurefunc(cf, "SetWidth", OnExternalResizeOrMove)
    hooksecurefunc(cf, "SetHeight", OnExternalResizeOrMove)
    hooksecurefunc(cf, "SetSize", OnExternalResizeOrMove)
    hooksecurefunc(cf, "SetParent", function(self, newParent)
        if M.db and M.db.enabled and not self.azLockingPoints and M.container and newParent ~= M.container then
            LockChatFramePoints(self)
        end
    end)
end

local function AttachChatFrame(chatFrame)
    if not chatFrame then return end
    local container = M.container
    if not container then return end

    if not chatFrame.azAttached then
        chatFrame.azAttached = true

        -- Limpa texturas nativas do ChatFrame
        StripTextures(chatFrame)
        if chatFrame.Background then chatFrame.Background:Hide() end

        -- Trava e aplica a fonte Azaath
        ApplyChatFont(chatFrame)
        if not chatFrame.azFontHooked then
            chatFrame.azFontHooked = true
            hooksecurefunc(chatFrame, "SetFont", function(self, font)
                if self.azApplyingFont then return end
                ApplyChatFont(self)
            end)
        end

        if chatFrame.SetSpacing then
            pcall(chatFrame.SetSpacing, chatFrame, 4)
        end

        -- Atualiza scroll thumb quando rolar
        chatFrame:EnableMouseWheel(true)
        chatFrame:HookScript("OnMouseWheel", function(self, delta)
            M:UpdateScrollVisual()
        end)

        SecureLockChatFrame(chatFrame)
    end

    -- Reancoragem segura e travada do ChatFrame dentro do container Azaath.
    -- O frame de mensagens é filho direto do container (não do chrome que sofre fade),
    -- ficando com opacidade suave em repouso e 100% nítido ao interagir.
    LockChatFramePoints(chatFrame)
    chatFrame:SetAlpha((IsChatActive and IsChatActive()) and 1.0 or (M.db.idleTextAlpha or 0.65))
end

--------------------------------------------------------------------------------
-- Estilização da Barra de Digitação (EditBox) Azaath
--------------------------------------------------------------------------------
LockEditBoxPoints = function(editBox)
    if not editBox or not M.container or not M.container.inputBar or not M.db or not M.db.enabled then return end
    if editBox.azLockingPoints then return end
    editBox.azLockingPoints = true

    if not InCombatLockdown() then
        if editBox:GetParent() ~= M.container.inputBar then
            editBox:SetParent(M.container.inputBar)
        end
        editBox:ClearAllPoints()
        editBox:SetPoint("BOTTOMLEFT", M.container.inputBar, "BOTTOMLEFT", 0, 2)
        editBox:SetPoint("BOTTOMRIGHT", M.container.inputBar, "BOTTOMRIGHT", 0, 2)
        editBox:SetHeight(26)
    end

    editBox.azLockingPoints = false
end

local function SetupEditBox(editBox)
    if not editBox or editBox.azInitialized then return end
    editBox.azInitialized = true
    skinnedEditBoxes[editBox] = true

    local media = Azaath.media
    local container = M.container
    if not container then return end

    -- Limpa arte da Blizzard
    local boxName = editBox:GetName()
    if boxName then
        local blizzTex = {
            _G[boxName .. "Left"], _G[boxName .. "Mid"], _G[boxName .. "Right"],
            _G[boxName .. "FocusLeft"], _G[boxName .. "FocusMid"], _G[boxName .. "FocusRight"],
        }
        for _, tex in ipairs(blizzTex) do
            if tex then tex:SetTexture(nil); tex:SetAlpha(0) end
        end
    end
    StripTextures(editBox)

    -- Caixa escura elegante 1px
    Azaath.SetBackdrop(editBox, {
        bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
        insets = { left = 4, right = 32, top = 2, bottom = 2 },
    })
    editBox:SetBackdropColor(0.04, 0.05, 0.07, 0.96)
    editBox:SetBackdropBorderColor(0.18, 0.23, 0.28, 0.85)

    -- Filete sutil
    local topBorder = editBox:CreateTexture(nil, "OVERLAY")
    topBorder:SetTexture(media.blank)
    topBorder:SetHeight(1)
    topBorder:SetPoint("TOPLEFT", editBox, "TOPLEFT", 1, -1)
    topBorder:SetPoint("TOPRIGHT", editBox, "TOPRIGHT", -1, -1)
    topBorder:SetVertexColor(0.0, 0.7, 0.95, 0.4)
    topBorder:Hide()
    editBox.azTopBorder = topBorder

    -- Placeholder "*Enter message*"
    local placeholder = editBox:CreateFontString(nil, "OVERLAY")
    placeholder:SetFont(media.font, 12, "")
    placeholder:SetTextColor(0.42, 0.48, 0.55, 0.75)
    placeholder:SetPoint("LEFT", editBox, "LEFT", 8, 0)
    placeholder:SetText("Enter message")
    editBox.azPlaceholder = placeholder

    -- Contador de Caracteres no canto inferior direito ("200")
    local counter = editBox:CreateFontString(nil, "OVERLAY")
    counter:SetFont(media.font, 11, "")
    counter:SetTextColor(0.55, 0.62, 0.70, 0.85)
    counter:SetPoint("RIGHT", editBox, "RIGHT", -6, 0)
    counter:SetText("200")
    editBox.azCounter = counter

    -- Fonte Azaath
    ApplyEditBoxFont(editBox)

    -- Posicionamento da caixa logo abaixo da pílula de canal, filha do inputBar
    LockEditBoxPoints(editBox)

    if not editBox.azPointHooked then
        editBox.azPointHooked = true
        local function OnEditBoxMoved(self)
            if M.db and M.db.enabled and not self.azLockingPoints then
                LockEditBoxPoints(self)
            end
        end
        hooksecurefunc(editBox, "SetPoint", OnEditBoxMoved)
        hooksecurefunc(editBox, "SetAllPoints", OnEditBoxMoved)
        hooksecurefunc(editBox, "SetWidth", OnEditBoxMoved)
        hooksecurefunc(editBox, "SetHeight", OnEditBoxMoved)
        hooksecurefunc(editBox, "SetParent", function(self, newParent)
            if M.db and M.db.enabled and not self.azLockingPoints and M.container and M.container.inputBar and newParent ~= M.container.inputBar then
                LockEditBoxPoints(self)
            end
        end)
    end

    -- Trava os insets de texto do EditBox para começar rente à esquerda (8px de padding)
    editBox.azSettingInsets = true
    editBox:SetTextInsets(8, 32, 0, 0)
    editBox.azSettingInsets = false

    if not editBox.azInsetsHooked then
        editBox.azInsetsHooked = true
        hooksecurefunc(editBox, "SetTextInsets", function(self, l, r, t, b)
            if self.azSettingInsets then return end
            if l ~= 8 or r ~= 32 then
                self.azSettingInsets = true
                self:SetTextInsets(8, 32, 0, 0)
                self.azSettingInsets = false
            end
        end)
    end

    -- Esconde cabeçalho nativo da Blizzard ("[Dizer]:", "[Geral]:", etc.) para não empurrar o texto
    local header = editBox.header or (boxName and _G[boxName .. "Header"])
    if header then
        header:SetAlpha(0)
        header:Hide()
        header:SetText("")
        header:SetWidth(0.001)
        header:ClearAllPoints()
        header:SetPoint("TOPLEFT", UIParent, "TOPLEFT", -9999, -9999)
        if not header.azHooked then
            header.azHooked = true
            hooksecurefunc(header, "SetText", function(self, txt)
                if M.db.enabled and txt and txt ~= "" then
                    self:SetText("")
                end
            end)
            hooksecurefunc(header, "Show", function(self)
                if M.db.enabled then
                    self:Hide()
                    self:SetAlpha(0)
                end
            end)
        end
    end

    -- Hook global no ChatEdit_UpdateHeader da Blizzard para garantir insets sempre corretos
    if ChatEdit_UpdateHeader and not M.chatEditHeaderHooked then
        M.chatEditHeaderHooked = true
        hooksecurefunc("ChatEdit_UpdateHeader", function(box)
            if not M.db.enabled or not box then return end
            local h = box.header or (_G[box:GetName() and (box:GetName() .. "Header")])
            if h then
                h:SetText("")
                h:SetAlpha(0)
                h:Hide()
                h:SetWidth(0.001)
            end
            box.azSettingInsets = true
            box:SetTextInsets(8, 32, 0, 0)
            box.azSettingInsets = false
            UpdateInputPillFromEditBox(box)
        end)
    end

    -- Dinâmica de foco e digitação: ao ativar, faz o painel Azaath surgir na hora
    editBox:HookScript("OnEditFocusGained", function(self)
        if container.chrome then
            container.chrome:SetAlpha(M.db.activeAlpha or 0.88)
        end
        self.azSettingInsets = true
        self:SetTextInsets(8, 32, 0, 0)
        self.azSettingInsets = false
        self:SetBackdropBorderColor(0.0, 0.7, 0.95, 0.9)
        self:SetBackdropColor(0.03, 0.04, 0.05, 0.98)
        if self.azTopBorder then self.azTopBorder:Show() end
        if self.azPlaceholder and self:GetText() == "" then
            self.azPlaceholder:Hide()
        end
        UpdateInputPillFromEditBox(self)
    end)

    editBox:HookScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(0.18, 0.23, 0.28, 0.85)
        self:SetBackdropColor(0.04, 0.05, 0.07, 0.96)
        if self.azTopBorder then self.azTopBorder:Hide() end
        if self.azPlaceholder and self:GetText() == "" then
            self.azPlaceholder:Show()
        end
    end)

    editBox:HookScript("OnTextChanged", function(self)
        local txt = self:GetText() or ""
        local len = #txt
        if self.azPlaceholder then
            if len > 0 or self:HasFocus() then
                self.azPlaceholder:Hide()
            else
                self.azPlaceholder:Show()
            end
        end

        if self.azCounter then
            local remaining = max(0, 255 - len)
            self.azCounter:SetText(tostring(remaining > 200 and 200 or remaining))
        end

        UpdateInputPillFromEditBox(self)
    end)

    editBox:HookScript("OnShow", function(self)
        if container.chrome then
            container.chrome:SetAlpha(M.db.activeAlpha or 0.88)
        end
        local h = self.header or (_G[self:GetName() and (self:GetName() .. "Header")])
        if h then
            h:SetText("")
            h:Hide()
            h:SetAlpha(0)
        end
        self.azSettingInsets = true
        self:SetTextInsets(8, 32, 0, 0)
        self.azSettingInsets = false

        local curType = self:GetAttribute("chatType")
        local tellTarget = self:GetAttribute("tellTarget")
        local isWhisper = (curType == "WHISPER" or curType == "BN_WHISPER") and (tellTarget and tellTarget ~= "")

        -- Não sobrescreve se for resposta de sussurro (R, clique em player, etc.) ou se estiver no FEED
        if not isWhisper and M.activeChannel ~= "FEED" then
            M:ApplyChannelToEditBox(self)
        else
            UpdateInputPillFromEditBox(self)
        end
    end)
end

--------------------------------------------------------------------------------
-- Atualização Visual do Scroll
--------------------------------------------------------------------------------
function M:UpdateScrollVisual()
    local container = M.container
    if not container or not container.scrollThumb or not container.scrollTrack then return end

    local chatFrame = (M.activeChannel == "COMBAT" and _G.ChatFrame2) or _G.ChatFrame1
    if not chatFrame then return end

    local numMessages = (chatFrame.GetNumMessages and chatFrame:GetNumMessages()) or 0
    local offset = (chatFrame.GetScrollOffset and chatFrame:GetScrollOffset()) or 0

    local trackH = container.scrollTrack:GetHeight() or 0
    if trackH <= 0 then return end

    if numMessages <= 0 then
        container.scrollThumb:SetHeight(trackH)
        container.scrollThumb:ClearAllPoints()
        container.scrollThumb:SetPoint("TOP", container.scrollTrack, "TOP", 0, 0)
        return
    end

    local h = (chatFrame.GetHeight and chatFrame:GetHeight()) or 200
    local lineH = (M.db.fontSize or 13) + 4
    local visibleLines = math.floor(h / lineH)
    if visibleLines < 1 then visibleLines = 10 end

    local thumbH = max(18, min(trackH, trackH * (visibleLines / max(visibleLines, numMessages))))
    container.scrollThumb:SetHeight(thumbH)

    local maxOffset = max(1, numMessages - visibleLines)
    local progress = min(1, max(0, (maxOffset - offset) / maxOffset))
    local topOffset = -progress * (trackH - thumbH)

    container.scrollThumb:ClearAllPoints()
    container.scrollThumb:SetPoint("TOP", container.scrollTrack, "TOP", 0, topOffset)

    if chatFrame.azScrollBtn and chatFrame.AtBottom then
        if chatFrame:AtBottom() then
            chatFrame.azScrollBtn:Hide()
        else
            chatFrame.azScrollBtn:Show()
        end
    end
end

--------------------------------------------------------------------------------
-- Controle de Canais e Abas
--------------------------------------------------------------------------------
function M:SelectChannel(chanKey, isUserAction)
    if CHANNEL_ALIASES[chanKey] then
        chanKey = CHANNEL_ALIASES[chanKey]
    end
    local info = CHANNEL_INFO[chanKey]
    if not info then return end

    M.activeChannel = chanKey
    if M.db then
        M.db.channelFilter = chanKey
        if isUserAction ~= false then
            M.db.userChangedChannel = true
        end
    end

    local container = M.container
    if not container then return end

    -- Atualiza Cabeçalho
    if container.title then
        container.title:SetText(info.title)
    end

    -- Atualiza Pílula do Canal
    if UpdateInputPillFromEditBox then
        UpdateInputPillFromEditBox()
    end

    -- Move a Pílula de Destaque da Barra Lateral
    local targetBtn = (chanKey == "FEED") and container.feedBtn or (container.chanButtons and container.chanButtons[chanKey])
    if targetBtn and container.activePill then
        container.activePill:ClearAllPoints()
        container.activePill:SetPoint("CENTER", targetBtn, "CENTER", 0, 0)
        container.activePill:Show()

        if targetBtn.unreadDot then
            targetBtn.unreadDot:Hide()
        end
    end

    -- Atualiza cores dos ícones da barra lateral
    if container.feedBtn and container.feedBtn.icon then
        container.feedBtn.icon:SetVertexColor(chanKey == "FEED" and 1 or 0.65, chanKey == "FEED" and 1 or 0.72, chanKey == "FEED" and 1 or 0.80, 1)
    end

    for k, btn in pairs(container.chanButtons or {}) do
        if btn.icon then
            if k == chanKey then
                btn.icon:SetVertexColor(1, 1, 1, 1)
            else
                btn.icon:SetVertexColor(0.60, 0.68, 0.76, 0.85)
            end
        end
    end

    -- Alternância entre ChatFrame1 (Mensagens) e ChatFrame2 (Combat Log)
    local cf1 = _G.ChatFrame1
    local cf2 = _G.ChatFrame2

    local textAlpha = (IsChatActive and IsChatActive()) and 1.0 or (M.db.idleTextAlpha or 0.65)
    if chanKey == "COMBAT" then
        if cf1 then
            cf1:Hide()
            cf1:SetAlpha(0)
            cf1:EnableMouse(false)
        end
        if cf2 then
            AttachChatFrame(cf2)
            cf2:Show()
            cf2:SetAlpha(textAlpha)
            cf2:EnableMouse(true)
            LockChatFramePoints(cf2)
        end
    else
        if cf2 then
            cf2:Hide()
            cf2:SetAlpha(0)
            cf2:EnableMouse(false)
        end
        if cf1 then
            cf1:Show()
            cf1:SetAlpha(textAlpha)
            cf1:EnableMouse(true)
            LockChatFramePoints(cf1)
            -- Recarrega histórico filtrado para o canal alvo
            M:FilterChatMessages(chanKey)
        end
    end

    -- Aplica ao EditBox ativo
    for box in pairs(skinnedEditBoxes) do
        if box:IsShown() then
            M:ApplyChannelToEditBox(box)
        end
    end

    if UpdateInputPillFromEditBox then
        UpdateInputPillFromEditBox()
    end

    M:UpdateScrollVisual()
end

function M:CycleNextChannel()
    local channels = { "FEED", "GERAL", "COMBAT", "SAY", "WHISPER", "GUILD", "PARTY", "RAID", "TRADE", "LFG" }
    local curIdx = 1
    for idx, key in ipairs(channels) do
        if key == M.activeChannel then
            curIdx = idx
            break
        end
    end
    local nextIdx = (curIdx % #channels) + 1
    M:SelectChannel(channels[nextIdx], true)
end

function M:ApplyChannelToEditBox(editBox)
    if not editBox then return end

    -- Se estiver na aba FEED (Todos), preserva o destino atual do jogador (Sussurro, Grupo, Guilda, etc.)
    if M.activeChannel == "FEED" then
        local curType = editBox:GetAttribute("chatType")
        if not curType or curType == "" then
            pcall(editBox.SetAttribute, editBox, "chatType", "SAY")
        end
        if UpdateInputPillFromEditBox then
            UpdateInputPillFromEditBox(editBox)
        end
        return
    end

    local info = CHANNEL_INFO[M.activeChannel]
    if not info then return end

    if info.chatType then
        pcall(editBox.SetAttribute, editBox, "chatType", info.chatType)
        if info.chatTarget then
            pcall(editBox.SetAttribute, editBox, "channelTarget", info.chatTarget)
        end
    elseif info.isCombatLog then
        pcall(editBox.SetAttribute, editBox, "chatType", "SAY")
    end

    if UpdateInputPillFromEditBox then
        UpdateInputPillFromEditBox(editBox)
    end
end

--------------------------------------------------------------------------------
-- Recolher / Expandir o Chat
--------------------------------------------------------------------------------
function M:ToggleCollapse()
    local container = M.container
    if not container then return end

    local activeCf = (M.activeChannel == "COMBAT" and _G.ChatFrame2) or _G.ChatFrame1
    local editBox = _G.ChatFrame1EditBox or (_G.ChatFrame1 and _G.ChatFrame1.editBox)
    M.isCollapsed = not M.isCollapsed
    M.db.collapsed = M.isCollapsed

    if M.isCollapsed then
        container:SetHeight(34)
        if activeCf then
            activeCf:SetAlpha(0)
            activeCf:Hide()
            activeCf:EnableMouse(false)
        end
        if container.sidebar then
            container.sidebar:Hide()
        end
        if container.inputBar then
            container.inputBar:Hide()
        end
        if editBox then
            editBox:SetAlpha(0)
            editBox:Hide()
            editBox:EnableMouse(false)
            if editBox.ClearFocus then editBox:ClearFocus() end
        end
        if container.scrollTrack then
            container.scrollTrack:Hide()
        end
        if container.header then
            container.header:ClearAllPoints()
            container.header:SetPoint("TOPLEFT", container, "TOPLEFT", 0, 0)
            container.header:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", 0, 0)
        end
        if container.collapseBtn and container.collapseBtn.icon then
            container.collapseBtn.icon:SetTexCoord(0, 1, 1, 0) -- inverte seta para baixo (▼)
        end
        if container.chrome then
            container.chrome:SetAlpha(0.40)
        end
    else
        container:SetHeight(M.db.height or 290)
        if container.sidebar then
            container.sidebar:Show()
        end
        if container.header then
            container.header:ClearAllPoints()
            container.header:SetPoint("TOPLEFT", container.sidebar, "TOPRIGHT", 0, 0)
            container.header:SetPoint("TOPRIGHT", container.chrome or container, "TOPRIGHT", 0, 0)
            container.header:SetHeight(32)
        end
        if activeCf then
            activeCf:Show()
            activeCf:SetAlpha((IsChatActive and IsChatActive()) and 1.0 or (M.db.idleTextAlpha or 0.65))
            activeCf:EnableMouse(true)
            LockChatFramePoints(activeCf)
        end
        if container.inputBar then
            container.inputBar:Show()
        end
        if editBox then
            editBox:Show()
            editBox:SetAlpha(1)
            editBox:EnableMouse(true)
            LockEditBoxPoints(editBox)
        end
        if container.scrollTrack then
            container.scrollTrack:Show()
        end
        if container.collapseBtn and container.collapseBtn.icon then
            container.collapseBtn.icon:SetTexCoord(0, 1, 0, 1) -- seta para cima (▲)
        end
        M:UpdateScrollVisual()
    end
end

function M:ApplyLayout()
    local container = M.container
    if not container then return end
    local db = self.db or {}

    local w = db.width or 420
    local h = db.height or 290
    local sc = db.scale or 1
    local x = db.offsetX or 28
    local y = db.offsetY or 48

    if not InCombatLockdown() then
        container:SetScale(sc)
        container:ClearAllPoints()
        container:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
        if not M.isCollapsed then
            container:SetSize(w, h)
        else
            container:SetSize(w, 34)
        end
        if Azaath.ClampToScreen then Azaath.ClampToScreen(container) end
    end

    if _G.ChatFrame1 then LockChatFramePoints(_G.ChatFrame1) end
    if _G.ChatFrame2 then LockChatFramePoints(_G.ChatFrame2) end
    for box in pairs(skinnedEditBoxes) do
        LockEditBoxPoints(box)
    end

    UpdateSidebarButtonsLayout()
    M:UpdateScrollVisual()
end

function M:SetEditing(isEditing)
    if isEditing then
        if M.isCollapsed then
            M:ToggleCollapse()
        end
        if M.container and M.container.chrome then
            M.container.chrome:SetAlpha(1.0)
        end
    end
end

--------------------------------------------------------------------------------
-- Histórico e Filtragem de Mensagens
--------------------------------------------------------------------------------
function M:StoreMessage(rawText, formattedText, chan, r, g, b)
    local history = M.messageHistory
    history[#history + 1] = {
        raw       = rawText,
        formatted = formattedText,
        channel   = chan,
        r = r, g = g, b = b,
    }
    if #history > MAX_HISTORY then
        table.remove(history, 1)
    end

    -- Se a mensagem chegou em outro canal que não o atual, acende o unreadDot
    if chan ~= M.activeChannel and M.activeChannel ~= "FEED" then
        local btn = M.container and M.container.chanButtons and M.container.chanButtons[chan]
        if btn and btn.unreadDot then
            btn.unreadDot:Show()
        end
    end
end

function M:FilterChatMessages(targetChannel)
    local chatFrame = _G.ChatFrame1
    if not chatFrame or not chatFrame.Clear or not chatFrame.azOriginalAddMessage then return end

    chatFrame.azFiltering = true
    chatFrame:Clear()

    for _, entry in ipairs(M.messageHistory) do
        if targetChannel == "FEED" or entry.channel == targetChannel then
            chatFrame.azOriginalAddMessage(chatFrame, entry.formatted, entry.r, entry.g, entry.b)
        end
    end

    chatFrame.azFiltering = false
    chatFrame:ScrollToBottom()
    M:UpdateScrollVisual()
end

--------------------------------------------------------------------------------
-- Hook Seguro no AddMessage do ChatFrame1
--------------------------------------------------------------------------------
local function HookChatFrameAddMessage(chatFrame)
    if not chatFrame or chatFrame.azAddMessageHooked then return end
    chatFrame.azAddMessageHooked = true

    local originalAddMessage = chatFrame.AddMessage
    chatFrame.azOriginalAddMessage = originalAddMessage

    chatFrame.AddMessage = function(self, text, r, g, b, ...)
        if self.azFiltering then
            return originalAddMessage(self, text, r, g, b, ...)
        end

        local formatted, chan = ParseAndFormatMessage(text, r, g, b)
        M:StoreMessage(text, formatted, chan, r, g, b)

        -- Exibe apenas se estiver no canal correspondente ou em FEED
        if M.activeChannel == "FEED" or chan == M.activeChannel then
            local res = originalAddMessage(self, formatted, r, g, b, ...)
            M:UpdateScrollVisual()
            return res
        end
    end
end

--------------------------------------------------------------------------------
-- Rolagem e Botão "▼ RECENTE"
--------------------------------------------------------------------------------
local function CreateScrollBottomButton(frame)
    if not frame or frame.azScrollBtn then return frame and frame.azScrollBtn end

    local c, media = Azaath.colors, Azaath.media
    local btn = CreateFrame("Button", nil, frame)
    btn:SetWidth(86)
    btn:SetHeight(20)
    btn:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, 4)
    btn:SetFrameLevel(frame:GetFrameLevel() + 5)

    Azaath.SetBackdrop(btn, {
        bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    btn:SetBackdropColor(0.06, 0.08, 0.10, 0.95)
    btn:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.85)

    local label = btn:CreateFontString(nil, "OVERLAY")
    label:SetFont(media.fontTitleB, 9, "")
    label:SetTextColor(c.accent[1], c.accent[2], c.accent[3], 1.0)
    label:SetPoint("CENTER", btn, "CENTER", 0, 0)
    label:SetText("▼ RECENTE")
    btn.label = label

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 0.95, 0.6, 1)
        self.label:SetTextColor(1, 1, 1, 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.85)
        self.label:SetTextColor(c.accent[1], c.accent[2], c.accent[3], 1.0)
    end)
    btn:SetScript("OnClick", function()
        frame:ScrollToBottom()
        btn:Hide()
        M:UpdateScrollVisual()
    end)

    btn:Hide()
    frame.azScrollBtn = btn
    return btn
end

local function OnChatMouseWheel(self, delta)
    if delta > 0 then
        if IsShiftKeyDown() then
            self:ScrollToTop()
        elseif IsControlKeyDown() then
            self:PageUp()
        else
            self:ScrollUp()
            self:ScrollUp()
            self:ScrollUp()
        end
    elseif delta < 0 then
        if IsShiftKeyDown() then
            self:ScrollToBottom()
        elseif IsControlKeyDown() then
            self:PageDown()
        else
            self:ScrollDown()
            self:ScrollDown()
            self:ScrollDown()
        end
    end

    M:UpdateScrollVisual()
end

--------------------------------------------------------------------------------
-- Ciclo de Atualização e Fading Suave (Fundo 100% invisível em repouso)
--------------------------------------------------------------------------------
local fadeDriver
local FADE_OUT_DELAY = 0.5 -- tempo em segundos antes de iniciar o esmaecimento ao tirar o mouse
local fadeOutTimer = 0

local function InitFadeDriver()
    if fadeDriver then return end
    fadeDriver = CreateFrame("Frame")
    fadeDriver:SetScript("OnUpdate", function(_, elapsed)
        local container = M.container
        if not container or not container:IsShown() then return end
        local chrome = container.chrome
        if not chrome then return end

        local isOver = IsChatActive()
        local targetAlpha
        local targetTextAlpha

        if isOver then
            fadeOutTimer = FADE_OUT_DELAY
            targetAlpha = M.db.activeAlpha or 0.88
            targetTextAlpha = 1.0
        else
            if fadeOutTimer > 0 then
                fadeOutTimer = fadeOutTimer - elapsed
                targetAlpha = M.db.activeAlpha or 0.88
                targetTextAlpha = 1.0
            else
                targetAlpha = (M.isCollapsed and 0.40) or (M.db.idleAlpha or 0.0)
                targetTextAlpha = (M.isCollapsed and 0.0) or (M.db.idleTextAlpha or 0.65)
            end
        end

        local cur = chrome:GetAlpha()

        if math.abs(cur - targetAlpha) > 0.005 then
            local speed = isOver and 0.35 or 0.12
            local nextAlpha = cur + (targetAlpha - cur) * speed
            if math.abs(nextAlpha - targetAlpha) < 0.015 then
                nextAlpha = targetAlpha
            end
            chrome:SetAlpha(nextAlpha)
            cur = nextAlpha
        end

        -- Transição suave da opacidade do texto das mensagens
        local activeCf = (M.activeChannel == "COMBAT" and _G.ChatFrame2) or _G.ChatFrame1
        if activeCf and not M.isCollapsed then
            local curTextAlpha = activeCf:GetAlpha()
            if math.abs(curTextAlpha - targetTextAlpha) > 0.005 then
                local textSpeed = isOver and 0.35 or 0.12
                local nextTextAlpha = curTextAlpha + (targetTextAlpha - curTextAlpha) * textSpeed
                if math.abs(nextTextAlpha - targetTextAlpha) < 0.015 then
                    nextTextAlpha = targetTextAlpha
                end
                activeCf:SetAlpha(nextTextAlpha)
            end
        end

        -- Controle de captura de mouse: quando invisível, libera cliques ao mundo
        if cur > 0.05 then
            if not chrome.azMouseEnabled then
                chrome.azMouseEnabled = true
                chrome:EnableMouse(true)
            end
        else
            if chrome.azMouseEnabled then
                chrome.azMouseEnabled = false
                chrome:EnableMouse(false)
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- Ciclo de Vida do Módulo
--------------------------------------------------------------------------------
function M:OnInitialize()
    self.db = Azaath.db.chat or {}
    -- Força idleAlpha para 0.0 para garantir fundo invisível em repouso
    self.db.idleAlpha = 0.0
    if self.db.idleTextAlpha == nil then
        self.db.idleTextAlpha = 0.65
    end
    -- FEED como chat principal por padrão, a menos que o usuário tenha alterado manualmente
    if not self.db.userChangedChannel or not self.db.channelFilter then
        self.db.channelFilter = "FEED"
    end
end

function M:RefreshStyle()
    if _G.ChatFrame1 then
        ApplyChatFont(_G.ChatFrame1)
    end
    if _G.ChatFrame2 then
        ApplyChatFont(_G.ChatFrame2)
    end
    for box in pairs(skinnedEditBoxes) do
        ApplyEditBoxFont(box)
    end
    if self.container and self.container.chrome then
        self.container.chrome:SetBackdropColor(0.04, 0.05, 0.07, self.db.activeAlpha or 0.88)
    end
    self:ApplyLayout()
end

function M:Build()
    if not self.db.enabled then return end

    HideChatClutter()

    CreateAzaathChatUI()
    local chatFrame = _G.ChatFrame1
    local combatFrame = _G.ChatFrame2

    if chatFrame then
        AttachChatFrame(chatFrame)
        HookChatFrameAddMessage(chatFrame)
        CreateScrollBottomButton(chatFrame)
        chatFrame:SetScript("OnMouseWheel", OnChatMouseWheel)
    end

    if combatFrame then
        AttachChatFrame(combatFrame)
        CreateScrollBottomButton(combatFrame)
        combatFrame:SetScript("OnMouseWheel", OnChatMouseWheel)
    end

    local editBox = _G.ChatFrame1EditBox or (chatFrame and chatFrame.editBox)
    if editBox then
        SetupEditBox(editBox)
    end

    local initialChannel = self.db.channelFilter or "FEED"
    if CHANNEL_ALIASES[initialChannel] then
        initialChannel = CHANNEL_ALIASES[initialChannel]
    end
    M:SelectChannel(initialChannel, false)
    M:ApplyLayout()
    if self.db.collapsed then
        M.isCollapsed = false
        M:ToggleCollapse()
    end

    if FCFDock_UpdateTabs and not M.dockHooked then
        M.dockHooked = true
        hooksecurefunc("FCFDock_UpdateTabs", function()
            if M.db.enabled then NeutralizeBlizzardChat() end
        end)
    end
    if FCF_DockUpdate and not M.fcfDockHooked then
        M.fcfDockHooked = true
        hooksecurefunc("FCF_DockUpdate", function()
            if M.db.enabled then
                if _G.ChatFrame1 then LockChatFramePoints(_G.ChatFrame1) end
                if _G.ChatFrame2 then LockChatFramePoints(_G.ChatFrame2) end
                NeutralizeBlizzardChat()
            end
        end)
    end
    if FCF_RestorePositionAndDimensions and not M.fcfRestoreHooked then
        M.fcfRestoreHooked = true
        hooksecurefunc("FCF_RestorePositionAndDimensions", function(cf)
            if M.db.enabled then
                if not cf or cf == _G.ChatFrame1 or cf == _G.ChatFrame2 then
                    if _G.ChatFrame1 then LockChatFramePoints(_G.ChatFrame1) end
                    if _G.ChatFrame2 then LockChatFramePoints(_G.ChatFrame2) end
                    NeutralizeBlizzardChat()
                end
            end
        end)
    end
    if FCF_SetChatWindowFontSize and not M.fcfFontHooked then
        M.fcfFontHooked = true
        hooksecurefunc("FCF_SetChatWindowFontSize", function(cf)
            if M.db.enabled and (cf == _G.ChatFrame1 or cf == _G.ChatFrame2) then
                LockChatFramePoints(cf)
            end
        end)
    end
    if FCF_OpenTemporaryWindow and not M.tempHooked then
        M.tempHooked = true
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            if M.db.enabled then NeutralizeBlizzardChat() end
        end)
    end

    if not M.eventWatcher then
        local watcher = CreateFrame("Frame")
        watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
        watcher:RegisterEvent("UPDATE_CHAT_WINDOWS")
        watcher:RegisterEvent("VARIABLES_LOADED")
        watcher:RegisterEvent("UI_SCALE_CHANGED")
        watcher:SetScript("OnEvent", function()
            if M.db and M.db.enabled then
                if _G.ChatFrame1 then LockChatFramePoints(_G.ChatFrame1) end
                if _G.ChatFrame2 then LockChatFramePoints(_G.ChatFrame2) end
                NeutralizeBlizzardChat()
                if C_Timer and C_Timer.After then
                    C_Timer.After(0.1, function()
                        if _G.ChatFrame1 then LockChatFramePoints(_G.ChatFrame1) end
                        if _G.ChatFrame2 then LockChatFramePoints(_G.ChatFrame2) end
                        NeutralizeBlizzardChat()
                    end)
                    C_Timer.After(0.5, function()
                        if _G.ChatFrame1 then LockChatFramePoints(_G.ChatFrame1) end
                        if _G.ChatFrame2 then LockChatFramePoints(_G.ChatFrame2) end
                        NeutralizeBlizzardChat()
                    end)
                end
            end
        end)
        M.eventWatcher = watcher
    end

    InitFadeDriver()
end

function M:OnEnable()
    if not self.db.enabled then return end
    Azaath:RunOutOfCombat(function()
        self:Build()
    end)
end
