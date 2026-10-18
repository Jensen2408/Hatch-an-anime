-- Upgrade reveal: the new building assembles itself. Parts drop into place
-- bottom to top in bands, each band landing with a puff, the whole structure
-- glowing while it builds. Roughly 1.8s.
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local FX={}

FX.Palettes={
 Temple ={core=Color3.fromRGB(255,243,206),glow=Color3.fromRGB(255,196,84),
          spark=Color3.fromRGB(255,226,150),dust=Color3.fromRGB(236,224,198)},
 Chamber={core=Color3.fromRGB(246,255,220),glow=Color3.fromRGB(214,238,160),
          spark=Color3.fromRGB(226,246,178),dust=Color3.fromRGB(230,235,212)},
}

FX.Sounds={
 Whoosh={id="rbxasset://sounds/action_falling.mp3",volume=.24,speed=1.2,pitchTo=2.2,cut=.4},
}

-- ponytail: only the top 220 parts animate, the rest snap in. Raise if the
-- base of a big temple ever reads as popping in.
local ASSEMBLE_CAP=220
local BANDS=11
local STAGGER=.078
local FALL=.34

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

local function neon(parent,size,cf,color,transparency)
 local p=Instance.new("Part")
 p.Anchored=true p.CanCollide=false p.CanQuery=false p.CanTouch=false p.CastShadow=false
 p.Material=Enum.Material.Neon p.Color=color p.Size=size p.CFrame=cf
 p.Transparency=transparency
 p.Parent=parent
 return p
end

local function disc(parent,groundCF,color,diameter,thickness,transparency)
 local d=neon(parent,Vector3.new(thickness,diameter,diameter),
   groundCF*CFrame.Angles(0,0,math.pi/2),color,transparency)
 d.Shape=Enum.PartType.Cylinder
 return d
end

-- Dust kicked out sideways where a course of blocks lands.
local function puff(cf,palette,spread,amount)
 local h=neon(workspace,Vector3.new(1,1,1),cf,palette.dust,1)
 h.Material=Enum.Material.SmoothPlastic
 local e=Instance.new("ParticleEmitter")
 e.Color=ColorSequence.new(palette.dust)
 e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.55),
   NumberSequenceKeypoint.new(.3,.68),NumberSequenceKeypoint.new(1,1)})
 e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,spread*.16),
   NumberSequenceKeypoint.new(1,spread*.5)})
 e.Lifetime=NumberRange.new(.35,.6)
 e.Speed=NumberRange.new(spread*.35,spread*.7)
 e.SpreadAngle=Vector2.new(85,85)
 e.Drag=6
 e.Rotation=NumberRange.new(0,360)
 e.RotSpeed=NumberRange.new(-60,60)
 e.LightEmission=.1
 e.Enabled=false
 e.Parent=h
 e:Emit(amount)
 Debris:AddItem(h,1.4)
end

