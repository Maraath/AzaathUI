--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Config.lua
    Módulo "Config": API (/azaath, /azaath edit) e o Modo de Edição Visual
    (arrastar, redimensionar pelo canto, roda = escala, Inspetor de Precisão).

    O painel de opções em si fica em Modules/Config/:
      Locale.lua  textos PT/EN       Options.lua  aplicação, migração e abas
      Widgets.lua estilo e controles Window.lua   janela, navegação e busca
    Símbolos comuns em Azaath.ConfigUI (U).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local M = Azaath:NewModule("Config")
local U = Azaath.ConfigUI

local _G = _G
local type, ipairs, pairs, format = type, ipairs, pairs, string.format
local floor, max, min = math.floor, math.max, math.min

-- estilo (Widgets.lua)
local CreateText, Panel, ShowTooltip = U.CreateText, U.Panel, U.ShowTooltip
local CreateStyledButton, GetBackdrop = U.CreateStyledButton, U.GetBackdrop
local Tr = U.Tr

-- aplicação ao vivo (Options.lua)
local A = U.Apply
local ApplyCompass, ApplyExperience, ApplyUnitFrames = A.Compass, A.Experience, A.UnitFrames
local ApplyActionBars, ApplyStancePet, ApplyMicroMenu = A.ActionBars, A.StancePet, A.MicroMenu
local ApplyCastBar, ApplyAuras, ApplyParty = A.CastBar, A.Auras, A.Party
local ApplyQuestTracker, ApplyMinimap, ApplyDialog = A.QuestTracker, A.Minimap, A.Dialog
local ApplyLoot, ApplyLootFeed, ApplyAzaathHUD, ApplyBDOHUD = A.Loot, A.LootFeed, A.AzaathHUD, A.BDOHUD


--------------------------------------------------------------------------------
-- MODO DE EDIÇÃO VISUAL (Mover, Redimensionar ◢, Roda = Escala, Inspetor)
--------------------------------------------------------------------------------
local editorFrame, gridFrame, inspectorFrame
local handles = {}
local selectedElem = nil

local function CopyTable(src, dst)
    if type(src) ~= "table" or type(dst) ~= "table" then return end
    for k, v in pairs(src) do
        if type(v) == "table" then
            if type(dst[k]) ~= "table" then dst[k] = {} end
            CopyTable(v, dst[k])
        else
            dst[k] = v
        end
    end
end

local function ResetPath(path)
    local src, dst = Azaath.defaults, Azaath.db
    local lastKey = nil
    for key in path:gmatch("[^%.]+") do
        if lastKey then
            src = src and src[lastKey]
            dst = dst and dst[lastKey]
        end
        lastKey = key
    end
    if src and dst and lastKey and src[lastKey] ~= nil then
        if type(src[lastKey]) == "table" then
            if type(dst[lastKey]) == "table" then
                wipe(dst[lastKey])
            else
                dst[lastKey] = {}
            end
            CopyTable(src[lastKey], dst[lastKey])
        else
            dst[lastKey] = src[lastKey]
        end
    end
end

