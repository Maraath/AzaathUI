--[[
    AzaathUI - Modules/RotationAssist.lua
    Assistente de rotação (por enquanto só Guerreiro):
      * Brado de Batalha brilha (vermelho) na barra enquanto o jogador está sem o efeito;
      * habilidades situacionais brilham (dourado) com um som leve quando ficam disponíveis.
    Reativas (o jogo libera quando a condição acontece; lidas por IsUsableAction):
      Executar (alvo <= 20%), Sobrepujar (alvo se esquivou), Revanche (bloqueio/esquiva/aparo),
      Ímpeto da Vitória (depois de matar). Só por proc (SPELL_ACTIVATION_OVERLAY_GLOW_*):
      Golpe (Ímpeto Sangrento), Batida com Escudo (Espada e Escudo), Executar (Morte Súbita),
      Sobrepujar (Gosto por Sangue). Interrupções (Murro, Golpe de Escudo) com o alvo conjurando.
    Os spellIDs servem só para descobrir o NOME de cada habilidade no cliente; a ligação
    com o botão é por nome, então qualquer patente funciona.
    Em combate, auras e usabilidade podem vir secretas: sem leitura, o Brado usa a
    duração estimada e a usabilidade vai para o alfa do brilho pelo próprio jogo (sem som).
    /azrot = diagnóstico · /azrot teste = acende tudo e toca o som.
]]
local _, Azaath = ...
local M = Azaath:NewModule("RotationAssist")

local R = {
    -- todas as patentes (Clássico/TBC/WotLK)
    shout = { 6673, 5242, 6192, 11549, 11550, 11551, 25289, 2048, 47436 },
    reactive = {
        5308, 20658, 20660, 20661, 20662, 25234, 25236, 47470, 47471, -- Executar
        7384, 7887, 11584, 11585,                                     -- Sobrepujar
        6572, 6574, 7379, 11600, 11601, 25288, 25269, 30357, 57823,   -- Revanche
    },
    procOnly = {
        1464, 8820, 11604, 11605, 25241, 25242, 47474, 47475,         -- Golpe (Ímpeto Sangrento)
        23922, 23923, 23924, 23925, 25258, 30356, 47487, 47488,       -- Batida com Escudo (Espada e Escudo)
    },
    victory = { 34428 },                                              -- Ímpeto da Vitória (precisa do efeito Vitorioso)
    victorious = { 32216, 82368 },                                    -- efeito Vitorioso (20 s depois de matar)
    victoryExpire = 0,
    interrupt = { 6552, 6554, 72, 1671, 1672, 29704 },                -- Murro, Golpe de Escudo
    names = {},     -- nome -> "shout" | "reactive" | "procOnly" | "interrupt"
    procs = {},     -- nome -> true enquanto o jogo manda o aro de proc
    lastOn = {},    -- nome -> GetTime() do último som
    glows = {},     -- botão -> textura do brilho
    shoutExpire = 0,
    shoutDur = 120,
    SOUND_GAP = 4,
    TICK = 0.1,
}

local function SpellName(id)
    if not id or Azaath.IsSecret(id) then return nil end
    local n
    if C_Spell and C_Spell.GetSpellName then
        local ok, v = pcall(C_Spell.GetSpellName, id); if ok then n = v end
    elseif GetSpellInfo then
        local ok, v = pcall(GetSpellInfo, id); if ok then n = v end
    end
    if n and not Azaath.IsSecret(n) and n ~= "" then return n end
end

-- Nomes de reserva (ptBR/enUS): no Forever algumas habilidades têm ID próprio
-- (o Ímpeto da Vitória com recarga de 30 s não é o 34428 do WotLK).
R.hints = {
    shout = { "Brado de Batalha", "Battle Shout" },
    reactive = { "Executar", "Execute", "Subjugar", "Sobrepujar", "Overpower", "Revanche", "Vingança", "Revenge" },
    victory = { "Ímpeto da Vitória", "Victory Rush" },
    interrupt = { "Murro", "Pummel", "Golpe de Escudo", "Shield Bash" },
    victorious = { "Vitorioso", "Victorious" },
}

local function BuildNames()
    wipe(R.names)
    for kind, list in pairs(R.hints) do
        if kind ~= "victorious" then
            for _, n in ipairs(list) do R.names[n] = kind end
        end
    end
    for _, kind in ipairs({ "shout", "reactive", "procOnly", "interrupt", "victory" }) do
        for _, id in ipairs(R[kind]) do
            local n = SpellName(id)
            if n and not R.names[n] then R.names[n] = kind end
        end
    end
end

