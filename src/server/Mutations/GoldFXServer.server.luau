local FX = require(game.ReplicatedStorage:WaitForChild("GoldCharacterFX"))
local watched = {}
local function eligible(m)
    return m:IsA("Model")
        and not m:FindFirstAncestor("GoldFX")
        and (m.Name:lower():find("gold") or m:GetAttribute("Gold") == true or m:GetAttribute("Golden") == true)
        and m:FindFirstChild("Torso", true)
        and m:FindFirstChild("Head", true)
end
local function apply(m)
    if eligible(m) and not m:FindFirstChild("GoldFX") then
        FX.apply(m)
    end
end
local function watch(m)
    if not m:IsA("Model") or watched[m] or m:FindFirstAncestor("GoldFX") then
        return
    end
    watched[m] = true
    m:GetAttributeChangedSignal("Gold"):Connect(function()
        apply(m)
    end)
    m:GetAttributeChangedSignal("Golden"):Connect(function()
        apply(m)
    end)
    m:GetPropertyChangedSignal("Name"):Connect(function()
        apply(m)
    end)
    task.defer(apply, m)
    m.Destroying:Connect(function()
        watched[m] = nil
    end)
end
workspace.DescendantAdded:Connect(watch)
for _, v in ipairs(workspace:GetDescendants()) do
    watch(v)
end
