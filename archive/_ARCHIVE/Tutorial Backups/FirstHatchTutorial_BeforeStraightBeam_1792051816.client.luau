-- A local first-hatch guide. No client requests can grant progress or rewards.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Pathfinding=game:GetService("PathfindingService")
local TweenService=game:GetService("TweenService")
local RS=game:GetService("ReplicatedStorage")
local guideConfig=RS:WaitForChild("FirstHatchGuide")
local Guide=require(guideConfig)
-- Same temple palette as the inventory and leaderboard (shrine redesign).
local Theme=require(RS:WaitForChild("CharacterInventory"):WaitForChild("InventoryConfig")).Theme
local player=Players.LocalPlayer
local pg=player:WaitForChild("PlayerGui")
local function make(class,props,parent)
 local o=Instance.new(class) for k,v in props do o[k]=v end o.Parent=parent return o
end
local BLACK=Color3.new(0,0,0)
local DISPLAY=Font.new("rbxasset://fonts/families/FredokaOne.json")
local BODY=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Medium)
local function stroke(parent,thickness)
 return make("UIStroke",{Color=BLACK,Thickness=thickness or 2.5,LineJoinMode=Enum.LineJoinMode.Miter,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},parent)
end
-- Card: brown lacquer frame under a roof strip with a gold eave, dark wood page, gold chip.
local CARD_W,CARD_H,COMPACT_H=380,158,82
local gui=make("ScreenGui",{Name="FirstHatchTutorial",ResetOnSpawn=false,DisplayOrder=55,Enabled=false},pg)
local card=make("Frame",{Name="GuideCard",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,132),Size=UDim2.fromOffset(CARD_W,CARD_H),BackgroundColor3=Theme.Panel,BorderSizePixel=0},gui)
stroke(card,3)
local scale=make("UIScale",{},card)
local header=make("Frame",{Name="Header",Size=UDim2.new(1,0,0,32),BackgroundColor3=Theme.Roof,BorderSizePixel=0},card)
make("Frame",{Name="Eave",Position=UDim2.new(0,0,1,-3),Size=UDim2.new(1,0,0,3),BackgroundColor3=Theme.Stud,BorderSizePixel=0},header)
local heading=make("TextLabel",{Name="Progress",Position=UDim2.fromOffset(12,1),Size=UDim2.new(1,-150,1,-4),BackgroundTransparency=1,Text="",FontFace=DISPLAY,TextSize=15,TextColor3=Theme.GoldHi,TextStrokeColor3=BLACK,TextStrokeTransparency=.2,TextXAlignment=Enum.TextXAlignment.Left},header)
local pipRow=make("Frame",{Name="Pips",AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-40,.5,-1),Size=UDim2.fromOffset(110,12),BackgroundTransparency=1},header)
make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},pipRow)
local pips={}
for i=1,#Guide.Steps do
 local pip=make("Frame",{Name="Pip"..i,LayoutOrder=i,Size=UDim2.fromOffset(8,8),BackgroundColor3=Theme.PanelEdge,BorderSizePixel=0},pipRow)
 stroke(pip,1.5);pips[i]=pip