-- Em combate o conteúdo do botão pode vir secreto: a última leitura legível de cada
-- slot fica em R.slots (limpa quando o slot muda fora de combate).
R.slots = {}
local function ReadAction(action)
    local okH, has = pcall(HasAction, action)
    if not okH or Azaath.IsSecret(has) then return false end
    if not has then return nil end
    local ok, kind, id = pcall(GetActionInfo, action)
    if not ok or Azaath.AnySecret(kind, id) then return false end
    if kind == "macro" and GetMacroSpell then
        local ok2, ms = pcall(GetMacroSpell, id)
        if not ok2 or Azaath.IsSecret(ms) then return false end
        id, kind = ms, ms and "spell"
    end
    if kind ~= "spell" then return nil end
    local n = SpellName(id)
    if not n then return false end
    return n, id
end

-- nome, spellID (do cache quando o jogo esconde)
local function ActionSpellName(action)
    if not action or Azaath.IsSecret(action) then return nil end
    local n, id = ReadAction(action)
    if n == false then
        local c = R.slots[action]
        R.fromCache = (R.fromCache or 0) + 1
        if c then return c.name, c.id end
        return nil
    end
    if n then
        local c = R.slots[action]
        if not c or c.name ~= n then R.slots[action] = { name = n, id = id } end
    else
        R.slots[action] = nil
    end
    return n, id
end

--------------------------------------------------------------------------------
-- Brilho
--------------------------------------------------------------------------------
local COLORS = {
    shout = { 1, 0.28, 0.12 },
    proc  = { 0.25, 0.62, 1 }, -- azul Azaath
}

-- Texturas de tools/rotation-glow/gen.js: o slot ocupa metade do lado, então o brilho tem 2x o botão.
-- Octógono na barra NextGen (layout "split"), quadrado nas outras.
local function GlowTex()
    local ab = Azaath.db and Azaath.db.actionbars
    local oct = ab and Azaath.IsSplitLayout and Azaath.IsSplitLayout(ab.layout)
    return Azaath.media.path .. "Rotation\\" .. (oct and "GlowOct" or "GlowSq")
end

local function GetGlow(b)
    local g = R.glows[b]
    if g then return g end
    local parent = b.textLayer or b
    g = parent:CreateTexture(nil, "OVERLAY", nil, 6)
    g:SetBlendMode("ADD")
    g:SetPoint("CENTER", b, "CENTER")
    g:Hide()
    -- segunda camada somada à primeira: dobra a intensidade no pico do pulso
    g.core = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    g.core:SetBlendMode("ADD")
    g.core:SetPoint("CENTER", b, "CENTER")
    g.core:Hide()
    local ag = g.core:CreateAnimationGroup()
    ag:SetLooping("BOUNCE")
    local al = ag:CreateAnimation("Alpha")
    al:SetFromAlpha(0.15)
    al:SetToAlpha(1)
    al:SetDuration(0.45)
    al:SetSmoothing("IN_OUT")
    g.anim = ag
    -- clarão de entrada: cresce e some uma vez quando acende
    g.burst = parent:CreateTexture(nil, "OVERLAY", nil, 7)
    g.burst:SetBlendMode("ADD")
    g.burst:SetPoint("CENTER", b, "CENTER")
    g.burst:Hide()
    local bg = g.burst:CreateAnimationGroup()
    local sc = bg:CreateAnimation("Scale")
    sc:SetScaleFrom(0.7, 0.7)
    sc:SetScaleTo(1.35, 1.35)
    sc:SetDuration(0.4)
    sc:SetSmoothing("OUT")
    local fa = bg:CreateAnimation("Alpha")
    fa:SetFromAlpha(1)
    fa:SetToAlpha(0)
    fa:SetDuration(0.4)
    bg:SetScript("OnFinished", function() g.burst:Hide() end)
    g.burstAnim = bg
    R.glows[b] = g
    return g
end

local function GlowLayers(g, fn)
    fn(g); fn(g.core); fn(g.burst)
end

-- state: nil (apaga) | "shout" | "proc" | "secret" (usabilidade secreta vai para o alfa)
local function SetGlow(b, state, secretUsable)
    local g = R.glows[b]
    if not state then
        if g and g.state then
            g.state = nil
            g.anim:Stop(); g.burstAnim:Stop()
            GlowLayers(g, function(t) t:Hide() end)
        end
        return
    end
    g = GetGlow(b)
    local s = (b:GetWidth() or 40) * 2
    local tex = GlowTex()
    local c = COLORS[state == "shout" and "shout" or "proc"]
    GlowLayers(g, function(t)
        t:SetSize(s, s)
        if t.tex ~= tex then t.tex = tex; t:SetTexture(tex) end
        t:SetVertexColor(c[1], c[2], c[3])
    end)
    if state == "secret" then
        g.anim:Stop(); g.core:Hide()
        g:Show()
        -- o jogo avalia o booleano secreto e devolve o alfa (o addon nunca lê o valor)
        local done = g.SetAlphaFromBoolean and pcall(g.SetAlphaFromBoolean, g, secretUsable, 1, 0)
        if not done and C_CurveUtil and C_CurveUtil.EvaluateColorValueFromBoolean then
            local ok, a = pcall(C_CurveUtil.EvaluateColorValueFromBoolean, secretUsable, 1, 0)
            done = ok and pcall(g.SetAlpha, g, a)
        end
        if not done then g:SetAlpha(0) end
        R.secretPath = done and "ok" or "sem API"
    elseif g.state ~= state or not g:IsShown() then
        g:SetAlpha(1); g:Show()
        g.core:Show(); g.anim:Play()
        g.burst:Show(); g.burstAnim:Stop(); g.burstAnim:Play()
    end
    g.state = state
