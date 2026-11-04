-- ReplicatedStorage.V2Moves.V2MoveFX: one function per signature move effect.
-- Called as FX[kind](model, color, spot, size): spot is a CFrame at the hand/head the effect starts from, +Z is the character's front.
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local FX = {}

local WHITE = Color3.new(1, 1, 1)
local OUT = Enum.EasingDirection.Out
local QUAD = Enum.EasingStyle.Quad

local function bone(model, name)
	for _, d in model:GetDescendants() do
		if d:IsA("Bone") and d.Name == name then
			return d
		end
	end
end

local function neon(size, cf, color)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Size = size
	p.CFrame = cf
	p.Parent = workspace
	return p
end

local function tween(p, time, goal, style, dir)
	TweenService:Create(p, TweenInfo.new(time, style or QUAD, dir or OUT), goal):Play()
	Debris:AddItem(p, time + 0.1)
end

local function ring(pos, color, width, life)
	local p = neon(Vector3.new(0.15, 2, 2), CFrame.new(pos) * CFrame.Angles(0, 0, math.pi / 2), color)
	p.Shape = Enum.PartType.Cylinder
	p.Transparency = 0.15
	tween(p, life or 0.5, { Size = Vector3.new(0.15, width, width), Transparency = 1 })
end

local function ball(cf, from, to, color, life)
	local p = neon(Vector3.one * from, cf, color)
	p.Shape = Enum.PartType.Ball
	p.Transparency = 0.1
	tween(p, life, { Size = Vector3.one * to, Transparency = 1 })
	return p
end

-- voxel chunks flying out of a point, the game's look
local function chunks(cf, color, count, reach, life, size)
	for _ = 1, count do
		local dir = Vector3.new(math.random() - 0.5, math.random() - 0.3, math.random() - 0.5).Unit
		local s = (size or 0.5) * (0.6 + math.random() * 0.8)
		local p = neon(Vector3.one * s, cf * CFrame.Angles(math.random() * 6, math.random() * 6, 0), color)
		tween(p, life, { CFrame = CFrame.new(cf.Position + dir * reach * (0.5 + math.random() * 0.6)) * CFrame.Angles(math.random() * 6, 0, math.random() * 6), Size = Vector3.one * 0.05 })
	end
end

-- a straight beam along the spot's +Z with a white core
local function beam(cf, length, width, color, life)
	local dir = cf * CFrame.new(0, 0, length / 2) * CFrame.Angles(0, math.pi / 2, 0)
	local outer = neon(Vector3.new(0.5, width, width), cf * CFrame.Angles(0, math.pi / 2, 0), color)
	outer.Shape = Enum.PartType.Cylinder
	outer.Transparency = 0.25
	local core = neon(Vector3.new(0.5, width * 0.55, width * 0.55), outer.CFrame, WHITE)
	core.Shape = Enum.PartType.Cylinder
	for _, p in { outer, core } do
		TweenService:Create(p, TweenInfo.new(0.12, QUAD, OUT), { Size = Vector3.new(length, p.Size.Y, p.Size.Z), CFrame = dir }):Play()
	end
	task.wait(life)
	for _, p in { outer, core } do
		tween(p, 0.25, { Size = Vector3.new(length, 0.05, 0.05), Transparency = 1 })
	end
end

local function slash(cf, color, delay, length)
	task.wait(delay)
	local p = neon(Vector3.new(0.5, 0.25, 0.06), cf, color)
	p.Transparency = 0.05
	TweenService:Create(p, TweenInfo.new(0.09, QUAD, OUT), { Size = Vector3.new(length or 11, 0.35, 0.06) }):Play()
	task.wait(0.09)
	tween(p, 0.4, { Size = Vector3.new(length or 11, 0.02, 0.02), Transparency = 1 })
end

