local Collection=game:GetService("CollectionService")
local FX={}
FX.Palettes={Temple={core=Color3.fromRGB(255,243,206),glow=Color3.fromRGB(255,196,84)},Chamber={core=Color3.fromRGB(246,255,220),glow=Color3.fromRGB(214,238,160)}}
function FX.Play(opts)
 if opts.isValid and not opts.isValid() then return nil end
 local isTemple=opts.palette==FX.Palettes.Temple
 if isTemple and opts.oldModel and opts.oldModel.Parent then
  local glow=Instance.new("Highlight") glow.Name="BuildCharge" glow.Adornee=opts.oldModel glow.FillColor=opts.palette.glow glow.OutlineColor=Color3.new(1,1,1) glow.FillTransparency=1 glow.OutlineTransparency=1 glow.DepthMode=Enum.HighlightDepthMode.Occluded glow.Parent=opts.oldModel
  game.TweenService:Create(glow,TweenInfo.new(.55),{FillTransparency=.12,OutlineTransparency=0}):Play()
  task.wait(.55)
  if opts.isValid and not opts.isValid() then glow:Destroy() return nil end
  local remote=game.ReplicatedStorage:FindFirstChild("UpgradeShake")
  if remote then remote:FireAllClients({position=opts.anchor.Position,templeFlash=true}) end
 end
 local model=opts.swap()
 if not model then return nil end
 local duration=opts.palette==FX.Palettes.Chamber and 2.1 or 4.8
 model.ModelStreamingMode=Enum.ModelStreamingMode.Atomic
 model:SetAttribute("BuildStart",workspace:GetServerTimeNow()+.5)
 model:SetAttribute("BuildDuration",duration)
 model:SetAttribute("BuildKind",isTemple and "Temple" or "Chamber")
 model:SetAttribute("BuildTint",opts.palette.glow)
 model:SetAttribute("UnderConstruction",true)
 local controls={}
 for _,v in model:GetDescendants() do
  if v:IsA("ProximityPrompt") then controls[v]=v.Enabled v.Enabled=false
  elseif v:IsA("ClickDetector") then controls[v]=v.MaxActivationDistance v.MaxActivationDistance=0 end
 end
 Collection:AddTag(model,"UpgradeAssembly")
 task.wait(duration+.65)
 if model.Parent then
  for v,state in controls do if v.Parent then if v:IsA("ProximityPrompt") then v.Enabled=state else v.MaxActivationDistance=state end end end
  model:SetAttribute("UnderConstruction",false)
  task.delay(1,function() if model.Parent then Collection:RemoveTag(model,"UpgradeAssembly") end end)
 end
 return model
end
return FX
