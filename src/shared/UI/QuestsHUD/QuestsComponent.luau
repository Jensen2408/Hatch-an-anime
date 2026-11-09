-- ReplicatedStorage.QuestsHUD.QuestsComponent  (ModuleScript, client)
-- The collapsible quest tracker in the Folk Stud look (2026-11-07): a white studded sheet, the title sitting on its top
-- border with the game's quest scroll hanging over the corner, mint quest cards with white bar tracks and a mango fill.
-- A finished quest turns its fill green and its outline glints gold. Display only: FigmaSkin feeds it from the server
-- (GameMenu GetState "quests"). Same API as the atlas version, so FigmaSkin is unchanged:
--
--   local hud = QuestsComponent.new(screenGui)
--   hud:SetQuests({ { id = "place2", title = "Place 2 characters", progress = 1, target = 2 }, ... })
--   hud:UpdateQuest("place2", 2, 2)
--   hud:ToggleExpanded() / hud:SetExpanded(false)
-- Collapsed, the sheet folds away into a small mint tab against the right edge (scroll + "Quests"), with a coral
-- badge when a quest is finished; pressing the tab opens the sheet again.
-- Old version: ServerStorage._ARCHIVE.QuestsComponent_BeforeStud_2026-11-07
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.H
local Config = require(script.Parent:WaitForChild("QuestsConfig"))

local QUEST_ICON = "rbxassetid://131345069239287"   -- FOLK scroll (i_quests), same as the rail
local W = Config.Width                                -- 252: FigmaSkin scales the tracker by this width
local TOP = 18                                        -- the sheet's top border; the title sits on it
local HEADER = 50                                     -- root top to the first card
local PITCH, CARD_H = 62, 54
local TRACK_X, TRACK_Y, TRACK_W, TRACK_H = 12, 31, 158, 16
local MINT, LEAF, MANGO = M.COLOR.mint, M.COLOR.leaf, M.COLOR.mango
local TAB = 82                                       -- the collapsed tab, flush with the tracker's right edge

local QuestsComponent = {}
QuestsComponent.__index = QuestsComponent

local function rowsHeight(n)
	return n > 0 and n * PITCH + 4 or 0
end

