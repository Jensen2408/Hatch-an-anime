-- Upgrade reveal: windup -> a bright ghost of the new building teleports in
-- above the plot and flows down -> it lands, white flash hides the swap ->
-- shockwave, shards, shine, settle. Roughly 2.0s.
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local FX={}

FX.Palettes={
 Temple ={core=Color3.fromRGB(255,255,255),glow=Color3.fromRGB(255,196,84),
          spark=Color3.fromRGB(255,226,150),dust=Color3.fromRGB(236,224,198),
          shard=Color3.fromRGB(255,214,128),ghost=Color3.fromRGB(255,228,160)},
 Chamber={core=Color3.fromRGB(255,255,255),glow=Color3.fromRGB(214,238,160),
          spark=Color3.fromRGB(226,246,178),dust=Color3.fromRGB(230,235,212),
          shard=Color3.fromRGB(206,234,158),ghost=Color3.fromRGB(226,248,180)},
}

-- Impact + shine tones removed on request. Add an entry here and it plays again.
FX.Sounds={
 Whoosh={id="rbxasset://sounds/action_falling.mp3",volume=.26,speed=1.1,pitchTo=2.4,cut=.5},
}

-- ponytail: ghost is capped to the biggest 90 parts and animated server-side.
-- Move it client-side if CFrame replication ever shows up in bandwidth.
local GHOST_CAP=90

local function neon(parent,size,cf,color,transparency)
 local p=Instance.new("Part")
 p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false p.CastShadow=false
 p.Material=Enum.Material.Neon p.Color=color p.Size=size p.CFrame=cf
 p.Transparency=transparency
 p.Parent=parent
 return p
end

local function playSound(host,spec)
 if not spec then return end
 local s=Instance.new("Sound")
 s.SoundId=spec.id s.Volume=spec.volume s.PlaybackSpeed=spec.speed or 1
 s.RollOffMinDistance=30 s.RollOffMaxDistance=260
 s.Parent=host s:Play()
 if spec.pitchTo then
  TweenService:Create(s,TweenInfo.new(spec.cut or .5,Enum.EasingStyle.Sine),{PlaybackSpeed=spec.pitchTo}):Play()
 end
 if spec.cut then task.delay(spec.cut,function() if s.Parent then s:Stop() end end) end
 Debris:AddItem(s,(spec.cut or 3)+1)
end

local function disc(parent,groundCF,color,diameter,thickness,transparency)
 local d=neon(parent,Vector3.new(thickness,diameter,diameter),
   groundCF*CFrame.Angles(0,0,math.pi/2),color,transparency)
 d.Shape=Enum.PartType.Cylinder
 return d
end

local function rim(model,color,outlineT)
 local h=Instance.new("Highlight")
 h.Name="UpgradeReveal" h.Adornee=model
 h.DepthMode=Enum.HighlightDepthMode.Occluded
 h.OutlineColor=color
 h.FillTransparency=1 h.OutlineTransparency=outlineT
 h.Parent=model
 return h
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

