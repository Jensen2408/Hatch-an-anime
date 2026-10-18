-- OwnerShowcaseFX (LocalScript, StarterPlayerScripts; shipped Disabled in default.project.json)
-- Client VFX around the owner's showcase statue: spinning ground sigil, lightning, pulsing light,
-- and a power burst (shockwave + sky pillar + flash) every 7 s. Only runs while you're within 160 studs
-- and the player's ReducedMotion attribute is not true.
-- Watches workspace.Plots.<plot>.OwnerShowcase; all FX live in a local "ShowcaseFXLocal" folder in workspace.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local player = game:GetService("Players").LocalPlayer

local WHITE, PURPLE, DEEP_PURPLE, CYAN =
    Color3.fromRGB(255, 245, 255),
    Color3.fromRGB(200, 90, 255),
    Color3.fromRGB(110, 30, 190),
    Color3.fromRGB(90, 220, 255)
local SPARK_TEXTURE, SHOCK_TEXTURE, CORE_TEXTURE =
    "rbxasset://textures/particles/sparkles_main.dds",
    "rbxasset://textures/particles/explosion01_shockwave_main.dds",
    "rbxasset://textures/particles/explosion01_core_main.dds"

-- colorSequence(time1, color1, time2, color2, ...)
local function colorSequence(...)
    local keypoints, args = {}, { ... }
    for i = 1, #args, 2 do
        table.insert(keypoints, ColorSequenceKeypoint.new(args[i], args[i + 1]))
    end
    return ColorSequence.new(keypoints)
end
-- numberSequence(time1, value1, time2, value2, ...)
local function numberSequence(...)
    local keypoints, args = {}, { ... }
    for i = 1, #args, 2 do
        table.insert(keypoints, NumberSequenceKeypoint.new(args[i], args[i + 1]))
    end
    return NumberSequence.new(keypoints)
end

