--[[ FirstHatchTutorial (LocalScript, StarterPlayerScripts)
A local first-hatch guide. No client requests can grant progress or rewards.

2026-11-07: Folk Stud look (white studded sheet, black outlines, candy colours, FOLK icons, Gotham Black). The step
logic, the remote and every name other scripts look for are unchanged: GuideCard, UpgradeTour.Coach, the gui name and
its Enabled flag (CinematicHatch turns it off). GuideCard / Coach carry Stud = true so StudHUDSkin leaves them alone.

Steps 0..8 (world guide; 0 = a new player's starter cash): ReplicatedStorage.FirstHatchGuide.Resolve(player) picks the
step and target part; this script shows the top card, a highlight, a bouncing destination sign and a beam toward it.
Steps 9..12 (UI tour of Plot -> Upgrades): server-driven via Player.TutorialTourStage. The client only reports
what it saw through ReplicatedStorage.FirstHatchTutorialAction (RemoteEvent, action string:
PlotOpened / UpgradesOpened / TempleSeen / IncubatorsSeen); TutorialProgress (server) validates the stage and
advances it. Step 13 / Player.TutorialCompleted ends the guide.

Reads player attributes TutorialDataReady, TutorialCompleted, JoinArrivalStarted / JoinArrivalFinished.
Depends on instance names owned by other scripts (see the GameHUD / MenuLogic headers):
  PlayerGui.GameHUD.EggBag, GameMenus.Dim / .Plot (attribute Page, child Live with UpgradesTab,
  TempleUpgrades, IncubatorUpgrades) / .LeftMenu (descendant PlotButton), MusicSettingsUI.Panel, CharacterInventory,
  OwnerPanel, StolenEggBanner.Frame, CinematicHatchUI (attribute Active), PromptCard billboards,
  HatchLoading / LaunchLoadingScreen.
]]

-- ===== 1. Services and dependencies =====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HudScale = require(ReplicatedStorage:WaitForChild("HudScale"))
local Guide = require(ReplicatedStorage:WaitForChild("FirstHatchGuide"))
local tourRemote = ReplicatedStorage:WaitForChild("FirstHatchTutorialAction")
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ===== 2. Style =====
local function hex(h)
	return Color3.fromHex(h)
end
local WHITE, BLACK = Color3.new(1, 1, 1), Color3.new(0, 0, 0)
local INK_TEXT = hex("26211D") -- warm charcoal for the small words on the white sheet
local FONT = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
local BODY = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Bold)
local STUD = "rbxassetid://3014551673"
-- face top, face bottom, lip (no indigo / violet: see the "No AI colours" rule)
local PAL = {
	gold = { hex("FFC21F"), hex("F58C00"), hex("8F4E00") },
	blue = { hex("2E9BFF"), hex("0B72E8"), hex("053E85") },
	green = { hex("3EE05A"), hex("13A831"), hex("0A5C1A") },
	pink = { hex("FF4FB8"), hex("E8148C"), hex("8C0852") },
	red = { hex("FF4A3D"), hex("E3261B"), hex("8A1209") },
	jade = { hex("1ED6B8"), hex("0AAE95"), hex("05604F") },
	grape = { hex("D24DF0"), hex("9C10C4"), hex("640878") },
	sky = { hex("4FD2FF"), hex("10A6E8"), hex("065C85") },
}
-- FOLK Icon Pack art (Steal Anime Egg/assets/ui/stud/up/ids.tsv)
local ICON = {
	cash = "rbxassetid://136807180106184", -- i_cash
	cashpile = "rbxassetid://86652590101281", -- i_cashpile
	egg = "rbxassetid://72466978369063", -- e_plain (image id)
	eggGold = "rbxassetid://132296043153963", -- e_cracked (image id)
	house = "rbxassetid://133879873952343", -- i_house
	clock = "rbxassetid://123064760828653", -- i_clock
	star = "rbxassetid://87844351568148", -- i_star
	friend = "rbxassetid://100051187503757", -- i_friend
	plot = "rbxassetid://95180290931446", -- i_plot
	rebirth = "rbxassetid://94797345269406", -- i_rebirth
	plus = "rbxassetid://124647673169644", -- i_plus
	trophy = "rbxassetid://133620970719071", -- i_trophy
}
-- one look per step: tile colour + icon
local LOOK = {
	[0] = { PAL.green, ICON.cash },
	[1] = { PAL.blue, ICON.egg },
	[2] = { PAL.gold, ICON.house },
	[3] = { PAL.pink, ICON.egg },
	[4] = { PAL.sky, ICON.clock },
	[5] = { PAL.gold, ICON.eggGold },
	[6] = { PAL.jade, ICON.friend },
	[7] = { PAL.red, ICON.plot },
	[8] = { PAL.green, ICON.cashpile },
	[9] = { PAL.red, ICON.plot },
	[10] = { PAL.blue, ICON.rebirth },
	[11] = { PAL.gold, ICON.house },
	[12] = { PAL.pink, ICON.plus },
}
local function reduced()
	return GuiService.ReducedMotionEnabled
end

local function new(class, props, parent)
	local instance = Instance.new(class)
	if instance:IsA("GuiObject") then
		instance.BorderSizePixel = 0
	end
	for key, value in props do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end
-- house style is sharp: no rounded corners anywhere (kept as a hook so the layout code reads the same)
local function corner(o, _r)
	return o
end
local function ink(o, t)
	return new("UIStroke", {
		Name = "Outline",
		Thickness = t or 4,
		Color = BLACK,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		LineJoinMode = Enum.LineJoinMode.Miter,
	}, o)
