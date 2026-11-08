--[[ StarterPlayerScripts.StudHUDSkin (LocalScript), 2026-11-07
The Folk Stud look on HUD buttons that GameHUD and FigmaSkin build in code, without touching those scripts:
  GameHUD.Hotbar slots  white studded squares with a lip and a black outline; the held slot gets a thick gold outline
                        (mutated items keep their mutation colour); slot number and stack count in Fredoka
  Backpack button       (GameMenus.HotbarBagSlot / SmallButtons.BagButton) a lilac studded button with the game's
                        backpack, its "Bag" word and the red count badge
Clicks, drags and the held logic stay GameHUD's: the skin only adds a face (a Frame) and follows the slot's own Edge
stroke to know which one is held. Looks: ReplicatedStorage.FolkStudUI (M.H.dress). ]]
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.H
local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")

local SLOT = { H.WHITE, H.hex("E4DEF5"), H.hex("8C84AD") }   -- white face, cool lilac-grey lip
local GOLD, BLACK, WHITE = H.hex("FFC400"), H.BLACK, H.WHITE
local BACKPACK_ICON = "rbxassetid://109595149634754"            -- FOLK backpack (i_bag)

local function fredoka(label, size, stroke)
	label.FontFace = M.FONT
	label.TextSize = size
	label.TextColor3 = WHITE
	local s = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color, s.Thickness, s.Transparency, s.LineJoinMode = BLACK, stroke, 0, Enum.LineJoinMode.Bevel
	s.Parent = label
end

---------------------------------------------------------------- hotbar slots
local function skinSlot(holder)
	local button = holder:WaitForChild("Button", 5)
	if not button or button:GetAttribute("Stud") then return end
	button:SetAttribute("Stud", true)
	local edge = button:FindFirstChild("Edge")
	H.dress(button, SLOT, 12, { lip = 5, studs = 0.6 })
	local outline = button:FindFirstChild("Outline")
	-- GameHUD tweens the slot's transparency on hover and hold; the face stays solid
	button:GetPropertyChangedSignal("BackgroundTransparency"):Connect(function()
		if button.BackgroundTransparency ~= 0 then button.BackgroundTransparency = 0 end
	end)
	-- held = GameHUD paints its Edge white; mutation items keep their own colour
	local function syncHeld()
		if not (edge and outline) then return end
		local held = edge.Color == Color3.new(1, 1, 1)
		local mutation = button:GetAttribute("EdgeColor")
		local isMutation = mutation and mutation ~= Color3.new(0, 0, 0)
		outline.Color = held and GOLD or (isMutation and mutation or BLACK)
		outline.Thickness = held and 5 or 4
	end
	if edge then
		edge:GetPropertyChangedSignal("Color"):Connect(syncHeld)
	end
	syncHeld()
	for _, c in ipairs(button:GetChildren()) do
		if c:IsA("TextLabel") then
			if c.Text:match("^%d+$") then
				fredoka(c, 17, 2.5)          -- slot number, top left
				c.Position = UDim2.fromOffset(5, 3)
			elseif c.Text:match("^x%d+") then
				fredoka(c, 16, 2.5)          -- stack count, bottom right
			end
		end
	end
	M.animate(holder, { sounds = false })
end

local function watchHotbar(hotbar)
	for _, c in ipairs(hotbar:GetChildren()) do
		if c:IsA("Frame") then task.spawn(skinSlot, c) end
	end
	hotbar.ChildAdded:Connect(function(c)
		if c:IsA("Frame") then task.spawn(skinSlot, c) end
	end)
end
task.spawn(function()
	local hud = playerGui:WaitForChild("GameHUD")
	local hotbar = hud:WaitForChild("Hotbar", 30)
	if hotbar then watchHotbar(hotbar) end
end)