local EDITOR_ELEMENTS = {
    {
        key = "azaathHUD",
        frameName = "AzaathUIAzaath",
        label = "HUD Azaath Reforged (Barras + Vida)",
        scaleOnResize = true,
        point = "BOTTOM",
        getPos = function()
            local az = Azaath.db.azaath or {}
            return az.offsetX or 0, az.offsetY or 10
        end,
        setPos = function(x, y)
            Azaath.db.azaath = Azaath.db.azaath or {}
            Azaath.db.azaath.offsetX = x
            Azaath.db.azaath.offsetY = y
        end,
        getSize = function()
            local A = Azaath.AZAATH
            local bw = (A and A.hud and A.hud.w) or 1020
            local bh = (A and A.hud and A.hud.h) or 178
            local sc = (Azaath.db.azaath and Azaath.db.azaath.scale) or 1
            return bw * sc, bh * sc
        end,
        setSize = function(w, h)
            local A = Azaath.AZAATH
            local bw = (A and A.hud and A.hud.w) or 1020
            local bh = (A and A.hud and A.hud.h) or 178
            local sc = max(0.5, min(1.5, floor(max(w / bw, h / bh) * 20 + 0.5) / 20))
            Azaath.db.azaath = Azaath.db.azaath or {}
            Azaath.db.azaath.scale = sc
        end,
        isEnabled = function() return Azaath.IsAzaath and Azaath.IsAzaath() end,
        minScale = 0.5,
        maxScale = 1.5,
        getScale = function() return (Azaath.db.azaath and Azaath.db.azaath.scale) or 1 end,
        setScale = function(s)
            Azaath.db.azaath = Azaath.db.azaath or {}
            Azaath.db.azaath.scale = max(0.5, min(1.5, s))
        end,
        apply = ApplyAzaathHUD,
        reset = function()
            if Azaath.db.azaath then
                local d = Azaath.defaults.azaath or {}
                Azaath.db.azaath.scale = d.scale or 1
                Azaath.db.azaath.offsetX = d.offsetX or 0
                Azaath.db.azaath.offsetY = d.offsetY or 10
            end
            ApplyAzaathHUD()
        end,
    },
    {
        key = "bdoHUD",
        frameName = "AzaathUIBDO",
        label = "HUD Black Desert (Jogador)",
        scaleOnResize = true,
        point = "TOPLEFT",
        getPos = function()
            local b = Azaath.db.bdo or {}
            return (b.offsetX ~= nil) and b.offsetX or 8, -((b.offsetY ~= nil) and b.offsetY or 6)
        end,
        setPos = function(x, y)
            Azaath.db.bdo = Azaath.db.bdo or {}
            Azaath.db.bdo.offsetX = x
            Azaath.db.bdo.offsetY = -y
        end,
        getSize = function()
            local B = Azaath.BDO
            local bw = (B and B.hud and B.hud.w) or 470
            local bh = (B and B.hud and B.hud.h) or 137
            local sc = (Azaath.db.bdo and Azaath.db.bdo.scale) or 1
            return bw * sc, bh * sc
        end,
        setSize = function(w, h)
            local B = Azaath.BDO
            local bw = (B and B.hud and B.hud.w) or 470
            local bh = (B and B.hud and B.hud.h) or 137
            local sc = max(0.5, min(2.0, floor(max(w / bw, h / bh) * 20 + 0.5) / 20))
            Azaath.db.bdo = Azaath.db.bdo or {}
            Azaath.db.bdo.scale = sc
        end,
        isEnabled = function() return Azaath.IsBDO and Azaath.IsBDO() end,
        minScale = 0.5,
        maxScale = 2.0,
        getScale = function() return (Azaath.db.bdo and Azaath.db.bdo.scale) or 1 end,
        setScale = function(s)
            Azaath.db.bdo = Azaath.db.bdo or {}
            Azaath.db.bdo.scale = max(0.5, min(2.0, s))
        end,
        apply = ApplyBDOHUD,
        reset = function()
            if Azaath.db.bdo then
                local d = Azaath.defaults.bdo or {}
                Azaath.db.bdo.scale = d.scale or 1
                Azaath.db.bdo.offsetX = d.offsetX or 8
                Azaath.db.bdo.offsetY = d.offsetY or 6
            end
            ApplyBDOHUD()
        end,
    },
    {
        key = "experienceBar",
        frameName = "AzaathUIExperienceBar",
        label = "Barra de Experiência (XP)",
        isEnabled = function()
            return Azaath.db.experience and Azaath.db.experience.enabled
                and not (Azaath.IsAzaath and Azaath.IsAzaath())
                and not (Azaath.IsBDO and Azaath.IsBDO())
        end,
        point = "BOTTOM",
        getPos = function() return Azaath.db.experience.offsetX or 0, Azaath.db.experience.offsetY or 6 end,
        setPos = function(x, y)
            Azaath.db.experience.offsetX = x
            Azaath.db.experience.offsetY = max(0, y)
        end,
        getSize = function()
            local db = Azaath.db.experience
            local w = db.width or 0
            if w <= 0 then
                local sc = (db.scale and db.scale > 0) and db.scale or 1
                local rootW = (Azaath.root:GetWidth() or UIParent:GetWidth() or 1280) / sc
                local leftPad = 8 + ((db.showBadge ~= false) and floor((db.badgeSize or 34) * (db.badgeScale or 1) * 0.62 + 0.5) or 0)
                w = floor(max(120, rootW - leftPad - 6))
            end
            return w, db.height or 5
        end,
        setSize = function(w, h)
            Azaath.db.experience.width = max(80, floor(w + 0.5))
            Azaath.db.experience.height = max(3, min(40, floor(h + 0.5)))
        end,
        wSpec = { label = "Largura (0 = Auto)", min = 0, max = 1920, step = 10,
                  get = function() return Azaath.db.experience.width or 0 end,
                  set = function(v) Azaath.db.experience.width = v end },
        hSpec = { label = "Altura da Barra", min = 3, max = 32, step = 1,
                  get = function() return Azaath.db.experience.height or 5 end,
                  set = function(v) Azaath.db.experience.height = v end },
        extraSpec = { label = "Divisões (Segmentos)", min = 1, max = 40, step = 1,
                      get = function() return Azaath.db.experience.segments or 10 end,
                      set = function(v) Azaath.db.experience.segments = v end },
        getScale = function() return Azaath.db.experience.scale or 1 end,
        setScale = function(s) Azaath.db.experience.scale = s end,
        apply = ApplyExperience,
        reset = function()
            local d, db = Azaath.defaults.experience, Azaath.db.experience
            db.width, db.height, db.segments = d.width, d.height, d.segments
            db.scale, db.offsetX, db.offsetY, db.showAtMax = d.scale, d.offsetX, d.offsetY, d.showAtMax
            db.badgeSize, db.badgeScale = d.badgeSize, d.badgeScale
            ApplyExperience()
        end,
    },
    {
        key = "compass",
        frameName = "AzaathUICompass",
        label = "Bússola",
        isEnabled = function() return Azaath.db.compass and Azaath.db.compass.enabled end,
        point = "TOP",
        getPos = function() return Azaath.db.compass.offsetX or 0, Azaath.db.compass.offsetY or -14 end,
        setPos = function(x, y)
            Azaath.db.compass.offsetX = x
            Azaath.db.compass.offsetY = y
        end,
        getSize = function() return Azaath.db.compass.width or 560, Azaath.db.compass.height or 28 end,
        setSize = function(w, h)
            Azaath.db.compass.width = max(200, min(1200, floor(w + 0.5)))
            Azaath.db.compass.height = max(18, min(64, floor(h + 0.5)))
        end,
        wSpec = { label = "Largura", min = 200, max = 1200, step = 10,
                  get = function() return Azaath.db.compass.width or 560 end,
                  set = function(v) Azaath.db.compass.width = v end },
        hSpec = { label = "Altura", min = 18, max = 64, step = 1,
                  get = function() return Azaath.db.compass.height or 28 end,
                  set = function(v) Azaath.db.compass.height = v end },
        extraSpec = { label = "Campo de Visão (°)", min = 90, max = 360, step = 15,
                      get = function() return Azaath.db.compass.fov or 180 end,
                      set = function(v) Azaath.db.compass.fov = v end },
        getScale = function() return Azaath.db.compass.scale or 1 end,
        setScale = function(s) Azaath.db.compass.scale = s end,
        apply = ApplyCompass,
        reset = function() ResetPath("compass"); ApplyCompass() end,
    },
    {
        key = "playerFrame",
        frameName = "AzaathUIPlayer",
        label = "Vida e Mana (Jogador)",
        isEnabled = function()
            local p = Azaath.db.unitframes and Azaath.db.unitframes.player
            return p and p.enabled
                and not (Azaath.IsAzaath and Azaath.IsAzaath())
                and not (Azaath.IsBDO and Azaath.IsBDO())
        end,
        point = "BOTTOM",
        getPos = function() return Azaath.db.unitframes.player.offsetX or 0, Azaath.db.unitframes.player.offsetY or 60 end,
        setPos = function(x, y)
            Azaath.db.unitframes.player.offsetX = x
            Azaath.db.unitframes.player.offsetY = y
        end,
        getSize = function()
            local p = Azaath.db.unitframes.player
            return p.width or 270, (p.healthHeight or 22) + (p.powerHeight or 9) + 3
        end,
        setSize = function(w, h)
            local p = Azaath.db.unitframes.player
            p.width = max(150, min(650, floor(w + 0.5)))
            p.healthHeight = max(8, min(45, floor(h - (p.powerHeight or 9) - 3 + 0.5)))
        end,
        wSpec = { label = "Largura", min = 150, max = 650, step = 5,
                  get = function() return Azaath.db.unitframes.player.width or 270 end,
                  set = function(v) Azaath.db.unitframes.player.width = v end },
        hSpec = { label = "Altura da Vida", min = 8, max = 45, step = 1,
                  get = function() return Azaath.db.unitframes.player.healthHeight or 22 end,
                  set = function(v) Azaath.db.unitframes.player.healthHeight = v end },
        extraSpec = { label = "Altura do Recurso (Mana)", min = 2, max = 20, step = 1,
                      get = function() return Azaath.db.unitframes.player.powerHeight or 9 end,
                      set = function(v) Azaath.db.unitframes.player.powerHeight = v end },
        getScale = function() return Azaath.db.unitframes.player.scale or 1 end,
        setScale = function(s) Azaath.db.unitframes.player.scale = s end,
        apply = ApplyUnitFrames,
        reset = function() ResetPath("unitframes.player"); ApplyUnitFrames() end,
    },
    {
        key = "targetFrame",
        frameName = "AzaathUITarget",
        getFrame = function()
            return (Azaath.IsBDO and Azaath.IsBDO() and _G.AzaathUIBDOTarget) or _G.AzaathUITarget
        end,
        label = "Quadro do Alvo",
        isEnabled = function()
            local t = Azaath.db.unitframes and Azaath.db.unitframes.target
            return (t and t.enabled) or (Azaath.IsBDO and Azaath.IsBDO())
        end,
        scaleOnResize = function() return Azaath.IsBDO and Azaath.IsBDO() end,
        point = "TOP",
        getPos = function() return Azaath.db.unitframes.target.offsetX or 0, Azaath.db.unitframes.target.offsetY or -78 end,
        setPos = function(x, y)
            Azaath.db.unitframes.target.offsetX = x
            Azaath.db.unitframes.target.offsetY = y
        end,
        getSize = function()
            local t = Azaath.db.unitframes.target
            local bz = Azaath.IsBDO and Azaath.IsBDO() and Azaath.BDOTargetBox
            if bz then
                local sc = (t.scale and t.scale > 0) and t.scale or 1
                return bz.w * sc, bz.h * sc
            end
            return t.width or 300, (t.healthHeight or 14) + 26
        end,
        setSize = function(w, h)
            local t = Azaath.db.unitframes.target
            local bz = Azaath.IsBDO and Azaath.IsBDO() and Azaath.BDOTargetBox
            if bz then
                t.scale = max(0.5, min(2.5, floor(max(w / bz.w, h / bz.h) * 20 + 0.5) / 20))
                return
            end
            t.width = max(150, min(650, floor(w + 0.5)))
            t.healthHeight = max(6, min(40, floor(h - 26 + 0.5)))
        end,
        wSpec = { label = "Largura", min = 150, max = 650, step = 5,
                  isEnabled = function() return not (Azaath.IsBDO and Azaath.IsBDO()) end,
                  get = function() return Azaath.db.unitframes.target.width or 300 end,
                  set = function(v) Azaath.db.unitframes.target.width = v end },
        hSpec = { label = "Altura da Vida", min = 6, max = 40, step = 1,
                  isEnabled = function() return not (Azaath.IsBDO and Azaath.IsBDO()) end,
                  get = function() return Azaath.db.unitframes.target.healthHeight or 14 end,
                  set = function(v) Azaath.db.unitframes.target.healthHeight = v end },
        extraSpec = { label = "Tamanho da Fonte do Nome", min = 10, max = 28, step = 1,
                      isEnabled = function() return not (Azaath.IsBDO and Azaath.IsBDO()) end,
                      get = function() return Azaath.db.unitframes.target.nameFont or 14 end,
                      set = function(v) Azaath.db.unitframes.target.nameFont = v end },
        getScale = function() return Azaath.db.unitframes.target.scale or 1 end,
        setScale = function(s) Azaath.db.unitframes.target.scale = s end,
        apply = function()
            ApplyUnitFrames()
            if Azaath.ApplyBDOTarget then Azaath.ApplyBDOTarget() end
        end,
        reset = function()
            ResetPath("unitframes.target")
            ApplyUnitFrames()
            if Azaath.ApplyBDOTarget then Azaath.ApplyBDOTarget() end
        end,
    },
    {
        key = "playerCastBar",
        frameName = "AzaathUICastBarPlayer",
        label = "Conjuração (Jogador)",
        isEnabled = function() return Azaath.db.castbar and Azaath.db.castbar.player and Azaath.db.castbar.player.enabled end,
        point = "BOTTOM",
        getPos = function()
            local c = Azaath.db.castbar.player
            return c.offsetX or 0, c.offsetY or 18
        end,
        setPos = function(x, y)
            local c = Azaath.db.castbar.player
            c.customPos = false
            c.offsetX = x
            c.offsetY = y
        end,
        -- Estilo espiral: o tamanho é o diâmetro do anel (+16 px de texto embaixo)
        getSize = function()
            local c = Azaath.db.castbar.player
            if c.style ~= "bar" then
                local s = c.ringSize or 56
                return s, s + 16
            end
            return c.width or 300, c.height or 14
        end,
        setSize = function(w, h)
            local c = Azaath.db.castbar.player
            if c.style ~= "bar" then
                c.ringSize = max(32, min(200, floor(min(w, h - 16) + 0.5)))
                return
            end
            c.width = max(120, min(600, floor(w + 0.5)))
            c.height = max(6, min(36, floor(h + 0.5)))
        end,
        wSpec = { label = "Largura (barra) / Diâmetro (espiral)", min = 32, max = 600, step = 2,
                  get = function()
                      local c = Azaath.db.castbar.player
                      if c.style ~= "bar" then return c.ringSize or 56 end
                      return c.width or 300
                  end,
                  set = function(v)
                      local c = Azaath.db.castbar.player
                      if c.style ~= "bar" then c.ringSize = max(32, min(200, v)) else c.width = max(120, v) end
                  end },
        hSpec = { label = "Altura (barra)", min = 6, max = 36, step = 1,
                  get = function() return Azaath.db.castbar.player.height or 14 end,
                  set = function(v) Azaath.db.castbar.player.height = v end },
        getScale = function() return Azaath.db.castbar.player.scale or 1 end,
        setScale = function(s) Azaath.db.castbar.player.scale = s end,
        apply = ApplyCastBar,
        reset = function() ResetPath("castbar.player"); ApplyCastBar() end,
    },
    {
        key = "targetCastBar",
        frameName = "AzaathUICastBarTarget",
        label = "Conjuração (Alvo)",
        isEnabled = function() return Azaath.db.castbar and Azaath.db.castbar.target and Azaath.db.castbar.target.enabled end,
        point = "TOP",
        getPos = function()
            local c = Azaath.db.castbar.target
            return c.offsetX or 0, c.offsetY or -8
        end,
        setPos = function(x, y)
            local c = Azaath.db.castbar.target
            c.customPos = false
            c.offsetX = x
            c.offsetY = y
        end,
        getSize = function() return (Azaath.db.castbar.target.width and Azaath.db.castbar.target.width > 0) and Azaath.db.castbar.target.width or 300, Azaath.db.castbar.target.height or 12 end,
        setSize = function(w, h)
            Azaath.db.castbar.target.width = max(120, min(600, floor(w + 0.5)))
            Azaath.db.castbar.target.height = max(6, min(32, floor(h + 0.5)))
        end,
        wSpec = { label = "Largura", min = 120, max = 600, step = 5,
                  get = function() return (Azaath.db.castbar.target.width and Azaath.db.castbar.target.width > 0) and Azaath.db.castbar.target.width or 300 end,
                  set = function(v) Azaath.db.castbar.target.width = v end },
        hSpec = { label = "Altura", min = 6, max = 32, step = 1,
                  get = function() return Azaath.db.castbar.target.height or 12 end,
                  set = function(v) Azaath.db.castbar.target.height = v end },
        getScale = function() return Azaath.db.castbar.target.scale or 1 end,
        setScale = function(s) Azaath.db.castbar.target.scale = s end,
        apply = ApplyCastBar,
        reset = function() ResetPath("castbar.target"); ApplyCastBar() end,
    },
    {
        key = "actionBar1",
        frameName = "AzaathUIBar1",
        label = "Barra de Ação 1",
        point = "BOTTOM",
        getPos = function()
            local b1 = Azaath.db.actionbars.bar1 or {}
            return b1.offsetX or 0, b1.offsetY or 0
        end,
        setPos = function(x, y)
            local b1 = Azaath.db.actionbars.bar1
            b1.customPos = false
            b1.offsetX = x
            b1.offsetY = y
        end,
        getSize = function()
            local ab = Azaath.db.actionbars
            local b1 = ab.bar1 or {}
            local sz = (b1.buttonSize and b1.buttonSize > 0) and b1.buttonSize or (ab.buttonSize or 42)
            local sp = ab.spacing or 6
            local cols = (b1.cols and b1.cols > 0) and b1.cols or ((Azaath.IsSixCols(ab.layout)) and 6 or 12)
            local rows = math.ceil(12 / cols)
            local keyH = (Azaath.IsSixCols(ab.layout)) and 21 or 0
            return cols * sz + (cols - 1) * sp, rows * (sz + sp + keyH) - sp
        end,
        setSize = function(w)
            local ab = Azaath.db.actionbars
            local b1 = ab.bar1
            local cols = (b1.cols and b1.cols > 0) and b1.cols or ((Azaath.IsSixCols(ab.layout)) and 6 or 12)
            local sp = ab.spacing or 6
            local sz = max(20, min(64, floor((w - (cols - 1) * sp) / cols + 0.5)))
            b1.buttonSize = sz
        end,
        isEnabled = function()
            local ab = Azaath.db.actionbars
            return ab and ab.enabled and Azaath.db.hideBlizzard.actionBars and (ab.bars or 3) >= 1 and not (Azaath.IsAzaath and Azaath.IsAzaath())
        end,
        wSpec = { label = "Tamanho dos Botões", min = 20, max = 64, step = 1,
                  get = function()
                      local ab = Azaath.db.actionbars
                      return (ab.bar1.buttonSize and ab.bar1.buttonSize > 0) and ab.bar1.buttonSize or (ab.buttonSize or 42)
                  end,
                  set = function(v) Azaath.db.actionbars.bar1.buttonSize = v end },
        extraSpec = { label = "Colunas (Botões por linha)", min = 1, max = 12, step = 1,
                      get = function()
                          local ab = Azaath.db.actionbars
                          return (ab.bar1.cols and ab.bar1.cols > 0) and ab.bar1.cols or ((Azaath.IsSixCols(ab.layout)) and 6 or 12)
                      end,
                      set = function(v) Azaath.db.actionbars.bar1.cols = v end },
        getScale = function() return Azaath.db.actionbars.bar1.scale or 1 end,
        setScale = function(s) Azaath.db.actionbars.bar1.scale = s end,
        apply = ApplyActionBars,
        reset = function() ResetPath("actionbars.bar1"); ApplyActionBars() end,
    },
    {
        key = "actionBar2",
        frameName = "AzaathUIBar2",
        label = "Barra de Ação 2",
        point = "BOTTOM",
        getPos = function()
            local b2 = Azaath.db.actionbars.bar2 or {}
            return b2.offsetX or 0, b2.offsetY or 0
        end,
        setPos = function(x, y)
            local b2 = Azaath.db.actionbars.bar2
            b2.customPos = false
            b2.offsetX = x
            b2.offsetY = y
        end,
        getSize = function()
            local ab = Azaath.db.actionbars
            local b2 = ab.bar2 or {}
            local defSz = (Azaath.IsSixCols(ab.layout)) and (ab.smallSize or 32) or (ab.buttonSize or 42)
            local sz = (b2.buttonSize and b2.buttonSize > 0) and b2.buttonSize or defSz
            local sp = ab.spacing or 6
            local defCols = (Azaath.IsSixCols(ab.layout)) and 6 or 12
            local cols = (b2.cols and b2.cols > 0) and b2.cols or defCols
            local rows = math.ceil(12 / cols)
            local keyH = (Azaath.IsSixCols(ab.layout)) and 21 or 0
            return cols * sz + (cols - 1) * sp, rows * (sz + sp + keyH) - sp
        end,
        setSize = function(w)
            local ab = Azaath.db.actionbars
            local b2 = ab.bar2
            local defCols = (Azaath.IsSixCols(ab.layout)) and 6 or 12
            local cols = (b2.cols and b2.cols > 0) and b2.cols or defCols
            local sp = ab.spacing or 6
            b2.buttonSize = max(18, min(60, floor((w - (cols - 1) * sp) / cols + 0.5)))
        end,
        isEnabled = function()
            local ab = Azaath.db.actionbars
            return ab and ab.enabled and Azaath.db.hideBlizzard.actionBars and (ab.bars or 3) >= 2 and not (Azaath.IsAzaath and Azaath.IsAzaath())
        end,
        wSpec = { label = "Tamanho dos Botões", min = 18, max = 60, step = 1,
                  get = function()
                      local ab = Azaath.db.actionbars
                      local defSz = (Azaath.IsSixCols(ab.layout)) and (ab.smallSize or 32) or (ab.buttonSize or 42)
                      return (ab.bar2.buttonSize and ab.bar2.buttonSize > 0) and ab.bar2.buttonSize or defSz
                  end,
                  set = function(v) Azaath.db.actionbars.bar2.buttonSize = v end },
        extraSpec = { label = "Colunas (Botões por linha)", min = 1, max = 12, step = 1,
                      get = function()
                          local ab = Azaath.db.actionbars
                          return (ab.bar2.cols and ab.bar2.cols > 0) and ab.bar2.cols or ((Azaath.IsSixCols(ab.layout)) and 6 or 12)
                      end,
                      set = function(v) Azaath.db.actionbars.bar2.cols = v end },
        getScale = function() return Azaath.db.actionbars.bar2.scale or 1 end,
        setScale = function(s) Azaath.db.actionbars.bar2.scale = s end,
        apply = ApplyActionBars,
        reset = function() ResetPath("actionbars.bar2"); ApplyActionBars() end,
    },
    {
        key = "actionBar3",
        frameName = "AzaathUIBar3",
        label = "Barra de Ação 3",
        point = "BOTTOM",
        getPos = function()
            local b3 = Azaath.db.actionbars.bar3 or {}
            return b3.offsetX or 0, b3.offsetY or 0
        end,
        setPos = function(x, y)
            local b3 = Azaath.db.actionbars.bar3
            b3.customPos = false
            b3.offsetX = x
            b3.offsetY = y
        end,
        getSize = function()
            local ab = Azaath.db.actionbars
            local b3 = ab.bar3 or {}
            local defSz = (Azaath.IsSixCols(ab.layout)) and (ab.smallSize or 32) or (ab.buttonSize or 42)
            local sz = (b3.buttonSize and b3.buttonSize > 0) and b3.buttonSize or defSz
            local sp = ab.spacing or 6
            local defCols = (Azaath.IsSixCols(ab.layout)) and 6 or 12
            local cols = (b3.cols and b3.cols > 0) and b3.cols or defCols
            local rows = math.ceil(12 / cols)
            local keyH = (Azaath.IsSixCols(ab.layout)) and 21 or 0
            return cols * sz + (cols - 1) * sp, rows * (sz + sp + keyH) - sp
        end,
        setSize = function(w)
            local ab = Azaath.db.actionbars
            local b3 = ab.bar3
            local defCols = (Azaath.IsSixCols(ab.layout)) and 6 or 12
            local cols = (b3.cols and b3.cols > 0) and b3.cols or defCols
            local sp = ab.spacing or 6
            b3.buttonSize = max(18, min(60, floor((w - (cols - 1) * sp) / cols + 0.5)))
        end,
        isEnabled = function()
            local ab = Azaath.db.actionbars
            return ab and ab.enabled and Azaath.db.hideBlizzard.actionBars and (ab.bars or 3) >= 3 and not (Azaath.IsAzaath and Azaath.IsAzaath())
        end,
        wSpec = { label = "Tamanho dos Botões", min = 18, max = 60, step = 1,
                  get = function()
                      local ab = Azaath.db.actionbars
                      local defSz = (Azaath.IsSixCols(ab.layout)) and (ab.smallSize or 32) or (ab.buttonSize or 42)
                      return (ab.bar3.buttonSize and ab.bar3.buttonSize > 0) and ab.bar3.buttonSize or defSz
                  end,
                  set = function(v) Azaath.db.actionbars.bar3.buttonSize = v end },
        extraSpec = { label = "Colunas (Botões por linha)", min = 1, max = 12, step = 1,
                      get = function()
                          local ab = Azaath.db.actionbars
                          return (ab.bar3.cols and ab.bar3.cols > 0) and ab.bar3.cols or ((Azaath.IsSixCols(ab.layout)) and 6 or 12)
                      end,
                      set = function(v) Azaath.db.actionbars.bar3.cols = v end },
        getScale = function() return Azaath.db.actionbars.bar3.scale or 1 end,
        setScale = function(s) Azaath.db.actionbars.bar3.scale = s end,
        apply = ApplyActionBars,
        reset = function() ResetPath("actionbars.bar3"); ApplyActionBars() end,
    },
    {
        key = "bagButton",
        frameName = "AzaathUIBagButton",
        label = "Mochila",
        point = "BOTTOMRIGHT",
        getPos = function()
            local bag = Azaath.db.actionbars.bag
            return bag.offsetX or -24, bag.offsetY or 30
        end,
        setPos = function(x, y)
            local bag = Azaath.db.actionbars.bag
            bag.offsetX = x
            bag.offsetY = y
        end,
        getSize = function()
            local s = Azaath.db.actionbars.bag.size or 42
            return s, s
        end,
        setSize = function(w, h)
            Azaath.db.actionbars.bag.size = max(24, min(72, floor(max(w, h) + 0.5)))
        end,
        isEnabled = function()
            local ab = Azaath.db.actionbars
            return ab and ab.enabled and Azaath.db.hideBlizzard.actionBars and ab.bagButton and not (Azaath.IsAzaath and Azaath.IsAzaath())
        end,
        wSpec = { label = "Tamanho do Botão", min = 24, max = 72, step = 1,
                  get = function() return Azaath.db.actionbars.bag.size or 42 end,
                  set = function(v) Azaath.db.actionbars.bag.size = v end },
        getScale = function() return Azaath.db.actionbars.bag.scale or 1 end,
        setScale = function(s) Azaath.db.actionbars.bag.scale = s end,
        apply = ApplyActionBars,
        reset = function() ResetPath("actionbars.bag"); ApplyActionBars() end,
    },
    {
        key = "stanceBar",
        frameName = "AzaathUIStanceBar",
        label = "Barra de Postura",
        point = "BOTTOM",
        getPos = function()
            local st = Azaath.db.actionbars.stance
            return st.offsetX or 0, st.offsetY or 0
        end,
        setPos = function(x, y)
            local st = Azaath.db.actionbars.stance
            st.customPos = false
            st.offsetX = x
            st.offsetY = y
        end,
        getSize = function()
            local st = Azaath.db.actionbars.stance
            local sz = st.buttonSize or 28
            local sp = st.spacing or 3
            local n = (GetNumShapeshiftForms and GetNumShapeshiftForms()) or 0
            if n <= 0 then n = 4 end
            return n * sz + (n - 1) * sp, sz
        end,
        setSize = function(w)
            local st = Azaath.db.actionbars.stance
            local sp = st.spacing or 3
            local n = (GetNumShapeshiftForms and GetNumShapeshiftForms()) or 0
            if n <= 0 then n = 4 end
            st.buttonSize = max(18, min(52, floor((w - (n - 1) * sp) / n + 0.5)))
        end,
        isEnabled = function()
            local ab = Azaath.db.actionbars
            return ab and ab.stance and ab.stance.enabled and Azaath.db.hideBlizzard.actionBars and not (Azaath.IsAzaath and Azaath.IsAzaath())
        end,
        wSpec = { label = "Tamanho dos Botões", min = 18, max = 52, step = 1,
                  get = function() return Azaath.db.actionbars.stance.buttonSize or 28 end,
                  set = function(v) Azaath.db.actionbars.stance.buttonSize = v end },
        getScale = function() return Azaath.db.actionbars.stance.scale or 1 end,
        setScale = function(s) Azaath.db.actionbars.stance.scale = s end,
        apply = ApplyStancePet,
        reset = function() ResetPath("actionbars.stance"); ApplyStancePet() end,
    },
    {
        key = "petBar",
        frameName = "AzaathUIPetBar",
        label = "Barra de Pet",
        point = "BOTTOM",
        getPos = function()
            local pt = Azaath.db.actionbars.pet
            return pt.offsetX or 0, pt.offsetY or 0
        end,
        setPos = function(x, y)
            local pt = Azaath.db.actionbars.pet
            pt.customPos = false
            pt.offsetX = x
            pt.offsetY = y
        end,
        getSize = function()
            local pt = Azaath.db.actionbars.pet
            local sz = pt.buttonSize or 28
            local sp = pt.spacing or 3
            return 10 * sz + 9 * sp, sz
        end,
        setSize = function(w)
            local pt = Azaath.db.actionbars.pet
            local sp = pt.spacing or 3
            pt.buttonSize = max(18, min(52, floor((w - 9 * sp) / 10 + 0.5)))
        end,
        isEnabled = function()
            local ab = Azaath.db.actionbars
            return ab and ab.pet and ab.pet.enabled and Azaath.db.hideBlizzard.actionBars and not (Azaath.IsAzaath and Azaath.IsAzaath())
        end,
        wSpec = { label = "Tamanho dos Botões", min = 18, max = 52, step = 1,
                  get = function() return Azaath.db.actionbars.pet.buttonSize or 28 end,
                  set = function(v) Azaath.db.actionbars.pet.buttonSize = v end },
        getScale = function() return Azaath.db.actionbars.pet.scale or 1 end,
        setScale = function(s) Azaath.db.actionbars.pet.scale = s end,
        apply = ApplyStancePet,
        reset = function() ResetPath("actionbars.pet"); ApplyStancePet() end,
    },
    {
        key = "minimap",
        frameName = "AzaathUIMinimap",
        label = "Minimapa",
        isEnabled = function() return Azaath.db.minimap and Azaath.db.minimap.enabled and Azaath.db.hideBlizzard and Azaath.db.hideBlizzard.minimap end,
        point = "TOPRIGHT",
        getPos = function() return Azaath.db.minimap.offsetX or -18, Azaath.db.minimap.offsetY or -44 end,
        setPos = function(x, y)
            Azaath.db.minimap.offsetX = x
            Azaath.db.minimap.offsetY = y
        end,
        getSize = function()
            local s = Azaath.db.minimap.size or 160
            return s, s
        end,
        setSize = function(w, h)
            Azaath.db.minimap.size = max(100, min(320, floor(max(w, h) + 0.5)))
        end,
        wSpec = { label = "Tamanho", min = 100, max = 320, step = 2,
                  get = function() return Azaath.db.minimap.size or 160 end,
                  set = function(v) Azaath.db.minimap.size = v end },
        getScale = function() return Azaath.db.minimap.scale or 1 end,
        setScale = function(s) Azaath.db.minimap.scale = s end,
        apply = ApplyMinimap,
        reset = function() ResetPath("minimap"); ApplyMinimap() end,
    },
    {
        key = "playerBuffs",
        frameName = "AzaathUIPlayerBuffs",
        label = "Buffs do Jogador",
        isEnabled = function()
            local au = Azaath.db.auras
            return au and au.playerBuffs and au.playerBuffs.enabled and Azaath.db.hideBlizzard.buffs and not (Azaath.IsAzaath and Azaath.IsAzaath())
        end,
        point = "TOPRIGHT",
        getPos = function()
            local b = Azaath.db.auras.playerBuffs
            return b.offsetX or 0, b.offsetY or 0
        end,
        setPos = function(x, y)
            local b = Azaath.db.auras.playerBuffs
            b.customPos = false
            b.offsetX = x
            b.offsetY = y
        end,
        getSize = function()
            local b = Azaath.db.auras.playerBuffs
            local sz, sp, pr = b.size or 30, b.spacing or 4, b.perRow or 12
            return pr * sz + (pr - 1) * sp, 2 * sz + sp
        end,
        setSize = function(w)
            local b = Azaath.db.auras.playerBuffs
            local pr, sp = b.perRow or 12, b.spacing or 4
            b.size = max(18, min(54, floor((w - (pr - 1) * sp) / pr + 0.5)))
        end,
        wSpec = { label = "Tamanho dos Ícones", min = 18, max = 54, step = 1,
                  get = function() return Azaath.db.auras.playerBuffs.size or 30 end,
                  set = function(v) Azaath.db.auras.playerBuffs.size = v end },
        extraSpec = { label = "Ícones por Linha", min = 4, max = 20, step = 1,
                      get = function() return Azaath.db.auras.playerBuffs.perRow or 12 end,
                      set = function(v) Azaath.db.auras.playerBuffs.perRow = v end },
        getScale = function() return Azaath.db.auras.playerBuffs.scale or 1 end,
        setScale = function(s) Azaath.db.auras.playerBuffs.scale = s end,
        apply = ApplyAuras,
        reset = function() ResetPath("auras.playerBuffs"); ApplyAuras() end,
    },
    {
        key = "playerDebuffs",
        frameName = "AzaathUIPlayerDebuffs",
        label = "Debuffs do Jogador",
        isEnabled = function()
            local au = Azaath.db.auras
            return au and au.playerDebuffs and au.playerDebuffs.enabled and Azaath.db.hideBlizzard.buffs and not (Azaath.IsAzaath and Azaath.IsAzaath())
        end,
        point = "BOTTOM",
        getPos = function()
            local d = Azaath.db.auras.playerDebuffs
            return d.offsetX or 0, d.offsetY or 18
        end,
        setPos = function(x, y)
            local d = Azaath.db.auras.playerDebuffs
            d.customPos = false
            d.offsetX = x
            d.offsetY = y
        end,
        getSize = function()
            local d = Azaath.db.auras.playerDebuffs
            local sz, sp, pr = d.size or 34, d.spacing or 4, d.perRow or 8
            return pr * sz + (pr - 1) * sp, sz
        end,
        setSize = function(w)
            local d = Azaath.db.auras.playerDebuffs
            local pr, sp = d.perRow or 8, d.spacing or 4
            d.size = max(18, min(56, floor((w - (pr - 1) * sp) / pr + 0.5)))
        end,
        wSpec = { label = "Tamanho dos Ícones", min = 18, max = 56, step = 1,
                  get = function() return Azaath.db.auras.playerDebuffs.size or 34 end,
                  set = function(v) Azaath.db.auras.playerDebuffs.size = v end },
        extraSpec = { label = "Ícones por Linha", min = 4, max = 16, step = 1,
                      get = function() return Azaath.db.auras.playerDebuffs.perRow or 8 end,
                      set = function(v) Azaath.db.auras.playerDebuffs.perRow = v end },
        getScale = function() return Azaath.db.auras.playerDebuffs.scale or 1 end,
        setScale = function(s) Azaath.db.auras.playerDebuffs.scale = s end,
        apply = ApplyAuras,
        reset = function() ResetPath("auras.playerDebuffs"); ApplyAuras() end,
    },
    {
        key = "targetAuras",
        frameName = "AzaathUITargetAuras",
        label = "Auras do Alvo",
        isEnabled = function() return Azaath.db.auras and Azaath.db.auras.target and Azaath.db.auras.target.enabled end,
        point = "TOP",
        getPos = function()
            local ta = Azaath.db.auras.target
            return ta.offsetX or 0, ta.offsetY or -26
        end,
        setPos = function(x, y)
            local ta = Azaath.db.auras.target
            ta.customPos = false
            ta.offsetX = x
            ta.offsetY = y
        end,
        getSize = function()
            local ta = Azaath.db.auras.target
            local sz, sp = ta.size or 24, ta.spacing or 3
            return 8 * sz + 7 * sp, 2 * sz + sp
        end,
        setSize = function(w)
            local ta = Azaath.db.auras.target
            local sp = ta.spacing or 3
            ta.size = max(16, min(48, floor((w - 7 * sp) / 8 + 0.5)))
        end,
        wSpec = { label = "Tamanho dos Ícones", min = 16, max = 48, step = 1,
                  get = function() return Azaath.db.auras.target.size or 24 end,
                  set = function(v) Azaath.db.auras.target.size = v end },
        getScale = function() return Azaath.db.auras.target.scale or 1 end,
        setScale = function(s) Azaath.db.auras.target.scale = s end,
        apply = ApplyAuras,
        reset = function() ResetPath("auras.target"); ApplyAuras() end,
    },
    {
        key = "partyFrames",
        frameName = "AzaathUIPartyContainer",
        label = "Quadros de Grupo",
        isEnabled = function() return Azaath.db.party and Azaath.db.party.enabled and Azaath.db.hideBlizzard and Azaath.db.hideBlizzard.partyFrames end,
        point = "TOPLEFT",
        getPos = function() return Azaath.db.party.offsetX or 28, Azaath.db.party.offsetY or -130 end,
        setPos = function(x, y)
            Azaath.db.party.offsetX = x
            Azaath.db.party.offsetY = y
        end,
        getSize = function()
            local p = Azaath.db.party
            return p.width or 200, 4 * (p.spacing or 42)
        end,
        setSize = function(w, h)
            Azaath.db.party.width = max(100, min(360, floor(w + 0.5)))
            Azaath.db.party.spacing = max(24, min(80, floor(h / 4 + 0.5)))
        end,
        wSpec = { label = "Largura", min = 100, max = 360, step = 5,
                  get = function() return Azaath.db.party.width or 200 end,
                  set = function(v) Azaath.db.party.width = v end },
        hSpec = { label = "Altura da Barra de Vida", min = 3, max = 20, step = 1,
                  get = function() return Azaath.db.party.barHeight or 5 end,
                  set = function(v) Azaath.db.party.barHeight = v end },
        extraSpec = { label = "Espaçamento entre Membros", min = 24, max = 80, step = 1,
                      get = function() return Azaath.db.party.spacing or 42 end,
                      set = function(v) Azaath.db.party.spacing = v end },
        getScale = function() return Azaath.db.party.scale or 1 end,
        setScale = function(s) Azaath.db.party.scale = s end,
        apply = ApplyParty,
        reset = function() ResetPath("party"); ApplyParty() end,
    },
    {
        key = "questTracker",
        frameName = "AzaathUIQuestTracker",
        label = "Rastreador de Missões",
        isEnabled = function() return Azaath.db.questtracker and Azaath.db.questtracker.enabled and Azaath.db.hideBlizzard and Azaath.db.hideBlizzard.questTracker end,
        point = "TOPRIGHT",
        getPos = function()
            local qt = Azaath.db.questtracker
            if qt.customPos then return qt.offsetX or -8, qt.offsetY or -250 end
            local f = _G.AzaathUIQuestTracker
            if f and f:GetTop() and Azaath.root:GetTop() then
                local sc = f:GetEffectiveScale() / Azaath.root:GetEffectiveScale()
                return qt.offsetX or -8, floor((f:GetTop() - Azaath.root:GetTop() / sc) + 0.5)
            end
            return qt.offsetX or -8, -250
        end,
        setPos = function(x, y)
            local qt = Azaath.db.questtracker
            qt.customPos = true
            qt.offsetX = x
            qt.offsetY = y
        end,
        getSize = function()
            local qt = Azaath.db.questtracker
            local f = _G.AzaathUIQuestTracker
            local fh = (f and f:IsShown() and f:GetHeight()) or 0
            return qt.width or 270, (fh > 20) and floor(fh + 0.5) or (qt.maxHeight or 420)
        end,
        setSize = function(w, h)
            Azaath.db.questtracker.width = max(180, min(450, floor(w + 0.5)))
            Azaath.db.questtracker.maxHeight = max(120, min(700, floor(h + 0.5)))
        end,
        wSpec = { label = "Largura", min = 180, max = 450, step = 5,
                  get = function() return Azaath.db.questtracker.width or 270 end,
                  set = function(v) Azaath.db.questtracker.width = v end },
        hSpec = { label = "Altura Máxima", min = 120, max = 700, step = 10,
                  get = function() return Azaath.db.questtracker.maxHeight or 420 end,
                  set = function(v) Azaath.db.questtracker.maxHeight = v end },
        getScale = function() return Azaath.db.questtracker.scale or 1 end,
        setScale = function(s) Azaath.db.questtracker.scale = s end,
        apply = ApplyQuestTracker,
        reset = function() ResetPath("questtracker"); ApplyQuestTracker() end,
    },
    {
        key = "microMenu",
        frameName = "AzaathUIMicroMenu",
        label = "Micro Menu (Utilidades)",
        point = "BOTTOMRIGHT",
        getPos = function()
            local m = Azaath.db.micromenu
            return (m and m.offsetX ~= nil) and m.offsetX or -16,
                   (m and m.offsetY ~= nil) and m.offsetY or 14
        end,
        setPos = function(x, y)
            Azaath.db.micromenu.anchor = "BOTTOMRIGHT"
            Azaath.db.micromenu.offsetX = x
            Azaath.db.micromenu.offsetY = y
        end,
        getSize = function()
            local m = Azaath.db.micromenu
            local mm = Azaath:GetModule("MicroMenu")
            local n = (mm and mm.GetButtonCount and mm:GetButtonCount()) or 13
            local sz, sp = m.buttonSize or 26, m.spacing or 5
            return n * sz + (n - 1) * sp, sz
        end,
        setSize = function(w)
            local m = Azaath.db.micromenu
            local mm = Azaath:GetModule("MicroMenu")
            local n = (mm and mm.GetButtonCount and mm:GetButtonCount()) or 13
            local sp = m.spacing or 5
            m.buttonSize = max(14, min(44, floor((w - (n - 1) * sp) / n + 0.5)))
        end,
        isEnabled = function()
            return Azaath.db.micromenu and Azaath.db.micromenu.enabled
        end,
        wSpec = { label = "Tamanho dos Botões", min = 14, max = 44, step = 1,
                  get = function() return Azaath.db.micromenu.buttonSize or 26 end,
                  set = function(v) Azaath.db.micromenu.buttonSize = v end },
        extraSpec = { label = "Espaçamento", min = 1, max = 12, step = 1,
                      get = function() return Azaath.db.micromenu.spacing or 5 end,
                      set = function(v) Azaath.db.micromenu.spacing = v end },
        getScale = function() return Azaath.db.micromenu.scale or 1 end,
        setScale = function(s) Azaath.db.micromenu.scale = s end,
        apply = ApplyMicroMenu,
        reset = function() ResetPath("micromenu"); ApplyMicroMenu() end,
    },
    {
        key = "dialog",
        frameName = "AzaathUIDialog",
        label = "Janela de Diálogo NPC",
        point = "RIGHT",
        getPos = function() return Azaath.db.dialog.offsetX or -57, Azaath.db.dialog.offsetY or -12 end,
        setPos = function(x, y)
            Azaath.db.dialog.offsetX = x
            Azaath.db.dialog.offsetY = y
        end,
        getSize = function()
            local w = Azaath.db.dialog.width or 500
            return w, floor(w * 800 / 698 + 0.5) -- proporção do painel Azaath
        end,
        setSize = function(w)
            Azaath.db.dialog.width = max(400, min(800, floor(w + 0.5)))
        end,
        isEnabled = function()
            return Azaath.db.dialog and Azaath.db.dialog.enabled
        end,
        wSpec = { label = "Largura da Janela", min = 400, max = 800, step = 10,
                  get = function() return Azaath.db.dialog.width or 500 end,
                  set = function(v) Azaath.db.dialog.width = v end },
        getScale = function() return Azaath.db.dialog.scale or 1 end,
        setScale = function(s) Azaath.db.dialog.scale = s end,
        apply = ApplyDialog,
        reset = function() ResetPath("dialog"); ApplyDialog() end,
    },
    {
        key = "loot",
        frameName = "AzaathUILoot",
        label = "Janela de Saque (Loot)",
        point = "CENTER",
        getPos = function() return Azaath.db.loot.offsetX or 180, Azaath.db.loot.offsetY or 20 end,
        setPos = function(x, y)
            Azaath.db.loot.offsetX = x
            Azaath.db.loot.offsetY = y
        end,
        getSize = function() return Azaath.db.loot.width or 320, 140 end,
        setSize = function(w)
            Azaath.db.loot.width = max(240, min(500, floor(w + 0.5)))
        end,
        isEnabled = function()
            return Azaath.db.loot and Azaath.db.loot.enabled
        end,
        wSpec = { label = "Largura da Janela", min = 240, max = 500, step = 10,
                  get = function() return Azaath.db.loot.width or 320 end,
                  set = function(v) Azaath.db.loot.width = v end },
        getScale = function() return Azaath.db.loot.scale or 1 end,
        setScale = function(s) Azaath.db.loot.scale = s end,
        apply = ApplyLoot,
        reset = function() ResetPath("loot"); ApplyLoot() end,
    },
    {
        key = "lootFeed",
        frameName = "AzaathUILootFeed",
        label = "Notificações de Saque",
        noResize = true,
        point = "CENTER",
        getPos = function() return Azaath.db.loot.feedX or 330, Azaath.db.loot.feedY or -60 end,
        setPos = function(x, y)
            Azaath.db.loot.feedX = x
            Azaath.db.loot.feedY = y
        end,
        getSize = function() return 300, 200 end,
        setSize = function() end,
        isEnabled = function()
            return Azaath.db.loot and Azaath.db.loot.feed
        end,
        getScale = function() return Azaath.db.loot.feedScale or 1 end,
        setScale = function(s) Azaath.db.loot.feedScale = s end,
        apply = ApplyLootFeed,
        reset = function()
            local d = Azaath.defaults.loot
            Azaath.db.loot.feedX, Azaath.db.loot.feedY, Azaath.db.loot.feedScale = d.feedX, d.feedY, d.feedScale
            ApplyLootFeed()
        end,
    },
    {
        key = "lootCelebration",
        frameName = "AzaathUILootCelebrationAnchor",
        label = "Celebrações de Saque",
        noResize = true,
        point = "CENTER",
        getPos = function()
            local lc = Azaath.db.lootCelebration or {}
            return lc.offsetX or 0, lc.offsetY or 210
        end,
        setPos = function(x, y)
            Azaath.db.lootCelebration.offsetX = x
            Azaath.db.lootCelebration.offsetY = y
        end,
        getSize = function() return 580, 250 end,
        setSize = function() end,
        isEnabled = function()
            return Azaath.db.lootCelebration and Azaath.db.lootCelebration.enabled ~= false
        end,
        getScale = function() return (Azaath.db.lootCelebration and Azaath.db.lootCelebration.scale) or 1 end,
        setScale = function(s) Azaath.db.lootCelebration.scale = s end,
        apply = function()
            local lc = Azaath:GetModule("LootCelebration")
            if lc and lc.ApplyLayout then lc:ApplyLayout() end
        end,
        reset = function()
            local d = Azaath.defaults.lootCelebration
            local lc = Azaath.db.lootCelebration
            lc.offsetX, lc.offsetY, lc.scale = d.offsetX, d.offsetY, d.scale
            local mod = Azaath:GetModule("LootCelebration")
            if mod and mod.ApplyLayout then mod:ApplyLayout() end
        end,
    },
    {
        key = "chat",
        frameName = "AzaathChatContainer",
        label = "Chat Azaath",
        point = "BOTTOMLEFT",
        getPos = function()
            local db = Azaath.db.chat or {}
            return db.offsetX or 28, db.offsetY or 48
        end,
        setPos = function(x, y)
            Azaath.db.chat.offsetX = x
            Azaath.db.chat.offsetY = y
        end,
        getSize = function()
            local db = Azaath.db.chat or {}
            return db.width or 420, db.height or 290
        end,
        setSize = function(w, h)
            Azaath.db.chat.width = max(260, min(800, floor(w + 0.5)))
            Azaath.db.chat.height = max(160, min(600, floor(h + 0.5)))
        end,
        isEnabled = function()
            return Azaath.db.chat and Azaath.db.chat.enabled
        end,
        wSpec = { label = "Largura do Chat", min = 260, max = 800, step = 10,
                  get = function() return Azaath.db.chat.width or 420 end,
                  set = function(v) Azaath.db.chat.width = v end },
        hSpec = { label = "Altura do Chat", min = 160, max = 600, step = 10,
                  get = function() return Azaath.db.chat.height or 290 end,
                  set = function(v) Azaath.db.chat.height = v end },
        getScale = function() return Azaath.db.chat.scale or 1 end,
        setScale = function(s) Azaath.db.chat.scale = s end,
        apply = function()
            local m = Azaath:GetModule("Chat")
            if m and m.ApplyLayout then m:ApplyLayout() end
        end,
        reset = function()
            local d = Azaath.defaults.chat or {}
            local db = Azaath.db.chat
            db.width = d.width or 420
            db.height = d.height or 290
            db.offsetX = d.offsetX or 28
            db.offsetY = d.offsetY or 48
            db.scale = d.scale or 1
            local m = Azaath:GetModule("Chat")
            if m and m.ApplyLayout then m:ApplyLayout() end
        end,
    },
}

