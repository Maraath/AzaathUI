--[[----------------------------------------------------------------------------
    AzaathUI - Modules/Config/Options.lua
    Dados do painel de configuração: aplicação ao vivo das opções, migração do
    banco do painel e o ESQUEMA das abas (sem textos: rótulos e descrições
    saem de Locale.lua pela chave de cada linha, normalmente o caminho no banco).

    Linha:
      t       = "toggle" | "slider" | "choice" | "button" | "note"
      path    = caminho em AzaathUIDB ("compass.width"); também é a chave do texto
      key     = chave do texto quando difere do caminho
      neg     = o banco guarda negativo (distância do topo), o controle mostra positivo
      get/set = acesso próprio; resetPaths = caminhos restaurados pelo "Restaurar seção"
      apply   = função chamada após mudar; reload = true se só vale após /reload
      needs   = caminho que precisa estar ligado; when/why = condição própria + texto
------------------------------------------------------------------------------]]

local _, Azaath = ...
local U = Azaath.ConfigUI

local type = type

--------------------------------------------------------------------------------
-- Banco por caminho
--------------------------------------------------------------------------------
function U.Resolve(path, root)
    local t, last = root or Azaath.db, nil
    for key in path:gmatch("[^%.]+") do
        if last then
            if type(t[last]) ~= "table" then
                if root then return nil end
                t[last] = {}
            end
            t = t[last]
        end
        last = key
    end
    return t, last
end

function U.DefaultOf(path)
    local t, k = U.Resolve(path, Azaath.defaults)
    if t then return t[k] end
end

--------------------------------------------------------------------------------
-- Aplicação imediata por módulo
--------------------------------------------------------------------------------
local A = {}
U.Apply = A

local function CallApply(modName, method)
    local mod = Azaath:GetModule(modName)
    method = method or "ApplyLayout"
    if mod and mod[method] then mod[method](mod) end
end
A.Call = CallApply

A.Compass     = function() CallApply("Compass") end
A.Experience  = function() CallApply("Experience") end
A.UnitFrames  = function() CallApply("UnitFrames") end
A.ActionBars  = function() CallApply("ActionBars") end
A.Rotation    = function() local m = Azaath:GetModule("RotationAssist"); if m and m.ApplySettings then m:ApplySettings() end end
A.StancePet   = function() CallApply("StancePetBars") end
A.MicroMenu   = function() CallApply("MicroMenu") end
A.CastBar     = function() CallApply("CastBar") end
A.Auras       = function() CallApply("Auras") end
A.Party       = function() CallApply("PartyFrames") end
A.QuestTracker = function() CallApply("QuestTracker") end
A.Minimap     = function() CallApply("Minimap") end
A.Dialog      = function() CallApply("Dialog") end
A.NpcCamera   = function() CallApply("NpcCamera") end
A.Loot        = function() CallApply("Loot") end
A.LootCelebration = function() CallApply("LootCelebration") end
A.TestCelebration = function()
    local lc = Azaath:GetModule("LootCelebration")
    if lc and lc.Test then lc:Test("showcase") end
end
A.TestLegendary = function()
    local lc = Azaath:GetModule("LootCelebration")
    if lc and lc.Test then lc:Test("legendary") end
end
A.OpenLootJournal = function()
    if Azaath.LootCel and Azaath.LootCel.ToggleJournal then
        Azaath.LootCel.ToggleJournal(true)
    end
end
A.ActionCam   = function() CallApply("ActionCam") end
A.AzaathHUD   = function() CallApply("AzaathHUD") end
A.BDOHUD      = function() CallApply("BDOHUD") end
A.LootBeam    = function() CallApply("LootBeam", "ApplyConfig") end
A.ItemCard    = function() CallApply("ItemCard", "ApplyConfig") end
A.Chat        = function() CallApply("Chat", "RefreshStyle") end
A.Olho        = function() CallApply("OlhoAzaath", "ApplyConfig") end
A.Character   = function() CallApply("Character", "Layout") end

-- posição/escala das notificações: mostra exemplos para ver onde ficam
A.LootFeed = function()
    CallApply("Loot")
    local loot = Azaath:GetModule("Loot")
    if loot and loot.TestFeed and loot.HasFeedEntries and not loot:HasFeedEntries() then
        loot:TestFeed()
    end
end

A.CompassEnabled = function(v)
    local compass = Azaath:GetModule("Compass")
    if compass and compass.SetEnabled then compass:SetEnabled(v) end
end

A.ExperienceEnabled = function(v)
    local xp = Azaath:GetModule("Experience")
    if xp and xp.SetEnabled then xp:SetEnabled(v) else A.Experience() end
end

-- Inventário com/sem personagem. Desligar com a mochila aberta fecha o
-- personagem na hora; ligar vale na próxima vez que abrir.
A.InventoryUnified = function(v)
    local db = Azaath.db.inventory
    if v ~= false then
        db.openMode = "camera"
    elseif db.openMode == "camera" then
        db.openMode = "bags"
    end
    local inv0 = Azaath:GetModule("Inventory")
    if inv0 and inv0.SyncEquipPanel then inv0:SyncEquipPanel() end
    if v ~= false then return end
    local inv, char = Azaath:GetModule("Inventory"), Azaath:GetModule("Character")
    if inv and inv.IsOpen and inv:IsOpen() and char and char.IsOpen and char:IsOpen() then
        char:Close(true)
    end
end

-- Troca de skin ou de barras: cada combinação tem a sua geometria
-- (Core: Azaath.LayoutKey/SwitchLayoutProfile); depois todos se reposicionam.
A.Layout = function()
    if Azaath.EnforceSkinBars then Azaath.EnforceSkinBars() end
    local key = Azaath.LayoutKey and Azaath.LayoutKey()
    local hadProfile = key and Azaath.SwitchLayoutProfile and Azaath.SwitchLayoutProfile(key)
    if not hadProfile then
        local ab = Azaath.db.actionbars
        if ab.bar1 then ab.bar1.customPos = false end
        if ab.bar2 then ab.bar2.customPos = false end
        if ab.bar3 then ab.bar3.customPos = false end
    end
    for _, mod in Azaath:IterateModules() do
        if mod.ApplyLayout then
            local ok, err = pcall(mod.ApplyLayout, mod)
            if not ok and Azaath.LogError then Azaath.LogError("AzaathUI layout " .. tostring(err)) end
        end
    end
end
A.SkinChoice = function() A.Layout(); U.ShowPopup("AZAATHUI_SKIN_RELOAD") end
A.BarChoice  = function() A.Layout(); U.ShowPopup("AZAATHUI_BARS_RELOAD") end

A.MagicPath = function(v)
    local nav = Azaath:GetModule("QuestNav")
    if nav and nav.SetMagicPathEnabled then nav:SetMagicPathEnabled(v) end
end

A.Scale = function() Azaath:ApplyScale() end
A.Shown = function(v) Azaath:SetUIShown(v) end

-- Testes
A.TestCast = function()
    local castbar = Azaath:GetModule("CastBar")
    if castbar and castbar.Test then castbar:Test() end
    local np = Azaath:GetModule("Nameplates")
    if np and np.Test then np:Test() end
end
A.TestPlates = function()
    local np = Azaath:GetModule("Nameplates")
    if np and np.Test then np:Test() end
end
A.OpenPlatesDesigner = function()
    if Azaath.ConfigUI and Azaath.ConfigUI.Hide then Azaath.ConfigUI.Hide() end
    local np = Azaath:GetModule("Nameplates")
    if np and np.OpenDesigner then np:OpenDesigner() end
end
A.SyncPlateStyle = function(v)
    local np = Azaath.NP
    if np and np.db and v and v ~= "blizzard" then
        local map = { auto = "modern", azaath = "azaath", zerker = "bdo", minimal = "bdo_pill" }
        np.ApplyBarStylePreset(map[v] or "modern", false)
    end
    A.Layout()
end
A.SyncPlateSetting = function()
    local np = Azaath.NP
    local cfg = Azaath.db and Azaath.db.nameplates
    if np and np.db and cfg then
        np.db.general.enabled = cfg.enabled ~= false
        np.db.general.utilityNPCs = cfg.utilityNPCs ~= false
        np.db.general.hideWorldNames = cfg.hideWorldNames ~= false
        if cfg.width and cfg.width >= 80 then
            np.db.units.enemynpc.healthWidth = cfg.width
            np.db.units.enemynpc.castWidth = cfg.width + 4
        end
        np.db.cast.enabled = cfg.castBar ~= false
        np.InvalidateUnitProfiles()
        np.RefreshAll()
    end
