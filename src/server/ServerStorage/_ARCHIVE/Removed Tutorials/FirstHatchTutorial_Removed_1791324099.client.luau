local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local old = playerGui:FindFirstChild("FirstHatchGuide")
if old then old:Destroy() end

local COLORS = {
	panel = Color3.fromRGB(20, 30, 49),
	panel2 = Color3.fromRGB(27, 42, 67),
	panel3 = Color3.fromRGB(36, 53, 80),
	ink = Color3.fromRGB(246, 249, 255),
	muted = Color3.fromRGB(181, 194, 216),
	yellow = Color3.fromRGB(255, 203, 61),
	orange = Color3.fromRGB(255, 139, 50),
	blue = Color3.fromRGB(60, 153, 255),
	green = Color3.fromRGB(75, 220, 126),
	red = Color3.fromRGB(255, 91, 91),
	shadow = Color3.fromRGB(4, 8, 16),
}

local function addCorner(object, pixels)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, pixels)
	corner.Parent = object
	return corner
end

local function addStroke(object, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = object
	return stroke
end

local function addPadding(object, left, right, top, bottom)
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, left)
	padding.PaddingRight = UDim.new(0, right)
	padding.PaddingTop = UDim.new(0, top)
	padding.PaddingBottom = UDim.new(0, bottom)
	padding.Parent = object
	return padding
end

local function textLabel(parent, name, text, size, color, font)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextSize = size
	label.Font = font or Enum.Font.GothamMedium
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Parent = parent
	return label
end

local function makeButton(parent, name, text)
	local button = Instance.new("TextButton")
	button.Name = name
	button.AutoButtonColor = false
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 12
	button.TextColor3 = COLORS.ink
	button.BackgroundColor3 = COLORS.panel2
	button.BorderSizePixel = 0
	button.Parent = parent
	addCorner(button, 8)
	addStroke(button, Color3.fromRGB(76, 98, 132), 1, 0.25)
	return button
end

local gui = Instance.new("ScreenGui")
gui.Name = "FirstHatchGuide"
gui.ResetOnSpawn = false
gui.DisplayOrder = 60
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.IgnoreGuiInset = false
gui.Parent = playerGui

local helpShadow = Instance.new("Frame")
helpShadow.Name = "HelpShadow"
helpShadow.AnchorPoint = Vector2.new(1, 0)
helpShadow.Position = UDim2.new(1, -18, 0, 80)
helpShadow.Size = UDim2.fromOffset(154, 44)
helpShadow.BackgroundColor3 = COLORS.shadow
helpShadow.BackgroundTransparency = 0.45
helpShadow.BorderSizePixel = 0
helpShadow.Parent = gui
addCorner(helpShadow, 11)

local help = makeButton(gui, "HowToPlay", "?  HOW TO PLAY")
help.AnchorPoint = Vector2.new(1, 0)
help.Position = UDim2.new(1, -22, 0, 76)
help.Size = UDim2.fromOffset(154, 44)
help.BackgroundColor3 = COLORS.panel
addStroke(help, COLORS.yellow, 2, 0.05)

local helpAccent = Instance.new("Frame")
helpAccent.Name = "Accent"
helpAccent.Size = UDim2.fromOffset(7, 28)
helpAccent.Position = UDim2.fromOffset(8, 8)
helpAccent.BackgroundColor3 = COLORS.yellow
helpAccent.BorderSizePixel = 0
helpAccent.Parent = help
addCorner(helpAccent, 4)

local shadow = Instance.new("Frame")
shadow.Name = "CardShadow"
shadow.AnchorPoint = Vector2.new(0, 0.5)
shadow.Position = UDim2.new(0, 29, 0.52, 7)
shadow.Size = UDim2.fromOffset(392, 382)
shadow.BackgroundColor3 = COLORS.shadow
shadow.BackgroundTransparency = 0.35
shadow.BorderSizePixel = 0
shadow.Visible = false
shadow.Parent = gui
addCorner(shadow, 17)

