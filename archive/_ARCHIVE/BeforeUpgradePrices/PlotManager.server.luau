local Players=game:GetService("Players")
local plots=workspace:WaitForChild("Plots")
local templates=game.ServerStorage:WaitForChild("TempleUpgradeTemplates")
local assigned,waiting,cooldowns={},{},{}
local occupancy=require(script.Parent.TempleOccupancy)
local Construction=require(script.Parent:WaitForChild("Construction"):WaitForChild("ConstructionService"))
local profiles={}
local busy={}
local function save(player) end -- saving lives in PlayerDataService
local function load(player)
 local t=os.clock() while player.Parent==Players and not player:GetAttribute("DataLoaded") and os.clock()-t<30 do task.wait(0.2) end
 profiles[player]={level=math.clamp(tonumber(player:GetAttribute("SavedTempleLevel")) or 1,1,3)}
 return player.Parent==Players
end
local function refresh(plot)
 local level=plot:GetAttribute("TempleLevel") or 1
 local owner=plot:GetAttribute("OwnerUserId") or 0
 occupancy.Apply(plot,owner~=0)
 require(script.Parent.TempleSlotUnlocks).Refresh(plot)
 plot:SetAttribute("TempleBuilding",busy[plot]==true)
end
-- Moves anyone standing where the new floors/stairs are about to appear.
local function clearFootprint(plot)
 for _,visitor in Players:GetPlayers() do
  local c=visitor.Character local r=c and c:FindFirstChild("HumanoidRootPart")
  if r then local pos=plot.TempleAnchor.CFrame:PointToObjectSpace(r.Position)
   if math.abs(pos.X)<40 and math.abs(pos.Z)<35 and pos.Y>-2 and pos.Y<100 then c:PivotTo(plot.PlotSpawn.CFrame*CFrame.new(0,4,0)) end
  end
 end
end
local function build(plot,level,animate)
 local template=templates:FindFirstChild("Level"..level)
 if not template then return end
 local expectedOwner=plot:GetAttribute("OwnerUserId")
 local old=plot:FindFirstChild("Temple")
 local function swap(prepare)
  clearFootprint(plot)
  local clone=template:Clone()
  require(game.ReplicatedStorage.TempleAppearanceThemes).Apply(clone,plot:GetAttribute("TempleAppearance") or "Original")
  clone.Name="Temple" clone:PivotTo(plot.TempleAnchor.CFrame)
  clone.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
  if prepare then prepare(clone) end
  clone.Parent=plot
  if old then old:Destroy() end
  plot:SetAttribute("TempleLevel",level)
  clone:SetAttribute("OwnerUserId",plot:GetAttribute("OwnerUserId") or 0)
  refresh(plot)
  return clone
 end
 if not animate then return swap() end
 local key=plot.Name..":Temple"
 if plot:GetAttribute("OwnerUserId")~=expectedOwner or expectedOwner==0 then return end
 local clone=template:Clone()
 require(game.ReplicatedStorage.TempleAppearanceThemes).Apply(clone,plot:GetAttribute("TempleAppearance") or "Original")
 clone.Name="Temple"
 clone.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 clearFootprint(plot)
 local ok,model=Construction.Upgrade({key=key,owner=Players:GetPlayerByUserId(expectedOwner),kind="Temple",parent=plot,
  oldModel=old,template=clone,pivot=plot.TempleAnchor.CFrame,mode="auto"})
 clone:Destroy()
 if not ok then error(model) end
 plot:SetAttribute("TempleLevel",level)
 model:SetAttribute("OwnerUserId",plot:GetAttribute("OwnerUserId") or 0)
 refresh(plot)
 -- keep the upgrade lock (busy) until the construction animation has finished
 while Construction.IsBusy(key) do task.wait(.1) end
 return model
end
local function moveCharacter(player,character)
 local root=character:WaitForChild("HumanoidRootPart",10)
 local plot=assigned[player]
 if root and plot and player.Character==character then
  character:PivotTo(plot.PlotSpawn.CFrame*CFrame.new(0,4,0))
 end
