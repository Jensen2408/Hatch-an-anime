--[[ StarterPlayerScripts.AnimeIdle (LocalScript)
Brings every anime character in Workspace (tag "AnimeIdle") to life, client-side only:
  * base   = the character's signature pose (ReplicatedStorage.AnimePoses), the rig itself stands neutral
  * idle   = a per-character style layered on top (bouncy / stoic / fighter / cute / float) with
             follow-through: the head, arms and forearms lag a little behind the body
  * power  = every 8-15 s a signature move blends in from the base pose (never stacked on it):
             wind-up -> charge glow -> hit (flash, shockwave, burst, light) -> ability VFX -> settle
Only characters within IDLE_DISTANCE of the camera animate. Nothing replicates.
]]
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local IDLE_DISTANCE = 120
local TAG = "AnimeIdle"
local POWER_TIME = 2.8
local rad, sin, clamp = math.rad, math.sin, math.clamp
local ID = CFrame.identity
local FLIP = CFrame.Angles(0, math.pi, 0)

local POSES = {}
do
	local m = ReplicatedStorage:FindFirstChild("AnimePoses")
	if m then local ok, t = pcall(require, m); if ok then POSES = t end end
end
local AnimeFX = nil
do
	local m = ReplicatedStorage:FindFirstChild("AnimeFX")
	if m then local ok, t = pcall(require, m); if ok then AnimeFX = t end end
end

-- idle: bouncy | stoic | fighter | cute | float     power: fistUp | charge | thrust | slash | spin | rise
-- color: main glow colour of the power-up
local STYLE = {
	Luffy = { "bouncy", "fistUp", "FFFFFF" }, Zoro = { "stoic", "slash", "4DFF7A" }, Nami = { "cute", "fistUp", "FFD23F" },
	Naruto = { "bouncy", "thrust", "3FA9FF" }, Sasuke = { "stoic", "thrust", "8FD0FF" }, Kakashi = { "stoic", "thrust", "BFE6FF" },
	Goku = { "fighter", "charge", "FFD23F" }, Vegeta = { "stoic", "charge", "3FA9FF" }, Piccolo = { "stoic", "thrust", "FFE066" },
	Saitama = { "stoic", "thrust", "FFFFFF" }, Genos = { "fighter", "thrust", "FF8A1F" }, Tatsumaki = { "float", "spin", "4DFF7A" },
	Tanjiro = { "fighter", "slash", "3FA9FF" }, Nezuko = { "cute", "spin", "FF5FA2" }, Zenitsu = { "cute", "slash", "FFD23F" },
	Gojo = { "stoic", "thrust", "B44DFF" }, Itadori = { "bouncy", "thrust", "FF3B3B" }, Sukuna = { "stoic", "slash", "FF3B3B" },
	Ichigo = { "fighter", "charge", "FF3B3B" }, Rukia = { "cute", "slash", "DFF4FF" }, Byakuya = { "stoic", "rise", "FF9EC4" },
	Eren = { "fighter", "charge", "FFE066" }, Levi = { "stoic", "spin", "D9E2EC" }, Mikasa = { "fighter", "slash", "FF3B3B" },
	Asta = { "bouncy", "charge", "5A5A5A" }, Yuno = { "float", "rise", "4DFF7A" }, Noelle = { "cute", "fistUp", "3FA9FF" },
	Deku = { "bouncy", "charge", "4DFF7A" }, Bakugo = { "fighter", "fistUp", "FF8A1F" }, Todoroki = { "stoic", "thrust", "8FD0FF" },
	Denji = { "bouncy", "slash", "FF8A1F" }, Power = { "fighter", "slash", "FF3B3B" }, Makima = { "stoic", "rise", "FF3B3B" },
	Natsu = { "bouncy", "fistUp", "FF5A1F" }, Lucy = { "cute", "spin", "FFD23F" }, Erza = { "fighter", "slash", "D9E2EC" },
	Hinata = { "bouncy", "spin", "FF8A1F" }, Isagi = { "fighter", "spin", "3FA9FF" }, Kuroko = { "cute", "rise", "8CC8F0" },
	Shinji = { "cute", "rise", "B44DFF" }, Asuka = { "fighter", "fistUp", "FF3B3B" }, Lelouch = { "stoic", "thrust", "FF3B3B" },
	["Sun God"] = { "float", "fistUp", "FFD23F" }, ["Moon Goddess"] = { "float", "rise", "D8E3F2" }, ["Cosmic Oracle"] = { "float", "rise", "B44DFF" },
}
local JOINTS = { "Torso", "Head", "UpperArmL", "UpperArmR", "ForearmL", "ForearmR", "ThighL", "ThighR", "ShinL", "ShinR", "FootL", "FootR" }