-- a label that fits its box: long quest names shrink, then cut off with "..."
local function fitText(parent, name, x, y, w, h, maxSize, z, align)
	local l = H.new("TextLabel", { Name = name, BackgroundTransparency = 1, FontFace = M.FONT, Text = "", TextScaled = true, TextColor3 = H.WHITE,
		TextXAlignment = align or Enum.TextXAlignment.Left, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z }, parent)
	H.new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 12 }, l)
	H.new("UIStroke", { Name = "UIStroke", Thickness = 3, Color = H.BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, l)
	return l
end

function QuestsComponent:_buildRow(index, parent)
	local card = H.rect(parent, "QuestRow" .. index, 12, 4 + (index - 1) * PITCH, W - 24, CARD_H, 14, 3, H.WHITE)
	H.grad(card, MINT[1], MINT[2])
	H.ink(card, 3.5)
	card:SetAttribute("Glint", false)   -- the kit's glint: gold outline while true, black while false
	card.Visible = false
	local description = fitText(card, "DescriptionText", 10, 3, W - 44, 25, 20, 5)
	description.TextTruncate = Enum.TextTruncate.AtEnd
	-- the bar: a white track with a black outline, the fill clipped to the progress
	local track = H.rect(card, "ProgressTrack", TRACK_X, TRACK_Y, TRACK_W, TRACK_H, 8, 4, H.WHITE)
	H.ink(track, 3)
	local clip = H.new("Frame", { Name = "FillClip", BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.fromOffset(0, TRACK_H), ZIndex = 4 }, track)
	local fill = H.rect(clip, "ProgressFill", 0, 0, TRACK_W, TRACK_H, 8, 5, H.WHITE)
	local fillGrad = H.grad(fill, MANGO[1], MANGO[2])
	local count = fitText(card, "ProgressText", TRACK_X + TRACK_W + 4, 25, W - 24 - (TRACK_X + TRACK_W + 4) - 8, 26, 21, 5, Enum.TextXAlignment.Right)
	return { Frame = card, Description = description, Fill = clip, FillGradient = fillGrad, Count = count, Ratio = nil, QuestId = nil }
end

function QuestsComponent.new(parent)
	local self = setmetatable({}, QuestsComponent)
	local root = H.new("Frame", { Name = "QuestsHUD", BackgroundTransparency = 1, Size = UDim2.fromOffset(W, HEADER + 10) }, nil)
	self.Scale = H.new("UIScale", {}, root)

	-- the sheet follows the root's height, so collapsing shrinks it
	local shadow = H.new("Frame", { Name = "SheetShadow", BackgroundColor3 = H.BLACK, BackgroundTransparency = 0.55, Position = UDim2.fromOffset(0, TOP + 6),
		Size = UDim2.new(1, 0, 1, -TOP), ZIndex = 1 }, root)
	H.round(shadow, 16)
	local sheet = H.new("Frame", { Name = "HeaderImage", BackgroundColor3 = H.WHITE, Position = UDim2.fromOffset(0, TOP), Size = UDim2.new(1, 0, 1, -TOP), ZIndex = 2 }, root)
	H.round(sheet, 16)
	H.ink(sheet, 4)
	H.neon(sheet, M.COLOR.mint, 5)
	H.studs(sheet, Vector2.new(50, 46), 0.8, 16, 2)

	-- cards live below the header; this clip frame's height is what collapses
	local content = H.new("Frame", { Name = "CollapsibleContent", BackgroundTransparency = 1, ClipsDescendants = true, Position = UDim2.fromOffset(0, HEADER),
		Size = UDim2.fromOffset(W, 0), ZIndex = 3 }, root)
	self.Rows = {}
	for index = 1, Config.MaxRows do
		self.Rows[index] = self:_buildRow(index, content)
	end

	-- the whole header is the toggle; the scroll hangs over the corner and the title sits on the top border
	local header = H.new("TextButton", { Name = "HeaderButton", BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.fromOffset(W, HEADER), ZIndex = 6 }, root)
	H.sticker(header, "Icon", QUEST_ICON, 22, 16, 56, 7, true)
	local title = H.text(header, "TitleText", "QUESTS", 56, TOP, 32, 8, H.WHITE, "left")
	H.gleam(title)

	-- the chevron: a small mint button on the top border (down = open, up = closed)
	local chev = H.button(header, "ChevronButton", W - 46, TOP - 15, 34, 30, 10, MINT, 8, { lip = 4, studs = 0.7 })
	local arrow = H.new("Frame", { Name = "ChevronIcon", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -2),
		Size = UDim2.fromOffset(18, 12), ZIndex = 10 }, chev)
	for i, rot in ipairs({ 40, -40 }) do
		H.new("Frame", { Name = "Bar" .. i, BackgroundColor3 = H.BLACK, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(i == 1 and 5 or 13, 6),
			Size = UDim2.fromOffset(12, 4), Rotation = rot, ZIndex = 10 }, arrow)
	end

	-- the collapsed tab: a pressable mint square with the scroll and a word, tucked against the right edge
	local tabShadow = H.shadow(root, "Tab", W - TAB, 4, TAB, TAB, 16, 1)
	local tab = H.button(root, "CollapsedTab", W - TAB, 4, TAB, TAB, 16, MINT, 3, { lip = 6, studs = 0.7 })
	tab:SetAttribute("Spring", 6)
	H.art(tab, "Icon", QUEST_ICON, TAB / 2, 30, 60, tab.ZIndex + 2):SetAttribute("Float", 30)
	H.gleam(H.text(tab, "Label", "Quests", TAB / 2, TAB - 22, 20, tab.ZIndex + 3))
	local badge = H.rect(tab, "Badge", TAB - 22, -10, 30, 30, 15, tab.ZIndex + 4, H.WHITE)
	H.grad(badge, M.COLOR.coral[1], M.COLOR.coral[2])
	H.ink(badge, 3)
	H.text(badge, "Mark", "!", 15, 14, 22, tab.ZIndex + 5)
	badge:SetAttribute("Wiggle", 8)
	badge.Visible = false
	tab.Visible, tabShadow.Visible = false, false
	tab:GetPropertyChangedSignal("Visible"):Connect(function() tabShadow.Visible = tab.Visible end)
	local tabPop = tab:WaitForChild("Pop")   -- the kit's own press scale
	tab.Activated:Connect(function() self:SetExpanded(true) end)
	self.Tab, self.TabPop, self.Badge = tab, tabPop, badge
	self.SheetFrame, self.SheetShadow = sheet, shadow
	self.Token = 0

	self.Root, self.Header, self.Chevron, self.Content = root, header, arrow, content
	self.IsExpanded = true
	self.RowCount = 0
	self.Tweens = {}
	header.Activated:Connect(function() self:ToggleExpanded() end)
	chev.Activated:Connect(function() self:ToggleExpanded() end)
	self:_applyHeight(false)
	M.animate(root)
	root.Parent = parent
	return self
