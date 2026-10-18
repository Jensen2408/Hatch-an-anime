local Catalog = require(game.ReplicatedStorage.CharacterCatalog)
local Scheduler = {}
local rarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local minimumAge = { Common = 0, Uncommon = 0, Rare = 24, Epic = 120, Legendary = 300 }
local cooldown = { Epic = 90, Legendary = 240 }
function Scheduler.new(templates, random)
    local buckets = {}
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
    local self = { count = 0, last = {}, buckets = buckets, random = random or Random.new() }
    function self:Next(age)
        self.count += 1
        if self.count <= 6 then
            return buckets.Common[((self.count - 1) % #buckets.Common) + 1]
        end
        local total = 0
        local eligible = {}
        for _, rarity in rarityOrder do
            local bucket = buckets[rarity]
            if
                bucket
                and #bucket > 0
                and age >= minimumAge[rarity]
                and (not cooldown[rarity] or age - (self.last[rarity] or -math.huge) >= cooldown[rarity])
            then
                local weight = Catalog.SpawnChances[rarity] or 0
                if rarity ~= "Common" then
                    weight *= workspace:GetAttribute("NightRiverLuckMultiplier") or 1
                end
                if weight > 0 then
                    total += weight
                    table.insert(eligible, { rarity = rarity, weight = weight, items = bucket })
                end
            end
        end
        local roll = self.random:NextNumber(0, total)
        local sum = 0
        for _, bucket in eligible do
            sum += bucket.weight
            if roll < sum then
                self.last[bucket.rarity] = age
                return bucket.items[self.random:NextInteger(1, #bucket.items)]
            end
        end
        return buckets.Common[1]
    end
    return self
end
return Scheduler
