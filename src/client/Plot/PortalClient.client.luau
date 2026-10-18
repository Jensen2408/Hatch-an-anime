--[[ StarterPlayer.StarterPlayerScripts.PortalClient  (LocalScript)
Draws and animates every Summon Gate (tag "AnimePortal") locally:
  • vortex: stacked glowing layers + counter-rotating energy arcs on both faces of the "Surface" part
  • particles: motes sucked into the vortex, rim sparks, ground mist; a glow pool + lights
  • emerge: surge → the character walks through the surface (each body part fades in exactly as it crosses),
    energy ripple + spark burst at the crossing, rarity-coloured outline that burns off, then a wave.
Needs CharacterAnimator (for the Walk / Wave limbs). Cosmetic only; the server already placed the character.
]]
local RS = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")
local C = require(RS:WaitForChild("Portal"):WaitForChild("PortalConfig"))

local player = Players.LocalPlayer
local TEX_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local TEX_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local WHITE, INK = Color3.new(1, 1, 1), C.Palette.Ink
local portals = {}

local function new(class, props, parent)
	local i = Instance.new(class)
	for k, v in props do i[k] = v end
	i.Parent = parent
	return i
end
local function seq(points)
	local k = {}
	for _, p in points do table.insert(k, NumberSequenceKeypoint.new(p[1], p[2])) end
	return NumberSequence.new(k)
end
local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(x) x = clamp01(x); return x * x * (3 - 2 * x) end
local function reduced() return player:GetAttribute(C.ReducedMotionAttribute) == true end
local function round(f, r) new("UICorner", { CornerRadius = UDim.new(r or 0.5, 0) }, f) end

local function sound(slot, parent, looped)
	local id = C.Sounds[slot]
	if not id or id == "" then return nil end
	local s = new("Sound", { SoundId = id:match("^rbxasset") and id or "rbxassetid://" .. id:gsub("%D", ""),
		Volume = C.Volume, Looped = looped or false, RollOffMaxDistance = 60 }, parent)
	local grp = SoundService:FindFirstChild(C.SoundGroupName)
	if grp and grp:IsA("SoundGroup") then s.SoundGroup = grp end
	return s
end
local function play(s) if s and not player:GetAttribute(C.MuteAttribute) then s:Play() end end

-- ── vortex face ───────────────────────────────────────────────────────────────
local function buildFace(st, face)
	local gui = new("SurfaceGui", { Name = "PortalVortex", Face = face, SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = C.PixelsPerStud, LightInfluence = 0, Brightness = 2.2, ClipsDescendants = true, ZOffset = 0 }, st.surface)
	local root = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, gui)
	local scale = new("UIScale", {}, root)
	table.insert(st.scales, scale)

	-- depth: 9 nested stadiums, dark rim -> bright heart
	for i = 1, 9 do
		local k = (i - 1) / 8
		local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5 + 0.02 * k),
			Size = UDim2.fromScale(1 - k * 0.8, 1 - k * 0.78), BorderSizePixel = 0, BackgroundTransparency = i == 1 and 0.02 or 0.35,
			ZIndex = i }, root)
		round(f)
		table.insert(st.layers, { f = f, k = k })
	end
	-- textured swirl: a CanvasGroup clips rotating images to the stadium (plain frames can't clip rotated children)
	local function img(id) return id ~= "" and (id:match("^rbxasset") and id or "rbxassetid://" .. id:gsub("%D", "")) or nil end
	local swirlId, coreId = img(C.Textures.Swirl), img(C.Textures.Core)
	if swirlId or coreId then
		st.textured = true
		local cg = new("CanvasGroup", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.97, 0.97),
			BackgroundTransparency = 1, ZIndex = 10 }, root)
		round(cg)
		local specs = swirlId and { { swirlId, 1.6, 1, 0 }, { swirlId, 1.05, 0.55, 0.3 } } or {}
		if coreId then table.insert(specs, { coreId, 0.9, 0, 0 }) end
		for i, s in specs do
			local im = new("ImageLabel", { Image = s[1], AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
				Size = UDim2.fromScale(s[2], s[2]), BackgroundTransparency = 1, ImageTransparency = s[4], ZIndex = i, Rotation = i * 40 }, cg)
			new("UIAspectRatioConstraint", { AspectRatio = 1, DominantAxis = Enum.DominantAxis.Height }, im)
			table.insert(st.swirls, { img = im, speed = s[3], core = s[1] == coreId and s[3] == 0 })
		end
	end
	-- energy arcs: rings whose stroke gradient leaves 1–2 bright crescents; inner rings spin faster
	local rng = Random.new(st.seed)
	for i = 1, 8 do
		local k = (i - 1) / 7
		local ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5 + 0.015 * k),
			Size = UDim2.fromScale(0.94 - k * 0.72, 0.95 - k * 0.7), BackgroundTransparency = 1, ZIndex = 20 + i }, root)
		round(ring)
		local stroke = new("UIStroke", { Thickness = math.floor(14 - k * 8), ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Transparency = 0 }, ring)
		local twoArcs = i % 2 == 0
		local grad = new("UIGradient", { Rotation = rng:NextNumber(0, 360),
			Transparency = twoArcs and seq({ { 0, 0 }, { 0.3, 1 }, { 0.7, 1 }, { 1, 0 } }) or seq({ { 0, 0 }, { 0.5, 1 }, { 1, 1 } }) }, stroke)
		local dir = i % 2 == 0 and -1 or 1
		table.insert(st.rings, { stroke = stroke, grad = grad, k = k, speed = dir * (70 + 260 * k) * rng:NextNumber(0.85, 1.15) })
	end
	-- rim + heart
	local rim = new("UIStroke", { Thickness = 10, Transparency = 0 }, st.layers[#st.layers - 8].f)
	table.insert(st.rims, rim)
	local heart = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.2, 0.17), BorderSizePixel = 0, BackgroundColor3 = WHITE, ZIndex = 40 }, root)
	round(heart)
	table.insert(st.hearts, heart)
	return gui, root
