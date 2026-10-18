local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local Service={}
local records={}
local drops=workspace:FindFirstChild("DroppedCarryItems") or Instance.new("Folder",workspace)
drops.Name="DroppedCarryItems"
local function eligible(tool)
 return tool:IsA("Tool") and tool:GetAttribute("HoldStyle")~="OneHand" and (tool:GetAttribute("EggType")~=nil or tool:GetAttribute("CharacterId")~=nil or tool:GetAttribute("BrainrotId")~=nil)
end
local function source(tool) return tool:FindFirstChild("Egg") or tool:FindFirstChild("Character") end
local function presentation(tool)
 -- mutated items keep their own mutated model + aura VFX (the plain templates would turn them back to normal)
 if tool:GetAttribute("Mutation") and source(tool) then return source(tool) end
 if tool:GetAttribute("GoldVariant") then
  local future=game.ServerStorage:FindFirstChild("FutureUpdateContent")
  local kind=tool:GetAttribute("CharacterId") and "Characters" or "Eggs"
  local folder=future and future:FindFirstChild(kind)
  local gold=folder and folder:FindFirstChild("Golden Pirate")
  if gold then return gold end
 end
 local eggs=game.ServerStorage:FindFirstChild("AuxEggTemplates")
 local chars=game.ServerStorage:FindFirstChild("BrainrotModels")
 local id=tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId")
 local template=id and chars and chars:FindFirstChild(id)
 if not template then
  local eggType=tool:GetAttribute("EggType")
  template=eggType and eggs and eggs:FindFirstChild(eggType)
 end
 return template or source(tool)
end
local function clean(model)
 for _,d in model:GetDescendants() do
  if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") or d:IsA("Sound") then d:Destroy() end
 end
end
local function calmVFX(model,factor)
 -- ScaleTo grows particles/lights with the model; held/dropped items keep normal-size, softer effects.
 local k=1/math.max(factor,1)
 for _,d in model:GetDescendants() do
  if d:IsA("ParticleEmitter") then
   local pts={} for _,p in d.Size.Keypoints do table.insert(pts,NumberSequenceKeypoint.new(p.Time,math.min(p.Value*k,1.2),math.min(p.Envelope*k,.3))) end
   d.Size=NumberSequence.new(pts) d.Speed=NumberRange.new(d.Speed.Min*k,d.Speed.Max*k) d.Rate=d.Rate*.5 d.LightEmission=math.min(d.LightEmission,.3) d.Brightness=math.min(d.Brightness,1.5)
  elseif d:IsA("Light") then d.Range=math.min(d.Range*k,8) d.Brightness=math.min(d.Brightness,1)
  elseif d:IsA("Beam") or d:IsA("Trail") then d.LightEmission=math.min(d.LightEmission,.5) end
 end
end
local function stop(player)
 local rec=records[player] if not rec then return end
 records[player]=nil
 if rec.visual then rec.visual:Destroy() end
 for p,t in rec.hidden do if p.Parent then p.Transparency=t end end if rec.off then for e in rec.off do if e.Parent then e.Enabled=true end end end