local RefreshAllHandles
local UpdateInspector

local function GetElemPoint(elem)
    if elem.getPoint then return elem.getPoint() end
    return elem.point or "CENTER"
end

local function ElemFrame(elem)
    return (elem.getFrame and elem.getFrame()) or (elem.frameName and _G[elem.frameName])
end

local function SyncHandle(h)
    local elem = h.elem
    if elem.isEnabled and not elem.isEnabled() then
        h:Hide()
        return
    end
    h:Show()

    local w, ht = elem.getSize()
    local sc = elem.getScale() or 1
    local f = ElemFrame(elem)
    local cx, cy
    if f then
        cx, cy = f:GetCenter()
    end

    local c = Azaath.colors
    local active = (selectedElem == elem) or h.isHovered or h.isDragging

    h:ClearAllPoints()
    local ew = editorFrame and editorFrame:GetWidth()
    if not ew or ew <= 0 then ew = UIParent:GetWidth() or 1920 end
    local eh = editorFrame and editorFrame:GetHeight()
    if not eh or eh <= 0 then eh = UIParent:GetHeight() or 1080 end
    local isOverlay = (elem.key == "dialog" or elem.key == "loot" or elem.key == "lootFeed" or elem.key == "lootCelebration")
    if f and cx and cy and editorFrame then
        local ratio = f:GetEffectiveScale() / editorFrame:GetEffectiveScale()
        local fw = (f:GetWidth() or w) * ratio
        local fh = (f:GetHeight() or ht) * ratio
        if ((elem.key == "dialog" or elem.key == "loot") and not f:IsShown()) or elem.key == "lootCelebration" then
            -- Janelas modais fechadas e âncora de celebração ficam como barra compacta até passar o mouse/selecionar
            fh = active and (ht * ratio) or 22
        end
        local hw, hh = max(28, fw), max(18, fh)
        h:SetWidth(hw)
        h:SetHeight(hh)
        local hx = (hw <= ew) and max(hw / 2, min(ew - hw / 2, cx * ratio)) or (ew / 2)
        local hy = (hh <= eh) and max(hh / 2, min(eh - hh / 2, cy * ratio)) or (eh / 2)
        h:SetPoint("CENTER", editorFrame, "BOTTOMLEFT", hx, hy)
    else
        local pt = GetElemPoint(elem)
        local ox, oy = elem.getPos()
        h:SetWidth(max(28, w * sc))
        h:SetHeight(max(18, ht * sc))
        h:SetPoint(pt, Azaath.root, pt, ox * sc, oy * sc)
        if Azaath.ClampToScreen then Azaath.ClampToScreen(h) end
    end

    local lvl = h.isDragging and 55 or ((selectedElem == elem) and 45 or (h.isHovered and 35 or (isOverlay and 12 or 20)))
    h:SetFrameLevel(lvl)
    if h.pill then h.pill:SetFrameLevel(lvl + 6) end
    if h.grip then h.grip:SetFrameLevel(lvl + 7) end
    if active then
        h.pillTxt:SetText(format("%s  |cffe0b159%dx%d|r · |cff8ec4ff%.2fx|r", Tr(elem.label), floor(w + 0.5), floor(ht + 0.5), sc))
    else
        h.pillTxt:SetText(Tr(elem.label))
    end
    local pw = (h.pillTxt:GetStringWidth() or 80) + 14
    h.pill:SetWidth(max(44, pw))

    -- Para elementos pequenos (ex.: Selo de Nível, Mochila), centraliza o botão compacto fora da caixa;
    -- nos demais, o rótulo fica dentro da caixa sem interceptar o mouse (evita perda de foco ao arrastar).
    h.pill:ClearAllPoints()
    if h:GetWidth() < 80 then
        h.pill:EnableMouse(true)
        local topY = h:GetTop()
        if topY and eh and (eh - topY) < 18 then
            h.pill:SetPoint("TOP", h, "BOTTOM", 0, -1)
        else
            h.pill:SetPoint("BOTTOM", h, "TOP", 0, 1)
        end
    else
        h.pill:EnableMouse(false)
        h.pill:SetPoint("TOPLEFT", h, "TOPLEFT", 1, -1)
    end

    if selectedElem == elem then
        h:SetBackdropColor(c.accent[1], c.accent[2], c.accent[3], 0.18)
        h:SetBackdropBorderColor(1, 0.88, 0.35, 1)
        h.pill:SetBackdropColor(0.14, 0.11, 0.04, 0.96)
        h.pill:SetBackdropBorderColor(1, 0.88, 0.35, 1)
    elseif h.isHovered or h.isDragging then
        h:SetBackdropColor(0.10, 0.16, 0.24, 0.16)
        h:SetBackdropBorderColor(1, 0.95, 0.75, 0.95)
        h.pill:SetBackdropColor(0.10, 0.13, 0.18, 0.96)
        h.pill:SetBackdropBorderColor(1, 0.95, 0.75, 0.95)
    else
        h:SetBackdropColor(0.05, 0.08, 0.12, 0.08)
        h:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.55)
        h.pill:SetBackdropColor(0.05, 0.06, 0.08, 0.88)
        h.pill:SetBackdropBorderColor(c.gold[1], c.gold[2], c.gold[3], 0.65)
    end
