--[[ ReplicatedStorage.CharacterInfo.Style  (ModuleScript)  shared look + number formatting ]]
local S = {}
local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
S.Ink, S.Cream, S.CreamLow, S.Crimson, S.Gold, S.Bracket = rgb(29, 20, 32), rgb(255, 243, 220), rgb(241, 220, 182), rgb(200, 32, 44), rgb(255, 211, 107), rgb(214, 164, 67)
S.MoneyBg, S.MoneyText, S.Muted = rgb(216, 242, 207), rgb(34, 106, 46), rgb(107, 85, 96)
S.Rarity = {
	Common = { rgb(138, 145, 156), Color3.new(1, 1, 1) }, Uncommon = { rgb(63, 174, 74), Color3.new(1, 1, 1) },
	Rare = { rgb(45, 111, 214), Color3.new(1, 1, 1) }, Epic = { rgb(138, 63, 208), Color3.new(1, 1, 1) }, Legendary = { rgb(255, 197, 61), rgb(29, 20, 32) },
}
S.Font = Font.new("rbxasset://fonts/families/FredokaOne.json")

local UNITS = { { 1e18, "Qi" }, { 1e15, "Qa" }, { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } }
function S.Short(n)
	n = tonumber(n) or 0
	for _, u in UNITS do
		if math.abs(n) >= u[1] then
			local v = n / u[1]
			local s = v < 10 and string.format("%.2f", v) or v < 100 and string.format("%.1f", v) or tostring(math.floor(v + 0.5))
			if s:find("%.") then s = s:gsub("0+$", ""):gsub("%.$", "") end
			return s .. u[2]
		end
	end
	local r = math.floor(n * 10 + 0.5) / 10
	return (r % 1 == 0) and tostring(math.floor(r)) or tostring(r)
end
function S.Full(n)
	n = math.floor((tonumber(n) or 0) + 0.5)
	if n >= 1e15 then return string.format("%.4g", n) end
	local s = tostring(n):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (s:gsub("^,", ""))
end

