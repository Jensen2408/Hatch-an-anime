-- Prepare prototype-only VFX from the existing Rainbow design in brighter cosmic purple/magenta/cyan starlight colors.
local RS = game:GetService("ReplicatedStorage")
local SS = game:GetService("ServerStorage")
local folder = RS:WaitForChild("GalaxyPrototype")
local existing = folder:FindFirstChild("GalaxyAura")
if existing then existing:Destroy() end
local auras = SS:WaitForChild("MutationAuras", 15)
local rainbow = auras and auras:WaitForChild("Rainbow", 10)
if not rainbow then
	warn("[GalaxyPrototype] Rainbow aura template unavailable")
	return
end
local aura = rainbow:Clone()
aura.Name = "GalaxyAura"
local cosmic = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(240, 155, 255)),
	ColorSequenceKeypoint.new(0.45, Color3.fromRGB(135, 95, 255)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(115, 230, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 235, 255)),
})
for _, v in aura:GetDescendants() do
	if v:IsA("ParticleEmitter") then
		v.Color = cosmic
		v.Rate = math.min(v.Rate * 0.18, 28)
		v.Lifetime = NumberRange.new(math.min(v.Lifetime.Min, 1.5), math.min(v.Lifetime.Max, 2.5))
		v.Brightness = math.min(math.max(v.Brightness, 2.5), 4.5)
	elseif v:IsA("Beam") or v:IsA("Trail") then
		v.Color = cosmic
	elseif v:IsA("PointLight") then
		v.Color = Color3.fromRGB(185, 115, 255)
		v.Brightness = math.min(math.max(v.Brightness, 1.35), 1.8)
	elseif v:IsA("BaseScript") or v:IsA("WeldConstraint") or v:IsA("Weld") then
		v:Destroy()
	end
end
if aura:IsA("BasePart") then
	aura.Anchored = true
	aura.Transparency = 1
	aura.CanCollide = false
	aura.CanTouch = false
	aura.CanQuery = false
end
aura.Parent = folder
