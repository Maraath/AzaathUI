--[[----------------------------------------------------------------------------
    AzaathUI - Modules/ActionCam/CameraMoves.lua
    Câmera por habilidade (fase 3 do rework): cada golpe conhecido ganha um
    gesto de câmera próprio — investida avança, giro abre, golpe pesado dá
    soco, brado sacode para cima, Tempestade de Lâminas afasta enquanto dura.
    Reconhece pelo NOME (pt-BR e inglês): em combate o spellID pode vir
    secreto, então o RotationAssist também avisa com o botão apertado.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local _G = _G

local AC = Azaath.ActionCam or {}
Azaath.ActionCam = AC

local GetTime = _G.GetTime

-- zoom (+ afasta / - aproxima, jardas) segurado por hold s;
-- kick = { ombro, inclinação, tremor lateral, tremor vertical }
local KINDS = {
    rush  = { zoom = -1.4, hold = 0.30, kick = { 4.5, -2.5, 0.30, 0.10 } },
    spin  = { zoom = 1.1,  hold = 0.45, kick = { 0.0, 1.5, 0.35, 0.15 } },
    heavy = { zoom = -0.9, hold = 0.12, kick = { 5.5, -3.0, 0.45, 0.20 } },
    light = { kick = { 3.0, -1.5, 0.25, 0.10 } },
    shout = { zoom = 0.7,  hold = 0.50, kick = { 0.0, 2.2, 0.10, 0.35 } },
    storm = { channelZoom = 2.0 },
}
AC.CameraMoveKinds = KINDS

local NAMES = {
    rush  = { "Investida", "Charge", "Interceptar", "Intercept", "Intervir", "Intervene" },
    spin  = { "Redemoinho", "Whirlwind", "Cutilada", "Cleave", "Trovoada", "Estrondo do Trovão",
              "Thunder Clap", "Onda de Choque", "Shockwave" },
    heavy = { "Executar", "Execute", "Golpe Mortal", "Mortal Strike", "Sede de Sangue", "Bloodthirst",
              "Batida", "Slam", "Pancada com Escudo", "Batida com Escudo", "Shield Slam", "Subjugar",
              "Overpower", "Revanche", "Revenge", "Golpe Heroico", "Heroic Strike" },
    light = { "Dilacerar", "Rend", "Devastar", "Devastate", "Ímpeto da Vitória", "Victory Rush" },
    shout = { "Brado de Batalha", "Battle Shout", "Brado Desmoralizador", "Demoralizing Shout",
              "Brado Intimidador", "Intimidating Shout", "Brado Desafiador", "Challenging Shout",
              "Temeridade", "Recklessness", "Ira Insana", "Berserker Rage", "Desejo de Morte", "Death Wish" },
    storm = { "Tempestade de Lâminas", "Bladestorm" },
}

local byName = {}
for kind, list in pairs(NAMES) do
    for _, n in ipairs(list) do byName[n] = kind end
end
AC.CameraMoveNames = byName

local lastName, lastAt = nil, 0

local function Enabled()
    local db = AC.DB and AC.DB()
    if not db or not db.enabled or db.bdoEnabled == false or db.bdoMoves == false then return nil end
    return db
end

local function Intensity(db)
    return math.max(0, math.min(1, tonumber(db.bdoIntensity) or 0.65))
end

-- Nome legível de um spellID (nil se secreto)
function AC.SpellNameSafe(id)
    if id == nil or (Azaath.IsSecret and Azaath.IsSecret(id)) then return nil end
    local n
    if _G.C_Spell and _G.C_Spell.GetSpellName then
        local ok, v = pcall(_G.C_Spell.GetSpellName, id); if ok then n = v end
    elseif _G.GetSpellInfo then
        local ok, v = pcall(_G.GetSpellInfo, id); if ok then n = v end
    end
    if n and not (Azaath.IsSecret and Azaath.IsSecret(n)) and n ~= "" then return n end
end

-- Golpe confirmado (UNIT_SPELLCAST_SUCCEEDED). Pode chegar duas vezes
-- (ActionCam + RotationAssist): a repetição em 0,25 s é ignorada.
function AC.OnSpellMove(name)
    if not name then return end
    local db = Enabled()
    if not db then return end
    local now = GetTime()
    if name == lastName and (now - lastAt) < 0.25 then return end
    lastName, lastAt = name, now

    local kind = byName[name]
    local k = kind and KINDS[kind]
    if not k or k.channelZoom then return end
    local I = Intensity(db)
    if k.zoom then AC.Cam.PulseZoom("golpe", k.zoom * I, k.hold) end
    if k.kick and AC.CameraKick then
        AC.CameraKick(k.kick[1], k.kick[2], k.kick[3], k.kick[4])
    end
end

-- Canalização (Tempestade de Lâminas): afasta enquanto dura
function AC.OnSpellChannel(started, name)
    if not started then
        AC.Cam.SetZoom("canal", nil)
        return
    end
    local db = Enabled()
    local k = db and name and KINDS[byName[name] or ""]
    if k and k.channelZoom then
        AC.Cam.SetZoom("canal", k.channelZoom * Intensity(db))
    end
end

function AC.GetCameraMoveKind(name)
    return name and byName[name]
end
