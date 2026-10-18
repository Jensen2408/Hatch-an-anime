
local Format = require(game:GetService("ReplicatedStorage"):WaitForChild("CharacterInventory"):WaitForChild("InventoryFormat"))
local Slots={}
Slots.Prices={0,250,2500,25000,150000,750000,5000000,25000000,150000000,750000000,3000000000,15000000000}
for i=13,36 do Slots.Prices[i]=Slots.Prices[i-1]*3 end
function Slots.Capacity(plot)return math.clamp(plot:GetAttribute("TempleLevel") or 1,1,3)*12 end
function Slots.CanUpgrade(plot)
 local cap=Slots.Capacity(plot)
 for i=1,cap do
  local slot=plot.Slots:FindFirstChild(string.format("Slot%02d",i))
  if not slot or slot:GetAttribute("Unlocked")~=true then return false end
 end
 return true
end
local function index(slot) return tonumber(slot.Name:match("%d+")) or 1 end
function Slots.Refresh(plot)
 local claimed=(plot:GetAttribute("OwnerUserId") or 0)~=0
 for _,slot in ipairs(plot.Slots:GetChildren()) do
  local i=index(slot)
  local available=i<=Slots.Capacity(plot)
  slot:SetAttribute("Available",available)
  for _,v in slot:GetDescendants()do
   if v:IsA("BasePart")then
    if v:GetAttribute("ClaimTransparency")==nil then v:SetAttribute("ClaimTransparency",v.Transparency);v:SetAttribute("ClaimCollide",v.CanCollide);v:SetAttribute("ClaimQuery",v.CanQuery)end
    v.Transparency=claimed and available and v:GetAttribute("ClaimTransparency") or 1
    v.CanCollide=claimed and available and v:GetAttribute("ClaimCollide") or false
    v.CanQuery=claimed and available and v:GetAttribute("ClaimQuery") or false
   end
  end
  local unlocked=slot:GetAttribute("Unlocked")==true
  local occupied=slot:GetAttribute("Occupied")==true
  local previous=plot.Slots:FindFirstChild(string.format("Slot%02d",i-1))
  local nextAvailable=i==1 or (previous and previous:GetAttribute("Unlocked")==true)
  local prompt=slot.Platform.PlacePrompt
  prompt.Enabled=claimed and available and not occupied and (unlocked or nextAvailable)
  prompt.ActionText=unlocked and "Place character" or ("Unlock • "..Slots.Format(Slots.Prices[i] or 250000))
  prompt.ObjectText="Character slot "..i
  prompt.HoldDuration=unlocked and .15 or .4
  local gui=slot.Platform:FindFirstChild("SlotUnlockLabel")
  if gui and gui:FindFirstChild("Card") then
   gui.Enabled=claimed and available and not unlocked
   local card=gui.Card local price=Slots.Prices[i] or 250000
   card.Title.Text="SLOT "..i
   if nextAvailable then
    gui.Size=UDim2.fromScale(4.6,2) card.BackgroundColor3=Color3.fromRGB(34,22,40) card.BackgroundTransparency=1
    card.Stroke.Color=Color3.fromRGB(255,200,90) card.Stroke.Transparency=1
    card.Title.TextColor3=Color3.new(1,1,1) card.Price.Visible=false card.Locked.Visible=false -- the green BUY SLOT prompt already shows the price card.Stroke.Enabled=false
    card.Price.Amount.Text=Slots.Format(price)
   else
    gui.Size=UDim2.fromScale(3.5,1.5) card.BackgroundColor3=Color3.fromRGB(18,14,22) card.BackgroundTransparency=.35
    card.Stroke.Color=Color3.fromRGB(120,110,130) card.Stroke.Transparency=.5
    card.Title.TextColor3=Color3.fromRGB(170,165,180) card.Price.Visible=false card.Locked.Visible=true card.Stroke.Enabled=true
    card.Locked.Text="🔒  UNLOCK SLOT "..(i-1).." FIRST"
   end
  end
 end
