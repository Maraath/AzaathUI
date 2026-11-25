--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Config/Locale.lua
    Textos do painel de configuração em Português (ptBR) e Inglês (enUS).

      * Chave = caminho da opção no banco ("compass.width") ou um prefixo:
        page.* (aba: título, subtítulo), sec.* (seção: título, descrição),
        btn.* (botão: título, descrição, texto do botão), note.*, why.*,
        o.<caminho>=<valor> (escolhas: rótulo, explicação), ui.*, pop.*, msg.*
      * Valor = string ou { rótulo, descrição[, ação] }.
      * Idioma: AzaathUIDB.config.lang = "auto" (segue o cliente), "ptBR" ou
        "enUS". Falta de chave cai no outro idioma e, por último, na própria chave.
      * EDITOR_EN traduz os textos do Modo de Edição (escritos em português no
        Config.lua) pelo próprio texto, sem mexer nas definições dos elementos.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = {}
Azaath.ConfigUI = U

local type = type

local ptBR, enUS = {}, {}
U.STR = { ptBR = ptBR, enUS = enUS }

function U.LangCode()
    local cfg = Azaath.db and Azaath.db.config
    local lang = cfg and cfg.lang
    if lang == "ptBR" or lang == "enUS" then return lang end
    return (GetLocale and GetLocale() == "ptBR") and "ptBR" or "enUS"
end

local function Entry(key)
    local code = U.LangCode()
    local v = U.STR[code][key]
    if v == nil then v = U.STR[code == "ptBR" and "enUS" or "ptBR"][key] end
    return v
end

-- idx: 1 = rótulo, 2 = descrição, 3 = texto do botão
function U.L(key, idx)
    local v = Entry(key)
    if type(v) == "table" then return v[idx or 1] end
    if (idx or 1) == 1 then return v or key end
    return nil
end

function U.Has(key) return Entry(key) ~= nil end

U.EDITOR_EN = {}
function U.Tr(s)
    if s == nil or U.LangCode() ~= "enUS" then return s end
    return U.EDITOR_EN[s] or s
end

--==============================================================================
-- PORTUGUÊS
--==============================================================================
local P = ptBR

-- Interface do painel
P["ui.title"]        = "AzaathUI"
P["ui.subtitle"]     = "Configurações"
P["ui.editMode"]     = "Modo de Edição"
P["ui.editModeTip"]  = { "Modo de Edição", "Fecha este painel e mostra todos os elementos da interface com alças: arraste para mover, puxe o canto para redimensionar, gire a roda do mouse para mudar a escala e clique para ajustes finos." }
P["ui.close"]        = "Fechar"
P["ui.search"]       = "Buscar opção..."
P["ui.noResults"]    = "Nenhuma opção encontrada para \"%s\"."
P["ui.pending"]      = "Há mudanças que só valem depois de recarregar."
P["ui.reloadNow"]    = "Recarregar agora"
P["ui.legendReload"] = "Requer recarregar a interface (/reload)"
P["ui.legendHelp"]   = "Passe o mouse sobre qualquer opção para ver a explicação completa"
P["ui.resetSection"] = "Restaurar seção"
P["ui.resetSectionTip"] = { "Restaurar seção", "Volta todas as opções desta seção para o valor padrão. Pede confirmação antes." }
P["ui.default"]      = "Padrão: %s"
P["ui.on"]           = "Ligado"
P["ui.off"]          = "Desligado"
P["ui.reloadTip"]    = "Só vale depois de recarregar a interface."
P["ui.needs"]        = "Disponível ao ativar: %s"
P["ui.wheelTip"]     = "Arraste o losango, use - e + para um passo ou clique no número para digitar."
P["ui.stubInfo"]     = "As opções ficam em uma janela própria. Atalhos: /azaath e /azaath edit"
P["ui.stubOpen"]     = "Abrir configurações"
P["ui.stubEdit"]     = "Modo de Edição"
P["ui.langShort.ptBR"] = "PT"
P["ui.langShort.enUS"] = "EN"
P["ui.langTip"]      = { "Idioma do painel", "Troca o idioma deste painel na hora. A escolha fica salva; em Geral > Idioma dá para voltar a seguir o idioma do jogo." }

-- Diálogos e mensagens
P["pop.skin"]      = "A skin muda o visual dos quadros e só fica completa depois de recarregar a interface.\nRecarregar agora?"
P["pop.bars"]      = "A disposição das barras muda a forma dos botões e só fica completa depois de recarregar a interface.\nRecarregar agora?"
P["pop.reset"]     = "Restaurar TODAS as configurações do AzaathUI deste personagem para o padrão?\nA interface será recarregada."
P["pop.resetElements"] = "Voltar a posição e o tamanho de todos os elementos para o padrão?"
P["pop.section"]   = "Restaurar os padrões da seção \"%s\"?"
P["pop.reloadNow"] = "Recarregar"
P["pop.later"]     = "Depois"
P["pop.yes"]       = "Sim"
P["pop.no"]        = "Não"
P["msg.bdoPreset"] = "Preset de câmera Black Desert aplicado (ombro 0.45, inclinação 0.45, tremor, inércia e zoom dinâmico)."
P["msg.sectionReset"] = "Seção \"%s\" restaurada."

-- Motivos de indisponibilidade
P["why.bdo"]       = "Só vale com a skin Zerker."
P["why.azaath"]    = "Só vale com a skin Azaath Reforged."
P["why.xpAuto"]    = "Desligue a largura automática para definir uma largura fixa."
P["why.ring"]      = "Só vale com o estilo Espiral."
P["why.bar"]       = "Só vale com o estilo Barra horizontal."

-- Abas
P["page.general"]    = { "Geral", "Idioma, escala, edição de layout e manutenção." }
P["page.character"]  = { "Personagem & HUD", "Skin, vida e recurso, experiência e efeitos do seu personagem." }
P["page.actionbars"] = { "Barras de Ação", "Disposição, tamanho dos botões, postura, pet e menu de utilidades." }
P["page.target"]     = { "Alvo & Inimigos", "Quadro do alvo, efeitos do alvo e placas sobre a cabeça." }
P["page.combat"]     = { "Combate", "Conjuração do jogador, do alvo e dos objetos, e dano flutuante." }
P["page.party"]      = { "Grupo", "Quadros dos membros do grupo." }
P["page.map"]        = { "Mapa & Missões", "Bússola, minimapa, mapa-múndi, navegação e rastreador de missões." }
P["page.loot"]       = { "Saque", "Janela de saque, notificações e facho de luz nos corpos." }
P["page.npc"]        = { "NPCs & Diálogos", "Conversas, câmera cinematográfica e mercadores." }
P["page.inventory"]  = { "Inventário & Janelas", "Mochila, personagem, ficha, talentos, livro e ofícios." }
P["page.auction"]    = { "Casa de Leilões", "Preço de leilão no card de item." }
P["page.chat"]       = { "Chat", "Aparência e comportamento da janela de conversa." }
P["page.actioncam"]  = { "Câmera Action", "Mouse Look, mira, alvo, clique e efeitos de câmera." }
P["page.olho"]       = { "Olho de Azaath", "Brilho nos objetos do mundo e ícones de coleta no minimapa." }
P["page.advanced"]   = { "Avançado", "Quadros originais da Blizzard e aparência geral." }

-- Geral ----------------------------------------------------------------------
P["sec.language"]    = { "Idioma", "Escolha o idioma deste painel." }
P["config.lang"]     = { "Idioma do painel", "Automático segue o idioma do cliente do jogo. Escolher Português ou English fixa o idioma, mesmo que o jogo esteja em outro." }
P["o.config.lang=auto"] = { "Automático", "Segue o idioma do cliente (Português se o jogo estiver em ptBR, senão English)." }
P["o.config.lang=ptBR"] = { "Português", "Painel sempre em português." }
P["o.config.lang=enUS"] = { "English", "Painel sempre em inglês." }
P["sec.interface"]   = { "Interface", "Visibilidade e tamanho geral." }
P["enabled"]         = { "Mostrar a interface AzaathUI", "Esconde ou mostra todos os elementos da AzaathUI de uma vez (o mesmo que /azaath toggle). Útil para prints ou para comparar com a interface original." }
P["scale"]           = { "Escala geral da HUD", "Multiplica o tamanho de todos os elementos da AzaathUI. Aumente em monitores grandes ou 4K; diminua em telas pequenas para liberar espaço." }
P["config.scale"]    = { "Tamanho deste painel", "Aumenta ou diminui só esta janela de configuração. Não afeta o jogo." }
P["sec.layout"]      = { "Posições e tamanhos", "Mova e redimensione os elementos direto na tela." }
P["note.editMode"]   = "No Modo de Edição você arrasta qualquer elemento, puxa o canto para redimensionar, gira a roda do mouse para mudar a escala e clica para abrir o Inspetor com ajuste fino. Atalho: /azaath edit."
P["btn.editMode"]    = { "Modo de Edição Visual", "Mostra alças sobre todos os elementos para mover e redimensionar com o mouse.", "Abrir editor" }
P["btn.resetElements"] = { "Posições de fábrica", "Volta posição e tamanho de todos os elementos para o padrão. As demais opções continuam como estão.", "Restaurar" }
P["sec.maintenance"] = { "Manutenção", "Recarregar e restaurar." }
P["btn.reload"]      = { "Recarregar a interface", "Aplica as mudanças marcadas com o losango laranja (o mesmo que /reload).", "Recarregar" }
P["btn.factoryReset"] = { "Restaurar padrões de fábrica", "Apaga TODAS as configurações da AzaathUI e recarrega. Use se algo ficou estranho e você quer começar do zero.", "Restaurar tudo" }

-- Personagem -------------------------------------------------------------------
P["sec.skin"]        = { "Skin", "Visual da barra de tarefas e do quadro do personagem." }
P["skin"]            = { "Skin da Azaath UI", "Muda só as barras de ação e o quadro do personagem (vida, recurso e XP); o resto da interface fica igual. Recarrega ao trocar." }
P["o.skin=modern"]   = { "Azaath", "Recurso e vida no centro inferior, losango de nível e XP sob a vida." }
P["o.skin=azaath"]   = { "Azaath Reforged", "Vida, recurso e XP na moldura central com o medalhão do nível. Buffs acompanham a HUD. Combina com as barras Reforged." }
P["o.skin=blizzard"] = { "Blizzard", "Quadros de vida do jogador e do alvo padrão do jogo. Barras, buffs e o resto da interface seguem o Azaath." }
P["o.skin=bdo"]      = { "Zerker", "Quadro no canto superior esquerdo: losango com nível e XP pela borda, vida vermelha e recurso em seta. Barras e buffs ficam livres." }
P["sec.zerker"]      = { "Quadro Zerker", "Ajustes do quadro da skin Zerker." }
P["bdo.scale"]       = { "Escala do quadro", "Tamanho do quadro Zerker no canto superior esquerdo." }
P["bdo.offsetX"]     = { "Distância da borda esquerda", "Afasta o quadro da borda esquerda da tela." }
P["bdo.offsetY"]     = { "Distância do topo", "Afasta o quadro do topo da tela." }
P["sec.reforged"]    = { "HUD Azaath Reforged", "Ajustes da HUD central da skin Reforged." }
P["azaath.scale"]    = { "Escala da HUD", "Tamanho de toda a HUD (barras, vida e medalhão). Buffs e debuffs acompanham." }
P["azaath.offsetY"]  = { "Altura da HUD", "Distância da HUD até a base da tela. Suba se ela cobrir o chat ou outros addons." }
P["azaath.glow"]     = { "Gemas pulsando", "Faz as gemas e filetes ciano da moldura pulsarem suavemente. Desligue se preferir uma HUD mais estática." }
P["sec.player"]      = { "Vida e recurso do jogador", "Barra de vida e de mana/energia/fúria." }
P["unitframes.player.enabled"] = { "Ativar barras do jogador", "Substitui o quadro do jogador da Blizzard pelas barras no estilo Azaath." }
P["unitframes.player.fadeOutOfCombat"] = { "Transparente fora de combate", "A barra fica discreta enquanto você não está lutando e volta ao normal no combate. Não vale na HUD Azaath." }
P["unitframes.player.scale"]        = { "Escala", "Tamanho do conjunto de vida e recurso." }
P["unitframes.player.width"]        = { "Largura", "Comprimento das barras de vida e recurso." }
P["unitframes.player.healthHeight"] = { "Altura da vida", "Espessura da barra de vida." }
P["unitframes.player.powerHeight"]  = { "Altura do recurso", "Espessura da barra de mana/energia/fúria." }
P["unitframes.player.healthFont"]   = { "Tamanho do texto de vida", "Tamanho dos números de vida sobre a barra." }
P["unitframes.player.offsetX"]      = { "Posição horizontal", "Desloca para a esquerda (negativo) ou direita (positivo) a partir do centro." }
P["unitframes.player.offsetY"]      = { "Distância da base", "Altura das barras em relação à parte de baixo da tela." }
P["sec.xp"]          = { "Experiência (XP)", "Barra de experiência no rodapé." }
P["experience.enabled"]   = { "Ativar barra de XP e selo de nível", "Mostra o progresso até o próximo nível e o losango com o seu nível." }
P["experience.showAtMax"] = { "Mostrar no nível máximo", "Mantém a barra visível mesmo sem XP para ganhar (no nível máximo ela some por padrão)." }
P["experience.autoWidth"] = { "Largura automática", "A barra estica de ponta a ponta na base da tela. Desligue para escolher uma largura fixa." }
P["experience.width"]     = { "Largura fixa", "Comprimento da barra quando a largura automática está desligada." }
P["experience.height"]    = { "Altura", "Espessura da barra de XP." }
P["experience.segments"]  = { "Divisões", "Quantos segmentos marcam a barra (ajuda a estimar quanto falta)." }
P["experience.scale"]     = { "Escala", "Tamanho da barra de XP." }
P["experience.offsetX"]   = { "Posição horizontal", "Desloca a barra a partir do centro da tela." }
P["experience.offsetY"]   = { "Distância da base", "Altura da barra em relação à parte de baixo da tela." }
P["sec.badge"]       = { "Selo de nível", "Losango com o seu nível." }
P["experience.showBadge"]  = { "Mostrar selo de nível", "Exibe o losango com o número do seu nível junto da barra de XP." }
P["experience.badgeSize"]  = { "Tamanho do selo", "Tamanho do losango em pixels." }
P["experience.badgeScale"] = { "Escala do selo", "Multiplica o tamanho do losango." }
P["sec.buffs"]       = { "Buffs do jogador", "Efeitos positivos ativos em você." }
P["note.aurasAzaath"] = "Na skin Azaath Reforged os buffs e debuffs ficam presos à HUD e acompanham a escala dela."
P["auras.playerBuffs.enabled"]        = { "Ativar buffs", "Mostra os seus buffs no estilo Azaath no lugar dos da Blizzard." }
P["auras.playerBuffs.weaponEnchants"] = { "Encantamentos de arma", "Inclui venenos, pedras de afiar e outros encantamentos temporários de arma." }
P["auras.playerBuffs.scale"]   = { "Escala", "Tamanho do grupo de buffs." }
P["auras.playerBuffs.size"]    = { "Tamanho dos ícones", "Tamanho de cada ícone em pixels." }
P["auras.playerBuffs.spacing"] = { "Espaçamento", "Espaço entre os ícones." }
P["auras.playerBuffs.perRow"]  = { "Ícones por linha", "Quantos ícones antes de quebrar para a linha de baixo." }
P["sec.debuffs"]     = { "Debuffs do jogador", "Efeitos negativos ativos em você." }
P["auras.playerDebuffs.enabled"] = { "Ativar debuffs", "Mostra os debuffs que estão em você, com a borda colorida pelo tipo (magia, veneno, doença...)." }
P["auras.playerDebuffs.scale"]   = { "Escala", "Tamanho do grupo de debuffs." }
P["auras.playerDebuffs.size"]    = { "Tamanho dos ícones", "Tamanho de cada ícone em pixels." }
P["auras.playerDebuffs.spacing"] = { "Espaçamento", "Espaço entre os ícones." }
P["auras.playerDebuffs.perRow"]  = { "Ícones por linha", "Quantos ícones antes de quebrar para a linha de baixo." }

