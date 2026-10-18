-- A local first-hatch guide. No client requests can grant progress or rewards.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Pathfinding=game:GetService("PathfindingService")
local guideConfig=game.ReplicatedStorage:WaitForChild("FirstHatchGuide")
local Guide=require(guideConfig)
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local function make(class,props,parent)
 local o=Instance.new(class) for k,v in props do o[k]=v end o.Parent=parent return o
end
-- Matches the existing HUD and inventory palette.
local INK=Color3.fromRGB(29,20,32)
local PANEL=Color3.fromRGB(40,26,44)
local CREAM=Color3.fromRGB(255,243,220)
local GOLD=Color3.fromRGB(255,200,80)
local RED=Color3.fromRGB(232,69,44)
local DISPLAY=Font.new("rbxasset://fonts/families/FredokaOne.json")
local gui=make("ScreenGui",{Name="FirstHatchTutorial",ResetOnSpawn=false,DisplayOrder=55,Enabled=false},pg)
local card=make("Frame",{Name="GuideCard",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,132),Size=UDim2.fromOffset(370,150),BackgroundColor3=PANEL,BorderSizePixel=0},gui)
make("UICorner",{CornerRadius=UDim.new(0,12)},card)
make("UIStroke",{Color=INK,Thickness=3},card)
local header=make("Frame",{Name="Header",Size=UDim2.new(1,0,0,30),BackgroundColor3=RED,BorderSizePixel=0},card)
make("UICorner",{CornerRadius=UDim.new(0,12)},header)
make("Frame",{Position=UDim2.new(0,0,1,-12),Size=UDim2.new(1,0,0,12),BackgroundColor3=RED,BorderSizePixel=0},header)
make("Frame",{Position=UDim2.fromOffset(0,30),Size=UDim2.new(1,0,0,2),BackgroundColor3=INK,BorderSizePixel=0},card)
local scale=make("UIScale",{},card)
local function label(name,pos,size,textSize,color)
 return make("TextLabel",{Name=name,Position=pos,Size=size,BackgroundTransparency=1,Text="",Font=Enum.Font.GothamBold,TextSize=textSize,TextColor3=color or CREAM,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Center},card)
end
local heading=label("Progress",UDim2.fromOffset(14,3),UDim2.fromOffset(300,24),14,CREAM)
heading.FontFace=DISPLAY;heading.TextStrokeColor3=INK;heading.TextStrokeTransparency=.55
local title=label("Objective",UDim2.fromOffset(14,37),UDim2.new(1,-28,0,27),21,CREAM)
title.FontFace=DISPLAY
local body=label("Instructions",UDim2.fromOffset(14,68),UDim2.new(1,-28,0,44),14,CREAM)
body.Font=Enum.Font.GothamMedium;body.TextWrapped=true
local distance=label("Distance",UDim2.fromOffset(14,121),UDim2.new(1,-28,0,19),11,GOLD)
local compact=false
local collapse=make("TextButton",{Name="Collapse",Position=UDim2.new(1,-34,0,1),Size=UDim2.fromOffset(29,27),Text="−",TextSize=22,FontFace=DISPLAY,TextColor3=CREAM,BackgroundTransparency=1},card)
collapse.Activated:Connect(function()
 compact=not compact;collapse.Text=compact and "+" or "−"
 body.Visible=not compact;distance.Visible=not compact;card.Size=UDim2.fromOffset(370,compact and 72 or 150)
end)
local fx=make("Folder",{Name="TutorialGroundTrail"},workspace)
local highlight=make("Highlight",{Name="TutorialObjective",FillTransparency=1,OutlineTransparency=.15,OutlineColor=GOLD,DepthMode=Enum.HighlightDepthMode.Occluded,Enabled=false},fx)
local marker=make("BillboardGui",{Name="Destination",Size=UDim2.fromOffset(180,36),StudsOffsetWorldSpace=Vector3.new(0,3,0),AlwaysOnTop=true,MaxDistance=180,Enabled=false},gui)
make("TextLabel",{Size=UDim2.fromScale(1,1),BackgroundColor3=PANEL,BackgroundTransparency=.06,BorderSizePixel=0,Text="",TextSize=15,TextColor3=GOLD,FontFace=DISPLAY,TextWrapped=true,Name="Caption"},marker)
make("UICorner",{CornerRadius=UDim.new(0,9)},marker.Caption)
make("UIStroke",{Color=INK,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},marker.Caption)
-- This invisible carrier only holds attachments. All visible guidance is a flat Beam.
local carrier=make("Part",{Name="TrailAttachments",Size=Vector3.one,CFrame=CFrame.identity,Transparency=1,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false},fx)
local REPEAT_LENGTH=3.4
local ribbons={}
for i=1,48 do
 local a=make("Attachment",{Name="From"..i},carrier)
 local b=make("Attachment",{Name="To"..i},carrier)
 local beam=make("Beam",{Name="GroundTrail"..i,Attachment0=a,Attachment1=b,Enabled=false,FaceCamera=false,Width0=1.7,Width1=1.7,Color=ColorSequence.new(GOLD),Transparency=NumberSequence.new(.12),LightEmission=.45,LightInfluence=0,Segments=1,TextureMode=Enum.TextureMode.Wrap,TextureLength=REPEAT_LENGTH,TextureSpeed=0},carrier)
 ribbons[i]={a=a,b=b,beam=beam,offset=0}
