local RunService=game:GetService("RunService")
local r=workspace:WaitForChild("WaterfallRiver")
local ribbons=r:WaitForChild("FlowRibbons"):GetChildren()
local streaks=r:WaitForChild("CartoonWaterStreaks"):GetChildren()
local eggs=workspace:WaitForChild("WaterfallEggs")
local wakes={}
local function addEgg(egg)
 if not egg:IsA("Model") then return end
 local folder=Instance.new("Folder");folder.Name="EggWake";folder.Parent=r
 local segments={}
 for i=1,22 do
  local p=Instance.new("Part");p.Name="WaterWake";p.Size=Vector3.new(.6,.009,.075);p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Color=Color3.fromRGB(189,238,242);p.Transparency=.55;p.Parent=folder;segments[i]=p
 end
 wakes[egg]={folder=folder,segments=segments}
end
eggs.ChildAdded:Connect(addEgg)
eggs.ChildRemoved:Connect(function(egg) local w=wakes[egg];if w then w.folder:Destroy();wakes[egg]=nil end end)
for _,egg in eggs:GetChildren() do addEgg(egg) end
RunService.RenderStepped:Connect(function()
 local t=workspace:GetServerTimeNow()
 for _,m in ribbons do
  local x=-300+(m:GetAttribute("Offset")+t*14)%534
  m:PivotTo(CFrame.new(x,24.711,20+m:GetAttribute("Lane")))
 end
 for _,p in streaks do
  local d=(p:GetAttribute("Phase")+t*19)%32;local y=57-d
  p.CFrame=CFrame.new(-306.6+(58-y)*.17,y,p:GetAttribute("Lane"))*CFrame.Angles(0,0,.169)
  p.Transparency=.2+.25*(math.abs(d-16)/16)^4
 end
 for egg,w in wakes do
  if egg.Parent then
   local pos=egg:GetPivot().Position
   local visible=pos.Y<29 and pos.Y>24 and pos.X>-295
   for i,p in w.segments do
    local a=.35+(i-1)/21*(math.pi*2-.7)
    local radius=2.65
    p.CFrame=CFrame.new(pos.X+math.cos(a)*radius-.15,24.716,pos.Z+math.sin(a)*radius*.78)*CFrame.Angles(0,-a+math.pi/2,0)
    p.Transparency=visible and (.45+.25*math.abs(i-11.5)/11.5) or 1
   end
  end
 end
end)
local glints=r:WaitForChild("RiverMistAndRipples"):WaitForChild("SurfaceShimmer"):GetChildren()
RunService.RenderStepped:Connect(function()
 local t=workspace:GetServerTimeNow()
 for _,p in glints do
  p.Position=Vector3.new(-300+(p:GetAttribute("Offset")+t*14)%534,24.711,20+p:GetAttribute("Lane"))
  p.Transparency=.78+.16*math.sin(t*1.4+p:GetAttribute("Phase"))
 end
end)
