--[[ StarterPlayerScripts.TrailerCinematic  (LocalScript)
Recording-only trailer for "Hatch an Anime". Runs entirely on YOUR client:
no currency, inventory, saves, hatch timers or server state are touched. Everything it creates is local
and removed on finish / cancel / death / error. Start: /trailer or F7. Cancel: /trailerstop or F7 again.
Delete this script + TrailerConfig + Workspace.TrailerMarkers to remove it completely.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local StarterGui = game:GetService("StarterGui")
local ContentProvider = game:GetService("ContentProvider")
local CollectionService = game:GetService("CollectionService")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")
local PathfindingService = game:GetService("PathfindingService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("TrailerConfig"))

local player = Players.LocalPlayer
if not (Config.OwnerIds[player.UserId] or (Config.AllowInStudio and RunService:IsStudio())) then return end

local clamp, sin, cos, abs, max, pi = math.clamp, math.sin, math.cos, math.abs, math.max, math.pi
local UP = Vector3.yAxis
local function seg(t, a, b) return clamp((t - a) / (b - a), 0, 1) end
local function ease(a) a = clamp(a, 0, 1); return a * a * (3 - 2 * a) end
local function easeIn(a) a = clamp(a, 0, 1); return a * a end
local function easeOut(a) a = clamp(a, 0, 1); return 1 - (1 - a) * (1 - a) end
local function accel(k) return k < 0.15 and (k * k / 0.3) or ((k - 0.075) / 0.925) end
local function decel(k) return 1 - (1 - clamp(k, 0, 1)) ^ 1.6 end
local function lerp(a, b, k) return a + (b - a) * k end
local function flat(v) return Vector3.new(v.X, 0, v.Z) end
local function unitOr(v, d) return v.Magnitude > 1e-3 and v.Unit or d end
local function yawOf(dir) dir = flat(dir); if dir.Magnitude < 1e-3 then return nil end return math.atan2(-dir.X, -dir.Z) end
local function fwdOf(yaw) return Vector3.new(-sin(yaw), 0, -cos(yaw)) end
local function wrap(a) return (a + pi) % (2 * pi) - pi end
local function lerpAngle(a, b, k) return a + wrap(b - a) * k end
local function pivotOf(x) return x:IsA("Model") and x:GetPivot() or x.CFrame end
local function setPivot(x, cf) if x:IsA("Model") then x:PivotTo(cf) else x.CFrame = cf end end
local function resolve(path)
	if typeof(path) == "Instance" then return path end
	if type(path) ~= "string" or path == "" then return nil end
	local parts = string.split(path, "/")
	local cur = (parts[1]:lower() == "workspace") and workspace or game:FindFirstChild(parts[1])
	for i = 2, #parts do cur = cur and cur:FindFirstChild(parts[i]) end
	return cur
end

local statusGui, statusN = nil, 0
local function status(text, secs)
	if not statusGui then
		statusGui = Instance.new("ScreenGui"); statusGui.Name = "TrailerStatus"; statusGui.ResetOnSpawn = false; statusGui.DisplayOrder = 1000
		local l = Instance.new("TextLabel"); l.Name = "Label"; l.AnchorPoint = Vector2.new(0.5, 0); l.Position = UDim2.new(0.5, 0, 0, 70)
		l.AutomaticSize = Enum.AutomaticSize.XY; l.BackgroundColor3 = Color3.fromRGB(29, 20, 32); l.BackgroundTransparency = 0.1
		l.TextColor3 = Color3.fromRGB(255, 243, 220); l.Font = Enum.Font.FredokaOne; l.TextSize = 20; l.Parent = statusGui
		local p = Instance.new("UIPadding"); p.PaddingLeft, p.PaddingRight, p.PaddingTop, p.PaddingBottom = UDim.new(0, 14), UDim.new(0, 14), UDim.new(0, 8), UDim.new(0, 8); p.Parent = l
		Instance.new("UICorner", l).CornerRadius = UDim.new(0, 10)
		statusGui.Parent = player:WaitForChild("PlayerGui")
	end
	statusN += 1
	local n = statusN
	statusGui.Label.Text = text; statusGui.Enabled = true
	if secs then task.delay(secs, function() if n == statusN then statusGui.Enabled = false end end) end
end

local JOINT = { neck = "Neck", waist = "Waist", ls = "LeftShoulder", rs = "RightShoulder", le = "LeftElbow", re = "RightElbow",
	lh = "LeftHip", rh = "RightHip", lk = "LeftKnee", rk = "RightKnee" }
local function V(x, y, z) return { x or 0, y or 0, z or 0 } end
local function runLegs(o, ph, amt)
	local s = sin(ph)
	o.lh = V(-s * 0.9 * amt); o.rh = V(s * 0.9 * amt)
	o.lk = V((-0.25 - 0.95 * max(0, s)) * amt); o.rk = V((-0.25 - 0.95 * max(0, -s)) * amt)
	o.rootY = (0.14 * abs(cos(ph)) - 0.05) * amt
end
local POSE = {}
POSE.idle = function(t) return { waist = V(-0.02 + 0.02 * sin(t * 2)), neck = V(0.02 * sin(t * 1.3)), ls = V(0.05, 0, -0.1), rs = V(0.05, 0, 0.1), le = V(0.15), re = V(0.15) } end
POSE.look = function(t, P) local o = POSE.idle(t); o.neck = V(0.05, P.look, 0); o.waist = V(-0.02, P.look * 0.25, 0); return o end
POSE.fall = function(t) return { ls = V(0.3, 0, -1.25 - 0.1 * sin(t * 9)), rs = V(0.3, 0, 1.25 + 0.1 * sin(t * 9)), le = V(0.5), re = V(0.5), lh = V(0.45), lk = V(-0.7), rh = V(-0.15), rk = V(-0.45), neck = V(-0.35) } end
POSE.land = function() return { rootY = -0.7, waist = V(-0.55), neck = V(0.45), lh = V(1.2), lk = V(-1.7), rh = V(1.0, 0, 0.12), rk = V(-1.6), rs = V(0.6, 0, 0.25), re = V(0.35), ls = V(-0.35, 0, -0.6), le = V(0.5) } end
POSE.excited = function(t) local h = max(0, sin(t * 9)); return { rootY = 0.45 * h, ls = V(2.5 + 0.25 * sin(t * 18), 0, 0.15), rs = V(2.5 + 0.25 * sin(t * 18 + 1), 0, -0.15), le = V(0.4), re = V(0.4), neck = V(0.25), lh = V(0.3 * h), rh = V(0.3 * h), lk = V(-0.5 * h), rk = V(-0.5 * h) } end
POSE.ready = function() return { rootY = -0.2, waist = V(-0.35), neck = V(0.2), lh = V(0.55), lk = V(-0.8), rh = V(-0.25), rk = V(-0.35), ls = V(-0.5, 0, -0.1), rs = V(0.6, 0, 0.1), le = V(0.9), re = V(0.9) } end
POSE.run = function(t, P) local s = sin(P.phase); local o = { waist = V(-0.18), neck = V(0.12), ls = V(s * 1.05, 0, -0.08), rs = V(-s * 1.05, 0, 0.08), le = V(1.25), re = V(1.25) }; runLegs(o, P.phase, 1); return o end
POSE.carry = function(t, P) local w = clamp(0.42 - 0.27 * (P.carryR or 1), 0, 0.35); local g = P.gait or 1; local o = { waist = V(-0.06 * g), neck = V(-0.05), ls = V(1.15, 0, w), rs = V(1.15, 0, -w), le = V(0.35), re = V(0.35) }; if P.moving then runLegs(o, P.phase, 0.85 * g) end; return o end
POSE.walk = function(t, P) local s = sin(P.phase); local o = { waist = V(-0.04), neck = V(0.04), ls = V(s * 0.5, 0, -0.08), rs = V(-s * 0.5, 0, 0.08), le = V(0.35), re = V(0.35) }; runLegs(o, P.phase, 0.55); return o end
POSE.stumble = function(t, P) local k = P.k; return { pitch = 1.42 * k, rootY = -0.12 * k, waist = V(-0.1 * k), neck = V(0.65 * k), ls = V(0.4 + 2.3 * k, 0, -0.15), rs = V(0.4 + 2.3 * k, 0, 0.15), le = V(0.2), re = V(0.2), lh = V(-0.2 - 0.45 * k), lk = V(-0.6 * k), rh = V(0.35 * k), rk = V(-0.25) } end
POSE.recover = function(t, P) local k = P.k; local ax = 0.1 + 1.5 * clamp(k / 0.6, 0, 1); local tuck = 4 * k * (1 - k); return { pitch = 1.42 * k, waist = V(-0.3 * k), neck = V(0.5 * k), ls = V(ax, 0, -0.1), rs = V(ax, 0, 0.1), le = V(0.15), re = V(0.15), lh = V(tuck), lk = V(-1.5 * tuck), rh = V(0.6 * tuck), rk = V(-tuck) } end
POSE.grab = function(t, P) local k = P.k; return { rootY = -0.1 * k, waist = V(-0.45 * k), neck = V(-0.3 * k), ls = V(0.4 + k, 0, 0.25 * k), rs = V(0.4 + k, 0, -0.25 * k), le = V(0.3), re = V(0.3), lh = V(0.3 * k), lk = V(-0.5 * k), rh = V(0.1), rk = V(-0.3 * k) } end
POSE.push = function(t, P) local k = P.k; return { rootY = -0.07 * k, waist = V(-0.15 - 0.25 * k), neck = V(-0.05), ls = V(0.9 + 0.75 * k, 0, 0.3), rs = V(0.9 + 0.75 * k, 0, -0.3), le = V(0.1 + 1.6 * (1 - k)), re = V(0.1 + 1.6 * (1 - k)), lh = V(0.4 * k), lk = V(-0.5 * k), rh = V(-0.3 * k) } end
POSE.lean = function(t) return { rootY = -0.05, waist = V(-0.42), neck = V(0.35), ls = V(0.35, 0, -0.05), rs = V(0.35, 0, 0.05), le = V(0.6), re = V(0.6), rh = V(0.2), rk = V(-0.25 - 0.15 * max(0, sin(t * 7))) } end
POSE.place = function(t, P) local k = P.k; return { rootY = -0.16 * k, waist = V(-0.55 * k), neck = V(-0.3 * k), ls = V(0.9 + 0.3 * k, 0, 0.3), rs = V(0.9 + 0.3 * k, 0, -0.3), le = V(0.3), re = V(0.3), lh = V(0.4 * k), rh = V(0.4 * k), lk = V(-0.8 * k), rk = V(-0.8 * k) } end
POSE.celebrate = function(t) local h = max(0, sin(t * 7.5)); return { rootY = 0.6 * h, ls = V(0, 0, -(2.55 + 0.2 * sin(t * 15))), rs = V(0, 0, 2.55 + 0.2 * sin(t * 15 + 1)), le = V(0.3), re = V(0.3), neck = V(0.3), lh = V(0.25 * h), rh = V(0.25 * h), lk = V(-0.45 * h), rk = V(-0.45 * h) } end

local function mix(a, b, w)
	local out = {}
	for k, v in a do local o = b[k]; if type(v) == "table" then o = o or V(); out[k] = V(lerp(v[1], o[1], w), lerp(v[2], o[2], w), lerp(v[3], o[3], w)) else out[k] = lerp(v, o or 0, w) end end
	for k, v in b do if out[k] == nil then if type(v) == "table" then out[k] = V(v[1] * w, v[2] * w, v[3] * w) else out[k] = v * w end end end
	return out
end

local run = nil
local function once(R, key) if R.cues[key] then return false end R.cues[key] = true; return true end
local function base(R) return CFrame.new(R.A.pos) * CFrame.Angles(0, R.A.yaw, 0) end
local function M(R, n) return R.M[n] and R.M[n].Position end

local function setPose(R, A, name, fade)
	if A.pose == name then return end
	A.prev, A.pose, A.blend0, A.blendDur = A.pose, name, R.now, fade or 0.2
	for n, tr in A.tracks do if n ~= name and tr.IsPlaying then tr:Stop(fade or 0.2) end end
	if A.tracks[name] then A.tracks[name]:Play(fade or 0.2) end
end
local function actorApply(R)
	local A = R.A
	local useTrack = A.tracks[A.pose] ~= nil
	local v = {}
	if not useTrack then
		v = (POSE[A.pose] or POSE.idle)(R.now, A.P)
		local w = A.blendDur > 0 and clamp((R.now - A.blend0) / A.blendDur, 0, 1) or 1
		if w < 1 and A.prev and POSE[A.prev] and not A.tracks[A.prev] then v = mix(POSE[A.prev](R.now, A.P), v, ease(w)) end
	end
	A.root.CFrame = base(R) * CFrame.new(0, v.rootY or 0, 0) * CFrame.Angles(-(v.pitch or 0), 0, 0) * CFrame.new(0, A.offset, 0)
	for key, j in A.joints do local a = (not useTrack) and v[key]; j.C0 = a and (A.c0[key] * CFrame.Angles(a[1], a[2], a[3])) or A.c0[key] end
	local l, r = A.model:FindFirstChild("LeftHand"), A.model:FindFirstChild("RightHand")
	if l and r then A.handsLocal = A.root.CFrame:PointToObjectSpace((l.Position + r.Position) / 2) end
	local lt = A.visible and 0 or 1
	for _, p in A.parts do p.LocalTransparencyModifier = lt end
end

local function groundHit(R, pos) return workspace:Raycast(pos + UP * 3, Vector3.new(0, -40, 0), R.ray) end
local function stand(R, pos) local h = groundHit(R, pos); return Vector3.new(pos.X, h and h.Position.Y or pos.Y, pos.Z) end
local function runTo(R, a, b, u, rate, dt)
	local A = R.A
	A.pos = stand(R, a:Lerp(b, clamp(u, 0, 1)))
	local y = yawOf(b - a); if y then A.yaw = lerpAngle(A.yaw, y, 1 - math.exp(-12 * dt)) end
	A.P.phase += dt * max(rate, 4) * 0.55
end

local function route(R, a, b)
	local pts = { a }
	pcall(function()
		local path = PathfindingService:CreatePath({ AgentRadius = 1.8, AgentHeight = 5.5, AgentCanJump = false, WaypointSpacing = 3 })
		path:ComputeAsync(a, b)
		if path.Status == Enum.PathStatus.Success then local w = path:GetWaypoints(); for i = 2, #w - 1 do table.insert(pts, w[i].Position) end end
	end)
	table.insert(pts, b)
	return pts
end
local function withStart(R, pts) local c = table.clone(pts); c[1] = R.A.pos; return c end
local function walkAlong(R, poly, u, dt)
	local A = R.A
	local p, dir = poly(u)
	local new = stand(R, p)
	A.P.phase += flat(new - A.pos).Magnitude * ((A.P.gait or 1) >= 0.9 and 1.15 or 1.8)
	A.pos = new
	local y = yawOf(dir); if y then A.yaw = lerpAngle(A.yaw, y, 1 - math.exp(-10 * dt)) end
end

local function camCut(R, cf) R.camCF = cf end
local function camFollow(R, cf, speed, dt) R.camCF = R.camCF and R.camCF:Lerp(cf, 1 - math.exp(-speed * dt)) or cf end
local function camLook(R, target, speed, dt) camFollow(R, CFrame.lookAt(R.camCF.Position, target), speed, dt) end
local function shake(R, amp, dur)
	if Config.Shake <= 0 or player:GetAttribute("ReducedMotion") then return end
	table.insert(R.shakes, { t0 = R.now, amp = amp * Config.Shake, dur = dur, seed = math.random() * 100 })
end

local function sound(R, slot, opts)
	local id = Config.Sounds[slot]
	if not id or id == "" or player:GetAttribute("SFXMuted") then return nil end
	opts = opts or {}
	local s = Instance.new("Sound"); s.SoundId = id; s.Volume = (opts.volume or 1) * Config.Volume; s.Looped = opts.loop == true
	local g = SoundService:FindFirstChild(Config.SoundGroup or "")
	if g and g:IsA("SoundGroup") then s.SoundGroup = g end
	s.Parent = R.FX; s:Play()
	if not s.Looped then s.Ended:Once(function() s:Destroy() end) end
	return s
end
local function startLoop(R, slot, vol) if not R.loops[slot] then R.loops[slot] = sound(R, slot, { loop = true, volume = vol }) end end
local function stopLoop(R, slot) local s = R.loops[slot]; R.loops[slot] = nil; if s then TweenService:Create(s, TweenInfo.new(0.2), { Volume = 0 }):Play(); Debris:AddItem(s, 0.3) end end

local SMOKE, SPARK = "rbxasset://textures/particles/smoke_main.dds", "rbxasset://textures/particles/sparkles_main.dds"
local function part(R, props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do p[k] = v end
	p.Parent = R.FX
	return p
end
local function emitAt(R, pos, o)
	local p = part(R, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(pos) })
	local a = Instance.new("Attachment"); a.Parent = p
	local e = Instance.new("ParticleEmitter")
	e.Texture = o.texture or SMOKE; e.Rate = 0; e.Color = ColorSequence.new(o.color or Color3.new(1, 1, 1))
	e.LightEmission = o.light or 0; e.LightInfluence = o.light and 0 or 1
	e.Size = NumberSequence.new(o.size0 or 1, o.size1 or 3); e.Transparency = NumberSequence.new(o.tr0 or 0.35, 1)
	e.Lifetime = NumberRange.new(o.life or 0.8, (o.life or 0.8) * 1.4); e.Speed = NumberRange.new(o.speed or 4, (o.speed or 4) * 1.6)
	e.SpreadAngle = Vector2.new(o.spread or 80, o.spread or 80); e.EmissionDirection = Enum.NormalId.Top
	e.Acceleration = o.accel or Vector3.new(0, -2, 0); e.Drag = o.drag or 2
	e.Rotation = NumberRange.new(0, 360); e.RotSpeed = NumberRange.new(-40, 40); e.Parent = a
	e:Emit(math.max(1, math.floor((o.count or 10) * Config.EffectDensity + 0.5)))
	Debris:AddItem(p, 4)
end
local function dust(R, pos, count)
	local h = groundHit(R, pos)
	local c = Color3.fromRGB(196, 178, 150)
	if h then c = (h.Instance:IsA("Terrain") and workspace.Terrain:GetMaterialColor(h.Material) or h.Instance.Color):Lerp(Color3.fromRGB(220, 208, 188), 0.35) end
	emitAt(R, (h and h.Position or pos) + UP * 0.3, { color = c, count = count, speed = 6, life = 0.9, size0 = 1, size1 = 3.5, spread = 85, accel = Vector3.new(0, -3, 0), drag = 3 })
end
local function sparks(R, pos, color, count) emitAt(R, pos, { texture = SPARK, color = color, light = 1, count = count, speed = 10, life = 0.6, size0 = 0.6, size1 = 0, tr0 = 0, spread = 180, accel = Vector3.new(0, -8, 0), drag = 4 }) end
local function flash(R, pos, color, peak, dur, range)
	local p = part(R, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(pos) })
	local l = Instance.new("PointLight"); l.Color = color; l.Range = range or 18; l.Brightness = peak; l.Shadows = false; l.Parent = p
	TweenService:Create(l, TweenInfo.new(dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	Debris:AddItem(p, dur + 0.2)
end
local function shockRing(R, pos, color, size, dur)
	local p = part(R, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = color, Size = Vector3.new(0.12, 1, 1), CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, pi / 2) })
	TweenService:Create(p, TweenInfo.new(dur, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Size = Vector3.new(0.12, size, size), Transparency = 1 }):Play()
	Debris:AddItem(p, dur + 0.1)
end
local function prepProp(src, scale, height)
	local m = src:Clone()
	if m:IsA("BasePart") then local w = Instance.new("Model"); m.Parent = w; m = w end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch = true, false, false, false
		elseif d:IsA("Humanoid") then d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		elseif d:IsA("BaseScript") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then d:Destroy() end
	end
	if scale and scale ~= 1 then m:ScaleTo(m:GetScale() * scale) end
	if height then local _, sz0 = m:GetBoundingBox(); if sz0.Y > 0 then m:ScaleTo(m:GetScale() * height / sz0.Y) end end
	local cf, size = m:GetBoundingBox()
	m.WorldPivot = CFrame.new(cf.Position - UP * size.Y / 2) * m:GetPivot().Rotation
	local r0 = max(size.X, size.Z) / 2
	return { m = m, h0 = size.Y, h = size.Y, r0 = r0, r = r0, s0 = m:GetScale(), rel = 1 }
end
local function setScale(o, rel) if o.rel == rel then return end o.rel = rel; o.m:ScaleTo(o.s0 * rel); o.h = o.h0 * rel; o.r = o.r0 * rel end
local function carriedCF(R, o)
	R.A.P.carryR = o.r
	local c = R.A.root.CFrame * R.A.handsLocal + fwdOf(R.A.yaw) * (o.r * 0.55 + 0.1)
	return CFrame.new(c - UP * o.h * 0.5) * CFrame.Angles(0, R.A.yaw, 0)
end
local function propApply(R, o)
	if not o.m.Parent then return end
	if o.mode == "river" then
		local k = clamp((R.now - o.t0) / o.travel, 0, 1)
		local p = M(R, "EggStart"):Lerp(M(R, "EggEnd"), k)
		o.cf = CFrame.new(p + UP * (0.15 * sin(R.now * 2.2) - o.h * 0.15)) * CFrame.Angles(0.06 * sin(R.now * 1.7), R.now * 0.25, 0.06 * sin(R.now * 1.3))
	elseif o.mode == "pick" then
		local k = clamp((R.now - o.pickT) / 0.2, 0, 1)
		o.cf = o.pick0:Lerp(carriedCF(R, o), ease(k)); if k >= 1 then o.mode = "carried" end
	elseif o.mode == "carried" then o.cf = carriedCF(R, o)
	elseif o.mode == "socket" then o.cf = CFrame.new(R.socket.Position) * CFrame.Angles(0, R.socketYaw, 0) * CFrame.Angles(o.rx or 0, 0, o.rz or 0)
	elseif o.mode == "slot" then o.cf = CFrame.new(R.slotTop) * CFrame.Angles(0, o.spin or 0, 0) end
	if o.cf then o.m:PivotTo(o.cf) end
end
local function eggCenter(R) local E = R.egg; return E.cf and (E.cf.Position + UP * E.h * 0.5) or M(R, "EggStart") end

local function setDoors(R, k)
	k = clamp(k, 0, 1)
	if R.doorK == k then return end
	R.doorK = k
	local right = R.inc:GetPivot().RightVector
	for _, d in R.doors do setPivot(d.obj, d.closed + right * (d.dir * Config.DoorSlide * k)) end
end
local function polyline(pts)
	local L, total = {}, 0
	for i = 1, #pts - 1 do L[i] = (pts[i + 1] - pts[i]).Magnitude; total += L[i] end
	return function(u)
		local d = clamp(u, 0, 1) * total
		for i = 1, #pts - 1 do
			if d <= L[i] or i == #pts - 1 then return pts[i]:Lerp(pts[i + 1], L[i] > 0 and clamp(d / L[i], 0, 1) or 1), pts[i + 1] - pts[i] end
			d -= L[i]
		end
	end, total
end

local SCENES = {}
local function scene(name, baseDur, start, update) table.insert(SCENES, { name = name, base = baseDur, dur = Config.Durations[name] or baseDur, start = start, update = update }) end
scene("RiftArrival", 9, function(R)
	local A = R.A
	R.landPos = stand(R, M(R, "Land"))
	R.fwd = unitOr(flat(R.M.Land.CFrame.LookVector), Vector3.new(0, 0, -1))
	A.yaw = yawOf(R.fwd) or 0
	A.pos = M(R, "Rift"); A.visible = false
	setPose(R, A, "fall", 0)
	local rf = {}
	rf.crack = part(R, { Material = Enum.Material.Neon, Color = R.riftColor, Size = Vector3.new(0.35, 0.05, 0.35), Transparency = 1 })
	rf.core = part(R, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 248, 220), Size = Vector3.new(0.2, 0.05, 0.05), Transparency = 1 })
	rf.ring = part(R, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = R.riftColor, Size = Vector3.new(0.15, 0.05, 0.05), Transparency = 1 })
	rf.shimmer = part(R, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.ForceField, Color = R.riftColor, Size = Vector3.new(0.1, 0.05, 0.05), Transparency = 1 })
	rf.light = Instance.new("PointLight"); rf.light.Color = R.riftColor; rf.light.Range = 50; rf.light.Brightness = 0; rf.light.Parent = rf.core
	local at = Instance.new("Attachment"); at.Parent = rf.ring
	rf.emitter = Instance.new("ParticleEmitter"); rf.emitter.Texture = SPARK; rf.emitter.Rate = 0; rf.emitter.LightEmission = 1
	rf.emitter.Color = ColorSequence.new(R.riftColor); rf.emitter.Size = NumberSequence.new(0.6, 0); rf.emitter.Speed = NumberRange.new(6, 10)
	rf.emitter.SpreadAngle = Vector2.new(180, 180); rf.emitter.Lifetime = NumberRange.new(0.5, 0.9); rf.emitter.Drag = 3; rf.emitter.Parent = at
	R.rift = rf
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, 1.1, 0), Vector3.new(0, -1.1, 0); a0.Parent, a1.Parent = A.root, A.root
	local tr = Instance.new("Trail"); tr.Attachment0, tr.Attachment1 = a0, a1; tr.Lifetime = 0.35; tr.LightEmission = 1
	tr.Color = ColorSequence.new(R.riftColor); tr.Transparency = NumberSequence.new(0.15, 1); tr.Enabled = false; tr.Parent = A.root
	R.trail = tr
	local back, side = -R.fwd, R.fwd:Cross(UP)
	R.openCF = R.M.OpeningCam and R.M.OpeningCam.CFrame or CFrame.lookAt(R.landPos + back * 70 + side * 20 + UP * 50, R.landPos:Lerp(M(R, "Rift"), 0.35))
	camCut(R, R.openCF); R.fov = 60
	R.music = sound(R, "Music", { volume = 0.6 })