local function bolt(from, to, color, thick)
	local steps = 6
	local last = from
	for i = 1, steps do
		local nextPoint = from:Lerp(to, i / steps)
		if i < steps then
			nextPoint += Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 1.6
		end
		local gap = (nextPoint - last).Magnitude
		local p = neon(Vector3.new(thick or 0.22, thick or 0.22, gap), CFrame.lookAt(last:Lerp(nextPoint, 0.5), nextPoint), color)
		tween(p, 0.28, { Transparency = 1 })
		last = nextPoint
	end
end

local function ground(spot, model)
	return Vector3.new(spot.Position.X, bone(model, "Root").WorldCFrame.Y + 0.15, spot.Position.Z)
end

-- Zoro: three green cuts across the path of the dash
function FX.OniGiri(model)
	local root = bone(model, "Root")
	if not root then
		return
	end
	local home = root.WorldCFrame
	local scale = model:GetScale() / 6
	local mid = home * CFrame.new(0, 3 * scale, 1.6 * scale)
	local green = Color3.fromRGB(77, 255, 122)
	task.spawn(slash, mid * CFrame.Angles(0, math.pi / 2, math.rad(32)), green, 0)
	task.spawn(slash, mid * CFrame.Angles(0, math.pi / 2, math.rad(-32)), green, 0.05)
	task.spawn(slash, mid * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(8)), WHITE, 0.1)
	ring((home * CFrame.new(0, 0.25, 3 * scale)).Position, green, 16)
end

function FX.Blast(_, color, spot, size)
	local at = spot * CFrame.new(0, 0, 1.5 * size)
	ball(at, 1, 9 * size, color, 0.45)
	ball(at, 0.5, 5 * size, WHITE, 0.25)
	chunks(at, color, 14, 8 * size, 0.6)
	task.spawn(beam, at, 7 * size, 2.2 * size, color, 0.08)
end

function FX.Orb(_, color, spot, size)
	local p = neon(Vector3.one * 0.3, spot, color)
	p.Shape = Enum.PartType.Ball
	p.Transparency = 0.15
	TweenService:Create(p, TweenInfo.new(0.7, Enum.EasingStyle.Sine, OUT), { Size = Vector3.one * 1.8 * size }):Play()
	for i = 1, 5 do
		task.delay(i * 0.1, ring, spot.Position, color, 3 * size, 0.3)
	end
	task.delay(0.72, function()
		tween(p, 0.12, { Size = Vector3.one * 0.1, Transparency = 1 })
	end)
end

function FX.Beam(_, color, spot, size)
	local at = spot * CFrame.new(0, 0, 0.6 * size)
	ring(at.Position, color, 7 * size)
	task.spawn(beam, at, 34 * size, 2.6 * size, color, 0.75)
end

function FX.FireBeam(_, color, spot, size)
	local at = spot * CFrame.new(0, 0, 0.6 * size)
	task.spawn(beam, at, 26 * size, 3.4 * size, color, 0.7)
	for i = 1, 8 do
		task.delay(i * 0.08, chunks, at * CFrame.new(0, 0, 3 * i * size), Color3.fromRGB(255, 214, 77), 3, 3 * size, 0.4)
	end
end

function FX.Eye(_, color, spot, size)
	local at = spot * CFrame.new(0, 0.5 * size, 1 * size)
	for i = 0, 2 do
		task.delay(i * 0.12, ring, (at * CFrame.new(0, 0, i * 2 * size)).Position, color, 4 * size, 0.5)
	end
	local mark = neon(Vector3.new(0.5, 0.5, 0.05) * size, at, color)
	tween(mark, 0.5, { Size = Vector3.new(3, 3, 0.05) * size, Transparency = 1 })
end

function FX.Bolt(_, color, spot, size)
	local from = spot * CFrame.new(0, 2.5 * size, -4 * size)
	bolt(from.Position, (spot * CFrame.new(0, 2.5 * size, 3 * size)).Position, color, 0.5 * size)
	bolt((from * CFrame.new(1, 1, 0)).Position, (spot * CFrame.new(-1, 3, 2)).Position, WHITE, 0.2 * size)
	ring(from.Position, color, 9 * size)
