-- ToolIcons: every egg / character Tool gets a picture (TextureId) so Roblox's default backpack + hotbar show what you hold.
-- Characters use their Index art (CharacterCatalog .image); eggs use rendered icons (uploaded 2026-10-18, sources in
-- D:\Roblox Dev\Steal Anime Egg\Eggs\_icons). ToolTip shows the full name incl. mutation on hover.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Catalog = require(RS:WaitForChild("CharacterCatalog"))

local EGG = {
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
local GOLDEN_EGG = "rbxassetid://81379007399857"

local function iconFor(tool)
    local cid = tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId")
    if cid then
        local e = Catalog.ById[cid]
        return e and e.image
    end
    local egg = tool:GetAttribute("EggType")
    if not egg then
        return nil
    end
    if tool:GetAttribute("GoldVariant") then
        return GOLDEN_EGG
    end
    if tool:GetAttribute("UnknownEgg") then
        return EGG.Unknown
    end
    return EGG[egg] or EGG.Pirate
end

local function stamp(tool)
    if not tool:IsA("Tool") then
        return
    end
    local img = iconFor(tool)
    if img and tool.TextureId ~= img then
        tool.TextureId = img
    end
    if img then
        local mut = tool:GetAttribute("Mutation")
        local name = tool.Name
        if mut and not name:find(mut) then
            name = mut .. " " .. name
        end
        if tool.ToolTip == "" or not tool.ToolTip:find(name, 1, true) then
            tool.ToolTip = name
        end
    end
end

local function watch(container)
    if not container then
        return
    end
    for _, t in container:GetChildren() do
        stamp(t)
    end
    container.ChildAdded:Connect(stamp)
end

local function onPlayer(p)
    watch(p:FindFirstChildOfClass("Backpack"))
    p.ChildAdded:Connect(function(c)
        if c:IsA("Backpack") then
            watch(c)
        end
    end)
    p.CharacterAdded:Connect(watch)
    if p.Character then
        watch(p.Character)
    end
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in Players:GetPlayers() do
    task.spawn(onPlayer, p)
end
