--[[ StarterPlayerScripts.RoleTagClient  (LocalScript)
Draws the OWNER / CO-OWNER / YOUTUBE tag above every tagged player's head. Cosmetic, client-only.
One tag per character; rebuilt on respawn; every tween/connection is cleaned up when the character goes.
]]
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local Config = {
	Height = 1.8,             -- studs above the head
	BaseSize = Vector2.new(3.8, 0.85), -- studs (in-world size, shrinks with distance)
	MinScale = 0.4, MaxScale = 1.0, -- on-screen cap so distant tags never look huge
	MaxDistance = 120,
	Font = Enum.Font.FredokaOne,
	Face = { Color3.fromRGB(255, 106, 92), Color3.fromRGB(239, 42, 46), Color3.fromRGB(180, 13, 23) },
	Outline = Color3.fromRGB(10, 5, 6),
	Glow = Color3.fromRGB(255, 40, 40),
	ShineEvery = { ["OWNER"] = 4.2, ["CO-OWNER"] = 5, ["YOUTUBE"] = 5 },
	ShineTime = 0.9,
	Emphasis = { ["OWNER"] = 1, ["CO-OWNER"] = 0.82, ["YOUTUBE"] = 0.86 },
}
local CROWN = {
	["OWNER"] = { "#.#.#.#", "#######", "##.#.##", "#######" },
	["CO-OWNER"] = { "..#.#..", ".#####.", "##.#.##", ".#####." },
}
local PLAY = { "#...", "##..", "###.", "##..", "#..." }

local function make(class, props, parent) local o = Instance.new(class); for k, v in props do o[k] = v end; o.Parent = parent; return o end
local function tween(o, t, props, s, d, rep, rev) local tw = TweenService:Create(o, TweenInfo.new(t, s or Enum.EasingStyle.Quad, d or Enum.EasingDirection.Out, rep or 0, rev or false), props); tw:Play(); return tw end

local tags = {} -- [character] = state
local revisions = setmetatable({}, {__mode = "k"})

local function textLayer(parent, name, text, z, color)
	return make("TextLabel", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Config.Font, Text = text,
		TextScaled = true, TextColor3 = color or Color3.new(1, 1, 1), ZIndex = z }, parent)
end