local card = Instance.new("Frame")
card.Name = "QuestCard"
card.AnchorPoint = Vector2.new(0, 0.5)
card.Position = UDim2.new(0, 22, 0.52, 0)
card.Size = UDim2.fromOffset(392, 382)
card.BackgroundColor3 = COLORS.panel
card.BorderSizePixel = 0
card.Visible = false
card.ClipsDescendants = true
card.Parent = gui
addCorner(card, 16)
addStroke(card, Color3.fromRGB(76, 98, 132), 2, 0.15)

local scale = Instance.new("UIScale")
scale.Name = "ResponsiveScale"
scale.Parent = card
local shadowScale = Instance.new("UIScale")
shadowScale.Name = "ResponsiveScale"
shadowScale.Parent = shadow

local topAccent = Instance.new("Frame")
topAccent.Name = "TopAccent"
topAccent.Size = UDim2.new(1, 0, 0, 8)
topAccent.BackgroundColor3 = COLORS.yellow
topAccent.BorderSizePixel = 0
topAccent.Parent = card

local studs = Instance.new("Frame")
studs.Name = "BrickStuds"
studs.Position = UDim2.fromOffset(18, 16)
studs.Size = UDim2.fromOffset(116, 14)
studs.BackgroundTransparency = 1
studs.Parent = card
local studsLayout = Instance.new("UIListLayout")
studsLayout.FillDirection = Enum.FillDirection.Horizontal
studsLayout.Padding = UDim.new(0, 7)
studsLayout.Parent = studs
for index = 1, 6 do
	local stud = Instance.new("Frame")
	stud.Name = "Stud" .. index
	stud.Size = UDim2.fromOffset(13, 13)
	stud.BackgroundColor3 = Color3.fromRGB(52, 72, 104)
	stud.BorderSizePixel = 0
	stud.Parent = studs
	addCorner(stud, 7)
	addStroke(stud, Color3.fromRGB(84, 107, 143), 1, 0.25)
end

local minimize = makeButton(card, "Minimize", "—")
minimize.Position = UDim2.new(1, -74, 0, 13)
minimize.Size = UDim2.fromOffset(28, 28)
minimize.TextSize = 18

local close = makeButton(card, "Close", "×")
close.Position = UDim2.new(1, -40, 0, 13)
close.Size = UDim2.fromOffset(28, 28)
close.TextSize = 18

local header = textLabel(card, "Header", "FIRST HATCH QUEST", 12, COLORS.yellow, Enum.Font.GothamBold)
header.Position = UDim2.fromOffset(20, 42)
header.Size = UDim2.fromOffset(250, 22)

local loopStrip = Instance.new("Frame")
loopStrip.Name = "MainLoop"
loopStrip.Position = UDim2.fromOffset(20, 69)
loopStrip.Size = UDim2.fromOffset(352, 31)
loopStrip.BackgroundColor3 = Color3.fromRGB(14, 23, 39)
loopStrip.BorderSizePixel = 0
loopStrip.Parent = card
addCorner(loopStrip, 8)

local loopText = textLabel(loopStrip, "LoopText", "EGGS  ›  HATCH  ›  HEROES  ›  CASH  ›  UPGRADES", 10, COLORS.muted, Enum.Font.GothamBold)
loopText.Size = UDim2.fromScale(1, 1)
loopText.TextXAlignment = Enum.TextXAlignment.Center

local badgeShadow = Instance.new("Frame")
badgeShadow.Name = "BadgeShadow"
badgeShadow.Position = UDim2.fromOffset(24, 113)
badgeShadow.Size = UDim2.fromOffset(58, 58)
badgeShadow.BackgroundColor3 = COLORS.shadow
badgeShadow.BackgroundTransparency = 0.35
badgeShadow.BorderSizePixel = 0
badgeShadow.Parent = card
addCorner(badgeShadow, 12)

local badge = Instance.new("Frame")
badge.Name = "StepBadge"
badge.Position = UDim2.fromOffset(20, 109)
badge.Size = UDim2.fromOffset(58, 58)
badge.BackgroundColor3 = COLORS.yellow
badge.BorderSizePixel = 0
badge.Parent = card
addCorner(badge, 12)
addStroke(badge, Color3.fromRGB(255, 231, 140), 2, 0.1)

local badgeNumber = textLabel(badge, "Number", "1", 27, COLORS.panel, Enum.Font.GothamBlack)
badgeNumber.Size = UDim2.fromScale(1, 1)
badgeNumber.TextXAlignment = Enum.TextXAlignment.Center

