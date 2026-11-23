--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Skins.lua
    Aplica o painel Azaath (azul-carvão, borda fina) a frames da Blizzard que só
    precisam de troca de fundo/borda:

      * Tooltips (GameTooltip, comparação, links, mapa): painel Azaath, título em
        Cinzel, barra de vida plana e borda na cor da RARIDADE do item.
      * Caixas de confirmação (StaticPopup1-4) e menus suspensos (DropDownList).

    Segurança/taint: só métodos de widget (SetBackdrop*, SetFont,
    SetStatusBarTexture) e HookScript — nada é gravado em tabelas da Blizzard.
    A Blizzard redefine as cores dos tooltips ao esconder (GameTooltip_OnHide),
    então as cores são reaplicadas em OnShow / OnTooltipSetItem.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("Skins")

local _G = _G
local ipairs, select = ipairs, select

local TOOLTIPS = {
    "GameTooltip", "ItemRefTooltip", "ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3",
    "ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "WorldMapTooltip", "FriendsTooltip",
}
local POPUPS = { "StaticPopup1", "StaticPopup2", "StaticPopup3", "StaticPopup4" }
local DROPDOWNS = {
    "DropDownList1Backdrop", "DropDownList2Backdrop", "DropDownList3Backdrop",
    "DropDownList1MenuBackdrop", "DropDownList2MenuBackdrop", "DropDownList3MenuBackdrop",
}

local backdrop
local function GetBackdrop()
    if not backdrop then
        local blank = Azaath.media.blank
        backdrop = {
            bgFile = blank, edgeFile = blank, edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        }
    end
    return backdrop
end

-- Painel Azaath padrão (também usado pelo módulo Dialog)
function Azaath.ApplyPanel(frame, alpha)
    local c = Azaath.colors
    Azaath.SetBackdrop(frame, GetBackdrop())
    frame:SetBackdropColor(c.dark[1], c.dark[2], c.dark[3], alpha or 0.94)
    frame:SetBackdropBorderColor(c.slate[1], c.slate[2], c.slate[3], 0.9)
end

--------------------------------------------------------------------------------
-- Tooltips
--------------------------------------------------------------------------------
-- Pinta fundo e borda de um frame da Blizzard:
--   * cliente moderno: tooltips/popups usam NineSlice (não trocamos o desenho,
--     só as cores — sem misturar BackdropTemplate em frames da Blizzard)
--   * 3.3.5: backdrop clássico
local function Paint(f, bg, bgA, br, bgG, bb, bA)
    local ns = f.NineSlice
    if ns and ns.SetCenterColor then
        ns:SetCenterColor(bg[1], bg[2], bg[3], bgA)
        ns:SetBorderColor(br, bgG, bb, bA)
    elseif f.SetBackdropColor then
        f:SetBackdropColor(bg[1], bg[2], bg[3], bgA)
        f:SetBackdropBorderColor(br, bgG, bb, bA)
    end
end

-- Borda: cor da raridade quando é item (incomum ou melhor), senão ardósia.
local function RecolorTooltip(tt)
    local c = Azaath.colors
    local link = tt.GetItem and select(2, tt:GetItem())
    local quality = link and select(3, Azaath.API.GetItemInfo(link))
    if quality and quality >= 2 then
        local r, g, b = Azaath.API.GetItemQualityColor(quality)
        Paint(tt, c.dark, 0.94, r, g, b, 0.9)
    else
        Paint(tt, c.dark, 0.94, c.slate[1], c.slate[2], c.slate[3], 0.9)
    end
end

