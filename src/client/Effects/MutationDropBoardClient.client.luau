local board = workspace:WaitForChild("MutationDropBoard"):WaitForChild("Board"):WaitForChild("Screen")
local timer = board:FindFirstChild("Timer", true) local tiers = board:FindFirstChild("Tiers", true)
local COL = { Silver = Color3.fromRGB(220,225,235), Gold = Color3.fromRGB(255,200,60), Diamond = Color3.fromRGB(90,220,255), Rainbow = Color3.fromRGB(255,90,200) }
while true do
	local now = workspace:GetServerTimeNow()
	local last, lastAt = workspace:GetAttribute("LastMutationDrop"), workspace:GetAttribute("LastMutationDropAt")
	if last and lastAt and now - lastAt < 20 then
		timer.Text = string.upper(last) .. " DROPPED!" timer.TextColor3 = COL[last] or Color3.new(1,1,1)
		tiers.Text = "GO GRAB IT IN THE RIVER!"
	else
		local left = math.max(0, math.ceil((workspace:GetAttribute("NextMutationDropAt") or now) - now))
		timer.Text = string.format("%d:%02d", left // 60, left % 60)
		timer.TextColor3 = left <= 10 and Color3.fromRGB(255,70,70) or Color3.fromRGB(255,220,80)
		tiers.Text = "SILVER · GOLD · DIAMOND · RAINBOW"
	end
	task.wait(.25)
end
