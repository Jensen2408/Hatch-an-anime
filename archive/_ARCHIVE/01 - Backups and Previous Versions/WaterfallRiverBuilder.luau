-- ServerStorage.WaterfallRiverBuilder  (run from the Command Bar:  require(game.ServerStorage.WaterfallRiverBuilder:Clone())() )
return function()
	local RS = game:GetService("ReplicatedStorage")
	local tmp = RS:WaitForChild("WaterfallRiver"):Clone() -- fresh copies so config edits apply without restarting Studio
	local Config = require(tmp.RiverConfig)
	local Path = require(tmp.RiverPath)
	local O, C = Config.Origin, Config.Colors
	local surf = Path.SurfaceY
	local bedTop = surf - Config.WaterDepth
	local topY = O.Y + Config.FallHeight
	local fw = Config.FallWidth
	local terrain = workspace.Terrain
	local rng = Random.new(Config.Seed)
	local function r(a, b) return a + (b - a) * rng:NextNumber() end
	local function chance(p) return rng:NextNumber() < p end
	local smooth = Path.Smooth
	local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

	local old = workspace:FindFirstChild("WaterfallRiver")
	if old then old:Destroy() end
	local root = Instance.new("Model")
	root.Name = "WaterfallRiver"
	local function group(name) local m = Instance.new("Model"); m.Name = name; m.Parent = root; return m end
	local Ground, Bed, Cliff, Fall, Banks, Rocks, Plants, Props, FX =
		group("Ground"), group("RiverBed"), group("Cliff"), group("Waterfall"), group("Banks"), group("Rocks"), group("Plants"), group("Props"), group("FX")

	local function vary(c, amt)
		local h, s, v = c:ToHSV()
		return Color3.fromHSV(h, math.clamp(s + r(-amt, amt) * 0.6, 0, 1), math.clamp(v + r(-amt, amt), 0, 1))
	end
	local function P(parent, size, cf, color, o)
		o = o or {}
		local p = Instance.new("Part")
		p.Anchored = true
		p.Size = size
		p.CFrame = cf
		p.Color = color
		p.Material = o.material or Enum.Material.Plastic
		p.TopSurface = o.smooth and Enum.SurfaceType.Smooth or Enum.SurfaceType.Studs
		p.BottomSurface = Enum.SurfaceType.Smooth
		if o.shape then p.Shape = o.shape end
		if o.transparency then p.Transparency = o.transparency end
		if o.fx then p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false end
		if o.noCollide then p.CanCollide = false end
		if o.name then p.Name = o.name end
		p.Parent = parent
		return p
	end
	local function frame(pos, tan) return CFrame.fromMatrix(pos, tan, Vector3.yAxis) end -- X downstream, Z = right
	local function flat(pos, dir) return CFrame.fromMatrix(pos, dir, Vector3.yAxis:Cross(dir)) end -- beam lying flat, flowing along dir

	local anchor = P(FX, Vector3.new(0.2, 0.2, 0.2), CFrame.new(O), C.Foam, { fx = true, transparency = 1, smooth = true, name = "FXAnchor" })
	local function att(cf) local a = Instance.new("Attachment"); a.Parent = anchor; a.WorldCFrame = cf; return a end
	local function beam(a0, a1, w0, w1, o)
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = a0, a1
		b.Width0, b.Width1 = w0, w1
		b.FaceCamera = false
		b.Segments = 24
		b.Color = ColorSequence.new(o.color or C.Foam)
		b.LightEmission = o.emission or 0.08
		b.LightInfluence = 0.75
		b.CurveSize0, b.CurveSize1 = o.c0 or 0, o.c1 or 0
		b.ZOffset = o.z or 0
		if o.speed then
			local phase = r(0, 2)
			b:SetAttribute("FlowSpeed", o.speed); b:SetAttribute("FlowLen", o.len); b:SetAttribute("FlowAlpha", o.alpha)
			b:SetAttribute("FlowPhase", phase); b:SetAttribute("FlowCount", o.count or 1)
			b.Transparency = Path.Dash(phase, o.len, o.alpha, o.count or 1)
		else
			b.Transparency = NumberSequence.new(1)
		end
		b.Name = o.name or "Streak"
		b.Parent = anchor
		return b
	end
	local function emitter(parent, props)
		local e = Instance.new("ParticleEmitter")
		e.Texture = SMOKE
		e.LightEmission = 0.05
		e.LightInfluence = 0.9
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-40, 40)
		e.Color = ColorSequence.new(C.Foam)
		for k, v in props do e[k] = v end
		e.Parent = parent
		return e
	end
	local NS = NumberSequence.new
	local KP = NumberSequenceKeypoint.new

	for k, v in Config.Terrain do terrain[k] = v end
	local zSpan = (Config.Meander + Config.RiverWidth / 2 + Config.PoolExtraWidth + 6) * 2
	terrain:FillBlock(CFrame.new(O.X + Config.Length / 2, surf - 2, O.Z), Vector3.new(Config.Length + 12, 8, zSpan), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(O.X - Config.CliffDepth / 2, topY - 2, O.Z), Vector3.new(Config.CliffDepth + 4, 6, fw + 4), Enum.Material.Air)

	local segs, d = {}, 0
	while d < Path.Total - 0.01 do
		local d1 = math.min(d + (d < Config.PoolLength and 3 or 9), Path.Total)
		table.insert(segs, { d, d1 })
		d = d1
	end
	for i, s in segs do
		local dm, len = (s[1] + s[2]) / 2, s[2] - s[1]
		local pos, tan, right = Path.At(dm)
		local hw = Path.WidthAt(dm) / 2
		local back = i == 1 and 2 or 0
		local c = pos - tan * (back / 2)
		len += back
		local lift = (i % 2) * 0.04
		if Config.BuildGround then
			for _, side in { -1, 1 } do
				local gp = c + right * side * (hw + 15)
				P(Ground, Vector3.new(len + 1.4, 10, 30), frame(Vector3.new(gp.X, O.Y - 5 + lift, gp.Z), tan), vary(C.Grass, 0.025), { name = "Turf" })
			end
		end
		local bedCol = C.Bed:Lerp(C.BedLight, math.clamp(0.5 + math.noise(dm / 40, 3.1) * 1.2, 0, 1))
		P(Bed, Vector3.new(len + 1.2, 2, hw * 2 + 2), frame(Vector3.new(c.X, bedTop - 1 + lift * 0.5, c.Z), tan), bedCol, { name = "Bed" })
		terrain:FillBlock(frame(Vector3.new(c.X, surf - 2, c.Z), tan), Vector3.new(len + 1.5, 4, hw * 2 + 0.5), Enum.Material.Water)
		for _ = 1, math.floor(len / 3) do
			if chance(0.7) then
				local h = r(0.3, 0.6)
				local pp = c + tan * r(-len / 2, len / 2) + right * r(-hw + 0.8, hw - 0.8)
				local col = ({ C.Sand, C.BedLight, C.StoneLight, C.Bed })[rng:NextInteger(1, 4)]
				P(Bed, Vector3.new(r(0.6, 1.5), h, r(0.6, 1.3)), CFrame.new(pp.X, bedTop + h / 2 - 0.1, pp.Z) * CFrame.Angles(0, r(0, 6.28), 0), vary(col, 0.05), { name = "Pebble" })
			end
		end
	end
	if Config.BuildGround then
		local inner = Config.Meander + Config.RiverWidth / 2 + 10
		for _, side in { -1, 1 } do
			P(Ground, Vector3.new(Config.Length + 2, 10, Config.PlayWidth), CFrame.new(O.X + Config.Length / 2 + 1, O.Y - 5.04, O.Z + side * (inner + Config.PlayWidth / 2)), C.Grass, { name = "Field" })
		end
	end

	local HW, CD = Config.CliffHalfWidth, Config.CliffDepth
	local function column(zc, w, h, faceX, wet)
		local col = wet and vary(C.StoneDark, 0.04) or vary(chance(0.3) and C.StoneLight or C.Stone, 0.05)
		local p = P(Cliff, Vector3.new(CD, h + 6, w), CFrame.new(faceX - CD / 2, O.Y + h / 2 - 3, zc), col, { name = "CliffColumn" })
		if not wet and chance(0.55) then
			local md = CD * r(0.25, 0.6)
			P(Cliff, Vector3.new(md, 0.5, w * r(0.5, 0.9)), CFrame.new(faceX - md / 2 - r(0, 2), O.Y + h + 0.25, zc + r(-0.5, 0.5)), vary(C.Moss, 0.05), { name = "Moss" })
		end
		return p
	end
	column(O.Z, fw, Config.FallHeight - 1.6, O.X, true)
	P(Cliff, Vector3.new(4, Config.FallHeight + 10, fw + 2), CFrame.new(O.X - CD - 1, O.Y + (Config.FallHeight + 4) / 2 - 3 + 2, O.Z), vary(C.Stone, 0.04), { name = "ChannelBack" })
	for _, side in { -1, 1 } do
		local z = fw / 2
		while z < HW do
			local w = math.min(r(5, 9), HW - z + 0.5)
			local zc = O.Z + side * (z + w / 2)
			local az = z + w / 2
			local e = smooth(HW * 0.55, HW, az)
			local h = (az < fw / 2 + 7) and (Config.FallHeight + r(3, 6)) or math.max(6, Config.FallHeight * (1 - 0.8 * e) + r(-2, 5))
			local wet = az < fw / 2 + 4
			local faceX = O.X - (az < fw / 2 + 3 and 0 or r(0, 2.5))
			column(zc, w, h, faceX, wet)
			if not wet and chance(0.5) then
				local bd, bh = r(2.5, 4.5), r(4, 12)
				P(Cliff, Vector3.new(bd + 3, bh, w * r(0.6, 1)), CFrame.new(faceX + bd / 2 - 1.5, O.Y + bh / 2 - 1, zc), vary(C.Stone, 0.05), { name = "Buttress" })
			end
			z += w
		end
	end
	for _ = 1, 16 do
		local side = chance(0.5) and 1 or -1
		local az = r(fw / 2 + 3, HW * 0.8)
		local sx = r(3, 5.5)
		local y = r(5, Config.FallHeight * (1 - 0.7 * smooth(HW * 0.55, HW, az)) - 3)
		P(Cliff, Vector3.new(sx, r(1.2, 2.6), r(4, 9)), CFrame.new(O.X - 3 + sx / 2, O.Y + y, O.Z + side * az), vary(C.StoneLight, 0.05), { name = "Ledge" })
	end
	terrain:FillBlock(CFrame.new(O.X - CD / 2, topY - 2, O.Z), Vector3.new(CD, 4, fw), Enum.Material.Water)

	local yTop, yBot = topY - 0.2, surf - 0.6
	local Hf = yTop - yBot
	local layers = {
		{ x = 0.75, t = 1.4, w = fw, tr = 0.3, c = C.WaterDeep },
		{ x = 1.75, t = 0.6, w = fw - 1.4, tr = 0.42, c = C.Water },
		{ x = 2.3, t = 0.3, w = fw - 3, tr = 0.56, c = C.WaterLight },
	}
	for i, L in layers do
		P(Fall, Vector3.new(L.t, Hf, L.w), CFrame.new(O.X + L.x, yBot + Hf / 2, O.Z), L.c, { fx = true, smooth = true, transparency = L.tr, material = Enum.Material.SmoothPlastic, name = "FallLayer" .. i })
	end
	P(Fall, Vector3.new(3.6, 0.5, fw - 0.4), CFrame.new(O.X + 0.6, topY - 0.4, O.Z) * CFrame.Angles(0, 0, math.rad(-16)), C.Water, { fx = true, smooth = true, transparency = 0.3, material = Enum.Material.SmoothPlastic, name = "Overflow" })
	local down, across = Vector3.new(0, -1, 0), Vector3.new(0, 0, -1)
	local function fallStreaks(n, x, halfW, alphaA, alphaB, vA, vB, wA, wB)
		for _ = 1, n do
			local z = O.Z + r(-halfW, halfW)
			local w = r(wA, wB)
			beam(att(CFrame.fromMatrix(Vector3.new(x, yTop, z), down, across)), att(CFrame.fromMatrix(Vector3.new(x, yBot + 0.8, z), down, across)), w, w * r(1, 1.6),
				{ speed = r(vA, vB) / Hf, len = r(0.1, 0.22), alpha = r(alphaA, alphaB), count = 2, name = "FallStreak" })
		end
	end
	fallStreaks(20, O.X + 2.3 + 0.17, (fw - 3) / 2 - 0.4, 0.05, 0.3, 22, 34, 0.25, 0.75)
	fallStreaks(12, O.X + 1.75 + 0.32, (fw - 1.4) / 2 - 0.4, 0.35, 0.55, 16, 24, 0.4, 1.0)
	fallStreaks(6, O.X + 0.75 + 0.72, fw / 2 - 0.5, 0.5, 0.65, 12, 18, 0.5, 1.2)
	for _ = 1, 10 do
		local z = O.Z + r(-fw / 2 + 1, fw / 2 - 1)
		local w = r(0.2, 0.5)
		beam(att(flat(Vector3.new(O.X - 14, topY + 0.1, z), Vector3.xAxis)), att(flat(Vector3.new(O.X + 0.4, topY + 0.1, z), Vector3.xAxis)), w, w,
			{ speed = r(8, 12) / 14.4, len = r(0.25, 0.4), alpha = r(0.3, 0.5), name = "ChannelStreak" })
	end

	local base = P(FX, Vector3.new(3, 0.2, fw - 1), CFrame.new(O.X + 2.8, surf + 0.1, O.Z), C.Foam, { fx = true, smooth = true, transparency = 1, name = "SplashEmitter" })
	emitter(base, { Name = "Spray", Size = NS({ KP(0, 1.2), KP(1, 3.2) }), Transparency = NS({ KP(0, 0.55), KP(0.3, 0.62), KP(1, 1) }), Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 22, Speed = NumberRange.new(5, 9), SpreadAngle = Vector2.new(35, 35), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(3, -5, 0), Drag = 1.5 })
	emitter(base, { Name = "Mist", Size = NS({ KP(0, 4), KP(1, 9) }), Transparency = NS({ KP(0, 1), KP(0.25, 0.85), KP(1, 1) }), Lifetime = NumberRange.new(3, 4.5),
		Rate = 4, Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(70, 70), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(2.2, 0.5, 0), Drag = 0.4, RotSpeed = NumberRange.new(-12, 12) })
	emitter(base, { Name = "Droplets", Size = NS({ KP(0, 0.35), KP(1, 0.18) }), Transparency = NS({ KP(0, 0.15), KP(1, 0.5) }), Lifetime = NumberRange.new(0.6, 1),
		Rate = 26, Speed = NumberRange.new(9, 15), SpreadAngle = Vector2.new(40, 40), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, -45, 0) })
	local face = P(FX, Vector3.new(0.2, Hf * 0.8, fw - 3), CFrame.new(O.X + 2.6, yBot + Hf * 0.45, O.Z), C.Foam, { fx = true, smooth = true, transparency = 1, name = "SheetDroplets" })
	emitter(face, { Name = "SheetDrops", Size = NS({ KP(0, 0.3), KP(1, 0.15) }), Transparency = NS({ KP(0, 0.3), KP(1, 0.7) }), Lifetime = NumberRange.new(0.5, 0.9),
		Rate = 7, Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Right, Acceleration = Vector3.new(0, -40, 0) })
	local lip = P(FX, Vector3.new(0.2, 0.2, fw - 2), CFrame.new(O.X + 2.2, topY - 0.8, O.Z), C.Foam, { fx = true, smooth = true, transparency = 1, name = "LipDroplets" })
	emitter(lip, { Name = "LipDrops", Size = NS({ KP(0, 0.3), KP(1, 0.2) }), Transparency = NS({ KP(0, 0.25), KP(1, 0.6) }), Lifetime = NumberRange.new(0.6, 1),
		Rate = 5, Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(20, 40), EmissionDirection = Enum.NormalId.Right, Acceleration = Vector3.new(0, -40, 0) })

	local function streakAlong(dA, len, latA, latB, w0, w1, o)
		local pA, tA, rA = Path.At(dA)
		local pB, tB, rB = Path.At(dA + len)
		local y = surf + (o.y or 0.12)
		local a = (pA + rA * latA); local b = (pB + rB * latB)
		return beam(att(flat(Vector3.new(a.X, y, a.Z), tA)), att(flat(Vector3.new(b.X, y, b.Z), tB)), w0, w1,
			{ speed = o.speed, len = o.len, alpha = o.alpha, count = o.count, c0 = len / 3, c1 = len / 3, z = o.z, name = o.name })
	end
	for k = 1, 16 do
		local dA = Path.LandDistance + r(-3, 10)
		local hw = Path.WidthAt(dA) / 2 - 1.5
		local lat = r(-hw, hw)
		local len = r(3, 8)
		streakAlong(dA, len, lat, math.clamp(lat + r(-1, 1), -hw, hw), r(1.2, 3), r(0.6, 2.6),
			{ speed = r(4, 7) / len, len = r(0.5, 0.8), alpha = r(0.25, 0.45), y = 0.12 + k * 0.004, name = "Foam" })
	end
	for _ = 1, 46 do
		local dA = Config.PoolLength * 0.5 + (Path.Total - Config.PoolLength - 20) * rng:NextNumber() ^ 1.6
		local len = r(14, 40)
		local hw = Path.WidthAt(dA) / 2
		local lat = r(-0.7, 0.7) * hw
		local near = 1 - smooth(0, 160, dA)
		local w = r(0.15, 0.4)
		streakAlong(dA, len, lat, math.clamp(lat + r(-1.5, 1.5), -hw * 0.8, hw * 0.8), w, w * r(0.7, 1.3),
			{ speed = Config.Egg.FloatSpeed * r(1, 1.6) / len, len = r(0.18, 0.4), alpha = 0.62 + (0.28 - 0.62) * near, count = chance(0.5) and 2 or 1, name = "Current" })
	end
	for i = 1, 7 do
		local b = beam(att(CFrame.new(O)), att(CFrame.new(O)), 0.2, 0.2, { name = "Ripple" })
		b:SetAttribute("Ripple", i); b:SetAttribute("RippleCount", 7)
	end

	local occupied = {}
	local function free(p, rad)
		for _, o in occupied do
			if (Vector2.new(o[1].X, o[1].Z) - Vector2.new(p.X, p.Z)).Magnitude < rad + o[2] then return false end
		end
		return true
	end
	local function claim(p, rad) table.insert(occupied, { p, rad }) end
	local function boulder(parent, basePos, s, color, hMul)
		hMul = hMul or 1
		local cf = CFrame.new(basePos) * CFrame.Angles(0, r(0, 6.28), 0) * CFrame.Angles(math.rad(r(-6, 6)), 0, math.rad(r(-6, 6)))
		local mS = Vector3.new(s * r(1, 1.3), s * r(0.6, 0.85) * hMul, s * r(0.85, 1.1))
		local mainCF = cf * CFrame.new(0, mS.Y / 2 - s * 0.15, 0)
		P(parent, mS, mainCF, vary(color, 0.05), { name = "Rock" })
		local tS = Vector3.new(mS.X * r(0.5, 0.7), s * r(0.3, 0.45), mS.Z * r(0.5, 0.75))
		local topCF = mainCF * CFrame.new(r(-0.15, 0.15) * s, mS.Y / 2 + tS.Y / 2 - 0.12 * s, r(-0.15, 0.15) * s) * CFrame.Angles(0, r(-0.4, 0.4), 0)
		P(parent, tS, topCF, vary(color, 0.05), { name = "Rock" })
		if chance(0.75) then
			local cS = Vector3.new(s * r(0.4, 0.6), s * r(0.35, 0.55) * hMul, s * r(0.4, 0.6))
			P(parent, cS, mainCF * CFrame.new(mS.X * 0.45, -mS.Y / 2 + cS.Y / 2, r(-0.25, 0.25) * s) * CFrame.Angles(0, r(-0.6, 0.6), 0), vary(C.StoneDark:Lerp(color, 0.5), 0.05), { name = "Rock" })
		end
		if chance(0.6) then
			P(parent, Vector3.new(tS.X * 0.8, 0.3, tS.Z * 0.7), topCF * CFrame.new(0, tS.Y / 2 + 0.15, 0), vary(C.Moss, 0.05), { name = "Moss" })
		end
	end
	local function foamAround(dA, lat, s, side)
		for k = 0, 1 do
			local len = r(4, 7)
			streakAlong(dA, len, lat - side * s * (0.6 - k * 0.3), lat - side * s * (0.3 + k * 0.4), 0.9, 0.3,
				{ speed = 6 / len, len = 0.6, alpha = r(0.3, 0.4), y = 0.14, name = "RockFoam" })
		end
	end
	for i = 1, 3 do
		local side = i % 2 == 0 and 1 or -1
		local dA = r(3, Config.PoolLength)
		local pos, _, right = Path.At(dA)
		local hw = Path.WidthAt(dA) / 2
		local s = r(4, 6)
		local p = pos + right * side * (hw - 1.5)
		boulder(Rocks, Vector3.new(p.X, bedTop, p.Z), s, C.StoneLight, 1.4)
		claim(p, s * 0.8)
		foamAround(dA, side * (hw - 1.5), s * 0.6, side)
	end
	local bridgeD = Path.Total * 0.55
	for _ = 1, 7 do
		local dA = r(Config.PoolLength + 10, Path.Total - 20)
		if math.abs(dA - bridgeD) > 12 then
			local side = chance(0.5) and 1 or -1
			local pos, _, right = Path.At(dA)
			local hw = Path.WidthAt(dA) / 2
			local lat = side * (hw - r(0.3, 1.2))
			local p = pos + right * lat
			local s = r(1.8, 2.6)
			if free(p, s) then
				boulder(Rocks, Vector3.new(p.X, bedTop, p.Z), s, C.Stone, 1.5)
				claim(p, s)
				foamAround(dA, lat, s * 0.6, side)
			end
		end
	end
	for _ = 1, 9 do
		local dA = r(4, Path.Total - 6)
		if math.abs(dA - bridgeD) > 12 then
			local side = chance(0.5) and 1 or -1
			local pos, _, right = Path.At(dA)
			local p = pos + right * side * (Path.WidthAt(dA) / 2 + r(2.5, 7))
			local s = r(3, 6)
			if free(p, s) then boulder(Rocks, Vector3.new(p.X, O.Y, p.Z), s, chance(0.5) and C.Stone or C.StoneLight); claim(p, s) end
		end
	end
	for _ = 1, 30 do
		local dA = r(0, Path.Total)
		local side = chance(0.5) and 1 or -1
		local pos, _, right = Path.At(dA)
		local p = pos + right * side * (Path.WidthAt(dA) / 2 + r(1.5, 10))
		local s = r(0.8, 1.6)
		if free(p, s * 0.6) then boulder(Rocks, Vector3.new(p.X, O.Y, p.Z), s, C.StoneLight); claim(p, s * 0.6) end
	end

	d = 1.5
	while d < Path.Total - 2 do
		local step = r(3.5, 7)
		if math.abs(d - bridgeD) > 4.5 then
			local pos, tan, right = Path.At(d)
			local hw = Path.WidthAt(d) / 2
			for _, side in { -1, 1 } do
				if chance(0.78) then
					local len, h, dep = r(2.5, 6.5), r(1.6, 2.8), r(1.8, 3.2)
					local p = pos + right * side * (hw + dep / 2 - r(0.4, 1))
					local top = O.Y + r(-0.3, 0.7)
					local cf = frame(Vector3.new(p.X, top - h / 2, p.Z), tan) * CFrame.Angles(0, math.rad(r(-12, 12)), 0)
					P(Banks, Vector3.new(len, h, dep), cf, vary(chance(0.35) and C.StoneLight or C.Stone, 0.05), { name = "BankStone" })
					if chance(0.3) then P(Banks, Vector3.new(len * r(0.4, 0.8), 0.3, dep * r(0.5, 0.8)), cf * CFrame.new(r(-0.5, 0.5), h / 2 + 0.15, 0), vary(C.Moss, 0.05), { name = "Moss" }) end
				end
			end
		end
		d += step
	end

	local function landSpot(minOff, maxOff, avoidR, tries, minD)
		for _ = 1, tries or 12 do
			local dA = r(minD or 2, Path.Total - 4)
			local side = chance(0.5) and 1 or -1
			local pos, _, right = Path.At(dA)
			local p = pos + right * side * (Path.WidthAt(dA) / 2 + r(minOff, maxOff))
			p = Vector3.new(p.X, O.Y, p.Z)
			if math.abs(dA - bridgeD) > 8 and free(p, avoidR) then return p, dA, side end
		end
	end
	for _ = 1, 70 do
		local p = landSpot(1.5, 12, 0.6, 4)
		if p then
			for _ = 1, rng:NextInteger(3, 4) do
				local h = r(0.7, 1.4)
				P(Plants, Vector3.new(0.3, h, 0.18), CFrame.new(p + Vector3.new(r(-0.4, 0.4), 0, r(-0.4, 0.4))) * CFrame.Angles(math.rad(r(-18, 18)), r(0, 6.28), math.rad(r(-18, 18))) * CFrame.new(0, h / 2, 0),
					vary(chance(0.5) and C.Grass or C.GrassDark, 0.06), { smooth = true, noCollide = true, name = "Blade" })
			end
		end
	end
	for _ = 1, 10 do
		local p = landSpot(-0.3, 1.2, 1.5, 8)
		if p then
			claim(p, 1.5)
			local flower = chance(0.45)
			for k = 1, rng:NextInteger(4, 6) do
				local h = r(2.5, 4)
				local cf = CFrame.new(p + Vector3.new(r(-0.6, 0.6), 0, r(-0.6, 0.6))) * CFrame.Angles(math.rad(r(-10, 10)), r(0, 6.28), math.rad(r(-10, 10)))
				P(Plants, Vector3.new(0.25, h, 0.12), cf * CFrame.new(0, h / 2, 0), vary(C.Reed, 0.06), { smooth = true, noCollide = true, name = "Reed" })
				if flower and k <= 2 then P(Plants, Vector3.new(0.6, 0.6, 0.6), cf * CFrame.new(0, h, 0) * CFrame.Angles(0, 0.78, 0), vary(C.Iris, 0.05), { noCollide = true, name = "Iris" }) end
			end
		end
	end
	for _ = 1, 3 do
		local p = landSpot(10, 16, 4, 20, Config.PoolLength + 30)
		if p then
			claim(p, 4)
			for _ = 1, rng:NextInteger(4, 6) do
				local b = p + Vector3.new(r(-2.5, 2.5), 0, r(-2.5, 2.5))
				local rad = r(0.45, 0.65)
				local stalk = CFrame.new(b) * CFrame.Angles(math.rad(r(-5, 5)), 0, math.rad(r(-5, 5)))
				local y, H = 0, r(14, 22)
				while y < H do
					local sl = math.min(r(2.6, 3.6), H - y)
					P(Plants, Vector3.new(sl - 0.08, rad * 2, rad * 2), stalk * CFrame.new(0, y + sl / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), vary(C.Bamboo, 0.04), { smooth = true, shape = Enum.PartType.Cylinder, name = "Bamboo" })
					P(Plants, Vector3.new(0.18, rad * 2 + 0.12, rad * 2 + 0.12), stalk * CFrame.new(0, y + sl, 0) * CFrame.Angles(0, 0, math.pi / 2), C.BambooNode, { smooth = true, shape = Enum.PartType.Cylinder, noCollide = true, name = "Node" })
					y += sl
				end
				for _ = 1, 4 do
					P(Plants, Vector3.new(2.4, 0.1, 0.6), stalk * CFrame.new(0, H - r(0, 3), 0) * CFrame.Angles(0, r(0, 6.28), math.rad(r(-25, -10))) * CFrame.new(1.2, 0, 0), vary(C.Grass, 0.05), { smooth = true, noCollide = true, name = "Leaf" })
				end
			end
		end
	end
	local function tree(p, canopy)
		claim(p, 5)
		local lean = CFrame.new(p) * CFrame.Angles(math.rad(r(-6, 6)), r(0, 6.28), math.rad(r(-6, 6)))
		P(Plants, Vector3.new(1.5, 6, 1.5), lean * CFrame.new(0, 3, 0), vary(C.Bark, 0.04), { name = "Trunk" })
		local upper = lean * CFrame.new(0.3, 6, 0) * CFrame.Angles(0, 0, math.rad(-12))
		P(Plants, Vector3.new(1.1, 4, 1.1), upper * CFrame.new(0, 2, 0), vary(C.Bark, 0.04), { name = "Trunk" })
		local top = (upper * CFrame.new(0, 4, 0)).Position
		for _ = 1, rng:NextInteger(7, 9) do
			local s = r(3.5, 6.5)
			P(Plants, Vector3.new(s, s * r(0.6, 0.9), s * r(0.8, 1.1)), CFrame.new(top + Vector3.new(r(-3.5, 3.5), r(-0.5, 3), r(-3.5, 3.5))) * CFrame.Angles(0, r(0, 6.28), 0),
				vary(canopy, 0.07), { noCollide = true, name = "Canopy" })
		end
	end
	local spots = {
		{ Config.PoolLength + r(2, 10), -1, C.Blossom },
		{ Path.Total * 0.35, 1, C.Maple },
		{ Path.Total * 0.78, -1, C.Blossom },
	}
	for _, sp in spots do
		local pos, _, right = Path.At(sp[1])
		local p = pos + right * sp[2] * (Path.WidthAt(sp[1]) / 2 + r(8, 12))
		tree(Vector3.new(p.X, O.Y, p.Z), sp[3])
	end

	for _, side in { -1, 1 } do
		local dA = r(5, Config.PoolLength - 4)
		local pos, _, right = Path.At(dA)
		local p = pos + right * side * (Path.WidthAt(dA) / 2 + 4.5)
		local b = CFrame.new(p.X, O.Y, p.Z) * CFrame.Angles(0, r(-0.3, 0.3), 0)
		claim(p, 2)
		local m = Instance.new("Model"); m.Name = "StoneLantern"; m.Parent = Props
		local sc = vary(C.StoneLight, 0.03)
		P(m, Vector3.new(2.4, 0.6, 2.4), b * CFrame.new(0, 0.3, 0), sc)
		P(m, Vector3.new(0.9, 2.6, 0.9), b * CFrame.new(0, 1.9, 0), sc)
		P(m, Vector3.new(2, 0.4, 2), b * CFrame.new(0, 3.4, 0), sc)
		local box = P(m, Vector3.new(1.5, 1.3, 1.5), b * CFrame.new(0, 4.25, 0), C.Paper, { material = Enum.Material.SmoothPlastic, smooth = true })
		local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255, 196, 120); light.Brightness = 0.8; light.Range = 12; light.Parent = box
		P(m, Vector3.new(2.8, 0.5, 2.8), b * CFrame.new(0, 5.15, 0), sc)
		P(m, Vector3.new(1.6, 0.4, 1.6), b * CFrame.new(0, 5.6, 0), sc)
		P(m, Vector3.new(0.6, 0.6, 0.6), b * CFrame.new(0, 6.1, 0) * CFrame.Angles(0, 0.78, 0), sc)
	end
	do
		local m = Instance.new("Model"); m.Name = "Bridge"; m.Parent = Props
		local pos, tan, right = Path.At(bridgeD)
		local S = Path.WidthAt(bridgeD) / 2 + 5
		local n = 9
		local fr = frame(Vector3.new(pos.X, O.Y, pos.Z), tan)
		local function deckY(s) return O.Y + 0.35 + 3.6 * (1 - (s / S) ^ 2) end
		for i = 1, n do
			local s = -S + (i - 0.5) * 2 * S / n
			P(m, Vector3.new(7, 0.7, 2 * S / n + 0.05), fr * CFrame.new(0, deckY(s) - O.Y, s), vary(C.Wood, 0.03), { name = "Plank" })
		end
		for _, e in { -3.3, 3.3 } do
			local prev
			for i = 0, 6 do
				local s = -S + i * 2 * S / 6
				local base = fr * CFrame.new(e, deckY(s) - O.Y, s)
				P(m, Vector3.new(0.6, 2.6, 0.6), base * CFrame.new(0, 1.3, 0), C.Vermilion, { smooth = true, name = "Post" })
				if i == 0 or i == 6 then P(m, Vector3.new(0.9, 0.5, 0.9), base * CFrame.new(0, 2.85, 0), Color3.fromRGB(46, 40, 40), { name = "Cap" }) end
				local topP = (base * CFrame.new(0, 2.3, 0)).Position
				if prev then
					local L = (topP - prev).Magnitude
					P(m, Vector3.new(0.45, 0.45, L), CFrame.lookAt((topP + prev) / 2, topP), C.Vermilion, { smooth = true, name = "Rail" })
				end
				prev = topP
			end
		end
	end
	do
		local m = Instance.new("Model"); m.Name = "Outlet"; m.Parent = Props
		local pos, tan, right = Path.At(Path.Total)
		local hw = Path.WidthAt(Path.Total) / 2
		local fr = frame(Vector3.new(pos.X, O.Y, pos.Z), tan)
		for _, side in { -1, 1 } do P(m, Vector3.new(4, 10, 3.5), fr * CFrame.new(0, 2, side * (hw + 1.5)), vary(C.Stone, 0.04)) end
		P(m, Vector3.new(5, 3, hw * 2 + 7), fr * CFrame.new(0, 7.5, 0), vary(C.StoneLight, 0.04))
		P(m, Vector3.new(1, 9, hw * 2 + 2), fr * CFrame.new(1.8, 1.5, 0), Color3.fromRGB(18, 26, 30), { smooth = true })
		for _ = 1, 5 do boulder(m, (fr * CFrame.new(r(-1, 3), 0, r(-1, 1) * (hw + 6))).Position, r(3, 5), C.Stone) end
	end

	root.WorldPivot = CFrame.new(O)
	root.Parent = workspace
	local count = 0
	for _, x in root:GetDescendants() do if x:IsA("BasePart") then count += 1 end end
	print(("[WaterfallRiver] built: %d parts, river %.0f studs"):format(count, Path.Total))
	tmp:Destroy()
	return root
end