end

-- Som do brilho (tools/rotation-glow/gen-voices.js): coral "RÁ!" para Subjugar e Executar; o resto
-- usa o "tim" padrão. O Ímpeto da Vitória só brilha, sem som (pedido do usuário em 24/11).
-- (WarCry.ogg fica sem uso por enquanto.)
R.sounds = {
    ChoirRa = { ids = { 7384, 5308 }, names = { "Subjugar", "Sobrepujar", "Overpower", "Executar", "Execute" } },
}
R.silentKinds = { victory = true }

-- Som ao USAR a habilidade (arquivos do usuário tratados por tools/rotation-glow/prep-casts.js).
-- Cada voz tem 3 variações de tom (CastX, CastX2, CastX3) sorteadas a cada uso, como o jogo faz com
-- as vozes dele. gap = intervalo mínimo entre duas vozes da mesma habilidade (o Executar é usado em
-- sequência no fim da luta: gritar em todo golpe soava artificial).
R.castSounds = {
    -- (o Executar teve falas às vezes até 24/11; o usuário pediu para tirar. Campos aceitos: lines, chance, gap)
    -- Luz de Elluna: "Testemunhem o poder de Eluna", em todo uso
    { file = "CastElune",        ids = {},              names = { "Luz de Elluna", "Luz de Elune", "Luz de Eluna" } },
}
function R.CastSoundFor(name)
    if not name then return nil end
    for _, d in ipairs(R.castSounds) do
        for _, n in ipairs(d.names) do if n == name then return d end end
        for _, id in ipairs(d.ids) do if SpellName(id) == name then return d end end
    end
end

-- Toca o arquivo de Media/Rotation no canal de Efeitos (SFX), na mesma mixagem dos golpes e
-- habilidades do jogo. "Volume dos sons" (actionbars.rotation.volume) acima de 1 empilha cópias no
-- mesmo instante (2 = ~+6 dB, 3 = ~+9,5 dB): os arquivos já estão no máximo sem distorcer.
function R.Play(file)
    local path = Azaath.media.path .. "Rotation" .. string.char(92) .. file .. ".ogg"
    local ok, willPlay = pcall(PlaySoundFile, path, "SFX")
    local n = math.floor((M.db and M.db.volume) or 1)
    for _ = 2, math.min(3, n) do pcall(PlaySoundFile, path, "SFX") end
    return ok and willPlay
end

-- Efeitos sonoros gerados (tools/rotation-glow/gen-sfx.js -> Media/Rotation/Sfx*.ogg), tocados em todo
-- uso (sem intervalo mínimo). onHit: o Golpe Heroico só acontece no próximo ataque, então o efeito sai
-- quando o golpe é confirmado (UNIT_SPELLCAST_SUCCEEDED), não quando o botão é apertado.
R.sfx = {
    { file = "SfxHeroicStrike", onHit = true, names = { "Golpe Heroico", "Heroic Strike" },
      ids = { 78, 284, 285, 1608, 11564, 11565, 11566, 11567, 25286, 29707, 30324, 47449, 47450 },
      mute = { 569827, 569828, 569829, 569830, 569831, 569098 } },
    -- Subjugar: ganhou o antigo efeito do Executar (golpe pesado); mesmos sons originais do Golpe Heroico
    { file = "SfxOverpower",    names = { "Subjugar", "Sobrepujar", "Overpower" }, ids = { 7384, 7887, 11584, 11585 },
      mute = { 569827, 569828, 569829, 569830, 569831, 569098 } },
    { file = "SfxExecute",      names = { "Executar", "Execute" }, ids = { 5308, 47471 },
      mute = { 569827, 569828, 569829, 569830, 569831, 568003 } },
    -- Cutilada: o mesmo efeito do Golpe Heroico; também sai no próximo ataque
    { file = "SfxHeroicStrike", onHit = true, names = { "Cutilada", "Cleave" },
      ids = { 845, 7369, 11608, 11609, 20569, 25231, 47519, 47520 },
      mute = { 569827, 569828, 569829, 569830, 569831, 568227 } },
    -- Batida: "Golpe final" (gen-strikes.js); tem conjuração, então sai quando o golpe é confirmado
    { file = "SfxSlam", onHit = true, names = { "Batida", "Slam" },
      ids = { 1464, 8820, 11604, 11605, 25241, 25242, 47474, 47475 },
      mute = { 569827, 569828, 569829, 569830, 569831, 567879 } },
    { file = "SfxBattleShout",  names = { "Brado de Batalha", "Battle Shout" }, ids = { 5242, 6673, 47436 },
      mute = { 568028 } },
    { file = "SfxIntimidating", names = { "Brado Intimidador", "Intimidating Shout" }, ids = { 5246 },
      mute = { 568028, 567950 } },
    { file = "SfxDemoralizing", names = { "Brado Desmoralizador", "Demoralizing Shout" }, ids = { 1160, 47437 },
      mute = { 568028, 568268 } },
}

