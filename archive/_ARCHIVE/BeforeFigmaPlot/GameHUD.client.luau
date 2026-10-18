-- GameHUD: custom hotbar (replaces Roblox's), backpack with egg and character selling, and the top-centre night timer.
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

-- ReplicatedFirst.CustomInventoryBootstrap keeps Roblox's backpack hidden from startup.

---------------------------------------------------------------- tool preview (3D icon)
local PREVIEW_CACHE=setmetatable({},{__mode="k"})
local function preview(tool,parent)
 local vp=make("ViewportFrame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=parent.ZIndex,LightColor=Color3.new(1,1,1),Ambient=Color3.fromRGB(190,190,200),LightDirection=Vector3.new(-1,-1,-1)},parent)
 if tool.TextureId~="" then vp:Destroy() return make("ImageLabel",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Image=tool.TextureId,ScaleType=Enum.ScaleType.Fit,ZIndex=parent.ZIndex},parent) end
 local m
 if PREVIEW_CACHE[tool] then m=PREVIEW_CACHE[tool]:Clone() else
  m=Instance.new("Model")
  local function grab(force) for _,d in tool:GetDescendants() do if d:IsA("BasePart") and d.Name~="Handle" and (force or d.Transparency<1) then local c=d:Clone() for _,k in c:GetChildren() do if not (k:IsA("DataModelMesh") or k:IsA("Decal") or k:IsA("SurfaceAppearance") or k:IsA("Texture")) then k:Destroy() end end if force and c.Transparency>=1 then c.Transparency=0 end c.Anchored=true c.Parent=m end end end
  grab(false)
  if #m:GetChildren()==0 then grab(true) end -- held eggs: the carry system hides the tool's parts and shows a copy in the arms
  if #m:GetChildren()==0 then local h=tool:FindFirstChild("Handle") if h and (h:IsA("MeshPart") or h:FindFirstChildWhichIsA("DataModelMesh")) then local c=h:Clone() for _,k in c:GetChildren() do if not (k:IsA("DataModelMesh") or k:IsA("SurfaceAppearance") or k:IsA("Decal") or k:IsA("Texture")) then k:Destroy() end end c.Transparency=0 c.Anchored=true c.Parent=m end end
  if #m:GetChildren()>0 then PREVIEW_CACHE[tool]=m:Clone() end
 end
 m.Parent=vp
 local cf,size=m:GetBoundingBox() local cam=make("Camera",{FieldOfView=30},vp) vp.CurrentCamera=cam
 local r=math.max(size.X,size.Y,size.Z)
 cam.CFrame=CFrame.lookAt(cf.Position+cf.LookVector*0+Vector3.new(0.6,0.35,1).Unit*r*2.1,cf.Position)
 return vp
end
local function category(tool)
 if tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId") then return "Characters" end
 if tool:GetAttribute("EggType") then return "Eggs" end
end
local function info(tool)
 local kind=category(tool)
 local id=tool:GetAttribute("CharacterId") or tool:GetAttribute("BrainrotId") or tool:GetAttribute("EggType")
 local e=id and Catalog.ById[id]
 local rarity=tool:GetAttribute("Rarity") or (e and e.Rarity)
 local name=tool.Name
 if kind=="Eggs" then name=tool:GetAttribute("UnknownEgg") and "Unknown Egg" or ((e and e.Id or id).." Egg")
 elseif kind=="Characters" then name=(tool:GetAttribute("GoldVariant") and "Golden " or "")..(e and e.Name or tool:GetAttribute("DesignName") or tool.Name) end
 return name,rarity,kind=="Eggs"
end

---------------------------------------------------------------- hotbar
local BLACK=Color3.new(0,0,0)
local PLATE=Color3.fromRGB(38,56,68)
local function studs(parent,size,transp) return make("ImageLabel",{Name="Studs",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image="rbxassetid://132561191216691",ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(size,size),ImageTransparency=transp,ZIndex=parent.ZIndex},parent) end
local trayShadow=make("Frame",{Name="HotbarShadow",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,6,1,-6),Size=UDim2.fromOffset(0,0),BackgroundColor3=BLACK,BorderSizePixel=0,Visible=false},gui)
local bar=make("Frame",{Name="Hotbar",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-12),Size=UDim2.fromOffset(0,96),AutomaticSize=Enum.AutomaticSize.X,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=3},gui)
-- backing layer (outside the bar so its UIListLayout only arranges slots)
local traySkin=make("Frame",{Name="HotbarSkin",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-12),Size=UDim2.fromOffset(0,0),BackgroundColor3=PLATE,BorderSizePixel=0,ZIndex=2,Visible=false},gui)
studs(traySkin,24,0.82)
make("Frame",{Name="TopStrip",Size=UDim2.new(1,0,0,5),BackgroundColor3=Color3.fromRGB(255,150,30),BorderSizePixel=0,ZIndex=2},traySkin)
make("UIStroke",{Color=BLACK,Thickness=3,LineJoinMode=Enum.LineJoinMode.Miter},bar)
make("UIPadding",{PaddingLeft=UDim.new(0,8),PaddingRight=UDim.new(0,8),PaddingTop=UDim.new(0,10),PaddingBottom=UDim.new(0,8)},bar)
make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),HorizontalAlignment=Enum.HorizontalAlignment.Center,VerticalAlignment=Enum.VerticalAlignment.Bottom,SortOrder=Enum.SortOrder.LayoutOrder},bar)
bar:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() local sz=UDim2.fromOffset(bar.AbsoluteSize.X,bar.AbsoluteSize.Y) trayShadow.Size=sz traySkin.Size=sz end)
-- phones: shrink fixed-pixel HUD pieces (hotbar, night timer) on short screens; desktop stays 1
local function phoneScale() local c=workspace.CurrentCamera local y=c and c.ViewportSize.Y or 720 return y<600 and math.clamp(y/720,.6,1) or 1 end
local barScale=make("UIScale",{Scale=phoneScale()},bar)
local bagOpen=false
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
 local n=math.min(#tools,MAX) bar.Visible=n>0 and not bagOpen;trayShadow.Visible=false;traySkin.Visible=false
 for i=1,n do local t=tools[i] local name,rarity=info(t) local on=equipped()==t
  local rc=RARITY[rarity] or Color3.fromRGB(150,140,160)
  local hold=make("Frame",{LayoutOrder=i,Size=UDim2.fromOffset(72,78),BackgroundTransparency=1},bar)
  local sh=make("Frame",{Position=UDim2.fromOffset(4,4),Size=UDim2.fromOffset(72,72),BackgroundColor3=BLACK,BorderSizePixel=0},hold)
  local b=make("TextButton",{Position=UDim2.fromOffset(0,on and -6 or 0),Size=UDim2.fromOffset(72,72),BackgroundColor3=on and GOLD or Color3.fromRGB(48,38,60),BorderSizePixel=0,Text="",AutoButtonColor=false,ZIndex=2},hold)
  make("UIStroke",{Color=BLACK,Thickness=3,LineJoinMode=Enum.LineJoinMode.Miter},b)
  local inner=make("Frame",{Position=UDim2.fromOffset(on and 4 or 0,on and 4 or 0),Size=UDim2.new(1,on and -8 or 0,1,on and -8 or 0),BackgroundColor3=Color3.fromRGB(48,38,60),BorderSizePixel=0,ZIndex=2},b)
  local icon=make("Frame",{Size=UDim2.new(1,-8,1,-24),Position=UDim2.fromOffset(4,4),BackgroundTransparency=1,ZIndex=3},inner) preview(t,icon)
  local strip=make("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,18),BackgroundColor3=BLACK,BorderSizePixel=0,ZIndex=3},inner)
  make("Frame",{Size=UDim2.new(1,0,0,3),BackgroundColor3=rc,BorderSizePixel=0,ZIndex=4},strip)
  local nl=make("TextLabel",{Position=UDim2.fromOffset(3,3),Size=UDim2.new(1,-6,1,-3),BackgroundTransparency=1,Text=string.upper(name),FontFace=FONT,TextScaled=true,TextColor3=Color3.new(1,1,1),ZIndex=5},strip)
  make("UITextSizeConstraint",{MaxTextSize=12},nl)
  local key=make("TextLabel",{Position=UDim2.fromOffset(-3,-3),Size=UDim2.fromOffset(18,18),BackgroundColor3=on and BLACK or rc,BorderSizePixel=0,Text=tostring(i),FontFace=FONT,TextSize=13,TextColor3=Color3.new(1,1,1),ZIndex=6},b)
  make("UIStroke",{Color=BLACK,Thickness=2,LineJoinMode=Enum.LineJoinMode.Miter,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},key)
  for _,d in hold:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex+=5 end end -- draw slots above the HotbarSkin studs (Global ZIndex), so the yellow selected border shows
  do -- figma slot art
    b.BackgroundTransparency=1 sh.Visible=false inner.BackgroundTransparency=1
    for _,x in b:GetChildren() do if x:IsA("UIStroke") then x.Enabled=false end end
    local art=make("ImageLabel",{Name="SlotArt",BackgroundTransparency=1,Image=on and "rbxassetid://93279544158680" or "rbxassetid://110062655055411",Size=UDim2.new(1,6,1,8),Position=UDim2.fromOffset(-3,-3),ScaleType=Enum.ScaleType.Stretch,ZIndex=b.ZIndex},b)
    inner.ZIndex=b.ZIndex+1
    strip.Position=UDim2.new(0,6,1,-6) strip.Size=UDim2.new(1,-12,0,16) strip.AnchorPoint=Vector2.new(0,1)
    strip.BackgroundTransparency=0.15 make("UICorner",{CornerRadius=UDim.new(0,5)},strip)
    for _,x in strip:GetChildren() do if x:IsA("Frame") then x.Visible=false end end
    for _,x in bar:GetChildren() do if x:IsA("UIStroke") then x.Enabled=false end end
    key.BackgroundTransparency=1 for _,x in key:GetChildren() do if x:IsA("UIStroke") then x.Enabled=false end end
    make("UIStroke",{Color=BLACK,Thickness=2},key)
   end
   b.Activated:Connect(function() toggle(t) end)
  b.MouseEnter:Connect(function() if not on then tw(b,.08,{Position=UDim2.fromOffset(0,-4)}) end end)
  b.MouseLeave:Connect(function() if not on then tw(b,.08,{Position=UDim2.fromOffset(0,0)}) end end)
  table.insert(slots,hold) end
end
UIS.InputBegan:Connect(function(input,gp) if gp then return end local k=input.KeyCode.Value-Enum.KeyCode.One.Value+1 if k>=1 and k<=MAX then local t=allTools()[k] if t then toggle(t) end end end)

---------------------------------------------------------------- backpack
local SellRF=RS:WaitForChild("SellEgg",10)
local InventoryRF=RS:WaitForChild("CharacterInventory"):WaitForChild("InventoryRequest")
local InventoryEvent=RS.CharacterInventory:WaitForChild("InventoryEvent")
local selectedTab="Eggs"
local armedTool,armedUntil=nil,0
local bulkIds,bulkUntil=nil,0
local selling=false
local right=make("Frame",{Name="RightButtons",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,250),Size=UDim2.fromOffset(150,64),BackgroundTransparency=1},gui)
local bagBtn=make("TextButton",{Name="BagButton",AnchorPoint=Vector2.new(1,0),Position=UDim2.fromScale(1,0),Size=UDim2.fromOffset(56,62),BackgroundColor3=Color3.fromRGB(255,196,60),Text="",AutoButtonColor=false},right)
round(bagBtn,UDim.new(0,16)) stroke(bagBtn,3)

require(game:GetService("ReplicatedStorage"):WaitForChild("PixelIcon")).build(bagBtn,"bag",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,4),Size=UDim2.new(1,-12,1,-20)})
make("TextLabel",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-2),Size=UDim2.new(1,0,0,16),BackgroundTransparency=1,Text="BACKPACK",FontFace=FONT,TextSize=9,TextColor3=Color3.new(1,1,1)},bagBtn)
local badge=make("TextLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(1,-4,0,4),Size=UDim2.fromOffset(24,24),BackgroundColor3=Color3.fromRGB(232,69,44),Text="0",FontFace=FONT,TextSize=14,TextColor3=Color3.new(1,1,1),Visible=false},bagBtn)
round(badge,UDim.new(1,0)) stroke(badge,2)
-- phones: the EGGS button would sit on the jump button at y=250, so shrink it and stack it right under the settings gear
local rightScale=make("UIScale",{},right)
local function layoutRight()
 local v=gui.AbsoluteSize if v.Y<=0 then return end
 local k=phoneScale() rightScale.Scale=k
 if k<1 then local s=math.min(1,v.X/600,v.Y/560) right.Position=UDim2.new(1,-10,0,20+104*s+(56+10)*k)
 else right.Position=UDim2.new(1,-8,0,250) end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutRight) task.defer(layoutRight)

