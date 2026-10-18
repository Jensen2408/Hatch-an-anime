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
-- Restore Roblox UI without enabling its hotbar; GameHUD owns inventory.
local function restoreCoreGui()
 for _, coreType in Enum.CoreGuiType:GetEnumItems() do
  if coreType ~= Enum.CoreGuiType.All then
   pcall(StarterGui.SetCoreGuiEnabled, StarterGui, coreType, coreType ~= Enum.CoreGuiType.Backpack)
  end
 end
end

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

-- raised square-stud button: dark base underneath, cream face on top, square studs on the surface
local skip = Instance.new("TextButton")
skip.Name = "Skip"; skip.AnchorPoint = Vector2.new(1, 1); skip.Position = UDim2.new(1, -24, 1, -24)
skip.Size = UDim2.fromOffset(150, 60); skip.BackgroundColor3 = Color3.new(0, 0, 0); skip.BorderSizePixel = 0
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = skip end
skip.Text = ""; skip.AutoButtonColor = false; skip.Parent = ui
local scale = Instance.new("UIScale"); scale.Parent = skip
local face = Instance.new("Frame")
face.Name = "Face"; face.Size = UDim2.new(1, 0, 1, -5); face.BackgroundColor3 = Color3.new(1, 1, 1); face.BorderSizePixel = 0
face.Parent = skip
face.BackgroundColor3 = Color3.new(1, 1, 1)
do local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 12); c.Parent = face; local g = Instance.new("UIGradient"); g.Rotation = 90; g.Color = ColorSequence.new(Color3.fromRGB(90, 170, 255), Color3.fromRGB(20, 70, 200)); g.Parent = face end
local faceStroke = Instance.new("UIStroke"); faceStroke.Thickness = 3; faceStroke.Color = Color3.new(1, 1, 1); faceStroke.LineJoinMode = Enum.LineJoinMode.Round; faceStroke.Parent = face
local skipStrip = Instance.new("Frame"); skipStrip.Size = UDim2.new(1, 0, 0, 5); skipStrip.BackgroundColor3 = Color3.fromRGB(255, 150, 30); skipStrip.BorderSizePixel = 0; skipStrip.Visible = false; skipStrip.Parent = face
local studTex = Instance.new("ImageLabel")
studTex.Name = "StudTex"; studTex.BackgroundTransparency = 1; studTex.Size = UDim2.fromScale(1, 1)
studTex.Image = "rbxassetid://132561191216691"; studTex.ImageTransparency = 0.45; studTex.ScaleType = Enum.ScaleType.Tile; studTex.TileSize = UDim2.fromOffset(18, 18)
studTex.Parent = face
local label = Instance.new("TextLabel")
label.BackgroundTransparency = 1; label.Size = UDim2.fromScale(1, 1); label.Font = Enum.Font.FredokaOne
label.Text = "SKIP ▶▶"; label.TextSize = 26; label.TextColor3 = Color3.new(1, 1, 1); label.Parent = face
do local ls = Instance.new("UIStroke"); ls.Color = Color3.new(0, 0, 0); ls.Thickness = 2.5; ls.Parent = label end
local function rescale()
	local s = ui.AbsoluteSize
	scale.Scale = math.clamp(math.min(s.X, s.Y) / 720, s.Y < 500 and 0.6 or 0.8, 1.15) -- smaller skip button on phones
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
	-- "Hero" arrival: close-up on YOUR character's face, then orbit round to the normal camera behind you.
	local root = char:FindFirstChild("HumanoidRootPart")
	local spawn = plot:FindFirstChild("PlotSpawn")
	if not root or not spawn then return nil end
	local head = char:FindFirstChild("Head")
	local headPos = head and head.Position or (root.Position + Vector3.new(0, 2, 0))
	local focus = root.Position + Vector3.new(0, 1.5, 0) -- where the default camera looks
	local fwd = flat(spawn.CFrame.LookVector)
	local right = fwd:Cross(UP)
	local pitch = math.rad(Config.EndPitch)
	local dist = Config.EndDistance
	local endPos = focus - fwd * math.cos(pitch) * dist + UP * math.sin(pitch) * dist + right * Config.ShoulderOffset
	local hit = blocked(focus, endPos)
	if hit then endPos = focus + (hit.Position - focus).Unit * math.max(2, (hit.Position - focus).Magnitude - 0.6) end
	local endCF = CFrame.lookAt(endPos, focus)
	local face = flat(root.CFrame.LookVector)
	local a0 = math.atan2(face.X, face.Z) -- camera starts in front of the face
	local off = endPos - focus
	local a1 = math.atan2(off.X, off.Z)
	local da = (a1 - a0 + math.pi) % (2 * math.pi) - math.pi
	if math.abs(da) < 0.6 then da = math.pi end -- always a proper swing round
	return {
		head = headPos, focus = focus, endCF = endCF, finish = endPos,
		a0 = a0, da = da, d0 = 5.5, d1 = Vector3.new(off.X, 0, off.Z).Magnitude, h0 = 0.25, h1 = off.Y,
	}
end

