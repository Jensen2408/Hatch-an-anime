-- PlayerPunish (owner only, used by the owner panel "Punish" page): take money from a player or wipe their save + leaderboard.
-- Works for online (this server) and offline players. A player playing in ANOTHER server is refused (their server owns the save).
-- Wipes keep the DataStore version history, so the Restore page can still bring an old save back.
local Players = game:GetService("Players")
local DSS = game:GetService("DataStoreService")
local SSS = game:GetService("ServerScriptService")
local LOCK_TIMEOUT = 150
local store = DSS:GetDataStore("PlayerData_v1")
local Leaderboard = require(SSS:WaitForChild("Leaderboard"):WaitForChild("LeaderboardService"))
local M = {}

local function resolve(who)
    local id = tonumber(who)
    if not id and type(who) == "string" and #who > 0 then
        local p = Players:FindFirstChild(who)
        if p then
            return p.UserId, p.Name
        end
        local ok, r = pcall(Players.GetUserIdFromNameAsync, Players, who)
        if ok then
            id = r
        end
    end
    if not id then
        error("Couldn't find that player. Use their exact username or User ID.")
    end
    local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, id)
    return id, ok and n or tostring(id)
end
local function fmt(n)
    return tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
local function lockedElsewhere(d)
    return type(d) == "table" and d.lock and d.lock.job ~= game.JobId and os.time() - (d.lock.t or 0) < LOCK_TIMEOUT
end

-- amount = number to take, or "all" to set them to $0
function M.TakeCash(by, who, amount)
    local id, name = resolve(who)
    local all = amount == "all"
    amount = tonumber(amount)
    assert(all or (amount and amount > 0), "Enter an amount to take.")
    local here = Players:GetPlayerByUserId(id)
    if here then
        local ls = here:FindFirstChild("leaderstats")
        local cash = ls and ls:FindFirstChild("Cash")
        assert(cash, "Their cash isn't loaded yet. Try again in a moment.")
        local before = cash.Value
        cash.Value = all and 0 or math.max(0, before - amount)
        -- money already sitting on their stands goes too when taking everything
        if all then
            for _, plot in workspace.Plots:GetChildren() do
                if plot:GetAttribute("OwnerUserId") == id then
                    for _, slot in plot.Slots:GetChildren() do
                        local st = slot:FindFirstChild("MoneyStand")
                        if st then
                            st:SetAttribute("Stored", 0)
                        end
                    end
                end
            end
        end
        warn(("[OwnerPunish] %s took $%s from @%s (online)"):format(by.Name, fmt(before - cash.Value), name))
        return ("Took $%s from @%s. They now have $%s."):format(fmt(before - cash.Value), name, fmt(cash.Value))
    end
    local blocked, before, after = false, 0, 0
    store:UpdateAsync("u" .. id, function(d)
        if type(d) ~= "table" then
            return nil
        end
        if lockedElsewhere(d) then
            blocked = true
            return nil
        end
        before = tonumber(d.cash) or 0
        after = all and 0 or math.max(0, before - amount)
        d.cash = after
        return d
    end)
    if blocked then
        error("@" .. name .. " is playing in another server right now. Try again when they leave.")
    end
    Leaderboard.SetGlobalCash(id, after)
    warn(("[OwnerPunish] %s took $%s from @%s (offline)"):format(by.Name, fmt(before - after), name))
    return ("Took $%s from @%s (offline). They now have $%s."):format(fmt(before - after), name, fmt(after))
end

-- Full reset: save back to a brand-new player + removed from every global leaderboard.
function M.Wipe(by, who)
    local id, name = resolve(who)
    assert(id ~= by.UserId, "You can't wipe yourself here.")
    local here = Players:GetPlayerByUserId(id)
    if here then
        here:Kick("Your progress was reset by the game owner.")
        -- wait for this server's leave-save + leaderboard flush to finish, so they can't write the old data back
        local t = os.clock()
        repeat
            task.wait(1)
            local ok, d = pcall(store.GetAsync, store, "u" .. id)
            if ok and not (type(d) == "table" and d.lock) then
                break
            end
        until os.clock() - t > 20
        task.wait(2)
    end
    local blocked = false
    store:UpdateAsync("u" .. id, function(d)
        if lockedElsewhere(d) and not here then
            blocked = true
            return nil
        end
        return { v = 1, wipedAt = os.time(), wipedBy = by.UserId }
    end)
    if blocked then
        error("@" .. name .. " is playing in another server right now. Try again when they leave.")
    end
    local lbOk = Leaderboard.Forget(id)
    warn(("[OwnerPunish] %s wiped @%s (save + leaderboards)"):format(by.Name, name))
    return "Wiped @"
        .. name
        .. ": fresh save"
        .. (lbOk and " and removed from all leaderboards." or ", but a leaderboard removal failed — try again.")
end

return M
