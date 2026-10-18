--[[ StarterPlayer.StarterPlayerScripts.PortalClient  (LocalScript)
Draws and animates every Summon Gate (tag "AnimePortal") locally:
  • vortex: stacked glowing layers + counter-rotating energy arcs on both faces of the "Surface" part
  • particles: motes sucked into the vortex, rim sparks, ground mist; a glow pool + lights
  • emerge: surge → the character walks through the surface (each body part fades in exactly as it crosses),
    energy ripple + spark burst at the crossing, rarity-coloured outline that burns off, then a wave.
Needs CharacterAnimator (for the Walk / Wave limbs). Cosmetic only; the server already placed the character.
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local Config = require(ReplicatedStorage:WaitForChild("Portal"):WaitForChild("PortalConfig"))

local localPlayer = Players.LocalPlayer
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local WHITE, INK = Color3.new(1, 1, 1), Config.Palette.Ink
local portals = {} -- [portal Model] = portalState (UI layers, emitters, lights, colour, current emerge)

-- Instance.new + property table + parent in one call.
local function create(class, props, parent)
    local instance = Instance.new(class)
    for key, value in props do
        instance[key] = value
    end
    instance.Parent = parent
    return instance
end
local function seq(points)
    local keypoints = {}
    for _, point in points do
        table.insert(keypoints, NumberSequenceKeypoint.new(point[1], point[2]))
    end
    return NumberSequence.new(keypoints)
end
local function clamp01(x)
    return math.clamp(x, 0, 1)
end
local function smooth(x)
    x = clamp01(x)
    return x * x * (3 - 2 * x)
end
local function reducedMotion()
    return localPlayer:GetAttribute(Config.ReducedMotionAttribute) == true
end
local function roundCorners(frame, radius)
    create("UICorner", { CornerRadius = UDim.new(radius or 0.5, 0) }, frame)
end

local function makeSound(soundName, parent, looped)
    local soundId = Config.Sounds[soundName]
    if not soundId or soundId == "" then
        return nil
    end
    local sound = create("Sound", {
        SoundId = soundId:match("^rbxasset") and soundId or "rbxassetid://" .. soundId:gsub("%D", ""),
        Volume = Config.Volume,
        Looped = looped or false,
        RollOffMaxDistance = 60,
    }, parent)
    local soundGroup = SoundService:FindFirstChild(Config.SoundGroupName)
    if soundGroup and soundGroup:IsA("SoundGroup") then
        sound.SoundGroup = soundGroup
    end
    return sound
end
local function playSound(sound)
    if sound and not localPlayer:GetAttribute(Config.MuteAttribute) then
        sound:Play()
    end
end

-- ── vortex face ───────────────────────────────────────────────────────────────
local function buildFace(portalState, face)
    local vortexGui = create("SurfaceGui", {
        Name = "PortalVortex",
        Face = face,
        SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
        PixelsPerStud = Config.PixelsPerStud,
        LightInfluence = 0,
        Brightness = 2.2,
        ClipsDescendants = true,
        ZOffset = 0,
    }, portalState.surface)
    local root = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.5),
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
    }, vortexGui)
    local scale = create("UIScale", {}, root)
    table.insert(portalState.scales, scale)

    -- depth: 9 nested stadiums, dark rim -> bright heart
    for i = 1, 9 do
        local depth = (i - 1) / 8
        local layerFrame = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5 + 0.02 * depth),
            Size = UDim2.fromScale(1 - depth * 0.8, 1 - depth * 0.78),
            BorderSizePixel = 0,
            BackgroundTransparency = i == 1 and 0.02 or 0.35,
            ZIndex = i,
        }, root)
        roundCorners(layerFrame)
        table.insert(portalState.layers, { f = layerFrame, k = depth })
    end
    -- textured swirl: a CanvasGroup clips rotating images to the stadium (plain frames can't clip rotated children)
    local function toAssetId(id)
        return id ~= "" and (id:match("^rbxasset") and id or "rbxassetid://" .. id:gsub("%D", "")) or nil
    end
    local swirlId, coreId = toAssetId(Config.Textures.Swirl), toAssetId(Config.Textures.Core)
    if swirlId or coreId then
        portalState.textured = true
        local swirlClip = create("CanvasGroup", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5),
            Size = UDim2.fromScale(0.97, 0.97),
            BackgroundTransparency = 1,
            ZIndex = 10,
        }, root)
        roundCorners(swirlClip)
        local specs = swirlId and { { swirlId, 1.6, 1, 0 }, { swirlId, 1.05, 0.55, 0.3 } } or {}
        if coreId then
            table.insert(specs, { coreId, 0.9, 0, 0 })
        end
        for i, spec in specs do
            local imageLabel = create("ImageLabel", {
                Image = spec[1],
                AnchorPoint = Vector2.new(0.5, 0.5),
                Position = UDim2.fromScale(0.5, 0.52),
                Size = UDim2.fromScale(spec[2], spec[2]),
                BackgroundTransparency = 1,
                ImageTransparency = spec[4],
                ZIndex = i,
                Rotation = i * 40,
            }, swirlClip)
            create("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }, imageLabel)
            table.insert(
                portalState.swirls,
                { img = imageLabel, speed = spec[3], core = spec[1] == coreId and spec[3] == 0 }
            )
        end
    end
    -- energy arcs: rings whose stroke gradient leaves 1–2 bright crescents; inner rings spin faster
    local rng = Random.new(portalState.seed)
    for i = 1, 8 do
        local depth = (i - 1) / 7
        local ring = create("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5),
            Position = UDim2.fromScale(0.5, 0.5 + 0.015 * depth),
            Size = UDim2.fromScale(0.94 - depth * 0.72, 0.95 - depth * 0.7),
            BackgroundTransparency = 1,
            ZIndex = 20 + i,
        }, root)
        roundCorners(ring)
        local stroke = create(
            "UIStroke",
            { Thickness = math.floor(14 - depth * 8), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0 },
            ring
        )
        local twoArcs = i % 2 == 0
        local gradient = create("UIGradient", {
            Rotation = rng:NextNumber(0, 360),
            Transparency = twoArcs and seq({ { 0, 0 }, { 0.3, 1 }, { 0.7, 1 }, { 1, 0 } })
                or seq({ { 0, 0 }, { 0.5, 1 }, { 1, 1 } }),
        }, stroke)
        local spinDirection = i % 2 == 0 and -1 or 1
        table.insert(portalState.rings, {
            stroke = stroke,
            grad = gradient,
            k = depth,
            speed = spinDirection * (70 + 260 * depth) * rng:NextNumber(0.85, 1.15),
        })
    end
    -- rim + heart
    local rim = create("UIStroke", { Thickness = 10, Transparency = 0 }, portalState.layers[#portalState.layers - 8].f)
    table.insert(portalState.rims, rim)
    local heart = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0.5, 0.52),
        Size = UDim2.fromScale(0.2, 0.17),
        BorderSizePixel = 0,
        BackgroundColor3 = WHITE,
        ZIndex = 40,
    }, root)
    roundCorners(heart)
    table.insert(portalState.hearts, heart)
    return vortexGui, root