end, function(R, t, dt)
	local A = R.A
	local rp = M(R, "Rift")
	if not R.cues.riftGone then
		local rf, camPos = R.rift, R.camCF.Position
		local toCam = unitOr(camPos - rp, Vector3.zAxis)
		local face = CFrame.lookAt(rp, camPos)
		rf.crack.Size = Vector3.new(0.35, max(0.05, 22 * ease(seg(t, 0.3, 1.4))), 0.35)
		rf.crack.CFrame = face * CFrame.Angles(0, 0, 0.35)
		rf.crack.Transparency = t < 0.3 and 1 or seg(t, 1.6, 2.0)
		if t >= 0.3 and once(R, "riftOpen") then sound(R, "RiftOpen") end
		local open = easeOut(seg(t, 1.4, 2.3)) * (1 - ease(seg(t, 7.6, 8.2)))
		local flare = 1 + 0.6 * (ease(seg(t, 7.55, 7.75)) - ease(seg(t, 7.75, 8.1)))
		local spin = t * 1.6
		local function disc(p, d, depth)
			p.Size = Vector3.new(p.Size.X, max(0.05, d), max(0.05, d))
			p.CFrame = CFrame.new(rp - toCam * depth) * face.Rotation * CFrame.Angles(0, pi / 2, 0) * CFrame.Angles(spin, 0, 0)
			p.Transparency = d < 0.1 and 1 or 0
		end
		disc(rf.core, 15 * open * flare, 0); disc(rf.ring, 21 * open, 0.25); disc(rf.shimmer, 26 * open, 0.5)
		if open > 0.01 then rf.shimmer.Transparency = 0.35 end
		rf.light.Brightness = 4 * open + 6 * (flare - 1)
		rf.emitter.Rate = open > 0.2 and 25 * Config.EffectDensity or 0
		if t >= 7.6 and once(R, "riftClose") then sound(R, "RiftClose"); flash(R, rp, R.riftColor, 8, 0.5, 60) end
		if t >= 8.4 and once(R, "riftGone") then for _, p in { rf.crack, rf.core, rf.ring, rf.shimmer } do p:Destroy() end end
	end
	if t < 2.6 then A.pos = rp
	elseif t < 4.2 then
		if once(R, "drop") then A.visible = true; R.trail.Enabled = true; sound(R, "Whoosh") end
		local k = seg(t, 2.6, 4.2)
		local xz = rp:Lerp(R.landPos, ease(k))
		A.pos = Vector3.new(xz.X, lerp(rp.Y, R.landPos.Y, easeIn(k)), xz.Z)
	else
		A.pos = R.landPos
		if once(R, "land") then R.trail.Enabled = false; setPose(R, A, "land", 0.06); dust(R, R.landPos, 14); shake(R, 1, 0.32); sound(R, "Land") end
	end
	if t >= 5.4 and once(R, "standUp") then setPose(R, A, "idle", 0.6) end
	if t >= 6.2 and once(R, "lookAround") then setPose(R, A, "look", 0.3) end
	if t >= 6.2 then A.P.look = 0.9 * ease(seg(t, 6.3, 6.8)) - 1.8 * ease(seg(t, 7.0, 7.6)) + 0.9 * ease(seg(t, 7.9, 8.4)) end
	local fwd, side = R.fwd, R.fwd:Cross(UP)
	local torso = A.pos + UP * 2
	local landShot = CFrame.lookAt(R.landPos + fwd * 8 + side * 5 + UP * 2.8, R.landPos + UP * 3.6)
	if t < 2.6 then camFollow(R, R.openCF * CFrame.new(0, 0, -6 * ease(seg(t, 0, 2.6))), 3, dt)
	elseif t < 3.7 then local k = seg(t, 2.6, 4.2); camFollow(R, CFrame.lookAt(torso - fwd * (24 - 12 * k) + UP * (9 - 5 * k) + side * 4 * k, torso), 9, dt)
	elseif t < 7.2 then camFollow(R, landShot, 6, dt)
	else local b = ease(seg(t, 7.2, 7.7)) - ease(seg(t, 8.2, 8.8)); camFollow(R, CFrame.lookAt(landShot.Position, (R.landPos + UP * 3.4):Lerp(rp, 0.4 * b)), 6, dt) end
