--[[ ServerScriptService.GameMenu.QuestService  (ModuleScript, server)
Server-authoritative quest progress. Other server scripts report progress:
  local Quests = require(game.ServerScriptService.GameMenu.QuestService)
  Quests.Increment(player, "HatchEgg", 1)   -- only after a hatch has really completed
Progress is SESSION-ONLY until you connect Persistence below.
]]
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("GameMenu"):WaitForChild("Config"))

local Q = { Changed = Instance.new("BindableEvent") }
local data = {} -- [player] = { [questId] = { key = periodKey, progress = n, claimed = bool } }
local claiming = {}

-- Persistence adapter: replace these two with your DataStore / ProfileService calls.
Q.Persistence = {
	Load = function(player) return nil end,       -- return the saved table or nil
	Save = function(player, tbl) end,              -- called on leave + after claims
}

local function row(player, q)
	local t = os.time()
	local d = data[player]; if not d then return nil end
	local r = d[q.id]
	local key = Config.PeriodKey(q.period, t)
	if not r or r.key ~= key then r = { key = key, progress = 0, claimed = false }; d[q.id] = r end -- period rolled over
	return r
end

function Q.Increment(player, objective, n)
	if not data[player] then return end
	n = tonumber(n) or 1
	local changed = false
	for _, q in Config.Quests do
		if q.objective == objective then
			local r = row(player, q)
			if r and not r.claimed and r.progress < q.target then r.progress = math.min(q.target, r.progress + n); changed = true end
		end
	end
	if changed then Q.Changed:Fire(player) end
end

function Q.Snapshot(player)
	local now = os.time()
	local out = { serverTime = now, ends = {}, list = {} }
	for _, p in { "Daily", "Weekly", "Monthly" } do out.ends[p] = Config.PeriodEnds(p, now) end
	for _, q in Config.Quests do
		local r = row(player, q)
		if r then table.insert(out.list, { id = q.id, period = q.period, order = q.order, title = q.title, description = q.description, target = q.target, progress = r.progress, claimed = r.claimed, reward = q.reward }) end
	end
	return out
end

-- grant(player, reward) must return true only if the reward was actually given
function Q.Claim(player, id, grant)
	if claiming[player] then return false, "Claim in progress" end
	local q; for _, x in Config.Quests do if x.id == id then q = x end end
	if not q then return false, "Unknown quest" end
	local r = row(player, q)
	if not r then return false, "Not loaded" end
	if r.claimed then return false, "Already claimed" end
	if r.progress < q.target then return false, "Not finished yet" end
	claiming[player] = true
	r.claimed = true -- mark first so repeated clicks can't double-pay
	local ok, msg = pcall(grant, player, q.reward)
	claiming[player] = nil
	if not ok or msg ~= true then r.claimed = false; return false, "Reward failed, try again" end
	Q.Persistence.Save(player, data[player])
	Q.Changed:Fire(player)
	return true, "Claimed"
end

Players.PlayerAdded:Connect(function(p) data[p] = Q.Persistence.Load(p) or {} end)
for _, p in Players:GetPlayers() do data[p] = data[p] or {} end
Players.PlayerRemoving:Connect(function(p) if data[p] then Q.Persistence.Save(p, data[p]) end data[p] = nil; claiming[p] = nil end)

return Q
