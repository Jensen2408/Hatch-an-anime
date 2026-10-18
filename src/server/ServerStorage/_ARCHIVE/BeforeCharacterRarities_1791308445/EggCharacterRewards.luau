local library=game.ServerStorage:WaitForChild("BrainrotModels")
local Rewards={}
function Rewards.Resolve(tool,source)
 local kind=(tool and tool:GetAttribute("EggType")) or source:GetAttribute("EggType") or (tool and tool.Name) or "Pirate"
 kind=tostring(kind):gsub("[Ee]gg",""):gsub("^%s+",""):gsub("%s+$","")

 local model=library:FindFirstChild(kind)
 if model and model:IsA("Model") and model:GetAttribute("CharacterId") then return model,kind end
 return nil,kind
end
function Rewards.Tool(template,id)
 local tool=Instance.new("Tool")
 tool.Name=id.." Character";tool.ToolTip="Hatched "..id.." • Place on your temple plate";tool.CanBeDropped=false
 tool:SetAttribute("BrainrotId",id);tool:SetAttribute("CharacterId",id);tool:SetAttribute("Hatched",true)
 local visual=template:Clone();visual.Name="Character";visual:ScaleTo(visual:GetScale()*.5)
 local box=visual:GetBoundingBox()
 visual:PivotTo(visual:GetPivot()-box.Position);visual.Parent=tool
 local handle=Instance.new("Part");handle.Name="Handle";handle.Size=Vector3.one;handle.Transparency=1;handle.CanCollide=false;handle.CanTouch=false;handle.Massless=true;handle.Parent=tool
 for _,p in visual:GetDescendants() do
  if p:IsA("BasePart") then
   p.Anchored=false;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true
   local w=Instance.new("WeldConstraint");w.Part0=handle;w.Part1=p;w.Parent=handle
  elseif p:IsA("BaseScript") or p:IsA("ProximityPrompt") or p:IsA("BillboardGui") then p:Destroy() end
 end
 tool.Grip=CFrame.new(0,-.35,0)*CFrame.Angles(0,math.pi,0)
 return tool
end
return Rewards