end

RefreshAllHandles = function()
    for _, h in ipairs(handles) do
        SyncHandle(h)
    end
    if UpdateInspector then UpdateInspector() end
end

-- Elementos ancorados uns nos outros (buffs/debuffs/conjuração na vida, selo
-- na XP, rastreador no minimapa...) não podem ir junto quando um deles é
-- movido ou redimensionado: tira-se uma "foto" da posição de tela dos outros
-- e, depois da mudança, cada um que saiu do lugar tem o deslocamento desfeito.
local function ElemCenter(e)
    local f = ElemFrame(e)
    if not (f and f.GetCenter and f:IsVisible()) then return nil end
    local x, y = f:GetCenter()
    if not x then return nil end
    local s = f:GetEffectiveScale()
    if not s or s <= 0 then return nil end
    return x * s, y * s, s
end

local function SnapshotOthers(moved)
    local snap = {}
    local isTarget = moved and moved.key == "targetFrame"
    for _, e in ipairs(EDITOR_ELEMENTS) do
        if e ~= moved and e.getPos and e.setPos and e.apply
            and not (isTarget and (e.key == "targetAuras" or e.key == "targetCastBar")) then
            local x, y = ElemCenter(e)
            if x then snap[e] = { x = x, y = y } end
        end
    end
    return snap
