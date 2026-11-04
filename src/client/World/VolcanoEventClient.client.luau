--!nonstrict
--[[ StarterPlayerScripts.VolcanoEventClient (client only): everything the player sees of the Volcano Eruption event.
The server only publishes workspace attribute VolcanoStart (server time); this script derives the phase and every effect from
that clock (ReplicatedStorage.VolcanoEvent.VolcanoConfig), so all players see the same eruption at the same moment.

  lighting    the whole map goes volcano: orange tint, bloom, red-orange atmosphere haze, warm sun and ambient, ash and
              embers drifting past the camera, a light camera rumble while it erupts (this player only, restored afterwards)
  volcano     the imported far voxel volcano (Model "FarVolcano"): a glowing lake in the caldera, a fire fountain, smoke and
              spark plumes, lava bombs thrown up and falling down the cone, and glowing lava flows running down its sides
  river       the river turns to lava from the waterfall downstream, one chunk at a time (the front sweeps along), then back
              to water, upstream first. Each river chunk's pieces are swapped for the studded lava textures; the waterfall
              tints red. Works on the river meshes made by RiverWater / WaterfallCurtain (folders RiverWaterLocal and
              WaterfallCurtainLocal).
If the volcano model is not in the place yet, lighting and the river still run; only the volcano effects are skipped.
Lava textures: ReplicatedStorage.VolcanoEvent.LavaTemplates.RiverLavaAppearance (place-owned: scripts cannot set maps). ]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local assets = ReplicatedStorage:WaitForChild("VolcanoEvent")
local Config = require(assets:WaitForChild("VolcanoConfig"))
local templates = assets:WaitForChild("LavaTemplates")
local Cinematic = require(script.Parent:WaitForChild("VolcanoCinematic"))
local player = Players.LocalPlayer
local TAU = math.pi * 2

local function eventTime()
    local started = workspace:GetAttribute("VolcanoStart")
    if type(started) ~= "number" then
        return nil
    end
    return workspace:GetServerTimeNow() - started
end

local function smooth(a, b, x)
    local q = math.clamp((x - a) / (b - a), 0, 1)
    return q * q * (3 - 2 * q)
end

-- ===== 1. Where the volcano is =====
local volcano = nil -- { model, centre, top, base, lakeY, crater, opening }
local cinematic = nil -- the running cutscene (VolcanoCinematic)
local cinematicFor = nil -- the VolcanoStart value the cutscene has already been started for
-- The opening cut through the caldera's rim: the lowest point on a ring just inside the rim, found by raycasting down onto the model.
-- Returns a flat unit vector from the crater toward it, or nil for a model without one.
local function findOpening(model, centre, top)
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { model }
    local lowest, highest, lowestAngle = math.huge, -math.huge, nil
    for step = 0, 71 do
        local angle = step / 72 * TAU
        local x, z = centre.X + math.cos(angle) * 98, centre.Z + math.sin(angle) * 98
        local hit = workspace:Raycast(Vector3.new(x, top + 100, z), Vector3.new(0, -(top + 2000), 0), params)
        if hit then
            if hit.Position.Y < lowest then
                lowest, lowestAngle = hit.Position.Y, angle
            end
            highest = math.max(highest, hit.Position.Y)
        end
    end
    if lowestAngle and highest - lowest > 25 then
        return Vector3.new(math.cos(lowestAngle), 0, math.sin(lowestAngle))
    end
    return nil
end

-- The opening in the crater's rim is only for the cutscene camera. The rest of the time a rock-coloured plug of studded blocks fills it, so
-- from the map the volcano is a plain cone (the lip of the opening is baked dark red-brown and would show). The plug is local, and is taken
-- out while the cutscene runs.
local plug = nil -- { folder, model }
local function destroyPlug()
    if plug then
        plug.folder:Destroy()
        plug = nil
    end
end
local function ensurePlug()
    if plug and plug.model == (volcano and volcano.model) and plug.folder.Parent then
        return
    end
    destroyPlug()
    if not volcano or not volcano.opening then
        return
    end
    local folder = Instance.new("Folder")
    folder.Name = "VolcanoOpeningPlug"
    local n = volcano.opening
    local up = Vector3.yAxis
    local right = n:Cross(up)
    local centre = Vector3.new(volcano.centre.X, 0, volcano.centre.Z) + n * 108
    local baseY = volcano.base
    local function block(width, height, length, bottom, color)
        local part = Instance.new("Part")
        part.Name = "PlugBlock"
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.Size = Vector3.new(width, height, length)
        part.CFrame = CFrame.fromMatrix(Vector3.new(centre.X, baseY + bottom + height / 2, centre.Z), right, up, -n)
        part.Material = Enum.Material.Plastic
        part.MaterialVariant = "Incubator One Stud Cavity"
        part.Color = color
        part.Parent = folder
    end
    block(64, 40, 56, Config.LipHeight - 22, Color3.fromRGB(122, 100, 90))
    block(54, 20, 40, Config.LipHeight + 18, Color3.fromRGB(150, 135, 126))
    folder.Parent = workspace
    plug = { folder = folder, model = volcano.model }
end
local function updatePlug()
    if not plug then
        return
    end
    local hide = cinematic ~= nil and cinematic.active
    local target = (not hide) and workspace or nil
    if plug.folder.Parent ~= target then
        plug.folder.Parent = target
    end
end

local lastLocate = -1e9
local function locate()
    if os.clock() - lastLocate < 4 then
        return
    end
    lastLocate = os.clock()
    local found = workspace:FindFirstChild(Config.ModelName, true)
    if not found then
        volcano = nil
        return
    end
    if volcano and volcano.model == found and found.Parent then
        return
    end
    local minV, maxV = Vector3.one * math.huge, Vector3.one * -math.huge
    local any = false
    for _, d in found:GetDescendants() do
        if d:IsA("BasePart") then
            any = true
            local h = d.Size / 2
            for sx = -1, 1, 2 do
                for sy = -1, 1, 2 do
                    for sz = -1, 1, 2 do
                        local p = d.CFrame:PointToWorldSpace(Vector3.new(h.X * sx, h.Y * sy, h.Z * sz))
                        minV = Vector3.new(math.min(minV.X, p.X), math.min(minV.Y, p.Y), math.min(minV.Z, p.Z))
                        maxV = Vector3.new(math.max(maxV.X, p.X), math.max(maxV.Y, p.Y), math.max(maxV.Z, p.Z))
                    end
                end
            end
        end
    end
    if found:IsA("BasePart") then
        any = true
        minV, maxV = found.Position - found.Size / 2, found.Position + found.Size / 2
    end
    if not any then
        volcano = nil
        return
    end
    local centre = Vector3.new((minV.X + maxV.X) / 2, 0, (minV.Z + maxV.Z) / 2)
    if found:IsA("Model") then
        -- the imported model's pivot sits on the volcano's own axis (the importer's "set pivot to scene origin"), which is the exact
        -- centre of the crater; the bounding box centre is off by a few studs because the footprint is not symmetrical
        local pivot = found:GetPivot().Position
        centre = Vector3.new(pivot.X, 0, pivot.Z)
    end
    local lakeY = minV.Y + Config.LipHeight - 2 -- the lava lake, filled to the lip of the opening
    local appearances = {}
    for _, d in found:GetDescendants() do
        if d:IsA("SurfaceAppearance") then
            table.insert(appearances, d)
        end
    end
    volcano = {
        appearances = appearances,
        model = found,
        centre = centre,
        top = maxV.Y,
        base = minV.Y,
        lakeY = lakeY,
        crater = Vector3.new(centre.X, lakeY + 3, centre.Z),
    }
    volcano.opening = findOpening(found, centre, maxV.Y)
    if not volcano.opening then
        local toMap = Vector3.new(-centre.X, 0, -centre.Z)
        volcano.opening = toMap.Magnitude > 1 and toMap.Unit or Vector3.xAxis
    end
end

-- ===== 2. World lighting =====
local tint = Instance.new("ColorCorrectionEffect")
tint.Name = "VolcanoTint"
tint.Enabled = false
tint.Parent = Lighting
local bloom = Instance.new("BloomEffect")
bloom.Name = "VolcanoBloom"
bloom.Size = 24
bloom.Threshold = 0.9
bloom.Intensity = 0
bloom.Enabled = false
bloom.Parent = Lighting

local before = nil -- Lighting values saved while the volcano look is on
local function saveLighting()
    local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
    before = {
        atmosphere = atmosphere,
        density = atmosphere and atmosphere.Density,
        color = atmosphere and atmosphere.Color,
        decay = atmosphere and atmosphere.Decay,
        haze = atmosphere and atmosphere.Haze,
        glare = atmosphere and atmosphere.Glare,
        shiftTop = Lighting.ColorShift_Top,
        shiftBottom = Lighting.ColorShift_Bottom,
        ambient = Lighting.Ambient,
        outdoor = Lighting.OutdoorAmbient,
    }
end
local function restoreLighting()
    if not before then
        return
    end
    local a = before.atmosphere
    if a and a.Parent then
        a.Density, a.Color, a.Decay, a.Haze, a.Glare = before.density, before.color, before.decay, before.haze, before.glare
    end
    Lighting.ColorShift_Top, Lighting.ColorShift_Bottom = before.shiftTop, before.shiftBottom
    Lighting.Ambient, Lighting.OutdoorAmbient = before.ambient, before.outdoor
    before = nil
end

local HOT = Color3.fromRGB(255, 120, 60)
local function applyLighting(k)
    if k <= 0.001 then
        tint.Enabled = false
        bloom.Enabled = false
        restoreLighting()
        return
    end
    if not before then
        saveLighting()
    end
    tint.Enabled = true
    tint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 185, 150), k)
    tint.Brightness = -0.06 * k
    tint.Contrast = 0.14 * k
    tint.Saturation = 0.12 * k
    bloom.Enabled = true
    bloom.Intensity = 0.55 * k
    local a = before.atmosphere
    if a and a.Parent then
        a.Density = before.density + (0.13 - before.density) * k * 0.7
        a.Color = before.color:Lerp(HOT, k)
        a.Decay = before.decay:Lerp(Color3.fromRGB(150, 45, 20), k)
        a.Haze = before.haze + 0.6 * k
        a.Glare = before.glare * (1 - k)
    end
    Lighting.ColorShift_Top = before.shiftTop:Lerp(Color3.fromRGB(255, 120, 60), k * 0.7)
    Lighting.ColorShift_Bottom = before.shiftBottom:Lerp(Color3.fromRGB(255, 70, 30), k * 0.5)
    Lighting.Ambient = before.ambient:Lerp(Color3.fromRGB(120, 60, 40), k * 0.6)
    Lighting.OutdoorAmbient = before.outdoor:Lerp(Color3.fromRGB(150, 85, 60), k * 0.6)
