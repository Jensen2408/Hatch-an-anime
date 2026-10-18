--[[ GameMenus (LocalScript)
Side buttons + four panels made in ForgeGUI: My Plot, Index, Quests, VIP Shop.
Panel art = full images; this script only adds the open/close behaviour and the
clickable areas on top (close X). Content (quests, items, slots) comes next.
Image ids live in ReplicatedStorage.GameMenuImages (attributes) so they can be swapped.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local images = ReplicatedStorage:WaitForChild("GameMenuImages")
local WOOD = Color3.fromRGB(74, 44, 30)
local CREAM = Color3.fromRGB(255, 243, 220)
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")

-- name, art aspect (w/h), button colour, close-X position on the art (scale)
local PANELS = {
	{ id = "Plot", title = "PLOT", aspect = 1672 / 941, color = Color3.fromRGB(214, 52, 45), close = nil },
	{ id = "Index", title = "INDEX", aspect = 1536 / 1024, color = Color3.fromRGB(64, 140, 220), close = Vector2.new(0.874, 0.163) },
	{ id = "Quests", title = "QUESTS", aspect = 1536 / 1024, color = Color3.fromRGB(76, 180, 72), close = Vector2.new(0.866, 0.240) },
	{ id = "VipShop", title = "VIP", aspect = 1536 / 1024, color = Color3.fromRGB(240, 180, 40), close = Vector2.new(0.882, 0.272) },
}

local gui = Instance.new("ScreenGui")
gui.Name = "GameMenus"; gui.ResetOnSpawn = false; gui.DisplayOrder = 20; gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

-- dim background behind an open panel; click it to close
local dim = Instance.new("TextButton")
dim.Name = "Dim"; dim.Text = ""; dim.AutoButtonColor = false; dim.Size = UDim2.fromScale(1, 1)
dim.BackgroundColor3 = Color3.new(0, 0, 0); dim.BackgroundTransparency = 1; dim.Visible = false; dim.Parent = gui

-- side buttons (left middle)
local side = Instance.new("Frame")
side.Name = "SideButtons"; side.BackgroundTransparency = 1; side.AnchorPoint = Vector2.new(0, 0.5)
side.Position = UDim2.new(0, 14, 0.5, 0); side.Size = UDim2.fromOffset(84, 4 * 92); side.Parent = gui
local list = Instance.new("UIListLayout"); list.Padding = UDim.new(0, 10); list.SortOrder = Enum.SortOrder.LayoutOrder; list.Parent = side

local open -- currently open panel record
local panels = {}

local function close()
	if not open then return end
	local p = open; open = nil
	TweenService:Create(p.scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
	TweenService:Create(dim, TweenInfo.new(0.15), { BackgroundTransparency = 1 }):Play()
	task.delay(0.15, function() if open ~= p then p.frame.Visible = false end; if not open then dim.Visible = false end end)
end

local function show(p)
	if open == p then close() return end
	if open then open.frame.Visible = false; open = nil end
	open = p
	p.frame.Visible = true; dim.Visible = true
	p.scale.Scale = 0.85
	TweenService:Create(p.scale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	TweenService:Create(dim, TweenInfo.new(0.2), { BackgroundTransparency = 0.55 }):Play()
end
dim.Activated:Connect(close)

for i, def in PANELS do
	-- panel
	local frame = Instance.new("ImageLabel")
	frame.Name = def.id; frame.BackgroundTransparency = 1; frame.Visible = false
	frame.AnchorPoint = Vector2.new(0.5, 0.5); frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromScale(0.62, 0.62); frame.ScaleType = Enum.ScaleType.Fit
	frame.Image = images:GetAttribute(def.id) or ""
	frame.ZIndex = 5; frame.Parent = gui
	local ar = Instance.new("UIAspectRatioConstraint"); ar.AspectRatio = def.aspect; ar.Parent = frame
	local sz = Instance.new("UISizeConstraint"); sz.MaxSize = Vector2.new(900, 900); sz.Parent = frame
	local scale = Instance.new("UIScale"); scale.Parent = frame
	images:GetAttributeChangedSignal(def.id):Connect(function() frame.Image = images:GetAttribute(def.id) or "" end)
	-- invisible hit area on the drawn close X
	local x = Instance.new("TextButton")
	x.Name = "Close"; x.Text = ""; x.BackgroundTransparency = 1; x.AnchorPoint = Vector2.new(0.5, 0.5)
	x.Size = UDim2.fromScale(0.08, 0.12); x.ZIndex = 6
	x.Position = def.close and UDim2.fromScale(def.close.X, def.close.Y) or UDim2.fromScale(0.95, 0.08)
	x.Parent = frame
	x.Activated:Connect(close)
	local rec = { frame = frame, scale = scale, def = def }
	panels[def.id] = rec

	-- side button: chunky stud style
	local b = Instance.new("TextButton")
	b.Name = def.id .. "Button"; b.LayoutOrder = i; b.Size = UDim2.fromOffset(84, 82); b.AutoButtonColor = false
	b.BackgroundColor3 = WOOD; b.Text = ""; b.Parent = side
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 14)
	local face = Instance.new("Frame")
	face.Size = UDim2.new(1, 0, 1, -6); face.BackgroundColor3 = def.color; face.Parent = b
	Instance.new("UICorner", face).CornerRadius = UDim.new(0, 14)
	local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = WOOD; st.Parent = face
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1; t.Size = UDim2.fromScale(1, 1); t.FontFace = FONT; t.Text = def.title
	t.TextColor3 = CREAM; t.TextScaled = true; t.Parent = face
	local pad = Instance.new("UIPadding"); pad.PaddingLeft = UDim.new(0, 8); pad.PaddingRight = UDim.new(0, 8); pad.Parent = t
	local ts = Instance.new("UIStroke"); ts.Thickness = 2.5; ts.Color = WOOD; ts.Parent = t
	b.MouseButton1Down:Connect(function() face.Position = UDim2.fromOffset(0, 4) end)
	b.MouseButton1Up:Connect(function() face.Position = UDim2.fromOffset(0, 0) end)
	b.MouseLeave:Connect(function() face.Position = UDim2.fromOffset(0, 0) end)
	b.Activated:Connect(function() show(rec) end)
end
