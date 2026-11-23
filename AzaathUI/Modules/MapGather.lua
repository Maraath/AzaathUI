--[[----------------------------------------------------------------------------
    AzaathUI - Modules/MapGather.lua
    Ervas e minérios para o mapa-múndi (Modules/WorldMap.lua desenha os pinos).

    Duas fontes, juntas:
      · coletor próprio: cada vez que você colhe uma erva ou minera um veio, grava o nome do nó, a
        zona, a posição e o ícone do que caiu (AzaathUIGatherDB, separado do AzaathUIDB para não
        se perder quando o addon muda de versão). Funciona sem nenhum outro addon.
      · GatherLite (se estiver ligado): os pontos que ele conhece, pela API dele
        (GetNodesForMap / GetNodeObject / translate). Nada é copiado: é lido em tempo real.

    Filtros (Azaath.db.worldmap): gatherHerb, gatherOre, gatherOnlyKnown (só o que a sua profissão já
    colhe, quando o nível do nó é conhecido), gatherLite (usar o GatherLite), gatherHide[nome] = true.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("MapGather")

local C_Map = _G.C_Map
local pairs, ipairs, pcall, type = pairs, ipairs, pcall, type
local floor, abs, sort = math.floor, math.abs, table.sort

local HERB, ORE = "herb", "ore"
local SAME = 0.006          -- dois registros do mesmo nó: mais perto que isso (coordenadas 0..1 da zona)

local cache = {}            -- [mapID] = lista de pontos (refeita quando algo muda)
local types = {}            -- [nome] = { kind, icon, min } de tudo o que já apareceu
M.version = 0               -- muda quando os dados mudam (o mapa redesenha)

local function Safe(fn, ...)
    if not fn then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function Changed(mapID)
    if mapID then cache[mapID] = nil else wipe(cache) end
    M.version = M.version + 1
    local wm = Azaath:GetModule("WorldMap")
    if wm and wm.Refresh then wm:Refresh() end
end

---------------------------------------------------------------------------
-- GatherLite
---------------------------------------------------------------------------
local GL_KINDS = { mining = ORE, herbalism = HERB }
local objCache = {}

local function GatherLite()
    if M.db and M.db.gatherLite == false then return nil end
    local AA = _G.LibStub and _G.LibStub("AceAddon-3.0", true)
    return AA and Safe(AA.GetAddon, AA, "GatherLite", true) or nil
end

local function GLObject(gl, id)
    local o = objCache[id]
    if o == nil then
        local obj = Safe(gl.GetNodeObject, gl, id)
        if obj and obj.name then
            local name = Safe(gl.translate, gl, "node." .. obj.name) or obj.name
            o = { name = name, icon = obj.icon, min = type(obj.levels) == "table" and obj.levels[1] or nil }
        else
            o = false
        end
        objCache[id] = o
    end
    return o or nil
end

---------------------------------------------------------------------------
-- Pontos de uma zona
---------------------------------------------------------------------------
local function Remember(name, kind, icon, min)
    local t = types[name]
    if not t then
        types[name] = { kind = kind, icon = icon, min = min }
    else
        t.icon = t.icon or icon
        t.min = t.min or min
    end
end

-- { x, y (0..1 da zona), kind, name, icon, min, count, src }
function M:GetZonePoints(mapID)
    local list = cache[mapID]
    if list then return list end
    list = {}
    local own = self.store and self.store.nodes[mapID]
    if own then
        for _, n in ipairs(own) do
            list[#list + 1] = { x = n[1], y = n[2], kind = n[3], name = n[4], icon = n[5], count = n[6] or 1, src = "own" }
            Remember(n[4], n[3], n[5])
        end
    end
    local gl = GatherLite()
    if gl and gl.GetNodesForMap then
        for glKind, kind in pairs(GL_KINDS) do
            for _, node in ipairs(Safe(gl.GetNodesForMap, gl, glKind, mapID) or {}) do
                local o = node.object and GLObject(gl, node.object)
                if o and node.posX and node.posY then
                    list[#list + 1] = { x = node.posX, y = node.posY, kind = kind, name = o.name, icon = o.icon,
                                        min = o.min, count = 1, src = "gl" }
                    Remember(o.name, kind, o.icon, o.min)
                end
            end
        end
    end
    cache[mapID] = list
    return list
end

-- tudo o que já apareceu, para o painel de filtros: { { name, kind, icon }, ... } por tipo e nome
function M:Types()
    if self.store then
        for _, nodes in pairs(self.store.nodes) do
            for _, n in ipairs(nodes) do Remember(n[4], n[3], n[5]) end
        end
    end
    local out = {}
    for name, t in pairs(types) do out[#out + 1] = { name = name, kind = t.kind, icon = t.icon } end
    sort(out, function(a, b)
        if a.kind ~= b.kind then return a.kind == HERB end
        return a.name < b.name
    end)
    return out
end

---------------------------------------------------------------------------
-- Filtros
---------------------------------------------------------------------------
local HERB_SKILLS = { Herbalism = true, Herborismo = true, ["Kräuterkunde"] = true, ["Herboristería"] = true,
    Herboristerie = true, Erbalismo = true, ["Травничество"] = true, ["약초채집"] = true, ["草药学"] = true, ["草藥學"] = true }
local ORE_SKILLS = { Mining = true, ["Mineração"] = true, Bergbau = true, ["Minería"] = true, Minage = true,
    Estrazione = true, ["Горное дело"] = true, ["채광"] = true, ["采矿"] = true, ["採礦"] = true }
local skill, skillAt = {}, 0

local function SkillLevel(kind)
    if GetTime() - skillAt > 10 then
        skillAt = GetTime()
        skill[HERB], skill[ORE] = nil, nil
        local SI = _G.C_SkillLine
        local n = (SI and SI.GetNumSkillLines and SI.GetNumSkillLines()) or (GetNumSkillLines and GetNumSkillLines()) or 0
        for i = 1, n do
            local name, rank
            if SI and SI.GetSkillLineInfo then
                local d = SI.GetSkillLineInfo(i)
                if d then name, rank = d.name, d.rank end
            elseif GetSkillLineInfo then
                local nm, _, _, rk = GetSkillLineInfo(i)
                name, rank = nm, rk
            end
            if name and HERB_SKILLS[name] then skill[HERB] = rank or 0 end
            if name and ORE_SKILLS[name] then skill[ORE] = rank or 0 end
        end
    end
    return skill[kind]
end

function M:Shows(p)
    local db = self.db
    if p.kind == HERB and db.gatherHerb == false then return false end
    if p.kind == ORE and db.gatherOre == false then return false end
    if db.gatherHide and db.gatherHide[p.name] then return false end
    if db.gatherOnlyKnown and p.min then
        local lv = SkillLevel(p.kind)
        if not lv or lv < p.min then return false end
    end
    return true
end

function M:AnyOn()
    return self.db and (self.db.gatherHerb ~= false or self.db.gatherOre ~= false)
end

---------------------------------------------------------------------------
-- Coletor próprio
---------------------------------------------------------------------------
local SPELL = {}    -- nome do feitiço -> tipo
local function SpellName(id)
    if _G.C_Spell and C_Spell.GetSpellInfo then
        local i = C_Spell.GetSpellInfo(id)
        if type(i) == "table" then return i.name end
    end
    return GetSpellInfo and (GetSpellInfo(id)) or nil
end

local pending       -- { kind, name, mapID, x, y, t }

local function Record(p, icon)
    local nodes = M.store.nodes[p.mapID]
    if not nodes then nodes = {}; M.store.nodes[p.mapID] = nodes end
    for _, n in ipairs(nodes) do
        if n[4] == p.name and abs(n[1] - p.x) < SAME and abs(n[2] - p.y) < SAME then
            n[6] = (n[6] or 1) + 1
            n[5] = n[5] or icon
            n[7] = time()
            Changed(p.mapID)
            return
        end
    end
    nodes[#nodes + 1] = { floor(p.x * 10000 + 0.5) / 10000, floor(p.y * 10000 + 0.5) / 10000, p.kind, p.name, icon, 1, time() }
    Changed(p.mapID)
end

local function OnSent(unit, target, _, spellID)
    -- em combate o alvo vem como valor secreto: checar ANTES de qualquer comparação
    local isSecret = Azaath.IsSecret or issecretvalue
    if isSecret and (isSecret(unit) or isSecret(target) or isSecret(spellID)) then return end
    if unit ~= "player" or type(target) ~= "string" or target == "" then return end
    local kind = spellID and SPELL[SpellName(spellID) or ""]
    if not kind then return end
    if IsInInstance and IsInInstance() then return end
    local mapID = Safe(C_Map.GetBestMapForUnit, "player")
    local pos = mapID and Safe(C_Map.GetPlayerMapPosition, mapID, "player")
    local x, y
    if pos then x, y = pos:GetXY() end
    if not (x and y) or (x == 0 and y == 0) then return end
    pending = { kind = kind, name = target, mapID = mapID, x = x, y = y, t = GetTime() }
end

local function OnLoot()
    local p = pending
    pending = nil
    if not p or GetTime() - p.t > 8 then return end
    local icon = GetLootSlotInfo and GetNumLootItems and GetNumLootItems() > 0 and (GetLootSlotInfo(1)) or nil
    Record(p, icon)
end

---------------------------------------------------------------------------
function M:OnInitialize()
    self.db = Azaath.db.worldmap
    if type(_G.AzaathUIGatherDB) ~= "table" then _G.AzaathUIGatherDB = {} end
    self.store = _G.AzaathUIGatherDB
    self.store.nodes = self.store.nodes or {}
    self.db.gatherHide = self.db.gatherHide or {}
end

function M:OnEnable()
    local mining, herb = SpellName(2575), SpellName(2366)
    if mining then SPELL[mining] = ORE end
    if herb then SPELL[herb] = HERB end
    local ev = CreateFrame("Frame")
    ev:RegisterEvent("UNIT_SPELLCAST_SENT")
    ev:RegisterEvent("LOOT_OPENED")
    ev:RegisterEvent("UNIT_SPELLCAST_FAILED")
    ev:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
    ev:SetScript("OnEvent", function(_, event, ...)
        if event == "UNIT_SPELLCAST_SENT" then
            OnSent(...)
        elseif event == "LOOT_OPENED" then
            OnLoot()
        elseif (...) == "player" then
            pending = nil
        end
    end)
    -- o GatherLite avisa quando aprende um nó novo
    local gl = GatherLite()
    if gl and gl.On then pcall(gl.On, gl, "nodes:added", function() Changed() end) end
end

-- ao abrir o mapa: relê as fontes (o GatherLite pode ter carregado os dados dele depois)
function M:Flush()
    wipe(cache)
end

-- trocar a fonte (GatherLite liga/desliga) exige refazer tudo
function M:Invalidate()
    wipe(objCache)
    wipe(types)
    Changed()
end
