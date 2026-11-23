--[[----------------------------------------------------------------------------
    AzaathUI - Modules/SheetDungeons.lua
    Aba "Masmorras" do Santuário: catálogo de masmorras e raides do Forever.
      * Esquerda: catálogo (Todas / Masmorras / Raides + busca), uma carta por masmorra.
      * Centro: chefes da masmorra escolhida (e o espólio dos inimigos comuns).
      * Direita: espólio do chefe, com ícone, qualidade, tipo de peça e % de drop.
      * O painel da direita alterna ESPÓLIO / MISSÕES. No espólio, a barra de classes de baixo
        apaga o que a classe escolhida não pode usar (armadura/arma ou "Classes:" do item).
        Nas missões: cadeia, etapa atual, quem dá/recebe, estado no diário e quem do grupo
        também está nela; clique marca no mapa (QuestNav), Shift + clique faz o link.
    Dados: Data/Quests/Dungeons.lua (gerado do OneForAll, GPL-3.0+) e
    Data/Quests/DungeonQuests.lua (gerado do Dungeon Master, GPL-3.0). As peças visuais
    são as mesmas da aba Drops (SheetDrops expõe H, C e utilitários).
    O botão "VER CHEFE" da aba Drops chama M:ShowBoss(chave da fonte).
------------------------------------------------------------------------------]]

local ADDON_NAME, Azaath = ...
local M = Azaath:NewModule("SheetDungeons")

local _G = _G
local ipairs, pairs, tonumber, type = ipairs, pairs, tonumber, type
local min, max, floor, format = math.min, math.max, math.floor, string.format

local ART_W, ART_H = 1920, 1080
local SHEET_MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Sheet\\"

local LIST_ROWS, BOSS_ROWS, LOOT_ROWS = 9, 11, 11
local ROW_H, BOSS_H, LOOT_H = 84, 62, 74

-- arte do cliente: botão do Diário de Masmorras (256x128, área útil 174x95) ou fundo do LFG (512x256)
local ART_SRC = { ej = { 256, 128, 0, 0.68359375, 0, 0.7421875 }, lfg = { 512, 256, 0, 1, 0, 1 } }

-- recorta da arte uma faixa central com a proporção w:h
local function SetArt(tex, d, w, h)
    local a = d and ART_SRC[d.artKind]
    if not (a and d.artFid) then tex:Hide() return end
    local W, Hh, u0, u1, v0, v1 = a[1], a[2], a[3], a[4], a[5], a[6]
    local pxW, pxH = (u1 - u0) * W, (v1 - v0) * Hh
    local wantH = pxW * h / w
    if wantH <= pxH then
        local dv, vc = wantH / Hh, (v0 + v1) / 2
        tex:SetTexCoord(u0, u1, vc - dv / 2, vc + dv / 2)
    else
        local du, uc = (pxH * w / h) / W, (u0 + u1) / 2
        tex:SetTexCoord(uc - du / 2, uc + du / 2, v0, v1)
    end
    tex:SetTexture(d.artFid)
    tex:Show()
end

local U = { filter = "all", query = "", dOff = 0, bOff = 0, lOff = 0, qOff = 0, mode = "loot" }
local catalog, byKey -- catalog[i] = { name, label, level, location, raid, area, bosses = { {key,name,items={{id,pct}}} } }

--------------------------------------------------------------------------------
-- Classes: o que cada uma pode usar (armadura = classe 4, arma = classe 2 do item)
--------------------------------------------------------------------------------
local CLASSES = { "WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID" }
local function ClassSet(s)
    local t = {}
    for c in s:gmatch("%u+") do t[c] = true end
    return t
end
local ARMOR = {
    [2] = ClassSet("WARRIOR PALADIN HUNTER ROGUE SHAMAN DRUID DEATHKNIGHT"),       -- couro
    [3] = ClassSet("WARRIOR PALADIN HUNTER SHAMAN DEATHKNIGHT"),                   -- malha
    [4] = ClassSet("WARRIOR PALADIN DEATHKNIGHT"),                                 -- placa
    [6] = ClassSet("WARRIOR PALADIN SHAMAN"),                                      -- escudo
    [7] = ClassSet("PALADIN"), [8] = ClassSet("DRUID"), [9] = ClassSet("SHAMAN"), -- libra, ídolo, totem
    [10] = ClassSet("DEATHKNIGHT"),                                                -- selo
}
local WEAPON = {
    [0]  = ClassSet("WARRIOR PALADIN HUNTER SHAMAN DEATHKNIGHT"),                  -- machado 1M
    [1]  = ClassSet("WARRIOR PALADIN HUNTER SHAMAN DEATHKNIGHT"),                  -- machado 2M
    [2]  = ClassSet("WARRIOR HUNTER ROGUE"),                                       -- arco
    [3]  = ClassSet("WARRIOR HUNTER ROGUE"),                                       -- arma de fogo
    [4]  = ClassSet("WARRIOR PALADIN ROGUE PRIEST SHAMAN DRUID DEATHKNIGHT"),      -- maça 1M
    [5]  = ClassSet("WARRIOR PALADIN SHAMAN DRUID DEATHKNIGHT"),                   -- maça 2M
    [6]  = ClassSet("WARRIOR PALADIN HUNTER DEATHKNIGHT"),                         -- arma de haste
    [7]  = ClassSet("WARRIOR PALADIN HUNTER ROGUE MAGE WARLOCK DEATHKNIGHT"),      -- espada 1M
    [8]  = ClassSet("WARRIOR PALADIN HUNTER DEATHKNIGHT"),                         -- espada 2M
    [10] = ClassSet("WARRIOR HUNTER PRIEST SHAMAN MAGE WARLOCK DRUID"),            -- cajado
    [13] = ClassSet("WARRIOR HUNTER ROGUE SHAMAN DRUID"),                          -- arma de punho
    [15] = ClassSet("WARRIOR HUNTER ROGUE PRIEST SHAMAN MAGE WARLOCK DRUID"),      -- adaga
    [16] = ClassSet("WARRIOR HUNTER ROGUE"),                                       -- arremesso
    [18] = ClassSet("WARRIOR HUNTER ROGUE"),                                       -- besta
    [19] = ClassSet("PRIEST MAGE WARLOCK"),                                        -- varinha
}

