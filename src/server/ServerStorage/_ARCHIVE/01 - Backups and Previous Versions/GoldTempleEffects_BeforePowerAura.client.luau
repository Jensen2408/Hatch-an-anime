local RunService=game:GetService("RunService")
local active,pending={},{}
local function add(model,burst)
 if not model:IsDescendantOf(workspace) or model:GetAttribute("TempleAppearance")~="Gold" or active[model] then return end
 local cf,size=model:GetBoundingBox()
 local root=Instance.new("Part")
 root.Name="LocalGoldShimmer" root.Size=Vector3.one root.Anchored=true root.Transparency=1
 root.CanCollide=false root.CanTouch=false root.CanQuery=false root.CastShadow=false
 root.CFrame=cf root.Parent=workspace
 local emitters,lights={},{}
 for i=1,5 do
  local a=Instance.new("Attachment")
  local x,z=0,0
  if i<=4 then x=(i<=2 and -1 or 1)*size.X*.38 z=(i%2==0 and -1 or 1)*size.Z*.38 end
  a.Position=Vector3.new(x,i==5 and size.Y*.44 or size.Y*.05,z) a.Parent=root
  local e=Instance.new("ParticleEmitter") e.Name="GoldMotes"
  e.Texture="rbxasset://textures/particles/sparkles_main.dds"
  e.Color=ColorSequence.new(Color3.fromRGB(255,242,178),Color3.fromRGB(255,175,36))
  e.LightEmission=1 e.LightInfluence=.1
  e.Rate=i==5 and 1.5 or 1 e.Lifetime=NumberRange.new(1.8,3)
  e.Speed=NumberRange.new(.6,1.8) e.Acceleration=Vector3.new(0,.3,0)
  e.SpreadAngle=Vector2.new(35,35)
  e.Rotation=NumberRange.new(0,180) e.RotSpeed=NumberRange.new(-30,30)
  e.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.25,.28),NumberSequenceKeypoint.new(.6,.12),NumberSequenceKeypoint.new(1,0)})
  e.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.1),NumberSequenceKeypoint.new(.7,.4),NumberSequenceKeypoint.new(1,1)})
  e.Parent=a table.insert(emitters,e)
  if burst then e:Emit(i==5 and 14 or 5) end
  if i==1 or i==4 then
   local light=Instance.new("PointLight") light.Color=Color3.fromRGB(255,195,74)
   light.Brightness=.45 light.Range=14 light.Shadows=false light.Parent=a table.insert(lights,light)
  end
 end
 local sheen=Instance.new("Highlight") sheen.Name="GoldSheen" sheen.Adornee=model
 sheen.DepthMode=Enum.HighlightDepthMode.Occluded sheen.FillColor=Color3.fromRGB(255,211,102)
 sheen.OutlineTransparency=1 sheen.FillTransparency=.96 sheen.Parent=root
 active[model]={root=root,emitters=emitters,lights=lights,sheen=sheen,phase=math.random()*6}
end
local function queue(model)
 if not model:IsA("Model") or model:GetAttribute("TempleAppearance")~="Gold" or pending[model] or active[model] then return end
 pending[model]=true
 -- Wait until the ground-rise assembly has reached its final positions.
 task.delay(4.5,function()pending[model]=nil add(model,true)end)
end
workspace.DescendantAdded:Connect(queue)
for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("Model") then add(v,false) end end
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
 elapsed+=dt if elapsed<.1 then return end elapsed=0
 local camera=workspace.CurrentCamera local now=os.clock()
 for model,item in pairs(active) do
  if not model:IsDescendantOf(workspace) or model:GetAttribute("TempleAppearance")~="Gold" then
   item.root:Destroy() active[model]=nil
  else
   local near=camera and (camera.CFrame.Position-item.root.Position).Magnitude<140 or false
   for _,e in ipairs(item.emitters) do e.Enabled=near end
   for _,light in ipairs(item.lights) do light.Enabled=near light.Brightness=.35+.12*(.5+.5*math.sin(now*1.5+item.phase)) end
   item.sheen.Enabled=near
   item.sheen.FillTransparency=.95+.025*math.sin(now*1.15+item.phase)
  end
 end
end)