local stepText = textLabel(card, "StepText", "STEP 1 OF 6", 10, COLORS.muted, Enum.Font.GothamBold)
stepText.Position = UDim2.fromOffset(94, 109)
stepText.Size = UDim2.fromOffset(230, 18)

local title = textLabel(card, "Title", "Find an egg", 22, COLORS.ink, Enum.Font.GothamBold)
title.Position = UDim2.fromOffset(94, 127)
title.Size = UDim2.fromOffset(278, 34)
title.TextTruncate = Enum.TextTruncate.AtEnd

local body = textLabel(card, "Body", "", 13, COLORS.muted, Enum.Font.GothamMedium)
body.Position = UDim2.fromOffset(20, 183)
body.Size = UDim2.fromOffset(352, 60)
body.TextWrapped = true
body.TextYAlignment = Enum.TextYAlignment.Top
body.LineHeight = 1.18

local action = Instance.new("Frame")
action.Name = "ActionBox"
action.Position = UDim2.fromOffset(20, 252)
action.Size = UDim2.fromOffset(352, 49)
action.BackgroundColor3 = COLORS.panel2
action.BorderSizePixel = 0
action.Parent = card
addCorner(action, 10)
local actionStroke = addStroke(action, COLORS.yellow, 2, 0.1)

local actionIcon = textLabel(action, "Arrow", "›", 27, COLORS.yellow, Enum.Font.GothamBlack)
actionIcon.Position = UDim2.fromOffset(13, 0)
actionIcon.Size = UDim2.fromOffset(25, 49)
actionIcon.TextXAlignment = Enum.TextXAlignment.Center

local actionText = textLabel(action, "ActionText", "", 12, COLORS.ink, Enum.Font.GothamBold)
actionText.Position = UDim2.fromOffset(46, 0)
actionText.Size = UDim2.fromOffset(210, 49)

local distance = textLabel(action, "Distance", "", 10, COLORS.yellow, Enum.Font.GothamBold)
distance.AnchorPoint = Vector2.new(1, 0)
distance.Position = UDim2.new(1, -13, 0, 0)
distance.Size = UDim2.fromOffset(85, 49)
distance.TextXAlignment = Enum.TextXAlignment.Right

local progress = Instance.new("Frame")
progress.Name = "Progress"
progress.Position = UDim2.fromOffset(20, 319)
progress.Size = UDim2.fromOffset(352, 10)
progress.BackgroundTransparency = 1
progress.Parent = card
local progressLayout = Instance.new("UIListLayout")
progressLayout.FillDirection = Enum.FillDirection.Horizontal
progressLayout.Padding = UDim.new(0, 5)
progressLayout.Parent = progress
local segments = {}
for index = 1, 6 do
	local segment = Instance.new("Frame")
	segment.Name = "Step" .. index
	segment.Size = UDim2.fromOffset(54, 8)
	segment.BackgroundColor3 = Color3.fromRGB(54, 69, 94)
	segment.BorderSizePixel = 0
	segment.Parent = progress
	addCorner(segment, 4)
	segments[index] = segment
end

local footer = textLabel(card, "Footer", "The glowing marker shows where to go.", 10, COLORS.muted, Enum.Font.GothamMedium)
footer.Position = UDim2.fromOffset(20, 343)
footer.Size = UDim2.fromOffset(240, 22)

local finish = makeButton(card, "Finish", "GOT IT  ›")
finish.Position = UDim2.new(1, -118, 1, -40)
finish.Size = UDim2.fromOffset(98, 28)
finish.BackgroundColor3 = COLORS.green
finish.TextColor3 = COLORS.panel
finish.Visible = false

local miniShadow = Instance.new("Frame")
miniShadow.Name = "MiniShadow"
miniShadow.AnchorPoint = Vector2.new(0, 0.5)
miniShadow.Position = UDim2.new(0, 28, 0.52, 5)
miniShadow.Size = UDim2.fromOffset(286, 76)
miniShadow.BackgroundColor3 = COLORS.shadow
miniShadow.BackgroundTransparency = 0.4
miniShadow.BorderSizePixel = 0
miniShadow.Visible = false
miniShadow.Parent = gui
addCorner(miniShadow, 13)