function S.make(c, p, parent) local o = Instance.new(c); for k, v in p do o[k] = v end; if parent then o.Parent = parent end; return o end
function S.corner(o, r) S.make("UICorner", { CornerRadius = UDim.new(0, r) }, o) end
function S.stroke(o, t) return S.make("UIStroke", { Color = S.Ink, Thickness = t, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end
function S.label(parent, text, size, color, props)
	local l = S.make("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, TextColor3 = color or S.Ink, FontFace = S.Font, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd }, parent)
	if props then for k, v in props do l[k] = v end end
	return l
end

-- Outlined-text label (no frame). d: { w, nameSize, rarSize, powLabel, powerSize, incSize, stroke, gap }.
-- Order: name, rarity, POWER value, $income/s. Each line is a TextLabel with a UIStroke.
S.Power, S.PowerGold, S.Income, S.White = rgb(255, 107, 74), rgb(255, 211, 77), rgb(125, 255, 90), Color3.new(1, 1, 1)
S.RarityText = { Common = rgb(212, 217, 224), Uncommon = rgb(95, 227, 106), Rare = rgb(79, 163, 255), Epic = rgb(196, 107, 255), Legendary = rgb(255, 197, 61) }
local function outlined(parent, size, color, th, order)
	local l = S.make("TextLabel", { BackgroundTransparency = 1, Text = "", TextSize = size, TextColor3 = color, FontFace = S.Font, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), LayoutOrder = order, ZIndex = 4 }, parent)
	S.make("UIPadding", { PaddingTop = UDim.new(0, 1), PaddingBottom = UDim.new(0, 1) }, l)
	S.make("UIStroke", { Color = S.Ink, Thickness = th, LineJoinMode = Enum.LineJoinMode.Round }, l)
	return l
end
-- Velm plate (Figma "World Nameplates v2"): rarity strip on top, studded night-purple plate, white border.
S.Stud = "rbxassetid://132561191216691"
S.Plate = { Common = { rgb(150, 156, 172), rgb(64, 70, 86) }, Uncommon = { rgb(67, 220, 78), rgb(11, 122, 27) }, Rare = { rgb(59, 120, 255), rgb(11, 42, 156) },
	Epic = { rgb(168, 102, 255), rgb(74, 21, 166) }, Legendary = { rgb(255, 214, 72), rgb(214, 132, 0) }, Mythic = { rgb(255, 74, 74), rgb(150, 0, 20) }, Secret = { rgb(40, 40, 48), rgb(0, 0, 0) } }
S.Mut = { Silver = rgb(220, 228, 240), Gold = rgb(255, 214, 72), Diamond = rgb(120, 230, 255), Rainbow = rgb(255, 120, 200) }
local function grad(o, a, b) return S.make("UIGradient", { Rotation = 90, Color = ColorSequence.new(a, b) }, o) end
local function studs(o, t) return S.make("ImageLabel", { Name = "Studs", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = S.Stud, ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(18, 18), ImageTransparency = t or 0.55, ZIndex = o.ZIndex }, o) end
local function text(parent, size, color, th, props)
	local l = S.make("TextLabel", { BackgroundTransparency = 1, Text = "", TextSize = size, TextColor3 = color, FontFace = S.Font, ZIndex = 5, TextTruncate = Enum.TextTruncate.AtEnd }, parent)
	S.make("UIStroke", { Color = S.Ink, Thickness = th, LineJoinMode = Enum.LineJoinMode.Round }, l)
	if props then for k, v in props do l[k] = v end end
	return l
end
function S.Card(parent, d)
	-- v3 plate: whole plate in the rarity colour, rarity tag on top, big name, stats in a dark inset bar
	local root = S.make("Frame", { Name = "Card", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	local shadow = S.make("Frame", { Name = "Shadow", BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0, Position = UDim2.fromOffset(6, 20), Size = UDim2.new(1, -12, 1, -22), ZIndex = 1 }, root); S.corner(shadow, 12)
	local plate = S.make("Frame", { Name = "Plate", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Position = UDim2.fromOffset(6, 14), Size = UDim2.new(1, -12, 1, -22), ZIndex = 2, ClipsDescendants = true }, root)
	S.corner(plate, 12)
	local sgrad = grad(plate, S.Plate.Common[1], S.Plate.Common[2])
	studs(plate, 0.5)
	S.make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, plate)
	local gloss = S.make("Frame", { Name = "Gloss", BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.82, BorderSizePixel = 0, Position = UDim2.fromOffset(8, 5), Size = UDim2.new(1, -16, 0, 5), ZIndex = 3 }, plate); S.corner(gloss, 3)
	-- rarity tag sitting on the top edge
	local tag = S.make("Frame", { Name = "RarityTag", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 22), BackgroundColor3 = S.Ink, BorderSizePixel = 0, ZIndex = 6 }, root)
	S.corner(tag, 7); S.make("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, tag)
	S.make("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingRight = UDim.new(0, 10) }, tag)
	local badge = S.make("TextLabel", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), Text = "", TextSize = d.rarSize or 13, TextColor3 = Color3.new(1, 1, 1), FontFace = S.Font, ZIndex = 7 }, tag)
	local name = text(plate, d.nameSize + 2, Color3.new(1, 1, 1), (d.stroke or 2.5) + 0.5, { Position = UDim2.fromOffset(6, 16), Size = UDim2.new(1, -12, 0, d.nameSize + 8) })
	local bar = S.make("Frame", { Name = "Stats", AnchorPoint = Vector2.new(0.5, 1), BackgroundColor3 = S.Ink, BackgroundTransparency = 0.35, BorderSizePixel = 0, Position = UDim2.new(0.5, 0, 1, -7), Size = UDim2.new(1, -18, 0, d.powerSize + 10), ZIndex = 3 }, plate)
	S.corner(bar, 8)
	local row = S.make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, bar)
	S.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local power = text(row, d.powerSize, S.Power, d.stroke or 2.5, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 1 })
	local pgrad = S.make("UIGradient", { Enabled = false, Rotation = 20, Offset = Vector2.new(-1.3, 0),
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, S.PowerGold), ColorSequenceKeypoint.new(0.45, S.PowerGold), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.55, S.PowerGold), ColorSequenceKeypoint.new(1, S.PowerGold) }) }, power)
	local income = text(row, d.incSize + 2, S.Income, d.stroke or 2.5, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), LayoutOrder = 2 })
	-- mutation badge in the top-right corner
	local mut = S.make("TextLabel", { Name = "Mutation", Visible = false, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -2, 0, 4), Rotation = 6, AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 18), BackgroundColor3 = S.Mut.Gold, Text = "", TextSize = 12, TextColor3 = S.Ink, FontFace = S.Font, ZIndex = 8 }, root)
	S.corner(mut, 6); S.make("UIStroke", { Color = S.Ink, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, mut); S.make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, mut)
	local spark = S.make("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 10 }, parent)
	local sparkScale = S.make("UIScale", { Scale = 0 }, spark)
	for _, sz in { UDim2.new(0, 3, 1, 0), UDim2.new(1, 0, 0, 3) } do local b2 = S.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = sz, BackgroundColor3 = Color3.fromRGB(255, 246, 200), BorderSizePixel = 0, ZIndex = 10 }, spark); S.corner(b2, 2); S.stroke(b2, 1.5) end
	return { root = root, card = plate, name = name, badge = badge, strip = sgrad, mut = mut, power = power, pgrad = pgrad, income = income, spark = spark, sparkScale = sparkScale }
