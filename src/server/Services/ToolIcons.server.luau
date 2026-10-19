-- ServerScriptService.ToolIcons (server, no remotes)
-- ToolIcons: every egg / character Tool gets a picture (TextureId) so Roblox's default backpack + hotbar show what you hold.
-- Characters use their Index art (CharacterCatalog .image); eggs use rendered icons (uploaded 2026-10-18, sources in
-- D:\Roblox Dev\Steal Anime Egg\Eggs\_icons). ToolTip shows the full name incl. mutation on hover.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterCatalog = require(ReplicatedStorage:WaitForChild("CharacterCatalog"))

local EGG_ICONS = {
    Academy = "rbxassetid://137164838180832",
    Curse = "rbxassetid://135569943434538",
    Devil = "rbxassetid://70407891592613",
    God = "rbxassetid://134576337298284",
    Guild = "rbxassetid://138122961621715",
    Hero = "rbxassetid://128626446683948",
    Magic = "rbxassetid://75370181928069",
    Mecha = "rbxassetid://102323344617016",
    Pirate = "rbxassetid://74319663850465",
    Power = "rbxassetid://88919675024847",
    Shinobi = "rbxassetid://122270717955727",
    Slayer = "rbxassetid://140219939471647",
    Soul = "rbxassetid://92563202680635",
    Sports = "rbxassetid://71168536845585",
    Titan = "rbxassetid://90171889847806",
    Unknown = "rbxassetid://97319510622615",
}
local GOLDEN_EGG_ICON = "rbxassetid://81379007399857"

-- Characters (CharacterId, legacy BrainrotId) use their catalog image; gold-variant eggs, unknown eggs and
-- regular eggs use the icons above (unlisted egg types fall back to the Pirate icon).
local function iconFor(tool)
    local characterId = tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId")
    if characterId then
        local entry = CharacterCatalog.ById[characterId]
        return entry and entry.image
    end
    local eggType = tool:GetAttribute("EggType")
    if not eggType then
        return nil
    end
    if tool:GetAttribute("GoldVariant") then
        return GOLDEN_EGG_ICON
    end
    if tool:GetAttribute("UnknownEgg") then
        return EGG_ICONS.Unknown
    end
    return EGG_ICONS[eggType] or EGG_ICONS.Pirate
end

local function stampIcon(tool)
    if not tool:IsA("Tool") then
        return
    end
    local icon = iconFor(tool)
    if icon and tool.TextureId ~= icon then
        tool.TextureId = icon
    end
    if icon then
        local mutation = tool:GetAttribute("Mutation")
        local displayName = tool.Name
        if mutation and not displayName:find(mutation) then
            displayName = mutation .. " " .. displayName
        end
        if tool.ToolTip == "" or not tool.ToolTip:find(displayName, 1, true) then
            tool.ToolTip = displayName
        end
    end
end

local function watchContainer(container)
    if not container then
        return
    end
    for _, child in container:GetChildren() do
        stampIcon(child)
    end
    container.ChildAdded:Connect(stampIcon)
end

local function onPlayerAdded(player)
    watchContainer(player:FindFirstChildOfClass("Backpack"))
    player.ChildAdded:Connect(function(child)
        if child:IsA("Backpack") then
            watchContainer(child)
        end
    end)
    player.CharacterAdded:Connect(watchContainer)
    if player.Character then
        watchContainer(player.Character)
    end
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
    task.spawn(onPlayerAdded, player)
end
