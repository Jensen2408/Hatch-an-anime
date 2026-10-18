-- Owner / Admin panel server. Every request is checked here against AdminRoles.
-- Owner: everything. Admin: events, river spawns, announcements, teleports, respawn, kick (not staff).
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local TextService=game:GetService("TextService")

local folder=RS:FindFirstChild("OwnerPanel") or Instance.new("Folder");folder.Name="OwnerPanel";folder.Parent=RS
local remote=folder:FindFirstChild("Action") or Instance.new("RemoteFunction");remote.Name="Action";remote.Parent=folder
local announce=folder:FindFirstChild("Announcement") or Instance.new("RemoteEvent");announce.Name="Announcement";announce.Parent=folder
local openEvent=RS:FindFirstChild("OwnerPanelOpen") or Instance.new("RemoteEvent");openEvent.Name="OwnerPanelOpen";openEvent.Parent=RS

local Roles=require(script.Parent:WaitForChild("AdminRoles"))
local StaffService=require(script.Parent:WaitForChild("StaffServerService"))
local CrossServerService=require(script.Parent:WaitForChild("CrossServerService"))
local Catalog=require(RS:WaitForChild("CharacterCatalog"))
local bridge=game.ServerScriptService:WaitForChild("OwnerControlServer"):WaitForChild("Dispatch")
local last,busy={},{}
local mapping={GiveCash="GiveCash",SetCash="SetCash",GiveEgg="SpawnEgg",GiveCharacter="SpawnCharacter",SpawnEgg="SpawnRiverEgg",UpgradeTemple="UpgradeTemple",UnlockSlot="UnlockNextSlot",AddIncubator="AddChamber",UpgradeIncubator="UpgradeChamber",ClearInventory="ClearInventory",ClearPlaced="ClearPlaced",ResetSlots="ResetSlots",StartEvent="StartEvent",StopEvent="StopEvent",SetSpawnInterval="SetSpawnInterval",SendHome="GoHome",Bring="Bring",GoTo="TeleportTo",SendToPlayer="SendToPlayer",Respawn="Respawn",Kick="Kick",Ban="Ban24h",Unban="Unban"}
local dangerous={SetCash=true,ClearInventory=true,ClearPlaced=true,ResetSlots=true,Respawn=true,Kick=true,Ban=true,Unban=true}
local single={SetCash=true,UpgradeTemple=true,UnlockSlot=true,AddIncubator=true,UpgradeIncubator=true,ClearInventory=true,ClearPlaced=true,ResetSlots=true,SendHome=true,Bring=true,GoTo=true,SendToPlayer=true,Respawn=true,Kick=true,Ban=true,Unban=true}
local lastShower,lastAnnounce=-1e9,{}
local function plotOf(p)
 for _,plot in workspace.Plots:GetChildren() do if plot:GetAttribute("OwnerUserId")==p.UserId then
  local slots=0;for _,s in plot.Slots:GetChildren() do if s:GetAttribute("Unlocked") then slots+=1 end end
  local chambers={};for i=1,3 do local c=plot.Chambers:FindFirstChild("Chamber"..i);if c then chambers[i]=c:GetAttribute("UpgradeLevel") or 1 end end
  return {level=plot:GetAttribute("TempleLevel") or 1,slots=slots,incubators=chambers,building=plot:GetAttribute("TempleBuilding")==true}
 end end
end
local function releasableEggs()
 local t={} for _,e in ipairs(Catalog.Order) do local tpl=game.ServerStorage.AuxEggTemplates:FindFirstChild(e.Id) if tpl and tpl:GetAttribute("ReleaseEnabled")~=false then table.insert(t,e) end end return t
