--!strict
--[[ ReplicatedStorage.VolcanoEvent.VolcanoConfig: shared numbers for the Volcano Eruption event.

The event, seconds after its start (everything on the server clock, so all players see the same thing):
  0      WARNING   the sky darkens, the volcano rumbles and glows, smoke starts
  20     ERUPTING  the volcano erupts: plume, lava bombs, lava runs down the cone; the world lights up red
  30     the river starts turning to lava at the waterfall and the front runs downstream, one chunk at a time
  50     LAVA      the river is lava; the eruption settles into a steady glow and ash fall
  120    COOLING   the lava cools back to water, upstream first, and the world lights ease back to normal
  150    over

The volcano itself is the imported voxel model (tools/volcano/build_volcano.py -> assets/Volcano/FarVolcano.glb) grouped as ONE
Model named Config.ModelName anywhere in the workspace. Scripts read its position from its bounding box: the crater is the
top-centre, the rim is the highest point, the lava lake sits LakeDepth studs below it. ]]
local Config = {}

Config.ModelName = "FarVolcano"
-- Where the volcano stands. VolcanoEventService moves the model here (once per server start) so it sits on the horizon behind
-- the far trees, west of the waterfall and beyond the map's edge (the map's terrain ends at x = -1022). X / Z are the centre
-- of its base, Y is the ground level; BuryDepth sinks the foot below that so no cliff edge shows. To place it by hand instead,
-- set the attribute ManualPlace = true on the model. Tune this one vector to nudge where it appears.
Config.Position = Vector3.new(-1480, 0, 440)
Config.BuryDepth = 30
Config.LakeDepth = 70 -- studs from the rim down to the lava lake (the generator's BOWL, 7 blocks of 10)
Config.CraterRadius = 110 -- studs
-- Heights of the imported model's caldera, in studs above its lowest point (the generator's FLOOR_H / LIP_H / RIM_H times its 10 stud
-- block): the floor of the crater, the lip of the opening cut through its rim (lava that rises past it spills out), and the rim.
Config.LakeFloor = 560
Config.LipHeight = 595
Config.RimHeight = 640
Config.LipRadius = 72 -- radius of the lava lake when it has risen to the lip

-- The cutscene at the start of the event (VolcanoCinematic): the camera flies to the volcano and watches the lava rise and the blast.
Config.Cinematic = true
Config.CinematicSeconds = 33

-- Schedule: every CycleSeconds, OffsetSeconds into the cycle (the boss runs on the hour, the arena on the half hour).
Config.CycleSeconds = 3600
Config.OffsetSeconds = 2400

Config.WarnSeconds = 20
Config.EruptSeconds = 30
Config.LavaSeconds = 70
Config.CoolSeconds = 30
Config.TotalSeconds = Config.WarnSeconds + Config.EruptSeconds + Config.LavaSeconds + Config.CoolSeconds

-- River: chunk i (1 at the waterfall, increasing downstream) turns to lava at RiverStart + (i - 1) * RiverFrontDelay and
-- back to water at RiverRevertAt + (i - 1) * RiverRevertDelay.
Config.RiverStart = 30
Config.RiverFrontDelay = 0.8 -- the front moves on quickly, but each chunk fades so slowly (below) that neighbours are never visibly different
Config.RiverRevertAt = 120
Config.RiverRevertDelay = 0.5
-- Each river chunk (and the waterfall) cross-fades between water and lava over these many seconds instead of snapping.
Config.RiverFadeIn = 8
Config.RiverFadeOut = 8

-- ===== Burning bridges =====
-- The two river bridges catch fire in the middle and burn outward to both ends, then grow back (ends first) after the event.
Config.BridgeNames = { "RiverBridge01", "RiverBridge02" }
Config.BridgeBurnStart = 38 -- seconds after the start when the middle catches fire
Config.BridgeBurnSeconds = 40 -- the fire takes this long to reach the ends
Config.BridgeRestoreAt = 118 -- the bridges start coming back
Config.BridgeRestoreSeconds = 22
Config.BridgeBand = 0.24 -- how much of the half-length is burning / charring at any moment (fraction)

