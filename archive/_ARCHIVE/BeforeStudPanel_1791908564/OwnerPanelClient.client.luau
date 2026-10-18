--[[ StarterPlayerScripts.OwnerPanelClient  (LocalScript)
v3 "cartoon Japanese" owner panel. Opens with /owner (chat) or F8. Only shown to owner IDs.
Purely visual: every button asks OwnerPanelServer, which re-checks the owner ID.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local player = Players.LocalPlayer
if player.UserId ~= 168774222 then return end -- cosmetic only; the server is the real gate
local Remote = ReplicatedStorage:WaitForChild("OwnerPanel"):WaitForChild("Action")

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end
local C = {
	Ink = rgb(29, 20, 32), Cream = rgb(255, 243, 220), Side = rgb(255, 232, 191), Card = rgb(255, 255, 255), Soft = rgb(255, 248, 234),
	Red = rgb(232, 69, 44), Tint = rgb(255, 217, 207), Gold = rgb(255, 211, 107), GoldH = rgb(255, 201, 74), Danger = rgb(229, 72, 77),
	Text = rgb(29, 20, 32), Muted = rgb(107, 85, 96), Cap = rgb(134, 112, 124), OwnerGold = rgb(201, 138, 18),
	OkT = rgb(47, 122, 58), OkB = rgb(216, 242, 207), ErrT = rgb(192, 48, 58), ErrB = rgb(255, 220, 220), Indigo = rgb(38, 48, 94),
}
local RC = { Common = rgb(111, 119, 132), Uncommon = rgb(47, 154, 58), Rare = rgb(45, 111, 214), Epic = rgb(138, 63, 208), Legendary = rgb(176, 122, 0) }
local F = Font.new("rbxasset://fonts/families/FredokaOne.json")
local FB = Font.new("rbxasset://fonts/families/BuilderSans.json", Enum.FontWeight.Bold)

local function make(c, p, parent) local o = Instance.new(c); for k, v in p do o[k] = v end; if parent then o.Parent = parent end; return o end
local function corner(o, r) make("UICorner", { CornerRadius = r and UDim.new(0, r) or UDim.new(1, 0) }, o) end
local function stroke(o, t) make("UIStroke", { Color = C.Ink, Thickness = t or 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end
local function pad(o, a) make("UIPadding", { PaddingTop = UDim.new(0, a), PaddingBottom = UDim.new(0, a), PaddingLeft = UDim.new(0, a), PaddingRight = UDim.new(0, a) }, o) end
local function list(o, gap, dir) return make("UIListLayout", { Padding = UDim.new(0, gap), FillDirection = dir or Enum.FillDirection.Vertical, SortOrder = Enum.SortOrder.LayoutOrder }, o) end
local function text(parent, s, size, color, font, props)
	local l = make("TextLabel", { BackgroundTransparency = 1, Text = s, TextSize = size or 14, TextColor3 = color or C.Text, FontFace = font or FB,
		TextXAlignment = Enum.TextXAlignment.Left, AutomaticSize = Enum.AutomaticSize.XY, TextWrapped = false }, parent)
	if props then for k, v in props do l[k] = v end end
	return l
end
local order = 0
local function nextOrder() order += 1; return order end

-- 3D cartoon button: ink base + coloured face that presses down 3 px
local function button3d(parent, label, color, onClick, w, h)
	h = h or 44
	local holder = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(w and 0 or 1, w or 0, 0, h + 5), LayoutOrder = nextOrder() }, parent)
	local base = make("Frame", { BackgroundColor3 = C.Ink, Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 0, h) }, holder); corner(base, 10)
	local face = make("TextButton", { BackgroundColor3 = color, Size = UDim2.new(1, 0, 0, h), Text = label, FontFace = F, TextSize = 15, AutoButtonColor = false,
		TextColor3 = (color == C.Red or color == C.Danger) and Color3.new(1, 1, 1) or C.Ink }, holder)
	corner(face, 10); stroke(face)
	make("Frame", { BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.5, BorderSizePixel = 0, Position = UDim2.fromOffset(6, 3), Size = UDim2.new(1, -12, 0, 3) }, face)
	local enabled = true
 local api = {}
	face.MouseButton1Down:Connect(function() if enabled then TweenService:Create(face, TweenInfo.new(0.08), { Position = UDim2.fromOffset(0, 3) }):Play() end end)
	face.MouseButton1Up:Connect(function() TweenService:Create(face, TweenInfo.new(0.1), { Position = UDim2.fromOffset(0, 0) }):Play() end)
	face.MouseLeave:Connect(function() face.Position = UDim2.fromOffset(0, 0) end)
	face.Activated:Connect(function() if enabled then onClick(api) end end)
	function api.set(on, newLabel) enabled = on; face.TextTransparency = on and 0 or 0.55; face.BackgroundTransparency = on and 0 or 0.35; if newLabel then face.Text = newLabel end end
	api.face = face
	return api
end
local function card(parent, title)
	local c = make("Frame", { BackgroundColor3 = C.Card, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder() }, parent)
	corner(c, 14); stroke(c); pad(c, 16); list(c, 10)
	if title then text(c, title, 16, C.Text, F, { LayoutOrder = 0 }) end
	return c
end
local function chipRow(parent) local r = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder() }, parent)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Wraps = true, Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, r); return r end
local function chip(parent, label, on, onClick)
	local b = make("TextButton", { BackgroundColor3 = on and C.Red or C.Soft, Text = label, FontFace = F, TextSize = 14, TextColor3 = on and Color3.new(1, 1, 1) or C.Ink,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), AutoButtonColor = false, LayoutOrder = nextOrder() }, parent)
	corner(b); stroke(b, 2); make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12) }, b)
	b.Activated:Connect(onClick); return b