end
local step,target,routeTarget,routeStart
local route,generation={},0
local busy=false
local lastPath=-math.huge
local stopped=false
local shown=false
local connections={}
local function hideTrail()
 for _,r in ribbons do r.beam.Enabled=false end
 gui:SetAttribute("VisibleTrailSegments",0)
end
local function clearTarget()
 generation+=1;route={};routeTarget=nil;routeStart=nil
 hideTrail();highlight.Enabled=false;highlight.Adornee=nil;marker.Enabled=false;marker.Adornee=nil
end
local function rayParams()
 local ignore={fx}
 for _,p in Players:GetPlayers() do if p.Character then table.insert(ignore,p.Character) end end
 for _,n in {"LocalRiverEggs","WaterfallEggs","FloatFX"} do local f=workspace:FindFirstChild(n) if f then table.insert(ignore,f) end end
 local plots=workspace:FindFirstChild("Plots")
 if plots then for _,p in plots:GetChildren() do local items=p:FindFirstChild("PlacedItems") if items then table.insert(ignore,items) end end end
 local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Exclude;params.FilterDescendantsInstances=ignore;params.RespectCanCollide=true
 return params
end
local function groundAt(position,params)
 return workspace:Raycast(position+Vector3.new(0,3,0),Vector3.new(0,-14,0),params)
end
local function destination(root,part,params)
 local delta=Vector3.new(part.Position.X-root.Position.X,0,part.Position.Z-root.Position.Z)
 local stop=part.Position-(delta.Magnitude>.1 and delta.Unit*3 or Vector3.zero)
 local floor=groundAt(stop,params)
 return floor and floor.Position or stop
end
local function updatePath(root,part)
 if busy or os.clock()-lastPath<1.5 then return end
 if routeTarget and (part.Position-routeTarget).Magnitude<5 and routeStart and (root.Position-routeStart).Magnitude<6 and os.clock()-lastPath<4 then return end
 lastPath=os.clock();busy=true
 local token=generation
 local start=root.Position;local params=rayParams();local finish=destination(root,part,params)
 routeTarget=part.Position;routeStart=start
 task.spawn(function()
  local path=Pathfinding:CreatePath({AgentRadius=2,AgentHeight=5,AgentCanJump=true,WaypointSpacing=4})
  local ok=pcall(path.ComputeAsync,path,start,finish)
  local points={}
  if ok and path.Status==Enum.PathStatus.Success then
   for _,wp in path:GetWaypoints() do table.insert(points,wp.Position) end
  else
   -- A short unobstructed direction hint is safer than drawing through a wall.
   local delta=finish-start
   local length=math.min(delta.Magnitude,18)
   if length>1 then
    local dir=delta.Unit;local hit=workspace:Raycast(start,dir*length,params)
    if hit then length=math.max(0,(hit.Position-start).Magnitude-2) end
    if length>2 then points={start,start+dir*length} end
   end
  end
  path:Destroy()
  if not stopped and token==generation then route=points end
  busy=false
 end)
