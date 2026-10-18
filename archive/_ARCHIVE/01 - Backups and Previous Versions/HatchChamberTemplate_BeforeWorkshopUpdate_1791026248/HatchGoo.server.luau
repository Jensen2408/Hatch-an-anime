local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local h=script.Parent
local frame=h:GetPivot()*CFrame.new(-22.75,-26,-92)
local m=h:WaitForChild("LiquidSystemAndTrim")
local button=m.HatchButton
local prompt=button.ProximityPrompt
local door=h.LoadingDoor
local liquid=m.TankLiquid
local text=m.TimerAnchor.CycleTimer.Status
local cameraCue=game.ReplicatedStorage:WaitForChild("HatchCameraCue")
local rest,doorRest=button.CFrame,door.CFrame
local fullSize,fullCF=liquid.Size,liquid.CFrame
local busy=false
local complete=Instance.new("BindableEvent")
complete.Name="HatchCycleCompleted" complete.Parent=h
local function tween(p,t,props)
 local tw=TweenService:Create(p,TweenInfo.new(t,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut),props)
 tw:Play() return tw
end
local function move(model,target,duration)
 local start=model:GetPivot()
 local elapsed=0
 while elapsed<duration do
  elapsed+=RunService.Heartbeat:Wait()
  local a=TweenService:GetValue(math.min(elapsed/duration,1),Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
  model:PivotTo(start:Lerp(target,a))
 end
end
local function say(state,message) h:SetAttribute("Status",state) text.Text=message m.TimerAnchor.CycleTimer.Enabled=state~="Ready" or message=="EQUIP AN EGG FIRST" end
local function cycle(player)
 if busy then return end
 local plot=h.Parent.Parent
 if player and plot:GetAttribute("OwnerUserId")~=player.UserId then return end
 local tool,source
 if player then
  local char=player.Character
  local root=char and char:FindFirstChild("HumanoidRootPart")
  if not root or (root.Position-button.Position).Magnitude>20 then return end
  for _,v in char:GetChildren() do if v:IsA("Tool") and v.Name:lower():find("egg") then tool=v break end end
  source=tool and tool:FindFirstChild("Egg")
  if not source or not source:IsA("Model") then
   say("Ready","EQUIP AN EGG FIRST")
   task.delay(2,function() if not busy then say("Ready","HOLD AN EGG • PRESS") end end)
   return
  end
 else
  -- Studio preview through the server-only BindableEvent.
  source=game.ServerStorage:FindFirstChild("WaterfallEggTemplate")
 end
 if not source then return end
 busy=true prompt.Enabled=false
 local visual
 local pickupAnchor
 local originalEnabled=tool and tool.Enabled
 local ok,err=xpcall(function()
  local seconds=tonumber(tool and tool:GetAttribute("HatchSeconds")) or h:GetAttribute("PreviewHatchSeconds") or 10
  seconds=math.clamp(seconds,1,3600)
  if tool then tool:SetAttribute("Incubating",true) local hum=player.Character:FindFirstChildOfClass("Humanoid") if hum then hum:UnequipTools() end end
  visual=source:Clone() visual.Name="IncubatingEgg"
  if tool then
   local held=player:FindFirstChild("IncubatorHeldEggs") or Instance.new("Folder")
   held.Name="IncubatorHeldEggs" held.Parent=player
   tool.Enabled=false tool.Parent=held
  end
  for _,v in visual:GetDescendants() do
   if v:IsA("LuaSourceContainer") or v:IsA("ProximityPrompt") or v:IsA("BillboardGui") then v:Destroy()
   elseif v:IsA("BasePart") then v.Anchored=true v.CanCollide=false v.CanTouch=false v.CanQuery=false end
  end
  local reference=visual:FindFirstChild("SkullBrow",true) or visual:FindFirstChild("WoodTier_5_FrontBack",true)
  local pivot=visual:GetPivot()
  if reference and reference:IsA("BasePart") then
   visual:PivotTo(CFrame.new(pivot.Position)*reference.CFrame.Rotation:Inverse()*pivot.Rotation)
  else
   visual:PivotTo(CFrame.new(pivot.Position))
  end
  visual.PrimaryPart=nil
  visual.WorldPivot=CFrame.new(visual:GetPivot().Position)
  local _,size=visual:GetBoundingBox()
  visual:ScaleTo(visual:GetScale()*math.min(2.5/size.Y,2.6/size.X,2.6/size.Z))
  local box=visual:GetBoundingBox()
  local offset=visual:GetPivot():ToObjectSpace(box)
  local function at(pos) return frame*CFrame.new(pos)*offset:Inverse() end
  local entry=at(Vector3.new(22.75,34.125,87.75))
  local inside=at(Vector3.new(22.75,34.125,92))
  visual:PivotTo(inside)
  local appearances={}
  for _,p in visual:GetDescendants() do if p:IsA("BasePart") then appearances[p]=p.Transparency p.Transparency=1 end end
  visual.Parent=h
  say("Loading","TELEPORTING...")
  tween(button,.1,{CFrame=rest+frame:VectorToWorldSpace(Vector3.new(0,0,.25))})
  task.wait(.16) tween(button,.18,{CFrame=rest})
  h:SetAttribute("TeleportPulse",workspace:GetServerTimeNow())
  task.wait(.15)
  for p,alpha in appearances do if p.Parent then tween(p,.2,{Transparency=alpha}) end end
  task.wait(.4)
  say("Incubating","INFUSING")
  h:SetAttribute("Hatching",true)
  h:SetAttribute("CycleEnd",workspace:GetServerTimeNow()+seconds)
  tween(liquid,seconds,{Size=Vector3.new(.5,fullSize.Y,fullSize.Z),CFrame=fullCF-Vector3.new(0,(fullSize.X-.5)/2,0)})
  local endAt=workspace:GetServerTimeNow()+seconds
  repeat
   local remaining=endAt-workspace:GetServerTimeNow()
   text.Text=string.format("INFUSING  %02d:%02d",math.floor(math.ceil(math.max(remaining,0))/60),math.ceil(math.max(remaining,0))%60)
   local t=workspace:GetServerTimeNow()
   visual:PivotTo(frame*CFrame.new(22.75,34.125,92)*CFrame.Angles(math.sin(t*29)*math.rad(.7),0,math.sin(t*33)*math.rad(.7))*offset:Inverse())
   task.wait(.05)
  until workspace:GetServerTimeNow()>=endAt
  h:SetAttribute("Hatching",false)
  visual:PivotTo(inside)
  say("Complete","CYCLE COMPLETE")
  -- Keep the camera steady; only the egg trembles around its center.
  complete:Fire(player,tool)
  h:SetAttribute("Venting",true)
  say("AwaitingPickup","READY • PICK UP EGG")
  tween(door,.45,{CFrame=doorRest+frame:VectorToWorldSpace(Vector3.new(-4.25,0,0))}).Completed:Wait()
  say("Ejecting","EGG READY")
  local elapsed=0
  while elapsed<1.6 do
   elapsed+=RunService.Heartbeat:Wait()
   local a=TweenService:GetValue(math.min(elapsed/1.6,1),Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
   visual:PivotTo(frame*CFrame.new(22.75,34.125,92-4*a)*offset:Inverse())
   local lowest=math.huge
   for _,p in visual:GetDescendants() do if p:IsA("BasePart") and p.Transparency<1 then
    local c,z=p.CFrame,p.Size
    local extent=(math.abs(c.RightVector.Y)*z.X+math.abs(c.UpVector.Y)*z.Y+math.abs(c.LookVector.Y)*z.Z)/2
    lowest=math.min(lowest,p.Position.Y-extent)
   end end
   if lowest<math.huge then visual:PivotTo(visual:GetPivot()+Vector3.new(0,frame:PointToWorldSpace(Vector3.new(22.75,32.875,92)).Y-lowest,0)) end
  end
  say("AwaitingPickup","READY • PICK UP EGG")
  pickupAnchor=Instance.new("Part")
  pickupAnchor.Name="EggPickupAnchor"
  pickupAnchor.Size=Vector3.one pickupAnchor.Transparency=1 pickupAnchor.Anchored=true
  pickupAnchor.CanCollide=false pickupAnchor.CanTouch=false pickupAnchor.CanQuery=false
  pickupAnchor.Position=frame:PointToWorldSpace(Vector3.new(22.75,34.125,87))
  pickupAnchor.Parent=h
  local pickup=Instance.new("ProximityPrompt")
  pickup.Name="PickUpEgg" pickup.ActionText="Pick up egg" pickup.ObjectText=tool and tool.Name or "Preview egg"
  pickup.RequiresLineOfSight=false pickup.MaxActivationDistance=12 pickup.HoldDuration=.2 pickup.Parent=pickupAnchor
  local collected=false
  local function collect(who)
   if collected or (player and who~=player) then return end
   local root=who and who.Character and who.Character:FindFirstChild("HumanoidRootPart")
   local bag=who and who:FindFirstChildOfClass("Backpack")
   if not root or not bag or (root.Position-pickupAnchor.Position).Magnitude>14 then return end
   collected=true pickup.Enabled=false
   if tool and tool.Parent then
    tool:SetAttribute("Incubating",nil) tool.Enabled=originalEnabled tool.Parent=bag
   end
  end
  pickup.Triggered:Connect(collect)
  local request=Instance.new("BindableEvent") request.Name="RequestPickup" request.Parent=pickupAnchor
  request.Event:Connect(collect)
  task.delay(2,function() if h.Parent then h:SetAttribute("Venting",false) end end)
  while not collected and (not player or player.Parent==game.Players) do task.wait(.1) end
 end,debug.traceback)
 h:SetAttribute("Hatching",false) h:SetAttribute("Venting",false) h:SetAttribute("CycleEnd",nil)
 if pickupAnchor then pickupAnchor:Destroy() end
 if visual then visual:Destroy() end
 if tool and tool.Parent then
  tool:SetAttribute("Incubating",nil) tool.Enabled=originalEnabled
  local bag=player and player:FindFirstChildOfClass("Backpack")
  if bag then tool.Parent=bag end
 end
 tween(button,.2,{CFrame=rest})
 tween(door,.45,{CFrame=doorRest})
 tween(liquid,1.5,{Size=fullSize,CFrame=fullCF}).Completed:Wait()
 busy=false prompt.Enabled=true
 say("Ready","HOLD AN EGG • PRESS")
 if not ok then warn("Hatch cycle failed: "..tostring(err)) end
end
button.ClickDetector.MouseClick:Connect(cycle)
prompt.Triggered:Connect(cycle)
h.RequestHatch.Event:Connect(cycle)
h:SetAttribute("Hatching",false)
say("Ready","HOLD AN EGG • PRESS")
