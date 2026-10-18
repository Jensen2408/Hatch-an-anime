local Players=game:GetService("Players")
local template=game.ServerStorage:WaitForChild("HatchChamberTemplate")
local plots=workspace:WaitForChild("Plots")
local FX=require(script.Parent.UpgradeEffects)
local function setup(plot)
 local yard=plot:WaitForChild("ChamberYard")
 local sign=yard.ChamberUpgradeSign
 local chambers=Instance.new("Folder") chambers.Name="Chambers" chambers.Parent=plot
 local cooldown=0
 local busy=false
 local function refresh()
  local count=#chambers:GetChildren()
  local owned=(plot:GetAttribute("OwnerUserId") or 0)~=0
  sign.SurfaceGui.Label.Text=count<3 and ("ADD CHAMBER\nFREE • "..count.." / 3") or "3 CHAMBERS\nFULLY UPGRADED"
  -- locked while an unlock animation is playing, so clicks cannot stack
  local open=owned and count<3 and not busy
  sign.ProximityPrompt.Enabled=open
  sign.ClickDetector.MaxActivationDistance=open and 18 or 0
  plot:SetAttribute("ChamberCount",count)
 end
 local function place(index,prepare)
  local h=template:Clone() h.Name="Chamber"..index
  h:SetAttribute("ClientEffectsReady",nil)
  h:SetAttribute("OwnerUserId",plot:GetAttribute("OwnerUserId"))
  h:PivotTo(plot.TempleAnchor.CFrame*CFrame.new(-44,.25,15-(index-1)*17)*CFrame.Angles(0,-math.pi/2,0))
  if prepare then prepare(h) end
  h.Parent=chambers
  refresh()
  return h
 end
 local function spawnChamber(index,reveal)
  if not reveal then return place(index) end
  local expectedOwner=plot:GetAttribute("OwnerUserId")
  local _,size=template:GetBoundingBox()
  return FX.Play({
   anchor=plot.TempleAnchor.CFrame*CFrame.new(-44,.25,15-(index-1)*17),
   radius=math.max(size.X,size.Z)*.5,
   height=size.Y,
   oldModel=nil, -- brand new chamber: nothing to glow during the windup
   ghostSource=template,
   swap=function(prepare) return place(index,prepare) end,
   ownerUserId=expectedOwner,
   palette=FX.Palettes.Chamber,
   isValid=function() return plot:GetAttribute("OwnerUserId")==expectedOwner and expectedOwner~=0 end,
  })
 end
 local function ownership()
  busy=false
  chambers:ClearAllChildren()
  if (plot:GetAttribute("OwnerUserId") or 0)~=0 then spawnChamber(1,false) end
  refresh()
 end
 local function upgrade(player)
  if typeof(player)~="Instance" or not player:IsA("Player") or player.Parent~=Players or player.UserId~=plot:GetAttribute("OwnerUserId") then return end
  if busy then return end
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if not root or (root.Position-sign.Position).Magnitude>20 or os.clock()<cooldown or #chambers:GetChildren()>=3 then return end
  busy=true
  cooldown=os.clock()+2.4
  refresh()
  local index=#chambers:GetChildren()+1
  task.spawn(function()
   if plot:GetAttribute("OwnerUserId")~=player.UserId then return end
   local ok,err=pcall(spawnChamber,index,true)
   if plot:GetAttribute("OwnerUserId")~=player.UserId then return end
   if not ok then
    warn("Chamber unlock effect failed, falling back to instant build: "..tostring(err))
    if not chambers:FindFirstChild("Chamber"..index) then pcall(spawnChamber,index,false) end
   end
   busy=false
   refresh()
  end)
 end
 sign.ProximityPrompt.Triggered:Connect(upgrade)
 sign.ClickDetector.MouseClick:Connect(upgrade)
 local request=Instance.new("BindableEvent") request.Name="RequestChamberUpgrade" request.Parent=plot request.Event:Connect(upgrade)
 plot:GetAttributeChangedSignal("OwnerUserId"):Connect(ownership)
 ownership()
end
for _,p in plots:GetChildren() do task.spawn(setup,p) end
plots.ChildAdded:Connect(function(p) task.spawn(setup,p) end)
