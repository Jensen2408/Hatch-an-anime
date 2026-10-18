local Carry=require(script.Parent.TwoHandItemCarryService)
Carry.Init()
local last={}
game.ReplicatedStorage.DropHeldItem.OnServerEvent:Connect(function(p)
 if os.clock()-(last[p] or -math.huge)<.5 then return end
 last[p]=os.clock()
 if p:GetAttribute("RiverEggCarryId") then require(script.Parent.RiverEggCarryService).Drop(p)
 else
 local c=p.Character local tool=c and c:FindFirstChildOfClass("Tool")
 if tool then Carry.DropTool(p,tool) end
 end
end)
game.Players.PlayerRemoving:Connect(function(p) last[p]=nil end)