-- Sons originais do jogo dessas habilidades (achados nos arquivos do cliente: magia -> SpellXSpellVisual
-- -> SpellVisualEvent -> SpellVisualKitEffect tipo 5 -> SoundKitEntry). São GENÉRICOS: o kit 3091
-- (569827-569831) toca em 563 magias (Subjugar, Golpe Mortal, Punhalada...), o 568028 em 130 (gritos e
-- rugidos). Por isso o silêncio é só uma janela em volta do seu uso: MuteSoundFile no envio do golpe e
-- UnmuteSoundFile ~1,5 s depois da confirmação. O jogo guarda o silêncio até no /reload: ao carregar,
-- tudo é liberado.
R.muteUntil = {}
function R.Mute(fids, sec, exact)
    if not (MuteSoundFile and fids) then return end
    local untilT = GetTime() + sec
    for _, fid in ipairs(fids) do
        local cur = R.muteUntil[fid]
        if not cur then pcall(MuteSoundFile, fid) end
        R.muteUntil[fid] = (exact or not cur) and untilT or math.max(cur, untilT)
    end
end
function R.UnmuteExpired(all)
    if not next(R.muteUntil) then return end
    local now = GetTime()
    for fid, t in pairs(R.muteUntil) do
        if all or now >= t then
            if UnmuteSoundFile then pcall(UnmuteSoundFile, fid) end
            R.muteUntil[fid] = nil
        end
    end
end
function R.UnmuteAllKnown()
    if not UnmuteSoundFile then return end
    for _, d in ipairs(R.sfx) do for _, fid in ipairs(d.mute or {}) do pcall(UnmuteSoundFile, fid) end end
    wipe(R.muteUntil)
end
function R.SfxFor(name)
    if not name then return nil end
    for _, d in ipairs(R.sfx) do
        for _, n in ipairs(d.names) do if n == name then return d end end
        for _, id in ipairs(d.ids) do if SpellName(id) == name then return d end end
    end
end
-- phase: "sent" (pedido enviado) ou "hit" (golpe confirmado)
function R.PlaySfx(name, phase)
    local db = M.db
    if not (db and db.enabled and db.castSfx ~= false) then return end
    local d = R.SfxFor(name)
    if not d then return end
    if phase == "sent" then
        -- silencia os originais antes do servidor confirmar (é na confirmação que o jogo toca o efeito dele);
        -- golpe "no próximo ataque": segura até 6 s, esperando o ataque
        R.Mute(d.mute, d.onHit and 6 or 2.5)
    else
        R.Mute(d.mute, 1.5, true) -- confirmado: libera 1,5 s depois
    end
    if (d.onHit and phase == "hit") or (not d.onHit and phase == "sent") then R.Play(d.file) end
end

function R.PlayCast(name, force)
    local db = M.db
    if not (db and db.enabled and db.castSounds ~= false) then return end
    local d = R.CastSoundFor(name)
    if not d then return end
    local now = GetTime()
    if not force then
        if d.last and now - d.last < (d.gap or 1) then return end
        if d.chance and math.random() > d.chance then return end
    end
    d.last = now
    -- sorteia uma das 3 variações, sem repetir a anterior
    local v = math.random(1, 2)
    if d.lastVar and v >= d.lastVar then v = v + 1 end
    if not d.lastVar then v = math.random(1, 3) end
    d.lastVar = v
    local base = d.file
    if d.lines then
        local n = #d.lines
        local i = math.random(1, n - 1)
        if d.lastLine and i >= d.lastLine then i = i + 1 end
        if not d.lastLine then i = math.random(1, n) end
        d.lastLine = i
        base = d.lines[i]
    end
    R.Play(base .. R.EnvSuffix() .. (v > 1 and v or ""))
end

-- Som de addon não recebe a acústica do lugar (os sons 3D do jogo recebem): em lugar fechado
-- (construção, caverna) ou masmorra/raide usa a versão com sala curta (CastXIn*.ogg).
function R.EnvSuffix()
    local ok, indoors = pcall(IsIndoors)
    if ok and not Azaath.IsSecret(indoors) and indoors then return "In" end
    local ok2, inInst, kind = pcall(IsInInstance)
    if ok2 and not Azaath.AnySecret(inInst, kind) and inInst and (kind == "party" or kind == "raid") then
        return "In"
    end
    return ""
