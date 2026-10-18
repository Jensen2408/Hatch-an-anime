--[[ StarterPlayerScripts.TrailerShots  (owner only)
Three clean cinematic camera shots for screen-recorded videos. No UI, no text, no player list.
  Shift+1 = River Run      (low glide along the egg river, rising into a wide reveal)
  Shift+2 = Temple Hero    (slow orbit + push-in on YOUR temple and characters)
  Shift+3 = Grand Tour     (high sweeping crane over the whole map)
  Backspace = stop.  Each shot holds 1.5 s on black-free frame before & after for clean cuts.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local PPS = game:GetService("ProximityPromptService")
local player = Players.LocalPlayer
if player.UserId ~= 168774222 and not RunService:IsStudio() then return end
local cam = workspace.CurrentCamera

local function myPlot()
	for _, p in workspace.Plots:GetChildren() do if p:GetAttribute("OwnerUserId") == player.UserId then return p end end
	return workspace.Plots:FindFirstChild("TemplePlot01")
end

-- smooth path through points (Catmull-Rom) + look target path
local function catmull(p0, p1, p2, p3, t)
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end
local function along(pts, a)
	local n = #pts
	local f = math.clamp(a, 0, 1) * (n - 1)
	local i = math.min(math.floor(f) + 1, n - 1)
	local t = f - (i - 1)
	return catmull(pts[math.max(i - 1, 1)], pts[i], pts[i + 1], pts[math.min(i + 2, n)], t)
end
local function ease(x) return x < 0.5 and 4 * x * x * x or 1 - (-2 * x + 2) ^ 3 / 2 end

local hidden, running = {}, nil
local function hideAll(on)
	if on then
		for _, g in player.PlayerGui:GetChildren() do if g:IsA("LayerCollector") and g.Enabled then hidden[g] = true; g.Enabled = false end end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)
		pcall(function() StarterGui:SetCore("TopbarEnabled", false) end)
		PPS.Enabled = false
		for _, root in { workspace, player.PlayerGui } do
			for _, b in root:GetDescendants() do if b:IsA("BillboardGui") and b.Enabled then hidden[b] = true; b.Enabled = false end end
		end
		for _, p in Players:GetPlayers() do local c = p.Character; if c then for _, d in c:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 1 end end end end
	else
		for g in hidden do if g.Parent then g.Enabled = true end end; table.clear(hidden)
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
		pcall(function() StarterGui:SetCore("TopbarEnabled", true) end)
		PPS.Enabled = true
		for _, p in Players:GetPlayers() do local c = p.Character; if c then for _, d in c:GetDescendants() do if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = 0 end end end end
	end
end
-- keep floating labels hidden if they spawn mid-shot
do
	local list, acc = {}, 1
	RunService.RenderStepped:Connect(function(dt)
		if not running then return end
		acc += dt
		if acc > 0.4 then
			acc = 0; table.clear(list)
			for _, root in { player.PlayerGui, workspace } do
				for _, d in root:GetDescendants() do if d:IsA("BillboardGui") or (d:IsA("SurfaceGui") and root == player.PlayerGui) or (d:IsA("ScreenGui")) then table.insert(list, d) end end
			end
		end
		for _, g in list do if g.Parent and g.Enabled then hidden[g] = true; g.Enabled = false end end
	end)
end
player.PlayerGui.DescendantAdded:Connect(function(d) if running and d:IsA("BillboardGui") then task.defer(function() if running and d.Enabled then hidden[d] = true; d.Enabled = false end end) end end)
local watch = workspace.DescendantAdded:Connect(function(d) if running and d:IsA("BillboardGui") then task.defer(function() if running and d.Enabled then hidden[d] = true; d.Enabled = false end end) end end)

local function play(shot)
	if running then return end
	running = shot
	local prevType, prevFov = cam.CameraType, cam.FieldOfView
	hideAll(true)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = shot.fov or 50
	local t0, hold = os.clock(), 1.5
	local conn
	conn = RunService.RenderStepped:Connect(function()
		if running ~= shot then return end
		local el = os.clock() - t0
		local a = ease(math.clamp((el - hold) / shot.duration, 0, 1))
		local pos, look = along(shot.cam, a), along(shot.look, a)
		local roll = shot.roll and math.rad(shot.roll * math.sin(a * math.pi)) or 0
		cam.CFrame = CFrame.lookAt(pos, look) * CFrame.Angles(0, 0, roll)
		if shot.fovTo then cam.FieldOfView = (shot.fov or 50) + (shot.fovTo - (shot.fov or 50)) * a end
		if el > shot.duration + hold * 2 then running = false end
	end)
	repeat task.wait() until running ~= shot
	conn:Disconnect()
	cam.CameraType, cam.FieldOfView = prevType, prevFov
	hideAll(false)
	running = nil
end

local function shots()
	local plot = myPlot()
	local A = plot.TempleAnchor.Position
	-- temple front = the side the plot spawn is on
	local flat = (plot.PlotSpawn.Position - A) * Vector3.new(1, 0, 1)
	local forward = flat.Magnitude > 1 and flat.Unit or Vector3.new(0, 0, 1)
	local right = forward:Cross(Vector3.yAxis)
	local temple = plot:FindFirstChild("Temple")
	local tc = temple and temple:GetBoundingBox().Position or (A + Vector3.new(0, 20, 0))
	local riverC = Vector3.new(0, 31, 20)
	local v = Vector3.new
	return {
		-- 1) RIVER RUN: skim low over the water following eggs, then lift into a wide reveal
		{ duration = 16, fov = 55, fovTo = 65, roll = 4,
			cam = { riverC + v(-95, 4, 10), riverC + v(-60, 3, 4), riverC + v(-20, 3.5, -2), riverC + v(20, 6, 0), riverC + v(55, 22, 20), riverC + v(70, 60, 70) },
			look = { riverC + v(-40, 0, 0), riverC + v(-10, 0, 0), riverC + v(30, 0, 0), riverC + v(60, 2, 0), riverC + v(20, 0, -20), riverC + v(0, 0, -10) } },
		-- 2) TEMPLE HERO: low orbit around your temple, pushing in on the characters
		{ duration = 18, fov = 40, fovTo = 30,
			cam = { A + forward * 110 + right * -80 + v(0, 6, 0), A + forward * 95 + right * -25 + v(0, 14, 0), A + forward * 85 + right * 35 + v(0, 24, 0), A + forward * 70 + right * 70 + v(0, 32, 0), A + forward * 60 + right * 20 + v(0, 18, 0), A + forward * 52 + v(0, 10, 0) },
			look = { tc, tc + v(0, 2, 0), tc + v(0, 2, 0), tc, tc - v(0, 6, 0), A + forward * 12 + v(0, 8, 0) } },
		-- 3) GRAND TOUR: high crane sweep across every temple, the river and the torii
		{ duration = 22, fov = 60, fovTo = 52, roll = -3,
			cam = { v(-330, 70, -260), v(-150, 95, -220), v(80, 110, -200), v(260, 95, -40), v(240, 80, 230), v(0, 120, 330), v(-260, 90, 220) },
			look = { v(-160, 20, -110), v(-60, 25, -60), v(60, 25, -60), v(120, 25, 20), v(80, 25, 120), v(0, 25, 40), v(-120, 25, 80) } },
	}
