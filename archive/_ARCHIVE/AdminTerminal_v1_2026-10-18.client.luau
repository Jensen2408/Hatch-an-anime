-- AdminTerminal (LocalScript): command line for staff (owner + admins from AdminRoles).
-- Open with F2 or the ` key, or type /terminal in chat. Every command goes through ReplicatedStorage.OwnerPanel.Action,
-- so the server checks permissions exactly like the owner panel (admins can't use owner-only commands).
local Players = game:GetService("Players")
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local player = Players.LocalPlayer
local Action = RS:WaitForChild("OwnerPanel"):WaitForChild("Action")

-- staff check: an empty announcement is refused with "Write a message first." only for staff
local isStaff = false
do local ok, _, msg = pcall(function() return Action:InvokeServer("Announce", { text = "" }) end)
	isStaff = ok and msg ~= nil and not tostring(msg):find("Staff access only") end
if not isStaff then return end

local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json")
local BOLD = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local GREEN, DIM, RED, GOLD, CYAN, W = Color3.fromRGB(120, 255, 140), Color3.fromRGB(150, 160, 190), Color3.fromRGB(255, 110, 110), Color3.fromRGB(255, 214, 90), Color3.fromRGB(110, 210, 255), Color3.new(1, 1, 1)
local function new(c, p, parent) local o = Instance.new(c) for k, v in p do o[k] = v end o.Parent = parent return o end

local gui = new("ScreenGui", { Name = "AdminTerminal", ResetOnSpawn = false, DisplayOrder = 200, Enabled = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling }, player:WaitForChild("PlayerGui"))
local win = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(720, 400), BackgroundColor3 = Color3.fromRGB(10, 12, 20), BackgroundTransparency = 0.06 }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, win)
local edge = new("UIStroke", { Color = W, Thickness = 2 }, win)
new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(120, 255, 140), Color3.fromRGB(110, 210, 255)) }, edge)
new("UIScale", { Scale = math.clamp(workspace.CurrentCamera.ViewportSize.X / 800, 0.55, 1) }, win)
local bar = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(22, 26, 40), BorderSizePixel = 0 }, win)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, bar)
for i, c in { Color3.fromRGB(255, 95, 86), Color3.fromRGB(255, 189, 46), Color3.fromRGB(39, 201, 63) } do local d = new("Frame", { Position = UDim2.fromOffset(12 + (i - 1) * 20, 11), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = c }, bar) new("UICorner", { CornerRadius = UDim.new(1, 0) }, d) end
new("TextLabel", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Text = "velm@hatch-an-anime: ~  (F2 to close · type help)", FontFace = BOLD, TextSize = 14, TextColor3 = DIM }, bar)
local log = new("ScrollingFrame", { Position = UDim2.fromOffset(12, 42), Size = UDim2.new(1, -24, 1, -92), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 4, ScrollBarImageColor3 = DIM, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y }, win)
new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, log)
local inputBg = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 12, 1, -12), Size = UDim2.new(1, -24, 0, 34), BackgroundColor3 = Color3.fromRGB(20, 24, 36) }, win)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, inputBg)
new("TextLabel", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 0), Size = UDim2.new(0, 20, 1, 0), Text = "❯", FontFace = BOLD, TextSize = 18, TextColor3 = GREEN }, inputBg)
local box = new("TextBox", { BackgroundTransparency = 1, Position = UDim2.fromOffset(32, 0), Size = UDim2.new(1, -40, 1, 0), Text = "", PlaceholderText = "give cash me 1000   ·   announce all Big update tonight!", PlaceholderColor3 = Color3.fromRGB(90, 100, 125), FontFace = MONO, TextSize = 16, TextColor3 = W, TextXAlignment = Enum.TextXAlignment.Left, ClearTextOnFocus = false }, inputBg)

local n = 0
local function out(text, color)
	n += 1
	new("TextLabel", { LayoutOrder = n, BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = text, FontFace = MONO, TextSize = 15, TextColor3 = color or W, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true }, log)
	task.defer(function() log.CanvasPosition = Vector2.new(0, 1e6) end)
end

-- helpers
local function findPlayer(name)
	if not name or name == "" then return nil end
	name = name:lower():gsub("^@", "")
	if name == "me" then return player end
	for _, p in Players:GetPlayers() do if p.Name:lower() == name or p.DisplayName:lower() == name then return p end end
	for _, p in Players:GetPlayers() do if p.Name:lower():sub(1, #name) == name then return p end end
	return nil
end
local function target(name)
	if not name then return nil, "Say who: a username, me or all." end
	local l = name:lower()
	if l == "me" then return { scope = "me" } end
	if l == "all" or l == "lobby" then return { scope = "lobby", confirmed = true } end
	local p = findPlayer(name) if not p then return nil, "No player called '" .. name .. "' in this server." end
	return { userId = p.UserId }
end
local function send(action, a)
	local ok, res, msg = pcall(function() return Action:InvokeServer(action, a) end)
	if not ok then out("✖ " .. tostring(res), RED) return end
	out((res and "✔ " or "✖ ") .. tostring(msg or (res and "Done." or "Failed.")), res and GREEN or RED)
end
local EVENTS = { rush = "rush", eggrush = "rush", cash = "cash", doublecash = "cash", gold = "gold", goldenhour = "gold" }
local function merge(t, extra) t = table.clone(t) for k, v in extra do t[k] = v end return t end

local HELP = {
	{ "players", "list everyone in this server" },
	{ "give cash <who> <amount>", "who = name · me · all" },
	{ "give egg <who> <EggId> [Silver|Gold|Diamond|Rainbow]", "e.g. give egg me Pirate Gold" },
	{ "give char <who> <Id>", "give a character" },
	{ "spawn egg <EggId>", "drop an egg on the river" },
	{ "event start <rush|cash|gold> [minutes]", "start a live event (banner for everyone)" },
	{ "event stop", "end the current event" },
	{ "night start | night stop", "force night / day" },
	{ "shower", "egg shower" },
	{ "announce <text>", "banner in this server" },
	{ "announce all <text>", "banner in EVERY server" },
	{ "kick <who>  ·  ban <who>  ·  unban <userId>", "moderation (ban = 24 h)" },
	{ "bring <who>  ·  goto <who>  ·  home <who>", "teleports" },
	{ "admin add <userId>  ·  admin remove <userId>", "owner only: share the terminal" },
	{ "clear", "clear this window" },
}
local function run(line)
	local args = {} for w in line:gmatch("%S+") do table.insert(args, w) end
	local cmd = (args[1] or ""):lower():gsub("^/", "")
	local sub = (args[2] or ""):lower()
	if cmd == "" then return end
	out("❯ " .. line, CYAN)
	if cmd == "help" then for _, h in HELP do out(string.format("  %-46s %s", h[1], h[2]), DIM) end return end
	if cmd == "clear" then for _, c in log:GetChildren() do if c:IsA("TextLabel") then c:Destroy() end end return end
	if cmd == "players" then for _, p in Players:GetPlayers() do out(string.format("  @%-20s %s  (%d)", p.Name, p.DisplayName, p.UserId), W) end return end
	if cmd == "give" then
		local t, err = target(args[3]) if not t then out("✖ " .. err, RED) return end
		if sub == "cash" or sub == "money" then local amt = tonumber(args[4]) if not amt then out("✖ give cash <who> <amount>", RED) return end send("GiveCash", merge(t, { amount = amt, confirmed = true }))
		elseif sub == "egg" then if not args[4] then out("✖ give egg <who> <EggId>", RED) return end send("GiveEgg", merge(t, { itemId = args[4], mutation = args[5], confirmed = true }))
		elseif sub == "char" or sub == "character" then if not args[4] then out("✖ give char <who> <Id>", RED) return end send("GiveCharacter", merge(t, { itemId = args[4], mutation = args[5], confirmed = true }))
		else out("✖ give cash|egg|char ...", RED) end
		return
	end
	if cmd == "spawn" and sub == "egg" then send("SpawnEgg", { scope = "me", itemId = args[3] }) return end
	if cmd == "event" then
		if sub == "stop" then send("StopEvent", { scope = "me" }) return end
		local id = EVENTS[(args[3] or ""):lower()] if sub ~= "start" or not id then out("✖ event start <rush|cash|gold> [minutes]", RED) return end
		send("StartEvent", { scope = "me", eventId = id, seconds = math.floor((tonumber(args[4]) or 10) * 60) }) return
	end
	if cmd == "night" then send(sub == "stop" and "StopNight" or "StartNight", { scope = "me" }) return end
	if cmd == "shower" then send("EggShower", { scope = "me" }) return end
	if cmd == "announce" then
		local all = sub == "all"
		local text = line:gsub("^%s*/?%S+%s*", "") if all then text = text:gsub("^%S+%s*", "") end
		send("Announce", { text = text, allServers = all, color = "pink" }) return
	end
	if cmd == "kick" or cmd == "ban" or cmd == "bring" or cmd == "goto" or cmd == "home" then
		local p = findPlayer(args[2]) if not p then out("✖ No player called '" .. tostring(args[2]) .. "'", RED) return end
		local action = ({ kick = "Kick", ban = "Ban", bring = "Bring", goto = "GoTo", home = "SendHome" })[cmd]
		send(action, { userId = p.UserId, confirmed = true }) return
	end
	if cmd == "unban" then send("Unban", { userId = tonumber(args[2]) }) return end
	if cmd == "admin" then local id = tonumber(args[3]) if not id then out("✖ admin add|remove <userId>", RED) return end send("SetAdmin", { userId = id, on = sub == "add" }) return end
	out("✖ Unknown command. Type help.", RED)
end

local history, hi = {}, 0
box.FocusLost:Connect(function(enter)
	if not enter then return end
	local line = box.Text box.Text = ""
	if line:gsub("%s", "") ~= "" then table.insert(history, line) hi = #history + 1 task.spawn(run, line) end
	task.defer(function() box:CaptureFocus() end)
end)
local function toggle()
	gui.Enabled = not gui.Enabled
	if gui.Enabled then win.Size = UDim2.fromOffset(720, 0) TS:Create(win, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(720, 400) }):Play() task.defer(function() box:CaptureFocus() end) end
end
UIS.InputBegan:Connect(function(input, gp)
	if input.KeyCode == Enum.KeyCode.F2 or (input.KeyCode == Enum.KeyCode.Backquote and not gp) then toggle() return end
	if gui.Enabled and box:IsFocused() and #history > 0 then
		if input.KeyCode == Enum.KeyCode.Up then hi = math.max(1, hi - 1) box.Text = history[hi] or "" box.CursorPosition = #box.Text + 1
		elseif input.KeyCode == Enum.KeyCode.Down then hi = math.min(#history + 1, hi + 1) box.Text = history[hi] or "" box.CursorPosition = #box.Text + 1 end
	end
end)
do local c = Instance.new("TextChatCommand") c.Name = "OpenTerminal" c.PrimaryAlias = "/terminal" c.SecondaryAlias = "/t" c.Parent = TextChatService
	c.Triggered:Connect(function(src) if src.UserId == player.UserId then toggle() end end) end
out("Velm terminal ready. Type help for commands.", GREEN)
