-- Temporary filming setup. Studio and published owner filming; remove this script to revert.
local Run=game:GetService("RunService")

local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local StarterGui=game:GetService("StarterGui")
local player=Players.LocalPlayer
if not Run:IsStudio() and player.UserId~=168774222 then return end
local camera=workspace.CurrentCamera
local oldStage=workspace:FindFirstChild("TEMP_FilmingActors");if oldStage then oldStage:Destroy()end
local hidden={}
local savedGUI={}
local savedBillboards={}
local topbarWasEnabled=true
local running=false
local elapsed=0
local hiddenEggPrices={}
local function hideEggPrice(v)
 if not running then return end
 local label=v:IsA("BillboardGui") and v or v:FindFirstAncestorWhichIsA("BillboardGui")
 if label and label.Name:sub(1,9)=="EggLabel_" then
  if hiddenEggPrices[label]==nil then hiddenEggPrices[label]=label.Enabled end
  label.Enabled=false
 end
end
player:WaitForChild("PlayerGui").DescendantAdded:Connect(hideEggPrice)

local controls
local original
local function restore()
 running=false
 Run:UnbindFromRenderStep("TEMP_FilmingCamera")
 for v,visible in hiddenEggPrices do if v.Parent then v.Enabled=visible end end
 hiddenEggPrices={}

 for gui,enabled in savedGUI do if gui.Parent then gui.Enabled=enabled end end
 savedGUI={}
 pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true)end)
 pcall(function()StarterGui:SetCore("TopbarEnabled",topbarWasEnabled)end)
 for gui,enabled in savedBillboards do if gui.Parent then gui.Enabled=enabled end end
 savedBillboards={}

 for part,alpha in hidden do if part.Parent then part.LocalTransparencyModifier=alpha end end
 hidden={}
 if controls then controls:Enable()end
 if original then camera.CameraType=original.kind;camera.CameraSubject=original.subject;camera.FieldOfView=original.fov end
end
local function hideUI()
 for _,gui in player.PlayerGui:GetChildren()do if gui:IsA("ScreenGui") and gui.Name~="TEMP_FilmCountdown" and gui.Name~="HatchLoading"then savedGUI[gui]=gui.Enabled;gui.Enabled=false end end
 pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false)end)
 pcall(function()StarterGui:SetCore("TopbarEnabled",false)end)
end
player.PlayerGui.ChildAdded:Connect(function(gui)if running and gui:IsA("ScreenGui") and gui.Name~="HatchLoading"then savedGUI[gui]=gui.Enabled;gui.Enabled=false end end)
local function prepare()
 for _,plot in workspace.Plots:GetChildren()do
  for _,v in plot:GetDescendants()do
   if v:IsA("BasePart") and v:GetAttribute("ClaimTransparency")~=nil then v.Transparency=v:GetAttribute("ClaimTransparency")end
  end
 end
end
local function ease(t)return t*t*(3-2*t)end
local function shot(t)
 local pos,yaw,pitch,fov
 if t<10 then
  local u=ease(t/10)
  pos=Vector3.new(-255,235,90):Lerp(Vector3.new(-245,45,20),u)
  local direction=Vector3.new(-170,27,20)-pos
  return CFrame.lookAt(pos,pos+direction),65-5*u
 elseif t<42 then
  local u=(t-10)/32
  pos=Vector3.new(-245+465*u,45,20)
  -- Two relaxed sweeps across the temples while continuing downriver.
  yaw=math.sin(u*math.pi*4)*1.12
  pitch=-.16
  fov=60
 elseif t<45 then
  local u=ease((t-42)/3)
  pos=Vector3.new(220,45,20)
  yaw=0;pitch=-.16+1.26*u;fov=60
 elseif t<51 then
  local u=ease((t-45)/6)
  pos=Vector3.new(220+100*u,45+275*u,20+140*u)
  yaw=0;pitch=1.1;fov=60+10*u
 elseif t<56 then
  local u=ease((t-51)/5)
  pos=Vector3.new(320,320,160)
  local target=Vector3.new(-35,27,20)
  local delta=target-pos
  local targetYaw=math.atan2(delta.Z,delta.X)
  -- Turn smoothly back toward the map instead of stopping at a straight-down view.
  yaw=targetYaw*u
  pitch=1.1+(math.asin(delta.Unit.Y)-1.1)*u
  fov=70
 else
  pos=Vector3.new(320,320,160)
  local target=Vector3.new(-35,27,20)
  return CFrame.lookAt(pos,target),70
 end
 local direction=Vector3.new(math.cos(yaw)*math.cos(pitch),math.sin(pitch),math.sin(yaw)*math.cos(pitch))
 return CFrame.lookAt(pos,pos+direction),fov
