
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Collection=game:GetService("CollectionService")
local player=Players.LocalPlayer
local Actions=game:GetService("ContextActionService")
local remote=game.ReplicatedStorage:WaitForChild("CinematicHatchCue")
local active={}
local session
local gui=Instance.new("ScreenGui");gui.Name="CinematicHatchUI";gui.IgnoreGuiInset=true;gui.ResetOnSpawn=false;gui.DisplayOrder=160;gui.Parent=player:WaitForChild("PlayerGui")
local flash=Instance.new("Frame");flash.Size=UDim2.fromScale(1,1);flash.BackgroundColor3=Color3.fromRGB(255,255,255);flash.BackgroundTransparency=1;flash.BorderSizePixel=0;flash.Parent=gui
local title=Instance.new("TextLabel");title.AnchorPoint=Vector2.new(.5,1);title.Position=UDim2.fromScale(.5,.9);title.Size=UDim2.fromOffset(420,48);title.BackgroundTransparency=1;title.TextColor3=Color3.fromRGB(255,233,167);title.TextStrokeTransparency=.3;title.Font=Enum.Font.GothamBold;title.TextSize=27;title.Text="";title.Parent=gui
local function finish()
 local s=session;if not s then return end;session=nil
 Actions:UnbindAction("CinematicHatchMovement")
 local cam=workspace.CurrentCamera
 if cam then cam.FieldOfView=s.fov;cam.CameraType=s.type;cam.CameraSubject=s.subject;cam.CFrame=s.original end
 for p,value in s.glass do if p.Parent then p.LocalTransparencyModifier=value end end
 if s.controls and s.controlsEnabled then s.controls:Enable()end
 title.Text="";flash.BackgroundTransparency=1
end
player.CharacterRemoving:Connect(finish)
remote.OnClientEvent:Connect(function(action,chamber,home,value)
 if action=="Start" then
  finish()
  local cam=workspace.CurrentCamera
  local controls
  local ok,result=pcall(function()return require(player.PlayerScripts:FindFirstChild("PlayerModule")):GetControls()end)
  if ok then controls=result end
  session={chamber=chamber,home=home,start=os.clock(),duration=value,original=cam.CFrame,fov=cam.FieldOfView,type=cam.CameraType,subject=cam.CameraSubject,glass={},controls=controls,controlsEnabled=not controls or controls.controlsEnabled~=false}
  if controls then controls:Disable()end
  Actions:BindActionAtPriority("CinematicHatchMovement",function()return Enum.ContextActionResult.Sink end,false,3000,table.unpack(Enum.PlayerActions:GetEnumItems()))
  for _,p in chamber:GetDescendants()do if p:IsA("BasePart")and (p.Material==Enum.Material.Glass or p.Name:lower():find("glass"))then session.glass[p]=p.LocalTransparencyModifier;p.LocalTransparencyModifier=.92 end end
  for _,other in Players:GetPlayers() do
   if other.Character then for _,part in other.Character:GetDescendants() do
    if part:IsA("BasePart") then session.glass[part]=part.LocalTransparencyModifier;part.LocalTransparencyModifier=1 end
   end end
  end
  cam.CameraType=Enum.CameraType.Scriptable
  title.Text="HATCHING..."
 elseif session and chamber==session.chamber and action=="Reveal" then
  session.reveal=os.clock();title.Text=tostring(value):upper().." UNLOCKED"
  Tween:Create(flash,TweenInfo.new(.55,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=.08}):Play()
  task.delay(.95,function()
   if session and session.chamber==chamber then
    Tween:Create(flash,TweenInfo.new(1.3,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),{BackgroundTransparency=1}):Play()
   end
  end)
 elseif session and chamber==session.chamber and action=="End" then session.ending=os.clock() end
end)
local function sound(parent,volume,pitch)
 local s=Instance.new("Sound");s.SoundId="rbxasset://sounds/action_footsteps_plastic.mp3";s.Volume=volume;s.PlaybackSpeed=pitch;s.RollOffMinDistance=5;s.RollOffMaxDistance=65;s.Parent=parent;s:Play();Debris:AddItem(s,1.5)