end

-- Root and clip heights for the current state; animated = tween, else snap. A running tween is replaced.
function QuestsComponent:_applyHeight(animated)
	local h = self.IsExpanded and rowsHeight(self.RowCount) or 0
	local goals = {
		[self.Content] = { Size = UDim2.fromOffset(W, h) },
		[self.Root] = { Size = UDim2.fromOffset(W, self.IsExpanded and HEADER + (h > 0 and h or 6) or TAB + 12) },
		[self.Chevron] = { Rotation = self.IsExpanded and 0 or 180 },
	}
	for instance, goal in goals do
		if self.Tweens[instance] then
			self.Tweens[instance]:Cancel()
			self.Tweens[instance] = nil
		end
		if animated then
			local tween = TweenService:Create(instance, TweenInfo.new(Config.CollapseTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
			self.Tweens[instance] = tween
			tween:Play()
		else
			for property, value in goal do instance[property] = value end
		end
	end
end

-- Closing: the cards fold up, then the white sheet shrinks and slides into the right corner, turning mint as it goes,
-- and becomes the tab. Opening plays the same thing backwards. A newer toggle cancels the running one (Token).
local FOLD = 0.22    -- cards folding up / down
local MORPH = 0.32   -- sheet <-> tab
local function play(self, instance, info, goal)
	if self.Tweens[instance] then self.Tweens[instance]:Cancel() end
	local tween = TweenService:Create(instance, info, goal)
	self.Tweens[instance] = tween
	tween:Play()
	return tween
end

-- the sheet and its shadow as a rect in root offsets (they follow the root's height again once restored)
function QuestsComponent:_sheetRect(x, y, w, h)
	self.SheetFrame.Position, self.SheetFrame.Size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	self.SheetShadow.Position, self.SheetShadow.Size = UDim2.fromOffset(x, y + 6), UDim2.fromOffset(w, h)
end
function QuestsComponent:_sheetFollowRoot()
	self.SheetFrame.Position, self.SheetFrame.Size = UDim2.fromOffset(0, TOP), UDim2.new(1, 0, 1, -TOP)
	self.SheetShadow.Position, self.SheetShadow.Size = UDim2.fromOffset(0, TOP + 6), UDim2.new(1, 0, 1, -TOP)
	self.SheetFrame.BackgroundColor3 = H.WHITE
end
-- tweens the sheet (and shadow) to a rect and colour; calls done when it lands, unless a newer toggle came first
function QuestsComponent:_morph(x, y, w, h, colour, info, token, done)
	local pos, size = UDim2.fromOffset(x, y), UDim2.fromOffset(w, h)
	local t = play(self, self.SheetFrame, info, { Position = pos, Size = size, BackgroundColor3 = colour })
	play(self, self.SheetShadow, info, { Position = pos + UDim2.fromOffset(0, 6), Size = size })
	t.Completed:Once(function(state)
		if state == Enum.PlaybackState.Completed and self.Token == token then done() end
	end)
end

function QuestsComponent:_showTab(on)
	self.SheetFrame.Visible, self.SheetShadow.Visible = not on, not on
	self.Header.Visible, self.Content.Visible = not on, not on
	self.Tab.Visible = on
end

function QuestsComponent:SetExpanded(expanded)
	if self.IsExpanded == expanded then return end
	self.IsExpanded = expanded
	self.Token += 1
	local token = self.Token
	local barH = HEADER - TOP + 6                     -- the sheet's height with no cards showing
	if not expanded then
		-- 1. fold the cards up; the sheet follows the root's height down to the header bar
		play(self, self.Content, TweenInfo.new(FOLD, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(W, 0) })
		play(self, self.Chevron, TweenInfo.new(FOLD), { Rotation = 180 })
		local fold = play(self, self.Root, TweenInfo.new(FOLD, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Size = UDim2.fromOffset(W, HEADER + 6) })
		fold.Completed:Once(function(state)
			if state ~= Enum.PlaybackState.Completed or self.Token ~= token then return end
			-- 2. the bar shrinks into the corner, turning mint, and becomes the tab
			self.Header.Visible = false
			self:_sheetRect(0, TOP, W, barH)
			self.Root.Size = UDim2.fromOffset(W, TAB + 12)
			self:_morph(W - TAB, 4, TAB, TAB, MINT[2], TweenInfo.new(MORPH, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), token, function()
				self:_showTab(true)
				self.TabPop.Scale = 0.9
				TweenService:Create(self.TabPop, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
			end)
		end)
	else
		-- 1. the tab grows back out of the corner into the white bar
		self:_showTab(false)
		self.Header.Visible = false
		self:_sheetRect(W - TAB, 4, TAB, TAB)
		self.SheetFrame.BackgroundColor3 = MINT[2]
		self:_morph(0, TOP, W, barH, H.WHITE, TweenInfo.new(MORPH, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), token, function()
			-- 2. the header comes back and the cards unfold
			self.Header.Visible = true
			self.Root.Size = UDim2.fromOffset(W, HEADER + 6)
			self:_sheetFollowRoot()
			self:_applyHeight(true)
		end)
	end
end

function QuestsComponent:ToggleExpanded()
	self:SetExpanded(not self.IsExpanded)
end

function QuestsComponent:_setRow(row, current, target)
	local ratio = math.clamp(current / math.max(target, 1), 0, 1)
	row.Count.Text = string.format("%s/%s", QuestsComponent.FormatCount(current), QuestsComponent.FormatCount(target))
	-- done: green fill and a gold glint on the card
	local done = ratio >= 1
	local pal = done and LEAF or MANGO
	row.FillGradient.Color = ColorSequence.new(pal[1], pal[2])
	row.Frame:SetAttribute("Glint", done)
	row.Done = done
	self:_refreshBadge()
	if row.Ratio == ratio then return end
	local goal = { Size = UDim2.fromOffset(math.floor(TRACK_W * ratio + 0.5), TRACK_H) }
	if row.FillTween then row.FillTween:Cancel() end
	if row.Ratio == nil then
		row.Fill.Size = goal.Size
	else
		row.FillTween = TweenService:Create(row.Fill, TweenInfo.new(Config.FillTime, Enum.EasingStyle.Quad), goal)
		row.FillTween:Play()
	end
	row.Ratio = ratio
end

-- the tab's "!" shows while any shown quest is finished
function QuestsComponent:_refreshBadge()
	local any = false
	for _, row in self.Rows do
		if row.Frame.Visible and row.Done then any = true end
	end
	if self.Badge then self.Badge.Visible = any end
end

-- 1500 -> "1.5K" (truncated), small numbers as they are
function QuestsComponent.FormatCount(amount)
	amount = math.floor(amount)
	for _, unit in { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if amount >= unit[1] then
			return string.format("%g", math.floor(amount / unit[1] * 10) / 10) .. unit[2]
		end
	end
	return tostring(amount)
end

-- Shows these quests (in order, at most MaxRows): { { id, title, progress, target }, ... }. Rows are reused;
-- a row keeps its fill when the same quest stays in the same slot, so progress animates instead of jumping.
function QuestsComponent:SetQuests(quests)
	local count = math.min(#quests, Config.MaxRows)
	for index, row in self.Rows do
		local quest = quests[index]
		if index <= count and quest then
			if row.QuestId ~= quest.id then
				row.QuestId = quest.id
				row.Ratio = nil
			end
			row.Description.Text = quest.title or ""
			self:_setRow(row, quest.progress or 0, quest.target or 1)
			row.Frame.Visible = true
		else
			row.QuestId = nil
			row.Ratio = nil
			row.Frame.Visible = false
			row.Frame:SetAttribute("Glint", false)
			row.Done = false
		end
	end
	self:_refreshBadge()
	if count ~= self.RowCount then
		self.RowCount = count
		self:_applyHeight(true)
	end
end

-- Updates one shown quest's progress (no-op if it is not shown).
function QuestsComponent:UpdateQuest(questId, current, target)
	for _, row in self.Rows do
		if row.QuestId == questId then
			self:_setRow(row, current, target)
			return
		end
	end
end

function QuestsComponent:SetVisible(visible)
	self.Root.Visible = visible
end

function QuestsComponent:Destroy()
	self.Root:Destroy()
end

return QuestsComponent
