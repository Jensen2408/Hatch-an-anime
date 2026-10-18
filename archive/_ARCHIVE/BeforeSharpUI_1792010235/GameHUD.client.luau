-- GameHUD: custom hotbar (replaces Roblox's), egg backpack with selling, and the top-centre night timer.
local Players=game:GetService("Players") local RS=game:GetService("ReplicatedStorage") local SG=game:GetService("StarterGui")
local UIS=game:GetService("UserInputService") local TS=game:GetService("TweenService") local RunService=game:GetService("RunService")
local player=Players.LocalPlayer local pg=player:WaitForChild("PlayerGui")
local Catalog=require(RS:WaitForChild("CharacterCatalog"))
local INK=Color3.fromRGB(29,20,32) local CREAM=Color3.fromRGB(255,243,220) local GOLD=Color3.fromRGB(255,200,80)
local FONT=Font.new("rbxasset://fonts/families/FredokaOne.json") local BOLD=Font.new("rbxasset://fonts/families/GothamSSm.json",Enum.FontWeight.Bold)
local RARITY={Common=Color3.fromRGB(190,195,205),Uncommon=Color3.fromRGB(109,225,132),Rare=Color3.fromRGB(98,172,255),Epic=Color3.fromRGB(197,126,255),Legendary=Color3.fromRGB(255,207,92),Limited=Color3.fromRGB(255,60,90)}
local function make(c,p,parent) local o=Instance.new(c) for k,v in p do o[k]=v end if parent then o.Parent=parent end return o end
local function round(o,r) return make("UICorner",{CornerRadius=r or UDim.new(0,12)},o) end
local function stroke(o,t,c) return make("UIStroke",{Thickness=t or 3,Color=c or INK,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},o) end
local function tw(o,t,p,st,dir) local x=TS:Create(o,TweenInfo.new(t,st or Enum.EasingStyle.Quad,dir or Enum.EasingDirection.Out),p) x:Play() return x end
local function money(n) local u={{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}} for _,x in u do if n>=x[1] then local v=n/x[1] local t=v>=100 and string.format("%d",v) or string.format("%.1f",v) return "$"..t:gsub("%.0$","")..x[2] end end return "$"..math.floor(n) end

local gui=make("ScreenGui",{Name="GameHUD",ResetOnSpawn=false,DisplayOrder=40,ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets},pg)

-- keep Roblox's own backpack hidden (other scripts sometimes re-enable all core UI)
task.spawn(function() while true do pcall(SG.SetCoreGuiEnabled,SG,Enum.CoreGuiType.Backpack,false) task.wait(1) end end)

---------------------------------------------------------------- tool preview (3D icon)
local function preview(tool,parent)
 local vp=make("ViewportFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,LightColor=Color3.new(1,1,1),Ambient=Color3.fromRGB(190,190,200),LightDirection=Vector3.new(-1,-1,-1)},parent)
 if tool.TextureId~="" then vp:Destroy() return make("ImageLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=tool.TextureId,ScaleType=Enum.ScaleType.Fit},parent) end
 local m=Instance.new("Model")
 for _,d in tool:GetDescendants() do if d:IsA("BasePart") and d.Name~="Handle" and d.Transparency<1 then local c=d:Clone() for _,k in c:GetChildren() do if not (k:IsA("DataModelMesh") or k:IsA("Decal") or k:IsA("SurfaceAppearance") or k:IsA("Texture")) then k:Destroy() end end c.Anchored=true c.Parent=m end end
 if #m:GetChildren()==0 then local h=tool:FindFirstChild("Handle") if h then local c=h:Clone() for _,k in c:GetChildren() do if not k:IsA("DataModelMesh") then k:Destroy() end end c.Transparency=0 c.Parent=m end end
 m.Parent=vp
 local cf,size=m:GetBoundingBox() local cam=make("Camera",{FieldOfView=30},vp) vp.CurrentCamera=cam
 local r=math.max(size.X,size.Y,size.Z)
 cam.CFrame=CFrame.lookAt(cf.Position+cf.LookVector*0+Vector3.new(0.6,0.35,1).Unit*r*2.1,cf.Position)
 return vp
end
local function info(tool)
 local id=tool:GetAttribute("EggType") or tool:GetAttribute("CharacterId")
 local e=id and Catalog.ById[id]
 local rarity=tool:GetAttribute("Rarity") or (e and e.Rarity)
 local name=tool.Name
 if tool:GetAttribute("EggType") and not tool:GetAttribute("CharacterId") then name=(tool:GetAttribute("UnknownEgg") and "Unknown Egg") or ((e and e.Id or id).." Egg") end
 return name,rarity,tool:GetAttribute("EggType")~=nil and not tool:GetAttribute("CharacterId")
end

---------------------------------------------------------------- hotbar
local bar=make("Frame",{Name="Hotbar",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-10),Size=UDim2.fromOffset(0,78),AutomaticSize=Enum.AutomaticSize.X,BackgroundTransparency=1},gui)
make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),HorizontalAlignment=Enum.HorizontalAlignment.Center,SortOrder=Enum.SortOrder.LayoutOrder},bar)
local MAX=9 local slots={}
local function backpack() return player:FindFirstChildOfClass("Backpack") end
local function equipped() local c=player.Character return c and c:FindFirstChildOfClass("Tool") end
local order={} -- stable order of tools
local function allTools()
 local list={} local bp=backpack() if bp then for _,t in bp:GetChildren() do if t:IsA("Tool") then table.insert(list,t) end end end
 local e=equipped() if e then table.insert(list,e) end
 for i=#order,1,-1 do if not table.find(list,order[i]) then table.remove(order,i) end end
 for _,t in list do if not table.find(order,t) then table.insert(order,t) end end
 return order
