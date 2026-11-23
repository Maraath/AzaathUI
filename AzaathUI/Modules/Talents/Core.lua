--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Talents/Core.lua
    Aba "Talentos" da ficha (tecla C / tecla N): O CRISOL DE AZAATH.

    Réplica da arte de conceito tools/talents-concept/concept_azaath_crucible.jpg:
      * As três árvores aparecem juntas, cada uma brotando do Núcleo Primordial
        (o cristal no centro): Armas em ouro à esquerda, Fúria em brasa embaixo e
        Proteção em ciano à direita. O círculo 1 fica junto do núcleo e o talento
        final (aro ornamentado) na ponta mais distante.
      * Correntes de energia ligam o núcleo a cada círculo e cada círculo aos seus
        talentos; acendem e correm conforme os pontos gastos. Trechos ainda
        bloqueados viram fumaça escura, como na arte.
      * Medalhões com os aros reais da arte: cor da árvore quando liberado,
        aro apagado quando bloqueado; losangos embaixo contam os pontos.
      * Prévia: clique = +1, botão direito = -1; nada é gasto até SELAR INFUSÃO.
        PURIFICAR FLUXO desfaz a prévia.
      * O painel à direita mostra o talento sob o mouse (ou o selecionado).

    Texturas: Media/Talents/Crucible*.tga saem de tools/talents-concept/gen.js.
------------------------------------------------------------------------------]]

local ADDON_NAME, Azaath = ...
local U = {}
Azaath.TalentsUI = U   -- símbolos compartilhados entre os arquivos de Modules/Talents/
local M = Azaath:NewModule("Talents")

local _G = _G
local pairs, format, type, pcall, select, tostring = pairs, string.format, type, pcall, select, tostring

local MEDIA = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\"
local TAL   = MEDIA .. "Talents\\"
local INV   = MEDIA .. "Inventory\\"
local WHITE8 = "Interface\\Buttons\\WHITE8x8"
-- aura dos medalhões (tools/talents-concept/gen-aura.js); grava sobre o arquivo
-- antigo do astrolábio para valer com /reload, sem reiniciar o cliente
local AURA_TEX = TAL .. "TalentDiagramGlow"

-- Dimensões da arte de conceito
local ART_W, ART_H = 1376, 768

-- Paleta Azaath
local CREAM     = { 0.92, 0.90, 0.85 }
local WHITE     = { 0.95, 0.97, 0.99 }
local SUB_COL   = { 0.74, 0.80, 0.86 }
local DESC_COL  = { 0.86, 0.90, 0.94 }
local GOLD      = { 1.00, 0.78, 0.32 }
local EMBER     = { 1.00, 0.46, 0.18 }
local CYAN      = { 0.30, 0.86, 1.00 }
local AZ_BRIGHT = { 0.55, 0.96, 1.00 }
local LOCK_COL  = { 0.95, 0.45, 0.38 }
local PURGE_RED = { 0.92, 0.28, 0.28 }

local TREE_COLORS = { GOLD, EMBER, CYAN }
local LABEL_COLS  = { { 0.90, 0.76, 0.50 }, { 0.95, 0.64, 0.48 }, { 0.70, 0.90, 0.96 } }

-- Geometria das três árvores (coordenadas da arte 1376x768).
-- O eixo dos círculos é a curva S -> C -> E (S = círculo 1, junto ao núcleo;
-- E = último círculo); as colunas se abrem ao longo de "dir", centradas no eixo.
local CORE_X, CORE_Y = 535, 385
local TREES = {
    { S = { 356, 404 }, C = { 246, 292 }, E = { 116, 198 }, dir = { 0.6, -0.8 }, gap = 50,
      anchor = { 412, 326 }, via = { { 392, 372 } }, label = { 196, 146 } },           -- Armas
    { S = { 566, 630 }, C = { 392, 632 }, E = { 222, 585 }, dir = { 0.12, -0.99 }, gap = 50,
      anchor = { 518, 522 }, via = { { 548, 578 } }, label = { 235, 515 } },           -- Fúria
    { S = { 852, 614 }, C = { 820, 407 }, E = { 856, 200 }, dir = { 1, 0 }, gap = 64,
      anchor = { 652, 398 }, via = { { 730, 470 }, { 790, 600 } }, label = { 855, 140 } }, -- Proteção
}
local ICON_R = { normal = 16, single = 18, cap = 21 } -- raio do ícone por tipo de medalhão

-- Painel do talento
local PANEL_X = 1190
local EMBLEM_X, EMBLEM_Y = 1190, 100 + 506 * 300 / 540 -- centro do ícone no card (tools/card-concept)

-- Estado do módulo

local nodeButtons, labels = {}, {}
local top, right, bottom, ambient = {}, {}, {}, {}
local particles, pulses = {}, {}
local segs = {}; U.segCount = 0

