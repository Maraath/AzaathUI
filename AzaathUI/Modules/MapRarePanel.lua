--[[----------------------------------------------------------------------------
    AzaathUI - Modules/MapRarePanel.lua
    Aba de detalhes de um raro (botão direito no pino do mapa, Modules/WorldMap.lua):
    retrato 3D, nível, respawn, situação (visto / morto) e a lista completa de drops com ícone,
    qualidade e chance. Passar o mouse num item mostra a dica do jogo (o card do Azaath, se ligado);
    Shift+clique põe o link no chat. Botões: SEGUIR (caminho mágico) e ESCONDER DO MAPA.

    Retrato: Model:SetCreature(npcID); se o jogo ainda não conhece a criatura, usa o displayID
    guardado quando o scanner viu o raro (Modules/MapRares.lua, rares.display[npcID]).
    Moldura e fontes: as do mapa (Modules/MapChrome.lua: PanelBox, Tex, Font).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("MapRarePanel")

local pcall, type, time = pcall, type, time
local ROWS = 9              -- linhas de item visíveis (a roda do mouse rola o resto)
local ROW_H = 26
local W = 360

local QUALITY = { [0] = { 0.62, 0.62, 0.62 }, [1] = { 0.92, 0.92, 0.92 }, [2] = { 0.12, 1, 0 },
                  [3] = { 0, 0.44, 0.87 }, [4] = { 0.64, 0.21, 0.93 }, [5] = { 1, 0.5, 0 } }

local U = {}

local function Safe(fn, ...)
    if not fn then return end
    local ok, a, b, c, d = pcall(fn, ...)
    if ok then return a, b, c, d end
end

local function Chrome() return Azaath:GetModule("MapChrome") end

local function Font(fs, size, bold)
    local C = Chrome()
    if C and C.Font then C.Font(fs, size, bold) else fs:SetFontObject(GameFontHighlight) end
end

local function ItemIcon(id)
    if _G.C_Item and C_Item.GetItemIconByID then
        local i = Safe(C_Item.GetItemIconByID, id)
        if i then return i end
    end
    return Safe(GetItemIcon, id) or "Interface\\Icons\\INV_Misc_QuestionMark"
end

---------------------------------------------------------------------------
-- Montagem
---------------------------------------------------------------------------
local function Button(parent, label, w)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(w, 26)
    local bg = b:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(0.06, 0.08, 0.09, 0.92)
    local line = b:CreateTexture(nil, "BORDER")
    line:SetPoint("BOTTOMLEFT"); line:SetPoint("BOTTOMRIGHT"); line:SetHeight(1)
    line:SetColorTexture(0.85, 0.7, 0.42, 0.7)
    local hl = b:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(0.37, 0.89, 0.90, 0.12)
    b.fs = b:CreateFontString(nil, "OVERLAY"); Font(b.fs, 13)
    b.fs:SetPoint("CENTER"); b.fs:SetText(label); b.fs:SetTextColor(0.92, 0.86, 0.7)
    return b
end

local function Row(i)
    local r = U.rows[i]
    if r then return r end
    r = CreateFrame("Button", nil, U.list)
    r:SetSize(W - 32, ROW_H - 2)
    r:SetPoint("TOPLEFT", 0, -(i - 1) * ROW_H)
    r:RegisterForClicks("LeftButtonUp")
    local hl = r:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(); hl:SetColorTexture(0.37, 0.89, 0.90, 0.08)
    r.icon = r:CreateTexture(nil, "ARTWORK")
    r.icon:SetSize(22, 22); r.icon:SetPoint("LEFT", 2, 0)
    r.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    r.rim = r:CreateTexture(nil, "OVERLAY")
    r.rim:SetPoint("TOPLEFT", r.icon, -1, 1); r.rim:SetPoint("BOTTOMRIGHT", r.icon, 1, -1)
    r.rim:SetColorTexture(1, 1, 1, 0)
    r.pct = r:CreateFontString(nil, "OVERLAY"); Font(r.pct, 13)
    r.pct:SetPoint("RIGHT", -4, 0); r.pct:SetJustifyH("RIGHT")
    r.pct:SetTextColor(0.85, 0.8, 0.68)
    r.name = r:CreateFontString(nil, "OVERLAY"); Font(r.name, 13)
    r.name:SetPoint("LEFT", r.icon, "RIGHT", 8, 0)
    r.name:SetPoint("RIGHT", r.pct, "LEFT", -8, 0)
    r.name:SetJustifyH("LEFT"); r.name:SetWordWrap(false)
    r:SetScript("OnEnter", function(self)
        if not self.itemID then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if not Safe(GameTooltip.SetItemByID, GameTooltip, self.itemID) then
            GameTooltip:AddLine(self.itemName or ("Item " .. self.itemID))
        end
        GameTooltip:Show()
    end)
    r:SetScript("OnLeave", function() GameTooltip:Hide() end)
    r:SetScript("OnClick", function(self)
        if not (self.itemID and IsModifiedClick and IsModifiedClick("CHATLINK")) then return end
        local _, link = Safe(GetItemInfo, self.itemID)
        if link and ChatEdit_InsertLink then ChatEdit_InsertLink(link) end
    end)
    U.rows[i] = r
    return r
end

local function Build(parent)
    local f = CreateFrame("Frame", "AzaathUIRarePanel", parent)
    f:SetSize(W, 200)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    local C = Chrome()
    if C and C.PanelBox then
        C.PanelBox(f)
    else
        local bg = f:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0.03, 0.05, 0.06, 0.95)
    end
    if C and C.Tex then
        local gem = C.Tex(f, "PanelGem", 20, 12, "OVERLAY")
        gem:SetPoint("CENTER", f, "TOP", 0, 0)
    end

    -- fechar
    local x = CreateFrame("Button", nil, f)
    x:SetSize(24, 24); x:SetPoint("TOPRIGHT", -8, -8)
    local xi = C and C.Tex and C.Tex(x, "IcoClose", 14, 14) or x:CreateTexture()
    xi:SetPoint("CENTER")
    x:SetScript("OnEnter", function() xi:SetVertexColor(0.37, 0.89, 0.90) end)
    x:SetScript("OnLeave", function() xi:SetVertexColor(1, 1, 1) end)
    x:SetScript("OnClick", function() f:Hide() end)

    f.title = f:CreateFontString(nil, "OVERLAY"); Font(f.title, 17, true)
    f.title:SetPoint("TOPLEFT", 16, -14); f.title:SetPoint("RIGHT", -40, 0)
    f.title:SetJustifyH("LEFT"); f.title:SetTextColor(1, 0.82, 0.45)
    f.sub = f:CreateFontString(nil, "OVERLAY"); Font(f.sub, 13)
    f.sub:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -4); f.sub:SetTextColor(0.78, 0.78, 0.86)
    f.state = f:CreateFontString(nil, "OVERLAY"); Font(f.state, 13)
    f.state:SetPoint("TOPLEFT", f.sub, "BOTTOMLEFT", 0, -3)

    -- retrato
    local box = CreateFrame("Frame", nil, f)
    box:SetPoint("TOPLEFT", 14, -80); box:SetPoint("TOPRIGHT", -14, -80); box:SetHeight(170)
    local bbg = box:CreateTexture(nil, "BACKGROUND")
    bbg:SetAllPoints(); bbg:SetColorTexture(0, 0, 0, 0.45)
    local ok, model = pcall(CreateFrame, "PlayerModel", nil, box)
    if ok and model then
        model:SetAllPoints()
        U.model = model
    end
    box.none = box:CreateFontString(nil, "OVERLAY"); Font(box.none, 12)
    box.none:SetPoint("CENTER"); box.none:SetWidth(W - 60)
    box.none:SetTextColor(0.6, 0.6, 0.6)
    box.none:SetText("Sem retrato ainda.\nChegue perto do raro uma vez para registrar.")
    U.box = box

    -- drops
    f.dropsTitle = f:CreateFontString(nil, "OVERLAY"); Font(f.dropsTitle, 14, true)
    f.dropsTitle:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 2, -10); f.dropsTitle:SetTextColor(0.86, 0.74, 0.45)
    U.list = CreateFrame("Frame", nil, f)
    U.list:SetPoint("TOPLEFT", f.dropsTitle, "BOTTOMLEFT", 0, -6)
    U.list:SetSize(W - 32, ROWS * ROW_H)
    U.list:EnableMouseWheel(true)
    U.list:SetScript("OnMouseWheel", function(_, d)
        local n = U.drops and #U.drops or 0
        U.offset = math.max(0, math.min(n - ROWS, (U.offset or 0) - d))
        M:FillDrops()
    end)
    U.rows = {}
    f.more = f:CreateFontString(nil, "OVERLAY"); Font(f.more, 11)
    f.more:SetTextColor(0.55, 0.55, 0.55)
    f.empty = f:CreateFontString(nil, "OVERLAY"); Font(f.empty, 13)
    f.empty:SetPoint("TOPLEFT", U.list, "TOPLEFT", 2, -4); f.empty:SetWidth(W - 40); f.empty:SetJustifyH("LEFT")
    f.empty:SetTextColor(0.7, 0.7, 0.7)
    f.empty:SetText("Nenhum drop próprio: só loot aleatório do mundo (itens comuns e verdes do nível).")

    -- botões
    U.follow = Button(f, "SEGUIR", 150)
    U.follow:SetPoint("BOTTOMLEFT", 16, 14)
    U.follow:SetScript("OnClick", function() if U.onFollow then U.onFollow() end end)
    U.hide = Button(f, "ESCONDER DO MAPA", 150)
    U.hide:SetPoint("BOTTOMRIGHT", -16, 14)
    U.hide:SetScript("OnClick", function()
        local R = Azaath:GetModule("MapRares")
        if R and U.id then
            R:SetHidden(U.id, not R:State().hide[U.id])
            M:Refresh()
        end
    end)

    f:SetScript("OnHide", function() GameTooltip:Hide() end)
    -- ESC fecha
    if _G.UISpecialFrames then table.insert(UISpecialFrames, "AzaathUIRarePanel") end
    f:Hide()
    U.f = f
