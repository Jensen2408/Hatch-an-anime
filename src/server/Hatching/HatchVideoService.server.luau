-- HatchVideoService (owners only): "hatching until I get a GOD" recording run.
-- Client sends "Start" -> server hatches a chain of eggs in incubator 1 instantly (no waiting),
-- each with the real hatch reveal, ending on the chosen top egg. Rewards are removed again afterwards.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local OWNERS = { [168774222] = true, [353101613] = true }
local CHAIN = { "Shinobi", "Hero", "Soul", "Devil", "God" }
local Catalog = require(RS:WaitForChild("CharacterCatalog"))
local remote = RS:FindFirstChild("HatchVideo") or Instance.new("RemoteEvent") remote.Name = "HatchVideo" remote.Parent = RS
local running = {}

local function plotOf(p) for _, pl in workspace.Plots:GetChildren() do if pl:GetAttribute("OwnerUserId") == p.UserId then return pl end end end
local function waitStatus(ch, want, timeout)
	local t = os.clock()
	while os.clock() - t < (timeout or 60) do
		if not ch.Parent then return false end
		local s = ch:GetAttribute("Status")
		if (type(want) == "table" and table.find(want, s)) or s == want then return true end
		task.wait(.1)
	end
	return false
end
local function makeEgg(id)
	local entry = Catalog.ById[id] local template = SS.AuxEggTemplates:FindFirstChild(id)
	if not entry or not template then return end
	local tool = Instance.new("Tool") tool.Name = id .. " Egg" tool.CanBeDropped = false
	Catalog.Stamp(tool, entry) tool:SetAttribute("EggType", id) tool:SetAttribute("OwnerSpawned", true) tool:SetAttribute("HatchVideo", true)
	local visual = template:Clone() visual.Name = "Egg" visual:ScaleTo(template:GetScale() * .5) visual:PivotTo(CFrame.new()) visual.Parent = tool
	local h = Instance.new("Part") h.Name = "Handle" h.Size = Vector3.one h.Transparency = 1 h.CanCollide = false h.Massless = true h.Parent = tool
	for _, p in visual:GetDescendants() do if p:IsA("BasePart") then p.Anchored = false p.CanCollide = false p.Massless = true
		local w = Instance.new("WeldConstraint") w.Part0 = h w.Part1 = p w.Parent = h elseif p:IsA("BaseScript") then p:Destroy() end end
	return tool
end

local function run(p, chain)
	local plot = plotOf(p) if not plot then remote:FireClient(p, "Error", "No temple") return end
	local ch = plot.Chambers:FindFirstChild("Chamber1") if not ch then return end
	local button = ch:FindFirstChild("HatchButton", true)
	local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") if not root then return end
	local bag = p:FindFirstChildOfClass("Backpack")
	-- park the (locally hidden) character right by the hatch button so all range checks pass
	local stand = (button and button:IsA("BasePart") and button.CFrame or ch:GetPivot()) * CFrame.new(0, 0, -6)
	local function park() if p.Character then p.Character:PivotTo(CFrame.new(stand.Position + Vector3.new(0, 3, 0))) end end
	local reward = bag and bag.ChildAdded:Connect(function(t) if t:IsA("Tool") and t:GetAttribute("Hatched") then task.defer(function() t:Destroy() end) end end)
	local cReward = p.Character and p.Character.ChildAdded:Connect(function(t) if t:IsA("Tool") and t:GetAttribute("Hatched") then task.defer(function() t:Destroy() end) end end)
	remote:FireClient(p, "Begin", ch)
	waitStatus(ch, "Ready", 30)
	for i, id in chain do
		if not running[p] or not p.Parent then break end
		park()
		local egg = makeEgg(id) if not egg then continue end
		egg.Parent = bag
		remote:FireClient(p, "Egg", i, #chain, id)
		ch.ResumeEgg:Invoke(p, egg, .6)
		if not waitStatus(ch, "Loaded", 20) then break end
		task.wait(.8)
		park() ch.RequestHatch:Fire(p)
		if not waitStatus(ch, "AwaitingPickup", 40) then break end
		task.wait(i == #chain and 5 or 1.6) -- hold longer on the final reveal
		local anchor = ch:FindFirstChild("EggPickupAnchor", true)
		park() if anchor and anchor:FindFirstChild("RequestPickup") then anchor.RequestPickup:Fire(p) end
		waitStatus(ch, "Ready", 15)
		task.wait(.4)
	end
	if reward then reward:Disconnect() end if cReward then cReward:Disconnect() end
	running[p] = nil
	remote:FireClient(p, "Done")
end

remote.OnServerEvent:Connect(function(p, action, list)
	if not OWNERS[p.UserId] then return end
	if action == "Start" and not running[p] then
		local chain = CHAIN
		if type(list) == "table" and #list > 0 and #list <= 10 then chain = {} for _, id in list do if type(id) == "string" and Catalog.ById[id] then table.insert(chain, id) end end end
		running[p] = true task.spawn(run, p, chain)
	elseif action == "Stop" then running[p] = nil end
end)
Players.PlayerRemoving:Connect(function(p) running[p] = nil end)
