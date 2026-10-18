-- SaveRestore (owner only, used by the owner panel): list a player's older saves (Roblox keeps ~30 days) and put one back.
-- Runtime: ModuleScript required by OwnerPanelServer (handlers SaveRestoreList / SaveRestore). Errors are raised with
-- player-facing messages; the caller pcalls and shows them.
-- Works on the same DataStore / key / schema as PlayerDataService ("PlayerData_v1", key "u<UserId>"); see the schema
-- header there. A restore clears `lock`, sets `restoredAt` + `savedAt` and refuses while another server holds a fresh
-- lock (150 s = PlayerDataService LOCK_TIMEOUT, duplicated here).
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local store = DataStoreService:GetDataStore("PlayerData_v1")
local SaveRestore = {}

-- Accepts a User ID (number or numeric string) or a username; returns userId, displayName. Errors if not found.
local function resolvePlayer(who)
    local userId = tonumber(who)
    if not userId and type(who) == "string" and #who > 0 then
        local player = Players:FindFirstChild(who)
        if player then
            return player.UserId, player.Name
        end
        local ok, foundId = pcall(Players.GetUserIdFromNameAsync, Players, who)
        if ok then
            userId = foundId
        end
    end
    if not userId then
        error("Couldn't find that player. Use their exact username or User ID.")
    end
    local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
    return userId, ok and name or tostring(userId)
end

-- Short summary of a saved table for the owner panel list (no `slots` field when the save is unreadable).
local function summarize(saved)
    if type(saved) ~= "table" then
        return { cash = 0, items = 0, placed = 0, temple = 1 }
    end
    return {
        cash = tonumber(saved.cash) or 0,
        items = #(saved.tools or {}),
        placed = #(saved.placed or {}),
        temple = saved.templeLevel or 1,
        slots = #(saved.unlocked or {}),
    }
end

-- Newest first, at most 25 non-deleted versions (from the first page of 40).
function SaveRestore.List(who)
    local userId, name = resolvePlayer(who)
    local key = "u" .. userId
    local pages = store:ListVersionsAsync(key, Enum.SortDirection.Descending, nil, nil, 40)
    local versions = {}
    for _, versionInfo in ipairs(pages:GetCurrentPage()) do
        if #versions >= 25 then
            break
        end
        if not versionInfo.IsDeleted then
            local ok, saved = pcall(store.GetVersionAsync, store, key, versionInfo.Version)
            local summary = summarize(ok and saved or nil)
            summary.version = versionInfo.Version
            summary.time = math.floor(versionInfo.CreatedTime / 1000)
            table.insert(versions, summary)
        end
    end
    return { userId = userId, name = name, online = Players:GetPlayerByUserId(userId) ~= nil, versions = versions }
end

-- Writes an old version back as the current save. The player must not be in this server (their live session would
-- overwrite it on leave) nor hold a fresh lock in another one.
function SaveRestore.Restore(who, version)
    local userId, name = resolvePlayer(who)
    local key = "u" .. userId
    assert(type(version) == "string" and #version > 0, "Pick a save first.")
    local playerHere = Players:GetPlayerByUserId(userId)
    if playerHere then
        error("@" .. name .. " is in this server. Kick them first (they rejoin after the restore).")
    end
    local ok, oldSave = pcall(store.GetVersionAsync, store, key, version)
    assert(ok and type(oldSave) == "table", "Couldn't read that save.")
    oldSave.lock = nil
    oldSave.restoredAt = os.time()
    oldSave.savedAt = os.time()
    local blocked = false
    store:UpdateAsync(key, function(current)
        if current and current.lock and os.time() - (current.lock.t or 0) < 150 then
            blocked = true
            return nil
        end
        return oldSave
    end)
    if blocked then
        error(
            "@" .. name .. " is playing in another server right now. Ask them to leave, wait 1 minute, then try again."
        )
    end
    local summary = summarize(oldSave)
    return ("Restored @%s: $%d, %d items, %d placed, temple %d. They get it next time they join."):format(
        name,
        summary.cash,
        summary.items,
        summary.placed,
        summary.temple
    )
end
return SaveRestore
