-- KeepItemsOnRespawn: eggs and characters (Tools with EggType / CharacterId / BrainrotId) survive dying and respawning.
-- Roblox clears the Backpack and destroys the held Tool on respawn, so a player who died lost every egg they carried.
-- On death they're parked in Player.RespawnHold, then put back in the new Backpack.
-- PlayerDataService saves from Backpack/Character/IncubatorHeldEggs; RespawnHold only exists for the few seconds of a respawn.
local Players = game:GetService("Players")

local function keep(t)
	return t:IsA("Tool") and (t:GetAttribute("EggType") ~= nil or t:GetAttribute("CharacterId") ~= nil or t:GetAttribute("BrainrotId") ~= nil)
		and not t:GetAttribute("Incubating")
end

local deadBag = setmetatable({}, { __mode = "k" }) -- [player] = the Backpack Roblox is about to replace

local function park(p, char)
	deadBag[p] = p:FindFirstChildOfClass("Backpack")
	local hold = p:FindFirstChild("RespawnHold") or Instance.new("Folder")
	hold.Name = "RespawnHold" hold.Parent = p
	for _, c in { p:FindFirstChildOfClass("Backpack"), char } do
		if c then for _, t in c:GetChildren() do if keep(t) then t.Parent = hold end end end
	end
end

local function restore(p)
	local hold = p:FindFirstChild("RespawnHold") if not hold then return end
	-- Roblox swaps in a fresh Backpack around CharacterAdded; putting items in the old one loses them
	local bag, t0 = nil, os.clock()
	repeat
		task.wait(0.1)
		bag = p:FindFirstChildOfClass("Backpack")
	until (bag and bag ~= deadBag[p] and bag.Parent == p) or os.clock() - t0 > 10 or not p.Parent
	if not bag or bag == deadBag[p] or not p.Parent then return end
	deadBag[p] = nil
	for _, t in hold:GetChildren() do
		t.Enabled = true t:SetAttribute("ReturningToBase", nil)
		t.Parent = bag
	end
	hold:Destroy()
end

local function watch(p)
	local function onChar(char)
		task.defer(restore, p)
		local hum = char:WaitForChild("Humanoid", 10)
		if hum then hum.Died:Connect(function() park(p, char) end) end
	end
	p.CharacterAdded:Connect(onChar)
	if p.Character then onChar(p.Character) end
end

Players.PlayerAdded:Connect(watch)
for _, p in Players:GetPlayers() do task.spawn(watch, p) end
