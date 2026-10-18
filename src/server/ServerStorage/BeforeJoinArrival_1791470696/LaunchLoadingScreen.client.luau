
--[[
	Hatch an Anime — Launch Loading Screen (matches your Figma export)
	Put this LocalScript in ReplicatedFirst.

	1. Upload ToriiGate.png and Logo.png (Asset Manager > Bulk Import).
	2. Right-click each upload > Copy Asset ID, paste below.
]]

local IMAGES = {
	Torii = "rbxassetid://105894939311351",       -- ToriiGate.png
	Logo = "rbxassetid://127289650811269",       -- Logo.png
	Petal = "rbxassetid://103348443787191",      -- sakura petal
}

local MIN_SHOW_TIME = 4
local HUD_GUI_NAME = "HUD"
local VERSION = "v1.0"

local TIPS = {
	"Tip: Check your Index to see every anime you have hatched!",
	"Tip: Visit the Store to grab something new!",
	"Tip: Tap the music button to mute the soundtrack.",
}

---------------------------------------------------------------------
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ContentProvider = game:GetService("ContentProvider")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()
pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WOOD = Color3.fromRGB(74, 44, 30)
local RED_LIGHT = Color3.fromRGB(255, 120, 120)
local RED = Color3.fromRGB(255, 60, 60)
local RED_DEEP = Color3.fromRGB(214, 28, 28)
local SAKURA = Color3.fromRGB(255, 183, 210)
local CREAM = Color3.fromRGB(255, 244, 220)
local CREAM_TOP = Color3.fromRGB(255, 248, 232)
local CREAM_BOT = Color3.fromRGB(243, 215, 166)

---------------------------------------------------------------------
local function make(className, props, children)
	local inst = Instance.new(className)
	for k, v in pairs(props or {}) do
		if k ~= "Parent" then
			inst[k] = v
		end
	end
	for _, c in ipairs(children or {}) do
		c.Parent = inst
	end
	if props and props.Parent then
		inst.Parent = props.Parent
	end
	return inst
end

local function corner(scale, offset)
	return make("UICorner", { CornerRadius = UDim.new(scale or 0, offset or 0) })
end

local function border(thickness, color)
	return make("UIStroke", {
		Thickness = thickness,
		Color = color or WOOD,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Round,
	})
end

local function textOutline(thickness)
	return make("UIStroke", { Thickness = thickness, Color = WOOD, LineJoinMode = Enum.LineJoinMode.Round })
end

local function vgrad(c1, c2, c3)
	local seq = c3
			and ColorSequence.new({
				ColorSequenceKeypoint.new(0, c1),
				ColorSequenceKeypoint.new(0.5, c2),
				ColorSequenceKeypoint.new(1, c3),
			})
		or ColorSequence.new(c1, c2)
	return make("UIGradient", { Color = seq, Rotation = 90 })
end

local function tween(obj, time, props, style, dir, repeats, reverses)
	local t = TweenService:Create(
		obj,
		TweenInfo.new(time, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, repeats or 0, reverses or false),
		props
	)
	t:Play()
	return t
end

local function box(props, children)
	props.BorderSizePixel = 0
	props.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
	return make("Frame", props, children)
end

local function label(props)
	local p = {
		BackgroundTransparency = 1,
		TextColor3 = Color3.new(1, 1, 1),
		Font = Enum.Font.FredokaOne,
		AnchorPoint = Vector2.new(0.5, 0.5),
	}
	for k, v in pairs(props) do
		p[k] = v
	end
	return make("TextLabel", p)
end

local function image(id, props)
	props.BackgroundTransparency = 1
	props.Image = id
	props.ScaleType = props.ScaleType or Enum.ScaleType.Fit
	props.AnchorPoint = props.AnchorPoint or Vector2.new(0.5, 0.5)
	return make("ImageLabel", props)
end

---------------------------------------------------------------------
-- Root
local gui = make("ScreenGui", {
	Name = "LaunchLoadingScreen",
	IgnoreGuiInset = true,
	ResetOnSpawn = false,
	DisplayOrder = 1000,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	Parent = playerGui,
})

-- CanvasGroup lets the whole screen fade out. Keep it clear: a UIGradient
-- placed directly on a CanvasGroup would tint everything inside it.
local root = make("CanvasGroup", {
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	Parent = gui,
})

-- Sky on its own layer at the back
make("Frame", {
	Name = "Sky",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	Parent = root,
}, {
	vgrad(Color3.fromRGB(110, 200, 255), Color3.fromRGB(175, 228, 255), Color3.fromRGB(255, 214, 236)),
})