-- Barras de ação ---------------------------------------------------------------
P["sec.barLayout"]   = { "Disposição", "Formato e posição das barras de ação." }
P["actionbars.layout"] = { "Disposição das barras", "Escolhe o desenho das barras de ação. Recarrega ao trocar." }
P["o.actionbars.layout=bdo"]   = { "Losyx", "Losangos em grupos de quatro no centro e asas de seis botões de cada lado." }
P["o.actionbars.layout=split"] = { "NextGen", "Duas barras de 12 teclas, uma em cada borda, em octógonos com faixa de vidro." }
P["o.actionbars.layout=az"]    = { "Minimalist", "Barra 1 à direita e barra 2 à esquerda da vida, como no Azaath." }
P["o.actionbars.layout=blizzard"] = { "Blizzard", "Barras de ação padrão do jogo, com o micromenu e as bolsas delas; o micromenu do Azaath some." }
P["o.actionbars.layout=reforged"] = { "Reforged", "Painéis da arte Azaath Reforged: barra 1 à direita, barra 2 à esquerda com as abas de postura. Cada painel se move à parte."  }
P["sec.rotation"] = { "Assistente de rotação", "Só para Guerreiro por enquanto. Acende na barra o Brado de Batalha e as habilidades situacionais." }
P["actionbars.rotation.enabled"] = { "Ligar assistente", "Faz brilhar Executar, Sobrepujar, Revanche, Ímpeto da Vitória, procs (Golpe, Batida com Escudo) e interrupções quando ficam disponíveis." }
P["actionbars.rotation.shout"] = { "Lembrar do Brado de Batalha", "O botão do Brado brilha em vermelho enquanto você está sem o efeito." }
P["actionbars.rotation.sound"] = { "Som de aviso", "Toca um som leve quando uma habilidade situacional acende." }
P["actionbars.rotation.castSounds"] = { "Vozes ao usar habilidades", "Luz de Elluna diz \"testemunhem o poder de Eluna\"." }
P["actionbars.rotation.volume"] = { "Volume dos sons", "1x = normal. 2x e 3x tocam o som em camadas para ficar mais alto que o limite do arquivo; em 3x pode distorcer." }
P["actionbars.rotation.castSfx"] = { "Efeitos sonoros das habilidades", "Golpe Heroico, Cutilada, Batida, Subjugar, Executar e os três brados trocam o som original do jogo por um efeito próprio (o original fica mudo só no instante do seu uso)." }
P["sec.barsGeneral"] = { "Geral", "Vale para todas as barras." }
P["actionbars.enabled"]     = { "Ativar barras de ação AzaathUI", "Substitui as barras da Blizzard pelas da AzaathUI." }
P["actionbars.showHotkeys"] = { "Mostrar teclas de atalho", "Escreve a tecla de cada botão. Desligue se você já decorou e prefere um visual limpo." }
P["actionbars.bagButton"]   = { "Botão da mochila", "Mostra um botão para abrir o inventário junto das barras." }
P["actionbars.bars"]        = { "Barras visíveis", "Quantas barras (1 a 3) aparecem na tela." }
P["actionbars.spacing"]     = { "Espaçamento entre botões", "Espaço entre um botão e outro." }
P["actionbars.buttonSize"]  = { "Tamanho dos botões da barra 1", "Tamanho dos botões principais. Zera o ajuste individual da barra 1 feito no Modo de Edição." }
P["actionbars.smallSize"]   = { "Tamanho dos botões das barras 2 e 3", "Tamanho dos botões secundários. Zera o ajuste individual das barras 2 e 3." }
P["actionbars.offsetX"]     = { "Posição horizontal", "Desloca todas as barras a partir do centro." }
P["actionbars.offsetY"]     = { "Distância da base", "Altura das barras em relação à parte de baixo da tela." }
P["sec.barsEach"]    = { "Ajuste por barra", "Escala e colunas de cada barra (0 colunas = padrão da disposição)." }
P["actionbars.bar1.scale"] = { "Barra 1: escala", "Tamanho só da barra 1." }
P["actionbars.bar1.cols"]  = { "Barra 1: botões por linha", "Quantos botões por linha na barra 1. 0 usa o padrão da disposição." }
P["actionbars.bar2.scale"] = { "Barra 2: escala", "Tamanho só da barra 2." }
P["actionbars.bar2.cols"]  = { "Barra 2: botões por linha", "Quantos botões por linha na barra 2. 0 usa o padrão da disposição." }
P["actionbars.bar3.scale"] = { "Barra 3: escala", "Tamanho só da barra 3." }
P["actionbars.bar3.cols"]  = { "Barra 3: botões por linha", "Quantos botões por linha na barra 3. 0 usa o padrão da disposição." }
P["sec.stancePet"]   = { "Postura e pet", "Barras de forma/postura e de comandos do ajudante." }
P["actionbars.stance.enabled"]    = { "Barra de postura/forma", "Botões de posturas do guerreiro, formas do druida, presenças etc." }
P["actionbars.stance.buttonSize"] = { "Tamanho dos botões de postura", "Tamanho de cada botão de postura." }
P["actionbars.stance.scale"]      = { "Escala da barra de postura", "Tamanho do conjunto de posturas." }
P["actionbars.pet.enabled"]       = { "Barra de pet", "Comandos do ajudante (atacar, seguir, habilidades do pet)." }
P["actionbars.pet.buttonSize"]    = { "Tamanho dos botões de pet", "Tamanho de cada botão de pet." }
P["actionbars.pet.scale"]         = { "Escala da barra de pet", "Tamanho do conjunto de pet." }
P["sec.micromenu"]   = { "Menu de utilidades", "Botões de personagem, feitiços, talentos, missões, menu etc." }
P["micromenu.enabled"]    = { "Ativar menu de utilidades", "Mostra a barra com os atalhos para as janelas do jogo." }
P["micromenu.style"]      = { "Estilo do menu de utilidades", "Visual da barra de atalhos e dos placares de informação." }
P["o.micromenu.style=bdo"]      = { "Minimalista", "Visual atual discreto: discos translúcidos, glifos limpos e losango central." }
P["o.micromenu.style=azaath"]   = { "Azaath Arcano", "Doca de obsidiana e ouro velho com ponteiras em cristal ciano e placar arcano." }
P["o.micromenu.style=numenor"]  = { "Forja de Númenor", "Ardósia negra, bronze oxidado, ícones gravados a buril e brilho de brasa." }
P["o.micromenu.style=tabletop"] = { "Mesa de RPG (WoW)", "Pedra cinzelada, slots retrato 3D, ícones coloridos, barra de latência e pergaminho." }
P["micromenu.buttonSize"] = { "Tamanho dos botões", "Tamanho de cada atalho." }
P["micromenu.spacing"]    = { "Espaçamento", "Espaço entre os atalhos." }
P["micromenu.scale"]      = { "Escala", "Tamanho de toda a barra." }
P["micromenu.offsetX"]    = { "Posição horizontal", "Desloca a barra para os lados." }
P["micromenu.offsetY"]    = { "Posição vertical", "Desloca a barra para cima ou para baixo." }
P["micromenu.idleAlpha"]  = { "Opacidade em repouso", "Quão visível a barra fica sem o mouse em cima. Valores baixos deixam a tela mais limpa." }

-- Alvo -------------------------------------------------------------------------
P["sec.targetFrame"] = { "Quadro do alvo", "Vida e nome de quem você selecionou." }
P["unitframes.target.enabled"]      = { "Ativar quadro do alvo", "Substitui o quadro de alvo da Blizzard pelo do estilo Azaath." }
P["unitframes.target.scale"]        = { "Escala", "Tamanho do quadro do alvo." }
P["unitframes.target.width"]        = { "Largura", "Comprimento da barra de vida do alvo." }
P["unitframes.target.healthHeight"] = { "Altura da vida", "Espessura da barra de vida do alvo." }
P["unitframes.target.nameFont"]     = { "Tamanho do nome", "Tamanho do nome do alvo." }
P["unitframes.target.offsetX"]      = { "Posição horizontal", "Desloca o quadro a partir do centro." }
P["unitframes.target.offsetY"]      = { "Distância do topo", "Distância do quadro até o topo da tela." }
P["sec.targetAuras"] = { "Efeitos do alvo", "Buffs e debuffs de quem você selecionou." }
P["auras.target.enabled"]  = { "Ativar efeitos do alvo", "Mostra buffs e debuffs do alvo junto do quadro dele." }
P["auras.target.onlyMine"] = { "Só os meus debuffs", "Esconde os debuffs de outros jogadores. Bom para acompanhar seus DoTs em raides." }
P["auras.target.scale"]    = { "Escala", "Tamanho do grupo de ícones." }
P["auras.target.size"]     = { "Tamanho dos ícones", "Tamanho de cada ícone em pixels." }
P["auras.target.spacing"]  = { "Espaçamento", "Espaço entre os ícones." }
P["sec.nameplates"]  = { "Placas sobre a cabeça", "Barras de vida e nomes que aparecem sobre inimigos e aliados." }
P["nameplates.enabled"]           = { "Placas no estilo Azaath", "Inimigos com nome espaçado, barra fina, losango de nível e asas nas elites." }
P["nameplates.style"]             = { "Estilo das placas", "Visual das placas de inimigo. Em todas: o alvo fica maior com nome dourado e mob com aggro em você ganha uma aura vermelha. Recarrega ao trocar." }
P["o.nameplates.style=auto"]   = { "Conforme a skin", "Zerker usa a minimalista; Azaath e Reforged usam a Azaath." }
P["o.nameplates.style=azaath"] = { "Azaath", "Nome espaçado, barra em pincel e tinta, losango de nível e asas nas elites." }
P["o.nameplates.style=zerker"] = { "Zerker", "Barra em paralelogramo com a mesma arte líquida da vida do quadro." }
P["o.nameplates.style=blizzard"] = { "Blizzard", "Placas de nome padrão do jogo, sem os marcadores, molduras e efeitos do Azaath." }
P["o.nameplates.style=minimal"] = { "Minimalista", "Como no Black Desert: nome pequeno e barra fina arredondada." }
P["nameplates.castBar"]           = { "Conjuração nos inimigos", "Barra de conjuração sob a placa do inimigo, para saber o que interromper." }
P["nameplates.allies"]            = { "Aliados no estilo Azaath", "Jogadores aliados com losango de nível e nome." }
P["nameplates.friendlyClickable"] = { "Selecionar aliados pela placa", "Permite clicar na placa de um aliado para selecioná-lo. Desligue se ela atrapalhar cliques no mundo." }
P["nameplates.utilityNPCs"]       = { "Placas de NPCs de serviço", "Leiloeiro, conserto, estalajadeiro, vendedores e quem dá missões ganham placa própria." }
P["nameplates.pets"]              = { "Pets no estilo Azaath", "Pets aliados com uma placa menor." }
P["nameplates.hideWorldNames"]    = { "Esconder nomes do WoW ao longe", "Tira os nomes padrão do jogo de aliados e pets para não duplicar com as placas." }
P["nameplates.width"]             = { "Largura das placas", "Comprimento da barra de vida dos inimigos." }
P["nameplates.allyOffsetY"]       = { "Altura da placa dos aliados", "Aproxima (negativo) ou afasta a placa da cabeça do aliado." }
P["btn.openPlatesDesigner"] = { "Personalizar tudo (Designer Visual)", "Abre o editor completo de placas com prévia ao vivo, auras, execute, ameaça, cores, perfis e importação (/azplates).", "Abrir Designer" }
P["btn.testPlates"]  = { "Testar placas", "Simula uma conjuração nas placas visíveis.", "Testar" }

-- Combate ----------------------------------------------------------------------
P["sec.castPlayer"]  = { "Conjuração do jogador", "Barra ou espiral que mostra suas magias sendo lançadas." }
P["castbar.player.enabled"]  = { "Ativar conjuração do jogador", "Mostra o progresso das suas magias no estilo AzaathUI." }
P["castbar.player.style"]    = { "Estilo", "Espiral (como no Azaath) ou barra horizontal. Recarrega ao trocar." }
P["o.castbar.player.style=ring"] = { "Espiral", "Anel que se preenche em volta do ícone da magia." }
P["o.castbar.player.style=bar"]  = { "Barra horizontal", "Barra reta com ícone e zona de latência." }
P["castbar.player.effects"]  = { "Efeitos da escola de magia", "Brilho com a cor da escola (luz, fogo, gelo, sombra...) durante a conjuração." }
P["castbar.player.ringSize"] = { "Tamanho da espiral", "Diâmetro do anel de conjuração." }
P["castbar.player.showLatency"] = { "Mostrar latência", "Pinta o fim da barra com a sua latência: pode apertar a próxima magia quando entrar nessa zona." }
P["castbar.player.scale"]    = { "Escala", "Tamanho da conjuração." }
P["castbar.player.width"]    = { "Largura", "Comprimento da barra." }
P["castbar.player.height"]   = { "Altura", "Espessura da barra." }
P["castbar.player.offsetX"]  = { "Posição horizontal", "Desloca a partir do centro." }
P["castbar.player.offsetY"]  = { "Posição vertical", "Desloca para cima ou para baixo." }
P["btn.testCast"]    = { "Testar conjuração", "Mostra uma conjuração de exemplo no jogador, no alvo e nas placas.", "Testar" }
P["sec.castWorld"]   = { "Interação com objetos", "Coleta de ervas, minérios, baús e objetos de missão." }
P["castbar.world.enabled"]      = { "Espiral sobre o objeto", "Ao coletar ou abrir algo, a espiral aparece em cima do objeto em vez de no personagem." }
P["castbar.world.size"]         = { "Tamanho do anel", "Diâmetro da espiral sobre o objeto." }
P["castbar.world.plateOffsetY"] = { "Posição vertical", "Sobe ou desce a espiral em relação ao objeto (negativo desce)." }
P["sec.castTarget"]  = { "Conjuração do alvo", "Barra com o que o seu alvo está lançando." }
P["castbar.target.enabled"] = { "Ativar conjuração do alvo", "Mostra as magias do alvo para você saber quando interromper." }
P["castbar.target.scale"]   = { "Escala", "Tamanho da barra do alvo." }
P["castbar.target.width"]   = { "Largura", "Comprimento da barra." }
P["castbar.target.height"]  = { "Altura", "Espessura da barra." }
P["castbar.target.offsetX"] = { "Posição horizontal", "Desloca a partir do centro." }
P["castbar.target.offsetY"] = { "Posição vertical", "Desloca para cima ou para baixo." }
P["sec.combatText"]  = { "Dano flutuante", "Números de dano saindo do alvo, no estilo Azaath." }
P["combattext.enabled"]      = { "Ativar dano flutuante", "Mostra o dano que você causa ao lado do alvo, com críticos em laranja." }
P["combattext.hideBlizzard"] = { "Esconder o dano da Blizzard", "Desliga os números padrão do jogo para não aparecer dano duplicado." }
P["combattext.showIcons"]    = { "Ícones do tipo de dano", "Desenha corte, perfuração, fogo etc. ao lado do número." }
P["combattext.onlyMine"]     = { "Só o meu dano", "Esconde o dano que os aliados causam no seu alvo." }
P["combattext.showPet"]      = { "Dano do pet", "Inclui o dano causado pelo seu ajudante." }
P["combattext.showPeriodic"] = { "Dano contínuo", "Inclui DoTs, venenos e sangramentos (gera mais números na tela)." }
P["combattext.showMiss"]     = { "Mostrar falhas", "Mostra Esquiva, Aparo e Erro quando o golpe não acerta." }
P["combattext.normalSize"]   = { "Tamanho do dano normal", "Tamanho da fonte dos acertos comuns." }
P["combattext.critSize"]     = { "Tamanho do crítico", "Tamanho da fonte dos acertos críticos." }
P["combattext.offsetX"]      = { "Distância do alvo", "Quão à direita do alvo os números nascem." }
P["combattext.duration"]     = { "Duração", "Por quanto tempo cada número fica visível." }
P["combattext.floatDistance"] = { "Distância de subida", "Quanto o número sobe enquanto desaparece." }
P["combattext.scale"]        = { "Escala geral", "Multiplica o tamanho de todos os números." }
P["btn.testDamage"]  = { "Testar dano", "Mostra um acerto normal (65) e um crítico (84) na tela.", "Testar" }

-- Grupo ------------------------------------------------------------------------
P["sec.party"]       = { "Quadros de grupo", "Vida dos membros do seu grupo." }
P["note.party"]      = "Clique: seleciona. Clique do meio: foco. Clique direito: menu (sussurrar, inspecionar, negociar e, se você for o líder, promover ou remover)."
P["party.enabled"]    = { "Ativar quadros de grupo AzaathUI", "Substitui os quadros de grupo da Blizzard." }
P["party.classColor"] = { "Vida na cor da classe", "Pinta a barra de cada membro com a cor da classe dele." }
P["party.showInRaid"] = { "Mostrar também em raides", "Mantém os quadros visíveis dentro de raides (mostra o seu subgrupo)." }
P["party.scale"]      = { "Escala", "Tamanho dos quadros." }
P["party.width"]      = { "Largura", "Comprimento de cada quadro." }
P["party.barHeight"]  = { "Altura da vida", "Espessura da barra de vida." }
P["party.spacing"]    = { "Espaço entre membros", "Distância vertical entre um membro e outro." }
P["party.offsetX"]    = { "Distância da esquerda", "Afasta os quadros da borda esquerda." }
P["party.offsetY"]    = { "Distância do topo", "Afasta os quadros do topo da tela." }

-- Mapa e missões ---------------------------------------------------------------
P["sec.compass"]     = { "Bússola", "Faixa de rumo no topo da tela." }
P["compass.enabled"]     = { "Ativar bússola", "Mostra a bússola do Azaath com pontos cardeais e o pino da missão em foco." }
P["compass.showZone"]    = { "Nome da zona", "Placa dourada com o nome da área atual sob a bússola." }
P["compass.showDegrees"] = { "Rumo em graus", "Mostra o ângulo numérico do seu rumo (o Azaath não mostra)." }
P["compass.scale"]       = { "Escala", "Tamanho da bússola." }
P["compass.width"]       = { "Largura", "Comprimento da faixa da bússola." }
P["compass.height"]      = { "Altura", "Espessura da faixa." }
P["compass.fov"]         = { "Campo de visão", "Quantos graus cabem na bússola de ponta a ponta. Menos graus = marcas mais espaçadas." }
P["compass.offsetX"]     = { "Posição horizontal", "Desloca a bússola a partir do centro." }
P["compass.offsetY"]     = { "Distância do topo", "Afasta a bússola do topo da tela." }
P["sec.minimap"]     = { "Minimapa", "Mapa pequeno no canto da tela." }
P["minimap.enabled"]    = { "Ativar minimapa AzaathUI", "Substitui o minimapa da Blizzard." }
P["minimap.square"]     = { "Formato quadrado", "Minimapa quadrado em vez de redondo." }
P["minimap.showCoords"] = { "Coordenadas", "Mostra as suas coordenadas no minimapa." }
P["minimap.showClock"]  = { "Relógio", "Mostra a hora no minimapa." }
P["minimap.scale"]      = { "Escala", "Tamanho do minimapa." }
P["minimap.size"]       = { "Tamanho", "Largura e altura do mapa em pixels." }
P["minimap.offsetX"]    = { "Posição horizontal", "Desloca a partir do canto superior direito." }
P["minimap.offsetY"]    = { "Posição vertical", "Desloca a partir do canto superior direito." }
P["sec.worldmap"]    = { "Mapa-múndi", "Mapa grande (tecla M)." }
P["worldmap.enabled"] = { "Mapa-múndi da AzaathUI", "Usa o mapa próprio da AzaathUI na tecla do mapa. Desligado, abre o mapa da Blizzard." }
P["note.worldmap"]   = "Filtros do mapa (ervas, minérios, masmorras, voo, áreas de missão, terreno) ficam na barra superior do próprio mapa."
P["sec.questNav"]    = { "Navegação de missões", "Marcadores e guia até os objetivos." }
P["questnav.enabled"]     = { "Navegação de missões", "Sistema de navegação até a missão em foco." }
P["questnav.worldMarker"] = { "Marcador 3D no mundo", "Losango sobre o objetivo com distância e indicação de dentro/fora/acima." }
P["questnav.compassPin"]  = { "Pino na bússola", "Mostra a missão em foco como um pino na bússola." }
P["questnav.magicPath"]   = { "Caminho mágico", "Desenha uma trilha caminhável até o objetivo, contornando obstáculos. Precisa dos addons de rota (AzaathUI_Nav_EK/Kalimdor) habilitados." }
P["questroute.autoAdvance"] = { "Avanço automático", "O guia passa sozinho para o próximo passo quando você conclui o atual." }
P["questroute.autoQuest"]   = { "Aceitar e entregar sozinho", "Aceita e entrega missões automaticamente ao falar com NPCs. Segure Shift para pausar." }
P["sec.questTracker"] = { "Rastreador de missões", "Lista de missões acompanhadas na lateral." }
P["note.questTracker"] = "Clique numa missão para abri-la no registro; clique direito para parar de acompanhar. Clique no título MISSÕES para recolher."
P["questtracker.enabled"]          = { "Ativar rastreador AzaathUI", "Substitui o rastreador de missões da Blizzard." }
P["questtracker.showAchievements"] = { "Conquistas acompanhadas", "Inclui as conquistas que você está acompanhando." }
P["questtracker.customPos"]        = { "Posição livre", "Solta o rastreador do minimapa para posicioná-lo onde quiser." }
P["questtracker.transparentBg"]    = { "Fundo transparente", "Remove o painel escuro atrás da lista." }
P["questtracker.scale"]     = { "Escala", "Tamanho do rastreador." }
P["questtracker.width"]     = { "Largura", "Largura da lista." }
P["questtracker.maxHeight"] = { "Altura máxima", "Altura máxima antes de rolar a lista." }
P["questtracker.offsetX"]   = { "Posição horizontal", "Desloca o rastreador (com posição livre)." }
P["questtracker.offsetY"]   = { "Distância do topo", "Afasta o rastreador do topo (com posição livre)." }

