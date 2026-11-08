--[[ StarterPlayerScripts.StudWorldSkin (LocalScript)
Folk Stud look for the world signs that other scripts build (many of them server-side, per plot).
Restyles them on this client only, as they appear; never touches text, logic or visibility.

  SlotUnlockLabel      temple slot signs (TempleSlotUnlocks + SharpUI pop/stroke scaling, kept)
  MoneyStand "Screen"  SurfaceGui on each slot's money stand (MoneyStandClient)
  CycleTimer           incubator status line (HatchGoo), now on a candy pill that turns green when ready
  IncubationCountdown  incubator countdown (HatchGoo)
  ChampionPlaque/Tag   leaderboard podium plaque + head tag (LeaderboardView)
  Placeholder          leaderboard screen before it loads
  Bubble               owner bubble over the plot (headshot)
  OwnerBanner          role tag over a head (RoleTagClient)

Everything gets NoSkin so SharpUI leaves corners alone (SharpUI still scales the slot sign strokes).
]]
local CollectionService = game:GetService("CollectionService")
local _ = CollectionService

local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end
local INK = rgb(36, 29, 53)
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy) -- Gotham Black, picked 2026-11-07
local STUD = "rbxassetid://3014551673"
local LOCK = "rbxassetid://104989619138958"
local C = {
	azure = { rgb(53, 168, 255), rgb(27, 107, 245) },
	leaf = { rgb(140, 245, 106), rgb(60, 203, 58) },
	mango = { rgb(255, 196, 61), rgb(255, 143, 31) },
	gold = { rgb(252, 197, 5), rgb(249, 144, 1) },
	coral = { rgb(255, 90, 110), rgb(240, 40, 74) },
	grey = { rgb(190, 186, 204), rgb(140, 134, 160) },
}

---------------------------------------------------------------- helpers
local function child(parent, className, name)
	local found = parent:FindFirstChild(name)
	if found and found:IsA(className) then
		return found
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = parent
	return made
end
-- the Border outline of a frame (reuses an existing Border UIStroke)
local function ink(target, thickness)
	local stroke
	for _, s in target:GetChildren() do
		if s:IsA("UIStroke") and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Border then
			stroke = s
		end
	end
	stroke = stroke or Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = BLACK
	stroke.Thickness = thickness
	stroke.Transparency = 0
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = target
	return stroke
end
-- the text outline of a label (reuses an existing Contextual UIStroke)
local function textInk(label, thickness)
	local stroke
	for _, s in label:GetChildren() do
		if s:IsA("UIStroke") and s.ApplyStrokeMode == Enum.ApplyStrokeMode.Contextual then
			stroke = s
		end
	end
	stroke = stroke or Instance.new("UIStroke")
	stroke.Color = BLACK
	stroke.Thickness = thickness
	stroke.Transparency = 0
	stroke.LineJoinMode = Enum.LineJoinMode.Bevel
	stroke.Parent = label
	label.TextStrokeTransparency = 1
	label.FontFace = FONT
	return stroke
end
local function round(target, scaleOrPx, isScale)
	local corner = target:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = isScale and UDim.new(scaleOrPx, 0) or UDim.new(0, scaleOrPx)
	corner.Parent = target
	return corner
end
local function grad(target, pair)
	local g = target:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new(pair[1], pair[2])
	g.Transparency = NumberSequence.new(0)
	g.Offset = Vector2.zero
	g.Parent = target
	return g
end
local function studs(target, transparency, tile)
	local layer = child(target, "ImageLabel", "Studs")
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.Image = STUD
	layer.ScaleType = Enum.ScaleType.Tile
	layer.TileSize = tile
	layer.ImageTransparency = transparency
	layer.ZIndex = target.ZIndex
	layer.Active = false
	return layer
end
local function noSkin(root)
	root:SetAttribute("NoSkin", true)
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			d:SetAttribute("NoSkin", true)
		end
	end
end

---------------------------------------------------------------- slot signs
local function skinSlot(bb)
	local card = bb:WaitForChild("Card", 5)
	if not card then
		return
	end
	local title, price, locked = card:WaitForChild("Title", 5), card:WaitForChild("Price", 5), card:WaitForChild("Locked", 5)
	if not (title and price and locked) then
		return
	end
	local amount = price:FindFirstChild("Amount")
	noSkin(card)
	card.BackgroundColor3, card.BackgroundTransparency = WHITE, 0
	round(card, 0.22, true)
	ink(card, 2.5)
	studs(card, 0.8, UDim2.fromScale(0.16, 0.37))
	textInk(title, 2)
	round(price, 0.5, true)
	ink(price, 2.5)
	if amount then
		amount.TextColor3 = WHITE
		textInk(amount, 2)
	end
	textInk(locked, 1.6)
	locked.TextColor3 = rgb(142, 136, 168)
	-- the lock emoji becomes the FOLK lock icon in front of the words; the padding keeps room for it
	-- (children sit inside the padded box, so the icon still lines up with the centred text)
	local pad = child(locked, "UIPadding", "IconRoom")
	pad.PaddingLeft = UDim.new(0.17, 0)
	local icon = child(locked, "ImageLabel", "LockIcon")
	icon.BackgroundTransparency = 1
	icon.Image = LOCK
	icon.AnchorPoint = Vector2.new(1, 0.5)
	icon.SizeConstraint = Enum.SizeConstraint.RelativeYY
	icon.Size = UDim2.fromScale(1, 1)
	icon:SetAttribute("NoSkin", true)
	local function place()
		local words = locked.Text:gsub("^%s*🔒%s*", "")
		if words ~= locked.Text then
			locked.Text = words
		end
		local w = locked.TextBounds.X
		icon.Position = UDim2.new(0.5, -w / 2 - 3, 0.5, 0)
	end
	locked:GetPropertyChangedSignal("Text"):Connect(place)
	locked:GetPropertyChangedSignal("TextBounds"):Connect(place)
	place()
	-- next slot to buy: blue title + green price; locked: grey
	local function state()
		local buyable = price.Visible
		title.TextColor3 = buyable and C.azure[1] or rgb(170, 165, 190)
		grad(price, buyable and C.leaf or C.grey)
		price.BackgroundColor3 = WHITE
	end
	price:GetPropertyChangedSignal("Visible"):Connect(state)
	state()