end

local function recolor(portalState, color)
    local dark, light = color:Lerp(INK, 0.72), color:Lerp(WHITE, 0.55)
    for _, layer in portalState.layers do
        layer.f.BackgroundColor3 = layer.k == 0 and dark
            or dark:Lerp(color, layer.k * 0.9):Lerp(light, math.max(0, layer.k - 0.6) * 1.6)
    end
    for _, ring in portalState.rings do
        ring.stroke.Color = color:Lerp(WHITE, 0.25 + 0.55 * ring.k)
    end
    for _, rim in portalState.rims do
        rim.Color = light
    end
    for _, swirl in portalState.swirls do
        swirl.img.ImageColor3 = swirl.core and color:Lerp(WHITE, 0.6) or color:Lerp(WHITE, 0.2)
    end
    local emitterColors = ColorSequence.new(color:Lerp(WHITE, 0.6), color)
    for _, emitter in portalState.emitters do
        emitter.Color = emitterColors
    end
    portalState.mist.Color = ColorSequence.new(color:Lerp(WHITE, 0.4))
    portalState.pool.Color = color
    portalState.point.Color = color
    portalState.slight.Color = color
    if portalState.highlight then
        portalState.highlight.FillColor = light
        portalState.highlight.OutlineColor = color:Lerp(WHITE, 0.3)
    end
end

