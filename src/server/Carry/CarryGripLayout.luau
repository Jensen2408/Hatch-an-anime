local Layout={}
function Layout.Frame(character,torso,half)
 -- Place the item just below shoulder height, where straight arms can support it.
 local sum,count=0,0
 for _,side in {"Left","Right"} do
  local shoulder=character:FindFirstChild(side.."Shoulder",true)
  local wrist=character:FindFirstChild(side.."Wrist",true)
  local anchor=torso:FindFirstChild(side.."ShoulderRigAttachment")
  if shoulder and shoulder.Part0 and wrist then
   local start=torso.CFrame:PointToObjectSpace((shoulder.Part0.CFrame*shoulder.C0).Position)
   sum+=start.Y-.35+.1-wrist.C1.Position.Y;count+=1
  elseif anchor then sum+=anchor.Position.Y-.5;count+=1 end
 end
 local y=count>0 and sum/count or .5

 local forward=math.huge
 for _,side in {"Left","Right"} do
  local shoulder=character:FindFirstChild(side.."Shoulder",true)
  local elbow=character:FindFirstChild(side.."Elbow",true)
  local wrist=character:FindFirstChild(side.."Wrist",true)
  if shoulder and elbow and wrist and shoulder.Part0 then
   local l1=(shoulder.C1.Position-elbow.C0.Position).Magnitude
   local l2=(elbow.C1.Position-wrist.C0.Position).Magnitude
   local start=torso.CFrame:PointToObjectSpace((shoulder.Part0.CFrame*shoulder.C0).Position)
   local x=(side=="Left" and -half-.03 or half+.03)+wrist.C1.Position.X
   local wy=y-.1+wrist.C1.Position.Y
   local reach=(l1+l2)
   local z=math.sqrt(math.max(.25,reach*reach-(x-start.X)^2-(wy-start.Y)^2))
   forward=math.min(forward,z-start.Z+.12+wrist.C1.Position.Z)
  end
 end
 if forward==math.huge then
  for _,side in {"Left","Right"} do
   local upper=character:FindFirstChild(side.."UpperArm")
   local lower=character:FindFirstChild(side.."LowerArm")
   local hand=character:FindFirstChild(side.."Hand")
   local sa=upper and upper:FindFirstChild(side.."ShoulderRigAttachment")
   local ea=upper and upper:FindFirstChild(side.."ElbowRigAttachment")
   local eb=lower and lower:FindFirstChild(side.."ElbowRigAttachment")
   local wa=lower and lower:FindFirstChild(side.."WristRigAttachment")
   local wb=hand and hand:FindFirstChild(side.."WristRigAttachment")
   local anchor=torso:FindFirstChild(side.."ShoulderRigAttachment")
   if sa and ea and eb and wa and wb and anchor then
    local reach=((sa.Position-ea.Position).Magnitude+(eb.Position-wa.Position).Magnitude)
    local start=anchor.Position
    local x=(side=="Left" and -half-.03 or half+.03)+wb.Position.X
    local wy=y-.1+wb.Position.Y
    forward=math.min(forward,math.sqrt(math.max(.25,reach*reach-(x-start.X)^2-(wy-start.Y)^2))-start.Z+.12+wb.Position.Z)
   end
  end
 end
 if forward==math.huge then
  local arm=character:FindFirstChild("Left Arm")
  forward=arm and math.max(1.1,arm.Size.Y*.82) or 1.65
 end
 return torso.CFrame*CFrame.new(0,y,-math.clamp(forward,.8,6))
end
return Layout
