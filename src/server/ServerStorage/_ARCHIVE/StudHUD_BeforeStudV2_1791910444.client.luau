-- StudHUD: adds brick studs on top of the HUD buttons and the cash panel (cosmetic only).
local pg = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
local INK = Color3.fromRGB(40, 24, 18)
local COLORS = {
	PlotButton = Color3.fromRGB(226, 66, 60), IndexButton = Color3.fromRGB(66, 134, 236),
	QuestsButton = Color3.fromRGB(92, 192, 70), VipShopButton = Color3.fromRGB(248, 188, 44),
	Money = Color3.fromRGB(246, 196, 84),
}
local function stud(parent, color, xScale, w, h, z)
	local base = Instance.new("Frame")
	base.Name = "Stud"; base.AnchorPoint = Vector2.new(0.5, 1); base.Position = UDim2.new(xScale, 0, 0, 0)
	base.Size = UDim2.fromOffset(w, h); base.BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.18); base.BorderSizePixel = 0; base.ZIndex = z
	Instance.new("UICorner", base).CornerRadius = UDim.new(0, math.floor(h * 0.45))
	local st = Instance.new("UIStroke"); st.Color = INK; st.Thickness = 2.5; st.Parent = base
	local top = Instance.new("Frame")
	top.Name = "Top"; top.BorderSizePixel = 0; top.BackgroundColor3 = color:Lerp(Color3.new(1, 1, 1), 0.28)
	top.Size = UDim2.new(1, -4, 0.55, 0); top.Position = UDim2.fromOffset(2, 2); top.ZIndex = z + 1
	Instance.new("UICorner", top).CornerRadius = UDim.new(0, math.floor(h * 0.35))
	local shine = Instance.new("Frame")
	shine.BorderSizePixel = 0; shine.BackgroundColor3 = Color3.new(1, 1, 1); shine.BackgroundTransparency = 0.35
	shine.Size = UDim2.new(0.28, 0, 0.35, 0); shine.Position = UDim2.new(0.14, 0, 0.18, 0); shine.ZIndex = z + 2
	Instance.new("UICorner", shine).CornerRadius = UDim.new(1, 0)
	shine.Parent = top; top.Parent = base; base.Parent = parent
end
local function decorate(obj, count, inset, w, h, top)
	if obj:FindFirstChild("Studs") then return end
	local row = Instance.new("Frame")
	row.Name = "Studs"; row.BackgroundTransparency = 1; row.Size = UDim2.new(1 - inset * 2, 0, 0, 0)
	row.Position = UDim2.new(inset, 0, top or 0.1, 0); row.ZIndex = obj.ZIndex + 1; row.Parent = obj
	for i = 1, count do stud(row, COLORS[obj.Name] or COLORS.Money, (i - 0.5) / count, w, h, obj.ZIndex + 1) end
end
task.spawn(function()
	local menus = pg:WaitForChild("GameMenus", 30)
	local side = menus and menus:WaitForChild("SideButtons", 30)
	if side then
		local grid = side:FindFirstChildOfClass("UIGridLayout")
		if grid then grid.CellPadding = UDim2.fromOffset(grid.CellPadding.X.Offset, 12) end
		for _, b in side:GetChildren() do if b:IsA("GuiButton") then decorate(b, 2, 0.24, 30, 14) end end
		side.ChildAdded:Connect(function(b) if b:IsA("GuiButton") then decorate(b, 2, 0.24, 30, 14) end end)
	end
end)
task.spawn(function()
	local md = pg:WaitForChild("MoneyDisplay", 30)
	local money = md and md:WaitForChild("Money", 30)
	if money then decorate(money, 3, 0.2, 46, 20, 0.19) end
end)