end

local function recolor(st, c)
	local dark, light = c:Lerp(INK, 0.72), c:Lerp(WHITE, 0.55)
	for _, L in st.layers do
		L.f.BackgroundColor3 = L.k == 0 and dark or dark:Lerp(c, L.k * 0.9):Lerp(light, math.max(0, L.k - 0.6) * 1.6)
	end
	for _, R in st.rings do R.stroke.Color = c:Lerp(WHITE, 0.25 + 0.55 * R.k) end
	for _, r in st.rims do r.Color = light end
	for _, w in st.swirls do w.img.ImageColor3 = w.core and c:Lerp(WHITE, 0.6) or c:Lerp(WHITE, 0.2) end
	local cs = ColorSequence.new(c:Lerp(WHITE, 0.6), c)
	for _, e in st.emitters do e.Color = cs end
	st.mist.Color = ColorSequence.new(c:Lerp(WHITE, 0.4))
	st.pool.Color = c
	st.point.Color = c; st.slight.Color = c
	if st.highlight then st.highlight.FillColor = light; st.highlight.OutlineColor = c:Lerp(WHITE, 0.3) end
end

-- ── build per portal ──────────────────────────────────────────────────────────
local function add(portal)
	if portals[portal] then return end
	local surface = portal:WaitForChild("Surface", 10)
	if not surface or not portal.Parent then return end
	local st = { portal = portal, surface = surface, layers = {}, rings = {}, rims = {}, hearts = {}, scales = {}, emitters = {}, swirls = {},
		seed = math.random(1, 1e6), color = C.IdleColor, target = C.IdleColor, surge = 0, kick = 0, t = 0, visible = true, ripples = {} }
	portals[portal] = st
	st.front = buildFace(st, Enum.NormalId.Front)
	buildFace(st, Enum.NormalId.Back)

	local fx = new("Folder", { Name = "PortalFXLocal" }, portal)
	st.fx = fx
	local base = portal:GetPivot()
	local cf = surface.CFrame
	local function fxPart(name, size, at)
		return new("Part", { Name = name, Size = size, CFrame = at, Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false,
			Transparency = 1, CastShadow = false }, fx)
	end
	-- motes pulled into the vortex
	local intake = fxPart("Intake", Vector3.new(C.Opening.X + 3, C.Opening.Y + 2, 6), cf)
	st.intake = new("ParticleEmitter", { Texture = TEX_SPARK, Rate = 18, Lifetime = NumberRange.new(1.0, 1.4), Speed = NumberRange.new(3, 5),
		Shape = Enum.ParticleEmitterShape.Box, ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume, ShapeInOut = Enum.ParticleEmitterShapeInOut.Inward,
		Size = seq({ { 0, 0.05 }, { 0.3, 0.35 }, { 1, 0 } }), Transparency = seq({ { 0, 1 }, { 0.2, 0 }, { 1, 0.4 } }),
		LightEmission = 1, Drag = 0.6, Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-180, 180) }, intake)
	-- sparks shed from the surface
	st.sparks = new("ParticleEmitter", { Texture = TEX_SPARK, Rate = 10, Lifetime = NumberRange.new(0.6, 1.1), Speed = NumberRange.new(0.6, 2),
		Shape = Enum.ParticleEmitterShape.Box, ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward, SpreadAngle = Vector2.new(30, 30),
		Size = seq({ { 0, 0.25 }, { 1, 0 } }), Transparency = seq({ { 0, 0 }, { 1, 1 } }), LightEmission = 1, Acceleration = Vector3.new(0, 1.5, 0) }, surface)
	-- burst used at the crossing (moved to the character's chest)
	local burstAt = new("Attachment", { Name = "BurstAt" }, surface)
	st.burstAt = burstAt
	st.burst = new("ParticleEmitter", { Texture = TEX_SPARK, Rate = 0, Lifetime = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(6, 13),
		SpreadAngle = Vector2.new(75, 75), EmissionDirection = Enum.NormalId.Front, Drag = 3, Size = seq({ { 0, 0.5 }, { 1, 0 } }),
		Transparency = seq({ { 0, 0 }, { 1, 1 } }), LightEmission = 1, Rotation = NumberRange.new(0, 360) }, burstAt)
	st.emitters = { st.intake, st.sparks, st.burst }
	-- ground mist spilling out of the gate
	local mistPad = fxPart("Mist", Vector3.new(7.5, 0.2, 3), base * CFrame.new(0, C.GroundY + 0.15, -1.6))
	st.mist = new("ParticleEmitter", { Texture = TEX_SMOKE, Rate = 7, Lifetime = NumberRange.new(2.5, 4), Speed = NumberRange.new(0.3, 0.8),
		EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0, 0.15, 0), Size = seq({ { 0, 1.5 }, { 1, 4.5 } }),
		Transparency = seq({ { 0, 1 }, { 0.3, 0.82 }, { 1, 1 } }), LightEmission = 0.5, Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-20, 20) }, mistPad)
	-- glow pool on the slab + lights
	st.pool = new("Part", { Name = "GlowPool", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.04, 8, 8), Material = Enum.Material.Neon,
		CFrame = base * CFrame.new(0, C.GroundY + 0.02, -1.4) * CFrame.Angles(0, 0, math.pi / 2), Transparency = 0.8,
		Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, CastShadow = false }, fx)
	local lightAt = new("Attachment", { Position = Vector3.new(0, 0, -2.5) }, surface)
	st.point = new("PointLight", { Range = 20, Brightness = 1.6, Shadows = true }, lightAt)
	st.slight = new("SurfaceLight", { Face = Enum.NormalId.Front, Range = 16, Angle = 80, Brightness = 1.2 }, surface)
	st.hum = sound("Hum", surface, true); play(st.hum)
	st.sSurge = sound("Surge", surface); st.sWhoosh = sound("Whoosh", surface); st.sArrive = sound("Arrive", surface)

	recolor(st, st.color)
	portal:GetAttributeChangedSignal("EmergeToken"):Connect(function() st.pending = true end)
	if portal:GetAttribute("EmergeToken") then st.pending = true end
	portal.AncestryChanged:Connect(function() if not portal:IsDescendantOf(workspace) then portals[portal] = nil end end)
	print("[Portal] vortex drawn on " .. portal:GetFullName() .. (st.textured and " (textured)" or " (no textures set: ring fallback)"))
