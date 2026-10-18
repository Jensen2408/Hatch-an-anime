-- Upgrade reveal: gather -> WHITE FLASH (swap hidden inside it) -> shards,
-- pillar and shockwave -> shine -> settle. Roughly 1.8s.
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local FX={}

FX.Palettes={
 Temple ={core=Color3.fromRGB(255,255,255),glow=Color3.fromRGB(255,196,84),
          spark=Color3.fromRGB(255,226,150),dust=Color3.fromRGB(236,224,198),
          shard=Color3.fromRGB(255,214,128)},
 Chamber={core=Color3.fromRGB(255,255,255),glow=Color3.fromRGB(214,238,160),
          spark=Color3.fromRGB(226,246,178),dust=Color3.fromRGB(230,235,212),
          shard=Color3.fromRGB(206,234,158)},
}

-- Impact + shine tones removed on request. Drop your own ids in and they play again.
FX.Sounds={
 Whoosh={id="rbxasset://sounds/action_falling.mp3",volume=.26,speed=1.1,pitchTo=2.4,cut=.5},
 Impact=nil,
 Shine =nil,
}

local function neon(parent,size,cf,color,transparency)
 local p=Instance.new("Part")
 p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false p.CastShadow=false
 p.Material=Enum.Material.Neon p.Color=color p.Size=size p.CFrame=cf
 p.Transparency=transparency or 0
 p.Parent=parent
 return p
end

local function playSound(host,spec)
 if not spec or not spec.id then return end
 local s=Instance.new("Sound")
 s.SoundId=spec.id s.Volume=spec.volume s.PlaybackSpeed=spec.speed or 1
 s.RollOffMinDistance=30 s.RollOffMaxDistance=260
 s.Parent=host s:Play()
 if spec.pitchTo then
  TweenService:Create(s,TweenInfo.new(spec.cut or .5,Enum.EasingStyle.Sine),{PlaybackSpeed=spec.pitchTo}):Play()
 end
 if spec.cut then task.delay(spec.cut,function() if s.Parent then s:Stop() end end) end
 Debris:AddItem(s,(spec.cut or 3)+1)
 return s
end

local function disc(parent,groundCF,color,diameter,thickness,transparency)
 local d=neon(parent,Vector3.new(thickness,diameter,diameter),
   groundCF*CFrame.Angles(0,0,math.pi/2),color,transparency)
 d.Shape=Enum.PartType.Cylinder
 return d
end