end

-- ash and embers drifting past the camera
local ashPart = Instance.new("Part")
ashPart.Name = "VolcanoAsh"
ashPart.Anchored = true
ashPart.CanCollide = false
ashPart.CanTouch = false
ashPart.CanQuery = false
ashPart.CastShadow = false
ashPart.Transparency = 1
ashPart.Size = Vector3.new(160, 1, 160)
local ash = Instance.new("ParticleEmitter")
ash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
ash.Lifetime = NumberRange.new(5, 8)
ash.Speed = NumberRange.new(3, 8)
ash.EmissionDirection = Enum.NormalId.Bottom
ash.SpreadAngle = Vector2.new(35, 35)
ash.Acceleration = Vector3.new(4, -1.5, 2)
ash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.1) })
ash.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.15, 0.2),
    NumberSequenceKeypoint.new(1, 1),
})
ash.Color = ColorSequence.new(Color3.fromRGB(255, 190, 110), Color3.fromRGB(120, 105, 100))
ash.LightEmission = 0.6
ash.Rate = 0
ash.Parent = ashPart

-- ===== 3. The volcano effects =====
local fx = nil -- { folder, glow, fountain, fountainChunks, light, emitters, plume, calderaSound }
local bombs = {}
local smokeCubes = {}
local flows = nil -- { segments = { {part, revealAt} }, built = false }
local lastBomb = 0
local lastBombSfx = 0
local lastSmokeCube = 0
local eruptionRumble = nil -- ambient map-wide eruption rumble Sound
local blastFiredFor = nil -- VolcanoStart value for which the main eruption blast sound has played
local startFiredFor = nil -- ... and the low boom that opens the event

-- Load the sounds now so the rumble is audible the instant the event starts.
task.spawn(function()
    local ContentProvider = game:GetService("ContentProvider")
    local holder = {}
    for _, id in { "9112823563", "9113220677", "9114463219", "9112822944", "9112823197" } do
        local sound = Instance.new("Sound")
        sound.SoundId = "rbxassetid://" .. id
        table.insert(holder, sound)
    end
    pcall(function()
        ContentProvider:PreloadAsync(holder)
    end)
    for _, sound in holder do
        sound:Destroy()
    end
end)

local function ensureEruptionRumble()
    if eruptionRumble and eruptionRumble.Parent then
        return eruptionRumble
    end
    local sound = Instance.new("Sound")
    sound.Name = "VolcanoEruptionRumble"
    sound.SoundId = "rbxassetid://9112823563"
    sound.Looped = true
    sound.Volume = 0
    sound.PlaybackSpeed = 0.9
    sound.Parent = workspace
    sound:Play()
    eruptionRumble = sound
    return sound
end

local function stopEruptionRumble()
    if eruptionRumble then
        eruptionRumble:Destroy()
        eruptionRumble = nil
    end
    blastFiredFor = nil
    startFiredFor = nil
end

local function playOneShot2D(name, soundId, volume, speed)
    local sound = Instance.new("Sound")
    sound.Name = name
    sound.SoundId = soundId
    sound.Volume = volume
    sound.PlaybackSpeed = speed or 1
    sound.Parent = workspace
    sound:Play()
    Debris:AddItem(sound, 5)
end