end
local function drawTrail(root)
 hideTrail()
 if #route<2 then return end
 local params=rayParams()
 local texture=guideConfig:GetAttribute("ArrowTexture") or ""
 if type(texture)~="string" then texture="" end
 -- Resume at the closest point on the route so the trail never points behind you.
 local closest,bestAlong,bestIndex=math.huge,0,1
 for i=1,#route-1 do
  local delta=route[i+1]-route[i]
  local t=delta:Dot(delta)>0 and math.clamp((root.Position-route[i]):Dot(delta)/delta:Dot(delta),0,1) or 0
  local d=(route[i]+delta*t-root.Position).Magnitude
  if d<closest then closest,bestAlong,bestIndex=d,t,i end
 end
 local count,travelled=0,0
 for i=bestIndex,#route-1 do
  local start=i==bestIndex and route[i]:Lerp(route[i+1],bestAlong) or route[i]
  local delta=route[i+1]-start;local length=delta.Magnitude
  if length>.05 then
   local pieces=math.ceil(length/2.5)
   for j=0,pieces-1 do
    local p0=start+delta*(j/pieces);local p1=start+delta*((j+1)/pieces)
    local h0=groundAt(p0,params);local h1=groundAt(p1,params)
    local span=(p1-p0).Magnitude
    if travelled>75 or count>=#ribbons then break end
    if h0 and h1 and h0.Normal.Y>.45 and h1.Normal.Y>.45 and math.abs(h1.Position.Y-h0.Position.Y)<2.5 then
     local origin=h0.Position+h0.Normal*.08
     local finish=h1.Position+h1.Normal*.08
     local forward=finish-origin
     local normal=(h0.Normal+h1.Normal).Unit
     local side=normal:Cross(forward)
     if forward.Magnitude>.05 and side.Magnitude>.01 then
      count+=1
      local r=ribbons[count]
      -- Attachment Y axes lie across the ground, keeping the ribbon horizontal.
      r.a.WorldCFrame=CFrame.fromMatrix(origin,forward.Unit,side.Unit)
      r.b.WorldCFrame=CFrame.fromMatrix(finish,forward.Unit,side.Unit)
      r.offset=travelled/REPEAT_LENGTH
      r.beam.Texture=texture
      -- Until an image is imported, display a slim gold guide line.
      local width=texture~="" and 1.7 or .32
      r.beam.Width0=width;r.beam.Width1=width
      r.beam.Enabled=true
     end
    end
    travelled+=span
   end
  end
  if travelled>75 or count>=#ribbons then break end
 end
 gui:SetAttribute("VisibleTrailSegments",count)
end
-- Animate a shared texture phase so adjacent ribbons flow as one trail.
table.insert(connections,Run.RenderStepped:Connect(function()
 local phase=player:GetAttribute("ReducedMotion") and 0 or os.clock()*.65
 for _,r in ribbons do
  if r.beam.Enabled and r.beam.Texture~="" then r.beam:SetTextureOffset((r.offset-phase)%1) end
 end
end))
local function finish()
 if stopped then return end
 stopped=true;clearTarget();fx:Destroy()
 for _,c in connections do c:Disconnect() end
 if shown then
  gui.Enabled=true;heading.Text="TUTORIAL COMPLETE";title.Text="Your temple is earning!"
  body.Text="Collect more eggs, hatch stronger characters, and unlock more podiums.";distance.Text="You're ready to grow your temple."
  task.delay(4,function()gui:Destroy()end)
 else gui:Destroy() end
end
local elapsed=0
table.insert(connections,Run.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.2 then return end;elapsed=0
 if player:GetAttribute("TutorialCompleted")==true then finish();return end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
 local loading=pg:FindFirstChild("HatchLoading") or pg:FindFirstChild("LaunchLoadingScreen")
 local arriving=player:GetAttribute("JoinArrivalStarted") and not player:GetAttribute("JoinArrivalFinished")
 local ready=player:GetAttribute("TutorialDataReady") and root and hum and hum.Health>0 and not loading and not arriving
 if not ready then gui.Enabled=false;clearTarget();return end
 local newStep,newTarget,note,revealing=Guide.Resolve(player)
 if newStep==9 then finish();return end
 if newStep~=step or newTarget~=target then clearTarget();step=newStep;target=newTarget end
 gui:SetAttribute("Step",step)
 gui.Enabled=not revealing;highlight.Enabled=false;marker.Enabled=false
 if revealing then hideTrail();return end
 shown=true
 local info=Guide.Steps[step];heading.Text="HOW TO PLAY  •  "..step.." / "..#Guide.Steps
 title.Text=info.title;body.Text=note or info.body
 local camera=workspace.CurrentCamera
 scale.Scale=camera and math.min(1,(camera.ViewportSize.X-24)/370,camera.ViewportSize.Y/680) or 1
 if not target or not target.Parent then distance.Text="Finding your next objective...";hideTrail();return end
 highlight.Adornee=target;highlight.Enabled=true;marker.Adornee=target;marker.Enabled=true;marker.Caption.Text=info.marker
 local d=(target.Position-root.Position).Magnitude
 distance.Text=d>7 and ("FOLLOW THE GOLD TRAIL  •  "..math.floor(d).." studs") or (step==4 and "YOUR EGG IS INCUBATING" or "YOU'RE HERE  •  USE THE INTERACTION PROMPT")
 if d<=7 then hideTrail();gui:SetAttribute("VisibleTrailSegments",0) else updatePath(root,target);drawTrail(root) end
end))
table.insert(connections,player:GetAttributeChangedSignal("TutorialCompleted"):Connect(function()if player:GetAttribute("TutorialCompleted") then finish() end end))
gui.Destroying:Connect(function()
 stopped=true;generation+=1
 for _,c in connections do c:Disconnect() end
 if fx.Parent then fx:Destroy() end
end)
