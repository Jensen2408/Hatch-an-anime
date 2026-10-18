
local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Lighting=game:GetService("Lighting")
local RunService=game:GetService("RunService")
local OWNER=168774222
local Catalog=require(RS:WaitForChild("CharacterCatalog"))
local Rewards=require(script.Parent:WaitForChild("EggCharacterRewards"))
local GameActions=require(script.Parent:WaitForChild("OwnerGameActions"))
local remote=RS:WaitForChild("OwnerControl")
local last={} local busy={} local activeEvent=nil
local function target(raw)
 if type(raw)~="string" or #raw>50 then return nil end
 local id=tonumber(raw)
 if id then if id<1 or id%1~=0 then return nil end return id,Players:GetPlayerByUserId(id) end
 for _,p in ipairs(Players:GetPlayers()) do if p.Name:lower()==raw:lower() then return p.UserId,p end end
 local ok,result=pcall(Players.GetUserIdFromNameAsync,Players,raw)
 if ok then return result,Players:GetPlayerByUserId(result) end
end
local function stopEvent()
 if not activeEvent then return end
 local event=activeEvent activeEvent=nil
 if event.Kind=="EggRush" and event.Conveyor.Parent then event.Conveyor:SetAttribute("SpawnInterval",event.Before)
 elseif event.Kind=="DoubleCash" then workspace:SetAttribute("OwnerIncomeMultiplier",event.Before)
 elseif event.Kind=="GoldenHour" then Lighting.ClockTime=event.Before end
 workspace:SetAttribute("OwnerEventName",nil) workspace:SetAttribute("OwnerEventEnds",nil)