---------------------------------------------------------------- event panels (BossEventClient, ArenaEventClient)
-- The scripts keep moving, resizing and filling their panels; the skin puts a candy slab underneath (sized past the
-- panel's padding so it covers the whole panel), outlines the words in black and turns bar tracks white.
local function skinText(label)
	if label:GetAttribute("Stud") then return end
	label:SetAttribute("Stud", true)
	label.FontFace = M.FONT
	local s = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = BLACK
	s.Thickness = math.clamp(label.TextSize * 0.14, 2, 3.7)
	s.LineJoinMode = Enum.LineJoinMode.Bevel
	s.Parent = label
end
local function skinInside(d)
	if d:IsA("TextLabel") then
		skinText(d)
	elseif d:IsA("Frame") and d.Name ~= "StudSlab" and d.BackgroundTransparency < 1 and d:FindFirstChildWhichIsA("Frame") and not d:GetAttribute("Stud") then
		-- a bar track (it holds its fill): white with a black outline
		d:SetAttribute("Stud", true)
		d.BackgroundColor3 = WHITE
		local s = d:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
		s.Color, s.Thickness, s.ApplyStrokeMode = BLACK, 3, Enum.ApplyStrokeMode.Border
		s.Parent = d
	elseif d:IsA("TextButton") and d.BackgroundTransparency < 0.5 and not d:GetAttribute("Stud") then
		d:SetAttribute("Stud", true)
		H.dress(d, M.COLOR.mango, 10, { lip = 4, studs = 0.7 })
	end
end
local function skinPanel(panel, pal)
	if panel:GetAttribute("Stud") then return end
	panel:SetAttribute("Stud", true)
	local pad = panel:FindFirstChildOfClass("UIPadding")
	local l, r = pad and pad.PaddingLeft.Offset or 0, pad and pad.PaddingRight.Offset or 0
	local t, b = pad and pad.PaddingTop.Offset or 0, pad and pad.PaddingBottom.Offset or 0
	panel.BackgroundTransparency = 1
	for _, c in ipairs(panel:GetChildren()) do
		if c:IsA("UIStroke") then c.Enabled = false end
	end
	local slab = H.new("Frame", { Name = "StudSlab", BackgroundColor3 = WHITE, Position = UDim2.fromOffset(-l, -t), Size = UDim2.new(1, l + r, 1, t + b), ZIndex = 0 }, panel)
	H.round(slab, 16)
	H.grad(slab, pal[1], pal[2])
	H.ink(slab, 4)
	H.studs(slab, Vector2.new(48, 48), 0.78, 16, 0)
	H.shine(slab, 16, 0)
	for _, d in ipairs(panel:GetDescendants()) do skinInside(d) end
	panel.DescendantAdded:Connect(function(d) task.defer(skinInside, d) end)
	M.animate(panel, { sounds = false })
end
local PANELS = {
	BossEventHUD = { Panel = M.COLOR.coral },
	ArenaEventHUD = { Panel = M.COLOR.azure, BuffsBar = M.COLOR.lilac },
}
local function watchGui(gui)
	local panels = PANELS[gui.Name]
	if not panels then return end
	for name, pal in pairs(panels) do
		task.spawn(function()
			local p = gui:WaitForChild(name, 30)
			if p then skinPanel(p, pal) end
		end)
	end
end
for _, g in ipairs(playerGui:GetChildren()) do watchGui(g) end
playerGui.ChildAdded:Connect(watchGui)

---------------------------------------------------------------- inventory window (GameHUD.Inventory, the Bag)
-- GameHUD builds it once over a painted background (MenuArt) and rebuilds the item cells on every render. The skin
-- hides the painting, draws a white studded sheet with the title on its top border, the bag hanging over the corner
-- and a red X, dresses the tabs / filters / SELL as candy buttons, and gives every cell a rarity-coloured studded
-- card. GameHUD's buttons, clicks, drag to hotbar and sell logic stay its own; they are only moved and dressed.
local function optOut(root)
	root:SetAttribute("NoSkin", true)
	root:SetAttribute("FS", true)
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("GuiObject") then
			d:SetAttribute("NoSkin", true)
			d:SetAttribute("FS", true)
		end
	end
end
local SILVER = { H.hex("DDE7FF"), H.hex("8798D6"), H.hex("3F4C80") }
local RARITY_PAL = {   -- GameHUD's RARITY_COLORS -> card palette
	{ Color3.fromRGB(190, 195, 205), SILVER },
	{ Color3.fromRGB(109, 225, 132), M.COLOR.leaf },
	{ Color3.fromRGB(98, 172, 255), M.COLOR.azure },
	{ Color3.fromRGB(197, 126, 255), M.COLOR.lilac },
	{ Color3.fromRGB(255, 207, 92), M.COLOR.mango },
	{ Color3.fromRGB(255, 60, 90), M.COLOR.bubblegum },
}
local function rarityPal(col)
	for _, e in ipairs(RARITY_PAL) do
		local c = e[1]
		if math.abs(c.R - col.R) + math.abs(c.G - col.G) + math.abs(c.B - col.B) < 0.03 then return e[2] end
	end
	return M.COLOR.ink
end

local INV_W, INV_H = 660, 402
local function centre(o, cx, cy, w, h)
	o.AnchorPoint = Vector2.new(0.5, 0.5)
	o.Position = UDim2.fromOffset(cx, cy)
	o.Size = UDim2.fromOffset(w, h)
end
local function scaledLabel(b, max)
	local l = b:FindFirstChild("Label")
	if not l then return end
	l.TextScaled = true
	l.TextTruncate = Enum.TextTruncate.None
	H.new("UITextSizeConstraint", { MaxTextSize = max }, l)
	optOut(b)
end

-- one item cell: a studded card in its rarity colour under GameHUD's icon, name, tags and hit button
local function skinCell(cell)
	if not cell:IsA("Frame") or cell:GetAttribute("Stud") then return end
	cell:SetAttribute("Stud", true)
	local strip, art
	for _, c in ipairs(cell:GetChildren()) do
		if c:IsA("ImageLabel") and c.Name == "Art" then art = c
		elseif c:IsA("Frame") and c.Size.Y.Offset == 3 and c.Size.Y.Scale == 0 then strip = c end
	end
	if art then art.Visible = false end
	local pal = strip and rarityPal(strip.BackgroundColor3) or M.COLOR.ink
	if strip then strip.Visible = false end
	local face = H.new("Frame", { Name = "StudFace", Size = UDim2.fromScale(1, 1), ZIndex = 22, BackgroundColor3 = WHITE })
	H.round(face, 9)
	H.grad(face, pal[1], pal[2])
	H.studs(face, Vector2.new(48, 48), 0.72, 9, 22)
	H.shine(face, 9, 22)
	-- a soft white glow behind the character / egg
	local glow = H.new("Frame", { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0, 34), Size = UDim2.fromOffset(70, 50), BackgroundColor3 = WHITE, BackgroundTransparency = 0.55, ZIndex = 22 }, face)
	H.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, glow)
	H.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(0.7, 0.75), NumberSequenceKeypoint.new(1, 1) }) }, glow)
	-- a dark name band along the bottom so white names read on every colour
	local band = H.new("Frame", { Name = "NameBand", Position = UDim2.new(0, 4, 1, -32), Size = UDim2.new(1, -8, 0, 26), BackgroundColor3 = BLACK, BackgroundTransparency = 0.72, ZIndex = 22 }, face)
	H.round(band, 6)
	local outline = H.ink(face, 3)
	optOut(face)
	face.Parent = cell
	-- GameHUD's own stroke shows on mutated / held cells: then the black card outline steps aside
	local cs = cell:FindFirstChildOfClass("UIStroke")
	local function syncStroke()
		outline.Transparency = (cs and cs.Transparency < 1) and 1 or 0
	end
	if cs then cs:GetPropertyChangedSignal("Transparency"):Connect(syncStroke) end
	syncStroke()
	for _, c in ipairs(cell:GetChildren()) do
		if c:IsA("TextLabel") and c.Name ~= "HotbarSlot" and c.TextScaled then
			c.Position = UDim2.new(0, 8, 1, -29)
			c.Size = UDim2.new(1, -16, 0, 20)
			local st = c:FindFirstChildOfClass("UIStroke")
			if st then st.Thickness, st.LineJoinMode = 2, Enum.LineJoinMode.Bevel end
			local k = c:FindFirstChildOfClass("UITextSizeConstraint")
			if k then k.MaxTextSize = 14 end
		end
	end
