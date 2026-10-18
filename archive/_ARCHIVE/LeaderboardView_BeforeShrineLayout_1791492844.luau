--[[ ReplicatedStorage.Leaderboard.LeaderboardView  (ModuleScript)
Builds one leaderboard UI inside a container: the board's SurfaceGui ("Board") or the expanded
ScreenGui panel ("Screen" / "Compact"). Every view renders the same state from LeaderboardClient,
so the board and the expanded screen always show the same tab, scope and data.

Look: a cashmere page with dark-brown ink, brown buttons that sit on a darker lip (pressing pushes
the face down), cream row cards, filled gold / silver / bronze rank badges, and a deep-brown pinned
YOUR RANK bar.

The list itself never animates: rows are pooled and only their text changes, and the scroll
position is kept per tab + scope.
]]
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.LeaderboardConfig)
local Format = require(script.Parent.LeaderboardFormat)

local T = Config.Theme
local HEAD = Font.new("rbxasset://fonts/families/FredokaOne.json")
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Medium)
local BOLD = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local QUICK = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local SLIDE = TweenInfo.new(0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
local SHINE = TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
local PRESS = TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local RELEASE = TweenInfo.new(0.14, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local MEDAL = { T.Gold, T.Silver, T.Bronze }

local METRICS = {
	Board = {
		Pad = 18, Header = 62, Title = 36, Scope = 14, ScopeW = 250, ScopeH = 38, Tabs = 54, TabText = 20,
		Column = 30, ColText = 13, Row = 58, Badge = 34, Avatar = 42, Name = 21, User = 14, Value = 21,
		ValueW = 190, YouLabel = 26, Meta = 24, MetaText = 13, Gap = 8, Bar = 6, Lip = 4,
		Edge = 13, -- the board's gold lining covers the outer 0.25 stud of the screen
	},
	Screen = {
		Pad = 16, Header = 56, Title = 30, Scope = 13, ScopeW = 210, ScopeH = 36, Tabs = 52, TabText = 18,
		Column = 28, ColText = 12, Row = 54, Badge = 32, Avatar = 38, Name = 18, User = 13, Value = 18,
		ValueW = 140, YouLabel = 24, Meta = 22, MetaText = 12, Gap = 6, Bar = 4, Lip = 4,
	},
	Compact = {
		Pad = 10, Header = 42, Title = 22, Scope = 11, ScopeW = 164, ScopeH = 30, Tabs = 40, TabText = 14,
		Column = 0, ColText = 11, Row = 46, Badge = 26, Avatar = 32, Name = 15, User = 11, Value = 15,
		ValueW = 104, YouLabel = 16, Meta = 0, MetaText = 11, Gap = 4, Bar = 4, Lip = 3, -- Meta 0: no meta line on phones
	},
}

local View = {}
View.__index = View

---------------------------------------------------------------- helpers
local function make(class, props, parent)
	local inst = Instance.new(class)
	for k, v in props do inst[k] = v end
	inst.Parent = parent
	return inst
end

local function corner(parent, radius)
	return make("UICorner", { CornerRadius = UDim.new(0, radius) }, parent)
end

local function stroke(parent, color, thickness, transparency)
	return make("UIStroke", {
		Color = color, Thickness = thickness or 1, Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	}, parent)
end

local function label(parent, props)
	local base = {
		BackgroundTransparency = 1, BorderSizePixel = 0, TextColor3 = T.Ink, FontFace = BODY, TextSize = 14,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for k, v in props do base[k] = v end
	return make("TextLabel", base, parent)
end

-- A brown button: a darker lip with the face sitting on top of it. Pressing moves the face down
-- onto the lip (and a UIScale gives the slight squeeze). Returns holder, face, scale.
local function brownButton(parent, props, lip, selectable)
	local holder = make("Frame", {
		Name = props.Name or "Button", AnchorPoint = props.AnchorPoint or Vector2.zero, Position = props.Position,
		Size = props.Size, BackgroundColor3 = T.ButtonLip, BorderSizePixel = 0,
	}, parent)
	corner(holder, 8)
	local scale = make("UIScale", {}, holder)
	local face = make("TextButton", {
		Name = "Face", Size = UDim2.new(1, 0, 1, -lip), BackgroundColor3 = T.Button, BorderSizePixel = 0,
		Text = "", AutoButtonColor = false, Selectable = selectable, ClipsDescendants = true,
	}, holder)
	corner(face, 8)
	make("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(226, 220, 214)), -- soft top light
	}, face)

	local pressed = false
	local function down()
		TweenService:Create(face, PRESS, { Position = UDim2.fromOffset(0, lip - 1) }):Play()
		TweenService:Create(scale, PRESS, { Scale = 0.97 }):Play()
	end
	local function up()
		TweenService:Create(face, RELEASE, { Position = UDim2.fromOffset(0, 0) }):Play()
		TweenService:Create(scale, RELEASE, { Scale = 1 }):Play()
	end
	face.InputBegan:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			pressed = true
			down()
		end
	end)
	face.InputEnded:Connect(function(input)
		local kind = input.UserInputType
		if kind == Enum.UserInputType.MouseButton1 or kind == Enum.UserInputType.Touch then
			pressed = false
			up()
		end
	end)
	face.Activated:Connect(function()
		if not pressed then -- gamepad / keyboard: the same press, played through
			down()
			task.delay(0.07, up)
		end
	end)
	return holder, face, scale
end

local function buildRow(parent, M, name, pinned)
	local row = { pinned = pinned }
	local f = make("Frame", {
		Name = name, Size = UDim2.new(1, 0, 0, M.Row - 6), BackgroundColor3 = pinned and T.You or T.Card,
		BorderSizePixel = 0,
	}, parent)
	corner(f, 8)
	row.frame = f
	row.edge = stroke(f, pinned and T.Gold or T.CardEdge, 1, pinned and 0.45 or 0)
	row.accent = make("Frame", {
		Name = "Accent", Position = UDim2.fromOffset(0, 8), Size = UDim2.new(0, 4, 1, -16),
		BackgroundColor3 = T.Gold, BorderSizePixel = 0, Visible = false,
	}, f)
	corner(row.accent, 2)

	local x = 12
	row.badge = make("Frame", {
		Name = "Rank", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 0.5, 0),
		Size = UDim2.fromOffset(M.Badge, M.Badge), BackgroundColor3 = T.Gold, BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, f)
	corner(row.badge, 8)
	row.badgeStroke = stroke(row.badge, T.Ink, 1, 0.75)
	row.badgeStroke.Enabled = false
	row.rank = label(row.badge, {
		Size = UDim2.fromScale(1, 1), FontFace = BOLD, TextSize = M.Name - 4,
		TextColor3 = pinned and T.YouText or T.InkSoft,
		TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.None,
	})

	x += M.Badge + 10
	row.avatar = make("ImageLabel", {
		Name = "Avatar", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, x, 0.5, 0),
		Size = UDim2.fromOffset(M.Avatar, M.Avatar), BackgroundColor3 = T.Avatar, BorderSizePixel = 0,
		ScaleType = Enum.ScaleType.Crop, Image = "",
	}, f)
	corner(row.avatar, 8)
	row.avatarStroke = stroke(row.avatar, pinned and T.YouSub or T.CardEdge, 1)

	x += M.Avatar + 12
	local names = make("Frame", {
		Name = "Names", BackgroundTransparency = 1, Position = UDim2.fromOffset(x, 0),
		Size = UDim2.new(1, -(x + M.ValueW + 22), 1, 0), ClipsDescendants = true,
	}, f)
	row.name = label(names, {
		Name = "DisplayName", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 0.5, 3),
		Size = UDim2.new(1, 0, 0, M.Name + 4), FontFace = BOLD, TextSize = M.Name,
		TextColor3 = pinned and T.YouText or T.Ink,
	})
	row.user = label(names, {
		Name = "Username", Position = UDim2.new(0, 0, 0.5, 3), Size = UDim2.new(1, 0, 0, M.User + 4),
		TextSize = M.User, TextColor3 = pinned and T.YouSub or T.InkSoft,
	})
	row.value = label(f, {
		Name = "Value", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.new(0, M.ValueW, 1, 0), FontFace = BOLD, TextSize = M.Value,
		TextColor3 = pinned and T.YouText or T.Ink,
		TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.None,
	})
	return row