local mini = Instance.new("TextButton")
mini.Name = "QuestMini"
mini.AnchorPoint = Vector2.new(0, 0.5)
mini.Position = UDim2.new(0, 22, 0.52, 0)
mini.Size = UDim2.fromOffset(286, 76)
mini.BackgroundColor3 = COLORS.panel
mini.BorderSizePixel = 0
mini.AutoButtonColor = false
mini.Text = ""
mini.Visible = false
mini.Parent = gui
addCorner(mini, 12)
addStroke(mini, COLORS.yellow, 2, 0.05)

local miniBadge = Instance.new("Frame")
miniBadge.Position = UDim2.fromOffset(10, 10)
miniBadge.Size = UDim2.fromOffset(54, 54)
miniBadge.BackgroundColor3 = COLORS.yellow
miniBadge.BorderSizePixel = 0
miniBadge.Parent = mini
addCorner(miniBadge, 10)
local miniNumber = textLabel(miniBadge, "Number", "1", 23, COLORS.panel, Enum.Font.GothamBlack)
miniNumber.Size = UDim2.fromScale(1, 1)
miniNumber.TextXAlignment = Enum.TextXAlignment.Center
local miniHeader = textLabel(mini, "Header", "CURRENT QUEST", 9, COLORS.yellow, Enum.Font.GothamBold)
miniHeader.Position = UDim2.fromOffset(77, 11)
miniHeader.Size = UDim2.fromOffset(180, 16)
local miniTitle = textLabel(mini, "Title", "", 14, COLORS.ink, Enum.Font.GothamBold)
miniTitle.Position = UDim2.fromOffset(77, 27)
miniTitle.Size = UDim2.fromOffset(190, 22)
miniTitle.TextTruncate = Enum.TextTruncate.AtEnd
local miniHint = textLabel(mini, "Hint", "CLICK TO EXPAND", 9, COLORS.muted, Enum.Font.GothamBold)
miniHint.Position = UDim2.fromOffset(77, 49)
miniHint.Size = UDim2.fromOffset(190, 15)

local highlight = Instance.new("Highlight")
highlight.Name = "TutorialTarget"
highlight.FillColor = COLORS.yellow
highlight.FillTransparency = 0.82
highlight.OutlineColor = COLORS.yellow
highlight.OutlineTransparency = 0
highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
highlight.Enabled = false
highlight.Parent = workspace

local marker = Instance.new("BillboardGui")
marker.Name = "TutorialMarker"
marker.Size = UDim2.fromOffset(196, 72)
marker.StudsOffsetWorldSpace = Vector3.new(0, 4.4, 0)
marker.AlwaysOnTop = true
marker.MaxDistance = 500
marker.Enabled = false
marker.Parent = gui

local markerFrame = Instance.new("Frame")
markerFrame.Name = "MarkerCard"
markerFrame.Size = UDim2.new(1, 0, 0, 47)
markerFrame.BackgroundColor3 = COLORS.panel
markerFrame.BackgroundTransparency = 0.04
markerFrame.BorderSizePixel = 0
markerFrame.Parent = marker
addCorner(markerFrame, 10)
addStroke(markerFrame, COLORS.yellow, 2, 0)

local markerDot = Instance.new("Frame")
markerDot.Position = UDim2.fromOffset(9, 9)
markerDot.Size = UDim2.fromOffset(29, 29)
markerDot.BackgroundColor3 = COLORS.yellow
markerDot.BorderSizePixel = 0
markerDot.Parent = markerFrame
addCorner(markerDot, 8)
local markerDotText = textLabel(markerDot, "Icon", "!", 17, COLORS.panel, Enum.Font.GothamBlack)
markerDotText.Size = UDim2.fromScale(1, 1)
markerDotText.TextXAlignment = Enum.TextXAlignment.Center

local markerText = textLabel(markerFrame, "Text", "", 11, COLORS.ink, Enum.Font.GothamBold)
markerText.Position = UDim2.fromOffset(47, 0)
markerText.Size = UDim2.fromOffset(140, 47)
markerText.TextXAlignment = Enum.TextXAlignment.Center
markerText.TextWrapped = true