end
function Service.Attach(player,tool)
 if not eligible(tool) then return end
 local char=player.Character local torso=char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
 local original=source(tool)
 if not torso or not original or tool.Parent~=char then return end
 stop(player)
 local rec={tool=tool,hidden={}} records[player]=rec
 local model=Instance.new("Model") model.Name="HeldItemCarry"
 local carrier=Instance.new("Part") carrier.Name="Carrier";carrier.Size=Vector3.one*.2;carrier.Transparency=1;carrier.Massless=true
 carrier.CanCollide=false;carrier.CanTouch=false;carrier.CanQuery=false
 carrier.CFrame=torso.CFrame*CFrame.new(0,-.25,-1.15);carrier.Parent=model
 local visual=presentation(tool):Clone() clean(visual)
 local _,size=visual:GetBoundingBox()
 local isCharacter=tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId")
 local factor=isCharacter and 6/math.max(size.Y,.01) or math.min(3.3/math.max(size.Y,.01),2.9/math.max(size.X,.01)) -- eggs held at normal tool size
 visual:ScaleTo(visual:GetScale()*factor) calmVFX(visual,factor)
 local box,newSize=visual:GetBoundingBox()
 local half=math.clamp(newSize.X*.5,.45,isCharacter and .95 or 1.45)
 carrier.CFrame=require(game.ServerScriptService.CarryGripLayout).Frame(char,torso,half)
 visual:PivotTo(carrier.CFrame*box:ToObjectSpace(visual:GetPivot()));visual.Parent=model
 model:SetAttribute("GripHalfWidth",half)
 for _,p in visual:GetDescendants() do if p:IsA("BasePart") then
 p.Anchored=false;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true
 local weld=Instance.new("WeldConstraint") weld.Part0=carrier;weld.Part1=p;weld.Parent=p
 end end
 local hold=Instance.new("WeldConstraint") hold.Part0=torso;hold.Part1=carrier;hold.Parent=carrier
 for _,p in original:GetDescendants() do if p:IsA("BasePart") then rec.hidden[p]=p.Transparency;p.Transparency=1
  elseif (p:IsA("ParticleEmitter") or p:IsA("Light") or p:IsA("Beam") or p:IsA("Trail")) and p.Enabled then rec.off=rec.off or {} rec.off[p]=true p.Enabled=false end end
 if not isCharacter then -- name + glowing rarity over a held egg, readable from a distance
  local RAR={Common=Color3.fromRGB(220,225,235),Uncommon=Color3.fromRGB(20,255,0),Rare=Color3.fromRGB(31,139,255),Epic=Color3.fromRGB(182,61,255),Legendary=Color3.fromRGB(255,196,0)}
  local rarity=tool:GetAttribute("Rarity") local id=tool:GetAttribute("EggType")
  if not rarity and id then local ok,Cat=pcall(require,RS:FindFirstChild("CharacterCatalog")) if ok and Cat.ById[id] then rarity=Cat.ById[id].Rarity end end
  rarity=RAR[rarity] and rarity or "Common" local rc=RAR[rarity]
  local bb=Instance.new("BillboardGui") bb.Name="HeldEggLabel" bb.Size=UDim2.fromOffset(200,58) bb.StudsOffset=Vector3.new(0,newSize.Y*.5+1.4,0) bb.MaxDistance=160 bb.LightInfluence=0 bb.AlwaysOnTop=false bb.Adornee=carrier bb.Parent=model
  local function lbl(txt,y,h,size,col,stCol,th) local l=Instance.new("TextLabel") l.BackgroundTransparency=1 l.Position=UDim2.fromOffset(0,y) l.Size=UDim2.new(1,0,0,h) l.Font=Enum.Font.FredokaOne l.Text=txt l.TextSize=size l.TextColor3=col l.Parent=bb local st=Instance.new("UIStroke") st.Color=stCol st.Thickness=th st.LineJoinMode=Enum.LineJoinMode.Round st.Parent=l return l,st end
  lbl((id or tool.Name):gsub("%s*[Ee]gg$","").." Egg",0,28,24,Color3.new(1,1,1),Color3.fromRGB(11,10,14),2)
  local g,gs=lbl(string.upper(rarity),28,26,20,rc,rc,6) g.TextTransparency=.4 gs.Transparency=.55
  local r,rs=lbl(string.upper(rarity),28,26,20,Color3.new(1,1,1),rc,2.6)
  game:GetService("TweenService"):Create(gs,TweenInfo.new(.9,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Transparency=.9,Thickness=9}):Play()
 end
 model.Parent=char;rec.visual=model
