--!strict
--[[ ReplicatedStorage.AnimeFX (ModuleScript, client)
Plays a character's ability VFX from the Blender-made kit in ReplicatedStorage.AnimeVFXKit:
  Meshes  : Slash, Ring, Twister, Beam, Aura, Orb, Bolt, Crystal, Spikes, Wind (UV'd for scrolling textures)
  Textures: attributes on AnimeVFXKit.Textures (slash, ring, energy, aura, glow, spark, smoke, lightning, flame_flipbook)
Every effect is local-only, tweened, and cleans itself up.
  AnimeFX.play(name, rootCF, handCF, color)   -- rootCF = character root (front = -LookVector... we use rootCF.LookVector)
]]
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local AnimeFX = {}

local KIT = ReplicatedStorage:WaitForChild("AnimeVFXKit", 10)
local MESH = KIT and KIT:FindFirstChild("Meshes")
local TEXT = KIT and KIT:FindFirstChild("Textures")
local function tex(n: string): string return TEXT and (TEXT:GetAttribute(n) :: string?) or "" end

local FOLDER = workspace:FindFirstChild("_AnimeFX") or Instance.new("Folder")
FOLDER.Name = "_AnimeFX"; FOLDER.Parent = workspace

-- canonical orientation of each kit mesh (as imported) -> "flat on the ground" / "upright" / "facing forward"
local UPRIGHT = CFrame.Angles(-math.pi / 2, 0, 0)     -- meshes modelled along +Z become vertical (+Y)
local FLAT = CFrame.Angles(math.pi / 2, 0, 0)         -- XY-plane meshes lie on the ground

local function tween(i: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local tw = TweenService:Create(i, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props)
	tw:Play(); return tw
end

-- textured, glowing copy of a kit mesh
local function mesh(name: string, cf: CFrame, size: number, color: Color3, texName: string?, life: number): MeshPart?
	local src = MESH and MESH:FindFirstChild(name) :: MeshPart?
	if not src then return nil end
	local p = src:Clone()
	p.Size = (src:GetAttribute("BaseSize") :: Vector3) * size
	p.CFrame = cf; p.Color = color; p.Material = Enum.Material.Neon; p.Transparency = 0.15
	if texName then
		p.Material = Enum.Material.SmoothPlastic
		local sa = Instance.new("SurfaceAppearance")
		sa.AlphaMode = Enum.AlphaMode.Transparency
		pcall(function() sa.ColorMap = tex(texName) end)
		pcall(function() (sa :: any).Color = color end)
		pcall(function() (sa :: any).EmissiveMaskContent = Content.fromUri(tex(texName)); (sa :: any).EmissiveStrength = 4; (sa :: any).EmissiveTint = color end)
		sa.Parent = p
	end
	p.Parent = FOLDER
	Debris:AddItem(p, life + 0.2)
	return p
end

-- upright meshes (height along local Z) are centred on their CFrame: lift them so they stand on the ground
local function standUp(p: BasePart?)
	if p then p.CFrame = p.CFrame * CFrame.new(0, 0, p.Size.Z / 2) end -- UPRIGHT maps local +Z to world up
end

local function attach(cf: CFrame): Attachment
	local a = Instance.new("Part")
	a.Size = Vector3.one * 0.2; a.Transparency = 1; a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.CanTouch = false
	a.CFrame = cf; a.Parent = FOLDER
	Debris:AddItem(a, 4)
	local at = Instance.new("Attachment"); at.Parent = a
	return at
end

local function ns(t: { { number } }): NumberSequence
	local k = {}
	for i, v in t do k[i] = NumberSequenceKeypoint.new(v[1], v[2]) end
	return NumberSequence.new(k)
end

local function particles(at: Attachment, texName: string, color: Color3, n: number, p: { [string]: any })
	local e = Instance.new("ParticleEmitter")
	e.Texture = tex(texName); e.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	e.LightEmission = p.glow or 1; e.LightInfluence = 0; e.Rate = 0
	e.Speed = p.speed or NumberRange.new(10, 22); e.Drag = p.drag or 3
	e.SpreadAngle = p.spread or Vector2.new(180, 180); e.Lifetime = p.life or NumberRange.new(0.4, 0.8)
	e.Size = p.size or ns({ { 0, 1 }, { 1, 0 } }); e.Transparency = p.tr or ns({ { 0, 0 }, { 0.7, 0.2 }, { 1, 1 } })
	e.Rotation = NumberRange.new(0, 360); e.RotSpeed = p.rot or NumberRange.new(-180, 180)
	e.Acceleration = p.acc or Vector3.zero; e.ZOffset = p.z or 0
	if p.flip then e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4; e.FlipbookMode = Enum.ParticleFlipbookMode.OneShot end
	if p.shape then e.Shape = p.shape; e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume end
	e.Parent = at
	e:Emit(n)
end

local function light(cf: CFrame, color: Color3, range: number, bright: number, life: number)
	local at = attach(cf)
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range; l.Brightness = bright; l.Parent = at.Parent
	tween(l, life, { Brightness = 0 })
end

-- scroll a SurfaceAppearance-free alternative: spin/rise the mesh instead (SA textures can't offset)
local function spin(p: BasePart, axis: Vector3, speed: number, life: number)
	local t0 = os.clock(); local base = p.CFrame
	local c; c = RunService.Heartbeat:Connect(function()
		if not p.Parent then c:Disconnect() return end
		local t = os.clock() - t0
		if t > life then c:Disconnect() return end
		p.CFrame = base * CFrame.fromAxisAngle(axis, speed * t)
	end)
end

---------------------------------------------------------------------------- building blocks
local E = {}

function E.slash(root: CFrame, hand: CFrame, c: Color3, n: number?)
	for i = 1, (n or 2) do
		local tilt = (i % 2 == 0) and 0.6 or -0.5
		local cf = root * CFrame.new(0, 1.5, -2.5) * CFrame.Angles(0, 0, tilt) * CFrame.Angles(0, 0, -1.2)
		local core = mesh("Slash", cf, 0.55, Color3.new(1, 1, 1), nil, 0.5)
		local glow = mesh("Slash", cf, 0.62, c, "slash", 0.6)
		for _, p in { core, glow } do
			if p then
				p.Transparency = p == core and 0.35 or 0
				tween(p, 0.22, { CFrame = cf * CFrame.Angles(0, 0, 2.4) }, Enum.EasingStyle.Quart)
				tween(p, 0.5, { Transparency = 1, Size = p.Size * 1.35 }, Enum.EasingStyle.Quad)
			end
		end
		task.wait(0.09)
	end
	particles(attach(root * CFrame.new(0, 1.5, -2.5)), "spark", c, 40, { speed = NumberRange.new(20, 40), spread = Vector2.new(100, 15) })
end

function E.orb(root: CFrame, hand: CFrame, c: Color3, size: number?)
	local s = size or 1.6
	local core = mesh("Orb", hand, s * 0.55, Color3.new(1, 1, 1), nil, 1.2)
	local shell = mesh("Orb", hand, s, c, "energy", 1.2)
	local ring1 = mesh("Ring", hand * CFrame.Angles(0.4, 0, 0), s * 0.9, c, "ring", 1.2)
	local ring2 = mesh("Ring", hand * CFrame.Angles(-0.6, 1.2, 0), s * 0.8, c, "ring", 1.2)
	for _, p in { core, shell, ring1, ring2 } do
		if p then
			local big = p.Size
			p.Size = big * 0.2
			tween(p, 0.35, { Size = big }, Enum.EasingStyle.Back)
			task.delay(0.8, function() if p.Parent then tween(p, 0.35, { Transparency = 1, Size = big * 1.6 }) end end)
		end
	end
	if ring1 then spin(ring1, Vector3.zAxis, 10, 1.2) end
	if ring2 then spin(ring2, Vector3.zAxis, -12, 1.2) end
	local at = attach(hand)
	particles(at, "spark", c, 30, { speed = NumberRange.new(-8, -4), shape = Enum.ParticleEmitterShape.Sphere, life = NumberRange.new(0.3, 0.6) })
	light(hand, c, 18, 6, 1.1)
end

function E.beam(root: CFrame, hand: CFrame, c: Color3, w: number?)
	local width = w or 2.2
	local dir = root * CFrame.new(0, 0, 0)
	local start = CFrame.new(hand.Position) * (dir - dir.Position) * CFrame.Angles(-math.pi / 2, 0, 0)
	local outer = mesh("Beam", start, 1, c, "energy", 1.2)
	local core = mesh("Beam", start, 1, Color3.new(1, 1, 1), nil, 1.2)
	for _, p in { outer, core } do
		if p then
			local thick = p == core and width * 0.45 or width
			-- the tube's local +Y now points forward (-Z of the character): grow it out from the hand
			p.Size = Vector3.new(thick, 0.1, thick)
			p.CFrame = start * CFrame.new(0, 0.05, 0)
			tween(p, 0.25, { Size = Vector3.new(thick, 40, thick), CFrame = start * CFrame.new(0, 20, 0) }, Enum.EasingStyle.Quart)
			task.delay(0.75, function() if p.Parent then tween(p, 0.4, { Size = Vector3.new(0.05, 40, 0.05), Transparency = 1 }) end end)
		end
	end
	E.orb(root, hand, c, width * 0.9)
	particles(attach(hand), "smoke", c, 12, { speed = NumberRange.new(4, 9), size = ns({ { 0, 1.5 }, { 1, 5 } }), glow = 0.4, life = NumberRange.new(0.8, 1.3) })
end

function E.shockwave(root: CFrame, hand: CFrame, c: Color3, size: number?)
	local s = size or 6
	local ground = root * CFrame.new(0, -2.4, 0) * FLAT
	for i, d in { 0, 0.12 } do
		task.delay(d, function()
			local r = mesh("Ring", ground, 1, c, "ring", 0.8)
			if r then
				local base = r.Size
				r.Size = base * 0.5
				tween(r, 0.7, { Size = base * s * (1 + i * 0.4), Transparency = 1 }, Enum.EasingStyle.Quart)
			end
		end)
	end
	particles(attach(root * CFrame.new(0, -2.3, 0)), "smoke", Color3.fromRGB(230, 220, 200), 20,
		{ speed = NumberRange.new(14, 24), spread = Vector2.new(5, 180), size = ns({ { 0, 1.5 }, { 1, 4 } }), glow = 0, life = NumberRange.new(0.6, 1) })
end

function E.aura(root: CFrame, hand: CFrame, c: Color3)
	local base = root * CFrame.new(0, -2.5, 0) * UPRIGHT
	local outer = mesh("Aura", base, 5, c, "aura", 1.6)
	local inner = mesh("Aura", base, 4, Color3.new(1, 1, 1), "aura", 1.6)
	standUp(outer); standUp(inner)
	for _, p in { outer, inner } do
		if p then
			local big = p.Size
			p.Size = Vector3.new(big.X, big.Y, big.Z * 0.2)
			tween(p, 0.3, { Size = big }, Enum.EasingStyle.Back)
			task.delay(1.0, function() if p.Parent then tween(p, 0.5, { Transparency = 1 }) end end)
			spin(p, Vector3.zAxis, p == outer and 3 or -4, 1.6)
		end
	end
	particles(attach(root * CFrame.new(0, -1.5, 0)), "spark", c, 50,
		{ speed = NumberRange.new(2, 5), acc = Vector3.new(0, 18, 0), shape = Enum.ParticleEmitterShape.Cylinder, life = NumberRange.new(0.6, 1.2) })
	light(root, c, 20, 5, 1.5)
end

function E.twister(root: CFrame, hand: CFrame, c: Color3)
	local cf = root * CFrame.new(0, -2.5, 0) * UPRIGHT
	local t = mesh("Twister", cf, 1, c, "energy", 1.4)
	standUp(t)
	if t then
		local big = t.Size
		t.Size = Vector3.new(big.X, big.Y, big.Z * 0.1)
		tween(t, 0.35, { Size = big }, Enum.EasingStyle.Quart)
		spin(t, Vector3.zAxis, 9, 1.4)
		task.delay(0.9, function() if t.Parent then tween(t, 0.45, { Transparency = 1 }) end end)
	end
end

function E.fire(root: CFrame, hand: CFrame, c: Color3)
	local at = attach(hand * CFrame.new(0, 0.5, 0))
	particles(at, "flame_flipbook", c, 28, { flip = true, speed = NumberRange.new(6, 14), spread = Vector2.new(25, 25), acc = Vector3.new(0, 14, 0),
		size = ns({ { 0, 2 }, { 0.5, 3.5 }, { 1, 1 } }), life = NumberRange.new(0.5, 0.8), rot = NumberRange.new(-30, 30) })
	particles(at, "spark", Color3.fromRGB(255, 220, 120), 30, { speed = NumberRange.new(12, 26), acc = Vector3.new(0, 10, 0) })
	particles(at, "smoke", Color3.fromRGB(60, 40, 40), 10, { glow = 0, speed = NumberRange.new(3, 6), acc = Vector3.new(0, 8, 0),
		size = ns({ { 0, 1.5 }, { 1, 6 } }), life = NumberRange.new(1, 1.6) })
	light(hand, c, 22, 7, 1)
end

function E.lightning(root: CFrame, hand: CFrame, c: Color3)
	for i = 1, 4 do
		local a = math.rad(i * 90 + math.random(-20, 20))
		local cf = root * CFrame.new(math.cos(a) * 2.2, 1, math.sin(a) * 2.2) * CFrame.Angles(math.random() * 0.6, a, math.random() * 0.6)
		local b = mesh("Bolt", cf, 0.7 + math.random() * 0.4, c, nil, 0.35)
		if b then b.Transparency = 0; task.delay(0.05, function() if b.Parent then tween(b, 0.25, { Transparency = 1 }) end end) end
		task.wait(0.04)
	end
	particles(attach(hand), "lightning", c, 18, { speed = NumberRange.new(0, 2), size = ns({ { 0, 4 }, { 1, 3 } }), life = NumberRange.new(0.08, 0.16), rot = NumberRange.new(0, 0) })
	particles(attach(hand), "spark", c, 50, { speed = NumberRange.new(30, 55), drag = 8, life = NumberRange.new(0.1, 0.25) })
	light(hand, c, 24, 9, 0.5)
end

function E.ice(root: CFrame, hand: CFrame, c: Color3)
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2
		local cf = root * CFrame.new(math.cos(a) * 3, -2.4, math.sin(a) * 3) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-20), 0, 0) * UPRIGHT
		local s = mesh("Crystal", cf, 1 + (i % 3) * 0.6, c, nil, 1.6)
		if s then
			s.Material = Enum.Material.Glass; s.Transparency = 0.2
			local big = s.Size; s.Size = big * 0.1
			tween(s, 0.25, { Size = big }, Enum.EasingStyle.Back)
			task.delay(1.1, function() if s.Parent then tween(s, 0.4, { Transparency = 1, Size = big * 0.6 }) end end)
		end
	end
	particles(attach(root), "smoke", c, 14, { glow = 0.3, speed = NumberRange.new(2, 5), size = ns({ { 0, 2 }, { 1, 6 } }), life = NumberRange.new(1, 1.6) })
	particles(attach(root), "spark", Color3.new(1, 1, 1), 30, { speed = NumberRange.new(4, 10), acc = Vector3.new(0, -4, 0) })
end

function E.spikes(root: CFrame, hand: CFrame, c: Color3)
	local s = mesh("Spikes", hand, 1.5, c, nil, 0.6)
	if s then
		local big = s.Size; s.Size = big * 0.2
		tween(s, 0.15, { Size = big * 2.2 }, Enum.EasingStyle.Quart)
		task.delay(0.15, function() if s.Parent then tween(s, 0.4, { Transparency = 1 }) end end)
		spin(s, Vector3.zAxis, 6, 0.6)
	end
end

function E.wind(root: CFrame, hand: CFrame, c: Color3)
	for i = 1, 3 do
		local cf = root * CFrame.new(0, -1 + i, 0) * CFrame.Angles(0, i * 2.1, 0)
		local w = mesh("Wind", cf, 1.2, c, "energy", 0.9)
		if w then spin(w, Vector3.yAxis, 8, 0.9); tween(w, 0.9, { Transparency = 1, Size = w.Size * 1.8 }) end
	end
end

function E.petals(root: CFrame, hand: CFrame, c: Color3)
	particles(attach(root * CFrame.new(0, 2, 0)), "spark", c, 80, { glow = 0.5, speed = NumberRange.new(8, 16), drag = 1.5, acc = Vector3.new(0, -3, 0),
		size = ns({ { 0, 0.5 }, { 1, 0.3 } }), life = NumberRange.new(1.2, 2), shape = Enum.ParticleEmitterShape.Sphere })
end

function E.dark(root: CFrame, hand: CFrame, c: Color3)
	particles(attach(root * CFrame.new(0, -1, 0)), "smoke", c, 30, { glow = 0, speed = NumberRange.new(2, 6), acc = Vector3.new(0, 6, 0),
		size = ns({ { 0, 2 }, { 1, 7 } }), tr = ns({ { 0, 0.1 }, { 1, 1 } }), life = NumberRange.new(1, 1.6), shape = Enum.ParticleEmitterShape.Cylinder })
end

function E.stars(root: CFrame, hand: CFrame, c: Color3)
	particles(attach(root * CFrame.new(0, 2, 0)), "spark", c, 50, { speed = NumberRange.new(3, 8), size = ns({ { 0, 0 }, { 0.2, 1.4 }, { 1, 0 } }),
		life = NumberRange.new(0.8, 1.4), shape = Enum.ParticleEmitterShape.Sphere })
	light(root, c, 18, 4, 1.2)
end

-- the impact every move shares: white flash orb + colored burst + light
function E.hit(root: CFrame, hand: CFrame, c: Color3)
	local f = mesh("Orb", hand, 1.2, Color3.new(1, 1, 1), nil, 0.35)
	if f then tween(f, 0.3, { Size = f.Size * 4, Transparency = 1 }, Enum.EasingStyle.Quint) end
	particles(attach(hand), "glow", c, 6, { speed = NumberRange.new(0, 1), size = ns({ { 0, 3 }, { 1, 7 } }), life = NumberRange.new(0.25, 0.35) })
	particles(attach(hand), "spark", c, 40, { speed = NumberRange.new(18, 34) })
	light(hand, c, 22, 8, 0.6)
end

---------------------------------------------------------------------------- who uses what
local R: { [string]: { { any } } } = {
	Luffy = { { "aura" }, { "shockwave", 7 }, { "stars" } }, Zoro = { { "slash", 3 }, { "dark" } }, Nami = { { "lightning" }, { "dark" } },
	Naruto = { { "orb", 1.8 }, { "aura" } }, Sasuke = { { "lightning" }, { "orb", 1.2 } }, Kakashi = { { "lightning" }, { "orb", 1 } },
	Goku = { { "beam", 2.6 }, { "aura" } }, Vegeta = { { "beam", 3 }, { "aura" } }, Piccolo = { { "beam", 0.8 }, { "twister" } },
	Saitama = { { "shockwave", 12 }, { "wind" }, { "spikes" } }, Genos = { { "fire" }, { "beam", 1.6 } }, Tatsumaki = { { "twister" }, { "shockwave", 8 } },
	Tanjiro = { { "slash", 2 }, { "wind" }, { "fire" } }, Nezuko = { { "fire" }, { "petals" } }, Zenitsu = { { "lightning" }, { "slash", 1 } },
	Gojo = { { "orb", 2.6 }, { "twister" } }, Itadori = { { "lightning" }, { "spikes" }, { "shockwave", 6 } }, Sukuna = { { "slash", 4 }, { "fire" } },
	Ichigo = { { "slash", 2 }, { "dark" }, { "aura" } }, Rukia = { { "ice" } }, Byakuya = { { "petals" }, { "twister" } },
	Eren = { { "lightning" }, { "shockwave", 10 } }, Levi = { { "slash", 4 }, { "wind" } }, Mikasa = { { "slash", 3 }, { "wind" } },
	Asta = { { "dark" }, { "aura" }, { "slash", 1 } }, Yuno = { { "wind" }, { "twister" } }, Noelle = { { "orb", 1.8 }, { "twister" } },
	Deku = { { "lightning" }, { "aura" }, { "shockwave", 8 } }, Bakugo = { { "fire" }, { "spikes" }, { "shockwave", 9 } }, Todoroki = { { "ice" }, { "fire" } },
	Denji = { { "slash", 2 }, { "fire" } }, Power = { { "spikes" }, { "slash", 2 } }, Makima = { { "dark" }, { "shockwave", 5 } },
	Natsu = { { "fire" }, { "beam", 1.4 } }, Lucy = { { "stars" }, { "petals" } }, Erza = { { "slash", 4 }, { "stars" } },
	Hinata = { { "wind" }, { "shockwave", 5 } }, Isagi = { { "aura" }, { "stars" } }, Kuroko = { { "aura" }, { "wind" } },
	Shinji = { { "shockwave", 7 }, { "aura" } }, Asuka = { { "aura" }, { "fire" } }, Lelouch = { { "dark" }, { "stars" } },
	["Sun God"] = { { "orb", 2.8 }, { "fire" }, { "aura" } }, ["Moon Goddess"] = { { "orb", 2.2 }, { "stars" } }, ["Cosmic Oracle"] = { { "stars" }, { "twister" }, { "shockwave", 9 } },
}

function AnimeFX.play(name: string, root: CFrame, hand: CFrame, color: Color3)
	if not KIT then return end
	task.spawn(E.hit, root, hand, color)
	for _, step in R[name] or { { "aura" } } do
		local f = E[step[1]]
		if f then task.spawn(f, root, hand, color, step[2]) end
	end
end

return AnimeFX
