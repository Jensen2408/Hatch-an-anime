--[[ ReplicatedStorage.CharacterInventory.InventoryView  (ModuleScript)
Builds and renders the inventory panel. It owns no game state: InventoryClient hands it a state
table and receives the player's intents through callbacks.

Two layouts:
  • "Wide"    desktop / tablet: header, toolbar, card grid and a details column side by side.
  • "Compact" phones / small windows: tighter metrics, details open as a sheet over the grid.

The grid is virtualized: only the visible rows (plus one row above and below) exist as cards, and
cards are pooled and re-used while scrolling. Card portraits are static ViewportFrames that are only
re-framed when a card shows a different character. Only the single details portrait turns slowly.
]]
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.InventoryConfig)
local Format = require(script.Parent.InventoryFormat)
local Model = require(script.Parent.InventoryModel)
local Style = require(script.Parent.InventoryStyle)
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))

local T = Config.Theme
local F = Config.Fonts
local make, text, chip = Style.Make, Style.Text, Style.Chip
local SHEET = TweenInfo.new(0.22, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

local View = {}
View.__index = View

---------------------------------------------------------------- portraits
local portraitFolder
local function portraitTemplate(item)
	portraitFolder = portraitFolder or ReplicatedStorage.CharacterInventory:FindFirstChild(Config.PortraitFolder)
	if not portraitFolder then return nil end
	return (item.golden and portraitFolder:FindFirstChild(item.characterId .. "_Golden"))
		or portraitFolder:FindFirstChild(item.characterId)
end

local function newViewport(parent, props)
	local vp = make("ViewportFrame", {
		Name = "Portrait", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1),
		Ambient = Color3.fromRGB(168, 170, 182), LightColor = Color3.fromRGB(255, 249, 238),
		LightDirection = Vector3.new(-0.55, -1, -0.65),
	}, parent)
	for k, v in props or {} do vp[k] = v end
	return vp
end

-- Puts a fresh copy of the character in the viewport (only when the character changes).
local function showPortrait(vp, item, key)
	if vp:GetAttribute("Key") == key then return end
	vp:SetAttribute("Key", key)
	for _, c in vp:GetChildren() do if c:IsA("Model") then c:Destroy() end end
	local template = item and portraitTemplate(item)
	if not template then return end
	local copy = template:Clone()
	copy.Parent = vp
	Style.FrameModel(vp, copy, 20, 1.08)
	return copy
end

---------------------------------------------------------------- small parts
local function statRow(parent, label, order, valueSize)
	local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, valueSize + 6), LayoutOrder = order }, parent)
	text(row, { Text = label, FontFace = F.Bold, TextSize = 11, TextColor3 = T.Muted, Size = UDim2.new(0.45, 0, 1, 0) })
	local value = text(row, {
		Name = "Value", Text = "", FontFace = F.Bold, TextSize = valueSize, TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.55, 0, 1, 0),
	})
	return row, value
end

---------------------------------------------------------------- construction
function View.new(gui, mode, density, callbacks)
	local self = setmetatable({}, View)
	self.gui = gui
	self.mode = mode
	self.density = density -- Wide only: "Full" (names + sort buttons) | "Roomy" (names) | "Dense" (short names)
	self.cb = callbacks
	self.M = mode == "Compact" and Config.Layout.Compact or Config.Layout.Wide
	self.cards = {}       -- pool
	self.list = {}        -- filtered + sorted items currently shown
	self.connections = {}
	self.state = nil
	self.detailsOpen = mode ~= "Compact"
	self:_build()
	return self
end

function View:_connect(signal, fn)
	local c = signal:Connect(function(...)
		UISound.Play("Click")
		fn(...)
	end)
	table.insert(self.connections, c)
	return c
end