local function neon(size, color, parent, shape)
    local p = Instance.new("Part")
    p.Anchored = true
    p.CanCollide = false
    p.CanTouch = false
    p.CanQuery = false
    p.CastShadow = false
    p.Material = Enum.Material.Neon
    p.Color = color
    p.Size = size
    if shape then
        p.Shape = shape
    end
    p.TopSurface = Enum.SurfaceType.Smooth
    p.BottomSurface = Enum.SurfaceType.Smooth
    p.Parent = parent
    return p
end

local function emitter(parent, props)
    local e = Instance.new("ParticleEmitter")
    for k, v in props do
        e[k] = v
    end
    e.Rate = 0
    e.Parent = parent
    return e
end

local function buildFx()
    local folder = Instance.new("Folder")
    folder.Name = "VolcanoFXLocal"
    folder.Parent = workspace
    local c = volcano.crater
    local R = Config.CraterRadius
    -- the glowing lake in the caldera
    local lakeDiameter = Config.LipRadius * 2
    local glow = neon(Vector3.new(4, lakeDiameter, lakeDiameter), Color3.fromRGB(255, 100, 30), folder, Enum.PartType.Cylinder)
    glow.CFrame = CFrame.new(c.X, volcano.lakeY, c.Z) * CFrame.Angles(0, 0, math.pi / 2)
    glow.Transparency = 1
    -- the fire fountain: a cluster of rising, pulsing neon voxel blocks & columns (instead of a single flat cylinder)
    local fountainChunks = {}
    local fRng = Random.new(404)
    for i = 1, 16 do
        local isCore = i <= 5
        local w = isCore and fRng:NextInteger(36, 58) or fRng:NextInteger(22, 40)
        local d = isCore and fRng:NextInteger(36, 58) or fRng:NextInteger(22, 40)
        local h = isCore and fRng:NextInteger(100, 175) or fRng:NextInteger(40, 90)
        local part = neon(Vector3.new(w, h, d), Color3.fromRGB(255, 140, 40), folder)
        part.Transparency = 1
        local angle = (i - 1) / 16 * TAU + fRng:NextNumber(-0.2, 0.2)
        local dist = isCore and fRng:NextNumber(0, 22) or fRng:NextNumber(20, 62)
        table.insert(fountainChunks, {
            part = part,
            baseSize = Vector3.new(w, h, d),
            offsetX = math.cos(angle) * dist,
            offsetZ = math.sin(angle) * dist,
            speed = fRng:NextNumber(1.3, 2.3),
            phase = (i - 1) / 16 + fRng:NextNumber(0, 0.15),
            spin = CFrame.Angles(
                fRng:NextNumber(-0.22, 0.22),
                fRng:NextNumber(0, TAU),
                fRng:NextNumber(-0.22, 0.22)
            ),
            isCore = isCore,
        })
    end
    -- an invisible emitter base in the caldera
    local plume = Instance.new("Part")
    plume.Anchored = true
    plume.CanCollide = false
    plume.CanTouch = false
    plume.CanQuery = false
    plume.Transparency = 1
    plume.Size = Vector3.new(R, 2, R)
    plume.CFrame = CFrame.new(c)
    plume.Parent = folder
    local light = Instance.new("PointLight")
    light.Color = Color3.fromRGB(255, 120, 50)
    light.Range = 60
    light.Brightness = 0
    light.Parent = plume
    local emitters = {
        smoke = emitter(plume, {
            Texture = "rbxasset://textures/particles/smoke_main.dds",
            Lifetime = NumberRange.new(16, 22),
            Speed = NumberRange.new(70, 110),
            SpreadAngle = Vector2.new(16, 16),
            EmissionDirection = Enum.NormalId.Top,
            Rotation = NumberRange.new(0, 360),
            RotSpeed = NumberRange.new(-12, 12),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 60), NumberSequenceKeypoint.new(1, 200) }),
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.1),
                NumberSequenceKeypoint.new(0.7, 0.4),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Color = ColorSequence.new(Color3.fromRGB(34, 30, 32), Color3.fromRGB(96, 82, 80)),
            Acceleration = Vector3.new(14, 6, 6),
        }),
        fire = emitter(plume, {
            Texture = "rbxasset://textures/particles/fire_main.dds",
            Lifetime = NumberRange.new(2.5, 4),
            Speed = NumberRange.new(170, 250),
            SpreadAngle = Vector2.new(12, 12),
            EmissionDirection = Enum.NormalId.Top,
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 80), NumberSequenceKeypoint.new(1, 20) }),
            Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) }),
            Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(255, 60, 20)),
            LightEmission = 1,
        }),
        sparks = emitter(plume, {
            Texture = "rbxasset://textures/particles/sparkles_main.dds",
            Lifetime = NumberRange.new(5, 7),
            Speed = NumberRange.new(220, 380),
            SpreadAngle = Vector2.new(30, 30),
            EmissionDirection = Enum.NormalId.Top,
            Acceleration = Vector3.new(0, -110, 0),
            Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 12), NumberSequenceKeypoint.new(1, 0) }),
            Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 80, 20)),
            LightEmission = 1,
        }),
    }
    local calderaSound = Instance.new("Sound")
    calderaSound.Name = "CalderaLavaSound"
    calderaSound.SoundId = "rbxassetid://9112822944"
    calderaSound.Looped = true
    calderaSound.Volume = 0
    calderaSound.PlaybackSpeed = 0.85
    calderaSound.RollOffMode = Enum.RollOffMode.InverseTapered
    calderaSound.RollOffMinDistance = 120
    calderaSound.RollOffMaxDistance = 1800
    calderaSound.Parent = plume
    calderaSound:Play()
    fx = {
        folder = folder,
        glow = glow,
        fountainChunks = fountainChunks,
        plume = plume,
        light = light,
        emitters = emitters,
        calderaSound = calderaSound,
        volcano = volcano,
    }
end

local function destroyFx()
    if fx then
        fx.folder:Destroy()
        fx = nil
    end
    for _, bomb in bombs do
        bomb.part:Destroy()
    end
    table.clear(bombs)
    for _, sc in smokeCubes do
        sc.part:Destroy()
    end
    table.clear(smokeCubes)
    flows = nil
    lastBomb = 0
    lastSmokeCube = 0
end