local panel=make("Frame",{Name="EggBag",Active=true,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(620,470),BackgroundColor3=PLATE,Visible=false,ZIndex=5},gui)
stroke(panel,4)
studs(panel,28,0.82)
local bagShadow=make("Frame",{Name="EggBagShadow",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.new(.5,10,.5,10),Size=UDim2.fromOffset(620,470),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,Visible=false,ZIndex=4},gui)
make("UISizeConstraint",{MaxSize=Vector2.new(620,470)},bagShadow)
panel:GetPropertyChangedSignal("Visible"):Connect(function()
 bagOpen=panel.Visible;bagShadow.Visible=bagOpen;gui.DisplayOrder=bagOpen and 60 or 40
 renderBar()
end)
make("UISizeConstraint",{MaxSize=Vector2.new(620,470)},panel)

local pscale=make("UIScale",{},panel)
local head=make("Frame",{Name="Header",Size=UDim2.new(1,0,0,62),BackgroundColor3=Color3.fromRGB(240,110,20),BorderSizePixel=0,ZIndex=6},panel) studs(head,26,0.1)
make("Frame",{Position=UDim2.new(0,0,1,0),Size=UDim2.new(1,0,0,4),BackgroundColor3=Color3.new(0,0,0),BorderSizePixel=0,ZIndex=8},head)
require(game:GetService("ReplicatedStorage"):WaitForChild("PixelIcon")).build(head,"bag",{AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,16,.5,0),Size=UDim2.fromOffset(40,40),ZIndex=7})