-- Builds the FX for one statue and runs it until the statue is removed. Yields up to 10 s for its root part.
local function build(statue)
    local root = statue:WaitForChild("HumanoidRootPart", 10)
    if not root then
        return
    end
    local humanoid = statue:FindFirstChildOfClass("Humanoid")
    local feetY = root.Position.Y - (humanoid and humanoid.HipHeight or 2) - root.Size.Y / 2
    local center = Vector3.new(root.Position.X, feetY, root.Position.Z)
    local fxFolder = Instance.new("Folder")
    fxFolder.Name = "ShowcaseFXLocal"
    fxFolder.Parent = workspace
    -- invisible anchored holder part for attachments / emitters / lights
    local function makeHolderPart(name, cframe)
        local holder = Instance.new("Part")
        holder.Name = name
        holder.Size = Vector3.one
        holder.CFrame = cframe
        holder.Anchored = true
        holder.CanCollide = false
        holder.CanQuery = false
        holder.CanTouch = false
        holder.Transparency = 1
        holder.CastShadow = false
        holder.Parent = fxFolder
        return holder
    end
    -- sigil rings (neon segments; every 4th segment left out as a gap)
    local function makeRing(radius, segmentCount, segmentWidth, color, heightOffset)
        local ringModel = Instance.new("Model")
        ringModel.Parent = fxFolder
        for i = 1, segmentCount do
            if i % 4 ~= 0 then
                local angle = i / segmentCount * math.pi * 2
                local segment = Instance.new("Part")
                segment.Anchored = true
                segment.CanCollide = false
                segment.CanQuery = false
                segment.CanTouch = false
                segment.CastShadow = false
                segment.Material = Enum.Material.Neon
                segment.Color = color
                segment.Size = Vector3.new(segmentWidth, 0.06, 2 * math.pi * radius / segmentCount * 0.9)
                segment.CFrame = CFrame.new(center + Vector3.new(0, heightOffset, 0))
                    * CFrame.Angles(0, angle, 0)
                    * CFrame.new(radius, 0, 0)
                segment.Parent = ringModel
            end
        end
        return ringModel, ringModel:GetPivot()
    end
    local outerRing, outerPivot = makeRing(6.5, 40, 0.35, PURPLE, 0.05)
    local innerRing, innerPivot = makeRing(4.2, 28, 0.25, CYAN, 0.07)
    local glowPart = makeHolderPart("Glow", CFrame.new(center + Vector3.new(0, 0.4, 0)))
    local glow = Instance.new("PointLight")
    glow.Color = PURPLE
    glow.Range = 18
    glow.Brightness = 5
    glow.Parent = glowPart
    -- lightning
    local boltsPart = makeHolderPart("Bolts", CFrame.new(center))
    local bolts = {} -- { a0, a1, b } per lightning beam
    for i = 1, 5 do
        local attachment0 = Instance.new("Attachment")
        attachment0.Parent = boltsPart
        local attachment1 = Instance.new("Attachment")
        attachment1.Parent = boltsPart
        local beam = Instance.new("Beam")
        beam.Attachment0 = attachment0
        beam.Attachment1 = attachment1
        beam.Texture = SPARK_TEXTURE
        beam.LightEmission = 1
        beam.LightInfluence = 0
        beam.Brightness = 10
        beam.Color = colorSequence(0, WHITE, 0.5, CYAN, 1, WHITE)
        beam.Width0 = 0.4
        beam.Width1 = 0.1
        beam.FaceCamera = true
        beam.Segments = 12
        beam.Parent = boltsPart
        bolts[i] = { a0 = attachment0, a1 = attachment1, b = beam }
    end
    -- random new path from the statue body to a point on the ground ring (70% chance to be visible)
    local function rerouteBolt(bolt)
        local angle = math.random() * math.pi * 2
        local radius = math.random() < 0.5 and 4 + math.random() * 2.5 or 1.5 + math.random() * 1.5
        bolt.a0.WorldPosition = root.Position
            + Vector3.new(math.random() * 2 - 1, math.random() * 4 - 1.5, math.random() * 1.2 - 0.6)
        bolt.a1.WorldPosition = center
            + Vector3.new(math.cos(angle) * radius, math.random() * 1.5, math.sin(angle) * radius)
        bolt.b.CurveSize0, bolt.b.CurveSize1 = math.random() * 6 - 3, math.random() * 6 - 3
        bolt.b.Enabled = math.random() < 0.7
    end
    -- burst
    local burstPart = makeHolderPart("Burst", CFrame.new(center + Vector3.new(0, 0.2, 0)))
    local function makeEmitter(props)
        local emitter = Instance.new("ParticleEmitter")
        emitter.Enabled = false
        for property, value in props do
            emitter[property] = value
        end
        emitter.Parent = burstPart
        return emitter
    end
    local shockEmitter = makeEmitter({
        Texture = SHOCK_TEXTURE,
        Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
        Speed = NumberRange.new(0.01),
        EmissionDirection = Enum.NormalId.Top,
        Color = colorSequence(0, WHITE, 0.4, PURPLE, 1, DEEP_PURPLE),
        LightEmission = 1,
        LightInfluence = 0,
        Brightness = 5,
        Size = numberSequence(0, 1, 1, 28),
        Transparency = numberSequence(0, 0, 0.6, 0.3, 1, 1),
        Lifetime = NumberRange.new(0.8),
    })
    local flashEmitter = makeEmitter({
        Texture = CORE_TEXTURE,
        Color = colorSequence(0, WHITE, 0.5, CYAN, 1, PURPLE),
        LightEmission = 1,
        LightInfluence = 0,
        Brightness = 6,
        Size = numberSequence(0, 4, 1, 15),
        Transparency = numberSequence(0, 0, 1, 1),
        Lifetime = NumberRange.new(0.35),
        Speed = NumberRange.new(0),
    })
    local debrisEmitter = makeEmitter({
        Texture = SPARK_TEXTURE,
        Color = colorSequence(0, WHITE, 0.5, PURPLE, 1, CYAN),
        LightEmission = 1,
        LightInfluence = 0,
        Brightness = 6,
        Size = numberSequence(0, 0.6, 1, 0),
        Lifetime = NumberRange.new(0.8, 1.4),
        Speed = NumberRange.new(25, 45),
        SpreadAngle = Vector2.new(80, 80),
        EmissionDirection = Enum.NormalId.Top,
        Acceleration = Vector3.new(0, -30, 0),
        Drag = 2,
        Orientation = Enum.ParticleOrientation.VelocityParallel,
    })
    local pillarBottom = Instance.new("Attachment")
    pillarBottom.Parent = burstPart
    local pillarTop = Instance.new("Attachment")
    pillarTop.Position = Vector3.new(0, 160, 0)
    pillarTop.Parent = burstPart
    local pillar = Instance.new("Beam")
    pillar.Attachment0 = pillarBottom
    pillar.Attachment1 = pillarTop
    pillar.Texture = SPARK_TEXTURE
    pillar.TextureSpeed = 4
    pillar.TextureLength = 6
    pillar.LightEmission = 1
    pillar.LightInfluence = 0
    pillar.Brightness = 8
    pillar.Color = colorSequence(0, WHITE, 0.4, PURPLE, 1, CYAN)
    pillar.Width0 = 8
    pillar.Width1 = 2
    pillar.FaceCamera = true
    pillar.Transparency = NumberSequence.new(1)
    pillar.Parent = burstPart
    local flashLight = Instance.new("PointLight")
    flashLight.Color = CYAN
    flashLight.Range = 45
    flashLight.Brightness = 0
    flashLight.Parent = burstPart

    local startClock, nextBoltAt, burstAt = os.clock(), 0, os.clock() + 2
    local renderConnection
    renderConnection = RunService.RenderStepped:Connect(function()
        if not statue.Parent then
            renderConnection:Disconnect()
            fxFolder:Destroy()
            return
        end
        local camera = workspace.CurrentCamera
        local near = camera
            and (camera.CFrame.Position - center).Magnitude < 160
            and player:GetAttribute("ReducedMotion") ~= true
        -- unparent (not destroy) when far so the FX can come back instantly
        fxFolder.Parent = near and workspace or nil
        if not near then
            return
        end
        local elapsed = os.clock() - startClock
        -- spin each ring around the vertical axis through `center`, keeping its original offset
        outerRing:PivotTo(
            CFrame.new(center) * CFrame.Angles(0, elapsed * 0.35, 0) * (CFrame.new(center):Inverse() * outerPivot)
        )
        innerRing:PivotTo(
            CFrame.new(center) * CFrame.Angles(0, -elapsed * 0.8, 0) * (CFrame.new(center):Inverse() * innerPivot)
        )
        glow.Brightness = 4 + 3 * (0.5 + 0.5 * math.sin(elapsed * 3))
        if os.clock() >= nextBoltAt then
            nextBoltAt = os.clock() + 0.07
            for _, bolt in bolts do
                if math.random() < 0.6 then
                    rerouteBolt(bolt)
                end
            end
        end
        if os.clock() >= burstAt then
            burstAt = os.clock() + 7
            shockEmitter:Emit(2)
            flashEmitter:Emit(1)
            debrisEmitter:Emit(40)
            flashLight.Brightness = 18
            TweenService:Create(flashLight, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
            -- fade the sky pillar out over ~0.84 s (21 steps x 0.04 s)
            task.spawn(function()
                for step = 0, 20 do
                    local fadeAlpha = step / 20
                    pillar.Transparency = numberSequence(0, fadeAlpha, 0.7, 0.3 + 0.7 * fadeAlpha, 1, 1)
                    pillar.Width0 = 10 - 7 * fadeAlpha
                    task.wait(0.04)
                end
                pillar.Transparency = NumberSequence.new(1)
            end)
            for _, bolt in bolts do
                rerouteBolt(bolt)
                bolt.b.Enabled = true
            end
        end
    end)
end

local function watchPlot(plot)
    plot.ChildAdded:Connect(function(child)
        if child.Name == "OwnerShowcase" then
            task.defer(build, child)
        end
    end)
    local showcase = plot:FindFirstChild("OwnerShowcase")
    if showcase then
        task.spawn(build, showcase)
    end
end

local plots = workspace:WaitForChild("Plots")
for _, plot in plots:GetChildren() do
    watchPlot(plot)
end
plots.ChildAdded:Connect(watchPlot)
