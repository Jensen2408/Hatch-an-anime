local RunService=game:GetService("RunService")
local r=workspace:WaitForChild("WaterfallRiver")
local foam=r:WaitForChild("RiverFoam"):GetChildren()
local edges=r:WaitForChild("EdgeFoam"):GetChildren()
local streaks=r:WaitForChild("CartoonWaterStreaks"):GetChildren()
local eggs=workspace:WaitForChild("WaterfallEggs")
local wakes={}
local function addEgg(egg)
 if not egg:IsA("Model") then return end
 local folder=Instance.new("Folder");folder.Name="EggWake";folder.Parent=r
 local segments={}
 for i=1,24 do
  local p=Instance.new("Part");p.Name="WakeArc";p.Size=Vector3.new(.68,.035,.12);p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Color=Color3.fromRGB(225,255,253);p.Parent=folder;segments[i]=p
 end
 wakes[egg]={folder=folder,segments=segments}
end
eggs.ChildAdded:Connect(addEgg)
eggs.ChildRemoved:Connect(function(egg) local w=wakes[egg];if w then w.folder:Destroy();wakes[egg]=nil end end)
for _,egg in eggs:GetChildren() do addEgg(egg) end
RunService.RenderStepped:Connect(function()
 local t=workspace:GetServerTimeNow()
 for _,p in foam do
  local x=-307+(p:GetAttribute("Offset")+t*12)%547
  p.CFrame=CFrame.new(x,24.77,20+p:GetAttribute("Lane"))*CFrame.Angles(0,.07*math.sin(t+p:GetAttribute("Phase")),0)
  p.Transparency=.32+.12*math.sin(t+p:GetAttribute("Phase"))
 end
 for _,b in edges do
  local phase=t*2-b:GetAttribute("Phase")
  local x=b:GetAttribute("BaseX");local side=b:GetAttribute("Side")
  local z0=20+side*(4.9+.7*math.sin(phase))
  local z1=20+side*(4.9+.7*math.sin(phase-1.3))
  b.Attachment0.CFrame=CFrame.fromMatrix(Vector3.new(x,24.78,z0),Vector3.xAxis,Vector3.zAxis,-Vector3.yAxis)*CFrame.Angles(0,0, .4*math.cos(phase))
  b.Attachment1.CFrame=CFrame.fromMatrix(Vector3.new(x+12,24.78,z1),Vector3.xAxis,Vector3.zAxis,-Vector3.yAxis)*CFrame.Angles(0,0, .4*math.cos(phase-1.3))
 end
 for _,p in streaks do
  local d=(p:GetAttribute("Phase")+t*19)%32;local y=57-d
  p.CFrame=CFrame.new(-306.6+(58-y)*.17,y,p:GetAttribute("Lane"))*CFrame.Angles(0,0,.169)
  p.Transparency=.2+.25*(math.abs(d-16)/16)^4
 end
 for egg,w in wakes do
  if egg.Parent then
   local pos=egg:GetPivot().Position
   local visible=pos.Y<29 and pos.Y>24
   for i,p in w.segments do
    local a=i/24*math.pi*2
    local radius=2.8+.12*math.sin(t*3)
    p.CFrame=CFrame.new(pos.X+math.cos(a)*radius,24.81,pos.Z+math.sin(a)*radius*.8)*CFrame.Angles(0,-a+math.pi/2,0)
    p.Transparency=visible and .18 or 1
   end
  end
 end
end)
local ribbons=r:WaitForChild("FlowRibbons"):GetChildren()
RunService.RenderStepped:Connect(function()
 local t=workspace:GetServerTimeNow()
 for _,model in ribbons do
  local x=-300+(model:GetAttribute("Offset")+t*10)%534
  local z=20+model:GetAttribute("Lane")+.15*math.sin(t+model:GetAttribute("Phase"))
  model:PivotTo(CFrame.new(x,24.8,z))
 end
end)
