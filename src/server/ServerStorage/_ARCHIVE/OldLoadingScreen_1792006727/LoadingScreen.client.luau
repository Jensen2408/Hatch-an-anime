--[[ ReplicatedFirst.LoadingScreen  (LocalScript)  — Hatch An Anime loading screen
Children: Config (ModuleScript).
Shows real loading progress (game load → assets → your plot), Skip at any time, closes within Config.MaxSeconds.
Cosmetic only: never touches money, inventory, spawning or gameplay.
]]
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Config = require(script:WaitForChild("Config"))
local C = Config.Colors
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("HatchLoading") then return end -- never twice
ReplicatedFirst:RemoveDefaultLoadingScreen()

local reduced = player:GetAttribute(Config.ReducedMotionAttribute) == true
pcall(function() reduced = reduced or GuiService.ReducedMotionEnabled end)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)

---------------------------------------------------------------- helpers
local conns, tweens = {}, {}
local function make(class, props, parent) local o = Instance.new(class); for k, v in props do o[k] = v end; if parent then o.Parent = parent end; return o end
local function corner(o, r) return make("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
local function ink(o, t) return make("UIStroke", { Color = C.Ink, Thickness = t or 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end
local function tween(o, t, props, style, dir, delay)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, 0, false, delay or 0), props)
	table.insert(tweens, tw); tw:Play(); return tw
end
local function frame(parent, props) props.BorderSizePixel = 0; return make("Frame", props, parent) end
local function image(parent, id, props) if id == "" then return nil end props.Image = id; props.BackgroundTransparency = 1; return make("ImageLabel", props, parent) end

---------------------------------------------------------------- build
-- ScreenInsets None: art covers the whole screen incl. notch strips (content is kept safe in layout())
local gui = make("ScreenGui", { Name = "HatchLoading", IgnoreGuiInset = true, ScreenInsets = Enum.ScreenInsets.None, ResetOnSpawn = false, DisplayOrder = 1000, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, playerGui)
local root = make("CanvasGroup", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Cream, BorderSizePixel = 0, Active = true }, gui) -- Active swallows clicks
local reveal = make("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.49, 0), NumberSequenceKeypoint.new(0.51, 1), NumberSequenceKeypoint.new(1, 1) }), Offset = Vector2.new(reduced and 1 or -0.5, 0) }, root)
local fit = make("UIScale", {}, root)

-- landscape (built-in shapes; optional painted layers sit on top when IDs are set)
local land = frame(root, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.Cream })
make("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.Sky), ColorSequenceKeypoint.new(0.46, C.Biscuit), ColorSequenceKeypoint.new(0.7, C.Cream), ColorSequenceKeypoint.new(1, C.Cream) }) }, land)
local sun = frame(land, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.16, 0.2), Size = UDim2.fromOffset(140, 140), BackgroundColor3 = C.Gold, BackgroundTransparency = 0.25 }); corner(sun, 70)
local far = image(land, Config.Images.Mountains, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 0.72), Size = UDim2.fromScale(2, 0.42), ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromScale(0.5, 1) })
if not far then -- fallback: two soft mountain bands
	far = frame(land, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 0.72), Size = UDim2.fromScale(2, 0.2), BackgroundColor3 = C.Haze })
end
local mid = image(land, Config.Images.Hills, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 0.78), Size = UDim2.fromScale(2, 0.3), ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromScale(0.5, 1) })
	or frame(land, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 0.78), Size = UDim2.fromScale(2, 0.12), BackgroundColor3 = C.Indigo })