end

local function RestoreOthers(snap)
    if not snap then return end
    for _ = 1, 3 do -- cadeias (ex.: vida -> conjuração -> debuffs)
        local changed = false
        for e, p in pairs(snap) do
            local x, y, s = ElemCenter(e)
            if x then
                local dx, dy = (x - p.x) / s, (y - p.y) / s
                local before = math.abs(dx) + math.abs(dy)
                if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then
                    local ox, oy = e.getPos()
                    e.setPos(floor((ox or 0) - dx + 0.5), floor((oy or 0) - dy + 0.5))
                    pcall(e.apply)
                    -- elemento que não responde ao próprio deslocamento (preso
                    -- por outra regra): desfaz e não mexe mais nele nesta ação
                    local nx, ny = ElemCenter(e)
                    local after = nx and (math.abs((nx - p.x) / s) + math.abs((ny - p.y) / s)) or 0
                    if after > before * 0.5 + 1 then
                        e.setPos(ox, oy)
                        pcall(e.apply)
                        snap[e] = nil
                    else
                        changed = true
                    end
                end
            end
        end
        if not changed then break end
    end
end

-- Executa uma mudança no elemento sem arrastar os vizinhos
local function WithOthersPinned(elem, fn)
    local snap = SnapshotOthers(elem)
    fn()
    RestoreOthers(snap)
