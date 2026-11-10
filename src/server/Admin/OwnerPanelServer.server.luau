--[[ ServerScriptService.OwnerPanelServer  (Script)
Server side of the owner / admin panel (StudPanel UI) and the admin terminal.

Remotes (created here if missing; names and payload shapes are contracts)
  ReplicatedStorage.OwnerPanel.Action        RemoteFunction: InvokeServer(action: string, args: table) -> (ok, result)
  ReplicatedStorage.OwnerPanel.Announcement  RemoteEvent, server -> clients: banner payloads (see StaffAnnouncements)
  ReplicatedStorage.OwnerPanelOpen           RemoteEvent, server -> client: open the panel (/admin chat command)

Who is authorized (checked on every invoke, in this order)
  1. AdminRoles.Role(player) must be "Owner" or "Admin", else "Staff access only."
  2. AdminRoles.Can(player, action) (owner: all, admin: AdminRoles.AdminActions); SetAdmin additionally owner-only.
  3. Owner-only handlers (SaveList, SaveRestore, TakeCash, WipePlayer) re-check role == "Owner" themselves.
  4. Mapped actions go through OwnerControlServer's Dispatch bindable, which checks again (owner, or ADMIN_BRIDGE).
Trusted input: action must be a string and args a table; individual args fields are validated by the handlers / the
dispatcher. args.color (announcements) is passed through unvalidated; clients fall back to red for unknown colours.
Rate limit: one request per player at a time, >= 0.2 s apart. Errors are caught and returned as (false, message).
]]
-- ===== 1. Services and remotes =====
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")

local folder = ReplicatedStorage:FindFirstChild("OwnerPanel") or Instance.new("Folder")
folder.Name = "OwnerPanel"
folder.Parent = ReplicatedStorage
local actionRemote = folder:FindFirstChild("Action") or Instance.new("RemoteFunction")
actionRemote.Name = "Action"
actionRemote.Parent = folder
local announceEvent = folder:FindFirstChild("Announcement") or Instance.new("RemoteEvent")
announceEvent.Name = "Announcement"
announceEvent.Parent = folder
local openEvent = ReplicatedStorage:FindFirstChild("OwnerPanelOpen") or Instance.new("RemoteEvent")
openEvent.Name = "OwnerPanelOpen"
openEvent.Parent = ReplicatedStorage

-- ===== 2. Dependencies, action tables and state =====
local AdminRoles = require(script.Parent:WaitForChild("AdminRoles"))
local StaffServerService = require(script.Parent:WaitForChild("StaffServerService"))
local CrossServerService = require(script.Parent:WaitForChild("CrossServerService"))
local AdminAbuseService = require(script.Parent:WaitForChild("AdminAbuseService"))
local Catalog = require(ReplicatedStorage:WaitForChild("CharacterCatalog"))
local HighTideService = require(script.Parent:WaitForChild("HighTideService"))
local BoostService = require(script.Parent:WaitForChild("BoostService"))
local RiverWaves = require(ReplicatedStorage:WaitForChild("WaterfallRiver"):WaitForChild("RiverWaves"))
local bridge = game.ServerScriptService:WaitForChild("OwnerControlServer"):WaitForChild("Dispatch")
local lastRequestAt, busy = {}, {}
-- Panel action name -> OwnerControlServer dispatch action name.
local PANEL_TO_DISPATCH_ACTION = {
    GiveCash = "GiveCash",
    SetCash = "SetCash",
    GiveEgg = "SpawnEgg",
    GiveCharacter = "SpawnCharacter",
    SpawnEgg = "SpawnRiverEgg",
    UpgradeTemple = "UpgradeTemple",
    UnlockSlot = "UnlockNextSlot",
    AddIncubator = "AddChamber",
    UpgradeIncubator = "UpgradeChamber",
    ClearInventory = "ClearInventory",
    ClearPlaced = "ClearPlaced",
    ResetSlots = "ResetSlots",
    StartEvent = "StartEvent",
    StopEvent = "StopEvent",
    SetSpawnInterval = "SetSpawnInterval",
    SendHome = "GoHome",
    Bring = "Bring",
    GoTo = "TeleportTo",
    SendToPlayer = "SendToPlayer",
    Respawn = "Respawn",
    Kick = "Kick",
    Ban = "Ban24h",
    Unban = "Unban",
}
-- Panel actions that require args.confirmed == true.
local NEEDS_CONFIRM = {
    SetCash = true,
    ClearInventory = true,
    ClearPlaced = true,
    ResetSlots = true,
    Respawn = true,
    Kick = true,
    Ban = true,
    Unban = true,
}
-- Panel actions that can never target the whole lobby.
local SINGLE_TARGET_ONLY = {
    SetCash = true,
    UpgradeTemple = true,
    UnlockSlot = true,
    AddIncubator = true,
    UpgradeIncubator = true,
    ClearInventory = true,
    ClearPlaced = true,
    ResetSlots = true,
    SendHome = true,
    Bring = true,
    GoTo = true,
    SendToPlayer = true,
    Respawn = true,
    Kick = true,
    Ban = true,
    Unban = true,
}
local lastShower, lastAnnounce = -1e9, {}

