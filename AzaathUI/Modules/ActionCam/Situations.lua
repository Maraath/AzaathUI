--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ActionCam/Situations.lua
    Situações da câmera (fase 2 do rework): descobre o momento do jogador
    (combate, chefe, montaria, voo, nado, masmorra, interior, descanso, morte,
    exploração) e entrega ao diretor um perfil: quanto do ombro usar, quanto
    somar na inclinação e em quanto tempo mudar. Cada situação lembra a
    distância de câmera que o jogador usou nela da última vez (por personagem).
    Conversa com NPC e ficha continuam sendo cenas próprias (suspendem tudo).
------------------------------------------------------------------------------]]

local _, Azaath = ...
local _G = _G

local AC = Azaath.ActionCam or {}
Azaath.ActionCam = AC

local GetTime = _G.GetTime
local abs = math.abs

-- mul = fração do ombro do jogador; pitch = soma na inclinação; dur = transição (s);
-- zoom = afastamento extra enquanto durar (jardas, camada "situacao" do diretor)
local PROFILES = {
    morte      = { mul = 0.00, pitch = 0.18, dur = 1.20, zoom = 2.0 },
    voo        = { mul = 0.35, pitch = 0.12, dur = 0.90 },
    chefe      = { mul = 0.75, pitch = 0.14, dur = 0.80, zoom = 3.0 },
    combate    = { mul = 0.85, pitch = 0.08, dur = 0.50, zoom = 1.5 },
    montaria   = { mul = 0.55, pitch = 0.06, dur = 0.80 },
    nado       = { mul = 0.80, pitch = 0.04, dur = 0.80 },
    masmorra   = { mul = 0.85, pitch = 0.00, dur = 0.70 },
    interior   = { mul = 0.65, pitch = -0.08, dur = 0.70 },
    descanso   = { mul = 0.90, pitch = 0.04, dur = 1.00 },
    exploracao = { mul = 1.00, pitch = 0.00, dur = 0.80 },
}
AC.CameraSituations = PROFILES

-- Entram na hora; as demais precisam ficar estáveis por HOLD segundos
-- (evita pisca-pisca em portas, saltos de montaria, fim de combate etc.)
local URGENT = { morte = true, chefe = true, combate = true }
local HOLD = 0.4

local current = nil
local candidate, candidateSince = nil, 0

local function Safe(v)
    if v == nil then return nil end
    if Azaath.IsSecret and Azaath.IsSecret(v) then return nil end
    return v
end

local function Call(fn, ...)
    if not fn then return nil end
    local ok, v = pcall(fn, ...)
    if not ok then return nil end
    return Safe(v)
end

local function IsBossFight()
    if Call(_G.IsEncounterInProgress) then return true end
    if Call(_G.UnitExists, "boss1") then return true end
    if Call(_G.UnitExists, "target") and Call(_G.UnitCanAttack, "player", "target") then
        local cls = Call(_G.UnitClassification, "target")
        if cls == "worldboss" then return true end
        local lvl = Call(_G.UnitLevel, "target")
        if lvl == -1 then return true end
    end
    return false
end

local function InGroupInstance()
    local inInst, kind = _G.IsInInstance and _G.IsInInstance()
    return Safe(inInst) and (kind == "party" or kind == "raid" or kind == "scenario")
end

function AC.DetectCameraSituation()
    if Call(_G.UnitIsDeadOrGhost, "player") then return "morte" end
    if Call(_G.IsFlying) then return "voo" end
    local inCombat = Call(_G.UnitAffectingCombat, "player")
    if inCombat then
        return IsBossFight() and "chefe" or "combate"
    end
    if Call(_G.IsMounted) then return "montaria" end
    if Call(_G.IsSwimming) then return "nado" end
    if InGroupInstance() then return "masmorra" end
    if Call(_G.IsIndoors) then return "interior" end
    if Call(_G.IsResting) then return "descanso" end
    return "exploracao"
end

local function ZoomMemory(db)
    if type(db.situationZoom) ~= "table" then db.situationZoom = {} end
    return db.situationZoom
end

local function Switch(db, name)
    local Cam = AC.Cam
    local mem = ZoomMemory(db)
    local userZoom = Cam.GetUserZoom()

    -- guarda a distância usada na situação que está saindo
    if current and userZoom then
        mem[current] = userZoom
    end
    -- e volta à distância lembrada da nova (só se o jogador já usou uma lá)
    if db.situationZoomMemory ~= false and userZoom and mem[name] and abs(mem[name] - userZoom) >= 0.5 then
        Cam.ZoomBy(mem[name] - userZoom)
    end

    current = name
    local p = PROFILES[name] or PROFILES.exploracao
    Cam.SetSituation(name, p.mul, p.pitch, p.dur)
    Cam.SetZoom("situacao", p.zoom)
end

-- Chamado pelo laço da Câmera Action (0,1 s)
function AC.UpdateCameraSituation()
    local db = AC.DB and AC.DB()
    if not db or not db.enabled or not AC.Cam then return end

    if db.situations == false then
        if current ~= "desligado" then
            current = "desligado"
            AC.Cam.SetSituation("desligado", 1, 0, 0.5)
            AC.Cam.SetZoom("situacao", nil)
        end
        return
    end
    if current == "desligado" then current = nil end

    -- cenas (NPC, ficha) mexem no zoom por conta própria: não lembrar nada delas
    if AC.npcCinematicActive then
        candidate = nil
        return
    end

    local now = GetTime()
    local want = AC.DetectCameraSituation()
    if want == current then
        candidate = nil
        return
    end
    if want ~= candidate then
        candidate, candidateSince = want, now
    end
    if URGENT[want] or current == nil or (now - candidateSince) >= HOLD then
        candidate = nil
        Switch(db, want)
    end
end

function AC.GetCameraSituation()
    return current
end
