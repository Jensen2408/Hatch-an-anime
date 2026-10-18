-- TrailerDuo (v2): two players drop from a portal, look around, see their temples, fight over a river egg.
-- /trailer opens a picker with every trailer version. Recording only, local only.
local Players=game:GetService("Players") local RS=game:GetService("RunService") local SG=game:GetService("StarterGui")
local Config=require(game.ReplicatedStorage:WaitForChild("TrailerConfig"))
local player=Players.LocalPlayer
if not (Config.OwnerIds[player.UserId]) then return end
local VERSIONS={
 {name="v1 · Rift trailer (solo)", date="12 Oct 2026", run=function() if _G.TrailerStartV1 then _G.TrailerStartV1() end end},
 {name="v2 · Duo river fight", date="13 Oct 2026", run=function() _G.TrailerDuoStartV2() end},
}
local ACTORS={{id=168774222,bank=Vector3.new(-215,25.9,10)},{id=353101613,bank=Vector3.new(-215,25.9,38)}}
local EGG_AT=Vector3.new(-215,24.3,25) local PORTAL=Vector3.new(-215,54,24)
local ANIM={fall="rbxassetid://507767968",idle="rbxassetid://507766388",run="rbxassetid://913376220"}
local A,lerp,clamp=CFrame.Angles,function(a,b,k) return a+(b-a)*k end,math.clamp
local function seg(t,a,b) return clamp((t-a)/(b-a),0,1) end
local function ease(x) x=clamp(x,0,1) return x*x*(3-2*x) end
local pg=player:WaitForChild("PlayerGui")
local running=false
local function picker()
 local old=pg:FindFirstChild("TrailerPicker") if old then old:Destroy() return end
 local g=Instance.new("ScreenGui") g.Name="TrailerPicker" g.ResetOnSpawn=false g.DisplayOrder=1001
 local f=Instance.new("Frame",g) f.AnchorPoint=Vector2.new(.5,.5) f.Position=UDim2.fromScale(.5,.5) f.Size=UDim2.fromOffset(380,70+#VERSIONS*62) f.BackgroundColor3=Color3.fromRGB(29,20,32)
 Instance.new("UICorner",f).CornerRadius=UDim.new(0,10)
 local t=Instance.new("TextLabel",f) t.BackgroundTransparency=1 t.Size=UDim2.new(1,0,0,46) t.Font=Enum.Font.FredokaOne t.TextSize=24 t.TextColor3=Color3.fromRGB(255,211,107) t.Text="Pick a trailer"
 for i,v in VERSIONS do local b=Instance.new("TextButton",f) b.Size=UDim2.new(1,-24,0,52) b.Position=UDim2.fromOffset(12,46+(i-1)*62) b.BackgroundColor3=Color3.fromRGB(70,52,80) b.Font=Enum.Font.FredokaOne b.TextSize=19 b.TextColor3=Color3.new(1,1,1) b.Text=v.name.."   ·   "..v.date
  Instance.new("UICorner",b).CornerRadius=UDim.new(0,8) b.Activated:Connect(function() g:Destroy() v.run() end) end
 g.Parent=pg
end


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
 local a=h:FindFirstChildOfClass("Animator") or Instance.new("Animator",h)
 local tr={} for k,idx in ANIM do local an=Instance.new("Animation") an.AnimationId=idx tr[k]=a:LoadAnimation(an) tr[k].Priority=Enum.AnimationPriority.Action end
 local mot,base={},{} for _,j in m:GetDescendants() do if j:IsA("Motor6D") then mot[j.Name]=j base[j.Name]=j.C0 end end
 return {m=m,tr=tr,mot=mot,base=base,off=h.HipHeight+m.HumanoidRootPart.Size.Y/2,cur=nil}
end
local function play(a,name) if a.cur==name then return end for k,t in a.tr do if k~=name and t.IsPlaying then t:Stop(0.15) end end if name and a.tr[name] then a.tr[name]:Play(0.15) end a.cur=name end
local function pose(a,p) for n,b in a.base do local r=p and p[n] a.mot[n].C0=r and b*r or b end end

function _G.TrailerDuoStartV2()
 if running then return end running=true
 local restore={}
 local fx=Instance.new("Folder",workspace) fx.Name="TrailerDuoFX"
 local status=Instance.new("ScreenGui") status.Name="TrailerDuoStatus" status.DisplayOrder=1000 status.ResetOnSpawn=false
 local sl=Instance.new("TextLabel",status) sl.AnchorPoint=Vector2.new(.5,0) sl.Position=UDim2.new(.5,0,0,70) sl.Size=UDim2.fromOffset(420,40) sl.BackgroundColor3=Color3.fromRGB(29,20,32) sl.TextColor3=Color3.new(1,1,1) sl.Font=Enum.Font.FredokaOne sl.TextSize=20 sl.Text="Loading actors…" status.Parent=pg
 local actors={} for i,info in ACTORS do local a=build(info.id,fx) if a then a.info=info a.side=i==1 and 1 or -1 a.m.Parent=fx actors[i]=a end end
 local egg=game.ReplicatedStorage.GameMenu.EggPreviews:FindFirstChild("MenuEgg_Pirate"):Clone()
 for _,p in egg:GetDescendants() do if p:IsA("BasePart") then p.Anchored=true p.CanCollide=false end end
 local _,es=egg:GetBoundingBox() egg:ScaleTo(egg:GetScale()*4/es.Y) local ecf,esz=egg:GetBoundingBox() egg.WorldPivot=CFrame.new(ecf.Position-Vector3.new(0,esz.Y/2,0)) egg.Parent=fx
 local glow=Instance.new("Highlight",egg) glow.FillColor=Color3.fromRGB(255,240,180) glow.FillTransparency=1 glow.OutlineTransparency=1
 local ring=Instance.new("Part",fx) ring.Shape=Enum.PartType.Cylinder ring.Material=Enum.Material.Neon ring.Color=Color3.fromRGB(170,90,255) ring.Anchored=true ring.CanCollide=false ring.Transparency=1
 local pl=Instance.new("PointLight",ring) pl.Color=Color3.fromRGB(190,120,255) pl.Range=40 pl.Brightness=0
 for i=3,1,-1 do sl.Text="Trailer v2 starts in "..i.." — start recording" task.wait(1) end
 status:Destroy()
 -- hide UI + players
 for _,g in pg:GetChildren() do if g:IsA("ScreenGui") and g.Enabled then g.Enabled=false table.insert(restore,function() g.Enabled=true end) end end
 pcall(SG.SetCoreGuiEnabled,SG,Enum.CoreGuiType.All,false) table.insert(restore,function() pcall(SG.SetCoreGuiEnabled,SG,Enum.CoreGuiType.All,true) end)
 for _,d in pg:GetDescendants() do if d:IsA("BillboardGui") and d.Enabled then d.Enabled=false table.insert(restore,function() d.Enabled=true end) end end
 local we=workspace:FindFirstChild("WaterfallEggs") local hideFolders={we}
 for _,d in workspace:GetDescendants() do if d:IsA("BillboardGui") and d.Enabled then d.Enabled=false table.insert(restore,function() d.Enabled=true end) end end
 local hidden={} for _,f in hideFolders do if f then for _,d in f:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then table.insert(hidden,d) end end end end for _,p in Players:GetPlayers() do if p.Character then for _,d in p.Character:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then table.insert(hidden,d) end end end end
 local cam=workspace.CurrentCamera local ct,fov=cam.CameraType,cam.FieldOfView cam.CameraType=Enum.CameraType.Scriptable
 local white=Instance.new("ScreenGui") white.Name="TrailerDuoCard" white.IgnoreGuiInset=true white.DisplayOrder=1002
 local wf=Instance.new("Frame",white) wf.Size=UDim2.fromScale(1,1) wf.BackgroundColor3=Color3.new(1,1,1) wf.BackgroundTransparency=1
 local function txt(t,y,h,c) local l=Instance.new("TextLabel",wf) l.BackgroundTransparency=1 l.AnchorPoint=Vector2.new(.5,.5) l.Position=UDim2.fromScale(.5,y) l.Size=UDim2.fromScale(.9,h) l.TextScaled=true l.Font=Enum.Font.FredokaOne l.Text=t l.TextColor3=c l.TextTransparency=1 local s=Instance.new("UIStroke",l) s.Thickness=4 s.Color=Color3.fromRGB(40,24,18) s.Transparency=1 return l,s end
 local t1,s1=txt("HATCH AN ANIME",.44,.12,Color3.fromRGB(255,190,40)) local t2,s2=txt("OUT NOW",.58,.09,Color3.fromRGB(235,60,50))
 white.Parent=pg
 local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Exclude rp.FilterDescendantsInstances={fx} rp.IgnoreWater=false
 local function ground(p) local r=workspace:Raycast(Vector3.new(p.X,60,p.Z),Vector3.new(0,-100,0),rp) return r and r.Position.Y or 25.9 end
 for _,a in actors do a.grab=Vector3.new(EGG_AT.X,0,EGG_AT.Z-a.side*3.4) a.grab=Vector3.new(a.grab.X,ground(a.grab),a.grab.Z) end
 local lastShot=-1 local lastShot=-1 local camCF=CFrame.lookAt(PORTAL+Vector3.new(30,-18,0),PORTAL)
 local t0=os.clock() local L=CFrame.lookAt local V=Vector3.new
 local TUG={UpperTorso=A(0.35,0,0),LeftUpperArm=A(1.45,0,0.3),RightUpperArm=A(1.45,0,-0.3),LeftLowerArm=A(0.25,0,0),RightLowerArm=A(0.25,0,0),LeftHip=A(0.7,0,0),LeftKnee=A(-0.9,0,0),RightHip=A(-0.45,0,0),RightKnee=A(-0.35,0,0)}
 local function tug(k) local p={} for n,c in TUG do p[n]=c end p.Waist=A(0.45*k,0,0) p.Neck=A(0.15+0.1*k,0,0) return p end
 local conn conn=RS.RenderStepped:Connect(function()
  local t=os.clock()-t0
  for _,d in hidden do d.LocalTransparencyModifier=1 end
  cam.CameraType=Enum.CameraType.Scriptable
  local we=workspace:FindFirstChild("WaterfallEggs") if we then for _,d in we:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier=1 elseif d:IsA("BillboardGui") then d.Enabled=false end end end
  for _,g in pg:GetChildren() do if g:IsA("ScreenGui") and g~=white and g.Enabled then g.Enabled=false table.insert(restore,function() g.Enabled=true end) end end
  -- portal
  local open=ease(seg(t,0,0.8))*(1-ease(seg(t,2.4,3.0)))
  ring.Size=Vector3.new(0.6,30*open+0.1,30*open+0.1) ring.CFrame=CFrame.new(PORTAL)*A(0,0,math.rad(90))*A(t*2,0,0) ring.Transparency=open>0.02 and 0.15 or 1 pl.Brightness=5*open
  -- egg
  local ey if t<6 then ey=60 elseif t<6.6 then ey=lerp(40,0,seg(t,6,6.6)^2) else ey=0 end
  local shake=t>9.2 and t<13.6 and (0.04+0.14*seg(t,9.2,13.4)) or 0
  local nudge=t>9.2 and math.sin(t*6)*0.5 or 0
  egg:PivotTo(CFrame.new(EGG_AT+V(0,ey,nudge))*A(math.sin(t*37)*shake,t<6.6 and t*3 or 0,math.cos(t*31)*shake))
  glow.FillTransparency=1-0.85*seg(t,11.5,13.6) glow.OutlineTransparency=glow.FillTransparency
  if t>13.6 then egg:PivotTo(CFrame.new(0,-500,0)) end
  -- actors
  for i,a in actors do local bank=a.info.bank local g=ground(bank)
   local faceRiver=V(0,0,a.side) local yawRiver=math.atan2(-faceRiver.X,-faceRiver.Z) local yawHome=yawRiver+math.pi
   local pos,yaw,anim,p=V(bank.X,g,bank.Z),yawRiver,"idle",nil
   if t<1.4 then pos=V(bank.X,PORTAL.Y,bank.Z) a.m.Parent=nil
   elseif t<2.4 then a.m.Parent=fx local k=seg(t,1.4,2.4) pos=V(lerp(PORTAL.X,bank.X,k),lerp(PORTAL.Y,g,k*k),lerp(PORTAL.Z,bank.Z,k)) anim="fall"
   elseif t<2.7 then p={Waist=A(-0.5,0,0),LeftHip=A(1.2,0,0),LeftKnee=A(-1.7,0,0),RightHip=A(1,0,0),RightKnee=A(-1.6,0,0)} pos=pos-V(0,1.1*(1-seg(t,2.4,2.7)),0) anim=nil
   elseif t<5.0 then local look=math.sin((t-2.7)*3.2+i)*0.8*(1-seg(t,4.2,4.6)) p={Neck=A(0,look,0)}
   elseif t<6.3 then yaw=lerp(yawRiver,yawHome,ease(seg(t,5,5.35)))
   elseif t<7.0 then yaw=lerp(yawHome,yawRiver,ease(seg(t,6.3,6.6))) p={LeftShoulder=A(2.3,0,0.2),RightShoulder=A(2.3,0,-0.2)}
   elseif t<8.9 then local k=seg(t,7,8.9) pos=V(bank.X,0,bank.Z):Lerp(a.grab,k^1.2) pos=V(pos.X,ground(pos),pos.Z) anim="run"
   elseif t<9.2 then pos=a.grab+V(0,0.3,0) p={Waist=A(-0.7,0,0),LeftShoulder=A(2.7,0,0),RightShoulder=A(2.7,0,0)} anim=nil
   elseif t<13.6 then local k=math.sin(t*6+i*math.pi) pos=a.grab+V(0,0,-a.side*0.5*k) p=tug(k) anim=nil
   else local k=seg(t,13.6,14.2) pos=a.grab+V(0,1.2*math.sin(k*math.pi),-a.side*4*k) p={Waist=A(0.6,0,0),LeftShoulder=A(0.6,0,-1.7),RightShoulder=A(0.6,0,1.7)} anim=nil end
   play(a,anim) pose(a,p)
   a.m.HumanoidRootPart.CFrame=CFrame.new(pos+V(0,a.off,0))*A(0,yaw,0)
   a.head=a.m.Head.Position end
  -- camera
  local jen,jac=actors[1] and actors[1].head or V(-215,29,10),actors[2] and actors[2].head or V(-215,29,38)
  local mid=(jen+jac)/2 local e=EGG_AT+V(0,2,0)
  local target,fv
  if t<1.4 then target=L(PORTAL+V(26,-16,6),PORTAL) fv=70
  elseif t<2.7 then target=L(V(-196,34,24),V(-215,30,24)) fv=60
  elseif t<3.5 then target=L(V(-207,38,-6),mid-V(0,1,0)) fv=55
  elseif t<4.25 then target=L(jen+V(1.5,0.4,7),jen) fv=40
  elseif t<5.0 then target=L(jac+V(1.5,0.4,-7),jac) fv=40
  elseif t<6.0 then target=L(V(-200,40,24),V(-215,34,24)+V(0,0,0)) fv=75
  elseif t<6.8 then target=L(e+V(9,3,0),e) fv=50
  elseif t<9.2 then target=L(V(-202,29,24),mid) fv=62
  elseif t<13.6 then local cut=math.floor((t-9.2)/1.1)%3 if cut==0 then target=L(e+V(8,1.5,0),e) fv=50 elseif cut==1 then target=L(jen+V(4,0.5,3),jen) fv=42 else target=L(jac+V(4,0.5,-3),jac) fv=42 end
  else target=L(e+V(6,1,0),e) fv=45 end
  local sid=t<1.4 and 0 or t<2.7 and 1 or t<3.5 and 2 or t<4.25 and 3 or t<5 and 4 or t<6 and 5 or t<6.8 and 6 or t<9.2 and 7 or t<13.6 and 8+math.floor((t-9.2)/1.1) or 99
  if sid~=lastShot then lastShot=sid camCF=target else camCF=camCF:Lerp(target,0.12) end
  local sh=(t>2.4 and t<2.7 and 0.4 or 0)+shake*2 cam.CFrame=camCF*CFrame.new(math.noise(t*20)*sh,math.noise(t*20,3)*sh,0) cam.FieldOfView=lerp(cam.FieldOfView,fv,0.2)
  -- white card
  local w=seg(t,13.4,13.8) wf.BackgroundTransparency=1-w local tt=1-seg(t,14.1,14.6) t1.TextTransparency=tt s1.Transparency=tt local t2t=1-seg(t,14.5,15) t2.TextTransparency=t2t s2.Transparency=t2t
  if t>18 then conn:Disconnect() fx:Destroy() white:Destroy() for _,d in hidden do if d.Parent then d.LocalTransparencyModifier=0 end end for i=#restore,1,-1 do restore[i]() end cam.CameraType=ct cam.FieldOfView=fov running=false end
 end)
end

player:GetAttributeChangedSignal("TrailerGo2"):Connect(function() if player:GetAttribute("TrailerGo2") then _G.TrailerDuoStartV2() end end)
