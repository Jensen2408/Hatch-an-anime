local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local templates=game.ServerStorage:WaitForChild("EggTemplates")
local config=require(ReplicatedStorage:WaitForChild("EggCatalog"))
local event=ReplicatedStorage:WaitForChild("EggCollected")
local conveyor=workspace:WaitForChild("EggConveyor")
local belt=conveyor:WaitForChild("Belt")
local folder=Instance.new("Folder");folder.Name="ConveyorEggs";folder.Parent=workspace
local random=Random.new()
local function choose()
 local roll=random:NextNumber(0,100)
 local sum=0
 for _,entry in ipairs(config) do sum+=entry.Weight;if roll<sum then return entry end end
 return config[#config]
end
local function makeTool(entry)
 local tool=Instance.new("Tool");tool.Name=entry.Name.." Egg";tool.ToolTip=entry.Rarity.." • "..entry.Name
 tool.CanBeDropped=false
 tool:SetAttribute("EggType",entry.Id);tool:SetAttribute("Rarity",entry.Rarity);tool:SetAttribute("Price",entry.Price)
 tool:SetAttribute("EggId",game:GetService("HttpService"):GenerateGUID(false))
 local handle=templates[entry.Id]:Clone();handle.Name="Handle";handle.Size*=2.6/handle.Size.Y
 handle.Anchored=false;handle.CanCollide=false;handle.CanTouch=false;handle.Massless=true;handle.Parent=tool
 return tool
end
local function spawnEgg()
 local entry=choose()
 local egg=templates[entry.Id]:Clone();egg.Name=entry.Id
 egg.Size*=4.8/egg.Size.Y;egg.Anchored=true;egg.CanCollide=false;egg.CanTouch=false
 egg:SetAttribute("EggType",entry.Id);egg:SetAttribute("Rarity",entry.Rarity);egg:SetAttribute("Price",entry.Price)
 local start=belt.EggStart.WorldPosition;local finish=belt.EggEnd.WorldPosition
 local y=belt.Position.Y+belt.Size.Y/2+egg.Size.Y/2+0.1
 start=Vector3.new(start.X,y,start.Z);finish=Vector3.new(finish.X,y,finish.Z)
 egg.Position=start;egg.Parent=folder
 local Style=require(ReplicatedStorage.EggUIStyle)
 local gui=Instance.new("BillboardGui");gui.Name="PriceTag";gui.Size=UDim2.fromScale(7.6,3.2);gui.StudsOffsetWorldSpace=Vector3.new(0,4.3,0);gui.MaxDistance=95;gui.Parent=egg
 local frame=Style.Panel(gui,entry.Color)
 Style.Text(frame,entry.Name.." Egg",UDim2.fromScale(.04,.06),UDim2.fromScale(.92,.33))
 Style.Text(frame,string.upper(entry.Rarity),UDim2.fromScale(.08,.43),UDim2.fromScale(.84,.20),Color3.fromRGB(255,239,154))
 local price=Instance.new("Frame");price.Position=UDim2.fromScale(.25,.69);price.Size=UDim2.fromScale(.5,.26);price.BackgroundColor3=Color3.fromRGB(54,189,72);price.BorderSizePixel=0;price.ZIndex=2;price.Parent=frame
 local round=Instance.new("UICorner");round.CornerRadius=UDim.new(.25,0);round.Parent=price
 local stroke=Instance.new("UIStroke");stroke.Thickness=2;stroke.Color=Color3.fromRGB(20,30,20);stroke.Parent=price
 Style.Text(price,"$"..entry.Price,UDim2.fromScale(.04,0),UDim2.fromScale(.92,1))
 local speed=math.max(math.abs(conveyor:GetAttribute("Speed") or 12),1)
 local tween=TweenService:Create(egg,TweenInfo.new((finish-start).Magnitude/speed,Enum.EasingStyle.Linear),{Position=finish})
 local prompt=Instance.new("ProximityPrompt");prompt.Name="CollectPrompt";prompt.ActionText="Collect (Free)";prompt.ObjectText=entry.Name.." • "..entry.Rarity;prompt.HoldDuration=0.15;prompt.MaxActivationDistance=10;prompt.RequiresLineOfSight=false;prompt.Parent=egg
 local collected=false
 prompt.Triggered:Connect(function(player)
 if collected or not egg.Parent then return end
 local c=player.Character;local root=c and c:FindFirstChild("HumanoidRootPart");local hum=c and c:FindFirstChildOfClass("Humanoid")
 local bag=player:FindFirstChildOfClass("Backpack");local gear=player:FindFirstChild("StarterGear")
 if not root or not hum or hum.Health<=0 or not bag or not gear or (root.Position-egg.Position).Magnitude>12 then return end
 collected=true;prompt.Enabled=false
 local tool=makeTool(entry);tool:Clone().Parent=gear;tool.Parent=bag
 event:FireClient(player,entry.Id,egg.CFrame,egg.Size)
 tween:Cancel();egg:Destroy()
 end)
 tween.Completed:Once(function() if egg.Parent then egg:Destroy() end end)
 tween:Play()
end
while true do spawnEgg();task.wait(6) end