end)

scene("SpotEgg", 7, function(R)
	local E = R.egg
	E.m.Parent = R.FX; E.mode = "river"; E.t0 = R.now
	E.travel = R.durOf.SpotEgg + R.durOf.Chase * (9.4 / 10)
	R.yaw0 = R.A.yaw
	setPose(R, R.A, "look", 0.3)
	local b = base(R)
	camCut(R, CFrame.lookAt((b * CFrame.new(1.8, 3.4, 5.2)).Position, (b * CFrame.new(0, 3.0, -12)).Position)); R.fov = 58
end, function(R, t, dt)
	local A = R.A
	local egg = eggCenter(R)
	local yr = yawOf(egg - A.pos) or A.yaw
	local rel = clamp(wrap(yr - R.yaw0), -1.1, 1.1)
	local turn = ease(seg(t, 1.2, 2.4))
	A.yaw = lerpAngle(R.yaw0, yr, turn)
	if t < 4.6 then A.P.look = rel * ease(seg(t, 0.4, 1.1)) * (1 - turn) end
	if t >= 4.6 and once(R, "excited") then setPose(R, A, "excited", 0.2) end
	if t >= 6.1 and once(R, "ready") then setPose(R, A, "ready", 0.3) end
	local b = base(R)
	if t < 2.6 then
		camFollow(R, CFrame.lookAt((b * CFrame.new(1.8, 3.4, 5.2)).Position, (b * CFrame.new(0, 3.0, -12)).Position:Lerp(egg, ease(seg(t, 1.0, 2.4)))), 8, dt)
	elseif t < 4.6 then
		local away = unitOr(flat(A.pos - egg), Vector3.zAxis)
		local sd = away:Cross(UP)
		R.noSafe = true
		local shot = CFrame.lookAt(egg + away * 7 + sd * 1.5 + UP * 1.6, egg)
		if once(R, "eggClose") then camCut(R, shot); R.fov = 45 end
		camFollow(R, shot, 10, dt)
		if t >= 3.3 and once(R, "glint") then sparks(R, egg + UP * R.egg.h * 0.3 + sd * R.egg.h * 0.2, Color3.new(1, 1, 1), 3); flash(R, egg + UP, Color3.fromRGB(255, 244, 210), 3, 0.35, 8); sound(R, "Glint") end
	else
		local shot = CFrame.lookAt((b * CFrame.new(1.6, 3.2, -6.5)).Position, (b * CFrame.new(0, 3.2, 0)).Position)
		if once(R, "react") then camCut(R, shot); R.fov = 55 end
		camFollow(R, shot, 8, dt)
	end
end)

