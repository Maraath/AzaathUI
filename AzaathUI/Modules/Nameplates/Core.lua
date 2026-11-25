--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Core.lua
    Núcleo compartilhado do sistema completo de placas de nome (Nameplates).
    Namespace: Azaath.NP
------------------------------------------------------------------------------]]

local _, Azaath = ...
local _G = _G
local type, pairs, ipairs, pcall, tostring, tonumber, select = type, pairs, ipairs, pcall, tostring, tonumber, select
local floor, ceil, max, min = math.floor, math.ceil, math.max, math.min
local wipe = wipe

local NP = {}
Azaath.NP = NP

NP.Elements = {}
NP.ElementOrder = {}
NP.ActivePlates = {}

function NP.RegisterElement(name, el)
    el.name = name
    NP.Elements[name] = el
    NP.ElementOrder[#NP.ElementOrder + 1] = el
end

-- Detecção segura de secret values (reaproveita Compat.lua + issecretvalue nativo)
local issecret = _G.issecretvalue or function() return false end
function NP.IsSecret(v)
    if v == nil then return false end
    if issecret(v) then return true end
    return Azaath.IsSecret(v)
end

function NP.Plain(v, fallback)
    if NP.IsSecret(v) then return fallback end
    return v
end

function NP.Truthy(v, fallback)
    if NP.IsSecret(v) then return fallback end
    return v and true or false
end

function NP.RGBA(t, fallbackAlpha)
    if type(t) ~= "table" then return 1, 1, 1, fallbackAlpha or 1 end
    return t[1] or 1, t[2] or 1, t[3] or 1, t[4] ~= nil and t[4] or (fallbackAlpha or 1)
end

function NP.CopyTable(src)
    if type(src) ~= "table" then return src end
    local out = {}
    for k, v in pairs(src) do
        out[k] = NP.CopyTable(v)
    end
    return out
end

function NP.MergeInto(dst, src)
    if type(dst) ~= "table" or type(src) ~= "table" then return dst end
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            NP.MergeInto(dst[k], v)
        else
            dst[k] = v
        end
    end
    return dst
end

-- Profiler leve para diagnóstico (/azplates perf)
local Perf = { on = false, data = {} }
NP.Perf = Perf
local dps = _G.debugprofilestop
local function PNow()
    local v = dps and dps()
    return type(v) == "number" and v or (_G.GetTime() * 1000)
end
Perf.Now = PNow
function Perf.Add(name, t0)
    local e = Perf.data[name]
    if not e then e = { 0, 0 }; Perf.data[name] = e end
    e[1] = e[1] + 1
    e[2] = e[2] + (PNow() - t0)
end
local function PerfDone(name, t0, ...)
    Perf.Add(name, t0)
    return ...
end
function Perf.Wrap(name, fn)
    if type(fn) ~= "function" then return fn end
    return function(...)
        if not Perf.on then return fn(...) end
        return PerfDone(name, PNow(), fn(...))
    end
end

-- Tipos de unidade e mapeamentos
NP.OOC_OF = {
    enemynpc    = "enemynpc_ooc",
    enemyplayer = "enemyplayer_ooc",
}
NP.NAME_ONLY_OF = {
    friendlyplate    = "friendlyplayer",
    npcplate         = "friendlynpc",
    enemynpc_ooc     = "enemynpc",
    enemyplayer_ooc  = "enemyplayer",
}
NP.SHARED_KEYS = {
    general = true, style = true, colors = true, debug = true, unitOverrides = true, customDebuffs = true,
}

local FRIENDLY_PLATE_MAP = {
    ["units.friendlyplayer."] = "units.friendlyplate.",
    ["unitOverrides.friendlyplayer."] = "unitOverrides.friendlyplate.",
}
function NP.FriendlyPlatePath(path)
    if type(path) ~= "string" then return nil end
    for k, rep in pairs(FRIENDLY_PLATE_MAP) do
        if path:sub(1, #k) == k then
            return rep .. path:sub(#k + 1)
        end
    end
    return nil
end

-- Perfis por tipo de unidade (mescla profile global + unitOverrides[kind])
local mergedCache = {}
function NP.InvalidateUnitProfiles()
    wipe(mergedCache)
end

function NP.ActiveProfile()
    return NP.db
end

function NP.Prof(f)
    if f and f.isPreview and NP.previewProfile then
        return NP.previewProfile
    end
    local kind = f and (f.profKind or f.kind)
    return NP.UnitProfile(kind)
end

function NP.UnitProfile(kind)
    if not NP.db then return NP.DEFAULTS end
    local m = kind and mergedCache[kind]
    if m then return m end
    local p = NP.db
    local d = NP.DEFAULTS
    m = {}
    for k in pairs(d) do m[k] = p[k] end
    for k, v in pairs(p) do m[k] = v end
    local o = kind and p.unitOverrides and p.unitOverrides[kind]
    if o then
        local eff = NP.CopyTable((d.unitOverrides and d.unitOverrides[kind]) or {})
        NP.MergeInto(eff, o)
        for k, v in pairs(eff) do
            if type(v) == "table" and type(p[k]) == "table" then
                local copy = NP.CopyTable(p[k])
                NP.MergeInto(copy, v)
                m[k] = copy
            else
                m[k] = v
            end
        end
    end
    if kind then mergedCache[kind] = m end
    return m
end

-- Âncoras (13 pontos: fora e dentro da barra)
NP.ANCHOR_SIDES = {
    [1]  = { "BOTTOMLEFT",  "TOPLEFT",     "LEFT",   "Acima (Esq.)" },
    [2]  = { "RIGHT",       "LEFT",        "RIGHT",  "Esquerda" },
    [3]  = { "LEFT",        "LEFT",        "LEFT",   "Dentro (Esq.)" },
    [4]  = { "TOP",         "BOTTOM",      "CENTER", "Abaixo" },
    [5]  = { "LEFT",        "RIGHT",       "LEFT",   "Direita" },
    [6]  = { "LEFT",        "RIGHT",       "LEFT",   "Direita (Fora)" },
    [7]  = { "TOPLEFT",     "BOTTOMLEFT",  "LEFT",   "Abaixo (Esq.)" },
    [8]  = { "BOTTOM",      "TOP",         "CENTER", "Acima (Centro)" },
    [9]  = { "CENTER",      "CENTER",      "CENTER", "Centro" },
    [10] = { "BOTTOMLEFT",  "TOPLEFT",     "LEFT",   "Topo (Esq.)" },
    [11] = { "RIGHT",       "RIGHT",       "RIGHT",  "Dentro (Dir.)" },
    [12] = { "TOP",         "TOP",         "CENTER", "Dentro (Topo)" },
    [13] = { "BOTTOM",      "BOTTOM",      "CENTER", "Dentro (Base)" },
}
NP.ANCHOR_ORDER = { 1, 8, 2, 9, 6, 7, 4, 3, 11, 12, 13 }

-- Pixel snap para nitidez de textos e bordas
function NP.PxSnap(f, v, isSize)
    v = tonumber(v) or 0
    if not (NP.db and NP.db.general and NP.db.general.pixelSnap ~= false) then
        return v
    end
    local ok, eff = pcall(f.GetEffectiveScale, f)
    local physH = _G.GetPhysicalScreenSize and select(2, _G.GetPhysicalScreenSize())
    if not ok or type(eff) ~= "number" or NP.IsSecret(eff) or eff <= 0 or type(physH) ~= "number" or physH <= 0 then
        return v
    end
    local px = (768 / physH) / eff
    if px <= 0 then return v end
    local res = floor(v / px + 0.5) * px
    if isSize and v > 0 and res < px then res = px end
    return res
end

function NP.PixelRound(frame)
    if not frame then return end
    if frame.SetSnapToPixelGrid then pcall(frame.SetSnapToPixelGrid, frame, true) end
    if frame.SetRoundLayoutToNearestPixel then pcall(frame.SetRoundLayoutToNearestPixel, frame, true) end
end

function NP.SetAnchor(region, anchor, rel)
    if not region or not rel then return end
    anchor = anchor or {}
    local side = NP.ANCHOR_SIDES[anchor.side or 9] or NP.ANCHOR_SIDES[9]
    local x = tonumber(anchor.x) or 0
    local y = tonumber(anchor.y) or 0
    region:ClearAllPoints()
    region:SetPoint(side[1], rel, side[2], x, y)
    if region.SetJustifyH then
        region:SetJustifyH(side[3])
    end
end

-- Ordem das classes e cores de classe
local EXCLUDE_CLASS = { ADVENTURER = true, TRAVELER = true }
function NP.ClassOrder()
    if type(_G.CLASS_SORT_ORDER) == "table" and #_G.CLASS_SORT_ORDER > 0 then
        return _G.CLASS_SORT_ORDER
    end
    local t = {}
    for cls in pairs(_G.RAID_CLASS_COLORS or {}) do
        if not EXCLUDE_CLASS[cls] then t[#t + 1] = cls end
    end
    table.sort(t)
    return t
end

function NP.GameClassColors()
    local out = {}
    local src = _G.CUSTOM_CLASS_COLORS or _G.RAID_CLASS_COLORS or {}
    for _, cls in ipairs(NP.ClassOrder()) do
        local c = src[cls]
        if c then out[cls] = { c.r, c.g, c.b, 1 } end
    end
    return out
end

-- Classes sociais / grupo reutilizáveis
function NP.IsGroupMate(unit)
    if not unit then return false end
    if _G.UnitPlayerOrPetInParty and NP.Truthy(_G.UnitPlayerOrPetInParty(unit), false) then return true end
    if _G.UnitPlayerOrPetInRaid and NP.Truthy(_G.UnitPlayerOrPetInRaid(unit), false) then return true end
    if _G.UnitInParty and NP.Truthy(_G.UnitInParty(unit), false) then return true end
    if _G.UnitInRaid and NP.Truthy(_G.UnitInRaid(unit), false) then return true end
    return false
end

function NP.IsGuildMate(unit)
    if not unit or not _G.IsInGuild or not _G.IsInGuild() then return false end
    local ok, isSame = pcall(function()
        local myG = _G.GetGuildInfo("player")
        local theirG = _G.GetGuildInfo(unit)
        if NP.IsSecret(myG) or NP.IsSecret(theirG) then return false end
        return myG and theirG and myG == theirG
    end)
    return ok and isSame or false
end

-- Helper simples para curvas booleanas (seguro para valores secretos)
function NP.EvalBool(cond, yesVal, noVal)
    if _G.C_CurveUtil and _G.C_CurveUtil.EvaluateColorValueFromBoolean then
        return _G.C_CurveUtil.EvaluateColorValueFromBoolean(cond, yesVal, noVal)
    end
    return cond and yesVal or noVal
end
