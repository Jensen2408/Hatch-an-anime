-- Prepare prototype-only VFX from the existing Rainbow design. No grants or automatic events.
local RS=game:GetService('ReplicatedStorage')
local SS=game:GetService('ServerStorage')
local folder=RS:WaitForChild('GalaxyPrototype')
if folder:FindFirstChild('GalaxyAura') then return end
local auras=SS:WaitForChild('MutationAuras',15)
local rainbow=auras and auras:WaitForChild('Rainbow',10)
if not rainbow then warn('[GalaxyPrototype] Rainbow aura template unavailable');return end
local aura=rainbow:Clone();aura.Name='GalaxyAura'
local purple=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromRGB(194,141,255)),ColorSequenceKeypoint.new(.5,Color3.fromRGB(110,65,245)),ColorSequenceKeypoint.new(1,Color3.fromRGB(225,197,255))})
for _,v in aura:GetDescendants() do
 if v:IsA('ParticleEmitter') then v.Color=purple;v.Rate=math.min(v.Rate*.15,24);v.Lifetime=NumberRange.new(math.min(v.Lifetime.Min,1.5),math.min(v.Lifetime.Max,2.5));v.Brightness=math.min(v.Brightness,4)
 elseif v:IsA('Beam') or v:IsA('Trail') then v.Color=purple
 elseif v:IsA('PointLight') then v.Color=Color3.fromRGB(157,95,255);v.Brightness=math.min(v.Brightness,1)
 elseif v:IsA('BaseScript') or v:IsA('WeldConstraint') or v:IsA('Weld') then v:Destroy() end
end
if aura:IsA('BasePart') then aura.Anchored=true;aura.Transparency=1;aura.CanCollide=false;aura.CanTouch=false;aura.CanQuery=false end
aura.Parent=folder
