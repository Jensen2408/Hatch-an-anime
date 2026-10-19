-- StarterPlayerScripts.WaterfallFallMotion
-- Falling streaks, foam boil and ripple rings for the waterfall.
-- Geometry comes from attributes on workspace.WaterfallRiver.FallFX: FrontX, TopY, BaseY, Z0, Z1.
-- Everything is local (client-only) so it is smooth and costs the server nothing.
local RunService = game:GetService("RunService")

local fallFx = workspace:WaitForChild("WaterfallRiver"):WaitForChild("FallFX")
local FRONT_X = fallFx:GetAttribute("FrontX")
local TOP_Y = fallFx:GetAttribute("TopY")
local BASE_Y = fallFx:GetAttribute("BaseY")
local Z_MIN, Z_MAX = fallFx:GetAttribute("Z0"), fallFx:GetAttribute("Z1")
local HEIGHT = TOP_Y - BASE_Y
local GRAVITY = 70

local motionFolder = Instance.new("Folder")
motionFolder.Name = "LocalFallMotion"
motionFolder.Parent = fallFx

local function makePart(size, color, transparency, shape)
    local newPart = Instance.new("Part")
    newPart.Anchored, newPart.CanCollide, newPart.CanTouch, newPart.CanQuery, newPart.CastShadow =
        true, false, false, false, false
    newPart.Material = Enum.Material.SmoothPlastic
    newPart.Size = size
    newPart.Color = color
    newPart.Transparency = transparency
    if shape then
        newPart.Shape = shape
    end
    newPart.Parent = motionFolder
    return newPart
end

-- ===== 1. Falling streaks =====
-- white ribbons that start slow at the lip and speed up as they fall
local streaks = {}
for i = 1, 46 do
    local depth = math.random() -- 0 = against the sheet, 1 = in front
    local streakPart = makePart(
        Vector3.new(0.12, 1, 0.12 + math.random() * 0.35),
        Color3.fromRGB(235, 250, 255),
        0.35 + math.random() * 0.3
    )
    streaks[i] = {
        p = streakPart,
        z = Z_MIN + 0.6 + math.random() * (Z_MAX - Z_MIN - 1.2),
        x = FRONT_X + 0.05 + depth * 0.35,
        t = math.random() * 1.0, -- time since leaving the lip
        len = 2.5 + math.random() * 4,
        v0 = 2 + math.random() * 3,
    }
end
-- time to fall HEIGHT starting at 2 studs/s (solves 2t + GRAVITY*t^2/2 = HEIGHT); faster streaks rest at BASE_Y
local FALL_TIME = (-2 + math.sqrt(4 + 2 * GRAVITY * HEIGHT)) / GRAVITY

-- ===== 2. Foam boil =====
local foam = {}
for i = 1, 14 do
    local diameter = 1.5 + math.random() * 2.2
    local foamPart = makePart(
        Vector3.new(diameter, diameter * 0.6, diameter),
        Color3.fromRGB(245, 253, 255),
        0.25,
        Enum.PartType.Ball
    )
    foamPart.Material = Enum.Material.Sand
    foam[i] = {
        p = foamPart,
        d = diameter,
        x = FRONT_X + 0.6 + math.random() * 3.2,
        z = Z_MIN + math.random() * (Z_MAX - Z_MIN),
        phase = math.random() * math.pi * 2,
        rate = 3 + math.random() * 4,
    }
end

-- ===== 3. Ripple rings =====
local RING_SEGMENTS = 20
local rings = {}
for ringIndex = 1, 5 do
    local segments = {}
    for i = 1, RING_SEGMENTS do
        segments[i] = makePart(Vector3.new(0.12, 0.05, 1), Color3.fromRGB(225, 248, 255), 1)
    end
    rings[ringIndex] = { segs = segments, age = (ringIndex - 1) * 0.6, life = 3, z = 20, x = FRONT_X + 2 }