end
local function paint(o, pal)
	o.BackgroundColor3 = WHITE
	local g = o:FindFirstChild("Paint") or new("UIGradient", { Name = "Paint", Rotation = 90 }, o)
	g.Color = ColorSequence.new(pal[1], pal[2])
	return g
end
local function studs(o, tile, tr, r)
	local s = new("ImageLabel", {
		Name = "Studs",
		BackgroundTransparency = 1,
		Image = STUD,
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(tile.X, tile.Y),
		ImageTransparency = tr,
		Size = UDim2.fromScale(1, 1),
		ZIndex = o.ZIndex,
	}, o)
	if r then
		corner(s, r)
	end
	return s
end
-- words with the house outline (Gotham Black + black bevel stroke)
local function words(parent, name, props, stroke)
	local l = new("TextLabel", {
		Name = name,
		BackgroundTransparency = 1,
		FontFace = FONT,
		TextColor3 = WHITE,
		TextScaled = true,
	}, parent)
	for k, v in props do
		l[k] = v
	end
	if stroke then
		new("UIStroke", { Name = "UIStroke", Color = BLACK, Thickness = stroke, LineJoinMode = Enum.LineJoinMode.Bevel }, l)
	end
	return l
end
-- art with a black outline (black copies underneath), the kit's sticker
local function sticker(parent, name, image, size, z)
	local holder = new("Frame", {
		Name = name,
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		ZIndex = z,
	}, parent)
	local inks = {}
	for _, d in { { 0, 5, 0.55 }, { -2, 0, 0 }, { 2, 0, 0 }, { 0, -2, 0 }, { 0, 2, 0 } } do
		table.insert(
			inks,
			new("ImageLabel", {
				Name = "Ink",
				BackgroundTransparency = 1,
				Image = image,
				ImageColor3 = BLACK,
				ImageTransparency = d[3],
				ScaleType = Enum.ScaleType.Fit,
				Position = UDim2.fromOffset(d[1], d[2]),
				Size = UDim2.fromScale(1, 1),
				ZIndex = z,
			}, holder)
		)
	end
	local art = new("ImageLabel", {
		Name = "Art",
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
		ZIndex = z,
	}, holder)
	return holder, function(newImage)
		art.Image = newImage
		for _, i in inks do
			i.Image = newImage
		end
	end
end
-- a light band that sweeps over a face now and then
local function shine(o, r)
	local s = new("Frame", { Name = "Shine", BackgroundColor3 = WHITE, Size = UDim2.fromScale(1, 1), ZIndex = o.ZIndex }, o)
	corner(s, r)
	local k = NumberSequenceKeypoint.new
	local g = new("UIGradient", {
		Rotation = 25,
		Offset = Vector2.new(-1, 0),
		Transparency = NumberSequence.new({ k(0, 1), k(0.4, 1), k(0.5, 0.45), k(0.6, 1), k(1, 1) }),
	}, s)
	return g
end
-- a pill on a border: candy face, black outline, white words; hugs its text
local function pill(parent, name, pal, text, height, textSize, z)
	local p = new("Frame", {
		Name = name,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = z,
	}, parent)
	corner(p, "pill")
	paint(p, pal)
	ink(p, 3)
	new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, p)
	local l = words(p, "Label", {
		Text = text,
		TextScaled = false,
		TextSize = textSize,
		Size = UDim2.fromOffset(0, height),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = z + 1,
	}, 2.6)
	return p, l
end
local TWEEN_POP = TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local function pop(scale, from)
	if reduced() then
		scale.Scale = 1
		return
	end
	scale.Scale = from or 0.82
	TweenService:Create(scale, TWEEN_POP, { Scale = 1 }):Play()
end

