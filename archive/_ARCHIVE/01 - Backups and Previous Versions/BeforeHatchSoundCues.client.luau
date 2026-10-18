local RunService=game:GetService("RunService")
local function setup(h)
if not h:IsDescendantOf(workspace) or h:GetAttribute("ClientEffectsReady") then return end
h:SetAttribute("ClientEffectsReady",true)
local frame=h:GetPivot()*CFrame.new(-22.75,-26,-92)
local m=h:WaitForChild("LiquidSystemAndTrim")
local nozzle=m:WaitForChild("InjectorNozzle")
local holder=Instance.new("Part")
holder.Name="LocalChamberGas" holder.Size=Vector3.new(.1,.1,.1)
holder.Transparency=1 holder.Anchored=true holder.CanCollide=false holder.CanTouch=false holder.CanQuery=false
holder.CFrame=frame*CFrame.new(22.75,34.125,92) holder.Parent=m
local function smoke(parent,name,size,lifetime)
 local e=Instance.new("ParticleEmitter") e.Name=name
 e.Texture="rbxasset://textures/particles/smoke_main.dds"
 e.Color=ColorSequence.new(Color3.fromRGB(207,242,157),Color3.fromRGB(143,195,119))
 e.LightEmission=.12 e.LightInfluence=.6
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,size*.6),NumberSequenceKeypoint.new(.5,size),NumberSequenceKeypoint.new(1,size*.9)})
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.58),NumberSequenceKeypoint.new(.7,.72),NumberSequenceKeypoint.new(1,1)})
 e.Lifetime=NumberRange.new(lifetime*.8,lifetime)
 e.Speed=NumberRange.new(0) e.Rotation=NumberRange.new(0,360) e.RotSpeed=NumberRange.new(-18,18)
 e.Rate=0 e.Parent=parent return e
end
local puff=smoke(holder,"TeleportPuff",2.4,.55)
puff.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(.3,.5),NumberSequenceKeypoint.new(1,1)})
local TweenService=game:GetService("TweenService")
puff.Color=ColorSequence.new(Color3.new(1,1,1))
puff.LightEmission=1
puff.LightInfluence=0
local flash=Instance.new("Part")
flash.Name="TeleportWhiteFlash"
flash.Shape=Enum.PartType.Ball
flash.Size=Vector3.one*.25
flash.CFrame=frame*CFrame.new(22.75,35,92)
flash.Color=Color3.new(1,1,1)
flash.Material=Enum.Material.Neon
flash.Transparency=1
flash.Anchored=true
flash.CanCollide=false
flash.CanTouch=false
flash.CanQuery=false
flash.CastShadow=false
flash.Parent=m
local fade
local pulseConnection=h:GetAttributeChangedSignal("TeleportPulse"):Connect(function()
 puff:Emit(9)
 if h:GetAttribute("Status")~="Loading" then return end
 if fade then fade:Cancel() end
 flash.Size=Vector3.one*.25
 flash.Transparency=.4
 fade=TweenService:Create(flash,TweenInfo.new(.42,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Transparency=1,Size=Vector3.one*3.2})
 fade:Play()
end)

local intakeAttachment=Instance.new("Attachment") intakeAttachment.Position=Vector3.new(0,-.35,0) intakeAttachment.Parent=nozzle
local intake=smoke(intakeAttachment,"GasInlet",.7,.65)
intake.EmissionDirection=Enum.NormalId.Bottom intake.Speed=NumberRange.new(1.5,2) intake.SpreadAngle=Vector2.new(12,12)
local layers={}
for layer=1,4 do
 for _,x in {-.65,.65} do for _,z in {-.5,.5} do
  local a=Instance.new("Attachment") a.Position=Vector3.new(x,33.5+(layer-1)*.9-34.125,z) a.Parent=holder
  table.insert(layers,{emitter=smoke(a,"ChamberMist"..layer,1.1,1.2),layer=layer})
 end end
end
local fill=0 local elapsed=0
local heartbeatConnection=RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt if elapsed<.1 then return end
 local step=elapsed elapsed=0
 local camera=workspace.CurrentCamera
 local near=camera and (camera.CFrame.Position-holder.Position).Magnitude<130
 local active=near and h:GetAttribute("Hatching")==true
 local venting=near and h:GetAttribute("Venting")==true
 fill=math.clamp(fill+(active and step/3 or -step*.3),0,1)
 intake.Rate=active and 14 or 0
 for _,item in layers do
  item.emitter.Rate=(active or venting or fill>0) and 2.5*math.clamp(fill*4-(item.layer-1),0,1) or 0
 end
end)
h.Destroying:Connect(function()
 heartbeatConnection:Disconnect() pulseConnection:Disconnect()
end)
end
local collection=game:GetService("CollectionService")
collection:GetInstanceAddedSignal("PlotHatchChamber"):Connect(function(h) task.spawn(setup,h) end)
for _,h in collection:GetTagged("PlotHatchChamber") do task.spawn(setup,h) end
