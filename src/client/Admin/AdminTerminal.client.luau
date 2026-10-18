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
do
    local ok, _, msg = pcall(function()
        return Action:InvokeServer("Announce", { text = "" })
    end)
    isStaff = ok and msg ~= nil and not tostring(msg):find("Staff access only")
end
if not isStaff then
    return
end

local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json")
local BOLD = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local GREEN, DIM, RED, GOLD, CYAN, W =
    Color3.fromRGB(120, 255, 140),
    Color3.fromRGB(150, 160, 190),
    Color3.fromRGB(255, 110, 110),
    Color3.fromRGB(255, 214, 90),
    Color3.fromRGB(110, 210, 255),
    Color3.new(1, 1, 1)
local function new(c, p, parent)
    local o = Instance.new(c)
    for k, v in p do
        o[k] = v
    end
    o.Parent = parent
    return o
end

local gui = new("ScreenGui", {
    Name = "AdminTerminal",
    ResetOnSpawn = false,
    DisplayOrder = 200,
    Enabled = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))
local win = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 70),
    Size = UDim2.fromOffset(720, 400),
    BackgroundColor3 = Color3.fromRGB(10, 12, 20),
    BackgroundTransparency = 0.06,
}, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, win)
local edge = new("UIStroke", { Color = W, Thickness = 2 }, win)
new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(120, 255, 140), Color3.fromRGB(110, 210, 255)) }, edge)
new("UIScale", { Scale = math.clamp(workspace.CurrentCamera.ViewportSize.X / 800, 0.55, 1) }, win)
local bar = new(
    "Frame",
    { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(22, 26, 40), BorderSizePixel = 0 },
    win
)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, bar)
for i, c in { Color3.fromRGB(255, 95, 86), Color3.fromRGB(255, 189, 46), Color3.fromRGB(39, 201, 63) } do
    local d = new(
        "Frame",
        { Position = UDim2.fromOffset(12 + (i - 1) * 20, 11), Size = UDim2.fromOffset(12, 12), BackgroundColor3 = c },
        bar
    )
    new("UICorner", { CornerRadius = UDim.new(1, 0) }, d)
end
new("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Text = "velm@hatch-an-anime: ~  (F2 to close · /help)",
    FontFace = BOLD,
    TextSize = 14,
    TextColor3 = DIM,
}, bar)
local log = new("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 42),
    Size = UDim2.new(1, -24, 1, -92),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = DIM,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, win)
new("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, log)
local inputBg = new("Frame", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 12, 1, -12),
    Size = UDim2.new(1, -24, 0, 34),
    BackgroundColor3 = Color3.fromRGB(20, 24, 36),
}, win)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, inputBg)
new("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(0, 20, 1, 0),
    Text = "❯",
    FontFace = BOLD,
    TextSize = 18,
    TextColor3 = GREEN,
}, inputBg)
local box = new("TextBox", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(32, 0),
    Size = UDim2.new(1, -40, 1, 0),
    Text = "",
    PlaceholderText = "/give me cash 1000   ·   ;global Big update tonight!   ·   ;invite",
    PlaceholderColor3 = Color3.fromRGB(90, 100, 125),
    FontFace = MONO,
    TextSize = 16,
    TextColor3 = W,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
}, inputBg)

local n = 0
local function out(text, color)
    n += 1
    new("TextLabel", {
        LayoutOrder = n,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = text,
        FontFace = MONO,
        TextSize = 15,
        TextColor3 = color or W,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    }, log)
    task.defer(function()
        log.CanvasPosition = Vector2.new(0, 1e6)
    end)
end

