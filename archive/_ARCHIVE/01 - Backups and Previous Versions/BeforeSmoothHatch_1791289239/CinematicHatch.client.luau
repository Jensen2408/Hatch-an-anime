-- CinematicHatch (LocalScript, StarterPlayerScripts)
-- Local hatch cinematic for the incubators. The server owns timing, rewards and machine
-- state; this script only draws. Everyone nearby sees the egg break; only the player who
-- pressed Hatch gets the camera, sound duck and control lock.
--
-- Physical cracking: the egg meshes are split into real shell sections with EditableMesh
-- (triangles grouped by fracture cell, original UVs + SurfaceAppearance kept), so the
-- intact egg looks identical and the pieces part along voxel-stepped fracture lines.
-- A warm core inside the shell is what you see through the opening seams.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Collection = game:GetService("CollectionService")
local AssetService = game:GetService("AssetService")
local Lighting = game:GetService("Lighting")
local SoundService = game:GetService("SoundService")
local Actions = game:GetService("ContextActionService")
local Debris = game:GetService("Debris")

local player = Players.LocalPlayer
local remote = game.ReplicatedStorage:WaitForChild("CinematicHatchCue")

local BASE = 5.6 -- timeline below is written for a 5.6 s hatch and scaled to the real one
local NEAR = 120
local TAU = math.pi * 2
local CORE = Color3.fromRGB(255, 236, 196)
-- Sounds are not set yet. Hook points are marked "SOUND:" below (hum start, each crack, release).
-- shake beats: first fracture is a single jolt, then bursts grow with shorter pauses
local BEATS = {
	{ t = 0.95, amp = 6, len = 0.28, cycles = 1, open = { 1, 2 }, vol = 0.5, pitch = 1.05, axis = 0.6 },
	{ t = 1.85, amp = 4, len = 0.38, cycles = 2, open = { 3 }, vol = 0.42, pitch = 1.2, axis = 2.2 },
	{ t = 2.55, amp = 6, len = 0.42, cycles = 2.5, open = { 4, 5 }, vol = 0.5, pitch = 1.3, axis = 4.0 },
	{ t = 3.15, amp = 8, len = 0.48, cycles = 3, open = { 6 }, vol = 0.6, pitch = 1.4, axis = 1.1 },
	{ t = 3.7, amp = 10, len = 0.52, cycles = 3.5, open = {}, vol = 0.7, pitch = 1.5, axis = 3.1 },
	{ t = 4.25, amp = 13, len = 0.62, cycles = 4.5, open = {}, vol = 0.8, pitch = 1.6, axis = 5.2 },
}
local WHITE_FROM, WHITE_TO, HOLD = 4.25, 5.0, 5.0 -- breaking point, then tension hold

local function wrap(a) return (a + math.pi) % TAU - math.pi end
local function smooth(x) x = math.clamp(x, 0, 1) return x * x * (3 - 2 * x) end