end
function R.SoundFor(name)
    for file, d in pairs(R.sounds) do
        if d.kinds and d.kinds[R.names[name] or ""] then return file end
        for _, n in ipairs(d.names) do if n == name then return file end end
        for _, id in ipairs(d.ids) do if SpellName(id) == name then return file end end
    end
end

local function PlayAlert(name)
    local db = M.db
    if not (db and db.sound) then return end
    local now = GetTime()
    if R.lastOn[name] and now - R.lastOn[name] < R.SOUND_GAP then return end
    R.lastOn[name] = now
    -- som próprio (tools/rotation-glow/gen.js) no canal Master: toca mesmo com Efeitos desligado
    if not R.Play(R.SoundFor(name) or "Alert") and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        pcall(PlaySound, SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "SFX")
    end
end

--------------------------------------------------------------------------------
-- Condições
--------------------------------------------------------------------------------
-- true = com Brado · false = sem · nil = não deu para ler (secreto em combate)
-- Procura um efeito no jogador pelo spellID OU pelo nome (os IDs do Forever podem
-- não ser os do WotLK). Devolve a aura, false (não tem) ou nil (lista secreta/ilegível).
local function FindPlayerAura(ids, hints)
    if not (C_UnitAuras and C_UnitAuras.GetAuraDataByIndex) then return nil end
    local idSet, nameSet, any = {}, {}, false
    for _, n in ipairs(hints or {}) do nameSet[n] = true; any = true end
    for _, id in ipairs(ids) do
        idSet[id] = true
        local n = SpellName(id)
        if n then nameSet[n] = true; any = true end
    end
    for i = 1, 40 do
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
        if not ok or Azaath.IsSecret(a) then return nil end
        if not a then break end
        local n, sid = a.name, a.spellId
        if Azaath.AnySecret(n, sid) then return nil end
        if idSet[sid] or nameSet[n] then return a end
    end
    if not any then return nil end -- não sabemos o nome do efeito: não dá para afirmar que falta
    return false
end

-- true = com Brado · false = sem · nil = não deu para ler (secreto em combate)
local function ReadShoutAura()
    local a = FindPlayerAura(R.shout, R.hints.shout)
    if a == nil then return nil end
    if not a then R.shoutExpire = 0; return false end
    local exp, dur = a.expirationTime, a.duration
    if not Azaath.AnySecret(exp, dur) then
        if exp and exp > 0 then R.shoutExpire = exp end
        if dur and dur > 0 then R.shoutDur = dur end
    end
    return true
end

local function HasShout()
    local v = ReadShoutAura()
    if v ~= nil then return v end
    return GetTime() < R.shoutExpire -- estimativa: última leitura legível ou último uso
end

local function TargetInterruptible()
    if not (UnitExists("target") and UnitCanAttack("player", "target")) then return false end
    local name, _, _, _, _, _, _, notInt = UnitCastingInfo("target")
    if Azaath.AnySecret(name, notInt) then return false end
    if not name then
        local n2, _, _, _, _, _, ni2 = UnitChannelInfo("target")
        if Azaath.AnySecret(n2, ni2) then return false end
        name, notInt = n2, ni2
    end
    return name ~= nil and not notInt
end

-- "proc" = brilhar · false = apagar · "secret" = usabilidade secreta (2º retorno)
-- Vitorioso: true/false lido · nil = secreto (em combate); guarda o fim para estimar depois
local function ReadVictorious()
    local a = FindPlayerAura(R.victorious, R.hints.victorious)
    if a == nil then return nil end
    if not a then R.victoryExpire = 0; return false end
    local exp = a.expirationTime
    if exp and not Azaath.IsSecret(exp) and exp > 0 then R.victoryExpire = exp end
    return true
end

-- destaque de proc perguntado ao jogo pelo spellID (não depende do evento)
local function Overlayed(id)
    if not id then return nil end
    local f = (C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed) or _G.IsSpellOverlayed
    if not f then return nil end
    local ok, v = pcall(f, id)
    if not ok or Azaath.IsSecret(v) then return nil end
    return v and true or false
end

-- usável: tenta a ação e depois a magia; devolve valor legível ou (nil, secreto)
local function Usable(action, id)
    local u = IsUsableAction(action)
    if not Azaath.IsSecret(u) then return u and true or false end
    if id and C_Spell and C_Spell.IsSpellUsable then
        local ok, su = pcall(C_Spell.IsSpellUsable, id)
        if ok and not Azaath.IsSecret(su) then return su and true or false end
    end
    return nil, u
end

local function SituationalState(b, name, kind, id)
    if R.procs[name] or Overlayed(id) then return "proc" end
    if kind == "procOnly" then return false end
    if kind == "victory" then
        local v = ReadVictorious()
        if v == false then return false end
        if v == nil and GetTime() < R.victoryExpire then return "proc" end
        if v then return "proc" end
        -- secreto e sem estimativa: cai no usável do jogo (abaixo)
    end
    local usable, secret = Usable(b.action, id)
    if usable == nil then
        if kind == "interrupt" then return false end
        return "secret", secret
    end
    if not usable then return false end
    if kind == "interrupt" and not TargetInterruptible() then return false end
    return "proc"
