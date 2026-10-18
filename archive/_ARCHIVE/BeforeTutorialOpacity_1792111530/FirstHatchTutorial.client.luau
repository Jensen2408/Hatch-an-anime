-- A local first-hatch guide. No client requests can grant progress or rewards.
local Players=game:GetService("Players")
local Run=game:GetService("RunService")
local Pathfinding=game:GetService("PathfindingService")
local TweenService=game:GetService("TweenService")
local RS=game:GetService("ReplicatedStorage")
local guideConfig=RS:WaitForChild("FirstHatchGuide")
local Guide=require(guideConfig)
local tourRemote=RS:WaitForChild("FirstHatchTutorialAction")
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
-- Card: a small see-through temple-brown strip: step tag + objective on one line, distance under it.
-- Card (house style): plate + orange strip + black outline. Big step number, bold objective,
-- the full instruction under it, a slim progress bar and a distance hint.
local CARD_W,CARD_H=380,112
local PLATE=Color3.fromRGB(38,56,68)
local ORANGE=Color3.fromRGB(255,150,30)
local gui=make("ScreenGui",{Name="FirstHatchTutorial",ResetOnSpawn=false,DisplayOrder=55,Enabled=false,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets},pg)
local card=make("Frame",{Name="GuideCard",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,72),Size=UDim2.fromOffset(CARD_W,CARD_H),BackgroundColor3=PLATE,BorderSizePixel=0,Active=true},gui)
stroke(card,4)
make("ImageLabel",{Name="Studs",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image="rbxassetid://132561191216691",ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(26,26),ImageTransparency=.85},card)
make("Frame",{Name="Strip",Size=UDim2.new(1,0,0,6),BackgroundColor3=ORANGE,BorderSizePixel=0,ZIndex=2},card)
local scale=make("UIScale",{},card)
local tag=make("Frame",{Name="StepTag",Position=UDim2.fromOffset(14,20),Size=UDim2.fromOffset(60,60),BackgroundColor3=Color3.fromRGB(255,176,40),BorderSizePixel=0,ZIndex=2},card)
stroke(tag,3)
make("ImageLabel",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image="rbxassetid://132561191216691",ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(20,20),ImageTransparency=.2,ZIndex=2},tag)
local heading=make("TextLabel",{Name="Progress",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Text="",FontFace=DISPLAY,TextSize=34,TextColor3=Color3.new(1,1,1),ZIndex=3},tag)
make("UIStroke",{Color=BLACK,Thickness=3},heading)
local title=make("TextLabel",{Name="Objective",Position=UDim2.fromOffset(88,16),Size=UDim2.new(1,-100,0,28),BackgroundTransparency=1,Text="",FontFace=DISPLAY,TextSize=24,TextColor3=Color3.new(1,1,1),TextXAlignment=Enum.TextXAlignment.Left,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=2},card)
make("UIStroke",{Color=BLACK,Thickness=2.5},title)
local body=make("TextLabel",{Name="Instruction",Position=UDim2.fromOffset(88,44),Size=UDim2.new(1,-100,0,36),BackgroundTransparency=1,Text="",FontFace=BODY,TextSize=14,TextColor3=Color3.fromRGB(215,228,236),TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,ZIndex=2},card)
local track=make("Frame",{Name="Track",Position=UDim2.new(0,14,1,-20),Size=UDim2.new(.55,0,0,8),BackgroundColor3=Color3.fromRGB(16,24,30),BorderSizePixel=0,ZIndex=2},card)
stroke(track,2)
local fill=make("Frame",{Name="Fill",Size=UDim2.fromScale(0,1),BackgroundColor3=ORANGE,BorderSizePixel=0,ZIndex=3},track)
local distance=make("TextLabel",{Name="Distance",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,1,-27),Size=UDim2.new(.4,-14,0,20),BackgroundTransparency=1,Text="",FontFace=DISPLAY,TextSize=14,TextColor3=Color3.fromRGB(255,206,60),TextXAlignment=Enum.TextXAlignment.Right,TextTruncate=Enum.TextTruncate.AtEnd,ZIndex=2},card)
make("UIStroke",{Color=BLACK,Thickness=2},distance)
local squeezed=false
local function applyLayout() end
local function setProgress(n)
 local k=math.clamp(((n or 1)-1)/#Guide.Steps,0,1)
 TweenService:Create(fill,TweenInfo.new(.35,Enum.EasingStyle.Quad),{Size=UDim2.fromScale(math.max(k,.03),1)}):Play()
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
 local phone=view.Y<500 or (game:GetService("UserInputService").TouchEnabled and view.X<1100)
 local phone_=phone
 -- Phones get a smaller card that sits just under the top bar instead of over the play area.
 scale.Scale=phone_ and .5 or .8
  local top=phone and 6 or 72
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
local highlight=make("Highlight",{Name="TutorialObjective",FillTransparency=1,OutlineTransparency=.45,OutlineColor=Theme.GoldHi,DepthMode=Enum.HighlightDepthMode.Occluded,Enabled=false},fx)
-- Destination sign: a cream plate with a gold sill and a pointer, like the prompt cards.
local marker=make("BillboardGui",{Name="Destination",Size=UDim2.fromOffset(160,36),StudsOffsetWorldSpace=Vector3.new(0,3.4,0),AlwaysOnTop=true,MaxDistance=180,Enabled=false,LightInfluence=0},gui)
local tip=make("Frame",{Name="Tip",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,0,0,26),Size=UDim2.fromOffset(9,9),Rotation=45,BackgroundColor3=Theme.Gold,BorderSizePixel=0},marker)
stroke(tip,2)
local plate=make("Frame",{Name="Plate",AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,2),Size=UDim2.fromOffset(0,24),AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=Theme.Card,BackgroundTransparency=.25,BorderSizePixel=0,ZIndex=2},marker)
stroke(plate,2.5)
local caption=make("TextLabel",{Name="Caption",Size=UDim2.new(0,0,1,-4),AutomaticSize=Enum.AutomaticSize.X,BackgroundTransparency=1,Text="",FontFace=DISPLAY,TextSize=13,TextColor3=Theme.Ink,ZIndex=3},plate)
make("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8)},caption)
make("Frame",{Name="Sill",AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,3),BackgroundColor3=Theme.Gold,BorderSizePixel=0,ZIndex=3},plate)

