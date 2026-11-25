--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Nameplates/Media.lua
    Catálogo de texturas de barra (incluindo Azaath e BDO), fontes e estilização
    de textos com cache de FontObjects e suporte opcional a LibSharedMedia-3.0.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local NP = Azaath.NP
local _G = _G
local pairs, ipairs, pcall, tostring, tonumber = pairs, ipairs, pcall, tostring, tonumber

local MEDIA_ROOT = "Interface\\AddOns\\AzaathUI\\Media\\"
local NP_MEDIA   = MEDIA_ROOT .. "Nameplates\\"
local FONTS_DIR  = MEDIA_ROOT .. "Fonts\\"

NP.MEDIA = NP_MEDIA

local BAR_TEXTURES = {
    ["AzNP Solid"]      = "Interface\\Buttons\\WHITE8x8",
    ["AzNP Skills"]     = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar",
    ["AzNP Shield"]     = "Interface\\RaidFrame\\Shield-Fill",
    ["Blizzard"]        = "Interface\\TargetingFrame\\UI-StatusBar",
    ["Blizzard Raid"]   = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill",
    ["Azaath Clássico"]  = MEDIA_ROOT .. "Target\\Fill.tga",
    ["Azaath Tinta"]     = MEDIA_ROOT .. "Target\\InkFill.tga",
    ["Azaath Mancha"]    = MEDIA_ROOT .. "Target\\InkBack.tga",
    ["BDO Barra"]        = MEDIA_ROOT .. "BDO\\HPFill.tga",
    ["BDO Fundo"]        = MEDIA_ROOT .. "BDO\\HPBg.tga",
    ["BDO Pílula"]       = MEDIA_ROOT .. "BDO\\PlateFill.tga",
    ["BDO Trilho"]       = MEDIA_ROOT .. "BDO\\PlateTrack.tga",
    ["AzNP Smooth"]     = NP_MEDIA .. "bar-smooth.png",
    ["AzNP Gloss"]      = NP_MEDIA .. "bar-gloss.png",
    ["AzNP Crisp"]      = NP_MEDIA .. "bar-crisp.png",
    ["AzNP Brushed"]    = NP_MEDIA .. "bar-brushed.png",
    ["AzNP Bevel"]      = NP_MEDIA .. "bar-bevel.png",
    ["AzNP Glass"]      = NP_MEDIA .. "bar-glass.png",
    ["AzNP Runic"]      = NP_MEDIA .. "bar-runic.png",
    ["AzNP Arcane"]     = NP_MEDIA .. "bar-arcane.png",
    ["AzNP Scales"]     = NP_MEDIA .. "bar-scales.png",
    ["AzNP Silk"]       = NP_MEDIA .. "bar-silk.png",
    ["AzNP Stone"]      = NP_MEDIA .. "bar-stone.png",
    ["AzNP Frost"]      = NP_MEDIA .. "bar-frost.png",
    ["AzNP Ridge"]      = NP_MEDIA .. "bar-ridge.png",
    ["AzNP Lines"]      = NP_MEDIA .. "bar-lines.png",
    ["AzNP Gilded"]     = NP_MEDIA .. "bar-gilded.png",
    ["AzNP Aurora"]     = NP_MEDIA .. "bar-aurora.png",
    ["AzNP Embers"]     = NP_MEDIA .. "bar-embers.png",
    ["AzNP Plate"]      = NP_MEDIA .. "bar-plate.png",
}

local OWN_FONTS = {
    ["Noto Sans SemiBold"] = FONTS_DIR .. "NotoSans-SemiBold.ttf",
    ["Noto Sans"]          = FONTS_DIR .. "NotoSans-Medium.ttf",
    ["Cinzel Bold"]        = FONTS_DIR .. "Cinzel-Bold.ttf",
    ["Cinzel"]             = FONTS_DIR .. "Cinzel-Regular.ttf",
    ["PT Sans Bold"]       = FONTS_DIR .. "PTSans-Bold.ttf",
    ["PT Sans"]            = FONTS_DIR .. "PTSans-Regular.ttf",
    ["IM Fell"]            = FONTS_DIR .. "IMFell-Regular.ttf",
    ["IM Fell Italic"]     = FONTS_DIR .. "IMFell-Italic.ttf",
    ["Segoe UI Bold"]      = FONTS_DIR .. "SegoeUI-Semibold.ttf",
    ["Segoe UI"]           = FONTS_DIR .. "SegoeUI-Regular.ttf",
    ["Friz Quadrata"]      = "Fonts\\FRIZQT__.TTF",
    ["Arial Narrow"]       = "Fonts\\ARIALN.TTF",
}

local function GetLSM()
    if _G.LibStub then
        local ok, lsm = pcall(_G.LibStub, "LibSharedMedia-3.0", true)
        if ok and lsm then return lsm end
    end
    return nil
end

