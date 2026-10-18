
local TweenService=game:GetService("TweenService")
local Players=game:GetService("Players")
local Collection=game:GetService("CollectionService")
local h=script.Parent
local frame=h:GetPivot()*CFrame.new(-22.75,-26,-92)
local m=h:WaitForChild("LiquidSystemAndTrim")
local button=m.HatchButton
local prompt=button.ProximityPrompt
local door=h.LoadingDoor
local liquid=m.TankLiquid
local text=m.TimerAnchor.CycleTimer.Status
local camera=game.ReplicatedStorage:WaitForChild("CinematicHatchCue")
local Rewards=require(game.ServerScriptService:WaitForChild("EggCharacterRewards"))
local rest,doorRest=button.CFrame,door.CFrame
local fullSize,fullCF=liquid.Size,liquid.CFrame
local busy=false
local waitingOwner,startRequested
local complete=Instance.new("BindableEvent");complete.Name="HatchCycleCompleted";complete.Parent=h
local function tween(p,t,props)
 local tw=TweenService:Create(p,TweenInfo.new(t,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),props);tw:Play();return tw
end
local function say(state,message)
 h:SetAttribute("Status",state);text.Text=message;m.TimerAnchor.CycleTimer.Enabled=state~="Ready" or message=="EQUIP AN EGG FIRST"
end
local function valid(player,range)
 if not player then return true end
 local plot=h.Parent and h.Parent.Parent
 local char=player.Character
 local root=char and char:FindFirstChild("HumanoidRootPart")
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 return player.Parent==Players and plot and plot:GetAttribute("OwnerUserId")==player.UserId and root and hum and hum.Health>0 and (root.Position-button.Position).Magnitude<(range or 20)
end
local function press()
 tween(button,.1,{CFrame=rest+frame:VectorToWorldSpace(Vector3.new(0,0,.25))})
 task.delay(.13,function()if button.Parent then tween(button,.18,{CFrame=rest})end end)