local function newPart(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	for k, v in props do p[k] = v end
	return p
end


------------------------------------------------------------------------ fracture builder
-- cells: 1-2 cap halves, 3-6 body sectors, 7 base cup (stays put)
local function cellOf(h, a)
	local cap = 0.13 + 0.05 * math.sin(3 * a + 1.3) + 0.025 * math.sin(7 * a + 0.4)
	local base = -0.29 + 0.035 * math.sin(4 * a + 2.1)
	if h > cap then
		return wrap(a - (0.18 + 0.9 * (h - cap))) < 0 and 1 or 2
	elseif h < base then
		return 7
	end
	local s = (a - 0.55 - 0.2 * math.sin(9 * h + 2 * a) - 0.07 * math.sin(23 * h + a)) % TAU
	return 3 + math.floor(s / (TAU / 4)) % 4
end

local sources = {} -- MeshId -> {em, center, size, faces = {{a, b, c, uvs, normals, centroid}}}
local function source(id)
	local c = sources[id]
	if c then return c end
	local em = AssetService:CreateEditableMeshAsync(Content.fromUri(id))
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, v in em:GetVertices() do
		local p = em:GetPosition(v); mn = mn:Min(p); mx = mx:Max(p)
	end
	c = { em = em, center = (mn + mx) / 2, size = mx - mn, faces = {} }
	for i, f in em:GetFaces() do
		local vs = em:GetFaceVertices(f)
		local a, b, d = em:GetPosition(vs[1]), em:GetPosition(vs[2]), em:GetPosition(vs[3])
		local uv, nm = {}, {}
		for k, id2 in em:GetFaceUVs(f) do uv[k] = em:GetUV(id2) end
		local okN, ns = pcall(em.GetFaceNormals, em, f)
		if okN then for k, id2 in ns do nm[k] = em:GetNormal(id2) end end
		c.faces[i] = { a, b, d, uv, nm, (a + b + d) / 3 }
		if i % 1500 == 0 then task.wait() end
	end
	sources[id] = c
	return c
end

-- Returns {pieces = {[cell] = {parts = {{part, rel}}, dir, meshes}}} or nil
local function buildFracture(egg)
	local box, size = egg:GetBoundingBox()
	local pivot = egg:GetPivot()
	local pieces, sums, glow = {}, {}, {}
	for _, d in egg:GetDescendants() do
		-- (the egg is still fading in when this runs, so its parts may read Transparency 1)
		if d:IsA("MeshPart") and d.MeshId ~= "" then
			local src = source(d.MeshId)
			if not egg.Parent then return nil end
			local scale = d.Size / src.size
			local buckets = {}
			for _, f in src.faces do
				local world = d.CFrame:PointToWorldSpace((f[6] - src.center) * scale)
				local l = box:PointToObjectSpace(world)
				local cell = cellOf(l.Y / size.Y, math.atan2(l.X, -l.Z)) -- angle 0 faces the walkway
				local b = buckets[cell]; if not b then b = {}; buckets[cell] = b end
				table.insert(b, f)
				local s = sums[cell]; if not s then s = { Vector3.zero, 0 }; sums[cell] = s end
				s[1] += l; s[2] += 1
			end
			local n = 0
			for cell, faces in buckets do
				local em = AssetService:CreateEditableMesh()
				local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
				for _, f in faces do
					local v = {}
					for k = 1, 3 do
						mn = mn:Min(f[k]); mx = mx:Max(f[k])
						v[k] = em:AddVertex(f[k])
					end
					local face = em:AddTriangle(v[1], v[2], v[3])
					if #f[4] == 3 then
						em:SetFaceUVs(face, { em:AddUV(f[4][1]), em:AddUV(f[4][2]), em:AddUV(f[4][3]) })
					end
					if #f[5] == 3 then
						pcall(function() em:SetFaceNormals(face, { em:AddNormal(f[5][1]), em:AddNormal(f[5][2]), em:AddNormal(f[5][3]) }) end)
					end
					n += 1
					if n % 1500 == 0 then task.wait() end
				end
				local part = AssetService:CreateMeshPartAsync(Content.fromObject(em))
				part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery = true, false, false, false
				part.Size = ((mx - mn) * scale):Max(Vector3.one * 0.02)
				-- a mesh made from an EditableMesh keeps its source origin (it is not re-centred)
				part.CFrame = d.CFrame * CFrame.new(-src.center * scale)
				part.Material, part.Color, part.Transparency = d.Material, d.Color, 0
				part.CastShadow = d.CastShadow
				local sa = d:FindFirstChildOfClass("SurfaceAppearance")
				if sa then sa:Clone().Parent = part end
				local piece = pieces[cell]
				if not piece then piece = { parts = {}, meshes = {} }; pieces[cell] = piece end
				table.insert(piece.parts, { part = part, rel = pivot:ToObjectSpace(part.CFrame) })
				table.insert(piece.meshes, em)
			end
			-- inner glow: the same egg layer shrunk to 92%, only visible through the seams
			local g = d:Clone()
			for _, ch in g:GetChildren() do ch:Destroy() end
			g.Material, g.Color, g.Transparency, g.CastShadow = Enum.Material.Neon, CORE, 1, false
			g.Anchored, g.CanCollide, g.CanTouch, g.CanQuery = true, false, false, false
			g.Size = d.Size * 0.92
			local rel = pivot:ToObjectSpace(d.CFrame)
			table.insert(glow, { part = g, rel = CFrame.new(rel.Position * 0.92) * rel.Rotation })
		end
	end
	-- outward direction of each piece, from the egg centre to the piece's real centroid
	for cell, piece in pieces do
		local c = sums[cell][1] / sums[cell][2]
		local flat = Vector3.new(c.X, 0, c.Z)
		local dir = flat.Magnitude > 0.01 and flat.Unit or Vector3.new(0, 0, -1)
		if cell <= 2 then dir = (dir + Vector3.new(0, 1.4, 0)).Unit end
		piece.dir = dir
		piece.cell = cell
	end
	if next(pieces) == nil then return nil end
	return { pieces = pieces, size = size, glow = glow }
end

------------------------------------------------------------------------ per-egg records
local records = {} -- egg model -> record

local function hideOriginal(r, hidden)
	for _, p in r.egg:GetDescendants() do
		if p:IsA("BasePart") or p:IsA("Decal") then p.LocalTransparencyModifier = hidden and 1 or 0 end
	end
end

local function cleanup(r)
	if r.dead then return end
	r.dead = true
	records[r.egg] = nil
	if r.hum then r.hum:Destroy() end
	if r.folder then r.folder:Destroy() end
	if r.fracture then
		for _, piece in r.fracture.pieces do for _, em in piece.meshes do em:Destroy() end end
	end
	if r.egg.Parent then hideOriginal(r, false) end
end

local function prepare(egg)
	if records[egg] or not egg:IsA("Model") then return end
	local home = egg:GetAttribute("ChamberHome")
	if typeof(home) ~= "CFrame" then return end
	local r = { egg = egg, home = home, state = "building" }
	records[egg] = r
	task.spawn(function()
		-- only build for eggs the camera is near (checked until it is)
		while not r.dead and egg.Parent and (workspace.CurrentCamera.CFrame.Position - home.Position).Magnitude > NEAR do
			task.wait(1)
		end
		if r.dead or not egg.Parent then return end
		local folder = Instance.new("Folder"); folder.Name = "LocalHatchShell"
		r.folder = folder
		local _, size = egg:GetBoundingBox()
		r.size = size
		-- invisible anchor for the light, sparkles and sounds
		r.core = newPart({ Name = "HatchCore", Size = Vector3.one * 0.2, Transparency = 1, CastShadow = false, CFrame = home, Parent = folder })
		r.light = Instance.new("PointLight"); r.light.Color = CORE; r.light.Range = 7; r.light.Brightness = 0; r.light.Shadows = false
		r.light.Parent = r.core
		r.sparkle = Instance.new("ParticleEmitter")
		r.sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"; r.sparkle.Rate = 0
		r.sparkle.LightEmission = 0.9; r.sparkle.LightInfluence = 0
		r.sparkle.Color = ColorSequence.new(Color3.fromRGB(255, 250, 235), Color3.fromRGB(255, 214, 140))
		r.sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0) })
		r.sparkle.Lifetime = NumberRange.new(0.45, 0.85); r.sparkle.Speed = NumberRange.new(2.5, 5)
		r.sparkle.Drag = 5; r.sparkle.SpreadAngle = Vector2.new(180, 180); r.sparkle.Parent = r.core
		r.highlight = Instance.new("Highlight"); r.highlight.FillColor = Color3.new(1, 1, 1); r.highlight.OutlineColor = CORE
		r.highlight.FillTransparency = 1; r.highlight.OutlineTransparency = 1
		r.highlight.DepthMode = Enum.HighlightDepthMode.Occluded; r.highlight.Adornee = folder; r.highlight.Parent = folder
		r.state = "effects" -- enough to animate the intact egg if the shell isn't ready in time
		local ok, result = pcall(buildFracture, egg)
		if r.dead then
			if ok and result then for _, piece in result.pieces do for _, em in piece.meshes do em:Destroy() end end end
			return
		end
		if not ok or not result then
			-- EditableMesh off (Game Settings > Security) or mesh not accessible: the intact egg
			-- still gets the full timing, light, whitening and release, just without shell pieces
			warn("Hatch fracture unavailable, using intact egg: " .. tostring(result))
			return
		end
		r.fracture = result
		if r.shown then return end -- already hatching with the intact egg; never swap mid-sequence
		for _, piece in result.pieces do
			piece.gap, piece.target = 0, 0
			for _, e in piece.parts do e.part.Parent = folder end
		end
		for _, g in result.glow do g.part.Parent = folder end
		r.state = "ready"
	end)
