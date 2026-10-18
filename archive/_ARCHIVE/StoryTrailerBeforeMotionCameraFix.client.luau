-- Temporary local trailer. F6 replay, F7 cancel. No gameplay rewards or purchases.
local P=game:GetService("Players")
local R=game:GetService("RunService")
local U=game:GetService("UserInputService")
local S=game:GetService("StarterGui")
local RS=game:GetService("ReplicatedStorage")
local player=P.LocalPlayer
if player.UserId~=168774222 and not R:IsStudio() then return end
local assets=RS:WaitForChild("TEMP_StoryTrailerAssets")
local active=false
local cleanup
local function smooth(x) x=math.clamp(x,0,1);return x*x*(3-2*x) end
local function lerp(a,b,u)return a:Lerp(b,smooth(u))end
local function clean(model)
 for _,v in model:GetDescendants() do
  if v:IsA("LuaSourceContainer") or v:IsA("ProximityPrompt") or v:IsA("BillboardGui") or v:IsA("SurfaceGui") or v:IsA("Sound") then v:Destroy()
  elseif v:IsA("BasePart") then v.CanCollide=false;v.CanTouch=false;v.CanQuery=false end
 end
end
local function begin()
 if active then cleanup() end
 local char=player.Character
 if not char or not char:FindFirstChild("HumanoidRootPart") then return end
 local plot
 for _,p in workspace.Plots:GetChildren() do if p:GetAttribute("OwnerUserId")==player.UserId then plot=p break end end
 plot=plot or workspace.Plots:FindFirstChild("TemplePlot07")
 if not plot then warn("Trailer: no plot found");return end
 active=true
 local cam=workspace.CurrentCamera
 local saved={cf=cam.CFrame,kind=cam.CameraType,subject=cam.CameraSubject,fov=cam.FieldOfView}
 local hidden,guiStates,partStates,coreStates,connections={},{},{},{},{}
 local stage=Instance.new("Folder");stage.Name="TEMP_StoryTrailer";stage.Parent=workspace
 local controls
 local ok,module=pcall(function()return require(player.PlayerScripts:WaitForChild("PlayerModule",5))end)
 if ok then controls=module:GetControls();controls:Disable() end
 local oldAnchor=char.HumanoidRootPart.Anchored
 char.HumanoidRootPart.Anchored=true
 local oldMouse=U.MouseIconEnabled;U.MouseIconEnabled=false
 local oldTop=true;pcall(function()oldTop=S:GetCore("TopbarEnabled")end)
 for _,kind in Enum.CoreGuiType:GetEnumItems() do if kind~=Enum.CoreGuiType.All then pcall(function()coreStates[kind]=S:GetCoreGuiEnabled(kind);S:SetCoreGuiEnabled(kind,false)end)end end
 pcall(function()S:SetCore("TopbarEnabled",false)end)
 local function hide(v)
  if v:IsA("ScreenGui") or v:IsA("BillboardGui") or v:IsA("SurfaceGui") then
   if guiStates[v]==nil then guiStates[v]=v.Enabled end;v.Enabled=false
  elseif v:IsA("ProximityPrompt") then
   if guiStates[v]==nil then guiStates[v]=v.Enabled end;v.Enabled=false
  end
 end
 for _,v in player.PlayerGui:GetDescendants() do hide(v) end
 for _,v in workspace:GetDescendants() do hide(v) end
 table.insert(connections,workspace.DescendantAdded:Connect(function(v)if not v:IsDescendantOf(stage) then hide(v)end end))
 table.insert(connections,player.PlayerGui.DescendantAdded:Connect(hide))
 local function hideCharacter(c)
  for _,v in c:GetDescendants() do if v:IsA("BasePart") then hidden[v]=v.LocalTransparencyModifier;v.LocalTransparencyModifier=1 end end
 end
 for _,p in P:GetPlayers() do if p.Character then hideCharacter(p.Character)end end
 -- Restore only temporary client-side visibility changes afterwards.
 for _,v in plot:GetDescendants() do
  if v:IsA("BasePart") and v:GetAttribute("ClaimTransparency")~=nil then partStates[v]=v.Transparency;v.Transparency=v:GetAttribute("ClaimTransparency") end
 end
 local actor
 local oldArch=char.Archivable;char.Archivable=true;actor=char:Clone();char.Archivable=oldArch
 actor.Name="TrailerAvatar";clean(actor)
 for _,v in actor:GetChildren() do if v:IsA("Tool") or v.Name=="HeldItemCarry" or v.Name=="RiverEggCarry" or v.Name=="StolenEggCarry" then v:Destroy()end end
 for _,v in actor:GetDescendants() do if v:IsA("BasePart") then v.LocalTransparencyModifier=0;v.Anchored=false end end
 local root=actor:FindFirstChild("HumanoidRootPart");root.Anchored=true
 local hum=actor:FindFirstChildOfClass("Humanoid");hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
 local animator=hum:FindFirstChildOfClass("Animator")
 if animator then for _,track in animator:GetPlayingAnimationTracks() do track:Stop(0)end;animator:Destroy()end
 actor.Parent=stage
 local base=plot.TempleAnchor.CFrame
 local function world(v)return base:PointToWorldSpace(v)end
 local function point(x,y,z)return world(Vector3.new(x,y,z))end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={stage,char}
 local function ground(v)
  local w=world(v);local hit=workspace:Raycast(w+Vector3.new(0,12,0),Vector3.new(0,-30,0),params)
  return hit and Vector3.new(w.X,hit.Position.Y,w.Z) or w
 end
 local foot=hum.RigType==Enum.HumanoidRigType.R15 and hum.HipHeight+root.Size.Y/2 or 3
 local function position(v)return ground(v)+Vector3.new(0,foot,0)end
 local landing=position(Vector3.new(-18,0,75))
 local eggSpot=position(Vector3.new(6,0,105))
 local turn=position(Vector3.new(-44,0,58))
 local approach=position(Vector3.new(-44,0,26))
 local entry=position(Vector3.new(0,0,43))
 local inside=position(Vector3.new(0,0,20))
 local slot=plot.Slots:FindFirstChild("Slot06") or plot.Slots:FindFirstChild("Slot01")
 local slotTop=slot and slot:FindFirstChild("Top")
 assert(slotTop,"Trailer needs a character slot")
 local destination=slotTop.Position+base.RightVector*5+Vector3.new(0,foot-1,0)
 local machine=assets.Machine:Clone();clean(machine);machine.Parent=stage
 local machineCF=base*CFrame.new(-44,0,15)*CFrame.Angles(0,math.pi,0)
 machine:PivotTo(machineCF)
 for _,v in machine:GetDescendants() do if v:IsA("BasePart") then v.Anchored=true end end
 for _,v in plot.ChamberYard:GetChildren() do if v:IsA("Model") then for _,p in v:GetDescendants() do if p:IsA("BasePart") then hidden[p]=p.LocalTransparencyModifier;p.LocalTransparencyModifier=1 end end end end
 local doors={}
 for _,v in machine:GetDescendants() do if v:IsA("BasePart") and (v:IsDescendantOf(machine.GlassLeft) or v:IsDescendantOf(machine.GlassRight)) then doors[v]={cf=v.CFrame,sign=v:IsDescendantOf(machine.GlassLeft) and -1 or 1} end end
 local function openDoors(u)for p,d in doors do p.CFrame=d.cf+machineCF.RightVector*d.sign*3*u end end
 local function prop(template,name,height)
  local m=template:Clone();m.Name=name;clean(m)
  local _,size=m:GetBoundingBox();m:ScaleTo(m:GetScale()*height/math.max(size.Y,.01))
  local box=m:GetBoundingBox();local offset=box:ToObjectSpace(m:GetPivot())
  for _,v in m:GetDescendants() do if v:IsA("BasePart") then v.Anchored=true end end
  m.Parent=stage
  return m,offset
 end
 local egg,eggOffset=prop(assets.Egg,"TrailerPirateEgg",2.2)
 local reward,rewardOffset=prop(assets.Reward,"TrailerReward",6)
 reward.Parent=nil
 local joints={}
 for _,v in actor:GetDescendants() do if v:IsA("Motor6D") then joints[v]={c0=v.C0,name=v.Name}end end
 local function pose(t,run,carry,crouch,celebrate,look)
  for j,d in joints do
   local n=d.name:lower();local side=n:find("left") and -1 or 1
   local a=CFrame.identity
   if n:find("shoulder") then a=CFrame.Angles(carry and 1.45 or celebrate and 2.5 or math.sin(t*11)*.65*run*side,0,carry and side*.12 or side*.08)
   elseif n:find("hip") then a=CFrame.Angles(math.sin(t*11)*.65*run*-side+crouch*.65,0,0)
   elseif n:find("knee") then a=CFrame.Angles(math.max(0,math.sin(t*11)*side)*.65*run+crouch*.85,0,0)
   elseif n:find("neck") then a=CFrame.Angles(0,look or 0,0)
   elseif n:find("waist") or n=="rootjoint" then a=CFrame.Angles(-crouch*.35,0,0)end
   j.C0=d.c0*a
  end
 end
 local function glowPart(name,shape,size,color)
  local p=Instance.new("Part");p.Name=name;p.Shape=shape;p.Size=size;p.Material=Enum.Material.Neon;p.Color=color;p.Anchored=true;p.CanCollide=false;p.CanQuery=false;p.CanTouch=false;p.Parent=stage;return p
 end
 local rift=glowPart("SkyRift",Enum.PartType.Cylinder,Vector3.new(.15,13,13),Color3.fromRGB(255,184,67))
 rift.CFrame=CFrame.new(landing+Vector3.new(0,60,0))*CFrame.Angles(0,0,math.pi/2)
 local core=glowPart("RiftCore",Enum.PartType.Cylinder,Vector3.new(.18,10.5,10.5),Color3.fromRGB(95,55,210));core.CFrame=rift.CFrame
 local light=Instance.new("PointLight",rift);light.Color=rift.Color;light.Brightness=3;light.Range=30
 local att=Instance.new("Attachment",rift)
 local sparks=Instance.new("ParticleEmitter",att);sparks.Texture="rbxasset://textures/particles/sparkles_main.dds";sparks.Rate=45;sparks.Lifetime=NumberRange.new(.4,1);sparks.Speed=NumberRange.new(5,12);sparks.SpreadAngle=Vector2.new(180,180);sparks.LightEmission=1;sparks.Color=ColorSequence.new(rift.Color)
 local function burst(pos,color)
  local p=glowPart("Impact",Enum.PartType.Ball,Vector3.one*.1,color);p.Transparency=1;p.Position=pos
  local a=Instance.new("Attachment",p);local e=Instance.new("ParticleEmitter",a)
  e.Texture="rbxasset://textures/particles/sparkles_main.dds";e.Color=ColorSequence.new(color);e.Lifetime=NumberRange.new(.3,.8);e.Speed=NumberRange.new(5,14);e.SpreadAngle=Vector2.new(180,180);e.Rate=0;e.LightEmission=.7;e:Emit(30)
  game:GetService("Debris"):AddItem(p,2)
 end
 local marks={}
 local function cue(name,t,now,fn) if now>=t and not marks[name] then marks[name]=true;fn()end end
 local cancelled=false
 cleanup=function()
  if cancelled then return end;cancelled=true;active=false
  R:UnbindFromRenderStep("TEMP_StoryCamera")
  for _,c in connections do c:Disconnect()end
  for v,x in hidden do if v.Parent then v.LocalTransparencyModifier=x end end
  for v,x in guiStates do if v.Parent then v.Enabled=x end end
  for v,x in partStates do if v.Parent then v.Transparency=x end end
  for kind,x in coreStates do pcall(function()S:SetCoreGuiEnabled(kind,x)end)end
  pcall(function()S:SetCore("TopbarEnabled",oldTop)end)
  U.MouseIconEnabled=oldMouse
  if char.Parent and char:FindFirstChild("HumanoidRootPart") then char.HumanoidRootPart.Anchored=oldAnchor end
  if controls then controls:Enable()end
  cam.CameraType=saved.kind;cam.CameraSubject=saved.subject;cam.FieldOfView=saved.fov;cam.CFrame=saved.cf
  egg:Destroy();reward:Destroy();stage:Destroy()
  script:SetAttribute("Scene","Stopped")
 end
 table.insert(connections,player.CharacterRemoving:Connect(cleanup))
 local start=os.clock()
 local previousCam
 local previousScene,transitionFrom,transitionAt
 local function sound(id,volume)
  local s=Instance.new("Sound");s.SoundId=id;s.Volume=volume;s.Parent=stage;s:Play();game:GetService("Debris"):AddItem(s,8)
 end
 local function render()
  local t=os.clock()-start
  if R:IsStudio() and type(script:GetAttribute("PreviewTime"))=="number" then t=script:GetAttribute("PreviewTime")end
  if t>54 then cleanup();return end
  local pos,target,camPos,camTarget,run,carry,crouch,celebrate,look
  run=0;crouch=0;target=eggSpot
  local machineEgg=machineCF:PointToWorldSpace(Vector3.new(0,3.5,-1.5))
  local scene
  if t<5 then
   scene="Rift arrival";local u=smooth(t/5)
   pos=landing+Vector3.new(0,60*(1-u),0)
   camPos=lerp(landing+base:VectorToWorldSpace(Vector3.new(28,70,48)),landing+base:VectorToWorldSpace(Vector3.new(8,2,12)),u)
   camTarget=pos; crouch=t>4.5 and smooth((t-4.5)/.5) or 0
  elseif t<9 then
   scene="Landing and looking around";pos=landing;crouch=1-smooth((t-5)/1.3);look=math.sin((t-6)*2)*.65
   camPos=landing+base:VectorToWorldSpace(Vector3.new(8,2,12));camTarget=pos+Vector3.new(0,1,0)
  elseif t<13 then
   scene="Spotting the Pirate Egg";pos=landing;look=-.5
   camPos=lerp(landing+base:VectorToWorldSpace(Vector3.new(-2,3,-5)),eggSpot+base:VectorToWorldSpace(Vector3.new(4,1,6)),(t-9)/4)
   camTarget=lerp(landing,eggSpot,(t-9)/2.5)
  elseif t<18 then
   scene="Chase";pos=landing:Lerp(eggSpot,(t-13)/8);run=1
   camPos=pos+base:VectorToWorldSpace(Vector3.new(8,2,5));camTarget=pos
  elseif t<21 then
   scene="Stumble and recovery";pos=landing:Lerp(eggSpot,.625)
   local u=(t-18)/3;crouch=math.sin(u*math.pi)
   pos-=Vector3.new(0,1.5*math.sin(u*math.pi),0)
   camPos=pos+base:VectorToWorldSpace(Vector3.new(7,2,6));camTarget=pos
  elseif t<24 then
   scene="Grab the egg";pos=lerp(landing:Lerp(eggSpot,.625),eggSpot,(t-21)/2);run=t<23 and 1 or 0;carry=t>=23
   camPos=pos+base:VectorToWorldSpace(Vector3.new(6,2,6));camTarget=pos
  elseif t<32 then
   scene="Return to the incubator";local u=(t-24)/8;pos=u<.55 and eggSpot:Lerp(turn,u/.55) or turn:Lerp(approach,(u-.55)/.45)
   target=u<.55 and turn or approach;run=1;carry=true
   camPos=pos+base:VectorToWorldSpace(Vector3.new(9,4,12));camTarget=pos
  elseif t<35 then
   scene="Load the incubator";pos=approach;target=machineEgg;carry=true;crouch=math.sin(math.clamp((t-33)*math.pi,0,math.pi))*.35
   camPos=approach+base:VectorToWorldSpace(Vector3.new(7,3,7));camTarget=machineEgg
  elseif t<38 then
   scene="Incubating";pos=approach;target=machineEgg
   camPos=lerp(approach+base:VectorToWorldSpace(Vector3.new(7,3,7)),machineEgg+machineCF:VectorToWorldSpace(Vector3.new(1,2,-13)),(t-35)/1.2);camTarget=machineEgg
  elseif t<42 then
   scene="Hatch reveal";pos=approach;target=machineEgg
   camPos=machineEgg+machineCF:VectorToWorldSpace(Vector3.new(1,2,-13));camTarget=machineEgg+Vector3.new(0,1,0)
  elseif t<49 then
   scene="Carry the character to its slot";carry=true;run=1
   local u=(t-42)/7
   if u<.28 then pos=approach:Lerp(turn,u/.28);target=turn
   elseif u<.58 then pos=turn:Lerp(entry,(u-.28)/.3);target=entry
   elseif u<.82 then pos=entry:Lerp(inside,(u-.58)/.24);target=inside
   else pos=inside:Lerp(destination,(u-.82)/.18);target=destination end
   camPos=pos+base:VectorToWorldSpace(Vector3.new(4,3,9));camTarget=pos
  else
   scene="Placement and celebration";pos=destination;target=slotTop.Position;celebrate=t>50
   camPos=lerp(pos+base:VectorToWorldSpace(Vector3.new(-5,4,10)),point(12,65,80),(t-50)/4);camTarget=lerp(slotTop.Position,point(0,10,15),(t-50)/4)
  end
  script:SetAttribute("Scene",scene)
  local delta=Vector3.new(target.X-pos.X,0,target.Z-pos.Z)
  local cf=CFrame.lookAt(pos,pos+(delta.Magnitude>.01 and delta or base.LookVector))
  if t>=18 and t<21 then cf*=CFrame.Angles(-math.sin((t-18)/3*math.pi)*1.2,0,.15*math.sin((t-18)/3*math.pi))end
  actor:PivotTo(cf);pose(t,run,carry,crouch,celebrate,look)
  local torso=actor:FindFirstChild("UpperTorso") or actor:FindFirstChild("Torso")
  local held=torso.CFrame*CFrame.new(0,-.2,-2)
  if t<23 then egg:PivotTo(CFrame.new(eggSpot-Vector3.new(0,foot-1.5,0))*CFrame.Angles(0,t*.5,0)*eggOffset)
  elseif t<33 then egg:PivotTo(held*eggOffset)
  elseif t<34 then egg:PivotTo(held:Lerp(CFrame.new(machineEgg),smooth(t-33))*eggOffset)
  elseif t<39 then egg:PivotTo(CFrame.new(machineEgg)*CFrame.Angles(0,0,t>38 and math.sin(t*40)*.15 or 0)*eggOffset)end
  if t>=39 and t<42 then reward:PivotTo(CFrame.new(machineEgg+Vector3.new(0,1,0))*CFrame.Angles(0,(t-39)*1.3,0)*rewardOffset)
  elseif t>=42 and t<49 then reward:PivotTo(held*rewardOffset)
  elseif t>=49 then reward:PivotTo(CFrame.new(slotTop.Position+Vector3.new(0,slotTop.Size.Y/2+3.65,0))*CFrame.Angles(0,(t-49)*.6,0)*rewardOffset)end
  local open=t<34 and 1 or t<35 and 1-smooth(t-34) or t<38 and 0 or smooth((t-38)/.8)
  openDoors(open)
  rift.Transparency=t<5 and .15 or math.clamp((t-5)/1.5,0,1);core.Transparency=rift.Transparency;light.Brightness=3*(1-rift.Transparency);sparks.Enabled=t<5
  cue("land",5,t,function()sound("rbxassetid://9126047777",.4);burst(landing-Vector3.new(0,foot,0),Color3.fromRGB(240,200,140))end)
  cue("fall",19,t,function()burst(pos,Color3.fromRGB(210,190,155))end)
  cue("slam",34,t,function()burst(machineEgg,Color3.fromRGB(255,190,65))end)
  cue("hatch",39,t,function()sound("rbxassetid://112485797063762",.5);egg.Parent=nil;reward.Parent=stage;burst(machineEgg,Color3.fromRGB(255,230,130))end)
  cue("place",49,t,function()sound("rbxassetid://112485797063762",.3);burst(slotTop.Position,Color3.fromRGB(255,220,90))end)
  cam.CameraType=Enum.CameraType.Scriptable;cam.FieldOfView=t<5 and 65 or 52
  -- Keep the lens on the visible side of walls and roofs.
  local view=camPos-camTarget
  local hit=workspace:Raycast(camTarget,view,params)
  if hit and view.Magnitude>1 then camPos=hit.Position-view.Unit*.7 end
  local wanted=CFrame.lookAt(camPos,camTarget)
  if scene~=previousScene then transitionFrom=previousCam or wanted;transitionAt=os.clock();previousScene=scene end
  local blend=smooth((os.clock()-(transitionAt or 0))/.35)
  cam.CFrame=transitionFrom:Lerp(wanted,blend);previousCam=cam.CFrame
  for v in hidden do if v.Parent then v.LocalTransparencyModifier=1 end end
  for v in guiStates do if v.Parent then v.Enabled=false end end
 end
 R:BindToRenderStep("TEMP_StoryCamera",Enum.RenderPriority.Last.Value,function()
  local ok,err=xpcall(render,debug.traceback)
  if not ok then warn("Trailer error: "..err);cleanup()end
 end)
end
local function startSafe()
 local ok,err=xpcall(begin,debug.traceback)
 if not ok then warn("Trailer setup error: "..err);if cleanup then cleanup()else active=false end end
end
U.InputBegan:Connect(function(key,processed)
 if key.KeyCode==Enum.KeyCode.F7 then if cleanup then cleanup()end
 elseif not processed and key.KeyCode==Enum.KeyCode.F6 then startSafe()end
end)
script.Destroying:Connect(function()if cleanup then cleanup()end end)
-- Studio-only automatic preview; published gameplay requires the owner's F6 key.
if R:IsStudio() then task.spawn(function()
 local deadline=os.clock()+35
 repeat task.wait(.2) until (player:GetAttribute("LoadingScreenDone") and player:GetAttribute("JoinArrivalFinished")) or os.clock()>deadline
 task.wait(2);if not active then startSafe()end
end)end