-- Saque ------------------------------------------------------------------------
P["sec.lootWindow"]  = { "Janela de saque", "O que acontece ao saquear um corpo ou baú." }
P["loot.enabled"]      = { "Saque no estilo Azaath", "Janela de saque própria da AzaathUI." }
P["loot.autoLoot"]     = { "Saque automático", "Pega tudo sem abrir janela, como no Azaath. Segurar Shift ao saquear inverte o modo." }
P["loot.showWhenFull"] = { "Abrir se sobrar item", "Com o inventário cheio, abre a janela para você escolher o que deixar." }
P["loot.scale"]   = { "Escala da janela", "Tamanho da janela de saque." }
P["loot.width"]   = { "Largura da janela", "Largura da janela de saque." }
P["loot.offsetX"] = { "Posição horizontal", "Desloca a janela a partir do centro." }
P["loot.offsetY"] = { "Posição vertical", "Desloca a janela para cima ou para baixo." }
P["sec.lootFeed"]    = { "Notificações", "Avisos \"+1 item\" do que você recebeu." }
P["loot.feed"]         = { "Notificações de itens", "Mostra cada item, ouro ou moeda recebido em uma faixa na tela." }
P["loot.feedDuration"] = { "Tempo na tela", "Quanto tempo cada aviso fica visível." }
P["loot.feedMax"]      = { "Máximo ao mesmo tempo", "Quantos avisos cabem empilhados." }
P["loot.feedScale"]    = { "Escala", "Tamanho dos avisos." }
P["loot.feedX"]        = { "Posição horizontal", "Desloca os avisos para os lados." }
P["loot.feedY"]        = { "Posição vertical", "Desloca os avisos para cima ou para baixo." }
P["btn.testFeed"]    = { "Testar notificações", "Mostra avisos de exemplo para conferir posição e tamanho.", "Testar" }
P["sec.lootRolls"]   = { "Rolagens do grupo", "Painel com a escolha e o número de cada membro nos itens disputados." }
P["lootRolls.enabled"] = { "Painel de rolagens", "Mostra quem pediu Necessidade, Ganância ou passou, os números tirados, quem está na frente e o vencedor. Arraste o cabeçalho para mover." }
P["btn.testRolls"]   = { "Testar rolagens", "Mostra um exemplo do painel (o mesmo que /azaath rolls).", "Testar" }
P["sec.lootBeam"]    ={ "Facho de luz nos corpos", "Feixe colorido pela raridade sobre corpos com saque." }
P["lootBeam.enabled"]        = { "Facho de luz de saque", "Feixe vertical sobre o corpo: verde incomum, azul raro, roxo épico, laranja lendário." }
P["lootBeam.showOnUnopened"] = { "Luz em corpos fechados", "Mostra a luz mesmo antes de você abrir o corpo." }
P["lootBeam.rarityBurst"]    = { "Explosão da raridade", "Ao saquear, uma explosão de luz na cor do item mais raro." }
P["lootBeam.persistRarity"]  = { "Manter a cor se sobrar item", "Se você deixou algo no corpo, a luz continua com a cor da raridade." }
P["lootBeam.multiCorpse"]    = { "Vários corpos ao mesmo tempo", "Mantém a luz nos corpos já vistos, não só no último." }
P["lootBeam.beamHeight"]     = { "Altura do feixe", "Altura da coluna de luz." }
P["lootBeam.beamWidth"]      = { "Largura do feixe", "Espessura da coluna de luz." }
P["lootBeam.groundFactor"]   = { "Descida até o chão", "Quanto o feixe desce até o pé do corpo. Ajuste se ficar flutuando ou enterrado." }
P["lootBeam.offsetY"]        = { "Ajuste fino vertical", "Pequena correção de altura do feixe." }
P["btn.testBeam"]    = { "Testar facho de luz", "Liga e desliga um facho de exemplo (o mesmo que /azaath beam).", "Testar" }
P["sec.lootCelebration"] = { "Celebrações de saque (Dopamina)", "Cartões chamativos no estilo Azaath para saques raros, Peixes Inchados, marcos e raros abatidos." }
P["lootCelebration.enabled"]       = { "Ativar celebrações de saque", "Mostra um cartão épico com partículas, raios e som ao conquistar algo raro." }
P["lootCelebration.sound"]         = { "Fanfarra sonora", "Toca o som temático da conquista (verde, raro, épico, tesouro, pesca, peixe inchado)." }
P["lootCelebration.edgeGlow"]      = { "Brilho nas bordas da tela", "Ilumina suavemente as bordas da tela na cor da raridade em grandes achados." }
P["lootCelebration.glowIntensity"] = { "Intensidade do brilho na tela", "Controla a força da vinheta luminosa nas bordas." }
P["o.lootCelebration.glowIntensity=normal"] = { "Normal", "Impacto visual completo para máxima dopamina." }
P["o.lootCelebration.glowIntensity=soft"]   = { "Suave", "Brilho mais discreto nas bordas da tela." }
P["lootCelebration.borderPulse"]   = { "Pulso luminoso na moldura", "Um feixe de luz na cor da raridade percorre continuamente a borda do cartão." }
P["lootCelebration.greenBoE"]      = { "Equipamentos verdes (BoE)", "Celebra equipamentos incomuns vinculados ao equipar saqueados." }
P["lootCelebration.quietFishing"]  = { "Achados silenciosos da pesca", "Mostra um aviso mais discreto ao pescar poções úteis." }
P["lootCelebration.milestones"]    = { "Marcos de profissão", "Celebra ao atingir 75, 150, 225 e 300 em qualquer ofício." }
P["lootCelebration.rareKills"]     = { "Inimigos raros abatidos", "Celebra ao derrotar um inimigo raro ou raro-elite, exibindo seu retrato 3D." }
P["lootCelebration.showVendor"]    = { "Mostrar valor de venda (NPC)", "Exibe quanto o item vale ao vender para um mercador." }
P["lootCelebration.showAH"]        = { "Mostrar valor do leilão", "Exibe o menor preço visto na Casa de Leilões (varredura do Azaath ou do Auctionator)." }
P["lootCelebration.movableAlerts"] = { "Arrastar alerta ativo", "Permite arrastar temporariamente um cartão enquanto ele está na tela." }
P["lootCelebration.durationScale"] = { "Duração dos cartões", "Multiplica o tempo que cada celebração permanece na tela." }
P["lootCelebration.scale"]         = { "Escala do cartão", "Tamanho do cartão de celebração." }
P["lootCelebration.offsetX"]       = { "Posição horizontal", "Desloca o cartão para os lados a partir do centro." }
P["lootCelebration.offsetY"]       = { "Posição vertical", "Sobe ou desce o cartão a partir do centro." }
P["btn.testCelebration"] = { "Testar celebração", "Dispara exemplos de celebração (Épico e Peixe Inchado) para testar visual e som.", "Testar" }
P["btn.testLegendary"]   = { "Prévia do item Lendário", "Mostra a janela de conquista Lendária (Trovofúria) com o coro épico completo.", "Testar Lendário" }
P["btn.openLootJournal"] = { "Crônicas de Saque e Pesca", "Abre o diário com estatísticas de pesca, saques por raridade e sorte em rolagens (/saques).", "Abrir diário" }

-- NPCs -------------------------------------------------------------------------
P["sec.dialog"]      = { "Diálogos", "Conversas com NPCs e janelas de missão." }
P["dialog.enabled"]     = { "Diálogos no estilo Azaath", "Substitui as janelas de conversa e de missão da Blizzard." }
P["dialog.numberKeys"]  = { "Teclas 1-9 escolhem as opções", "Responda e escolha missões pelo teclado." }
P["dialog.interactKey"] = { "Tecla F escolhe a primeira opção", "Aperte F para avançar sem usar o mouse." }
P["dialog.scale"]       = { "Escala", "Tamanho da janela de diálogo." }
P["dialog.width"]       = { "Largura", "Largura da janela de diálogo." }
P["dialog.offsetX"]     = { "Posição horizontal", "Desloca a janela para os lados." }
P["dialog.offsetY"]     = { "Posição vertical", "Desloca a janela para cima ou para baixo." }
P["sec.npcCamera"]   = { "Câmera cinematográfica", "Aproxima a câmera ao conversar com NPCs." }
P["npcCamera.enabled"]         = { "Câmera cinematográfica", "Ao falar com um NPC, a câmera aproxima e enquadra a conversa." }
P["npcCamera.questAndGossip"]  = { "NPCs de missão e conversa", "Ativa a câmera em diálogos e missões." }
P["npcCamera.otherNPCs"]       = { "Outros NPCs", "Ativa também em mercador, treinador, banco, leilão e voo." }
P["npcCamera.zoomDistance"]    = { "Distância do zoom", "Quão perto a câmera chega do personagem." }
P["npcCamera.shoulderOffset"]  = { "Deslocamento de ombro", "Move a câmera para o lado, deixando o NPC mais à vista." }
P["npcCamera.focusStrength"]   = { "Foco no NPC", "Quanto a câmera gira para olhar o NPC (0 = nada, 1 = totalmente)." }
P["npcCamera.dynamicPitch"]    = { "Inclinação dinâmica", "Inclina a câmera durante a conversa para um enquadramento mais cinematográfico." }
P["npcCamera.fovZoom"]         = { "Zoom de campo de visão", "Fecha o campo de visão durante a conversa, como uma lente." }
P["npcCamera.fovTarget"]       = { "Campo de visão na conversa", "Ângulo usado enquanto fala com o NPC (menor = mais zoom)." }
P["npcCamera.subtlePan"]       = { "Movimento panorâmico leve", "Pequeno movimento contínuo da câmera, para a cena não ficar parada." }
P["npcCamera.vignette"]        = { "Vinheta nas bordas", "Escurece as bordas da tela durante a conversa." }
P["npcCamera.disableInCombat"] = { "Desligar em combate", "Restaura a câmera na hora se o combate começar." }
P["npcCamera.disableInInstances"] = { "Desligar em masmorras e raides", "Não muda a câmera dentro de instâncias." }
P["sec.merchant"]    = { "Mercador", "Compra, venda e conserto." }
P["merchant.enabled"]     = { "Mercador no estilo Azaath", "Janela de compra, recompra e conserto da AzaathUI." }
P["merchant.autoRepair"]  = { "Consertar sozinho", "Conserta todo o equipamento ao abrir um mercador que conserta." }
P["merchant.guildRepair"] = { "Usar o banco da guilda", "O conserto automático usa o dinheiro da guilda, quando permitido." }
P["sec.auction"]          = { "Casa de Leilões", "Preços lidos sozinhos ao abrir o leilão; dispensa o Auctionator." }
P["auction.autoScan"]     = { "Varredura automática", "Ao abrir a Casa de Leilões, lê todos os preços (o servidor libera uma vez a cada 15 min). /leilao varrer força." }
P["auction.cardPrice"]    = { "Preço do leilão no card", "Mostra no card de item o menor preço visto na última varredura." }

-- Inventário -------------------------------------------------------------------
P["sec.inventory"]   = { "Inventário", "Bolsas e itens." }
P["inventory.enabled"]       = { "Inventário unificado", "Junta todas as bolsas em uma janela no estilo Azaath." }
P["inventory.style"]         = { "Visual da mochila", "Moldura e estilo da janela do inventário. Vale após /reload." }
P["o.inventory.style=classic"] = { "Padrão", "Cabeçalho azul escovado e corpo escuro (visual atual)." }
P["o.inventory.style=azaath"]  = { "Azaath", "Moldura azul-petróleo com ouro, brasão de cristal, chips de categoria e aros por raridade." }
P["inventory.viewMode"]      = { "Modo de exibição", "Como os itens são agrupados na janela." }
P["o.inventory.viewMode=az"]   = { "Categorias", "Armas, equipamentos, consumíveis, materiais etc., como no Azaath." }
P["o.inventory.viewMode=bags"] = { "Bolsas separadas", "Cada bolsa em uma seção própria." }
P["inventory.showItemLevel"] = { "Nível do item", "Escreve o nível de cada equipamento no canto do ícone." }
P["inventory.columns"]       = { "Colunas", "Quantos itens por linha." }
P["sec.charView"]    = { "Personagem com a mochila", "Equipamento ao redor do personagem (tecla B)." }
P["character.enabled"]        = { "Equipamento ao redor do personagem", "A tecla B mostra o personagem no centro com os espaços de equipamento em volta." }
P["inventory.unified"]        = { "Abrir o personagem junto", "Abre o personagem com o inventário. Desligado, a tecla B abre só as bolsas, sem girar a câmera nem esconder a HUD." }
P["inventory.openMode"]       = { "Ao abrir a mochila", "O que aparece junto com o inventário (tecla B)." }
P["o.inventory.openMode=camera"] = { "Personagem (câmera)", "Gira a câmera para o personagem e mostra o equipamento em volta dele." }
P["o.inventory.openMode=panel"]  = { "Painel Equipado", "Painel de equipamento ao lado da mochila, com o menu radial embaixo. Não mexe na câmera." }
P["o.inventory.openMode=bags"]   = { "Só a mochila", "Abre apenas as bolsas, sem girar a câmera nem esconder a HUD." }
P["inventory.keepOnMove"]     = { "Andar com o inventário aberto", "Ao andar, o personagem fecha (a câmera volta) e as bolsas continuam abertas. Entrar em combate ainda fecha tudo." }
P["inventory.cameraLock"]     = { "Girar a câmera para a frente", "Vira a câmera para o rosto do personagem enquanto a janela está aberta." }
P["inventory.cameraDistance"] = { "Distância da câmera", "Quão longe a câmera fica do personagem (em jardas)." }
P["character.offsetY"]        = { "Altura do equipamento", "Sobe ou desce o conjunto de espaços de equipamento." }
P["character.hideHUD"]        = { "Esconder a HUD", "Esconde as barras da AzaathUI enquanto o personagem está aberto, para uma vista limpa." }
P["sec.windows"]     = { "Janelas da AzaathUI", "Substitutos das janelas da Blizzard." }
P["sheet.enabled"]       = { "Ficha do personagem (C)", "Ficha completa: atributos, PvP, santuário, reputação e perícias." }
P["talents.enabled"]     = { "Crisol de talentos (N)", "Janela de talentos com as três árvores saindo do núcleo." }
P["spellbook.enabled"]   = { "Grimório (P)", "Livro de feitiços no estilo da arte de conceito." }
P["professions.enabled"] = { "Mesa do artesão (K)", "Janela de ofícios com cartas de receita, favoritos e altar." }

-- Chat -------------------------------------------------------------------------
P["sec.chat"]        = { "Chat", "Estrutura da janela de conversa." }
P["chat.enabled"]      = { "Chat no estilo Azaath", "Ativa o visual Aeternum na janela de conversa." }
P["chat.backdrop"]     = { "Painel escuro de fundo", "Desenha o painel escuro atrás das mensagens." }
P["chat.cleanTabs"]    = { "Barra lateral de canais", "Troca as abas do chat por uma barra lateral com cabeçalho." }
P["chat.cleanEditBox"] = { "Barra de digitação nova", "Caixa de texto com a pílula do canal e contador de caracteres." }
P["chat.hideButtons"]  = { "Esconder botões extras", "Remove os botões de menu, voz e setas laterais." }
P["chat.mouseScroll"]  = { "Rolagem suave", "Rola com a roda do mouse e mostra um botão para voltar às mensagens recentes." }
P["sec.chatLook"]    = { "Aparência", "Opacidade e fonte." }
P["chat.activeAlpha"] = { "Opacidade em uso", "Quão visível o chat fica com o mouse em cima ou digitando." }
P["chat.idleAlpha"]   = { "Opacidade em repouso", "Quão visível o chat fica parado. 0 esconde o fundo por completo." }
P["chat.fontSize"]    = { "Tamanho da fonte", "Tamanho do texto das mensagens." }
P["chat.bold"]        = { "Fonte em negrito", "Usa PT Sans Bold nas mensagens (mais legível em telas grandes)." }