local function build(character, role, revision)
	local head = character:WaitForChild("Head", 10)
	if not head or not character.Parent or revisions[character] ~= revision then return end
	local k = Config.Emphasis[role] or 1
	local st = { conns = {}, tweens = {} }
	local gui = make("BillboardGui", { Name = "RoleTag", Adornee = head, Size = UDim2.new(Config.BaseSize.X * k, 0, Config.BaseSize.Y * k, 0),
		StudsOffsetWorldSpace = Vector3.new(0, Config.Height, 0), AlwaysOnTop = true, LightInfluence = 0, MaxDistance = Config.MaxDistance,
		ResetOnSpawn = false, ClipsDescendants = false }, head)
	local root = make("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), Position = UDim2.fromScale(0, 0.25), BackgroundTransparency = 1 }, gui)
	local pop = make("UIScale", { Scale = 0.9 }, root)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, HorizontalAlignment = Enum.HorizontalAlignment.Center, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0.03, 0), SortOrder = Enum.SortOrder.LayoutOrder }, root)
	-- emblem (stud pixels)
	local rows = CROWN[role] or PLAY
	local cols = #rows[1]
	local em = make("Frame", { Name = "Emblem", LayoutOrder = 1, Size = UDim2.fromScale(0.13, 0.62), BackgroundTransparency = 1 }, root)
	make("UIAspectRatioConstraint", { AspectRatio = role == "YOUTUBE" and 1.36 or cols / #rows }, em)
	if role == "YOUTUBE" then
		em.BackgroundColor3 = Color3.fromRGB(239, 42, 46); em.BackgroundTransparency = 0
		make("UICorner", { CornerRadius = UDim.new(0.22, 0) }, em)
		make("UIStroke", { Color = Config.Outline, Thickness = 2.5 }, em)
		make("UIGradient", { Rotation = 90, Color = ColorSequence.new(Config.Face[1], Config.Face[3]) }, em)
	end
	local gridW, gridH = role == "YOUTUBE" and 0.42 or 1, role == "YOUTUBE" and 0.6 or 1
	for r, row in rows do for c = 1, #row do
		if row:sub(c, c) == "#" then
			local px = make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5 + gridW * ((c - 0.5) / #row - 0.5) + (role == "YOUTUBE" and 0.06 or 0), 0.5 + gridH * ((r - 0.5) / #rows - 0.5)),
				Size = UDim2.fromScale(gridW / #row * 0.96, gridH / #rows * 0.96), BorderSizePixel = 0,
				BackgroundColor3 = role == "YOUTUBE" and Color3.new(1, 1, 1) or (r == 1 and Color3.fromRGB(255, 231, 163) or Color3.fromRGB(255, 59, 59)) }, em)
			if role ~= "YOUTUBE" then make("UIStroke", { Color = Config.Outline, Thickness = 1 }, px) end
		end
	end end
	-- lettering
	local word = make("Frame", { Name = "Word", LayoutOrder = 2, Size = UDim2.fromScale(0.78, 1), BackgroundTransparency = 1 }, root)
	local glow = textLayer(word, "Glow", role, 1, Config.Glow)
	glow.TextTransparency = 1
	local glowStroke = make("UIStroke", { Color = Config.Glow, Thickness = 4, Transparency = 0.7, LineJoinMode = Enum.LineJoinMode.Round }, glow)
	local depth = textLayer(word, "Depth", role, 2, Config.Outline)
	depth.Position = UDim2.new(0, 0, 0.06, 0)
	make("UIStroke", { Color = Config.Outline, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round }, depth)
	local face = textLayer(word, "Face", role, 3)
	make("UIStroke", { Color = Config.Outline, Thickness = 2, LineJoinMode = Enum.LineJoinMode.Round }, face)
	make("UIGradient", { Rotation = 90, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Config.Face[1]), ColorSequenceKeypoint.new(0.42, Config.Face[2]), ColorSequenceKeypoint.new(1, Config.Face[3]) }) }, face)
	local hl = textLayer(word, "Highlight", role, 4)
	make("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.24, 1), NumberSequenceKeypoint.new(0.26, 0.2), NumberSequenceKeypoint.new(0.32, 0.2), NumberSequenceKeypoint.new(0.34, 1), NumberSequenceKeypoint.new(1, 1) }) }, hl)
	-- shine: white text whose gradient is a moving diagonal band, so it's clipped to the letters
	local shine = textLayer(word, "Shine", role, 5)
	local shineGrad = make("UIGradient", { Rotation = 25, Offset = Vector2.new(-1.2, 0), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.44, 1), NumberSequenceKeypoint.new(0.5, 0.05), NumberSequenceKeypoint.new(0.56, 1), NumberSequenceKeypoint.new(1, 1) }) }, shine)
	-- glint (4-point star on the last letter)
	local glint = make("Frame", { Name = "Glint", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.98, 0.08), Size = UDim2.fromScale(0.07, 0.5), BackgroundTransparency = 1, ZIndex = 6 }, word)
	make("UIAspectRatioConstraint", { AspectRatio = 1 }, glint)
	local gs = make("UIScale", { Scale = 0 }, glint)
	for _, sz in { UDim2.new(0.14, 0, 1, 0), UDim2.new(1, 0, 0.14, 0) } do
		make("UICorner", { CornerRadius = UDim.new(1, 0) }, make("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = sz, BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = 6 }, glint))
	end

	-- entrance: rise + spring
	tween(root, 0.55, { Position = UDim2.fromScale(0, 0) }, Enum.EasingStyle.Back)
	tween(pop, 0.55, { Scale = 1 }, Enum.EasingStyle.Back)
	-- breathing glow (one looping tween)
	table.insert(st.tweens, tween(glowStroke, role == "OWNER" and 1.3 or 1.6, { Transparency = role == "OWNER" and 0.35 or 0.5, Thickness = 5 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true))
	-- shine + glint schedule
	local every = Config.ShineEvery[role] or 5
	local alive = true
	task.spawn(function()
		task.wait(0.8 + math.random() * every)
		while alive do
			shineGrad.Offset = Vector2.new(-1.2, 0)
			tween(shineGrad, Config.ShineTime, { Offset = Vector2.new(1.2, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)
			if math.random() < 0.5 then
				task.delay(Config.ShineTime * 0.75, function()
					if not alive then return end
					glint.Rotation = 0
					tween(gs, 0.14, { Scale = 1 }, Enum.EasingStyle.Back); tween(glint, 0.4, { Rotation = 90 })
					task.delay(0.18, function() if alive then tween(gs, 0.2, { Scale = 0 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end end)
				end)
			end
			task.wait(every)
		end
	end)
	st.stop = function() alive = false end
	st.gui, st.word = gui, word
	tags[character] = st
	table.insert(st.conns, character.AncestryChanged:Connect(function(_, parent) if not parent then
		alive = false
		for _, tw in st.tweens do tw:Cancel() end
		for _, c in st.conns do c:Disconnect() end
		if gui.Parent then gui:Destroy() end
		tags[character] = nil
	end end))
end

local function clear(character)
	local st = tags[character]; if not st then return end
	st.stop(); for _, tw in st.tweens do tw:Cancel() end; for _, c in st.conns do c:Disconnect() end
	if st.gui.Parent then st.gui:Destroy() end
	tags[character] = nil
end

local function refresh(player)
	local character = player.Character
	if not character then return end
	clear(character) -- no duplicates
 revisions[character] = (revisions[character] or 0) + 1
 local revision = revisions[character]
	local role = player:GetAttribute("RoleTag")
	if role and (CROWN[role] or role == "YOUTUBE") then task.spawn(build, character, role, revision) end
end

local function watch(player)
	player.CharacterAdded:Connect(function() refresh(player) end)
	player:GetAttributeChangedSignal("RoleTag"):Connect(function() refresh(player) end)
	refresh(player)
end
Players.PlayerAdded:Connect(watch)
for _, p in Players:GetPlayers() do watch(p) end
Players.PlayerRemoving:Connect(function(p) if p.Character then clear(p.Character) end end)

-- Fixed size in studs: tags shrink naturally with camera distance.