local ground = frame(land, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.fromScale(1, 0.28), BackgroundColor3 = C.Grass })
local river = frame(land, { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(-0.05, 1), Size = UDim2.fromScale(1.1, 0.13), BackgroundColor3 = C.River }); ink(river, 4)
local flow = make("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C.River), ColorSequenceKeypoint.new(0.48, C.River), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.52, C.River), ColorSequenceKeypoint.new(1, C.River) }) }, river)
local function shrine(x, w, h, anchorX)
	local s = frame(land, { AnchorPoint = Vector2.new(anchorX, 1), Position = UDim2.fromScale(x, 0.79), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1 })
	local roof = frame(s, { Position = UDim2.new(-0.14, 0, 0, 0), Size = UDim2.new(1.28, 0, 0.22, 0), BackgroundColor3 = C.Crimson }); corner(roof, 6); ink(roof, 4)
	local body = frame(s, { Position = UDim2.new(0.05, 0, 0.22, 0), Size = UDim2.new(0.9, 0, 0.78, 0), BackgroundColor3 = C.Cream }); ink(body, 4)
	for _, px in { 0.14, 0.76 } do local p = frame(body, { Position = UDim2.fromScale(px, 0), Size = UDim2.fromScale(0.1, 1), BackgroundColor3 = C.Red }); ink(p, 3) end
	return s
end
local temple = image(land, Config.Images.Temple, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromScale(0.5, 0.8), Size = UDim2.fromScale(1, 0.35), ScaleType = Enum.ScaleType.Fit })
local shrines = temple and { temple } or { shrine(0.08, 230, 190, 0), shrine(0.92, 170, 140, 1) }
local branchL = image(land, Config.Images.BranchLeft, { Position = UDim2.fromOffset(-20, -10), Size = UDim2.fromOffset(420, 200) })
local branchR = image(land, Config.Images.BranchRight, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 20, 0, -10), Size = UDim2.fromOffset(420, 200) })
if Config.Images.Paper ~= "" then image(land, Config.Images.Paper, { Size = UDim2.fromScale(1, 1), ImageTransparency = 0.8, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(256, 256) }) end
-- lanterns
local lanterns = {}
for i, x in { 0.18, 0.3, 0.82 } do
	local cord = frame(land, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(x, 0), Size = UDim2.fromOffset(2, 80 + i * 12), BackgroundColor3 = C.Ink })
	local lamp = frame(cord, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.fromOffset(28, 32), BackgroundColor3 = C.Red }); corner(lamp, 10); ink(lamp, 3)
	table.insert(lanterns, { cord = cord, phase = i * 1.7, speed = 1.6 + i * 0.3 })
end

-- sliding doors
local doors = {}
for _, side in { -1, 1 } do
	local d = frame(root, { AnchorPoint = Vector2.new(side < 0 and 1 or 0, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), BackgroundColor3 = C.Cream, ZIndex = 20 })
	ink(d, 4)
	frame(d, { Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = C.Ink, ZIndex = 21 })
	for _, px in { 0.33, 0.66 } do frame(d, { Position = UDim2.fromScale(px, 0), Size = UDim2.new(0, 4, 1, 0), BackgroundColor3 = C.Ink, ZIndex = 21 }) end
	table.insert(doors, { f = d, side = side })
	if reduced then d.Visible = false end
end

-- logo plaque (logo image used unchanged, framed in gold)
local center = frame(root, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.11), Size = UDim2.fromOffset(560, 360), BackgroundTransparency = 1, ZIndex = 10 })
local rays = frame(center, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 138), Size = UDim2.fromOffset(470, 470), BackgroundTransparency = 1, ZIndex = 9 })
for i = 0, 11 do
	-- full-length spokes crossing the centre (GUI rotation pivots on each spoke's centre)
	local r = frame(rays, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 30, 1, 0), Rotation = i * 15, BackgroundColor3 = C.Gold, BackgroundTransparency = 0.45, ZIndex = 9 })
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.35, 0.35), NumberSequenceKeypoint.new(0.5, 0.15), NumberSequenceKeypoint.new(0.65, 0.35), NumberSequenceKeypoint.new(1, 1) }) }, r)
end
if reduced then rays.Visible = false end
local plaqueHold = frame(center, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(270, 277), BackgroundTransparency = 1, ZIndex = 10 })
local logoScale = make("UIScale", { Scale = reduced and 1 or 0.4 }, plaqueHold)
local base = frame(plaqueHold, { Position = UDim2.fromOffset(0, 7), Size = UDim2.fromOffset(270, 270), BackgroundColor3 = C.Ink, ZIndex = 10 }); corner(base, 24)
local plaque = frame(plaqueHold, { Size = UDim2.fromOffset(270, 270), BackgroundColor3 = C.Gold, ZIndex = 11 }); corner(plaque, 24); ink(plaque, 5)
local logoClip = make("CanvasGroup", { Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 1, -16), BackgroundColor3 = Color3.fromRGB(8, 18, 37), BorderSizePixel = 0, ZIndex = 12 }, plaque); corner(logoClip, 14)
local logo = make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Config.Images.Logo, ScaleType = Enum.ScaleType.Fit, ZIndex = 12 }, logoClip)
local logoFallback = make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "HATCH AN ANIME", FontFace = FONT, TextScaled = true, TextColor3 = C.Cream, Visible = Config.Images.Logo == "", ZIndex = 13 }, logoClip)
make("UIPadding", { PaddingLeft = UDim.new(0.15, 0), PaddingRight = UDim.new(0.15, 0) }, logoFallback)
local shine = frame(logoClip, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 224, 150), ZIndex = 14 })
local shineGrad = make("UIGradient", { Rotation = 20, Offset = Vector2.new(-1.3, 0), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }) }, shine)
if reduced then shine.Visible = false end
logoClip.GroupTransparency = reduced and 0 or 1

