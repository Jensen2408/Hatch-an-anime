--[[ ServerScriptService.AdminRoles  (ModuleScript, server only)
Single source of truth for staff permissions. Owner = every action. Admin = only the actions in AdminRoles.AdminActions.

Who is authorized
  Owners  hard-coded UserIds in AdminRoles.Owners (168774222).
  Admins  hard-coded UserIds in AdminRoles.Admins (353101613, CO-OWNER) plus the ones added on the owner panel's Admins
          page (SetAdmin), persisted in DataStore "PanelAdmins_v1", key "list" = { [tostring(userId)] = name }.
How it is checked
  AdminRoles.Role(playerOrId) -> "Owner" | "Admin" | nil, from the tables above (pure lookup, never trusts the client).
  AdminRoles.Can(player, action) -> Owner always, Admin only when AdminActions[action] == true.
  Studio only: workspace attribute StudioTestRole = "Admin" makes an owner resolve as "Admin" (to test the admin view).
Replicated output
  Player attribute "PanelRole" (Role result) is set on join and after SetAdmin. Clients only use it to decide whether to
  build the panel UI; every server entry point calls Role / Can again.
Known issue (docs/PROJECT_AUDIT.md): the saved list is read once at server start, so a revoked admin keeps access on
other running servers until they restart. SetAdmin only updates this server's copy.
]]
-- ===== 1. Services and role tables =====
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local AdminRoles = {}
AdminRoles.Owners = { [168774222] = true }
AdminRoles.Admins = {
    [353101613] = true, -- CO-OWNER tag
}
-- Keys are OwnerPanel.Action names (see OwnerPanelServer), not OwnerControl dispatch names.
-- Actions an Admin may use (everything else is owner-only)
AdminRoles.AdminActions = {
    Snapshot = true,
    SpawnEgg = true,
    EggShower = true,
    StartEvent = true,
    StopEvent = true,
    StartNight = true,
    StopNight = true,
    SetSpawnInterval = true,
    SendHome = true,
    Bring = true,
    GoTo = true,
    SendToPlayer = true,
    Respawn = true,
    Kick = true,
    Announce = true,
    JoinStaffServer = true,
    ReturnToPublic = true,
    AnnounceUpdate = true,
}

-- ===== 2. Panel-added admins (DataStore, loaded once at require time; GetAsync yields) =====
local savedAdmins = {} -- [userId]=name (from DataStore)
local adminStore
do
    local ok, dataStore = pcall(DataStoreService.GetDataStore, DataStoreService, "PanelAdmins_v1")
    adminStore = ok and dataStore or nil
end
pcall(function()
    local data = adminStore and adminStore:GetAsync("list")
    if type(data) == "table" then
        for userIdKey, adminName in pairs(data) do
            savedAdmins[tonumber(userIdKey)] = adminName
        end
    end
end)

-- ===== 3. Public API =====
-- playerOrId: a Player instance or a UserId (number or numeric string).
function AdminRoles.Role(playerOrId)
    local userId = typeof(playerOrId) == "Instance" and playerOrId.UserId or tonumber(playerOrId)
    if not userId then
        return nil
    end
    -- Studio testing only: workspace attribute StudioTestRole="Admin" makes the owner act as an admin
    if
        game:GetService("RunService"):IsStudio()
        and AdminRoles.Owners[userId]
        and workspace:GetAttribute("StudioTestRole") == "Admin"
    then
        return "Admin"
    end
    if AdminRoles.Owners[userId] then
        return "Owner"
    end
    if AdminRoles.Admins[userId] or savedAdmins[userId] then
        return "Admin"
    end
    return nil
end
function AdminRoles.Can(player, action)
    local role = AdminRoles.Role(player)
    return role == "Owner" or (role == "Admin" and AdminRoles.AdminActions[action] == true)
end
-- For the owner panel's Admins page. fixed = true means hard-coded here (cannot be removed from the panel).
function AdminRoles.List()
    local list = {}
    for userId in pairs(AdminRoles.Admins) do
        table.insert(list, { userId = userId, name = savedAdmins[userId] or tostring(userId), fixed = true })
    end
    for userId, name in pairs(savedAdmins) do
        if not AdminRoles.Admins[userId] then
            table.insert(list, { userId = userId, name = name, fixed = false })
        end
    end
    return list
end
-- Refreshes the PanelRole attribute if that user is in this server.
local function publishRole(userId)
    local player = Players:GetPlayerByUserId(userId)
    if player then
        player:SetAttribute("PanelRole", AdminRoles.Role(player))
    end
end
-- Owner-only (OwnerPanelServer checks the caller is Owner before calling). Updates this server immediately and
-- the DataStore list; returns whether the DataStore write succeeded. assert messages are shown to the owner.
function AdminRoles.SetAdmin(userId, name, isAdmin)
    userId = tonumber(userId)
    assert(userId and userId > 0 and userId % 1 == 0, "Enter a numeric User ID.")
    assert(not AdminRoles.Owners[userId], "The owner can't be changed.")
    assert(
        not (AdminRoles.Admins[userId] and not isAdmin),
        "That admin is in the AdminRoles script; remove them there."
    )
    savedAdmins[userId] = isAdmin and (name or tostring(userId)) or nil
    local persisted = false
    if adminStore then
        persisted = pcall(function()
            adminStore:UpdateAsync("list", function(old)
                old = type(old) == "table" and old or {}
                old[tostring(userId)] = isAdmin and (name or tostring(userId)) or nil
                return old
            end)
        end)
    end
    publishRole(userId)
    return persisted
end

-- ===== 4. Publish PanelRole for every player =====
local function onPlayerAdded(player)
    player:SetAttribute("PanelRole", AdminRoles.Role(player))
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
    onPlayerAdded(player)
end
return AdminRoles