-- In-world guide: one straight Beam from an Attachment on the player to an Attachment on the
-- objective. No pathfinding and no animation. The arrow texture points toward Attachment0, so
-- Attachment0 sits on the target and Attachment1 on the player.
local ARROW="rbxassetid://86109313256799"
local guide=make("Beam",{Name="GuideBeam",Enabled=false,FaceCamera=true,Width0=1.5,Width1=1.5,Color=ColorSequence.new(Theme.GoldHi),Transparency=NumberSequence.new(.45),LightEmission=.4,LightInfluence=0,Segments=1,Texture=ARROW,TextureMode=Enum.TextureMode.Static,TextureLength=3,TextureSpeed=0},fx)
local goal -- Attachment on the current target part
local foot -- Attachment on the local character
local step,target
local stopped=false
local shown=false
local connections={}
local function hideTrail()
 guide.Enabled=false
end
local function clearTarget()
 hideTrail()
 if goal then goal:Destroy();goal=nil end
 highlight.Enabled=false;highlight.Adornee=nil;marker.Enabled=false;marker.Adornee=nil
end
-- Destination labels yield to the real interaction card at the same anchor.
local function hasInteractionCard(part)
 for _,bb in pg:GetChildren() do
  if bb:IsA("BillboardGui") and bb.Name=="PromptCard" and bb.Enabled then
   local adorn=bb.Adornee
   if adorn==part or (adorn and adorn:IsDescendantOf(part)) then return true end
  end
 end
 return false
end
local function hatchCameraActive()
 local cinematic=pg:FindFirstChild("CinematicHatchUI")
 return cinematic and cinematic:GetAttribute("Active")==true
end
-- Hide immediately at camera takeover rather than waiting for the next guide update.
local function watchHatchUI(cinematic)
 if cinematic.Name~="CinematicHatchUI" then return end
 local function changed()
  if cinematic:GetAttribute("Active")==true then gui.Enabled=false;clearTarget() end
 end
 table.insert(connections,cinematic:GetAttributeChangedSignal("Active"):Connect(changed))
 changed()
end
local cinematic=pg:FindFirstChild("CinematicHatchUI")
if cinematic then watchHatchUI(cinematic) end
table.insert(connections,pg.ChildAdded:Connect(watchHatchUI))
local function ensureFoot(root)
 if foot and foot.Parent==root then return end
 if foot then foot:Destroy() end
 foot=make("Attachment",{Name="TutorialGuideFoot",Position=Vector3.new(0,-1.5,0)},root)
 guide.Attachment1=foot
end
local function ensureGoal(part)
 if goal and goal.Parent==part then return end
 if goal then goal:Destroy() end
 goal=make("Attachment",{Name="TutorialGuideGoal"},part)
 guide.Attachment0=goal
end

