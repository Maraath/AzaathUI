--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/DesignerSchema.lua
    Esquema completo das opções do Designer Visual (peças da placa + abas
    globais: Geral, Alpha/Alcance, Escala/CVars, Cores/Ameaça e Perfis).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local ipairs = ipairs

local S = {}
NP.Schema = S

local function T(label, path, tip) return { t = "toggle", label = label, path = path, tip = tip } end
local function R(label, path, min, max, step, tip) return { t = "range", label = label, path = path, min = min, max = max, step = step, tip = tip } end
local function K(label, path, tip) return { t = "color", label = label, path = path, tip = tip } end
local function Sel(label, path, vals, ord, tip) return { t = "select", label = label, path = path, values = vals, order = ord, tip = tip } end
local function H(label) return { t = "header", label = label } end
local function Anchor(prefix)
    return {
        Sel("Âncora", prefix .. ".anchor.side", function()
            local m = {}; for k, v in pairs(NP.ANCHOR_SIDES) do m[k] = v[4] end; return m
        end, NP.ANCHOR_ORDER),
        R("Deslocamento X", prefix .. ".anchor.x", -150, 150, 0.5),
        R("Deslocamento Y", prefix .. ".anchor.y", -150, 150, 0.5),
    }
end

local function Append(dst, src)
    for _, v in ipairs(src) do dst[#dst + 1] = v end
    return dst
end

local MODES = { full = "Barra completa", nameOnly = "Somente nome", blizzard = "Padrão Blizzard" }
local MODE_ORDER = { "full", "nameOnly", "blizzard" }

-- Esquemas por peça clicável no Designer
S.PARTS = {
    { key = "health", label = "Barra de Vida", schema = function()
        local list = {
            H("Estilo & Dimensões"),
            Sel("Estilo predefinido de barra", "style.barStyle", NP.BAR_STYLES, NP.BAR_STYLE_ORDER,
                "Aplica os visuais Moderno, Azaath Clássico, Azaath Tinta, Zerker ou Minimalista."),
            Sel("Modo desta unidade", "units.$unit.mode", MODES, MODE_ORDER),
            R("Largura", "units.$unit.healthWidth", 40, 320, 1),
            R("Altura", "units.$unit.healthHeight", 3, 40, 0.5),
            R("Posição X", "units.$unit.healthOffsetX", -100, 100, 0.5),
            R("Posição Y", "units.$unit.healthOffsetY", -100, 100, 0.5),
            T("Cor de classe na barra", "units.$unit.useClassColor"),
            H("Aparência"),
            Sel("Textura da vida", "style.healthTexture", NP.StatusBarTextureList),
            R("Opacidade da textura", "style.healthTextureAlpha", 0, 1, 0.05),
            Sel("Textura de fundo", "style.healthBgTexture", NP.StatusBarTextureList),
            K("Cor de fundo", "style.healthBgColor"),
            Sel("Estilo da borda", "style.borderStyle", NP.BORDER_STYLES, { "pixel", "classic" }),
            R("Espessura da borda", "style.borderSize", 0, 5, 0.5),
            K("Cor da borda", "style.borderColor"),
            Sel("Cantos arredondados", "style.corners.health", NP.CORNER_STYLES, NP.CORNER_ORDER),
            T("Degradê vertical", "style.gradient.enabled"),
            R("Força do degradê", "style.gradient.alpha", 0, 1, 0.05),
            T("Animar barra suave", "style.animateHealth"),
            H("Absorção & Cura"),
            T("Mostrar absorção (escudos)", "style.absorbs.enabled"),
            K("Cor da absorção", "style.absorbs.color"),
            Sel("Posição da absorção", "style.absorbs.position", { smart = "Inteligente", after = "Após a vida", over = "Sobreposta" }, { "smart", "after", "over" }),
            T("Mostrar previsão de cura", "style.healPrediction.enabled"),
            K("Cor da previsão de cura", "style.healPrediction.color"),
            H("Faixa de Execute"),
            T("Ativar linha de Execute", "style.execute.enabled"),
            T("Detectar pelas suas magias", "style.execute.auto"),
            T("Só mostrar se possuir Execute", "style.execute.onlyWithExecute"),
            R("Porcentagem manual (%)", "style.execute.percent", 5, 50, 1),
            K("Cor normal da linha", "style.execute.color"),
            K("Cor dentro da faixa", "style.execute.executeColor"),
            T("Destacar zona de Execute", "style.execute.zone"),
            K("Cor da zona", "style.execute.zoneColor"),
            T("Ícone de Execute", "style.execute.icon"),
            R("Tamanho do ícone", "style.execute.iconSize", 10, 40, 1),
            Sel("Brilho do ícone", "style.execute.iconGlowStyle", NP.EXEC_GLOW_STYLES, NP.EXEC_GLOW_ORDER),
            T("Mostrar cooldown no ícone", "style.execute.iconCooldown"),
            T("Sempre visível (esmaecido fora)", "style.execute.iconAlways"),
            H("Fora de Combate (OOC) & CastWatch"),
            T("Inimigos só com nome até entrar em combate", "units.$unit.nameOnlyUntilCombat"),
            T("Apenas inimigos hostis", "units.$unit.nameOnlyHostileOnly"),
            T("Desativar OOC dentro de instâncias", "units.$unit.nameOnlyNotInstances"),
            T("Mostrar barra completa ao conjurar", "units.$unit.castFullPlate"),
            T("Não expandir em áreas de descanso", "units.$unit.castFullNotResting"),
            T("Estilo próprio do nome em OOC", "units.$unit.combatName.own"),
            R("Tamanho do nome em OOC", "units.$unit.combatName.nameSize", 8, 26, 0.5),
            Sel("Cor do nome em OOC", "units.$unit.combatName.nameColorMode", { same = "Igual ao normal", reaction = "Reação", color = "Cor fixa" }, { "same", "reaction", "color" }),
            K("Cor fixa em OOC", "units.$unit.combatName.nameColor"),
            T("Mostrar ícone Elite em OOC", "units.$unit.combatName.eliteShow"),
            T("Mostrar nível em OOC", "units.$unit.combatName.levelShow"),
        }
        return list
    end },

    { key = "name", label = "Nome", schema = function()
        local list = {
            H("Texto do Nome"),
            T("Mostrar nome", "units.$unit.name.enabled"),
            Sel("Fonte", "units.$unit.name.font", NP.FontList),
            R("Tamanho", "units.$unit.name.size", 6, 30, 0.5),
            Sel("Contorno", "units.$unit.name.outline", NP.OUTLINES, NP.OUTLINE_ORDER),
            T("Sombra", "units.$unit.name.shadow"),
            T("Letras espaçadas (Estilo Azaath)", "units.$unit.name.tracked"),
            K("Cor padrão", "units.$unit.name.color"),
            T("Cor de classe (jogadores)", "units.$unit.name.useClassColor"),
            T("Cor de reação no nome", "units.$unit.name.reactionTint"),
            T("Cor vermelha ao atacar você", "units.$unit.name.reactionColor"),
            R("Largura máxima (0 = livre)", "units.$unit.name.maxWidth", 0, 260, 2),
            T("Quebrar linha", "units.$unit.name.wrap"),
            H("Preenchimento de Vida no Nome"),
            T("Nome esvazia com a vida", "units.$unit.name.healthFill"),
            T("Seguir largura da barra", "units.$unit.name.fillFollowBar"),
            K("Cor da vida perdida", "units.$unit.name.lostColor"),
        }
        return Append(list, Anchor("units.$unit.name"))
    end },

    { key = "guild", label = "Guilda / Subtítulo", schema = function()
        local list = {
            H("Guilda / Subtítulo do NPC"),
            T("Mostrar", "units.$unit.guild.enabled"),
            Sel("Fonte", "units.$unit.guild.font", NP.FontList),
            R("Tamanho", "units.$unit.guild.size", 6, 24, 0.5),
            K("Cor", "units.$unit.guild.color"),
            T("Cor própria para sua guilda", "units.$unit.guild.myGuildColorOn"),
            K("Cor da sua guilda", "units.$unit.guild.myGuildColor"),
            T("Esconder durante conjuração", "units.$unit.guild.hideWhileCasting"),
            T("Ocultar em pets", "units.$unit.guild.hidePets"),
        }
        return Append(list, Anchor("units.$unit.guild"))
    end },

    { key = "healthText", label = "Texto de Vida", schema = function()
        local list = {
            H("Texto de Vida"),
            T("Mostrar", "units.$unit.healthText.enabled"),
            T("Mostrar porcentagem (%)", "units.$unit.healthText.showPercent"),
            T("Mostrar valor numérico", "units.$unit.healthText.showValue"),
            T("Casas decimais (%.1f%%)", "units.$unit.healthText.decimals"),
            T("Números completos (sem K/M)", "units.$unit.healthText.fullNumbers"),
            Sel("Fonte", "units.$unit.healthText.font", NP.FontList),
            R("Tamanho", "units.$unit.healthText.size", 6, 24, 0.5),
            Sel("Contorno", "units.$unit.healthText.outline", NP.OUTLINES, NP.OUTLINE_ORDER),
            K("Cor", "units.$unit.healthText.color"),
        }
        return Append(list, Anchor("units.$unit.healthText"))
    end },

    { key = "level", label = "Nível", schema = function()
        local list = {
            H("Nível"),
            T("Mostrar nível", "units.$unit.level.enabled"),
            Sel("Fonte", "units.$unit.level.font", NP.FontList),
            R("Tamanho", "units.$unit.level.size", 6, 24, 0.5),
            T("Cor fixa (ignorar dificuldade)", "units.$unit.level.plainColor"),
            K("Cor fixa", "units.$unit.level.color"),
            H("Caixa do Nível"),
            T("Mostrar caixa ao redor", "units.$unit.level.box"),
            Sel("Formato da caixa", "units.$unit.level.boxShape", NP.LEVEL_BOX_SHAPES, NP.LEVEL_BOX_SHAPE_ORDER),
            R("Largura da caixa", "units.$unit.level.boxWidth", 12, 42, 1),
            R("Altura (0 = automática)", "units.$unit.level.boxHeight", 0, 42, 1),
            Sel("Cores da caixa", "units.$unit.level.boxColors", { bar = "Igual à barra", own = "Próprias" }, { "bar", "own" }),
            K("Fundo próprio", "units.$unit.level.boxBgColor"),
            K("Borda própria", "units.$unit.level.boxBorderColor"),
            T("Borda na cor de classe", "units.$unit.level.boxClassBorder"),
            T("Fundo na cor de classe", "units.$unit.level.boxClassFill"),
        }
        return Append(list, Anchor("units.$unit.level"))
    end },

    { key = "cast", label = "Barra de Conjuração", schema = function()
        return {
            H("Barra de Conjuração"),
            T("Ativar barra de conjuração", "cast.enabled"),
            T("Ocultar em aliados", "cast.hideFriendly"),
            R("Largura", "units.$unit.castWidth", 60, 320, 1),
            R("Altura", "units.$unit.castHeight", 4, 30, 0.5),
            R("Posição X", "units.$unit.castOffsetX", -100, 100, 0.5),
            R("Posição Y", "units.$unit.castOffsetY", -100, 100, 0.5),
            Sel("Textura", "cast.texture", NP.StatusBarTextureList),
            K("Cor de fundo", "cast.bgColor"),
            R("Espessura da borda", "cast.borderSize", 0, 4, 0.5),
            K("Cor da borda", "cast.borderColor"),
            Sel("Cantos arredondados", "style.corners.cast", NP.CORNER_STYLES, NP.CORNER_ORDER),
            H("Cores da Conjuração"),
            K("Conjuração normal", "cast.colors.cast"),
            K("Canalização", "cast.colors.channel"),
            T("Cor para casts importantes", "cast.useImportantColor"),
            K("Cast importante", "cast.colors.important"),
            K("Ininterruptível", "cast.colors.nointerrupt"),
            K("Interrompido", "cast.colors.interrupted"),
            H("Brilho de Cast Importante"),
            T("Destacar casts importantes", "cast.importantDots.enabled"),
            Sel("Estilo", "cast.importantDots.style", NP.HIGHLIGHT_STYLES, NP.HIGHLIGHT_ORDER),
            K("Cor do destaque", "cast.importantDots.color"),
            R("Tamanho / espessura", "cast.importantDots.size", 0.5, 10, 0.5),
            H("Kick + Tick (Interrupt)"),
            T("Ativar Kick + Tick", "cast.kick.enabled"),
            Sel("Modo de indicação", "cast.kick.mode", { border = "Borda", bar = "Barra", both = "Ambos" }, { "border", "bar", "both" }),
            K("Cor quando pronto", "cast.kick.readyColor"),
            T("Cor quando em recarga", "cast.kick.cooldownColorEnabled"),
            K("Cor em recarga", "cast.kick.cooldownColor"),
            K("Cor ininterruptível", "cast.kick.noInterruptColor"),
            T("Mostrar marcador (tick) de retorno", "cast.kick.tick.enabled"),
            K("Cor do tick", "cast.kick.tick.color"),
            R("Largura do tick", "cast.kick.tick.width", 1, 6, 0.5),
            T("Tingir barra de vida se Kick pronto", "cast.kick.healthBar"),
            H("Ícone, Spark & Textos"),
            T("Mostrar ícone do feitiço", "cast.showIcon"),
            Sel("Lado do ícone", "cast.icon.side", { LEFT = "Esquerda", RIGHT = "Direita", INSIDE_LEFT = "Dentro (Esq.)", INSIDE_RIGHT = "Dentro (Dir.)" }, { "LEFT", "RIGHT", "INSIDE_LEFT", "INSIDE_RIGHT" }),
            R("Tamanho do ícone (0 = auto)", "cast.icon.size", 0, 40, 1),
            R("Deslocamento X do ícone", "cast.icon.offsetX", -30, 30, 0.5),
            R("Deslocamento Y do ícone", "cast.icon.offsetY", -30, 30, 0.5),
            T("Ícone altura dupla (vida + cast)", "cast.icon.tall"),
            T("Mostrar faísca (spark)", "cast.spark.enabled"),
            Sel("Estilo do spark", "cast.spark.style", NP.SPARK_STYLES, NP.SPARK_ORDER),
            R("Largura do spark", "cast.spark.width", 2, 30, 1),
            K("Cor do spark", "cast.spark.color"),
            T("Mostrar nome do feitiço", "units.$unit.castName.enabled"),
            Sel("Fonte do nome", "units.$unit.castName.font", NP.FontList),
            R("Tamanho do nome", "units.$unit.castName.size", 6, 20, 0.5),
            T("Mostrar tempo restante", "units.$unit.castTimer.enabled"),
            R("Tamanho do tempo", "units.$unit.castTimer.size", 6, 20, 0.5),
            T("Mostrar alvo da magia", "units.$unit.castTarget.enabled"),
            R("Tamanho do alvo", "units.$unit.castTarget.size", 6, 20, 0.5),
            T("Mostrar quem interrompeu", "cast.showInterrupter"),
            H("Alerta 'EM VOCÊ!'"),
            T("Ativar alerta quando conjurar em você", "units.$unit.castOnYou.enabled"),
            Sel("Texto", "units.$unit.castOnYou.text", NP.ONYOU_TEXTS, NP.ONYOU_ORDER),
            T("Pulsar texto", "units.$unit.castOnYou.pulse"),
            T("Substituir alvo do cast", "units.$unit.castOnYou.replaceTarget"),
        }
    end },

    { key = "debuffs", label = "Debuffs (Inimigos)", schema = function()
        local list = {
            H("Debuffs nos Inimigos"),
            T("Mostrar debuffs", "auras.debuffs.enabled"),
            T("Apenas os seus debuffs", "auras.debuffs.onlyMine"),
            T("Apenas debuffs importantes", "auras.debuffs.onlyImportant"),
            R("Largura do ícone", "auras.debuffs.width", 10, 44, 1),
            R("Altura do ícone", "auras.debuffs.height", 10, 44, 1),
            R("Por linha", "auras.debuffs.perRow", 1, 12, 1),
            R("Máximo", "auras.debuffs.max", 1, 20, 1),
            R("Espaçamento", "auras.debuffs.spacing", 0, 10, 0.5),
            Sel("Crescimento", "auras.debuffs.grow", { RIGHT = "Direita", LEFT = "Esquerda", CENTER = "Centro" }, { "RIGHT", "LEFT", "CENTER" }),
            Sel("Ordenação", "auras.debuffs.sort", { default = "Padrão", duration = "Tempo restante" }, { "default", "duration" }),
            T("Borda por tipo de dispel", "auras.borderByDispelType"),
            R("Espessura da borda", "auras.borderSize", 0, 4, 0.5),
            T("Mostrar varredura (swipe)", "auras.swipe"),
            T("Inverter varredura", "auras.reverseSwipe"),
            H("Timer & Acúmulos (Stacks)"),
            T("Mostrar tempo restante", "auras.timer.enabled"),
            Sel("Fonte das auras", "auras.font", NP.FontList),
            R("Tamanho do timer", "auras.timer.size", 6, 20, 0.5),
            K("Cor do timer", "auras.timer.color"),
            T("Mostrar acúmulos (stacks)", "auras.stacks.enabled"),
            R("Tamanho dos acúmulos", "auras.stacks.size", 6, 22, 0.5),
            K("Cor dos acúmulos", "auras.stacks.color"),
            H("Pandemic (Últimos 30%)"),
            T("Efeito Pandemic", "auras.debuffs.pandemic.enabled"),
            Sel("Estilo", "auras.debuffs.pandemic.style", NP.PANDEMIC_STYLES, NP.PANDEMIC_ORDER),
            K("Cor Pandemic", "auras.debuffs.pandemic.color"),
            T("Timer vermelho no Pandemic", "auras.debuffs.pandemic.colorTimer"),
            H("Debuffs em Aliados"),
            T("Mostrar debuffs em aliados", "auras.friendDebuffs.enabled"),
            T("Apenas dissipáveis", "auras.friendDebuffs.onlyDispellable"),
            R("Tamanho (Aliados)", "auras.friendDebuffs.width", 10, 36, 1),
        }
        return Append(list, Anchor("auras.debuffs"))
    end },

    { key = "buffs", label = "Buffs (Inimigos)", schema = function()
        local list = {
            H("Buffs nos Inimigos"),
            T("Mostrar buffs", "auras.buffs.enabled"),
            T("Dissipáveis (Purge)", "auras.buffs.showDispellable"),
            T("Enfurecer (Enrage)", "auras.buffs.showEnrage"),
            T("Importantes", "auras.buffs.showImportant"),
            T("Mostrar todos os buffs", "auras.buffs.showAll"),
            R("Duração máx. (0 = qualquer)", "auras.buffs.maxDuration", 0, 120, 5),
            R("Largura do ícone", "auras.buffs.width", 10, 44, 1),
            R("Altura do ícone", "auras.buffs.height", 10, 44, 1),
            R("Por linha", "auras.buffs.perRow", 1, 10, 1),
            R("Máximo", "auras.buffs.max", 1, 12, 1),
            R("Espaçamento", "auras.buffs.spacing", 0, 10, 0.5),
            Sel("Crescimento", "auras.buffs.grow", { RIGHT = "Direita", LEFT = "Esquerda", CENTER = "Centro" }, { "RIGHT", "LEFT", "CENTER" }),
            H("Destaque Purge / Enrage"),
            Sel("Estilo do destaque", "auras.buffs.highlight.style", NP.HIGHLIGHT_BUFF_STYLES, NP.HIGHLIGHT_BUFF_ORDER),
            T("Destacar Purge (Magia)", "auras.buffs.highlight.purge.enabled"),
            K("Cor Purge", "auras.buffs.highlight.purge.color"),
            T("Destacar Enrage", "auras.buffs.highlight.enrage.enabled"),
            K("Cor Enrage", "auras.buffs.highlight.enrage.color"),
            H("Buffs em Aliados"),
            T("Mostrar buffs em aliados", "auras.friendBuffs.enabled"),
            R("Largura (Aliados)", "auras.friendBuffs.width", 10, 36, 1),
            R("Máximo (Aliados)", "auras.friendBuffs.max", 1, 10, 1),
        }
        return Append(list, Anchor("auras.buffs"))
    end },

    { key = "cc", label = "Controle de Grupo (CC)", schema = function()
        local list = {
            H("Linha de CC"),
            T("Mostrar CC separado", "auras.cc.enabled"),
            R("Largura do ícone", "auras.cc.width", 12, 48, 1),
            R("Altura do ícone", "auras.cc.height", 12, 48, 1),
            R("Máximo", "auras.cc.max", 1, 8, 1),
            K("Cor da borda de CC", "auras.cc.borderColor"),
        }
        return Append(list, Anchor("auras.cc"))
    end },

    { key = "target", label = "Alvo, Aggro & Foco", schema = function()
        return {
            H("Aggro & Ameaça (Quando o mob mira você)"),
            T("Ativar alerta de Aggro / Ameaça", "colors.threat.enabled"),
            Sel("Onde exibir o Aggro", "colors.threat.showOn", NP.THREAT_SPOTS, NP.THREAT_SPOT_ORDER),
            R("Espessura da borda de Aggro", "colors.threat.borderSize", 0.5, 4, 0.5),
            Sel("Forma do halo de Aggro", "colors.threat.haloShape", { round = "Halo redondo", square = "Quadrado" }, { "round", "square" }),
            R("Tamanho do halo de Aggro", "colors.threat.haloSize", 1, 20, 0.5),
            R("Alpha do halo de Aggro", "colors.threat.haloAlpha", 0.1, 1.0, 0.05),
            K("Cor da borda/alerta de Aggro", "colors.threat.dps.aggro"),
            K("Cor puxando Aggro", "colors.threat.dps.pulling"),
            Sel("Função (Tank / DPS)", "colors.threat.role", { auto = "Automático", tank = "Tank", dps = "DPS / Curandeiro" }, { "auto", "tank", "dps" }),
            H("Alvo Selecionado"),
            R("Escala da placa do alvo", "general.targetScale", 0.8, 2.0, 0.05),
            T("Borda de alvo", "indicators.targetBorder.enabled"),
            K("Cor da borda", "indicators.targetBorder.color"),
            R("Espessura da borda", "indicators.targetBorder.size", 0, 5, 0.5),
            T("Brilho externo (Glow)", "indicators.targetGlow.glowOn"),
            Sel("Forma do brilho", "indicators.targetGlow.glowShape", { round = "Halo redondo", square = "Quadrado" }, { "round", "square" }),
            K("Cor do brilho", "indicators.targetGlow.glowColor"),
            R("Tamanho do brilho", "indicators.targetGlow.glowSize", 1, 20, 0.5),
            T("Marcadores laterais/topo", "indicators.targetGlow.marksOn"),
            Sel("Estilo dos marcadores", "indicators.targetGlow.style", function()
                local m = {}; for k, v in pairs(NP.SELECTION_MARKERS) do m[k] = v.label end; return m
            end, NP.MARKER_ORDER),
            K("Cor dos marcadores", "indicators.targetGlow.color"),
            T("Animar marcadores", "indicators.targetGlow.arrowMotion"),
            T("Overlay brilhante na barra", "indicators.targetOverlay.enabled"),
            R("Alpha do overlay", "indicators.targetOverlay.alpha", 0, 1, 0.05),
            H("Foco & Mouseover"),
            T("Borda no foco", "indicators.focusBorder.enabled"),
            K("Cor da borda do foco", "indicators.focusBorder.color"),
            T("Brilho interno no foco", "indicators.focusOverlay.enabled"),
            Sel("Estilo do brilho do foco", "indicators.focusOverlay.texture", function()
                local m = {}; for k, v in pairs(NP.FOCUS_TEXTURES) do m[k] = v.label end; return m
            end, NP.FOCUS_TEXTURE_ORDER),
            K("Cor do brilho do foco", "indicators.focusOverlay.color"),
            T("Brilho ao passar o mouse", "indicators.hover.enabled"),
            R("Alpha do hover", "indicators.hover.alpha", 0, 1, 0.05),
        }
    end },

    { key = "indicators", label = "Ícones & Indicadores", schema = function()
        return {
            H("Ícones de Missão & Utilidade"),
            T("Ícone de Quest (inimigos)", "indicators.quest.enabled"),
            T("Ícone distinto (kill/loot)", "indicators.quest.byType"),
            R("Tamanho do ícone de Quest", "indicators.quest.size", 10, 36, 1),
            T("Texto de progresso (3/8)", "indicators.questText.enabled"),
            T("Ícones de utilidade (NPCs aliados)", "units.$unit.serviceIcon.enabled"),
            R("Tamanho do ícone de utilidade", "units.$unit.serviceIcon.size", 12, 36, 1),
            H("Marcadores & Ícones"),
            T("Marcador de Raide", "units.$unit.raidMark.enabled"),
            R("Tamanho do Raid Mark", "units.$unit.raidMark.size", 10, 40, 1),
            T("Ícone de Elite / Raro", "units.$unit.eliteIcon.enabled"),
            R("Tamanho Elite", "units.$unit.eliteIcon.size", 10, 32, 1),
            T("Ícone de Classe (jogadores)", "units.$unit.classIcon.enabled"),
            R("Tamanho Classe", "units.$unit.classIcon.size", 10, 36, 1),
            T("Ícone de Facção", "units.$unit.factionIcon.enabled"),
            T("Ícone de Tipo (Boss/Caster/Elite)", "indicators.typeIcon.enabled"),
            T("Texto de Ameaça (%)", "indicators.threatText.enabled"),
            T("Alvo da Unidade (quem o mob mira)", "units.$unit.unitTarget.enabled"),
            T("Última magia (LastSpell)", "units.$unit.lastSpell.enabled"),
        }
    end },

    { key = "resources", label = "Recursos & Extras", schema = function()
        return {
            H("Recursos de Classe na Placa"),
            T("Mostrar recursos (Combo/Runas/etc.)", "classResources.enabled"),
            Sel("Estilo", "classResources.style", NP.RESOURCE_STYLES, NP.RESOURCE_STYLE_ORDER),
            R("Tamanho", "classResources.mfSize", 6, 28, 0.5),
            R("Espaçamento", "classResources.mfSpacing", 0, 10, 0.5),
            R("Posição Y", "classResources.anchor.y", -60, 60, 0.5),
            T("Só em inimigos atacáveis", "classResources.onlyAttackable"),
            T("Só em combate", "classResources.onlyInCombat"),
            H("Vida & Poder Pessoal no Alvo"),
            T("Barra de poder pessoal no alvo", "playerPower.enabled"),
            R("Altura da barra de poder", "playerPower.height", 3, 20, 0.5),
            T("Barra de vida pessoal no alvo", "playerHealth.enabled"),
            R("Altura da barra de vida", "playerHealth.height", 4, 24, 0.5),
            H("Mítica+ & Energia de Chefes"),
            T("Mostrar % Enemy Forces (M+)", "extras.mplus.enabled"),
            Sel("Formato M+", "extras.mplus.mode", { percent = "Somente %", value = "Valor bruto", both = "Ambos" }, { "percent", "value", "both" }),
            R("Casas decimais (M+)", "extras.mplus.decimals", 0, 2, 1),
            R("Tamanho da fonte (M+)", "extras.mplus.size", 7, 18, 0.5),
            K("Cor do texto (M+)", "extras.mplus.color"),
            T("Barra de Energia de Boss", "extras.bossEnergy.enabled"),
            T("Mostrar também em Minibosses", "extras.bossEnergy.miniboss"),
            R("Altura da barra de Energia", "extras.bossEnergy.height", 3, 16, 0.5),
            K("Cor da barra de Energia", "extras.bossEnergy.fillColor"),
            T("Texto de Energia", "extras.bossEnergy.text"),
            Sel("Formato do texto de Energia", "extras.bossEnergy.textFormat", { percent = "%", current = "Atual", both = "Ambos" }, { "percent", "current", "both" }),
        }
    end },
}

-- Abas Globais (Geral, Visibilidade/Alcance, Cores/Ameaça, Perfis)
S.GLOBAL_TABS = {
    { key = "general", label = "Geral & Estilo", schema = function()
        return {
            H("Sistema & Predefinições de Barra"),
            T("Ativar sistema de Nameplates", "general.enabled"),
            Sel("Estilo predefinido de barra", "style.barStyle", NP.BAR_STYLES, NP.BAR_STYLE_ORDER,
                "Aplica os visuais Moderno, Azaath Clássico, Azaath Tinta, Zerker ou Minimalista como ponto de partida."),
            T("Substituir fonte em todas as placas", "style.allFontOn"),
            Sel("Fonte global", "style.allFont", NP.FontList),
            T("Ícones de utilidade em NPCs aliados", "general.utilityNPCs"),
            T("Mostrar ícone de Soft-Target (Mira Rápida)", "general.softTarget"),
            T("Ocultar nomes 3D de aliados fora do alcance", "general.hideWorldNames"),
            T("Usar nomes de RP (Total RP 3)", "general.rpNames"),
            H("Comportamento em Combate & Aliados"),
            T("Inimigos só com nome até entrar em combate", "units.$unit.nameOnlyUntilCombat"),
            T("Mostrar barra completa se estiver conjurando", "units.$unit.castFullPlate"),
            T("Ocultar inimigos fora de combate", "general.combatOnly"),
            T("Ocultar unidades mortas", "general.hideDead"),
            T("Aliados viram barra ao selecionar", "general.friendlyFullOnTarget"),
            T("Aliados viram barra quando feridos", "general.friendlyFullWhenHurt"),
            T("Aliados viram barra em combate", "general.friendlyFullInCombat"),
            T("Aliados viram barra no grupo/raide", "general.friendlyFullGroup"),
            T("Mostrar apenas jogadores aliados do grupo", "general.friendlyOnlyGroup"),
            T("Mostrar aliados apenas se estiverem feridos", "general.friendlyOnlyHurt"),
            T("Ocultar NPCs aliados comuns (só importantes/quest)", "general.friendlyNpcImportant"),
            T("Ocultar pets de aliados", "general.friendlyNpcHidePets"),
        }
    end },

    { key = "visibility", label = "Alpha, Alcance & CVars", schema = function()
        return {
            H("Transparência (Alpha)"),
            T("Esmaecer placas que não são o alvo", "general.nonTargetAlphaEnabled"),
            R("Alpha das não-alvo", "general.nonTargetAlpha", 0.05, 1, 0.05),
            R("Alpha do alvo", "general.targetAlpha", 0.1, 1, 0.05),
            R("Alpha quando sem alvo", "general.noTargetAlpha", 0.1, 1, 0.05),
            R("Alpha de aliados não-alvo", "general.friendlyNonTargetAlpha", 0.05, 1, 0.05),
            T("Esmaecer apenas em instâncias", "general.fadeInstancesOnly"),
            T("Alpha 100% ao passar o mouse", "general.mouseoverFullAlpha"),
            T("Destacar placas que estão conjurando", "extras.castHighlight.enabled"),
            T("Apenas conjurações importantes", "extras.castHighlight.importantOnly"),
            T("Esmaecer atrás de paredes", "general.fadeOccluded"),
            R("Alpha atrás de paredes", "general.occludedAlpha", 0, 1, 0.05),
            H("Alcance & Escala por Distância"),
            T("Esmaecer inimigos fora de alcance", "general.rangeFade.enabled"),
            R("Alpha fora de alcance", "general.rangeFade.alpha", 0.05, 1, 0.05),
            T("Aplicar também no alvo", "general.rangeFade.target"),
            T("Reduzir escala conforme a distância", "general.distanceScale.enabled"),
            R("Escala mínima à distância", "general.distanceScale.min", 0.4, 1.0, 0.05),
            R("Distância máxima (jardas)", "general.distanceScale.fullDist", 5, 40, 1),
            H("Escala, Clique & Empilhamento"),
            R("Escala global das placas", "general.globalScale", 0.5, 2.0, 0.05),
            T("Placas menores para lacaios/triviais", "general.smallPlates.enabled"),
            R("Escala de placas menores", "general.smallPlates.scale", 0.3, 1.0, 0.05),
            R("Largura clicável (Inimigos)", "general.clickWidth", 60, 300, 1),
            R("Altura clicável (Inimigos)", "general.clickHeight", 10, 80, 1),
            R("Largura clicável (Aliados)", "general.friendlyClickWidth", 40, 260, 1),
            R("Altura clicável (Aliados)", "general.friendlyClickHeight", 10, 80, 1),
            T("Empilhar placas (não sobrepor)", "general.stackEnemies"),
            T("Caixa de empilhamento automática", "general.stackAuto"),
            R("Escala horiz. empilhamento", "general.stackWidthScale", 0.4, 1.5, 0.05),
            R("Escala vert. empilhamento", "general.stackHeightScale", 0.5, 2.0, 0.05),
            R("Espaçamento horizontal", "general.overlapH", 0.4, 2.5, 0.05),
            R("Espaçamento vertical", "general.overlapV", 0.4, 2.5, 0.05),
            R("Distância máxima das placas", "general.viewDistance", 20, 100, 5),
            T("Mostrar caixas de clique/empilhamento (Debug)", "general.debugBoxes"),
        }
    end },

    { key = "colors", label = "Cores & Ameaça", schema = function()
        return {
            H("Reação & Missões"),
            K("Hostil", "colors.reaction.hostile"),
            K("Neutro", "colors.reaction.neutral"),
            K("Aliado", "colors.reaction.friendly"),
            K("Mob já marcado por outro (Tapped)", "colors.tapped"),
            T("Colorir mobs de missão", "colors.quest.enabled"),
            K("Quest (Hostil)", "colors.quest.hostile"),
            K("Quest (Neutro)", "colors.quest.neutral"),
            H("Ameaça / Threat (Tank & DPS)"),
            T("Ativar cores de ameaça", "colors.threat.enabled"),
            Sel("Função", "colors.threat.role", { auto = "Automático", tank = "Tank", dps = "DPS / Curandeiro" }, { "auto", "tank", "dps" }),
            Sel("Onde exibir", "colors.threat.showOn", NP.THREAT_SPOTS, NP.THREAT_SPOT_ORDER),
            K("DPS: Com aggro (Perigo)", "colors.threat.dps.aggro"),
            K("DPS: Puxando aggro", "colors.threat.dps.pulling"),
            K("Tank: Sem aggro", "colors.threat.tank.noaggro"),
            K("Tank: Perdendo aggro", "colors.threat.tank.pulling"),
            K("Tank: Outro tank segurando", "colors.threat.tank.anothertank"),
            H("Conjuradores & Tipos de Masmorra"),
            T("Cor própria para conjuradores (Caster)", "colors.caster.enabled"),
            K("Cor de Caster", "colors.caster.color"),
            T("Apenas em instâncias", "colors.caster.instancesOnly"),
            T("Cores por tipo em instâncias", "colors.unitType.enabled"),
            K("Chefe (Boss)", "colors.unitType.boss"),
            K("Mini-chefe (Miniboss)", "colors.unitType.miniboss"),
            K("Elite", "colors.unitType.elite"),
            K("Trivial / Lacaio", "colors.unitType.trivial"),
            H("Mundo Aberto & Ociosos"),
            T("Cores especiais no mundo aberto", "colors.world.enabled"),
            T("Raro", "colors.world.rare.enabled"),
            K("Cor de Raro", "colors.world.rare.color"),
            T("Raro Elite", "colors.world.rareElite.enabled"),
            K("Cor de Raro Elite", "colors.world.rareElite.color"),
            T("Chefe de Mundo", "colors.world.worldBoss.enabled"),
            K("Cor de Chefe de Mundo", "colors.world.worldBoss.color"),
            T("Esmaecer mobs fora de combate (Idle)", "colors.idle.enabled"),
            R("Força do esmaecimento", "colors.idle.strength", 0.1, 1.0, 0.05),
        }
    end },
}