local sparks = {}
for i, p in { { -0.06, 0.08, 16 }, { 0.96, 0.18, 12 }, { 0.9, 0.88, 18 }, { -0.02, 0.78, 11 }, { 0.48, -0.08, 14 } } do
	local sp = frame(plaqueHold, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(p[1], p[2]), Size = UDim2.fromOffset(p[3], p[3]), BackgroundTransparency = 1, ZIndex = 16 })
	frame(sp, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.22, 0, 1, 0), BackgroundColor3 = C.Gold, ZIndex = 16 })
	frame(sp, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0.22, 0), BackgroundColor3 = C.Gold, ZIndex = 16 })
	local sc = make("UIScale", { Scale = 0 }, sp)
	table.insert(sparks, { sc = sc, f = sp, d = 1.6 + i * 0.8 })
end
local clouds = {}
for i, c in { { 0.7, 0.2, 180 }, { 0.3, 0.06, 130 }, { 1.15, 0.13, 150 } } do
	local cl = frame(land, { Position = UDim2.fromScale(c[1], c[2]), Size = UDim2.fromOffset(c[3], c[3] * 0.4), BackgroundColor3 = C.Ivory }); corner(cl, 999); ink(cl, 3)
	table.insert(clouds, { f = cl, x = c[1], y = c[2], speed = 1 / (70 + i * 15) })
end
local koi = frame(land, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.44, 0.95), Size = UDim2.fromOffset(30, 16), BackgroundColor3 = Color3.fromRGB(255, 138, 60), Visible = false, ZIndex = 3 }); corner(koi, 8); ink(koi, 3)
local title = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 312), Size = UDim2.fromOffset(560, 62), BackgroundTransparency = 1, FontFace = FONT, RichText = true,
	Text = 'HATCH AN <font color="#E8452C">ANIME</font>', TextColor3 = C.Cream, TextScaled = true, ZIndex = 12, TextTransparency = reduced and 0 or 1 }, center)
local titleStroke = make("UIStroke", { Color = C.Ink, Thickness = 5, LineJoinMode = Enum.LineJoinMode.Round, Transparency = reduced and 0 or 1 }, title)

-- painted background replaces the built-in scene when set
if (Config.Images.Background or "") ~= "" then
	for _, o in land:GetChildren() do if o:IsA("GuiObject") then o.Visible = false end end
	local bg = frame(land, { Name = "Background", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), BackgroundTransparency = 1, ZIndex = 2 })
	if (Config.Images.BackgroundRight or "") ~= "" then
		make("ImageLabel", { Size = UDim2.new(0.5, 1, 1, 0), BackgroundTransparency = 1, Image = Config.Images.Background, ScaleType = Enum.ScaleType.Stretch, ZIndex = 2 }, bg)
		make("ImageLabel", { Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromScale(0.5, 1), BackgroundTransparency = 1, Image = Config.Images.BackgroundRight, ScaleType = Enum.ScaleType.Stretch, ZIndex = 2 }, bg)
	else
		make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = Config.Images.Background, ZIndex = 2 }, bg)
	end
	local function cover()
		local v = root.AbsoluteSize; if v.X < 2 or v.Y < 2 then v = workspace.CurrentCamera.ViewportSize end -- camera reports the safe area only on notched phones
		local ar = Config.BackgroundAspect or (1376 / 768)
		local w, h = v.X * 1.04, v.X * 1.04 / ar
		if h < v.Y * 1.04 then h = v.Y * 1.04; w = h * ar end
		bg.Size = UDim2.fromOffset(w, h)
	end
	cover(); table.insert(conns, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(cover))
	local vig = frame(land, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(0, 0, 0), ZIndex = 3 })
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.75), NumberSequenceKeypoint.new(0.35, 1), NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 0.35) }) }, vig)
	far, mid = frame(land, { Visible = false }), frame(land, { Visible = false })
	shrines, lanterns, clouds = { bg }, {}, {}
	koi.Visible = false; koi = frame(land, { Visible = false })