scene("Chase", 10, function(R)
	R.A.P.gait = 1
	R.q1 = polyline(withStart(R, R.routes.chase1))
	setPose(R, R.A, "run", 0.25); startLoop(R, "Footsteps")
	local b = base(R)
	camCut(R, CFrame.lookAt((b * CFrame.new(6, 3.2, 1)).Position, (b * CFrame.new(0, 3.0, -4)).Position)); R.fov = 60
end, function(R, t, dt)
	local A = R.A
	if t < 3.8 then walkAlong(R, R.q1, accel(seg(t, 0, 3.8)), dt)
	elseif t < 4.4 then
		if once(R, "trip") then setPose(R, A, "stumble", 0.08); stopLoop(R, "Footsteps"); R.trip0 = A.pos end
		A.pos = stand(R, R.trip0 + fwdOf(A.yaw) * 1.4 * easeOut(seg(t, 3.8, 4.4)))
		A.P.k = easeIn(seg(t, 3.8, 4.33))
		if t >= 4.32 and once(R, "hit") then dust(R, A.pos + fwdOf(A.yaw) * 1.8, 10); shake(R, 0.55, 0.25); sound(R, "Stumble") end
	elseif t < 5.2 then A.P.k = 1
	elseif t < 6.0 then if once(R, "recover") then setPose(R, A, "recover", 0.15) end; A.P.k = 1 - ease(seg(t, 5.2, 6.0))
	elseif t < 6.4 then
		if once(R, "glance") then setPose(R, A, "look", 0.15) end
		A.P.look = clamp(wrap((yawOf(eggCenter(R) - A.pos) or A.yaw) - A.yaw), -1, 1) * sin(pi * seg(t, 6.0, 6.4))
	elseif t < 9.0 then
		if once(R, "run2") then setPose(R, A, "run", 0.15); startLoop(R, "Footsteps"); R.q2 = polyline(withStart(R, R.routes.chase2)) end
		walkAlong(R, R.q2, accel(seg(t, 6.4, 9.0)), dt)
	else
		if once(R, "reach") then setPose(R, A, "grab", 0.12); stopLoop(R, "Footsteps") end
		local y = yawOf(eggCenter(R) - A.pos); if y then A.yaw = lerpAngle(A.yaw, y, 1 - math.exp(-14 * dt)) end
		A.P.k = ease(seg(t, 9.0, 9.35))
		if t >= 9.4 and once(R, "grab") then R.egg.mode = "pick"; R.egg.pick0 = R.egg.cf; R.egg.pickT = R.now; sound(R, "Grab") end
		if t >= 9.55 and once(R, "carry") then setPose(R, A, "carry", 0.25) end
	end
	local b = base(R)
	local torso = A.pos + UP * 1.8
	if t < 2.4 then camFollow(R, CFrame.lookAt((b * CFrame.new(6, 3.2, 1)).Position, (b * CFrame.new(0, 3.0, -4)).Position), 8, dt)
	elseif t < 3.8 then camFollow(R, CFrame.lookAt((b * CFrame.new(2.5, 3.4, -9)).Position, torso + UP * 1.2), 4, dt)
	elseif t < 6.4 then camLook(R, torso - UP * 0.6 * A.P.k, 6, dt)
	elseif t < 9.0 then camFollow(R, CFrame.lookAt((b * CFrame.new(6, 3.4, 0.5)).Position, (b * CFrame.new(0, 3.0, -4)).Position), 5, dt)
	else
		local shot = CFrame.lookAt((b * CFrame.new(2.6, 2.4, -3.8)).Position, eggCenter(R):Lerp(torso, 0.3))
		if once(R, "grabCam") then camCut(R, shot); R.fov = 50 end
		camFollow(R, shot, 8, dt)
	end
end)

scene("BringHome", 9, function(R)
	R.A.P.moving = true; R.A.P.gait = 1
	R.h1, R.h2 = polyline(withStart(R, R.routes.home1)), polyline(R.routes.home2)
	setPose(R, R.A, "carry", 0.2); startLoop(R, "Footsteps")
	local b = base(R)
	camCut(R, CFrame.lookAt((b * CFrame.new(0, 4.2, 10)).Position, (b * CFrame.new(0, 2, -6)).Position)); R.fov = 60
end, function(R, t, dt)
	local A = R.A
	if t < 5.2 then walkAlong(R, R.h1, accel(seg(t, 0, 5.2)), dt)
	elseif t < 8.6 then
		if once(R, "walkIn") then A.P.gait = 0.6 end
		walkAlong(R, R.h2, decel(seg(t, 5.2, 8.6)), dt)
	else
		if once(R, "arrive") then A.P.moving = false; stopLoop(R, "Footsteps") end
		local y = yawOf(R.socket.Position - A.pos); if y then A.yaw = lerpAngle(A.yaw, y, 1 - math.exp(-10 * dt)) end
	end
	setDoors(R, ease(seg(t, 6.4, 7.9)))
	local b = base(R)
	local torso = A.pos + UP * 1.8
	if t < 4.2 then camFollow(R, CFrame.lookAt((b * CFrame.new(0, 4.2, 10)).Position, (b * CFrame.new(0, 2, -6)).Position), 6, dt)
	elseif t < 6.2 then
		if once(R, "sideShot") then camCut(R, CFrame.lookAt((R.entCF * CFrame.new(8, 3.5, 4)).Position, torso)) end
		camLook(R, torso, 7, dt)
	else
		local k = ease(seg(t, 6.6, 9.0))
		camFollow(R, CFrame.lookAt((b * CFrame.new(0, 5, 11)).Position:Lerp(R.incShot.Position, k), torso:Lerp(R.socket.Position + UP * 1.6, k)), 5, dt)
	end
end)

local ROCKS = { { 1.35, 0.24, 0.07 }, { 1.75, 0.24, 0.09 }, { 2.12, 0.22, 0.11 }, { 2.42, 0.2, 0.13 }, { 2.68, 0.18, 0.15 }, { 2.88, 0.16, 0.17 }, { 3.02, 0.13, 0.26 }, { 3.17, 0.13, 0.28 } }
scene("Hatch", 9, function(R)
	setPose(R, R.A, "push", 0.15); R.A.P.k = 0
	R.fov = 55
	R.mlight = Instance.new("PointLight"); R.mlight.Color = Config.MachineColor; R.mlight.Range = 12; R.mlight.Brightness = 0; R.mlight.Shadows = false
	R.mlight.Parent = part(R, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(R.socket.Position + UP * 3) })
