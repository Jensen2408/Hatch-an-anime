local RunService = game:GetService("RunService")
local active, pending = {}, {}
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
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
    for _, e in ipairs(item.emitters) do
        e:Emit(3)
    end
end
local function add(model, burst)
    if not model:IsDescendantOf(workspace) or model:GetAttribute("TempleAppearance") ~= "Gold" or active[model] then
        return
    end
    local cf, size = model:GetBoundingBox()
    local root = Instance.new("Part")
    root.Name = "LocalGoldShimmer"
    root.Size = Vector3.one
    root.Anchored = true
    root.Transparency = 1
    root.CanCollide = false
    root.CanTouch = false
    root.CanQuery = false
    root.CastShadow = false
    root.CFrame = cf
    root.Parent = workspace
    local emitters, lights = {}, {}
    for i = 1, 5 do
        local a = Instance.new("Attachment")
        local x, z = 0, 0
        if i <= 4 then
            x = (i <= 2 and -1 or 1) * size.X * 0.38
            z = (i % 2 == 0 and -1 or 1) * size.Z * 0.38
        end
        a.Position = Vector3.new(x, i == 5 and size.Y * 0.44 or size.Y * 0.05, z)
        a.Parent = root
        local e = Instance.new("ParticleEmitter")
        e.Name = "GoldMotes"
        e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
        e.Color = ColorSequence.new(Color3.fromRGB(255, 242, 178), Color3.fromRGB(255, 175, 36))
        e.LightEmission = 1
        e.LightInfluence = 0.1
        e.Rate = i == 5 and 1.5 or 1
        e.Lifetime = NumberRange.new(1.8, 3)
        e.Speed = NumberRange.new(0.6, 1.8)
        e.Acceleration = Vector3.new(0, 0.3, 0)
        e.SpreadAngle = Vector2.new(35, 35)
        e.Rotation = NumberRange.new(0, 180)
        e.RotSpeed = NumberRange.new(-30, 30)
        e.Size = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 0),
            NumberSequenceKeypoint.new(0.25, 0.28),
            NumberSequenceKeypoint.new(0.6, 0.12),
            NumberSequenceKeypoint.new(1, 0),
        })
        e.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, 0.1),
            NumberSequenceKeypoint.new(0.7, 0.4),
            NumberSequenceKeypoint.new(1, 1),
        })
        e.Parent = a
        table.insert(emitters, e)
        if burst then
            e:Emit(i == 5 and 14 or 5)
        end
        if i == 1 or i == 4 then
            local light = Instance.new("PointLight")
            light.Color = Color3.fromRGB(255, 195, 74)
            light.Brightness = 0.45
            light.Range = 14
            light.Shadows = false
            light.Parent = a
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
    active[model] = item
    if burst then
        pulse(item)
    end
end
local function queue(model)
    if
        not model:IsA("Model")
        or model:GetAttribute("TempleAppearance") ~= "Gold"
        or pending[model]
        or active[model]
    then
        return
    end
    pending[model] = true
    -- Wait until the ground-rise assembly has reached its final positions.
    task.delay(4.5, function()
        pending[model] = nil
        add(model, true)
    end)
end
workspace.DescendantAdded:Connect(queue)
for _, v in ipairs(workspace:GetDescendants()) do
    if v:IsA("Model") then
        add(v, false)
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
    for model, item in pairs(active) do
        if not model:IsDescendantOf(workspace) or model:GetAttribute("TempleAppearance") ~= "Gold" then
            item.root:Destroy()
            active[model] = nil
        else
            local near = camera and (camera.CFrame.Position - item.root.Position).Magnitude < 140 or false
            for _, e in ipairs(item.emitters) do
                e.Enabled = near
            end
            for _, light in ipairs(item.lights) do
                light.Enabled = near
                light.Brightness = 0.35 + 0.12 * (0.5 + 0.5 * math.sin(now * 1.5 + item.phase))
            end
            for _, r in ipairs(item.ribbons) do
                r.beam.Enabled = near
                if near then
                    local angle = now * 0.22 + r.angle
                    r.low.Position =
                        Vector3.new(math.cos(angle) * item.radius, -item.height * 0.48, math.sin(angle) * item.radius)
                    r.high.Position = Vector3.new(
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
