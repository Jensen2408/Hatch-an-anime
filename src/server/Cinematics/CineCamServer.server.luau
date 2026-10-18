-- Hatch An Anime CineCam: place in ServerScriptService as CineCamServer.
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
local open = ReplicatedStorage:FindFirstChild("CineCamOpen") or Instance.new("RemoteEvent")
open.Name = "CineCamOpen"
open.Parent = ReplicatedStorage

local function allowed(player)
    return player.UserId == OWNER_ID or (RunService:IsStudio() and player.UserId == 0)
end

local function validPoint(point)
    if type(point) ~= "table" or type(point.cf) ~= "table" or #point.cf ~= 12 then
        return false
    end
    for _, n in ipairs(point.cf) do
        if type(n) ~= "number" or n ~= n or math.abs(n) > 1000000 then
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

remote.OnServerInvoke = function(player, action, payload)
    if not allowed(player) then
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

local command = TextChatService:FindFirstChild("CineCamCommand") or Instance.new("TextChatCommand")
command.Name = "CineCamCommand"
command.PrimaryAlias = "/film"
command.Parent = TextChatService
command.Triggered:Connect(function(source)
    if not source then
        return
    end
    local player = Players:GetPlayerByUserId(source.UserId)
    if player and allowed(player) then
        open:FireClient(player)
    end
end)
