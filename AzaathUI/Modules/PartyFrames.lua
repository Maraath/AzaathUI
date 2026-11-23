--[[----------------------------------------------------------------------------
    AzaathUI - Modules/PartyFrames.lua
    Quadros de grupo no canto superior esquerdo, estilo Azaath (3.3.5a):
    losango na cor da classe + nome + ícone de líder, barra de vida fina
    embaixo (azul Azaath, ou cor da classe). Alvo atual com nome em dourado.

    Interação (botões SEGUROS: SecureUnitButtonTemplate):
      * Clique esquerdo  = selecionar como alvo (seguro, funciona em combate)
      * Clique do meio   = definir foco (ação segura "focus")
      * Clique direito   = menu próprio da Azaath (sussurrar, inspecionar,
        negociar, promover/remover se você for o líder).
        NÃO usamos o menu da Blizzard (UIDropDownMenu): aberto por addon, ele
        contamina UIDROPDOWNMENU_* e passa a bloquear "Definir foco" em todos
        os menus de unidade. Por isso o foco fica no clique do meio.

    Visibilidade: RegisterUnitWatch em cada botão (o driver seguro mostra/
    esconde conforme party1-4 existem) e um driver de visibilidade no
    contêiner para sumir em raides.
    Alcance: UnitInRange a cada 0.5s; fora de alcance = transparente.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("PartyFrames")

local _G = _G
local ipairs = ipairs
local UnitExists, UnitName, UnitClass = UnitExists, UnitName, UnitClass
local UnitHealth, UnitHealthMax = UnitHealth, UnitHealthMax
local UnitIsDead, UnitIsGhost, UnitIsConnected = UnitIsDead, UnitIsGhost, UnitIsConnected
local UnitInRange, UnitIsUnit = UnitInRange, UnitIsUnit

local NUM_PARTY    = 4
local NAME_ROW     = 18
local BAR_H        = 5
local RANGE_TICK   = 0.5
local OUT_OF_RANGE = 0.45
local LOW_HEALTH   = 0.35

local AZ_BLUE   = { 0.29, 0.56, 0.89 }
local LOW_COLOR = { 0.86, 0.36, 0.30 }

local container
local frames = {}      -- [i] = botão
local byUnit = {}      -- ["party1"] = botão

--------------------------------------------------------------------------------
-- Atualizações (só métodos não protegidos: texto, cor, valores, alpha)
--------------------------------------------------------------------------------
local function ClassColor(unit)
    local _, class = UnitClass(unit)
    local cc = class and RAID_CLASS_COLORS and RAID_CLASS_COLORS[class]
    if cc then return cc.r, cc.g, cc.b end
    local c = Azaath.colors.cream
    return c[1], c[2], c[3]
end

local function UpdateName(f)
    local unit = f.unit
    if not UnitExists(unit) then return end
    f.name:SetText(UnitName(unit) or "")
    f.diamond:SetVertexColor(ClassColor(unit))
    if UnitIsUnit("target", unit) then
        local a = Azaath.colors.accent
        f.name:SetTextColor(a[1], a[2], a[3])
    else
        local c = Azaath.colors.cream
        f.name:SetTextColor(c[1], c[2], c[3])
    end
    if Azaath.API.IsGroupLeader(unit) then
        f.leader:Show()
    else
        f.leader:Hide()
    end
end

local function UpdateHealth(f)
    local unit = f.unit
    if not UnitExists(unit) then return end
    local cur, max = UnitHealth(unit), UnitHealthMax(unit)
    local secret = Azaath.AnySecret(cur, max)
    if not secret and max <= 0 then max = 1 end
    f.bar:SetMinMaxValues(0, max)

    local status
    if not UnitIsConnected(unit) then
        status = "Offline"
    elseif UnitIsGhost(unit) then
        status = "Fantasma"
    elseif UnitIsDead(unit) then
        status = "Morto"
    end

    if status then
        f.bar:SetValue(0)
        if Azaath.UpdateHealPrediction then Azaath.UpdateHealPrediction(f.bar, unit, true) end
        f.status:SetText(status)
        f.status:Show()
        f.diamond:SetVertexColor(0.5, 0.5, 0.5)
        return
    end
    f.status:Hide()
    f.bar:SetValue(cur)

    local r, g, b
    -- valor secreto: sem a cor de vida baixa (não dá para comparar)
    if not secret and cur / max < LOW_HEALTH then
        r, g, b = LOW_COLOR[1], LOW_COLOR[2], LOW_COLOR[3]
    elseif M.db.classColor then
        r, g, b = ClassColor(unit)
    else
        r, g, b = AZ_BLUE[1], AZ_BLUE[2], AZ_BLUE[3]
    end
    f.bar:SetStatusBarColor(r, g, b)
    -- cura prevista (faixa verde-clara, igual aos quadros do jogador/alvo)
    if Azaath.UpdateHealPrediction then Azaath.UpdateHealPrediction(f.bar, unit) end
end

local function UpdateAll(f)
    if not UnitExists(f.unit) and M.editing then
        local c = Azaath.colors.cream
        f.name:SetText("Aliado " .. (f.index or ""))
        f.name:SetTextColor(c[1], c[2], c[3])
        f.diamond:SetVertexColor(AZ_BLUE[1], AZ_BLUE[2], AZ_BLUE[3])
        if f.index == 1 then f.leader:Show() else f.leader:Hide() end
        f.status:Hide()
        f.bar:SetMinMaxValues(0, 100)
        f.bar:SetValue(85)
        f.bar:SetStatusBarColor(AZ_BLUE[1], AZ_BLUE[2], AZ_BLUE[3])
        f:SetAlpha(1)
        return
    end
    UpdateName(f)
    UpdateHealth(f)
end

local function UpdateRange()
    for i = 1, NUM_PARTY do
        local f = frames[i]
        if f and f:IsVisible() then
            if not UnitExists(f.unit) and M.editing then
                f:SetAlpha(1)
            else
                local inRange = UnitInRange(f.unit)
                local connected = UnitIsConnected(f.unit)
                if Azaath.IsSecret(inRange) then
                    f:SetAlpha(connected and 1 or OUT_OF_RANGE)
                else
                    f:SetAlpha((inRange or not connected) and 1 or OUT_OF_RANGE)
                end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Menu de contexto (somente ações NÃO protegidas)
--------------------------------------------------------------------------------
local function OpenMenu(self, unit)
    if not UnitExists(unit) then return end
    local name, realm = UnitName(unit)
    local fullName = (realm and realm ~= "") and (name .. "-" .. realm) or name
    local isLeader = Azaath.API.IsGroupLeader("player")

    local entries = { title = Azaath.Tracked(name or "") }
    entries[#entries + 1] = { text = "Sussurrar", func = function() ChatFrame_SendTell(fullName) end }
    entries[#entries + 1] = {
        text = "Inspecionar",
        disabled = not (UnitIsConnected(unit) and CheckInteractDistance(unit, 1)),
        func = function() InspectUnit(unit) end,
    }
    entries[#entries + 1] = {
        text = "Negociar",
        disabled = not (UnitIsConnected(unit) and CheckInteractDistance(unit, 2)),
        func = function() InitiateTrade(unit) end,
    }
    if isLeader then
        entries[#entries + 1] = { text = "Promover a líder", func = function() PromoteToLeader(unit) end }
        entries[#entries + 1] = { text = "Remover do grupo", func = function() UninviteUnit(fullName) end }
    end
    entries[#entries + 1] = { text = "Foco: clique do meio", disabled = true }
    Azaath:ShowMenu(entries)
end

--------------------------------------------------------------------------------
-- Construção
--------------------------------------------------------------------------------
local function CreateText(parent, font, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(font, size, "")
    fs:SetShadowOffset(1, -1)
    fs:SetShadowColor(0, 0, 0, 0.95)
    fs:SetJustifyH("LEFT")
    return fs
end

local function CreateMember(i)
    local db, c, media = M.db, Azaath.colors, Azaath.media
    local unit = "party" .. i

    local f = CreateFrame("Button", "AzaathUIParty" .. i, container, "SecureUnitButtonTemplate")
    f:SetWidth(db.width)
    f:SetHeight(NAME_ROW + 2 + BAR_H)
    f:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(i - 1) * db.spacing)
    f:RegisterForClicks("AnyUp")

    -- Atributos seguros (definidos fora de combate, na criação)
    f:SetAttribute("unit", unit)
    f:SetAttribute("*type1", "target")
    -- Cliente moderno: "togglemenu" abre o menu de unidade da PRÓPRIA Blizzard
    -- pelo caminho seguro (sem taint; "Definir foco" funciona lá também).
    -- 3.3.5: "menu" chama self.menu (o nosso menu próprio, abaixo).
    f:SetAttribute("*type2", Azaath.IS_MODERN and "togglemenu" or "menu")
    f:SetAttribute("*type3", "focus")
    f.menu = OpenMenu   -- chamado pela ação segura "menu" com (self, unit, button)
    f.unit = unit
    f.index = i
    RegisterUnitWatch(f)

    -- Losango na cor da classe
    f.diamond = f:CreateTexture(nil, "ARTWORK")
    f.diamond:SetTexture(media.path .. "Diamond")
    f.diamond:SetWidth(11)
    f.diamond:SetHeight(11)
    f.diamond:SetPoint("TOPLEFT", f, "TOPLEFT", 1, -3)

    f.name = CreateText(f, media.font, 14)
    f.name:SetPoint("TOPLEFT", f, "TOPLEFT", 17, -1)
    f.name:SetWidth(db.width - 40)
    f.name:SetHeight(16)

    f.leader = f:CreateTexture(nil, "OVERLAY")
    f.leader:SetTexture("Interface\\GroupFrame\\UI-Group-LeaderIcon")
    f.leader:SetWidth(12)
    f.leader:SetHeight(12)
    f.leader:SetPoint("TOPRIGHT", f, "TOPRIGHT", -2, -2)
    f.leader:Hide()

    f.status = CreateText(f, media.font, 11)
    f.status:SetPoint("RIGHT", f.leader, "LEFT", -4, 0)
    f.status:SetTextColor(c.dim[1], c.dim[2], c.dim[3])
    f.status:Hide()

    -- Barra de vida fina
    local barH = db.barHeight or BAR_H
    local bg = f:CreateTexture(nil, "BACKGROUND")
    bg:SetTexture(media.blank)
    bg:SetVertexColor(0, 0, 0)
    bg:SetAlpha(0.6)
    bg:SetPoint("TOPLEFT", f, "TOPLEFT", -1, -(NAME_ROW + 1))
    bg:SetPoint("TOPRIGHT", f, "TOPRIGHT", 1, -(NAME_ROW + 1))
    bg:SetHeight(barH + 2)
    f.bg = bg

    f.bar = CreateFrame("StatusBar", nil, f)
    f.bar:SetPoint("TOPLEFT", f, "TOPLEFT", 0, -(NAME_ROW + 2))
    f.bar:SetPoint("TOPRIGHT", f, "TOPRIGHT", 0, -(NAME_ROW + 2))
    f.bar:SetHeight(barH)
    f.bar:SetStatusBarTexture(media.blank)
    f.bar:SetMinMaxValues(0, 1)
    f.bar:SetValue(1)

    f:SetHeight(NAME_ROW + 2 + barH)

    -- Tooltip de unidade padrão; atualiza ao aparecer (unit watch mostrou)
    f:SetScript("OnEnter", function(self)
        GameTooltip_SetDefaultAnchor(GameTooltip, self)
        GameTooltip:SetUnit(self.unit)
    end)
    f:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f:HookScript("OnShow", UpdateAll)

    frames[i] = f
    byUnit[unit] = f
end

local function Build()
    local db = M.db
    container = CreateFrame("Frame", "AzaathUIPartyContainer", Azaath.root, "SecureHandlerStateTemplate")
    container:SetFrameStrata("LOW")
    container:SetScale((db.scale and db.scale > 0) and db.scale or 1)
    container:SetWidth(db.width)
    container:SetHeight(NUM_PARTY * db.spacing)
    container:SetPoint("TOPLEFT", Azaath.root, "TOPLEFT", db.offsetX, db.offsetY)
    if not db.showInRaid then
        RegisterStateDriver(container, "visibility", "[group:raid] hide; show")
    end

    for i = 1, NUM_PARTY do CreateMember(i) end

    -- Quadros da Blizzard: botões seguros, então só fora de combate
    if Azaath.db.hideBlizzard.partyFrames and Azaath.DisableBlizzardFrame then
        for i = 1, NUM_PARTY do
            local pf = _G["PartyMemberFrame" .. i]
            if pf then
                Azaath.DisableBlizzardFrame(pf, { unitWatch = true })
                if pf.healthbar and pf.healthbar.UnregisterAllEvents then pf.healthbar:UnregisterAllEvents() end
                if pf.manabar and pf.manabar.UnregisterAllEvents then pf.manabar:UnregisterAllEvents() end
            end
            Azaath.DisableBlizzardFrame("PartyMemberFrame" .. i .. "HealthBar")
            Azaath.DisableBlizzardFrame("PartyMemberFrame" .. i .. "ManaBar")
            Azaath.DisableBlizzardFrame("PartyMemberFrame" .. i .. "PetFrame", { unitWatch = true })
        end
        Azaath.DisableBlizzardFrame("PartyMemberBackground")
        if _G.PartyFrame then
            Azaath.DisableBlizzardFrame("PartyFrame") -- contêiner no cliente moderno
            if _G.PartyFrame.GetChildren then
                for _, child in ipairs({ _G.PartyFrame:GetChildren() }) do
                    if child.UnregisterAllEvents then pcall(child.UnregisterAllEvents, child) end
                    if child.healthbar and child.healthbar.UnregisterAllEvents then
                        pcall(child.healthbar.UnregisterAllEvents, child.healthbar)
                    end
                    if child.manabar and child.manabar.UnregisterAllEvents then
                        pcall(child.manabar.UnregisterAllEvents, child.manabar)
                    end
                end
            end
        end
    end

    for i = 1, NUM_PARTY do UpdateAll(frames[i]) end
end

--------------------------------------------------------------------------------
-- Eventos
--------------------------------------------------------------------------------
local events = CreateFrame("Frame")
events:SetScript("OnEvent", function(_, event, unit)
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" then
        local f = byUnit[unit]
        if f then UpdateHealth(f) end
    elseif event == "UNIT_HEAL_PREDICTION" then
        local f = byUnit[unit]
        if f and Azaath.UpdateHealPrediction then Azaath.UpdateHealPrediction(f.bar, unit) end
    elseif event == "UNIT_NAME_UPDATE" then
        local f = byUnit[unit]
        if f then UpdateName(f) end
    else
        -- grupo mudou, líder mudou, alvo mudou, membro conectou/desconectou
        for i = 1, NUM_PARTY do
            if frames[i] then UpdateAll(frames[i]) end
        end
    end
end)

local ticker = CreateFrame("Frame")
ticker.elapsed = 0
ticker:SetScript("OnUpdate", function(self, elapsed)
    self.elapsed = (self.elapsed or 0) + (elapsed or 0)
    if self.elapsed < RANGE_TICK then return end
    self.elapsed = 0
    UpdateRange()
end)
ticker:Hide()

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:ApplyLayout()
    local db = self.db
    if not db or not container then return end
    Azaath:RunOutOfCombat(function()
        local w = db.width or 200
        local sp = db.spacing or 42
        local barH = db.barHeight or BAR_H
        local sc = (db.scale and db.scale > 0) and db.scale or 1

        container:SetScale(sc)
        container:SetWidth(w)
        container:SetHeight(NUM_PARTY * sp)
        container:ClearAllPoints()
        container:SetPoint("TOPLEFT", Azaath.root, "TOPLEFT", db.offsetX or 28, db.offsetY or -130)
        if Azaath.ClampToScreen then Azaath.ClampToScreen(container) end

        if UnregisterStateDriver then
            pcall(UnregisterStateDriver, container, "visibility")
        end
        if self.editing then
            container:Show()
        elseif not db.showInRaid then
            RegisterStateDriver(container, "visibility", "[group:raid] hide; show")
        else
            container:Show()
        end

        for i = 1, NUM_PARTY do
            local f = frames[i]
            if f then
                f:SetWidth(w)
                f:SetHeight(NAME_ROW + 2 + barH)
                f:ClearAllPoints()
                f:SetPoint("TOPLEFT", container, "TOPLEFT", 0, -(i - 1) * sp)
                if f.name then f.name:SetWidth(math.max(40, w - 40)) end
                if f.bg then f.bg:SetHeight(barH + 2) end
                if f.bar then f.bar:SetHeight(barH) end
                if self.editing and not UnitExists(f.unit) then
                    UnregisterUnitWatch(f)
                    f:Show()
                else
                    RegisterUnitWatch(f)
                end
                UpdateAll(f)
            end
        end
    end)
end

function M:SetEditing(editing)
    self.editing = editing and true or false
    self:ApplyLayout()
end

function M:OnInitialize()
    self.db = Azaath.db.party
end

function M:OnEnable()
    if not self.db.enabled then return end
    -- Com os quadros da Blizzard restaurados, não duplica
    if not Azaath.db.hideBlizzard.partyFrames then return end

    -- Botões seguros: criar/registrar só fora de combate
    Azaath:RunOutOfCombat(function()
        Build()
        for _, e in ipairs({ "UNIT_HEALTH", "UNIT_MAXHEALTH", "UNIT_HEAL_PREDICTION", "UNIT_NAME_UPDATE",
                             "PARTY_MEMBERS_CHANGED", "PARTY_LEADER_CHANGED",
                             "GROUP_ROSTER_UPDATE", "UNIT_CONNECTION", -- cliente moderno
                             "PARTY_MEMBER_ENABLE", "PARTY_MEMBER_DISABLE",
                             "PLAYER_TARGET_CHANGED", "PLAYER_ENTERING_WORLD" }) do
            Azaath.SafeRegister(events, e)
        end
        ticker:Show()
    end)
end