end

local function BuildInspector()
    if inspectorFrame then return end
    local c = Azaath.colors

    inspectorFrame = CreateFrame("Frame", "AzaathUIEditorInspector", UIParent)
    inspectorFrame:SetWidth(330)
    inspectorFrame:SetHeight(350)
    inspectorFrame:SetPoint("CENTER", UIParent, "CENTER", 0, -170)
    inspectorFrame:SetFrameStrata("FULLSCREEN_DIALOG")
    inspectorFrame:SetToplevel(true)
    inspectorFrame:EnableMouse(true)
    inspectorFrame:SetMovable(true)
    inspectorFrame:SetClampedToScreen(true)
    inspectorFrame:RegisterForDrag("LeftButton")
    inspectorFrame:SetScript("OnDragStart", inspectorFrame.StartMoving)
    inspectorFrame:SetScript("OnDragStop", inspectorFrame.StopMovingOrSizing)
    Panel(inspectorFrame, 0.96, 0.75)
    inspectorFrame:Hide()

    local title = CreateText(inspectorFrame, 14, c.gold)
    title:SetPoint("TOPLEFT", inspectorFrame, "TOPLEFT", 14, -12)
    title:SetText(Tr("Inspetor de Elemento"))
    inspectorFrame.title = title

    local close = CreateStyledButton(inspectorFrame, "X", 22, function()
        selectedElem = nil
        inspectorFrame:Hide()
        RefreshAllHandles()
    end)
    close:SetPoint("TOPRIGHT", inspectorFrame, "TOPRIGHT", -8, -8)

    local function MakeInspSlider(yOffset)
        local row = CreateFrame("Frame", nil, inspectorFrame)
        row:SetHeight(36)
        row:SetPoint("TOPLEFT", inspectorFrame, "TOPLEFT", 14, yOffset)
        row:SetPoint("TOPRIGHT", inspectorFrame, "TOPRIGHT", -14, yOffset)

        row.label = CreateText(row, 11)
        row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
        row.val = CreateText(row, 11, c.gold)
        row.val:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)

        local s = CreateFrame("Slider", nil, row)
        s:SetOrientation("HORIZONTAL")
        s:SetHeight(10)
        s:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -18)
        s:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -18)
        Panel(s, 0.9, 0.35)
        s:SetThumbTexture(Azaath.media.blank)
        local th = s:GetThumbTexture()
        th:SetWidth(8)
        th:SetHeight(15)
        th:SetVertexColor(c.accent[1], c.accent[2], c.accent[3])
        s:EnableMouseWheel(true)
        row.slider = s
        return row
    end

    local sScale = MakeInspSlider(-42)
    local sW     = MakeInspSlider(-82)
    local sH     = MakeInspSlider(-122)
    local sExtra = MakeInspSlider(-162)
    local sX     = MakeInspSlider(-202)
    local sY     = MakeInspSlider(-242)

    local function BindRow(row, labelText, minV, maxV, stepV, fmtStr, getter, setter)
        if not getter or not setter then
            row:Hide()
            return
        end
        row:Show()
        row.updating = true
        row.label:SetText(Tr(labelText))
        row.slider:SetMinMaxValues(minV, maxV)
        row.slider:SetValueStep(stepV)
        local cur = getter() or minV
        local snapped = floor((cur - minV) / stepV + 0.5) * stepV + minV
        snapped = max(minV, min(maxV, snapped))
        row.slider:SetValue(snapped)
        row.val:SetText(format(fmtStr, snapped))
        row.updating = false

        row.slider:SetScript("OnValueChanged", function(_, v)
            if row.updating or not selectedElem then return end
            v = floor((v - minV) / stepV + 0.5) * stepV + minV
            v = max(minV, min(maxV, v))
            row.val:SetText(format(fmtStr, v))
            local elem = selectedElem
            WithOthersPinned(elem, function()
                setter(v)
                elem.apply()
            end)
            for _, h in ipairs(handles) do SyncHandle(h) end
        end)
        row.slider:SetScript("OnMouseWheel", function(self, delta)
            self:SetValue(max(minV, min(maxV, self:GetValue() + delta * stepV)))
        end)
    end

    local centerBtn = CreateStyledButton(inspectorFrame, Tr("Centralizar X"), 142, function()
        if not selectedElem then return end
        local elem = selectedElem
        local _, y = elem.getPos()
        WithOthersPinned(elem, function()
            elem.setPos(0, y)
            elem.apply()
        end)
        RefreshAllHandles()
    end)
    centerBtn:SetPoint("BOTTOMLEFT", inspectorFrame, "BOTTOMLEFT", 14, 14)

    local resetBtn = CreateStyledButton(inspectorFrame, Tr("Resetar Elemento"), 148, function()
        if not selectedElem then return end
        WithOthersPinned(selectedElem, selectedElem.reset)
        RefreshAllHandles()
    end)
    resetBtn:SetPoint("BOTTOMRIGHT", inspectorFrame, "BOTTOMRIGHT", -14, 14)

    UpdateInspector = function()
        if not inspectorFrame then return end
        if not selectedElem then
            inspectorFrame:Hide()
            return
        end
        local elem = selectedElem
        title:SetText(Tr(elem.label))
        centerBtn.text:SetText(Tr("Centralizar X"))
        resetBtn.text:SetText(Tr("Resetar Elemento"))

        BindRow(sScale, "Escala", elem.minScale or 0.5, elem.maxScale or 2.5, 0.05, "%.2fx", elem.getScale, elem.setScale)
        if elem.wSpec and (not elem.wSpec.isEnabled or elem.wSpec.isEnabled()) then
            BindRow(sW, elem.wSpec.label, elem.wSpec.min, elem.wSpec.max, elem.wSpec.step, "%d px", elem.wSpec.get, elem.wSpec.set)
        else
            BindRow(sW, nil, 0, 1, 1, "%d", nil, nil)
        end
        if elem.hSpec and (not elem.hSpec.isEnabled or elem.hSpec.isEnabled()) then
            BindRow(sH, elem.hSpec.label, elem.hSpec.min, elem.hSpec.max, elem.hSpec.step, "%d px", elem.hSpec.get, elem.hSpec.set)
        else
            BindRow(sH, nil, 0, 1, 1, "%d", nil, nil)
        end
        if elem.extraSpec and (not elem.extraSpec.isEnabled or elem.extraSpec.isEnabled()) then
            BindRow(sExtra, elem.extraSpec.label, elem.extraSpec.min, elem.extraSpec.max, elem.extraSpec.step, "%d", elem.extraSpec.get, elem.extraSpec.set)
        else
            BindRow(sExtra, nil, 0, 1, 1, "%d", nil, nil)
        end
        BindRow(sX, "Posição Horizontal (X)", -1600, 1600, 1, "%d px",
            function() local x = elem.getPos(); return x end,
            function(v) local _, y = elem.getPos(); elem.setPos(v, y) end)
        BindRow(sY, "Posição Vertical (Y)", -1600, 1600, 1, "%d px",
            function() local _, y = elem.getPos(); return y end,
            function(v) local x = elem.getPos(); elem.setPos(x, v) end)

        inspectorFrame:Show()
    end
