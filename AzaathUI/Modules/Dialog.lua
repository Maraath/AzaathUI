--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Dialog.lua
    Janela própria para conversa com NPC e missões, fiel ao painel do Azaath
    ("NORA LINCH / Watcher of First Light"):
      * cabeçalho azul escovado com topo rasgado: nome do NPC em maiúsculas
        espaçadas (Cinzel) e subtítulo (função do NPC) em PT Sans Bold;
      * corpo marrom-carvão translúcido com filete interno e base rasgada;
      * texto da fala em IM Fell;
      * opções em faixas com moldura dourada: caixinha da tecla (E / ESC)
        pendurada à esquerda, ícone (losango "!" para pegar, "?" para entregar,
        balão de conversa, ícone oficial do serviço - Pedra de Regresso na
        estalagem, bolsa no vendedor... - e porta de saída), número "1." e o texto; nível à direita;
        destaque dourado ao passar o mouse.
    Texturas: Media/Dialog/*.tga (tools/media/generate-dialog-media.js).

    Cobre: conversa (gossip), saudação de missões, detalhes (aceitar/recusar),
    progresso (itens necessários) e entrega (escolha de recompensa).

    Por que uma janela própria e não reestilizar GossipFrame/QuestFrame?
      * Aquelas janelas têm arte com margens e texturas trocadas em tempo de
        execução (pergaminhos); uma janela nova é previsível e fiel ao estilo.
      * As funções usadas (SelectGossipOption, AcceptQuest, CompleteQuest,
        GetQuestReward...) NÃO são protegidas: tudo funciona sem frames seguros.
      * As janelas da Blizzard só têm os eventos desligados (não são protegidas).

    Teclas: 1-9 (e F, atalho principal da Azaath, na primeira opção) via SetOverrideBindingClick enquanto a
    janela está aberta e fora de combate; ao fechar, as teclas voltam ao normal.

    Medidas: todo o layout é escrito em "pixels de referência" (painel de 698 px
    de largura na captura 1080p) e multiplicado por S = largura / 698.
------------------------------------------------------------------------------]]

local ADDON_NAME, Azaath = ...
local M = Azaath:NewModule("Dialog")

local _G = _G
local ipairs, type, format, floor, min, max = ipairs, type, string.format, math.floor, math.min, math.max
local pcall, tostring = pcall, tostring

--------------------------------------------------------------------------------
-- Medidas (px de referência)
--------------------------------------------------------------------------------
local REF_W      = 698   -- largura do painel
local MIN_H      = 800   -- altura mínima do painel
local HEADER_H   = 107   -- cabeçalho azul
local FOOTER_H   = 64    -- base rasgada
local FRAME_IN   = 16    -- filete interno: distância das laterais
local FRAME_BOT  = 11    -- filete interno: distância da base
local TEXT_X     = 57    -- margem do texto
local TEXT_TOP   = 138   -- topo da área de texto
local TEXT_W     = 545   -- largura do texto
local TEXT_MIN   = 355   -- altura mínima da área de texto (opções começam em 507)
local TEXT_MAX   = 520
local ROWS_GAP   = 14    -- texto -> primeira opção
local ROW_X      = 58    -- opções: de 58 a 640
local ROW_W      = 582
local ROW_H      = 51
local ROW_STEP   = 60
local KEY_RIGHT  = 72    -- borda direita da caixinha da tecla (px do painel)
local KEY_H      = 31
local ICON_CX    = 43    -- centro do ícone (px da opção)
local ICON_SIZE  = 28
local NUM_X      = 71
local TEXT_OPT_X = 96
local LEVEL_R    = 21
local BOTTOM_PAD = 40

-- Tecla da primeira opção: F é o atalho principal (interagir) na Azaath
local INTERACT_KEY = "F"

local TEX = "Interface\\AddOns\\" .. ADDON_NAME .. "\\Media\\Dialog\\"
local ICON_QUEST      = TEX .. "IconQuest"           -- losango simples (aceitar/concluir)
local ICON_QUEST_NEW  = TEX .. "IconQuestAvailable"  -- losango com "!" (missão para pegar)
local ICON_QUEST_DONE = TEX .. "IconQuestTurnIn"     -- losango com "?" (entregar; cinza se incompleta)
local ICON_TALK       = TEX .. "IconTalk"            -- balão: só conversa
local ICON_LEAVE      = TEX .. "IconLeave"

-- Opções de serviço: ícones oficiais do jogo. Os de Interface\Icons são ícones
-- de item quadrados com moldura: "crop" corta a moldura.
local GOSSIP_DIR = "Interface\\GossipFrame\\"
local SERVICE_ICONS = {
    binder       = { icon = "Interface\\Icons\\INV_Misc_Rune_01", crop = true }, -- Pedra de Regresso
    vendor       = { icon = GOSSIP_DIR .. "VendorGossipIcon" },
    taxi         = { icon = GOSSIP_DIR .. "TaxiGossipIcon" },
    trainer      = { icon = GOSSIP_DIR .. "TrainerGossipIcon" },
    banker       = { icon = GOSSIP_DIR .. "BankerGossipIcon" },
    battlemaster = { icon = GOSSIP_DIR .. "BattleMasterGossipIcon" },
    petition     = { icon = GOSSIP_DIR .. "PetitionGossipIcon" },
    tabard       = { icon = GOSSIP_DIR .. "TabardGossipIcon" },
    healer       = { icon = GOSSIP_DIR .. "HealerGossipIcon" },
}
local GOSSIP_TALK_FILEID = 132053 -- GossipGossipIcon no cliente moderno

-- Ícone de uma opção de conversa: balão para fala, oficial para serviços
local function OptionIcon(o)
    local kind = o.kind and o.kind:lower()
    local svc = kind and SERVICE_ICONS[kind]
    if svc then return svc.icon, svc.crop end
    if kind == nil and type(o.icon) == "number" and o.icon ~= GOSSIP_TALK_FILEID then
        return o.icon, false -- cliente moderno: fileID oficial que a própria API manda
    end
    return ICON_TALK, false
end

-- Cores amostradas da referência
local COL = {
    name      = { 1.00, 1.00, 1.00 },
    subtitle  = { 0.84, 0.80, 0.68 },
    body      = { 0.96, 0.95, 0.91 },
    quest     = { 0.95, 0.80, 0.45 },  -- título da missão no corpo
    header    = { 0.79, 0.66, 0.42 },  -- "OBJETIVOS", "RECOMPENSAS"
    dim       = { 0.60, 0.58, 0.54 },
    option    = { 1.00, 1.00, 1.00 },
    number    = { 0.63, 0.61, 0.58 },
    level     = { 0.59, 0.565, 0.525 },
    key       = { 0.89, 0.88, 0.84 },
    leave     = { 0.75, 0.73, 0.70 },  -- ícone da porta
    sepDark   = { 0.137, 0.208, 0.263 },
    sepLight  = { 0.31, 0.314, 0.30 },
    frameLine = { 0.204, 0.196, 0.173 },
    border    = { 0.35, 0.31, 0.22 },
    borderHi  = { 0.50, 0.42, 0.26 },
    borderOut = { 0.08, 0.05, 0.00 },
    trivial   = { 0.62, 0.62, 0.62 },
    incomplete = { 0.55, 0.55, 0.55 },
}

local S = 1                     -- escala: largura configurada / REF_W
local function P(v) return v * S end

local frame, headerTex, bodyTex, footerTex, nameText, subText
local sepDark, sepLight, frameL, frameR, frameB
local scroll, child, rowsAnchor
local rows = {}
local fsPool, fsUsed = {}, 0
local itemPool, itemUsed = {}, 0
local y, innerWidth = 0, 300
local mode            -- "gossip" | "quest" | nil
local currentView     -- função da tela atual (para QUEST_ITEM_UPDATE)
local selectedChoice  -- recompensa escolhida na entrega
local closingByEvent = false

--------------------------------------------------------------------------------
-- Janelas da Blizzard (conversa e missão)
-- No cliente moderno quem abre GossipFrame/QuestFrame é o gerenciador de
-- interações do jogo, não os eventos da própria janela: desregistrar não basta.
-- Escondê-las também não serve, pois o OnHide delas encerra a conversa (e
-- fecharia a Azaath junto). Então ficam presas num pai oculto: "abertas" para o
-- jogo, invisíveis e sem clique. Ao fim da conversa são fechadas de verdade
-- para liberar o espaço de painel da esquerda.
--------------------------------------------------------------------------------
local BLIZZ_PANELS = { "GossipFrame", "QuestFrame" }
local blizzHider = CreateFrame("Frame")
blizzHider:Hide()

local function SilenceBlizzardPanels()
    for _, name in ipairs(BLIZZ_PANELS) do
        local f = _G[name]
        if f and not f.azaathSilenced then
            f.azaathSilenced = true
            f:UnregisterAllEvents()
            f:SetParent(blizzHider)
            f:HookScript("OnShow", function(self)
                if self:GetParent() ~= blizzHider then self:SetParent(blizzHider) end
            end)
        end
    end
end

local function CloseBlizzardPanel(name)
    -- Cliente moderno: o gerenciador de interações fecha a janela sozinho. HideUIPanel
    -- chamado pelo addon contamina o gerenciador de painéis, e a próxima janela aberta
    -- por ele (ex.: banco) herda o taint, bloqueando ações como comprar espaço.
    if Azaath.IS_MODERN then return end
    local f = _G[name]
    if f and f.azaathSilenced and f:IsShown() then
        if _G.HideUIPanel then pcall(HideUIPanel, f) end
        if f:IsShown() then f:Hide() end
    end
end

local function SetColor(obj, c, a)
    if obj.SetVertexColor then obj:SetVertexColor(c[1], c[2], c[3], a or 1)
    else obj:SetTextColor(c[1], c[2], c[3], a or 1) end
end

local function Solid(parent, layer, c)
    local t = parent:CreateTexture(nil, layer)
    t:SetTexture(Azaath.media.blank)
    SetColor(t, c)
    return t
end

--------------------------------------------------------------------------------
-- Utilitários
--------------------------------------------------------------------------------
local function Money(copper)
    return Azaath.FormatMoney(copper)
end

-- Subtítulo do NPC ("Watcher of First Light"): a 2ª linha do tooltip da
-- unidade, quando não é a linha de nível/tipo. Tudo protegido por pcall
-- (no cliente moderno textos de tooltip podem vir como valores secretos).
local scanTip
local function NPCSubtitle()
    local ok, result = pcall(function()
        if not UnitExists("npc") or UnitIsPlayer("npc") then return nil end
        local TI = _G.C_TooltipInfo
        if TI and TI.GetUnit then
            local ok2, data = pcall(TI.GetUnit, "npc")
            if ok2 and type(data) == "table" and type(data.lines) == "table" then
                for i = 2, math.min(5, #data.lines) do
                    local line = data.lines[i]
                    if line then
                        if line.args and _G.TooltipUtil and TooltipUtil.SurfaceArgs then
                            pcall(TooltipUtil.SurfaceArgs, line)
                        end
                        local t = line.leftText or (line.args and line.args[2] and line.args[2].stringVal)
                        if type(t) == "string" and t ~= "" and not Azaath.IsSecret(t) then
                            local low = t:lower()
                            if not t:find("%d") and not t:find("%?%?") and not low:find("nivel") and not low:find("nível") and not low:find("level") then
                                return t
                            end
                        end
                    end
                end
            end
            return nil
        end

        if not scanTip then
            scanTip = CreateFrame("GameTooltip", "AzaathUIDialogScan", nil, "GameTooltipTemplate")
            local sb = scanTip.StatusBar or _G["AzaathUIDialogScanStatusBar"]
            if sb then sb:SetScript("OnValueChanged", nil) end
        end
        scanTip:SetOwner(WorldFrame, "ANCHOR_NONE")
        scanTip:ClearLines()
        scanTip:SetUnit("npc")
        local line = _G["AzaathUIDialogScanTextLeft2"]
        local text = line and line:GetText()
        scanTip:Hide()
        if type(text) ~= "string" or text == "" then return nil end
        if _G.issecretvalue and _G.issecretvalue(text) then return nil end
        -- "Nível 10 Humanoide", "Level ??": não é subtítulo
        if text:find("%d") or text:find("%?%?") then return nil end
        return text
    end)
    return ok and result or nil
end

--------------------------------------------------------------------------------
-- Conteúdo rolável (pools de textos e itens)
--------------------------------------------------------------------------------
local function NextText(font, size, color)
    fsUsed = fsUsed + 1
    local fs = fsPool[fsUsed]
    if not fs then
        fs = child:CreateFontString(nil, "OVERLAY")
        fs:SetJustifyH("LEFT")
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 0.85)
        fsPool[fsUsed] = fs
    end
    fs:SetFont(font, size, "")
    fs:SetSpacing(0)
    fs:SetWidth(innerWidth)
    SetColor(fs, color or COL.body)
    fs:Show()
    return fs
end

local function Place(region, height, gap)
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    y = y + height + (gap or P(10))
end

local function AddTitle(text)
    if not text or text == "" then return end
    local fs = NextText(Azaath.media.fontBold, P(21), COL.quest)
    fs:SetText(text)
    Place(fs, fs:GetStringHeight(), P(14))
end

-- Fala: IM Fell 22 px, linhas a cada 32 px como na referência
local function AddParagraph(text, color, size)
    if not text or text == "" then return end
    local fs = NextText(Azaath.media.fontTitle, P(size or 22), color)
    fs:SetSpacing(P(7))
    fs:SetText(text)
    Place(fs, fs:GetStringHeight(), P(18))
end

local function AddHeader(label)
    local fs = NextText(Azaath.media.fontTitleB, P(14), COL.header)
    fs:SetText(Azaath.Tracked(label))
    Place(fs, P(16), P(10))
end

local function RefreshChoiceHighlights()
    for i = 1, itemUsed do
        local b = itemPool[i]
        if b.kind == "choice" and b.selectable and b.index == selectedChoice then
            b.sel:Show()
        else
            b.sel:Hide()
        end
    end
end

local function Item_OnClick(self)
    if not self.selectable then return end
    selectedChoice = self.index
    Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
    RefreshChoiceHighlights()
end

local function Item_OnEnter(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetQuestItem(self.kind, self.index)
    GameTooltip:Show()
end

local function NextItem()
    itemUsed = itemUsed + 1
    local b = itemPool[itemUsed]
    if not b then
        local media = Azaath.media
        b = CreateFrame("Button", nil, child)

        b.bg = b:CreateTexture(nil, "BACKGROUND")
        b.bg:SetTexture(TEX .. "OptionFill")
        b.bg:SetAllPoints(b)

        b.sel = b:CreateTexture(nil, "BORDER")
        b.sel:SetTexture(TEX .. "OptionHover")
        b.sel:SetAllPoints(b)
        b.sel:Hide()

        b.border = CreateFrame("Frame", nil, b)
        Azaath.SetBackdrop(b.border, { bgFile = media.blank, edgeFile = media.blank, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 } })
        b.border:SetBackdropColor(0, 0, 0, 0.7)

        b.icon = b.border:CreateTexture(nil, "ARTWORK")
        b.icon:SetPoint("TOPLEFT", b.border, "TOPLEFT", 2, -2)
        b.icon:SetPoint("BOTTOMRIGHT", b.border, "BOTTOMRIGHT", -2, 2)
        b.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        b.count = b.border:CreateFontString(nil, "OVERLAY")
        b.count:SetPoint("BOTTOMRIGHT", b.border, "BOTTOMRIGHT", -2, 2)

        b.name = b:CreateFontString(nil, "OVERLAY")
        b.name:SetJustifyH("LEFT")
        b.name:SetShadowOffset(1, -1)
        b.name:SetShadowColor(0, 0, 0, 0.85)

        b:SetScript("OnClick", Item_OnClick)
        b:SetScript("OnEnter", Item_OnEnter)
        b:SetScript("OnLeave", function() GameTooltip:Hide() end)
        itemPool[itemUsed] = b
    end
    -- tamanhos dependem da escala atual
    local h = P(54)
    b:SetHeight(h)
    b.border:SetWidth(h - P(10))
    b.border:SetHeight(h - P(10))
    b.border:ClearAllPoints()
    b.border:SetPoint("LEFT", b, "LEFT", P(5), 0)
    b.count:SetFont(Azaath.media.fontBold, P(15), "OUTLINE")
    b.name:SetFont(Azaath.media.fontBold, P(16), "")
    b.name:ClearAllPoints()
    b.name:SetPoint("LEFT", b.border, "RIGHT", P(8), 0)
    b.name:SetPoint("RIGHT", b, "RIGHT", -P(6), 0)
    b.name:SetHeight(h - P(4))
    b:Show()
    return b
end

local function AddItems(kind, count, selectable)
    local y0 = y
    local gap = P(8)
    local w = (innerWidth - gap) / 2
    local h = P(54)
    for i = 1, count do
        local name, texture, num, quality = GetQuestItemInfo(kind, i)
        local b = NextItem()
        b.kind, b.index, b.selectable = kind, i, selectable
        b:SetWidth(w)
        b.icon:SetTexture(texture)
        b.count:SetText((num and num > 1) and num or "")
        b.name:SetText(name or "")
        local r, g, bl = 1, 1, 1
        if quality and quality >= 0 and Azaath.API.GetItemQualityColor then r, g, bl = Azaath.API.GetItemQualityColor(quality) end
        b.name:SetTextColor(r, g, bl)
        b.border:SetBackdropBorderColor(r, g, bl, (quality and quality >= 2) and 0.9 or 0.45)
        local col, row = (i - 1) % 2, floor((i - 1) / 2)
        b:ClearAllPoints()
        b:SetPoint("TOPLEFT", child, "TOPLEFT", col * (w + gap), -(y0 + row * (h + gap)))
    end
    y = y0 + math.ceil(count / 2) * (h + gap) + P(8)
    RefreshChoiceHighlights()
end

local function AddRewards(isComplete)
    local nChoices, nRewards = GetNumQuestChoices(), GetNumQuestRewards()
    local money = GetRewardMoney() or 0
    local xp = GetRewardXP and GetRewardXP() or 0
    if nChoices + nRewards == 0 and money == 0 and xp == 0 then return end

    AddHeader("Recompensas")
    if nChoices > 0 then
        AddParagraph(nChoices > 1 and "Escolha uma destas recompensas:" or "Você receberá:", COL.dim, 18)
        AddItems("choice", nChoices, isComplete and nChoices > 1)
    end
    if nRewards > 0 then
        AddParagraph(nChoices > 0 and "Você também receberá:" or "Você receberá:", COL.dim, 18)
        AddItems("reward", nRewards, false)
    end
    if money > 0 then AddParagraph(Money(money), nil, 18) end
    if xp > 0 then AddParagraph(Azaath.Thousands(xp) .. " de experiência", nil, 18) end
end

--------------------------------------------------------------------------------
-- Opções (faixas com moldura dourada)
--------------------------------------------------------------------------------
local function SetBorderColor(row, c)
    for _, t in ipairs(row.borderIn) do SetColor(t, c) end
end

local function Row_OnEnter(self)
    if not self.func then return end
    self.hover:Show()
    SetBorderColor(self, COL.borderHi)
end

local function Row_OnLeave(self)
    self.hover:Hide()
    SetBorderColor(self, COL.border)
end

local function Row_OnClick(self)
    if self.func then
        Azaath.PlaySound("igMainMenuOptionCheckBoxOn")
        self.func()
    end
end

-- 4 filetes formando uma moldura (inset a partir da borda, espessura t)
local function MakeBorder(parent, layer, c)
    local list = {}
    for i = 1, 4 do list[i] = Solid(parent, layer, c) end
    return list
end

local function LayoutBorder(list, parent, inset, t)
    local top, bot, lft, rgt = list[1], list[2], list[3], list[4]
    for _, tex in ipairs(list) do tex:ClearAllPoints() end
    top:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    top:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)
    top:SetHeight(t)
    bot:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, inset)
    bot:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
    bot:SetHeight(t)
    lft:SetPoint("TOPLEFT", parent, "TOPLEFT", inset, -inset)
    lft:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", inset, inset)
    lft:SetWidth(t)
    rgt:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -inset, -inset)
    rgt:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -inset, inset)
    rgt:SetWidth(t)
end

local function GetRow(i)
    if rows[i] then return rows[i] end
    local row = CreateFrame("Button", "AzaathUIDialogOption" .. i, frame)
    row:RegisterForClicks("LeftButtonUp")
    row:SetScript("OnClick", Row_OnClick)
    row:SetScript("OnEnter", Row_OnEnter)
    row:SetScript("OnLeave", Row_OnLeave)

    row.fill = row:CreateTexture(nil, "BACKGROUND")
    row.fill:SetTexture(TEX .. "OptionFill")
    row.fill:SetAllPoints(row)

    row.hover = row:CreateTexture(nil, "BORDER")
    row.hover:SetTexture(TEX .. "OptionHover")
    row.hover:SetAllPoints(row)
    row.hover:Hide()

    row.borderOut = MakeBorder(row, "ARTWORK", COL.borderOut)
    row.borderIn  = MakeBorder(row, "ARTWORK", COL.border)

    -- caixinha da tecla, pendurada sobre a borda esquerda (frame filho: fica
    -- acima da moldura; o cliente 3.3.5 não tem sub-níveis de camada)
    row.keyFrame = CreateFrame("Frame", nil, row)
    row.keyFrame:SetFrameLevel(row:GetFrameLevel() + 2)
    row.keyBox = row.keyFrame:CreateTexture(nil, "BACKGROUND")
    row.keyBox:SetAllPoints(row.keyFrame)
    row.key = row.keyFrame:CreateFontString(nil, "OVERLAY")
    row.key:SetPoint("CENTER", row.keyBox, "CENTER", 0, 0)
    SetColor(row.key, COL.key)

    row.icon = row:CreateTexture(nil, "OVERLAY")

    row.num = row:CreateFontString(nil, "OVERLAY")
    row.num:SetJustifyH("LEFT")
    SetColor(row.num, COL.number)

    row.level = row:CreateFontString(nil, "OVERLAY")
    row.level:SetJustifyH("RIGHT")
    SetColor(row.level, COL.level)

    row.text = row:CreateFontString(nil, "OVERLAY")
    row.text:SetJustifyH("LEFT")
    row.text:SetShadowOffset(1, -1)
    row.text:SetShadowColor(0, 0, 0, 0.9)

    rows[i] = row
    return row
end

-- Posições e fontes da faixa (dependem da escala S)
local function LayoutRow(row, keyWide)
    local media = Azaath.media
    row:SetWidth(P(ROW_W))
    row:SetHeight(P(ROW_H))
    LayoutBorder(row.borderOut, row, 0, 1)
    LayoutBorder(row.borderIn, row, 1, max(1, P(2)))

    local kw = P(keyWide and 44 or 30)
    row.keyBox:SetTexture(TEX .. (keyWide and "KeyBoxWide" or "KeyBox"))
    row.keyFrame:SetWidth(kw)
    row.keyFrame:SetHeight(P(KEY_H))
    row.keyFrame:ClearAllPoints()
    row.keyFrame:SetPoint("RIGHT", row, "LEFT", P(KEY_RIGHT - ROW_X), 0)
    row.key:SetFont(media.font, P(17), "")

    row.icon:SetWidth(P(ICON_SIZE))
    row.icon:SetHeight(P(ICON_SIZE))
    row.icon:ClearAllPoints()
    row.icon:SetPoint("CENTER", row, "LEFT", P(ICON_CX), 0)

    row.num:SetFont(media.fontBold, P(17), "")
    row.num:ClearAllPoints()
    row.num:SetPoint("LEFT", row, "LEFT", P(NUM_X), 0)

    row.level:SetFont(media.font, P(17), "")
    row.level:ClearAllPoints()
    row.level:SetPoint("RIGHT", row, "RIGHT", -P(LEVEL_R), 0)

    row.text:SetFont(media.fontBold, P(20), "")
    row.text:SetHeight(P(ROW_H) - 2)
end

-- entries: { text, icon, crop, func, disabled, color, desaturate, tint, level }
-- A última é sempre a de saída (caixinha ESC).
local function SetRows(entries)
    local db = M.db
    for i, e in ipairs(entries) do
        local row = GetRow(i)
        local isEsc = (i == #entries)
        local isFirst = (i == 1) and not isEsc
        LayoutRow(row, isEsc)

        -- caixinha: F (ou 1) na primeira opção, ESC na saída
        if isEsc then
            row.key:SetText("ESC")
        elseif isFirst then
            row.key:SetText(db.interactKey and INTERACT_KEY or "1")
        end
        if isEsc or isFirst then row.keyFrame:Show() else row.keyFrame:Hide() end

        row.numbered = i <= 9
        row.num:SetText(row.numbered and (i .. ".") or "")

        row.icon:SetTexture(e.icon)
        if e.crop then row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) else row.icon:SetTexCoord(0, 1, 0, 1) end
        if e.icon then row.icon:Show() else row.icon:Hide() end
        row.icon:SetDesaturated(e.desaturate and true or false)
        if e.tint then SetColor(row.icon, e.tint) else row.icon:SetVertexColor(1, 1, 1) end

        row.level:SetText(e.level and format("Nível %d", e.level) or "")
        row.text:ClearAllPoints()
        row.text:SetPoint("LEFT", row, "LEFT", P(TEXT_OPT_X), 0)
        if e.level then
            row.text:SetPoint("RIGHT", row.level, "LEFT", -P(10), 0)
        else
            row.text:SetPoint("RIGHT", row, "RIGHT", -P(LEVEL_R), 0)
        end
        row.text:SetText(e.text)
        SetColor(row.text, (e.disabled and COL.dim) or e.color or COL.option)
        SetColor(row.num, e.disabled and COL.dim or COL.number)

        row.func = (not e.disabled) and e.func or nil
        row.hover:Hide()
        SetBorderColor(row, COL.border)

        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", rowsAnchor, "TOPLEFT", 0, -(i - 1) * P(ROW_STEP))
        row:Show()
        local over = (row.IsMouseOver and row:IsMouseOver()) or (_G.MouseIsOver and _G.MouseIsOver(row))
        if over then Row_OnEnter(row) end
    end
    for i = #entries + 1, #rows do
        rows[i]:Hide()
        rows[i].numbered = false
        rows[i].func = nil
    end
    return #entries
end

local function BindKeys()
    if InCombatLockdown() then return end
    ClearOverrideBindings(frame)
    local db = M.db
    if db.numberKeys then
        for i = 1, 9 do
            local row = rows[i]
            if row and row:IsShown() and row.numbered and row.func then
                SetOverrideBindingClick(frame, true, tostring(i), row:GetName(), "LeftButton")
            end
        end
    end
    local first = rows[1]
    if db.interactKey and first and first:IsShown() and first.func and first.keyFrame:IsShown()
        and first.key:GetText() == INTERACT_KEY then
        SetOverrideBindingClick(frame, true, INTERACT_KEY, first:GetName(), "LeftButton")
    end
end

local function UnbindKeys()
    if InCombatLockdown() then
        Azaath:RunOutOfCombat(function() ClearOverrideBindings(frame) end)
    else
        ClearOverrideBindings(frame)
    end
end

--------------------------------------------------------------------------------
-- Montagem de uma tela
--------------------------------------------------------------------------------
local function SetHeader(name, subtitle)
    nameText:SetText(Azaath.Tracked(name or ""))
    subText:SetText(subtitle or "")
    nameText:ClearAllPoints()
    local cy = (subtitle and subtitle ~= "") and 46 or (HEADER_H / 2)
    nameText:SetPoint("LEFT", frame, "TOPLEFT", P(58), -P(cy))
    nameText:SetPoint("RIGHT", frame, "TOPRIGHT", -P(40), -P(cy))
    if cy == 46 then subText:Show() else subText:Hide() end
end

local function Begin(newMode, fallbackName)
    mode = newMode
    for i = 1, fsUsed do fsPool[i]:Hide() end
    for i = 1, itemUsed do itemPool[i]:Hide() end
    fsUsed, itemUsed, y = 0, 0, 0
    local npc = UnitName("npc")
    if npc and npc ~= "" then
        SetHeader(npc, NPCSubtitle())
    else
        SetHeader(fallbackName or "", nil)
    end
end

local function Finish(entries)
    local nRows = SetRows(entries)
    child:SetHeight(max(1, y))
    -- área de texto: no mínimo a da referência (opções em 507 px); com muitas
    -- opções ela encolhe para a janela não passar da tela
    local textMin = max(150, TEXT_MIN - max(0, nRows - 3) * ROW_STEP)
    local textH = min(max(y, P(textMin)), P(TEXT_MAX))
    scroll:SetHeight(max(1, textH))
    scroll:UpdateScrollChildRect()
    scroll:SetVerticalScroll(0)
    local rowsTop = P(TEXT_TOP + ROWS_GAP) + textH
    local panelH = max(P(MIN_H), rowsTop + nRows * P(ROW_STEP) - P(ROW_STEP - ROW_H) + P(BOTTOM_PAD))
    frame:SetHeight(panelH)
    frame:Show()
    BindKeys()
end

local function Exit()
    frame:Hide() -- OnHide fecha a conversa/missão no servidor
end

-- linha de saída padrão (ESC)
local function LeaveEntry(text, func)
    return { text = text or "Sair", icon = ICON_LEAVE, tint = COL.leave, func = func or Exit }
end

--------------------------------------------------------------------------------
-- Telas
--------------------------------------------------------------------------------
local function Quoted(text)
    if not text or text == "" then return text end
    if text:find('^"') then return text end
    return '"' .. text .. '"'
end

-- Determina se a i-ésima quest ativa de QUEST_GREETING está concluída.
-- Clientes modernos/Classic não expõem IsActiveQuestComplete(i); consultam
-- GetActiveQuestID + C_QuestLog.IsComplete ou o registro de missões.
local function IsActiveQuestDone(i, title)
    if _G.IsActiveQuestComplete then
        local done = IsActiveQuestComplete(i)
        if done ~= nil then return done and true or false end
    end
    local qid = _G.GetActiveQuestID and GetActiveQuestID(i)
    if qid and _G.C_QuestLog and C_QuestLog.IsComplete then
        return C_QuestLog.IsComplete(qid) and true or false
    end
    local API = Azaath.API
    if API and API.NumQuestLogEntries and API.QuestInfo then
        for idx = 1, API.NumQuestLogEntries() do
            local qTitle, _, _, _, isHeader, isComplete, _, questID = API.QuestInfo(idx)
            if not isHeader and ((qid and questID == qid) or (title and qTitle == title)) then
                return isComplete == 1 or isComplete == true
            end
        end
    end
    return false
end

local function ShowGossip()
    Begin("gossip")
    -- Compat: C_GossipInfo no cliente moderno, funções globais na 3.3.5
    local API = Azaath.API
    AddParagraph(API.GossipText())

    local entries = {}
    for _, q in ipairs(API.GossipAvailableQuests()) do
        entries[#entries + 1] = {
            text = q.title, icon = ICON_QUEST_NEW, level = q.level,
            color = q.trivial and COL.trivial or nil,
            desaturate = q.trivial,
            func = q.select,
        }
    end
    for _, q in ipairs(API.GossipActiveQuests()) do
        local done = q.complete and true or false
        entries[#entries + 1] = {
            text = q.title, icon = ICON_QUEST_DONE, level = q.level,
            desaturate = not done,
            tint = (not done) and COL.incomplete or nil,
            func = q.select,
        }
    end
    for _, o in ipairs(API.GossipOptions()) do
        local icon, crop = OptionIcon(o)
        entries[#entries + 1] = { text = Quoted(o.text), icon = icon, crop = crop, func = o.select }
    end
    entries[#entries + 1] = LeaveEntry()
    currentView = ShowGossip
    Finish(entries)
end

local function ShowGreeting()
    Begin("quest")
    AddParagraph(GetGreetingText())
    local entries = {}
    for i = 1, GetNumActiveQuests() do
        local title = GetActiveTitle(i)
        local done = IsActiveQuestDone(i, title)
        entries[#entries + 1] = { text = title, icon = ICON_QUEST_DONE,
            desaturate = not done,
            tint = (not done) and COL.incomplete or nil,
            level = GetActiveLevel and GetActiveLevel(i) or nil,
            func = function() SelectActiveQuest(i) end }
    end
    for i = 1, GetNumAvailableQuests() do
        entries[#entries + 1] = { text = GetAvailableTitle(i), icon = ICON_QUEST_NEW,
            level = GetAvailableLevel and GetAvailableLevel(i) or nil,
            func = function() SelectAvailableQuest(i) end }
    end
    entries[#entries + 1] = LeaveEntry()
    currentView = ShowGreeting
    Finish(entries)
end

local function ShowDetail()
    Begin("quest", GetTitleText())
    AddTitle(GetTitleText())
    AddParagraph(GetQuestText())
    local objectives = GetObjectiveText()
    if objectives and objectives ~= "" then
        AddHeader("Objetivos")
        AddParagraph(objectives)
    end
    AddRewards(false)
    currentView = ShowDetail
    Finish({
        { text = "Aceitar missão", icon = ICON_QUEST, func = function() AcceptQuest() end },
        LeaveEntry("Recusar", function() DeclineQuest() end),
    })
end

local function ShowProgress()
    Begin("quest", GetTitleText())
    AddTitle(GetTitleText())
    AddParagraph(GetProgressText())
    local nItems = GetNumQuestItems()
    local money = GetQuestMoneyToGet and GetQuestMoneyToGet() or 0
    if nItems > 0 or money > 0 then
        AddHeader("Itens necessários")
        if nItems > 0 then AddItems("required", nItems, false) end
        if money > 0 then AddParagraph(Money(money), nil, 18) end
    end
    local entries = {}
    if IsQuestCompletable() then
        entries[1] = { text = "Continuar", icon = ICON_QUEST, func = function() CompleteQuest() end }
    else
        entries[1] = { text = "Missão ainda não concluída", icon = ICON_QUEST, desaturate = true, disabled = true }
    end
    entries[2] = LeaveEntry()
    currentView = ShowProgress
    Finish(entries)
end

local function CompleteWithReward()
    local n = GetNumQuestChoices()
    if n > 1 and not selectedChoice then
        UIErrorsFrame:AddMessage("Escolha uma recompensa primeiro.", 1, 0.3, 0.25)
        return
    end
    GetQuestReward(selectedChoice or (n == 1 and 1) or 0)
end

local function ShowComplete()
    Begin("quest", GetTitleText())
    AddTitle(GetTitleText())
    AddParagraph(GetRewardText())
    AddRewards(true)
    currentView = ShowComplete
    Finish({
        { text = "Concluir missão", icon = ICON_QUEST, func = CompleteWithReward },
        LeaveEntry(),
    })
end

--------------------------------------------------------------------------------
-- Janela
--------------------------------------------------------------------------------
local function CloseByEvent()
    closingByEvent = true
    frame:Hide()
    closingByEvent = false
end

-- Posições/tamanhos estáticos (refeitos quando a largura ou escala mudam)
local function Layout()
    local db, media = M.db, Azaath.media
    local width = db.width or 500
    S = width / REF_W
    innerWidth = P(TEXT_W)

    frame:SetScale((db.scale and db.scale > 0) and db.scale or 1)
    frame:SetWidth(width)
    if not frame:IsShown() then frame:SetHeight(P(MIN_H)) end
    frame:ClearAllPoints()
    frame:SetPoint("RIGHT", UIParent, "RIGHT", db.offsetX or -57, db.offsetY or -12)
    if Azaath.ClampToScreen then Azaath.ClampToScreen(frame) end

    headerTex:SetHeight(P(HEADER_H))
    footerTex:SetHeight(P(FOOTER_H))

    sepDark:ClearAllPoints()
    sepDark:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -P(HEADER_H) + 1)
    sepDark:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -P(HEADER_H) + 1)
    sepDark:SetHeight(1)
    sepLight:ClearAllPoints()
    sepLight:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, -P(HEADER_H))
    sepLight:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, -P(HEADER_H))
    sepLight:SetHeight(max(1, P(1.5)))

    local lw = max(1, P(1.5))
    frameL:ClearAllPoints()
    frameL:SetPoint("TOPLEFT", frame, "TOPLEFT", P(FRAME_IN), -P(HEADER_H + 1))
    frameL:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", P(FRAME_IN), P(FRAME_BOT))
    frameL:SetWidth(lw)
    frameR:ClearAllPoints()
    frameR:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -P(FRAME_IN), -P(HEADER_H + 1))
    frameR:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -P(FRAME_IN), P(FRAME_BOT))
    frameR:SetWidth(lw)
    frameB:ClearAllPoints()
    frameB:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", P(FRAME_IN), P(FRAME_BOT))
    frameB:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -P(FRAME_IN), P(FRAME_BOT))
    frameB:SetHeight(lw)

    nameText:SetFont(media.fontCinzel, P(30), "")
    subText:SetFont(media.fontBold, P(17.5), "")
    subText:ClearAllPoints()
    subText:SetPoint("LEFT", frame, "TOPLEFT", P(57), -P(83))
    subText:SetPoint("RIGHT", frame, "TOPRIGHT", -P(40), -P(83))

    scroll:ClearAllPoints()
    scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", P(TEXT_X), -P(TEXT_TOP))
    scroll:SetWidth(innerWidth + P(6))
    child:SetWidth(innerWidth)

    rowsAnchor:ClearAllPoints()
    rowsAnchor:SetPoint("TOPLEFT", scroll, "BOTTOMLEFT", P(ROW_X - TEXT_X), -P(ROWS_GAP))
end

local function Build()
    frame = CreateFrame("Frame", "AzaathUIDialog", UIParent)
    frame:SetFrameStrata("HIGH")
    frame:SetToplevel(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:Hide()
    tinsert(UISpecialFrames, "AzaathUIDialog") -- ESC fecha (e encerra a conversa)

    -- fundo: cabeçalho azul, corpo translúcido e base rasgada
    headerTex = frame:CreateTexture(nil, "BACKGROUND")
    headerTex:SetTexture(TEX .. "Header")
    headerTex:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    headerTex:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)

    footerTex = frame:CreateTexture(nil, "BACKGROUND")
    footerTex:SetTexture(TEX .. "Footer")
    footerTex:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    footerTex:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    footerTex:SetAlpha(0.93)

    bodyTex = frame:CreateTexture(nil, "BACKGROUND")
    bodyTex:SetTexture(TEX .. "Body")
    bodyTex:SetPoint("TOPLEFT", headerTex, "BOTTOMLEFT", 0, 0)
    bodyTex:SetPoint("TOPRIGHT", headerTex, "BOTTOMRIGHT", 0, 0)
    bodyTex:SetPoint("BOTTOMLEFT", footerTex, "TOPLEFT", 0, 0)
    bodyTex:SetPoint("BOTTOMRIGHT", footerTex, "TOPRIGHT", 0, 0)
    bodyTex:SetAlpha(0.93)

    -- filete sob o cabeçalho e moldura interna fina
    sepDark  = Solid(frame, "BORDER", COL.sepDark)
    sepLight = Solid(frame, "BORDER", COL.sepLight)
    frameL   = Solid(frame, "BORDER", COL.frameLine)
    frameR   = Solid(frame, "BORDER", COL.frameLine)
    frameB   = Solid(frame, "BORDER", COL.frameLine)

    nameText = frame:CreateFontString(nil, "OVERLAY")
    nameText:SetJustifyH("LEFT")
    nameText:SetShadowOffset(1, -1)
    nameText:SetShadowColor(0, 0, 0, 0.6)
    SetColor(nameText, COL.name)

    subText = frame:CreateFontString(nil, "OVERLAY")
    subText:SetJustifyH("LEFT")
    subText:SetShadowOffset(1, -1)
    subText:SetShadowColor(0, 0, 0, 0.6)
    SetColor(subText, COL.subtitle)

    -- Corpo rolável (roda do mouse)
    scroll = CreateFrame("ScrollFrame", nil, frame)
    scroll:SetHeight(100)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local v = self:GetVerticalScroll() - delta * P(48)
        self:SetVerticalScroll(max(0, min(v, self:GetVerticalScrollRange())))
    end)
    child = CreateFrame("Frame", nil, scroll)
    child:SetHeight(1)
    scroll:SetScrollChild(child)

    -- Âncora das opções: logo abaixo do corpo
    rowsAnchor = CreateFrame("Frame", nil, frame)
    rowsAnchor:SetWidth(1)
    rowsAnchor:SetHeight(1)

    Layout()

    frame:SetScript("OnHide", function()
        UnbindKeys()
        if not closingByEvent then
            if mode == "gossip" then
                Azaath.API.CloseGossip()
                CloseBlizzardPanel("GossipFrame")
            elseif mode == "quest" then
                CloseQuest()
                CloseBlizzardPanel("QuestFrame")
            end
        end
        mode, currentView = nil, nil
    end)
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
-- A conversa leva a outra janela do jogo (mapa de voo, vendedor, treinador,
-- banco...): a Azaath não tem versão própria dessas, então a conversa sai de
-- cena em vez de ficar aberta junto. Fecha "por evento" (sem CloseGossip),
-- senão o jogo encerraria a interação e fecharia a janela que acabou de abrir.
local HANDOFF = {
    TAXIMAP_OPENED = true, MERCHANT_SHOW = true, TRAINER_SHOW = true,
    BANKFRAME_OPENED = true, AUCTION_HOUSE_SHOW = true, MAIL_SHOW = true,
    GUILDBANKFRAME_OPENED = true,
}
local taxiOpenAt -- mapa de voo aberto (nil = fechado)

local function TaxiMapShown()
    if not taxiOpenAt then return false end
    for _, name in ipairs({ "FlightMapFrame", "TaxiFrame" }) do
        local f = _G[name]
        if f and f:IsShown() then return true end
    end
    -- o evento pode chegar antes da janela aparecer
    return GetTime() - taxiOpenAt < 2
end

local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event)
    SilenceBlizzardPanels() -- caso a janela da Blizzard tenha sido criada depois do login
    if HANDOFF[event] then
        if event == "TAXIMAP_OPENED" then taxiOpenAt = GetTime() end
        if mode == "gossip" and frame and frame:IsShown() then CloseByEvent() end
    elseif event == "TAXIMAP_CLOSED" then
        taxiOpenAt = nil
    elseif event == "GOSSIP_SHOW" then
        -- mestre de voo que abre o mapa direto também manda a conversa
        if TaxiMapShown() then return end
        ShowGossip()
    elseif event == "GOSSIP_CLOSED" then
        if mode == "gossip" then CloseByEvent() end
        CloseBlizzardPanel("GossipFrame")
    elseif event == "QUEST_GREETING" then
        ShowGreeting()
    elseif event == "QUEST_DETAIL" then
        ShowDetail()
    elseif event == "QUEST_PROGRESS" then
        ShowProgress()
    elseif event == "QUEST_COMPLETE" then
        selectedChoice = nil
        ShowComplete()
    elseif event == "QUEST_FINISHED" then
        if mode == "quest" then CloseByEvent() end
        CloseBlizzardPanel("QuestFrame")
    elseif event == "QUEST_ITEM_UPDATE" then
        -- informações de item chegaram do servidor: redesenha a tela atual
        if currentView and frame:IsShown() and mode == "quest" then currentView() end
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- teclas não podem ser ligadas em combate: liga ao sair dele
        if frame and frame:IsShown() then BindKeys() end
    end
end)

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:ApplyLayout()
    if not self.db or not frame then return end
    Layout()
    if currentView and frame:IsShown() then currentView() end
end

function M:OnInitialize()
    self.db = Azaath.db.dialog
    -- layout Azaath fiel à referência (painel de ~500 de largura): migra uma vez
    -- quem ainda tem a largura/posição da janela compacta antiga
    if (self.db.layoutVersion or 1) < 2 then
        self.db.width, self.db.offsetX, self.db.offsetY = 500, -57, -12
        self.db.layoutVersion = 2
    end
    if self.db.interactKey == nil then self.db.interactKey = true end
end

function M:OnEnable()
    if not self.db.enabled then return end
    Build()

    -- Janelas da Blizzard (não protegidas): fecham e passam a abrir invisíveis
    for _, name in ipairs(BLIZZ_PANELS) do
        local f = _G[name]
        if f and f:IsShown() then f:Hide() end
    end
    SilenceBlizzardPanels()

    for _, e in ipairs({ "GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_GREETING", "QUEST_DETAIL",
                         "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED", "QUEST_ITEM_UPDATE",
                         "PLAYER_REGEN_ENABLED", "TAXIMAP_CLOSED" }) do
        Azaath.SafeRegister(events, e)
    end
    for e in pairs(HANDOFF) do
        Azaath.SafeRegister(events, e)
    end
end
