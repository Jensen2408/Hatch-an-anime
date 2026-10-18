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
 local highlight=Instance.new("Highlight");highlight.FillTransparency=1;highlight.OutlineColor=entry.Color;highlight.OutlineTransparency=0.35;highlight.DepthMode=Enum.HighlightDepthMode.Occluded;highlight.Parent=egg
 local gui=Instance.new("BillboardGui");gui.Name="PriceTag";gui.Size=UDim2.fromScale(8,3);gui.StudsOffsetWorldSpace=Vector3.new(0,4.3,0);gui.MaxDistance=110;gui.Parent=egg
 local frame=Instance.new("Frame");frame.Size=UDim2.fromScale(1,1);frame.BackgroundColor3=Color3.fromRGB(24,28,36);frame.BackgroundTransparency=0.12;frame.Parent=gui
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0.15,0);corner.Parent=frame
 local stroke=Instance.new("UIStroke");stroke.Color=entry.Color;stroke.Thickness=2;stroke.Parent=frame
 local function line(text,ypos,height,color)
 local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Position=UDim2.fromScale(0.05,ypos);t.Size=UDim2.fromScale(0.9,height);t.Text=text;t.Font=Enum.Font.GothamBold;t.TextScaled=true;t.TextColor3=color;t.Parent=frame
 end
 line(string.upper(entry.Rarity),0.06,0.22,entry.Color)
 line(entry.Name.." Egg",0.31,0.29,Color3.new(1,1,1))
 line("$"..entry.Price.."  •  FREE TEST",0.68,0.2,Color3.fromRGB(170,235,185))
 local speed=math.max(math.abs(conveyor:GetAttribute("Speed") or 12),1)
 local tween=TweenService:Create(egg,TweenInfo.new((finish-start).Magnitude/speed,Enum.EasingStyle.Linear),{Position=finish})
 local prompt=Instance.new("ProximityPrompt");prompt.Name="CollectPrompt";prompt.ActionText="Collect";prompt.ObjectText=entry.Name.." • "..entry.Rarity;prompt.HoldDuration=0.15;prompt.MaxActivationDistance=10;prompt.RequiresLineOfSight=false;prompt.Parent=egg
 local collected=false
 prompt.Triggered:Connect(function(player)
 if collected or not egg.Parent then return end
 local c=player.Character;local root=c and c:FindFirstChild("HumanoidRootPart");local hum=c and c:FindFirstChildOfClass("Humanoid")
 local bag=player:FindFirstChildOfClass("Backpack");local gear=player:FindFirstChild("StarterGear")
 if not root or not hum or hum.Health<=0 or not bag or not gear or (root.Position-egg.Position).Magnitude>12 then return end
 collected=true;prompt.Enabled=false
 local tool=makeTool(entry);tool:Clone().Parent=gear;tool.Parent=bag
 event:FireClient(player,entry.Id)
 tween:Cancel();egg:Destroy()
 end)
 tween.Completed:Once(function() if egg.Parent then egg:Destroy() end end)
 tween:Play()
end
while true do spawnEgg();task.wait(6) end