-- ── build per portal ──────────────────────────────────────────────────────────
local function addPortal(portal)
    if portals[portal] then
        return
    end
    local surface = portal:WaitForChild("Surface", 10)
    if not surface or not portal.Parent then
        return
    end
    local portalState = {
        portal = portal,
        surface = surface,
        layers = {},
        rings = {},
        rims = {},
        hearts = {},
        scales = {},
        emitters = {},
        swirls = {},
        seed = math.random(1, 1e6),
        color = Config.IdleColor,
        target = Config.IdleColor,
        surge = 0,
        kick = 0,
        t = 0,
        visible = true,
        ripples = {},
    }
    portals[portal] = portalState
    portalState.front = buildFace(portalState, Enum.NormalId.Front)
    buildFace(portalState, Enum.NormalId.Back)

    local fx = create("Folder", { Name = "PortalFXLocal" }, portal)
    portalState.fx = fx
    local gatePivot = portal:GetPivot()
    local surfaceCFrame = surface.CFrame
    local function fxPart(name, size, cframe)
        return create("Part", {
            Name = name,
            Size = size,
            CFrame = cframe,
            Anchored = true,
            CanCollide = false,
            CanQuery = false,
            CanTouch = false,
            Transparency = 1,
            CastShadow = false,
        }, fx)
    end
    -- motes pulled into the vortex
    local intake = fxPart("Intake", Vector3.new(Config.Opening.X + 3, Config.Opening.Y + 2, 6), surfaceCFrame)
    portalState.intake = create("ParticleEmitter", {
        Texture = TEX_SPARK,
        Rate = 18,
        Lifetime = NumberRange.new(1.0, 1.4),
        Speed = NumberRange.new(3, 5),
        Shape = Enum.ParticleEmitterShape.Box,
        ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume,
        ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
        Size = seq({ { 0, 0.05 }, { 0.3, 0.35 }, { 1, 0 } }),
        Transparency = seq({ { 0, 1 }, { 0.2, 0 }, { 1, 0.4 } }),
        LightEmission = 1,
        Drag = 0.6,
        Rotation = NumberRange.new(0, 360),
        RotSpeed = NumberRange.new(-180, 180),
    }, intake)
    -- sparks shed from the surface
    portalState.sparks = create("ParticleEmitter", {
        Texture = TEX_SPARK,
        Rate = 10,
        Lifetime = NumberRange.new(0.6, 1.1),
        Speed = NumberRange.new(0.6, 2),
        Shape = Enum.ParticleEmitterShape.Box,
        ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
        SpreadAngle = Vector2.new(30, 30),
        Size = seq({ { 0, 0.25 }, { 1, 0 } }),
        Transparency = seq({ { 0, 0 }, { 1, 1 } }),
        LightEmission = 1,
        Acceleration = Vector3.new(0, 1.5, 0),
    }, surface)
    -- burst used at the crossing (moved to the character's chest)
    local burstAt = create("Attachment", { Name = "BurstAt" }, surface)
    portalState.burstAt = burstAt
    portalState.burst = create("ParticleEmitter", {
        Texture = TEX_SPARK,
        Rate = 0,
        Lifetime = NumberRange.new(0.5, 0.9),
        Speed = NumberRange.new(6, 13),
        SpreadAngle = Vector2.new(75, 75),
        EmissionDirection = Enum.NormalId.Front,
        Drag = 3,
        Size = seq({ { 0, 0.5 }, { 1, 0 } }),
        Transparency = seq({ { 0, 0 }, { 1, 1 } }),
        LightEmission = 1,
        Rotation = NumberRange.new(0, 360),
    }, burstAt)
    portalState.emitters = { portalState.intake, portalState.sparks, portalState.burst }
    -- ground mist spilling out of the gate
    local mistPad = fxPart("Mist", Vector3.new(7.5, 0.2, 3), gatePivot * CFrame.new(0, Config.GroundY + 0.15, -1.6))
    portalState.mist = create("ParticleEmitter", {
        Texture = TEX_SMOKE,
        Rate = 7,
        Lifetime = NumberRange.new(2.5, 4),
        Speed = NumberRange.new(0.3, 0.8),
        EmissionDirection = Enum.NormalId.Top,
        Acceleration = Vector3.new(0, 0.15, 0),
        Size = seq({ { 0, 1.5 }, { 1, 4.5 } }),
        Transparency = seq({ { 0, 1 }, { 0.3, 0.82 }, { 1, 1 } }),
        LightEmission = 0.5,
        Rotation = NumberRange.new(0, 360),
        RotSpeed = NumberRange.new(-20, 20),
    }, mistPad)
    -- glow pool on the slab + lights
    portalState.pool = create("Part", {
        Name = "GlowPool",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.04, 8, 8),
        Material = Enum.Material.Neon,
        CFrame = gatePivot * CFrame.new(0, Config.GroundY + 0.02, -1.4) * CFrame.Angles(0, 0, math.pi / 2),
        Transparency = 0.8,
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
        CastShadow = false,
    }, fx)
    local lightAt = create("Attachment", { Position = Vector3.new(0, 0, -2.5) }, surface)
    portalState.point = create("PointLight", { Range = 20, Brightness = 1.6, Shadows = true }, lightAt)
    portalState.slight =
        create("SurfaceLight", { Face = Enum.NormalId.Front, Range = 16, Angle = 80, Brightness = 1.2 }, surface)
    portalState.hum = makeSound("Hum", surface, true)
    playSound(portalState.hum)
    portalState.sSurge = makeSound("Surge", surface)
    portalState.sWhoosh = makeSound("Whoosh", surface)
    portalState.sArrive = makeSound("Arrive", surface)

    recolor(portalState, portalState.color)
    portal:GetAttributeChangedSignal("EmergeToken"):Connect(function()
        portalState.pending = true
    end)
    if portal:GetAttribute("EmergeToken") then
        portalState.pending = true
    end
    portal.AncestryChanged:Connect(function()
        if not portal:IsDescendantOf(workspace) then
            portals[portal] = nil
        end
    end)
    print(
        "[Portal] vortex drawn on "
            .. portal:GetFullName()
            .. (portalState.textured and " (textured)" or " (no textures set: ring fallback)")
    )
