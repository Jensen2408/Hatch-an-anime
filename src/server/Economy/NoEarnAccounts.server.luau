-- NoEarnAccounts: these accounts can never gain cash (stands, offline earnings, sales, gifts...). Spending still works.
-- The saved balance is restored normally on join; guarding starts once the save is fully loaded.
-- Turn off for one session: set the player attribute AllowEarnings = true (server side). Turn off completely: disable this script.
local Players = game:GetService("Players")
local NO_EARN = {
    [168774222] = true, -- Jen1sen (owner)
}

local function guard(p)
    if not NO_EARN[p.UserId] then
        return
    end
    -- wait until PlayerDataService has put the saved cash back
    local t = os.clock()
    while p.Parent and not p:GetAttribute("TutorialDataReady") and os.clock() - t < 90 do
        task.wait(0.5)
    end
    if not p.Parent then
        return
    end
    local ls = p:WaitForChild("leaderstats", 30)
    local cash = ls and ls:WaitForChild("Cash", 30)
    if not cash then
        return
    end
    local last = cash.Value
    local fixing = false
    cash.Changed:Connect(function(v)
        if fixing then
            return
        end
        if v > last and not p:GetAttribute("AllowEarnings") then
            fixing = true
            cash.Value = last
            fixing = false
        else
            last = v
        end
    end)
end

Players.PlayerAdded:Connect(guard)
for _, p in Players:GetPlayers() do
    task.spawn(guard, p)
end
