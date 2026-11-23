-- Olho de Azaath: textos em português do Brasil
local _, Azaath = ...
local ns = Azaath.OlhoNS
local L = {}
ns.LOCALES.ptBR = L

L.LANGUAGE_NAME = "Português"
L.PREFIX = "|cffe3c78bOlho de Azaath|r: "
L.YES, L.NO = "sim", "não"
L.SETTING = "%s: %s"
L.OF_CATEGORY = "%s (%s)"
L.FORMAT_PERCENT = "%d%%"
L.FORMAT_RANGE = "%d m"
L.CONFIRM = "Confirmar?"

-- palavra digitada -> comando (os nomes em inglês sempre funcionam; acento é opcional)
L.COMMANDS = {
    ligar = "on", desligar = "off", previa = "preview", minimapa = "minimap", efeito = "effect", cor = "color",
    padrao = "default", compartilhado = "shared", tamanho = "size", intensidade = "intensity", deslocamento = "offset",
    texto = "text", fonte = "font", esmaecer = "fade", nome = "name", icone = "icon", combate = "combat",
    instancia = "instance", indisponivel = "unavailable", profissao = "profession", brilho = "glowonly",
    exclusivo = "exclusive", ignorar = "ignore", lista = "list", limpar = "clear", silhueta = "silhouette",
    mostrar = "show", alcance = "range", direcao = "arc", tecla = "key", nenhuma = "none", alternar = "switch",
    idioma = "language", objetivos = "objectives", estado = "status", ajuda = "help",
    minerio = "ore", erva = "herb", missao = "quest", bau = "chest", boia = "bobber", outro = "other",
}

-- categorias
L.CATEGORY_ORE, L.CATEGORY_ORE_TIP = "Minérios", "Veios e jazidas para minerar."
L.CATEGORY_HERB, L.CATEGORY_HERB_TIP = "Ervas", "Plantas para colher."
L.CATEGORY_QUEST, L.CATEGORY_QUEST_TIP = "Missões", "Objetos que fazem parte de uma missão que você está fazendo."
L.CATEGORY_CHEST, L.CATEGORY_CHEST_TIP = "Baús", "Baús, caixotes, barris: tudo o que se saqueia."
L.CATEGORY_BOBBER, L.CATEGORY_BOBBER_TIP = "Pesca", "A boia da sua linha de pesca."
L.CATEGORY_OTHER, L.CATEGORY_OTHER_TIP = "Outros", "O resto: portas, alavancas, caixas de correio..."
L.NAME_ORE, L.NAME_HERB, L.NAME_QUEST = "minério", "erva", "missão"
L.NAME_CHEST, L.NAME_BOBBER, L.NAME_OTHER = "baú", "boia", "outro"
L.NAME_NONE = "nenhuma"
L.NAME_UNNAMED = "Objetos sem nome"
L.SAMPLE_ORE, L.SAMPLE_HERB, L.SAMPLE_QUEST = "Veio de Cobre", "Flor-da-paz", "Caixote de Suprimentos"
L.SAMPLE_CHEST, L.SAMPLE_BOBBER, L.SAMPLE_OTHER = "Baú Gasto", "Boia de Pesca", "Caixa de Correio"
L.STATE_FAR, L.STATE_READY, L.STATE_LOCKED = "longe", "ao alcance", "recusado pelo jogo"

-- efeitos
L.EFFECT_AURA, L.EFFECT_AURA_TIP = "Aura", "Halo com névoa, anel, cometas e uma coroa de chamas."
L.EFFECT_SUBTLE, L.EFFECT_SUBTLE_TIP = "Sutil", "Só um halo macio, sem anel."
L.EFFECT_SIGIL, L.EFFECT_SIGIL_TIP = "Selo", "Círculo de runas girando em volta do objeto."
L.EFFECT_BRACKETS, L.EFFECT_BRACKETS_TIP = "Mira", "Quatro cantos procuram o objeto e travam nele ao alcance."
L.EFFECT_VORTEX, L.EFFECT_VORTEX_TIP = "Vórtice", "Braços de luz se enrolando como um portal."
L.EFFECT_RIFT, L.EFFECT_RIFT_TIP = "Fenda", "Um buraco escuro que engole faíscas em espiral."
L.EFFECT_FLAME, L.EFFECT_FLAME_TIP = "Chama", "Fogo na cor do objeto, com brasas e fumaça."
L.EFFECT_STORM, L.EFFECT_STORM_TIP = "Tempestade", "Uma nuvem acima do objeto soltando raios."
L.EFFECT_BEAM, L.EFFECT_BEAM_TIP = "Facho", "Coluna de luz subindo do objeto."
L.EFFECT_GEYSER, L.EFFECT_GEYSER_TIP = "Gêiser", "Jato de luz com gotas caindo em volta."
L.EFFECT_BEACON, L.EFFECT_BEACON_TIP = "Farol", "Um cristal flutuando acima do objeto."
L.EFFECT_ORBIT, L.EFFECT_ORBIT_TIP = "Órbita", "Três luzes girando em órbitas inclinadas."
L.EFFECT_SPIRIT, L.EFFECT_SPIRIT_TIP = "Espírito", "Dois fogos-fátuos dançando com fitas de luz."
L.EFFECT_RIPPLE, L.EFFECT_RIPPLE_TIP = "Ondas", "Ondulações abrindo no chão."
L.EFFECT_SPARKLE, L.EFFECT_SPARKLE_TIP = "Cintilar", "Lampejos que acendem e apagam em volta."

