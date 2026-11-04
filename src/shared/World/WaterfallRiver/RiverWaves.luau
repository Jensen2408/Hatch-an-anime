-- ReplicatedStorage.WaterfallRiver.RiverWaves
-- Shared, deterministic river wave field (adapted from the MIC SIDEWAYS! ocean). The RiverWater client renders it and
-- RollingMotion floats the eggs on it, so both agree without replicating anything. Everything is a pure function of
-- server time plus the high tide workspace attributes written by the server's RiverWater script:
--   HighTideStartedAt, HighTideEndsAt   server time of the current (or last) high tide window
--
-- Usage: local state = Waves.State(workspace:GetServerTimeNow()) once per frame, then Waves.HeightAt(state, d, s)
-- for any point, where d = studs downstream from the waterfall foot (RiverPath distance) and s = -1..1 across the
-- river (wall to wall). HeightAt returns studs above RiverPath.SurfaceY.
--
-- Layers:
--   current ripples  three short trains running downstream, two of them skewed across the flow so they cross into
--                    the V-shaped chop of fast shallow water, plus slow standing riffles
--   plunge pool      extra chop and rings spreading from where the waterfall lands
--   high tide        the waterfall bursts (WaterfallCurtain), the whole river rises by TideRise, the chop roughens,
--                    the current runs up to 1 + FlowBoost times faster, and surge waves pour off the waterfall foot
--                    and race downstream to the east wall
--
-- Flow speed: Waves.FlowTime(t0, t1) is the "current time" elapsed between two server times, (t1 - t0) stretched by
-- the tide's extra speed. RollingMotion multiplies it by the egg speed, so eggs speed up and slow down smoothly with
-- no jumps, on the server and every client alike.
local Config = require(script.Parent.RiverConfig)
local Path = require(script.Parent.RiverPath)
local smooth = Path.Smooth

local Waves = {}

Waves.TideRise = 0.75 -- studs the river rises at full high tide (the banks are RiverDepth = 1.6 above still water)
Waves.TideRiseTime = 12 -- seconds to rise at the start of the window (was 8: slower is smoother)
Waves.TideFallTime = 16 -- seconds to fall back at its end (was 10)
Waves.FlowBoost = 1.5 -- extra current at full tide: eggs and ripples move 2.5x as fast
Waves.SurgeSpeed = 24 -- studs per second, downstream from the waterfall foot
Waves.SurgeInterval = 5 -- seconds between surges
Waves.SurgeHeight = 0.9 -- crest height of a surge above the raised tide level (was 1.1)
Waves.MaxHeight = 2.3 -- mid-channel ceiling (studs above still water): surge crests may mound above the banks
Waves.EdgeMaxHeight = 1.4 -- ceiling against the walls, so the water never spills over the banks

local TOTAL = Path.Total
local IMPACT_DISTANCE = 2 -- where the waterfall lands, along the river
local POOL_END = Config.PoolLength + 4

-- How far into the high tide window `now` is: 0 outside it, easing to 1 after TideRiseTime and back to 0 over the
-- last TideFallTime seconds.
local function tideStrength(startAt, endsAt, now)
    if not startAt or not endsAt or now <= startAt or now >= endsAt then
        return 0
    end
    return smooth(startAt, startAt + Waves.TideRiseTime, now) * (1 - smooth(endsAt - Waves.TideFallTime, endsAt, now))
end
Waves.TideStrength = tideStrength

-- Integral of tideStrength from the start of the window to x, in closed form (the integral of the smoothstep
-- 3u^2 - 2u^3 is u^3 - u^4 / 2). Assumes the rise and the fall don't overlap (windows are at least 25 s).
local function tideIntegral(startAt, endsAt, x)
    if not startAt or not endsAt or x <= startAt then
        return 0
    end
    local rise, fall = Waves.TideRiseTime, Waves.TideFallTime
    local u = math.min((x - startAt) / rise, 1)
    local total = rise * (u ^ 3 - u ^ 4 / 2)
    local holdEnd = endsAt - fall
    if x > startAt + rise then
        total += math.max(0, math.min(x, holdEnd) - (startAt + rise))
    end
    if x > holdEnd then
        local v = math.min((x - holdEnd) / fall, 1)
        total += fall * (v - (v ^ 3 - v ^ 4 / 2))
    end
    return total
