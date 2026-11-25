--[[----------------------------------------------------------------------------
    AzaathUI - Core.lua
    Cliente alvo: World of Warcraft 3.3.5a (Interface 30300)

    Responsabilidades:
      * Namespace privado do addon (compartilhado entre todos os arquivos via "...")
      * SavedVariables (AzaathUIDB) com merge de valores padrão
      * Sistema simples de módulos (OnInitialize -> ADDON_LOADED, OnEnable -> PLAYER_LOGIN)
      * Fila de ações fora de combate (evita ADDON_ACTION_BLOCKED em frames protegidos)
      * Frame raiz (todos os elementos da Azaath são filhos dele) e frame "hider"
      * Comandos de barra: /azaath
------------------------------------------------------------------------------]]

local ADDON_NAME, Azaath = ...
_G.AzaathUI = Azaath -- exposto globalmente apenas para depuração (/dump AzaathUI)

local _G = _G
local type, pairs, ipairs, pcall, tostring, select = type, pairs, ipairs, pcall, tostring, select
local tinsert, wipe = table.insert, wipe
local InCombatLockdown = InCombatLockdown

Azaath.version = Azaath.API.GetAddOnMetadata(ADDON_NAME, "Version") or "dev"

--------------------------------------------------------------------------------
-- Valores padrão (mesclados no AzaathUIDB sem sobrescrever o que o jogador já salvou)
--------------------------------------------------------------------------------
Azaath.defaults = {
    enabled = true, -- visibilidade da camada Azaath (/azaath toggle)
    scale   = 1,    -- escala geral de todos os elementos Azaath
    skin    = "modern", -- skin da Azaath UI (barra de tarefas + frame do personagem): "modern", "azaath", "bdo" ou "blizzard"

    -- Painel de configuração (/azaath): idioma ("auto" segue o cliente, "ptBR", "enUS"),
    -- tamanho da janela e última aba aberta
    config = {
        lang  = "auto",
        scale = 1,
        page  = "general",
    },

    -- Skin BDO: quadro do jogador no estilo Black Desert Online (canto superior esquerdo)
    bdo = {
        scale   = 1,
        offsetX = 8,  -- distância da borda esquerda da tela
        offsetY = 6,  -- distância do topo da tela
    },

    -- Skin Azaath: HUD única (painéis de ação + vida/recurso/XP + medalhão)
    -- recortada da arte de conceito (Modules/AzaathHUD.lua, tools/actionbar-concept)
    azaath = {
        scale   = 1,
        offsetX = 0,
        offsetY = 10,   -- distância da base da tela
        page    = 1,    -- aba ativa do painel esquerdo: 1 = barra 2 (CF1), 2 = barra 3 (CF2)
        glow    = true, -- gemas e filetes ciano pulsando
    },

    hideBlizzard = {
        actionBars  = true, -- MainMenuBar (+ XP/rep e barras inferiores)
        playerFrame = true,
        targetFrame = true,
        minimap     = true, -- MinimapCluster (indicadores de fila/correio são preservados)
        buffs       = true, -- BuffFrame / TemporaryEnchantFrame
        questTracker = true, -- WatchFrame (substituído pelo módulo QuestTracker)
        partyFrames  = true, -- PartyMemberFrame1-4 (substituídos pelo módulo PartyFrames)
    },

    compass = {
        enabled     = true,
        width       = 640,
        height      = 34,
        offsetX     = 0,     -- deslocamento horizontal a partir do centro
        offsetY     = -10,   -- distância do topo da tela
        scale       = 1,
        fov         = 180,   -- graus visíveis de ponta a ponta da bússola
        interval    = 0.04,  -- throttle do OnUpdate (limitado entre 0.03 e 0.05)
        showDegrees = false, -- rumo numérico abaixo da placa (o Azaath não mostra)
        showZone    = true,  -- placa dourada com o nome da subzona
    },

    unitframes = {
        -- Jogador: barra larga de vida no centro inferior (estilo Azaath).
        player = {
            enabled         = true,
            width           = 320,
            healthHeight    = 20,
            powerHeight     = 7,   -- HUD Azaath: recurso fino segmentado encostado na vida
            healthFont      = 13,
            powerFont       = 0,   -- 0 = sem texto
            fadeOutOfCombat = false, -- barra de vida transparente fora de combate (ignorado na HUD Azaath)
            scale           = 1,
            offsetX         = 0,
            offsetY         = 100, -- distância da base da tela (losango de nível/XP e debuffs ficam embaixo)
        },
        -- Alvo: centro superior, abaixo da bússola (estilo aliado Azaath).
        target = {
            enabled      = true,
            width        = 300,
            healthHeight = 14,
            powerHeight  = 4,
            healthFont   = 11,
            powerFont    = 0,
            nameFont     = 14,
            scale        = 1,
            offsetX      = 0,
            offsetY      = -78, -- distância do topo da tela
        },
    },

    -- Placas de nome dos inimigos (sobre a cabeça) no estilo Azaath:
    -- nome espaçado, barra fina, losango do nível, moldura de combate,
    -- asas de prata/ouro nas elites e efeitos (buffs/debuffs) acima do nome.
    nameplates = {
        enabled      = true,
        -- visual das placas de inimigo: "auto" (Zerker = minimalista, demais = Azaath),
        -- "azaath" (pincel e tinta), "zerker" (paralelogramo) ou "minimal" (estilo BDO)
        style         = "auto",
        castBar       = true, -- barra de conjuração tática nos inimigos
        width         = 110,  -- discreta: ~70% da barra do Azaath (155 x 10 px em 1080p)
        healthHeight  = 6,
        nameFont      = 15,   -- escala com a largura: ~11 px na barra de 110
        auraSize      = 12,   -- ícones pequenos de efeitos acima do nome
        maxDebuffs    = 8,    -- debuffs de qualquer origem (seus e dos aliados)
        maxBuffs      = 4,
        selectedScale = 0.85, -- inimigo selecionado: o jogo aumenta a placa; compensa
        allies        = true, -- jogadores aliados: losango do nível + nome; barra branca em combate
        friendlyClickable = true, -- permite selecionar aliados clicando na placa (desativa click-through)
        allyBarWidth  = 104,  -- barra do aliado no Azaath: 106 x 3 px em 1080p
        allyNameFont  = 14,
        allyNameMaxW  = 185,  -- largura máx. para o nome todo caber (só corta se super comprido)
        allyOffsetY   = -8,   -- aproxima levemente a placa da cabeça do aliado
        pets          = true, -- pets amigos: placa de aliado em tamanho menor
        petScale      = 0.72,
        utilityNPCs   = true, -- placas para NPCs utilitários (leilão, conserto, venda, estalagem, quests)
        hideWorldNames = true, -- some com o nome padrão do WoW de aliados/pets fora do alcance das placas
    },

    actionbars = {
        enabled       = true,  -- exige hideBlizzard.actionBars = true
        layout        = "az",  -- "az" = Opção 1 (HUD Azaath: barra 1 à direita, barra 2 à esquerda da vida) · "split" = Opção 2 (duas barras 6x2 na base, uma de cada lado da vida)
        bars          = 3,     -- 1 = principal, 2 = + inferior esquerda, 3 = + inferior direita
        buttonSize    = 46,    -- barra principal
        smallSize     = 36,    -- barras secundárias (2 e 3) no layout "az"
        spacing       = 6,
        scale         = 1,
        offsetX       = -28,   -- layout "az": distância da borda direita
        offsetY       = 34,    -- distância da base da tela
        showHotkeys   = true,
        bagButton     = true,  -- botão redondo de inventário (layout "az")
        rangeInterval = 0.2,   -- throttle da checagem de alcance

        bar1 = { scale = 1, offsetX = 0, offsetY = 0, cols = 0, buttonSize = 0, customPos = false },
        bar2 = { scale = 1, offsetX = 0, offsetY = 0, cols = 0, buttonSize = 0, customPos = false },
        bar3 = { scale = 1, offsetX = 0, offsetY = 0, cols = 0, buttonSize = 0, customPos = false },
        bag  = { scale = 1, size = 42, offsetX = -24, offsetY = 30 },

        -- Postura/forma/aura/presença: alinhada à esquerda, acima da barra superior.
        stance = { enabled = true, buttonSize = 28, spacing = 3, scale = 1, offsetX = 0, offsetY = 0, customPos = false },
        -- Pet: alinhada à direita, acima da barra superior.
        -- Assistente de rotação (Modules/RotationAssist.lua; só Guerreiro por enquanto)
        rotation = { enabled = true, sound = true, shout = true, castSounds = true, castSfx = true, volume = 1 },
        pet    = { enabled = true, buttonSize = 28, spacing = 3, scale = 1, offsetX = 0, offsetY = 0, customPos = false },
    },

    castbar = {
        -- Jogador: acima das barras de vida/recurso (ancorada no frame do jogador).
        player = {
            enabled     = true,
            width       = 300,
            height      = 14,
            scale       = 1,
            offsetX     = 0,
            offsetY     = 18,   -- distância acima do frame do jogador
            customPos   = false,
            showLatency = true, -- "zona segura" vermelha no fim da barra (só no estilo barra)
            style       = "ring", -- "ring" = espiral do Azaath · "bar" = barra horizontal
            ringSize    = 56,     -- diâmetro do anel (estilo espiral moderno; era 72)
            effects     = true,   -- efeitos por escola de magia (luz, fogo, gelo...)
        },
        -- Interação com o mundo (baús, minérios, ervas, objetos de missão):
        -- anel em espiral em cima do objeto, no lugar da barra do jogador.
        world = {
            enabled   = true,
            size      = 54,     -- anel moderno, discreto (era 64 no visual clássico)
            fallbackX = 0,      -- sem cursor sobre o objeto: posição em relação
            fallbackY = -20,    -- ao centro da tela
            plateOffsetY = -45, -- placa fica acima do objeto; valor negativo desce o anel ao centro do item
        },
        -- Alvo: logo abaixo do frame do alvo, com a mesma largura dele.
        target = {
            enabled   = true,
            width     = 300,
            height    = 12,
            scale     = 1,
            offsetX   = 0,
            offsetY   = -8,     -- distância abaixo do frame do alvo
            customPos = false,
        },
    },

    minimap = {
        enabled    = true,    -- exige hideBlizzard.minimap = true
        size       = 170,
        scale      = 1,
        shape      = "square", -- "round" ou "square" (padrão quadrado)
        offsetX    = -24,     -- a partir do canto superior direito
        offsetY    = -24,
        showCoords = true,
        showClock  = true,
    },

    auras = {
        -- Buffs do jogador: grade no canto superior direito (exige hideBlizzard.buffs).
        playerBuffs = {
            enabled = true, size = 24, spacing = 6, perRow = 10, max = 40,
            scale = 1, offsetX = -12, offsetY = -52, customPos = false, weaponEnchants = true,
        },
        -- Debuffs do jogador: linha centralizada acima da barra de conjuração.
        playerDebuffs = {
            enabled = true, size = 28, spacing = 4, perRow = 10, max = 16,
            scale = 1, offsetX = 0, offsetY = 18, customPos = false,
        },
        -- Alvo: debuffs e depois buffs, abaixo do frame do alvo.
        target = {
            enabled = true, size = 22, spacing = 3, perRow = 11, max = 22,
            scale = 1, offsetX = 0, offsetY = -26, customPos = false,
            onlyMine = false, -- true = mostra só os debuffs aplicados por você
        },
    },

    party = {
        enabled    = true,
        width      = 150,
        barHeight  = 5,
        spacing    = 40,    -- distância vertical entre membros
        scale      = 1,
        offsetX    = 16,    -- a partir do canto superior esquerdo
        offsetY    = -140,
        classColor = false, -- barra de vida na cor da classe (padrão: azul Azaath)
        showInRaid = false, -- em raide os quadros de grupo somem
    },

    questnav = {
        enabled     = true, -- navegação 3D nativa (C_Navigation / C_SuperTrack)
        worldMarker = true, -- marcador 3D no estilo Azaath com distância e Dentro/Fora/Acima
        compassPin  = true, -- pino da missão em foco na bússola
        magicPath   = true, -- caminho mágico (rota caminhável contornando obstáculos)
    },

    questroute = {
        enabled     = true, -- guia dinâmico passo a passo (pegar -> fazer -> entregar)
        autoAdvance = true, -- avança automaticamente ao concluir/entregar
        autoQuest   = false, -- aceitar e entregar missões automaticamente ao falar com NPC
        mode        = "loremaster", -- "none" (Livre) | "loremaster" | "tryhard"
    },

    questtracker = {
        enabled          = true,
        width            = 270,
        maxHeight        = 300,  -- missões que não cabem viram "+N missões"
        scale            = 1,
        offsetX          = -8,
        offsetY          = -140, -- abaixo dos buffs (com o minimapa Azaath) ou do topo
        customPos        = false,
        showAchievements = true, -- conquistas acompanhadas, depois das missões
        collapsed        = false,
        transparentBg    = false,
    },

    dialog = {
        enabled    = true,  -- janela própria para conversa com NPC e missões
        numberKeys = true,  -- teclas 1-9 escolhem as opções enquanto a janela está aberta
        interactKey = true, -- tecla F (atalho principal da Azaath) escolhe a primeira opção
        width      = 500,   -- painel Azaath: 698x800 px de referência em 1080p
        scale      = 1,
        offsetX    = -57,   -- a partir da borda direita
        offsetY    = -12,   -- a partir do centro vertical
    },

    npcCamera = {
        enabled            = true,  -- câmera cinemática nativa (estilo Immersion) ao interagir com NPCs
        questAndGossip     = true,  -- ativa em diálogos e missões (Gossip / Quest)
        otherNPCs          = true,  -- ativa em mercadores, treinadores, banco, leilão, estábulo, voo
        zoomDistance       = 4.5,   -- distância alvo da câmera em jardas
        shoulderOffset     = 1.25,  -- deslocamento lateral para enquadrar NPC à esquerda do painel
        focusStrength      = 0.80,  -- força de foco no NPC (Pitch/Yaw)
        dynamicPitch       = true,  -- inclinação dinâmica suave durante a conversa
        fovZoom            = true,  -- aproxima levemente o campo de visão (cameraFov)
        fovTarget          = 78,    -- FOV alvo durante a conversa
        subtlePan          = false, -- leve movimento panorâmico contínuo
        vignette           = true,  -- vinheta cinematográfica nas bordas da tela
        disableInCombat    = true,  -- não ativa em combate e restaura ao entrar em combate
        disableInInstances = false, -- desativa dentro de masmorras/raides
    },

    merchant = {
        enabled     = true,   -- janela própria de mercador (comprar, recomprar, consertar)
        autoRepair  = false,  -- consertar tudo ao abrir um mercador que conserta
        guildRepair = true,   -- o conserto automático usa o banco da guilda quando ele cobre
        scale       = 1,
    },

    auction = {
        autoScan  = true,     -- varredura completa automática ao abrir o leilão (1 a cada 15 min)
        cardPrice = true,     -- preço do leilão no card de item
    },

    inventory = {
        enabled       = true,  -- janela única para as bolsas 0-4 (o banco continua Blizzard)
        style         = "classic", -- "classic" (padrão) ou "azaath" (moldura do conceito, InventorySkin.lua)
        viewMode      = "az",  -- "az" (categorias estilo Azaath) ou "bags" (bolsas separadas)
        columns       = 8,     -- total: metade por coluna de seções (2 colunas, como no Azaath)
        buttonSize    = 36,    -- (antigo; o layout Azaath usa slotSize)
        slotSize      = 44,    -- tamanho dos espaços de item no painel Azaath
        sort          = "recent", -- "recent" (relógio), "rarity" (estrela), "level" (triângulo)
        collapsed     = {},    -- seções recolhidas pela seta do título
        maxHeight     = 600,   -- acima disso, rola com a roda do mouse
        showItemLevel = true,  -- nível do item no canto (armas e equipamentos)
        unified       = true,  -- abre junto com o personagem (estilo Azaath)
        openMode      = "camera", -- "camera" (personagem no mundo), "panel" (painel Equipado ao lado) ou "bags"
        equipHidden   = false, -- painel Equipado recolhido pela aba ao lado da mochila (fica salvo)
        keepOnMove    = true,  -- andar não fecha as bolsas (só o personagem, para soltar a câmera)
        cameraLock    = true,  -- gira e aproxima a câmera de frente para o personagem
        cameraDistance = 3.7,  -- distância da câmera (jardas) com o personagem aberto
        pos           = nil,   -- posição salva ao arrastar o cabeçalho (fora do personagem)
    },

    loot = {
        enabled = true,  -- janela de saque (loot) elegante no estilo Azaath
        width   = 320,
        scale   = 1,
        offsetX = 180,
        offsetY = 20,
        autoLoot     = true,  -- pega tudo na hora, sem janela (Shift inverte)
        showWhenFull = true,  -- no automático, abre a janela se sobrar item (inventário cheio)
        feed         = true,  -- notificações "+1 Madeira Verde" do que você recebeu
        feedDuration = 5,     -- segundos na tela
        feedMax      = 6,     -- linhas ao mesmo tempo
        feedScale    = 1,
        feedX        = 330,   -- a partir do centro da tela
        feedY        = -60,
    },

    lootRolls = {
        enabled = true,  -- painel de rolagens do grupo (Necessidade/Ganância, números, vencedor)
        pos     = nil,   -- posição salva ao arrastar o cabeçalho
    },

    lootBeam = {
        enabled        = true,  -- facho de luz sobre corpos com saque (estilo Azaath)
        showOnUnopened = true,  -- mostrar luz sob o corpo antes de abrir se houver drop
        rarityBurst    = true,  -- explosão de luz na cor da maior raridade (Verde/Azul/Roxo/Laranja)
        persistRarity  = true,  -- manter o facho na cor da raridade enquanto sobrar item no corpo
        beamHeight     = 180,   -- altura do feixe vertical
        beamWidth      = 75,    -- largura do anel no chão
        offsetY        = 0,     -- ajuste fino de altura (px) depois da descida automática
        groundFactor   = 100,   -- % da altura do mob usada para descer o facho até o pé
        multiCorpse    = true,  -- manter o facho nos corpos já vistos (vários ao mesmo tempo)
        duration       = 2.6,   -- duração da explosão de luz
    },

    lootCelebration = {
        enabled       = true,     -- popups chamativos no estilo Azaath ao obter saques raros/marcos
        sound         = true,     -- fanfarra sonora por tipo de conquista
        edgeGlow      = true,     -- brilho suave nas bordas da tela
        glowIntensity = "normal", -- "normal" ou "soft"
        borderPulse   = true,     -- pulso luminoso percorrendo a moldura do card
        greenBoE      = true,     -- celebrar equipamentos verdes BoE saqueados
        quietFishing  = true,     -- aviso discreto para poções pescadas
        milestones    = true,     -- marcos de profissão (75, 150, 225, 300)
        rareKills     = true,     -- celebrar inimigos raros abatidos (com retrato 3D)
        showVendor    = true,     -- mostrar valor de venda em NPC
        showAH        = true,     -- mostrar valor estimado do Auctionator (se instalado)
        movableAlerts = true,     -- permitir arrastar um alerta ativo temporariamente
        durationScale = 1.0,      -- multiplicador de duração (0.5x a 2.0x)
        scale         = 1.0,      -- escala do card de celebração
        offsetX       = 0,        -- deslocamento horizontal a partir do centro
        offsetY       = 210,      -- deslocamento vertical a partir do centro
        watch         = {},       -- itemIDs customizados para vigiar
        ignore        = {},       -- itemIDs silenciados
        durations     = {},       -- durações customizadas por categoria
    },

    chat = {
        enabled       = true,  -- chat minimalista e imersivo no estilo Azaath
        backdrop      = true,  -- painel escuro Azaath com borda e filete
        channelFilter = "FEED", -- canal selecionado inicialmente (Feed por padrão)
        cleanTabs     = true,  -- barra lateral Azaath com ícones dedicados
        cleanEditBox  = true,  -- barra de digitação estilizada com pílula de canal e contador
        hideButtons   = true,  -- oculta botões poluídos (menu, canal de voz, amigos rápidos)
        mouseScroll   = true,  -- rolagem com a roda do mouse e botão de retorno
        activeAlpha   = 0.88,  -- opacidade ao passar o mouse ou digitar
        idleAlpha     = 0.0,   -- opacidade em repouso (fundo invisível estilo Azaath)
        idleTextAlpha = 0.65,  -- opacidade do texto em repouso (levemente transparente)
        fontStyle     = "ptsans",  -- "ptsans" (fonte oficial UI/chat Azaath), "bold", ou "imfell"
        fontSize      = 13,        -- tamanho da fonte
        fontOutline   = "OUTLINE", -- contorno nítido Azaath
        width         = 420,
        height        = 290,
        offsetX       = 28,
        offsetY       = 48,
        scale         = 1,
        collapsed     = false,
    },

    sheet = {
        enabled = true,        -- ficha completa Azaath; a tecla "Personagem" (C) passa a abri-la
        tab     = "character", -- última aba aberta
        sub     = "attributes", -- sub-aba do Personagem (atributos, conjuntos, títulos)
        pos     = nil,         -- posição salva ao arrastar o cabeçalho
    },

    talents = {
        enabled = true,  -- janela de talentos Azaath; a tecla de Talentos passa a abri-la
        pos     = nil,
    },

    professions = {
        enabled   = true, -- aba Ofícios (K / janelas de profissão)
        favorites = {},   -- receitas favoritadas
        cache     = {},   -- cache de receitas por personagem
    },

    character = {
        enabled = true,  -- equipamento ao redor do personagem; abre com a mochila (B)
        hideHUD = true,  -- esconde o HUD da Azaath enquanto o personagem está aberto
        scale   = 1,     -- escala dos espaços de equipamento (além do ajuste à tela)
        offsetX = 0,     -- deslocamento do conjunto em relação ao centro da tela
        offsetY = 0,
    },

    spellbook = {
        enabled = true,  -- livro Azaath; a tecla do livro de feitiços (P) passa a abri-lo
        pos     = nil,   -- posição salva ao arrastar o cabeçalho
    },

    skins = {
        tooltips = true,    -- tooltips no painel Azaath + borda na cor da raridade
        popups   = true,    -- caixas de confirmação e menus suspensos
        itemCard       = true,  -- card de item no estilo New World no lugar da tooltip
        itemCardSparks = true,  -- fagulhas no cabeçalho (quantidade pela raridade)
        itemCardScale  = 1,
    },

    experience = {
        enabled    = true,
        showBadge  = true,  -- exibe o selo de nível em losango
        showAtMax  = false, -- mantém a barra visível no nível máximo
        width      = 0,     -- 0 = largura automática na base da tela; > 0 = largura fixa (px)
        height     = 5,     -- altura da barra de XP segmentada (px)
        segments   = 20,    -- quantidade de divisórias (1 a 40)
        scale      = 1,     -- escala da barra de XP
        offsetX    = 0,     -- deslocamento horizontal da barra (px)
        offsetY    = 6,     -- distância da base da tela (px)
        badgeSize  = 34,    -- tamanho do losango de nível (px)
        badgeScale = 1,     -- escala do losango de nível
        badgeX     = 12,    -- distância esquerda do losango (px)
        badgeY     = 4,     -- distância inferior do losango (px)
    },

    micromenu = {
        enabled    = true,
        style      = "bdo", -- "bdo" (minimalista), "azaath" (arcano), "numenor" (forja/astrolábio), "tabletop" (mesa de RPG / WoW)
        buttonSize = 26,
        spacing    = 5,
        scale      = 1,
        anchor     = "BOTTOMRIGHT",
        offsetX    = -16,
        offsetY    = 14,
        idleAlpha  = 0.80, -- opacidade discreta em repouso (1.0 ao passar o mouse)
        collapsed  = false,
    },

    worldmap = {
        enabled        = true,  -- mapa-múndi próprio do Azaath (tecla do mapa); desligado, abre o da Blizzard
        showUnexplored = true,  -- mostra as áreas ainda não exploradas (escurecidas)
        revealAll      = false, -- mostra as não exploradas coloridas, como se estivessem exploradas
        terrain        = true,  -- visão de terreno (imagens do minimapa) no lugar da arte pintada
        showNames      = true,  -- nomes das zonas e sub-regiões na visão de terreno
        maximized      = false, -- mapa em tela cheia (botão da barra superior / dois cliques nela)
        questCollapsed = {},    -- [zona] = true: grupo recolhido na lista de missões do mapa
        poiTaxi        = true,  -- mestres de voo no mapa (o seu lado e os neutros)
        taxiMap        = true,  -- falar com o mestre de voo abre este mapa no lugar do da Blizzard (Modules/MapTaxi.lua)
        poiDungeons    = true,  -- entradas de masmorras e raides
        poiQuests      = true,  -- missões do diário (de perto)
        questAreas     = true,  -- áreas das missões (onde ficam os objetivos), em dourado
        interiors      = "auto", -- interiores: "auto" (subterrâneos: cidades, cavernas, minas + a construção onde você está), "all", "off"
        poiGroup       = true,  -- membros do grupo/raide
        gatherHerb     = true,  -- pinos de ervas no mapa (Modules/MapGather.lua)
        gatherOre      = true,  -- pinos de minérios no mapa
        gatherOnlyKnown = false, -- só o que a sua profissão já colhe
        gatherLite     = true,  -- usar também os pontos do GatherLite, se ele estiver ligado
        gatherHide     = {},    -- [nome do nó] = true: tipo escondido no filtro
    },

    combattext = {
        enabled       = true,        -- dano flutuante no estilo Azaath
        fontStyle     = "cinzel",    -- "cinzel" (fonte oficial Azaath), "imfell", "ptsans"
        normalSize    = 28,          -- tamanho do dano normal (ampliado, nítido e legível)
        critSize      = 40,          -- tamanho do dano crítico (laranja, grande e imponente)
        offsetX       = 68,          -- deslocamento horizontal à direita do alvo (estilo Azaath)
        duration      = 1.15,        -- duração total da animação em segundos
        floatDistance = 48,          -- distância vertical que o número sobe (pixels)
        showIcons     = true,        -- ícone do tipo de dano (corte, perfuração, etc.)
        iconSize      = 26,          -- tamanho do ícone no dano normal
        critIconSize  = 38,          -- tamanho do ícone no dano crítico
        onlyMine      = true,        -- esconde o dano que aliados causam no seu alvo
        showPet       = true,        -- exibe dano causado pelo pet do jogador
        showPeriodic  = true,        -- exibe dano periódico (DoTs)
        showMiss      = true,        -- exibe erros (Esquiva, Apara, etc.)
        hideBlizzard  = true,        -- desativa o texto nativo da Blizzard
        scale         = 1,           -- escala geral do texto flutuante
    },

    actioncam = {
        enabled                    = true,   -- ativa o sistema de Câmera Action / Mouse Look nativo
        -- Mouse Look & Câmera
        mouseLookSpeed             = 100,    -- velocidade de giro da câmera (20-200)
        minCameraZoom              = 3,      -- zoom mínimo em jardas (0 = desligado)
        shoulderOffset             = 1.2,    -- deslocamento lateral da câmera (test_cameraOverShoulder)
        shoulderFollowsMouseLook   = false,  -- suaviza o ombro junto com o Mouse Look
        shoulderZoomScale          = true,   -- ombro proporcional à distância da câmera
        situations                 = true,   -- câmera muda por situação (combate, chefe, montaria...)
        situationZoomMemory        = true,   -- cada situação lembra a distância usada nela
        dynamicPitch               = true,   -- inclinação dinâmica (test_cameraDynamicPitch)
        dynamicPitchStrength       = 0.4,    -- força da inclinação dinâmica (0-1)
        autofocusLockedTarget      = false,  -- câmera segue o alvo travado (test_cameraTargetFocusEnemyEnable)
        respectMotionSickness      = false,  -- respeita opções de acessibilidade contra enjoo
        -- Vignette (escurecimento nas bordas)
        vignetteConditions         = "mouselook", -- CSV: mouselook | combat | interaction ("" = desligado)
        vignetteMatch              = "any",       -- "any" | "all"
        -- Comportamento Geral
        pulseCursor                = true,   -- pulso visual ao destravar o cursor
        hideTooltip                = true,   -- esconde tooltips durante o Mouse Look
        tooltipModifier            = "ALT",  -- tecla para espiar tooltip: ALT | CTRL | SHIFT
        sheathWeaponsWithMouselook = false,  -- embainha armas ao sair do Mouse Look
        closeWindowsOnMouseLook    = false,  -- tecla Mouse Look fecha janelas abertas
        ctrlToggle                 = false,  -- toque rápido no Ctrl alterna o Mouse Look (como a tecla V)
        interactUnit               = "target",
        -- Sons
        soundMouseLook             = true,
        soundTargetLock            = true,
        soundRadialMenu            = true,
        soundAllyCycle             = true,
        -- Mira (Crosshair)
        crosshair                  = true,
        crosshairStyle             = "diamond", -- "diamond" | "ring" | "dot" | "cross" | "star" | "hidden"
        crosshairCastFeedback      = true,
        crosshairScale             = 1.0,
        crosshairY                 = 100,    -- deslocamento vertical em pixels
        crosshairColors            = {},     -- overrides de cor por reação
        crosshairSituationalCondition = "local d = UnitIsDeadOrGhost and UnitIsDeadOrGhost('player')\nif d then return true end\nreturn false",
        crosshairSituationalStyle     = "hidden",
        -- HUD de Interação e Assistência
        interactionHUD             = true,   -- mostra prompt de interação abaixo da mira
        crosshairTargetPreview     = true,   -- mostra prévia Azaath do alvo sob a mira no canto inferior direito
        interactionHUDPlayers      = true,   -- mostra nome/retrato de outros jogadores sob a mira
        disablePlayerInteract      = false,  -- desativa menu de contexto em jogadores ao interagir
        showTargetLockMarker       = true,   -- marcador na nameplate do alvo travado (focus)
        assistedHighlightMode      = "always", -- "always" | "combat" | "hidden"
        assistedHighlightSide      = "RIGHT",
        assistedHighlightScale     = 1.0,
        assistedHighlightPadding   = 24,
        -- Reticle Targeting (Soft Target)
        reticleTargeting           = true,   -- mira reticular (SoftTarget)
        reticleOutline             = true,   -- contorno brilhante no alvo (Outline 3)
        selectionCircleMode        = "target", -- "target" | "locked" | "soft" | "hidden"
        autoTargetLockOnAttack     = false,  -- trava foco automaticamente ao atacar
        targetLockBehavior         = "toggle", -- "toggle" | "switch"
        reticleCVarOverrides       = {},
        priorCVarSnapshot          = nil,
        -- Click Casting (botões do mouse no Mouse Look)
        useGlobalBindings          = true,
        macroInjectionClickCastOnly = false,
        excludeFromTargetingSpells = "",
        castAtCursorSpells         = "",
        bindings = {
            button1      = { enabled = true, key = "BUTTON1",       value = "ACTIONBUTTON1",   macroName = "" },
            button2      = { enabled = true, key = "BUTTON2",       value = "ACTIONBUTTON2",   macroName = "" },
            shiftbutton1 = { enabled = true, key = "SHIFT-BUTTON1", value = "ACTIONBUTTON3",   macroName = "" },
            shiftbutton2 = { enabled = true, key = "SHIFT-BUTTON2", value = "ACTIONBUTTON4",   macroName = "" },
            ctrlbutton1  = { enabled = true, key = "CTRL-BUTTON1",  value = "ACTIONBUTTON5",   macroName = "" },
            ctrlbutton2  = { enabled = true, key = "CTRL-BUTTON2",  value = "ACTIONBUTTON6",   macroName = "" },
            altbutton1   = { enabled = true, key = "ALT-BUTTON1",   value = "TARGETMOUSEOVER", macroName = "" },
            altbutton2   = { enabled = true, key = "ALT-BUTTON2",   value = "CLEARTARGET",     macroName = "" },
        },
        -- Modo Suporte
        supportModePage            = 2,          -- página de barra ao ativar (2-6, 0 = não troca)
        supportModeNameplateMode   = "friendly", -- "keep" | "friendly" | "all" | "none"
        supportModeCrosshairFirst  = false,
        supportModeTintVignette    = true,
        supportModeActive          = false,
        -- Ciclo de Aliados (Ally Cycle)
        allyCycle = {
            showHud                 = true,
            hudSide                 = "BOTTOM",
            scale                   = 1.0,
            padding                 = 24,
            skipPlayer              = true,
            extraUnits              = "playerPet", -- CSV: playerPet | partyPets
            restoreAllyAfterHarm    = false,
        },
        -- Menu Radial
        radialEnabled              = true,
        radialBackdrop             = true,  -- false: menu radial transparente (só os aros)
        radialConsumables          = { 6948 }, -- Pedra de Regresso no slot 1 por padrão
        radialSpells               = {},       -- habilidades da aba Habilidades (IDs de feitiço)
        radialWheels               = {},
        partyWheelSpells           = "",
        -- Câmera de Combate (estilo Black Desert)
        bdoEnabled                 = true,
        bdoIntensity               = 0.65,
        bdoCastFocus               = true,
        bdoSkillPunch              = true,
        bdoHitShake                = true,
        bdoCritImpact              = true,
        bdoMoves                   = true,   -- gesto de câmera por habilidade (investida, giro, golpe pesado, brado)
        bdoHurtShake               = true,   -- tremor ao levar dano
        bdoCritSound               = true,
        bdoCritSoundStyle          = "impact",
        bdoSpeedZoom               = true,
        bdoCameraInertia           = true,
        bdoCombatZoomOut           = false,
        -- Auto Cursor Unlock
        frameWatching              = true,
        watchlist                  = {},
        mountsToUnlock             = "",
        customCondition            = "",
        customConditionOnce        = false,
        customLockCondition        = "",
        customLockConditionOnce    = false,
        -- Perfis por personagem
        chars                      = {},
    },

    -- Destaque de objetos do mundo e nós no minimapa (Olho de Azaath nativo)
    olho = {
        enabled        = true,
        range          = 15,
        arc            = 2,
        glowOnly       = false,
        exclusive      = true,
        silhouette     = true,
        hideInCombat   = false,
        hideInInstance = false,
    },
}

