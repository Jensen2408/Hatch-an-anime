-- Client VFX around the owner's showcase statue: spinning ground sigil, lightning, pulsing light,
-- and a power burst (shockwave + sky pillar + flash) every 7 s. Only runs while you're within 160 studs.
local RunService = game:GetService("RunService")
local TS = game:GetService("TweenService")
local player = game:GetService("Players").LocalPlayer
local W, P, D, C =
    Color3.fromRGB(255, 245, 255),
    Color3.fromRGB(200, 90, 255),
    Color3.fromRGB(110, 30, 190),
    Color3.fromRGB(90, 220, 255)
local SPARK, SHOCK, CORE =
    "rbxasset://textures/particles/sparkles_main.dds",
    "rbxasset://textures/particles/explosion01_shockwave_main.dds",
    "rbxasset://textures/particles/explosion01_core_main.dds"
local function cs(...)
    local k, a = {}, { ... }
    for i = 1, #a, 2 do
        table.insert(k, ColorSequenceKeypoint.new(a[i], a[i + 1]))
    end
    return ColorSequence.new(k)
end
local function ns(...)
    local k, a = {}, { ... }
    for i = 1, #a, 2 do
        table.insert(k, NumberSequenceKeypoint.new(a[i], a[i + 1]))
    end
    return NumberSequence.new(k)
end