local rigs = {}
local function add(model)
	if not model:IsA("Model") or not model:IsDescendantOf(workspace) then return end
	local st = STYLE[model.Name] or { "stoic", "fistUp", "FFFFFF" }
	rigs[model] = {
		joints = {}, count = 0, rescan = 0, root = nil, scale = model:GetAttribute("Scale") and 2.6 or 2.6,
		idle = st[1], power = st[2], color = Color3.fromHex(st[3]), base = POSES[model.Name] or {},
		phase = (#model.Name * 1.7) % 6.28, nextPower = os.clock() + 2 + math.random() * 9, powerStart = nil, fired = {},
	}
end
local function remove(model)
	local r = rigs[model]
	if r then for _, j in r.joints do j.Transform = ID end; rigs[model] = nil end
end
for _, m in CollectionService:GetTagged(TAG) do add(m) end
CollectionService:GetInstanceAddedSignal(TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(TAG):Connect(remove)

---------------------------------------------------------------------------- VFX helpers
local FX = workspace:FindFirstChild("_AnimeFX") or Instance.new("Folder")
FX.Name = "_AnimeFX"; FX.Parent = workspace

local function neonBall(cf, color, size, life, grow)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Ball; p.Material = Enum.Material.Neon; p.Color = color
	p.Size = Vector3.one * size; p.CFrame = cf; p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false
	p.Transparency = 0.1; p.Parent = FX
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Size = Vector3.one * size * grow, Transparency = 1 }):Play()
	Debris:AddItem(p, life + 0.1)
	return p
end
local function ring(cf, color, size, life)
	local p = Instance.new("Part")
	p.Shape = Enum.PartType.Cylinder; p.Material = Enum.Material.Neon; p.Color = color
	p.Size = Vector3.new(0.15, size, size); p.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
	p.Anchored = true; p.CanCollide = false; p.CanQuery = false; p.CanTouch = false; p.CastShadow = false; p.Transparency = 0.2; p.Parent = FX
	TweenService:Create(p, TweenInfo.new(life, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(0.05, size * 6, size * 6), Transparency = 1 }):Play()
	Debris:AddItem(p, life + 0.1)
end
local function burst(cf, color, n)
	local a = Instance.new("Part"); a.Size = Vector3.one * 0.2; a.Transparency = 1; a.Anchored = true; a.CanCollide = false; a.CanQuery = false; a.CanTouch = false
	a.CFrame = cf; a.Parent = FX
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"; e.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	e.LightEmission = 1; e.LightInfluence = 0; e.Rate = 0; e.Speed = NumberRange.new(18, 34); e.Drag = 4
	e.SpreadAngle = Vector2.new(180, 180); e.Lifetime = NumberRange.new(0.35, 0.7)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Parent = a; e:Emit(n)
	local l = Instance.new("PointLight"); l.Color = color; l.Range = 22; l.Brightness = 8; l.Parent = a
	TweenService:Create(l, TweenInfo.new(0.6), { Brightness = 0 }):Play()
	Debris:AddItem(a, 1)
