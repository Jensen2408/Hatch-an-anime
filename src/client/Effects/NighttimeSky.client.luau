-- NighttimeSky (LocalScript, StarterPlayerScripts)
-- Local night look, driven by the server's workspace attributes (NighttimeActive / NighttimeNextAt /
-- NighttimeEndsAt, see NighttimeService):
--   * 4 s tween of Lighting, ClockTime (shortest way round the 24 h dial), Sky, Atmosphere, plus a
--     "NighttimeGrade" ColorCorrection and "NighttimeBloom" effect added to Lighting.
--   * Aurora ribbons above the plots' average TempleAnchor and drifting star motes around the character,
--     scaled by the tweened NightBlend value (player attribute NightFX == false turns them off).
--   * A legacy "NighttimeStatus" banner ScreenGui. It is created with Enabled = false (replaced by NighttimeHUD)
--     but is still updated every frame.
-- The day values are captured from Lighting when the script starts.
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

-- Lighting snapshots / targets ------------------------------------------------------------------------------------
local dayLighting = {
    Brightness = Lighting.Brightness,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    ExposureCompensation = Lighting.ExposureCompensation,
}
local dayClockTime = Lighting.ClockTime
local NIGHT_LIGHTING = {
    Brightness = 2.4,
    Ambient = Color3.fromRGB(92, 88, 138),
    OutdoorAmbient = Color3.fromRGB(118, 140, 190),
    ExposureCompensation = 0.25,
}
local sky = Lighting:FindFirstChildOfClass("Sky")
local daySky = sky
    and { StarCount = sky.StarCount, MoonAngularSize = sky.MoonAngularSize, SunAngularSize = sky.SunAngularSize }
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local dayAtmosphere = atmosphere
    and {
        Density = atmosphere.Density,
        Offset = atmosphere.Offset,
        Color = atmosphere.Color,
        Decay = atmosphere.Decay,
        Glare = atmosphere.Glare,
        Haze = atmosphere.Haze,
    }

-- Post effects and tween drivers ----------------------------------------------------------------------------------
local colorGrade = Instance.new("ColorCorrectionEffect")
colorGrade.Name = "NighttimeGrade"
colorGrade.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Name = "NighttimeBloom"
bloom.Intensity = 0
bloom.Threshold = 1.3
bloom.Size = 30
bloom.Parent = Lighting
-- 0 (day) .. 1 (night); tweened, scales the aurora + motes
local nightBlend = Instance.new("NumberValue")
nightBlend.Name = "NightBlend"
nightBlend.Parent = script
-- tweened unwrapped clock (may leave 0..24); written to Lighting.ClockTime modulo 24
local clockValue = Instance.new("NumberValue")
clockValue.Value = dayClockTime
clockValue.Parent = script
clockValue.Changed:Connect(function(value)
    Lighting.ClockTime = value % 24
end)

-- World FX: aurora ribbons + star motes -------------------------------------------------------------------------
local fxFolder = Instance.new("Folder")
fxFolder.Name = "NighttimeLocalFX"
fxFolder.Parent = workspace
local function makeHolderPart(name)
    local holder = Instance.new("Part")
    holder.Name = name
    holder.Anchored = true
    holder.Transparency = 1
    holder.CanCollide = false
    holder.CanTouch = false
    holder.CanQuery = false
    holder.CastShadow = false
    holder.Size = Vector3.one
    holder.Parent = fxFolder
    return holder
end
-- aurora is centred on the average TempleAnchor of the plots that exist at startup (origin if none)
local auroraCenter = Vector3.zero
local anchorCount = 0
local plots = workspace:WaitForChild("Plots")
for _, plot in plots:GetChildren() do
    local templeAnchor = plot:FindFirstChild("TempleAnchor")
    if templeAnchor then
        auroraCenter += templeAnchor.Position
        anchorCount += 1
    end
end
if anchorCount > 0 then
    auroraCenter /= anchorCount
end
local ribbons = {} -- { a, b (attachments), beam, index }
for i = 1, 14 do
    local ribbonPart = makeHolderPart("AuroraRibbon" .. i)
    local attachment0 = Instance.new("Attachment")
    attachment0.Parent = ribbonPart
    local attachment1 = Instance.new("Attachment")
    attachment1.Parent = ribbonPart
    local beam = Instance.new("Beam")
    beam.Name = "Aurora"
    beam.Attachment0 = attachment0
    beam.Attachment1 = attachment1
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
    beam.Parent = ribbonPart
    table.insert(ribbons, { a = attachment0, b = attachment1, beam = beam, index = i })