-- Versão do esquema do banco. Ao mudar o layout padrão de forma incompatível,
-- incremente: bancos antigos são redefinidos uma vez (ver ADDON_LOADED).
Azaath.DB_VERSION = 2

--------------------------------------------------------------------------------
-- Mídia e paleta (inspiradas na linguagem visual de Azaath; arte própria)
--------------------------------------------------------------------------------
local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"

-- Validador seguro de fontes: verifica se o motor gráfico do WoW consegue carregar
-- o arquivo .ttf. Se o jogo foi iniciado antes da cópia de novos arquivos, o cliente WoW
-- exige reinicialização completa para indexar novos .ttf; enquanto isso, usamos o
-- fallback nativo de forma 100% transparente sem quebrar nada nem retornar nil.
local probeFS
local function SafeFont(path, fallback)
    if not probeFS and UIParent and UIParent.CreateFontString then
        probeFS = UIParent:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    end
    if path and probeFS then
        local ok = pcall(probeFS.SetFont, probeFS, path, 12, "")
        if ok then
            local cur = probeFS:GetFont()
            if cur and (string.lower(cur) == string.lower(path) or string.find(string.lower(cur), string.lower(path), 1, true)) then
                return path
            end
        end
    end
    return fallback
end

local fontPTSans   = SafeFont(MEDIA .. "Fonts\\PTSans-Regular.ttf", "Fonts\\ARIALN.TTF")
local fontPTSansB  = SafeFont(MEDIA .. "Fonts\\PTSans-Bold.ttf", fontPTSans or "Fonts\\ARIALN.TTF")
local fontCinzelB  = SafeFont(MEDIA .. "Fonts\\Cinzel-Bold.ttf", "Fonts\\FRIZQT__.TTF")
local fontCinzelR  = SafeFont(MEDIA .. "Fonts\\Cinzel-Regular.ttf", fontCinzelB or "Fonts\\FRIZQT__.TTF")
local fontIMFell   = SafeFont(MEDIA .. "Fonts\\IMFell-Regular.ttf", fontCinzelR or "Fonts\\FRIZQT__.TTF")
local fontIMFellI  = SafeFont(MEDIA .. "Fonts\\IMFell-Italic.ttf", fontIMFell)
-- Card de atributos (tecla C): sans larga do conceito
local fontCardSB   = SafeFont(MEDIA .. "Fonts\\SegoeUI-Semibold.ttf", fontPTSansB or "Fonts\\ARIALN.TTF")
local fontCardR    = SafeFont(MEDIA .. "Fonts\\SegoeUI-Regular.ttf", fontCardSB or fontPTSans)
-- Skin Black Desert: Noto Sans Medium (fonte da interface do BDO)
local fontBDO      = SafeFont(MEDIA .. "Fonts\\NotoSans-Medium.ttf", fontPTSans)
local fontBDOB     = SafeFont(MEDIA .. "Fonts\\NotoSans-SemiBold.ttf", fontBDO)

