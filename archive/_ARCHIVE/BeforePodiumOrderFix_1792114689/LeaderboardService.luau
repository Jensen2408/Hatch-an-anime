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
]]
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserService = game:GetService("UserService")

local Shared = ReplicatedStorage:WaitForChild("Leaderboard")
local Config = require(Shared:WaitForChild("LeaderboardConfig"))
local S = Config.Server

local Service = {}

-- Fires (statId) after every global read attempt, successful or not. Used by LeaderboardChampions.
Service.GlobalUpdated = Instance.new("BindableEvent")

local STATS = Config.StatById
local SCOPES = { Server = true, Global = true }
local MAX_VALUE = 2 ^ 53
local WRITE = Enum.DataStoreRequestType.SetIncrementSortedAsync
local READ_SORTED = Enum.DataStoreRequestType.GetSortedAsync
local READ = Enum.DataStoreRequestType.GetAsync

local plots = workspace:WaitForChild("Plots")

local records = {}       -- [Player] = record (see newRecord)
local serverBoards = {}  -- [statId] = { entries, rankByUser, total, updated }
local globalBoards = {}  -- [statId] = { status, entries, rankByUser, valueByUser, total, updated }
local nameCache = {}     -- [userId] = { n = username, d = displayName, at = os.clock() }
local lastGlobalDemand = {} -- [statId] = os.clock() of the last GLOBAL request
local buckets = {}       -- [Player] = rate-limit bucket
local started = false

---------------------------------------------------------------- stores
local stores = {}
local storesOk = pcall(function()
	for id in STATS do
		local name = "Leaderboard_" .. id .. "_" .. S.StoreVersion
		if RunService:IsStudio() and S.SeparateStudioStores then name ..= "_Studio" end
		stores[id] = DataStoreService:GetOrderedDataStore(name)
	end
end)
if not storesOk then warn("[Leaderboard] OrderedDataStores unavailable; GLOBAL will show as unavailable.") end

-- One warning per topic every 10 minutes, so a DataStore outage (or Studio without API access)
-- doesn't flood the output.
local warnedAt = {}
local function note(topic, message)
	local now = os.clock()
	if warnedAt[topic] and now - warnedAt[topic] < 600 then return end
	warnedAt[topic] = now
	warn("[Leaderboard] " .. message)
end

local function budget(kind)
	local ok, n = pcall(DataStoreService.GetRequestBudgetForRequestType, DataStoreService, kind)
	return ok and n or 0
end

local function clean(v)
	v = tonumber(v)
	if not v or v ~= v or v < 0 then return nil end
	return math.floor(math.min(v, MAX_VALUE))
end

---------------------------------------------------------------- live values
local function cashOf(player)
	local stats = player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("Cash")
	if cash and (cash:IsA("IntValue") or cash:IsA("NumberValue")) then return cash.Value end
	return nil
end

local function incomeOf(player)
	local total = 0
	for _, plot in plots:GetChildren() do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			local placed = plot:FindFirstChild("PlacedItems")
			if placed then
				for _, item in placed:GetChildren() do
					local rate = item:GetAttribute("IncomePerSecond")
					if type(rate) == "number" and rate == rate and rate > 0 and rate < math.huge then total += rate end
				end
			end
		end
	end
	if S.IncludeIncomeMultiplier then total *= (tonumber(workspace:GetAttribute("OwnerIncomeMultiplier")) or 1)*(workspace:GetAttribute("NightCashMultiplier") or 1) end
	return total
end

local function newRecord()
	return {
		values = {},            -- [statId] = latest value (number) or nil when not ready
		written = {},           -- [statId] = value last written to the global store
		nextWrite = os.clock() + S.FirstWriteDelay + math.random() * 15,
		hatchStored = nil,      -- lifetime hatches in the store (known after load / increment)
		hatchPending = 0,       -- completed here, not yet written
		hatchInflight = 0,      -- being written right now
		hatchState = "loading", -- loading → ready | offline
	}