local arrow = textLabel(marker, "Arrow", "▼", 24, COLORS.yellow, Enum.Font.GothamBlack)
arrow.Position = UDim2.new(0, 0, 0, 43)
arrow.Size = UDim2.new(1, 0, 0, 26)
arrow.TextXAlignment = Enum.TextXAlignment.Center

local steps = {
	{
		title = "Grab a river egg",
		body = "Follow the glowing marker to the river. Walk up to an egg and hold the interaction button to collect it.",
		action = "COLLECT A RIVER EGG",
		marker = "RIVER EGG",
		color = COLORS.blue,
	},
	{
		title = "Load your incubator",
		body = "Equip the egg from your hotbar, go to your plot's incubator, then choose Insert Egg.",
		action = "EQUIP EGG  →  INSERT",
		marker = "YOUR INCUBATOR",
		color = COLORS.orange,
	},
	{
		title = "Wait for incubation",
		body = "The chamber prepares your egg automatically. Watch the timer above the machine until it is ready.",
		action = "WAIT FOR THE TIMER",
		marker = "INCUBATING",
		color = COLORS.yellow,
	},
	{
		title = "Hatch the egg",
		body = "When the timer finishes, interact with the incubator again and press Hatch to start the reveal.",
		action = "PRESS HATCH",
		marker = "READY TO HATCH",
		color = COLORS.green,
	},
	{
		title = "Collect your hero",
		body = "After the reveal, collect the character from inside the open incubator. It will go into your hotbar.",
		action = "COLLECT CHARACTER",
		marker = "NEW CHARACTER",
		color = COLORS.blue,
	},
	{
		title = "Place it in your temple",
		body = "Equip the character and interact with an empty platform. Placed heroes automatically earn cash for you.",
		action = "EQUIP HERO  →  PLACE",
		marker = "EMPTY PLATFORM",
		color = COLORS.green,
	},
}

local step = 1
local active = true
local collapsed = false
local ready = false
local target
local chamber
local lastRenderedStep = 0

local function findTool(predicate)
	for _, container in ipairs({player:FindFirstChild("Backpack"), player.Character}) do
		if container then
			for _, object in ipairs(container:GetChildren()) do
				if object:IsA("Tool") and predicate(object) then
					return object
				end
			end
		end
	end
end

local function eggTool()
	return findTool(function(object)
		return object:GetAttribute("EggType") ~= nil and not object:GetAttribute("Hatched")
	end)
end

local function rewardTool()
	return findTool(function(object)
		return object:GetAttribute("Hatched") == true
	end)
end

local function ownedPlot()
	local plots = workspace:FindFirstChild("Plots")
	if not plots then return end
	for _, candidate in ipairs(plots:GetChildren()) do
		if candidate:GetAttribute("OwnerUserId") == player.UserId then
			return candidate
		end
	end
end

local function hasPlacedCharacter(plot)
	local slots = plot and plot:FindFirstChild("Slots")
	if not slots then return false end
	for _, slot in ipairs(slots:GetChildren()) do
		if slot:GetAttribute("Occupied") then
			return true
		end
	end
	return false
end

local function findChamber(plot)
	local chambers = plot and plot:FindFirstChild("Chambers")
	if not chambers then return end
	if chamber and chamber.Parent == chambers then return chamber end
	for _, machine in ipairs(chambers:GetChildren()) do
		if machine:GetAttribute("Status") ~= "Ready" then
			chamber = machine
			return machine
		end
	end
	chamber = chambers:FindFirstChild("Chamber1")
	return chamber
end

local function targetPart(object)
	if not object then return end
	if object:IsA("BasePart") then return object end
	return object:FindFirstChild("CollectAnchor", true)
		or object:FindFirstChild("EggPickupAnchor", true)
		or object:FindFirstChild("HatchButton", true)
		or object:FindFirstChildWhichIsA("BasePart", true)
end

local function clearTarget()
	target = nil
	highlight.Adornee = nil
	highlight.Enabled = false
	marker.Adornee = nil
	marker.Enabled = false
end

