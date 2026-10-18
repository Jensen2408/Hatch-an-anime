--[[ ReplicatedFirst.LoadingScreen  (LocalScript) — Hatch An Anime × Velm Studios
1. Velm Studios intro (logo art, push-in, light sweep)
2. Cinematic loading: drifting art, glowing title, live percentage, tips, Skip
Real progress comes from ReplicatedFirst.StartupLoader. Keeps the JoinArrival handshake
(LoadingScreenFinishing → waits for JoinArrivalCameraSet → LoadingScreenDone). Cosmetic only.
Settings: Config (child ModuleScript). Old version: ServerStorage._ARCHIVE.OldLoadingScreen_*.
]]
local RF=game:GetService("ReplicatedFirst") local Players=game:GetService("Players") local TS=game:GetService("TweenService")
local RunService=game:GetService("RunService") local CP=game:GetService("ContentProvider") local GuiService=game:GetService("GuiService")
local StarterGui=game:GetService("StarterGui")
-- Restore Roblox UI without enabling its hotbar; GameHUD owns inventory.
local function restoreCoreGui()
 for _, coreType in Enum.CoreGuiType:GetEnumItems() do
  if coreType ~= Enum.CoreGuiType.All then
   pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, coreType ~= Enum.CoreGuiType.Backpack)
  end
 end
end

local Config=require(script:WaitForChild("Config")) local C=Config.Colors
local player=Players.LocalPlayer local pg=player:WaitForChild("PlayerGui")
if pg:FindFirstChild("HatchLoading") then return end
RF:RemoveDefaultLoadingScreen()
local reduced=player:GetAttribute(Config.ReducedMotionAttribute)==true pcall(function() reduced=reduced or GuiService.ReducedMotionEnabled end)
local TITLE=Font.new("rbxasset://fonts/families/FredokaOne.json")
local BODY=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Medium)
local BOLD=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Bold)
local t0=os.clock()
local conns,tweens={},{}
local function make(cl,p,parent) local o=Instance.new(cl) for k,v in p do o[k]=v end if parent then o.Parent=parent end return o end
local function tw(o,t,p,st,dir,delay) local x=TS:Create(o,TweenInfo.new(t,st or Enum.EasingStyle.Quad,dir or Enum.EasingDirection.Out,0,false,delay or 0),p) x:Play() table.insert(tweens,x) return x end
local function loop(o,t,p,st) local x=TS:Create(o,TweenInfo.new(t,st or Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),p) x:Play() table.insert(tweens,x) return x end
local function seq(t) local k={} for _,v in t do table.insert(k,NumberSequenceKeypoint.new(v[1],v[2])) end return NumberSequence.new(k) end

-- hide the Roblox HUD + controls while loading
local hiddenCore=false
if Config.HideCoreGui then hiddenCore=pcall(function() StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false) end) end
local controls
if Config.DisableControls then task.spawn(function() local ps=player:WaitForChild("PlayerScripts",10) local pm=ps and ps:WaitForChild("PlayerModule",10)
 if pm then pcall(function() controls=require(pm):GetControls() controls:Disable() end) end end) end

