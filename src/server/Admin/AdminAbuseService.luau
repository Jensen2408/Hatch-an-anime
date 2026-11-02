--[[ ServerScriptService.AdminAbuseService  (ModuleScript, server only)
Admin abuses: timed boosts that run in every server of the game at once. Kinds and limits: AdminAbuseConfig.

Commands (Service.RunCommand), from the admin terminal (OwnerPanel action "AdminAbuse") or the /abuse chat command:
  /abuse <hatch|cash|legendary> <x> <minutes>   start, or replace the running one of that kind
  /abuse stop [hatch|cash|legendary]            stop one, or all of them
  /abuse list                                   what is running
Who is authorized: AdminRoles.Can(player, "AdminAbuse"), checked by both entry points.

Across servers: MemoryStore hash map "AdminAbuse_v1" holds the running abuses (each key expires with its abuse), so a
server that starts later catches up. A MessagingService message on topic "AdminAbuse_v1" applies a change at once; every
server also re-reads the map each REFRESH_SECONDS, which covers a lost message. Studio uses its own map and topic, so a
playtest can never boost the live servers.

Replicated output: workspace attributes Abuse<Kind>Multiplier / Abuse<Kind>EndsAt (read by the income loop, HatchGoo,
RiverEggSpawnScheduler, the potion row and the rain) and an OwnerPanel.Announcement banner for each new abuse.
]]
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local AdminRoles = require(script.Parent:WaitForChild("AdminRoles"))
local Config = require(ReplicatedStorage:WaitForChild("AdminAbuseConfig"))

local REFRESH_SECONDS = 20
local STORE_NAME = RunService:IsStudio() and "AdminAbuse_v1_Studio" or "AdminAbuse_v1"
local KIND_WORDS = {
    hatch = "Hatch",
    cash = "Cash",
    money = "Cash",
    legendary = "Legendary",
    legend = "Legendary",
    leg = "Legendary",
}
local USAGE = "/abuse <hatch|cash|legendary> <x> <minutes>  ·  /abuse stop [kind]  ·  /abuse list"

local announceEvent = ReplicatedStorage:WaitForChild("OwnerPanel"):WaitForChild("Announcement")
local store = MemoryStoreService:GetHashMap(STORE_NAME)
local active = {} -- [kind] = { Value, EndsAt (server time), By }

local Service = {}

local function minutesWord(minutes)
    return minutes .. (minutes == 1 and " minute" or " minutes")
end

-- Makes this server match `state` (nil = off). A new or changed abuse gets its banner here, so it shows on every
-- server however the change arrived.
local function apply(kind, state)
    local now = workspace:GetServerTimeNow()
    if state and state.EndsAt <= now then
        state = nil
    end
    local previous = active[kind]
    active[kind] = state
    workspace:SetAttribute("Abuse" .. kind .. "Multiplier", state and state.Value or nil)
    workspace:SetAttribute("Abuse" .. kind .. "EndsAt", state and state.EndsAt or nil)
    if state and not (previous and previous.Value == state.Value and previous.EndsAt == state.EndsAt) then
        announceEvent:FireAllClients({
            title = "ADMIN ABUSE!",
            text = string.format(
                "x%d %s for %s!",
                state.Value,
                Config.Kinds[kind].Name,
                minutesWord(math.max(1, math.round((state.EndsAt - now) / 60)))
            ),
            color = "gold",
            by = state.By,
        })
    end
end

local function publish(kind, state)
    return pcall(function()
        MessagingService:PublishAsync(STORE_NAME, { Kind = kind, State = state })
    end)
end

-- A read that fails leaves this server as it is. A running abuse is never ended by a store outage, only by its timer.
local function refresh()
    for _, kind in Config.Order do
        local ok, state = pcall(store.GetAsync, store, kind)
        if ok then
            apply(kind, state)
        end
    end
end

