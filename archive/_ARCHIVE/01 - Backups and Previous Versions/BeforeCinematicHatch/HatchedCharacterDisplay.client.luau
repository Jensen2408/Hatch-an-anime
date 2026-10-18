local Collection=game:GetService("CollectionService")
local RunService=game:GetService("RunService")
local Tween=game:GetService("TweenService")
local Debris=game:GetService("Debris")
local active={}
local function add(model)
 if active[model] then return end
 local home=model:GetAttribute("RewardHome")
 if not home then return end
 active[model]={home=home,epoch=model:GetAttribute("RevealEpoch") or workspace:GetServerTimeNow()}
 local root=Instance.new("Part");root.Name="LocalHatchReveal";root.Size=Vector3.one;root.Transparency=1;root.Anchored=true;root.CanCollide=false;root.CanQuery=false;root.CanTouch=false;root.CFrame=home*CFrame.new(0,1.8,0);root.Parent=workspace
 local puff=Instance.new("ParticleEmitter");puff.Texture="rbxasset://textures/particles/smoke_main.dds";puff.Rate=0;puff.Color=ColorSequence.new(Color3.fromRGB(240,250,231));puff.LightEmission=.5;puff.Lifetime=NumberRange.new(.35,.65);puff.Speed=NumberRange.new(1.5,3);puff.SpreadAngle=Vector2.new(180,180);puff.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.5),NumberSequenceKeypoint.new(1,1.8)});puff.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(1,1)});puff.Parent=root;puff:Emit(12)
 local highlight=Instance.new("Highlight");highlight.Adornee=model;highlight.FillColor=Color3.fromRGB(255,237,167);highlight.FillTransparency=.4;highlight.OutlineTransparency=.2;highlight.Parent=root
 Tween:Create(highlight,TweenInfo.new(.5),{FillTransparency=1,OutlineTransparency=1}):Play()
 Debris:AddItem(root,1)
end
Collection:GetInstanceAddedSignal("HatchRewardDisplay"):Connect(add)
Collection:GetInstanceRemovedSignal("HatchRewardDisplay"):Connect(function(m)active[m]=nil end)
for _,m in Collection:GetTagged("HatchRewardDisplay") do add(m)end
RunService:BindToRenderStep("HatchedCharacterIdle",Enum.RenderPriority.Camera.Value+2,function()
 local now=workspace:GetServerTimeNow()
 for model,r in active do
  if not model:IsDescendantOf(workspace) then active[model]=nil
  elseif workspace.CurrentCamera and (workspace.CurrentCamera.CFrame.Position-r.home.Position).Magnitude<130 then
   local t=math.max(0,now-r.epoch)
   model:PivotTo(r.home*CFrame.new(0,.16*(1-math.cos(t*2)),0)*CFrame.Angles(0,t*.7,0))
  end
 end
end)