end

local function hatchesOf(rec)
	return (rec.hatchStored or 0) + rec.hatchPending + rec.hatchInflight
end

---------------------------------------------------------------- global writes
local function loadHatches(player, rec)
	local store = stores.Hatches
	if not store then rec.hatchState = "offline" return end
	for attempt = 1, 3 do
		if player.Parent ~= Players then return end
		if budget(READ) > 2 then
			local ok, value = pcall(store.GetAsync, store, tostring(player.UserId))
			if ok then
				rec.hatchStored = clean(value) or 0
				rec.hatchState = "ready"
				return
			end
			note("load", "could not load hatches for " .. player.Name .. ": " .. tostring(value))
		end
		task.wait(5 * attempt)
	end
	rec.hatchState = "offline" -- session hatches still count and are added with IncrementAsync later
end

local function flush(player, rec, final)
	if not storesOk then return end
	local key = tostring(player.UserId)

	-- Hatches: atomic increment. Skipped while the first load is running so the two can't double count
	-- (except on leave, where only the store matters).
	if rec.hatchPending > 0 and (final or rec.hatchState ~= "loading") and (final or budget(WRITE) > S.WriteReserve) then
		local delta = rec.hatchPending
		rec.hatchPending = 0
		rec.hatchInflight = delta
		local ok, newValue = pcall(stores.Hatches.IncrementAsync, stores.Hatches, key, delta)
		rec.hatchInflight = 0
		if ok then
			rec.hatchStored = clean(newValue) or ((rec.hatchStored or 0) + delta)
			rec.hatchState = "ready"
		else
			rec.hatchPending += delta
			note("write", "hatch write failed for " .. player.Name .. ": " .. tostring(newValue))
		end
	end

	-- Cash / Income: the current value, written only when it changed.
	for _, id in { "Cash", "Income" } do
		local value = rec.values[id]
		local last = rec.written[id]
		if value ~= nil and value ~= last and not (last == nil and value == 0) then
			if final or budget(WRITE) > S.WriteReserve then
				local ok, err = pcall(stores[id].SetAsync, stores[id], key, value)
				if ok then rec.written[id] = value else note("write", id .. " write failed: " .. tostring(err)) end
			end
		end
	end
end

