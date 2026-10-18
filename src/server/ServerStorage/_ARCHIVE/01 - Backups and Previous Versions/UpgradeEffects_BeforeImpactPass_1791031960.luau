-- Shared "upgrade reveal" effect for temples and hatch chambers.
-- Buildup -> flash/ring/dust -> reveal -> shine sweep -> sparkle fade. ~1.8s.
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local FX={}

FX.Palettes={
 Temple ={core=Color3.fromRGB(255,243,214),glow=Color3.fromRGB(255,203,105),
          spark=Color3.fromRGB(255,222,146),dust=Color3.fromRGB(238,226,198)},
 Chamber={core=Color3.fromRGB(255,247,228),glow=Color3.fromRGB(224,240,174),
          spark=Color3.fromRGB(203,235,158),dust=Color3.fromRGB(230,235,212)},
}

-- Built-in Roblox sounds: no uploaded assets needed. Swap in your own ids here.
FX.Sounds={
 -- cut = stop after this many seconds, pitchTo = glide the pitch over that time
 Whoosh={id="rbxasset://sounds/action_falling.mp3",volume=.30,speed=1.15,pitchTo=2.3,cut=.48},
 Impact={id="rbxasset://sounds/bass.wav",          volume=.45,speed=1.15,cut=.9},
 Shine ={id="rbxasset://sounds/electronicpingshort.wav",volume=.22,speed=1.30,cut=.7},
}

local function shakeEvent()
 return ReplicatedStorage:FindFirstChild("UpgradeShake")
end

local function neon(parent,size,cf,color,transparency)
 local p=Instance.new("Part")
 p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false p.CastShadow=false
 p.Material=Enum.Material.Neon p.Color=color p.Size=size p.CFrame=cf
 p.Transparency=transparency or 0
 p.Parent=parent
 return p
end

local function playSound(host,spec)
 local s=Instance.new("Sound")
 s.SoundId=spec.id s.Volume=spec.volume s.PlaybackSpeed=spec.speed or 1
 s.RollOffMinDistance=30 s.RollOffMaxDistance=260
 s.Parent=host
 s:Play()
 if spec.pitchTo then
  TweenService:Create(s,TweenInfo.new(spec.cut or .5,Enum.EasingStyle.Sine),{PlaybackSpeed=spec.pitchTo}):Play()
 end
 if spec.cut then
  task.delay(spec.cut,function() if s.Parent then s:Stop() end end)
 end
 Debris:AddItem(s,(spec.cut or 3)+1)
 return s
end

local function dustEmitter(host,palette,radius)
 local e=Instance.new("ParticleEmitter")
 e.Color=ColorSequence.new(palette.dust)
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.45),
   NumberSequenceKeypoint.new(.3,.6),NumberSequenceKeypoint.new(1,1)})
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,radius*.16),
   NumberSequenceKeypoint.new(1,radius*.5)})
 e.Lifetime=NumberRange.new(.45,.8)
 e.Speed=NumberRange.new(radius*.45,radius*.85)
 e.SpreadAngle=Vector2.new(68,68)
 e.Drag=4.5
 e.Rotation=NumberRange.new(0,360)
 e.RotSpeed=NumberRange.new(-45,45)
 e.LightEmission=.12
 e.Enabled=false
 e.Parent=host
 return e
end

local function sparkEmitter(host,palette,radius)
 local e=Instance.new("ParticleEmitter")
 e.Color=ColorSequence.new(palette.spark)
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.1),
   NumberSequenceKeypoint.new(.65,.35),NumberSequenceKeypoint.new(1,1)})
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,radius*.055),
   NumberSequenceKeypoint.new(1,0)})
 e.Lifetime=NumberRange.new(.55,1.0)
 e.Speed=NumberRange.new(radius*.3,radius*.7)
 e.SpreadAngle=Vector2.new(55,55)
 e.Acceleration=Vector3.new(0,-14,0)
 e.Drag=2
 e.LightEmission=1
 e.LightInfluence=0
 e.Enabled=false
 e.Parent=host
 return e
end