end
local function add(model)
 if active[model]then return end
 local home=model:GetAttribute("ChamberHome")
 if not home then return end
 local group=Instance.new("Model");group.Name="LocalEggHatchFX";group.Parent=workspace
 local host=Instance.new("Part");host.Name="HatchGlow";host.Size=Vector3.one;host.Anchored=true;host.Transparency=1;host.CanCollide=false;host.CanQuery=false;host.CanTouch=false;host.CFrame=home;host.Parent=group
 local light=Instance.new("PointLight");light.Color=Color3.fromRGB(255,225,144);light.Range=8;light.Brightness=.15;light.Shadows=false;light.Parent=host
 local highlight=Instance.new("Highlight");highlight.Adornee=model;highlight.FillColor=light.Color;highlight.FillTransparency=1;highlight.OutlineTransparency=1;highlight.Parent=group
 local sparks=Instance.new("ParticleEmitter");sparks.Texture="rbxasset://textures/particles/sparkles_main.dds";sparks.Rate=0;sparks.LightEmission=.8;sparks.Speed=NumberRange.new(.4,1);sparks.Lifetime=NumberRange.new(.3,.65);sparks.Size=NumberSequence.new(.09);sparks.Color=ColorSequence.new(light.Color);sparks.SpreadAngle=Vector2.new(180,180);sparks.Parent=host
 local sourcePivot=model:GetPivot()
 local box,size=model:GetBoundingBox()
 local rays=RaycastParams.new();rays.FilterType=Enum.RaycastFilterType.Include;rays.FilterDescendantsInstances={model}
 for _,p in model:GetDescendants()do if p:IsA("BasePart")then p.CanQuery=true end end
 local function surface(x,y)
  local origin=box:PointToWorldSpace(Vector3.new(x,y,-size.Z))
  return workspace:Raycast(origin,box.LookVector*-size.Z*2,rays)
 end
 local appearances={}
 for _,p in model:GetDescendants()do if p:IsA("BasePart")then appearances[p]={color=p.Color,material=p.Material}end end
 local r={appearances=appearances,outside=model:GetAttribute("HatchOutside")or home,travel=model:GetAttribute("HatchTravelDuration")or 1.7,home=home,epoch=model:GetAttribute("HatchEpoch"),duration=model:GetAttribute("HatchDuration"),group=group,host=host,light=light,highlight=highlight,sparks=sparks,stage=0,lines={},paths={}}
 -- Four asymmetric branching cracks, added one at a time.
 local paths={
 {{-.05,.95},{.08,.6},{-.13,.28},{.04,-.08},{-.13,-.45}},
 {{.08,.6},{.37,.39},{.28,.09},{.59,-.13}},
 {{-.13,.28},{-.43,.1},{-.34,-.23},{-.66,-.44}},
 {{.04,-.08},{.27,-.3},{.13,-.65},{.28,-.92}}
 }
 -- Sample tiny flush marks individually. Never bridge empty space or miss the shell.
 for stage,path in paths do
  local marks={}
  for i=1,#path-1 do
   local a,b=path[i],path[i+1]
   local count=math.ceil(Vector2.new((b[1]-a[1])*size.X*.32,(b[2]-a[2])*size.Y*.32).Magnitude/.045)
   for step=0,count do
    local u=step/math.max(count,1)
    local hit=surface((a[1]+(b[1]-a[1])*u)*size.X*.32,(a[2]+(b[2]-a[2])*u)*size.Y*.32)
    local localHit=hit and box:PointToObjectSpace(hit.Position)
    local safe=localHit and (localHit.X/(size.X*.38))^2+(localHit.Y/(size.Y*.39))^2<.88
    if hit and safe then
     local normal=hit.Normal
     local tangent=box:VectorToWorldSpace(Vector3.new((b[1]-a[1])*size.X,(b[2]-a[2])*size.Y,0))
     tangent=tangent-normal*tangent:Dot(normal)
     if tangent.Magnitude>.001 then
      tangent=tangent.Unit
      local right=tangent:Cross(normal).Unit
      local surfaceCF=CFrame.fromMatrix(hit.Position+normal*.0015,right,normal,-tangent)
      table.insert(marks,{cf=sourcePivot:ToObjectSpace(surfaceCF)})
     end
    end
   end
  end
  r.paths[stage]=marks
 end
 active[model]=r