end

-- Seconds of current between server times t0 and t1 (>= t1 - t0; longer while the tide speeds the river up).
function Waves.FlowTime(t0, t1)
    local startAt = workspace:GetAttribute("HighTideStartedAt")
    local endsAt = workspace:GetAttribute("HighTideEndsAt")
    return (t1 - t0) + Waves.FlowBoost * (tideIntegral(startAt, endsAt, t1) - tideIntegral(startAt, endsAt, t0))
end

-- Per-frame state: the tide level and the surges currently in the river.
function Waves.State(now)
    local startAt = workspace:GetAttribute("HighTideStartedAt")
    local endsAt = workspace:GetAttribute("HighTideEndsAt")
    local tide = tideStrength(startAt, endsAt, now)
    local surges = {}
    if startAt and endsAt and now > startAt then
        -- Surge k pours off the waterfall foot at firstAt + k * interval and runs until it passes the east wall.
        local firstAt = startAt + 1.5
        local lastAt = endsAt - Waves.TideFallTime
        local travelTime = (TOTAL + 30) / Waves.SurgeSpeed
        local newest = math.floor((now - firstAt) / Waves.SurgeInterval)
        local oldest = math.max(0, math.ceil((now - firstAt - travelTime) / Waves.SurgeInterval))
        for k = oldest, newest do
            local launchedAt = firstAt + k * Waves.SurgeInterval
            if launchedAt <= lastAt and launchedAt <= now then
                local crest = -6 + (now - launchedAt) * Waves.SurgeSpeed
                -- Sets: every third surge is bigger; the very first one (the burst) is the biggest. Surges shrink
                -- as the tide falls and build up as they leave the wide plunge pool.
                local size = (0.7 + 0.3 * math.sin(k * 2.1) ^ 2 + (k % 3 == 2 and 0.25 or 0) + (k == 0 and 0.35 or 0))
                    * math.max(tide, k <= 1 and 0.8 or 0, 0.25 * tideStrength(startAt, endsAt, launchedAt))
                    * (0.7 + 0.3 * smooth(0, POOL_END + 20, crest))
                table.insert(surges, { crest = crest, height = Waves.SurgeHeight * size, index = k })
            end
        end
    end
    -- Time terms of every wave train, so per-point work is multiplies only: sin(a - wt) = sin a cos wt - cos a sin wt.
    return {
        now = now,
        tide = tide,
        startedAt = startAt,
        level = Waves.TideRise * tide,
        flow = 1 + Waves.FlowBoost * tide, -- current speed multiplier
        surges = surges,
        c1 = math.cos(5.2 * now),
        s1 = math.sin(5.2 * now),
        c2 = math.cos(7.9 * now),
        s2 = math.sin(7.9 * now),
        c3 = math.cos(11 * now),
        s3 = math.sin(11 * now),
        c4 = math.cos(1.6 * now),
        s4 = math.sin(1.6 * now),
        c5 = math.cos(7 * now),
        s5 = math.sin(7 * now),
    }
end

-- Shape of a surge at x studs downstream of its crest (crest = 1): a steep breaking front downstream, then a raised
-- plateau behind it (upstream) with a train of smaller undulations, like the whelps behind a real bore.
local function surgeProfile(x)
    if x > 0 then
        return math.exp(-(x / 4.4) ^ 2) -- a longer, gentler front (was 2.4)
    end
    local y = -x
    return 0.3 * math.exp(-y / 70) + 0.7 * math.exp(-(y / 5.5) ^ 2) + 0.2 * math.sin(y * 0.72) * math.exp(-y / 16)