end
-- loading bar block
local barBlock = frame(root, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -64), Size = UDim2.fromOffset(520, 110), BackgroundTransparency = 1, ZIndex = 10 })
local stageLbl = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 28), BackgroundColor3 = C.Cream,
	FontFace = FONT, TextSize = 16, TextColor3 = C.Ink, Text = "Preparing your temple…", ZIndex = 11 }, barBlock)
corner(stageLbl, 10); ink(stageLbl, 3); make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, stageLbl)
local barBase = frame(barBlock, { Position = UDim2.fromOffset(0, 47), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.Ink, ZIndex = 10 }); corner(barBase, 15)
local bar = frame(barBlock, { Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 0, 30), BackgroundColor3 = C.Ivory, ZIndex = 11 }); corner(bar, 15); ink(bar, 4)
make("UIStroke", { Color = C.Gold, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0.1 }, frame(bar, { Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundTransparency = 1, ZIndex = 11 })).Parent.Name = "GoldRim"
local fill = frame(bar, { Position = UDim2.fromOffset(4, 4), Size = UDim2.new(0.04, -8, 1, -8), BackgroundColor3 = C.Jade, ZIndex = 12 }); corner(fill, 10)
make("UIGradient", { Rotation = 90, Color = ColorSequence.new(C.JadeLight, C.Jade) }, fill)
-- egg mascot riding the fill edge
local egg = frame(bar, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.04, 0, 0, 8), Size = UDim2.fromOffset(24, 30), BackgroundColor3 = C.Ivory, ZIndex = 14 })
corner(egg, 12); ink(egg, 3)
frame(egg, { Position = UDim2.new(0, 2, 0.45, 0), Size = UDim2.new(1, -4, 0, 4), BackgroundColor3 = C.Red, ZIndex = 15 })
local tipLbl = make("TextLabel", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 86), Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, FontFace = BODY, TextSize = 15, TextColor3 = C.Ink, Text = Config.Tips[1] or "", TextWrapped = true, ZIndex = 11 }, barBlock)
local barGroup = { stageLbl, barBase, bar, tipLbl }
tipLbl.TextColor3 = Color3.new(1, 1, 1); tipLbl.FontFace = FONT; tipLbl.TextSize = 17
make("UIStroke", { Color = C.Ink, Thickness = 2 }, tipLbl)
if not reduced then for _, o in barGroup do o.Visible = false end end

-- petals: a pool of 6 reused tiles
local petals = {}
for i = 1, reduced and 0 or 6 do
	local p = Config.Images.Petal ~= "" and make("ImageLabel", { Image = Config.Images.Petal, BackgroundTransparency = 1, Size = UDim2.fromOffset(16, 13), ZIndex = 18 }, root)
		or frame(root, { Size = UDim2.fromOffset(14, 11), BackgroundColor3 = C.Blossom, ZIndex = 18 })
	if p:IsA("Frame") then corner(p, 6); ink(p, 2) end
	table.insert(petals, { p = p, t = -i * 1.8, dur = 8 + (i % 3) * 2, y = 0.05 + (i * 0.07) % 0.35, spin = 120 + i * 40 })
end

-- Skip button (mouse, touch, gamepad)
local skipHold = frame(root, { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -28, 1, -26), Size = UDim2.fromOffset(120, 52), BackgroundTransparency = 1, ZIndex = 30 })
local skipBase = frame(skipHold, { Position = UDim2.fromOffset(0, 6), Size = UDim2.fromOffset(120, 46), BackgroundColor3 = C.Crimson, ZIndex = 30 }); corner(skipBase, 12); ink(skipBase, 3)
local skip = make("TextButton", { Size = UDim2.fromOffset(120, 46), BackgroundColor3 = C.Red, Text = "SKIP", FontFace = FONT, TextSize = 20, TextColor3 = C.Cream, AutoButtonColor = false, ZIndex = 31, Selectable = true }, skipHold)
corner(skip, 12); ink(skip, 3); make("UIStroke", { Color = C.Ink, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, skip)
local gem = frame(skip, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 22, 0.5, 0), Size = UDim2.fromOffset(9, 9), Rotation = 45, BackgroundColor3 = C.Gold, ZIndex = 32 }); ink(gem, 2)
local function skipPos(y) tween(skip, 0.08, { Position = UDim2.fromOffset(0, y) }) end
table.insert(conns, skip.MouseEnter:Connect(function() skipPos(-2) end))
table.insert(conns, skip.MouseLeave:Connect(function() skipPos(0) end))
table.insert(conns, skip.MouseButton1Down:Connect(function() skipPos(6) end))
table.insert(conns, skip.MouseButton1Up:Connect(function() skipPos(0) end))
table.insert(conns, skip.SelectionGained:Connect(function() skipPos(-2) end))
table.insert(conns, skip.SelectionLost:Connect(function() skipPos(0) end))

