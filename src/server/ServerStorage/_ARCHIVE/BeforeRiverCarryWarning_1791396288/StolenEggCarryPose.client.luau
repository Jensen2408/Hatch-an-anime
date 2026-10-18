local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local watched={}
local function watch(character)
 local joints={}
 for _,side in {"Left","Right"} do
  local upper=character:FindFirstChild(side.."UpperArm")
  local lower=character:FindFirstChild(side.."LowerArm")
  local shoulder=upper and upper:FindFirstChild(side.."Shoulder")
  local elbow=lower and lower:FindFirstChild(side.."Elbow")
  if shoulder and (shoulder:IsA("AnimationConstraint") or shoulder:IsA("Motor6D")) then
   table.insert(joints,{joint=shoulder,pose=CFrame.Angles(math.rad(65),0,side=="Left" and -.6 or .6)})
  end
  if elbow and (elbow:IsA("AnimationConstraint") or elbow:IsA("Motor6D")) then
   table.insert(joints,{joint=elbow,pose=CFrame.Angles(math.rad(15),0,0)})
  end
 end
 watched[character]={joints=joints,carrying=false}
end
local function player(p)
 p.CharacterAdded:Connect(function(c) task.delay(1,function() if c.Parent then watch(c) end end) end)
 if p.Character then watch(p.Character) end
end
for _,p in Players:GetPlayers() do player(p) end
Players.PlayerAdded:Connect(player)
RunService.PreSimulation:Connect(function()
 for c,rec in watched do
  if not c.Parent then watched[c]=nil
  else
   local carrying=c:FindFirstChild("StolenEggCarry")~=nil
   if carrying then
    for _,v in rec.joints do if v.joint.Parent then v.joint.Transform=v.pose end end
   elseif rec.carrying then
    for _,v in rec.joints do if v.joint.Parent then v.joint.Transform=CFrame.identity end end
   end
   rec.carrying=carrying
  end
 end
end)