-- Rounded green hill: a huge circle whose top edge peeks above the bottom of the screen
local hill = make("Frame", {
	Name = "Hill",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.74),
	Size = UDim2.fromScale(4.3, 4.3),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	Parent = root,
}, {
	make("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Width }),
	corner(1, 0),
	border(6),
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(140, 226, 120)),
			ColorSequenceKeypoint.new(0.035, Color3.fromRGB(79, 180, 92)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(47, 138, 60)),
		}),
	}),
})

local petalLayer = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root })

-- 1920x1080 canvas (same coordinates as Figma), scaled to any screen
local canvas = box({
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(1920, 1080),
	BackgroundTransparency = 1,
	Parent = root,
})
local uiScale = make("UIScale", { Parent = canvas })
local function rescale()
	local s = gui.AbsoluteSize
	if s.X > 0 and s.Y > 0 then
		uiScale.Scale = math.min(s.X / 1920, s.Y / 1080)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale)
rescale()

---------------------------------------------------------------------
-- Torii gate
local TORII_HOME = UDim2.fromOffset(960, 404)
local torii
if IMAGES.Torii ~= "" then
	torii = image(IMAGES.Torii, { Position = TORII_HOME, Size = UDim2.fromOffset(1200, 768), Parent = canvas })
else
	torii = box({ Position = TORII_HOME, Size = UDim2.fromOffset(1200, 768), BackgroundTransparency = 1, Parent = canvas })
	label({ Text = "(add ToriiGate image ID)", TextSize = 28, Position = UDim2.fromScale(0.5, 0.2), Size = UDim2.fromOffset(600, 40), Parent = torii })
end

-- Logo
local LOGO_HOME = UDim2.fromOffset(960, 510)
local logo
if IMAGES.Logo ~= "" then
	logo = image(IMAGES.Logo, { Position = LOGO_HOME, Size = UDim2.fromOffset(968, 372), Parent = canvas })
else
	logo = box({ Position = LOGO_HOME, Size = UDim2.fromOffset(968, 372), BackgroundTransparency = 1, Parent = canvas })
	local a = label({ Text = "HATCH AN", TextSize = 60, Position = UDim2.new(0.5, 0, 0, 55), Size = UDim2.fromOffset(500, 64), Parent = logo })
	textOutline(5).Parent = a
	local b = label({ Text = "ANIME", Font = Enum.Font.LuckiestGuy, TextSize = 170, Position = UDim2.new(0.5, 0, 0, 185), Size = UDim2.fromOffset(760, 170), Parent = logo })
	textOutline(8).Parent = b
	vgrad(Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 8, 8), Color3.fromRGB(230, 30, 30)).Parent = b
end

---------------------------------------------------------------------
-- Status, progress bar, tip, version
local status = label({ Text = "Loading assets...", TextSize = 44, Position = UDim2.fromOffset(960, 822), Size = UDim2.fromOffset(600, 56), Parent = canvas })
textOutline(5).Parent = status

local track = box({
	Position = UDim2.fromOffset(960, 897),
	Size = UDim2.fromOffset(760, 58),
	BackgroundColor3 = Color3.new(1, 1, 1),
	ClipsDescendants = true,
	Parent = canvas,
}, { corner(1, 0), border(6), vgrad(CREAM_TOP, CREAM_BOT) })

local fill = make("Frame", {
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Color3.new(1, 1, 1),
	BorderSizePixel = 0,
	ClipsDescendants = true,
	Parent = track,
}, { corner(1, 0), vgrad(RED_LIGHT, RED, RED_DEEP) })

-- diagonal candy stripes that scroll
local stripes = make("Frame", {
	Size = UDim2.new(0, 900, 1, 0),
	Position = UDim2.fromOffset(-72, 0),
	BackgroundTransparency = 1,
	Parent = fill,
})
for i = 0, 26 do
	make("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, i * 36, 0.5, 0),
		Size = UDim2.fromOffset(14, 90),
		Rotation = 20,
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.75,
		BorderSizePixel = 0,
		Parent = stripes,
	})
end
tween(stripes, 0.8, { Position = UDim2.fromOffset(-36, 0) }, Enum.EasingStyle.Linear, Enum.EasingDirection.Out, -1)

local percent = label({ Text = "0%", TextSize = 30, Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), ZIndex = 5, Parent = track })
textOutline(4).Parent = percent

local tip = label({ Text = TIPS[1], TextSize = 30, TextColor3 = CREAM, Position = UDim2.fromOffset(960, 978), Size = UDim2.fromOffset(1200, 40), Parent = canvas })
textOutline(4).Parent = tip

label({
	Text = VERSION,
	TextSize = 22,
	TextTransparency = 0.3,
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -20, 1, -16),
	Size = UDim2.fromOffset(100, 30),
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = root,
})