end
local function resetRing(ring)
    ring.age = 0
    ring.life = 2.4 + math.random() * 1.2
    ring.z = Z_MIN + 2 + math.random() * (Z_MAX - Z_MIN - 4)
    ring.x = FRONT_X + 2 + math.random() * 2
end
for _, ring in rings do
    resetRing(ring)
    ring.age = math.random() * ring.life
end

-- ===== 4. Update (~30 Hz, only near the camera) =====
local camera = workspace.CurrentCamera
local updateElapsed = 0
local centre = Vector3.new(FRONT_X, (TOP_Y + BASE_Y) / 2, (Z_MIN + Z_MAX) / 2)

RunService.RenderStepped:Connect(function(dt)
    updateElapsed += dt
    if updateElapsed < 1 / 30 then
        return
    end
    dt = math.min(updateElapsed, 0.1)
    updateElapsed = 0
    camera = workspace.CurrentCamera
    if not camera or not fallFx:IsDescendantOf(workspace) then
        return
    end
    -- skip the work when nobody is near
    if (camera.CFrame.Position - centre).Magnitude > 260 then
        return
    end
    local now = os.clock()

    for _, streak in streaks do
        streak.t += dt
        if streak.t > FALL_TIME then
            streak.t -= FALL_TIME
            streak.z = Z_MIN + 0.6 + math.random() * (Z_MAX - Z_MIN - 1.2)
        end
        local fallTime = streak.t
        local drop = streak.v0 * fallTime + 0.5 * GRAVITY * fallTime * fallTime
        local speed = streak.v0 + GRAVITY * fallTime
        -- stretch with speed, like motion blur
        local len = math.min(streak.len * (0.5 + speed / 25), drop + 0.2, 9)
        local y = TOP_Y - drop + len / 2
        local wobble = math.sin(now * 3 + streak.z) * 0.08
        streak.p.Size = Vector3.new(streak.p.Size.X, len, streak.p.Size.Z)
        streak.p.CFrame = CFrame.new(streak.x + wobble, math.max(y, BASE_Y + len / 2), streak.z)
        -- fade in at the lip, fade out into the splash
        local fadeIn = math.clamp(drop / 3, 0, 1)
        local fadeOut = math.clamp((y - len / 2 - BASE_Y) / 3, 0, 1)
        streak.p.Transparency = 1 - (1 - 0.45) * fadeIn * fadeOut
    end

    for _, blob in foam do
        local pulse = 0.5 + 0.5 * math.sin(now * blob.rate + blob.phase)
        local diameter = blob.d * (0.75 + 0.45 * pulse)
        blob.p.Size = Vector3.new(diameter, diameter * (0.45 + 0.25 * pulse), diameter)
        blob.p.CFrame = CFrame.new(blob.x + math.sin(now * 0.7 + blob.phase) * 0.4, BASE_Y + 0.1 * pulse, blob.z)
        blob.p.Transparency = 0.15 + 0.35 * (1 - pulse)
    end

    for _, ring in rings do
        ring.age += dt
        if ring.age > ring.life then
            resetRing(ring)
        end
        local lifeFraction = ring.age / ring.life
        local radius = 1.5 + lifeFraction * 6
        local segLen = 2 * math.pi * radius / RING_SEGMENTS * 1.05
        for i, seg in ring.segs do
            local angle = (i / RING_SEGMENTS) * math.pi * 2
            local segmentX = ring.x + math.cos(angle) * radius
            local segmentZ = ring.z + math.sin(angle) * radius
            -- keep the ring on the downstream side of the fall
            seg.Size = Vector3.new(0.14, 0.04, segLen)
            seg.CFrame = CFrame.new(math.max(segmentX, FRONT_X + 0.3), BASE_Y + 0.08, segmentZ)
                * CFrame.Angles(0, -angle, 0)
            seg.Transparency = (segmentX < FRONT_X + 0.3 or segmentZ < Z_MIN - 2 or segmentZ > Z_MAX + 2) and 1
                or (0.35 + 0.65 * lifeFraction)
        end
    end
end)
