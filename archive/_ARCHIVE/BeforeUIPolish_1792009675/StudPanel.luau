-- StudPanel: the brick/stud style Owner + Admin panel UI. Built by OwnerPanelClient.
-- Purely visual: every button calls the server (OwnerPanelServer), which checks the role again.
local TweenService=game:GetService("TweenService")
local M={}
local function rgb(r,g,b) return Color3.fromRGB(r,g,b) end
local INK=rgb(8,8,10)
local C={Plate=rgb(22,22,26),Plate2=rgb(32,32,38),Card=rgb(44,44,52),Inset=rgb(16,16,20),White=rgb(255,255,255),Muted=rgb(178,186,210),
 Red=rgb(226,66,60),Blue=rgb(66,134,236),Green=rgb(92,192,70),Yellow=rgb(248,188,44),Purple=rgb(150,100,230),Orange=rgb(245,130,40),Teal=rgb(40,190,190),Pink=rgb(236,90,160),Grey=rgb(120,128,150)}
M.Colors=C
local RC={Common=rgb(160,168,184),Uncommon=C.Green,Rare=C.Blue,Epic=C.Purple,Legendary=C.Yellow,Mythic=C.Pink,Secret=C.Red}
local F=Font.new("rbxasset://fonts/families/BuilderSans.json",Enum.FontWeight.Heavy)
local FB=Font.new("rbxasset://fonts/families/BuilderSans.json",Enum.FontWeight.Bold)
local function dark(c,a) return c:Lerp(Color3.new(0,0,0),a or .3) end
local function light(c,a) return c:Lerp(Color3.new(1,1,1),a or .3) end
local function make(cls,props,parent) local o=Instance.new(cls) for k,v in pairs(props) do o[k]=v end if parent then o.Parent=parent end return o end
local function corner(o,r) make("UICorner",{CornerRadius=UDim.new(0,math.min(r or 2,2))},o) end
local function studTex(o) local im=make("ImageLabel",{Name="StudTex",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image="rbxassetid://132561191216691",ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(28,28),ZIndex=o.ZIndex},o) corner(im) return im end
local function stroke(o,t,col) return make("UIStroke",{Color=col or INK,Thickness=t or 3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},o) end
local function pad(o,t,s) make("UIPadding",{PaddingTop=UDim.new(0,t),PaddingBottom=UDim.new(0,t),PaddingLeft=UDim.new(0,s or t),PaddingRight=UDim.new(0,s or t)},o) end
local function vlist(o,gap) return make("UIListLayout",{Padding=UDim.new(0,gap),SortOrder=Enum.SortOrder.LayoutOrder},o) end
local order=0 local function nx() order+=1 return order end
local function label(parent,txt,size,color,font,props)
 local l=make("TextLabel",{BackgroundTransparency=1,Text=txt,TextSize=size or 16,TextColor3=color or C.White,FontFace=font or F,TextXAlignment=Enum.TextXAlignment.Left,AutomaticSize=Enum.AutomaticSize.XY},parent)
 if props then for k,v in pairs(props) do l[k]=v end end return l
end
local function title(parent,txt,size,props) local l=label(parent,txt,size,C.White,F,props) make("UIStroke",{Color=INK,Thickness=size>=24 and 3 or 2},l) return l end
-- one brick stud (same look as the StudHUD buttons)
local function stud(parent,color,x,w,h,z)
 local base=make("Frame",{Name="Stud",AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(x,0,0,2),Size=UDim2.fromOffset(w,h),BackgroundColor3=dark(color,.18),BorderSizePixel=0,ZIndex=z},parent)
 corner(base,math.floor(h*.45)) stroke(base,2.5)
 local top=make("Frame",{BorderSizePixel=0,BackgroundColor3=light(color,.28),Size=UDim2.new(1,-4,.55,0),Position=UDim2.fromOffset(2,2),ZIndex=z+1},base) corner(top,math.floor(h*.35))
 local sh=make("Frame",{BorderSizePixel=0,BackgroundColor3=C.White,BackgroundTransparency=.35,Size=UDim2.new(.28,0,.35,0),Position=UDim2.new(.14,0,.18,0),ZIndex=z+2},top) corner(sh,99)
end
local function studRow(parent,color,count,inset,w,h)
 do return nil end -- studs live on the surface now (studTex)
 local row=make("Frame",{Name="Studs",BackgroundTransparency=1,Size=UDim2.new(1-inset*2,0,0,0),Position=UDim2.new(inset,0,0,0),ZIndex=parent.ZIndex+1},parent)
 for i=1,count do stud(row,color,(i-.5)/count,w,h,parent.ZIndex+1) end return row
