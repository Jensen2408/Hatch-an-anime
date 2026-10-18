
--[[ ServerScriptService.OwnerPanelServer  (Script)
Every request is checked HERE against the owner ID. The client UI is cosmetic.
Each action calls a hook in HOOKS below. Point each hook at your existing game code
(OwnerGameActions / OwnerControlServer). Anything left as TODO returns a clear error so nothing fails silently.
]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local OWNER_IDS = { [168774222] = true }

local folder = ReplicatedStorage:FindFirstChild("OwnerPanel") or Instance.new("Folder")
folder.Name = "OwnerPanel"; folder.Parent = ReplicatedStorage
local remote = folder:FindFirstChild("Action") or Instance.new("RemoteFunction")
remote.Name = "Action"; remote.Parent = folder

-- Try to reuse your existing module if it exists
local Game = nil
pcall(function() Game = require(game.ServerScriptService:FindFirstChild("OwnerGameActions", true)) end)

local function todo(name) return function() return false, name .. " is not connected yet (see HOOKS in OwnerPanelServer)" end end
local function call(fnName) -- calls Game[fnName](...) if your module has it
	return function(...)
		if Game and type(Game[fnName]) == "function" then
			local ok, a, b = pcall(Game[fnName], ...)
			if not ok then return false, tostring(a) end
			if a == false then return false, b or "Failed" end
			return true, b or a
		end
		return false, fnName .. " is not connected yet (see HOOKS in OwnerPanelServer)"
	end
end

-- HOOKS: rename the strings to match your existing functions, or replace with your own code
local HOOKS = {
	GiveCash      = call("GiveCash"),        -- (target: Player, amount: number)
	SetCash       = call("SetCash"),         -- (target, amount)
	GiveEgg       = call("GiveEgg"),         -- (target, catalogId: string)
	GiveCharacter = call("GiveCharacter"),   -- (target, catalogId)
	SpawnEgg      = call("SpawnRiverEgg"),   -- (catalogId)
	UpgradeTemple = call("UpgradeTemple"),   -- (target)
	UnlockSlot    = call("UnlockSlot"),      -- (target)
	AddIncubator  = call("AddIncubator"),    -- (target)
	UpgradeIncubator = call("UpgradeIncubator"), -- (target, index)
	ClearInventory = call("ClearInventory"), -- (target)
	ClearPlaced   = call("ClearPlaced"),     -- (target)
	ResetSlots    = call("ResetSlots"),      -- (target)
	StartEvent    = call("StartEvent"),      -- (eventId: "rush"|"cash"|"gold", seconds)
	StopEvent     = call("StopEvent"),       -- ()
	SetSpawnInterval = call("SetSpawnInterval"), -- (seconds)
	GetCatalog    = call("GetCatalog"),      -- () -> { {id, name, rarity, kind="egg"|"char"|"reserved"}, ... }
	GetPlot       = call("GetPlot"),         -- (target) -> { level, slots, incubators = {1,2,3}, building }
}

local function plotOf(p) local ok, r = HOOKS.GetPlot(p); return ok and r or nil end

local LIMIT = 1e12
local lastCall = {}
local ACTIONS = {}

local function target(args, caller)
	if args.scope == "me" then return { caller } end
	if args.scope == "lobby" then return Players:GetPlayers() end
	local p = Players:GetPlayerByUserId(tonumber(args.userId) or 0)
	return p and { p } or nil
end
local function eachTarget(args, caller, fn)
	local list = target(args, caller)
	if not list then return false, "That player left the server" end
	local okN, last = 0, nil
	for _, p in list do local ok, msg = fn(p); if ok then okN += 1 else last = msg end end
	if okN == 0 then return false, last or "Nothing changed" end
	return true, (#list > 1) and ("Done for " .. okN .. " players") or "Done"
end
local function amount(v) v = tonumber(v); if not v or v ~= v or v <= 0 or v > LIMIT or v % 1 ~= 0 then return nil end return v end

ACTIONS.Snapshot = function(caller)
	local list = {}
	for _, p in Players:GetPlayers() do table.insert(list, { userId = p.UserId, name = p.DisplayName, user = p.Name, plot = plotOf(p) }) end
	local okC, cat = HOOKS.GetCatalog()
	return true, { players = list, catalog = okC and cat or {} }
end
ACTIONS.GiveCash = function(c, a) local n = amount(a.amount); if not n then return false, "Invalid amount" end return eachTarget(a, c, function(p) return HOOKS.GiveCash(p, n) end) end
ACTIONS.SetCash = function(c, a) local n = amount(a.amount); if not n then return false, "Invalid amount" end if a.scope == "lobby" then return false, "Choose one player" end return eachTarget(a, c, function(p) return HOOKS.SetCash(p, n) end) end
ACTIONS.GiveEgg = function(c, a) return eachTarget(a, c, function(p) return HOOKS.GiveEgg(p, tostring(a.itemId)) end) end
ACTIONS.GiveCharacter = function(c, a) return eachTarget(a, c, function(p) return HOOKS.GiveCharacter(p, tostring(a.itemId)) end) end
ACTIONS.SpawnEgg = function(_, a) return HOOKS.SpawnEgg(tostring(a.itemId)) end
for _, k in { "UpgradeTemple", "UnlockSlot", "AddIncubator", "ClearInventory", "ClearPlaced", "ResetSlots" } do
	ACTIONS[k] = function(c, a) if a.scope == "lobby" then return false, "Choose one player" end return eachTarget(a, c, function(p) return HOOKS[k](p) end) end
end
ACTIONS.UpgradeIncubator = function(c, a) return eachTarget(a, c, function(p) return HOOKS.UpgradeIncubator(p, tonumber(a.index)) end) end
ACTIONS.StartEvent = function(_, a) local s = math.clamp(tonumber(a.seconds) or 300, 60, 3600); return HOOKS.StartEvent(tostring(a.eventId), s) end
ACTIONS.StopEvent = function() return HOOKS.StopEvent() end
ACTIONS.SetSpawnInterval = function(_, a) return HOOKS.SetSpawnInterval(math.clamp(tonumber(a.seconds) or 5, 1, 20)) end
ACTIONS.SendHome = function(c, a) return eachTarget(a, c, function(p) return call("SendHome")(p) end) end
ACTIONS.Bring = function(c, a) return eachTarget(a, c, function(p)
		local from, to = c.Character and c.Character:FindFirstChild("HumanoidRootPart"), p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not (from and to) then return false, "No character" end; to.CFrame = from.CFrame * CFrame.new(0, 0, -4); return true end) end
ACTIONS.GoTo = function(c, a) return eachTarget(a, c, function(p)
		local from, to = c.Character and c.Character:FindFirstChild("HumanoidRootPart"), p.Character and p.Character:FindFirstChild("HumanoidRootPart")
		if not (from and to) then return false, "No character" end; from.CFrame = to.CFrame * CFrame.new(0, 0, -4); return true end) end
ACTIONS.Respawn = function(c, a) return eachTarget(a, c, function(p) p:LoadCharacter(); return true end) end
ACTIONS.Kick = function(c, a)
	local p = Players:GetPlayerByUserId(tonumber(a.userId) or 0)
	if not p then return false, "Player left" end
	if OWNER_IDS[p.UserId] then return false, "Owner protection" end
	p:Kick("Removed by the game owner."); return true, "Player removed"
end
ACTIONS.Ban = function(c, a)
	local id = tonumber(a.userId); if not id or OWNER_IDS[id] then return false, "Invalid target" end
	if game:GetService("RunService"):IsStudio() then return false, "Skipped: bans only work in published servers" end
	local ok, err = pcall(function() Players:BanAsync({ UserIds = { id }, Duration = 86400, DisplayReason = "Banned for 24 hours.", PrivateReason = "Owner panel", ApplyToUniverse = true }) end)
	return ok, ok and "Banned for 24 hours" or tostring(err)
end
ACTIONS.Unban = function(c, a)
	local id = tonumber(a.userId); if not id then return false, "Enter a numeric User ID" end
	local ok, err = pcall(function() Players:UnbanAsync({ UserIds = { id }, ApplyToUniverse = true }) end)
	return ok, ok and "Unbanned" or tostring(err)
end

remote.OnServerInvoke = function(player, action, args)
	if not OWNER_IDS[player.UserId] then return false, "Not allowed" end
	if type(action) ~= "string" or not ACTIONS[action] then return false, "Unknown action" end
	local now = os.clock()
	if action ~= "Snapshot" and lastCall[player] and now - lastCall[player] < 0.25 then return false, "Slow down" end
	lastCall[player] = now
	local ok, res, msg = pcall(ACTIONS[action], player, type(args) == "table" and args or {})
	if not ok then warn("[OwnerPanel]", action, res); return false, "Server error" end
	return res, msg
end
Players.PlayerRemoving:Connect(function(p) lastCall[p] = nil end)