end

-- ── emerge ────────────────────────────────────────────────────────────────────
local function feetOrigin(model)
    local boxCFrame, size = model:GetBoundingBox()
    return CFrame.new(boxCFrame.Position - Vector3.new(0, size.Y / 2, 0)) * boxCFrame.Rotation
end

local function endEmerge(portalState)
    local emerge = portalState.emerge
    if not emerge then
        return
    end
    portalState.emerge = nil
    if emerge.model.Parent then
        for _, part in emerge.parts do
            part.LocalTransparencyModifier = 0
        end
        emerge.model:PivotTo(emerge.final)
        emerge.model:SetAttribute("Animation", emerge.prevAnim)
    end
    if portalState.highlight then
        portalState.highlight:Destroy()
        portalState.highlight = nil
    end
    portalState.target = Config.IdleColor
end

-- Triggered by EmergeToken changes. Waits (max 3 s) for the server's EmergeTarget character, hides it and
-- starts the local walk-out; ignored if the emerge is already over or a newer token arrived meanwhile.
local function startEmerge(portalState)
    portalState.pending = false
    endEmerge(portalState)
    local portal = portalState.portal
    local startTime, token = portal:GetAttribute("EmergeStart"), portal:GetAttribute("EmergeToken")
    if not (startTime and token) then
        return
    end
    if workspace:GetServerTimeNow() - startTime > Config.Total() then
        return
    end
    local targetValue = portal:WaitForChild("EmergeTarget", 3)
    local waitStart = os.clock()
    while targetValue and not targetValue.Value and os.clock() - waitStart < 3 do
        task.wait()
    end
    local model = targetValue and targetValue.Value
    if not model or portal:GetAttribute("EmergeToken") ~= token then
        return
    end
    while model.Parent and not model:FindFirstChild("Torso", true) and os.clock() - waitStart < 3 do
        task.wait()
    end

    local parts = {}
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") then
            table.insert(parts, descendant)
            descendant.LocalTransparencyModifier = 1
        end
    end
    local final = model:GetPivot()
    local feet = feetOrigin(model)
    portalState.emerge = {
        model = model,
        parts = parts,
        start = startTime,
        final = final,
        feet = feet,
        offset = feet:ToObjectSpace(final),
        prevAnim = model:GetAttribute("Animation") or Config.EndAnimation,
        chest = model:FindFirstChild("Torso", true),
        phase = 0,
    }
    portalState.target = Config.Color(portal:GetAttribute("EmergeRarity"))
    portalState.highlight = create("Highlight", {
        Adornee = model,
        DepthMode = Enum.HighlightDepthMode.Occluded,
        FillTransparency = 1,
        OutlineTransparency = 1,
        Enabled = false,
    }, portalState.fx)
    playSound(portalState.sSurge)
end