end, function(R, t, dt)
	local A, E, W = R.A, R.egg, R.reward
	if t < 0.9 then A.P.k = ease(seg(t, 0.3, 0.55)) end
	if t >= 0.3 and t < 0.55 then
		if once(R, "slamStart") then E.mode = "manual"; E.from = E.cf end
		E.cf = E.from:Lerp(CFrame.new(R.socket.Position) * CFrame.Angles(0, R.socketYaw, 0), easeIn(seg(t, 0.3, 0.55)))
	end
	if t >= 0.55 and once(R, "socketed") then
		E.mode = "socket"; E.rx, E.rz = 0, 0
		sparks(R, R.socket.Position + UP * 0.3, Config.MachineColor, 14); shake(R, 0.7, 0.25); sound(R, "Slam"); R.mlight.Brightness = 4
	end
	if t >= 0.7 and t < 3.3 then setDoors(R, 1 - ease(seg(t, 0.7, 1.3))) elseif t >= 3.3 then setDoors(R, ease(seg(t, 3.3, 3.75))) end
	if t >= 0.9 and once(R, "settle") then setPose(R, A, "idle", 0.35) end
	if t >= 1.8 and once(R, "lean") then setPose(R, A, "lean", 0.5) end
	if t >= 1.3 and once(R, "hum") then startLoop(R, "Hum", 0.7) end
	if t >= 3.3 and once(R, "pause") then stopLoop(R, "Hum") end
	local ramp = seg(t, 1.3, 3.3)
	if t >= 0.55 and t < 3.3 then R.mlight.Brightness = lerp(R.mlight.Brightness, 1.2 + 2.2 * ramp * (0.5 + 0.5 * sin(t * (8 + 10 * ramp))), 1 - math.exp(-12 * dt))
	elseif t >= 3.3 and t < 3.8 then R.mlight.Brightness = lerp(R.mlight.Brightness, 0.3, 1 - math.exp(-10 * dt)) end
	if E.mode == "socket" then
		local rz, rx = 0, 0
		for _, s in ROCKS do local k = (t - s[1]) / s[2]; if k >= 0 and k <= 1 then local env = sin(k * pi); rz += s[3] * env * sin(k * pi * 4); rx += s[3] * 0.35 * env * sin(k * pi * 4 + 1.2) end end
		E.rz, E.rx = rz, rx
	end
	if (t >= 1.6 and once(R, "p1")) or (t >= 2.3 and once(R, "p2")) or (t >= 2.9 and once(R, "p3")) then sparks(R, R.socket.Position + UP * E.h * 0.5, Config.MachineColor, 3) end
	if t >= 2.95 and once(R, "vib") then shake(R, 0.18, 0.5) end
	if t >= 3.8 and once(R, "reveal") then
		E.m.Parent = nil; E.mode = "gone"
		local c = R.socket.Position + UP * E.h * 0.5
		sparks(R, c, Config.RevealColor, 26)
		emitAt(R, c, { color = Color3.new(1, 1, 1), count = 6, speed = 5, life = 0.5, size0 = 1.5, size1 = 4, tr0 = 0.4, spread = 180, accel = Vector3.zero })
		shockRing(R, R.socket.Position + UP * 0.2, Config.RevealColor, 12, 0.45)
		flash(R, c, Config.RevealColor, 9, 0.7, 24); sound(R, "Reveal"); shake(R, 0.45, 0.3)
		R.mlight.Brightness = 0
		W.m.Parent = R.FX; W.mode = "socket"; setScale(W, 0.55); W.popT = R.now
	end
	if W.popT then
		local k = R.now - W.popT
		setScale(W, k < 0.18 and lerp(0.55, 1.08, easeOut(k / 0.18)) or k < 0.33 and lerp(1.08, 1, ease((k - 0.18) / 0.15)) or 1)
		if k >= 0.33 then W.popT = nil end
	end
	if t >= 6.2 and once(R, "reachReward") then setPose(R, A, "grab", 0.2) end
	if t >= 6.2 and t < 7.4 then A.P.k = ease(seg(t, 6.2, 6.8)) end
	if t >= 7.0 and once(R, "lift") then W.mode = "manual"; W.from = W.cf; W.liftT = R.now; sound(R, "Grab") end
	if W.liftT then
		local k = clamp((R.now - W.liftT) / 0.5, 0, 1)
		setScale(W, lerp(1, Config.RewardCarryScale, ease(k)))
		W.cf = W.from:Lerp(carriedCF(R, W), ease(k))
		if k >= 1 then W.mode = "carried"; W.liftT = nil end
	end
	if t >= 7.4 and once(R, "carry2") then setPose(R, A, "carry", 0.3) end
	if t >= 7.6 then local y = yawOf((R.routes.place[2] or M(R, "SlotFront")) - A.pos); if y then A.yaw = lerpAngle(A.yaw, y, 1 - math.exp(-6 * dt)) end end
	if t < 4.0 then camFollow(R, R.incShot * CFrame.new(0, 0, -1.2 * ease(seg(t, 1.3, 3.8))), 8, dt)
	elseif t < 6.0 then
		R.noSafe = true
		local c = R.socket.Position + UP * W.h * 0.55
		local shot = CFrame.lookAt(c + R.incFront * 6.5 + UP * 0.4, c + UP * W.h * 0.1)
		if once(R, "hero") then camCut(R, shot); R.fov = 42 end
		camFollow(R, shot * CFrame.new(0, 0, -1.2 * ease(seg(t, 4.0, 6.0))), 6, dt)
	else
		if once(R, "medium") then camCut(R, R.incShot); R.fov = 55 end
		camFollow(R, R.incShot, 6, dt)
	end
end)

scene("Place", 9, function(R)
	R.path = polyline(withStart(R, R.routes.place))
	R.A.P.moving = true; R.A.P.gait = 0.6; setPose(R, R.A, "carry", 0.2); startLoop(R, "Footsteps", 0.6)
	local b = base(R)
	camCut(R, CFrame.lookAt((b * CFrame.new(4, 4.2, 9)).Position, (b * CFrame.new(0, 2, -5)).Position)); R.fov = 60
end, function(R, t, dt)
	local A, W = R.A, R.reward
	if t < 3.4 then walkAlong(R, R.path, ease(seg(t, 0, 3.4)), dt)
	else
		if once(R, "stopP") then A.P.moving = false; stopLoop(R, "Footsteps") end
		if t < 4.6 then local y = yawOf(M(R, "Slot") - A.pos); if y then A.yaw = lerpAngle(A.yaw, y, 1 - math.exp(-10 * dt)) end end
	end
	if t >= 3.5 and once(R, "placePose") then setPose(R, A, "place", 0.15) end
	if t >= 3.5 and t < 4.9 then A.P.k = ease(seg(t, 3.5, 4.2)) * (1 - ease(seg(t, 4.4, 4.9))) end
	if t >= 4.3 and once(R, "placed") then
		W.mode = "slot"; setScale(W, Config.SlotScale); W.spin = R.slotYaw
		sparks(R, R.slotTop + UP, Config.RevealColor, 10); flash(R, R.slotTop + UP, Config.RevealColor, 3, 0.5, 12); sound(R, "Place")
		local g = part(R, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = Config.RevealColor, Size = Vector3.new(0.08, 4, 4),
			CFrame = CFrame.new(R.slotTop + UP * 0.04) * CFrame.Angles(0, 0, pi / 2), Transparency = 1 })
		TweenService:Create(g, TweenInfo.new(0.6), { Transparency = 0.45 }):Play()
		local l = Instance.new("PointLight"); l.Color = Config.RevealColor; l.Range = 8; l.Brightness = 1.4; l.Shadows = false; l.Parent = g
	end
	if W.mode == "slot" then W.spin += dt * 0.6 end
	if t >= 4.6 and once(R, "stepBack") then setPose(R, A, "walk", 0.3); R.sb0 = A.pos end
	if t >= 4.6 and t < 5.5 then local np = stand(R, R.sb0 - fwdOf(A.yaw) * 3 * ease(seg(t, 4.6, 5.4))); A.P.phase -= flat(np - A.pos).Magnitude * 1.8; A.pos = np end
	if t >= 5.5 and once(R, "celebrate") then setPose(R, A, "celebrate", 0.25); sound(R, "Cheer") end
	if t >= 7.2 and once(R, "musicOut") and R.music then TweenService:Create(R.music, TweenInfo.new(1.8), { Volume = 0 }):Play() end
	local b = base(R)
	if t < 3.4 then camFollow(R, CFrame.lookAt((b * CFrame.new(4, 4.2, 9)).Position, (b * CFrame.new(0, 2, -5)).Position), 5, dt)
	elseif t < 5.0 then if once(R, "placeCam") then camCut(R, R.placeShot); R.fov = 55 end; camFollow(R, R.placeShot, 6, dt)
	else camFollow(R, R.placeShot:Lerp(R.finalCF, ease(seg(t, 5.0, 7.0))), 8, dt) end
end)

