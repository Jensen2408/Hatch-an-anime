--[[ ServerScriptService.Leaderboard.LeaderboardService  (ModuleScript)
Server-authoritative rankings for the leaderboard boards.

Scores come only from the server's own state:
  • Cash     leaderstats.Cash
  • Income   sum of IncomePerSecond on the characters placed on the player's plot (Plots.*.PlacedItems)
  • Hatches  each chamber's HatchCycleCompleted BindableEvent (fires once the reveal has finished),
             counted only when the chamber sits on a plot that player owns

The client can only ASK for a ranking ("Cash", "Global"). Nothing it sends is ever stored.

GLOBAL uses one OrderedDataStore per stat. Reads are cached (Config.Server.GlobalRead) and skipped when
nobody is looking; writes happen only when a value changed, are spread out per player, and every call
checks the request budget first. Hatches use IncrementAsync so two servers never overwrite each other.

Data model (persistence contract - do not change):
  • store   OrderedDataStore "Leaderboard_<statId>_<Config.Server.StoreVersion>", plus "_Studio" in Studio
            when Config.Server.SeparateStudioStores is set
  • key     tostring(player.UserId)
  • value   non-negative integer, math.floor(math.min(value, 2^53)) (see sanitizeScore)
  • Cash / Income are written with SetAsync (latest value), Hatches with IncrementAsync (lifetime total)

Network contract: RemoteFunction Shared.<Config.RemoteName>, created by Service.Start.
  InvokeServer(statId: string, scope: "Server" | "Global") ->
    nil                                          invalid arguments
    { stat, scope, status = "busy" }             per-player token bucket empty
    { stat, scope, status, entries, total, updated, depth?, you = { r?, v? } }
  entries[i] = { r = rank, u = userId, n = username?, d = displayName?, v = value }, at most Config.MaxRows.
  status: "ok" | "loading" | "stale" (last good GLOBAL page after a failed read) | "unavailable".

Public API (also used by LeaderboardChampions and PlayerPunish): GlobalUpdated, RecordHatch, Forget,
SetGlobalCash, GetValue, GetGlobalTop, Start.
]]
-- ===== 1. Setup =====
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("Leaderboard")
local Config = require(Shared:WaitForChild("LeaderboardConfig"))
local ServerConfig = Config.Server

local Service = {}

-- Fires (statId) after every global read attempt, successful or not. Used by LeaderboardChampions.
Service.GlobalUpdated = Instance.new("BindableEvent")

local STATS = Config.StatById
local SCOPES = { Server = true, Global = true }
local MAX_VALUE = 2 ^ 53
local WRITE_REQUEST = Enum.DataStoreRequestType.SetIncrementSortedAsync
local READ_SORTED_REQUEST = Enum.DataStoreRequestType.GetSortedAsync
local READ_REQUEST = Enum.DataStoreRequestType.GetAsync

local plotsFolder = workspace:WaitForChild("Plots")

-- Never shown on any board (server or global) and never written to the global stores.
local HIDDEN_USER_IDS = {
    [168774222] = true, -- Jen1sen (owner)
}

local records = {} -- [Player] = record (see newRecord)
local serverBoards = {} -- [statId] = { entries, rankByUser, total, updated }
local globalBoards = {} -- [statId] = { status, entries, rankByUser, valueByUser, total, updated }
local nameCache = {} -- [userId] = { n = username, d = displayName, at = os.clock() }
local lastGlobalDemand = {} -- [statId] = os.clock() of the last GLOBAL request
local buckets = {} -- [Player] = { tokens, at } rate-limit bucket for the remote
local started = false

-- ===== 2. Stores and warning throttle =====
local stores = {}
local storesOk = pcall(function()
    for statId in STATS do
        local storeName = "Leaderboard_" .. statId .. "_" .. ServerConfig.StoreVersion
        if RunService:IsStudio() and ServerConfig.SeparateStudioStores then
            storeName ..= "_Studio"
        end
        stores[statId] = DataStoreService:GetOrderedDataStore(storeName)
    end
end)
if not storesOk then
    warn("[Leaderboard] OrderedDataStores unavailable; GLOBAL will show as unavailable.")
end

-- One warning per topic every 10 minutes, so a DataStore outage (or Studio without API access)
-- doesn't flood the output.
local warnedAt = {}
local function warnThrottled(topic, message)
    local now = os.clock()
    if warnedAt[topic] and now - warnedAt[topic] < 600 then
        return
    end
    warnedAt[topic] = now
    warn("[Leaderboard] " .. message)
