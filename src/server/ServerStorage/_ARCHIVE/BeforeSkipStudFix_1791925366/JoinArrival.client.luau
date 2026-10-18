--[[ JoinArrival (LocalScript, StarterPlayerScripts)
	Sky-to-player arrival that plays once per join:
	  sky view -> descent toward YOUR temple plot -> settle behind your character -> normal camera.
	The server (PlotManager) already assigns the plot and spawns the character at plot.PlotSpawn;
	this script only waits for that, then animates the camera locally.

	Handshake with ReplicatedFirst.LaunchLoadingScreen (player attributes):
	  LoadingScreenFinishing  set by the loading screen when it is about to fade out
	  JoinArrivalCameraSet    set here once the sky shot is in place (the loading screen waits for it)
	  LoadingScreenDone       set by the loading screen after its fade
	  JoinArrivalStarted / JoinArrivalFinished  so the loading screen knows who restores the HUD
	Settings: ReplicatedStorage.JoinArrival.Config
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local StarterGui = game:GetService("StarterGui")
local Actions = game:GetService("ContextActionService")
local PromptService = game:GetService("ProximityPromptService")
local UserInput = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local folder = ReplicatedStorage:WaitForChild("JoinArrival")
local Config = require(folder:WaitForChild("Config"))
local UP = Vector3.yAxis

local function clamp01(x) return math.clamp(x, 0, 1) end
local function smooth(x) x = clamp01(x) return x * x * (3 - 2 * x) end
local function smoother(x) x = clamp01(x) return x * x * x * (x * (x * 6 - 15) + 10) end
local function flat(v) v = Vector3.new(v.X, 0, v.Z) return v.Magnitude > 1e-3 and v.Unit or Vector3.new(0, 0, -1) end

------------------------------------------------------------------------ UI: cover + skip button
local WOOD = Color3.fromRGB(74, 44, 30)
local CREAM_TOP = Color3.fromRGB(255, 248, 232)
local CREAM_BOT = Color3.fromRGB(243, 215, 166)
local SKY = Color3.fromRGB(214, 236, 255)

local ui = Instance.new("ScreenGui")
ui.Name = "JoinArrivalUI"; ui.IgnoreGuiInset = true; ui.ResetOnSpawn = false; ui.DisplayOrder = 900
ui.Enabled = false; ui.Parent = playerGui

local cover = Instance.new("Frame")
cover.Name = "AtmosphereCover"; cover.Size = UDim2.fromScale(1, 1); cover.BorderSizePixel = 0
cover.BackgroundColor3 = SKY; cover.BackgroundTransparency = 1; cover.Parent = ui

-- raised square-stud button: dark base underneath, cream face on top, two studs on the lid
local skip = Instance.new("TextButton")
skip.Name = "Skip"; skip.AnchorPoint = Vector2.new(1, 1); skip.Position = UDim2.new(1, -24, 1, -24)
skip.Size = UDim2.fromOffset(124, 50); skip.BackgroundColor3 = WOOD; skip.BorderSizePixel = 0
skip.Text = ""; skip.AutoButtonColor = false; skip.Parent = ui
Instance.new("UICorner", skip).CornerRadius = UDim.new(0, 10)
local scale = Instance.new("UIScale"); scale.Parent = skip
local face = Instance.new("Frame")
face.Name = "Face"; face.Size = UDim2.new(1, 0, 1, -5); face.BackgroundColor3 = Color3.new(1, 1, 1); face.BorderSizePixel = 0
face.Parent = skip
Instance.new("UICorner", face).CornerRadius = UDim.new(0, 10)
local faceStroke = Instance.new("UIStroke"); faceStroke.Thickness = 3; faceStroke.Color = WOOD; faceStroke.Parent = face
local grad = Instance.new("UIGradient"); grad.Rotation = 90; grad.Color = ColorSequence.new(CREAM_TOP, CREAM_BOT); grad.Parent = face
for i, x in { 0.3, 0.7 } do
	local stud = Instance.new("Frame")
	stud.Name = "Stud" .. i; stud.AnchorPoint = Vector2.new(0.5, 1); stud.Position = UDim2.new(x, 0, 0, 2)
	stud.Size = UDim2.fromOffset(16, 6); stud.BackgroundColor3 = CREAM_TOP; stud.BorderSizePixel = 0; stud.Parent = face
	Instance.new("UICorner", stud).CornerRadius = UDim.new(0, 3)
	local s = Instance.new("UIStroke"); s.Thickness = 2; s.Color = WOOD; s.Parent = stud
end
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1; label.Size = UDim2.fromScale(1, 1); label.Font = Enum.Font.FredokaOne
label.Text = "Skip  ▸"; label.TextSize = 24; label.TextColor3 = WOOD; label.Parent = face
local function rescale()
	local s = ui.AbsoluteSize
	scale.Scale = math.clamp(math.min(s.X, s.Y) / 720, 0.8, 1.15)
end
ui:GetPropertyChangedSignal("AbsoluteSize"):Connect(rescale); rescale()
skip.MouseButton1Down:Connect(function() face.Position = UDim2.fromOffset(0, 3) end)
skip.MouseButton1Up:Connect(function() face.Position = UDim2.fromOffset(0, 0) end)
skip.MouseLeave:Connect(function() face.Position = UDim2.fromOffset(0, 0) end)

------------------------------------------------------------------------ sounds (optional)
local function makeSound(slot)
	local cfg = Config.Sounds and Config.Sounds[slot]
	if not cfg or not cfg.Id or cfg.Id == "" then return nil end
	local s = Instance.new("Sound"); s.Name = "JoinArrival" .. slot; s.SoundId = cfg.Id; s.Volume = cfg.Volume or 0.5
	s.Parent = ui
	return s, cfg.Volume or 0.5
end

------------------------------------------------------------------------ helpers
local function findPlot()
	local id = player:GetAttribute("PlotId")
	local plots = workspace:FindFirstChild("Plots")
	if not id or not plots then return nil end
	for _, p in plots:GetChildren() do
		if p:GetAttribute("PlotId") == id and p:GetAttribute("OwnerUserId") == player.UserId then return p end
	end
end

local function waitFor(check, timeout)
	local t0 = os.clock()
	while os.clock() - t0 < timeout do
		local v = check()
		if v then return v end
		task.wait(0.1)
	end
end

local function mapBounds(plotsFolder)
	local mn, mx = Vector3.one * math.huge, -Vector3.one * math.huge
	local function add(cf, size)
		local h = size / 2
		mn = mn:Min(cf.Position - h); mx = mx:Max(cf.Position + h)
	end
	for _, p in plotsFolder:GetChildren() do
		local a = p:FindFirstChild("TempleAnchor")
		if a then add(a.CFrame, Vector3.new(84, 50, 74)) end -- plot footprint (works even if the plot is not streamed in)
	end
	local river = workspace:FindFirstChild("WaterfallRiver")
	if river and river:IsA("Model") then add(river:GetBoundingBox()) end
	return (mn + mx) / 2, mx - mn, mx
end

-- blocking geometry between two points (characters ignored)
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true
local function blocked(a, b)
	local chars = {}
	for _, p in Players:GetPlayers() do if p.Character then table.insert(chars, p.Character) end end
	rayParams.FilterDescendantsInstances = chars
	local hit = workspace:Raycast(a, b - a, rayParams)
	return hit
end

-- cubic bezier
local function bezier(p0, p1, p2, p3, t)
	local u = 1 - t
	return p0 * u * u * u + p1 * 3 * u * u * t + p2 * 3 * u * t * t + p3 * t * t * t
end

------------------------------------------------------------------------ the run
local run -- current arrival state (nil when idle)

-- gameplay UI hidden while the arrival plays, faded back in at the handoff
local function isOurs(g) return g == ui or g.Name == "LaunchLoadingScreen" or g.Name == "HatchLoading" or g.Name == "CinematicHatchUI" end
local function hideGui(r, g)
	if g:IsA("ScreenGui") and not isOurs(g) and (g.Enabled or g.Name == "HUD") and not r.guis[g] then
		r.guis[g] = true; g.Enabled = false
	end
end

local FADE_PROPS = {
	GuiObject = { "BackgroundTransparency" },
	TextLabel = { "TextTransparency", "TextStrokeTransparency" },
	TextButton = { "TextTransparency", "TextStrokeTransparency" },
	TextBox = { "TextTransparency", "TextStrokeTransparency" },
	ImageLabel = { "ImageTransparency" },
	ImageButton = { "ImageTransparency" },
	UIStroke = { "Transparency" },
}
local function fadeInGuis(guis, time)
	local saved = {}
	for g in guis do
		if g.Parent then
			if time > 0 then
				for _, d in g:GetDescendants() do
					for class, props in FADE_PROPS do
						if d:IsA(class) then
							for _, prop in props do
								local v = d[prop]
								if v < 1 then
									table.insert(saved, { d, prop, v })
									d[prop] = 1
									TweenService:Create(d, TweenInfo.new(time, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { [prop] = v }):Play()
								end
							end
						end
					end
				end
			end
			g.Enabled = true
		end
	end
	-- make sure every value lands exactly where it was
	task.delay(time + 0.05, function()
		for _, s in saved do if s[1].Parent then s[1][s[2]] = s[3] end end
	end)
end

-- floating labels (player role tags, owner banners, egg names, price tags) stay hidden until
-- the character has landed. MaxDistance is used instead of Enabled because other scripts
-- toggle Enabled themselves.
local function hideLabel(r, b)
	if b:IsA("BillboardGui") and r.labels[b] == nil then
		r.labels[b] = b.MaxDistance
		b.MaxDistance = 0.001
	end
end
local function hideLabels(r)
	for _, root in { workspace, playerGui } do
		for _, d in root:GetDescendants() do hideLabel(r, d) end
		table.insert(r.conns, root.DescendantAdded:Connect(function(d) if not r.labelsShown then hideLabel(r, d) end end))
	end
end
local function showLabels(r)
	if r.labelsShown then return end
	r.labelsShown = true
	for b, dist in r.labels do if b.Parent then b.MaxDistance = dist end end
	r.labels = {}
end

local function setCharacterAlpha(char, a)
	if not char then return end
	for _, d in char:GetDescendants() do
		if d:IsA("BasePart") or d:IsA("Decal") then d.LocalTransparencyModifier = a end
	end
end

local function lockControls(on)
	if on then
		Actions:BindActionAtPriority("JoinArrivalLock", function() return Enum.ContextActionResult.Sink end, false, 3500,
			table.unpack(Enum.PlayerActions:GetEnumItems()))
	else
		Actions:UnbindAction("JoinArrivalLock")
	end
end

-- one place that puts everything back, used by the normal end, skip, death and failures
local function restore(r, guiFade)
	if r.restored then return end
	r.restored = true
	for _, c in r.conns do c:Disconnect() end
	showLabels(r)
	RunService:UnbindFromRenderStep("JoinArrivalCamera")
	lockControls(false)
	PromptService.Enabled = r.promptsWere ~= false
	local cam = workspace.CurrentCamera
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if cam.CameraType == Enum.CameraType.Scriptable then
		cam.CameraType = Enum.CameraType.Custom
		if hum then cam.CameraSubject = hum end
	end
	cam.FieldOfView = r.fov
	setCharacterAlpha(player.Character, 0)
	if r.ambience then
		local s = r.ambience
		TweenService:Create(s, TweenInfo.new(0.6), { Volume = 0 }):Play()
		task.delay(0.7, function() s:Destroy() end)
	end
	if r.whoosh then r.whoosh:Destroy() end
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
	fadeInGuis(r.guis, guiFade or 0)
	skip.Visible = false
	TweenService:Create(cover, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
	task.delay(0.4, function() if run == nil or run == r then ui.Enabled = false end end)
	player:SetAttribute("JoinArrivalFinished", true)
	if run == r then run = nil end
end

-- builds the camera journey for this plot; returns nil if it cannot be framed
local function buildPath(plot, char)
	local root = char:FindFirstChild("HumanoidRootPart")
	local spawn = plot:FindFirstChild("PlotSpawn")
	local anchor = plot:FindFirstChild("TempleAnchor")
	if not root or not spawn or not anchor then return nil end

	local focus = root.Position + Vector3.new(0, 1.5, 0) -- where the default camera looks
	local fwd = flat(spawn.CFrame.LookVector) -- facing into the plot
	local right = fwd:Cross(UP)
	local pitch = math.rad(Config.EndPitch)
	local dist = Config.EndDistance
	local endPos = focus - fwd * math.cos(pitch) * dist + UP * math.sin(pitch) * dist + right * Config.ShoulderOffset
	-- keep the landing spot out of walls/roofs: pull in toward the character if something is in the way
	local hit = blocked(focus, endPos)
	if hit then endPos = focus + (hit.Position - focus).Unit * math.max(2, (hit.Position - focus).Magnitude - 0.6) end
	local endCF = CFrame.lookAt(endPos, focus)

	local center, size, top = mapBounds(plot.Parent)
	local radius = math.max(size.X, size.Z) / 2
	local plotCenter = anchor.Position
	local side = math.rad(Config.SkySideAngle)
	local awayDir = CFrame.Angles(0, side, 0):VectorToWorldSpace(-fwd)
	local startPos = plotCenter + awayDir * radius * Config.SkyBackScale
	startPos = Vector3.new(startPos.X, math.max(top.Y, plotCenter.Y) + radius * Config.SkyHeightScale, startPos.Z)
	local skyLook = plotCenter:Lerp(center, Config.SkyLookBias or 0.3)
	local templeLook = plotCenter + UP * 12

	-- controls: stay high while travelling over, then come in low from behind the spawn
	local p1 = startPos:Lerp(plotCenter, 0.45) + UP * radius * 0.08
	local lift = 16
	local p2
	for _ = 1, 5 do -- raise the low control point until the final stretch is clear
		p2 = endPos - fwd * 22 + UP * lift
		local clear = true
		local prev = bezier(startPos, p1, p2, endPos, 0.6)
		for i = 1, 10 do
			local pt = bezier(startPos, p1, p2, endPos, 0.6 + 0.4 * i / 10)
			if blocked(prev, pt) then clear = false break end
			prev = pt
		end
		if clear then break end
		lift += 10
	end
	return {
		start = startPos, p1 = p1, p2 = p2, finish = endPos, endCF = endCF,
		focus = focus, skyLook = skyLook, templeLook = templeLook, plotCenter = plotCenter,
	}
end

local function poseAt(path, p)
	local pos = bezier(path.start, path.p1, path.p2, path.finish, p)
	local look = path.skyLook:Lerp(path.templeLook, smooth(p / 0.6)):Lerp(path.focus, smoother((p - 0.45) / 0.55))
	if p >= 1 then return path.endCF end
	return CFrame.lookAt(pos, look)
end

local function streamAround(position)
	if not workspace.StreamingEnabled then return end
	pcall(function() player:RequestStreamAroundAsync(position, Config.StreamTimeout) end)
end

local function begin(isReplay)
	if run then return end
	local r = { guis = {}, labels = {}, conns = {}, fov = workspace.CurrentCamera.FieldOfView, promptsWere = PromptService.Enabled }
	run = r
	player:SetAttribute("JoinArrivalStarted", true)
	player:SetAttribute("JoinArrivalFinished", nil)
	ui.Enabled = true; skip.Visible = false
	lockControls(true)
	PromptService.Enabled = false
	hideLabels(r)
	for _, g in playerGui:GetChildren() do hideGui(r, g) end
	table.insert(r.conns, playerGui.ChildAdded:Connect(function(g) task.defer(function() if not r.restored then hideGui(r, g) end end) end))
	pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, false)

	local ok, err = pcall(function()
		-- 1. loading screen nearly done (it waits for our sky shot before fading)
		if not isReplay then
			waitFor(function()
				return player:GetAttribute("LoadingScreenFinishing") or player:GetAttribute("LoadingScreenDone")
					or not (playerGui:FindFirstChild("LaunchLoadingScreen") or playerGui:FindFirstChild("HatchLoading"))
			end, Config.LoadingScreenWait)
		end
		-- 2. plot assigned by the server, character spawned at that plot
		local plot = waitFor(findPlot, Config.PlotWaitTimeout)
		if not plot then error("no assigned plot") end
		local char = waitFor(function()
			local c = player.Character
			local rp = c and c:FindFirstChild("HumanoidRootPart")
			local sp = plot:FindFirstChild("PlotSpawn")
			return rp and sp and (rp.Position - sp.Position).Magnitude < 14 and c
		end, Config.PlotWaitTimeout)
		if not char then error("character not at plot") end
		-- 3. make sure the destination exists on this client (StreamingEnabled)
		streamAround(plot.TempleAnchor.Position)
		local path = buildPath(plot, char)
		if not path then error("plot not streamed in") end
		r.path = path
		r.char = char
	end)
	if not ok then
		warn("JoinArrival skipped, starting normal gameplay: " .. tostring(err))
		player:SetAttribute("JoinArrivalCameraSet", true)
		restore(r, 0.35)
		return
	end

	local cam = workspace.CurrentCamera
	local hum = r.char:FindFirstChildOfClass("Humanoid")
	cam.CameraType = Enum.CameraType.Scriptable
	cam.CFrame = poseAt(r.path, 0)
	cam.FieldOfView = Config.StartFov
	setCharacterAlpha(r.char, 1)
	player:SetAttribute("JoinArrivalCameraSet", true)

	-- abort cleanly on death / reset / respawn
	if hum then table.insert(r.conns, hum.Died:Connect(function() restore(r, 0.2) end)) end
	table.insert(r.conns, player.CharacterRemoving:Connect(function() restore(r, 0.2) end))

	-- if the loading screen is still up, give it a moment to fade over our sky shot
	if not isReplay then
		waitFor(function() return player:GetAttribute("LoadingScreenDone") or not (playerGui:FindFirstChild("LaunchLoadingScreen") or playerGui:FindFirstChild("HatchLoading")) end, 3)
	else
		cover.BackgroundTransparency = 0
	end

	local reduced = GuiService.ReducedMotionEnabled or Config.ForceReducedMotion or folder:GetAttribute("ForceReducedMotion") == true
	local travel = Config.SkyTime + Config.ApproachTime + Config.RevealTime
	local t0 = os.clock()
	local handoffAt, handoffCF
	local ambience, ambVol = makeSound("Ambience")
	if ambience then r.ambience = ambience; ambience.Looped = true; ambience.Volume = 0; ambience:Play()
		TweenService:Create(ambience, TweenInfo.new(0.8), { Volume = ambVol }):Play() end
	local whoosh = makeSound("Whoosh"); r.whoosh = whoosh
	local whooshed = false

	-- the atmosphere cover starts slightly hazy and clears during the sky beat
	if cover.BackgroundTransparency > 0.3 then cover.BackgroundTransparency = 0.3 end
	TweenService:Create(cover, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), { BackgroundTransparency = 1 }):Play()
	skip.Visible = true

	local function startHandoff()
		if handoffAt then return end
		handoffAt = os.clock()
		handoffCF = cam.CFrame
		skip.Visible = false
		setCharacterAlpha(r.char, 0)
		-- hand the camera back already pointing where the default camera will look
		cam.CFrame = r.path.endCF
		cam.Focus = CFrame.new(r.path.focus)
		cam.CameraType = Enum.CameraType.Custom
		if hum then cam.CameraSubject = hum end
		lockControls(false)
		PromptService.Enabled = r.promptsWere ~= false
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.All, true)
		fadeInGuis(r.guis, Config.HandoffTime)
		r.guis = {}
		local arrival = makeSound("Arrival")
		if arrival then arrival:Play(); task.delay(4, function() arrival:Destroy() end) end
	end

	-- skip / reduced motion: short fade straight to the landing shot
	local function jumpToEnd()
		if handoffAt or r.jumping then return end
		r.jumping = true
		skip.Visible = false
		TweenService:Create(cover, TweenInfo.new(0.2), { BackgroundTransparency = 0 }):Play()
		task.delay(0.22, function()
			if r.restored then return end
			t0 = os.clock() - travel -- timeline at the landing
			cam.CFrame = r.path.endCF
			cam.FieldOfView = r.fov
			startHandoff()
			handoffCF = r.path.endCF
			TweenService:Create(cover, TweenInfo.new(0.45, Enum.EasingStyle.Sine), { BackgroundTransparency = 1 }):Play()
		end)
	end
	table.insert(r.conns, skip.Activated:Connect(jumpToEnd))
	-- safety: if frames stop (window minimised, Studio in the background) never leave the game locked
	task.delay(travel + Config.HandoffTime + 6, function()
		if not r.restored then
			warn("JoinArrival timed out, restoring gameplay")
			restore(r, 0.3)
		end
	end)
	if reduced then jumpToEnd() end

	RunService:BindToRenderStep("JoinArrivalCamera", Enum.RenderPriority.Camera.Value + 1, function()
		if r.restored then return end
		local t = os.clock() - t0
		-- Studio scrubber: set ReplicatedStorage.JoinArrival "PreviewTime" (seconds) during a replay to freeze there
		local scrub = RunService:IsStudio() and folder:GetAttribute("PreviewTime")
		if typeof(scrub) == "number" and not handoffAt then t = math.clamp(scrub, 0, travel - 0.01); t0 = os.clock() - t end
		if not handoffAt then
			if r.jumping then return end
			local p = smoother(t / travel) -- slow sky beat, faster middle, soft landing
			cam.CameraType = Enum.CameraType.Scriptable
			cam.CFrame = poseAt(r.path, p)
			cam.FieldOfView = Config.StartFov + (r.fov - Config.StartFov) * smooth(p)
			-- character fades in during the reveal beat
			local revealStart = (Config.SkyTime + Config.ApproachTime) / travel
			setCharacterAlpha(r.char, 1 - smooth((t / travel - revealStart) / (1 - revealStart) * 1.4))
			if whoosh and not whooshed and t > Config.SkyTime * 0.8 then whooshed = true; whoosh:Play() end
			if t >= travel then startHandoff() end
		else
			-- handoff: the default camera is running again; ease from our last frame into its output
			local k = smooth((os.clock() - handoffAt) / Config.HandoffTime)
			cam.CFrame = handoffCF:Lerp(cam.CFrame, k)
			if k >= 1 then restore(r, 0) end
		end
	end)
end

------------------------------------------------------------------------ entry
task.spawn(function()
	if folder:GetAttribute("Enabled") == false then
		player:SetAttribute("JoinArrivalCameraSet", true)
		return
	end
	-- The loading screen owns startup. Do not start its cinematic on an arbitrary timer.
while not player:GetAttribute("LoadingScreenFinishing") and not player:GetAttribute("LoadingScreenDone") do
 if not (playerGui:FindFirstChild("LaunchLoadingScreen") or playerGui:FindFirstChild("HatchLoading")) and not game:GetService("ReplicatedFirst"):FindFirstChild("LaunchLoadingScreen") then break end
 task.wait(.1)
end
local ok, err = pcall(begin, false)
	if not ok then
		warn("JoinArrival failed: " .. tostring(err))
		player:SetAttribute("JoinArrivalCameraSet", true)
		if run then restore(run, 0.3) end
	end
end)

-- Studio preview: replay the arrival with a key press (or ui.ReplayArrival:Fire()) during a play test
if RunService:IsStudio() then
	local replay = Instance.new("BindableEvent"); replay.Name = "ReplayArrival"; replay.Parent = ui
	replay.Event:Connect(function() if not run then task.spawn(begin, true) end end)
end
if RunService:IsStudio() and Config.StudioReplayKey then
	UserInput.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Config.StudioReplayKey and not run then
			task.spawn(begin, true)
		end
	end)
end
