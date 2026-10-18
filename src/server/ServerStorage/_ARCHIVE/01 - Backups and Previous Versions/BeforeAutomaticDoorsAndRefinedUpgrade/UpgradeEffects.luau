local TweenService=game:GetService("TweenService")
local Collection=game:GetService("CollectionService")
local FX={}
FX.Palettes={Temple={glow=Color3.fromRGB(255,196,84)},Chamber={glow=Color3.fromRGB(214,238,160)}}
local function signature(p)
 local values={p.ClassName,tostring(p.Color),p.Material.Name}
 for _,v in {p.Size.X,p.Size.Y,p.Size.Z,p.CFrame:GetComponents()} do table.insert(values,string.format("%.2f",v)) end
 if p:IsA("MeshPart") then table.insert(values,p.MeshId);table.insert(values,p.TextureID) end
 return table.concat(values,"|")
end
function FX.Play(opts)
 if opts.isValid and not opts.isValid() then return end
 local oldParts={}
 if false and opts.oldModel then
  for _,p in opts.oldModel:GetDescendants() do if p:IsA("BasePart") then
   local k=signature(p);oldParts[k]=oldParts[k] or {};table.insert(oldParts[k],p)
  end end
 end
 local records,controls={},{}
 local duration=3.4
 local function prepare(model)
  model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
  model:SetAttribute("UnderConstruction",true)
  model:SetAttribute("BuildDuration",duration)
  model:SetAttribute("BuildGround",opts.anchor.Position.Y)
  model:SetAttribute("BuildOwner",opts.ownerUserId or 0)
  model:SetAttribute("BuildRadius",opts.radius)
  model:SetAttribute("BuildKind",opts.palette==FX.Palettes.Temple and "Temple" or "Chamber")
  local retained=0
  for _,p in model:GetDescendants() do
   if p:IsA("BasePart") then
    local bucket=oldParts[signature(p)]
    local original=bucket and table.remove(bucket)
    if original then
     original.Parent=p.Parent;p:Destroy();retained+=1
    else
     p.Anchored=true
     table.insert(records,{part=p,cf=p.CFrame,collide=p.CanCollide,volume=p.Size.X*p.Size.Y*p.Size.Z})
    end
   end
  end
  table.sort(records,function(a,b)
   -- Structural masses before trim; height breaks ties.
   local av,bv=a.volume>=15,b.volume>=15
   if av~=bv then return av end
   if math.abs(a.cf.Y-b.cf.Y)>.05 then return a.cf.Y<b.cf.Y end
   return a.volume>b.volume
  end)
  local box,size=model:GetBoundingBox()
  model:SetAttribute("BuildFootprint",Vector3.new(size.X,0,size.Z))
  model:SetAttribute("BuildCenter",Vector3.new(box.X,opts.anchor.Position.Y,box.Z))
  local riseDistance=math.max(3,box.Y+size.Y*.5-opts.anchor.Position.Y+.5)
  for i,r in records do
   local layer=math.floor(math.clamp((r.cf.Y-(box.Y-size.Y*.5))/math.max(size.Y,1),0,1)*12)
   r.delay=layer/12*1.8+(i%5)*.016
   r.travel=r.volume>=15 and 1.02 or .72
   if r.volume<15 then r.delay+=.2 end
   r.seat=r.volume>=15 and .2 or .1
   r.part:SetAttribute("ConstructionDelay",r.delay)
   r.part:SetAttribute("ConstructionFinal",r.cf)
   local p=r.part
   local extent=(math.abs(p.CFrame.RightVector.Y)*p.Size.X+math.abs(p.CFrame.UpVector.Y)*p.Size.Y+math.abs(p.CFrame.LookVector.Y)*p.Size.Z)*.5
   local depth=math.max(2,r.cf.Y+extent-opts.anchor.Position.Y+.5)
   local side=(i%2==0 and 1 or -1)
   p.CFrame=(r.cf-Vector3.new(side*.22,depth,0))*CFrame.Angles(0,math.rad(side*1.5),0)
   p.CanCollide=false
  end
  for _,v in model:GetDescendants() do
   if v:IsA("ProximityPrompt") or v:IsA("Light") or v:IsA("BillboardGui") or v:IsA("SurfaceGui") then controls[v]=v.Enabled;v.Enabled=false
   elseif v:IsA("ClickDetector") then controls[v]=v.MaxActivationDistance;v.MaxActivationDistance=0 end
  end
  model:SetAttribute("BuildNewParts",#records)
  model:SetAttribute("BuildRetainedParts",retained)
 end
 local model=opts.swap(prepare)
 if not model then return end
 local start=workspace:GetServerTimeNow()+.2
 model:SetAttribute("BuildStart",start)
 Collection:AddTag(model,"UpgradeAssembly")
 local tweens={}
 for _,r in records do
  task.delay(.2+r.delay,function()
   if not model.Parent or not r.part.Parent then return end
   local tween=TweenService:Create(r.part,TweenInfo.new(r.travel,Enum.EasingStyle.Quart,Enum.EasingDirection.Out),{CFrame=r.cf+Vector3.new(0,r.seat,0)})
   table.insert(tweens,tween);tween:Play()
   task.delay(r.travel,function()
    if not model.Parent or not r.part.Parent then return end
    local seat=TweenService:Create(r.part,TweenInfo.new(.16,Enum.EasingStyle.Quad,Enum.EasingDirection.In),{CFrame=r.cf})
    table.insert(tweens,seat);seat:Play()
   end)
  end)
 end
 task.wait(duration+.2)
 for _,t in tweens do t:Cancel() end
 if model.Parent then
  for _,r in records do if r.part.Parent then r.part.CFrame=r.cf;r.part.CanCollide=r.collide end end
  for v,state in controls do if v.Parent then
   if v:IsA("ClickDetector") then v.MaxActivationDistance=state else v.Enabled=state end
  end end
  model:SetAttribute("UnderConstruction",false)
  Collection:RemoveTag(model,"UpgradeAssembly")
 end
 return model
end
return FX
