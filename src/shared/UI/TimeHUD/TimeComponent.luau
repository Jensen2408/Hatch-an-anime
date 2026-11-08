-- ReplicatedStorage.TimeHUD.TimeComponent  (ModuleScript, client)
-- The Day / Night event header in the Folk Stud look (2026-11-07): a candy slab with a black outline, faint studs, a hard
-- shadow and a light sweep, the game's moon or sun icons breaking out over both ends, and the countdown in Fredoka with
-- a gleam on its outline. Under it, a white studded strip with the night bonuses (CASH / HATCH / LUCK).
--   Night look (shown during the day, counting down to the night): lilac slab, moons, no bonus strip
--   Day look (shown during the night, counting down to daylight): mango slab, suns, bonus strip
-- Display only; GameHUD (section 9) feeds it the server's state. Same API and names as the image version:
--
--   local hud = TimeComponent.new(screenGui)
--   hud:SetMode("Night")                 -- "Day" | "Night"
--   hud:SetRemainingTime(248)            --> "NIGHT EVENT IN 04:08"
--   hud:SetMultipliers({ Cash = 3, Hatch = 2, Luck = 3 })
--   hud:SetVisible(true)
-- Old version: ServerStorage._ARCHIVE.TimeComponent_BeforeStud_2026-11-07
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.H
local Config = require(script.Parent:WaitForChild("TimeConfig"))

local RW, RH = Config.RootSize.X, Config.RootSize.Y   -- 480 x 102: GameHUD scales the header by this size
local LOOKS = {
	Night = { pal = M.COLOR.lilac, left = Config.Modes.Night.LeftIcon, right = Config.Modes.Night.RightIcon, names = Config.Modes.Night.IconNames },
	Day = { pal = M.COLOR.mango, left = Config.Modes.Day.LeftIcon, right = Config.Modes.Day.RightIcon, names = Config.Modes.Day.IconNames },
}
local BONUS_COLOR = { Cash = H.hex("FFD000"), Hatch = H.hex("5BEBFF"), Luck = H.hex("FF6FD0") }

local TimeComponent = {}
TimeComponent.__index = TimeComponent

-- "MM:SS", rounded up, never negative
function TimeComponent.FormatClock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%02d:%02d", seconds // 60, seconds % 60)
end

-- 3 -> "3x", 1.5 -> "1.5x"
local function formatMultiplier(value)
	return (value % 1 == 0 and string.format("%d", value) or string.format("%.1f", value)) .. "x"
end

