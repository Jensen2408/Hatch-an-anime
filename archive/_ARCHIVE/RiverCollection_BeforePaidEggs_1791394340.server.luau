local RunService=game:GetService("RunService")
local Catalog=require(game.ReplicatedStorage.CharacterCatalog)
local m=workspace:WaitForChild("PirateEggConveyor")
local templates={}
for _,template in ipairs(game.ServerStorage:WaitForChild("AuxEggTemplates"):GetChildren())do
 if template:GetAttribute("ReleaseEnabled")~=false then table.insert(templates,template)end
end
table.sort(templates,function(a,b) return a:GetAttribute("Order")<b:GetAttribute("Order") end)
local folder=workspace:WaitForChild("WaterfallEggs")
local motion=require(m:WaitForChild("RollingMotion"))
local active={}
local serial=0
local random=Random.new()
local chooseTemplate=Catalog.BuildSpawnPool(templates)
local function spawnEgg(forcedTemplate)
 serial+=1
 local template=forcedTemplate or chooseTemplate(random)
 local egg=template:Clone();egg.Name="RiverEgg_"..serial
 egg:SetAttribute("Sequence",serial)
 egg:PivotTo(CFrame.new(m:GetAttribute("FallStart")))
 for _,name in {"LabelAnchor","CollectAnchor"} do
  local p=m[name]:Clone();p.CFrame=egg:GetPivot();p.Parent=egg
 end
 local label=egg.LabelAnchor
 for _,gui in label:GetChildren() do if gui:IsA("BillboardGui") then gui:Destroy() end end
 local entry=Catalog.ById[template.Name]
 if entry then Catalog.Stamp(egg,entry) end
 egg:SetAttribute("EggType",template.Name)
 local prompt=egg.CollectAnchor:FindFirstChildOfClass("ProximityPrompt")
 if prompt then prompt.ObjectText=template.Name.." Egg";prompt.ActionText="Collect • Free" end
 egg:SetAttribute("Epoch",workspace:GetServerTimeNow())
 egg.Parent=folder
 game:GetService("CollectionService"):AddTag(egg,"RiverEgg")
 local update,pose=motion(m,egg)
 local _,_,_,duration=pose(0)
 
 local prompt=egg.CollectAnchor:FindFirstChildOfClass("ProximityPrompt")
 local collected=false
 local function collectEgg(player)
  if collected or not egg.Parent then return end
  local cf,phase=pose(workspace:GetServerTimeNow()-egg:GetAttribute("Epoch"))
  if phase~="travel" then return end
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  local bag=player:FindFirstChildOfClass("Backpack")
  if not root or not bag or (root.Position-cf.Position).Magnitude>17 then return end
  collected=true
  egg:SetAttribute("Collected",true)
  local tool=Instance.new("Tool");tool.Name=template.Name.." Egg";tool.ToolTip="FREE";tool:SetAttribute("EggType",template.Name);tool.CanBeDropped=false;tool:SetAttribute("Price",0)
  if entry then Catalog.Stamp(tool,entry) tool.ToolTip=entry.Rarity.." • "..Catalog.FormatPrice(entry.Price).." (Free playtest)" end
  local visual=template:Clone();visual.Name="Egg";visual:ScaleTo(template:GetScale()*.5);visual:PivotTo(CFrame.new());visual.Parent=tool
  local handle=Instance.new("Part");handle.Name="Handle";handle.Size=Vector3.one;handle.Transparency=1;handle.CanCollide=false;handle.Massless=true;handle.Parent=tool
  for _,p in visual:GetDescendants() do if p:IsA("BasePart") then
   p.Anchored=false;p.CanCollide=false;p.CanTouch=false;p.Massless=true
   local weld=Instance.new("WeldConstraint");weld.Part0=handle;weld.Part1=p;weld.Parent=handle
  end end
  tool.Parent=bag;active[egg]=nil;egg:Destroy()
 end
 active[egg]=collectEgg
 if prompt then prompt.Triggered:Connect(collectEgg) end
 task.delay(duration-.05,function() active[egg]=nil;if egg.Parent then egg:Destroy() end end)
end
game.ReplicatedStorage.CollectRiverEgg.OnServerEvent:Connect(function(player,egg)
 if typeof(egg)~="Instance" then return end
 local collect=active[egg]
 if collect then collect(player) end
end)
local ownerRequest=m:FindFirstChild("RequestOwnerRiverEgg") or Instance.new("BindableEvent")
ownerRequest.Name="RequestOwnerRiverEgg" ownerRequest.Parent=m
ownerRequest.Event:Connect(function(owner,id)
 if typeof(owner)~="Instance" or not owner:IsA("Player") or owner.UserId~=168774222 or owner.Parent~=game.Players then return end
 local entry=type(id)=="string" and Catalog.ById[id]
 local template=entry and game.ServerStorage.AuxEggTemplates:FindFirstChild(id)
 if template and template:GetAttribute("ReleaseEnabled")~=false then spawnEgg(template) end
end)
while true do spawnEgg();task.wait(m:GetAttribute("SpawnInterval") or 5) end