function View:_build()
	local compact = self.mode == "Compact"
	local pad = compact and 8 or 12

	-- the shrine shell: tile roof, gold studs and a dark-wood page, the same build as the leaderboard's expanded view
	local root = Style.Shell(self.gui, {
		Name = "InventoryPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(800, 520), Active = true,
	}, 12)
	self.root = root
	self.scale = make("UIScale", { Scale = 1 }, root)
	self.roofH = compact and 16 or 22
	Style.Roof(root, self.roofH)
	local band = Style.StudBand(root, 6, 26, 6, 2)
	band.Position = UDim2.fromOffset(20, 6)
	band.Size = UDim2.new(1, -40, 0, 6)
	local page = Style.Page(root, 8, 16, 8, 8, 8)
	self.page = page

	------------------------------------------------ header
	local headerY = compact and 6 or 10
	local headerH = compact and 32 or 40
	local header = make("Frame", {
		Name = "Header", BackgroundTransparency = 1, Position = UDim2.fromOffset(pad, headerY),
		Size = UDim2.new(1, -pad * 2, 0, headerH),
	}, page)
	local left = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X }, header)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, compact and 8 or 12), SortOrder = Enum.SortOrder.LayoutOrder,
	}, left)
	self.title = text(left, {
		Text = "CHARACTERS", FontFace = F.Head, TextSize = compact and 22 or 27, AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.new(0, 0, 1, 0), TextTruncate = Enum.TextTruncate.None, LayoutOrder = 1,
	})
	Style.GoldText(self.title, compact and 2 or 3)
	self.owned = text(left, {
		Text = "", FontFace = F.Bold, TextSize = compact and 11 or 13, TextColor3 = T.PageMuted, LayoutOrder = 2,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.new(0, 0, 1, 0), TextTruncate = Enum.TextTruncate.None,
	})
	Style.Pad(self.owned, 0, compact and 4 or 6, 0, 0)

	local right = make("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X,
	}, header)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, compact and 8 or 12),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, right)

	-- capacity: "SLOTS 4 / 6" + one pip per slot
	local cap = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(compact and 74 or 150, headerH), LayoutOrder = 1 }, right)
	self.capLabel = text(cap, {
		Text = "SLOTS", FontFace = F.Bold, TextSize = 10, TextColor3 = T.PageMuted, Size = UDim2.new(1, 0, 0, 12),
		Position = UDim2.fromOffset(0, compact and 1 or 2), TextXAlignment = Enum.TextXAlignment.Right,
	})
	self.capValue = text(cap, {
		Text = "–", FontFace = F.Heavy, TextSize = compact and 15 or 17, TextColor3 = T.PageText, Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, compact and 12 or 13), TextXAlignment = Enum.TextXAlignment.Right,
	})
	self.pips = make("Frame", {
		BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 6), Position = UDim2.fromOffset(0, compact and 32 or 33),
		Visible = not compact,
	}, cap)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right,
		Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder,
	}, self.pips)

	self.bestButton = Style.Button(right, "PLACE BEST", "Primary", {
		Size = UDim2.fromOffset(compact and 112 or 160, compact and 30 or 38), LayoutOrder = 2,
		TextSize = compact and 15 or 17, TextYAlignment = compact and Enum.TextYAlignment.Center or Enum.TextYAlignment.Top,
	})
	if not compact then
		Style.Pad(self.bestButton, 0, 4, 0, 0)
		self.bestSub = text(self.bestButton, {
			Text = "", FontFace = F.Bold, TextSize = 11, TextColor3 = T.Ink, TextTransparency = 0.15,
			Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 13), TextXAlignment = Enum.TextXAlignment.Center,
		})
	end
	self:_connect(self.bestButton.Activated, function()
		if Style.Enabled(self.bestButton) then self.cb.onAction("PlaceBest") end
	end)

	self.closeButton = Style.Button(right, "×", "Secondary", {
		Size = UDim2.fromOffset(compact and 30 or 34, compact and 30 or 34), TextSize = compact and 20 or 22,
		FontFace = F.Bold, LayoutOrder = 3,
	})
	self:_connect(self.closeButton.Activated, function() self.cb.onClose() end)

	------------------------------------------------ toolbar
	local toolY = headerY + headerH + (compact and 4 or 6)
	local toolH = compact and 28 or 32
	local toolbar = make("Frame", {
		Name = "Toolbar", BackgroundTransparency = 1, Position = UDim2.fromOffset(pad, toolY),
		Size = UDim2.new(1, -pad * 2, 0, toolH),
	}, page)
	local searchW = compact and 140 or (self.density == "Full" and 220 or (self.density == "Roomy" and 190 or 170))
	local searchWell = Style.Inset(toolbar, { Size = UDim2.fromOffset(searchW, toolH), BackgroundColor3 = T.Card }, 7)
	self.search = make("TextBox", {
		Name = "Search", BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(1, -20, 1, 0),
		FontFace = F.Body, TextSize = compact and 12 or 13, TextColor3 = T.Text, PlaceholderText = "Search characters",
		PlaceholderColor3 = T.Faint, Text = "", ClearTextOnFocus = false, TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3, Selectable = true,
	}, searchWell)
	local searchSeq = 0
	self:_connect(self.search:GetPropertyChangedSignal("Text"), function()
		searchSeq += 1
		local mine = searchSeq
		task.delay(0.12, function() if mine == searchSeq then self.cb.onSearch(self.search.Text) end end)
	end)

	local chips = make("Frame", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(searchW + 10, 0),
		Size = UDim2.new(1, -(searchW + 10), 1, 0),
	}, toolbar)
	self.chips = chips
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center,
		Padding = UDim.new(0, compact and 4 or 6), SortOrder = Enum.SortOrder.LayoutOrder,
	}, chips)
	self.rarityButtons = {}
	local function rarityButton(id, label, color, order)
		local b = Style.Button(chips, label, "Secondary", {
			Size = UDim2.fromOffset(0, toolH), AutomaticSize = Enum.AutomaticSize.X, TextSize = compact and 11 or 12,
			LayoutOrder = order,
		})
		Style.Pad(b, color and (compact and 20 or 24) or 10, 0, compact and 8 or 10, 0)
		if color then
			local sw = make("Frame", {
				BorderSizePixel = 0, BackgroundColor3 = color, Size = UDim2.fromOffset(8, 8), AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, compact and -12 or -14, 0.5, 0), ZIndex = b.ZIndex + 1,
			}, b)
			Style.Corner(sw, 2)
		end
		self:_connect(b.Activated, function() self.cb.onRarity(id) end)
		self.rarityButtons[id or "All"] = b
		return b
	end
	local SHORT = { Common = "COM", Uncommon = "UNC", Rare = "RARE", Epic = "EPIC", Legendary = "LEG" }
	rarityButton(nil, "ALL", nil, 0)
	for i, r in Config.Rarities do
		local label = compact and r:sub(1, 1) or (self.density == "Dense" and SHORT[r] or string.upper(r))
		rarityButton(r, label, T.Rarity[r], i)
	end

	-- sort: segmented control (full width) or one cycling button (dense / compact)
	local spacer = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(compact and 4 or 12, 1), LayoutOrder = 10 }, chips)
	spacer.Name = "Spacer"
	self.sortButtons = {}
	if compact or self.density ~= "Full" then
		local b = Style.Button(chips, "POWER ▼", "Secondary", {
			Size = UDim2.fromOffset(0, toolH), AutomaticSize = Enum.AutomaticSize.X, TextSize = 11, LayoutOrder = 11,
		})
		Style.Pad(b, 10, 0, 10, 0)
		Style.SetOn(b, true)
		self.sortCycle = b
		self:_connect(b.Activated, function() self.cb.onSort(nil) end)
	else
		text(chips, {
			Text = "SORT", FontFace = F.Bold, TextSize = 10, TextColor3 = T.PageMuted, Size = UDim2.fromOffset(30, toolH),
			LayoutOrder = 11, TextXAlignment = Enum.TextXAlignment.Right,
		})
		for i, s in Config.Sorts do
			local b = Style.Button(chips, s.Label, "Secondary", {
				Size = UDim2.fromOffset(0, toolH), AutomaticSize = Enum.AutomaticSize.X, TextSize = 12, LayoutOrder = 11 + i,
			})
			Style.Pad(b, 10, 0, 10, 0)
			self.sortButtons[s.Id] = b
			self:_connect(b.Activated, function() self.cb.onSort(s.Id) end)
		end
	end

	------------------------------------------------ body
	local bodyY = toolY + toolH + (compact and 6 or 8)
	local footer = compact and 16 or 20
	local detailsW = compact and 0 or Config.Layout.DetailsWidth
	local body = make("Frame", {
		Name = "Body", BackgroundTransparency = 1, Position = UDim2.fromOffset(pad, bodyY),
		Size = UDim2.new(1, -pad * 2, 1, -(bodyY + footer + (compact and 2 or 4))),
		ClipsDescendants = compact, -- the details sheet slides up from inside the body
	}, page)
	self.body = body

	-- the cards sit straight on the dark-wood page (no extra box around them)
	local gridWell = make("Frame", {
		Name = "GridWell", BackgroundTransparency = 1, ClipsDescendants = true,
		Size = UDim2.new(1, compact and 0 or -(detailsW + 8), 1, 0),
	}, body)
	self.gridWell = gridWell
	self.grid = make("ScrollingFrame", {
		Name = "Grid", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1),
		CanvasSize = UDim2.new(), ScrollBarThickness = compact and 4 or 6, ScrollBarImageColor3 = T.CardEdge,
		ScrollingDirection = Enum.ScrollingDirection.Y, VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.WhenScrollable, ZIndex = 2, Selectable = false,
		ScrollBarImageTransparency = 0.25,
	}, gridWell)
	self:_connect(self.grid:GetPropertyChangedSignal("CanvasPosition"), function() self:_layoutGrid(false) end)
	self:_connect(self.grid:GetPropertyChangedSignal("AbsoluteSize"), function() self:_layoutGrid(true) end)

	-- placeholder (loading / empty / no results)
	local note = make("Frame", {
		Name = "Note", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46),
		Size = UDim2.fromOffset(compact and 360 or 450, 200), Visible = false, ZIndex = 5,
	}, gridWell)
	self.noteIcon = make("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(32, 32), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), ZIndex = 5 }, note)
	for i = 0, 3 do
		Style.Stud(self.noteIcon, (i % 2) * 18, math.floor(i / 2) * 18, 14, 6)
	end
	self.noteTitle = text(note, {
		Text = "", FontFace = F.Head, TextSize = compact and 18 or 22, TextColor3 = T.PageText, Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5,
	})
	self.noteBody = text(note, {
		Text = "", TextColor3 = T.PageMuted, TextSize = compact and 12 or 14, Position = UDim2.fromOffset(0, 70),
		Size = UDim2.new(1, 0, 0, 36), TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5, TextTruncate = Enum.TextTruncate.None,
	})
	self.noteButton = Style.Button(note, "CLEAR FILTERS", "Secondary", {
		AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108), Size = UDim2.fromOffset(140, 32),
		Visible = false, ZIndex = 5,
	})
	self:_connect(self.noteButton.Activated, function() self.cb.onClearFilters() end)
	-- first visit: hatch, collect, come back
	self.steps = make("Frame", {
		Name = "Steps", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 108),
		Size = UDim2.new(1, 0, 0, compact and 76 or 86), Visible = false, ZIndex = 5,
	}, note)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, self.steps)
	for i, s in { { "Hatch an egg", "Hold an egg at your chamber" }, { "Collect it", "Every hatch rolls its own Power" }, { "Come back here", "Place your best on the temple" } } do
		local card = make("Frame", { BackgroundColor3 = T.Card, BorderSizePixel = 0, Size = UDim2.new(1 / 3, -6, 1, 0), LayoutOrder = i, ZIndex = 5 }, self.steps)
		Style.Corner(card, 10)
		Style.Stroke(card, T.CardEdge, 1)
		chip(card, tostring(i), T.ChipOn, { TextColor3 = T.ButtonText, Position = UDim2.fromOffset(8, 8), ZIndex = 6, TextSize = 11, Size = UDim2.fromOffset(0, 18) })
		text(card, { Text = s[1], FontFace = F.Head, TextSize = compact and 13 or 15, Position = UDim2.fromOffset(8, 30), Size = UDim2.new(1, -16, 0, 18), ZIndex = 6 })
		text(card, {
			Text = s[2], TextSize = 11, TextColor3 = T.Muted, TextWrapped = true, TextTruncate = Enum.TextTruncate.None,
			TextYAlignment = Enum.TextYAlignment.Top, Position = UDim2.fromOffset(8, 50), Size = UDim2.new(1, -16, 0, 30), ZIndex = 6,
		})
	end
	self.note = note

	-- skeleton cards while loading (one CanvasGroup pulses, nothing else animates)
	self.skeleton = make("CanvasGroup", {
		Name = "Skeleton", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false, ZIndex = 3,
	}, gridWell)

	------------------------------------------------ details
	local details
	details = Style.Inset(body, compact and {
		Name = "DetailsSheet", Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 1.1),
		Visible = false, ZIndex = 20, BackgroundColor3 = T.Card,
	} or {
		Name = "Details", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, detailsW, 1, 0), BackgroundColor3 = T.Card,
	}, 8)
	local detailsEdge = details:FindFirstChildOfClass("UIStroke")
	detailsEdge.Color, detailsEdge.Thickness = T.Gold, 2
	self.details = details
	self:_buildDetails(details)

	------------------------------------------------ footer: hints + toast
	self.hint = text(page, {
		Name = "Hint", Text = "", FontFace = F.Bold, TextSize = 11, TextColor3 = T.PageMuted,
		Position = UDim2.new(0, pad, 1, -(footer + 1)), Size = UDim2.new(0.6, 0, 0, footer),
	})
	self.toast = text(page, {
		Name = "Toast", Text = "", FontFace = F.Bold, TextSize = compact and 11 or 13, TextColor3 = T.PageText,
		AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -pad, 1, -(footer + 1)), Size = UDim2.new(0.5, 0, 0, footer),
		TextXAlignment = Enum.TextXAlignment.Right, TextTransparency = 1,
	})