end

-- 0 when the budget can't be read, so callers simply skip the request.
local function requestBudget(requestType)
    local ok, remaining = pcall(DataStoreService.GetRequestBudgetForRequestType, DataStoreService, requestType)
    return ok and remaining or 0
end

-- nil for non-numbers, NaN and negatives; otherwise an integer clamped to 2^53.
local function sanitizeScore(value)
    value = tonumber(value)
    if not value or value ~= value or value < 0 then
        return nil
    end
    return math.floor(math.min(value, MAX_VALUE))
end

-- ===== 3. Live values =====
local function cashOf(player)
    local stats = player:FindFirstChild("leaderstats")
    local cash = stats and stats:FindFirstChild("Cash")
    if cash and (cash:IsA("IntValue") or cash:IsA("NumberValue")) then
        return cash.Value
    end
    return nil
end

local function incomeOf(player)
    local total = 0
    for _, plot in plotsFolder:GetChildren() do
        if plot:GetAttribute("OwnerUserId") == player.UserId then
            local placed = plot:FindFirstChild("PlacedItems")
            if placed then
                for _, item in placed:GetChildren() do
                    local rate = item:GetAttribute("IncomePerSecond")
                    if type(rate) == "number" and rate == rate and rate > 0 and rate < math.huge then
                        total += rate
                    end
                end
            end
        end
    end
    if ServerConfig.IncludeIncomeMultiplier then
        total *= (tonumber(workspace:GetAttribute("OwnerIncomeMultiplier")) or 1) * (workspace:GetAttribute(
            "NightCashMultiplier"
        ) or 1)
    end
    return total
end

local function newRecord()
    return {
        values = {}, -- [statId] = latest value (number) or nil when not ready
        written = {}, -- [statId] = value last written to the global store
        nextWrite = os.clock() + ServerConfig.FirstWriteDelay + math.random() * 15,
        hatchStored = nil, -- lifetime hatches in the store (known after load / increment)
        hatchPending = 0, -- completed here, not yet written
        hatchInflight = 0, -- being written right now
        hatchState = "loading", -- loading → ready | offline
    }
end

local function hatchesOf(record)
    return (record.hatchStored or 0) + record.hatchPending + record.hatchInflight
end

-- ===== 4. Global writes =====
local function loadHatches(player, record)
    local store = stores.Hatches
    if not store then
        record.hatchState = "offline"
        return
    end
    for attempt = 1, 3 do
        if player.Parent ~= Players then
            return
        end
        if requestBudget(READ_REQUEST) > 2 then
            local ok, value = pcall(store.GetAsync, store, tostring(player.UserId))
            if ok then
                record.hatchStored = sanitizeScore(value) or 0
                record.hatchState = "ready"
                return
            end
            warnThrottled("load", "could not load hatches for " .. player.Name .. ": " .. tostring(value))
        end
        task.wait(5 * attempt)
    end
    record.hatchState = "offline" -- session hatches still count and are added with IncrementAsync later
end

-- Writes a player's changed values to the global stores. `final` (leaving / shutdown) ignores the write
-- budget and the hatch-load guard, because there is no later chance.
local function flush(player, record, final)
    if not storesOk or HIDDEN_USER_IDS[player.UserId] then
        return
    end
    local key = tostring(player.UserId)

    -- Hatches: atomic increment. Skipped while the first load is running so the two can't double count
    -- (except on leave, where only the store matters).
    if
        record.hatchPending > 0
        and (final or record.hatchState ~= "loading")
        and (final or requestBudget(WRITE_REQUEST) > ServerConfig.WriteReserve)
    then
        local delta = record.hatchPending
        record.hatchPending = 0
        record.hatchInflight = delta
        local ok, newValue = pcall(stores.Hatches.IncrementAsync, stores.Hatches, key, delta)
        record.hatchInflight = 0
        if ok then
            record.hatchStored = sanitizeScore(newValue) or ((record.hatchStored or 0) + delta)
            record.hatchState = "ready"
        else
            record.hatchPending += delta
            warnThrottled("write", "hatch write failed for " .. player.Name .. ": " .. tostring(newValue))
        end
    end

    -- Cash / Income: the current value, written only when it changed.
    for _, statId in { "Cash", "Income" } do
        local value = record.values[statId]
        local last = record.written[statId]
        if value ~= nil and value ~= last and not (last == nil and value == 0) then
            if final or requestBudget(WRITE_REQUEST) > ServerConfig.WriteReserve then
                local ok, err = pcall(stores[statId].SetAsync, stores[statId], key, value)
                if ok then
                    record.written[statId] = value
                else
                    warnThrottled("write", statId .. " write failed: " .. tostring(err))
                end
            end
        end
    end