-- Final UI tour. Keep the existing world guide and compact card unchanged.
local tourCanvas=make("Frame",{Name="UpgradeTour",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=false},gui)
local focus=make("Frame",{Name="Focus",BackgroundTransparency=1,BorderSizePixel=0,Visible=false,ZIndex=20},tourCanvas)
make("UIStroke",{Color=Theme.GoldHi,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},focus)
local coach=make("Frame",{Name="Coach",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-8),Size=UDim2.fromOffset(340,116),BackgroundColor3=Theme.Screen,BorderSizePixel=0,ZIndex=30},tourCanvas)
stroke(coach,2)
local coachTitle=make("TextLabel",{Name="Title",Position=UDim2.fromOffset(12,7),Size=UDim2.new(1,-24,0,22),BackgroundTransparency=1,FontFace=DISPLAY,TextSize=16,TextColor3=Theme.GoldHi,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=31},coach)
local coachBody=make("TextLabel",{Name="Body",Position=UDim2.fromOffset(12,31),Size=UDim2.new(1,-24,0,48),BackgroundTransparency=1,FontFace=BODY,TextSize=13,TextColor3=Theme.PageText,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,ZIndex=31},coach)
local coachHint=make("TextLabel",{Name="Hint",Position=UDim2.new(0,12,1,-30),Size=UDim2.new(1,-132,0,22),BackgroundTransparency=1,FontFace=BODY,TextSize=11,TextColor3=Theme.GoldHi,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=31},coach)
local nextButton=make("TextButton",{Name="Next",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-10,1,-8),Size=UDim2.fromOffset(100,27),BackgroundColor3=Theme.Gold,TextColor3=Theme.Ink,FontFace=DISPLAY,TextSize=14,Text="NEXT",BorderSizePixel=0,ZIndex=32},coach)
stroke(nextButton,2)
local tourPanel,originalPanelPosition=nil,nil
local panelLift=0
local function restoreTourPanel()
 if tourPanel and tourPanel.Parent and originalPanelPosition then tourPanel.Position=originalPanelPosition end
 tourPanel=nil;originalPanelPosition=nil;panelLift=0
end
local nextAction=nil
local lastAck,ackStage=-math.huge,nil
local viewedTarget,viewedSince=nil,0
local function visibleUI(obj)
 if not obj or not obj:IsA("GuiObject") or obj.AbsoluteSize.X<=0 or obj.AbsoluteSize.Y<=0 then return false end
 local ancestor=obj
 while ancestor and ancestor~=pg do
  if ancestor:IsA("GuiObject") and not ancestor.Visible then return false end
  if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return false end
  ancestor=ancestor.Parent
 end
 return ancestor==pg
end
local function acknowledge(action)
 if ackStage==step and os.clock()-lastAck<1 then return end
 lastAck=os.clock();ackStage=step
 tourRemote:FireServer(action)