-- helpers
local function findPlayer(name)
    if not name or name == "" then
        return nil
    end
    name = name:lower():gsub("^@", "")
    if name == "me" then
        return player
    end
    for _, p in Players:GetPlayers() do
        if p.Name:lower() == name or p.DisplayName:lower() == name then
            return p
        end
    end
    for _, p in Players:GetPlayers() do
        if p.Name:lower():sub(1, #name) == name then
            return p
        end
    end
    return nil
end
local function target(name)
    if not name then
        return nil, "Say who: a username, me or all."
    end
    local l = name:lower()
    if l == "me" then
        return { scope = "me" }
    end
    if l == "all" or l == "lobby" then
        return { scope = "lobby", confirmed = true }
    end
    local p = findPlayer(name)
    if not p then
        return nil, "No player called '" .. name .. "' in this server."
    end
    return { userId = p.UserId }
end
local function send(action, a)
    local ok, res, msg = pcall(function()
        return Action:InvokeServer(action, a)
    end)
    if not ok then
        out("✖ " .. tostring(res), RED)
        return
    end
    out((res and "✔ " or "✖ ") .. tostring(msg or (res and "Done." or "Failed.")), res and GREEN or RED)
end
local EVENTS =
    { rush = "rush", eggrush = "rush", cash = "cash", doublecash = "cash", gold = "gold", goldenhour = "gold" }
local function merge(t, extra)
    t = table.clone(t)
    for k, v in extra do
        t[k] = v
    end
    return t
end

-- ===== commands (prefix ; : / ! or none) =====
local SocialService = game:GetService("SocialService")
local CMDS, ORDER = {}, {}
local function cmd(names, usage, desc, fn)
    local def = { names = names, usage = usage, desc = desc, fn = fn }
    for _, n in names do
        CMDS[n] = def
    end
    table.insert(ORDER, def)
end
local function need(t, err)
    if not t then
        out("✖ " .. err, RED)
    end
    return t
end
local function who(name)
    local t, err = target(name)
    if not t then
        out("✖ " .. err, RED)
    end
    return t
end
local GIVE_TYPES =
    { cash = "cash", money = "cash", egg = "egg", eggs = "egg", char = "char", character = "char", pet = "char" }
local function give(kind, whoName, a3, a4)
    local t = who(whoName)
    if not t then
        return
    end
    if kind == "cash" then
        local amt = need(tonumber(a3), "Amount needed: ;cash <who> <amount>")
        if amt then
            send("GiveCash", merge(t, { amount = amt, confirmed = true }))
        end
    elseif kind == "egg" then
        if need(a3, "Egg needed: ;egg <who> <EggId> [mutation]") then
            send("GiveEgg", merge(t, { itemId = a3, mutation = a4, confirmed = true }))
        end
    else
        if need(a3, "Character needed: ;char <who> <Id> [mutation]") then
            send("GiveCharacter", merge(t, { itemId = a3, mutation = a4, confirmed = true }))
        end
    end
end

cmd({ "help", "cmds", "commands", "?" }, "/help [command]", "list commands", function(a)
    local d = a[1] and CMDS[a[1]:lower()]
    if d then
        out("  " .. d.usage .. "   — " .. d.desc, GOLD)
        out("  aliases: " .. table.concat(d.names, ", "), DIM)
        return
    end
    for _, c in ORDER do
        out(string.format("  %-40s %s", c.usage, c.desc), DIM)
    end
    out("  who = @name · me · all      Tab completes names      ↑/↓ history", CYAN)
end)
cmd({ "players", "plrs", "list" }, "/players", "everyone in this server", function()
    for _, p in Players:GetPlayers() do
        out(string.format("  @%-20s %-18s %d", p.Name, p.DisplayName, p.UserId), W)
    end
end)
cmd({ "invite", "inv" }, "/invite [username]", "invite a friend (or get the game link for anyone)", function(a)
    local name = a[1] and a[1]:gsub("^@", "")
    if not name then
        local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
        if ok and can then
            SocialService:PromptGameInvite(player)
            out("✔ Invite window opened.", GREEN)
        else
            out("✖ Invites aren't available here (works in the live game).", RED)
        end
        return
    end
    local okId, id = pcall(Players.GetUserIdFromNameAsync, Players, name)
    if not okId or not id then
        out("✖ No Roblox user called '" .. name .. "'.", RED)
        return
    end
    local okF, friends = pcall(player.IsFriendsWith, player, id)
    if okF and friends then
        local opts = Instance.new("ExperienceInviteOptions")
        opts.InviteUser = id
        opts.PromptMessage = "Join me in Hatch an Anime!"
        local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player, id)
        if ok and can then
            SocialService:PromptGameInvite(player, opts)
            out("✔ Invite sent to @" .. name .. " — they get a Roblox notification.", GREEN)
        else
            out("✖ Roblox won't let you invite @" .. name .. " right now (their settings, or Studio).", RED)
        end
    else
        out("✖ @" .. name .. " isn't on your friends list — Roblox only allows game invites to friends.", RED)
        out("  Send them this link instead (they'll join a public server):", DIM)
        out("  https://www.roblox.com/games/" .. game.PlaceId, GOLD)
        out("  Or friend them first, then /invite " .. name .. " again.", DIM)
    end
end)
cmd({ "link" }, "/link", "the game link to send to anyone", function()
    out("  https://www.roblox.com/games/" .. game.PlaceId, GOLD)
end)
cmd({ "give" }, "/give <who> <cash|egg|char> <amount|Id> [mutation]", "give anything", function(a)
    local k1, k2 = GIVE_TYPES[(a[1] or ""):lower()], GIVE_TYPES[(a[2] or ""):lower()]
    if k1 then
        give(k1, a[2], a[3], a[4])
    elseif k2 then
        give(k2, a[1], a[3], a[4])
    else
        out("✖ ;give <who> <cash|egg|char> ...", RED)
    end
end)
cmd({ "cash", "money" }, "/cash <who> <amount>", "give cash", function(a)
    give("cash", a[1], a[2])
end)
cmd({ "setcash" }, "/setcash <who> <amount>", "set a player's cash exactly", function(a)
    local t = who(a[1])
    local amt = tonumber(a[2])
    if t and need(amt, "/setcash <who> <amount>") then
        send("SetCash", merge(t, { amount = amt, confirmed = true }))
    end
end)
cmd({ "egg" }, "/egg <who> <EggId> [mutation]", "give an egg (e.g. ;egg me Pirate Gold)", function(a)
    give("egg", a[1], a[2], a[3])
end)
cmd({ "char", "character" }, "/char <who> <Id> [mutation]", "give a character", function(a)
    give("char", a[1], a[2], a[3])
end)
cmd({ "riveregg", "spawn", "drop" }, "/riveregg <EggId>", "drop an egg on the river", function(a)
    send("SpawnEgg", { scope = "me", itemId = a[1] })
end)
cmd({ "event", "ev" }, "/event <rush|cash|gold|stop> [minutes]", "start / stop a live event", function(a)
    local k = (a[1] or ""):lower()
    if k == "stop" or k == "end" then
        send("StopEvent", { scope = "me" })
        return
    end
    local id = EVENTS[k]
    if not id then
        out("✖ ;event <rush|cash|gold|stop> [minutes]", RED)
        return
    end
    send("StartEvent", { scope = "me", eventId = id, seconds = math.floor((tonumber(a[2]) or 10) * 60) })
end)
cmd({ "stopevent", "endevent" }, "/stopevent", "end the current event", function()
    send("StopEvent", { scope = "me" })
end)
cmd({ "night" }, "/night", "force night", function()
    send("StartNight", { scope = "me" })
end)
cmd({ "day" }, "/day", "back to day", function()
    send("StopNight", { scope = "me" })
end)
cmd({ "shower", "eggshower" }, "/shower", "egg shower", function()
    send("EggShower", { scope = "me" })
end)
cmd({ "spawnrate", "rate" }, "/spawnrate <seconds>", "river egg spawn interval (1.5–30)", function(a)
    send("SetSpawnInterval", { scope = "me", seconds = tonumber(a[1]) })
end)
cmd({ "announce", "ann", "a", "m" }, "/announce <text>", "banner in this server", function(_, rest)
    send("Announce", { text = rest, color = "pink" })
end)
cmd({ "gannounce", "ga", "global", "sm" }, "/global <text>", "banner in EVERY server", function(_, rest)
    send("Announce", { text = rest, allServers = true, color = "purple" })
end)
cmd({ "update", "shutdown" }, "/update [text]", "update countdown + rejoin all servers", function(_, rest)
    send("AnnounceUpdate", { text = rest ~= "" and rest or nil })
end)
local function onPlayer(action, extra)
    return function(a)
        local p = findPlayer(a[1])
        if not p then
            out("✖ No player '" .. tostring(a[1]) .. "'", RED)
            return
        end
        send(action, merge({ userId = p.UserId, confirmed = true }, extra or {}))
    end