end
local collapse=make("TextButton",{Name="Collapse",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-4,0,2),Size=UDim2.fromOffset(28,26),Text="−",TextSize=24,FontFace=DISPLAY,TextColor3=Theme.GoldHi,TextStrokeColor3=BLACK,TextStrokeTransparency=.2,BackgroundTransparency=1},header)
local page=make("Frame",{Name="Page",Position=UDim2.fromOffset(6,38),Size=UDim2.new(1,-12,1,-44),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0},card)
make("UIGradient",{Rotation=90,Color=ColorSequence.new(Theme.ScreenTop,Theme.Screen)},page)
stroke(page,2)
local title=make("TextLabel",{Name="Objective",Position=UDim2.fromOffset(10,5),Size=UDim2.new(1,-20,0,26),BackgroundTransparency=1,Text="",FontFace=DISPLAY,TextSize=22,TextColor3=Theme.PageText,TextStrokeColor3=BLACK,TextStrokeTransparency=.35,TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd},page)
local body=make("TextLabel",{Name="Instructions",Position=UDim2.fromOffset(10,33),Size=UDim2.new(1,-20,0,38),BackgroundTransparency=1,Text="",FontFace=BODY,TextSize=14,TextColor3=Theme.PageMuted,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top},page)
local chip=make("Frame",{Name="DistanceChip",Position=UDim2.new(0,10,1,-30),Size=UDim2.fromOffset(0,22),AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=Theme.Gold,BorderSizePixel=0},page)
stroke(chip,2)
make("UIPadding",{PaddingLeft=UDim.new(0,10),PaddingRight=UDim.new(0,10)},chip)
local distance=make("TextLabel",{Name="Distance",Size=UDim2.fromScale(0,1),AutomaticSize=Enum.AutomaticSize.X,BackgroundTransparency=1,Text="",FontFace=DISPLAY,TextSize=13,TextColor3=Theme.Ink},chip)
local compact,squeezed=false,false -- squeezed: auto-collapsed on a phone while the egg banner shows
local function applyLayout()
 local small=compact or squeezed
 collapse.Text=small and "+" or "−"
 body.Visible=not small;chip.Visible=not small;card.Size=UDim2.fromOffset(CARD_W,small and COMPACT_H or CARD_H)
end
collapse.Activated:Connect(function()
 if squeezed then squeezed=false;compact=false else compact=not compact end
 applyLayout()
end)
local function setProgress(current)
 for i,pip in pips do
  local done=i<current
  pip.BackgroundColor3=(done and Theme.Gold) or (i==current and Theme.GoldHi) or Theme.PanelEdge
  pip.Size=i==current and UDim2.fromOffset(11,11) or UDim2.fromOffset(8,8)
 end
end
-- The card steps aside while a menu panel (shop, egg bag, inventory, settings) is open.
local function shown_(guiName,childName)
 local g=pg:FindFirstChild(guiName)
 if not (g and g:IsA("ScreenGui") and g.Enabled) then return false end
 if not childName then
  for _,c in g:GetChildren() do if c:IsA("GuiObject") and c.Visible then return true end end
  return false
 end
 local c=g:FindFirstChild(childName)
 return c~=nil and c:IsA("GuiObject") and c.Visible
end
local function menuOpen()
 return shown_("GameHUD","EggBag") or shown_("GameMenus","Dim") or shown_("MusicSettingsUI","Panel") or shown_("CharacterInventory") or shown_("OwnerPanel")
end
local cardTop,cardTween=nil,nil
local function fitToScreen()
 local camera=workspace.CurrentCamera
 if not camera then return end
 local view=camera.ViewportSize
 -- Phones get a smaller card that sits just under the top bar instead of over the play area.
 scale.Scale=math.clamp(math.min((view.X-24)/CARD_W,view.Y/620),.55,1)
 local phone=view.Y<500
 local top=phone and 8 or 132
 -- Slide below the stolen/returning egg banner while it is showing (title row only on phones).
 local banner=pg:FindFirstChild("StolenEggBanner")
 local frame=banner and banner:IsA("ScreenGui") and banner.Enabled and banner:FindFirstChild("Frame")
 local covered=false
 if frame and frame:IsA("GuiObject") and frame.Visible then
  local bottom=frame.AbsolutePosition.Y+frame.AbsoluteSize.Y
  if bottom>0 then top=math.max(top,math.floor(bottom+6));covered=true end
 end
 local squeeze=phone and covered
 if squeeze~=squeezed then squeezed=squeeze;applyLayout() end
 if top~=cardTop then
  local first=cardTop==nil
  cardTop=top
  if cardTween then cardTween:Cancel() end
  if first then card.Position=UDim2.new(.5,0,0,top)
  else cardTween=TweenService:Create(card,TweenInfo.new(.25,Enum.EasingStyle.Quad),{Position=UDim2.new(.5,0,0,top)});cardTween:Play() end
 end
end