-- premium restyle (soft shadows, thin gold rims, glossy fills)
do
	local GOLD, DEEP = Color3.fromRGB(255, 214, 120), Color3.fromRGB(20, 12, 24)
	local function soft(o) for _, st in o:GetChildren() do if st:IsA("UIStroke") then st:Destroy() end end end
	-- logo: thin gold rim + glow halo
	soft(plaque); make("UIStroke", { Color = Color3.fromRGB(255, 236, 170), Thickness = 2, Transparency = 0.1 }, plaque)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 226, 140), Color3.fromRGB(214, 150, 50)) }, plaque)
	base.BackgroundTransparency = 0.55; base.Position = UDim2.fromOffset(0, 10)
	local halo = make("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.7, 1.7), BackgroundTransparency = 1,
		Image = "rbxasset://textures/ui/LuaApp/graphic/shadow_24.png", ImageColor3 = Color3.fromRGB(255, 200, 110), ImageTransparency = 0.35, ScaleType = Enum.ScaleType.Slice, SliceCenter = Rect.new(24, 24, 40, 40), ZIndex = 9 }, plaqueHold)
	for _, r in rays:GetChildren() do if r:IsA("Frame") then r.BackgroundTransparency = 0.7; r.Size = UDim2.new(0, 18, 1, 0) end end
	-- title: warm gradient, soft dark outline
	title.TextColor3 = Color3.new(1, 1, 1); titleStroke.Thickness = 3.5; titleStroke.Color = Color3.fromRGB(60, 22, 18)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 252, 240), Color3.fromRGB(255, 214, 150)) }, title)
	-- stage text: floating white text with shadow (no pill)
	soft(stageLbl); stageLbl.BackgroundTransparency = 1; stageLbl.TextColor3 = Color3.new(1, 1, 1); stageLbl.TextSize = 18
	make("UIStroke", { Color = DEEP, Thickness = 2, Transparency = 0.2 }, stageLbl)
	-- bar: dark glass track, thin gold rim, glossy jade fill with moving shine
	barBase.BackgroundTransparency = 0.6; barBase.Position = UDim2.fromOffset(0, 46); barBase.Size = UDim2.new(1, 0, 0, 22)
	soft(bar); bar.Size = UDim2.new(1, 0, 0, 22); bar.BackgroundColor3 = DEEP; bar.BackgroundTransparency = 0.35; corner(bar, 11)
	for _, c in bar:GetChildren() do if c.Name == "GoldRim" then c:Destroy() end end
	make("UIStroke", { Color = GOLD, Thickness = 1.5, Transparency = 0.15 }, bar)
	fill.BackgroundColor3 = Color3.new(1, 1, 1); fill.Position = UDim2.fromOffset(3, 3); fill.Size = UDim2.new(0.04, -6, 1, -6)
	for _, g in fill:GetChildren() do if g:IsA("UIGradient") then g.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 226, 130)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 150, 70)) }) end end
	local gloss = frame(fill, { Size = UDim2.fromScale(1, 0.45), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.6, ZIndex = 13 }); corner(gloss, 8)
	local sheen = frame(fill, { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 13 }); corner(sheen, 8)
	local sg = make("UIGradient", { Offset = Vector2.new(-1, 0), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) }) }, sheen)
	local sw = TweenService:Create(sg, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1), { Offset = Vector2.new(1, 0) }); table.insert(tweens, sw); sw:Play()
	egg.Position = UDim2.new(0.04, 0, 0, 4); soft(egg); make("UIStroke", { Color = DEEP, Thickness = 2 }, egg)
	-- skip: glassy pill
	skipBase.BackgroundTransparency = 0.6; soft(skipBase); soft(skip)
	skip.BackgroundColor3 = Color3.fromRGB(210, 55, 45)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(255, 120, 90), Color3.fromRGB(190, 40, 35)) }, skip)
	make("UIStroke", { Color = Color3.fromRGB(255, 220, 190), Thickness = 1.5, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, skip)
	make("UIStroke", { Color = DEEP, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual }, skip)
	-- petals softer
	for _, p in petals do if p.p:IsA("Frame") then soft(p.p); p.p.BackgroundTransparency = 0.15 end end
end

-- responsive: desktop / tablet / phone (portrait + wide landscape), device safe areas
-- a probe ScreenGui with DeviceSafeInsets measures notch / home-bar space
local safeGui = make("ScreenGui", { Name = "HatchLoadingSafe", ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets, ResetOnSpawn = false, DisplayOrder = 999 }, playerGui)
local safeProbe = frame(safeGui, { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })
local LOGO_H, BAR_H, GAP = 374, 110, 18 -- design px: plaque + title, stage + bar + tip
local barShown, barY = reduced, -64
local function scaler(o) return o:FindFirstChild("Fit") or make("UIScale", { Name = "Fit" }, o) end
local function layout()
	local cam = workspace.CurrentCamera; if not cam then return end
	local v = root.AbsoluteSize; if v.X < 2 or v.Y < 2 then v = cam.ViewportSize end
	local sz = safeProbe.AbsoluteSize; if sz.X < 2 or sz.Y < 2 then sz = v end
	local padX = math.max(0, (v.X - sz.X) / 2) -- notch, both sides
	local padB = math.max(0, v.Y - sz.Y) -- home indicator (worst case: all at bottom)
	local portrait = v.Y > v.X
	local availW, availH = v.X - padX * 2, v.Y - padB
	fit.Scale = 1
	local sk = math.clamp(math.min(v.X / (portrait and 420 or 1280), v.Y / 720) * 1.1, 0.7, 1.2)
	local top = math.max(10, v.Y * (portrait and 0.08 or 0.035))
	local bottom = portrait and (40 + 52 * sk + 10) or math.max(12, v.Y * 0.04)
	-- scale so logo + bar always fit the height (wide phones are the tight case)
	local s = math.min(v.X / (portrait and 420 or 1280), v.Y / (portrait and 860 or 720), (availH - top - bottom) / (LOGO_H + GAP + BAR_H))
	s = math.clamp(s, 0.32, 1.4)
	-- spread spare height evenly above, between and below
	local spare = math.max(0, availH - top - bottom - (LOGO_H + GAP + BAR_H) * s)
	top += spare * (portrait and 0.25 or 0.2); bottom += spare * (portrait and 0.25 or 0.2)
	local cw = math.min(560, (availW - 24) / s)
	center.Size = UDim2.fromOffset(cw, 380); title.Size = UDim2.fromOffset(cw, 62)
	scaler(center).Scale = s
	center.Position = UDim2.new(0.5, 0, 0, top)
	barBlock.Size = UDim2.fromOffset(math.min(520, (availW - 40) / s), BAR_H)
	scaler(barBlock).Scale = s
	-- keep stage / tip text readable (>= ~12px on screen) when the block is scaled down
	stageLbl.TextSize = math.max(18, 12 / s)
	tipLbl.TextSize = math.max(17, 12 / s); tipLbl.Size = UDim2.new(1, 0, 0, math.max(22, tipLbl.TextSize + 4))
	barY = -(padB + bottom)
	barBlock.Position = UDim2.new(0.5, 0, 1, barShown and barY or barY + 24)
	skipHold.Position = UDim2.new(1, -(padX + 18), 1, -(padB + (portrait and 40 or 18)))
	scaler(skipHold).Scale = sk
	for _, l in lanterns do l.cord.Visible = not portrait or l ~= lanterns[2] end
end
layout()
table.insert(conns, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))
table.insert(conns, safeProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))
table.insert(conns, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(layout))