-- Câmera Action ----------------------------------------------------------------
P["sec.acMain"]      = { "Câmera Action", "Câmera com o mouse travado, como em jogos de ação." }
P["note.actioncam"]  = "Mouse Look, mira, alvo pela mira, clique para conjurar, trava de alvo, ciclo de aliados e menu radial. Os atalhos ficam em Esc > Opções > Teclas > AzaathUI."
P["actioncam.enabled"] = { "Ativar Câmera Action", "Liga todo o sistema de câmera action. Desligado, todas as opções abaixo ficam inativas." }
P["sec.acCamera"]    = { "Câmera e Mouse Look", "Movimento e enquadramento da câmera." }
P["actioncam.mouseLookSpeed"]       = { "Velocidade do Mouse Look", "Sensibilidade do mouse com a câmera travada." }
P["actioncam.shoulderOffset"]       = { "Deslocamento de ombro", "Coloca o personagem um pouco de lado, como em jogos em terceira pessoa." }
P["actioncam.shoulderFollowsMouseLook"] = { "Ombro só no Mouse Look", "Aplica o deslocamento de ombro apenas enquanto a câmera está travada." }
P["actioncam.situations"] = { "Câmera por situação", "Combate, chefe, montaria, voo, nado, masmorra, interior, descanso e morte ganham enquadramento próprio, com transição suave." }
P["actioncam.situationZoomMemory"] = { "Lembrar zoom por situação", "Cada situação guarda a distância de câmera que você usou nela e volta para ela ao entrar de novo." }
P["actioncam.shoulderZoomScale"] = { "Ombro proporcional ao zoom", "Ajusta o deslocamento de ombro à distância da câmera: o enquadramento fica igual de perto e de longe." }
P["actioncam.dynamicPitch"]         = { "Inclinação dinâmica", "Inclina a câmera para mostrar mais do que está à frente." }
P["actioncam.dynamicPitchStrength"] = { "Força da inclinação", "Quanto a câmera inclina." }
P["actioncam.minCameraZoom"]        = { "Zoom mínimo", "Distância mínima da câmera (0 = sem limite)." }
P["actioncam.autofocusLockedTarget"] = { "Seguir alvo travado", "Com a trava de alvo, a câmera acompanha o inimigo." }
P["actioncam.respectMotionSickness"] = { "Proteção contra enjoo", "Respeita a opção do jogo que reduz movimentos bruscos de câmera." }
P["actioncam.vignetteConditions"]    = { "Vinheta nas bordas", "Quando escurecer as bordas da tela." }
P["o.actioncam.vignetteConditions=mouselook"] = { "Mouse Look", "Só com a câmera travada." }
P["o.actioncam.vignetteConditions=combat"]    = { "Combate", "Só em combate." }
P["o.actioncam.vignetteConditions=mouselook,combat"] = { "Ambos", "Com a câmera travada ou em combate." }
P["o.actioncam.vignetteConditions="]          = { "Desligada", "Nunca escurece as bordas." }
P["sec.acCursor"]    = { "Cursor", "Quando o cursor aparece e some." }
P["actioncam.frameWatching"]           = { "Destravar ao abrir janelas", "Solta o cursor sozinho quando você abre bolsas, mapa, diálogos etc." }
P["actioncam.ctrlToggle"]              = { "Ctrl alterna a Câmera Action", "Um toque rápido no Ctrl trava/destrava o Mouse Look, igual à tecla V. Ctrl+tecla, Ctrl+clique ou segurar o Ctrl não alternam." }
P["actioncam.closeWindowsOnMouseLook"] = { "Mouse Look fecha janelas", "A tecla de Mouse Look fecha as janelas abertas antes de travar." }
P["actioncam.pulseCursor"]             = { "Pulso no cursor", "Um brilho rápido mostra onde o cursor reapareceu." }
P["actioncam.hideTooltip"]             = { "Esconder tooltips no Mouse Look", "Evita tooltips piscando enquanto você gira a câmera." }
P["actioncam.tooltipModifier"]         = { "Espiar tooltip segurando", "Tecla que mostra a tooltip mesmo no Mouse Look." }
P["o.actioncam.tooltipModifier=ALT"]   = { "Alt" }
P["o.actioncam.tooltipModifier=CTRL"]  = { "Ctrl" }
P["o.actioncam.tooltipModifier=SHIFT"] = { "Shift" }
P["actioncam.sheathWeaponsWithMouselook"] = { "Embainhar ao sair", "Guarda as armas quando você sai do Mouse Look fora de combate." }
P["sec.acCrosshair"] = { "Mira e HUD", "Mira central e informações sob ela." }
P["actioncam.crosshair"]             = { "Mira central", "Mostra uma mira no centro da tela." }
P["actioncam.crosshairStyle"]        = { "Estilo da mira", "Formato do desenho da mira." }
P["o.actioncam.crosshairStyle=diamond"] = { "Losango" }
P["o.actioncam.crosshairStyle=ring"]    = { "Anel" }
P["o.actioncam.crosshairStyle=dot"]     = { "Ponto" }
P["o.actioncam.crosshairStyle=cross"]   = { "Cruz" }
P["o.actioncam.crosshairStyle=star"]    = { "Estrela" }
P["actioncam.crosshairScale"]        = { "Escala da mira", "Tamanho da mira." }
P["actioncam.crosshairY"]            = { "Altura da mira", "Sobe ou desce a mira (útil com ombro deslocado)." }
P["actioncam.crosshairCastFeedback"] = { "Anel de conjuração na mira", "A mira mostra o progresso da conjuração." }
P["actioncam.interactionHUD"]        = { "HUD de interação", "Abaixo da mira, mostra o nome do que você pode interagir." }
P["actioncam.interactionHUDPlayers"] = { "Jogadores na HUD de interação", "Inclui jogadores na HUD de interação." }
P["actioncam.crosshairTargetPreview"] = { "Prévia do alvo", "Mostra no canto direito uma placa com o que está na mira." }
P["actioncam.showTargetLockMarker"]  = { "Marcador de trava", "Desenha um marcador na placa do inimigo travado." }
P["sec.acTargeting"] = { "Alvo pela mira", "Seleção automática e trava de alvo." }
P["actioncam.reticleTargeting"]       = { "Alvo pela mira", "Seleciona sozinho o inimigo no centro da tela." }
P["actioncam.reticleOutline"]         = { "Contorno no alvo", "Contorno brilhante em volta do alvo da mira." }
P["actioncam.selectionCircleMode"]    = { "Círculo no chão", "Qual alvo ganha o círculo de seleção sob os pés." }
P["o.actioncam.selectionCircleMode=target"] = { "Alvo", "Só o alvo selecionado." }
P["o.actioncam.selectionCircleMode=soft"]   = { "Mira", "O alvo provisório da mira." }
P["o.actioncam.selectionCircleMode=hidden"] = { "Oculto", "Nenhum círculo." }
P["actioncam.autoTargetLockOnAttack"] = { "Travar ao atacar", "Trava o alvo automaticamente quando você ataca." }
P["actioncam.targetLockBehavior"]     = { "Tecla de trava", "O que a tecla de trava faz com um alvo já travado." }
P["o.actioncam.targetLockBehavior=toggle"] = { "Alternar", "Aperte de novo para soltar." }
P["o.actioncam.targetLockBehavior=switch"] = { "Trocar", "Aperte de novo para trocar para o próximo inimigo." }
P["sec.acClick"]     = { "Clique para conjurar", "O que cada botão do mouse faz no Mouse Look." }
P["actioncam.bindings.button1.value"]      = { "Botão esquerdo", "Ação do clique esquerdo com a câmera travada." }
P["actioncam.bindings.button2.value"]      = { "Botão direito", "Ação do clique direito com a câmera travada." }
P["actioncam.bindings.shiftbutton1.value"] = { "Shift + esquerdo", "Ação do Shift + clique esquerdo." }
P["actioncam.bindings.shiftbutton2.value"] = { "Shift + direito", "Ação do Shift + clique direito." }
P["o.actioncam.bindings.button1.value=ACTIONBUTTON1"]   = { "Barra 1, botão 1" }
P["o.actioncam.bindings.button1.value=STARTATTACK"]     = { "Atacar" }
P["o.actioncam.bindings.button1.value=TARGETMOUSEOVER"] = { "Alvo na mira" }
P["o.actioncam.bindings.button2.value=ACTIONBUTTON2"]     = { "Barra 1, botão 2" }
P["o.actioncam.bindings.button2.value=INTERACTMOUSEOVER"] = { "Interagir" }
P["o.actioncam.bindings.button2.value=CLEARTARGET"]       = { "Limpar alvo" }
P["o.actioncam.bindings.shiftbutton1.value=ACTIONBUTTON3"] = { "Barra 1, botão 3" }
P["o.actioncam.bindings.shiftbutton1.value=ACTIONBUTTON7"] = { "Barra 1, botão 7" }
P["o.actioncam.bindings.shiftbutton1.value="]              = { "Desativado" }
P["o.actioncam.bindings.shiftbutton2.value=ACTIONBUTTON4"] = { "Barra 1, botão 4" }
P["o.actioncam.bindings.shiftbutton2.value=ACTIONBUTTON8"] = { "Barra 1, botão 8" }
P["o.actioncam.bindings.shiftbutton2.value="]              = { "Desativado" }
P["sec.acAlly"]      = { "Aliados e suporte", "Ciclo de aliados para curar e ajudar." }
P["actioncam.allyCycle.showHud"]    = { "HUD do ciclo de aliados", "Mostra quem está selecionado ao ciclar aliados." }
P["actioncam.allyCycle.skipPlayer"] = { "Pular a si mesmo", "O ciclo não passa pelo seu personagem." }
P["actioncam.supportModeTintVignette"] = { "Vinheta no modo suporte", "Tinge as bordas da tela enquanto o modo suporte está ativo." }
P["sec.acBdo"]       = { "Câmera de combate", "Efeitos de impacto no estilo Black Desert." }
P["btn.bdoPreset"]   = { "Preset Black Desert", "Liga de uma vez o enquadramento e os efeitos recomendados (ombro, inclinação, tremor, inércia e zoom dinâmico).", "Aplicar" }
P["actioncam.bdoEnabled"]      = { "Efeitos de câmera em combate", "Liga os efeitos abaixo durante o combate." }
P["actioncam.bdoIntensity"]    = { "Intensidade", "Força geral dos efeitos (0 = sutil, 1 = forte)." }
P["actioncam.bdoHitShake"]     = { "Tremor ao acertar", "Pequeno tremor da câmera em cada golpe." }
P["actioncam.bdoCastFocus"]    = { "Foco ao conjurar", "Leve zoom enquanto você conjura ou canaliza." }
P["actioncam.bdoSkillPunch"]   = { "Pulso das habilidades", "Pequeno recuo da câmera ao usar habilidades." }
P["actioncam.bdoMoves"]        = { "Câmera por habilidade", "Investida avança, giros abrem, golpes pesados dão soco, brados sacodem e a Tempestade de Lâminas afasta a câmera." }
P["actioncam.bdoHurtShake"]    = { "Tremor ao levar dano", "A câmera sacode de leve quando você é atingido (mais forte em críticos)." }
P["actioncam.bdoCritImpact"]   = { "Impacto em críticos", "Micro-zoom extra nos acertos críticos." }
P["actioncam.bdoCritSound"]    = { "Som de crítico", "Toca um som de impacto nos críticos." }
P["actioncam.bdoCritSoundStyle"] = { "Som do crítico", "Qual som tocar nos críticos." }
P["o.actioncam.bdoCritSoundStyle=impact"]  = { "Impacto metálico" }
P["o.actioncam.bdoCritSoundStyle=ping"]    = { "Ping metálico" }
P["o.actioncam.bdoCritSoundStyle=drum"]    = { "Tambor" }
P["o.actioncam.bdoCritSoundStyle=thunder"] = { "Estrondo" }
P["actioncam.bdoSpeedZoom"]     = { "Zoom pela velocidade", "Afasta a câmera ao correr ou montar." }
P["actioncam.bdoCameraInertia"] = { "Inércia da câmera", "A câmera segue o personagem com um leve atraso suave." }
P["actioncam.bdoCombatZoomOut"] = { "Afastar em combate", "Abre a câmera ao entrar em combate para ver melhor ao redor." }
P["sec.acRadial"]    = { "Menu radial", "Roda de consumíveis e atalhos." }
P["actioncam.radialEnabled"]   = { "Ativar menu radial", "Segure a tecla do menu radial para escolher consumíveis em roda." }
P["actioncam.radialBackdrop"] = { "Fundo do menu radial", "Desligado, a roda fica transparente: só os aros de ouro, os ícones e o centro, para ver o jogo por trás." }
P["actioncam.soundRadialMenu"] = { "Sons do menu radial", "Toca sons ao abrir e escolher." }
P["btn.radialConsumables"] = { "Consumíveis do menu radial", "Escolha quais poções, comidas e itens aparecem na roda.", "Configurar" }
P["btn.radialSpells"] = { "Habilidades do menu radial", "Escolha até oito habilidades (bênçãos, buffs, formas...) para a aba Habilidades da roda.", "Configurar" }
P["sec.acMaint"]     = { "Manutenção", "Voltar ao padrão." }
P["btn.acReset"]     = { "Restaurar Câmera Action", "Volta todas as opções da câmera action e as CVars de câmera do jogo ao padrão.", "Restaurar" }

-- Olho de Azaath ---------------------------------------------------------------
P["sec.olho"]        = { "Destaque de objetos", "Brilho em minérios, ervas, baús, objetos de missão e boias." }
P["btn.olhoStudio"]  = { "Estúdio do Olho de Azaath", "Prévia 3D, efeitos e cores do brilho (o mesmo que /olho).", "Abrir estúdio" }
P["olho.enabled"]    = { "Ativar Olho de Azaath", "Faz os objetos do mundo brilharem quando você se aproxima." }
P["olho.range"]      = { "Alcance", "Até que distância os objetos são destacados." }
P["olho.arc"]        = { "Direção", "Em que direção ao redor do personagem procurar objetos." }
P["o.olho.arc=0"]    = { "Bem à frente", "Só o que está diretamente na sua frente." }
P["o.olho.arc=1"]    = { "À frente", "Um cone largo à frente." }
P["o.olho.arc=2"]    = { "360 graus", "Em todas as direções." }
P["olho.glowOnly"]   = { "Só o brilho", "Mantém a placa padrão do jogo (ou de outro addon) e só adiciona o brilho." }
P["olho.exclusive"]  = { "Só alvos destacados", "Esconde as placas de objetos que não estão destacados." }
P["olho.silhouette"] = { "Atravessar o personagem", "O brilho aparece mesmo atrás do seu personagem (silhueta)." }
P["olho.hideInCombat"]   = { "Ocultar em combate", "Desliga o brilho enquanto você luta." }
P["olho.hideInInstance"] = { "Ocultar em instâncias", "Desliga o brilho em masmorras e raides." }

-- Avançado ---------------------------------------------------------------------
P["sec.blizzard"]    = { "Interface da Blizzard", "Quais quadros originais ficam escondidos." }
P["note.blizzard"]   = "Marcado = escondido. Desmarcar traz de volta o quadro original da Blizzard; deixe marcado enquanto usar o substituto da AzaathUI para não aparecerem os dois."
P["hideBlizzard.actionBars"]   = { "Esconder barras de ação", "Barra principal, XP/reputação e barras inferiores da Blizzard." }
P["hideBlizzard.playerFrame"]  = { "Esconder quadro do jogador", "Retrato e barras do jogador da Blizzard." }
P["hideBlizzard.targetFrame"]  = { "Esconder quadro do alvo", "Retrato e barras do alvo da Blizzard." }
P["hideBlizzard.minimap"]      = { "Esconder minimapa", "Minimapa da Blizzard (avisos de fila e correio continuam)." }
P["hideBlizzard.buffs"]        = { "Esconder buffs", "Buffs, debuffs e encantamentos de arma da Blizzard." }
P["hideBlizzard.questTracker"] = { "Esconder rastreador de missões", "Lista de missões da Blizzard." }
P["hideBlizzard.partyFrames"]  = { "Esconder quadros de grupo", "Quadros de grupo da Blizzard." }
P["sec.skins"]       = { "Aparência geral", "Visual AzaathUI em elementos da Blizzard." }
P["skins.tooltips"]  = { "Tooltips no estilo Azaath", "Tooltips escuras com a borda na cor da raridade do item." }
P["skins.popups"]    = { "Caixas e menus no estilo Azaath", "Caixas de confirmação e menus suspensos com o visual AzaathUI." }
P["skins.itemCard"]  = { "Card de item (New World)", "Ao passar o mouse num item: cabeçalho na cor da raridade, nível do item em destaque, efeitos com ícone e rodapé com vínculo, durabilidade e valor de venda." }
P["skins.itemCardSparks"] = { "Fagulhas no card", "Fagulhas subindo no cabeçalho; quanto mais raro o item, mais fagulhas." }
P["skins.itemCardScale"]  = { "Tamanho do card", "Escala do card de item." }