-- ===== 3. Guide card (steps 0..8) =====
local CARD_W, CARD_H = 480, 132
local TOTAL = #Guide.Steps
-- built unparented so StudHUDSkin's ChildAdded sees Stud = true on the card before it looks
local gui = new("ScreenGui", {
	Name = "FirstHatchTutorial",
	ResetOnSpawn = false,
	DisplayOrder = 55,
	Enabled = false,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, nil)
local card = new("Frame", {
	Name = "GuideCard",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 72),
	Size = UDim2.fromOffset(CARD_W, CARD_H),
	BackgroundTransparency = 1,
	Active = false,
}, gui)
card:SetAttribute("Stud", true)
card:SetAttribute("NoSkin", true)
local cardScale = new("UIScale", { Name = "Fit" }, card)
-- the motion scale sits on an inner holder, so fitting and popping never fight over one UIScale
local cardBody = new("Frame", {
	Name = "Body",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
}, card)
local cardPop = new("UIScale", { Name = "Pop" }, cardBody)
new("Frame", {
	Name = "Shadow",
	Position = UDim2.fromOffset(0, 7),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = BLACK,
	BackgroundTransparency = 0.6,
	ZIndex = 1,
}, cardBody)
corner(cardBody.Shadow, 18)
local sheet = new("Frame", { Name = "Sheet", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 2 }, cardBody)
corner(sheet, 18)
ink(sheet, 4)
studs(sheet, Vector2.new(50, 46), 0.8, 18)
-- icon tile on the left
local TILE = 96
local tile = new("Frame", {
	Name = "IconTile",
	Position = UDim2.fromOffset(16, (CARD_H - TILE) / 2 + 2),
	Size = UDim2.fromOffset(TILE, TILE),
	ZIndex = 3,
}, cardBody)
corner(tile, 16)
paint(tile, LOOK[1][1])
ink(tile, 4)
studs(tile, Vector2.new(48, 48), 0.6, 16)
local tileShine = shine(tile, 16)
local tileIcon, setTileIcon = sticker(tile, "Icon", LOOK[1][2], 72, 5)
-- the step chip on the top border (the style's title-on-the-line)
local chip, chipLabel = pill(cardBody, "StepChip", PAL.gold, "STEP 1 OF " .. TOTAL, 30, 16, 8)
chip.Position = UDim2.new(0.5, 0, 0, 0)
local chipPop = new("UIScale", {}, chip)
-- words
local TX = 16 + TILE + 16
local objectiveLabel = words(cardBody, "Objective", {
	Position = UDim2.fromOffset(TX, 20),
	Size = UDim2.fromOffset(CARD_W - TX - 18, 34),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 4,
}, 3.2)
new("UITextSizeConstraint", { MaxTextSize = 28, MinTextSize = 14 }, objectiveLabel)
local instructionLabel = new("TextLabel", {
	Name = "Instruction",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(TX, 56),
	Size = UDim2.fromOffset(CARD_W - TX - 18, 38),
	FontFace = BODY,
	TextColor3 = INK_TEXT,
	TextScaled = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 4,
}, cardBody)
new("UITextSizeConstraint", { MaxTextSize = 17, MinTextSize = 11 }, instructionLabel)
-- progress pips along the bottom
local PIP, PIP_GAP = 13, 4
local pipRow = new("Frame", {
	Name = "Track",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(TX, CARD_H - 36),
	Size = UDim2.fromOffset(TOTAL * (PIP + PIP_GAP), PIP + 4),
	ZIndex = 4,
}, cardBody)
local pips = {}
for i = 1, TOTAL do
	local p = new("Frame", {
		Name = "Pip" .. i,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((i - 1) * (PIP + PIP_GAP) + PIP / 2 + 2, (PIP + 4) / 2),
		Size = UDim2.fromOffset(PIP, PIP),
		BackgroundColor3 = WHITE,
		ZIndex = 4,
	}, pipRow)
	corner(p, 4)
	ink(p, 2.5)
	pips[i] = { frame = p, scale = new("UIScale", {}, p) }
end
-- distance / status pill, bottom right
local distancePill, distanceLabel = pill(cardBody, "Distance", PAL.gold, "", 30, 16, 6)
-- sits on the bottom border (mirrors the step chip on the top line), so it never covers the pips
distancePill.AnchorPoint = Vector2.new(1, 0.5)
distancePill.Position = UDim2.fromOffset(CARD_W - 18, CARD_H)

local currentPipTween
local function setProgress(stepNumber)
	if currentPipTween then
		currentPipTween:Cancel()
		currentPipTween = nil
	end
	for i, pip in pips do
		local frame = pip.frame
		pip.scale.Scale = 1
		if i < (stepNumber or 0) then
			paint(frame, PAL.green)
		elseif i == stepNumber then
			paint(frame, PAL.gold)
			if not reduced() then
				currentPipTween = TweenService:Create(
					pip.scale,
					TweenInfo.new(0.55, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
					{ Scale = 1.3 }
				)
				currentPipTween:Play()
			end
		else
			local g = frame:FindFirstChild("Paint")
			if g then
				g:Destroy()
			end
			frame.BackgroundColor3 = WHITE
		end
	end
end
local lastDistanceKind
local function setDistance(kind, text)
	distanceLabel.Text = text
	if kind ~= lastDistanceKind then
		lastDistanceKind = kind
		paint(distancePill, kind == "here" and PAL.green or (kind == "wait" and PAL.sky or PAL.gold))
	end
end
local shownStep
local function showStep(step, title, body)
	local look = LOOK[step] or LOOK[1]
	objectiveLabel.Text = title
	instructionLabel.Text = body
	if step == shownStep then
		return
	end
	local isAdvance = shownStep ~= nil and step > shownStep
	shownStep = step
	paint(tile, look[1])
	paint(chip, look[1])
	setTileIcon(look[2])
	chipLabel.Text = step == 0 and "START" or ("STEP " .. step .. " OF " .. TOTAL)
	setProgress(step)
	pop(cardPop, isAdvance and 0.86 or 0.9)
	pop(chipPop, 0.6)
	if isAdvance then
		UISound.Play("Success", 1.05, 0.35)
	end
end
-- the tile's icon bobs and its shine sweeps now and then (stopped under Reduced Motion)
task.spawn(function()
	local t = 0
	repeat
		t += task.wait(1 / 30)
		if gui.Enabled and card.Visible and not reduced() then
			tileIcon.Position = UDim2.new(0.5, 0, 0.5, math.sin(t * 2.4) * 3)
			tileIcon.Rotation = math.sin(t * 1.7) * 5
			local phase = (t % 3.2) / 0.9
			tileShine.Offset = Vector2.new(phase <= 1 and (-1 + phase * 2) or 1, 0)
		end
	until gui.Parent == nil -- the gui is parented at the end of this script, before this loop resumes
end)
-- The card steps aside while a menu panel (shop, egg bag, inventory, settings) is open.
local function isGuiShown(guiName, childName)
	local screenGui = playerGui:FindFirstChild(guiName)
	if not (screenGui and screenGui:IsA("ScreenGui") and screenGui.Enabled) then
		return false
	end
	if not childName then
		for _, child in screenGui:GetChildren() do
			if child:IsA("GuiObject") and child.Visible then
				return true
			end
		end
		return false
	end
	local child = screenGui:FindFirstChild(childName)
	return child ~= nil and child:IsA("GuiObject") and child.Visible
end
local function isMenuOpen()
	return isGuiShown("GameHUD", "EggBag")
		or isGuiShown("GameMenus", "Dim")
		or isGuiShown("MusicSettingsUI", "Panel")
		or isGuiShown("CharacterInventory")
		or isGuiShown("OwnerPanel")
end
-- Scales the card for the viewport and moves it below the egg banner; snaps on first placement, tweens after.
local cardTop, cardTween = nil, nil
local function fitToScreen()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local hud = HudScale.For(gui.AbsoluteSize)
	-- full HUD size so it reads next to the rail buttons, but never wider than the screen (phones)
	cardScale.Scale = math.min(hud, (gui.AbsoluteSize.X - 24) / CARD_W)
	local targetTop = math.round(34 * hud) -- room for the chip that sits on the top border
	local banner = playerGui:FindFirstChild("StolenEggBanner")
	local bannerFrame = banner and banner:IsA("ScreenGui") and banner.Enabled and banner:FindFirstChild("Frame")
	if bannerFrame and bannerFrame:IsA("GuiObject") and bannerFrame.Visible then
		local bannerBottom = bannerFrame.AbsolutePosition.Y + bannerFrame.AbsoluteSize.Y
		if bannerBottom > 0 then
			targetTop = math.max(targetTop, math.floor(bannerBottom + 18 * hud))
		end
	end
	if targetTop ~= cardTop then
		local isFirstPlacement = cardTop == nil
		cardTop = targetTop
		if cardTween then
			cardTween:Cancel()
		end
		if isFirstPlacement then
			card.Position = UDim2.new(0.5, 0, 0, targetTop)
		else
			cardTween = TweenService:Create(
				card,
				TweenInfo.new(0.25, Enum.EasingStyle.Quad),
				{ Position = UDim2.new(0.5, 0, 0, targetTop) }
			)
			cardTween:Play()
		end
	end
end

-- ===== 4. World guide: highlight, destination sign, beam =====
local worldFolder = new("Folder", { Name = "TutorialGroundTrail" }, workspace)
local objectiveHighlight = new("Highlight", {
	Name = "TutorialObjective",
	FillColor = PAL.gold[1],
	FillTransparency = 0.85,
	OutlineTransparency = 0.1,
	OutlineColor = PAL.gold[1],
	DepthMode = Enum.HighlightDepthMode.Occluded,
	Enabled = false,
}, worldFolder)
-- Destination sign: a gold pill with the step's word and a bouncing pointer under it
local destinationMarker = new("BillboardGui", {
	Name = "Destination",
	Size = UDim2.fromOffset(260, 104),
	StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0),
	AlwaysOnTop = true,
	MaxDistance = 220,
	Enabled = false,
	LightInfluence = 0,
	ResetOnSpawn = false,
}, gui)
local markerBob = new("Frame", {
	Name = "Bob",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
}, destinationMarker)
local markerPlate, markerCaption = pill(markerBob, "Plate", PAL.gold, "", 40, 21, 3)
markerPlate.Position = UDim2.new(0.5, 0, 0, 24)
local markerIconHolder = new("Frame", {
	Name = "IconSlot",
	BackgroundTransparency = 1,
	Size = UDim2.fromOffset(34, 34),
	LayoutOrder = -1,
	ZIndex = 5,
}, markerPlate)
local _, setMarkerIcon = sticker(markerIconHolder, "Icon", ICON.egg, 34, 5)
markerCaption.LayoutOrder = 1
new("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	VerticalAlignment = Enum.VerticalAlignment.Center,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, markerPlate)
-- pointer: a gold diamond with a black outline under the pill
local markerTip = new("Frame", {
	Name = "Tip",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, 62),
	Size = UDim2.fromOffset(26, 26),
	Rotation = 45,
	ZIndex = 2,
}, markerBob)
corner(markerTip, 4)
paint(markerTip, PAL.gold).Rotation = 45
ink(markerTip, 3)
local markerPop = new("UIScale", {}, markerBob)
task.spawn(function()
	local t = 0
	while worldFolder.Parent do
		t += task.wait(1 / 30)
		if destinationMarker.Enabled and not reduced() then
			local bounce = math.abs(math.sin(t * 3.2))
			markerBob.Position = UDim2.fromOffset(0, -bounce * 10)
			markerTip.Size = UDim2.fromOffset(26, 26 - (1 - bounce) * 4)
		end
	end
end)
-- In-world guide: one straight Beam from an Attachment on the player to an Attachment on the
-- objective. The arrow texture points toward Attachment0, so Attachment0 sits on the target.
local ARROW_TEXTURE = "rbxassetid://86109313256799"
local guideBeam = new("Beam", {
	Name = "GuideBeam",
	Enabled = false,
	FaceCamera = true,
	Width0 = 1.6,
	Width1 = 1.6,
	Color = ColorSequence.new(PAL.gold[1]),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.55) }),
	LightEmission = 0.5,
	LightInfluence = 0,
	Segments = 1,
	Texture = ARROW_TEXTURE,
	TextureMode = Enum.TextureMode.Static,
	TextureLength = 3,
	TextureSpeed = 0,
}, worldFolder)
local goalAttachment -- Attachment on the current target part
local footAttachment -- Attachment on the local character
local currentStep, currentTarget
-- ===== 5. State and target helpers =====
local stopped = false
-- true once the guide was visible at least once; finish() only shows the "ready" card then.
local hasShownGuide = false
local connections = {}
local function hideTrail()
	guideBeam.Enabled = false
