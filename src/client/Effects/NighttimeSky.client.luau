local Lighting = game:GetService("Lighting")
local Tween = game:GetService("TweenService")
local Players = game:GetService("Players")
local Run = game:GetService("RunService")
local player = Players.LocalPlayer
local day = {
    Brightness = Lighting.Brightness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ExposureCompensation = Lighting.ExposureCompensation,
}
local dayClock = Lighting.ClockTime
local night = {
    Brightness = 2.4,
    Ambient = Color3.fromRGB(92, 88, 138),
    OutdoorAmbient = Color3.fromRGB(118, 140, 190),
    ExposureCompensation = 0.25,
}
local sky = Lighting:FindFirstChildOfClass("Sky")
local skyDay = sky
    and { StarCount = sky.StarCount, MoonAngularSize = sky.MoonAngularSize, SunAngularSize = sky.SunAngularSize }
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local airDay = atmosphere
    and {
        Density = atmosphere.Density,
        Offset = atmosphere.Offset,
        Color = atmosphere.Color,
        Decay = atmosphere.Decay,
        Glare = atmosphere.Glare,
        Haze = atmosphere.Haze,
    }
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "NighttimeGrade"
grade.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Name = "NighttimeBloom"
bloom.Intensity = 0
bloom.Threshold = 1.3
bloom.Size = 30
bloom.Parent = Lighting
local strength = Instance.new("NumberValue")
strength.Name = "NightBlend"
strength.Parent = script
local clock = Instance.new("NumberValue")
clock.Value = dayClock
clock.Parent = script
clock.Changed:Connect(function(v)
    Lighting.ClockTime = v % 24
end)
local fx = Instance.new("Folder")
fx.Name = "NighttimeLocalFX"
fx.Parent = workspace
local function part(name)
    local p = Instance.new("Part")
    p.Name = name
    p.Anchored = true
    p.Transparency = 1
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Size = Vector3.one
    p.Parent = fx
    return p
end
local center = Vector3.zero
local count = 0
local plots = workspace:WaitForChild("Plots")
for _, plot in plots:GetChildren() do
    local anchor = plot:FindFirstChild("TempleAnchor")
    if anchor then
        center += anchor.Position
        count += 1
    end
end
if count > 0 then
    center /= count
end
local ribbons = {}
for i = 1, 14 do
    local p = part("AuroraRibbon" .. i)
    local a = Instance.new("Attachment")
    a.Parent = p
    local b = Instance.new("Attachment")
    b.Parent = p
    local beam = Instance.new("Beam")
    beam.Name = "Aurora"
    beam.Attachment0 = a
    beam.Attachment1 = b
    beam.FaceCamera = true
    beam.Segments = 40
    beam.Width0 = 24 + i * 2.2
    beam.Width1 = 36 + i * 2
    beam.LightEmission = 1
    beam.LightInfluence = 0
    beam.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(74, 255, 205)),
        ColorSequenceKeypoint.new(0.45, Color3.fromRGB(93, 146, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(202, 93, 255)),
    })
    beam.Transparency = NumberSequence.new(1)
    beam.Parent = p
    table.insert(ribbons, { a = a, b = b, beam = beam, index = i })
end
local motes = part("MoonlitMotes")
local particles = Instance.new("ParticleEmitter")
particles.Name = "DriftingStars"
particles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
particles.Color = ColorSequence.new(Color3.fromRGB(157, 219, 255), Color3.fromRGB(220, 174, 255))
particles.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(0.25, 0.15),
    NumberSequenceKeypoint.new(0.8, 0.12),
    NumberSequenceKeypoint.new(1, 0),
})
particles.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.25, 0.3),
    NumberSequenceKeypoint.new(0.8, 0.5),
    NumberSequenceKeypoint.new(1, 1),
})
particles.LightEmission = 1
particles.Lifetime = NumberRange.new(3, 6)
particles.Speed = NumberRange.new(0.5, 2)
particles.Acceleration = Vector3.new(0.25, 0.35, 0)
particles.SpreadAngle = Vector2.new(180, 180)
particles.Rate = 0
particles.Parent = motes
motes.Size = Vector3.new(85, 25, 85)
local gui = Instance.new("ScreenGui")
gui.Name = "NighttimeStatus"
gui.ResetOnSpawn = false
gui.DisplayOrder = 50
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui") -- replaced by NighttimeHUD
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, -115)
panel.Size = UDim2.new(0.8, 0, 0, 78)
panel.BackgroundColor3 = Color3.fromRGB(19, 20, 48)
panel.BackgroundTransparency = 0.08
panel.Parent = gui
local limit = Instance.new("UISizeConstraint")
limit.MaxSize = Vector2.new(470, 78)
limit.Parent = panel
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(158, 139, 255)
stroke.Thickness = 2
stroke.Parent = panel
local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new(Color3.fromRGB(115, 150, 255), Color3.fromRGB(236, 150, 255))
grad.Parent = stroke
local function text(y, height, size, color)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Position = UDim2.new(0, 12, 0, y)
    l.Size = UDim2.new(1, -24, 0, height)
    l.Font = Enum.Font.GothamBold
    l.TextSize = size
    l.TextColor3 = color
    l.Parent = panel
    return l
