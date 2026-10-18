local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local h=script.Parent
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
 local ok,err=xpcall(function()
  local seconds=tonumber(tool and tool:GetAttribute("HatchSeconds")) or h:GetAttribute("PreviewHatchSeconds") or 10
  seconds=math.clamp(seconds,1,3600)
  if tool then tool:SetAttribute("Incubating",true) local hum=player.Character:FindFirstChildOfClass("Humanoid") if hum then hum:UnequipTools() end end
  visual=source:Clone() visual.Name="IncubatingEgg"
  for _,v in visual:GetDescendants() do
   if v:IsA("LuaSourceContainer") or v:IsA("ProximityPrompt") or v:IsA("BillboardGui") then v:Destroy()
   elseif v:IsA("BasePart") then v.Anchored=true v.CanCollide=false v.CanTouch=false v.CanQuery=false end
  end
  local _,size=visual:GetBoundingBox()
  visual:ScaleTo(visual:GetScale()*math.min(2.5/size.Y,2.6/size.X,2.6/size.Z))
  local box=visual:GetBoundingBox()
  local offset=visual:GetPivot():ToObjectSpace(box)
  local function at(pos) return CFrame.new(pos)*offset:Inverse() end
  local entry=at(Vector3.new(22.75,34.125,87.75))
  local inside=at(Vector3.new(22.75,34.125,92))
  visual:PivotTo(entry) visual.Parent=h
  say("Loading","LOADING...")
  tween(button,.1,{CFrame=rest+Vector3.new(0,0,.25)})
  task.wait(.16) tween(button,.18,{CFrame=rest})
  tween(door,.5,{CFrame=doorRest+Vector3.new(-4.25,0,0)}).Completed:Wait()
  move(visual,inside,1.1)
  tween(door,.5,{CFrame=doorRest}).Completed:Wait()
  if player then cameraCue:FireClient(player,.35,.1) end
  say("Incubating","INFUSING")
  h:SetAttribute("Hatching",true)
  h:SetAttribute("CycleEnd",workspace:GetServerTimeNow()+seconds)
  tween(liquid,seconds,{Size=Vector3.new(.5,fullSize.Y,fullSize.Z),CFrame=fullCF-Vector3.new(0,(fullSize.X-.5)/2,0)})
  local endAt=workspace:GetServerTimeNow()+seconds
  repeat
   local remaining=endAt-workspace:GetServerTimeNow()
   text.Text=string.format("INFUSING  %02d:%02d",math.floor(math.ceil(math.max(remaining,0))/60),math.ceil(math.max(remaining,0))%60)
   local t=workspace:GetServerTimeNow()
   visual:PivotTo(inside*CFrame.new(0,math.sin(t*7)*.035,0)*CFrame.Angles(0,0,math.sin(t*9)*math.rad(2)))
   task.wait(.05)
  until workspace:GetServerTimeNow()>=endAt
  h:SetAttribute("Hatching",false)
  visual:PivotTo(inside)
  say("Complete","CYCLE COMPLETE")
  if player then cameraCue:FireClient(player,.45,.14) end
  complete:Fire(player,tool)
  task.wait(.65)
  tween(door,.45,{CFrame=doorRest+Vector3.new(-4.25,0,0)}).Completed:Wait()
  move(visual,entry,.9)
  task.wait(.4)
 end,debug.traceback)
 h:SetAttribute("Hatching",false) h:SetAttribute("CycleEnd",nil)
 if visual then visual:Destroy() end
 if tool and tool.Parent then tool:SetAttribute("Incubating",nil) end
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
