--[[ MutationDropAnnounce — LocalScript (StarterPlayerScripts)
Full-screen "<TIER> / MUTATION DROPPED!" banner when the guaranteed river mutation drops.
Builds its own ScreenGui "MutationDropAnnounce" in PlayerGui at runtime.
Listens to ReplicatedStorage.<CONFIG.EventName> (RemoteEvent fired by MutationDropService).
Payload can be a string ("Gold") or a table ({Mutation = "Gold"} / {Name = "Gold"}).
Owner test: type  /testdrop gold   (or /testdrop  with no name to preview all).
]]

------------------------------------------------------------------ CONFIG
local CONFIG = {
	EventName = "MutationDropped",
	TitleFormat = "%s",
	TagText = "MUTATION DROPPED!",
	ShowBand = false, -- dark band behind the text (off = no background)
	Subtitle = "at the river! Go grab it!",
	TestCommand = "/testdrop",
	Font = Enum.Font.LuckiestGuy, -- try: FredokaOne, Bangers, GothamBlack, Cartoon
	StrokeColor = Color3.fromRGB(29, 20, 32), -- #1D1420
	BandColor = Color3.fromRGB(16, 11, 20),
	BandTransparency = 0.18,
	BandHeight = 190, -- at 1280x720 reference
	TitleMaxTextSize = 120,
	TagMaxTextSize = 44,
	SubMaxTextSize = 26,
	Timing = { -- seconds (~2.5 total)
		BandIn = 0.25,
		Slam = 0.45,
		Shine = 0.55,
		SubtitleAt = 0.65,
		SubtitleFade = 0.25,
		Hold = 1.45, -- time on screen after the slam
		Out = 0.4,
		Gap = 0.2, -- pause between queued announcements
	},
	Mutations = {
		Silver = {
			Label = "SILVER",
			Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(205, 212, 224), Color3.fromRGB(150, 160, 178), Color3.fromRGB(235, 240, 248) },
			Glow = Color3.fromRGB(200, 215, 235),
			SubColor = Color3.fromRGB(225, 232, 242),
			Effect = "Sparkles",
			ParticleColors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(210, 220, 235) },
			GlowPulse = false,
			SoundId = "", -- e.g. "rbxassetid://1234567"
			SoundName = "", -- or the name of an existing Sound anywhere in ReplicatedStorage/SoundService
		},
		Gold = {
			Label = "GOLD",
			Colors = { Color3.fromRGB(255, 240, 160), Color3.fromRGB(255, 211, 107), Color3.fromRGB(226, 150, 30), Color3.fromRGB(255, 226, 120) },
			Glow = Color3.fromRGB(255, 190, 60),
			SubColor = Color3.fromRGB(255, 222, 140),
			Effect = "Coins",
			ParticleColors = { Color3.fromRGB(255, 211, 107), Color3.fromRGB(240, 170, 40) },
			GlowPulse = true,
			SoundId = "",
			SoundName = "",
		},
		Diamond = {
			Label = "DIAMOND",
			Colors = { Color3.fromRGB(230, 255, 255), Color3.fromRGB(120, 225, 255), Color3.fromRGB(50, 160, 235), Color3.fromRGB(180, 245, 255) },
			Glow = Color3.fromRGB(80, 210, 255),
			SubColor = Color3.fromRGB(180, 240, 255),
			Effect = "Shards",
			ParticleColors = { Color3.fromRGB(200, 250, 255), Color3.fromRGB(110, 215, 255), Color3.fromRGB(60, 170, 240) },
			GlowPulse = false,
			SoundId = "",
			SoundName = "",
		},
		Rainbow = {
			Label = "RAINBOW",
			Colors = {
				Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 235, 60),
				Color3.fromRGB(80, 220, 100), Color3.fromRGB(60, 160, 255), Color3.fromRGB(170, 90, 255), Color3.fromRGB(255, 70, 70),
			},
			Glow = Color3.fromRGB(255, 255, 255),
			SubColor = Color3.fromRGB(255, 255, 255),
			Effect = "Rainbow",
			ParticleColors = {
				Color3.fromRGB(255, 70, 70), Color3.fromRGB(255, 160, 40), Color3.fromRGB(255, 235, 60),
				Color3.fromRGB(80, 220, 100), Color3.fromRGB(60, 160, 255), Color3.fromRGB(170, 90, 255),
			},
			GlowPulse = false,
			RainbowSpeed = 160, -- gradient degrees per second
			SoundId = "",
			SoundName = "",
		},
	},
	-- used when the server sends a mutation name that isn't listed above
	Fallback = {
		Colors = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(255, 211, 107) },
		Glow = Color3.fromRGB(232, 69, 44),
		SubColor = Color3.fromRGB(255, 243, 220),
		Effect = "Sparkles",
		ParticleColors = { Color3.fromRGB(255, 211, 107), Color3.fromRGB(255, 255, 255) },
		GlowPulse = false,
		SoundId = "",
		SoundName = "",
	},
}
------------------------------------------------------------------ END CONFIG

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TextChatService = game:GetService("TextChatService")

