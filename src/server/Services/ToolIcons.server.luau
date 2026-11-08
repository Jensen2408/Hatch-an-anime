-- ServerScriptService.ToolIcons (server, no remotes)
-- Gives every egg and character Tool its picture (Tool.TextureId), so Roblox's default backpack shows it (2026-11-08).
-- Tools are made in many places (river, hatch, admin, saved data, shops), so this watches the backpack and the
-- character instead of touching each one. Lookup: ReplicatedStorage.ItemIcons.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ItemIcons = require(ReplicatedStorage:WaitForChild("ItemIcons"))

-- old egg pictures (2026-10-18), only for eggs that have no new picture: golden and unknown eggs
local GOLDEN_EGG_ICON = "rbxassetid://81379007399857"
local UNKNOWN_EGG_ICON = "rbxassetid://97319510622615"

local function iconFor(tool: Tool): string?
    if tool:GetAttribute("EggType") and not (tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId")) then
        if tool:GetAttribute("GoldVariant") then
            return GOLDEN_EGG_ICON
        end
        if tool:GetAttribute("UnknownEgg") then
            return UNKNOWN_EGG_ICON
        end
    end
    return ItemIcons.ForTool(tool) or (tool:GetAttribute("EggType") and ItemIcons.Egg.Pirate) or nil
end

local function apply(tool: Instance)
    if not tool:IsA("Tool") then
        return
    end
    local function set()
        local image = iconFor(tool)
        if image and tool.TextureId ~= image then
            tool.TextureId = image
        end
        -- hover text in the backpack: the full name with the mutation
        if image then
            local mutation = tool:GetAttribute("Mutation")
            local displayName = tool.Name
            if mutation and not displayName:find(mutation, 1, true) then
                displayName = mutation .. " " .. displayName
            end
            if tool.ToolTip == "" or not tool.ToolTip:find(displayName, 1, true) then
                tool.ToolTip = displayName
            end
        end
    end
    set()
    -- attributes and the name are often filled in right after the tool is parented
    task.defer(set)
    task.delay(0.5, set)
end

local function watch(container: Instance)
    for _, child in container:GetChildren() do
        apply(child)
    end
    container.ChildAdded:Connect(apply)
end

local function onPlayer(player: Player)
    local backpack = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 30)
    if backpack then
        watch(backpack)
    end
    player.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then
            watch(child)
        end
    end)
    if player.Character then
        watch(player.Character)
    end
    player.CharacterAdded:Connect(watch)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in Players:GetPlayers() do
    task.spawn(onPlayer, player)
end
