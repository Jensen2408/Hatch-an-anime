
local Collection=game:GetService("CollectionService")
local Run=game:GetService("RunService")
local config=game.ReplicatedStorage:WaitForChild("GoldShineConfig")
local active={}
local function add(model)
 if active[model]then return end
 local fx=model:WaitForChild("GoldFX",10)if not fx then return end
 local boxes=fx:WaitForChild("ShineBoxes",10)
 local emitter=fx:WaitForChild("GoldFX_Emitter",10)
 local ground=fx:WaitForChild("GroundRing",10)
 if not boxes or not emitter or not ground then return end
 local light=emitter:WaitForChild("WarmLight",10)local ring=ground:WaitForChild("RingBurst",10)
 local highlight=fx:WaitForChild("GoldShine",10)
 local textures={}for _,v in ipairs(boxes:GetDescendants())do if v:IsA("Texture")then table.insert(textures,{texture=v,box=v.Parent,sideCycle=-1,sideStart=-1})end end
 local root=model:FindFirstChild("HumanoidRootPart",true)or model:FindFirstChild("Torso",true)
 if not root then return end
 active[model]={fx=fx,root=root,boxes=boxes:GetChildren(),textures=textures,light=light,ring=ring,highlight=highlight,start=workspace:GetServerTimeNow()-(model:GetAttribute("GoldFXPhase")or 0),burstCycle=-1}
end
Collection:GetInstanceAddedSignal("GoldCharacter"):Connect(function(m)task.defer(add,m)end)
Collection:GetInstanceRemovedSignal("GoldCharacter"):Connect(function(m)active[m]=nil end)
for _,m in ipairs(Collection:GetTagged("GoldCharacter"))do task.spawn(add,m)end
Run.RenderStepped:Connect(function()
 local camera=workspace.CurrentCamera if not camera then return end
 local now=workspace:GetServerTimeNow()
 local duration=config:GetAttribute("Duration")or .9
 local period=math.max(config:GetAttribute("Period")or 3.2,duration+.1)
 local sign=config:GetAttribute("OffsetSign")or 1
 local count=0 for _ in pairs(active)do count+=1 end
 local budget=math.min(1,8/math.max(1,count))
 for model,data in pairs(active)do
 if not model:IsDescendantOf(workspace)or not data.fx.Parent then active[model]=nil
 else
 local near=(camera.CFrame.Position-data.root.Position).Magnitude<120
 local elapsed=math.max(0,now-data.start)local cycle=math.floor(elapsed/period)local phase=elapsed%period
 local sweeping=near and phase<duration
 local k=math.clamp(phase/duration,0,1)
 local pulse=sweeping and math.max(0,1-math.abs(phase-duration*.5)/(duration*.5))or 0
 if data.highlight then data.highlight.Enabled=near data.highlight.FillTransparency=.86-.44*pulse*pulse end
 if data.light then data.light.Enabled=near data.light.Brightness=1.4+.25*math.sin(elapsed*2)+1.6*pulse end
 if sweeping and phase>=duration*.5 and data.burstCycle~=cycle then data.burstCycle=cycle if data.ring then data.ring:Emit(math.floor(40*budget))end end
 for _,e in ipairs(data.fx.GoldFX_Emitter:GetChildren())do if e:IsA("ParticleEmitter")then e.Enabled=near e.Rate=(e:GetAttribute("BaseRate")or 10)*budget end end
 for _,shell in ipairs(data.fx.ShineShells:GetChildren())do if shell:IsA("BasePart")then shell.Transparency=1 end end
 if sweeping then
 local R=data.root.CFrame.RightVector
 local minR,maxR,topY=math.huge,-math.huge,-math.huge
 for _,b in ipairs(data.boxes)do
 for _,x in ipairs({-.5,.5})do for _,y in ipairs({-.5,.5})do for _,z in ipairs({-.5,.5})do
 local corner=b.CFrame:PointToWorldSpace(Vector3.new(b.Size.X*x,b.Size.Y*y,b.Size.Z*z))
 local r=corner:Dot(R)minR=math.min(minR,r)maxR=math.max(maxR,r)topY=math.max(topY,corner.Y)
 end end end
 end
 minR-=3 maxR+=3
 local s=minR+(maxR-minR)*(k*k*(3-2*k))
 local fade=math.min(1,k/.1,(1-k)/.1)
 for _,entry in ipairs(data.textures)do
 local tex,b=entry.texture,entry.box
 local U,N,width
 if tex.Face==Enum.NormalId.Front then U=-b.CFrame.RightVector N=b.CFrame.LookVector width=b.Size.X
 elseif tex.Face==Enum.NormalId.Back then U=b.CFrame.RightVector N=-b.CFrame.LookVector width=b.Size.X
 elseif tex.Face==Enum.NormalId.Left then U=b.CFrame.LookVector N=-b.CFrame.RightVector width=b.Size.Z
 else U=-b.CFrame.LookVector N=b.CFrame.RightVector width=b.Size.Z end
 local depth=(tex.Face==Enum.NormalId.Front or tex.Face==Enum.NormalId.Back)and b.Size.Z or b.Size.X
 local faceCenter=b.Position+N*depth*.5
 local origin=faceCenter-U*width*.5+b.CFrame.UpVector*b.Size.Y*.5
 local dot=U:Dot(R)local band
 if math.abs(dot)>.8 then band=(s-origin:Dot(R))/dot
 else
 if entry.sideCycle~=cycle then entry.sideCycle=cycle entry.sideStart=-1 end
 if entry.sideStart<0 and math.abs(s-faceCenter:Dot(R))<=.6 then entry.sideStart=phase end
 if entry.sideStart>=0 and phase-entry.sideStart<=.25 then band=-1+(width+2)*math.clamp((phase-entry.sideStart)/.25,0,1)end
 end
 if band then
 tex.OffsetStudsU=sign*(8-band)
 tex.OffsetStudsV=topY-(b.Position.Y+b.Size.Y*.5)
 tex.Transparency=1-.9*fade
 else tex.Transparency=1 end
 end
 else for _,entry in ipairs(data.textures)do entry.texture.Transparency=1 end end
 end end
end)