local player = Players.LocalPlayer
local gui = Instance.new("ScreenGui")
gui.Parent = player:WaitForChild("PlayerGui")
local T = CONFIG.Timing
local REF_W, REF_H = 1280, 720
local rng = Random.new()

gui.Name = "MutationDropAnnounce"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

------------------------------------------------------------------ helpers
local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in pairs(props) do o[k] = v end
	if o:IsA("GuiObject") then o.Active = false; o.Selectable = false end
	o.Parent = parent
	return o
end

local function tween(o, t, props, style, dir, reps, rev)
	local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out, reps or 0, rev or false), props)
	tw:Play()
	return tw
end

local function seq(colors)
	if #colors == 1 then return ColorSequence.new(colors[1]) end
	local kps = {}
	for i, c in ipairs(colors) do kps[i] = ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c) end
	return ColorSequence.new(kps)
end

local function pick(list) return list[rng:NextInteger(1, #list)] end

local function textLabel(name, z, maxSize, parent)
	local l = new("TextLabel", {
		Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Font = CONFIG.Font,
		Text = "", TextScaled = true, TextColor3 = Color3.new(1, 1, 1), ZIndex = z, TextTransparency = 1,
	}, parent)
	new("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = 10 }, l)
	return l
end

------------------------------------------------------------------ UI
local root = new("Frame", { Name = "Root", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Visible = false }, gui)

local band = new("Frame", {
	Name = "Band", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(-1, 0, 0.5, 0), Size = UDim2.new(1, 0, 0, CONFIG.BandHeight),
	BackgroundColor3 = CONFIG.BandColor, BackgroundTransparency = CONFIG.BandTransparency, BorderSizePixel = 0, ZIndex = 1, Visible = CONFIG.ShowBand,
}, root)
local edgeFade = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0), NumberSequenceKeypoint.new(0.75, 0), NumberSequenceKeypoint.new(1, 1),
})
local bandEdge = new("Frame", { Name = "EdgeTop", Position = UDim2.fromScale(0, 0), Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, ZIndex = 1 }, band)
new("UIGradient", { Transparency = edgeFade }, bandEdge)
local bandEdge2 = new("Frame", { Name = "EdgeBottom", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 2), BorderSizePixel = 0, ZIndex = 1 }, band)
new("UIGradient", { Transparency = edgeFade }, bandEdge2)

-- fixed 1280x720 stage, scaled to the screen with UIScale
local stage = new("Frame", { Name = "Stage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(REF_W, REF_H), BackgroundTransparency = 1, ZIndex = 2 }, root)
local stageScale = new("UIScale", {}, stage)

local holderBase = UDim2.new(0.5, 0, 0.5, -26)
local holder = new("Frame", { Name = "TitleHolder", AnchorPoint = Vector2.new(0.5, 0.5), Position = holderBase, Size = UDim2.fromOffset(1180, 130), BackgroundTransparency = 1, ZIndex = 3 }, stage)
local slam = new("UIScale", { Name = "Slam", Scale = 1 }, holder)

-- chunky 3D drop shadow under the title
local shadow = textLabel("Shadow", 2, CONFIG.TitleMaxTextSize, holder)
shadow.Position = UDim2.fromOffset(0, 9)
shadow.TextColor3 = CONFIG.StrokeColor
local shadowStroke = new("UIStroke", { Thickness = 7, Color = CONFIG.StrokeColor, Transparency = 1, LineJoinMode = Enum.LineJoinMode.Round }, shadow)

local glow = textLabel("Glow", 3, CONFIG.TitleMaxTextSize, holder)
local glowStroke = new("UIStroke", { Thickness = 8, Transparency = 1, LineJoinMode = Enum.LineJoinMode.Round }, glow)

local title = textLabel("Title", 4, CONFIG.TitleMaxTextSize, holder)
local titleStroke = new("UIStroke", { Thickness = 7, Color = CONFIG.StrokeColor, Transparency = 1, LineJoinMode = Enum.LineJoinMode.Round }, title)
local titleGrad = new("UIGradient", { Rotation = 90 }, title)

local shine = textLabel("Shine", 5, CONFIG.TitleMaxTextSize, holder)
local shineGrad = new("UIGradient", { Rotation = 18, Offset = Vector2.new(-1.2, 0), Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.44, 1), NumberSequenceKeypoint.new(0.5, 0.2),
	NumberSequenceKeypoint.new(0.56, 1), NumberSequenceKeypoint.new(1, 1),
}) }, shine)

