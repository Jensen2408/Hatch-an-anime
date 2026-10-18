-- ReplicatedStorage.WaterfallRiver.RiverPath
-- Shared, deterministic river + egg maths. Server (validation) and client (visuals) compute identical positions from server time.
-- The centre line is sampled once at load into SAMPLE_COUNT + 1 points with cumulative arc length, so
-- Path.At(distance) is a binary search + lerp (distance = studs downstream from the waterfall foot).
local Config = require(script.Parent.RiverConfig)
local Path = {}
local ORIGIN = Config.Origin
local SAMPLE_COUNT = 160

-- Hermite smoothstep: 0 at edge0, 1 at edge1, smooth in between.
local function smooth(edge0, edge1, x)
    local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
    return t * t * (3 - 2 * t)
end
Path.Smooth = smooth

-- Sideways (Z) position of the centre line at normalised length t (0..1): two sine waves for a natural
-- meander, faded in over the first 12% so the plunge pool under the waterfall stays straight.
local function centerZ(t)
    return ORIGIN.Z
        + Config.Meander
            * (math.sin(t * math.pi * 2.2) * 0.7 + math.sin(t * math.pi * 4.7 + 1.3) * 0.3)
            * smooth(0, 0.12, t)
end

Path.SurfaceY = ORIGIN.Y - Config.RiverDepth
local points, cumulativeDistance = table.create(SAMPLE_COUNT + 1), table.create(SAMPLE_COUNT + 1)
for i = 0, SAMPLE_COUNT do
    local t = i / SAMPLE_COUNT
    points[i + 1] = Vector3.new(ORIGIN.X + 1 + t * Config.Length, Path.SurfaceY, centerZ(t))
end
cumulativeDistance[1] = 0
for i = 2, SAMPLE_COUNT + 1 do
    cumulativeDistance[i] = cumulativeDistance[i - 1] + (points[i] - points[i - 1]).Magnitude
end
Path.Total = cumulativeDistance[SAMPLE_COUNT + 1] -- full river length along the centre line (studs)
Path.LandDistance = 5 -- where falling eggs touch the water

-- position on the centre line (at surface height), unit tangent (downstream), unit right
function Path.At(distance)
    distance = math.clamp(distance, 0, Path.Total)
    local lo, hi = 1, SAMPLE_COUNT + 1
    while hi - lo > 1 do
        local mid = (lo + hi) // 2
        if cumulativeDistance[mid] <= distance then
            lo = mid
        else
            hi = mid
        end
    end
    local segmentStart, segmentEnd = points[lo], points[hi]
    local segmentLength = cumulativeDistance[hi] - cumulativeDistance[lo]
    local fraction = segmentLength > 0 and (distance - cumulativeDistance[lo]) / segmentLength or 0
    local tangent = (segmentEnd - segmentStart).Unit
    return segmentStart:Lerp(segmentEnd, fraction), tangent, tangent:Cross(Vector3.yAxis).Unit
end

-- River width at `distance`: wider plunge pool near the waterfall, narrowing smoothly to RiverWidth.
function Path.WidthAt(distance)
    return Config.RiverWidth
        + Config.PoolExtraWidth * (1 - smooth(Config.PoolLength * 0.4, Config.PoolLength, distance))
end

-- Transparency sequence with `count` soft-edged dashes travelling along a beam. x grows with time.
-- len = dash length (0..1 of the beam), alpha = transparency at the dash's brightest point.
function Path.Dash(x, len, alpha, count)
    count = count or 1
    local period = 1 + len
    local dashHeads = table.create(count)
    for k = 0, count - 1 do
        dashHeads[k + 1] = (x + k * period / count) % period
    end
    table.sort(dashHeads)
    local keypoints = { NumberSequenceKeypoint.new(0, 1) }
    local lastTime = 0
    -- NumberSequence needs strictly increasing times inside (0, 1); points that would break that are skipped.
    local function addKeypoint(time, value)
        if time > lastTime + 0.002 and time < 0.998 then
            table.insert(keypoints, NumberSequenceKeypoint.new(time, value))
            lastTime = time
        end
    end
    for _, head in dashHeads do
        addKeypoint(head - len, 1)
        addKeypoint(head - len * 0.35, alpha)
        addKeypoint(head, 1)
    end
    table.insert(keypoints, NumberSequenceKeypoint.new(1, 1))
    return NumberSequence.new(keypoints)
end

return Path
