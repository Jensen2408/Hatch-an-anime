--[[ ServerScriptService.PlayerPunish  (ModuleScript, server only)
Owner panel "Punish" page: take money from a player or wipe their save + global leaderboard entries. Works for players
in this server and for offline players. A player playing in ANOTHER server is refused (their server owns the save).
Wipes keep the DataStore version history, so the Restore page (SaveRestore) can still bring an old save back.

Who is authorized: the owner only. This module does NOT check permissions itself; OwnerPanelServer's TakeCash /
WipePlayer handlers check role == "Owner" and args.confirmed == true before calling. byPlayer is that owner.
Trusted input: nameOrId / amount come from the owner's client and are validated here (resolvePlayer, amount > 0).
Errors (error / assert) are caught by OwnerPanelServer's pcall and shown to the owner as the message.

DataStore contract: "PlayerData_v1", key "u" .. userId (same store as PlayerData). Fields used: cash, lock = { job, t }.
A lock whose job is another JobId and is younger than LOCK_TIMEOUT seconds means "playing elsewhere".
Wipe writes { v = 1, wipedAt, wipedBy }, i.e. a brand-new save.
]]
-- ===== 1. Services, store and helpers =====
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ServerScriptService = game:GetService("ServerScriptService")
-- Seconds after which another server's session lock is treated as stale (keep in sync with PlayerData).
local LOCK_TIMEOUT = 150
local playerDataStore = DataStoreService:GetDataStore("PlayerData_v1")
local Leaderboard = require(ServerScriptService:WaitForChild("Leaderboard"):WaitForChild("LeaderboardService"))
local PlayerPunish = {}

-- Username (online first, then web lookup) or UserId -> userId, username. Errors when nothing matches.
local function resolvePlayer(nameOrId)
    local userId = tonumber(nameOrId)
    if not userId and type(nameOrId) == "string" and #nameOrId > 0 then
        local onlinePlayer = Players:FindFirstChild(nameOrId)
        if onlinePlayer then
            return onlinePlayer.UserId, onlinePlayer.Name
        end
        local ok, lookedUpId = pcall(Players.GetUserIdFromNameAsync, Players, nameOrId)
        if ok then
            userId = lookedUpId
        end
    end
    if not userId then
        error("Couldn't find that player. Use their exact username or User ID.")
    end
    local ok, userName = pcall(Players.GetNameFromUserIdAsync, Players, userId)
    return userId, ok and userName or tostring(userId)
end
-- 1234567 -> "1,234,567" (floors; negative numbers are not expected here).
local function formatCash(amount)
    return tostring(math.floor(amount)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end
local function lockedElsewhere(save)
    return type(save) == "table"
        and save.lock
        and save.lock.job ~= game.JobId
        and os.time() - (save.lock.t or 0) < LOCK_TIMEOUT
end

-- ===== 2. Public API =====
-- amount = number to take, or "all" to set them to $0
function PlayerPunish.TakeCash(byPlayer, nameOrId, amount)
    local userId, name = resolvePlayer(nameOrId)
    local takeAll = amount == "all"
    amount = tonumber(amount)
    assert(takeAll or (amount and amount > 0), "Enter an amount to take.")
    local onlinePlayer = Players:GetPlayerByUserId(userId)
    if onlinePlayer then
        local leaderstats = onlinePlayer:FindFirstChild("leaderstats")
        local cash = leaderstats and leaderstats:FindFirstChild("Cash")
        assert(cash, "Their cash isn't loaded yet. Try again in a moment.")
        local before = cash.Value
        cash.Value = takeAll and 0 or math.max(0, before - amount)
        -- money already sitting on their stands goes too when taking everything
        if takeAll then
            for _, plot in workspace.Plots:GetChildren() do
                if plot:GetAttribute("OwnerUserId") == userId then
                    for _, slot in plot.Slots:GetChildren() do
                        local moneyStand = slot:FindFirstChild("MoneyStand")
                        if moneyStand then
                            moneyStand:SetAttribute("Stored", 0)
                        end
                    end
                end
            end
        end
        warn(
            ("[OwnerPunish] %s took $%s from @%s (online)"):format(byPlayer.Name, formatCash(before - cash.Value), name)
        )
        return ("Took $%s from @%s. They now have $%s."):format(
            formatCash(before - cash.Value),
            name,
            formatCash(cash.Value)
        )
    end
    local blocked, before, after = false, 0, 0
    playerDataStore:UpdateAsync("u" .. userId, function(save)
        if type(save) ~= "table" then
            return nil
        end
        if lockedElsewhere(save) then
            blocked = true
            return nil
        end
        before = tonumber(save.cash) or 0
        after = takeAll and 0 or math.max(0, before - amount)
        save.cash = after
        return save
    end)
    if blocked then
        error("@" .. name .. " is playing in another server right now. Try again when they leave.")
    end
    Leaderboard.SetGlobalCash(userId, after)
    warn(("[OwnerPunish] %s took $%s from @%s (offline)"):format(byPlayer.Name, formatCash(before - after), name))
    return ("Took $%s from @%s (offline). They now have $%s."):format(
        formatCash(before - after),
        name,
        formatCash(after)
    )
end

-- Full reset: save back to a brand-new player + removed from every global leaderboard.
function PlayerPunish.Wipe(byPlayer, nameOrId)
    local userId, name = resolvePlayer(nameOrId)
    assert(userId ~= byPlayer.UserId, "You can't wipe yourself here.")
    local onlinePlayer = Players:GetPlayerByUserId(userId)
    if onlinePlayer then
        onlinePlayer:Kick("Your progress was reset by the game owner.")
        -- wait for this server's leave-save + leaderboard flush to finish, so they can't write the old data back
        local waitStart = os.clock()
        repeat
            task.wait(1)
            local ok, save = pcall(playerDataStore.GetAsync, playerDataStore, "u" .. userId)
            if ok and not (type(save) == "table" and save.lock) then
                break
            end
        until os.clock() - waitStart > 20
        task.wait(2)
    end
    local blocked = false
    playerDataStore:UpdateAsync("u" .. userId, function(save)
        if lockedElsewhere(save) and not onlinePlayer then
            blocked = true
            return nil
        end
        return { v = 1, wipedAt = os.time(), wipedBy = byPlayer.UserId }
    end)
    if blocked then
        error("@" .. name .. " is playing in another server right now. Try again when they leave.")
    end
    local lbOk = Leaderboard.Forget(userId)
    warn(("[OwnerPunish] %s wiped @%s (save + leaderboards)"):format(byPlayer.Name, name))
    return "Wiped @"
        .. name
        .. ": fresh save"
        .. (lbOk and " and removed from all leaderboards." or ", but a leaderboard removal failed — try again.")
end

return PlayerPunish
