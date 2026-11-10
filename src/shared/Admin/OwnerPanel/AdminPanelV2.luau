--[[ ReplicatedStorage.OwnerPanel.AdminPanelV2 (ModuleScript, client) - 2026-11-10
The staff panel, second version, in the Folk Stud look (ReplicatedStorage.FolkStudUI).
Sidebar of pages on the left, search + shared target chip on top, one scrolling page on the right.
  AdminPanelV2.Build(gui, context) -> { open(), close(), toggle(), refresh(), show(pageId) }
  context = { role = "Owner" | "Admin", userId, userName, invoke = function(action, args) -> (ok, messageOrData) }
Same contract as StudPanel.Build, so OwnerPanelClient only swaps the module. StudPanel stays as the "classic" fallback
(Server page -> CLASSIC PANEL), which still has the save restore page.
Nothing here is trusted: OwnerPanelServer checks the role, the arguments and the confirm flag on every invoke.
The server takes one request at a time per player, 0.2 s apart, so every call goes through one queue (busy flag).

Pages and the server actions they call (OwnerPanel.Action):
  events   StartEvent/StopEvent {eventId, seconds}, StartNight {seconds}/StopNight, StartHighTide {seconds}/StopHighTide,
           StartBoss/StopBoss, StartArena/StopArena, StartVolcano/StopVolcano, StartMeteor/StopMeteor, EggShower {amount},
           StartBoost {targets, multiplier, seconds}, StopBoost {target?}, StopAllEvents
  economy  GiveCash {amount, scope, userId, confirmed?}, TakeCash {who, amount | "all", confirmed}, SetCash {amount, userId, confirmed}
  spawn    GiveEgg / GiveCharacter {itemId, mutation?, amount, scope, userId}, SpawnEgg {itemId, mutation?, amount} (river)
  players  GoTo, Bring, SendHome, Respawn*, Kick*, Ban*, SetFreecam {userId, on}, SetAdmin {userId, on, name},
           UpgradeTemple, UnlockSlot, AddIncubator, UpgradeIncubator {index}, ClearInventory*, ClearPlaced*, ResetSlots*,
           WipePlayer {who}*            (* = sent with confirmed = true after the confirm dialog)
  server   Announce {text, color, allServers}, AnnounceUpdate {}, SetSpawnInterval {seconds}, JoinStaffServer, ReturnToPublic,
           AdminAbuse {text}, Unban {userId}*, SetAdmin {userId, on}
  log      (local only)
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Folk = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H, C = Folk.H, Folk.COLOR
local WHITE, BLACK = H.WHITE, H.BLACK
local GOLD = Color3.fromRGB(255, 208, 0)
local okRarity, RarityText = pcall(function()
	return require(ReplicatedStorage:WaitForChild("RarityText", 5))
end)

local W, HH = 1160, 680 -- design size of the window; a UIScale fits it to the screen
local RX, RY, RW, RH = 232, 112, 912, 552 -- the page region inside the window
local CW = RW - 18 -- usable page width (the scroll bar keeps the rest)

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Cosmic", "Limited" }
local RARITY_PAL = {
	Common = C.sky, Uncommon = C.green, Rare = C.blue, Epic = C.purple,
	Legendary = C.gold, Mythic = C.red, Cosmic = C.pink, Limited = C.orange,
}
local MUTATIONS = {
	{ "None", "NONE", C.blue }, { "Silver", "SILVER", C.sky }, { "Gold", "GOLD", C.gold },
	{ "Diamond", "DIAMOND", C.aqua }, { "Rainbow", "RAINBOW", C.pink }, { "Molten", "MOLTEN", C.orange },
}
-- seconds = takes a duration; max = the server's own cap for that event (it clamps again)
local EVENTS = {
	{ id = "rush", icon = "🥚", name = "EGG RUSH", desc = "Eggs spawn 2x faster", pal = C.orange, start = "StartEvent", stop = "StopEvent", timed = true, max = 7200, eventId = true },
	{ id = "cash", icon = "💰", name = "DOUBLE CASH", desc = "All income x2", pal = C.green, start = "StartEvent", stop = "StopEvent", timed = true, max = 7200, eventId = true },
	{ id = "gold", icon = "🌅", name = "GOLDEN HOUR", desc = "Golden sunset sky", pal = C.gold, start = "StartEvent", stop = "StopEvent", timed = true, max = 7200, eventId = true },
	{ id = "night", icon = "🌙", name = "NIGHTTIME", desc = "Night falls (max 10 min)", pal = C.purple, start = "StartNight", stop = "StopNight", timed = true, max = 600 },
	{ id = "rapids", icon = "🌊", name = "RAPIDS", desc = "High tide river (max 10 min)", pal = C.blue, start = "StartHighTide", stop = "StopHighTide", timed = true, max = 600 },
	{ id = "boss", icon = "👹", name = "RIVER BOSS", desc = "Summon the boss", pal = C.red, start = "StartBoss", stop = "StopBoss" },
	{ id = "arena", icon = "⚔️", name = "ARENA BRAWL", desc = "Start an arena round", pal = C.pink, start = "StartArena", stop = "StopArena" },
	{ id = "volcano", icon = "🌋", name = "VOLCANO", desc = "The volcano erupts", pal = C.mango, start = "StartVolcano", stop = "StopVolcano" },
	{ id = "meteor", icon = "☄️", name = "METEOR SHOWER", desc = "Meteors rain down", pal = C.azure, start = "StartMeteor", stop = "StopMeteor" },
}
local BOOSTS = {
	{ "Cash", "💰 CASH", C.green }, { "Luck", "🍀 LUCK", C.leaf }, { "Hatch", "🐣 HATCH SPEED", C.orange },
	{ "Mutation", "🧬 MUTATION", C.pink }, { "RiverSpeed", "🌊 RIVER SPEED", C.blue },
}

------------------------------------------------------------------ small helpers
local function label(parent, str, x, y, w, h, size, align, z, col)
	local l = H.new("TextLabel", {
		Name = "Label", BackgroundTransparency = 1, FontFace = Folk.FONT, Text = str, TextSize = size, TextColor3 = col or WHITE,
		Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z or 6, TextWrapped = true,
		TextXAlignment = align == "left" and Enum.TextXAlignment.Left or (align == "right" and Enum.TextXAlignment.Right or Enum.TextXAlignment.Center),
		TextYAlignment = Enum.TextYAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd,
	}, parent)
	H.new("UIStroke", { Name = "UIStroke", Thickness = 3.7, Color = BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, l)
	return l
end
-- pressable: lip + studs. o.light = no moving shine (for grids with many cells). Returns the button and its label
local function btn(parent, str, x, y, w, h, pal, onClick, o)
	o = o or {}
	local r, lip, z = o.r or 14, o.lip or 5, o.z or 5
	local b = H.button(parent, "Btn", x, y, w, h, r, pal, z, { lip = lip, plain = o.light, studs = 0.6 })
	local face = b:FindFirstChild("Face")
	if o.light and face then
		H.studs(face, Vector2.new(48, 48), 0.65, r - 1)
	end
	local l = label(b, str, 6, 0, w - 12, h - lip, o.size or 22, o.align, z + 3)
	if onClick then
		b.Activated:Connect(function()
			onClick(b, l)
		end)
	end
	return b, l
end
local function setSelected(b, on)
	local s = b:FindFirstChild("Outline")
	if s then
		s.Color = on and GOLD or BLACK
		s.Thickness = on and 7 or 4
	end
end
-- read-only: flat, black outline, no lip
local function card(parent, x, y, w, h, pal, z)
	local f = H.rect(parent, "Card", x, y, w, h, 16, z or 3)
	H.grad(f, pal[1], pal[2])
	H.ink(f, 4)
	H.gloss(f, 16, z or 3)
	return f
end
local function heading(parent, str, x, y)
	return H.text(parent, "Heading", str, x, y + 16, 26, 6, WHITE, "left")
end
-- a text field: flat blue box with a black outline. onChange(text) on every edit
local function input(parent, x, y, w, h, placeholder, value, onChange, z)
	local f = H.rect(parent, "Input", x, y, w, h, 14, z or 4)
	H.grad(f, C.azure[1], C.azure[2])
	H.ink(f, 4)
	local box = H.new("TextBox", {
		Name = "Box", BackgroundTransparency = 1, FontFace = Folk.FONT, Text = value or "", PlaceholderText = placeholder or "",
		PlaceholderColor3 = Color3.fromRGB(200, 232, 255), TextColor3 = WHITE, TextSize = math.min(22, math.floor(h * 0.44)), ClearTextOnFocus = false,
		Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -28, 1, 0), TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = (z or 4) + 1,
	}, f)
	H.new("UIStroke", { Name = "UIStroke", Thickness = 3.7, Color = BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, box)
	if onChange then
		box:GetPropertyChangedSignal("Text"):Connect(function()
			onChange(box.Text)
		end)
	end
	return box, f
end
-- a row of pick-one (or pick-many when current is a set) chips that wraps. Returns the y under the row
local function chipRow(parent, x, y, maxW, options, current, onPick, cw, ch)
	ch = ch or 46
	local cx, cy = x, y
	for _, opt in ipairs(options) do
		local value, text, pal, w = opt[1], opt[2], opt[3] or C.blue, opt[4] or cw or 110
		if cx + w > x + maxW + 1 and cx > x then
			cx, cy = x, cy + ch + 12
		end
		local b = btn(parent, text, cx, cy, w, ch, pal, function()
			onPick(value)
		end, { size = 18, lip = 4, r = 12, light = true })
		local on
		if type(current) == "table" then
			on = current[value] == true
		else
			on = current == value
		end
		setSelected(b, on)
		cx += w + 12
	end
	return cy + ch + 14
end
local function parseAmount(s)
	if type(s) == "number" then
		return s
	end
	local clean = (tostring(s or ""):lower():gsub("[,%s%$]", ""))
	local num, suffix = clean:match("^([%d%.]+)([kmbt]?)$")
	local n = tonumber(num)
	if not n then
		return nil
	end
	local mult = ({ k = 1e3, m = 1e6, b = 1e9, t = 1e12 })[suffix] or 1
	n = math.floor(n * mult + 0.5)
	if n ~= n or n < 0 or n > 1e15 then
		return nil
	end
	return n
end
local function commas(n)
	local s = string.format("%.0f", tonumber(n) or 0)
	local out = (s:reverse():gsub("(%d%d%d)", "%1,")):reverse()
	if out:sub(1, 1) == "," then
		out = out:sub(2)
	end
	return out
end
local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end
local function matches(query, ...)
	if query == "" then
		return true
	end
	for _, s in ipairs({ ... }) do
		if type(s) == "string" and s:lower():find(query, 1, true) then
			return true
		end
	end
	return false
end
local thumbs = {}
local function avatar(parent, userId, x, y, size, z)
	local f = H.rect(parent, "Avatar", x, y, size, size, 14, z or 5)
	H.grad(f, C.sky[1], C.sky[2])
	H.ink(f, 3)
	local img = H.new("ImageLabel", { Name = "Face", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = (z or 5) + 1, Image = thumbs[userId] or "" }, f)
	H.round(img, 14)
	if not thumbs[userId] and type(userId) == "number" and userId > 0 then
		task.spawn(function()
			local ok, url = pcall(Players.GetUserThumbnailAsync, Players, userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
			if ok and type(url) == "string" then
				thumbs[userId] = url
				if img.Parent then
					img.Image = url
				end
			end
		end)
	end
	return f
end

local AdminPanelV2 = {}

function AdminPanelV2.Build(gui, context)
	local isOwner = context.role == "Owner"
	local api = {}
	local pages, pageOrder = {}, {}
	local page = "events"
	local search = ""
	local render -- forward

	------------------------------------------------------------------ frame
	local dim = H.new("TextButton", { Name = "Dim", Text = "", AutoButtonColor = false, BackgroundColor3 = BLACK, BackgroundTransparency = 0.5, Size = UDim2.fromScale(1, 1), ZIndex = 0 }, gui)
	local root = H.new("Frame", { Name = "Root", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 12), Size = UDim2.fromOffset(W, HH) }, gui)
	local fit = H.new("UIScale", { Name = "Fit" }, root)
	local stage = H.new("Frame", { Name = "Stage", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1) }, root)
	local pop = H.new("UIScale", { Name = "Pop" }, stage)
	local function refit()
		local v = gui.AbsoluteSize
		if v.X < 50 or v.Y < 50 then
			local cam = workspace.CurrentCamera
			v = cam and cam.ViewportSize or v
		end
		if v.X < 50 or v.Y < 50 then
			return
		end
		-- room for the X that hangs over the corner and the title on the top border
		fit.Scale = math.clamp(math.min((v.X - 16) / (W + 60), (v.Y - 16) / (HH + 84)), 0.25, 1.3)
	end
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)

	H.shadow(stage, "Window", -2, 4, W + 4, HH + 4, 16, 1)
	local win = H.rect(stage, "Window", 0, 0, W, HH, 14, 1)
	H.ink(win, 4)
	H.studs(win, Vector2.new(50, 46), 0.8, 12, 1)
	local title = H.text(stage, "Title", isOwner and "OWNER PANEL" or "ADMIN PANEL", 30, -2, 46, 8, WHITE, "left")
	H.gleam(title)
	local closeBtn = H.closeButton(stage, W - 42, -26)
	closeBtn.Activated:Connect(function()
		api.close()
	end)

	local scroll = H.new("ScrollingFrame", {
		Name = "Page", BackgroundTransparency = 1, Position = UDim2.fromOffset(RX, RY), Size = UDim2.fromOffset(RW, RH), CanvasSize = UDim2.new(),
		ScrollBarThickness = 8, ScrollBarImageColor3 = BLACK, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3,
	}, stage)
	-- parts of a page that do not scroll (the spawn bar, the player actions); positions are window coordinates
	local fixed = H.new("Frame", { Name = "Fixed", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4 }, stage)

	------------------------------------------------------------------ toast
	local toastCard = card(stage, (W - 660) / 2, HH - 84, 660, 60, C.leaf, 60)
	toastCard.Name = "Toast"
	toastCard.Visible = false
	local toastGrad = toastCard:FindFirstChildOfClass("UIGradient")
	local toastLabel = label(toastCard, "", 14, 0, 632, 60, 20, "center", 62)
	local toastId = 0
	local function toast(ok, message)
		toastId += 1
		local id = toastId
		local pal = ok == nil and C.azure or (ok and C.leaf or C.coral)
		if toastGrad then
			toastGrad.Color = ColorSequence.new(pal[1], pal[2])
		end
		toastLabel.Text = (ok == nil and "" or (ok and "✓  " or "✕  ")) .. tostring(message)
		toastCard.Visible = true
		toastCard.Position = UDim2.fromOffset((W - 660) / 2, HH - 54)
		TweenService:Create(toastCard, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Position = UDim2.fromOffset((W - 660) / 2, HH - 84) }):Play()
		task.delay(3.2, function()
			if id == toastId then
				toastCard.Visible = false
			end
		end)
	end

	------------------------------------------------------------------ overlay: confirm dialog and target picker
	local overlay
	local function closeOverlay()
		if overlay then
			overlay:Destroy()
			overlay = nil
		end
	end
	local function openOverlay()
		closeOverlay()
		overlay = H.new("Frame", { Name = "Overlay", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 40 }, stage)
		local shade = H.new("TextButton", { Name = "Shade", Text = "", AutoButtonColor = false, BackgroundColor3 = BLACK, BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 40 }, overlay)
		H.round(shade, 14)
		shade.Activated:Connect(closeOverlay)
		return overlay
	end
	local function dialog(dw, dh, titleText)
		local o = openOverlay()
		local x0, y0 = (W - dw) / 2, (HH - dh) / 2
		H.shadow(o, "Dialog", x0, y0, dw, dh, 16, 42)
		local d = H.rect(o, "Dialog", x0, y0, dw, dh, 16, 43)
		d.Active = true
		H.ink(d, 4)
		H.studs(d, Vector2.new(50, 46), 0.8, 14, 1)
		label(d, titleText, 20, 16, dw - 40, 50, 30, "center", 5)
		return d
	end
	local function confirm(titleText, body, yesText, onYes)
		local dw, dh = 580, 300
		local d = dialog(dw, dh, titleText)
		label(d, body, 30, 72, dw - 60, 112, 20, "center", 5)
		btn(d, "CANCEL", 30, dh - 96, 240, 68, C.blue, closeOverlay, { size = 26 })
		btn(d, yesText or "YES, DO IT", dw - 270, dh - 96, 240, 68, C.red, function()
			closeOverlay()
			onYes()
		end, { size = 26 })
	end

	------------------------------------------------------------------ data: snapshot, target, server calls
	local snapshot = { players = {}, catalog = {}, liveEvents = {} }
	local snapClock, snapServer = os.clock(), 0
	local target = { kind = "me", userId = context.userId }
	local log = {}
	local busy, lastCall = false, 0

	local function findPlayer(userId)
		for _, p in ipairs(snapshot.players) do
			if p.userId == userId then
				return p
			end
		end
		return nil
	end
	local function targetName()
		if target.kind == "lobby" then
			return "EVERYONE (" .. #snapshot.players .. ")"
		elseif target.kind == "me" then
			return "ME"
		end
		local p = findPlayer(target.userId)
		return p and tostring(p.name) or "NOBODY (LEFT)"
	end
	local function targetUserId()
		if target.kind == "me" then
			return context.userId
		elseif target.kind == "player" then
			return target.userId
		end
		return nil
	end
	-- fills scope / userId the way OwnerPanelServer reads them
	local function withTarget(args)
		args = args or {}
		if target.kind == "lobby" then
			args.scope = "lobby"
		elseif target.kind == "me" then
			args.scope = "me"
			args.userId = context.userId
		else
			args.scope = "player"
			args.userId = target.userId
		end
		return args
	end
	-- seconds left until a server time, measured from the last snapshot
	local function remaining(ends)
		if type(ends) ~= "number" then
			return nil
		end
		return ends - (snapServer + (os.clock() - snapClock))
	end
	-- one server call; waits out the server's 0.2 s gap. Yields. Returns (ok, messageOrData)
	local function call(action, args)
		local gap = 0.26 - (os.clock() - lastCall)
		if gap > 0 then
			task.wait(gap)
		end
		local okCall, ok, message = pcall(context.invoke, action, args or {})
		lastCall = os.clock()
		if not okCall then
			return false, "Server didn't respond"
		end
		return ok == true, message
	end
	local function fetchSnapshot()
		local ok, data = call("Snapshot", {})
		if ok and type(data) == "table" then
			data.players = type(data.players) == "table" and data.players or {}
			data.catalog = type(data.catalog) == "table" and data.catalog or {}
			data.liveEvents = type(data.liveEvents) == "table" and data.liveEvents or {}
			snapshot = data
			snapClock, snapServer = os.clock(), tonumber(data.serverTime) or 0
		end
		return ok
	end
	local function typing()
		local box = UserInputService:GetFocusedTextBox()
		return box ~= nil and box:IsDescendantOf(scroll)
	end
	local function addLog(what, ok, message)
		table.insert(log, 1, { time = os.date("%H:%M:%S"), what = what, ok = ok, msg = message })
		if #log > 80 then
			table.remove(log)
		end
	end
	-- the only way actions reach the server: one at a time, logged, toasted, then the snapshot is refreshed
	local function send(action, args, what, done)
		if busy then
			toast(nil, "Hold on, still working on the last one...")
			return
		end
		busy = true
		task.spawn(function()
			local okRun, err = pcall(function()
				local ok, message = call(action, args or {})
				local text = type(message) == "string" and message or (ok and "Done" or "Failed")
				addLog(what or action, ok, text)
				toast(ok, text)
				fetchSnapshot()
				if done then
					done(ok, message)
				end
			end)
			busy = false
			if not okRun then
				warn("[AdminPanelV2]", err)
			end
			if gui.Enabled and (pages[page].live or page == "log") and not typing() then
				render(true)
			end
		end)
	end
	local function refresh(force)
		if busy then
			return
		end
		busy = true
		task.spawn(function()
			pcall(fetchSnapshot)
			busy = false
			if gui.Enabled and (force or pages[page].live) and not typing() then
				render(true)
			end
		end)
	end

	local function pickTarget()
		local dw, dh = 520, 600
		local d = dialog(dw, dh, "WHO IS THE TARGET?")
		local function choose(kind, userId)
			target = { kind = kind, userId = userId }
			closeOverlay()
			render(true)
		end
		local half = isOwner and (dw - 60 - 12) / 2 or (dw - 60)
		setSelected(btn(d, "🙋 ME", 30, 76, half, 60, C.green, function()
			choose("me", context.userId)
		end, { size = 24 }), target.kind == "me")
		if isOwner then
			setSelected(btn(d, "🌍 EVERYONE", 30 + half + 12, 76, half, 60, C.purple, function()
				choose("lobby", nil)
			end, { size = 24 }), target.kind == "lobby")
		end
		local list = H.new("ScrollingFrame", {
			Name = "List", BackgroundTransparency = 1, Position = UDim2.fromOffset(22, 152), Size = UDim2.fromOffset(dw - 44, dh - 172), CanvasSize = UDim2.new(),
			ScrollBarThickness = 8, ScrollBarImageColor3 = BLACK, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 5,
		}, d)
		local y = 8
		for _, p in ipairs(snapshot.players) do
			local b = btn(list, "", 8, y, dw - 76, 64, p.role and C.gold or C.blue, function()
				choose("player", p.userId)
			end, { light = true, lip = 4 })
			avatar(b, p.userId, 8, 6, 48, 8)
			label(b, tostring(p.name) .. "  @" .. tostring(p.user), 66, 0, dw - 76 - 76, 60, 20, "left", 8)
			setSelected(b, target.kind == "player" and target.userId == p.userId)
			y += 76
		end
		list.CanvasSize = UDim2.fromOffset(0, y + 8)
	end
	-- actions that only make sense on one player
	local function needOne()
		if target.kind == "lobby" or (target.kind == "player" and not findPlayer(target.userId)) then
			toast(false, "Pick one player first")
			pickTarget()
			return false
		end
		return true
	end

	------------------------------------------------------------------ sidebar and top bar
	local navButtons = {}
	local function addPage(id, text, pal, def)
		def.id = id
		pages[id] = def
		table.insert(pageOrder, id)
		local i = #pageOrder
		navButtons[id] = btn(stage, text, 18, 46 + (i - 1) * 74, 196, 62, pal, function()
			api.show(id)
		end, { size = 22, align = "left" })
	end
	label(stage, isOwner and "👑 OWNER" or "🛡️ ADMIN", 18, HH - 126, 196, 30, 20, "center", 6)
	btn(stage, "🔄 REFRESH", 18, HH - 88, 196, 62, C.sky, function()
		refresh(true)
		toast(nil, "Refreshing...")
	end, { size = 22 })

	local searchBox = input(stage, RX, 48, 300, 54, "🔍 Search this page...", "", function(text)
		search = text:lower()
		if render then
			render(false)
		end
	end, 5)
	local targetBtn, targetLabel = btn(stage, "", RX + 314, 48, 330, 54, C.purple, pickTarget, { size = 20 })
	btn(stage, "ME", RX + 656, 48, 84, 54, C.green, function()
		target = { kind = "me", userId = context.userId }
		render(true)
	end, { size = 20 })
	if isOwner then
		btn(stage, "ALL", RX + 752, 48, 84, 54, C.pink, function()
			target = { kind = "lobby" }
			render(true)
		end, { size = 20 })
	end

	local live = {} -- functions run twice a second while the panel is open (countdowns)
	render = function(keepScroll)
		local at = scroll.CanvasPosition
		for _, child in ipairs(scroll:GetChildren()) do
			child:Destroy()
		end
		for _, child in ipairs(fixed:GetChildren()) do
			child:Destroy()
		end
		table.clear(live)
		scroll.Position = UDim2.fromOffset(RX, RY)
		scroll.Size = UDim2.fromOffset(RW, RH)
		for id, b in pairs(navButtons) do
			setSelected(b, id == page)
		end
		targetLabel.Text = "🎯 " .. targetName()
		local ok, height = pcall(pages[page].draw)
		if not ok then
			warn("[AdminPanelV2] page", page, height)
			label(scroll, "This page hit an error: " .. tostring(height), 8, 8, CW - 16, 120, 20, "left")
			height = 140
		end
		scroll.CanvasSize = UDim2.fromOffset(0, (tonumber(height) or 0) + 16)
		scroll.CanvasPosition = keepScroll and at or Vector2.zero
	end

	------------------------------------------------------------------ page: events
	local ev = { seconds = 300, custom = "", targets = { Cash = true }, mult = 2, multCustom = "", shower = 8 }
	addPage("events", "🎉 EVENTS", C.orange, {
		live = true,
		draw = function()
			local x0, y, w = 8, 6, CW - 8
			heading(scroll, "⏱️ HOW LONG  (timed events and boosts)", x0, y)
			y += 40
			local rowY = y
			y = chipRow(scroll, x0, y, w - 220, {
				{ 60, "1 MIN" }, { 120, "2 MIN" }, { 300, "5 MIN" }, { 600, "10 MIN" }, { 1800, "30 MIN" }, { 3600, "1 HOUR" },
			}, ev.custom == "" and ev.seconds or nil, function(v)
				ev.seconds, ev.custom = v, ""
				render(true)
			end, 100)
			input(scroll, x0 + w - 206, rowY, 206, 46, "or minutes...", ev.custom, function(text)
				ev.custom = text
				local minutes = tonumber(text)
				if minutes and minutes > 0 then
					ev.seconds = math.floor(minutes * 60)
				end
			end)

			heading(scroll, "🎉 EVENTS", x0, y)
			y += 40
			local cw, ch, col = math.floor((w - 24) / 3), 150, 0
			for _, e in ipairs(EVENTS) do
				if matches(search, e.name, e.desc) then
					local c = card(scroll, x0 + col * (cw + 12), y, cw, ch, e.pal)
					label(c, e.icon .. " " .. e.name, 12, 6, cw - 24, 32, 22, "left")
					label(c, e.desc, 12, 38, cw - 24, 22, 16, "left")
					local status = label(c, "OFF", 12, 62, cw - 24, 26, 18, "left")
					local bw = math.floor((cw - 36) / 2)
					btn(c, "▶ START", 12, 94, bw, 46, C.green, function()
						local args = {}
						if e.eventId then
							args.eventId = e.id
						end
						if e.timed then
							args.seconds = math.clamp(ev.seconds, 30, e.max)
						end
						send(e.start, args, "Start " .. e.name)
					end, { size = 20, lip = 4 })
					btn(c, "■ STOP", 24 + bw, 94, bw, 46, C.red, function()
						send(e.stop, e.eventId and { eventId = e.id } or {}, "Stop " .. e.name)
					end, { size = 20, lip = 4 })
					local function update()
						local st = snapshot.liveEvents[e.id]
						local on = type(st) == "table" and st.on == true
						local left = on and remaining(st.ends) or nil
						if on and e.timed and left and left <= 0 then
							on = false
						end
						if on then
							status.Text = "🟢 LIVE" .. ((left and left > 0) and ("   " .. clock(left)) or "")
						else
							local nextIn = type(st) == "table" and remaining(st.next) or nil
							status.Text = (nextIn and nextIn > 0) and ("NEXT IN " .. clock(nextIn)) or "OFF"
						end
						setSelected(c, on)
					end
					update()
					table.insert(live, update)
					col += 1
					if col == 3 then
						col, y = 0, y + ch + 12
					end
				end
			end
			if col > 0 then
				y += ch + 12
			end

			y += 4
			btn(scroll, "🥚 EGG SHOWER", x0, y, 250, 60, C.orange, function()
				send("EggShower", { amount = ev.shower }, "Egg shower x" .. ev.shower)
			end, { size = 22 })
			chipRow(scroll, x0 + 262, y + 7, 300, { { 5, "5" }, { 8, "8" }, { 12, "12" }, { 15, "15" } }, ev.shower, function(v)
				ev.shower = v
				render(true)
			end, 62)
			btn(scroll, "⛔ STOP ALL EVENTS", x0 + w - 300, y, 300, 60, C.red, function()
				confirm("STOP EVERY EVENT?", "Ends every running event and boost in this server.", "STOP ALL", function()
					send("StopAllEvents", {}, "Stop all events")
				end)
			end, { size = 22 })
			y += 78

			heading(scroll, "🚀 BOOSTS  (pick what, how strong, then start)", x0, y)
			y += 40
			local boostChips = {}
			for _, b in ipairs(BOOSTS) do
				table.insert(boostChips, { b[1], b[2], b[3], 166 })
			end
			y = chipRow(scroll, x0, y, w, boostChips, ev.targets, function(v)
				ev.targets[v] = (not ev.targets[v]) or nil
				render(true)
			end)
			rowY = y
			y = chipRow(scroll, x0, y, w - 220, {
				{ 2, "x2" }, { 3, "x3" }, { 5, "x5" }, { 10, "x10" }, { 25, "x25" }, { 50, "x50" },
			}, ev.multCustom == "" and ev.mult or nil, function(v)
				ev.mult, ev.multCustom = v, ""
				render(true)
			end, 90)
			input(scroll, x0 + w - 206, rowY, 206, 46, "or custom x...", ev.multCustom, function(text)
				ev.multCustom = text
				local m = tonumber(text)
				if m and m >= 1.1 then
					ev.mult = m
				end
			end)
			btn(scroll, "▶ START BOOST", x0, y, 300, 60, C.green, function()
				local list = {}
				for _, b in ipairs(BOOSTS) do
					if ev.targets[b[1]] then
						table.insert(list, b[1])
					end
				end
				if #list == 0 then
					toast(false, "Pick at least one boost")
					return
				end
				send("StartBoost", { targets = list, multiplier = ev.mult, seconds = math.clamp(ev.seconds, 15, 14400) }, "Boost x" .. ev.mult .. " " .. table.concat(list, ", "))
			end, { size = 22 })
			btn(scroll, "■ STOP BOOSTS", x0 + 312, y, 260, 60, C.red, function()
				send("StopBoost", {}, "Stop boosts")
			end, { size = 22 })
			local boostLine = label(scroll, "", x0 + 584, y, w - 584, 60, 17, "left")
			local function updateBoosts()
				local parts = {}
				local boosts = snapshot.liveEvents.boosts
				if type(boosts) == "table" then
					for name, b in pairs(boosts) do
						local left = type(b) == "table" and remaining(b.ends) or nil
						if type(b) == "table" and (not left or left > 0) then
							table.insert(parts, tostring(name) .. " x" .. tostring(b.x) .. (left and (" " .. clock(left)) or ""))
						end
					end
				end
				table.sort(parts)
				boostLine.Text = #parts > 0 and ("🟢 " .. table.concat(parts, "  ·  ")) or "No boost running"
			end
			updateBoosts()
			table.insert(live, updateBoosts)
			return y + 70
		end,
	})

	------------------------------------------------------------------ page: economy (owner only: the server refuses admins)
	local eco = { amount = 10000, custom = "", who = "" }
	if isOwner then
		addPage("economy", "💰 MONEY", C.green, {
			draw = function()
				local x0, y, w = 8, 6, CW - 8
				local function amount()
					if eco.custom ~= "" then
						return parseAmount(eco.custom)
					end
					return eco.amount
				end
				local who = card(scroll, x0, y, w, 76, C.purple)
				label(who, "🎯 PLAYER:  " .. targetName(), 16, 0, w - 250, 76, 26, "left")
				btn(who, "CHANGE", w - 216, 12, 200, 52, C.gold, pickTarget, { size = 22, lip = 4 })
				y += 94

				heading(scroll, "💵 HOW MUCH", x0, y)
				y += 40
				local amountLabel
				local function showAmount()
					local n = amount()
					amountLabel.Text = n and ("$" .. commas(n)) or "???"
				end
				y = chipRow(scroll, x0, y, w, {
					{ 1e3, "1K" }, { 1e4, "10K" }, { 1e5, "100K" }, { 1e6, "1M" }, { 1e7, "10M" }, { 1e8, "100M" }, { 1e9, "1B" },
				}, eco.custom == "" and eco.amount or nil, function(v)
					eco.amount, eco.custom = v, ""
					render(true)
				end, 114, 56)
				input(scroll, x0, y, 420, 56, "or type it: 2500, 50k, 2.5m ...", eco.custom, function(text)
					eco.custom = text
					showAmount()
				end)
				local amountCard = card(scroll, x0 + 432, y, w - 432, 56, C.gold)
				amountLabel = label(amountCard, "", 10, 0, w - 452, 56, 28, "center")
				showAmount()
				y += 78

				local bw = math.floor((w - 36) / 4)
				btn(scroll, "➕ GIVE", x0, y, bw, 92, C.green, function()
					local n = amount()
					if not n or n <= 0 then
						toast(false, "Enter an amount first")
						return
					end
					local args = withTarget({ amount = n })
					if target.kind == "lobby" then
						confirm("GIVE TO EVERYONE?", "$" .. commas(n) .. " for every player in this server.", "GIVE", function()
							args.confirmed = true
							send("GiveCash", args, "Give $" .. commas(n) .. " to everyone")
						end)
					else
						send("GiveCash", args, "Give $" .. commas(n) .. " to " .. targetName())
					end
				end, { size = 28, lip = 6 })
				local function takeFrom()
					if eco.who ~= "" then
						return eco.who, eco.who
					end
					if not needOne() then
						return nil
					end
					return tostring(targetUserId()), targetName()
				end
				btn(scroll, "➖ TAKE", x0 + (bw + 12), y, bw, 92, C.orange, function()
					local n = amount()
					if not n or n <= 0 then
						toast(false, "Enter an amount first")
						return
					end
					local id, name = takeFrom()
					if not id then
						return
					end
					confirm("TAKE $" .. commas(n) .. "?", "Taken from " .. name .. ". Their cash never goes below $0.", "TAKE", function()
						send("TakeCash", { who = id, amount = n, confirmed = true }, "Take $" .. commas(n) .. " from " .. name)
					end)
				end, { size = 28, lip = 6 })
				btn(scroll, "🟰 SET TO", x0 + (bw + 12) * 2, y, bw, 92, C.blue, function()
					local n = amount()
					if not n then
						toast(false, "Enter an amount first")
						return
					end
					if not needOne() then
						return
					end
					confirm("SET CASH TO $" .. commas(n) .. "?", targetName() .. " will have exactly this much cash.", "SET", function()
						send("SetCash", withTarget({ amount = n, confirmed = true }), "Set " .. targetName() .. " to $" .. commas(n))
					end)
				end, { size = 28, lip = 6 })
				btn(scroll, "🧹 TAKE ALL", x0 + (bw + 12) * 3, y, bw, 92, C.red, function()
					local id, name = takeFrom()
					if not id then
						return
					end
					confirm("TAKE ALL MONEY?", name .. " goes to $0, including money waiting on their stands.", "TAKE ALL", function()
						send("TakeCash", { who = id, amount = "all", confirmed = true }, "Take all from " .. name)
					end)
				end, { size = 26, lip = 6 })
				y += 114

				heading(scroll, "📴 OFFLINE PLAYER  (TAKE and TAKE ALL only)", x0, y)
				y += 40
				input(scroll, x0, y, 520, 54, "username or user id, empty = the player above", eco.who, function(text)
					eco.who = (text:gsub("^%s+", ""):gsub("%s+$", ""))
				end)
				return y + 70
			end,
		})
	end

	------------------------------------------------------------------ page: spawn
	local sp = { kind = "Egg", mutation = "None", where = "Hand", amount = 1, pick = nil }
	addPage("spawn", "🥚 SPAWN", C.purple, {
		draw = function()
			local x0, y, w = 8, 6, CW - 8
			scroll.Size = UDim2.fromOffset(RW, RH - 96)
			local items, byId = {}, {}
			for _, item in ipairs(snapshot.catalog) do
				local kind = item.kind or (item.charAvailable and not item.eggAvailable and "Character" or "Egg")
				if item.id == "Golden Pirate" or kind == sp.kind then
					byId[item.id] = item
					if matches(search, item.name, item.id, item.rarity, item.egg) then
						table.insert(items, item)
					end
				end
			end
			if sp.pick and not byId[sp.pick] then
				sp.pick = nil
			end
			local function canRiver(item)
				return sp.kind == "Egg" and item ~= nil and item.eggAvailable and not item.noRiver
			end
			local function describe()
				local item = sp.pick and byId[sp.pick]
				if not item then
					return nil
				end
				return (sp.amount > 1 and (sp.amount .. "x ") or "") .. (sp.mutation ~= "None" and (sp.mutation .. " ") or "") .. tostring(item.name), item
			end

			chipRow(scroll, x0, y, 300, { { "Egg", "🥚 EGGS", C.purple }, { "Character", "🧍 CHARACTERS", C.gold } }, sp.kind, function(v)
				sp.kind, sp.pick = v, nil
				if v == "Character" then
					sp.where = "Hand"
				end
				render(false)
			end, 140)
			local whereChips = { { "Hand", "✋ IN HAND", C.green } }
			if sp.kind == "Egg" then
				table.insert(whereChips, { "River", "🌊 RIVER", C.blue })
			end
			chipRow(scroll, x0 + 316, y, 280, whereChips, sp.where, function(v)
				sp.where = v
				render(true)
			end, 130)
			y = chipRow(scroll, x0 + 612, y, 270, { { 1, "x1" }, { 3, "x3" }, { 5, "x5" }, { 10, "x10" } }, sp.amount, function(v)
				sp.amount = v
				render(true)
			end, 56)
			y = chipRow(scroll, x0, y, w, MUTATIONS, sp.mutation, function(v)
				sp.mutation = v
				render(true)
			end, 136)

			-- the bar that stays put: what will happen + the big button
			local barY = RY + RH - 84
			local summaryCard = card(fixed, RX + 8, barY, RW - 300, 76, C.azure)
			local summary = label(summaryCard, "", 14, 0, RW - 328, 76, 22, "left")
			local function updateSummary()
				local text = describe()
				if not text then
					summary.Text = "👆 Click an egg or character"
				elseif sp.where == "River" then
					summary.Text = text .. "  →  the river"
				else
					summary.Text = text .. "  →  " .. targetName()
				end
			end
			updateSummary()
			btn(fixed, "✨ SPAWN", RX + RW - 278, barY, 262, 76, C.green, function()
				local text, item = describe()
				if not item then
					toast(false, "Pick an egg or character first")
					return
				end
				local mutation = sp.mutation ~= "None" and sp.mutation or nil
				if sp.where == "River" then
					if not canRiver(item) then
						toast(false, "That one can't go in the river")
						return
					end
					send("SpawnEgg", { itemId = item.id, mutation = mutation, amount = sp.amount }, "River " .. text)
					return
				end
				local available
				if sp.kind == "Egg" then
					available = item.eggAvailable
				else
					available = item.charAvailable
				end
				if not available then
					toast(false, "That one can't be given as " .. (sp.kind == "Egg" and "an egg" or "a character"))
					return
				end
				local action = sp.kind == "Egg" and "GiveEgg" or "GiveCharacter"
				local args = withTarget({ itemId = item.id, mutation = mutation, amount = sp.amount })
				if target.kind == "lobby" then
					confirm("GIVE TO EVERYONE?", text .. " for every player in this server.", "GIVE", function()
						args.confirmed = true
						send(action, args, "Give " .. text .. " to everyone")
					end)
				else
					send(action, args, "Give " .. text .. " to " .. targetName())
				end
			end, { size = 30, lip = 6 })

			-- the catalog by rarity
			local cells = {}
			local groups, order = {}, {}
			for _, rarity in ipairs(RARITY_ORDER) do
				groups[rarity] = {}
				table.insert(order, rarity)
			end
			for _, item in ipairs(items) do
				local rarity = item.rarity or "Common"
				if not groups[rarity] then
					groups[rarity] = {}
					table.insert(order, rarity)
				end
				table.insert(groups[rarity], item)
			end
			local cw, ch = math.floor((w - 36) / 4), 70
			for _, rarity in ipairs(order) do
				local list = groups[rarity]
				if #list > 0 then
					table.sort(list, function(a, b)
						if (a.order or 0) ~= (b.order or 0) then
							return (a.order or 0) < (b.order or 0)
						end
						return tostring(a.name) < tostring(b.name)
					end)
					local head = heading(scroll, tostring(rarity):upper() .. "  (" .. #list .. ")", x0, y)
					if okRarity and type(RarityText) == "table" and RarityText.Themes and RarityText.Themes[rarity] then
						pcall(RarityText.Apply, head, rarity)
					end
					y += 40
					local pal = RARITY_PAL[rarity] or C.sky
					for i, item in ipairs(list) do
						local cx = x0 + ((i - 1) % 4) * (cw + 12)
						local cy = y + ((i - 1) // 4) * (ch + 12)
						local name = tostring(item.name)
						local sub = sp.kind == "Egg" and (item.characters and table.concat(item.characters, " · ") or "") or ""
						if sp.kind == "Character" and type(item.id) == "string" and item.id ~= "Golden Pirate" then
							sub = name
							name = (item.id:gsub("(%l)(%u)", "%1 %2"))
						end
						local b = btn(scroll, "", cx, cy, cw, ch, pal, function()
							sp.pick = item.id
							if sp.where == "River" and not canRiver(item) then
								sp.where = "Hand"
								render(true)
								return
							end
							for id, other in pairs(cells) do
								setSelected(other, id == sp.pick)
							end
							updateSummary()
						end, { light = true, lip = 4 })
						label(b, name, 8, sub ~= "" and 4 or 0, cw - 16, sub ~= "" and 36 or ch - 4, 19, "center", 8)
						if sub ~= "" then
							label(b, sub, 8, 38, cw - 16, 22, 14, "center", 8)
						end
						setSelected(b, sp.pick == item.id)
						cells[item.id] = b
					end
					y += math.ceil(#list / 4) * (ch + 12) + 6
				end
			end
			if #items == 0 then
				label(scroll, search ~= "" and "Nothing matches the search" or "No items loaded yet - press REFRESH", x0, y, w, 60, 22, "center")
				y += 70
			end
			return y
		end,
	})

	------------------------------------------------------------------ page: players
	addPage("players", "👥 PLAYERS", C.blue, {
		live = true,
		draw = function()
			local listW = 430
			scroll.Size = UDim2.fromOffset(listW, RH)
			local y = 6
			for _, p in ipairs(snapshot.players) do
				if matches(search, p.name, p.user, tostring(p.userId), p.role) then
					local selected = (target.kind == "player" and target.userId == p.userId) or (target.kind == "me" and p.userId == context.userId)
					local b = btn(scroll, "", 8, y, listW - 34, 68, p.role == "Owner" and C.gold or (p.role == "Admin" and C.pink or C.blue), function()
						if p.userId == context.userId then
							target = { kind = "me", userId = context.userId }
						else
							target = { kind = "player", userId = p.userId }
						end
						render(true)
					end, { light = true, lip = 4 })
					avatar(b, p.userId, 8, 7, 50, 8)
					local tag = p.role == "Owner" and "👑 " or (p.role == "Admin" and "🛡️ " or "")
					label(b, tag .. tostring(p.name), 68, 4, listW - 34 - 78, 30, 20, "left", 8)
					local plot = type(p.plot) == "table" and p.plot or nil
					local info = "@" .. tostring(p.user)
					if plot then
						info ..= "  ·  Lv " .. tostring(plot.level or "?") .. "  ·  " .. tostring(plot.slots or "?") .. " slots"
					end
					label(b, info, 68, 34, listW - 34 - 78, 24, 15, "left", 8)
					setSelected(b, selected)
					y += 80
				end
			end
			if y == 6 then
				label(scroll, "Nobody matches", 8, 8, listW - 34, 50, 20, "center")
				y = 70
			end

			-- actions for the selected player (fixed, on the right)
			local px, py, pw = RX + listW + 12, RY, RW - listW - 12
			local who = card(fixed, px, py + 4, pw - 6, 60, C.purple)
			label(who, "🎯 " .. targetName(), 14, 0, pw - 34, 60, 24, "left")
			py += 74
			local bw, bh = math.floor((pw - 6 - 20) / 3), 46
			local slot = 0
			local function place(text, pal, onClick)
				local bx = px + (slot % 3) * (bw + 10)
				local by = py + (slot // 3) * (bh + 8)
				slot += 1
				return btn(fixed, text, bx, by, bw, bh, pal, onClick, { size = 15, lip = 4, r = 12 })
			end
			local function endRows()
				py += math.ceil(slot / 3) * (bh + 8)
				slot = 0
			end
			-- one-player action through the dispatcher; body = needs the confirm dialog (server wants confirmed = true)
			local function run(action, what, args, body)
				if not needOne() then
					return
				end
				local name = targetName()
				args = withTarget(args or {})
				if body then
					confirm(what:upper() .. "?", name .. ": " .. body, "YES", function()
						args.confirmed = true
						send(action, args, what .. " " .. name)
					end)
				else
					send(action, args, what .. " " .. name)
				end
			end
			place("🚀 GO TO", C.blue, function()
				run("GoTo", "Go to")
			end)
			place("🧲 BRING", C.blue, function()
				run("Bring", "Bring")
			end)
			place("🏠 SEND HOME", C.sky, function()
				run("SendHome", "Send home")
			end)
			place("💫 RESPAWN", C.orange, function()
				run("Respawn", "Respawn", nil, "they respawn right now.")
			end)
			place("👢 KICK", C.red, function()
				run("Kick", "Kick", nil, "removed from this server.")
			end)
			if isOwner then
				place("🔨 BAN 24H", C.red, function()
					run("Ban", "Ban", nil, "banned for 24 hours.")
				end)
				local function flag(action, on, what)
					if not needOne() then
						return
					end
					local p = findPlayer(targetUserId())
					send(action, { userId = targetUserId(), on = on, name = p and p.user or nil }, what .. " " .. targetName(), function()
						if gui.Enabled and page == "players" then
							render(true)
						end
					end)
				end
				place("🎥 FREECAM ON", C.purple, function()
					flag("SetFreecam", true, "Freecam on")
				end)
				place("🎥 FREECAM OFF", C.purple, function()
					flag("SetFreecam", false, "Freecam off")
				end)
				place("🛡️ MAKE ADMIN", C.pink, function()
					local name = targetName()
					if needOne() then
						confirm("MAKE ADMIN?", name .. " gets the admin panel.", "MAKE ADMIN", function()
							flag("SetAdmin", true, "Make admin")
						end)
					end
				end)
				place("🚫 REMOVE ADMIN", C.pink, function()
					flag("SetAdmin", false, "Remove admin")
				end)
				endRows()
				H.text(fixed, "Heading", "🏝️ PLOT", px + 2, py + 14, 22, 6, WHITE, "left")
				py += 32
				place("⛩️ TEMPLE UP", C.green, function()
					run("UpgradeTemple", "Upgrade temple")
				end)
				place("🔓 UNLOCK SLOT", C.green, function()
					run("UnlockSlot", "Unlock slot")
				end)
				place("🐣 ADD INCUBATOR", C.green, function()
					run("AddIncubator", "Add incubator")
				end)
				for index = 1, 3 do
					place("⬆ INCUBATOR " .. index, C.leaf, function()
						run("UpgradeIncubator", "Upgrade incubator " .. index, { index = index })
					end)
				end
				place("🎒 CLEAR INVENTORY", C.orange, function()
					run("ClearInventory", "Clear inventory", nil, "everything in their inventory is deleted.")
				end)
				place("🧹 CLEAR PLACED", C.orange, function()
					run("ClearPlaced", "Clear placed", nil, "everything placed on their plot is deleted.")
				end)
				place("♻️ RESET SLOTS", C.orange, function()
					run("ResetSlots", "Reset slots", nil, "their plot slots go back to the start.")
				end)
				place("💀 WIPE PLAYER", C.red, function()
					if not needOne() then
						return
					end
					local id, name = tostring(targetUserId()), targetName()
					confirm("WIPE " .. name:upper() .. "?", "Their whole save is reset. This cannot be undone here.", "WIPE", function()
						send("WipePlayer", { who = id, confirmed = true }, "Wipe " .. name)
					end)
				end)
			end
			endRows()
			return y
		end,
	})

	------------------------------------------------------------------ classic panel (the old StudPanel, kept as a fallback)
	local classicGui, classicApi
	local function openClassic()
		if not classicApi then
			local ok, err = pcall(function()
				local StudPanel = require(script.Parent:WaitForChild("StudPanel"))
				classicGui = Instance.new("ScreenGui")
				classicGui.Name = "OwnerPanelClassic"
				classicGui.ResetOnSpawn = false
				classicGui.Enabled = false
				classicGui.IgnoreGuiInset = true
				classicGui.DisplayOrder = 50
				classicGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
				classicGui.Parent = gui.Parent
				classicApi = StudPanel.Build(classicGui, context)
			end)
			if not ok or not classicApi then
				warn("[AdminPanelV2] classic panel:", err)
				if classicGui then
					classicGui:Destroy()
				end
				classicGui, classicApi = nil, nil
				toast(false, "The classic panel could not load")
				return
			end
		end
		api.close()
		task.delay(0.3, function() -- past the server's request gap
			if classicApi then
				classicApi.open()
			end
		end)
	end
	gui.Destroying:Connect(function()
		if classicGui then
			classicGui:Destroy()
		end
	end)

	------------------------------------------------------------------ page: server
	local sv = { announce = "", interval = "", abuse = "", unban = "", adminId = "" }
	addPage("server", "🖥️ SERVER", C.pink, {
		draw = function()
			local x0, y, w = 8, 6, CW - 8
			local function redraw()
				if gui.Enabled and page == "server" then
					render(true)
				end
			end
			heading(scroll, "📢 ANNOUNCEMENT", x0, y)
			y += 40
			input(scroll, x0, y, w, 54, "Write the message (max 120 letters)...", sv.announce, function(text)
				sv.announce = text:sub(1, 120)
			end)
			y += 68
			local function announceText()
				if sv.announce:gsub("%s", "") == "" then
					toast(false, "Write a message first")
					return nil
				end
				return sv.announce
			end
			btn(scroll, "📣 THIS SERVER", x0, y, 280, 60, C.pink, function()
				local text = announceText()
				if text then
					send("Announce", { text = text, color = "pink", allServers = false }, "Announce")
				end
			end, { size = 22 })
			btn(scroll, "🌍 ALL SERVERS", x0 + 292, y, 280, 60, C.purple, function()
				local text = announceText()
				if text then
					confirm("SEND TO ALL SERVERS?", "\"" .. text .. "\" is shown to every player in every server.", "SEND", function()
						send("Announce", { text = text, color = "purple", allServers = true }, "Announce (all servers)")
					end)
				end
			end, { size = 22 })
			btn(scroll, "🆕 UPDATE & REJOIN", x0 + 584, y, w - 584, 60, C.orange, function()
				confirm("ANNOUNCE AN UPDATE?", "Tells every server that a new update is out, so players rejoin.", "ANNOUNCE", function()
					send("AnnounceUpdate", {}, "Update announcement")
				end)
			end, { size = 20 })
			y += 82

			heading(scroll, "🥚 RIVER EGG SPEED  (seconds between eggs, 1.5 to 30)", x0, y)
			y += 40
			input(scroll, x0, y, 280, 54, "seconds, like 4", sv.interval, function(text)
				sv.interval = text
			end)
			btn(scroll, "SET SPEED", x0 + 292, y - 3, 220, 60, C.green, function()
				local seconds = tonumber(sv.interval)
				if not seconds then
					toast(false, "Type a number of seconds first")
					return
				end
				send("SetSpawnInterval", { seconds = seconds }, "River egg every " .. seconds .. " s")
			end, { size = 22 })
			y += 78

			heading(scroll, "🛡️ STAFF SERVER" .. (snapshot.isStaffServer and "  (you are in it)" or ""), x0, y)
			y += 40
			btn(scroll, "➡️ JOIN STAFF SERVER", x0, y, 330, 60, C.blue, function()
				confirm("JOIN THE STAFF SERVER?", "You are teleported to the private staff server.", "JOIN", function()
					send("JoinStaffServer", {}, "Join staff server")
				end)
			end, { size = 20 })
			btn(scroll, "⬅️ BACK TO PUBLIC", x0 + 342, y, 330, 60, C.sky, function()
				confirm("BACK TO A PUBLIC SERVER?", "You are teleported to a normal public server.", "GO", function()
					send("ReturnToPublic", {}, "Return to public")
				end)
			end, { size = 20 })
			y += 82

			heading(scroll, "😈 ADMIN ABUSE  (server-wide multipliers: kind, x, minutes)", x0, y)
			y += 40
			y = chipRow(scroll, x0, y, w, {
				{ "cash 2 10", "💰 CASH x2 10M", C.green, 180 }, { "hatch 2 10", "🐣 HATCH x2 10M", C.orange, 180 },
				{ "legendary 5 10", "⭐ LEGENDARY x5 10M", C.gold, 220 }, { "list", "📋 LIST", C.blue, 110 }, { "stop", "■ STOP", C.red, 110 },
			}, nil, function(v)
				send("AdminAbuse", { text = v }, "Admin abuse: " .. v)
			end)
			input(scroll, x0, y, 420, 54, "or type: cash 3 30", sv.abuse, function(text)
				sv.abuse = text
			end)
			btn(scroll, "RUN", x0 + 432, y - 3, 160, 60, C.green, function()
				if sv.abuse:gsub("%s", "") == "" then
					toast(false, "Type a command first")
					return
				end
				send("AdminAbuse", { text = sv.abuse }, "Admin abuse: " .. sv.abuse)
			end, { size = 22 })
			y += 78

			if isOwner then
				heading(scroll, "🔓 UNBAN", x0, y)
				y += 40
				input(scroll, x0, y, 280, 54, "user id", sv.unban, function(text)
					sv.unban = text
				end)
				btn(scroll, "UNBAN", x0 + 292, y - 3, 200, 60, C.green, function()
					local id = tonumber(sv.unban)
					if not id then
						toast(false, "Type a numeric user id first")
						return
					end
					confirm("UNBAN " .. sv.unban .. "?", "Removes their active ban.", "UNBAN", function()
						send("Unban", { userId = tostring(id), confirmed = true }, "Unban " .. tostring(id))
					end)
				end, { size = 22 })
				y += 78

				heading(scroll, "👑 ADMINS", x0, y)
				y += 40
				input(scroll, x0, y, 280, 54, "user id", sv.adminId, function(text)
					sv.adminId = text
				end)
				btn(scroll, "➕ ADD ADMIN", x0 + 292, y - 3, 240, 60, C.pink, function()
					local id = tonumber(sv.adminId)
					if not id then
						toast(false, "Type a numeric user id first")
						return
					end
					confirm("MAKE " .. sv.adminId .. " AN ADMIN?", "They get the admin panel in every server.", "MAKE ADMIN", function()
						send("SetAdmin", { userId = id, on = true }, "Make admin " .. tostring(id), redraw)
					end)
				end, { size = 22 })
				y += 74
				if type(snapshot.admins) == "table" then
					for _, admin in ipairs(snapshot.admins) do
						local row = card(scroll, x0, y, w, 56, admin.fixed and C.gold or C.lilac)
						label(row, (admin.fixed and "👑 " or "🛡️ ") .. tostring(admin.name) .. "   (" .. tostring(admin.userId) .. ")", 16, 0, w - 220, 56, 20, "left")
						if not admin.fixed then
							btn(row, "REMOVE", w - 176, 6, 164, 44, C.red, function()
								confirm("REMOVE ADMIN?", tostring(admin.name) .. " loses the admin panel.", "REMOVE", function()
									send("SetAdmin", { userId = admin.userId, on = false, name = admin.name }, "Remove admin " .. tostring(admin.name), redraw)
								end)
							end, { size = 18, lip = 4 })
						end
						y += 68
					end
				end
				y += 10
			end

			heading(scroll, "🕰️ OLD PANEL  (still has: restore saves, send to player)", x0, y)
			y += 40
			btn(scroll, "OPEN CLASSIC PANEL", x0, y, 330, 60, C.sky, openClassic, { size = 20 })
			return y + 70
		end,
	})

	------------------------------------------------------------------ page: log
	addPage("log", "📜 LOG", C.sky, {
		draw = function()
			local x0, y, w = 8, 6, CW - 8
			heading(scroll, "📜 WHAT YOU DID THIS SESSION  (" .. #log .. ")", x0, y)
			btn(scroll, "CLEAR", x0 + w - 150, y, 150, 42, C.red, function()
				table.clear(log)
				render(false)
			end, { size = 18, lip = 4 })
			y += 54
			for _, row in ipairs(log) do
				if matches(search, row.what, row.msg) then
					local c = card(scroll, x0, y, w, 62, row.ok and C.leaf or C.coral)
					label(c, row.time, 12, 0, 96, 62, 16, "left")
					label(c, (row.ok and "✓ " or "✕ ") .. tostring(row.what), 112, 2, w - 124, 30, 19, "left")
					label(c, tostring(row.msg), 112, 32, w - 124, 26, 15, "left")
					y += 72
				end
			end
			if #log == 0 then
				label(scroll, "Nothing yet. Every action you run shows up here.", x0, y, w, 60, 20, "center")
				y += 70
			end
			return y
		end,
	})

	------------------------------------------------------------------ ticking, open / close
	task.spawn(function()
		local n = 0
		while gui.Parent do
			task.wait(0.5)
			if gui.Enabled then
				n += 1
				for _, update in ipairs(live) do
					pcall(update)
				end
				-- events can start and end on their own: re-read the state now and then (no redraw, the labels read it)
				if n % 16 == 0 and page == "events" and not busy then
					busy = true
					pcall(fetchSnapshot)
					busy = false
				end
			end
		end
	end)

	local OLD_PAGE_IDS = { home = "events", eggs = "spawn", money = "economy", announce = "server", punish = "economy", restore = "server" }
	function api.open()
		gui.Enabled = true
		refit()
		render(false)
		pop.Scale = 0.9
		TweenService:Create(pop, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 }):Play()
		refresh(true)
	end
	function api.close()
		closeOverlay()
		gui.Enabled = false
	end
	function api.toggle()
		if gui.Enabled then
			api.close()
		else
			api.open()
		end
	end
	function api.refresh()
		if gui.Enabled then
			refresh(false)
		end
	end
	function api.show(pageId)
		pageId = pages[pageId] and pageId or OLD_PAGE_IDS[pageId]
		if not pageId or not pages[pageId] then
			return
		end
		page = pageId
		closeOverlay()
		if searchBox.Text ~= "" then
			searchBox.Text = "" -- its change handler redraws
		else
			render(false)
		end
	end

	Folk.animate(gui)
	refit()
	return api
end

return AdminPanelV2