end

function View:_buildDetails(parent)
	local compact = self.mode == "Compact"
	local d = {}
	self.d = d
	local footerH = compact and 90 or 98
	local scroll = make("ScrollingFrame", {
		Name = "Scroll", BackgroundTransparency = 1, BorderSizePixel = 0, Size = UDim2.new(1, 0, 1, -footerH),
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 4,
		ScrollBarImageColor3 = T.Faint, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = parent.ZIndex + 1,
		Selectable = false,
	}, parent)
	Style.Pad(scroll, 12, compact and 10 or 12, 12, 12)
	make("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, scroll)
	d.scroll = scroll

	-- empty selection
	d.empty = text(scroll, {
		Text = "Select a character to see its exact Power, income and actions.", TextColor3 = T.Muted, TextSize = 13,
		TextWrapped = true, Size = UDim2.new(1, 0, 0, 60), TextXAlignment = Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.None, LayoutOrder = 0,
	})

	local content = make("Frame", {
		Name = "Content", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 1, Visible = false,
	}, scroll)
	make("UIListLayout", { Padding = UDim.new(0, compact and 6 or 8), SortOrder = Enum.SortOrder.LayoutOrder }, content)
	d.content = content

	if compact then
		d.back = Style.Button(content, "‹ BACK", "Secondary", { Size = UDim2.fromOffset(84, 28), TextSize = 12, LayoutOrder = 0 })
		self:_connect(d.back.Activated, function() self.cb.onSelect(nil) end)
	end

	local portraitWell = Style.Inset(content, { Size = UDim2.new(1, 0, 0, compact and 120 or 140), LayoutOrder = 1 }, 6)
	portraitWell.BackgroundColor3 = T.Portrait
	d.rarityGlow = make("Frame", {
		BorderSizePixel = 0, BackgroundColor3 = T.Rarity.Common, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 0,
	}, portraitWell)
	make("UIGradient", {
		Rotation = 90, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.55, 0.96), NumberSequenceKeypoint.new(1, 0.78),
		}),
	}, d.rarityGlow)
	d.viewport = newViewport(portraitWell, { ZIndex = portraitWell.ZIndex + 1 })

	d.name = text(content, {
		Text = "", FontFace = F.Head, TextSize = compact and 20 or 22, Size = UDim2.new(1, 0, 0, compact and 24 or 26), LayoutOrder = 2,
	})
	local chipsRow = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 3 }, content)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, chipsRow)
	d.rarityChip = chip(chipsRow, "", T.Rarity.Common, { LayoutOrder = 1, Size = UDim2.fromOffset(0, 18), TextSize = 11 })
	d.qualityChip = chip(chipsRow, "", T.Portrait, { LayoutOrder = 2, Size = UDim2.fromOffset(0, 18), TextSize = 11 })
	d.stateChip = chip(chipsRow, "", T.Placed, { LayoutOrder = 3, Size = UDim2.fromOffset(0, 18), TextSize = 11 })

	-- Power and income: two big tiles side by side, exact Power underneath
	local tiles = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, compact and 62 or 68), LayoutOrder = 4 }, content)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, tiles)
	local powerTile = Style.Inset(tiles, { Size = UDim2.new(0.56, -4, 1, 0), BackgroundColor3 = T.Panel, LayoutOrder = 1 }, 8)
	powerTile:FindFirstChildOfClass("UIStroke").Color = T.Gold
	Style.Pad(powerTile, 10, 6, 10, 6)
	text(powerTile, { Text = "POWER", FontFace = F.Bold, TextSize = 10, TextColor3 = T.ButtonTextDim, Size = UDim2.new(1, 0, 0, 12) })
	d.power = text(powerTile, {
		Text = "", FontFace = F.Heavy, TextSize = compact and 26 or 30, TextColor3 = T.GoldHi, Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 1, -14), TextTruncate = Enum.TextTruncate.None,
	})
	local incomeTile = Style.Inset(tiles, { Size = UDim2.new(0.44, -4, 1, 0), BackgroundColor3 = T.IncomeTile, LayoutOrder = 2 }, 8)
	incomeTile:FindFirstChildOfClass("UIStroke").Color = T.Income
	Style.Pad(incomeTile, 10, 6, 10, 6)
	text(incomeTile, { Text = "INCOME / SEC", FontFace = F.Bold, TextSize = 10, TextColor3 = T.IncomeLight, Size = UDim2.new(1, 0, 0, 12) })
	d.income = text(incomeTile, {
		Text = "", FontFace = F.Heavy, TextSize = compact and 17 or 19, TextColor3 = T.IncomeLight, Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 1, -14), TextTruncate = Enum.TextTruncate.None,
	})
	local exactRow = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 5 }, content)
	d.exact = text(exactRow, { Text = "", FontFace = F.Body, TextSize = 12, TextColor3 = T.Muted, Size = UDim2.new(0.62, 0, 1, 0) })
	d.multiplier = text(exactRow, {
		Text = "", FontFace = F.Bold, TextSize = 11, TextColor3 = T.Muted, AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0), Size = UDim2.new(0.38, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right,
	})
	local eventRow, eventValue = statRow(content, "OWNER EVENT", 6, 12)
	d.eventRow, d.eventValue = eventRow, eventValue
	local _, base = statRow(content, "BASE POWER", 7, 13)
	d.base = base
	local slotRow, slotValue = statRow(content, "SLOT", 8, 13)
	d.slotRow, d.slotValue = slotRow, slotValue
	local _, acquired = statRow(content, "ACQUIRED", 9, 13)
	d.acquired = acquired

	-- comparison
	local compareWell = Style.Inset(content, { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 10 }, 6)
	Style.Pad(compareWell, 12, 9, 12, 9)
	make("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder }, compareWell)
	d.compareTitle = text(compareWell, { Text = "", FontFace = F.Bold, TextSize = 11, TextColor3 = T.Muted, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 1 })
	local function deltaRow(label, order)
		local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 20), LayoutOrder = order }, compareWell)
		text(row, { Text = label, FontFace = F.Bold, TextSize = 11, TextColor3 = T.Muted, Size = UDim2.new(0.34, 0, 1, 0) })
		local value = text(row, {
			Text = "", FontFace = F.Bold, TextSize = 14, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -52, 0, 0),
			Size = UDim2.new(0.66, -52, 1, 0), TextXAlignment = Enum.TextXAlignment.Right,
		})
		local rel = text(row, {
			Text = "", FontFace = F.Bold, TextSize = 11, TextColor3 = T.Muted, AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0), Size = UDim2.new(0, 48, 1, 0), TextXAlignment = Enum.TextXAlignment.Right,
		})
		return row, value, rel
	end
	d.cmpPowerRow, d.cmpPower, d.cmpPowerRel = deltaRow("POWER", 2)
	d.cmpIncomeRow, d.cmpIncome, d.cmpIncomeRel = deltaRow("INCOME", 3)
	d.compareNone = text(compareWell, { Text = "Nothing to compare yet.", TextColor3 = T.Muted, TextSize = 12, Size = UDim2.new(1, 0, 0, 16), LayoutOrder = 4 })

	-- actions
	-- pinned to the bottom of the panel so the actions never scroll out of view
	local footer = make("Frame", {
		Name = "Actions", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, footerH), ZIndex = parent.ZIndex + 1, Visible = false,
	}, parent)
	Style.Pad(footer, 12, 8, 12, compact and 10 or 12)
	make("UIListLayout", {
		Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, VerticalAlignment = Enum.VerticalAlignment.Bottom,
	}, footer)
	make("Frame", { BorderSizePixel = 0, BackgroundColor3 = T.CardEdge, Size = UDim2.new(1, 0, 0, 1), LayoutOrder = 0 }, footer)
	d.footer = footer
	local actions = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, compact and 34 or 38), LayoutOrder = 2 }, footer)
	make("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder,
	}, actions)
	d.primary = Style.Button(actions, "PLACE", "Primary", { Size = UDim2.new(0.5, -4, 1, 0), LayoutOrder = 1 })
	d.secondary = Style.Button(actions, "HOLD", "Secondary", { Size = UDim2.new(0.3, -4, 1, 0), LayoutOrder = 2 })
	d.pin = Style.Button(actions, "PIN", "Ghost", { Size = UDim2.new(0.2, -8, 1, 0), LayoutOrder = 3, TextSize = 11 })
	d.reason = text(footer, {
		Text = "", TextColor3 = T.Warn, TextSize = 11, TextWrapped = true, Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y, TextTruncate = Enum.TextTruncate.None, LayoutOrder = 1,
	})
	local function fire(button)
		local spec = button:GetAttribute("Action")
		if spec and Style.Enabled(button) and self.selected then self.cb.onAction(spec, self.selected.id) end
	end
	self:_connect(d.primary.Activated, function() fire(d.primary) end)
	self:_connect(d.secondary.Activated, function() fire(d.secondary) end)
	self:_connect(d.pin.Activated, function()
		if self.selected and Style.Enabled(d.pin) then self.cb.onPin(self.selected.id) end
	end)