-- A glowing silhouette of the building that is about to arrive.
local function buildGhost(source,color)
 local g=Instance.new("Model")
 g.Name="UpgradeGhost"
 local parts={}
 for _,d in source:GetDescendants() do
  if d:IsA("BasePart") then parts[#parts+1]=d end
 end
 table.sort(parts,function(a,b)
  local x,y=a.Size,b.Size
  return x.X*x.Y*x.Z>y.X*y.Y*y.Z
 end)
 for i=1,math.min(#parts,GHOST_CAP) do
  local p=parts[i]:Clone()
  p:ClearAllChildren()
  p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false p.CastShadow=false
  p.Material=Enum.Material.Neon p.Color=color p.Transparency=.62 p.Reflectance=0
  if p:IsA("MeshPart") then p.TextureID="" end
  p.Parent=g
 end
 g.WorldPivot=source:GetPivot()
 return g
end

function FX.Play(opts)
 local palette=opts.palette or FX.Palettes.Temple
 local anchor=opts.anchor
 local radius=math.max(opts.radius,6)
 local height=math.max(opts.height,6)
 local rise=height*1.25+10

 local host=Instance.new("Part")
 host.Name="UpgradeFX" host.Anchored=true host.CanCollide=false
 host.CanQuery=false host.CanTouch=false host.CastShadow=false
 host.Transparency=1 host.Size=Vector3.new(radius*1.6,1,radius*1.6)
 host.CFrame=anchor*CFrame.new(0,1,0)
 host.Parent=workspace
 Debris:AddItem(host,3.6)

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

 ------------------------------------------------------------------ 1. windup
 playSound(host,FX.Sounds.Whoosh)
 local ring=disc(workspace,anchor*CFrame.new(0,.3,0),palette.glow,radius*2.6,.3,.55)
 TweenService:Create(ring,TweenInfo.new(.5,Enum.EasingStyle.Quart,Enum.EasingDirection.In),
   {Size=Vector3.new(.3,radius*.5,radius*.5),Transparency=.2}):Play()
 Debris:AddItem(ring,.7)
 TweenService:Create(light,TweenInfo.new(.5,Enum.EasingStyle.Quart,Enum.EasingDirection.In),
   {Brightness=3}):Play()
 gather:Emit(22)
 task.wait(.34)

 ------------------------------------------------------------------ 2. arrival
 -- the bright copy snaps into existence overhead, then flows down
 local ghost
 if opts.ghostSource then
  ghost=buildGhost(opts.ghostSource,palette.ghost)
  ghost:PivotTo(anchor*CFrame.new(0,rise,0))
  ghost.Parent=workspace
  Debris:AddItem(ghost,2)
 end

 -- the column it rides down
 local beam=neon(workspace,Vector3.new(rise*1.1,radius*.5,radius*.5),
   anchor*CFrame.new(0,rise*.55,0)*CFrame.Angles(0,0,math.pi/2),palette.core,.72)
 beam.Shape=Enum.PartType.Cylinder
 Debris:AddItem(beam,1.6)

 local DROP=.52
 if ghost then
  local t0=os.clock()
  local conn
  conn=RunService.Heartbeat:Connect(function()
   local a=math.min((os.clock()-t0)/DROP,1)
   local e=1-(1-a)^3                        -- ease out: fast in, settles
   ghost:PivotTo(anchor*CFrame.new(0,rise*(1-e),0))
   if a>=1 then conn:Disconnect() end
  end)
  gather:Emit(10)
 end
 task.wait(DROP)

 ------------------------------------------------------------------ 3. landing
 ReplicatedStorage.UpgradeShake:FireAllClients({
  position=anchor.Position,
  strength=math.clamp(radius/32,.55,1),
  flash=true,
  tint=palette.glow,
 })
 local newModel=opts.swap()
 if ghost then ghost:Destroy() end
 TweenService:Create(beam,TweenInfo.new(.3,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
   {Size=Vector3.new(rise*1.1,radius*.08,radius*.08),Transparency=1}):Play()

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

 shards(workspace,anchor,palette,radius,9)
 dust:Emit(18)
 sparks:Emit(16)

 ------------------------------------------------------------------ 4. reveal
 local revealRim=rim(newModel,palette.core,.05)
 TweenService:Create(revealRim,TweenInfo.new(.75,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),
   {OutlineTransparency=1}):Play()
 Debris:AddItem(revealRim,1)
 task.wait(.2)

 ------------------------------------------------------------------ 5. shine
 local band=neon(workspace,Vector3.new(radius*2.05,.35,radius*2.05),
   anchor*CFrame.new(0,.4,0),palette.core,.3)
 TweenService:Create(band,TweenInfo.new(.45,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
   {CFrame=anchor*CFrame.new(0,height+2,0),Transparency=1}):Play()
 Debris:AddItem(band,.7)
 task.wait(.42)

 ------------------------------------------------------------------ 6. settle
 sparks:Emit(8)
 task.wait(.6)
 return newModel
end

return FX
