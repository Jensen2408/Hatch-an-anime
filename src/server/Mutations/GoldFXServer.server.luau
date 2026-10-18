-- GoldFXServer (server Script, ServerScriptService)
-- Applies the shared gold character effect (ReplicatedStorage.GoldCharacterFX) to every gold character model in
-- the workspace. A model is "gold" when its name contains "gold" (case-insensitive) or it has the Gold / Golden
-- attribute set to true, and it has a Torso and a Head. Re-checked when those attributes or the name change.
-- GoldCharacterFX.apply builds a "GoldFX" child in the model; the client animates it (GoldFXClient).
local GoldCharacterFX = require(game.ReplicatedStorage:WaitForChild("GoldCharacterFX"))

local watchedModels = {}

local function isGoldCharacter(model)
    return model:IsA("Model")
        and not model:FindFirstAncestor("GoldFX")
        and (model.Name:lower():find("gold") or model:GetAttribute("Gold") == true or model:GetAttribute("Golden") == true)
        and model:FindFirstChild("Torso", true)
        and model:FindFirstChild("Head", true)
end

local function applyIfGold(model)
    if isGoldCharacter(model) and not model:FindFirstChild("GoldFX") then
        GoldCharacterFX.apply(model)
    end
end

local function watchModel(model)
    if not model:IsA("Model") or watchedModels[model] or model:FindFirstAncestor("GoldFX") then
        return
    end
    watchedModels[model] = true
    model:GetAttributeChangedSignal("Gold"):Connect(function()
        applyIfGold(model)
    end)
    model:GetAttributeChangedSignal("Golden"):Connect(function()
        applyIfGold(model)
    end)
    model:GetPropertyChangedSignal("Name"):Connect(function()
        applyIfGold(model)
    end)
    -- deferred: DescendantAdded fires before the rest of a cloned model's children are parented
    task.defer(applyIfGold, model)
    model.Destroying:Connect(function()
        watchedModels[model] = nil
    end)
end

workspace.DescendantAdded:Connect(watchModel)
for _, descendant in ipairs(workspace:GetDescendants()) do
    watchModel(descendant)
end