end

function FX.Burst(_, color, spot, size)
	ring(spot.Position, color, 10 * size)
	ball(spot, 1, 5 * size, WHITE, 0.25)
	chunks(spot, color, 12, 6 * size, 0.5)
end

function FX.Wave(_, color, spot, size)
	for i = 0, 4 do
		local cf = spot * CFrame.new(0, 0, (0.8 + i * 0.7) * size) * CFrame.Angles(0, math.rad(90 - i * 40), 0)
		task.spawn(slash, cf, i % 2 == 0 and color or WHITE, i * 0.05, 8 * size)
	end
	chunks(spot, color, 8, 6 * size, 0.6)
end

function FX.Crescent(_, color, spot, size)
	local at = spot * CFrame.new(0, 1 * size, 1 * size)
	local p = neon(Vector3.new(0.5, 6, 2) * size, at, color)
	p.Transparency = 0.1
	tween(p, 0.8, { CFrame = at * CFrame.new(0, 0, 24 * size), Size = Vector3.new(0.5, 13, 3) * size, Transparency = 1 }, Enum.EasingStyle.Sine)
	local edge = neon(Vector3.new(0.2, 6.5, 0.6) * size, at * CFrame.new(0, 0, 1), WHITE)
	tween(edge, 0.8, { CFrame = at * CFrame.new(0, 0, 25 * size), Size = Vector3.new(0.2, 14, 0.6) * size, Transparency = 1 }, Enum.EasingStyle.Sine)
end

function FX.Petals(_, color, spot, size)
	for i = 1, 40 do
		task.delay(i * 0.018, function()
			local a = i * 0.7
			local start = spot * CFrame.new(math.cos(a) * size, 0, math.sin(a) * size)
			local p = neon(Vector3.new(0.35, 0.05, 0.25) * size, start, color)
			tween(p, 1.1, { CFrame = spot * CFrame.new(math.cos(a) * 7 * size, 1 + math.random() * 3, 9 * size * math.random()) * CFrame.Angles(a, a * 2, 0), Transparency = 1 }, Enum.EasingStyle.Sine)
		end)
	end
end

function FX.Lightning(_, color, spot, size)
	for i = 0, 3 do
		task.delay(i * 0.08, function()
			local a = i * 1.7 + math.random()
			local base = spot.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * 2.5 * size
			bolt(base + Vector3.new(0, 12, 0) * size, base - Vector3.new(0, 5, 0) * size, i % 2 == 0 and color or WHITE, 0.35 * size)
		end)
	end
	ring(spot.Position, color, 10 * size)
end

function FX.Spin(_, color, spot, size)
	for i = 0, 3 do
		task.delay(i * 0.09, function()
			local p = neon(Vector3.new(0.15, 7, 7) * size, spot * CFrame.Angles(0, 0, math.pi / 2 + i * 0.25), i % 2 == 0 and color or WHITE)
			p.Shape = Enum.PartType.Cylinder
			p.Transparency = 0.55
			tween(p, 0.4, { Size = Vector3.new(0.05, 11, 11) * size, Transparency = 1 })
		end)
	end
end

function FX.Stretch(_, color, spot, size)
	local at = spot * CFrame.new(0, 0, 11 * size)
	ring(at.Position, color, 12 * size)
	ball(at, 1, 6 * size, color, 0.3)
	chunks(at, color, 10, 7 * size, 0.5)
end