end

local function startHatch(egg)
	prepare(egg)
	local r = records[egg]
	if not r then return end
	r.epoch = egg:GetAttribute("HatchEpoch") or workspace:GetServerTimeNow()
	r.duration = egg:GetAttribute("HatchDuration") or BASE
	r.hatching = true
	r.beat = 0
end

Collection:GetInstanceAddedSignal("IncubatorEgg"):Connect(prepare)
Collection:GetInstanceAddedSignal("CinematicEggHatch"):Connect(startHatch)
Collection:GetInstanceRemovedSignal("CinematicEggHatch"):Connect(function(egg)
	local r = records[egg]; if r and not r.released then cleanup(r) end -- released shells finish their fall
end)
for _, e in Collection:GetTagged("IncubatorEgg") do prepare(e) end
for _, e in Collection:GetTagged("CinematicEggHatch") do startHatch(e) end

------------------------------------------------------------------------ owner session
local gui = Instance.new("ScreenGui")
gui.Name = "CinematicHatchUI"; gui.IgnoreGuiInset = true; gui.ResetOnSpawn = false; gui.DisplayOrder = 160
gui.Parent = player:WaitForChild("PlayerGui")
local flash = Instance.new("Frame")
flash.Size = UDim2.fromScale(1, 1); flash.BackgroundColor3 = Color3.new(1, 1, 1); flash.BackgroundTransparency = 1
flash.BorderSizePixel = 0; flash.Parent = gui
local title = Instance.new("TextLabel")
title.AnchorPoint = Vector2.new(0.5, 1); title.Position = UDim2.fromScale(0.5, 0.9); title.Size = UDim2.fromOffset(460, 48)
title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(255, 233, 167); title.TextStrokeTransparency = 0.3
title.Font = Enum.Font.GothamBold; title.TextSize = 27; title.Text = ""; title.TextTransparency = 1; title.Parent = gui