-- lava running down the cone: segments found by marching out from the rim and raycasting down onto the model
local function buildFlows()
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Include
    params.FilterDescendantsInstances = { volcano.model }
    local out = { segments = {}, built = true }
    local rng = Random.new(77)
    local count = 7
    for i = 1, count do
        local baseAngle = (i - 1) / count * TAU + rng:NextNumber(-0.25, 0.25)
        local phase = rng:NextNumber(0, TAU)
        local radius = Config.CraterRadius * 0.8 -- starts inside the rim, so the lava is seen spilling over it
        local reveal = rng:NextNumber(0.3, 2)
        -- the first flow is the main one: it pours out through the opening in the rim, right as the volcano blows
        local main = i == 1 and volcano.opening ~= nil
        if main then
            baseAngle = math.atan2(volcano.opening.Z, volcano.opening.X)
            reveal = 0
        end
        -- march down the cone: one surface point per step
        local points = {}
        for step = 1, 60 do
            -- each flow wanders a little to either side as it runs down
            local angle = baseAngle + 0.05 * math.sin(step * 0.45 + phase) + 0.025 * math.sin(step * 1.1 + phase * 2)
            local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
            local x, z = volcano.centre.X + dir.X * radius, volcano.centre.Z + dir.Z * radius
            local hit = workspace:Raycast(Vector3.new(x, volcano.top + 200, z), Vector3.new(0, -(volcano.top - volcano.base + 400), 0), params)
            if not hit or hit.Position.Y < volcano.base + 25 then
                break
            end
            table.insert(points, { position = hit.Position + hit.Normal * 2.5, normal = hit.Normal })
            radius += 20
        end
        -- a piece between each pair of neighbouring points, so the flow reads as one unbroken stream
        for step = 1, #points - 1 do
            local a, b = points[step], points[step + 1]
            local length = (b.position - a.position).Magnitude + 3
            -- thick enough to read from a thousand studs away, widening as the lava spreads out downhill
            local width = math.min(60, 24 + step * 0.9) * (0.85 + 0.3 * math.sin(step * 0.8 + phase)) * (main and 1.6 or 1)
            local part = neon(Vector3.new(width, 5, length), Color3.fromRGB(255, 120, 30), fx.folder)
            part.CFrame = CFrame.lookAt((a.position + b.position) / 2, b.position, a.normal)
            part.Transparency = 1
            table.insert(out.segments, { part = part, revealAt = reveal })
            reveal += 0.3 -- the head of the flow runs down the cone at about 70 studs a second
        end
    end
    return out
end

local function spawnBomb(now)
    if #bombs > 75 or not fx then
        return
    end
    local rng = Random.new(math.floor(now * 1000))
    local side = ({ 14, 20, 26, 36 })[rng:NextInteger(1, 4)]
    local heat = rng:NextNumber()
    local part = neon(Vector3.new(side, side, side), Color3.fromRGB(255, 70 + heat * 150, 10 + heat * 60), fx.folder)
    local angle = rng:NextNumber() * TAU
    local flat = rng:NextNumber(50, 240)
    local origin = volcano.crater + Vector3.new(rng:NextNumber(-45, 45), 14, rng:NextNumber(-45, 45))
    if now - lastBombSfx >= 1.2 and fx.plume and fx.plume.Parent then
        lastBombSfx = now
        local launch = Instance.new("Sound")
        launch.Name = "VolcanoBombSfx"
        launch.SoundId = "rbxassetid://9114463219"
        launch.Volume = 0.25
        launch.PlaybackSpeed = 0.6 + rng:NextNumber() * 0.25
        launch.RollOffMode = Enum.RollOffMode.InverseTapered
        launch.RollOffMinDistance = 80
        launch.RollOffMaxDistance = 900
        launch.Parent = fx.plume
        launch:Play()
        Debris:AddItem(launch, 2.5)
    end
    table.insert(bombs, {
        part = part,
        origin = origin,
        velocity = Vector3.new(math.cos(angle) * flat, rng:NextNumber(280, 460), math.sin(angle) * flat),
        born = os.clock(),
        spin = CFrame.Angles(rng:NextNumber() * TAU, rng:NextNumber() * TAU, 0),
    })
end

local BOMB_GRAVITY = 150
local function stepBombs()
    local now = os.clock()
    for i = #bombs, 1, -1 do
        local bomb = bombs[i]
        local age = now - bomb.born
        local p = bomb.origin + bomb.velocity * age + Vector3.new(0, -0.5 * BOMB_GRAVITY * age * age, 0)
        if age > 12 or p.Y < volcano.base + 20 or not bomb.part.Parent then
            bomb.part:Destroy()
            table.remove(bombs, i)
        else
            bomb.part.CFrame = CFrame.new(p) * bomb.spin * CFrame.Angles(age * 2, age * 1.3, 0)
        end
    end
end