end
function Service.DropTool(player,tool)
 local char=player.Character local root=char and char:FindFirstChild("HumanoidRootPart")
 local hum=char and char:FindFirstChildOfClass("Humanoid")
 if not root or not hum or hum.Health<=0 or not eligible(tool) or not (tool.Parent==char or tool.Parent==player:FindFirstChildOfClass("Backpack")) then return false end
 local original=source(tool) if not original then return false end
 stop(player)
 hum:UnequipTools()
 local model=Instance.new("Model") model.Name=tool.Name.." Dropped"
 local visual=presentation(tool):Clone() clean(visual) -- mutated eggs use their own mutated model + aura (see presentation)
 local characterItem=tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId")
 local _,size=visual:GetBoundingBox()
 -- dropped eggs are big and easy to spot (about 1.6x the held size)
 local dropFactor=characterItem and 6/math.max(size.Y,.01) or math.min(5.2/math.max(size.Y,.01),4.6/math.max(size.X,.01))
 visual:ScaleTo(visual:GetScale()*dropFactor) calmVFX(visual,dropFactor)
 local box,newSize=visual:GetBoundingBox()
 -- land a few studs to the side so the knocked-out player doesn't fall on it
 local dir=CFrame.Angles(0,math.random()*math.pi*2,0).LookVector
 local position=root.Position+dir*4
 local params=RaycastParams.new() params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={char,drops}
 local hit=workspace:Raycast(position+Vector3.new(0,6,0),Vector3.new(0,-40,0),params)
 local ground=hit and hit.Position.Y or (root.Position.Y-3)
 local restY=ground+newSize.Y*.5+.6
 local offset=box:ToObjectSpace(visual:GetPivot())
 visual:PivotTo(CFrame.new(position.X,restY+6,position.Z)*offset);visual.Parent=model
 for _,p in visual:GetDescendants() do if p:IsA("BasePart") then p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false end end
 local anchor=Instance.new("Part") anchor.Name="PickupAnchor";anchor.Anchored=true;anchor.Transparency=1;anchor.Size=Vector3.one;anchor.Position=Vector3.new(position.X,restY,position.Z)
 anchor.CanCollide=false;anchor.CanTouch=false;anchor.CanQuery=false;anchor.Parent=model
 local prompt=Instance.new("ProximityPrompt") prompt.ActionText="Pick up";prompt.ObjectText=tool.Name;prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.MaxActivationDistance=12;prompt.HoldDuration=.2;prompt.RequiresLineOfSight=false;prompt.Parent=anchor
 -- rarity colour for the FX
 local RAR={Common=Color3.fromRGB(235,240,255),Uncommon=Color3.fromRGB(60,255,90),Rare=Color3.fromRGB(60,160,255),Epic=Color3.fromRGB(190,90,255),Legendary=Color3.fromRGB(255,200,40),Limited=Color3.fromRGB(255,60,90)}
 local MUT={Silver=Color3.fromRGB(220,230,245),Gold=Color3.fromRGB(255,200,60),Diamond=Color3.fromRGB(90,225,255),Rainbow=Color3.fromRGB(255,90,220)}
 local rarity=tool:GetAttribute("Rarity") local eggId=tool:GetAttribute("EggType")
 if not rarity and eggId then local ok,Cat=pcall(require,RS:FindFirstChild("CharacterCatalog")) if ok and Cat.ById[eggId] then rarity=Cat.ById[eggId].Rarity end end
 local mut=tool:GetAttribute("Mutation")
 local col=MUT[mut] or RAR[rarity] or RAR.Common
 -- light pillar + glow + sparkles + ground ring
 local base=Instance.new("Attachment") base.Parent=anchor base.Position=Vector3.new(0,-newSize.Y*.5,0)
 local top=Instance.new("Attachment") top.Parent=anchor top.Position=Vector3.new(0,22,0)
 local beam=Instance.new("Beam") beam.Attachment0=base beam.Attachment1=top beam.Width0=2.6 beam.Width1=.4 beam.FaceCamera=true beam.LightEmission=1 beam.LightInfluence=0
 beam.Color=ColorSequence.new(col) beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.25),NumberSequenceKeypoint.new(1,1)}) beam.Parent=anchor
 local light=Instance.new("PointLight") light.Color=col light.Range=14 light.Brightness=2.5 light.Parent=anchor
 local spark=Instance.new("ParticleEmitter") spark.Name="DropSparkles" spark.Color=ColorSequence.new(Color3.new(1,1,1),col) spark.LightEmission=1 spark.Rate=14
 spark.Lifetime=NumberRange.new(.8,1.4) spark.Speed=NumberRange.new(2,4) spark.SpreadAngle=Vector2.new(180,180) spark.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(1,0)}) spark.Parent=anchor
 local burst=spark:Clone() burst.Name="DropBurst" burst.Rate=0 burst.Speed=NumberRange.new(10,18) burst.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}) burst.Parent=anchor
 local ring=Instance.new("Part") ring.Name="GlowRing" ring.Shape=Enum.PartType.Cylinder ring.Anchored=true ring.CanCollide=false ring.CanTouch=false ring.CanQuery=false ring.Material=Enum.Material.Neon ring.Color=col ring.Transparency=.35
 ring.Size=Vector3.new(.15,newSize.X*1.6,newSize.X*1.6) ring.CFrame=CFrame.new(position.X,ground+.08,position.Z)*CFrame.Angles(0,0,math.pi/2) ring.Parent=model
 -- floating label
 local bb=Instance.new("BillboardGui") bb.Name="DropLabel" bb.Adornee=anchor bb.Size=UDim2.fromOffset(240,64) bb.StudsOffset=Vector3.new(0,newSize.Y*.5+2.2,0) bb.MaxDistance=120 bb.LightInfluence=0 bb.AlwaysOnTop=true bb.Parent=model
 local function lbl(txt,y,h,sz,c,th) local l=Instance.new("TextLabel") l.BackgroundTransparency=1 l.Position=UDim2.fromOffset(0,y) l.Size=UDim2.new(1,0,0,h) l.Font=Enum.Font.FredokaOne l.Text=txt l.TextSize=sz l.TextColor3=c l.Parent=bb local st=Instance.new("UIStroke") st.Color=Color3.fromRGB(11,10,14) st.Thickness=th st.Parent=l return l end
 local top1=lbl("DROPPED!",0,30,28,col,3)
 lbl(((mut and (mut.." ") or "")..(eggId or tool.Name:gsub("%s*[Ee]gg$",""))).." Egg  •  grab it!",30,26,19,Color3.new(1,1,1),2)
 local TS=game:GetService("TweenService")
 TS:Create(top1,TweenInfo.new(.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{TextSize=32}):Play()
 -- the owned Tool is parked in ServerStorage: a Tool sitting in Workspace is auto-picked up by touch,
 -- which used to put it straight back into the knocked-out player's hand and left an empty egg on the ground
 local store=game.ServerStorage:FindFirstChild("DroppedItemStore") or Instance.new("Folder") store.Name="DroppedItemStore" store.Parent=game.ServerStorage
 local storage=Instance.new("Folder") storage.Name=game.HttpService:GenerateGUID(false) storage.Parent=store
 local itemId=tool:GetAttribute("EggId") or tool:GetAttribute("CarryItemId")
 if not itemId then itemId=game.HttpService:GenerateGUID(false);tool:SetAttribute("CarryItemId",itemId) end
 local gear=player:FindFirstChild("StarterGear")
 if gear then for _,other in gear:GetChildren() do
  if other:IsA("Tool") and (other:GetAttribute("EggId")==itemId or other:GetAttribute("CarryItemId")==itemId) then other:Destroy() end
 end end
 tool.Enabled=true tool:SetAttribute("ReturningToBase",nil)
 tool.Parent=storage;model.Parent=drops
 -- pop: fall in with a bounce, burst of sparkles, then bob + spin
 local alive=true
 task.spawn(function()
  local t0=os.clock()
  while alive and model.Parent do
   local t=os.clock()-t0
   local y
   if t<.45 then local a=t/.45 y=restY+6*(1-a*a) elseif t<.75 then local a=(t-.45)/.3 y=restY+math.sin(a*math.pi)*1.2 else y=restY+math.sin((t-.75)*2.4)*.35 end
   visual:PivotTo(CFrame.new(position.X,y,position.Z)*CFrame.Angles(0,t*1.6,0)*offset)
   if t>=.45 and not burst:GetAttribute("Done") then burst:SetAttribute("Done",true) burst:Emit(40) end
   task.wait(1/30)
  end
 end)
 local claimed=false
 local droppedBy,droppedAt=player,os.clock()
 local function finish() alive=false claimed=true prompt.Enabled=false if model.Parent then model:Destroy() end if storage.Parent and #storage:GetChildren()==0 then storage:Destroy() end end
 prompt.Triggered:Connect(function(p)
  if claimed or tool.Parent~=storage then return end
  if p==droppedBy and os.clock()-droppedAt<2 then return end
  local r=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
  local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
  local bag=p:FindFirstChildOfClass("Backpack")
  if not r or not h or h.Health<=0 or not bag or (r.Position-anchor.Position).Magnitude>14 then return end
  tool.Parent=bag
  finish()
  if tool:GetAttribute("EggType") and not tool:GetAttribute("CharacterId") then
   local ok=pcall(require(game.ServerScriptService.RiverEggCarryService).Begin,p,tool)
   if not ok then h:EquipTool(tool) end
  else h:EquipTool(tool) end
 end)
 -- nobody grabbed it: back to whoever dropped it after 60 s (or gone if they left)
 task.delay(60,function()
  if claimed or tool.Parent~=storage then return end
  local bag=droppedBy.Parent and droppedBy:FindFirstChildOfClass("Backpack")
  if bag then tool.Parent=bag else tool:Destroy() end
  finish()
 end)
 return true
end
local function watchCharacter(player,char)
 char.ChildAdded:Connect(function(tool) if eligible(tool) then task.defer(Service.Attach,player,tool) end end)
 char.ChildRemoved:Connect(function(tool) local rec=records[player] if rec and rec.tool==tool then stop(player) end end)
 for _,tool in char:GetChildren() do if eligible(tool) then Service.Attach(player,tool) end end
end
function Service.Init()
 local function watch(p)
 p.CharacterAdded:Connect(function(c) stop(p);watchCharacter(p,c) end)
 if p.Character then watchCharacter(p,p.Character) end
 end
 for _,p in Players:GetPlayers() do watch(p) end
 Players.PlayerAdded:Connect(watch)
 Players.PlayerRemoving:Connect(stop)
end
return Service