local Players=game:GetService("Players")
local function give(player)
 if player.UserId~=168774222 then return end
 local bag=player:WaitForChild("Backpack")
 if bag:FindFirstChild("Golden Pirate Egg")then return end
 local template=game.ServerStorage.AuxEggTemplates["Golden Pirate"]
 local tool=Instance.new("Tool") tool.Name="Golden Pirate Egg" tool.ToolTip="Golden Luffy • incubator test" tool.CanBeDropped=false
 tool:SetAttribute("EggType","Golden Pirate")tool:SetAttribute("Golden",true)tool:SetAttribute("HatchSeconds",10)tool:SetAttribute("Price",0)
 local visual=template:Clone()visual.Name="Egg"visual:ScaleTo(visual:GetScale()*.5)visual:PivotTo(CFrame.new())visual.Parent=tool
 local handle=Instance.new("Part")handle.Name="Handle"handle.Size=Vector3.one handle.Transparency=1 handle.CanCollide=false handle.CanTouch=false handle.Massless=true handle.Parent=tool
 for _,p in ipairs(visual:GetDescendants())do if p:IsA("BasePart")then p.Anchored=false p.CanCollide=false p.CanTouch=false p.Massless=true local w=Instance.new("WeldConstraint")w.Part0=handle w.Part1=p w.Parent=handle end end
 tool.Parent=bag
end
Players.PlayerAdded:Connect(function(player)player.CharacterAdded:Connect(function()task.defer(give,player)end)if player.Character then task.defer(give,player)end end)
for _,p in ipairs(Players:GetPlayers())do give(p)end
