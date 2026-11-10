--[[ ReplicatedStorage.Leaderboard.LeaderboardView  (ModuleScript) - Folk Stud rebuild, 2026-11-08
Builds one leaderboard UI inside a container: the board's SurfaceGui ("Board") or the expanded
ScreenGui panel ("Screen" / "Compact"). Every view renders the same state from LeaderboardClient.

Look (the game's Folk Stud UI): a white studded sheet with a thick black outline, "LEADERBOARD" in big
gold letters with a sweeping light, three chunky studded tabs (the selected one gold and a bit bigger),
a THIS SERVER / GLOBAL toggle, white rows with black outlines and gold / silver / bronze medals for the
top three, your own row outlined in gold, and a red studded YOUR RANK card pinned at the bottom.

Everything is laid out on one 800 x 700 design canvas and scaled to fit its container with a UIScale,
so the board and the expanded window look the same and nothing overlaps at any size.
Pure UI: owns no data and talks to no remote; input goes out through the callbacks table
({ onTab(statId), onScope(scope), onClose() }) passed to View.new.
Old shrine version: ServerStorage._ARCHIVE.LeaderboardView_BeforeStudRebuild_2026-11-08
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(script.Parent.LeaderboardConfig)
local Format = require(script.Parent.LeaderboardFormat)
local FolkStud = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = FolkStud.H
local C = FolkStud.COLOR

local DW, DH = 800, 700 -- design canvas
local ROW_H, ROW_GAP = 58, 8
local COUNT_TIME = 0.6
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local GREEN = H.hex("2BF08C")
local GOLD = H.hex("FFC400")
local FONT = FolkStud.FONT
local CASH_ART = "rbxassetid://136807180106184"
local MEDALS = {
	{ H.hex("FFE600"), H.hex("FF9D00"), H.hex("8C5200") }, -- gold
	{ H.hex("FFFFFF"), H.hex("A9B8CC"), H.hex("4A5668") }, -- silver
	{ H.hex("FFB27A"), H.hex("D2691E"), H.hex("6E3410") }, -- bronze
}

local View = {}
View.__index = View

-- a label of fixed size that shrinks long text instead of running over (rows, card)
local function label(parent, name, text, x, y, w, h, size, color, alignX, z)
	local l = H.new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = FONT,
		Text = text,
		TextColor3 = color or WHITE,
		TextSize = size, -- a plain size, so it scales with the board's UIScale (TextScaled caps in screen pixels)
		TextXAlignment = alignX or Enum.TextXAlignment.Center,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(w, h),
		ZIndex = z or 6,
	}, parent)
	H.new("UIStroke", { Name = "UIStroke", Thickness = math.clamp(size * 0.12, 2, 3.7), Color = BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, l)
	return l
end

local function circle(parent, name, cx, cy, size, z)
	local f = H.new("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(size, size), ZIndex = z, BackgroundColor3 = WHITE }, parent)
	H.new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
	H.ink(f, 3)
	return f
end

local function setPalette(face, pal)
	local g = face:FindFirstChildOfClass("UIGradient")
	if g then
		g.Color = ColorSequence.new(pal[1], pal[2])
	end
end

---------------------------------------------------------------- build
function View.new(parent, mode, callbacks)
	local self = setmetatable({}, View)
	self.mode = mode
	self.callbacks = callbacks or {}
	self.rows = {}
	self.scroll = {}
	self.conns = {}
	self.tabs = {}
	self:_build(parent)
	return self
end

function View:_build(parent)
	-- panel modes: the client's old wooden shell becomes a plain black outline (no roof, studs or bevel)
	if self.mode ~= "Board" then
		local shell = parent.Parent
		if shell and shell:IsA("Frame") then
			shell.BackgroundColor3 = BLACK
			for _, n in { "Roof", "Bevel", "Studs" } do
				local p = shell:FindFirstChild(n)
				if p then
					p.Visible = false
				end
			end
			parent.Position = UDim2.fromOffset(4, 4)
			parent.Size = UDim2.new(1, -8, 1, -8)
			parent.BackgroundColor3 = WHITE
			local trim = parent:FindFirstChildOfClass("UIStroke")
			if trim then
				trim.Enabled = false
			end
		end
	end

	-- root fills the container (the client looks for a child named "Leaderboard" on boards, so it is named V2)
	local root = H.new("Frame", { Name = "LeaderboardV2", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ClipsDescendants = true }, parent)
	H.studs(root, Vector2.new(50, 46), 0.8, nil, 1)
	self.root = root
	local design = H.new("Frame", { Name = "Design", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(DW, DH), BackgroundTransparency = 1, ZIndex = 2 }, root)
	local fit = H.new("UIScale", { Name = "Fit" }, design)
	local function refit()
		local s = root.AbsoluteSize
		if s.X > 1 and s.Y > 1 then
			-- AbsoluteSize already includes ancestor UIScales; undo them so the fit is in the root's own units
			local k = 1
			local a = root.Parent
			while a do
				local sc = a:FindFirstChildOfClass("UIScale")
				if sc and a:IsA("GuiObject") then
					k *= sc.Scale
				end
				a = a.Parent
				if a and a:IsA("LayerCollector") then
					break
				end
			end
			fit.Scale = math.min(s.X / DW, s.Y / DH) / k
		end
	end
	table.insert(self.conns, root:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit))
	task.defer(refit)
	refit()
	local d = design

	-- title
	local title = H.text(d, "Title", "LEADERBOARD", DW / 2, 44, 62, 8)
	H.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(H.hex("FFE600"), H.hex("FF8A00")) }, title)
	H.gleam(title)
	H.sparkle(d, "Twinkle1", DW / 2 - 230, 24, 30, 9, 0)
	H.sparkle(d, "Twinkle2", DW / 2 + 232, 58, 24, 9, 0.5)
	if self.mode ~= "Board" then
		local close = H.closeButton(d, DW - 78, 8)
		table.insert(self.conns, close.Activated:Connect(function()
			if self.callbacks.onClose then
				self.callbacks.onClose()
			end
		end))
	end

	-- tabs
	local TW, TH, TG = 240, 62, 16
	local tx = (DW - #Config.Stats * TW - (#Config.Stats - 1) * TG) / 2
	for i, stat in Config.Stats do
		local x = tx + (i - 1) * (TW + TG)
		H.shadow(d, "Tab" .. stat.Id, x, 92, TW, TH, 14, 3)
		local b = H.button(d, "Tab" .. stat.Id, x, 92, TW, TH, 14, C.blue, 4)
		label(b, "Label", stat.Tab, 12, 6, TW - 24, TH - 16, 30, WHITE, nil, b.ZIndex + 2)
		local face = b:FindFirstChild("Face")
		self.tabs[i] = { id = stat.Id, button = b, face = face }
		table.insert(self.conns, b.Activated:Connect(function()
			if self.callbacks.onTab then
				self.callbacks.onTab(stat.Id)
			end
		end))
	end

	-- scope toggle
	local SW, SH = 210, 46
	self.scopes = {}
	for i, scope in { { "Server", "THIS SERVER" }, { "Global", "GLOBAL" } } do
		local x = DW / 2 - SW - 6 + (i - 1) * (SW + 12)
		H.shadow(d, "Scope" .. scope[1], x, 168, SW, SH, 12, 3)
		local b = H.button(d, "Scope" .. scope[1], x, 168, SW, SH, 12, C.purple, 4)
		label(b, "Label", scope[2], 10, 4, SW - 20, SH - 14, 24, WHITE, nil, b.ZIndex + 2)
		self.scopes[scope[1]] = { button = b, face = b:FindFirstChild("Face") }
		table.insert(self.conns, b.Activated:Connect(function()
			if self.callbacks.onScope then
				self.callbacks.onScope(scope[1])
			end
		end))
	end

	-- column labels
	label(d, "ColRank", "RANK", 34, 224, 70, 22, 18, WHITE, Enum.TextXAlignment.Left, 6)
	label(d, "ColPlayer", "PLAYER", 150, 224, 160, 22, 18, WHITE, Enum.TextXAlignment.Left, 6)
	self.columnValue = label(d, "ColValue", "", DW - 250, 224, 214, 22, 18, WHITE, Enum.TextXAlignment.Right, 6)

	-- the list well
	local WY, WHH = 250, 344
	local well = H.rect(d, "Well", 20, WY, DW - 40, WHH, 14, 3, H.hex("2FB8FF"))
	H.grad(well, H.hex("2FB8FF"), H.hex("0283FB"))
	H.studs(well, Vector2.new(48, 48), 0.82, 13, 3)
	H.ink(well, 4)
	self.well = well
	local list = H.new("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(6, 6),
		Size = UDim2.new(1, -12, 1, -12),
		ScrollBarThickness = 8,
		ScrollBarImageColor3 = H.hex("9A9A9A"),
		TopImage = "",
		BottomImage = "",
		ScrollingDirection = Enum.ScrollingDirection.Y,
		CanvasSize = UDim2.new(),
		ZIndex = 4,
	}, well)
	self.list = list
	self.listW = DW - 40 - 12 - 14

	-- status (loading / empty / error), centred in the well
	local status = H.new("Frame", { Name = "Status", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 8, Visible = false }, well)
	self.statusTitle = label(status, "Title", "", 30, WHH / 2 - 60, DW - 100, 44, 36, GOLD, nil, 9)
	self.statusBody = label(status, "Body", "", 50, WHH / 2 - 8, DW - 140, 30, 22, WHITE, nil, 9)
	self.status = status

	-- YOUR RANK card
	local YY, YH = 606, 74
	H.shadow(d, "YourRank", 20, YY, DW - 40, YH, 16, 3)
	local card = H.rect(d, "YourRank", 20, YY, DW - 40, YH, 16, 4)
	H.ink(card, 4)
	H.grad(card, C.red[1], C.red[2])
	H.studs(card, Vector2.new(48, 48), 0.72, 15, 4)
	self.youLabel = label(d, "YouLabel", "YOUR RANK", 168, YY - 14, 360, 26, 22, H.hex("FFE600"), Enum.TextXAlignment.Left, 9)
	local you = {}
	you.badge = circle(card, "Badge", 46, YH / 2, 52, 6)
	you.badgeGrad = H.grad(you.badge, H.hex("FFE600"), H.hex("FF9D00"))
	you.rank = label(you.badge, "Rank", "—", 2, 8, 48, 34, 26, WHITE, nil, 7)
	local av = circle(card, "AvatarRing", 112, YH / 2, 52, 6)
	you.avatar = H.new("ImageLabel", { Name = "Avatar", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7 }, av)
	H.new("UICorner", { CornerRadius = UDim.new(1, 0) }, you.avatar)
	you.name = label(card, "Name", "", 150, 8, 330, 32, 28, WHITE, Enum.TextXAlignment.Left, 7)
	you.user = label(card, "Note", "", 150, 42, 380, 24, 19, H.hex("FFE600"), Enum.TextXAlignment.Left, 7)
	you.value = label(card, "Value", "—", DW - 40 - 250, 14, 226, 44, 38, GREEN, Enum.TextXAlignment.Right, 7)
	self.youRow = you

	-- meta line
	self.metaLeft = label(d, "MetaLeft", "", 26, DH - 16, 380, 16, 15, H.hex("6C6880"), Enum.TextXAlignment.Left, 6)
	self.metaRight = label(d, "MetaRight", "", DW - 26 - 300, DH - 16, 300, 16, 15, H.hex("6C6880"), Enum.TextXAlignment.Right, 6)
	for _, l in { self.metaLeft, self.metaRight } do
		l.UIStroke.Enabled = false
	end

	FolkStud.animate(root, { sounds = self.mode ~= "Board" })
