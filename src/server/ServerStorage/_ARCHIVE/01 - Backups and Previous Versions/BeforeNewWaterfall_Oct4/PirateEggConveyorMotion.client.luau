local RunService=game:GetService("RunService")
local m=workspace:WaitForChild("PirateEggConveyor")
local folder=workspace:WaitForChild("WaterfallEggs")
local motion=require(m:WaitForChild("RollingMotion"))
local remote=game.ReplicatedStorage:WaitForChild("CollectRiverEgg")
local visuals=Instance.new("Folder");visuals.Name="LocalRiverEggs";visuals.Parent=workspace
local active={}
local function hide(p)
 if p:IsA("BasePart") then p.LocalTransparencyModifier=1
 elseif p:IsA("BillboardGui") or p:IsA("ProximityPrompt") then p.Enabled=false end
end
local function added(source)
 if not source:IsA("Model") or active[source] then return end
 local record={};active[source]=record
 task.spawn(function()
  if not source:WaitForChild("LabelAnchor",10) or not source:WaitForChild("CollectAnchor",10) or not source.Parent then active[source]=nil;return end
  local egg=source:Clone()
  for _,p in egg:GetDescendants() do if p:IsA("BasePart") then p.LocalTransparencyModifier=0;p.CanCollide=false end end
  record.visual=egg
  for _,p in source:GetDescendants() do hide(p) end
  record.connection=source.DescendantAdded:Connect(hide)
  record.update=motion(m,egg)
  record.update()
  local prompt=egg.CollectAnchor:FindFirstChildOfClass("ProximityPrompt")
  if prompt then prompt.Triggered:Connect(function() remote:FireServer(source) end) end
  egg.Parent=visuals
 end)
end
folder.ChildAdded:Connect(added)
folder.ChildRemoved:Connect(function(source)
 local record=active[source]
 if record then
  if record.connection then record.connection:Disconnect() end
  if record.visual then record.visual:Destroy() end
  active[source]=nil
 end
end)
for _,egg in folder:GetChildren() do added(egg) end
RunService:BindToRenderStep("RiverEggVisualMotion",Enum.RenderPriority.Camera.Value+1,function()
 for _,record in active do if record.update and record.visual.Parent then record.update() end end
end)
-- Local water reflection follows gold eggs without adding replicated moving parts.
local golden={}
local function clearGold(egg)
 local effect=golden[egg]
 if effect then effect.host:Destroy();golden[egg]=nil end
end
local function watchGold(egg)
 if not egg:IsA("Model") or not egg:GetAttribute("Golden") or golden[egg] then return end
 local host=Instance.new("Part");host.Name="GoldenWaterGlow";host.Size=Vector3.one;host.Transparency=1;host.Anchored=true;host.CanCollide=false;host.CanTouch=false;host.CanQuery=false;host.Parent=workspace
 local light=Instance.new("PointLight");light.Color=Color3.fromRGB(255,191,65);light.Brightness=.8;light.Range=11;light.Shadows=false;light.Enabled=false;light.Parent=host
 local glow=Instance.new("ParticleEmitter");glow.Name="WaterShimmer";glow.Texture="rbxasset://textures/particles/smoke_main.dds";glow.Orientation=Enum.ParticleOrientation.VelocityPerpendicular;glow.Rate=0;glow.Speed=NumberRange.new(.015,.03);glow.EmissionDirection=Enum.NormalId.Top;glow.Lifetime=NumberRange.new(.65,.9);glow.LightEmission=.85;glow.Color=ColorSequence.new(Color3.fromRGB(255,191,54));glow.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,3.5),NumberSequenceKeypoint.new(1,6)});glow.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.72),NumberSequenceKeypoint.new(1,1)});glow.Parent=host
 local sparks=Instance.new("ParticleEmitter");sparks.Name="GoldFlecks";sparks.Texture="rbxasset://textures/particles/sparkles_main.dds";sparks.Rate=0;sparks.Speed=NumberRange.new(.3,.8);sparks.SpreadAngle=Vector2.new(60,60);sparks.Lifetime=NumberRange.new(.4,.8);sparks.LightEmission=.8;sparks.Color=ColorSequence.new(Color3.fromRGB(255,225,139));sparks.Size=NumberSequence.new(.12);sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.3),NumberSequenceKeypoint.new(1,1)});sparks.Parent=host
 golden[egg]={host=host,light=light,glow=glow,sparks=sparks}
end
visuals.ChildAdded:Connect(watchGold)
visuals.ChildRemoved:Connect(clearGold)
for _,egg in visuals:GetChildren() do watchGold(egg) end
RunService.RenderStepped:Connect(function()
 for egg,fx in golden do
  if not egg.Parent then clearGold(egg) else
   local pos=egg:GetPivot().Position
   local epoch=egg:GetAttribute("Epoch") or workspace:GetServerTimeNow()
   local age=workspace:GetServerTimeNow()-epoch
   local visible=age>=(m:GetAttribute("DropDuration") or 1.8) and pos.X<= (m:GetAttribute("ExitX") or 235) and (workspace.CurrentCamera.CFrame.Position-pos).Magnitude<160
   fx.host.Position=Vector3.new(pos.X,24.8,pos.Z)
   fx.light.Enabled=visible;fx.glow.Rate=visible and 9 or 0;fx.sparks.Rate=visible and 5 or 0
  end
 end
end)