-- ===== 3. Helpers =====
-- Temple level / unlocked slot count / incubator levels for the roster (nil when the player has no plot).
local function plotSummary(player)
    for _, plot in workspace.Plots:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            local slots = 0
            for _, slot in plot.Slots:GetChildren() do
                if slot:GetAttribute("Unlocked") then
                    slots += 1
                end
            end
            local chambers = {}
            for i = 1, 3 do
                local chamber = plot.Chambers:FindFirstChild("Chamber" .. i)
                if chamber then
                    chambers[i] = chamber:GetAttribute("UpgradeLevel") or 1
                end
            end
            return {
                level = plot:GetAttribute("TempleLevel") or 1,
                slots = slots,
                incubators = chambers,
                building = plot:GetAttribute("TempleBuilding") == true,
            }
        end
    end
end
local function releasableEggs()
    local eggs = {}
    for _, entry in ipairs(Catalog.Eggs) do
        local template = game.ServerStorage.AuxEggTemplates:FindFirstChild(entry.Id)
        if template and template:GetAttribute("ReleaseEnabled") ~= false then
            table.insert(eggs, entry)
        end
    end
    return eggs
end

-- ===== 4. Direct handlers: handlers[action](player, args, role) -> (ok, result) =====
local handlers = {}
local SaveRestore = require(script.Parent:WaitForChild("SaveRestore"))
handlers.SaveList = function(_player, args, role)
    if role ~= "Owner" then
        return false, "Only the owner can do that."
    end
    return true, SaveRestore.List(args.who)
end
handlers.SaveRestore = function(_player, args, role)
    if role ~= "Owner" then
        return false, "Only the owner can do that."
    end
    if args.confirmed ~= true then
        return false, "Confirm first."
    end
    return true, SaveRestore.Restore(args.who, args.version)
end
local PlayerPunish = require(script.Parent:WaitForChild("PlayerPunish"))
handlers.TakeCash = function(player, args, role)
    if role ~= "Owner" then
        return false, "Only the owner can do that."
    end
    if args.confirmed ~= true then
        return false, "Confirm first."
    end
    return true, PlayerPunish.TakeCash(player, args.who, args.amount)
end
handlers.WipePlayer = function(player, args, role)
    if role ~= "Owner" then
        return false, "Only the owner can do that."
    end
    if args.confirmed ~= true then
        return false, "Confirm first."
    end
    return true, PlayerPunish.Wipe(player, args.who)