end

---------------------------------------------------------------- money stand screens
local function skinMoney(screen)
	local frame = screen:WaitForChild("Frame", 5)
	if not frame then
		return
	end
	noSkin(frame)
	frame.BackgroundColor3, frame.BackgroundTransparency = WHITE, 0
	round(frame, 0.12, true)
	ink(frame, 8)
	studs(frame, 0.82, UDim2.fromScale(0.25, 0.25))
	local amount, status = frame:FindFirstChild("Amount"), frame:FindFirstChild("Status")
	if amount then
		textInk(amount, 6)
		-- MoneyStandClient flips the amount between a dim brown (empty) and cream (has money):
		-- show those as grey and burning green instead
		local DIM, MONEY = rgb(170, 165, 190), C.leaf[2]
		local function recolour()
			local c = amount.TextColor3
			if c ~= DIM and c ~= MONEY then
				amount.TextColor3 = (c.R + c.G + c.B) / 3 < 0.7 and DIM or MONEY
			end
		end
		amount:GetPropertyChangedSignal("TextColor3"):Connect(recolour)
		recolour()
	end
	if status then
		status.TextColor3 = C.mango[1]
		textInk(status, 4)
	end
end

---------------------------------------------------------------- incubator status + countdown
local function pillBehind(label, bb)
	local pill = child(bb, "Frame", "StudPill")
	pill.AnchorPoint = Vector2.new(0.5, 0.5)
	pill.Position = UDim2.fromScale(0.5, 0.5)
	pill.BackgroundColor3 = WHITE
	pill.ZIndex = 0
	round(pill, 0.5, true)
	ink(pill, 3)
	studs(pill, 0.78, UDim2.fromOffset(24, 24))
	label.ZIndex = math.max(label.ZIndex, 2)
	local function fit()
		local b = label.TextBounds
		pill.Visible = label.Text ~= "" and b.X > 0
		pill.Size = UDim2.fromOffset(b.X + b.Y * 1.3, b.Y * 1.45)
		local ready = label.Text:find("READY") and not label.Text:find("HOLD") and not label.Text:find("EQUIP")
		grad(pill, ready and C.leaf or C.azure)
	end
	label:GetPropertyChangedSignal("Text"):Connect(fit)
	label:GetPropertyChangedSignal("TextBounds"):Connect(fit)
	fit()
	return pill
end
local function skinCycle(bb)
	local label = bb:WaitForChild("Status", 5)
	if not label then
		return
	end
	noSkin(bb)
	label.TextColor3 = WHITE
	label.TextScaled = false
	label.TextSize = 17
	textInk(label, 2.6)
	pillBehind(label, bb)
end
local function skinCountdown(bb)
	local label = bb:FindFirstChildOfClass("TextLabel") or bb:WaitForChild("TextLabel", 5)
	if not label then
		return
	end
	noSkin(bb)
	label.BackgroundColor3, label.BackgroundTransparency = WHITE, 0
	round(label, 0.5, true)
	ink(label, 3)
	studs(label, 0.78, UDim2.fromOffset(24, 24))
	label.TextColor3 = WHITE
	local pad = child(label, "UIPadding", "Pad")
	pad.PaddingTop, pad.PaddingBottom = UDim.new(0.14, 0), UDim.new(0.14, 0)
	pad.PaddingLeft, pad.PaddingRight = UDim.new(0.06, 0), UDim.new(0.06, 0)
	textInk(label, 2.6)
	local function state()
		grad(label, label.Text:find("READY") and C.leaf or C.azure)
	end
	label:GetPropertyChangedSignal("Text"):Connect(state)
	state()
end