-- intro: drone flyover of the map, letterbox bars and a title card, then flash into the rift
local function titleGui(R)
	if R.title then return R.title end
	local g = Instance.new("ScreenGui"); g.Name = "TrailerTitle"; g.IgnoreGuiInset = true; g.ResetOnSpawn = false; g.DisplayOrder = 999
	local function bar(y, ay) local f = Instance.new("Frame"); f.BorderSizePixel = 0; f.BackgroundColor3 = Color3.new(0, 0, 0); f.AnchorPoint = Vector2.new(0, ay); f.Position = UDim2.fromScale(0, y); f.Size = UDim2.fromScale(1, 0); f.Parent = g; return f end
	local top, bot = bar(0, 0), bar(1, 1)
	local flashF = Instance.new("Frame"); flashF.BorderSizePixel = 0; flashF.BackgroundColor3 = Color3.fromRGB(255, 244, 214); flashF.Size = UDim2.fromScale(1, 1); flashF.BackgroundTransparency = 1; flashF.Parent = g
	local function label(text, size, y, font)
		local l = Instance.new("TextLabel"); l.BackgroundTransparency = 1; l.AnchorPoint = Vector2.new(0.5, 0.5); l.Position = UDim2.fromScale(0.5, y)
		l.Size = UDim2.fromScale(0.9, size); l.TextScaled = true; l.Font = font or Enum.Font.FredokaOne; l.Text = text; l.TextColor3 = Color3.new(1, 1, 1); l.TextTransparency = 1; l.Parent = g
		local st = Instance.new("UIStroke"); st.Thickness = 3; st.Color = Color3.fromRGB(60, 25, 10); st.Transparency = 1; st.Parent = l
		return l, st
	end
	local t1, s1 = label(Config.TitleText or "HATCH AN ANIME", 0.16, 0.45)
	local gr = Instance.new("UIGradient"); gr.Rotation = 90; gr.Color = ColorSequence.new(Color3.fromRGB(255, 240, 170), Color3.fromRGB(255, 160, 60)); gr.Parent = t1
	local t2, s2 = label(Config.TaglineText or "Catch it. Hatch it. Collect them all.", 0.055, 0.58, Enum.Font.GothamBold)
	local t3, s3 = label(Config.OutroText or "PLAY NOW ON ROBLOX", 0.09, 0.82)
	local gr3 = gr:Clone(); gr3.Parent = t3
	g.Parent = player:WaitForChild("PlayerGui")
	R.title = { g = g, top = top, bot = bot, flash = flashF, t1 = t1, s1 = s1, t2 = t2, s2 = s2, t3 = t3, s3 = s3 }
	table.insert(R.restore, function() g:Destroy() end)
	return R.title
end
local function bars(T, k) T.top.Size = UDim2.fromScale(1, 0.11 * k); T.bot.Size = UDim2.fromScale(1, 0.11 * k) end
local function fadeText(l, st, a) l.TextTransparency = 1 - a; st.Transparency = 1 - a end

scene("Intro", 7, function(R)
	local T = titleGui(R)
	local land = M(R, "Land")
	local fwd = unitOr(flat(R.M.Land.CFrame.LookVector), Vector3.new(0, 0, -1))
	local side = fwd:Cross(UP)
	local focus = M(R, "EggStart"):Lerp(M(R, "EggEnd"), 0.5)
	R.introA = CFrame.lookAt(land - fwd * 150 + side * 90 + UP * 95, focus)
	R.introB = CFrame.lookAt(land - fwd * 55 - side * 35 + UP * 38, focus + UP * 8)
	camCut(R, R.introA); R.fov = 50
	R.A.visible = false
end, function(R, t, dt)
	local T = R.title
	local k = ease(seg(t, 0, 7))
	local cf = R.introA:Lerp(R.introB, k)
	camFollow(R, cf * CFrame.Angles(0, 0, 0.04 * sin(t * 0.6)), 4, dt)
	R.fov = 50 - 6 * k
	bars(T, ease(seg(t, 0, 1)))
	fadeText(T.t1, T.s1, ease(seg(t, 1.0, 2.0)) * (1 - ease(seg(t, 5.0, 5.8))))
	T.t1.Size = UDim2.fromScale(0.8 + 0.1 * k, 0.15 + 0.02 * k)
	fadeText(T.t2, T.s2, ease(seg(t, 2.0, 2.8)) * (1 - ease(seg(t, 5.0, 5.8))))
	T.flash.BackgroundTransparency = 1 - 0.9 * (ease(seg(t, 6.3, 6.8)) * (1 - ease(seg(t, 6.85, 7.0))))
	if t >= 6.85 and once(R, "introOut") then T.flash.BackgroundTransparency = 1 end
end)
-- outro title on the final hold, bars stay for the whole video
local placeScene
for _, sc in SCENES do if sc.name == "Place" then placeScene = sc end end
local placeUpdate = placeScene.update
placeScene.update = function(R, t, dt)
	placeUpdate(R, t, dt)
	local T = R.title
	if not T then return end
	bars(T, 1)
	fadeText(T.t1, T.s1, ease(seg(t, 6.6, 7.3)))
	fadeText(T.t3, T.s3, ease(seg(t, 7.0, 7.7)))
end
for _, sc in SCENES do
	if sc.name ~= "Intro" and sc.name ~= "Place" then
		local u = sc.update
		sc.update = function(R, t, dt) u(R, t, dt); if R.title then bars(R.title, 1) end end
	end
end
for i, sc in SCENES do if sc.name == "Intro" then table.remove(SCENES, i); table.insert(SCENES, 1, sc); break end end

local function hideForRecording(R)
	local function remember(fn) table.insert(R.restore, fn) end
	for _, t in Enum.CoreGuiType:GetEnumItems() do
		if t ~= Enum.CoreGuiType.All then
			local ok, on = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, t)
			if ok and on then pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, false); remember(function() pcall(StarterGui.SetCoreGuiEnabled, StarterGui, t, true) end) end
		end
	end
	local okT, top = pcall(StarterGui.GetCore, StarterGui, "TopbarEnabled")
	if okT and top ~= false then pcall(StarterGui.SetCore, StarterGui, "TopbarEnabled", false); remember(function() pcall(StarterGui.SetCore, StarterGui, "TopbarEnabled", true) end) end
	for _, n in { "ChatWindowConfiguration", "ChatInputBarConfiguration", "BubbleChatConfiguration" } do
		local c = TextChatService:FindFirstChild(n)
		if c and c.Enabled then c.Enabled = false; remember(function() c.Enabled = true end) end
	end
	if UserInputService.MouseIconEnabled then UserInputService.MouseIconEnabled = false; remember(function() UserInputService.MouseIconEnabled = true end) end
	local function addGui(g)
		if g == statusGui or g.Name == "TrailerTitle" or not g:IsA("LayerCollector") or R.offSet[g] then return end
		if g:IsA("SurfaceGui") and not Config.HideSurfaceGuis then return end
		if g.Enabled then R.offSet[g] = true; table.insert(R.off, g); g.Enabled = false end
	end
	for _, root in { player:WaitForChild("PlayerGui"), workspace } do
		for _, d in root:GetDescendants() do
			addGui(d)
			if d:IsA("Humanoid") and d.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then local old = d.DisplayDistanceType; d.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None; remember(function() if d.Parent then d.DisplayDistanceType = old end end)
			elseif d:IsA("ProximityPrompt") and d.Enabled then d.Enabled = false; remember(function() if d.Parent then d.Enabled = true end end)
			elseif d:IsA("Highlight") and d.Enabled then d.Enabled = false; remember(function() if d.Parent then d.Enabled = true end end) end
		end
		table.insert(R.conns, root.DescendantAdded:Connect(function(d) task.defer(function() if run == R and d.Parent then addGui(d); if d:IsA("ProximityPrompt") then d.Enabled = false end end end) end))
	end
	local function hideModel(m) for _, d in m:GetDescendants() do if (d:IsA("BasePart") or d:IsA("Decal")) then table.insert(R.hidden, d) end end end
	for _, p in Players:GetPlayers() do if p.Character then hideModel(p.Character) end end
	table.insert(R.conns, Players.PlayerAdded:Connect(function(p) p.CharacterAdded:Connect(function(c) if run == R then task.wait(); hideModel(c) end end) end))
	for _, p in Players:GetPlayers() do if p ~= player then table.insert(R.conns, p.CharacterAdded:Connect(function(c) if run == R then task.wait(); hideModel(c) end end)) end end
	for _, tag in Config.HideTags do
		for _, x in CollectionService:GetTagged(tag) do hideModel(x) end
		table.insert(R.conns, CollectionService:GetInstanceAddedSignal(tag):Connect(function(x) if run == R then task.wait(); hideModel(x) end end))
	end
	local pm = player:FindFirstChild("PlayerScripts") and player.PlayerScripts:FindFirstChild("PlayerModule")
	if pm then local ok, controls = pcall(function() return require(pm):GetControls() end); if ok and controls then controls:Disable(); remember(function() controls:Enable() end) end end
	if Config.ColorGrade then
		local cc = Instance.new("ColorCorrectionEffect"); cc.Name = "TrailerGrade"; cc.Saturation = 0.22; cc.Contrast = 0.12; cc.Brightness = 0.02; cc.TintColor = Color3.fromRGB(255, 248, 238); cc.Parent = Lighting
		local bl = Instance.new("BloomEffect"); bl.Name = "TrailerBloom"; bl.Intensity = 0.7; bl.Size = 28; bl.Threshold = 0.9; bl.Parent = Lighting
		local sr = Instance.new("SunRaysEffect"); sr.Name = "TrailerRays"; sr.Intensity = 0.06; sr.Spread = 0.6; sr.Parent = Lighting
		local dof = Instance.new("DepthOfFieldEffect"); dof.Name = "TrailerDOF"; dof.FarIntensity = 0.35; dof.FocusDistance = 14; dof.InFocusRadius = 18; dof.NearIntensity = 0; dof.Parent = Lighting
		R.dof = dof
		if Config.ClockTime then local ck = Lighting.ClockTime; R.clock = Config.ClockTime; remember(function() R.clock = nil; Lighting.ClockTime = ck end) end
		remember(function() cc:Destroy(); bl:Destroy(); sr:Destroy(); dof:Destroy() end)
	end
	local cam = workspace.CurrentCamera
	local ct, cs, fov = cam.CameraType, cam.CameraSubject, cam.FieldOfView
	cam.CameraType = Enum.CameraType.Scriptable
	remember(function() cam.CameraType = ct; cam.CameraSubject = cs; cam.FieldOfView = fov end)
end