local fx=make("Folder",{Name="TutorialGroundTrail"},workspace)
local highlight=make("Highlight",{Name="TutorialObjective",FillTransparency=1,OutlineTransparency=.15,OutlineColor=Theme.GoldHi,DepthMode=Enum.HighlightDepthMode.Occluded,Enabled=false},fx)
-- Destination sign: a cream plate with a gold sill and a pointer, like the prompt cards.
local marker=make("BillboardGui",{Name="Destination",Size=UDim2.fromOffset(220,50),StudsOffsetWorldSpace=Vector3.new(0,3.4,0),AlwaysOnTop=true,MaxDistance=180,Enabled=false,LightInfluence=0},gui)
local tip=make("Frame",{Name="Tip",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,36),Size=UDim2.fromOffset(13,13),Rotation=45,BackgroundColor3=Theme.Gold,BorderSizePixel=0},marker)
stroke(tip,2)
local plate=make("Frame",{Name="Plate",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,2),Size=UDim2.fromOffset(0,34),AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=Theme.Card,BorderSizePixel=0,ZIndex=2},marker)
stroke(plate,2.5)
local caption=make("TextLabel",{Name="Caption",Size=UDim2.new(0,0,1,-4),AutomaticSize=Enum.AutomaticSize.X,BackgroundTransparency=1,Text="",FontFace=DISPLAY,TextSize=17,TextColor3=Theme.Ink,ZIndex=3},plate)
make("UIPadding",{PaddingLeft=UDim.new(0,12),PaddingRight=UDim.new(0,12)},caption)
make("Frame",{Name="Sill",AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,4),BackgroundColor3=Theme.Gold,BorderSizePixel=0,ZIndex=3},plate)

-- In-world guide path. An invisible anchored carrier holds every attachment.
-- Ribbons: a flat gold line on the ground along the computed route.
-- Chevrons: one arrow per Beam laid across the path so the texture points along it, sliding toward the goal.
-- Leash: links an attachment at the character's feet to the start of the route.
-- Beacon: a light column standing on the objective.
local carrier=make("Part",{Name="TrailAttachments",Size=Vector3.one,CFrame=CFrame.identity,Transparency=1,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,CastShadow=false},fx)
local SAMPLE_SPACING,MAX_TRAIL=1.6,75
local CHEVRON_GAP,CHEVRON_SIZE,CHEVRON_SPEED=3.4,3,5
local GLOW=Theme.GoldHi
local ribbons,chevrons={},{}
for i=1,48 do
 local a=make("Attachment",{Name="From"..i},carrier)
 local b=make("Attachment",{Name="To"..i},carrier)
 local beam=make("Beam",{Name="GroundTrail"..i,Attachment0=a,Attachment1=b,Enabled=false,FaceCamera=false,Width0=.5,Width1=.5,Color=ColorSequence.new(GLOW),Transparency=NumberSequence.new(.4),LightEmission=.5,LightInfluence=0,Segments=1},carrier)
 ribbons[i]={a=a,b=b,beam=beam}
end
for i=1,math.ceil(MAX_TRAIL/CHEVRON_GAP) do
 local a=make("Attachment",{Name="ChevronL"..i},carrier)
 local b=make("Attachment",{Name="ChevronR"..i},carrier)
 local beam=make("Beam",{Name="Chevron"..i,Attachment0=a,Attachment1=b,Enabled=false,FaceCamera=false,Width0=CHEVRON_SIZE,Width1=CHEVRON_SIZE,Color=ColorSequence.new(GLOW),LightEmission=.8,LightInfluence=0,Segments=1,TextureMode=Enum.TextureMode.Stretch,TextureLength=1,TextureSpeed=0},carrier)
 chevrons[i]={a=a,b=b,beam=beam}
end
local leashEnd=make("Attachment",{Name="LeashEnd"},carrier)
local leash=make("Beam",{Name="Leash",Attachment1=leashEnd,Enabled=false,FaceCamera=true,Width0=.5,Width1=.5,Color=ColorSequence.new(GLOW),Transparency=NumberSequence.new(.4),LightEmission=.5,LightInfluence=0,Segments=1},carrier)
local beaconBase=make("Attachment",{Name="BeaconBase"},carrier)
local beaconTop=make("Attachment",{Name="BeaconTop"},carrier)
local beacon=make("Beam",{Name="Beacon",Attachment0=beaconBase,Attachment1=beaconTop,Enabled=false,FaceCamera=true,Width0=2.6,Width1=.6,Color=ColorSequence.new(GLOW),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(1,1)}),LightEmission=1,LightInfluence=0,Segments=1},carrier)
local foot -- Attachment at the local character's feet (created per character)