end
local function upgrade(plot,player,adminActor)
 local admin=adminActor and adminActor.UserId==168774222
 if typeof(player)~="Instance" or not player:IsA("Player") or player.Parent~=Players then return end
 if busy[plot] or plot:GetAttribute("AppearanceBuilding") then return end
 if assigned[player]~=plot or plot:GetAttribute("OwnerUserId")~=player.UserId then return end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if not admin and (not root or not hum or hum.Health<=0 or (root.Position-plot.TempleAnchor.Position).Magnitude>80) then return end
 local level=plot:GetAttribute("TempleLevel") or 1
 if level>=3 or os.clock()<(cooldowns[plot] or 0) then return end
 if not require(script.Parent.TempleSlotUnlocks).CanUpgrade(plot) then return end
 busy[plot]=true
 cooldowns[plot]=os.clock()+2.4
 refresh(plot) -- locks the prompt for the duration of the animation
 player:SetAttribute("TempleLevel",level+1)
 if profiles[player] then profiles[player].level=level+1 end
 task.spawn(save,player)
 task.spawn(function()
  if plot:GetAttribute("OwnerUserId")~=player.UserId then return end
  local ok,err=pcall(build,plot,level+1,true)
  if plot:GetAttribute("OwnerUserId")~=player.UserId then return end
  if not ok then
   warn("Temple upgrade effect failed, falling back to instant build: "..tostring(err))
   pcall(build,plot,level+1,false)
  end
  busy[plot]=nil
  refresh(plot)
 end)
end
local function assign(player)
 if assigned[player] then return true end
 local sorted=plots:GetChildren()
 table.sort(sorted,function(a,b) return (a:GetAttribute("PlotId") or 0)<(b:GetAttribute("PlotId") or 0) end)
 for _,plot in sorted do
  if plot:GetAttribute("OwnerUserId")==0 then
   assigned[player]=plot plot:SetAttribute("OwnerUserId",player.UserId) plot:SetAttribute("OwnerName",player.DisplayName)
   build(plot,profiles[player].level,false)
   player:SetAttribute("PlotId",plot:GetAttribute("PlotId")) player:SetAttribute("TempleLevel",plot:GetAttribute("TempleLevel"))
   player:SetAttribute("WaitingForPlot",false) player.RespawnLocation=plot.PlotSpawn
   plot.Temple:SetAttribute("OwnerUserId",player.UserId)
   refresh(plot)
   player:SetAttribute("StartupSessionReady",true)
   if player.Character then task.spawn(moveCharacter,player,player.Character) end
   return true
  end
 end
 return false
end
local function serviceWaiting()
 for i=#waiting,1,-1 do if waiting[i].Parent~=Players then table.remove(waiting,i) end end
 while #waiting>0 do if assign(waiting[1]) then table.remove(waiting,1) else break end end
end
local function setup(plot) plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
  occupancy.ApplyPaths(plot,(plot:GetAttribute("OwnerUserId") or 0)~=0)
 end)
 plot.DescendantAdded:Connect(function(item)
  local fence=plot:FindFirstChild("FENCE")
  if fence and item:IsDescendantOf(fence) then
   task.defer(function() if plot.Parent then occupancy.ApplyPaths(plot,(plot:GetAttribute("OwnerUserId") or 0)~=0) end end)
  end
 end)

 plot:SetAttribute("OwnerUserId",0) plot:SetAttribute("OwnerName","")
 build(plot,1,false)


 local request=Instance.new("BindableEvent") request.Name="RequestUpgrade" request.Parent=plot
 request.Event:Connect(function(p,adminActor) upgrade(plot,p,adminActor) end)
 serviceWaiting()
end
for _,plot in plots:GetChildren() do setup(plot) end
plots.ChildAdded:Connect(setup)
local function joined(player)
 if assigned[player] or table.find(waiting,player) then return end
 player.CharacterAdded:Connect(function(c) moveCharacter(player,c) end)
 if not load(player) then return end
 if not assign(player) then
  player:SetAttribute("WaitingForPlot",true) table.insert(waiting,player)
 end
end
Players.PlayerRemoving:Connect(function(player)
 local snap=game:GetService("ServerStorage"):FindFirstChild("PlayerDataSnapshot") if snap then pcall(snap.Invoke,snap,player) end -- save before the plot is cleared
 local i=table.find(waiting,player) if i then table.remove(waiting,i) end
 task.spawn(function() save(player) profiles[player]=nil end)
 local plot=assigned[player] assigned[player]=nil
 if not plot then return end
 Construction.Cancel(plot.Name..":Temple")
 plot:SetAttribute("OwnerUserId",0) plot:SetAttribute("OwnerName","")
 plot.PlacedItems:ClearAllChildren()
 for _,slot in plot.Slots:GetChildren() do slot:SetAttribute("Occupied",false) slot.Platform.PlacePrompt.Enabled=true end
 cooldowns[plot]=nil busy[plot]=nil build(plot,1,false) serviceWaiting()
end)
Players.PlayerAdded:Connect(joined)
for _,p in Players:GetPlayers() do task.spawn(joined,p) end