local function showTarget(object, caption)
	target = object
	local part = targetPart(object)
	local show = active and ready and part ~= nil and step <= #steps
	highlight.Adornee = object
	highlight.Enabled = show
	marker.Adornee = part
	marker.Enabled = show
	markerText.Text = caption
end

local function animateCard()
	scale.Scale = 0.92
	TweenService:Create(scale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()
end

local function render()
	gui:SetAttribute("Step", step)
	local complete = step > #steps
	finish.Visible = complete
	distance.Text = ""
	
	if complete then
		header.Text = "QUEST COMPLETE"
		header.TextColor3 = COLORS.green
		badge.BackgroundColor3 = COLORS.green
		badgeNumber.Text = "✓"
		stepText.Text = "YOU KNOW THE CORE LOOP"
		title.Text = "Build the strongest temple!"
		body.Text = "Keep collecting eggs and placing heroes to earn cash. Spend it to unlock more platforms, add incubators, and upgrade your temple."
		actionText.Text = "EGGS  →  HEROES  →  CASH  →  UPGRADES"
		actionText.Size = UDim2.fromOffset(285, 49)
		actionIcon.Text = "★"
		actionIcon.TextColor3 = COLORS.green
		actionStroke.Color = COLORS.green
		action.BackgroundColor3 = Color3.fromRGB(24, 62, 52)
		footer.Text = "Better eggs and more space make your temple stronger."
		miniNumber.Text = "✓"
		miniBadge.BackgroundColor3 = COLORS.green
		miniTitle.Text = "Tutorial complete"
		for _, segment in ipairs(segments) do segment.BackgroundColor3 = COLORS.green end
		clearTarget()
	else
		local data = steps[step]
		header.Text = "FIRST HATCH QUEST"
		header.TextColor3 = COLORS.yellow
		badge.BackgroundColor3 = data.color
		badgeNumber.Text = tostring(step)
		stepText.Text = string.format("STEP %d OF %d", step, #steps)
		title.Text = data.title
		body.Text = data.body
		actionText.Text = data.action
		actionText.Size = UDim2.fromOffset(210, 49)
		actionIcon.Text = "›"
		actionIcon.TextColor3 = data.color
		actionStroke.Color = data.color
		action.BackgroundColor3 = COLORS.panel2
		footer.Text = "The glowing marker shows where to go."
		miniNumber.Text = tostring(step)
		miniBadge.BackgroundColor3 = data.color
		miniTitle.Text = data.title
		for index, segment in ipairs(segments) do
			segment.BackgroundColor3 = index < step and COLORS.green or (index == step and data.color or Color3.fromRGB(54, 69, 94))
		end
	end
	
	if step ~= lastRenderedStep and card.Visible then
		animateCard()
	end
	lastRenderedStep = step
end

local function advance()
	if step <= #steps then
		step += 1
		render()
	end
end

local function hideGuide()
	active = false
	collapsed = false
	card.Visible = false
	shadow.Visible = false
	mini.Visible = false
	miniShadow.Visible = false
	clearTarget()
end

local function setCollapsed(value)
	collapsed = value
	card.Visible = ready and active and not collapsed
	shadow.Visible = card.Visible
	mini.Visible = ready and active and collapsed
	miniShadow.Visible = mini.Visible
	if not collapsed and card.Visible then animateCard() end
end

close.Activated:Connect(hideGuide)
finish.Activated:Connect(hideGuide)
minimize.Activated:Connect(function() setCollapsed(true) end)
mini.Activated:Connect(function() setCollapsed(false) end)

help.Activated:Connect(function()
	if active then
		setCollapsed(not collapsed)
	else
		step = 1
		chamber = nil
		active = true
		setCollapsed(false)
		render()
	end
end)

for _, button in ipairs({help, minimize, close, finish, mini}) do
	button.MouseEnter:Connect(function()
		TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = button == finish and Color3.fromRGB(102, 238, 148) or COLORS.panel3}):Play()
	end)
	button.MouseLeave:Connect(function()
		local normal = COLORS.panel2
		if button == help or button == mini then normal = COLORS.panel end
		if button == finish then normal = COLORS.green end
		TweenService:Create(button, TweenInfo.new(0.12), {BackgroundColor3 = normal}):Play()
	end)
end

render()