-- Power: a blood hammer grown overhead, swung down onto the ground in front of her
function FX.Hammer(_, color, spot, size)
	local pivot = spot * CFrame.new(0, -1.5 * size, 0)
	local up = pivot * CFrame.Angles(math.rad(-30), 0, 0)
	local down = pivot * CFrame.Angles(math.rad(115), 0, 0)
	local handle = CFrame.new(0, 2 * size, 0)
	local head = CFrame.new(0, 4.4 * size, 0)
	local stick = neon(Vector3.new(0.5, 4.5, 0.5) * size, up * handle, color)
	local block = neon(Vector3.new(1, 1, 1) * size, up * head, color)
	TweenService:Create(block, TweenInfo.new(0.25, Enum.EasingStyle.Back, OUT), { Size = Vector3.new(4.6, 3, 3) * size }):Play()
	task.wait(0.28)
	TweenService:Create(stick, TweenInfo.new(0.16, QUAD, Enum.EasingDirection.In), { CFrame = down * handle }):Play()
	TweenService:Create(block, TweenInfo.new(0.16, QUAD, Enum.EasingDirection.In), { CFrame = down * head }):Play()
	task.wait(0.7)
	tween(stick, 0.25, { Transparency = 1 })
	tween(block, 0.25, { Transparency = 1 })
end

function FX.Slam(model, color, spot, size)
	local pos = ground(spot, model)
	ring(pos, color, 22 * size, 0.6)
	ring(pos + Vector3.new(0, 0.3, 0), WHITE, 13 * size, 0.4)
	chunks(CFrame.new(pos), color, 22, 10 * size, 0.7, 0.8)
end

function FX.Pop(_, color, spot, size)
	local at = spot * CFrame.new(0, 0, 18 * size)
	ball(spot * CFrame.new(0, 0, 0.5), 0.2, 1.2 * size, WHITE, 0.15)
	task.delay(0.35, function()
		ball(at, 1, 12 * size, color, 0.4)
		chunks(at, color, 20, 9 * size, 0.7)
	end)
end

function FX.Punch(_, color, spot, size)
	local at = spot * CFrame.new(0, 0, 1 * size)
	for i = 0, 3 do
		task.delay(i * 0.07, ring, (at * CFrame.new(0, 0, (2 + i * 4) * size)).Position, i % 2 == 0 and color or WHITE, (9 + i * 6) * size, 0.45)
	end
	task.spawn(beam, at, 22 * size, 3 * size, color, 0.1)
end

function FX.BlackFlash(_, color, spot, size)
	local at = spot * CFrame.new(0, 0, 1 * size)
	local red = Color3.fromRGB(255, 42, 42)
	ball(at, 1, 7 * size, color, 0.3)
	for i = 1, 6 do
		local a = i * 1.05
		task.delay(i * 0.02, bolt, at.Position, (at * CFrame.new(math.cos(a) * 7 * size, math.sin(a) * 7 * size, 1)).Position, i % 2 == 0 and red or color, 0.3 * size)
	end
end

function FX.FireBreath(_, color, spot, size)
	local at = spot * CFrame.new(0, -0.6 * size, 0.8 * size)
	for i = 1, 16 do
		task.delay(i * 0.04, function()
			local p = neon(Vector3.one * 0.9 * size, at, i % 3 == 0 and Color3.fromRGB(255, 214, 77) or color)
			local to = at * CFrame.new((math.random() - 0.5) * 8 * size, (math.random() - 0.5) * 6 * size, (14 + math.random() * 6) * size)
			tween(p, 0.6, { CFrame = to * CFrame.Angles(i, i, 0), Size = Vector3.one * 3.5 * size, Transparency = 1 })
		end)
	end
end

function FX.Sparks(_, color, spot, size)
	chunks(spot * CFrame.new(0, 0, 1 * size), color, 12, 5 * size, 0.35, 0.25)
end

function FX.Slashes(_, color, spot, size)
	for i = 1, 14 do
		local a, b = math.random() * math.pi * 2, 3 + math.random() * 7
		local cf = spot * CFrame.new(math.cos(a) * b * size, 1 + math.random() * 7 * size, math.sin(a) * b * size) * CFrame.Angles(math.random() * 3, math.random() * 3, math.random() * 3)
		task.spawn(slash, cf, i % 3 == 0 and WHITE or color, i * 0.05, 9 * size)
	end
end