end

-- ===== 5. THIS SERVER rankings =====
-- Rebuilds serverBoards from the live values of everyone in this server (cheap, no DataStore calls).
local function refreshServer()
    for player, record in records do
        if player.Parent ~= Players then
            continue
        end
        record.values.Cash = sanitizeScore(cashOf(player))
        record.values.Income = sanitizeScore(incomeOf(player))
        record.values.Hatches = sanitizeScore(hatchesOf(record))
    end
    local now = workspace:GetServerTimeNow()
    for statId in STATS do
        local list = {}
        for player, record in records do
            local value = record.values[statId]
            if player.Parent == Players and value and value > 0 and not HIDDEN_USER_IDS[player.UserId] then
                table.insert(list, { player = player, v = value })
            end
        end
        table.sort(list, function(left, right)
            if left.v ~= right.v then
                return left.v > right.v
            end
            return left.player.UserId < right.player.UserId
        end)
        local entries, rankByUser = {}, {}
        for i, item in list do
            rankByUser[item.player.UserId] = i
            if i <= Config.MaxRows then
                entries[i] =
                    { r = i, u = item.player.UserId, n = item.player.Name, d = item.player.DisplayName, v = item.v }
            end
        end
        serverBoards[statId] = { entries = entries, rankByUser = rankByUser, total = #list, updated = now }
    end
end

-- ===== 6. GLOBAL rankings =====
-- Fills nameCache for the given users (online players directly, others via UserService, cached 1 hour).
local function resolveNames(userIds)
    local missing = {}
    local now = os.clock()
    for _, userId in userIds do
        local onlinePlayer = Players:GetPlayerByUserId(userId)
        if onlinePlayer then
            nameCache[userId] = { n = onlinePlayer.Name, d = onlinePlayer.DisplayName, at = now }
        elseif not nameCache[userId] or now - nameCache[userId].at > 3600 then
            table.insert(missing, userId)
        end
    end
    if #missing == 0 then
        return
    end
    local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
    if ok and type(infos) == "table" then
        for _, info in infos do
            nameCache[info.Id] = { n = info.Username, d = info.DisplayName, at = now }
        end
    else
        warnThrottled("names", "name lookup failed: " .. tostring(infos))
    end
end

-- Reads the top Config.Server.GlobalFetchSize of one stat. Returns true on success; on failure keeps the
-- previous page and marks it "stale" (or "unavailable" if there never was one).
local function refreshGlobal(statId)
    local board = globalBoards[statId]
    local store = stores[statId]
    if not store then
        board.status = board.entries and "stale" or "unavailable"
        return false
    end
    if requestBudget(READ_SORTED_REQUEST) < 1 then
        return false
    end
    local ok, page = pcall(function()
        return store:GetSortedAsync(false, ServerConfig.GlobalFetchSize, 1):GetCurrentPage()
    end)
    if not ok then
        warnThrottled("read", "global " .. statId .. " read failed: " .. tostring(page))
        board.status = board.entries and "stale" or "unavailable"
        return false
    end
    local userIds = {}
    for _, item in page do
        local userId = tonumber(item.key)
        if userId then
            table.insert(userIds, userId)
        end
    end
    resolveNames(userIds)
    local entries, rankByUser, valueByUser, rank = {}, {}, {}, 0
    for _, item in page do
        local userId, value = tonumber(item.key), sanitizeScore(item.value)
        if userId and value and value > 0 and not HIDDEN_USER_IDS[userId] then
            rank += 1
            rankByUser[userId] = rank
            valueByUser[userId] = value
            if rank <= Config.MaxRows then
                local name = nameCache[userId]
                entries[rank] = { r = rank, u = userId, n = name and name.n, d = name and name.d, v = value }
            end
        end
    end
    board.status = "ok"
    board.entries, board.rankByUser, board.valueByUser = entries, rankByUser, valueByUser
    board.total = rank
    board.updated = workspace:GetServerTimeNow()
    return true
end

-- ===== 7. Remote handler =====
-- Builds the remote's reply (shape documented in the header). A GLOBAL request also marks the stat as
-- "being looked at", which keeps its periodic reads running.
local function snapshot(player, statId, scope)
    local record = records[player]
    local live = record and record.values[statId]
    if scope == "Server" then
        local board = serverBoards[statId]
        if not board then
            return { stat = statId, scope = scope, status = "loading" }
        end
        return {
            stat = statId,
            scope = scope,
            status = "ok",
            entries = board.entries,
            total = board.total,
            updated = board.updated,
            you = { r = board.rankByUser[player.UserId], v = live },
        }
    end
    lastGlobalDemand[statId] = os.clock()
    local board = globalBoards[statId]
    local rank = board.rankByUser and board.rankByUser[player.UserId]
    local you = rank and { r = rank, v = board.valueByUser[player.UserId] } or { v = live }
    return {
        stat = statId,
        scope = scope,
        status = board.status,
        entries = board.entries,
        total = board.total,
        updated = board.updated,
        depth = ServerConfig.GlobalFetchSize,
        you = you,
    }
end

-- OnServerInvoke: validates the arguments, then spends one token from the player's bucket
-- (Config.Server.RequestBurst tokens, refilled at RequestsPerSecond).
local function onInvoke(player, statId, scope)
    if type(statId) ~= "string" or not STATS[statId] or type(scope) ~= "string" or not SCOPES[scope] then
        return nil
    end
    local now = os.clock()
    local bucket = buckets[player]
    if not bucket then
        bucket = { tokens = ServerConfig.RequestBurst, at = now }
        buckets[player] = bucket
    end
    bucket.tokens =
        math.min(ServerConfig.RequestBurst, bucket.tokens + (now - bucket.at) * ServerConfig.RequestsPerSecond)
    bucket.at = now
    if bucket.tokens < 1 then
        return { stat = statId, scope = scope, status = "busy" }
    end
    bucket.tokens -= 1
    return snapshot(player, statId, scope)
end

-- ===== 8. Hatch tracking and public API =====
-- The direct child of workspace.Plots that contains `instance` (nil if it is not under Plots).
local function plotOf(instance)
    local node = instance
    while node and node.Parent ~= plotsFolder do
        node = node.Parent
    end
    return node
end

local hookedEvents = setmetatable({}, { __mode = "k" })
local function hookChamber(hatchEvent)
    if hookedEvents[hatchEvent] or hatchEvent.Name ~= "HatchCycleCompleted" or not hatchEvent:IsA("BindableEvent") then
        return
    end
    hookedEvents[hatchEvent] = true
    hatchEvent.Event:Connect(function(hatcher)
        if typeof(hatcher) ~= "Instance" or not hatcher:IsA("Player") or hatcher.Parent ~= Players then
            return
        end
        local plot = plotOf(hatchEvent)
        if not plot or plot:GetAttribute("OwnerUserId") ~= hatcher.UserId then
            return
        end
        Service.RecordHatch(hatcher)
    end)
end

-- Server-side only. Call this from other server systems if you add new ways to complete a hatch.
function Service.RecordHatch(player)
    local record = records[player]
    if record then
        record.hatchPending += 1
    end
end

-- Owner tools: remove a user from every GLOBAL board (stores + cached boards) and reset their live record.
function Service.Forget(userId)
    userId = tonumber(userId)
    if not userId then
        return false
    end
    local key, ok = tostring(userId), true
    for statId, store in stores do
        local removed = pcall(store.RemoveAsync, store, key)
        ok = ok and removed
        local board = globalBoards[statId]
        if board and board.entries then
            local keep, rankByUser, valueByUser = {}, {}, {}
            for _, entry in board.entries do
                if entry.u ~= userId then
                    table.insert(keep, entry)
                    entry.r = #keep
                    rankByUser[entry.u] = #keep
                    valueByUser[entry.u] = entry.v
                end
            end
            board.entries, board.rankByUser, board.valueByUser = keep, rankByUser, valueByUser
            board.total = #keep
        end
        Service.GlobalUpdated:Fire(statId)
    end
    for player, record in records do
        if player.UserId == userId then
            record.written = {}
            record.hatchStored = 0
            record.hatchPending = 0
        end
    end
    return ok
end

-- Owner tools: write a Cash value straight to the global board (after taking money from an offline player).
function Service.SetGlobalCash(userId, value)
    if not stores.Cash then
        return false
    end
    return (pcall(stores.Cash.SetAsync, stores.Cash, tostring(userId), sanitizeScore(value) or 0))
end

function Service.GetValue(player, statId)
    local record = records[player]
    return record and record.values[statId]
end

-- Top `count` GLOBAL entries for a stat, copied: status ("loading" | "ok" | "stale" | "unavailable"), list.
-- Calling it counts as someone looking, so the stat keeps being read while the podiums need it.
function Service.GetGlobalTop(statId, count)
    if not STATS[statId] then
        return "unavailable", {}
    end
    lastGlobalDemand[statId] = os.clock()
    local board = globalBoards[statId]
    if not board then
        return "loading", {}
    end
    -- Use the exact snapshot and rank numbers returned to the GLOBAL board.
    -- Local balances must never create a second, differently ordered global ranking.
    local list = {}
    for i = 1, math.min(math.max(0, math.floor(tonumber(count) or 3)), #(board.entries or {})) do
        list[i] = table.clone(board.entries[i])
    end
    return board.status, list
end

-- ===== 9. Lifecycle =====
local function onJoin(player)
    if records[player] then
        return
    end
    local record = newRecord()
    records[player] = record
    nameCache[player.UserId] = { n = player.Name, d = player.DisplayName, at = os.clock() }
    task.spawn(loadHatches, player, record)
end

local function onLeave(player)
    local record = records[player]
    records[player] = nil
    buckets[player] = nil
    if record then
        task.spawn(flush, player, record, true)
    end
end

function Service.Start()
    if started then
        return
    end
    started = true

    local remote = Shared:FindFirstChild(Config.RemoteName) or Instance.new("RemoteFunction")
    remote.Name = Config.RemoteName
    remote.OnServerInvoke = onInvoke
    remote.Parent = Shared

    for statId in STATS do
        globalBoards[statId] = { status = storesOk and "loading" or "unavailable" }
    end

    Players.PlayerAdded:Connect(onJoin)
    Players.PlayerRemoving:Connect(onLeave)
    for _, existingPlayer in Players:GetPlayers() do
        onJoin(existingPlayer)
    end
    -- clear any old global entries of hidden accounts (once per server start, live game only)
    if storesOk and not RunService:IsStudio() then
        task.delay(20, function()
            for statId in HIDDEN_USER_IDS do
                pcall(Service.Forget, statId)
            end
        end)
    end

    for _, descendant in plotsFolder:GetDescendants() do
        hookChamber(descendant)
    end
    plotsFolder.DescendantAdded:Connect(hookChamber)

    -- THIS SERVER: cheap rebuild from live values.
    refreshServer()
    task.spawn(function()
        while true do
            task.wait(ServerConfig.ServerRefresh)
            local ok, err = pcall(refreshServer)
            if not ok then
                warnThrottled("refresh", "server refresh: " .. tostring(err))
            end
        end
    end)

    -- GLOBAL reads: staggered, cached, skipped when nobody is looking.
    task.spawn(function()
        local nextRead = {}
        for i, stat in Config.Stats do
            nextRead[stat.Id] = os.clock() + 3 + (i - 1) * 3
        end
        while true do
            task.wait(1)
            if not storesOk then
                continue
            end
            for statId, dueAt in nextRead do
                if os.clock() < dueAt then
                    continue
                end
                local board = globalBoards[statId]
                local idle = board.entries
                    and os.clock() - (lastGlobalDemand[statId] or -math.huge) > ServerConfig.GlobalIdleAfter
                if idle then
                    nextRead[statId] = os.clock() + 5 -- re-check soon; reads resume as soon as someone looks
                else
                    local ok = refreshGlobal(statId)
                    nextRead[statId] = os.clock() + (ok and ServerConfig.GlobalRead or ServerConfig.GlobalRetry)
                    Service.GlobalUpdated:Fire(statId)
                end
            end
        end
    end)

    -- GLOBAL writes: each player at most every GlobalWrite seconds, only when something changed.
    task.spawn(function()
        while true do
            task.wait(5)
            local now, done = os.clock(), 0
            for player, record in records do
                if done >= ServerConfig.WritesPerTick then
                    break
                end
                if now >= record.nextWrite then
                    record.nextWrite = now + ServerConfig.GlobalWrite
                    done += 1
                    task.spawn(flush, player, record, false)
                end
            end
        end
    end)

    game:BindToClose(function()
        if not storesOk then
            return
        end
        local pending = 0
        for player, record in records do
            pending += 1
            task.spawn(function()
                pcall(flush, player, record, true)
                pending -= 1
            end)
        end
        local closeStartedAt = os.clock()
        while pending > 0 and os.clock() - closeStartedAt < 20 do
            task.wait(0.25)
        end
    end)
end

return Service