end

local function CreateElementHandle(elem)
    local c = Azaath.colors
    local h = CreateFrame("Button", nil, editorFrame)
    h:SetFrameStrata("DIALOG")
    h:SetFrameLevel(20)
    h:EnableMouse(true)
    h:EnableMouseWheel(true)
    h:RegisterForDrag("LeftButton")
    Azaath.SetBackdrop(h, GetBackdrop())
    h.elem = elem

    -- Botão compacto de arrastar e editar acoplado diretamente ao elemento
    local pill = CreateFrame("Button", nil, h)
    pill:SetHeight(16)
    pill:SetWidth(90)
    pill:SetPoint("TOPLEFT", h, "TOPLEFT", 1, -1)
    pill:SetFrameLevel(h:GetFrameLevel() + 6)
    pill:EnableMouse(true)
    pill:EnableMouseWheel(true)
    pill:RegisterForDrag("LeftButton")
    pill:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    Azaath.SetBackdrop(pill, GetBackdrop())
    h.pill = pill

    local pillTxt = CreateText(pill, 10, c.cream)
    pillTxt:SetPoint("CENTER", pill, "CENTER", 0, 0)
    pillTxt:SetJustifyH("CENTER")
    h.pillTxt = pillTxt

    -- Alça de redimensionamento no canto inferior direito (◢)
    local grip = CreateFrame("Button", nil, h)
    grip:SetWidth(16)
    grip:SetHeight(16)
    grip:SetPoint("BOTTOMRIGHT", h, "BOTTOMRIGHT", -1, 1)
    grip:SetFrameLevel(h:GetFrameLevel() + 7)
    grip:EnableMouse(not elem.noResize)
    grip:RegisterForDrag("LeftButton")
    if elem.noResize then grip:Hide() end
    h.grip = grip

    -- textura do próprio jogo (o caractere "◢" virava quadrado na fonte)
    local gripTxt = grip:CreateTexture(nil, "OVERLAY")
    gripTxt:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    gripTxt:SetSize(14, 14)
    gripTxt:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", -1, 1)
    gripTxt:SetVertexColor(c.gold[1], c.gold[2], c.gold[3])
    gripTxt.SetTextColor = gripTxt.SetVertexColor

    local function StopMoveDrag()
        if not h.isDragging and not h.mouseArmed then return end
        h.isDragging = false
        h.mouseArmed = false
        h:SetScript("OnUpdate", nil)
        h.pinSnap = nil
        RefreshAllHandles()
    end

    local function BeginMove(requireThreshold)
        selectedElem = elem
        if elem.lockedPos then
            RefreshAllHandles()
            return
        end
        if h.isDragging or h.mouseArmed then
            if not requireThreshold then h.mouseArmed = false end
            return
        end
        local cx, cy = GetCursorPosition()
        h.rawStartX = cx
        h.rawStartY = cy
        local ox, oy = elem.getPos()
        local f0 = ElemFrame(elem)
        local altF0 = elem.frameName and _G[elem.frameName]
        local cdx0 = (f0 and f0._azClampDX and f0._azClampDX ~= 0 and f0._azClampDX) or (altF0 and altF0._azClampDX) or 0
        local cdy0 = (f0 and f0._azClampDY and f0._azClampDY ~= 0 and f0._azClampDY) or (altF0 and altF0._azClampDY) or 0
        h.origX = ox + cdx0
        h.origY = oy + cdy0
        h.pinSnap = SnapshotOthers(elem)
        h.mouseArmed = requireThreshold and true or false
        h.isDragging = true
        h:SetScript("OnUpdate", function(s)
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                StopMoveDrag()
                return
            end
            local nx, ny = GetCursorPosition()
            if s.mouseArmed then
                if math.abs(nx - s.rawStartX) < 2 and math.abs(ny - s.rawStartY) < 2 then
                    return
                end
                s.mouseArmed = false
            end
            local f = ElemFrame(elem)
            local altF = elem.frameName and _G[elem.frameName]
            local eff = (f and f:GetEffectiveScale()) or (Azaath.root:GetEffectiveScale() * (elem.getScale() or 1))
            if not eff or eff <= 0 then eff = 1 end
            local dx = (nx - s.rawStartX) / eff
            local dy = (ny - s.rawStartY) / eff
            local tx = floor(s.origX + dx + 0.5)
            local ty = floor(s.origY + dy + 0.5)
            elem.setPos(tx, ty)
            elem.apply()
            local cdx = (f and f._azClampDX and f._azClampDX ~= 0 and f._azClampDX) or (altF and altF._azClampDX) or 0
            local cdy = (f and f._azClampDY and f._azClampDY ~= 0 and f._azClampDY) or (altF and altF._azClampDY) or 0
            if cdx ~= 0 or cdy ~= 0 then
                local tx2 = floor(tx + cdx + 0.5)
                local ty2 = floor(ty + cdy + 0.5)
                if tx2 ~= tx or ty2 ~= ty then
                    elem.setPos(tx2, ty2)
                    elem.apply()
                end
            end
            RestoreOthers(s.pinSnap)
            for _, oh in ipairs(handles) do SyncHandle(oh) end
            if UpdateInspector then UpdateInspector() end
        end)
    end

    local function StartMoveDrag()
        BeginMove(false)
    end

    local function HandleMouseDown(_, btn)
        if btn == "RightButton" then
            WithOthersPinned(elem, elem.reset)
            RefreshAllHandles()
            return
        end
        if btn == "LeftButton" then
            BeginMove(true)
        end
    end

    local function HandleMouseUp(_, btn)
        if btn == "LeftButton" then
            StopMoveDrag()
        end
    end

    local function HandleClick(_, btn)
        if btn == "RightButton" then
            WithOthersPinned(elem, elem.reset)
            RefreshAllHandles()
            return
        end
        selectedElem = elem
        RefreshAllHandles()
    end

    local function HandleWheel(_, delta)
        selectedElem = elem
        local cur = elem.getScale() or 1
        local nextScale = max(elem.minScale or 0.5, min(elem.maxScale or 2.5, floor((cur + delta * 0.05) * 20 + 0.5) / 20))
        WithOthersPinned(elem, function()
            elem.setScale(nextScale)
            elem.apply()
        end)
        RefreshAllHandles()
    end

    local function HandleEnter(owner)
        h.isHovered = true
        SyncHandle(h)
        if elem.lockedPos then
            ShowTooltip(owner, Tr(elem.label) .. Tr("\n• Posição fixa nesta skin\n• Canto ou Roda do mouse: Dimensionar HUD\n• Clique esquerdo: Editar no Inspetor\n• Clique direito: Resetar tamanho"))
        else
            ShowTooltip(owner, Tr(elem.label) .. Tr("\n• Arraste o botão ou quadro: Mover junto\n• Canto: Redimensionar\n• Roda do mouse: Escala\n• Clique esquerdo: Editar no Inspetor\n• Clique direito: Resetar elemento"))
        end
    end

    local function HandleLeave()
        h.isHovered = false
        GameTooltip:Hide()
        SyncHandle(h)
    end

    -- Arrastar / clicar tanto no quadro quanto no botão acoplado move e edita o conjunto
    h:SetScript("OnDragStart", StartMoveDrag)
    h:SetScript("OnDragStop", StopMoveDrag)
    h:SetScript("OnMouseDown", HandleMouseDown)
    h:SetScript("OnMouseUp", HandleMouseUp)
    h:SetScript("OnHide", function()
        if h.isDragging or h.mouseArmed then
            h.isDragging = false
            h.mouseArmed = false
            h:SetScript("OnUpdate", nil)
            h.pinSnap = nil
        end
    end)
    h:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    h:SetScript("OnClick", HandleClick)
    h:SetScript("OnMouseWheel", HandleWheel)
    h:SetScript("OnEnter", HandleEnter)
    h:SetScript("OnLeave", HandleLeave)

    pill:SetScript("OnDragStart", StartMoveDrag)
    pill:SetScript("OnDragStop", StopMoveDrag)
    pill:SetScript("OnMouseDown", HandleMouseDown)
    pill:SetScript("OnMouseUp", HandleMouseUp)
    pill:SetScript("OnClick", HandleClick)
    pill:SetScript("OnMouseWheel", HandleWheel)
    pill:SetScript("OnEnter", HandleEnter)
    pill:SetScript("OnLeave", HandleLeave)

    -- Arrastar o canto inferior direito (◢) para redimensionar
    local function StopResize(self)
        if not self.isResizing then return end
        self.isResizing = false
        h.isDragging = false
        self:SetScript("OnUpdate", nil)
        self.pinSnap = nil
        RefreshAllHandles()
    end

    local function StartResize(self)
        if self.isResizing then return end
        selectedElem = elem
        self.isResizing = true
        h.isDragging = true
        local cx, cy = GetCursorPosition()
        self.rawStartX = cx
        self.rawStartY = cy
        self.origW, self.origH = elem.getSize()
        self.pinSnap = SnapshotOthers(elem)
        self:SetScript("OnUpdate", function(s)
            if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
                StopResize(s)
                return
            end
            local nx, ny = GetCursorPosition()
            local f = ElemFrame(elem)
            local isScaleResize = (elem.scaleOnResize == true) or (type(elem.scaleOnResize) == "function" and elem.scaleOnResize())
            local eff = isScaleResize
                and (Azaath.root:GetEffectiveScale() or 1)
                or ((f and f:GetEffectiveScale()) or (Azaath.root:GetEffectiveScale() * (elem.getScale() or 1)))
            if not eff or eff <= 0 then eff = 1 end
            local dw = (nx - s.rawStartX) / eff
            local dh = (s.rawStartY - ny) / eff
            elem.setSize(max(16, s.origW + dw), max(6, s.origH + dh))
            elem.apply()
            RestoreOthers(s.pinSnap)
            for _, oh in ipairs(handles) do SyncHandle(oh) end
            if UpdateInspector then UpdateInspector() end
        end)
    end

    grip:SetScript("OnDragStart", StartResize)
    grip:SetScript("OnDragStop", StopResize)
    grip:SetScript("OnMouseDown", function(self, btn)
        if btn == "LeftButton" then StartResize(self) end
    end)
    grip:SetScript("OnMouseUp", function(self, btn)
        if btn == "LeftButton" then StopResize(self) end
    end)
    grip:SetScript("OnHide", function(self)
        if self.isResizing or h.isDragging then
            self.isResizing = false
            h.isDragging = false
            self:SetScript("OnUpdate", nil)
            self.pinSnap = nil
        end
    end)
    grip:SetScript("OnEnter", function(self)
        h.isHovered = true
        gripTxt:SetTextColor(1, 1, 1)
        SyncHandle(h)
        ShowTooltip(self, Tr("Arraste para redimensionar ") .. Tr(elem.label))
    end)
    grip:SetScript("OnLeave", function()
        h.isHovered = false
        gripTxt:SetTextColor(c.gold[1], c.gold[2], c.gold[3])
        GameTooltip:Hide()
        SyncHandle(h)
    end)

    return h
