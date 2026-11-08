-- Night-only optional event. No Lighting or Sky mutations.
local RS=game:GetService("ReplicatedStorage")
local SS=game:GetService("ServerStorage")
local Players=game:GetService("Players")
local Tween=game:GetService("TweenService")
local Http=game:GetService("HttpService")
local folder=RS:WaitForChild("MeteorEvent")
local Config=require(folder:WaitForChild("MeteorConfig"))
local Catalog=require(RS:WaitForChild("CharacterCatalog"))
local Timing=require(RS:WaitForChild("EggHatchTiming"))
local Roles=require(script.Parent:WaitForChild("AdminRoles"))
local Carry=require(script.Parent:WaitForChild("RiverEggCarryService"))
local Path=require(RS:WaitForChild("WaterfallRiver"):WaitForChild("RiverPath"))
local impactRemote=folder:FindFirstChild('Impact') or Instance.new('RemoteEvent')
impactRemote.Name='Impact'; impactRemote.Parent=folder
local rng=Random.new()
local sites=Instance.new("Folder"); sites.Name="MeteorSites"; sites.Parent=workspace
local control=Instance.new("BindableFunction"); control.Name="Control"; control.Parent=script
local active=false
local generation=0
local function now() return workspace:GetServerTimeNow() end
local function fade(site)
 if not site.Parent or site:GetAttribute("Fading") then return end
 site:SetAttribute("Fading",true)
 for _,v in site:GetDescendants() do
  if v:IsA("ProximityPrompt") then v.Enabled=false
  elseif v:IsA("BasePart") then Tween:Create(v,TweenInfo.new(Config.FadeSeconds),{Transparency=1}):Play()
  elseif v:IsA("PointLight") then Tween:Create(v,TweenInfo.new(Config.FadeSeconds),{Brightness=0}):Play() end
 end
 task.delay(Config.FadeSeconds,function() site:Destroy() end)
end
local function part(parent,size,cf,color,material)
 local p=Instance.new("Part"); p.Size=size; p.CFrame=cf; p.Color=color; p.Material=material or Enum.Material.SmoothPlastic; if not material then p.MaterialVariant="HD STUDS" end
 p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false; p.Parent=parent; return p
end
local function dry(p)
 for d=0,Path.Total,4 do
  local cf=Path.At(d)
  local q=cf
  if Vector2.new(p.X-q.X,p.Z-q.Z).Magnitude<Path.WidthAt(d)/2+Config.Radius+4 then return false end
 end
 return true
end
local function landing(existing)
 local ground=workspace:FindFirstChild("WaterfallRiver") and workspace.WaterfallRiver:FindFirstChild("RiverGround")
 if not ground then return end
 local ignore={sites}
 for _,v in workspace:GetDescendants() do if v:IsA("BasePart") and v.Transparency==1 then table.insert(ignore,v) end end
 local params=RaycastParams.new(); params.FilterDescendantsInstances=ignore
 for attempt=1,180 do
  local p=ground.CFrame:PointToWorldSpace(Vector3.new(rng:NextNumber(-ground.Size.X/2+15,ground.Size.X/2-15),ground.Size.Y/2,rng:NextNumber(-ground.Size.Z/2+15,ground.Size.Z/2-15)))
  local valid=dry(p)
  for _,q in existing do if (p-q).Magnitude<Config.MinSeparation then valid=false end end
  if valid then
   for _,offset in {Vector3.zero,Vector3.new(9,0,9),Vector3.new(-9,0,9),Vector3.new(9,0,-9),Vector3.new(-9,0,-9)} do
    local hit=workspace:Raycast(p+offset+Vector3.new(0,100,0),Vector3.new(0,-110,0),params)
    if not hit or hit.Instance~=ground or hit.Normal.Y<0.95 then valid=false; break end
   end
  end
  if valid then return p end
 end
end
local function tool()
 local entry=assert(Catalog.ById[Config.RewardEggType],"Missing catalog egg")
 local source=assert(SS.AuxEggTemplates:FindFirstChild(entry.Id),"Missing egg template")
 local t=Instance.new("Tool"); t.Name=entry.Id.." Egg"; t.CanBeDropped=false
 Catalog.Stamp(t,entry); t:SetAttribute("EggType",entry.Id); t:SetAttribute("Price",entry.Price)
 t:SetAttribute("HatchSeconds",Timing.Seconds(entry.Id)); t:SetAttribute("ItemId",Http:GenerateGUID(false)); t:SetAttribute("MeteorReward",true)
 local model=source:Clone(); model.Name="Egg"; model:ScaleTo(model:GetScale()*0.5); model:PivotTo(CFrame.new()); model.Parent=t
 local h=part(t,Vector3.one,CFrame.new(),Color3.new()); h.Name="Handle"; h.Transparency=1; h.Anchored=false; h.Massless=true
 for _,v in model:GetDescendants() do
  if v:IsA("BaseScript") then v:Destroy() elseif v:IsA("BasePart") then
   v.Anchored=false; v.CanCollide=false; v.CanTouch=false; v.Massless=true
   local w=Instance.new("WeldConstraint"); w.Part0=h; w.Part1=v; w.Parent=h
  end
 end
 return t
