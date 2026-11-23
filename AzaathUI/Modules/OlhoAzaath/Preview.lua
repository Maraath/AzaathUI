--[[----------------------------------------------------------------------------
    AzaathUI - Olho de Azaath / Preview.lua
    Vitrine da janela de ajustes: um objeto 3D da categoria escolhida (veio,
    erva, baú...) com uma "placa" no lugar onde o jogo a poria, e o brilho de
    verdade (Glow.lua) preso a ela, passando pelos estados em loop.
    Arrastar gira a câmera em volta do objeto, botão direito desloca, a roda
    aproxima. Quando o jogo aponta um objeto real, o brilho vai para ele.
------------------------------------------------------------------------------]]

local _, Azaath = ...
local ns = Azaath.OlhoNS
local L = ns.L

local sin, cos, tan, asin, rad, sqrt = math.sin, math.cos, math.tan, math.asin, math.rad, math.sqrt
local min, max, pi = math.min, math.max, math.pi

local FOV = rad(30)
local PITCH = asin(0.36)          -- inclinação típica da câmera do jogo
local YAW0 = pi - 0.5             -- vista de três quartos
local PER_YARD = 40               -- unidades de interface por metro, a ~10 m (medido no jogo)
local PLATE_ABOVE = 2.0           -- a placa flutua ~2 m acima do pé do objeto
local LIMIT_H, LIMIT_W = 1.8, 2.4 -- tamanho máximo do modelo (o servidor encolhe os objetos)
local TURN_RATE = 0.012           -- radianos por unidade arrastada
local ZOOM_RATE, ZOOM_MIN, ZOOM_MAX = 0.88, 0.2, 2.5
local PAN_MAX = 4

-- modelos do cliente (IDs de arquivo) para cada categoria
local MODEL = {
    ore = 219514,    -- veio de cobre
    herb = 219481,   -- flor-da-paz
    quest = 198168,  -- caixote de Ventobravo
    chest = 219372,  -- baú do tesouro
    bobber = 201000, -- boia de pesca
    other = 199999,  -- caixa de correio
}

local P = {
    cat = ns.CATEGORY_ORDER[1], view = nil, plate = nil, scene = nil, actor = nil,
    ready = false, yaw = YAW0, dist = 10, homeDist = 10,
    foot = { 0, 0, 0 }, aim = { 0, 0, 0 }, home = { 0, 0, 0 }, plateZ = PLATE_ABOVE, drag = nil,
}

local function Camera()
    local s = P.scene
    local ch = cos(PITCH)
    local fx, fy, fz = ch * cos(P.yaw), ch * sin(P.yaw), -sin(PITCH)
    s:SetCameraPosition(P.aim[1] - fx * P.dist, P.aim[2] - fy * P.dist, P.aim[3] - fz * P.dist)
    s:SetCameraOrientationByYawPitchRoll(P.yaw, PITCH, 0)
    s:SetLightDirection(fx, fy, fz)
end

local function Project(x, y, z)
    local px, py = P.scene:Project3DPointTo2D(x, y, z)
    if not px then return nil end
    local k = P.scene:GetEffectiveScale()
    return px / k, py / k
end

local function PlacePlate()
    Camera()
    local x, y = Project(P.foot[1], P.foot[2], P.foot[3] + P.plateZ)
    if x then
        P.plate:ClearAllPoints()
        P.plate:SetPoint("CENTER", P.view, "BOTTOMLEFT", x, y)
    end
end

-- enquadra o modelo carregado: tamanho de jogo, câmera mirando entre o pé e a placa
local function Frame()
    P.ready = true
    local a = P.actor
    local x1, y1, z1, x2, y2, z2 = a:GetActiveBoundingBox()
    local scale = 1
    P.plateZ = PLATE_ABOVE
    if x1 and z2 then
        local h, w = z2 - z1, max(x2 - x1, y2 - y1)
        if h > 0 and w > 0 then scale = min(1, LIMIT_H / h, LIMIT_W / w) end
        P.foot = { (x1 + x2) / 2 * scale, (y1 + y2) / 2 * scale, z1 * scale }
        P.plateZ = max(PLATE_ABOVE, h * scale + 0.2)
    else
        P.foot = { 0, 0, 0 }
    end
    if a.SetScale then pcall(a.SetScale, a, scale) end
    P.home = { P.foot[1], P.foot[2], P.foot[3] + P.plateZ / 2 }
    P.aim = { P.home[1], P.home[2], P.home[3] }
    P.yaw = YAW0
    -- distância em que 1 metro ocupa PER_YARD unidades na altura da vista
    P.homeDist = P.view:GetHeight() / (2 * tan(FOV / 2) * PER_YARD)
    P.dist = P.homeDist
    PlacePlate()
    a:Show()
end

local function Follow()
    local d = P.drag
    local k = P.view:GetEffectiveScale()
    local cx, cy = GetCursorPosition()
    cx, cy = cx / k, cy / k
    local dx, dy = cx - d.x, cy - d.y
    d.x, d.y = cx, cy
    if not d.pan then
        P.yaw = P.yaw - dx * TURN_RATE
        return
    end
    local per = PER_YARD * P.homeDist / P.dist
    local rx, ry, rz = P.scene:GetCameraRight()
    local ux, uy, uz = P.scene:GetCameraUp()
    local mr, mu = -dx / per, -dy / per
    local aim = P.aim
    aim[1] = aim[1] + rx * mr + ux * mu
    aim[2] = aim[2] + ry * mr + uy * mu
    aim[3] = aim[3] + rz * mr + uz * mu
    local ex, ey, ez = aim[1] - P.home[1], aim[2] - P.home[2], aim[3] - P.home[3]
    local far = sqrt(ex * ex + ey * ey + ez * ez)
    if far > PAN_MAX then
        local f = PAN_MAX / far
        aim[1], aim[2], aim[3] = P.home[1] + ex * f, P.home[2] + ey * f, P.home[3] + ez * f
    end