end
local function clearTarget()
	hideTrail()
	if goalAttachment then
		goalAttachment:Destroy()
		goalAttachment = nil
	end
	objectiveHighlight.Enabled = false
	objectiveHighlight.Adornee = nil
	destinationMarker.Enabled = false
	destinationMarker.Adornee = nil
end
-- Destination labels yield to the real interaction card at the same anchor.
local function hasInteractionCard(part)
	for _, billboard in playerGui:GetChildren() do
		if billboard:IsA("BillboardGui") and billboard.Name == "PromptCard" and billboard.Enabled then
			local adornee = billboard.Adornee
			if adornee == part or (adornee and adornee:IsDescendantOf(part)) then
				return true
			end
		end
	end
	return false
end
local function hatchCameraActive()
	local cinematicGui = playerGui:FindFirstChild("CinematicHatchUI")
	return cinematicGui and cinematicGui:GetAttribute("Active") == true
end
-- Hide immediately at camera takeover rather than waiting for the next guide update.
local function watchHatchUI(cinematicGui)
	if cinematicGui.Name ~= "CinematicHatchUI" then
		return
	end
	local function onActiveChanged()
		if cinematicGui:GetAttribute("Active") == true then
			gui.Enabled = false
			clearTarget()
		end
	end
	table.insert(connections, cinematicGui:GetAttributeChangedSignal("Active"):Connect(onActiveChanged))
	onActiveChanged()