local title=make("TextLabel",{Position=UDim2.fromOffset(66,0),Size=UDim2.new(1,-140,1,0),BackgroundTransparency=1,Name="Title",Text="BACKPACK",FontFace=FONT,TextSize=28,TextColor3=Color3.new(1,1,1),TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7},head)
stroke(title,2.5).ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
local close=make("TextButton",{Name="Close",AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-14,.5,0),Size=UDim2.fromOffset(44,44),BackgroundColor3=Color3.fromRGB(226,50,44),Text="X",FontFace=FONT,TextSize=28,TextColor3=Color3.new(1,1,1),ZIndex=7},head) make("UIStroke",{Color=Color3.new(0,0,0),Thickness=2.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual},close) round(close,UDim.new(0,12)) stroke(close,3)
local tabs=make("Frame",{Name="Tabs",Position=UDim2.fromOffset(16,72),Size=UDim2.new(1,-32,0,36),BackgroundTransparency=1,ZIndex=6},panel)
local tabButtons={}
for i,name in {"Eggs","Characters"} do
 local b=make("TextButton",{Name=name,Position=UDim2.new((i-1)*.5,0,0,0),Size=UDim2.new(.5,-6,1,0),BackgroundColor3=PLATE,BorderSizePixel=0,Text=string.upper(name),FontFace=FONT,TextSize=19,TextColor3=CREAM,ZIndex=7},tabs)
 stroke(b,2);tabButtons[name]=b
