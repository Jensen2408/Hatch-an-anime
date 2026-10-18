local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local Service={}
local active={}
local event=RS:WaitForChild("RiverEggCarryState")
local function home(player)
 for _,plot in workspace.Plots:GetChildren() do
  if plot:GetAttribute("OwnerUserId")==player.UserId then return plot end
 end
end
local function finish(player,state)
 local rec=active[player] if not rec then return end
 active[player]=nil
 if rec.visual then rec.visual:Destroy() end
 if rec.tool and rec.tool.Parent then rec.tool.Enabled=rec.enabled;rec.tool:SetAttribute("ReturningToBase",nil) end
 player:SetAttribute("RiverEggCarryBase",nil)
 player:SetAttribute("RiverEggCarryId",nil)
 event:FireClient(player,state,{id=rec.id})
end
function Service.Begin(player,tool)
 local plot=home(player)
 local char=player.Character
 local torso=char and (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso"))
 local source=tool:FindFirstChild("Egg")
 if not plot or not torso or not source then return false end
 if active[player] then finish(player,"Cancelled") end
 local rec={tool=tool,enabled=tool.Enabled,plot=plot,char=char,started=os.clock(),id=game:GetService("HttpService"):GenerateGUID(false)}
 active[player]=rec
 tool.Enabled=false;tool:SetAttribute("ReturningToBase",true)
 local model=Instance.new("Model") model.Name="RiverEggCarry"
 local carrier=Instance.new("Part") carrier.Name="Carrier";carrier.Size=Vector3.one*.2
 carrier.Transparency=1;carrier.CanCollide=false;carrier.CanQuery=false;carrier.CanTouch=false;carrier.Massless=true
 carrier.CFrame=torso.CFrame*CFrame.new(0,-.25,-1.15);carrier.Parent=model
 local egg=source:Clone()
 for _,d in egg:GetDescendants() do
  if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("BillboardGui") then d:Destroy() end
 end
 local box,size=egg:GetBoundingBox()
 egg:ScaleTo(egg:GetScale()*math.min(2.2/math.max(size.Y,.01),1.9/math.max(size.X,.01)))
 local fittedSize;box,fittedSize=egg:GetBoundingBox()
 model:SetAttribute("GripHalfWidth",math.clamp(fittedSize.X*.5,.45,.95))
 egg:PivotTo(carrier.CFrame*box:ToObjectSpace(egg:GetPivot()))
 egg.Parent=model
 for _,p in egg:GetDescendants() do if p:IsA("BasePart") then
  p.Anchored=false;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true
  -- Preserve the original egg colours, materials and mesh textures.
  local weld=Instance.new("WeldConstraint") weld.Part0=carrier;weld.Part1=p;weld.Parent=p
 end end
 local hold=Instance.new("WeldConstraint") hold.Part0=torso;hold.Part1=carrier;hold.Parent=carrier
 model.Parent=char;rec.visual=model
 local base=plot.PlotSpawn.Position
 player:SetAttribute("RiverEggCarryBase",base)
 player:SetAttribute("RiverEggCarryId",rec.id)
 event:FireClient(player,"Stolen",{basePosition=base,id=rec.id})
 return true
end
RunService.Heartbeat:Connect(function()
 for player,rec in active do
  local char=player.Character
  local root=char and char:FindFirstChild("HumanoidRootPart")
  local hum=char and char:FindFirstChildOfClass("Humanoid")
  if char~=rec.char or not root or not hum or hum.Health<=0 or not rec.tool.Parent or rec.plot:GetAttribute("OwnerUserId")~=player.UserId then
   finish(player,"Cancelled")
  elseif os.clock()-rec.started>.5 then
   local rel=rec.plot.TempleAnchor.CFrame:PointToObjectSpace(root.Position)
   if rel.X>=-58 and rel.X<=32 and rel.Z>=-32 and rel.Z<=48 and rel.Y>=-15 and rel.Y<=60 then
    finish(player,"Secured")
   end
  end
 end
end)
Players.PlayerRemoving:Connect(function(p) local rec=active[p] if rec and rec.visual then rec.visual:Destroy() end active[p]=nil end)
function Service.Drop(player)
 local rec=active[player] if not rec then return false end
 local tool=rec.tool
 finish(player,"Dropped")
 return require(game.ServerScriptService.TwoHandItemCarryService).DropTool(player,tool)
end
return Service