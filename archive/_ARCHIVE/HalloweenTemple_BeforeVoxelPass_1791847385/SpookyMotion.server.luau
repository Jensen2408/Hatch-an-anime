local RS=game:GetService("RunService")
local root=script.Parent
local ghosts,bats,flick={}, {}, {}
for _,g in root.Ghosts:GetChildren() do table.insert(ghosts,{m=g,base=g:GetPivot(),ph=math.random()*6}) end
local c=root.TempleGlow.Position
for _,b in root.Bats:GetChildren() do local p=b:GetPivot().Position local off=p-c table.insert(bats,{m=b,r=Vector3.new(off.X,0,off.Z).Magnitude+6,y=p.Y,a=math.atan2(off.Z,off.X),s=0.4+math.random()*0.5}) end
for _,l in root:GetDescendants() do if l:IsA("PointLight") and l.Parent.Name=="Rib" then table.insert(flick,{l=l,b=l.Brightness}) end end
RS.Heartbeat:Connect(function()
 local t=os.clock()
 for _,g in ghosts do g.m:PivotTo(g.base*CFrame.new(math.sin(t*0.5+g.ph)*4,math.sin(t*1.3+g.ph)*1.5,0)*CFrame.Angles(0,math.sin(t*0.4+g.ph)*0.6,0)) end
 for _,b in bats do local a=b.a+t*b.s local pos=Vector3.new(c.X+math.cos(a)*b.r,b.y+math.sin(t*3+b.a)*1.5,c.Z+math.sin(a)*b.r)
  b.m:PivotTo(CFrame.lookAt(pos,pos+Vector3.new(-math.sin(a),0,math.cos(a)))*CFrame.Angles(0,0,math.sin(t*18+b.a)*0.5)) end
 for _,f in flick do f.l.Brightness=f.b*(0.75+0.25*math.noise(t*6,f.b)) end
end)
