
local Collection=game:GetService("CollectionService")
local FX={}
local GOLD=Color3.fromRGB(255,205,90)
function FX.remove(model)
 Collection:RemoveTag(model,"GoldCharacter")
 local old=model:FindFirstChild("GoldFX") if old then old:Destroy()end
end
function FX.apply(model,opts)
 opts=opts or {}
 if not model:IsA("Model")then return nil end
 FX.remove(model)
 local core=model:FindFirstChild("HumanoidRootPart",true)or model:FindFirstChild("Torso",true)or model:FindFirstChildWhichIsA("BasePart",true)
 if not core then return nil end
 local cf,size=model:GetBoundingBox()
 local original={}
 for _,v in ipairs(model:GetDescendants())do if v:IsA("BasePart")then table.insert(original,v)end end
 local folder=Instance.new("Folder")folder.Name="GoldFX"folder.Parent=model
 local shells=Instance.new("Folder")shells.Name="ShineShells"shells.Parent=folder
 for _,p in ipairs(original)do
  if p.Name~="HumanoidRootPart"and p.Transparency<1 then
   local sa=p:FindFirstChildWhichIsA("SurfaceAppearance")
   -- Keep original SurfaceAppearance albedo and cavity normals intact.
   p.Material=Enum.Material.Metal p.Reflectance=opts.Reflectance or .3
   if p:IsA("MeshPart")then
    local shell=p:Clone()shell:ClearAllChildren()shell.Name="Shine_"..p.Name
    shell.Size=p.Size*1.015 shell.TextureID=""shell.Material=Enum.Material.ForceField
    shell.Color=Color3.fromRGB(255,236,170)shell.Transparency=.55
    shell.Anchored=false shell.Massless=true shell.CanCollide=false shell.CanTouch=false shell.CanQuery=false shell.CastShadow=false shell.Parent=shells
    local w=Instance.new("WeldConstraint")w.Part0=p w.Part1=shell w.Parent=shell
   end
  end
 end
 local emitter=Instance.new("Part")emitter.Name="GoldFX_Emitter"emitter.Size=size*Vector3.new(.9,.95,.9)emitter.CFrame=cf emitter.Transparency=1 emitter.Anchored=false emitter.Massless=true emitter.CanCollide=false emitter.CanTouch=false emitter.CanQuery=false emitter.CastShadow=false emitter.Parent=folder
 local weld=Instance.new("WeldConstraint")weld.Part0=core weld.Part1=emitter weld.Parent=emitter
 local function particle(name,rate)
  local e=Instance.new("ParticleEmitter")e.Name=name e.Texture="rbxasset://textures/particles/sparkles_main.dds"e.Color=ColorSequence.new(GOLD)
  e.Shape=Enum.ParticleEmitterShape.Box e.ShapeStyle=Enum.ParticleEmitterShapeStyle.Volume e.LightEmission=1 e.LightInfluence=0 e.Brightness=3 e.Rate=rate
  e.Parent=emitter return e
 end
 local stars=particle("Sparkles",opts.Sparkles or 9)stars:SetAttribute("BaseRate",stars.Rate)
 stars.Lifetime=NumberRange.new(.5,.9)stars.Speed=NumberRange.new(0)stars.Rotation=NumberRange.new(0,360)stars.RotSpeed=NumberRange.new(-90,90)
 stars.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.35,.45),NumberSequenceKeypoint.new(1,0)})
 local dust=particle("GoldSpecks",opts.Specks or 6)dust:SetAttribute("BaseRate",dust.Rate)dust.Brightness=2 dust.Lifetime=NumberRange.new(2,3)dust.Speed=NumberRange.new(.6,1.2)dust.SpreadAngle=Vector2.new(15,15)
 dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.5,.12),NumberSequenceKeypoint.new(1,0)})dust.Transparency=NumberSequence.new(.2,1)
 local light=Instance.new("PointLight")light.Name="WarmLight"light.Color=GOLD light.Brightness=1.1 light.Range=9 light.Shadows=false light.Parent=emitter
 local ring=Instance.new("Part")ring.Name="GroundRing"ring.Shape=Enum.PartType.Cylinder ring.Size=Vector3.new(.05,size.X*1.25,size.X*1.25)
 ring.CFrame=CFrame.new(cf.Position-Vector3.new(0,size.Y*.5-.025,0))*CFrame.Angles(0,0,math.pi*.5)
 ring.Transparency=1 ring.Anchored=false ring.Massless=true ring.CanCollide=false ring.CanTouch=false ring.CanQuery=false ring.CastShadow=false ring.Parent=folder
 local rw=Instance.new("WeldConstraint")rw.Part0=core rw.Part1=ring rw.Parent=ring
 local ripple=Instance.new("ParticleEmitter")ripple.Name="RingBurst"ripple.Texture="rbxasset://textures/particles/sparkles_main.dds"ripple.Shape=Enum.ParticleEmitterShape.Disc ripple.ShapeStyle=Enum.ParticleEmitterShapeStyle.Surface
 pcall(function()ripple.ShapeInOut=Enum.ParticleEmitterShapeInOut.Outward end)
 ripple.Orientation=Enum.ParticleOrientation.VelocityPerpendicular ripple.Rate=0 ripple.Color=ColorSequence.new(GOLD)ripple.LightEmission=1 ripple.Brightness=3 ripple.Speed=NumberRange.new(1,2)ripple.Lifetime=NumberRange.new(.5,.9)
 ripple.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.12),NumberSequenceKeypoint.new(.3,.18),NumberSequenceKeypoint.new(1,0)})ripple.Transparency=NumberSequence.new(.1,1)ripple.Parent=ring
 local highlight=Instance.new("Highlight")highlight.Name="GoldShine"highlight.Adornee=model highlight.FillColor=Color3.fromRGB(255,236,170)highlight.FillTransparency=1 highlight.OutlineTransparency=1 highlight.DepthMode=Enum.HighlightDepthMode.Occluded highlight.Parent=folder
 model:SetAttribute("Gold",true)model:SetAttribute("GoldFXPhase",opts.Phase or math.random()*3.2)
 Collection:AddTag(model,"GoldCharacter")
 return folder
end
return FX
