local Players = game:GetService("Players")
local Roles = require(script.Parent:WaitForChild("AdminRoles"))
local ROLES = {
    [168774222] = "OWNER",
    [353101613] = "CO-OWNER",
    [10192461618] = "YOUTUBE", -- RofloxReal, verified username lookup
}
local function assign(player)
    player:SetAttribute("RoleTag", ROLES[player.UserId] or (Roles.Role(player) == "Admin" and "ADMIN" or nil))
end
local function hook(p)
    assign(p)
    p:GetAttributeChangedSignal("PanelRole"):Connect(function()
        assign(p)
    end)
end
Players.PlayerAdded:Connect(hook)
for _, p in Players:GetPlayers() do
    hook(p)
end
