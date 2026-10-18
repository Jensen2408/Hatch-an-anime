--[[ ServerScriptService.RiverEggSpawnScheduler  (ModuleScript, SERVER)
Weighted rarity picker for the river (PirateEggFreeConveyor).
Scheduler.new(templates, random?) -> scheduler; scheduler:Next(serverAgeSeconds) -> template
  - Templates are bucketed by CharacterCatalog rarity (ReleaseEnabled == false ones are skipped) and sorted by Order.
  - The first 6 spawns are always Common (round-robin) so a fresh server starts with affordable eggs.
  - After that: weights = CharacterCatalog.SpawnChances, non-Common weights x workspace "NightRiverLuckMultiplier".
  - A rarity is only eligible after RARITY_MIN_AGE seconds of server age and RARITY_COOLDOWN seconds since its last spawn.
]]
local Catalog = require(game.ReplicatedStorage.CharacterCatalog)

local Scheduler = {}

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local RARITY_MIN_AGE = { Common = 0, Uncommon = 0, Rare = 24, Epic = 120, Legendary = 300 } -- seconds of server age
local RARITY_COOLDOWN = { Epic = 90, Legendary = 240 } -- seconds between two spawns of this rarity

function Scheduler.new(templates, random)
    local buckets = {} -- [rarity] = { template, ... } sorted by catalog Order
    for _, template in templates do
        local entry = Catalog.ById[template.Name]
        if entry and template:GetAttribute("ReleaseEnabled") ~= false then
            buckets[entry.Rarity] = buckets[entry.Rarity] or {}
            table.insert(buckets[entry.Rarity], template)
        end
    end
    for _, bucket in buckets do
        table.sort(bucket, function(a, b)
            return Catalog.ById[a.Name].Order < Catalog.ById[b.Name].Order
        end)
    end
    assert(buckets.Common and #buckets.Common > 0, "Common egg templates required")
    -- count = spawns so far; last = [rarity] = server age of the last spawn of that rarity
    local scheduler = { count = 0, last = {}, buckets = buckets, random = random or Random.new() }
    function scheduler:Next(age)
        self.count += 1
        if self.count <= 6 then
            return buckets.Common[((self.count - 1) % #buckets.Common) + 1]
        end
        local totalWeight = 0
        local eligible = {}
        for _, rarity in RARITY_ORDER do
            local bucket = buckets[rarity]
            if
                bucket
                and #bucket > 0
                and age >= RARITY_MIN_AGE[rarity]
                and (not RARITY_COOLDOWN[rarity] or age - (self.last[rarity] or -math.huge) >= RARITY_COOLDOWN[rarity])
            then
                local weight = Catalog.SpawnChances[rarity] or 0
                if rarity ~= "Common" then
                    weight *= workspace:GetAttribute("NightRiverLuckMultiplier") or 1
                end
                if weight > 0 then
                    totalWeight += weight
                    table.insert(eligible, { rarity = rarity, weight = weight, items = bucket })
                end
            end
        end
        local roll = self.random:NextNumber(0, totalWeight)
        local cumulative = 0
        for _, candidate in eligible do
            cumulative += candidate.weight
            if roll < cumulative then
                self.last[candidate.rarity] = age
                return candidate.items[self.random:NextInteger(1, #candidate.items)]
            end
        end
        return buckets.Common[1]
    end
    return scheduler
end

return Scheduler