end
local existingCinematic = playerGui:FindFirstChild("CinematicHatchUI")
if existingCinematic then
	watchHatchUI(existingCinematic)
end
table.insert(connections, playerGui.ChildAdded:Connect(watchHatchUI))
local function ensureFoot(rootPart)
	if footAttachment and footAttachment.Parent == rootPart then
		return
	end
	if footAttachment then
		footAttachment:Destroy()
	end
	footAttachment = new("Attachment", { Name = "TutorialGuideFoot", Position = Vector3.new(0, -1.5, 0) }, rootPart)
	guideBeam.Attachment1 = footAttachment
end
local function ensureGoal(part)
	if goalAttachment and goalAttachment.Parent == part then
		return
	end
	if goalAttachment then
		goalAttachment:Destroy()
	end
	goalAttachment = new("Attachment", { Name = "TutorialGuideGoal" }, part)
	guideBeam.Attachment0 = goalAttachment
end

-- ===== 6. UI tour (steps 9..12) =====
local tourCanvas = new(
	"Frame",
	{ Name = "UpgradeTour", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false },
	gui
)
-- focus ring: black outside, gold inside, gently breathing; a "TAP!" pointer bobs above it
local focusFrame = new(
	"Frame",
	{ Name = "Focus", BackgroundTransparency = 1, Visible = false, ZIndex = 20 },
	tourCanvas
)
corner(focusFrame, 12)
new("UIStroke", { Color = BLACK, Thickness = 9, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, focusFrame)
local focusInner = new("Frame", {
	Name = "Gold",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
	ZIndex = 21,
}, focusFrame)
corner(focusInner, 12)
local focusGold = new("UIStroke", { Color = PAL.gold[1], Thickness = 5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, focusInner)
local tapPointer = new("Frame", {
	Name = "Tap",
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 1),
	Size = UDim2.fromOffset(90, 56),
	ZIndex = 22,
}, focusFrame)
local tapPill = pill(tapPointer, "Pill", PAL.gold, "TAP!", 30, 17, 23)
tapPill.Position = UDim2.new(0.5, 0, 0, 15)
local tapTip = new("Frame", {
	Name = "Tip",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.new(0.5, 0, 0, 38),
	Size = UDim2.fromOffset(18, 18),
	Rotation = 45,
	ZIndex = 22,
}, tapPointer)
corner(tapTip, 3)
paint(tapTip, PAL.gold).Rotation = 45
ink(tapTip, 3)
-- coach card at the bottom: same white sheet as the guide card
local COACH_W, COACH_H = 440, 150
local coachCard = new("Frame", {
	Name = "Coach",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -12),
	Size = UDim2.fromOffset(COACH_W, COACH_H),
	BackgroundTransparency = 1,
	ZIndex = 30,
}, tourCanvas)
coachCard:SetAttribute("Stud", true)
coachCard:SetAttribute("NoSkin", true)
local coachFit = new("UIScale", { Name = "Fit" }, coachCard)
local coachBodyFrame = new("Frame", {
	Name = "Body",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	ZIndex = 30,
}, coachCard)
local coachPop = new("UIScale", { Name = "Pop" }, coachBodyFrame)
local coachShadow = new("Frame", {
	Name = "Shadow",
	Position = UDim2.fromOffset(0, 7),
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = BLACK,
	BackgroundTransparency = 0.6,
	ZIndex = 30,
}, coachBodyFrame)
corner(coachShadow, 18)
local coachSheet = new("Frame", { Name = "Sheet", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, ZIndex = 31 }, coachBodyFrame)
corner(coachSheet, 18)
ink(coachSheet, 4)
studs(coachSheet, Vector2.new(50, 46), 0.8, 18)
local coachTile = new("Frame", {
	Name = "IconTile",
	Position = UDim2.fromOffset(16, 26),
	Size = UDim2.fromOffset(84, 84),
	ZIndex = 32,
}, coachBodyFrame)
corner(coachTile, 14)
paint(coachTile, PAL.red)
ink(coachTile, 4)
studs(coachTile, Vector2.new(48, 48), 0.6, 14)
local _, setCoachIcon = sticker(coachTile, "Icon", ICON.plot, 62, 34)
local coachChip, coachChipLabel = pill(coachBodyFrame, "StepChip", PAL.red, "", 30, 16, 36)
coachChip.Position = UDim2.new(0.5, 0, 0, 0)
local CX = 16 + 84 + 14
local coachTitle = words(coachBodyFrame, "Title", {
	Position = UDim2.fromOffset(CX, 20),
	Size = UDim2.fromOffset(COACH_W - CX - 16, 30),
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 33,
}, 3)
new("UITextSizeConstraint", { MaxTextSize = 25, MinTextSize = 13 }, coachTitle)
local coachBody = new("TextLabel", {
	Name = "Body",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(CX, 52),
	Size = UDim2.fromOffset(COACH_W - CX - 16, 40),
	FontFace = BODY,
	TextColor3 = INK_TEXT,
	TextScaled = true,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
	ZIndex = 33,
}, coachBodyFrame)
new("UITextSizeConstraint", { MaxTextSize = 16, MinTextSize = 11 }, coachBody)
local coachHint = new("TextLabel", {
	Name = "Hint",
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(CX, COACH_H - 40),
	Size = UDim2.fromOffset(COACH_W - CX - 150, 28),
	FontFace = FONT,
	TextColor3 = PAL.gold[2],
	TextScaled = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	ZIndex = 33,
}, coachBodyFrame)
new("UITextSizeConstraint", { MaxTextSize = 15, MinTextSize = 10 }, coachHint)
-- NEXT: a lime studded button with a lip, like every pressable thing in the kit
local nextButton = new("TextButton", {
	Name = "Next",
	Text = "",
	AutoButtonColor = false,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromOffset(COACH_W - 14 - 63, COACH_H - 30),
	Size = UDim2.fromOffset(126, 46),
	BackgroundColor3 = PAL.green[3],
	ZIndex = 34,
}, coachBodyFrame)
corner(nextButton, 12)
ink(nextButton, 4)
local nextFace = new("Frame", { Name = "Face", Size = UDim2.new(1, 0, 1, -5), ZIndex = 34 }, nextButton)
corner(nextFace, 11)
paint(nextFace, PAL.green)
studs(nextFace, Vector2.new(48, 48), 0.6, 11)
local nextLabel = words(nextFace, "Label", {
	Text = "NEXT",
	Size = UDim2.new(1, -12, 1, -8),
	Position = UDim2.fromOffset(6, 4),
	ZIndex = 35,
}, 3)
new("UITextSizeConstraint", { MaxTextSize = 24 }, nextLabel)
local nextPop = new("UIScale", {}, nextButton)
nextButton.MouseEnter:Connect(function()
	if nextButton.Interactable then
		TweenService:Create(nextPop, TweenInfo.new(0.1), { Scale = 1.06 }):Play()
	end
end)
nextButton.MouseLeave:Connect(function()
	TweenService:Create(nextPop, TweenInfo.new(0.1), { Scale = 1 }):Play()
end)
nextButton.MouseButton1Down:Connect(function()
	if nextButton.Interactable then
		TweenService:Create(nextPop, TweenInfo.new(0.05), { Scale = 0.94 }):Play()
		UISound.Play("Click")
	end
end)
nextButton.MouseButton1Up:Connect(function()
	TweenService:Create(nextPop, TweenInfo.new(0.1), { Scale = 1 }):Play()
end)
local function setNextEnabled(enabled)
	nextButton.Interactable = enabled
	paint(nextFace, enabled and PAL.green or { hex("BDBDBD"), hex("9A9A9A") })
	nextButton.BackgroundColor3 = enabled and PAL.green[3] or hex("5E5E5E")
