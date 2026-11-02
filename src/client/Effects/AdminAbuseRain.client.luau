-- AdminAbuseRain (LocalScript, StarterPlayerScripts)
-- While an admin abuse runs, comets of its item fall in the distance (coins for Cash, eggs for Hatch, golden eggs for
-- Legendary) and sparks twinkle in the air, both in the abuse's colour. Everything stays well in front of the camera so
-- it never covers the view, and abuses running at once thin each other out.
-- One invisible part per kind carries the sparks around eye height; sparks stay in the world once they leave it. Comets
-- are a small shared pool of billboards with a Trail, flown here each frame.
-- Local only: watches the workspace attributes AdminAbuseService writes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage:WaitForChild("AdminAbuseConfig"))

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SPARK_RATE = 34
local GLOW = "rbxassetid://130563114903838" -- the soft halo of the announcement banners
local AIR_SIZE = Vector3.new(80, 26, 80)
local AIR_AHEAD = 56
local COMET_COUNT = 10
local COMET_SIZE = 1.9 -- studs, the item; its halo is 2.6 times that
local COMET_VELOCITY = Vector3.new(9, -46, 4) -- all lean the same way, like a meteor shower
local COMET_FLOOR = 34 -- studs below the camera where a comet ends

local function twinkle(...)
    local keypoints = {}
    local values = { ... }
    for index, value in values do
        table.insert(keypoints, NumberSequenceKeypoint.new((index - 1) / (#values - 1), value))
    end
    return NumberSequence.new(keypoints)
end

local camera = workspace.CurrentCamera
local random = Random.new()
local kinds = {}
local runningKinds = {}
local comets = {}

local function newPart(name, size)
    local part = Instance.new("Part")
    part.Name = name
    part.Anchored = true
    part.CanCollide = false
    part.CanTouch = false
    part.CanQuery = false
    part.CastShadow = false
    part.Transparency = 1
    part.Size = size
    part.Parent = camera
    return part
end

local function newSparks(parent, kind)
    local sparks = Instance.new("ParticleEmitter")
    sparks.Name = "Sparks"
    sparks.Texture = SPARK
    sparks.EmissionDirection = Enum.NormalId.Top
    sparks.Lifetime = NumberRange.new(1.4, 2.6)
    sparks.Speed = NumberRange.new(1, 3)
    sparks.SpreadAngle = Vector2.new(40, 40)
    sparks.Rotation = NumberRange.new(0, 90)
    sparks.RotSpeed = NumberRange.new(-50, 50)
    sparks.Size = twinkle(0, 1.5, 0.6, 1.6, 0)
    sparks.Transparency = twinkle(1, 0, 0.5, 0, 1)
    sparks.LightEmission = 0.25
    sparks.LightInfluence = 0
    sparks.Color = ColorSequence.new(Config.Kinds[kind].Glow)
    sparks.Enabled = false
    sparks.Parent = parent
    return sparks
end

local function newComet(parent)
    local head = Instance.new("Attachment")
    head.Parent = parent
    local tail = Instance.new("Attachment")
    tail.Parent = parent
    local billboard = Instance.new("BillboardGui")
    billboard.Size = UDim2.fromScale(COMET_SIZE, COMET_SIZE)
    billboard.LightInfluence = 0
    billboard.Enabled = false
    billboard.Parent = head
    local halo = Instance.new("ImageLabel")
    halo.BackgroundTransparency = 1
    halo.Image = GLOW
    halo.ImageTransparency = 0.25
    halo.AnchorPoint = Vector2.new(0.5, 0.5)
    halo.Position = UDim2.fromScale(0.5, 0.5)
    halo.Size = UDim2.fromScale(2.6, 2.6)
    halo.Parent = billboard
    local item = Instance.new("ImageLabel")
    item.BackgroundTransparency = 1
    item.ScaleType = Enum.ScaleType.Fit
    item.Size = UDim2.fromScale(1, 1)
    item.ZIndex = 2
    item.Parent = billboard
    local trail = Instance.new("Trail")
    trail.Attachment0 = head
    trail.Attachment1 = tail
    trail.FaceCamera = true
    trail.Lifetime = 0.45
    trail.LightEmission = 0.7
    trail.LightInfluence = 0
    trail.Transparency = NumberSequence.new(0.05, 1)
    trail.WidthScale = NumberSequence.new(1, 0)
    trail.Enabled = false
    trail.Parent = parent
    return { Head = head, Tail = tail, Billboard = billboard, Halo = halo, Item = item, Trail = trail }
end

local function hideComet(comet)
    comet.Trail.Enabled = false
    comet.Billboard.Enabled = false
    comet.Position = nil
end

-- Sends a comet from the top again as one of the running abuses, after a short pause so they never fall in a row.
local function launch(comet, now, forward)
    comet.Trail:Clear()
    comet.ReadyAt = comet.ReadyAt or now + random:NextNumber(0.2, 2.4)
    if now < comet.ReadyAt then
        return
    end
    comet.ReadyAt = nil
    local definition = Config.Kinds[runningKinds[random:NextInteger(1, #runningKinds)]]
    comet.Item.Image = definition.Rain
    comet.Halo.ImageColor3 = definition.Glow
    comet.Trail.Color = ColorSequence.new(definition.Glow)
    local right = Vector3.new(-forward.Z, 0, forward.X)
    comet.Position = camera.CFrame.Position
        + forward * random:NextNumber(46, 118)
        + right * random:NextNumber(-55, 55)
        + Vector3.new(0, random:NextNumber(28, 58), 0)
    comet.Velocity = COMET_VELOCITY * random:NextNumber(0.8, 1.2)
    comet.JustLaunched = true
end

local function flyComets(dt, forward)
    local now = os.clock()
    local floor = camera.CFrame.Position.Y - COMET_FLOOR
    for _, comet in comets do
        if #runningKinds == 0 or (comet.Position and comet.Position.Y < floor) then
            hideComet(comet)
        end
        if #runningKinds > 0 and not comet.Position then
            launch(comet, now, forward)
        end
        if comet.Position then
            comet.Position += comet.Velocity * dt
            comet.Head.WorldPosition = comet.Position
            comet.Tail.WorldPosition = comet.Position + Vector3.new(0.9, 0, 0)
            -- one frame after the jump to the top, or the trail would draw a line across the sky
            comet.Trail.Enabled = not comet.JustLaunched
            comet.Billboard.Enabled = true
            comet.JustLaunched = false
        end
    end
end

local function isRunning(kind)
    return workspace:GetAttribute("Abuse" .. kind .. "Multiplier") ~= nil
end

local function refresh()
    table.clear(runningKinds)
    for _, kind in Config.Order do
        if isRunning(kind) then
            table.insert(runningKinds, kind)
        end
    end
    for kind, effect in kinds do
        effect.Sparks.Enabled = isRunning(kind)
        effect.Sparks.Rate = SPARK_RATE / math.sqrt(math.max(#runningKinds, 1))
    end
end

for _, kind in Config.Order do
    local air = newPart("AbuseSparks" .. kind, AIR_SIZE)
    kinds[kind] = { Air = air, Sparks = newSparks(air, kind) }
    workspace:GetAttributeChangedSignal("Abuse" .. kind .. "Multiplier"):Connect(refresh)
end
local cometHolder = newPart("AbuseComets", Vector3.one)
for index = 1, COMET_COUNT do
    comets[index] = newComet(cometHolder)
end
refresh()

RunService.RenderStepped:Connect(function(dt)
    local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
    local forward = look.Magnitude > 0.01 and look.Unit or Vector3.zAxis
    for _, kind in runningKinds do
        kinds[kind].Air.Position = camera.CFrame.Position + forward * AIR_AHEAD
    end
    flyComets(dt, forward)
end)
