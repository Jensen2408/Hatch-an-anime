-- Announcement banner (staff announcements, events, /update). Rounded 3D card in the game's clean style: no pill studs.
-- /update countdown ticks update ONE banner in place instead of stacking five.
local Players=game:GetService("Players")
local TS=game:GetService("TweenService")
local RS=game:GetService("ReplicatedStorage")
local event=RS:WaitForChild("OwnerPanel"):WaitForChild("Announcement")
local INK=Color3.fromRGB(17,23,26)
local STUDS="rbxassetid://132561191216691"
local GLOW="rbxassetid://130563114903838"
local THEMES={
	red={Color3.fromRGB(255,95,95),Color3.fromRGB(210,35,45),"📢"},
	blue={Color3.fromRGB(90,170,255),Color3.fromRGB(40,100,230),"📢"},
	green={Color3.fromRGB(130,235,90),Color3.fromRGB(55,170,40),"✅"},
	gold={Color3.fromRGB(255,215,70),Color3.fromRGB(240,140,0),"⭐"},
	pink={Color3.fromRGB(255,130,200),Color3.fromRGB(220,50,140),"💬"},
	purple={Color3.fromRGB(190,140,255),Color3.fromRGB(110,60,220),"🌙"},
}
local F=Font.new("rbxasset://fonts/families/FredokaOne.json")
local gui=Instance.new("ScreenGui") gui.Name="StaffAnnouncements" gui.ResetOnSpawn=false gui.DisplayOrder=60 gui.IgnoreGuiInset=true gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local function mk(c,p,parent) local o=Instance.new(c) for k,v in pairs(p) do o[k]=v end o.Parent=parent return o end
local function round(o,r) mk("UICorner",{CornerRadius=UDim.new(0,r)},o) end
local function label(par,text,size,props) local l=mk("TextLabel",{BackgroundTransparency=1,Text=text,FontFace=F,TextSize=size,TextColor3=Color3.new(1,1,1),TextWrapped=true},par) mk("UIStroke",{Color=INK,Thickness=size>=24 and 3 or 2},l) for k,v in pairs(props or {}) do l[k]=v end return l end

