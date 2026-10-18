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

-- Builds the shared card. dims: { w, h, studs, studW, nameSize, powerSize, incSize, badge } in pixels.
-- Returns refs used by both the held card and the placed label.
function S.Card(parent, d)
	local root = S.make("Frame", { Name = "Card", BackgroundTransparency = 1, Size = UDim2.fromOffset(d.w, d.h + 12) }, parent)
	local studs = S.make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 8), ZIndex = 3 }, root)
	S.make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, Padding = UDim.new(0, d.studGap) }, studs)
	local studList = {}
	for i = 1, d.studs do
		local s = S.make("Frame", { Size = UDim2.fromOffset(d.studW, 9), BackgroundColor3 = S.Cream, ZIndex = 3 }, studs)
		S.corner(s, 3); S.stroke(s, 2.5)
		S.make("Frame", { Position = UDim2.fromOffset(2, 1), Size = UDim2.new(1, -4, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 4 }, s)
		studList[i] = s
	end
	local base = S.make("Frame", { Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(d.w, d.h), BackgroundColor3 = S.Ink }, root); S.corner(base, 12)
	local card = S.make("Frame", { Position = UDim2.fromOffset(0, 7), Size = UDim2.fromOffset(d.w, d.h), BackgroundColor3 = S.Cream, ClipsDescendants = true, ZIndex = 2 }, root)
	S.corner(card, 12); S.stroke(card, 3)
	S.make("Frame", { Position = UDim2.fromOffset(8, 2), Size = UDim2.new(1, -16, 0, 2), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 2 }, card)
	S.make("Frame", { Position = UDim2.new(0, 8, 1, -5), Size = UDim2.new(1, -16, 0, 3), BackgroundColor3 = S.CreamLow, BorderSizePixel = 0, ZIndex = 2 }, card)
	local brackets = {}
	for _, c in { { 0, 0 }, { 1, 0 }, { 0, 1 }, { 1, 1 } } do -- gold L-brackets
		local h = S.make("Frame", { AnchorPoint = Vector2.new(c[1], c[2]), Position = UDim2.new(c[1], c[1] == 1 and -5 or 5, c[2], c[2] == 1 and -5 or 5), Size = UDim2.fromOffset(10, 3), BackgroundColor3 = S.Bracket, BorderSizePixel = 0, ZIndex = 3 }, card)
		local v = S.make("Frame", { AnchorPoint = Vector2.new(c[1], c[2]), Position = h.Position, Size = UDim2.fromOffset(3, 10), BackgroundColor3 = S.Bracket, BorderSizePixel = 0, ZIndex = 3 }, card)
		table.insert(brackets, h); table.insert(brackets, v)
	end
	local stripe = S.make("Frame", { Size = UDim2.new(1, 0, 0, 4), BackgroundColor3 = S.Gold, BorderSizePixel = 0, Visible = false, ZIndex = 3 }, card)
	local shine = S.make("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Visible = false, ZIndex = 9 }, card)
	local shineGrad = S.make("UIGradient", { Rotation = 22, Offset = Vector2.new(-1.3, 0), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.45, 1), NumberSequenceKeypoint.new(0.5, 0.1), NumberSequenceKeypoint.new(0.55, 1), NumberSequenceKeypoint.new(1, 1) }) }, shine)
	-- row 1: name + rarity badge
	local px = d.padX
	local badge = S.make("TextLabel", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -px, 0, d.padY + 2), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, d.badge + 8),
		FontFace = S.Font, TextSize = d.badge, Text = "", ZIndex = 4 }, card)
	S.corner(badge, 6); S.stroke(badge, 2); S.make("UIPadding", { PaddingLeft = UDim.new(0, 7), PaddingRight = UDim.new(0, 7) }, badge)
	local name = S.label(card, "", d.nameSize, S.Ink, { Position = UDim2.fromOffset(px, d.padY), Size = UDim2.new(1, -px * 2 - 90, 0, d.nameSize + 4), ZIndex = 4 })
	-- row 2: POWER + income pill
	local y2 = d.padY + d.nameSize + d.rowGap
	S.label(card, "POWER", d.labelSize, S.Crimson, { Position = UDim2.fromOffset(px, y2), Size = UDim2.fromOffset(80, d.labelSize + 2), ZIndex = 4 })
	local power = S.label(card, "", d.powerSize, S.Ink, { Position = UDim2.fromOffset(px, y2 + d.labelSize + 2), Size = UDim2.new(0.55, -px, 0, d.powerSize + 4), TextScaled = false, ZIndex = 4 })
	S.make("UITextSizeConstraint", { MaxTextSize = d.powerSize, MinTextSize = math.floor(d.powerSize * 0.6) }, power)
	local pill = S.make("Frame", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -px, 0, y2 + d.labelSize + d.powerSize + 4), AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, d.incSize + 10), BackgroundColor3 = S.MoneyBg, ZIndex = 4 }, card)
	S.corner(pill, 8); S.stroke(pill, 2); S.make("UIPadding", { PaddingLeft = UDim.new(0, 9), PaddingRight = UDim.new(0, 9) }, pill)
	local income = S.label(pill, "", d.incSize, S.MoneyText, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromScale(0, 1), TextTruncate = Enum.TextTruncate.None, ZIndex = 5 })
	local spark = S.make("Frame", { Size = UDim2.fromOffset(14, 14), AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1, Visible = false, ZIndex = 10 }, card)
	local sparkScale = S.make("UIScale", { Scale = 0 }, spark)
	for _, sz in { UDim2.new(0, 3, 1, 0), UDim2.new(1, 0, 0, 3) } do local b = S.make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = sz, BackgroundColor3 = S.Gold, BorderSizePixel = 0, ZIndex = 10 }, spark); S.corner(b, 2); S.stroke(b, 1) end
	return { root = root, card = card, name = name, badge = badge, power = power, income = income, studs = studList, stripe = stripe, shine = shine, shineGrad = shineGrad, spark = spark, sparkScale = sparkScale, brackets = brackets, y2 = y2 }
