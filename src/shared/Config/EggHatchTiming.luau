--[[ ReplicatedStorage.EggHatchTiming  (ModuleScript, shared)
Incubation time per egg type (seconds, by egg id: every character of an egg takes the same time) and the
countdown text format.
Read by PirateEggFreeConveyor (stamps attribute HatchSeconds) and HatchGoo.
]]
-- Not used below; the require is kept so load order stays exactly as before.
local _Economy = require(script.Parent.CharacterEconomy)
local Timing = {}
Timing.Base = {
    Pirate = 10,
    Shinobi = 15,
    Power = 20,
    Hero = 30,
    Slayer = 45,
    Curse = 60,
    Soul = 120,
    Titan = 180,
    Magic = 300,
    Academy = 600,
    Devil = 900,
    Guild = 1200,
    Sports = 1800,
    Mecha = 2700,
    God = 3600,
    Unknown = 600,
    Hunter = 4800, -- NEW.csv says 4 h; scaled like the other eggs (God: 3 h in the sheet, 1 h here)
    Alien = 7200, -- NEW.csv says 6 h
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