-- Real 3D studded voxel smoke cubes rising into the sky (3D BaseParts render at any distance, unlike 2D ParticleEmitters)
local SMOKE_COLORS = {
    Color3.fromRGB(70, 56, 58),
    Color3.fromRGB(92, 74, 72),
    Color3.fromRGB(115, 92, 88),
    Color3.fromRGB(142, 110, 98),
    Color3.fromRGB(168, 118, 92), -- warm ash-lit smoke so stud texture reads in the sky
}
local function spawnSmokeCube(now, blast, isWarning)
    if #smokeCubes > 110 or not fx then
        return
    end
    local rng = Random.new(math.floor(now * 1000) + #smokeCubes * 37)
    local baseSide = isWarning and ({ 32, 44, 56, 70 })[rng:NextInteger(1, 4)]
        or ({ 48, 68, 90, 116, 144 })[rng:NextInteger(1, 5)]
    local endScale = rng:NextNumber(2.0, 2.8)
    local part = Instance.new("Part")
    part.Name = "VolcanoSmokeCube"
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Material = Enum.Material.Plastic
    part.MaterialVariant = "Incubator One Stud Cavity"
    part.Color = SMOKE_COLORS[rng:NextInteger(1, #SMOKE_COLORS)]
    part.Size = Vector3.new(baseSide, baseSide, baseSide)
    part.Transparency = 0.85
    part.TopSurface = Enum.SurfaceType.Smooth
    part.BottomSurface = Enum.SurfaceType.Smooth
    part.Parent = fx.folder
    local angle = rng:NextNumber() * TAU
    local radius = rng:NextNumber(24, 90)
    -- Start higher on the plume so the bright glowing fire jet at the crater mouth is clearly seen underneath
    local origin = volcano.crater + Vector3.new(math.cos(angle) * radius, rng:NextNumber(70, 180), math.sin(angle) * radius)
    local riseSpeed = isWarning and rng:NextNumber(45, 75) or rng:NextNumber(80, 145) * (0.65 + 0.35 * blast)
    -- drift outward & slightly across the sky toward the map so a huge mushroom cloud forms overhead
    local spread = isWarning and rng:NextNumber(10, 26) or rng:NextNumber(22, 68)
    local wind = Vector3.new(22, 0, -12)
    local vx = math.cos(angle) * spread + wind.X + rng:NextNumber(-12, 12)
    local vz = math.sin(angle) * spread + wind.Z + rng:NextNumber(-12, 12)
    local life = isWarning and rng:NextNumber(12, 17) or rng:NextNumber(16, 23)
    local spin = CFrame.Angles(rng:NextNumber() * TAU, rng:NextNumber() * TAU, rng:NextNumber() * TAU)
    local rotAxis = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
    if rotAxis.Magnitude < 0.1 then
        rotAxis = Vector3.yAxis
    else
        rotAxis = rotAxis.Unit
    end
    part.CFrame = CFrame.new(origin) * spin
    table.insert(smokeCubes, {
        part = part,
        origin = origin,
        velocity = Vector3.new(vx, riseSpeed, vz),
        baseSide = baseSide,
        endScale = endScale,
        born = now,
        life = life,
        spin = spin,
        rotAxis = rotAxis,
        rotSpeed = rng:NextNumber(0.18, 0.55),
        wobblePhase = rng:NextNumber(0, TAU),
        wobbleAmp = rng:NextNumber(12, 32),
    })
end

local function stepSmokeCubes(now)
    for i = #smokeCubes, 1, -1 do
        local sc = smokeCubes[i]
        local age = now - sc.born
        if age >= sc.life or not sc.part.Parent then
            sc.part:Destroy()
            table.remove(smokeCubes, i)
        else
            local u = age / sc.life
            -- As smoke reaches high altitude, vertical speed eases off and horizontal mushroom spread widens
            local highSpread = u * u * 90
            local swayX = math.sin(age * 0.7 + sc.wobblePhase) * sc.wobbleAmp
            local swayZ = math.cos(age * 0.6 + sc.wobblePhase) * sc.wobbleAmp
            local yOffset = sc.velocity.Y * age * (1 - 0.28 * u)
            local pos = sc.origin + Vector3.new(
                sc.velocity.X * age + swayX + math.cos(sc.wobblePhase) * highSpread,
                yOffset,
                sc.velocity.Z * age + swayZ + math.sin(sc.wobblePhase) * highSpread
            )
            local scale = 1 + (sc.endScale - 1) * math.sqrt(u)
            local side = math.floor(sc.baseSide * scale + 0.5)
            sc.part.Size = Vector3.new(side, side, side)
            sc.part.CFrame = CFrame.new(pos) * sc.spin * CFrame.fromAxisAngle(sc.rotAxis, age * sc.rotSpeed)
            -- Fade in smoothly from the crater, stay chunky in the sky, then dissolve at the top
            local alpha
            if u < 0.14 then
                alpha = u / 0.14
            elseif u > 0.65 then
                alpha = 1 - (u - 0.65) / 0.35
            else
                alpha = 1
            end
            sc.part.Transparency = 1 - alpha * 0.76
        end
    end
end

-- The imported volcano's lava is NOT painted on: the lake and the cracks are dark, cooled rock and only light up through the
-- emissive mask, so the glow can follow the event (and be off when it is over).
local GLOW_STRENGTH = 0 -- the volcano's own mesh no longer glows: lava on the volcano is seen only in the cutscene (set 5 to bring it back)
local function setVolcanoGlow(level)
    if not volcano then
        return
    end
    for _, appearance in volcano.appearances do
        if appearance.Parent then
            appearance.EmissiveStrength = GLOW_STRENGTH * level
        end
    end
end

local function updateVolcano(t, k)
    if not volcano then
        if fx then
            destroyFx()
        end
        return
    end
    if fx and fx.volcano ~= volcano then
        destroyFx()
    end
    local phase = Config.PhaseAt(t)
    if phase == "Idle" then
        setVolcanoGlow(0)
        if fx then
            destroyFx()
        end
        return
    end
    if not fx then
        buildFx()
    end
    local warn, erupt = Config.WarnSeconds, Config.EruptSeconds
    local coolStart = warn + erupt + Config.LavaSeconds
    -- strength of the eruption itself: 0 in the warning, 1 while erupting, easing down in lava and cooling
    local blast = 0
    if t >= warn and t < warn + erupt then
        blast = smooth(warn, warn + 4, t)
    elseif t >= warn + erupt and t < coolStart then
        blast = 0.35 + 0.65 * (1 - smooth(warn + erupt, warn + erupt + 25, t))
    elseif t >= coolStart then
        blast = 0.35 * (1 - smooth(coolStart, coolStart + Config.CoolSeconds * 0.8, t))
    end
    local glowK = phase == "Warning" and (0.25 + 0.55 * (t / warn)) or phase == "Cooling" and (0.9 * (1 - (t - coolStart) / Config.CoolSeconds)) or 1
    local pulse = 0.5 + 0.5 * math.sin(os.clock() * (phase == "Warning" and 3 or 5))
    fx.glow.Transparency = 1 -- the glowing lake disc is gone: the cutscene's own animated lava lake is the only lava in the caldera
    setVolcanoGlow(glowK * (0.85 + 0.15 * pulse))
    fx.light.Brightness = 8 * glowK
    if fx.calderaSound then
        fx.calderaSound.Volume = 0.4 * glowK
    end
    local e = fx.emitters
    e.smoke.Rate = phase == "Warning" and 1.5 + 5 * (t / warn) or 4 + 22 * blast
    e.fire.Rate = 30 * blast
    e.sparks.Rate = 70 * blast
    -- the fountain: rising, pulsing neon voxel blocks & columns
    local now = os.clock()
    local maxH = 60 + 540 * blast
    for _, fc in fx.fountainChunks do
        if blast <= 0.02 then
            fc.part.Transparency = 1
        else
            local u = (now * fc.speed * 0.35 + fc.phase) % 1
            local y = u * maxH
            local spread = 1 + u * (fc.isCore and 0.6 or 1.8)
            local scale = (1 - 0.35 * u) * (0.65 + 0.35 * blast)
            fc.part.Size = Vector3.new(
                fc.baseSize.X * scale,
                fc.baseSize.Y * (0.5 + 0.7 * blast) * (1 - 0.25 * u),
                fc.baseSize.Z * scale
            )
            local pos = volcano.crater + Vector3.new(fc.offsetX * spread, y + fc.part.Size.Y * 0.35, fc.offsetZ * spread)
            fc.part.CFrame = CFrame.new(pos) * fc.spin * CFrame.Angles(0, now * (fc.isCore and 0.4 or 0.9), 0)
            local heat = 1 - u
            fc.part.Color = Color3.fromRGB(255, 75, 20):Lerp(Color3.fromRGB(255, 230, 110), heat * heat)
            local fadeTop = u > 0.72 and (u - 0.72) / 0.28 or 0
            fc.part.Transparency = math.clamp(0.15 + 0.35 * (1 - blast) + fadeTop * 0.85, 0, 1)
        end
    end
    -- bombs
    local gap = blast > 0.6 and 0.16 or 0.55
    if blast > 0.05 and now - lastBomb > gap then
        lastBomb = now
        spawnBomb(now)
    end
    stepBombs()
    -- 3D voxel smoke cubes in the sky (visible from the entire map, unlike 2D particles)
    local isWarning = phase == "Warning"
    local smokeActive = isWarning or blast > 0.03
    local smokeGap = isWarning and (0.45 - 0.22 * math.clamp(t / warn, 0, 1)) or math.max(0.11, 0.32 - 0.21 * blast)
    if smokeActive and now - lastSmokeCube > smokeGap then
        lastSmokeCube = now
        spawnSmokeCube(now, blast, isWarning)
    end
    stepSmokeCubes(now)
    -- flows: build as soon as the volcano erupts (t >= warn) and keep across the whole eruption & lava phase so the cone has rivers of lava from afar!
    if t >= warn and not flows then
        local ok, result = pcall(buildFlows)
        flows = ok and result or { segments = {}, built = true }
        if not ok then
            warn("[VolcanoEvent] lava flows failed:", result)
        end
    end
    if flows then
        local since = t - warn
        for _, segment in flows.segments do
            if segment.part.Parent then
                if t >= coolStart then
                    local f = smooth(coolStart, coolStart + Config.CoolSeconds, t)
                    segment.part.Color = Color3.fromRGB(255, 120, 30):Lerp(Color3.fromRGB(110, 36, 26), math.min(1, f * 1.6))
                    segment.part.Material = f > 0.5 and Enum.Material.SmoothPlastic or Enum.Material.Neon
                    segment.part.Transparency = f > 0.85 and (f - 0.85) / 0.15 or 0
                elseif since >= segment.revealAt then
                    -- fades in as the head reaches it, white-hot at first, cooling to orange then deep red behind the head
                    local age = since - segment.revealAt
                    local appear = math.clamp(age / 1.4, 0, 1)
                    local cooled = Color3.fromRGB(255, 120, 30):Lerp(Color3.fromRGB(200, 52, 20), math.clamp((age - 6) / 24, 0, 1))
                    local heat = math.clamp(1 - age / 6, 0, 1)
                    segment.part.Color = cooled:Lerp(Color3.fromRGB(255, 236, 160), heat * heat)
                    segment.part.Transparency = 1 - appear * (0.9 - 0.08 * math.sin(now * 3 + segment.revealAt * 5))
                end
            end
        end
    end
end

-- ===== 4. River and waterfall turn to lava =====
-- Lava is a second mesh part laid over each water piece. It SHARES the water piece's EditableMesh, so it rides the same waves
-- and the same texture slide for free, and it cross-fades in over Config.RiverFadeIn seconds (and out over RiverFadeOut)
-- while the water underneath is never touched: nothing snaps, and restoring the water is just removing the overlay.
local AssetService = game:GetService("AssetService")
local LAVA_LOOP_VOLUME = 0.09 -- each river chunk's lava bubbling (nine of them overlap, so each one is quiet)
local LAVA_SURGE_VOLUME = 0.14 -- the whoosh as the lava front reaches a chunk
local SEAM_OVERLAP = Vector3.new(0.3, 0, 0) -- see buildOverlay
local LIFT = 0.06 -- the lava sits this far above the water piece (the foam is 0.045 above it, the ripple sheen higher)

local riverChunks = {} -- [index] = { base, foam, wave, fade, overlay, building, ... }
local fall = { fade = 0 } -- the waterfall sheet
local lastRiverScan = -1e9
local function scanRiver()
    if os.clock() - lastRiverScan < 2 then
        return
    end
    lastRiverScan = os.clock()
    local folder = workspace:FindFirstChild("RiverWaterLocal")
    if folder then
        for _, part in folder:GetChildren() do
            local kind, index = string.match(part.Name, "^(River%a+)(%d+)$")
            if kind and part:IsA("MeshPart") then
                index = tonumber(index)
                local chunk = riverChunks[index]
                if not chunk then
                    chunk = { fade = 0, index = index }
                    riverChunks[index] = chunk
                end
                if kind == "RiverWater" then
                    chunk.base = part
                elseif kind == "RiverFoam" then
                    chunk.foam = part
                elseif kind == "RiverWaves" then
                    chunk.wave = part
                end
            end
        end
    end
    local curtain = workspace:FindFirstChild("WaterfallCurtainLocal")
    local body = curtain and curtain:FindFirstChild("WaterfallBody")
    if body and body:IsA("MeshPart") then
        fall.base = body
    end
end

local function makeSound(parent, id, volume, speed, minD, maxD, looped)
    local sound = Instance.new("Sound")
    sound.SoundId = id
    sound.Looped = looped
    sound.Volume = volume
    sound.PlaybackSpeed = speed
    sound.RollOffMode = Enum.RollOffMode.InverseTapered
    sound.RollOffMinDistance = minD
    sound.RollOffMaxDistance = maxD
    sound.Parent = parent
    return sound
end

-- Builds the lava overlay for a piece (river chunk or waterfall sheet) the first time it is needed.
local function buildOverlay(entry, template, name, offset, withEffects, widen)
    if entry.overlay or entry.building or not entry.base or not entry.base.Parent then
        return
    end
    entry.building = true
    task.spawn(function()
        local ok, part = pcall(function()
            return AssetService:CreateMeshPartAsync(entry.base.MeshContent, { CollisionFidelity = Enum.CollisionFidelity.Box })
        end)
        if not ok or not part then
            entry.building = false
            return
        end
        part.Name = name
        part.Anchored = true
        part.CanCollide = false
        part.CanTouch = false
        part.CanQuery = false
        part.CastShadow = false
        part.DoubleSided = true
        part.Material = Enum.Material.SmoothPlastic
        part.Color = Color3.fromRGB(205, 150, 130)
        part.Transparency = 1
        part.CFrame = entry.base.CFrame + offset
        -- Neighbouring river chunks only touch at an edge, and the renderer leaves a hairline gap between them that shows the
        -- water underneath as a pale seam across the lava. Stretching each lava piece a hair longer makes them overlap.
        if widen then
            part.Size = entry.base.Size + widen
        end
        template:Clone().Parent = part
        local light = Instance.new("PointLight")
        light.Color = Color3.fromRGB(255, 120, 50)
        light.Range = 60
        light.Brightness = 0
        light.Parent = part
        entry.light = light
        if withEffects then
            local steam = Instance.new("ParticleEmitter")
            steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
            steam.Lifetime = NumberRange.new(3, 5)
            steam.Speed = NumberRange.new(5, 10)
            steam.SpreadAngle = Vector2.new(25, 25)
            steam.EmissionDirection = Enum.NormalId.Top
            steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 5), NumberSequenceKeypoint.new(1, 16) })
            steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
            steam.Color = ColorSequence.new(Color3.fromRGB(255, 220, 190), Color3.fromRGB(190, 120, 90))
            steam.LightEmission = 0.4
            steam.Rate = 0
            steam.Parent = part
            entry.steam = steam
            local idx = entry.index or 1
            local loopId = (idx % 2 == 0) and "rbxassetid://9112822944" or "rbxassetid://9112823197"
            entry.loop = makeSound(part, loopId, 0, 0.9 + (idx % 5) * 0.04, 18, 100, true)
            entry.surge = makeSound(part, "rbxassetid://9114463219", 0, 0.85, 15, 90, false)
        end
        part.Parent = entry.base.Parent
        entry.overlay = part
        entry.building = false
    end)
