-- KeepItemsOnRespawn: eggs and characters (Tools with EggType / CharacterId / BrainrotId) survive dying and respawning.
-- Roblox clears the Backpack and destroys the held Tool on respawn, so a player who died lost every egg they carried.
-- On death they're parked in Player.RespawnHold, then put back in the new Backpack.
-- PlayerDataService saves from Backpack/Character/IncubatorHeldEggs; RespawnHold only exists for the few seconds of a respawn.
-- Runtime: Script in ServerScriptService. Note: a respawn without Humanoid.Died (e.g. LoadCharacterAsync from the admin
-- "Respawn" action) is not handled — see docs/PROJECT_AUDIT.md.
local Players = game:GetService("Players")

-- Eggs / characters that are not currently sitting in an incubator.
local function shouldKeep(tool)
    return tool:IsA("Tool")
        and (tool:GetAttribute("EggType") ~= nil or tool:GetAttribute("CharacterId") ~= nil or tool:GetAttribute(
            "BrainrotId"
        ) ~= nil)
        and not tool:GetAttribute("Incubating")
end

local deadBackpacks = setmetatable({}, { __mode = "k" }) -- [player] = the Backpack Roblox is about to replace

local function parkItems(player, character)
    deadBackpacks[player] = player:FindFirstChildOfClass("Backpack")
    local hold = player:FindFirstChild("RespawnHold") or Instance.new("Folder")
    hold.Name = "RespawnHold"
    hold.Parent = player
    for _, container in { player:FindFirstChildOfClass("Backpack"), character } do
        if container then
            for _, tool in container:GetChildren() do
                if shouldKeep(tool) then
                    tool.Parent = hold
                end
            end
        end
    end
end

local function restoreItems(player)
    local hold = player:FindFirstChild("RespawnHold")
    if not hold then
        return
    end
    -- Roblox swaps in a fresh Backpack around CharacterAdded; putting items in the old one loses them
    local backpack, startedAt = nil, os.clock()
    repeat
        task.wait(0.1)
        backpack = player:FindFirstChildOfClass("Backpack")
    until (backpack and backpack ~= deadBackpacks[player] and backpack.Parent == player)
        or os.clock() - startedAt > 10
        or not player.Parent
    if not backpack or backpack == deadBackpacks[player] or not player.Parent then
        return
    end
    deadBackpacks[player] = nil
    for _, tool in hold:GetChildren() do
        tool.Enabled = true
        tool:SetAttribute("ReturningToBase", nil)
        tool.Parent = backpack
    end
    hold:Destroy()
end

local function watchPlayer(player)
    local function onCharacterAdded(character)
        task.defer(restoreItems, player)
        local humanoid = character:WaitForChild("Humanoid", 10)
        if humanoid then
            humanoid.Died:Connect(function()
                parkItems(player, character)
            end)
        end
    end
    player.CharacterAdded:Connect(onCharacterAdded)
    if player.Character then
        onCharacterAdded(player.Character)
    end
end

Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do
    task.spawn(watchPlayer, player)
end