end

-- one pooled row
function View:_row(i)
	local w = self.listW
	local y = (i - 1) * (ROW_H + ROW_GAP) + 2
	local f = H.rect(self.list, "Row" .. i, 2, y, w, ROW_H, 12, 5)
	local ink = H.ink(f, 3)
	local row = { frame = f, ink = ink }
	row.badge = circle(f, "Badge", 34, ROW_H / 2, 42, 6)
	row.badgeGrad = H.grad(row.badge, C.blue[1], C.blue[2])
	row.rank = label(row.badge, "Rank", "", 2, 7, 38, 28, 24, WHITE, nil, 7)
	local ring = circle(f, "AvatarRing", 96, ROW_H / 2, 44, 6)
	row.avatar = H.new("ImageLabel", { Name = "Avatar", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7 }, ring)
	H.new("UICorner", { CornerRadius = UDim.new(1, 0) }, row.avatar)
	row.name = label(f, "Name", "", 130, 5, 330, 28, 26, WHITE, Enum.TextXAlignment.Left, 7)
	row.user = label(f, "User", "", 132, 34, 330, 18, 16, H.hex("4A4560"), Enum.TextXAlignment.Left, 7)
	row.user.UIStroke.Enabled = false
	row.you = label(f, "You", "YOU", 470, 14, 60, 28, 22, H.hex("FFE600"), nil, 7)
	row.value = label(f, "Value", "", w - 236, 9, 222, 40, 32, GREEN, Enum.TextXAlignment.Right, 7)
	self.rows[i] = row
	return row