-- Primeiros Passos (Modules/Config/Setup.lua) ---------------------------------
P["sec.setup"]       = { "Primeiros Passos", "Assistente de configuração inicial." }
P["btn.setup"]       = { "Assistente Primeiros Passos", "Escolhe módulo por módulo entre o visual do addon e o da Blizzard, a skin, as barras e a escala. Reabrir não apaga o resto das suas configurações. Atalho: /azaath setup.", "Abrir assistente" }
P["setup.title"]     = "Primeiros Passos"
P["setup.subtitle"]  = "Deixe a interface do seu jeito em poucos cliques"
P["setup.step.1"]    = "Boas-vindas"
P["setup.step.2"]    = "Módulos"
P["setup.step.3"]    = "Recursos"
P["setup.step.4"]    = "Câmera"
P["setup.step.5"]    = "Visual"
P["setup.step.6"]    = "Conclusão"
P["setup.back"]      = "Voltar"
P["setup.next"]      = "Próximo"
P["setup.skip"]      = "Pular assistente"
P["setup.skipTip"]   = "Fecha sem aplicar nada. Dá para reabrir quando quiser com /azaath setup."
P["setup.finish"]    = "Concluir"
P["setup.applyReload"] = "Aplicar e Recarregar UI"
P["setup.applyReloadTip"] = "Grava as escolhas e recarrega a interface para que os módulos trocados entrem em vigor."
P["setup.pending"]   = "%d mudança(s) exigem recarregar"
P["setup.welcome.title"] = "Bem-vindo ao AzaathUI"
P["setup.welcome.body"]  = "O addon pode substituir quase toda a interface da Blizzard. Escolha como começar: tudo pronto no visual do addon ou decidindo módulo por módulo."
P["setup.welcome.foot"]  = "Nada é gravado até você concluir. Reabra quando quiser com /azaath setup ou pelo painel (Geral)."
P["setup.mode.full"]   = { "Experiência Completa", "Liga todos os módulos do addon: barras, quadros, mapa, mochila, ficha, talentos, diálogos, saque e mais. Também liga os recursos extras e a Câmera Action; depois você ainda escolhe a skin, as barras e a escala." }
P["setup.mode.custom"] = { "Personalizar passo a passo", "Decida para cada parte da interface se quer o visual do addon ou manter a janela original da Blizzard." }
P["setup.recommended"] = "Recomendado"
P["setup.step2.title"] = "Addon ou Blizzard"
P["setup.step2.desc"]  = "Escolha quem desenha cada parte. Trocar um módulo só vale depois de recarregar a interface."
P["setup.allAddon"]  = { "Ativar Todos (Addon)", "Marca todos os módulos com o visual do addon." }
P["setup.allBlizz"]  = { "Manter Padrão Blizzard", "Marca todos os módulos para usar as janelas e quadros originais da Blizzard." }
P["setup.count"]     = "%d de %d módulos com o visual do addon"
P["setup.addon"]     = "Addon"
P["setup.blizz"]     = "Blizzard"
P["setup.state.addon"] = "Escolhido: visual do addon"
P["setup.state.blizz"] = "Escolhido: original da Blizzard"
P["setup.m.actionbars"]  = { "Barras de Ação", "Barras, postura e pet no estilo do addon." }
P["setup.m.player"]      = { "Quadro do Jogador", "Vida, recurso e nível do seu personagem." }
P["setup.m.target"]      = { "Quadro do Alvo", "Vida, nome e nível do alvo selecionado." }
P["setup.m.party"]       = { "Quadros de Grupo", "Membros do grupo à esquerda da tela." }
P["setup.m.auras"]       = { "Bônus e Penalidades", "Buffs e debuffs do jogador." }
P["setup.m.castbar"]     = { "Conjuração", "Espiral ou barra do jogador e barra do alvo." }
P["setup.m.nameplates"]  = { "Placas de Nome", "Vida e nome sobre a cabeça dos inimigos." }
P["setup.m.combattext"]  = { "Dano Flutuante", "Números de dano e cura no estilo do addon." }
P["setup.m.minimap"]     = { "Minimapa", "Minimapa com coordenadas e relógio." }
P["setup.m.worldmap"]    = { "Mapa-múndi", "Mapa próprio do addon na tecla M." }
P["setup.m.questtracker"] = { "Rastreador de Missões", "Lista de objetivos ao lado da tela." }
P["setup.m.inventory"]   = { "Mochila", "Inventário unificado na tecla B." }
P["setup.m.character"]   = { "Personagem e Equipamento", "Modelo 3D com os espaços de equipamento." }
P["setup.m.sheet"]       = { "Santuário (Ficha)", "Ficha da tecla C: atributos, reputação, perícias e Grimório." }
P["setup.m.talents"]     = { "Talentos", "Crisol com as três árvores de talento." }
P["setup.m.spellbook"]   = { "Livro de Magias", "Grimório do addon no lugar do livro de feitiços." }
P["setup.m.professions"] = { "Profissões", "Mesa do Artesão para criar itens." }
P["setup.m.dialog"]      = { "Diálogos", "Conversas com NPCs e missões no estilo do addon." }
P["setup.m.loot"]        = { "Saque", "Janela de saque própria." }
P["setup.m.merchant"]    = { "Mercador", "Janela de compra e venda dos vendedores." }
P["setup.m.chat"]        = { "Chat", "Janela de conversa limpa e transparente." }
P["setup.step6.title"] = "Tudo pronto"
P["setup.step6.desc"]  = "Confira o resumo. Clique em uma etapa acima para revisar qualquer escolha antes de aplicar."
P["setup.camPreset"] = { "Estilo da câmera", "Desligada mantém a câmera do jogo. Clássica liga a Câmera Action com os valores padrão. Black Desert aplica o preset completo (ombro, inclinação, tremor e inércia)." }
P["o.setup.camPreset=off"]     = { "Desligada", "Câmera e cursor normais do jogo." }
P["o.setup.camPreset=classic"] = { "Clássica", "Câmera Action com os valores padrão do addon." }
P["o.setup.camPreset=bdo"]     = { "Black Desert", "Câmera sobre o ombro com tremor nos golpes, foco ao conjurar e inércia." }
P["setup.why.cam"]   = "Escolha um estilo de câmera para ativar."
P["setup.sum.features"] = "Recursos ligados"
P["setup.sum.camera"] = "Câmera Action"
P["setup.tips"]      = "Comandos úteis"
P["setup.summary"]   = "Resumo"
P["setup.tip.1"]     = "Abre o painel com todas as opções."
P["setup.tip.2"]     = "Modo de Edição: arraste e redimensione os elementos."
P["setup.tip.3"]     = "Reabre este assistente."
P["setup.tip.4"]     = "Mostra ou esconde a interface do addon."
P["setup.tip.5"]     = "Estúdio do Olho de Azaath (brilho e coleta)."
P["setup.tip.6"]     = "Lista todos os comandos."
P["setup.where"]     = "Para reabrir: /azaath setup, /azaath tutorial ou Painel > Geral > Primeiros Passos."
P["setup.sum.addon"] = "Módulos do addon"
P["setup.sum.blizz"] = "Módulos da Blizzard"
P["setup.sum.reload"] = "Recarregar a interface"
P["setup.sum.reloadN"] = "Sim (%d mudança(s))"
P["setup.sum.none"]  = "Não é preciso"
P["setup.msg.combat"] = "o assistente abre ao sair do combate."
P["setup.msg.done"]  = "configuração concluída. Reabra com |cffe3c78b/azaath setup|r."
P["setup.msg.hint"]  = "novo: assistente Primeiros Passos em |cffe3c78b/azaath setup|r."

--==============================================================================
-- ENGLISH
--==============================================================================
local E = enUS

E["ui.title"]        = "AzaathUI"
E["ui.subtitle"]     = "Settings"
E["ui.editMode"]     = "Edit Mode"
E["ui.editModeTip"]  = { "Edit Mode", "Closes this panel and shows handles on every interface element: drag to move, pull the corner to resize, use the mouse wheel to scale and click for fine tuning." }
E["ui.close"]        = "Close"
E["ui.search"]       = "Search settings..."
E["ui.noResults"]    = "No settings found for \"%s\"."
E["ui.pending"]      = "Some changes only take effect after reloading."
E["ui.reloadNow"]    = "Reload now"
E["ui.legendReload"] = "Requires a UI reload (/reload)"
E["ui.legendHelp"]   = "Hover any setting to read its full explanation"
E["ui.resetSection"] = "Reset section"
E["ui.resetSectionTip"] = { "Reset section", "Restores every setting in this section to its default value. Asks for confirmation first." }
E["ui.default"]      = "Default: %s"
E["ui.on"]           = "On"
E["ui.off"]          = "Off"
E["ui.reloadTip"]    = "Takes effect after reloading the interface."
E["ui.needs"]        = "Available when enabled: %s"
E["ui.wheelTip"]     = "Drag the diamond, use - and + for one step or click the number to type a value."
E["ui.stubInfo"]     = "Settings live in their own window. Shortcuts: /azaath and /azaath edit"
E["ui.stubOpen"]     = "Open settings"
E["ui.stubEdit"]     = "Edit Mode"
E["ui.langShort.ptBR"] = "PT"
E["ui.langShort.enUS"] = "EN"
E["ui.langTip"]      = { "Panel language", "Switches this panel's language instantly. The choice is saved; use General > Language to follow the game client again." }

E["pop.skin"]      = "The skin changes how the frames are built and is only complete after reloading the interface.\nReload now?"
E["pop.bars"]      = "The bar layout changes the button shapes and is only complete after reloading the interface.\nReload now?"
E["pop.reset"]     = "Restore ALL AzaathUI settings of this character to their defaults?\nThe interface will reload."
E["pop.resetElements"] = "Restore the position and size of every element to the default?"
E["pop.section"]   = "Restore the defaults of the \"%s\" section?"
E["pop.reloadNow"] = "Reload"
E["pop.later"]     = "Later"
E["pop.yes"]       = "Yes"
E["pop.no"]        = "No"
E["msg.bdoPreset"] = "Black Desert camera preset applied (shoulder 0.45, pitch 0.45, hit shake, inertia and dynamic zoom)."
E["msg.sectionReset"] = "Section \"%s\" restored."

E["why.bdo"]       = "Only applies to the Zerker skin."
E["why.azaath"]    = "Only applies to the Azaath Reforged skin."
E["why.xpAuto"]    = "Turn off automatic width to set a fixed width."
E["why.ring"]      = "Only applies to the Spiral style."
E["why.bar"]       = "Only applies to the Horizontal bar style."

E["page.general"]    = { "General", "Language, scale, layout editing and maintenance." }
E["page.character"]  = { "Character & HUD", "Skin, health and resource, experience and your auras." }
E["page.actionbars"] = { "Action Bars", "Layout, button size, stance, pet and utility menu." }
E["page.target"]     = { "Target & Enemies", "Target frame, target auras and nameplates." }
E["page.combat"]     = { "Combat", "Player, target and object cast bars, and floating damage." }
E["page.party"]      = { "Party", "Party member frames." }
E["page.map"]        = { "Map & Quests", "Compass, minimap, world map, quest navigation and tracker." }
E["page.loot"]       = { "Loot", "Loot window, notifications and corpse loot beams." }
E["page.npc"]        = { "NPCs & Dialogs", "Conversations, cinematic camera and merchants." }
E["page.inventory"]  = { "Inventory & Windows", "Bags, character, sheet, talents, spellbook and professions." }
E["page.auction"]    = { "Auction House", "Auction price on the item card." }
E["page.chat"]       = { "Chat", "Chat window look and behavior." }
E["page.actioncam"]  = { "Action Camera", "Mouse Look, crosshair, targeting, click casting and camera effects." }
E["page.olho"]       = { "Eye of Azaath", "World object glow and gathering icons on the minimap." }
E["page.advanced"]   = { "Advanced", "Original Blizzard frames and general appearance." }

E["sec.language"]    = { "Language", "Choose this panel's language." }
E["config.lang"]     = { "Panel language", "Automatic follows the game client language. Picking Português or English locks it regardless of the client." }
E["o.config.lang=auto"] = { "Automatic", "Follows the client (Portuguese on a ptBR client, English otherwise)." }
E["o.config.lang=ptBR"] = { "Português", "Panel always in Portuguese." }
E["o.config.lang=enUS"] = { "English", "Panel always in English." }
E["sec.interface"]   = { "Interface", "Visibility and overall size." }
E["enabled"]         = { "Show the AzaathUI interface", "Hides or shows every AzaathUI element at once (same as /azaath toggle). Handy for screenshots or comparing with the default UI." }
E["scale"]           = { "Global HUD scale", "Multiplies the size of every AzaathUI element. Increase on large or 4K screens; decrease on small screens to free up space." }
E["config.scale"]    = { "Settings panel size", "Makes only this settings window bigger or smaller. Does not affect the game." }
E["sec.layout"]      = { "Positions and sizes", "Move and resize elements right on the screen." }
E["note.editMode"]   = "In Edit Mode you drag any element, pull its corner to resize, use the mouse wheel to change scale and click to open the Inspector for fine tuning. Shortcut: /azaath edit."
E["btn.editMode"]    = { "Visual Edit Mode", "Shows handles over every element so you can move and resize them with the mouse.", "Open editor" }
E["btn.resetElements"] = { "Factory positions", "Restores the position and size of every element. Other settings are kept.", "Restore" }
E["sec.maintenance"] = { "Maintenance", "Reload and restore." }
E["btn.reload"]      = { "Reload the interface", "Applies changes marked with the orange diamond (same as /reload).", "Reload" }
E["btn.factoryReset"] = { "Restore factory defaults", "Erases ALL AzaathUI settings and reloads. Use it if something looks wrong and you want a fresh start.", "Restore all" }

E["sec.skin"]        = { "Skin", "Look of the action bars and the character frame." }
E["skin"]            = { "Azaath UI skin", "Only changes the action bars and the character frame (health, resource and XP); the rest of the UI stays the same. Reloads on change." }
E["o.skin=modern"]   = { "Azaath", "Resource and health at the bottom center, level diamond and XP below health." }
E["o.skin=azaath"]   = { "Azaath Reforged", "Health, resource and XP in the central frame with the level medallion. Buffs follow the HUD. Pairs with the Reforged bars." }
E["o.skin=blizzard"] = { "Blizzard", "The game's default player and target health frames. Bars, buffs and the rest of the UI stay Azaath." }
E["o.skin=bdo"]      = { "Zerker", "Frame at the top left: level diamond with XP around its edge, red health and arrow resource. Bars and buffs stay free." }
E["sec.zerker"]      = { "Zerker frame", "Settings for the Zerker skin frame." }
E["bdo.scale"]       = { "Frame scale", "Size of the Zerker frame at the top left." }
E["bdo.offsetX"]     = { "Distance from left edge", "Moves the frame away from the left edge of the screen." }
E["bdo.offsetY"]     = { "Distance from top", "Moves the frame away from the top of the screen." }
E["sec.reforged"]    = { "Azaath Reforged HUD", "Settings for the Reforged central HUD." }
E["azaath.scale"]    = { "HUD scale", "Size of the whole HUD (bars, health and medallion). Buffs and debuffs follow." }
E["azaath.offsetY"]  = { "HUD height", "Distance from the HUD to the bottom of the screen. Raise it if it covers chat or other addons." }
E["azaath.glow"]     = { "Pulsing gems", "Makes the cyan gems and trims pulse softly. Turn off for a more static HUD." }
E["sec.player"]      = { "Player health and resource", "Health bar and mana/energy/rage bar." }
E["unitframes.player.enabled"] = { "Enable player bars", "Replaces Blizzard's player frame with Azaath style bars." }
E["unitframes.player.fadeOutOfCombat"] = { "Transparent out of combat", "The bar stays subtle while you are not fighting and returns in combat. Not used by the Azaath HUD." }
E["unitframes.player.scale"]        = { "Scale", "Size of the health and resource group." }
E["unitframes.player.width"]        = { "Width", "Length of the health and resource bars." }
E["unitframes.player.healthHeight"] = { "Health height", "Thickness of the health bar." }
E["unitframes.player.powerHeight"]  = { "Resource height", "Thickness of the mana/energy/rage bar." }
E["unitframes.player.healthFont"]   = { "Health text size", "Size of the health numbers on the bar." }
E["unitframes.player.offsetX"]      = { "Horizontal position", "Moves left (negative) or right (positive) from the center." }
E["unitframes.player.offsetY"]      = { "Distance from bottom", "Height of the bars from the bottom of the screen." }
E["sec.xp"]          = { "Experience (XP)", "Experience bar at the bottom." }
E["experience.enabled"]   = { "Enable XP bar and level badge", "Shows progress to the next level and the diamond with your level." }
E["experience.showAtMax"] = { "Show at max level", "Keeps the bar visible even with no XP left to earn (hidden at max level by default)." }
E["experience.autoWidth"] = { "Automatic width", "The bar stretches edge to edge at the bottom. Turn off to choose a fixed width." }
E["experience.width"]     = { "Fixed width", "Bar length when automatic width is off." }
E["experience.height"]    = { "Height", "Thickness of the XP bar." }
E["experience.segments"]  = { "Segments", "How many ticks divide the bar (helps estimate what is left)." }
E["experience.scale"]     = { "Scale", "Size of the XP bar." }
E["experience.offsetX"]   = { "Horizontal position", "Moves the bar from the screen center." }
E["experience.offsetY"]   = { "Distance from bottom", "Height of the bar from the bottom of the screen." }
E["sec.badge"]       = { "Level badge", "Diamond with your level." }
E["experience.showBadge"]  = { "Show level badge", "Displays the diamond with your level number next to the XP bar." }
E["experience.badgeSize"]  = { "Badge size", "Diamond size in pixels." }
E["experience.badgeScale"] = { "Badge scale", "Multiplies the diamond size." }
E["sec.buffs"]       = { "Player buffs", "Beneficial effects active on you." }
E["note.aurasAzaath"] = "With the Azaath Reforged skin, buffs and debuffs are attached to the HUD and follow its scale."
E["auras.playerBuffs.enabled"]        = { "Enable buffs", "Shows your buffs in Azaath style instead of Blizzard's." }
E["auras.playerBuffs.weaponEnchants"] = { "Weapon enchants", "Includes poisons, sharpening stones and other temporary weapon enchants." }
E["auras.playerBuffs.scale"]   = { "Scale", "Size of the buff group." }
E["auras.playerBuffs.size"]    = { "Icon size", "Size of each icon in pixels." }
E["auras.playerBuffs.spacing"] = { "Spacing", "Space between icons." }
E["auras.playerBuffs.perRow"]  = { "Icons per row", "How many icons before wrapping to the next row." }
E["sec.debuffs"]     = { "Player debuffs", "Harmful effects active on you." }
E["auras.playerDebuffs.enabled"] = { "Enable debuffs", "Shows debuffs on you, bordered by type (magic, poison, disease...)." }
E["auras.playerDebuffs.scale"]   = { "Scale", "Size of the debuff group." }
E["auras.playerDebuffs.size"]    = { "Icon size", "Size of each icon in pixels." }
E["auras.playerDebuffs.spacing"] = { "Spacing", "Space between icons." }
E["auras.playerDebuffs.perRow"]  = { "Icons per row", "How many icons before wrapping to the next row." }

