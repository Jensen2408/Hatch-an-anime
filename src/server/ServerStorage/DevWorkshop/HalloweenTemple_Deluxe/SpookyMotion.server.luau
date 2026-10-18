local RS=game:GetService("RunService")
local root=script.Parent
local flick={}
-- candle-style flicker: old pumpkin "Rib" lights plus any light inside a voxel *_Glow part (jack-o'-lanterns, candles)
local function track(l) if l:IsA("PointLight") and (l.Parent.Name=="Rib" or l.Parent.Name:find("_Glow") or l:GetAttribute("Flicker")) then table.insert(flick,{l=l,b=l.Brightness,s=math.random()*100}) end end
for _,d in root:GetDescendants() do track(d) end
root.DescendantAdded:Connect(track)
RS.Heartbeat:Connect(function()
 local t=os.clock()
 for _,f in flick do if f.l.Parent then f.l.Brightness=f.b*(0.75+0.25*math.noise(t*6,f.s)) end end
end)
