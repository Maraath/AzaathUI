--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ActionCam/AllyCycle.lua
    Ciclo de Aliados (Ally Cycle) + HUD compacto próximo à mira com nome,
    cor de classe e barra de vida segura contra secret values.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local _G = _G

local AC = Azaath.ActionCam or {}
Azaath.ActionCam = AC

local CreateFrame       = _G.CreateFrame
local GetNumGroupMembers = _G.GetNumGroupMembers
local IsInRaid          = _G.IsInRaid
local PlaySound         = _G.PlaySound
local SOUNDKIT          = _G.SOUNDKIT
local TargetUnit        = _G.TargetUnit
local UIParent          = _G.UIParent
local UnitClass         = _G.UnitClass
local UnitExists        = _G.UnitExists
local UnitHealth        = _G.UnitHealth
local UnitHealthMax     = _G.UnitHealthMax
local UnitIsUnit        = _G.UnitIsUnit
local UnitName          = _G.UnitName

local pcall, tonumber, type = pcall, tonumber, type

local currentIndex = 0
local allyList = {}
local hudFrame, hudName, hudBar

local function RebuildAllyList()
    local db = AC.DB()
    local cfg = db and db.allyCycle or {}
    local list = {}

    if not cfg.skipPlayer then
        list[#list + 1] = "player"
    end

    local num = GetNumGroupMembers and GetNumGroupMembers() or 0
    if IsInRaid and IsInRaid() then
        for i = 1, num do
            local u = "raid" .. i
            if UnitExists(u) and not (cfg.skipPlayer and UnitIsUnit(u, "player")) then
                list[#list + 1] = u
            end
        end
    else
        for i = 1, 4 do
            local u = "party" .. i
            if UnitExists(u) then
                list[#list + 1] = u
            end
        end
    end

    local extra = cfg.extraUnits or ""
    if extra:find("playerPet", 1, true) and UnitExists("pet") then
        list[#list + 1] = "pet"
    end
    if extra:find("partyPets", 1, true) then
        for i = 1, 4 do
            local u = "partypet" .. i
            if UnitExists(u) then
                list[#list + 1] = u
            end
        end
    end

    allyList = list
    return list
end

local function EnsureHUD()
    if hudFrame then return hudFrame end
    local anchor = _G.AzaathUICrosshairFrame or UIParent
    hudFrame = CreateFrame("Frame", "AzaathUIAllyCycleHUD", UIParent)
    hudFrame:SetSize(130, 26)
    hudFrame:SetPoint("TOP", anchor, "BOTTOM", 0, -24)
    hudFrame:EnableMouse(false)
    hudFrame:Hide()

    Azaath.SetBackdrop(hudFrame, {
        bgFile   = Azaath.media.blank,
        edgeFile = Azaath.media.blank,
        edgeSize = 1,
    })
    hudFrame:SetBackdropColor(0.06, 0.06, 0.07, 0.82)
    hudFrame:SetBackdropBorderColor(0.79, 0.66, 0.42, 0.75)

    hudName = hudFrame:CreateFontString(nil, "OVERLAY")
    hudName:SetFont(Azaath.media.fontBold, 11, "OUTLINE")
    hudName:SetPoint("TOPLEFT", hudFrame, "TOPLEFT", 6, -3)
    hudName:SetPoint("TOPRIGHT", hudFrame, "TOPRIGHT", -6, -3)
    hudName:SetJustifyH("LEFT")

    hudBar = CreateFrame("StatusBar", nil, hudFrame)
    hudBar:SetStatusBarTexture(Azaath.media.blank)
    hudBar:SetPoint("BOTTOMLEFT", hudFrame, "BOTTOMLEFT", 4, 4)
    hudBar:SetPoint("BOTTOMRIGHT", hudFrame, "BOTTOMRIGHT", -4, 4)
    hudBar:SetHeight(5)
    hudBar:SetStatusBarColor(0.28, 0.82, 0.45)

    return hudFrame
end

function AC.UpdateAllyCycleHUD()
    local db = AC.DB()
    local cfg = db and db.allyCycle
    local f = EnsureHUD()
    if not (db and db.enabled and cfg and cfg.showHud) then
        f:Hide()
        return
    end
    local unit = allyList[currentIndex]
    if not unit or not UnitExists(unit) then
        f:Hide()
        return
    end

    local name = UnitName(unit)
    if Azaath.IsSecret(name) or type(name) ~= "string" then
        hudName:SetText(unit)
    else
        hudName:SetText(name)
    end

    local _, classFile = UnitClass(unit)
    if not Azaath.IsSecret(classFile) and classFile and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[classFile] then
        local c = _G.RAID_CLASS_COLORS[classFile]
        hudName:SetTextColor(c.r, c.g, c.b)
        hudBar:SetStatusBarColor(c.r, c.g, c.b)
    else
        hudName:SetTextColor(0.93, 0.90, 0.83)
        hudBar:SetStatusBarColor(0.28, 0.82, 0.45)
    end

    local hp = UnitHealth(unit)
    local maxHp = UnitHealthMax(unit)
    if hp and maxHp then
        pcall(hudBar.SetMinMaxValues, hudBar, 0, maxHp)
        pcall(hudBar.SetValue, hudBar, hp)
    end

    local anchor = _G.AzaathUICrosshairFrame or UIParent
    local pad = tonumber(cfg.padding) or 24
    local side = cfg.hudSide or "BOTTOM"
    f:SetScale(tonumber(cfg.scale) or 1.0)
    f:ClearAllPoints()
    if side == "TOP" then
        f:SetPoint("BOTTOM", anchor, "TOP", 0, pad)
    elseif side == "LEFT" then
        f:SetPoint("RIGHT", anchor, "LEFT", -pad, 0)
    elseif side == "RIGHT" then
        f:SetPoint("LEFT", anchor, "RIGHT", pad, 0)
    else
        f:SetPoint("TOP", anchor, "BOTTOM", 0, -pad)
    end
    f:Show()
end

local function CycleAlly(delta)
    local db = AC.DB()
    if not (db and db.enabled) then return end
    local list = RebuildAllyList()
    if #list == 0 then
        currentIndex = 0
        AC.UpdateAllyCycleHUD()
        return
    end
    currentIndex = currentIndex + delta
    if currentIndex > #list then currentIndex = 1 end
    if currentIndex < 1 then currentIndex = #list end

    local unit = list[currentIndex]
    if unit and UnitExists(unit) and TargetUnit then
        pcall(TargetUnit, unit)
    end
    if db.soundAllyCycle and PlaySound and SOUNDKIT then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON, "Master", true)
    end
    AC.UpdateAllyCycleHUD()
end

function _G.AZAATH_AllyCycleUp()
    CycleAlly(1)
end

function _G.AZAATH_AllyCycleDown()
    CycleAlly(-1)
end

function AC.OnGroupRosterChanged()
    RebuildAllyList()
    AC.UpdateAllyCycleHUD()
end
