local RunService=game:GetService("RunService")
local model=workspace:WaitForChild("EggConveyor")
local belt=model:WaitForChild("Belt")
local stripes={}
local spacing=6
local length=belt.Size.Z
for i=1,math.floor(length/spacing) do
 local p=Instance.new("Part")
 p.Name="TreadStripe";p.Size=Vector3.new(belt.Size.X-0.3,0.025,0.18)
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false
 p.Color=Color3.fromRGB(75,80,85);p.Material=Enum.Material.SmoothPlastic
 p.Parent=model;stripes[i]=p
end
local offset=0
RunService.RenderStepped:Connect(function(dt)
 if not belt.Parent then return end
 local speed=model:GetAttribute("Speed")
 if typeof(speed)~="number" then speed=12 end
 offset=(offset+dt*math.clamp(speed,-100,100))%length
 for i,p in ipairs(stripes) do
  local z=((i-1)*spacing-offset)%length-length/2
  p.CFrame=belt.CFrame*CFrame.new(0,belt.Size.Y/2+0.015,z)
 end
end)
