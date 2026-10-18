--[[ ReplicatedStorage.CharacterInventory.InventoryModel  (ModuleScript)
Pure functions over the server snapshot: filtering, sorting, comparisons, the PLACE BEST preview and
which actions are available. No Instances and no side effects, so the same rules drive every view.
The PLACE BEST preview mirrors the server's rule (highest actual income first) but the server
re-checks everything when the button is pressed.
]]
local Config = require(script.Parent.InventoryConfig)

local Model = {}

local RARITY_RANK = {}
for i, r in Config.Rarities do RARITY_RANK[r] = i end

local function byIncome(a, b)
	if a.income ~= b.income then return a.income > b.income end
	if a.power ~= b.power then return a.power > b.power end
	return a.id < b.id
end
Model.ByIncome = byIncome

function Model.Filter(items, search, rarities)
	local q = string.lower(search or ""):gsub("^%s+", ""):gsub("%s+$", "")
	local anyRarity = next(rarities or {}) == nil
	local out = {}
	for _, item in items do
		if anyRarity or rarities[item.rarity] then
			if q == "" or string.find(string.lower(item.name), q, 1, true) or string.find(string.lower(item.characterId), q, 1, true)
				or string.find(string.lower(item.quality), q, 1, true) or string.find(string.lower(item.rarity), q, 1, true) then
				table.insert(out, item)
			end
		end
	end
	return out
end

local SORTS = {
	Power = function(a, b)
		if a.power ~= b.power then return a.power > b.power end
		return byIncome(a, b)
	end,
	Income = byIncome,
	Rarity = function(a, b)
		local ra, rb = RARITY_RANK[a.rarity] or 0, RARITY_RANK[b.rarity] or 0
		if ra ~= rb then return ra > rb end
		if a.power ~= b.power then return a.power > b.power end
		return a.id < b.id
	end,
	Newest = function(a, b)
		local ta, tb = a.acquired or 0, b.acquired or 0
		if ta ~= tb then return ta > tb end
		return a.id < b.id
	end,
}

function Model.Sort(list, sortId, ascending)
	local cmp = SORTS[sortId] or SORTS.Power
	if ascending then
		table.sort(list, function(a, b) return cmp(b, a) end)
	else
		table.sort(list, cmp)
	end
	return list
end

function Model.Strongest(items)
	local best
	for _, item in items do
		if not best or item.power > best.power or (item.power == best.power and item.income > best.income) then best = item end
	end
	return best
end

-- Mirrors InventoryService PlaceBest. Returns { gain, place, swap, current, after }.
function Model.BestPlan(items, cap, allowStore)
	local plan = { gain = 0, place = 0, swap = 0, current = 0, after = 0 }
	if not cap or not cap.hasPlot or cap.unlocked == 0 then return plan end
	local sorted = table.clone(items)
	table.sort(sorted, byIncome)
	for _, item in sorted do if item.state == "Placed" then plan.current += item.income end end
	if allowStore then
		local n = math.min(cap.unlocked, #sorted)
		local storeable = 0
		for i = 1, #sorted do
			local item = sorted[i]
			if i <= n then
				plan.after += item.income
				if item.state ~= "Placed" then plan.place += 1 end
			elseif item.state == "Placed" then
				storeable += 1
			end
		end
		local free = cap.unlocked - cap.placed
		plan.swap = math.min(storeable, math.max(0, plan.place - free))
	else
		plan.after = plan.current
		local free = cap.unlocked - cap.placed
		for _, item in sorted do
			if free <= 0 then break end
			if item.state ~= "Placed" then plan.after += item.income plan.place += 1 free -= 1 end
		end
	end
	plan.gain = plan.after - plan.current
	return plan
end

-- What the selected character is compared against, and why.
function Model.CompareTarget(items, selected, pinnedId)
	if not selected then return nil end
	if pinnedId and pinnedId ~= selected.id then
		for _, item in items do if item.id == pinnedId then return item, "PINNED" end end
	end
	if selected.state ~= "Placed" then
		for _, item in items do
			if item.state == "Held" and item.id ~= selected.id then return item, "HELD" end
		end
		local weakest
		for _, item in items do
			if item.state == "Placed" and (not weakest or byIncome(weakest, item)) then weakest = item end
		end
		if weakest then return weakest, "WEAKEST PLACED" end
	else
		local best
		for _, item in items do
			if item.state ~= "Placed" and (not best or byIncome(item, best)) then best = item end
		end
		if best then return best, "BEST UNPLACED" end
	end
	return nil
end

-- { { action, label, kind, enabled, reason } } for the details panel, in display order.
function Model.Actions(item, cap, allowStore, alive)
	local list = {}
	if not item then return list end
	if item.state == "Placed" then
		table.insert(list, {
			action = "Store", label = "STORE", kind = "Primary", enabled = allowStore and alive,
			reason = not allowStore and "Placed characters stay on their slot."
				or (not alive and "Wait until you respawn." or nil),
		})
		return list
	end
	local reason
	if not cap or not cap.hasPlot then reason = "Claim a plot to place characters."
	elseif cap.unlocked == 0 then reason = "Unlock a slot at your temple first."
	elseif cap.placed >= cap.unlocked then
		reason = allowStore and "All unlocked slots are full. Store one, or use PLACE BEST to swap."
			or "All unlocked slots are full."
	elseif not alive then reason = "Wait until you respawn." end
	table.insert(list, { action = "Place", label = "PLACE", kind = "Primary", enabled = reason == nil, reason = reason })
	if item.state == "Held" then
		table.insert(list, { action = "PutAway", label = "PUT AWAY", kind = "Secondary", enabled = alive })
	else
		table.insert(list, {
			action = "Hold", label = "HOLD", kind = "Secondary", enabled = alive,
			reason = not alive and "Wait until you respawn." or nil,
		})
	end
	return list
end

return Model