end
remote.OnServerInvoke=function(player,action,payload)
 if player.UserId~=OWNER then return {Ok=false,Message="Owner access only."} end
 if type(action)~="string" or (payload~=nil and type(payload)~="table") then return {Ok=false,Message="Invalid request."} end
 if busy[player] or os.clock()-(last[player] or -100)<.2 then return {Ok=false,Message="Please wait a moment."} end
 last[player]=os.clock() busy[player]=true payload=payload or {}
 if type(payload.Target)=="string" then local normalized=payload.Target:upper():gsub("%s","") if normalized=="ALL" or normalized=="LOBBY" then payload.Target="ALL" end end
 local ok,result=pcall(function()
  if GameActions.Handles[action] then return GameActions.Run(player,action,payload)
  elseif action=="Info" then
   local items={} for _,e in ipairs(Catalog.Order) do table.insert(items,{Id=e.Id,Name=e.Name,Rarity=e.Rarity,EggAvailable=game.ServerStorage.AuxEggTemplates:FindFirstChild(e.Id)~=nil}) end
   local roster={} for _,p in ipairs(Players:GetPlayers()) do table.insert(roster,{Id=p.UserId,Name=p.Name,Display=p.DisplayName}) end
   return {Ok=true,Items=items,Players=roster,Event=activeEvent and activeEvent.Kind or "None"}
  elseif action=="SpawnRiverEgg" then
   local entry=type(payload.Id)=="string" and Catalog.ById[payload.Id] assert(entry,"Choose an egg.")
   local template=game.ServerStorage.AuxEggTemplates:FindFirstChild(entry.Id) assert(template and template:GetAttribute("ReleaseEnabled")~=false,"Egg unavailable.")
   local request=workspace.PirateEggConveyor:FindFirstChild("RequestOwnerRiverEgg") assert(request,"River is not ready.")
   request:Fire(player,entry.Id)
   return {Ok=true,Message=entry.Id.." egg spawned at the waterfall."}
  elseif action=="SpawnEgg" or action=="SpawnCharacter" then
   local entry=type(payload.Id)=="string" and Catalog.ById[payload.Id] assert(entry,"Choose a released egg or character.")
   local recipients=payload.Target=="ALL" and Players:GetPlayers() or {GameActions.GetPlayer(player,payload.Target)}
   if payload.Target=="ALL" then assert(payload.Confirmed==true,"Confirm gifting to the whole lobby.") end
   for _,recipient in ipairs(recipients) do assert(recipient:FindFirstChildOfClass("Backpack"),"A player backpack is not ready. Try again.") end
   for _,recipient in ipairs(recipients) do
   local bag=recipient:FindFirstChildOfClass("Backpack") assert(bag,"Your backpack is not ready.")
   if action=="SpawnCharacter" then
    local template=game.ServerStorage.BrainrotModels:FindFirstChild(entry.Id) assert(template,"Character unavailable.")
    Rewards.Tool(template,entry.Id).Parent=bag
   else
    local template=game.ServerStorage.AuxEggTemplates:FindFirstChild(entry.Id)
    assert(template and template:GetAttribute("ReleaseEnabled")~=false,"Egg unavailable.")
    local tool=Instance.new("Tool") tool.Name=entry.Id.." Egg" tool.CanBeDropped=false Catalog.Stamp(tool,entry) tool:SetAttribute("EggType",entry.Id) tool:SetAttribute("OwnerSpawned",true)
    tool.ToolTip=entry.Rarity.." • Owner test egg"
    local visual=template:Clone() visual.Name="Egg" visual:ScaleTo(template:GetScale()*.5) visual:PivotTo(CFrame.new()) visual.Parent=tool
    local handle=Instance.new("Part") handle.Name="Handle" handle.Size=Vector3.one handle.Transparency=1 handle.CanCollide=false handle.Massless=true handle.Parent=tool
    for _,p in ipairs(visual:GetDescendants()) do if p:IsA("BasePart") then p.Anchored=false p.CanCollide=false p.CanTouch=false p.Massless=true local w=Instance.new("WeldConstraint") w.Part0=handle w.Part1=p w.Parent=handle elseif p:IsA("BaseScript") then p:Destroy() end end
    tool.Parent=bag
   end
   end
   return {Ok=true,Message=entry.Name.." given to "..#recipients.." player(s)."}
  elseif action=="GiveCash" then
   local amount=tonumber(payload.Amount) assert(amount and amount==amount and amount>0 and amount<=1000000000000,"Enter an amount from 1 to 1 trillion.")
   local cash=player:FindFirstChild("leaderstats") and player.leaderstats:FindFirstChild("Cash") assert(cash,"Cash is not ready.")
   cash.Value=math.min(cash.Value+math.floor(amount),1000000000000000)
   return {Ok=true,Message="Test cash added to your account."}
  elseif action=="StartEvent" then
   assert(payload.Kind=="EggRush" or payload.Kind=="DoubleCash" or payload.Kind=="GoldenHour","Unknown event.")
   local duration=tonumber(payload.Duration) or 120 assert(duration==duration and duration>=15 and duration<=300,"Duration must be 15–300 seconds.")
   stopEvent()
   local event={Kind=payload.Kind}
   if event.Kind=="EggRush" then event.Conveyor=workspace:FindFirstChild("PirateEggConveyor") assert(event.Conveyor,"River unavailable.") event.Before=event.Conveyor:GetAttribute("SpawnInterval") or 4 event.Conveyor:SetAttribute("SpawnInterval",math.max(1.5,event.Before*.5))
   elseif event.Kind=="DoubleCash" then event.Before=workspace:GetAttribute("OwnerIncomeMultiplier") or 1 workspace:SetAttribute("OwnerIncomeMultiplier",2)
   else event.Before=Lighting.ClockTime Lighting.ClockTime=17.4 end
   activeEvent=event workspace:SetAttribute("OwnerEventName",event.Kind) workspace:SetAttribute("OwnerEventEnds",workspace:GetServerTimeNow()+duration)
   task.delay(duration,function() if activeEvent==event then stopEvent() end end)
   return {Ok=true,Message=event.Kind.." started in this server for "..duration.." seconds."}
  elseif action=="StopEvent" then stopEvent() return {Ok=true,Message="Event stopped; original settings restored."}
  elseif action=="Kick" or action=="Ban24h" or action=="Unban" then
   assert(payload.Confirmed==true,"Confirm this moderation action first.")
   local id,p=target(payload.Target) assert(id,"Enter an exact username or numeric User ID.")
   assert(id~=OWNER,"Your owner account is protected.")
   if action=="Kick" then assert(p,"That player is not in this server.") p:Kick("Removed by the game owner.")
   else
    assert(not RunService:IsStudio(),"Persistent bans must be used in the published game; Studio is a preview.")
    if action=="Ban24h" then Players:BanAsync({UserIds={id},Duration=86400,ApplyToUniverse=true,DisplayReason="Temporarily banned by the game owner.",PrivateReason="Owner panel: 24 hour ban by "..player.UserId,ExcludeAltAccounts=true,ApplyDeviceBlock=false})
    else Players:UnbanAsync({UserIds={id},ApplyToUniverse=true}) end
   end
   return {Ok=true,Message=action.." completed for User ID "..id.."."}
  end
  return {Ok=false,Message="Unknown action."}
 end)
 busy[player]=nil
 if not ok then return {Ok=false,Message=tostring(result):gsub("^.-:%d+: ","")} end
 return result
end
Players.PlayerRemoving:Connect(function(p) last[p]=nil busy[p]=nil end)
local chat=game:GetService("TextChatService")
local command=chat:FindFirstChild("OpenOwnerPanel") or Instance.new("TextChatCommand")
command.Name="OpenOwnerPanel" command.PrimaryAlias="/owner" command.Parent=chat
command.Triggered:Connect(function(source) if source and source.UserId==OWNER then local p=Players:GetPlayerByUserId(OWNER) if p then RS.OwnerPanelOpen:FireClient(p) end end end)