end
local liveEventStates
-- Every event's live state for the panel's Events page (2026-11-08): { [id] = { on = bool, ends = serverTime? } }
-- plus boosts = { [target] = { x, ends } }. Events run on their own, so several can be on at once.
liveEventStates = function()
    local now = workspace:GetServerTimeNow()
    local function attr(name)
        return workspace:GetAttribute(name)
    end
    local states = {}
    for id, kind in { rush = "EggRush", cash = "DoubleCash", gold = "GoldenHour" } do
        local ends = attr("OwnerEvent_" .. kind .. "Ends")
        states[id] = { on = ends ~= nil and ends > now, ends = ends }
    end
    states.boss = { on = attr("BossActive") == true, ends = attr("BossEndsAt"), next = attr("BossNextAt") }
    local arenaPhase = attr("ArenaPhase")
    states.arena = { on = arenaPhase ~= nil and arenaPhase ~= "Idle" and arenaPhase ~= "Ended", ends = attr("ArenaEndsAt"), phase = arenaPhase, next = attr("ArenaNextAt") }
    local volcanoStart = attr("VolcanoStart")
    states.volcano = { on = volcanoStart ~= nil, ends = volcanoStart and volcanoStart + 150 or nil, next = attr("VolcanoNextAt") }
    states.night = { on = attr("NighttimeActive") == true, ends = attr("NighttimeEndsAt"), next = attr("NighttimeNextAt"), forced = (attr("NightForcedUntil") or 0) > now }
    states.rapids = { on = attr("HighTideActive") == true, ends = attr("HighTideEndsAt"), next = attr("HighTideNextAt") }
    local meteor = ReplicatedStorage:FindFirstChild("MeteorEvent")
    local meteorEnds = meteor and meteor:GetAttribute("EndsAt") or 0
    states.meteor = { on = meteorEnds > now, ends = meteorEnds > now and meteorEnds or nil }
    states.boosts = {}
    for _, target in BoostService.Targets do
        local x = attr("Boost" .. target .. "Multiplier")
        if x then
            states.boosts[target] = { x = x, ends = attr("Boost" .. target .. "EndsAt") }
        end
    end
    return states
end
handlers.Snapshot = function(player, _args, role)
    local info = bridge:Invoke(player, "Info", {})
    if not info.Ok then
        return false, info.Message
    end
    local catalog = {}
    for _, item in info.Items do
        local entry = {
            id = item.Id,
            name = item.Name,
            rarity = item.Rarity,
            eggAvailable = item.EggAvailable,
            charAvailable = item.CharacterAvailable,
            noRiver = item.NoRiver == true,
            price = item.Price,
            kind = item.Kind,
            egg = item.Egg,
            order = item.Order,
            chance = item.Chance,
            income = item.Income,
            characters = item.Characters,
        }
        -- 2026-11-08: admins see the whole catalog too (owner-only items like the Golden Pirate stay owner-only)
        if role == "Owner" or not item.NoRiver then
            table.insert(catalog, entry)
        end
    end
    local roster = {}
    for _, who in Players:GetPlayers() do
        table.insert(roster, {
            userId = who.UserId,
            name = who.DisplayName,
            user = who.Name,
            role = AdminRoles.Role(who),
            plot = plotSummary(who),
        })
    end
    return true,
        {
            players = roster,
            catalog = catalog,
            event = info.Event,
            role = role,
            admins = role == "Owner" and AdminRoles.List() or nil,
            eventEnds = workspace:GetAttribute("OwnerEventEnds"),
            isStaffServer = workspace:GetAttribute("IsStaffServer") == true,
            liveEvents = liveEventStates(),
            serverTime = workspace:GetServerTimeNow(),
        }