end
cmd({ "kick" }, "/kick <who>", "kick a player", onPlayer("Kick"))
cmd({ "ban" }, "/ban <who>", "ban for 24 h", onPlayer("Ban"))
cmd({ "unban" }, "/unban <userId>", "lift a ban", function(a)
    send("Unban", { userId = tonumber(a[1]) })
end)
cmd({ "bring" }, "/bring <who>", "teleport them to you", onPlayer("Bring"))
cmd({ "goto", "tp", "to" }, "/tp <who>", "teleport to them", onPlayer("GoTo"))
cmd({ "home", "base" }, "/home <who>", "send them to their temple", onPlayer("SendHome"))
cmd({ "respawn", "re", "refresh" }, "/respawn <who>", "respawn a player", onPlayer("Respawn"))
local function onTarget(action)
    return function(a)
        local t = who(a[1] or "me")
        if t then
            send(action, merge(t, { confirmed = true }))
        end
    end
end
cmd({ "unlock", "slot" }, "/unlock <who>", "unlock their next slot", onTarget("UnlockSlot"))
cmd({ "temple", "upgrade" }, "/temple <who>", "upgrade their temple", onTarget("UpgradeTemple"))
cmd({ "addinc", "incubator" }, "/addinc <who>", "give them another incubator", onTarget("AddIncubator"))
cmd({ "upinc" }, "/upinc <who>", "upgrade their first incubator", function(a)
    local t = who(a[1] or "me")
    if t then
        send("UpgradeIncubator", merge(t, { index = tonumber(a[2]) or 1, confirmed = true }))
    end
end)
cmd({ "clearinv" }, "/clearinv <who>", "clear their backpack", onTarget("ClearInventory"))
cmd({ "clearplaced" }, "/clearplaced <who>", "clear their placed characters", onTarget("ClearPlaced"))
cmd({ "resetslots" }, "/resetslots <who>", "reset their slots", onTarget("ResetSlots"))
cmd({ "staff" }, "/staff", "go to the private staff server", function()
    send("JoinStaffServer", {})
end)
cmd({ "public" }, "/public", "back to a public server", function()
    send("ReturnToPublic", {})
end)
cmd({ "admin" }, "/admin <add|remove> <userId|@name>", "owner: share the terminal", function(a)
    local id = tonumber(a[2])
    if not id and a[2] then
        local p = findPlayer(a[2])
        id = p and p.UserId
    end
    if not need(id, "/admin add <userId|@name>") then
        return
    end
    send("SetAdmin", { userId = id, on = (a[1] or ""):lower() ~= "remove" })
end)
cmd({ "clear", "cls" }, "/clear", "clear this window", function()
    for _, c in log:GetChildren() do
        if c:IsA("TextLabel") then
            c:Destroy()
        end
    end
end)

