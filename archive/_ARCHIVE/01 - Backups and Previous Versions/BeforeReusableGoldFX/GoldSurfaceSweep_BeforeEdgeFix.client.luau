
local Collection=game:GetService("CollectionService")
local Run=game:GetService("RunService")
local active={}
local SEGMENTS=40
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
 local emitter=fx:WaitForChild("GoldFX_Emitter",10)
 if emitter then cf=emitter.CFrame size=Vector3.new(emitter.Size.X/.9,emitter.Size.Y/.95,emitter.Size.Z/.9)end
 local root=Instance.new("Part")root.Name="LocalGoldSurfaceSweep"root.Size=Vector3.one root.Transparency=1 root.Anchored=true root.CanCollide=false root.CanTouch=false root.CanQuery=false root.Parent=workspace
 local points={}for i=1,SEGMENTS+1 do local a=Instance.new("Attachment")a.Parent=root points[i]=a end
 local beams={}
 for i=1,SEGMENTS do
 local b=Instance.new("Beam")b.Name="GoldSweepCore"b.Attachment0=points[i]b.Attachment1=points[i+1]b.FaceCamera=true b.Segments=1 b.Width0=size.Y*.018 b.Width1=b.Width0 b.Color=ColorSequence.new(Color3.fromRGB(255,249,218))b.LightEmission=1 b.LightInfluence=0 b.Transparency=NumberSequence.new(.28)b.Enabled=false b.Parent=root
 local halo=b:Clone()halo.Name="GoldSweepHalo"halo.Width0=size.Y*.048 halo.Width1=halo.Width0 halo.Color=ColorSequence.new(Color3.fromRGB(255,213,97))halo.Transparency=NumberSequence.new(.83)halo.Parent=root
 beams[i]={core=b,halo=halo}
 end
 local params=RaycastParams.new()params.FilterType=Enum.RaycastFilterType.Include params.FilterDescendantsInstances=parts params.IgnoreWater=true
 active[model]={fx=fx,parts=parts,params=params,root=root,points=points,beams=beams,size=size,offset=model:GetPivot():ToObjectSpace(cf),targets={},phase=model:GetAttribute("GoldFXPhase")or 0}
end
Collection:GetInstanceAddedSignal("GoldCharacter"):Connect(function(m)task.delay(.5,add,m)end)
Collection:GetInstanceRemovedSignal("GoldCharacter"):Connect(remove)
for _,m in ipairs(Collection:GetTagged("GoldCharacter"))do task.delay(.5,add,m)end
local elapsed=0
Run.Heartbeat:Connect(function(dt)
 elapsed+=dt if elapsed<1/15 then return end elapsed=0
 local camera=workspace.CurrentCamera if not camera then return end
 local now=workspace:GetServerTimeNow()
 for model,d in pairs(active)do
 if not model:IsDescendantOf(workspace)or not d.fx.Parent then remove(model)
 else
 local center=(model:GetPivot()*d.offset).Position
 local near=(camera.CFrame.Position-center).Magnitude<65
 local t=(now+d.phase)%5.8
 local showing=near and t<3.4
 if showing then
 d.root.CFrame=CFrame.new(center)
 local look=camera.CFrame.LookVector
 local right=Vector3.new(camera.CFrame.RightVector.X,0,camera.CFrame.RightVector.Z).Unit
 local width=math.max(d.size.X,d.size.Z)*1.05
 local range=d.size.Magnitude+8
 local hits={}local hitParts={}local old={}
 for _,p in ipairs(d.parts)do if p.Parent then old[p]=p.CanQuery p.CanQuery=true end end
 for i=1,SEGMENTS+1 do
 local x=((i-1)/SEGMENTS-.5)*width
 local y=(t/3.4-.5)*d.size.Y*1.4-x*.34
 local target=center+right*x+Vector3.new(0,y,0)
 local result=workspace:Raycast(target-look*range*.5,look*range,d.params)
 if result then
 local pos=result.Position+result.Normal*.025
 hits[i]=pos hitParts[i]=result.Instance if not d.targets[i]then d.points[i].WorldPosition=pos end d.targets[i]=pos
 end
 end
 for p,value in pairs(old)do if p.Parent then p.CanQuery=value end end
 -- One continuous stripe per visible body surface, rather than short separate dashes.
 for _,b in ipairs(d.beams)do b.core.Enabled=false b.halo.Enabled=false end
 local index=1
 while index<=SEGMENTS do
  if hits[index]then
   local finish=index
   while finish<SEGMENTS+1 and hits[finish+1] and hitParts[finish+1]==hitParts[index] do finish+=1 end
   if finish>index then
    local beam=d.beams[index]
    beam.core.Attachment0=d.points[index]beam.core.Attachment1=d.points[finish]
    beam.halo.Attachment0=d.points[index]beam.halo.Attachment1=d.points[finish]
    beam.core.Enabled=true beam.halo.Enabled=true
    beam.core.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.55),NumberSequenceKeypoint.new(.12,.2),NumberSequenceKeypoint.new(.88,.2),NumberSequenceKeypoint.new(1,.55)})
    beam.halo.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.84),NumberSequenceKeypoint.new(.8,.84),NumberSequenceKeypoint.new(1,1)})
   end
   index=finish+1
  else index+=1 end
 end
 else for _,b in ipairs(d.beams)do b.core.Enabled=false b.halo.Enabled=false end end
 end end
end)
Run.RenderStepped:Connect(function(dt)
 local alpha=1-math.exp(-30*dt)
 for _,d in pairs(active)do
 for i,pos in pairs(d.targets)do
 if d.points[i].Parent then d.points[i].WorldPosition=d.points[i].WorldPosition:Lerp(pos,alpha)end
 end
 end
end)