local function start(kind, value, minutes, byName)
    local definition = Config.Kinds[kind]
    if not value or value % 1 ~= 0 or value < definition.Min or value > definition.Max then
        return false, string.format("%s goes from x%d to x%d.", definition.Name, definition.Min, definition.Max)
    end
    if not minutes or minutes % 1 ~= 0 or minutes < 1 or minutes > Config.MaxMinutes then
        return false, "Minutes must be a whole number from 1 to " .. Config.MaxMinutes .. "."
    end
    local seconds = minutes * 60
    -- whole seconds: EndsAt must survive the trip through JSON unchanged, apply() compares it
    local state = { Value = value, EndsAt = math.ceil(workspace:GetServerTimeNow()) + seconds, By = byName }
    local stored = pcall(store.SetAsync, store, kind, state, seconds)
    if not stored and not RunService:IsStudio() then
        return false, "Couldn't reach the other servers. Nothing started; try again."
    end
    apply(kind, state)
    local published = publish(kind, state)
    return true,
        string.format("x%d %s for %s", value, definition.Name, minutesWord(minutes))
            .. ((stored and published) and " in every server." or " in this server only (no cross-server here)."),
        true
end

local function stop(kind)
    local failed = false
    for _, stopKind in kind and { kind } or Config.Order do
        if active[stopKind] then
            if not pcall(store.RemoveAsync, store, stopKind) then
                failed = true
            end
            apply(stopKind, nil)
            publish(stopKind, nil)
        end
    end
    -- the store keeps the abuse, so the next refresh would bring it back here until it expires
    if failed and not RunService:IsStudio() then
        return false, "Couldn't reach the other servers; the abuse will come back. Try again."
    end
    return true, (kind and Config.Kinds[kind].Name or "All abuses") .. " stopped."
end

local function list()
    local lines = {}
    local now = workspace:GetServerTimeNow()
    for _, kind in Config.Order do
        local state = active[kind]
        if state then
            local left = math.max(0, math.ceil(state.EndsAt - now))
            table.insert(
                lines,
                string.format("%s x%d (%d:%02d left)", Config.Kinds[kind].Name, state.Value, left // 60, left % 60)
            )
        end
    end
    return true, #lines > 0 and table.concat(lines, "  ·  ") or "No abuse running."
end

-- text = everything after "/abuse". Returns (ok, message, started).
function Service.RunCommand(byName, text)
    local words = {}
    for word in tostring(text):lower():gmatch("%S+") do
        table.insert(words, word)
    end
    local first = words[1]
    if first == "list" then
        return list()
    end
    if first == "stop" or first == "end" then
        local kind = KIND_WORDS[words[2] or ""]
        if words[2] and words[2] ~= "all" and not kind then
            return false, USAGE
        end
        return stop(kind)
    end
    local kind = KIND_WORDS[first or ""]
    if not kind then
        return false, USAGE
    end
    return start(kind, tonumber((words[2] or ""):match("^x?(%d+%.?%d*)$")), tonumber(words[3]), byName)
end

-- ===== Chat command =====
local command = TextChatService:FindFirstChild("AdminAbuseCommand") or Instance.new("TextChatCommand")
command.Name = "AdminAbuseCommand"
command.PrimaryAlias = "/abuse"
command.Parent = TextChatService
command.Triggered:Connect(function(source, text)
    local player = source and Players:GetPlayerByUserId(source.UserId)
    if not player or not AdminRoles.Can(player, "AdminAbuse") then
        return
    end
    local words = tostring(text):gsub("^%s*/%S+%s*", "")
    local ok, message, started = Service.RunCommand(player.DisplayName, words)
    if not started then -- a new abuse already has its banner
        announceEvent:FireClient(player, { title = "ADMIN ABUSE", text = message, color = ok and "green" or "red" })
    end
end)

-- ===== Other servers =====
task.spawn(function()
    local ok, err = pcall(function()
        return MessagingService:SubscribeAsync(STORE_NAME, function(message)
            local data = message.Data
            if type(data) == "table" and Config.Kinds[data.Kind] then
                apply(data.Kind, data.State)
            end
        end)
    end)
    if not ok then
        warn("[AdminAbuseService] MessagingService subscribe unavailable:", err)
    end
end)

task.spawn(function()
    local nextRefresh = 0
    while true do
        local now = workspace:GetServerTimeNow()
        if now >= nextRefresh then
            nextRefresh = now + REFRESH_SECONDS
            refresh()
        end
        for kind, state in active do
            if now >= state.EndsAt then
                apply(kind, nil)
            end
        end
        task.wait(1)
    end
end)

return Service
