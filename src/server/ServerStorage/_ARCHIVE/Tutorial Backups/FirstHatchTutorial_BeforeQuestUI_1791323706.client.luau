
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local player=Players.LocalPlayer
local playerGui=player:WaitForChild("PlayerGui")
local gui=Instance.new("ScreenGui")
gui.Name="FirstHatchGuide";gui.ResetOnSpawn=false;gui.DisplayOrder=35;gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=playerGui
local white=Color3.fromRGB(242,245,250)
local muted=Color3.fromRGB(165,176,194)
local accent=Color3.fromRGB(255,207,109)
local function label(parent,content,size,color)
 local t=Instance.new("TextLabel");t.BackgroundTransparency=1;t.Text=content;t.Font=Enum.Font.GothamMedium;t.TextSize=size;t.TextColor3=color;t.TextXAlignment=Enum.TextXAlignment.Left;t.Parent=parent;return t
end
local function rounded(frame,radius)
 local c=Instance.new("UICorner");c.CornerRadius=UDim.new(0,radius);c.Parent=frame
end
local help=Instance.new("TextButton");help.Name="HowToPlay";help.AnchorPoint=Vector2.new(1,0);help.Position=UDim2.new(1,-22,0,74);help.Size=UDim2.fromOffset(126,36);help.BackgroundColor3=Color3.fromRGB(18,23,31);help.Text="HOW TO PLAY";help.TextColor3=white;help.Font=Enum.Font.GothamBold;help.TextSize=11;help.Parent=gui;rounded(help,8)
local helpBorder=Instance.new("UIStroke");helpBorder.Color=Color3.fromRGB(65,75,91);helpBorder.Parent=help
local card=Instance.new("Frame");card.Name="GuideCard";card.Position=UDim2.new(0,22,.38,0);card.Size=UDim2.fromOffset(340,242);card.BackgroundColor3=Color3.fromRGB(13,18,26);card.BackgroundTransparency=.06;card.BorderSizePixel=0;card.Visible=false;card.Parent=gui;rounded(card,12)
local border=Instance.new("UIStroke");border.Color=Color3.fromRGB(58,69,86);border.Transparency=.2;border.Parent=card
local scale=Instance.new("UIScale");scale.Parent=card
local eyebrow=label(card,"YOUR FIRST HATCH",11,accent);eyebrow.Position=UDim2.fromOffset(20,18);eyebrow.Size=UDim2.fromOffset(225,20);eyebrow.Font=Enum.Font.GothamBold
local dismiss=Instance.new("TextButton");dismiss.Name="Dismiss";dismiss.BackgroundTransparency=1;dismiss.Position=UDim2.new(1,-38,0,12);dismiss.Size=UDim2.fromOffset(26,26);dismiss.Text="×";dismiss.TextSize=23;dismiss.TextColor3=muted;dismiss.Parent=card
local title=label(card,"",23,white);title.Font=Enum.Font.GothamBold;title.Position=UDim2.fromOffset(20,48);title.Size=UDim2.fromOffset(300,34)
local body=label(card,"",14,muted);body.Position=UDim2.fromOffset(20,90);body.Size=UDim2.fromOffset(296,64);body.TextWrapped=true;body.TextYAlignment=Enum.TextYAlignment.Top;body.LineHeight=1.18
local hint=label(card,"",12,accent);hint.Position=UDim2.fromOffset(20,158);hint.Size=UDim2.fromOffset(300,24)
local track=Instance.new("Frame");track.BorderSizePixel=0;track.BackgroundColor3=Color3.fromRGB(37,45,57);track.Position=UDim2.fromOffset(20,193);track.Size=UDim2.fromOffset(300,3);track.Parent=card
local fill=Instance.new("Frame");fill.BorderSizePixel=0;fill.BackgroundColor3=accent;fill.Size=UDim2.fromScale(0,1);fill.Parent=track
local count=label(card,"",11,muted);count.Position=UDim2.fromOffset(20,208);count.Size=UDim2.fromOffset(180,18)
local nextButton=Instance.new("TextButton");nextButton.Name="Finish";nextButton.BackgroundTransparency=1;nextButton.Text="LET'S GO  ›";nextButton.TextColor3=white;nextButton.Font=Enum.Font.GothamBold;nextButton.TextSize=11;nextButton.Position=UDim2.fromOffset(220,204);nextButton.Size=UDim2.fromOffset(100,26);nextButton.Visible=false;nextButton.Parent=card
local highlight=Instance.new("Highlight");highlight.Name="TutorialTarget";highlight.FillTransparency=1;highlight.OutlineColor=accent;highlight.OutlineTransparency=.15;highlight.DepthMode=Enum.HighlightDepthMode.Occluded;highlight.Enabled=false;highlight.Parent=workspace
local marker=Instance.new("BillboardGui");marker.Name="TutorialMarker";marker.Size=UDim2.fromOffset(170,58);marker.StudsOffsetWorldSpace=Vector3.new(0,3.6,0);marker.AlwaysOnTop=true;marker.MaxDistance=350;marker.Enabled=false;marker.Parent=gui
local markerText=label(marker,"",13,accent);markerText.Size=UDim2.fromScale(1,1);markerText.Font=Enum.Font.GothamBold;markerText.TextXAlignment=Enum.TextXAlignment.Center;markerText.TextStrokeTransparency=.05
local steps={
 {"Find a river egg","Follow the river and collect an egg using its interaction prompt.","COLLECT AN EGG","RIVER EGG"},
 {"Load your incubator","Equip the egg from your inventory. Follow the marker to your incubator and choose Insert egg.","EQUIP EGG → INSERT","YOUR INCUBATOR"},
 {"Let it incubate","The glass closes while the chamber prepares your egg. The timer above it shows the remaining time.","WAIT FOR THE TIMER","INCUBATING"},
 {"Hatch your egg","Your egg is ready. Use Hatch at the incubator to begin the reveal.","PRESS HATCH","READY TO HATCH"},
 {"Collect your character","After the reveal, the glass opens. Collect your character from inside the chamber.","COLLECT CHARACTER","YOUR NEW CHARACTER"},
 {"Place it in your temple","Equip your character, then use an empty platform inside your temple. Placed characters earn cash automatically.","EQUIP CHARACTER → PLACE","EMPTY PLATFORM"},
}
local step=1
local active=true
local ready=false
local target
local chamber
local function tools(predicate)
 for _,container in {player:FindFirstChild("Backpack"),player.Character} do
  if container then for _,o in container:GetChildren() do if o:IsA("Tool") and predicate(o) then return o end end end
 end