local step,target,routeTarget,routeStart
local route,generation={},0
local samples,sampleLength={},0
local busy=false
local lastPath=-math.huge
local stopped=false
local shown=false
local connections={}
local function hideTrail()
 for _,r in ribbons do r.beam.Enabled=false end
 for _,c in chevrons do c.beam.Enabled=false end
 leash.Enabled=false;beacon.Enabled=false
 table.clear(samples);sampleLength=0
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
local function ensureFoot(root,hum)
 if foot and foot.Parent==root then return end
 if foot then foot:Destroy() end
 foot=make("Attachment",{Name="TutorialGuideFoot",Position=Vector3.new(0,-(hum.HipHeight+root.Size.Y/2)+.25,0)},root)
 leash.Attachment0=foot
end
-- Samples the route on the ground from the point closest to the player. Each sample keeps its
-- distance along the route; `gap` marks a sample that must not be joined to the one before it.
local function sampleTrail(root)
 table.clear(samples);sampleLength=0
 if #route<2 then return end
 local params=rayParams()
 -- Resume at the closest point on the route so the trail never points behind you.
 local closest,bestAlong,bestIndex=math.huge,0,1
 for i=1,#route-1 do
  local delta=route[i+1]-route[i]
  local t=delta:Dot(delta)>0 and math.clamp((root.Position-route[i]):Dot(delta)/delta:Dot(delta),0,1) or 0
  local d=(route[i]+delta*t-root.Position).Magnitude
  if d<closest then closest,bestAlong,bestIndex=d,t,i end
 end
 local travelled,previous,gap=0,nil,false
 for i=bestIndex,#route-1 do
  local start=i==bestIndex and route[i]:Lerp(route[i+1],bestAlong) or route[i]
  local delta=route[i+1]-start;local length=delta.Magnitude
  if length>.05 then
   local pieces=math.ceil(length/SAMPLE_SPACING)
   for j=(i==bestIndex and 0 or 1),pieces do
    local p=start+delta*(j/pieces)
    if previous then travelled+=(p-previous).Magnitude end
    previous=p
    if travelled>MAX_TRAIL then break end
    local hit=groundAt(p,params)
    if hit and hit.Normal.Y>.45 then
     local last=samples[#samples]
     local point=hit.Position+hit.Normal*.08
     table.insert(samples,{p=point,n=hit.Normal,s=travelled,gap=gap or (last~=nil and math.abs(point.Y-last.p.Y)>2.5)})
     gap=false
    else gap=true end
   end
  end
  if travelled>MAX_TRAIL then break end
 end
 sampleLength=#samples>0 and samples[#samples].s or 0
end
local function drawRibbons()
 for _,r in ribbons do r.beam.Enabled=false end
 local count=0
 for i=2,#samples do
  if count>=#ribbons then break end
  local s0,s1=samples[i-1],samples[i]
  local forward=s1.p-s0.p
  local side=(s0.n+s1.n).Unit:Cross(forward)
  if not s1.gap and forward.Magnitude>.05 and side.Magnitude>.01 then
   count+=1
   local r=ribbons[count]
   -- Attachment Y axes lie across the ground, keeping the ribbon flat.
   r.a.WorldCFrame=CFrame.fromMatrix(s0.p,forward.Unit,side.Unit)
   r.b.WorldCFrame=CFrame.fromMatrix(s1.p,forward.Unit,side.Unit)
   r.beam.Enabled=true
  end
 end
 gui:SetAttribute("VisibleTrailSegments",count)
end
-- Places the chevrons along the sampled route. The arrow image points right, and a Beam maps the
-- image's right edge onto the attachments' -Y axis, so each chevron beam runs across the path
-- (left to right) with its Y axis pointing back down the path.
local function drawChevrons()
 local texture=guideConfig:GetAttribute("ArrowTexture")
 local usable=type(texture)=="string" and texture~="" and #samples>=2
 local phase=player:GetAttribute("ReducedMotion") and CHEVRON_GAP*.5 or (os.clock()*CHEVRON_SPEED)%CHEVRON_GAP
 local index=2
 for k,c in chevrons do
  local s=(k-1)*CHEVRON_GAP+phase
  local placed=false
  if usable and s<sampleLength-1 then
   while index<#samples and samples[index].s<s do index+=1 end
   local s0,s1=samples[index-1],samples[index]
   if s0 and s1 and not s1.gap and s1.s>s0.s then
    local t=math.clamp((s-s0.s)/(s1.s-s0.s),0,1)
    local normal=(s0.n+s1.n).Unit
    local forward=s1.p-s0.p
    forward=(forward-normal*forward:Dot(normal))
    if forward.Magnitude>.05 then
     forward=forward.Unit
     local side=normal:Cross(forward)
     local centre=s0.p:Lerp(s1.p,t)+normal*.04
     local half=side*(CHEVRON_SIZE*.5)
     c.a.WorldCFrame=CFrame.fromMatrix(centre-half,side,-forward)
     c.b.WorldCFrame=CFrame.fromMatrix(centre+half,side,-forward)
     -- Fade in at the player's feet and out at the goal.
     local alpha=math.min(1,s/2,(sampleLength-s)/3)
     c.beam.Transparency=NumberSequence.new(1-alpha*.95)
     c.beam.Texture=texture
     placed=true
    end
   end
  end
  c.beam.Enabled=placed
 end
end
table.insert(connections,Run.RenderStepped:Connect(drawChevrons))
local function finish()
 if stopped then return end
 stopped=true;clearTarget();fx:Destroy()
 if foot then foot:Destroy();foot=nil end
 for _,c in connections do c:Disconnect() end
 if shown then
  gui.Enabled=true;card.Visible=true;heading.Text="TUTORIAL COMPLETE";title.Text="Your temple is earning!";setProgress(#Guide.Steps+1)
  body.Text="Collect more eggs, hatch stronger characters, and unlock more podiums.";distance.Text="YOU'RE READY TO GROW YOUR TEMPLE"
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
 title.Text=info.title;body.Text=note or info.body;setProgress(step)
 card.Visible=not menuOpen()
 fitToScreen()
 if not target or not target.Parent then distance.Text="FINDING YOUR NEXT OBJECTIVE...";hideTrail();return end
 highlight.Adornee=target;highlight.Enabled=true;marker.Adornee=target;marker.Enabled=true;caption.Text=info.marker
 local d=(target.Position-root.Position).Magnitude
 distance.Text=d>7 and ("FOLLOW THE GOLD ARROWS  •  "..math.floor(d).." STUDS") or (step==4 and "YOUR EGG IS INCUBATING" or "YOU'RE HERE  •  USE THE PROMPT")
 if d<=7 then hideTrail();return end
 updatePath(root,target);sampleTrail(root);drawRibbons()
 ensureFoot(root,hum)
 if samples[1] then leashEnd.WorldPosition=samples[1].p;leash.Enabled=(samples[1].p-foot.WorldPosition).Magnitude>.5 else leash.Enabled=false end
 local params=rayParams()
 local base=groundAt(target.Position,params)
 beaconBase.WorldPosition=base and base.Position or target.Position
 beaconTop.WorldPosition=beaconBase.WorldPosition+Vector3.new(0,16,0)
 beacon.Enabled=true
end))
table.insert(connections,player:GetAttributeChangedSignal("TutorialCompleted"):Connect(function()if player:GetAttribute("TutorialCompleted") then finish() end end))
gui.Destroying:Connect(function()
 stopped=true;generation+=1
 for _,c in connections do c:Disconnect() end
 if fx.Parent then fx:Destroy() end
 if foot then foot:Destroy();foot=nil end
end)