end

--------------------------------------------------------------------------------
-- Registro de diagnóstico (AzaathUIDB.rotDiag, gravado no /reload ou ao sair):
-- uma linha por mudança do que o jogo devolve para cada habilidade acompanhada.
--------------------------------------------------------------------------------
local function Raw(f, ...)
    if not f then return "sem API" end
    local ok, v = pcall(f, ...)
    if not ok then return "ERRO" end
    if Azaath.IsSecret(v) then return "SECRETO" end
    return tostring(v)
end

local function DiagLog(line)
    if not AzaathUIDB then return end
    local log = AzaathUIDB.rotDiag
    if type(log) ~= "table" or log.v ~= 2 then log = { v = 2 }; AzaathUIDB.rotDiag = log end
    tinsert(log, date("%H:%M:%S") .. format(".%03d ", (GetTime() % 1) * 1000) .. line)
    while #log > 150 do tremove(log, 1) end
end
R.DiagLog = DiagLog

R.lastSig = {}
function R.Record(b, name, id, state)
    local ov = (C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed) or _G.IsSpellOverlayed
    local sig = format("%s [%s] comb=%s usável=%s spellUsable=%s overlay=%s evento=%s vitorioso=%s => %s",
        name, tostring(id), tostring(InCombatLockdown()), Raw(IsUsableAction, b.action),
        Raw(C_Spell and C_Spell.IsSpellUsable, id), Raw(ov, id), tostring(R.procs[name] or false),
        R.names[name] == "victory" and Raw(function() local v = ReadVictorious(); return v == nil and "?" or v end) or "-",
        tostring(state))
    if R.lastSig[b] == sig then return end
    R.lastSig[b] = sig
    DiagLog(sig .. format(" | cache=%d alfaSecreto=%s", R.fromCache or 0, tostring(R.secretPath)))
end

--------------------------------------------------------------------------------
-- Laço
--------------------------------------------------------------------------------
-- Em combate o efeito Vitorioso fica ilegível: alvo hostil que você atacou e que
-- morre (UnitIsDead segue legível) vale como abate e abre a janela de 20 s.
local function WatchTargetDeath()
    if not UnitExists("target") then R.tgtAlive = nil; return end
    local okD, dead = pcall(UnitIsDead, "target")
    local okA, hostile = pcall(UnitCanAttack, "player", "target")
    if not (okD and okA) or Azaath.AnySecret(dead, hostile) then return end
    local okT, denied = pcall(UnitIsTapDenied, "target")
    if okT and not Azaath.IsSecret(denied) and denied then R.tgtAlive = nil; return end
    if dead and R.tgtAlive and hostile then
        R.victoryExpire = GetTime() + 20
        DiagLog("alvo morreu: janela do Ímpeto da Vitória por 20 s")
    end
    R.tgtAlive = (not dead) and hostile and InCombatLockdown() or nil
end

local function Update()
    local db = M.db
    local ab = Azaath:GetModule("ActionBars")
    local buttons = ab and ab.buttons
    if not (db and db.enabled and buttons) then return end
    if R.testUntil and GetTime() < R.testUntil then return end -- /azrot teste segura o brilho
    local noShout = db.shout and not HasShout()
    WatchTargetDeath()
    local lit = {}
    for i = 1, #buttons do
        local b = buttons[i]
        local name, id
        if b:IsVisible() then name, id = ActionSpellName(b.action) end
        if not b.rotHooked and not InCombatLockdown() then
            b.rotHooked = true
            -- PreClick: o nome fica guardado ANTES do pedido de lançamento (o UNIT_SPELLCAST_SENT vem logo depois)
            b:HookScript("PreClick", function(self)
                local n = ActionSpellName(self.action)
                if n then R.pending = { name = n, t = GetTime() } end
            end)
        end
        local kind = name and R.names[name]
        if kind == "shout" then
            SetGlow(b, noShout and "shout" or nil)
        elseif kind then
            local state, secretUsable = SituationalState(b, name, kind, id)
            if R.Record then R.Record(b, name, id, state) end
            if state == "proc" then
                local g = R.glows[b]
                if not (g and g.state == "proc") and not lit[name] and not R.silentKinds[kind] then PlayAlert(name) end
                lit[name] = true
            end
            SetGlow(b, state or nil, secretUsable)
        else
            SetGlow(b, nil)
        end
    end
end

local driver = CreateFrame("Frame")
driver:Hide()
driver.elapsed = 0
driver:SetScript("OnUpdate", function(self, el)
    self.elapsed = self.elapsed + el
    if self.elapsed < R.TICK then return end
    self.elapsed = 0
    R.UnmuteExpired()
    local ok, err = pcall(Update)
    if not ok and Azaath.LogError then Azaath.LogError("RotationAssist: " .. tostring(err)) end
end)