end

-- ── emerge ────────────────────────────────────────────────────────────────────
local function feetOrigin(model)
	local cf, size = model:GetBoundingBox()
	return CFrame.new(cf.Position - Vector3.new(0, size.Y / 2, 0)) * cf.Rotation
end

local function endEmerge(st)
	local e = st.emerge; if not e then return end
	st.emerge = nil
	if e.model.Parent then
		for _, p in e.parts do p.LocalTransparencyModifier = 0 end
		e.model:PivotTo(e.final)
		e.model:SetAttribute("Animation", e.prevAnim)
	end
	if st.highlight then st.highlight:Destroy(); st.highlight = nil end
	st.target = C.IdleColor
end

local function startEmerge(st)
	st.pending = false
	endEmerge(st)
	local portal = st.portal
	local start, token = portal:GetAttribute("EmergeStart"), portal:GetAttribute("EmergeToken")
	if not (start and token) then return end
	if workspace:GetServerTimeNow() - start > C.Total() then return end
	local ref = portal:WaitForChild("EmergeTarget", 3)
	local t0 = os.clock()
	while ref and not ref.Value and os.clock() - t0 < 3 do task.wait() end
	local model = ref and ref.Value
	if not model or portal:GetAttribute("EmergeToken") ~= token then return end
	while model.Parent and not model:FindFirstChild("Torso", true) and os.clock() - t0 < 3 do task.wait() end

	local parts = {}
	for _, d in model:GetDescendants() do if d:IsA("BasePart") then table.insert(parts, d); d.LocalTransparencyModifier = 1 end end
	local final = model:GetPivot()
	local feet = feetOrigin(model)
	st.emerge = { model = model, parts = parts, start = start, final = final, feet = feet, offset = feet:ToObjectSpace(final),
		prevAnim = model:GetAttribute("Animation") or C.EndAnimation, chest = model:FindFirstChild("Torso", true), phase = 0 }
	st.target = C.Color(portal:GetAttribute("EmergeRarity"))
	st.highlight = new("Highlight", { Adornee = model, DepthMode = Enum.HighlightDepthMode.Occluded, FillTransparency = 1, OutlineTransparency = 1, Enabled = false }, st.fx)
	play(st.sSurge)
