--[[----------------------------------------------------------------------------
    AzaathUI - Olho de Azaath / Commands.lua
    /olho e seus subcomandos, a tecla de interação do jogo e o /olho status.
    Os comandos aceitam o nome em inglês ou o do idioma escolhido (L.COMMANDS),
    com ou sem acento.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local ns = Azaath.OlhoNS
local L = ns.L
local M = ns.M
local S, N, G, W = ns.Sense, ns.Native, ns.Glow, ns.Watch
local SafeCall, Flag, Fold, Print, NameKey = ns.SafeCall, ns.Flag, ns.Fold, ns.Print, ns.NameKey

local pairs, ipairs, tostring, tonumber, type = pairs, ipairs, tostring, tonumber, type
local floor = math.floor

--------------------------------------------------------------------------------
-- Idioma e apelidos
--------------------------------------------------------------------------------

local alias = {} -- palavra digitada (sem acento) -> comando, efeito ou fonte em inglês

local function EffectName(key) return L["EFFECT_" .. key:upper()] end
local function CatLabel(cat) return L["CATEGORY_" .. cat:upper()] end
local function FontLabel(key) return ns.FontName(key) or L.FONT_GAME end

function ns.ApplyLanguage()
    ns.UseLanguage(ns.db.language)
    wipe(alias)
    for word, cmd in pairs(L.COMMANDS) do alias[Fold(word)] = cmd end
    for _, key in ipairs(ns.EFFECT_ORDER) do alias[Fold(EffectName(key))] = key end
    for _, key in ipairs(ns.FontChoices()) do alias[Fold(FontLabel(key))] = key end
end

ns.OnOption("language", function()
    ns.ApplyLanguage()
    W.ForgetReport()
    G.RefreshTag(nil, nil)
    if ns.Retext then ns.Retext() end
end)

local function LanguageLabel()
    local code = ns.db.language
    return code == "auto" and L.LANGUAGE_AUTO or ns.LOCALES[code].LANGUAGE_NAME
end

--------------------------------------------------------------------------------
-- Tecla de interação: o Olho não tem atalho próprio (interagir é ação protegida);
-- ele ajuda a configurar o "Interagir com o alvo" do jogo.
--------------------------------------------------------------------------------

local ACTION = "INTERACTTARGET"

local function Context()
    return C_KeyBindings and C_KeyBindings.GetBindingContextForAction
        and SafeCall(C_KeyBindings.GetBindingContextForAction, ACTION)
end

function ns.GetInteractKey()
    return (GetBindingKey(ACTION, nil, Context()))
end

function ns.KeyText(key)
    return GetBindingText and GetBindingText(key) or key
end

-- outro atalho que já usa esta tecla, ou nil
function ns.KeyOwner(key)
    local action = GetBindingAction(key, nil, Context())
    if type(action) ~= "string" or action == "" or action == ACTION then return nil end
    return _G["BINDING_NAME_" .. action] or action
end

-- põe `key` como tecla principal de interação (nil tira); devolve false e o motivo
function ns.SetInteractKey(key)
    if InCombatLockdown() then return false, L.MSG_KEY_COMBAT end
    local ctx = Context()
    local k1, k2 = GetBindingKey(ACTION, nil, ctx)
    if k1 then SetBinding(k1, nil, ctx) end
    if k2 then SetBinding(k2, nil, ctx) end
    local ok = key == nil or SetBinding(key, ACTION, ctx)
    if not ok and k1 then SetBinding(k1, ACTION, ctx) end
    if k2 and k2 ~= key then SetBinding(k2, ACTION, ctx) end
    local save = SaveBindings or AttemptToSaveBindings
    if save and GetCurrentBindingSet then pcall(save, GetCurrentBindingSet()) end
    ns.Notify()
    if not ok then return false, L.MSG_KEY_REFUSED:format(key) end
    return true
end

--------------------------------------------------------------------------------
-- Ignorar o objeto mirado
--------------------------------------------------------------------------------

local UNIGNORE_WINDOW = 10 -- segundos para confirmar que quer voltar a ver um objeto
local unignoreAsk

function ns.IgnoreTarget()
    local name = S.TargetObjectName()
    if not name then Print(L.MSG_IGNORE_NO_TARGET) return end
    local key = NameKey(name)
    local unnamed = key == ""
    local shown = unnamed and L.NAME_UNNAMED or name
    local now = GetTime()
    local asked = unignoreAsk
    unignoreAsk = nil
    -- já ignorado: o primeiro pedido só avisa (ignorar vale para todos com esse nome)
    if ns.db.ignored[key] and not (asked and asked.key == key and now - asked.at <= UNIGNORE_WINDOW) then
        unignoreAsk = { key = key, at = now }
        Print(L.MSG_IGNORED_ALREADY:format(shown))
        return
    end
    local nowIgnored = ns.ToggleIgnored(name, unnamed)
    Print((nowIgnored and L.MSG_IGNORED or L.MSG_UNIGNORED):format(shown))
end

--------------------------------------------------------------------------------
-- Comandos
--------------------------------------------------------------------------------

local C = {}

local function Help()
    Print(L.HELP_HEADER)
    for _, line in ipairs(L.HELP) do print("  " .. ns.FillLimits(line)) end
end

-- "ore", "minério"... -> categoria em inglês
local function AsCategory(word)
    local w = alias[word] or word
    return ns.ACCOUNT_DEFAULTS.colors[w] and w or nil
end

-- "/olho size ore 150": categoria opcional antes do valor
local function SplitCategory(arg)
    local first, rest = arg:match("^(%S*)%s*(.-)$")
    local cat = AsCategory(first)
    if cat then return cat, rest end
    return nil, arg
end

local function Scoped(text, cat)
    return cat and L.OF_CATEGORY:format(text, CatLabel(cat)) or text
end

C[""] = function() if ns.ToggleMenu then ns.ToggleMenu() end end
C.menu = C[""]
C.on = function() ns.Toggle(true) end
C.off = function() ns.Toggle(false) end
C.preview = function() if ns.TogglePreview then ns.TogglePreview() end end
C.help = Help

function C.minimap()
    if not ns.ShowMinimapButton then return end
    ns.ShowMinimapButton(ns.db.minimap.hide)
    Print(L.SETTING:format(L.MINIMAP, Flag(not ns.db.minimap.hide)))
end

function C.effect(arg)
    local cat, rest = SplitCategory(arg)
    local key = alias[rest] or rest
    if key ~= "fallback" and ns.EFFECTS[key] then
        ns.SetOption("effect", key, cat)
        Print(L.SETTING:format(Scoped(L.EFFECT, cat), EffectName(key)))
        return
    end
    local names = {}
    for i, k in ipairs(ns.EFFECT_ORDER) do names[i] = EffectName(k) end
    Print(L.MSG_EFFECTS:format(table.concat(names, ", "), EffectName(ns.Look(cat, "effect"))))
end

function C.color(arg)
    local cat, rest = SplitCategory(arg)
    if not cat then return false end
    local r, g, b = rest:match("^#?(%x%x)(%x%x)(%x%x)$")
    if r then
        ns.SetColor(cat, tonumber(r, 16) / 255, tonumber(g, 16) / 255, tonumber(b, 16) / 255)
    elseif (alias[rest] or rest) == "default" then
        ns.SetColor(cat)
    elseif rest ~= "" then
        return false
    end
    local cr, cg, cb = ns.GetColor(cat)
    local hex = ("%02x%02x%02x"):format(floor(cr * 255 + 0.5), floor(cg * 255 + 0.5), floor(cb * 255 + 0.5))
    Print(L.MSG_COLOR:format(CatLabel(cat), "|cff" .. hex .. hex .. "|r"))
end

function C.shared(arg)
    local cat = AsCategory(arg)
    if not cat then return false end
    ns.ClearOwnSettings(cat)
    Print(L.MSG_SHARED:format(CatLabel(cat)))
end

local function Number(key, label, fmt)
    return function(arg)
        local cat, rest = SplitCategory(arg)
        local n = tonumber(rest)
        if not n then return false end
        ns.SetOption(key, n, cat)
        Print(L.SETTING:format(Scoped(L[label], cat), (fmt and L[fmt] or "%d"):format(ns.GetOption(key, cat))))
    end
end
C.size = Number("size", "SIZE")
C.intensity = Number("intensity", "INTENSITY", "FORMAT_PERCENT")
C.offset = Number("offsetY", "OFFSET")
C.text = Number("textSize", "TEXT_SIZE", "FORMAT_PERCENT")

function C.font(arg)
    local cat, rest = SplitCategory(arg)
    local key = alias[rest] or rest
    if key == "default" then key = "game" end
    for _, choice in ipairs(ns.FontChoices()) do
        if choice == key then
            ns.SetOption("textFont", key, cat)
            Print(L.SETTING:format(Scoped(L.FONT, cat), FontLabel(key)))
            return
        end
    end
    local names = {}
    for i, choice in ipairs(ns.FontChoices()) do names[i] = FontLabel(choice) end
    Print(L.MSG_FONTS:format(table.concat(names, ", "), FontLabel(ns.Look(cat, "textFont"))))
end

local function LookSwitch(key, label)
    return function(arg)
        local cat, rest = SplitCategory(arg)
        if rest ~= "" then return false end
        ns.SetOption(key, not ns.Look(cat, key), cat)
        Print(L.SETTING:format(Scoped(L[label], cat), Flag(ns.Look(cat, key))))
    end
end
C.fade = LookSwitch("followAlpha", "FADE")
C.name = LookSwitch("showName", "SHOW_NAME")
C.icon = LookSwitch("showIcon", "SHOW_ICON")

local function Switch(key, msg)
    return function()
        ns.SetOption(key, not ns.GetOption(key))
        Print(L[msg]:format(Flag(ns.GetOption(key))))
    end
end
C.combat = Switch("hideInCombat", "MSG_HIDE_COMBAT")
C.instance = Switch("hideInInstance", "MSG_HIDE_INSTANCE")
C.unavailable = Switch("hideLocked", "MSG_HIDE_LOCKED")
C.profession = Switch("hideUntrained", "MSG_HIDE_UNTRAINED")
C.glowonly = Switch("glowOnly", "MSG_GLOW_ONLY")

function C.exclusive()
    ns.SetOption("exclusive", not ns.db.exclusive)
    Print(ns.db.exclusive and L.MSG_EXCLUSIVE_ON or L.MSG_EXCLUSIVE_OFF)
end

function C.ignore(arg)
    if arg == "" then
        ns.IgnoreTarget()
    elseif arg == "list" then
        local names = ns.IgnoredNames()
        Print(#names > 0 and L.MSG_IGNORE_LIST:format(table.concat(names, ", ")) or L.MSG_IGNORE_EMPTY)
    elseif arg == "clear" then
        ns.ClearIgnored()
        Print(L.MSG_IGNORE_EMPTY)
    else
        local before = ns.db.ignored[NameKey(arg)]
        local now = ns.ToggleIgnored(arg)
        if now == nil then return false end
        Print((now and L.MSG_IGNORED or L.MSG_UNIGNORED):format(before or arg))
    end
end

function C.silhouette(arg)
    local scale, shift = arg:match("^(%d+)%s*(%-?%d*)$")
    local cat = AsCategory(arg)
    if arg == "" or cat then
        ns.SetOption("silhouette", not ns.Look(cat, "silhouette"), cat)
        local on = ns.Look(cat, "silhouette")
        if cat then
            Print(L.SETTING:format(Scoped(L.SILHOUETTE, cat), Flag(on)))
        else
            Print(on and L.MSG_SILHOUETTE_ON or L.MSG_SILHOUETTE_OFF)
        end
        local fail = ns.SilhouetteFailure()
        if on and fail then Print(L.MSG_CUTOUT_UNAVAILABLE:format(fail)) end
    elseif arg == "show" then
        ns.ShowZone(not ns.IsZoneShown())
        local fail = ns.SilhouetteFailure()
        Print(fail and L.MSG_CUTOUT_UNAVAILABLE:format(fail) or (ns.IsZoneShown() and L.MSG_ZONE_SHOWN or L.MSG_ZONE_HIDDEN))
    elseif scale then
        ns.SetOption("bodyScale", tonumber(scale))
        if shift ~= "" and shift ~= "-" then ns.SetOption("bodyShift", tonumber(shift)) end
        Print(L.MSG_SILHOUETTE_VALUES:format(ns.cdb.bodyScale, ns.cdb.bodyShift))
    else
        Print(ns.FillLimits(L.MSG_SILHOUETTE_USAGE))
    end
end

function C.range(_, n)
    if not n then return false end
    ns.SetOption("range", n)
    local applied = tonumber(N.Get("SoftTargetInteractRange"))
    if N.Pending() == "apply" then
        Print(L.MSG_RANGE_COMBAT:format(ns.db.range))
    elseif ns.db.enabled and applied and applied ~= N.WantedRange() then
        Print(L.MSG_RANGE_CLIENT:format(ns.db.range, tostring(applied)))
    else
        Print(L.MSG_RANGE:format(ns.db.range))
    end
end

function C.arc(_, n)
    if not n then return false end
    ns.SetOption("arc", n)
    Print(L.SETTING:format(L.DIRECTION, L["ARC_" .. ns.db.arc]))
end

function C.key(arg)
    if arg ~= "" then
        local key = arg ~= "none" and arg:upper() or nil
        local owner = key and ns.KeyOwner(key)
        local ok, why = ns.SetInteractKey(key)
        if not ok then Print(why) return end
        if owner then Print(L.MSG_KEY_REPLACED:format(ns.KeyText(key), owner)) end
    end
    local key = ns.GetInteractKey()
    Print(L.SETTING:format(L.KEY, key and ns.KeyText(key) or L.KEY_NONE))
end

for _, cat in ipairs(ns.CATEGORY_ORDER) do
    C[cat] = function()
        ns.SetCategory(cat, not ns.IsCategoryShown(cat))
        Print(L.SETTING:format(CatLabel(cat), Flag(ns.IsCategoryShown(cat))))
    end
end

-- duas profissões de coleta: alterna os rastreamentos de ervas e minérios
function C.switch(arg, n)
    if n then
        ns.SetOption("nodeSwitchYards", n)
        Print(L.SETTING:format(L.NODE_SWITCH_YARDS, L.FORMAT_RANGE:format(ns.cdb.nodeSwitchYards)))
    elseif arg == "" then
        ns.SetOption("nodeSwitch", not ns.cdb.nodeSwitch)
        Print(L.SETTING:format(L.NODE_SWITCH, Flag(ns.cdb.nodeSwitch)))
    else
        return false
    end
end

function C.language(arg)
    local pick
    if arg == "auto" or arg == Fold(L.LANGUAGE_AUTO) then pick = "auto" end
    for code, texts in pairs(ns.LOCALES) do
        if arg == code:lower() or arg == code:sub(1, 2) or arg == Fold(texts.LANGUAGE_NAME) then pick = code end
    end
    if pick then ns.SetOption("language", pick) end
    Print(L.SETTING:format(L.LANGUAGE, LanguageLabel()))
end

function C.debug()
    ns.SetOption("debug", not ns.db.debug)
    Print(L.SETTING:format(L.DEBUG, Flag(ns.db.debug)))
end

function C.objectives()
    S.QuestsChanged()
    local list, titles = S.Objectives()
    Print(L.OBJECTIVES_HEADER:format(#list))
    for _, o in ipairs(list) do print("  " .. o.text .. (o.item and "" or L.OBJECTIVES_NOT_ITEM)) end
    for name, title in pairs(ns.db.questObjects) do
        if titles[title] then print("  " .. L.OBJECTIVES_LEARNED:format(name, title)) end
    end
end

function C.status()
    local db, cdb = ns.db, ns.cdb
    local version, build = GetBuildInfo()
    Print(L.STATUS_CLIENT:format(tostring(version), tostring(build), tostring(GetLocale()), LanguageLabel()))
    for _, list in ipairs({ N.MANAGED, N.WATCHED }) do
        for _, name in ipairs(list) do
            local v = N.Get(name)
            local d = C_CVar and C_CVar.GetCVarDefault and SafeCall(C_CVar.GetCVarDefault, name)
            print(("  %s = %s%s"):format(name, v == nil and L.STATUS_CVAR_UNKNOWN or tostring(v),
                d and L.STATUS_CVAR_DEFAULT:format(tostring(d)) or ""))
        end
    end
    local gate = N.GateState()
    print("  " .. L.STATUS_EXPECTED:format(N.WantedRange(), db.arc))
    print("  " .. L.STATUS_GATE:format(Flag(db.exclusive), gate == nil and "?" or (gate and L.GATE_OPEN or L.GATE_CLOSED)))
    print("  " .. L.STATUS_GLOW_ONLY:format(Flag(db.glowOnly), Flag(N.Plumber())))
    local fail = ns.SilhouetteFailure()
    print("  " .. L.STATUS_SILHOUETTE:format(fail and L.STATUS_UNAVAILABLE:format(fail) or Flag(db.silhouette)))
    print("  " .. L.STATUS_DIRECT:format(S.DirectWorks() and L.YES or L.STATUS_NOT_YET))
    print("  " .. L.STATUS_RANGE_API:format(Flag(UnitIsInInteractRange ~= nil)))
    local fishing, channel, icon = S.Fishing()
    print("  " .. L.STATUS_LINE:format(Flag(fishing), channel and ("%s, %s"):format(channel, tostring(icon)) or L.NAME_NONE))
    print("  " .. L.STATUS_TRAINED:format(Flag(db.hideUntrained), Flag(S.Trained("herb")), Flag(S.Trained("ore"))))
    print("  " .. L.STATUS_HIDE:format(Flag(db.hideInCombat), Flag(db.hideInInstance), Flag(db.hideLocked), Flag(W.Paused())))
    local shown, own = {}, {}
    for _, cat in ipairs(ns.CATEGORY_ORDER) do
        if cdb.categories[cat] then shown[#shown + 1] = L["NAME_" .. cat:upper()] end
        if ns.HasOwnSettings(cat) then own[#own + 1] = L["NAME_" .. cat:upper()] end
    end
    print("  " .. L.STATUS_OBJECTS:format(#shown > 0 and table.concat(shown, ", ") or L.NAME_NONE, #ns.IgnoredNames()))
    print("  " .. L.STATUS_OWN:format(#own > 0 and table.concat(own, ", ") or L.NAME_NONE))
    local key = ns.GetInteractKey()
    print("  " .. L.STATUS_KEY:format(key and ns.KeyText(key) or L.KEY_NONE))
    local e = ns.EFFECTS[db.effect]
    print("  " .. L.STATUS_EFFECT:format(EffectName(db.effect),
        e.missing and L.TEXTURES_MISSING or (e.fx and L.TEXTURES_LOADED or L.TEXTURES_PENDING)))
end

function M:SlashCommand(input)
    local cmd, arg = Fold(input or ""):match("^%s*(%S*)%s*(.-)%s*$")
    local fn = C[alias[cmd] or cmd]
    if not fn or fn(alias[arg] or arg, tonumber(arg)) == false then Help() end
end

function M:OpenMenu()
    if ns.ToggleMenu then ns.ToggleMenu() end
end

if not SlashCmdList["OLHOAZAATH"] then
    SLASH_OLHOAZAATH1 = "/olho"
    SlashCmdList["OLHOAZAATH"] = function(input) M:SlashCommand(input) end
end