---------------------------------------------------------------- controls + core gui
local hiddenCore = false
local controls
if Config.HideCoreGui then hiddenCore = pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, false) end) end
if Config.DisableControls then
	task.spawn(function()
		local ok, pm = pcall(function() return require(player:WaitForChild("PlayerScripts", 5):WaitForChild("PlayerModule", 5)) end)
		if ok and pm then controls = pm:GetControls(); if gui.Parent then controls:Disable() end end
	end)
end

---------------------------------------------------------------- entrance (≈1.5 s)
if not reduced then
	tween(reveal, 0.45, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
	for _, d in doors do tween(d.f, 0.45, { Position = UDim2.new(0.5 + d.side * 0.52, 0, 0, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut, 0.35) end
	tween(logoClip, 0.3, { GroupTransparency = 0 }, nil, nil, 0.7)
	tween(logoScale, 0.32, { Scale = 1.08 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0.7).Completed:Once(function()
		if gui.Parent then tween(logoScale, 0.18, { Scale = 1 }, Enum.EasingStyle.Sine) end
	end)
	tween(shineGrad, 0.7, { Offset = Vector2.new(1.3, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut, 1.2)
	tween(title, 0.35, { TextTransparency = 0 }, nil, nil, 1.05); tween(titleStroke, 0.35, { Transparency = 0 }, nil, nil, 1.05)
	task.delay(1.18, function()
		if not gui.Parent then return end
		for _, o in barGroup do o.Visible = true end
		barShown = true
		tween(barBlock, 0.35, { Position = UDim2.new(0.5, 0, 1, barY) }, Enum.EasingStyle.Back)
	end)
else
	for _, o in barGroup do o.Visible = true end
	root.GroupTransparency = 1; tween(root, 0.3, { GroupTransparency = 0 })
end
GuiService.SelectedObject = UserInputService.GamepadEnabled and skip or nil

---------------------------------------------------------------- ambient loop (one connection, 30 Hz)
local t0, acc, tipI, tipT = os.clock(), 0, 1, 0
table.insert(conns, RunService.RenderStepped:Connect(function(dt)
	acc += dt; tipT += dt
	if tipT >= Config.TipSeconds and #Config.Tips > 1 then
		tipT = 0; tipI = tipI % #Config.Tips + 1
		if reduced then tipLbl.Text = Config.Tips[tipI] else
			tween(tipLbl, 0.15, { TextTransparency = 1 }).Completed:Once(function() if gui.Parent then tipLbl.Text = Config.Tips[tipI]; tween(tipLbl, 0.2, { TextTransparency = 0 }) end end)
		end
	end
	if acc < 1 / 30 or reduced then return end
	local t = os.clock() - t0; acc = 0
	far.Position = UDim2.new(-(t / 140) % 1, 0, 0.72, 0)
	mid.Position = UDim2.new(-(t / 90) % 1, 0, 0.78, 0)
	flow.Offset = Vector2.new(((t / 3.5) % 2) - 1, 0)
	for _, s in shrines do s.Rotation = math.sin(t * 0.45) * 0.4 end
	for _, l in lanterns do l.cord.Rotation = math.sin(t * l.speed + l.phase) * 4 end
	if branchL then branchL.Rotation = math.sin(t * 0.6) * 1.2 end
	if branchR then branchR.Rotation = -math.sin(t * 0.55 + 1) * 1.2 end
	egg.Rotation = math.sin(t * 7) * 6
	rays.Rotation = t * 9
	if t > 1.6 then plaqueHold.Position = UDim2.new(0.5, 0, 0, math.sin((t - 1.6) * 1.6) * 6) end
	for _, sp in sparks do local k = ((t - sp.d) % 4.2) / 4.2; local v = (t > sp.d and k > 0.7 and k < 0.9) and math.sin((k - 0.7) / 0.2 * math.pi) or 0; sp.sc.Scale = v; sp.f.Rotation = k * 180 end
	for _, c in clouds do c.f.Position = UDim2.fromScale(((c.x - t * c.speed) % 1.4) - 0.2, c.y) end
	local kk = ((t - 2) % 7) / 7
	koi.Visible = t > 2 and kk > 0.62 and kk < 0.82
	if koi.Visible then local q = (kk - 0.62) / 0.2; koi.Position = UDim2.fromScale(0.44 + q * 0.06, 0.95 - math.sin(q * math.pi) * 0.09); koi.Rotation = -60 + q * 130 end
	for _, p in petals do
		local k = ((t + p.t) % p.dur) / p.dur
		p.p.Position = UDim2.fromScale(1.04 - k * 1.25, p.y + k * 0.48)
		p.p.Rotation = k * p.spin
		p.p.Visible = (t + p.t) > 0
	end
end))

---------------------------------------------------------------- truthful progress
local progress = 0
local function setProgress(v, stage)
	progress = math.max(progress, math.clamp(v, 0, 1))
	if stage then stageLbl.Text = stage end
	local p = math.max(0.04, progress)
	tween(fill, 0.35, { Size = UDim2.new(p, -8, 1, -8) })
	tween(egg, 0.35, { Position = UDim2.new(p, -2, 0, 8) })
end
-- steps weighted: game load 30%, assets 50%, plot 20%
local closing = false
local close -- forward
task.spawn(function()
	setProgress(0.02, "Preparing your temple…")
	-- real loading: session, plot, streaming and every model/visual asset (StartupLoader)
	local loader = ReplicatedFirst:WaitForChild("StartupLoader", 10)
	local ok, err = pcall(function()
		require(loader).Run(player, gui, function(p, msg)
			if closing then return end
			setProgress(p, msg and (msg:sub(-1) == "!" and msg or msg .. "…") or nil)
		end)
	end)
	if not ok then warn("[LoadingScreen] " .. tostring(err)) end
	local wait = Config.MinSeconds - (os.clock() - t0)
	if wait > 0 then task.wait(wait) end
	close(true)
end)

---------------------------------------------------------------- exit (≈0.4 s) + cleanup
close = function(finished)
	if closing then return end
	closing = true -- Keep the loading art opaque until the arrival camera is already in the sky.
 player:SetAttribute("LoadingScreenFinishing",true)
 local arrival=game:GetService("ReplicatedStorage"):FindFirstChild("JoinArrival")
 if arrival and arrival:GetAttribute("Enabled")~=false then
  local deadline=os.clock()+6
  while not player:GetAttribute("JoinArrivalCameraSet") and os.clock()<deadline do
   RunService.RenderStepped:Wait()
  end
 end

	if finished and not reduced then -- egg cracks: two shell halves + one gold sparkle
		local abs = egg.AbsolutePosition - root.AbsolutePosition
		egg.Visible = false
		for _, side in { -1, 1 } do
			local h = frame(root, { Position = UDim2.fromOffset(abs.X + (side < 0 and 0 or 12), abs.Y + 6), Size = UDim2.fromOffset(12, 16), BackgroundColor3 = C.Ivory, ZIndex = 25 }); corner(h, 6); ink(h, 3)
			tween(h, 0.45, { Position = h.Position + UDim2.fromOffset(side * 16, -20), Rotation = side * 70, BackgroundTransparency = 1 })
		end
		local sp = frame(root, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(abs.X + 12, abs.Y + 10), Size = UDim2.fromOffset(4, 18), BackgroundColor3 = C.Gold, ZIndex = 26 })
		frame(sp, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 4), BackgroundColor3 = C.Gold, ZIndex = 26 })
		tween(sp, 0.45, { Rotation = 90, Size = UDim2.fromOffset(1, 4) })
		task.wait(0.45)
	end
	if reduced then
		tween(root, 0.3, { GroupTransparency = 1 })
	else
		reveal.Offset = Vector2.new(-0.5, 0)
		reveal.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.49, 1), NumberSequenceKeypoint.new(0.51, 0), NumberSequenceKeypoint.new(1, 0) })
		tween(reveal, 0.4, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.InOut)
		tween(root, 0.4, { GroupTransparency = 0.3 })
	end
	task.wait(reduced and 0.3 or 0.42)
	for _, c in conns do c:Disconnect() end
	for _, tw in tweens do tw:Cancel() end
	if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then GuiService.SelectedObject = nil end
	gui:Destroy(); safeGui:Destroy()
	player:SetAttribute("LoadingScreenDone", true) -- lets JoinArrival continue
	if hiddenCore and (not player:GetAttribute("JoinArrivalStarted") or player:GetAttribute("JoinArrivalFinished")) then for _ = 1, 5 do if pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All, true) end) then break end task.wait(0.2) end end
	if controls then pcall(function() controls:Enable() end) end
end
table.insert(conns, skip.Activated:Connect(function() task.spawn(close, false) end))
task.delay(Config.MaxSeconds or 180, function() task.spawn(close, false) end) -- hard cap
