
local Slots={}
Slots.Prices={0,250,2500,25000,150000,750000,5000000,25000000,150000000,750000000,3000000000,15000000000}
local function index(slot) return tonumber(slot.Name:match("%d+")) or 1 end
function Slots.Refresh(plot)
 local claimed=(plot:GetAttribute("OwnerUserId") or 0)~=0
 for _,slot in ipairs(plot.Slots:GetChildren()) do
  local i=index(slot) local unlocked=slot:GetAttribute("Unlocked")==true
  local occupied=slot:GetAttribute("Occupied")==true
  local previous=plot.Slots:FindFirstChild(string.format("Slot%02d",i-1))
  local nextAvailable=i==1 or (previous and previous:GetAttribute("Unlocked")==true)
  local prompt=slot.Platform.PlacePrompt
  prompt.Enabled=claimed and not occupied and (unlocked or nextAvailable)
  prompt.ActionText=unlocked and "Place character" or ("Unlock • $"..tostring(Slots.Prices[i] or 250000))
  prompt.ObjectText="Character slot "..i
  prompt.HoldDuration=unlocked and .15 or .4
  local gui=slot.Platform:FindFirstChild("SlotUnlockLabel")
  if gui then
   gui.Enabled=claimed and not unlocked
   gui.Text.Text=nextAvailable and ("SLOT "..i.."\nUNLOCK • $"..tostring(Slots.Prices[i] or 250000)) or ("SLOT "..i.."\nLOCKED")
   gui.Text.TextColor3=nextAvailable and Color3.fromRGB(255,213,124) or Color3.fromRGB(165,171,185)
  end
 end
end
function Slots.Reset(plot)
 for _,slot in ipairs(plot.Slots:GetChildren()) do
  slot:SetAttribute("Unlocked",index(slot)==1)
  slot:SetAttribute("UnlockPrice",Slots.Prices[index(slot)] or 250000)
 end
 Slots.Refresh(plot)
end
function Slots.Purchase(plot,slot,player)
 if plot:GetAttribute("OwnerUserId")~=player.UserId or slot:GetAttribute("Unlocked") or slot:GetAttribute("Occupied") then return false,"Unavailable" end
 local i=index(slot)
 local previous=plot.Slots:FindFirstChild(string.format("Slot%02d",i-1))
 if i>1 and (not previous or not previous:GetAttribute("Unlocked")) then return false,"Unlock the previous slot first" end
 local char=player.Character local root=char and char:FindFirstChild("HumanoidRootPart") local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.Health<=0 or (root.Position-slot.Platform.Position).Magnitude>12 then return false,"Too far away" end
 local stats=player:FindFirstChild("leaderstats") local cash=stats and stats:FindFirstChild("Cash")
 local price=Slots.Prices[i] or 250000
 if not cash or cash.Value<price then return false,"Not enough cash" end
 -- No yielding between payment and unlock, preventing duplicate charges.
 cash.Value-=price slot:SetAttribute("Unlocked",true) Slots.Refresh(plot)
 return true
end
function Slots.Setup(plot)
 for _,slot in ipairs(plot.Slots:GetChildren()) do
  local base=slot.Platform
  local gui=base:FindFirstChild("SlotUnlockLabel") or Instance.new("BillboardGui")
  gui.Name="SlotUnlockLabel" gui.Size=UDim2.fromOffset(180,48) gui.StudsOffsetWorldSpace=Vector3.new(0,1.8,0) gui.MaxDistance=45 gui.AlwaysOnTop=false gui.Parent=base
  local text=gui:FindFirstChild("Text") or Instance.new("TextLabel")
  text.Name="Text" text.Size=UDim2.fromScale(1,1) text.BackgroundTransparency=1 text.Font=Enum.Font.GothamBold text.TextSize=14 text.TextStrokeTransparency=.15 text.Parent=gui
 end
 Slots.Reset(plot)
 plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function() Slots.Reset(plot) task.defer(Slots.Refresh,plot) end)
 plot:GetAttributeChangedSignal("TempleLevel"):Connect(function() task.defer(Slots.Refresh,plot) end)
end
return Slots