end
local function ability(model, r, at)
	local folder = ReplicatedStorage:FindFirstChild("AnimeVFX")
	local egg = model:GetAttribute("Egg")
	local src = folder and egg and folder:FindFirstChild(egg) and folder[egg]:FindFirstChild(model.Name)
	if not src then return end
	local fx = src:Clone()
	-- effects and characters both face -Z (Roblox front)
	fx:PivotTo(at)
	fx.Parent = FX
	task.delay(1.9, function()
		for _, e in fx:GetDescendants() do
			if e:IsA("ParticleEmitter") or e:IsA("Beam") or e:IsA("Light") then e.Enabled = false end
			if e:IsA("BasePart") and e.Transparency < 1 then TweenService:Create(e, TweenInfo.new(0.6), { Transparency = 1 }):Play() end
		end
		task.wait(1.2); fx:Destroy()
	end)
end

---------------------------------------------------------------------------- poses
local function A(x, y, z) return CFrame.Angles(rad(x or 0), rad(y or 0), rad(z or 0)) end
local function smooth(x) x = clamp(x, 0, 1); return x * x * (3 - 2 * x) end

-- power poses are absolute (built for the neutral rig: arms hang down, front = +Z)
-- returns pose table for phase p (0..1); wind-up 0-0.3, hit at 0.35, hold, recover 0.75-1
local POWER = {}
function POWER.fistUp(p)
	local w = smooth(p / 0.3)
	return { Torso = CFrame.new(0, -0.25 * w + 0.35 * smooth((p - 0.3) / 0.1), 0) * A(-6 * w),
		UpperArmR = A(-175 * smooth((p - 0.2) / 0.15) - 20 * w, 0, -10), ForearmR = A(-10), Head = A(-18 * smooth((p - 0.3) / 0.2)),
		UpperArmL = A(10, 0, 25 * w), ForearmL = A(-50 * w), ThighL = A(-10 * w), ShinL = A(20 * w), ThighR = A(5 * w) }
end
function POWER.charge(p, t)
	local w = smooth(p / 0.35); local shake = (p > 0.2 and p < 0.75) and 0.06 * sin(t * 70) or 0
	return { Torso = CFrame.new(shake, -0.7 * w, 0) * A(12 * w),
		UpperArmL = A(-20 * w, 0, 70 * w), UpperArmR = A(-20 * w, 0, -70 * w), ForearmL = A(-80 * w), ForearmR = A(-80 * w),
		Head = A(-28 * smooth((p - 0.3) / 0.15)), ThighL = A(-35 * w, 0, 12 * w), ThighR = A(-35 * w, 0, -12 * w), ShinL = A(55 * w), ShinR = A(55 * w),
		FootL = A(-20 * w), FootR = A(-20 * w) }
end
function POWER.thrust(p)
	local wind = smooth(p / 0.25); local hit = smooth((p - 0.25) / 0.1)
	return { Torso = A(0, -30 * wind + 55 * hit, 0) * CFrame.new(0, -0.2 * wind, 0),
		UpperArmR = A(-40 * wind - 55 * hit, 0, 15 * wind - 15 * hit), ForearmR = A(-70 * wind + 70 * hit),
		UpperArmL = A(-30 * hit, 0, 20 * hit), ForearmL = A(-60 * hit), Head = A(0, -15 * hit, 0),
		ThighL = A(-25 * hit), ShinL = A(25 * hit), ThighR = A(15 * hit) }
end
function POWER.slash(p)
	local wind = smooth(p / 0.25); local sw = smooth((p - 0.27) / 0.12)
	return { Torso = A(0, -40 * wind + 85 * sw, 0) * CFrame.new(0, -0.25 * wind, 0),
		UpperArmR = A(-150 * wind + 120 * sw, 0, -25 * wind + 55 * sw), ForearmR = A(-30 * wind + 20 * sw),
		UpperArmL = A(-20, 0, 30 * wind), Head = A(0, 20 * wind - 30 * sw, 0), ThighL = A(-20 * sw), ShinL = A(25 * sw), ThighR = A(20 * sw) }
