local RunService=game:GetService("RunService")
local m=workspace:WaitForChild("PirateEggConveyor")
local template=game.ServerStorage:WaitForChild("WaterfallEggTemplate")
local folder=workspace:WaitForChild("WaterfallEggs")
local motion=require(m:WaitForChild("RollingMotion"))
local active={}
local serial=0
local function spawnEgg()
 serial+=1
 local egg=template:Clone();egg.Name="RiverEgg_"..serial
 egg:PivotTo(CFrame.new(m:GetAttribute("FallStart")))
 for _,name in {"LabelAnchor","CollectAnchor"} do
  local p=m[name]:Clone();p.CFrame=egg:GetPivot();p.Parent=egg
 end
 egg:SetAttribute("Epoch",workspace:GetServerTimeNow())
 egg.Parent=folder
 local update,pose=motion(m,egg)
 local _,_,_,duration=pose(0)
 active[egg]=update
 local prompt=egg.CollectAnchor:FindFirstChildOfClass("ProximityPrompt")
 local collected=false
 if prompt then prompt.Triggered:Connect(function(player)
  if collected or not egg.Parent then return end
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local bag=player:FindFirstChildOfClass("Backpack")
  if not root or not bag or (root.Position-egg.CollectAnchor.Position).Magnitude>17 then return end
  collected=true
  local tool=Instance.new("Tool");tool.Name="Pirate Egg";tool.ToolTip="Common • FREE";tool.CanBeDropped=false;tool:SetAttribute("Price",0)
  local visual=template:Clone();visual.Name="Egg";visual:ScaleTo(template:GetScale()*.5);visual:PivotTo(CFrame.new());visual.Parent=tool
  local handle=Instance.new("Part");handle.Name="Handle";handle.Size=Vector3.one;handle.Transparency=1;handle.CanCollide=false;handle.Massless=true;handle.Parent=tool
  for _,p in visual:GetDescendants() do if p:IsA("BasePart") then
   p.Anchored=false;p.CanCollide=false;p.CanTouch=false;p.Massless=true
   local weld=Instance.new("WeldConstraint");weld.Part0=handle;weld.Part1=p;weld.Parent=handle
  end end
  tool.Parent=bag;active[egg]=nil;egg:Destroy()
 end) end
 task.delay(duration-.05,function() active[egg]=nil;if egg.Parent then egg:Destroy() end end)
end
RunService.Heartbeat:Connect(function()
 for egg,update in active do if egg.Parent then update() else active[egg]=nil end end
end)
while true do spawnEgg();task.wait(m:GetAttribute("SpawnInterval") or 5) end