local function ripple(portalState, worldPos)
    if not portalState.front then
        return
    end
    local localPos = portalState.surface.CFrame:PointToObjectSpace(worldPos)
    local u, v = 0.5 - localPos.X / Config.Opening.X, 0.5 - localPos.Y / Config.Opening.Y
    local root = portalState.front:FindFirstChildOfClass("Frame")
    local rippleFrame = create("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(u, v),
        Size = UDim2.fromScale(0.1, 0.085),
        BackgroundTransparency = 1,
        ZIndex = 50,
    }, root)
    roundCorners(rippleFrame)
    local rippleStroke = create(
        "UIStroke",
        { Thickness = 18, Color = portalState.color:Lerp(WHITE, 0.7), Transparency = 0 },
        rippleFrame
    )
    local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    TweenService:Create(rippleFrame, info, { Size = UDim2.fromScale(1.2, 1.0) }):Play()
    TweenService:Create(rippleStroke, info, { Transparency = 1, Thickness = 2 }):Play()
    task.delay(0.75, function()
        rippleFrame:Destroy()
    end)
end

-- Per-frame emerge driven by server time since EmergeStart. emerge.phase: 0 = surge (character hidden behind
-- the surface), 1 = walking out, 2 = chest crossed the surface (burst, ripple, outline), 3 = arrived (wave).
local function stepEmerge(portalState)
    local emerge = portalState.emerge
    if not emerge.model.Parent then
        endEmerge(portalState)
        return
    end
    local elapsed = workspace:GetServerTimeNow() - emerge.start
    local walkT = Config.WalkTime()
    local walkDistance = Config.StartBehind + Config.WalkOut
    if elapsed >= Config.Total() then
        endEmerge(portalState)
        return
    end

    if elapsed < Config.Surge then
        portalState.surge = smooth(elapsed / Config.Surge)
        for _, part in emerge.parts do
            part.LocalTransparencyModifier = 1
        end
        emerge.model:PivotTo(emerge.feet * CFrame.new(0, 0, walkDistance) * emerge.offset)
        return
    end
    if emerge.phase == 0 then
        emerge.phase = 1
        emerge.model:SetAttribute("Animation", "Walk")
    end

    local walkProgress = clamp01((elapsed - Config.Surge) / walkT)
    local along = walkProgress < 0.85 and walkProgress or 0.85 + (1 - (1 - (walkProgress - 0.85) / 0.15) ^ 2) * 0.15 -- ease out the last steps
    emerge.model:PivotTo(emerge.feet * CFrame.new(0, 0, (1 - along) * walkDistance) * emerge.offset)

    local surfaceNormal, surfaceOrigin = portalState.surface.CFrame.LookVector, portalState.surface.Position
    local minVisible = 1
    for _, part in emerge.parts do
        local depth = (part.Position - surfaceOrigin):Dot(surfaceNormal)
        local hidden = clamp01(0.5 - depth / Config.FadeBand)
        part.LocalTransparencyModifier = hidden
        minVisible = math.min(minVisible, 1 - hidden)
    end
    local chestDepth = emerge.chest and (emerge.chest.Position - surfaceOrigin):Dot(surfaceNormal) or -1
    if emerge.phase == 1 and chestDepth > 0 then
        emerge.phase = 2
        portalState.kick = 1
        portalState.highlight.Enabled = true
        portalState.burstAt.WorldPosition = emerge.chest.Position
        portalState.burst:Emit(reducedMotion() and 14 or 30)
        ripple(portalState, emerge.chest.Position)
        playSound(portalState.sWhoosh)
    end
    if emerge.phase >= 2 then
        if minVisible >= 1 and not emerge.outAt then
            emerge.outAt = elapsed
        end
        local glowFade = emerge.outAt and clamp01((elapsed - emerge.outAt) / Config.GlowFade) or 0
        portalState.highlight.FillTransparency = 0.35 + 0.65 * glowFade
        portalState.highlight.OutlineTransparency = glowFade
    end
    if walkProgress >= 1 and emerge.phase < 3 then
        emerge.phase = 3
        emerge.model:SetAttribute("Animation", "Wave")
        portalState.target = Config.IdleColor:Lerp(portalState.target, 0.5)
        playSound(portalState.sArrive)
    end
    portalState.surge = emerge.phase == 3 and math.max(0, 1 - (elapsed - Config.Surge - walkT) / 1.2) or 1
end