local session
local function tween(obj, t, props, style)
	local tw = TweenService:Create(obj, TweenInfo.new(t, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props)
	tw:Play()
	if session then table.insert(session.tweens, tw) end
	return tw
end

local function finish()
	local s = session
	if not s then return end
	session = nil
	for _, tw in s.tweens do tw:Cancel() end
	for _, c in s.connections do c:Disconnect() end
	Actions:UnbindAction("CinematicHatchLock")
	local cam = workspace.CurrentCamera
	if cam then
		cam.CameraType = s.camType; cam.CameraSubject = s.subject; cam.FieldOfView = s.fov
		if s.camType == Enum.CameraType.Scriptable then cam.CFrame = s.original end
	end
	for inst, v in s.hidden do if inst.Parent then inst.LocalTransparencyModifier = v end end
	for snd, v in s.ducked do if snd.Parent then snd.Volume = v end end
	if s.controls then pcall(function() s.controls:Enable() end) end
	if s.cc then s.cc:Destroy() end
	flash.BackgroundTransparency = 1; title.Text = ""; title.TextTransparency = 1
end

local function hideInstance(s, inst, value)
	if s.hidden[inst] == nil then s.hidden[inst] = inst.LocalTransparencyModifier end
	inst.LocalTransparencyModifier = value
end

local function hideAvatars(s)
	for _, other in Players:GetPlayers() do
		local char = other.Character
		local root = char and char:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - s.home.Position).Magnitude < 40 then
			for _, p in char:GetDescendants() do
				if p:IsA("BasePart") or p:IsA("Decal") then hideInstance(s, p, 1) end
			end
		end
	end