---------------------------------------------------------------- leaderboard
local PODIUM = { C.gold, C.azure, C.coral }
local function skinPlaque(surface)
	local frame = surface:WaitForChild("Frame", 5)
	if not frame then
		return
	end
	noSkin(frame)
	local podium = tonumber((surface:GetFullName():match("Podium(%d)"))) or 1
	frame.BackgroundColor3, frame.BackgroundTransparency = WHITE, 0
	local border = ink(frame, 6)
	-- LeaderboardView paints its tan lacquer border back on updates: keep it black
	border:GetPropertyChangedSignal("Color"):Connect(function()
		if border.Color ~= BLACK then
			border.Color = BLACK
		end
	end)
	round(frame, 18)
	studs(frame, 0.82, UDim2.fromOffset(48, 46))
	local title, sub = frame:FindFirstChild("Title"), frame:FindFirstChild("Sub")
	if title then
		title.TextColor3 = (PODIUM[podium] or C.gold)[1]
		textInk(title, 4)
		local pad = child(title, "UIPadding", "Pad")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0.05, 0), UDim.new(0.05, 0)
	end
	if sub then
		sub.TextColor3 = INK
		sub.FontFace = FONT
		-- Fredoka is wider: one scaled line, never two spilling out
		sub.TextWrapped = false
		sub.TextScaled = true
		local cap = child(sub, "UITextSizeConstraint", "Cap")
		cap.MaxTextSize = 40
		sub:GetPropertyChangedSignal("TextScaled"):Connect(function()
			sub.TextScaled = true
		end)
	end
end
local function skinChampTag(bb)
	for _, label in bb:GetChildren() do
		if label:IsA("TextLabel") then
			textInk(label, label.Name == "DisplayName" and 3 or 2.4)
			if label.Name == "Value" then
				label.TextColor3 = C.leaf[1]
			elseif label.Name == "DisplayName" then
				label.TextColor3 = WHITE
			end
		end
	end
end
local function skinPlaceholder(surface)
	local frame = surface:WaitForChild("Frame", 5)
	if not frame then
		return
	end
	noSkin(frame)
	frame.BackgroundColor3 = WHITE
	studs(frame, 0.85, UDim2.fromOffset(50, 46))
	for _, label in frame:GetChildren() do
		if label:IsA("TextLabel") then
			label.FontFace = FONT
			if label.TextSize >= 40 then
				label.TextColor3 = C.azure[1]
				textInk(label, 5)
			else
				label.TextColor3 = INK
			end
		end
	end
end

---------------------------------------------------------------- owner bubble + role tag
local function skinBubble(bb)
	-- the box is the tallest Frame (the other one is the little pointer under it)
	local box
	for _, f in bb:GetChildren() do
		if f:IsA("Frame") and (not box or f.Size.Y.Scale > box.Size.Y.Scale) then
			box = f
		end
	end
	if not box then
		return
	end
	noSkin(bb)
	box.BackgroundColor3 = WHITE
	ink(box, 4)
	round(box, 0.18, true)
	for _, f in box:GetChildren() do
		if f:IsA("Frame") then
			f.BackgroundColor3 = C.mango[2] -- the top strip
		elseif f:IsA("ImageLabel") then
			round(f, 0.18, true)
		end
	end
	for _, f in bb:GetChildren() do
		if f:IsA("TextLabel") then
			textInk(f, 3)
		end
	end
end
local function skinRoleTag(bb)
	-- OWNER glow (OwnerOverheadBanner, 2026-11-08): the OwnerGlow halos keep their gold strokes and only get the
	-- font; the title gets a warm gold edge instead of black so the letters look lit
	local glowing = bb:FindFirstChild("OwnerGlow1") ~= nil
	for _, label in bb:GetChildren() do
		if label:IsA("TextLabel") then
			if label.Name:match("^OwnerGlow") then
				label.FontFace = FONT
			else
				local stroke = textInk(label, glowing and 2.4 or 3.2)
				if glowing then
					stroke.Color = Color3.fromRGB(255, 196, 64)
				end
			end
		end
	end
end

---------------------------------------------------------------- dispatch
local SKINS = {
	SlotUnlockLabel = { "BillboardGui", skinSlot },
	Screen = { "SurfaceGui", skinMoney, "MoneyStand" },
	CycleTimer = { "BillboardGui", skinCycle },
	IncubationCountdown = { "BillboardGui", skinCountdown },
	ChampionPlaque = { "SurfaceGui", skinPlaque },
	ChampionTag = { "BillboardGui", skinChampTag },
	Placeholder = { "SurfaceGui", skinPlaceholder, "Leaderboard" },
	Bubble = { "BillboardGui", skinBubble, "OwnerBubble" },
	OwnerBanner = { "BillboardGui", skinRoleTag },
}
local done = setmetatable({}, { __mode = "k" })
local function consider(inst)
	local entry = SKINS[inst.Name]
	if not entry or done[inst] or not inst:IsA(entry[1]) then
		return
	end
	if entry[3] and not inst:FindFirstAncestor(entry[3]) then
		return
	end
	done[inst] = true
	task.spawn(function()
		local ok, err = pcall(entry[2], inst)
		if not ok then
			warn("[StudWorldSkin] " .. inst:GetFullName() .. ": " .. tostring(err))
		end
	end)
end
for _, d in workspace:GetDescendants() do
	consider(d)
end
workspace.DescendantAdded:Connect(consider)
