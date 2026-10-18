local Players=game:GetService("Players")
local remote=game.ReplicatedStorage.TempleAppearanceRequest
local themes=require(game.ReplicatedStorage.TempleAppearanceThemes)
local FX=require(script.Parent.UpgradeEffects)
local occupancy=require(script.Parent.TempleOccupancy)
local plots=workspace.Plots
local allowed={} for _,t in ipairs(themes) do allowed[t.Id]=true end
local function find(player)
 for _,plot in ipairs(plots:GetChildren()) do if plot:GetAttribute("OwnerUserId")==player.UserId then return plot end end
end
local function apply(player,action,id)
 local plot=find(player) local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not plot or not root or (root.Position-plot.AppearanceSign.Position).Magnitude>22 or plot:GetAttribute("TempleBuilding") or plot:GetAttribute("AppearanceBuilding") then return end
 if action=="Open" then remote:FireClient(player,"Open",plot:GetAttribute("TempleAppearance") or "Original") return end
 if action~="Apply" or not allowed[id] or id==(plot:GetAttribute("TempleAppearance") or "Original") then return end
 plot:SetAttribute("AppearanceBuilding",true)
 local prompt=plot.OwnerSign.UpgradePrompt local click=plot.OwnerSign.ClickDetector
 prompt.Enabled=false click.MaxActivationDistance=0
 remote:FireClient(player,"Building",id)
 local owner=player.UserId local level=plot:GetAttribute("TempleLevel") or 1
 local template=game.ServerStorage.TempleUpgradeTemplates["Level"..level]
 local old=plot.Temple local _,size=template:GetBoundingBox()
 local function valid() return plot.Parent and plot:GetAttribute("OwnerUserId")==owner end
 local function swap(prepare)
  if not valid() then return end
  for _,visitor in ipairs(Players:GetPlayers()) do local c=visitor.Character local r=c and c:FindFirstChild("HumanoidRootPart")
   if r then local pos=plot.TempleAnchor.CFrame:PointToObjectSpace(r.Position)
    if math.abs(pos.X)<40 and math.abs(pos.Z)<35 and pos.Y>-2 and pos.Y<100 then c:PivotTo(plot.PlotSpawn.CFrame*CFrame.new(0,4,0)) end
   end
  end
  local clone=template:Clone() clone.Name="Temple" clone:PivotTo(plot.TempleAnchor.CFrame)
  themes.Apply(clone,id) clone:SetAttribute("OwnerUserId",owner)
  if prepare then prepare(clone) end
  clone.Parent=plot if old.Parent then old:Destroy() end
  plot:SetAttribute("TempleAppearance",id)
  return clone
 end
 local ok,err=pcall(function() FX.Play({anchor=plot.TempleAnchor.CFrame,radius=math.max(size.X,size.Z)*.5,height=size.Y,oldModel=old,ghostSource=template,ownerUserId=owner,palette=FX.Palettes.Temple,isValid=valid,swap=swap}) end)
 if not ok and valid() then warn(err);pcall(swap) end
 plot:SetAttribute("AppearanceBuilding",nil)
 if valid() then
  occupancy.Apply(plot,true)
  prompt.Enabled=level<3 click.MaxActivationDistance=level<3 and 18 or 0
  remote:FireClient(player,"Done",id)
 end
end
remote.OnServerEvent:Connect(apply)
local function setup(plot)
 plot.AppearanceSign.AppearancePrompt.Triggered:Connect(function(player)apply(player,"Open")end)
 plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
  plot:SetAttribute("TempleAppearance","Original") plot:SetAttribute("AppearanceBuilding",nil)
 end)
end
for _,plot in ipairs(plots:GetChildren()) do setup(plot) end
plots.ChildAdded:Connect(setup)
