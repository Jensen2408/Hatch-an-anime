--[[ ReplicatedStorage.StolenEggBanner  (ModuleScript, client)
Top-centre "RETURN TO BASE!" banner for the player carrying a stolen egg.
Driven ONLY by server events. The server keeps validation and rewards; this file is cosmetic.

Server → client RemoteEvent: ReplicatedStorage.StealEvents.StealState
  FireClient(player, "Stolen",    { basePosition = Vector3 })   -- player picked up an egg
  FireClient(player, "Secured",   {})                            -- server confirmed delivery
  FireClient(player, "Dropped",   {})                            -- caught / dropped / timed out
  FireClient(player, "Cancelled", {})                            -- owner left, egg reset, etc.
If your stealing system already fires different events, call Banner.Show / Banner.Resolve from those instead.

Start once from a LocalScript:  require(ReplicatedStorage.StolenEggBanner).Start()
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Banner = {}
local player = Players.LocalPlayer

local Config = {
	-- Sound slots. These must be real Creator Store assets you've checked can be used in your experience.
	-- No IDs are filled in here on purpose; see README.
	AlertSound = "rbxasset://sounds/electronicpingshort.wav",      -- short theft-alert chime when the steal starts
	SuccessSound = "rbxasset://sounds/victory.wav",    -- chime on EGG SECURED!
	FailSound = "",       -- optional soft sound on dropped / cancelled
	Volume = 0.35,
	SoundGroupName = "SFX", -- if SoundService has a SoundGroup with this name, sounds use it (respects your volume settings)
	MuteAttribute = "SFXMuted", -- player attribute that silences these sounds
	ReducedMotionAttribute = "ReducedMotion",
	FontHeading = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Regular),
	FontBody = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium),
	DismissAfter = { Secured = 1.7, Dropped = 1.8, Cancelled = 1.6 },
}
Banner.Config = Config

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local THEMES = {
	Stolen = { frame = rgb(142, 26, 34), hi = rgb(196, 58, 60), lo = rgb(90, 12, 19), stud = rgb(181, 42, 47), cav = rgb(60, 7, 12), side = rgb(116, 18, 25), inset = rgb(58, 10, 15), egg = rgb(232, 50, 60), sub = rgb(255, 214, 207) },
	Secured = { frame = rgb(31, 122, 58), hi = rgb(63, 179, 92), lo = rgb(15, 74, 34), stud = rgb(47, 154, 74), cav = rgb(10, 47, 21), side = rgb(24, 101, 48), inset = rgb(12, 46, 23), egg = rgb(67, 196, 99), sub = rgb(212, 247, 218) },
	Failed = { frame = rgb(75, 79, 90), hi = rgb(116, 122, 136), lo = rgb(43, 46, 53), stud = rgb(93, 98, 110), cav = rgb(26, 28, 33), side = rgb(62, 66, 75), inset = rgb(31, 33, 39), egg = rgb(154, 160, 172), sub = rgb(225, 228, 234) },
}
local COPY = {
	Stolen = { "RETURN TO BASE!", "Bring the stolen egg home to secure it." },
	Secured = { "EGG SECURED!", "Nice! The egg is safe in your base." },
	Dropped = { "EGG DROPPED!", "You did not secure the egg." },
	Cancelled = { "STEAL CANCELLED", "The steal has ended." },
}
local OUTLINE, GOLD = rgb(20, 5, 7), rgb(214, 164, 67)

---------------------------------------------------------------- build helpers
local function make(class, props, parent) local o = Instance.new(class); for k, v in props do o[k] = v end; o.Parent = parent; return o end
local function corner(p, r) return make("UICorner", { CornerRadius = UDim.new(0, r) }, p) end
local function tween(o, t, props, style, dir) local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props); tw:Play(); return tw end
-- Bevel = 1-2 px strips (crisp at any scale, unlike a stretched texture)
local function bevel(p, hiColor, loColor, hiT, loT, z)
	local top = make("Frame", { Name = "BevelTop", Size = UDim2.new(1, -6, 0, 3), Position = UDim2.fromOffset(3, 0), BackgroundColor3 = hiColor, BackgroundTransparency = hiT or 0, BorderSizePixel = 0, ZIndex = z }, p)
	local bot = make("Frame", { Name = "BevelBottom", Size = UDim2.new(1, -6, 0, 4), Position = UDim2.new(0, 3, 1, -4), BackgroundColor3 = loColor, BackgroundTransparency = loT or 0, BorderSizePixel = 0, ZIndex = z }, p)
	return top, bot
