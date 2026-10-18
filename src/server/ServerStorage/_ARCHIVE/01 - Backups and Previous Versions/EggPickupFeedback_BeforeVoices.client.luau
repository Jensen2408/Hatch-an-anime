local Players=game:GetService("Players")
local RS=game:GetService("ReplicatedStorage")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local SoundService=game:GetService("SoundService")
local player=Players.LocalPlayer
local catalog=require(RS:WaitForChild("EggCatalog"))
local entries={};for _,e in ipairs(catalog) do entries[e.Id]=e end
local gui=Instance.new("ScreenGui");gui.Name="EggPickupFeedback";gui.ResetOnSpawn=false;gui.Parent=player:WaitForChild("PlayerGui")
local Style=require(RS:WaitForChild("EggUIStyle"))
local holder=Instance.new("Frame");holder.Name="PickupCard";holder.AnchorPoint=Vector2.new(.5,1);holder.Position=UDim2.fromScale(.5,.83);holder.Size=UDim2.new(.8,0,0,60);holder.BackgroundTransparency=1;holder.Visible=false;holder.Parent=gui
local constraint=Instance.new("UISizeConstraint");constraint.MaxSize=Vector2.new(370,60);constraint.Parent=holder
local panel=Style.Panel(holder,Color3.fromRGB(70,195,90))
local label=Style.Text(panel,"",UDim2.fromScale(.04,.1),UDim2.fromScale(.92,.8))
local scale=Instance.new("UIScale");scale.Parent=holder
local sound=Instance.new("Sound")
sound.Name="EggPickupSoft"
sound.SoundId="rbxasset://sounds/volume_slider.ogg"
sound.Volume=0
sound.PlaybackSpeed=.85
sound.Parent=SoundService
local eq=Instance.new("EqualizerSoundEffect")
eq.HighGain=-18;eq.MidGain=-5;eq.LowGain=0;eq.Parent=sound
task.spawn(function() pcall(function() game:GetService("ContentProvider"):PreloadAsync({sound}) end) end)
local soundSerial=0
local soundTween
local function playPickup()
 soundSerial+=1;local token=soundSerial
 if soundTween then soundTween:Cancel() end
 sound:Stop();sound.Volume=0;sound.TimePosition=0;sound:Play()
 soundTween=TweenService:Create(sound,TweenInfo.new(.07,Enum.EasingStyle.Sine),{Volume=.18});soundTween:Play()
 task.delay(.16,function()
  if token~=soundSerial then return end
  soundTween=TweenService:Create(sound,TweenInfo.new(.28,Enum.EasingStyle.Sine),{Volume=0});soundTween:Play()
  task.delay(.29,function() if token==soundSerial then sound:Stop() end end)
 end)
end
local serial=0
RS:WaitForChild("EggCollected").OnClientEvent:Connect(function(id,from,size)
 local e=entries[id];local template=RS.EggVisuals:FindFirstChild(id);if not e or not template then return end
 local character=player.Character;local root=character and character:FindFirstChild("HumanoidRootPart");if not root then return end
 local visual=template:Clone();visual.Name="CollectingEgg";visual.Size=size;visual.CFrame=from;visual.Anchored=true;visual.CanCollide=false;visual.CanTouch=false;visual.CanQuery=false;visual.Parent=workspace
 local elapsed=0;local duration=.65;local connection
 connection=RunService.RenderStepped:Connect(function(dt)
 elapsed+=dt;local t=math.min(elapsed/duration,1)
 if not root.Parent then connection:Disconnect();visual:Destroy();return end
 local target=root.CFrame:PointToWorldSpace(Vector3.new(0,.6,1.25))
 local control=(from.Position+target)/2+Vector3.new(0,5,0)
 local u=t*t*(3-2*t)
 local pos=(1-u)^2*from.Position+2*(1-u)*u*control+u*u*target
 visual.CFrame=CFrame.new(pos)*from.Rotation*CFrame.Angles(0,u*math.pi*2,0)
 visual.Size=size*math.max(.05,1-.95*u)
 if t>=1 then
 connection:Disconnect();visual:Destroy()
 playPickup()
 serial+=1;local token=serial
 label.Text="+1 "..e.Name.." Egg";holder.Visible=true;scale.Scale=.8;TweenService:Create(scale,TweenInfo.new(.25,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
 task.delay(1.7,function() if serial==token then holder.Visible=false end end)
 end
 end)
end)