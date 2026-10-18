-- TrailerDuoV3: Jen1sen + Jacobo6I9 step out of two Summon Gates by the temple, look around, peek at the temple,
-- an egg drops from the sky into the river, both sprint and fight over it. /trailer opens the version picker.
-- Recording only, runs on the owner's screen only. Test hook: player attribute TrailerGo3.
local Players=game:GetService("Players") local RS=game:GetService("RunService") local SG=game:GetService("StarterGui") local TS=game:GetService("TweenService")
local Config=require(game.ReplicatedStorage:WaitForChild("TrailerConfig"))
local Builder=require(game.ReplicatedStorage:WaitForChild("Portal"):WaitForChild("PortalBuilder"))
local PC=require(game.ReplicatedStorage.Portal.PortalConfig)
local player=Players.LocalPlayer
if not Config.OwnerIds[player.UserId] then return end
local pg=player:WaitForChild("PlayerGui")

local VERSIONS={
 {name="v1 · Rift trailer (solo)",date="12 Oct 2026",run=function() if _G.TrailerStartV1 then _G.TrailerStartV1() end end},
 {name="v2 · Duo river fight",date="13 Oct 2026",run=function() if _G.TrailerDuoStartV2 then _G.TrailerDuoStartV2() end end},
 {name="v3 · Summon gates + egg drop",date="13 Oct 2026",run=function() _G.TrailerDuoStartV3() end},
}
local function picker()
 local old=pg:FindFirstChild("TrailerPicker") if old then old:Destroy() return end
 local g=Instance.new("ScreenGui") g.Name="TrailerPicker" g.ResetOnSpawn=false g.DisplayOrder=1001
 local f=Instance.new("Frame",g) f.AnchorPoint=Vector2.new(.5,.5) f.Position=UDim2.fromScale(.5,.5) f.Size=UDim2.fromOffset(420,70+#VERSIONS*62) f.BackgroundColor3=Color3.fromRGB(29,20,32)
 Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
 local t=Instance.new("TextLabel",f) t.BackgroundTransparency=1 t.Size=UDim2.new(1,0,0,46) t.Font=Enum.Font.FredokaOne t.TextSize=24 t.TextColor3=Color3.fromRGB(255,211,107) t.Text="Pick a trailer"
 for i,v in VERSIONS do local b=Instance.new("TextButton",f) b.Size=UDim2.new(1,-24,0,52) b.Position=UDim2.fromOffset(12,46+(i-1)*62) b.BackgroundColor3=i==#VERSIONS and Color3.fromRGB(200,60,60) or Color3.fromRGB(70,52,80) b.Font=Enum.Font.FredokaOne b.TextSize=19 b.TextColor3=Color3.new(1,1,1) b.Text=v.name.."   ·   "..v.date
  Instance.new("UICorner",b).CornerRadius=UDim.new(0,8) b.Activated:Connect(function() g:Destroy() v.run() end) end
 g.Parent=pg
end
_G.TrailerPicker=picker

local ACTORS={{id=168774222,gateX=-232},{id=353101613,gateX=-200}}
local GATE_Z,GROUND=-48,25.9
local EGG_AT=Vector3.new(-216,24.3,24)
local TEMPLE_LOOK=Vector3.new(-206,42,-82)
local ANIM={walk="rbxassetid://913402848",run="rbxassetid://913376220",idle="rbxassetid://507766388"}
local A=CFrame.Angles local V=Vector3.new local L=CFrame.lookAt
local function lerp(a,b,k) return a+(b-a)*k end local clamp=math.clamp
local function seg(t,a,b) return clamp((t-a)/(b-a),0,1) end
local function ease(x) x=clamp(x,0,1) return x*x*(3-2*x) end
local function yawFacing(dir) return math.atan2(-dir.X,-dir.Z) end

local function build(id,parent)
 local m local ok=pcall(function() m=Players:CreateHumanoidModelFromDescription(Players:GetHumanoidDescriptionFromUserId(id),Enum.HumanoidRigType.R15) end)
 if not m then return nil end
 for _,c in m:GetDescendants() do
  if c:IsA("AnimationConstraint") and c.Attachment0 and c.Attachment1 then local j=Instance.new("Motor6D") j.Name=c.Name j.Part0=c.Attachment0.Parent j.Part1=c.Attachment1.Parent j.C0=c.Attachment0.CFrame j.C1=c.Attachment1.CFrame j.Parent=c.Parent c:Destroy()
  elseif c:IsA("BallSocketConstraint") or c:IsA("HingeConstraint") or c:IsA("BaseScript") then c:Destroy()
  elseif c:IsA("BasePart") then c.CanCollide=false c.CanQuery=false c.CanTouch=false end end
 local h=m:FindFirstChildOfClass("Humanoid") h.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None h.PlatformStand=true
 m.HumanoidRootPart.Anchored=true
 m.Parent=parent
 local an=h:FindFirstChildOfClass("Animator") or Instance.new("Animator",h)
 local tr={} for k,idx in ANIM do local a=Instance.new("Animation") a.AnimationId=idx tr[k]=an:LoadAnimation(a) tr[k].Priority=Enum.AnimationPriority.Action end
 local mot,base,parts={},{},{} for _,j in m:GetDescendants() do if j:IsA("Motor6D") then mot[j.Name]=j base[j.Name]=j.C0 elseif j:IsA("BasePart") or j:IsA("Decal") then table.insert(parts,j) end end
 return {m=m,tr=tr,mot=mot,base=base,parts=parts,off=h.HipHeight+m.HumanoidRootPart.Size.Y/2,cur=nil}
end
local function play(a,name,speed) if a.cur~=name then for k,t in a.tr do if k~=name and t.IsPlaying then t:Stop(0.12) end end if name and a.tr[name] then a.tr[name]:Play(0.12) end a.cur=name end if name and a.tr[name] then a.tr[name]:AdjustSpeed(speed or 1) end end
local function pose(a,p) for n,b in a.base do local r=p and p[n] a.mot[n].C0=r and b*r or b end end
local function tug(k) return {Waist=A(0.35*k,0,0),Neck=A(0.15+0.12*k,0,0),LeftShoulder=A(1.45,0,0.3),RightShoulder=A(1.45,0,-0.3),LeftElbow=A(0.25,0,0),RightElbow=A(0.25,0,0),LeftHip=A(0.65,0,0),LeftKnee=A(-0.9,0,0),RightHip=A(-0.45,0,0),RightKnee=A(-0.3,0,0)} end
local SHOCK={Neck=A(0.2,0,0),LeftShoulder=A(2.3,0,0.25),RightShoulder=A(2.3,0,-0.25),LeftElbow=A(0.5,0,0),RightElbow=A(0.5,0,0),Waist=A(0.12,0,0)}
local DIVE={Waist=A(-0.7,0,0),LeftShoulder=A(2.7,0,0),RightShoulder=A(2.7,0,0),LeftHip=A(-0.5,0,0),RightHip=A(-0.9,0,0)}
local BLOWN={Waist=A(0.6,0,0),Neck=A(0.5,0,0),LeftShoulder=A(0.6,0,-1.7),RightShoulder=A(0.6,0,1.7),LeftHip=A(0.7,0,0),RightHip=A(0.7,0,0),LeftKnee=A(-0.9,0,0),RightKnee=A(-0.9,0,0)}

local running=false
function _G.TrailerDuoStartV3()
 if running then return end running=true
 local restore={}
 local fx=Instance.new("Folder") fx.Name="TrailerDuoFX" fx.Parent=workspace
 local status=Instance.new("ScreenGui") status.Name="TrailerDuoStatus" status.DisplayOrder=1000 status.ResetOnSpawn=false
 local sl=Instance.new("TextLabel",status) sl.AnchorPoint=Vector2.new(.5,0) sl.Position=UDim2.new(.5,0,0,70) sl.Size=UDim2.fromOffset(460,40) sl.BackgroundColor3=Color3.fromRGB(29,20,32) sl.TextColor3=Color3.new(1,1,1) sl.Font=Enum.Font.FredokaOne sl.TextSize=20 sl.Text="Loading actors…" status.Parent=pg
 -- gates (local only; PortalClient draws the vortex because of the tag)
 local gates={}
 for i,info in ACTORS do local base=L(V(info.gateX,GROUND,GATE_Z),V(info.gateX,GROUND,GATE_Z+10)) gates[i]=Builder.Build(base,fx) gates[i]:SetAttribute("SurgeLevel",0) end
 local actors={} for i,info in ACTORS do local a=build(info.id,fx) if a then a.info=info a.side=i==1 and -1 or 1 a.gate=gates[i] a.m.Parent=fx actors[i]=a end end
 -- egg
 local egg=game.ReplicatedStorage.GameMenu.EggPreviews:FindFirstChild("MenuEgg_Pirate"):Clone()
 for _,p in egg:GetDescendants() do if p:IsA("BasePart") then p.Anchored=true p.CanCollide=false end end
 local _,es=egg:GetBoundingBox() egg:ScaleTo(egg:GetScale()*4/es.Y) local ecf,esz=egg:GetBoundingBox() egg.WorldPivot=CFrame.new(ecf.Position-V(0,esz.Y/2,0)) egg.Parent=fx
 local glow=Instance.new("Highlight",egg) glow.FillColor=Color3.fromRGB(255,240,180) glow.FillTransparency=1 glow.OutlineTransparency=1
 local eggFx=Instance.new("Part",fx) eggFx.Size=V(1,1,1) eggFx.Transparency=1 eggFx.Anchored=true eggFx.CanCollide=false eggFx.CFrame=CFrame.new(EGG_AT)
 local splashAt=Instance.new("Attachment",eggFx)
 local spray=Instance.new("ParticleEmitter",splashAt) spray.Texture="rbxasset://textures/particles/sparkles_main.dds" spray.Rate=0 spray.Speed=NumberRange.new(14,24) spray.Lifetime=NumberRange.new(0.5,0.9) spray.SpreadAngle=Vector2.new(70,70) spray.Color=ColorSequence.new(Color3.fromRGB(200,235,255)) spray.LightEmission=0.6 spray.Size=NumberSequence.new(0.8,0) spray.Acceleration=V(0,-30,0)
 local sparks=Instance.new("ParticleEmitter",splashAt) sparks.Texture="rbxasset://textures/particles/sparkles_main.dds" sparks.Rate=0 sparks.Speed=NumberRange.new(10,22) sparks.Lifetime=NumberRange.new(0.6,1.1) sparks.SpreadAngle=Vector2.new(180,180) sparks.Color=ColorSequence.new(Color3.fromRGB(255,220,120)) sparks.LightEmission=1 sparks.Size=NumberSequence.new(0.9,0)
 local trail=Instance.new("Part",fx) trail.Size=V(0.5,0.5,0.5) trail.Transparency=1 trail.Anchored=true trail.CanCollide=false
 local ta=Instance.new("Attachment",trail) local tail=Instance.new("ParticleEmitter",ta) tail.Texture="rbxasset://textures/particles/sparkles_main.dds" tail.Rate=0 tail.Speed=NumberRange.new(1,3) tail.Lifetime=NumberRange.new(0.4,0.8) tail.Color=ColorSequence.new(Color3.fromRGB(255,200,90)) tail.LightEmission=1 tail.Size=NumberSequence.new(0.7,0) tail.SpreadAngle=Vector2.new(180,180)
 local flashPart=Instance.new("Part",fx) flashPart.Shape=Enum.PartType.Ball flashPart.Material=Enum.Material.Neon flashPart.Color=Color3.new(1,1,1) flashPart.Anchored=true flashPart.CanCollide=false flashPart.Transparency=1 flashPart.Size=V(1,1,1) flashPart.CFrame=CFrame.new(EGG_AT+V(0,2,0))
 for i=3,1,-1 do sl.Text="Trailer v3 starts in "..i.." — start recording" task.wait(1) end
 status:Destroy()
 -- hide UI + players
 local white=Instance.new("ScreenGui") white.Name="TrailerDuoCard" white.IgnoreGuiInset=true white.DisplayOrder=1002
 local wf=Instance.new("Frame",white) wf.Size=UDim2.fromScale(1,1) wf.BackgroundColor3=Color3.new(1,1,1) wf.BackgroundTransparency=1 wf.BorderSizePixel=0
 local function txt(t,y,h,c) local l=Instance.new("TextLabel",wf) l.BackgroundTransparency=1 l.AnchorPoint=Vector2.new(.5,.5) l.Position=UDim2.fromScale(.5,y) l.Size=UDim2.fromScale(.9,h) l.TextScaled=true l.Font=Enum.Font.FredokaOne l.Text=t l.TextColor3=c l.TextTransparency=1 local s=Instance.new("UIStroke",l) s.Thickness=4 s.Color=Color3.fromRGB(40,24,18) s.Transparency=1 return l,s end
 local t1,s1=txt("HATCH AN ANIME",.44,.12,Color3.fromRGB(255,190,40)) local t2,s2=txt("OUT NOW",.58,.09,Color3.fromRGB(235,60,50))
 white.Parent=pg
 for _,g in pg:GetChildren() do if g:IsA("ScreenGui") and g~=white and g.Enabled then g.Enabled=false table.insert(restore,function() g.Enabled=true end) end end
 pcall(SG.SetCoreGuiEnabled,SG,Enum.CoreGuiType.All,false) table.insert(restore,function() pcall(SG.SetCoreGuiEnabled,SG,Enum.CoreGuiType.All,true) end)
 for _,d in workspace:GetDescendants() do if d:IsA("BillboardGui") and d.Enabled and not d:IsDescendantOf(fx) then d.Enabled=false table.insert(restore,function() d.Enabled=true end) end end
 local hidden={} for _,p in Players:GetPlayers() do if p.Character then for _,d in p.Character:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then table.insert(hidden,d) end end end end
 local cam=workspace.CurrentCamera local ct,fov0=cam.CameraType,cam.FieldOfView cam.CameraType=Enum.CameraType.Scriptable
 local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude rp.FilterDescendantsInstances={fx} rp.IgnoreWater=false
 local function ground(p,gateX) if p.Z<-40.5 and gateX and math.abs(p.X-gateX)<8.5 then return GROUND+PC.GroundY end local r=workspace:Raycast(V(p.X,60,p.Z),V(0,-100,0),rp) return r and r.Position.Y or GROUND end
 for i,a in actors do a.walkOut=V(a.info.gateX,GROUND+PC.GroundY,GATE_Z+PC.WalkOut) a.startPos=V(a.info.gateX,GROUND+PC.GroundY,GATE_Z-PC.StartBehind)
  a.grab=V(EGG_AT.X+a.side*3.6,EGG_AT.Y,EGG_AT.Z-2) a.surf=a.gate:FindFirstChild("Surface") a.crossed=false end
 local yawRiver=yawFacing(V(0,0,1)) local yawTemple=yawFacing(V(0,0,-1))
 local bbOff={} local lastShot,camCF=-1,L(V(-216,30,-22),V(-216,31,-48))
 local t0=os.clock() local shakeAmt=0
 local conn conn=RS.RenderStepped:Connect(function(dt)
  local t=os.clock()-t0 fx:SetAttribute("T",t)
  for _,d in hidden do d.LocalTransparencyModifier=1 end
  cam.CameraType=Enum.CameraType.Scriptable
  for _,fn in {"WaterfallEggs","LocalRiverEggs"} do local we=workspace:FindFirstChild(fn) if we then for _,d in we:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier=1 elseif d:IsA("BillboardGui") then d.Enabled=false end end end end
  for _,g in pg:GetChildren() do if g:IsA("ScreenGui") and g~=white and g.Enabled then g.Enabled=false table.insert(restore,function() g.Enabled=true end) end end
  for _,g in pg:GetDescendants() do if g:IsA("BillboardGui") and g.Enabled then g.Enabled=false if not bbOff[g] then bbOff[g]=true table.insert(restore,function() if g.Parent then g.Enabled=true end end) end end end
  -- gates surge
  local surge=ease(seg(t,0,0.8))*(1-ease(seg(t,2.6,3.6)))
  for _,g in gates do g:SetAttribute("SurgeLevel",surge) end
  -- egg
  local ey local eggVis=t>=5.3
  if t<5.3 then ey=80 elseif t<6.3 then ey=lerp(60,0,seg(t,5.3,6.3)^2) else ey=0 end
  local tugK=seg(t,9.4,13.3) local shake=t>9.4 and t<13.4 and (0.03+0.15*tugK) or 0
  local nudge=t>9.4 and t<13.4 and math.sin(t*7)*0.45 or 0
  local bob=t>6.3 and t<13.4 and -0.6+0.15*math.sin(t*3) or 0
  if eggVis and t<13.4 then egg:PivotTo(CFrame.new(EGG_AT+V(nudge,ey+bob,0))*A(math.sin(t*37)*shake,t<6.3 and t*4 or 0,math.cos(t*31)*shake))
  elseif t>=13.4 then egg:PivotTo(CFrame.new(0,-500,0)) else egg:PivotTo(CFrame.new(0,-500,0)) end
  if t>=5.3 and t<6.3 then trail.CFrame=CFrame.new(EGG_AT+V(0,ey+2,0)) tail:Emit(3) end
  if t>=6.3 and not fx:GetAttribute("splash") then fx:SetAttribute("splash",true) spray:Emit(60) shakeAmt=0.6
   local ring=Instance.new("Part",fx) ring.Shape=Enum.PartType.Cylinder ring.Material=Enum.Material.Neon ring.Color=Color3.fromRGB(220,245,255) ring.Anchored=true ring.CanCollide=false ring.Size=V(0.2,2,2) ring.CFrame=CFrame.new(EGG_AT+V(0,0.1,0))*A(0,0,math.pi/2) ring.Transparency=0.2
   TS:Create(ring,TweenInfo.new(0.7,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{Size=V(0.2,16,16),Transparency=1}):Play() end
  glow.FillTransparency=1-0.35*tugK glow.OutlineTransparency=1-0.9*tugK glow.OutlineColor=Color3.fromRGB(255,220,120)
  if t>=13.4 and not fx:GetAttribute("burst") then fx:SetAttribute("burst",true) sparks:Emit(80) shakeAmt=0.9 flashPart.Transparency=0 TS:Create(flashPart,TweenInfo.new(0.35,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Size=V(18,18,18),Transparency=0.4}):Play() end
  -- actors
  for i,a in actors do local gx=a.info.gateX
   local pos,yaw,anim,spd,p=a.walkOut,yawRiver,"idle",1,nil
   local vis=true
   if t<0.8 then pos=a.startPos vis=false
   elseif t<2.6 then local u=seg(t,0.8,2.6) local along=u<0.85 and u or 0.85+(1-(1-(u-0.85)/0.15)^2)*0.15 pos=a.startPos:Lerp(a.walkOut,along) anim="walk" spd=1.15
   elseif t<3.6 then p={Neck=A(0.02,math.sin((t-2.6)*5.5+i*1.3)*0.75,0),Waist=A(0,math.sin((t-2.6)*5.5+i*1.3)*0.2,0)}
   elseif t<4.3 then yaw=lerp(yawRiver,yawTemple,ease(seg(t,3.6,4.1))) p={Neck=A(0.35*seg(t,4.0,4.3),0,0)}
   elseif t<5.0 then yaw=yawTemple p={Neck=A(0.4,0.15*math.sin((t-4.3)*4),0)}
   elseif t<5.9 then yaw=lerp(yawTemple,yawRiver,ease(seg(t,5.0,5.45)))
   elseif t<6.5 then p=SHOCK
   elseif t<9.0 then local k=seg(t,6.5,9.0) pos=a.walkOut:Lerp(a.grab,k^1.15) pos=V(pos.X,ground(pos,gx),pos.Z) yaw=yawFacing(a.grab-a.walkOut) anim="run" spd=1.5
   elseif t<9.4 then pos=a.grab+V(0,0.35,0) yaw=yawFacing(V(-a.side,0,0)) p=DIVE anim=nil
   elseif t<13.4 then local k=math.sin(t*7+i*math.pi) pos=a.grab+V(a.side*0.45*k,0,0) yaw=yawFacing(V(-a.side,0,0)) p=tug(k) anim=nil
   else local k=seg(t,13.4,14.0) pos=a.grab+V(a.side*5*k,1.4*math.sin(k*math.pi),0) yaw=yawFacing(V(-a.side,0,0)) p=BLOWN anim=nil end
   play(a,anim,spd) pose(a,p) a.m:SetAttribute("Anim",anim or "pose")
   a.m.HumanoidRootPart.CFrame=CFrame.new(pos+V(0,a.off,0))*A(0,yaw,0)
   -- gate crossing fade
   if not vis then for _,pt in a.parts do pt.LocalTransparencyModifier=1 end
   elseif t<3.6 then local n,o=a.surf.CFrame.LookVector,a.surf.Position
    for _,pt in a.parts do if pt:IsA("BasePart") then local dd=(pt.Position-o):Dot(n) pt.LocalTransparencyModifier=clamp(0.5-dd/PC.FadeBand,0,1) else pt.LocalTransparencyModifier=0 end end
    local chest=a.m:FindFirstChild("UpperTorso") if chest and not a.crossed and (chest.Position-o):Dot(n)>0 then a.crossed=true if _G.PortalRipple then _G.PortalRipple(a.gate,chest.Position) end end
   else for _,pt in a.parts do pt.LocalTransparencyModifier=0 end end
   a.head=a.m.Head.Position
  end
  -- camera
  local jen,jac=actors[1].head,actors[2].head local mid=(jen+jac)/2 local e=EGG_AT+V(0,ey+2,0)
  local target,fv,sid
  if t<0.8 then sid=0 target=L(V(-216,31,-14+3*seg(t,0,0.8)),V(-216,34,-50)) fv=66
  elseif t<2.6 then sid=1 target=L(V(-216,29,-24+2*seg(t,0.8,2.6)),mid) fv=64
  elseif t<3.1 then sid=2 target=L(jen+V(0,0.3,5.5),jen) fv=40
  elseif t<3.6 then sid=3 target=L(jac+V(0,0.3,5.5),jac) fv=40
  elseif t<5.0 then sid=4 local k=ease(seg(t,3.75,4.35)) target=L(V(-216,29+4*k,-30),mid:Lerp(TEMPLE_LOOK,k)) fv=62
  elseif t<5.9 then sid=5 target=L(V(-216,29,-26),mid+V(0,0.5,0)) fv=60
  elseif t<6.6 then sid=6 target=L(V(-236,30,6),EGG_AT+V(0,ey*0.6+2,0)) fv=50
  elseif t<9.0 then sid=7 target=L(V(mid.X,28.5,mid.Z+16),mid+V(0,1,0)) fv=62
  elseif t<13.4 then local cut=math.floor((t-9.0)/1.1)%3 sid=8+math.floor((t-9.0)/1.1)
   if cut==0 then target=L(EGG_AT+V(0,4.5,-11),EGG_AT+V(0,2,0)) fv=50 elseif cut==1 then target=L(jen+V(4,0.3,-2.5),jen) fv=42 else target=L(jac+V(-4,0.3,-2.5),jac) fv=42 end
  else sid=99 target=L(EGG_AT+V(0,2.5,-9),EGG_AT+V(0,1.5,0)) fv=52 end
  if sid~=lastShot then lastShot=sid camCF=target else camCF=camCF:Lerp(target,0.14) end
  shakeAmt=math.max(0,shakeAmt-dt*1.6) local sh=shakeAmt+shake*2.2
  cam.CFrame=camCF*CFrame.new(math.noise(t*22,1)*sh,math.noise(t*22,5)*sh,0)*A(0,0,math.noise(t*18,9)*sh*0.05) cam.FieldOfView=lerp(cam.FieldOfView,fv,0.2)
  -- white card
  wf.BackgroundTransparency=1-seg(t,13.5,13.9) local tt=1-seg(t,14.2,14.7) t1.TextTransparency=tt s1.Transparency=tt local t2t=1-seg(t,14.6,15.1) t2.TextTransparency=t2t s2.Transparency=t2t
  if t>18 then conn:Disconnect() fx:Destroy() white:Destroy() for _,d in hidden do if d.Parent then d.LocalTransparencyModifier=0 end end
   for _,fn in {"WaterfallEggs","LocalRiverEggs"} do local we2=workspace:FindFirstChild(fn) if we2 then for _,d in we2:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier=0 elseif d:IsA("BillboardGui") then d.Enabled=true end end end end
   for i=#restore,1,-1 do restore[i]() end cam.CameraType=ct cam.FieldOfView=fov0 running=false end
 end)
end
player:GetAttributeChangedSignal("TrailerGo3"):Connect(function() if player:GetAttribute("TrailerGo3") then _G.TrailerDuoStartV3() end end)