end

-- e = { r = rank?, u = userId, n = username?, d = displayName?, v = value? }
-- isSelf: the local player's own row inside the list (gets a soft gold tint)
local function fillRow(row, e, kind, isSelf, alt)
	local medal = e.r and MEDAL[e.r]
	if not row.pinned then
		local bg = alt and T.CardAlt or T.Card
		if isSelf then bg = T.Card:Lerp(T.Gold, 0.18) elseif medal then bg = T.Card:Lerp(medal, 0.1) end
		row.frame.BackgroundColor3 = bg
		row.edge.Color = isSelf and T.Accent or (medal or T.CardEdge)
		row.edge.Transparency = (isSelf or medal) and 0.3 or 0
	end
	row.accent.Visible = medal ~= nil
	row.badge.BackgroundTransparency = medal and 0 or 1
	row.badgeStroke.Enabled = medal ~= nil
	if medal then
		row.accent.BackgroundColor3 = medal
		row.badge.BackgroundColor3 = medal
	end
	row.rank.Text = e.r and tostring(e.r) or "—"
	row.rank.TextColor3 = medal and T.Ink or (row.pinned and T.YouText or T.InkSoft)
	row.avatarStroke.Color = medal or (row.pinned and T.YouSub or T.CardEdge)
	local image = (e.u and e.u > 0) and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=60&h=60", e.u) or ""
	if row.avatar.Image ~= image then row.avatar.Image = image end
	row.name.Text = e.d or e.n or "Unknown player"
	row.user.Text = e.n and ("@" .. e.n) or (e.u and ("ID " .. e.u) or "")
	row.value.Text = e.v and Format.Value(kind, e.v) or "—"