local function SkinTooltips()
    for _, name in ipairs(TOOLTIPS) do
        local tt = _G[name]
        if tt then
            -- 3.3.5: troca o backdrop pela borda fina; moderno: só recolore o NineSlice
            if not tt.NineSlice and tt.SetBackdrop then
                Azaath.SetBackdrop(tt, GetBackdrop())
            end
            RecolorTooltip(tt)
            tt:HookScript("OnShow", RecolorTooltip)
            if tt:HasScript("OnTooltipSetItem") then
                tt:HookScript("OnTooltipSetItem", RecolorTooltip)
            end
        end
    end
    -- Cliente moderno: o gancho de item vem do TooltipDataProcessor
    if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall and Enum and Enum.TooltipDataType then
        TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tt)
            if tt and tt.GetItem then RecolorTooltip(tt) end
        end)
    end

    -- Título em Cinzel (como os nomes de item do Azaath); corpo na sans do addon
    if GameTooltipHeaderText then
        GameTooltipHeaderText:SetFont(Azaath.media.fontTitleB, 14, "")
    end
    if GameTooltipText then
        GameTooltipText:SetFont(Azaath.media.font, 13, "")
    end
    if GameTooltipTextSmall then
        GameTooltipTextSmall:SetFont(Azaath.media.font, 12, "")
    end

    -- Barra de vida da unidade: plana e fina, colada na base
    local bars = {
        _G.GameTooltipStatusBar,
        GameTooltip and GameTooltip.StatusBar,
        GameTooltip and GameTooltip.healthBar,
        GameTooltip and GameTooltip.HealthBar,
    }
    for _, bar in ipairs(bars) do
        if bar then
            bar:SetStatusBarTexture(Azaath.media.blank)
            bar:SetHeight(4)
            bar:ClearAllPoints()
            bar:SetPoint("BOTTOMLEFT", GameTooltip, "BOTTOMLEFT", 2, 2)
            bar:SetPoint("BOTTOMRIGHT", GameTooltip, "BOTTOMRIGHT", -2, 2)
            -- No cliente 12.x/Camelot, HealthBar_OnValueChanged compara 'value' (secret number)
            -- se a chamada vier de contexto de addon, gerando erro.
            if Azaath.IS_MODERN then
                bar:SetScript("OnValueChanged", nil)
            end
        end
    end

    for _, name in ipairs(TOOLTIPS) do
        local tt = _G[name]
        if tt then
            local sb = tt.StatusBar or tt.healthBar or tt.HealthBar or _G[name .. "StatusBar"]
            if sb and Azaath.IS_MODERN then
                sb:SetScript("OnValueChanged", nil)
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Caixas de confirmação e menus suspensos
--------------------------------------------------------------------------------
local function SkinPopups()
    local c = Azaath.colors
    local function Restyle(f)
        if f.NineSlice then
            Paint(f, c.dark, 0.96, c.slate[1], c.slate[2], c.slate[3], 0.9) -- moderno
        else
            Azaath.ApplyPanel(f, 0.96) -- 3.3.5
        end
    end
    for _, list in ipairs({ POPUPS, DROPDOWNS }) do
        for _, name in ipairs(list) do
            local f = _G[name]
            if f and (f.NineSlice or f.SetBackdrop) then
                Restyle(f)
                f:HookScript("OnShow", Restyle)
                local text = _G[name .. "Text"]
                if text then text:SetFont(Azaath.media.font, 14, "") end
            end
        end
    end
end

--------------------------------------------------------------------------------
-- Menus de contexto modernos (Blizzard_Menu) abertos a partir dos NOSSOS
-- botões (ex.: clique direito na barra de vida do jogador)
--
-- O menu continua sendo o da Blizzard (aberto pelo caminho seguro
-- "togglemenu"), então todas as opções funcionam sem taint. Só trocamos o
-- visual, sempre por hooksecurefunc (o hook roda isolado e não contamina o
-- código da Blizzard):
--   * MenuStyle1Mixin.Generate: esconde o fundo da Blizzard e anexa o painel
--     Azaath (fundo carvão em degradê + moldura clara pintada à mão, a mesma arte
--     dos espaços da barra de ação). Regiões anexadas pelo compositor são
--     liberadas quando o menu fecha, então nada vaza para outros menus.
--   * MenuVariants.CreateHighlight / CreateSubmenuArrow / CreateFontString:
--     destaque, seta e fonte Azaath nos itens.
-- Só menus "nossos" mudam: o raiz é o que abre com o mouse sobre um botão
-- registrado; submenus são os que abrem com o mouse sobre um menu já pintado.
--------------------------------------------------------------------------------
local menuOwners = {}                               -- [botão] = true
local azMenus = setmetatable({}, { __mode = "k" })  -- frames de menu pintados agora

local function MouseOverAny(set)
    for f in pairs(set) do
        if f:IsVisible() and f:IsMouseOver() then return true end
    end
    return false
end

local function IsInAzMenu(frame)
    local p = frame
    for _ = 1, 6 do
        if not p then return false end
        if azMenus[p] then return true end
        p = p:GetParent()
    end
    return false
end

