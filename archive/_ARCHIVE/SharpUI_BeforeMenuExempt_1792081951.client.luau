-- SharpUI: house style = sharp corners + solid black outlines on all game menus.
-- Strips UICorner, forces UIStroke black/mitred, removes thin white highlight lines. Image art (torii, side buttons) is left alone.
local Players = game:GetService("Players")
local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
local TARGETS = { GameMenus = true, GameHUD = true, NightBar = true, MusicSettingsUI = true, JoinArrivalUI = true }
local KEEP_ROUND = { ImageLabel = true, ImageButton = true } -- corners on pictures stay (they're clipping masks)
local BLACK = Color3.new(0, 0, 0)

local function fix(d)
	if d:IsA("UICorner") then
		local p = d.Parent
		if p and KEEP_ROUND[p.ClassName] and p.Image ~= "" then return end
		d.CornerRadius = UDim.new(0, 0)
	elseif d:IsA("UIStroke") then
		d.Color = BLACK
		d.LineJoinMode = Enum.LineJoinMode.Miter
		if d.ApplyStrokeMode == Enum.ApplyStrokeMode.Border and d.Thickness < 2.5 then d.Thickness = 2.5 end
		d.Transparency = math.min(d.Transparency, 0)
	elseif d:IsA("Frame") then
		local c = d.BackgroundColor3
		if c.R > 0.95 and c.G > 0.95 and c.B > 0.95 and d.BackgroundTransparency > 0.3 and d.BackgroundTransparency < 0.97 then
			task.defer(function() if d.Parent and d.AbsoluteSize.Y <= 8 then d.Visible = false end end)
		end
		if d.Name == "Gloss" or d.Name == "Stripes" then d.Visible = false end
	end
end
local function watch(gui)
	for _, d in gui:GetDescendants() do fix(d) end
	gui.DescendantAdded:Connect(fix)
end
for _, g in pg:GetChildren() do if TARGETS[g.Name] then watch(g) end end
pg.ChildAdded:Connect(function(g) if TARGETS[g.Name] then watch(g) end end)

-- slot unlock labels above temple slots
-- outlines scale with the sign (it's sized in studs), so they thin out with distance instead of staying chunky
local slotStrokes = {} -- UIStroke -> { card, base thickness }
local function trackStroke(d, b)
	if d:IsA("UIStroke") and b:FindFirstChild("Card") then slotStrokes[d] = { b.Card, d.Thickness } end
end
-- signs grow in when you come within range and shrink out when you leave (instead of popping)
local SHOW_DIST = 45
local TS = game:GetService("TweenService")
local pops = {} -- billboard -> { card, scale, shown }
local function addPop(b)
	local card = b:WaitForChild("Card", 5); if not card then return end
	card.AnchorPoint = Vector2.new(0.5, 0.5); card.Position = UDim2.fromScale(0.5, 0.5)
	local sc = card:FindFirstChild("Pop") or Instance.new("UIScale"); sc.Name = "Pop"; sc.Scale = 0.01; sc.Parent = card
	card.Visible = false -- hidden while shrunk (outlines would otherwise leave a dot)
	b.MaxDistance = 0 -- distance handled below
	pops[b] = { card = card, scale = sc, shown = false }
end
local function sharpBillboard(b) if b:IsA("BillboardGui") and b.Name == "SlotUnlockLabel" then
	for _, d in b:GetDescendants() do fix(d); trackStroke(d, b) end
	b.DescendantAdded:Connect(function(d) fix(d); trackStroke(d, b) end)
	task.spawn(addPop, b)
end end
game:GetService("RunService").RenderStepped:Connect(function()
	local cam = workspace.CurrentCamera
	for b, p in pops do
		if not b.Parent then pops[b] = nil else
			local a = b.Parent
			local want = b.Enabled and a:IsA("BasePart") and cam and (a.Position - cam.CFrame.Position).Magnitude < SHOW_DIST
			if want ~= p.shown then
				p.shown = want
				if p.tw then p.tw:Cancel() end
				p.tw = want and TS:Create(p.scale, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Scale = 1 })
					or TS:Create(p.scale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.01 })
				if want then p.card.Visible = true
				else local tw = p.tw; tw.Completed:Once(function(state) if state == Enum.PlaybackState.Completed and not p.shown then p.card.Visible = false end end) end
				p.tw:Play()
			end
		end
	end
	for s, t in slotStrokes do
		if not s.Parent then slotStrokes[s] = nil
		else local h = t[1].AbsoluteSize.Y; s.Thickness = h > 0 and math.clamp(t[2] * h / 74, 0.5, t[2]) or t[2] end
	end
end)
for _, d in workspace:GetDescendants() do sharpBillboard(d) end
workspace.DescendantAdded:Connect(sharpBillboard)