end
local motesPart = makeHolderPart("MoonlitMotes")
local motes = Instance.new("ParticleEmitter")
motes.Name = "DriftingStars"
motes.Texture = "rbxasset://textures/particles/sparkles_main.dds"
motes.Color = ColorSequence.new(Color3.fromRGB(157, 219, 255), Color3.fromRGB(220, 174, 255))
motes.Size = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(0.25, 0.15),
    NumberSequenceKeypoint.new(0.8, 0.12),
    NumberSequenceKeypoint.new(1, 0),
})
motes.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.25, 0.3),
    NumberSequenceKeypoint.new(0.8, 0.5),
    NumberSequenceKeypoint.new(1, 1),
})
motes.LightEmission = 1
motes.Lifetime = NumberRange.new(3, 6)
motes.Speed = NumberRange.new(0.5, 2)
motes.Acceleration = Vector3.new(0.25, 0.35, 0)
motes.SpreadAngle = Vector2.new(180, 180)
motes.Rate = 0
motes.Parent = motesPart
motesPart.Size = Vector3.new(85, 25, 85)

-- Legacy status banner (disabled) -------------------------------------------------------------------------------
local statusGui = Instance.new("ScreenGui")
statusGui.Name = "NighttimeStatus"
statusGui.ResetOnSpawn = false
statusGui.DisplayOrder = 50
statusGui.Enabled = false
statusGui.Parent = player:WaitForChild("PlayerGui") -- replaced by NighttimeHUD
local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, -115)
panel.Size = UDim2.new(0.8, 0, 0, 78)
panel.BackgroundColor3 = Color3.fromRGB(19, 20, 48)
panel.BackgroundTransparency = 0.08
panel.Parent = statusGui
local sizeLimit = Instance.new("UISizeConstraint")
sizeLimit.MaxSize = Vector2.new(470, 78)
sizeLimit.Parent = panel
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 16)
corner.Parent = panel
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(158, 139, 255)
stroke.Thickness = 2
stroke.Parent = panel
local strokeGradient = Instance.new("UIGradient")
strokeGradient.Color = ColorSequence.new(Color3.fromRGB(115, 150, 255), Color3.fromRGB(236, 150, 255))
strokeGradient.Parent = stroke
local function makeLabel(y, height, textSize, color)
    local label = Instance.new("TextLabel")
    label.BackgroundTransparency = 1
    label.Position = UDim2.new(0, 12, 0, y)
    label.Size = UDim2.new(1, -24, 0, height)
    label.Font = Enum.Font.GothamBold
    label.TextSize = textSize
    label.TextColor3 = color
    label.Parent = panel
    return label
end
local titleLabel = makeLabel(8, 27, 22, Color3.fromRGB(237, 227, 255))
titleLabel.Text = "✦ NIGHTTIME ✦"
local bonusLabel = makeLabel(37, 20, 13, Color3.fromRGB(166, 225, 255))
bonusLabel.Text = "2× CASH   •   2× HATCH SPEED   •   2× RIVER LUCK"
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
flash.Parent = statusGui

