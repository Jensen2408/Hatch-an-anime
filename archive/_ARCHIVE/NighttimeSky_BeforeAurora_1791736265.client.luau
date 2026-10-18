local Lighting=game:GetService("Lighting")
local Tween=game:GetService("TweenService")
local Players=game:GetService("Players")
local day={ClockTime=Lighting.ClockTime,Brightness=Lighting.Brightness,Ambient=Lighting.Ambient,OutdoorAmbient=Lighting.OutdoorAmbient,ExposureCompensation=Lighting.ExposureCompensation}
local night={ClockTime=24,Brightness=1.1,Ambient=Color3.fromRGB(55,62,95),OutdoorAmbient=Color3.fromRGB(65,78,115),ExposureCompensation=-.15}
local grade=Instance.new("ColorCorrectionEffect");grade.Name="NighttimeGrade";grade.Parent=Lighting
local gui=Instance.new("ScreenGui");gui.Name="NighttimeStatus";gui.ResetOnSpawn=false;gui.DisplayOrder=50;gui.Parent=Players.LocalPlayer:WaitForChild("PlayerGui")
local label=Instance.new("TextLabel");label.AnchorPoint=Vector2.new(.5,0);label.Position=UDim2.fromScale(.5,.035);label.Size=UDim2.fromOffset(410,42);label.BackgroundColor3=Color3.fromRGB(25,28,55);label.BackgroundTransparency=.15;label.TextColor3=Color3.fromRGB(255,235,170);label.Font=Enum.Font.GothamBold;label.TextSize=17;label.Parent=gui
local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,12);corner.Parent=label
local current,gradeTween
local function change()
 local active=workspace:GetAttribute("NighttimeActive")==true
 if current then current:Cancel()end;if gradeTween then gradeTween:Cancel()end
 local target=active and night or day
 -- Continue forward through midnight instead of sweeping backwards through daytime.
 if not active then Lighting.ClockTime=Lighting.ClockTime%24 end
 current=Tween:Create(Lighting,TweenInfo.new(2.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),target);current:Play()
 gradeTween=Tween:Create(grade,TweenInfo.new(2.5),{TintColor=active and Color3.fromRGB(200,217,255) or Color3.new(1,1,1),Saturation=active and -.08 or 0});gradeTween:Play()
end
workspace:GetAttributeChangedSignal("NighttimeActive"):Connect(change);change()
while true do
 local active=workspace:GetAttribute("NighttimeActive")==true
 label.Visible=active
 if active then label.Text="NIGHTTIME  •  2× CASH / HATCH / LUCK  •  "..math.max(0,math.ceil((workspace:GetAttribute("NighttimeEndsAt") or 0)-workspace:GetServerTimeNow())).."s" end
 task.wait(.2)
end