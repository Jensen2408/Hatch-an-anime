--[[ StarterPlayerScripts.GoldTempleEffects  (LocalScript)
Local-only shimmer for temples whose model has TempleAppearance == "Gold": gold motes at the corners and top,
two pulsing point lights, a faint Highlight sheen, four rising Beam ribbons and a ground pulse ring every 8 s.
New gold temples get the effect 4.5 s after they appear (after the rise animation) with an initial burst.
Effects switch off beyond 140 studs from the camera and are removed when the model leaves workspace or
loses the Gold appearance. Updated at ~10 Hz.
]]
local RunService = game:GetService("RunService")
local activeTemples, pendingTemples = {}, {}
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
-- Expanding neon ring on the ground plus a small burst from every emitter.
local function pulse(item)
    local ring = Instance.new("Part")
    ring.Name = "GoldPowerPulse"
    ring.Shape = Enum.PartType.Cylinder
    ring.Material = Enum.Material.Neon
    ring.Color = Color3.fromRGB(255, 211, 91)
    ring.Anchored = true
    ring.CanCollide = false
    ring.CanTouch = false
    ring.CanQuery = false
    ring.CastShadow = false
    ring.Transparency = 0.88
    ring.Size = Vector3.new(0.06, item.radius * 0.8, item.radius * 0.8)
    ring.CFrame = item.root.CFrame * CFrame.new(0, -item.height * 0.5 + 0.15, 0) * CFrame.Angles(0, 0, math.pi * 0.5)
    ring.Parent = item.root
    TweenService:Create(
        ring,
        TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
        { Size = Vector3.new(0.06, item.radius * 2.3, item.radius * 2.3), Transparency = 1 }
    ):Play()
    Debris:AddItem(ring, 1.5)
    for _, emitter in ipairs(item.emitters) do
        emitter:Emit(3)
    end
end
local function addGoldEffects(model, burst)
    if
        not model:IsDescendantOf(workspace)
        or model:GetAttribute("TempleAppearance") ~= "Gold"
        or activeTemples[model]
    then
        return
    end
    local boxCFrame, size = model:GetBoundingBox()
    local root = Instance.new("Part")
    root.Name = "LocalGoldShimmer"
    root.Size = Vector3.one
    root.Anchored = true
    root.Transparency = 1
    root.CanCollide = false
    root.CanTouch = false
    root.CanQuery = false
    root.CastShadow = false
    root.CFrame = boxCFrame
    root.Parent = workspace
    local emitters, lights = {}, {}
    -- emitters 1-4 sit near the four footprint corners, 5 above the roof
    for i = 1, 5 do
        local attachment = Instance.new("Attachment")
        local offsetX, offsetZ = 0, 0
        if i <= 4 then
            offsetX = (i <= 2 and -1 or 1) * size.X * 0.38
            offsetZ = (i % 2 == 0 and -1 or 1) * size.Z * 0.38
        end
        attachment.Position = Vector3.new(offsetX, i == 5 and size.Y * 0.44 or size.Y * 0.05, offsetZ)
        attachment.Parent = root
        local emitter = Instance.new("ParticleEmitter")
        emitter.Name = "GoldMotes"
        emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        emitter.Color = ColorSequence.new(Color3.fromRGB(255, 242, 178), Color3.fromRGB(255, 175, 36))
        emitter.LightEmission = 1
        emitter.LightInfluence = 0.1
        emitter.Rate = i == 5 and 1.5 or 1
        emitter.Lifetime = NumberRange.new(1.8, 3)
        emitter.Speed = NumberRange.new(0.6, 1.8)
        emitter.Acceleration = Vector3.new(0, 0.3, 0)
        emitter.SpreadAngle = Vector2.new(35, 35)
        emitter.Rotation = NumberRange.new(0, 180)
        emitter.RotSpeed = NumberRange.new(-30, 30)
        emitter.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.25, 0.28),
            NumberSequenceKeypoint.new(0.6, 0.12),
            NumberSequenceKeypoint.new(1, 0),
        })
        emitter.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0.1),
            NumberSequenceKeypoint.new(0.7, 0.4),
            NumberSequenceKeypoint.new(1, 1),
        })
        emitter.Parent = attachment
        table.insert(emitters, emitter)
        if burst then
            emitter:Emit(i == 5 and 14 or 5)
        end
        if i == 1 or i == 4 then
            local light = Instance.new("PointLight")
            light.Color = Color3.fromRGB(255, 195, 74)
            light.Brightness = 0.45
            light.Range = 14
            light.Shadows = false
            light.Parent = attachment
            table.insert(lights, light)
        end
    end
    local sheen = Instance.new("Highlight")
    sheen.Name = "GoldSheen"
    sheen.Adornee = model
    sheen.DepthMode = Enum.HighlightDepthMode.Occluded
    sheen.FillColor = Color3.fromRGB(255, 211, 102)
    sheen.OutlineTransparency = 1
    sheen.FillTransparency = 0.96
    sheen.Parent = root
    local ribbons = {}
    for i = 1, 4 do
        local low = Instance.new("Attachment")
        low.Name = "AuraBase"
        low.Parent = root
        local high = Instance.new("Attachment")
        high.Name = "AuraTip"
        high.Parent = root
        local beam = Instance.new("Beam")
        beam.Name = "RisingGoldEnergy"
        beam.Attachment0 = low
        beam.Attachment1 = high
        beam.FaceCamera = true
        beam.Segments = 12
        beam.Width0 = 0.14
        beam.Width1 = 0.02
        beam.Color = ColorSequence.new(Color3.fromRGB(255, 180, 36), Color3.fromRGB(255, 245, 186))
        beam.LightEmission = 1
        beam.LightInfluence = 0
        beam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0.55),
            NumberSequenceKeypoint.new(0.7, 0.75),
            NumberSequenceKeypoint.new(1, 1),
        })
        beam.CurveSize0 = size.Y * 0.16
        beam.CurveSize1 = -size.Y * 0.12
        beam.Parent = root
        table.insert(ribbons, { low = low, high = high, beam = beam, angle = i * math.pi * 0.5 })
    end
    local item = {
        root = root,
        emitters = emitters,
        lights = lights,
        sheen = sheen,
        phase = math.random() * 6,
        ribbons = ribbons,
        radius = math.max(size.X, size.Z) * 0.52,
        height = size.Y,
        nextPulse = os.clock() + 2,
    }
    activeTemples[model] = item
    if burst then
        pulse(item)
    end