local function cleanup(R, msg)
	if R.cleaned then return end
	R.cleaned = true
	pcall(RunService.UnbindFromRenderStep, RunService, "TrailerCinematic")
	for _, c in R.conns do c:Disconnect() end
	if R.doors then for _, d in R.doors do if d.obj.Parent then setPivot(d.obj, d.closed) end end end
	for _, g in R.off do if g.Parent then g.Enabled = true end end
	for _, d in R.hidden do if d.Parent then d.LocalTransparencyModifier = 0 end end
	for i = #R.restore, 1, -1 do pcall(R.restore[i]) end
	if R.A then R.A.model:Destroy() end
	if R.FX then R.FX:Destroy() end
	if run == R then run = nil end
	if msg then status(msg, 4) end
end

local function update(R, dt)
	dt = math.min(dt, 1 / 20)
	R.now = os.clock() - R.t0
	local acc = 0
	for i, sc in SCENES do
		if R.now < acc + sc.dur or i == #SCENES then
			if R.scene ~= i then R.scene = i; R.cues = {}; sc.start(R) end
			local k = sc.base / sc.dur
			sc.update(R, (R.now - acc) * k, dt * k)
			break
		end
		acc += sc.dur
	end
	actorApply(R)
	propApply(R, R.egg); propApply(R, R.reward)
	for _, g in R.off do if g.Enabled then g.Enabled = false end end
	for _, d in R.hidden do d.LocalTransparencyModifier = 1 end
	local ox, oy, rz = 0, 0, 0
	for i = #R.shakes, 1, -1 do
		local s = R.shakes[i]
		local k = (R.now - s.t0) / s.dur
		if k >= 1 then table.remove(R.shakes, i) else local f = (1 - k) ^ 2 * s.amp; ox += math.noise(s.seed, R.now * 25) * f; oy += math.noise(s.seed + 5, R.now * 25) * f; rz += math.noise(s.seed + 9, R.now * 20) * f end
	end
	local camCF = R.camCF
	if R.scene and R.scene > 1 and not R.noSafe and R.A.visible then
		local focus = R.A.pos + UP * 2
		local to = camCF.Position - focus
		if to.Magnitude > 1 then local hit = workspace:Raycast(focus, to, R.ray); if hit then camCF = CFrame.new(hit.Position - to.Unit * 0.6) * camCF.Rotation end end
	end
	R.noSafe = false
	local cam = workspace.CurrentCamera
	cam.CameraType = Enum.CameraType.Scriptable
	local hand = CFrame.new(math.noise(R.now * 0.35, 1) * 0.12, math.noise(R.now * 0.35, 7) * 0.1, 0) * CFrame.Angles(0, 0, math.noise(R.now * 0.3, 13) * 0.006)
	cam.CFrame = camCF * hand * CFrame.new(ox * 0.25, oy * 0.25, 0) * CFrame.Angles(0, 0, rz * 0.03)
	cam.FieldOfView = lerp(cam.FieldOfView, R.fov or 60, 1 - math.exp(-6 * dt))
	if R.clock then Lighting.ClockTime = R.clock end
	if R.dof then R.dof.FocusDistance = lerp(R.dof.FocusDistance, (camCF.Position - (R.A.pos + UP * 2)).Magnitude, 1 - math.exp(-8 * dt)) end
	if R.now >= R.total + 0.25 then cleanup(R, "Trailer finished") end
end

local REQUIRED = { "Rift", "Land", "EggStart", "EggEnd", "Stumble", "Grab", "IncubatorFront", "SlotFront", "Slot" }
local function nameMatch(n, list) n = n:lower(); for _, p in list do if n:find(p:lower(), 1, true) then return true end end return false end
local function findMyPlot()
	local root = resolve(Config.PlotsFolder) or workspace
	for _, d in root:GetDescendants() do
		if (d:IsA("Model") or d:IsA("Folder")) and not d:FindFirstChildOfClass("Humanoid") then
			for _, a in Config.PlotOwnerAttributes do
				local v = d:GetAttribute(a)
				if v ~= nil and (v == player.UserId or tostring(v) == tostring(player.UserId) or v == player.Name) then return d end
			end
			local ov = d:FindFirstChild("Owner")
			if ov and ((ov:IsA("ObjectValue") and ov.Value == player) or ((ov:IsA("IntValue") or ov:IsA("NumberValue")) and ov.Value == player.UserId) or (ov:IsA("StringValue") and ov.Value == player.Name)) then return d end
		end
	end
end
local function slotFree(s)
	if s:GetAttribute("Occupied") == true then return false end
	local id = s:GetAttribute("CharacterId"); if id ~= nil and id ~= "" and id ~= 0 then return false end
	for _, c in s:GetDescendants() do if c:IsA("Humanoid") then return false end end
	return true
end
local function incubatorFront(inc)
	local cf, size = inc:GetBoundingBox()
	local gl, gr = inc:FindFirstChild("GlassLeft", true), inc:FindFirstChild("GlassRight", true)
	local dir
	if gl and gr then dir = flat((pivotOf(gl).Position + pivotOf(gr).Position) / 2 - cf.Position) end
	if not dir or dir.Magnitude < 0.5 then dir = flat(-inc:GetPivot().LookVector) end
	dir = unitOr(dir, Vector3.zAxis)
	local e = abs(dir:Dot(cf.RightVector)) * size.X / 2 + abs(dir:Dot(cf.LookVector)) * size.Z / 2
	return Vector3.new(cf.Position.X, cf.Position.Y - size.Y / 2, cf.Position.Z) + dir * (e + 2.5)
