
-- Owner Panel v3 adapter. Existing OwnerControlServer validates and executes gameplay.
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local OWNER_IDS={[168774222]=true}
local folder=RS:FindFirstChild("OwnerPanel") or Instance.new("Folder");folder.Name="OwnerPanel";folder.Parent=RS
local remote=folder:FindFirstChild("Action") or Instance.new("RemoteFunction");remote.Name="Action";remote.Parent=folder
local bridge=game.ServerScriptService:WaitForChild("OwnerControlServer"):WaitForChild("Dispatch")
local last,busy={},{}
local mapping={GiveCash="GiveCash",SetCash="SetCash",GiveEgg="SpawnEgg",GiveCharacter="SpawnCharacter",SpawnEgg="SpawnRiverEgg",UpgradeTemple="UpgradeTemple",UnlockSlot="UnlockNextSlot",AddIncubator="AddChamber",UpgradeIncubator="UpgradeChamber",ClearInventory="ClearInventory",ClearPlaced="ClearPlaced",ResetSlots="ResetSlots",StartEvent="StartEvent",StopEvent="StopEvent",SetSpawnInterval="SetSpawnInterval",SendHome="GoHome",Bring="Bring",GoTo="TeleportTo",SendToPlayer="SendToPlayer",Respawn="Respawn",Kick="Kick",Ban="Ban24h",Unban="Unban"}
local dangerous={SetCash=true,ClearInventory=true,ClearPlaced=true,ResetSlots=true,Respawn=true,Kick=true,Ban=true,Unban=true}
local single={SetCash=true,UpgradeTemple=true,UnlockSlot=true,AddIncubator=true,UpgradeIncubator=true,ClearInventory=true,ClearPlaced=true,ResetSlots=true,SendHome=true,Bring=true,GoTo=true,SendToPlayer=true,Respawn=true,Kick=true,Ban=true,Unban=true}
local function plotOf(p)
 for _,plot in workspace.Plots:GetChildren() do if plot:GetAttribute("OwnerUserId")==p.UserId then
  local slots=0;for _,s in plot.Slots:GetChildren() do if s:GetAttribute("Unlocked") then slots+=1 end end
  local chambers={};for i=1,3 do local c=plot.Chambers:FindFirstChild("Chamber"..i);if c then chambers[i]=c:GetAttribute("UpgradeLevel") or 1 end end
  return {level=plot:GetAttribute("TempleLevel") or 1,slots=slots,incubators=chambers,building=plot:GetAttribute("TempleBuilding")==true}
 end end
end
remote.OnServerInvoke=function(p,action,a)
 if not OWNER_IDS[p.UserId] then return false,"Owner access only." end
 if type(action)~="string" or type(a)~="table" then return false,"Invalid request." end
 if busy[p] or os.clock()-(last[p] or -100)<.2 then return false,"Please wait a moment." end
 last[p]=os.clock();busy[p]=true
 local ok,res,msg=pcall(function()
  if action=="Snapshot" then
   local info=bridge:Invoke(p,"Info",{});if not info.Ok then return false,info.Message end
   local catalog={};for _,it in info.Items do table.insert(catalog,{id=it.Id,name=it.Name,rarity=it.Rarity,kind=it.EggAvailable and "egg" or (it.CharacterAvailable and "char" or "reserved"),eggAvailable=it.EggAvailable,charAvailable=it.CharacterAvailable,noRiver=it.NoRiver==true,price=it.Price}) end
   local roster={};for _,who in Players:GetPlayers() do table.insert(roster,{userId=who.UserId,name=who.DisplayName,user=who.Name,plot=plotOf(who)}) end
   return true,{players=roster,catalog=catalog,event=info.Event}
  end
  local mapped=mapping[action];if not mapped then return false,"Unknown action." end
  if dangerous[action] and a.confirmed~=true then return false,"Confirm this action first." end
  if a.scope=="lobby" and action~="StartEvent" and action~="StopEvent" and action~="SetSpawnInterval" and action~="SpawnEgg" and (single[action] or a.confirmed~=true) then return false,"Choose one player or confirm gifting to the lobby." end
  local target
  if action=="SpawnEgg" or action=="StartEvent" or action=="StopEvent" or action=="SetSpawnInterval" then target=tostring(p.UserId)
  elseif action=="Unban" then target=tostring(a.userId or "")
  elseif a.scope=="me" then target=tostring(p.UserId)
  elseif a.scope=="lobby" then target="ALL"
  else local who=Players:GetPlayerByUserId(tonumber(a.userId) or 0);if not who then return false,"Select an online player first." end;target=tostring(who.UserId) end
  local payload={Target=target,Confirmed=a.confirmed==true,Amount=a.amount,Id=a.itemId,Index=a.index,Destination=tostring(a.destination or ""),Kind=({rush="EggRush",cash="DoubleCash",gold="GoldenHour"})[a.eventId],Duration=a.seconds}
  if action=="SetSpawnInterval" then payload.Amount=a.seconds end
  local result=bridge:Invoke(p,mapped,payload)
  return result.Ok,result.Message
 end)
 busy[p]=nil
 if not ok then warn("[OwnerPanel v3]",action,res);return false,"Action failed: "..tostring(res):gsub("^.-:%d+: ","") end
 return res,msg
end
Players.PlayerRemoving:Connect(function(p)last[p]=nil;busy[p]=nil end)
