-- ReplicatedStorage.SettingsMenu.SettingsComponent  (ModuleScript, client)
-- The Settings window in the Folk Stud look (2026-11-07): a white studded sheet, "SETTINGS" on the top border with
-- the game's gear hanging over the corner and a red X over the other corner. One candy row per setting with an icon
-- tile: sliders are a white track with a gold fill and a white knob, toggles a chunky ON (lime) / OFF (dark) switch.
-- MusicSettings owns the values and passes them in / gets them back through callbacks. Same API as before:
--
--   local view = SettingsComponent.new(panel, {
--       onClose = function() ... end,
--       rows = {
--           { kind = "slider", title = "Music", value = 0.8, onChange = function(value) end },
--           { kind = "toggle", title = "Animations", text = "…", value = true, onChange = function(isOn) end },
--       },
--   })
--   view.setters[i](value, silent)   -- move a row's control without (silent) or with its callback
-- Old version: ServerStorage._ARCHIVE.SettingsComponent_BeforeStud_2026-11-07
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.H
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local Theme = require(ReplicatedStorage:WaitForChild("StudKit"):WaitForChild("StudTheme"))

local CW, CH = Theme.CanvasSize.X, Theme.CanvasSize.Y   -- 1160 x 730, the panel's aspect
local Z = 10
local C = M.COLOR
local WHITE, BLACK, hex = H.WHITE, H.BLACK, H.hex
local INK_TEXT = hex("3A3150")
local CLOSE = { CW - 40, -30, 74, 74 }
local GEAR_ICON = "rbxassetid://111302073344226"   -- FOLK gear (i_settings), same as the rail

local ROW_COLORS = { C.lilac, C.azure, C.mango, C.aqua, C.bubblegum }
-- 2026-11-07 clean pass: FOLK icons (sharp 256 px art) instead of emoji, which drew small and faint
local ICONS = {
	Music = "rbxassetid://76972732691343",                 -- i_music
	["Sound effects"] = "rbxassetid://128939546342582",    -- i_sound
	Animations = "rbxassetid://87844351568148",            -- i_star
	["Night sky effects"] = "rbxassetid://93829375643664", -- i_planet
	["Floating labels"] = "rbxassetid://129450737903983",  -- i_chat
}
local SLIDER_H, TOGGLE_H, GAP, TOP = 108, 94, 14, 66
local TRACK = { X = 400, W = 420, H = 24 }
local SWITCH = { W = 130, H = 54 }

local SettingsComponent = {}