end
-- pointer bob + ring breathing for the tour
task.spawn(function()
	local t = 0
	while not stopped do
		t += task.wait(1 / 30)
		if focusFrame.Visible and not reduced() then
			local bounce = math.abs(math.sin(t * 3.4))
			tapPointer.Position = UDim2.new(0.5, 0, 0, -6 - bounce * 10)
			focusGold.Transparency = 0.25 * (0.5 + 0.5 * math.sin(t * 4))
		elseif focusFrame.Visible then
			tapPointer.Position = UDim2.new(0.5, 0, 0, -6)
		end
	end
end)
local tourPanel, originalPanelPosition = nil, nil
local panelLift = 0
local function restoreTourPanel()
	if tourPanel and tourPanel.Parent and originalPanelPosition then
		tourPanel.Position = originalPanelPosition
	end
	tourPanel = nil
	originalPanelPosition = nil
	panelLift = 0
end
local nextAction = nil
local lastAckAt, lastAckStep = -math.huge, nil
local viewedTarget, viewedSince = nil, 0
local coachShownStep
local function isUiVisible(guiObject)
	if
		not guiObject
		or not guiObject:IsA("GuiObject")
		or guiObject.AbsoluteSize.X <= 0
		or guiObject.AbsoluteSize.Y <= 0
	then
		return false
	end
	local ancestor = guiObject
	while ancestor and ancestor ~= playerGui do
		if ancestor:IsA("GuiObject") and not ancestor.Visible then
			return false
		end
		if ancestor:IsA("ScreenGui") and not ancestor.Enabled then
			return false
		end
		ancestor = ancestor.Parent
	end
	return ancestor == playerGui
end
-- Reports a tour action to the server, at most once per second per step (the server ignores
-- anything that does not match the current TutorialTourStage).
local function acknowledge(action)
	if lastAckStep == currentStep and os.clock() - lastAckAt < 1 then
		return
	end
	lastAckAt = os.clock()
	lastAckStep = currentStep
	tourRemote:FireServer(action)