end

local function begin(chamber, home, duration)
	finish()
	local cam = workspace.CurrentCamera
	local controls
	pcall(function() controls = require(player.PlayerScripts:WaitForChild("PlayerModule", 2)):GetControls() end)
	local s = {
		chamber = chamber, home = home, duration = duration or BASE, start = os.clock(),
		original = cam.CFrame, fov = cam.FieldOfView, camType = cam.CameraType, subject = cam.CameraSubject,
		controls = controls, hidden = {}, ducked = {}, tweens = {}, connections = {},
	}
	session = s
	if controls then pcall(function() controls:Disable() end) end
	Actions:BindActionAtPriority("CinematicHatchLock", function() return Enum.ContextActionResult.Sink end, false, 3000,
		table.unpack(Enum.PlayerActions:GetEnumItems()))
	-- glass stays closed; just a little clearer for this player
	for _, p in chamber:GetDescendants() do
		if p:IsA("BasePart") and (p.Material == Enum.Material.Glass or p.Name:lower():find("glass") or p.Name:find("Pane")) then
			hideInstance(s, p, 0.55)
		end
	end
	hideAvatars(s)
	-- duck what is already playing
	for _, root in { workspace, SoundService } do
		for _, snd in root:GetDescendants() do
			if snd:IsA("Sound") and snd.Playing and snd.Volume > 0 and not snd:GetAttribute("HatchFX") then
				s.ducked[snd] = snd.Volume
				tween(snd, 0.8, { Volume = snd.Volume * 0.4 })
			end
		end
	end
	s.cc = Instance.new("ColorCorrectionEffect"); s.cc.Name = "HatchFlashGrade"; s.cc.Parent = Lighting
	-- restore if the player dies, respawns, or the machine disappears
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if hum then table.insert(s.connections, hum.Died:Connect(finish)) end
	table.insert(s.connections, player.CharacterRemoving:Connect(finish))
	table.insert(s.connections, chamber.AncestryChanged:Connect(function() if not chamber:IsDescendantOf(workspace) then finish() end end))
	cam.CameraType = Enum.CameraType.Scriptable
	title.Text = "HATCHING..."
	tween(title, 0.6, { TextTransparency = 0 })
end

remote.OnClientEvent:Connect(function(action, chamber, home, value, intro)
	if action == "Start" then
		begin(chamber, home, value)
		if session then session.intro = intro or 0 end
	elseif session and chamber == session.chamber then
		if action == "Reveal" then
			session.reveal = os.clock()
			title.Text = tostring(value):upper() .. " UNLOCKED"
		elseif action == "End" then
			session.ending = os.clock()
		end
	end
end)

