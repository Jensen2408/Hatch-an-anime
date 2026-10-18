-- Shows Owner/Admin announcements and event starts as a stud banner at the top of the screen (all players).
local Players=game:GetService("Players")
local TweenService=game:GetService("TweenService")
local RS=game:GetService("ReplicatedStorage")
local Button=nil
local event=RS:WaitForChild("OwnerPanel"):WaitForChild("Announcement")
local INK=Color3.fromRGB(40,24,18)
local COLORS={red=Color3.fromRGB(226,66,60),blue=Color3.fromRGB(66,134,236),green=Color3.fromRGB(92,192,70),gold=Color3.fromRGB(248,188,44),pink=Color3.fromRGB(236,90,160),purple=Color3.fromRGB(150,100,230)}
local F=Font.new("rbxasset://fonts/families/FredokaOne.json")
local gui=Instance.new("ScreenGui") gui.Name="StaffAnnouncements" gui.ResetOnSpawn=false gui.DisplayOrder=60 gui.IgnoreGuiInset=true gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local function mk(c,p,parent) local o=Instance.new(c) for k,v in pairs(p) do o[k]=v end o.Parent=parent return o end
local function stud(parent,color,x)
	local b=mk("Frame",{AnchorPoint=Vector2.new(.5,1),Position=UDim2.new(x,0,0,2),Size=UDim2.fromOffset(34,14),BackgroundColor3=color:Lerp(Color3.new(),.18),BorderSizePixel=0},parent)
	mk("UICorner",{CornerRadius=UDim.new(0,6)},b) mk("UIStroke",{Color=INK,Thickness=2.5},b)
	local t=mk("Frame",{BorderSizePixel=0,BackgroundColor3=color:Lerp(Color3.new(1,1,1),.28),Size=UDim2.new(1,-4,.55,0),Position=UDim2.fromOffset(2,2)},b) mk("UICorner",{CornerRadius=UDim.new(0,5)},t)
end
local queue,showing={},false
local function show(d)
	showing=true
	local color=COLORS[d.color] or COLORS.red
	local holder=mk("Frame",{AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,-140),Size=UDim2.fromOffset(620,104),BackgroundTransparency=1},gui)
	mk("UISizeConstraint",{MaxSize=Vector2.new(620,104)},holder)
	local scale=mk("UIScale",{Scale=math.clamp((workspace.CurrentCamera.ViewportSize.X-24)/620,.5,1)},holder)
	local side=mk("Frame",{BackgroundColor3=color:Lerp(Color3.new(),.4),Position=UDim2.fromOffset(0,8),Size=UDim2.new(1,0,1,-8)},holder) mk("UICorner",{CornerRadius=UDim.new(0,14)},side) mk("UIStroke",{Color=INK,Thickness=3},side)
	local face=mk("Frame",{BackgroundColor3=color,Size=UDim2.new(1,0,1,-8)},holder) mk("UICorner",{CornerRadius=UDim.new(0,14)},face) mk("UIStroke",{Color=INK,Thickness=3},face)
	mk("Frame",{BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.7,BorderSizePixel=0,Position=UDim2.fromOffset(12,5),Size=UDim2.new(1,-24,0,4)},face)
	for i=1,8 do stud(face,color,(i-.5)/8) end
	local t=mk("TextLabel",{BackgroundTransparency=1,Text=tostring(d.title or ""),FontFace=F,TextSize=26,TextColor3=Color3.new(1,1,1),Position=UDim2.fromOffset(0,10),Size=UDim2.new(1,0,0,32)},face) mk("UIStroke",{Color=INK,Thickness=3},t)
	local b=mk("TextLabel",{BackgroundTransparency=1,Text=tostring(d.text or ""),FontFace=F,TextSize=19,TextColor3=Color3.new(1,1,1),TextWrapped=true,Position=UDim2.fromOffset(16,44),Size=UDim2.new(1,-32,0,44)},face) mk("UIStroke",{Color=INK,Thickness=2},b)
	TweenService:Create(holder,TweenInfo.new(.45,Enum.EasingStyle.Back),{Position=UDim2.new(.5,0,0,70)}):Play()
	task.wait(5.5)
	TweenService:Create(holder,TweenInfo.new(.3),{Position=UDim2.new(.5,0,0,-140)}):Play()
	task.wait(.35) holder:Destroy()
	showing=false
	if #queue>0 then show(table.remove(queue,1)) end
end
event.OnClientEvent:Connect(function(d) if type(d)~="table" then return end if showing then if #queue<3 then table.insert(queue,d) end else task.spawn(show,d) end end)