end
A.TestDamage = function()
    local ct = Azaath:GetModule("CombatText")
    if ct and ct.Test then ct:Test() end
end
A.TestFeed = function()
    local loot = Azaath:GetModule("Loot")
    if loot and loot.TestFeed then loot:TestFeed() end
end
A.TestRolls = function()
    local r = Azaath:GetModule("LootRolls")
    if r and r.Preview then r:Preview() end
end
A.TestBeam = function()
    local beam = Azaath:GetModule("LootBeam")
    if beam and beam.ToggleTest then beam:ToggleTest() end
end

-- Preset de câmera no estilo Black Desert
A.BdoPreset = function()
    local ac = Azaath.db and Azaath.db.actioncam
    if not ac then return end
    ac.enabled, ac.shoulderOffset, ac.shoulderFollowsMouseLook = true, 0.45, false
    ac.dynamicPitch, ac.dynamicPitchStrength, ac.minCameraZoom = true, 0.45, 3
    ac.respectMotionSickness = false
    ac.bdoEnabled, ac.bdoIntensity = true, 0.70
    ac.bdoHitShake, ac.bdoCastFocus, ac.bdoSkillPunch, ac.bdoCritImpact = true, true, true, true
    ac.bdoSpeedZoom, ac.bdoCameraInertia = true, true
    A.ActionCam()
    if U.RefreshVisible then U.RefreshVisible() end
    Azaath:Print(U.L("msg.bdoPreset"))
end

--------------------------------------------------------------------------------
-- Condições
--------------------------------------------------------------------------------
local function IsBDO()    return Azaath.IsBDO and Azaath.IsBDO() end
local function IsAzaath() return Azaath.IsAzaath and Azaath.IsAzaath() end
local function CastStyle(s) return function() return Azaath.db.castbar.player.style == s end end
local function XPFixedWidth() return (Azaath.db.experience.width or 0) > 0 end

--------------------------------------------------------------------------------
-- Diálogos (textos trocados conforme o idioma na hora de mostrar)
--------------------------------------------------------------------------------
local POPUPS = {
    AZAATHUI_SKIN_RELOAD   = { text = "pop.skin",    yes = "pop.reloadNow", no = "pop.later",
                                 accept = function() ReloadUI() end },
    AZAATHUI_BARS_RELOAD   = { text = "pop.bars",    yes = "pop.reloadNow", no = "pop.later",
                                 accept = function() ReloadUI() end },
    AZAATHUI_RESET         = { text = "pop.reset",   yes = "pop.yes", no = "pop.no",
                                 accept = function() Azaath.ResetDB(); ReloadUI() end },
    AZAATHUI_RESET_ELEMENTS = { text = "pop.resetElements", yes = "pop.yes", no = "pop.no",
                                 accept = function() local m = Azaath:GetModule("Config"); if m then m:ResetAllElements() end end },
    AZAATHUI_SECTION_RESET = { text = "pop.section", yes = "pop.yes", no = "pop.no",
                                 accept = function(_, data) if data and data.run then data.run() end end },
}

function U.ShowPopup(name, data, ...)
    local def = POPUPS[name]
    if not (def and StaticPopup_Show) then return end
    local d = StaticPopupDialogs[name] or {}
    StaticPopupDialogs[name] = d
    d.text = U.L(def.text)
    d.button1 = U.L(def.yes)
    d.button2 = U.L(def.no)
    d.OnAccept = def.accept
    d.timeout, d.whileDead, d.hideOnEscape, d.preferredIndex = 0, 1, 1, 3
    local dialog = StaticPopup_Show(name, ...)
    if dialog then dialog.data = data end
    return dialog
end

--------------------------------------------------------------------------------
-- Migração do banco do painel (as opções em si não mudaram de lugar no banco:
-- a reorganização é só visual, então os SavedVariables antigos valem como estão)
--------------------------------------------------------------------------------
local LANGS = { auto = true, ptBR = true, enUS = true }

function U.Migrate()
    local db = Azaath.db
    if not db then return end
    if type(db.config) ~= "table" then db.config = {} end
    local cfg = db.config
    if not LANGS[cfg.lang or ""] then cfg.lang = "auto" end
    local s = tonumber(cfg.scale) or 1
    cfg.scale = s < 0.8 and 0.8 or (s > 1.3 and 1.3 or s)
    if type(cfg.page) ~= "string" then cfg.page = "general" end
    -- A largura fixa da XP agora começa em 200 px (0 continua sendo "automática")
    local xp = db.experience
    if xp and type(xp.width) == "number" and xp.width > 0 and xp.width < 200 then xp.width = 200 end
end

--------------------------------------------------------------------------------
-- Esquema das abas
--------------------------------------------------------------------------------
local ICON = "Interface\\Icons\\"