end

---------------------------------------------------------------- cards
function View:_newCard()
	local M = self.M
	local compact = self.mode == "Compact"
	local c = {}
	local f = make("TextButton", {
		Name = "Card", AutoButtonColor = false, Text = "", BackgroundColor3 = T.Card, BorderSizePixel = 0,
		Size = UDim2.fromOffset(M.CardW, M.CardH), Selectable = true, ZIndex = 3, Visible = false,
	}, self.grid)
	Style.Corner(f, 8)
	c.stroke = Style.Stroke(f, T.CardEdge, 1)
	make("Frame", { -- top light
		BorderSizePixel = 0, BackgroundColor3 = T.CardHi, Size = UDim2.new(1, -14, 0, 1),
		Position = UDim2.fromOffset(7, 1), ZIndex = 4,
	}, f)
	c.frame = f

	local portrait = Style.Inset(f, {
		Position = UDim2.fromOffset(6, 6), Size = UDim2.new(1, -12, 0, M.Portrait), BackgroundColor3 = T.Portrait, ZIndex = 4,
	}, 6)
	c.glow = make("Frame", { BorderSizePixel = 0, BackgroundColor3 = T.Rarity.Common, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, portrait)
	make("UIGradient", {
		Rotation = 90, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.5, 0.62), NumberSequenceKeypoint.new(1, 0.35),
		}),
	}, c.glow)
	c.viewport = newViewport(portrait, { ZIndex = 5 })
	-- static diagonal sheen, only on unusual rolls
	c.sheen = make("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), ZIndex = 6, Visible = false }, portrait)
	make("UIGradient", {
		Rotation = 35, Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.86),
			NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
		}),
	}, c.sheen)
	c.rarity = chip(portrait, "", T.Rarity.Common, { Position = UDim2.fromOffset(5, 5), ZIndex = 7, TextSize = compact and 9 or 10, Size = UDim2.fromOffset(0, compact and 14 or 16) })
	c.quality = chip(portrait, "", T.Ink, {
		AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 5, 1, -5), ZIndex = 7, TextSize = compact and 9 or 10,
		Size = UDim2.fromOffset(0, compact and 14 or 16), BackgroundTransparency = 0.15,
	})

	local y = 6 + M.Portrait + (compact and 5 or 6)
	c.name = text(f, {
		Text = "", FontFace = F.Head, TextSize = compact and 15 or 17, Position = UDim2.fromOffset(8, y),
		Size = UDim2.new(1, -16, 0, compact and 18 or 20), ZIndex = 4,
	})
	y += compact and 19 or 21
	text(f, {
		Text = "POWER", FontFace = F.Bold, TextSize = compact and 9 or 10, TextColor3 = T.Muted, Position = UDim2.fromOffset(8, y),
		Size = UDim2.new(1, -16, 0, 11), ZIndex = 4,
	})
	y += compact and 10 or 11
	c.power = text(f, {
		Text = "", FontFace = F.Heavy, TextSize = compact and 22 or 26, Position = UDim2.fromOffset(8, y),
		Size = UDim2.new(1, -16, 0, compact and 24 or 28), ZIndex = 4, TextTruncate = Enum.TextTruncate.None,
	})
	y += compact and 24 or 28
	c.income = text(f, {
		Text = "", FontFace = F.Bold, TextSize = compact and 12 or 13, TextColor3 = T.Income, Position = UDim2.fromOffset(8, y),
		Size = UDim2.new(1, -16, 0, 16), ZIndex = 4,
	})
	-- placed / held state sits on the income line: a placed character is the one earning
	c.stateChip = chip(f, "", T.Placed, {
		AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -8, 0, y + 8), ZIndex = 5, TextSize = compact and 9 or 10,
		Size = UDim2.fromOffset(0, compact and 14 or 16),
	})

	f.MouseEnter:Connect(function() c.hover = true self:_paintCard(c) end)
	f.MouseLeave:Connect(function() c.hover = false self:_paintCard(c) end)
	f.SelectionGained:Connect(function() c.hover = true self:_paintCard(c) end)
	f.SelectionLost:Connect(function() c.hover = false self:_paintCard(c) end)
	f.Activated:Connect(function() if c.item then self.cb.onSelect(c.item.id) end end)
	return c