end

local function skinInventory(inv)
	if inv:GetAttribute("Stud") then return end
	inv:SetAttribute("Stud", true)
	local bg = inv:FindFirstChild("Background")
	if bg then bg.Visible = false end
	for _, c in ipairs(inv:GetChildren()) do
		if c:IsA("ImageLabel") and (c.Name:match("^TabArt") or c.Name == "SellArt") then c.ImageTransparency = 1 end
	end

	-- the chrome, built unparented so SharpUI / FigmaSkin see NoSkin on it from the start
	local chrome = H.new("Frame", { Name = "StudChrome", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 20 })
	local sh = H.rect(chrome, "Shadow", 0, 8, INV_W, INV_H, 14, 19, BLACK); sh.BackgroundTransparency = 0.55
	local sheet = H.rect(chrome, "Sheet", 0, 0, INV_W, INV_H, 14, 20, WHITE)
	H.ink(sheet, 5)
	H.studs(sheet, Vector2.new(50, 46), 0.8, 14, 20)
	local well = H.rect(chrome, "Well", 14, 126, INV_W - 28, 268, 10, 20, H.hex("EDE8FA"))
	H.ink(well, 3)
	H.rect(chrome, "SearchBox", 20, 80, 200, 36, 8, 21, WHITE)
	H.ink(chrome.SearchBox, 3)
	H.text(chrome, "SearchIcon", "🔍", 38, 98, 18, 22)
	local pill = H.rect(chrome, "CountPill", 66, 35, 58, 34, 17, 21, WHITE)
	H.grad(pill, M.COLOR.coral[1], M.COLOR.coral[2])
	H.ink(pill, 3)
	H.beams(chrome, 30, 8, 130, 25, H.hex("FFE36B"), 0.35, 6)
	local bag = H.sticker(chrome, "BagIcon", BACKPACK_ICON, 30, 8, 68, 26, true)
	local title = H.text(chrome, "Title", "INVENTORY", INV_W / 2, 2, 46, 27, WHITE)
	H.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, H.hex("FFE36B")) }, title)
	H.gleam(title)
	local x = H.rect(chrome, "CloseArt", 622, -24, 56, 56, 12, 27, WHITE)
	H.grad(x, M.COLOR.coral[1], M.COLOR.coral[2])
	H.ink(x, 4)
	H.text(x, "X", "X", 28, 24, 40, 28)
	optOut(chrome)
	chrome.Parent = inv

	-- GameHUD's pieces, found by where it put them (their texts change with the filters)
	local atlas = require(ReplicatedStorage:WaitForChild("MenuArt"):WaitForChild("MenuArtAtlas"))
	local onRect = atlas.Pieces.InvTabOn and atlas.Pieces.InvTabOn.Rect
	local tabs = {
		[223] = { "All", 201, 130, M.COLOR.bubblegum },
		[352] = { "Eggs", 346, 140, M.COLOR.leaf },
		[481] = { "Characters", 521, 190, M.COLOR.azure },
	}
	local sellFace, sellButton
	for _, c in ipairs(inv:GetChildren()) do
		local px, py = 0, 0
		if c:IsA("GuiObject") then px, py = c.Position.X.Offset, c.Position.Y.Offset end
		if c:IsA("TextButton") then
			if c.Text == "" and not (px == 607 and py == 17) then c.Text = " " end   -- filled on the first render; dress needs a word to make its label
			if py == 17 and tabs[px] then
				local t = tabs[px]
				local tabArt = inv:FindFirstChild("TabArt" .. t[1])
				centre(c, t[2], 52, t[3], 36)
				H.dress(c, t[4], 10, { lip = 5, studs = 0.7 })
				scaledLabel(c, 20)
				local outline = c:FindFirstChild("Outline")
				local function syncTab()
					local on = tabArt and onRect and tabArt.ImageRectOffset == Vector2.new(onRect[1], onRect[2])
					outline.Color = on and GOLD or BLACK
					outline.Thickness = on and 6 or 4
				end
				if tabArt then tabArt:GetPropertyChangedSignal("ImageRectOffset"):Connect(syncTab) end
				syncTab()
			elseif px == 607 and py == 17 then
				centre(c, 650, 4, 60, 60)   -- invisible hit box over the drawn X
				c.Text = ""
				c.ZIndex = 30
			elseif px == 234 and py == 68 then
				centre(c, 305, 98, 150, 36)
				H.dress(c, M.COLOR.lilac, 8, { lip = 4, studs = 0.7 })
				scaledLabel(c, 17)
			elseif px == 384 and py == 68 then
				centre(c, 452, 98, 124, 36)
				H.dress(c, M.COLOR.azure, 8, { lip = 4, studs = 0.7 })
				scaledLabel(c, 17)
			elseif px == 507 and py == 68 then
				centre(c, 582, 98, 116, 36)
				sellFace = H.dress(c, M.COLOR.leaf, 8, { lip = 4, studs = 0.7 })
				sellButton = c
				scaledLabel(c, 17)
			end
		elseif c:IsA("TextBox") then
			c.Position, c.Size = UDim2.fromOffset(52, 80), UDim2.fromOffset(164, 36)
			c.TextColor3 = H.hex("3A3150")
			c.PlaceholderColor3 = H.hex("9A93B5")
			c.TextSize = 17
		elseif c:IsA("TextLabel") and px == 190 and py == 17 then
			c.Position, c.Size = UDim2.fromOffset(66, 35), UDim2.fromOffset(58, 30)
			c.TextColor3 = WHITE
			c.TextSize = 20
			c.ZIndex = 23
		elseif c:IsA("TextLabel") and px == 20 and py == 112 then   -- "Nothing here yet"
			c.Position, c.Size = UDim2.fromOffset(18, 130), UDim2.fromOffset(624, 262)
			c.TextColor3 = WHITE
			c.TextSize = 24
		elseif c:IsA("ScrollingFrame") then
			c.Position, c.Size = UDim2.fromOffset(18, 130), UDim2.fromOffset(624, 262)
			c.ScrollBarImageColor3 = H.hex("7C4DF2")
			for _, cell in ipairs(c:GetChildren()) do task.defer(skinCell, cell) end
			c.ChildAdded:Connect(function(cell) task.defer(skinCell, cell) end)
		end
	end
	-- SELL mode: GameHUD shows its red piece; the dressed button turns coral instead
	local sellArt = inv:FindFirstChild("SellArt")
	if sellArt and sellFace then
		local g = sellFace:FindFirstChildOfClass("UIGradient")
		local function syncSell()
			local pal = sellArt.Visible and M.COLOR.coral or M.COLOR.leaf
			g.Color = ColorSequence.new(pal[1], pal[2])
			sellButton.BackgroundColor3 = pal[3]
		end
		sellArt:GetPropertyChangedSignal("Visible"):Connect(syncSell)
		syncSell()
	end
	M.animate(inv, { sounds = false })
