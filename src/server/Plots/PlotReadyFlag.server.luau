--[[ PlotReadyFlag  (Script, server)
Sets Player.PlotReady = true once PlotManager has given the player a plot (OwnerUserId match).
Polls every 0.25 s for at most 40 tries (10 s) after the player joins. The client LoadingScreen.Config names
this attribute (PlotReadyAttribute), but no script currently reads it (docs/PROJECT_AUDIT.md: unused).
]]
local Players = game:GetService("Players")

-- Returns true (and sets the flag) if some plot is owned by this player; nil otherwise.
local function markIfPlotAssigned(player)
    for _, plot in workspace:WaitForChild("Plots"):GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            player:SetAttribute("PlotReady", true)
            return true
        end
    end
end

Players.PlayerAdded:Connect(function(player)
    for _ = 1, 40 do
        if markIfPlotAssigned(player) or not player.Parent then
            return
        end
        task.wait(0.25)
    end
end)
