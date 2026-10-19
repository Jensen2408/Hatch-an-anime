-- ServerScriptService.NoDropping (server, no remotes)
-- Players can't drop anything (owner's rule). Safety net: any Tool that ends up in a
-- player's Backpack or character gets CanBeDropped = false, even if a future script forgets.
-- (The F key / Drop button are also off: see TwoHandItemCarryServer.)
local Players = game:GetService("Players")
local function lockTool(tool)
    if tool:IsA("Tool") and tool.CanBeDropped then
        tool.CanBeDropped = false
    end
end
local function watchContainer(container)
    for _, child in container:GetChildren() do
        lockTool(child)
    end
    container.ChildAdded:Connect(lockTool)
end
local function onPlayerAdded(player)
    local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 10)
    if backpack then
        watchContainer(backpack)
    end
    player.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then
            watchContainer(child)
        end
    end)
    if player.Character then
        watchContainer(player.Character)
    end
    player.CharacterAdded:Connect(watchContainer)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end
