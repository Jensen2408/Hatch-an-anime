-- Collect-all pad in front of each temple (Adam, Oct 16). Stand on your own plot's pad to
-- collect every MoneyStand you own at once. The label shows the total waiting.
local Players = game:GetService("Players")
local CS = game:GetService("CollectionService")

local function short(n)
	n = math.floor(n or 0)
	for _, u in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= u[1] then return (string.format("%.1f", n / u[1]):gsub("%.0$", "")) .. u[2] end
	end
	return tostring(n)
end

local function ownedStands(uid)
	local list = {}
	if uid == 0 then return list end
	for _, m in CS:GetTagged("MoneyStand") do
		if m:GetAttribute("OwnerUserId") == uid then table.insert(list, m) end
	end
	return list
end

local function inPad(pad, pos)
	local rel = pad.CFrame:PointToObjectSpace(pos)
	return math.abs(rel.X) <= pad.Size.X / 2 + 0.5 and math.abs(rel.Z) <= pad.Size.Z / 2 + 0.5 and rel.Y >= -0.5 and rel.Y <= 7
end

local last = {}
task.spawn(function()
	local tick = 0
	while true do
		task.wait(0.15)
		tick += 1
		for _, zone in CS:GetTagged("CollectAllZone") do
			local plot = zone.Parent
			local pad = zone:FindFirstChild("Pad")
			if not (plot and pad) then continue end
			local uid = plot:GetAttribute("OwnerUserId") or 0
			local stands = ownedStands(uid)
			local owner = uid ~= 0 and Players:GetPlayerByUserId(uid)
			local char = owner and owner.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hrp and hum and hum.Health > 0 and inPad(pad, hrp.Position) and os.clock() - (last[zone] or 0) >= 1 then
				local total = 0
				for _, m in stands do
					local v = m:GetAttribute("Stored") or 0
					if v > 0 then m:SetAttribute("Stored", 0) total += v end
				end
				if total > 0 then
					last[zone] = os.clock()
					local ls = owner:FindFirstChild("leaderstats")
					local cash = ls and ls:FindFirstChild("Cash")
					if cash then
						cash.Value += total
						pcall(function() require(game.ServerScriptService.GameMenu.QuestService).Increment(owner, "CollectIncome", 1) end)
						owner:SetAttribute("TutorialIncomeCollected", true)
						local remote = game.ReplicatedStorage:FindFirstChild("MoneyCollected")
						if remote and stands[1] then pcall(remote.FireClient, remote, owner, stands[1], total) end
					end
				end
			end
			if tick % 3 == 0 then
				local sum = 0
				for _, m in stands do sum += m:GetAttribute("Stored") or 0 end
				local tag = pad:FindFirstChild("CollectAllTag")
				if tag then
					tag.Enabled = uid ~= 0
					tag.Amount.Text = "$" .. short(sum)
				end
			end
		end
	end
end)