end
local function impact(site,p,token)
 if generation~=token or not site.Parent or workspace:GetAttribute("NighttimeActive")~=true then site:Destroy(); return end
 site:SetAttribute("Landed",true); impactRemote:FireAllClients("Impact",p)
 local crater=part(site,Vector3.new(0.25,15,15),CFrame.new(p+Vector3.new(0,0.08,0))*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(39,32,31)); crater.Shape=Enum.PartType.Cylinder
 for i=1,12 do local a=i*math.pi/6
  part(site,Vector3.new(rng:NextInteger(2,4),rng:NextInteger(1,3),rng:NextInteger(2,4)),CFrame.new(p+Vector3.new(math.cos(a)*6.5,0.6,math.sin(a)*6.5))*CFrame.Angles(0,a,0.3),Color3.fromRGB(65,54,50))
 end
 local egg=SS.AuxEggTemplates[Config.RewardEggType]:Clone(); egg.Name="MeteorEgg"
 for _,v in egg:GetDescendants() do if v:IsA("BaseScript") then v:Destroy() elseif v:IsA("BasePart") then v.Anchored=true; v.CanCollide=false; v.CanTouch=false; v.CanQuery=false end end
 local _,size=egg:GetBoundingBox(); egg:ScaleTo(egg:GetScale()*4/math.max(size.Y,0.01)); egg:PivotTo(CFrame.new(p+Vector3.new(0,2.2,0))); egg.Parent=site
 local anchor=part(site,Vector3.one,CFrame.new(p+Vector3.new(0,2,0)),Color3.new()); anchor.Transparency=1
 local light=Instance.new("PointLight"); light.Color=Color3.fromRGB(255,179,77); light.Range=20; light.Brightness=2; light.Parent=anchor
 local prompt=Instance.new("ProximityPrompt"); prompt.ActionText="Collect"; prompt.ObjectText="Meteor God Egg"; prompt.HoldDuration=0.4; prompt.MaxActivationDistance=10; prompt.Parent=anchor
 prompt.Triggered:Connect(function(player)
  if site:GetAttribute("Claimed") or site:GetAttribute("Fading") then return end
  local char=player.Character; local root=char and char:FindFirstChild("HumanoidRootPart"); local hum=char and char:FindFirstChildOfClass("Humanoid")
  local bag=player:FindFirstChildOfClass("Backpack")
  if not root or not hum or hum.Health<=0 or not bag or (root.Position-anchor.Position).Magnitude>12 or Carry.IsCarrying(player) then return end
  site:SetAttribute("Claimed",true); prompt.Enabled=false
  local ok,reward=pcall(tool)
  if not ok then site:SetAttribute("Claimed",false); prompt.Enabled=true; warn(reward); return end
  reward.Parent=bag -- Existing PlayerDataService serializes EggType Tools.
  egg:Destroy(); fade(site)
  local success,err=pcall(Carry.Begin,player,reward)
  if not success then warn(err) end
 end)
 task.delay(Config.RewardLifetime,function() fade(site) end)
end
local function stop()
 generation+=1; active=false; folder:SetAttribute("EndsAt",0)
 for _,site in sites:GetChildren() do fade(site) end
 return true
end
local function start(count)
 if active then return false,"Meteor event already active" end
 if workspace:GetAttribute("NighttimeActive")~=true or (workspace:GetAttribute("NighttimeEndsAt") or 0)-now()<17 then return false,"Needs at least 17 seconds of night remaining" end
 if not SS.AuxEggTemplates:FindFirstChild(Config.RewardEggType) then return false,"Missing reward egg" end
 local positions={}
 for _=1,(count==1 and 1 or count==2 and 2 or rng:NextInteger(1,2)) do local p=landing(positions); if p then table.insert(positions,p) end end
 if #positions==0 then return false,"No clear grass sites" end
 active=true; generation+=1; local token=generation; local epoch=now()
 folder:SetAttribute("StartsAt",epoch); folder:SetAttribute("EndsAt",math.min(epoch+Config.ShowerSeconds,workspace:GetAttribute("NighttimeEndsAt"))); folder:SetAttribute("EventId",Http:GenerateGUID(false))
 for i,p in positions do
  local site=Instance.new("Model"); site.Name="MeteorSite"; site:SetAttribute("Position",p); site:SetAttribute("ImpactAt",epoch+7+(i-1)*6); site.Parent=sites
  task.delay(4+(i-1)*6,function() if generation==token and site.Parent and workspace:GetAttribute("NighttimeActive")==true then impactRemote:FireAllClients("Approach",p) end end)
  task.delay(7+(i-1)*6,function() impact(site,p,token) end)
 end
 local panel=RS:FindFirstChild("OwnerPanel"); local announcement=panel and panel:FindFirstChild("Announcement")
 if announcement then announcement:FireAllClients({title="METEOR SHOWER!",text="Watch for rare eggs in fallen meteor debris!",color="gold",by="Server"}) end
 task.delay(Config.ShowerSeconds,function() if generation==token then active=false; folder:SetAttribute("EndsAt",0) end end)
 return true,#positions
end
control.OnInvoke=function(action,count) if action=="Stop" then return stop() elseif action=="Start" then return start(count) end return false end
local command=Instance.new("TextChatCommand"); command.Name="MeteorCommand"; command.PrimaryAlias="/meteor"; command.Parent=game:GetService("TextChatService")
command.Triggered:Connect(function(source,text)
 local player=Players:GetPlayerByUserId(source.UserId)
 if not player or not Roles.Can(player,"StartBoss") then return end
 local ok,msg
 if text:lower():find("stop") then ok,msg=stop() else ok,msg=start(tonumber(text:match("%s+(%d+)"))) end
 if not ok then warn("[MeteorEvent] "..tostring(msg)) end
end)
local lastCycle=math.floor(now()/300)
while task.wait(0.25) do
 local t=now(); local cycle=math.floor(t/300)
 if cycle~=lastCycle then
  lastCycle=cycle
  if Config.AutomaticEnabled == true and t%300<2 and #Players:GetPlayers()>0 and rng:NextNumber()<Config.ChancePerNight then start() end
 end
 if active and workspace:GetAttribute("NighttimeActive")~=true then stop() end
end
