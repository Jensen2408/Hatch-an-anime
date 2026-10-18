--[[ ReplicatedStorage.CharacterInventory.InventoryModel  (ModuleScript)
Pure functions over the server snapshot: filtering, sorting, comparisons, the PLACE BEST preview and
which actions are available. No Instances and no side effects, so the same rules drive every view.
The PLACE BEST preview mirrors the server's rule (highest actual income first) but the server
re-checks everything when the button is pressed.
]]
local Config = require(script.Parent.InventoryConfig)

local Model = {}

-- Rarity name -> position in Config.Rarities (higher = rarer).
local RARITY_RANK = {}
for rank, rarity in Config.Rarities do
    RARITY_RANK[rarity] = rank
end

-- Comparators below return true when `a` should come first (strongest first). Ties always fall
-- back to the ItemId so the order is stable between snapshots.

local function byIncome(a, b)
    if a.income ~= b.income then
        return a.income > b.income
    end
    if a.power ~= b.power then
        return a.power > b.power
    end
    return a.id < b.id
end
Model.ByIncome = byIncome

-- Case-insensitive substring search over name, characterId, quality and rarity, plus an optional
-- rarity set ({ [rarity] = true }; empty = all rarities).
function Model.Filter(items, search, rarities)
    local query = string.lower(search or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local anyRarity = next(rarities or {}) == nil
    local matches = {}
    for _, item in items do
        if anyRarity or rarities[item.rarity] then
            if
                query == ""
                or string.find(string.lower(item.name), query, 1, true)
                or string.find(string.lower(item.characterId), query, 1, true)
                or string.find(string.lower(item.quality), query, 1, true)
                or string.find(string.lower(item.rarity), query, 1, true)
            then
                table.insert(matches, item)
            end
        end
    end
    return matches
end

-- Sort id (Config.Sorts[].Id) -> comparator. Unknown ids fall back to Power.
local SORTS = {
    Power = function(a, b)
        if a.power ~= b.power then
            return a.power > b.power
        end
        return byIncome(a, b)
    end,
    Income = byIncome,
    Rarity = function(a, b)
        local rankA, rankB = RARITY_RANK[a.rarity] or 0, RARITY_RANK[b.rarity] or 0
        if rankA ~= rankB then
            return rankA > rankB
        end
        if a.power ~= b.power then
            return a.power > b.power
        end
        return a.id < b.id
    end,
    Newest = function(a, b)
        local acquiredA, acquiredB = a.acquired or 0, b.acquired or 0
        if acquiredA ~= acquiredB then
            return acquiredA > acquiredB
        end
        return a.id < b.id
    end,
}

-- Sorts `list` in place (and returns it). `ascending` flips the comparator's natural strongest-first order.
function Model.Sort(list, sortId, ascending)
    local compare = SORTS[sortId] or SORTS.Power
    if ascending then
        table.sort(list, function(a, b)
            return compare(b, a)
        end)
    else
        table.sort(list, compare)
    end
    return list
end

-- Highest Power (ties: higher income); nil for an empty list. Drives the HUD "BEST POWER" value.
function Model.Strongest(items)
    local best
    for _, item in items do
        if not best or item.power > best.power or (item.power == best.power and item.income > best.income) then
            best = item
        end
    end
    return best
end

-- Mirrors InventoryService PlaceBest. Returns { gain, place, swap, current, after }:
--   current/after = plot income before/after (item.income, before the event multiplier), gain = after - current,
--   place = characters that would be placed, swap = placed characters that would be stored for them.
-- allowStore: the best `unlocked` characters end up placed (swapping weaker ones out);
-- otherwise only free unlocked slots are filled, best unplaced first.
function Model.BestPlan(items, capacity, allowStore)
    local plan = { gain = 0, place = 0, swap = 0, current = 0, after = 0 }
    if not capacity or not capacity.hasPlot or capacity.unlocked == 0 then
        return plan
    end
    local sorted = table.clone(items)
    table.sort(sorted, byIncome)
    for _, item in sorted do
        if item.state == "Placed" then
            plan.current += item.income
        end
    end
    if allowStore then
        local slotsToFill = math.min(capacity.unlocked, #sorted)
        local storeable = 0
        for i = 1, #sorted do
            local item = sorted[i]
            if i <= slotsToFill then
                plan.after += item.income
                if item.state ~= "Placed" then
                    plan.place += 1
                end
            elseif item.state == "Placed" then
                storeable += 1
            end
        end
        local freeSlots = capacity.unlocked - capacity.placed
        plan.swap = math.min(storeable, math.max(0, plan.place - freeSlots))
    else
        plan.after = plan.current
        local freeSlots = capacity.unlocked - capacity.placed
        for _, item in sorted do
            if freeSlots <= 0 then
                break
            end
            if item.state ~= "Placed" then
                plan.after += item.income
                plan.place += 1
                freeSlots -= 1
            end
        end
    end
    plan.gain = plan.after - plan.current
    return plan
end

-- What the selected character is compared against, and why. Returns (item, reason) or nil.
-- Priority: the pinned item; for an unplaced selection the held item, else the weakest placed one;
-- for a placed selection the best unplaced one.
function Model.CompareTarget(items, selected, pinnedId)
    if not selected then
        return nil
    end
    if pinnedId and pinnedId ~= selected.id then
        for _, item in items do
            if item.id == pinnedId then
                return item, "PINNED"
            end
        end
    end
    if selected.state ~= "Placed" then
        for _, item in items do
            if item.state == "Held" and item.id ~= selected.id then
                return item, "HELD"
            end
        end
        local weakest
        for _, item in items do
            if item.state == "Placed" and (not weakest or byIncome(weakest, item)) then
                weakest = item
            end
        end
        if weakest then
            return weakest, "WEAKEST PLACED"
        end
    else
        local best
        for _, item in items do
            if item.state ~= "Placed" and (not best or byIncome(item, best)) then
                best = item
            end
        end
        if best then
            return best, "BEST UNPLACED"
        end
    end
    return nil
end

-- { { action, label, kind, enabled, reason } } for the details panel, in display order.
-- `reason` is the player-facing explanation shown when an action is disabled.
function Model.Actions(item, capacity, allowStore, alive)
    local list = {}
    if not item then
        return list
    end
    if item.state == "Placed" then
        table.insert(list, {
            action = "Store",
            label = "STORE",
            kind = "Primary",
            enabled = allowStore and alive,
            reason = not allowStore and "Placed characters stay on their slot."
                or (not alive and "Wait until you respawn." or nil),
        })
        return list
    end
    local reason
    if not capacity or not capacity.hasPlot then
        reason = "Claim a plot to place characters."
    elseif capacity.unlocked == 0 then
        reason = "Unlock a slot at your temple first."
    elseif capacity.placed >= capacity.unlocked then
        reason = allowStore and "All unlocked slots are full. Store one, or use PLACE BEST to swap."
            or "All unlocked slots are full."
    elseif not alive then
        reason = "Wait until you respawn."
    end
    table.insert(
        list,
        { action = "Place", label = "PLACE", kind = "Primary", enabled = reason == nil, reason = reason }
    )
    if item.state == "Held" then
        table.insert(list, { action = "PutAway", label = "PUT AWAY", kind = "Secondary", enabled = alive })
    else
        table.insert(list, {
            action = "Hold",
            label = "HOLD",
            kind = "Secondary",
            enabled = alive,
            reason = not alive and "Wait until you respawn." or nil,
        })
    end
    return list
end

return Model
