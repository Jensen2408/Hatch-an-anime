--[[ StarterPlayerScripts.NighttimeHUD
Top-centre Nighttime indicator + announcements. Reads the server's workspace attributes
(NighttimeActive / NighttimeEndsAt / NighttimeNextAt) and server time, so every player is in sync.
States: countdown pill -> (last 10s) expanded "APPROACHING" -> big start card -> active bar -> "DAYLIGHT RETURNS" -> countdown.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer

local INDIGO, VIOLET, CYAN, GOLD, MOON = Color3.fromRGB(24, 22, 58), Color3.fromRGB(128, 104, 220), Color3.fromRGB(140, 222, 255), Color3.fromRGB(242, 190, 85), Color3.fromRGB(235, 238, 255)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local DURATION = 20

local function make(c, p, parent) local o = Instance.new(c); for k, v in p do o[k] = v end; if parent then o.Parent = parent end; return o end
local function tw(o, t, props, style) local x = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props); x:Play(); return x end

local gui = make("ScreenGui", { Name = "NighttimeHUD", ResetOnSpawn = false, DisplayOrder = 40, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))

local function panel(name, size)
	local f = make("CanvasGroup", { Name = name, AnchorPoint = Vector2.new(1, 0), Size = size, BackgroundColor3 = INDIGO, BorderSizePixel = 0, GroupTransparency = 1, Visible = false }, gui)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, f)
	-- soft top sheen as its own layer (a UIGradient on a CanvasGroup would tint the text too)
	local sheen = make("Frame", { Size = UDim2.fromScale(1, 0.5), BackgroundColor3 = Color3.fromRGB(70, 62, 140), BackgroundTransparency = 0.55, BorderSizePixel = 0, ZIndex = 0 }, f)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, sheen)
	local st = make("UIStroke", { Color = VIOLET, Thickness = 1.5, Transparency = 0.15 }, f)
	return f, st
end
local function label(parent, text, size, color, props)
	local l = make("TextLabel", { BackgroundTransparency = 1, FontFace = FONT, TextSize = size, TextColor3 = color, Text = text }, parent)
	for k, v in props or {} do l[k] = v end
	return l
end

-- compact pill (countdown / active)
local pill = panel("Pill", UDim2.fromOffset(250, 40))
local moon = make("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 12, 0.5, -2), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = MOON }, pill)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, moon)
local bite = make("Frame", { Position = UDim2.fromOffset(7, -3), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = Color3.fromRGB(40, 35, 92) }, moon) -- crescent
make("UICorner", { CornerRadius = UDim.new(1, 0) }, bite)
local pillText = label(pill, "", 17, MOON, { Position = UDim2.new(0, 40, 0, 0), Size = UDim2.new(1, -52, 1, -6), TextXAlignment = Enum.TextXAlignment.Left })
local pillBonus = label(pill, "2× CASH • 2× HATCH • 2× LUCK", 11, CYAN, { Position = UDim2.new(0, 40, 0, 22), Size = UDim2.new(1, -52, 0, 12), TextXAlignment = Enum.TextXAlignment.Left, Visible = false })
local track = make("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -4), Size = UDim2.new(1, -24, 0, 3), BackgroundColor3 = Color3.fromRGB(60, 56, 120), BorderSizePixel = 0 }, pill)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
local bar = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = CYAN, BorderSizePixel = 0 }, track)
make("UICorner", { CornerRadius = UDim.new(1, 0) }, bar)
local barGrad = make("UIGradient", { Color = ColorSequence.new(CYAN, VIOLET) }, bar)
local goldDot = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -12, 0.5, -2), Size = UDim2.fromOffset(5, 5), Rotation = 45, BackgroundColor3 = GOLD, BorderSizePixel = 0 }, pill)
local pillScale = make("UIScale", {}, pill); make("UIScale", {}, gui):Destroy()

-- big announcement
local big, bigStroke = panel("Announcement", UDim2.fromOffset(330, 104))
local bigScale = make("UIScale", {}, big)
local bigTitle = label(big, "", 26, MOON, { Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 40) })
local bigSub = label(big, "", 16, GOLD, { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 20) })
local bigBonus = label(big, "", 12, CYAN, { Position = UDim2.fromOffset(0, 82), Size = UDim2.new(1, 0, 0, 18) })
for _, x in { 0.08, 0.92 } do make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(x, 0.3), Size = UDim2.fromOffset(6, 6), Rotation = 45, BackgroundColor3 = GOLD, BorderSizePixel = 0 }, big) end
make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 52), Size = UDim2.fromOffset(120, 1), BackgroundColor3 = GOLD, BackgroundTransparency = 0.4, BorderSizePixel = 0 }, big)

-- ScreenGui already excludes the top bar and hardware safe area.
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
local function layout()
	local v = gui.AbsoluteSize
	if v.X <= 0 or v.Y <= 0 then return end
	local s = math.min(1, v.X / 600, v.Y / 560)
	pillScale.Scale = s; bigScale.Scale = s
	pill.Position = UDim2.new(1, -10, 0, 10)
	big.Position = UDim2.new(1, -10, 0, 10)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
