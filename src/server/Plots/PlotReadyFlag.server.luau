local Players = game:GetService("Players")
local function check(p)
	for _, pl in workspace:WaitForChild("Plots"):GetChildren() do
		if pl:GetAttribute("OwnerUserId") == p.UserId then p:SetAttribute("PlotReady", true) return true end
	end
end
Players.PlayerAdded:Connect(function(p) for _ = 1, 40 do if check(p) or not p.Parent then return end task.wait(0.25) end end)
