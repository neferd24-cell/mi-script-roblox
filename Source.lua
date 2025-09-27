-- LowPerformanceMode.lua  (LocalScript)
-- Pegar en StarterPlayer > StarterPlayerScripts o StarterGui

local UserInputService = game:GetService("UserInputService")
local UserSettings = UserSettings() -- singleton
local UserGameSettings = UserSettings:GetService("UserGameSettings")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local applied = false

-- CONFIGURACIÓN (ajusta según tu juego)
local MIN_SAVED_QUALITY = Enum.SavedQualitySetting.QualityLevel2 -- si el jugador tiene menor calidad, forzamos modo bajo
local LOWPERF_TAG = "LowPerf" -- los objetos decorativos que quieres afectar deben llevar esta tag
local HIDE_DECAL_TRANSPARENCY = 0.9 -- 0 = visible, 1 = invisible (para Decals/Textures)
local PART_TRANSPARENCY_MOD = 0.5 -- LocalTransparencyModifier para parts etiquetadas (0 = sin cambio, 1 = invisible)
local MESH_SCALE_FACTOR = 0.6 -- factor reducido para SpecialMesh / MeshPart scale
local DISABLE_SHADOWS = true -- si quieres desactivar sombras en el cliente

-- Función que decide si debemos aplicar el modo bajo
local function shouldApplyLowPerf()
    -- Detectamos si es dispositivo táctil (móvil/tablet). No es perfecto, pero es útil.
    local isTouch = UserInputService.TouchEnabled
    -- Obtenemos la calidad guardada del usuario
    local saved = UserGameSettings and UserGameSettings.SavedQualityLevel
    local lowQuality = false
    if typeof(saved) == "EnumItem" then
        -- comparamos ordinalmente (QualityLevel1, QualityLevel2...)
        lowQuality = (saved.Value <= MIN_SAVED_QUALITY.Value)
    end
    return isTouch or lowQuality
end

-- Aplica cambios visuales de bajo rendimiento (cliente-local)
local function applyLowPerf()
    if applied then return end
    applied = true

    -- 1) Opciones de Lighting
    pcall(function()
        if DISABLE_SHADOWS and Lighting then
            Lighting.GlobalShadows = false -- reduce costo del render
            -- También puedes bajar otras propiedades si quieres:
            -- Lighting.OutdoorAmbient = Color3.fromRGB(180,180,180)
        end
    end)

    -- 2) Desactivar partículas, trails, luces y efectos
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ParticleEmitter") or obj:IsA("Trail") then
            pcall(function() obj.Enabled = false end)
        elseif obj:IsA("PointLight") or obj:IsA("SurfaceLight") or obj:IsA("SpotLight") then
            pcall(function() obj.Enabled = false end)
        elseif obj:IsA("Beam") then
            pcall(function() obj.Enabled = false end)
        end
    end

    -- 3) Hacer invisibles o casi invisibles decals/textures en cliente
    for _, dec in ipairs(workspace:GetDescendants()) do
        if dec:IsA("Decal") or dec:IsA("Texture") then
            pcall(function() dec.Transparency = HIDE_DECAL_TRANSPARENCY end)
        end
    end

    -- 4) Reducir detalle de meshes/meshparts o usar LocalTransparencyModifier para partes "decorativas"
    -- Recomendación: marca las partes decorativas con CollectionService tag = LOWPERF_TAG
    local tagged = CollectionService:GetTagged(LOWPERF_TAG)
    for _, inst in ipairs(tagged) do
        pcall(function()
            if inst:IsA("BasePart") then
                -- LocalTransparencyModifier solo afecta a este cliente
                if inst.LocalTransparencyModifier ~= nil then
                    inst.LocalTransparencyModifier = PART_TRANSPARENCY_MOD
                else
                    inst.Transparency = math.clamp(inst.Transparency + 0.3, 0, 1)
                end
            elseif inst:IsA("SpecialMesh") then
                if inst.Scale then
                    inst.Scale = inst.Scale * MESH_SCALE_FACTOR
                end
            elseif inst:IsA("MeshPart") then
                if inst.Size then
                    inst.Size = inst.Size * MESH_SCALE_FACTOR
                end
            end
        end)
    end

    -- 5) Opcional: reducir efectos en la cámara (motion blur, depth of field) si los usas
    -- (si usas PostEffect, desactiva los que consumen)
    for _, effect in ipairs(Lighting:GetDescendants()) do
        if effect:IsA("BlurEffect") or effect:IsA("DepthOfFieldEffect") or effect:IsA("SunRaysEffect") or effect:IsA("ColorCorrectionEffect") then
            pcall(function() effect.Enabled = false end)
        end
    end

    -- 6) Desactivar partes móviles/animaciones decorativas (opcional)
    -- Nota: Ten cuidado de no desactivar animaciones esenciales del gameplay.
    for _, anim in ipairs(workspace:GetDescendants()) do
        if anim:IsA("ParticleEmitter") or anim:IsA("AnimationController") then
            pcall(function() anim:Destroy() end) -- usa con extrema precaución; preferible marcar con tag antes
        end
    end

    -- Mensaje por consola para debug
    warn("[LowPerf] Low performance mode applied for player:", player and player.Name or "unknown")
end

-- Puedes crear una función para revertir cambios si quieres un toggle (no implementada completa aquí)
local function revertLowPerf()
    -- Implementar si quieres permitir volver a alta calidad (revertir cambios previos)
    -- Necesitarás almacenar valores originales antes de cambiarlos.
    warn("[LowPerf] revert not implemented")
end

-- Aplicar si corresponde al unirse el jugador
if shouldApplyLowPerf() then
    applyLowPerf()
else
    -- Escuchar cambios en la calidad guardada (por ejemplo si el jugador baja la calidad manualmente)
    if UserGameSettings then
        UserGameSettings.Changed:Connect(function(prop)
            if prop == "SavedQualityLevel" then
                if shouldApplyLowPerf() then
                    applyLowPerf()
                end
            end
        end)
    end
end

-- También puedes exponer un toggle desde una GUI para que el usuario elija "Baja calidad"
-- (Sería un botón que llame a applyLowPerf() / revertLowPerf()).