end
local function virtual(p, look) return { Position = p, CFrame = look and CFrame.lookAt(p, look) or CFrame.new(p), Size = Vector3.one } end
local function prepare(R)
	local missing = {}
	local folder = resolve(Config.MarkersFolder)
	R.M = {}
	local eggSrc, rewardSrc = resolve(Config.Models.PirateEgg), resolve(Config.Models.Reward)
	local plot = Config.AutoPlot and findMyPlot() or nil
	-- markers were placed around Config.MarkerPlot; they move with you to the plot you own
	local srcPlot, xf = resolve(Config.MarkerPlot), CFrame.identity
	if plot and srcPlot and plot ~= srcPlot and plot:FindFirstChild("TempleAnchor") and srcPlot:FindFirstChild("TempleAnchor") then
		xf = plot.TempleAnchor.CFrame * srcPlot.TempleAnchor.CFrame:Inverse()
	end
	if folder then for _, c in folder:GetChildren() do if c:IsA("BasePart") then local cf = xf * c.CFrame; R.M[c.Name] = { CFrame = cf, Position = cf.Position, Size = c.Size } end end end
	local inc
	if plot then for _, d in plot:GetDescendants() do if d:IsA("Model") and nameMatch(d.Name, Config.IncubatorNames) and not nameMatch(d.Parent.Name, Config.IncubatorNames) then inc = d; break end end end
	inc = inc or resolve(Config.Models.Incubator)
	if inc and not R.M.IncubatorFront then R.M.IncubatorFront = virtual(incubatorFront(inc)) end
	if plot then
		local center = plot:IsA("Model") and plot:GetBoundingBox().Position or (inc and inc:GetPivot().Position) or Vector3.zero
		if not R.M.Slot then
			local near, best, bd = inc and inc:GetPivot().Position or center, nil, nil
			for _, d in plot:GetDescendants() do
				if (d:IsA("BasePart") or d:IsA("Model")) and nameMatch(d.Name, Config.SlotNames) and not nameMatch(d.Parent.Name, Config.SlotNames) and slotFree(d) then
					local dist = (pivotOf(d).Position - near).Magnitude
					if not bd or dist < bd then best, bd = d, dist end
				end
			end
			if best then
				local cf, size
				if best:IsA("Model") then cf, size = best:GetBoundingBox() else cf, size = best.CFrame, best.Size end
				R.M.Slot = { Position = cf.Position, CFrame = cf, Size = size }
				if not R.M.SlotFront then
					local dir = unitOr(flat(center - cf.Position), Vector3.zAxis)
					R.M.SlotFront = virtual(cf.Position + dir * (max(size.X, size.Z) / 2 + 2.5), cf.Position)
				end
			end
		end
		if not R.M.TempleEntrance then
			for _, d in plot:GetDescendants() do
				if (d:IsA("BasePart") or d:IsA("Model")) and nameMatch(d.Name, Config.EntranceNames) then local p = pivotOf(d).Position; R.M.TempleEntrance = virtual(p, Vector3.new(center.X, p.Y, center.Z)); break end
			end
		end
	end
	for _, n in REQUIRED do if not R.M[n] then table.insert(missing, (n == "Slot" or n == "SlotFront" or n == "IncubatorFront") and (n .. " (no free slot/incubator found in your plot, and no marker)") or ("marker " .. n)) end end
	if not eggSrc then table.insert(missing, "PirateEgg model") end
	if not rewardSrc then table.insert(missing, "Reward model") end
	if not inc then table.insert(missing, "Incubator (none in your plot and Config path not found)") end
	if #missing > 0 then error("Missing: " .. table.concat(missing, ", "), 0) end
	if plot then status("Using your plot: " .. plot.Name, 3) end
	R.FX = Instance.new("Folder"); R.FX.Name = "TrailerFX"; R.FX.Parent = workspace
	R.riftColor = Config.RiftColor
	R.durOf = {}; R.total = 0
	for _, sc in SCENES do sc.dur = Config.Durations[sc.name] or sc.base; R.durOf[sc.name] = sc.dur; R.total += sc.dur end
	local model
	pcall(function() model = Players:CreateHumanoidModelFromDescription(Players:GetHumanoidDescriptionFromUserId(player.UserId), Enum.HumanoidRigType.R15) end)
	if not model and player.Character then player.Character.Archivable = true; model = player.Character:Clone() end
	if not model then error("Couldn't build your avatar", 0) end
	for _, d in model:GetDescendants() do
		if d:IsA("BaseScript") or d:IsA("Tool") or d:IsA("BillboardGui") or d:IsA("ForceField") then d:Destroy()
		elseif d:IsA("BasePart") then d.CanCollide, d.CanQuery, d.CanTouch = false, false, false end
	end
	model.Name = "TrailerActor"
	local hum = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (hum and root) then error("Avatar model has no Humanoid/HumanoidRootPart", 0) end
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	hum.PlatformStand = true
	root.Anchored = true
	model.Parent = R.FX
	local A = { model = model, hum = hum, root = root, joints = {}, tracks = {}, parts = {}, P = { look = 0, k = 0, phase = 0, moving = false },
		pose = "idle", blend0 = 0, blendDur = 0, visible = false, pos = root.Position, yaw = 0, handsLocal = Vector3.new(0, 0.3, -1.4) }
	-- new avatar joints (AnimationConstraint + BallSocket) -> rigid Motor6Ds the poses can drive
	for _, c in model:GetDescendants() do
		if c:IsA("AnimationConstraint") and c.Attachment0 and c.Attachment1 then
			local m6 = Instance.new("Motor6D"); m6.Name = c.Name
			m6.Part0, m6.Part1 = c.Attachment0.Parent, c.Attachment1.Parent
			m6.C0, m6.C1 = c.Attachment0.CFrame, c.Attachment1.CFrame
			m6.Parent = c.Parent
			c:Destroy()
		elseif c:IsA("BallSocketConstraint") or c:IsA("HingeConstraint") then c:Destroy() end
	end
	for key, n in JOINT do local j = model:FindFirstChild(n, true); if j and j:IsA("Motor6D") then A.joints[key] = j end end
	A.c0 = {}
	for key, j in A.joints do A.c0[key] = j.C0 end
	if hum.RigType == Enum.HumanoidRigType.R15 then A.offset = hum.HipHeight + root.Size.Y / 2
	else local cf, size = model:GetBoundingBox(); A.offset = root.Position.Y - (cf.Position.Y - size.Y / 2) end
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	for name, id in Config.Animations do
		if id ~= "" then local a = Instance.new("Animation"); a.AnimationId = id; local ok, tr = pcall(animator.LoadAnimation, animator, a); if ok then A.tracks[name:lower()] = tr end end
	end
	for _, d in model:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then table.insert(A.parts, d) end end
	R.A = A
	R.egg = prepProp(eggSrc, Config.EggScale, Config.EggHeight); R.egg.mode = "hidden"
	R.reward = prepProp(rewardSrc, 1, Config.RewardHeight); R.reward.mode = "hidden"
	R.inc = inc; R.doors = {}
	for _, n in { "GlassLeft", "GlassRight" } do local d = inc:FindFirstChild(n, true); if d then table.insert(R.doors, { obj = d, closed = pivotOf(d), dir = n == "GlassLeft" and -1 or 1 }) end end
	local anchor = inc:FindFirstChild("EggAnchor", true)
	if anchor and anchor:IsA("Attachment") then R.socket = CFrame.new(anchor.WorldPosition)
	elseif anchor and anchor:IsA("BasePart") then R.socket = CFrame.new(anchor.Position - UP * anchor.Size.Y / 2)
	elseif anchor and anchor:IsA("Model") then local acf, asz = anchor:GetBoundingBox(); R.socket = CFrame.new(acf.Position - UP * asz.Y / 2)
	else
		local plat = inc:FindFirstChild("EggPlatform", true)
		if plat then local pcf, ps = plat:IsA("Model") and plat:GetBoundingBox() or plat.CFrame, plat:IsA("Model") and select(2, plat:GetBoundingBox()) or plat.Size; R.socket = CFrame.new(pcf.Position + UP * ps.Y / 2)
		else R.socket = CFrame.new((inc:GetPivot() * CFrame.new(0, 2.25, 1.5)).Position) end
	end
	R.ray = RaycastParams.new(); R.ray.FilterType = Enum.RaycastFilterType.Exclude; R.ray.RespectCanCollide = true
	local ignore = { R.FX, folder }
	for _, p in Players:GetPlayers() do if p.Character then table.insert(ignore, p.Character) end end
	R.ray.FilterDescendantsInstances = ignore
	do -- sit the egg / character on the visible platform surface
		local h = workspace:Raycast(R.socket.Position + UP * 4, Vector3.new(0, -8, 0), R.ray)
		if h and h.Position.Y > R.socket.Position.Y then R.socket = CFrame.new(h.Position) end
	end
	R.incFront = unitOr(flat(M(R, "IncubatorFront") - R.socket.Position), Vector3.zAxis)
	R.socketYaw = (yawOf(R.incFront) or 0) + math.rad(Config.RewardYawOffset)
	local incSide = R.incFront:Cross(UP)
	R.incShot = R.M.IncubatorCam and R.M.IncubatorCam.CFrame or CFrame.lookAt(R.socket.Position + R.incFront * 11 + incSide * 4 + UP * 3.5, R.socket.Position + UP * 1.6)
	local slot = R.M.Slot
	R.slotTop = slot.Position + UP * (slot.Size.Y / 2 + Config.SlotLift)
	local sf = M(R, "SlotFront")
	R.slotYaw = (yawOf(sf - slot.Position) or 0) + math.rad(Config.RewardYawOffset)
	local dirS = unitOr(flat(slot.Position - sf), Vector3.new(0, 0, -1))
	local sideS = dirS:Cross(UP)
	local mid = sf:Lerp(slot.Position, 0.5)
	R.placeShot = CFrame.lookAt(mid + sideS * 7.5 - dirS * 1.5 + UP * 3, mid + UP * 2)
	R.finalCF = R.M.FinalCam and R.M.FinalCam.CFrame or CFrame.lookAt(slot.Position - dirS * 20 + sideS * 8 + UP * 11, slot.Position:Lerp(sf, 0.4) + UP * 2.5)
	status("Planning routes…")
	local land, stum, grab = stand(R, M(R, "Land")), stand(R, M(R, "Stumble")), stand(R, M(R, "Grab"))
	local incF, slotF = stand(R, M(R, "IncubatorFront")), stand(R, M(R, "SlotFront"))
	R.routes = { chase1 = route(R, land, stum), chase2 = route(R, stum, grab) }
	if R.M.TempleEntrance then
		local ent = stand(R, M(R, "TempleEntrance"))
		R.routes.home1, R.routes.home2 = route(R, grab, ent), route(R, ent, incF)
		R.entCF = R.M.TempleEntrance.CFrame
	else
		local all = route(R, grab, incF)
		local c = math.max(2, math.floor(#all * 0.65))
		R.routes.home1 = { table.unpack(all, 1, c) }
		R.routes.home2 = { table.unpack(all, c, #all) }
		if #R.routes.home2 < 2 then table.insert(R.routes.home2, incF) end
		R.entCF = CFrame.lookAt(all[c], all[c] + unitOr(flat(incF - all[c]), Vector3.zAxis))
	end
	local pts = { incF }
	for i = 1, 3 do local m = R.M["SlotPath" .. i]; if m then table.insert(pts, stand(R, m.Position)) end end
	table.insert(pts, slotF)
	R.routes.place = { incF }
	for i = 1, #pts - 1 do local seg2 = route(R, pts[i], pts[i + 1]); for j = 2, #seg2 do table.insert(R.routes.place, seg2[j]) end end
	local list = { model, R.egg.m, R.reward.m }
	for _, id in Config.Sounds do if id ~= "" then table.insert(list, id) end end
	for _, id in Config.Animations do if id ~= "" then table.insert(list, id) end end
	local done = false
	task.spawn(function() pcall(ContentProvider.PreloadAsync, ContentProvider, list); done = true end)
	local t0 = os.clock()
	while not done and os.clock() - t0 < 8 do status("Loading trailer assets…"); task.wait(0.2) end
	for i = Config.StartDelay, 1, -1 do if run ~= R then return end status("Trailer starts in " .. i .. " — start recording"); task.wait(1) end
	if run ~= R then return end
	statusGui.Enabled = false
	hideForRecording(R)
	local hum0 = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum0 then table.insert(R.conns, hum0.Died:Connect(function() cleanup(R, "Trailer stopped (character died)") end)) end
	table.insert(R.conns, player.CharacterAdded:Connect(function() cleanup(R, "Trailer stopped (respawn)") end))
	R.t0 = os.clock(); R.now = 0
	RunService:BindToRenderStep("TrailerCinematic", Enum.RenderPriority.Camera.Value + 2, function(dt)
		if run ~= R then return end
		local ok, err = pcall(update, R, dt)
		if not ok then warn("[Trailer] stopped after an error:", err); cleanup(R, "Trailer stopped: " .. tostring(err)) end
	end)
end

local function start()
	if run then return end
	local R = { restore = {}, conns = {}, off = {}, offSet = {}, hidden = {}, shakes = {}, loops = {}, cues = {}, now = 0 }
	run = R
	task.spawn(function()
		local ok, err = pcall(prepare, R)
		if not ok then warn("[Trailer]", err); cleanup(R, tostring(err)) end
	end)
end
local function stop() if run then cleanup(run, "Trailer cancelled") end end

local cmd = Instance.new("TextChatCommand"); cmd.Name = "TrailerStart"; cmd.PrimaryAlias = Config.Command; cmd.Parent = TextChatService
cmd.Triggered:Connect(function(src) if src.UserId == player.UserId then if run then stop(); task.wait(0.1) end if _G.TrailerPicker then _G.TrailerPicker() else start() end end end)
local cmd2 = Instance.new("TextChatCommand"); cmd2.Name = "TrailerStop"; cmd2.PrimaryAlias = Config.StopCommand; cmd2.Parent = TextChatService
cmd2.Triggered:Connect(function(src) if src.UserId == player.UserId then stop() end end)
UserInputService.InputBegan:Connect(function(i, gp) if not gp and i.KeyCode == Config.Key then if run then stop() else start() end end end)
player:GetAttributeChangedSignal("TrailerGo"):Connect(function() if player:GetAttribute("TrailerGo") then start() else stop() end end)

_G.TrailerStartV1 = start
