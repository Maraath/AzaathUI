--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Talents/Tree.lua
    Crisol de talentos: leitura das árvores (API clássica de 3 abas e C_Traits do WoW Forever).
    Símbolos comuns vêm de Azaath.TalentsUI (Modules/Talents/Core.lua).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.TalentsUI
local _G, format, ipairs, max = _G, string.format, ipairs, math.max
local min, pairs, pcall, sin = math.min, pairs, pcall, math.sin
local sqrt, tsort, type, wipe = math.sqrt, table.sort, type, wipe
local Call, ICON_R, Pack, ParseClassicTalentTooltip = U.Call, U.ICON_R, U.Pack, U.ParseClassicTalentTooltip
local TREES, pending, traitsInfo = U.TREES, U.pending, U.traitsInfo

--------------------------------------------------------------------------------
-- Leitura da Árvore Real (API clássica de 3 abas)
--------------------------------------------------------------------------------
local function TalentInfo(tab, idx, group)
    local r = Pack(pcall(_G.GetTalentInfo, tab, idx, false, false, group))
    if not (r[1] and r[2]) then r = Pack(pcall(_G.GetTalentInfo, tab, idx)) end
    if not r[1] then return nil end
    local a = r[2]
    if type(a) == "table" then -- formato em tabela de clientes novos
        return a.name, a.icon or a.iconTexture, a.tier or a.row, a.column, a.rank, a.maxRank, a.previewRank
    end
    -- name, icon, tier, column, rank, maxRank, isExceptional, available, previewRank, previewAvailable
    return a, r[3], r[4], r[5], r[6], r[7], r[10]
end

local function TabInfo(tab, group)
    local r = Pack(pcall(_G.GetTalentTabInfo, tab, false, false, group))
    if not r[1] or r[2] == nil then r = Pack(pcall(_G.GetTalentTabInfo, tab)) end
    if not r[1] then return nil end
    if type(r[2]) == "string" then
        -- name, icon, pointsSpent, background, previewPointsSpent
        return r[2], r[3], tonumber(r[4]) or 0
    end
    -- id, name, description, icon, pointsSpent, background, previewPointsSpent, isUnlocked
    return r[3], r[5], tonumber(r[6]) or 0
end

local function NumTalents(tab)
    local n = Call(_G.GetNumTalents, tab, false, false)
    if not n or n == 0 then n = Call(_G.GetNumTalents, tab) end
    return n or 0
end

