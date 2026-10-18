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

local function characterId(inst)
	return inst:GetAttribute("BrainrotId") or inst:GetAttribute("CharacterId")
end

function Adapter.IsCharacterTool(tool)
	return tool:IsA("Tool") and tool:GetAttribute(Adapter.Attr.CharacterId) ~= nil
end

function Adapter.Read(inst)
	local A = Adapter.Attr
	local power = inst:GetAttribute(A.Power)
	if power == nil then return nil end
	local entry = Catalog.ById[characterId(inst) or ""]
	local name = Catalog.DisplayName(inst:GetAttribute(A.Name) or (entry and entry.Name) or inst.Name)
	if inst:GetAttribute("GoldVariant") and not name:match("^Golden%s") then name = "Golden " .. name end
	return {
		name = name,
		rarity = inst:GetAttribute(A.Rarity) or (entry and entry.Rarity) or "Common",
		power = tonumber(power) or 0,
		income = tonumber(inst:GetAttribute(A.Income)) or 0,
		exceptional = BIG_ROLLS[inst:GetAttribute(A.Quality) or ""] == true or inst:GetAttribute("GoldVariant") == true,
	}
end

function Adapter.Watched()
	local t = {}
	for _, v in Adapter.Attr do table.insert(t, v) end
	table.insert(t, "GoldVariant")
	return t
end

-- Touch Drop: the game's existing DropHeldItemClient already shows a Drop button on touch screens,
-- so the card's own button stays off to avoid two Drop buttons. To use the card button instead:
-- Adapter.Drop = function() ReplicatedStorage.DropHeldItem:FireServer() end
Adapter.Drop = nil

Adapter.DropKey = Enum.KeyCode.F -- DropHeldItemClient binds F
Adapter.ReducedMotion = function()
	return Players.LocalPlayer:GetAttribute("ReducedMotion") == true or game:GetService("GuiService").ReducedMotionEnabled
end

return Adapter