end

local function dropOverlay(entry)
    if entry.overlay then
        entry.overlay:Destroy()
    end
    entry.overlay, entry.light, entry.steam, entry.loop, entry.surge = nil, nil, nil, nil, nil
end

-- eases entry.fade toward target (0 water ... 1 lava) and returns it smoothed
local function stepFade(entry, target, dt)
    if target > entry.fade then
        entry.fade = math.min(target, entry.fade + dt / Config.RiverFadeIn)
    else
        entry.fade = math.max(target, entry.fade - dt / Config.RiverFadeOut)
    end
    return entry.fade * entry.fade * (3 - 2 * entry.fade)
end

local function updateChunk(chunk, target, dt, keep)
    local shown = stepFade(chunk, target, dt)
    if chunk.fade <= 0 and target == 0 and keep then
        -- not lava yet (or lava has gone again) but the event is running: keep the layer built, invisible, so nothing hitches
        buildOverlay(chunk, templates.RiverLavaAppearance, "VolcanoLava" .. chunk.index, Vector3.new(0, LIFT, 0), true, SEAM_OVERLAP)
        if chunk.overlay then
            chunk.overlay.Transparency = 1
            chunk.light.Brightness = 0
            chunk.steam.Rate = 0
            if chunk.loop.IsPlaying then
                chunk.loop:Stop()
            end
            if chunk.foam then
                chunk.foam.LocalTransparencyModifier = 0
            end
        end
        return
    end
    if chunk.fade <= 0 and target == 0 then
        if chunk.overlay then
            if chunk.wave and chunk.waveColor then
                chunk.wave.Color = chunk.waveColor
                chunk.waveColor = nil
            end
            chunk.base.LocalTransparencyModifier = 0
            if chunk.foam then
                chunk.foam.LocalTransparencyModifier = 0
            end
            if chunk.wave then
                chunk.wave.LocalTransparencyModifier = 0
            end
            dropOverlay(chunk)
        end
        return
    end
    buildOverlay(chunk, templates.RiverLavaAppearance, "VolcanoLava" .. chunk.index, Vector3.new(0, LIFT, 0), true, SEAM_OVERLAP)
    local overlay = chunk.overlay
    if not overlay or not chunk.base.Parent then
        return
    end
    overlay.CFrame = chunk.base.CFrame + Vector3.new(0, LIFT, 0)
    overlay.Transparency = 1 - shown
    chunk.light.Brightness = 3 * shown
    chunk.steam.Rate = 5 * shown
    if shown > 0.02 and not chunk.loop.IsPlaying then
        chunk.loop:Play()
        chunk.surge:Play()
    elseif shown <= 0.02 and chunk.loop.IsPlaying then
        chunk.loop:Stop()
    end
    chunk.loop.Volume = LAVA_LOOP_VOLUME * shown
    chunk.surge.Volume = LAVA_SURGE_VOLUME
    -- the water goes as the lava comes: the water, its foam and its ripple sheen all fade away completely, so nothing shows
    -- through or over the lava
    chunk.base.LocalTransparencyModifier = shown
    if chunk.foam then
        chunk.foam.LocalTransparencyModifier = shown
    end
    if chunk.wave then
        chunk.wave.LocalTransparencyModifier = shown
    end
