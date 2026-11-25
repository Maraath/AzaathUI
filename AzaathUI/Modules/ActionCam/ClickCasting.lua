--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ActionCam/ClickCasting.lua
    Click Casting no Mouse Look (BUTTON1/2 + modificadores), Reticle Targeting
    macros, integração nativa com AzaathUIBar1..3Button1..12 (e fallback
    Blizzard), Target Lock (Focus) e Modo Suporte.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local _G = _G

local AC = Azaath.ActionCam or {}
Azaath.ActionCam = AC

local ClearOverrideBindings      = _G.ClearOverrideBindings
local CreateFrame                = _G.CreateFrame
local GetBindingKey              = _G.GetBindingKey
local InCombatLockdown           = _G.InCombatLockdown
local SetMouselookOverrideBinding = _G.SetMouselookOverrideBinding
local SetOverrideBindingClick    = _G.SetOverrideBindingClick
local UIParent                   = _G.UIParent

local ipairs, pcall, tonumber, type = ipairs, pcall, tonumber, type

local pendingRefresh = false

local CLICKCAST_KEYS = {
    { slot = "button1",      key = "BUTTON1" },
    { slot = "button2",      key = "BUTTON2" },
    { slot = "shiftbutton1", key = "SHIFT-BUTTON1" },
    { slot = "shiftbutton2", key = "SHIFT-BUTTON2" },
    { slot = "ctrlbutton1",  key = "CTRL-BUTTON1" },
    { slot = "ctrlbutton2",  key = "CTRL-BUTTON2" },
    { slot = "altbutton1",   key = "ALT-BUTTON1" },
    { slot = "altbutton2",   key = "ALT-BUTTON2" },
}

local BAR_MAP = {
    { bind = "ACTIONBUTTON",          azaath = 1, blizz = "ActionButton" },
    { bind = "MULTIACTIONBAR1BUTTON", azaath = 2, blizz = "MultiBarBottomLeftButton" },
    { bind = "MULTIACTIONBAR2BUTTON", azaath = 3, blizz = "MultiBarBottomRightButton" },
    { bind = "MULTIACTIONBAR3BUTTON", azaath = nil, blizz = "MultiBarRightButton" },
    { bind = "MULTIACTIONBAR4BUTTON", azaath = nil, blizz = "MultiBarLeftButton" },
}

local function ResolveActionButtonName(bindingValue)
    if type(bindingValue) ~= "string" then return nil end
    for _, bar in ipairs(BAR_MAP) do
        local idx = bindingValue:match("^" .. bar.bind .. "(%d+)$")
        if idx then
            idx = tonumber(idx)
            if bar.azaath then
                local azName = string.format("AzaathUIBar%dButton%d", bar.azaath, idx)
                if _G[azName] and _G[azName]:IsShown() then
                    return azName
                end
            end
            return bar.blizz .. idx
        end
    end
    return nil
end

local function BuildReticlePreline(supportMode)
    local db = AC.DB()
    if not (db and db.reticleTargeting) then
        return ""
    end
    if supportMode then
        return "/target [@mouseover,help,nodead][@softfriend,help,nodead]\n"
    end
    if db.autoTargetLockOnAttack then
        return "/focus [@mouseover,harm,nodead][@softenemy,harm,nodead]\n/target [@mouseover,harm,nodead][@softenemy,harm,nodead]\n"
    end
    return "/target [@mouseover,harm,nodead][@softenemy,harm,nodead][@focus,harm,nodead]\n"
end

local function BuildClickCastMacro(entry, supportMode)
    local val = entry and entry.value or ""
    if val == "" then return "" end

    if val == "TARGETMOUSEOVER" then
        return "/target [@mouseover,exists][@softenemy,exists][@softfriend,exists]"
    elseif val == "INTERACTMOUSEOVER" then
        return "/interact"
    elseif val == "CLEARTARGET" then
        return "/cleartarget"
    elseif val == "FOLLOW" then
        return "/follow [@mouseover,help,nodead][@target,help,nodead]"
    elseif val == "STARTATTACK" then
        return BuildReticlePreline(supportMode) .. "/startattack"
    elseif val == "PETATTACK" then
        return BuildReticlePreline(supportMode) .. "/petattack"
    elseif val == "MACRO" then
        local mName = entry.macroName or ""
        if mName ~= "" then
            return "/click " .. mName
        end
        return ""
    end

    local btnName = ResolveActionButtonName(val)
    if btnName then
        return BuildReticlePreline(supportMode) .. "/click " .. btnName
    end
    return ""
end

--------------------------------------------------------------------------------
-- Botões seguros
--------------------------------------------------------------------------------
local ClickCastFrames = {}
for i, info in ipairs(CLICKCAST_KEYS) do
    local f = CreateFrame("Button", "AzaathUIClickCast" .. i, UIParent, "SecureActionButtonTemplate")
    f:SetAttribute("type", "macro")
    f:RegisterForClicks("AnyDown")
    ClickCastFrames[info.slot] = f
end

-- Target Lock (Focus)
local FocusOverrideOwner = CreateFrame("Frame", "AzaathUIFocusOverrideOwner", UIParent)
local ToggleFocusBtn = CreateFrame("Button", "AzaathUIToggleFocusBtn", FocusOverrideOwner, "SecureActionButtonTemplate")
ToggleFocusBtn:SetAttribute("type", "macro")
ToggleFocusBtn:RegisterForClicks("AnyDown")

local CycleFocusNextBtn = CreateFrame("Button", "AzaathUICycleFocusNextBtn", FocusOverrideOwner, "SecureActionButtonTemplate")
CycleFocusNextBtn:SetAttribute("type", "macro")
CycleFocusNextBtn:RegisterForClicks("AnyDown")

