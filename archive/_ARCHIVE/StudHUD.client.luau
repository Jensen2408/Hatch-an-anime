-- StudHUD v2: LEGO-style studs on the HUD buttons and the cash panel, plus small hover / coin effects (cosmetic only).
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
local INK = Color3.fromRGB(40, 24, 18)
local COLORS = {
	PlotButton = Color3.fromRGB(226, 66, 60), IndexButton = Color3.fromRGB(66, 134, 236),
	QuestsButton = Color3.fromRGB(92, 192, 70), VipShopButton = Color3.fromRGB(248, 188, 44),
	Money = Color3.fromRGB(246, 196, 84),
}
local function dark(c, a) return c:Lerp(Color3.new(0, 0, 0), a) end
local function light(c, a) return c:Lerp(Color3.new(1, 1, 1), a) end
local function round(o, r) local u = Instance.new("UICorner"); u.CornerRadius = r or UDim.new(1, 0); u.Parent = o end
local function frame(parent, props) local f = Instance.new("Frame"); f.BorderSizePixel = 0; for k, v in pairs(props) do f[k] = v end; f.Parent = parent; return f end
-- one stud: shadow + cylinder side + round top with rim + shine
local function stud(parent, color, xScale, w, h, z)
	local holder = frame(parent, { Name = "Stud", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(xScale, 0, 0, 3), Size = UDim2.fromOffset(w, h), ZIndex = z })
	frame(holder, { Name = "Shadow", BackgroundColor3 = INK, BackgroundTransparency = 0.55, Position = UDim2.fromOffset(2, 3), Size = UDim2.fromScale(1, 1), ZIndex = z }).Parent = holder
	round(holder.Shadow, UDim.new(0, math.floor(h * 0.5)))
	local side = frame(holder, { Name = "Side", BackgroundColor3 = dark(color, 0.22), Size = UDim2.fromScale(1, 1), ZIndex = z + 1 })
	round(side, UDim.new(0, math.floor(h * 0.5)))
	local s = Instance.new("UIStroke"); s.Color = INK; s.Thickness = 2.5; s.Parent = side
	local g = Instance.new("UIGradient"); g.Color = ColorSequence.new(dark(color, 0.32), dark(color, 0.12), dark(color, 0.32)); g.Parent = side
	local top = frame(side, { Name = "Top", BackgroundColor3 = light(color, 0.25), Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 0.62, 0), ZIndex = z + 2 })
	round(top)
	local rim = Instance.new("UIStroke"); rim.Color = dark(color, 0.08); rim.Thickness = 1.5; rim.Transparency = 0.2; rim.Parent = top
	local tg = Instance.new("UIGradient"); tg.Rotation = 90; tg.Color = ColorSequence.new(light(color, 0.45), light(color, 0.1)); tg.Parent = top
	local shine = frame(top, { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, Position = UDim2.new(0.16, 0, 0.18, 0), Size = UDim2.new(0.26, 0, 0.36, 0), ZIndex = z + 3 })
	round(shine)
	return holder
end
local function decorate(obj, count, inset, w, h, top, color)
	if obj:FindFirstChild("Studs") then obj.Studs:Destroy() end
	local row = frame(obj, { Name = "Studs", BackgroundTransparency = 1, Size = UDim2.new(1 - inset * 2, 0, 0, 0), Position = UDim2.new(inset, 0, top or 0.08, 0), ZIndex = obj.ZIndex + 1 })
	for i = 1, count do stud(row, color or COLORS[obj.Name] or COLORS.Money, (i - 0.5) / count, w, h, obj.ZIndex + 1) end
	return row
end
-- studs hop up one after another (used on hover and now and then)
local function hop(row, amount)
	for i, s in ipairs(row:GetChildren()) do
		task.delay((i - 1) * 0.06, function()
			if not s.Parent then return end
			local p = s.Position
			local up = TweenService:Create(s, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Position = p - UDim2.fromOffset(0, amount) })
			up:Play(); up.Completed:Wait()
			TweenService:Create(s, TweenInfo.new(0.25, Enum.EasingStyle.Bounce), { Position = p }):Play()
		end)
	end
end
local function hookButton(b)
	if not b:IsA("GuiButton") or b:GetAttribute("StudV2") then return end
	b:SetAttribute("StudV2", true)
	local row = decorate(b, 2, 0.22, 34, 17)
	local busy = false
	b.MouseEnter:Connect(function()
		if busy then return end busy = true
		hop(row, 7)
		TweenService:Create(b, TweenInfo.new(0.08), { Rotation = -4 }):Play()
		task.delay(0.08, function() TweenService:Create(b, TweenInfo.new(0.35, Enum.EasingStyle.Elastic), { Rotation = 0 }):Play() end)
		task.delay(0.45, function() busy = false end)
	end)
end
task.spawn(function()
	local menus = pg:WaitForChild("GameMenus", 30)
	local side = menus and menus:WaitForChild("SideButtons", 30)
	if not side then return end
	local grid = side:FindFirstChildOfClass("UIGridLayout")
	if grid then grid.CellPadding = UDim2.fromOffset(grid.CellPadding.X.Offset, 16) end
	for _, b in side:GetChildren() do hookButton(b) end
	side.ChildAdded:Connect(hookButton)
	-- idle: a random button's studs hop every few seconds so the HUD feels alive
	while side.Parent do
		task.wait(4 + math.random() * 3)
		local list = {}
		for _, b in side:GetChildren() do if b:IsA("GuiButton") and b:FindFirstChild("Studs") then table.insert(list, b) end end
		if #list > 0 then hop(list[math.random(#list)].Studs, 5) end
	end
end)
task.spawn(function()
	local md = pg:WaitForChild("MoneyDisplay", 30)
	local money = md and md:WaitForChild("Money", 30)
	if not money then return end
	local row = decorate(money, 3, 0.24, 52, 24, 0.2)
	-- coin: gentle wobble + sparkle every few seconds
	local coinBox = money:FindFirstChild("CoinBox")
	local coin = coinBox and coinBox:FindFirstChild("Coin")
	if coin then
		local spark = Instance.new("TextLabel")
		spark.BackgroundTransparency = 1; spark.Text = "✨"; spark.TextSize = 30; spark.Size = UDim2.fromOffset(34, 34)
		spark.AnchorPoint = Vector2.new(0.5, 0.5); spark.Position = UDim2.fromScale(0.75, 0.2); spark.TextTransparency = 1; spark.ZIndex = coin.ZIndex + 2; spark.Parent = coinBox
		while coin.Parent do
			task.wait(5 + math.random() * 3)
			TweenService:Create(coin, TweenInfo.new(0.12), { Rotation = -14 }):Play(); task.wait(0.12)
			TweenService:Create(coin, TweenInfo.new(0.6, Enum.EasingStyle.Elastic), { Rotation = 0 }):Play()
			spark.Position = UDim2.fromScale(0.6 + math.random() * 0.3, 0.1 + math.random() * 0.3); spark.Rotation = math.random(-30, 30)
			TweenService:Create(spark, TweenInfo.new(0.25), { TextTransparency = 0, TextSize = 36 }):Play(); task.wait(0.35)
			TweenService:Create(spark, TweenInfo.new(0.4), { TextTransparency = 1, TextSize = 24 }):Play()
			hop(row, 5)
		end
	end
end)