---------------------------------------------------------------- root
local gui=make("ScreenGui",{Name="HatchLoading",IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=100000,ScreenInsets=Enum.ScreenInsets.None,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local root=make("CanvasGroup",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0},gui)

---------------------------------------------------------------- scene: Velm chrome stage
local LOGO=script:GetAttribute("VelmLogo") or ""
local HALF_L,HALF_R=script:GetAttribute("VelmLeft") or "",script:GetAttribute("VelmRight") or ""
local ASPECT=2000/754
local function makeStage(parent,z)
 local st=make("CanvasGroup",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),BackgroundTransparency=1,ZIndex=z},parent)
 if HALF_L~="" and HALF_R~="" then
  make("ImageLabel",{Size=UDim2.fromScale(.5,1),BackgroundTransparency=1,Image=HALF_L,ScaleType=Enum.ScaleType.Stretch,ResampleMode=Enum.ResamplerMode.Default,ZIndex=z},st)
  make("ImageLabel",{Position=UDim2.fromScale(.5,0),Size=UDim2.fromScale(.5,1),BackgroundTransparency=1,Image=HALF_R,ScaleType=Enum.ScaleType.Stretch,ZIndex=z},st)
 else
  make("ImageLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=LOGO,ScaleType=Enum.ScaleType.Stretch,ZIndex=z},st)
 end
 return st
end
local function cover(st,zoom,dx,dy)
 local v=gui.AbsoluteSize if v.X<=0 then return end
 local w=math.max(v.X,v.Y*ASPECT)*zoom
 st.Size=UDim2.fromOffset(w,w/ASPECT) st.Position=UDim2.new(.5,dx or 0,.5,dy or 0)
end
local scene=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=1},root)
-- the logo art is the stage: spotlight, chrome logo, reflective floor
local art=makeStage(scene,1) local artZoom=1.0
-- moving spotlight beam across the wall
local beam=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.1,.3),Size=UDim2.fromScale(.35,1.6),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.88,BorderSizePixel=0,Rotation=-28,ZIndex=2},scene)
make("UIGradient",{Transparency=seq({{0,1},{.5,0},{1,1}})},beam)
-- vignette + floor fade so the UI reads
local vign=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=3},scene)
make("UIGradient",{Transparency=seq({{0,.25},{.2,1},{.8,1},{1,.25}})},vign)
local floor=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=3},scene)
make("UIGradient",{Rotation=90,Transparency=seq({{0,1},{.62,1},{1,.05}})},floor)
-- silver dust drifting up
local petals=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=4,ClipsDescendants=true},scene)
local rng=Random.new()
local function petal()
 local sz=rng:NextInteger(2,5)
 local p=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Size=UDim2.fromOffset(sz,sz),Position=UDim2.new(rng:NextNumber(0,1),0,1.02,0),BackgroundColor3=Color3.fromRGB(235,240,255),
  BackgroundTransparency=rng:NextNumber(.2,.6),BorderSizePixel=0,ZIndex=4},petals)
 make("UICorner",{CornerRadius=UDim.new(1,0)},p)
 local d=rng:NextNumber(5,9)
 tw(p,d,{Position=UDim2.new(p.Position.X.Scale+rng:NextNumber(-.06,.06),0,rng:NextNumber(.1,.6),0),BackgroundTransparency=1},Enum.EasingStyle.Sine)
 task.delay(d,function() p:Destroy() end)
end
-- twinkle star (matches the star on the logo)
local star=make("ImageLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.68,.295),Size=UDim2.fromOffset(90,90),BackgroundTransparency=1,Image="rbxasset://textures/particles/sparkles_main.dds",ImageTransparency=.3,ZIndex=5},scene)
local rays={} rays.Rotation=0

-- game title under the logo, chrome style
local titleBox=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.73),Size=UDim2.fromScale(.6,.09),BackgroundTransparency=1,ZIndex=10},scene)
make("UISizeConstraint",{MaxSize=Vector2.new(720,70)},titleBox)
local tscale=make("UIScale",{Scale=1},titleBox)
local hatch=make("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="HATCH  AN  ANIME",FontFace=BOLD,TextScaled=true,TextColor3=Color3.new(1,1,1),ZIndex=12},titleBox)
make("UIGradient",{Rotation=90,Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(255,255,255)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(190,195,205)),ColorSequenceKeypoint.new(1,Color3.fromRGB(120,125,135))})},hatch)
local anime=hatch
local shineLabel=hatch:Clone() shineLabel.Name="Shine" for _,c in shineLabel:GetChildren() do c:Destroy() end shineLabel.ZIndex=13 shineLabel.Parent=titleBox
local shineGrad=make("UIGradient",{Rotation=10,Transparency=seq({{0,1},{.44,1},{.5,0},{.56,1},{1,1}}),Offset=Vector2.new(-1.2,0)},shineLabel)
local line=make("Frame",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,1,8),Size=UDim2.new(.5,0,0,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=12},titleBox)
make("UIGradient",{Transparency=seq({{0,1},{.5,.2},{1,1}})},line)