end
handlers.EggShower = function(player, args)
    assert(os.clock() - lastShower > 20, "Egg Shower is cooling down. Try again in a few seconds.")
    local eggs = releasableEggs()
    assert(#eggs > 0, "No eggs available.")
    local request = workspace.PirateEggConveyor:FindFirstChild("RequestOwnerRiverEgg")
    assert(request, "River is not ready.")
    local eggCount = math.clamp(math.floor(tonumber(args.amount) or 8), 3, 15)
    lastShower = os.clock()
    task.spawn(function()
        for _ = 1, eggCount do
            if not player.Parent then
                break
            end
            request:Fire(player, eggs[math.random(#eggs)].Id)
            task.wait(1.1)
        end
    end)
    announceEvent:FireAllClients({
        title = "EGG SHOWER!",
        text = eggCount .. " eggs are coming down the river!",
        color = "green",
        by = player.DisplayName,
    })
    return true, eggCount .. " eggs are coming down the river."
end
handlers.StartNight = function(player, args)
    local secs = math.clamp(math.floor(tonumber(args.seconds) or 20), 10, 600)
    workspace:SetAttribute("NightForcedUntil", workspace:GetServerTimeNow() + secs)
    announceEvent:FireAllClients({
        title = "NIGHTTIME!",
        text = "Night has fallen — 3x cash, 2x hatch speed and 3x river luck! (" .. secs .. "s)",
        color = "purple",
        by = player.DisplayName,
    })
    return true, "Nighttime started for " .. secs .. " seconds."
end
handlers.StopNight = function(_player, _args)
    workspace:SetAttribute("NightForcedUntil", nil)
    return true, "Forced nighttime stopped (the regular 5-minute cycle still runs)."
end
-- River boss (BossEventService.Control); the service builds the announcement banner itself.
local function bossControl()
    local service = script.Parent:FindFirstChild("BossEventService")
    local bossBridge = service and service:FindFirstChild("Control")
    assert(bossBridge, "The boss event is not running.")
    return bossBridge
end
handlers.StartBoss = function(player, _args)
    return bossControl():Invoke("Start", player)
end
handlers.StopBoss = function(player, _args)
    return bossControl():Invoke("Stop", player)
end
-- Arena Brawl PvP event (ArenaEventService.Control); the service builds its own announcements.
local function arenaControl()
    local service = script.Parent:FindFirstChild("ArenaEventService")
    local arenaBridge = service and service:FindFirstChild("Control")
    assert(arenaBridge, "The arena event is not running.")
    return arenaBridge
end
handlers.StartArena = function(player, _args)
    return arenaControl():Invoke("Start", player)
end
handlers.StopArena = function(player, _args)
    return arenaControl():Invoke("Stop", player)
end
-- Volcano Eruption event (VolcanoEventService.Control)
local function volcanoControl()
    local service = script.Parent:FindFirstChild("VolcanoEventService")
    local volcanoBridge = service and service:FindFirstChild("Control")
    assert(volcanoBridge, "The volcano event is not running.")
    return volcanoBridge
end
handlers.StartVolcano = function(player, _args)
    return volcanoControl():Invoke("Start", player)
end
handlers.StopVolcano = function(player, _args)
    return volcanoControl():Invoke("Stop", player)
end
handlers.StartHighTide = function(player, args)
    local secs = math.clamp(math.floor(tonumber(args.seconds) or 50), 25, 600)
    local ok, message = HighTideService.Force(workspace:GetServerTimeNow(), secs)
    if not ok then
        return false, message
    end
    announceEvent:FireAllClients({
        title = "RAPIDS!",
        text = "The waterfall burst — huge waves and a flood of eggs are racing down the river! (" .. secs .. "s)",
        color = "tide",
        by = player.DisplayName,
    })
    return true, "Rapids started for " .. secs .. " seconds."
end
handlers.StopHighTide = function(_player, _args)
    HighTideService.Stop(workspace:GetServerTimeNow(), RiverWaves.TideFallTime)
    return true, "Forced rapids are receding (the regular 7-minute cycle still runs)."
end
-- Meteor Shower (MeteorEventService.Control). It needs night, so the panel brings night first when it is day.
handlers.StartMeteor = function(_player, _args)
    local service = script.Parent:FindFirstChild("MeteorEventService")
    local meteorBridge = service and service:FindFirstChild("Control")
    assert(meteorBridge, "The meteor event is not running.")
    local now = workspace:GetServerTimeNow()
    if workspace:GetAttribute("NighttimeActive") ~= true or (workspace:GetAttribute("NighttimeEndsAt") or 0) - now < 20 then
        workspace:SetAttribute("NightForcedUntil", now + 30)
        task.wait(0.4) -- NighttimeClock publishes the forced night within 0.1 s
    end
    local ok, result = meteorBridge:Invoke("Start")
    if not ok then
        return false, tostring(result)
    end
    return true, "Meteor Shower started (" .. tostring(result) .. " impact sites)."
end
handlers.StopMeteor = function(_player, _args)
    local service = script.Parent:FindFirstChild("MeteorEventService")
    local meteorBridge = service and service:FindFirstChild("Control")
    assert(meteorBridge, "The meteor event is not running.")
    meteorBridge:Invoke("Stop")
    return true, "Meteor Shower stopped."
end
-- Boost event (BoostService): any multiplier for any target, stacks with every other event.
local BOOST_TITLES = { Cash = "CASH", Luck = "LUCK", Hatch = "HATCH SPEED", Mutation = "MUTATION", RiverSpeed = "RIVER SPEED" }
handlers.StartBoost = function(player, args)
    local targets = type(args.targets) == "table" and args.targets or { args.target }
    assert(#targets > 0 and #targets <= #BoostService.Targets, "Pick what to boost.")
    local x = tonumber(args.multiplier)
    local secs = tonumber(args.seconds) or 300
    local started = {}
    for _, target in targets do
        local ok, message = BoostService.Start(target, x, secs)
        assert(ok, message)
        table.insert(started, BOOST_TITLES[target])
    end
    local shown = math.floor(x * 10 + 0.5) / 10
    announceEvent:FireAllClients({
        title = shown .. "x " .. table.concat(started, " + ") .. "!",
        text = "Boost event for " .. math.floor(secs / 60 + 0.5) .. " min — go go go!",
        color = "gold",
        by = player.DisplayName,
    })
    return true, shown .. "x " .. table.concat(started, " + ") .. " for " .. math.floor(secs / 60 + 0.5) .. " min."
end
handlers.StopBoost = function(_player, args)
    local target = type(args.target) == "string" and args.target or nil
    BoostService.Stop(target)
    return true, target and (BOOST_TITLES[target] or target) .. " boost stopped." or "All boosts stopped."
end
-- Stop everything that is running in this server (live events, boosts, forced night / rapids, boss, arena,
-- volcano, meteor). The regular schedules keep running.
handlers.StopAllEvents = function(player, _args)
    local stopped = {}
    pcall(function()
        local result = bridge:Invoke(player, "StopEvent", {})
        if result.Ok then
            table.insert(stopped, "live events")
        end
    end)
    BoostService.Stop()
    table.insert(stopped, "boosts")
    workspace:SetAttribute("NightForcedUntil", nil)
    pcall(HighTideService.Stop, workspace:GetServerTimeNow(), RiverWaves.TideFallTime)
    for _, name in { "BossEventService", "ArenaEventService", "VolcanoEventService", "MeteorEventService" } do
        local service = script.Parent:FindFirstChild(name)
        local control = service and service:FindFirstChild("Control")
        if control then
            pcall(function()
                control:Invoke("Stop", player)
            end)
        end
    end
    return true, "Stopped every event in this server."
end
handlers.Announce = function(player, args)
    local message = type(args.text) == "string" and args.text:sub(1, 120) or ""
    assert(#message:gsub("%s", "") > 0, "Write a message first.")
    assert(os.clock() - (lastAnnounce[player] or -1e9) > 8, "Wait a few seconds between announcements.")
    lastAnnounce[player] = os.clock()
    if args.allServers == true then
        return CrossServerService.GlobalAnnounce(player, message, args.color or "purple")
    else
        local ok, filtered = pcall(function()
            return TextService:FilterStringAsync(message, player.UserId, Enum.TextFilterContext.PublicChat)
                :GetNonChatStringForBroadcastAsync()
        end)
        assert(ok, "Couldn't check that message. Try again.")
        announceEvent:FireAllClients({
            title = (AdminRoles.Role(player) == "Owner" and "OWNER" or "ADMIN") .. " ANNOUNCEMENT",
            text = filtered,
            color = args.color or "red",
            by = player.DisplayName,
            byId = player.UserId,
            style = "chat",
        })
        return true, "Announcement sent to everyone in this server."
    end
end
handlers.AnnounceUpdate = function(player, args)
    local msg = type(args.text) == "string" and args.text or nil
    return CrossServerService.AnnounceUpdate(player, msg)
end
handlers.AdminAbuse = function(player, args)
    return AdminAbuseService.RunCommand(player.DisplayName, args.text)
end
handlers.SetAdmin = function(_player, args)
    local id = tonumber(args.userId)
    assert(id, "Enter a numeric User ID.")
    local name = args.name
    local who = Players:GetPlayerByUserId(id)
    if who then
        name = who.Name
    end
    if not name then
        local ok, fetchedName = pcall(Players.GetNameFromUserIdAsync, Players, id)
        name = ok and fetchedName or tostring(id)
    end
    local persisted = AdminRoles.SetAdmin(id, name, args.on == true)
    return true,
        (args.on and "@" .. name .. " is now an admin" or "@" .. name .. " is no longer an admin")
            .. (persisted and "." or " (this server only; saving works in the published game).")
end
handlers.SetFreecam = function(_player, args)
    local id = tonumber(args.userId)
    assert(id, "Enter a numeric User ID.")
    local who = Players:GetPlayerByUserId(id)
    local name = who and who.Name
    if not name then
        local ok, fetchedName = pcall(Players.GetNameFromUserIdAsync, Players, id)
        name = ok and fetchedName or tostring(id)
    end
    local persisted = AdminRoles.SetFreecam(id, name, args.on == true)
    local note = AdminRoles.Role(id) and " (staff always have freecam)" or ""
    return true,
        (args.on and "@" .. name .. " can now use freecam (Shift + P)" or "@" .. name .. " can no longer use freecam")
            .. note
            .. (persisted and "." or " (this server only; saving works in the published game).")
end
handlers.JoinStaffServer = function(player, _args, _role)
    return StaffServerService.TeleportToStaffServer(player)
end
handlers.ReturnToPublic = function(player, _args, _role)
    return StaffServerService.ReturnToPublic(player)
end

-- ===== 5. Main remote =====
local function eventAnnouncement(player, args)
    local titles = { rush = "EGG RUSH", cash = "DOUBLE CASH", gold = "GOLDEN HOUR" }
    local blurbs =
        { rush = "Eggs spawn twice as fast!", cash = "All income is doubled!", gold = "Golden sunset across the map!" }
    if titles[args.eventId] then
        announceEvent:FireAllClients({
            title = titles[args.eventId] .. " STARTED!",
            text = blurbs[args.eventId] .. " (" .. math.floor((tonumber(args.seconds) or 0) / 60) .. " min)",
            color = "gold",
            by = player.DisplayName,
        })
    end
end
actionRemote.OnServerInvoke = function(player, action, args)
    local role = AdminRoles.Role(player)
    if not role then
        return false, "Staff access only."
    end
    if type(action) ~= "string" or type(args) ~= "table" then
        return false, "Invalid request."
    end
    if not AdminRoles.Can(player, action) and action ~= "SetAdmin" then
        return false, "Only the owner can do that."
    end
    if action == "SetAdmin" and role ~= "Owner" then
        return false, "Only the owner can do that."
    end
    if busy[player] or os.clock() - (lastRequestAt[player] or -100) < 0.2 then
        return false, "Please wait a moment."
    end
    lastRequestAt[player] = os.clock()
    busy[player] = true
    local ok, success, message = pcall(function()
        -- Direct handlers first, then the dispatcher bridge for mapped actions.
        if handlers[action] then
            return handlers[action](player, args, role)
        end
        local mapped = PANEL_TO_DISPATCH_ACTION[action]
        if not mapped then
            return false, "Unknown action."
        end
        if NEEDS_CONFIRM[action] and args.confirmed ~= true then
            return false, "Confirm this action first."
        end
        -- Lobby-wide requests: owner only; then (except events, spawn rate and river eggs) they need confirmation and
        -- are never allowed for SINGLE_TARGET_ONLY actions.
        if args.scope == "lobby" and role ~= "Owner" then
            return false, "Choose one player."
        end
        if
            args.scope == "lobby"
            and action ~= "StartEvent"
            and action ~= "StopEvent"
            and action ~= "SetSpawnInterval"
            and action ~= "SpawnEgg"
            and (SINGLE_TARGET_ONLY[action] or args.confirmed ~= true)
        then
            return false, "Choose one player or confirm gifting to the lobby."
        end
        local target
        -- Resolve the dispatch Target. selene if_same_then_else (pre-existing): this branch and the scope == "me" branch
        -- are identical on purpose (lobby-wide actions always run as the caller).
        if action == "SpawnEgg" or action == "StartEvent" or action == "StopEvent" or action == "SetSpawnInterval" then
            target = tostring(player.UserId)
        elseif action == "Unban" then
            target = tostring(args.userId or "")
        elseif args.scope == "me" then
            target = tostring(player.UserId)
        elseif args.scope == "lobby" then
            target = "ALL"
        else
            local who = Players:GetPlayerByUserId(tonumber(args.userId) or 0)
            if not who then
                return false, "Select an online player first."
            end
            target = tostring(who.UserId)
        end
        -- Staff can never be kicked from the panel; admin kicks happen here (dispatch-level Kick is owner-only).
        if action == "Kick" then
            local who = Players:GetPlayerByUserId(tonumber(target) or 0)
            if not who then
                return false, "That player is not in this server."
            end
            if who == player then
                return false, "You can't kick yourself."
            end
            if AdminRoles.Role(who) then
                return false, "Staff can't be kicked from the panel."
            end
            if role == "Admin" then
                who:Kick("You were kicked by an admin.")
                return true, "Kicked @" .. who.Name .. "."
            end
        end
        local payload = {
            Target = target,
            Confirmed = args.confirmed == true,
            Amount = args.amount,
            Id = args.itemId,
            Index = args.index,
            Destination = tostring(args.destination or ""),
            Kind = ({ rush = "EggRush", cash = "DoubleCash", gold = "GoldenHour" })[args.eventId],
            Duration = args.seconds,
            Mutation = type(args.mutation) == "string" and args.mutation or nil,
        }
        if action == "SetSpawnInterval" then
            payload.Amount = args.seconds
        end
        local result = bridge:Invoke(player, mapped, payload)
        if result.Ok and action == "StartEvent" then
            eventAnnouncement(player, args)
        end
        return result.Ok, result.Message
    end)
    busy[player] = nil
    if not ok then
        warn("[StaffPanel]", action, success)
        return false, (tostring(success):gsub("^.-:%d+: ", ""))
    end
    return success, message
end
Players.PlayerRemoving:Connect(function(player)
    lastRequestAt[player] = nil
    busy[player] = nil
    lastAnnounce[player] = nil
end)

-- ===== 6. Cleanup and chat command =====
-- /admin opens the panel for any staff member (/owner still works for the owner)
local TextChatService = game:GetService("TextChatService")
local command = TextChatService:FindFirstChild("OpenStaffPanel") or Instance.new("TextChatCommand")
command.Name = "OpenStaffPanel"
command.PrimaryAlias = "/admin"
command.SecondaryAlias = ""
command.Parent = TextChatService
command.Triggered:Connect(function(source)
    local who = source and Players:GetPlayerByUserId(source.UserId)
    if who and AdminRoles.Role(who) then
        openEvent:FireClient(who)
    end
end)
