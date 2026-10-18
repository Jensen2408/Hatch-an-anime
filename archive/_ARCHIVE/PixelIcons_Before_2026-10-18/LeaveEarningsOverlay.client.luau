-- LeaveEarningsOverlay (LocalScript): when the Roblox menu (Esc) opens, show behind it that the temple keeps earning offline.
-- Offline rate matches PlayerDataService: half of live income, for up to 8 hours.
local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local TS = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local OFFLINE_RATE, OFFLINE_CAP = 0.5, 8 * 3600
local F = Font.new("rbxasset://fonts/families/FredokaOne.json")
local K, W = Color3.new(0, 0, 0), Color3.new(1, 1, 1)
local GLOW = "rbxthumb://type=Asset&id=85372533044428&w=420&h=420"
local RAYS = "rbxthumb://type=Asset&id=110993746998606&w=420&h=420"
local SPARK = "rbxthumb://type=Asset&id=87376394612367&w=420&h=420"
local COINS = "rbxassetid://110158547331194"
local function new(c, p, parent) local o = Instance.new(c) for k, v in p do o[k] = v end o.Parent = parent return o end
local UNITS = { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
local function short(n) n = tonumber(n) or 0 for _, u in UNITS do if n >= u[1] then local v = n / u[1] local s = v < 10 and string.format("%.2f", v) or v < 100 and string.format("%.1f", v) or tostring(math.floor(v + 0.5)) s = s:gsub("%.?0+$", "") return "$" .. s .. u[2] end end return "$" .. tostring(math.floor(n)) end
local function income()
	local total = 0
	local plots = workspace:FindFirstChild("Plots")
	if plots then for _, plot in plots:GetChildren() do if plot:GetAttribute("OwnerUserId") == player.UserId then
		local placed = plot:FindFirstChild("PlacedItems") if placed then for _, m in placed:GetChildren() do total += m:GetAttribute("IncomePerSecond") or 0 end end end end end
	return total * (workspace:GetAttribute("OwnerIncomeMultiplier") or 1)
end

local gui = new("ScreenGui", { Name = "LeaveEarningsOverlay", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 999, Enabled = false }, player:WaitForChild("PlayerGui"))
local bg = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(18, 8, 40), BackgroundTransparency = 1 }, gui)
new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(60, 20, 110), Color3.fromRGB(10, 4, 24)) }, bg)
local rays = new("ImageLabel", { BackgroundTransparency = 1, Image = RAYS, ImageColor3 = Color3.fromRGB(255, 210, 90), ImageTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.16), Size = UDim2.fromOffset(900, 900) }, gui)
local halo = new("ImageLabel", { BackgroundTransparency = 1, Image = GLOW, ImageColor3 = Color3.fromRGB(255, 200, 60), ImageTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.13), Size = UDim2.fromOffset(620, 300) }, gui)
local top = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(900, 170) }, gui)
local scale = new("UIScale", {}, top)
local function txt(s, y, size, color, th)
	local l = new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, size + 8), Text = s, FontFace = F, TextSize = size, TextColor3 = color, TextTransparency = 1 }, top)
	local st = new("UIStroke", { Color = K, Thickness = th, Transparency = 1, LineJoinMode = Enum.LineJoinMode.Round }, l)
	return l, st
end
local t1, s1 = txt("🌙  YOUR TEMPLE KEEPS EARNING!", 0, 44, W, 5)
local t2, s2 = txt("$0/s while you're away", 58, 34, Color3.fromRGB(130, 255, 110), 4)
local t3, s3 = txt("Come back to collect up to $0  ·  max 8 hours", 104, 22, Color3.fromRGB(255, 225, 150), 3)
local g1 = new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 214, 72)), ColorSequenceKeypoint.new(0.5, W), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 140, 220)) }) }, t1)
local rain = new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true }, gui)

local open, conn = false, nil
local function fade(on)
	local t = TweenInfo.new(0.35, Enum.EasingStyle.Quad)
	TS:Create(bg, t, { BackgroundTransparency = on and 0.25 or 1 }):Play()
	TS:Create(rays, t, { ImageTransparency = on and 0.55 or 1 }):Play()
	TS:Create(halo, t, { ImageTransparency = on and 0.3 or 1 }):Play()
	for _, x in { t1, t2, t3 } do TS:Create(x, t, { TextTransparency = on and 0 or 1 }):Play() end
	for _, x in { s1, s2, s3 } do TS:Create(x, t, { Transparency = on and 0 or 1 }):Play() end
end
local function coin()
	local sz = math.random(26, 54)
	local img = math.random() < 0.75 and COINS or SPARK
	local c = new("ImageLabel", { BackgroundTransparency = 1, Image = img, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(math.random(), 0, 0, -60), Size = UDim2.fromOffset(sz, sz), Rotation = math.random(-40, 40), ImageTransparency = img == SPARK and 0.2 or 0 }, rain)
	local dur = 3 + math.random() * 2.5
	TS:Create(c, TweenInfo.new(dur, Enum.EasingStyle.Linear), { Position = c.Position + UDim2.new((math.random() - 0.5) * 0.1, 0, 1.15, 0), Rotation = c.Rotation + math.random(-180, 180) }):Play()
	task.delay(dur, function() c:Destroy() end)
end
local function show()
	if open then return end open = true
	local rate = income() * OFFLINE_RATE
	t2.Text = short(rate) .. "/s while you're away"
	t3.Text = "Come back to collect up to " .. short(rate * OFFLINE_CAP) .. "  ·  max 8 hours"
	if rate <= 0 then t2.Text = "Place characters on your stands" t3.Text = "...and they earn cash for you even while you're offline!" end
	scale.Scale = math.clamp(workspace.CurrentCamera.ViewportSize.X / 960, 0.5, 1.1)
	gui.Enabled = true fade(true)
	scale.Scale *= 0.85 TS:Create(scale, TweenInfo.new(0.45, Enum.EasingStyle.Back), { Scale = scale.Scale / 0.85 }):Play()
	local acc, t0 = 0, os.clock()
	conn = RunService.RenderStepped:Connect(function(dt)
		rays.Rotation += dt * 8
		g1.Offset = Vector2.new(math.sin((os.clock() - t0) * 1.5) * 0.4, 0)
		halo.Size = UDim2.fromOffset(620 + math.sin(os.clock() * 2) * 40, 300 + math.sin(os.clock() * 2) * 20)
		acc += dt if acc > 0.12 then acc = 0 coin() end
	end)
end
local function hide()
	if not open then return end open = false
	fade(false)
	if conn then conn:Disconnect() conn = nil end
	task.delay(0.4, function() if not open then gui.Enabled = false rain:ClearAllChildren() end end)
end
GuiService.MenuOpened:Connect(show)
GuiService.MenuClosed:Connect(hide)