local function smoothstep(a: number, b: number, x: number): number
    local q = math.clamp((x - a) / (b - a), 0, 1)
    return q * q * (3 - 2 * q)
end
Config.SmoothStep = smoothstep

-- 0 = whole bridge intact ... 1 = burnt to both ends. Rises while burning, holds, then falls as the bridge comes back.
function Config.BridgeLevel(t: number?): number
    if not t then
        return 0
    end
    local up = smoothstep(Config.BridgeBurnStart, Config.BridgeBurnStart + Config.BridgeBurnSeconds, t)
    local down = smoothstep(Config.BridgeRestoreAt, Config.BridgeRestoreAt + Config.BridgeRestoreSeconds, t)
    return up * (1 - down)
end

-- How burnt a piece is: q = 0 at the bridge's middle ... 1 at its ends. <= 0 untouched, 0..1 burning / charring, >= 1 gone.
function Config.BridgeBurnValue(level: number, q: number): number
    return (level * (1 + 1.3 * Config.BridgeBand) - q) / Config.BridgeBand
end

-- ===== Lava hazards for players =====
Config.LavaDps = 55 -- health per second while standing in lava (players have 100): about two seconds
Config.LavaKills = true -- lava ignores the health floor below; bridge fire and afterburn still respect it
Config.BridgeDps = 8 -- ... while standing on / beside a burning part of a bridge
Config.AfterburnDps = 3 -- ... while still on fire after leaving it
Config.BurnSeconds = 3.5 -- how long the fire lasts after the last contact
Config.BurnSpeedBoost = 1.35 -- the bonus: on fire = this much faster
Config.MinHealthFraction = 0.1 -- the fire never takes a player below this share of their health (set 0 to let it kill)

-- How much of a river chunk (1 at the waterfall ... 9) is lava at time t, 0..1: the same cross-fade the clients draw.
function Config.ChunkLavaLevel(index: number, t: number?): number
    if not t then
        return 0
    end
    local turn = Config.RiverStart + (index - 1) * Config.RiverFrontDelay
    local revert = Config.RiverRevertAt + (index - 1) * Config.RiverRevertDelay
    if t < turn then
        return 0
    elseif t < revert then
        return smoothstep(turn, turn + Config.RiverFadeIn, t)
    end
    return 1 - smoothstep(revert, revert + Config.RiverFadeOut, t)
end

function Config.NextScheduled(now: number): number
    return (math.floor((now - Config.OffsetSeconds) / Config.CycleSeconds) + 1) * Config.CycleSeconds
        + Config.OffsetSeconds
end

-- "Idle" outside the event, otherwise the phase name for t seconds after the start.
function Config.PhaseAt(t: number): string
    if t < 0 or t >= Config.TotalSeconds then
        return "Idle"
    elseif t < Config.WarnSeconds then
        return "Warning"
    elseif t < Config.WarnSeconds + Config.EruptSeconds then
        return "Erupting"
    elseif t < Config.WarnSeconds + Config.EruptSeconds + Config.LavaSeconds then
        return "Lava"
    end
    return "Cooling"
end

-- How strongly the world lighting is "volcano" at t seconds (0 normal ... 1 full eruption red).
function Config.Intensity(t: number): number
    local warn, erupt, lava = Config.WarnSeconds, Config.EruptSeconds, Config.LavaSeconds
    if t < 0 or t >= Config.TotalSeconds then
        return 0
    elseif t < warn then
        return 0.35 * (t / warn)
    elseif t < warn + erupt then
        return 0.35 + 0.65 * ((t - warn) / erupt)
    elseif t < warn + erupt + lava then
        return 1 - 0.15 * ((t - warn - erupt) / lava)
    end
    return 0.85 * (1 - (t - warn - erupt - lava) / Config.CoolSeconds)
end

return Config