-- janela
L.TAB_LOOK, L.TAB_SETTINGS = "Aparência", "Ajustes"
L.SCOPE_ALL, L.SCOPE_ALL_TIP = "Todos", "Ajuste para todas as categorias. Categorias com aparência própria perdem o valor próprio do que você mudar."
L.SCOPE_ONE_TIP = "Ajuste só esta categoria. Clique na caixa para mostrar ou esconder o brilho dela neste personagem."
L.LOOK_OF_ALL = "Aparência de todos os objetos"
L.LOOK_OF = "Aparência: %s"
L.SHARED, L.SHARED_TIP = "Usar a aparência geral", "Tira desta categoria tudo o que ela tem de próprio."
L.EFFECT, L.EFFECT_TIP = "Efeito", "O desenho do brilho."
L.SIZE, L.SIZE_TIP = "Tamanho", "Tamanho do efeito."
L.INTENSITY, L.INTENSITY_TIP = "Intensidade", "Força da luz."
L.OFFSET, L.OFFSET_TIP = "Altura", "Sobe ou desce o efeito em relação à placa de nome do objeto."
L.FADE, L.FADE_TIP = "Some com a placa", "O efeito esmaece quando o jogo esmaece a placa (objeto atrás do cenário)."
L.SILHOUETTE, L.SILHOUETTE_TIP = "Passar atrás do personagem", "Recorta o efeito em volta do seu personagem, que fica na frente da luz."
L.SHOW_NAME, L.SHOW_NAME_TIP = "Nome", "Escreve o nome do objeto, na cor dele, no lugar do texto do jogo."
L.SHOW_ICON, L.SHOW_ICON_TIP = "Ícone", "Mostra o ícone de interação acima do nome."
L.TEXT_SIZE, L.TEXT_SIZE_TIP = "Tamanho do nome", "Tamanho do nome escrito sobre o objeto."
L.FONT, L.FONT_TIP, L.FONT_GAME = "Fonte do nome", "Fonte usada no nome do objeto.", "Fonte do jogo"
L.COLOR, L.COLOR_TIP = "Cor", "Cor do brilho desta categoria."
L.TIP_COLOR_SET, L.TIP_COLOR_RESET = "Clique: escolher a cor", "Botão direito: cor original"
L.SHOW_CATEGORY_TIP = "Marcado: os objetos desta categoria brilham neste personagem."

