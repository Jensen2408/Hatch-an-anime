-- NoEarnAccounts: these accounts can never gain cash (stands, offline earnings, sales, gifts...). Spending still works.
-- The saved balance is restored normally on join; guarding starts once the save is fully loaded.
-- Turn off for one session: set the player attribute AllowEarnings = true (server side). Turn off completely: disable this script.
-- Runtime: Script in ServerScriptService. Waits for PlayerDataService's TutorialDataReady attribute (max 90 s), then
-- reverts any increase of leaderstats.Cash.
local Players = game:GetService("Players")
local NO_EARN = {
    [168774222] = true, -- Jen1sen (owner)
}

local function guardCash(player)
    if not NO_EARN[player.UserId] then
        return
    end
    -- wait until PlayerDataService has put the saved cash back
    local startedAt = os.clock()
    while player.Parent and not player:GetAttribute("TutorialDataReady") and os.clock() - startedAt < 90 do
        task.wait(0.5)
    end
    if not player.Parent then
        return
    end
    local leaderstats = player:WaitForChild("leaderstats", 30)
    local cash = leaderstats and leaderstats:WaitForChild("Cash", 30)
    if not cash then
        return
    end
    local lastValue = cash.Value
    local isReverting = false -- ignores the Changed event fired by our own revert
    cash.Changed:Connect(function(newValue)
        if isReverting then
            return
        end
        if newValue > lastValue and not player:GetAttribute("AllowEarnings") then
            isReverting = true
            cash.Value = lastValue
            isReverting = false
        else
            lastValue = newValue
        end
    end)
end

Players.PlayerAdded:Connect(guardCash)
for _, player in Players:GetPlayers() do
    task.spawn(guardCash, player)
end