-- Displace every part upward and invisible, then let them fall back into
-- place bottom-to-top. Returns how long the whole build takes.
local function assemble(model,palette)
 local parts={}
 for _,d in model:GetDescendants() do
  if d:IsA("BasePart") then parts[#parts+1]=d end
 end
 if #parts==0 then return 0 end

 -- keep the top of the structure: that is the new layer, and the part worth watching
 table.sort(parts,function(a,b) return a.Position.Y>b.Position.Y end)
 local animated={}
 for i=1,math.min(#parts,ASSEMBLE_CAP) do animated[i]=parts[i] end
 table.sort(animated,function(a,b) return a.Position.Y<b.Position.Y end)

 local minY=animated[1].Position.Y
 local maxY=animated[#animated].Position.Y
 local span=math.max(maxY-minY,1)
 local rise=math.clamp(span*.3,5,16)

 for _,p in animated do
  local band=math.floor(((p.Position.Y-minY)/span)*(BANDS-1)+.5)
  local finalCF=p.CFrame
  local finalT=p.Transparency
  local wasAnchored=p.Anchored
  p.Anchored=true
  p.CFrame=finalCF+Vector3.new(0,rise,0)
  p.Transparency=1
  task.delay(band*STAGGER,function()
   if not p.Parent then return end
   TweenService:Create(p,TweenInfo.new(FALL,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
     {CFrame=finalCF,Transparency=finalT}):Play()
   task.delay(FALL,function()
    if p.Parent then p.CFrame=finalCF p.Anchored=wasAnchored end
   end)
  end)
 end
 return (BANDS-1)*STAGGER+FALL,minY,maxY
end

function FX.Play(opts)
 local palette=opts.palette or FX.Palettes.Temple
 local anchor=opts.anchor
 local radius=math.max(opts.radius,6)
 local height=math.max(opts.height,6)

 local host=Instance.new("Part")
 host.Name="UpgradeFX" host.Anchored=true host.CanCollide=false
 host.CanQuery=false host.CanTouch=false host.CastShadow=false
 host.Transparency=1 host.Size=Vector3.new(radius*1.6,1,radius*1.6)
 host.CFrame=anchor*CFrame.new(0,1,0)
 host.Parent=workspace
 Debris:AddItem(host,3.6)

 local light=Instance.new("PointLight")
 light.Color=palette.glow light.Range=math.min(radius*1.9,60)
 light.Brightness=0 light.Shadows=false light.Parent=host

 local sparks=Instance.new("ParticleEmitter")
 sparks.Color=ColorSequence.new(palette.spark)
 sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.05),
   NumberSequenceKeypoint.new(.7,.3),NumberSequenceKeypoint.new(1,1)})
 sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,radius*.05),
   NumberSequenceKeypoint.new(1,0)})
 sparks.Lifetime=NumberRange.new(.6,1.1)
 sparks.Speed=NumberRange.new(radius*.35,radius*.8)
 sparks.SpreadAngle=Vector2.new(60,60)
 sparks.Acceleration=Vector3.new(0,-16,0)
 sparks.Drag=1.8 sparks.LightEmission=1 sparks.LightInfluence=0
 sparks.Enabled=false sparks.Parent=host

 ------------------------------------------------------------------ 1. windup
 playSound(host,FX.Sounds.Whoosh)
 TweenService:Create(light,TweenInfo.new(.3,Enum.EasingStyle.Quart,Enum.EasingDirection.In),
   {Brightness=3}):Play()
 task.wait(.3)

 ------------------------------------------------------------------ 2. swap
 -- a short flash covers the old building leaving; the build itself is the show
 ReplicatedStorage.UpgradeShake:FireAllClients({
  position=anchor.Position,
  strength=math.clamp(radius/32,.5,.85),
  flash=true,
  tint=palette.glow,
 })
 local newModel=opts.swap()
 local duration,minY,maxY=assemble(newModel,palette)

 local glow=Instance.new("Highlight")
 glow.Name="UpgradeReveal" glow.Adornee=newModel
 glow.DepthMode=Enum.HighlightDepthMode.Occluded
 glow.FillColor=palette.core glow.OutlineColor=palette.core
 glow.FillTransparency=.5 glow.OutlineTransparency=.1
 glow.Parent=newModel
 TweenService:Create(glow,TweenInfo.new(duration+.35,Enum.EasingStyle.Sine,Enum.EasingDirection.Out),
   {FillTransparency=1,OutlineTransparency=1}):Play()
 Debris:AddItem(glow,duration+.6)

 light.Brightness=6
 TweenService:Create(light,TweenInfo.new(duration,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),
   {Brightness=0}):Play()

 ------------------------------------------------------------------ 3. courses land
 local span=math.max((maxY or height)-(minY or 0),1)
 task.spawn(function()
  for band=0,BANDS-1 do
   task.wait(band==0 and FALL*.8 or STAGGER)
   local y=(minY or anchor.Y)+span*(band/(BANDS-1))
   local shrink=1-(band/BANDS)*.45
   puff(CFrame.new(anchor.X,y,anchor.Z),palette,radius*shrink,band%2==0 and 7 or 4)
  end
 end)
 task.wait(duration)

 ------------------------------------------------------------------ 4. settle
 local wave=disc(workspace,anchor*CFrame.new(0,.35,0),palette.core,radius*.5,.4,.25)
 TweenService:Create(wave,TweenInfo.new(.5,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
   {Size=Vector3.new(.4,radius*2.6,radius*2.6),Transparency=1}):Play()
 Debris:AddItem(wave,.7)
 sparks:Emit(14)
 task.wait(.45)
 return newModel
end

return FX