end
local grid=make("ScrollingFrame",{Name="Items",Position=UDim2.fromOffset(16,122),Size=UDim2.new(1,-32,1,-198),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=6,AutomaticCanvasSize=Enum.AutomaticSize.Y,CanvasSize=UDim2.new(),ZIndex=6},panel)
local gridLayout=make("UIGridLayout",{CellSize=UDim2.fromOffset(134,184),CellPadding=UDim2.fromOffset(10,10),SortOrder=Enum.SortOrder.LayoutOrder},grid)
local empty=make("TextLabel",{Name="Empty",Position=UDim2.fromOffset(16,122),Size=UDim2.new(1,-32,1,-198),BackgroundTransparency=1,Text="No eggs yet — grab some from the river!",FontFace=FONT,TextSize=22,TextColor3=Color3.fromRGB(200,185,205),ZIndex=6},panel)
local foot=make("Frame",{Name="Footer",AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,16,1,-14),Size=UDim2.new(1,-32,0,56),BackgroundTransparency=1,ZIndex=6},panel)
local totalL=make("TextLabel",{Size=UDim2.new(.5,0,1,0),BackgroundTransparency=1,Text="",FontFace=FONT,TextSize=20,TextColor3=CREAM,TextXAlignment=Enum.TextXAlignment.Left,ZIndex=7},foot)
local sellAll=make("TextButton",{Name="SellAll",AnchorPoint=Vector2.new(1,0),Position=UDim2.fromScale(1,0),Size=UDim2.fromOffset(200,52),BackgroundColor3=Color3.fromRGB(92,192,70),Text="SELL ALL",FontFace=FONT,TextSize=24,TextColor3=Color3.new(1,1,1),ZIndex=7},foot)
round(sellAll,UDim.new(0,14)) stroke(sellAll,3) make("UIStroke",{Color=Color3.new(0,0,0),Thickness=2.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual},sellAll)
local function bagItems(kind)
 local list={}
 for _,t in allTools() do if category(t)==kind then table.insert(list,t) end end
 return list
end
local function bagCount()
 return #bagItems("Eggs")+#bagItems("Characters")
end
local quotes=setmetatable({},{__mode="k"})
local characterItems={}
local characterLoaded=false
local fetching=false
local onQuote
local function applySnapshot(snapshot)
 if type(snapshot)~="table" then return end
 characterItems={}
 for _,item in snapshot.items or {} do characterItems[item.id]=item end
 characterLoaded=true
 if onQuote then onQuote() end