L.HEADER_DETECTION = "Detecção"
L.HEADER_GENERAL = "Geral"
L.HEADER_HIDE = "Quando esconder"
L.HEADER_SILHOUETTE = "Recorte do personagem"
L.HEADER_GATHER = "Coleta"
L.RANGE, L.RANGE_TIP = "Alcance", "Até que distância o jogo escolhe um objeto. Acima de 15 m o jogo não acha nada."
L.DIRECTION, L.DIRECTION_TIP = "Procurar", "Em que direção, em volta de você, o jogo procura objetos."
L.ARC_0, L.ARC_0_TIP = "Bem à frente", "Só o que está diretamente na sua frente."
L.ARC_1, L.ARC_1_TIP = "À frente", "Um cone largo na sua frente."
L.ARC_2, L.ARC_2_TIP = "Em volta", "Em todas as direções."
L.EXCLUSIVE, L.EXCLUSIVE_TIP = "Só destacar o que brilha", "O jogo deixa de mostrar placa e ícone nos alvos que o Olho não ilumina (PNJs, caixas de correio...). A tecla de interação continua funcionando neles."
L.KEY, L.KEY_TIP = "Tecla de interação", "É o atalho \"Interagir com o alvo\" do próprio jogo: pega, colhe ou usa o objeto destacado."
L.KEY_NONE, L.KEY_LISTEN = "Nenhuma", "Aperte uma tecla..."
L.KEY_LISTEN_TIP = "Aperte a tecla (com Shift, Ctrl ou Alt se quiser), um botão do mouse ou gire a roda. Esc cancela."
L.KEY_TAKEN = "%s já é usada por \"%s\". Aperte de novo para trocar mesmo assim."
L.TIP_KEY_SET, L.TIP_KEY_CLEAR = "Clique: escolher outra tecla", "Botão direito: tirar a tecla"
L.IGNORED, L.IGNORED_TIP = "Ignorados: %d", "Objetos que nunca brilham, pelo nome. Use o botão com o objeto mirado."
L.IGNORE_TARGET, L.IGNORE_TARGET_TIP = "Ignorar o mirado", "Ignora (ou volta a mostrar) o objeto mirado agora e todos com o mesmo nome."
L.ENABLE, L.ENABLE_TIP = "Ligado", "Desligado, o Olho devolve ao jogo as configurações de mira que mudou."
L.GLOW_ONLY, L.GLOW_ONLY_TIP = "Só a luz", "Não escreve nome nem ícone: a placa fica com o jogo ou com outro addon (sempre assim com o Plumber)."
L.MINIMAP, L.MINIMAP_TIP = "Botão no minimapa", "Mostra o botão do Olho na borda do minimapa."
L.DEBUG, L.DEBUG_TIP = "Diagnóstico no chat", "Escreve no chat o que o Olho entende de cada objeto mirado."
L.LANGUAGE, L.LANGUAGE_TIP = "Idioma", "Idioma dos textos e comandos do Olho."
L.LANGUAGE_AUTO, L.LANGUAGE_AUTO_TIP = "Automático", "O idioma do jogo."
L.HIDE_COMBAT, L.HIDE_COMBAT_TIP = "Em combate", "Sem brilho durante a luta."
L.HIDE_INSTANCE, L.HIDE_INSTANCE_TIP = "Em instâncias", "Sem brilho em masmorras, raides e campos de batalha."
L.HIDE_LOCKED, L.HIDE_LOCKED_TIP = "Recusados pelo jogo", "Apaga o brilho de objetos que você ainda não pode usar (perícia baixa, trancado...)."
L.HIDE_UNTRAINED, L.HIDE_UNTRAINED_TIP = "Sem a profissão", "Sem brilho em ervas sem Herborismo, nem em minérios sem Mineração."
L.ZONE_SIZE, L.ZONE_SIZE_TIP = "Tamanho", "Tamanho da área recortada em volta do personagem (de cada personagem)."
L.ZONE_HEIGHT, L.ZONE_HEIGHT_TIP = "Altura", "Sobe ou desce a área recortada."
L.ZONE_SHOW, L.ZONE_SHOW_TIP = "Mostrar a área", "Contorna a área em vermelho enquanto esta janela está aberta."
L.NODE_SWITCH, L.NODE_SWITCH_TIP = "Alternar ervas e minérios", "Com as duas profissões: troca entre Encontrar Ervas e Encontrar Minerais enquanto você anda (só neste personagem)."
L.NODE_SWITCH_YARDS, L.NODE_SWITCH_YARDS_TIP = "Trocar a cada", "Distância andada entre uma troca e outra."
L.DEFAULTS, L.DEFAULTS_TIP = "Padrões", "Volta aparência e ajustes ao original (ignorados e idioma ficam). Clique duas vezes."
L.FOOTER = "/olho ajuda: todos os comandos"
L.PREVIEW_NO_MODEL = "Sem modelo 3D neste cliente"
L.PREVIEW_HINT = "Arraste para girar, botão direito para mover, roda para aproximar"
L.OPTIONS_NOTE = "Faz minérios, ervas, objetos de missão e baús brilharem quando você chega perto."
L.OPTIONS_OPEN = "Abrir o Olho de Azaath"
L.TIP_ENABLED, L.TIP_DISABLED = "Ligado", "Desligado"
L.TIP_LEFT_CLICK, L.TIP_RIGHT_CLICK, L.TIP_DRAG = "Clique: abrir", "Botão direito: ligar ou desligar", "Arraste: mover o botão"