end
local function start()
 if running then return end
 original={kind=camera.CameraType,subject=camera.CameraSubject,fov=camera.FieldOfView}
 pcall(function()topbarWasEnabled=StarterGui:GetCore("TopbarEnabled")end)
 pcall(function()controls=require(player.PlayerScripts:FindFirstChild("PlayerModule")):GetControls();controls:Disable()end)
 running=true;elapsed=0;hideUI()
 for _,v in player.PlayerGui:GetDescendants()do hideEggPrice(v)end
 if player.Character then for _,p in player.Character:GetDescendants()do if p:IsA("BasePart")then hidden[p]=p.LocalTransparencyModifier;p.LocalTransparencyModifier=1 end end end
 Run:BindToRenderStep("TEMP_FilmingCamera",Enum.RenderPriority.Camera.Value+20,function(dt)
  elapsed+=dt
  for _,gui in workspace:GetDescendants()do
   if gui:IsA("BillboardGui") then
    if savedBillboards[gui]==nil then savedBillboards[gui]=gui.Enabled end
    gui.Enabled=false
   end
  end
  -- Other scripts can re-enable their menus and tags; keep the recording clean.
  for _,gui in player.PlayerGui:GetChildren()do
   if gui:IsA("ScreenGui") and gui.Name~="TEMP_FilmCountdown" and gui.Name~="HatchLoading" then
    if savedGUI[gui]==nil then savedGUI[gui]=gui.Enabled end
    gui.Enabled=false
   end
  end
  for _,p in Players:GetPlayers()do
   if p.Character then
    for _,gui in p.Character:GetDescendants()do
     if gui:IsA("BillboardGui") then
      if savedBillboards[gui]==nil then savedBillboards[gui]=gui.Enabled end
      gui.Enabled=false
     end
    end
   end
  end
  if math.floor(elapsed*2)~=math.floor((elapsed-dt)*2) then
   pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false)end)
   pcall(function()StarterGui:SetCore("TopbarEnabled",false)end)
  end
  for _,v in player.PlayerGui:GetDescendants()do
   if v:IsA("BillboardGui") and v.Name:sub(1,9)=="EggLabel_" then hideEggPrice(v)end
  end
  local cf,fov=shot(elapsed)
  camera.CameraType=Enum.CameraType.Scriptable
  camera.CFrame=cf
  camera.FieldOfView=fov
  -- Hold the final sky shot until replay or exit.
 end)
end
UIS.InputBegan:Connect(function(input,processed)
 if input.KeyCode==Enum.KeyCode.Escape then restore()
 elseif not processed and input.KeyCode==Enum.KeyCode.R then restore();start()end
end)
local deadline=os.clock()+25
repeat task.wait(.2)until player:GetAttribute("LoadingScreenDone")==true or os.clock()>deadline
local char=player.Character or player.CharacterAdded:Wait()
char:WaitForChild("HumanoidRootPart",15)
local readyDeadline=os.clock()+10
repeat task.wait(.2) until player:GetAttribute("StartupSessionReady")==true or os.clock()>readyDeadline
prepare()
local gui=Instance.new("ScreenGui");gui.Name="TEMP_FilmCountdown";gui.IgnoreGuiInset=true;gui.Parent=player.PlayerGui
local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,.15);text.Position=UDim2.fromScale(0,.4);text.BackgroundTransparency=.25;text.BackgroundColor3=Color3.new(0,0,0);text.TextColor3=Color3.new(1,1,1);text.Font=Enum.Font.GothamBold;text.TextSize=28;text.Parent=gui
for i=5,1,-1 do text.Text="Filming starts in "..i.."  |  R replay · Esc exit";task.wait(1)end
gui:Destroy()
start()