end
local function queueGoldEffects(model)
    if
        not model:IsA("Model")
        or model:GetAttribute("TempleAppearance") ~= "Gold"
        or pendingTemples[model]
        or activeTemples[model]
    then
        return
    end
    pendingTemples[model] = true
    -- Wait until the ground-rise assembly has reached its final positions.
    task.delay(4.5, function()
        pendingTemples[model] = nil
        addGoldEffects(model, true)
    end)
end
workspace.DescendantAdded:Connect(queueGoldEffects)
for _, descendant in ipairs(workspace:GetDescendants()) do
    if descendant:IsA("Model") then
        addGoldEffects(descendant, false)
    end
end
local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
    elapsed += dt
    if elapsed < 0.1 then
        return
    end
    elapsed = 0
    local camera = workspace.CurrentCamera
    local now = os.clock()
    for model, item in pairs(activeTemples) do
        if not model:IsDescendantOf(workspace) or model:GetAttribute("TempleAppearance") ~= "Gold" then
            item.root:Destroy()
            activeTemples[model] = nil
        else
            local near = camera and (camera.CFrame.Position - item.root.Position).Magnitude < 140 or false
            for _, emitter in ipairs(item.emitters) do
                emitter.Enabled = near
            end
            for _, light in ipairs(item.lights) do
                light.Enabled = near
                light.Brightness = 0.35 + 0.12 * (0.5 + 0.5 * math.sin(now * 1.5 + item.phase))
            end
            for _, ribbon in ipairs(item.ribbons) do
                ribbon.beam.Enabled = near
                if near then
                    local angle = now * 0.22 + ribbon.angle
                    ribbon.low.Position =
                        Vector3.new(math.cos(angle) * item.radius, -item.height * 0.48, math.sin(angle) * item.radius)
                    ribbon.high.Position = Vector3.new(
                        math.cos(angle + 0.55) * item.radius * 0.65,
                        item.height * 0.38,
                        math.sin(angle + 0.55) * item.radius * 0.65
                    )
                end
            end
            if near and now >= item.nextPulse then
                pulse(item)
                item.nextPulse = now + 8
            end
            item.sheen.Enabled = near
            item.sheen.FillTransparency = 0.95 + 0.025 * math.sin(now * 1.15 + item.phase)
        end
    end
end)