end
local function fetchCharacters()
 if fetching then return end
 fetching=true
 task.spawn(function()
  local ok,res=pcall(InventoryRF.InvokeServer,InventoryRF,"Fetch")
  fetching=false
  if ok and type(res)=="table" and res.ok then applySnapshot(res.snapshot) end
 end)
end
InventoryEvent.OnClientEvent:Connect(function(action,snapshot)
 if action=="Snapshot" then applySnapshot(snapshot) end
end)
local function quote(t)
 if category(t)=="Characters" then
  if not characterLoaded then return nil end
  local item=characterItems[t:GetAttribute("ItemId")]
  return item and item.sellValue or false
 end
 if quotes[t]==nil then
  quotes[t]="wait"
  task.spawn(function()
   local ok,v=pcall(SellRF.InvokeServer,SellRF,"Quote",t)
   quotes[t]=(ok and type(v)=="number") and v or false
   if onQuote then onQuote() end
  end)
 end
 if quotes[t]=="wait" then return nil end
 return quotes[t]
end
local function popup(text,color)
 local l=make("TextLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.45),Size=UDim2.fromOffset(400,50),BackgroundTransparency=1,Text=text,FontFace=FONT,TextSize=34,TextColor3=color or Color3.fromRGB(130,240,110),ZIndex=20},gui)
 stroke(l,3).ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual tw(l,.9,{Position=UDim2.fromScale(.5,.38),TextTransparency=1}) task.delay(1,function() l:Destroy() end)
end
local renderBag
local function sellCharacters(action,payload)
 local ok,res=pcall(InventoryRF.InvokeServer,InventoryRF,action,payload)
 if not ok or type(res)~="table" then popup("Couldn't sell. Try again.",Color3.fromRGB(255,120,100));return end
 if res.snapshot then applySnapshot(res.snapshot) end
 if res.ok then
  local decoded,data=pcall(game:GetService("HttpService").JSONDecode,game:GetService("HttpService"),res.message)
  if decoded then popup("+"..money(data.cash).."  ("..data.count.." characters)") end
 else popup(res.message or "Couldn't sell.",Color3.fromRGB(255,120,100)) end
end
renderBag=function()
 for _,c in grid:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
 local isCharacters=selectedTab=="Characters"
 local list=bagItems(selectedTab)
 local sum,sellable=0,0
 empty.Visible=#list==0
 empty.Text=isCharacters and "No characters in your backpack — hatch an egg first!" or "No eggs yet — grab some from the river!"
 gridLayout.CellSize=UDim2.fromOffset(134,isCharacters and 208 or 184)
 for name,b in tabButtons do
  b.BackgroundColor3=name==selectedTab and GOLD or PLATE
  b.TextColor3=name==selectedTab and INK or CREAM
 end
 local count=bagCount();badge.Visible=count>0;badge.Text=tostring(count)
 for i,t in list do
  local name,rarity=info(t)
  local q=quote(t)
  local canSell=type(q)=="number"
  if canSell then sum+=q;sellable+=1 end
  local card=make("Frame",{Name="Item"..i,LayoutOrder=i,BackgroundColor3=Color3.fromRGB(26,38,46),BorderSizePixel=0,ZIndex=7},grid)
  card:SetAttribute("ItemId",t:GetAttribute("ItemId"));card:SetAttribute("Category",selectedTab);stroke(card,3,BLACK)
  local top=make("Frame",{Size=UDim2.new(1,0,0,96),BackgroundColor3=RARITY[rarity] or Color3.fromRGB(190,195,205),BorderSizePixel=0,ZIndex=7},card)
  studs(top,20,.55)
  make("Frame",{Position=UDim2.new(0,0,1,0),Size=UDim2.new(1,0,0,3),BackgroundColor3=BLACK,BorderSizePixel=0,ZIndex=8},top)
  local ic=make("Frame",{Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=8},top);preview(t,ic).ZIndex=8
  make("TextLabel",{Name="ItemName",Position=UDim2.fromOffset(6,98),Size=UDim2.new(1,-12,0,20),BackgroundTransparency=1,Text=name,FontFace=FONT,TextScaled=true,TextColor3=Color3.new(1,1,1),ZIndex=8},card)
  make("TextLabel",{Position=UDim2.fromOffset(6,119),Size=UDim2.new(1,-12,0,14),BackgroundTransparency=1,Text=string.upper(rarity or ""),FontFace=BOLD,TextScaled=true,TextColor3=RARITY[rarity] or Color3.new(1,1,1),ZIndex=8},card)
  if isCharacters then
   local record=characterItems[t:GetAttribute("ItemId")]
   local power=record and record.power or t:GetAttribute("Power") or 0
   local income=record and record.income or t:GetAttribute("IncomePerSecond") or 0
   make("TextLabel",{Name="Stats",Position=UDim2.fromOffset(5,136),Size=UDim2.new(1,-10,0,18),BackgroundTransparency=1,Text="PWR "..money(power):sub(2).." • "..money(income).."/s",FontFace=BOLD,TextScaled=true,TextColor3=CREAM,ZIndex=8},card)
  end
  local confirming=isCharacters and armedTool==t and os.clock()<armedUntil
  local sb=make("TextButton",{Name="Sell",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-6),Size=UDim2.new(1,-12,0,40),BackgroundColor3=canSell and Color3.fromRGB(92,192,70) or Color3.fromRGB(150,140,150),Text=canSell and ((confirming and "CONFIRM " or "SELL ")..money(q)) or (q==false and "CAN'T SELL" or "…"),FontFace=FONT,TextSize=14,TextColor3=Color3.new(1,1,1),AutoButtonColor=canSell,Interactable=canSell,ZIndex=8},card)
  round(sb,UDim.new(0,9));stroke(sb,2)
  sb.Activated:Connect(function()
   if not canSell or selling then return end
   if isCharacters then
    if armedTool~=t or os.clock()>=armedUntil then
     armedTool=t;armedUntil=os.clock()+4;bulkIds=nil;renderBag()
     task.delay(4,function()if armedTool==t then armedTool=nil;if panel.Visible then renderBag() end end end)
     return
    end
    selling=true;armedTool=nil
    sellCharacters("SellBackpack",{id=t:GetAttribute("ItemId")})
   else
    selling=true
    local success,ok,got=pcall(SellRF.InvokeServer,SellRF,"Sell",t)
    if success and ok then popup("+"..money(got)) else popup(tostring(success and got or "Couldn't sell."),Color3.fromRGB(255,120,100)) end
   end
   selling=false
  end)
 end
 totalL.Text=#list>0 and ("Total value  "..money(sum)) or ""
 sellAll.Text=isCharacters and (bulkIds and os.clock()<bulkUntil and "CONFIRM ALL?" or "SELL ALL CHARACTERS") or "SELL ALL EGGS"
 sellAll.TextSize=isCharacters and 17 or 21
 sellAll.Interactable=sellable>0;sellAll.AutoButtonColor=sellable>0