end
-- 3D brick: darker side under a coloured face. Returns holder, face
local function brick(parent,color,size,depth,props)
 depth=depth or 6
 local holder=make("Frame",{BackgroundTransparency=1,Size=size},parent)
 if props then for k,v in pairs(props) do holder[k]=v end end
 local side=make("Frame",{Name="Side",BackgroundColor3=dark(color,.38),Position=UDim2.fromOffset(0,depth),Size=UDim2.new(1,0,1,-depth)},holder) corner(side,12) stroke(side,3)
 local face=make("Frame",{Name="Face",BackgroundColor3=color,Size=UDim2.new(1,0,1,-depth)},holder) corner(face,12) stroke(face,3) studTex(face)
 make("Frame",{Name="Shine",BackgroundColor3=C.White,BackgroundTransparency=.72,BorderSizePixel=0,Position=UDim2.fromOffset(8,4),Size=UDim2.new(1,-16,0,4)},face).ZIndex=face.ZIndex
 return holder,face
end
-- pressable 3D brick button
local function button(parent,txt,color,onClick,opt)
 opt=opt or {}
 local depth=opt.depth or 6 local h=opt.h or 50
 local holder=make("Frame",{BackgroundTransparency=1,Size=opt.size or UDim2.new(opt.w and 0 or 1,opt.w or 0,0,h+depth),LayoutOrder=opt.order or nx()},parent)
 local side=make("Frame",{BackgroundColor3=dark(color,.4),Position=UDim2.fromOffset(0,depth),Size=UDim2.new(1,0,1,-depth)},holder) corner(side,12) stroke(side,3)
 local face=make("TextButton",{BackgroundColor3=color,Size=UDim2.new(1,0,1,-depth),Text="",AutoButtonColor=false},holder) corner(face,12) local fs=stroke(face,3) studTex(face)
 make("Frame",{BackgroundColor3=C.White,BackgroundTransparency=.65,BorderSizePixel=0,Position=UDim2.fromOffset(8,4),Size=UDim2.new(1,-16,0,4)},face)
 local t=title(face,txt,opt.textSize or 18,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.55),TextXAlignment=Enum.TextXAlignment.Center,AutomaticSize=Enum.AutomaticSize.None,Size=UDim2.new(1,-16,1,0),TextScaled=false,TextWrapped=true})
 if opt.studs~=false then studRow(face,color,opt.studs or 2,.22,22,10) end
 local enabled=true local pressed=false
 local function setDown(d) TweenService:Create(face,TweenInfo.new(.07),{Position=UDim2.fromOffset(0,d and depth-1 or 0)}):Play() end
 face.MouseButton1Down:Connect(function() if enabled then pressed=true setDown(true) end end)
 face.MouseButton1Up:Connect(function() pressed=false setDown(false) end)
 face.MouseLeave:Connect(function() if pressed then pressed=false setDown(false) end TweenService:Create(face,TweenInfo.new(.1),{BackgroundColor3=color}):Play() end)
 face.MouseEnter:Connect(function() if enabled then TweenService:Create(face,TweenInfo.new(.1),{BackgroundColor3=light(color,.12)}):Play() end end)
 local api={face=face,holder=holder,label=t,stroke=fs}
 face.Activated:Connect(function() if enabled and onClick then onClick(api) end end)
 function api.set(on,newText) enabled=on face.BackgroundColor3=on and color or C.Grey side.BackgroundColor3=on and dark(color,.4) or dark(C.Grey,.4) t.TextTransparency=on and 0 or .4 if newText then t.Text=newText end end
 function api.select(on) face.Position=UDim2.fromOffset(0,on and depth-2 or 0) fs.Color=on and C.White or INK fs.Thickness=on and 3.5 or 3 end
 return api
end
M.Button=button
local function grid(parent,cellW,cellH)
 local f=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=nx()},parent)
 make("UIGridLayout",{CellSize=UDim2.fromOffset(cellW,cellH),CellPadding=UDim2.fromOffset(12,14),SortOrder=Enum.SortOrder.LayoutOrder},f) return f
end
-- brick card with a coloured title strip + studs
local function card(parent,txt,color,sub)
 color=color or C.Blue
 local holder=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=nx()},parent)
 local body=make("Frame",{BackgroundColor3=C.Card,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y},holder) corner(body,14) stroke(body,3)
 make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,6),Position=UDim2.new(0,0,1,0)},holder)
 local head=make("Frame",{BackgroundColor3=color,Size=UDim2.new(1,0,0,46),LayoutOrder=0},body) corner(head,12) stroke(head,3) studTex(head)
 make("Frame",{BackgroundColor3=color,BorderSizePixel=0,Position=UDim2.new(0,3,1,-12),Size=UDim2.new(1,-6,0,10)},head)
 make("Frame",{BackgroundColor3=C.White,BackgroundTransparency=.7,BorderSizePixel=0,Position=UDim2.fromOffset(10,5),Size=UDim2.new(1,-20,0,4)},head)
 studRow(head,color,6,.04,26,12)
 title(head,txt,20,{Position=UDim2.fromOffset(16,12)})
 if sub then label(head,sub,14,light(color,.75),FB,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-16,0,15)}) end
 vlist(body,0)
 local inner=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,LayoutOrder=1},body)
 pad(inner,16) vlist(inner,12)
 return inner
