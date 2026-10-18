local RunService=game:GetService("RunService")
local m=workspace:WaitForChild("PirateEggConveyor")
local folder=workspace:WaitForChild("WaterfallEggs")
local motion=require(m:WaitForChild("RollingMotion"))
local active={}
local function added(egg)
 if not egg:IsA("Model") then return end
 task.spawn(function()
  egg:WaitForChild("LabelAnchor");egg:WaitForChild("CollectAnchor")
  if egg.Parent then active[egg]=motion(m,egg) end
 end)
end
folder.ChildAdded:Connect(added)
folder.ChildRemoved:Connect(function(egg) active[egg]=nil end)
for _,egg in folder:GetChildren() do added(egg) end
RunService.RenderStepped:Connect(function()
 for egg,update in active do if egg.Parent then update() else active[egg]=nil end end
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
folder.ChildAdded:Connect(watchGold)
folder.ChildRemoved:Connect(clearGold)
for _,egg in folder:GetChildren() do watchGold(egg) end
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