-- Moldura em 9 fatias recortada de Media/ActionBar/SlotBorder (64x64):
-- cantos fixos e lados esticados mantêm o traço irregular de pincel.
local BORDER_TEX = 5 / 64 -- tamanho do canto na textura
local BORDER_PX = 4       -- tamanho do canto na tela
local function AttachAzPanel(menu)
    local media = Azaath.media

    local bg = menu:AttachTexture()
    bg:SetDrawLayer("BACKGROUND", -7)
    bg:SetTexture(media.blank)
    bg:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -2)
    bg:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -2, 2)
    -- degradê vertical: carvão um pouco mais claro em cima
    Azaath.Gradient(bg, "VERTICAL", 0.035, 0.04, 0.045, 0.97, 0.10, 0.11, 0.12, 0.97)

    local tex = media.path .. "ActionBar\\SlotBorder"
    local a, b = BORDER_TEX, 1 - BORDER_TEX
    local function piece(l, r, t, bt)
        local p = menu:AttachTexture()
        p:SetDrawLayer("BORDER", 7)
        p:SetTexture(tex)
        p:SetTexCoord(l, r, t, bt)
        return p
    end
    -- cantos (tamanho fixo)
    local tl, tr = piece(0, a, 0, a), piece(b, 1, 0, a)
    local bl, br = piece(0, a, b, 1), piece(b, 1, b, 1)
    for point, corner in pairs({ TOPLEFT = tl, TOPRIGHT = tr, BOTTOMLEFT = bl, BOTTOMRIGHT = br }) do
        corner:SetSize(BORDER_PX, BORDER_PX)
        corner:SetPoint(point, menu, point)
    end
    -- lados (esticados entre os cantos)
    local top = piece(a, b, 0, a)
    top:SetPoint("TOPLEFT", tl, "TOPRIGHT")
    top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
    local bottom = piece(a, b, b, 1)
    bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT")
    bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
    local left = piece(0, a, a, b)
    left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT")
    left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
    local right = piece(b, 1, a, b)
    right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT")
    right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
end

local menuHooksInstalled
local function InstallMenuHooks()
    if menuHooksInstalled then return end
    if not (MenuStyle1Mixin and MenuStyle1Mixin.Generate and MenuVariants) then return end
    menuHooksInstalled = true

    hooksecurefunc(MenuStyle1Mixin, "Generate", function(menu)
        local ours = MouseOverAny(menuOwners) or MouseOverAny(azMenus)
        if not ours then
            azMenus[menu] = nil -- frame reaproveitado por outro menu
            return
        end
        -- some com o fundo da Blizzard (só as regiões criadas agora pelo estilo)
        for _, region in ipairs({ menu:GetRegions() }) do
            region:SetAlpha(0)
        end
        AttachAzPanel(menu)
        azMenus[menu] = true
    end)

    local c = Azaath.colors
    hooksecurefunc(MenuVariants, "CreateHighlight", function(frame)
        if not (frame.highlight and IsInAzMenu(frame)) then return end
        -- faixa clara discreta (ADD), como a seleção de listas do Azaath
        frame.highlight:SetColorTexture(1, 1, 1, 0.09)
    end)
    hooksecurefunc(MenuVariants, "CreateSubmenuArrow", function(frame)
        if not (frame.arrow and IsInAzMenu(frame)) then return end
        frame.arrow:SetVertexColor(c.cream[1], c.cream[2], c.cream[3])
    end)
    -- O compositor proíbe SetFont nas FontStrings do menu: usamos um objeto
    -- de fonte próprio com SetFontObject (permitido). Cor/título continuam
    -- sendo aplicados depois pela Blizzard (SetTextColor).
    local menuFont = CreateFont("AzaathUIMenuFont")
    menuFont:SetFont(Azaath.media.font, 13, "")
    menuFont:SetTextColor(c.cream[1], c.cream[2], c.cream[3])
    menuFont:SetShadowOffset(1, -1)
    menuFont:SetShadowColor(0, 0, 0, 0.8)
    hooksecurefunc(MenuVariants, "CreateFontString", function(frame)
        if not IsInAzMenu(frame) then return end
        -- o texto recém-anexado é a única FontString do item neste momento
        for _, region in ipairs({ frame:GetRegions() }) do
            if region:GetObjectType() == "FontString" then
                region:SetFontObject(menuFont)
            end
        end
    end)
end

-- Registra um botão nosso cujo menu de contexto (togglemenu) deve usar o visual Azaath
function Azaath.RegisterAzMenuOwner(button)
    menuOwners[button] = true
    InstallMenuHooks()
end

--------------------------------------------------------------------------------
-- Ciclo de vida
--------------------------------------------------------------------------------
function M:OnInitialize()
    self.db = Azaath.db.skins
end

function M:OnEnable()
    if self.db.tooltips then SkinTooltips() end
    if self.db.popups then SkinPopups() end
    -- caso algum botão tenha se registrado antes do Blizzard_Menu existir
    if next(menuOwners) then InstallMenuHooks() end
end