end
task.spawn(function()
	local hud = playerGui:WaitForChild("GameHUD")
	local inv = hud:WaitForChild("Inventory", 60)
	if inv then skinInventory(inv) end
end)

---------------------------------------------------------------- tutorial card, tour coach, event toasts
-- FirstHatchTutorial.GuideCard / UpgradeTour.Coach, LegendaryDropBanner.Banner, EggPickupFeedback.PickupCard: their
-- scripts only move, show and fill them, so a candy slab underneath plus outlined words is all the skin needs.
local function boldText(label, stroke, col)
	label.FontFace = M.FONT
	if col then label.TextColor3 = col end
	local s = label:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color, s.Thickness, s.Transparency, s.LineJoinMode = BLACK, stroke, 0, Enum.LineJoinMode.Bevel
	s.Parent = label
end
local function slab(parent, pal, r, z, studsTr)
	local f = H.new("Frame", { Name = "StudSlab", Size = UDim2.fromScale(1, 1), ZIndex = z or 1, BackgroundColor3 = WHITE })
	H.round(f, r)
	H.grad(f, pal[1], pal[2])
	H.ink(f, 4)
	H.studs(f, Vector2.new(48, 48), studsTr or 0.75, r, f.ZIndex)
	H.shine(f, r, f.ZIndex)
	optOut(f)
	f.Parent = parent
	return f