end

local shatter, superJump, spinUp, slamDown, waitBeats, slowmo, shake, dash
local beatOn = false
---------------------------------------------------------------- SCENE 4: "IT HATCHED IN MY HANDS"
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local ANIM = { walk = "rbxassetid://507777826", idle = "rbxassetid://507766388", jump = "rbxassetid://507765000", cheer = "rbxassetid://507770677" }
local tw
tw = function(o, t, p, st, d) local x = TweenService:Create(o, TweenInfo.new(t, st or Enum.EasingStyle.Quad, d or Enum.EasingDirection.Out), p); x:Play(); return x end

local function actor(name, recolor)
	local src = player.Character; if not src then return end
	src.Archivable = true
	local c = src:Clone(); src.Archivable = false
	for _, d in c:GetDescendants() do
		if d:IsA("LuaSourceContainer") or d:IsA("BillboardGui") or d:IsA("Tool") or d:IsA("ForceField") then d:Destroy()
		elseif d:IsA("BasePart") then d.LocalTransparencyModifier = 0; d.Anchored = false; d.CanCollide = false end
	end
	c.Name = name
	local hum = c:FindFirstChildOfClass("Humanoid")
	hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	if recolor then
		for _, d in c:GetChildren() do if d:IsA("Accessory") or d:IsA("Shirt") or d:IsA("Pants") or d:IsA("ShirtGraphic") then d:Destroy() end end
		local bc = c:FindFirstChildOfClass("BodyColors") or Instance.new("BodyColors", c)
		bc.HeadColor3, bc.LeftArmColor3, bc.RightArmColor3 = recolor.skin, recolor.skin, recolor.skin
		bc.TorsoColor3, bc.LeftLegColor3, bc.RightLegColor3 = recolor.top, recolor.legs, recolor.legs
	end
	local root = c:FindFirstChild("HumanoidRootPart"); root.Anchored = true
	c:SetAttribute("Hip", hum.HipHeight + root.Size.Y / 2)
	c.Parent = workspace
	local animator = hum:FindFirstChildOfClass("Animator") or Instance.new("Animator", hum)
	local tracks = {}
	local function play(k, speed, looped)
		for kk, t in tracks do if kk ~= k then t:Stop(0.2) end end
		if not tracks[k] then local a = Instance.new("Animation"); a.AnimationId = ANIM[k]; tracks[k] = animator:LoadAnimation(a) end
		tracks[k].Looped = looped ~= false; tracks[k]:Play(0.2, 1, speed or 1)
		return tracks[k]
	end
	return c, root, play
end

local function ground(pos)
	local rp = RaycastParams.new(); rp.FilterType = Enum.RaycastFilterType.Exclude
	rp.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("LocalRiverEggs") }
	local r = workspace:Raycast(Vector3.new(pos.X, 29.5, pos.Z), Vector3.new(0, -20, 0), rp)
	return r and r.Position or Vector3.new(pos.X, 26, pos.Z)
end
local function walk(root, play, from, to, time)
	play("walk", 1.1)
	local hip = root.Parent:GetAttribute("Hip") or 3
	root.CFrame = CFrame.lookAt(from + Vector3.new(0, hip, 0), to + Vector3.new(0, hip, 0))
	local t = tw(root, time, { CFrame = CFrame.lookAt(to + Vector3.new(0, hip, 0), to + (to - from).Unit + Vector3.new(0, hip, 0)) }, Enum.EasingStyle.Linear)
	t.Completed:Wait()
	play("idle")
end