end
table.insert(connections,nextButton.Activated:Connect(function()
 if nextAction and nextButton.Interactable and visibleUI(viewedTarget) then acknowledge(nextAction) end
end))
local function updateTour()
 clearTarget()
 card.Visible=false;tourCanvas.Visible=true;gui.Enabled=true;shown=true
 local menus=pg:FindFirstChild("GameMenus")
 gui.DisplayOrder=math.max(65,menus and menus.DisplayOrder+2 or 65)
 local compact=tourCanvas.AbsoluteSize.Y<500
 coach.Size=UDim2.fromOffset(math.min(340,math.max(220,tourCanvas.AbsoluteSize.X-20)),compact and 112 or 116)
 coach.Position=UDim2.new(.5,0,1,compact and -4 or -8)
 coachBody.Size=compact and UDim2.new(1,-132,0,58) or UDim2.new(1,-24,0,48)
 coachBody.TextSize=compact and 12 or 13
 coachHint.Position=UDim2.new(0,12,1,compact and -18 or -30)
 coachHint.Size=UDim2.new(1,-132,0,compact and 14 or 22)
 nextButton.Size=UDim2.fromOffset(100,compact and 44 or 27)
 local panel=menus and menus:FindFirstChild("Plot")
 local plotOpen=visibleUI(panel)
 local page=plotOpen and panel:GetAttribute("Page")
 local live=panel and panel:FindFirstChild("Live")
 local wanted
 local info=Guide.Steps[step]
 coachTitle.Text=step.."/"..#Guide.Steps.."  "..info.title
 coachBody.Text=info.body
 coachHint.Text="Use the highlighted button"
 nextButton.Visible=false;nextAction=nil
 if not plotOpen then
  local side=menus and menus:FindFirstChild("SideButtons")
  wanted=side and side:FindFirstChild("PlotButton")
  coachBody.Text="You can add more upgrades to your plot. Press Plot to find them."
 elseif step==9 then
  acknowledge("PlotOpened")
 elseif page~="upgrades" then
  wanted=live and live:FindFirstChild("UpgradesTab",true)
  coachBody.Text="Press Upgrades to see your temple and incubator upgrades."
 elseif step==10 then
  acknowledge("UpgradesOpened")
 else
  wanted=live and live:FindFirstChild(step==11 and "TempleUpgrades" or "IncubatorUpgrades",true)
  nextAction=step==11 and "TempleSeen" or "IncubatorsSeen"
  nextButton.Text=step==11 and "NEXT" or "GOT IT!"
  nextButton.Visible=visibleUI(wanted)
  coachHint.Text="No purchase needed"
 end
 if wanted~=viewedTarget then viewedTarget=wanted;viewedSince=os.clock() end
 nextButton.Interactable=nextButton.Visible and os.clock()-viewedSince>=.8
 nextButton.AutoButtonColor=nextButton.Interactable
 focus.Visible=visibleUI(wanted)
 -- On short screens, lift the menu only enough to keep the highlighted row above the coach.
 if plotOpen then
  if tourPanel~=panel then restoreTourPanel();tourPanel=panel;originalPanelPosition=panel.Position end
  local lift=0
  if compact and focus.Visible and wanted:IsDescendantOf(panel) then
   local rowBottom=wanted.AbsolutePosition.Y+wanted.AbsoluteSize.Y+panelLift
   local topRoom=math.max(0,panel.AbsolutePosition.Y+panelLift-tourCanvas.AbsolutePosition.Y-4)
   lift=math.clamp(rowBottom-coach.AbsolutePosition.Y+10,0,topRoom)
  end
  panelLift=lift;panel.Position=originalPanelPosition+UDim2.fromOffset(0,-lift)
 else restoreTourPanel() end
 if focus.Visible then
  local p=wanted.AbsolutePosition-tourCanvas.AbsolutePosition
  focus.Position=UDim2.fromOffset(p.X-3,p.Y-3)
  focus.Size=UDim2.fromOffset(wanted.AbsoluteSize.X+6,wanted.AbsoluteSize.Y+6)
 end
end

local function finish()
 if stopped then return end
 stopped=true;clearTarget();fx:Destroy()
 tourCanvas.Visible=false;gui.DisplayOrder=55;restoreTourPanel()
 if foot then foot:Destroy();foot=nil end
 if goal then goal:Destroy();goal=nil end
 for _,c in connections do c:Disconnect() end
 if shown then
  gui.Enabled=true;card.Visible=true;heading.Text="✓";title.Text="You’re ready to grow!";setProgress(#Guide.Steps+1)
  body.Text="Collect more eggs, hatch stronger characters, and unlock more podiums.";distance.Text="Find upgrades in Plot → Upgrades"
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
 if not ready then gui.Enabled=false;tourCanvas.Visible=false;restoreTourPanel();clearTarget();return end
 local newStep,newTarget,note,revealing=Guide.Resolve(player)
 if newStep>#Guide.Steps then finish();return end
 if newStep~=step or newTarget~=target then clearTarget();step=newStep;target=newTarget end
 gui:SetAttribute("Step",step)
 if step>=9 then updateTour();return end
 tourCanvas.Visible=false;gui.DisplayOrder=55
 gui.Enabled=not revealing and not hatchCameraActive();highlight.Enabled=false;marker.Enabled=false
 if revealing or hatchCameraActive() then hideTrail();return end
 shown=true
 local info=Guide.Steps[step];heading.Text=tostring(step)
 title.Text=info.title;body.Text=note or info.body;setProgress(step)
 card.Visible=not menuOpen()
 fitToScreen()
 if menuOpen() then hideTrail();return end
 if not target or not target.Parent then distance.Text="Finding your next goal…";hideTrail();return end
 highlight.Adornee=target;highlight.Enabled=true;marker.Adornee=target;caption.Text=info.marker
 local d=(target.Position-root.Position).Magnitude
 marker.Enabled=d>7 and not hasInteractionCard(target)
 distance.Text=d>7 and ("→ "..math.floor(d).." studs") or (step==4 and "Incubating…" or "You're here • use the prompt")
 if d<=7 then hideTrail();return end
 ensureFoot(root);ensureGoal(target);guide.Enabled=true
end))
table.insert(connections,player:GetAttributeChangedSignal("TutorialCompleted"):Connect(function()if player:GetAttribute("TutorialCompleted") then finish() end end))
gui.Destroying:Connect(function()
 restoreTourPanel()
 stopped=true
 for _,c in connections do c:Disconnect() end
 if fx.Parent then fx:Destroy() end
 if foot then foot:Destroy();foot=nil end
 if goal then goal:Destroy();goal=nil end
end)