end
local function toggle(tool) local hum=player.Character and player.Character:FindFirstChildOfClass("Humanoid") if not hum then return end if equipped()==tool then hum:UnequipTools() else hum:EquipTool(tool) end end
local function renderBar()
 for _,s in slots do s:Destroy() end table.clear(slots)
 local tools=allTools()
 for i=1,math.min(#tools,MAX) do local t=tools[i] local name,rarity=info(t) local on=equipped()==t
  local b=make("TextButton",{LayoutOrder=i,Size=UDim2.fromOffset(72,72),BackgroundColor3=on and Color3.fromRGB(60,40,70) or Color3.fromRGB(26,18,32),BackgroundTransparency=.12,Text="",AutoButtonColor=false},bar)
  round(b) stroke(b,on and 3 or 2,on and GOLD or (RARITY[rarity] or Color3.fromRGB(110,100,120)))
  local icon=make("Frame",{Size=UDim2.new(1,-10,1,-24),Position=UDim2.fromOffset(5,4),BackgroundTransparency=1},b) preview(t,icon)
  make("TextLabel",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-3),Size=UDim2.new(1,-6,0,16),BackgroundTransparency=1,Text=name,FontFace=BOLD,TextScaled=true,TextColor3=CREAM},b)
  make("TextLabel",{Position=UDim2.fromOffset(5,3),Size=UDim2.fromOffset(14,14),BackgroundTransparency=1,Text=tostring(i),FontFace=FONT,TextSize=14,TextColor3=Color3.fromRGB(230,220,235),TextXAlignment=Enum.TextXAlignment.Left},b)
  b.Activated:Connect(function() toggle(t) end)
  b.MouseEnter:Connect(function() tw(b,.1,{Size=UDim2.fromOffset(76,76)}) end) b.MouseLeave:Connect(function() tw(b,.1,{Size=UDim2.fromOffset(72,72)}) end)
  table.insert(slots,b) end
end
UIS.InputBegan:Connect(function(input,gp) if gp then return end local k=input.KeyCode.Value-Enum.KeyCode.One.Value+1 if k>=1 and k<=MAX then local t=allTools()[k] if t then toggle(t) end end end)

