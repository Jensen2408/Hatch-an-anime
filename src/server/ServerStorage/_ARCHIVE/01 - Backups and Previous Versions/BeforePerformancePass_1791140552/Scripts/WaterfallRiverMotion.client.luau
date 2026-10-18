-- Soft wake ring around river eggs, following the new winding WaterfallRiver.
local RunService=game:GetService("RunService")
local Path=require(game.ReplicatedStorage:WaitForChild("WaterfallRiver"):WaitForChild("RiverPath"))
local r=workspace:WaitForChild("WaterfallRiver")
local visuals=workspace:WaitForChild("LocalRiverEggs",15) or workspace:WaitForChild("WaterfallEggs")
local wakes={}
local surfY=Path.SurfaceY
local function addEgg(egg)
 if not egg:IsA("Model") then return end
 local folder=Instance.new("Folder");folder.Name="EggWake";folder.Parent=r
 local segments={}
 for i=1,22 do
  local p=Instance.new("Part");p.Name="WaterWake";p.Size=Vector3.new(.6,.009,.075);p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic;p.Color=Color3.fromRGB(189,238,242);p.Transparency=1;p.Parent=folder;segments[i]=p
 end
 wakes[egg]={folder=folder,segments=segments}
end
visuals.ChildAdded:Connect(addEgg)
visuals.ChildRemoved:Connect(function(egg) local w=wakes[egg];if w then w.folder:Destroy();wakes[egg]=nil end end)
for _,egg in visuals:GetChildren() do addEgg(egg) end
local startX=Path.At(Path.LandDistance+2).X
local endX=Path.At(Path.Total-4).X
RunService.RenderStepped:Connect(function()
 for egg,w in wakes do
  if egg.Parent then
   local cf,size=egg:GetBoundingBox()
   local pos=cf.Position
   local bottom=pos.Y-size.Y/2
   local visible=math.abs(bottom-surfY)<1.6 and pos.X>startX and pos.X<endX
   for i,p in w.segments do
    local a=.35+(i-1)/21*(math.pi*2-.7)
    local radius=2.65
    p.CFrame=CFrame.new(pos.X+math.cos(a)*radius-.15,surfY+.06,pos.Z+math.sin(a)*radius*.78)*CFrame.Angles(0,-a+math.pi/2,0)
    p.Transparency=visible and (.45+.25*math.abs(i-11.5)/11.5) or 1
   end
  end
 end
end)
