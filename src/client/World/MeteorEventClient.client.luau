-- Cosmetic flight rendering only. Never changes Lighting/Sky.
local RS=game:GetService("ReplicatedStorage")
local Run=game:GetService("RunService")
local Debris=game:GetService("Debris")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local Tween=game:GetService("TweenService")
local folder=RS:WaitForChild("MeteorEvent")
local sites=workspace:WaitForChild("MeteorSites")
local rng=Random.new()
local fx=Instance.new("Folder"); fx.Name="MeteorFXLocal"
local flights={}; local seen={}; local nextStreak=0
local function rock(size)
 local p=Instance.new("Part"); p.Size=Vector3.one*size; p.Anchored=true; p.CanCollide=false; p.CanTouch=false; p.CanQuery=false
 p.Material=Enum.Material.Neon; p.Color=Color3.fromRGB(255,184,87); p.Parent=fx
 local a=Instance.new("Attachment"); a.Position=Vector3.new(0,size/2,0); a.Parent=p
 local b=Instance.new("Attachment"); b.Position=Vector3.new(0,-size/2,0); b.Parent=p
 local trail=Instance.new("Trail"); trail.Attachment0=a; trail.Attachment1=b; trail.Lifetime=0.65; trail.FaceCamera=true
 trail.Color=ColorSequence.new(Color3.fromRGB(255,233,167),Color3.fromRGB(255,89,32)); trail.Transparency=NumberSequence.new(0,1); trail.LightEmission=1; trail.Parent=p
 return p
end
local function burst(pos)
 for i=1,10 do
  local p=rock(rng:NextNumber(0.5,1.3)); p.Position=pos
  Tween:Create(p,TweenInfo.new(0.8,Enum.EasingStyle.Quad,Enum.EasingDirection.Out),{Position=pos+Vector3.new(rng:NextNumber(-12,12),rng:NextNumber(2,7),rng:NextNumber(-12,12)),Transparency=1}):Play(); Debris:AddItem(p,1.5)
 end
end
-- Screen-space impact feedback. One bounded procedural rubble burst in a UI viewport.
local SoundService=game:GetService("SoundService")
local GuiService=game:GetService("GuiService")
local ContentProvider=game:GetService("ContentProvider")
local impactRemote=folder:WaitForChild("Impact")
if playerGui:FindFirstChild("MeteorImpactUI") then
 return
end
local gui=Instance.new("ScreenGui")
gui.Name="MeteorImpactUI"; gui.ResetOnSpawn=false; gui.IgnoreGuiInset=true; gui.DisplayOrder=45; gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
local viewport=Instance.new("ViewportFrame")
viewport.Name="StuddedDirtBurst"; viewport.BackgroundTransparency=1; viewport.Size=UDim2.fromScale(1,1); viewport.Active=false
viewport.Ambient=Color3.fromRGB(185,166,146); viewport.LightColor=Color3.fromRGB(255,224,180); viewport.LightDirection=Vector3.new(-1,-2,-3); viewport.Parent=gui
local world=Instance.new("WorldModel"); world.Name="Rubble"; world.Parent=viewport
local uiCamera=Instance.new("Camera"); uiCamera.FieldOfView=50; uiCamera.CFrame=CFrame.new(0,0,24); uiCamera.Parent=viewport; viewport.CurrentCamera=uiCamera
local cue=Instance.new("TextLabel"); cue.Name="ImpactCue"; cue.AnchorPoint=Vector2.new(0.5,1); cue.Position=UDim2.fromScale(0.5,0.84); cue.Size=UDim2.fromScale(0.7,0.055)
cue.BackgroundTransparency=1; cue.Font=Enum.Font.LuckiestGuy; cue.Text="METEOR IMPACT!"; cue.TextColor3=Color3.fromRGB(255,204,113); cue.TextStrokeColor3=Color3.fromRGB(40,25,15); cue.TextStrokeTransparency=0; cue.TextScaled=true; cue.Visible=false; cue.Active=false; cue.Parent=gui
local textLimit=Instance.new("UITextSizeConstraint"); textLimit.MaxTextSize=32; textLimit.MinTextSize=12; textLimit.Parent=cue
local template=Instance.new("Part"); template.Name="HDStuddedDirt"; template.Size=Vector3.new(2,2,2); template.Anchored=true; template.CanCollide=false; template.Material=Enum.Material.SmoothPlastic
for _,face in Enum.NormalId:GetEnumItems() do
 local texture=Instance.new("Texture"); texture.Name="HDStuds"; texture.Texture="rbxassetid://77460845872634"; texture.StudsPerTileU=4; texture.StudsPerTileV=4; texture.Face=face; texture.Parent=template
