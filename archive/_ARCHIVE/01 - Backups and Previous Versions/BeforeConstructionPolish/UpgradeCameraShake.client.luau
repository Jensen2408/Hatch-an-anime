local Collection=game:GetService("CollectionService")
local TweenService=game:GetService("TweenService")
local RunService=game:GetService("RunService")
local Debris=game:GetService("Debris")
local player=game.Players.LocalPlayer
local active={}
local trauma=0
local lastOffset=CFrame.identity
-- Undo only our previous offset before Roblox updates its camera.
RunService:BindToRenderStep("ConstructionShakeReset",Enum.RenderPriority.Camera.Value-1,function()
 local camera=workspace.CurrentCamera
 if camera then camera.CFrame=camera.CFrame*lastOffset:Inverse() end
 lastOffset=CFrame.identity
end)
RunService:BindToRenderStep("ConstructionShake",Enum.RenderPriority.Camera.Value+1,function(dt)
 trauma=math.max(0,trauma-dt*.9)
 local camera=workspace.CurrentCamera
 if not camera or trauma<=0 then return end
 local t=os.clock()*19
 local amount=trauma*trauma
 lastOffset=CFrame.new(math.noise(t,0)*.12*amount,math.noise(0,t)*.09*amount,0)*CFrame.Angles(0,0,math.noise(t,t)*math.rad(.4)*amount)
 camera.CFrame=camera.CFrame*lastOffset
end)
local function play(model)
 if active[model] or not model:IsDescendantOf(workspace) then return end
 local start=model:GetAttribute("BuildStart")
 if not start or workspace:GetServerTimeNow()>start+3.4 then return end
 local pivot=model:GetPivot()
 -- During construction the model pivot can be below ground; use its authored anchor.
 local ground=model:GetAttribute("BuildGround")
 local center=Vector3.new(pivot.X,ground+.06,pivot.Z)
 local camera=workspace.CurrentCamera
 if not camera or (camera.CFrame.Position-center).Magnitude>200 then return end
 active[model]=true
 local owner=model:GetAttribute("BuildOwner")==player.UserId
 local radius=math.clamp(model:GetAttribute("BuildRadius") or 8,4,34)
 local host=Instance.new("Part");host.Name="ConstructionGroundFX";host.Anchored=true;host.Transparency=1;host.CanCollide=false;host.CanTouch=false;host.CanQuery=false;host.Size=Vector3.one;host.Position=center;host.Parent=workspace
 Debris:AddItem(host,6.5)
 local emitters={}
 for i=1,20 do
  local angle=i/20*math.pi*2
  local dir=Vector3.new(math.cos(angle),0,math.sin(angle))
  local a=Instance.new("Attachment");a.CFrame=CFrame.lookAt(dir*radius*1.02,dir*(radius*1.02+1)+Vector3.new(0,.15,0));a.Parent=host
  local dust=Instance.new("ParticleEmitter");dust.Name="GroundDust";dust.Texture="rbxasset://textures/particles/smoke_main.dds";dust.Rate=7;dust.EmissionDirection=Enum.NormalId.Front;dust.Speed=NumberRange.new(4,8);dust.Drag=2;dust.Acceleration=Vector3.new(0,.4,0);dust.SpreadAngle=Vector2.new(22,35);dust.Lifetime=NumberRange.new(1,1.8);dust.Rotation=NumberRange.new(0,360);dust.RotSpeed=NumberRange.new(-18,18);dust.Color=ColorSequence.new(Color3.fromRGB(170,154,130),Color3.fromRGB(204,191,165));dust.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.6),NumberSequenceKeypoint.new(.4,2.5),NumberSequenceKeypoint.new(1,3.6)});dust.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.7),NumberSequenceKeypoint.new(.2,.4),NumberSequenceKeypoint.new(1,1)});dust.Parent=a
  local grit=Instance.new("ParticleEmitter");grit.Name="TinyDebris";grit.Texture="rbxasset://textures/particles/sparkles_main.dds";grit.Rate=0;grit.LightEmission=0;grit.Color=ColorSequence.new(Color3.fromRGB(102,92,73));grit.Size=NumberSequence.new(.09);grit.Speed=NumberRange.new(2,4);grit.Acceleration=Vector3.new(0,-18,0);grit.Lifetime=NumberRange.new(.25,.5);grit.SpreadAngle=Vector2.new(55,55);grit.Parent=a
  table.insert(emitters,{dust,grit})
 end
 local function pulse(strength,final)
  if not host.Parent then return end
  for _,pair in emitters do pair[1]:Emit(final and 5 or 2);pair[2]:Emit(final and 2 or 1) end
  if owner then trauma=math.min(.65,trauma+strength) end
  local sound=Instance.new("Sound");sound.SoundId="rbxasset://sounds/action_footsteps_plastic.mp3";sound.Volume=final and .26 or .12;sound.PlaybackSpeed=final and .42 or .58;sound.RollOffMinDistance=8;sound.RollOffMaxDistance=100;sound.Parent=host
  local eq=Instance.new("EqualizerSoundEffect");eq.LowGain=5;eq.MidGain=-5;eq.HighGain=-18;eq.Parent=sound
  sound:Play();Debris:AddItem(sound,1.5)
  -- Short, local ground ripple: never move the actual floor or standing players.
  if final then
   local ring=Instance.new("Part");ring.Name="GroundPressureRing";ring.Shape=Enum.PartType.Cylinder;ring.Material=Enum.Material.SmoothPlastic;ring.Color=Color3.fromRGB(201,189,159);ring.Transparency=.88;ring.Size=Vector3.new(.025,radius*1.4,radius*1.4);ring.CFrame=CFrame.new(center)*CFrame.Angles(0,0,math.pi/2);ring.Anchored=true;ring.CanCollide=false;ring.CanTouch=false;ring.CanQuery=false;ring.CastShadow=false;ring.Parent=host
   TweenService:Create(ring,TweenInfo.new(.65,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=Vector3.new(.025,radius*2.35,radius*2.35),Transparency=1}):Play();Debris:AddItem(ring,.7)
  end
 end
 local function schedule(at,fn)
  task.delay(math.max(0,start+at-workspace:GetServerTimeNow()),function() if model.Parent and host.Parent then fn() end end)
 end
 schedule(0,function() pulse(.28,false) end)
 schedule(1.25,function() pulse(.15,false) end)
 schedule(1.85,function() pulse(.12,false) end)
 schedule(2.5,function() pulse(.12,false) end)
 schedule(3.05,function()
  for _,pair in emitters do pair[1].Rate=0 end
  pulse(.38,true)
 end)
 task.delay(5.5,function() active[model]=nil;if host.Parent then host:Destroy() end end)
end
Collection:GetInstanceAddedSignal("UpgradeAssembly"):Connect(function(m) task.spawn(play,m) end)
for _,m in Collection:GetTagged("UpgradeAssembly") do task.spawn(play,m) end
