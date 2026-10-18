
-- Game Menu adapters: use existing server inventory/economy, never client stats.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("ServerStorage")
local SSS=game:GetService("ServerScriptService")
local Http=game:GetService("HttpService")
local Catalog=require(RS.CharacterCatalog)
local Inventory=require(SSS.CharacterInventory.InventoryService)
local Rewards=require(SSS.EggCharacterRewards)
local Quests=require(script.Parent.QuestService)
local Adapter={}
local discoveries={}
local function plotOf(p) for _,plot in workspace.Plots:GetChildren() do if plot:GetAttribute("OwnerUserId")==p.UserId then return plot end end end
local function remember(p,key)
 discoveries[p]=discoveries[p] or {}
 if not discoveries[p][key] then discoveries[p][key]=true;return true end
 return false
end
function Adapter.GetCatalog()
 local out={eggs={},characters={}}
 for _,e in Catalog.Order do
  table.insert(out.characters,{id="char:"..e.Id,name=e.Name,rarity=e.Rarity,image=e.image,description="Each hatch rolls individual Power and earnings.",obtain="Hatch a "..e.Id.." egg in your incubator."})
  local model=SS.AuxEggTemplates:FindFirstChild(e.Id)
  if model and model:GetAttribute("ReleaseEnabled")~=false then
   table.insert(out.eggs,{id="egg:"..e.Id,name=e.Id.." Egg",rarity=e.Rarity,model="MenuEgg_"..e.Id,description="Price: "..Catalog.FormatPrice(e.Price),obtain="Collect from the river and return to your plot."})
  end
 end
 return out
end
function Adapter.GetPlot(p)
 local snap=Inventory.Snapshot(p)
 local plot=plotOf(p)
 local items={}
 for _,it in snap.items do
  local entry=Catalog.ById[it.characterId]
  table.insert(items,{uid=it.id,id="char:"..it.characterId,name=it.name,rarity=it.rarity,power=it.power,income=it.income*snap.multiplier,state=({Placed="placed",Held="held",Backpack="stored"})[it.state],acquired=it.acquired,image=entry.image})
 end
 return {plotOwned=plot~=nil,level=plot and plot:GetAttribute("TempleLevel") or 0,unlocked=snap.capacity.unlocked,items=items}
end
function Adapter.GetOwnedEggs(p)
 local out={}
 for _,container in {p:FindFirstChildOfClass("Backpack"),p.Character} do if container then for _,tool in container:GetChildren() do local id=tool:GetAttribute("EggType");if tool:IsA("Tool") and id and Catalog.ById[id] then local key="egg:"..id;out[key]=(out[key] or 0)+1 end end end end
 return out
end
function Adapter.GetDiscovered(p)
 discoveries[p]=discoveries[p] or {}
 for _,it in Inventory.Snapshot(p).items do remember(p,"char:"..it.characterId) end
 for _,container in {p:FindFirstChildOfClass("Backpack"),p.Character} do if container then for _,tool in container:GetChildren() do local id=tool:GetAttribute("EggType");if tool:IsA("Tool") and id and Catalog.ById[id] then remember(p,"egg:"..id) end end end end
 return table.clone(discoveries[p])
end
local function batch(p,uids,action)
 if type(uids)~="table" or #uids>60 then return nil,"Invalid selection." end
 local done,seen=0,{}
 for _,uid in ipairs(uids) do
  if type(uid)~="string" or seen[uid] then return nil,"Invalid selection." end
  seen[uid]=true
 end
 for _,uid in ipairs(uids) do
  local result=Inventory.MenuRequest(p,action,{id=uid})
  if not result.ok then return done>0 and done or nil,result.message or result.code end
  done+=1
  if #uids>1 then task.wait(.27) end
 end
 return done
end
function Adapter.PlaceCharacters(p,uids) return batch(p,uids,"Place") end
function Adapter.StoreCharacters(p,uids) return batch(p,uids,"Store") end
function Adapter.EquipBest(p)
 local r=Inventory.MenuRequest(p,"PlaceBest",{})
 return r.ok,r.message or (r.ok and "Best earners placed." or r.code)
end
function Adapter.GetCash(p) local s=p:FindFirstChild("leaderstats");local cash=s and s:FindFirstChild("Cash");return cash and cash.Value or 0 end
function Adapter.SpendCash(p,n)
 local s=p:FindFirstChild("leaderstats");local cash=s and s:FindFirstChild("Cash")
 if not cash or type(n)~="number" or n~=n or n<0 or n%1~=0 then return nil,"Invalid price." end
 if cash.Value<n then return nil,"Not enough cash." end
 cash.Value-=n
 return true
end
function Adapter.GrantReward(p,reward)
 local s=p:FindFirstChild("leaderstats");local cash=s and s:FindFirstChild("Cash")
 local n=reward and reward.cash
 if not cash or type(n)~="number" or n<0 or n~=n then return nil,"Cash is unavailable." end
 cash.Value+=math.floor(n)
 return true