end
table.insert(
	connections,
	nextButton.Activated:Connect(function()
		if nextAction and nextButton.Interactable and isUiVisible(viewedTarget) then
			acknowledge(nextAction)
		end
	end)
)
-- Step 9: open Plot (auto-acknowledged once open). Step 10: open the Upgrades page (auto-acknowledged).
-- Steps 11/12: look at Temple / Incubator upgrades, then press NEXT / GOT IT (enabled after 0.8 s of viewing).
-- Until the right panel is open, the focus ring points at the button that opens it.
local function updateTour()
	clearTarget()
	card.Visible = false
	tourCanvas.Visible = true
	gui.Enabled = true
	hasShownGuide = true
	local gameMenus = playerGui:FindFirstChild("GameMenus")
	gui.DisplayOrder = math.max(65, gameMenus and gameMenus.DisplayOrder + 2 or 65)
	local canvasSize = tourCanvas.AbsoluteSize
	local isCompact = canvasSize.Y < 500
	coachFit.Scale = math.clamp(math.min((canvasSize.X - 20) / COACH_W, 0.8 * HudScale.For(canvasSize) + 0.1), 0.5, 1)
	coachCard.Position = UDim2.new(0.5, 0, 1, isCompact and -4 or -12)
	local plotPanel = gameMenus and gameMenus:FindFirstChild("Plot")
	local isPlotOpen = isUiVisible(plotPanel)
	local currentPage = isPlotOpen and plotPanel:GetAttribute("Page")
	local livePanel = plotPanel and plotPanel:FindFirstChild("Live")
	local wantedTarget
	local stepInfo = Guide.Steps[currentStep]
	if coachShownStep ~= currentStep then
		local look = LOOK[currentStep] or LOOK[9]
		paint(coachTile, look[1])
		paint(coachChip, look[1])
		setCoachIcon(look[2])
		coachChipLabel.Text = "STEP " .. currentStep .. " OF " .. TOTAL
		pop(coachPop, coachShownStep and 0.88 or 0.8)
		if coachShownStep then
			UISound.Play("Success", 1.1, 0.3)
		end
		coachShownStep = currentStep
	end
	coachTitle.Text = stepInfo.title
	coachBody.Text = stepInfo.body
	coachHint.Text = "Tap the glowing button"
	nextButton.Visible = false
	nextAction = nil
	if not isPlotOpen then
		local leftMenu = gameMenus and gameMenus:FindFirstChild("LeftMenu")
		wantedTarget = leftMenu and leftMenu:FindFirstChild("PlotButton", true)
		coachBody.Text = "You can add more upgrades to your plot. Press Plot to find them."
	elseif currentStep == 9 then
		acknowledge("PlotOpened")
	elseif currentPage ~= "upgrades" and currentPage ~= "figma" then
		-- Only the legacy tabbed Plot panel has an Upgrades tab; the current "figma" layout shows the
		-- upgrade rows on the same page, so it counts as the Upgrades page already being open.
		wantedTarget = livePanel and livePanel:FindFirstChild("UpgradesTab", true)
		coachBody.Text = "Press Upgrades to see your temple and incubator upgrades."
	elseif currentStep == 10 then
		acknowledge("UpgradesOpened")
	else
		wantedTarget = livePanel
			and livePanel:FindFirstChild(currentStep == 11 and "TempleUpgrades" or "IncubatorUpgrades", true)
		nextAction = currentStep == 11 and "TempleSeen" or "IncubatorsSeen"
		nextLabel.Text = currentStep == 11 and "NEXT" or "GOT IT!"
		nextButton.Visible = isUiVisible(wantedTarget)
		coachHint.Text = "No purchase needed"
	end
	if wantedTarget ~= viewedTarget then
		viewedTarget = wantedTarget
		viewedSince = os.clock()
	end
	setNextEnabled(nextButton.Visible and os.clock() - viewedSince >= 0.8)
	focusFrame.Visible = isUiVisible(wantedTarget)
	-- the TAP! pointer only on buttons, not on the big rows you just look at
	tapPointer.Visible = nextAction == nil
	-- On short screens, lift the menu only enough to keep the highlighted row above the coach.
	if isPlotOpen then
		if tourPanel ~= plotPanel then
			restoreTourPanel()
			tourPanel = plotPanel
			originalPanelPosition = plotPanel.Position
		end
		local lift = 0
		if isCompact and focusFrame.Visible and wantedTarget:IsDescendantOf(plotPanel) then
			local rowBottom = wantedTarget.AbsolutePosition.Y + wantedTarget.AbsoluteSize.Y + panelLift
			local topRoom = math.max(0, plotPanel.AbsolutePosition.Y + panelLift - tourCanvas.AbsolutePosition.Y - 4)
			lift = math.clamp(rowBottom - coachCard.AbsolutePosition.Y + 10, 0, topRoom)
		end
		panelLift = lift
		plotPanel.Position = originalPanelPosition + UDim2.fromOffset(0, -lift)
	else
		restoreTourPanel()
	end
	if focusFrame.Visible then
		local offset = wantedTarget.AbsolutePosition - tourCanvas.AbsolutePosition
		focusFrame.Position = UDim2.fromOffset(offset.X - 5, offset.Y - 5)
		focusFrame.Size = UDim2.fromOffset(wantedTarget.AbsoluteSize.X + 10, wantedTarget.AbsoluteSize.Y + 10)
	end
end