R.casts = {} -- castGUID -> nome (do envio até a confirmação; o spellID pode vir secreto)
driver:SetScript("OnEvent", function(_, event, a1, a2, a3, a4)
    if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" or event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
        local n = SpellName(a1)
        if n and R.names[n] then R.procs[n] = (event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW") or nil end
        DiagLog(format("%s id=%s nome=%s", "proc " .. event:sub(31), Azaath.IsSecret(a1) and "SECRETO" or tostring(a1), tostring(n)))
    elseif event == "UNIT_SPELLCAST_SENT" then
        -- a voz sai quando o pedido vai para o servidor (sem esperar a confirmação, que soma a latência);
        -- o próprio cliente já barra antes disso falta de raiva, alcance e recarga
        R.sawSent = true
        local name = SpellName(a4)
        if not name and R.pending and GetTime() - R.pending.t < 1 then name = R.pending.name end
        R.PlayCast(name)
        R.PlaySfx(name, "sent")
        if name then
            if a3 and not Azaath.IsSecret(a3) then
                R.castsN = (R.castsN or 0) + 1
                if R.castsN > 100 then wipe(R.casts); R.castsN = 0 end -- envios que nunca confirmaram
                R.casts[a3] = name
            end
            local d = R.SfxFor(name)
            if d and d.onHit then R.queuedHit = { name = name, t = GetTime() } end
        end
    elseif event == "UNIT_SPELLCAST_SUCCEEDED" then
        -- em combate o spellID pode vir secreto: usa o botão apertado há menos de 1 s
        local name = SpellName(a3)
        if not name and a2 and not Azaath.IsSecret(a2) then name = R.casts[a2] end
        if a2 and not Azaath.IsSecret(a2) then R.casts[a2] = nil end
        if not name and R.pending and GetTime() - R.pending.t < 1 then name = R.pending.name end
        -- golpe "no próximo ataque" confirmado até 6 s depois do envio
        if not name and R.queuedHit and GetTime() - R.queuedHit.t < 6 then name = R.queuedHit.name end
        if R.queuedHit and name == R.queuedHit.name then R.queuedHit = nil end
        R.pending = nil
        if not R.sawSent then R.PlayCast(name); R.PlaySfx(name, "sent") end -- reserva: cliente sem UNIT_SPELLCAST_SENT
        R.PlaySfx(name, "hit")
        -- câmera por habilidade: aqui o nome já foi resolvido mesmo com spellID secreto
        if name and Azaath.ActionCam and Azaath.ActionCam.OnSpellMove then Azaath.ActionCam.OnSpellMove(name) end
        local k = R.names[name or ""]
        if k == "shout" then
            R.shoutExpire = GetTime() + R.shoutDur
        elseif k == "victory" then
            R.victoryExpire = 0 -- usou: consome o Vitorioso
        end
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED" then
        -- conjuração cortada (ex.: Batida ao andar): libera na hora os sons originais silenciados
        local name = SpellName(a3)
        if not name and a2 and not Azaath.IsSecret(a2) then name = R.casts[a2] end
        local d = R.SfxFor(name)
        if d then
            R.Mute(d.mute, 0.05, true)
            if R.queuedHit and R.queuedHit.name == name then R.queuedHit = nil end
        end
    elseif event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        DiagLog(event == "PLAYER_REGEN_DISABLED" and "---- entrou em combate" or "---- saiu de combate")
    elseif event == "PLAYER_TARGET_CHANGED" then
        R.tgtAlive = nil
    elseif event == "SPELLS_CHANGED" or event == "PLAYER_ENTERING_WORLD" then
        BuildNames()
    end
end)

function M:ApplySettings()
    local on = self.db and self.db.enabled and self.isWarrior
    driver:SetShown(on and true or false)
    if not on then
        for b in pairs(R.glows) do SetGlow(b, nil) end
        R.UnmuteAllKnown()
    end
end

function M:OnInitialize()
    self.db = Azaath.db.actionbars.rotation
end

function M:OnEnable()
    local _, class = UnitClass("player")
    self.isWarrior = class == "WARRIOR"
    if not self.isWarrior then return end
    R.UnmuteAllKnown() -- um /reload no meio da janela deixaria o som original mudo até relogar
    BuildNames()
    for _, e in ipairs({ "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW", "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE",
        "SPELLS_CHANGED", "PLAYER_ENTERING_WORLD", "PLAYER_TARGET_CHANGED", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
        Azaath.SafeRegister(driver, e)
    end
    pcall(driver.RegisterUnitEvent, driver, "UNIT_SPELLCAST_SUCCEEDED", "player")
    pcall(driver.RegisterUnitEvent, driver, "UNIT_SPELLCAST_SENT", "player")
    pcall(driver.RegisterUnitEvent, driver, "UNIT_SPELLCAST_INTERRUPTED", "player")
    pcall(driver.RegisterUnitEvent, driver, "UNIT_SPELLCAST_FAILED", "player")
    self:ApplySettings()
end

--------------------------------------------------------------------------------
-- /azrot: diagnóstico · /azrot teste
--------------------------------------------------------------------------------
local function Show(v)
    if Azaath.IsSecret(v) then return "SECRETO" end
    return tostring(v)
end

SLASH_AZAATHROT1 = "/azrot"
SlashCmdList.AZAATHROT = function(msg)
    msg = (msg or ""):lower()
    if not M.isWarrior then Azaath:Print("Assistente de rotação: só para Guerreiro por enquanto.") return end
    local ab = Azaath:GetModule("ActionBars")
    local buttons = (ab and ab.buttons) or {}
    if msg == "efeitos" then -- ouve os 5 efeitos gerados, um a cada 2,6 s
        for i, d in ipairs(R.sfx) do C_Timer.After((i - 1) * 2.6, function() R.Play(d.file) end) end
        Azaath:Print("Rotação: tocando os efeitos (Golpe Heroico, Subjugar, Executar, Cutilada, Batida, Brado de Batalha, Intimidador, Desmoralizador).")
        return
    end
    if msg == "vozes" then -- ouve as 5 vozes (variação sorteada, ambiente atual), uma a cada 2,8 s
        local was = M.db.castSounds
        for i, d in ipairs(R.castSounds) do
            C_Timer.After((i - 1) * 2.8, function()
                M.db.castSounds = true
                d.last = nil
                R.PlayCast(d.names[1], true)
                M.db.castSounds = was
            end)
        end
        Azaath:Print("Rotação: tocando as vozes (" .. (R.EnvSuffix() == "In" and "lugar fechado" or "ao ar livre") .. ").")
        return
    end
    if msg == "coro" or msg == "grito" then -- ouvir os sons: /azrot coro · /azrot grito
        R.lastOn.Subjugar, R.lastOn.Executar = nil, nil
        local was = M.db.sound; M.db.sound = true
        PlayAlert(msg == "coro" and "Subjugar" or "Executar"); M.db.sound = was
        R.lastOn.Subjugar, R.lastOn.Executar = nil, nil
        return
    end
    if msg == "teste" or msg == "test" then
        for i = 1, #buttons do
            local n = ActionSpellName(buttons[i].action)
            local k = n and R.names[n]
            if k then SetGlow(buttons[i], k == "shout" and "shout" or "proc") end
        end
        local was = M.db.sound; M.db.sound = true; R.lastOn.__test = nil
        PlayAlert("__test"); M.db.sound = was
        R.testUntil = GetTime() + 5
        Azaath:Print("Assistente de rotação: teste aceso por 5 s.")
        return
    end
    Azaath:Print(format("Rotação: ligado=%s som=%s brado=%s | aura do Brado=%s (estimativa %.0fs)",
        tostring(M.db.enabled), tostring(M.db.sound), tostring(M.db.shout),
        Show(ReadShoutAura()), math.max(0, R.shoutExpire - GetTime())))
    do -- efeitos em você (nome e ID), para conferir os IDs do Forever
        local list = {}
        for i = 1, 40 do
            local ok, au = pcall(C_UnitAuras.GetAuraDataByIndex, "player", i, "HELPFUL")
            if not ok or Azaath.IsSecret(au) then list[#list + 1] = "SECRETO"; break end
            if not au then break end
            list[#list + 1] = Show(au.name) .. "=" .. Show(au.spellId)
        end
        Azaath:Print("  efeitos: " .. table.concat(list, ", "))
        DiagLog("efeitos: " .. table.concat(list, ", "))
    end
    Azaath:Print("  silenciar originais: " .. (MuteSoundFile and "disponível" or "SEM MuteSoundFile neste cliente")
        .. " | mudos agora: " .. (next(R.muteUntil) and "sim" or "não"))
    Azaath:Print("  efeito Vitorioso=" .. Show(ReadVictorious()) .. format(" (resta %.0fs)", math.max(0, R.victoryExpire - GetTime())))
    local found = 0
    for i = 1, #buttons do
        local b = buttons[i]
        local n = ActionSpellName(b.action)
        local k = n and R.names[n]
        if k then
            found = found + 1
            local u, nm = IsUsableAction(b.action)
            Azaath:Print(format("  %s [%s] botão %s: usável=%s semRecurso=%s proc=%s",
                n, k, tostring(b.action), Show(u), Show(nm), tostring(R.procs[n] or false)))
        end
    end
    if found == 0 then
        local list = {}
        for n, k in pairs(R.names) do list[#list + 1] = n .. "(" .. k .. ")" end
        Azaath:Print("  Nenhuma habilidade acompanhada nas barras. Conhecidas: " .. table.concat(list, ", "))
    end
end