E["sec.barLayout"]   = { "Layout", "Shape and placement of the action bars." }
E["actionbars.layout"] = { "Bar layout", "Picks the action bar design. Reloads on change." }
E["o.actionbars.layout=bdo"]   = { "Losyx", "Diamonds in groups of four in the center and six-button wings on each side." }
E["o.actionbars.layout=split"] = { "NextGen", "Two 12-key bars, one on each edge, in octagons with a glass strip." }
E["o.actionbars.layout=az"]    = { "Minimalist", "Bar 1 to the right and bar 2 to the left of health, like Azaath." }
E["o.actionbars.layout=blizzard"] = { "Blizzard", "The game's default action bars, with their micro menu and bags; the Azaath micro menu is hidden." }
E["o.actionbars.layout=reforged"] = { "Reforged", "Azaath Reforged art panels: bar 1 on the right, bar 2 on the left with the stance tabs. Each panel moves on its own." }
E["sec.rotation"] = { "Rotation helper", "Warrior only for now. Lights up Battle Shout and situational abilities on the bar." }
E["actionbars.rotation.enabled"] = { "Enable helper", "Makes Execute, Overpower, Revenge, Victory Rush, procs (Slam, Shield Slam) and interrupts glow when available." }
E["actionbars.rotation.shout"] = { "Battle Shout reminder", "The Battle Shout button glows red while you lack the buff." }
E["actionbars.rotation.sound"] = { "Alert sound", "Plays a soft sound when a situational ability lights up." }
E["actionbars.rotation.castSounds"] = { "Voices on ability use", "Light of Elune says its line when used." }
E["actionbars.rotation.volume"] = { "Sound volume", "1x = normal. 2x and 3x layer the sound to go past the file's limit; 3x may distort." }
E["actionbars.rotation.castSfx"] = { "Ability sound effects", "Heroic Strike, Execute and the three shouts replace the game's original sound with their own effect (the original is muted only around your use)." }
E["sec.barsGeneral"] = { "General", "Applies to every bar." }
E["actionbars.enabled"]     = { "Enable AzaathUI action bars", "Replaces Blizzard's action bars with AzaathUI's." }
E["actionbars.showHotkeys"] = { "Show keybinds", "Prints each button's key. Turn off if you know them by heart and prefer a clean look." }
E["actionbars.bagButton"]   = { "Bag button", "Shows a button to open the inventory next to the bars." }
E["actionbars.bars"]        = { "Visible bars", "How many bars (1 to 3) are shown." }
E["actionbars.spacing"]     = { "Button spacing", "Space between buttons." }
E["actionbars.buttonSize"]  = { "Bar 1 button size", "Size of the main buttons. Clears bar 1's individual size from Edit Mode." }
E["actionbars.smallSize"]   = { "Bars 2 and 3 button size", "Size of the secondary buttons. Clears the individual size of bars 2 and 3." }
E["actionbars.offsetX"]     = { "Horizontal position", "Moves every bar from the center." }
E["actionbars.offsetY"]     = { "Distance from bottom", "Height of the bars from the bottom of the screen." }
E["sec.barsEach"]    = { "Per bar", "Scale and columns of each bar (0 columns = layout default)." }
E["actionbars.bar1.scale"] = { "Bar 1: scale", "Size of bar 1 only." }
E["actionbars.bar1.cols"]  = { "Bar 1: buttons per row", "Buttons per row on bar 1. 0 uses the layout default." }
E["actionbars.bar2.scale"] = { "Bar 2: scale", "Size of bar 2 only." }
E["actionbars.bar2.cols"]  = { "Bar 2: buttons per row", "Buttons per row on bar 2. 0 uses the layout default." }
E["actionbars.bar3.scale"] = { "Bar 3: scale", "Size of bar 3 only." }
E["actionbars.bar3.cols"]  = { "Bar 3: buttons per row", "Buttons per row on bar 3. 0 uses the layout default." }
E["sec.stancePet"]   = { "Stance and pet", "Stance/form bar and pet command bar." }
E["actionbars.stance.enabled"]    = { "Stance/form bar", "Warrior stances, druid forms, presences and so on." }
E["actionbars.stance.buttonSize"] = { "Stance button size", "Size of each stance button." }
E["actionbars.stance.scale"]      = { "Stance bar scale", "Size of the stance group." }
E["actionbars.pet.enabled"]       = { "Pet bar", "Pet commands (attack, follow, pet abilities)." }
E["actionbars.pet.buttonSize"]    = { "Pet button size", "Size of each pet button." }
E["actionbars.pet.scale"]         = { "Pet bar scale", "Size of the pet group." }
E["sec.micromenu"]   = { "Utility menu", "Character, spellbook, talents, quests, game menu buttons and more." }
E["micromenu.enabled"]    = { "Enable utility menu", "Shows the bar with shortcuts to the game windows." }
E["micromenu.style"]      = { "Utility menu style", "Visual theme of the utility bar and info placards." }
E["o.micromenu.style=bdo"]      = { "Minimalist", "Current sleek look: translucent discs, clean glyphs and central diamond." }
E["o.micromenu.style=azaath"]   = { "Azaath Arcane", "Obsidian and antique gold dock with cyan crystal wings and arcane placard." }
E["o.micromenu.style=numenor"]  = { "Forge of Númenor", "Dark slate, tarnished bronze, etched icons and forge ember glow." }
E["o.micromenu.style=tabletop"] = { "Tabletop RPG (WoW)", "Chiseled stone rail, 3D portrait slots, painted icons, latency bar and parchment." }
E["micromenu.buttonSize"] = { "Button size", "Size of each shortcut." }
E["micromenu.spacing"]    = { "Spacing", "Space between shortcuts." }
E["micromenu.scale"]      = { "Scale", "Size of the whole bar." }
E["micromenu.offsetX"]    = { "Horizontal position", "Moves the bar sideways." }
E["micromenu.offsetY"]    = { "Vertical position", "Moves the bar up or down." }
E["micromenu.idleAlpha"]  = { "Idle opacity", "How visible the bar is without the mouse over it. Low values keep the screen cleaner." }

E["sec.targetFrame"] = { "Target frame", "Health and name of your selection." }
E["unitframes.target.enabled"]      = { "Enable target frame", "Replaces Blizzard's target frame with the Azaath style one." }
E["unitframes.target.scale"]        = { "Scale", "Size of the target frame." }
E["unitframes.target.width"]        = { "Width", "Length of the target health bar." }
E["unitframes.target.healthHeight"] = { "Health height", "Thickness of the target health bar." }
E["unitframes.target.nameFont"]     = { "Name size", "Size of the target's name." }
E["unitframes.target.offsetX"]      = { "Horizontal position", "Moves the frame from the center." }
E["unitframes.target.offsetY"]      = { "Distance from top", "Distance from the frame to the top of the screen." }
E["sec.targetAuras"] = { "Target auras", "Buffs and debuffs of your selection." }
E["auras.target.enabled"]  = { "Enable target auras", "Shows the target's buffs and debuffs next to its frame." }
E["auras.target.onlyMine"] = { "Only my debuffs", "Hides other players' debuffs. Good for tracking your DoTs in raids." }
E["auras.target.scale"]    = { "Scale", "Size of the icon group." }
E["auras.target.size"]     = { "Icon size", "Size of each icon in pixels." }
E["auras.target.spacing"]  = { "Spacing", "Space between icons." }
E["sec.nameplates"]  = { "Nameplates", "Health bars and names above enemies and allies." }
E["nameplates.enabled"]           = { "Azaath style nameplates", "Enemies with spaced names, thin bars, level diamond and wings on elites." }
E["nameplates.style"]             = { "Nameplate style", "Look of enemy nameplates. In all of them: your target is bigger with a golden name and mobs aggroed on you get a red aura. Reloads on change." }
E["o.nameplates.style=auto"]   = { "Follow the skin", "Zerker uses Minimal; Azaath and Reforged use Azaath." }
E["o.nameplates.style=azaath"] = { "Azaath", "Spaced name, ink-brush bar, level diamond and wings on elites." }
E["o.nameplates.style=zerker"] = { "Zerker", "Parallelogram bar with the same liquid art as the health frame." }
E["o.nameplates.style=blizzard"] = { "Blizzard", "The game's default nameplates, without the Azaath markers, frames and effects." }
E["o.nameplates.style=minimal"] = { "Minimal", "Like Black Desert: small name and a thin rounded bar." }
E["nameplates.castBar"]           = { "Enemy cast bars", "Cast bar under the enemy plate so you know what to interrupt." }
E["nameplates.allies"]            = { "Azaath style allies", "Friendly players with level diamond and name." }
E["nameplates.friendlyClickable"] = { "Select allies via plate", "Lets you click an ally's plate to target them. Turn off if it gets in the way of world clicks." }
E["nameplates.utilityNPCs"]       = { "Service NPC plates", "Auctioneers, repair, innkeepers, vendors and quest givers get their own plate." }
E["nameplates.pets"]              = { "Azaath style pets", "Friendly pets with a smaller plate." }
E["nameplates.hideWorldNames"]    = { "Hide WoW names at range", "Removes the game's default names on allies and pets to avoid duplicates." }
E["nameplates.width"]             = { "Plate width", "Length of enemy health bars." }
E["nameplates.allyOffsetY"]       = { "Ally plate height", "Moves the ally plate closer (negative) or farther from their head." }
E["btn.openPlatesDesigner"] = { "Customize everything (Visual Designer)", "Opens the full Nameplates Designer with live preview, auras, execute, threat, colors, profiles and import/export (/azplates).", "Open Designer" }
E["btn.testPlates"]  = { "Test nameplates", "Simulates a cast on visible nameplates.", "Test" }

E["sec.castPlayer"]  = { "Player cast bar", "Bar or spiral showing your spells being cast." }
E["castbar.player.enabled"]  = { "Enable player cast bar", "Shows your spell progress in AzaathUI style." }
E["castbar.player.style"]    = { "Style", "Spiral (like Azaath) or horizontal bar. Reloads on change." }
E["o.castbar.player.style=ring"] = { "Spiral", "Ring that fills around the spell icon." }
E["o.castbar.player.style=bar"]  = { "Horizontal bar", "Straight bar with icon and latency zone." }
E["castbar.player.effects"]  = { "Spell school effects", "Glow in the school color (holy, fire, frost, shadow...) while casting." }
E["castbar.player.ringSize"] = { "Spiral size", "Diameter of the cast ring." }
E["castbar.player.showLatency"] = { "Show latency", "Paints the end of the bar with your latency: you can queue the next spell once inside it." }
E["castbar.player.scale"]    = { "Scale", "Size of the cast bar." }
E["castbar.player.width"]    = { "Width", "Bar length." }
E["castbar.player.height"]   = { "Height", "Bar thickness." }
E["castbar.player.offsetX"]  = { "Horizontal position", "Moves from the center." }
E["castbar.player.offsetY"]  = { "Vertical position", "Moves up or down." }
E["btn.testCast"]    = { "Test cast bars", "Shows a sample cast on the player, the target and nameplates.", "Test" }
E["sec.castWorld"]   = { "Object interaction", "Gathering herbs, ore, chests and quest objects." }
E["castbar.world.enabled"]      = { "Spiral over the object", "When gathering or opening something, the spiral appears on the object instead of your character." }
E["castbar.world.size"]         = { "Ring size", "Diameter of the spiral over the object." }
E["castbar.world.plateOffsetY"] = { "Vertical position", "Raises or lowers the spiral relative to the object (negative lowers)." }
E["sec.castTarget"]  = { "Target cast bar", "Bar with what your target is casting." }
E["castbar.target.enabled"] = { "Enable target cast bar", "Shows the target's spells so you know when to interrupt." }
E["castbar.target.scale"]   = { "Scale", "Size of the target bar." }
E["castbar.target.width"]   = { "Width", "Bar length." }
E["castbar.target.height"]  = { "Height", "Bar thickness." }
E["castbar.target.offsetX"] = { "Horizontal position", "Moves from the center." }
E["castbar.target.offsetY"] = { "Vertical position", "Moves up or down." }
E["sec.combatText"]  = { "Floating damage", "Damage numbers coming off the target, Azaath style." }
E["combattext.enabled"]      = { "Enable floating damage", "Shows the damage you deal next to the target, crits in orange." }
E["combattext.hideBlizzard"] = { "Hide Blizzard damage", "Turns off the game's default numbers to avoid duplicates." }
E["combattext.showIcons"]    = { "Damage type icons", "Draws slash, pierce, fire and so on next to the number." }
E["combattext.onlyMine"]     = { "Only my damage", "Hides damage dealt by allies to your target." }
E["combattext.showPet"]      = { "Pet damage", "Includes damage dealt by your pet." }
E["combattext.showPeriodic"] = { "Periodic damage", "Includes DoTs, poisons and bleeds (more numbers on screen)." }
E["combattext.showMiss"]     = { "Show misses", "Shows Dodge, Parry and Miss when a hit fails." }
E["combattext.normalSize"]   = { "Normal hit size", "Font size of regular hits." }
E["combattext.critSize"]     = { "Critical size", "Font size of critical hits." }
E["combattext.offsetX"]      = { "Distance from target", "How far to the right of the target numbers spawn." }
E["combattext.duration"]     = { "Duration", "How long each number stays visible." }
E["combattext.floatDistance"] = { "Float distance", "How far the number rises while fading." }
E["combattext.scale"]        = { "Global scale", "Multiplies the size of every number." }
E["btn.testDamage"]  = { "Test damage", "Shows a normal (65) and a critical (84) hit.", "Test" }

E["sec.party"]       = { "Party frames", "Health of your party members." }
E["note.party"]      = "Click: target. Middle click: focus. Right click: menu (whisper, inspect, trade and, if you are the leader, promote or remove)."
E["party.enabled"]    = { "Enable AzaathUI party frames", "Replaces Blizzard's party frames." }
E["party.classColor"] = { "Class colored health", "Paints each member's bar with their class color." }
E["party.showInRaid"] = { "Also show in raids", "Keeps the frames visible inside raids (shows your subgroup)." }
E["party.scale"]      = { "Scale", "Size of the frames." }
E["party.width"]      = { "Width", "Length of each frame." }
E["party.barHeight"]  = { "Health height", "Thickness of the health bar." }
E["party.spacing"]    = { "Member spacing", "Vertical distance between members." }
E["party.offsetX"]    = { "Distance from left", "Moves the frames away from the left edge." }
E["party.offsetY"]    = { "Distance from top", "Moves the frames away from the top of the screen." }

E["sec.compass"]     = { "Compass", "Heading strip at the top of the screen." }
E["compass.enabled"]     = { "Enable compass", "Shows the Azaath compass with cardinal points and the focused quest pin." }
E["compass.showZone"]    = { "Zone name", "Golden plate with the current area name under the compass." }
E["compass.showDegrees"] = { "Heading in degrees", "Shows the numeric angle of your heading (Azaath doesn't)." }
E["compass.scale"]       = { "Scale", "Size of the compass." }
E["compass.width"]       = { "Width", "Length of the compass strip." }
E["compass.height"]      = { "Height", "Thickness of the strip." }
E["compass.fov"]         = { "Field of view", "How many degrees fit edge to edge. Fewer degrees = more spaced marks." }
E["compass.offsetX"]     = { "Horizontal position", "Moves the compass from the center." }
E["compass.offsetY"]     = { "Distance from top", "Moves the compass away from the top of the screen." }
E["sec.minimap"]     = { "Minimap", "Small map in the screen corner." }
E["minimap.enabled"]    = { "Enable AzaathUI minimap", "Replaces Blizzard's minimap." }
E["minimap.square"]     = { "Square shape", "Square minimap instead of round." }
E["minimap.showCoords"] = { "Coordinates", "Shows your coordinates on the minimap." }
E["minimap.showClock"]  = { "Clock", "Shows the time on the minimap." }
E["minimap.scale"]      = { "Scale", "Size of the minimap." }
E["minimap.size"]       = { "Size", "Map width and height in pixels." }
E["minimap.offsetX"]    = { "Horizontal position", "Moves from the top right corner." }
E["minimap.offsetY"]    = { "Vertical position", "Moves from the top right corner." }
E["sec.worldmap"]    = { "World map", "Big map (M key)." }
E["worldmap.enabled"] = { "AzaathUI world map", "Uses AzaathUI's own map on the map key. Off opens Blizzard's map." }
E["note.worldmap"]   = "Map filters (herbs, ore, dungeons, flight, quest areas, terrain) live in the map's own top bar."
E["sec.questNav"]    = { "Quest navigation", "Markers and guidance to objectives." }
E["questnav.enabled"]     = { "Quest navigation", "Navigation system toward the focused quest." }
E["questnav.worldMarker"] = { "3D world marker", "Diamond over the objective with distance and inside/outside/above hints." }
E["questnav.compassPin"]  = { "Compass pin", "Shows the focused quest as a pin on the compass." }
E["questnav.magicPath"]   = { "Magic path", "Draws a walkable trail to the objective around obstacles. Needs the route addons (AzaathUI_Nav_EK/Kalimdor) enabled." }
E["questroute.autoAdvance"] = { "Auto advance", "The guide moves to the next step on its own when you finish the current one." }
E["questroute.autoQuest"]   = { "Auto accept and turn in", "Accepts and turns in quests automatically when talking to NPCs. Hold Shift to pause." }
E["sec.questTracker"] = { "Quest tracker", "Side list of tracked quests." }
E["note.questTracker"] = "Click a quest to open it in the log; right click to untrack. Click the QUESTS title to collapse."
E["questtracker.enabled"]          = { "Enable AzaathUI tracker", "Replaces Blizzard's quest tracker." }
E["questtracker.showAchievements"] = { "Tracked achievements", "Includes the achievements you are tracking." }
E["questtracker.customPos"]        = { "Free position", "Detaches the tracker from the minimap so you can place it anywhere." }
E["questtracker.transparentBg"]    = { "Transparent background", "Removes the dark panel behind the list." }
E["questtracker.scale"]     = { "Scale", "Size of the tracker." }
E["questtracker.width"]     = { "Width", "Width of the list." }
E["questtracker.maxHeight"] = { "Maximum height", "Maximum height before the list scrolls." }
E["questtracker.offsetX"]   = { "Horizontal position", "Moves the tracker (with free position)." }
E["questtracker.offsetY"]   = { "Distance from top", "Moves the tracker from the top (with free position)." }