function TimeComponent:_buildMode(modeName)
	local mode, look = Config.Modes[modeName], LOOKS[modeName]
	local hud = H.new("Frame", { Name = modeName .. "EventHUD", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, self.Root)

	-- the slab
	local PX, PY, PW, PH = 18, 4, RW - 36, 54
	local main = H.new("Frame", { Name = "MainPanel", BackgroundTransparency = 1, Position = UDim2.fromOffset(PX, PY), Size = UDim2.fromOffset(PW, PH) }, hud)
	H.shadow(main, "Slab", 0, 0, PW, PH, 16, 1)
	local slab = H.rect(main, modeName .. "CardTop", 0, 0, PW, PH, 16, 2, H.WHITE)
	H.grad(slab, look.pal[1], look.pal[2])
	H.ink(slab, 4)
	H.studs(slab, Vector2.new(48, 48), 0.78, 16, 2)
	H.shine(slab, 16, 3)

	-- the icons break out over both ends and bob gently
	for i, side in ipairs({ { look.left, 2 }, { look.right, PW - 2 } }) do
		local icon = H.art(main, look.names[i], side[1], side[2], PH / 2 - 2, 66, 6)
		icon.ResampleMode = Enum.ResamplerMode.Pixelated
		icon:SetAttribute("Float", PH / 2 - 2)
	end

	local countdown = H.new("TextLabel", { Name = "CountdownText", BackgroundTransparency = 1, FontFace = M.FONT, Text = "", TextScaled = true, TextColor3 = H.WHITE,
		Position = UDim2.fromOffset(46, 7), Size = UDim2.fromOffset(PW - 92, PH - 16), ZIndex = 7 }, main)
	H.new("UITextSizeConstraint", { MaxTextSize = 32 }, countdown)
	H.new("UIStroke", { Name = "UIStroke", Thickness = 3.7, Color = H.BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, countdown)
	H.gleam(countdown)

	-- the bonus strip: white studded, hangs under the slab
	local BW, BH = 300, 36
	local panel = H.new("Frame", { Name = "MultiplierPanel", BackgroundTransparency = 1, Position = UDim2.fromOffset((RW - BW) / 2, PY + PH + 2), Size = UDim2.fromOffset(BW, BH),
		Visible = mode.ShowMultipliers ~= false }, hud)
	H.shadow(panel, "Strip", 0, -4, BW, BH, 12, 1)
	local strip = H.rect(panel, "MultiplierBackground", 0, 0, BW, BH, 12, 1, H.WHITE)
	H.ink(strip, 4)
	H.studs(strip, Vector2.new(50, 46), 0.8, 12, 1)
	local content = H.new("Frame", { Name = "MultiplierContent", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8 }, panel)
	H.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center,
		VerticalAlignment = Enum.VerticalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8) }, content)
	local multipliers = {}
	for index, spec in Config.Multipliers do
		if index > 1 then
			-- a small black-outlined diamond between the bonuses
			local holder = H.new("Frame", { Name = "Separator" .. (index - 1), BackgroundTransparency = 1, Size = UDim2.fromOffset(12, 12), LayoutOrder = index * 2 - 1, ZIndex = 8 }, content)
			local d = H.new("Frame", { Name = "Diamond", BackgroundColor3 = look.pal[1], AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(9, 9), Rotation = 45, ZIndex = 8 }, holder)
			H.ink(d, 2.5)
		end
		local l = H.new("TextLabel", { Name = spec.Name, BackgroundTransparency = 1, FontFace = M.FONT, Text = "", TextSize = 21, TextColor3 = BONUS_COLOR[spec.Key] or H.WHITE,
			AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, BH - 6), LayoutOrder = index * 2, ZIndex = 9 }, content)
		H.new("UIStroke", { Name = "UIStroke", Thickness = 3, Color = H.BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, l)
		multipliers[spec.Key] = l
	end
	return { Hud = hud, Mode = mode, Countdown = countdown, Multipliers = multipliers }
end

function TimeComponent.new(parent)
	local self = setmetatable({}, TimeComponent)
	local root = H.new("Frame", { Name = "TimeHUD", BackgroundTransparency = 1, Size = UDim2.fromOffset(RW, RH) }, nil)
	self.Root = root
	self.Scale = H.new("UIScale", {}, root)
	self.Modes = { Day = self:_buildMode("Day"), Night = self:_buildMode("Night") }
	self.RemainingTime = 0
	self.MultiplierValues = { Cash = 1, Hatch = 1, Luck = 1 }
	self:SetMode("Night")
	M.animate(root, { sounds = false })
	root.Parent = parent
	return self
end

-- Writes the countdown and multiplier text of the visible mode (unchanged text is skipped).
function TimeComponent:_refresh()
	local state = self.Modes[self.ModeName]
	local title = state.Mode.TitlePrefix .. TimeComponent.FormatClock(self.RemainingTime)
	if state.Countdown.Text ~= title then state.Countdown.Text = title end
	for _, spec in Config.Multipliers do
		local t = formatMultiplier(self.MultiplierValues[spec.Key] or 1) .. " " .. spec.Label
		local l = state.Multipliers[spec.Key]
		if l.Text ~= t then l.Text = t end
	end
end

function TimeComponent:SetMode(modeName)
	assert(Config.Modes[modeName], 'TimeComponent:SetMode expects "Day" or "Night"')
	if modeName == self.ModeName then return end
	self.ModeName = modeName
	for name, state in self.Modes do
		state.Hud.Visible = name == modeName
	end
	self:_refresh()
end

function TimeComponent:SetRemainingTime(seconds)
	self.RemainingTime = seconds
	self:_refresh()
end

function TimeComponent:SetMultipliers(values)
	for key, value in values do
		self.MultiplierValues[key] = value
	end
	self:_refresh()
end

function TimeComponent:SetVisible(visible)
	self.Root.Visible = visible
end

function TimeComponent:Destroy()
	self.Root:Destroy()
end

return TimeComponent