local function playHatch()
	if running then return end
	running = "hatch"
	local scene = Instance.new("Folder"); scene.Name = "TrailerScene"; scene.Parent = workspace
	local prevType, prevFov = cam.CameraType, cam.FieldOfView
	hideAll(true)
	cam.CameraType = Enum.CameraType.Scriptable
	cam.FieldOfView = 45
	-- stage: river bank
	local bank = ground(Vector3.new(-30, 30, 33))
	local start = ground(bank + Vector3.new(-26, 0, 6))
	local me, root, play = actor("TrailerMe")
	me.Parent = scene
	-- egg drifting on the river toward us
	local eggSrc = RS.GameMenu.EggPreviews:FindFirstChild("MenuEgg_Pirate")
	local egg = eggSrc:Clone(); egg.Parent = scene
	for _, p in egg:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end end
	egg:ScaleTo(egg:GetScale() * 0.3)
	local eggCF = CFrame.new(bank + Vector3.new(-30, 1.2, -12))
	egg:PivotTo(eggCF)
	local eggVal = Instance.new("CFrameValue"); eggVal.Value = eggCF
	eggVal.Changed:Connect(function(v) if egg.Parent then egg:PivotTo(v) end end)
	local drift = tw(eggVal, 5.2, { Value = CFrame.new(bank + Vector3.new(0, 1.2, -11)) }, Enum.EasingStyle.Sine)
	-- hide the real river eggs so only our egg is in shot
	local river = workspace:FindFirstChild("LocalRiverEggs")
	local hiddenEggs = {}
	if river then for _, d in river:GetDescendants() do if d:IsA("BasePart") and d.LocalTransparencyModifier < 1 then hiddenEggs[d] = true; d.LocalTransparencyModifier = 1 end end end
	-- camera rig follows a CFrameValue so we can tween it
	local camVal = Instance.new("CFrameValue")
	camVal.Value = CFrame.lookAt(bank + Vector3.new(-14, 4, 20), start + Vector3.new(0, 3, 0))
	local follow = RunService.RenderStepped:Connect(function() cam.CFrame = camVal.Value end)
	task.wait(0.8)

	-- 1. walk up the bank
	tw(camVal, 4.6, { Value = CFrame.lookAt(bank + Vector3.new(-6, 3, 16), bank + Vector3.new(-4, 3, -6)) }, Enum.EasingStyle.Sine)
	beatOn = true
	walk(root, play, start, bank - (bank - start).Unit * 6, 3.2)
	play("jump", 1, false)
	-- low hero angle that keeps the whole flip in frame
	tw(camVal, 0.5, { Value = CFrame.lookAt(root.Position + (root.CFrame.RightVector * 14) + Vector3.new(0, -1, 0), root.Position + Vector3.new(0, 7, 0)) }, Enum.EasingStyle.Sine)
	superJump(root, scene, 9, 2)
	root.CFrame = CFrame.new(bank + Vector3.new(0, me:GetAttribute("Hip") or 3, 0)) * root.CFrame.Rotation
	play("idle")
	-- 2. turn to the river, reach down, scoop the egg up
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(egg:GetPivot().X, root.Position.Y, egg:GetPivot().Z))
	task.wait(0.3)
	drift:Cancel()
	local hands = root.CFrame * CFrame.new(0, -0.2, -2.6)
	tw(eggVal, 0.9, { Value = hands }, Enum.EasingStyle.Back)
	task.wait(1)
	-- 3. camera pushes in on the egg; it starts shaking & glowing
	tw(camVal, 3.2, { Value = CFrame.lookAt((root.CFrame * CFrame.new(6, 3, -11)).Position, (root.CFrame * CFrame.new(0, -0.2, -2.6)).Position) }, Enum.EasingStyle.Sine)
	local glow = Instance.new("PointLight"); glow.Color = Color3.fromRGB(255, 210, 90); glow.Range = 0; glow.Brightness = 4
	glow.Parent = egg:FindFirstChildWhichIsA("BasePart", true)
	tw(glow, 3, { Range = 18 })
	local t0 = os.clock()
	local shake = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - t0) / 3, 0, 1)
		local base = root.CFrame * CFrame.new(0, -0.2 + k * 0.8, -2.6)
		eggVal.Value = base * CFrame.Angles(0, 0, math.sin(os.clock() * (12 + k * 30)) * (0.05 + k * 0.28))
	end)
	task.wait(3)
	shake:Disconnect()

	-- 4. BURST: flash, shell pieces fly, sparkles
	local center = egg:GetPivot().Position
	eggVal:Destroy()
	local flash = Instance.new("Part"); flash.Shape = Enum.PartType.Ball; flash.Anchored = true; flash.CanCollide = false
	flash.Material = Enum.Material.Neon; flash.Color = Color3.fromRGB(255, 235, 170); flash.Size = Vector3.one; flash.CFrame = CFrame.new(center); flash.Parent = scene
	tw(flash, 0.5, { Size = Vector3.one * 14, Transparency = 1 })
	local ring = flash:Clone(); ring.Shape = Enum.PartType.Cylinder; ring.Size = Vector3.new(0.2, 1, 1); ring.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2); ring.Transparency = 0.2; ring.Parent = scene
	tw(ring, 0.8, { Size = Vector3.new(0.2, 24, 24), Transparency = 1 })
	local spark = Instance.new("ParticleEmitter")
	spark.Texture = "rbxasset://textures/particles/sparkles_main.dds"; spark.LightEmission = 1
	spark.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 255, 255))
	spark.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	spark.Speed = NumberRange.new(10, 22); spark.SpreadAngle = Vector2.new(180, 180); spark.Lifetime = NumberRange.new(0.6, 1.2); spark.Rate = 0
	spark.Parent = flash; spark:Emit(80)
	glow.Parent = flash
	shatter(egg, center)
	cam.FieldOfView = 42; tw(cam, 0.6, { FieldOfView = 50 })
	task.wait(0.35)

	-- 5. the character rises out of the light, spins, lands
	local portraits = RS:FindFirstChild("CharacterInventory") and RS.CharacterInventory:FindFirstChild("Portraits")
	local pick = portraits and (portraits:FindFirstChild("Pirate") or portraits:GetChildren()[1])
	if pick then
		local ch = pick:Clone(); ch.Parent = scene
		for _, p in ch:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end end
		local _, sz = ch:GetBoundingBox(); ch:ScaleTo(ch:GetScale() * 4.6 / math.max(sz.Y, 0.01))
		local face = CFrame.lookAt(center, Vector3.new(cam.CFrame.Position.X, center.Y, cam.CFrame.Position.Z))
		local v = Instance.new("CFrameValue"); v.Value = face * CFrame.new(0, -1, 0) * CFrame.Angles(0, math.pi, 0)
		v.Changed:Connect(function(x) if ch.Parent then ch:PivotTo(x) end end); ch:PivotTo(v.Value)
		tw(v, 1.4, { Value = face * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, math.pi * 2, 0) }, Enum.EasingStyle.Back)
		tw(camVal, 2.2, { Value = CFrame.lookAt((face * CFrame.new(-6, 4.5, -17)).Position, (face * CFrame.new(0, 3, 0)).Position) }, Enum.EasingStyle.Sine)
		local aura = spark:Clone(); aura.Rate = 25; aura.Speed = NumberRange.new(2, 4); aura.Parent = ch:FindFirstChildWhichIsA("BasePart", true)
	end
	play("cheer", 1, false)
	slowmo(1.2)
	local aura4, base4 = spinUp(root, scene, 5, 1.2)
	waitBeats(2); slamDown(root, scene, base4); aura4:Destroy()
	play("cheer", 1, false)
	task.wait(0.4)

	-- 6. a fan runs in from the side and freaks out
	local fan, froot, fplay = actor("TrailerFan", { skin = Color3.fromRGB(255, 204, 153), top = Color3.fromRGB(60, 120, 220), legs = Color3.fromRGB(40, 40, 55) })
	fan.Parent = scene
	local fanFrom = ground(bank + Vector3.new(16, 0, -10))
	local fanTo = ground(bank + Vector3.new(5, 0, -4))
	tw(camVal, 2.6, { Value = CFrame.lookAt(bank + Vector3.new(4, 6, -20), bank + Vector3.new(2, 4, 0)) }, Enum.EasingStyle.Sine)
	walk(froot, fplay, fanFrom, fanTo, 1.6)
	froot.CFrame = CFrame.lookAt(froot.Position, Vector3.new(center.X, froot.Position.Y, center.Z))
	for _ = 1, 2 do
		fplay("jump", 1, false)
		tw(froot, 0.25, { CFrame = froot.CFrame + Vector3.new(0, 2.5, 0) }, Enum.EasingStyle.Quad).Completed:Wait()
		tw(froot, 0.25, { CFrame = froot.CFrame - Vector3.new(0, 2.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
	end
	fplay("cheer", 1, false); play("cheer", 1, false)
	-- slow pull-back to finish
	tw(camVal, 3.5, { Value = CFrame.lookAt(bank + Vector3.new(-6, 12, -32), bank + Vector3.new(0, 3, 0)) }, Enum.EasingStyle.Sine)
	task.wait(3.8)

	beatOn = false
	follow:Disconnect()
	scene:Destroy()
	for d in hiddenEggs do if d.Parent then d.LocalTransparencyModifier = 0 end end
	cam.CameraType, cam.FieldOfView = prevType, prevFov
	hideAll(false)
	running = nil
end

---------------------------------------------------------------- STUNTS + BEAT (TikTok edit feel)
-- BPM: set to your sound's tempo (most TikTok sounds are 120-150). Camera punches land on the beat.
local BPM = 128
local BEAT = 60 / BPM
RunService.RenderStepped:Connect(function()
	if not (running and beatOn) then return end
	local ph = (os.clock() % BEAT) / BEAT
	local k = math.max(0, 1 - ph * 5) -- quick punch right on the beat
	cam.FieldOfView = cam.FieldOfView - k * 0.9
	cam.CFrame = cam.CFrame * CFrame.Angles(0, 0, math.rad(math.sin(os.clock() * 40) * k * 0.6))
end)
waitBeats = function(n) task.wait(BEAT * n) end
shake = function(time, power)
	local t0 = os.clock()
	local c; c = RunService.RenderStepped:Connect(function()
		local k = 1 - (os.clock() - t0) / time
		if k <= 0 then c:Disconnect() return end
		cam.CFrame = cam.CFrame * CFrame.new((math.random() - 0.5) * power * k, (math.random() - 0.5) * power * k, 0)
	end)
end
slowmo = function(seconds) -- visual slow-mo: tweens started now run slower
	local old = tw
	tw = function(o, t, p, st, d) return old(o, t * 2.2, p, st, d) end
	task.delay(seconds, function() tw = old end)
end
local function afterimage(model, scene)
	local g = Instance.new("Model"); g.Name = "Ghost"
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p.Transparency < 1 and p.Name ~= "HumanoidRootPart" then
			local c = Instance.new("Part"); c.Anchored = true; c.CanCollide = false; c.CastShadow = false
			c.Size = p.Size; c.CFrame = p.CFrame; c.Material = Enum.Material.Neon; c.Color = Color3.fromRGB(120, 200, 255); c.Transparency = 0.45; c.Parent = g
		end
	end
	g.Parent = scene
	for _, c in g:GetChildren() do tw(c, 0.45, { Transparency = 1 }) end
	task.delay(0.5, function() g:Destroy() end)
end
local function shockwave(scene, pos, color)
	local r = Instance.new("Part"); r.Shape = Enum.PartType.Cylinder; r.Anchored = true; r.CanCollide = false; r.CastShadow = false
	r.Material = Enum.Material.Neon; r.Color = color or Color3.fromRGB(255, 230, 160); r.Transparency = 0.15
	r.Size = Vector3.new(0.3, 2, 2); r.CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2); r.Parent = scene
	tw(r, 0.6, { Size = Vector3.new(0.3, 34, 34), Transparency = 1 })
	local dust = Instance.new("ParticleEmitter"); dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(230, 220, 200)); dust.Size = NumberSequence.new(2, 5); dust.Transparency = NumberSequence.new(0.4, 1)
	dust.Speed = NumberRange.new(12, 18); dust.SpreadAngle = Vector2.new(5, 180); dust.Lifetime = NumberRange.new(0.6, 1); dust.Rate = 0
	dust.Parent = r; dust:Emit(30)
end
-- impossible moves (all CFrame-driven, so they look clean on any avatar)
superJump = function(root, scene, height, flips)
	local start = root.CFrame
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a)
		local y = math.sin(a * math.pi) * height
		root.CFrame = start * CFrame.new(0, y, 0) * CFrame.Angles(-a * math.pi * 2 * (flips or 1), 0, 0)
	end)
	shockwave(scene, start.Position - Vector3.new(0, 3, 0))
	tw(v, 1.3, { Value = 1 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut).Completed:Wait()
	root.CFrame = start
	shockwave(scene, start.Position - Vector3.new(0, 3, 0), Color3.fromRGB(255, 200, 120)); shake(0.35, 0.8)
end
spinUp = function(root, scene, height, time)
	local start = root.CFrame
	local aura = Instance.new("ParticleEmitter"); aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"; aura.LightEmission = 1
	aura.Color = ColorSequence.new(Color3.fromRGB(255, 220, 120)); aura.Size = NumberSequence.new(0.5, 0); aura.Speed = NumberRange.new(2, 5)
	aura.SpreadAngle = Vector2.new(180, 180); aura.Lifetime = NumberRange.new(0.5, 1); aura.Rate = 60; aura.Parent = root
	local v = Instance.new("NumberValue")
	v.Changed:Connect(function(a) root.CFrame = start * CFrame.new(0, a * height, 0) * CFrame.Angles(0, a * math.pi * 6, 0) end)
	tw(v, time, { Value = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out).Completed:Wait()
	return aura, start
end
slamDown = function(root, scene, start)
	tw(root, 0.25, { CFrame = start }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
	shockwave(scene, start.Position - Vector3.new(0, 3, 0)); shake(0.5, 1.4)
end
dash = function(model, root, scene, to, time)
	local from = root.CFrame
	local goal = CFrame.lookAt(to, to + from.LookVector)
	local t0 = os.clock()
	local c; c = RunService.Heartbeat:Connect(function() afterimage(model, scene) end)
	tw(root, time, { CFrame = goal }, Enum.EasingStyle.Quart, Enum.EasingDirection.Out).Completed:Wait()
	c:Disconnect()
end

---------------------------------------------------------------- SCENES 5-7 (shared helpers)
local function newScene()
	local scene = Instance.new("Folder"); scene.Name = "TrailerScene"; scene.Parent = workspace
	local prevType, prevFov = cam.CameraType, cam.FieldOfView
	hideAll(true)
	cam.CameraType = Enum.CameraType.Scriptable
	local river = workspace:FindFirstChild("LocalRiverEggs")
	local hiddenEggs = {}
	if river then for _, d in river:GetDescendants() do if d:IsA("BasePart") and d.LocalTransparencyModifier < 1 then hiddenEggs[d] = true; d.LocalTransparencyModifier = 1 end end end
	local camVal = Instance.new("CFrameValue")
	local follow = RunService.RenderStepped:Connect(function() cam.CFrame = camVal.Value end)
	beatOn = true
	local function finish()
		beatOn = false
		follow:Disconnect(); scene:Destroy()
		for d in hiddenEggs do if d.Parent then d.LocalTransparencyModifier = 0 end end
		cam.CameraType, cam.FieldOfView = prevType, prevFov
		hideAll(false); running = nil
	end
	return scene, camVal, finish
end
local EGGS = { "Pirate", "Shinobi", "Magic", "Curse", "Academy", "Titan", "Guild", "Mecha", "Hero", "Soul", "Slayer", "Devil", "Sports", "God" }
local function makeEgg(scene, kind, scale, cf)
	local src = RS.GameMenu.EggPreviews:FindFirstChild("MenuEgg_" .. kind) or RS.GameMenu.EggPreviews:GetChildren()[1]
	local e = src:Clone(); e.Parent = scene
	for _, p in e:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end end
	e:ScaleTo(e:GetScale() * scale); e:PivotTo(cf)
	local v = Instance.new("CFrameValue"); v.Value = cf
	v.Changed:Connect(function(x) if e.Parent then e:PivotTo(x) end end)
	return e, v
end
local function burst(scene, center, color, size)
	size = size or 1
	local flash = Instance.new("Part"); flash.Shape = Enum.PartType.Ball; flash.Anchored = true; flash.CanCollide = false; flash.CastShadow = false
	flash.Material = Enum.Material.Neon; flash.Color = color or Color3.fromRGB(255, 235, 170); flash.Size = Vector3.one; flash.CFrame = CFrame.new(center); flash.Parent = scene
	tw(flash, 0.5, { Size = Vector3.one * 12 * size, Transparency = 1 })
	local ring = flash:Clone(); ring.Shape = Enum.PartType.Cylinder; ring.Size = Vector3.new(0.2, 1, 1); ring.CFrame = CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2); ring.Transparency = 0.2; ring.Parent = scene
	tw(ring, 0.8, { Size = Vector3.new(0.2, 22 * size, 22 * size), Transparency = 1 })
	local sp = Instance.new("ParticleEmitter")
	sp.Texture = "rbxasset://textures/particles/sparkles_main.dds"; sp.LightEmission = 1
	sp.Color = ColorSequence.new(color or Color3.fromRGB(255, 220, 120), Color3.new(1, 1, 1))
	sp.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6 * size), NumberSequenceKeypoint.new(1, 0) })
	sp.Speed = NumberRange.new(10, 22); sp.SpreadAngle = Vector2.new(180, 180); sp.Lifetime = NumberRange.new(0.6, 1.2); sp.Rate = 0
	sp.Parent = flash; sp:Emit(60 * size)
	return sp
