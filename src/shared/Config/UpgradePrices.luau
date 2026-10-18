-- ReplicatedStorage.UpgradePrices  (ModuleScript, shared)
-- Cash prices for plot upgrades. Server charges these; the Plot menu shows them.
-- Tables are keyed by the level being bought (e.g. Temple[2] = price of floor 2).
local Prices = {}
Prices.Temple = { [2] = 50e9, [3] = 25e12 } -- temple floor 2 / 3 (also needs every slot unlocked)
Prices.AddIncubator = { [2] = 50e3, [3] = 5e6 } -- 2nd / 3rd incubator
Prices.IncubatorLevel = { [2] = 100e3, [3] = 10e6 } -- upgrade an incubator to level 2 / 3
-- Server only: takes `amount` from leaderstats.Cash. Returns true on success (also for a nil/0 price),
-- false if the player has no Cash stat or not enough.
function Prices.Charge(player, amount)
    if not amount or amount <= 0 then
        return true
    end
    local leaderstats = player:FindFirstChild("leaderstats")
    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
    if not cash or cash.Value < amount then
        return false
    end
    cash.Value -= amount
    return true
end
function Prices.CanAfford(player, amount)
    local leaderstats = player:FindFirstChild("leaderstats")
    local cash = leaderstats and leaderstats:FindFirstChild("Cash")
    return cash ~= nil and cash.Value >= (amount or 0)
end
return Prices