-- mensagens
L.MSG_ENABLED = "ligado."
L.MSG_DISABLED = "desligado; as configurações do jogo voltaram ao que eram."
L.NATIVE_SPARKLE, L.NATIVE_SPARKLE_TIP = "Purpurina do jogo", "Liga o brilho dourado do próprio jogo nos itens de missão e corpos com saque, em vários ao mesmo tempo. Desligar só some depois de reiniciar o jogo."
L.MSG_SPARKLE_RESTART = "a purpurina do jogo some depois de reiniciar o jogo (/reload não basta)."
L.MSG_EXCLUSIVE_ON ="o jogo só destaca o que brilha."
L.MSG_EXCLUSIVE_OFF = "o jogo volta a destacar todo alvo de interação."
L.MSG_SILHOUETTE_ON = "o brilho passa atrás do personagem."
L.MSG_SILHOUETTE_OFF = "o brilho cobre o personagem."
L.MSG_CUTOUT_UNAVAILABLE = "recorte indisponível: %s."
L.MSG_ZONE_SHOWN, L.MSG_ZONE_HIDDEN = "área do recorte contornada em vermelho.", "contorno escondido."
L.MSG_SILHOUETTE_VALUES = "recorte: tamanho %d%%, altura %d%%"
L.MSG_SILHOUETTE_USAGE = "uso: /olho silhueta [categoria] | mostrar | <tamanho {bodyScale}> [altura {bodyShift}]"
L.MSG_EFFECTS = "efeitos: %s (atual: %s)"
L.MSG_FONTS = "fontes: %s (atual: %s)"
L.MSG_COLOR = "%s: cor %s"
L.MSG_NO_PICKER = "sem seletor de cor neste cliente; use /olho cor <categoria> <rrggbb>."
L.MSG_SHARED = "%s voltou à aparência geral."
L.MSG_HIDE_COMBAT = "sem brilho em combate: %s"
L.MSG_HIDE_INSTANCE = "sem brilho em instâncias: %s"
L.MSG_HIDE_LOCKED = "sem brilho em objetos recusados: %s"
L.MSG_HIDE_UNTRAINED = "sem brilho sem a profissão: %s"
L.MSG_GLOW_ONLY = "só a luz: %s"
L.MSG_IGNORED, L.MSG_UNIGNORED = "%s não brilha mais.", "%s voltou a brilhar."
L.MSG_IGNORED_ALREADY = "%s já está ignorado (todos com esse nome). Repita em até 10 s para voltar a mostrar."
L.MSG_IGNORE_NO_TARGET = "nenhum objeto mirado."
L.MSG_IGNORE_LIST, L.MSG_IGNORE_EMPTY = "ignorados: %s", "nenhum objeto ignorado."
L.MSG_RANGE = "alcance: %d m"
L.MSG_RANGE_COMBAT = "alcance: %d m (aplicado ao sair do combate)."
L.MSG_RANGE_CLIENT = "alcance pedido: %d m; o jogo ficou com %s."
L.MSG_KEY_COMBAT = "atalhos não mudam em combate."
L.MSG_KEY_REFUSED = "o jogo recusou a tecla \"%s\"."
L.MSG_KEY_REPLACED = "%s deixou de fazer \"%s\"."
L.FAIL_NO_MASK = "este cliente não tem máscaras"
L.FAIL_MASK_TEXTURE = "imagem da máscara não encontrada (reinicie o jogo)"
L.FAIL_MASK_REFUSED = "o jogo recusou a máscara"