---------------------------------------------------------------- THIS SERVER
local function refreshServer()
	for player, rec in records do
		if player.Parent ~= Players then continue end
		rec.values.Cash = clean(cashOf(player))
		rec.values.Income = clean(incomeOf(player))
		rec.values.Hatches = clean(hatchesOf(rec))
	end
	local now = workspace:GetServerTimeNow()
	for id in STATS do
		local list = {}
		for player, rec in records do
			local v = rec.values[id]
			if player.Parent == Players and v and v > 0 then table.insert(list, { player = player, v = v }) end
		end
		table.sort(list, function(a, b)
			if a.v ~= b.v then return a.v > b.v end
			return a.player.UserId < b.player.UserId
		end)
		local entries, rankByUser = {}, {}
		for i, item in list do
			rankByUser[item.player.UserId] = i
			if i <= Config.MaxRows then
				entries[i] = { r = i, u = item.player.UserId, n = item.player.Name, d = item.player.DisplayName, v = item.v }
			end
		end
		serverBoards[id] = { entries = entries, rankByUser = rankByUser, total = #list, updated = now }
	end
end

---------------------------------------------------------------- GLOBAL
local function resolveNames(ids)
	local missing = {}
	local now = os.clock()
	for _, id in ids do
		local p = Players:GetPlayerByUserId(id)
		if p then
			nameCache[id] = { n = p.Name, d = p.DisplayName, at = now }
		elseif not nameCache[id] or now - nameCache[id].at > 3600 then
			table.insert(missing, id)
		end
	end
	if #missing == 0 then return end
	local ok, infos = pcall(UserService.GetUserInfosByUserIdsAsync, UserService, missing)
	if ok and type(infos) == "table" then
		for _, info in infos do nameCache[info.Id] = { n = info.Username, d = info.DisplayName, at = now } end
	else
		note("names", "name lookup failed: " .. tostring(infos))
	end
end

local function refreshGlobal(id)
	local board = globalBoards[id]
	local store = stores[id]
	if not store then
		board.status = board.entries and "stale" or "unavailable"
		return false
	end
	if budget(READ_SORTED) < 1 then return false end
	local ok, page = pcall(function()
		return store:GetSortedAsync(false, S.GlobalFetchSize, 1):GetCurrentPage()
	end)
	if not ok then
		note("read", "global " .. id .. " read failed: " .. tostring(page))
		board.status = board.entries and "stale" or "unavailable"
		return false
	end
	local ids = {}
	for _, item in page do
		local uid = tonumber(item.key)
		if uid then table.insert(ids, uid) end
	end
	resolveNames(ids)
	local entries, rankByUser, valueByUser, rank = {}, {}, {}, 0
	for _, item in page do
		local uid, v = tonumber(item.key), clean(item.value)
		if uid and v and v > 0 then
			rank += 1
			rankByUser[uid] = rank
			valueByUser[uid] = v
			if rank <= Config.MaxRows then
				local name = nameCache[uid]
				entries[rank] = { r = rank, u = uid, n = name and name.n, d = name and name.d, v = v }
			end
		end
	end
	board.status = "ok"
	board.entries, board.rankByUser, board.valueByUser = entries, rankByUser, valueByUser
	board.total = rank
	board.updated = workspace:GetServerTimeNow()
	return true
end

---------------------------------------------------------------- remote
local function snapshot(player, id, scope)
	local rec = records[player]
	local live = rec and rec.values[id]
	if scope == "Server" then
		local board = serverBoards[id]
		if not board then return { stat = id, scope = scope, status = "loading" } end
		return {
			stat = id, scope = scope, status = "ok", entries = board.entries, total = board.total,
			updated = board.updated, you = { r = board.rankByUser[player.UserId], v = live },
		}
	end
	lastGlobalDemand[id] = os.clock()
	local board = globalBoards[id]
	local rank = board.rankByUser and board.rankByUser[player.UserId]
	local you = rank and { r = rank, v = board.valueByUser[player.UserId] } or { v = live }
	return {
		stat = id, scope = scope, status = board.status, entries = board.entries, total = board.total,
		updated = board.updated, depth = S.GlobalFetchSize, you = you,
	}
end

local function onInvoke(player, id, scope)
	if type(id) ~= "string" or not STATS[id] or type(scope) ~= "string" or not SCOPES[scope] then return nil end
	local now = os.clock()
	local bucket = buckets[player]
	if not bucket then
		bucket = { tokens = S.RequestBurst, at = now }
		buckets[player] = bucket
	end
	bucket.tokens = math.min(S.RequestBurst, bucket.tokens + (now - bucket.at) * S.RequestsPerSecond)
	bucket.at = now
	if bucket.tokens < 1 then return { stat = id, scope = scope, status = "busy" } end
	bucket.tokens -= 1
	return snapshot(player, id, scope)
end

---------------------------------------------------------------- hatches
local function plotOf(inst)
	local node = inst
	while node and node.Parent ~= plots do node = node.Parent end
	return node
end

local hooked = setmetatable({}, { __mode = "k" })
local function hookChamber(inst)
	if hooked[inst] or inst.Name ~= "HatchCycleCompleted" or not inst:IsA("BindableEvent") then return end
	hooked[inst] = true
	inst.Event:Connect(function(who)
		if typeof(who) ~= "Instance" or not who:IsA("Player") or who.Parent ~= Players then return end
		local plot = plotOf(inst)
		if not plot or plot:GetAttribute("OwnerUserId") ~= who.UserId then return end
		Service.RecordHatch(who)
	end)
end

-- Server-side only. Call this from other server systems if you add new ways to complete a hatch.
function Service.RecordHatch(player)
	local rec = records[player]
	if rec then rec.hatchPending += 1 end
end

function Service.GetValue(player, statId)
	local rec = records[player]
	return rec and rec.values[statId]
end

-- Top `count` GLOBAL entries for a stat, copied: status ("loading" | "ok" | "stale" | "unavailable"), list.
-- Calling it counts as someone looking, so the stat keeps being read while the podiums need it.
function Service.GetGlobalTop(statId, count)
	lastGlobalDemand[statId] = os.clock()
	local board = globalBoards[statId]
	if not board then return "loading", {} end
	local list = {}
	for i = 1, math.min(count, board.entries and #board.entries or 0) do
		local e = board.entries[i]
		list[i] = { r = e.r, u = e.u, n = e.n, d = e.d, v = e.v }
	end
	return board.status, list
end

---------------------------------------------------------------- lifecycle
local function onJoin(player)
	if records[player] then return end
	local rec = newRecord()
	records[player] = rec
	nameCache[player.UserId] = { n = player.Name, d = player.DisplayName, at = os.clock() }
	task.spawn(loadHatches, player, rec)
end

local function onLeave(player)
	local rec = records[player]
	records[player] = nil
	buckets[player] = nil
	if rec then task.spawn(flush, player, rec, true) end
end

function Service.Start()
	if started then return end
	started = true

	local remote = Shared:FindFirstChild(Config.RemoteName) or Instance.new("RemoteFunction")
	remote.Name = Config.RemoteName
	remote.OnServerInvoke = onInvoke
	remote.Parent = Shared

	for id in STATS do globalBoards[id] = { status = storesOk and "loading" or "unavailable" } end

	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(onLeave)
	for _, p in Players:GetPlayers() do onJoin(p) end

	for _, d in plots:GetDescendants() do hookChamber(d) end
	plots.DescendantAdded:Connect(hookChamber)

	-- THIS SERVER: cheap rebuild from live values.
	refreshServer()
	task.spawn(function()
		while true do
			task.wait(S.ServerRefresh)
			local ok, err = pcall(refreshServer)
			if not ok then note("refresh", "server refresh: " .. tostring(err)) end
		end
	end)

	-- GLOBAL reads: staggered, cached, skipped when nobody is looking.
	task.spawn(function()
		local nextRead = {}
		for i, stat in Config.Stats do nextRead[stat.Id] = os.clock() + 3 + (i - 1) * 3 end
		while true do
			task.wait(1)
			if not storesOk then continue end
			for id, at in nextRead do
				if os.clock() < at then continue end
				local board = globalBoards[id]
				local idle = board.entries and os.clock() - (lastGlobalDemand[id] or -math.huge) > S.GlobalIdleAfter
				if idle then
					nextRead[id] = os.clock() + 5 -- re-check soon; reads resume as soon as someone looks
				else
					local ok = refreshGlobal(id)
					nextRead[id] = os.clock() + (ok and S.GlobalRead or S.GlobalRetry)
					Service.GlobalUpdated:Fire(id)
				end
			end
		end
	end)

	-- GLOBAL writes: each player at most every GlobalWrite seconds, only when something changed.
	task.spawn(function()
		while true do
			task.wait(5)
			local now, done = os.clock(), 0
			for player, rec in records do
				if done >= S.WritesPerTick then break end
				if now >= rec.nextWrite then
					rec.nextWrite = now + S.GlobalWrite
					done += 1
					task.spawn(flush, player, rec, false)
				end
			end
		end
	end)

	game:BindToClose(function()
		if not storesOk then return end
		local pending = 0
		for player, rec in records do
			pending += 1
			task.spawn(function()
				pcall(flush, player, rec, true)
				pending -= 1
			end)
		end
		local t = os.clock()
		while pending > 0 and os.clock() - t < 20 do task.wait(0.25) end
	end)
end

return Service
