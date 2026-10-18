local Players=game:GetService("Players")
local templates=game.ServerStorage:WaitForChild("BrainrotModels")
local plots=workspace:WaitForChild("Plots")
local function setup(plot)
 for _,slot in plot.Slots:GetChildren() do
  local base=slot.Platform
  local prompt=base.PlacePrompt
  prompt.Triggered:Connect(function(player)
   if plot:GetAttribute("OwnerUserId")~=player.UserId or slot:GetAttribute("Occupied") then return end
   local character=player.Character
   local root=character and character:FindFirstChild("HumanoidRootPart")
   local tool=character and character:FindFirstChildOfClass("Tool")
   if not root or (root.Position-base.Position).Magnitude>12 or not tool then return end
   local id=tool:GetAttribute("BrainrotId")
   local template=id and templates:FindFirstChild(id)
   if not template or not template:IsA("Model") then return end
   local rate=template:GetAttribute("IncomePerSecond")
   if type(rate)~="number" or rate<0 or rate~=rate or rate==math.huge then return end
   slot:SetAttribute("Occupied",true)
   local display=template:Clone()
   display.Name=slot.Name.."_Brainrot"
   for _,p in display:GetDescendants() do if p:IsA("BasePart") then p.Anchored=true p.CanCollide=false p.CanTouch=false end end
   local _,size=display:GetBoundingBox()
   display:ScaleTo(display:GetScale()*math.min(1,5/math.max(size.X,size.Y,size.Z)))
   display.Parent=plot.PlacedItems
   local home=CFrame.new(base.Position+Vector3.new(0,4,0))
   display:PivotTo(home)
   tool:Destroy()
   prompt.Enabled=false
   local gui=Instance.new("BillboardGui",base)
   gui.Size=UDim2.fromOffset(90,24) gui.StudsOffset=Vector3.new(0,7,0) gui.MaxDistance=80
   local label=Instance.new("TextLabel",gui) label.Size=UDim2.fromScale(1,1) label.BackgroundTransparency=1
   label.Text="$"..rate.."/s" label.TextColor3=Color3.fromRGB(115,255,143) label.TextStrokeTransparency=.15 label.Font=Enum.Font.GothamBold label.TextSize=15
   task.spawn(function()
    while display.Parent and plot:GetAttribute("OwnerUserId")==player.UserId do
     task.wait(1)
     if not display.Parent or plot:GetAttribute("OwnerUserId")~=player.UserId then break end
     local stats=player:FindFirstChild("leaderstats")
     local cash=stats and stats:FindFirstChild("Cash")
     if cash then cash.Value+=rate end
    end
    if display.Parent then display:Destroy() end
    gui:Destroy() slot:SetAttribute("Occupied",false) prompt.Enabled=true
   end)
   task.spawn(function()
    local t=0
    while display.Parent do t+=.05 display:PivotTo(home*CFrame.new(0,math.sin(t*2)*.35,0)*CFrame.Angles(0,t*.35,0)) task.wait(.05) end
   end)
  end)
 end
end
local function joined(p)
 local stats=p:FindFirstChild("leaderstats") or Instance.new("Folder",p) stats.Name="leaderstats"
 if not stats:FindFirstChild("Cash") then local cash=Instance.new("IntValue",stats) cash.Name="Cash" end
end
Players.PlayerAdded:Connect(joined)
for _,p in Players:GetPlayers() do joined(p) end
for _,plot in plots:GetChildren() do setup(plot) end