end

local function BuildEditor()
    if editorFrame then return end
    local c = Azaath.colors

    editorFrame = CreateFrame("Frame", "AzaathUIEditor", UIParent)
    editorFrame:SetAllPoints(UIParent)
    editorFrame:SetFrameStrata("DIALOG")
    editorFrame:Hide()
    tinsert(UISpecialFrames, "AzaathUIEditor")

    -- Grade de alinhamento opcional
    gridFrame = CreateFrame("Frame", nil, editorFrame)
    gridFrame:SetAllPoints(editorFrame)
    gridFrame:SetFrameLevel(1)
    local cols, rows = 32, 18
    gridFrame.vLines, gridFrame.hLines = {}, {}
    for i = 1, cols - 1 do
        local line = gridFrame:CreateTexture(nil, "BACKGROUND")
        line:SetTexture(Azaath.media.blank)
        local isCenter = (i == cols / 2)
        line:SetVertexColor(c.gold[1], c.gold[2], c.gold[3], isCenter and 0.45 or 0.10)
        line:SetWidth(isCenter and 2 or 1)
        gridFrame.vLines[i] = line
    end
    for j = 1, rows - 1 do
        local line = gridFrame:CreateTexture(nil, "BACKGROUND")
        line:SetTexture(Azaath.media.blank)
        local isCenter = (j == rows / 2)
        line:SetVertexColor(c.gold[1], c.gold[2], c.gold[3], isCenter and 0.45 or 0.10)
        line:SetHeight(isCenter and 2 or 1)
        gridFrame.hLines[j] = line
    end

    -- Barra de controle móvel (inicia no centro para não cobrir Bússola/Alvo no topo)
    local banner = CreateFrame("Frame", nil, editorFrame)
    banner:SetWidth(680)
    banner:SetHeight(58)
    banner:SetPoint("CENTER", editorFrame, "CENTER", 0, 50)
    banner:SetFrameStrata("FULLSCREEN_DIALOG")
    banner:SetClampedToScreen(true)
    banner:EnableMouse(true)
    banner:SetMovable(true)
    banner:RegisterForDrag("LeftButton")
    banner:SetScript("OnDragStart", banner.StartMoving)
    banner:SetScript("OnDragStop", banner.StopMovingOrSizing)
    Panel(banner, 0.96, 0.8)

    local function LayoutGrid()
        local sw = (editorFrame and editorFrame:GetWidth()) or UIParent:GetWidth() or 1920
        local sh = (editorFrame and editorFrame:GetHeight()) or UIParent:GetHeight() or 1080
        for i, line in ipairs(gridFrame.vLines) do
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", (sw / cols) * i, 0)
            line:SetPoint("BOTTOMLEFT", gridFrame, "BOTTOMLEFT", (sw / cols) * i, 0)
        end
        for j, line in ipairs(gridFrame.hLines) do
            line:ClearAllPoints()
            line:SetPoint("TOPLEFT", gridFrame, "TOPLEFT", 0, -(sh / rows) * j)
            line:SetPoint("TOPRIGHT", gridFrame, "TOPRIGHT", 0, -(sh / rows) * j)
        end
        banner:SetScale(min(1, max(0.5, (sw - 20) / 680)))
    end
    editorFrame.LayoutGrid = LayoutGrid
    LayoutGrid()

    local bTitle = CreateText(banner, 14, c.gold)
    bTitle:SetPoint("TOPLEFT", banner, "TOPLEFT", 14, -10)

    local bSub = CreateText(banner, 11, c.dim)
    bSub:SetPoint("BOTTOMLEFT", banner, "BOTTOMLEFT", 14, 10)

    local doneBtn = CreateStyledButton(banner, "Concluir", 96, function()
        M:ToggleEditMode(false)
    end)
    doneBtn:SetPoint("RIGHT", banner, "RIGHT", -12, 0)

    local cfgBtn = CreateStyledButton(banner, "Menu /azaath", 96, function()
        M:ToggleEditMode(false)
        M:Open()
    end)
    cfgBtn:SetPoint("RIGHT", doneBtn, "LEFT", -6, 0)

    local resetAllBtn = CreateStyledButton(banner, "Resetar Tudo", 104, function()
        M:ResetAllElements()
    end)
    resetAllBtn:SetPoint("RIGHT", cfgBtn, "LEFT", -6, 0)

    local gridBtn = CreateStyledButton(banner, "Grade", 70, function()
        if gridFrame:IsShown() then gridFrame:Hide() else gridFrame:Show() end
    end)
    gridBtn:SetPoint("RIGHT", resetAllBtn, "LEFT", -6, 0)

    -- textos no idioma do painel (refeitos a cada abertura)
    local function LocalizeBanner()
        bTitle:SetText(Tr("MODO DE EDIÇÃO AZAATHUI"))
        bSub:SetText(Tr("Arraste = Mover · Canto = Redimensionar · Roda = Escala · Clique = Ajuste Fino"))
        doneBtn.text:SetText(Tr("Concluir"))
        cfgBtn.text:SetText(Tr("Menu /azaath"))
        resetAllBtn.text:SetText(Tr("Resetar Tudo"))
        gridBtn.text:SetText(Tr("Grade"))
    end

    BuildInspector()

    for i, elem in ipairs(EDITOR_ELEMENTS) do
        handles[i] = CreateElementHandle(elem)
    end

    local EDITABLE_MODULES = {
        "Experience", "UnitFrames", "BDOHUD", "CastBar", "Auras", "StancePetBars", "PartyFrames", "MicroMenu", "Chat",
    }

    local syncAcc = 0
    editorFrame:SetScript("OnUpdate", function(_, elapsed)
        syncAcc = syncAcc + (elapsed or 0)
        if syncAcc >= 0.15 then
            syncAcc = 0
            for _, h in ipairs(handles) do
                if not h.isDragging then
                    SyncHandle(h)
                end
            end
        end
    end)

    editorFrame:SetScript("OnSizeChanged", function()
        LayoutGrid()
        if editorFrame:IsShown() then RefreshAllHandles() end
    end)

    editorFrame:SetScript("OnShow", function()
        LocalizeBanner()
        LayoutGrid()
        for _, mName in ipairs(EDITABLE_MODULES) do
            local mod = Azaath:GetModule(mName)
            if mod and mod.SetEditing then mod:SetEditing(true) end
        end
        RefreshAllHandles()
    end)
    editorFrame:SetScript("OnHide", function()
        for _, mName in ipairs(EDITABLE_MODULES) do
            local mod = Azaath:GetModule(mName)
            if mod and mod.SetEditing then mod:SetEditing(false) end
        end
        if inspectorFrame then inspectorFrame:Hide() end
        selectedElem = nil
        -- o que foi mexido vira o preset da skin atual
        if Azaath.SaveLayoutProfile then pcall(Azaath.SaveLayoutProfile) end
    end)
end

function M:ResetAllElements()
    for _, elem in ipairs(EDITOR_ELEMENTS) do
        if elem.reset then elem.reset() end
    end
    RefreshAllHandles()
    if U.RefreshVisible then U.RefreshVisible() end
end

function M:ToggleEditMode(forceState)
    BuildEditor()
    local show = forceState
    if show == nil then show = not editorFrame:IsShown() end
    if show then
        U.Hide()
        editorFrame:Show()
    else
        editorFrame:Hide()
    end
end

--------------------------------------------------------------------------------
-- API do módulo
--------------------------------------------------------------------------------
function M:Open()
    if editorFrame and editorFrame:IsShown() then editorFrame:Hide() end
    U.Open()
end

function M:OnScaleChanged()
    if U.ApplyWindowScale then U.ApplyWindowScale() end
    if editorFrame then
        if editorFrame.LayoutGrid then editorFrame.LayoutGrid() end
        if editorFrame:IsShown() then RefreshAllHandles() end
    end
end

function M:Toggle()
    if U.IsShown() then U.Hide() else self:Open() end
end

function M:OnEnable()
    U.Migrate()
    local ab = Azaath.db and Azaath.db.actionbars
    local cleaned = false
    if ab then
        for _, k in ipairs({ "bar1", "bar2", "bar3" }) do
            local b = ab[k]
            if b and (b.customPos or (Azaath.IsSixCols(ab.layout) and b.cols == 12)) then
                b.customPos = false
                b.offsetX = 0
                b.offsetY = 0
                if b.cols == 12 and Azaath.IsSixCols(ab.layout) then b.cols = 0 end
                cleaned = true
            end
        end
    end
    -- Limpeza única dos elementos que haviam ficado empilhados no centro na versão anterior do editor
    if Azaath.db and not Azaath.db.editorFixedV3 then
        Azaath.db.editorFixedV3 = true
        if ab then
            for _, k in ipairs({ "bar1", "bar2", "bar3", "stance", "pet" }) do
                if ab[k] then
                    ab[k].customPos = false
                    ab[k].offsetX = 0
                    ab[k].offsetY = 0
                end
            end
            cleaned = true
        end
        if Azaath.db.castbar and Azaath.db.castbar.player then
            Azaath.db.castbar.player.offsetX = 0
            Azaath.db.castbar.player.offsetY = 18
            ApplyCastBar()
        end
        if Azaath.db.auras and Azaath.db.auras.playerDebuffs then
            Azaath.db.auras.playerDebuffs.offsetX = 0
            Azaath.db.auras.playerDebuffs.offsetY = 18
            ApplyAuras()
        end
    end
    if cleaned then
        ApplyActionBars()
        ApplyStancePet()
    end
    U.CreateOptionsStub()
end
