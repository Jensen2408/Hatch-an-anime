local Players=game:GetService("Players")
local template=game.ServerStorage:WaitForChild("HatchChamberTemplate")
local plots=workspace:WaitForChild("Plots")
local function setup(plot)
 local yard=plot:WaitForChild("ChamberYard")
 local sign=yard.ChamberUpgradeSign
 local chambers=Instance.new("Folder") chambers.Name="Chambers" chambers.Parent=plot
 local cooldown=0
 local function refresh()
  local count=#chambers:GetChildren()
  local owned=(plot:GetAttribute("OwnerUserId") or 0)~=0
  sign.SurfaceGui.Label.Text=count<3 and ("ADD CHAMBER\nFREE • "..count.." / 3") or "3 CHAMBERS\nFULLY UPGRADED"
  sign.ProximityPrompt.Enabled=owned and count<3
  sign.ClickDetector.MaxActivationDistance=owned and count<3 and 18 or 0
  plot:SetAttribute("ChamberCount",count)
 end
 local function spawnChamber(index,reveal)
  local h=template:Clone() h.Name="Chamber"..index
  h:SetAttribute("ClientEffectsReady",nil)
  h:SetAttribute("OwnerUserId",plot:GetAttribute("OwnerUserId"))
  h:PivotTo(plot.TempleAnchor.CFrame*CFrame.new(-44,.25,15-(index-1)*17)*CFrame.Angles(0,-math.pi/2,0))
  h.Parent=chambers
  if reveal then
   local glow=Instance.new("Highlight") glow.Adornee=h glow.DepthMode=Enum.HighlightDepthMode.Occluded glow.FillColor=Color3.fromRGB(213,246,167) glow.OutlineColor=Color3.fromRGB(255,231,174) glow.FillTransparency=.3 glow.Parent=h
   game.TweenService:Create(glow,TweenInfo.new(.9),{FillTransparency=1,OutlineTransparency=1}):Play()
   game.Debris:AddItem(glow,1)
  end
  refresh()
 end
 local function ownership()
  chambers:ClearAllChildren()
  if (plot:GetAttribute("OwnerUserId") or 0)~=0 then spawnChamber(1,false) end
  refresh()
 end
 local function upgrade(player)
  if typeof(player)~="Instance" or not player:IsA("Player") or player.Parent~=Players or player.UserId~=plot:GetAttribute("OwnerUserId") then return end
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if not root or (root.Position-sign.Position).Magnitude>20 or os.clock()<cooldown or #chambers:GetChildren()>=3 then return end
  cooldown=os.clock()+1
  spawnChamber(#chambers:GetChildren()+1,true)
 end
 sign.ProximityPrompt.Triggered:Connect(upgrade)
 sign.ClickDetector.MouseClick:Connect(upgrade)
 local request=Instance.new("BindableEvent") request.Name="RequestChamberUpgrade" request.Parent=plot request.Event:Connect(upgrade)
 plot:GetAttributeChangedSignal("OwnerUserId"):Connect(ownership)
 ownership()
end
for _,p in plots:GetChildren() do task.spawn(setup,p) end
plots.ChildAdded:Connect(function(p) task.spawn(setup,p) end)