end
local function eggTool() return tools(function(o)return o:GetAttribute("EggType")~=nil and not o:GetAttribute("Hatched") end) end
local function rewardTool() return tools(function(o)return o:GetAttribute("Hatched")==true end) end
local function plot()
 local plots=workspace:FindFirstChild("Plots");if not plots then return end
 for _,p in plots:GetChildren() do if p:GetAttribute("OwnerUserId")==player.UserId then return p end end
end
local function occupied(p)
 local slots=p and p:FindFirstChild("Slots");if slots then for _,s in slots:GetChildren() do if s:GetAttribute("Occupied") then return true end end end
 return false
end
local function findChamber(p)
 local all=p and p:FindFirstChild("Chambers");if not all then return end
 if chamber and chamber.Parent==all then return chamber end
 for _,m in all:GetChildren() do if m:GetAttribute("Status")~="Ready" then chamber=m;return m end end
 chamber=all:FindFirstChild("Chamber1");return chamber
end
local function targetPart(o)
 if not o then return end
 if o:IsA("BasePart") then return o end
 return o:FindFirstChild("CollectAnchor",true) or o:FindFirstChild("HatchButton",true) or o:FindFirstChildWhichIsA("BasePart",true)
end
local function showTarget(o,caption)
 target=o
 local part=targetPart(o)
 highlight.Adornee=o;highlight.Enabled=active and part~=nil and step<=6
 marker.Adornee=part;marker.Enabled=highlight.Enabled
 markerText.Text=caption.."\n↓"
