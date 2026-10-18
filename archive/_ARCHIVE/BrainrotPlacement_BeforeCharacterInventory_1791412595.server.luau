local Players=game:GetService("Players")
local Catalog=require(game.ReplicatedStorage.CharacterCatalog)
local Economy=require(game.ReplicatedStorage.CharacterEconomy)
local SlotUnlocks=require(script.Parent.TempleSlotUnlocks)
local templates=game.ServerStorage:WaitForChild("BrainrotModels")
local plots=workspace:WaitForChild("Plots")
local function setup(plot)
 SlotUnlocks.Setup(plot)
 for _,slot in plot.Slots:GetChildren() do
  local base=slot.Platform
  local prompt=base.PlacePrompt
  local function placeCharacter(player)
   if plot:GetAttribute("OwnerUserId")~=player.UserId or slot:GetAttribute("Occupied") then return end
   if not slot:GetAttribute("Unlocked") then
    local bought,reason=SlotUnlocks.Purchase(plot,slot,player)
    if not bought and reason=="Not enough cash" then
     local old=prompt.ActionText prompt.ActionText="Not enough cash"
     task.delay(1.5,function() if prompt.Parent then SlotUnlocks.Refresh(plot) end end)
    end
    return
   end
   local character=player.Character
   local root=character and character:FindFirstChild("HumanoidRootPart")
   local tool=character and character:FindFirstChildOfClass("Tool")
   if not root or (root.Position-base.Position).Magnitude>12 or not tool then return end
   local id=tool:GetAttribute("BrainrotId")
   local template=id and templates:FindFirstChild(id)
   if tool:GetAttribute("GoldVariant") then template=game.ServerStorage.FutureUpdateContent.Characters:FindFirstChild("Golden Pirate") end
   if not template or not template:IsA("Model") then return end
   local stats=Economy.Read(tool,id) or Economy.Roll(id)
   local rate=stats.IncomePerSecond
   if type(rate)~="number" or rate<0 or rate~=rate or rate==math.huge then return end
   local placementToken=game:GetService("HttpService"):GenerateGUID(false)
   slot:SetAttribute("PlacementToken",placementToken)
   slot:SetAttribute("Occupied",true)
   local display=template:Clone()
   display.Name=slot.Name.."_Brainrot"
   for _,p in display:GetDescendants() do if p:IsA("BasePart") then p.Anchored=true p.CanCollide=false p.CanTouch=false end end
   local _,size=display:GetBoundingBox()
   display:ScaleTo(display:GetScale()*4.5/math.max(size.Y,.01))
   display.Parent=plot.PlacedItems
   local stand=slot:FindFirstChild("MoneyStand")
   local support=stand and stand.CharacterSlot or base
   local box,displaySize=display:GetBoundingBox()
   local center=support.Position+Vector3.new(0,support.Size.Y/2+displaySize.Y/2,0)
   local facing=stand and -stand.Plate.CFrame.LookVector or base.CFrame.LookVector
   display.PrimaryPart=nil
   display.WorldPivot=CFrame.new(box.Position)
   local home=CFrame.lookAt(center,center+facing)
   display:SetAttribute("DisplayHeight",4.5)
   display:SetAttribute("SlotSurfaceY",support.Position.Y+support.Size.Y/2)
   display:PivotTo(home)
   display:SetAttribute("FloatHeight",.65)
   game.CollectionService:AddTag(display,"FloatingCharacter")
   Economy.Apply(display,id,stats)
   Economy.Label(display,id,stats)
   local entry=Catalog.ById[id] if entry then Catalog.Label(display,entry) end
   tool:Destroy()
   prompt.Enabled=false
   local gui=display.PowerInfo
   task.spawn(function()
    while display.Parent and plot:GetAttribute("OwnerUserId")==player.UserId do
     task.wait(1)
     if not display.Parent or plot:GetAttribute("OwnerUserId")~=player.UserId then break end
     local stats=player:FindFirstChild("leaderstats")
     local cash=stats and stats:FindFirstChild("Cash")
     local stand=slot:FindFirstChild("MoneyStand")
     if stand and stand:GetAttribute("OwnerUserId")==player.UserId then
      stand:SetAttribute("IncomePerSecond",rate)
      stand:SetAttribute("Stored",(stand:GetAttribute("Stored") or 0)+rate*(workspace:GetAttribute("OwnerIncomeMultiplier") or 1))
     end
    end
    game.CollectionService:RemoveTag(display,"FloatingCharacter")
    if display.Parent then display:Destroy() end
    gui:Destroy()
    if slot:GetAttribute("PlacementToken")==placementToken then slot:SetAttribute("Occupied",false) slot:SetAttribute("PlacementToken",nil) SlotUnlocks.Refresh(plot) end
   end)
   -- FloatingCharacters handles showcase motion locally; no competing server animation.
  end
  prompt.Triggered:Connect(placeCharacter)
  local request=base:FindFirstChild("RequestPlaceCharacter") or Instance.new("BindableEvent")
  request.Name="RequestPlaceCharacter" request.Parent=base request.Event:Connect(placeCharacter)
 end
end
local function joined(p)
 local stats=p:FindFirstChild("leaderstats") or Instance.new("Folder",p) stats.Name="leaderstats"
 if not stats:FindFirstChild("Cash") then local cash=Instance.new("IntValue",stats) cash.Name="Cash" end
end
Players.PlayerAdded:Connect(joined)
for _,p in Players:GetPlayers() do joined(p) end
for _,plot in plots:GetChildren() do setup(plot) end