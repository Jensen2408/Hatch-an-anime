-- UpdateAnnouncer: countdown banner before the update, "What's new" window after it. Config: RS.UpdateConfig
local Players = game:GetService("Players")
local TS = game:GetService("TweenService")
local player = Players.LocalPlayer
local pg = player:WaitForChild("PlayerGui")
local C = require(game.ReplicatedStorage:WaitForChild("UpdateConfig"))
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local STUDS = "rbxassetid://132561191216691"
local INK = Color3.fromRGB(13, 10, 20)
local function make(c, p, parent) local o = Instance.new(c); for k, v in p do o[k] = v end; o.Parent = parent; return o end
local function stroke(o, t, col, border) return make("UIStroke", { Thickness = t, Color = col or INK, ApplyStrokeMode = border and Enum.ApplyStrokeMode.Border or Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Miter }, o) end
local function block(parent, top, bot, props)
	local f = make("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0 }, parent)
	for k, v in props or {} do f[k] = v end
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(top, bot) }, f)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, f)
	stroke(f, 4, Color3.new(1, 1, 1), true)
	local st = make("ImageLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = STUDS, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(24, 24), ImageTransparency = 0.55, ZIndex = f.ZIndex }, f)
	make("UICorner", { CornerRadius = UDim.new(0, 12) }, st)
	return f
end
local function label(parent, t, size, col, props)
	local l = make("TextLabel", { BackgroundTransparency = 1, FontFace = FONT, Text = t, TextSize = size, TextColor3 = col or Color3.new(1, 1, 1) }, parent)
	for k, v in props or {} do l[k] = v end
	stroke(l, size >= 24 and 3 or 2); return l
end
local function now() return workspace:GetServerTimeNow() end
local gui = make("ScreenGui", { Name = "UpdateUI", ResetOnSpawn = false, DisplayOrder = 42, IgnoreGuiInset = false }, pg)

-- ===== countdown banner (under the money) =====
if C.ShowCountdown and now() < C.LaunchTime then
	local b = block(gui, Color3.fromRGB(255, 99, 177), Color3.fromRGB(163, 17, 91), { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 104), Size = UDim2.fromOffset(300, 54) })
	label(b, "🚀 " .. C.Title, 18, Color3.fromRGB(255, 240, 170), { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 20), ZIndex = 3 })
	local t = label(b, "", 22, nil, { Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 26), ZIndex = 3 })
	make("Frame", { BackgroundColor3 = INK, BorderSizePixel = 0, Position = UDim2.fromOffset(0, 6), Size = UDim2.fromScale(1, 1), ZIndex = 0 }, b).Parent = b
	task.spawn(function()
		while b.Parent do
			local left = math.floor(C.LaunchTime - now())
			if left <= 0 then t.Text = "OUT NOW! REJOIN"; break end
			local d, h, m, s = left // 86400, (left // 3600) % 24, (left // 60) % 60, left % 60
			t.Text = (d > 0 and (d .. "d ") or "") .. string.format("%02dh %02dm %02ds", h, m, s)
			task.wait(1)
		end
	end)
end

-- ===== "What's new" window (after launch, once per update) =====
if now() >= C.LaunchTime and player:GetAttribute("SeenUpdate_" .. C.Id) == nil then
	player:SetAttribute("SeenUpdate_" .. C.Id, true)
	task.wait(6) -- let the join intro finish
	local dim = make("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.new(0, 0, 0), BackgroundTransparency = 0.45, Size = UDim2.new(1, 0, 1, 60), Position = UDim2.fromOffset(0, -60), ZIndex = 10 }, gui)
	local h = 150 + #C.Items * 40
	local w = block(gui, Color3.fromRGB(47, 35, 87), Color3.fromRGB(20, 13, 43), { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(520, h), ZIndex = 11 })
	local sc = make("UIScale", { Scale = 0.8 }, w)
	local head = block(w, Color3.fromRGB(255, 201, 63), Color3.fromRGB(163, 92, 0), { Size = UDim2.new(1, 0, 0, 74), ZIndex = 12 })
	label(head, "✨ WHAT'S NEW ✨", 36, nil, { Size = UDim2.fromScale(1, 1), ZIndex = 14 })
	label(w, C.Title, 20, Color3.fromRGB(255, 227, 107), { Position = UDim2.fromOffset(0, 80), Size = UDim2.new(1, 0, 0, 24), ZIndex = 13 })
	for i, item in C.Items do
		label(w, item, 19, nil, { Position = UDim2.fromOffset(30, 104 + (i - 1) * 40), Size = UDim2.new(1, -60, 0, 36), TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, ZIndex = 13 })
	end
	local ok = make("TextButton", { Text = "", AutoButtonColor = false, AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -14), Size = UDim2.fromOffset(180, 46), BackgroundColor3 = Color3.fromRGB(67, 220, 78), ZIndex = 13 }, w)
	make("UICorner", { CornerRadius = UDim.new(0, 10) }, ok); stroke(ok, 3, INK, true)
	label(ok, "LET'S GO!", 24, nil, { Size = UDim2.fromScale(1, 1), ZIndex = 14 })
	TS:Create(sc, TweenInfo.new(0.3, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	local function close() gui:Destroy() end
	ok.Activated:Connect(close); dim.Activated:Connect(close)
end