end
local audioTemplates={}
for name,id in {Approach=9114463219,Crash=9113220677} do
 local s=Instance.new("Sound"); s.Name="Meteor"..name; s.SoundId="rbxassetid://"..id; s.Volume=0; s.Parent=SoundService; audioTemplates[name]=s
end
task.spawn(function() pcall(function() ContentProvider:PreloadAsync({audioTemplates.Approach,audioTemplates.Crash,template}) end) end)
local function sound(name,volume,speed)
 local s=audioTemplates[name]:Clone(); s.Volume=volume; s.PlaybackSpeed=speed
 local group=SoundService:FindFirstChild("SFX"); if group then s.SoundGroup=group end
 s.Parent=SoundService; s:Play(); Debris:AddItem(s,8)
end
local rubble={}; local shakeUntil=0; local shakeStart=0; local cueUntil=0; local lastCamera=nil; local lastOffset=CFrame.new()
local function reduced() return player:GetAttribute("ReducedMotion")==true or GuiService.ReducedMotionEnabled end
local function clearRubble()
 for _,r in rubble do r.part:Destroy() end; table.clear(rubble)
end
local function impactFeedback(pos)
 local t=os.clock(); clearRubble()
 cue.Visible=true; cue.TextTransparency=0; cue.TextStrokeTransparency=0; cueUntil=t+1.4
 sound("Crash",0.85,0.85)
 if reduced() then shakeUntil=0; return end
 shakeStart=t; shakeUntil=t+0.65
 local aspect=math.max(viewport.AbsoluteSize.X,1)/math.max(viewport.AbsoluteSize.Y,1)
 local halfHeight=24*math.tan(math.rad(uiCamera.FieldOfView/2)); local halfWidth=halfHeight*aspect
 for i=1,18 do
  local side=i%2==0 and 1 or -1
  local p=template:Clone(); p.Name="DirtChunk"; p.Color=i%3==0 and Color3.fromRGB(103,76,46) or Color3.fromRGB(73,51,32)
  local size=rng:NextNumber(0.65,1.3); p.Size=Vector3.one*size; for _,texture in p:GetChildren() do if texture:IsA("Texture") then texture.Color3=p.Color end end; p.Parent=world
  -- Bottom corners arc upward and outward, preserving the middle of the screen.
  local origin=Vector3.new(side*rng:NextNumber(0.65,0.98)*halfWidth,-halfHeight-1,rng:NextNumber(-1,1))
  table.insert(rubble,{part=p,origin=origin,velocity=Vector3.new(side*rng:NextNumber(0.2,2.5),rng:NextNumber(14,20),0),spin=Vector3.new(rng:NextNumber(-5,5),rng:NextNumber(-5,5),rng:NextNumber(-5,5)),start=t})
  p.CFrame=CFrame.new(origin)
 end
 gui:SetAttribute("ImpactCount",(gui:GetAttribute("ImpactCount") or 0)+1)
