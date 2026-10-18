-- SaveRestore (owner only, used by the owner panel): list a player's older saves (Roblox keeps ~30 days) and put one back.
local Players = game:GetService("Players")
local DSS = game:GetService("DataStoreService")
local store = DSS:GetDataStore("PlayerData_v1")
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
local function summary(d)
    if type(d) ~= "table" then
        return { cash = 0, items = 0, placed = 0, temple = 1 }
    end
    return {
        cash = tonumber(d.cash) or 0,
        items = #(d.tools or {}),
        placed = #(d.placed or {}),
        temple = d.templeLevel or 1,
        slots = #(d.unlocked or {}),
    }
end
function M.List(who)
    local id, name = resolve(who)
    local key = "u" .. id
    local pages = store:ListVersionsAsync(key, Enum.SortDirection.Descending, nil, nil, 40)
    local out = {}
    for _, v in ipairs(pages:GetCurrentPage()) do
        if #out >= 25 then
            break
        end
        if not v.IsDeleted then
            local ok, d = pcall(store.GetVersionAsync, store, key, v.Version)
            local s = summary(ok and d or nil)
            s.version = v.Version
            s.time = math.floor(v.CreatedTime / 1000)
            table.insert(out, s)
        end
    end
    return { userId = id, name = name, online = Players:GetPlayerByUserId(id) ~= nil, versions = out }
end
function M.Restore(who, version)
    local id, name = resolve(who)
    local key = "u" .. id
    assert(type(version) == "string" and #version > 0, "Pick a save first.")
    local here = Players:GetPlayerByUserId(id)
    if here then
        error("@" .. name .. " is in this server. Kick them first (they rejoin after the restore).")
    end
    local ok, old = pcall(store.GetVersionAsync, store, key, version)
    assert(ok and type(old) == "table", "Couldn't read that save.")
    old.lock = nil
    old.restoredAt = os.time()
    old.savedAt = os.time()
    local blocked = false
    store:UpdateAsync(key, function(cur)
        if cur and cur.lock and os.time() - (cur.lock.t or 0) < 150 then
            blocked = true
            return nil
        end
        return old
    end)
    if blocked then
        error(
            "@" .. name .. " is playing in another server right now. Ask them to leave, wait 1 minute, then try again."
        )
    end
    local s = summary(old)
    return ("Restored @%s: $%d, %d items, %d placed, temple %d. They get it next time they join."):format(
        name,
        s.cash,
        s.items,
        s.placed,
        s.temple
    )
end
return M
