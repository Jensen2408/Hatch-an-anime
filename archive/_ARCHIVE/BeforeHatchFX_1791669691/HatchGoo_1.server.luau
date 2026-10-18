
local TweenService=game:GetService("TweenService")
local Players=game:GetService("Players")
local Collection=game:GetService("CollectionService")
local h=script.Parent
while h:GetAttribute("UnderConstruction") do task.wait(.05) end
if not h.Parent then return end
local frame=h:GetPivot()
local controller=require(game.ReplicatedStorage.IncubatorController).new(h)
h.Destroying:Connect(function() controller:Destroy() end)
local m=h:WaitForChild("LiquidSystemAndTrim")
local button=m.HatchButton
local prompt=button.ProximityPrompt
local door=h.LoadingDoor
local liquid=m.TankLiquid
local text=m.TimerAnchor.CycleTimer.Status
local camera=game.ReplicatedStorage:WaitForChild("CinematicHatchCue")
local Rewards=require(game.ServerScriptService:WaitForChild("EggCharacterRewards"))
local Economy=require(game.ReplicatedStorage.CharacterEconomy)
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
-- An egg belongs to this chamber until collected. Walking away or respawning
-- does not cancel incubation; distance is checked only for button/pickup actions.
local function ownsChamber(player)
 if not player then return true end
 local plot=h.Parent and h.Parent.Parent
 return player.Parent==Players and plot and plot:GetAttribute("OwnerUserId")==player.UserId and not h:GetAttribute("EggStolen") -- EggSteal
end
local function press()
 tween(button,.1,{CFrame=rest+frame:VectorToWorldSpace(Vector3.new(0,0,.25))})
 task.delay(.13,function()if button.Parent then tween(button,.18,{CFrame=rest})end end)
