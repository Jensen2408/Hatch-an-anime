local Players=game:GetService("Players")
local templates=game.ServerStorage:WaitForChild("IncubatorUpgradeTemplates")
local plots=workspace:WaitForChild("Plots")
local Construction=require(script.Parent:WaitForChild("Construction"):WaitForChild("ConstructionService"))
local function setup(plot)
 local sign=plot.TempleAnchor
 local chambers=plot:FindFirstChild("Chambers") or Instance.new("Folder")
 chambers.Name="Chambers"; chambers.Parent=plot
 local busy=false
 local generation=0
 local function owned(player,target,adminActor)
  if adminActor and adminActor.UserId==168774222 then return player and player.Parent==Players and plot:GetAttribute("OwnerUserId")==player.UserId end
  local root=player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  return player and player.Parent==Players and plot:GetAttribute("OwnerUserId")==player.UserId and root and (root.Position-plot.TempleAnchor.Position).Magnitude<=80 -- anywhere on own plot
 end
 local function refresh()
  local count=#chambers:GetChildren()
  plot:SetAttribute("ChamberCount",count)
  plot:SetAttribute("ChamberBuilding",busy)
 end
 local function anchor(index)
  return plot.TempleAnchor.CFrame*CFrame.new(-44,.25,15-(index-1)*17)*CFrame.Angles(0,-math.pi/2,0)
 end
 local upgrade
 local function wire(model,index)

  model.RequestIncubatorUpgrade.Event:Connect(function(player,adminActor) upgrade(player,index,adminActor) end)
 end
 local function make(index,level)
  local model=templates["Level"..level]:Clone()
  model.Name="Chamber"..index
  model:SetAttribute("ChamberIndex",index)
  model:SetAttribute("UpgradeLevel",level)
  model:SetAttribute("OwnerUserId",plot:GetAttribute("OwnerUserId"))
  model:SetAttribute("ClientEffectsReady",nil)
  model:PivotTo(anchor(index))
  local request=Instance.new("BindableEvent");request.Name="RequestIncubatorUpgrade";request.Parent=model
  return model
 end
 local function place(index,level,prepare)
  local model=make(index,level)
  wire(model,index)
  if prepare then prepare(model) end
  local old=chambers:FindFirstChild(model.Name)
  model.Parent=chambers
  if old then old:Destroy() end
  refresh()
  return model
 end
 local function construct(player,index,level,old)
  local expected=plot:GetAttribute("OwnerUserId")
  local token=generation
  local function valid() return plot.Parent~=nil and generation==token and plot:GetAttribute("OwnerUserId")==expected and expected~=0 end
  busy=true;refresh()
  if old then old:SetAttribute("UnderConstruction",true) end
  local key=plot.Name..":Chamber"..index
  local ok,err=pcall(function()
   if not valid() then return end
   local template=make(index,level)
   template.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
   if old then old.Name="Chamber"..index.."_Retiring" end -- avoid two models sharing a name while the old one sinks
   local built,model=Construction.Upgrade({key=key,owner=player,kind="Incubator",parent=chambers,oldModel=old,
    template=template,pivot=anchor(index),mode="replace"})
   template:Destroy()
   if not built then if old then old.Name="Chamber"..index end error(model) end
   wire(model,index)
   model:SetAttribute("UnderConstruction",true)
   refresh()
   while Construction.IsBusy(key) and valid() do task.wait(.1) end
  end)
  if generation~=token then return end
  if not ok and valid() then
   warn("Incubator construction recovered: "..tostring(err))
   local current=chambers:FindFirstChild("Chamber"..index)
   if not current or current:GetAttribute("UpgradeLevel")~=level then place(index,level) end
  end
  local current=chambers:FindFirstChild("Chamber"..index)
  if current then current:SetAttribute("UnderConstruction",nil) end
  busy=false;refresh()
 end
 upgrade=function(player,index,adminActor)
  if busy then return end
  local old=chambers:FindFirstChild("Chamber"..index)
  if not old then return end
  local level=old:GetAttribute("UpgradeLevel") or 1
  if level>=3 or old:GetAttribute("UnderConstruction") or (old:GetAttribute("Status") or "Ready")~="Ready" then return end
  if not owned(player,plot.TempleAnchor,adminActor) then return end
  -- Lock synchronously before dispatch: repeated clicks cannot queue upgrades.
  busy=true;refresh();old:SetAttribute("UnderConstruction",true)
  task.spawn(construct,player,index,level+1,old)
 end
 local function add(player,adminActor)
  if busy or #chambers:GetChildren()>=3 or not owned(player,sign,adminActor) then return end
  local index=#chambers:GetChildren()+1
  busy=true;refresh()
  task.spawn(construct,player,index,1,nil)
 end
 local function ownership()
  generation+=1;busy=false
  for i=1,3 do Construction.Cancel(plot.Name..":Chamber"..i) end
  chambers:ClearAllChildren()
  if (plot:GetAttribute("OwnerUserId") or 0)~=0 then place(1,1) end
  refresh()
 end


 local oldRequest=plot:FindFirstChild("RequestChamberUpgrade");if oldRequest then oldRequest:Destroy() end
 local request=Instance.new("BindableEvent");request.Name="RequestChamberUpgrade";request.Parent=plot;request.Event:Connect(add)
 plot:GetAttributeChangedSignal("OwnerUserId"):Connect(ownership)
 ownership()
end
for _,plot in ipairs(plots:GetChildren()) do task.spawn(setup,plot) end
plots.ChildAdded:Connect(function(plot) task.spawn(setup,plot) end)