U.selKey = nil; U.hovKey = nil
U.specMode = 1
U.clock = 0
local anim = {}
U.treeData = nil
U.dirty = true
local pending = {}       -- prévia local (cliente sem API de prévia): key -> pontos
local applyQueue = {}    -- pontos a aprender um a um
U.applyWait = 0

local scanTip
local traitsInfo = {} -- último config/árvore lidos pelo C_Traits (diagnóstico)
U.lineTiling = true -- some se o cliente não aceitar textura repetida nas linhas

--------------------------------------------------------------------------------
-- Utilitários
--------------------------------------------------------------------------------
local function Call(fn, ...)
    if type(fn) ~= "function" then return nil end
    return select(2, pcall(fn, ...))
end

local function Text(parent, font, size, col, justify, flags)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font or Azaath.media.font, size or 12, flags or "")
    col = col or WHITE
    fs:SetTextColor(col[1], col[2], col[3], col[4] or 1)
    fs:SetJustifyH(justify or "CENTER")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.92)
    fs.baseFont, fs.baseSize, fs.baseFlags = font or Azaath.media.font, size or 12, flags or ""
    return fs
end

local function Tex(parent, layer, path, blend, sub)
    local t = parent:CreateTexture(nil, layer or "ARTWORK", nil, sub or 0)
    if path then t:SetTexture(path) end
    if blend then t:SetBlendMode(blend) end
    return t
end

local function At(region, rel, x, y, point)
    region:ClearAllPoints()
    region:SetPoint(point or "CENTER", rel, "TOPLEFT", x, -y)
end

-- Encolhe a fonte até o texto caber na largura (os textos espaçados estouravam os botões)
local function FitText(fs, text, maxW, minSize)
    local size = fs.baseSize
    fs:SetFont(fs.baseFont, size, fs.baseFlags)
    fs:SetText(text)
    minSize = minSize or 7.5
    while size > minSize and (fs:GetStringWidth() or 0) > maxW do
        size = size - 0.5
        fs:SetFont(fs.baseFont, size, fs.baseFlags)
        fs:SetText(text)
    end
end