---------------------------------------------------------------- egg backpack
local SellRF=RS:WaitForChild("SellEgg",10)
local right=make("Frame",{Name="RightButtons",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,192),Size=UDim2.fromOffset(150,64),BackgroundTransparency=1},gui)
local bagBtn=make("TextButton",{Name="BagButton",AnchorPoint=Vector2.new(1,0),Position=UDim2.fromScale(1,0),Size=UDim2.fromOffset(64,64),BackgroundColor3=Color3.fromRGB(160,96,52),Text="",AutoButtonColor=false},right)
round(bagBtn,UDim.new(0,16)) stroke(bagBtn,3)
make("UIGradient",{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(205,140,80),Color3.fromRGB(130,74,38))},bagBtn)
make("TextLabel",{Size=UDim2.new(1,0,1,-14),BackgroundTransparency=1,Text="🎒",TextScaled=true,FontFace=FONT},bagBtn)
make("TextLabel",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-2),Size=UDim2.new(1,0,0,16),BackgroundTransparency=1,Text="EGGS",FontFace=FONT,TextSize=14,TextColor3=CREAM},bagBtn)
local badge=make("TextLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(1,-4,0,4),Size=UDim2.fromOffset(24,24),BackgroundColor3=Color3.fromRGB(232,69,44),Text="0",FontFace=FONT,TextSize=14,TextColor3=Color3.new(1,1,1),Visible=false},bagBtn)
round(badge,UDim.new(1,0)) stroke(badge,2)

local panel=make("Frame",{Name="EggBag",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(620,470),BackgroundColor3=Color3.fromRGB(40,26,44),Visible=false,ZIndex=5},gui)
round(panel,UDim.new(0,20)) stroke(panel,4) make("UISizeConstraint",{MaxSize=Vector2.new(620,470)},panel)
make("UIGradient",{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(62,40,68),Color3.fromRGB(30,20,34))},panel)
local pscale=make("UIScale",{},panel)
local head=make("Frame",{Size=UDim2.new(1,0,0,62),BackgroundColor3=Color3.fromRGB(232,69,44),ZIndex=6},panel) round(head,UDim.new(0,20))
make("UIGradient",{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(255,110,80),Color3.fromRGB(200,45,40))},head)
make("Frame",{Position=UDim2.new(0,0,1,-20),Size=UDim2.new(1,0,0,20),BackgroundColor3=Color3.fromRGB(200,45,40),BorderSizePixel=0,ZIndex=6},head)
local title=make("TextLabel",{Position=UDim2.fromOffset(22,0),Size=UDim2.new(1,-120,1,0),BackgroundTransparency=1,Text="🎒  EGG BACKPACK",FontFace=FONT,TextSize=28,TextColor3=Color3.new(1,1,1),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7},head)
stroke(title,2.5).ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
local close=make("TextButton",{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-14,.5,0),Size=UDim2.fromOffset(42,42),BackgroundColor3=CREAM,Text="✕",FontFace=FONT,TextSize=22,TextColor3=INK,ZIndex=7},head) round(close,UDim.new(0,12)) stroke(close,3)
local grid=make("ScrollingFrame",{Position=UDim2.fromOffset(16,76),Size=UDim2.new(1,-32,1,-152),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=6,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ZIndex=6},panel)
make("UIGridLayout",{CellSize=UDim2.fromOffset(134,170),CellPadding=UDim2.fromOffset(10,10),SortOrder=Enum.SortOrder.LayoutOrder},grid)
local empty=make("TextLabel",{Position=UDim2.fromOffset(16,76),Size=UDim2.new(1,-32,1,-152),BackgroundTransparency=1,Text="No eggs yet — grab some from the river!",FontFace=FONT,TextSize=22,TextColor3=Color3.fromRGB(200,185,205),ZIndex=6},panel)
local foot=make("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,16,1,-14),Size=UDim2.new(1,-32,0,56),BackgroundTransparency=1,ZIndex=6},panel)
local totalL=make("TextLabel",{Size=UDim2.new(.5,0,1,0),BackgroundTransparency=1,Text="",FontFace=FONT,TextSize=20,TextColor3=CREAM,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7},foot)
local sellAll=make("TextButton",{AnchorPoint=Vector2.new(1,0),Position=UDim2.fromScale(1,0),Size=UDim2.fromOffset(200,52),BackgroundColor3=Color3.fromRGB(92,192,70),Text="SELL ALL",FontFace=FONT,TextSize=24,TextColor3=Color3.new(1,1,1),ZIndex=7},foot)
round(sellAll,UDim.new(0,14)) stroke(sellAll,3) make("UIGradient",{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(130,225,95),Color3.fromRGB(60,160,50))},sellAll)
local function eggs() local l={} for _,t in allTools() do local _,_,isEgg=info(t) if isEgg then table.insert(l,t) end end return l end
local quotes=setmetatable({},{__mode="k"})
local onQuote
local function quote(t) if quotes[t]==nil then quotes[t]="wait" task.spawn(function() local ok,v=pcall(SellRF.InvokeServer,SellRF,"Quote",t) quotes[t]=(ok and type(v)=="number") and v or false if onQuote then onQuote() end end) end if quotes[t]=="wait" then return nil end return quotes[t] end
local function popup(text,color)
 local l=make("TextLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.45),Size=UDim2.fromOffset(400,50),BackgroundTransparency=1,Text=text,FontFace=FONT,TextSize=34,TextColor3=color or Color3.fromRGB(130,240,110),ZIndex=20},gui)
 stroke(l,3).ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual tw(l,.9,{Position=UDim2.fromScale(.5,.38),TextTransparency=1}) task.delay(1,function() l:Destroy() end)
end
local function renderBag()
 for _,c in grid:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
 local list=eggs() local sum=0 empty.Visible=#list==0
 badge.Visible=#list>0 badge.Text=tostring(#list)
 for i,t in list do local name,rarity=info(t) local q=quote(t) if q then sum+=q end
  local card=make("Frame",{LayoutOrder=i,BackgroundColor3=Color3.fromRGB(255,246,228),ZIndex=7},grid) round(card,UDim.new(0,14)) stroke(card,3,RARITY[rarity] and RARITY[rarity]:Lerp(INK,.35) or INK)
  local top=make("Frame",{Size=UDim2.new(1,0,0,96),BackgroundColor3=RARITY[rarity] or Color3.fromRGB(190,195,205),ZIndex=7},card) round(top,UDim.new(0,14))
  make("UIGradient",{Rotation=90,Color=ColorSequence.new(Color3.new(1,1,1),Color3.fromRGB(150,150,160))},top)
  local ic=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=8},top) preview(t,ic).ZIndex=8
  make("TextLabel",{Position=UDim2.fromOffset(6,98),Size=UDim2.new(1,-12,0,20),BackgroundTransparency=1,Text=name,FontFace=FONT,TextScaled=true,TextColor3=INK,ZIndex=8},card)
  make("TextLabel",{Position=UDim2.fromOffset(6,117),Size=UDim2.new(1,-12,0,14),BackgroundTransparency=1,Text=string.upper(rarity or ""),FontFace=BOLD,TextScaled=true,TextColor3=(RARITY[rarity] or INK):Lerp(INK,.35),ZIndex=8},card)
  local sb=make("TextButton",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-6),Size=UDim2.new(1,-12,0,28),BackgroundColor3=q and Color3.fromRGB(92,192,70) or Color3.fromRGB(150,140,150),
   Text=q and ("SELL "..money(q)) or (q==false and "CAN'T SELL" or "…"),FontFace=FONT,TextSize=15,TextColor3=Color3.new(1,1,1),AutoButtonColor=q and true or false,ZIndex=8},card)
  round(sb,UDim.new(0,9)) stroke(sb,2)
  sb.Activated:Connect(function() if not q then return end local ok,got=SellRF:InvokeServer("Sell",t) if ok then popup("+"..money(got)) end end)
 end
 totalL.Text=#list>0 and ("Total value  "..money(sum)) or ""