local function shards(parent,anchor,palette,radius,count)
 for i=1,count do
  local a=(i/count)*math.pi*2+math.random()*.4
  local w=Instance.new("WedgePart")
  w.Anchored=true w.CanCollide=false w.CanQuery=false w.CanTouch=false w.CastShadow=false
  w.Material=Enum.Material.SmoothPlastic
  w.Color=palette.shard
  local s=radius*(.09+math.random()*.07)
  w.Size=Vector3.new(s*.7,s,s*1.5)
  w.CFrame=anchor*CFrame.new(math.cos(a)*radius*.25,radius*.12,math.sin(a)*radius*.25)
    *CFrame.Angles(math.random()*6,math.random()*6,math.random()*6)
  w.Parent=parent
  local dist=radius*(.9+math.random()*.7)
  local goal=anchor*CFrame.new(math.cos(a)*dist,radius*(.35+math.random()*.45),math.sin(a)*dist)
    *CFrame.Angles(math.random()*8,math.random()*8,math.random()*8)
  TweenService:Create(w,TweenInfo.new(.62,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
    {CFrame=goal,Transparency=1}):Play()
  Debris:AddItem(w,.9)
 end
end

local function rim(model,color,outlineT)
 local h=Instance.new("Highlight")
 h.Name="UpgradeReveal" h.Adornee=model
 h.DepthMode=Enum.HighlightDepthMode.Occluded
 h.FillColor=color h.OutlineColor=color
 h.FillTransparency=1 h.OutlineTransparency=outlineT
 h.Parent=model
 return h
end

function FX.Play(opts)
 local palette=opts.palette or FX.Palettes.Temple
 local anchor=opts.anchor
 local radius=math.max(opts.radius or 20,6)
 local height=math.max(opts.height or 20,6)

 local host=Instance.new("Part")
 host.Name="UpgradeFX" host.Anchored=true host.CanCollide=false
 host.CanQuery=false host.CanTouch=false host.CastShadow=false
 host.Transparency=1 host.Size=Vector3.new(radius*1.6,1,radius*1.6)
 host.CFrame=anchor*CFrame.new(0,1,0)
 host.Parent=workspace
 Debris:AddItem(host,3.4)

 local light=Instance.new("PointLight")
 light.Color=palette.glow light.Range=math.min(radius*1.8,60)
 light.Brightness=0 light.Shadows=false light.Parent=host

 local gather=Instance.new("ParticleEmitter")
 gather.Color=ColorSequence.new(palette.spark)
 gather.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),
   NumberSequenceKeypoint.new(.25,.15),NumberSequenceKeypoint.new(1,1)})
 gather.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,radius*.045),
   NumberSequenceKeypoint.new(1,0)})
 gather.Lifetime=NumberRange.new(.45,.55)
 gather.Speed=NumberRange.new(-radius*1.5,-radius*1.1)
 gather.SpreadAngle=Vector2.new(16,16)
 gather.EmissionDirection=Enum.NormalId.Top
 gather.LightEmission=1 gather.LightInfluence=0
 gather.Enabled=false gather.Parent=host

 local dust=Instance.new("ParticleEmitter")
 dust.Color=ColorSequence.new(palette.dust)
 dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),
   NumberSequenceKeypoint.new(.3,.62),NumberSequenceKeypoint.new(1,1)})
 dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,radius*.18),
   NumberSequenceKeypoint.new(1,radius*.62)})
 dust.Lifetime=NumberRange.new(.5,.9)
 dust.Speed=NumberRange.new(radius*.6,radius*1.05)
 dust.SpreadAngle=Vector2.new(78,78)
 dust.Drag=5 dust.Rotation=NumberRange.new(0,360)
 dust.RotSpeed=NumberRange.new(-50,50)
 dust.LightEmission=.1 dust.Enabled=false dust.Parent=host

 local sparks=Instance.new("ParticleEmitter")
 sparks.Color=ColorSequence.new(palette.spark)
 sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.05),
   NumberSequenceKeypoint.new(.7,.3),NumberSequenceKeypoint.new(1,1)})
 sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,radius*.05),
   NumberSequenceKeypoint.new(1,0)})
 sparks.Lifetime=NumberRange.new(.6,1.1)
 sparks.Speed=NumberRange.new(radius*.4,radius*.95)
 sparks.SpreadAngle=Vector2.new(60,60)
 sparks.Acceleration=Vector3.new(0,-16,0)
 sparks.Drag=1.8 sparks.LightEmission=1 sparks.LightInfluence=0
 sparks.Enabled=false sparks.Parent=host

 local ev=ReplicatedStorage:FindFirstChild("UpgradeShake")

 ------------------------------------------------------------------ 1. windup
 playSound(host,FX.Sounds.Whoosh)
 local ring=disc(workspace,anchor*CFrame.new(0,.3,0),palette.glow,radius*2.6,.3,.55)
 TweenService:Create(ring,TweenInfo.new(.52,Enum.EasingStyle.Quart,Enum.EasingDirection.In),
   {Size=Vector3.new(.3,radius*.5,radius*.5),Transparency=.2}):Play()
 Debris:AddItem(ring,.7)

 local windGlow
 if opts.oldModel then
  windGlow=rim(opts.oldModel,palette.glow,1)
  TweenService:Create(windGlow,TweenInfo.new(.5,Enum.EasingStyle.Quart,Enum.EasingDirection.In),
    {OutlineTransparency=.1}):Play()
 end
 TweenService:Create(light,TweenInfo.new(.5,Enum.EasingStyle.Quart,Enum.EasingDirection.In),
   {Brightness=3}):Play()
 gather:Emit(22)
 task.wait(.38)
 gather:Emit(16)
 task.wait(.17)

 ------------------------------------------------------------------ 2. impact
 if ev then
  ev:FireAllClients({
   position=anchor.Position,
   strength=math.clamp(radius/32,.55,1),
   flash=true,
   tint=palette.glow,
  })
 end
 if windGlow then windGlow:Destroy() end
 local newModel=opts.swap and opts.swap() or nil

 light.Brightness=7
 TweenService:Create(light,TweenInfo.new(.55,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
   {Brightness=0}):Play()

 local wave=disc(workspace,anchor*CFrame.new(0,.35,0),palette.core,radius*.4,.5,.1)
 TweenService:Create(wave,TweenInfo.new(.48,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
   {Size=Vector3.new(.5,radius*3.1,radius*3.1),Transparency=1}):Play()
 Debris:AddItem(wave,.7)
 local wave2=disc(workspace,anchor*CFrame.new(0,.2,0),palette.glow,radius*.3,.35,.35)
 TweenService:Create(wave2,TweenInfo.new(.62,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
   {Size=Vector3.new(.35,radius*2.2,radius*2.2),Transparency=1}):Play()
 Debris:AddItem(wave2,.8)

 local pillar=neon(workspace,Vector3.new(height*.3,radius*.9,radius*.9),
   anchor*CFrame.new(0,height*.15,0)*CFrame.Angles(0,0,math.pi/2),palette.core,.25)
 pillar.Shape=Enum.PartType.Cylinder
 TweenService:Create(pillar,TweenInfo.new(.42,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
   {Size=Vector3.new(height*2.3,radius*.22,radius*.22),
    CFrame=anchor*CFrame.new(0,height*1.15,0)*CFrame.Angles(0,0,math.pi/2),
    Transparency=1}):Play()
 Debris:AddItem(pillar,.6)

 shards(workspace,anchor,palette,radius,9)
 dust:Emit(18)
 sparks:Emit(16)

 ------------------------------------------------------------------ 3. reveal
 local revealRim
 if newModel then
  revealRim=rim(newModel,palette.core,.05)
  TweenService:Create(revealRim,TweenInfo.new(.75,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),
    {OutlineTransparency=1}):Play()
  Debris:AddItem(revealRim,1)
 end
 task.wait(.2)

 ------------------------------------------------------------------ 4. shine
 local band=neon(workspace,Vector3.new(radius*2.05,.35,radius*2.05),
   anchor*CFrame.new(0,.4,0),palette.core,.3)
 TweenService:Create(band,TweenInfo.new(.45,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
   {CFrame=anchor*CFrame.new(0,height+2,0),Transparency=1}):Play()
 Debris:AddItem(band,.7)
 task.wait(.42)

 ------------------------------------------------------------------ 5. settle
 sparks:Emit(8)
 task.wait(.6)
 return newModel
end

return FX