local queue,current={},nil
local function build(d)
	local th=THEMES[d.color] or THEMES.red
	local isUpdate=d.isUpdate==true
	local W,H=640,isUpdate and 132 or 118
	local holder=mk("Frame",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,-170),Size=UDim2.fromOffset(W,H),BackgroundTransparency=1},gui)
	mk("UIScale",{Scale=math.clamp((workspace.CurrentCamera.ViewportSize.X-24)/W,.5,1)},holder)
	-- 3D base
	local base=mk("Frame",{BackgroundColor3=th[2]:Lerp(Color3.new(),.45),Position=UDim2.fromOffset(0,8),Size=UDim2.new(1,0,1,-8)},holder) round(base,20) mk("UIStroke",{Color=INK,Thickness=3.5},base)
	local face=mk("Frame",{BackgroundColor3=Color3.new(1,1,1),Size=UDim2.new(1,0,1,-8),ClipsDescendants=true},holder) round(face,20) mk("UIStroke",{Color=INK,Thickness=3.5},face)
	mk("UIGradient",{Rotation=90,Color=ColorSequence.new(th[1],th[2])},face)
	local st=mk("ImageLabel",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image=STUDS,ScaleType=Enum.ScaleType.Tile,TileSize=UDim2.fromOffset(26,26),ImageTransparency=.15},face) round(st,20)
	local gl=mk("Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.65,BorderSizePixel=0,Position=UDim2.fromOffset(18,6),Size=UDim2.new(1,-36,0,5)},face) round(gl,99)
	-- shine sweep
	local sweep=mk("Frame",{BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,Size=UDim2.fromScale(1,1)},face) round(sweep,20)
	local sg=mk("UIGradient",{Rotation=20,Offset=Vector2.new(-1.2,0),Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.44,1),NumberSequenceKeypoint.new(.5,.45),NumberSequenceKeypoint.new(.56,1),NumberSequenceKeypoint.new(1,1)})},sweep)
	TS:Create(sg,TweenInfo.new(1.1,Enum.EasingStyle.Sine,Enum.EasingDirection.Out,-1,false,1.6),{Offset=Vector2.new(1.2,0)}):Play()
	-- icon badge
	local badge=mk("Frame",{AnchorPoint=Vector2.new(0,.5),Position=UDim2.new(0,16,.5,-4),Size=UDim2.fromOffset(74,74),BackgroundColor3=th[2]:Lerp(Color3.new(),.35)},face) round(badge,18) mk("UIStroke",{Color=INK,Thickness=3},badge)
	local glow=mk("ImageLabel",{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1.6,1.6),Image=GLOW,ImageColor3=th[1],ImageTransparency=.35},badge)
	TS:Create(glow,TweenInfo.new(8,Enum.EasingStyle.Linear,Enum.EasingDirection.In,-1),{Rotation=360}):Play()
	local icon=mk("TextLabel",{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Text=isUpdate and "🚨" or th[3],TextSize=40,FontFace=F},badge)
	local bob=mk("UIScale",{},icon) TS:Create(bob,TweenInfo.new(.6,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,-1,true),{Scale=1.12}):Play()
	-- text
	local title=label(face,tostring(d.title or ""),28,{Position=UDim2.fromOffset(104,12),Size=UDim2.new(1,-120,0,34),TextXAlignment=Enum.TextXAlignment.Left,TextScaled=true})
	mk("UITextSizeConstraint",{MaxTextSize=28},title)
	local body=label(face,tostring(d.text or ""),19,{Position=UDim2.fromOffset(104,48),Size=UDim2.new(1,-120,0,isUpdate and 34 or 42),TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top})
	local by=d.by and d.by~="Server" and label(face,"— "..tostring(d.by),13,{AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-16,1,-8),Size=UDim2.fromOffset(240,16),TextXAlignment=Enum.TextXAlignment.Right,TextColor3=Color3.fromRGB(240,240,240)}) or nil
	-- time bar
	local trough=mk("Frame",{AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,104,1,-12),Size=UDim2.new(1,by and -372 or -124,0,8),BackgroundColor3=Color3.fromRGB(20,30,36),BackgroundTransparency=.2},face) round(trough,99)
	local fill=mk("Frame",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1)},trough) round(fill,99)
	TS:Create(holder,TweenInfo.new(.5,Enum.EasingStyle.Back),{Position=UDim2.new(.5,0,0,64)}):Play()
	return {holder=holder,body=body,fill=fill,title=title,update=isUpdate}
end
local function hide(c) TS:Create(c.holder,TweenInfo.new(.3,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{Position=UDim2.new(.5,0,0,-170)}):Play() task.wait(.32) c.holder:Destroy() end
local function play(d)
	current=build(d)
	local dur=d.isUpdate and 1.3 or 5.5
	current.until_=os.clock()+dur
	TS:Create(current.fill,TweenInfo.new(dur,Enum.EasingStyle.Linear),{Size=UDim2.fromScale(0,1)}):Play()
	while os.clock()<current.until_ do task.wait(.1) end
	local c=current current=nil hide(c)
	if #queue>0 then task.spawn(play,table.remove(queue,1)) end
end
event.OnClientEvent:Connect(function(d)
	if type(d)~="table" then return end
	-- /update countdown: refresh the banner that is already showing
	if d.isUpdate and current and current.update then
		current.body.Text=tostring(d.text or "") current.title.Text=tostring(d.title or current.title.Text)
		current.until_=os.clock()+1.3 current.fill.Size=UDim2.fromScale(1,1)
		TS:Create(current.fill,TweenInfo.new(1.3,Enum.EasingStyle.Linear),{Size=UDim2.fromScale(0,1)}):Play()
		return
	end
	if current then if #queue<3 then table.insert(queue,d) end else task.spawn(play,d) end
end)
