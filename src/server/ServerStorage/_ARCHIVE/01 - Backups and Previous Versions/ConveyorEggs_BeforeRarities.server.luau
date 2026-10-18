local TweenService=game:GetService("TweenService")
local conveyor=workspace:WaitForChild("EggConveyor")
local belt=conveyor:WaitForChild("Belt")
local folder=Instance.new("Folder")
folder.Name="ConveyorEggs"
folder.Parent=workspace
local function spawnEgg()
 local egg=game.ServerStorage.ConveyorEggTemplate:Clone()
 egg.Name="BasicEgg"
 egg.Size=egg.Size*(4.4/egg.Size.Y)
 egg.Anchored=true
 egg.CanCollide=false
 egg.CanTouch=false
 egg:SetAttribute("Price",50)
 local start=belt.EggStart.WorldPosition
 local finish=belt.EggEnd.WorldPosition
 local y=belt.Position.Y+belt.Size.Y/2+egg.Size.Y/2
 start=Vector3.new(start.X,y,start.Z)
 finish=Vector3.new(finish.X,y,finish.Z)
 egg.Position=start
 local gui=Instance.new("BillboardGui")
 gui.Name="PriceTag"
 gui.Size=UDim2.fromScale(7,2)
 gui.StudsOffsetWorldSpace=Vector3.new(0,3.8,0)
 gui.MaxDistance=150
 gui.Parent=egg
 local label=Instance.new("TextLabel")
 label.Size=UDim2.fromScale(1,1)
 label.BackgroundTransparency=1
 label.Text="Basic Egg\n$50"
 label.TextColor3=Color3.fromRGB(130,255,135)
 label.TextStrokeColor3=Color3.fromRGB(25,35,25)
 label.TextStrokeTransparency=0.1
 label.Font=Enum.Font.GothamBold
 label.TextScaled=true
 label.Parent=gui
 egg.Parent=folder
 local speed=math.max(math.abs(conveyor:GetAttribute("Speed") or 12),1)
 local tween=TweenService:Create(egg,TweenInfo.new((finish-start).Magnitude/speed,Enum.EasingStyle.Linear),{Position=finish})
 tween.Completed:Once(function() egg:Destroy() end)
 local prompt=Instance.new("ProximityPrompt")
 prompt.Name="CollectPrompt"
 prompt.ActionText="Collect (Free)"
 prompt.ObjectText="Basic Egg"
 prompt.KeyboardKeyCode=Enum.KeyCode.E
 prompt.HoldDuration=0.2
 prompt.MaxActivationDistance=10
 prompt.RequiresLineOfSight=false
 prompt.Parent=egg
 local collected=false
 prompt.Triggered:Connect(function(player)
  if collected or not egg.Parent then return end
  local character=player.Character
  local root=character and character:FindFirstChild("HumanoidRootPart")
  local humanoid=character and character:FindFirstChildOfClass("Humanoid")
  local backpack=player:FindFirstChildOfClass("Backpack")
  local starterGear=player:FindFirstChild("StarterGear")
  if not root or not humanoid or humanoid.Health<=0 or not backpack or not starterGear then return end
  if (root.Position-egg.Position).Magnitude>12 then return end
  collected=true
  prompt.Enabled=false
  local tool=Instance.new("Tool")
  tool.Name="Basic Egg"
  tool.ToolTip="Basic Egg — ready for your plot"
  tool.CanBeDropped=false
  tool:SetAttribute("EggType","Basic")
  tool:SetAttribute("Price",50)
  local handle=game.ServerStorage.ConveyorEggTemplate:Clone()
  handle.Name="Handle"
  handle.Size=handle.Size*(2.2/handle.Size.Y)
  handle.Anchored=false
  handle.CanCollide=false
  handle.CanTouch=false
  handle.Massless=true
  handle.Parent=tool
  tool:Clone().Parent=starterGear
  tool.Parent=backpack
  tween:Cancel()
  if egg.Parent then egg:Destroy() end
 end)

 tween:Play()
end
while true do
 spawnEgg()
 task.wait(6)
end