-- bottom: thin chrome progress
local bottom=make("Frame",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-36),Size=UDim2.new(.5,0,0,70),BackgroundTransparency=1,ZIndex=20},scene)
make("UISizeConstraint",{MaxSize=Vector2.new(620,70),MinSize=Vector2.new(280,0)},bottom)
local stage=make("TextLabel",{Position=UDim2.new(0,0,0,0),Size=UDim2.new(.75,0,0,18),BackgroundTransparency=1,Text="Preparing your temple…",FontFace=BODY,TextSize=14,
 TextColor3=Color3.fromRGB(200,205,215),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=21},bottom)
local pct=make("TextLabel",{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,0),Size=UDim2.new(.25,0,0,18),BackgroundTransparency=1,Text="0%",FontFace=BOLD,TextSize=16,
 TextColor3=Color3.new(1,1,1),TextXAlignment=Enum.TextXAlignment.Right,ZIndex=21},bottom)
local track=make("Frame",{Position=UDim2.new(0,0,0,26),Size=UDim2.new(1,0,0,3),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.85,BorderSizePixel=0,ZIndex=21},bottom)
make("UICorner",{CornerRadius=UDim.new(1,0)},track)
local fill=make("Frame",{Size=UDim2.fromScale(.02,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=22},track)
make("UICorner",{CornerRadius=UDim.new(1,0)},fill)
make("UIGradient",{Color=ColorSequence.new(Color3.fromRGB(150,155,165),Color3.new(1,1,1))},fill)
local glow=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(1,.5),Size=UDim2.fromOffset(16,16),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.1,BorderSizePixel=0,ZIndex=23},fill)
make("UICorner",{CornerRadius=UDim.new(1,0)},glow) make("UIGradient",{Transparency=seq({{0,1},{.5,0},{1,1}})},glow)
local fillShine=make("UIGradient",{Transparency=seq({{0,1},{1,1}})},make("Frame",{Size=UDim2.fromScale(0,0),BackgroundTransparency=1},fill))
local tip=make("TextLabel",{Position=UDim2.new(0,0,0,42),Size=UDim2.new(1,0,0,18),BackgroundTransparency=1,Text="",FontFace=BODY,TextSize=14,TextColor3=Color3.fromRGB(165,170,182),ZIndex=21},bottom)

local skip=make("TextButton",{AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-24,1,-24),Size=UDim2.fromOffset(96,34),BackgroundColor3=Color3.new(0,0,0),BackgroundTransparency=.4,
 Text="SKIP",FontFace=BOLD,TextSize=13,TextColor3=Color3.fromRGB(220,225,235),AutoButtonColor=true,ZIndex=30},scene)
make("UICorner",{CornerRadius=UDim.new(1,0)},skip) make("UIStroke",{Color=Color3.new(1,1,1),Thickness=1,Transparency=.7,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},skip)

---------------------------------------------------------------- Velm intro (on top): same art, so it flows straight into the stage
local intro=make("CanvasGroup",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=50},root)
local logo=makeStage(intro,51) logo.GroupTransparency=1 local logoZoom=Instance.new("NumberValue") logoZoom.Value=1.06
local sweep=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(-.3,.4),Size=UDim2.fromScale(.12,.5),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Rotation=18,BackgroundTransparency=1,ZIndex=52},intro)
make("UIGradient",{Transparency=seq({{0,1},{.5,.75},{1,1}})},sweep)
gui.Parent=pg
pcall(function() CP:PreloadAsync({logo,art}) end)
for _,st in {art,logo} do cover(st,1) end

---------------------------------------------------------------- live motion
local tipIndex=0
local function nextTip() tipIndex=tipIndex%#Config.Tips+1 tip.TextTransparency=1 tip.Text=Config.Tips[tipIndex] tw(tip,.5,{TextTransparency=0}) end
table.insert(conns,RunService.RenderStepped:Connect(function(dt)
 local t=os.clock()-t0
 if logo.Parent then cover(logo,logoZoom.Value) end
 if reduced then cover(art,1) end
 if not reduced then
  cover(art,1.0+(math.sin(t*.25)+1)*.008,math.sin(t*.15)*8,0)
  beam.Position=UDim2.fromScale(.1+math.sin(t*.35)*.18,.3) beam.BackgroundTransparency=.86+math.sin(t*.7)*.04
  local tw2=(math.sin(t*2.2)+1)/2 star.ImageTransparency=.15+tw2*.6 star.Size=UDim2.fromOffset(60+tw2*50,60+tw2*50) star.Rotation=t*20
 end
end))

