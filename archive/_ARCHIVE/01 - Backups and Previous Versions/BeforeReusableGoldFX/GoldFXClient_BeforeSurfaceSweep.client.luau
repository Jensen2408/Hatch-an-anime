
local Collection=game:GetService("CollectionService")
local Run=game:GetService("RunService")
local active={}
local function add(model)
 local fx=model:WaitForChild("GoldFX",10)if not fx then return end
 local emitter=fx:WaitForChild("GoldFX_Emitter",10)
 local ground=fx:WaitForChild("GroundRing",10)
 local shells=fx:WaitForChild("ShineShells",10)
 if not emitter or not ground or not shells or not model:IsDescendantOf(workspace) then return end
 local light=emitter:WaitForChild("WarmLight",10)
 local ripple=ground:WaitForChild("RingBurst",10)
 local shine=fx:WaitForChild("GoldShine",10)
 active[model]={fx=fx,highlight=fx:FindFirstChild("GoldShine"),light=light,ring=ripple,phase=model:GetAttribute("GoldFXPhase")or 0,last=-1}
end
Collection:GetInstanceAddedSignal("GoldCharacter"):Connect(function(m)task.defer(add,m)end)
Collection:GetInstanceRemovedSignal("GoldCharacter"):Connect(function(m)active[m]=nil end)
for _,m in ipairs(Collection:GetTagged("GoldCharacter"))do add(m)end
local dtSum=0
Run.Heartbeat:Connect(function(dt)
 dtSum+=dt if dtSum<.05 then return end dtSum=0
 local cam=workspace.CurrentCamera local now=workspace:GetServerTimeNow()
 local count=0 for _ in pairs(active)do count+=1 end
 local budget=math.min(1,8/math.max(1,count))
 for model,data in pairs(active)do
  if not model:IsDescendantOf(workspace)or not data.fx.Parent then active[model]=nil
  else
   local position=data.fx.GoldFX_Emitter.Position
   local near=cam and(cam.CFrame.Position-position).Magnitude<110 or false
   local time=now+data.phase local cycle=math.floor(time/3.2)local t=time%3.2
   local k=math.max(0,1-math.abs(t-.45)/.45)
   if data.highlight then data.highlight.Enabled=near data.highlight.FillTransparency=1-.55*k*k end
   if data.light then data.light.Enabled=near data.light.Brightness=1.4+.25*math.sin(time*2)+1.6*k end
   for _,e in ipairs(data.fx.GoldFX_Emitter:GetChildren())do if e:IsA("ParticleEmitter")then e.Enabled=near e.Rate=(e:GetAttribute("BaseRate")or 10)*budget end end
   if near and cycle~=data.last then if data.ring then data.ring:Emit(math.floor(40*budget))end data.last=cycle end
   for _,shell in ipairs(data.fx.ShineShells:GetChildren())do if shell:IsA("BasePart")then shell.Transparency=near and(.65-.15*math.sin(time*2))or 1 end end
  end
 end
end)
