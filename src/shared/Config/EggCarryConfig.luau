-- ReplicatedStorage.EggCarryConfig  (ModuleScript, shared)
-- Tuning for the "carry it home" phase (RiverEggCarryService): a bought river egg or a picked-up dropped egg.
local Config = {}

-- WalkSpeed while carrying an egg home = normal WalkSpeed * this (1 = no slowdown, 0.8 = 20% slower).
-- Restored as soon as the egg is secured, dropped or the carry is cancelled.
Config.CarryWalkSpeedMultiplier = 0.8

return Config
