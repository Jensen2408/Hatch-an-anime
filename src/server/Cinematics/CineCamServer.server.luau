--[[ ServerScriptService.CineCamServer  (Script)
Server side of CineCam (the owner-only trailer camera tool, see CineCamClient). Creates the remotes and the /film
chat command, and stores the owner's saved shots.

Remote contract (both created here in ReplicatedStorage, reused if they already exist; payload shapes are contracts)
  CineCamOpen   RemoteEvent, server -> client, no payload. Fired to the speaker when an allowed player types /film
                (TextChatCommand TextChatService.CineCamCommand).
  CineCamRemote RemoteFunction, client -> server: OnServerInvoke(player, action, payload)
    "load"          -> { ok = true, shots = { Shot } } | { ok = false, error = string }
                       Studio: the shots saved this session, else the library. Live: DataStore "CineCamShots_v1" key
                       "owner_" .. OWNER_ID, or the library when nothing is saved.
    "save", shots   -> { ok = true } | { ok = false, error = string }
                       Studio: kept in memory only (sessionShots). Live: SetAsync on the same key.
    other actions   -> { ok = false, error = "Unknown action" }

What the server validates (the client is never trusted)
  - isAllowed(player) on every invoke and on /film: UserId == OWNER_ID, or UserId 0 in Studio. Otherwise
    { ok = false, error = "Owner only" } and no CineCamOpen.
  - save: payload is a table with at most 25 array entries, and every entry passes validShot:
    name string of 1-40 bytes, duration 1-29, 2-40 points; each point has cf = 12 numbers (no NaN, |n| <= 1e6)
    and fov 20-100.
  - Library shots (ReplicatedStorage.CineCamShotLibrary StringValues, JSON) go through the same validShot.
]]
-- ===== 1. Services, constants and remotes =====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TextChatService = game:GetService("TextChatService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local OWNER_ID = 168774222 -- Matches the game's existing owner controls.
local store = DataStoreService:GetDataStore("CineCamShots_v1")
local sessionShots = nil
local remote = ReplicatedStorage:FindFirstChild("CineCamRemote") or Instance.new("RemoteFunction")
remote.Name = "CineCamRemote"
remote.Parent = ReplicatedStorage
local openEvent = ReplicatedStorage:FindFirstChild("CineCamOpen") or Instance.new("RemoteEvent")
openEvent.Name = "CineCamOpen"
openEvent.Parent = ReplicatedStorage

-- ===== 2. Validation =====
local function isAllowed(player)
    return player.UserId == OWNER_ID or (RunService:IsStudio() and player.UserId == 0)
end

-- n ~= n rejects NaN.
local function validPoint(point)
    if type(point) ~= "table" or type(point.cf) ~= "table" or #point.cf ~= 12 then
        return false
    end
    for _, component in ipairs(point.cf) do
        if type(component) ~= "number" or component ~= component or math.abs(component) > 1000000 then
            return false
        end
    end
    return type(point.fov) == "number" and point.fov >= 20 and point.fov <= 100
end

local function validShot(shot)
    if type(shot) ~= "table" or type(shot.name) ~= "string" or #shot.name < 1 or #shot.name > 40 then
        return false
    end
    if type(shot.duration) ~= "number" or shot.duration < 1 or shot.duration > 29 then
        return false
    end
    if type(shot.points) ~= "table" or #shot.points < 2 or #shot.points > 40 then
        return false
    end
    for _, point in ipairs(shot.points) do
        if not validPoint(point) then
            return false
        end
    end
    return true
end

-- ===== 3. Shot library (fallback when nothing is saved) =====
local function libraryShots()
    local result = {}
    local folder = ReplicatedStorage:FindFirstChild("CineCamShotLibrary")
    if not folder then
        return result
    end
    for _, item in ipairs(folder:GetChildren()) do
        if item:IsA("StringValue") then
            local ok, shot = pcall(HttpService.JSONDecode, HttpService, item.Value)
            if ok and validShot(shot) then
                table.insert(result, shot)
            end
        end
    end
    return result
end

-- ===== 4. Remote handler =====
remote.OnServerInvoke = function(player, action, payload)
    if not isAllowed(player) then
        return { ok = false, error = "Owner only" }
    end
    if action == "load" then
        if RunService:IsStudio() then
            return { ok = true, shots = sessionShots or libraryShots() }
        end
        local ok, result = pcall(function()
            return store:GetAsync("owner_" .. OWNER_ID)
        end)
        if not ok then
            return { ok = false, error = "Could not load saved shots: " .. tostring(result) }
        end
        return { ok = true, shots = type(result) == "table" and result or libraryShots() }
    elseif action == "save" then
        if type(payload) ~= "table" or #payload > 25 then
            return { ok = false, error = "Too many shots" }
        end
        for _, shot in ipairs(payload) do
            if not validShot(shot) then
                return { ok = false, error = "Invalid shot" }
            end
        end
        if RunService:IsStudio() then
            sessionShots = payload
            return { ok = true }
        end
        local ok, err = pcall(function()
            store:SetAsync("owner_" .. OWNER_ID, payload)
        end)
        if not ok then
            return { ok = false, error = "Could not save shots: " .. tostring(err) }
        end
        return { ok = true }
    end
    return { ok = false, error = "Unknown action" }
end

-- ===== 5. /film chat command =====
local command = TextChatService:FindFirstChild("CineCamCommand") or Instance.new("TextChatCommand")
command.Name = "CineCamCommand"
command.PrimaryAlias = "/film"
command.Parent = TextChatService
command.Triggered:Connect(function(source)
    if not source then
        return
    end
    local player = Players:GetPlayerByUserId(source.UserId)
    if player and isAllowed(player) then
        openEvent:FireClient(player)
    end
end)
