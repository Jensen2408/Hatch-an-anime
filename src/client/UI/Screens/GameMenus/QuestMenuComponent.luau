-- GameMenus.QuestMenuComponent  (ModuleScript, client)
-- The Quests window in the Folk Stud look (2026-11-07): a white studded sheet, "QUESTS" on the top border with the
-- game's quest scroll hanging over the corner and a red X over the other corner. Three candy period tabs (red count
-- of quests ready to claim), vivid quest rows with a white icon tile, a white bar track with a mango fill, a reward
-- pill and one button: blue GO, lime CLAIM (light rays behind the icon, the row's outline glints gold) or a flat
-- lime DONE. The footer holds the reset timer and CLAIM ALL.
-- Display only: MenuLogic (RENDER.Quests) reads the quest state and passes Claim / Claim all as callbacks. Same API
-- and model as the atlas version:
--
--   local view = QuestMenuComponent.new(panel, layer, model)
--   view:Destroy()
--
-- model = {
--   tabs = { { key, label, selected, ready, onActivate } x3 },
--   quests = { { title, text, icon, progress (0..1), count, reward?, rewardIcon?, state = "claimable" |
--                "active" | "claimed", onActivate } },
--   resetEndsAt? (os.clock), claimAll = { text, enabled, onActivate }, emptyText,
-- }
-- Old version: ServerStorage._ARCHIVE.QuestMenuComponent_BeforeStud_2026-11-07
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.H
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local Theme = require(ReplicatedStorage:WaitForChild("StudKit"):WaitForChild("StudTheme"))

local CW, CH = Theme.CanvasSize.X, Theme.CanvasSize.Y   -- 1160 x 730: MenuLogic sizes the panel by this aspect
local Z = 10
local C = M.COLOR
local WHITE, BLACK, hex = H.WHITE, H.BLACK, H.hex
local GOLD = hex("FFC400")
local GOLD_TEXT = hex("FFE14D")
local INK_TEXT = hex("3A3150")
local DONE = { hex("8CF56A"), hex("3CCB3A"), hex("1A6E1E") }
local CLOSE = { CW - 40, -30, 74, 74 }
local QUEST_ICON = "rbxassetid://131345069239287"   -- FOLK scroll (i_quests), same as the rail

local TAB_COLORS = { Daily = C.mango, Weekly = C.lilac, Monthly = C.bubblegum }
local ROW_COLORS = { C.azure, C.mint, C.lilac, C.mango, C.bubblegum, C.aqua }
local LIST = { X = 44, Y = 144, W = CW - 88, H = 474 }
local ROW_H, ROW_GAP, PAD = 112, 12, 8
local FOOT_Y, FOOT_H = CH - 96, 62

local QuestMenuComponent = {}
QuestMenuComponent.__index = QuestMenuComponent
QuestMenuComponent.AspectRatio = CW / CH

---------------------------------------------------------------- building blocks
local function txt(parent, name, str, x, y, w, h, size, z, col, align, wrap)
	local l = H.new("TextLabel", { Name = name, BackgroundTransparency = 1, FontFace = M.FONT, Text = str or "", TextScaled = true, TextWrapped = wrap == true,
		TextColor3 = col or WHITE, TextXAlignment = align or Enum.TextXAlignment.Center, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z }, parent)
	H.new("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = 10 }, l)
	H.new("UIStroke", { Name = "UIStroke", Thickness = size >= 28 and 3.7 or (size >= 20 and 3 or 2.5), Color = BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, l)
	return l
end
local function card(parent, name, x, y, w, h, pal, z)
	H.shadow(parent, name, x, y, w, h, 18, z)
	local f = H.rect(parent, name, x, y, w, h, 18, z + 1, WHITE)
	H.grad(f, pal[1], pal[2])
	H.ink(f, 4)
	H.studs(f, Vector2.new(48, 48), 0.84, 18, z + 1)
	return f
end
local function btn(parent, name, x, y, w, h, pal, word, size, z, onActivate, done)
	local b
	if done then
		b = H.button(parent, name, x, y, w, h, 14, pal, z, { lip = 0, plain = true })
		b.AutoButtonColor = false
		b.Active = false
		b:SetAttribute("Pressable", nil)
	else
		b = H.button(parent, name, x, y, w, h, 14, pal, z, { lip = 6, studs = 0.7 })
		if onActivate then b.Activated:Connect(onActivate) end
	end
	txt(b, "Label", word, 8, 2, w - 16, h - (done and 4 or 10), size, b.ZIndex + 3)
	return b
end
-- old pixel art -> sharp FOLK art (2026-11-07)
local SWAP = { ["rbxassetid://125162321561970"] = "rbxassetid://136807180106184" } -- pixel coins -> i_cash
local function image(parent, name, source, cx, cy, size, z)
	if not source or source == "" then return nil end
	source = SWAP[source] or source
	return H.new("ImageLabel", { Name = name, BackgroundTransparency = 1, Image = source, ScaleType = Enum.ScaleType.Fit, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(size, size), ZIndex = z }, parent)
end
local function optOut(root)
	root:SetAttribute("NoSkin", true)
	root:SetAttribute("FS", true)
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			d:SetAttribute("NoSkin", true)
			d:SetAttribute("FS", true)
		end
	end
end
-- 12:45:30 (days fold into hours)
local function formatHms(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end

---------------------------------------------------------------- one quest row
local function questRow(parent, i, quest, y)
	local claimable, claimed = quest.state == "claimable", quest.state == "claimed"
	local w = LIST.W - PAD * 2 - 10
	local pal = ROW_COLORS[(i - 1) % #ROW_COLORS + 1]
	local row = card(parent, "Quest" .. i, PAD, y, w, ROW_H, pal, Z + 1)
	if claimable then
		row:SetAttribute("Glint", true)
		local o = row:FindFirstChild("Outline")
		if o then o.Thickness = 5 end
	end
	-- the icon on a white tile (rays behind it once it can be claimed)
	local T = 86
	if claimable then H.beams(row, 14 + T / 2, ROW_H / 2, 170, Z + 2, WHITE, 0.25, 8) end
	local tile = H.rect(row, "IconTile", 14, (ROW_H - T) / 2, T, T, 16, Z + 3, WHITE)
	H.ink(tile, 3.5)
	if claimed then
		txt(tile, "Check", "✓", 0, 2, T, T - 4, 60, Z + 4, DONE[1])
	else
		local ic = image(tile, "Icon", quest.icon, T / 2, T / 2, T - 14, Z + 4)
		if ic and claimable then ic:SetAttribute("Wiggle", 0) end
	end
	-- words, bar and count
	local tx = 14 + T + 16
	local wordsW = w - tx - 410
	txt(row, "Title", quest.title, tx, 8, wordsW, 34, 30, Z + 4, nil, Enum.TextXAlignment.Left)
	txt(row, "Text", quest.text, tx, 42, wordsW, 26, 20, Z + 4, GOLD_TEXT, Enum.TextXAlignment.Left)
	local trackW = wordsW - 110
	local track = H.rect(row, "Track", tx, 76, trackW, 22, 10, Z + 3, WHITE)
	H.ink(track, 3)
	local progress = math.clamp(quest.progress or 0, 0, 1)
	if progress > 0 then
		local clip = H.new("Frame", { Name = "FillClip", BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.fromOffset(math.max(12, trackW * progress), 22), ZIndex = Z + 4 }, track)
		local fill = H.rect(clip, "Fill", 0, 0, trackW, 22, 10, Z + 4, WHITE)
		local fpal = (claimable or claimed) and C.leaf or C.mango
		H.grad(fill, fpal[1], fpal[2])
	end
	txt(row, "Count", quest.count, tx + trackW + 8, 70, 102, 32, 24, Z + 4, nil, Enum.TextXAlignment.Left)
	-- the reward: a white pill with the coin and the amount
	local rx = w - 404
	if quest.reward then
		local pill = H.rect(row, "Reward", rx, (ROW_H - 56) / 2, 196, 56, 14, Z + 3, WHITE)
		H.ink(pill, 3.5)
		local hasIcon = quest.rewardIcon ~= nil
		if hasIcon then image(pill, "RewardIcon", quest.rewardIcon, 30, 28, 42, Z + 4) end
		local r = txt(pill, "RewardText", quest.reward, hasIcon and 54 or 10, 6, hasIcon and 132 or 176, 44, 30, Z + 4, GOLD_TEXT)
		H.gleam(r)
	end
	-- the one button
	local bx, bw, bh = w - 196, 180, 68
	if claimed then
		btn(row, "Action", bx, (ROW_H - bh) / 2, bw, bh, DONE, "DONE!", 34, Z + 4, nil, true)
	elseif claimable then
		btn(row, "Action", bx, (ROW_H - bh) / 2, bw, bh, C.leaf, "CLAIM", 34, Z + 4, quest.onActivate)
	else
		btn(row, "Action", bx, (ROW_H - bh) / 2, bw, bh, C.blue, "GO", 36, Z + 4, quest.onActivate)
	end
	return row
end

---------------------------------------------------------------- the window
function QuestMenuComponent.new(panel, layer, model)
	local self = setmetatable({ model = model, alive = true }, QuestMenuComponent)
	for _, name in { "CleanSkin", "CleanBase", "FigmaWindow" } do
		local child = panel:FindFirstChild(name)
		if child and child:IsA("GuiObject") then child.Visible = false end
	end
	-- the panel's own Close button becomes an invisible hit-box over the drawn X
	local closeButton = panel:FindFirstChild("Close")
	if closeButton then
		closeButton.AnchorPoint = Vector2.zero
		closeButton.Position = UDim2.fromScale(CLOSE[1] / CW, CLOSE[2] / CH)
		closeButton.Size = UDim2.fromScale(CLOSE[3] / CW, CLOSE[4] / CH)
		closeButton.BackgroundTransparency = 1
		closeButton.ZIndex = 30
		for _, d in closeButton:GetDescendants() do
			if d:IsA("GuiObject") then d.Visible = false elseif d:IsA("UIStroke") then d.Enabled = false end
		end
		if closeButton:IsA("ImageButton") then closeButton.ImageTransparency = 1
		elseif closeButton:IsA("TextButton") then closeButton.TextTransparency = 1 end
	end

	local canvas = H.new("Frame", { Name = "StudCanvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CW, CH), ZIndex = Z }, nil)
	local scale = H.new("UIScale", {}, canvas)
	local function fit() scale.Scale = math.max(panel.Size.X.Offset, 1) / CW end
	fit()
	self.sizeConnection = panel:GetPropertyChangedSignal("Size"):Connect(fit)
	self.canvas = canvas

	-- the sheet, the title on the top border, the scroll over the corner, the X over the other corner
	H.shadow(canvas, "Sheet", 0, 0, CW, CH, 26, Z - 2)
	local sheet = H.rect(canvas, "Background", 0, 0, CW, CH, 26, Z - 1, WHITE)
	H.ink(sheet, 5)
	H.studs(sheet, Vector2.new(50, 46), 0.8, 26, Z - 1)
	H.beams(canvas, 52, 18, 190, Z + 1, hex("8CF56A"), 0.35, 6)
	local scroll = H.art(canvas, "HeaderIcon", QUEST_ICON, 52, 16, 116, Z + 2)
	scroll:SetAttribute("Float", 16)
	local title = H.text(canvas, "HeaderTitle", "QUESTS", CW / 2, 6, 72, Z + 4, WHITE)
	H.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, hex("A8FF8C")) }, title)
	H.gleam(title)
	local x = H.rect(canvas, "CloseArt", CLOSE[1], CLOSE[2], CLOSE[3], CLOSE[4], 14, Z + 6, WHITE)
	H.grad(x, C.coral[1], C.coral[2])
	H.ink(x, 4)
	txt(x, "X", "X", 0, 2, CLOSE[3], CLOSE[4] - 6, 54, Z + 7)

	-- period tabs (a red count of ready quests on each)
	local gap = 12
	local tw = (CW - 88 - gap * 2) / 3
	for i, tab in model.tabs do
		if i > 3 then break end
		local tx = 44 + (i - 1) * (tw + gap)
		local b = H.button(canvas, "Tab_" .. tab.key, tx, 66, tw, 60, 14, TAB_COLORS[tab.key] or C.azure, Z + 3, { lip = 6, studs = 0.7 })
		if tab.selected then
			local o = b:FindFirstChild("Outline")
			if o then o.Color, o.Thickness = GOLD, 5 end
			b.Size = UDim2.fromOffset(tw + 6, 66)
		end
		txt(b, "Label", tab.label, 12, 6, tw - 24, 42, 34, b.ZIndex + 3)
		if tab.onActivate then b.Activated:Connect(tab.onActivate) end
		if (tab.ready or 0) > 0 then
			local dot = H.circle(canvas, "Ready_" .. tab.key, tx + tw - 6, 64, 36, Z + 6, C.coral[1], C.coral[2], 3)
			txt(dot, "Count", tostring(tab.ready), 0, 1, 36, 32, 24, Z + 7)
			dot:SetAttribute("Wiggle", 0)
		end
	end

	-- the list: a light well with the rows scrolling inside
	local well = H.rect(canvas, "ListWell", LIST.X, LIST.Y, LIST.W, LIST.H, 18, Z, hex("EDE8FA"))
	H.ink(well, 4)
	if #model.quests == 0 then
		local empty = txt(canvas, "Empty", model.emptyText, LIST.X + 40, LIST.Y + LIST.H / 2 - 30, LIST.W - 80, 60, 36, Z + 2, INK_TEXT)
		empty.UIStroke.Enabled = false
	else
		local scroller = H.new("ScrollingFrame", { Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(LIST.X, LIST.Y), Size = UDim2.fromOffset(LIST.W, LIST.H),
			ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = hex("7C4DF2"), ZIndex = Z + 1 }, canvas)
		for i, quest in model.quests do
			questRow(scroller, i, quest, PAD + (i - 1) * (ROW_H + ROW_GAP))
		end
		scroller.CanvasSize = UDim2.fromOffset(0, PAD * 2 + #model.quests * ROW_H + (#model.quests - 1) * ROW_GAP + 6)
	end

	-- footer: the reset timer and CLAIM ALL
	if model.resetEndsAt then
		local pill = H.rect(canvas, "ResetPill", 44, FOOT_Y, 420, FOOT_H, 16, Z + 1, WHITE)
		H.ink(pill, 4)
		local clock = txt(pill, "Clock", "⏰", 8, 4, 54, FOOT_H - 8, 34, Z + 2)
		clock:SetAttribute("Wiggle", 0)
		local resetText = txt(pill, "ResetText", "", 66, 8, 340, FOOT_H - 16, 30, Z + 2, INK_TEXT, Enum.TextXAlignment.Left)
		resetText.UIStroke.Enabled = false
		local function update()
			resetText.Text = "Resets in " .. formatHms(model.resetEndsAt - os.clock())
		end
		update()
		task.spawn(function()
			while self.alive do
				task.wait(1)
				if self.alive then update() end
			end
		end)
	end
	local claimAll = model.claimAll
	btn(canvas, "ClaimAll", CW - 44 - 340, FOOT_Y - 2, 340, FOOT_H + 4, claimAll.enabled and C.leaf or C.ink, claimAll.text, 34, Z + 2,
		claimAll.enabled and claimAll.onActivate or nil, not claimAll.enabled)

	optOut(canvas)
	M.animate(canvas, { sound = function(kind) UISound.Play(kind == "hover" and "Hover" or "Click") end })
	canvas.Parent = layer
	return self
end

function QuestMenuComponent:Destroy()
	self.alive = false
	self.sizeConnection:Disconnect()
	self.canvas:Destroy()
end

return QuestMenuComponent