end
local function cycle(player)
 if h:GetAttribute("UnderConstruction") then return end
 if busy then
  if h:GetAttribute("Status")=="Loaded" and player==waitingOwner and valid(player,20) and not startRequested then
   startRequested=true;prompt.Enabled=false;press()
  end
  return
 end
 if not valid(player,20) then return end
 local tool,source
 if player then
  for _,v in player.Character:GetChildren()do if v:IsA("Tool") and v.Name:lower():find("egg") then tool=v;break end end
  source=tool and tool:FindFirstChild("Egg")
 else source=game.ServerStorage:FindFirstChild("WaterfallEggTemplate") end
 if not source or not source:IsA("Model") then
  say("Ready","EQUIP AN EGG FIRST")
  task.delay(2,function()if not busy then say("Ready","HOLD AN EGG • INSERT")end end);return
 end
 local rewardTemplate,rewardId=Rewards.Resolve(tool,source)
 if not rewardTemplate then say("Ready","NO CHARACTER FOR "..tostring(rewardId):upper());return end
 busy=true;prompt.Enabled=false;waitingOwner=player;startRequested=false
 local visual,pickupAnchor
 local enabled=tool and tool.Enabled
 local focusSent=false
 local ok,err=xpcall(function()
  local seconds=tonumber(tool and tool:GetAttribute("HatchSeconds")) or h:GetAttribute("PreviewHatchSeconds") or 10
  seconds=math.clamp(seconds,1,3600)
  if tool then
   tool:SetAttribute("Incubating",true)
   player.Character.Humanoid:UnequipTools()
   local held=player:FindFirstChild("IncubatorHeldEggs") or Instance.new("Folder");held.Name="IncubatorHeldEggs";held.Parent=player
   tool.Enabled=false;tool.Parent=held
  end
  visual=source:Clone();visual.Name="IncubatingEgg"
  for _,v in visual:GetDescendants()do
   if v:IsA("LuaSourceContainer") or v:IsA("ProximityPrompt") or v:IsA("BillboardGui")then v:Destroy()
   elseif v:IsA("BasePart")then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false end
  end
  local _,size=visual:GetBoundingBox()
  visual:ScaleTo(visual:GetScale()*math.min(2.5/size.Y,2.6/size.X,2.6/size.Z))
  local box=visual:GetBoundingBox()
  visual.PrimaryPart=nil;visual.WorldPivot=CFrame.new(box.Position)
  local inside=frame*CFrame.new(22.75,34.125,92)
  visual:PivotTo(inside)
  visual:SetAttribute("ChamberHome",inside)
  local appearances={}
  for _,p in visual:GetDescendants()do if p:IsA("BasePart")then appearances[p]=p.Transparency;p.Transparency=1 end end
  visual.Parent=h
  say("Loading","INSERTING EGG");press()
  h:SetAttribute("TeleportPulse",workspace:GetServerTimeNow())
  task.wait(.22)
  for p,alpha in appearances do if p.Parent then tween(p,.35,{Transparency=alpha})end end
  task.wait(.45)
  say("Loaded","EGG LOADED • PRESS HATCH")
  prompt.ActionText="Hatch";prompt.ObjectText=rewardId.." Egg";prompt.Enabled=player~=nil
  local timeout=os.clock()+120
  while player and not startRequested do
   if not valid(player,100) or not h:IsDescendantOf(workspace) or os.clock()>timeout then return end
   task.wait(.08)
  end
  prompt.Enabled=false
  if not valid(player,100)then return end
  local epoch=workspace:GetServerTimeNow()
  h:SetAttribute("Hatching",true);h:SetAttribute("HatchStart",epoch);h:SetAttribute("HatchDuration",seconds)
  h:SetAttribute("CycleEnd",epoch+seconds)
  visual:SetAttribute("HatchEpoch",epoch);visual:SetAttribute("HatchDuration",seconds)
  visual:SetAttribute("HatchOwner",player and player.UserId or 0)
  Collection:AddTag(visual,"CinematicEggHatch")
  if player then camera:FireClient(player,"Start",h,inside,seconds);focusSent=true end
  say("Incubating","AWAKENING")
  tween(liquid,seconds,{Size=Vector3.new(.5,fullSize.Y,fullSize.Z),CFrame=fullCF-Vector3.new(0,(fullSize.X-.5)/2,0)})
  while workspace:GetServerTimeNow()<epoch+seconds do
   if not valid(player,100)or not h:IsDescendantOf(workspace)then return end
   local progress=math.clamp((workspace:GetServerTimeNow()-epoch)/seconds,0,1)
   h:SetAttribute("CrackStage",math.min(4,math.floor(progress*4)))
   text.Text=progress<.3 and "AWAKENING..." or progress<.65 and "SHELL CRACKING..." or "READY TO BREAK..."
   task.wait(.1)
  end
  h:SetAttribute("Hatching",false);h:SetAttribute("CrackStage",4)
  say("Revealing","HATCHING "..rewardId:upper())
  visual:SetAttribute("HatchOpening",true)
  if player then camera:FireClient(player,"Reveal",h,inside,rewardId)end
  task.wait(.35)
  local oldEgg=visual
  for _,p in oldEgg:GetDescendants()do if p:IsA("BasePart")then tween(p,.25,{Transparency=1})end end
  local character=rewardTemplate:Clone();character.Name="HatchedCharacter"
  for _,p in character:GetDescendants()do if p:IsA("BasePart")then p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false end end
  local _,charSize=character:GetBoundingBox()
  character:ScaleTo(character:GetScale()*math.min(3.8/charSize.Y,2.8/charSize.X,2.65/charSize.Z))
  local charBox,finalSize=character:GetBoundingBox()
  local bottom=charBox.Y-finalSize.Y*.5
  local home=frame*CFrame.new(22.75,32.975,92)
  character:PivotTo(home*CFrame.new(-charBox.X,-bottom,-charBox.Z))
  character:SetAttribute("RewardHome",character:GetPivot())
  character:SetAttribute("RevealEpoch",workspace:GetServerTimeNow())
  character:SetAttribute("CharacterId",rewardId)
  character:SetAttribute("ChamberReveal",true)
  character.Parent=h;visual=character
  h:SetAttribute("RewardId",rewardId)
  Collection:AddTag(character,"HatchRewardDisplay")
  task.delay(.3,function()if oldEgg.Parent then oldEgg:Destroy()end end)
  complete:Fire(player,tool,rewardId)
  task.wait(1.25)
  if player then camera:FireClient(player,"End",h);focusSent=false end
  h:SetAttribute("Venting",true)
  tween(door,.45,{CFrame=doorRest+frame:VectorToWorldSpace(Vector3.new(-4.25,0,0))})
  say("AwaitingPickup","READY • COLLECT "..rewardId:upper())
  pickupAnchor=Instance.new("Part");pickupAnchor.Name="EggPickupAnchor";pickupAnchor.Size=Vector3.one;pickupAnchor.Transparency=1;pickupAnchor.Anchored=true
  pickupAnchor.CanCollide=false;pickupAnchor.CanTouch=false;pickupAnchor.CanQuery=false
  pickupAnchor.Position=frame:PointToWorldSpace(Vector3.new(22.75,34.125,87));pickupAnchor.Parent=h
  local pickup=Instance.new("ProximityPrompt");pickup.Name="PickUpCharacter";pickup.ActionText="Collect character";pickup.ObjectText=rewardId
  pickup.RequiresLineOfSight=false;pickup.MaxActivationDistance=12;pickup.HoldDuration=.2;pickup.Parent=pickupAnchor
  local collected=false
  local function collect(who)
   if collected or (player and who~=player) then return end
   local root=who and who.Character and who.Character:FindFirstChild("HumanoidRootPart")
   local bag=who and who:FindFirstChildOfClass("Backpack")
   if not root or not bag or (root.Position-pickupAnchor.Position).Magnitude>14 then return end
   local rewardTool=Rewards.Tool(rewardTemplate,rewardId)
   rewardTool.Parent=bag;collected=true;pickup.Enabled=false
   if tool and tool.Parent then tool:Destroy();tool=nil end
  end
  pickup.Triggered:Connect(collect)
  local request=Instance.new("BindableEvent");request.Name="RequestPickup";request.Parent=pickupAnchor;request.Event:Connect(collect)
  task.delay(2,function()if h.Parent then h:SetAttribute("Venting",false)end end)
  while not collected and (not player or player.Parent==Players) and h:IsDescendantOf(workspace)do task.wait(.1)end
 end,debug.traceback)
 if focusSent and player and player.Parent==Players then camera:FireClient(player,"End",h)end
 h:SetAttribute("Hatching",false);h:SetAttribute("Venting",false);h:SetAttribute("CycleEnd",nil);h:SetAttribute("RewardId",nil);h:SetAttribute("CrackStage",nil)
 if pickupAnchor then pickupAnchor:Destroy()end
 if visual then visual:Destroy()end
 if tool and tool.Parent then tool:SetAttribute("Incubating",nil);tool.Enabled=enabled;local bag=player and player:FindFirstChildOfClass("Backpack");if bag then tool.Parent=bag end end
 if button.Parent then tween(button,.2,{CFrame=rest})end
 if door.Parent then tween(door,.45,{CFrame=doorRest})end
 if liquid.Parent then tween(liquid,1.25,{Size=fullSize,CFrame=fullCF}).Completed:Wait()end
 busy=false;waitingOwner=nil;startRequested=false;prompt.ActionText="Insert egg";prompt.ObjectText="Hatching chamber";prompt.Enabled=true
 say("Ready","HOLD AN EGG • INSERT")
 if not ok then warn("Hatch cycle recovered: "..tostring(err))end
end
button.ClickDetector.MouseClick:Connect(cycle)
prompt.Triggered:Connect(cycle)
h.RequestHatch.Event:Connect(cycle)
h:SetAttribute("Hatching",false);prompt.ActionText="Insert egg"
say("Ready","HOLD AN EGG • INSERT")