end
sellAll.Activated:Connect(function()
 if selling then return end
 if selectedTab=="Characters" then
  if not bulkIds or os.clock()>=bulkUntil then
   bulkIds={}
   for _,t in bagItems("Characters") do if type(quote(t))=="number" then table.insert(bulkIds,t:GetAttribute("ItemId")) end end
   if #bulkIds==0 then bulkIds=nil;return end
   bulkUntil=os.clock()+4;armedTool=nil;renderBag()
   local expires=bulkUntil
   task.delay(4,function()if bulkUntil==expires then bulkIds=nil;if panel.Visible then renderBag() end end end)
   return
  end
  local ids=bulkIds;bulkIds=nil;selling=true
  sellCharacters("SellBackpackAll",{ids=ids})
 else
  selling=true
  local success,ok,got,n=pcall(SellRF.InvokeServer,SellRF,"SellAll")
  if success and ok then popup("+"..money(got).."  ("..n.." eggs)") else popup(tostring(success and got or "Couldn't sell."),Color3.fromRGB(255,120,100)) end
 end
 selling=false;renderBag()
end)
for name,b in tabButtons do b.Activated:Connect(function()
 selectedTab=name;armedTool=nil;bulkIds=nil;grid.CanvasPosition=Vector2.zero
 if name=="Characters" then fetchCharacters() end
 renderBag()
end) end
local qPending=false
onQuote=function() if qPending then return end qPending=true task.delay(.1,function() qPending=false if panel.Visible then renderBag() end end) end
-- Shrinks the bag to fit small (phone) screens; desktop keeps the full 620x470 panel.
local function bagFit() local v=gui.AbsoluteSize if v.X<=0 or v.Y<=0 then return 1 end return math.clamp(math.min(1,(v.X-24)/620,(v.Y-24)/470),.4,1) end
local function setOpen(v) if v then panel.Visible=true fetchCharacters();pscale.Scale=bagFit()*.85 tw(pscale,.25,{Scale=bagFit()},Enum.EasingStyle.Back) renderBag() else armedTool=nil;bulkIds=nil;panel.Visible=false end end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() if panel.Visible then pscale.Scale=bagFit() end end)
bagBtn.Activated:Connect(function() setOpen(not panel.Visible) end) close.Activated:Connect(function() setOpen(false) end)
bagBtn.MouseEnter:Connect(function() tw(bagBtn,.1,{Rotation=-6}) end) bagBtn.MouseLeave:Connect(function() tw(bagBtn,.1,{Rotation=0}) end)

