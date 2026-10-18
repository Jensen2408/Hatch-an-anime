--[[ ReplicatedStorage.GoldCharacterFX  (ModuleScript, shared)
"Golden" character look. FX.apply(model, opts) turns every visible part into gold metal (via
RichGoldFinish), adds ForceField shine shells on MeshParts, and builds a "GoldFX" folder with a
sparkle emitter, warm light, ground ring burst, highlight and stripe-textured shine boxes on R6 limbs.
Effects start invisible / at rest (Transparency 1, RingBurst Rate 0): GoldFXClient (client) animates them,
using attributes Gold, GoldFXPhase, BaseRate and tag "GoldCharacter".
  opts: Reflectance (0.45), Sparkles (16), Specks (10), Phase (random 0..3.2)
]]
local CollectionService = game:GetService("CollectionService")
local FX = {}
local GOLD = Color3.fromRGB(255, 203, 35)

-- Re-applies the plain gold finish and strips the animated extras (folder + tag).
function FX.remove(model)
    require(game.ReplicatedStorage.RichGoldFinish).Apply(model)
    CollectionService:RemoveTag(model, "GoldCharacter")
    local existingFx = model:FindFirstChild("GoldFX")
    if existingFx then
        existingFx:Destroy()
    end
end

-- Returns the GoldFX folder, or nil if `model` is not a Model or has no BasePart.
function FX.apply(model, opts)
    opts = opts or {}
    if not model:IsA("Model") then
        return nil
    end
    FX.remove(model)
    local core = model:FindFirstChild("HumanoidRootPart", true)
        or model:FindFirstChild("Torso", true)
        or model:FindFirstChildWhichIsA("BasePart", true)
    if not core then
        return nil
    end
    local boxCFrame, boxSize = model:GetBoundingBox()
    -- Snapshot the original parts before any FX parts are added to the model.
    local originalParts = {}
    for _, descendant in ipairs(model:GetDescendants()) do
        if descendant:IsA("BasePart") then
            table.insert(originalParts, descendant)
        end
    end
    local folder = Instance.new("Folder")
    folder.Name = "GoldFX"
    folder.Parent = model
    local shells = Instance.new("Folder")
    shells.Name = "ShineShells"
    shells.Parent = folder
    for _, part in ipairs(originalParts) do
        if part.Name ~= "HumanoidRootPart" and part.Transparency < 1 then
            local _surfaceAppearance = part:FindFirstChildWhichIsA("SurfaceAppearance") -- unused
            -- Keep original SurfaceAppearance albedo and cavity normals intact.
            part.Material = Enum.Material.Metal
            part.Reflectance = opts.Reflectance or 0.45
            if part:IsA("MeshPart") then
                -- Slightly larger ForceField copy welded on top: gives the moving shine.
                local shell = part:Clone()
                shell:ClearAllChildren()
                shell.Name = "Shine_" .. part.Name
                shell.Size = part.Size * 1.015
                shell.TextureID = ""
                shell.Material = Enum.Material.ForceField
                shell.Color = Color3.fromRGB(255, 221, 90)
                shell.Transparency = 0.55
                shell.Anchored = false
                shell.Massless = true
                shell.CanCollide = false
                shell.CanTouch = false
                shell.CanQuery = false
                shell.CastShadow = false
                shell.Parent = shells
                local weld = Instance.new("WeldConstraint")
                weld.Part0 = part
                weld.Part1 = shell
                weld.Parent = shell
            end
        end
    end
    -- Invisible box around the body that hosts the particles and light.
    local emitter = Instance.new("Part")
    emitter.Name = "GoldFX_Emitter"
    emitter.Size = boxSize * Vector3.new(0.9, 0.95, 0.9)
    emitter.CFrame = boxCFrame
    emitter.Transparency = 1
    emitter.Anchored = false
    emitter.Massless = true
    emitter.CanCollide = false
    emitter.CanTouch = false
    emitter.CanQuery = false
    emitter.CastShadow = false
    emitter.Parent = folder
    local weld = Instance.new("WeldConstraint")
    weld.Part0 = core
    weld.Part1 = emitter
    weld.Parent = emitter
    local function addSparkleEmitter(name, rate)
        local particles = Instance.new("ParticleEmitter")
        particles.Name = name
        particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        particles.Color = ColorSequence.new(GOLD)
        particles.Shape = Enum.ParticleEmitterShape.Box
        particles.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
        particles.LightEmission = 1
        particles.LightInfluence = 0
        particles.Brightness = 3
        particles.Rate = rate
        particles.Parent = emitter
        return particles
    end
    local stars = addSparkleEmitter("Sparkles", opts.Sparkles or 16)
    stars:SetAttribute("BaseRate", stars.Rate)
    stars.Lifetime = NumberRange.new(0.5, 0.9)
    stars.Speed = NumberRange.new(0)
    stars.Rotation = NumberRange.new(0, 360)
    stars.RotSpeed = NumberRange.new(-90, 90)
    stars.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.35, 0.45),
        NumberSequenceKeypoint.new(1, 0),
    })
    local dust = addSparkleEmitter("GoldSpecks", opts.Specks or 10)
    dust:SetAttribute("BaseRate", dust.Rate)
    dust.Brightness = 2
    dust.Lifetime = NumberRange.new(2, 3)
    dust.Speed = NumberRange.new(0.6, 1.2)
    dust.SpreadAngle = Vector2.new(15, 15)
    dust.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0),
        NumberSequenceKeypoint.new(0.5, 0.12),
        NumberSequenceKeypoint.new(1, 0),
    })
    dust.Transparency = NumberSequence.new(0.2, 1)
    local light = Instance.new("PointLight")
    light.Name = "WarmLight"
    light.Color = GOLD
    light.Brightness = 1.1
    light.Range = 9
    light.Shadows = false
    light.Parent = emitter
    -- Flat invisible disc at the feet; its RingBurst emitter is fired by GoldFXClient (Rate stays 0).
    local ring = Instance.new("Part")
    ring.Name = "GroundRing"
    ring.Shape = Enum.PartType.Cylinder
    ring.Size = Vector3.new(0.05, boxSize.X * 1.25, boxSize.X * 1.25)
    ring.CFrame = CFrame.new(boxCFrame.Position - Vector3.new(0, boxSize.Y * 0.5 - 0.025, 0))
        * CFrame.Angles(0, 0, math.pi * 0.5)
    ring.Transparency = 1
    ring.Anchored = false
    ring.Massless = true
    ring.CanCollide = false
    ring.CanTouch = false
    ring.CanQuery = false
    ring.CastShadow = false
    ring.Parent = folder
    local ringWeld = Instance.new("WeldConstraint")
    ringWeld.Part0 = core
    ringWeld.Part1 = ring
    ringWeld.Parent = ring
    local ripple = Instance.new("ParticleEmitter")
    ripple.Name = "RingBurst"
    ripple.Texture = "rbxasset://textures/particles/sparkles_main.dds"
    ripple.Shape = Enum.ParticleEmitterShape.Disc
    ripple.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
    -- pcall: guards against ShapeInOut being unavailable (assignment errors are swallowed).
    pcall(function()
        ripple.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
    end)
    ripple.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
    ripple.Rate = 0
    ripple.Color = ColorSequence.new(GOLD)
    ripple.LightEmission = 1
    ripple.Brightness = 3
    ripple.Speed = NumberRange.new(1, 2)
    ripple.Lifetime = NumberRange.new(0.5, 0.9)
    ripple.Size = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.12),
        NumberSequenceKeypoint.new(0.3, 0.18),
        NumberSequenceKeypoint.new(1, 0),
    })
    ripple.Transparency = NumberSequence.new(0.1, 1)
    ripple.Parent = ring
    local highlight = Instance.new("Highlight")
    highlight.Name = "GoldShine"
    highlight.Adornee = model
    highlight.FillColor = Color3.fromRGB(255, 221, 90)
    highlight.FillTransparency = 1
    highlight.OutlineTransparency = 1
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Parent = folder
    -- R6 limbs: a slightly larger invisible box carrying a shine-stripe Texture on its four sides.
    local shineFolder = Instance.new("Folder")
    shineFolder.Name = "ShineBoxes"
    shineFolder.Parent = folder
    for _, name in ipairs({ "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }) do
        local limb = model:FindFirstChild(name, true)
        if limb and limb:IsA("BasePart") then
            local box = Instance.new("Part")
            box.Name = name .. "_Shine"
            box.Size = limb.Size + Vector3.new(0.03, 0.03, 0.03)
            box.CFrame = limb.CFrame
            box.Transparency = 1
            box.CanCollide = false
            box.CanTouch = false
            box.CanQuery = false
            box.Massless = true
            box.CastShadow = false
            box.Anchored = false
            box.Parent = shineFolder
            local boxWeld = Instance.new("WeldConstraint")
            boxWeld.Part0 = limb
            boxWeld.Part1 = box
            boxWeld.Parent = box
            for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
                local texture = Instance.new("Texture")
                texture.Name = "ShineStripe"
                texture.Texture = "rbxassetid://91836211653754"
                texture.Face = face
                texture.StudsPerTileU = 16
                texture.StudsPerTileV = 8
                texture.Color3 = Color3.fromRGB(255, 226, 150)
                texture.Transparency = 1
                texture.ZIndex = 2
                texture.Parent = box
            end
        end
    end
    model:SetAttribute("Gold", true)
    -- Phase offset so several gold characters don't shine in sync.
    model:SetAttribute("GoldFXPhase", opts.Phase or math.random() * 3.2)
    CollectionService:AddTag(model, "GoldCharacter")
    return folder
end
return FX