U.PAGES = {
    ----------------------------------------------------------------------------
    { key = "general", icon = ICON .. "INV_Misc_Gear_01", sections = {
        { key = "sec.language", noReset = true, rows = {
            { t = "choice", path = "config.lang", apply = function() U.Relocalize() end,
              options = { { v = "auto" }, { v = "ptBR" }, { v = "enUS" } } },
        } },
        { key = "sec.setup", noReset = true, rows = {
            { t = "button", key = "btn.setup", primary = true,
              run = function() if U.OpenSetup then U.OpenSetup() end end },
        } },
        { key = "sec.interface", rows = {
            { t = "toggle", path = "enabled", apply = A.Shown },
            { t = "slider", path = "scale", min = 0.6, max = 1.5, step = 0.05, fmt = "%.2fx", apply = A.Scale },
            { t = "slider", path = "config.scale", min = 0.8, max = 1.3, step = 0.05, fmt = "%.2fx",
              apply = function() U.ApplyWindowScale() end },
        } },
        { key = "sec.layout", noReset = true, rows = {
            { t = "note", key = "note.editMode" },
            { t = "button", key = "btn.editMode", primary = true,
              run = function() Azaath:GetModule("Config"):ToggleEditMode() end },
            { t = "button", key = "btn.resetElements",
              run = function() U.ShowPopup("AZAATHUI_RESET_ELEMENTS") end },
        } },
        { key = "sec.maintenance", noReset = true, rows = {
            { t = "button", key = "btn.reload", run = function() ReloadUI() end },
            { t = "button", key = "btn.factoryReset", danger = true,
              run = function() U.ShowPopup("AZAATHUI_RESET") end },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "character", icon = ICON .. "INV_Misc_Head_Human_01", sections = {
        { key = "sec.skin", rows = {
            { t = "choice", path = "skin", reload = true, onChange = A.SkinChoice,
              options = { { v = "modern" }, { v = "azaath" }, { v = "bdo" }, { v = "blizzard" } } },
        } },
        { key = "sec.zerker", when = IsBDO, why = "why.bdo", rows = {
            { t = "slider", path = "bdo.scale", min = 0.5, max = 2.0, step = 0.05, fmt = "%.2fx", apply = A.BDOHUD },
            { t = "slider", path = "bdo.offsetX", min = 0, max = 800, step = 2, fmt = "%d px", apply = A.BDOHUD },
            { t = "slider", path = "bdo.offsetY", min = 0, max = 600, step = 2, fmt = "%d px", apply = A.BDOHUD },
        } },
        { key = "sec.reforged", when = IsAzaath, why = "why.azaath", rows = {
            { t = "slider", path = "azaath.scale", min = 0.5, max = 1.5, step = 0.05, fmt = "%.2fx", apply = A.AzaathHUD },
            { t = "slider", path = "azaath.offsetY", min = -40, max = 400, step = 2, fmt = "%d px", apply = A.AzaathHUD },
            { t = "toggle", path = "azaath.glow", apply = A.AzaathHUD },
        } },
        { key = "sec.player", rows = {
            { t = "toggle", path = "unitframes.player.enabled", reload = true },
            { t = "toggle", path = "unitframes.player.fadeOutOfCombat", apply = A.UnitFrames, needs = "unitframes.player.enabled" },
            { t = "slider", path = "unitframes.player.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.UnitFrames, needs = "unitframes.player.enabled" },
            { t = "slider", path = "unitframes.player.width", min = 160, max = 600, step = 5, fmt = "%d px", apply = A.UnitFrames, needs = "unitframes.player.enabled" },
            { t = "slider", path = "unitframes.player.healthHeight", min = 8, max = 40, step = 1, fmt = "%d px", apply = A.UnitFrames, needs = "unitframes.player.enabled" },
            { t = "slider", path = "unitframes.player.powerHeight", min = 2, max = 20, step = 1, fmt = "%d px", apply = A.UnitFrames, needs = "unitframes.player.enabled" },
            { t = "slider", path = "unitframes.player.healthFont", min = 9, max = 24, step = 1, fmt = "%d pt", apply = A.UnitFrames, needs = "unitframes.player.enabled" },
            { t = "slider", path = "unitframes.player.offsetX", min = -700, max = 700, step = 2, fmt = "%d px", apply = A.UnitFrames, needs = "unitframes.player.enabled" },
            { t = "slider", path = "unitframes.player.offsetY", min = 10, max = 600, step = 2, fmt = "%d px", apply = A.UnitFrames, needs = "unitframes.player.enabled" },
        } },
        { key = "sec.xp", rows = {
            { t = "toggle", path = "experience.enabled", apply = A.ExperienceEnabled },
            { t = "toggle", path = "experience.showAtMax", apply = A.Experience, needs = "experience.enabled" },
            { t = "toggle", key = "experience.autoWidth", needs = "experience.enabled",
              resetPaths = { "experience.width", "experience.offsetX" },
              get = function() return (Azaath.db.experience.width or 0) <= 0 end,
              set = function(v)
                  Azaath.db.experience.width = v and 0 or 1000
                  if v then Azaath.db.experience.offsetX = 0 end
              end,
              apply = A.Experience },
            { t = "slider", path = "experience.width", min = 200, max = 1920, step = 10, fmt = "%d px",
              apply = A.Experience, needs = "experience.enabled", when = XPFixedWidth, why = "why.xpAuto" },
            { t = "slider", path = "experience.height", min = 3, max = 28, step = 1, fmt = "%d px", apply = A.Experience, needs = "experience.enabled" },
            { t = "slider", path = "experience.segments", min = 1, max = 40, step = 1, fmt = "%d", apply = A.Experience, needs = "experience.enabled" },
            { t = "slider", path = "experience.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.Experience, needs = "experience.enabled" },
            { t = "slider", path = "experience.offsetX", min = -800, max = 800, step = 2, fmt = "%d px", apply = A.Experience, needs = "experience.enabled" },
            { t = "slider", path = "experience.offsetY", min = 0, max = 600, step = 1, fmt = "%d px", apply = A.Experience, needs = "experience.enabled" },
        } },
        { key = "sec.badge", needs = "experience.enabled", rows = {
            { t = "toggle", path = "experience.showBadge", apply = A.Experience },
            { t = "slider", path = "experience.badgeSize", min = 18, max = 64, step = 1, fmt = "%d px", apply = A.Experience, needs = "experience.showBadge" },
            { t = "slider", path = "experience.badgeScale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.Experience, needs = "experience.showBadge" },
        } },
        { key = "sec.buffs", rows = {
            { t = "note", key = "note.aurasAzaath" },
            { t = "toggle", path = "auras.playerBuffs.enabled", reload = true },
            { t = "toggle", path = "auras.playerBuffs.weaponEnchants", apply = A.Auras, needs = "auras.playerBuffs.enabled" },
            { t = "slider", path = "auras.playerBuffs.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.Auras, needs = "auras.playerBuffs.enabled" },
            { t = "slider", path = "auras.playerBuffs.size", min = 18, max = 54, step = 1, fmt = "%d px", apply = A.Auras, needs = "auras.playerBuffs.enabled" },
            { t = "slider", path = "auras.playerBuffs.spacing", min = 1, max = 14, step = 1, fmt = "%d px", apply = A.Auras, needs = "auras.playerBuffs.enabled" },
            { t = "slider", path = "auras.playerBuffs.perRow", min = 4, max = 20, step = 1, fmt = "%d", apply = A.Auras, needs = "auras.playerBuffs.enabled" },
        } },
        { key = "sec.debuffs", rows = {
            { t = "toggle", path = "auras.playerDebuffs.enabled", reload = true },
            { t = "slider", path = "auras.playerDebuffs.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.Auras, needs = "auras.playerDebuffs.enabled" },
            { t = "slider", path = "auras.playerDebuffs.size", min = 18, max = 56, step = 1, fmt = "%d px", apply = A.Auras, needs = "auras.playerDebuffs.enabled" },
            { t = "slider", path = "auras.playerDebuffs.spacing", min = 1, max = 14, step = 1, fmt = "%d px", apply = A.Auras, needs = "auras.playerDebuffs.enabled" },
            { t = "slider", path = "auras.playerDebuffs.perRow", min = 4, max = 16, step = 1, fmt = "%d", apply = A.Auras, needs = "auras.playerDebuffs.enabled" },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "actionbars", icon = ICON .. "Ability_DualWield", sections = {
        { key = "sec.barLayout", rows = {
            { t = "choice", path = "actionbars.layout", onChange = A.BarChoice,
              options = { { v = "bdo" }, { v = "split" }, { v = "az" }, { v = "reforged" }, { v = "blizzard" } } },
        } },
        { key = "sec.rotation", rows = {
            { t = "toggle", path = "actionbars.rotation.enabled", apply = A.Rotation },
            { t = "toggle", path = "actionbars.rotation.shout", needs = "actionbars.rotation.enabled" },
            { t = "toggle", path = "actionbars.rotation.sound", needs = "actionbars.rotation.enabled" },
            { t = "toggle", path = "actionbars.rotation.castSfx", needs = "actionbars.rotation.enabled" },
            { t = "toggle", path = "actionbars.rotation.castSounds", needs = "actionbars.rotation.enabled" },
            { t = "slider", path = "actionbars.rotation.volume", min = 1, max = 3, step = 1, fmt = "%dx", needs = "actionbars.rotation.enabled" },
        } },
        { key = "sec.barsGeneral", rows = {
            { t = "toggle", path = "actionbars.enabled", reload = true },
            { t = "toggle", path = "actionbars.showHotkeys", apply = A.ActionBars, needs = "actionbars.enabled" },
            { t = "toggle", path = "actionbars.bagButton", apply = A.ActionBars, needs = "actionbars.enabled" },
            { t = "slider", path = "actionbars.bars", min = 1, max = 3, step = 1, fmt = "%d", apply = A.ActionBars, needs = "actionbars.enabled" },
            { t = "slider", path = "actionbars.spacing", min = 1, max = 14, step = 1, fmt = "%d px", apply = A.ActionBars, needs = "actionbars.enabled" },
            { t = "slider", path = "actionbars.buttonSize", min = 20, max = 64, step = 1, fmt = "%d px", needs = "actionbars.enabled",
              set = function(v)
                  Azaath.db.actionbars.buttonSize = v
                  if Azaath.db.actionbars.bar1 then Azaath.db.actionbars.bar1.buttonSize = 0 end
              end,
              apply = A.ActionBars },
            { t = "slider", path = "actionbars.smallSize", min = 18, max = 56, step = 1, fmt = "%d px", needs = "actionbars.enabled",
              set = function(v)
                  Azaath.db.actionbars.smallSize = v
                  if Azaath.db.actionbars.bar2 then Azaath.db.actionbars.bar2.buttonSize = 0 end
                  if Azaath.db.actionbars.bar3 then Azaath.db.actionbars.bar3.buttonSize = 0 end
              end,
              apply = A.ActionBars },
            { t = "slider", path = "actionbars.offsetX", min = -600, max = 200, step = 2, fmt = "%d px", apply = A.ActionBars, needs = "actionbars.enabled" },
            { t = "slider", path = "actionbars.offsetY", min = 0, max = 300, step = 2, fmt = "%d px", apply = A.ActionBars, needs = "actionbars.enabled" },
        } },
        { key = "sec.barsEach", needs = "actionbars.enabled", rows = {
            { t = "slider", path = "actionbars.bar1.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.ActionBars },
            { t = "slider", path = "actionbars.bar1.cols", min = 0, max = 12, step = 1, fmt = "%d", apply = A.ActionBars },
            { t = "slider", path = "actionbars.bar2.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.ActionBars },
            { t = "slider", path = "actionbars.bar2.cols", min = 0, max = 12, step = 1, fmt = "%d", apply = A.ActionBars },
            { t = "slider", path = "actionbars.bar3.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.ActionBars },
            { t = "slider", path = "actionbars.bar3.cols", min = 0, max = 12, step = 1, fmt = "%d", apply = A.ActionBars },
        } },
        { key = "sec.stancePet", rows = {
            { t = "toggle", path = "actionbars.stance.enabled", reload = true },
            { t = "slider", path = "actionbars.stance.buttonSize", min = 18, max = 52, step = 1, fmt = "%d px", apply = A.StancePet, needs = "actionbars.stance.enabled" },
            { t = "slider", path = "actionbars.stance.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.StancePet, needs = "actionbars.stance.enabled" },
            { t = "toggle", path = "actionbars.pet.enabled", reload = true },
            { t = "slider", path = "actionbars.pet.buttonSize", min = 18, max = 52, step = 1, fmt = "%d px", apply = A.StancePet, needs = "actionbars.pet.enabled" },
            { t = "slider", path = "actionbars.pet.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.StancePet, needs = "actionbars.pet.enabled" },
        } },
        { key = "sec.micromenu", rows = {
            { t = "toggle", path = "micromenu.enabled", apply = A.MicroMenu },
            { t = "choice", path = "micromenu.style", apply = A.MicroMenu, needs = "micromenu.enabled",
              options = { { v = "bdo" }, { v = "azaath" }, { v = "numenor" }, { v = "tabletop" } } },
            { t = "slider", path = "micromenu.buttonSize", min = 14, max = 44, step = 1, fmt = "%d px", apply = A.MicroMenu, needs = "micromenu.enabled" },
            { t = "slider", path = "micromenu.spacing", min = 1, max = 12, step = 1, fmt = "%d px", apply = A.MicroMenu, needs = "micromenu.enabled" },
            { t = "slider", path = "micromenu.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.MicroMenu, needs = "micromenu.enabled" },
            { t = "slider", path = "micromenu.offsetX", min = -800, max = 800, step = 2, fmt = "%d px", apply = A.MicroMenu, needs = "micromenu.enabled" },
            { t = "slider", path = "micromenu.offsetY", min = -400, max = 400, step = 2, fmt = "%d px", apply = A.MicroMenu, needs = "micromenu.enabled" },
            { t = "slider", path = "micromenu.idleAlpha", min = 0.1, max = 1.0, step = 0.05, fmt = "%.2f", apply = A.MicroMenu, needs = "micromenu.enabled" },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "target", icon = ICON .. "Ability_Hunter_SniperShot", sections = {
        { key = "sec.targetFrame", rows = {
            { t = "toggle", path = "unitframes.target.enabled", reload = true },
            { t = "slider", path = "unitframes.target.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.UnitFrames, needs = "unitframes.target.enabled" },
            { t = "slider", path = "unitframes.target.width", min = 160, max = 600, step = 5, fmt = "%d px", apply = A.UnitFrames, needs = "unitframes.target.enabled" },
            { t = "slider", path = "unitframes.target.healthHeight", min = 6, max = 36, step = 1, fmt = "%d px", apply = A.UnitFrames, needs = "unitframes.target.enabled" },
            { t = "slider", path = "unitframes.target.nameFont", min = 10, max = 26, step = 1, fmt = "%d pt", apply = A.UnitFrames, needs = "unitframes.target.enabled" },
            { t = "slider", path = "unitframes.target.offsetX", min = -700, max = 700, step = 2, fmt = "%d px", apply = A.UnitFrames, needs = "unitframes.target.enabled" },
            { t = "slider", path = "unitframes.target.offsetY", neg = true, min = 10, max = 500, step = 2, fmt = "%d px", apply = A.UnitFrames, needs = "unitframes.target.enabled" },
        } },
        { key = "sec.targetAuras", rows = {
            { t = "toggle", path = "auras.target.enabled", reload = true },
            { t = "toggle", path = "auras.target.onlyMine", apply = A.Auras, needs = "auras.target.enabled" },
            { t = "slider", path = "auras.target.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.Auras, needs = "auras.target.enabled" },
            { t = "slider", path = "auras.target.size", min = 16, max = 48, step = 1, fmt = "%d px", apply = A.Auras, needs = "auras.target.enabled" },
            { t = "slider", path = "auras.target.spacing", min = 1, max = 14, step = 1, fmt = "%d px", apply = A.Auras, needs = "auras.target.enabled" },
        } },
        { key = "sec.nameplates", rows = {
            { t = "toggle", path = "nameplates.enabled", apply = A.SyncPlateSetting, reload = true },
            { t = "choice", path = "nameplates.style", apply = A.SyncPlateStyle, needs = "nameplates.enabled",
              options = { { v = "auto" }, { v = "azaath" }, { v = "zerker" }, { v = "minimal" }, { v = "blizzard" } } },
            { t = "toggle", path = "nameplates.castBar", apply = A.SyncPlateSetting, needs = "nameplates.enabled" },
            { t = "toggle", path = "nameplates.utilityNPCs", apply = A.SyncPlateSetting, needs = "nameplates.enabled" },
            { t = "toggle", path = "nameplates.hideWorldNames", apply = A.SyncPlateSetting, needs = "nameplates.enabled" },
            { t = "slider", path = "nameplates.width", min = 100, max = 260, step = 5, fmt = "%d px", apply = A.SyncPlateSetting, needs = "nameplates.enabled" },
            { t = "button", key = "btn.openPlatesDesigner", run = A.OpenPlatesDesigner, needs = "nameplates.enabled" },
            { t = "button", key = "btn.testPlates", run = A.TestPlates, needs = "nameplates.enabled" },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "combat", icon = ICON .. "Spell_Fire_FlameBolt", sections = {
        { key = "sec.castPlayer", rows = {
            { t = "toggle", path = "castbar.player.enabled", reload = true },
            { t = "choice", path = "castbar.player.style", reload = true, needs = "castbar.player.enabled",
              options = { { v = "ring" }, { v = "bar" } } },
            { t = "toggle", path = "castbar.player.effects", apply = A.CastBar, needs = "castbar.player.enabled" },
            { t = "slider", path = "castbar.player.ringSize", min = 32, max = 200, step = 2, fmt = "%d px", apply = A.CastBar,
              needs = "castbar.player.enabled", when = CastStyle("ring"), why = "why.ring" },
            { t = "toggle", path = "castbar.player.showLatency", apply = A.CastBar,
              needs = "castbar.player.enabled", when = CastStyle("bar"), why = "why.bar" },
            { t = "slider", path = "castbar.player.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.CastBar, needs = "castbar.player.enabled" },
            { t = "slider", path = "castbar.player.width", min = 120, max = 600, step = 5, fmt = "%d px", apply = A.CastBar,
              needs = "castbar.player.enabled", when = CastStyle("bar"), why = "why.bar" },
            { t = "slider", path = "castbar.player.height", min = 6, max = 36, step = 1, fmt = "%d px", apply = A.CastBar,
              needs = "castbar.player.enabled", when = CastStyle("bar"), why = "why.bar" },
            { t = "slider", path = "castbar.player.offsetX", min = -600, max = 600, step = 2, fmt = "%d px", apply = A.CastBar, needs = "castbar.player.enabled" },
            { t = "slider", path = "castbar.player.offsetY", min = -200, max = 400, step = 2, fmt = "%d px", apply = A.CastBar, needs = "castbar.player.enabled" },
            { t = "button", key = "btn.testCast", run = A.TestCast },
        } },
        { key = "sec.castWorld", rows = {
            { t = "toggle", path = "castbar.world.enabled", apply = A.CastBar },
            { t = "slider", path = "castbar.world.size", min = 28, max = 120, step = 2, fmt = "%d px", apply = A.CastBar, needs = "castbar.world.enabled" },
            { t = "slider", path = "castbar.world.plateOffsetY", min = -120, max = 40, step = 2, fmt = "%d px", apply = A.CastBar, needs = "castbar.world.enabled" },
        } },
        { key = "sec.castTarget", rows = {
            { t = "toggle", path = "castbar.target.enabled", reload = true },
            { t = "slider", path = "castbar.target.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.CastBar, needs = "castbar.target.enabled" },
            { t = "slider", path = "castbar.target.width", min = 120, max = 600, step = 5, fmt = "%d px", apply = A.CastBar, needs = "castbar.target.enabled" },
            { t = "slider", path = "castbar.target.height", min = 6, max = 32, step = 1, fmt = "%d px", apply = A.CastBar, needs = "castbar.target.enabled" },
            { t = "slider", path = "castbar.target.offsetX", min = -600, max = 600, step = 2, fmt = "%d px", apply = A.CastBar, needs = "castbar.target.enabled" },
            { t = "slider", path = "castbar.target.offsetY", min = -400, max = 200, step = 2, fmt = "%d px", apply = A.CastBar, needs = "castbar.target.enabled" },
        } },
        { key = "sec.combatText", rows = {
            { t = "toggle", path = "combattext.enabled" },
            { t = "toggle", path = "combattext.hideBlizzard", reload = true },
            { t = "toggle", path = "combattext.showIcons", needs = "combattext.enabled" },
            { t = "toggle", path = "combattext.onlyMine", needs = "combattext.enabled" },
            { t = "toggle", path = "combattext.showPet", needs = "combattext.enabled" },
            { t = "toggle", path = "combattext.showPeriodic", needs = "combattext.enabled" },
            { t = "toggle", path = "combattext.showMiss", needs = "combattext.enabled" },
            { t = "slider", path = "combattext.normalSize", min = 24, max = 46, step = 1, fmt = "%d pt", needs = "combattext.enabled" },
            { t = "slider", path = "combattext.critSize", min = 24, max = 58, step = 1, fmt = "%d pt", needs = "combattext.enabled" },
            { t = "slider", path = "combattext.offsetX", min = 20, max = 160, step = 5, fmt = "%d px", needs = "combattext.enabled" },
            { t = "slider", path = "combattext.duration", min = 0.6, max = 2.5, step = 0.05, fmt = "%.2f s", needs = "combattext.enabled" },
            { t = "slider", path = "combattext.floatDistance", min = 20, max = 100, step = 5, fmt = "%d px", needs = "combattext.enabled" },
            { t = "slider", path = "combattext.scale", min = 0.6, max = 2.0, step = 0.05, fmt = "%.2fx", needs = "combattext.enabled" },
            { t = "button", key = "btn.testDamage", run = A.TestDamage, needs = "combattext.enabled" },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "party", icon = ICON .. "Spell_Holy_PrayerOfHealing02", sections = {
        { key = "sec.party", rows = {
            { t = "note", key = "note.party" },
            { t = "toggle", path = "party.enabled", reload = true },
            { t = "toggle", path = "party.classColor", apply = A.Party, needs = "party.enabled" },
            { t = "toggle", path = "party.showInRaid", apply = A.Party, needs = "party.enabled" },
            { t = "slider", path = "party.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.Party, needs = "party.enabled" },
            { t = "slider", path = "party.width", min = 100, max = 340, step = 5, fmt = "%d px", apply = A.Party, needs = "party.enabled" },
            { t = "slider", path = "party.barHeight", min = 3, max = 20, step = 1, fmt = "%d px", apply = A.Party, needs = "party.enabled" },
            { t = "slider", path = "party.spacing", min = 24, max = 80, step = 1, fmt = "%d px", apply = A.Party, needs = "party.enabled" },
            { t = "slider", path = "party.offsetX", min = 0, max = 600, step = 2, fmt = "%d px", apply = A.Party, needs = "party.enabled" },
            { t = "slider", path = "party.offsetY", neg = true, min = 0, max = 600, step = 2, fmt = "%d px", apply = A.Party, needs = "party.enabled" },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "map", icon = ICON .. "INV_Misc_Map_01", sections = {
        { key = "sec.compass", rows = {
            { t = "toggle", path = "compass.enabled", apply = A.CompassEnabled },
            { t = "toggle", path = "compass.showZone", apply = A.Compass, needs = "compass.enabled" },
            { t = "toggle", path = "compass.showDegrees", apply = A.Compass, needs = "compass.enabled" },
            { t = "slider", path = "compass.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.Compass, needs = "compass.enabled" },
            { t = "slider", path = "compass.width", min = 200, max = 1200, step = 10, fmt = "%d px", apply = A.Compass, needs = "compass.enabled" },
            { t = "slider", path = "compass.height", min = 18, max = 60, step = 1, fmt = "%d px", apply = A.Compass, needs = "compass.enabled" },
            { t = "slider", path = "compass.fov", min = 90, max = 360, step = 15, fmt = "%d°", apply = A.Compass, needs = "compass.enabled" },
            { t = "slider", path = "compass.offsetX", min = -600, max = 600, step = 2, fmt = "%d px", apply = A.Compass, needs = "compass.enabled" },
            { t = "slider", path = "compass.offsetY", neg = true, min = 0, max = 300, step = 2, fmt = "%d px", apply = A.Compass, needs = "compass.enabled" },
        } },
        { key = "sec.minimap", rows = {
            { t = "toggle", path = "minimap.enabled", reload = true },
            { t = "toggle", key = "minimap.square", resetPaths = { "minimap.shape" }, needs = "minimap.enabled",
              get = function() return Azaath.db.minimap.shape == "square" end,
              set = function(v) Azaath.db.minimap.shape = v and "square" or "round" end,
              apply = A.Minimap },
            { t = "toggle", path = "minimap.showCoords", apply = A.Minimap, needs = "minimap.enabled" },
            { t = "toggle", path = "minimap.showClock", apply = A.Minimap, needs = "minimap.enabled" },
            { t = "slider", path = "minimap.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.Minimap, needs = "minimap.enabled" },
            { t = "slider", path = "minimap.size", min = 100, max = 320, step = 2, fmt = "%d px", apply = A.Minimap, needs = "minimap.enabled" },
            { t = "slider", path = "minimap.offsetX", min = -600, max = 50, step = 2, fmt = "%d px", apply = A.Minimap, needs = "minimap.enabled" },
            { t = "slider", path = "minimap.offsetY", min = -600, max = 50, step = 2, fmt = "%d px", apply = A.Minimap, needs = "minimap.enabled" },
        } },
        { key = "sec.worldmap", rows = {
            { t = "toggle", path = "worldmap.enabled", reload = true },
            { t = "note", key = "note.worldmap" },
        } },
        { key = "sec.questNav", rows = {
            { t = "toggle", path = "questnav.worldMarker", needs = "questnav.enabled" },
            { t = "toggle", path = "questnav.compassPin", needs = "questnav.enabled" },
            { t = "toggle", path = "questnav.magicPath", needs = "questnav.enabled",
              set = function(v) Azaath.db.questnav.magicPath = v and true or false end, apply = A.MagicPath },
            { t = "toggle", path = "questroute.autoAdvance" },
            { t = "toggle", path = "questroute.autoQuest" },
        } },
        { key = "sec.questTracker", rows = {
            { t = "note", key = "note.questTracker" },
            { t = "toggle", path = "questtracker.enabled", reload = true },
            { t = "toggle", path = "questtracker.showAchievements", apply = A.QuestTracker, needs = "questtracker.enabled" },
            { t = "toggle", path = "questtracker.customPos", apply = A.QuestTracker, needs = "questtracker.enabled" },
            { t = "toggle", path = "questtracker.transparentBg", apply = A.QuestTracker, needs = "questtracker.enabled" },
            { t = "slider", path = "questtracker.scale", min = 0.5, max = 2.5, step = 0.05, fmt = "%.2fx", apply = A.QuestTracker, needs = "questtracker.enabled" },
            { t = "slider", path = "questtracker.width", min = 180, max = 450, step = 5, fmt = "%d px", apply = A.QuestTracker, needs = "questtracker.enabled" },
            { t = "slider", path = "questtracker.maxHeight", min = 120, max = 700, step = 10, fmt = "%d px", apply = A.QuestTracker, needs = "questtracker.enabled" },
            { t = "slider", path = "questtracker.offsetX", min = -600, max = 100, step = 2, fmt = "%d px", apply = A.QuestTracker, needs = "questtracker.customPos" },
            { t = "slider", path = "questtracker.offsetY", neg = true, min = 0, max = 600, step = 5, fmt = "%d px", apply = A.QuestTracker, needs = "questtracker.customPos" },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "loot", icon = ICON .. "INV_Misc_Coin_02", sections = {
        { key = "sec.lootWindow", rows = {
            { t = "toggle", path = "loot.enabled", reload = true },
            { t = "toggle", path = "loot.autoLoot", needs = "loot.enabled" },
            { t = "toggle", path = "loot.showWhenFull", needs = "loot.autoLoot" },
            { t = "slider", path = "loot.scale", min = 0.6, max = 2.0, step = 0.05, fmt = "%.2fx", apply = A.Loot, needs = "loot.enabled" },
            { t = "slider", path = "loot.width", min = 240, max = 500, step = 10, fmt = "%d px", apply = A.Loot, needs = "loot.enabled" },
            { t = "slider", path = "loot.offsetX", min = -600, max = 600, step = 5, fmt = "%d px", apply = A.Loot, needs = "loot.enabled" },
            { t = "slider", path = "loot.offsetY", min = -400, max = 400, step = 5, fmt = "%d px", apply = A.Loot, needs = "loot.enabled" },
        } },
        { key = "sec.lootFeed", rows = {
            { t = "toggle", path = "loot.feed" },
            { t = "slider", path = "loot.feedDuration", min = 2, max = 15, step = 0.5, fmt = "%.1f s", needs = "loot.feed" },
            { t = "slider", path = "loot.feedMax", min = 2, max = 12, step = 1, fmt = "%d", needs = "loot.feed" },
            { t = "slider", path = "loot.feedScale", min = 0.6, max = 2.0, step = 0.05, fmt = "%.2fx", apply = A.LootFeed, needs = "loot.feed" },
            { t = "slider", path = "loot.feedX", min = -900, max = 900, step = 5, fmt = "%d px", apply = A.LootFeed, needs = "loot.feed" },
            { t = "slider", path = "loot.feedY", min = -500, max = 500, step = 5, fmt = "%d px", apply = A.LootFeed, needs = "loot.feed" },
            { t = "button", key = "btn.testFeed", run = A.TestFeed, needs = "loot.feed" },
        } },
        { key = "sec.lootRolls", rows = {
            { t = "toggle", path = "lootRolls.enabled" },
            { t = "button", key = "btn.testRolls", run = A.TestRolls, needs = "lootRolls.enabled" },
        } },
        { key = "sec.lootBeam", rows = {
            { t = "toggle", path = "lootBeam.enabled", apply = A.LootBeam },
            { t = "toggle", path = "lootBeam.showOnUnopened", needs = "lootBeam.enabled" },
            { t = "toggle", path = "lootBeam.rarityBurst", needs = "lootBeam.enabled" },
            { t = "toggle", path = "lootBeam.persistRarity", needs = "lootBeam.enabled" },
            { t = "toggle", path = "lootBeam.multiCorpse", needs = "lootBeam.enabled" },
            { t = "slider", path = "lootBeam.beamHeight", min = 80, max = 260, step = 5, fmt = "%d px", apply = A.LootBeam, needs = "lootBeam.enabled" },
            { t = "slider", path = "lootBeam.beamWidth", min = 16, max = 80, step = 2, fmt = "%d px", apply = A.LootBeam, needs = "lootBeam.enabled" },
            { t = "slider", path = "lootBeam.groundFactor", min = 30, max = 250, step = 5, fmt = "%d%%", apply = A.LootBeam, needs = "lootBeam.enabled" },
            { t = "slider", path = "lootBeam.offsetY", min = -40, max = 30, step = 1, fmt = "%d px", apply = A.LootBeam, needs = "lootBeam.enabled" },
            { t = "button", key = "btn.testBeam", run = A.TestBeam, needs = "lootBeam.enabled" },
        } },
        { key = "sec.lootCelebration", rows = {
            { t = "toggle", path = "lootCelebration.enabled", apply = A.LootCelebration },
            { t = "toggle", path = "lootCelebration.sound", needs = "lootCelebration.enabled" },
            { t = "toggle", path = "lootCelebration.edgeGlow", needs = "lootCelebration.enabled" },
            { t = "choice", path = "lootCelebration.glowIntensity", options = { { v = "normal" }, { v = "soft" } }, needs = "lootCelebration.edgeGlow" },
            { t = "toggle", path = "lootCelebration.borderPulse", apply = A.LootCelebration, needs = "lootCelebration.enabled" },
            { t = "toggle", path = "lootCelebration.greenBoE", needs = "lootCelebration.enabled" },
            { t = "toggle", path = "lootCelebration.quietFishing", needs = "lootCelebration.enabled" },
            { t = "toggle", path = "lootCelebration.milestones", needs = "lootCelebration.enabled" },
            { t = "toggle", path = "lootCelebration.rareKills", needs = "lootCelebration.enabled" },
            { t = "toggle", path = "lootCelebration.showVendor", needs = "lootCelebration.enabled" },
            { t = "toggle", path = "lootCelebration.showAH", needs = "lootCelebration.enabled" },
            { t = "toggle", path = "lootCelebration.movableAlerts", apply = A.LootCelebration, needs = "lootCelebration.enabled" },
            { t = "slider", path = "lootCelebration.durationScale", min = 0.5, max = 2.0, step = 0.1, fmt = "%.1fx", needs = "lootCelebration.enabled" },
            { t = "slider", path = "lootCelebration.scale", min = 0.6, max = 1.6, step = 0.05, fmt = "%.2fx", apply = A.LootCelebration, needs = "lootCelebration.enabled" },
            { t = "slider", path = "lootCelebration.offsetX", min = -700, max = 700, step = 10, fmt = "%d px", apply = A.LootCelebration, needs = "lootCelebration.enabled" },
            { t = "slider", path = "lootCelebration.offsetY", min = -450, max = 450, step = 10, fmt = "%d px", apply = A.LootCelebration, needs = "lootCelebration.enabled" },
            { t = "button", key = "btn.testCelebration", run = A.TestCelebration, needs = "lootCelebration.enabled" },
            { t = "button", key = "btn.testLegendary", run = A.TestLegendary, needs = "lootCelebration.enabled" },
            { t = "button", key = "btn.openLootJournal", run = A.OpenLootJournal },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "npc", icon = ICON .. "INV_Misc_Note_01", sections = {
        { key = "sec.dialog", rows = {
            { t = "toggle", path = "dialog.enabled", reload = true },
            { t = "toggle", path = "dialog.numberKeys", needs = "dialog.enabled" },
            { t = "toggle", path = "dialog.interactKey", apply = A.Dialog, needs = "dialog.enabled" },
            { t = "slider", path = "dialog.scale", min = 0.6, max = 2.0, step = 0.05, fmt = "%.2fx", apply = A.Dialog, needs = "dialog.enabled" },
            { t = "slider", path = "dialog.width", min = 400, max = 800, step = 10, fmt = "%d px", apply = A.Dialog, needs = "dialog.enabled" },
            { t = "slider", path = "dialog.offsetX", min = -600, max = 100, step = 5, fmt = "%d px", apply = A.Dialog, needs = "dialog.enabled" },
            { t = "slider", path = "dialog.offsetY", min = -300, max = 300, step = 5, fmt = "%d px", apply = A.Dialog, needs = "dialog.enabled" },
        } },
        { key = "sec.npcCamera", rows = {
            { t = "toggle", path = "npcCamera.enabled", apply = A.NpcCamera },
            { t = "toggle", path = "npcCamera.questAndGossip", needs = "npcCamera.enabled" },
            { t = "toggle", path = "npcCamera.otherNPCs", needs = "npcCamera.enabled" },
            { t = "slider", path = "npcCamera.zoomDistance", min = 2.5, max = 12.0, step = 0.5, fmt = "%.1f m", needs = "npcCamera.enabled" },
            { t = "slider", path = "npcCamera.shoulderOffset", min = -3.0, max = 3.0, step = 0.05, fmt = "%.2f", needs = "npcCamera.enabled" },
            { t = "slider", path = "npcCamera.focusStrength", min = 0.0, max = 1.0, step = 0.05, fmt = "%.2f", needs = "npcCamera.enabled" },
            { t = "toggle", path = "npcCamera.dynamicPitch", needs = "npcCamera.enabled" },
            { t = "toggle", path = "npcCamera.fovZoom", needs = "npcCamera.enabled" },
            { t = "slider", path = "npcCamera.fovTarget", min = 65, max = 90, step = 1, fmt = "%d°", needs = "npcCamera.fovZoom" },
            { t = "toggle", path = "npcCamera.subtlePan", needs = "npcCamera.enabled" },
            { t = "toggle", path = "npcCamera.vignette", needs = "npcCamera.enabled" },
            { t = "toggle", path = "npcCamera.disableInCombat", needs = "npcCamera.enabled" },
            { t = "toggle", path = "npcCamera.disableInInstances", needs = "npcCamera.enabled" },
        } },
        { key = "sec.merchant", rows = {
            { t = "toggle", path = "merchant.enabled", reload = true },
            { t = "toggle", path = "merchant.autoRepair" },
            { t = "toggle", path = "merchant.guildRepair", needs = "merchant.autoRepair" },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "auction", icon = ICON .. "INV_Misc_Coin_01", sections = {
        { key = "sec.auction", rows = {
            { t = "toggle", path = "auction.autoScan" },
            { t = "toggle", path = "auction.cardPrice" },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "inventory", icon = ICON .. "INV_Misc_Bag_08", sections = {
        { key = "sec.inventory", rows = {
            { t = "toggle", path = "inventory.enabled", reload = true },
            { t = "choice", path = "inventory.style", reload = true, needs = "inventory.enabled",
              options = { { v = "classic" }, { v = "azaath" } } },
            { t = "choice", path = "inventory.viewMode", reload = true, needs = "inventory.enabled",
              options = { { v = "az" }, { v = "bags" } } },
            { t = "toggle", path = "inventory.showItemLevel", reload = true, needs = "inventory.enabled" },
            { t = "slider", path = "inventory.columns", min = 6, max = 14, step = 1, fmt = "%d", reload = true, needs = "inventory.enabled" },
        } },
        { key = "sec.charView", rows = {
            { t = "toggle", path = "character.enabled", reload = true },
            { t = "choice", path = "inventory.openMode", resetPaths = { "inventory.openMode", "inventory.unified" },
              apply = function(v)
                  Azaath.db.inventory.openMode = v
                  Azaath.db.inventory.unified = (v == "camera")
                  A.InventoryUnified(v == "camera")
              end,
              options = { { v = "camera" }, { v = "panel" }, { v = "bags" } } },
            { t = "toggle", path = "inventory.keepOnMove", needs = "inventory.unified" },
            { t = "toggle", path = "inventory.cameraLock", needs = "inventory.unified" },
            { t = "slider", path = "inventory.cameraDistance", min = 2, max = 10, step = 0.5, fmt = "%.1f", needs = "inventory.cameraLock" },
            { t = "slider", path = "character.offsetY", min = -200, max = 200, step = 5, fmt = "%d px", apply = A.Character, needs = "character.enabled" },
            { t = "toggle", path = "character.hideHUD", needs = "character.enabled" },
        } },
        { key = "sec.windows", rows = {
            { t = "toggle", path = "sheet.enabled", reload = true },
            { t = "toggle", path = "talents.enabled", reload = true },
            { t = "toggle", path = "spellbook.enabled", reload = true },
            { t = "toggle", path = "professions.enabled", reload = true },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "chat", icon = ICON .. "INV_Scroll_08", sections = {
        { key = "sec.chat", rows = {
            { t = "toggle", path = "chat.enabled", reload = true },
            { t = "toggle", path = "chat.backdrop", reload = true, needs = "chat.enabled" },
            { t = "toggle", path = "chat.cleanTabs", reload = true, needs = "chat.enabled" },
            { t = "toggle", path = "chat.cleanEditBox", reload = true, needs = "chat.enabled" },
            { t = "toggle", path = "chat.hideButtons", reload = true, needs = "chat.enabled" },
            { t = "toggle", path = "chat.mouseScroll", reload = true, needs = "chat.enabled" },
        } },
        { key = "sec.chatLook", needs = "chat.enabled", rows = {
            { t = "slider", path = "chat.activeAlpha", min = 0.40, max = 1.0, step = 0.05, fmt = "%.2f", apply = A.Chat },
            { t = "slider", path = "chat.idleAlpha", min = 0.0, max = 0.80, step = 0.05, fmt = "%.2f", apply = A.Chat },
            { t = "slider", path = "chat.fontSize", min = 10, max = 20, step = 1, fmt = "%d pt", apply = A.Chat },
            { t = "toggle", key = "chat.bold", resetPaths = { "chat.fontStyle" },
              get = function() return Azaath.db.chat and Azaath.db.chat.fontStyle == "bold" end,
              set = function(v) if Azaath.db.chat then Azaath.db.chat.fontStyle = v and "bold" or "ptsans" end end,
              apply = A.Chat },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "actioncam", icon = ICON .. "Ability_EyeOfTheOwl", sections = {
        { key = "sec.acMain", rows = {
            { t = "note", key = "note.actioncam" },
            { t = "toggle", path = "actioncam.enabled", apply = A.ActionCam },
        } },
        { key = "sec.acCamera", needs = "actioncam.enabled", rows = {
            { t = "slider", path = "actioncam.mouseLookSpeed", min = 20, max = 200, step = 5, fmt = "%d%%", apply = A.ActionCam },
            { t = "slider", path = "actioncam.shoulderOffset", min = -3.0, max = 3.0, step = 0.1, fmt = "%.1f", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.shoulderFollowsMouseLook", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.shoulderZoomScale", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.situations", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.situationZoomMemory", apply = A.ActionCam, needs = "actioncam.situations" },
            { t = "toggle", path = "actioncam.dynamicPitch", apply = A.ActionCam },
            { t = "slider", path = "actioncam.dynamicPitchStrength", min = 0.0, max = 1.0, step = 0.05, fmt = "%.2f", apply = A.ActionCam, needs = "actioncam.dynamicPitch" },
            { t = "slider", path = "actioncam.minCameraZoom", min = 0, max = 15, step = 1, fmt = "%d m", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.autofocusLockedTarget", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.respectMotionSickness", apply = A.ActionCam },
            { t = "choice", path = "actioncam.vignetteConditions", apply = A.ActionCam,
              options = { { v = "mouselook" }, { v = "combat" }, { v = "mouselook,combat" }, { v = "" } } },
        } },
        { key = "sec.acCursor", needs = "actioncam.enabled", rows = {
            { t = "toggle", path = "actioncam.frameWatching", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.ctrlToggle", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.closeWindowsOnMouseLook", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.pulseCursor", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.hideTooltip", apply = A.ActionCam },
            { t = "choice", path = "actioncam.tooltipModifier", apply = A.ActionCam, needs = "actioncam.hideTooltip",
              options = { { v = "ALT" }, { v = "CTRL" }, { v = "SHIFT" } } },
            { t = "toggle", path = "actioncam.sheathWeaponsWithMouselook", apply = A.ActionCam },
        } },
        { key = "sec.acCrosshair", needs = "actioncam.enabled", rows = {
            { t = "toggle", path = "actioncam.crosshair", apply = A.ActionCam },
            { t = "choice", path = "actioncam.crosshairStyle", apply = A.ActionCam, needs = "actioncam.crosshair",
              options = { { v = "diamond" }, { v = "ring" }, { v = "dot" }, { v = "cross" }, { v = "star" } } },
            { t = "slider", path = "actioncam.crosshairScale", min = 0.5, max = 2.0, step = 0.05, fmt = "%.2fx", apply = A.ActionCam, needs = "actioncam.crosshair" },
            { t = "slider", path = "actioncam.crosshairY", min = -200, max = 300, step = 5, fmt = "%d px", apply = A.ActionCam, needs = "actioncam.crosshair" },
            { t = "toggle", path = "actioncam.crosshairCastFeedback", apply = A.ActionCam, needs = "actioncam.crosshair" },
            { t = "toggle", path = "actioncam.interactionHUD", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.interactionHUDPlayers", apply = A.ActionCam, needs = "actioncam.interactionHUD" },
            { t = "toggle", path = "actioncam.crosshairTargetPreview", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.showTargetLockMarker", apply = A.ActionCam },
        } },
        { key = "sec.acTargeting", needs = "actioncam.enabled", rows = {
            { t = "toggle", path = "actioncam.reticleTargeting", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.reticleOutline", apply = A.ActionCam },
            { t = "choice", path = "actioncam.selectionCircleMode", apply = A.ActionCam,
              options = { { v = "target" }, { v = "soft" }, { v = "hidden" } } },
            { t = "toggle", path = "actioncam.autoTargetLockOnAttack", apply = A.ActionCam },
            { t = "choice", path = "actioncam.targetLockBehavior", apply = A.ActionCam,
              options = { { v = "toggle" }, { v = "switch" } } },
        } },
        { key = "sec.acClick", needs = "actioncam.enabled", rows = {
            { t = "choice", path = "actioncam.bindings.button1.value", apply = A.ActionCam,
              options = { { v = "ACTIONBUTTON1" }, { v = "STARTATTACK" }, { v = "TARGETMOUSEOVER" } } },
            { t = "choice", path = "actioncam.bindings.button2.value", apply = A.ActionCam,
              options = { { v = "ACTIONBUTTON2" }, { v = "INTERACTMOUSEOVER" }, { v = "CLEARTARGET" } } },
            { t = "choice", path = "actioncam.bindings.shiftbutton1.value", apply = A.ActionCam,
              options = { { v = "ACTIONBUTTON3" }, { v = "ACTIONBUTTON7" }, { v = "" } } },
            { t = "choice", path = "actioncam.bindings.shiftbutton2.value", apply = A.ActionCam,
              options = { { v = "ACTIONBUTTON4" }, { v = "ACTIONBUTTON8" }, { v = "" } } },
        } },
        { key = "sec.acAlly", needs = "actioncam.enabled", rows = {
            { t = "toggle", path = "actioncam.allyCycle.showHud", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.allyCycle.skipPlayer", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.supportModeTintVignette", apply = A.ActionCam },
        } },
        { key = "sec.acBdo", needs = "actioncam.enabled", rows = {
            { t = "button", key = "btn.bdoPreset", primary = true, run = A.BdoPreset },
            { t = "toggle", path = "actioncam.bdoEnabled", apply = A.ActionCam },
            { t = "slider", path = "actioncam.bdoIntensity", min = 0.0, max = 1.0, step = 0.05, fmt = "%.2f", apply = A.ActionCam, needs = "actioncam.bdoEnabled" },
            { t = "toggle", path = "actioncam.bdoHitShake", apply = A.ActionCam, needs = "actioncam.bdoEnabled" },
            { t = "toggle", path = "actioncam.bdoCastFocus", apply = A.ActionCam, needs = "actioncam.bdoEnabled" },
            { t = "toggle", path = "actioncam.bdoSkillPunch", apply = A.ActionCam, needs = "actioncam.bdoEnabled" },
            { t = "toggle", path = "actioncam.bdoCritImpact", apply = A.ActionCam, needs = "actioncam.bdoEnabled" },
            { t = "toggle", path = "actioncam.bdoMoves", apply = A.ActionCam, needs = "actioncam.bdoEnabled" },
            { t = "toggle", path = "actioncam.bdoHurtShake", apply = A.ActionCam, needs = "actioncam.bdoEnabled" },
            { t = "toggle", path = "actioncam.bdoCritSound", apply = A.ActionCam, needs = "actioncam.bdoEnabled" },
            { t = "choice", path = "actioncam.bdoCritSoundStyle", apply = A.ActionCam, needs = "actioncam.bdoCritSound",
              options = { { v = "impact" }, { v = "ping" }, { v = "drum" }, { v = "thunder" } } },
            { t = "toggle", path = "actioncam.bdoSpeedZoom", apply = A.ActionCam, needs = "actioncam.bdoEnabled" },
            { t = "toggle", path = "actioncam.bdoCameraInertia", apply = A.ActionCam, needs = "actioncam.bdoEnabled" },
            { t = "toggle", path = "actioncam.bdoCombatZoomOut", apply = A.ActionCam, needs = "actioncam.bdoEnabled" },
        } },
        { key = "sec.acRadial", needs = "actioncam.enabled", rows = {
            { t = "toggle", path = "actioncam.radialEnabled", apply = A.ActionCam },
            { t = "toggle", path = "actioncam.radialBackdrop", apply = A.ActionCam, needs = "actioncam.radialEnabled" },
            { t = "toggle", path = "actioncam.soundRadialMenu", apply = A.ActionCam, needs = "actioncam.radialEnabled" },
            { t = "button", key = "btn.radialConsumables", needs = "actioncam.radialEnabled",
              run = function()
                  if Azaath.ActionCam and Azaath.ActionCam.OpenRadialConsumablesEditor then
                      Azaath.ActionCam.OpenRadialConsumablesEditor()
                  end
              end },
            { t = "button", key = "btn.radialSpells", needs = "actioncam.radialEnabled",
              run = function()
                  if Azaath.ActionCam and Azaath.ActionCam.OpenRadialConsumablesEditor then
                      Azaath.ActionCam.OpenRadialConsumablesEditor("spells")
                  end
              end },
        } },
        { key = "sec.acMaint", noReset = true, rows = {
            { t = "button", key = "btn.acReset", danger = true,
              run = function()
                  if Azaath.ActionCam and Azaath.ActionCam.ResetAllToDefaults then
                      Azaath.ActionCam.ResetAllToDefaults()
                      if U.RefreshVisible then U.RefreshVisible() end
                  end
              end },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "olho", icon = ICON .. "Spell_Holy_MindVision", sections = {
        { key = "sec.olho", rows = {
            { t = "button", key = "btn.olhoStudio", primary = true,
              run = function()
                  local m = Azaath:GetModule("OlhoAzaath")
                  if m and m.OpenMenu then m:OpenMenu() end
              end },
            { t = "toggle", path = "olho.enabled", apply = A.Olho },
            { t = "slider", path = "olho.range", min = 5, max = 15, step = 1, fmt = "%d m", apply = A.Olho, needs = "olho.enabled" },
            { t = "choice", path = "olho.arc", apply = A.Olho, needs = "olho.enabled",
              options = { { v = 0 }, { v = 1 }, { v = 2 } } },
            { t = "toggle", path = "olho.glowOnly", apply = A.Olho, needs = "olho.enabled" },
            { t = "toggle", path = "olho.exclusive", apply = A.Olho, needs = "olho.enabled" },
            { t = "toggle", path = "olho.silhouette", apply = A.Olho, needs = "olho.enabled" },
            { t = "toggle", path = "olho.hideInCombat", apply = A.Olho, needs = "olho.enabled" },
            { t = "toggle", path = "olho.hideInInstance", apply = A.Olho, needs = "olho.enabled" },
        } },
    } },
    ----------------------------------------------------------------------------
    { key = "advanced", icon = ICON .. "Trade_Engineering", sections = {
        { key = "sec.blizzard", rows = {
            { t = "note", key = "note.blizzard" },
            { t = "toggle", path = "hideBlizzard.actionBars", reload = true },
            { t = "toggle", path = "hideBlizzard.playerFrame", reload = true },
            { t = "toggle", path = "hideBlizzard.targetFrame", reload = true },
            { t = "toggle", path = "hideBlizzard.minimap", reload = true },
            { t = "toggle", path = "hideBlizzard.buffs", reload = true },
            { t = "toggle", path = "hideBlizzard.questTracker", reload = true },
            { t = "toggle", path = "hideBlizzard.partyFrames", reload = true },
        } },
        { key = "sec.skins", rows = {
            { t = "toggle", path = "skins.tooltips", reload = true },
            { t = "toggle", path = "skins.popups", reload = true },
            { t = "toggle", path = "skins.itemCard", apply = A.ItemCard },
            { t = "toggle", path = "skins.itemCardSparks", needs = "skins.itemCard" },
            { t = "slider", path = "skins.itemCardScale", min = 0.7, max = 1.5, step = 0.05, fmt = "%.2fx", needs = "skins.itemCard" },
        } },
    } },
}