end
local function stud(parent, theme, order)
	local s = make("Frame", { Name = "Stud", LayoutOrder = order, Size = UDim2.fromOffset(10, 10), BackgroundColor3 = theme.stud, BorderSizePixel = 0, ZIndex = 4 }, parent)
	corner(s, 2)
	make("Frame", { Name = "Highlight", Size = UDim2.new(1, -2, 0, 2), Position = UDim2.fromOffset(1, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.58, BorderSizePixel = 0, ZIndex = 5 }, s)
	make("Frame", { Name = "Shade", Size = UDim2.new(1, -2, 0, 2), Position = UDim2.new(0, 1, 1, -2), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.78, BorderSizePixel = 0, ZIndex = 5 }, s)
	make("Frame", { Name = "Cavity", Size = UDim2.new(1, 0, 0, 2), Position = UDim2.new(0, 0, 1, 0), BackgroundColor3 = theme.cav, BorderSizePixel = 0, ZIndex = 4 }, s)
	return s
end
local function pixelShape(parent, rows, colorFor, px, z)
	local h = #rows
	local w = #rows[1]
	local f = make("Frame", { Name = "Pixels", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w * px, h * px), BackgroundTransparency = 1, ZIndex = z }, parent)
	for r = 1, h do for c = 1, w do
		local ch = rows[r]:sub(c, c)
		if ch ~= "." then make("Frame", { Name = "P", Position = UDim2.fromOffset((c - 1) * px, (r - 1) * px), Size = UDim2.fromOffset(px, px), BackgroundColor3 = colorFor(ch), BorderSizePixel = 0, ZIndex = z }, f) end
	end end
	return f
end

