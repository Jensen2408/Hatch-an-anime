--[[ ReplicatedStorage.EggHatchTiming  (ModuleScript, shared)
Incubation time per egg type (seconds) and the countdown text format.
Read by PirateEggFreeConveyor (stamps attribute HatchSeconds) and HatchGoo.
]]
-- Not used below; the require is kept so load order stays exactly as before.
local _Economy = require(script.Parent.CharacterEconomy)
local Timing = {}
Timing.Base = {
    Pirate = 30,
    Shinobi = 60,
    Power = 90,
    Hero = 180,
    Slayer = 300,
    Curse = 480,
    Soul = 720,
    Titan = 900,
    Magic = 1200,
    Academy = 1800,
    Devil = 2700,
    Guild = 3600,
    Sports = 5400,
    Mecha = 7200,
    God = 10800,
    Unknown = 1800,
}
-- Every egg of a given type has the same base incubation time.
-- Power rolls do not change the timer; Nighttime speeds up the countdown.
-- `_stats` (the rolled stats) is accepted for API compatibility but ignored. Unlisted ids get 120 s.
function Timing.Seconds(id, _stats)
    return Timing.Base[id] or 120
end
-- Incubator upgrade level -> hatch speed multiplier (stacks with the night / player multipliers).
Timing.LevelSpeeds = { 1, 1.5, 2 }
function Timing.LevelSpeed(level)
    return Timing.LevelSpeeds[tonumber(level) or 1] or 1
end
-- 3725 -> "1:02:05", 125 -> "02:05". Rounds up so the countdown never shows 00:00 early.
function Timing.Format(seconds)
    seconds = math.max(0, math.ceil(seconds))
    local hours = math.floor(seconds / 3600)
    local minutes = math.floor(seconds / 60) % 60
    local secs = seconds % 60
    if hours > 0 then
        return string.format("%d:%02d:%02d", hours, minutes, secs)
    end
    return string.format("%02d:%02d", minutes, secs)
end
return Timing