------------------------------------------------------------------------ frame update
local function shotFor(s, u, elapsed)
	-- slow dolly toward the egg, tighter at the tension hold, ease back for the reveal
	local dist = 4.2 - 0.7 * smooth(u / WHITE_TO) - 0.35 * smooth((u - HOLD) / 0.6)
	if s.reveal then dist += 0.9 * smooth((os.clock() - s.reveal) / 0.9) end
	-- a slow orbit across the whole sequence gives the shot parallax
	local orbit = math.rad(-10 + 18 * smooth(elapsed / ((s.intro or 0) + s.duration + 1.5)))
	local eyeLocal = CFrame.Angles(0, orbit, 0):VectorToWorldSpace(Vector3.new(0.35, 0.55 + 0.15 * smooth(u / BASE), -dist))
	-- gentle handheld drift (very low frequency, never a shake)
	local drift = Vector3.new(math.noise(elapsed * 0.45, 7.1) * 0.05, math.noise(3.3, elapsed * 0.4) * 0.035, 0)
	local eye = s.home:PointToWorldSpace(eyeLocal + drift)
	return CFrame.lookAt(eye, s.home.Position + Vector3.new(0, 0.1, 0))
end

-- camera travel bends out through the open space in front of the glass, so the
-- transition never cuts through the incubator frame
local function arc(s, from, to, k)
	local mid = s.home:PointToWorldSpace(Vector3.new(0.35, 1.4, -7.5))
	local p = (1 - k) ^ 2 * from.Position + 2 * (1 - k) * k * mid + k ^ 2 * to.Position
	return CFrame.new(p) * from.Rotation:Lerp(to.Rotation, k)
end

local function beatPose(u)
	local tx, tz, lift, shake = 0, 0, 0, 0
	for _, b in BEATS do
		local d = u - b.t
		if d >= 0 and d < b.len then
			local x = d / b.len
			local env = (1 - x) ^ 2
			local w = b.cycles <= 1 and math.sin(x * math.pi) * math.exp(-3 * x) * 2 or math.sin(x * b.cycles * TAU)
			local attack = smooth(x / 0.12) -- eases into each burst instead of snapping
			local a = math.rad(b.amp) * env * w * attack
			tx += a * math.sin(b.axis); tz += a * math.cos(b.axis)
			lift += math.abs(w) * env * 0.012 * b.amp
			shake = math.max(shake, env * b.amp / 13)
		end
	end
	if u > HOLD then -- tension: almost still, a fine tremble
		local k = smooth((u - HOLD) / 0.3)
		tx += math.rad(0.7) * k * math.sin(u * 73); tz += math.rad(0.7) * k * math.sin(u * 61 + 1)
	end
	return tx, tz, lift, shake
end

local function release(r)
	r.released = true
	r.releaseAt = os.clock()
	-- SOUND: release / shatter
	r.sparkle:Emit(16)
	r.light.Brightness = 9; r.light.Range = 11
	TweenService:Create(r.light, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0, Range = 7 }):Play()
	for _, g in r.glow do
		TweenService:Create(g.part, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 }):Play()
	end
	TweenService:Create(r.highlight, TweenInfo.new(0.5), { FillTransparency = 1, OutlineTransparency = 1 }):Play()
	for cell, piece in r.pieces do
		local still = cell == 7
		piece.vel = still and Vector3.zero or piece.dir * (2.4 + math.random() * 1.2) + Vector3.new(0, cell <= 2 and 3 or 1.9, 0)
		piece.spin = still and Vector3.zero or Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 6
		piece.pos, piece.rot = piece.dir * piece.gap, Vector3.zero
	end
end