local tag = new("TextLabel", {
	Name = "Tag", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 4), Size = UDim2.fromOffset(760, 46),
	BackgroundTransparency = 1, Font = CONFIG.Font, Text = CONFIG.TagText, TextScaled = true, TextTransparency = 1,
	TextColor3 = Color3.new(1, 1, 1), ZIndex = 4,
}, holder)
new("UITextSizeConstraint", { MaxTextSize = CONFIG.TagMaxTextSize, MinTextSize = 10 }, tag)
local tagStroke = new("UIStroke", { Thickness = 5, Color = CONFIG.StrokeColor, Transparency = 1, LineJoinMode = Enum.LineJoinMode.Round }, tag)

local sub = new("TextLabel", {
	Name = "Subtitle", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 112), Size = UDim2.fromOffset(900, 34),
	BackgroundTransparency = 1, Font = CONFIG.Font, Text = CONFIG.Subtitle, TextScaled = true, TextTransparency = 1, ZIndex = 4,
}, stage)
new("UITextSizeConstraint", { MaxTextSize = CONFIG.SubMaxTextSize, MinTextSize = 10 }, sub)
local subStroke = new("UIStroke", { Thickness = 4, Color = CONFIG.StrokeColor, Transparency = 1 }, sub)

local fx = new("Frame", { Name = "FX", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 6, ClipsDescendants = false }, stage)

local function rescale()
	local cam = workspace.CurrentCamera
	if not cam then return end
	local vp = cam.ViewportSize
	local s = math.clamp(math.min(vp.X / REF_W, vp.Y / REF_H), 0.42, 1.6)
	stageScale.Scale = s
	band.Size = UDim2.new(1, 0, 0, CONFIG.BandHeight * s)
end
rescale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
	rescale()
	if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end
end)
if workspace.CurrentCamera then workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(rescale) end

------------------------------------------------------------------ sounds
local soundCache = {}
local function getSound(cfg)
	local key = (cfg.SoundName or "") .. "|" .. (cfg.SoundId or "")
	if soundCache[key] ~= nil then return soundCache[key] or nil end
	local s
	if cfg.SoundName and cfg.SoundName ~= "" then
		for _, place in ipairs({ ReplicatedStorage, SoundService }) do
			local found = place:FindFirstChild(cfg.SoundName, true)
			if found and found:IsA("Sound") then s = found break end
		end
	end
	if not s and cfg.SoundId and cfg.SoundId ~= "" then
		s = new("Sound", { Name = "AnnounceSound", SoundId = cfg.SoundId, Volume = 0.8 }, gui)
	end
	soundCache[key] = s or false
	return s
end

------------------------------------------------------------------ particles (all shrink to 0 instead of fading, so one tween works for every kind)
local CX, CY = REF_W / 2, REF_H / 2 - 26

local function spawnParticle(kind, cfg)
	local p
	local c = pick(cfg.ParticleColors)
	if kind == "Sparkle" then
		local s = rng:NextInteger(7, 13)
		p = new("Frame", { Size = UDim2.fromOffset(s, s), Rotation = 45, BackgroundColor3 = c, BorderSizePixel = 0 }, fx)
	elseif kind == "Coin" then
		local s = rng:NextInteger(14, 20)
		p = new("Frame", { Size = UDim2.fromOffset(s, s), BackgroundColor3 = c, BorderSizePixel = 0 }, fx)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, p)
		new("UIStroke", { Color = Color3.fromRGB(157, 100, 20), Thickness = 2.5 }, p)
		local dot = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.35, 0.35), Size = UDim2.fromScale(0.3, 0.3), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.25, BorderSizePixel = 0 }, p)
		new("UICorner", { CornerRadius = UDim.new(1, 0) }, dot)
	elseif kind == "Shard" then
		p = new("Frame", { Size = UDim2.fromOffset(rng:NextInteger(4, 7), rng:NextInteger(16, 28)), BackgroundColor3 = c, BorderSizePixel = 0 }, fx)
		new("UIGradient", { Rotation = 90, Color = seq({ Color3.new(1, 1, 1), c }) }, p)
	elseif kind == "Icon" then
		p = new("TextLabel", { Size = UDim2.fromOffset(40, 40), BackgroundTransparency = 1, Text = pick(cfg.SpookyIcons or { "🦇" }), TextSize = rng:NextInteger(26, 40), Font = CONFIG.Font, TextColor3 = c }, fx)
	end
	p.AnchorPoint = Vector2.new(0.5, 0.5)
	p.ZIndex = 6
	return p
