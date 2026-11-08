-- GameMenus.LeftMenuComponent  (ModuleScript, client)
-- The left menu in the Folk Stud look (2026-11-07): studded candy squares with the game's pixel icons, a black outline,
-- a lip you press into, and a light that sweeps over them. Same API as the old art version, so MenuLogic is unchanged:
--
--   local menu = LeftMenuComponent.new(gameMenusGui)
--   menu.Buttons.Plot.Activated:Connect(...)       -- EquipBest, Home, Plot, Index, Quests, Shop, Daily, Settings
--   menu:SetButtonPx(98)                            -- on-screen width of one square
--   menu:SetVisible(bool)   menu:Destroy()
--
-- Looks: ReplicatedStorage.FolkStudUI (the kit). Colours and icons: LOOK below. Old version: ServerStorage._ARCHIVE.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.H
local Config = require(script.Parent:WaitForChild("LeftMenuConfig"))

local TILE, GAP, PILL = 112, 12, 54
local W = TILE * 2 + GAP
local GRID_TOP = (PILL + GAP) * 2
local HEIGHT = GRID_TOP + 3 * TILE + 2 * GAP + 8

-- key -> { icon, colour }. Icons: FOLK Icon Pack, 256 px (assets\ui\stud\up\i_*.png, ids in ids.tsv)
local LOOK = {
	Plot = { "rbxassetid://133879873952343", M.COLOR.coral },
	Index = { "rbxassetid://72680797337159", M.COLOR.azure },
	Quests = { "rbxassetid://131345069239287", M.COLOR.mint },
	Shop = { "rbxassetid://76604900085245", M.COLOR.mango },
	Daily = { "rbxassetid://138288609047988", M.COLOR.bubblegum },
	Settings = { "rbxassetid://111302073344226", M.COLOR.lilac },
}

local LeftMenuComponent = {}
LeftMenuComponent.__index = LeftMenuComponent

-- a wide studded pill with a word on it (Equip Best, Home)
local function pill(parent, name, y, word, pal)
	local shadow = H.shadow(parent, name, 0, y, W, PILL, 14, 2)
	local b = H.button(parent, name, 0, y, W, PILL, 14, pal, 3, { lip = 6, studs = 0.7 })
	H.gleam(H.text(b, "Label", word, W / 2, (PILL - 6) / 2, 28, b.ZIndex + 2))
	-- the shadow follows the button, so hiding Home (while carrying an egg) hides both
	b:GetPropertyChangedSignal("Visible"):Connect(function() shadow.Visible = b.Visible end)
	return b
end

function LeftMenuComponent.new(parent)
	local self = setmetatable({}, LeftMenuComponent)
	local root = H.new("Frame", { Name = "LeftMenu", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, HEIGHT) }, nil)
	self.Scale = H.new("UIScale", {}, root)
	local container = H.new("Frame", { Name = "MenuContainer", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, root)

	self.Buttons = {}
	self.Buttons.EquipBest = pill(container, "EquipBestButton", 0, "EQUIP BEST", M.COLOR.leaf)
	self.Buttons.Home = pill(container, "HomeButton", PILL + GAP, "HOME", M.COLOR.aqua)

	for i, entry in ipairs(Config.Grid) do
		local look = LOOK[entry.Key] or { nil, M.COLOR.azure }
		local x = ((i - 1) % 2) * (TILE + GAP)
		local y = GRID_TOP + math.floor((i - 1) / 2) * (TILE + GAP)
		H.shadow(container, entry.Name, x, y, TILE, TILE, 16, 2)
		local b = H.button(container, entry.Name, x, y, TILE, TILE, 16, look[2], 3, { lip = 6, studs = 0.72 })
		b:SetAttribute("Spring", 7)
		b.LayoutOrder = i
		H.art(b, "Icon", look[1], TILE / 2, 40, 76, b.ZIndex + 1):SetAttribute("Float", 40)
		-- one size on every square, so the rail reads as a set
		H.gleam(H.text(b, "Label", entry.Key, TILE / 2, 86, 22, b.ZIndex + 2))
		self.Buttons[entry.Key] = b
	end

	-- MenuLogic gives every descendant one ZIndex after new(); keep each piece's own layer so it can be put back
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then d:SetAttribute("Z", d.ZIndex) end
	end
	M.animate(root, { sounds = false })   -- MenuLogic plays the game's own hover and click sounds

	self.Root = root
	root.Parent = parent
	return self
end

-- Shrinks the whole menu so one square button is `pixels` wide on screen.
function LeftMenuComponent:SetButtonPx(pixels)
	self.Scale.Scale = pixels / TILE
	local base = self.Root.ZIndex
	for _, d in ipairs(self.Root:GetDescendants()) do
		local z = d:IsA("GuiObject") and d:GetAttribute("Z")
		if z then d.ZIndex = base + z end
	end
end

function LeftMenuComponent:SetVisible(visible)
	self.Root.Visible = visible
end

function LeftMenuComponent:Destroy()
	self.Root:Destroy()
end

return LeftMenuComponent