---------------------------------------------------------------------
-- Motion
local running = true

local function spawnPetal(startPos, endPos, duration)
	local size = math.random(26, 44)
	local petal
	if IMAGES.Petal ~= "" then
		petal = image(IMAGES.Petal, {
			Position = startPos,
			Size = UDim2.fromOffset(size, size),
			Rotation = math.random(0, 360),
			Parent = petalLayer,
		})
	else
		petal = box({
			Position = startPos,
			Size = UDim2.fromOffset(size, size * 0.7),
			Rotation = math.random(0, 360),
			BackgroundColor3 = SAKURA,
			Parent = petalLayer,
		}, { corner(1, 0), border(2) })
	end
	tween(petal, duration, { Position = endPos, Rotation = petal.Rotation + math.random(-240, 240) }, Enum.EasingStyle.Linear)
	task.delay(duration, function()
		petal:Destroy()
	end)
end

task.spawn(function()
	while running do
		local x = math.random()
		spawnPetal(UDim2.fromScale(x, -0.05), UDim2.fromScale(x + (math.random() - 0.5) * 0.25, 1.05), 6 + math.random() * 3)
		task.wait(0.35)
	end
end)

task.spawn(function()
	local i = 0
	while running do
		i = (i % 3) + 1
		status.Text = "Loading assets" .. string.rep(".", i)
		task.wait(0.4)
	end
end)

task.spawn(function()
	local i = 1
	while running do
		task.wait(4)
		if not running then
			break
		end
		tween(tip, 0.25, { TextTransparency = 1 })
		task.wait(0.25)
		i = (i % #TIPS) + 1
		tip.Text = TIPS[i]
		tween(tip, 0.25, { TextTransparency = 0 })
	end
end)

-- Intro
torii.Position = UDim2.fromOffset(960, -400)
logo.Size = UDim2.fromOffset(0, 0)
tween(torii, 0.7, { Position = TORII_HOME }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
task.delay(0.5, function()
	tween(logo, 0.5, { Size = UDim2.fromOffset(968, 372) }, Enum.EasingStyle.Back, Enum.EasingDirection.Out).Completed:Wait()
	if running then
		tween(logo, 2, { Position = LOGO_HOME - UDim2.fromOffset(0, 10) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	end
end)

-- Hide HUD until done
local hud
task.spawn(function()
	hud = playerGui:WaitForChild(HUD_GUI_NAME, 15)
	if hud and running then
		hud.Enabled = false
	end
end)

---------------------------------------------------------------------
-- Loading
pcall(function()
	ContentProvider:PreloadAsync({ gui }) -- load this screen's own images first
end)

local progress, target = 0, 0
local finishedLoading = false
local startTime = os.clock()

task.spawn(function()
	if not game:IsLoaded() then
		game.Loaded:Wait()
	end
	target = 0.6
	local ok, err = pcall(function()
		ContentProvider:PreloadAsync({ workspace, game:GetService("ReplicatedStorage") })
	end)
	if not ok then
		warn("Preload issue:", err)
	end
	target = 1
	finishedLoading = true
end)

local conn = RunService.RenderStepped:Connect(function(dt)
	if target < 0.6 then
		target = math.min(0.55, target + dt * 0.08)
	end
	local timeCap = math.clamp((os.clock() - startTime) / MIN_SHOW_TIME, 0, 1)
	local goal = math.min(target, 0.15 + 0.85 * timeCap)
	progress += (goal - progress) * math.min(1, dt * 4)
	fill.Size = UDim2.fromScale(progress, 1)
	percent.Text = math.floor(progress * 100 + 0.5) .. "%"
end)

repeat
	task.wait(0.1)
until finishedLoading and progress >= 0.995 and os.clock() - startTime >= MIN_SHOW_TIME

---------------------------------------------------------------------
-- Done
running = false
conn:Disconnect()
fill.Size = UDim2.fromScale(1, 1)
percent.Text = "100%"
status.Text = "Ready!"

for _ = 1, 18 do
	local a = math.random() * math.pi * 2
	local d = 0.15 + math.random() * 0.2
	spawnPetal(UDim2.fromScale(0.5, 0.8), UDim2.fromScale(0.5 + math.cos(a) * d, 0.8 + math.sin(a) * d), 0.7)
end

task.wait(0.6)
tween(torii, 0.5, { Position = UDim2.fromOffset(960, -500) }, Enum.EasingStyle.Back, Enum.EasingDirection.In)
tween(root, 0.6, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
task.wait(0.65)

pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
if hud then
	hud.Enabled = true
end
gui:Destroy()
