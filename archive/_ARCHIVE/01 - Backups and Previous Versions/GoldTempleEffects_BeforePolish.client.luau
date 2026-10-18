local RunService=game:GetService("RunService")
local player=game.Players.LocalPlayer
local active={}
local function add(model)
 if not model:IsA("Model") or model:GetAttribute("TempleAppearance")~="Gold" or active[model] then return end
 local cf,size=model:GetBoundingBox()
 local root=Instance.new("Part") root.Name="LocalGoldShimmer" root.Size=Vector3.new(1,1,1) root.Anchored=true root.Transparency=1 root.CanCollide=false root.CanTouch=false root.CanQuery=false root.CastShadow=false root.CFrame=cf*CFrame.new(0,size.Y*.32,0) root.Parent=workspace
 local a=Instance.new("Attachment") a.Parent=root
 local e=Instance.new("ParticleEmitter") e.Name="GoldDust" e.Texture="rbxasset://textures/particles/sparkles_main.dds" e.Color=ColorSequence.new(Color3.fromRGB(255,229,137),Color3.fromRGB(237,161,38)) e.LightEmission=.75 e.Rate=3 e.Lifetime=NumberRange.new(1.2,2.2) e.Speed=NumberRange.new(.35,1.2) e.SpreadAngle=Vector2.new(180,180) e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.08),NumberSequenceKeypoint.new(.3,.2),NumberSequenceKeypoint.new(1,0)}) e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.15,.25),NumberSequenceKeypoint.new(1,1)}) e.Parent=a
 local light=Instance.new("PointLight") light.Color=Color3.fromRGB(255,198,86) light.Brightness=.35 light.Range=math.min(18,size.X*.5) light.Shadows=false light.Parent=a
 active[model]={root=root,emitter=e,light=light}
 e:Emit(18)
end
workspace.DescendantAdded:Connect(function(v)
 if v:IsA("Model") then task.defer(function()if v.Parent then add(v)end end) end
end)
for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("Model") then add(v) end end
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt if elapsed<.25 then return end elapsed=0
 local camera=workspace.CurrentCamera
 for model,item in pairs(active) do
  if not model:IsDescendantOf(workspace) or model:GetAttribute("TempleAppearance")~="Gold" then item.root:Destroy() active[model]=nil
  else local near=camera and (camera.CFrame.Position-item.root.Position).Magnitude<140 item.emitter.Enabled=near or false item.light.Enabled=near or false end
 end
end)