-- Day <-> night transition ----------------------------------------------------------------------------------------
local transitionTweens = {} -- cancelled when the state flips again mid-transition
local function playTween(instance, duration, props, easingStyle)
    local tween = TweenService:Create(
        instance,
        TweenInfo.new(duration, easingStyle or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
        props
    )
    table.insert(transitionTweens, tween)
    tween:Play()
    return tween
end
local initialized = false
local function onNighttimeChanged()
    for _, tween in transitionTweens do
        tween:Cancel()
    end
    table.clear(transitionTweens)
    local active = workspace:GetAttribute("NighttimeActive") == true
    -- first call during the day: nothing to tween, the world already has its day look
    if not initialized and not active then
        initialized = true
        return
    end
    initialized = true
    playTween(Lighting, 4, active and NIGHT_LIGHTING or dayLighting)
    -- tween ClockTime the short way round (delta in -12..12 h)
    local currentClock = Lighting.ClockTime
    local desiredClock = active and 0 or dayClockTime
    local clockDelta = (desiredClock - currentClock + 12) % 24 - 12
    clockValue.Value = currentClock
    local targetClock = currentClock + clockDelta
    playTween(clockValue, 4, { Value = targetClock })
    playTween(nightBlend, 4, { Value = active and 1 or 0 })
    playTween(colorGrade, 4, {
        TintColor = active and Color3.fromRGB(207, 219, 255) or Color3.new(1, 1, 1),
        Contrast = active and 0.12 or 0,
        Saturation = active and 0.12 or 0,
    })
    playTween(bloom, 4, { Intensity = active and 0.35 or 0 })
    if atmosphere then
        playTween(atmosphere, 4, active and {
            Density = 0.2,
            Offset = 0.15,
            Color = Color3.fromRGB(150, 172, 226),
            Decay = Color3.fromRGB(98, 86, 156),
            Glare = 0.15,
            Haze = 1,
        } or dayAtmosphere)
    end
    if sky then
        playTween(sky, 4, active and { StarCount = 5000, MoonAngularSize = 21, SunAngularSize = 0 } or daySky)
    end
    playTween(
        panel,
        0.65,
        { Position = active and UDim2.new(0.5, 0, 0, 16) or UDim2.new(0.5, 0, 0, -115) },
        Enum.EasingStyle.Quart
    )
    flash.BackgroundTransparency = 1
end
workspace:GetAttributeChangedSignal("NighttimeActive"):Connect(onNighttimeChanged)
onNighttimeChanged()

-- Per-frame: banner text (throttled to 20 Hz) + aurora / motes ----------------------------------------------------
local textTimer = 0
local previousMode = ""
local bannerTween
RunService.RenderStepped:Connect(function(dt)
    local now = workspace:GetServerTimeNow()
    local active = workspace:GetAttribute("NighttimeActive") == true
    -- fallback mirrors NighttimeService's 300 s cycle
    local nextAt = workspace:GetAttribute("NighttimeNextAt") or (math.floor(now / 300) + 1) * 300
    local untilNight = nextAt - now
    local preview = not active and untilNight > 0 and untilNight <= 10
    local mode = active and "active" or preview and "countdown" or "hidden"
    if mode ~= previousMode then
        previousMode = mode
        if bannerTween then
            bannerTween:Cancel()
        end
        bannerTween = TweenService:Create(
            panel,
            TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
            { Position = mode ~= "hidden" and UDim2.new(0.5, 0, 0, 16) or UDim2.new(0.5, 0, 0, -115) }
        )
        bannerTween:Play()
    end
    textTimer += dt
    if textTimer > 0.05 then
        textTimer = 0
        if preview then
            titleLabel.Text = "✦ NIGHTTIME IN " .. math.ceil(untilNight) .. " ✦"
            bonusLabel.Text = "GET READY  •  DOUBLE CASH, HATCH SPEED & RIVER LUCK"
            bonusLabel.TextSize = 12
            bar.Size = UDim2.fromScale(math.clamp(1 - untilNight / 10, 0, 1), 1)
            stroke.Thickness = 2 + math.max(0, math.sin(now * math.pi * 2)) * (untilNight <= 3 and 1.5 or 0.5)
        elseif active then
            local secondsLeft = math.max(0, (workspace:GetAttribute("NighttimeEndsAt") or 0) - now)
            titleLabel.Text = "✦ NIGHTTIME  " .. math.ceil(secondsLeft) .. "s ✦"
            bonusLabel.Text = "2× CASH   •   2× HATCH SPEED   •   2× RIVER LUCK"
            bonusLabel.TextSize = 13
            bar.Size = UDim2.fromScale(math.clamp(secondsLeft / 20, 0, 1), 1)
            stroke.Thickness = 2
        end
        strokeGradient.Rotation = (now * 12) % 360
    end
    local blend = player:GetAttribute("NightFX") == false and 0 or nightBlend.Value
    if blend < 0.001 then
        for _, ribbon in ribbons do
            ribbon.beam.Enabled = false
        end
        motes.Rate = 0
        return
    end

    for _, ribbon in ribbons do
        local i = ribbon.index
        ribbon.beam.Enabled = true
        ribbon.a.Position = auroraCenter + Vector3.new(-420, 150 + i * 6 + math.sin(now * 0.22 + i) * 12, -200 + i * 24)
        ribbon.b.Position = auroraCenter + Vector3.new(420, 185 + i * 5 + math.cos(now * 0.18 + i) * 14, -150 + i * 24)
        ribbon.beam.CurveSize0 = 110 + math.sin(now * 0.2 + i) * 70
        ribbon.beam.CurveSize1 = -110 + math.cos(now * 0.17 + i) * 70
        local alpha = 1 - blend * (0.1 + 0.07 * math.sin(now * 0.4 + i) ^ 2)
        ribbon.beam.Transparency = NumberSequence.new({
            NumberSequenceKeypoint.new(0, 1),
            NumberSequenceKeypoint.new(0.2, alpha),
            NumberSequenceKeypoint.new(0.7, alpha),
            NumberSequenceKeypoint.new(1, 1),
        })
    end
    local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
    if rootPart then
        motesPart.Position = rootPart.Position + Vector3.new(0, 10, 0)
    end
    motes.Rate = 12 * blend
end)