---------------------------------------------------------------- sequence
local progress,closing,close=0,false,nil
local function setProgress(v,msg)
 progress=math.max(progress,math.clamp(v,0,1))
 if msg then stage.Text=msg end
 tw(fill,.35,{Size=UDim2.fromScale(math.max(.03,progress),1)})
 pct.Text=math.floor(progress*100+.5).."%"
end
task.spawn(function()
 -- intro
 tw(logo,.9,{GroupTransparency=0},Enum.EasingStyle.Sine)
 if not reduced then tw(logoZoom,2.9,{Value=1.0},Enum.EasingStyle.Sine,Enum.EasingDirection.InOut) end
 task.wait(.8)
 if not reduced then sweep.BackgroundTransparency=0 tw(sweep,.9,{Position=UDim2.fromScale(1.3,.47)},Enum.EasingStyle.Quad,Enum.EasingDirection.InOut) end
 task.wait(1.3)
 tw(intro,.7,{GroupTransparency=1},Enum.EasingStyle.Sine)
 -- title pops in as the intro clears
 hatch.TextTransparency=1 shineLabel.TextTransparency=1 tw(hatch,.8,{TextTransparency=0},nil,nil,.2) tw(shineLabel,.8,{TextTransparency=0},nil,nil,.2)
 task.wait(.75) intro:Destroy()
 nextTip()
 task.spawn(function() while not closing do task.wait(Config.TipSeconds or 3.2) if closing then break end nextTip() end end)
 task.spawn(function() while not closing do shineGrad.Offset=Vector2.new(-1.2,0) tw(shineGrad,1.1,{Offset=Vector2.new(1.2,0)},Enum.EasingStyle.Quad,Enum.EasingDirection.InOut)
  task.wait(3.2) end end)
 task.spawn(function() while not closing do if not reduced then petal() end task.wait(.09) end end)
end)
task.spawn(function()
 setProgress(.02,"Preparing your temple…")
 local loader=RF:WaitForChild("StartupLoader",10)
 local ok,err=pcall(function() require(loader).Run(player,gui,function(p,msg) if closing then return end setProgress(p,msg and (msg:sub(-1)=="!" and msg or msg.."…") or nil) end) end)
 if not ok then warn("[LoadingScreen] "..tostring(err)) end
 local w=(Config.MinSeconds or 3.4)-(os.clock()-t0) if w>0 then task.wait(w) end
 close(true)
end)

close=function(finished)
 if closing then return end
 while RunService:IsStudio() and player:GetAttribute("HoldLoading") and finished do task.wait(.1) end
 closing=true
 player:SetAttribute("LoadingScreenFinishing",true)
 local arrival=game:GetService("ReplicatedStorage"):FindFirstChild("JoinArrival")
 if arrival and arrival:GetAttribute("Enabled")~=false then
  local deadline=os.clock()+6
  while not player:GetAttribute("JoinArrivalCameraSet") and os.clock()<deadline do RunService.RenderStepped:Wait() end
 end
 setProgress(1,"Ready!")
 if not reduced then
  tw(tscale,.35,{Scale=1.12},Enum.EasingStyle.Back)
  local flash=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=1,BorderSizePixel=0,ZIndex=60},root)
  tw(flash,.18,{BackgroundTransparency=.25}) task.wait(.2)
 end
 tw(root,.45,{GroupTransparency=1},Enum.EasingStyle.Sine)
 task.wait(.47)
 for _,c in conns do c:Disconnect() end for _,x in tweens do x:Cancel() end
 if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(gui) then GuiService.SelectedObject=nil end
 gui:Destroy()
 player:SetAttribute("LoadingScreenDone",true)
 if hiddenCore and (not player:GetAttribute("JoinArrivalStarted") or player:GetAttribute("JoinArrivalFinished")) then
  for _=1,5 do if pcall(restoreCoreGui) then break end task.wait(.2) end end
 if controls then pcall(function() controls:Enable() end) end
end
table.insert(conns,skip.Activated:Connect(function() task.spawn(close,false) end))
task.delay(Config.MaxSeconds or 180,function() task.spawn(close,false) end)
