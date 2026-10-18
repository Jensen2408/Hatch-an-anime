local RunService=game:GetService("RunService")
local active={}
local function add(model)
 if not model:IsA("Model") or active[model] then return end
 if model.Name~="LUFFY GOLD" and not (model.Name=="HatchedCharacter" and model:GetAttribute("Golden"))then return end
 local root=model:FindFirstChild("HumanoidRootPart",true)
 if not root then return end
 local joints={}
 for _,v in ipairs(model:GetDescendants())do
  if v:IsA("Motor6D")then joints[v]=v.C0
  elseif v:IsA("BasePart")then v.Anchored=v==root v.CanCollide=false end
 end
 active[model]={root=root,joints=joints}
end
workspace.DescendantAdded:Connect(function(v)if v:IsA("Model")then task.defer(add,v)end end)
for _,v in ipairs(workspace:GetDescendants())do if v:IsA("Model")then add(v)end end
RunService:BindToRenderStep("GoldenLuffyIdle",Enum.RenderPriority.Camera.Value+3,function()
 local t=os.clock()
 for model,data in pairs(active)do
 if not model:IsDescendantOf(workspace)then active[model]=nil
 elseif workspace.CurrentCamera and (workspace.CurrentCamera.CFrame.Position-data.root.Position).Magnitude<100 then
 for joint,base in pairs(data.joints)do
 if joint.Parent then
 local angle=math.sin(t*1.8)*.045
 if joint.Name=="Right Shoulder"then joint.C0=base*CFrame.Angles(0,0,angle)
 elseif joint.Name=="Left Shoulder"then joint.C0=base*CFrame.Angles(0,0,-angle)
 elseif joint.Name=="Neck"then joint.C0=base*CFrame.Angles(math.sin(t*1.1)*.025,0,0)
 elseif joint.Name=="RootJoint"then joint.C0=base*CFrame.new(0,math.sin(t*1.8)*.035,0) end
 end end end end
end)