local function CircleMask(owner, tex)
    if not (owner.CreateMaskTexture and tex.AddMaskTexture) then return end
    local m = owner:CreateMaskTexture()
    m:SetAllPoints(tex)
    local ok = pcall(m.SetTexture, m, INV .. "RoundMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    if not ok then
        pcall(m.SetTexture, m, "Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
    end
    pcall(tex.AddMaskTexture, tex, m)
end

local function Clamp(v, a, b) if v < a then return a elseif v > b then return b end return v end
local function Damp(a, b, k, dt) return a + (b - a) * (1 - k ^ dt) end
local function EaseOut(u) return 1 - (1 - u) ^ 3 end
local function BackOut(u)
    local c1 = 1.70158
    return 1 + (c1 + 1) * (u - 1) ^ 3 + c1 * (u - 1) ^ 2
end

local function Tracked(s) return Azaath.Tracked and Azaath.Tracked(s) or s end
local function Upper(s) s = s or ""; return Azaath.Upper and Azaath.Upper(s) or s:upper() end

local function Plural(n, one, many) return n == 1 and one or many end

--------------------------------------------------------------------------------
-- Diagnóstico: o que a API de talentos devolveu (AzaathUIDB.talentDiag, /reload grava)
--------------------------------------------------------------------------------
local function Pack(...) return { n = select("#", ...), ... } end
local function Show(t)
    local out = {}
    for i = 1, (t and t.n or 0) do out[#out + 1] = tostring(t[i]) end
    return table.concat(out, ", ")
end

local function WriteDiag()
    if type(AzaathUIDB) ~= "table" then return end
    local d = { time = date and date("%H:%M:%S") or "" }
    local function probe(label, fn, ...)
        if type(fn) ~= "function" then d[label] = "função ausente"; return end
        local r = Pack(pcall(fn, ...))
        d[label] = (r[1] and "ok: " or "erro: ") .. Show({ n = r.n - 1, select(2, unpack(r, 1, r.n)) })
    end
    probe("GetNumTalentTabs()", _G.GetNumTalentTabs)
    probe("GetNumTalentTabs(false,false)", _G.GetNumTalentTabs, false, false)
    probe("GetActiveTalentGroup()", _G.GetActiveTalentGroup)
    probe("GetNumTalentGroups()", _G.GetNumTalentGroups)
    probe("GetUnspentTalentPoints()", _G.GetUnspentTalentPoints)
    probe("UnitCharacterPoints(player)", _G.UnitCharacterPoints, "player")
    probe("GetTalentTabInfo(1)", _G.GetTalentTabInfo, 1)
    probe("GetTalentTabInfo(1,false,false,1)", _G.GetTalentTabInfo, 1, false, false, 1)
    probe("GetNumTalents(1)", _G.GetNumTalents, 1)
    probe("GetNumTalents(1,false,false)", _G.GetNumTalents, 1, false, false)
    probe("GetTalentInfo(1,1)", _G.GetTalentInfo, 1, 1)
    probe("GetTalentInfo(1,1,false,false,1)", _G.GetTalentInfo, 1, 1, false, false, 1)
    probe("GetTalentPrereqs(1,1)", _G.GetTalentPrereqs, 1, 1)
    d.previewAPI = tostring(_G.AddPreviewTalentPoints ~= nil and _G.LearnPreviewTalents ~= nil)
    d.C_SpecializationInfo = tostring(_G.C_SpecializationInfo ~= nil)
    d.C_Traits = tostring(_G.C_Traits ~= nil)
    d.traits = {}
    for k, v in pairs(traitsInfo) do d.traits[k] = tostring(v) end
    local CCT = _G.C_ClassTalents
    probe("C_ClassTalents.GetActiveConfigID()", CCT and CCT.GetActiveConfigID)
    d.lido = U.treeData and format("%d talentos em %d árvores", #U.treeData.nodes, #U.treeData.tabs) or "nada (árvore vazia)"
    AzaathUIDB.talentDiag = d
end

--------------------------------------------------------------------------------
-- Leitura de Descrição via GameTooltip
--------------------------------------------------------------------------------
local function EnsureScanTip()
    if not scanTip then
        scanTip = CreateFrame("GameTooltip", "AzaathTalentsScanTip", UIParent, "GameTooltipTemplate")
    end
    return scanTip
end

local function ParseClassicTalentTooltip(tab, idx, group)
    local tip = EnsureScanTip()
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    if not pcall(tip.SetTalent, tip, tab, idx, false, false, group) then
        pcall(tip.SetTalent, tip, tab, idx)
    end
    local lines, nextLines, inNext = {}, {}, false
    for i = 2, (tip:NumLines() or 0) do
        local L = _G["AzaathTalentsScanTipTextLeft" .. i]
        local lt = L and L:GetText()
        if lt and not (Azaath.IsSecret and Azaath.IsSecret(lt)) and lt ~= "" then
            if lt:match("^Próximo") or lt:match("^Next rank") then
                inNext = true
            elseif lt:match("^Ranque") or lt:match("^Rank") or lt:match("^Grau") or lt:match("^Posto")
                or lt:match("^Clique") or lt:match("^Click") or lt:match("^Requer") or lt:match("^Requires")
                or lt:match("^Botão direito") or lt:match("^Right%-click") then
                -- cabeçalho de posto, requisitos e dicas de clique: o códice mostra os seus
            elseif inNext then
                nextLines[#nextLines + 1] = lt
            else
                lines[#lines + 1] = lt
            end
        end
    end
    tip:Hide()
    return table.concat(lines, "\n"), (#nextLines > 0) and table.concat(nextLines, "\n") or nil
end

-- compartilhado com os outros arquivos de Modules/Talents/
U.ART_H, U.ART_W, U.AURA_TEX, U.AZ_BRIGHT = ART_H, ART_W, AURA_TEX, AZ_BRIGHT
U.At, U.BackOut, U.CORE_X, U.CORE_Y = At, BackOut, CORE_X, CORE_Y
U.CREAM, U.CYAN, U.Call, U.CircleMask = CREAM, CYAN, Call, CircleMask
U.Clamp, U.DESC_COL, U.Damp, U.EMBLEM_X = Clamp, DESC_COL, Damp, EMBLEM_X
U.EMBLEM_Y, U.EaseOut, U.FitText, U.GOLD = EMBLEM_Y, EaseOut, FitText, GOLD
U.ICON_R, U.LABEL_COLS, U.LOCK_COL, U.M = ICON_R, LABEL_COLS, LOCK_COL, M
U.MEDIA, U.PANEL_X, U.PURGE_RED, U.Pack = MEDIA, PANEL_X, PURGE_RED, Pack
U.ParseClassicTalentTooltip, U.Plural, U.SUB_COL, U.TAL = ParseClassicTalentTooltip, Plural, SUB_COL, TAL
U.TREES, U.TREE_COLORS, U.Tex, U.Text = TREES, TREE_COLORS, Tex, Text
U.Tracked, U.Upper, U.WHITE, U.WHITE8 = Tracked, Upper, WHITE, WHITE8
U.WriteDiag, U.ambient, U.anim, U.applyQueue = WriteDiag, ambient, anim, applyQueue
U.bottom, U.labels, U.nodeButtons, U.particles = bottom, labels, nodeButtons, particles
U.pending, U.pulses, U.right, U.segs = pending, pulses, right, segs
U.top, U.traitsInfo = top, traitsInfo
