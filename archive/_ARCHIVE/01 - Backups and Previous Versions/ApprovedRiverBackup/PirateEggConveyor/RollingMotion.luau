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
 local function pose(elapsed)
  local speed=math.max(m:GetAttribute("Speed") or 14,1)
  local fall=m:GetAttribute("DropDuration") or 1.35
  local settle=m:GetAttribute("SettleDuration") or .65
  local start=m:GetAttribute("FallStart") or Vector3.new(-308,61.1,20)
  local x0=m:GetAttribute("LandingX") or -299
  local x1=m:GetAttribute("ExitX") or 235
  local y=23.65-minY
  local travel=(x1-x0)/speed
  local cycle=fall+settle+travel+1.2
  local t=elapsed%cycle
  local pos,rot,phase
  if t<fall then
   local u=t/fall
   pos=Vector3.new(start.X+(x0-start.X)*u,start.Y+(y-start.Y)*u*u,start.Z)
   rot=CFrame.Angles(.22*math.sin(math.pi*u),math.pi*2*u,-math.pi*2*u)
   phase="fall"
  elseif t<fall+settle then
   local u=(t-fall)/settle
   pos=Vector3.new(x0+speed*.25*u,y+math.sin(u*math.pi)*1.5*(1-u),belt.Position.Z)
   rot=CFrame.Angles(0,0, .3*math.sin(u*math.pi*4)*(1-u))
   phase="land"
  elseif t<fall+settle+travel then
   local u=t-fall-settle
   pos=Vector3.new(x0+speed*.25+u*(x1-x0-speed*.25)/travel,y+.16*math.sin(u*2),belt.Position.Z)
   rot=CFrame.Angles(0,0, .065*math.sin(u*1.7))
   phase="travel"
  else
   local u=(t-fall-settle-travel)/1.2
   pos=Vector3.new(x1+u*5,y-u*u*10,belt.Position.Z)
   rot=CFrame.Angles(0,0,-u*.5)
   phase="exit"
  end
  if phase=="travel" or phase=="exit" then pos=Vector3.new(pos.X,pos.Y,20+4*math.sin((pos.X+299)/50)) end
  return CFrame.new(pos)*rot,phase,math.floor(elapsed/cycle),cycle
 end
 local function update()
  local epoch=egg:GetAttribute("Epoch")
  if not epoch then return end
  local elapsed=math.max(0,workspace:GetServerTimeNow()-epoch)
  local cf,phase,cycle=pose(elapsed)
  egg:PivotTo(cf)
  label.Position=cf.Position+Vector3.new(0,6,0)
  collect.Position=cf.Position
  for _,gui in label:GetDescendants() do if gui:IsA("BillboardGui") then gui.Enabled=(phase=="travel" or phase=="land") end end
  local prompt=collect:FindFirstChildOfClass("ProximityPrompt")
  if prompt then prompt.Enabled=(phase=="travel" or phase=="land") end
  if game:GetService("RunService"):IsClient() and phase=="land" and (lastPhase~="land" or lastCycle~=cycle) then
   local river=workspace:FindFirstChild("WaterfallRiver")
   local burst=river and river:FindFirstChild("EggLandingSplash")
   if burst then for _,e in burst:GetChildren() do if e:IsA("ParticleEmitter") then e:Emit(35) end end end
  end
  lastPhase,lastCycle=phase,cycle
 end
 return update,pose
end