end

local function fillRow(row, entry, kind, isSelf, shownValue)
	local medal = entry.r and MEDALS[entry.r]
	if medal then
		row.badgeGrad.Color = ColorSequence.new(medal[1], medal[2])
	elseif row.frame then
		row.badgeGrad.Color = ColorSequence.new(C.blue[1], C.blue[2])
	else
		row.badgeGrad.Color = ColorSequence.new(H.hex("FFE600"), H.hex("FF9D00")) -- YOUR RANK badge stays gold
	end
	row.rank.Text = entry.r and tostring(entry.r) or "—"
	if row.frame then
		row.frame.BackgroundColor3 = medal and (entry.r == 1 and H.hex("FFF6C9") or entry.r == 2 and H.hex("F2F6FC") or H.hex("FFE9D8")) or WHITE
		row.ink.Color = isSelf and GOLD or BLACK
		row.ink.Thickness = isSelf and 5 or 3
		row.you.Visible = isSelf
	end
	local image = (entry.u and entry.u > 0) and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", entry.u) or ""
	if row.avatar.Image ~= image then
		row.avatar.Image = image
	end
	row.name.Text = entry.d or entry.n or "Unknown player"
	if row.frame then
		row.user.Text = entry.n and ("@" .. entry.n) or ""
	end
	row.target = entry.v
	local v = shownValue or entry.v
	row.value.Text = v and Format.Value(kind, v) or "—"