-- ===== 7. Finish and update loop =====
-- Runs once: tears down the world guide and shows a 4 s "ready" card (only if the guide was ever shown).
local function finish()
	if stopped then
		return
	end
	stopped = true
	clearTarget()
	worldFolder:Destroy()
	tourCanvas.Visible = false
	gui.DisplayOrder = 55
	restoreTourPanel()
	if footAttachment then
		footAttachment:Destroy()
		footAttachment = nil
	end
	if goalAttachment then
		goalAttachment:Destroy()
		goalAttachment = nil
	end
	for _, connection in connections do
		connection:Disconnect()
	end
	if hasShownGuide then
		gui.Enabled = true
		card.Visible = true
		fitToScreen()
		shownStep = nil
		showStep(TOTAL + 1, "You're ready to grow!", "Catch more eggs, hatch stronger characters and unlock more podiums.")
		paint(tile, PAL.green)
		paint(chip, PAL.green)
		setTileIcon(ICON.trophy)
		chipLabel.Text = "TUTORIAL DONE!"
		setProgress(TOTAL + 1)
		setDistance("here", "Upgrades: Plot")
		-- light rays behind the trophy
		if not reduced() then
			local rays = new("Frame", {
				Name = "Rays",
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(150, 150),
				ZIndex = 4,
			}, tile)
			for i = 1, 6 do
				local beam = new("Frame", {
					BackgroundColor3 = WHITE,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, 0, 0, 14),
					Rotation = (i - 1) * 30,
					ZIndex = 4,
				}, rays)
				local k = NumberSequenceKeypoint.new
				new("UIGradient", { Transparency = NumberSequence.new({ k(0, 1), k(0.35, 0.6), k(0.5, 0.25), k(0.65, 0.6), k(1, 1) }) }, beam)
			end
			TweenService:Create(rays, TweenInfo.new(6, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
		end
		UISound.Play("Success", 1, 0.55)
		pop(cardPop, 0.7)
		task.delay(4, function()
			if reduced() then
				gui:Destroy()
				return
			end
			TweenService:Create(cardPop, TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.6 }):Play()
			task.wait(0.18)
			gui:Destroy()
		end)
	else
		gui:Destroy()
	end
end
-- Guide update, throttled to every 0.2 s.
local elapsed = 0
table.insert(
	connections,
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.2 then
			return
		end
		elapsed = 0
		if player:GetAttribute("TutorialCompleted") == true then
			finish()
			return
		end
		local rootPart = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		local loadingScreen = playerGui:FindFirstChild("HatchLoading")
			or playerGui:FindFirstChild("LaunchLoadingScreen")
		local isArriving = player:GetAttribute("JoinArrivalStarted") and not player:GetAttribute("JoinArrivalFinished")
		local isReady = player:GetAttribute("TutorialDataReady")
			and rootPart
			and humanoid
			and humanoid.Health > 0
			and not loadingScreen
			and not isArriving
		if not isReady then
			gui.Enabled = false
			tourCanvas.Visible = false
			restoreTourPanel()
			clearTarget()
			return
		end
		-- isRevealing: Guide reports the hatch reveal is playing; the guide stays hidden meanwhile.
		local newStep, newTarget, note, isRevealing = Guide.Resolve(player)
		if newStep > #Guide.Steps then
			finish()
			return
		end
		if newStep ~= currentStep or newTarget ~= currentTarget then
			clearTarget()
			currentStep = newStep
			currentTarget = newTarget
		end
		gui:SetAttribute("Step", currentStep)
		if currentStep >= 9 then
			updateTour()
			return
		end
		tourCanvas.Visible = false
		gui.DisplayOrder = 55
		gui.Enabled = not isRevealing and not hatchCameraActive()
		objectiveHighlight.Enabled = false
		destinationMarker.Enabled = false
		if isRevealing or hatchCameraActive() then
			hideTrail()
			return
		end
		hasShownGuide = true
		local stepInfo = Guide.Steps[currentStep]
		card.Visible = not isMenuOpen()
		fitToScreen()
		showStep(currentStep, stepInfo.title, note or stepInfo.body)
		if isMenuOpen() then
			hideTrail()
			return
		end
		if not currentTarget or not currentTarget.Parent then
			setDistance("wait", "Finding your goal...")
			hideTrail()
			return
		end
		objectiveHighlight.Adornee = currentTarget
		objectiveHighlight.Enabled = true
		destinationMarker.Adornee = currentTarget
		if markerCaption.Text ~= stepInfo.marker then
			markerCaption.Text = stepInfo.marker
			setMarkerIcon((LOOK[currentStep] or LOOK[1])[2])
			pop(markerPop, 0.6)
		end
		local distanceToTarget = (currentTarget.Position - rootPart.Position).Magnitude
		destinationMarker.Enabled = distanceToTarget > 7 and stepInfo.marker ~= "" and not hasInteractionCard(currentTarget)
		if distanceToTarget > 7 then
			setDistance("far", math.floor(distanceToTarget) .. " studs away")
		elseif currentStep == 4 then
			setDistance("wait", "Incubating...")
		else
			setDistance("here", "You're here!")
		end
		if distanceToTarget <= 7 then
			hideTrail()
			return
		end
		ensureFoot(rootPart)
		ensureGoal(currentTarget)
		guideBeam.Enabled = true
	end)
)
table.insert(
	connections,
	player:GetAttributeChangedSignal("TutorialCompleted"):Connect(function()
		if player:GetAttribute("TutorialCompleted") then
			finish()
		end
	end)
)
-- ===== 8. Cleanup =====
gui.Destroying:Connect(function()
	restoreTourPanel()
	stopped = true
	for _, connection in connections do
		connection:Disconnect()
	end
	if worldFolder.Parent then
		worldFolder:Destroy()
	end
	if footAttachment then
		footAttachment:Destroy()
		footAttachment = nil
	end
	if goalAttachment then
		goalAttachment:Destroy()
		goalAttachment = nil
	end
end)
-- parent last, so every look is in place before other scripts see the gui
gui.Parent = playerGui
