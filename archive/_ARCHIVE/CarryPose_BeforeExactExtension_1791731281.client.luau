local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local watched={}
local function joint(part,name) return part and part:FindFirstChild(name,true) end
local function watch(c)
 local arms={}
 for _,side in {"Left","Right"} do
  local upper=c:FindFirstChild(side.."UpperArm")
  local lower=c:FindFirstChild(side.."LowerArm")
  local hand=c:FindFirstChild(side.."Hand")
  local shoulder=joint(c,side.."Shoulder")
  local elbow=joint(c,side.."Elbow")
  local wrist=joint(c,side.."Wrist")
  if shoulder and elbow and wrist then
   table.insert(arms,{side=side,shoulder=shoulder,elbow=elbow,wrist=wrist,
    l1=(shoulder.C1.Position-elbow.C0.Position).Magnitude,
    l2=(elbow.C1.Position-wrist.C0.Position).Magnitude})
  end
 end
 local previous=watched[c]
 watched[c]={arms=arms,active=previous and previous.active or false,lastScan=os.clock()}
end
local function setup(p)
 p.CharacterAdded:Connect(function(c) task.delay(.5,function() if c.Parent then watch(c) end end) end)
 if p.Character then watch(p.Character) end
 p.CharacterRemoving:Connect(function(c) watched[c]=nil end)
end
for _,p in Players:GetPlayers() do setup(p) end
Players.PlayerAdded:Connect(setup)
local function downFrame(origin,destination)
 return CFrame.lookAt(origin,destination)*CFrame.Angles(math.pi/2,0,0)
end
local scanElapsed=0
RunService.PreSimulation:Connect(function(dt)
 scanElapsed+=dt
 if scanElapsed>=.5 then
  scanElapsed=0
  for _,p in Players:GetPlayers() do
   local c=p.Character
   if c and c.Parent and not watched[c] then watch(c) end
  end
 end
 for c,rec in watched do
 if not c.Parent then watched[c]=nil
 else
 if #rec.arms<2 and os.clock()-rec.lastScan>.5 then watch(c);rec=watched[c] end
 local carry=c:FindFirstChild("RiverEggCarry") or c:FindFirstChild("HeldItemCarry") or c:FindFirstChild("StolenEggCarry")
 local carrier=carry and carry:FindFirstChild("Carrier")
 if carrier then
 local half=carry:GetAttribute("GripHalfWidth") or .75
 for _,a in rec.arms do
 local shoulder,elbow=a.shoulder,a.elbow
 if shoulder.Parent and elbow.Parent and shoulder.Part0 and a.wrist.Parent then
 local world=shoulder.Part0.CFrame*shoulder.C0
 local s=world.Position
 local target=carrier.CFrame:PointToWorldSpace(Vector3.new(a.side=="Left" and -half-.03 or half+.03,-.1,.12))
 -- Left/right refer to the avatar's own axes: left is negative X.
 local handFrame=CFrame.new(target)*carrier.CFrame.Rotation
 local wristFrame=handFrame*a.wrist.C1
 local delta=wristFrame.Position-s
 -- Full extension: upper arm and forearm share one direction.
 local d=a.l1+a.l2
 local dir=delta.Magnitude>.001 and delta.Unit or carrier.CFrame.LookVector
 local e=s+dir*a.l1
 -- Preserve wrist orientation without translating/stretching the hand to an unreachable point.
 wristFrame=CFrame.new(s+dir*d)*wristFrame.Rotation
 local upperAttachment=downFrame(s,e)
 shoulder.Transform=world:ToObjectSpace(upperAttachment)
 local upperWorld=upperAttachment*shoulder.C1:Inverse()
 local elbowBase=upperWorld*elbow.C0
 elbow.Transform=elbowBase:ToObjectSpace(downFrame(e,s+dir*d))
 local lowerWorld=downFrame(e,s+dir*d)*elbow.C1:Inverse()
 a.wrist.Transform=(lowerWorld*a.wrist.C0):ToObjectSpace(wristFrame)
 end end
 if #rec.arms==0 then
  local torso=c:FindFirstChild("Torso")
  if torso then for _,side in {"Left","Right"} do
   local j=torso:FindFirstChild(side.." Shoulder")
   if j and j:IsA("Motor6D") and j.Part0 and j.Part1 then
    local target=carrier.CFrame:PointToWorldSpace(Vector3.new(side=="Left" and -half or half,-.1,.12))
    local world=j.Part0.CFrame*j.C0
    local desired=downFrame(world.Position,target)
    j.Transform=world:ToObjectSpace(desired)
   end
  end end
 end
 elseif rec.active then
 if #rec.arms==0 then
  local torso=c:FindFirstChild("Torso")
  if torso then for _,side in {"Left","Right"} do local joint=torso:FindFirstChild(side.." Shoulder")
   if joint and joint:IsA("Motor6D") then joint.Transform=CFrame.identity end
  end end
 end
 for _,a in rec.arms do for _,j in {a.shoulder,a.elbow,a.wrist} do if j.Parent then j.Transform=CFrame.identity end end end
 end
 rec.active=carrier~=nil
 end end
end)