end
local function hideOwnLook(f)
	f.BackgroundTransparency = 1
	for _, c in ipairs(f:GetChildren()) do
		if c:IsA("UIStroke") then c.Enabled = false end
	end
end

local function skinGuide(gui)
	local card = gui:WaitForChild("GuideCard", 30)
	if card and not card:GetAttribute("Stud") then
		card:SetAttribute("Stud", true)
		hideOwnLook(card)
		for _, n in ipairs({ "Studs", "Strip" }) do
			local c = card:FindFirstChild(n)
			if c then c.Visible = false end
		end
		slab(card, M.COLOR.mango, 14, 1)
		local tag = card:FindFirstChild("StepTag")
		if tag then
			for _, c in ipairs(tag:GetChildren()) do
				if c:IsA("ImageLabel") then c.Visible = false end
				if c:IsA("UIStroke") then c.Enabled = false end
			end
			tag.BackgroundTransparency = 1
			local face = H.new("Frame", { Name = "StudFace", Size = UDim2.fromScale(1, 1), ZIndex = tag.ZIndex, BackgroundColor3 = WHITE })
			H.round(face, 12); H.grad(face, M.COLOR.lilac[1], M.COLOR.lilac[2]); H.ink(face, 4)
			H.studs(face, Vector2.new(48, 48), 0.65, 12, tag.ZIndex)
			optOut(face)
			face.Parent = tag
			local n = tag:FindFirstChild("Progress")
			if n then boldText(n, 3.7, WHITE); n.ZIndex = tag.ZIndex + 2 end
		end
		local o = card:FindFirstChild("Objective")
		if o then boldText(o, 3.2, WHITE) end
		local i = card:FindFirstChild("Instruction")
		if i then boldText(i, 1.6, WHITE); i.TextSize = 15 end
		local d = card:FindFirstChild("Distance")
		if d then boldText(d, 2.4, WHITE) end
		local track = card:FindFirstChild("Track")
		if track then
			track.BackgroundColor3 = WHITE
			local s = track:FindFirstChildOfClass("UIStroke")
			if s then s.Color, s.Thickness = BLACK, 2.5 end
			H.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, track)
			local fill = track:FindFirstChild("Fill")
			if fill then
				fill.BackgroundColor3 = WHITE
				H.new("UICorner", { CornerRadius = UDim.new(0.5, 0) }, fill)
				H.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(M.COLOR.leaf[1], M.COLOR.leaf[2]) }, fill)
			end
		end
		M.animate(card, { sounds = false })
	end
	local tour = gui:WaitForChild("UpgradeTour", 30)
	local coach = tour and tour:WaitForChild("Coach", 30)
	if coach and not coach:GetAttribute("Stud") then
		coach:SetAttribute("Stud", true)
		hideOwnLook(coach)
		slab(coach, M.COLOR.lilac, 14, coach.ZIndex)
		for _, n in ipairs({ "Title", "Body", "Hint" }) do
			local l = coach:FindFirstChild(n)
			if l then
				boldText(l, n == "Title" and 2.8 or 2, n == "Title" and H.hex("FFE36B") or WHITE)
				l.ZIndex = coach.ZIndex + 3
			end
		end
		local nextButton = coach:FindFirstChild("Next")
		if nextButton then
			local w, h = nextButton.Size.X.Offset, nextButton.Size.Y.Offset
			nextButton.Size = UDim2.fromOffset(w, h + 6)
			H.dress(nextButton, M.COLOR.leaf, 8, { lip = 4, studs = 0.7 })
			optOut(nextButton)
		end
		M.animate(coach, { sounds = false })
	end