end
local function input(parent, placeholder, numeric)
	local box = make("TextBox", { BackgroundColor3 = C.Side, PlaceholderText = placeholder, Text = "", FontFace = F, TextSize = 18, TextColor3 = C.Ink,
		PlaceholderColor3 = C.Cap, ClearTextOnFocus = false, Size = UDim2.new(1, 0, 0, 46), TextXAlignment = Enum.TextXAlignment.Left, LayoutOrder = nextOrder() }, parent)
	corner(box, 10); stroke(box); make("UIPadding", { PaddingLeft = UDim.new(0, 14) }, box)
	if numeric then box:GetPropertyChangedSignal("Text"):Connect(function() local t = box.Text:gsub("[^%d]", ""); if t ~= box.Text then box.Text = t end end) end
	return box
end
local function fmt(n)
 return require(game:GetService("ReplicatedStorage").CharacterInventory.InventoryFormat).Money(n)
end

---------------------------------------------------------------- shell
local previous = player:WaitForChild("PlayerGui"):FindFirstChild("OwnerPanel"); if previous then previous:Destroy() end
local gui = make("ScreenGui", { Name = "OwnerPanel", ResetOnSpawn = false, Enabled = false, IgnoreGuiInset = true, DisplayOrder = 50, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
make("Frame", { BackgroundColor3 = C.Indigo, BackgroundTransparency = 0.25, Size = UDim2.fromScale(1, 1) }, gui)
local panel = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(1240, 780), BackgroundColor3 = C.Cream }, gui)
corner(panel, 18); stroke(panel, 4)
local fit = make("UIScale", {}, panel)
local function refit() local v = workspace.CurrentCamera.ViewportSize; fit.Scale = math.clamp(math.min((v.X - 24) / 1240, (v.Y - 24) / 780), 0.2, 1) end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refit); refit()

