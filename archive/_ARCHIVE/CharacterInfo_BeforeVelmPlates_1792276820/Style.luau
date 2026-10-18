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
function S.Card(parent, d)
	local card = S.make("Frame", { Name = "Card", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, parent)
	S.make("UIListLayout", { HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, (d.gap or 2) + math.ceil((d.stroke or 3) * 2)), SortOrder = Enum.SortOrder.LayoutOrder }, card)
	local th = d.stroke or 3
	local name = outlined(card, d.nameSize, S.White, th, 1)
	local badge = outlined(card, d.rarSize or math.floor(d.nameSize * 0.62), S.RarityText.Common, th * 0.8, 2)
	local row = S.make("Frame", { BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.XY, Size = UDim2.new(), LayoutOrder = 3 }, card)
	S.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Bottom, Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local plabel = outlined(row, d.powLabel or math.floor(d.powerSize * 0.46), S.White, th * 0.8, 1); plabel.Text = "POWER"
	local power = outlined(row, d.powerSize, S.Power, th, 2)
	local pgrad = S.make("UIGradient", { Enabled = false, Rotation = 20, Offset = Vector2.new(-1.3, 0),
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, S.PowerGold), ColorSequenceKeypoint.new(0.45, S.PowerGold), ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)), ColorSequenceKeypoint.new(0.55, S.PowerGold), ColorSequenceKeypoint.new(1, S.PowerGold) }) }, power)
	local income = outlined(card, d.incSize, S.Income, th, 4)
	local spark = S.make("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 10 }, parent)
	local sparkScale = S.make("UIScale", { Scale = 0 }, spark)
	for _, sz in { UDim2.new(0, 3, 1, 0), UDim2.new(1, 0, 0, 3) } do local bar = S.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = sz, BackgroundColor3 = Color3.fromRGB(255, 246, 200), BorderSizePixel = 0, ZIndex = 10 }, spark); S.corner(bar, 2); S.stroke(bar, 1.5) end
	return { root = card, card = card, name = name, badge = badge, power = power, pgrad = pgrad, income = income, spark = spark, sparkScale = sparkScale }
end

function S.Apply(ui, data)
	ui.name.Text = data.name
	ui.badge.Text = data.rarity
	ui.badge.TextColor3 = S.RarityText[data.rarity] or S.RarityText.Common
	ui.power.Text = S.Short(data.power)
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
