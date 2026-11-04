--[[ ReplicatedStorage.BossEvent.BossConfig  (ModuleScript, shared)
River boss event: the Voxel Oni wades along the waterfall river carrying a rare egg on its back. Shared by
ServerScriptService.BossEventService (authority: HP, hits, reward) and StarterPlayerScripts.BossEventClient
(model, animation, HUD), so both derive the boss position from the same server-time clock (like the river eggs).

Timeline (t = seconds since workspace attribute BossEpoch):
  0 .. EMERGE_SECONDS            rises out of the water at the waterfall end of the path
  then, repeating every STEP_SECONDS: WALK_SECONDS of walking, then SLAM_SECONDS standing still for a ground slam
  the walk travels downstream once, then crawls into the outlet. The route determines BossEndsAt.
Pose(t) -> (cframe at the feet, phase "emerge" | "walk" | "slam", distance walked, slamTime or nil).
]]
local Config = {}

-- ===== Schedule and balance =====
Config.CycleSeconds = 3600 -- one boss per hour on every server...
Config.OffsetSeconds = 1800 -- ...at half past the hour (server time), so it rarely lands on a fresh join
Config.WarnSeconds = 60 -- "the river stirs" banner this long before a scheduled boss
Config.EventSeconds = 300 -- failsafe cap; normal escape is determined by the one-way route
Config.BaseHealth = 80
Config.HealthPerPlayer = 60 -- max HP = BaseHealth + HealthPerPlayer * players in the server at the start
Config.HitDamage = 3
Config.HitCooldown = 1.1 -- matches WoodenBat swing cooldown
Config.HitRange = 6.5 -- bat reach from the surface of the server-side boss bounds
Config.HitHalfSize = Vector3.new(13.5, 19, 8.5)
Config.HitArcCos = 0.25
Config.SlamRadius = 40 -- was 48; damage and launch are server-authoritative
Config.SlamDamage = 20
Config.SlamLaunchUp = 65
Config.SlamLaunchOut = 35
Config.SlamVerticalRange = 18
Config.StunSeconds = 1.5
-- Breaking the world (ServerScriptService.BossBreakables): props tagged "BossBreakable" (the river bridges) break when
-- this body box, centred on the boss's feet, touches them, and come back this long after the boss is gone.
Config.BreakHalfSize = Vector3.new(14, 20, 9)
Config.BreakRespawnSeconds = 6

-- ===== Reward (placeholder: a Rainbow God egg from UpdatePack_Mutations) =====
Config.RewardEggType = "God"
Config.RewardMutation = "Rainbow"
Config.RewardEggModel = "God_Rainbow_Egg"

-- ===== Motion =====
Config.EmergeSeconds = 4
Config.SinkSeconds = 3
Config.WalkSpeed = 7 -- studs per second
Config.WalkSeconds = 8
Config.SlamSeconds = 4.2
Config.SlamImpactAt = 3.0 -- seconds into the slam when the fists land; the red warning field shows from the first
-- second of the slam, so this is how long players have to run out of the circle (was 1.5 s)
Config.StepSeconds = Config.WalkSeconds + Config.SlamSeconds
Config.StrideStuds = 9 -- one full leg cycle per this many studs walked
Config.BedY = 22 -- top of WaterfallRiver.RiverBed
Config.CrawlSeconds = 8
Config.ExitPosition = Vector3.new(272, 22, 22.76) -- beyond the outlet at x=243
Config.CrawlDrop = 10 -- lower the tall carried shrine beneath the outlet roof

-- River centreline {x, z}, measured on the RiverBed (2026-11-02). Waterfall end first.
local POINTS = {
    { -248, 22.8 }, { -234, 24.2 }, { -220, 25.5 }, { -206, 25.2 }, { -192, 24.2 }, { -178, 23.8 }, { -164, 23.8 },
    { -150, 23.8 }, { -136, 24.5 }, { -122, 25.0 }, { -108, 23.8 }, { -94, 24.8 }, { -80, 24.8 }, { -66, 24.2 },
    { -52, 22.5 }, { -38, 21.2 }, { -24, 20.8 }, { -10, 18.5 }, { 4, 16.2 }, { 18, 13.8 }, { 32, 12.8 },
    { 46, 11.0 }, { 60, 10.5 }, { 74, 11.2 }, { 88, 11.0 }, { 102, 13.0 }, { 116, 13.5 }, { 130, 15.8 },
    { 144, 17.0 }, { 158, 20.2 }, { 172, 21.5 }, { 186, 21.0 }, { 200, 21.5 }, { 214, 23.5 }, { 226, 22.8 },
}
local path, cumulative = {}, { 0 }
for i, point in ipairs(POINTS) do
    path[i] = Vector3.new(point[1], Config.BedY, point[2])
    if i > 1 then
        cumulative[i] = cumulative[i - 1] + (path[i] - path[i - 1]).Magnitude
    end
end
Config.Path = path
Config.PathLength = cumulative[#cumulative]

-- Point and tangent at arc length s (0..PathLength).
local function sample(s)
    for i = 2, #path do
        if s <= cumulative[i] or i == #path then
            local segment = cumulative[i] - cumulative[i - 1]
            local alpha = math.clamp((s - cumulative[i - 1]) / segment, 0, 1)
            return path[i - 1]:Lerp(path[i], alpha), (path[i] - path[i - 1]).Unit
        end
    end
    return path[1], (path[2] - path[1]).Unit
end

-- One pass only: clamp instead of wrapping or reversing at the end.
function Config.AtDistance(distance)
    local position, tangent = sample(math.clamp(distance, 0, Config.PathLength))
    return CFrame.lookAt(position, position + tangent)
end

local movingSeconds = Config.PathLength / Config.WalkSpeed
local pauses = math.max(0, math.ceil(movingSeconds / Config.WalkSeconds) - 1)
Config.CrawlStartsAt = Config.EmergeSeconds + movingSeconds + pauses * Config.SlamSeconds
Config.RouteSeconds = Config.CrawlStartsAt + Config.CrawlSeconds

function Config.Pose(t)
    t = math.max(0, t)
    if t < Config.EmergeSeconds then
        return Config.AtDistance(0), "emerge", 0, nil
    end
    if t >= Config.CrawlStartsAt then
        local progress = math.clamp((t - Config.CrawlStartsAt) / Config.CrawlSeconds, 0, 1)
        local start = path[#path]
        local position = start:Lerp(Config.ExitPosition, progress)
        local direction = (Config.ExitPosition - start).Unit
        return CFrame.lookAt(position, position + direction), progress >= 1 and "exited" or "crawl",
            Config.PathLength + (position - start).Magnitude, progress
    end
    local walkTime = t - Config.EmergeSeconds
    local steps = math.floor(walkTime / Config.StepSeconds)
    local inStep = walkTime - steps * Config.StepSeconds
    local walked = steps * Config.WalkSeconds + math.min(inStep, Config.WalkSeconds)
    local distance = math.min(walked * Config.WalkSpeed, Config.PathLength)
    if inStep > Config.WalkSeconds then
        return Config.AtDistance(distance), "slam", distance, inStep - Config.WalkSeconds
    end
    return Config.AtDistance(distance), "walk", distance, nil
end

-- Server time of the next scheduled boss after `now`.
function Config.NextScheduled(now)
    return (math.floor((now - Config.OffsetSeconds) / Config.CycleSeconds) + 1) * Config.CycleSeconds
        + Config.OffsetSeconds
end

function Config.MaxHealth(playerCount)
    return Config.BaseHealth + Config.HealthPerPlayer * math.max(1, playerCount)
end

return Config