-- linha "Classes: X, Y" do item (tier, tomos): lida da dica do cliente, guardada por item
local allowedCache, allowedPat = {}, nil
local function AllowedClasses(id)
    local c = allowedCache[id]
    if c ~= nil then return c or nil end
    local TI, fmt = _G.C_TooltipInfo, _G.ITEM_CLASSES_ALLOWED
    if not (TI and TI.GetItemByID and type(fmt) == "string") then return nil end
    if not allowedPat then
        local esc = fmt:gsub("([%%%(%)%.%+%-%*%?%[%]%^%$])", "%%%1")
        allowedPat = "^" .. esc:gsub("%%%%s", "(.+)") .. "$"
    end
    local ok, data = pcall(TI.GetItemByID, id)
    if not (ok and type(data) == "table" and type(data.lines) == "table" and #data.lines > 1) then return nil end
    local found = false
    for _, line in ipairs(data.lines) do
        local txt = line.leftText
        if type(txt) == "string" and not Azaath.IsSecret(txt) then
            local names = txt:match(allowedPat)
            if names then
                found = {}
                for _, t in ipairs({ _G.LOCALIZED_CLASS_NAMES_MALE or {}, _G.LOCALIZED_CLASS_NAMES_FEMALE or {} }) do
                    for cls, n in pairs(t) do
                        if names:find(n, 1, true) then found[cls] = true end
                    end
                end
                break
            end
        end
    end
    allowedCache[id] = found
    return found or nil
end

local function Usable(id, class)
    if not class or class == "ALL" then return true end
    local get = (_G.C_Item and _G.C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
    if get then
        local _, _, _, equipLoc, _, classID, subID = get(id)
        local rule
        if classID == 4 and equipLoc ~= "INVTYPE_CLOAK" then rule = ARMOR[subID]
        elseif classID == 2 then rule = WEAPON[subID] end
        if rule and not rule[class] then return false end
    end
    local allowed = AllowedClasses(id)
    return not (allowed and not allowed[class])
end

local function ClassName(class)
    if class == "ALL" then return "Todas as classes" end
    local t = _G.LOCALIZED_CLASS_NAMES_MALE
    return t and t[class] or class
end

--------------------------------------------------------------------------------
-- Missões das masmorras (Data/Quests/DungeonQuests.lua)
--------------------------------------------------------------------------------
local quests, questsByDungeon -- quests[id] = { id, name, level, ... }; questsByDungeon[nome] = { ids finais }

local function QNum(f, i) return tonumber(f[i] or "") end
local function QStr(f, i) local v = f[i]; return v and v ~= "" and v or nil end
local function QIds(f, i)
    local t = {}
    for x in (f[i] or ""):gmatch("%d+") do t[#t + 1] = tonumber(x) end
    return #t > 0 and t or nil
end

local function EnsureQuests()
    if quests then return end
    quests, questsByDungeon = {}, {}
    local raw = Azaath.DungeonQuestsRaw
    if type(raw) ~= "string" then return end
    for line in raw:gmatch("[^\r\n]+") do
        local f = {}
        for v in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = v end
        if f[1] == "D" then
            questsByDungeon[f[2]] = QIds(f, 3) or {}
        elseif f[1] == "Q" then
            local id = tonumber(f[2])
            quests[id] = {
                id = id, name = f[3], level = QNum(f, 4), minLevel = QNum(f, 5), faction = QStr(f, 6), prev = QNum(f, 7),
                flags = f[8] or "", npc = QStr(f, 9), npcID = QNum(f, 10), map = QNum(f, 11), x = QNum(f, 12), y = QNum(f, 13),
                ender = QStr(f, 14), emap = QNum(f, 15), ex = QNum(f, 16), ey = QNum(f, 17), classes = QStr(f, 18),
                choices = QIds(f, 19), rewards = QIds(f, 20), item = QNum(f, 21), alt = QNum(f, 22),
                objective = QStr(f, 23), tip = QStr(f, 24),
                namePt = QStr(f, 25), npcPt = QStr(f, 26), enderPt = QStr(f, 27), objPt = QStr(f, 28), tipPt = QStr(f, 29),
            }
        end
    end
    Azaath.DungeonQuestsRaw = nil
end

local function QCall(fn, ...)
    if not fn then return nil end
    local ok, r = pcall(fn, ...)
    if ok and not Azaath.IsSecret(r) then return r end
end

local function QDone(q)
    local CQ = _G.C_QuestLog
    if not CQ then return false end
    return QCall(CQ.IsQuestFlaggedCompleted, q.id) or (q.alt and QCall(CQ.IsQuestFlaggedCompleted, q.alt)) or false
end

local function QInLog(q)
    local CQ = _G.C_QuestLog
    if not CQ then return nil end
    if QCall(CQ.IsOnQuest, q.id) then return q.id end
    if q.alt and QCall(CQ.IsOnQuest, q.alt) then return q.alt end
end

local function QTitle(q, pt)
    local CQ = _G.C_QuestLog
    if pt and q.namePt then return q.namePt end
    if pt and CQ then
        local t = QCall(CQ.GetTitleForQuestID, q.id)
        if type(t) == "string" and t ~= "" then return t end
        QCall(CQ.RequestLoadQuestByID, q.id)
    end
    return q.name or ("Missão #" .. q.id)
end

-- textos no idioma escolhido (pt quando houver tradução; senão o original em inglês)
local function QNpc(q, pt) return pt and q.npcPt or q.npc end
local function QEnder(q, pt) return pt and q.enderPt or q.ender end
local function QObjective(q, pt)
    local t = pt and q.objPt or q.objective
    if t and t:find("{", 1, true) then
        t = t:gsub("{nome}", UnitName("player") or ""):gsub("{classe}", UnitClass("player") or ""):gsub("{raça}", UnitRace("player") or "")
    end
    return t
end
local function QTip(q, pt) return pt and q.tipPt or q.tip end

local mapNames = {}
local function MapName(map)
    if not map then return nil end
    if mapNames[map] == nil then
        local info = _G.C_Map and QCall(_G.C_Map.GetMapInfo, map)
        mapNames[map] = info and info.name or false
    end
    return mapNames[map] or nil
end

-- estado de uma missão final da masmorra: etapa atual da cadeia, situação e grupo
local QSTATE = {
    ready = { "ENTREGAR",   { 1.00, 0.82, 0.30 }, 1, "Interface\\GossipFrame\\ActiveQuestIcon" },
    log   = { "NO DIÁRIO",  { 0.55, 0.88, 1.00 }, 2, "Interface\\GossipFrame\\IncompleteQuestIcon" },
    avail = { "DISPONÍVEL", { 0.93, 0.90, 0.83 }, 3, "Interface\\GossipFrame\\AvailableQuestIcon" },
    low   = { "NÍVEL %d",   { 0.95, 0.42, 0.36 }, 4, "Interface\\GossipFrame\\AvailableQuestIcon" },
    done  = { "CONCLUÍDA",  { 0.45, 0.86, 0.45 }, 5, "Interface\\RaidFrame\\ReadyCheck-Ready" },
}

local function QuestView(q, ctx)
    local chain, s, guard = {}, q, 0
    while s and guard < 40 do
        table.insert(chain, 1, s)
        s = s.prev and quests[s.prev]
        guard = guard + 1
    end
    local v = { q = q, chain = chain, step = #chain }
    if QDone(q) then
        v.state, v.cur = "done", q
    else
        for i, st in ipairs(chain) do
            if not QDone(st) then v.cur, v.step = st, i break end
        end
        v.cur = v.cur or q
        local logID = QInLog(v.cur)
        if logID then
            v.logID = logID
            v.state = QCall(_G.C_QuestLog.IsComplete, logID) and "ready" or "log"
        elseif (v.cur.minLevel or 0) > ctx.level then
            v.state = "low"
        else
            v.state = "avail"
        end
    end
    v.classOk = not q.classes or q.classes:find(ctx.class, 1, true) ~= nil
    v.party = 0
    if v.state ~= "done" and _G.C_QuestLog and _G.C_QuestLog.IsUnitOnQuest then
        for i = 1, 4 do
            local unit = "party" .. i
            if UnitExists(unit) and QCall(_G.C_QuestLog.IsUnitOnQuest, unit, v.logID or v.cur.id) then v.party = v.party + 1 end
        end
    end
    return v
end

local function DungeonQuests(d)
    EnsureQuests()
    local out = {}
    if not d then return out end
    local ids = questsByDungeon[d.name] or {}
    local fac = (UnitFactionGroup("player") or ""):sub(1, 1)
    local ctx = { level = UnitLevel("player") or 1, class = select(2, UnitClass("player")) or "" }
    for _, id in ipairs(ids) do
        local q = quests[id]
        if q and (not q.faction or q.faction == fac) then out[#out + 1] = QuestView(q, ctx) end
    end
    table.sort(out, function(a, b)
        if a.classOk ~= b.classOk then return a.classOk end
        local sa, sb = QSTATE[a.state][3], QSTATE[b.state][3]
        if sa ~= sb then return sa < sb end
        local la, lb = a.q.level or 0, b.q.level or 0
        if la ~= lb then return la < lb end
        return a.q.id < b.q.id
    end)
    return out
end

local function QuestCount(d)
    EnsureQuests()
    local ids = d and questsByDungeon[d.name]
    if not ids then return 0 end
    local fac, n = (UnitFactionGroup("player") or ""):sub(1, 1), 0
    for _, id in ipairs(ids) do
        local q = quests[id]
        if q and (not q.faction or q.faction == fac) then n = n + 1 end
    end
    return n
end

--------------------------------------------------------------------------------
-- Dados
--------------------------------------------------------------------------------
local FOLD = {
    ["á"]="a", ["à"]="a", ["â"]="a", ["ã"]="a", ["ä"]="a",
    ["Á"]="a", ["À"]="a", ["Â"]="a", ["Ã"]="a", ["Ä"]="a",
    ["é"]="e", ["è"]="e", ["ê"]="e", ["ë"]="e",
    ["É"]="e", ["È"]="e", ["Ê"]="e", ["Ë"]="e",
    ["í"]="i", ["ì"]="i", ["î"]="i", ["ï"]="i",
    ["Í"]="i", ["Ì"]="i", ["Î"]="i", ["Ï"]="i",
    ["ó"]="o", ["ò"]="o", ["ô"]="o", ["õ"]="o", ["ö"]="o",
    ["Ó"]="o", ["Ò"]="o", ["Ô"]="o", ["Õ"]="o", ["Ö"]="o",
    ["ú"]="u", ["ù"]="u", ["û"]="u", ["ü"]="u",
    ["Ú"]="u", ["Ù"]="u", ["Û"]="u", ["Ü"]="u",
    ["ç"]="c", ["Ç"]="c",
}
local function Norm(s)
    s = (s or ""):gsub("[\194-\244][\128-\191]*", FOLD):lower()
    return (s:gsub("[%c%p]", " "))
end

local function AreaName(area)
    if area and area > 0 and _G.C_Map and _G.C_Map.GetAreaInfo then
        local ok, name = pcall(_G.C_Map.GetAreaInfo, area)
        if ok and type(name) == "string" and name ~= "" then return name end
    end
end

local function EnsureCatalog()
    if catalog then return end
    catalog, byKey = {}, {}
    local raw = Azaath.DungeonCatalogRaw
    if type(raw) ~= "string" then return end
    local cur
    for line in raw:gmatch("[^\r\n]+") do
        local f = {}
        for v in (line .. "\t"):gmatch("([^\t]*)\t") do f[#f + 1] = v end
        local kind, a, b, c, d, e, g = f[1], f[2] or "", f[3] or "", f[4] or "", f[5] or "", f[6] or "", f[7] or ""
        if kind == "D" then
            local area = tonumber(e) or 0
            local pt = f[8] or ""
            cur = {
                name = a, pt = pt ~= "" and pt or nil, locPt = (f[9] or "") ~= "" and f[9] or nil, level = b, location = c, raid = d == "1", area = area,
                bosses = {}, artKind = g:match("^(%a+)"), artFid = tonumber(g:match("(%d+)$")),
            }
            cur.search = Norm((cur.pt or "") .. " " .. (AreaName(area) or "") .. " " .. a .. " " .. c .. " " .. (f[9] or ""))
            catalog[#catalog + 1] = cur
        elseif kind == "B" and cur then
            local pt = f[6] or ""
            local boss = { key = a, name = b, pt = pt ~= "" and pt or nil, items = {}, dungeon = cur, display = tonumber(d) or 0 }
            for id, pct in c:gmatch("(%d+):([%d%.]+)") do
                boss.items[#boss.items + 1] = { id = tonumber(id), pct = tonumber(pct) or 0 }
            end
            table.sort(boss.items, function(x, y) return x.pct > y.pct end)
            cur.bosses[#cur.bosses + 1] = boss
            boss.index = #cur.bosses
            byKey[a] = byKey[a] or boss
        end
    end
    Azaath.DungeonCatalogRaw = nil
    -- masmorras primeiro (pela faixa de nível), raides no fim
    local function lvl(d) return tonumber((d.level or ""):match("^(%d+)")) or 99 end
    table.sort(catalog, function(x, y)
        if x.raid ~= y.raid then return not x.raid end
        if lvl(x) ~= lvl(y) then return lvl(x) < lvl(y) end
        return x.name < y.name
    end)
end

-- Nome no idioma escolhido nas configurações do Azaath (Português/Inglês; padrão = idioma do cliente).
-- Em português: tradução do catálogo, senão o nome da zona dado pelo cliente, senão o original.
local function IsPt()
    local cfg = Azaath.ConfigUI
    if cfg and cfg.LangCode then return cfg.LangCode() == "ptBR" end
    return GetLocale and GetLocale() == "ptBR"
end

local function DName(d)
    if not d then return "" end
    if IsPt() then return d.pt or AreaName(d.area) or d.name end
    return d.name
end

local function BName(b)
    if not b then return "" end
    return IsPt() and b.pt or b.name
end

-- local da masmorra no idioma escolhido; a vírgula vira traço (a fonte do texto não tem vírgula)
local function DLoc(d)
    local loc = (IsPt() and d.locPt) or d.location
    if not loc or loc == "" then return "?" end
    return (loc:gsub(",", " -"))
end

function M:HasBoss(key)
    EnsureCatalog()
    return key and byKey[key] ~= nil
end

local function Filtered()
    EnsureCatalog()
    local out, q = {}, Norm(U.query)
    for _, d in ipairs(catalog) do
        local okF = U.filter == "all" or (U.filter == "raid") == d.raid
        if okF and (q == "" or d.search:find(q, 1, true)) then out[#out + 1] = d end
    end
    return out
end

--------------------------------------------------------------------------------
-- Pintura
--------------------------------------------------------------------------------
local SD, H, C, QC

local function SetRowState(row, active, hover)
    if row.thin then
        -- card de masmorra: sem moldura; o escolhido acende a arte e o feixe de baixo
        if row.beam then row.beam:SetAlpha(active and 0.85 or (hover and 0.45 or 0)) end
        row.art:SetAlpha((active or hover) and 1 or 0.82)
        -- hover: borda azul sutil e um leve clarão por cima da arte (cards escuros ficam legíveis)
        -- borda azul: fixa no card escolhido (onde estamos), sutil no hover
        for _, t in ipairs(row.edges) do t:SetAlpha(active and 1 or (hover and 0.75 or 0)) end
        row.glow:SetAlpha(hover and 0.10 or 0)
        return
    end
    row.skin:Apply(active and "WideA" or "WideN", true, not active)
    local a = active and 1 or (hover and 0.95 or 0.78)
    row.skin:SetAlpha(a)
    if row.beam then row.beam:SetAlpha(active and 0.85 or (hover and 0.45 or 0)) end
    if row.art then row.art:SetAlpha(active and 1 or (hover and 0.95 or 0.8)) end
end

-- retrato do chefe pelo displayID (o próprio cliente desenha); sem displayID, um ícone
local function SetPortrait(medal, boss)
    local tex = medal.icon
    if boss and boss.display and boss.display > 0 and _G.SetPortraitTextureFromCreatureDisplayID then
        tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        tex:SetVertexColor(1, 1, 1)
        if pcall(_G.SetPortraitTextureFromCreatureDisplayID, tex, boss.display) then return end
    end
    H.SkillIconTex(tex, boss and boss.key and boss.key:match("^t") and "axe" or "great", 14)
    tex:SetVertexColor(C.GOLD[1], C.GOLD[2], C.GOLD[3])
end

local function ItemInfo(id)
    local idr = Azaath:GetModule("ItemDrops")
    local e = idr and idr:GetItem(id)
    local meta = SD.GetItemMeta(id, e and e.quality)
    return e, meta
end

local function SetRowIcon(row, tex, small)
    local ic = row.medal.icon
    local sz = small and 30 or row.medal.baseIconSize
    ic:SetSize(sz, sz)
    if small then ic:SetTexCoord(0, 1, 0, 1) else ic:SetTexCoord(0.08, 0.92, 0.08, 0.92) end
    ic:SetTexture(tex)
end

local function PaintItems()
    local boss = U.boss
    local items = boss and boss.items or {}
    local maxOff = max(0, #items - LOOT_ROWS)
    U.lOff = min(maxOff, max(0, U.lOff))
    U.lootTitle:SetText(boss and Azaath.Upper(BName(boss)) or "")
    U.lootMedal:SetShown(boss and true or false)
    if boss then SetPortrait(U.lootMedal, boss) end
    local usable = 0
    for _, it in ipairs(items) do
        it.usable = Usable(it.id, U.class)
        if it.usable then usable = usable + 1 end
    end
    local sub = ""
    if boss then
        sub = #items > 0 and format("%d %s", #items, #items == 1 and "item" or "itens") or "Espólio ainda não publicado"
        if #items > 0 and U.class ~= "ALL" then sub = format("%s  ·  %d para %s", sub, usable, ClassName(U.class)) end
    end
    U.lootSub:SetText(sub)
    for i = 1, LOOT_ROWS do
        local row, it = U.loot[i], items[i + U.lOff]
        row.item, row.quest = it, nil
        if it then
            local e, meta = ItemInfo(it.id)
            local q = meta.quality or (e and e.quality) or 1
            local qc = QC[q] or QC[1]
            SetRowIcon(row, meta.icon)
            row.mapBtn:Hide()
            row.name:SetPoint("RIGHT", -148, 0)
            row.sub:SetPoint("RIGHT", -148, 0)
            row.medal.icon:SetDesaturated(not it.usable)
            row.medal.rim:SetVertexColor(qc[1], qc[2], qc[3], 0.9)
            row.name:SetText((e and SD.ItemName(e, meta)) or meta.name or ("Item #" .. it.id))
            row.name:SetTextColor(qc[1], qc[2], qc[3])
            local s = meta.slot or meta.subType or ""
            if meta.subType and meta.slot and meta.subType ~= meta.slot then s = meta.slot .. "  ·  " .. meta.subType end
            if meta.iLevel and meta.iLevel > 1 then s = (s ~= "" and s .. "  ·  " or "") .. "iLvl " .. meta.iLevel end
            row.sub:SetText(s)
            row.pct:SetText(it.pct > 0 and format("%.1f%%", it.pct) or "?")
            row.pct:SetTextColor(0.62, 0.98, 0.95)
            row:SetAlpha(it.usable and 1 or 0.38)
            row:Show()
        else
            row:Hide()
        end
    end
end

local function PaintQuests()
    local d = U.dungeon
    local list = DungeonQuests(d)
    U.questList = list
    local maxOff = max(0, #list - LOOT_ROWS)
    U.qOff = min(maxOff, max(0, U.qOff))
    U.lootTitle:SetText(d and Azaath.Upper(DName(d)) or "")
    U.lootMedal:Hide()
    local done, inLog = 0, 0
    for _, v in ipairs(list) do
        if v.state == "done" then done = done + 1 elseif v.state == "log" or v.state == "ready" then inLog = inLog + 1 end
    end
    U.lootSub:SetText(#list > 0 and format("%d %s  ·  %d %s  ·  %d no diário", #list, #list == 1 and "missão" or "missões",
        done, done == 1 and "concluída" or "concluídas", inLog) or "Nenhuma missão conhecida para este local")
    local pt = IsPt()
    for i = 1, LOOT_ROWS do
        local row, v = U.loot[i], list[i + U.qOff]
        row.item, row.quest = nil, v
        if v then
            local st = QSTATE[v.state]
            SetRowIcon(row, st[4], true)
            local tMap, _, _, _, turnIn = M.QuestTarget(v)
            row.mapBtn:SetShown(tMap ~= nil)
            if tMap then row.mapBtn.label:SetText(turnIn and "ONDE ENTREGAR" or "ONDE PEGAR") end
            local rgt = tMap and -274 or -148
            row.name:SetPoint("RIGHT", rgt, 0)
            row.sub:SetPoint("RIGHT", rgt, 0)
            row.medal.icon:SetDesaturated(v.state == "low")
            row.medal.rim:SetVertexColor(st[2][1], st[2][2], st[2][3], 0.9)
            row.name:SetText(QTitle(v.q, pt))
            row.name:SetTextColor(C.CREAM[1], C.CREAM[2], C.CREAM[3])
            local parts, cur = {}, v.cur
            if #v.chain > 1 and v.state ~= "done" then
                parts[#parts + 1] = cur ~= v.q and format("Etapa %d/%d: %s", v.step, #v.chain, QTitle(cur, pt))
                    or format("Etapa final (%d/%d)", v.step, #v.chain)
            end
            if v.state == "log" or v.state == "ready" then
                if cur.ender then parts[#parts + 1] = "Entregar: " .. QEnder(cur, pt) .. (MapName(cur.emap) and (" (" .. MapName(cur.emap) .. ")") or "") end
            elseif v.state ~= "done" then
                if cur.flags:find("i", 1, true) then parts[#parts + 1] = "Começa dentro da masmorra"
                elseif cur.flags:find("d", 1, true) and not cur.npc then parts[#parts + 1] = "Começa com um item"
                elseif cur.npc then parts[#parts + 1] = "Pegar: " .. QNpc(cur, pt) .. (MapName(cur.map) and (" (" .. MapName(cur.map) .. ")") or "") end
            end
            if v.q.level then parts[#parts + 1] = "Nv " .. v.q.level end
            if not v.classOk then parts[#parts + 1] = "Só " .. v.q.classes:gsub("%u+", ClassName):gsub(",", "/") end
            local s = table.concat(parts, "  ·  ")
            if v.party > 0 then s = s .. format("  ·  |cff8ce0ff+%d do grupo|r", v.party) end
            row.sub:SetText(s)
            row.pct:SetText(v.state == "low" and format(st[1], v.cur.minLevel or 0) or st[1])
            row.pct:SetTextColor(st[2][1], st[2][2], st[2][3])
            row:SetAlpha(v.classOk and (v.state == "done" and 0.6 or 1) or 0.38)
            row:Show()
        else
            row:Hide()
        end
    end
end

local function PaintLoot()
    local quest = U.mode == "quests"
    if U.tabs then
        U.tabs.loot:SetActiveState(not quest, C.CYAN)
        U.tabs.quests:SetActiveState(quest, C.GOLD)
        local n = QuestCount(U.dungeon)
        U.tabs.quests.label:SetText(n > 0 and format("MISSÕES (%d)", n) or "MISSÕES")
    end
    if U.classBar then U.classBar:SetShown(not quest) end
    if U.questHint then U.questHint:SetShown(quest) end
    if quest then PaintQuests() else PaintItems() end
end

local T_DONE = "|TInterface\\RaidFrame\\ReadyCheck-Ready:14:14|t "
local T_NOW = "|TInterface\\RaidFrame\\ReadyCheck-Waiting:14:14|t "

local function ItemList(ids)
    local CI, names = _G.C_Item, {}
    for _, id in ipairs(ids) do
        local n = CI and QCall(CI.GetItemNameByID, id)
        if not n and CI then QCall(CI.RequestLoadItemDataByID, id) end
        local q = CI and QCall(CI.GetItemQualityByID, id)
        local col = q and _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[q]
        names[#names + 1] = (col and col.hex or "|cffffffff") .. (n or ("Item #" .. id)) .. "|r"
    end
    return table.concat(names, ", ")
end

local function PartyNames(questID)
    local out = {}
    if not (_G.C_QuestLog and _G.C_QuestLog.IsUnitOnQuest) then return out end
    for i = 1, 4 do
        local unit = "party" .. i
        if UnitExists(unit) and QCall(_G.C_QuestLog.IsUnitOnQuest, unit, questID) then
            local n = UnitName(unit)
            if n and not Azaath.IsSecret(n) then out[#out + 1] = n end
        end
    end
    return out
end

function M.QuestTooltip(owner, v)
    local pt, q, cur = IsPt(), v.q, v.cur
    local st = QSTATE[v.state]
    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(QTitle(q, pt), 1, 0.82, 0.3)
    GameTooltip:AddLine(format("Nível %s%s  ·  %s", q.level or "?", q.minLevel and format(" (mín. %d)", q.minLevel) or "",
        v.state == "low" and format(st[1], cur.minLevel or 0) or st[1]), st[2][1], st[2][2], st[2][3])
    if q.objective then GameTooltip:AddLine(QObjective(q, pt), 0.85, 0.85, 0.85, true) end
    if q.tip then GameTooltip:AddLine("Dica: " .. QTip(q, pt), 0.55, 0.88, 1, true) end
    local tags = {}
    if q.flags:find("b", 1, true) then tags[#tags + 1] = "introdutória" end
    if q.flags:find("o", 1, true) then tags[#tags + 1] = "opcional" end
    if q.flags:find("r", 1, true) then tags[#tags + 1] = "repetível" end
    if q.flags:find("f", 1, true) then tags[#tags + 1] = "nova do Forever" end
    if #tags > 0 then GameTooltip:AddLine("Missão " .. table.concat(tags, ", "), 0.6, 0.6, 0.6) end
    if #v.chain > 1 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(format("CADEIA  (%d etapas)", #v.chain), 0.79, 0.66, 0.42)
        for _, s in ipairs(v.chain) do
            local done = QDone(s)
            local mark = done and T_DONE or (s == cur and v.state ~= "done" and T_NOW or "      ")
            local who = s.npc and ("  |cff8a8a8a" .. QNpc(s, pt) .. "|r") or (s.flags:find("i", 1, true) and "  |cff8a8a8adentro|r" or "")
            if done then
                GameTooltip:AddLine(mark .. QTitle(s, pt) .. who, 0.50, 0.78, 0.50)
            else
                GameTooltip:AddLine(mark .. QTitle(s, pt) .. who, 0.93, 0.90, 0.83)
            end
        end
    end
    if v.state ~= "done" then
        GameTooltip:AddLine(" ")
        if cur.npc then
            GameTooltip:AddDoubleLine("Pegar com", QNpc(cur, pt) .. (MapName(cur.map) and ("  (" .. MapName(cur.map) .. ")") or ""), 0.6, 0.6, 0.6, 1, 1, 1)
        elseif cur.flags:find("i", 1, true) then
            GameTooltip:AddDoubleLine("Começa", "dentro da masmorra", 0.6, 0.6, 0.6, 1, 1, 1)
        elseif cur.item then
            GameTooltip:AddDoubleLine("Começa com", ItemList({ cur.item }), 0.6, 0.6, 0.6, 1, 1, 1)
        end
        if cur.ender then
            GameTooltip:AddDoubleLine("Entregar a", QEnder(cur, pt) .. (MapName(cur.emap) and ("  (" .. MapName(cur.emap) .. ")") or ""), 0.6, 0.6, 0.6, 1, 1, 1)
        end
    end
    if q.choices or q.rewards then
        GameTooltip:AddLine(" ")
        if q.choices then GameTooltip:AddLine("Escolha uma: " .. ItemList(q.choices), 0.8, 0.8, 0.8, true) end
        if q.rewards then GameTooltip:AddLine("Recebe: " .. ItemList(q.rewards), 0.8, 0.8, 0.8, true) end
    end
    local party = v.state ~= "done" and PartyNames(v.logID or cur.id) or {}
    if #party > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Do grupo nesta missão: " .. table.concat(party, ", "), 0.55, 0.88, 1, true)
    end
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine("Clique: pin fixo no mapa   ·   Shift + clique: link no chat", 0.5, 0.5, 0.5)
    GameTooltip:Show()
end

-- onde ir: quem entrega (missão no diário) ou quem dá a etapa atual; nil sem posição conhecida
function M.QuestTarget(v)
    local pt, cur = IsPt(), v.cur
    if v.state == "done" then return end
    if (v.state == "log" or v.state == "ready") and cur.emap and cur.ex and cur.ey then
        return cur.emap, cur.ex, cur.ey, QEnder(cur, pt), true
    end
    if cur.map and cur.x and cur.y then
        return cur.map, cur.x, cur.y, QNpc(cur, pt), false
    end
end

-- pin fixo no mapa do Azaath (o mesmo do Ctrl+clique: salvo, seguido pela navegação e só some quando
-- o jogador o remove com Ctrl+clique). Sem o mapa, só o destino da navegação. -> true se fez o pin
local function PinQuest(v, map, x, y, who, turnIn)
    local title = QTitle(v.cur, IsPt())
    local note = format("%s %s", turnIn and "Entregar a" or "Pegar com", who or "?")
    local wm = Azaath:GetModule("WorldMap")
    if wm and wm.api and wm.api.AddUserPin and wm.db then
        wm.api.AddUserPin(map, x, y, title, note)
        return true
    end
    local qn = Azaath:GetModule("QuestNav")
    if qn and qn.SetCustomWaypoint then qn:SetCustomWaypoint(map, x, y, title .. " - " .. note) end
end

-- leva ao mapa do Azaath: fecha a ficha, abre o mapa no ponto e deixa o pin fixo (com navegação)
function M.QuestOnMap(v)
    local map, x, y, who, turnIn = M.QuestTarget(v)
    if not (map and x and y) then return end
    SD.PlayClick()
    local sheet = Azaath:GetModule("Sheet")
    if sheet and sheet.Close then sheet:Close() end
    local wm = Azaath:GetModule("WorldMap")
    if wm and wm.Open then wm:Open(map) end
    PinQuest(v, map, x, y, who, turnIn)
    if wm and wm.api and wm.api.FocusMapXY then wm.api.FocusMapXY(map, x, y) end
end

function M.QuestClick(v)
    local pt, cur = IsPt(), v.cur
    if _G.IsModifiedClick and _G.IsModifiedClick("CHATLINK") then
        local link = format("|cffffff00|Hquest:%d:%d|h[%s]|h|r", v.q.id, v.q.level or 0, QTitle(v.q, pt))
        if _G.ChatEdit_InsertLink then _G.ChatEdit_InsertLink(link) end
        return
    end
    local map, x, y, who, turnIn = M.QuestTarget(v)
    if not (map and x and y) then
        Azaath:Print("Sem posição conhecida para \"%s\"", QTitle(cur, pt))
        return
    end
    SD.PlayClick()
    local pinned = PinQuest(v, map, x, y, who, turnIn)
    Azaath:Print("%s: %s  (%s)", pinned and "Pin fixo no mapa" or "Marcado no mapa", who or QTitle(cur, pt), MapName(map) or "?")
end

local function PaintBosses()
    local d = U.dungeon
    local bosses = d and d.bosses or {}
    local maxOff = max(0, #bosses - BOSS_ROWS)
    U.bOff = min(maxOff, max(0, U.bOff))
    U.dTitle:SetText(d and Azaath.Upper(DName(d)) or "")
    SetArt(U.banner, d, 424, 156)
    U.dSub:SetText(d and format("%s  ·  Nível %s%s", DLoc(d), d.level ~= "" and d.level or "?",
        d.raid and "  ·  RAIDE" or "") or "")
    for i = 1, BOSS_ROWS do
        local row, b = U.bossRows[i], bosses[i + U.bOff]
        row.boss = b
        if b then
            row.name:SetText(BName(b))
            row.count:SetText(#b.items > 0 and tostring(#b.items) or "—")
            SetPortrait(row.medal, b)
            SetRowState(row, U.boss == b, row.hover)
            row:Show()
        else
            row:Hide()
        end
    end
    PaintLoot()
end

local function PaintList()
    local list = Filtered()
    U.list = list
    local maxOff = max(0, #list - LIST_ROWS)
    U.dOff = min(maxOff, max(0, U.dOff))
    U.count:SetText(format("%d %s", #list, #list == 1 and "local" or "locais"))
    for i = 1, LIST_ROWS do
        local row, d = U.rows[i], list[i + U.dOff]
        row.dungeon = d
        if d then
            row.name:SetText(DName(d))
            local nq = QuestCount(d)
            row.sub:SetText(format("Nível %s  ·  %d %s%s", d.level ~= "" and d.level or "?", #d.bosses, #d.bosses == 1 and "chefe" or "chefes",
                nq > 0 and format("  ·  %d %s", nq, nq == 1 and "missão" or "missões") or ""))
            row.tag:SetShown(d.raid)
            SetArt(row.art, d, 452, ROW_H - 16)
            SetRowState(row, U.dungeon == d, row.hover)
            row:Show()
        else
            row:Hide()
        end
    end
    for k, p in pairs(U.filterPills) do p:SetActiveState(U.filter == k, C.CYAN) end
end

local function SelectDungeon(d, boss)
    U.dungeon = d
    U.boss = boss or (d and d.bosses[1])
    U.bOff, U.lOff, U.qOff = 0, 0, 0
    if boss then U.mode = "loot" end
    if boss and boss.index > BOSS_ROWS then U.bOff = boss.index - BOSS_ROWS end
    PaintList()
    PaintBosses()
end

function M:Refresh()
    if not (U.page and U.page:IsShown()) then return end
    EnsureCatalog()
    if not U.dungeon then
        local list = Filtered()
        SelectDungeon(list[1])
    else
        PaintList()
        PaintBosses()
    end
end

-- Abre a aba já no chefe (botão VER CHEFE da aba Drops)
function M:ShowBoss(key)
    EnsureCatalog()
    local b = key and byKey[key]
    if not b then return false end
    U.filter, U.query = "all", ""
    if U.search then U.search:SetText("") end
    local list = Filtered()
    for i, d in ipairs(list) do
        if d == b.dungeon then U.dOff = max(0, i - floor(LIST_ROWS / 2)) break end
    end
    U.dungeon, U.boss = nil, nil
    local sheet = Azaath:GetModule("Sheet")
    if sheet and sheet.Open then sheet:Open("dungeons") end
    SelectDungeon(b.dungeon, b)
    return true
end

--------------------------------------------------------------------------------
-- Construção
--------------------------------------------------------------------------------
local function Panel(art, x, y, w, h, title)
    local p = CreateFrame("Frame", nil, art)
    p:SetPoint("TOPLEFT", art, "TOPLEFT", x, y)
    p:SetSize(w, h)
    p:SetFrameLevel(art:GetFrameLevel() + 2)
    local bg = p:CreateTexture(nil, "BACKGROUND", nil, 0)
    bg:SetPoint("TOPLEFT", 6, -6)
    bg:SetPoint("BOTTOMRIGHT", -6, 6)
    Azaath.Gradient(bg, "VERTICAL", 0.018, 0.040, 0.090, 0.94, 0.038, 0.082, 0.165, 0.94)
    p.skin = H.Skin(p, "DropPanel", 0.62, "BORDER", 1)
    if title then
        p.title = H.Txt(p, U.F.C, 22, C.GOLD_HI, "CENTER")
        p.title:SetPoint("TOP", 0, -22)
        p.title:SetText(title)
    end
    return p
end

local function MakeRow(parent, w, h)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(w, h)
    row.skin = H.Skin(row, "WideN", 0.46, "BACKGROUND", 1)
    row.beam = row:CreateTexture(nil, "OVERLAY", nil, 2)
    row.beam:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\UnitFrames\\ClassicGlassH")
    row.beam:SetBlendMode("ADD")
    row.beam:SetHeight(2.5)
    row.beam:SetPoint("BOTTOMLEFT", 30, 2)
    row.beam:SetPoint("BOTTOMRIGHT", -30, 2)
    row.beam:SetVertexColor(C.CYAN[1], C.CYAN[2], C.CYAN[3], 1)
    row.beam:SetAlpha(0)
    row:SetScript("OnEnter", function(self)
        self.hover = true
        SetRowState(self, (self.dungeon and self.dungeon == U.dungeon) or (self.boss and self.boss == U.boss), true)
    end)
    row:SetScript("OnLeave", function(self)
        self.hover = false
        SetRowState(self, (self.dungeon and self.dungeon == U.dungeon) or (self.boss and self.boss == U.boss), false)
    end)
    return row
end

local function Wheel(frame, field, paint)
    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(_, delta)
        U[field] = max(0, U[field] - delta)
        paint()
    end)
end

local function BuildCatalogPanel(art)
    local p = Panel(art, 34, -104, 520, 950, "MASMORRAS & RAIDES")
    U.count = H.Txt(p, U.F.B, 13, C.MUTED, "CENTER")
    U.count:SetPoint("TOP", 0, -52)

    U.filterPills = {}
    local defs = { { "all", "Todas" }, { "dungeon", "Masmorras" }, { "raid", "Raides" } }
    for i, def in ipairs(defs) do
        local pill = H.Pill(p, 144, 34, def[2], 13, C.TEXT_HI, "PillN", 34 / 54)
        pill:SetPoint("TOPLEFT", 34 + (i - 1) * 152, -78)
        pill:SetScript("OnClick", function()
            SD.PlayClick()
            U.filter, U.dOff = def[1], 0
            PaintList()
        end)
        U.filterPills[def[1]] = pill
    end

    local sbFrame = CreateFrame("Frame", nil, p)
    sbFrame:SetSize(452, 38)
    sbFrame:SetPoint("TOP", 0, -124)
    H.Skin(sbFrame, "Search", 38 / 87, "BACKGROUND", 1)
    local sb = CreateFrame("EditBox", nil, sbFrame)
    sb:SetPoint("TOPLEFT", 40, -4)
    sb:SetPoint("BOTTOMRIGHT", -24, 4)
    sb:SetAutoFocus(false)
    sb:SetFont(U.F.B, 14, "")
    sb:SetTextColor(C.CREAM[1], C.CREAM[2], C.CREAM[3])
    local hint = H.Txt(sbFrame, U.F.B, 14, C.DIM, "LEFT")
    hint:SetPoint("LEFT", 42, 0)
    hint:SetText("Buscar masmorra...")
    sb:SetScript("OnTextChanged", function(self)
        U.query = self:GetText() or ""
        hint:SetShown(U.query == "")
        U.dOff = 0
        PaintList()
    end)
    sb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    sb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    U.search = sb

    U.rows = {}
    for i = 1, LIST_ROWS do
        local row = MakeRow(p, 452, ROW_H - 16)
        row:SetPoint("TOP", 0, -176 - (i - 1) * ROW_H)
        row.thin = true
        row.edges = {}
        for _, e in ipairs({ { "TOPLEFT", "TOPRIGHT", false }, { "BOTTOMLEFT", "BOTTOMRIGHT", false },
                             { "TOPLEFT", "BOTTOMLEFT", true }, { "TOPRIGHT", "BOTTOMRIGHT", true } }) do
            local t = row:CreateTexture(nil, "OVERLAY", nil, 1)
            t:SetColorTexture(C.CYAN[1], C.CYAN[2], C.CYAN[3], 1)
            t:SetPoint(e[1])
            t:SetPoint(e[2])
            if e[3] then t:SetWidth(1.5) else t:SetHeight(1.5) end
            t:SetAlpha(0)
            row.edges[#row.edges + 1] = t
        end
        row.glow = row:CreateTexture(nil, "BACKGROUND", nil, 4)
        row.glow:SetAllPoints(row)
        row.glow:SetColorTexture(0.55, 0.85, 1, 1)
        row.glow:SetBlendMode("ADD")
        row.glow:SetAlpha(0)
        for i = 1, 9 do row.skin.t[i]:Hide() end
        row.skin.dTop:Hide(); row.skin.dBot:Hide(); row.skin.flare:Hide()
        row.art = row:CreateTexture(nil, "BACKGROUND", nil, 2)
        row.art:SetAllPoints(row)
        row.shade = row:CreateTexture(nil, "BACKGROUND", nil, 3)
        row.shade:SetPoint("TOPLEFT")
        row.shade:SetPoint("BOTTOMLEFT")
        row.shade:SetWidth(300)
        Azaath.Gradient(row.shade, "HORIZONTAL", 0.01, 0.02, 0.045, 0.45, 0.01, 0.02, 0.045, 0)
        row.name = H.Txt(row, U.F.C, 17, C.CREAM, "LEFT")
        row.name:SetPoint("TOPLEFT", 26, -12)
        row.name:SetPoint("RIGHT", -84, 0)
        row.sub = H.Txt(row, U.F.B, 12, C.MUTED, "LEFT")
        row.sub:SetPoint("BOTTOMLEFT", 26, 12)
        row.tag = H.Txt(row, U.F.CB or U.F.C, 12, C.GOLD, "RIGHT")
        row.tag:SetPoint("RIGHT", -24, 0)
        row.tag:SetText("RAIDE")
        row:SetScript("OnClick", function(self)
            if not self.dungeon then return end
            SD.PlayClick()
            SelectDungeon(self.dungeon)
        end)
        U.rows[i] = row
    end
    Wheel(p, "dOff", PaintList)
end

local function BuildBossPanel(art)
    local p = Panel(art, 572, -104, 470, 950)
    -- estandarte: a arte da masmorra no alto do painel, com o nome por cima
    -- num quadro próprio, acima do miolo da moldura do painel (que é opaco)
    local bf = CreateFrame("Frame", nil, p)
    bf:SetAllPoints(p)
    bf:SetFrameLevel(p:GetFrameLevel() + 1)
    U.banner = bf:CreateTexture(nil, "BACKGROUND", nil, 2)
    U.banner:SetSize(424, 156)
    U.banner:SetPoint("TOP", 0, -20)
    local bShade = bf:CreateTexture(nil, "BACKGROUND", nil, 3)
    bShade:SetAllPoints(U.banner)
    Azaath.Gradient(bShade, "VERTICAL", 0.01, 0.02, 0.045, 0.96, 0.01, 0.02, 0.045, 0.05)
    local bBeam = bf:CreateTexture(nil, "BORDER", nil, 2)
    bBeam:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\UnitFrames\\ClassicGlassH")
    bBeam:SetBlendMode("ADD")
    bBeam:SetHeight(2.5)
    bBeam:SetPoint("BOTTOMLEFT", U.banner, "BOTTOMLEFT", 20, 0)
    bBeam:SetPoint("BOTTOMRIGHT", U.banner, "BOTTOMRIGHT", -20, 0)
    bBeam:SetVertexColor(C.GOLD[1], C.GOLD[2], C.GOLD[3], 0.8)
    -- moldura dourada em volta da arte (a mesma peça das caixas da aba Drops, sem o miolo)
    local frameBox = CreateFrame("Frame", nil, bf)
    frameBox:SetAllPoints(U.banner)
    frameBox:SetFrameLevel(bf:GetFrameLevel() + 1)
    local fsk = H.Skin(frameBox, "DropSquare", 0.42, "BORDER", 1)
    fsk:SetCenterAlpha(0)
    U.dTitle = H.Txt(bf, U.F.C, 22, C.GOLD_HI, "CENTER")
    U.dTitle:SetPoint("BOTTOM", U.banner, "BOTTOM", 0, 24)
    U.dTitle:SetWidth(400)
    U.dSub = H.Txt(bf, U.F.B, 13, C.TEXT_HI, "CENTER")
    U.dSub:SetPoint("TOP", U.banner, "BOTTOM", 0, -14) -- fora do estandarte: a moldura cortava o texto
    U.dSub:SetWidth(400)
    local head = H.Txt(p, U.F.CB or U.F.C, 13, C.CYAN, "LEFT")
    head:SetPoint("TOPLEFT", 40, -214)
    head:SetText("CHEFES")
    local headR = H.Txt(p, U.F.CB or U.F.C, 13, C.CYAN, "RIGHT")
    headR:SetPoint("TOPRIGHT", -40, -214)
    headR:SetText("ITENS")

    U.bossRows = {}
    for i = 1, BOSS_ROWS do
        local row = MakeRow(p, 410, BOSS_H - 6)
        row:SetPoint("TOP", 0, -238 - (i - 1) * BOSS_H)
        row.medal = H.CircleIcon(row, 40, 48, "bezel")
        row.medal:SetPoint("LEFT", 16, 0)
        row.name = H.Txt(row, U.F.C, 15, C.CREAM, "LEFT")
        row.name:SetPoint("LEFT", 72, 0)
        row.name:SetPoint("RIGHT", -70, 0)
        row.count = H.Txt(row, U.F.B, 14, C.GOLD_HI, "RIGHT")
        row.count:SetPoint("RIGHT", -26, 0)
        row:SetScript("OnClick", function(self)
            if not self.boss then return end
            SD.PlayClick()
            U.boss, U.lOff, U.mode = self.boss, 0, "loot"
            PaintBosses()
        end)
        U.bossRows[i] = row
    end
    Wheel(p, "bOff", PaintBosses)
end

local function BuildLootPanel(art)
    local p = Panel(art, 1060, -104, 826, 950)
    U.lootMedal = H.CircleIcon(p, 52, 62, "bezel")
    U.lootMedal:SetPoint("TOPLEFT", 40, -16)
    U.lootTitle = H.Txt(p, U.F.C, 22, C.GOLD_HI, "CENTER")
    U.lootTitle:SetPoint("TOP", -110, -24)
    U.lootTitle:SetWidth(400)
    U.lootSub = H.Txt(p, U.F.B, 13, C.MUTED, "CENTER")
    U.lootSub:SetPoint("TOP", -110, -60)
    U.lootSub:SetWidth(440)

    -- ESPÓLIO / MISSÕES
    U.tabs = {}
    for i, def in ipairs({ { "quests", "MISSÕES" }, { "loot", "ESPÓLIO" } }) do
        local pill = H.Pill(p, 132, 32, def[2], 12, C.TEXT_HI, "PillN", 32 / 54)
        pill:SetPoint("TOPRIGHT", -34 - (i - 1) * 140, -22)
        pill:SetScript("OnClick", function()
            if U.mode == def[1] then return end
            SD.PlayClick()
            U.mode = def[1]
            PaintLoot()
        end)
        U.tabs[def[1]] = pill
    end

    -- barra de classes do espólio: apaga o que a classe não usa
    local bar = CreateFrame("Frame", nil, p)
    bar:SetSize(760, 34)
    bar:SetPoint("BOTTOM", 0, 14)
    U.classBar = bar
    local lbl = H.Txt(bar, U.F.CB or U.F.C, 12, C.CYAN, "LEFT")
    lbl:SetPoint("LEFT", 8, 0)
    lbl:SetText("CLASSE")
    local classes = { "ALL" }
    for _, c in ipairs(CLASSES) do classes[#classes + 1] = c end
    local mine = select(2, UnitClass("player"))
    if mine and not tContains(classes, mine) then classes[#classes + 1] = mine end
    U.classBtns = {}
    local function PaintClassBar()
        for _, b in ipairs(U.classBtns) do
            local on = b.class == U.class
            b.icon:SetDesaturated(not on)
            b.icon:SetAlpha(on and 1 or (b.hover and 0.9 or 0.55))
            b.sel:SetShown(on)
        end
    end
    for i, cls in ipairs(classes) do
        local b = CreateFrame("Button", nil, bar)
        b:SetSize(30, 30)
        b:SetPoint("LEFT", 80 + (i - 1) * 38, 0)
        b.class = cls
        b.icon = b:CreateTexture(nil, "ARTWORK")
        b.icon:SetAllPoints(b)
        local tc = _G.CLASS_ICON_TCOORDS and _G.CLASS_ICON_TCOORDS[cls]
        if tc then
            b.icon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
            b.icon:SetTexCoord(tc[1], tc[2], tc[3], tc[4])
        else
            H.SkillIconTex(b.icon, "great", 4)
        end
        b.sel = b:CreateTexture(nil, "OVERLAY")
        b.sel:SetTexture("Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\UnitFrames\\ClassicGlassH")
        b.sel:SetBlendMode("ADD")
        b.sel:SetHeight(2.5)
        b.sel:SetPoint("TOPLEFT", b, "BOTTOMLEFT", 2, -3)
        b.sel:SetPoint("TOPRIGHT", b, "BOTTOMRIGHT", -2, -3)
        b.sel:SetVertexColor(C.CYAN[1], C.CYAN[2], C.CYAN[3], 1)
        b:SetScript("OnEnter", function(self)
            self.hover = true
            PaintClassBar()
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(ClassName(self.class), 1, 1, 1)
            GameTooltip:AddLine(self.class == "ALL" and "Mostra todo o espólio aceso"
                or "Apaga o que esta classe não pode usar", 0.7, 0.7, 0.7)
            GameTooltip:Show()
        end)
        b:SetScript("OnLeave", function(self)
            self.hover = false
            PaintClassBar()
            GameTooltip:Hide()
        end)
        b:SetScript("OnClick", function(self)
            SD.PlayClick()
            U.class = self.class
            Azaath.db.dungeonClass = self.class
            PaintClassBar()
            PaintLoot()
        end)
        U.classBtns[i] = b
    end
    U.PaintClassBar = PaintClassBar
    local hint = H.Txt(bar, U.F.B, 12, C.DIM, "RIGHT")
    hint:SetPoint("RIGHT", -8, 0)
    hint:SetText("Shift + clique: link no chat")

    U.questHint = H.Txt(p, U.F.B, 12, C.DIM, "CENTER")
    U.questHint:SetPoint("BOTTOM", 0, 22)
    U.questHint:SetText("ONDE PEGAR: abre o mapa com um pin fixo (Ctrl + clique no pin remove)   ·   Clique na linha: só fixa o pin   ·   Shift + clique: link")
    U.questHint:Hide()

    U.loot = {}
    for i = 1, LOOT_ROWS do
        local row = CreateFrame("Button", nil, p)
        row:SetSize(760, LOOT_H - 8)
        row:SetPoint("TOP", 0, -92 - (i - 1) * LOOT_H)
        row.skin = H.Skin(row, "WideN", 0.5, "BACKGROUND", 1)
        row.skin:SetAlpha(0.72)
        row.medal = H.CircleIcon(row, 44, 54, "bezel")
        row.medal:SetPoint("LEFT", 22, 0)
        row.name = H.Txt(row, U.F.C, 16, C.CREAM, "LEFT")
        row.name:SetPoint("TOPLEFT", 90, -14)
        row.name:SetPoint("RIGHT", -148, 0)
        row.sub = H.Txt(row, U.F.B, 12, C.MUTED, "LEFT")
        row.sub:SetPoint("BOTTOMLEFT", 90, 14)
        row.sub:SetPoint("RIGHT", -148, 0)
        row.pctPill = H.Skin(CreateFrame("Frame", nil, row), "PillA", 30 / 60, "BACKGROUND", 1)
        row.pctFrame = row.pctPill.f
        row.pctFrame:SetSize(112, 30)
        row.pctFrame:SetPoint("RIGHT", -22, 0)
        row.pct = H.Txt(row.pctFrame, U.F.B, 13, { 0.62, 0.98, 0.95 }, "CENTER")
        row.pct:SetPoint("CENTER")
        -- missões: leva ao mapa com o pin de onde pegar/entregar
        row.mapBtn = H.Pill(row, 116, 26, "ONDE PEGAR", 10, { 1, 1, 1 }, "PillA")
        row.mapBtn:SetPoint("RIGHT", row.pctFrame, "LEFT", -10, 0)
        row.mapBtn.keepBaseColor = true
        row.mapBtn.accent = C.GOLD
        row.mapBtn:SetScript("OnClick", function(self)
            local v = self:GetParent().quest
            if v then M.QuestOnMap(v) end
        end)
        row.mapBtn:HookScript("OnEnter", function(self)
            local v = self:GetParent().quest
            local map, _, _, who, turnIn = v and M.QuestTarget(v)
            if not map then return end
            GameTooltip:SetOwner(self, "ANCHOR_TOP")
            GameTooltip:SetText(turnIn and "Onde entregar" or "Onde pegar", 1, 0.82, 0.3)
            GameTooltip:AddLine((who or "?") .. (MapName(map) and ("  (" .. MapName(map) .. ")") or ""), 1, 1, 1)
            GameTooltip:AddLine("Abre o mapa com um pin fixo (Ctrl + clique no pin remove)", 0.6, 0.6, 0.6)
            GameTooltip:Show()
        end)
        row.mapBtn:HookScript("OnLeave", function() GameTooltip:Hide() end)
        row.mapBtn:Hide()
        row:SetScript("OnEnter", function(self)
            self.skin:SetAlpha(1)
            if self.quest then
                M.QuestTooltip(self, self.quest)
                return
            end
            if not self.item then return end
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            local ok = pcall(GameTooltip.SetItemByID, GameTooltip, self.item.id)
            if not ok then GameTooltip:AddLine(self.name:GetText() or "") end
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function(self)
            self.skin:SetAlpha(0.72)
            GameTooltip:Hide()
        end)
        row:SetScript("OnClick", function(self)
            if self.quest then
                M.QuestClick(self.quest)
                return
            end
            if not self.item then return end
            if _G.IsModifiedClick and _G.IsModifiedClick("CHATLINK") and SD.LinkItemToChat then
                local e = ItemInfo(self.item.id)
                SD.LinkItemToChat(e or { id = self.item.id, name = self.name:GetText() })
            end
        end)
        row:Hide()
        U.loot[i] = row
    end
    p:EnableMouseWheel(true)
    p:SetScript("OnMouseWheel", function(_, delta)
        local field = U.mode == "quests" and "qOff" or "lOff"
        U[field] = max(0, U[field] - delta)
        PaintLoot()
    end)
end

function M:BuildPage(parent, cw, ch)
    if not parent or parent.dungeons then return end
    SD = Azaath:GetModule("SheetDrops")
    if not (SD and SD.H and SD.GetFonts and SD:GetFonts().B) then
        error("a aba Drops precisa ser montada antes da aba Masmorras")
    end
    H, C, QC = SD.H, SD.C, SD.QUALITY_COLORS
    U.F = SD:GetFonts()
    U.page = parent
    parent.dungeons = true
    U.class = Azaath.db and Azaath.db.dungeonClass or select(2, UnitClass("player")) or "ALL"

    local root = parent:GetParent() and parent:GetParent():GetParent() or UIParent
    local art = CreateFrame("Frame", nil, parent)
    art:SetSize(ART_W, ART_H)
    art:SetPoint("CENTER", root, "CENTER", 0, 0)
    art:SetFrameLevel(parent:GetFrameLevel())
    local function Fit()
        local w, h = root:GetWidth(), root:GetHeight()
        if not (w and h and w > 0 and h > 0) then w, h = UIParent:GetWidth(), UIParent:GetHeight() end
        art:SetScale(max(w / ART_W, h / ART_H))
    end
    Fit()
    parent:HookScript("OnShow", function() Fit(); M:Refresh() end)

    local bg = art:CreateTexture(nil, "BACKGROUND", nil, -1)
    bg:SetTexture(SHEET_MEDIA .. "ProfessionsBG")
    bg:SetTexCoord(0, ART_W / 2048, 0, ART_H / 2048)
    bg:SetAllPoints(art)
    local veil = art:CreateTexture(nil, "BACKGROUND", nil, 0)
    veil:SetAllPoints(art)
    veil:SetColorTexture(0.01, 0.024, 0.042, 0.24)

    BuildCatalogPanel(art)
    BuildBossPanel(art)
    BuildLootPanel(art)
    U.PaintClassBar()

    -- itens/missões ainda não carregados no cliente e mudanças no diário ou no grupo: repinta
    local ev, pending = CreateFrame("Frame", nil, parent), 0
    for _, e in ipairs({ "GET_ITEM_INFO_RECEIVED", "QUEST_DATA_LOAD_RESULT", "QUEST_LOG_UPDATE", "QUEST_TURNED_IN",
                         "GROUP_ROSTER_UPDATE", "UNIT_QUEST_LOG_CHANGED", "PLAYER_LEVEL_UP" }) do
        pcall(ev.RegisterEvent, ev, e)
    end
    ev:SetScript("OnEvent", function() pending = 0.2 end)
    ev:SetScript("OnUpdate", function(_, el)
        if pending > 0 then
            pending = pending - el
            if pending <= 0 and parent:IsShown() then PaintLoot() end
        end
    end)
end