end

---------------------------------------------------------------------------
-- Conteúdo
---------------------------------------------------------------------------
local function ShowModel(id)
    local m, box = U.model, U.box
    box.none:Show()
    if not m then return end
    pcall(m.ClearModel, m)
    local function Has()
        local fid = Safe(m.GetModelFileID, m)
        return fid and fid ~= 0
    end
    -- modelo: o displayID dos dados (Rares.lua) ou o capturado pelo scanner. SetCreature(npcID) não serve:
    -- sem a criatura no cache, o cliente põe um modelo padrão (um urso) em todos.
    local R = Azaath:GetModule("MapRares")
    local info = R and R:Info(id)
    local disp = (info and info.display) or (R and R:State().display[id])
    if not (disp and m.SetDisplayInfo) then m:Hide() return end
    pcall(m.SetDisplayInfo, m, disp)
    local function Settle()
        if U.id ~= id then return end
        if not Has() then pcall(m.SetDisplayInfo, m, disp) end
        if Has() then
            box.none:Hide()
            pcall(m.SetPortraitZoom, m, 0)
            pcall(m.SetCamDistanceScale, m, 1.1)
            pcall(m.SetFacing, m, 0.35)
            m:Show()
        else
            m:Hide()
        end
    end
    m:Show()
    Settle()
    -- o jogo pode demorar a carregar a criatura: confere de novo
    C_Timer.After(0.4, Settle)
    C_Timer.After(1.5, Settle)
