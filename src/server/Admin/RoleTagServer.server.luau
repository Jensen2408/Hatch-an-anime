--[[ ServerScriptService.RoleTagServer  (Script)
Sets the player attribute "RoleTag" (OWNER / CO-OWNER / YOUTUBE from the hard-coded list below, else ADMIN for any
AdminRoles admin, else nil). Purely cosmetic: chat / overhead tags read it, no permission depends on it.
Re-evaluated when "PanelRole" changes (AdminRoles.SetAdmin). UserIds here duplicate AdminRoles / OwnerOverheadBanner.
]]
local Players = game:GetService("Players")
local AdminRoles = require(script.Parent:WaitForChild("AdminRoles"))
-- Fixed tags win over the ADMIN tag.
local TAG_BY_USER_ID = {
    [168774222] = "OWNER",
    [353101613] = "CO-OWNER",
    [10192461618] = "YOUTUBE", -- RofloxReal, verified username lookup
}
local function assignRoleTag(player)
    player:SetAttribute(
        "RoleTag",
        TAG_BY_USER_ID[player.UserId] or (AdminRoles.Role(player) == "Admin" and "ADMIN" or nil)
    )
end
local function watchPlayer(player)
    assignRoleTag(player)
    player:GetAttributeChangedSignal("PanelRole"):Connect(function()
        assignRoleTag(player)
    end)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, player in Players:GetPlayers() do
    watchPlayer(player)
end