end
shatter = function(egg, center)
	local _, sz = egg:GetBoundingBox()
	for _, p in egg:GetDescendants() do if p:IsA("BasePart") then p.Transparency = 1 end end
	local col = Color3.fromRGB(255, 245, 225)
	local any = egg:FindFirstChildWhichIsA("BasePart", true); if any then col = any.Color end
	for i = 1, 10 do
		local sh = Instance.new("Part"); sh.Anchored = true; sh.CanCollide = false; sh.CastShadow = false
		sh.Size = Vector3.new(sz.X * 0.32, sz.Y * 0.22, 0.15); sh.Color = i % 2 == 0 and col or Color3.fromRGB(255, 240, 210)
		sh.Material = Enum.Material.SmoothPlastic; sh.CFrame = CFrame.new(center) * CFrame.Angles(0, i * 0.63, 0) * CFrame.new(0, 0, -sz.X * 0.3)
		sh.Parent = egg.Parent
		local out = (sh.Position - center) * Vector3.new(1, 0, 1); out = out.Magnitude > 0 and out.Unit or Vector3.xAxis
		tw(sh, 0.9, { CFrame = sh.CFrame + out * 6 + Vector3.new(0, 1.5 + (i % 3), 0), Transparency = 1 }, Enum.EasingStyle.Quad)
		tw(sh, 0.9, { Orientation = sh.Orientation + Vector3.new(math.random(-180, 180), math.random(-180, 180), 0) })
	end
	task.delay(1, function() if egg.Parent then egg:Destroy() end end)