end

function M:FillDrops()
    local f = U.f
    local d = U.drops or {}
    local off = U.offset or 0
    for i = 1, ROWS do
        local r = Row(i)
        local e = d[off + i]
        if e then
            local name, q = e.name, e.q
            if not name or name == "" then
                local gn, _, gq = Safe(GetItemInfo, e.id)
                name, q = gn or ("Item " .. e.id), gq or q
            end
            local c = QUALITY[q or 1] or QUALITY[1]
            r.itemID, r.itemName = e.id, name
            r.icon:SetTexture(ItemIcon(e.id))
            r.name:SetText(name); r.name:SetTextColor(c[1], c[2], c[3])
            r.rim:SetColorTexture(c[1], c[2], c[3], (q or 1) >= 2 and 0.35 or 0)
            r.icon:SetDrawLayer("OVERLAY", 1)
            r.pct:SetText((e.pct >= 10 and tostring(math.floor(e.pct + 0.5)) or string.format("%.1f", e.pct)) .. "%")
            r:Show()
        else
            r.itemID = nil
            r:Hide()
        end
    end
    local n = #d
    f.empty:SetShown(n == 0)
    f.dropsTitle:SetText(n > 0 and ("DROPS (" .. n .. ")") or "DROPS")
    f.more:ClearAllPoints()
    f.more:SetPoint("TOPRIGHT", U.list, "BOTTOMRIGHT", 0, -2)
    f.more:SetText(n > ROWS and ("roda do mouse: mais itens  ·  " .. (off + 1) .. "-" .. math.min(n, off + ROWS) .. " de " .. n) or "Shift+clique: link no chat")