end
local function createEgg(p,id)
 local e=Catalog.ById[id]
 local template=e and SS.AuxEggTemplates:FindFirstChild(id)
 local bag=p:FindFirstChildOfClass("Backpack")
 if not bag or not template or template:GetAttribute("ReleaseEnabled")==false then return nil,"Egg is unavailable." end
 local tool=Instance.new("Tool");tool.Name=id.." Egg";tool.CanBeDropped=false;Catalog.Stamp(tool,e)
 tool:SetAttribute("EggType",id);tool:SetAttribute("EggId",Http:GenerateGUID(false));tool:SetAttribute("ShopPurchased",true)
 local visual=template:Clone();visual.Name="Egg";visual:ScaleTo(template:GetScale()*.5);visual:PivotTo(CFrame.new());visual.Parent=tool
 local handle=Instance.new("Part");handle.Name="Handle";handle.Size=Vector3.one;handle.Transparency=1;handle.CanCollide=false;handle.Massless=true;handle.Parent=tool
 for _,part in visual:GetDescendants() do if part:IsA("BasePart") then part.Anchored=false;part.CanCollide=false;part.CanTouch=false;part.Massless=true;local weld=Instance.new("WeldConstraint");weld.Part0=handle;weld.Part1=part;weld.Parent=handle elseif part:IsA("BaseScript") then part:Destroy() end end
 return tool,bag
end
function Adapter.BuyCash(p,shop)
 local id=shop.grant and shop.grant.egg
 local tool,bag=createEgg(p,id)
 if not tool then return false,bag end
 local ok,why=Adapter.SpendCash(p,shop.price)
 if not ok then tool:Destroy();return false,why end
 -- No yield between payment and delivery; refund if delivery unexpectedly fails.
 local delivered,err=pcall(function()tool.Parent=bag end)
 if not delivered then Adapter.GrantReward(p,{cash=shop.price});tool:Destroy();return false,"Purchase refunded." end
 return true,"Bought "..shop.name
end
function Adapter.GrantShopItem(p,e)
 local tool,bag=createEgg(p,e.grant and e.grant.egg)
 if not tool then return nil,bag end
 tool.Parent=bag;return true
end
function Adapter.Init(push)
 local watched=setmetatable({},{__mode="k"})
 local function watchPlayer(p)
  discoveries[p]={}
  local function container(c)
   if not c then return end
   c.ChildAdded:Connect(function(tool)
    if not tool:IsA("Tool") then return end
    task.defer(function()
     local charId=tool:GetAttribute("CharacterId")
     local eggId=tool:GetAttribute("EggType")
     if charId and Catalog.ById[charId] then remember(p,"char:"..charId) end
     if eggId and Catalog.ById[eggId] then remember(p,"egg:"..eggId) end
     push(p)
    end)
   end)
  end
  container(p:FindFirstChildOfClass("Backpack"));container(p.Character)
  p.CharacterAdded:Connect(container)
  p.ChildAdded:Connect(function(c)if c:IsA("Backpack") then container(c) end end)
 end
 for _,p in Players:GetPlayers() do watchPlayer(p) end
 Players.PlayerAdded:Connect(watchPlayer)
 Players.PlayerRemoving:Connect(function(p)discoveries[p]=nil end)
 local function hookHatch(event)
  if event.Name~="HatchCycleCompleted" or not event:IsA("BindableEvent") or watched[event] then return end
  watched[event]=true
  event.Event:Connect(function(p,tool,id)
   local plot=plotOf(p)
   if not plot or not event:IsDescendantOf(plot) then return end
   Quests.Increment(p,"HatchEgg",1)
   if id and Catalog.ById[id] then
    local marker="hatch:"..id
    if remember(p,marker) then Quests.Increment(p,"DiscoverCharacter",1) end
    remember(p,"char:"..id)
   end
   push(p)
  end)
 end
 for _,d in workspace.Plots:GetDescendants() do hookHatch(d) end
 workspace.Plots.DescendantAdded:Connect(hookHatch)
 local function owner(plot)return Players:GetPlayerByUserId(plot:GetAttribute("OwnerUserId") or 0) end
 local function watchPlot(plot)
  local placed=plot:WaitForChild("PlacedItems",30)
  local slots=plot:WaitForChild("Slots",30)
  local chambers=plot:WaitForChild("Chambers",30)
  if not placed or not slots or not chambers then warn("[GameMenu] plot folders not ready: "..plot.Name);return end
  local prev=plot:GetAttribute("TempleLevel") or 1
  plot:GetAttributeChangedSignal("TempleLevel"):Connect(function()
   local n=plot:GetAttribute("TempleLevel") or 1;local p=owner(plot)
   if p and n>prev then Quests.Increment(p,"Upgrade",1) end;prev=n;if p then push(p) end
  end)
  placed.ChildAdded:Connect(function(model)
   task.defer(function() local p=owner(plot);if p and model.Parent and model:GetAttribute("CharacterId") then Quests.Increment(p,"PlaceCharacter",1);push(p) end end)
  end)
  for _,slot in slots:GetChildren() do slot:GetAttributeChangedSignal("Unlocked"):Connect(function()local p=owner(plot);if p then push(p) end end) end
  local function watchChamber(c)
   local level=c:GetAttribute("UpgradeLevel") or 1
   c:GetAttributeChangedSignal("UpgradeLevel"):Connect(function()
    local n=c:GetAttribute("UpgradeLevel") or 1;local p=owner(plot);if p and n>level then Quests.Increment(p,"Upgrade",1) end;level=n;if p then push(p) end
   end)
  end
  for _,c in chambers:GetChildren() do watchChamber(c) end
  chambers.ChildAdded:Connect(watchChamber)
 end
 for _,plot in workspace.Plots:GetChildren() do task.spawn(watchPlot,plot) end
 workspace.Plots.ChildAdded:Connect(function(plot)task.spawn(watchPlot,plot) end)
end
return Adapter
