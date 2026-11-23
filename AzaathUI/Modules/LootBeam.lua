--[[----------------------------------------------------------------------------
    AzaathUI - Modules/LootBeam.lua
    Facho de Luz e Coluna de Saque sobre Corpos de Inimigos no Estilo Azaath:
      * Ao haver saque em corpos de inimigos no campo de visão, surge
        automaticamente uma coluna de luz vertical com halo e anel no solo,
        sem necessidade de passar o mouse ou selecionar o corpo.
      * Aparece quando o corpo está dentro do campo de visão do jogador (mesmo sem
        estar de frente pro alvo). Se o jogador virar totalmente de costas para o
        corpo (fora do campo de visão / atrás da câmera), o facho oculta
        imediatamente, sem deixar resíduos ou pings congelados na tela.
      * O efeito é posicionado no chão diretamente sobre o corpo: a placa do corpo
        fica na altura da cabeça do mob vivo, então o facho desce pela altura do
        mob projetada em perspectiva (distância estimada por itens de alcance).
      * LIMITE DO JOGO: corpos mortos perdem a placa de nome; só o corpo sob a
        interação suave (retícula), o alvo e o mouseover ganham placa. Para
        mostrar vários corpos, o facho de um corpo que perdeu a placa fica
        "na memória" na última posição (compensando o giro da câmera) até você
        andar ou girar demais.
      * Ignora completamente jogadores, aliados, o próprio personagem, inimigos vivos
        e objetos do cenário (minérios, plantas, etc.), atuando EXCLUSIVAMENTE sobre
        corpos de monstros/criaturas mortas que possuam drop.
      * No momento em que o corpo é aberto ou saqueado (mesmo com saque automático),
        o facho irrompe em uma explosão de luz na cor exata da MAIOR raridade
        que dropou do mob:
          - Incomum   (Verde)   -> Facho Verde Esmeralda vibrante (#1ee661)
          - Raro      (Azul)    -> Facho Azul Celeste brilhante   (#00b0ff)
          - Épico     (Roxo)    -> Facho Roxo Arcano / Violeta    (#b545ff)
          - Lendário  (Laranja) -> Facho Laranja / Ouro Solar     (#ff8800)
          - Comum     (Branco)  -> Facho Branco / Prata suave     (#e6e6f0)
          - Missão    (Amarelo) -> Facho Dourado de Missão        (#ffd700)
      * Se sobrarem itens no corpo (inventário cheio ou saque manual), o corpo
        continua emitindo o facho permanente na cor daquela raridade máxima.
      * Suporta múltiplos corpos no chão simultaneamente através de um pool de fachos.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("LootBeam")

local _G = _G
local pairs, ipairs, pcall, type, tonumber = pairs, ipairs, pcall, type, tonumber
local sin, cos, min, max, pi = math.sin, math.cos, math.min, math.max, math.pi
local GetTime = GetTime
local API = Azaath.API

--------------------------------------------------------------------------------
-- Paleta de Raridades do Azaath
--------------------------------------------------------------------------------
local RARITY_COLORS = {
    [0] = { 0.65, 0.65, 0.68 }, -- Pobre / Cinza
    [1] = { 0.92, 0.92, 0.96 }, -- Comum / Branco
    [2] = { 0.12, 0.90, 0.38 }, -- Incomum / Verde Azaath
    [3] = { 0.00, 0.69, 1.00 }, -- Raro / Azul Azaath
    [4] = { 0.71, 0.27, 1.00 }, -- Épico / Roxo Azaath
    [5] = { 1.00, 0.53, 0.00 }, -- Lendário / Laranja Azaath
    [6] = { 0.90, 0.80, 0.50 }, -- Artefato
    [7] = { 0.00, 0.85, 0.90 }, -- Herança
}

-- Cores especiais
local COLOR_DEFAULT = { 0.92, 0.78, 0.38 } -- Dourado/Âmbar suave (corpo ainda fechado)
local COLOR_QUEST   = { 1.00, 0.86, 0.12 } -- Amarelo intenso de missão


--------------------------------------------------------------------------------
-- Estado do Módulo
--------------------------------------------------------------------------------
local beamPool      = {} -- Fachos livres prontos para reutilização
local activeBeams   = {} -- [plate] = beamFrame
local probe         = nil -- Textura oculta para ler o cursor da unidade
local lootedCorpses = {} -- [corpseGUID] = { quality = q, empty = boolean, at = time }
local lootSession   = nil -- { guids = {[guid]=true}, remaining = itens ainda no corpo }
local KillBeam           -- definido mais abaixo (usado no OnUpdate)
local DYING_TIME    = 0.8 -- corpo esvaziado: o facho apaga em ~0,8 s (mostra a cor e some)

local testMode      = false
local testEnd       = 0
local testStep      = 0
local testBeam      = nil

local function SafeCall(fn, ...)
    if not fn then return nil end
    local ok, res = pcall(fn, ...)
    if ok and not Azaath.IsSecret(res) then return res end
    return nil
end

-- Cache de FileIDs conhecidos de cursores de saque
local CURSOR_FILE_IDS = {}
local function BuildCursorCache()
    if not GetFileIDFromPath then return end
    local list = {
        { "LootAll", "loot" },
        { "Pickup", "loot" },
        { "PickLock", "loot" },
        { "Quest", "quest" },
        { "QuestTurnIn", "quest" },
        { "QuestInteract", "quest" },
        { "Important", "quest" },
        { "ImportantTurnIn", "quest" },
        { "Recurring", "quest" },
        { "CampaignQuest", "quest" },
    }
    for _, item in ipairs(list) do
        for _, prefix in ipairs({ "", "Unable" }) do
            local p = "Interface\\Cursor\\" .. prefix .. item[1]
            local id = SafeCall(GetFileIDFromPath, p) or SafeCall(GetFileIDFromPath, p .. ".blp")
            if id then CURSOR_FILE_IDS[id] = item[2] end
        end
    end
end

local function DB()
    local db = Azaath.db and Azaath.db.lootBeam
    if not db then
        db = {
            enabled        = true,
            showOnUnopened = true,
            rarityBurst    = true,
            persistRarity  = true,
            beamHeight     = 130, -- Tamanho menor equilibrado
            beamWidth      = 38,  -- Largura compacta e viva
            offsetY        = 0,   -- Posicionado no centro do corpo do mob no solo
            duration       = 2.6,
        }
    end
    -- Corrige offsets legados (como -110 ou -55 que afundavam o facho dependendo do angulo de camera)
    if db.offsetY == nil or db.offsetY < -40 or db.offsetY > 30 then
        db.offsetY = 0
    end
    -- Migra se estiver com os valores de espeto fino
    if db.beamHeight == nil or db.beamHeight < 110 or db.beamHeight > 180 then
        db.beamHeight = 130
    end
    if db.beamWidth == nil or db.beamWidth < 30 or db.beamWidth > 55 then
        db.beamWidth = 38
    end
    if db.groundFactor == nil or db.groundFactor < 30 or db.groundFactor > 250 then
        db.groundFactor = 100
    end
    return db
end

--------------------------------------------------------------------------------
-- Utilitários de Cursor e Detecção de Saque
--------------------------------------------------------------------------------
local function CreateProbe()
    if probe then return end
    probe = UIParent:CreateTexture(nil, "BACKGROUND")
    probe:Hide()
end

local function IsBehindCamera(unit)
    if not unit then return false end
    if _G.C_NamePlateManager and C_NamePlateManager.IsNamePlateUnitBehindCamera then
        local ok, behind = pcall(C_NamePlateManager.IsNamePlateUnitBehindCamera, unit)
        if ok and not Azaath.IsSecret(behind) and behind == true then
            return true
        end
    end
    return false
end

-- Verifica com altíssimo rigor se a unidade é estritamente um corpo de MOB com saque
local function CheckUnitLoot(unit)
    if not unit or not UnitExists(unit) then return false, false end

    -- 1. NUNCA o jogador, NUNCA aliados, NUNCA lacaios/pets de jogadores
    if UnitIsUnit and UnitIsUnit(unit, "player") then return false, false end
    if UnitPlayerControlled and UnitPlayerControlled(unit) then return false, false end
    local okP, isP = pcall(UnitIsPlayer, unit)
    if okP and not Azaath.IsSecret(isP) and isP == true then return false, false end

    -- 2. NUNCA objetos do cenário (minérios, ervas, baús, portas)
    if UnitIsGameObject and UnitIsGameObject(unit) then return false, false end

    -- 3. Validação rigorosa por GUID: OBRIGATORIAMENTE Criatura/Veículo
    --    Em masmorras o GUID de mobs vem SECRETO: aí não dá para checar o tipo
    --    nem a memória de corpos, e seguimos só com as checagens abaixo
    --    (morto, não jogador, não aliado, não tap-denied).
    local guid = SafeCall(UnitGUID, unit)
    if guid ~= nil and type(guid) ~= "string" then guid = nil end
    if guid and not (guid:find("^Creature%-") or guid:find("^Vehicle%-")) then
        return false, false
    end

    -- 4. Se o corpo já foi totalmente esvaziado pelo jogador
    if guid and lootedCorpses[guid] and lootedCorpses[guid].empty then
        return false, false
    end

    -- 5. DEVE ESTAR CONFIRMADO COMO MORTO (Inimigos vivos NUNCA entram aqui)
    local isDead = false
    local okDead, d = pcall(UnitIsDead, unit)
    if okDead and not Azaath.IsSecret(d) and d == true then
        isDead = true
    end
    if not isDead then
        local okC, c = pcall(UnitIsCorpse, unit)
        if okC and not Azaath.IsSecret(c) and c == true then
            isDead = true
        end
    end
    if not isDead then
        local okDG, dg = pcall(UnitIsDeadOrGhost, unit)
        if okDG and not Azaath.IsSecret(dg) and dg == true then
            isDead = true
        end
    end
    if not isDead then
        local okH, hp = pcall(UnitHealth, unit)
        if okH and not Azaath.IsSecret(hp) and type(hp) == "number" and hp == 0 then
            isDead = true
        end
    end

    if not isDead then
        return false, false
    end

    -- 6. Checagem por reação: NUNCA aliados ou NPCs amigáveis mortos
    if UnitReaction then
        local okR, reaction = pcall(UnitReaction, "player", unit)
        if okR and type(reaction) == "number" and not Azaath.IsSecret(reaction) then
            if reaction >= 5 then
                return false, false
            end
        end
    end

    -- 7. Checagem por bloqueio de tap (se outro jogador atacou primeiro e o mob ficou cinza)
    if UnitIsTapDenied then
        local okTap, tap = pcall(UnitIsTapDenied, unit)
        if okTap and not Azaath.IsSecret(tap) and tap == true then
            return false, false
        end
    end

    -- 8. Se já tivermos registro prévio deste corpo saqueado com sobra de loot
    if guid and lootedCorpses[guid] and not lootedCorpses[guid].empty then
        return true, false
    end

    -- 9. Detecção de saque e tipo de cursor (quest vs normal)
    local isQuest = false
    local isLoot = false

    -- Probe de textura de cursor (funciona em softinteract, mouseover, target)
    CreateProbe()
    local okProbe = SafeCall(SetUnitCursorTexture, probe, unit, nil, true)
    if okProbe then
        local tex = probe:GetTexture()
        local atlas = probe.GetAtlas and probe:GetAtlas()
        if Azaath.IsSecret(tex) then tex = nil end
        if Azaath.IsSecret(atlas) then atlas = nil end

        if type(tex) == "number" and CURSOR_FILE_IDS[tex] then
            isLoot = true
            if CURSOR_FILE_IDS[tex] == "quest" then isQuest = true end
        end

        local s = (type(tex) == "string" and tex:lower()) or (type(atlas) == "string" and atlas:lower()) or ""
        if s ~= "" then
            isQuest = s:find("quest", 1, true) ~= nil or s:find("important", 1, true) ~= nil
            isLoot = isQuest or s:find("loot", 1, true) ~= nil or s:find("pickup", 1, true) ~= nil or s:find("picklock", 1, true) ~= nil
        end
    end

    -- Para softinteract: se o cursor não foi pego mas softinteract selecionou o corpo morto, saque garantido
    if not isLoot and unit == "softinteract" then
        isLoot = true
    end

    -- Para todas as demais nameplates de corpos mortos visíveis no campo de visão:
    -- Qualquer criatura inimiga/neutra morta, não tap-denied e não esvaziada tem saque disponível!
    if not isLoot then
        isLoot = true
    end

    return isLoot, isQuest
end

function M:WantsUnit(unit)
    local db = DB()
    if not db.enabled or not db.showOnUnopened then return false end
    local isLoot = CheckUnitLoot(unit)
    return isLoot == true
end

-- Obtém a Nameplate para a unidade (com busca reversa robusta para softinteract)
local function GetUnitNamePlate(unit)
    if not unit then return nil end
    if _G.C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok and plate then return plate end
    end
    -- Fallback: busca reversa nas Nameplates ativas se o token direto não retornar
    if _G.C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local u = plate.namePlateUnitToken
            if u and UnitExists(u) and UnitIsUnit(u, unit) then
                return plate
            end
        end
    end
    return nil
end

--------------------------------------------------------------------------------
-- Posição no solo (rente ao corpo)
-- A placa de um corpo fica na altura da CABEÇA do mob vivo, não no chão. Não há
-- API de posição 3D, então estimamos a distância até o corpo (itens de alcance,
-- só fora de combate) e descemos o facho pela altura do mob projetada em
-- perspectiva: quanto mais longe, menor a distância em pixels entre cabeça e pé.
--------------------------------------------------------------------------------
local FOCAL_UI  = 680   -- distância focal aproximada em unidades do UIParent (FOV padrão)
local REF_DEPTH = 14    -- profundidade em que o facho tem escala 1
-- Em combate o jogo proíbe medir a distância de inimigos. Um mob que acabou de
-- morrer quase sempre está colado no jogador, então esse é o melhor chute.
local DIST_UNKNOWN = 6

-- { alcance máximo em jardas, itemID } (mesma tabela usada pelo LibRangeCheck)
local RANGE_ITEMS = {
    { 5, 37727 }, { 8, 34368 }, { 10, 32321 }, { 15, 1251 }, { 20, 21519 },
    { 25, 31463 }, { 30, 34191 }, { 35, 18904 }, { 40, 28767 },
}
local distCache = {} -- [guid] = jardas

local function RequestRangeItems()
    if _G.C_Item and C_Item.RequestLoadItemDataByID then
        for _, e in ipairs(RANGE_ITEMS) do pcall(C_Item.RequestLoadItemDataByID, e[2]) end
    end
end

local function IsTrue(ok, v)
    return ok and not Azaath.IsSecret(v) and v == true
end

-- Distância estimada (jardas). Em combate as checagens de alcance são proibidas
-- para inimigos, então usa a última leitura guardada do corpo.
local function EstimateDistance(unit, guid)
    if not unit then return nil end
    if InCombatLockdown and InCombatLockdown() then
        return guid and distCache[guid]
    end
    local d
    local isDead = IsTrue(pcall(UnitIsDead, unit)) or IsTrue(pcall(UnitIsCorpse, unit))
    local IsInRange = (_G.C_Item and C_Item.IsItemInRange) or _G.IsItemInRange
    if IsInRange and not isDead then
        local prev, anyAnswer = 0, false
        for _, e in ipairs(RANGE_ITEMS) do
            local ok, r = pcall(IsInRange, e[2], unit)
            if ok and not Azaath.IsSecret(r) and r ~= nil then
                anyAnswer = true
                if r == true then
                    d = (prev + e[1]) * 0.5
                    break
                end
            end
            prev = e[1]
        end
        if not d and anyAnswer then d = 45 end
    end
    if not d and _G.UnitIsInInteractRange and IsTrue(pcall(UnitIsInInteractRange, unit)) then
        d = 6
    end
    if not d and _G.CheckInteractDistance then
        if IsTrue(pcall(CheckInteractDistance, unit, 3)) then
            d = 7
        elseif IsTrue(pcall(CheckInteractDistance, unit, 4)) then
            d = 18
        else
            d = (guid and distCache[guid]) or 30
        end
    end
    if d and guid then distCache[guid] = d end
    return d
end

local function CameraZoom()
    local z = _G.GetCameraZoom and SafeCall(GetCameraZoom)
    if type(z) ~= "number" then z = 10 end
    return z
end

--------------------------------------------------------------------------------
-- Fachos "memória" (vários corpos ao mesmo tempo)
-- O jogo só dá placa ao corpo da retícula. Quando a retícula passa para outro
-- corpo, a placa antiga some mas a moldura oculta guarda a última posição; o
-- facho continua preso nela (é o que a versão antiga fazia sem querer). Para não
-- ficar "congelado" errado, ele é deslocado conforme você gira e some se você
-- andar ou girar demais.
--------------------------------------------------------------------------------
local ghosts        = {} -- [guid] = beam
-- Limites para manter os fachos-memória em múltiplos corpos no campo de visão
local GHOST_MAX_YAW  = 0.55 -- rad (~31 graus) de giro do personagem
local GHOST_MAX_MOVE = 5.0  -- jardas andadas antes de apagar
local GHOST_MAX_ZOOM = 2.0  -- mudança de zoom da câmera
local GHOST_MAX_CAM  = 80   -- movimento do mouse girando só a câmera
local GHOST_MAX_AGE  = 120  -- segundos
local GHOST_NOYAW    = 8    -- segundos de vida se o jogo não informar a direção

local function PlayerFacing()
    local f = _G.GetPlayerFacing and SafeCall(GetPlayerFacing)
    if type(f) == "number" then return f end
    return nil
end

local function PlayerPos()
    if not _G.UnitPosition then return nil end
    local ok, y, x = pcall(UnitPosition, "player")
    if ok and type(y) == "number" and type(x) == "number"
        and not Azaath.IsSecret(y) and not Azaath.IsSecret(x) then
        return x, y
    end
    return nil
end


local function CachePlatePosition(beam, plate)
    if not plate then return end
    local okC, cx = pcall(plate.GetCenter, plate)
    local okB, bot = pcall(plate.GetBottom, plate)
    local okS, ps = pcall(plate.GetEffectiveScale, plate)
    local okU, us = pcall(UIParent.GetEffectiveScale, UIParent)
    if okC and okB and okS and okU and type(cx) == "number" and type(bot) == "number"
        and type(ps) == "number" and type(us) == "number" and us > 0
        and not Azaath.IsSecret(cx) and not Azaath.IsSecret(bot)
        and not Azaath.IsSecret(ps) and not Azaath.IsSecret(us) then
        local r = ps / us
        beam.cachedX = cx * r
        beam.cachedY = bot * r
    end
end

-- Liga o facho à placa; a posição real é recalculada a cada quadro no OnUpdate
local function PlaceBeam(beam, plate, unit)
    -- Pai = UIParent (só a âncora é a placa): quando o jogo esconde a placa o
    -- facho não some junto, então não pisca na troca para facho-memória.
    beam.plate = plate
    beam.lastSeen = GetTime()
    beam.unitToken = unit or beam.unitToken
    local guid = beam.unitToken and SafeCall(UnitGUID, beam.unitToken)
    beam.guid = guid
    CachePlatePosition(beam, plate)
    local d = EstimateDistance(beam.unitToken, guid)
    if d then
        -- Primeira medida real (ex.: fim do combate): encaixa direto, sem escorregar
        if not beam.distKnown then
            beam.distCur = d
            beam.distKnown = true
        end
        beam.distTarget = d
    end
    if not beam.distCur then beam.distCur = beam.distTarget or DIST_UNKNOWN end
    if not beam:IsShown() then beam.distCur = beam.distTarget or beam.distCur end
end

local function ReleaseGhost(beam)
    if beam.guid and ghosts[beam.guid] == beam then ghosts[beam.guid] = nil end
    beam.isGhost = false
    beam.burstActive = false
    beam.dying = nil
    beam:Hide()
    beam:ClearAllPoints()
    beam:SetParent(UIParent)
    beam.plate, beam.unitToken, beam.guid = nil, nil, nil
    beam.anchoredTo, beam.lastOY, beam.lastDX, beam.lastScale = nil, nil, nil, nil
    beam.cachedX, beam.cachedY = nil, nil
    beam.distCur, beam.distTarget, beam.distKnown = nil, nil, nil
    beamPool[#beamPool + 1] = beam
end

-- A placa saiu do corpo: o facho fica preso à moldura oculta, na última posição
local function MakeGhost(beam)
    local old = beam.guid and ghosts[beam.guid]
    if old and old ~= beam then ReleaseGhost(old) end
    beam.isGhost     = true
    beam.ghostStart  = GetTime()
    beam.ghostFacing = PlayerFacing()
    beam.ghostX, beam.ghostY = PlayerPos()
    beam.ghostZoom = CameraZoom()
    beam.ghostCam = 0
    beam.ghostLastFacing = beam.ghostFacing
    beam:SetParent(UIParent)
    beam:SetFrameStrata("HIGH")
    beam.lastScale, beam.lastOY = nil, nil
    if beam.guid then ghosts[beam.guid] = beam end
end

-- Ainda dá para confiar na posição guardada? Devolve o deslocamento lateral (UI)
local function GhostOffset(beam)
    local now = GetTime()
    local age = now - (beam.ghostStart or now)
    if age > GHOST_MAX_AGE then return nil end
    local dx = 0
    local f = PlayerFacing()
    if f and beam.ghostFacing then
        local d = (f - beam.ghostFacing + pi) % (2 * pi) - pi
        if math.abs(d) > GHOST_MAX_YAW then return nil end
        -- girar para a esquerda (direção aumenta) empurra o mundo para a direita
        local dist = beam.distCur or 15
        dx = FOCAL_UI * dist * sin(d) / max(1, dist * cos(d) + CameraZoom())
    elseif age > GHOST_NOYAW then
        return nil
    end
    if beam.ghostX then
        local x, y = PlayerPos()
        if x and ((x - beam.ghostX) ^ 2 + (y - beam.ghostY) ^ 2) > GHOST_MAX_MOVE ^ 2 then
            return nil
        end
    end
    -- Zoom mudou: a perspectiva toda muda
    if beam.ghostZoom and math.abs(CameraZoom() - beam.ghostZoom) > GHOST_MAX_ZOOM then
        return nil
    end
    -- Câmera girando sem o personagem (arrastar o mouse) ou subindo/descendo:
    -- o jogo não informa a direção da câmera, então soma o movimento do mouse
    local looking = (_G.IsMouselooking and IsMouselooking())
        or (_G.IsMouseButtonDown and (IsMouseButtonDown("LeftButton") or IsMouseButtonDown("RightButton")))
    if looking and _G.GetCursorDelta then
        local ok, mx, my = pcall(GetCursorDelta)
        if ok and type(mx) == "number" and type(my) == "number"
            and not Azaath.IsSecret(mx) and not Azaath.IsSecret(my) then
            local turned = f and beam.ghostLastFacing and math.abs(f - beam.ghostLastFacing) > 0.0005
            local cam = math.abs(my) + (turned and 0 or math.abs(mx))
            beam.ghostCam = (beam.ghostCam or 0) + cam
            if beam.ghostCam > GHOST_MAX_CAM then return nil end
        end
    end
    beam.ghostLastFacing = f
    return dx
end

--------------------------------------------------------------------------------
-- Construção do Facho de Luz (Animação Beam do Olho de Azaath com Cor por Raridade)
--------------------------------------------------------------------------------
local OLHO_MEDIA = "Interface\\AddOns\\AzaathUI\\Media\\OlhoAzaath\\"
local APPEAR_TIME = 0.28
local FLASH_TIME  = 0.45
local TWO_PI      = 2 * pi

local function Lerp(a, b, t)
    return a + (b - a) * t
end

local function Tint(texture, r, g, b, a)
    texture:SetVertexColor(r, g, b, a <= 0 and 0 or a >= 1 and 1 or a)
end

local function CreateOlhoLayer(parent, file, drawLayer, subLevel, blendMode)
    local texture = parent:CreateTexture(nil, drawLayer, nil, subLevel)
    texture:SetTexture(OLHO_MEDIA .. file .. ".tga")
    texture:SetBlendMode(blendMode or "ADD")
    texture:SetPoint("CENTER")
    texture:SetVertexColor(1, 1, 1, 0)
    if texture.SetSnapToPixelGrid then texture:SetSnapToPixelGrid(false) end
    if texture.SetTexelSnappingBias then texture:SetTexelSnappingBias(0) end
    return texture
end

local function StartWave(beam, from, to, duration, peak, inward)
    local fx = beam.fx
    if not fx or not fx.waves then return end
    local chosen
    for _, wave in ipairs(fx.waves) do
        if not wave.age then chosen = wave break end
        if not chosen or wave.age > chosen.age then chosen = wave end
    end
    if not chosen then return end
    chosen.age, chosen.from, chosen.to = 0, from, to
    chosen.duration, chosen.peak, chosen.inward = duration, peak, inward
end

local function ResetBeamAnim(beam)
    beam.appear   = 0
    beam.flash    = 0.65
    beam.ready    = 0
    beam.nextPing = 0.8
    beam.phase    = 0
    beam.spin     = math.random() * TWO_PI
    if beam.fx and beam.fx.waves then
        for _, wave in ipairs(beam.fx.waves) do
            wave.age = nil
            Tint(wave.texture, 1, 1, 1, 0)
        end
    end
    StartWave(beam, 0.50, 1.50, 0.9, 0.8)
end

local function BeamSize(db)
    return (db.beamHeight or 130) / 1.75
end

local function GetSoftTargetAnchor(plate)
    if not plate then return nil end
    local ok, anchor = pcall(function()
        local uf = plate.UnitFrame
        local stf = uf and uf.SoftTargetFrame
        if stf and stf.IsShown and stf:IsShown() then
            local icon = stf.Icon
            if icon and icon.IsShown and icon:IsShown() then
                return icon
            end
            return stf
        end
        return nil
    end)
    if ok and anchor then return anchor end
    return nil
end

local function CreateBeamWidget()
    local f = CreateFrame("Frame", nil, UIParent)
    f:SetFrameStrata("HIGH")
    f:SetFrameLevel(4)
    f:SetSize(1, 1)
    f:Hide()

    local EFFECTS = Azaath.OlhoNS and Azaath.OlhoNS.EFFECTS
    local beamEffect = EFFECTS and (EFFECTS.aura or EFFECTS.subtle or EFFECTS.sparkle)
    local fx = { waves = {} }
    local function Layer(...)
        return CreateOlhoLayer(f, ...)
    end
    if beamEffect then
        beamEffect.Build(fx, Layer)
        if beamEffect.wave then
            for i = 1, 2 do
                fx.waves[i] = { texture = Layer(beamEffect.wave, "BORDER") }
            end
        end
    end
    f.fx = fx
    f.beamEffect = beamEffect
    f.context = {}

    f.curR, f.curG, f.curB = COLOR_DEFAULT[1], COLOR_DEFAULT[2], COLOR_DEFAULT[3]
    f.targetR, f.targetG, f.targetB = f.curR, f.curG, f.curB
    f.appear      = 0
    f.ready       = 0
    f.flash       = 0
    f.phase       = 0
    f.spin        = math.random() * TWO_PI
    f.nextPing    = 0.8
    f.burstActive = false
    f.burstEnd    = 0
    f.burstDur    = 2.6

    ----------------------------------------------------------------------------
    -- Animação em Tempo Real (Aura/Anel no ícone (F) + Explosão por Raridade)
    ----------------------------------------------------------------------------
    f:SetScript("OnUpdate", function(self, elapsed)
        local db = DB()
        local size = BeamSize(db)

        if not self.isTest then
            local p = self.plate
            if not p then
                self:Hide()
                return
            end

            if not self.isGhost and p.IsShown and not p:IsShown() then
                if self.dying then
                    if activeBeams[p] == self then activeBeams[p] = nil end
                    MakeGhost(self)
                else
                    self:Hide()
                    return
                end
            end

            local gdx = 0
            if self.isGhost then
                gdx = GhostOffset(self)
                if not gdx then
                    ReleaseGhost(self)
                    return
                end
            elseif self.unitToken and IsBehindCamera(self.unitToken) then
                self:Hide()
                return
            end

            local stAnchor = (not self.isGhost) and GetSoftTargetAnchor(p) or nil
            local targetFrame = stAnchor or p
            local sc
            if stAnchor then
                sc = 1.0
                size = 76
            else
                local dtDist = self.distTarget or self.distCur or DIST_UNKNOWN
                self.distCur = (self.distCur or dtDist) + (dtDist - (self.distCur or dtDist)) * min(1, elapsed * 4)
                local depth = max(3, self.distCur + CameraZoom() * 0.8)
                sc = min(1.3, max(0.55, REF_DEPTH / depth))
            end
            if not self.lastScale or math.abs(self.lastScale - sc) > 0.01 then
                self:SetScale(sc)
                self.lastScale = sc
            end
            local ratio = 1 / sc
            local okU, uiS = pcall(UIParent.GetEffectiveScale, UIParent)
            local okB, bS = pcall(self.GetEffectiveScale, self)
            if okU and okB and not Azaath.IsSecret(uiS) and not Azaath.IsSecret(bS)
                and type(uiS) == "number" and type(bS) == "number" and bS > 0 then
                ratio = uiS / bS
            end
            local oy = stAnchor and 0 or ((db.offsetY or 0) / sc)
            local ox = gdx * ratio
            if self.isGhost and self.cachedX and self.cachedY then
                local gx = self.cachedX * ratio + ox
                local gy = self.cachedY * ratio + oy
                if self.anchoredTo ~= UIParent or not self.lastOY or math.abs(self.lastOY - gy) > 0.5
                    or math.abs((self.lastDX or 0) - gx) > 0.5 then
                    self:ClearAllPoints()
                    self:SetPoint("CENTER", UIParent, "BOTTOMLEFT", gx, gy)
                    self.anchoredTo = UIParent
                    self.lastOY = gy
                    self.lastDX = gx
                end
            else
                if not self.isGhost then CachePlatePosition(self, targetFrame) end
                if self.anchoredTo ~= targetFrame or not self.lastOY or math.abs(self.lastOY - oy) > 0.5
                    or math.abs((self.lastDX or 0) - ox) > 0.5 then
                    self:ClearAllPoints()
                    self:SetPoint("CENTER", targetFrame, "CENTER", ox, oy)
                    self.anchoredTo = targetFrame
                    self.lastOY = oy
                    self.lastDX = ox
                end
            end
        else
            if testMode and GetTime() >= testEnd then
                M:StopTest()
                return
            end
            local step = math.floor(((self.phase or 0) * 0.45) % 5)
            if step ~= testStep then
                testStep = step
                local demoQualities = { 2, 3, 4, 5, 1 }
                local q = demoQualities[(step % #demoQualities) + 1]
                local c = RARITY_COLORS[q] or COLOR_DEFAULT
                self.targetR, self.targetG, self.targetB = c[1], c[2], c[3]
            end
        end

        local alphaMod = 1.0
        if self.burstActive then
            local remain = self.burstEnd - GetTime()
            if remain <= 0 then
                self.burstActive = false
            else
                local prog = 1 - (remain / self.burstDur)
                if prog > 0.65 then
                    alphaMod = (1 - prog) / 0.35
                else
                    alphaMod = 1.0
                end
            end
        end

        -- Corpo esvaziado: apaga suavemente e devolve o facho ao pool
        if self.dying then
            local k = (GetTime() - self.dying) / DYING_TIME
            if k >= 1 then
                KillBeam(self)
                return
            end
            alphaMod = alphaMod * (1 - k)
        end

        -- Suavização de cor por raridade (Lerp)
        local lerpSpeed = elapsed * 10
        self.curR = self.curR + (self.targetR - self.curR) * min(1, lerpSpeed)
        self.curG = self.curG + (self.targetG - self.curG) * min(1, lerpSpeed)
        self.curB = self.curB + (self.targetB - self.curB) * min(1, lerpSpeed)
        local r, g, b = self.curR, self.curG, self.curB

        if not self.beamEffect then return end

        local dt = min(elapsed, 0.1)
        self.appear = min(1, (self.appear or 0) + dt / APPEAR_TIME)

        local inRange = self.burstActive or self.isTest
        if not inRange and self.unitToken and _G.UnitIsInInteractRange then
            inRange = SafeCall(UnitIsInInteractRange, self.unitToken) == true
        end
        local targetReady = inRange and 1 or 0.45
        self.ready = Lerp(self.ready or 0, targetReady, min(1, dt / 0.18))
        self.flash = max((self.flash or 0) - dt / FLASH_TIME, 0)
        self.phase = (self.phase or 0) + dt * TWO_PI / Lerp(3.4, 1.7, self.ready)
        self.spin  = (self.spin or 0) - dt * Lerp(0.55, 1.6, self.ready)

        local c = self.context
        c.frame   = self
        c.elapsed = dt
        c.size    = size
        c.arrive  = 1 - (1 - self.appear) ^ 3
        c.alpha   = c.arrive * alphaMod
        c.ready   = self.ready
        c.locked  = 0
        c.flash   = self.flash
        c.phase   = self.phase
        c.spin    = self.spin
        c.breath  = 0.5 + 0.5 * sin(self.phase)
        c.twinkle = 0.5 + 0.5 * sin(self.phase * 2.3 + 1.3)
        c.r, c.g, c.b = r, g, b
        c.hr, c.hg, c.hb = Lerp(r, 1, 0.55), Lerp(g, 1, 0.55), Lerp(b, 1, 0.55)
        c.wr, c.wg, c.wb = Lerp(r, 1, 0.75), Lerp(g, 1, 0.75), Lerp(b, 1, 0.75)

        local fx = self.fx
        self.beamEffect.Update(fx, c)

        -- Ondas expansivas no solo (mesmo ritmo do Olho de Azaath)
        self.nextPing = (self.nextPing or 0) - dt
        if self.nextPing <= 0 then
            self.nextPing = Lerp(2.4, 3.8, self.ready)
            if not self.dying then
                StartWave(self, 0.55, 1.45, 1.0, 0.55)
            end
        end
        local base = fx.waveSize or c.size
        local flat = self.beamEffect.flat or 1
        local gain = c.alpha * (self.beamEffect.waveGain or 1)
        for _, wave in ipairs(fx.waves) do
            if wave.age then
                wave.age = wave.age + dt
                local progress = wave.age / wave.duration
                if progress >= 1 then
                    wave.age = nil
                    Tint(wave.texture, 1, 1, 1, 0)
                else
                    local fade = wave.inward
                        and (progress < 0.7 and progress / 0.7 or (1 - progress) / 0.3)
                        or ((1 - progress) ^ 1.5)
                    local width = base * Lerp(wave.from, wave.to, 1 - (1 - progress) ^ 2)
                    wave.texture:SetSize(max(width, 0.01), max(width * flat, 0.01))
                    if fx.waveY then
                        wave.texture:SetPoint("CENTER", self, "CENTER", 0, fx.waveY)
                    end
                    if fx.waveAngle then wave.texture:SetRotation(fx.waveAngle) end
                    Tint(wave.texture, c.hr, c.hg, c.hb, gain * wave.peak * fade)
                end
            end
        end
    end)

    return f
end

local function AcquireBeam(plate, guid)
    local beam = activeBeams[plate]
    if beam and guid and beam.guid and beam.guid ~= guid then
        -- A placa passou para outro corpo: a posição do corpo antigo se perdeu
        activeBeams[plate] = nil
        ReleaseGhost(beam)
        beam = nil
    end
    if not beam and guid and ghosts[guid] then
        -- O corpo voltou a ter placa: o mesmo facho continua (sem reiniciar a animação)
        beam = ghosts[guid]
        ghosts[guid] = nil
        beam.isGhost = false
        activeBeams[plate] = beam
    end
    if not beam then
        beam = table.remove(beamPool) or CreateBeamWidget()
        beam.isGhost = false
        beam.dying = nil
        ResetBeamAnim(beam)
        activeBeams[plate] = beam
    end
    beam.plate = plate
    return beam
end

local function ReleaseBeam(plate)
    local beam = activeBeams[plate]
    if beam then
        if beam.burstActive then return end
        beam:Hide()
        beam:ClearAllPoints()
        beam:SetParent(UIParent)
        beam.plate = nil
        beam.unitToken = nil
        beam.anchoredTo = nil
        beam.distCur, beam.distTarget, beam.distKnown = nil, nil, nil
        activeBeams[plate] = nil
        beamPool[#beamPool + 1] = beam
    end
end

--------------------------------------------------------------------------------
local killBurstSeen = {}

-- Avaliação e Atualização Global de Corpos no Mundo
--------------------------------------------------------------------------------
local function EvaluateWorld()
    if testMode then return end
    local db = DB()
    if not db.enabled or not db.showOnUnopened then
        for plate, beam in pairs(activeBeams) do
            if not beam.burstActive then
                beam:Hide()
                activeBeams[plate] = nil
                beamPool[#beamPool + 1] = beam
            end
        end
        for _, g in pairs(ghosts) do ReleaseGhost(g) end
        return
    end

    local seenPlates = {}
    local plateCache = M.plateCache or {}
    M.plateCache = plateCache

    -- 1. Varre TODAS as Nameplates disponíveis (via tokens nameplate1..40 e C_NamePlate)
    local function ProcessUnitPlate(u, plate)
        if not u or not plate or seenPlates[plate] then return end
        if plate.IsShown and not plate:IsShown() then return end
        if not UnitExists(u) or IsBehindCamera(u) then return end
        local uguid = SafeCall(UnitGUID, u)
        if uguid and (uguid:find("^Creature%-") or uguid:find("^Vehicle%-")) then
            local entry = plateCache[u] or {}
            entry.plate = plate
            entry.guid = uguid
            CachePlatePosition(entry, plate)
            local d = EstimateDistance(u, uguid)
            if d then entry.dist = d end
            if IsTrue(pcall(UnitIsDead, u)) or IsTrue(pcall(UnitIsCorpse, u)) or (SafeCall(UnitHealth, u) == 0) then
                entry.dead = true
            end
            plateCache[u] = entry
        end
        local isLoot, isQuest = CheckUnitLoot(u)
        if isLoot then
            seenPlates[plate] = true
            local beam = AcquireBeam(plate, uguid)
            PlaceBeam(beam, plate, u)
            if uguid and not killBurstSeen[uguid] then
                killBurstSeen[uguid] = GetTime()
                beam.flash = 1.0
                StartWave(beam, 0.40, 1.75, 0.70, 1.0)
            end
            beam:Show()

            local saved = uguid and lootedCorpses[uguid]
            if saved and saved.quality and RARITY_COLORS[saved.quality] then
                local c = RARITY_COLORS[saved.quality]
                beam.targetR, beam.targetG, beam.targetB = c[1], c[2], c[3]
            elseif isQuest then
                beam.targetR, beam.targetG, beam.targetB = COLOR_QUEST[1], COLOR_QUEST[2], COLOR_QUEST[3]
            else
                beam.targetR, beam.targetG, beam.targetB = COLOR_DEFAULT[1], COLOR_DEFAULT[2], COLOR_DEFAULT[3]
            end
        end
    end

    for i = 1, 40 do
        local u = "nameplate" .. i
        if UnitExists(u) then
            local plate = GetUnitNamePlate(u)
            if plate then ProcessUnitPlate(u, plate) end
        end
    end

    if _G.C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local u = plate.namePlateUnitToken or plate.unit or (plate.UnitFrame and plate.UnitFrame.unit)
            if u then ProcessUnitPlate(u, plate) end
        end
    end

    -- 2. Avalia unidades diretas essenciais: softinteract (retícula), target, mouseover, focus
    local directUnits = { "softinteract", "target", "mouseover", "focus" }
    for _, u in ipairs(directUnits) do
        if UnitExists(u) and not IsBehindCamera(u) then
            local isLoot, isQuest = CheckUnitLoot(u)
            if isLoot then
                local plate = GetUnitNamePlate(u)
                if plate and not seenPlates[plate] then
                    seenPlates[plate] = true
                    local beam = AcquireBeam(plate, SafeCall(UnitGUID, u))
                    PlaceBeam(beam, plate, plate.namePlateUnitToken or u)
                    beam:Show()

                    local guid = SafeCall(UnitGUID, u)
                    local saved = guid and lootedCorpses[guid]
                    if saved and saved.quality and RARITY_COLORS[saved.quality] then
                        local c = RARITY_COLORS[saved.quality]
                        beam.targetR, beam.targetG, beam.targetB = c[1], c[2], c[3]
                    elseif isQuest then
                        beam.targetR, beam.targetG, beam.targetB = COLOR_QUEST[1], COLOR_QUEST[2], COLOR_QUEST[3]
                    else
                        beam.targetR, beam.targetG, beam.targetB = COLOR_DEFAULT[1], COLOR_DEFAULT[2], COLOR_DEFAULT[3]
                    end
                end
            end
        end
    end

    -- Corpo voltou a ter placa: o facho vivo substitui o facho-memória
    for _, beam in pairs(activeBeams) do
        local g = beam.guid and ghosts[beam.guid]
        if g and g ~= beam then ReleaseGhost(g) end
    end

    -- 3. Placas que saíram: mantém uma tolerância curta (0,35s) e depois libera
    --    sem criar fantasmas 2D soltos na tela.
    for plate, beam in pairs(activeBeams) do
        if beam.dying and not beam:IsShown() then
            KillBeam(beam)
        elseif not seenPlates[plate] and not beam.dying then
            local guid = beam.guid
            local emptied = guid and lootedCorpses[guid] and lootedCorpses[guid].empty
            if not emptied and beam.lastSeen and (GetTime() - beam.lastSeen) < 0.35 then
                -- tolerância: uma checagem que falha por um instante não apaga o facho
            else
                ReleaseBeam(plate)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Extração de Raridade e Disparo de Explosão de Luz
--------------------------------------------------------------------------------
local function ScanLootRarity()
    local numItems = SafeCall(API.GetNumLootItems) or 0
    if numItems <= 0 then return nil end

    local maxQuality = 0
    local sourceGUID = nil

    for i = 1, numItems do
        local _, _, _, quality, _, isQuestItem = API.GetLootSlotInfo(i)
        local link = API.GetLootSlotLink and API.GetLootSlotLink(i)

        local q = quality
        if (q == nil or Azaath.IsSecret(q) or q <= 1) and link then
            local hex = link:match("|c%x%x(%x%x%x%x%x%x)") or link:match("|c(%x%x%x%x%x%x)")
            if hex then
                local HEX_TO_Q = {
                    ["9d9d9d"] = 0, ["ffffff"] = 1, ["1eff00"] = 2,
                    ["0070dd"] = 3, ["0070ff"] = 3, ["a335ee"] = 4,
                    ["ff8000"] = 5, ["e6cc80"] = 6, ["00ccff"] = 7,
                }
                if HEX_TO_Q[hex:lower()] then q = HEX_TO_Q[hex:lower()] end
            end
            if (q == nil or q <= 1) and _G.C_Item and C_Item.GetItemQualityByID then
                local ok, iq = pcall(C_Item.GetItemQualityByID, link)
                if ok and type(iq) == "number" and not Azaath.IsSecret(iq) then q = iq end
            end
            if (q == nil or q <= 1) and _G.GetItemInfo then
                local ok, _, _, iq = pcall(GetItemInfo, link)
                if ok and type(iq) == "number" and not Azaath.IsSecret(iq) then q = iq end
            end
        end

        if isQuestItem and (q == nil or q < 1) then q = 1 end
        q = tonumber(q) or 1
        if q > maxQuality then maxQuality = q end

        if not sourceGUID and _G.GetLootSourceInfo then
            local ok, src = pcall(GetLootSourceInfo, i)
            if ok and type(src) == "string" and not Azaath.IsSecret(src) then
                sourceGUID = src
            end
        end
    end

    return maxQuality, sourceGUID
end

function M:TriggerLootBurst(quality, anchor, sourceGUID)
    local db = DB()
    if not db.enabled or not db.rarityBurst then return end

    local color = RARITY_COLORS[quality] or COLOR_DEFAULT
    local targetPlate = anchor

    -- 1. Se soubermos o GUID da fonte do saque, localiza a placa exata daquele corpo
    if not targetPlate and sourceGUID and _G.C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local u = plate.namePlateUnitToken
            if u and SafeCall(UnitGUID, u) == sourceGUID and plate:IsShown() and not IsBehindCamera(u) then
                targetPlate = plate
                break
            end
        end
    end

    -- 2. Fallbacks: somente se forem corpos de mob válidos
    if not targetPlate then
        for _, u in ipairs({ "softinteract", "target", "mouseover" }) do
            if UnitExists(u) and CheckUnitLoot(u) and not IsBehindCamera(u) then
                local p = GetUnitNamePlate(u)
                if p and p:IsShown() then
                    targetPlate = p
                    break
                end
            end
        end
    end

    -- Se não encontrar uma placa válida de corpo morto na tela, nunca dispara em frames genéricos
    if not targetPlate then return end

    local beam = AcquireBeam(targetPlate)
    PlaceBeam(beam, targetPlate, targetPlate.namePlateUnitToken or targetPlate.unit)
    beam:Show()

    beam.dying       = nil
    beam.burstActive = true
    beam.burstDur    = db.duration or 2.6
    beam.burstEnd    = GetTime() + beam.burstDur
    beam.flash       = 1.0
    beam.curR, beam.curG, beam.curB = color[1], color[2], color[3]
    beam.targetR, beam.targetG, beam.targetB = color[1], color[2], color[3]
    StartWave(beam, 1.50, 1.00, 0.35, 0.9, true)
end

--------------------------------------------------------------------------------
-- Fim do saque: identificar os corpos e apagar o facho quando esvaziarem
--------------------------------------------------------------------------------
KillBeam = function(beam)
    if not beam.isGhost and beam.plate and activeBeams[beam.plate] == beam then
        activeBeams[beam.plate] = nil
    end
    ReleaseGhost(beam) -- devolve ao pool e zera tudo (serve para facho vivo também)
end

local function MarkCorpseEmpty(guid)
    if not guid then return end
    local rec = lootedCorpses[guid] or {}
    rec.empty = true
    rec.at = GetTime()
    lootedCorpses[guid] = rec
    for _, beam in pairs(activeBeams) do
        if beam.guid == guid and not beam.dying then beam.dying = GetTime() end
    end
    local g = ghosts[guid]
    if g and not g.dying then g.dying = GetTime() end
end

-- GUIDs dos corpos do saque aberto. Se o jogo não informar a origem, usa o
-- corpo morto da retícula / alvo / mouseover (é ele que está sendo saqueado).
local function LootSources()
    local set = {}
    local n = SafeCall(API.GetNumLootItems) or 0
    if _G.GetLootSourceInfo then
        for i = 1, n do
            local ok, g1, _, g2, _, g3 = pcall(GetLootSourceInfo, i)
            if ok then
                for _, g in ipairs({ g1, g2, g3 }) do
                    if type(g) == "string" and not Azaath.IsSecret(g) then set[g] = true end
                end
            end
        end
    end
    if not next(set) then
        for _, u in ipairs({ "softinteract", "target", "mouseover" }) do
            if UnitExists(u) and IsTrue(pcall(UnitIsDead, u)) then
                local g = SafeCall(UnitGUID, u)
                if type(g) == "string" then
                    set[g] = true
                    break
                end
            end
        end
    end
    return set, n
end

--------------------------------------------------------------------------------
-- Configuração de CVars e Integração
--------------------------------------------------------------------------------
local function Enforce360Interaction()
    if InCombatLockdown and InCombatLockdown() then return end
    local olhoActive = Azaath.db and Azaath.db.olho and Azaath.db.olho.enabled
    pcall(function()
        if SetCVar then
            SetCVar("nameplateShowAll", "1")
            SetCVar("nameplateShowEnemies", "1")
            SetCVar("SoftTargetInteract", "3")
            SetCVar("SoftTargetNameplateInteract", "1")
            SetCVar("SoftTargetInteractArc", "2")          -- 2 = 360 graus para detecção em torno do jogador
            SetCVar("SoftTargetInteractOnlyInRange", "0")
            SetCVar("SoftTargetInteractRangeIsHard", "0")
            if not olhoActive then
                -- 45 jd: corpos um pouco mais longe ou num desnível (a altura conta na
                -- distância) também ganham placa. O jogo ainda corta pelo próprio limite.
                SetCVar("SoftTargetInteractRange", "45")
            end
        end
    end)
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("LOOT_READY")
eventFrame:RegisterEvent("LOOT_OPENED")
eventFrame:RegisterEvent("LOOT_CLOSED")
eventFrame:RegisterEvent("LOOT_SLOT_CLEARED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_BEHIND_CAMERA_CHANGED")
eventFrame:RegisterEvent("UNIT_HEALTH")
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
eventFrame:RegisterEvent("PLAYER_SOFT_INTERACT_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "CVAR_UPDATE")
-- NUNCA registrar COMBAT_LOG_EVENT_UNFILTERED: no WoW Forever abre a janela de
-- "ação bloqueada". A varredura de 0,1 s já detecta os corpos novos.

eventFrame:SetScript("OnEvent", function(self, event, arg1, ...)
    if event == "PLAYER_LOGIN" or event == "PLAYER_ENTERING_WORLD" then
        Enforce360Interaction()
        BuildCursorCache()
        RequestRangeItems()
        EvaluateWorld()
    elseif event == "PLAYER_REGEN_ENABLED" then
        Enforce360Interaction()
        EvaluateWorld()
    elseif event == "CVAR_UPDATE" then
        -- Preset de gráficos desfaz a detecção de corpos: devolve 1 s depois
        -- (em combate Enforce360Interaction espera o PLAYER_REGEN_ENABLED)
        if type(arg1) == "string" and not Azaath.IsSecret(arg1) then
            local n = arg1:lower()
            if n == "graphicsquality" or n == "raidgraphicsquality" then
                C_Timer.After(1, Enforce360Interaction)
            end
        end
    elseif event == "LOOT_READY" or event == "LOOT_OPENED" then
        local maxQ, guid = ScanLootRarity()
        local sources, n = LootSources()
        if not lootSession then
            lootSession = { guids = sources, remaining = n }
        else
            for g in pairs(sources) do lootSession.guids[g] = true end
        end
        if maxQ then
            for g in pairs(sources) do
                local prev = lootedCorpses[g]
                if not (prev and prev.empty) then
                    lootedCorpses[g] = { quality = maxQ, empty = false, at = GetTime() }
                end
            end
            M:TriggerLootBurst(maxQ, nil, guid or next(sources))
        end
    elseif event == "LOOT_SLOT_CLEARED" then
        if lootSession then
            lootSession.remaining = (lootSession.remaining or 1) - 1
            if lootSession.remaining <= 0 then
                for g in pairs(lootSession.guids) do MarkCorpseEmpty(g) end
            end
        end
    elseif event == "LOOT_CLOSED" then
        if lootSession then
            -- Sem itens sobrando (ou sem como contar): o corpo foi esvaziado
            if (lootSession.remaining or 0) <= 0 then
                for g in pairs(lootSession.guids) do MarkCorpseEmpty(g) end
            end
            lootSession = nil
        end
        EvaluateWorld()
    elseif event == "UNIT_HEALTH" and arg1 then
        if type(arg1) == "string" and arg1:find("^nameplate") then
            local dead = IsTrue(pcall(UnitIsDead, arg1))
                or IsTrue(pcall(UnitIsCorpse, arg1))
                or (SafeCall(UnitHealth, arg1) == 0)
            if dead then
                if M.plateCache and M.plateCache[arg1] then
                    M.plateCache[arg1].dead = true
                end
                EvaluateWorld()
            end
        end
    elseif event == "NAME_PLATE_UNIT_REMOVED" and arg1 then
        if M.plateCache then M.plateCache[arg1] = nil end
        EvaluateWorld()
    else
        EvaluateWorld()
    end
end)

-- Varredura contínua suave (10x por segundo) para detectar corpos e atualizar visibilidade
local pollTimer = 0
local pollFrame = CreateFrame("Frame")
pollFrame:SetScript("OnUpdate", function(_, el)
    pollTimer = pollTimer + el
    if pollTimer >= 0.10 then
        pollTimer = 0
        EvaluateWorld()
    end
end)

--------------------------------------------------------------------------------
-- Modo de Demonstração / Teste (/azaath beam)
--------------------------------------------------------------------------------
function M:StartTest()
    local db = DB()
    local footPad = 0.12 * BeamSize(db)
    local playerPlate = GetUnitNamePlate("player")
    if not testBeam then testBeam = CreateBeamWidget() end
    testBeam:ClearAllPoints()
    if playerPlate then
        testBeam:SetParent(playerPlate)
        testBeam:SetPoint("CENTER", playerPlate, "CENTER", 0, (db.offsetY or 0) + footPad)
    else
        testBeam:SetParent(UIParent)
        testBeam:SetPoint("CENTER", UIParent, "CENTER", 0, -80 + footPad)
    end
    testBeam.isTest = true
    ResetBeamAnim(testBeam)
    testBeam:Show()

    testMode = true
    testEnd  = GetTime() + 10
    testStep = -1
    Azaath:Print("Demonstração da Luz de Saque Azaath ativada por 10s!")
end

function M:StopTest()
    testMode = false
    if testBeam then testBeam:Hide() end
    EvaluateWorld()
end

function M:ToggleTest()
    if testMode then M:StopTest() else M:StartTest() end
end

-- Atualiza a posição de todos os fachos ativos quando o slider de offset muda
function M:ApplyConfig()
    local db = DB()
    local offsetY = db.offsetY or 0
    local footPad = 0.12 * BeamSize(db)
    for plate, beam in pairs(activeBeams) do
        beam.lastOY = nil -- o OnUpdate reposiciona com o novo ajuste
    end
    if testBeam and testBeam:IsShown() then
        local playerPlate = GetUnitNamePlate("player")
        testBeam:ClearAllPoints()
        if playerPlate then
            testBeam:SetPoint("CENTER", playerPlate, "CENTER", 0, offsetY + footPad)
        else
            testBeam:SetPoint("CENTER", UIParent, "CENTER", 0, -80 + footPad)
        end
    end
end

-- /azaath beamdiag: mostra quantas placas existem, quantas são corpos e a conta da altura
function M:Diag()
    local total, dead = 0, 0
    if _G.C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            total = total + 1
            local u = plate.namePlateUnitToken
            if u and IsTrue(pcall(UnitIsDead, u)) then dead = dead + 1 end
        end
    end
    Azaath:Print("Facho: %d placas na tela, %d de corpos mortos. Zoom da camera: %.1f", total, dead, CameraZoom())
    local n = 0
    for plate, beam in pairs(activeBeams) do
        n = n + 1
        local name = beam.unitToken and SafeCall(UnitName, beam.unitToken) or "?"
        Azaath:Print("  %s [%s]: distancia ~%.0f jd, escala %.2f, descida %.0f",
            tostring(name), tostring(beam.unitToken), beam.distCur or -1,
            beam.lastScale or 1, -(beam.lastOY or 0))
    end
    if n == 0 then Azaath:Print("  nenhum facho ativo agora.") end
    local ng = 0
    for _ in pairs(ghosts) do ng = ng + 1 end
    Azaath:Print("  fachos-memoria (corpos ja vistos): %d", ng)

    -- Grava tudo no SavedVariables (AzaathUIDB.beamDiag) para leitura fora do jogo
    local out = { time = date and date("%Y-%m-%d %H:%M:%S") or "", plates = {}, cvars = {}, units = {} }
    if _G.C_NamePlate and C_NamePlate.GetNamePlates then
        for _, plate in ipairs(C_NamePlate.GetNamePlates()) do
            local u = plate.namePlateUnitToken
            out.plates[#out.plates + 1] = string.format("%s | %s | morto=%s",
                tostring(u), tostring(u and SafeCall(UnitName, u)),
                tostring(u and IsTrue(pcall(UnitIsDead, u))))
        end
    end
    -- P: valor cru de uma API ("SECRETO", "ERRO" ou o valor), para ver o que a instância esconde
    local function P(fn, ...)
        if not fn then return "sem-api" end
        local ok, v = pcall(fn, ...)
        if not ok then return "ERRO" end
        if Azaath.IsSecret(v) then return "SECRETO" end
        return tostring(v)
    end
    local inInst, instType = false, nil
    if IsInInstance then local ok, a, b = pcall(IsInInstance); if ok then inInst, instType = a, b end end
    out.instance = tostring(inInst) .. " " .. tostring(instType)
    local function RawPlate(u)
        if not (_G.C_NamePlate and C_NamePlate.GetNamePlateForUnit) then return "sem-api" end
        local ok, p = pcall(C_NamePlate.GetNamePlateForUnit, u)
        if not ok then return "ERRO" end
        if p == nil then return "nil" end
        local forb = p.IsForbidden and p:IsForbidden()
        return forb and "PROIBIDA" or "ok"
    end
    local NP = _G.C_NamePlate
    out.plateCount = NP and NP.GetNamePlates and P(function() return #NP.GetNamePlates() end) or "?"
    out.plateCountAll = NP and NP.GetNamePlates and P(function() return #NP.GetNamePlates(true) end) or "?"
    for _, u in ipairs({ "softinteract", "softenemy", "softfriend", "target", "mouseover" }) do
        out.units[#out.units + 1] = string.format(
            "%s | existe=%s obj=%s nome=%s guid=%s morto=%s cadaver=%s vida=%s reacao=%s tap=%s jogador=%s placa=%s",
            u, P(UnitExists, u), P(UnitIsGameObject, u), P(UnitName, u),
            (function() local r = P(UnitGUID, u); return r:sub(1, 12) end)(),
            P(UnitIsDead, u), P(UnitIsCorpse, u), P(UnitHealth, u), P(UnitReaction, "player", u),
            P(UnitIsTapDenied, u), P(UnitIsPlayer, u), RawPlate(u))
    end
    for i = 1, 40 do
        local u = "nameplate" .. i
        if SafeCall(UnitExists, u) == true then
            out.units[#out.units + 1] = string.format("%s | obj=%s nome=%s morto=%s placa=%s",
                u, P(UnitIsGameObject, u), P(UnitName, u), P(UnitIsDead, u), RawPlate(u))
        end
    end
    -- Procura no próprio cliente alguma opção (CVar) que mantenha placas em corpos
    if _G.C_Console and C_Console.GetAllCommands then
        local ok, all = pcall(C_Console.GetAllCommands)
        if ok and type(all) == "table" then
            for _, c in ipairs(all) do
                local name = c.command
                if type(name) == "string" then
                    local l = name:lower()
                    if l:find("nameplate", 1, true) or l:find("softtarget", 1, true)
                        or l:find("corpse", 1, true) or l:find("dead", 1, true)
                        or l:find("loot", 1, true) then
                        local v = _G.GetCVar and SafeCall(GetCVar, name)
                        out.cvars[#out.cvars + 1] = name .. " = " .. tostring(v)
                    end
                end
            end
        end
    end
    if #out.cvars == 0 then
        local keys = {
            "nameplateShowAll", "nameplateShowEnemies",
            "SoftTargetInteract", "SoftTargetNameplateInteract",
            "SoftTargetInteractArc", "SoftTargetInteractRange",
            "SoftTargetInteractOnlyInRange", "SoftTargetIconInteract",
            "SoftTargetIconGameObject",
        }
        local getCVar = (_G.C_CVar and C_CVar.GetCVar) or _G.GetCVar
        if getCVar then
            for _, k in ipairs(keys) do
                out.cvars[#out.cvars + 1] = k .. " = " .. tostring(SafeCall(getCVar, k))
            end
        end
    end
    if type(AzaathUIDB) == "table" then AzaathUIDB.beamDiag = out end
    Azaath:Print("  %d opcoes do jogo anotadas. Faca /reload para gravar o diagnostico.", #out.cvars)
end

BuildCursorCache()
RequestRangeItems()
Enforce360Interaction()