end
local function input(parent,ph,numeric)
 local b=make("TextBox",{BackgroundColor3=C.Inset,PlaceholderText=ph,Text="",FontFace=F,TextSize=20,TextColor3=C.White,PlaceholderColor3=C.Grey,ClearTextOnFocus=false,Size=UDim2.new(1,0,0,50),TextXAlignment=Enum.TextXAlignment.Left,LayoutOrder=nx()},parent)
 corner(b,10) stroke(b,3) make("UIPadding",{PaddingLeft=UDim.new(0,16)},b)
 if numeric then b:GetPropertyChangedSignal("Text"):Connect(function() local t=b.Text:gsub("[^%d]","") if t~=b.Text then b.Text=t end end) end
 return b
end
local function fmt(n) n=tonumber(n) or 0 for _,u in ipairs({{1e12,"T"},{1e9,"B"},{1e6,"M"},{1e3,"K"}}) do if n>=u[1] then return (string.format("%.2f",n/u[1]):gsub("0+$",""):gsub("%.$",""))..u[2] end end return tostring(math.floor(n)) end

function M.Build(gui,ctx)
 local isOwner=ctx.role=="Owner"
 local accent=isOwner and C.Red or C.Blue
 local snap={players={},catalog={},admins={}}
 local logRows={}
 local scope,selectedId="me",ctx.userId
 local page="home"
 make("Frame",{Name="Dim",BackgroundColor3=rgb(10,12,20),BackgroundTransparency=.35,Size=UDim2.fromScale(1,1)},gui)
 local W,H=1180,730
 local root=make("Frame",{Name="Panel",AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(W,H),BackgroundTransparency=1},gui)
 local fit=make("UIScale",{},root)
 local function refit() local v=workspace.CurrentCamera.ViewportSize fit.Scale=math.clamp(math.min((v.X-20)/W,(v.Y-30)/(H+12)),.3,1) end
 workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(refit) refit()
 make("Frame",{BackgroundColor3=INK,Position=UDim2.fromOffset(0,12),Size=UDim2.new(1,0,1,0)},root).ZIndex=0
 local plate=make("Frame",{BackgroundColor3=C.Plate,Size=UDim2.fromScale(1,1)},root) corner(plate,18) stroke(plate,4)
 for _,c in ipairs(root:GetChildren()) do if c:IsA("Frame") and c.BackgroundColor3==INK then corner(c,18) end end
 -- top bar
 local top=make("Frame",{BackgroundColor3=accent,Position=UDim2.fromOffset(14,22),Size=UDim2.new(1,-28,0,74)},plate) corner(top,14) stroke(top,3) studTex(top)
 make("Frame",{BackgroundColor3=dark(accent,.35),Position=UDim2.new(0,0,1,-3),Size=UDim2.new(1,0,0,8),ZIndex=0},top)
 make("Frame",{BackgroundColor3=C.White,BackgroundTransparency=.7,BorderSizePixel=0,Position=UDim2.fromOffset(12,6),Size=UDim2.new(1,-24,0,5)},top)
 studRow(top,accent,16,.02,34,14)
 title(top,isOwner and "OWNER PANEL" or "ADMIN PANEL",34,{Position=UDim2.fromOffset(22,10)})
 label(top,"Hatch an Anime  •  server control",15,light(accent,.7),FB,{Position=UDim2.fromOffset(24,48)})
 local topRight=make("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-12,.5,2),Size=UDim2.fromOffset(640,56)},top)
 make("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,HorizontalAlignment=Enum.HorizontalAlignment.Right,VerticalAlignment=Enum.VerticalAlignment.Center,Padding=UDim.new(0,10),SortOrder=Enum.SortOrder.LayoutOrder},topRight)
 local target=make("Frame",{BackgroundColor3=dark(accent,.45),AutomaticSize=Enum.AutomaticSize.X,Size=UDim2.fromOffset(0,40),LayoutOrder=1},topRight) corner(target,10) stroke(target,3) pad(target,0,14)
 local targetText=title(target,"",16,{AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,0,.5,0),AutomaticSize=Enum.AutomaticSize.XY})
 local scopeBtns={}
 local content -- forward
 local render
 local closeBtn
 -- sidebar + content plates
 local side=make("Frame",{BackgroundTransparency=1,Position=UDim2.fromOffset(14,118),Size=UDim2.new(0,236,1,-132)},plate)
 vlist(side,10)
 local body=make("Frame",{BackgroundColor3=C.Plate2,Position=UDim2.fromOffset(264,112),Size=UDim2.new(1,-278,1,-126)},plate) corner(body,16) stroke(body,3)
 -- dotted stud pattern on the content plate
 local dots=make("Frame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ClipsDescendants=true},body) corner(dots,16)
 studTex(dots)
 content=make("ScrollingFrame",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=8,ScrollBarImageColor3=accent,BorderSizePixel=0},body)
 pad(content,22,20) vlist(content,22)
 -- toast
 local toastHolder=make("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(.5,0,1,-18),Size=UDim2.fromOffset(560,64),Visible=false,ZIndex=40},root)
 local toastFace=make("Frame",{BackgroundColor3=C.Green,Size=UDim2.new(1,0,0,58),ZIndex=41},toastHolder) corner(toastFace,12) stroke(toastFace,3)
 local toastText=title(toastFace,"",17,{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),TextXAlignment=Enum.TextXAlignment.Center,ZIndex=42,AutomaticSize=Enum.AutomaticSize.None,Size=UDim2.new(1,-24,1,0),TextWrapped=true})
 local toastId=0
 local function toast(ok,msg)
  toastId+=1 local id=toastId
  toastFace.BackgroundColor3=ok and C.Green or C.Red toastText.Text=(ok and "✓  " or "✕  ")..msg
  toastHolder.Visible=true toastHolder.Position=UDim2.new(.5,0,1,10)
  TweenService:Create(toastHolder,TweenInfo.new(.25,Enum.EasingStyle.Back),{Position=UDim2.new(.5,0,1,-18)}):Play()
  task.delay(2.8,function() if id==toastId then toastHolder.Visible=false end end)
 end
 local busy=false local confirmed=false
 local function ask(action,args,lbl,btn)
  if busy then return end busy=true
  local old=btn and btn.label.Text if btn then btn.set(false,"...") end
  args=args or {} args.confirmed=confirmed or args.confirmed args.scope=args.scope or scope args.userId=args.userId or selectedId
  local ok,res,msg=pcall(ctx.invoke,action,args)
  busy=false if btn then btn.set(true,old) end
  if not ok then res,msg=false,"Server didn't respond" end
  msg=type(msg)=="string" and msg or (res and "Done" or "Failed")
  table.insert(logRows,1,{time=os.date("%H:%M"),action=lbl or action,ok=res,msg=msg}) if #logRows>50 then table.remove(logRows) end
  toast(res,msg) return res,msg
 end
 local function refresh() local ok,res,data=pcall(ctx.invoke,"Snapshot",{}) if ok and res and type(data)=="table" then snap=data end end
 local function selected() for _,p in ipairs(snap.players) do if p.userId==selectedId then return p end end end
 local function confirm(head,text,onYes)
  local dim=make("TextButton",{Text="",AutoButtonColor=false,BackgroundColor3=rgb(10,12,20),BackgroundTransparency=.35,Size=UDim2.fromScale(1,1),ZIndex=50},root) corner(dim,18)
  local box=make("Frame",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(460,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,ZIndex=51},dim)
  local inner=card(box,head,C.Red)
  label(inner,text,17,C.Muted,FB,{TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0)})
  local row=grid(inner,200,62)
  button(row,"Cancel",C.Grey,function() dim:Destroy() end)
  button(row,"Confirm",C.Red,function() dim:Destroy() confirmed=true local ok,err=pcall(onYes) confirmed=false if not ok then toast(false,tostring(err)) end end)
  for _,d in ipairs(dim:GetDescendants()) do if d:IsA("GuiObject") then d.ZIndex=d.ZIndex+51 end end
 end
 local function header(txt,sub) local f=make("Frame",{BackgroundTransparency=1,Size=UDim2.new(1,0,0,62),LayoutOrder=nx()},content) title(f,txt,32) label(f,sub,16,C.Muted,FB,{Position=UDim2.fromOffset(2,40)}) end
 local function roleColor(r) return r=="Owner" and C.Red or r=="Admin" and C.Blue or C.Grey end
 local pages={}
 pages.home=function()
  header("Home","Live view of this server")
  local g=grid(content,196,112)
  local sel=selected()
  local stats={{"PLAYERS",tostring(#snap.players),C.Blue},{"SELECTED",sel and sel.name or "-",C.Purple},{"EVENT",(snap.event and snap.event~="None") and snap.event or "None",C.Orange},{"YOUR ROLE",ctx.role,accent}}
  for _,s in ipairs(stats) do
   local h,face=brick(g,s[3],UDim2.fromOffset(196,112)) studRow(face,s[3],3,.14,26,11)
   label(face,s[1],14,light(s[3],.75),FB,{Position=UDim2.fromOffset(16,14)})
   title(face,s[2],26,{Position=UDim2.fromOffset(16,40),AutomaticSize=Enum.AutomaticSize.None,Size=UDim2.new(1,-24,0,40),TextTruncate=Enum.TextTruncate.AtEnd})
  end
  local q=card(content,"Quick actions",C.Yellow)
  local g2=grid(q,250,62)
  if isOwner then button(g2,"Give $1M to me",C.Green,function(b) ask("GiveCash",{amount="1000000",scope="me"},"Give $1M",b) end) end
  button(g2,"Egg Shower",C.Teal,function(b) ask("EggShower",{amount=8},"Egg Shower",b) end)
  button(g2,"Start Egg Rush 5m",C.Orange,function(b) ask("StartEvent",{eventId="rush",seconds=300},"Egg Rush",b) end)
  button(g2,"Stop event",C.Red,function(b) ask("StopEvent",{},"Stop event",b) end)
  button(g2,"Find a player",C.Blue,function() page="players" render() end)
 end
 pages.players=function()
  header("Players",#snap.players.." in this server")
  local c=card(content,"Pick a player",C.Blue)
  for _,p in ipairs(snap.players) do
   local on=p.userId==selectedId
   local rowH,face=brick(c,on and C.Purple or C.Inset,UDim2.new(1,0,0,72),5,{LayoutOrder=nx()})
   local hit=make("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},face)
   local av=make("ImageLabel",{Image=("rbxthumb://type=AvatarHeadShot&id=%d&w=60&h=60"):format(p.userId),BackgroundColor3=C.Plate,Position=UDim2.fromOffset(10,8),Size=UDim2.fromOffset(50,50)},face) corner(av,10) stroke(av,2.5)
   title(face,p.name,19,{Position=UDim2.fromOffset(72,10)})
   label(face,"@"..p.user.."  •  "..p.userId,14,C.Muted,FB,{Position=UDim2.fromOffset(72,38)})
   if p.role then local tag=make("Frame",{AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-14,.5,0),Size=UDim2.fromOffset(0,32),AutomaticSize=Enum.AutomaticSize.X,BackgroundColor3=roleColor(p.role)},face) corner(tag,8) stroke(tag,2.5) pad(tag,0,12) title(tag,p.role:upper(),15,{AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,0,.5,0)}) end
   hit.Activated:Connect(function() selectedId=p.userId scope=(p.userId==ctx.userId) and "me" or "selected" render() end)
  end
  local sel=selected()
  local t=card(content,"Teleport",C.Teal,sel and ("Selected: "..sel.name) or "Select a player")
  local g=grid(t,250,62)
  button(g,"Bring to me",C.Teal,function(b) ask("Bring",{},"Bring",b) end)
  button(g,"Go to them",C.Teal,function(b) ask("GoTo",{},"Go to player",b) end)
  button(g,"Send home",C.Teal,function(b) ask("SendHome",{},"Send home",b) end)
  button(g,"Respawn",C.Orange,function() local s=selected() if s then confirm("Respawn "..s.name.."?","Their character will restart.",function() ask("Respawn",{},"Respawn") end) end end)
  local m=card(content,"Moderation",C.Red)
  local g3=grid(m,250,62)
  local can=sel and not sel.role
  local k=button(g3,"Kick",C.Red,function() local s=selected() if s then confirm("Kick "..s.name.."?","They are removed from this server and can rejoin.",function() ask("Kick",{userId=s.userId},"Kick") refresh() render() end) end end)
  k.set(can and true or false)
  if isOwner then
   local b=button(g3,"Ban 24 hours",dark(C.Red,.25),function() local s=selected() if s then confirm("Ban "..s.name.." for 24 hours?","Roblox ban. Only works in the published game.",function() ask("Ban",{userId=s.userId},"Ban 24h") end) end end)
   b.set(can and true or false)
   if sel and sel.userId~=ctx.userId and sel.role~="Owner" then
    local isAdmin=sel.role=="Admin"
    button(g3,isAdmin and "Remove admin" or "Make admin",C.Blue,function(btn) ask("SetAdmin",{userId=sel.userId,on=not isAdmin},isAdmin and "Remove admin" or "Make admin",btn) refresh() render() end)
   end
   local box=input(m,"User ID to unban",true)
   button(m,"Unban",C.Grey,function() if box.Text~="" then confirm("Unban "..box.Text.."?","Removes their active ban.",function() ask("Unban",{userId=box.Text},"Unban") end) end end,{w=250})
  end
  if not can then label(m,"Staff can't be kicked or banned. Pick a normal player.",15,C.Muted,FB,{LayoutOrder=nx()}) end
 end
 pages.eggs=function()
  header(isOwner and "Eggs & Characters" or "River Eggs",isOwner and "Give items or drop eggs in the river" or "Drop any egg into the river for everyone")
  local chosen
  local act=card(content,"Selected",C.Purple)
  local chosenText=title(act,"Pick an item below",22,{LayoutOrder=nx()})
  local g=grid(act,250,62)
  local b1,b2
  if isOwner then
   b1=button(g,"Give egg",C.Green,function(b) if chosen then local function give() ask("GiveEgg",{itemId=chosen.id},"Give "..chosen.name,b) end if scope=="lobby" then confirm("Give egg to everyone?",chosen.name,give) else give() end end end)
   b2=button(g,"Give character",C.Yellow,function(b) if chosen then local function give() ask("GiveCharacter",{itemId=chosen.id},"Give "..chosen.name,b) end if scope=="lobby" then confirm("Give character to everyone?",chosen.name,give) else give() end end end)
   b1.set(false) b2.set(false)
  end
  local b3=button(g,"Drop in river",C.Teal,function(b) if chosen then ask("SpawnEgg",{itemId=chosen.id},"River "..chosen.name,b) end end) b3.set(false)
  local list=card(content,"Catalog",C.Blue,#snap.catalog.." items")
  local cg=grid(list,190,84)
  for _,it in ipairs(snap.catalog) do
   local col=RC[it.rarity] or C.Grey
   local h,face=brick(cg,C.Inset,UDim2.fromOffset(190,84),5)
   make("Frame",{BackgroundColor3=col,BorderSizePixel=0,Size=UDim2.new(0,8,1,-16),Position=UDim2.fromOffset(8,8)},face)
   title(face,it.name,17,{Position=UDim2.fromOffset(24,12),AutomaticSize=Enum.AutomaticSize.None,Size=UDim2.new(1,-30,0,24),TextTruncate=Enum.TextTruncate.AtEnd})
   label(face,(it.rarity or ""):upper(),14,col,F,{Position=UDim2.fromOffset(24,42)})
   local hit=make("TextButton",{Text="",BackgroundTransparency=1,Size=UDim2.fromScale(1,1)},face)
   hit.Activated:Connect(function()
    chosen=it chosenText.Text=it.name.."  •  "..(it.rarity or "")
    if b1 then b1.set(it.eggAvailable) b2.set(it.charAvailable) end
    b3.set(it.eggAvailable and not it.noRiver)
    for _,o in ipairs(cg:GetChildren()) do local f=o:FindFirstChild("Face") if f then f:FindFirstChildOfClass("UIStroke").Color=INK end end
    face:FindFirstChildOfClass("UIStroke").Color=C.White
   end)
  end
 end
 pages.money=function()
  header("Money","Give or set cash")
  local c=card(content,"Amount",C.Green)
  local box=input(c,"Amount",true) box.Text="1000000"
  local prev=title(c,"",22,{LayoutOrder=nx()})
  local function upd() local n=tonumber(box.Text) prev.Text=n and n>0 and ("$"..fmt(n)) or "Enter an amount" end
  box:GetPropertyChangedSignal("Text"):Connect(upd) upd()
  local g=grid(c,130,58)
  for _,p in ipairs({{"1K",1e3},{"100K",1e5},{"1M",1e6},{"1B",1e9},{"1T",1e12}}) do button(g,p[1],C.Yellow,function() box.Text=tostring(p[2]) end,{h=46,studs=1}) end
  local a=card(content,"Send it",C.Yellow)
  local g2=grid(a,250,62)
  button(g2,"Give cash",C.Green,function(b) if scope=="lobby" then confirm("Give cash to everyone?","Every player gets $"..fmt(box.Text),function() ask("GiveCash",{amount=box.Text},"Give lobby",b) end) else ask("GiveCash",{amount=box.Text},"Give $"..fmt(box.Text),b) end end)
  button(g2,"Set exact balance",C.Orange,function() confirm("Replace balance?","Their current cash is overwritten.",function() ask("SetCash",{amount=box.Text},"Set $"..fmt(box.Text)) end) end)
  button(g2,"Give whole lobby",C.Purple,function() confirm("Give cash to everyone?","Every player gets $"..fmt(box.Text),function() ask("GiveCash",{amount=box.Text,scope="lobby"},"Give lobby $"..fmt(box.Text)) end) end)
 end
 pages.temple=function()
  header("Temples","Plot of the selected player")
  local sel=selected()
  if scope=="lobby" or not sel then card(content,"Pick one player first (Me or Selected)",C.Grey) return end
  local plot=sel.plot
  local c=card(content,sel.name.."'s temple",C.Orange,plot and ("Level "..(plot.level or 1).."/3  •  "..(plot.slots or 0).." slots") or "No plot")
  local g=grid(c,250,62)
  button(g,"Upgrade temple",C.Orange,function(b) ask("UpgradeTemple",{},"Upgrade temple",b) refresh() render() end)
  button(g,"Unlock next slot",C.Yellow,function(b) ask("UnlockSlot",{},"Unlock slot",b) refresh() render() end)
  button(g,"Add incubator",C.Teal,function(b) ask("AddIncubator",{},"Add incubator",b) refresh() render() end)
  if plot and plot.incubators then
   local ic=card(content,"Incubators",C.Teal)
   local g2=grid(ic,250,62)
   for i,lvl in pairs(plot.incubators) do button(g2,("#%d  Lv %d  ▲"):format(i,lvl),C.Teal,function(b) ask("UpgradeIncubator",{index=i},"Upgrade incubator "..i,b) refresh() render() end).set(lvl<3) end
  end
  local d=card(content,"Clean-up",C.Red)
  local g3=grid(d,250,62)
  button(g3,"Clear inventory",C.Red,function() confirm("Clear held inventory?","Removes held eggs and characters.",function() ask("ClearInventory",{},"Clear inventory") end) end)
  button(g3,"Clear placed",C.Red,function() confirm("Clear placed characters?","Removes every placed character on their plot.",function() ask("ClearPlaced",{},"Clear placed") end) end)
  button(g3,"Reset slots",C.Red,function() confirm("Reset slot unlocks?","Locks every slot except the first.",function() ask("ResetSlots",{},"Reset slots") end) end)
 end
 local dur=300
 pages.events=function()
  header("Events","Start server events for everyone")
  local d=card(content,"How long?",C.Purple)
  local g=grid(d,150,58)
  for _,x in ipairs({{"5 min",300},{"10 min",600},{"30 min",1800}}) do local b=button(g,x[1],C.Purple,function() dur=x[2] render() end,{h=46,studs=1}) b.select(dur==x[2]) end
  local eg=card(content,"Events",C.Orange,(snap.event and snap.event~="None") and ("Running: "..snap.event) or "Nothing running")
  local g2=grid(eg,250,110)
  for _,ev in ipairs({{"rush","EGG RUSH","Eggs spawn 2x faster",C.Orange},{"cash","DOUBLE CASH","All income doubled",C.Green},{"gold","GOLDEN HOUR","Golden sunset",C.Yellow}}) do
   local h=make("Frame",{BackgroundTransparency=1,LayoutOrder=nx()},g2) vlist(h,4)
   button(h,ev[2],ev[4],function(b) ask("StartEvent",{eventId=ev[1],seconds=dur},"Start "..ev[2],b) refresh() end,{h=56})
   label(h,ev[3].."  •  "..math.floor(dur/60).." min",14,C.Muted,FB,{LayoutOrder=nx()})
  end
  local g3=grid(eg,250,62)
  button(g3,"EGG SHOWER",C.Teal,function(b) ask("EggShower",{amount=8},"Egg Shower",b) end)
  button(g3,"Stop event",C.Red,function(b) ask("StopEvent",{},"Stop event",b) refresh() end)
  local an=card(content,"Announcement",C.Pink,"Shows a banner to everyone")
  local box=input(an,"Write a message for the whole server...",false)
  local g4=grid(an,250,62)
  button(g4,"Send announcement",C.Pink,function(b) ask("Announce",{text=box.Text,color="pink"},"Announcement",b) end)
  local r=card(content,"River speed",C.Blue,"Seconds between eggs (1.5 - 30)")
  local rb=input(r,"e.g. 4",false)
  button(r,"Set river speed",C.Blue,function(b) ask("SetSpawnInterval",{seconds=rb.Text},"River speed "..rb.Text.."s",b) end,{w=250})
 end
 pages.admins=function()
  header("Admins","People who can open the Admin Panel")
  local c=card(content,"Current admins",C.Blue)
  if #(snap.admins or {})==0 then label(c,"No admins yet.",16,C.Muted,FB,{LayoutOrder=nx()}) end
  for _,a in ipairs(snap.admins or {}) do
   local h,face=brick(c,C.Inset,UDim2.new(1,0,0,66),5,{LayoutOrder=nx()})
   local av=make("ImageLabel",{Image=("rbxthumb://type=AvatarHeadShot&id=%d&w=60&h=60"):format(a.userId),BackgroundColor3=C.Plate,Position=UDim2.fromOffset(10,7),Size=UDim2.fromOffset(46,46)},face) corner(av,10) stroke(av,2.5)
   title(face,a.name,18,{Position=UDim2.fromOffset(68,9)})
   label(face,tostring(a.userId)..(a.fixed and "  •  set in AdminRoles script" or ""),14,C.Muted,FB,{Position=UDim2.fromOffset(68,35)})
   do local on=game:GetService("Players"):GetPlayerByUserId(tonumber(a.userId) or 0)~=nil
    label(face,on and "● ONLINE — can use the panel now" or "○ offline",14,on and C.Green or C.Grey,FB,{Position=UDim2.fromOffset(68,53)}) end
   if not a.fixed then
    local holder=make("Frame",{BackgroundTransparency=1,AnchorPoint=Vector2.new(1,.5),Position=UDim2.new(1,-10,.5,0),Size=UDim2.fromOffset(130,48)},face)
    button(holder,"Remove",C.Red,function(b) ask("SetAdmin",{userId=a.userId,on=false},"Remove admin",b) refresh() render() end,{h=40,studs=false,size=UDim2.fromScale(1,1),textSize=16})
   end
  end
  local add=card(content,"Add an admin",C.Green,"Saved in the published game")
  local box=input(add,"User ID",true)
  button(add,"Add admin",C.Green,function(b) if box.Text~="" then ask("SetAdmin",{userId=box.Text,on=true},"Add admin",b) refresh() render() end end,{w=250})
  local info=card(content,"What admins can do",C.Grey)
  label(info,"✓ Start / stop events, Egg Shower, drop eggs in the river\n✓ Announcements, river speed\n✓ Teleport, send home, respawn, kick normal players\n✕ No money, no giving eggs/characters, no bans, no temple edits",16,C.White,FB,{LayoutOrder=nx(),TextWrapped=true,AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0)})
 end
 pages.log=function()
  header("Activity","Your last 50 actions this session")
  local c=card(content,"Log",C.Grey)
  if #logRows==0 then label(c,"Nothing yet.",16,C.Muted,FB,{LayoutOrder=nx()}) end
  for _,l in ipairs(logRows) do
   local h,face=brick(c,l.ok and dark(C.Green,.35) or dark(C.Red,.3),UDim2.new(1,0,0,48),4,{LayoutOrder=nx()})
   title(face,l.time.."   "..l.action,16,{Position=UDim2.fromOffset(14,11)})
   label(face,l.msg,14,C.White,FB,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,13)})
  end
 end
 local NAV=isOwner and {{"home","Home",C.Red},{"players","Players",C.Blue},{"eggs","Eggs",C.Purple},{"money","Money",C.Green},{"temple","Temples",C.Orange},{"events","Events",C.Yellow},{"admins","Admins",C.Teal},{"log","Activity",C.Grey}}
  or {{"home","Home",C.Blue},{"players","Players",C.Purple},{"eggs","River Eggs",C.Teal},{"events","Events",C.Yellow},{"log","Activity",C.Grey}}
 local navBtns={}
 for i,n in ipairs(NAV) do navBtns[n[1]]=button(side,n[2],n[3],function() page=n[1] render() end,{h=50,order=i,textSize=19}) end
 local scopes=isOwner and {{"me","Me"},{"selected","Selected"},{"lobby","Lobby"}} or {{"me","Me"},{"selected","Selected"}}
 for i,s in ipairs(scopes) do
  scopeBtns[s[1]]=button(topRight,s[2],C.Yellow,function() scope=s[1] if scope=="me" then selectedId=ctx.userId end render() end,{w=96,h=40,depth=5,studs=1,order=1+i,textSize=16})
 end
 closeBtn=button(topRight,"X",C.Red,function() gui.Enabled=false end,{w=48,h=40,depth=5,studs=1,order=10,textSize=20})
 closeBtn.face.BackgroundColor3=dark(C.Red,.1)
 render=function()
  for _,ch in ipairs(content:GetChildren()) do if ch:IsA("GuiObject") then ch:Destroy() end end
  order=0
  for id,b in pairs(navBtns) do b.select(id==page) end
  for id,b in pairs(scopeBtns) do b.select(id==scope) end
  local sel=selected()
  targetText.Text=scope=="lobby" and ("Target: everyone ("..#snap.players..")") or scope=="me" and ("Target: me") or (sel and ("Target: "..sel.name) or "Target: nobody")
  pages[page]()
  content.CanvasPosition=Vector2.zero
 end
 local api={}
 function api.open() refresh() render() gui.Enabled=true refit() root.Position=UDim2.new(.5,0,.5,30) TweenService:Create(root,TweenInfo.new(.25,Enum.EasingStyle.Back),{Position=UDim2.fromScale(.5,.5)}):Play() end
 function api.close() gui.Enabled=false end
 function api.toggle() if gui.Enabled then api.close() else api.open() end end
 function api.refresh() if gui.Enabled then refresh() render() end end
 function api.show(p) page=p render() end
 return api
end
return M

-- StudSkin texture is applied by StarterPlayerScripts.StudSkin
