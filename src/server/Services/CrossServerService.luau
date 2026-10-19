--!strict
--[[ ServerScriptService.CrossServerService  (ModuleScript, server only)
Universe-wide announcements and "game update" soft shutdowns over MessagingService topic "GameGlobalAnnouncements_v1".

Who is authorized: AnnounceUpdate / GlobalAnnounce require AdminRoles.Role(sender) (any staff; AnnounceUpdate also
accepts sender = nil for server-initiated calls). Callers: OwnerPanelServer (Announce with allServers, AnnounceUpdate)
and the /update, /announceupdate, /globalannounce, /gannounce chat commands below (staff only).
Trusted input
  - Staff text is filtered with TextService (PublicChat) before it is broadcast.
  - Messages from other servers (tables) are trusted as-is and forwarded to this server's clients; isUpdate == true
    starts the rejoin countdown here. Messages sent from outside (Open Cloud, a JSON string) are decoded and can never
    trigger a rejoin (isUpdate is cleared).
  - TeleportData.SoftShutdown on join (client-controlled) only bounces that player back to a public server.
Replicated output: ReplicatedStorage.OwnerPanel.Announcement (shared with OwnerPanelServer) gets every banner payload;
workspace attribute "ServerUpdating" = true while this server is shutting down (new joins are kicked).
PerformRejoin: 5 s countdown, PlayerDataSaveAll, then teleport everyone through a reserved "bounce" server
(TeleportData { SoftShutdown = true }) and kick whoever is left after 15 s.
]]

-- ===== 1. Services, topic and remote =====
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
local SERVER_ID = (game.JobId and #game.JobId > 0) and game.JobId or HttpService:GenerateGUID(false)

local folder = ReplicatedStorage:FindFirstChild("OwnerPanel") or Instance.new("Folder")
folder.Name = "OwnerPanel"
folder.Parent = ReplicatedStorage

local announceEvent = folder:FindFirstChild("Announcement") or Instance.new("RemoteEvent")
announceEvent.Name = "Announcement"
announceEvent.Parent = folder

-- ===== 2. Cross-server listener =====
-- Cross-server listener
local subOk, subErr = pcall(function()
    return MessagingService:SubscribeAsync(TOPIC, function(message)
        local data = message.Data
        if type(data) == "string" then -- sent from outside (Open Cloud / live announce page)
            local ok, decoded = pcall(HttpService.JSONDecode, HttpService, data)
            data = ok and type(decoded) == "table" and decoded or nil
            if data then
                data.isUpdate = nil
            end -- outside messages can never trigger a rejoin
        end
        if type(data) == "table" then
            -- Avoid duplicating banner on the originating server
            if data.ServerId == SERVER_ID then
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

-- ===== 3. Public API =====
-- Raw publish (no permission check: server code only). Stamps SERVER_ID so this server ignores its own echo.
function CrossServerService.Broadcast(payload: { [string]: any })
    payload.ServerId = SERVER_ID
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
                return TextService:FilterStringAsync(raw, sender.UserId, Enum.TextFilterContext.PublicChat)
                    :GetNonChatStringForBroadcastAsync()
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
        ServerId = SERVER_ID,
    }

    -- 1. Display immediately in this server
    announceEvent:FireAllClients(payload)

    -- 2. Broadcast across all servers
    local pubOk, _pubErr = pcall(function()
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
        return TextService:FilterStringAsync(raw, sender.UserId, Enum.TextFilterContext.PublicChat)
            :GetNonChatStringForBroadcastAsync()
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
        ServerId = SERVER_ID,
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

-- ===== 4. Chat commands (staff only) =====
-- Chat Commands: /update, /announceupdate, /globalannounce
local updateCommand = TextChatService:FindFirstChild("AnnounceUpdateCommand") or Instance.new("TextChatCommand")
updateCommand.Name = "AnnounceUpdateCommand"
updateCommand.PrimaryAlias = "/update"
updateCommand.SecondaryAlias = "/announceupdate"
updateCommand.Parent = TextChatService

updateCommand.Triggered:Connect(function(source, text)
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

local globalCommand = TextChatService:FindFirstChild("GlobalAnnounceCommand") or Instance.new("TextChatCommand")
globalCommand.Name = "GlobalAnnounceCommand"
globalCommand.PrimaryAlias = "/globalannounce"
globalCommand.SecondaryAlias = "/gannounce"
globalCommand.Parent = TextChatService

globalCommand.Triggered:Connect(function(source, text)
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

-- ===== 5. Soft shutdown =====
-- Runs at most once per server (ServerUpdating gate; reset only in Studio or when the server is empty).
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
            ServerId = SERVER_ID,
        })
        task.wait(1)
    end

    local players = Players:GetPlayers()
    if #players == 0 then
        workspace:SetAttribute("ServerUpdating", false)
        return
    end

    if RunService:IsStudio() then
        warn(
            "[Update] Studio test: Rejoin sequence completed. In live game, all "
                .. #players
                .. " players would now be teleported."
        )
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
    local saveAllFunction = game.ServerStorage:FindFirstChild("PlayerDataSaveAll")
    if saveAllFunction then
        pcall(saveAllFunction.Invoke, saveAllFunction)
    end

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
            for _, player in ipairs(players) do
                pcall(TeleportService.Teleport, TeleportService, game.PlaceId, player)
            end
        end
    else
        for _, player in ipairs(players) do
            pcall(TeleportService.Teleport, TeleportService, game.PlaceId, player)
        end
    end

    -- Safeguard: kick remaining players after 15 seconds
    task.delay(15, function()
        for _, player in ipairs(Players:GetPlayers()) do
            player:Kick("Game updated! Please rejoin to load the newest version.")
        end
    end)
end

-- ===== 6. Join handling =====
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
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end

return CrossServerService