end
local function riseChar(scene, kind, center, faceTo, height)
	local portraits = RS:FindFirstChild("CharacterInventory") and RS.CharacterInventory:FindFirstChild("Portraits")
	local pick = portraits and (portraits:FindFirstChild(kind) or portraits:GetChildren()[1]); if not pick then return end
	local ch = pick:Clone(); ch.Parent = scene
	for _, p in ch:GetDescendants() do if p:IsA("BasePart") then p.Anchored = true; p.CanCollide = false end end
	local _, sz = ch:GetBoundingBox(); ch:ScaleTo(ch:GetScale() * (height or 3.4) / math.max(sz.Y, 0.01))
	local face = CFrame.lookAt(center, Vector3.new(faceTo.X, center.Y, faceTo.Z))
	local v = Instance.new("CFrameValue"); v.Value = face * CFrame.new(0, -1, 0) * CFrame.Angles(0, math.pi, 0)
	v.Changed:Connect(function(x) if ch.Parent then ch:PivotTo(x) end end); ch:PivotTo(v.Value)
	tw(v, 1.3, { Value = face * CFrame.new(0, (height or 3.4) * 0.7, 0) * CFrame.Angles(0, math.pi * 2, 0) }, Enum.EasingStyle.Back)
	return ch
end
local function hop(root, n, h)
	for _ = 1, n do
		tw(root, 0.22, { CFrame = root.CFrame + Vector3.new(0, h or 2.5, 0) }).Completed:Wait()
		tw(root, 0.22, { CFrame = root.CFrame - Vector3.new(0, h or 2.5, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In).Completed:Wait()
	end
end

-- SCENE 5: EGG RAIN — the sky darkens and eggs rain down all around you; they all hatch at once
local function playRain()
	if running then return end
	running = "rain"
	local scene, camVal, finish = newScene()
	cam.FieldOfView = 55
	local spot = ground(Vector3.new(-40, 30, 70))
	local me, root, play = actor("TrailerMe"); me.Parent = scene
	root.CFrame = CFrame.lookAt(spot + Vector3.new(0, me:GetAttribute("Hip"), 0), spot + Vector3.new(0, me:GetAttribute("Hip"), -10))
	play("idle")
	local cc = Instance.new("ColorCorrectionEffect"); cc.Parent = game.Lighting
	camVal.Value = CFrame.lookAt(spot + Vector3.new(0, 4, -16), spot + Vector3.new(0, 4, 0))
	task.wait(0.6)
	-- sky goes dramatic, camera tilts up
	tw(cc, 1.5, { Brightness = -0.15, Contrast = 0.2, TintColor = Color3.fromRGB(200, 185, 255) })
	tw(camVal, 2, { Value = CFrame.lookAt(spot + Vector3.new(0, 3, -14), spot + Vector3.new(0, 30, 10)) }, Enum.EasingStyle.Sine)
	task.wait(1.6)
	-- eggs fall
	local eggs = {}
	for i = 1, 12 do
		local ang = (i / 12) * math.pi * 2 + math.random() * 0.4
		local r = 7 + (i % 3) * 3
		local land = ground(spot + Vector3.new(math.cos(ang) * r, 0, math.sin(ang) * r)) + Vector3.new(0, 1.3, 0)
		local e, v = makeEgg(scene, EGGS[(i - 1) % #EGGS + 1], 0.32, CFrame.new(land + Vector3.new(0, 70 + i * 3, 0)) * CFrame.Angles(0, ang, 0.3))
		local trail = Instance.new("Trail")
		table.insert(eggs, { e = e, v = v, land = land })
		task.delay(i * 0.18, function()
			tw(v, 1.1, { Value = CFrame.new(land) * CFrame.Angles(0, ang, 0) }, Enum.EasingStyle.Bounce)
		end)
	end
	tw(camVal, 3.2, { Value = CFrame.lookAt(spot + Vector3.new(14, 8, -12), spot + Vector3.new(0, 2, 0)) }, Enum.EasingStyle.Sine)
	task.wait(1.2)
	local aura5, base5 = spinUp(root, scene, 7, 1.8)
	waitBeats(3)
	-- slow orbit while they glow
	local a0 = os.clock()
	local orbit = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - a0) * 0.35
		camVal.Value = CFrame.lookAt(spot + Vector3.new(math.sin(a * 0.6 + 0.4) * 15, 7, -math.cos(a * 0.6 + 0.4) * 15), spot + Vector3.new(0, 2.5, 0))
	end)
	for _, it in eggs do local l = Instance.new("PointLight"); l.Color = Color3.fromRGB(255, 210, 90); l.Range = 0; l.Brightness = 3; l.Parent = it.e:FindFirstChildWhichIsA("BasePart", true); tw(l, 2, { Range = 10 }) end
	task.wait(1.2)
	slamDown(root, scene, base5); aura5:Destroy()
	-- all hatch at once
	for i, it in ipairs(eggs) do
		task.delay(i * 0.06, function()
			local c = it.e:GetPivot().Position
			burst(scene, c, nil, 0.7); shatter(it.e, c)
			riseChar(scene, EGGS[(i - 1) % #EGGS + 1], c, spot, 3)
		end)
	end
	play("cheer", 1, false)
	task.wait(3.2)
	orbit:Disconnect()
	tw(camVal, 2.5, { Value = CFrame.lookAt(spot + Vector3.new(4, 16, -24), spot + Vector3.new(0, 2, 0)) }, Enum.EasingStyle.Sine)
	tw(cc, 2.5, { Brightness = 0, Contrast = 0, TintColor = Color3.new(1, 1, 1) })
	task.wait(2.8)
	cc:Destroy()
	finish()
end

-- SCENE 6: THE HEIST — a thief swipes your egg, you chase him down, the egg flies back and hatches
local function playHeist()
	if running then return end
	running = "heist"
	local scene, camVal, finish = newScene()
	cam.FieldOfView = 50
	local a = ground(Vector3.new(-60, 30, 60))
	local me, root, play = actor("TrailerMe"); me.Parent = scene
	root.CFrame = CFrame.lookAt(a + Vector3.new(0, me:GetAttribute("Hip"), 0), a + Vector3.new(1, me:GetAttribute("Hip"), 0))
	play("idle")
	local egg, ev = makeEgg(scene, "Devil", 0.22, root.CFrame * CFrame.new(0, 0.6, -2.2))
	local thief, troot, tplay = actor("TrailerThief", { skin = Color3.fromRGB(240, 200, 160), top = Color3.fromRGB(25, 25, 30), legs = Color3.fromRGB(20, 20, 25) })
	thief.Parent = scene
	local tFrom = ground(a + Vector3.new(14, 0, -10))
	troot.CFrame = CFrame.new(tFrom + Vector3.new(0, thief:GetAttribute("Hip"), 0))
	camVal.Value = CFrame.lookAt(a + Vector3.new(-6, 4, -9), a + Vector3.new(2, 3, 0))
	task.wait(0.8)
	-- thief sneaks in
	tw(camVal, 2, { Value = CFrame.lookAt(a + Vector3.new(-3, 3.5, -8), a + Vector3.new(3, 3, -2)) }, Enum.EasingStyle.Sine)
	walk(troot, tplay, tFrom, a + Vector3.new(2.6, 0, -1.2), 1.6)
	-- snatch!
	tw(ev, 0.25, { Value = troot.CFrame * CFrame.new(0, 0.6, -1.6) })
	task.wait(0.3)
	local carry = RunService.RenderStepped:Connect(function() ev.Value = troot.CFrame * CFrame.new(0, 1.2, 1.2) end)
	play("jump", 1, false); hop(root, 1, 1.5)
	-- chase down the path
	local escape = ground(a + Vector3.new(46, 0, 8))
	local catch = ground(a + Vector3.new(38, 0, 6))
	local camRun = RunService.RenderStepped:Connect(function()
		local mid = (root.Position + troot.Position) / 2
		camVal.Value = camVal.Value:Lerp(CFrame.lookAt(mid + Vector3.new(-4, 6, -16), mid), 0.08)
	end)
	task.spawn(walk, troot, tplay, a + Vector3.new(2.6, 0, -1.2), escape, 2.8)
	task.wait(0.35)
	play("walk", 1.6)
	dash(me, root, scene, catch + Vector3.new(0, me:GetAttribute("Hip") or 3, 0), 0.9)
	play("jump", 1, false)
	superJump(root, scene, 6, 1)
	camRun:Disconnect(); carry:Disconnect()
	-- tackle: thief flips, egg flies back to your hands
	tw(troot, 0.5, { CFrame = troot.CFrame * CFrame.new(0, -1.5, 0) * CFrame.Angles(math.rad(-80), 0, 0) })
	root.CFrame = CFrame.lookAt(root.Position, Vector3.new(troot.Position.X, root.Position.Y, troot.Position.Z))
	tw(ev, 0.7, { Value = root.CFrame * CFrame.new(0, 0.6, -2.2) }, Enum.EasingStyle.Back)
	tw(camVal, 1.2, { Value = CFrame.lookAt((root.CFrame * CFrame.new(5, 2.5, -10)).Position, (root.CFrame * CFrame.new(0, 0.6, -2.2)).Position) }, Enum.EasingStyle.Sine)
	task.wait(1.3)
	-- it shakes ... and hatches
	local t0 = os.clock()
	local shake = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - t0) / 2.2, 0, 1)
		ev.Value = root.CFrame * CFrame.new(0, -0.2 + k * 0.8, -2.6) * CFrame.Angles(0, 0, math.sin(os.clock() * (14 + k * 30)) * (0.05 + k * 0.3))
	end)
	task.wait(2.2); shake:Disconnect()
	local c = egg:GetPivot().Position
	burst(scene, c, Color3.fromRGB(255, 110, 90)); shatter(egg, c); ev:Destroy()
	riseChar(scene, "Devil", c, cam.CFrame.Position, 3.4)
	play("cheer", 1, false)
	task.wait(0.4)
	tw(camVal, 3, { Value = CFrame.lookAt((root.CFrame * CFrame.new(-6, 4, -16)).Position, c + Vector3.new(0, 2, 0)) }, Enum.EasingStyle.Sine)
	task.wait(3.2)
	finish()
end

-- SCENE 7: GOD PULL — slow-motion legendary hatch with a golden light pillar
local function playLegend()
	if running then return end
	running = "legend"
	local scene, camVal, finish = newScene()
	cam.FieldOfView = 42
	local spot = ground(Vector3.new(-20, 30, 75))
	local me, root, play = actor("TrailerMe"); me.Parent = scene
	root.CFrame = CFrame.lookAt(spot + Vector3.new(0, me:GetAttribute("Hip"), 0), spot + Vector3.new(0, me:GetAttribute("Hip"), -10))
	play("idle")
	local egg, ev = makeEgg(scene, "God", 0.22, root.CFrame * CFrame.new(0, 0.6, -2.2))
	local cc = Instance.new("ColorCorrectionEffect"); cc.Parent = game.Lighting
	local bloom = Instance.new("BloomEffect"); bloom.Intensity = 0; bloom.Size = 40; bloom.Threshold = 0.9; bloom.Parent = game.Lighting
	camVal.Value = CFrame.lookAt((root.CFrame * CFrame.new(0, 2.5, -14)).Position, root.Position + Vector3.new(0, 1.5, 0))
	task.wait(0.6)
	-- world dims, the egg starts to glow
	tw(cc, 2, { Brightness = -0.25, Saturation = -0.3, Contrast = 0.25 })
	local light = Instance.new("PointLight"); light.Color = Color3.fromRGB(255, 215, 110); light.Range = 0; light.Brightness = 5; light.Parent = egg:FindFirstChildWhichIsA("BasePart", true)
	tw(light, 3, { Range = 22 })
	tw(camVal, 3.5, { Value = CFrame.lookAt((root.CFrame * CFrame.new(3, 1.2, -6)).Position, (root.CFrame * CFrame.new(0, 0.2, -2.6)).Position) }, Enum.EasingStyle.Sine)
	local t0 = os.clock()
	local shake = RunService.RenderStepped:Connect(function()
		local k = math.clamp((os.clock() - t0) / 3.5, 0, 1)
		ev.Value = root.CFrame * CFrame.new(0, -0.2 + k * 1.6, -2.6) * CFrame.Angles(0, os.clock() * k * 3, math.sin(os.clock() * (10 + k * 26)) * (0.04 + k * 0.22))
	end)
	task.wait(3.5)
	-- pillar of light from the sky
	local c = egg:GetPivot().Position
	local pillar = Instance.new("Part"); pillar.Shape = Enum.PartType.Cylinder; pillar.Anchored = true; pillar.CanCollide = false; pillar.CastShadow = false
	pillar.Material = Enum.Material.Neon; pillar.Color = Color3.fromRGB(255, 220, 120); pillar.Transparency = 0.3
	pillar.Size = Vector3.new(200, 0.2, 0.2); pillar.CFrame = CFrame.new(c + Vector3.new(0, 100, 0)) * CFrame.Angles(0, 0, math.pi / 2); pillar.Parent = scene
	tw(pillar, 0.5, { Size = Vector3.new(200, 7, 7) })
	shake(0.8, 1.2)
	tw(bloom, 0.5, { Intensity = 1.2 })
	tw(camVal, 0.6, { Value = CFrame.lookAt((root.CFrame * CFrame.new(-8, 2, -20)).Position, c + Vector3.new(0, 6, 0)) })
	task.wait(1.2)
	shake:Disconnect()
	-- the hatch (slow-mo feel: long flash, big ring)
	burst(scene, c, Color3.fromRGB(255, 220, 120), 1.8); shatter(egg, c); ev:Destroy()
	tw(pillar, 1.2, { Size = Vector3.new(200, 0.2, 0.2), Transparency = 1 })
	tw(cc, 1.5, { Brightness = 0.05, Saturation = 0.15, Contrast = 0.1 })
	local god = riseChar(scene, "God", c, cam.CFrame.Position, 4.2)
	if god then local aura = Instance.new("Sparkles"); aura.SparkleColor = Color3.fromRGB(255, 220, 120); aura.Parent = god:FindFirstChildWhichIsA("BasePart", true) end
	play("cheer", 1, false)
	slowmo(2)
	local aura7, base7 = spinUp(root, scene, 4, 1.6)
	task.delay(2.6, function() if root.Parent then slamDown(root, scene, base7); aura7:Destroy() end end)
	task.wait(0.6)
	local a0 = os.clock()
	local orbit = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - a0) * 0.45
		camVal.Value = CFrame.lookAt(c + Vector3.new(math.sin(a) * 13, 4.5, -math.cos(a) * 13), c + Vector3.new(0, 3, 0))
	end)
	task.wait(4.5)
	orbit:Disconnect()
	tw(bloom, 1.5, { Intensity = 0 }); tw(cc, 1.5, { Brightness = 0, Saturation = 0, Contrast = 0 })
	task.wait(1.6)
	cc:Destroy(); bloom:Destroy()
	finish()
end

UIS.InputBegan:Connect(function(i, gp)
	if gp then return end
	local k = i.KeyCode
	if k == Enum.KeyCode.Backspace then running = false return end
	local idx = UIS:IsKeyDown(Enum.KeyCode.LeftShift) and ((k == Enum.KeyCode.One and 1) or (k == Enum.KeyCode.Two and 2) or (k == Enum.KeyCode.Three and 3))
	if idx then task.spawn(play, shots()[idx]) end
	if UIS:IsKeyDown(Enum.KeyCode.LeftShift) then
		if k == Enum.KeyCode.Four then task.spawn(playHatch)
		elseif k == Enum.KeyCode.Five then task.spawn(playRain)
		elseif k == Enum.KeyCode.Six then task.spawn(playHeist)
		elseif k == Enum.KeyCode.Seven then task.spawn(playLegend) end
	end
end)
player:GetAttributeChangedSignal("TrailerShot"):Connect(function() local i = player:GetAttribute("TrailerShot"); if i == 4 then task.spawn(playHatch) elseif i == 5 then task.spawn(playRain) elseif i == 6 then task.spawn(playHeist) elseif i == 7 then task.spawn(playLegend) elseif i then task.spawn(play, shots()[i]) end end)