end

local function MakeScene()
    local ok, scene = pcall(CreateFrame, "ModelScene", nil, P.view)
    if not ok or not scene then return end
    local actor
    ok = pcall(function()
        scene:SetAllPoints()
        scene:SetCameraFieldOfView(FOV)
        scene:SetCameraNearClip(0.05)
        scene:SetCameraFarClip(500)
        scene:SetLightVisible(true)
        scene:SetLightAmbientColor(0.75, 0.75, 0.75)
        scene:SetLightDiffuseColor(1, 1, 1)
        actor = scene:CreateActor(nil, "ModelSceneActorTemplate")
    end)
    if ok and actor then P.scene, P.actor = scene, actor else scene:Hide() end
end

local function Show(cat)
    P.cat, P.drag = cat, nil
    P.plate:ClearAllPoints()
    P.plate:SetPoint("CENTER", P.view, "CENTER", 0, 45)
    local loaded = false
    if P.actor then
        P.actor:Hide()
        if P.actor.SetScale then pcall(P.actor.SetScale, P.actor, 1) end
        local ok, r = pcall(P.actor.SetModelByFileID, P.actor, MODEL[cat])
        loaded = ok and r == true
        P.scene:SetShown(loaded)
    end
    P.ready = not loaded
    P.notice:SetShown(not loaded)
    P.hint:SetShown(loaded)
    if not ns.GlowTaken() then ns.StartPreview(P.plate, cat, true) end
end

local function Tick()
    -- o brilho pode ter ido para um alvo real (ou o Olho foi desligado): pega de volta quando livre
    if not ns.IsPreviewing() and not ns.GlowTaken() then ns.StartPreview(P.plate, P.cat, true) end
    local state = ns.PreviewState()
    P.caption:SetText(state and L["STATE_" .. state:upper()] or "")
    P.notice:SetText(L.PREVIEW_NO_MODEL)
    P.hint:SetText(L.PREVIEW_HINT)
    if not P.ready then
        if P.actor and P.actor:IsLoaded() then Frame() end
    elseif P.scene and P.scene:IsShown() then
        if P.drag then Follow() end
        PlacePlate()
    end
end

-- monta a vitrine em `parent` e devolve a vista
function ns.PreviewPane(parent, width, height)
    local view = CreateFrame("Frame", nil, parent)
    P.view = view
    view:SetSize(width, height)
    view:SetClipsChildren(true)
    view:EnableMouse(true)
    view:EnableMouseWheel(true)
    local bg = view:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetTexture(Azaath.media.blank)
    Azaath.Gradient(bg, "VERTICAL", 0.02, 0.02, 0.03, 1, 0.08, 0.09, 0.11, 1)

    view:SetScript("OnMouseDown", function(_, button)
        if not P.scene or not P.ready then return end
        local k = view:GetEffectiveScale()
        local x, y = GetCursorPosition()
        P.drag = { x = x / k, y = y / k, pan = button == "RightButton" }
    end)
    view:SetScript("OnMouseUp", function() P.drag = nil end)
    view:SetScript("OnMouseWheel", function(_, delta)
        if not P.scene or not P.ready then return end
        P.dist = max(P.homeDist * ZOOM_MIN, min(P.homeDist * ZOOM_MAX, P.dist * ZOOM_RATE ^ delta))
    end)

    MakeScene()
    P.plate = CreateFrame("Frame", nil, view)
    P.plate:SetSize(1, 1)
    P.plate:SetFrameLevel(view:GetFrameLevel() + 5)

    local over = CreateFrame("Frame", nil, view)
    over:SetAllPoints()
    over:SetFrameLevel(view:GetFrameLevel() + 8)
    local c = Azaath.ConfigUI.C
    P.caption = ns.Skin.Text(over, 12, c.accent, "bold")
    P.caption:SetPoint("BOTTOM", 0, 10)
    P.caption:SetJustifyH("CENTER")
    P.notice = ns.Skin.Text(over, 11, c.dim)
    P.notice:SetPoint("TOP", 0, -10)
    P.notice:SetJustifyH("CENTER")
    P.hint = ns.Skin.Text(parent, 10, c.dim)
    P.hint:SetPoint("TOP", view, "BOTTOM", 0, -6)
    P.hint:SetWidth(width)
    P.hint:SetJustifyH("CENTER")

    view:SetScript("OnShow", function() Show(P.cat) end)
    view:SetScript("OnHide", function()
        P.drag = nil
        ns.StopPreview()
    end)
    view:SetScript("OnUpdate", Tick)
    if view:IsVisible() then Show(P.cat) end
    return view
end

function ns.ShowPreviewCategory(cat)
    if cat == P.cat then return end
    P.cat = cat
    if P.view and P.view:IsVisible() then Show(cat) end
end
