
local Collection=game:GetService("CollectionService")
local Run=game:GetService("RunService")
local active={}
local SEGMENTS=24
local function remove(model)
 local data=active[model]if data then data.root:Destroy()active[model]=nil end
end
local add
add=function(model)
 if active[model]then return end
 local fx=model:WaitForChild("GoldFX",10)if not fx or not model:IsDescendantOf(workspace)then return end
 local parts={}for _,p in ipairs(model:GetDescendants())do if p:IsA("MeshPart")and not p:FindFirstAncestor("GoldFX")then table.insert(parts,p)end end
 if #parts==0 then task.delay(.5,function()if model:IsDescendantOf(workspace)then add(model)end end)return end
 local cf,size=model:GetBoundingBox()
 local root=Instance.new("Part")root.Name="LocalGoldSurfaceSweep"root.Size=Vector3.one root.Transparency=1 root.Anchored=true root.CanCollide=false root.CanTouch=false root.CanQuery=false root.Parent=workspace
 local points={}for i=1,SEGMENTS+1 do local a=Instance.new("Attachment")a.Parent=root points[i]=a end
 local beams={}
 for i=1,SEGMENTS do
 local b=Instance.new("Beam")b.Name="GoldSweepCore"b.Attachment0=points[i]b.Attachment1=points[i+1]b.FaceCamera=true b.Segments=1 b.Width0=size.Y*.022 b.Width1=b.Width0 b.Color=ColorSequence.new(Color3.fromRGB(255,249,218))b.LightEmission=1 b.LightInfluence=0 b.Transparency=NumberSequence.new(.15)b.Enabled=false b.Parent=root
 local halo=b:Clone()halo.Name="GoldSweepHalo"halo.Width0=size.Y*.085 halo.Width1=halo.Width0 halo.Color=ColorSequence.new(Color3.fromRGB(255,213,97))halo.Transparency=NumberSequence.new(.65)halo.Parent=root
 beams[i]={core=b,halo=halo}
 end
 local params=RaycastParams.new()params.FilterType=Enum.RaycastFilterType.Include params.FilterDescendantsInstances=parts params.IgnoreWater=true
 active[model]={fx=fx,parts=parts,params=params,root=root,points=points,beams=beams,size=size,offset=model:GetPivot():ToObjectSpace(cf),phase=model:GetAttribute("GoldFXPhase")or 0}
end
Collection:GetInstanceAddedSignal("GoldCharacter"):Connect(function(m)task.delay(.5,add,m)end)
Collection:GetInstanceRemovedSignal("GoldCharacter"):Connect(remove)
for _,m in ipairs(Collection:GetTagged("GoldCharacter"))do task.delay(.5,add,m)end
local elapsed=0
Run.Heartbeat:Connect(function(dt)
 elapsed+=dt if elapsed<1/30 then return end elapsed=0
 local camera=workspace.CurrentCamera if not camera then return end
 local now=workspace:GetServerTimeNow()
 for model,d in pairs(active)do
 if not model:IsDescendantOf(workspace)or not d.fx.Parent then remove(model)
 else
 local center=(model:GetPivot()*d.offset).Position
 local near=(camera.CFrame.Position-center).Magnitude<85
 local t=(now+d.phase)%4.6
 local showing=near and t<2.7
 if showing then
 d.root.CFrame=CFrame.new(center)
 local look=camera.CFrame.LookVector
 local right=Vector3.new(camera.CFrame.RightVector.X,0,camera.CFrame.RightVector.Z).Unit
 local width=math.max(d.size.X,d.size.Z)*1.05
 local range=d.size.Magnitude+8
 local hits={}local old={}
 for _,p in ipairs(d.parts)do if p.Parent then old[p]=p.CanQuery p.CanQuery=true end end
 for i=1,SEGMENTS+1 do
 local x=((i-1)/SEGMENTS-.5)*width
 local y=(t/2.7-.5)*d.size.Y*1.4-x*.34
 local target=center+right*x+Vector3.new(0,y,0)
 local result=workspace:Raycast(target-look*range*.5,look*range,d.params)
 if result then
 local pos=result.Position+result.Normal*.025
 hits[i]=pos d.points[i].WorldPosition=pos
 end
 end
 for p,value in pairs(old)do if p.Parent then p.CanQuery=value end end
 for i,b in ipairs(d.beams)do
 local valid=hits[i]and hits[i+1]and(hits[i]-hits[i+1]).Magnitude<width*.22
 b.core.Enabled=valid and true or false b.halo.Enabled=b.core.Enabled
 end
 else for _,b in ipairs(d.beams)do b.core.Enabled=false b.halo.Enabled=false end end
 end end
end)
