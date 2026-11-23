--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ActionCam/Vignette.lua
    Vinheta sutil nas bordas da tela com fade suave, baseada nas condições
    configuradas (mouselook, combat, interaction) e tintagem no Modo Suporte.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local _G = _G

local AC = Azaath.ActionCam or {}
Azaath.ActionCam = AC

local CreateFrame   = _G.CreateFrame
local InCombatLockdown = _G.InCombatLockdown
local UnitAffectingCombat = _G.UnitAffectingCombat
local UnitExists    = _G.UnitExists
local UIParent      = _G.UIParent

local min, max = math.min, math.max

local vignetteFrame, vignetteTex
local currentAlpha = 0
local targetAlpha  = 0
local fadeDuration = 0.35

local function EnsureVignette()
    if vignetteFrame then return vignetteFrame end
    vignetteFrame = CreateFrame("Frame", "AzaathUIActionVignette", UIParent)
    vignetteFrame:SetAllPoints(UIParent)
    vignetteFrame:SetFrameStrata("BACKGROUND")
    vignetteFrame:SetFrameLevel(0)
    vignetteFrame:EnableMouse(false)
    vignetteFrame:SetAlpha(0)
    vignetteFrame:Hide()

    vignetteTex = vignetteFrame:CreateTexture(nil, "BACKGROUND")
    vignetteTex:SetAllPoints(vignetteFrame)
    vignetteTex:SetTexture(Azaath.media.path .. "Minimap\\MinimapVignette.tga")
    vignetteTex:SetVertexColor(0, 0, 0, 0.72)

    vignetteFrame:SetScript("OnUpdate", function(self, elapsed)
        local step = (elapsed or 0.016) / fadeDuration
        if currentAlpha < targetAlpha then
            currentAlpha = min(targetAlpha, currentAlpha + step)
        elseif currentAlpha > targetAlpha then
            currentAlpha = max(targetAlpha, currentAlpha - step)
        end
        self:SetAlpha(currentAlpha)
        if currentAlpha <= 0.001 and targetAlpha == 0 then
            currentAlpha = 0
            self:Hide()
        end
    end)

    return vignetteFrame
end

local function ShouldShowVignette()
    local db = AC.DB()
    if not db or not db.enabled then return false end
    local conds = db.vignetteConditions or ""
    if conds == "" then return false end

    local wantMouse  = conds:find("mouselook", 1, true) ~= nil
    local wantCombat = conds:find("combat", 1, true) ~= nil
    local wantInter  = conds:find("interaction", 1, true) ~= nil
    if not (wantMouse or wantCombat or wantInter) then return false end

    local isMouse  = AC.IsMouseLookCameraChromeActive and AC.IsMouseLookCameraChromeActive() or false
    local isCombat = InCombatLockdown() or (UnitAffectingCombat and UnitAffectingCombat("player")) or false
    local isInter  = (UnitExists("softinteract") or UnitExists("npc")) and true or false

    if db.vignetteMatch == "all" then
        if wantMouse  and not isMouse  then return false end
        if wantCombat and not isCombat then return false end
        if wantInter  and not isInter  then return false end
        return true
    else
        if wantMouse  and isMouse  then return true end
        if wantCombat and isCombat then return true end
        if wantInter  and isInter  then return true end
        return false
    end
end

function AC.UpdateVignette()
    local f = EnsureVignette()
    local db = AC.DB()
    local show = ShouldShowVignette()
    targetAlpha = show and 1 or 0

    if db and db.supportModeActive and db.supportModeTintVignette then
        vignetteTex:SetVertexColor(0.18, 0.55, 0.42, 0.65)
    else
        vignetteTex:SetVertexColor(0, 0, 0, 0.72)
    end

    if show and not f:IsShown() then
        f:Show()
    end
end