local CycleFocusPrevBtn = CreateFrame("Button", "AzaathUICycleFocusPrevBtn", FocusOverrideOwner, "SecureActionButtonTemplate")
CycleFocusPrevBtn:SetAttribute("type", "macro")
CycleFocusPrevBtn:RegisterForClicks("AnyDown")

-- Support Mode
local SupportOverrideOwner = CreateFrame("Frame", "AzaathUISupportOverrideOwner", UIParent)
local SupportModeBtn = CreateFrame("Button", "AzaathUISupportModeBtn", SupportOverrideOwner, "SecureActionButtonTemplate")
SupportModeBtn:RegisterForClicks("AnyDown")
SupportModeBtn:SetScript("PostClick", function()
    local db = AC.DB()
    if not db then return end
    db.supportModeActive = not db.supportModeActive
    AC.RefreshClickCastBindings()
    if AC.UpdateVignette then AC.UpdateVignette() end
    if AC.UpdateCrosshairReaction then AC.UpdateCrosshairReaction() end
end)

function AC.RefreshClickCastBindings()
    if InCombatLockdown() then
        pendingRefresh = true
        return
    end
    pendingRefresh = false

    local db = AC.DB()
    if not db or not db.enabled then
        if SetMouselookOverrideBinding then
            for _, info in ipairs(CLICKCAST_KEYS) do
                pcall(SetMouselookOverrideBinding, info.key, nil)
            end
        end
        ClearOverrideBindings(FocusOverrideOwner)
        ClearOverrideBindings(SupportOverrideOwner)
        return
    end

    local bindings = AC.GetBindingsTable()
    local support = db.supportModeActive == true

    for _, info in ipairs(CLICKCAST_KEYS) do
        local entry = bindings[info.slot]
        local f = ClickCastFrames[info.slot]
        if entry and entry.enabled and entry.value and entry.value ~= "" then
            local macro = BuildClickCastMacro(entry, support)
            if macro ~= "" then
                f:SetAttribute("macrotext", macro)
                if SetMouselookOverrideBinding then
                    pcall(SetMouselookOverrideBinding, info.key, "CLICK " .. f:GetName() .. ":LeftButton")
                end
            elseif SetMouselookOverrideBinding then
                pcall(SetMouselookOverrideBinding, info.key, nil)
            end
        elseif SetMouselookOverrideBinding then
            pcall(SetMouselookOverrideBinding, info.key, nil)
        end
    end

    -- Target Lock macros
    local behavior = db.targetLockBehavior or "toggle"
    if behavior == "switch" then
        ToggleFocusBtn:SetAttribute("macrotext", "/focus [@mouseover,exists][@softenemy,exists]; [@focus,exists] none")
    else
        ToggleFocusBtn:SetAttribute("macrotext", "/clearfocus [@focus,exists]\n/stopmacro [@focus,exists]\n/focus [@mouseover,exists][@softenemy,exists][@target,exists]")
    end
    CycleFocusNextBtn:SetAttribute("macrotext", "/targetenemy\n/focus [@target,exists]")
    CycleFocusPrevBtn:SetAttribute("macrotext", "/targetenemy 1\n/focus [@target,exists]")

    ClearOverrideBindings(FocusOverrideOwner)
    if GetBindingKey and SetOverrideBindingClick then
        local function BindFocusKey(bindingName, btn)
            local k1, k2 = GetBindingKey(bindingName)
            if k1 then SetOverrideBindingClick(FocusOverrideOwner, false, k1, btn:GetName(), "LeftButton") end
            if k2 then SetOverrideBindingClick(FocusOverrideOwner, false, k2, btn:GetName(), "LeftButton") end
        end
        BindFocusKey("AZAATH_TOGGLEFOCUS", ToggleFocusBtn)
        BindFocusKey("AZAATH_CYCLEFOCUS_NEXT", CycleFocusNextBtn)
        BindFocusKey("AZAATH_CYCLEFOCUS_PREV", CycleFocusPrevBtn)
    end

    -- Support Mode keybind override
    ClearOverrideBindings(SupportOverrideOwner)
    if GetBindingKey and SetOverrideBindingClick then
        local k1, k2 = GetBindingKey("AZAATH_SUPPORTMODE")
        if k1 then SetOverrideBindingClick(SupportOverrideOwner, false, k1, SupportModeBtn:GetName(), "LeftButton") end
        if k2 then SetOverrideBindingClick(SupportOverrideOwner, false, k2, SupportModeBtn:GetName(), "LeftButton") end
    end
end

function AC.FlushPendingClickCastRefresh()
    if pendingRefresh and not InCombatLockdown() then
        AC.RefreshClickCastBindings()
    end
end

--------------------------------------------------------------------------------
-- Wrappers globais para Bindings.xml
--------------------------------------------------------------------------------
function _G.AZAATH_ToggleFocusTarget()
    if InCombatLockdown() then return end
    if _G.RunMacroText then
        _G.RunMacroText(ToggleFocusBtn:GetAttribute("macrotext") or "")
    end
end

function _G.AZAATH_CycleFocusNext()
    if InCombatLockdown() then return end
    if _G.RunMacroText then
        _G.RunMacroText(CycleFocusNextBtn:GetAttribute("macrotext") or "")
    end
end

function _G.AZAATH_CycleFocusPrevious()
    if InCombatLockdown() then return end
    if _G.RunMacroText then
        _G.RunMacroText(CycleFocusPrevBtn:GetAttribute("macrotext") or "")
    end
end