end
local title = text(8, 27, 22, Color3.fromRGB(237, 227, 255))
title.Text = "✦ NIGHTTIME ✦"
local bonus = text(37, 20, 13, Color3.fromRGB(166, 225, 255))
bonus.Text = "2× CASH   •   2× HATCH SPEED   •   2× RIVER LUCK"
local track = Instance.new("Frame")
track.BackgroundColor3 = Color3.fromRGB(45, 46, 76)
track.BorderSizePixel = 0
track.Position = UDim2.new(0, 15, 1, -10)
track.Size = UDim2.new(1, -30, 0, 3)
track.Parent = panel
local bar = Instance.new("Frame")
bar.BackgroundColor3 = Color3.fromRGB(143, 208, 255)
bar.BorderSizePixel = 0
bar.Size = UDim2.fromScale(1, 1)
bar.Parent = track
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1)
flash.BackgroundColor3 = Color3.fromRGB(154, 166, 255)
flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0
flash.Parent = gui
local tweens = {}
local function tween(obj, duration, props, style)
    local tw =
        Tween:Create(obj, TweenInfo.new(duration, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props)
    table.insert(tweens, tw)
    tw:Play()
    return tw
end
local initialized = false
local function change()
    for _, tw in tweens do
        tw:Cancel()
    end
    table.clear(tweens)
    local active = workspace:GetAttribute("NighttimeActive") == true
    if not initialized and not active then
        initialized = true
        return
    end
    initialized = true
    tween(Lighting, 4, active and night or day)
    local currentClock = Lighting.ClockTime
    local desired = active and 0 or dayClock
    local delta = (desired - currentClock + 12) % 24 - 12
    clock.Value = currentClock
    local target = currentClock + delta
    tween(clock, 4, { Value = target })
    tween(strength, 4, { Value = active and 1 or 0 })
    tween(grade, 4, {
        TintColor = active and Color3.fromRGB(207, 219, 255) or Color3.new(1, 1, 1),
        Contrast = active and 0.12 or 0,
        Saturation = active and 0.12 or 0,
    })
    tween(bloom, 4, { Intensity = active and 0.35 or 0 })
    if atmosphere then
        tween(atmosphere, 4, active and {
            Density = 0.2,
            Offset = 0.15,
            Color = Color3.fromRGB(150, 172, 226),
            Decay = Color3.fromRGB(98, 86, 156),
            Glare = 0.15,
            Haze = 1,
        } or airDay)
    end
    if sky then
        tween(sky, 4, active and { StarCount = 5000, MoonAngularSize = 21, SunAngularSize = 0 } or skyDay)
    end
    tween(
        panel,
        0.65,
        { Position = active and UDim2.new(0.5, 0, 0, 16) or UDim2.new(0.5, 0, 0, -115) },
        Enum.EasingStyle.Quart
    )
    flash.BackgroundTransparency = 1
end
workspace:GetAttributeChangedSignal("NighttimeActive"):Connect(change)
change()
local timer = 0
local previousMode = ""
local bannerTween
Run.RenderStepped:Connect(function(dt)
    local now = workspace:GetServerTimeNow()
    local active = workspace:GetAttribute("NighttimeActive") == true
    local nextAt = workspace:GetAttribute("NighttimeNextAt") or (math.floor(now / 300) + 1) * 300
    local untilNight = nextAt - now
    local preview = not active and untilNight > 0 and untilNight <= 10
    local mode = active and "active" or preview and "countdown" or "hidden"
    if mode ~= previousMode then
        previousMode = mode
        if bannerTween then
            bannerTween:Cancel()
        end
        bannerTween = Tween:Create(
            panel,
            TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { Position = mode ~= "hidden" and UDim2.new(0.5, 0, 0, 16) or UDim2.new(0.5, 0, 0, -115) }
        )
        bannerTween:Play()
    end
    timer += dt
    if timer > 0.05 then
        timer = 0
        if preview then
            title.Text = "✦ NIGHTTIME IN " .. math.ceil(untilNight) .. " ✦"
            bonus.Text = "GET READY  •  DOUBLE CASH, HATCH SPEED & RIVER LUCK"
            bonus.TextSize = 12
            bar.Size = UDim2.fromScale(math.clamp(1 - untilNight / 10, 0, 1), 1)
            stroke.Thickness = 2 + math.max(0, math.sin(now * math.pi * 2)) * (untilNight <= 3 and 1.5 or 0.5)
        elseif active then
            local left = math.max(0, (workspace:GetAttribute("NighttimeEndsAt") or 0) - now)
            title.Text = "✦ NIGHTTIME  " .. math.ceil(left) .. "s ✦"
            bonus.Text = "2× CASH   •   2× HATCH SPEED   •   2× RIVER LUCK"
            bonus.TextSize = 13
            bar.Size = UDim2.fromScale(math.clamp(left / 20, 0, 1), 1)
            stroke.Thickness = 2
        end
        grad.Rotation = (now * 12) % 360
    end
    local k = player:GetAttribute("NightFX") == false and 0 or strength.Value
    if k < 0.001 then
        for _, r in ribbons do
            r.beam.Enabled = false
        end
        particles.Rate = 0
        return
    end

    for _, r in ribbons do
        local i = r.index
        r.beam.Enabled = true
        r.a.Position = center + Vector3.new(-420, 150 + i * 6 + math.sin(now * 0.22 + i) * 12, -200 + i * 24)
        r.b.Position = center + Vector3.new(420, 185 + i * 5 + math.cos(now * 0.18 + i) * 14, -150 + i * 24)
        r.beam.CurveSize0 = 110 + math.sin(now * 0.2 + i) * 70
        r.beam.CurveSize1 = -110 + math.cos(now * 0.17 + i) * 70
        local alpha = 1 - k * (0.1 + 0.07 * math.sin(now * 0.4 + i) ^ 2)
        r.beam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, alpha),
            NumberSequenceKeypoint.new(0.7, alpha),
            NumberSequenceKeypoint.new(1, 1),
        })
    end
    local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if root then
        motes.Position = root.Position + Vector3.new(0, 10, 0)
    end
    particles.Rate = 12 * k
end)