end

function View:_paintCard(c)
	local item = c.item
	if not item then return end
	local selected = self.state and self.state.selectedId == item.id
	local notable = item.qualityRank >= Config.NotableRank
	c.frame.BackgroundColor3 = c.hover and T.CardHover or T.Card
	if selected then
		c.stroke.Color, c.stroke.Thickness = T.Accent, 2.5
	elseif notable then
		c.stroke.Color, c.stroke.Thickness = Style.Deep(item.qualityColor), 1.5
	else
		c.stroke.Color, c.stroke.Thickness = Style.Deep(T.Rarity[item.rarity] or T.CardEdge):Lerp(T.CardEdge, 0.3), 1.5 -- rarity-coloured edge
	end
end

function View:_assignCard(c, item, multiplier)
	c.item = item
	local key = item.id .. "|" .. item.power .. "|" .. item.state .. "|" .. tostring(item.slot) .. "|" .. multiplier
	if c.key ~= key then
		c.key = key
		local rarityColor = T.Rarity[item.rarity] or T.Rarity.Common
		c.glow.BackgroundColor3 = rarityColor
		c.rarity.Text = string.upper(item.rarity)
		c.rarity.BackgroundColor3 = rarityColor
		c.name.Text = item.name
		c.power.Text = Format.Short(item.power)
		c.income.Text = Format.Rate(item.income * multiplier)
		local notable = item.qualityRank >= Config.NotableRank
		c.power.TextColor3 = notable and Style.Deep(item.qualityColor) or T.Text
		c.sheen.Visible = notable
		c.quality.Visible = notable
		if notable then
			c.quality.Text = string.upper(item.quality)
			c.quality.TextColor3 = item.qualityColor
			c.quality.BackgroundColor3 = T.Ink
		end
		if item.state == "Placed" then
			c.stateChip.Visible = true
			c.stateChip.Text = item.slot and ("SLOT " .. item.slot) or "PLACED"
			c.stateChip.BackgroundColor3 = T.Placed
		elseif item.state == "Held" then
			c.stateChip.Visible = true
			c.stateChip.Text = "HELD"
			c.stateChip.BackgroundColor3 = T.Held
		else
			c.stateChip.Visible = false
		end
		showPortrait(c.viewport, item, item.characterId .. (item.golden and "_G" or ""))
	end
	self:_paintCard(c)