local lsmRegistered = false
local function EnsureLSM()
    if lsmRegistered then return end
    local lsm = GetLSM()
    if not lsm then return end
    lsmRegistered = true
    for k, path in pairs(BAR_TEXTURES) do
        pcall(lsm.Register, lsm, "statusbar", k, path)
    end
    for k, path in pairs(OWN_FONTS) do
        pcall(lsm.Register, lsm, "font", k, path)
    end
end

function NP.GetStatusBarTexture(name)
    EnsureLSM()
    if type(name) == "string" and BAR_TEXTURES[name] then
        return BAR_TEXTURES[name]
    end
    local lsm = GetLSM()
    if lsm and type(name) == "string" then
        local path = lsm:Fetch("statusbar", name, true)
        if path then return path end
    end
    return BAR_TEXTURES["AzNP Smooth"]
end

function NP.StatusBarTextureList()
    EnsureLSM()
    local seen, out = {}, {}
    for k in pairs(BAR_TEXTURES) do
        seen[k] = true
        out[#out + 1] = k
    end
    local lsm = GetLSM()
    if lsm and lsm.List then
        for _, k in ipairs(lsm:List("statusbar") or {}) do
            if not seen[k] then
                seen[k] = true
                out[#out + 1] = k
            end
        end
    end
    table.sort(out)
    return out
end

local probeFS
local function ProbeFont(path)
    if not path then return false end
    if not probeFS and _G.UIParent and _G.UIParent.CreateFontString then
        probeFS = _G.UIParent:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    end
    if not probeFS then return true end
    local ok = pcall(probeFS.SetFont, probeFS, path, 12, "")
    if not ok then return false end
    local cur = probeFS:GetFont()
    return cur and (cur:lower() == path:lower() or cur:lower():find(path:lower(), 1, true) ~= nil)
end

function NP.GetFontPath(name)
    EnsureLSM()
    local path
    if type(name) == "string" and OWN_FONTS[name] then
        path = OWN_FONTS[name]
    else
        local lsm = GetLSM()
        if lsm and type(name) == "string" then
            path = lsm:Fetch("font", name, true)
        end
    end
    if path and ProbeFont(path) then return path end
    if Azaath.media and Azaath.media.fontBold and ProbeFont(Azaath.media.fontBold) then
        return Azaath.media.fontBold
    end
    return "Fonts\\ARIALN.TTF"
end

function NP.FontList()
    EnsureLSM()
    local seen, out = {}, {}
    for k in pairs(OWN_FONTS) do
        seen[k] = true
        out[#out + 1] = k
    end
    local lsm = GetLSM()
    if lsm and lsm.List then
        for _, k in ipairs(lsm:List("font") or {}) do
            if not seen[k] then
                seen[k] = true
                out[#out + 1] = k
            end
        end
    end
    table.sort(out)
    return out
end

function NP.FontOverrideKey()
    local st = NP.db and NP.db.style
    if st and st.allFontOn and st.allFont then
        return tostring(st.allFont)
    end
    return ""
end

local fontObjects = {}
local fontCount = 0

function NP.ResetFontCache()
    -- Mantém FontObjects existentes e atualiza se necessário
end

function NP.StyleText(fs, cfg, overrideColor, allowAllFont)
    if not fs or type(cfg) ~= "table" then return end
    local st = NP.db and NP.db.style
    local fontName = cfg.font or (st and st.font) or "Noto Sans SemiBold"
    if allowAllFont ~= false and st and st.allFontOn and st.allFont then
        fontName = st.allFont
    end
    local path = NP.GetFontPath(fontName)
    local size = math.max(5, math.min(48, tonumber(cfg.size) or 11))
    local outline = cfg.outline or "OUTLINE"
    if outline == "NONE" then outline = "" end

    local smooth = st and st.smoothText ~= false
    local flags = outline
    if smooth and not flags:find("MONOCHROME") then
        -- Usa fonte suave (sem MONOCHROME)
    end

    local ok = pcall(fs.SetFont, fs, path, size, flags)
    if not ok then
        pcall(fs.SetFont, fs, "Fonts\\ARIALN.TTF", size, flags)
    end

    local key = tostring(path) .. "|" .. size .. "|" .. flags
    local fo = fontObjects[key]
    if not fo and _G.CreateFont then
        fontCount = fontCount + 1
        fo = _G.CreateFont("AzaathNP_Font" .. fontCount)
        if pcall(fo.SetFont, fo, path, size, flags) then
            fontObjects[key] = fo
        end
    end

    if cfg.shadow ~= false then
        local off = (st and tonumber(st.textShadowOffset)) or 1
        local sa = (st and tonumber(st.textShadowAlpha)) or 1
        fs:SetShadowOffset(off, -off)
        fs:SetShadowColor(0, 0, 0, sa)
    else
        fs:SetShadowOffset(0, 0)
    end

    local col = overrideColor or cfg.color
    if col then
        fs:SetTextColor(NP.RGBA(col))
    end
end

NP.OUTLINES = {
    NONE         = "Sem contorno",
    OUTLINE      = "Contorno fino",
    THICKOUTLINE = "Contorno grosso",
}
NP.OUTLINE_ORDER = { "NONE", "OUTLINE", "THICKOUTLINE" }
