local Run=game:GetService("RunService")
local active={}
local function add(model)
 if not model:IsA("Model") or active[model] then return end
 if model.Name~="LUFFY GOLD" and not(model.Name=="HatchedCharacter" and model:GetAttribute("Golden"))then return end
 local cf,size=model:GetBoundingBox()
 local folder=Instance.new("Folder")folder.Name="GoldenCharacterVFX"folder.Parent=workspace
 local root=Instance.new("Part")root.Size=Vector3.one root.Transparency=1 root.Anchored=true root.CanCollide=false root.CanTouch=false root.CanQuery=false root.Parent=folder
 local glints={}
 for i,pos in ipairs({Vector3.new(size.X*.38,size.Y*.15,-size.Z*.52),Vector3.new(-size.X*.28,size.Y*.4,-size.Z*.4),Vector3.new(size.X*.14,-size.Y*.24,-size.Z*.5)})do
 local a=Instance.new("Attachment")a.Position=pos a.Parent=root
 local gui=Instance.new("BillboardGui")gui.Size=UDim2.fromOffset(65,65)gui.AlwaysOnTop=false gui.MaxDistance=100 gui.LightInfluence=0 gui.Parent=a
 local glow=Instance.new("ImageLabel")glow.Size=UDim2.fromScale(1,1)glow.BackgroundTransparency=1 glow.Image="rbxasset://textures/particles/sparkles_main.dds"glow.ImageColor3=Color3.fromRGB(255,238,165)glow.Parent=gui
 for j=1,2 do
 local line=Instance.new("Frame")line.AnchorPoint=Vector2.new(.5,.5)line.Position=UDim2.fromScale(.5,.5)
 line.Size=j==1 and UDim2.fromScale(.72,.025)or UDim2.fromScale(.025,.9)
 line.BorderSizePixel=0 line.BackgroundColor3=Color3.fromRGB(255,249,210)line.Parent=gui
 local gradient=Instance.new("UIGradient")gradient.Rotation=j==1 and 0 or 90 gradient.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.45,.1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(.55,.1),NumberSequenceKeypoint.new(1,1)})gradient.Parent=line
 end
 table.insert(glints,{gui=gui,glow=glow,phase=i*2})
 end
 local rings={}
 for ring=1,2 do for i=1,28 do
 local p=Instance.new("Part")p.Name="GoldOrbitFleck"p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false p.CastShadow=false p.Material=Enum.Material.Neon p.Color=Color3.fromRGB(255,198,70)
 p.Size=Vector3.new(size.Y*.022,.025,size.Y*.045)p.Parent=folder
 table.insert(rings,{part=p,angle=i*math.pi*2/28,radius=size.X*(ring==1 and .72 or 1.05),direction=ring==1 and 1 or -1})
 end end
 local sweep0=Instance.new("Attachment")sweep0.Parent=root
 local sweep1=Instance.new("Attachment")sweep1.Parent=root
 local beam=Instance.new("Beam")beam.Name="GoldLightSweep"beam.Attachment0=sweep0 beam.Attachment1=sweep1 beam.FaceCamera=true beam.Width0=size.Y*.055 beam.Width1=beam.Width0 beam.LightEmission=1 beam.Color=ColorSequence.new(Color3.fromRGB(255,239,170))
 beam.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.3,.6),NumberSequenceKeypoint.new(.5,.2),NumberSequenceKeypoint.new(.7,.6),NumberSequenceKeypoint.new(1,1)})beam.Parent=root
 local halo=beam:Clone()halo.Name="GoldSweepSoftGlow"
 halo.Width0=size.Y*.16 halo.Width1=halo.Width0
 halo.Color=ColorSequence.new(Color3.fromRGB(255,210,85))
 halo.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.9),NumberSequenceKeypoint.new(.5,.72),NumberSequenceKeypoint.new(.8,.9),NumberSequenceKeypoint.new(1,1)})
 halo.Parent=root
 active[model]={folder=folder,root=root,offset=model:GetPivot():ToObjectSpace(cf),size=size,glints=glints,rings=rings,beam=beam,halo=halo,a=sweep0,b=sweep1}
end
workspace.DescendantAdded:Connect(function(v)if v:IsA("Model")then task.defer(add,v)end end)
for _,v in ipairs(workspace:GetDescendants())do if v:IsA("Model")then add(v)end end
local elapsed=0
Run.Heartbeat:Connect(function(dt)
 elapsed+=dt if elapsed<.05 then return end elapsed=0
 local now=os.clock()
 for model,item in pairs(active)do
 if not model:IsDescendantOf(workspace)then item.folder:Destroy()active[model]=nil
 else
 local cf=model:GetPivot()*item.offset
 local near=workspace.CurrentCamera and(workspace.CurrentCamera.CFrame.Position-cf.Position).Magnitude<100
 item.root.CFrame=cf item.beam.Enabled=near or false
 local fx=model:FindFirstChild("GoldFX")
 if fx then
 local highlight=fx:FindFirstChild("GoldShine")
 local emitter=fx:FindFirstChild("GoldFX_Emitter")
 local light=emitter and emitter:FindFirstChildWhichIsA("PointLight")
 local t=now%3.2 local k=math.max(0,1-math.abs(t-.45)/.45)
 if highlight then highlight.Enabled=near or false highlight.FillTransparency=0.88-.4*k*k end
 if light then light.Enabled=near or false light.Brightness=2.6+.4*math.sin(now*2)+2*k end
 if emitter then for _,e in ipairs(emitter:GetChildren())do if e:IsA("ParticleEmitter")then e.Enabled=near or false end end end
 end

 for _,g in ipairs(item.glints)do
 local pulse=math.max(0,math.sin(now*2+g.phase))^6
 g.gui.Enabled=near and pulse>.03 or false
 g.gui.Size=UDim2.fromOffset(35+40*pulse,35+40*pulse)
 g.glow.ImageTransparency=.3+.6*(1-pulse)
 end
 item.beam.Enabled=near and (now%5)<3.4 or false item.halo.Enabled=item.beam.Enabled
 local progress=math.clamp((now%5)/3.4,0,1)
 item.a.Position=Vector3.new(-item.size.X*.48,(progress-.5)*item.size.Y*1.35+item.size.Y*.18,-item.size.Z*.53)
 item.b.Position=Vector3.new(item.size.X*.48,(progress-.5)*item.size.Y*1.35-item.size.Y*.18,-item.size.Z*.53)
 for _,r in ipairs(item.rings)do
 r.part.Transparency=near and .3 or 1
 if near then local angle=r.angle+now*.12*r.direction r.part.CFrame=CFrame.new(cf.Position+Vector3.new(math.cos(angle)*r.radius,-item.size.Y*.5+.035,math.sin(angle)*r.radius))*CFrame.Angles(0,-angle,0)end
 end
 end end
end)