end

function View:_layoutGrid(force)
	local M = self.M
	local grid = self.grid
	local pad = self.mode == "Compact" and 6 or 8
	local width = grid.AbsoluteSize.X - grid.ScrollBarThickness
	if width <= 0 then return end
	local cols = math.max(1, math.floor((width - pad * 2 + M.Gap) / (M.CardW + M.Gap)))
	-- cards widen (up to +25%) to fill the row instead of leaving wide gutters
	local cardW = math.max(M.CardW, math.min(math.floor(M.CardW * 1.25), math.floor((width - pad * 2 - (cols - 1) * M.Gap) / cols)))
	local n = #self.list
	local rows = math.ceil(n / cols)
	local stepY = M.CardH + M.Gap
	local canvasH = rows > 0 and (rows * stepY - M.Gap + pad * 2) or 0
	if force or self.cols ~= cols or self.canvasH ~= canvasH then
		self.cols, self.canvasH = cols, canvasH
		grid.CanvasSize = UDim2.fromOffset(0, canvasH)
	end
	local used = cols * cardW + (cols - 1) * M.Gap
	local x0 = math.floor((width - used) / 2)
	local top = grid.CanvasPosition.Y
	local first = math.max(0, math.floor((top - pad) / stepY) - Config.Layout.BufferRows)
	local last = math.min(rows - 1, math.floor((top + grid.AbsoluteSize.Y - pad) / stepY) + Config.Layout.BufferRows)

	-- cards keep their index while visible, so a scroll only touches the rows that changed
	local wanted = {}
	for row = first, last do
		for col = 0, cols - 1 do
			local i = row * cols + col + 1
			if i <= n then wanted[i] = true end
		end
	end
	local free = {}
	for i, c in self.cards do
		if not wanted[i] then
			self.cards[i] = nil
			table.insert(free, c)
		end
	end
	self.spare = self.spare or {}
	for _, c in free do
		if GuiService.SelectedObject == c.frame then GuiService.SelectedObject = nil end
		c.frame.Visible = false
		table.insert(self.spare, c)
	end
	local mult = self.state and self.state.multiplier or 1
	for i in wanted do
		local c = self.cards[i]
		if not c then
			c = table.remove(self.spare) or self:_newCard()
			self.cards[i] = c
		end
		local row, col = (i - 1) // cols, (i - 1) % cols
		c.frame.Position = UDim2.fromOffset(x0 + col * (cardW + M.Gap), pad + row * stepY)
		c.frame.Size = UDim2.fromOffset(cardW, M.CardH)
		c.frame.LayoutOrder = i
		c.frame.Visible = true
		self:_assignCard(c, self.list[i], mult)
	end
end

---------------------------------------------------------------- rendering
function View:SetSize(viewport)
	local L = Config.Layout
	local margin = self.mode == "Compact" and 8 or L.Margin
	local w = math.min(L.PanelMaxWidth, viewport.X - margin * 2)
	local h = math.min(L.PanelMaxHeight, viewport.Y - margin * 2 - self.roofH)
	self.root.Size = UDim2.fromOffset(math.max(320, w), math.max(260, h))
	self.root.Position = UDim2.new(0.5, 0, 0.5, math.floor(self.roofH / 2)) -- the roof stands above the panel
end