layout()

local function show(f, on, t)
	if on then f.Visible = true end
	local x = tw(f, t or 0.35, { GroupTransparency = on and 0 or 1 })
	if not on then x.Completed:Once(function() if f.GroupTransparency > 0.99 then f.Visible = false end end) end
end
local function setPill(w, h)
	tw(pill, 0.35, { Size = UDim2.fromOffset(w, h) })
end

local function fmt(sec) sec = math.max(0, math.ceil(sec)); return string.format("%02d:%02d", sec // 60, sec % 60) end

local mode -- "countdown" | "approach" | "active" | nil
local function setMode(m)
	if m == mode then return end
	local prev = mode; mode = m
	if m == "countdown" then
		if prev == "active" then -- daylight returns transition
			bigTitle.Text = "DAYLIGHT RETURNS"; bigTitle.TextColor3 = Color3.fromRGB(255, 226, 160)
			bigSub.Text = "Bonuses have ended"; bigBonus.Text = ""
			show(pill, false, 0.25); big.Position = big.Position - UDim2.fromOffset(0, 10); show(big, true, 0.35)
			tw(big, 0.4, { Position = big.Position + UDim2.fromOffset(0, 10) })
			task.delay(2.2, function() if mode == "countdown" then show(big, false, 0.4); task.delay(0.3, function() if mode == "countdown" then show(pill, true) end end) end end)
		else
			show(big, false); show(pill, true)
		end
		pillBonus.Visible = false; setPill(250, 40); goldDot.Visible = true
	elseif m == "approach" then
		show(pill, false, 0.25)
		bigTitle.Text = "NIGHTTIME APPROACHING"; bigTitle.TextColor3 = MOON
		bigBonus.Text = "2× CASH  •  2× HATCH SPEED  •  2× RIVER LUCK"
		big.Position = big.Position - UDim2.fromOffset(0, 12); show(big, true, 0.4)
		tw(big, 0.45, { Position = big.Position + UDim2.fromOffset(0, 12) })
	elseif m == "active" then
		bigTitle.Text = "NIGHTTIME"; bigTitle.TextColor3 = MOON
		bigSub.Text = DURATION .. " SECONDS OF DOUBLE REWARDS"
		bigBonus.Text = "2× CASH  •  2× HATCH SPEED  •  2× RIVER LUCK"
		local fresh = prev == "approach" or prev == "countdown"
		local now = workspace:GetServerTimeNow()
		local left = (workspace:GetAttribute("NighttimeEndsAt") or now) - now
		pillBonus.Visible = true; goldDot.Visible = false; setPill(270, 52)
		if fresh and left > DURATION - 3 then
			show(pill, false, 0.2); show(big, true, 0.3)
			bigScale.Scale = bigScale.Scale * 1.06; tw(bigScale, 0.5, { Scale = bigScale.Scale / 1.06 }, Enum.EasingStyle.Back)
			task.delay(2.6, function() if mode == "active" then show(big, false, 0.45); task.delay(0.25, function() if mode == "active" then show(pill, true) end end) end end)
		else -- joined mid-event: go straight to the compact bar
			show(big, false, 0.2); show(pill, true)
		end
	end
end

local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt; if acc < 0.05 then return end; acc = 0
	local now = workspace:GetServerTimeNow()
	local active = workspace:GetAttribute("NighttimeActive") == true
	local nextAt = workspace:GetAttribute("NighttimeNextAt") or (math.floor(now / 300) + 1) * 300
	if active then
		local left = math.max(0, (workspace:GetAttribute("NighttimeEndsAt") or now) - now)
		setMode("active")
		pillText.Text = "NIGHTTIME • " .. fmt(left)
		pillText.Size = UDim2.new(1, -52, 0, 24); pillText.Position = UDim2.fromOffset(40, 2)
		bar.Size = UDim2.fromScale(math.clamp(left / DURATION, 0, 1), 1)
	else
		local untilNight = nextAt - now
		if untilNight <= 10 and untilNight > 0 then
			setMode("approach")
			bigSub.Text = "Begins in " .. math.ceil(untilNight) .. "s"
			bigStroke.Thickness = untilNight <= 3 and (1.5 + math.abs(math.sin(now * math.pi)) * 2) or 1.5
			if untilNight <= 3 then bigScale.Scale = pillScale.Scale * (1 + math.abs(math.sin(now * math.pi)) * 0.025) end
		else
			setMode("countdown")
			pillText.Text = "NIGHTTIME IN " .. fmt(untilNight)
			pillText.Size = UDim2.new(1, -52, 1, -6); pillText.Position = UDim2.fromOffset(40, 0)
			bar.Size = UDim2.fromScale(math.clamp(1 - untilNight / (300 - DURATION), 0, 1), 1)
		end
	end
end)