end

local function yourRankNote(ownEntry, entries, snapshot, status, scope, kind)
	if ownEntry.r and ownEntry.r > 1 and entries[ownEntry.r - 1] and entries[ownEntry.r - 1].v and ownEntry.v then
		local ahead = entries[ownEntry.r - 1]
		return Format.Value(kind, math.max(0, ahead.v - ownEntry.v)) .. " to pass " .. (ahead.d or ahead.n or "the next player")
	elseif ownEntry.r == 1 then
		return "You lead " .. (scope == "Server" and "this server!" or "everyone!")
	elseif not snapshot or status == "loading" then
		return "Loading..."
	elseif status == "unavailable" then
		return "Global unavailable"
	elseif scope == "Global" and ownEntry.v and ownEntry.v > 0 then
		return (snapshot.total or 0) >= (snapshot.depth or 100) and ("Outside the top " .. (snapshot.depth or 100) .. " · keep climbing")
			or "Not on the global board yet"
	end
	return "Not ranked yet"
end

---------------------------------------------------------------- state
function View:_selectTab(index)
	for i, t in self.tabs do
		local on = i == index
		setPalette(t.face, on and C.gold or C.blue)
		local pop = t.button:FindFirstChild("Pop")
		if pop then
			TweenService:Create(pop, TweenInfo.new(0.16, Enum.EasingStyle.Back), { Scale = on and 1.06 or 1 }):Play()
		end
	end
	self.tabIndex = index
end

function View:_selectScope(scope)
	for id, s in self.scopes do
		setPalette(s.face, id == scope and C.green or C.purple)
	end
	self.scopeId = scope
end

function View:_setStatus(kind, title, body)
	if not kind then
		self.status.Visible = false
		return
	end
	self.status.Visible = true
	if kind == "loading" then
		self.statusTitle.Text = "Loading..."
		self.statusBody.Text = ""
	else
		self.statusTitle.Text = title or ""
		self.statusBody.Text = body or ""
	end
end