local function parse(line)
    local body = line:gsub("^%s*[;:/!]", "")
    local name, rest = body:match("^%s*(%S+)%s*(.*)$")
    local args = {}
    for w in (rest or ""):gmatch("%S+") do
        table.insert(args, w)
    end
    return (name or ""):lower(), args, rest or ""
end
local function run(line)
    local name, args, rest = parse(line)
    if name == "" then
        return
    end
    out("❯ " .. line, CYAN)
    local d = CMDS[name]
    if not d then
        out("✖ Unknown command '" .. name .. "'. Try /help", RED)
        return
    end
    local ok, err = pcall(d.fn, args, rest)
    if not ok then
        out("✖ " .. tostring(err), RED)
    end
end

-- suggestions under the input
local sug = new("Frame", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 12, 1, -50),
    Size = UDim2.new(1, -24, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundColor3 = Color3.fromRGB(16, 20, 32),
    BackgroundTransparency = 0.05,
    Visible = false,
    ZIndex = 5,
}, win)
new("UICorner", { CornerRadius = UDim.new(0, 8) }, sug)
new("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, sug)
new("UIPadding", { PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) }, sug)
local firstMatch
local function refreshSug()
    for _, c in sug:GetChildren() do
        if c:IsA("TextLabel") then
            c:Destroy()
        end
    end
    firstMatch = nil
    local t = box.Text
    local name = t:gsub("^%s*[;:/!]", ""):match("^(%S*)$")
    if not name or name == "" then
        sug.Visible = false
        return
    end
    local k = 0
    for _, d in ORDER do
        for _, n in d.names do
            if n:sub(1, #name) == name:lower() then
                k += 1
                firstMatch = firstMatch or n
                new("TextLabel", {
                    LayoutOrder = k,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    Text = d.usage .. "   " .. d.desc,
                    FontFace = MONO,
                    TextSize = 14,
                    TextColor3 = k == 1 and GOLD or DIM,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6,
                }, sug)
                break
            end
        end
        if k >= 6 then
            break
        end
    end
    sug.Visible = k > 0
end
box:GetPropertyChangedSignal("Text"):Connect(refreshSug)
local function tabComplete()
    local t = box.Text
    if t:gsub("^%s*[;:/!]", ""):match("^%S*$") then
        if firstMatch then
            local pre = t:match("^%s*([;:/!]?)") or ";"
            box.Text = (pre ~= "" and pre or "/") .. firstMatch .. " "
        end
    else
        local head, last = t:match("^(.-)(%S*)$")
        if last ~= "" then
            local l = last:lower():gsub("^@", "")
            for _, p in Players:GetPlayers() do
                if p.Name:lower():sub(1, #l) == l or p.DisplayName:lower():sub(1, #l) == l then
                    box.Text = head .. p.Name .. " "
                    break
                end
            end
        end
    end
    box.CursorPosition = #box.Text + 1
end

local history, hi = {}, 0
box.FocusLost:Connect(function(enter)
    if not enter then
        return
    end
    local line = box.Text
    box.Text = ""
    if line:gsub("%s", "") ~= "" then
        table.insert(history, line)
        hi = #history + 1
        task.spawn(run, line)
    end
    task.defer(function()
        box:CaptureFocus()
    end)
end)
local function toggle()
    gui.Enabled = not gui.Enabled
    if gui.Enabled then
        win.Size = UDim2.fromOffset(720, 0)
        TS:Create(win, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(720, 400) }):Play()
        task.defer(function()
            box:CaptureFocus()
        end)
    end
end
UIS.InputBegan:Connect(function(input, gp)
    if input.KeyCode == Enum.KeyCode.F2 or (input.KeyCode == Enum.KeyCode.Backquote and not gp) then
        toggle()
        return
    end
    if not (gui.Enabled and box:IsFocused()) then
        return
    end
    if input.KeyCode == Enum.KeyCode.Tab then
        task.defer(function()
            box.Text = box.Text:gsub("\t", "")
            tabComplete()
        end)
        return
    end
    if #history > 0 then
        if input.KeyCode == Enum.KeyCode.Up then
            hi = math.max(1, hi - 1)
            box.Text = history[hi] or ""
            box.CursorPosition = #box.Text + 1
        elseif input.KeyCode == Enum.KeyCode.Down then
            hi = math.min(#history + 1, hi + 1)
            box.Text = history[hi] or ""
            box.CursorPosition = #box.Text + 1
        end
    end
end)
do
    local c = Instance.new("TextChatCommand")
    c.Name = "OpenTerminal"
    c.PrimaryAlias = "/terminal"
    c.SecondaryAlias = "/t"
    c.Parent = TextChatService
    c.Triggered:Connect(function(src)
        if src.UserId == player.UserId then
            toggle()
        end
    end)
end
out("Velm terminal ready. Type /help  (Tab completes, ↑/↓ history)", GREEN)
