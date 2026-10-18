-- Cash display: panel + coin art from ReplicatedStorage.GameMenuImages (CashPanel / CashCoin),
-- smooth count, +$ popups, coin bounce, shine sweep, income per second.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local gui = script.Parent
local money = gui.Money
local face = money.Face
local amount = face.Amount
local sweep = face.Shine.Sweep
local coinBox = money.CoinBox
local coinScale = coinBox.UIScale
local panelScale = money.UIScale
local incomeText = face.Income.Text
local pops = money.Popups
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json", Enum.FontWeight.Bold)
local INK = Color3.fromRGB(40, 24, 18)

local UNITS = { { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
local function short(n)
	for _, u in UNITS do
		if n >= u[1] then
			local v = n / u[1]
			local s = v < 10 and ("%.2f"):format(v) or v < 100 and ("%.1f"):format(v) or tostring(math.floor(v))
			s = s:gsub("%.?0+$", "")
			return s .. u[2]
		end
	end
	return tostring(math.floor(n))
end
local function full(n) local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse(); return (s:gsub("^,", "")) end
local function fmt(n) return "$" .. (n < 1e5 and full(n) or short(n)) end
local function tw(o, t, p, s, d) local x = TweenService:Create(o, TweenInfo.new(t, s or Enum.EasingStyle.Quad, d or Enum.EasingDirection.Out), p) x:Play() return x end

local images = RS:WaitForChild("GameMenuImages", 10)
local function setArt()
	if not images then return end
	money.Image = images:GetAttribute("CashPanel") or ""
	local c = images:GetAttribute("CashCoin") or ""
	coinBox.Coin.Image = c; coinBox.CoinShadow.Image = c
end
if images then
	images:GetAttributeChangedSignal("CashPanel"):Connect(setArt)
	images:GetAttributeChangedSignal("CashCoin"):Connect(setArt)
end
setArt()

local function shine()
	sweep.Offset = Vector2.new(-1.5, 0)
	tw(sweep, 0.7, { Offset = Vector2.new(1.5, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
end

local function popup(delta)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1; l.FontFace = FONT; l.TextSize = 26; l.ZIndex = 21
	l.Text = (delta > 0 and "+" or "-") .. fmt(math.abs(delta))
	l.TextColor3 = delta > 0 and Color3.fromRGB(120, 245, 110) or Color3.fromRGB(255, 95, 80)
	l.AutomaticSize = Enum.AutomaticSize.XY; l.Size = UDim2.new()
	l.AnchorPoint = Vector2.new(1, 1); l.Position = UDim2.new(1, math.random(-10, 6), 0, 8)
	local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = delta > 0 and Color3.fromRGB(20, 70, 25) or INK; st.Parent = l
	l.Parent = pops
	tw(l, 0.9, { Position = l.Position - UDim2.fromOffset(0, 44) })
	task.delay(0.5, function() tw(l, 0.4, { TextTransparency = 1 }); tw(st, 0.4, { Transparency = 1 }) end)
	task.delay(1, function() l:Destroy() end)
end

local shown, target = 0, 0
local lastPop, pending = 0, 0
task.spawn(function()
	local cash = player:WaitForChild("leaderstats"):WaitForChild("Cash")
	shown, target = cash.Value, cash.Value
	amount.Text = fmt(shown)
	cash.Changed:Connect(function(v)
		local delta = v - target
		target = v
		if delta == 0 then return end
		pending += delta
		if os.clock() - lastPop > 0.25 then lastPop = os.clock(); popup(pending); pending = 0 end
		coinScale.Scale = 1.18; tw(coinScale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
		panelScale.Scale = delta > 0 and 1.04 or 0.97; tw(panelScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
		if delta > 0 and delta >= math.max(1000, target * 0.1) then shine() end
	end)
end)

local function income()
	local total = 0
	for _, plot in workspace:WaitForChild("Plots"):GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			local placed = plot:FindFirstChild("PlacedItems")
			if placed then for _, m in placed:GetChildren() do total += m:GetAttribute("IncomePerSecond") or 0 end end
		end
	end
	return total * (workspace:GetAttribute("OwnerIncomeMultiplier") or 1)
end
task.spawn(function() while true do incomeText.Text = "+" .. fmt(income()) .. "/sec"; task.wait(1) end end)
task.spawn(function() while true do task.wait(7) shine() end end)

local t0 = os.clock()
RunService.RenderStepped:Connect(function(dt)
	coinBox.Rotation = math.sin((os.clock() - t0) * 1.6) * 4
	if shown ~= target then
		shown += (target - shown) * math.min(1, dt * 10)
		if math.abs(target - shown) < 1 then shown = target end
		amount.Text = fmt(math.floor(shown + 0.5))
	end
end)

-- IncomeShimmer: shine across the green pill + soft glow pulse
local pillSweep = face.Income.Shimmer.Sweep
local pillGlow = face:FindFirstChild("IncomeGlow")
task.spawn(function()
	while true do
		pillSweep.Offset = Vector2.new(-1.5, 0)
		tw(pillSweep, 0.9, { Offset = Vector2.new(1.5, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.wait(2.6)
	end
end)
if pillGlow then
	RunService.RenderStepped:Connect(function()
		pillGlow.ImageTransparency = 0.72 + math.sin(os.clock() * 2.2) * 0.1
	end)
end
