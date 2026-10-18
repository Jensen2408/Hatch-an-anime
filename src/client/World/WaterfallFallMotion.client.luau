-- Falling streaks, foam boil and ripple rings for the waterfall.
-- Everything is local (client-only) so it is smooth and costs the server nothing.
local RunService = game:GetService("RunService")

local fx = workspace:WaitForChild("WaterfallRiver"):WaitForChild("FallFX")
local FRONT_X = fx:GetAttribute("FrontX")
local TOP_Y = fx:GetAttribute("TopY")
local BASE_Y = fx:GetAttribute("BaseY")
local Z0, Z1 = fx:GetAttribute("Z0"), fx:GetAttribute("Z1")
local HEIGHT = TOP_Y - BASE_Y
local GRAVITY = 70

local folder = Instance.new("Folder")
folder.Name = "LocalFallMotion"
folder.Parent = fx

local function part(size, color, transparency, shape)
    local p = Instance.new("Part")
    p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
    p.Material = Enum.Material.SmoothPlastic
    p.Size = size
    p.Color = color
    p.Transparency = transparency
    if shape then
        p.Shape = shape
    end
    p.Parent = folder
    return p
end

---------------------------------------------------------------- falling streaks
-- white ribbons that start slow at the lip and speed up as they fall
local streaks = {}
for i = 1, 46 do
    local depth = math.random() -- 0 = against the sheet, 1 = in front
    local p = part(
        Vector3.new(0.12, 1, 0.12 + math.random() * 0.35),
        Color3.fromRGB(235, 250, 255),
        0.35 + math.random() * 0.3
    )
    streaks[i] = {
        p = p,
        z = Z0 + 0.6 + math.random() * (Z1 - Z0 - 1.2),
        x = FRONT_X + 0.05 + depth * 0.35,
        t = math.random() * 1.0, -- time since leaving the lip
        len = 2.5 + math.random() * 4,
        v0 = 2 + math.random() * 3,
    }
end
local FALL_TIME = (-2 + math.sqrt(4 + 2 * GRAVITY * HEIGHT)) / GRAVITY

---------------------------------------------------------------- foam boil
local foam = {}
for i = 1, 14 do
    local d = 1.5 + math.random() * 2.2
    local p = part(Vector3.new(d, d * 0.6, d), Color3.fromRGB(245, 253, 255), 0.25, Enum.PartType.Ball)
    p.Material = Enum.Material.Sand
    foam[i] = {
        p = p,
        d = d,
        x = FRONT_X + 0.6 + math.random() * 3.2,
        z = Z0 + math.random() * (Z1 - Z0),
        phase = math.random() * math.pi * 2,
        rate = 3 + math.random() * 4,
    }
end

---------------------------------------------------------------- ripple rings
local RING_SEGMENTS = 20
local rings = {}
for r = 1, 5 do
    local segs = {}
    for i = 1, RING_SEGMENTS do
        segs[i] = part(Vector3.new(0.12, 0.05, 1), Color3.fromRGB(225, 248, 255), 1)
    end
    rings[r] = { segs = segs, age = (r - 1) * 0.6, life = 3, z = 20, x = FRONT_X + 2 }
end
local function resetRing(ring)
    ring.age = 0
    ring.life = 2.4 + math.random() * 1.2
    ring.z = Z0 + 2 + math.random() * (Z1 - Z0 - 4)
    ring.x = FRONT_X + 2 + math.random() * 2
end
for _, r in rings do
    resetRing(r)
    r.age = math.random() * r.life
end

---------------------------------------------------------------- update
local camera = workspace.CurrentCamera
local updateElapsed = 0
local centre = Vector3.new(FRONT_X, (TOP_Y + BASE_Y) / 2, (Z0 + Z1) / 2)

RunService.RenderStepped:Connect(function(dt)
    updateElapsed += dt
    if updateElapsed < 1 / 30 then
        return
    end
    dt = math.min(updateElapsed, 0.1)
    updateElapsed = 0
    camera = workspace.CurrentCamera
    if not camera or not fx:IsDescendantOf(workspace) then
        return
    end
    -- skip the work when nobody is near
    if (camera.CFrame.Position - centre).Magnitude > 260 then
        return
    end
    local now = os.clock()

    for _, s in streaks do
        s.t += dt
        if s.t > FALL_TIME then
            s.t -= FALL_TIME
            s.z = Z0 + 0.6 + math.random() * (Z1 - Z0 - 1.2)
        end
        local t = s.t
        local drop = s.v0 * t + 0.5 * GRAVITY * t * t
        local speed = s.v0 + GRAVITY * t
        -- stretch with speed, like motion blur
        local len = math.min(s.len * (0.5 + speed / 25), drop + 0.2, 9)
        local y = TOP_Y - drop + len / 2
        local wobble = math.sin(now * 3 + s.z) * 0.08
        s.p.Size = Vector3.new(s.p.Size.X, len, s.p.Size.Z)
        s.p.CFrame = CFrame.new(s.x + wobble, math.max(y, BASE_Y + len / 2), s.z)
        -- fade in at the lip, fade out into the splash
        local fadeIn = math.clamp(drop / 3, 0, 1)
        local fadeOut = math.clamp((y - len / 2 - BASE_Y) / 3, 0, 1)
        s.p.Transparency = 1 - (1 - 0.45) * fadeIn * fadeOut
    end

    for _, f in foam do
        local k = 0.5 + 0.5 * math.sin(now * f.rate + f.phase)
        local d = f.d * (0.75 + 0.45 * k)
        f.p.Size = Vector3.new(d, d * (0.45 + 0.25 * k), d)
        f.p.CFrame = CFrame.new(f.x + math.sin(now * 0.7 + f.phase) * 0.4, BASE_Y + 0.1 * k, f.z)
        f.p.Transparency = 0.15 + 0.35 * (1 - k)
    end

    for _, ring in rings do
        ring.age += dt
        if ring.age > ring.life then
            resetRing(ring)
        end
        local a = ring.age / ring.life
        local radius = 1.5 + a * 6
        local segLen = 2 * math.pi * radius / RING_SEGMENTS * 1.05
        for i, seg in ring.segs do
            local ang = (i / RING_SEGMENTS) * math.pi * 2
            local px = ring.x + math.cos(ang) * radius
            local pz = ring.z + math.sin(ang) * radius
            -- keep the ring on the downstream side of the fall
            seg.Size = Vector3.new(0.14, 0.04, segLen)
            seg.CFrame = CFrame.new(math.max(px, FRONT_X + 0.3), BASE_Y + 0.08, pz) * CFrame.Angles(0, -ang, 0)
            seg.Transparency = (px < FRONT_X + 0.3 or pz < Z0 - 2 or pz > Z1 + 2) and 1 or (0.35 + 0.65 * a)
        end
    end
end)