RunService:BindToRenderStep("CinematicHatch", Enum.RenderPriority.Camera.Value + 3, function(dt)
	local now = workspace:GetServerTimeNow()
	local cam = workspace.CurrentCamera

	for egg, r in records do
		if not egg:IsDescendantOf(workspace) and not r.released then
			cleanup(r)
		elseif r.hatching and (r.state == "ready" or r.state == "effects") and (r.released or (cam.CFrame.Position - r.home.Position).Magnitude < NEAR) then
			local t = now - r.epoch
			local u = t * BASE / r.duration
			local half = r.size.Y / 2
			if not r.shown then
				r.shown = true
				r.shell = r.state == "ready"
				r.fallback = not r.shell
				r.pieces = r.shell and r.fracture.pieces or {}
				r.glow = r.shell and r.fracture.glow or {}
				-- joined late (walked up mid-hatch): skip beats already missed instead of firing them all at once
				while r.beat < #BEATS and u >= BEATS[r.beat + 1].t + 0.3 do
					r.beat += 1
					for _, cell in BEATS[r.beat].open do local p = r.pieces[cell]; if p then p.target = 0.035 end end
				end
				if not r.fallback then hideOriginal(r, true) end
				r.highlight.Adornee = r.fallback and r.egg or r.folder
				r.folder.Parent = workspace
				-- SOUND: rising hum starts here
			end
			if not r.released then
				local tx, tz, lift, shake = beatPose(u)
				r.shake = shake
				local pose = r.home * CFrame.new(0, -half + lift, 0) * CFrame.Angles(tx, 0, tz) * CFrame.new(0, half, 0)
				-- beats: crack sound, seam opens, light pops
				while r.beat < #BEATS and u >= BEATS[r.beat + 1].t do
					r.beat += 1
					local b = BEATS[r.beat]
					for _, cell in b.open do local p = r.pieces[cell]; if p then p.target = 0.035 end end
					-- SOUND: crack (b.vol / b.pitch rise with each beat)
					r.pop = 1
					r.sparkle:Emit(r.beat >= 4 and 3 or 1)
				end
				r.pop = math.max(0, (r.pop or 0) - dt * 5)
				local white = smooth((u - WHITE_FROM) / (WHITE_TO - WHITE_FROM))
				local progress = math.clamp(u / WHITE_TO, 0, 1)
				-- light leaking through the fractures
				-- the glow breathes between bursts and flares on each crack
				local breathe = 0.5 + 0.5 * math.sin(u * (3 + 5 * progress))
				for _, g in r.glow do
					g.part.CFrame = pose * g.rel
					g.part.Transparency = r.beat > 0 and math.clamp(0.35 - 0.3 * breathe * progress - 0.35 * r.pop - white, 0, 1) or 1
				end
				r.light.Brightness = (r.beat > 0 and 0.4 or 0) + 2.2 * progress * progress + 0.6 * breathe * progress + 2.5 * r.pop + 3 * white
				r.highlight.FillTransparency = 1 - 0.88 * white
				r.highlight.OutlineTransparency = 1 - 0.5 * white
				-- SOUND: cut the hum at u > BASE - 0.18 for a beat of silence before release
				for cell, piece in r.pieces do
					if white > 0 and cell ~= 7 then piece.target = math.max(piece.target, 0.035 + 0.045 * white) end
					piece.gap += (piece.target - piece.gap) * (1 - math.exp(-dt * 14))
					local capLift = cell <= 2 and 0.05 * smooth((u - HOLD) / 0.5) or 0
					local offset = CFrame.new(piece.dir * piece.gap + Vector3.new(0, capLift, 0))
					for _, e in piece.parts do e.part.CFrame = pose * offset * e.rel end
				end
				r.core.CFrame = pose
				r.pose = pose
				if r.fallback then r.egg:PivotTo(pose) end
				if t >= r.duration then release(r) end
			else
				-- shell pieces fly a short way, land inside the chamber and fade
				local age = os.clock() - r.releaseAt
				local floorY = -half
				for cell, piece in r.pieces do
					if cell ~= 7 then
						-- floaty fall: softer gravity plus air drag, so the shell drifts apart
						piece.vel -= Vector3.new(0, 18 * dt, 0)
						piece.vel *= math.exp(-1.8 * dt)
						piece.spin *= math.exp(-1.2 * dt)
						piece.pos += piece.vel * dt
						local flat = Vector3.new(piece.pos.X, 0, piece.pos.Z)
						if flat.Magnitude > 1.9 then -- stay inside the glass
							piece.pos = flat.Unit * 1.9 + Vector3.new(0, piece.pos.Y, 0)
							piece.vel = Vector3.new(0, piece.vel.Y, 0)
						end
						if piece.pos.Y < floorY + 0.3 then
							piece.pos = Vector3.new(piece.pos.X, floorY + 0.3, piece.pos.Z)
							piece.vel = Vector3.new(piece.vel.X * 0.4, 0, piece.vel.Z * 0.4)
							piece.spin *= 0.5
						end
						piece.rot += piece.spin * dt
					end
					local fade = smooth((age - (cell == 7 and 0.1 or 0.5)) / 0.6)
					local spinCF = CFrame.Angles(piece.rot.X, piece.rot.Y, piece.rot.Z)
					for _, e in piece.parts do
						e.part.CFrame = r.pose * CFrame.new(piece.pos) * spinCF * e.rel
						e.part.Transparency = fade
					end
				end
				if r.fallback and r.egg.Parent then
					local fade = smooth(age / 0.25)
					for _, p in r.egg:GetDescendants() do if p:IsA("BasePart") then p.LocalTransparencyModifier = fade end end
				end
				if age > 1.7 then cleanup(r) end
			end
		end
	end

	-- owner camera
	local s = session
	if not s then return end
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not s.chamber:IsDescendantOf(workspace) or not hum or hum.Health <= 0 or os.clock() - s.start > s.duration + (s.intro or 0) + 6 then
		finish(); return
	end
	hideAvatars(s) -- keeps late arrivals and respawned avatars out of the shot
	cam.CameraType = Enum.CameraType.Scriptable
	local intro = s.intro or 0
	local elapsed = os.clock() - s.start
	local u = math.max(0, elapsed - intro) * BASE / s.duration -- egg timeline starts after the intro
	-- zoom-in during the intro while the glass opens: moves at once, settles as the shell starts to crack
	local enter = 1 - (1 - math.clamp(elapsed / math.max(intro, 0.5), 0, 1)) ^ 3
	local target = shotFor(s, u, elapsed)
	if enter < 1 then
		s.smoothCF = arc(s, s.original, target, enter)
	else
		-- critically-damped follow: glides into every change instead of snapping
		s.smoothCF = (s.smoothCF or target):Lerp(target, 1 - math.exp(-dt * 9))
	end
	local shot = s.smoothCF
	local fov = s.fov + (55 - s.fov) * enter - 5 * smooth(u / WHITE_TO) + (s.reveal and 6 * smooth((os.clock() - s.reveal) / 0.8) or 0)
	-- restrained shake, only on the bursts
	local shake = 0
	for _, rec in records do if rec.home == s.home then shake = rec.shake or 0 end end
	local amp = shake * 0.035
	if amp > 0 then
		shot *= CFrame.new(math.noise(elapsed * 23, 1) * amp, math.noise(2, elapsed * 23) * amp, 0)
			* CFrame.Angles(0, 0, math.noise(elapsed * 19, 3) * amp * 0.4)
	end
	-- reveal flash: grows, peaks under the swap, clears gracefully (never fully opaque)
	if s.reveal then
		local k = os.clock() - s.reveal
		local up, down = smooth(k / 0.12), smooth((k - 0.25) / 0.9)
		local f = math.max(up, 0.73) * (1 - down) -- continues from the pre-flash, no dip
		flash.BackgroundTransparency = 1 - 0.55 * f
		s.cc.Brightness = 0.25 * f; s.cc.Contrast = -0.1 * f
	elseif u > BASE - 0.1 then -- release happens just before the server's reveal cue arrives
		local f = smooth((u - (BASE - 0.1)) / 0.15)
		flash.BackgroundTransparency = 1 - 0.4 * f
		s.cc.Brightness = 0.18 * f
	end
	if s.ending then
		local exit = smooth((os.clock() - s.ending) / 0.85)
		cam.CFrame = arc(s, shot, s.original, exit)
		cam.FieldOfView = fov + (s.fov - fov) * exit
		title.TextTransparency = exit
		if exit >= 1 then finish() end
	else
		cam.CFrame = shot
		cam.FieldOfView = fov
	end
end)
