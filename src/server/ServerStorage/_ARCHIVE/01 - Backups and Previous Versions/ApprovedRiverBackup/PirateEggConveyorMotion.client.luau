local RunService=game:GetService("RunService")
local m=workspace:WaitForChild("PirateEggConveyor")
local folder=workspace:WaitForChild("WaterfallEggs")
local motion=require(m:WaitForChild("RollingMotion"))
local active={}
local function added(egg)
 if not egg:IsA("Model") then return end
 task.spawn(function()
  egg:WaitForChild("LabelAnchor");egg:WaitForChild("CollectAnchor")
  if egg.Parent then active[egg]=motion(m,egg) end
 end)
end
folder.ChildAdded:Connect(added)
folder.ChildRemoved:Connect(function(egg) active[egg]=nil end)
for _,egg in folder:GetChildren() do added(egg) end
RunService.RenderStepped:Connect(function()
 for egg,update in active do if egg.Parent then update() else active[egg]=nil end end
end)
