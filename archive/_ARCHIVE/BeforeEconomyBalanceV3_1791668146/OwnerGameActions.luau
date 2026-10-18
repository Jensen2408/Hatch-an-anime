
local Players=game:GetService("Players")
local Slots=require(script.Parent.TempleSlotUnlocks)
local Actions={}
Actions.Handles={GiveCash=true,SetCash=true,UnlockSlots=true,UnlockNextSlot=true,ResetSlots=true,ClearPlaced=true,ClearInventory=true,Respawn=true,TeleportTo=true,Bring=true,SendToPlayer=true,GoHome=true,UpgradeTemple=true,AddChamber=true,UpgradeChamber=true,SetSpawnInterval=true}
local function getPlayer(owner,value)
 if type(value)=="string" then value=value:gsub("^%s+",""):gsub("%s+$",""):gsub("^@","") end
 if value==nil or value=="" or value:upper()=="ME" then return owner end
 assert(type(value)=="string" and #value<=50,"Enter an exact username or User ID.")
 for _,p in ipairs(Players:GetPlayers()) do if tostring(p.UserId)==value or p.Name:lower()==value:lower() then return p end end
 local matches={} for _,p in ipairs(Players:GetPlayers()) do if p.DisplayName:lower()==value:lower() then table.insert(matches,p) end end
 if #matches==1 then return matches[1] end
 if #matches>1 then error("Multiple players share that display name. Use their @username or User ID.") end
 error("That player is not in this server.")
end
local function plotOf(player)
 for _,plot in ipairs(workspace.Plots:GetChildren()) do if plot:GetAttribute("OwnerUserId")==player.UserId then return plot end end
 error("That player has no plot.")
end
local function root(player) local c=player.Character local r=c and c:FindFirstChild("HumanoidRootPart") assert(r,"Character is not ready.") return r end
function Actions.Run(owner,action,payload)
 assert(owner.UserId==168774222,"Owner access only.")
 if type(payload.Target)=="string" then local normalized=payload.Target:upper():gsub("%s","") if normalized=="LOBBY" or normalized=="ALL" then payload.Target="ALL" end end
 if action=="SetSpawnInterval" then
  local n=tonumber(payload.Amount) assert(n and n==n and n>=1.5 and n<=30,"Spawn interval must be 1.5–30 seconds.")
  assert(not workspace:GetAttribute("OwnerEventName"),"Stop the active event before changing spawn timing.")
  workspace.PirateEggConveyor:SetAttribute("SpawnInterval",n)
  return {Ok=true,Message="River spawn interval: "..n.." seconds."}
 end
 if action=="GiveCash" or action=="SetCash" then
  local amount=tonumber(payload.Amount) assert(amount and amount==amount and amount>=0 and amount<=1000000000000,"Enter an amount from 0 to 1 trillion.")
  if action=="SetCash" then assert(payload.Confirmed,"Confirm replacing the player's cash.") end
  local recipients=payload.Target=="ALL" and Players:GetPlayers() or {getPlayer(owner,payload.Target)}
  if payload.Target=="ALL" then assert(payload.Confirmed,"Confirm giving money to everyone.") assert(action=="GiveCash","Set cash supports one player at a time.") end
  local changed=0
  for _,p in ipairs(recipients) do
   local cash=p:FindFirstChild("leaderstats") and p.leaderstats:FindFirstChild("Cash")
   if cash then cash.Value=action=="GiveCash" and math.min(cash.Value+math.floor(amount),1000000000000000) or math.floor(amount) changed+=1 end
  end
  assert(changed>0,"Player cash is not ready.")
  return {Ok=true,Message=(action=="GiveCash" and "Added $" or "Set cash to $")..math.floor(amount).." for "..changed.." player(s)."}
 end
 local p=getPlayer(owner,payload.Target)
 if action=="ClearInventory" then
  assert(payload.Confirmed,"Confirm clearing inventory.")
  for _,container in ipairs({p:FindFirstChildOfClass("Backpack"),p.Character}) do if container then for _,t in ipairs(container:GetChildren()) do if t:IsA("Tool") then t:Destroy() end end end end
 elseif action=="Respawn" then assert(payload.Confirmed,"Confirm respawning this player.") p:LoadCharacterAsync()
 elseif action=="TeleportTo" then root(owner) owner.Character:PivotTo(root(p).CFrame*CFrame.new(4,0,0))
 elseif action=="Bring" then root(p) p.Character:PivotTo(root(owner).CFrame*CFrame.new(4,0,0))
 elseif action=="SendToPlayer" then
  assert(type(payload.Destination)=="string" and payload.Destination~="ALL","Choose an online destination player.")
  local destination=getPlayer(owner,payload.Destination)
  assert(destination~=p,"Choose a different destination player.")
  local sourceRoot=root(p);local destinationRoot=root(destination)
  local sourceHum=p.Character:FindFirstChildOfClass("Humanoid")
  local destinationHum=destination.Character:FindFirstChildOfClass("Humanoid")
  assert(sourceHum and sourceHum.Health>0 and destinationHum and destinationHum.Health>0,"Both characters must be alive.")
  p.Character:PivotTo(destinationRoot.CFrame*CFrame.new(4.5,0,0))
  sourceRoot.AssemblyLinearVelocity=Vector3.zero;sourceRoot.AssemblyAngularVelocity=Vector3.zero
  return {Ok=true,Message="Teleported @"..p.Name.." to @"..destination.Name.."."}
 elseif action=="GoHome" then root(p) p.Character:PivotTo(plotOf(p).PlotSpawn.CFrame*CFrame.new(0,4,0))
 else
  local plot=plotOf(p)
  if action=="UnlockNextSlot" then
   local ordered=plot.Slots:GetChildren();table.sort(ordered,function(a,b) return a.Name<b.Name end)
   for _,slot in ipairs(ordered) do if not slot:GetAttribute("Unlocked") then slot:SetAttribute("Unlocked",true);Slots.Refresh(plot);return {Ok=true,Message=slot.Name.." unlocked for @"..p.Name.."."} end end
   error("All character slots are already unlocked.")
  elseif action=="UnlockSlots" then for _,slot in ipairs(plot.Slots:GetChildren()) do slot:SetAttribute("Unlocked",true) end Slots.Refresh(plot)
  elseif action=="ResetSlots" then
   assert(payload.Confirmed,"Confirm resetting slot unlocks.")
   for _,slot in ipairs(plot.Slots:GetChildren()) do assert(not slot:GetAttribute("Occupied"),"Clear placed characters before resetting slots.") end
   Slots.Reset(plot)
  elseif action=="ClearPlaced" then
   assert(payload.Confirmed,"Confirm clearing placed characters.")
   plot.PlacedItems:ClearAllChildren()
   for _,slot in ipairs(plot.Slots:GetChildren()) do slot:SetAttribute("Occupied",false) slot:SetAttribute("PlacementToken",nil) end Slots.Refresh(plot)
  elseif action=="UpgradeTemple" then
   assert(not plot:GetAttribute("TempleBuilding"),"Temple is already upgrading.")
   assert((plot:GetAttribute("TempleLevel") or 1)<3,"Temple is already level 3.")
   plot.RequestUpgrade:Fire(p,owner)
  elseif action=="AddChamber" then
   assert((plot:GetAttribute("ChamberCount") or 0)<3,"The plot already has 3 incubators.")
   assert(not plot:GetAttribute("ChamberBuilding"),"An incubator is already upgrading.")
   plot.RequestChamberUpgrade:Fire(p,owner)
  elseif action=="UpgradeChamber" then
   local i=tonumber(payload.Index) assert(i and i%1==0 and i>=1 and i<=3,"Choose incubator 1, 2, or 3.")
   local chamber=plot.Chambers:FindFirstChild("Chamber"..i) assert(chamber,"That incubator has not been built.")
   assert((chamber:GetAttribute("UpgradeLevel") or 1)<3,"Incubator is already level 3.")
   assert(not plot:GetAttribute("ChamberBuilding") and not chamber:GetAttribute("UnderConstruction") and (chamber:GetAttribute("Status") or "Ready")=="Ready","Incubator is busy; wait until the egg is collected.")
   chamber.RequestIncubatorUpgrade:Fire(p,owner)
  end
 end
 return {Ok=true,Message=action.." applied to @"..p.Name.."."}
end
Actions.GetPlayer=getPlayer
return Actions
