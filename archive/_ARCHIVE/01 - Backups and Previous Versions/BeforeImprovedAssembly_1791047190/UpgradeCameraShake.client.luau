-- Client half of the upgrade reveal: white flash, FOV punch, bloom spike,
-- and a short camera kick. Everything scales down with distance.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local TweenService=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local Lighting=game:GetService("Lighting")
local ReplicatedStorage=game:GetService("ReplicatedStorage")

local player=Players.LocalPlayer
local camera=workspace.CurrentCamera
local BASE_FOV=camera.FieldOfView   -- captured once: a punch mid-recovery must not become the new base
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
 camera=workspace.CurrentCamera
end)

local RANGE=150
local SHAKE_TIME=.30
local MAX_OFFSET=.55
local MAX_TILT=.9
local FOV_PUNCH=7

local gui=Instance.new("ScreenGui")
gui.Name="UpgradeFlash"
gui.ResetOnSpawn=false
gui.IgnoreGuiInset=true
gui.DisplayOrder=2000
gui.Parent=player:WaitForChild("PlayerGui")

local flash=Instance.new("Frame")
flash.Size=UDim2.fromScale(1,1)
flash.BackgroundColor3=Color3.new(1,1,1)
flash.BackgroundTransparency=1
flash.BorderSizePixel=0
flash.Parent=gui

local shake=0
local seed=0

local function doFlash(intensity,tint)
 flash.BackgroundColor3=Color3.new(1,1,1):Lerp(tint or Color3.new(1,1,1),.25)
 flash.BackgroundTransparency=1-intensity
 -- snap to white, hold one beat, then ease out
 task.delay(.06,function()
  TweenService:Create(flash,TweenInfo.new(.26,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
    {BackgroundTransparency=1}):Play()
 end)
end

local function doFov(intensity)
 if not camera then return end
 camera.FieldOfView=BASE_FOV-FOV_PUNCH*intensity
 TweenService:Create(camera,
   TweenInfo.new(.45,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{FieldOfView=BASE_FOV}):Play()
end

local function doBloom(intensity)
 local bloom=Instance.new("BloomEffect")
 bloom.Intensity=1.6*intensity
 bloom.Size=24
 bloom.Threshold=.8
 bloom.Parent=Lighting
 TweenService:Create(bloom,TweenInfo.new(.55,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),
   {Intensity=0}):Play()
 Debris:AddItem(bloom,.9)
end

local function onUpgrade(data)
 if not data or not data.position then return end

 local character=player.Character
 local root=character and character:FindFirstChild("HumanoidRootPart")
 local origin=root and root.Position or (camera and camera.CFrame.Position)
 if not origin then return end

 local distance=(origin-data.position).Magnitude
 if distance>RANGE then return end

 local falloff=1-(distance/RANGE)
 local intensity=math.clamp(falloff*falloff*(data.strength or 1),0,1)
 if intensity<=.02 then return end

 shake=math.max(shake,intensity)
 seed=os.clock()*37

 if data.flash then
  doFlash(math.min(intensity*.92,.92),data.tint)
  doBloom(intensity)
 end
 doFov(intensity)
end

ReplicatedStorage:WaitForChild("UpgradeShake").OnClientEvent:Connect(onUpgrade)

RunService:BindToRenderStep("UpgradeCameraShake",Enum.RenderPriority.Camera.Value+1,function(dt)
 if shake<=.001 then return end
 shake=math.max(0,shake-dt/SHAKE_TIME)
 if not camera then return end

 local t=os.clock()*34+seed
 local decay=shake*shake
 camera.CFrame=camera.CFrame
   *CFrame.new(math.noise(t,0)*MAX_OFFSET*decay,math.noise(0,t)*MAX_OFFSET*decay,0)
   *CFrame.Angles(0,0,math.noise(t,t)*math.rad(MAX_TILT)*decay)
end)
