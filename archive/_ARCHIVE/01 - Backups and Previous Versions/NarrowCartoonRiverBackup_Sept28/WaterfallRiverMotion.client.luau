local r=workspace:WaitForChild("WaterfallRiver")
local foam=r:WaitForChild("RiverFoam"):GetChildren()
game:GetService("RunService").RenderStepped:Connect(function()
 local t=workspace:GetServerTimeNow()
 for _,p in foam do
  local x=-299+(p:GetAttribute("Offset")+t*12)%534
  p.Position=Vector3.new(x,24.05+.025*math.sin(t*2+p:GetAttribute("Phase")),20+4*math.sin((x+299)/50)+p:GetAttribute("Lane"))
  p.Transparency=.22+.12*math.sin(t+p:GetAttribute("Phase"))
 end
end)
local strokes=r:WaitForChild("CartoonWaterStreaks"):GetChildren()
game:GetService("RunService").RenderStepped:Connect(function()
 local t=workspace:GetServerTimeNow()
 for _,p in strokes do
  local d=(p:GetAttribute("Phase")+t*19)%32
  local y=57-d
  p.CFrame=CFrame.new(-306.6+(58-y)*.17,y,p:GetAttribute("Lane"))*CFrame.Angles(0,0,.169)
  p.Transparency=.2+.25*(math.abs(d-16)/16)^4
 end
end)