Azaath.media = {
    path        = MEDIA,
    font        = fontPTSans,    -- fonte UI limpa Azaath (chat, objetivos, loot, botões)
    fontBold    = fontPTSansB,   -- números, quantidades e destaques em negrito
    fontTitle   = fontIMFell,    -- fonte oficial de títulos Azaath (Pilgrimage of Pain, Isle of Night)
    fontTitleB  = fontCinzelB,   -- títulos monumentais em maiúsculas (bússola, brasões, abas)
    fontCinzel  = fontCinzelR,   -- nomes de inimigos (serifa clássica, peso normal)
    fontDamage  = fontCinzelB,   -- fonte oficial dos números de dano Azaath (Cinzel Bold, mesma do inventário e UI)
    fontDamageR = fontCinzelR,
    fontItalic  = fontIMFellI,
    fontCard    = fontCardSB,    -- card "Atributos & Combate" (rótulos, números)
    fontCardR   = fontCardR,
    fontBDO     = fontBDO,
    fontBDOB    = fontBDOB,  -- número do nível no losango
    blank       = "Interface\\Buttons\\WHITE8X8",
}

-- Define globalmente a fonte padrão de texto de dano (3.3.5 e Classic)
_G.DAMAGE_TEXT_FONT = fontCinzelB

-- Registro de fontes no LibSharedMedia para compatibilidade geral de addons
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
if LSM then
    pcall(LSM.Register, LSM, "font", "PT Sans", Azaath.media.font)
    pcall(LSM.Register, LSM, "font", "PT Sans Bold", Azaath.media.fontBold)
    pcall(LSM.Register, LSM, "font", "IM Fell DW Pica", Azaath.media.fontTitle)
    pcall(LSM.Register, LSM, "font", "IM Fell DW Pica Italic", Azaath.media.fontDamage)
    pcall(LSM.Register, LSM, "font", "Cinzel Bold", Azaath.media.fontTitleB)
