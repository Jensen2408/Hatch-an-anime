--[[ ServerScriptService.NighttimeService (ModuleScript, server only)
Night cycle, derived purely from server time so it needs no state: every 300 s (on a 300 s boundary of
workspace:GetServerTimeNow()) night is active for the first 20 s. Staff can force night via the workspace
attribute NightForcedUntil (server time; written by OwnerPanelServer).

Update(now) is called ~10x per second by NighttimeClock and publishes workspace attributes (server authority):
  NighttimeActive, NighttimeEndsAt, NighttimeNextAt   -> read by NighttimeHUD / NighttimeSky (clients)
  NightCashMultiplier (3 / 1), NightHatchSpeedMultiplier (2 / 1), NightRiverLuckMultiplier (3 / 1)
                                                       -> read by income, HatchGoo and river egg spawners
Returns whether night is active.
]]
local CYCLE_SECONDS = 300 -- a night starts every 5 minutes
local NIGHT_SECONDS = 20 -- and lasts 20 s

local Service = {}

function Service.Update(now)
    local cycleStart = math.floor(now / CYCLE_SECONDS) * CYCLE_SECONDS
    local active = now - cycleStart < NIGHT_SECONDS
    local endsAt = cycleStart + NIGHT_SECONDS
    -- Staff panel trigger: NightForcedUntil (server time) forces night on until then
    local forcedUntil = workspace:GetAttribute("NightForcedUntil")
    if forcedUntil and now < forcedUntil then
        active = true
        endsAt = math.max(forcedUntil, active and endsAt or 0)
    end
    workspace:SetAttribute("NighttimeActive", active)
    workspace:SetAttribute("NighttimeEndsAt", endsAt)
    workspace:SetAttribute("NighttimeNextAt", cycleStart + CYCLE_SECONDS)
    workspace:SetAttribute("NightCashMultiplier", active and 3 or 1)
    workspace:SetAttribute("NightHatchSpeedMultiplier", active and 2 or 1)
    workspace:SetAttribute("NightRiverLuckMultiplier", active and 3 or 1)
    return active
end

return Service
