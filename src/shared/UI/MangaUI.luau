-- ReplicatedStorage.MangaUI  (ModuleScript, client)
-- The game's manga page look: black ink, white paper, halftone dots, red hits. Every menu builds from these
-- pieces so they stay one family. Sharp corners, solid black outlines, hard black offset shadows only: no
-- rounded corners, gloss or soft gradients. Characters are the only full colour on the page.
-- Art is drawn by assets/ui/manga/make_art.py (no outside art) and uploaded by upload_art.py.
-- Every GuiObject made here carries NoSkin, so SharpUI and FigmaSkin leave it alone.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local MangaUI = {}

MangaUI.Ink = Color3.new(0, 0, 0)
MangaUI.Paper = Color3.new(1, 1, 1)
MangaUI.Red = Color3.fromRGB(224, 18, 42)
MangaUI.Grey = Color3.fromRGB(205, 205, 205)
MangaUI.Dim = Color3.fromRGB(96, 96, 96)

MangaUI.Display = Font.new("rbxasset://fonts/families/Bangers.json")
MangaUI.Body = Font.new("rbxasset://fonts/families/ComicNeueAngular.json", Enum.FontWeight.Bold)

MangaUI.Art = {
	Burst = "rbxassetid://88316292349108",
	Brush = "rbxassetid://114184572125924",
	Halftone = "rbxassetid://138937872818165",
	Icons = "rbxassetid://113242894736940",
	Speed = "rbxassetid://85077289875839",
	ToneCorner = "rbxassetid://111684220206458",
	ToneEdge = "rbxassetid://100876425777371",
	PageFeatured = "rbxassetid://119090823283093",
	PageBoosts = "rbxassetid://81086755218862",
	PagePasses = "rbxassetid://140696858563912",
	PageCash = "rbxassetid://99425691378910",
}

