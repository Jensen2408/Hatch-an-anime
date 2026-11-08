--[[ TutorialSpotlight (LocalScript, StarterPlayerScripts) - 2026-11-08
Darkens the whole screen during the first-hatch tutorial and cuts a lit "hole" around the thing to use next,
like the tutorials in other simulators: the egg / incubator / podium / cash plate in the world, the hotbar when you
still have to equip the egg or character, and the glowing button during the Plot -> Upgrades tour.
It only READS the tutorial (FirstHatchTutorial): its gui (Enabled, attribute Step), the world highlight
workspace.TutorialGroundTrail.TutorialObjective (Adornee = the goal) and UpgradeTour.Focus (the tour's ring).
Nothing here changes progress. Delete this script to turn the spotlight off; change DARK to make it lighter/darker.
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local GuiService = game:GetService("GuiService")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local DARK = 0.18 -- transparency of the dark layer (0 = pitch black, 1 = off)
local PAD = 26 -- pixels of light around the goal
local MIN_HOLE = 190 -- the lit hole is never smaller than this
local GOLD, BLACK = Color3.fromHex("FFC21F"), Color3.new(0, 0, 0)

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialSpotlight"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ScreenInsets = Enum.ScreenInsets.None
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 54
gui.Enabled = false
gui.Parent = playerGui

local layer = Instance.new("Frame")
layer.Name = "Mask"
layer.BackgroundTransparency = 1
layer.Size = UDim2.fromScale(1, 1)
layer.Parent = gui

-- the dark pieces around the holes (a pool, reused every frame)
local pool, used = {}, 0
local fade = 1 -- 1 = hidden, 0 = fully dark; eased every frame
local function piece(x0, y0, x1, y1)
	if x1 - x0 < 1 or y1 - y0 < 1 then
		return
	end
	used += 1
	local f = pool[used]
	if not f then
		f = Instance.new("Frame")
		f.Name = "Dark"
		f.BorderSizePixel = 0
		f.BackgroundColor3 = BLACK
		f.Active = false
		f.Parent = layer
		pool[used] = f
	end
	f.Visible = true
	f.Position = UDim2.fromOffset(x0, y0)
	f.Size = UDim2.fromOffset(x1 - x0, y1 - y0)
	f.BackgroundTransparency = DARK + (1 - DARK) * fade
end

-- ring round the world goal: black outside, gold inside, breathing (the tour has its own ring)
local ring = Instance.new("Frame")
ring.Name = "Ring"
ring.BackgroundTransparency = 1
ring.Visible = false
ring.ZIndex = 5
ring.Parent = gui
local ringBlack = Instance.new("UIStroke")
ringBlack.Thickness = 8
ringBlack.Color = BLACK
ringBlack.Parent = ring
local ringInner = Instance.new("Frame")
ringInner.BackgroundTransparency = 1
ringInner.Size = UDim2.fromScale(1, 1)
ringInner.ZIndex = 6
ringInner.Parent = ring
local ringGold = Instance.new("UIStroke")
ringGold.Thickness = 4
ringGold.Color = GOLD
ringGold.Parent = ringInner

-- the goal glows through walls while the spotlight is on
local glow = Instance.new("Highlight")
glow.Name = "TutorialSpotlightGlow"
glow.FillColor = GOLD
glow.FillTransparency = 0.75
glow.OutlineColor = Color3.new(1, 1, 1)
glow.OutlineTransparency = 0
glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
glow.Enabled = false
glow.Parent = gui

local function rectOf(guiObject)
	local p = guiObject.AbsolutePosition
	-- objects in guis that respect the top bar are measured below it; ours ignores it
	local sg = guiObject:FindFirstAncestorWhichIsA("ScreenGui")
	if sg and not sg.IgnoreGuiInset then
		p += GuiService:GetGuiInset()
	end
	return { p.X, p.Y, p.X + guiObject.AbsoluteSize.X, p.Y + guiObject.AbsoluteSize.Y }
end
local function shown(o)
	if not o or not o:IsA("GuiObject") or o.AbsoluteSize.X <= 0 then
		return false
	end
	local a = o
	while a and a ~= playerGui do
		if a:IsA("GuiObject") and not a.Visible then
			return false
		end
		if a:IsA("ScreenGui") and not a.Enabled then
			return false
		end
		a = a.Parent
	end
	return a == playerGui
end
-- the thing to light: an invisible anchor lights its (egg / chamber) model instead, if that model is small
local function lightTarget(part)
	local model = part.Parent
	if part.Transparency >= 0.95 and model and model:IsA("Model") then
		local _, size = model:GetBoundingBox()
		if size.Magnitude < 40 then
			return model
		end
	end
	return part
end
-- the goal's box on screen, or nil when it is behind the camera / off screen
local function screenBox(target)
	local camera = workspace.CurrentCamera
	local cf, size
	if target:IsA("Model") then
		cf, size = target:GetBoundingBox()
	else
		cf, size = target.CFrame, target.Size
	end
	size = size:Max(Vector3.new(3, 3, 3))
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for _, sx in { -0.5, 0.5 } do
		for _, sy in { -0.5, 0.5 } do
			for _, sz in { -0.5, 0.5 } do
				local v = camera:WorldToViewportPoint(cf:PointToWorldSpace(size * Vector3.new(sx, sy, sz)))
				if v.Z <= 0 then
					return nil
				end
				x0, y0, x1, y1 = math.min(x0, v.X), math.min(y0, v.Y), math.max(x1, v.X), math.max(y1, v.Y)
			end
		end
	end
	local view = camera.ViewportSize
	if x1 < 0 or y1 < 0 or x0 > view.X or y0 > view.Y then
		return nil
	end
	-- room above for the Collect / Hatch card that pops over the goal, and a minimum size
	y0 -= (y1 - y0) * 0.6 + 30
	local cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
	local w, h = math.max(x1 - x0 + PAD * 2, MIN_HOLE), math.max(y1 - y0 + PAD * 2, MIN_HOLE)
	return { cx - w / 2, cy - h / 2, cx + w / 2, cy + h / 2 }
end
local function holdingTool()
	return player.Character and player.Character:FindFirstChildOfClass("Tool") ~= nil
end

local t = 0
RunService.RenderStepped:Connect(function(dt)
	t += dt
	local holes, main, active = {}, nil, false
	local tut = playerGui:FindFirstChild("FirstHatchTutorial")
	local step = tut and tut.Enabled and tut:GetAttribute("Step")
	local target
	if step and step >= 9 then
		-- Plot -> Upgrades tour: light the tour's glowing button. With a menu open the dark goes under the menu,
		-- so the menu stays bright; with no menu open it goes over the side buttons, leaving only Plot lit.
		local tour = tut:FindFirstChild("UpgradeTour")
		local focus = tour and tour:FindFirstChild("Focus")
		if shown(focus) then
			active = true
			table.insert(holes, rectOf(focus))
			local menus = playerGui:FindFirstChild("GameMenus")
			local dim = menus and menus:FindFirstChild("Dim")
			local menuOpen = dim and shown(dim)
			gui.DisplayOrder = menus and (menus.DisplayOrder + (menuOpen and -1 or 1)) or 54
		end
	elseif step and step ~= 4 then -- step 4 is "wait while it incubates": you are free to walk about
		local trail = workspace:FindFirstChild("TutorialGroundTrail")
		local hl = trail and trail:FindFirstChild("TutorialObjective")
		local card = tut:FindFirstChild("GuideCard")
		if hl and hl.Enabled and hl.Adornee and hl.Adornee:IsA("BasePart") and card and card.Visible then
			active = true
			gui.DisplayOrder = 54 -- under the tutorial card (55), over the rest of the HUD
			target = lightTarget(hl.Adornee)
			main = screenBox(target)
			if main then
				table.insert(holes, main)
			end
			-- equip steps: the hotbar stays lit until something is in your hand
			if (step == 3 or step == 7) and not holdingTool() then
				local hud = playerGui:FindFirstChild("GameHUD")
				local bar = hud and hud:FindFirstChild("Hotbar", true)
				if shown(bar) then
					local r = rectOf(bar)
					table.insert(holes, { r[1] - 10, r[2] - 10, r[3] + 10, r[4] + 10 })
				end
			end
		end
	end
	-- ease in / out
	local goal = active and 0 or 1
	fade += (goal - fade) * math.min(1, dt * 8)
	if not active and fade > 0.98 then
		gui.Enabled = false
		glow.Enabled = false
		glow.Adornee = nil
		return
	end
	gui.Enabled = true
	if active then
		glow.Adornee = target
		glow.Enabled = target ~= nil
	end
	-- cut the screen into bands at every hole edge, and fill each band except where a hole covers it
	local view = gui.AbsoluteSize
	local W, H = view.X, view.Y
	local ys = { 0, H }
	for _, h in holes do
		h[1], h[3] = math.clamp(math.floor(h[1]), 0, W), math.clamp(math.ceil(h[3]), 0, W)
		h[2], h[4] = math.clamp(math.floor(h[2]), 0, H), math.clamp(math.ceil(h[4]), 0, H)
		table.insert(ys, h[2])
		table.insert(ys, h[4])
	end
	table.sort(ys)
	used = 0
	for i = 1, #ys - 1 do
		local ya, yb = ys[i], ys[i + 1]
		if yb > ya then
			local spans = {}
			for _, h in holes do
				if h[2] <= ya and h[4] >= yb and h[3] > h[1] then
					table.insert(spans, { h[1], h[3] })
				end
			end
			table.sort(spans, function(a, b)
				return a[1] < b[1]
			end)
			local x = 0
			for _, s in spans do
				if s[1] > x then
					piece(x, ya, s[1], yb)
				end
				x = math.max(x, s[2])
			end
			piece(x, ya, W, yb)
		end
	end
	for i = used + 1, #pool do
		pool[i].Visible = false
	end
	-- the ring round the world goal
	ring.Visible = main ~= nil and active
	if ring.Visible then
		ring.Position = UDim2.fromOffset(main[1], main[2])
		ring.Size = UDim2.fromOffset(main[3] - main[1], main[4] - main[2])
		ringGold.Transparency = GuiService.ReducedMotionEnabled and 0 or 0.3 * (0.5 + 0.5 * math.sin(t * 4))
	end
end)
