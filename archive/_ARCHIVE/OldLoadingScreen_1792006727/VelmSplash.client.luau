-- VelmSplash: studio intro shown on top of the loading screen while the game loads underneath (adds no wait).
local Players=game:GetService("Players") local TS=game:GetService("TweenService") local CP=game:GetService("ContentProvider")
local GuiService=game:GetService("GuiService")
local player=Players.LocalPlayer
local LOGO=script:GetAttribute("Logo")
local gui=Instance.new("ScreenGui") gui.Name="VelmSplash" gui.IgnoreGuiInset=true gui.ResetOnSpawn=false gui.DisplayOrder=1000000 gui.ScreenInsets=Enum.ScreenInsets.None
local bg=Instance.new("Frame",gui) bg.Size=UDim2.fromScale(1,1) bg.BackgroundColor3=Color3.new(0,0,0) bg.BorderSizePixel=0
-- the artwork fills the screen (it already has the spotlight + floor), cropped to fit any shape
local art=Instance.new("ImageLabel",bg) art.BackgroundTransparency=1 art.Image=LOGO art.ScaleType=Enum.ScaleType.Crop
art.AnchorPoint=Vector2.new(.5,.5) art.Position=UDim2.fromScale(.5,.5) art.Size=UDim2.fromScale(1.06,1.06) art.ImageTransparency=1
local vig=Instance.new("Frame",bg) vig.Size=UDim2.fromScale(1,1) vig.BackgroundColor3=Color3.new(0,0,0) vig.BorderSizePixel=0 vig.BackgroundTransparency=1 vig.ZIndex=3
local g=Instance.new("UIGradient",vig) g.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.15),NumberSequenceKeypoint.new(0.25,1),NumberSequenceKeypoint.new(0.75,1),NumberSequenceKeypoint.new(1,0.15)})
-- a soft light sweep across the logo
local sweep=Instance.new("Frame",bg) sweep.AnchorPoint=Vector2.new(.5,.5) sweep.Position=UDim2.fromScale(-0.3,.47) sweep.Size=UDim2.fromScale(.18,.5) sweep.BackgroundColor3=Color3.new(1,1,1) sweep.BorderSizePixel=0 sweep.Rotation=18 sweep.ZIndex=2 sweep.BackgroundTransparency=1
local sg=Instance.new("UIGradient",sweep) sg.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.5,0.82),NumberSequenceKeypoint.new(1,1)})
gui.Parent=player:WaitForChild("PlayerGui")
pcall(function() CP:PreloadAsync({art}) end)
local reduced=GuiService.ReducedMotionEnabled
local function tw(o,t,p,style,dir) local x=TS:Create(o,TweenInfo.new(t,style or Enum.EasingStyle.Quad,dir or Enum.EasingDirection.Out),p) x:Play() return x end
-- 1. logo eases in with a slow push-in
tw(art,0.9,{ImageTransparency=0},Enum.EasingStyle.Sine)
if not reduced then tw(art,3.0,{Size=UDim2.fromScale(1,1)},Enum.EasingStyle.Sine,Enum.EasingDirection.InOut) end
task.wait(0.8)
if not reduced then sweep.BackgroundTransparency=0 tw(sweep,0.9,{Position=UDim2.fromScale(1.3,.47)},Enum.EasingStyle.Quad,Enum.EasingDirection.InOut) end
task.wait(1.4)
-- 2. fade out to reveal the game's loading screen
tw(art,0.55,{ImageTransparency=1},Enum.EasingStyle.Sine) tw(bg,0.7,{BackgroundTransparency=1},Enum.EasingStyle.Sine)
task.wait(0.75)
gui:Destroy()