local function txt(parent, name, str, x, y, w, h, size, z, col, align)
	local l = H.new("TextLabel", { Name = name, BackgroundTransparency = 1, FontFace = M.FONT, Text = str or "", TextScaled = true,
		TextColor3 = col or WHITE, TextXAlignment = align or Enum.TextXAlignment.Center, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z }, parent)
	H.new("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = 10 }, l)
	H.new("UIStroke", { Name = "UIStroke", Thickness = size >= 28 and 3.7 or (size >= 20 and 3 or 2.5), Color = BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, l)
	return l
end
local function card(parent, name, x, y, w, h, pal, z)
	H.shadow(parent, name, x, y, w, h, 18, z)
	local f = H.rect(parent, name, x, y, w, h, 18, z + 1, WHITE)
	H.grad(f, pal[1], pal[2])
	H.ink(f, 4)
	H.studs(f, Vector2.new(48, 48), 0.84, 18, z + 1)
	return f
end
local function percent(value)
	return value == 0 and "OFF" or (math.floor(value * 100 + 0.5) .. "%")
end
local function optOut(root)
	root:SetAttribute("NoSkin", true)
	root:SetAttribute("FS", true)
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			d:SetAttribute("NoSkin", true)
			d:SetAttribute("FS", true)
		end
	end
end

-- a white track with a black outline, a gold fill and a white knob; drag anywhere on the bar. Returns set(value, silent).
local function slider(row, y, value, onChange)
	local track = H.rect(row, "Track", TRACK.X, y, TRACK.W, TRACK.H, 10, Z + 3, WHITE)
	H.ink(track, 3.5)
	local clip = H.new("Frame", { Name = "FillClip", BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.fromOffset(0, TRACK.H), ZIndex = Z + 4 }, track)
	local fill = H.rect(clip, "Fill", 0, 0, TRACK.W, TRACK.H, 10, Z + 4, WHITE)
	H.grad(fill, C.gold[1], C.gold[2])
	local knob = H.circle(row, "Knob", TRACK.X, y + TRACK.H / 2, 46, Z + 6, WHITE, hex("E4DEF5"), 4)
	local pop = H.new("UIScale", { Name = "Grab" }, knob)
	local hit = H.new("TextButton", { Name = "SliderHit", BackgroundTransparency = 1, Text = "", AutoButtonColor = false,
		Position = UDim2.fromOffset(TRACK.X - 24, y - 26), Size = UDim2.fromOffset(TRACK.W + 48, TRACK.H + 52), ZIndex = Z + 8 }, row)
	local current = value
	local function set(newValue, silent)
		current = math.clamp(newValue, 0, 1)
		clip.Size = UDim2.fromOffset(TRACK.W * current, TRACK.H)
		knob.Position = UDim2.fromOffset(TRACK.X + TRACK.W * current, y + TRACK.H / 2)
		if not silent then onChange(current) end
	end
	local dragging = false
	local function fromScreen(x)
		local left, width = track.AbsolutePosition.X, track.AbsoluteSize.X
		set((x - left) / math.max(width, 1))
	end
	hit.MouseEnter:Connect(function() UISound.Play("Hover") end)
	hit.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			pop.Scale = 1.15
			UISound.Play("Click")
			fromScreen(input.Position.X)
		end
	end)
	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromScreen(input.Position.X)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			pop.Scale = 1
		end
	end)
	set(value, true)
	return set
end

-- a chunky switch: ON = lime with the knob right, OFF = the dark slab with the knob left. Returns set(isOn, silent).
local function toggle(row, x, y, value, onChange)
	local sw = H.button(row, "Toggle", x, y, SWITCH.W, SWITCH.H, 20, C.leaf, Z + 3, { lip = 5, studs = 0.7 })
	local face = sw:FindFirstChild("Face")
	local faceGrad = face and face:FindFirstChildOfClass("UIGradient")
	local word = txt(sw, "Word", "ON", 0, 4, SWITCH.W, SWITCH.H - 14, 26, Z + 6)
	local knob = H.circle(sw, "Knob", 0, (SWITCH.H - 5) / 2, SWITCH.H - 14, Z + 7, WHITE, hex("E4DEF5"), 3.5)
	local current = value
	local function look(isOn, animate)
		local pal = isOn and C.leaf or C.ink
		sw.BackgroundColor3 = pal[3]
		if faceGrad then faceGrad.Color = ColorSequence.new(pal[1], pal[2]) end
		word.Text = isOn and "ON" or "OFF"
		word.Position = UDim2.fromOffset(isOn and -18 or 18, 4)
		local goal = { Position = UDim2.fromOffset(isOn and SWITCH.W - SWITCH.H / 2 + 2 or SWITCH.H / 2 - 2, (SWITCH.H - 5) / 2) }
		if animate then
			TweenService:Create(knob, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal):Play()
		else
			knob.Position = goal.Position
		end
	end
	local function set(isOn, silent)
		current = isOn
		look(isOn, not silent)
		if not silent then onChange(isOn) end
	end
	sw.Activated:Connect(function() set(not current) end)
	look(value, false)
	return set
end