function FX.Pulse(_, color, spot, size)
	local at = spot * CFrame.new(0, 0, 0.8 * size)
	ring(at.Position, color, 5 * size, 0.3)
	ball(at, 0.5, 2.5 * size, WHITE, 0.2)
end

function FX.Gate(_, color, spot, size)
	local at = spot * CFrame.new(0, 2 * size, 4 * size)
	local gate = neon(Vector3.new(0.3, 0.3, 0.1) * size, at, color)
	tween(gate, 0.9, { Size = Vector3.new(7, 10, 0.1) * size, Transparency = 1 })
	for i = 0, 2 do
		task.delay(i * 0.14, ring, at.Position, i == 1 and WHITE or color, 12 * size, 0.6)
	end
	chunks(at, color, 12, 8 * size, 0.8)
end

function FX.Wind(_, color, spot, size)
	for i = 0, 5 do
		local cf = spot * CFrame.new(0, (i - 2) * 0.9 * size, (2 + i) * size) * CFrame.Angles(0, 0, math.rad(i * 9 - 20))
		task.spawn(slash, cf, i % 2 == 0 and color or WHITE, i * 0.05, 12 * size)
	end
end

function FX.Ice(model, color, spot, size)
	local pos = ground(spot, model)
	for i = 1, 9 do
		task.delay(i * 0.03, function()
			local cf = CFrame.new(pos) * spot.Rotation * CFrame.new((i % 3 - 1) * 1.4 * size, 0, i * 1.6 * size) * CFrame.Angles(math.rad(14), 0, math.rad((i % 3 - 1) * 12))
			local h = (2.5 + i * 0.5) * size
			local p = neon(Vector3.new(1.4 * size, 0.1, 1.4 * size), cf, color)
			TweenService:Create(p, TweenInfo.new(0.16, Enum.EasingStyle.Back, OUT), { Size = Vector3.new(1.4 * size, h, 1.4 * size), CFrame = cf * CFrame.new(0, h / 2, 0) }):Play()
			task.delay(0.9, function()
				tween(p, 0.4, { Size = Vector3.new(0.1, h, 0.1), Transparency = 1 })
			end)
		end)
	end
end

function FX.Fire(_, color, spot, size)
	local at = spot * CFrame.new(0, 0, 0.8 * size)
	for i = 1, 14 do
		task.delay(i * 0.035, function()
			local a = -0.9 + i * 0.13
			local p = neon(Vector3.one * 0.8 * size, at, i % 3 == 0 and Color3.fromRGB(255, 214, 77) or Color3.fromRGB(255, 90, 31))
			tween(p, 0.55, { CFrame = at * CFrame.new(math.sin(a) * 12 * size, math.random() * 2, math.cos(a) * 12 * size), Size = Vector3.one * 2.6 * size, Transparency = 1 })
		end)
	end
end

function FX.Flare(_, color, spot, size)
	local at = spot * CFrame.new(0, 2 * size, 0)
	ball(at, 1, 18 * size, color, 0.8)
	ball(at, 1, 10 * size, WHITE, 0.5)
	ring(at.Position, color, 30 * size, 0.8)
	chunks(at, color, 16, 14 * size, 0.9)
end

function FX.Stars(_, color, spot, size)
	for i = 1, 14 do
		local a = i * 0.9
		local cf = spot * CFrame.new(math.cos(a) * 3 * size, 1 + (i % 4) * 1.1 * size, math.sin(a) * 3 * size)
		task.delay(i * 0.04, function()
			local p = neon(Vector3.one * 0.5 * size, cf * CFrame.Angles(0.8, 0.8, 0), i % 3 == 0 and WHITE or color)
			tween(p, 1, { CFrame = cf * CFrame.new(0, 3 * size, 0) * CFrame.Angles(0.8, 3, 0), Size = Vector3.one * 0.05, Transparency = 0.3 }, Enum.EasingStyle.Sine)
		end)
	end
end

return FX