end

local function ripple(st, worldPos)
	if not st.front then return end
	local lp = st.surface.CFrame:PointToObjectSpace(worldPos)
	local u, v = 0.5 - lp.X / C.Opening.X, 0.5 - lp.Y / C.Opening.Y
	local root = st.front:FindFirstChildOfClass("Frame")
	local r = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(u, v), Size = UDim2.fromScale(0.1, 0.085),
		BackgroundTransparency = 1, ZIndex = 50 }, root)
	round(r)
	local s = new("UIStroke", { Thickness = 18, Color = st.color:Lerp(WHITE, 0.7), Transparency = 0 }, r)
	local info = TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(r, info, { Size = UDim2.fromScale(1.2, 1.0) }):Play()
	TweenService:Create(s, info, { Transparency = 1, Thickness = 2 }):Play()
	task.delay(0.75, function() r:Destroy() end)
end

local function stepEmerge(st)
	local e = st.emerge
	if not e.model.Parent then endEmerge(st) return end
	local t = workspace:GetServerTimeNow() - e.start
	local walkT = C.WalkTime()
	local dist = C.StartBehind + C.WalkOut
	if t >= C.Total() then endEmerge(st) return end

	if t < C.Surge then
		st.surge = smooth(t / C.Surge)
		for _, p in e.parts do p.LocalTransparencyModifier = 1 end
		e.model:PivotTo(e.feet * CFrame.new(0, 0, dist) * e.offset)
		return
	end
	if e.phase == 0 then e.phase = 1; e.model:SetAttribute("Animation", "Walk") end

	local u = clamp01((t - C.Surge) / walkT)
	local along = u < 0.85 and u or 0.85 + (1 - (1 - (u - 0.85) / 0.15) ^ 2) * 0.15 -- ease out the last steps
	e.model:PivotTo(e.feet * CFrame.new(0, 0, (1 - along) * dist) * e.offset)

	local n, o = st.surface.CFrame.LookVector, st.surface.Position
	local out = 1
	for _, p in e.parts do
		local d = (p.Position - o):Dot(n)
		local hide = clamp01(0.5 - d / C.FadeBand)
		p.LocalTransparencyModifier = hide
		out = math.min(out, 1 - hide)
	end
	local chestD = e.chest and (e.chest.Position - o):Dot(n) or -1
	if e.phase == 1 and chestD > 0 then
		e.phase = 2
		st.kick = 1
		st.highlight.Enabled = true
		st.burstAt.WorldPosition = e.chest.Position
		st.burst:Emit(reduced() and 14 or 30)
		ripple(st, e.chest.Position)
		play(st.sWhoosh)
	end
	if e.phase >= 2 then
		if out >= 1 and not e.outAt then e.outAt = t end
		local g = e.outAt and clamp01((t - e.outAt) / C.GlowFade) or 0
		st.highlight.FillTransparency = 0.35 + 0.65 * g
		st.highlight.OutlineTransparency = g
	end
	if u >= 1 and e.phase < 3 then
		e.phase = 3
		e.model:SetAttribute("Animation", "Wave")
		st.target = C.IdleColor:Lerp(st.target, 0.5)
		play(st.sArrive)
	end
	st.surge = e.phase == 3 and math.max(0, 1 - (t - C.Surge - walkT) / 1.2) or 1
