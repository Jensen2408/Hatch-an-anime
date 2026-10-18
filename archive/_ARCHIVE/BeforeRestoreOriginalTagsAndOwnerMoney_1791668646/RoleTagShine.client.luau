local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local active = setmetatable({}, {__mode = "k"})
local function animate(object)
 if not object:IsA("UIGradient") or object.Name ~= "RoleShine" or active[object] then return end
 local gui = object:FindFirstAncestorWhichIsA("BillboardGui")
 if not gui or gui.Name ~= "OwnerBanner" then return end
 active[object] = true
 task.spawn(function()
  while object:IsDescendantOf(workspace) do
   object.Offset = Vector2.new(-1, 0)
   local tween = TweenService:Create(object, TweenInfo.new(1.15, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), {Offset = Vector2.new(1, 0)})
   local connection = object.Destroying:Connect(function() tween:Cancel() end)
   tween:Play()
   tween.Completed:Wait()
   connection:Disconnect()
   task.wait(2.4)
  end
  active[object] = nil
 end)
end
local function characterAdded(character)
 for _, object in character:GetDescendants() do animate(object) end
 character.DescendantAdded:Connect(animate)
end
local function playerAdded(player)
 player.CharacterAdded:Connect(characterAdded)
 if player.Character then characterAdded(player.Character) end
end
Players.PlayerAdded:Connect(playerAdded)
for _, player in Players:GetPlayers() do playerAdded(player) end