end
local function cycle(player)
 if h:GetAttribute("StealLock") then return end -- EggSteal
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
   tool:SetAttribute("Incubating",true);tool:SetAttribute("IncubatorChamber",h:GetFullName()) -- EggSteal
   player.Character.Humanoid:UnequipTools()
   local held=player:FindFirstChild("IncubatorHeldEggs") or Instance.new("Folder");held.Name="IncubatorHeldEggs";held.Parent=player
   tool.Enabled=false;tool.Parent=held
  end
  local eggTemplates=game.ServerStorage:FindFirstChild("AuxEggTemplates")
  local eggType=tool and tool:GetAttribute("EggType")
  local cleanSource=eggType and eggTemplates and eggTemplates:FindFirstChild(eggType)
  if tool and tool:GetAttribute("GoldVariant") then cleanSource=game.ServerStorage.FutureUpdateContent.Eggs:FindFirstChild("Golden Pirate") end
  visual=(cleanSource or source):Clone();visual.Name="IncubatingEgg"
  -- Tool carry hides its own geometry; chamber visuals must never inherit that state.
  for _,part in visual:GetDescendants() do
   if part:IsA("BasePart") then
    local alpha=part:GetAttribute("CarryOriginalTransparency")
    if alpha~=nil then part.Transparency=alpha end
    part.LocalTransparencyModifier=0
   elseif part:IsA("WeldConstraint") or part:IsA("JointInstance") then part:Destroy() end
  end
  for _,v in visual:GetDescendants()do
   if v:IsA("LuaSourceContainer") or v:IsA("ProximityPrompt") or v:IsA("BillboardGui")then v:Destroy()
   elseif v:IsA("BasePart")then v.Anchored=true;v.CanCollide=false;v.CanTouch=false;v.CanQuery=false end
  end
  local _,size=visual:GetBoundingBox()
  visual:ScaleTo(visual:GetScale()*math.min(2.5/size.Y,2.6/size.X,2.6/size.Z))
  local box=visual:GetBoundingBox()
  visual.PrimaryPart=nil;visual.WorldPivot=CFrame.new(box.Position)
  local inside=frame*CFrame.new(0,3.5,-1.5)
  visual:PivotTo(inside)
  visual:SetAttribute("ChamberHome",inside)
  local appearances={}
  for _,p in visual:GetDescendants()do if p:IsA("BasePart")then appearances[p]=p.Transparency;p.Transparency=1 end end
  visual.Parent=h
  Collection:AddTag(visual,"IncubatorEgg") -- lets nearby clients pre-build the fractured shell
  say("Loading","INSERTING EGG");controller:Open(.45);press()
  h:SetAttribute("TeleportPulse",workspace:GetServerTimeNow())
  task.wait(.22)
  for p,alpha in appearances do if p.Parent then tween(p,.35,{Transparency=alpha})end end
  task.wait(.45)
  controller:Close(.45)
  local incubationStart=workspace:GetServerTimeNow()
  h:SetAttribute("Hatching",true);h:SetAttribute("HatchStart",incubationStart);h:SetAttribute("HatchDuration",seconds)
  h:SetAttribute("CycleEnd",incubationStart+seconds)
  say("Incubating","INCUBATING")
  tween(liquid,seconds,{Size=Vector3.new(.5,fullSize.Y,fullSize.Z),CFrame=fullCF-Vector3.new(0,(fullSize.X-.5)/2,0)})
  while workspace:GetServerTimeNow()<incubationStart+seconds do
   if not ownsChamber(player)or not h:IsDescendantOf(workspace)then return end
   local remaining=math.ceil(incubationStart+seconds-workspace:GetServerTimeNow())
   text.Text=string.format("INCUBATING • %02d:%02d",math.floor(remaining/60),remaining%60)
   task.wait(.1)
  end
  h:SetAttribute("Hatching",false);h:SetAttribute("CycleEnd",nil)
  say("Loaded","READY • PRESS HATCH")
  prompt.ActionText="Hatch";prompt.ObjectText=rewardId.." Egg";prompt.Enabled=player~=nil and not h:GetAttribute("StealLock") -- EggSteal
  while player and not startRequested do
   if not ownsChamber(player)or not h:IsDescendantOf(workspace) then return end
   task.wait(.08)
  end
  prompt.Enabled=false
  if not ownsChamber(player)then return end
  local duration=5.6 -- anticipation → cracks → breaking point; the reveal follows
  -- intro: camera zooms in the instant Hatch is pressed while the glass slides open,
  -- then the egg starts breaking once the shot has arrived
  local intro=1.1
  if player then camera:FireClient(player,"Start",h,inside,duration,intro);focusSent=true end
  say("HatchReveal","OPENING...")
  task.spawn(function() controller:Open(intro) end)
  task.wait(intro)
  local epoch=workspace:GetServerTimeNow()
  local outside=inside
  visual:SetAttribute("HatchEpoch",epoch);visual:SetAttribute("HatchDuration",duration)
  visual:SetAttribute("HatchOutside",outside);visual:SetAttribute("HatchTravelDuration",0)
  visual:SetAttribute("HatchOwner",player and player.UserId or 0)
  Collection:AddTag(visual,"CinematicEggHatch")
  say("HatchReveal","HATCHING...")
  while workspace:GetServerTimeNow()<epoch+duration do
   if not ownsChamber(player)or not h:IsDescendantOf(workspace)then return end
   local t=workspace:GetServerTimeNow()-epoch
   h:SetAttribute("CrackStage",math.min(4,math.floor(t/duration*5)))
   text.Text=t<.9 and "ENERGY BUILDING..." or t<4.2 and "SHELL CRACKING..." or "AWAKENING..."
   task.wait(.05)
  end
  visual:PivotTo(outside)
  h:SetAttribute("Hatching",false);h:SetAttribute("CrackStage",4)
  say("Revealing","HATCHING "..rewardId:upper())
  visual:SetAttribute("HatchOpening",true)
  if player then camera:FireClient(player,"Reveal",h,outside,rewardId)end
  task.wait(.3) -- character lands under the reveal flash
  local oldEgg=visual
  for _,p in oldEgg:GetDescendants()do if p:IsA("BasePart")then tween(p,.25,{Transparency=1})end end
  local rewardStats=Economy.Roll(rewardId)
  local character=rewardTemplate:Clone();character.Name="HatchedCharacter"
  for _,p in character:GetDescendants()do if p:IsA("BasePart")then p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false end end
  local _,charSize=character:GetBoundingBox()
  character:ScaleTo(character:GetScale()*math.min(2.65/charSize.Y,1.95/charSize.X,1.85/charSize.Z))
  local charBox,finalSize=character:GetBoundingBox()
  local bottom=charBox.Y-finalSize.Y*.5
  local home=frame*CFrame.new(0,2.25,-1.5)
  character:PivotTo(home*CFrame.new(0,finalSize.Y*.5,0)*charBox:ToObjectSpace(character:GetPivot()))
  character:SetAttribute("RewardHome",character:GetPivot())
  character:SetAttribute("RevealEpoch",workspace:GetServerTimeNow())
  character:SetAttribute("CharacterId",rewardId)
  character:SetAttribute("ChamberReveal",true)
  Economy.Apply(character,rewardId,rewardStats)
  character.Parent=h;visual=character
  Economy.Label(character,rewardId,rewardStats)
  h:SetAttribute("RewardId",rewardId)
  Collection:AddTag(character,"HatchRewardDisplay")
  task.delay(.3,function()if oldEgg.Parent then oldEgg:Destroy()end end)
  complete:Fire(player,tool,rewardId)
  task.wait(1.7)
  if player then camera:FireClient(player,"End",h);focusSent=false end
  h:SetAttribute("Venting",true)
  controller:Open(.45)
  say("AwaitingPickup","POWER "..Economy.Format(rewardStats.Power).." • $"..Economy.Format(rewardStats.IncomePerSecond).."/sec")
  pickupAnchor=Instance.new("Part");pickupAnchor.Name="EggPickupAnchor";pickupAnchor.Size=Vector3.one;pickupAnchor.Transparency=1;pickupAnchor.Anchored=true
  pickupAnchor.CanCollide=false;pickupAnchor.CanTouch=false;pickupAnchor.CanQuery=false
  pickupAnchor.Position=frame:PointToWorldSpace(Vector3.new(0,3.5,-1.5));pickupAnchor.Parent=h
  local pickup=Instance.new("ProximityPrompt");pickup.Name="PickUpCharacter";pickup.ActionText="Collect character";pickup.ObjectText=rewardId.." • Power "..Economy.Format(rewardStats.Power)
  pickup.RequiresLineOfSight=false;pickup.MaxActivationDistance=12;pickup.HoldDuration=.2;pickup.Parent=pickupAnchor
  local collected=false
  local function collect(who)
   if collected or (player and who~=player) then return end
   local root=who and who.Character and who.Character:FindFirstChild("HumanoidRootPart")
   local bag=who and who:FindFirstChildOfClass("Backpack")
   if not root or not bag or (root.Position-pickupAnchor.Position).Magnitude>14 then return end
   local rewardTool=Rewards.Tool(rewardTemplate,rewardId,rewardStats)
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
 if h.Parent then controller:Close(.45) end
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
