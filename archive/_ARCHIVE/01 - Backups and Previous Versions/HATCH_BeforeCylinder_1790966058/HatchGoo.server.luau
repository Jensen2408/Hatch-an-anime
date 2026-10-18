-- HatchGoo: lives inside workspace.HATCH.
-- When an egg is inside the glass chamber, the goo drains out of the
-- "Goo Container" on top, pours down into the chamber and glows round the
-- egg. When the egg leaves, the stream stops and the container refills.
-- An "egg" is any part whose name, or whose model's name, contains "Egg".
-- You can also start it from another script: HATCH:SetAttribute("Hatching", true)

local TweenService = game:GetService("TweenService")

local hatch = script.Parent
local container = workspace:WaitForChild("Goo Container"):WaitForChild("Container")
local goo = container:WaitForChild("Goo")

local GOO_COLOR = goo.Color
local DRAIN_TIME = 4
local REFILL_TIME = 3
local MIN_LEVEL = 0.15

local CHAMBER_MIN = Vector3.new(20.75, 32.4, 90.5)
local CHAMBER_MAX = Vector3.new(24.75, 39.3, 93.75)
local chamberCenter = (CHAMBER_MIN + CHAMBER_MAX) / 2
local chamberSize = CHAMBER_MAX - CHAMBER_MIN

local fullCF, fullH = goo.CFrame, goo.Size.X
local gooBottomY = goo.Position.Y - fullH / 2
local level = Instance.new("NumberValue")
level.Value = 1

local function applyLevel(f)
	local h = math.max(fullH * f, 0.05)
	goo.Size = Vector3.new(h, goo.Size.Y, goo.Size.Z)
	goo.CFrame = fullCF + Vector3.new(0, -(fullH - h) / 2, 0)
end
level.Changed:Connect(applyLevel)

local function part(name, size, cf, transparency, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored, p.CanCollide, p.CanQuery, p.CastShadow = true, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = GOO_COLOR
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Transparency = 1
	p:SetAttribute("OnT", transparency)
	p.Parent = hatch
	return p
end

local topY, botY = gooBottomY, CHAMBER_MIN.Y
local stream = part("GooStream", Vector3.new(topY - botY, 0.35, 0.35),
	CFrame.new(goo.Position.X, (topY + botY) / 2, goo.Position.Z) * CFrame.Angles(0, 0, math.rad(90)),
	0.25, Enum.PartType.Cylinder)
local drips = Instance.new("ParticleEmitter")
drips.Color = ColorSequence.new(GOO_COLOR)
drips.LightEmission = 0.6
drips.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18), NumberSequenceKeypoint.new(1, 0.05) })
drips.Lifetime = NumberRange.new(0.6, 0.9)
drips.Speed = NumberRange.new(2, 4)
drips.Acceleration = Vector3.new(0, -20, 0)
drips.EmissionDirection = Enum.NormalId.Bottom
drips.Rate = 0
drips.Parent = stream

local pool = part("GooPool", Vector3.new(chamberSize.X - 0.2, 0.4, chamberSize.Z - 0.2),
	CFrame.new(chamberCenter.X, CHAMBER_MIN.Y + 0.2, chamberCenter.Z), 0.35)
local mist = part("GooMist", chamberSize - Vector3.new(0.3, 0.3, 0.3), CFrame.new(chamberCenter), 0.85)
local bubbles = Instance.new("ParticleEmitter")
bubbles.Color = ColorSequence.new(GOO_COLOR)
bubbles.LightEmission = 1
bubbles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) })
bubbles.Transparency = NumberSequence.new(0.1, 1)
bubbles.Lifetime = NumberRange.new(1.5, 2.5)
bubbles.Speed = NumberRange.new(1, 2)
bubbles.EmissionDirection = Enum.NormalId.Top
bubbles.Rate = 0
bubbles.Parent = pool
local light = Instance.new("PointLight")
light.Color = GOO_COLOR
light.Range = 14
light.Brightness = 0
light.Parent = mist

local function fade(p, on, t)
	TweenService:Create(p, TweenInfo.new(t), { Transparency = on and p:GetAttribute("OnT") or 1 }):Play()
end

local active = false
local function setActive(on)
	if on == active then return end
	active = on
	if on then
		fade(stream, true, 0.3); fade(pool, true, 1.5); fade(mist, true, 2)
		drips.Rate, bubbles.Rate = 25, 12
		TweenService:Create(light, TweenInfo.new(1.5), { Brightness = 2.5 }):Play()
		TweenService:Create(level, TweenInfo.new(DRAIN_TIME, Enum.EasingStyle.Sine), { Value = MIN_LEVEL }):Play()
		task.delay(DRAIN_TIME, function()
			if active then
				fade(stream, false, 0.4); drips.Rate = 0
			end
		end)
	else
		fade(stream, false, 0.4); fade(pool, false, 1.5); fade(mist, false, 1.5)
		drips.Rate, bubbles.Rate = 0, 0
		TweenService:Create(light, TweenInfo.new(1.5), { Brightness = 0 }):Play()
		TweenService:Create(level, TweenInfo.new(REFILL_TIME, Enum.EasingStyle.Sine), { Value = 1 }):Play()
	end
end

local params = OverlapParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { hatch, workspace:FindFirstChild("Goo Container") }

local function isEgg(p)
	local m = p:FindFirstAncestorOfClass("Model")
	return p.Name:lower():find("egg") ~= nil or (m ~= nil and m.Name:lower():find("egg") ~= nil)
end

local function eggInside()
	for _, p in workspace:GetPartBoundsInBox(CFrame.new(chamberCenter), chamberSize, params) do
		if isEgg(p) then return true end
	end
	return false
end

while true do
	setActive(hatch:GetAttribute("Hatching") == true or eggInside())
	task.wait(0.3)
end
