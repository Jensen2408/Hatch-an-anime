local Collection=game:GetService("CollectionService")
local FX={}
FX.Palettes={Temple={core=Color3.fromRGB(255,243,206),glow=Color3.fromRGB(255,196,84)},Chamber={core=Color3.fromRGB(246,255,220),glow=Color3.fromRGB(214,238,160)}}
function FX.Play(opts)
 if opts.isValid and not opts.isValid() then return nil end
 local model=opts.swap()
 if not model then return nil end
 local duration=opts.palette==FX.Palettes.Chamber and 2.1 or 3.2
 model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 model:SetAttribute("BuildStart",workspace:GetServerTimeNow()+.18)
 model:SetAttribute("BuildDuration",duration)
 model:SetAttribute("BuildTint",opts.palette.glow)
 model:SetAttribute("UnderConstruction",true)
 local controls={}
 for _,v in model:GetDescendants() do
  if v:IsA("ProximityPrompt") then controls[v]=v.Enabled v.Enabled=false
  elseif v:IsA("ClickDetector") then controls[v]=v.MaxActivationDistance v.MaxActivationDistance=0 end
 end
 Collection:AddTag(model,"UpgradeAssembly")
 task.wait(duration+.3)
 if model.Parent then
  for v,state in controls do if v.Parent then if v:IsA("ProximityPrompt") then v.Enabled=state else v.MaxActivationDistance=state end end end
  model:SetAttribute("UnderConstruction",false)
  task.delay(1,function() if model.Parent then Collection:RemoveTag(model,"UpgradeAssembly") end end)
 end
 return model
end
return FX
