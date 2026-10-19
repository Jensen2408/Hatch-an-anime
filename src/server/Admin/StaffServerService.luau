--!strict
--[[ ServerScriptService.StaffServerService  (ModuleScript, server only)
Reserved "staff server": one private server shared by all staff. The access code is cached for 4 hours in MemoryStore
sorted map "StaffServerCode_v2" (key "active_code"), with DataStore "StaffServerBackup_v1" ({ code, created }) as a
fallback, so every staff member who joins ends up in the same instance.

Who is authorized: any AdminRoles role (Owner or Admin). TeleportToStaffServer / ReturnToPublic check
AdminRoles.Role(player) themselves; callers are OwnerPanelServer (JoinStaffServer / ReturnToPublic actions, which also
pass AdminRoles.Can) and the /staffserver, /staff chat command below.

Trusted input / known issue: the server marks itself as a staff server (workspace attribute "IsStaffServer") when ANY
joining player's TeleportData has isStaffServer == true. TeleportData is client-controlled, so a non-staff player can
mark a public server as staff-only and every non-staff player who joins afterwards is kicked. guardPlayer also skips
anyone whose TeleportData has SoftShutdown == true, which is equally client-controlled.
See docs/PROJECT_AUDIT.md ("StaffServer TeleportData trust"); not fixed here (behaviour-preserving refactor).
Studio: workspace attribute StudioStaffServer = true simulates a staff server; teleports are refused in Studio.
]]

-- ===== 1. Services and dependencies =====
local TeleportService = game:GetService("TeleportService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local AdminRoles = require(script.Parent:WaitForChild("AdminRoles"))

local StaffServerService = {}

-- ===== 2. Staff-server detection (trusts TeleportData, see header) =====
-- Determine if current server is a reserved staff server
local function checkStaffServer(player: Player)
    local joinData = player:GetJoinData()
    local tpData = joinData and joinData.TeleportData
    if type(tpData) == "table" and tpData.isStaffServer == true then
        workspace:SetAttribute("IsStaffServer", true)
    end
end
Players.PlayerAdded:Connect(checkStaffServer)
for _, player in ipairs(Players:GetPlayers()) do
    checkStaffServer(player)
end

if workspace:GetAttribute("StudioStaffServer") == true then
    workspace:SetAttribute("IsStaffServer", true)
end

-- ===== 3. Shared access-code storage =====
-- MemoryStore with DataStore fallback
local memoryStore = nil
pcall(function()
    memoryStore = MemoryStoreService:GetSortedMap("StaffServerCode_v2")
end)

local backupStore = nil
pcall(function()
    backupStore = DataStoreService:GetDataStore("StaffServerBackup_v1")
end)

-- ===== 4. Public API =====
-- Returns the shared reserved-server code (cached -> backup -> newly reserved), or nil + a message for the player.
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

-- ===== 5. Join guard and chat command =====
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
for _, player in ipairs(Players:GetPlayers()) do
    guardPlayer(player)
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
