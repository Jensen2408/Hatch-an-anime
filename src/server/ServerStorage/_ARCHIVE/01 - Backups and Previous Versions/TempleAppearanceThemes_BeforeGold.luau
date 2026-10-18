local T={
{Id="Original",Name="Classic",Tint=Color3.fromRGB(255,255,255)},
{Id="Jade",Name="Jade Garden",Tint=Color3.fromRGB(174,235,193)},
{Id="Sakura",Name="Sakura",Tint=Color3.fromRGB(255,188,211)},
{Id="Midnight",Name="Midnight",Tint=Color3.fromRGB(164,189,246)},
{Id="Amber",Name="Amber",Tint=Color3.fromRGB(255,221,160)}}
function T.Apply(model,id)
 local theme=T[1] for _,t in ipairs(T) do if t.Id==id then theme=t end end
 model:SetAttribute("TempleAppearance",theme.Id)
 if theme.Id=="Original" then return end
 for _,p in ipairs(model:GetDescendants()) do
 if p:IsA("BasePart") and p.Material~=Enum.Material.Neon and p.Material~=Enum.Material.Glass then
 local sa=p:FindFirstChildWhichIsA("SurfaceAppearance")
 if sa then sa.Color=theme.Tint else local c=p.Color local t=theme.Tint p.Color=Color3.new(c.R*t.R,c.G*t.G,c.B*t.B) end
 end end
end
return T