-- atlas cells, 128 px, left to right (same order as ICONS in make_art.py)
local ICON_ORDER = {
	"home", "temple", "book", "scroll", "bag", "gift", "gear", "coin",
	"star", "bolt", "ticket", "calendar", "clock", "lock", "check", "cross",
	"egg", "crown", "flame", "moon", "search", "up", "cash", "people",
	"hatch", "bell", "chat", "note", "plus", "drop", "sword",
}
local ICON_CELL = 128
local ICONS = {}
for index, name in ICON_ORDER do
	ICONS[name] = Vector2.new((index - 1) % 8 * ICON_CELL, (index - 1) // 8 * ICON_CELL)
end

function MangaUI.rect(instance, r)
	instance.Position = UDim2.fromOffset(r[1], r[2])
	instance.Size = UDim2.fromOffset(r[3], r[4])
end

function MangaUI.new(className, name, parent, zIndex)
	local instance = Instance.new(className)
	instance.Name = name
	if instance:IsA("GuiObject") then
		instance.BackgroundTransparency = 1
		instance.BorderSizePixel = 0
		instance.ZIndex = zIndex or 10
		instance:SetAttribute("NoSkin", true)
	end
	instance.Parent = parent
	return instance
end

function MangaUI.fill(parent, name, r, color, zIndex)
	local frame = MangaUI.new("Frame", name, parent, zIndex)
	frame.BackgroundTransparency = 0
	frame.BackgroundColor3 = color
	MangaUI.rect(frame, r)
	return frame
end

-- A flat inked box: black shadow (optional), black border, flat fill. Returns the fill frame; children go in it.
-- r is the outer box without its shadow.
function MangaUI.box(parent, name, r, options)
	options = options or {}
	local zIndex, border, shadow = options.z or 10, options.border or 4, options.shadow or 0
	local holder = MangaUI.new("Frame", name, parent, zIndex)
	MangaUI.rect(holder, r)
	if shadow > 0 then
		MangaUI.fill(holder, "Shadow", { shadow, shadow, r[3], r[4] }, MangaUI.Ink, zIndex)
	end
	MangaUI.fill(holder, "Border", { 0, 0, r[3], r[4] }, MangaUI.Ink, zIndex)
	return MangaUI.fill(
		holder,
		"Fill",
		{ border, border, r[3] - border * 2, r[4] - border * 2 },
		options.fill or MangaUI.Paper,
		zIndex
	),
		holder
end

function MangaUI.label(parent, name, text, r, size, color, zIndex, options)
	options = options or {}
	local label = MangaUI.new("TextLabel", name, parent, zIndex)
	label.FontFace = options.font or MangaUI.Display
	label.Text = text
	label.TextColor3 = color or MangaUI.Ink
	label.TextXAlignment = options.alignX or Enum.TextXAlignment.Center
	label.TextYAlignment = options.alignY or Enum.TextYAlignment.Center
	label.TextWrapped = options.wrap == true
	label.TextScaled = true
	local limit = Instance.new("UITextSizeConstraint")
	limit.MaxTextSize = size
	limit.Parent = label
	MangaUI.rect(label, r)
	if options.stroke then
		local stroke = Instance.new("UIStroke")
		stroke.Color = options.strokeColor or MangaUI.Ink
		stroke.Thickness = options.stroke
		stroke.LineJoinMode = Enum.LineJoinMode.Miter
		stroke.Parent = label
	end
	return label
end

-- Body text: small lettering for sentences (the display face is for shouting)
function MangaUI.body(parent, name, text, r, size, color, zIndex, options)
	options = options or {}
	options.font = MangaUI.Body
	if options.wrap == nil then
		options.wrap = true
	end
	return MangaUI.label(parent, name, text, r, size, color, zIndex, options)
end

-- Big shouted text with a hard offset shadow behind it. Returns the front label.
function MangaUI.shout(parent, name, text, r, size, color, zIndex, options)
	options = options or {}
	local offset = options.offset or 5
	local back = table.clone(options)
	back.stroke = nil
	MangaUI.label(
		parent,
		name .. "Shadow",
		text,
		{ r[1] + offset, r[2] + offset, r[3], r[4] },
		size,
		options.shadowColor or MangaUI.Ink,
		zIndex,
		back
	)
	return MangaUI.label(parent, name, text, r, size, color, zIndex, options)
end

function MangaUI.icon(parent, name, r, zIndex)
	local image = MangaUI.new("ImageLabel", "Icon_" .. name, parent, zIndex)
	image.Image = MangaUI.Art.Icons
	image.ImageRectOffset = ICONS[name] or ICONS.star
	image.ImageRectSize = Vector2.new(ICON_CELL, ICON_CELL)
	MangaUI.rect(image, r)
	return image
end

function MangaUI.image(parent, name, art, r, zIndex)
	local image = MangaUI.new("ImageLabel", name, parent, zIndex)
	image.Image = MangaUI.Art[art]
	MangaUI.rect(image, r)
	return image
end

-- Flat screen-tone dots across a rectangle
function MangaUI.tone(parent, name, r, zIndex, transparency)
	local image = MangaUI.image(parent, name, "Halftone", r, zIndex)
	image.ScaleType = Enum.ScaleType.Tile
	image.TileSize = UDim2.fromOffset(28, 28)
	image.ImageTransparency = transparency or 0.55
	return image
end

-- A rubber stamp slapped over a card (OWNED, MAXED, CLAIMED)
function MangaUI.stamp(parent, text, r, zIndex)
	local inner, holder = MangaUI.box(parent, "Stamp", r, { fill = MangaUI.Paper, z = zIndex, border = 5 })
	inner.BackgroundColor3 = MangaUI.Paper
	holder.Rotation = -6
	holder.Border.BackgroundColor3 = MangaUI.Red
	MangaUI.label(inner, "Text", text, { 6, 2, r[3] - 22, r[4] - 14 }, r[4], MangaUI.Red, zIndex)
	return holder
end

-- Pressable slab: a face sitting on a hard shadow; pressing pushes the face into the shadow.
-- options = { text, size, icon?, style = "go"|"plain"|"ink"|"off", z, shadow, onActivate }
-- style "off" has no shadow and cannot be pressed: it needs a word, never colour alone.
local STYLES = {
	go = { fill = MangaUI.Red, text = MangaUI.Paper, stroke = 2 },
	plain = { fill = MangaUI.Paper, text = MangaUI.Ink },
	ink = { fill = MangaUI.Ink, text = MangaUI.Paper },
	off = { fill = MangaUI.Grey, text = MangaUI.Dim },
}

function MangaUI.button(parent, name, r, options)
	local zIndex = options.z or 12
	local style = STYLES[options.style or "plain"]
	local pressable = options.style ~= "off" and options.onActivate ~= nil
	local depth = pressable and (options.shadow or 6) or 0
	local holder = MangaUI.new("Frame", name, parent, zIndex)
	MangaUI.rect(holder, r)
	if depth > 0 then
		MangaUI.fill(holder, "Shadow", { depth, depth, r[3], r[4] }, MangaUI.Ink, zIndex)
	end
	local face = MangaUI.fill(holder, "Face", { 0, 0, r[3], r[4] }, MangaUI.Ink, zIndex)
	local border = options.border or 4
	local fill = MangaUI.fill(
		face,
		"Fill",
		{ border, border, r[3] - border * 2, r[4] - border * 2 },
		style.fill,
		zIndex
	)
	local inset = 0
	if options.icon then
		local iconSize = options.iconSize or math.min(r[4] - 16, 56)
		MangaUI.icon(fill, options.icon, { 8, (r[4] - border * 2 - iconSize) / 2, iconSize, iconSize }, zIndex)
		inset = iconSize + 6
	end
	local text = MangaUI.label(
		fill,
		"Text",
		options.text or "",
		{ 8 + inset, 2, r[3] - border * 2 - 16 - inset, r[4] - border * 2 - 4 },
		options.size or 34,
		style.text,
		zIndex,
		{ stroke = style.stroke }
	)
	local hit = MangaUI.new("TextButton", "Hit", holder, zIndex + 1)
	hit.Text = ""
	hit.AutoButtonColor = false
	hit.Size = UDim2.fromScale(1, 1)
	hit.Active = pressable
	hit.Selectable = pressable
	if pressable then
		local pressed = UDim2.fromOffset(depth - 2, depth - 2)
		local press = TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local release = TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		hit.MouseButton1Down:Connect(function()
			TweenService:Create(face, press, { Position = pressed }):Play()
		end)
		local function up()
			TweenService:Create(face, release, { Position = UDim2.fromOffset(0, 0) }):Play()
		end
		hit.MouseButton1Up:Connect(up)
		hit.MouseLeave:Connect(up)
		hit.Activated:Connect(function()
			local sound = ReplicatedStorage:FindFirstChild("UISound")
			if sound then
				pcall(function()
					require(sound).Play("Click")
				end)
			end
			options.onActivate()
		end)
	end
	return { Root = holder, Face = face, Fill = fill, Text = text, Hit = hit }
end

-- Level squares: filled red = owned levels, the count is also written next to them by the caller
function MangaUI.pips(parent, x, y, size, gap, level, maxLevel, zIndex, emptyColor)
	for index = 1, maxLevel do
		local fill = MangaUI.box(
			parent,
			"Pip" .. index,
			{ x + (index - 1) * (size + gap), y, size, size },
			{ fill = index <= level and MangaUI.Red or emptyColor or MangaUI.Paper, z = zIndex, border = 3 }
		)
		fill.Name = "PipFill"
	end
end

-- A progress bar: black track, red fill, sharp ends
function MangaUI.bar(parent, name, r, progress, zIndex, color)
	local fill = MangaUI.box(parent, name, r, { fill = MangaUI.Paper, z = zIndex, border = 3 })
	local amount = math.clamp(progress or 0, 0, 1)
	local bar = MangaUI.fill(fill, "Bar", { 0, 0, 0, r[4] - 6 }, color or MangaUI.Red, zIndex)
	bar.Size = UDim2.new(amount, 0, 1, 0)
	return fill, bar
end

-- The panel's own skin goes away and its Close button becomes an invisible hit-box over `closeRect`
-- (canvas pixels). Same job as MenuArt.useClose, for canvases that do not fill the art.
local function takeOverPanel(panel, canvasSize, closeRect)
	for _, name in { "CleanSkin", "CleanBase", "FigmaWindow" } do
		local child = panel:FindFirstChild(name)
		if child and child:IsA("GuiObject") then
			child.Visible = false
		end
	end
	if panel:IsA("ImageLabel") then
		panel.ImageTransparency = 1
	end
	panel.BackgroundTransparency = 1
	local closeButton = panel:FindFirstChild("Close")
	if not closeButton then
		return
	end
	if not closeRect then
		closeButton.Visible = false
		return
	end
	closeButton.AnchorPoint = Vector2.zero
	closeButton.Position = UDim2.fromScale(closeRect[1] / canvasSize.X, closeRect[2] / canvasSize.Y)
	closeButton.Size = UDim2.fromScale(closeRect[3] / canvasSize.X, closeRect[4] / canvasSize.Y)
	closeButton.BackgroundTransparency = 1
	closeButton.ZIndex = 30
	for _, descendant in closeButton:GetDescendants() do
		if descendant:IsA("GuiObject") then
			descendant.Visible = false
		elseif descendant:IsA("UIStroke") then
			descendant.Enabled = false
		end
	end
	if closeButton:IsA("ImageButton") then
		closeButton.ImageTransparency = 1
	elseif closeButton:IsA("TextButton") then
		closeButton.TextTransparency = 1
	end
end

MangaUI.Canvas = Vector2.new(1200, 620) -- every menu window; MenuLogic gives its panels this aspect ratio
MangaUI.AspectRatio = MangaUI.Canvas.X / MangaUI.Canvas.Y
local CLOSE = { 1200 - 72, -14, 86, 86 }

-- The window every menu shares: paper page, ink border, hard shadow, the close X.
-- Returns the canvas (draw on it in canvas pixels) and a stop function for the view's Destroy.
-- options = { name, title?, close = false to leave the X out }
function MangaUI.window(panel, layer, options)
	options = options or {}
	local size = MangaUI.Canvas
	local closeRect = options.close ~= false and CLOSE or nil
	takeOverPanel(panel, size, closeRect)
	local canvas = MangaUI.new("Frame", options.name or "MangaCanvas", nil, 10)
	canvas.AnchorPoint = Vector2.new(0.5, 0.5)
	canvas.Position = UDim2.fromScale(0.5, 0.5)
	canvas.Size = UDim2.fromOffset(size.X, size.Y)
	local scale = Instance.new("UIScale")
	scale.Parent = canvas
	local function fit()
		scale.Scale = math.max(panel.Size.X.Offset, 1) / size.X
	end
	fit()
	local connection = panel:GetPropertyChangedSignal("Size"):Connect(fit)
	MangaUI.fill(canvas, "PageShadow", { 12, 12, size.X, size.Y }, MangaUI.Ink, 10)
	MangaUI.fill(canvas, "PageBorder", { 0, 0, size.X, size.Y }, MangaUI.Ink, 10)
	MangaUI.fill(canvas, "Paper", { 6, 6, size.X - 12, size.Y - 12 }, MangaUI.Paper, 10)
	if closeRect then
		local fill = MangaUI.box(canvas, "CloseX", { CLOSE[1] + 8, CLOSE[2] + 8, 70, 70 }, {
			fill = MangaUI.Ink,
			z = 28,
			border = 4,
			shadow = 5,
		})
		MangaUI.icon(fill, "cross", { 8, 8, 46, 46 }, 28)
	end
	return canvas, function()
		connection:Disconnect()
	end
end

-- The left rail of a tabbed window: title block, then tabs. tabs = { { key, label, icon, alert? } }.
-- Returns the canvas x where the page starts.
function MangaUI.rail(canvas, title, tabs, selected, onTab, zIndex)
	zIndex = zIndex or 12
	local width = 212
	MangaUI.tone(canvas, "RailTone", { 6, 6, width - 6, 608 }, zIndex - 1, 0.7)
	MangaUI.fill(canvas, "RailEdge", { width, 6, 5, 608 }, MangaUI.Ink, zIndex)
	local head = MangaUI.fill(canvas, "Title", { 6, 6, width - 6, 100 }, MangaUI.Ink, zIndex)
	local brush = MangaUI.image(head, "Brush", "Brush", { -14, 8, width + 20, 84 }, zIndex)
	brush.ImageColor3 = MangaUI.Red
	MangaUI.shout(head, "TitleText", title, { 8, 12, width - 22, 76 }, 74, MangaUI.Paper, zIndex, { offset = 4 })
	local top, gap = 118, 8
	local height = (608 - top - gap * (#tabs - 1) - 4) / #tabs
	for index, tab in tabs do
		local y = top + (index - 1) * (height + gap)
		local active = tab.key == selected
		local button = MangaUI.button(canvas, "Tab_" .. tab.key, { 16, y, width - 30, height }, {
			text = tab.label,
			size = 32,
			icon = tab.icon,
			iconSize = 44,
			style = active and "ink" or "plain",
			z = zIndex + 1,
			shadow = active and 0 or 5,
			onActivate = function()
				onTab(tab.key)
			end,
		})
		button.Text.TextXAlignment = Enum.TextXAlignment.Left
		if active then
			local arrow = MangaUI.fill(canvas, "TabMark", { width - 14, y + 8, 12, height - 16 }, MangaUI.Red, zIndex + 2)
			arrow.BorderSizePixel = 0
		end
		if tab.alert then
			local fill = MangaUI.box(canvas, "Alert", { width - 46, y - 8, 36, 36 }, {
				fill = MangaUI.Red,
				z = zIndex + 3,
				border = 3,
			})
			MangaUI.label(fill, "Mark", "!", { 0, 0, 30, 30 }, 30, MangaUI.Paper, zIndex + 3)
		end
	end
	return width + 10
end

-- 1:02:03
function MangaUI.hms(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end

return MangaUI
