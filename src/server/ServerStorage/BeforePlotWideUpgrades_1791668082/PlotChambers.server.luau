local Players=game:GetService("Players")
local templates=game.ServerStorage:WaitForChild("IncubatorUpgradeTemplates")
local plots=workspace:WaitForChild("Plots")
local Construction=require(script.Parent:WaitForChild("Construction"):WaitForChild("ConstructionService"))
local function setup(plot)
 local sign=plot:WaitForChild("ChamberYard"):WaitForChild("ChamberUpgradeSign")
 local chambers=plot:FindFirstChild("Chambers") or Instance.new("Folder")
 chambers.Name="Chambers"; chambers.Parent=plot
 local busy=false
 local generation=0
 local function owned(player,target,adminActor)
  if adminActor and adminActor.UserId==168774222 then return player and player.Parent==Players and plot:GetAttribute("OwnerUserId")==player.UserId end
  local root=player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  return player and player.Parent==Players and plot:GetAttribute("OwnerUserId")==player.UserId and root and (root.Position-target.Position).Magnitude<=20
 end
 local function refresh()
  local count=#chambers:GetChildren()
  local open=(plot:GetAttribute("OwnerUserId") or 0)~=0 and count<3 and not busy
  sign.SurfaceGui.Label.Text=count<3 and ("ADD INCUBATOR\nFREE • "..count.." / 3") or "3 INCUBATORS\nUPGRADE EACH MACHINE"
  sign.ProximityPrompt.Enabled=open
  sign.ClickDetector.MaxActivationDistance=open and 18 or 0
  plot:SetAttribute("ChamberCount",count)
  plot:SetAttribute("ChamberBuilding",busy)
 end
 local function anchor(index)
  return plot.TempleAnchor.CFrame*CFrame.new(-44,.25,15-(index-1)*17)*CFrame.Angles(0,-math.pi/2,0)
 end
 local upgrade
 local function wire(model,index)
  model.IncubatorUpgradeControl.UpgradeIncubator.Triggered:Connect(function(player) upgrade(player,index) end)
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
  local panel=Instance.new("Part")
  panel.Transparency=1;panel.CanCollide=false;panel.CanTouch=false;panel.CanQuery=false;panel.Name="IncubatorUpgradeControl";panel.Size=Vector3.new(1.5,.75,.25)
  panel.CFrame=anchor(index)*CFrame.new(-3.25,2.5,-4.75)
  panel.Color=Color3.fromRGB(61,46,54);panel.Anchored=true;panel.Parent=model
  local prompt=Instance.new("ProximityPrompt")
  prompt.Name="UpgradeIncubator";prompt.ActionText="Upgrade • FREE"
  prompt.ObjectText="Incubator "..index.." • Level "..level..(level<3 and (" → "..level+1) or " • MAX")
  prompt.MaxActivationDistance=10;prompt.RequiresLineOfSight=false;prompt.HoldDuration=.35
  prompt.Enabled=level<3;prompt.Parent=panel
  local gui=Instance.new("SurfaceGui");gui.Enabled=false;gui.Face=Enum.NormalId.Front;gui.CanvasSize=Vector2.new(512,256);gui.Parent=panel
  local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,1);text.BackgroundTransparency=1;text.TextScaled=true;text.Font=Enum.Font.GothamBold;text.TextColor3=Color3.fromRGB(212,187,148)
  text.Text=level<3 and ("UPGRADE\nLV "..level.." → "..level+1) or "LEVEL 3\nMAX";text.Parent=gui
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
  if not owned(player,old.IncubatorUpgradeControl,adminActor) then return end
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
 sign.ProximityPrompt.Triggered:Connect(add)
 sign.ClickDetector.MouseClick:Connect(add)
 local oldRequest=plot:FindFirstChild("RequestChamberUpgrade");if oldRequest then oldRequest:Destroy() end
 local request=Instance.new("BindableEvent");request.Name="RequestChamberUpgrade";request.Parent=plot;request.Event:Connect(add)
 plot:GetAttributeChangedSignal("OwnerUserId"):Connect(ownership)
 ownership()
end
for _,plot in ipairs(plots:GetChildren()) do task.spawn(setup,plot) end
plots.ChildAdded:Connect(function(plot) task.spawn(setup,plot) end)