-- ── per frame ─────────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function(dt)
    local camera = workspace.CurrentCamera
    local camPos = camera and camera.CFrame.Position or Vector3.zero
    local isReducedMotion = reducedMotion()
    for portal, portalState in portals do
        if not portal.Parent then
            portals[portal] = nil
            continue
        end
        if portalState.pending then
            task.spawn(startEmerge, portalState)
            portalState.pending = false
        end
        if portalState.emerge then
            stepEmerge(portalState)
        elseif portalState.surge > 0 then
            portalState.surge = math.max(0, portalState.surge - dt)
        end

        local near = (portalState.surface.Position - camPos).Magnitude < Config.EffectsDistance
        if near ~= portalState.visible then
            portalState.visible = near
            for _, emitter in portalState.emitters do
                emitter.Enabled = near and emitter ~= portalState.burst
            end
            portalState.mist.Enabled = near
        end
        if not near and not portalState.emerge then
            continue
        end

        portalState.t += dt
        local surge, elapsed = portalState.surge, portalState.t
        portalState.kick = math.max(0, portalState.kick - dt * 3)
        -- colour
        if
            (portalState.color.R - portalState.target.R) ^ 2 + (portalState.color.G - portalState.target.G) ^ 2 + (portalState.color.B - portalState.target.B) ^ 2
            > 1e-5
        then
            portalState.color = portalState.color:Lerp(portalState.target, 1 - math.exp(-dt * 3.5))
            recolor(portalState, portalState.color)
        end
        -- spin + breathe
        local spin = dt * (1 + 2.2 * surge) * (isReducedMotion and 0.5 or 1)
        for _, ring in portalState.rings do
            ring.grad.Rotation = (ring.grad.Rotation + ring.speed * spin) % 360
            ring.stroke.Transparency = math.min(
                1,
                0.15
                    + 0.25 * (0.5 + 0.5 * math.sin(elapsed * 2 + ring.k * 6))
                    - 0.15 * surge
                    + (portalState.textured and 0.45 or 0)
            )
        end
        local swirlDegrees = Config.SwirlSpeed * dt * (1 + 2.4 * surge) * (isReducedMotion and 0.5 or 1)
        for _, swirl in portalState.swirls do
            if swirl.core then
                swirl.img.ImageTransparency = clamp01(0.25 - 0.25 * surge - 0.1 * math.sin(elapsed * 3.1))
            else
                swirl.img.Rotation = (swirl.img.Rotation - swirlDegrees * swirl.speed) % 360
            end
        end
        local breathe = 1
            + 0.012 * math.sin(elapsed * 1.7)
            + 0.04 * surge
            + 0.06 * portalState.kick * (isReducedMotion and 0.5 or 1)
        for _, uiScale in portalState.scales do
            uiScale.Scale = breathe
        end
        for _, heart in portalState.hearts do
            heart.BackgroundTransparency = clamp01(0.25 + 0.12 * math.sin(elapsed * 3.1) - 0.25 * surge)
            heart.Size = UDim2.fromScale(
                0.2 + 0.08 * surge + 0.02 * math.sin(elapsed * 2.3),
                0.17 + 0.07 * surge + 0.02 * math.sin(elapsed * 2.3)
            )
        end
        for _, rim in portalState.rims do
            rim.Thickness = 9 + 3 * math.sin(elapsed * 2.6) + 8 * surge
        end
        portalState.point.Brightness = 1.5 + 0.3 * math.sin(elapsed * 2.3) + 2.8 * surge + 2 * portalState.kick
        portalState.slight.Brightness = 1.1 + 1.8 * surge
        portalState.pool.Transparency = 0.82 - 0.25 * surge - 0.04 * math.sin(elapsed * 2.3)
        portalState.intake.Rate = (isReducedMotion and 0.5 or 1) * (16 + 50 * surge)
        portalState.sparks.Rate = (isReducedMotion and 0.5 or 1) * (8 + 24 * surge)
        if portalState.hum then
            portalState.hum.PlaybackSpeed = 1 + 0.25 * surge
        end
    end
end)

print("[Portal] client running, " .. #CollectionService:GetTagged(Config.Tag) .. " portal(s) found so far")
for _, portal in CollectionService:GetTagged(Config.Tag) do
    task.spawn(addPortal, portal)
end
CollectionService:GetInstanceAddedSignal(Config.Tag):Connect(function(portal)
    task.spawn(addPortal, portal)
end)