end

---------------------------------------------------------------- construction
function View.new(parent, mode, callbacks)
	local self = setmetatable({}, View)
	self.mode = mode
	self.M = METRICS[mode]
	self.interactive = mode ~= "Board" -- gamepad selection lives in the ScreenGui
	self.callbacks = callbacks
	self.scroll = {}
	self.rows = {}
	self:_build(parent)
	return self
end

function View:_build(parent)
	local M = self.M
	local root = make("Frame", {
		Name = "Leaderboard", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
		ClipsDescendants = true,
	}, parent)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new(T.ScreenTop, T.Screen) }, root)
	local edge = M.Edge or 0
	make("UIPadding", {
		PaddingLeft = UDim.new(0, M.Pad + edge), PaddingRight = UDim.new(0, M.Pad + edge),
		PaddingTop = UDim.new(0, M.Pad - 4 + edge), PaddingBottom = UDim.new(0, M.Pad - 8 + edge),
	}, root)
	self.root = root
	local y = 0

	-- header: gold stud + title on the left, scope switch (and close) on the right
	local header = make("Frame", { Name = "Header", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, M.Header) }, root)
	local studSize = math.floor(M.Title * 0.34)
	local stud = make("Frame", {
		Name = "Stud", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
		Size = UDim2.fromOffset(studSize, studSize), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
	}, header)
	corner(stud, 2)
	local title = label(header, {
		Name = "Title", Text = "LEADERBOARD", FontFace = HEAD, TextScaled = true, TextColor3 = T.Ink,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, studSize + 12, 0.5, 0),
		Size = UDim2.new(1, -(studSize + 12 + M.ScopeW + (self.mode == "Board" and 16 or M.ScopeH + 24)), 0, M.Title + 4),
		TextTruncate = Enum.TextTruncate.None,
	})
	make("UITextSizeConstraint", { MaxTextSize = M.Title, MinTextSize = 12 }, title)

	local right = 0
	if self.mode ~= "Board" then
		local _, close = brownButton(header, {
			Name = "Close", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0),
			Size = UDim2.fromOffset(M.ScopeH, M.ScopeH),
		}, M.Lip, true)
		for _, rotation in { 45, -45 } do
			make("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0.44, 0, 0, 2),
				Rotation = rotation, BackgroundColor3 = T.ButtonText, BorderSizePixel = 0, ZIndex = 2,
			}, close)
		end
		close.Activated:Connect(function() self.callbacks.onClose() end)
		self.closeButton = close
		right = M.ScopeH + 8
	end

	-- scope switch: a brown track with a cashmere knob
	local scope = make("Frame", {
		Name = "Scope", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -right, 0.5, 0),
		Size = UDim2.fromOffset(M.ScopeW, M.ScopeH), BackgroundColor3 = T.ButtonActive, BorderSizePixel = 0,
	}, header)
	corner(scope, 8)
	stroke(scope, T.ButtonLip, 1)
	self.scopeKnob = make("Frame", {
		Name = "Knob", Position = UDim2.fromOffset(3, 3), Size = UDim2.new(0.5, -3, 1, -6),
		BackgroundColor3 = T.ScreenTop, BorderSizePixel = 0,
	}, scope)
	corner(self.scopeKnob, 6)
	self.scopeButtons = {}
	for i, id in { "Server", "Global" } do
		local button = make("TextButton", {
			Name = id, Position = UDim2.fromScale((i - 1) * 0.5, 0), Size = UDim2.fromScale(0.5, 1),
			BackgroundTransparency = 1, Text = id == "Server" and "THIS SERVER" or "GLOBAL", FontFace = BOLD,
			TextSize = M.Scope, TextColor3 = T.ButtonTextDim, AutoButtonColor = false, Selectable = self.interactive, ZIndex = 2,
		}, scope)
		button.Activated:Connect(function() self.callbacks.onScope(id) end)
		self.scopeButtons[id] = button
	end
	y += M.Header

	-- tabs: three brown buttons and a gold underline that slides beneath the selected one
	local tabs = make("Frame", {
		Name = "Tabs", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, M.Tabs),
	}, root)
	self.tabs = {}
	local count = #Config.Stats
	for i, stat in Config.Stats do
		local holder, face = brownButton(tabs, {
			Name = stat.Id, Position = UDim2.new((i - 1) / count, 3, 0, 0), Size = UDim2.new(1 / count, -6, 1, -7),
		}, M.Lip, self.interactive)
		local shine = make("Frame", {
			Name = "Shine", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0,
			Visible = false, ZIndex = 2,
		}, face)
		local gradient = make("UIGradient", {
			Rotation = 18, Offset = Vector2.new(-1, 0),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 1), NumberSequenceKeypoint.new(0.5, 0.78),
				NumberSequenceKeypoint.new(0.6, 1), NumberSequenceKeypoint.new(1, 1),
			}),
		}, shine)
		local text = label(face, {
			Name = "Label", Text = stat.Tab, FontFace = HEAD, TextScaled = true, TextColor3 = T.ButtonTextDim,
			TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, -10, 0, M.TabText + 2),
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), TextTruncate = Enum.TextTruncate.None,
			ZIndex = 3,
		})
		make("UITextSizeConstraint", { MaxTextSize = M.TabText, MinTextSize = 9 }, text)
		face.Activated:Connect(function() self.callbacks.onTab(stat.Id) end)
		self.tabs[i] = { id = stat.Id, holder = holder, button = face, text = text, shine = shine, gradient = gradient }
	end
	self.underline = make("Frame", {
		Name = "Underline", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 18, 1, 0),
		Size = UDim2.new(1 / count, -36, 0, 3), BackgroundColor3 = T.Accent, BorderSizePixel = 0,
	}, tabs)
	corner(self.underline, 2)
	y += M.Tabs + M.Gap

	-- column header
	if M.Column > 0 then
		local columns = make("Frame", {
			Name = "Columns", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, M.Column),
		}, root)
		label(columns, {
			Text = "#", FontFace = BOLD, TextSize = M.ColText, TextColor3 = T.InkFaint,
			TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0, M.Badge, 1, 0),
		})
		label(columns, {
			Text = "PLAYER", FontFace = BOLD, TextSize = M.ColText, TextColor3 = T.InkFaint,
			Position = UDim2.fromOffset(22 + M.Badge, 0), Size = UDim2.new(0, 160, 1, 0),
		})
		self.columnValue = label(columns, {
			Text = "", FontFace = BOLD, TextSize = M.ColText, TextColor3 = T.InkFaint,
			TextXAlignment = Enum.TextXAlignment.Right, AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -14 - M.Bar, 0, 0), Size = UDim2.new(0, M.ValueW, 1, 0),
		})
		y += M.Column
	end

	-- list (pooled rows, created on demand)
	local you = M.YouLabel + M.Row
	local bottom = you + M.Meta + M.Gap
	self.list = make("ScrollingFrame", {
		Name = "List", Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 1, -(y + bottom)),
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(), ScrollBarThickness = M.Bar,
		ScrollBarImageColor3 = T.Scroll, ScrollBarImageTransparency = 0.25, ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar, ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
		Selectable = self.interactive, SelectionGroup = false,
	}, root)

	-- states: loading / empty / unavailable
	local status = make("Frame", {
		Name = "Status", BackgroundTransparency = 1, Position = self.list.Position, Size = self.list.Size,
		Visible = false, ZIndex = 3,
	}, root)
	self.status = status
	self.statusTitle = label(status, {
		FontFace = HEAD, TextSize = M.Name + 3, TextColor3 = T.Ink, TextXAlignment = Enum.TextXAlignment.Center,
		AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.5, -20), Size = UDim2.new(1, -40, 0, M.Name + 8),
	})
	self.statusBody = label(status, {
		TextSize = M.User + 1, TextColor3 = T.InkSoft, TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, -14), Size = UDim2.new(1, -60, 0, (M.User + 3) * 2),
	})
	local statusHolder, statusFace = brownButton(status, {
		Name = "ViewServer", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.5, (M.User + 3) * 2 - 2),
		Size = UDim2.fromOffset(M.ScopeW - 20, M.ScopeH),
	}, M.Lip, self.interactive)
	label(statusFace, {
		Text = "VIEW THIS SERVER", FontFace = BOLD, TextSize = M.Scope, TextColor3 = T.ButtonText,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromScale(1, 1), ZIndex = 3,
	})
	statusFace.Activated:Connect(function() self.callbacks.onScope("Server") end)
	self.statusButton = statusHolder

	-- YOUR RANK, pinned under the list
	local youFrame = make("Frame", {
		Name = "YourRank", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 0, 1, -M.Meta),
		Size = UDim2.new(1, -M.Bar, 0, you), BackgroundTransparency = 1, -- -Bar keeps values aligned with the list
	}, root)
	label(youFrame, {
		Text = "YOUR RANK", FontFace = BOLD, TextSize = M.ColText, TextColor3 = T.Accent,
		Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -24, 0, M.YouLabel - 2),
	})
	self.youRow = buildRow(youFrame, M, "You", true)
	self.youRow.frame.Position = UDim2.fromOffset(0, M.YouLabel)

	-- meta line
	if M.Meta == 0 then return end
	self.metaLeft = label(root, {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 4, 1, 0), Size = UDim2.new(0.6, 0, 0, M.Meta),
		TextSize = M.MetaText, TextColor3 = T.InkFaint,
	})
	self.metaRight = label(root, {
		AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -4, 1, 0), Size = UDim2.new(0.4, 0, 0, M.Meta),
		TextSize = M.MetaText, TextColor3 = T.InkFaint, TextXAlignment = Enum.TextXAlignment.Right,
	})