-- refresh on backpack changes
local dirty=true
local function hook(c) if c then c.ChildAdded:Connect(function() dirty=true end) c.ChildRemoved:Connect(function() dirty=true end) end end
hook(backpack()) player.ChildAdded:Connect(function(c) if c:IsA("Backpack") then hook(c) dirty=true end end)
player.CharacterAdded:Connect(function(c) hook(c) dirty=true end) hook(player.Character)
task.spawn(function() while true do if dirty then dirty=false renderBar() if panel.Visible then task.wait(.25) renderBag() else local n=bagCount() badge.Visible=n>0 badge.Text=tostring(n) end end task.wait(.15) end end)

---------------------------------------------------------------- night timer (top centre)
for _,n in {"NighttimeHUD","NighttimeStatus"} do local g=pg:FindFirstChild(n) if g then g.Enabled=false end end
pg.ChildAdded:Connect(function(g) if g.Name=="NighttimeHUD" or g.Name=="NighttimeStatus" then task.defer(function() g.Enabled=false end) end end)
local nightGui=make("ScreenGui",{Name="NightBar",ResetOnSpawn=false,DisplayOrder=41,ScreenInsets=Enum.ScreenInsets.None,IgnoreGuiInset=true},pg)
local hs=phoneScale()
local tab=make("Frame",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,0,38*hs),Size=UDim2.fromOffset(250,110),BackgroundColor3=Color3.fromRGB(28,22,62)},nightGui)
round(tab,UDim.new(0,18)) local tst=stroke(tab,3,Color3.fromRGB(140,120,255))

local small=make("TextLabel",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-8),Size=UDim2.new(1,-20,0,28),BackgroundTransparency=1,Text="🌙  NIGHT IN 4:30",FontFace=FONT,TextSize=22,TextColor3=Color3.fromRGB(220,215,255)},tab)
local big=make("TextLabel",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,18),Size=UDim2.new(1,-20,0,40),BackgroundTransparency=1,Text="🌙 NIGHT TIME!",FontFace=FONT,TextSize=34,TextColor3=Color3.fromRGB(255,230,120),TextTransparency=1},tab)
stroke(big,3).ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
local sub=make("TextLabel",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,58),Size=UDim2.new(1,-20,0,20),BackgroundTransparency=1,Text="3× CASH • 2× HATCH • 3× LUCK",FontFace=BOLD,TextSize=14,TextColor3=Color3.fromRGB(150,240,255),TextTransparency=1},tab)
local cnt=make("TextLabel",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.32),Size=UDim2.fromOffset(300,120),BackgroundTransparency=1,Text="",FontFace=FONT,TextSize=110,TextColor3=Color3.fromRGB(255,60,60),TextTransparency=1},nightGui)
stroke(cnt,5).ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual
local tabScale=make("UIScale",{Scale=hs},tab) local cntScale=make("UIScale",{Scale=hs},cnt)
local state
local function rescale()
 hs=phoneScale() barScale.Scale=hs tabScale.Scale=hs cntScale.Scale=hs
 tab.Position=UDim2.new(.5,0,0,(state=="night" and 128 or 38)*hs)
