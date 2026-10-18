local RunService=game:GetService("RunService")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local h=workspace:WaitForChild("HATCH")
local m=h:WaitForChild("LiquidSystemAndTrim")
local nozzle=m:WaitForChild("InjectorNozzle")
local holder=Instance.new("Part")
holder.Name="LocalHatchSpray"
holder.Size=Vector3.new(.1,.1,.1) holder.Transparency=1 holder.Anchored=true holder.CanCollide=false holder.CanTouch=false holder.CanQuery=false
holder.Position=Vector3.new(22.75,35.25,92) holder.Parent=m
local green=Color3.fromRGB(157,230,99)
local beams={}
for i=-1,1 do
 local a=Instance.new("Attachment") a.Position=Vector3.new(i*.2,-.25,0) a.Parent=nozzle
 local b=Instance.new("Attachment") b.Position=Vector3.new(i*.45,0,0) b.Parent=holder
 local beam=Instance.new("Beam") beam.Attachment0=a beam.Attachment1=b beam.FaceCamera=true beam.Width0=.055 beam.Width1=.12 beam.Segments=3
 beam.Color=ColorSequence.new(green) beam.Transparency=NumberSequence.new(.25) beam.LightEmission=.25 beam.Enabled=false beam.Parent=holder table.insert(beams,beam)
end
local spray=Instance.new("ParticleEmitter")
spray.Name="LiquidSplash" spray.Texture="rbxasset://textures/particles/sparkles_main.dds"
spray.Color=ColorSequence.new(green) spray.LightEmission=.25
spray.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(1,.025)})
spray.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(1,1)})
spray.Lifetime=NumberRange.new(.25,.45) spray.Speed=NumberRange.new(2,4) spray.Acceleration=Vector3.new(0,-15,0) spray.SpreadAngle=Vector2.new(65,65) spray.Rate=24 spray.Enabled=false spray.Parent=holder
local function update()
 local active=h:GetAttribute("Hatching")==true
 for _,b in beams do b.Enabled=active end
 spray.Enabled=active
end
h:GetAttributeChangedSignal("Hatching"):Connect(update) update()
local shakeEnd,shakeStart,shakeDuration,strength=0,0,0,0
local lastHum,baseOffset
game.ReplicatedStorage:WaitForChild("HatchCameraCue").OnClientEvent:Connect(function(duration,amount)
 shakeStart=os.clock() shakeDuration=duration shakeEnd=shakeStart+duration strength=amount
end)
RunService:BindToRenderStep("HatchGentleShake",Enum.RenderPriority.Camera.Value-1,function()
 local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 if lastHum and lastHum.Parent and baseOffset then lastHum.CameraOffset=baseOffset end
 lastHum=nil baseOffset=nil
 if hum and os.clock()<shakeEnd then
  local t=os.clock()-shakeStart
  local fade=1-t/shakeDuration
  baseOffset=hum.CameraOffset lastHum=hum
  hum.CameraOffset=baseOffset+Vector3.new(math.sin(t*83),math.cos(t*67),0)*strength*fade
 end
end)