end
function Slots.Format(n)
 return "$" .. Format.Short(n)
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
 if i>Slots.Capacity(plot) then return false,"Upgrade your temple to unlock this floor" end
 local previous=plot.Slots:FindFirstChild(string.format("Slot%02d",i-1))
 if i>1 and (not previous or not previous:GetAttribute("Unlocked")) then return false,"Unlock the previous slot first" end
 local char=player.Character local root=char and char:FindFirstChild("HumanoidRootPart") local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.Health<=0 or (root.Position-slot.Platform.Position).Magnitude>12 then return false,"Too far away" end
 local stats=player:FindFirstChild("leaderstats") local cash=stats and stats:FindFirstChild("Cash")
 local price=Slots.Prices[i] or 250000
 if not cash or cash.Value<price then return false,"Not enough money" end
 -- No yielding between payment and unlock, preventing duplicate charges.
 cash.Value-=price slot:SetAttribute("Unlocked",true) Slots.Refresh(plot)
 return true
end
function Slots.Setup(plot)
 for _,slot in ipairs(plot.Slots:GetChildren()) do
  local base=slot.Platform
  local old=base:FindFirstChild("SlotUnlockLabel") if old then old:Destroy() end
  local gui=Instance.new("BillboardGui") gui.Name="SlotUnlockLabel" gui.Size=UDim2.fromScale(4.6,2) gui.StudsOffsetWorldSpace=Vector3.new(0,2.6,0)
  gui.MaxDistance=45 gui.AlwaysOnTop=false gui.LightInfluence=0 gui.Parent=base
  local card=Instance.new("Frame") card.Name="Card" card.Size=UDim2.fromScale(1,1) card.BorderSizePixel=0 card.Parent=gui
  Instance.new("UICorner",card).CornerRadius=UDim.new(0,12)
  local st=Instance.new("UIStroke") st.Name="Stroke" st.Thickness=2.5 st.ApplyStrokeMode=Enum.ApplyStrokeMode.Border st.Parent=card
  local title=Instance.new("TextLabel") title.Name="Title" title.BackgroundTransparency=1 title.Size=UDim2.new(1,0,.42,0) title.Position=UDim2.fromScale(0,.06)
  title.Font=Enum.Font.FredokaOne title.TextScaled=true title.Parent=card
  local tst=Instance.new("UIStroke") tst.Thickness=2 tst.Color=Color3.fromRGB(20,10,24) tst.Parent=title
  local pc=Instance.new("UITextSizeConstraint") pc.MaxTextSize=26 pc.Parent=title
  local price=Instance.new("Frame") price.Name="Price" price.AnchorPoint=Vector2.new(.5,1) price.Position=UDim2.fromScale(.5,.91) price.Size=UDim2.new(.82,0,.42,0)
  price.BackgroundColor3=Color3.fromRGB(255,196,60) price.BorderSizePixel=0 price.Parent=card
  Instance.new("UICorner",price).CornerRadius=UDim.new(1,0)
  local pg=Instance.new("UIGradient") pg.Rotation=90 pg.Color=ColorSequence.new(Color3.fromRGB(255,232,140),Color3.fromRGB(240,160,30)) pg.Parent=price
  local ps=Instance.new("UIStroke") ps.Color=Color3.fromRGB(120,70,10) ps.Thickness=2 ps.ApplyStrokeMode=Enum.ApplyStrokeMode.Border ps.Parent=price
  local amt=Instance.new("TextLabel") amt.Name="Amount" amt.BackgroundTransparency=1 amt.Size=UDim2.fromScale(1,1) amt.Font=Enum.Font.FredokaOne amt.TextScaled=true
  amt.TextColor3=Color3.fromRGB(70,35,5) amt.Parent=price
  local apad=Instance.new("UIPadding") apad.PaddingTop=UDim.new(.1,0) apad.PaddingBottom=UDim.new(.1,0) apad.Parent=amt
  local locked=Instance.new("TextLabel") locked.Name="Locked" locked.BackgroundTransparency=1 locked.AnchorPoint=Vector2.new(.5,1) locked.Position=UDim2.fromScale(.5,.9)
  locked.Size=UDim2.new(.92,0,.36,0) locked.Font=Enum.Font.GothamBold locked.TextScaled=true locked.TextColor3=Color3.fromRGB(165,160,175) locked.Parent=card
 end
 Slots.Reset(plot)
 plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function() Slots.Reset(plot) task.defer(Slots.Refresh,plot) end)
 plot:GetAttributeChangedSignal("TempleLevel"):Connect(function() task.defer(Slots.Refresh,plot) end)
end
return Slots
