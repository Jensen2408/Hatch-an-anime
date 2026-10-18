local TweenService=game:GetService("TweenService")
local h=script.Parent
local m=h:WaitForChild("LiquidSystemAndTrim")
local button=m:WaitForChild("HatchButton")
local prompt=button.ProximityPrompt
local liquid=m.TankLiquid
local rest=button.CFrame
local fullSize,fullCF=liquid.Size,liquid.CFrame
local busy=false
local completed=Instance.new("BindableEvent")
completed.Name="HatchCycleCompleted"
completed.Parent=h
local function tween(p,t,props)
 local tw=TweenService:Create(p,TweenInfo.new(t,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut),props)
 tw:Play()
 return tw
end
local function cycle(player)
 if busy then return end
 if player then
  local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
  if not root or (root.Position-button.Position).Magnitude>20 then return end
 end
 busy=true prompt.Enabled=false h:SetAttribute("Hatching",true)
 tween(button,.12,{CFrame=rest+Vector3.new(0,0,.25)})
 task.wait(.18)
 tween(button,.2,{CFrame=rest})
 local height=.5
 tween(liquid,3.5,{Size=Vector3.new(height,fullSize.Y,fullSize.Z),CFrame=fullCF-Vector3.new(0,(fullSize.X-height)/2,0)})
 task.wait(3.5)
 h:SetAttribute("Hatching",false)
 completed:Fire(player)
 tween(liquid,2,{Size=fullSize,CFrame=fullCF})
 task.wait(2)
 busy=false prompt.Enabled=true
end
button.ClickDetector.MouseClick:Connect(cycle)
prompt.Triggered:Connect(cycle)
h.RequestHatch.Event:Connect(cycle)
h:SetAttribute("Hatching",false)