end
workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale)
local lastSec,cntTween=nil,nil
local function hideCnt() lastSec=nil if cntTween then cntTween:Cancel() cntTween=nil end cnt.TextTransparency=1 cnt.Text="" end
local function fmt(s) s=math.max(0,math.ceil(s)) return string.format("%d:%02d",s//60,s%60) end
RunService.RenderStepped:Connect(function()
 local now=workspace:GetServerTimeNow() local active=workspace:GetAttribute("NighttimeActive")
 big.Visible=active==true sub.Visible=active==true
 if active then
  local left=(workspace:GetAttribute("NighttimeEndsAt") or now)-now
  if state~="night" then state="night" tw(tab,1.6,{Position=UDim2.new(.5,0,0,128*hs),Size=UDim2.fromOffset(340,136)},Enum.EasingStyle.Quint) task.delay(.9,function() if state=="night" then tw(big,.5,{TextTransparency=0}) tw(sub,.5,{TextTransparency=0}) end end) tst.Color=Color3.fromRGB(255,220,120) end
  if lastSec then hideCnt() end
  small.Text="ENDS IN "..fmt(left)
 else
  local left=(workspace:GetAttribute("NighttimeNextAt") or now)-now
  if state~="day" then state="day" tw(tab,1,{Position=UDim2.new(.5,0,0,38*hs),Size=UDim2.fromOffset(250,110)},Enum.EasingStyle.Quad) tw(big,.2,{TextTransparency=1}) tw(sub,.2,{TextTransparency=1}) tst.Color=Color3.fromRGB(140,120,255) end
  small.Text="🌙  NIGHT IN "..fmt(left)
  local sec=math.ceil(left)
  if left<=5 and left>0 then
   small.TextColor3=Color3.fromRGB(255,90,90)
   if sec~=lastSec then lastSec=sec if cntTween then cntTween:Cancel() end cnt.Text=tostring(sec) cnt.TextTransparency=0 cnt.TextSize=150 cntTween=tw(cnt,.9,{TextSize=100,TextTransparency=.6}) end
  else small.TextColor3=Color3.fromRGB(220,215,255) if lastSec then hideCnt() end end
 end
end)

-- away earnings popup (PlayerDataService)
do local function show() local v=player:GetAttribute("OfflineEarnings") if v and v>0 then local h=math.floor((player:GetAttribute("OfflineSeconds") or 0)/60) popup("WHILE YOU WERE AWAY: +"..money(v),Color3.fromRGB(255,206,60)) end end player:GetAttributeChangedSignal("OfflineEarnings"):Connect(show) task.delay(3,show) end

---------------------------------------------------------------- PLOT button (above the 4 side buttons; rounded by request; key H)
do
	local GoHome = RS:WaitForChild("GoHome", 10)
	local holder = make("Frame", { Name = "HomeButton", Size = UDim2.fromOffset(212, 50), BackgroundTransparency = 1 }, gui)
	local shadow = make("Frame", { Name = "Shadow", Position = UDim2.fromOffset(0, 5), Size = UDim2.new(1, 0, 1, -5), BackgroundColor3 = Color3.new(0, 0, 0), BorderSizePixel = 0 }, holder)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, shadow) shadow:SetAttribute("KeepRound", true)
	local hb = make("TextButton", { Name = "Button", Size = UDim2.new(1, 0, 1, -5), BackgroundColor3 = Color3.fromRGB(255, 176, 40), BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 2 }, holder)
	hb:SetAttribute("KeepRound", true)
	make("UICorner", { CornerRadius = UDim.new(0, 14) }, hb)
	make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, hb)
	local st = make("ImageLabel", { Name = "Studs", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Image = "rbxassetid://132561191216691", ScaleType = Enum.ScaleType.Tile, TileSize = UDim2.fromOffset(22, 22), ImageTransparency = 0.15, ZIndex = 2 }, hb)
	st:SetAttribute("KeepRound", true) make("UICorner", { CornerRadius = UDim.new(0, 14) }, st)
	local hl = make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "PLOT", FontFace = FONT, TextSize = 30, TextColor3 = Color3.new(1, 1, 1), ZIndex = 3 }, hb)
	make("UIStroke", { Color = Color3.new(0, 0, 0), Thickness = 3 }, hl)
	-- sit right above the side buttons (GameMenus.SideButtons), same width, follows their responsive scale
	local side
	local function place()
		side = side or (pg:FindFirstChild("GameMenus") and pg.GameMenus:FindFirstChild("SideButtons"))
		if not side then return end
		local p, sz = side.AbsolutePosition, side.AbsoluteSize
		local h = math.floor(sz.X * 112 / 372)
		holder.Size = UDim2.fromOffset(sz.X, h)
		holder.Position = UDim2.fromOffset(p.X, p.Y - h - 8)
		hl.TextSize = math.floor(h * 0.6)
	end
	task.spawn(function()
		local gm = pg:WaitForChild("GameMenus", 30)
		side = gm and gm:WaitForChild("SideButtons", 30)
		if not side then return end
		side:GetPropertyChangedSignal("AbsolutePosition"):Connect(place)
		side:GetPropertyChangedSignal("AbsoluteSize"):Connect(place)
		place()
	end)
	local function go()
		if GoHome then GoHome:FireServer() end
		hb.Position = UDim2.fromOffset(0, 4) task.delay(0.1, function() hb.Position = UDim2.fromOffset(0, 0) end)
	end
	hb.Activated:Connect(go)
	hb.MouseEnter:Connect(function() hb.Position = UDim2.fromOffset(0, -2) end)
	hb.MouseLeave:Connect(function() hb.Position = UDim2.fromOffset(0, 0) end)
	UIS.InputBegan:Connect(function(input, gp) if not gp and input.KeyCode == Enum.KeyCode.H then go() end end)
	if GoHome then GoHome.OnClientEvent:Connect(function(msg) if msg ~= "OK" and msg ~= "Wait a moment" then popup(msg, Color3.fromRGB(255, 120, 100)) end end) end
end
