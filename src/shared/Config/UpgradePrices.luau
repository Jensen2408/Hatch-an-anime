-- Cash prices for plot upgrades. Server charges these; the Plot menu shows them.
local P = {}
P.Temple = { [2] = 50e9, [3] = 25e12 } -- temple floor 2 / 3 (also needs every slot unlocked)
P.AddIncubator = { [2] = 50e3, [3] = 5e6 } -- 2nd / 3rd incubator
P.IncubatorLevel = { [2] = 100e3, [3] = 10e6 } -- upgrade an incubator to level 2 / 3
function P.Charge(player, amount)
    if not amount or amount <= 0 then
        return true
    end
    local ls = player:FindFirstChild("leaderstats")
    local cash = ls and ls:FindFirstChild("Cash")
    if not cash or cash.Value < amount then
        return false
    end
    cash.Value -= amount
    return true
end
function P.CanAfford(player, amount)
    local ls = player:FindFirstChild("leaderstats")
    local cash = ls and ls:FindFirstChild("Cash")
    return cash ~= nil and cash.Value >= (amount or 0)
end
return P