local side = make("Frame", { BackgroundColor3 = C.Side, Size = UDim2.new(0, 224, 1, 0) }, panel); corner(side, 18); pad(side, 14); list(side, 6)
make("Frame", { BackgroundColor3 = C.Ink, BorderSizePixel = 0, Position = UDim2.new(0, 224, 0, 0), Size = UDim2.new(0, 3, 1, 0) }, panel)
text(side, "Command Center", 18, C.Ink, F, { LayoutOrder = 0 }); text(side, "Hatch An Anime Egg", 12, C.Muted, FB, { LayoutOrder = 1 })
local main = make("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(227, 0), Size = UDim2.new(1, -227, 1, 0) }, panel)
local header = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 72) }, main); pad(header, 16)
make("Frame", { BackgroundColor3 = C.Ink, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, 72), Size = UDim2.new(1, 0, 0, 3) }, main)
local title = text(header, "Overview", 26, C.Red, F)
local subtitle = text(header, "", 12, C.Muted, FB, { Position = UDim2.fromOffset(0, 30) })
local content = make("ScrollingFrame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 75), Size = UDim2.new(1, 0, 1, -75), CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6, ScrollBarImageColor3 = C.Ink, BorderSizePixel = 0 }, main)
pad(content, 20); list(content, 14)

-- scope + recipient (top right)
local scope, selectedId = "me", player.UserId
local right = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(560, 40) }, header)
make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 8), VerticalAlignment = Enum.VerticalAlignment.Center }, right)
local scopeBtns = {}
local recipient = text(right, "No player selected", 14, C.Ink, F, { LayoutOrder = 10 })
local closeBtn = make("TextButton", { Text = "X", FontFace = F, TextSize = 18, Size = UDim2.fromOffset(38, 38), BackgroundColor3 = C.Gold, TextColor3 = C.Ink, LayoutOrder = 11, AutoButtonColor = false }, right)
corner(closeBtn, 10); stroke(closeBtn)

---------------------------------------------------------------- data + server calls
local snap = { players = {}, catalog = {} }
local logRows = {}
local toast = make("TextLabel", { AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -18), AutomaticSize = Enum.AutomaticSize.XY, BackgroundColor3 = C.Card,
	Text = "", FontFace = F, TextSize = 15, TextColor3 = C.Ink, Visible = false, ZIndex = 20 }, panel)
corner(toast, 12); stroke(toast); pad(toast, 12)
local function showToast(ok, msg) toast.Text = (ok and "✓ " or "✕ ") .. msg; toast.TextColor3 = ok and C.OkT or C.ErrT; toast.Visible = true
	task.delay(2.6, function() if toast.Text == (ok and "✓ " or "✕ ") .. msg then toast.Visible = false end end) end
local busy = false
local confirmedAction = false
local render -- forward
local function ask(action, args, label, btn)
	if busy then return end
	busy = true
	local old = btn and btn.face.Text; if btn then btn.set(false, "Waiting for server…") end
	args = args or {}; args.confirmed = confirmedAction or args.confirmed; args.scope = args.scope or scope; args.userId = args.userId or selectedId
	local ok, res, msg = pcall(Remote.InvokeServer, Remote, action, args)
	busy = false; if btn then btn.set(true, old) end
	if not ok then res, msg = false, "Server didn't respond" end
	msg = type(msg) == "string" and msg or (res and "Done" or "Failed")
	table.insert(logRows, 1, { time = os.date("%H:%M"), action = label or action, ok = res, msg = msg }); if #logRows > 50 then table.remove(logRows) end
	showToast(res, (label or action) .. " · " .. msg)
	return res, msg
end
local function refresh() task.wait(0.25); local ok, res, data = pcall(Remote.InvokeServer, Remote, "Snapshot", {}); if ok and res and type(data) == "table" then snap = data else showToast(false, ok and tostring(data) or "Server did not respond") end end
local function selected() for _, p in snap.players do if p.userId == selectedId then return p end end end

-- confirm dialog
local function confirm(titleText, body, onYes)
	local dim = make("TextButton", { Text = "", BackgroundColor3 = C.Ink, BackgroundTransparency = 0.45, Size = UDim2.fromScale(1, 1), ZIndex = 30, AutoButtonColor = false }, panel)
	corner(dim, 18)
	local box = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(400, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.Cream, ZIndex = 31 }, dim)
	corner(box, 16); stroke(box, 3); pad(box, 20); list(box, 12)
	for _, o in { text(box, titleText, 18, C.Ink, F), text(box, body, 14, C.Muted, FB, { TextWrapped = true, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y }) } do o.ZIndex = 32 end
	local row = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 50), LayoutOrder = 99, ZIndex = 32 }, box)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Right, Padding = UDim.new(0, 8) }, row)
	local function z(api) for _, d in api.face.Parent:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex = 33 end end api.face.Parent.ZIndex = 33 end
	z(button3d(row, "Cancel", C.Gold, function() dim:Destroy() end, 110))
	z(button3d(row, "Confirm", C.Red, function() dim:Destroy(); confirmedAction = true; local ok, err = pcall(onYes); confirmedAction = false; if not ok then showToast(false, tostring(err)) end end, 120))
