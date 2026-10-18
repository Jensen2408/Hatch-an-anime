local Players=game:GetService("Players")
local plots=workspace:WaitForChild("Plots")
local templates=game.ServerStorage:WaitForChild("TempleUpgradeTemplates")
local assigned,waiting,cooldowns={},{},{}
local occupancy=require(script.Parent.TempleOccupancy)
local store=game:GetService("DataStoreService"):GetDataStore("TempleProgress_v1")
local profiles={}
local function save(player)
 local data=profiles[player]
 if not data or not data.loaded then return end
 local level=data.level
 local ok,err
 for attempt=1,3 do
  ok,err=pcall(function()
   store:UpdateAsync("Player_"..player.UserId,function(old)
    old=type(old)=="table" and old or {}
    old.TempleLevel=math.max(tonumber(old.TempleLevel) or 1,level)
    old.Version=1
    return old
   end)
  end)
  if ok then break end
  task.wait(attempt)
 end
 player:SetAttribute("TempleSaveStatus",ok and "Saved" or "Save failed")
 if not ok then warn("Temple save failed for "..player.UserId..": "..tostring(err)) end
end
local function load(player)
 player:SetAttribute("TempleSaveStatus","Loading")
 local ok,data
 for attempt=1,3 do
  ok,data=pcall(function() return store:GetAsync("Player_"..player.UserId) end)
  if ok then break end
  task.wait(attempt)
 end
 if player.Parent~=Players then return false end
 profiles[player]={loaded=ok,level=ok and math.clamp(math.floor(tonumber(type(data)=="table" and data.TempleLevel) or 1),1,3) or 1}
 player:SetAttribute("TempleSaveStatus",ok and "Loaded" or "Unavailable — temporary session")
 if not ok then warn("Temple data unavailable; this session will not overwrite saved progress: "..tostring(data)) end
 return true
end
local function refresh(plot)
 local level=plot:GetAttribute("TempleLevel") or 1
 local owner=plot:GetAttribute("OwnerUserId") or 0
 occupancy.Apply(plot,owner~=0)
 local sign=plot.OwnerSign local gui=sign.OwnerGui
 gui.OwnerText.Text=owner~=0 and ((plot:GetAttribute("OwnerName") or "Player").."'s Temple") or "Available temple"
 gui.OwnerAvatar.Visible=owner~=0
 gui.OwnerAvatar.Image=owner~=0 and ("rbxthumb://type=AvatarHeadShot&id="..owner.."&w=150&h=150") or ""
 gui.UpgradeText.Text=level<3 and ("TEMPLE "..level.." → "..(level+1).."\nUPGRADE • FREE") or "TEMPLE 3\nFULLY UPGRADED"
 sign.UpgradePrompt.Enabled=owner~=0 and level<3
 sign.UpgradePrompt.ObjectText="Temple "..level..(level<3 and (" → "..(level+1)) or "")
 sign.ClickDetector.MaxActivationDistance=owner~=0 and level<3 and 18 or 0
end
local function build(plot,level)
 local clone=templates:FindFirstChild("Level"..level):Clone()
 clone.Name="Temple" clone:PivotTo(plot.TempleAnchor.CFrame)
 local old=plot:FindFirstChild("Temple")
 clone.Parent=plot
 if old then old:Destroy() end
 plot:SetAttribute("TempleLevel",level)
 clone:SetAttribute("OwnerUserId",plot:GetAttribute("OwnerUserId") or 0)
 refresh(plot)
end
local function moveCharacter(player,character)
 local root=character:WaitForChild("HumanoidRootPart",10)
 local plot=assigned[player]
 if root and plot and player.Character==character then
  character:PivotTo(plot.PlotSpawn.CFrame*CFrame.new(0,4,0))
 end
end
local function upgrade(plot,player)
 if typeof(player)~="Instance" or not player:IsA("Player") or player.Parent~=Players then return end
 if assigned[player]~=plot or plot:GetAttribute("OwnerUserId")~=player.UserId then return end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.Health<=0 or (root.Position-plot.OwnerSign.Position).Magnitude>20 then return end
 local level=plot:GetAttribute("TempleLevel") or 1
 if level>=3 or os.clock()<(cooldowns[plot] or 0) then return end
 cooldowns[plot]=os.clock()+.75
 -- Keep everyone clear of newly appearing floors/stairs during the swap.
 for _,visitor in Players:GetPlayers() do
  local c=visitor.Character local r=c and c:FindFirstChild("HumanoidRootPart")
  if r then local pos=plot.TempleAnchor.CFrame:PointToObjectSpace(r.Position)
   if math.abs(pos.X)<40 and math.abs(pos.Z)<35 and pos.Y>-2 and pos.Y<100 then c:PivotTo(plot.PlotSpawn.CFrame*CFrame.new(0,4,0)) end
  end
 end
 build(plot,level+1)
 player:SetAttribute("TempleLevel",level+1)
 profiles[player].level=level+1
 task.spawn(save,player)
end
local function assign(player)
 if assigned[player] then return true end
 local sorted=plots:GetChildren()
 table.sort(sorted,function(a,b) return (a:GetAttribute("PlotId") or 0)<(b:GetAttribute("PlotId") or 0) end)
 for _,plot in sorted do
  if plot:GetAttribute("OwnerUserId")==0 then
   assigned[player]=plot plot:SetAttribute("OwnerUserId",player.UserId) plot:SetAttribute("OwnerName",player.DisplayName)
   build(plot,profiles[player].level)
   player:SetAttribute("PlotId",plot:GetAttribute("PlotId")) player:SetAttribute("TempleLevel",plot:GetAttribute("TempleLevel"))
   player:SetAttribute("WaitingForPlot",false) player.RespawnLocation=plot.PlotSpawn
   plot.Temple:SetAttribute("OwnerUserId",player.UserId)
   refresh(plot)
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
local function setup(plot)
 plot:SetAttribute("OwnerUserId",0) plot:SetAttribute("OwnerName","")
 build(plot,1)
 plot.OwnerSign.ClickDetector.MouseClick:Connect(function(p) upgrade(plot,p) end)
 plot.OwnerSign.UpgradePrompt.Triggered:Connect(function(p) upgrade(plot,p) end)
 local request=Instance.new("BindableEvent") request.Name="RequestUpgrade" request.Parent=plot
 request.Event:Connect(function(p) upgrade(plot,p) end)
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
 local i=table.find(waiting,player) if i then table.remove(waiting,i) end
 task.spawn(function() save(player) profiles[player]=nil end)
 local plot=assigned[player] assigned[player]=nil
 if not plot then return end
 plot:SetAttribute("OwnerUserId",0) plot:SetAttribute("OwnerName","")
 plot.PlacedItems:ClearAllChildren()
 for _,slot in plot.Slots:GetChildren() do slot:SetAttribute("Occupied",false) slot.Platform.PlacePrompt.Enabled=true end
 cooldowns[plot]=nil build(plot,1) serviceWaiting()
end)
Players.PlayerAdded:Connect(joined)
for _,p in Players:GetPlayers() do task.spawn(joined,p) end
game:BindToClose(function()
 local pending=0
 for p in profiles do pending+=1 task.spawn(function() save(p) pending-=1 end) end
 local deadline=os.clock()+25
 while pending>0 and os.clock()<deadline do task.wait(.1) end
end)