end

local FALL_OFFSET = Vector3.new(0.8, 0.5, 0) -- in front of the sheet's veil and ripple layers
local function updateFall(target, dt, keep)
    if not fall.base or not fall.base.Parent then
        return
    end
    local shown = stepFade(fall, target, dt)
    if fall.fade <= 0 and target == 0 and keep then
        buildOverlay(fall, templates.WaterfallLavaAppearance, "VolcanoLavaFall", FALL_OFFSET, false)
        if fall.overlay then
            fall.overlay.Transparency = 1
            fall.light.Brightness = 0
        end
        return
    end
    if fall.fade <= 0 and target == 0 then
        if fall.overlay then
            local curtain = workspace:FindFirstChild("WaterfallCurtainLocal")
            if curtain then
                for _, part in curtain:GetChildren() do
                    if part:IsA("MeshPart") then
                        part.LocalTransparencyModifier = 0
                    end
                end
            end
            dropOverlay(fall)
        end
        return
    end
    buildOverlay(fall, templates.WaterfallLavaAppearance, "VolcanoLavaFall", FALL_OFFSET, false)
    local curtain = workspace:FindFirstChild("WaterfallCurtainLocal")
    if curtain then
        for _, part in curtain:GetChildren() do
            if part:IsA("MeshPart") and part.Name ~= "VolcanoLavaFall" then
                part.LocalTransparencyModifier = shown -- body, veil and ripple sheen fade out under the lava
            end
        end
    end
    if fall.overlay then
        fall.overlay.CFrame = fall.base.CFrame + FALL_OFFSET
        fall.overlay.Transparency = 1 - shown
        fall.light.Brightness = 4 * shown
    end
end

local function updateRiver(t, dt)
    scanRiver()
    for index, chunk in riverChunks do
        local target = 0
        if t then
            local turn = Config.RiverStart + (index - 1) * Config.RiverFrontDelay
            local revert = Config.RiverRevertAt + (index - 1) * Config.RiverRevertDelay
            target = (t >= turn and t < revert) and 1 or 0
        end
        -- keep the lava layer built from the start of the event until its water is back, so it can fade without a hitch
        local keep = t ~= nil
            and t < Config.RiverRevertAt + (index - 1) * Config.RiverRevertDelay + Config.RiverFadeOut + 1
        updateChunk(chunk, target, dt, keep)
    end
    local fallTarget = 0
    if t then
        fallTarget = (t >= Config.RiverStart and t < Config.RiverRevertAt) and 1 or 0
    end
    updateFall(fallTarget, dt, t ~= nil and t < Config.RiverRevertAt + Config.RiverFadeOut + 1)
end

-- ===== 4b. The bridges burn =====
-- Config.BridgeLevel(t) is how far the fire has spread (0 whole ... 1 burnt to the ends); each piece has q = 0 at the bridge's
-- middle ... 1 at its ends, and Config.BridgeBurnValue gives how burnt it is: <= 0 untouched, 0..1 burning and charring, >= 1 gone.
-- The server turns collision off for pieces that are gone (VolcanoHazardService); this draws the rest. Going back is the same
-- picture played in reverse (without flames), so the bridge grows back from its ends inward.
local EMBER = Color3.fromRGB(235, 90, 25)
local CHAR = Color3.fromRGB(26, 20, 18)
local bridges = {} -- [name] = { model, parts = { { part, q, color, fire, smoke } } }
local lastBridgeScan = -1e9

local function scanBridges()
    if os.clock() - lastBridgeScan < 2 then
        return
    end
    lastBridgeScan = os.clock()
    for _, name in Config.BridgeNames do
        local model = workspace:FindFirstChild(name, true)
        local entry = bridges[name]
        if model and (not entry or entry.model ~= model) then
            local minV, maxV = Vector3.one * math.huge, Vector3.one * -math.huge
            for _, d in model:GetDescendants() do
                if d:IsA("BasePart") then
                    local p, h = d.Position, d.Size / 2
                    minV = Vector3.new(math.min(minV.X, p.X - h.X), math.min(minV.Y, p.Y - h.Y), math.min(minV.Z, p.Z - h.Z))
                    maxV = Vector3.new(math.max(maxV.X, p.X + h.X), math.max(maxV.Y, p.Y + h.Y), math.max(maxV.Z, p.Z + h.Z))
                end
            end
            local size = maxV - minV
            local alongX = size.X > size.Z
            local centre = (minV + maxV) / 2
            local half = math.max(1, (alongX and size.X or size.Z) / 2)
            local parts = {}
            for _, d in model:GetDescendants() do
                if d:IsA("BasePart") then
                    local along = alongX and (d.Position.X - centre.X) or (d.Position.Z - centre.Z)
                    table.insert(parts, { part = d, q = math.clamp(math.abs(along) / half, 0, 1), color = d.Color, shown = 0 })
                end
            end
            bridges[name] = { model = model, parts = parts }
        elseif not model and entry then
            bridges[name] = nil -- the boss broke it (the stash puts back a fresh copy later)
        end
    end
end