end

---------------------------------------------------------------- pages
local pages, page = {}, "overview"
local NAV = { { "overview", "Overview" }, { "players", "Players" }, { "eggs", "Eggs and Characters" }, { "money", "Money" }, { "temple", "Temples and Incubators" }, { "events", "Events" }, { "log", "Activity Log" } }
local SUB = { overview = "Live state of this server", players = "Players in this server only", eggs = "Source: CharacterCatalog", money = "Session-only balances", temple = "Plot of the current recipient", events = "Current server", log = "Confirmed server results" }
local navBtns = {}

pages.overview = function()
	local grid = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder() }, content)
	make("UIGridLayout", { CellSize = UDim2.new(0.25, -9, 0, 104), CellPadding = UDim2.fromOffset(12, 12) }, grid)
	local sel = selected()
	for _, s in { { "Online players", tostring(#snap.players) }, { "Selected player", sel and sel.name or "—" }, { "Temple", sel and sel.plot and ("Level " .. sel.plot.level) or "—" }, { "Incubators", sel and sel.plot and tostring(#(sel.plot.incubators or {})) or "—" } } do
		local c = make("Frame", { BackgroundColor3 = C.Card }, grid); corner(c, 14); stroke(c); pad(c, 16); list(c, 6)
		text(c, s[1], 12, C.Muted, FB); text(c, s[2], 24, C.Ink, F)
	end
	local sc = card(content, "Shortcuts")
	for _, s in { { "Give $1M", "money" }, { "Give an egg", "eggs" }, { "Start an event", "events" }, { "Find a player", "players" } } do
		button3d(sc, s[1], C.Gold, function() page = s[2]; render() end)
	end
end

pages.players = function()
	local c = card(content, ("%d online · current server"):format(#snap.players))
	for _, p in snap.players do
		local on = p.userId == selectedId
		local row = make("TextButton", { Text = "", BackgroundColor3 = on and C.Tint or C.Soft, Size = UDim2.new(1, 0, 0, 56), AutoButtonColor = false, LayoutOrder = nextOrder() }, c)
		corner(row, 12); stroke(row, on and 3 or 2)
		make("ImageLabel", { Image = ("rbxthumb://type=AvatarHeadShot&id=%d&w=48&h=48"):format(p.userId), BackgroundColor3 = C.Side, Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(40, 40) }, row)
		text(row, p.name, 15, C.Ink, F, { Position = UDim2.fromOffset(58, 9) })
		text(row, ("@%s · ID %d"):format(p.user, p.userId), 12, C.Muted, FB, { Position = UDim2.fromOffset(58, 30) })
		if p.userId == 168774222 then text(row, "Owner", 12, C.OwnerGold, F, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0) }) end
		row.Activated:Connect(function() selectedId = p.userId; scope = "selected"; render() end)
	end
	local tp = card(content, "Teleport selected player")
 button3d(tp, "Bring to me", C.Gold, function(b) ask("Bring", {}, "Bring", b) end)
 button3d(tp, "Go to player", C.Gold, function(b) ask("GoTo", {}, "Go to player", b) end)
 local destinations = chipRow(tp)
 for _, destination in snap.players do
  chip(destinations, "Send to @" .. destination.user, false, function() ask("SendToPlayer", { destination = destination.userId }, "Teleport to @" .. destination.user) end)
 end
 local m = card(content, "Moderation")
	local sel = selected()
	local kick = button3d(m, "Kick", C.Gold, function() local s = selected(); if s then confirm("Kick " .. s.name .. "?", "They can rejoin right away.", function() ask("Kick", { userId = s.userId }, "Kick"); refresh(); render() end) end end)
	local ban = button3d(m, "Ban 24 hours", C.Danger, function() local s = selected(); if s then confirm("Ban " .. s.name .. " for 24 hours?", "Uses Roblox bans. Only works in published servers.", function() ask("Ban", { userId = s.userId }, "Ban 24h") end) end end)
	local can = sel and sel.userId ~= 168774222
	kick.set(can); ban.set(can)
	local box = input(m, "User ID to unban", true)
	button3d(m, "Unban", C.Gold, function() if box.Text ~= "" then confirm("Unban " .. box.Text .. "?", "Removes their active ban.", function() ask("Unban", { userId = box.Text }, "Unban") end) end end)
end

pages.eggs = function()
	local c = card(content, "Catalog")
	if #snap.catalog == 0 then text(c, "No catalog yet. Connect HOOKS.GetCatalog in OwnerPanelServer.", 14, C.Muted, FB) end
	local chosen
	local grid = make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = nextOrder() }, c)
	make("UIGridLayout", { CellSize = UDim2.fromOffset(170, 74), CellPadding = UDim2.fromOffset(10, 10) }, grid)
	local actions = card(content, "Selected item")
	local label = text(actions, "Pick an item", 15, C.Ink, F)
	local b1 = button3d(actions, "Give egg", C.Red, function(_) if chosen then local function give() ask("GiveEgg", { itemId = chosen.id }, "Give " .. chosen.name) end; if scope == "lobby" then confirm("Give egg to everyone?", chosen.name, give) else give() end end end)
	local b2 = button3d(actions, "Give character", C.Gold, function() if chosen then local function give() ask("GiveCharacter", { itemId = chosen.id }, "Give " .. chosen.name) end; if scope == "lobby" then confirm("Give character to everyone?", chosen.name, give) else give() end end end)
	local b3 = button3d(actions, "Spawn on river", C.Gold, function() if chosen then ask("SpawnEgg", { itemId = chosen.id }, "Spawn " .. chosen.name) end end)
	b1.set(false); b2.set(false); b3.set(false)
	for _, it in snap.catalog do
		local cell = make("TextButton", { Text = "", BackgroundColor3 = C.Soft, AutoButtonColor = false }, grid); corner(cell, 12); stroke(cell, 2)
		text(cell, it.name, 14, C.Ink, F, { Position = UDim2.fromOffset(12, 12) })
		text(cell, it.rarity or "", 12, RC[it.rarity] or C.Muted, F, { Position = UDim2.fromOffset(12, 38) })
		cell.Activated:Connect(function()
			chosen = it; label.Text = it.name .. " · " .. (it.rarity or "")
			b1.set(it.eggAvailable); b2.set(it.charAvailable); b3.set(it.eggAvailable and not it.noRiver)
		end)
	end
end

pages.money = function()
	local c = card(content, "Amount")
	local box = input(c, "Amount", true); box.Text = "100000"
	local prev = text(c, "", 15, C.OkT, F)
	local function upd() local n = tonumber(box.Text); prev.Text = n and n > 0 and n < math.huge and n == n and (fmt(n) .. " · " .. box.Text) or "Enter a positive amount (no gameplay cap)"; prev.TextColor3 = (n and n > 0 and n < math.huge and n == n) and C.OkT or C.ErrT end
	box:GetPropertyChangedSignal("Text"):Connect(upd); upd()
	local row = chipRow(c)
	for _, p in { { "1K", 1e3 }, { "100K", 1e5 }, { "1M", 1e6 }, { "1B", 1e9 } } do chip(row, p[1], false, function() box.Text = tostring(p[2]) end) end
	local a = card(content, "Actions")
	button3d(a, "Give cash", C.Red, function(b) if scope == "lobby" then confirm("Give cash to everyone?", "Every player receives " .. fmt(box.Text), function() ask("GiveCash", { amount = box.Text }, "Give lobby", b) end) else ask("GiveCash", { amount = box.Text }, "Give " .. fmt(box.Text), b) end end)
	button3d(a, "Set exact balance", C.Gold, function() confirm("Replace balance?", "Their current balance is overwritten.", function() ask("SetCash", { amount = box.Text }, "Set balance " .. fmt(box.Text)) end) end)
	button3d(a, "Give to entire lobby", C.Gold, function() confirm("Give cash to everyone?", "Every player in this server receives " .. fmt(box.Text) .. ".", function() ask("GiveCash", { amount = box.Text, scope = "lobby" }, "Give lobby " .. fmt(box.Text)) end) end)
end

pages.temple = function()
	local sel = selected()
	if scope == "lobby" then card(content, "Temple controls apply to one player. Choose Me or Selected."); return end
	if not sel then card(content, "Select a player first."); return end
	local plot = sel.plot
	local c = card(content, sel.name .. "'s temple")
	text(c, plot and ("Level %d / 3 · %d / 12 slots%s"):format(plot.level or 1, plot.slots or 1, plot.building and " · constructing" or "") or "No plot data (connect HOOKS.GetPlot)", 14, C.Muted, FB)
	button3d(c, "Upgrade temple", C.Red, function(b) ask("UpgradeTemple", {}, "Upgrade temple", b); refresh(); render() end)
	button3d(c, "Unlock next slot", C.Gold, function(b) ask("UnlockSlot", {}, "Unlock slot", b); refresh(); render() end)
	button3d(c, "Add incubator", C.Gold, function(b) ask("AddIncubator", {}, "Add incubator", b); refresh(); render() end)
	if plot and plot.incubators then
		local ic = card(content, "Incubators")
		for i, lvl in plot.incubators do button3d(ic, ("Incubator %d · level %d → upgrade"):format(i, lvl), lvl >= 3 and C.Soft or C.Gold, function(b) ask("UpgradeIncubator", { index = i }, "Upgrade incubator " .. i, b); refresh(); render() end).set(lvl < 3) end
	end
	local p = card(content, "Player")
	button3d(p, "Send home", C.Gold, function(b) ask("SendHome", {}, "Send home", b) end)
	button3d(p, "Bring to me", C.Gold, function(b) ask("Bring", {}, "Bring to me", b) end)
	button3d(p, "Go to player", C.Gold, function(b) ask("GoTo", {}, "Go to player", b) end)
	button3d(p, "Respawn", C.Gold, function(b) confirm("Respawn player?", "Their character will restart.", function() ask("Respawn", {}, "Respawn", b) end) end)
	local d = card(content, "Clean-up")
	button3d(d, "Clear held inventory", C.Danger, function() confirm("Clear held inventory?", "Removes held eggs and characters.", function() ask("ClearInventory", {}, "Clear inventory") end) end)
	button3d(d, "Clear placed characters", C.Danger, function() confirm("Clear placed characters?", "Removes every placed character on their plot.", function() ask("ClearPlaced", {}, "Clear placed") end) end)
	button3d(d, "Reset slot unlocks", C.Danger, function() confirm("Reset slot unlocks?", "Locks every slot except the first.", function() ask("ResetSlots", {}, "Reset slots") end) end)
end

local dur = 300
pages.events = function()
	local d = card(content, "Duration")
	local row = chipRow(d)
	for _, x in { { "5 min", 300 }, { "10 min", 600 }, { "30 min", 1800 } } do chip(row, x[1], dur == x[2], function() dur = x[2]; render() end) end
	for _, ev in { { "rush", "Egg Rush", "Eggs spawn twice as fast." }, { "cash", "Double Cash", "All character income is doubled." }, { "gold", "Golden Hour", "Warm sunset lighting across the map." } } do
		local c = card(content, ev[2]); text(c, ev[3], 14, C.Muted, FB)
		button3d(c, "Start · " .. (dur // 60) .. " min", C.Red, function(b) ask("StartEvent", { eventId = ev[1], seconds = dur }, "Start " .. ev[2], b) end)
	end
	local s = card(content, "Event controls")
	button3d(s, "Stop event", C.Danger, function(b) ask("StopEvent", {}, "Stop event", b) end)
	local box = input(s, "River spawn interval (seconds, 1.5-30)", false)
	button3d(s, "Set spawn interval", C.Gold, function(b) ask("SetSpawnInterval", { seconds = box.Text }, "Spawn interval " .. box.Text .. " s", b) end)
end

pages.log = function()
	local c = card(content, "This session · last 50 results")
	if #logRows == 0 then text(c, "No actions yet this session.", 14, C.Muted, FB) end
	for _, l in logRows do
		local r = make("Frame", { BackgroundColor3 = l.ok and C.OkB or C.ErrB, Size = UDim2.new(1, 0, 0, 38), LayoutOrder = nextOrder() }, c); corner(r, 10); stroke(r, 2)
		text(r, ("%s   %s   ·   %s"):format(l.time, l.action, l.msg), 14, l.ok and C.OkT or C.ErrT, F, { Position = UDim2.fromOffset(12, 9) })
	end
end

---------------------------------------------------------------- render + open/close
render = function()
	for _, ch in content:GetChildren() do if ch:IsA("GuiObject") then ch:Destroy() end end
	order = 0
	title.Text = NAV[table.find((function() local t = {} for i, n in NAV do t[i] = n[1] end return t end)(), page)][2]
	subtitle.Text = SUB[page]
	for id, b in navBtns do b.BackgroundColor3 = id == page and C.Tint or C.Side; b.Bar.Visible = id == page end
	for id, b in scopeBtns do b.BackgroundColor3 = id == scope and C.Red or C.Soft; b.TextColor3 = id == scope and Color3.new(1, 1, 1) or C.Ink end
	local sel = selected()
	recipient.Text = scope == "lobby" and ("Entire lobby (" .. #snap.players .. ")") or scope == "me" and ("Me · @" .. player.Name) or (sel and (sel.name .. " · @" .. sel.user) or "No player selected")
	recipient.TextColor3 = (scope == "selected" and not sel) and C.ErrT or C.Ink
	pages[page]()
end

for i, n in NAV do
	local b = make("TextButton", { Text = "  " .. n[2], FontFace = F, TextSize = 15, TextColor3 = C.Ink, TextXAlignment = Enum.TextXAlignment.Left, BackgroundColor3 = C.Side,
		Size = UDim2.new(1, 0, 0, 42), AutoButtonColor = false, LayoutOrder = 10 + i }, side)
	corner(b, 10)
	make("Frame", { Name = "Bar", BackgroundColor3 = C.Red, BorderSizePixel = 0, Size = UDim2.new(0, 4, 1, -12), Position = UDim2.fromOffset(0, 6), Visible = false }, b)
	b.Activated:Connect(function() page = n[1]; render() end)
	navBtns[n[1]] = b
end
for i, s in { { "me", "Me" }, { "selected", "Selected" }, { "lobby", "Lobby" } } do
	local b = make("TextButton", { Text = s[2], FontFace = F, TextSize = 14, Size = UDim2.fromOffset(86, 34), AutoButtonColor = false, LayoutOrder = i }, right)
	corner(b, 10); stroke(b, 2)
	b.Activated:Connect(function() scope = s[1]; if scope == "me" then selectedId = player.UserId end; render() end)
	scopeBtns[s[1]] = b
end

local function open() refresh(); render(); gui.Enabled = true; fit.Scale *= 0.94; refit()
	panel.Position = UDim2.new(0.5, 0, 0.5, 14); TweenService:Create(panel, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Position = UDim2.fromScale(0.5, 0.5) }):Play() end
local function close() gui.Enabled = false end
closeBtn.Activated:Connect(close)
UserInputService.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.F8 then if gui.Enabled then close() else open() end
	elseif i.KeyCode == Enum.KeyCode.Escape and gui.Enabled then close() end
end)
-- /owner chat command
ReplicatedStorage:WaitForChild("OwnerPanelOpen").OnClientEvent:Connect(open)
Players.PlayerAdded:Connect(function() if gui.Enabled then refresh(); render() end end)
Players.PlayerRemoving:Connect(function(p) if p.UserId == selectedId then selectedId = nil end if gui.Enabled then task.wait(); refresh(); render() end end)