E["sec.lootWindow"]  = { "Loot window", "What happens when looting a corpse or chest." }
E["loot.enabled"]      = { "Azaath style loot", "AzaathUI's own loot window." }
E["loot.autoLoot"]     = { "Auto loot", "Takes everything without a window, like Azaath. Holding Shift while looting inverts it." }
E["loot.showWhenFull"] = { "Open if items are left", "With full bags, opens the window so you choose what to leave." }
E["loot.scale"]   = { "Window scale", "Size of the loot window." }
E["loot.width"]   = { "Window width", "Width of the loot window." }
E["loot.offsetX"] = { "Horizontal position", "Moves the window from the center." }
E["loot.offsetY"] = { "Vertical position", "Moves the window up or down." }
E["sec.lootFeed"]    = { "Notifications", "\"+1 item\" notices of what you received." }
E["loot.feed"]         = { "Item notifications", "Shows each item, gold or currency received as a strip on screen." }
E["loot.feedDuration"] = { "Time on screen", "How long each notice stays visible." }
E["loot.feedMax"]      = { "Maximum at once", "How many notices can stack." }
E["loot.feedScale"]    = { "Scale", "Size of the notices." }
E["loot.feedX"]        = { "Horizontal position", "Moves the notices sideways." }
E["loot.feedY"]        = { "Vertical position", "Moves the notices up or down." }
E["btn.testFeed"]    = { "Test notifications", "Shows sample notices to check position and size.", "Test" }
E["sec.lootRolls"]   = { "Group rolls", "Panel with each member's choice and roll on contested items." }
E["lootRolls.enabled"] = { "Roll panel", "Shows who chose Need, Greed or passed, the rolls, the current leader and the winner. Drag the header to move it." }
E["btn.testRolls"]   = { "Test rolls", "Shows a sample of the panel (same as /azaath rolls).", "Test" }
E["sec.lootBeam"]    ={ "Corpse loot beams", "Rarity-colored beam over corpses with loot." }
E["lootBeam.enabled"]        = { "Loot beam", "Vertical beam over the corpse: green uncommon, blue rare, purple epic, orange legendary." }
E["lootBeam.showOnUnopened"] = { "Light on unopened corpses", "Shows the light before you open the corpse." }
E["lootBeam.rarityBurst"]    = { "Rarity burst", "On loot, a burst of light in the color of the rarest item." }
E["lootBeam.persistRarity"]  = { "Keep color if items remain", "If you left something on the corpse, the light keeps the rarity color." }
E["lootBeam.multiCorpse"]    = { "Several corpses at once", "Keeps the light on corpses you have seen, not only the last one." }
E["lootBeam.beamHeight"]     = { "Beam height", "Height of the light column." }
E["lootBeam.beamWidth"]      = { "Beam width", "Thickness of the light column." }
E["lootBeam.groundFactor"]   = { "Drop to ground", "How far the beam reaches down to the corpse's feet. Adjust if it floats or sinks." }
E["lootBeam.offsetY"]        = { "Vertical fine tune", "Small height correction of the beam." }
E["btn.testBeam"]    = { "Test loot beam", "Toggles a sample beam (same as /azaath beam).", "Test" }
E["sec.lootCelebration"] = { "Loot celebrations (Dopamine)", "Flashy Azaath-styled celebration cards for rare loot, Bloated fish, milestones and rare kills." }
E["lootCelebration.enabled"]       = { "Enable loot celebrations", "Shows a celebratory card with particles, rays and fanfare when obtaining rare finds." }
E["lootCelebration.sound"]         = { "Fanfare sound", "Plays the themed celebration audio (uncommon, rare, epic, treasure, fish, bloated)." }
E["lootCelebration.edgeGlow"]      = { "Screen edge glow", "Softly illuminates screen edges in the rarity color on major drops." }
E["lootCelebration.glowIntensity"] = { "Edge glow intensity", "Controls the strength of the screen-edge vignette." }
E["o.lootCelebration.glowIntensity=normal"] = { "Normal", "Full visual punch for maximum dopamine." }
E["o.lootCelebration.glowIntensity=soft"]   = { "Soft", "Subtler edge lighting." }
E["lootCelebration.borderPulse"]   = { "Animated border pulse", "A rarity-colored light trail continuously sweeps around the card border." }
E["lootCelebration.greenBoE"]      = { "Uncommon BoE gear", "Celebrates Bind-on-Equip green gear dropped in the world." }
E["lootCelebration.quietFishing"]  = { "Quiet fishing finds", "Shows a restrained card when fishing up useful potions." }
E["lootCelebration.milestones"]    = { "Profession milestones", "Celebrates reaching 75, 150, 225 and 300 in any profession." }
E["lootCelebration.rareKills"]     = { "Rare enemies defeated", "Celebrates defeating a rare or rare-elite enemy with its 3D portrait." }
E["lootCelebration.showVendor"]    = { "Show vendor value", "Displays NPC merchant sell value on qualifying item cards." }
E["lootCelebration.showAH"]        = { "Show auction value", "Displays the lowest Auction House price seen (Azaath or Auctionator scan)." }
E["lootCelebration.movableAlerts"] = { "Drag active alert", "Allows temporarily dragging an active alert card on screen." }
E["lootCelebration.durationScale"] = { "Card duration", "Scales how long each celebration stays visible." }
E["lootCelebration.scale"]         = { "Card scale", "Size of the celebration card." }
E["lootCelebration.offsetX"]       = { "Horizontal position", "Moves the card sideways from center." }
E["lootCelebration.offsetY"]       = { "Vertical position", "Moves the card up or down from center." }
E["btn.testCelebration"] = { "Test celebration", "Triggers sample celebrations (Epic and Bloated Fish) to preview visuals and sound.", "Test" }
E["btn.testLegendary"]   = { "Legendary item preview", "Triggers the Legendary loot card (Thunderfury) with the full epic choir.", "Test Legendary" }
E["btn.openLootJournal"] = { "Loot & Fishing Chronicles", "Opens the journal with fishing records, loot breakdown and roll luck (/saques).", "Open journal" }

E["sec.dialog"]      = { "Dialogs", "NPC conversations and quest windows." }
E["dialog.enabled"]     = { "Azaath style dialogs", "Replaces Blizzard's gossip and quest windows." }
E["dialog.numberKeys"]  = { "Keys 1-9 pick options", "Answer and choose quests with the keyboard." }
E["dialog.interactKey"] = { "F picks the first option", "Press F to advance without the mouse." }
E["dialog.scale"]       = { "Scale", "Size of the dialog window." }
E["dialog.width"]       = { "Width", "Width of the dialog window." }
E["dialog.offsetX"]     = { "Horizontal position", "Moves the window sideways." }
E["dialog.offsetY"]     = { "Vertical position", "Moves the window up or down." }
E["sec.npcCamera"]   = { "Cinematic camera", "Zooms the camera in while talking to NPCs." }
E["npcCamera.enabled"]         = { "Cinematic camera", "When talking to an NPC, the camera closes in and frames the conversation." }
E["npcCamera.questAndGossip"]  = { "Quest and gossip NPCs", "Enables the camera for dialogs and quests." }
E["npcCamera.otherNPCs"]       = { "Other NPCs", "Also enables it for vendors, trainers, bank, auction house and flight masters." }
E["npcCamera.zoomDistance"]    = { "Zoom distance", "How close the camera gets to the character." }
E["npcCamera.shoulderOffset"]  = { "Shoulder offset", "Moves the camera sideways, giving the NPC more room." }
E["npcCamera.focusStrength"]   = { "NPC focus", "How much the camera turns to look at the NPC (0 = none, 1 = fully)." }
E["npcCamera.dynamicPitch"]    = { "Dynamic pitch", "Tilts the camera during the conversation for a more cinematic framing." }
E["npcCamera.fovZoom"]         = { "Field of view zoom", "Narrows the field of view during the conversation, like a lens." }
E["npcCamera.fovTarget"]       = { "Conversation field of view", "Angle used while talking (smaller = more zoom)." }
E["npcCamera.subtlePan"]       = { "Subtle pan", "Small continuous camera drift so the scene isn't static." }
E["npcCamera.vignette"]        = { "Edge vignette", "Darkens the screen edges during the conversation." }
E["npcCamera.disableInCombat"] = { "Disable in combat", "Restores the camera immediately if combat starts." }
E["npcCamera.disableInInstances"] = { "Disable in dungeons and raids", "Leaves the camera alone inside instances." }
E["sec.merchant"]    = { "Merchant", "Buying, selling and repairs." }
E["merchant.enabled"]     = { "Azaath style merchant", "AzaathUI buy, buyback and repair window." }
E["merchant.autoRepair"]  = { "Auto repair", "Repairs all gear when opening a merchant that repairs." }
E["merchant.guildRepair"] = { "Use guild bank", "Auto repair uses guild funds when allowed." }
E["sec.auction"]          = { "Auction House", "Prices read automatically when the auction house opens; no Auctionator needed." }
E["auction.autoScan"]     = { "Automatic scan", "When the Auction House opens, reads every price (the server allows it once every 15 min). /leilao varrer forces it." }
E["auction.cardPrice"]    = { "Auction price on card", "Shows the lowest price seen in the last scan on the item card." }

E["sec.inventory"]   = { "Inventory", "Bags and items." }
E["inventory.enabled"]       = { "Unified inventory", "Merges every bag into one Azaath style window." }
E["inventory.style"]         = { "Bag look", "Frame and style of the inventory window. Applies after /reload." }
E["o.inventory.style=classic"] = { "Default", "Brushed blue header and dark body (current look)." }
E["o.inventory.style=azaath"]  = { "Azaath", "Teal and gold frame, crystal crest, category chips and rarity rims." }
E["inventory.viewMode"]      = { "View mode", "How items are grouped in the window." }
E["o.inventory.viewMode=az"]   = { "Categories", "Weapons, gear, consumables, materials and so on, like Azaath." }
E["o.inventory.viewMode=bags"] = { "Separate bags", "Each bag in its own section." }
E["inventory.showItemLevel"] = { "Item level", "Prints each gear piece's item level on the icon corner." }
E["inventory.columns"]       = { "Columns", "Items per row." }
E["sec.charView"]    = { "Character with bags", "Gear around your character (B key)." }
E["character.enabled"]        = { "Gear around the character", "The B key shows your character in the center with gear slots around it." }
E["inventory.unified"]        = { "Open character together", "Opens the character with the inventory. Off, B opens only the bags, without turning the camera or hiding the HUD." }
E["inventory.openMode"]       = { "When opening the bag", "What shows up together with the inventory (B key)." }
E["o.inventory.openMode=camera"] = { "Character (camera)", "Turns the camera to the character and shows the gear around it." }
E["o.inventory.openMode=panel"]  = { "Equipped panel", "Gear panel beside the bag, with the radial menu below. Leaves the camera alone." }
E["o.inventory.openMode=bags"]   = { "Bag only", "Opens only the bags, without turning the camera or hiding the HUD." }
E["inventory.keepOnMove"]     = { "Walk with inventory open", "When you move, the character view closes (camera returns) and bags stay open. Entering combat still closes everything." }
E["inventory.cameraLock"]     = { "Turn camera to face you", "Turns the camera to the character's face while the window is open." }
E["inventory.cameraDistance"] = { "Camera distance", "How far the camera stays from the character (yards)." }
E["character.offsetY"]        = { "Gear height", "Raises or lowers the gear slot group." }
E["character.hideHUD"]        = { "Hide the HUD", "Hides AzaathUI bars while the character is open, for a clean view." }
E["sec.windows"]     = { "AzaathUI windows", "Replacements for Blizzard windows." }
E["sheet.enabled"]       = { "Character sheet (C)", "Full sheet: attributes, PvP, sanctuary, reputation and skills." }
E["talents.enabled"]     = { "Talent crucible (N)", "Talent window with the three trees branching from the core." }
E["spellbook.enabled"]   = { "Grimoire (P)", "Spellbook in the concept art style." }
E["professions.enabled"] = { "Crafting table (K)", "Professions window with recipe cards, favorites and altar." }

E["sec.chat"]        = { "Chat", "Chat window structure." }
E["chat.enabled"]      = { "Azaath style chat", "Enables the Aeternum look on the chat window." }
E["chat.backdrop"]     = { "Dark background panel", "Draws the dark panel behind messages." }
E["chat.cleanTabs"]    = { "Channel sidebar", "Replaces chat tabs with a sidebar and header." }
E["chat.cleanEditBox"] = { "New input bar", "Text box with channel pill and character counter." }
E["chat.hideButtons"]  = { "Hide extra buttons", "Removes the menu, voice and side arrow buttons." }
E["chat.mouseScroll"]  = { "Smooth scrolling", "Scrolls with the mouse wheel and shows a button to jump back to recent messages." }
E["sec.chatLook"]    = { "Appearance", "Opacity and font." }
E["chat.activeAlpha"] = { "Active opacity", "How visible chat is while hovered or typing." }
E["chat.idleAlpha"]   = { "Idle opacity", "How visible chat is when idle. 0 hides the background completely." }
E["chat.fontSize"]    = { "Font size", "Size of message text." }
E["chat.bold"]        = { "Bold font", "Uses PT Sans Bold for messages (easier to read on large screens)." }

E["sec.acMain"]      = { "Action Camera", "Mouse-locked camera, like action games." }
E["note.actioncam"]  = "Mouse Look, crosshair, reticle targeting, click casting, target lock, ally cycling and radial menu. Keybinds live in Esc > Options > Keybindings > AzaathUI."
E["actioncam.enabled"] = { "Enable Action Camera", "Turns on the whole action camera system. Off, every option below is inactive." }
E["sec.acCamera"]    = { "Camera and Mouse Look", "Camera movement and framing." }
E["actioncam.mouseLookSpeed"]       = { "Mouse Look speed", "Mouse sensitivity while the camera is locked." }
E["actioncam.shoulderOffset"]       = { "Shoulder offset", "Places the character slightly to the side, like third-person games." }
E["actioncam.shoulderFollowsMouseLook"] = { "Shoulder only in Mouse Look", "Applies the shoulder offset only while the camera is locked." }
E["actioncam.situations"] = { "Camera per situation", "Combat, boss, mount, flying, swimming, dungeon, indoors, resting and death get their own framing with smooth transitions." }
E["actioncam.situationZoomMemory"] = { "Remember zoom per situation", "Each situation keeps the camera distance you used in it and returns to it when you enter again." }
E["actioncam.shoulderZoomScale"] = { "Shoulder scales with zoom", "Scales the shoulder offset with camera distance so framing stays the same up close and far away." }
E["actioncam.dynamicPitch"]         = { "Dynamic pitch", "Tilts the camera to show more of what's ahead." }
E["actioncam.dynamicPitchStrength"] = { "Pitch strength", "How much the camera tilts." }
E["actioncam.minCameraZoom"]        = { "Minimum zoom", "Minimum camera distance (0 = no limit)." }
E["actioncam.autofocusLockedTarget"] = { "Follow locked target", "With target lock, the camera tracks the enemy." }
E["actioncam.respectMotionSickness"] = { "Motion sickness protection", "Honors the game option that reduces sudden camera motion." }
E["actioncam.vignetteConditions"]    = { "Edge vignette", "When to darken the screen edges." }
E["o.actioncam.vignetteConditions=mouselook"] = { "Mouse Look", "Only with the camera locked." }
E["o.actioncam.vignetteConditions=combat"]    = { "Combat", "Only in combat." }
E["o.actioncam.vignetteConditions=mouselook,combat"] = { "Both", "Camera locked or in combat." }
E["o.actioncam.vignetteConditions="]          = { "Off", "Never darkens the edges." }
E["sec.acCursor"]    = { "Cursor", "When the cursor shows and hides." }
E["actioncam.frameWatching"]           = { "Unlock when windows open", "Frees the cursor on its own when you open bags, map, dialogs and so on." }
E["actioncam.ctrlToggle"]              = { "Ctrl toggles Action Camera", "A quick tap on Ctrl locks/unlocks Mouse Look, like the V key. Ctrl+key, Ctrl+click or holding Ctrl do not toggle." }
E["actioncam.closeWindowsOnMouseLook"] = { "Mouse Look closes windows", "The Mouse Look key closes open windows before locking." }
E["actioncam.pulseCursor"]             = { "Cursor pulse", "A quick flash shows where the cursor reappeared." }
E["actioncam.hideTooltip"]             = { "Hide tooltips in Mouse Look", "Avoids flickering tooltips while you turn the camera." }
E["actioncam.tooltipModifier"]         = { "Peek tooltip while holding", "Key that shows the tooltip even in Mouse Look." }
E["o.actioncam.tooltipModifier=ALT"]   = { "Alt" }
E["o.actioncam.tooltipModifier=CTRL"]  = { "Ctrl" }
E["o.actioncam.tooltipModifier=SHIFT"] = { "Shift" }
E["actioncam.sheathWeaponsWithMouselook"] = { "Sheathe on exit", "Puts weapons away when leaving Mouse Look out of combat." }
E["sec.acCrosshair"] = { "Crosshair and HUD", "Center crosshair and info under it." }
E["actioncam.crosshair"]             = { "Center crosshair", "Shows a crosshair in the middle of the screen." }
E["actioncam.crosshairStyle"]        = { "Crosshair style", "Shape of the crosshair." }
E["o.actioncam.crosshairStyle=diamond"] = { "Diamond" }
E["o.actioncam.crosshairStyle=ring"]    = { "Ring" }
E["o.actioncam.crosshairStyle=dot"]     = { "Dot" }
E["o.actioncam.crosshairStyle=cross"]   = { "Cross" }
E["o.actioncam.crosshairStyle=star"]    = { "Star" }
E["actioncam.crosshairScale"]        = { "Crosshair scale", "Size of the crosshair." }
E["actioncam.crosshairY"]            = { "Crosshair height", "Raises or lowers the crosshair (useful with shoulder offset)." }
E["actioncam.crosshairCastFeedback"] = { "Cast ring on crosshair", "The crosshair shows cast progress." }
E["actioncam.interactionHUD"]        = { "Interaction HUD", "Under the crosshair, shows the name of what you can interact with." }
E["actioncam.interactionHUDPlayers"] = { "Players in interaction HUD", "Includes players in the interaction HUD." }
E["actioncam.crosshairTargetPreview"] = { "Target preview", "Shows a plate with what's under the crosshair on the right." }
E["actioncam.showTargetLockMarker"]  = { "Lock marker", "Draws a marker on the locked enemy's nameplate." }
E["sec.acTargeting"] = { "Reticle targeting", "Automatic selection and target lock." }
E["actioncam.reticleTargeting"]       = { "Reticle targeting", "Selects the enemy in the center of the screen on its own." }
E["actioncam.reticleOutline"]         = { "Target outline", "Glowing outline around the reticle target." }
E["actioncam.selectionCircleMode"]    = { "Ground circle", "Which target gets the selection circle under its feet." }
E["o.actioncam.selectionCircleMode=target"] = { "Target", "Only the selected target." }
E["o.actioncam.selectionCircleMode=soft"]   = { "Reticle", "The reticle's soft target." }
E["o.actioncam.selectionCircleMode=hidden"] = { "Hidden", "No circle." }
E["actioncam.autoTargetLockOnAttack"] = { "Lock on attack", "Locks the target automatically when you attack." }
E["actioncam.targetLockBehavior"]     = { "Lock key", "What the lock key does with an already locked target." }
E["o.actioncam.targetLockBehavior=toggle"] = { "Toggle", "Press again to release." }
E["o.actioncam.targetLockBehavior=switch"] = { "Switch", "Press again to switch to the next enemy." }
E["sec.acClick"]     = { "Click casting", "What each mouse button does in Mouse Look." }
E["actioncam.bindings.button1.value"]      = { "Left button", "Left click action while the camera is locked." }
E["actioncam.bindings.button2.value"]      = { "Right button", "Right click action while the camera is locked." }
E["actioncam.bindings.shiftbutton1.value"] = { "Shift + left", "Shift + left click action." }
E["actioncam.bindings.shiftbutton2.value"] = { "Shift + right", "Shift + right click action." }
E["o.actioncam.bindings.button1.value=ACTIONBUTTON1"]   = { "Bar 1, button 1" }
E["o.actioncam.bindings.button1.value=STARTATTACK"]     = { "Attack" }
E["o.actioncam.bindings.button1.value=TARGETMOUSEOVER"] = { "Reticle target" }
E["o.actioncam.bindings.button2.value=ACTIONBUTTON2"]     = { "Bar 1, button 2" }
E["o.actioncam.bindings.button2.value=INTERACTMOUSEOVER"] = { "Interact" }
E["o.actioncam.bindings.button2.value=CLEARTARGET"]       = { "Clear target" }
E["o.actioncam.bindings.shiftbutton1.value=ACTIONBUTTON3"] = { "Bar 1, button 3" }
E["o.actioncam.bindings.shiftbutton1.value=ACTIONBUTTON7"] = { "Bar 1, button 7" }
E["o.actioncam.bindings.shiftbutton1.value="]              = { "Disabled" }
E["o.actioncam.bindings.shiftbutton2.value=ACTIONBUTTON4"] = { "Bar 1, button 4" }
E["o.actioncam.bindings.shiftbutton2.value=ACTIONBUTTON8"] = { "Bar 1, button 8" }
E["o.actioncam.bindings.shiftbutton2.value="]              = { "Disabled" }
E["sec.acAlly"]      = { "Allies and support", "Ally cycling for healing and support." }
E["actioncam.allyCycle.showHud"]    = { "Ally cycle HUD", "Shows who is selected while cycling allies." }
E["actioncam.allyCycle.skipPlayer"] = { "Skip yourself", "The cycle doesn't stop on your character." }
E["actioncam.supportModeTintVignette"] = { "Support mode vignette", "Tints the screen edges while support mode is active." }
E["sec.acBdo"]       = { "Combat camera", "Black Desert style impact effects." }
E["btn.bdoPreset"]   = { "Black Desert preset", "Turns on the recommended framing and effects at once (shoulder, pitch, shake, inertia and dynamic zoom).", "Apply" }
E["actioncam.bdoEnabled"]      = { "Combat camera effects", "Enables the effects below during combat." }
E["actioncam.bdoIntensity"]    = { "Intensity", "Overall strength of the effects (0 = subtle, 1 = strong)." }
E["actioncam.bdoHitShake"]     = { "Hit shake", "Small camera shake on each hit." }
E["actioncam.bdoCastFocus"]    = { "Cast focus", "Light zoom while casting or channeling." }
E["actioncam.bdoSkillPunch"]   = { "Skill punch", "Small camera recoil when using abilities." }
E["actioncam.bdoMoves"]        = { "Camera per ability", "Charges push in, spins pull out, heavy strikes punch, shouts shake and Bladestorm pulls the camera back." }
E["actioncam.bdoHurtShake"]    = { "Shake when hit", "The camera shakes slightly when you take damage (stronger on crits)." }
E["actioncam.bdoCritImpact"]   = { "Critical impact", "Extra micro zoom on critical hits." }
E["actioncam.bdoCritSound"]    = { "Critical sound", "Plays an impact sound on crits." }
E["actioncam.bdoCritSoundStyle"] = { "Critical sound style", "Which sound plays on crits." }
E["o.actioncam.bdoCritSoundStyle=impact"]  = { "Metal impact" }
E["o.actioncam.bdoCritSoundStyle=ping"]    = { "Metal ping" }
E["o.actioncam.bdoCritSoundStyle=drum"]    = { "War drum" }
E["o.actioncam.bdoCritSoundStyle=thunder"] = { "Heavy boom" }
E["actioncam.bdoSpeedZoom"]     = { "Speed zoom", "Pulls the camera back while running or mounted." }
E["actioncam.bdoCameraInertia"] = { "Camera inertia", "The camera follows the character with a slight smooth delay." }
E["actioncam.bdoCombatZoomOut"] = { "Zoom out in combat", "Opens the camera when combat starts to see more around you." }
E["sec.acRadial"]    = { "Radial menu", "Wheel of consumables and shortcuts." }
E["actioncam.radialEnabled"]   = { "Enable radial menu", "Hold the radial menu key to pick consumables on a wheel." }
E["actioncam.radialBackdrop"] = { "Radial menu background", "When off, the wheel is transparent: only the gold rings, icons and center, so you see the game behind it." }
E["actioncam.soundRadialMenu"] = { "Radial menu sounds", "Plays sounds when opening and choosing." }
E["btn.radialConsumables"] = { "Radial menu consumables", "Choose which potions, food and items appear on the wheel.", "Configure" }
E["btn.radialSpells"] = { "Radial menu abilities", "Pick up to eight abilities (blessings, buffs, forms...) for the wheel's Abilities tab.", "Configure" }
E["sec.acMaint"]     = { "Maintenance", "Back to defaults." }
E["btn.acReset"]     = { "Reset Action Camera", "Restores every action camera setting and the game's camera CVars to default.", "Restore" }