end
function POWER.spin(p)
	local spinT = smooth((p - 0.1) / 0.55); local up = sin(clamp((p - 0.1) / 0.55, 0, 1) * math.pi)
	return { Torso = CFrame.new(0, 1.4 * up, 0) * A(0, 360 * spinT, 0),
		UpperArmL = A(0, 0, 80 * up), UpperArmR = A(0, 0, -80 * up), ThighL = A(-30 * up), ShinL = A(60 * up), ThighR = A(-10 * up), ShinR = A(30 * up) }
end
function POWER.rise(p)
	local w = smooth(p / 0.35)
	return { Torso = CFrame.new(0, 2.2 * w, 0) * A(-8 * w), UpperArmL = A(-15 * w, 0, 70 * w), UpperArmR = A(-15 * w, 0, -70 * w),
		ForearmL = A(-25 * w), ForearmR = A(-25 * w), Head = A(-20 * w), ThighL = A(-10 * w), ThighR = A(5 * w), ShinL = A(25 * w), ShinR = A(10 * w),
		FootL = A(30 * w), FootR = A(30 * w) }
end

-- idle layer (added on top of the base pose). l = lagged time for follow-through.
local function idle(r, t)
	local p = t + r.phase
	local lag = p - 0.35
	local b, bl = sin(p * 1.6), sin(lag * 1.6)
	local s, sl = sin(p * 0.7), sin(lag * 0.7)
	local look = sin(p * 0.33) + 0.45 * sin(p * 0.91)
	local o = {}
	if r.idle == "bouncy" then
		local hop = math.abs(sin(p * 3)); local hl = math.abs(sin(lag * 3))
		o.Torso = CFrame.new(0, 0.18 * hop - 0.12, 0) * A(3 * hop, 6 * s, 0)
		o.Head = A(5 * hl - 3, 16 * look, 4 * sl)
		o.UpperArmL = A(14 * sin(lag * 3), 0, 6 * hl); o.UpperArmR = A(-14 * sin(lag * 3), 0, -6 * hl)
		o.ForearmL = A(-12 - 10 * hl); o.ForearmR = A(-12 - 10 * hl)
		o.ThighL = A(-14 + 8 * hop); o.ThighR = A(-14 + 8 * hop); o.ShinL = A(24 - 14 * hop); o.ShinR = A(24 - 14 * hop)
		o.FootL = A(-10 + 6 * hop); o.FootR = A(-10 + 6 * hop)
	elseif r.idle == "fighter" then
		local shift = s
		o.Torso = CFrame.new(0.12 * shift, -0.15 + 0.04 * b, 0) * A(4, 8 * shift, -3 * shift)
		o.Head = A(2 * bl, 8 * look - 6 * sl, 0)
		o.UpperArmL = A(-10 - 4 * bl, 0, 4); o.UpperArmR = A(-10 + 4 * bl, 0, -4)
		o.ForearmL = A(-25 - 6 * bl); o.ForearmR = A(-25 + 6 * bl)
		o.ThighL = A(-16 - 6 * shift, 0, 6); o.ThighR = A(-16 + 6 * shift, 0, -6); o.ShinL = A(26 + 6 * shift); o.ShinR = A(26 - 6 * shift)
		o.FootL = A(-10); o.FootR = A(-10)
	elseif r.idle == "cute" then
		o.Torso = CFrame.new(0, 0.04 * b, 0) * A(0, 5 * s, 3 * s)
		o.Head = A(3 * bl, 10 * look, 12 * sin(lag * 0.9))
		o.UpperArmL = A(4 * sl, 0, 6 + 4 * bl); o.UpperArmR = A(-4 * sl, 0, -6 - 4 * bl)
		o.ForearmL = A(-15 - 5 * bl); o.ForearmR = A(-15 - 5 * bl)
		o.ThighL = A(-4 * s); o.ShinL = A(8 + 8 * math.max(0, s)); o.FootL = A(-4 * s)
	elseif r.idle == "float" then
		local hover = sin(p * 1.1)
		o.Torso = CFrame.new(0, 0.9 + 0.35 * hover, 0) * A(-3 + 2 * sin(lag * 1.1), 6 * s, 0)
		o.Head = A(-3 + 2 * bl, 10 * look, 0)
		o.UpperArmL = A(-6 * sl, 0, 18 + 6 * sin(lag * 1.1)); o.UpperArmR = A(6 * sl, 0, -18 - 6 * sin(lag * 1.1))
		o.ForearmL = A(-20); o.ForearmR = A(-20)
		o.ThighL = A(-12 + 4 * hover); o.ThighR = A(-4 + 4 * hover); o.ShinL = A(30); o.ShinR = A(15); o.FootL = A(35); o.FootR = A(30)
	else -- stoic
		o.Torso = CFrame.new(0, 0.03 * b, 0) * A(-1.5 * b, 3 * s, 0)
		o.Head = A(2 * bl, 9 * look, 0)
		o.UpperArmL = A(2 * sl, 0, 2 + 1.5 * bl); o.UpperArmR = A(-2 * sl, 0, -2 - 1.5 * bl)
		o.ThighL = A(-2 * b); o.ShinL = A(3 * b)
	end
	return o