end
sellAll.Activated:Connect(function() local ok,got,n=SellRF:InvokeServer("SellAll") if ok then popup("+"..money(got).."  ("..n.." eggs)") else popup(tostring(got),Color3.fromRGB(255,120,100)) end end)
local qPending=false
onQuote=function() if qPending then return end qPending=true task.delay(.1,function() qPending=false if panel.Visible then renderBag() end end) end
local function setOpen(v) if v then panel.Visible=true pscale.Scale=.85 tw(pscale,.25,{Scale=1},Enum.EasingStyle.Back) renderBag() else panel.Visible=false end end
bagBtn.Activated:Connect(function() setOpen(not panel.Visible) end) close.Activated:Connect(function() setOpen(false) end)
bagBtn.MouseEnter:Connect(function() tw(bagBtn,.1,{Rotation=-6}) end) bagBtn.MouseLeave:Connect(function() tw(bagBtn,.1,{Rotation=0}) end)

-- refresh on backpack changes
local dirty=true
local function hook(c) if c then c.ChildAdded:Connect(function() dirty=true end) c.ChildRemoved:Connect(function() dirty=true end) end end
hook(backpack()) player.ChildAdded:Connect(function(c) if c:IsA("Backpack") then hook(c) dirty=true end end)
player.CharacterAdded:Connect(function(c) hook(c) dirty=true end) hook(player.Character)
task.spawn(function() while true do if dirty then dirty=false renderBar() if panel.Visible then task.wait(.25) renderBag() else local n=#eggs() badge.Visible=n>0 badge.Text=tostring(n) end end task.wait(.15) end end)

---------------------------------------------------------------- night timer (top centre)
for _,n in {"NighttimeHUD","NighttimeStatus"} do local g=pg:FindFirstChild(n) if g then g.Enabled=false end end
pg.ChildAdded:Connect(function(g) if g.Name=="NighttimeHUD" or g.Name=="NighttimeStatus" then task.defer(function() g.Enabled=false end) end end)
local nightGui=make("ScreenGui",{Name="NightBar",ResetOnSpawn=false,DisplayOrder=41,ScreenInsets=Enum.ScreenInsets.None,IgnoreGuiInset=true},pg)
local tab=make("Frame",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,0,44),Size=UDim2.fromOffset(250,110),BackgroundColor3=Color3.fromRGB(28,22,62)},nightGui)
round(tab,UDim.new(0,18)) local tst=stroke(tab,3,Color3.fromRGB(140,120,255))
make("UIGradient",{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(70,50,140),Color3.fromRGB(22,16,48))},tab)
local small=make("TextLabel",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-8),Size=UDim2.new(1,-20,0,28),BackgroundTransparency=1,Text="🌙  NIGHT IN 4:30",FontFace=FONT,TextSize=22,TextColor3=Color3.fromRGB(220,215,255)},tab)
local big=make("TextLabel",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,18),Size=UDim2.new(1,-20,0,40),BackgroundTransparency=1,Text="🌙 NIGHT TIME!",FontFace=FONT,TextSize=34,TextColor3=Color3.fromRGB(255,230,120),TextTransparency=1},tab)
stroke(big,3).ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
local sub=make("TextLabel",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,58),Size=UDim2.new(1,-20,0,20),BackgroundTransparency=1,Text="50× CASH • 50× HATCH • 50× LUCK",FontFace=BOLD,TextSize=14,TextColor3=Color3.fromRGB(150,240,255),TextTransparency=1},tab)
local cnt=make("TextLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.32),Size=UDim2.fromOffset(300,120),BackgroundTransparency=1,Text="",FontFace=FONT,TextSize=110,TextColor3=Color3.fromRGB(255,60,60),TextTransparency=1},nightGui)
stroke(cnt,5).ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
local state,lastSec=nil,nil
local function fmt(s) s=math.max(0,math.ceil(s)) return string.format("%d:%02d",s//60,s%60) end
RunService.RenderStepped:Connect(function()
 local now=workspace:GetServerTimeNow() local active=workspace:GetAttribute("NighttimeActive")
 if active then
  local left=(workspace:GetAttribute("NighttimeEndsAt") or now)-now
  if state~="night" then state="night" tw(tab,.45,{Position=UDim2.new(.5,0,0,118),Size=UDim2.fromOffset(340,110)},Enum.EasingStyle.Back) tw(big,.3,{TextTransparency=0}) tw(sub,.3,{TextTransparency=0}) tst.Color=Color3.fromRGB(255,220,120) cnt.TextTransparency=1 end
  small.Text="ENDS IN "..fmt(left)
 else
  local left=(workspace:GetAttribute("NighttimeNextAt") or now)-now
  if state~="day" then state="day" tw(tab,.4,{Position=UDim2.new(.5,0,0,44),Size=UDim2.fromOffset(250,110)}) tw(big,.2,{TextTransparency=1}) tw(sub,.2,{TextTransparency=1}) tst.Color=Color3.fromRGB(140,120,255) end
  small.Text="🌙  NIGHT IN "..fmt(left)
  local sec=math.ceil(left)
  if left<=5 and left>0 then
   small.TextColor3=Color3.fromRGB(255,90,90)
   if sec~=lastSec then lastSec=sec cnt.Text=tostring(sec) cnt.TextTransparency=0 cnt.TextSize=150 tw(cnt,.9,{TextSize=100,TextTransparency=.6}) end
  else small.TextColor3=Color3.fromRGB(220,215,255) if lastSec then lastSec=nil cnt.TextTransparency=1 end end
 end
end)