E["sec.olho"]        = { "Object highlight", "Glow on ore, herbs, chests, quest objects and fishing bobbers." }
E["btn.olhoStudio"]  = { "Eye of Azaath studio", "3D preview, effects and glow colors (same as /olho).", "Open studio" }
E["olho.enabled"]    = { "Enable Eye of Azaath", "Makes world objects glow as you get close." }
E["olho.range"]      = { "Range", "How far objects are highlighted." }
E["olho.arc"]        = { "Direction", "Which direction around the character to look for objects." }
E["o.olho.arc=0"]    = { "Straight ahead", "Only what's directly in front of you." }
E["o.olho.arc=1"]    = { "Ahead", "A wide cone in front." }
E["o.olho.arc=2"]    = { "360 degrees", "Every direction." }
E["olho.glowOnly"]   = { "Glow only", "Keeps the game's (or another addon's) plate and only adds the glow." }
E["olho.exclusive"]  = { "Only highlighted targets", "Hides plates of objects that are not highlighted." }
E["olho.silhouette"] = { "Through the character", "The glow shows even behind your character (silhouette)." }
E["olho.hideInCombat"]   = { "Hide in combat", "Turns the glow off while fighting." }
E["olho.hideInInstance"] = { "Hide in instances", "Turns the glow off in dungeons and raids." }

E["sec.blizzard"]    = { "Blizzard interface", "Which original frames stay hidden." }
E["note.blizzard"]   = "Checked = hidden. Unchecking brings back Blizzard's original frame; keep it checked while using the AzaathUI replacement so both don't show."
E["hideBlizzard.actionBars"]   = { "Hide action bars", "Blizzard's main bar, XP/reputation and bottom bars." }
E["hideBlizzard.playerFrame"]  = { "Hide player frame", "Blizzard's player portrait and bars." }
E["hideBlizzard.targetFrame"]  = { "Hide target frame", "Blizzard's target portrait and bars." }
E["hideBlizzard.minimap"]      = { "Hide minimap", "Blizzard's minimap (queue and mail indicators remain)." }
E["hideBlizzard.buffs"]        = { "Hide buffs", "Blizzard's buffs, debuffs and weapon enchants." }
E["hideBlizzard.questTracker"] = { "Hide quest tracker", "Blizzard's quest list." }
E["hideBlizzard.partyFrames"]  = { "Hide party frames", "Blizzard's party frames." }
E["sec.skins"]       = { "General appearance", "AzaathUI look on Blizzard elements." }
E["skins.tooltips"]  = { "Azaath style tooltips", "Dark tooltips bordered by item rarity color." }
E["skins.popups"]    = { "Azaath style dialogs and menus", "Confirmation boxes and dropdown menus with the AzaathUI look." }
E["skins.itemCard"]  = { "Item card (New World)", "When hovering an item: rarity-colored header, highlighted item level, effects with icons and a footer with binding, durability and sell value." }
E["skins.itemCardSparks"] = { "Card sparks", "Sparks rising in the header; rarer items get more sparks." }
E["skins.itemCardScale"]  = { "Card size", "Scale of the item card." }

-- First Steps (Modules/Config/Setup.lua) --------------------------------------
E["sec.setup"]       = { "First Steps", "Initial setup wizard." }
E["btn.setup"]       = { "First Steps wizard", "Choose module by module between the addon look and Blizzard's, plus skin, bars and scale. Reopening keeps the rest of your settings. Shortcut: /azaath setup.", "Open wizard" }
E["setup.title"]     = "First Steps"
E["setup.subtitle"]  = "Make the interface yours in a few clicks"
E["setup.step.1"]    = "Welcome"
E["setup.step.2"]    = "Modules"
E["setup.step.3"]    = "Features"
E["setup.step.4"]    = "Camera"
E["setup.step.5"]    = "Visual"
E["setup.step.6"]    = "Finish"
E["setup.back"]      = "Back"
E["setup.next"]      = "Next"
E["setup.skip"]      = "Skip wizard"
E["setup.skipTip"]   = "Closes without applying anything. Reopen any time with /azaath setup."
E["setup.finish"]    = "Finish"
E["setup.applyReload"] = "Apply and Reload UI"
E["setup.applyReloadTip"] = "Saves your choices and reloads the interface so the swapped modules take effect."
E["setup.pending"]   = "%d change(s) need a reload"
E["setup.welcome.title"] = "Welcome to AzaathUI"
E["setup.welcome.body"]  = "The addon can replace almost the whole Blizzard interface. Choose how to start: everything ready in the addon look, or deciding module by module."
E["setup.welcome.foot"]  = "Nothing is saved until you finish. Reopen any time with /azaath setup or from the panel (General)."
E["setup.mode.full"]   = { "Full Experience", "Turns on every addon module: bars, frames, map, bag, sheet, talents, dialogs, loot and more. Also turns on the extra features and the Action Camera; you still pick the skin, bars and scale afterwards." }
E["setup.mode.custom"] = { "Customize step by step", "Decide for each part of the interface whether you want the addon look or keep Blizzard's original window." }
E["setup.recommended"] = "Recommended"
E["setup.step2.title"] = "Addon or Blizzard"
E["setup.step2.desc"]  = "Choose who draws each part. Swapping a module only takes effect after reloading the interface."
E["setup.allAddon"]  = { "Enable All (Addon)", "Sets every module to the addon look." }
E["setup.allBlizz"]  = { "Keep Blizzard Default", "Sets every module to Blizzard's original windows and frames." }
E["setup.count"]     = "%d of %d modules with the addon look"
E["setup.addon"]     = "Addon"
E["setup.blizz"]     = "Blizzard"
E["setup.state.addon"] = "Chosen: addon look"
E["setup.state.blizz"] = "Chosen: Blizzard original"
E["setup.m.actionbars"]  = { "Action Bars", "Bars, stance and pet in the addon style." }
E["setup.m.player"]      = { "Player Frame", "Your character's health, resource and level." }
E["setup.m.target"]      = { "Target Frame", "Health, name and level of the selected target." }
E["setup.m.party"]       = { "Party Frames", "Group members on the left of the screen." }
E["setup.m.auras"]       = { "Buffs and Debuffs", "Player buffs and debuffs." }
E["setup.m.castbar"]     = { "Cast Bar", "Player spiral or bar and the target cast bar." }
E["setup.m.nameplates"]  = { "Nameplates", "Health and name above enemies' heads." }
E["setup.m.combattext"]  = { "Floating Damage", "Damage and healing numbers in the addon style." }
E["setup.m.minimap"]     = { "Minimap", "Minimap with coordinates and clock." }
E["setup.m.worldmap"]    = { "World Map", "The addon's own map on the M key." }
E["setup.m.questtracker"] = { "Quest Tracker", "Objective list at the side of the screen." }
E["setup.m.inventory"]   = { "Bag", "Unified inventory on the B key." }
E["setup.m.character"]   = { "Character and Gear", "3D model with the equipment slots." }
E["setup.m.sheet"]       = { "Sanctuary (Sheet)", "C key sheet: attributes, reputation, skills and Grimoire." }
E["setup.m.talents"]     = { "Talents", "Crucible with the three talent trees." }
E["setup.m.spellbook"]   = { "Spellbook", "The addon Grimoire instead of the spellbook." }
E["setup.m.professions"] = { "Professions", "Artisan's Table for crafting." }
E["setup.m.dialog"]      = { "Dialogs", "NPC and quest conversations in the addon style." }
E["setup.m.loot"]        = { "Loot", "The addon's own loot window." }
E["setup.m.merchant"]    = { "Merchant", "Vendors' buy and sell window." }
E["setup.m.chat"]        = { "Chat", "Clean, transparent chat window." }
E["setup.step6.title"] = "All set"
E["setup.step6.desc"]  = "Check the summary. Click a step above to review any choice before applying."
E["setup.camPreset"] = { "Camera style", "Off keeps the game camera. Classic turns on the Action Camera with default values. Black Desert applies the full preset (shoulder, pitch, shake and inertia)." }
E["o.setup.camPreset=off"]     = { "Off", "Normal game camera and cursor." }
E["o.setup.camPreset=classic"] = { "Classic", "Action Camera with the addon's default values." }
E["o.setup.camPreset=bdo"]     = { "Black Desert", "Over-the-shoulder camera with hit shake, cast focus and inertia." }
E["setup.why.cam"]   = "Pick a camera style to enable."
E["setup.sum.features"] = "Features on"
E["setup.sum.camera"] = "Action Camera"
E["setup.tips"]      = "Useful commands"
E["setup.summary"]   = "Summary"
E["setup.tip.1"]     = "Opens the panel with every option."
E["setup.tip.2"]     = "Edit Mode: drag and resize elements."
E["setup.tip.3"]     = "Reopens this wizard."
E["setup.tip.4"]     = "Shows or hides the addon interface."
E["setup.tip.5"]     = "Eye of Azaath studio (glow and gathering)."
E["setup.tip.6"]     = "Lists every command."
E["setup.where"]     = "To reopen: /azaath setup, /azaath tutorial or Panel > General > First Steps."
E["setup.sum.addon"] = "Addon modules"
E["setup.sum.blizz"] = "Blizzard modules"
E["setup.sum.reload"] = "Reload the interface"
E["setup.sum.reloadN"] = "Yes (%d change(s))"
E["setup.sum.none"]  = "Not needed"
E["setup.msg.combat"] = "the wizard will open after combat."
E["setup.msg.done"]  = "setup finished. Reopen with |cffe3c78b/azaath setup|r."
E["setup.msg.hint"]  = "new: First Steps wizard with |cffe3c78b/azaath setup|r."

--==============================================================================
-- Modo de Edição (texto em português -> inglês)
--==============================================================================
local ED = U.EDITOR_EN
ED["HUD Azaath Reforged (Vida)"] = "Azaath Reforged HUD (Health)"
ED["Barra de Experiência (XP)"] = "Experience Bar (XP)"
ED["Largura (0 = Auto)"] = "Width (0 = Auto)"
ED["Altura da Barra"] = "Bar Height"
ED["Divisões (Segmentos)"] = "Segments"
ED["Bússola"] = "Compass"
ED["Largura"] = "Width"
ED["Altura"] = "Height"
ED["Campo de Visão (°)"] = "Field of View (°)"
ED["Vida e Mana (Jogador)"] = "Health and Mana (Player)"
ED["Altura da Vida"] = "Health Height"
ED["Altura do Recurso (Mana)"] = "Resource Height (Mana)"
ED["Quadro do Alvo"] = "Target Frame"
ED["Tamanho da Fonte do Nome"] = "Name Font Size"
ED["Conjuração (Jogador)"] = "Cast Bar (Player)"
ED["Largura (barra) / Diâmetro (espiral)"] = "Width (bar) / Diameter (spiral)"
ED["Altura (barra)"] = "Height (bar)"
ED["Conjuração (Alvo)"] = "Cast Bar (Target)"
ED["Barra de Ação 1"] = "Action Bar 1"
ED["Barra de Ação 2"] = "Action Bar 2"
ED["Barra de Ação 3"] = "Action Bar 3"
ED["Tamanho dos Botões"] = "Button Size"
ED["Colunas (Botões por linha)"] = "Columns (Buttons per row)"
ED["Mochila"] = "Bag"
ED["Tamanho do Botão"] = "Button Size"
ED["Barra de Postura"] = "Stance Bar"
ED["Barra de Pet"] = "Pet Bar"
ED["Minimapa"] = "Minimap"
ED["Tamanho"] = "Size"
ED["Buffs do Jogador"] = "Player Buffs"
ED["Debuffs do Jogador"] = "Player Debuffs"
ED["Tamanho dos Ícones"] = "Icon Size"
ED["Ícones por Linha"] = "Icons per Row"
ED["Auras do Alvo"] = "Target Auras"
ED["Quadros de Grupo"] = "Party Frames"
ED["Altura da Barra de Vida"] = "Health Bar Height"
ED["Espaçamento entre Membros"] = "Member Spacing"
ED["Rastreador de Missões"] = "Quest Tracker"
ED["Altura Máxima"] = "Max Height"
ED["Micro Menu (Utilidades)"] = "Micro Menu (Utilities)"
ED["Espaçamento"] = "Spacing"
ED["Janela de Diálogo NPC"] = "NPC Dialog Window"
ED["Largura da Janela"] = "Window Width"
ED["Janela de Saque (Loot)"] = "Loot Window"
ED["Notificações de Saque"] = "Loot Notifications"
ED["Celebrações de Saque"] = "Loot Celebrations"
ED["Chat Azaath"] = "Azaath Chat"
ED["Largura do Chat"] = "Chat Width"
ED["Altura do Chat"] = "Chat Height"
ED["Inspetor de Elemento"] = "Element Inspector"
ED["Escala"] = "Scale"
ED["Posição Horizontal (X)"] = "Horizontal Position (X)"
ED["Posição Vertical (Y)"] = "Vertical Position (Y)"
ED["Centralizar X"] = "Center X"
ED["Resetar Elemento"] = "Reset Element"
ED["MODO DE EDIÇÃO AZAATHUI"] = "AZAATHUI EDIT MODE"
ED["Arraste = Mover · Canto = Redimensionar · Roda = Escala · Clique = Ajuste Fino"] = "Drag = Move · Corner = Resize · Wheel = Scale · Click = Fine Tune"
ED["Concluir"] = "Done"
ED["Menu /azaath"] = "/azaath Menu"
ED["Resetar Tudo"] = "Reset All"
ED["Grade"] = "Grid"
ED["\n• Posição fixa nesta skin\n• Canto ou Roda do mouse: Dimensionar HUD\n• Clique esquerdo: Editar no Inspetor\n• Clique direito: Resetar tamanho"] =
    "\n• Fixed position in this skin\n• Corner or mouse wheel: Resize HUD\n• Left click: Edit in Inspector\n• Right click: Reset size"
ED["\n• Arraste o botão ou quadro: Mover junto\n• Canto: Redimensionar\n• Roda do mouse: Escala\n• Clique esquerdo: Editar no Inspetor\n• Clique direito: Resetar elemento"] =
    "\n• Drag the button or frame: Move\n• Corner: Resize\n• Mouse wheel: Scale\n• Left click: Edit in Inspector\n• Right click: Reset element"
ED["Arraste para redimensionar "] = "Drag to resize "