end

local function fly(p, from, to, t, rot, style, dir)
	p.Position = UDim2.fromOffset(from.X, from.Y)
	local size = p.Size
	p.Size = UDim2.fromOffset(0, 0)
	tween(p, math.min(0.12, t * 0.2), { Size = size }, Enum.EasingStyle.Back)
	tween(p, t, { Position = UDim2.fromOffset(to.X, to.Y), Rotation = p.Rotation + (rot or 0) }, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out)
	task.delay(t * 0.6, function()
		if p.Parent then tween(p, t * 0.4, { Size = UDim2.fromOffset(0, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In) end
	end)
	task.delay(t + 0.05, function() p:Destroy() end)
end

local EFFECTS = {}
EFFECTS.Sparkles = {
	burst = function(cfg)
		for _ = 1, 6 do
			local from = Vector2.new(CX + rng:NextNumber(-520, 520), CY + rng:NextNumber(-55, 55))
			fly(spawnParticle("Sparkle", cfg), from, from + Vector2.new(rng:NextNumber(-30, 30), rng:NextNumber(-40, 10)), rng:NextNumber(0.5, 0.9), 90)
		end
	end,
	rate = 4,
	tick = function(cfg)
		local from = Vector2.new(CX + rng:NextNumber(-540, 540), CY + rng:NextNumber(-60, 60))
		fly(spawnParticle("Sparkle", cfg), from, from + Vector2.new(0, -rng:NextNumber(10, 40)), rng:NextNumber(0.45, 0.8), 90)
	end,
}
EFFECTS.Coins = {
	burst = function(cfg)
		for _ = 1, 8 do
			local from = Vector2.new(CX + rng:NextNumber(-260, 260), CY)
			local to = Vector2.new(from.X + rng:NextNumber(-260, 260), CY - rng:NextNumber(110, 190))
			fly(spawnParticle("Coin", cfg), from, to, rng:NextNumber(0.5, 0.75), rng:NextNumber(-180, 180), Enum.EasingStyle.Quint)
		end
	end,
	rate = 3,
	tick = function(cfg)
		local x = CX + rng:NextNumber(-560, 560)
		fly(spawnParticle("Coin", cfg), Vector2.new(x, CY - 150), Vector2.new(x + rng:NextNumber(-30, 30), CY + 170), rng:NextNumber(0.8, 1.1), rng:NextNumber(-90, 90), Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	end,
}
EFFECTS.Shards = {
	burst = function(cfg)
		for i = 1, 14 do
			local a = (i / 14) * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
			local d = rng:NextNumber(200, 420)
			local p = spawnParticle("Shard", cfg)
			p.Rotation = math.deg(a) + 90
			fly(p, Vector2.new(CX, CY), Vector2.new(CX + math.cos(a) * d * 1.4, CY + math.sin(a) * d * 0.55), rng:NextNumber(0.5, 0.8), rng:NextNumber(-60, 60), Enum.EasingStyle.Quint)
		end
	end,
	rate = 3,
	tick = function(cfg)
		local from = Vector2.new(CX + rng:NextNumber(-520, 520), CY + rng:NextNumber(-50, 50))
		local p = spawnParticle("Shard", cfg)
		p.Rotation = rng:NextNumber(0, 360)
		fly(p, from, from + Vector2.new(rng:NextNumber(-40, 40), rng:NextNumber(-60, 60)), rng:NextNumber(0.5, 0.8), 120)
	end,
}
EFFECTS.Rainbow = {
	burst = function(cfg) EFFECTS.Sparkles.burst(cfg) end,
	rate = 10,
	trailX = 0,
	tick = function(cfg, elapsed)
		-- trail follows a point sweeping across the text
		local k = (elapsed * 0.9) % 1
		local x = CX - 560 + k * 1120
		local from = Vector2.new(x, CY + math.sin(elapsed * 9) * 38)
		fly(spawnParticle("Sparkle", cfg), from, from + Vector2.new(-rng:NextNumber(40, 90), rng:NextNumber(-25, 25)), rng:NextNumber(0.4, 0.65), 90)
	end,
}
EFFECTS.Spooky = {
	burst = function(cfg)
		for _ = 1, 8 do
			local from = Vector2.new(CX + rng:NextNumber(-420, 420), CY + rng:NextNumber(-20, 30))
			fly(spawnParticle("Icon", cfg), from, from + Vector2.new(rng:NextNumber(-120, 120), -rng:NextNumber(140, 230)), rng:NextNumber(0.9, 1.3), rng:NextNumber(-30, 30))
		end
	end,
	rate = 6,
	tick = function(cfg)
		local from = Vector2.new(CX + rng:NextNumber(-560, 560), CY + rng:NextNumber(0, 60))
		fly(spawnParticle("Icon", cfg), from, from + Vector2.new(rng:NextNumber(-90, 90), -rng:NextNumber(150, 240)), rng:NextNumber(1, 1.4), rng:NextNumber(-25, 25), Enum.EasingStyle.Sine)
	end,
}

------------------------------------------------------------------ resolve mutation
local function resolve(payload)
	local name = payload
	if typeof(payload) == "table" then name = payload.Mutation or payload.MutationName or payload.Name or payload.mutation end
	name = tostring(name or "")
	for key, cfg in pairs(CONFIG.Mutations) do
		if string.lower(key) == string.lower(name) then return cfg, cfg.Label or string.upper(key) end
	end
	return CONFIG.Fallback, string.upper(name)
end

local function setTitleAlpha(a, t)
	local props = { TextTransparency = a }
	if t and t > 0 then
		tween(title, t, props); tween(titleStroke, t, { Transparency = a })
		tween(glow, t, props)
		tween(shine, t, props)
		tween(shadow, t, props); tween(shadowStroke, t, { Transparency = a })
		tween(tag, t, props); tween(tagStroke, t, { Transparency = a })
	else
		title.TextTransparency = a; titleStroke.Transparency = a; glow.TextTransparency = a; shine.TextTransparency = a
		shadow.TextTransparency = a; shadowStroke.Transparency = a; tag.TextTransparency = a; tagStroke.Transparency = a
	end
end

------------------------------------------------------------------ play one
local function play(payload)
	local cfg, label = resolve(payload)
	local text = string.format(CONFIG.TitleFormat, label)
	title.Text, glow.Text, shine.Text, shadow.Text = text, text, text, text
	tag.Text = CONFIG.TagText
	titleGrad.Color = seq(cfg.Colors)
	titleGrad.Rotation = cfg.Effect == "Rainbow" and 0 or 90
	titleGrad.Offset = Vector2.zero
	glow.TextColor3 = cfg.Glow
	glowStroke.Color = cfg.Glow
	glowStroke.Transparency = 1
	sub.TextColor3 = cfg.SubColor
	bandEdge.BackgroundColor3 = cfg.Glow
	bandEdge2.BackgroundColor3 = cfg.Glow
	shineGrad.Offset = Vector2.new(-1.2, 0)

	band.Position = UDim2.new(-1, 0, 0.5, 0)
	band.BackgroundTransparency = CONFIG.BandTransparency
	holder.Position = holderBase
	holder.Rotation = 0
	sub.Position = UDim2.new(0.5, 0, 0.5, 126)
	sub.TextTransparency, subStroke.Transparency = 1, 1
	setTitleAlpha(1)
	root.Visible = true

	-- 1. band slides in
	tween(band, T.BandIn, { Position = UDim2.new(0, 0, 0.5, 0) }, Enum.EasingStyle.Quart)
	task.wait(T.BandIn * 0.7)

	-- 2. slam
	slam.Scale = 3
	setTitleAlpha(0, 0.1)
	tween(slam, T.Slam, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	local snd = getSound(cfg)
	if snd then SoundService:PlayLocalSound(snd) end

	local start = os.clock()
	local effect = EFFECTS[cfg.Effect] or EFFECTS.Sparkles
	local running = true
	local pulse

	task.delay(T.Slam * 0.55, function()
		-- GUI shake (no camera)
		local t0 = os.clock()
		while os.clock() - t0 < 0.25 do
			local k = 1 - (os.clock() - t0) / 0.25
			holder.Position = holderBase + UDim2.fromOffset(rng:NextNumber(-9, 9) * k, rng:NextNumber(-6, 6) * k)
			RunService.Heartbeat:Wait()
		end
		holder.Position = holderBase
		-- glow + effect burst
		glowStroke.Transparency = 0.5
		if cfg.GlowPulse then
			pulse = tween(glowStroke, 0.35, { Transparency = 0.15 }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
		else
			tween(glowStroke, 0.4, { Transparency = 0.6 })
		end
		effect.burst(cfg)
		-- 3. shine sweep
		tween(shineGrad, T.Shine, { Offset = Vector2.new(1.2, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end)

	-- continuous effect + rainbow rotation + halloween wobble
	task.spawn(function()
		local acc = 0
		task.wait(T.Slam * 0.6)
		while running do
			local dt = RunService.Heartbeat:Wait()
			local el = os.clock() - start
			acc += dt
			local step = 1 / effect.rate
			while acc >= step and running do acc -= step; effect.tick(cfg, el) end
			if cfg.Effect == "Rainbow" then
				titleGrad.Rotation = (titleGrad.Rotation + dt * (cfg.RainbowSpeed or 160)) % 360
			end
			if cfg.Wobble then holder.Rotation = math.sin(el * 7) * cfg.Wobble end
		end
	end)

	-- 4. subtitle
	task.delay(T.SubtitleAt, function()
		tween(sub, T.SubtitleFade, { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 112) })
		tween(subStroke, T.SubtitleFade, { Transparency = 0 })
	end)

	task.wait(T.Slam + T.Hold)

	-- 5. out
	running = false
	if pulse then pulse:Cancel() end
	tween(band, T.Out, { Position = UDim2.new(1, 0, 0.5, 0), BackgroundTransparency = 1 }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	tween(holder, T.Out, { Position = holderBase + UDim2.fromOffset(260, 0) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	tween(sub, T.Out, { TextTransparency = 1, Position = UDim2.new(0.5, 180, 0.5, 112) }, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	tween(subStroke, T.Out, { Transparency = 1 })
	tween(glowStroke, T.Out, { Transparency = 1 })
	setTitleAlpha(1, T.Out)
	task.wait(T.Out)
	holder.Rotation = 0
	root.Visible = false
end

------------------------------------------------------------------ queue
local queue, busy = {}, false
local function announce(payload)
	table.insert(queue, payload)
	if busy then return end
	busy = true
	task.spawn(function()
		while #queue > 0 do
			local nextPayload = table.remove(queue, 1)
			local ok, err = pcall(play, nextPayload)
			if not ok then warn("[MutationDropAnnounce] ", err); root.Visible = false end
			task.wait(T.Gap)
		end
		busy = false
	end)
end

task.spawn(function()
	local ev = ReplicatedStorage:WaitForChild(CONFIG.EventName)
	ev.OnClientEvent:Connect(function(payload) announce(payload) end)
end)

------------------------------------------------------------------ owner test: /testdrop <mutation>
local function isOwner()
	if RunService:IsStudio() then return true end
	if game.CreatorType == Enum.CreatorType.User then return player.UserId == game.CreatorId end
	local ok, rank = pcall(function() return player:GetRankInGroup(game.CreatorId) end)
	return ok and rank == 255
end

local function runTest(arg)
	arg = arg and arg:match("^%s*(.-)%s*$") or ""
	if arg == "" or arg:lower() == "all" then
		for _, key in ipairs({ "Silver", "Gold", "Diamond", "Rainbow" }) do announce(key) end
	else
		announce(arg)
	end
end

task.spawn(function()
	if not isOwner() then return end
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local cmd = Instance.new("TextChatCommand")
		cmd.Name = "TestDropCommand"
		cmd.PrimaryAlias = CONFIG.TestCommand
		cmd.Parent = TextChatService
		cmd.Triggered:Connect(function(source, text)
			if source.UserId ~= player.UserId then return end
			runTest(text:sub(#CONFIG.TestCommand + 1))
		end)
	else
		player.Chatted:Connect(function(msg)
			if msg:lower():sub(1, #CONFIG.TestCommand) == CONFIG.TestCommand then runTest(msg:sub(#CONFIG.TestCommand + 1)) end
		end)
	end
end)