end

local function fxAnchor(r, kind)
	local hand = r.joints.HandR and r.joints.HandR.Part1
	if (kind == "thrust" or kind == "fistUp" or kind == "slash") and hand then return CFrame.new(hand.Position) * (r.root.CFrame - r.root.Position) end
	return r.root.CFrame * CFrame.new(0, 1, 0)
end

local function events(model, r, p)
	local f = r.fired
	if p >= 0.05 and not f.charge then
		f.charge = true
		local cf = fxAnchor(r, r.power)
		neonBall(cf, r.color, 0.6, 0.9, 5)
	end
	if p >= 0.35 and not f.hit then
		f.hit = true
		local cf = fxAnchor(r, r.power)
		if AnimeFX then
			-- Blender-made kit: slashes, beams, orbs, auras, bolts, crystals... (ReplicatedStorage.AnimeFX)
			AnimeFX.play(model.Name, r.root.CFrame, cf, r.color)
		else
			neonBall(cf, Color3.new(1, 1, 1), 1.2, 0.35, 6)
			neonBall(cf, r.color, 2, 0.6, 4)
			ring(r.root.CFrame * CFrame.new(0, -2.6, 0), r.color, 3, 0.7)
			burst(cf, r.color, 60)
			ability(model, r, cf)
		end
	end
end

RunService.Heartbeat:Connect(function()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local camPos = cam.CFrame.Position
	local t = os.clock()
	for model, r in rigs do
		if not model.Parent then rigs[model] = nil continue end
		if r.count < 14 and t >= r.rescan then -- streaming can deliver parts late
			r.rescan = t + 1
			local n = 0
			for _, m in model:GetDescendants() do if m:IsA("Motor6D") then r.joints[m.Name] = m; n += 1 end end
			r.count = n
			r.root = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
		end
		if not r.root or (r.root.Position - camPos).Magnitude > IDLE_DISTANCE then continue end

		local lay = idle(r, t)
		local pw, e = nil, 0
		if not r.powerStart and t >= r.nextPower then r.powerStart = t; r.fired = {} end
		if r.powerStart then
			local p = (t - r.powerStart) / POWER_TIME
			if p >= 1 then
				r.powerStart = nil; r.nextPower = t + 8 + math.random() * 7
			else
				events(model, r, p)
				pw = POWER[r.power](p, t)
				e = smooth(p / 0.12) * (1 - smooth((p - 0.72) / 0.28)) -- blend in fast, out slowly
			end
		end
		for _, name in JOINTS do
			local j = r.joints[name]
			if j then
				local rest = (r.base[name] or ID) * (lay[name] or ID)
				local cf = pw and rest:Lerp(pw[name] or ID, e) or rest
				-- poses are authored facing +Z; the imported rigs face -Z (Roblox front), so turn them 180 deg
				j.Transform = FLIP * cf * FLIP
			end
		end
	end
end)