end
local function render()
 gui:SetAttribute("Step",step)
 nextButton.Visible=step==7
 if step==7 then
  eyebrow.Text="FIRST HATCH COMPLETE";title.Text="Your temple is alive."
  body.Text="Collect more eggs, hatch new characters, and fill your temple. Upgrade your incubators and temple using their interaction prompts."
  hint.Text="BUILD YOUR COLLECTION"
  count.Text="YOU KNOW THE LOOP"
  showTarget(nil,"")
 else
  eyebrow.Text="YOUR FIRST HATCH"
  title.Text=steps[step][1];body.Text=steps[step][2];hint.Text=steps[step][3]
  count.Text=string.format("STEP %d OF 6",step)
 end
 TweenService:Create(fill,TweenInfo.new(.35),{Size=UDim2.fromScale(math.min(1,(step-1)/6),1)}):Play()
end
local function advance() step+=1;render() end
local function hide()
 active=false;card.Visible=false;highlight.Enabled=false;marker.Enabled=false
end
dismiss.Activated:Connect(hide);nextButton.Activated:Connect(hide)
help.Activated:Connect(function()step=1;active=true;chamber=nil;card.Visible=ready;render()end)
render()
local elapsed=0
local connection
connection=RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt;if elapsed<.25 then return end;elapsed=0
 local camera=workspace.CurrentCamera
 if camera then scale.Scale=math.min(1,(camera.ViewportSize.X-32)/340,camera.ViewportSize.Y/660) end
 local loading=playerGui:FindFirstChild("AnimeEggPreloader")~=nil
 ready=not loading and player.Character~=nil
 help.Visible=ready;card.Visible=ready and active
 if not ready or not active or step>6 then return end
 local p=plot();local h=findChamber(p);local state=h and h:GetAttribute("Status")
 marker.StudsOffsetWorldSpace=Vector3.new(0,3.6+math.sin(os.clock()*2)*.12,0)
 if state=="HatchReveal" or state=="Revealing" then card.Visible=false;marker.Enabled=false;highlight.Enabled=false;return end
 if step==1 then
  if eggTool() or state=="Incubating" or state=="Loaded" then advance();return end
  local river=workspace:FindFirstChild("WaterfallEggs")
  local root=player.Character:FindFirstChild("HumanoidRootPart")
  local best,distance=nil,math.huge
  if river and root then for _,egg in river:GetChildren() do local part=targetPart(egg);if part then local d=(part.Position-root.Position).Magnitude;if d<distance then best=egg;distance=d end end end end
  showTarget(best,"RIVER EGG")
 elseif step==2 then
  if state and state~="Ready" then advance();return end
  showTarget(h,"YOUR INCUBATOR")
 elseif step==3 then
  if state=="Loaded" or state=="HatchReveal" or state=="Revealing" or state=="AwaitingPickup" then advance();return end
  local endTime=h and h:GetAttribute("CycleEnd")
  if endTime then hint.Text=string.format("READY IN %ds",math.max(0,math.ceil(endTime-workspace:GetServerTimeNow()))) end
  showTarget(h,"INCUBATING")
 elseif step==4 then
  if state=="AwaitingPickup" or rewardTool() then advance();return end
  showTarget(h,"READY TO HATCH")
 elseif step==5 then
  if rewardTool() or occupied(p) then advance();return end
  showTarget(h and (h:FindFirstChild("EggPickupAnchor") or h),"COLLECT CHARACTER")
 elseif step==6 then
  if occupied(p) then advance();return end
  local empty
  local slots=p and p:FindFirstChild("Slots")
  if slots then for _,slot in slots:GetChildren() do if not slot:GetAttribute("Occupied") then empty=slot:FindFirstChild("Platform");break end end end
  showTarget(empty,"EMPTY PLATFORM")
 end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local part=targetPart(target)
 if part and root and step~=3 then
  hint.Text=steps[step][3].."  •  "..math.floor((part.Position-root.Position).Magnitude).." STUDS"
 end
end)
gui.Destroying:Connect(function()connection:Disconnect();highlight:Destroy()end)
