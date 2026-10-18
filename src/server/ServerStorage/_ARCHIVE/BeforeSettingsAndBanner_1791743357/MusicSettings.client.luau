
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local player=Players.LocalPlayer
local gui=Instance.new("ScreenGui")
gui.Name="MusicSettingsUI" gui.ResetOnSpawn=false gui.DisplayOrder=45 gui.Parent=player:WaitForChild("PlayerGui")
local function corner(o,r) local c=Instance.new("UICorner",o) c.CornerRadius=UDim.new(0,r) end
local function label(parent,text,size,pos,font)
 local l=Instance.new("TextLabel") l.BackgroundTransparency=1 l.Size=size l.Position=pos l.Text=text l.Font=font or Enum.Font.GothamBold l.TextSize=16 l.TextColor3=Color3.fromRGB(245,245,250) l.Parent=parent return l
end
local function button(parent,text,size,pos)
 local b=Instance.new("TextButton") b.Size=size b.Position=pos b.Text=text b.Font=Enum.Font.GothamBold b.TextSize=14 b.TextColor3=Color3.fromRGB(245,245,250) b.BackgroundColor3=Color3.fromRGB(25,29,37) b.Parent=parent corner(b,8) return b
end
local toggle=button(gui,"SETTINGS",UDim2.fromOffset(126,36),UDim2.new(1,-148,0,118))
local panel=Instance.new("Frame") panel.Name="Panel" panel.Size=UDim2.fromOffset(280,164) panel.Position=UDim2.new(1,-302,0,162) panel.BackgroundColor3=Color3.fromRGB(16,19,25) panel.Visible=false panel.Parent=gui corner(panel,12)
local stroke=Instance.new("UIStroke",panel) stroke.Color=Color3.fromRGB(66,70,81)
label(panel,"SETTINGS",UDim2.fromOffset(200,30),UDim2.fromOffset(18,12)).TextXAlignment=Enum.TextXAlignment.Left
local close=button(panel,"×",UDim2.fromOffset(28,28),UDim2.fromOffset(235,12))
label(panel,"Music volume",UDim2.fromOffset(160,26),UDim2.fromOffset(18,51)).TextXAlignment=Enum.TextXAlignment.Left
local value=label(panel,"100%",UDim2.fromOffset(70,26),UDim2.fromOffset(194,51))
local track=Instance.new("Frame") track.Name="VolumeSlider" track.Size=UDim2.fromOffset(244,8) track.Position=UDim2.fromOffset(18,91) track.BackgroundColor3=Color3.fromRGB(49,54,64) track.Parent=panel corner(track,4)
local fill=Instance.new("Frame") fill.Size=UDim2.fromScale(1,1) fill.BackgroundColor3=Color3.fromRGB(255,207,109) fill.BorderSizePixel=0 fill.Parent=track corner(fill,4)
local knob=button(track,"",UDim2.fromOffset(18,18),UDim2.new(1,-9,.5,-9)) knob.BackgroundColor3=Color3.fromRGB(250,250,255)
local hit=button(panel,"",UDim2.fromOffset(244,30),UDim2.fromOffset(18,80)) hit.BackgroundTransparency=1
local mute=button(panel,"MUTE",UDim2.fromOffset(244,30),UDim2.fromOffset(18,117))
local volume=1 local previous=1 local originals={} local dragging=false
local function isMusic(sound)
 local music=workspace:FindFirstChild("Music")
 return sound:IsA("Sound") and music and sound:IsDescendantOf(music)
end
local function register(sound)
 if not isMusic(sound) or originals[sound] then return end
 originals[sound]=sound.Volume
 sound.Volume=originals[sound]*volume
end
local function setVolume(v)
 volume=math.clamp(v,0,1)
 value.Text=tostring(math.floor(volume*100+.5)).."%"
 fill.Size=UDim2.fromScale(volume,1) knob.Position=UDim2.new(volume,-9,.5,-9)
 mute.Text=volume==0 and "UNMUTE" or "MUTE"
 for sound,base in pairs(originals) do if sound.Parent then sound.Volume=base*volume else originals[sound]=nil end end
 player:SetAttribute("MusicVolume",volume)
end
local function drag(x) setVolume((x-track.AbsolutePosition.X)/track.AbsoluteSize.X) end
hit.InputBegan:Connect(function(input)
 if input.UserInputType==Enum.UserInputType.MouseButton1 or input.UserInputType==Enum.UserInputType.Touch then dragging=input drag(input.Position.X) end
end)
UIS.InputChanged:Connect(function(input)
 if dragging and (input.UserInputType==Enum.UserInputType.MouseMovement or input==dragging) then drag(input.Position.X) end
end)
UIS.InputEnded:Connect(function(input)
 if input==dragging or input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)
mute.Activated:Connect(function() if volume>0 then previous=volume setVolume(0) else setVolume(previous) end end)
toggle.Activated:Connect(function() panel.Visible=not panel.Visible end)
close.Activated:Connect(function() panel.Visible=false end)
workspace.DescendantAdded:Connect(register)
for _,sound in ipairs(workspace:GetDescendants()) do register(sound) end
setVolume(1)
toggle.Visible=false
task.spawn(function()
 repeat task.wait(.15) until not gui.Parent:FindFirstChild("AnimeEggPreloader")
 toggle.Visible=true
end)