end

function View:_row(i)
	local row = buildRow(self.list, self.M, "Row" .. i, false)
	row.frame.Position = UDim2.fromOffset(0, (i - 1) * self.M.Row + 1)
	self.rows[i] = row
	return row
end

---------------------------------------------------------------- state changes
function View:_selectTab(index, animate)
	for i, tab in self.tabs do
		local on = i == index
		local textGoal = { TextColor3 = on and T.ButtonText or T.ButtonTextDim }
		local faceGoal = { BackgroundColor3 = on and T.ButtonActive or T.Button }
		if animate then
			TweenService:Create(tab.text, QUICK, textGoal):Play()
			TweenService:Create(tab.button, QUICK, faceGoal):Play()
		else
			tab.text.TextColor3 = textGoal.TextColor3
			tab.button.BackgroundColor3 = faceGoal.BackgroundColor3
		end
	end
	local goal = UDim2.new((index - 1) / #self.tabs, 18, 1, 0)
	if animate then
		TweenService:Create(self.underline, SLIDE, { Position = goal }):Play()
		local tab = self.tabs[index]
		tab.gradient.Offset = Vector2.new(-1, 0)
		tab.shine.Visible = true
		local sweep = TweenService:Create(tab.gradient, SHINE, { Offset = Vector2.new(1, 0) })
		sweep.Completed:Once(function() tab.shine.Visible = false end)
		sweep:Play()
	else
		self.underline.Position = goal
	end
	self.tabIndex = index
end

function View:_selectScope(scope, animate)
	local goal = scope == "Server" and UDim2.fromOffset(3, 3) or UDim2.new(0.5, 0, 0, 3)
	if animate then TweenService:Create(self.scopeKnob, QUICK, { Position = goal }):Play() else self.scopeKnob.Position = goal end
	for id, button in self.scopeButtons do
		local color = id == scope and T.Ink or T.ButtonTextDim
		if animate then TweenService:Create(button, QUICK, { TextColor3 = color }):Play() else button.TextColor3 = color end
	end
	self.scopeId = scope
end

function View:_setStatus(title, body, showButton)
	self.status.Visible = title ~= nil
	if title then
		self.statusTitle.Text = title
		self.statusBody.Text = body or ""
		self.statusButton.Visible = showButton == true
	end
end

function View:_meta(state)
	if not self.metaLeft then return end
	local snap = state.snapshot
	if state.scope == "Server" then
		local n = snap and snap.total
		self.metaLeft.Text = n and string.format("THIS SERVER  ·  %d ranked", n) or "THIS SERVER"
	else
		self.metaLeft.Text = "GLOBAL  ·  all servers, top " .. Config.MaxRows
	end
	local right = ""
	if snap and snap.updated then
		local age = workspace:GetServerTimeNow() - snap.updated
		if snap.status == "stale" then
			right = "Couldn't refresh  ·  from " .. Format.Age(age)
		else
			right = "Updated " .. Format.Age(age)
		end
	end
	self.metaRight.Text = right
end

---------------------------------------------------------------- public
--[[ state = {
	tab, scope, phase = "loading" | "ready" | "error",
	snapshot = { status, entries, total, updated, depth, you = { r, v } } | nil,
	localUserId, localName, localDisplayName,
} ]]
function View:Render(state)
	self.state = state
	local stat = Config.StatById[state.tab]
	local index = 1
	for i, tab in self.tabs do if tab.id == state.tab then index = i end end
	if index ~= self.tabIndex then self:_selectTab(index, self.tabIndex ~= nil) end
	if state.scope ~= self.scopeId then self:_selectScope(state.scope, self.scopeId ~= nil) end
	if self.columnValue then self.columnValue.Text = stat.Column end

	-- remember scroll per tab + scope; a data update for the same key never moves the list
	local key = state.tab .. "|" .. state.scope
	local restore
	if key ~= self.key then
		if self.key then self.scroll[self.key] = self.list.CanvasPosition end
		self.key = key
		restore = self.scroll[key] or Vector2.zero
	end

	local snap = state.snapshot
	local entries = snap and snap.entries or {}
	local count = math.min(#entries, Config.MaxRows)
	for i = 1, count do
		local row = self.rows[i] or self:_row(i)
		local e = entries[i]
		fillRow(row, e, stat.Kind, e.u == state.localUserId, i % 2 == 0)
		row.frame.Visible = true
	end
	for i = count + 1, #self.rows do self.rows[i].frame.Visible = false end
	self.list.CanvasSize = UDim2.fromOffset(0, count * self.M.Row + 2)
	if restore then
		local list = self.list
		task.defer(function() if list.Parent then list.CanvasPosition = restore end end)
	end

	-- loading / empty / unavailable
	local status = snap and snap.status
	if count > 0 then
		self:_setStatus(nil)
	elseif state.phase == "error" and not snap then
		self:_setStatus("Couldn't load rankings", "Trying again in a few seconds.")
	elseif state.phase == "loading" or status == "loading" then
		self:_setStatus("Loading rankings...", "Fetching the latest scores.")
	elseif status == "unavailable" then
		self:_setStatus("Global rankings unavailable", "We couldn't reach the global scores. They'll be back shortly.", true)
	else
		self:_setStatus("No rankings yet", stat.Empty)
	end

	-- YOUR RANK
	local you = snap and snap.you
	local mine = {
		r = you and you.r, u = state.localUserId, n = state.localName, d = state.localDisplayName, v = you and you.v,
	}
	fillRow(self.youRow, mine, stat.Kind, false, false)
	if not mine.r then
		local note
		if not snap or status == "loading" then
			note = "Loading"
		elseif status == "unavailable" then
			note = "Global unavailable"
		elseif state.scope == "Global" and mine.v and mine.v > 0 then
			note = (snap.total or 0) >= (snap.depth or 100) and ("Outside top " .. (snap.depth or 100)) or "Not on the global board yet"
		else
			note = "Not ranked yet"
		end
		self.youRow.user.Text = "@" .. state.localName .. "  ·  " .. note
	end

	self:_meta(state)
end

function View:Tick()
	if self.state then self:_meta(self.state) end
end

function View:DefaultSelection()
	local tab = self.tabs[self.tabIndex or 1]
	return tab and tab.button
end

function View:Destroy()
	if self.root then self.root:Destroy() end
	self.root = nil
end

return View