end
local handlers={}
local SaveRestore=require(script.Parent:WaitForChild("SaveRestore"))
handlers.SaveList=function(p,a,role) if role~="Owner" then return false,"Only the owner can do that." end return true,SaveRestore.List(a.who) end
handlers.SaveRestore=function(p,a,role) if role~="Owner" then return false,"Only the owner can do that." end if a.confirmed~=true then return false,"Confirm first." end return true,SaveRestore.Restore(a.who,a.version) end
handlers.Snapshot=function(p,a,role)
 local info=bridge:Invoke(p,"Info",{});if not info.Ok then return false,info.Message end
 local catalog={};for _,it in info.Items do
  local entry={id=it.Id,name=it.Name,rarity=it.Rarity,eggAvailable=it.EggAvailable,charAvailable=it.CharacterAvailable,noRiver=it.NoRiver==true,price=it.Price}
  if role=="Owner" or (it.EggAvailable and not it.NoRiver) then table.insert(catalog,entry) end
 end
 local roster={};for _,who in Players:GetPlayers() do table.insert(roster,{userId=who.UserId,name=who.DisplayName,user=who.Name,role=Roles.Role(who),plot=plotOf(who)}) end
 return true,{players=roster,catalog=catalog,event=info.Event,role=role,admins=role=="Owner" and Roles.List() or nil,eventEnds=workspace:GetAttribute("OwnerEventEnds"),isStaffServer=workspace:GetAttribute("IsStaffServer")==true}
