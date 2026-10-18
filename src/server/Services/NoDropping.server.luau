-- Players can't drop anything (owner's rule). Safety net: any Tool that ends up in a
-- player's Backpack or character gets CanBeDropped = false, even if a future script forgets.
-- (The F key / Drop button are also off: see TwoHandItemCarryServer.)
local Players = game:GetService("Players")
local function lock(t)
    if t:IsA("Tool") and t.CanBeDropped then
        t.CanBeDropped = false
    end
end
local function watch(container)
    for _, t in container:GetChildren() do
        lock(t)
    end
    container.ChildAdded:Connect(lock)
end
local function onPlayer(p)
    local bag = p:FindFirstChildOfClass("Backpack") or p:WaitForChild("Backpack", 10)
    if bag then
        watch(bag)
    end
    p.ChildAdded:Connect(function(c)
        if c:IsA("Backpack") then
            watch(c)
        end
    end)
    if p.Character then
        watch(p.Character)
    end
    p.CharacterAdded:Connect(watch)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
    task.spawn(onPlayer, p)
end