end
function S.Apply(ui, data)
	ui.name.Text = data.name
	local c = S.Plate[data.rarity] or S.Plate.Common
	ui.strip.Color = ColorSequence.new(c[1], c[2])
	ui.badge.Text = string.upper(data.rarity); local tg = ui.badge.Parent; if tg and tg:IsA("Frame") then tg.BackgroundColor3 = (S.Plate[data.rarity] or S.Plate.Common)[2] end
	ui.mut.Visible = data.mutation ~= nil
	if data.mutation then ui.mut.Text = "✦ " .. string.upper(data.mutation); ui.mut.BackgroundColor3 = S.Mut[data.mutation] or S.Mut.Gold end
	ui.power.Text = "⚡ " .. S.Short(data.power)
	ui.power.TextColor3 = data.exceptional and Color3.new(1, 1, 1) or S.Power
	ui.pgrad.Enabled = data.exceptional == true
	ui.income.Text = "$" .. S.Short(data.income) .. "/s"
end

-- exceptional roll: one diagonal shine through the gold Power text + one sparkle
function S.Celebrate(ui, reduced)
	if reduced then return end
	local TS = game:GetService("TweenService")
	ui.pgrad.Offset = Vector2.new(-1.3, 0)
	task.delay(0.35, function() TS:Create(ui.pgrad, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Offset = Vector2.new(1.3, 0) }):Play() end)
	task.delay(0.7, function()
		local p = ui.power.AbsolutePosition - ui.spark.Parent.AbsolutePosition
		ui.spark.Position = UDim2.fromOffset(p.X + ui.power.AbsoluteSize.X + 6, p.Y + 4)
		ui.spark.Visible = true; ui.spark.Rotation = 0
		TS:Create(ui.sparkScale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		TS:Create(ui.spark, TweenInfo.new(0.5), { Rotation = 90 }):Play()
		task.delay(0.25, function() local t = TS:Create(ui.sparkScale, TweenInfo.new(0.22), { Scale = 0 }); t.Completed:Once(function() ui.spark.Visible = false end); t:Play() end)
	end)
end

return S