function View:_meta(state)
	local snapshot = state.snapshot
	if state.scope == "Server" then
		local n = snapshot and snapshot.total
		self.metaLeft.Text = n and string.format("THIS SERVER  ·  %d ranked", n) or "THIS SERVER"
	else
		self.metaLeft.Text = "GLOBAL  ·  all servers, top " .. Config.MaxRows
	end
	local right = ""
	if snapshot and snapshot.updated then
		local age = workspace:GetServerTimeNow() - snapshot.updated
		right = snapshot.status == "stale" and ("Couldn't refresh  ·  from " .. Format.Age(age)) or ("Updated " .. Format.Age(age))
	end
	self.metaRight.Text = right
end

function View:_countUp(kind)
	local token = {}
	self.countToken = token
	local started = os.clock()
	local targets = {}
	for _, row in self.rows do
		if row.frame.Visible and row.target then
			table.insert(targets, row)
		end
	end
	if self.youRow.target then
		table.insert(targets, self.youRow)
	end
	task.spawn(function()
		while self.countToken == token and self.root and self.root.Parent do
			local t = math.clamp((os.clock() - started) / COUNT_TIME, 0, 1)
			local e = 1 - (1 - t) ^ 3
			for _, row in targets do
				if row.target then
					row.value.Text = Format.Value(kind, math.floor(row.target * e + 0.5))
				end
			end
			if t >= 1 then
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
end

function View:Render(state)
	self.state = state
	local stat = Config.StatById[state.tab] or Config.Stats[1]
	local index = 1
	for i, tab in self.tabs do
		if tab.id == state.tab then
			index = i
		end
	end
	if index ~= self.tabIndex then
		self:_selectTab(index)
	end
	if state.scope ~= self.scopeId then
		self:_selectScope(state.scope)
	end
	self.columnValue.Text = stat.Column

	local key = state.tab .. "|" .. state.scope
	local restore
	if key ~= self.key then
		if self.key then
			self.scroll[self.key] = self.list.CanvasPosition
		end
		self.key = key
		restore = self.scroll[key] or Vector2.zero
	end

	local snapshot = state.snapshot
	local entries = snapshot and snapshot.entries or {}
	local count = math.min(#entries, Config.MaxRows)
	local animate = count > 0 and self.counted ~= key
	if animate then
		self.counted = key
	end
	for i = 1, count do
		local row = self.rows[i] or self:_row(i)
		local entry = entries[i]
		fillRow(row, entry, stat.Kind, entry.u == state.localUserId, animate and 0 or nil)
		row.frame.Visible = true
	end
	for i = count + 1, #self.rows do
		self.rows[i].frame.Visible = false
		self.rows[i].target = nil
	end
	self.list.CanvasSize = UDim2.fromOffset(0, count * (ROW_H + ROW_GAP) + 6)
	if restore then
		local list = self.list
		task.defer(function()
			if list.Parent then
				list.CanvasPosition = restore
			end
		end)
	end

	local status = snapshot and snapshot.status
	if count > 0 then
		self:_setStatus(nil)
	elseif state.phase == "error" and not snapshot then
		self:_setStatus("error", "Couldn't load rankings", "Trying again in a few seconds.")
	elseif state.phase == "loading" or status == "loading" then
		self:_setStatus("loading")
	elseif status == "unavailable" then
		self:_setStatus("error", "Global rankings are resting", "Your score is safe. Try THIS SERVER.")
	else
		self:_setStatus("empty", "The first spot is open!", stat.Empty)
	end

	local yr = snapshot and snapshot.you
	local own = { r = yr and yr.r, u = state.localUserId, n = state.localName, d = state.localDisplayName, v = yr and yr.v }
	fillRow(self.youRow, own, stat.Kind, false, animate and own.v and 0 or nil)
	self.youLabel.Text = "YOUR RANK  ·  " .. (state.scope == "Server" and "THIS SERVER" or "GLOBAL")
	self.youRow.user.Text = yourRankNote(own, entries, snapshot, status, state.scope, stat.Kind)
	self.youRow.rank.Text = own.r and tostring(own.r) or "—"
	if animate then
		self:_countUp(stat.Kind)
	end
	self:_meta(state)
end

function View:Tick()
	if self.state then
		self:_meta(self.state)
	end
end

function View:DefaultSelection()
	local tab = self.tabs[self.tabIndex or 1]
	return tab and tab.button
end

function View:Destroy()
	self.countToken = nil
	for _, c in self.conns do
		c:Disconnect()
	end
	if self.root then
		self.root:Destroy()
		self.root = nil
	end
end

return View