end

-- ── per frame ─────────────────────────────────────────────────────────────────
RunService.RenderStepped:Connect(function(dt)
	local cam = workspace.CurrentCamera
	local camPos = cam and cam.CFrame.Position or Vector3.zero
	local rm = reduced()
	for portal, st in portals do
		if not portal.Parent then portals[portal] = nil continue end
		if st.pending then task.spawn(startEmerge, st) st.pending = false end
		if st.emerge then stepEmerge(st) elseif st.surge > 0 then st.surge = math.max(0, st.surge - dt) end

		local near = (st.surface.Position - camPos).Magnitude < C.EffectsDistance
		if near ~= st.visible then
			st.visible = near
			for _, em in st.emitters do em.Enabled = near and em ~= st.burst end
			st.mist.Enabled = near
		end
		if not near and not st.emerge then continue end

		st.t += dt
		local s, t = st.surge, st.t
		st.kick = math.max(0, st.kick - dt * 3)
		-- colour
		if (st.color.R - st.target.R) ^ 2 + (st.color.G - st.target.G) ^ 2 + (st.color.B - st.target.B) ^ 2 > 1e-5 then
			st.color = st.color:Lerp(st.target, 1 - math.exp(-dt * 3.5))
			recolor(st, st.color)
		end
		-- spin + breathe
		local spin = dt * (1 + 2.2 * s) * (rm and 0.5 or 1)
		for _, R in st.rings do
			R.grad.Rotation = (R.grad.Rotation + R.speed * spin) % 360
			R.stroke.Transparency = math.min(1, 0.15 + 0.25 * (0.5 + 0.5 * math.sin(t * 2 + R.k * 6)) - 0.15 * s + (st.textured and 0.45 or 0))
		end
		local deg = C.SwirlSpeed * dt * (1 + 2.4 * s) * (rm and 0.5 or 1)
		for _, w in st.swirls do
			if w.core then w.img.ImageTransparency = clamp01(0.25 - 0.25 * s - 0.1 * math.sin(t * 3.1))
			else w.img.Rotation = (w.img.Rotation - deg * w.speed) % 360 end
		end
		local breathe = 1 + 0.012 * math.sin(t * 1.7) + 0.04 * s + 0.06 * st.kick * (rm and 0.5 or 1)
		for _, sc in st.scales do sc.Scale = breathe end
		for _, h in st.hearts do
			h.BackgroundTransparency = clamp01(0.25 + 0.12 * math.sin(t * 3.1) - 0.25 * s)
			h.Size = UDim2.fromScale(0.2 + 0.08 * s + 0.02 * math.sin(t * 2.3), 0.17 + 0.07 * s + 0.02 * math.sin(t * 2.3))
		end
		for _, r in st.rims do r.Thickness = 9 + 3 * math.sin(t * 2.6) + 8 * s end
		st.point.Brightness = 1.5 + 0.3 * math.sin(t * 2.3) + 2.8 * s + 2 * st.kick
		st.slight.Brightness = 1.1 + 1.8 * s
		st.pool.Transparency = 0.82 - 0.25 * s - 0.04 * math.sin(t * 2.3)
		st.intake.Rate = (rm and 0.5 or 1) * (16 + 50 * s)
		st.sparks.Rate = (rm and 0.5 or 1) * (8 + 24 * s)
		if st.hum then st.hum.PlaybackSpeed = 1 + 0.25 * s end
	end
end)

print("[Portal] client running, " .. #CollectionService:GetTagged(C.Tag) .. " portal(s) found so far")
for _, p in CollectionService:GetTagged(C.Tag) do task.spawn(add, p) end
CollectionService:GetInstanceAddedSignal(C.Tag):Connect(function(p) task.spawn(add, p) end)
