--!strict
-- CrossServerService: Handles universe-wide announcements and update notifications using MessagingService.

local MessagingService = game:GetService("MessagingService")
local TeleportService = game:GetService("TeleportService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")

local AdminRoles = require(script.Parent:WaitForChild("AdminRoles"))

local CrossServerService = {}

local TOPIC = "GameGlobalAnnouncements_v1"
local serverId = (game.JobId and #game.JobId > 0) and game.JobId or HttpService:GenerateGUID(false)

local folder = ReplicatedStorage:FindFirstChild("OwnerPanel") or Instance.new("Folder")
folder.Name = "OwnerPanel"
folder.Parent = ReplicatedStorage

local announceEvent = folder:FindFirstChild("Announcement") or Instance.new("RemoteEvent")
announceEvent.Name = "Announcement"
announceEvent.Parent = folder

-- Cross-server listener
local subOk, subErr = pcall(function()
	return MessagingService:SubscribeAsync(TOPIC, function(message)
		local data = message.Data
		if type(data) == "string" then -- sent from outside (Open Cloud / live announce page)
			local ok, decoded = pcall(HttpService.JSONDecode, HttpService, data)
			data = ok and type(decoded) == "table" and decoded or nil
			if data then data.isUpdate = nil end -- outside messages can never trigger a rejoin
		end
		if type(data) == "table" then
			-- Avoid duplicating banner on the originating server
			if data.ServerId == serverId then
				return
			end
			announceEvent:FireAllClients(data)
			if data.isUpdate == true then
				task.spawn(function()
					CrossServerService.PerformRejoin()
				end)
			end
		end
	end)
end)

if not subOk then
	warn("[CrossServerService] MessagingService subscribe unavailable:", subErr)
end

function CrossServerService.Broadcast(payload: { [string]: any })
	payload.ServerId = serverId
	local ok, err = pcall(function()
		MessagingService:PublishAsync(TOPIC, payload)
	end)
	return ok, err
end

function CrossServerService.AnnounceUpdate(sender: Player?, customMessage: string?): (boolean, string)
	if sender and not AdminRoles.Role(sender) then
		return false, "Staff access only."
	end

	local text = "A new update has been released! Rejoin to get the latest features!"
	if customMessage and #customMessage:gsub("%s", "") > 0 then
		local raw = customMessage:sub(1, 140)
		if sender then
			local ok, filtered = pcall(function()
				return TextService:FilterStringAsync(raw, sender.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
			end)
			if ok and filtered then
				text = filtered
			else
				return false, "Could not filter the update message. Please try again."
			end
		else
			text = raw
		end
	end

	local payload = {
		title = "🚨 GAME UPDATE!",
		text = text,
		color = "gold",
		by = sender and sender.DisplayName or "Server",
		isUpdate = true,
		ServerId = serverId,
	}

	-- 1. Display immediately in this server
	announceEvent:FireAllClients(payload)

	-- 2. Broadcast across all servers
	local pubOk, pubErr = pcall(function()
		MessagingService:PublishAsync(TOPIC, payload)
	end)

	-- 3. Trigger rejoin countdown on this server
	task.spawn(function()
		CrossServerService.PerformRejoin()
	end)

	if pubOk then
		return true, "Update announced across ALL servers!"
	else
		return true, "Update announced in this server (cross-server requires live published game)."
	end
end

function CrossServerService.GlobalAnnounce(sender: Player, message: string, color: string?): (boolean, string)
	if not AdminRoles.Role(sender) then
		return false, "Staff access only."
	end

	local raw = type(message) == "string" and message:sub(1, 140) or ""
	if #raw:gsub("%s", "") == 0 then
		return false, "Please write a message first."
	end

	local ok, filtered = pcall(function()
		return TextService:FilterStringAsync(raw, sender.UserId, Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync()
	end)
	if not ok or not filtered then
		return false, "Could not filter announcement message."
	end

	local role = AdminRoles.Role(sender)
	local payload = {
		title = (role == "Owner" and "GLOBAL OWNER" or "GLOBAL ADMIN") .. " ANNOUNCEMENT",
		text = filtered,
		color = color or "purple",
		by = sender.DisplayName,
		byId = sender.UserId,
		style = "chat",
		ServerId = serverId,
	}

	announceEvent:FireAllClients(payload)

	local pubOk, _ = pcall(function()
		MessagingService:PublishAsync(TOPIC, payload)
	end)

	if pubOk then
		return true, "Global announcement sent across ALL servers!"
	else
		return true, "Announcement sent in this server (cross-server requires live published game)."
	end
end

-- Chat Commands: /update, /announceupdate, /globalannounce
local updateCmd = TextChatService:FindFirstChild("AnnounceUpdateCommand") or Instance.new("TextChatCommand")
updateCmd.Name = "AnnounceUpdateCommand"
updateCmd.PrimaryAlias = "/update"
updateCmd.SecondaryAlias = "/announceupdate"
updateCmd.Parent = TextChatService

updateCmd.Triggered:Connect(function(source, text)
	local who = source and Players:GetPlayerByUserId(source.UserId)
	if who and AdminRoles.Role(who) then
		local custom = nil
		if type(text) == "string" then
			local stripped = text:gsub("^/[%w_]+%s*", "")
			if #stripped > 0 then
				custom = stripped
			end
		end
		CrossServerService.AnnounceUpdate(who, custom)
	end
end)

local globalCmd = TextChatService:FindFirstChild("GlobalAnnounceCommand") or Instance.new("TextChatCommand")
globalCmd.Name = "GlobalAnnounceCommand"
globalCmd.PrimaryAlias = "/globalannounce"
globalCmd.SecondaryAlias = "/gannounce"
globalCmd.Parent = TextChatService

globalCmd.Triggered:Connect(function(source, text)
	local who = source and Players:GetPlayerByUserId(source.UserId)
	if who and AdminRoles.Role(who) then
		local msg = ""
		if type(text) == "string" then
			msg = text:gsub("^/[%w_]+%s*", "")
		end
		if #msg > 0 then
			CrossServerService.GlobalAnnounce(who, msg, "purple")
		end
	end
end)

function CrossServerService.PerformRejoin()
	if workspace:GetAttribute("ServerUpdating") == true then
		return
	end
	workspace:SetAttribute("ServerUpdating", true)

	-- 5-second countdown on screen
	for i = 5, 1, -1 do
		announceEvent:FireAllClients({
			title = "🚨 GAME UPDATE!",
			text = "Rejoining updated server in " .. i .. "s...",
			color = "gold",
			by = "Server",
			isUpdate = true,
			ServerId = serverId,
		})
		task.wait(1)
	end

	local players = Players:GetPlayers()
	if #players == 0 then
		workspace:SetAttribute("ServerUpdating", false)
		return
	end

	if RunService:IsStudio() then
		warn("[Update] Studio test: Rejoin sequence completed. In live game, all " .. #players .. " players would now be teleported.")
		announceEvent:FireAllClients({
			title = "🚨 UPDATE TEST",
			text = "Studio test complete: Live players would reconnect now.",
			color = "green",
			by = "Server",
		})
		task.wait(3)
		workspace:SetAttribute("ServerUpdating", false)
		return
	end

	-- save everyone and release their save lock BEFORE they leave (stops wipes on rejoin)
	local sa = game.ServerStorage:FindFirstChild("PlayerDataSaveAll")
	if sa then pcall(sa.Invoke, sa) end

	-- Create bounce pad reserved server
	local ok, code = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)

	if ok and code then
		local tpOptions = Instance.new("TeleportOptions")
		tpOptions.ReservedServerAccessCode = code
		tpOptions:SetTeleportData({ SoftShutdown = true })
		local tpOk, tpErr = pcall(function()
			TeleportService:TeleportAsync(game.PlaceId, players, tpOptions)
		end)
		if not tpOk then
			warn("[Update] TeleportAsync failed:", tpErr)
			for _, p in ipairs(players) do
				pcall(TeleportService.Teleport, TeleportService, game.PlaceId, p)
			end
		end
	else
		for _, p in ipairs(players) do
			pcall(TeleportService.Teleport, TeleportService, game.PlaceId, p)
		end
	end

	-- Safeguard: kick remaining players after 15 seconds
	task.delay(15, function()
		for _, p in ipairs(Players:GetPlayers()) do
			p:Kick("Game updated! Please rejoin to load the newest version.")
		end
	end)
end

-- Rejoin listeners: soft shutdown bounce handler and updating server gate
local function onPlayerAdded(player: Player)
	if workspace:GetAttribute("ServerUpdating") == true then
		player:Kick("Server is restarting for a game update. Please rejoin in a moment!")
		return
	end

	local joinData = player:GetJoinData()
	local tpData = joinData and joinData.TeleportData
	if type(tpData) == "table" and tpData.SoftShutdown == true then
		task.delay(1, function()
			if player and player.Parent then
				pcall(function()
					TeleportService:Teleport(game.PlaceId, player)
				end)
			end
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayerAdded(p)
end

return CrossServerService
