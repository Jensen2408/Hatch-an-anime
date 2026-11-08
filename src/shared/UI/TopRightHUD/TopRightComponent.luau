-- ReplicatedStorage.TopRightHUD.TopRightComponent  (ModuleScript, client)
-- The top-right HUD in the Folk Stud look (2026-11-07): the backpack counter is an azure candy slab (black outline,
-- faint studs, light sweep, hard shadow) with the game's backpack breaking out over its left end, and the feedback
-- button is a pressable bubblegum square with a lip. Display only: FeedbackClient feeds the counter and connects
-- FeedbackButton. Same API, names and root size as the image version, so FeedbackClient's layout is unchanged:
--
--   local hud = TopRightComponent.new(screenGui)
--   hud:SetCapacity(8, 30)   --> "8 / 30"
--   hud:SetVisible(true)
--   hud.FeedbackButton.Activated:Connect(openFeedback)
-- Old version: ServerStorage._ARCHIVE.TopRightComponent_BeforeStud_2026-11-07
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.H
local Config = require(script.Parent:WaitForChild("TopRightConfig"))

local bounds = Config.RefBounds
local RW, RH = bounds[3] * Config.Unit, bounds[4] * Config.Unit   -- ~411 x 101, FeedbackClient lays out by this size

local TopRightComponent = {}
TopRightComponent.__index = TopRightComponent

function TopRightComponent.new(parent)
	local self = setmetatable({}, TopRightComponent)
	local root = H.new("Frame", { Name = "TopRightHUD", BackgroundTransparency = 1, Size = UDim2.fromOffset(RW, RH) }, nil)
	self.Scale = H.new("UIScale", {}, root)

	-- the counter slab (read only: no lip)
	local CX, CY, CW, CH = 18, 10, 286, 80
	local counter = H.new("Frame", { Name = "BackpackCounter", BackgroundTransparency = 1, Size = UDim2.fromOffset(CX + CW, RH) }, root)
	H.shadow(counter, "Counter", CX, CY, CW, CH, 16, 1)
	local slab = H.rect(counter, "CounterBackground", CX, CY, CW, CH, 16, 2, H.WHITE)
	H.grad(slab, M.COLOR.azure[1], M.COLOR.azure[2])
	H.ink(slab, 4)
	H.studs(slab, Vector2.new(48, 48), 0.78, 16, 2)
	H.shine(slab, 16, 3)
	local bag = H.art(counter, "BackpackIcon", "rbxassetid://109595149634754", 44, 46, 92, 5)   -- FOLK backpack (i_bag)
	bag:SetAttribute("Wiggle", 0)

	local text = H.new("TextLabel", { Name = "CapacityText", BackgroundTransparency = 1, FontFace = M.FONT, Text = "", TextScaled = true, TextColor3 = H.WHITE,
		Position = UDim2.fromOffset(98, CY + 10), Size = UDim2.fromOffset(CX + CW - 98 - 14, CH - 22), ZIndex = 6 }, counter)
	H.new("UITextSizeConstraint", { MaxTextSize = 54 }, text)
	H.new("UIStroke", { Name = "UIStroke", Thickness = 3.7, Color = H.BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, text)
	H.gleam(text)
	self.CapacityLabel = text

	-- the feedback button: pressable, so it gets a lip and studs
	local fb = H.button(root, "FeedbackButton", RW - 92, 8, 86, 80, 16, M.COLOR.bubblegum, 3, { lip = 6, studs = 0.7 })
	fb:SetAttribute("Spring", 6)
	H.art(fb, "Icon", Config.Assets.FeedbackIcon, 43, 37, 54, fb.ZIndex + 2).ResampleMode = Enum.ResamplerMode.Pixelated

	M.animate(root, { sounds = false })   -- FeedbackClient plays the game's own open / close sounds
	self.Root = root
	self.FeedbackButton = fb
	self:SetCapacity(0, 0)
	root.Parent = parent
	return self
end

-- "used / max"; long values shrink to fit the slab
function TopRightComponent:SetCapacity(used, max)
	local t = tostring(used) .. Config.CapacitySeparator .. tostring(max)
	if self.CapacityLabel.Text ~= t then self.CapacityLabel.Text = t end
end

function TopRightComponent:SetVisible(visible)
	self.Root.Visible = visible
end

function TopRightComponent:Destroy()
	self.Root:Destroy()
end

return TopRightComponent