end

Azaath.colors = {
    gold      = { 0.79, 0.66, 0.42 },  -- filetes e bordas
    cream     = { 0.93, 0.90, 0.83 },  -- texto principal
    accent    = { 0.96, 0.78, 0.38 },  -- destaques (marcadores, ativo)
    dark      = { 0.07, 0.085, 0.10 }, -- painéis azul-carvão
    dim       = { 0.58, 0.60, 0.60 },  -- texto secundário
    parchment = { 0.87, 0.85, 0.80 },  -- preenchimento da vida do jogador
    slate     = { 0.34, 0.38, 0.42 },  -- bordas de botões
}

-- Espaça as letras de um título ("POSTREKHIN" -> "P O S T R E K H I N"),
-- imitando o tracking largo dos títulos do Azaath (FontString 3.3.5 não tem
-- espaçamento de letras). Palavras ficam separadas por 3 espaços.
-- string.upper só conhece ASCII: acentos do português são convertidos à mão
local ACCENT_UPPER = {
    ["á"] = "Á", ["à"] = "À", ["â"] = "Â", ["ã"] = "Ã", ["é"] = "É", ["ê"] = "Ê",
    ["í"] = "Í", ["ó"] = "Ó", ["ô"] = "Ô", ["õ"] = "Õ", ["ú"] = "Ú", ["ü"] = "Ü", ["ç"] = "Ç",
}
function Azaath.Upper(text)
    return ((text or ""):upper():gsub("\195[\160-\191]", ACCENT_UPPER))
end