end

local function skinLegendaryBanner(gui)
	local banner = gui:WaitForChild("Banner", 30)
	if not banner or banner:GetAttribute("Stud") then return end
	banner:SetAttribute("Stud", true)
	local plate = banner:FindFirstChild("Plate")
	if plate then plate.Visible = false end
	local holder = H.new("Frame", { Name = "StudBack", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 })
	local s = slab(holder, M.COLOR.mango, 16, 1, 0.7)
	s.Position, s.Size = UDim2.fromOffset(0, 4), UDim2.new(1, 0, 1, -8)
	s:FindFirstChild("Outline").Thickness = 5
	H.beams(holder, 46, 44, 130, 2, H.hex("FFF6B0"), 0.3, 6)
	-- the egg from the plot atlas (PlotConfig / PlotAtlas sit next to PlotComponent in GameMenus)
	local menus = playerGui:WaitForChild("GameMenus", 30)
	local okC, cfg = pcall(function() return require(menus:WaitForChild("PlotConfig", 20)) end)
	local okA, atlas = pcall(function() return require(menus:WaitForChild("PlotAtlas", 20)) end)
	local info = okA and atlas.Pieces and atlas.Pieces.Egg
	if okC and info then
		local r = info.Rect
		local k = 66 / math.max(r[3], r[4])
		local egg = H.new("ImageLabel", { Name = "Egg", BackgroundTransparency = 1, Image = cfg.Pieces, ImageRectOffset = Vector2.new(r[1], r[2]), ImageRectSize = Vector2.new(r[3], r[4]),
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(46, 44), Size = UDim2.fromOffset(r[3] * k, r[4] * k), ZIndex = 3 }, holder)
		egg:SetAttribute("Wiggle", 0)
	end
	optOut(holder)
	holder.Parent = banner
	local label = banner:FindFirstChild("Label")
	if label then
		label.Position, label.Size = UDim2.fromOffset(82, 12), UDim2.fromOffset(540, 60)
		boldText(label, 3.7, WHITE)
		label.ZIndex = 4
		local k = label:FindFirstChildOfClass("UITextSizeConstraint")
		if k then k.MaxTextSize = 44 end
		if not label:FindFirstChildOfClass("UIGradient") then
			H.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, H.hex("FFF3B0")) }, label)
		end
		H.gleam(label)
	end
	M.animate(banner, { sounds = false })
