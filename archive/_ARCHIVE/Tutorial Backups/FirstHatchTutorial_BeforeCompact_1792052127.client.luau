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

-- In-world guide: one straight Beam from an Attachment on the player to an Attachment on the
-- objective. No pathfinding and no animation. The arrow texture points toward Attachment0, so
-- Attachment0 sits on the target and Attachment1 on the player.
local ARROW="rbxassetid://86109313256799"
local guide=make("Beam",{Name="GuideBeam",Enabled=false,FaceCamera=true,Width0=2.2,Width1=2.2,Color=ColorSequence.new(Theme.GoldHi),Transparency=NumberSequence.new(.1),LightEmission=.6,LightInfluence=0,Segments=1,Texture=ARROW,TextureMode=Enum.TextureMode.Static,TextureLength=3,TextureSpeed=0},fx)
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
local function finish()
 if stopped then return end
 stopped=true;clearTarget();fx:Destroy()
 if foot then foot:Destroy();foot=nil end
 if goal then goal:Destroy();goal=nil end
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
 ensureFoot(root);ensureGoal(target);guide.Enabled=true
end))
table.insert(connections,player:GetAttributeChangedSignal("TutorialCompleted"):Connect(function()if player:GetAttribute("TutorialCompleted") then finish() end end))
gui.Destroying:Connect(function()
 stopped=true
 for _,c in connections do c:Disconnect() end
 if fx.Parent then fx:Destroy() end
 if foot then foot:Destroy();foot=nil end
 if goal then goal:Destroy();goal=nil end
end)
