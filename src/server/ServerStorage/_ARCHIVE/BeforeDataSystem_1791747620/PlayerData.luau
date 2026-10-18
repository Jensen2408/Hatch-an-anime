--[[ ServerScriptService.PlayerData  (ModuleScript)
One saved table per player (DataStore "PlayerData_v1", key "u<UserId>").
  PlayerData.Get(player)  -> the table (yields until loaded). Other scripts read/write fields on it.
  PlayerData.Ready(player) -> true once loading finished (only then do we ever save, so a failed load can't wipe data).
Fields: cash, templeLevel, slots{index=true}, chambers{level,...}, characters{...}, discovered{key=true}, quests{...}
]]
local Players = game:GetService("Players")
local DSS = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local M = {}
local store do local ok, s = pcall(DSS.GetDataStore, DSS, "PlayerData_v1"); store = ok and s or nil end
local cache, loading, ready = {}, {}, {}
M.Collectors = {} -- functions(player, data) that copy live game state into the table before saving

local function default() return { cash = 0, templeLevel = 1, slots = { [1] = true }, chambers = { 1 }, characters = {}, discovered = {}, quests = nil, version = 1 } end

function M.Get(player)
	if cache[player] then return cache[player] end
	if loading[player] then while loading[player] and player.Parent do task.wait(0.1) end; return cache[player] or default() end
	loading[player] = true
	local data
	if store then
		for attempt = 1, 4 do
			local ok, r = pcall(store.GetAsync, store, "u" .. player.UserId)
			if ok then data = type(r) == "table" and r or nil; ready[player] = true; break end
			warn("[PlayerData] load failed (" .. attempt .. "): " .. tostring(r)); task.wait(attempt)
		end
	end
	if not store then ready[player] = RunService:IsStudio() end -- Studio without API access: play, never save
	data = data or default()
	for k, v in default() do if data[k] == nil then data[k] = v end end
	cache[player] = data
	loading[player] = nil
	player:SetAttribute("DataStatus", ready[player] and (store and "Loaded" or "Studio") or "LoadFailed")
	return data
end

function M.Ready(player) return ready[player] == true end

function M.Save(player)
	local data = cache[player]
	if not data or not ready[player] or not store then return end
	for _, f in M.Collectors do local ok, err = pcall(f, player, data); if not ok then warn("[PlayerData] collect: " .. tostring(err)) end end
	for attempt = 1, 3 do
		local ok, err = pcall(store.UpdateAsync, store, "u" .. player.UserId, function() return data end)
		if ok then return true end
		warn("[PlayerData] save failed (" .. attempt .. "): " .. tostring(err)); task.wait(attempt)
	end
end

function M.Release(player) cache[player] = nil; ready[player] = nil; loading[player] = nil end
return M