local function build(statue)
    local root = statue:WaitForChild("HumanoidRootPart", 10)
    if not root then
        return
    end
    local hum = statue:FindFirstChildOfClass("Humanoid")
    local feet = root.Position.Y - (hum and hum.HipHeight or 2) - root.Size.Y / 2
    local center = Vector3.new(root.Position.X, feet, root.Position.Z)
    local fx = Instance.new("Folder")
    fx.Name = "ShowcaseFXLocal"
    fx.Parent = workspace
    local function part(name, cf)
        local p = Instance.new("Part")
        p.Name = name
        p.Size = Vector3.one
        p.CFrame = cf
        p.Anchored = true
        p.CanCollide = false
        p.CanQuery = false
        p.CanTouch = false
        p.Transparency = 1
        p.CastShadow = false
        p.Parent = fx
        return p
    end
    -- sigil rings (neon segments)
    local function ring(r, n, w, col, y)
        local m = Instance.new("Model")
        m.Parent = fx
        for i = 1, n do
            if i % 4 ~= 0 then
                local a = i / n * math.pi * 2
                local seg = Instance.new("Part")
                seg.Anchored = true
                seg.CanCollide = false
                seg.CanQuery = false
                seg.CanTouch = false
                seg.CastShadow = false
                seg.Material = Enum.Material.Neon
                seg.Color = col
                seg.Size = Vector3.new(w, 0.06, 2 * math.pi * r / n * 0.9)
                seg.CFrame = CFrame.new(center + Vector3.new(0, y, 0)) * CFrame.Angles(0, a, 0) * CFrame.new(r, 0, 0)
                seg.Parent = m
            end
        end
        return m, m:GetPivot()
    end
    local outer, outerPivot = ring(6.5, 40, 0.35, P, 0.05)
    local inner, innerPivot = ring(4.2, 28, 0.25, C, 0.07)
    local glowPart = part("Glow", CFrame.new(center + Vector3.new(0, 0.4, 0)))
    local glow = Instance.new("PointLight")
    glow.Color = P
    glow.Range = 18
    glow.Brightness = 5
    glow.Parent = glowPart
    -- lightning
    local bolts = part("Bolts", CFrame.new(center))
    local beams = {}
    for i = 1, 5 do
        local a0 = Instance.new("Attachment")
        a0.Parent = bolts
        local a1 = Instance.new("Attachment")
        a1.Parent = bolts
        local b = Instance.new("Beam")
        b.Attachment0 = a0
        b.Attachment1 = a1
        b.Texture = SPARK
        b.LightEmission = 1
        b.LightInfluence = 0
        b.Brightness = 10
        b.Color = cs(0, W, 0.5, C, 1, W)
        b.Width0 = 0.4
        b.Width1 = 0.1
        b.FaceCamera = true
        b.Segments = 12
        b.Parent = bolts
        beams[i] = { a0 = a0, a1 = a1, b = b }
    end
    local function reroute(t)
        local ang = math.random() * math.pi * 2
        local r = math.random() < 0.5 and 4 + math.random() * 2.5 or 1.5 + math.random() * 1.5
        t.a0.WorldPosition = root.Position
            + Vector3.new(math.random() * 2 - 1, math.random() * 4 - 1.5, math.random() * 1.2 - 0.6)
        t.a1.WorldPosition = center + Vector3.new(math.cos(ang) * r, math.random() * 1.5, math.sin(ang) * r)
        t.b.CurveSize0, t.b.CurveSize1 = math.random() * 6 - 3, math.random() * 6 - 3
        t.b.Enabled = math.random() < 0.7
    end
    -- burst
    local burst = part("Burst", CFrame.new(center + Vector3.new(0, 0.2, 0)))
    local function em(props)
        local e = Instance.new("ParticleEmitter")
        e.Enabled = false
        for k, v in props do
            e[k] = v
        end
        e.Parent = burst
        return e
    end
    local shock = em({
        Texture = SHOCK,
        Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
        Speed = NumberRange.new(0.01),
        EmissionDirection = Enum.NormalId.Top,
        Color = cs(0, W, 0.4, P, 1, D),
        LightEmission = 1,
        LightInfluence = 0,
        Brightness = 5,
        Size = ns(0, 1, 1, 28),
        Transparency = ns(0, 0, 0.6, 0.3, 1, 1),
        Lifetime = NumberRange.new(0.8),
    })
    local flash = em({
        Texture = CORE,
        Color = cs(0, W, 0.5, C, 1, P),
        LightEmission = 1,
        LightInfluence = 0,
        Brightness = 6,
        Size = ns(0, 4, 1, 15),
        Transparency = ns(0, 0, 1, 1),
        Lifetime = NumberRange.new(0.35),
        Speed = NumberRange.new(0),
    })
    local debris = em({
        Texture = SPARK,
        Color = cs(0, W, 0.5, P, 1, C),
        LightEmission = 1,
        LightInfluence = 0,
        Brightness = 6,
        Size = ns(0, 0.6, 1, 0),
        Lifetime = NumberRange.new(0.8, 1.4),
        Speed = NumberRange.new(25, 45),
        SpreadAngle = Vector2.new(80, 80),
        EmissionDirection = Enum.NormalId.Top,
        Acceleration = Vector3.new(0, -30, 0),
        Drag = 2,
        Orientation = Enum.ParticleOrientation.VelocityParallel,
    })
    local p0 = Instance.new("Attachment")
    p0.Parent = burst
    local p1 = Instance.new("Attachment")
    p1.Position = Vector3.new(0, 160, 0)
    p1.Parent = burst
    local pillar = Instance.new("Beam")
    pillar.Attachment0 = p0
    pillar.Attachment1 = p1
    pillar.Texture = SPARK
    pillar.TextureSpeed = 4
    pillar.TextureLength = 6
    pillar.LightEmission = 1
    pillar.LightInfluence = 0
    pillar.Brightness = 8
    pillar.Color = cs(0, W, 0.4, P, 1, C)
    pillar.Width0 = 8
    pillar.Width1 = 2
    pillar.FaceCamera = true
    pillar.Transparency = NumberSequence.new(1)
    pillar.Parent = burst
    local fl = Instance.new("PointLight")
    fl.Color = C
    fl.Range = 45
    fl.Brightness = 0
    fl.Parent = burst

    local t0, nextBolt, burstAt = os.clock(), 0, os.clock() + 2
    local conn
    conn = RunService.RenderStepped:Connect(function()
        if not statue.Parent then
            conn:Disconnect()
            fx:Destroy()
            return
        end
        local cam = workspace.CurrentCamera
        local near = cam
            and (cam.CFrame.Position - center).Magnitude < 160
            and player:GetAttribute("ReducedMotion") ~= true
        fx.Parent = near and workspace or nil
        if not near then
            return
        end
        local t = os.clock() - t0
        outer:PivotTo(CFrame.new(center) * CFrame.Angles(0, t * 0.35, 0) * (CFrame.new(center):Inverse() * outerPivot))
        inner:PivotTo(CFrame.new(center) * CFrame.Angles(0, -t * 0.8, 0) * (CFrame.new(center):Inverse() * innerPivot))
        glow.Brightness = 4 + 3 * (0.5 + 0.5 * math.sin(t * 3))
        if os.clock() >= nextBolt then
            nextBolt = os.clock() + 0.07
            for _, b in beams do
                if math.random() < 0.6 then
                    reroute(b)
                end
            end
        end
        if os.clock() >= burstAt then
            burstAt = os.clock() + 7
            shock:Emit(2)
            flash:Emit(1)
            debris:Emit(40)
            fl.Brightness = 18
            TS:Create(fl, TweenInfo.new(0.9, Enum.EasingStyle.Quad), { Brightness = 0 }):Play()
            task.spawn(function()
                for k = 0, 20 do
                    local a = k / 20
                    pillar.Transparency = ns(0, a, 0.7, 0.3 + 0.7 * a, 1, 1)
                    pillar.Width0 = 10 - 7 * a
                    task.wait(0.04)
                end
                pillar.Transparency = NumberSequence.new(1)
            end)
            for _, b in beams do
                reroute(b)
                b.b.Enabled = true
            end
        end
    end)
end

local function watch(plot)
    plot.ChildAdded:Connect(function(c)
        if c.Name == "OwnerShowcase" then
            task.defer(build, c)
        end
    end)
    local s = plot:FindFirstChild("OwnerShowcase")
    if s then
        task.spawn(build, s)
    end
end
local plots = workspace:WaitForChild("Plots")
for _, p in plots:GetChildren() do
    watch(p)
end
plots.ChildAdded:Connect(watch)