local function ReadClassicTree()
    if not (_G.GetNumTalentTabs and _G.GetTalentTabInfo and _G.GetNumTalents and _G.GetTalentInfo) then
        return nil
    end
    local numTabs = Call(_G.GetNumTalentTabs, false, false) or Call(_G.GetNumTalentTabs) or 0
    if numTabs <= 0 then return nil end

    U.specMode = (_G.GetActiveTalentGroup and Call(_G.GetActiveTalentGroup, false, false)) or 1
    local numGroups = (_G.GetNumTalentGroups and Call(_G.GetNumTalentGroups, false, false)) or 1
    local hasPreviewAPI = (_G.AddPreviewTalentPoints ~= nil and _G.LearnPreviewTalents ~= nil
        and _G.GetGroupPreviewTalentPointsSpent ~= nil)

    local rawUnspent = (_G.GetUnspentTalentPoints and Call(_G.GetUnspentTalentPoints, false, false, U.specMode))
    if type(rawUnspent) ~= "number" then rawUnspent = (_G.UnitCharacterPoints and Call(_G.UnitCharacterPoints, "player")) or 0 end

    local data = {
        group = U.specMode, numGroups = numGroups, hasPreviewAPI = hasPreviewAPI,
        rawUnspent = rawUnspent, tabs = {}, nodes = {}, byKey = {},
    }

    local stagedTotal = 0
    for tab = 1, min(3, numTabs) do
        local tabName, tabIcon = TabInfo(tab, U.specMode)
        local tabNodes, grid = {}, {}
        local maxTier, maxCol = 1, 4

        for idx = 1, NumTalents(tab) do
            local name, icon, tier, col, rank, maxRank, previewRank = TalentInfo(tab, idx, U.specMode)
            if name and tier and col then
                rank, maxRank = rank or 0, maxRank or 1
                local key = tab .. ":" .. idx
                local eff = rank
                if hasPreviewAPI then
                    if type(previewRank) == "number" and previewRank > rank then eff = previewRank end
                else
                    eff = min(maxRank, rank + (pending[key] or 0))
                end
                stagedTotal = stagedTotal + (eff - rank)
                maxTier, maxCol = max(maxTier, tier), max(maxCol, col)

                local prereqs = {}
                if _G.GetTalentPrereqs then
                    local pr = Pack(pcall(_G.GetTalentPrereqs, tab, idx, false, false, U.specMode))
                    if not (pr[1] and pr[2]) then pr = Pack(pcall(_G.GetTalentPrereqs, tab, idx)) end
                    if pr[1] then
                        for p = 2, pr.n, 3 do
                            if pr[p] and pr[p + 1] then
                                prereqs[#prereqs + 1] = { tier = pr[p], col = pr[p + 1] }
                            end
                        end
                    end
                end

                local rec = {
                    key = key, tab = tab, idx = idx, name = name,
                    icon = icon or "Interface\\Icons\\INV_Misc_QuestionMark",
                    tier = tier, col = col, rank = eff, baseRank = rank, max = maxRank,
                    reqPoints = (tier - 1) * 5, prereqs = prereqs,
                }
                tabNodes[#tabNodes + 1] = rec
                data.nodes[#data.nodes + 1] = rec
                data.byKey[key] = rec
                grid[tier .. ":" .. col] = rec
            end
        end

        for _, rec in ipairs(tabNodes) do
            for _, pr in ipairs(rec.prereqs) do
                local parent = grid[pr.tier .. ":" .. pr.col]
                if parent then pr.parentKey = parent.key end
            end
        end
        data.tabs[tab] = { tab = tab, name = tabName or ("Senda " .. tab), icon = tabIcon, nodes = tabNodes }
    end
    if #data.nodes == 0 then return data end

    data.staged = stagedTotal
    data.unspent = max(0, rawUnspent - stagedTotal)
    return data
end

-- Ponto da curva do eixo de uma árvore (Bézier quadrática S -> C -> E)
local function Bez(L, t)
    local u = 1 - t
    return u * u * L.S[1] + 2 * u * t * L.C[1] + t * t * L.E[1],
           u * u * L.S[2] + 2 * u * t * L.C[2] + t * t * L.E[2]
end

-- Posição de cada talento no Crisol e estados.
-- Regras clássicas: o círculo exige 5 pontos por círculo anterior na árvore e o
-- pré-requisito precisa estar no máximo. Quando o jogo informa disponibilidade
-- (C_Traits), a palavra final é dele; as regras ficam para explicar o motivo.
local function Finalize(data)
    for tabIdx, info in pairs(data.tabs) do
        local L = TREES[tabIdx] or TREES[3]
        local maxTier, maxCol, spent = 1, 4, 0
        local sum, cnt = {}, {}
        for _, rec in ipairs(info.nodes) do
            maxTier, maxCol = max(maxTier, rec.tier), max(maxCol, rec.col)
            spent = spent + rec.rank
            sum[rec.tier] = (sum[rec.tier] or 0) + rec.col
            cnt[rec.tier] = (cnt[rec.tier] or 0) + 1
        end
        info.spent, info.maxTier, info.maxCol = spent, maxTier, maxCol
        info.axis = {}
        for t = 1, maxTier do
            local u = (maxTier > 1) and (t - 1) / (maxTier - 1) or 0
            local x, y = Bez(L, u)
            info.axis[t] = { x, y }
        end
        for _, rec in ipairs(info.nodes) do
            local a = info.axis[rec.tier]
            local off = (rec.col - (sum[rec.tier] / cnt[rec.tier])) * L.gap
            -- leve ondulação ao longo do eixo: os medalhões da arte não formam grade
            local u = (maxTier > 1) and (rec.tier - 1) / (maxTier - 1) or 0
            local tx = 2 * (1 - u) * (L.C[1] - L.S[1]) + 2 * u * (L.E[1] - L.C[1])
            local ty = 2 * (1 - u) * (L.C[2] - L.S[2]) + 2 * u * (L.E[2] - L.C[2])
            local tl = max(1, sqrt(tx * tx + ty * ty))
            local wob = sin(rec.col * 2.1 + rec.tier * 1.3) * 6
            rec.sx, rec.sy = a[1], a[2]
            rec.cx = a[1] + L.dir[1] * off + tx / tl * wob
            rec.cy = a[2] + L.dir[2] * off + ty / tl * wob
            rec.cap = (rec.tier == maxTier and maxTier > 1)
            rec.iconR = rec.cap and ICON_R.cap or (rec.max == 1 and ICON_R.single or ICON_R.normal)
        end
    end

    for _, rec in ipairs(data.nodes) do
        local tabInfo = data.tabs[rec.tab]
        local below = 0
        for _, o in ipairs(tabInfo.nodes) do
            if o.tier < rec.tier then below = below + o.rank end
        end
        rec.pointsBelow = below
        rec.tierUnlocked = below >= rec.reqPoints
        rec.prereqsMet = true
        for _, pr in ipairs(rec.prereqs) do
            local parent = pr.parentKey and data.byKey[pr.parentKey]
            pr.ok = parent and parent.rank >= parent.max or false
            if not pr.ok then rec.prereqsMet = false end
        end
        if rec.gameAvailable ~= nil then
            rec.available = rec.gameAvailable and true or false
        else
            rec.available = rec.tierUnlocked and rec.prereqsMet
        end
        if rec.gameCanBuy ~= nil then
            rec.canBuy = rec.gameCanBuy and rec.rank < rec.max and true or false
        else
            rec.canBuy = rec.available and rec.rank < rec.max and data.unspent > 0
        end
        rec.canRefund = rec.rank > rec.baseRank and rec.gameCanRefund ~= false
    end
    return data
end

--------------------------------------------------------------------------------
-- Leitura da Árvore no WoW Forever (C_Traits): uma árvore única por classe com
-- os talentos das três sendas. Quem diz a senda, fileira, coluna e o
-- pré-requisito de cada nó são os dados embutidos (Modules/TalentLayoutData.lua);
-- se a classe faltar neles, os nós são agrupados pela posição na árvore do jogo.
--------------------------------------------------------------------------------
local TREE_PT = {
    WarriorArms = "Armas", WarriorFury = "Fúria", WarriorProtection = "Proteção",
    PaladinHoly = "Sagrado", PaladinProtection = "Proteção", PaladinCombat = "Retribuição",
    HunterBeastMastery = "Domínio das Feras", HunterMarksmanship = "Precisão", HunterSurvival = "Sobrevivência",
    RogueAssassination = "Assassinato", RogueCombat = "Combate", RogueSubtlety = "Subterfúgio",
    PriestDiscipline = "Disciplina", PriestHoly = "Sagrado", PriestShadow = "Sombra",
    ShamanElementalCombat = "Elemental", ShamanEnhancement = "Aperfeiçoamento", ShamanRestoration = "Restauração",
    MageArcane = "Arcano", MageFire = "Fogo", MageFrost = "Gélido",
    WarlockCurses = "Suplício", WarlockSummoning = "Demonologia", WarlockDestruction = "Destruição",
    DruidBalance = "Equilíbrio", DruidFeralCombat = "Combate Feral", DruidRestoration = "Restauração",
}

-- Ícone de cada senda (ícones do próprio jogo)
local TREE_ICON = {
    WarriorArms = "ability_rogue_eviscerate", WarriorFury = "ability_warrior_innerrage", WarriorProtection = "inv_shield_06",
    PaladinHoly = "spell_holy_holybolt", PaladinProtection = "spell_holy_devotionaura", PaladinCombat = "spell_holy_auraoflight",
    HunterBeastMastery = "ability_hunter_beasttaming", HunterMarksmanship = "ability_marksmanship", HunterSurvival = "ability_hunter_swiftstrike",
    RogueAssassination = "ability_rogue_eviscerate", RogueCombat = "ability_backstab", RogueSubtlety = "ability_stealth",
    PriestDiscipline = "spell_holy_wordfortitude", PriestHoly = "spell_holy_guardianspirit", PriestShadow = "spell_shadow_shadowwordpain",
    ShamanElementalCombat = "spell_nature_lightning", ShamanEnhancement = "spell_nature_lightningshield", ShamanRestoration = "spell_nature_magicimmunity",
    MageArcane = "spell_holy_magicalsentry", MageFire = "spell_fire_firebolt02", MageFrost = "spell_frost_frostbolt02",
    WarlockCurses = "spell_shadow_deathcoil", WarlockSummoning = "spell_shadow_metamorphosis", WarlockDestruction = "spell_shadow_rainoffire",
    DruidBalance = "spell_nature_starfall", DruidFeralCombat = "ability_racial_bearform", DruidRestoration = "spell_nature_healingtouch",
}

-- Árvores de cada classe na ordem do jogo (esquerda para a direita). Reserva
-- para quando a classe falta nos dados embutidos: os talentos são
-- agrupados pela posição e o nome vem daqui em vez de "Senda N".
local CLASS_TREES = {
    WARRIOR = { "WarriorArms", "WarriorFury", "WarriorProtection" },
    PALADIN = { "PaladinHoly", "PaladinProtection", "PaladinCombat" },
    HUNTER  = { "HunterBeastMastery", "HunterMarksmanship", "HunterSurvival" },
    ROGUE   = { "RogueAssassination", "RogueCombat", "RogueSubtlety" },
    PRIEST  = { "PriestDiscipline", "PriestHoly", "PriestShadow" },
    SHAMAN  = { "ShamanElementalCombat", "ShamanEnhancement", "ShamanRestoration" },
    MAGE    = { "MageArcane", "MageFire", "MageFrost" },
    WARLOCK = { "WarlockCurses", "WarlockSummoning", "WarlockDestruction" },
    DRUID   = { "DruidBalance", "DruidFeralCombat", "DruidRestoration" },
}
local function ClassTreeName(cls, t)
    local list = cls and CLASS_TREES[cls]
    return list and list[t] and TREE_PT[list[t]] or nil
end

local function TraitsConfigFor(treeID)
    local CT = _G.C_Traits
    local function holds(cfg)
        if type(cfg) ~= "number" or cfg <= 0 then return false end
        local info = Call(CT.GetConfigInfo, cfg)
        for _, t in ipairs(info and info.treeIDs or {}) do
            if t == treeID then return true end
        end
        return false
    end
    local CCT = _G.C_ClassTalents
    local cfg = CCT and Call(CCT.GetActiveConfigID)
    if holds(cfg) then return cfg end
    cfg = Call(CT.GetConfigIDByTreeID, treeID)
    if holds(cfg) then return cfg end
    if CT.GetConfigIDBySystemID then
        for sys = 1, 40 do
            cfg = Call(CT.GetConfigIDBySystemID, sys)
            if holds(cfg) then return cfg end
        end
    end
    return nil
end

local function SpellNameIcon(spell)
    local CS = _G.C_Spell
    local name = CS and Call(CS.GetSpellName, spell)
    local icon = CS and Call(CS.GetSpellTexture, spell)
    if not name and _G.GetSpellInfo then
        local n, _, ic = Call(_G.GetSpellInfo, spell)
        name, icon = name or n, icon or ic
    end
    return name, icon
end

-- o feitiço do talento é passivo? true / false / nil (o jogo não diz)
local function SpellPassive(spell)
    if not spell then return nil end
    local CS = _G.C_Spell
    local v = CS and CS.IsSpellPassive and Call(CS.IsSpellPassive, spell)
    if v == nil and _G.IsPassiveSpell then v = Call(_G.IsPassiveSpell, spell) end
    if v == nil then return nil end
    return v and true or false
end

-- índices por valor com tolerância (posições da árvore do jogo)
local function Levels(values, tol)
    tsort(values)
    local lv = {}
    for _, v in ipairs(values) do
        if #lv == 0 or v - lv[#lv] > tol then lv[#lv + 1] = v end
    end
    return function(v)
        local best, bd = 1, math.huge
        for i, l in ipairs(lv) do
            local d = math.abs(v - l)
            if d < bd then best, bd = i, d end
        end
        return best
    end, #lv
end

local function ReadTraitsTree()
    local CT = _G.C_Traits
    if not (CT and CT.GetTreeNodes and CT.GetNodeInfo and CT.GetConfigInfo) then return nil end
    local _, cls = UnitClass("player")
    -- mapa das árvores: sempre o embutido em Modules/TalentLayoutData.lua
    local cdata, source
    local D = Azaath.TalentLayoutData
    if type(D) == "table" and type(D.classes) == "table" and type(D.classes[cls]) == "table" then
        cdata, source = D.classes[cls], "AzaathUI"
    end

    local treeID = cdata and cdata.tree
    local cfg = treeID and TraitsConfigFor(treeID)
    if not cfg then
        local CCT = _G.C_ClassTalents
        local active = CCT and Call(CCT.GetActiveConfigID)
        local info = active and Call(CT.GetConfigInfo, active)
        if info and info.treeIDs and info.treeIDs[1] then cfg, treeID = active, info.treeIDs[1] end
    end
    wipe(traitsInfo)
    traitsInfo.treeID, traitsInfo.configID, traitsInfo.data = treeID, cfg, source or "posição"
    if not (cfg and treeID) then return nil end

    local raw = {}
    for _, id in ipairs(Call(CT.GetTreeNodes, treeID) or {}) do
        local n = Call(CT.GetNodeInfo, cfg, id)
        if type(n) == "table" and (n.maxRanks or 0) > 0 and n.isVisible ~= false then
            local entry = n.activeEntry and n.activeEntry.entryID or (n.entryIDs and n.entryIDs[1])
            local spell, name, icon
            if entry then
                local e = Call(CT.GetEntryInfo, cfg, entry)
                local d = e and e.definitionID and Call(CT.GetDefinitionInfo, e.definitionID)
                if d then
                    spell = d.spellID or d.overriddenSpellID
                    if d.overrideName and d.overrideName ~= "" then name = d.overrideName end
                    icon = d.overrideIcon
                end
            end
            if spell then
                local sn, si = SpellNameIcon(spell)
                name, icon = name or sn, icon or si
            end
            raw[#raw + 1] = { id = id, n = n, entry = entry, spell = spell, name = name, icon = icon }
        end
    end
    traitsInfo.visibleNodes = #raw
    if #raw == 0 then return nil end

    -- senda, fileira e coluna de cada nó
    local tabMeta = {}
    local mapped = 0
    if cdata and type(cdata.trees) == "table" then
        local byNode, bySpell = {}, {}
        for ti, tr in ipairs(cdata.trees) do
            for i, t in ipairs(tr.talents or {}) do
                if not t.removed then
                    local ref = { ti = ti, i = i, t = t }
                    if t.node then byNode[t.node] = ref end
                    if t.spell then bySpell[t.spell] = ref end
                end
            end
            local icon = tr.icon or TREE_ICON[tr.bg]
            tabMeta[ti] = { name = TREE_PT[tr.bg] or tr.name, icon = icon and ("Interface\\Icons\\" .. icon) }
        end
        for _, x in ipairs(raw) do
            local ref = x.spell and bySpell[x.spell]
            if not ref then
                ref = byNode[x.id]
                -- um nó que hoje carrega outro feitiço não é este talento
                if ref and x.spell and ref.t.spell and ref.t.spell ~= x.spell then ref = nil end
            end
            if ref and ref.t.row and ref.t.col then
                x.tab, x.tier, x.col, x.ref = ref.ti, ref.t.row, ref.t.col, ref
                mapped = mapped + 1
            end
        end
    end
    traitsInfo.mapped = mapped
    -- mapa de outra build do jogo (casou só uma parte): talentos sem par sumiriam
    -- da tela; nesse caso vale a dedução pela posição para todos
    if mapped > 0 and mapped < #raw * 0.9 then
        for _, x in ipairs(raw) do x.tab, x.tier, x.col, x.ref = nil, nil, nil, nil end
        traitsInfo.mapped = mapped .. " de " .. #raw .. " (mapa desatualizado, usando posição)"
        mapped = 0
    end

    if mapped == 0 then
        -- sem dados: três grupos pelas duas maiores lacunas em X; fileira por Y, coluna por X
        tsort(raw, function(a, b) return (a.n.posX or 0) < (b.n.posX or 0) end)
        local gaps = {}
        for i = 2, #raw do
            gaps[#gaps + 1] = { i = i, d = (raw[i].n.posX or 0) - (raw[i - 1].n.posX or 0) }
        end
        tsort(gaps, function(a, b) return a.d > b.d end)
        local cuts = {}
        for k = 1, min(2, #gaps) do cuts[#cuts + 1] = gaps[k].i end
        tsort(cuts)
        local g = 1
        for i, x in ipairs(raw) do
            while cuts[g] and i >= cuts[g] do g = g + 1 end
            x.tab = g
        end
        for t = 1, 3 do
            local xs, ys, members = {}, {}, {}
            for _, x in ipairs(raw) do
                if x.tab == t then
                    members[#members + 1] = x
                    xs[#xs + 1], ys[#ys + 1] = x.n.posX or 0, x.n.posY or 0
                end
            end
            if #members > 0 then
                local colOf = Levels(xs, 150)
                local rowOf = Levels(ys, 150)
                for _, x in ipairs(members) do
                    x.col, x.tier = colOf(x.n.posX or 0), rowOf(x.n.posY or 0)
                end
                tabMeta[t] = { name = ClassTreeName(cls, t) or ("Senda " .. t), icon = members[1].icon }
            end
        end
    end

    local data = {
        mode = "traits", configID = cfg, treeID = treeID, group = 1, numGroups = 1,
        tabs = {}, nodes = {}, byKey = {},
    }
    local cfgInfo = Call(CT.GetConfigInfo, cfg)
    data.configName = cfgInfo and cfgInfo.name

    local byTabIdx = {}
    for _, x in ipairs(raw) do
        if x.tab and x.tier and x.col and x.tab <= 3 then
            local n = x.n
            local cur = n.currentRank or n.ranksPurchased or n.activeRank or 0
            local base = n.activeRank or cur
            local key = "n" .. x.id
            local rec = {
                key = key, tab = x.tab, idx = x.ref and x.ref.i or x.id, node = x.id, entry = x.entry, spell = x.spell,
                name = x.name or (x.ref and x.ref.t.name) or ("Talento " .. x.id),
                icon = x.icon or (x.ref and x.ref.t.icon and ("Interface\\Icons\\" .. x.ref.t.icon))
                    or "Interface\\Icons\\INV_Misc_QuestionMark",
                tier = x.tier, col = x.col, rank = min(cur, n.maxRanks), baseRank = min(base, n.maxRanks), max = n.maxRanks,
                reqPoints = (x.tier - 1) * 5, prereqs = {},
                gameAvailable = n.isAvailable, gameCanBuy = n.canPurchaseRank, gameCanRefund = n.canRefundRank,
                edges = n.visibleEdges, req = x.ref and x.ref.t.req, passive = SpellPassive(x.spell),
            }
            local info = data.tabs[x.tab]
            if not info then
                local meta = tabMeta[x.tab] or {}
                info = { tab = x.tab, name = meta.name or ClassTreeName(cls, x.tab) or ("Senda " .. x.tab), icon = meta.icon or rec.icon, nodes = {} }
                data.tabs[x.tab] = info
            end
            info.nodes[#info.nodes + 1] = rec
            data.nodes[#data.nodes + 1] = rec
            data.byKey[key] = rec
            byTabIdx[x.tab .. ":" .. rec.idx] = rec
        end
    end
    -- as três sendas sempre existem (selos), mesmo vazias
    for t = 1, 3 do
        if not data.tabs[t] then
            data.tabs[t] = { tab = t, name = (tabMeta[t] and tabMeta[t].name) or ClassTreeName(cls, t) or ("Senda " .. t), icon = tabMeta[t] and tabMeta[t].icon, nodes = {} }
        end
    end

    -- pré-requisitos: índice "req" dos dados, senão as arestas visíveis do jogo
    for _, rec in ipairs(data.nodes) do
        if rec.req then
            local p = byTabIdx[rec.tab .. ":" .. rec.req]
            if p then rec.prereqs[#rec.prereqs + 1] = { parentKey = p.key } end
        end
    end
    if mapped == 0 then
        for _, rec in ipairs(data.nodes) do
            for _, e in ipairs(rec.edges or {}) do
                local child = e.targetNode and data.byKey["n" .. e.targetNode]
                if child then child.prereqs[#child.prereqs + 1] = { parentKey = rec.key } end
            end
        end
    end

    local staged = 0
    for _, rec in ipairs(data.nodes) do staged = staged + (rec.rank - rec.baseRank) end
    if CT.ConfigHasStagedChanges and staged == 0 and Call(CT.ConfigHasStagedChanges, cfg) then staged = 1 end
    data.staged = staged

    local unspent
    if CT.GetTreeCurrencyInfo then
        local cur = Call(CT.GetTreeCurrencyInfo, cfg, treeID, false)
        local ci = type(cur) == "table" and cur[1]
        if ci and ci.quantity then unspent = ci.quantity end
    end
    if not unspent then
        local spent = 0
        for _, rec in ipairs(data.nodes) do spent = spent + rec.rank end
        unspent = max(0, min(51, (UnitLevel("player") or 10) - 9) - spent)
    end
    data.unspent = unspent
    traitsInfo.read = #data.nodes
    return data
end

-- Descrição de um traço (C_Traits): linhas do tooltip do jogo para o posto atual e o próximo
local function TipLinesFrom(getter, ...)
    if type(getter) ~= "function" then return nil end
    local ok, data = pcall(getter, ...)
    if not ok or type(data) ~= "table" or type(data.lines) ~= "table" then return nil end
    local out = {}
    for _, line in ipairs(data.lines) do
        if _G.TooltipUtil and TooltipUtil.SurfaceArgs and not line.leftText then pcall(TooltipUtil.SurfaceArgs, line) end
        if type(line.leftText) == "string" then out[#out + 1] = line.leftText end
    end
    return #out > 0 and out or nil
end

local function NoiseLine(s)
    return s == "" or s == "Passiva" or s == "Passivo" or s == "Passive" or (_G.SPELL_PASSIVE and s == SPELL_PASSIVE)
        or s:match("^Ranque") or s:match("^Rank") or s:match("^Grau %d") or s:match("^Posto")
        or s:match("^Requer") or s:match("^Requires") or s:match("^Próximo") or s:match("^Next rank")
end

local function TraitDesc(r)
    local CTI = _G.C_TooltipInfo
    local function body(rank)
        local lines = (r.entry and CTI and TipLinesFrom(CTI.GetTraitEntry, r.entry, rank))
            or (r.spell and CTI and TipLinesFrom(CTI.GetSpellByID, r.spell))
        if lines then
            local keep = {}
            for k = 2, #lines do
                local s = lines[k]
                if not (Azaath.IsSecret and Azaath.IsSecret(s)) and not NoiseLine(s) then keep[#keep + 1] = s end
            end
            return table.concat(keep, "\n")
        end
        local CS = _G.C_Spell
        return (r.spell and CS and Call(CS.GetSpellDescription, r.spell)) or ""
    end
    local cur = body(max(1, r.rank))
    local nxt = (r.rank > 0 and r.rank < r.max) and body(r.rank + 1) or nil
    if nxt == cur then nxt = nil end
    return cur, nxt
end

local function DescFor(r)
    if U.treeData and U.treeData.mode == "traits" then return TraitDesc(r) end
    return ParseClassicTalentTooltip(r.tab, r.idx, U.specMode)
end

-- Pode tirar 1 ponto da prévia sem quebrar outro talento já previsto?
local function CanRemovePoint(rec)
    if not (rec and rec.rank > rec.baseRank) then return false, nil end
    local tabInfo = U.treeData.tabs[rec.tab]
    for _, o in ipairs(tabInfo.nodes) do
        if o ~= rec and o.rank > 0 then
            for _, pr in ipairs(o.prereqs) do
                if pr.parentKey == rec.key and rec.rank == rec.max then
                    return false, format("%s depende deste talento no máximo.", o.name)
                end
            end
            if o.tier > rec.tier then
                local below = 0
                for _, q in ipairs(tabInfo.nodes) do
                    if q.tier < o.tier then below = below + q.rank end
                end
                if below - 1 < o.reqPoints then
                    return false, format("%s precisa destes pontos para continuar liberado.", o.name)
                end
            end
        end
    end
    return true
end

-- compartilhado com os outros arquivos de Modules/Talents/
U.CanRemovePoint, U.DescFor, U.Finalize, U.ReadClassicTree = CanRemovePoint, DescFor, Finalize, ReadClassicTree
U.ReadTraitsTree = ReadTraitsTree