-- /olho estado
L.STATUS_CLIENT = "cliente %s (%s), idioma %s; textos do Olho: %s. Configurações do jogo:"
L.STATUS_CVAR_UNKNOWN = "não existe neste cliente"
L.STATUS_CVAR_DEFAULT = " (padrão %s)"
L.STATUS_EXPECTED = "o Olho pede: alcance %d, direção %d"
L.STATUS_GATE = "só destacar o que brilha: %s | destaque do jogo agora: %s"
L.GATE_OPEN, L.GATE_CLOSED = "aberto", "fechado"
L.STATUS_GLOW_ONLY = "só a luz: %s | Plumber escrevendo o nome: %s"
L.STATUS_SILHOUETTE = "recorte do personagem: %s"
L.STATUS_UNAVAILABLE = "indisponível (%s)"
L.STATUS_DIRECT = "placa lida direto do alvo: %s"
L.STATUS_NOT_YET = "ainda não"
L.STATUS_RANGE_API = "o jogo informa o alcance de interação: %s"
L.STATUS_LINE = "linha de pesca na água: %s | canalizando: %s"
L.STATUS_TRAINED = "esconder sem a profissão: %s | herborismo: %s, mineração: %s"
L.STATUS_HIDE = "esconder em combate: %s | em instância: %s | recusados: %s | pausado agora: %s"
L.STATUS_OBJECTS = "categorias deste personagem: %s | ignorados: %d"
L.STATUS_OWN = "categorias com aparência própria: %s"
L.STATUS_KEY = "tecla de interação: %s"
L.STATUS_EFFECT = "efeito: %s | imagens: %s"
L.TEXTURES_PENDING, L.TEXTURES_LOADED = "ainda não usadas", "carregadas"
L.TEXTURES_MISSING = "faltando (reinicie o jogo); usando o efeito reserva"
L.OBJECTIVES_HEADER = "%d objetivo(s) aberto(s):"
L.OBJECTIVES_NOT_ITEM = "  (de abate/fala: só o nome inteiro conta)"
L.OBJECTIVES_LEARNED = "aprendido pela dica: %s -> %s"

-- diagnóstico
L.DEBUG_NO_TARGET = "sem alvo de interação"
L.DEBUG_PAUSED = "pausado (combate ou instância)"
L.DEBUG_LINE_OUT = "linha na água: pedi %d m, o jogo está com %s"
L.DEBUG_LINE_IN = "linha recolhida: pedi %d m, o jogo está com %s"
L.DEBUG_IGNORED = "%s: não é objeto do cenário"
L.DEBUG_SKIPPED = "%s: está na lista de ignorados"
L.DEBUG_HIDDEN = "%s -> %s: categoria escondida ou desconhecida"
L.DEBUG_UNTRAINED = "%s -> %s: sem a profissão"
L.DEBUG_NO_PLATE = "%s -> %s: o jogo não deu placa de nome"
L.DEBUG_SHOWN = "%s -> %s, %s"
L.DEBUG_CURSOR, L.DEBUG_VIA, L.DEBUG_RANGE = "cursor %s", "alvo %s", "ao alcance %s"
L.DEBUG_OBJECT, L.DEBUG_FISHING, L.DEBUG_QUEST = "objeto %s", "pescando %s", "missão pelo jogo %s"
L.DEBUG_MATCH = "missão por: %s (%d objetivos)"
L.DEBUG_CHEST = "baú por: %s"
L.DEBUG_SECRET, L.DEBUG_BEHIND = "identidade secreta %s", "atrás da câmera %s"
L.VIA_DIRECT, L.VIA_SWEEP = "direto", "procurado nas placas"
L.MATCH_NONE, L.MATCH_CURSOR = "nada", "nada (o cursor já diz)"
L.MATCH_TOOLTIP, L.MATCH_NAME, L.MATCH_WORD, L.MATCH_LOOT = "dica aprendida", "nome", "palavra \"%s\"", "já saqueado"

-- ajuda; {ajuste} = limites, {ajuste=} = padrão
L.HELP_HEADER = "comandos:"
L.HELP = {
    "/olho - abre a janela | ligar | desligar | previa | minimapa",
    "/olho efeito [categoria] <nome> - escolhe o efeito; sem nome, lista",
    "/olho cor <categoria> <rrggbb> | padrao - cor da categoria",
    "/olho tamanho | intensidade | deslocamento | texto [categoria] <n> - tamanho {size}, intensidade {intensity}, altura {offsetY}, nome {textSize}",
    "/olho fonte [categoria] <nome> - fonte do nome; sem nome, lista",
    "/olho nome | icone | esmaecer [categoria] - liga ou desliga",
    "/olho compartilhado <categoria> - categoria volta à aparência geral",
    "/olho silhueta [categoria] | mostrar | <tamanho> [altura] - recorte do personagem",
    "/olho alcance <{range}> | direcao <{arc}> | exclusivo | brilho",
    "/olho combate | instancia | indisponivel | profissao - quando esconder",
    "/olho minerio | erva | missao | bau | boia | outro - mostra ou esconde a categoria",
    "/olho ignorar [lista | limpar | <nome>] - sem nome, o objeto mirado",
    "/olho tecla <TECLA> | nenhuma - tecla de interação do jogo",
    "/olho alternar [<{nodeSwitchYards}>] - alterna ervas e minérios no minimapa",
    "/olho idioma <auto | pt | en> | estado | objetivos | debug | ajuda",
}