function SettingsComponent.new(panel, model)
	for _, name in { "CleanSkin", "CleanBase", "FigmaWindow" } do
		local child = panel:FindFirstChild(name)
		if child and child:IsA("GuiObject") then child.Visible = false end
	end
	local canvas = H.new("Frame", { Name = "StudCanvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CW, CH), ZIndex = Z }, nil)
	local scale = H.new("UIScale", {}, canvas)
	local function fit() scale.Scale = math.max(panel.Size.X.Offset, 1) / CW end
	fit()
	panel:GetPropertyChangedSignal("Size"):Connect(fit)

	-- the sheet, the title on the top border, the gear over the corner, the X over the other corner
	H.shadow(canvas, "Sheet", 0, 0, CW, CH, 26, Z - 2)
	local sheet = H.rect(canvas, "Background", 0, 0, CW, CH, 26, Z - 1, WHITE)
	H.ink(sheet, 5)
	H.crazy(canvas, sheet, { pal = C.purple, w = CW, h = CH, z = Z, band = 58 })
	H.studs(sheet, Vector2.new(50, 46), 0.8, 26, Z - 1)
	H.beams(canvas, 52, 18, 190, Z + 1, hex("B08CFF"), 0.35, 6)
	local gear = H.art(canvas, "HeaderIcon", GEAR_ICON, 52, 16, 112, Z + 2)
	gear:SetAttribute("Float", 16)
	local title = H.text(canvas, "HeaderTitle", "SETTINGS", CW / 2, 6, 72, Z + 4, WHITE)
	H.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, hex("D9C8FF")) }, title)
	H.gleam(title)
	local closeArt = H.rect(canvas, "CloseArt", CLOSE[1], CLOSE[2], CLOSE[3], CLOSE[4], 14, Z + 6, WHITE)
	H.grad(closeArt, C.coral[1], C.coral[2])
	H.ink(closeArt, 4)
	txt(closeArt, "X", "X", 0, 2, CLOSE[3], CLOSE[4] - 6, 54, Z + 7)
	local close = H.new("TextButton", { Name = "Close", BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Position = UDim2.fromOffset(CLOSE[1], CLOSE[2]),
		Size = UDim2.fromOffset(CLOSE[3], CLOSE[4]), ZIndex = Z + 9 }, canvas)
	close.MouseEnter:Connect(function() UISound.Play("Hover") end)
	close.Activated:Connect(function()
		UISound.Play("Click")
		if model.onClose then model.onClose() end
	end)

	local setters = {}
	local y = TOP
	local W = CW - 88
	for i, row in model.rows do
		local h = row.kind == "slider" and SLIDER_H or TOGGLE_H
		local f = card(canvas, "Row" .. i, 44, y, W, h, ROW_COLORS[(i - 1) % #ROW_COLORS + 1], Z)
		local tile = H.rect(f, "IconTile", 14, (h - 70) / 2, 70, 70, 14, Z + 3, WHITE)
		H.ink(tile, 3.5)
		H.art(tile, "Icon", ICONS[row.title] or GEAR_ICON, 35, 35, 60, Z + 4)
		if row.kind == "slider" then
			txt(f, "Title", row.title, 100, 0, 270, h, 34, Z + 4, nil, Enum.TextXAlignment.Left)
			local valuePill = H.rect(f, "ValuePill", W - 150, (h - 54) / 2, 132, 54, 14, Z + 3, WHITE)
			H.ink(valuePill, 3.5)
			local value = txt(valuePill, "Value", percent(row.value), 6, 4, 120, 46, 34, Z + 4, INK_TEXT)
			value.UIStroke.Enabled = false
			local setSlider = slider(f, (h - TRACK.H) / 2, row.value, function(newValue)
				value.Text = percent(newValue)
				row.onChange(newValue)
			end)
			setters[i] = function(newValue, silent)
				value.Text = percent(newValue)
				setSlider(newValue, silent)
			end
		else
			txt(f, "Title", row.title, 100, 10, W - 300, 42, 34, Z + 4, nil, Enum.TextXAlignment.Left)
			txt(f, "Text", row.text or "", 100, 52, W - 300, 30, 22, Z + 4, WHITE, Enum.TextXAlignment.Left)
			setters[i] = toggle(f, W - 20 - SWITCH.W, (h - SWITCH.H) / 2 + 2, row.value, row.onChange)
		end
		y += h + GAP
	end
	local note = txt(canvas, "Note", "✔ Settings are saved automatically.", 80, CH - 60, CW - 160, 32, 24, Z + 1, INK_TEXT)
	note.UIStroke.Enabled = false

	optOut(canvas)
	M.animate(canvas, { sound = function(kind) UISound.Play(kind == "hover" and "Hover" or "Click") end })
	canvas.Parent = panel
	return { canvas = canvas, setters = setters }
end

return SettingsComponent
