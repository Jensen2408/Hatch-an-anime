-- Nearby construction is cosmetic and local; server geometry stays at its final pose.
local Collection=game:GetService("CollectionService")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local active=setmetatable({},{__mode="k"})
local function play(model)
 if active[model] or not model:IsDescendantOf(workspace) then return end
 local start=model:GetAttribute("BuildStart")
 local duration=model:GetAttribute("BuildDuration")
 if not start or not duration or workspace:GetServerTimeNow()>start+duration then return end
 local box,size=model:GetBoundingBox()
 local camera=workspace.CurrentCamera
 if not camera or (camera.CFrame.Position-box.Position).Magnitude>220 then return end
 active[model]=true
 local records={} local lights={} local interfaces={}
 local minY,maxY=math.huge,-math.huge
 for _,p in model:GetDescendants() do
  if p:IsA("BasePart") and p.Transparency<1 then
   table.insert(records,{p=p,cf=p.CFrame,t=p.Transparency,localT=p.LocalTransparencyModifier,collide=p.CanCollide})
   minY=math.min(minY,p.Position.Y) maxY=math.max(maxY,p.Position.Y)
  elseif p:IsA("Light") then lights[p]=p.Enabled p.Enabled=false
  elseif p:IsA("SurfaceGui") or p:IsA("BillboardGui") then interfaces[p]=p.Enabled p.Enabled=false end
 end
 if #records==0 then active[model]=nil return end
 local span=math.max(maxY-minY,1)
 local fall=.38
 table.sort(records,function(a,b) if math.abs(a.cf.Y-b.cf.Y)>.05 then return a.cf.Y<b.cf.Y end return a.cf.X<b.cf.X end)
 for i,r in records do
  local tier=math.floor((r.cf.Y-minY)/span*17)
  r.delay=tier/17*(duration-fall-.16)+(i%7)*.016
  local side=(i%2==0 and 1 or -1)
  r.from=(r.cf+Vector3.new(side*.45,math.clamp(span*.08,1.8,5),0))*CFrame.Angles(0,0,math.rad(side*5))
  r.p.LocalTransparencyModifier=1
  r.p.CanCollide=false
 end
 local host=Instance.new("Part") host.Name="LocalConstructionDust" host.Anchored=true host.Transparency=1 host.CanCollide=false host.CanQuery=false host.CanTouch=false host.Size=Vector3.new(math.min(size.X,12),.1,math.min(size.Z,12))
 host.Position=Vector3.new(box.X,minY,box.Z) host.Parent=workspace
 local dust=Instance.new("ParticleEmitter") dust.Texture="rbxasset://textures/particles/smoke_main.dds"
 dust.Color=ColorSequence.new(Color3.fromRGB(235,221,191)) dust.Rate=0 dust.Speed=NumberRange.new(1,3) dust.Drag=4 dust.SpreadAngle=Vector2.new(80,80) dust.Lifetime=NumberRange.new(.3,.6)
 dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(1,2)})
 dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(1,1)}) dust.Parent=host
 local sound=Instance.new("Sound") sound.SoundId="rbxasset://sounds/action_falling.mp3" sound.Volume=.1 sound.PlaybackSpeed=1.8 sound.RollOffMaxDistance=80 sound.Parent=host sound:Play()
 task.delay(.35,function() if sound.Parent then sound:Stop() end end)
 local lastCourse=-1
 local ok,err=xpcall(function()
 while model:IsDescendantOf(workspace) do
  local elapsed=workspace:GetServerTimeNow()-start
  for _,r in records do
   if not r.done and r.p.Parent then
    local t=(elapsed-r.delay)/fall
    if t>=1 then
     r.p.CFrame=r.cf r.p.LocalTransparencyModifier=r.localT r.p.CanCollide=r.collide r.done=true
    elseif t>=0 then
     local eased=1-(1-t)^3
     r.p.LocalTransparencyModifier=math.max(r.localT,1-math.min(t*5,1))
     r.p.CFrame=r.from:Lerp(r.cf,eased)
    end
   end
  end
  local course=math.floor(math.max(elapsed,0)/duration*4)
  if elapsed>=0 and course>lastCourse then
   lastCourse=course host.Position=Vector3.new(box.X,minY+span*math.min(course/4,1),box.Z) dust:Emit(5)
  end
  if elapsed>=duration then break end
  RunService.RenderStepped:Wait()
 end
 end,debug.traceback)
 for _,r in records do if r.p.Parent then r.p.CFrame=r.cf r.p.LocalTransparencyModifier=r.localT r.p.CanCollide=r.collide end end
 for l,state in lights do if l.Parent then l.Enabled=state end end
 for gui,state in interfaces do if gui.Parent then gui.Enabled=state end end
 if model:IsDescendantOf(workspace) then
  local glow=Instance.new("Highlight") glow.Name="ConstructionFinish" glow.Adornee=model glow.DepthMode=Enum.HighlightDepthMode.Occluded
  glow.FillColor=model:GetAttribute("BuildTint") or Color3.fromRGB(255,219,143) glow.OutlineColor=glow.FillColor glow.FillTransparency=.75 glow.OutlineTransparency=.25 glow.Parent=model
  TweenService:Create(glow,TweenInfo.new(.6),{FillTransparency=1,OutlineTransparency=1}):Play() Debris:AddItem(glow,.7)
  model:SetAttribute("ClientAssemblyVerifiedParts",#records)
 end
 Debris:AddItem(host,1)
 active[model]=nil
 if not ok then warn("Construction visual recovered: "..tostring(err)) end
end
Collection:GetInstanceAddedSignal("UpgradeAssembly"):Connect(function(m) task.spawn(play,m) end)
for _,m in Collection:GetTagged("UpgradeAssembly") do task.spawn(play,m) end