end

local function skinPickup(gui)
	local card = gui:WaitForChild("PickupCard", 30)
	local panel = card and card:WaitForChild("Panel", 10)
	if not panel or panel:GetAttribute("Stud") then return end
	panel:SetAttribute("Stud", true)
	for _, c in ipairs(panel:GetChildren()) do
		if c.Name == "EggPattern" then c.Visible = false
		elseif c:IsA("UIGradient") then c.Color = ColorSequence.new(M.COLOR.leaf[1], M.COLOR.leaf[2]); c.Rotation = 90
		elseif c:IsA("UIStroke") then c.Color, c.Thickness, c.LineJoinMode = BLACK, 4, Enum.LineJoinMode.Bevel
		elseif c:IsA("UICorner") then c.CornerRadius = UDim.new(0, 10)
		elseif c:IsA("TextLabel") then boldText(c, 3, WHITE)
		end
	end
	panel.BackgroundColor3 = WHITE
	local st = H.studs(panel, Vector2.new(48, 48), 0.7, 10, 2)
	st:SetAttribute("NoSkin", true)
	H.shine(panel, 10, 2):SetAttribute("NoSkin", true)
	M.animate(panel, { sounds = false })
end

-- CinematicHatch's "HATCHING..." / "<NAME> UNLOCKED" line: big Fredoka with a gold fade and a black outline (the
-- script fades it with TextTransparency, which the outline follows)
local function skinHatchTitle(gui)
	local title
	for _ = 1, 40 do
		title = gui:FindFirstChildOfClass("TextLabel")
		if title then break end
		task.wait(0.25)
	end
	if not title or title:GetAttribute("Stud") then return end
	title:SetAttribute("Stud", true)
	title.TextStrokeTransparency = 1
	title.Size = UDim2.fromOffset(1000, 86)
	title.TextScaled = true
	title.TextColor3 = WHITE
	H.new("UITextSizeConstraint", { MaxTextSize = 62 }, title)
	boldText(title, 4, WHITE)
	H.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, H.hex("FFC400")) }, title)
end

local EVENT_GUIS = { FirstHatchTutorial = skinGuide, LegendaryDropBanner = skinLegendaryBanner, EggPickupFeedback = skinPickup, CinematicHatchUI = skinHatchTitle }
local function watchEventGui(g)
	local f = EVENT_GUIS[g.Name]
	if f then task.spawn(f, g) end
end
for _, g in ipairs(playerGui:GetChildren()) do watchEventGui(g) end
playerGui.ChildAdded:Connect(watchEventGui)

---------------------------------------------------------------- backpack button
local function skinBag(bag)
	if bag:GetAttribute("Stud") then return end
	bag:SetAttribute("Stud", true)
	bag:SetAttribute("Smooth", true)   -- FigmaSkin's own hover would fight the kit's pop
	local badge = bag:FindFirstChild("Badge")
	H.dress(bag, M.COLOR.lilac, 14, { lip = 5, studs = 0.7, hide = true, keep = { Badge = true } })
	local icon = H.art(bag, "Icon", BACKPACK_ICON, 31, 26, 46, bag.ZIndex + 2)
	H.gleam(H.text(bag, "Word", "Bag", 31, 50, 17, bag.ZIndex + 3))
	if badge then
		badge.ZIndex = bag.ZIndex + 5
		badge.FontFace = M.FONT
	end
	M.animate(bag, { sounds = false })
end
task.spawn(function()
	local hud = playerGui:WaitForChild("GameHUD")
	local right = hud:WaitForChild("RightButtons", 30)
	local bag = right and right:FindFirstChild("BagButton")
	if not bag then
		-- FigmaSkin moves it into GameMenus (SmallButtons, then HotbarBagSlot)
		local menus = playerGui:WaitForChild("GameMenus")
		for _ = 1, 60 do
			bag = menus:FindFirstChild("BagButton", true)
			if bag then break end
			task.wait(0.5)
		end
	end
	if not bag then return end
	-- FigmaSkin swaps its art in after it moves the button (and would hide anything added before): dress it after that
	for _ = 1, 60 do
		if bag:FindFirstChild("FigmaArt") then break end
		task.wait(0.5)
	end
	task.wait(0.2)
	skinBag(bag)
end)