function View:_showNote(kind)
	local note = self.note
	if not kind then note.Visible = false self.skeleton.Visible = false return end
	note.Visible = kind ~= "loading"
	self.noteButton.Visible = kind == "nomatch"
	self.steps.Visible = kind == "empty"
	self.skeleton.Visible = kind == "loading"
	if kind == "empty" then
		self.noteTitle.Text = "No characters yet"
		self.noteBody.Text = "Your collection starts with your first hatch."
	elseif kind == "nomatch" then
		self.noteTitle.Text = "No characters match"
		self.noteBody.Text = "Try another name or turn a rarity filter off."
	elseif kind == "error" then
		self.noteTitle.Text = "Couldn't load your characters"
		self.noteBody.Text = "Retrying in a moment."
	end
	if kind == "loading" and #self.skeleton:GetChildren() == 0 then
		local M = self.M
		for i = 0, 7 do
			local s = make("Frame", {
				BorderSizePixel = 0, BackgroundColor3 = T.Card, Size = UDim2.fromOffset(M.CardW, M.CardH),
				Position = UDim2.fromOffset(10 + (i % 4) * (M.CardW + M.Gap), 10 + (i // 4) * (M.CardH + M.Gap)),
			}, self.skeleton)
			Style.Corner(s, 6)
			local p = make("Frame", { BorderSizePixel = 0, BackgroundColor3 = T.Portrait, Position = UDim2.fromOffset(6, 6), Size = UDim2.fromOffset(M.CardW - 12, M.Portrait) }, s)
			Style.Corner(p, 4)
			for j, wv in { 0.6, 0.3, 0.5 } do
				local bar = make("Frame", {
					BorderSizePixel = 0, BackgroundColor3 = T.Portrait, Size = UDim2.new(wv, 0, 0, j == 3 and 18 or 10),
					Position = UDim2.fromOffset(8, M.Portrait + 14 + (j - 1) * 20),
				}, s)
				Style.Corner(bar, 2)
			end
		end
	end
end

function View:SetLoadingPulse(alpha) self.skeleton.GroupTransparency = alpha end

function View:Render(state)
	self.state = state
	local items = state.items
	local compact = self.mode == "Compact"

	-- header
	self.owned.Text = state.status == "ready" and (#items == 1 and "1 owned" or (#items .. " owned")) or ""
	local cap = state.capacity
	if cap and cap.hasPlot then
		self.capValue.Text = cap.placed .. " / " .. cap.unlocked
		local full = cap.unlocked > 0 and cap.placed >= cap.unlocked
		self.capValue.TextColor3 = full and T.PageWarn or T.PageText
		self.capLabel.Text = full and "SLOTS · FULL" or "SLOTS"
		self.capLabel.TextColor3 = full and T.PageWarn or T.PageMuted
		if not compact then
			for _, p in self.pips:GetChildren() do if p:IsA("Frame") then p:Destroy() end end
			for i = 1, cap.total do
				local filled = i <= cap.placed
				local open = i <= cap.unlocked
				local p = make("Frame", {
					BorderSizePixel = 0, Size = UDim2.fromOffset(8, 6), LayoutOrder = i,
					BackgroundColor3 = filled and T.Placed or (open and T.Card or T.Locked),
				}, self.pips)
				Style.Corner(p, 1)
				if open and not filled then Style.Stroke(p, T.Faint, 1, 0.3) end
			end
		end
	else
		self.capValue.Text = "—"
		self.capValue.TextColor3 = T.PageMuted
		self.capLabel.Text = state.status == "ready" and "NO PLOT" or "SLOTS"
		self.capLabel.TextColor3 = T.PageMuted
		if not compact then for _, p in self.pips:GetChildren() do if p:IsA("Frame") then p:Destroy() end end end
	end

	-- PLACE BEST
	local plan = Model.BestPlan(items, cap, state.allowStore)
	local pendingBest = state.pending and state.pending.action == "PlaceBest"
	local canBest = state.status == "ready" and cap and cap.hasPlot and plan.place > 0 and state.alive and not state.pending
	self.bestButton:SetAttribute("Disabled", not canBest)
	self.bestButton.Text = pendingBest and "PLACING…" or "PLACE BEST"
	if self.bestSub then
		local mult = state.multiplier or 1
		if pendingBest then self.bestSub.Text = ""
		elseif not cap or not cap.hasPlot then self.bestSub.Text = "claim a plot first"
		elseif plan.place > 0 and plan.gain > 0 then self.bestSub.Text = Format.Delta(plan.gain * mult, true) .. "/s"
		elseif plan.place > 0 then self.bestSub.Text = plan.place .. " to place"
		else self.bestSub.Text = "best already placed" end
	end

	-- filters + sort
	local noneOn = next(state.rarities) == nil
	local counts = { All = #items }
	for _, item in items do counts[item.rarity] = (counts[item.rarity] or 0) + 1 end
	for id, b in self.rarityButtons do
		local on = (id == "All" and noneOn) or state.rarities[id] == true
		Style.SetOn(b, on)
		if on and id ~= "All" then -- a selected rarity fills with its own colour
			b:SetAttribute("Fill", T.Rarity[id])
			b.TextColor3 = T.Ink
		end
		local base = b:GetAttribute("Label") or b.Text
		b:SetAttribute("Label", base)
		b.Text = compact and base or (base .. "  " .. (counts[id] or 0))
	end
	local arrow = state.ascending and " ▲" or " ▼"
	for id, b in self.sortButtons do
		local on = state.sort == id
		local label
		for _, s in Config.Sorts do if s.Id == id then label = s.Label end end
		b.Text = label .. (on and arrow or "")
		Style.SetOn(b, on)
	end
	if self.sortCycle then
		local prefix = self.mode == "Compact" and "" or "SORT: "
		for _, s in Config.Sorts do if s.Id == state.sort then self.sortCycle.Text = prefix .. s.Label .. arrow end end
	end
	if self.search.Text ~= state.search and not self.search:IsFocused() then self.search.Text = state.search end

	-- grid
	self.list = Model.Sort(Model.Filter(items, state.search, state.rarities), state.sort, state.ascending)
	if state.status == "loading" then self:_showNote("loading")
	elseif state.status == "error" and #items == 0 then self:_showNote("error")
	elseif #items == 0 then self:_showNote("empty")
	elseif #self.list == 0 then self:_showNote("nomatch")
	else self:_showNote(nil) end
	self:_layoutGrid(true)

	self:_renderDetails(state)

	-- footer
	self.hint.Text = state.inputHint or ""
end

function View:_renderDetails(state)
	local d = self.d
	local selected = state.selectedId and state.byId[state.selectedId]
	self.selected = selected
	if self.mode == "Compact" then
		local open = selected ~= nil
		if open ~= self.detailsOpen then
			self.detailsOpen = open
			if open then
				self.details.Visible = true
				self.details.Position = UDim2.fromScale(0, 1.1)
				TweenService:Create(self.details, SHEET, { Position = UDim2.fromScale(0, 0) }):Play()
			else
				local tw = TweenService:Create(self.details, SHEET, { Position = UDim2.fromScale(0, 1.1) })
				tw.Completed:Connect(function() if not self.detailsOpen then self.details.Visible = false end end)
				tw:Play()
			end
		end
	end
	d.empty.Visible = selected == nil
	d.content.Visible = selected ~= nil
	d.footer.Visible = selected ~= nil
	if not selected then return end

	local mult = state.multiplier or 1
	local rarityColor = T.Rarity[selected.rarity] or T.Rarity.Common
	d.rarityGlow.BackgroundColor3 = rarityColor
	d.name.Text = selected.name
	d.rarityChip.Text = string.upper(selected.rarity)
	d.rarityChip.BackgroundColor3 = rarityColor
	d.qualityChip.Text = string.upper(selected.quality) .. " ROLL"
	local notable = selected.qualityRank >= Config.NotableRank
	d.qualityChip.BackgroundColor3 = notable and T.Ink or T.Portrait
	d.qualityChip.TextColor3 = notable and selected.qualityColor or T.Text
	d.stateChip.Visible = selected.state ~= "Backpack"
	d.stateChip.Text = selected.state == "Placed" and "PLACED" or "HELD"
	d.stateChip.BackgroundColor3 = selected.state == "Placed" and T.Placed or T.Held

	d.power.Text = Format.Short(selected.power)
	d.power.TextColor3 = notable and selected.qualityColor or T.GoldHi -- light on the dark tile
	d.exact.Text = Format.Exact(selected.power) .. " exact"
	d.multiplier.Text = Format.Multiplier(selected.power, selected.basePower) .. " of base"
	d.income.Text = Format.Rate(selected.income * mult)
	d.eventRow.Visible = mult ~= 1
	d.eventValue.Text = "×" .. tostring(mult) .. " applied"
	d.base.Text = Format.Exact(selected.basePower)
	d.slotRow.Visible = selected.state == "Placed" and selected.slot ~= nil
	d.slotValue.Text = selected.slot and ("Slot " .. selected.slot) or ""
	d.acquired.Text = selected.acquired and Format.Ago((state.serverNow or 0) - selected.acquired) or "—"
	self.detailsModel = showPortrait(d.viewport, selected, selected.characterId .. (selected.golden and "_G" or "")) or self.detailsModel

	-- comparison
	local other, why = Model.CompareTarget(state.items, selected, state.pinnedId)
	d.compareNone.Visible = other == nil
	d.cmpPowerRow.Visible = other ~= nil
	d.cmpIncomeRow.Visible = other ~= nil
	if other then
		d.compareTitle.Text = "VS " .. why .. " · " .. string.upper(other.name)
		local dp = selected.power - other.power
		local di = (selected.income - other.income) * mult
		d.cmpPower.Text = Format.Delta(dp)
		d.cmpPower.TextColor3 = dp > 0 and T.Up or (dp < 0 and T.Down or T.Muted)
		d.cmpPowerRel.Text = Format.Relative(selected.power, other.power)
		d.cmpIncome.Text = Format.Delta(di, true) .. "/s"
		d.cmpIncome.TextColor3 = di > 0 and T.Up or (di < 0 and T.Down or T.Muted)
		d.cmpIncomeRel.Text = Format.Relative(selected.income, other.income)
	else
		d.compareTitle.Text = "COMPARE"
	end
	d.pin.Text = state.pinnedId == selected.id and "UNPIN" or "PIN"
	d.pin:SetAttribute("Disabled", #state.items < 2)

	-- actions
	local actions = Model.Actions(selected, state.capacity, state.allowStore, state.alive)
	local pending = state.pending
	local buttons = { d.primary, d.secondary }
	local reason
	for i, b in buttons do
		local a = actions[i]
		b.Visible = a ~= nil
		if a then
			local busyHere = pending and pending.id == selected.id and pending.action == a.action
			b.Text = busyHere and "…" or a.label
			b:SetAttribute("Action", a.action)
			b:SetAttribute("Disabled", not a.enabled or pending ~= nil)
			if not a.enabled and a.reason and not reason then reason = a.reason end
		end
	end
	d.primary.Size = actions[2] and UDim2.new(0.5, -4, 1, 0) or UDim2.new(0.8, -4, 1, 0)
	d.reason.Text = reason or ""
	d.reason.Visible = reason ~= nil
end

function View:Toast(message, kind)
	self.toastSeq = (self.toastSeq or 0) + 1
	local mine = self.toastSeq
	self.toast.Text = message
	self.toast.TextColor3 = kind == "error" and T.PageDown or (kind == "ok" and T.PageUp or T.PageText)
	self.toast.TextTransparency = 0
	task.delay(2.6, function()
		if self.toastSeq == mine and self.toast.Parent then
			TweenService:Create(self.toast, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
		end
	end)
end

-- Turns only the details portrait, slowly. Called from one RenderStepped while the panel is open.
function View:Step(dt, reducedMotion)
	if reducedMotion or not self.selected or not self.detailsModel or not self.detailsModel.Parent then return end
	self.spin = ((self.spin or 0) + dt * 18) % 360
	Style.FrameModel(self.d.viewport, self.detailsModel, 20 + math.sin(math.rad(self.spin)) * 28, 1.08)
end

function View:FirstSelectable()
	local best, bestIndex
	for i, c in self.cards do
		if c.frame.Visible and (not bestIndex or i < bestIndex) then best, bestIndex = c.frame, i end
	end
	return best or self.search
end

function View:Destroy()
	for _, c in self.connections do c:Disconnect() end
	self.connections = {}
	if self.root then self.root:Destroy() end
	self.cards, self.spare = {}, {}
end

return View
