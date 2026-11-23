--[[----------------------------------------------------------------------------
    AzaathUI - Compat.lua
    Camada de compatibilidade entre a API da 3.3.5a e o motor moderno usado
    pelo WoW Forever (1.60.x, Interface 16001, projeto "Camelot").

    Carregado ANTES do Core: os módulos chamam as funções daqui em vez das
    globais que mudaram de nome/assinatura. Cada função detecta o que existe
    no cliente (sem depender de número de versão), então o addon segue
    funcionando nos dois mundos.

    Principais diferenças tratadas:
      * SetBackdrop só existe em frames com BackdropTemplate (Mixin sob demanda)
      * SetGradientAlpha -> SetGradient(orient, CreateColor, CreateColor)
      * PlaySound recebe IDs (SOUNDKIT), não nomes
      * Cooldowns: "enable" pode ser 1 ou true; frame Cooldown precisa de template
      * RegisterEvent de evento inexistente gera erro no cliente moderno
      * Bolsas (C_Container), auras (C_UnitAuras), itens (C_Item), mapa (C_Map),
        rastreamento (C_Minimap), conjuração, formas, missões, livro de feitiços
------------------------------------------------------------------------------]]

local _, Azaath = ...
local _G = _G
local type, select, pcall, ipairs = type, select, pcall, ipairs

-- Motor moderno (BfA+ e clássicos modernos, incluindo o WoW Forever)
Azaath.IS_MODERN = (_G.BackdropTemplateMixin ~= nil)

-- Mostrar/esconder janela da Blizzard sem ShowUIPanel/HideUIPanel no cliente moderno:
-- chamados pelo addon, eles contaminam o gerenciador de painéis e a próxima janela
-- aberta por ele herda o taint (ex.: compra de espaço no banco bloqueada).
function Azaath.ShowPanel(f)
    if not f then return end
    if Azaath.IS_MODERN or not _G.ShowUIPanel then f:Show() else ShowUIPanel(f) end
end
function Azaath.HidePanel(f)
    if not (f and f:IsShown()) then return end
    if Azaath.IS_MODERN or not _G.HideUIPanel then f:Hide() else HideUIPanel(f) end
end

local API = {}
Azaath.API = API

--------------------------------------------------------------------------------
-- Widgets
--------------------------------------------------------------------------------
-- SetBackdrop em qualquer frame: no cliente moderno, aplica o BackdropTemplate
-- sob demanda (padrão usado pelos addons atuais).
function Azaath.SetBackdrop(frame, backdrop)
    if not frame.SetBackdrop and _G.BackdropTemplateMixin then
        Mixin(frame, BackdropTemplateMixin)
        if frame.OnBackdropSizeChanged then
            frame:HookScript("OnSizeChanged", frame.OnBackdropSizeChanged)
        end
    end
    frame:SetBackdrop(backdrop)
end