local elapsed = 0
local connection
connection = RunService.Heartbeat:Connect(function(deltaTime)
	elapsed += deltaTime
	if elapsed < 0.2 then return end
	elapsed = 0
	
	local camera = workspace.CurrentCamera
	if camera then
		local factor = math.min(1, (camera.ViewportSize.X - 28) / 410, (camera.ViewportSize.Y - 120) / 410)
		factor = math.max(0.70, factor)
		scale.Scale = factor
		shadowScale.Scale = factor
	end
	
	local loading = playerGui:FindFirstChild("AnimeEggPreloader") ~= nil or playerGui:FindFirstChild("LaunchLoadingScreen") ~= nil
	ready = not loading and player.Character ~= nil
	help.Visible = ready
	helpShadow.Visible = ready
	card.Visible = ready and active and not collapsed
	shadow.Visible = card.Visible
	mini.Visible = ready and active and collapsed
	miniShadow.Visible = mini.Visible
	
	if not ready or not active or step > #steps then return end
	
	local plot = ownedPlot()
	local hatchMachine = findChamber(plot)
	local state = hatchMachine and hatchMachine:GetAttribute("Status")
	
	marker.StudsOffsetWorldSpace = Vector3.new(0, 4.4 + math.sin(os.clock() * 2.4) * 0.18, 0)
	
	if state == "HatchReveal" or state == "Revealing" then
		card.Visible = false
		shadow.Visible = false
		marker.Enabled = false
		highlight.Enabled = false
		return
	end
	
	if step == 1 then
		if eggTool() or (state and state ~= "Ready") then
			advance()
			return
		end
		local river = workspace:FindFirstChild("WaterfallEggs")
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local best, bestDistance = nil, math.huge
		if river and root then
			for _, egg in ipairs(river:GetChildren()) do
				local part = targetPart(egg)
				if part then
					local currentDistance = (part.Position - root.Position).Magnitude
					if currentDistance < bestDistance then
						best = egg
						bestDistance = currentDistance
					end
				end
			end
		end
		showTarget(best, "COLLECT THIS EGG")
	elseif step == 2 then
		if state and state ~= "Ready" then
			advance()
			return
		end
		showTarget(hatchMachine, "INSERT YOUR EGG")
	elseif step == 3 then
		if state == "Loaded" or state == "HatchReveal" or state == "Revealing" or state == "AwaitingPickup" then
			advance()
			return
		end
		local cycleEnd = hatchMachine and hatchMachine:GetAttribute("CycleEnd")
		if cycleEnd then
			local seconds = math.max(0, math.ceil(cycleEnd - workspace:GetServerTimeNow()))
			actionText.Text = "INCUBATING..."
			distance.Text = tostring(seconds) .. "s LEFT"
		end
		showTarget(hatchMachine, "INCUBATING")
	elseif step == 4 then
		if state == "AwaitingPickup" or rewardTool() then
			advance()
			return
		end
		showTarget(hatchMachine, "PRESS HATCH")
	elseif step == 5 then
		if rewardTool() or hasPlacedCharacter(plot) then
			advance()
			return
		end
		local pickup = hatchMachine and (hatchMachine:FindFirstChild("EggPickupAnchor") or hatchMachine)
		showTarget(pickup, "COLLECT YOUR HERO")
	elseif step == 6 then
		if hasPlacedCharacter(plot) then
			advance()
			return
		end
		local emptyPlatform
		local slots = plot and plot:FindFirstChild("Slots")
		if slots then
			local ordered = slots:GetChildren()
			table.sort(ordered, function(a, b) return a.Name < b.Name end)
			for _, slot in ipairs(ordered) do
				if not slot:GetAttribute("Occupied") then
					emptyPlatform = slot:FindFirstChild("Platform")
					break
				end
			end
		end
		showTarget(emptyPlatform, "PLACE HERO HERE")
	end
	
	if step ~= 3 then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local part = targetPart(target)
		if part and root then
			distance.Text = tostring(math.floor((part.Position - root.Position).Magnitude)) .. " STUDS"
		else
			distance.Text = plot and "" or "FINDING PLOT..."
		end
	end
end)

gui.Destroying:Connect(function()
	if connection then connection:Disconnect() end
	if highlight then highlight:Destroy() end
end)