end
handlers.EggShower=function(p,a)
 assert(os.clock()-lastShower>20,"Egg Shower is cooling down. Try again in a few seconds.")
 local eggs=releasableEggs() assert(#eggs>0,"No eggs available.")
 local request=workspace.PirateEggConveyor:FindFirstChild("RequestOwnerRiverEgg") assert(request,"River is not ready.")
 local n=math.clamp(math.floor(tonumber(a.amount) or 8),3,15)
 lastShower=os.clock()
 task.spawn(function() for i=1,n do if not p.Parent then break end request:Fire(p,eggs[math.random(#eggs)].Id) task.wait(1.1) end end)
 announce:FireAllClients({title="EGG SHOWER!",text=n.." eggs are coming down the river!",color="green",by=p.DisplayName})
 return true,n.." eggs are coming down the river."
end
handlers.StartNight=function(p,a)
 local secs=math.clamp(math.floor(tonumber(a.seconds) or 20),10,600)
 workspace:SetAttribute("NightForcedUntil",workspace:GetServerTimeNow()+secs)
 announce:FireAllClients({title="NIGHTTIME!",text="Night has fallen — 3x cash, 2x hatch speed and 3x river luck! ("..secs.."s)",color="purple",by=p.DisplayName})
 return true,"Nighttime started for "..secs.." seconds."
end
handlers.StopNight=function(p,a)
 workspace:SetAttribute("NightForcedUntil",nil)
 return true,"Forced nighttime stopped (the regular 5-minute cycle still runs)."
end
handlers.Announce=function(p,a)
 local msg=type(a.text)=="string" and a.text:sub(1,120) or "" assert(#msg:gsub("%s","")>0,"Write a message first.")
 assert(os.clock()-(lastAnnounce[p] or -1e9)>8,"Wait a few seconds between announcements.")
 lastAnnounce[p]=os.clock()
 if a.allServers==true then
  return CrossServerService.GlobalAnnounce(p,msg,a.color or "purple")
 else
  local ok,filtered=pcall(function() return TextService:FilterStringAsync(msg,p.UserId,Enum.TextFilterContext.PublicChat):GetNonChatStringForBroadcastAsync() end)
  assert(ok,"Couldn't check that message. Try again.")
  announce:FireAllClients({title=(Roles.Role(p)=="Owner" and "OWNER" or "ADMIN").." ANNOUNCEMENT",text=filtered,color=a.color or "red",by=p.DisplayName})
  return true,"Announcement sent to everyone in this server."
 end
end
handlers.AnnounceUpdate=function(p,a)
 local msg=type(a.text)=="string" and a.text or nil
 return CrossServerService.AnnounceUpdate(p,msg)
end
handlers.SetAdmin=function(p,a)
 local id=tonumber(a.userId) assert(id,"Enter a numeric User ID.")
 local name=a.name local who=Players:GetPlayerByUserId(id)
 if who then name=who.Name end
 if not name then local ok,n=pcall(Players.GetNameFromUserIdAsync,Players,id) name=ok and n or tostring(id) end
 local saved=Roles.SetAdmin(id,name,a.on==true)
 return true,(a.on and "@"..name.." is now an admin" or "@"..name.." is no longer an admin")..(saved and "." or " (this server only; saving works in the published game).")
end
handlers.JoinStaffServer=function(p,a,role)
 return StaffService.TeleportToStaffServer(p)
end
handlers.ReturnToPublic=function(p,a,role)
 return StaffService.ReturnToPublic(p)
end
local function eventAnnouncement(p,a)
 local names={rush="EGG RUSH",cash="DOUBLE CASH",gold="GOLDEN HOUR"}
 local txt={rush="Eggs spawn twice as fast!",cash="All income is doubled!",gold="Golden sunset across the map!"}
 if names[a.eventId] then announce:FireAllClients({title=names[a.eventId].." STARTED!",text=txt[a.eventId].." ("..math.floor((tonumber(a.seconds) or 0)/60).." min)",color="gold",by=p.DisplayName}) end
end
remote.OnServerInvoke=function(p,action,a)
 local role=Roles.Role(p)
 if not role then return false,"Staff access only." end
 if type(action)~="string" or type(a)~="table" then return false,"Invalid request." end
 if not Roles.Can(p,action) and action~="SetAdmin" then return false,"Only the owner can do that." end
 if action=="SetAdmin" and role~="Owner" then return false,"Only the owner can do that." end
 if busy[p] or os.clock()-(last[p] or -100)<.2 then return false,"Please wait a moment." end
 last[p]=os.clock();busy[p]=true
 local ok,res,msg=pcall(function()
  if handlers[action] then return handlers[action](p,a,role) end
  local mapped=mapping[action];if not mapped then return false,"Unknown action." end
  if dangerous[action] and a.confirmed~=true then return false,"Confirm this action first." end
  if a.scope=="lobby" and role~="Owner" then return false,"Choose one player." end
  if a.scope=="lobby" and action~="StartEvent" and action~="StopEvent" and action~="SetSpawnInterval" and action~="SpawnEgg" and (single[action] or a.confirmed~=true) then return false,"Choose one player or confirm gifting to the lobby." end
  local target
  if action=="SpawnEgg" or action=="StartEvent" or action=="StopEvent" or action=="SetSpawnInterval" then target=tostring(p.UserId)
  elseif action=="Unban" then target=tostring(a.userId or "")
  elseif a.scope=="me" then target=tostring(p.UserId)
  elseif a.scope=="lobby" then target="ALL"
  else local who=Players:GetPlayerByUserId(tonumber(a.userId) or 0);if not who then return false,"Select an online player first." end;target=tostring(who.UserId) end
  if action=="Kick" then
   local who=Players:GetPlayerByUserId(tonumber(target) or 0) if not who then return false,"That player is not in this server." end
   if who==p then return false,"You can't kick yourself." end
   if Roles.Role(who) then return false,"Staff can't be kicked from the panel." end
   if role=="Admin" then who:Kick("You were kicked by an admin.") return true,"Kicked @"..who.Name.."." end
  end
  local payload={Target=target,Confirmed=a.confirmed==true,Amount=a.amount,Id=a.itemId,Index=a.index,Destination=tostring(a.destination or ""),Kind=({rush="EggRush",cash="DoubleCash",gold="GoldenHour"})[a.eventId],Duration=a.seconds}
  if action=="SetSpawnInterval" then payload.Amount=a.seconds end
  local result=bridge:Invoke(p,mapped,payload)
  if result.Ok and action=="StartEvent" then eventAnnouncement(p,a) end
  return result.Ok,result.Message
 end)
 busy[p]=nil
 if not ok then warn("[StaffPanel]",action,res);return false,(tostring(res):gsub("^.-:%d+: ","")) end
 return res,msg
end
Players.PlayerRemoving:Connect(function(p)last[p]=nil;busy[p]=nil;lastAnnounce[p]=nil end)
-- /admin opens the panel for any staff member (/owner still works for the owner)
local chat=game:GetService("TextChatService")
local command=chat:FindFirstChild("OpenStaffPanel") or Instance.new("TextChatCommand")
command.Name="OpenStaffPanel" command.PrimaryAlias="/admin" command.SecondaryAlias="" command.Parent=chat
command.Triggered:Connect(function(source) local who=source and Players:GetPlayerByUserId(source.UserId) if who and Roles.Role(who) then openEvent:FireClient(who) end end)