---------------------------------------------------------------- the banner
local gui, ui, current
local function build()
	gui = make("ScreenGui", { Name = "StolenEggBanner", ResetOnSpawn = false, IgnoreGuiInset = false, DisplayOrder = 20, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, Enabled = false }, player:WaitForChild("PlayerGui"))
	local W, H = 540, 124
	local holder = make("Frame", { Name = "Holder", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, -H - 20), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1 }, gui)
	local scale = make("UIScale", {}, holder)
	local pop = make("Frame", { Name = "Pop", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, holder)
	local popScale = make("UIScale", {}, pop)
	-- outline + contact shadow
	local shadow = make("Frame", { Name = "ContactShadow", Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = OUTLINE, BorderSizePixel = 0, ZIndex = 1 }, pop)
	corner(shadow, 12)
	local pulse = make("UIStroke", { Name = "Pulse", Color = rgb(255, 96, 80), Thickness = 0, Transparency = 1 }, shadow)
	local outline = make("Frame", { Name = "Outline", Size = UDim2.fromScale(1, 1), BackgroundColor3 = OUTLINE, BorderSizePixel = 0, ZIndex = 1 }, pop)
	corner(outline, 12)
	local frame = make("Frame", { Name = "Frame", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6), BorderSizePixel = 0, ZIndex = 2, ClipsDescendants = true }, pop)
	corner(frame, 9)
	local fTop, fBot = bevel(frame, Color3.new(), Color3.new(), 0, 0, 3)
	-- stud row
	local studs = make("Frame", { Name = "Studs", Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -28, 0, 12), BackgroundTransparency = 1, ZIndex = 4 }, frame)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, HorizontalFlex = Enum.UIFlexAlignment.SpaceBetween, SortOrder = Enum.SortOrder.LayoutOrder }, studs)
	local studList = {}
	-- sides + inset
	local row = make("Frame", { Name = "Row", Position = UDim2.fromOffset(10, 25), Size = UDim2.new(1, -20, 1, -42), BackgroundTransparency = 1, ZIndex = 3 }, frame)
	local function side(name, x, w)
		local s = make("Frame", { Name = name, Position = UDim2.new(x, x == 1 and -w or 0, 0, 0), Size = UDim2.new(0, w, 1, 0), BorderSizePixel = 0, ZIndex = 3 }, row)
		corner(s, 6)
		local t, b = bevel(s, Color3.new(1, 1, 1), Color3.new(), 0.8, 0, 4)
		return s, b
	end
	local left, leftLo = side("Emblem", 0, 58)
	local right, rightLo = side("Compass", 1, 64)
	local inset = make("Frame", { Name = "Inset", Position = UDim2.fromOffset(66, 0), Size = UDim2.new(1, -138, 1, 0), BorderSizePixel = 0, ZIndex = 3, ClipsDescendants = true }, row)
	corner(inset, 6)
	make("UIStroke", { Color = GOLD, Transparency = 0.55, Thickness = 1.5 }, inset)
	make("Frame", { Name = "InnerShadow", Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 4 }, inset)
	local shine = make("Frame", { Name = "Shine", Size = UDim2.fromScale(1, 1), BackgroundColor3 = rgb(255, 244, 214), BorderSizePixel = 0, ZIndex = 5 }, inset)
	local shineGrad = make("UIGradient", { Rotation = 20, Offset = Vector2.new(-1.4, 0), Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.62), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }) }, shine)
	local title = make("TextLabel", { Name = "Title", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 9), Size = UDim2.new(1, -24, 0, 34), BackgroundTransparency = 1, FontFace = Config.FontHeading, TextColor3 = Color3.new(1, 1, 1), TextScaled = true, ZIndex = 7 }, inset)
	make("UITextSizeConstraint", { MaxTextSize = 31, MinTextSize = 20 }, title)
	make("UIStroke", { Color = OUTLINE, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round }, title)
	local titleShadow = make("TextLabel", { Name = "TitleShadow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 12), Size = UDim2.new(1, -24, 0, 34), BackgroundTransparency = 1, FontFace = Config.FontHeading, TextColor3 = OUTLINE, TextScaled = true, ZIndex = 6 }, inset)
	make("UITextSizeConstraint", { MaxTextSize = 31, MinTextSize = 20 }, titleShadow)
	make("UIStroke", { Color = OUTLINE, Thickness = 3, LineJoinMode = Enum.LineJoinMode.Round }, titleShadow)
	local sub = make("TextLabel", { Name = "Sub", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.new(1, -24, 0, 16), BackgroundTransparency = 1, FontFace = Config.FontBody, TextScaled = true, ZIndex = 7 }, inset)
	make("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 10 }, sub)
	-- emblem: blocky egg
	local slot = make("Frame", { Name = "Slot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(38, 38), BackgroundColor3 = rgb(26, 11, 13), BorderSizePixel = 0, ZIndex = 4 }, left)
	corner(slot, 7); make("UIStroke", { Color = GOLD, Thickness = 2 }, slot)
	local eggPix = {}
	local eggShape = pixelShape(slot, { "..ww..", ".wwww.", "bbbbbb", "cccccc", ".cccc.", "..dd.." }, function(ch)
		return ch == "w" and rgb(255, 246, 228) or ch == "c" and rgb(244, 230, 200) or ch == "d" and rgb(216, 194, 148) or Color3.new() end, 4, 5)
	for _, px in eggShape:GetChildren() do if px.Position.Y.Offset == 8 then table.insert(eggPix, px) end end
	-- compass: arrow + distance / check / cross
	local dial = make("Frame", { Name = "Dial", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(32, 32), BackgroundColor3 = rgb(26, 11, 13), BorderSizePixel = 0, ZIndex = 4 }, right)
	corner(dial, 16); make("UIStroke", { Color = GOLD, Thickness = 2 }, dial)
	local arrow = pixelShape(dial, { "..yy..", ".yyyy.", "yyyyyy", "..gg..", "..gg..", "..gg.." }, function(ch) return ch == "y" and rgb(255, 233, 168) or rgb(255, 211, 106) end, 3, 5)
	local check = pixelShape(dial, { ".....g", "....g.", "g..g..", ".gg..." }, function() return rgb(143, 240, 160) end, 4, 5)
	local cross = pixelShape(dial, { "r..r", ".rr.", ".rr.", "r..r" }, function() return rgb(255, 143, 143) end, 4, 5)
	local dist = make("TextLabel", { Name = "Distance", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 46), Size = UDim2.new(1, -6, 0, 16), BackgroundTransparency = 1, FontFace = Config.FontBody, TextColor3 = rgb(255, 243, 220), TextScaled = true, Text = "", ZIndex = 5 }, right)
	make("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 9 }, dist)
	make("UIStroke", { Color = OUTLINE, Thickness = 1.5 }, dist)
	local trim = make("Frame", { Name = "GoldTrim", Position = UDim2.new(0, 6, 1, -10), Size = UDim2.new(1, -12, 0, 3), BackgroundColor3 = GOLD, BorderSizePixel = 0, ZIndex = 4 }, frame)
	corner(trim, 2)
	make("Frame", { Name = "TrimShade", Position = UDim2.new(0, 0, 1, 0), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = rgb(58, 37, 8), BorderSizePixel = 0, ZIndex = 4 }, trim)

	ui = { holder = holder, scale = scale, popScale = popScale, frame = frame, fTop = fTop, fBot = fBot, studs = studs, studList = studList,
		left = left, right = right, leftLo = leftLo, rightLo = rightLo, inset = inset, title = title, titleShadow = titleShadow, sub = sub,
		shineGrad = shineGrad, eggPix = eggPix, arrow = arrow, check = check, cross = cross, dist = dist, dial = dial, pulse = pulse, H = H }
	-- studs (re-themed in place)
	for i = 1, 22 do table.insert(studList, stud(studs, THEMES.Stolen, i)) end
	-- responsive scale (PC + mobile)
	local function fit()
		local cam = workspace.CurrentCamera
		if not cam then return end
		local vp = cam.ViewportSize
		scale.Scale = math.clamp(math.min(vp.Y / 760, (vp.X - 24) / 540), 0.3, 1)
	end
	fit()
	local cameraConn
 local function hookCamera()
  if cameraConn then cameraConn:Disconnect() end
  local cam=workspace.CurrentCamera
  if cam then cameraConn=cam:GetPropertyChangedSignal("ViewportSize"):Connect(fit) end
  fit()
 end
 hookCamera()
 workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(hookCamera)
end

local function applyTheme(name, t)
	local th = THEMES[name]
	local props = function(o, p) if t > 0 then tween(o, t, p) else for k, v in p do o[k] = v end end end
	props(ui.frame, { BackgroundColor3 = th.frame }); props(ui.fTop, { BackgroundColor3 = th.hi }); props(ui.fBot, { BackgroundColor3 = th.lo })
	props(ui.left, { BackgroundColor3 = th.side }); props(ui.right, { BackgroundColor3 = th.side }); props(ui.leftLo, { BackgroundColor3 = th.lo }); props(ui.rightLo, { BackgroundColor3 = th.lo })
	props(ui.inset, { BackgroundColor3 = th.inset }); props(ui.sub, { TextColor3 = th.sub })
	for _, s in ui.studList do props(s, { BackgroundColor3 = th.stud }); props(s.Cavity, { BackgroundColor3 = th.cav }) end
	for _, px in ui.eggPix do props(px, { BackgroundColor3 = th.egg }) end
end

local function playSound(id)
	if not id or id == "" or player:GetAttribute(Config.MuteAttribute) then return end
	local s = make("Sound", { SoundId = id, Volume = Config.Volume }, gui)
	local grp = SoundService:FindFirstChild(Config.SoundGroupName)
	if grp and grp:IsA("SoundGroup") then s.SoundGroup = grp end
	s.Ended:Once(function() s:Destroy() end)
	s:Play()
	task.delay(6, function() if s.Parent then s:Destroy() end end)
end

local function reduced() return player:GetAttribute(Config.ReducedMotionAttribute) == true end

---------------------------------------------------------------- arrow tracking (only while stolen)
local trackConn, pulseTween
local function stopTracking()
	if trackConn then trackConn:Disconnect(); trackConn = nil end
	if pulseTween then pulseTween:Cancel(); pulseTween = nil end
	ui.pulse.Thickness, ui.pulse.Transparency = 0, 1
end
local function startTracking(basePos)
	stopTracking()
	local acc = 0
	trackConn = RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc < 1 / 20 then return end
		acc = 0
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local cam = workspace.CurrentCamera
		if not hrp or not cam then return end
		local to = basePos - hrp.Position
		local flat = Vector3.new(to.X, 0, to.Z)
		local look = Vector3.new(cam.CFrame.LookVector.X, 0, cam.CFrame.LookVector.Z)
		if flat.Magnitude > 0.1 and look.Magnitude > 0.01 then
			local a = math.atan2(look.Unit:Cross(flat.Unit).Y, look.Unit:Dot(flat.Unit))
			ui.arrow.Rotation = -math.deg(a)
		end
		ui.dist.Text = string.format("%d studs", math.floor(flat.Magnitude + 0.5))
	end)
	if not reduced() then
		ui.pulse.Transparency = 0.7
		pulseTween = TweenService:Create(ui.pulse, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true, 0.4), { Thickness = 4, Transparency = 0.45 })
		pulseTween:Play()
	end
end

---------------------------------------------------------------- public API
local token = 0
local function slideIn()
	gui.Enabled = true
	local h = ui.holder
	if reduced() then h.Position = UDim2.new(0.5, 0, 0, 14); return end
	h.Position = UDim2.new(0.5, 0, 0, -ui.H - 20)
	local expected = token
	local down = tween(h, 0.32, { Position = UDim2.new(0.5, 0, 0, 22) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	down.Completed:Once(function(state)
		if state ~= Enum.PlaybackState.Completed or expected ~= token then return end
		tween(h, 0.2, { Position = UDim2.new(0.5, 0, 0, 14) }, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)
	end)
end
local function shineOnce(delay)
	if reduced() then return end
	local expected = token
	task.delay(delay, function()
		if expected ~= token or not gui.Enabled then return end
		ui.shineGrad.Offset = Vector2.new(-1.4, 0)
		tween(ui.shineGrad, 0.7, { Offset = Vector2.new(1.4, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
	end)
end
local function setText(state)
	local c = COPY[state]
	ui.title.Text, ui.titleShadow.Text, ui.sub.Text = c[1], c[1], c[2]
	ui.arrow.Visible = state == "Stolen"
	ui.dist.Visible = state == "Stolen"
	ui.check.Visible = state == "Secured"
	ui.cross.Visible = state == "Dropped" or state == "Cancelled"
end

function Banner.Show(basePosition)
 if current == "Stolen" and gui.Enabled then
  if typeof(basePosition) == "Vector3" then startTracking(basePosition) end
  return
 end
 token += 1
	local wasShown = current == "Stolen"
	current = "Stolen"
	setText("Stolen")
	applyTheme("Stolen", 0)
	ui.popScale.Scale = 1
	if not wasShown or not gui.Enabled then slideIn() end -- duplicate events don't replay the slide
	shineOnce(0.5)
	playSound(Config.AlertSound)
	if typeof(basePosition) == "Vector3" then startTracking(basePosition) else ui.dist.Text = "" end
end

function Banner.Resolve(state) -- "Secured" | "Dropped" | "Cancelled"
	if not COPY[state] or state == "Stolen" then return end
	if not current then return end -- nothing on screen: ignore stray events
	token += 1
	local my = token
	current = state
	stopTracking()
	setText(state)
	applyTheme(state == "Secured" and "Secured" or "Failed", 0.3)
	if not reduced() then
		ui.popScale.Scale = 1
		local up = tween(ui.popScale, 0.12, { Scale = 1.06 })
		up.Completed:Once(function() tween(ui.popScale, 0.22, { Scale = 1 }) end)
	end
	if state == "Secured" then shineOnce(0.05); playSound(Config.SuccessSound) else playSound(Config.FailSound) end
	task.delay(Config.DismissAfter[state] or 1.6, function()
		if my ~= token then return end
		Banner.Hide()
	end)
end

function Banner.Hide()
	token += 1
	local my = token
	stopTracking()
	current = nil
	if not gui.Enabled then return end
	if reduced() then gui.Enabled = false; return end
	local tw = tween(ui.holder, 0.38, { Position = UDim2.new(0.5, 0, 0, -ui.H - 20) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	tw.Completed:Once(function() if my == token then gui.Enabled = false end end)
end

local started = false
function Banner.Start()
	if started then return end
	started = true
	build()
	-- Existing EggStealClient translates the game's server messages into this API.
 player.CharacterRemoving:Connect(function() if current == "Stolen" then Banner.Hide() end end)
end

return Banner