local function dropFlames(entry)
    if entry.fire then
        entry.fire:Destroy()
        entry.smoke:Destroy()
        entry.fire, entry.smoke = nil, nil
    end
end

local function styleBridgePiece(entry, bv, burning, index)
    local part = entry.part
    if not part.Parent then
        return
    end
    if bv <= 0 then
        if entry.shown ~= 0 then
            entry.shown = 0
            part.Color = entry.color
            part.LocalTransparencyModifier = 0
            dropFlames(entry)
        end
        return
    end
    entry.shown = bv
    if bv < 0.3 then
        part.Color = entry.color:Lerp(EMBER, bv / 0.3)
    else
        part.Color = EMBER:Lerp(CHAR, math.clamp((bv - 0.3) / 0.5, 0, 1))
    end
    part.LocalTransparencyModifier = smooth(0.8, 1.2, bv) -- fades away as it burns through
    if burning and bv < 1 then
        if not entry.fire then
            local longest = math.max(part.Size.X, part.Size.Y, part.Size.Z)
            local fire = Instance.new("Fire")
            fire.Name = "VolcanoBridgeFire"
            fire.Size = math.clamp(longest * 0.8, 3, 9)
            fire.Heat = 6
            fire.Color = Color3.fromRGB(255, 150, 40)
            fire.SecondaryColor = Color3.fromRGB(200, 40, 10)
            fire.Parent = part
            local smoke = Instance.new("Smoke")
            smoke.Name = "VolcanoBridgeSmoke"
            smoke.Size = 6
            smoke.Opacity = (index % 3 == 0) and 0.35 or 0
            smoke.RiseVelocity = 7
            smoke.Color = Color3.fromRGB(60, 50, 48)
            smoke.Parent = part
            entry.fire, entry.smoke = fire, smoke
        end
    else
        dropFlames(entry)
    end
end

local function updateBridges(t)
    scanBridges()
    local level = Config.BridgeLevel(t)
    -- flames only while the fire is spreading; the way back is quiet
    local rising = t ~= nil and t < Config.BridgeRestoreAt
    for _, bridge in bridges do
        for index, entry in bridge.parts do
            styleBridgePiece(entry, Config.BridgeBurnValue(level, entry.q), rising, index)
        end
    end
end

-- on fire: a red tint on the player's own screen
local burnTint = Instance.new("ColorCorrectionEffect")
burnTint.Name = "VolcanoBurnTint"
burnTint.Enabled = false
burnTint.Parent = Lighting
local burnK = 0
local function updateBurnTint(dt)
    local target = player:GetAttribute("VolcanoBurning") and 1 or 0
    burnK += (target - burnK) * math.min(1, dt * 5)
    if burnK > 0.01 then
        burnTint.Enabled = true
        local flicker = 0.85 + 0.15 * math.sin(os.clock() * 11)
        burnTint.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 120, 95), 0.55 * burnK * flicker)
        burnTint.Saturation = 0.15 * burnK
    else
        burnTint.Enabled = false
    end
end

-- ===== 5. Frame loop =====
local shake = 0
local running = false
local function reset()
    if cinematic and cinematic.active then
        cinematic:Stop("reset")
    end
    cinematicFor = nil
    setVolcanoGlow(0)
    for _, chunk in riverChunks do
        chunk.fade = 0
    end
    fall.fade = 0
    applyLighting(0)
    ash.Rate = 0
    ashPart.Parent = nil
    stopEruptionRumble()
    destroyFx()
    updateRiver(nil, 1)
    updateBridges(nil)
    shake = 0
    running = false
end

local slow = 0
RunService.RenderStepped:Connect(function(dt)
    local t = eventTime()
    updateBurnTint(dt)
    updatePlug()
    if not t or Config.PhaseAt(t) == "Idle" then
        if running then
            reset()
        end
        return
    end
    running = true
    local k = Config.Intensity(t)
    -- the arena brawl has its own volcano lighting: stay out of its way
    local inArena = player:GetAttribute("ArenaIn") == true
    applyLighting(inArena and 0 or k)
    local rumbleSound = ensureEruptionRumble()
    local phase = Config.PhaseAt(t)
    if inArena then
        rumbleSound.Volume = 0
    elseif phase == "Warning" then
        rumbleSound.Volume = 0.55 + 0.35 * math.clamp(t / Config.WarnSeconds, 0, 1)
    elseif phase == "Erupting" then
        rumbleSound.Volume = 1.0
    else
        rumbleSound.Volume = 0.5 * k
    end
    local started = workspace:GetAttribute("VolcanoStart")
    if not inArena and started and startFiredFor ~= started and t < 4 then
        startFiredFor = started
        playOneShot2D("VolcanoStartBoom", "rbxassetid://9113220677", 0.8, 0.5)
    end
    if not inArena and started and blastFiredFor ~= started and t >= Config.WarnSeconds - 1.5 and t < Config.WarnSeconds + 4 then
        blastFiredFor = started
        playOneShot2D("VolcanoBlastSfx", "rbxassetid://9113220677", 1.0, 0.72)
        playOneShot2D("VolcanoFireBurstSfx", "rbxassetid://9114463219", 0.7, 0.65)
    end
    local camera = workspace.CurrentCamera
    if camera then
        ashPart.Parent = (not inArena and k > 0.2) and workspace or nil
        ashPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(0, 40, 0))
        ash.Rate = (not inArena) and 60 * k * k or 0
    end
    slow += dt
    if slow > 0.1 then
        slow = 0
        locate()
    end
    if Config.Cinematic and volcano and started ~= cinematicFor and t < 3 and not inArena then
        cinematicFor = started
        cinematic = Cinematic.new({ Config = Config, volcano = volcano, opening = volcano.opening, templates = templates })
        cinematic:Start(started)
    end
    updateVolcano(t, k)
    updateRiver(t, dt)
    updateBridges(t)
    -- a light rumble: strongest as the volcano blows
    local rumble = 0
    if t >= Config.WarnSeconds - 2 and t < Config.WarnSeconds + 10 then
        rumble = smooth(Config.WarnSeconds - 2, Config.WarnSeconds + 1, t) * (1 - smooth(Config.WarnSeconds + 4, Config.WarnSeconds + 10, t))
    elseif t < Config.WarnSeconds then
        rumble = 0.12 * (t / Config.WarnSeconds)
    end
    shake = inArena and 0 or rumble
end)

-- the camera script rewrites the camera every frame, so the rumble is applied just after it
RunService:BindToRenderStep("VolcanoRumble", Enum.RenderPriority.Camera.Value + 1, function()
    local camera = workspace.CurrentCamera
    if camera and shake > 0.005 then
        local a = shake * 0.006
        camera.CFrame = camera.CFrame
            * CFrame.Angles((math.random() - 0.5) * a, (math.random() - 0.5) * a, (math.random() - 0.5) * a * 0.5)
    end
end)

workspace:GetAttributeChangedSignal("VolcanoStart"):Connect(function()
    if eventTime() == nil and running then
        reset()
    end
end)

-- keep the volcano located and its opening plugged even when no event runs
task.spawn(function()
    while true do
        locate()
        ensurePlug()
        task.wait(3)
    end
end)