-- Degradê com alpha nas duas pontas
function Azaath.Gradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
    if tex.SetGradientAlpha then
        tex:SetGradientAlpha(orientation, r1, g1, b1, a1, r2, g2, b2, a2)
    else
        tex:SetGradient(orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
    end
end

-- Sons: nomes da 3.3.5 -> chaves do SOUNDKIT no cliente moderno
local SOUNDS = {
    igMainMenuOptionCheckBoxOn  = "IG_MAINMENU_OPTION_CHECKBOX_ON",
    igMainMenuOptionCheckBoxOff = "IG_MAINMENU_OPTION_CHECKBOX_OFF",
    igCharacterInfoOpen         = "IG_CHARACTER_INFO_OPEN",
    igCharacterInfoClose        = "IG_CHARACTER_INFO_CLOSE",
    igSpellBookOpen             = "IG_SPELLBOOK_OPEN",
    igSpellBookClose            = "IG_SPELLBOOK_CLOSE",
    igAbiliityPageTurn          = "IG_ABILITY_PAGE_TURN",
}
function Azaath.PlaySound(name)
    if _G.SOUNDKIT then
        local key = SOUNDS[name]
        local id = key and SOUNDKIT[key]
        if id then PlaySound(id) end
    else
        PlaySound(name)
    end
end

-- "enable" de cooldowns: 1 (antigo) ou true (moderno), seguro contra secret values
function Azaath.IsOn(v)
    if v == nil or Azaath.IsSecret(v) then return false end
    return v == 1 or v == true
end

-- Valores secretos (motor 12.x, usado pelo WoW Forever): vida/recurso de
-- unidades, durações de auras etc. podem vir como "secret number", "secret boolean" etc.
-- Código de addon pode repassá-los a widgets (StatusBar:SetValue, FontString:SetText),
-- mas NÃO pode compará-los nem testá-los logicamente (if secret_bool then ...).
local issecret = _G.issecretvalue or _G.issecret or _G.issecretvariable
function Azaath.IsSecret(v)
    if v == nil then return false end
    if issecret then
        local ok, res = pcall(issecret, v)
        if ok and res then return true end
    end
    local t = type(v)
    if t == "boolean" then
        local ok = pcall(function() if v then end end)
        return not ok
    elseif t == "number" then
        local ok = pcall(function() return v > 0 end)
        return not ok
    elseif t == "string" then
        local ok = pcall(function() return #v end)
        return not ok
    end
    return false
end
function Azaath.AnySecret(...)
    for i = 1, select("#", ...) do
        if Azaath.IsSecret((select(i, ...))) then return true end
    end
    return false
end

-- Proteção contra crash de secret value em HealthBar_OnValueChanged (cliente moderno / 12.x)
local hookedHealthBar = false
local function ProtectHealthBarOnValueChanged()
    if not hookedHealthBar and type(_G.HealthBar_OnValueChanged) == "function" then
        hookedHealthBar = true
        local orig = _G.HealthBar_OnValueChanged
        _G.HealthBar_OnValueChanged = function(self, value, ...)
            if Azaath.IsSecret(value) then return end
            return orig(self, value, ...)
        end
    end
end
ProtectHealthBarOnValueChanged()
Azaath.ProtectHealthBarOnValueChanged = ProtectHealthBarOnValueChanged

-- Registra evento sem quebrar se ele não existir neste cliente
function Azaath.SafeRegister(frame, event)
    local ok = pcall(frame.RegisterEvent, frame, event)
    return ok
end

--------------------------------------------------------------------------------
-- Addon / itens
--------------------------------------------------------------------------------
API.GetAddOnMetadata   = (_G.C_AddOns and C_AddOns.GetAddOnMetadata) or _G.GetAddOnMetadata
API.GetItemInfo        = (_G.C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
API.GetItemInfoInstant = (_G.C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
API.GetItemQualityColor = (_G.C_Item and C_Item.GetItemQualityColor) or _G.GetItemQualityColor
API.GetItemCooldown    = (_G.C_Container and C_Container.GetItemCooldown) or (_G.C_Item and C_Item.GetItemCooldown) or _G.GetItemCooldown

function API.MaxLevel()
    if _G.GetMaxPlayerLevel then return GetMaxPlayerLevel() end
    if _G.MAX_PLAYER_LEVEL_TABLE and _G.GetAccountExpansionLevel then
        return MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()] or 80
    end
    return 80
end

--------------------------------------------------------------------------------
-- Bolsas
--------------------------------------------------------------------------------
local CC = _G.C_Container
API.GetContainerNumSlots     = (CC and CC.GetContainerNumSlots) or _G.GetContainerNumSlots
API.GetContainerNumFreeSlots = (CC and CC.GetContainerNumFreeSlots) or _G.GetContainerNumFreeSlots
API.GetContainerItemLink     = (CC and CC.GetContainerItemLink) or _G.GetContainerItemLink
API.GetContainerItemCooldown = (CC and CC.GetContainerItemCooldown) or _G.GetContainerItemCooldown
API.UseContainerItem         = (CC and CC.UseContainerItem) or _G.UseContainerItem
API.PickupContainerItem      = (CC and CC.PickupContainerItem) or _G.PickupContainerItem
API.SplitContainerItem       = (CC and CC.SplitContainerItem) or _G.SplitContainerItem
API.ShowContainerSellCursor  = (CC and CC.ShowContainerSellCursor) or _G.ShowContainerSellCursor

-- Normalizado: texture, count, locked, quality
function API.GetContainerItemInfo(bag, slot)
    if CC and CC.GetContainerItemInfo then
        local info = CC.GetContainerItemInfo(bag, slot)
        if not info then return nil end
        return info.iconFileID, info.stackCount, info.isLocked, info.quality
    end
    local texture, count, locked, quality = GetContainerItemInfo(bag, slot)
    return texture, count, locked, quality
end

-- Normalizado: isQuestItem, questID, isActive (questID sem isActive = inicia missão)
function API.GetContainerItemQuestInfo(bag, slot)
    local fn = (CC and CC.GetContainerItemQuestInfo) or _G.GetContainerItemQuestInfo
    if not fn then return false, nil, false end
    local ok, a, b, c = pcall(fn, bag, slot)
    if not ok then return false, nil, false end
    if type(a) == "table" then
        return a.isQuestItem and true or false, a.questID, a.isActive and true or false
    end
    return a and true or false, b, c and true or false
end

--------------------------------------------------------------------------------
-- Saque (Loot)
--------------------------------------------------------------------------------
API.GetNumLootItems = _G.GetNumLootItems
API.GetLootSlotLink = _G.GetLootSlotLink
API.LootSlot        = _G.LootSlot
API.CloseLoot       = _G.CloseLoot

-- Normalizado: texture, item, quantity, quality, isLocked, isQuestItem, currencyID
function API.GetLootSlotInfo(slot)
    if not GetLootSlotInfo then return nil end
    if Azaath.IS_MODERN then
        local ok, texture, item, quantity, currencyID, quality, isLocked, isQuestItem = pcall(GetLootSlotInfo, slot)
        if not ok or not texture then return nil end
        if type(currencyID) == "number" and (quality == nil or type(quality) == "boolean") then
            quality = currencyID
            currencyID = nil
        end
        return texture, item, quantity, quality, isLocked, isQuestItem, currencyID
    end
    local ok, texture, item, quantity, quality, isLocked, isQuestItem = pcall(GetLootSlotInfo, slot)
    if not ok or not texture then return nil end
    return texture, item, quantity, quality, isLocked, isQuestItem, nil
end

--------------------------------------------------------------------------------
-- Auras / encantamentos
--------------------------------------------------------------------------------
-- Normalizado: name, icon, count, debuffType, duration, expiration, caster, stealable
-- Em combate (motor 12.x) nome/tipo/origem podem vir secretos: testar ou usar
-- como chave de tabela gera erro e a lista de buffs parava no meio. O nome só
-- serve para saber se a aura existe; tipo/origem secretos viram nil.
local function CleanAura(name, icon, count, dtype, duration, expiration, caster, stealable)
    if name == nil then return nil end
    if Azaath.IsSecret(name) then name = true end
    if Azaath.IsSecret(dtype) then dtype = nil end
    if Azaath.IsSecret(caster) then caster = nil end
    return name, icon, count, dtype, duration, expiration, caster, stealable
end

function API.UnitAura(unit, index, filter)
    if _G.C_UnitAuras and C_UnitAuras.GetAuraDataByIndex then
        local ok, a = pcall(C_UnitAuras.GetAuraDataByIndex, unit, index, filter)
        if not ok or type(a) ~= "table" then return nil end
        return CleanAura(a.name or a.auraInstanceID or true, a.icon, a.applications, a.dispelName,
            a.duration, a.expirationTime, a.sourceUnit, a.isStealable)
    end
    if Azaath.IS_MODERN then
        local ok, name, icon, count, dtype, duration, expiration, caster, stealable = pcall(UnitAura, unit, index, filter)
        if not ok then return nil end
        return CleanAura(name, icon, count, dtype, duration, expiration, caster, stealable)
    end
    local ok, name, _, icon, count, dtype, duration, expiration, caster, stealable = pcall(UnitAura, unit, index, filter)
    if not ok then return nil end
    return name, icon, count, dtype, duration, expiration, caster, stealable
end

-- Normalizado: hasMain, mainExpMS, mainCharges, hasOff, offExpMS, offCharges
-- "Tem encantamento?" secreto (combate): mantém o último valor conhecido, para
-- o ícone não sumir nem quebrar a lista de buffs com "if secret_bool".
local lastHasMain, lastHasOff = false, false
function API.GetWeaponEnchantInfo()
    local ok, hm, me, mc, ho, oe, oc
    if Azaath.IS_MODERN then
        local _
        ok, hm, me, mc, _, ho, oe, oc = pcall(GetWeaponEnchantInfo)
    else
        ok, hm, me, mc, ho, oe, oc = pcall(GetWeaponEnchantInfo)
    end
    if not ok then return lastHasMain, nil, nil, lastHasOff, nil, nil end
    if Azaath.IsSecret(hm) then hm = lastHasMain else hm = hm and true or false; lastHasMain = hm end
    if Azaath.IsSecret(ho) then ho = lastHasOff else ho = ho and true or false; lastHasOff = ho end
    return hm, me, mc, ho, oe, oc
end

-- Cancelar buffs é protegido no cliente moderno (só via SecureAuraHeader)
API.CanCancelAuras = not Azaath.IS_MODERN

--------------------------------------------------------------------------------
-- Unidades
--------------------------------------------------------------------------------
-- Alvo já "marcado" por outro jogador (cinza)
function API.IsTappedByOther(unit)
    if _G.UnitIsTapDenied then return UnitIsTapDenied(unit) end
    return UnitIsTapped(unit) and not UnitIsTappedByPlayer(unit)
end

function API.IsGroupLeader(unit)
    if _G.UnitIsGroupLeader then return UnitIsGroupLeader(unit) end
    if unit == "player" then return _G.IsPartyLeader and IsPartyLeader() end
    local idx = tonumber((unit or ""):match("%d"))
    return idx and _G.GetPartyLeaderIndex and GetPartyLeaderIndex() == idx
end

--------------------------------------------------------------------------------
-- Conjuração
--------------------------------------------------------------------------------
-- Normalizado: name, text, texture, startMS, endMS, castID, notInterruptible
function API.CastingInfo(unit)
    if Azaath.IS_MODERN then
        local name, text, texture, s, e, _, castID, notInt = UnitCastingInfo(unit)
        return name, text, texture, s, e, castID, notInt
    end
    local name, _, text, texture, s, e, _, castID, notInt = UnitCastingInfo(unit)
    if type(castID) ~= "number" then notInt, castID = castID, nil end
    return name, text, texture, s, e, castID, notInt
end

function API.ChannelInfo(unit)
    if Azaath.IS_MODERN then
        local name, text, texture, s, e, _, notInt = UnitChannelInfo(unit)
        return name, text, texture, s, e, nil, notInt
    end
    local name, _, text, texture, s, e, _, notInt = UnitChannelInfo(unit)
    return name, text, texture, s, e, nil, notInt
end

-- ID da conjuração nos eventos UNIT_SPELLCAST_* (argumentos após a unidade):
-- moderno (castGUID, spellID) · 3.3.5 (nome, posto, castID)
function API.EventCastID(...)
    if Azaath.IS_MODERN then return (...) end
    return (select(3, ...))
end

--------------------------------------------------------------------------------
-- Formas / posturas
--------------------------------------------------------------------------------
-- Normalizado: texture, isActive, isCastable
-- (3.3.5: texture, name, active, castable · moderno: icon, active, castable, spellID)
function API.ShapeshiftFormInfo(i)
    local a, b, c, d = GetShapeshiftFormInfo(i)
    if type(b) == "string" then return a, c, d end
    return a, b, c
end

--------------------------------------------------------------------------------
-- Barras de ação
--------------------------------------------------------------------------------
function API.ActionBarsLocked()
    if _G.LOCK_ACTIONBAR then return LOCK_ACTIONBAR == "1" end
    return GetCVar("lockActionBars") == "1"
end

--------------------------------------------------------------------------------
-- Mapa e minimapa
--------------------------------------------------------------------------------
API.NeedsMapSync = not (_G.C_Map and C_Map.GetBestMapForUnit)

function API.PlayerMapPosition()
    if _G.C_Map and C_Map.GetBestMapForUnit then
        local mapID = C_Map.GetBestMapForUnit("player")
        if not mapID then return nil end
        local pos = C_Map.GetPlayerMapPosition(mapID, "player")
        if pos then return pos:GetXY() end
        return nil
    end
    return GetPlayerMapPosition("player")
end

function API.ZonePVPInfo()
    if _G.C_PvP and C_PvP.GetZonePVPInfo then return C_PvP.GetZonePVPInfo() end
    return _G.GetZonePVPInfo and GetZonePVPInfo()
end

function API.NumTracking()
    if _G.C_Minimap and C_Minimap.GetNumTrackingTypes then return C_Minimap.GetNumTrackingTypes() end
    return _G.GetNumTrackingTypes and GetNumTrackingTypes() or 0
end

-- Normalizado: name, texture, active
function API.TrackingInfo(i)
    if _G.C_Minimap and C_Minimap.GetTrackingInfo then
        local r, t, a = C_Minimap.GetTrackingInfo(i)
        if type(r) == "table" then return r.name, r.texture, r.active end
        return r, t, a
    end
    local name, texture, active = GetTrackingInfo(i)
    return name, texture, active
end

function API.SetTracking(i, on)
    if _G.C_Minimap and C_Minimap.SetTracking then
        C_Minimap.SetTracking(i, on)
    else
        SetTracking(i, on)
    end
end

--------------------------------------------------------------------------------
-- Diálogos (gossip)
--------------------------------------------------------------------------------
local GI = _G.C_GossipInfo
-- API moderna (10.0+) seleciona por ID; anterior, por índice
local GOSSIP_BY_ID = GI and GI.SelectOptionByIndex ~= nil

function API.GossipText()
    if GI and GI.GetText then return GI.GetText() end
    return GetGossipText()
end

function API.CloseGossip()
    if GI and GI.CloseGossip then GI.CloseGossip() else CloseGossip() end
end

-- Listas normalizadas: { title, level, trivial, complete, select = function }
local function GroupByTitle(...)
    local list, cur = {}, nil
    for i = 1, select("#", ...) do
        local v = select(i, ...)
        if type(v) == "string" then
            cur = { title = v, n = 0, fields = {} }
            list[#list + 1] = cur
        elseif cur then
            cur.n = cur.n + 1
            cur.fields[cur.n] = v
        end
    end
    return list
end

function API.GossipAvailableQuests()
    local out = {}
    if GI and GI.GetAvailableQuests then
        for i, q in ipairs(GI.GetAvailableQuests() or {}) do
            local key = GOSSIP_BY_ID and q.questID or i
            out[#out + 1] = { title = q.title, level = q.questLevel, trivial = q.isTrivial,
                select = function() GI.SelectAvailableQuest(key) end }
        end
    else
        for i, q in ipairs(GroupByTitle(GetGossipAvailableQuests())) do
            out[#out + 1] = { title = q.title, level = tonumber(q.fields[1]), trivial = q.fields[2],
                select = function() SelectGossipAvailableQuest(i) end }
        end
    end
    return out
end

function API.GossipActiveQuests()
    local out = {}
    if GI and GI.GetActiveQuests then
        for i, q in ipairs(GI.GetActiveQuests() or {}) do
            local key = GOSSIP_BY_ID and q.questID or i
            local complete = q.isComplete
            if complete == nil and q.questID and _G.C_QuestLog and C_QuestLog.IsComplete then
                complete = C_QuestLog.IsComplete(q.questID)
            end
            out[#out + 1] = { title = q.title, level = q.questLevel, complete = complete,
                select = function() GI.SelectActiveQuest(key) end }
        end
    else
        for i, q in ipairs(GroupByTitle(GetGossipActiveQuests())) do
            out[#out + 1] = { title = q.title, level = tonumber(q.fields[1]), complete = q.fields[3],
                select = function() SelectGossipActiveQuest(i) end }
        end
    end
    return out
end

-- { text, kind ("gossip", "vendor", "binder"...), icon, select = function }
function API.GossipOptions()
    local out = {}
    if GI and GI.GetOptions then
        for i, o in ipairs(GI.GetOptions() or {}) do
            local id = o.gossipOptionID
            out[#out + 1] = {
                text = o.name,
                kind = o.type,
                icon = o.icon or ("Interface\\GossipFrame\\" .. (o.type or "gossip") .. "GossipIcon"),
                select = function()
                    if GOSSIP_BY_ID and id then GI.SelectOption(id) else GI.SelectOption(i) end
                end,
            }
        end
    else
        local flat = { GetGossipOptions() }
        for i = 1, #flat, 2 do
            local index = (i + 1) / 2
            out[#out + 1] = {
                text = flat[i],
                kind = flat[i + 1],
                icon = "Interface\\GossipFrame\\" .. (flat[i + 1] or "gossip") .. "GossipIcon",
                select = function() SelectGossipOption(index) end,
            }
        end
    end
    return out
end

--------------------------------------------------------------------------------
-- Registro de missões
--------------------------------------------------------------------------------
local QL = _G.C_QuestLog

-- Índices do registro das missões acompanhadas
function API.WatchedQuestIndexes()
    local out = {}
    if _G.GetNumQuestWatches and _G.GetQuestIndexForWatch then
        for w = 1, GetNumQuestWatches() do
            local idx = GetQuestIndexForWatch(w)
            if idx then out[#out + 1] = idx end
        end
    elseif QL and QL.GetNumQuestWatches then
        for w = 1, QL.GetNumQuestWatches() do
            local qid = QL.GetQuestIDForQuestWatchIndex(w)
            local idx = qid and QL.GetLogIndexForQuestID(qid)
            if idx then out[#out + 1] = idx end
        end
    end
    return out
end

-- Normalizado: title, level, tag, group, isHeader, isComplete(1/-1/nil), isDaily, questID
function API.QuestInfo(index)
    if _G.GetQuestLogTitle then
        if Azaath.IS_MODERN then
            local title, level, group, isHeader, _, isComplete, frequency, questID = GetQuestLogTitle(index)
            local daily = (_G.LE_QUEST_FREQUENCY_DAILY and frequency == LE_QUEST_FREQUENCY_DAILY)
                or (_G.Enum and Enum.QuestFrequency and frequency == Enum.QuestFrequency.Daily)
            return title, level, nil, group, isHeader, isComplete, daily, questID
        end
        return GetQuestLogTitle(index) -- 3.3.5: title, level, tag, group, isHeader, collapsed, complete, daily, id
    end
    local info = QL and QL.GetInfo(index)
    if not info then return nil end
    local complete = QL.IsComplete and QL.IsComplete(info.questID) and 1 or nil
    if QL.IsFailed and QL.IsFailed(info.questID) then complete = -1 end
    local daily = _G.Enum and Enum.QuestFrequency and info.frequency == Enum.QuestFrequency.Daily
    return info.title, info.level, nil, info.suggestedGroup, info.isHeader, complete, daily, info.questID
end

-- No 3.3.5 QuestInfo devolve 9 valores (com "collapsed"); padroniza para 8
function API.QuestInfo8(index)
    if _G.GetQuestLogTitle and not Azaath.IS_MODERN then
        local title, level, tag, group, isHeader, _, isComplete, isDaily, questID = GetQuestLogTitle(index)
        return title, level, tag, group, isHeader, isComplete, isDaily, questID
    end
    return API.QuestInfo(index)
end

-- { text, finished }
function API.QuestObjectives(index, questID)
    local out = {}
    if _G.GetNumQuestLeaderBoards and _G.GetQuestLogLeaderBoard then
        for j = 1, GetNumQuestLeaderBoards(index) or 0 do
            local text, _, finished = GetQuestLogLeaderBoard(j, index)
            if text and text ~= "" then out[#out + 1] = { text = text, finished = finished } end
        end
    elseif QL and QL.GetQuestObjectives and questID then
        for _, o in ipairs(QL.GetQuestObjectives(questID) or {}) do
            if o.text and o.text ~= "" then out[#out + 1] = { text = o.text, finished = o.finished } end
        end
    end
    return out
end

function API.QuestSpecialItem(index)
    if _G.GetQuestLogSpecialItemInfo then return GetQuestLogSpecialItemInfo(index) end
    return nil
end

function API.RemoveQuestWatch(index, questID)
    if _G.RemoveQuestWatch then
        RemoveQuestWatch(index)
    elseif QL and QL.RemoveQuestWatch and questID then
        QL.RemoveQuestWatch(questID)
    end
end

-- questID de uma posição do registro (clientes só com C_QuestLog)
local function QuestIDAt(index)
    local info = QL and QL.GetInfo and QL.GetInfo(index)
    return info and not info.isHeader and info.questID or nil
end

function API.IsQuestWatched(index)
    if _G.IsQuestWatched then return IsQuestWatched(index) end
    local qid = QuestIDAt(index)
    if qid and QL.GetQuestWatchType then return QL.GetQuestWatchType(qid) ~= nil end
    if qid and QL.IsQuestWatched then return QL.IsQuestWatched(qid) and true or false end
    return false
end

function API.AddQuestWatch(index)
    if _G.AddQuestWatch then
        AddQuestWatch(index)
        return
    end
    local qid = QuestIDAt(index)
    if qid and QL.AddQuestWatch then QL.AddQuestWatch(qid) end
end

function API.NumQuestWatches()
    if _G.GetNumQuestWatches then return GetNumQuestWatches() end
    return QL and QL.GetNumQuestWatches and QL.GetNumQuestWatches() or 0
end

function API.NumQuestLogEntries()
    if _G.GetNumQuestLogEntries then return (GetNumQuestLogEntries()) end
    return QL and QL.GetNumQuestLogEntries and (QL.GetNumQuestLogEntries()) or 0
end

function API.OpenQuest(index)
    if _G.QuestLog_OpenToQuest then
        QuestLog_OpenToQuest(index)
    elseif _G.QuestLogFrame then
        ShowUIPanel(QuestLogFrame)
        if _G.QuestLog_SetSelection then QuestLog_SetSelection(index) end
        if _G.QuestLog_Update then QuestLog_Update() end
    elseif _G.ToggleQuestLog then
        ToggleQuestLog()
    end
end

--------------------------------------------------------------------------------
-- Livro de feitiços
--------------------------------------------------------------------------------
local SB = _G.C_SpellBook
local BANK = _G.Enum and Enum.SpellBookSpellBank

-- "spell"/"pet" -> banco do C_SpellBook
local function Bank(book)
    if BANK then return (book == "pet") and BANK.Pet or BANK.Player end
    return book
end
local MODERN_BOOK = SB and SB.GetSpellBookItemName ~= nil

function API.SpellTabCount()
    if SB and SB.GetNumSpellBookSkillLines then return SB.GetNumSpellBookSkillLines() end
    return GetNumSpellTabs() or 0
end

-- Normalizado: name, offset, numSpells
function API.SpellTabInfo(tab)
    if SB and SB.GetSpellBookSkillLineInfo then
        local info = SB.GetSpellBookSkillLineInfo(tab)
        if not info then return nil, 0, 0 end
        return info.name, info.itemIndexOffset or 0, info.numSpellBookItems or 0
    end
    local name, _, offset, num = GetSpellTabInfo(tab)
    return name, offset or 0, num or 0
end

function API.SpellName(i, book)
    if MODERN_BOOK then return SB.GetSpellBookItemName(i, Bank(book)) end
    if _G.GetSpellBookItemName then return GetSpellBookItemName(i, book) end
    return GetSpellName(i, book)
end

function API.SpellTexture(i, book)
    if SB and SB.GetSpellBookItemTexture then return SB.GetSpellBookItemTexture(i, Bank(book)) end
    if _G.GetSpellBookItemTexture then return GetSpellBookItemTexture(i, book) end
    return GetSpellTexture(i, book)
end

function API.SpellIsPassive(i, book)
    if SB and SB.IsSpellBookItemPassive then return SB.IsSpellBookItemPassive(i, Bank(book)) end
    return IsPassiveSpell(i, book)
end

-- Normalizado: start, duration, enabled
function API.SpellCooldown(i, book)
    if SB and SB.GetSpellBookItemCooldown then
        local cd = SB.GetSpellBookItemCooldown(i, Bank(book))
        if not cd then return 0, 0, false end
        return cd.startTime, cd.duration, cd.isEnabled
    end
    return GetSpellCooldown(i, book)
end

function API.SpellLink(i, book)
    if SB and SB.GetSpellBookItemLink then return SB.GetSpellBookItemLink(i, Bank(book)) end
    return GetSpellLink(i, book)
end

function API.PickupSpell(i, book)
    if SB and SB.PickupSpellBookItem then return SB.PickupSpellBookItem(i, Bank(book)) end
    if _G.PickupSpellBookItem then return PickupSpellBookItem(i, book) end
    return PickupSpell(i, book)
end

function API.SetSpellTooltip(tooltip, i, book)
    if tooltip.SetSpellBookItem then
        tooltip:SetSpellBookItem(i, MODERN_BOOK and Bank(book) or book)
    else
        tooltip:SetSpell(i, book)
    end
end

function API.NumPetSpells()
    if SB and SB.HasPetSpells then return SB.HasPetSpells() or 0 end
    return HasPetSpells() or 0
end

function API.OpenDefaultSpellbook()
    if _G.ToggleSpellBook then
        ToggleSpellBook(BOOKTYPE_SPELL or "spell")
    elseif _G.PlayerSpellsUtil and PlayerSpellsUtil.ToggleSpellBookFrame then
        PlayerSpellsUtil.ToggleSpellBookFrame()
    end
end
