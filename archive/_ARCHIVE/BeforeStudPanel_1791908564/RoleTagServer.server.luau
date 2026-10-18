local Players = game:GetService("Players")
local ROLES = {
 [168774222] = "OWNER",
 [353101613] = "CO-OWNER",
 [10192461618] = "YOUTUBE", -- RofloxReal, verified username lookup
}
local function assign(player)
 player:SetAttribute("RoleTag", ROLES[player.UserId])
end
Players.PlayerAdded:Connect(assign)
for _,p in Players:GetPlayers() do assign(p) end