function Azaath.Tracked(text)
    text = Azaath.Upper(text)
    local out = {}
    for word in text:gmatch("%S+") do
        local letters = {}
        -- percorre caracteres UTF-8 inteiros (acentos têm 2 bytes)
        for ch in word:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
            letters[#letters + 1] = ch
        end
        out[#out + 1] = table.concat(letters, " ")
    end
    return table.concat(out, "   ")
end

-- Formata 3010 -> "3,010" (BreakUpLargeNumbers não existe na 3.3.5)
function Azaath.Thousands(n)
    local s = tostring(math.floor((n or 0) + 0.5))
    local formatted
    repeat
        s, formatted = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
    until formatted == 0
    return s
end

-- 47530 -> "4 ouro  75 prata  30 cobre" (com as cores das moedas)
function Azaath.FormatMoney(copper)
    copper = copper or 0
    local g, s, c = math.floor(copper / 10000), math.floor(copper % 10000 / 100), copper % 100
    local parts = {}
    if g > 0 then parts[#parts + 1] = format("|cffffd700%s|r ouro", Azaath.Thousands(g)) end
    if s > 0 then parts[#parts + 1] = format("|cffc7c7cf%d|r prata", s) end
    if c > 0 or #parts == 0 then parts[#parts + 1] = format("|cffeda55f%d|r cobre", c) end
    return table.concat(parts, "  ")
end

--------------------------------------------------------------------------------
-- Menu de contexto próprio (no lugar do UIDropDownMenu)
-- Abrir um UIDropDownMenu a partir de código de addon contamina as globais
-- UIDROPDOWNMENU_* e quebra "Definir foco" nos menus da Blizzard. Este menu
-- é um frame comum: só deve conter ações NÃO protegidas.
--   entries = { title = "Nome", { text = "...", func = fn, disabled = bool }, ... }
--------------------------------------------------------------------------------
local menu
local MENU_ROW, MENU_W = 18, 170

local function Menu_OnUpdate(self, elapsed)
    -- fecha sozinho com o mouse fora por 1.5s
    local over = (self.IsMouseOver and self:IsMouseOver()) or (_G.MouseIsOver and _G.MouseIsOver(self))
    if over then
        self.idle = 0
    else
        self.idle = self.idle + elapsed
        if self.idle > 1.5 then self:Hide() end
    end
end

function Azaath:ShowMenu(entries)
    local c, media = self.colors, self.media
    if not menu then
        menu = CreateFrame("Frame", "AzaathUIMenu", UIParent)
        menu:SetFrameStrata("DIALOG")
        menu:SetWidth(MENU_W)
        menu:SetClampedToScreen(true)
        menu:EnableMouse(true)
        Azaath.SetBackdrop(menu, {
            bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
        menu:SetBackdropColor(c.dark[1], c.dark[2], c.dark[3], 0.96)
        menu:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.6)
        menu.title = menu:CreateFontString(nil, "OVERLAY")
        menu.title:SetFont(media.fontTitleB, 11, "")
        menu.title:SetTextColor(c.gold[1], c.gold[2], c.gold[3])
        menu.title:SetPoint("TOPLEFT", menu, "TOPLEFT", 10, -8)
        menu.rows = {}
        menu.idle = 0
        menu:SetScript("OnUpdate", Menu_OnUpdate)
        menu:SetScript("OnShow", function(f) f.idle = 0 end)
        menu:Hide()
        tinsert(UISpecialFrames, "AzaathUIMenu") -- fecha com ESC
    end

    local top = 8
    if entries.title then
        menu.title:SetText(entries.title)
        menu.title:Show()
        top = 26
    else
        menu.title:Hide()
    end

    for i, entry in ipairs(entries) do
        local row = menu.rows[i]
        if not row then
            row = CreateFrame("Button", nil, menu)
            row:SetHeight(MENU_ROW)
            row:SetHighlightTexture(media.blank)
            local hl = row:GetHighlightTexture()
            hl:SetVertexColor(1, 1, 1)
            hl:SetAlpha(0.08)
            row.text = row:CreateFontString(nil, "OVERLAY")
            row.text:SetFont(media.font, 13, "")
            row.text:SetPoint("LEFT", row, "LEFT", 10, 0)
            row:SetScript("OnClick", function(r)
                menu:Hide()
                if r.func then r.func() end
            end)
            menu.rows[i] = row
        end
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -(top + (i - 1) * MENU_ROW))
        row:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -1, -(top + (i - 1) * MENU_ROW))
        row.text:SetText(entry.text)
        row.func = entry.func
        if entry.disabled then
            row:Disable()
            row.text:SetTextColor(c.dim[1], c.dim[2], c.dim[3])
        else
            row:Enable()
            row.text:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
        end
        row:Show()
    end
    for i = #entries + 1, #menu.rows do menu.rows[i]:Hide() end
    menu:SetHeight(top + #entries * MENU_ROW + 8)

    local scale = UIParent:GetEffectiveScale()
    local x, y = GetCursorPosition()
    menu:ClearAllPoints()
    menu:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x / scale, y / scale)
    menu:Show()
end

--------------------------------------------------------------------------------
-- Utilitários
--------------------------------------------------------------------------------
local PREFIX = "|cffe3c78bAzaath|r|cffbfa77bUI|r: "

function Azaath:Print(msg, ...)
    if select("#", ...) > 0 then
        msg = msg:format(...)
    end
    DEFAULT_CHAT_FRAME:AddMessage(PREFIX .. tostring(msg))
end

local function MergeDefaults(src, dst)
    if type(dst) ~= "table" then dst = {} end
    for k, v in pairs(src) do
        if type(v) == "table" then
            dst[k] = MergeDefaults(v, dst[k])
        elseif dst[k] == nil then
            dst[k] = v
        end
    end
    return dst
end

function Azaath.CopyDeep(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, x in pairs(v) do t[k] = Azaath.CopyDeep(x) end
    return t
end

-- Volta este personagem aos padrões (o modelo da conta também, senão ele seria copiado de volta)
function Azaath.ResetDB()
    AzaathUIDB = nil
    AzaathUICharDB = nil
end

-- Chama um método de módulo isolando erros: um módulo quebrado não derruba os demais.
-- Diagnóstico: guarda os últimos erros de Lua do addon no AzaathUIDB.errorLog
-- (o cliente esconde erros por padrão; o arquivo salvo é gravado no /reload)
local pendingErrors = {}
function Azaath.LogError(msg)
    local line = (date and date("%H:%M:%S") or "") .. " " .. tostring(msg)
    local db = Azaath.db
    if type(db) ~= "table" then
        pendingErrors[#pendingErrors + 1] = line -- antes do ADDON_LOADED
        return
    end
    db.errorLog = type(db.errorLog) == "table" and db.errorLog or {}
    local log = db.errorLog
    log[#log + 1] = line
    while #log > 60 do table.remove(log, 1) end
end

do
    local prev = geterrorhandler()
    seterrorhandler(function(msg, ...)
        local s = tostring(msg)
        if s:find("AzaathUI", 1, true) then pcall(Azaath.LogError, s) end
        if prev then return prev(msg, ...) end
    end)
    -- "ação bloqueada" (a janela de Desativar/Ignorar): anota qual função o jogo barrou
    local blocked = CreateFrame("Frame")
    for _, ev in ipairs({ "ADDON_ACTION_BLOCKED", "ADDON_ACTION_FORBIDDEN" }) do
        pcall(blocked.RegisterEvent, blocked, ev)
    end
    blocked:SetScript("OnEvent", function(_, event, addon, func)
        if addon ~= "AzaathUI" then return end
        pcall(Azaath.LogError, ("%s: %s (combate: %s)"):format(event, tostring(func),
            tostring(InCombatLockdown and InCombatLockdown())))
        -- a pilha no momento do bloqueio (o evento chega durante a chamada barrada)
        local ok, stack = pcall(debugstack, 2, 30, 0)
        if ok and type(stack) == "string" then
            for line in stack:gmatch("[^\n]+") do pcall(Azaath.LogError, "  " .. line) end
        end
    end)
end

local function SafeCall(mod, method, ...)
    local fn = mod[method]
    if type(fn) ~= "function" then return end
    local ok, err = pcall(fn, mod, ...)
    if not ok then
        local msg = ("AzaathUI [%s:%s] %s"):format(mod.name, method, tostring(err))
        pcall(Azaath.LogError, msg)
        geterrorhandler()(msg)
    end
end
Azaath.SafeCall = SafeCall

--------------------------------------------------------------------------------
-- Frames base
--------------------------------------------------------------------------------
-- Raiz de toda a interface Azaath. Filho de UIParent => respeita Alt+Z e cinemáticas.
local root = CreateFrame("Frame", "AzaathUIRoot", UIParent)
root:SetAllPoints(UIParent)
Azaath.root = root

-- Frame oculto usado como "pai" de frames da Blizzard que queremos sumir.
-- Reparentar para um pai oculto é a forma limpa: não substitui métodos (sem taint)
-- e o frame continua invisível mesmo que o código da Blizzard chame :Show().
local hider = CreateFrame("Frame", "AzaathUIHider")
hider:Hide()
Azaath.hider = hider

--------------------------------------------------------------------------------
-- Sistema de módulos
--------------------------------------------------------------------------------
Azaath.modules = {}
Azaath.moduleOrder = {}

function Azaath:NewModule(name)
    assert(not self.modules[name], "AzaathUI: módulo duplicado: " .. tostring(name))
    local mod = { name = name }
    self.modules[name] = mod
    tinsert(self.moduleOrder, name)
    return mod
end

function Azaath:GetModule(name)
    return self.modules[name]
end

function Azaath:IterateModules()
    local i = 0
    return function()
        i = i + 1
        local name = self.moduleOrder[i]
        if name then return name, self.modules[name] end
    end
end

--------------------------------------------------------------------------------
-- Eventos e fila fora de combate
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
local combatQueue = {}

-- Executa func imediatamente, ou assim que o jogador sair de combate.
-- Retorna true se executou na hora.
function Azaath:RunOutOfCombat(func)
    if not InCombatLockdown() then
        func()
        return true
    end
    tinsert(combatQueue, func)
    Azaath.SafeRegister(events, "PLAYER_REGEN_ENABLED")
    return false
end

local function FlushCombatQueue()
    events:UnregisterEvent("PLAYER_REGEN_ENABLED")
    for i = 1, #combatQueue do
        local ok, err = pcall(combatQueue[i])
        if not ok then geterrorhandler()(err) end
    end
    wipe(combatQueue)
end

-- Mostra/esconde toda a camada Azaath.
function Azaath:SetUIShown(show)
    self.db.enabled = show and true or false
    local ranNow = self:RunOutOfCombat(function()
        if self.db.enabled then root:Show() else root:Hide() end
        for _, mod in self:IterateModules() do
            SafeCall(mod, "OnVisibilityChanged", self.db.enabled)
        end
    end)
    if not ranNow then
        self:Print("em combate: a alteração será aplicada ao sair do combate.")
    end
end

-- Escala geral e ajuste automático para manter todos os elementos dentro da
-- tela sempre que a escala (Blizzard ou AzaathUI) ou a resolução mudarem.
-- O root tem filhos protegidos (barras de ação), então em combate é adiado.
function Azaath.ClampToScreen(frame, pad)
    if not frame or not UIParent then return 0, 0 end
    if frame.IsProtected and frame:IsProtected() and InCombatLockdown() then return 0, 0 end
    if frame.SetClampedToScreen then pcall(frame.SetClampedToScreen, frame, true) end

    local left, right, bottom, top = frame:GetLeft(), frame:GetRight(), frame:GetBottom(), frame:GetTop()
    local fs = frame:GetEffectiveScale()
    local us = UIParent:GetEffectiveScale()
    if not (left and right and bottom and top and fs and us) or fs <= 0 or us <= 0 then
        frame._azClampDX, frame._azClampDY = 0, 0
        return 0, 0
    end

    local sLeft   = (UIParent:GetLeft()   or 0) * us
    local sRight  = (UIParent:GetRight()  or UIParent:GetWidth()  or 0) * us
    local sBottom = (UIParent:GetBottom() or 0) * us
    local sTop    = (UIParent:GetTop()    or UIParent:GetHeight() or 0) * us
    if sRight <= sLeft or sTop <= sBottom then
        frame._azClampDX, frame._azClampDY = 0, 0
        return 0, 0
    end

    local pL, pR, pB, pT
    if type(pad) == "table" then
        pL, pR, pB, pT = (pad.left or 0) * us, (pad.right or 0) * us, (pad.bottom or 0) * us, (pad.top or 0) * us
    else
        local p = (pad or 0) * us
        pL, pR, pB, pT = p, p, p, p
    end

    left, right   = left * fs, right * fs
    bottom, top   = bottom * fs, top * fs
    local fw, fh  = right - left, top - bottom
    local sw, sh  = (sRight - sLeft) - (pL + pR), (sTop - sBottom) - (pB + pT)
    local dxPx, dyPx = 0, 0

    if fw <= sw then
        if left < sLeft + pL then dxPx = (sLeft + pL) - left
        elseif right > sRight - pR then dxPx = (sRight - pR) - right end
    else
        dxPx = (sLeft + sRight) / 2 - (left + right) / 2
    end
    if fh <= sh then
        if bottom < sBottom + pB then dyPx = (sBottom + pB) - bottom
        elseif top > sTop - pT then dyPx = (sTop - pT) - top end
    else
        dyPx = (sBottom + sTop) / 2 - (bottom + top) / 2
    end

    local dx, dy = dxPx / fs, dyPx / fs
    if math.abs(dxPx) >= 0.5 or math.abs(dyPx) >= 0.5 then
        local n = frame:GetNumPoints()
        if n and n > 0 then
            local pts = {}
            for i = 1, n do pts[i] = { frame:GetPoint(i) } end
            frame:ClearAllPoints()
            for i = 1, n do
                local p = pts[i]
                frame:SetPoint(p[1], p[2], p[3], (p[4] or 0) + dx, (p[5] or 0) + dy)
            end
        end
        frame._azClampDX, frame._azClampDY = dx, dy
    else
        frame._azClampDX, frame._azClampDY = 0, 0
    end
    return frame._azClampDX, frame._azClampDY
end

local SCALE_LAYOUT_MODULES = {
    "AzaathHUD", "BDOHUD", "UnitFrames", "Experience", "Compass",
    "ActionBars", "StancePetBars", "CastBar", "Minimap", "Auras",
    "PartyFrames", "QuestTracker", "MicroMenu", "Dialog", "Loot",
    "Chat", "Merchant",
}

local scaleRefreshFrame = CreateFrame("Frame")
scaleRefreshFrame:Hide()
scaleRefreshFrame:SetScript("OnUpdate", function(self)
    self:Hide()
    if Azaath.RefreshScaleLayout then Azaath:RefreshScaleLayout() end
end)

local function ScheduleScaleRefresh()
    scaleRefreshFrame:Show()
end

function Azaath:RefreshScaleLayout()
    if not self.db then return end
    self:RunOutOfCombat(function()
        root:ClearAllPoints()
        root:SetAllPoints(UIParent)
        root:SetScale(self.db.scale or 1)
        for _, name in ipairs(SCALE_LAYOUT_MODULES) do
            local mod = self:GetModule(name)
            if mod and mod.ApplyLayout then
                local ok, err = pcall(mod.ApplyLayout, mod)
                if not ok and self.LogError then
                    self.LogError("AzaathUI scale [" .. name .. "]: " .. tostring(err))
                end
            end
        end
        local cfg = self:GetModule("Config")
        if cfg and cfg.OnScaleChanged then pcall(cfg.OnScaleChanged, cfg) end
    end)
end

function Azaath:ApplyScale()
    self:RefreshScaleLayout()
    ScheduleScaleRefresh()
end

--------------------------------------------------------------------------------
-- Perfis de geometria por disposição ("az" = Azaath Modern, "center" =
-- Custom, e as que vierem depois). Mexer nos elementos (Modo de Edição ou
-- opções) numa disposição não altera as outras: cada uma guarda a sua cópia
-- de posição/tamanho/escala. Opções de comportamento (ligado/desligado,
-- atalhos, fontes...) continuam compartilhadas.
-- AzaathUIDB.layoutProfiles = { active = "az", az = { [caminho] = { chave = valor } }, ... }
--------------------------------------------------------------------------------
local GEO_PATHS = {
    "experience", "compass", "minimap", "party", "questtracker", "micromenu",
    "dialog", "loot", "chat",
    "unitframes.player", "unitframes.target",
    "castbar.player", "castbar.target",
    "actionbars", "actionbars.bar1", "actionbars.bar2", "actionbars.bar3",
    "actionbars.bag", "actionbars.pet", "actionbars.stance",
    "auras.playerBuffs", "auras.playerDebuffs", "auras.target",
    "lootCelebration",
}
local GEO_KEYS = {
    "offsetX", "offsetY", "scale", "width", "height", "size", "buttonSize",
    "smallSize", "spacing", "cols", "perRow", "customPos", "healthHeight",
    "powerHeight", "segments", "maxHeight", "barHeight", "nameFont", "fov",
    "badgeX", "badgeY", "badgeSize", "badgeScale", "feedX", "feedY", "feedScale",
    "ringSize", "anchor",
}
Azaath.LAYOUT_GEO_PATHS, Azaath.LAYOUT_GEO_KEYS = GEO_PATHS, GEO_KEYS

-- Skins da Azaath UI (apenas barra de tarefas e frame do personagem):
-- "modern" = Azaath Modern (HUD com losango/XP sob a vida)
-- "azaath"  = Azaath Reforged (arte de conceito)
function Azaath.IsAzLayout(layout)
    return layout == "az" or layout == "azclassic"
end

-- Opção 2 (split): duas barras de 12 teclas na base, uma de cada lado da vida
function Azaath.IsSplitLayout(layout)
    return layout == "split"
end

-- Barras em grade de 6 colunas (Opção 1 e Opção 2): 12 teclas em 2 fileiras
function Azaath.IsSixCols(layout)
    return Azaath.IsAzLayout(layout) or Azaath.IsSplitLayout(layout)
end

function Azaath.GetSkin()
    local s = Azaath.db and Azaath.db.skin
    if s == "azaath" then return "azaath" end
    if s == "bdo"   then return "bdo" end
    if s == "blizzard" then return "blizzard" end
    return "modern"
end

-- Opções "Blizzard": a parte fica com o quadro/barra/placa padrão do jogo (vale após /reload)
--   skin "blizzard" ............ quadros do jogador e do alvo da Blizzard
--   actionbars.layout "blizzard" barras de ação da Blizzard (com o micromenu dela; o nosso some)
--   nameplates.style "blizzard"  placas de nome padrão
function Azaath.IsBlizzSkin()
    return Azaath.db ~= nil and Azaath.db.skin == "blizzard"
end
function Azaath.IsBlizzBars()
    local ab = Azaath.db and Azaath.db.actionbars
    return ab ~= nil and ab.layout == "blizzard"
end
function Azaath.IsBlizzPlates()
    local np = Azaath.db and Azaath.db.nameplates
    return np ~= nil and np.style == "blizzard"
end
-- hideBlizzard[key] já descontando as opções "Blizzard" acima
function Azaath.HideBlizzOn(key)
    local hb = Azaath.db and Azaath.db.hideBlizzard
    if not (hb and hb[key]) then return false end
    if key == "actionBars" and Azaath.IsBlizzBars() then return false end
    if (key == "playerFrame" or key == "targetFrame") and Azaath.IsBlizzSkin() then return false end
    -- "Ativar quadro do alvo" desligado: volta o quadro de alvo da Blizzard (em qualquer skin)
    if key == "targetFrame" and not Azaath.TargetFrameOn() then return false end
    return true
end

-- quadro de alvo do Azaath (UnitFrames ou o da skin Zerker): ligado no menu e fora da skin Blizzard
function Azaath.TargetFrameOn()
    local t = Azaath.db and Azaath.db.unitframes and Azaath.db.unitframes.target
    return t ~= nil and t.enabled ~= false and not Azaath.IsBlizzSkin()
end

-- Skin Azaath Reforged: moldura central própria (vida/recurso/XP) em AzaathHUD.lua
function Azaath.IsAzaath()
    return Azaath.GetSkin() == "azaath"
end

-- Opção 4 (Reforged): painéis da arte de conceito como barras livres, em qualquer skin
function Azaath.IsReforgedBars()
    local ab = Azaath.db and Azaath.db.actionbars
    return ab ~= nil and ab.layout == "reforged" and Azaath.AZAATH ~= nil
end

-- Skin BDO: HUD própria em BDOHUD.lua
function Azaath.IsBDO()
    return Azaath.GetSkin() == "bdo"
end

-- Chave do perfil de medidas: uma por skin ("modern" ou "azaath")
-- A skin só muda vida/recurso, XP e nível; a barra de ação é escolha à parte (actionbars.layout):
-- "bdo" = Opção 1, "split" = Opção 2, "az" = Opção 3. Cada combinação skin + barra tem as suas medidas
-- (a combinação "natural" — BDO com "bdo", as outras com "az" — usa só o nome da skin).
-- "reforged" = Opção 4 (painéis da Reforged), natural da skin Azaath Reforged.
function Azaath.LayoutKey()
    local skin = Azaath.GetSkin()
    local ab = Azaath.db and Azaath.db.actionbars
    local layout = ab and ab.layout or "az"
    if layout == "azclassic" then layout = "az" end
    local natural = (skin == "bdo") and "bdo" or (skin == "azaath") and "reforged" or (skin == "blizzard") and "blizzard" or "az"
    if layout ~= natural then return skin .. "_" .. layout end
    return skin
end

-- Garante que barras e skin estejam sempre nos valores suportados ("modern", "azaath" ou "bdo")
function Azaath.EnforceSkinBars()
    local db = Azaath.db
    if db and (db.skin == "classic" or db.skin == "azoth_crystal") then db.skin = "modern" end
    -- BDO: barras de ação ficam livres (sem forçar layout "az")
    if db and db.skin == "bdo" then return end
    local ab = db and db.actionbars
    if type(ab) == "table" and ab.layout == "center" then
        ab.layout = "az"
    end
end

-- Medidas iniciais de uma combinação na primeira vez que é escolhida.
local LAYOUT_SEEDS = {
    -- Azaath Reforged: buffs no canto superior esquerdo da moldura central (34 px, como no conceito)
    azaath = {
        ["auras.playerBuffs"] = { size = 34, spacing = 6, perRow = 10, scale = 1, offsetX = 0, offsetY = 0, customPos = false },
        ["auras.playerDebuffs"] = { size = 34, spacing = 6, perRow = 10, scale = 1, offsetX = 0, offsetY = 0, customPos = false },
    },
}

local function ResolvePath(root, path)
    local t = root
    for part in path:gmatch("[^%.]+") do
        if type(t) ~= "table" then return nil end
        t = t[part]
    end
    return type(t) == "table" and t or nil
end

local function CopyGeoValue(v)
    if type(v) ~= "table" then return v end
    local out = {}
    for k, x in pairs(v) do out[k] = CopyGeoValue(x) end
    return out
end

-- Foto da geometria atual
local function CaptureGeometry()
    local snap = {}
    for _, path in ipairs(GEO_PATHS) do
        local t = ResolvePath(Azaath.db, path)
        if t then
            local s = {}
            for _, k in ipairs(GEO_KEYS) do
                if t[k] ~= nil then s[k] = CopyGeoValue(t[k]) end
            end
            snap[path] = s
        end
    end
    return snap
end

-- Aplica uma foto: chaves ausentes nela voltam ao padrão do addon
local function RestoreGeometry(snap)
    for _, path in ipairs(GEO_PATHS) do
        local t = ResolvePath(Azaath.db, path)
        local s = snap[path]
        if t and s then
            local d = ResolvePath(Azaath.defaults, path)
            for _, k in ipairs(GEO_KEYS) do
                local v = s[k]
                if v == nil and d then v = d[k] end
                t[k] = CopyGeoValue(v)
            end
        end
    end
end

local function Profiles()
    local lp = Azaath.db.layoutProfiles
    if type(lp) ~= "table" then
        lp = {}
        Azaath.db.layoutProfiles = lp
    end
    return lp
end

local function CurrentLayout()
    return Azaath.LayoutKey()
end

-- 10/11/2026: Modern/Classic viraram skins e Custom virou opção só das
-- barras. Converte a escolha antiga e os perfis já salvos (uma vez).
function Azaath.MigrateSkins()
    local db = Azaath.db
    local ab = db.actionbars
    -- 20/11/2026: o nome Azoth virou Azaath; leva a escolha e as medidas salvas com o nome antigo
    local OLD = "az" .. "oth"
    if db.skin == OLD then db.skin = "azaath" end
    if db[OLD] ~= nil then
        db.azaath = db[OLD] -- o antigo é o do jogador; o novo pode ser só o padrão recém-criado
        db[OLD] = nil
    end
    if db[OLD .. "V1"] then db.azaathV1, db[OLD .. "V1"] = true, nil end
    local lp0 = db.layoutProfiles
    if type(lp0) == "table" then
        if lp0.active == OLD then lp0.active = "azaath" end
        if lp0[OLD] ~= nil then
            lp0.azaath = lp0[OLD]
            lp0[OLD] = nil
        end
    end
    if not db.skinV1 then
        if type(ab) == "table" and (ab.layout == "azclassic" or ab.layout == "center") then
            ab.layout = "az"
        end
        if db.skin ~= "azaath" then db.skin = "modern" end
        local lp = db.layoutProfiles
        if type(lp) == "table" then
            if type(lp.az) == "table" and lp.modern == nil then lp.modern = lp.az end
            lp.az, lp.azclassic, lp.center, lp.classic, lp.classic_custom, lp.modern_custom = nil, nil, nil, nil, nil, nil
            if lp.active and lp.active ~= "azaath" then lp.active = "modern" end
        end
        db.skinV1 = true
    end
    if db.skin == "classic" or db.skin == "azoth_crystal" then db.skin = "modern" end
    -- 19/11/2026: a skin não decide mais a barra de ação. Quem usava a skin BDO ficava com as barras BDO:
    -- passam a ser a Opção 1 ("bdo"); as demais combinações seguem como estavam.
    if not db.barOptV1 then
        if db.skin == "bdo" and type(ab) == "table" and (ab.layout == "az" or ab.layout == nil) then ab.layout = "bdo" end
        db.barOptV1 = true
    end
end

function Azaath.InitLayoutProfiles()
    local lp = Profiles()
    local cur = CurrentLayout()
    if not lp.active then
        -- primeira vez: a combinação atual guarda a geometria de hoje; as
        -- outras ganham a sua na primeira troca (ou a semente delas)
        lp[cur] = lp[cur] or CaptureGeometry()
        lp.active = cur
    elseif lp.active ~= cur then
        -- disposição trocada fora do menu (migração): carrega a dela
        if type(lp[cur]) == "table" then RestoreGeometry(lp[cur]) end
        lp.active = cur
    end
end

-- Chamado depois de actionbars.layout mudar para "new": salva a disposição
-- anterior e carrega a nova. Devolve true se a nova já tinha perfil próprio.
function Azaath.SwitchLayoutProfile(new)
    local lp = Profiles()
    local old = lp.active
    if old == new then return true end
    if old then lp[old] = CaptureGeometry() end
    lp.active = new
    if type(lp[new]) == "table" then
        RestoreGeometry(lp[new])
        return true
    end
    -- Combinação nova: começa das medidas de fábrica (+ semente dela), nunca das da skin
    -- anterior — senão buffs/barras de uma skin "vazavam" para a outra.
    local seed = LAYOUT_SEEDS[new]
    local snap = {}
    if seed then
        for path, vals in pairs(seed) do snap[path] = CopyGeoValue(vals) end
    end
    for _, path in ipairs(GEO_PATHS) do snap[path] = snap[path] or {} end
    RestoreGeometry(snap)
    lp[new] = CaptureGeometry()
    return seed ~= nil
end

-- Grava a geometria atual no perfil da combinação ativa (logout e saída do Modo de Edição),
-- para o preset da skin nunca depender só do momento da troca.
function Azaath.SaveLayoutProfile()
    if not Azaath.db then return end
    local lp = Profiles()
    local cur = lp.active or CurrentLayout()
    if cur ~= CurrentLayout() then return end -- troca em andamento: SwitchLayoutProfile cuida
    lp[cur] = CaptureGeometry()
    lp.active = cur
end

Azaath.SafeRegister(events, "ADDON_LOADED")
Azaath.SafeRegister(events, "PLAYER_LOGIN")
Azaath.SafeRegister(events, "PLAYER_LOGOUT")
Azaath.SafeRegister(events, "UI_SCALE_CHANGED")
Azaath.SafeRegister(events, "DISPLAY_SIZE_CHANGED")
events:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" then
        if arg1 ~= ADDON_NAME then return end
        self:UnregisterEvent("ADDON_LOADED")

        -- Configurações por personagem (AzaathUICharDB). O AzaathUIDB da conta vira só o
        -- modelo: um personagem sem banco próprio começa com uma cópia dele (o último
        -- personagem jogado, pois no fim da carga os dois apontam para a mesma tabela).
        if type(AzaathUICharDB) ~= "table" then
            AzaathUICharDB = type(AzaathUIDB) == "table" and Azaath.CopyDeep(AzaathUIDB) or nil
        end
        AzaathUIDB = AzaathUICharDB

        -- Layout padrão mudou de forma incompatível: redefine bancos antigos uma vez
        if type(AzaathUIDB) == "table" and (AzaathUIDB.dbVersion or 1) < Azaath.DB_VERSION then
            AzaathUIDB = nil
            Azaath.dbWasReset = true
        end
        Azaath.freshDB = type(AzaathUIDB) ~= "table" -- instalação nova (Setup.lua abre o assistente)
        AzaathUIDB = MergeDefaults(Azaath.defaults, AzaathUIDB)
        AzaathUIDB.dbVersion = Azaath.DB_VERSION
        if AzaathUIDB.actionbars and AzaathUIDB.actionbars.layout == "cards" then
            AzaathUIDB.actionbars.layout = "az"
        end
        if AzaathUIDB.actionbars then
            AzaathUIDB.actionbars.layoutBeforeCards = nil
            if not AzaathUIDB.actionbars.bastionV2Fixed then
                AzaathUIDB.actionbars.bars = 3
                AzaathUIDB.actionbars.offsetX = 0
                AzaathUIDB.actionbars.bar1 = { scale = 1, offsetX = 0, offsetY = 0, cols = 12, buttonSize = 42, customPos = false }
                AzaathUIDB.actionbars.bar2 = { scale = 1, offsetX = 0, offsetY = 0, cols = 2, buttonSize = 38, customPos = false }
                AzaathUIDB.actionbars.bar3 = { scale = 1, offsetX = 0, offsetY = 0, cols = 2, buttonSize = 38, customPos = false }
                if AzaathUIDB.unitframes and AzaathUIDB.unitframes.player then
                    AzaathUIDB.unitframes.player.width = 440
                    AzaathUIDB.unitframes.player.scale = 1
                    AzaathUIDB.unitframes.player.offsetX = 0
                    AzaathUIDB.unitframes.player.customPos = false
                end
                AzaathUIDB.actionbars.bastionV2Fixed = true
            end
            -- HUD Azaath (09/11/2026): passa uma vez para o layout "az" com
            -- as medidas da captura de referência. Depois disso a escolha do
            -- jogador no menu de opções é respeitada.
            if not AzaathUIDB.actionbars.hudV1 then
                local ab = AzaathUIDB.actionbars
                ab.layout = "az"
                ab.buttonSize, ab.smallSize, ab.spacing, ab.offsetY = 46, 36, 6, 34
                for _, k in ipairs({ "bar1", "bar2", "bar3" }) do
                    ab[k] = { scale = 1, offsetX = 0, offsetY = 0, cols = 0, buttonSize = 0, customPos = false }
                end
                local pl = AzaathUIDB.unitframes and AzaathUIDB.unitframes.player
                if pl then
                    pl.width, pl.healthHeight, pl.powerHeight = 340, 20, 16
                    pl.scale, pl.offsetX, pl.offsetY, pl.customPos = 1, 0, 84, false
                    pl.fadeOutOfCombat = false
                end
                local au = AzaathUIDB.auras
                if au and au.playerBuffs then
                    au.playerBuffs.size, au.playerBuffs.perRow, au.playerBuffs.spacing = 30, 10, 4
                    au.playerBuffs.offsetX, au.playerBuffs.offsetY, au.playerBuffs.customPos = 0, 0, false
                end
                if au and au.playerDebuffs then
                    au.playerDebuffs.size, au.playerDebuffs.perRow, au.playerDebuffs.spacing = 28, 10, 4
                    au.playerDebuffs.offsetX, au.playerDebuffs.offsetY, au.playerDebuffs.customPos = 0, 0, false
                end
                ab.hudV1 = true
            end
            -- HUD v2 (09/11/2026): losango de nível + XP sob o quadro; sobe o quadro
            if not AzaathUIDB.actionbars.hudV2 then
                local pl = AzaathUIDB.unitframes and AzaathUIDB.unitframes.player
                if pl and not pl.customPos then pl.offsetY = 100 end
                AzaathUIDB.actionbars.hudV2 = true
            end
            -- HUD v3 (09/11/2026): barras mais finas, como a captura de referência
            if not AzaathUIDB.actionbars.hudV3 then
                local pl = AzaathUIDB.unitframes and AzaathUIDB.unitframes.player
                if pl then pl.healthHeight, pl.powerHeight = 16, 10 end
                AzaathUIDB.actionbars.hudV3 = true
            end
            -- HUD v4 (09/11/2026): medidas da especificação (320 x 20 / 7 / 4) e buffs menores
            if not AzaathUIDB.actionbars.hudV4 then
                local pl = AzaathUIDB.unitframes and AzaathUIDB.unitframes.player
                if pl then pl.width, pl.healthHeight, pl.powerHeight = 320, 20, 7 end
                local pb = AzaathUIDB.auras and AzaathUIDB.auras.playerBuffs
                if pb then pb.size, pb.spacing = 24, 6 end
                AzaathUIDB.actionbars.hudV4 = true
            end
        end
        -- restos de diagnósticos antigos
        AzaathUIDB.apiDump, AzaathUIDB.apiDump2 = nil, nil
        AzaathUIDB.errorLog = pendingErrors -- log de erros recomeça a cada sessão
        -- restos de diagnósticos das placas de nome (07/11/2026)
        AzaathUIDB.npStats, AzaathUIDB.auraDiag, AzaathUIDB.apiProbe = nil, nil, nil
        AzaathUIDB.auraFrameProbe, AzaathUIDB.diagTarget = nil, nil
        -- disposição "Asas do Bastião" (Opção B) removida do menu: volta ao HUD Azaath
        if type(AzaathUIDB.actionbars) == "table" and AzaathUIDB.actionbars.layout == "bastion" then
            AzaathUIDB.actionbars.layout = "az"
        end
        -- Chat: Feed como canal padrão a menos que o usuário tenha alterado manualmente
        if AzaathUIDB.chat and not AzaathUIDB.chat.userChangedChannel then
            AzaathUIDB.chat.channelFilter = "FEED"
        end
        Azaath.db = AzaathUIDB
        AzaathUICharDB = AzaathUIDB -- (MergeDefaults pode ter criado a tabela)
        Azaath.MigrateSkins()
        -- 23/11/2026: barras da Reforged soltas da HUD (Opção 4); quem usa a skin fica com elas
        if not AzaathUIDB.reforgedBarsV1 then
            AzaathUIDB.reforgedBarsV1 = true
            local ab, az = AzaathUIDB.actionbars, AzaathUIDB.azaath or {}
            if AzaathUIDB.skin == "azaath" and type(ab) == "table" then
                ab.layout = "reforged"
                -- painéis nascem onde estavam: mesma escala e deslocamento da HUD antiga
                local s = (az.scale and az.scale > 0) and az.scale or 1
                for _, k in ipairs({ "bar1", "bar2", "bar3" }) do
                    ab[k] = type(ab[k]) == "table" and ab[k] or {}
                    ab[k].scale, ab[k].offsetX, ab[k].offsetY = s, az.offsetX or 0, (az.offsetY or 10) - 10
                end
            end
        end
        Azaath.EnforceSkinBars()
        Azaath.InitLayoutProfiles()
        -- 15/11/2026: skin Azaath (arte de conceito) passa a ser a ativa, uma vez
        if not AzaathUIDB.azaathV1 then
            AzaathUIDB.azaathV1 = true
            AzaathUIDB.skin = "azaath"
            if type(AzaathUIDB.actionbars) == "table" then AzaathUIDB.actionbars.layout = "reforged" end
            Azaath.EnforceSkinBars()
            Azaath.SwitchLayoutProfile(Azaath.LayoutKey())
        end
        -- 19/11/2026: Micro Menu estilo Black Desert no canto inferior direito
        if not AzaathUIDB.bdoMicroV1 then
            AzaathUIDB.bdoMicroV1 = true
            local m = AzaathUIDB.micromenu
            if m then
                m.anchor     = "BOTTOMRIGHT"
                m.offsetX    = -16
                m.offsetY    = 14
                m.buttonSize = 26
                m.spacing    = 5
                m.idleAlpha  = 0.80
                m.collapsed  = false
            end
        end

        for _, mod in Azaath:IterateModules() do
            SafeCall(mod, "OnInitialize")
        end

    elseif event == "PLAYER_LOGOUT" then
        pcall(Azaath.SaveLayoutProfile)
    elseif event == "PLAYER_LOGIN" then
        self:UnregisterEvent("PLAYER_LOGIN")

        if not Azaath.db.enabled then root:Hide() end
        -- Antes dos módulos: o root ainda não tem filhos protegidos, então
        -- pode ser escalado mesmo após um /reload em combate.
        root:SetScale(Azaath.db.scale or 1)

        for _, mod in Azaath:IterateModules() do
            SafeCall(mod, "OnEnable")
        end

        Azaath:Print("v%s carregado. Digite |cffe3c78b/azaath|r para ver os comandos.", Azaath.version)
        if Azaath.dbWasReset then
            Azaath:Print("o layout padrão mudou nesta versão: suas configurações foram redefinidas.")
        end
        ScheduleScaleRefresh()

    elseif event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED" then
        Azaath:RefreshScaleLayout()
        ScheduleScaleRefresh()

    elseif event == "PLAYER_REGEN_ENABLED" then
        FlushCombatQueue()
    end
end)

--------------------------------------------------------------------------------
-- Comandos de barra
--------------------------------------------------------------------------------
-- Aliases aceitos em "/azaath blizz <parte>"
local BLIZZ_KEYS = {
    actionbars = "actionBars", bars = "actionBars",
    player = "playerFrame",
    target = "targetFrame",
    minimap = "minimap", map = "minimap",
    buffs = "buffs",
}

local commands = {}
Azaath.commands = commands -- módulos acrescentam subcomandos (ex.: AzaathHUD)

commands.reload = function()
    ReloadUI()
end
commands.rl = commands.reload

commands.toggle = function()
    Azaath:SetUIShown(not Azaath.db.enabled)
    Azaath:Print("interface %s.", Azaath.db.enabled and "|cff80ff80visível|r" or "|cffff8080oculta|r")
end

commands.compass = function()
    local compass = Azaath:GetModule("Compass")
    if compass then
        compass:SetEnabled(not Azaath.db.compass.enabled)
        Azaath:Print("bússola %s.", Azaath.db.compass.enabled and "ativada" or "desativada")
    end
end

commands.config = function()
    local config = Azaath:GetModule("Config")
    if config then config:Toggle() end
end
commands.options = commands.config

commands.edit = function()
    local config = Azaath:GetModule("Config")
    if config and config.ToggleEditMode then
        config:ToggleEditMode()
    end
end
commands.layout = commands.edit
commands.move = commands.edit

commands.char = function()
    local sheet = Azaath:GetModule("Sheet")
    if sheet and sheet.Toggle and Azaath.db.sheet.enabled then sheet:Toggle() end
end

commands.bag = function()
    local inv = Azaath:GetModule("Inventory")
    if inv and inv.Toggle then inv:Toggle() end
end

commands.map = function()
    local wm = Azaath:GetModule("WorldMap")
    if wm and wm.Toggle and Azaath.db.worldmap.enabled then wm:Toggle()
    elseif _G.ToggleWorldMap then _G.ToggleWorldMap() end
end

commands.cast = function(arg)
    local castbar = Azaath:GetModule("CastBar")
    if castbar and castbar.Test then
        castbar:Test(arg) -- /azaath cast luz|fogo|gelo|arcano|sombra|vil|natureza|fisico
    end
    local np = Azaath:GetModule("Nameplates")
    if np and np.Test then
        np:Test()
    end
end

commands.plates = function()
    local np = Azaath:GetModule("Nameplates")
    if np and np.OpenDesigner then
        np:OpenDesigner()
    end
end
commands.nameplates = commands.plates
commands.placas = commands.plates

commands.damage = function()
    local ct = Azaath:GetModule("CombatText")
    if ct and ct.Test then
        ct:Test()
    else
        Azaath:Print("Módulo de dano flutuante (CombatText) não encontrado. Reinicie o cliente do World of Warcraft para indexar os novos arquivos.")
    end
end
commands.test = commands.damage
commands.ct = commands.damage

commands.loot = function()
    local loot = Azaath:GetModule("Loot")
    if loot and loot.TestFeed then loot:TestFeed() end
end
commands.loottest = commands.loot

commands.rolls = function()
    local r = Azaath:GetModule("LootRolls")
    if r and r.Preview then r:Preview() end
end

commands.beam = function()
    local beam = Azaath:GetModule("LootBeam")
    if beam and beam.ToggleTest then beam:ToggleTest() end
end
commands.lootbeam = commands.beam

commands.beamdiag = function()
    local beam = Azaath:GetModule("LootBeam")
    if beam and beam.Diag then beam:Diag() end
end

commands.saques = function()
    if Azaath.LootCel and Azaath.LootCel.ToggleJournal then
        Azaath.LootCel.ToggleJournal()
    end
end
commands.journal = commands.saques

commands.celebrate = function(arg)
    local lc = Azaath:GetModule("LootCelebration")
    if lc and lc.Test then lc:Test(arg) end
end
commands.celebrar = commands.celebrate

commands.olho = function(arg)
    local olho = Azaath:GetModule("OlhoAzaath")
    if not olho then return end
    if arg and arg ~= "" then
        if olho.SlashCommand then olho:SlashCommand(arg) end
    else
        if olho.OpenMenu then olho:OpenMenu() end
    end
end

-- Ocultar frames da Blizzard é irreversível sem /reload (os eventos são desregistrados),
-- então este comando alterna a opção e recarrega a UI.
commands.blizz = function(arg)
    local hb = Azaath.db.hideBlizzard
    if arg and arg ~= "" then
        local key = BLIZZ_KEYS[arg]
        if not key then
            Azaath:Print("parte desconhecida '%s'. Use: actionbars, player, target, minimap, buffs.", arg)
            return
        end
        hb[key] = not hb[key]
    else
        local anyHidden = false
        for _, v in pairs(hb) do
            if v then anyHidden = true break end
        end
        for k in pairs(hb) do hb[k] = not anyHidden end
    end
    ReloadUI()
end

-- /azaath cd [nome]: diagnóstico das recargas das barras de ação (ActionBars.lua)
commands.cd = function(arg)
    if Azaath.DebugCooldowns then
        Azaath.DebugCooldowns(arg or "")
    else
        Azaath:Print("barras de ação do AzaathUI desligadas.")
    end
end

-- /azaath perf: quanto de memória Lua e de CPU o AzaathUI usa agora (e os addons que mais pesam).
-- Imprime no chat e grava em AzaathUIDB.perf (vai para o SavedVariables no /reload).
commands.perf = function()
    local A = C_AddOns or {}
    local num = A.GetNumAddOns or GetNumAddOns
    local info = A.GetAddOnInfo or GetAddOnInfo
    local out = { at = date and date("%H:%M:%S") or "", fps = GetFramerate and math.floor(GetFramerate() + 0.5) or nil }
    local c = "|cffe3c78b"

    -- memória Lua de cada addon (texturas ficam na placa de vídeo e não entram aqui)
    local mem, total = {}, 0
    if UpdateAddOnMemoryUsage and GetAddOnMemoryUsage and num and info and pcall(UpdateAddOnMemoryUsage) then
        for i = 1, num() do
            local kb = GetAddOnMemoryUsage(i) or 0
            if kb > 0 then
                local name = info(i)
                mem[#mem + 1] = { name = name, mb = kb / 1024 }
                total = total + kb / 1024
                if name == "AzaathUI" then out.memMB = kb / 1024 end
            end
        end
        table.sort(mem, function(a, b) return a.mb > b.mb end)
    end
    out.memTotalMB = total

    -- CPU: tempo por quadro (ms), pelo perfilador de addons do cliente
    local P = C_AddOnProfiler
    local M = Enum and Enum.AddOnProfilerMetric
    local function metric(addon, key)
        if not (P and M and M[key] ~= nil) then return nil end
        local fn = addon and P.GetAddOnMetric or P.GetOverallMetric
        if not fn then return nil end
        local ok, v
        if addon then ok, v = pcall(fn, addon, M[key]) else ok, v = pcall(fn, M[key]) end
        return ok and type(v) == "number" and v or nil
    end
    out.cpuRecent  = metric("AzaathUI", "RecentAverageTime")
    out.cpuSession = metric("AzaathUI", "SessionAverageTime")
    out.cpuPeak    = metric("AzaathUI", "PeakTime")
    out.cpuAllRecent = metric(nil, "RecentAverageTime")
    out.cpuAllSession = metric(nil, "SessionAverageTime")
    local cpu = {}
    if P and M and num and info then
        for i = 1, num() do
            local name = info(i)
            local v = (A.IsAddOnLoaded or IsAddOnLoaded) and (A.IsAddOnLoaded or IsAddOnLoaded)(name) and metric(name, "SessionAverageTime")
            if v and v > 0 then cpu[#cpu + 1] = { name = name, ms = v } end
        end
        table.sort(cpu, function(a, b) return a.ms > b.ms end)
    end

    Azaath:Print("desempenho (%s, %s FPS):", out.at, tostring(out.fps or "?"))
    if out.memMB then
        DEFAULT_CHAT_FRAME:AddMessage(("%sMemória Lua|r: %.1f MB (todos os addons: %.1f MB)"):format(c, out.memMB, total))
    end
    if out.cpuSession then
        local frameMs = out.fps and out.fps > 0 and 1000 / out.fps or nil
        DEFAULT_CHAT_FRAME:AddMessage(("%sCPU|r: %.2f ms/quadro agora, %.2f na sessão, pico %.1f ms%s"):format(c,
            out.cpuRecent or 0, out.cpuSession, out.cpuPeak or 0,
            frameMs and (" (%.1f%% do quadro)"):format((out.cpuRecent or out.cpuSession) / frameMs * 100) or ""))
        if out.cpuAllSession then
            DEFAULT_CHAT_FRAME:AddMessage(("%sCPU de todos os addons|r: %.2f ms/quadro agora, %.2f na sessão"):format(c,
                out.cpuAllRecent or 0, out.cpuAllSession))
        end
    else
        DEFAULT_CHAT_FRAME:AddMessage(c .. "CPU|r: o cliente não expõe o perfilador de addons.")
    end
    out.memTop, out.cpuTop = {}, {}
    for i = 1, math.min(6, #mem) do
        out.memTop[i] = ("%s %.1f MB"):format(mem[i].name, mem[i].mb)
    end
    for i = 1, math.min(6, #cpu) do
        out.cpuTop[i] = ("%s %.3f ms"):format(cpu[i].name, cpu[i].ms)
    end
    if #out.memTop > 0 then DEFAULT_CHAT_FRAME:AddMessage(c .. "Mais memória|r: " .. table.concat(out.memTop, ", ")) end
    if #out.cpuTop > 0 then DEFAULT_CHAT_FRAME:AddMessage(c .. "Mais CPU (média da sessão)|r: " .. table.concat(out.cpuTop, ", ")) end

    if AzaathUIDB then
        AzaathUIDB.perf = AzaathUIDB.perf or {}
        table.insert(AzaathUIDB.perf, 1, out)
        while #AzaathUIDB.perf > 5 do table.remove(AzaathUIDB.perf) end
    end
end

commands.reset = function()
    Azaath.ResetDB()
    ReloadUI()
end

commands.help = function()
    Azaath:Print("comandos:")
    local c = "|cffe3c78b"
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath|r ou |cffe3c78b/azaath config|r - abre o painel de configuração")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath setup|r ou |cffe3c78b/azaath tutorial|r - assistente Primeiros Passos (módulos Addon/Blizzard, skin, barras, escala)")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath edit|r ou |cffe3c78b/azaath layout|r - modo de edição (mover e redimensionar todos os elementos)")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath reload|r - recarrega a interface")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath toggle|r - mostra/esconde a interface AzaathUI")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath compass|r - liga/desliga a bússola")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath damage|r - dispara teste de dano Azaath (normal e crítico)")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath cast [luz|fogo|gelo|arcano|sombra|vil|natureza]|r - conjuração de teste (posição e efeitos)")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath loot|r - mostra notificações de saque de teste (posicionamento)")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath celebrate [tipo]|r - testa os cards de celebração (epic, legendary, bloated, jackpot, rarekill, skill)")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath saques|r (ou |cffe3c78b/saques|r) - abre as Crônicas de Saque, Pesca e Rolagens")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath olho [comando]|r - abre o Estúdio do Olho de Azaath ou executa subcomando (/olho help)")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath char|r - abre a ficha do personagem (tecla C)")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath bag|r - abre a mochila com o equipamento (tecla B)")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath map|r - abre o mapa-múndi Azaath (tecla M)")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath blizz [actionbars|player|target|minimap|buffs]|r - restaura/oculta frames da Blizzard (recarrega)")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath perf|r - mostra a memória e a CPU que o AzaathUI usa")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath cd [nome]|r - diagnóstico da recarga dos botões das barras")
    DEFAULT_CHAT_FRAME:AddMessage(c .. "/azaath reset|r - volta as configurações DESTE personagem ao padrão (recarrega)")
end

SLASH_AZAATHUI1 = "/azaath"
SlashCmdList["AZAATHUI"] = function(msg)
    local cmd, arg = (msg or ""):lower():match("^%s*(%S*)%s*(.-)%s*$")
    local handler = (cmd == "" and commands.config) or commands[cmd] or commands.help
    handler(arg)
end
