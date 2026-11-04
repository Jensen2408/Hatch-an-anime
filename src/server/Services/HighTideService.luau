--[[ ServerScriptService.HighTideService (ModuleScript, server only)
High tide event on the waterfall river, derived from server time like NighttimeService: every CYCLE_SECONDS (offset
by OFFSET_SECONDS so it rarely lands on night) the tide is high for TIDE_SECONDS. Staff can force one with the
workspace attributes HighTideForcedAt / HighTideForcedUntil (server time; written by OwnerPanelServer).

Update(now) is called ~10x per second by the RiverWater server script and publishes (server authority):
  HighTideStartedAt, HighTideEndsAt  the current or most recent window -> ReplicatedStorage.WaterfallRiver.RiverWaves
                                     turns these into the water level and surge waves (renderer and eggs)
  HighTideActive, HighTideNextAt     for HUDs
Returns (active, startedNow): startedNow is true on the first update of a scheduled (not staff-forced) tide.
]]
local CYCLE_SECONDS = 420 -- a high tide every 7 minutes
local OFFSET_SECONDS = 150
local TIDE_SECONDS = 50 -- including the rise and the fall (RiverWaves.TideRiseTime / TideFallTime)

local Service = {}
Service.CycleSeconds = CYCLE_SECONDS
Service.TideSeconds = TIDE_SECONDS

local announcedStart -- the scheduled window already announced
local firstUpdate = true

local function publish(name, value)
    if workspace:GetAttribute(name) ~= value then
        workspace:SetAttribute(name, value)
    end
end

function Service.Update(now)
    local cycleStart = math.floor((now - OFFSET_SECONDS) / CYCLE_SECONDS) * CYCLE_SECONDS + OFFSET_SECONDS
    local startAt, endsAt = cycleStart, cycleStart + TIDE_SECONDS
    local forced = false
    -- A staff tide wins while it is newer than the scheduled window.
    local forcedAt, forcedUntil = workspace:GetAttribute("HighTideForcedAt"), workspace:GetAttribute("HighTideForcedUntil")
    if forcedAt and forcedUntil and forcedAt >= startAt then
        startAt, endsAt, forced = forcedAt, forcedUntil, true
    end
    local active = now >= startAt and now < endsAt
    publish("HighTideStartedAt", startAt)
    publish("HighTideEndsAt", endsAt)
    publish("HighTideActive", active)
    publish("HighTideNextAt", cycleStart + CYCLE_SECONDS)
    local startedNow = false
    if active and not forced and announcedStart ~= startAt then
        -- A tide already running when the server started is not announced.
        startedNow = not firstUpdate
        announcedStart = startAt
    end
    firstUpdate = false
    return active, startedNow
end

-- Staff trigger: a tide lasting `seconds` from now. Stop() lets the current forced tide recede.
function Service.Force(now, seconds)
    workspace:SetAttribute("HighTideForcedAt", now)
    workspace:SetAttribute("HighTideForcedUntil", now + seconds)
end

function Service.Stop(now, fallSeconds)
    local forcedUntil = workspace:GetAttribute("HighTideForcedUntil")
    if forcedUntil and forcedUntil > now + fallSeconds then
        workspace:SetAttribute("HighTideForcedUntil", now + fallSeconds)
    end
end

return Service
