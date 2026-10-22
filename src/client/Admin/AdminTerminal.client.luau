--[[ StarterPlayerScripts.AdminTerminal  (LocalScript)
Command line for staff (owner + admins from AdminRoles).
Open with F2 or the ` key, or type /terminal in chat. Every command goes through ReplicatedStorage.OwnerPanel.Action,
so the server checks permissions exactly like the owner panel (admins can't use owner-only commands).

Staff detection: at start-up the script invokes Action("Announce", { text = "" }). Staff get a validation error
("Write a message first."), everyone else "Staff access only.", in which case the script returns before building
any UI. This only hides the UI; the server checks every command. (The probe also counts against the 0.2 s rate limit.)
Commands accept the prefixes ; : / ! or none. who = @name / me / all. Tab completes, Up / Down walk the history.
]]
-- ===== 1. Services, remote and staff probe =====
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")
local player = Players.LocalPlayer
local actionRemote = ReplicatedStorage:WaitForChild("OwnerPanel"):WaitForChild("Action")

-- staff check: an empty announcement is refused with "Write a message first." only for staff
local isStaff = false
do
    local ok, _, message = pcall(function()
        return actionRemote:InvokeServer("Announce", { text = "" })
    end)
    isStaff = ok and message ~= nil and not tostring(message):find("Staff access only")
end
if not isStaff then
    return
end

-- ===== 2. Style and window =====
local MONO = Font.new("rbxasset://fonts/families/RobotoMono.json")
local BOLD = Font.new("rbxasset://fonts/families/RobotoMono.json", Enum.FontWeight.Bold)
local GREEN, DIM, RED, GOLD, CYAN, WHITE =
    Color3.fromRGB(120, 255, 140),
    Color3.fromRGB(150, 160, 190),
    Color3.fromRGB(255, 110, 110),
    Color3.fromRGB(255, 214, 90),
    Color3.fromRGB(110, 210, 255),
    Color3.new(1, 1, 1)
local function make(className, props, parent)
    local o = Instance.new(className)
    for key, value in props do
        o[key] = value
    end
    o.Parent = parent
    return o
end

local gui = make("ScreenGui", {
    Name = "AdminTerminal",
    ResetOnSpawn = false,
    DisplayOrder = 200,
    Enabled = false,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, player:WaitForChild("PlayerGui"))
local window = make("Frame", {
    AnchorPoint = Vector2.new(0.5, 0),
    Position = UDim2.new(0.5, 0, 0, 70),
    Size = UDim2.fromOffset(720, 400),
    BackgroundColor3 = Color3.fromRGB(10, 12, 20),
    BackgroundTransparency = 0.06,
}, gui)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, window)
local edge = make("UIStroke", { Color = WHITE, Thickness = 2 }, window)
make("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(120, 255, 140), Color3.fromRGB(110, 210, 255)) }, edge)
make("UIScale", { Scale = math.clamp(workspace.CurrentCamera.ViewportSize.X / 800, 0.55, 1) }, window)
local titleBar = make(
    "Frame",
    { Size = UDim2.new(1, 0, 0, 34), BackgroundColor3 = Color3.fromRGB(22, 26, 40), BorderSizePixel = 0 },
    window
)
make("UICorner", { CornerRadius = UDim.new(0, 12) }, titleBar)
for i, dotColor in { Color3.fromRGB(255, 95, 86), Color3.fromRGB(255, 189, 46), Color3.fromRGB(39, 201, 63) } do
    local dot = make("Frame", {
        Position = UDim2.fromOffset(12 + (i - 1) * 20, 11),
        Size = UDim2.fromOffset(12, 12),
        BackgroundColor3 = dotColor,
    }, titleBar)
    make("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
end
make("TextLabel", {
    BackgroundTransparency = 1,
    Size = UDim2.fromScale(1, 1),
    Text = "velm@hatch-an-anime: ~  (F2 to close · /help)",
    FontFace = BOLD,
    TextSize = 14,
    TextColor3 = DIM,
}, titleBar)
local logFrame = make("ScrollingFrame", {
    Position = UDim2.fromOffset(12, 42),
    Size = UDim2.new(1, -24, 1, -92),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 4,
    ScrollBarImageColor3 = DIM,
    CanvasSize = UDim2.new(),
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
}, window)
make("UIListLayout", { Padding = UDim.new(0, 2), SortOrder = Enum.SortOrder.LayoutOrder }, logFrame)
local inputBg = make("Frame", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 12, 1, -12),
    Size = UDim2.new(1, -24, 0, 34),
    BackgroundColor3 = Color3.fromRGB(20, 24, 36),
}, window)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, inputBg)
make("TextLabel", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(10, 0),
    Size = UDim2.new(0, 20, 1, 0),
    Text = "❯",
    FontFace = BOLD,
    TextSize = 18,
    TextColor3 = GREEN,
}, inputBg)
local inputBox = make("TextBox", {
    BackgroundTransparency = 1,
    Position = UDim2.fromOffset(32, 0),
    Size = UDim2.new(1, -40, 1, 0),
    Text = "",
    PlaceholderText = "/give me cash 1000   ·   ;global Big update tonight!   ·   ;invite",
    PlaceholderColor3 = Color3.fromRGB(90, 100, 125),
    FontFace = MONO,
    TextSize = 16,
    TextColor3 = WHITE,
    TextXAlignment = Enum.TextXAlignment.Left,
    ClearTextOnFocus = false,
}, inputBg)

-- ===== 3. Output and targeting helpers =====
local logLineCount = 0
local function printLine(text, color)
    logLineCount += 1
    make("TextLabel", {
        LayoutOrder = logLineCount,
        BackgroundTransparency = 1,
        Size = UDim2.new(1, 0, 0, 0),
        AutomaticSize = Enum.AutomaticSize.Y,
        Text = text,
        FontFace = MONO,
        TextSize = 15,
        TextColor3 = color or WHITE,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
    }, logFrame)
    task.defer(function()
        logFrame.CanvasPosition = Vector2.new(0, 1e6)
    end)
end

-- helpers
-- Exact username / display name first, then a username prefix. "me" is the local player.
local function findPlayer(name)
    if not name or name == "" then
        return nil
    end
    name = name:lower():gsub("^@", "")
    if name == "me" then
        return player
    end
    for _, candidate in Players:GetPlayers() do
        if candidate.Name:lower() == name or candidate.DisplayName:lower() == name then
            return candidate
        end
    end
    for _, candidate in Players:GetPlayers() do
        if candidate.Name:lower():sub(1, #name) == name then
            return candidate
        end
    end
    return nil
end
-- who -> panel targeting args ({ scope = "me" } / lobby / { userId }) or nil + error text.
local function buildTarget(name)
    if not name then
        return nil, "Say who: a username, me or all."
    end
    local lowered = name:lower()
    if lowered == "me" then
        return { scope = "me" }
    end
    if lowered == "all" or lowered == "lobby" then
        return { scope = "lobby", confirmed = true }
    end
    local found = findPlayer(name)
    if not found then
        return nil, "No player called '" .. name .. "' in this server."
    end
    return { userId = found.UserId }
end
-- Invokes OwnerPanel.Action and prints the server's (ok, message) reply.
local function sendAction(action, args)
    local ok, success, message = pcall(function()
        return actionRemote:InvokeServer(action, args)
    end)
    if not ok then
        printLine("✖ " .. tostring(success), RED)
        return
    end
    printLine(
        (success and "✔ " or "✖ ") .. tostring(message or (success and "Done." or "Failed.")),
        success and GREEN or RED
    )
end
local EVENTS =
    { rush = "rush", eggrush = "rush", cash = "cash", doublecash = "cash", gold = "gold", goldenhour = "gold" }
-- Shallow copy of base with extra's fields on top.
local function withFields(base, extra)
    base = table.clone(base)
    for key, value in extra do
        base[key] = value
    end
    return base
end

-- ===== 4. Command table =====
-- Commands (prefix ; : / ! or none). Each callback gets (args, rest) where rest is the raw text after the name.
local SocialService = game:GetService("SocialService")
local COMMANDS, COMMAND_ORDER = {}, {}
local function defineCommand(names, usage, desc, fn)
    local def = { names = names, usage = usage, desc = desc, fn = fn }
    for _, alias in names do
        COMMANDS[alias] = def
    end
    table.insert(COMMAND_ORDER, def)
end
-- Prints err when value is missing; returns value.
local function need(value, err)
    if not value then
        printLine("✖ " .. err, RED)
    end
    return value
end
local function targetOrError(name)
    local targetArgs, err = buildTarget(name)
    if not targetArgs then
        printLine("✖ " .. err, RED)
    end
    return targetArgs
end
local GIVE_TYPES =
    { cash = "cash", money = "cash", egg = "egg", eggs = "egg", char = "char", character = "char", pet = "char" }
local function give(kind, whoName, value, mutation)
    local targetArgs = targetOrError(whoName)
    if not targetArgs then
        return
    end
    if kind == "cash" then
        local amount = need(tonumber(value), "Amount needed: ;cash <who> <amount>")
        if amount then
            sendAction("GiveCash", withFields(targetArgs, { amount = amount, confirmed = true }))
        end
    elseif kind == "egg" then
        if need(value, "Egg needed: ;egg <who> <EggId> [mutation]") then
            sendAction("GiveEgg", withFields(targetArgs, { itemId = value, mutation = mutation, confirmed = true }))
        end
    else
        if need(value, "Character needed: ;char <who> <Id> [mutation]") then
            sendAction(
                "GiveCharacter",
                withFields(targetArgs, { itemId = value, mutation = mutation, confirmed = true })
            )
        end
    end
end

defineCommand({ "help", "cmds", "commands", "?" }, "/help [command]", "list commands", function(args)
    local definition = args[1] and COMMANDS[args[1]:lower()]
    if definition then
        printLine("  " .. definition.usage .. "   — " .. definition.desc, GOLD)
        printLine("  aliases: " .. table.concat(definition.names, ", "), DIM)
        return
    end
    for _, command in COMMAND_ORDER do
        printLine(string.format("  %-40s %s", command.usage, command.desc), DIM)
    end
    printLine("  who = @name · me · all      Tab completes names      ↑/↓ history", CYAN)
end)
defineCommand({ "players", "plrs", "list" }, "/players", "everyone in this server", function()
    for _, other in Players:GetPlayers() do
        printLine(string.format("  @%-20s %-18s %d", other.Name, other.DisplayName, other.UserId), WHITE)
    end
end)
defineCommand(
    { "invite", "inv" },
    "/invite [username]",
    "invite a friend (or get the game link for anyone)",
    function(args)
        local name = args[1] and args[1]:gsub("^@", "")
        if not name then
            local ok, can = pcall(SocialService.CanSendGameInviteAsync, SocialService, player)
            if ok and can then
                SocialService:PromptGameInvite(player)
                printLine("✔ Invite window opened.", GREEN)
            else
                printLine("✖ Invites aren't available here (works in the live game).", RED)
            end
            return
        end
        local okId, id = pcall(Players.GetUserIdFromNameAsync, Players, name)
        if not okId or not id then
            printLine("✖ No Roblox user called '" .. name .. "'.", RED)
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
                printLine("✔ Invite sent to @" .. name .. " — they get a Roblox notification.", GREEN)
            else
                printLine("✖ Roblox won't let you invite @" .. name .. " right now (their settings, or Studio).", RED)
            end
        else
            printLine(
                "✖ @" .. name .. " isn't on your friends list — Roblox only allows game invites to friends.",
                RED
            )
            printLine("  Send them this link instead (they'll join a public server):", DIM)
            printLine("  https://www.roblox.com/games/" .. game.PlaceId, GOLD)
            printLine("  Or friend them first, then /invite " .. name .. " again.", DIM)
        end
    end
)
defineCommand({ "link" }, "/link", "the game link to send to anyone", function()
    printLine("  https://www.roblox.com/games/" .. game.PlaceId, GOLD)
end)
defineCommand({ "give" }, "/give <who> <cash|egg|char> <amount|Id> [mutation]", "give anything", function(args)
    local firstKind, secondKind = GIVE_TYPES[(args[1] or ""):lower()], GIVE_TYPES[(args[2] or ""):lower()]
    if firstKind then
        give(firstKind, args[2], args[3], args[4])
    elseif secondKind then
        give(secondKind, args[1], args[3], args[4])
    else
        printLine("✖ ;give <who> <cash|egg|char> ...", RED)
    end
end)
defineCommand({ "cash", "money" }, "/cash <who> <amount>", "give cash", function(args)
    give("cash", args[1], args[2])
end)
defineCommand({ "setcash" }, "/setcash <who> <amount>", "set a player's cash exactly", function(args)
    local targetArgs = targetOrError(args[1])
    local amount = tonumber(args[2])
    if targetArgs and need(amount, "/setcash <who> <amount>") then
        sendAction("SetCash", withFields(targetArgs, { amount = amount, confirmed = true }))
    end
end)
defineCommand({ "egg" }, "/egg <who> <EggId> [mutation]", "give an egg (e.g. ;egg me Pirate Gold)", function(args)
    give("egg", args[1], args[2], args[3])
end)
defineCommand({ "char", "character" }, "/char <who> <Id> [mutation]", "give a character", function(args)
    give("char", args[1], args[2], args[3])
end)
defineCommand({ "riveregg", "spawn", "drop" }, "/riveregg <EggId>", "drop an egg on the river", function(args)
    sendAction("SpawnEgg", { scope = "me", itemId = args[1] })
end)
defineCommand({ "event", "ev" }, "/event <rush|cash|gold|stop> [minutes]", "start / stop a live event", function(args)
    local eventName = (args[1] or ""):lower()
    if eventName == "stop" or eventName == "end" then
        sendAction("StopEvent", { scope = "me" })
        return
    end
    local eventId = EVENTS[eventName]
    if not eventId then
        printLine("✖ ;event <rush|cash|gold|stop> [minutes]", RED)
        return
    end
    sendAction("StartEvent", { scope = "me", eventId = eventId, seconds = math.floor((tonumber(args[2]) or 10) * 60) })
end)
defineCommand({ "stopevent", "endevent" }, "/stopevent", "end the current event", function()
    sendAction("StopEvent", { scope = "me" })
end)
defineCommand({ "night" }, "/night", "force night", function()
    sendAction("StartNight", { scope = "me" })
end)
defineCommand({ "day" }, "/day", "back to day", function()
    sendAction("StopNight", { scope = "me" })
end)
defineCommand({ "shower", "eggshower" }, "/shower", "egg shower", function()
    sendAction("EggShower", { scope = "me" })
end)
defineCommand({ "spawnrate", "rate" }, "/spawnrate <seconds>", "river egg spawn interval (1.5–30)", function(args)
    sendAction("SetSpawnInterval", { scope = "me", seconds = tonumber(args[1]) })
end)
defineCommand({ "announce", "ann", "a", "m" }, "/announce <text>", "banner in this server", function(_, rest)
    sendAction("Announce", { text = rest, color = "pink" })
end)
defineCommand({ "gannounce", "ga", "global", "sm" }, "/global <text>", "banner in EVERY server", function(_, rest)
    sendAction("Announce", { text = rest, allServers = true, color = "purple" })
end)
defineCommand({ "update", "shutdown" }, "/update [text]", "update countdown + rejoin all servers", function(_, rest)
    sendAction("AnnounceUpdate", { text = rest ~= "" and rest or nil })
end)
local function onPlayer(action, extra)
    return function(args)
        local found = findPlayer(args[1])
        if not found then
            printLine("✖ No player '" .. tostring(args[1]) .. "'", RED)
            return
        end
        sendAction(action, withFields({ userId = found.UserId, confirmed = true }, extra or {}))
    end
end
defineCommand({ "kick" }, "/kick <who>", "kick a player", onPlayer("Kick"))
defineCommand({ "ban" }, "/ban <who>", "ban for 24 h", onPlayer("Ban"))
defineCommand({ "unban" }, "/unban <userId>", "lift a ban", function(args)
    sendAction("Unban", { userId = tonumber(args[1]) })
end)
defineCommand({ "bring" }, "/bring <who>", "teleport them to you", onPlayer("Bring"))
defineCommand({ "goto", "tp", "to" }, "/tp <who>", "teleport to them", onPlayer("GoTo"))
defineCommand({ "home", "base" }, "/home <who>", "send them to their temple", onPlayer("SendHome"))
defineCommand({ "respawn", "re", "refresh" }, "/respawn <who>", "respawn a player", onPlayer("Respawn"))
local function onTarget(action)
    return function(args)
        local targetArgs = targetOrError(args[1] or "me")
        if targetArgs then
            sendAction(action, withFields(targetArgs, { confirmed = true }))
        end
    end
end
defineCommand({ "unlock", "slot" }, "/unlock <who>", "unlock their next slot", onTarget("UnlockSlot"))
defineCommand({ "temple", "upgrade" }, "/temple <who>", "upgrade their temple", onTarget("UpgradeTemple"))
defineCommand({ "addinc", "incubator" }, "/addinc <who>", "give them another incubator", onTarget("AddIncubator"))
defineCommand({ "upinc" }, "/upinc <who>", "upgrade their first incubator", function(args)
    local targetArgs = targetOrError(args[1] or "me")
    if targetArgs then
        sendAction("UpgradeIncubator", withFields(targetArgs, { index = tonumber(args[2]) or 1, confirmed = true }))
    end
end)
defineCommand({ "clearinv" }, "/clearinv <who>", "clear their backpack", onTarget("ClearInventory"))
defineCommand({ "clearplaced" }, "/clearplaced <who>", "clear their placed characters", onTarget("ClearPlaced"))
defineCommand({ "resetslots" }, "/resetslots <who>", "reset their slots", onTarget("ResetSlots"))
defineCommand({ "staff" }, "/staff", "go to the private staff server", function()
    sendAction("JoinStaffServer", {})
end)
defineCommand({ "public" }, "/public", "back to a public server", function()
    sendAction("ReturnToPublic", {})
end)
defineCommand({ "admin" }, "/admin <add|remove> <userId|@name>", "owner: share the terminal", function(args)
    local userId = tonumber(args[2])
    if not userId and args[2] then
        local found = findPlayer(args[2])
        userId = found and found.UserId
    end
    if not need(userId, "/admin add <userId|@name>") then
        return
    end
    sendAction("SetAdmin", { userId = userId, on = (args[1] or ""):lower() ~= "remove" })
end)
defineCommand(
    { "setfreecam", "freecam" },
    "/setfreecam <add|remove> <userId|@name>",
    "owner: give freecam only (Shift + P)",
    function(args)
        local userId = tonumber(args[2])
        if not userId and args[2] then
            local found = findPlayer(args[2])
            userId = found and found.UserId
        end
        if not need(userId, "/setfreecam add <userId|@name>") then
            return
        end
        sendAction("SetFreecam", { userId = userId, on = (args[1] or ""):lower() ~= "remove" })
    end
)
defineCommand({ "clear", "cls" }, "/clear", "clear this window", function()
    for _, child in logFrame:GetChildren() do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end)

-- ===== 5. Parsing and running =====
-- "/give me cash 5" -> "give", { "me", "cash", "5" }, "me cash 5"
local function parse(line)
    local body = line:gsub("^%s*[;:/!]", "")
    local name, rest = body:match("^%s*(%S+)%s*(.*)$")
    local args = {}
    for word in (rest or ""):gmatch("%S+") do
        table.insert(args, word)
    end
    return (name or ""):lower(), args, rest or ""
end
local function run(line)
    local name, args, rest = parse(line)
    if name == "" then
        return
    end
    printLine("❯ " .. line, CYAN)
    local definition = COMMANDS[name]
    if not definition then
        printLine("✖ Unknown command '" .. name .. "'. Try /help", RED)
        return
    end
    local ok, err = pcall(definition.fn, args, rest)
    if not ok then
        printLine("✖ " .. tostring(err), RED)
    end
end

-- ===== 6. Suggestions, Tab completion and history =====
-- suggestions under the input
local suggestionFrame = make("Frame", {
    AnchorPoint = Vector2.new(0, 1),
    Position = UDim2.new(0, 12, 1, -50),
    Size = UDim2.new(1, -24, 0, 0),
    AutomaticSize = Enum.AutomaticSize.Y,
    BackgroundColor3 = Color3.fromRGB(16, 20, 32),
    BackgroundTransparency = 0.05,
    Visible = false,
    ZIndex = 5,
}, window)
make("UICorner", { CornerRadius = UDim.new(0, 8) }, suggestionFrame)
make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, suggestionFrame)
make(
    "UIPadding",
    { PaddingLeft = UDim.new(0, 10), PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 4) },
    suggestionFrame
)
local firstMatch
local function refreshSuggestions()
    for _, child in suggestionFrame:GetChildren() do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
    firstMatch = nil
    local text = inputBox.Text
    local name = text:gsub("^%s*[;:/!]", ""):match("^(%S*)$")
    if not name or name == "" then
        suggestionFrame.Visible = false
        return
    end
    local shownCount = 0
    for _, definition in COMMAND_ORDER do
        for _, alias in definition.names do
            if alias:sub(1, #name) == name:lower() then
                shownCount += 1
                firstMatch = firstMatch or alias
                make("TextLabel", {
                    LayoutOrder = shownCount,
                    BackgroundTransparency = 1,
                    Size = UDim2.new(1, 0, 0, 20),
                    Text = definition.usage .. "   " .. definition.desc,
                    FontFace = MONO,
                    TextSize = 14,
                    TextColor3 = shownCount == 1 and GOLD or DIM,
                    TextXAlignment = Enum.TextXAlignment.Left,
                    ZIndex = 6,
                }, suggestionFrame)
                break
            end
        end
        if shownCount >= 6 then
            break
        end
    end
    suggestionFrame.Visible = shownCount > 0
end
inputBox:GetPropertyChangedSignal("Text"):Connect(refreshSuggestions)
local function tabComplete()
    local text = inputBox.Text
    if text:gsub("^%s*[;:/!]", ""):match("^%S*$") then
        if firstMatch then
            local prefix = text:match("^%s*([;:/!]?)") or ";"
            inputBox.Text = (prefix ~= "" and prefix or "/") .. firstMatch .. " "
        end
    else
        local head, lastWord = text:match("^(.-)(%S*)$")
        if lastWord ~= "" then
            local partial = lastWord:lower():gsub("^@", "")
            for _, candidate in Players:GetPlayers() do
                if
                    candidate.Name:lower():sub(1, #partial) == partial
                    or candidate.DisplayName:lower():sub(1, #partial) == partial
                then
                    inputBox.Text = head .. candidate.Name .. " "
                    break
                end
            end
        end
    end
    inputBox.CursorPosition = #inputBox.Text + 1
end

local history, historyIndex = {}, 0
inputBox.FocusLost:Connect(function(enterPressed)
    if not enterPressed then
        return
    end
    local line = inputBox.Text
    inputBox.Text = ""
    if line:gsub("%s", "") ~= "" then
        table.insert(history, line)
        historyIndex = #history + 1
        task.spawn(run, line)
    end
    task.defer(function()
        inputBox:CaptureFocus()
    end)
end)

-- ===== 7. Open / close, keys and chat command =====
local function toggle()
    gui.Enabled = not gui.Enabled
    if gui.Enabled then
        window.Size = UDim2.fromOffset(720, 0)
        TweenService:Create(window, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Size = UDim2.fromOffset(720, 400) })
            :Play()
        task.defer(function()
            inputBox:CaptureFocus()
        end)
    end
end
UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if input.KeyCode == Enum.KeyCode.F2 or (input.KeyCode == Enum.KeyCode.Backquote and not gameProcessed) then
        toggle()
        return
    end
    if not (gui.Enabled and inputBox:IsFocused()) then
        return
    end
    if input.KeyCode == Enum.KeyCode.Tab then
        task.defer(function()
            inputBox.Text = inputBox.Text:gsub("\t", "")
            tabComplete()
        end)
        return
    end
    if #history > 0 then
        if input.KeyCode == Enum.KeyCode.Up then
            historyIndex = math.max(1, historyIndex - 1)
            inputBox.Text = history[historyIndex] or ""
            inputBox.CursorPosition = #inputBox.Text + 1
        elseif input.KeyCode == Enum.KeyCode.Down then
            historyIndex = math.min(#history + 1, historyIndex + 1)
            inputBox.Text = history[historyIndex] or ""
            inputBox.CursorPosition = #inputBox.Text + 1
        end
    end
end)
do
    local command = Instance.new("TextChatCommand")
    command.Name = "OpenTerminal"
    command.PrimaryAlias = "/terminal"
    command.SecondaryAlias = "/t"
    command.Parent = TextChatService
    command.Triggered:Connect(function(source)
        if source.UserId == player.UserId then
            toggle()
        end
    end)
end
printLine("Velm terminal ready. Type /help  (Tab completes, ↑/↓ history)", GREEN)