end
Waves.SurgeProfile = surgeProfile

-- The time-independent part of a point's waves (distance d downstream, s = -1..1 across, wall to wall). The renderer
-- prepares each vertex once; HeightAt prepares on the fly.
function Waves.Prepare(d, s)
    local halfWidth = Path.WidthAt(math.clamp(d, 0, TOTAL)) * 0.5
    local lateral = s * halfWidth
    -- Current ripples: crests run downstream at ~9 studs/s; the skewed pair crosses into V-shaped chop.
    local a1 = 0.571 * (d - 0.35 * lateral)
    local a2 = 0.86 * (d + 0.42 * lateral) + 1.3
    local a3 = 1.21 * d + 0.6 * lateral + 4
    local b = 0.13 * d
    -- Plunge pool: rougher water and rings spreading from the impact point.
    local pool = 1 - smooth(6, POOL_END, d)
    local r = math.sqrt((d - IMPACT_DISTANCE) ^ 2 + lateral * lateral)
    return {
        d = d,
        lag = 1.8 * s * s, -- bank drag holds surge crests back near the walls, so they bow downstream mid-channel
        sa1 = 0.06 * math.sin(a1),
        ca1 = 0.06 * math.cos(a1),
        sa2 = 0.045 * math.sin(a2),
        ca2 = 0.045 * math.cos(a2),
        sa3 = 0.03 * math.sin(a3),
        ca3 = 0.03 * math.cos(a3),
        -- Standing riffles over the bed, breathing slowly.
        riffle = 0.035 * math.sin(0.33 * d + 1.7 * s),
        sb = math.sin(b),
        cb = math.cos(b),
        poolBoost = 1 + 1.8 * pool,
        ringS = 0.13 * pool * math.exp(-r / 9) * math.sin(1.1 * r),
        ringC = 0.13 * pool * math.exp(-r / 9) * math.cos(1.1 * r),
        edge = 1 - 0.55 * s * s, -- the walls calm the chop (the mesh edge tucks under the bank there)
        cap = Waves.MaxHeight + (Waves.EdgeMaxHeight - Waves.MaxHeight) * smooth(0.45, 1, math.abs(s)),
    }
end

-- Studs above RiverPath.SurfaceY at a prepared point.
function Waves.HeightAtPrepared(state, p)
    local chop = (p.sa1 * state.c1 - p.ca1 * state.s1)
        + (p.sa2 * state.c2 - p.ca2 * state.s2)
        + (p.sa3 * state.c3 - p.ca3 * state.s3)
        + p.riffle * (state.s4 * p.cb + state.c4 * p.sb)
    chop = chop * p.poolBoost + (p.ringS * state.c5 - p.ringC * state.s5)
    -- High tide roughens the surface.
    local h = state.level + chop * (1 + 0.9 * state.tide) * p.edge
    local d = p.d
    for _, surge in state.surges do
        local x = d - surge.crest + p.lag
        if x < 10 and x > -120 then
            h += surge.height * surgeProfile(x)
        end
    end
    local knee = p.cap - 0.3
    if h > knee then
        -- Soft ceiling: heights ease into the cap instead of flattening abruptly.
        h = knee + 0.3 * math.tanh((h - knee) / 0.3)
    end
    return h
end

-- Studs above RiverPath.SurfaceY at distance d downstream, s = -1..1 across (wall to wall).
function Waves.HeightAt(state, d, s)
    return Waves.HeightAtPrepared(state, Waves.Prepare(d, s))
end

-- World Y of the water at a world-space point on the river (nil off the river). Used by eggs and effects.
function Waves.SurfaceAt(state, distance, lateralStuds)
    local halfWidth = Path.WidthAt(math.clamp(distance, 0, TOTAL)) * 0.5
    return Path.SurfaceY + Waves.HeightAt(state, distance, math.clamp(lateralStuds / halfWidth, -1, 1))
end

return Waves