end

function S.Apply(ui, data)
	ui.name.Text = data.name
	local rc = S.Rarity[data.rarity] or S.Rarity.Common
	ui.badge.Text = string.upper(data.rarity); ui.badge.BackgroundColor3 = rc[1]; ui.badge.TextColor3 = rc[2]
	ui.power.Text = S.Short(data.power)
	ui.income.Text = "$" .. S.Short(data.income) .. "/sec"
	ui.stripe.Visible = data.exceptional
	for _, s in ui.studs do s.BackgroundColor3 = data.exceptional and S.Gold or S.Cream end
end

function S.Celebrate(ui, reduced)
	if reduced then return end
	local TS = game:GetService("TweenService")
	ui.shine.Visible = true; ui.shineGrad.Offset = Vector2.new(-1.3, 0)
	local tw = TS:Create(ui.shineGrad, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { Offset = Vector2.new(1.3, 0) })
	tw.Completed:Once(function() ui.shine.Visible = false end)
	task.delay(0.35, function() tw:Play() end)
	ui.spark.Position = UDim2.new(0, ui.power.TextBounds.X + ui.power.Position.X.Offset + 8, 0, ui.power.Position.Y.Offset + 6)
	ui.spark.Visible = true; ui.spark.Rotation = 0
	task.delay(0.7, function()
		TS:Create(ui.sparkScale, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		TS:Create(ui.spark, TweenInfo.new(0.5), { Rotation = 90 }):Play()
		task.delay(0.25, function() local t = TS:Create(ui.sparkScale, TweenInfo.new(0.22), { Scale = 0 }); t.Completed:Once(function() ui.spark.Visible = false end); t:Play() end)
	end)
end

return S