end
impactRemote.OnClientEvent:Connect(function(kind,pos)
 if kind=="Approach" then sound("Approach",0.45,0.75)
 elseif kind=="Impact" and typeof(pos)=="Vector3" then burst(pos+Vector3.new(0,2,0)); impactFeedback(pos) end
end)
gui.Parent=playerGui
fx.Parent=workspace
-- Remove our previous offset before camera controllers run; apply fresh shake afterward.
Run:BindToRenderStep("MeteorShakeRestore",Enum.RenderPriority.Camera.Value-1,function()
 if lastCamera and lastCamera==workspace.CurrentCamera then lastCamera.CFrame=lastCamera.CFrame*lastOffset:Inverse() end
 lastCamera=nil; lastOffset=CFrame.new()
end)
Run:BindToRenderStep("MeteorImpactFeedback",Enum.RenderPriority.Camera.Value+2,function()
 local t=os.clock()
 if t<shakeUntil and not reduced() then
  local k=(1-(t-shakeStart)/0.65)^2; local cam=workspace.CurrentCamera
  if cam then
   local offset=CFrame.new(math.noise(t*35,0)*0.42*k,math.noise(0,t*39)*0.34*k,0)*CFrame.Angles(0,0,math.sin(t*43)*math.rad(0.65)*k)
   cam.CFrame=cam.CFrame*offset; lastCamera=cam; lastOffset=offset
  end
 end
 for i=#rubble,1,-1 do
  local r=rubble[i]; local age=t-r.start
  if age>1.3 or reduced() then r.part:Destroy(); table.remove(rubble,i)
  else r.part.CFrame=CFrame.new(r.origin+r.velocity*age+Vector3.new(0,-17*age*age,0))*CFrame.Angles(r.spin.X*age,r.spin.Y*age,r.spin.Z*age); r.part.Transparency=math.clamp((age-0.8)/0.5,0,1) end
 end
 if cue.Visible then
  local alpha=math.clamp((t-(cueUntil-0.35))/0.35,0,1); cue.TextTransparency=alpha; cue.TextStrokeTransparency=alpha
  if t>=cueUntil then cue.Visible=false end
 end
end)
player.CharacterAdded:Connect(function() clearRubble(); shakeUntil=0; cue.Visible=false end)
script.Destroying:Connect(function()
 Run:UnbindFromRenderStep("MeteorImpactFeedback"); Run:UnbindFromRenderStep("MeteorShakeRestore")
 if lastCamera then lastCamera.CFrame=lastCamera.CFrame*lastOffset:Inverse() end
 clearRubble(); gui:Destroy(); template:Destroy()
 for _,s in audioTemplates do s:Destroy() end
end)

Run.RenderStepped:Connect(function()
 local t=workspace:GetServerTimeNow(); local night=workspace:GetAttribute("NighttimeActive")==true
 local shower=night and t<(folder:GetAttribute("EndsAt") or 0)
 if shower and t>nextStreak then
  nextStreak=t+0.35
  local cam=workspace.CurrentCamera
  if cam then
   local origin=cam.CFrame.Position+Vector3.new(rng:NextNumber(-500,500),rng:NextNumber(220,380),rng:NextNumber(-500,500))
   local p=rock(rng:NextNumber(0.6,1.3)); p.Position=origin
   table.insert(flights,{part=p,from=origin,to=origin+Vector3.new(190,-100,60),start=t,finish=t+1.3})
  end
 end
 for _,site in sites:GetChildren() do
  local at=site:GetAttribute("ImpactAt"); local pos=site:GetAttribute("Position")
  if at and pos and not seen[site] then
   if t>=at then seen[site]=true
   elseif shower and t>=at-3 then
    seen[site]=true
    local p=rock(3.5); p.Position=pos+Vector3.new(-180,260,-80)
    table.insert(flights,{part=p,from=p.Position,to=pos+Vector3.new(0,2,0),start=at-3,finish=at,site=site})
    local marker=Instance.new("Part"); marker.Shape=Enum.PartType.Cylinder; marker.Size=Vector3.new(0.12,16,16); marker.CFrame=CFrame.new(pos+Vector3.new(0,0.15,0))*CFrame.Angles(0,0,math.pi/2)
    marker.Color=Color3.fromRGB(255,151,55); marker.Material=Enum.Material.Neon; marker.Transparency=0.6; marker.Anchored=true; marker.CanCollide=false; marker.CanTouch=false; marker.CanQuery=false; marker.Parent=fx; Debris:AddItem(marker,3)
   end
  end
 end
 for i=#flights,1,-1 do
  local f=flights[i]
  if not shower or (f.site and (not f.site.Parent or f.site:GetAttribute("Fading"))) then f.part:Destroy(); table.remove(flights,i)
  elseif t>=f.finish then
   -- Impact burst is driven by the authoritative server message for every player.
   f.part.Transparency=1; Debris:AddItem(f.part,0.7); table.remove(flights,i)
  else f.part.Position=f.from:Lerp(f.to,math.clamp((t-f.start)/(f.finish-f.start),0,1)); f.part.Orientation=Vector3.new(t*80,t*110,30) end
 end
 for site in seen do if not site.Parent then seen[site]=nil end end
end)
