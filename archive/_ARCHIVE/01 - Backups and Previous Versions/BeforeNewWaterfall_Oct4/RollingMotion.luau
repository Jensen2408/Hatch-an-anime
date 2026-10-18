return function(m,egg)
 local belt=m:WaitForChild("Belt")
 local label=egg:WaitForChild("LabelAnchor")
 local collect=egg:WaitForChild("CollectAnchor")
 local treads=m:WaitForChild("Treads"):GetChildren()
 local pivot=egg:GetPivot()
 local _,size=egg:GetBoundingBox()
 local minY=math.huge
 for _,p in egg:GetDescendants() do
  if p:IsA("BasePart") and p.Transparency<1 then
   for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
    minY=math.min(minY,pivot:PointToObjectSpace(p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)*.5)).Y)
   end end end
  end
 end
 local lastCycle,lastPhase
 local speed=math.max(m:GetAttribute("Speed") or 14,1)
 local fall=m:GetAttribute("DropDuration") or 1.8
 local settle=m:GetAttribute("SettleDuration") or 1.45
 local start=m:GetAttribute("FallStart")
 local x0=m:GetAttribute("LandingX") or -299
 local x1=m:GetAttribute("ExitX") or 235
 local y=24.35-minY
 local travel=(x1-x0)/speed
 local duration=fall+travel+1.2
 local function pose(elapsed)
  local t=math.clamp(elapsed,0,duration)
  local pos,rot,phase
  if t<fall then
   local u=t/fall
   -- Cubic horizontal path meets the river's forward speed without a jump.
   local h=u*u*(3-2*u)
   local distance=math.max(x0-start.X,.01)
   local x=start.X+distance*u^(fall*speed/distance)
   local drop=u*u*(3-2*u)
   pos=Vector3.new(x,start.Y+(y-start.Y)*drop,start.Z)
   rot=CFrame.Angles(.1*math.sin(math.pi*u)^2,0,-.12*math.sin(math.pi*u)^2)
   phase="fall"
  elseif t<fall+travel then
   local waterTime=t-fall
   local u=math.clamp(waterTime/settle,0,1)
   local dip=-.85*math.sin(math.pi*u)^2
   pos=Vector3.new(x0+speed*waterTime,y+dip,start.Z)
   rot=CFrame.identity
   phase=waterTime<settle and "land" or "travel"
  else
   local u=(t-fall-travel)/1.2
   pos=Vector3.new(x1+speed*1.2*u,y-10*u*u,start.Z)
   rot=CFrame.identity
   phase="exit"
  end
  return CFrame.new(pos)*rot,phase,0,duration
 end
 local function update()
  local epoch=egg:GetAttribute("Epoch")
  if not epoch then return end
  local elapsed=math.max(0,workspace:GetServerTimeNow()-epoch)
  local cf,phase,cycle=pose(elapsed)
  egg:PivotTo(cf)
  label.Position=cf.Position+Vector3.new(0,size.Y*.5+2,0)
  collect.Position=cf.Position
  for _,gui in label:GetDescendants() do if gui:IsA("BillboardGui") then gui.Enabled=(phase=="travel") end end
  local prompt=collect:FindFirstChildOfClass("ProximityPrompt")
  if prompt then prompt.Enabled=(phase=="travel") end
  if game:GetService("RunService"):IsClient() and phase=="land" and (lastPhase~="land" or lastCycle~=cycle) then
   local river=workspace:FindFirstChild("WaterfallRiver")
   local burst=river and river:FindFirstChild("EggLandingSplash")
   if burst then for _,e in burst:GetChildren() do if e:IsA("ParticleEmitter") then e:Emit(16) end end end   if river then
    local debris=game:GetService("Debris")
    local tween=game:GetService("TweenService")
    local origin=Vector3.new(cf.Position.X,24.725,20)
    local ring=Instance.new("Folder");ring.Name="LandingRipples";ring.Parent=river;debris:AddItem(ring,1.7)
    for layer=1,2 do
     for i=1,28 do
      local a=i/28*math.pi*2
      local p=Instance.new("Part");p.Name="Ripple";p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Color=Color3.fromRGB(210,248,250);p.Transparency=.3
      local radius=1.6+layer*.25
      p.Size=Vector3.new(radius*math.pi*2/28+.02,.012,.09)
      p.CFrame=CFrame.new(origin+Vector3.new(math.cos(a)*radius,layer*.005,math.sin(a)*radius*.8))*CFrame.Angles(0,-a-math.pi*.5,0);p.Parent=ring
      local finish=4+layer*.55
      tween:Create(p,TweenInfo.new(1.1+layer*.18,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{CFrame=CFrame.new(origin+Vector3.new(1.4+math.cos(a)*finish,layer*.005,math.sin(a)*finish*.8))*CFrame.Angles(0,-a-math.pi*.5,0),Size=Vector3.new(finish*math.pi*2/28+.02,.012,.025),Transparency=1}):Play()
     end
    end
   end

  end
  lastPhase,lastCycle=phase,cycle
 end
 return update,pose
end