end

function M:Refresh()
    local R = Azaath:GetModule("MapRares")
    local id, f = U.id, U.f
    if not (R and id and f) then return end
    local info = R:Info(id)
    f.title:SetText(info and info.name or ("Raro " .. id))
    local sub = info and ("Nível " .. info.level .. (info.elite and "  ·  Raro de elite" or "  ·  Raro")) or "Raro"
    if info and info.respawn > 0 then sub = sub .. "  ·  Respawn ~" .. R.Ago(info.respawn) end
    f.sub:SetText(sub)
    local st = R:State()
    local left = R:RespawnLeft(id)
    local seen = R:SeenRecently(id)
    if seen then
        f.state:SetText("Visto há pouco por você"); f.state:SetTextColor(0.45, 0.95, 0.55)
    elseif left then
        f.state:SetText("Morto  ·  renasce em ~" .. R.Ago(left)); f.state:SetTextColor(0.95, 0.45, 0.4)
    elseif st.killed[id] then
        f.state:SetText("Morto há " .. R.Ago(time() - st.killed[id]) .. "  ·  já pode ter renascido"); f.state:SetTextColor(0.9, 0.75, 0.4)
    else
        f.state:SetText("Sem registro de morte"); f.state:SetTextColor(0.6, 0.6, 0.6)
    end
    U.hide.fs:SetText(st.hide[id] and "MOSTRAR NO MAPA" or "ESCONDER DO MAPA")
    U.follow:SetShown(U.onFollow ~= nil)
    -- drops
    local list = {}
    local d = info and info.drops or {}
    for i = 1, #d - 3, 4 do
        list[#list + 1] = { id = d[i], pct = d[i + 1], q = d[i + 2], name = d[i + 3] }
    end
    U.drops = list
    self:FillDrops()
    local listH = (#list > 0 and math.min(#list, ROWS) or 2) * ROW_H
    U.list:SetHeight(listH)
    f:SetHeight(80 + 170 + 10 + 20 + 6 + listH + 18 + 54)
end

-- id: npcID; parent: a janela do mapa; onFollow: função que segue o pino (ou nil)
function M:Open(id, parent, onFollow)
    if not U.f then Build(parent or UIParent) end
    local f = U.f
    if parent and f:GetParent() ~= parent then f:SetParent(parent) end
    f:SetFrameStrata("DIALOG")
    if not f.placed then
        f:ClearAllPoints()
        f:SetPoint("RIGHT", parent or UIParent, "RIGHT", -80, 0)
        f.placed = true
    end
    U.id, U.offset, U.onFollow = id, 0, onFollow
    self:Refresh()
    f:Show()
    ShowModel(id)
end

function M:IsShown(id)
    return U.f and U.f:IsShown() and (not id or U.id == id)
end