-- A flat disc that scales outward and fades: reads as a ground shockwave.
local function groundRing(parent,groundCF,color,diameter,duration,thickness,startT)
 local disc=neon(parent,Vector3.new(thickness,diameter*.18,diameter*.18),
   groundCF*CFrame.Angles(0,0,math.pi/2),color,startT)
 disc.Shape=Enum.PartType.Cylinder
 TweenService:Create(disc,TweenInfo.new(duration,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
   {Size=Vector3.new(thickness,diameter,diameter),Transparency=1}):Play()
 Debris:AddItem(disc,duration+.4)
 return disc
end

local function highlight(model,fill,outline,fillT,outlineT)
 local h=Instance.new("Highlight")
 h.Name="UpgradeReveal"
 h.Adornee=model
 h.DepthMode=Enum.HighlightDepthMode.Occluded
 h.FillColor=fill h.OutlineColor=outline
 h.FillTransparency=fillT h.OutlineTransparency=outlineT
 h.Parent=model
 return h
end

--[[ FX.Play(opts)
 opts.anchor    CFrame at ground level, centre of the building
 opts.radius    footprint radius in studs
 opts.height    building height in studs
 opts.oldModel  model visible during the buildup (optional)
 opts.swap      function called at the flash; should return the new model
 opts.palette   FX.Palettes entry
 Runs on the calling thread and returns the new model. ~1.8s.
]]
function FX.Play(opts)
 local palette=opts.palette or FX.Palettes.Temple
 local anchor=opts.anchor
 local radius=math.max(opts.radius or 20,6)
 local height=math.max(opts.height or 20,6)

 local host=Instance.new("Part")
 host.Name="UpgradeFX"
 host.Anchored=true host.CanCollide=false host.CanQuery=false host.CanTouch=false
 host.CastShadow=false host.Transparency=1 host.Size=Vector3.new(1,1,1)
 host.CFrame=anchor*CFrame.new(0,1.5,0)
 host.Parent=workspace
 Debris:AddItem(host,6)

 local dust=dustEmitter(host,palette,radius)
 local sparks=sparkEmitter(host,palette,radius)

 local light=Instance.new("PointLight")
 light.Color=palette.glow light.Range=math.min(radius*1.6,60)
 light.Brightness=0 light.Shadows=false light.Parent=host

 ---------------------------------------------------------------- 1. buildup
 playSound(host,FX.Sounds.Whoosh)
 local buildGlow
 if opts.oldModel then
  buildGlow=highlight(opts.oldModel,palette.glow,palette.core,1,1)
  TweenService:Create(buildGlow,TweenInfo.new(.45,Enum.EasingStyle.Sine,Enum.EasingDirection.In),
    {FillTransparency=.55,OutlineTransparency=.15}):Play()
 end
 TweenService:Create(light,TweenInfo.new(.45,Enum.EasingStyle.Sine,Enum.EasingDirection.In),
   {Brightness=2.2}):Play()
 task.wait(.46)

 ---------------------------------------------------------------- 2. the hit
 if buildGlow then buildGlow:Destroy() end
 local newModel=opts.swap and opts.swap() or nil

 local flash=neon(workspace,Vector3.new(1,1,1)*radius*.5,anchor*CFrame.new(0,radius*.28,0),
   palette.core,.15)
 flash.Shape=Enum.PartType.Ball
 TweenService:Create(flash,TweenInfo.new(.22,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
   {Size=Vector3.new(1,1,1)*radius*1.15,Transparency=1}):Play()
 Debris:AddItem(flash,.5)

 groundRing(workspace,anchor*CFrame.new(0,.35,0),palette.core,radius*2.4,.55,.45,.2)
 groundRing(workspace,anchor*CFrame.new(0,.2,0),palette.glow,radius*1.7,.42,.3,.35)

 light.Brightness=5.5
 TweenService:Create(light,TweenInfo.new(.5,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
   {Brightness=0}):Play()

 dust:Emit(16)
 sparks:Emit(14)
 playSound(host,FX.Sounds.Impact)

 local ev=shakeEvent()
 if ev then ev:FireAllClients(anchor.Position,math.clamp(radius/32,.5,1)) end

 ---------------------------------------------------------------- 3. reveal
 local revealGlow
 if newModel then
  revealGlow=highlight(newModel,palette.core,palette.glow,.5,.1)
  TweenService:Create(revealGlow,TweenInfo.new(.85,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),
    {FillTransparency=1,OutlineTransparency=1}):Play()
  Debris:AddItem(revealGlow,1.1)
 end
 task.wait(.24)

 ---------------------------------------------------------------- 4. shine sweep
 local band=neon(workspace,Vector3.new(radius*2.1,.7,radius*2.1),
   anchor*CFrame.new(0,.6,0),palette.core,.45)
 TweenService:Create(band,TweenInfo.new(.55,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
   {CFrame=anchor*CFrame.new(0,height+2,0),Transparency=1}):Play()
 Debris:AddItem(band,.8)
 playSound(host,FX.Sounds.Shine)
 task.wait(.42)

 ---------------------------------------------------------------- 5. settle
 sparks:Emit(7)
 task.wait(.6)
 return newModel
end

return FX