end
local function remove(model)
 local r=active[model]
 if r then
  if model.Parent then
   model:PivotTo(r.outside)
   for p,appearance in r.appearances do if p.Parent then p.Color=appearance.color;p.Material=appearance.material end end
  end
  r.group:Destroy();active[model]=nil
 end
end
Collection:GetInstanceAddedSignal("CinematicEggHatch"):Connect(add)
Collection:GetInstanceRemovedSignal("CinematicEggHatch"):Connect(remove)
for _,model in Collection:GetTagged("CinematicEggHatch")do add(model)end
RunService:BindToRenderStep("CinematicEggMotion",Enum.RenderPriority.Camera.Value+3,function()
 local now=workspace:GetServerTimeNow()
 for model,r in active do
  if not model:IsDescendantOf(workspace)then remove(model)
  else
   local t=math.max(0,now-r.epoch)
   local progress=math.clamp((t-r.travel)/(r.duration-r.travel),0,1)
   local move=Tween:GetValue(math.clamp(t/r.travel,0,1),Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
   local movingHome=r.home:Lerp(r.outside,move)
   local near=workspace.CurrentCamera and (workspace.CurrentCamera.CFrame.Position-r.home.Position).Magnitude<100
   if near then
    local a=(.08+progress*progress*2.5)*math.pi/180
    local cf=movingHome*CFrame.new(math.sin(t*15)*.025*progress,math.sin(t*11)*.025*progress,0)*CFrame.Angles(math.sin(t*(9+progress*12))*a,0,math.sin(t*(11+progress*10))*a)
    model:PivotTo(cf)
    r.host.CFrame=cf
    local whiten=Tween:GetValue(math.clamp((progress-.58)/.42,0,1),Enum.EasingStyle.Sine,Enum.EasingDirection.In)
    for part,appearance in r.appearances do
     if part.Parent then
      part.Color=appearance.color:Lerp(Color3.new(1,1,1),whiten)
      if whiten>.75 then part.Material=Enum.Material.Neon end
     end
    end
    r.highlight.FillColor=Color3.new(1,1,1)
    for _,mark in r.lines do
     local growth=math.clamp((t-mark.born)/.09,0,1)
     mark.part.CFrame=cf*mark.cf
     mark.part.Transparency=math.max(1-growth,math.clamp((whiten-.45)/.55,0,1))
     -- Width remains hairline thin: no raised rails or oversized black bars.
     mark.part.Size=Vector3.new(.009+progress*.005,.003,.049)
     mark.part.Color=Color3.fromRGB(40,27,18):Lerp(Color3.fromRGB(255,223,156),math.clamp((progress-.35)*2.3,0,1))
     mark.part.Material=progress>.55 and Enum.Material.Neon or Enum.Material.SmoothPlastic
    end
    if not r.opened then r.light.Brightness=.2+progress*1.2+whiten*3+math.max(0,math.sin(t*(5+progress*10)))*progress*.5;r.sparks.Rate=progress>.4 and 3+progress*5 or 0 else r.sparks.Rate=0 end;r.highlight.OutlineTransparency=1-progress*.55;r.highlight.FillTransparency=1-whiten*.96
    local stage=t<r.travel and 0 or math.min(4,math.floor(progress*4.8)+1)
    while r.stage<stage do
     r.stage+=1
     local path=r.paths[r.stage]
     for i,mark in path do
      local p=Instance.new("Part");p.Name="FlushShellCrack";p.Size=Vector3.new(.009,.003,.049)
      p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false
      p.Material=Enum.Material.SmoothPlastic;p.Color=Color3.fromRGB(40,27,18);p.Transparency=1
      p.CFrame=cf*mark.cf;p.Parent=r.group
      table.insert(r.lines,{part=p,cf=mark.cf,born=t+(i-1)*.003})
     end
     r.sparks:Emit(2);sound(r.host,.12,.9+r.stage*.13)
     task.delay(.07,function()if r.host.Parent then sound(r.host,.055,1.6+r.stage*.1)end end)
    end
    if model:GetAttribute("HatchOpening")and not r.opened then
     r.opened=true;r.light.Brightness=4;r.sparks:Emit(24)
     sound(r.host,.16,.55)
     Tween:Create(r.light,TweenInfo.new(.7),{Brightness=0}):Play()
     local orb=Instance.new("Part");orb.Name="HatchLightBurst";orb.Shape=Enum.PartType.Ball;orb.Size=Vector3.one*.3;orb.Color=Color3.fromRGB(255,245,208);orb.Material=Enum.Material.Neon;orb.Transparency=.35;orb.Anchored=true;orb.CanCollide=false;orb.CanQuery=false;orb.CanTouch=false;orb.CFrame=cf;orb.Parent=r.group
     Tween:Create(orb,TweenInfo.new(1.3,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),{Size=Vector3.one*2.7,Transparency=1}):Play()
     for i=1,8 do
      local angle=i/8*math.pi*2
      local shard=Instance.new("WedgePart");shard.Name="ShellFragment";shard.Size=Vector3.new(.13,.22,.1);shard.Color=Color3.fromRGB(224,213,180);shard.Material=Enum.Material.SmoothPlastic;shard.Anchored=true;shard.CanCollide=false;shard.CanTouch=false;shard.CanQuery=false;shard.CFrame=cf;shard.Parent=workspace
      local target=cf*CFrame.new(math.cos(angle)*.85,.3+math.sin(angle)*.6,math.sin(angle)*.85)*CFrame.Angles(angle,angle,.5)
      Tween:Create(shard,TweenInfo.new(.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=target,Transparency=1}):Play();Debris:AddItem(shard,.6)
     end
    end
   end
  end
 end
 local s=session
 if s then
  local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
  if not s.chamber:IsDescendantOf(workspace)or not hum or hum.Health<=0 or os.clock()-s.start>s.duration+8 then finish();return end
  local cam=workspace.CurrentCamera
  cam.CameraType=Enum.CameraType.Scriptable
  local elapsed=os.clock()-s.start
  local p=math.clamp(elapsed/s.duration,0,1)
  local travel=Tween:GetValue(math.clamp(elapsed/1.7,0,1),Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
  local focus=s.home
  local look=focus.Position+Vector3.new(0,.18,0)
  local cameraPosition=focus:PointToWorldSpace(Vector3.new(.2,.35,-(3.8-p*.65)))
  local target=CFrame.lookAt(cameraPosition,look)
  local enter=Tween:GetValue(math.clamp(elapsed/.8,0,1),Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
  local shot=s.original:Lerp(target,enter)
  if s.ending then
   local exit=Tween:GetValue(math.clamp((os.clock()-s.ending)/.65,0,1),Enum.EasingStyle.Sine,Enum.EasingDirection.InOut)
   cam.CFrame=shot:Lerp(s.original,exit);cam.FieldOfView=48+(s.fov-48)*exit
   if exit>=1 then finish()end
  else
   local shake=p*p*.012
   cam.CFrame=shot*CFrame.new(math.noise(elapsed*17,0)*shake,math.noise(0,elapsed*17)*shake,0)
   cam.FieldOfView=s.fov+(62-s.fov)*enter-p*7
  end
 end
end)