local function poseAt(path, p)
	if p >= 1 then return path.endCF end
	local ang = path.a0 + path.da * p
	local dist = path.d0 + (path.d1 - path.d0) * p
	local h = path.h0 + (path.h1 - path.h0) * p
	local target = path.head:Lerp(path.focus, p)
	local pos = target + Vector3.new(math.sin(ang), 0, math.cos(ang)) * dist + UP * h
	return CFrame.lookAt(pos, target)
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
		-- (sky shot is prepared immediately; the loading screen fades over it once it is in place)
		-- 2. plot assigned by the server, character spawned at that plot
		local plot = waitFor(findPlot, Config.PlotWaitTimeout)
		if not plot then error("no assigned plot") end
		local char = waitFor(function()
			local c = player.Character
			local rp = c and c:FindFirstChild("HumanoidRootPart")
			local sp = plot:FindFirstChild("PlotSpawn")
			return rp and sp and (rp.Position - sp.Position).Magnitude < 14 and c
		end, 4)
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
		waitFor(function() return player:GetAttribute("LoadingScreenDone") or not (playerGui:FindFirstChild("LaunchLoadingScreen") or playerGui:FindFirstChild("HatchLoading")) end, Config.LoadingScreenWait)
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
	do -- clean welcome card with your name
		local card = Instance.new("Frame") card.Name = "WelcomeCard" card.AnchorPoint = Vector2.new(0.5, 1) card.Position = UDim2.new(0.5, 0, 1, -70)
		card.Size = UDim2.fromOffset(0, 104) card.AutomaticSize = Enum.AutomaticSize.X card.BackgroundColor3 = Color3.new(1, 1, 1) card.BorderSizePixel = 0 card.ZIndex = 50
		do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 14) c.Parent = card
			local g = Instance.new("UIGradient") g.Rotation = 90 g.Color = ColorSequence.new(Color3.fromRGB(255, 92, 168), Color3.fromRGB(150, 10, 84)) g.Parent = card
			local st = Instance.new("UIStroke") st.Color = Color3.new(1, 1, 1) st.Thickness = 4 st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border st.Parent = card
			local stud = Instance.new("ImageLabel") stud.Name = "Studs" stud.BackgroundTransparency = 1 stud.Size = UDim2.fromScale(1, 1) stud.Image = "rbxassetid://132561191216691" stud.ImageTransparency = 0.4 stud.ScaleType = Enum.ScaleType.Tile stud.TileSize = UDim2.fromOffset(18, 18) stud.ZIndex = 50 stud.Parent = card
			local stc = Instance.new("UICorner") stc.CornerRadius = UDim.new(0, 14) stc.Parent = stud
			end
		local pad = Instance.new("UIPadding") pad.PaddingLeft = UDim.new(0, 20) pad.PaddingRight = UDim.new(0, 20) pad.Parent = card
		-- content row (the stud texture must not be part of the list layout, or it pushes the avatar and name off the card)
		local row = Instance.new("Frame") row.Name = "Content" row.BackgroundTransparency = 1 row.AutomaticSize = Enum.AutomaticSize.X row.Size = UDim2.fromScale(0, 1) row.ZIndex = 52 row.Parent = card
		local list = Instance.new("UIListLayout") list.FillDirection = Enum.FillDirection.Horizontal list.VerticalAlignment = Enum.VerticalAlignment.Center list.Padding = UDim.new(0, 16) list.SortOrder = Enum.SortOrder.LayoutOrder list.Parent = row
		local av = Instance.new("ImageLabel") av.Name = "Avatar" av.Size = UDim2.fromOffset(80, 80) av.BackgroundColor3 = Color3.fromRGB(59, 120, 255) av.ZIndex = 52 av.LayoutOrder = 1 av.Parent = row
		do local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, 12) c.Parent = av local st2 = Instance.new("UIStroke") st2.Color = Color3.new(1, 1, 1) st2.Thickness = 3 st2.Parent = av
			task.spawn(function() local ok, img = pcall(function() return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150) end) if ok then av.Image = img end end) end
		local col = Instance.new("Frame") col.BackgroundTransparency = 1 col.Size = UDim2.fromOffset(0, 80) col.AutomaticSize = Enum.AutomaticSize.X col.LayoutOrder = 2 col.ZIndex = 52 col.Parent = row
		local cl = Instance.new("UIListLayout") cl.VerticalAlignment = Enum.VerticalAlignment.Center cl.Padding = UDim.new(0, 0) cl.Parent = col
		local small = Instance.new("TextLabel") small.BackgroundTransparency = 1 small.Size = UDim2.fromOffset(0, 26) small.AutomaticSize = Enum.AutomaticSize.X small.TextXAlignment = Enum.TextXAlignment.Left
		small.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json") small.TextSize = 22 small.TextColor3 = Color3.fromRGB(255, 226, 240) small.ZIndex = 52 small.Text = "WELCOME BACK,"
		do local ss = Instance.new("UIStroke") ss.Color = Color3.fromRGB(13, 10, 20) ss.Thickness = 2 ss.Parent = small end small.Parent = col
		local t = Instance.new("TextLabel") t.BackgroundTransparency = 1 t.Size = UDim2.fromOffset(0, 50) t.AutomaticSize = Enum.AutomaticSize.X t.TextXAlignment = Enum.TextXAlignment.Left
		t.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json") t.TextSize = 44 t.TextColor3 = Color3.new(1, 1, 1) t.ZIndex = 52
		t.Text = string.upper(player.DisplayName) .. "!"
		local ts = Instance.new("UIStroke") ts.Color = Color3.fromRGB(13, 10, 20) ts.Thickness = 4 ts.Parent = t
		t.Parent = col
		local vs = ui.AbsoluteSize local full = math.clamp(math.min(vs.X, vs.Y) / 1100, 0.42, 0.72) -- smaller, scales with screen
		card.Position = UDim2.new(0.5, 0, 1, -40)
		local sc = Instance.new("UIScale") sc.Scale = 0.6 * full sc.Parent = card
		card.Parent = ui
		TweenService:Create(sc, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Scale = full }):Play()
		task.delay(travel - 0.3, function() if card.Parent then TweenService:Create(sc, TweenInfo.new(0.2), { Scale = 0 }):Play() task.delay(0.25, function() card:Destroy() end) end end)
	end

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
			setCharacterAlpha(r.char, 0)
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
