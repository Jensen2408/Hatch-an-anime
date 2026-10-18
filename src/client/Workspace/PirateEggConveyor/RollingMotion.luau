-- Moves a river egg along the new winding WaterfallRiver (ReplicatedStorage.WaterfallRiver.RiverPath).
-- Same API as before: returns update(), pose(elapsed) -> cframe, phase ("fall"|"land"|"travel"|"exit"), cycle, duration
local RS=game:GetService("ReplicatedStorage")
local riverFolder=RS:WaitForChild("WaterfallRiver")
local Config=require(riverFolder:WaitForChild("RiverConfig"))
local Path=require(riverFolder:WaitForChild("RiverPath"))
return function(m,egg)
 local label=egg:WaitForChild("LabelAnchor")
 local collect=egg:WaitForChild("CollectAnchor")
 local pivot=egg:GetPivot()
 local _,size=egg:GetBoundingBox()
 local minY=math.huge
 for _,p in egg:GetDescendants() do
  if p:IsA("BasePart") and p.Transparency<1 and p~=label and p~=collect then
   for _,x in {-1,1} do for _,y in {-1,1} do for _,z in {-1,1} do
    minY=math.min(minY,pivot:PointToObjectSpace(p.CFrame:PointToWorldSpace(p.Size*Vector3.new(x,y,z)*.5)).Y)
   end end end
  end
 end
 if minY==math.huge then minY=-size.Y/2 end
 local O=Config.Origin
 local seed=((egg:GetAttribute("Sequence") or 1)*0.618034)%1
 local lateral=(seed-.5)*Config.RiverWidth*.25
 local speed=math.max(m:GetAttribute("Speed") or 14,1)
 local fall=m:GetAttribute("DropDuration") or 1.8
 local settle=m:GetAttribute("SettleDuration") or 1.45
 local floatY=Path.SurfaceY-.3-minY
 local topY=O.Y+Config.FallHeight-minY+.1
 local startX=O.X-9
 local landD=Path.LandDistance
 local landPos,_,landRight=Path.At(landD)
 local land=landPos+landRight*lateral
 local endD=Path.Total-3
 local travel=(endD-landD)/speed
 local exitTime=1.2
 local duration=fall+travel+exitTime
 local function riverPoint(d,t)
  local pos,_,right=Path.At(d)
  local sway=math.sin(t*.5+seed*10)*.7*math.min(1,t/3)
  return pos+right*(lateral+sway)
 end
 local function pose(elapsed)
  local t=math.clamp(elapsed,0,duration)
  local pos,rot,phase
  if t<fall then
   local u=t/fall
   if u<.3 then
    local k=u/.3
    pos=Vector3.new(startX+(O.X+1-startX)*k*k,topY,O.Z+lateral*k)
    rot=CFrame.identity
   else
    local k=(u-.3)/.7
    local x=O.X+1+(land.X-(O.X+1))*(1-(1-k)^2)
    pos=Vector3.new(x,topY+(floatY-topY)*k*k,(O.Z+lateral)+(land.Z-(O.Z+lateral))*k)
    rot=CFrame.Angles(.15*math.sin(math.pi*k),0,-.2*math.sin(math.pi*k))
   end
   phase="fall"
  elseif t<fall+travel then
   local wt=t-fall
   local d=landD+speed*wt
   local u=math.clamp(wt/settle,0,1)
   local dip=-.85*math.sin(math.pi*u)^2
   local bob=.1*math.sin(wt*2.2+seed*20)*u
   local p=riverPoint(d,wt)
   pos=Vector3.new(p.X,floatY+dip+bob,p.Z)
   rot=CFrame.Angles(.05*math.sin(wt*1.7+seed*9)*u,0,.05*math.sin(wt*1.3+seed*4)*u)
   phase=wt<settle and "land" or "travel"
  else
   local u=(t-fall-travel)/exitTime
   local p=riverPoint(endD+speed*exitTime*u,travel)
   pos=Vector3.new(p.X,floatY-6*u*u,p.Z)
   rot=CFrame.identity
   phase="exit"
  end
  return CFrame.new(pos)*rot,phase,0,duration
 end
 local lastPhase
 local function update()
  local epoch=egg:GetAttribute("Epoch")
  if not epoch then return end
  local elapsed=math.max(0,workspace:GetServerTimeNow()-epoch)
  local cf,phase=pose(elapsed)
  if egg:GetAttribute("RiverEggVisual") and egg:GetAttribute("Collectible")~=(phase=="travel") then egg:SetAttribute("Collectible",phase=="travel") end
  egg:PivotTo(cf)
  label.Position=cf.Position+Vector3.new(0,size.Y*.5+2,0)
  collect.Position=cf.Position
  for _,gui in label:GetDescendants() do if gui:IsA("BillboardGui") then gui.Enabled=(phase=="travel") end end
  local prompt=collect:FindFirstChildOfClass("ProximityPrompt")
  if prompt then prompt.Enabled=(phase=="travel") end
  if game:GetService("RunService"):IsClient() and phase=="land" and lastPhase~="land" then
   local river=workspace:FindFirstChild("WaterfallRiver")
   if river then
    local debris=game:GetService("Debris")
    local tween=game:GetService("TweenService")
    local origin=Vector3.new(cf.Position.X,Path.SurfaceY+.07,cf.Position.Z)
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
  lastPhase=phase
 end
 return update,pose
end
