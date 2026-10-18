-- Temporary filming setup. Studio only; remove this script to revert.
local Run=game:GetService("RunService")
if not Run:IsStudio() then return end
local Players=game:GetService("Players")
local UIS=game:GetService("UserInputService")
local StarterGui=game:GetService("StarterGui")
local player=Players.LocalPlayer
local camera=workspace.CurrentCamera
local stage=Instance.new("Folder");stage.Name="TEMP_FilmingActors";stage.Parent=workspace
local actors={}
local hidden={}
local savedGUI={}
local running=false
local elapsed=0
local controls
local original
local function restore()
 running=false
 Run:UnbindFromRenderStep("TEMP_FilmingCamera")
 for gui,enabled in savedGUI do if gui.Parent then gui.Enabled=enabled end end
 savedGUI={}
 pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,true)end)
 for part,alpha in hidden do if part.Parent then part.LocalTransparencyModifier=alpha end end
 hidden={}
 if controls then controls:Enable()end
 if original then camera.CameraType=original.kind;camera.CameraSubject=original.subject;camera.FieldOfView=original.fov end
end
local function hideUI()
 for _,gui in player.PlayerGui:GetChildren()do if gui:IsA("ScreenGui") and gui.Name~="TEMP_FilmCountdown"then savedGUI[gui]=gui.Enabled;gui.Enabled=false end end
 pcall(function()StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.All,false)end)
end
player.PlayerGui.ChildAdded:Connect(function(gui)if running and gui:IsA("ScreenGui")then savedGUI[gui]=gui.Enabled;gui.Enabled=false end end)
local function prepare()
 local char=player.Character or player.CharacterAdded:Wait()
 char.Archivable=true
 for _,plot in workspace.Plots:GetChildren()do
  -- Reveal existing set dressing locally for the promotional shot.
  for _,v in plot:GetDescendants()do
   if v:IsA("BasePart") and v:GetAttribute("ClaimTransparency")~=nil then v.Transparency=v:GetAttribute("ClaimTransparency")end
  end
  local avatar=char:Clone();avatar.Name="FilmingPlayer"
  for _,x in avatar:GetDescendants()do
   if x:IsA("LuaSourceContainer") or x:IsA("Animator") or x:IsA("BillboardGui") or x:IsA("Tool")then x:Destroy()
   elseif x:IsA("BasePart")then x.CanCollide=false;x.CanTouch=false;x.CanQuery=false end
  end
  local root=avatar:FindFirstChild("HumanoidRootPart")
  if root then
   root.Anchored=true
   local hum=avatar:FindFirstChildOfClass("Humanoid");if hum then hum.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None end
   local origin=plot.PlotSpawn.Position+Vector3.new(0,3,0)
   avatar.Parent=stage
   local joints={}
   for _,j in avatar:GetDescendants()do if j:IsA("Motor6D")then joints[j]=j.C0 end end
   table.insert(actors,{model=avatar,origin=origin,joints=joints,phase=#actors*1.4})
  else avatar:Destroy()end
 end
end
local function ease(t)return t*t*(3-2*t)end
local keys={
 {t=0,p=Vector3.new(-255,235,90),look=Vector3.new(-170,27,20),fov=65},
 {t=10,p=Vector3.new(-245,45,20),look=Vector3.new(-170,28,20),fov=60},
 {t=27,p=Vector3.new(135,43,20),look=Vector3.new(195,29,20),fov=60},
 {t=35,p=Vector3.new(150,53,5),look=Vector3.new(150,31,-92),fov=58},
 {t=43,p=Vector3.new(155,53,35),look=Vector3.new(155,31,114),fov=58},
 {t=55,p=Vector3.new(25,245,80),look=Vector3.new(-35,27,20),fov=68},
}
local function start()
 if running then return end
 original={kind=camera.CameraType,subject=camera.CameraSubject,fov=camera.FieldOfView}
 pcall(function()controls=require(player.PlayerScripts:WaitForChild("PlayerModule")):GetControls();controls:Disable()end)
 running=true;elapsed=0;hideUI()
 if player.Character then for _,p in player.Character:GetDescendants()do if p:IsA("BasePart")then hidden[p]=p.LocalTransparencyModifier;p.LocalTransparencyModifier=1 end end end
 Run:BindToRenderStep("TEMP_FilmingCamera",Enum.RenderPriority.Camera.Value+20,function(dt)
  elapsed+=dt
  local a,b=keys[#keys-1],keys[#keys]
  for i=1,#keys-1 do if elapsed<=keys[i+1].t then a,b=keys[i],keys[i+1];break end end
  local u=ease(math.clamp((elapsed-a.t)/(b.t-a.t),0,1))
  camera.CameraType=Enum.CameraType.Scriptable
  camera.CFrame=CFrame.lookAt(a.p:Lerp(b.p,u),a.look:Lerp(b.look,u))
  camera.FieldOfView=a.fov+(b.fov-a.fov)*u
  for _,actor in actors do
   local t=elapsed+actor.phase
   local pos=actor.origin+Vector3.new(math.sin(t*.3)*12,math.abs(math.sin(t*3))*.08,math.cos(t*.3)*4)
   local dir=Vector3.new(math.cos(t*.3)*12,0,-math.sin(t*.3)*4)
   actor.model:PivotTo(CFrame.lookAt(pos,pos+dir))
   for joint,base in actor.joints do
    local name=joint.Name:lower()
    local swing=math.sin(t*6)*.42
    if name:find("hip") or name:find("shoulder") then
     joint.C0=base*CFrame.Angles(name:find("right") and swing or -swing,0,0)
    elseif name:find("elbow")then joint.C0=base*CFrame.Angles(-.2,0,0)end
   end
  end
  -- Hold the final sky shot until replay or exit.
 end)
end
UIS.InputBegan:Connect(function(input,processed)
 if input.KeyCode==Enum.KeyCode.Escape then restore()
 elseif not processed and input.KeyCode==Enum.KeyCode.R then restore();start()end
end)
local deadline=os.clock()+25
repeat task.wait(.2)until player:GetAttribute("LoadingScreenDone")==true or os.clock()>deadline
task.wait(3)
prepare()
local gui=Instance.new("ScreenGui");gui.Name="TEMP_FilmCountdown";gui.IgnoreGuiInset=true;gui.Parent=player.PlayerGui
local text=Instance.new("TextLabel");text.Size=UDim2.fromScale(1,.15);text.Position=UDim2.fromScale(0,.4);text.BackgroundTransparency=.25;text.BackgroundColor3=Color3.new(0,0,0);text.TextColor3=Color3.new(1,1,1);text.Font=Enum.Font.GothamBold;text.TextSize=28;text.Parent=gui
for i=5,1,-1 do text.Text="Filming starts in "..i.."  |  R replay · Esc exit";task.wait(1)end
gui:Destroy()
start()
