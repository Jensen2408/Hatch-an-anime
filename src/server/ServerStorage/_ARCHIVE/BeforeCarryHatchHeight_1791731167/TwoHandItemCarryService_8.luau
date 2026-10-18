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
local function stop(player)
 local rec=records[player] if not rec then return end
 records[player]=nil
 if rec.visual then rec.visual:Destroy() end
 for p,t in rec.hidden do if p.Parent then p.Transparency=t end end
end
function Service.Attach(player,tool)
 if not eligible(tool) or tool:GetAttribute("ReturningToBase") then return end
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
 local factor=math.min(2.2/math.max(size.Y,.01),1.9/math.max(size.X,.01))
 visual:ScaleTo(visual:GetScale()*factor)
 local box,newSize=visual:GetBoundingBox()
 local half=math.clamp(newSize.X*.5,.45,.95)
 carrier.CFrame=require(game.ServerScriptService.CarryGripLayout).Frame(char,torso,half)
 visual:PivotTo(carrier.CFrame*box:ToObjectSpace(visual:GetPivot()));visual.Parent=model
 model:SetAttribute("GripHalfWidth",math.clamp(newSize.X*.5,.45,.95))
 for _,p in visual:GetDescendants() do if p:IsA("BasePart") then
 p.Anchored=false;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true
 local weld=Instance.new("WeldConstraint") weld.Part0=carrier;weld.Part1=p;weld.Parent=p
 end end
 local hold=Instance.new("WeldConstraint") hold.Part0=torso;hold.Part1=carrier;hold.Parent=carrier
 for _,p in original:GetDescendants() do if p:IsA("BasePart") then rec.hidden[p]=p.Transparency;p.Transparency=1 end end
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
 local visual=presentation(tool):Clone() clean(visual)
 local _,size=visual:GetBoundingBox() visual:ScaleTo(visual:GetScale()*math.min(2.2/math.max(size.Y,.01),1.9/math.max(size.X,.01)))
 local box,newSize=visual:GetBoundingBox()
 local position=root.Position+root.CFrame.LookVector*3
 local params=RaycastParams.new() params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances={char,drops}
 local hit=workspace:Raycast(position+Vector3.new(0,5,0),Vector3.new(0,-30,0),params)
 if hit then position=Vector3.new(position.X,hit.Position.Y+newSize.Y*.5+.1,position.Z) end
 visual:PivotTo(CFrame.new(position)*box:ToObjectSpace(visual:GetPivot()));visual.Parent=model
 for _,p in visual:GetDescendants() do if p:IsA("BasePart") then p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false end end
 local anchor=Instance.new("Part") anchor.Name="PickupAnchor";anchor.Anchored=true;anchor.Transparency=1;anchor.Size=Vector3.one;anchor.Position=position
 anchor.CanCollide=false;anchor.CanTouch=false;anchor.Parent=model
 local prompt=Instance.new("ProximityPrompt") prompt.ActionText="Pick up";prompt.ObjectText=tool.Name;prompt.KeyboardKeyCode=Enum.KeyCode.E;prompt.MaxActivationDistance=10;prompt.HoldDuration=.15;prompt.RequiresLineOfSight=false;prompt.Parent=anchor
 local storage=Instance.new("Folder") storage.Name="Item";storage.Parent=model
 -- The ground visual is the only visible copy. Park the owned Tool invisibly.
 local itemId=tool:GetAttribute("EggId") or tool:GetAttribute("CarryItemId")
 if not itemId then itemId=game.HttpService:GenerateGUID(false);tool:SetAttribute("CarryItemId",itemId) end
 for _,part in tool:GetDescendants() do if part:IsA("BasePart") then
  part:SetAttribute("DropOriginalTransparency",part.Transparency)
  part:SetAttribute("DropOriginalAnchored",part.Anchored)
  part.Transparency=1;part.Anchored=true
 end end
 local gear=player:FindFirstChild("StarterGear")
 if gear then for _,other in gear:GetChildren() do
  if other:IsA("Tool") and (other:GetAttribute("EggId")==itemId or other:GetAttribute("CarryItemId")==itemId) then other:Destroy() end
 end end
 tool.Parent=storage;model.Parent=drops
 local claimed=false
 prompt.Triggered:Connect(function(p)
 if claimed or tool.Parent~=storage then return end
 local r=p.Character and p.Character:FindFirstChild("HumanoidRootPart")
 local h=p.Character and p.Character:FindFirstChildOfClass("Humanoid")
 local bag=p:FindFirstChildOfClass("Backpack")
 if not r or not h or h.Health<=0 or not bag or (r.Position-anchor.Position).Magnitude>12 then return end
 claimed=true;prompt.Enabled=false
 for _,part in tool:GetDescendants() do if part:IsA("BasePart") then
  local alpha=part:GetAttribute("DropOriginalTransparency")
  local anchored=part:GetAttribute("DropOriginalAnchored")
  if alpha~=nil then part.Transparency=alpha end
  if anchored~=nil then part.Anchored=anchored end
  part:SetAttribute("DropOriginalTransparency",nil);part:SetAttribute("DropOriginalAnchored",nil)
 end end
 tool.Parent=bag
 if tool:GetAttribute("EggType") and not tool:GetAttribute("CharacterId") then require(game.ServerScriptService.RiverEggCarryService).Begin(p,tool)
 else h:EquipTool(tool) end
 model:Destroy()
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