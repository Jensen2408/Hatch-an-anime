--!strict
-- StaffServerService: Manages reserved server access for Admins and Owner.
-- Cross-server sync via MemoryStoreService ensures all staff join the same reserved instance.

local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local AdminRoles = require(script.Parent:WaitForChild("AdminRoles"))

local StaffServerService = {}

-- Determine if current server is a reserved staff server
local function checkStaffServer(player: Player)
	local joinData = player:GetJoinData()
	local tpData = joinData and joinData.TeleportData
	if type(tpData) == "table" and tpData.isStaffServer == true then
		workspace:SetAttribute("IsStaffServer", true)
	end
end
Players.PlayerAdded:Connect(checkStaffServer)
for _, p in ipairs(Players:GetPlayers()) do
	checkStaffServer(p)
end

if workspace:GetAttribute("StudioStaffServer") == true then
	workspace:SetAttribute("IsStaffServer", true)
end

-- MemoryStore with DataStore fallback
local memoryStore = nil
pcall(function()
	memoryStore = MemoryStoreService:GetSortedMap("StaffServerCode_v2")
end)

local backupStore = nil
pcall(function()
	backupStore = DataStoreService:GetDataStore("StaffServerBackup_v1")
end)

function StaffServerService.GetOrCreateStaffServerCode(): (string?, string?)
	if RunService:IsStudio() then
		return nil, "Teleportation only works in the live published game."
	end

	-- 1. Try MemoryStore
	if memoryStore then
		local ok, code = pcall(function()
			return memoryStore:GetAsync("active_code")
		end)
		if ok and type(code) == "string" and #code > 0 then
			return code, nil
		end
	end

	-- 2. Try DataStore fallback
	if backupStore then
		local ok, data = pcall(function()
			return backupStore:GetAsync("active_code")
		end)
		if ok and type(data) == "table" and data.code and (os.time() - (data.created or 0) < 14400) then
			if memoryStore then
				pcall(function()
					memoryStore:SetAsync("active_code", data.code, 14400 - (os.time() - data.created))
				end)
			end
			return data.code, nil
		end
	end

	-- 3. Reserve a new private server code
	local ok, newCode = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)

	if not ok or not newCode then
		return nil, "Roblox TeleportService failed to reserve a server."
	end

	-- Save for 4 hours (14,400 seconds)
	if memoryStore then
		pcall(function()
			memoryStore:SetAsync("active_code", newCode, 14400)
		end)
	end
	if backupStore then
		pcall(function()
			backupStore:SetAsync("active_code", { code = newCode, created = os.time() })
		end)
	end

	return newCode, nil
end

function StaffServerService.TeleportToStaffServer(player: Player): (boolean, string)
	if not AdminRoles.Role(player) then
		return false, "Staff access only."
	end

	if RunService:IsStudio() then
		return false, "Staff server teleport only works in the live published game."
	end

	if workspace:GetAttribute("IsStaffServer") == true then
		return false, "You are already in the Staff Server."
	end

	local code, err = StaffServerService.GetOrCreateStaffServerCode()
	if not code then
		return false, err or "Could not retrieve staff server code."
	end

	local ok, tpErr = pcall(function()
		local tpOptions = Instance.new("TeleportOptions")
		tpOptions.ReservedServerAccessCode = code
		tpOptions:SetTeleportData({ isStaffServer = true })
		TeleportService:TeleportAsync(game.PlaceId, { player }, tpOptions)
	end)

	if not ok then
		return false, "Teleport error: " .. tostring(tpErr)
	end

	return true, "Teleporting to Staff Server..."
end

function StaffServerService.ReturnToPublic(player: Player): (boolean, string)
	if not AdminRoles.Role(player) then
		return false, "Staff access only."
	end

	if RunService:IsStudio() then
		return false, "Teleportation only works in the live published game."
	end

	local ok, tpErr = pcall(function()
		TeleportService:Teleport(game.PlaceId, player)
	end)

	if not ok then
		return false, "Teleport error: " .. tostring(tpErr)
	end

	return true, "Returning to public server..."
end

-- Security guard: if this server is a reserved staff server, kick any non-staff
local function guardPlayer(player: Player)
	local joinData = player:GetJoinData()
	local tpData = joinData and joinData.TeleportData
	if type(tpData) == "table" and tpData.SoftShutdown == true then
		return
	end
	if workspace:GetAttribute("IsStaffServer") == true then
		task.delay(0.5, function()
			if player and player.Parent and not AdminRoles.Role(player) then
				player:Kick("This server is reserved for Staff (Admins and Owner) only.")
			end
		end)
	end
end

Players.PlayerAdded:Connect(guardPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	guardPlayer(p)
end

-- Register /staffserver and /staff chat commands
local command = TextChatService:FindFirstChild("StaffServerCommand") or Instance.new("TextChatCommand")
command.Name = "StaffServerCommand"
command.PrimaryAlias = "/staffserver"
command.SecondaryAlias = "/staff"
command.Parent = TextChatService

command.Triggered:Connect(function(source)
	local who = source and Players:GetPlayerByUserId(source.UserId)
	if who and AdminRoles.Role(who) then
		StaffServerService.TeleportToStaffServer(who)
	end
end)

return StaffServerService
