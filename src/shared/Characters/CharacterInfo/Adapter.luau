--[[ ReplicatedStorage.CharacterInfo.Adapter  (ModuleScript)
Maps the Character Info UI onto Hatch an Anime. Display only: the server stays authoritative.
  Held tools  (EggCharacterRewards.Tool): CharacterId, BrainrotId, DesignName, Rarity, Power, IncomePerSecond, RollQuality
  Placed models (BrainrotPlacement): tag "FloatingCharacter", Power, IncomePerSecond, RollQuality, CharacterId
                (no Rarity/name attributes, so those come from CharacterCatalog by id)
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("CharacterCatalog"))
local Adapter = {}

-- Attribute names the card reads (values are attribute names, keys are what the UI calls them).
Adapter.Attr = {
    Name = "DesignName",
    Rarity = "Rarity",
    Power = "Power",
    Income = "IncomePerSecond",
    Quality = "RollQuality",
    CharacterId = "CharacterId",
}
Adapter.PlacedTag = "FloatingCharacter" -- BrainrotPlacement already tags every placed character with this
-- every world model that gets a floating label, with its label size
Adapter.ModelTags = {
    FloatingCharacter = "Placed", -- on a temple slot
    HatchRewardDisplay = "Hatch", -- standing in the incubator after hatching
}
-- old plain-text labels the server still puts on some models; hidden locally so nothing doubles up
Adapter.OldLabels = { "PowerInfo", "CharacterInfo" }

-- Gold stripe + shine for the rare huge rolls (CharacterEconomy bands, 10x base Power and up)
local BIG_ROLLS = { Jackpot = true, Ultra = true, Cosmic = true }

-- Older tools carry BrainrotId; it wins over CharacterId when both exist.
local function characterId(instance)
    return instance:GetAttribute("BrainrotId") or instance:GetAttribute("CharacterId")
end

function Adapter.IsCharacterTool(tool)
    return tool:IsA("Tool") and tool:GetAttribute(Adapter.Attr.CharacterId) ~= nil
end

-- Card data for a tool or model, or nil when it has no Power attribute (not a rolled character).
function Adapter.Read(instance)
    local attr = Adapter.Attr
    local power = instance:GetAttribute(attr.Power)
    if power == nil then
        return nil
    end
    local entry = Catalog.ById[characterId(instance) or ""]
    local name = Catalog.DisplayName(instance:GetAttribute(attr.Name) or (entry and entry.Name) or instance.Name)
    if instance:GetAttribute("GoldVariant") and not name:match("^Golden%s") then
        name = "Golden " .. name
    end
    return {
        name = name,
        rarity = instance:GetAttribute(attr.Rarity) or (entry and entry.Rarity) or "Common",
        power = tonumber(power) or 0,
        income = tonumber(instance:GetAttribute(attr.Income)) or 0,
        mutation = instance:GetAttribute("Mutation"),
        exceptional = BIG_ROLLS[instance:GetAttribute(attr.Quality) or ""] == true
            or instance:GetAttribute("GoldVariant") == true,
    }
end

-- Every attribute whose change should refresh the card.
function Adapter.Watched()
    local attributeNames = {}
    for _, attributeName in Adapter.Attr do
        table.insert(attributeNames, attributeName)
    end
    table.insert(attributeNames, "GoldVariant")
    table.insert(attributeNames, "Mutation")
    return attributeNames
end

-- Touch Drop: the game's existing DropHeldItemClient already shows a Drop button on touch screens,
-- so the card's own button stays off to avoid two Drop buttons. To use the card button instead:
-- Adapter.Drop = function() ReplicatedStorage.DropHeldItem:FireServer() end
Adapter.Drop = nil

Adapter.DropKey = Enum.KeyCode.F -- DropHeldItemClient binds F
-- Client only (uses LocalPlayer): the game's own toggle or the Roblox setting.
Adapter.ReducedMotion = function()
    return Players.LocalPlayer:GetAttribute("ReducedMotion") == true
        or game:GetService("GuiService").ReducedMotionEnabled
end

return Adapter
