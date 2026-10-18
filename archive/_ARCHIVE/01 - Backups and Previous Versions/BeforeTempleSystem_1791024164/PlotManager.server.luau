local Players = game:GetService("Players")
local plots = workspace:WaitForChild("Plots"):GetChildren()
table.sort(plots, function(a,b) return a:GetAttribute("PlotId") < b:GetAttribute("PlotId") end)
local assignments = {}
local waiting = {}
local function updateLabel(plot, text)
 local gui = plot.OwnerSign.OwnerGui
 gui.OwnerText.Text = text
 local userId = plot:GetAttribute("OwnerUserId") or 0
 gui.OwnerAvatar.Visible = userId ~= 0
 gui.OwnerAvatar.Image = userId ~= 0 and ("rbxthumb://type=AvatarHeadShot&id=" .. userId .. "&w=150&h=150") or ""
end
for _,plot in ipairs(plots) do
 plot:SetAttribute("OwnerUserId", 0)
 plot:SetAttribute("OwnerName", "")
 updateLabel(plot, "Available plot")
end
local function moveCharacter(player, character)
 local root = character:WaitForChild("HumanoidRootPart", 10)
 local plot = assignments[player]
 if root and plot and player.Character == character then
  character:PivotTo(plot.PlotSpawn.CFrame * CFrame.new(0, 4, 0))
 end
end
local function assign(player)
 if assignments[player] then return true end
 for _,plot in ipairs(plots) do
  if plot:GetAttribute("OwnerUserId") == 0 then
   assignments[player] = plot
   plot:SetAttribute("OwnerUserId", player.UserId)
   plot:SetAttribute("OwnerName", player.Name)
   player:SetAttribute("PlotId", plot:GetAttribute("PlotId"))
   player:SetAttribute("WaitingForPlot", false)
   player.RespawnLocation = plot.PlotSpawn
   updateLabel(plot, player.DisplayName .. "'s Plot")
   if player.Character then task.spawn(moveCharacter, player, player.Character) end
   return true
  end
 end
 return false
end
local function joined(player)
 if assignments[player] or table.find(waiting, player) then return end
 player.CharacterAdded:Connect(function(character) moveCharacter(player, character) end)
 if not assign(player) then
  player:SetAttribute("WaitingForPlot", true)
  table.insert(waiting, player)
 end
end
Players.PlayerRemoving:Connect(function(player)
 local index = table.find(waiting, player)
 if index then table.remove(waiting,index) end
 local plot = assignments[player]
 if not plot then return end
 assignments[player] = nil
 player.RespawnLocation = nil
 plot:SetAttribute("OwnerUserId", 0)
 plot:SetAttribute("OwnerName", "")
 plot.PlacedItems:ClearAllChildren()
 updateLabel(plot, "Available plot")
 while #waiting > 0 do
  local nextPlayer = table.remove(waiting,1)
  if nextPlayer.Parent == Players then
   assign(nextPlayer)
   break
  end
 end
end)
Players.PlayerAdded:Connect(joined)
for _,player in ipairs(Players:GetPlayers()) do joined(player) end
