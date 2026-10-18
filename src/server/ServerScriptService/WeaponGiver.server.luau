--[[
	WeaponGiver
	Gives players weapons from ServerStorage > Weapons each time they spawn.
	Add a weapon's name to STARTER_WEAPONS to hand it out.
]]

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local weaponsFolder = ServerStorage:WaitForChild("Weapons")

local STARTER_WEAPONS = {
	"WoodenBat",
	-- "IronSword",   -- add future weapons here
}

local function giveWeapons(player)
	local backpack = player:WaitForChild("Backpack")
	for _, weaponName in ipairs(STARTER_WEAPONS) do
		local template = weaponsFolder:FindFirstChild(weaponName)
		if template then
			template:Clone().Parent = backpack
		else
			warn("WeaponGiver: no weapon named '" .. weaponName .. "' in ServerStorage.Weapons")
		end
	end
end

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		giveWeapons(player)
	end)
	if player.Character then
		giveWeapons(player)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end
