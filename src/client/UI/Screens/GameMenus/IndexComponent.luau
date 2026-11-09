-- GameMenus.IndexComponent  (ModuleScript, client)
-- The Character Index in the Folk Stud look (2026-11-07): a white studded sheet, "INDEX" on the top border with the
-- game's index book hanging over the corner and a red X over the other corner. Season tabs on top, a white collection
-- bar with a gold fill, a search box and rarity pills, a scrolling grid of cards in their rarity colour (undiscovered
-- ones are dark with a black silhouette), a big detail card with light rays, the three collection chests, and the
-- Characters / Eggs / Mutations tabs sitting on the bottom border.
-- Display only: MenuLogic (RENDER.Index) reads the catalogue / discovered state and passes the actions as callbacks.
-- Typing in the search box filters the grid here, without a re-render. Same API and model as the atlas version:
--
--   local view = IndexComponent.new(panel, layer, model)
--   view:Destroy()
--
-- model = {
--   page = "Characters" | "Eggs" | "Mutations", onPage(page),
--   season = "Original" | "Halloween", onSeason(season), onWinter(),
--   collectionText, progress (0..1),
--   filters = { { key, selected } }, onFilter(key), search, onSearch(text),   (ignored on Mutations)
--   cards = { { id, name, rarity, image?, egg?, characterId?, discovered, selected, mutation?, badge?, subtitle? } },
--   onSelect(id),
--   selected = { name, rarity, image?, egg?, characterId?, obtain, badge?, status?, mutation? }?,
--   rewards = { { at, state = "locked" | "ready" | "claimed", onActivate } } x3,
--   scrollY, onScroll(y),
-- }
-- Old version: ServerStorage._ARCHIVE.IndexComponent_BeforeStud_2026-11-07
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local TweenService = game:GetService("TweenService")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.H
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local Config = require(script.Parent:WaitForChild("IndexConfig"))
local Atlas = require(script.Parent:WaitForChild("IndexAtlas"))
local MenuArt = require(ReplicatedStorage:WaitForChild("MenuArt"):WaitForChild("MenuArt"))

local CANVAS = Atlas.Canvas                 -- 1270 x 840: MenuLogic sizes the panel by this aspect
local CW, CH = CANVAS.X, CANVAS.Y
local Z = 10
local C = M.COLOR
local WHITE, BLACK, hex = H.WHITE, H.BLACK, H.hex
local GOLD = hex("FFC400")
local GOLD_TEXT = hex("FFE14D")
local DONE = { hex("8CF56A"), hex("3CCB3A"), hex("1A6E1E") }
local CLOSE = { CW - 40, -30, 74, 74 }
local INDEX_ICON = "rbxassetid://72680797337159"   -- FOLK red book (i_book), same as the rail

-- every rarity gets its own burning colour; undiscovered cards are dark
local SILVER = { hex("DDE7FF"), hex("8798D6"), hex("3F4C80") }
local RARITY = {
	Common = SILVER, Uncommon = C.leaf, Rare = C.azure, Epic = C.lilac, Legendary = C.mango,
	Limited = C.bubblegum, Mythic = C.coral, Secret = C.aqua, Locked = C.ink,
}
local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, hex("FF5A6E")), ColorSequenceKeypoint.new(0.25, hex("FFC43D")), ColorSequenceKeypoint.new(0.5, hex("8CF56A")),
	ColorSequenceKeypoint.new(0.75, hex("35A8FF")), ColorSequenceKeypoint.new(1, hex("B08CFF")),
})
local MUTATION = { Silver = SILVER, Gold = C.gold, Diamond = C.aqua, Rainbow = { RAINBOW, nil, hex("44228F") } }
local FILTER_WIDTH = { All = 70, Common = 112, Uncommon = 134, Rare = 86, Epic = 80, Legendary = 134 }

-- layout (canvas pixels)
local SEASON_Y, SEASON_H = 66, 58
local BAR = { 44, 140, CW - 88, 36 }
local TOOL_Y, TOOL_H = 190, 50
local GRID = { X = 44, Y = 252, W = 818, H = 532 }
local CARD_W, CARD_H, GAP, PAD = 190, 226, 12, 8
local DETAIL = { X = 880, Y = 252, W = 346, H = 370 }
local REWARDS = { X = 880, Y = 638, W = 346, H = 146 }
local PAGE_W, PAGE_H, PAGE_Y = 252, 62, CH - 34

local IndexComponent = {}
IndexComponent.__index = IndexComponent
IndexComponent.AspectRatio = CW / CH

---------------------------------------------------------------- building blocks
local function txt(parent, name, str, x, y, w, h, size, z, col, align, wrap)
	local l = H.new("TextLabel", { Name = name, BackgroundTransparency = 1, FontFace = M.FONT, Text = str or "", TextScaled = true, TextWrapped = wrap == true,
		TextColor3 = col or WHITE, TextXAlignment = align or Enum.TextXAlignment.Center, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z }, parent)
	H.new("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = 10 }, l)
	H.new("UIStroke", { Name = "UIStroke", Thickness = size >= 28 and 3.7 or (size >= 20 and 3 or 2.5), Color = BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, l)
	return l
end
-- an atlas piece (the game's own index icons), centred, fitted into a square
-- tighter crops where the atlas rect picked up bits of the next piece (measured on the sheet, 2026-11-07)
local TRIM = { IconEgg = { 868, 418, 29, 34 }, IconDna = { 481, 462, 34, 34 } }
local function icon(parent, name, pieceName, cx, cy, size, z)
	local info = Atlas.Pieces[pieceName]
	if not info then return nil end
	local r = TRIM[pieceName] or info.Rect
	local k = size / math.max(r[3], r[4])
	return H.new("ImageLabel", { Name = name, BackgroundTransparency = 1, Image = Config.Pieces, ImageRectOffset = Vector2.new(r[1], r[2]), ImageRectSize = Vector2.new(r[3], r[4]),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(r[3] * k, r[4] * k), ZIndex = z }, parent)
end
local function paint(f, pal)
	if typeof(pal[1]) == "ColorSequence" then return H.grad(f, pal[1]) end
	return H.grad(f, pal[1], pal[2])
end
-- a vivid card you read: gradient face, black outline, faint studs, hard shadow (and a light sweep when `shine`)
local function card(parent, name, x, y, w, h, pal, z, shine)
	H.shadow(parent, name, x, y, w, h, 18, z)
	local f = H.rect(parent, name, x, y, w, h, 18, z + 1, WHITE)
	paint(f, pal)
	H.ink(f, 4)
	H.studs(f, Vector2.new(48, 48), 0.84, 18, z + 1)
	if shine then H.shine(f, 18, z + 1) end
	return f
end
-- a pressable button; done = flat lime with no lip, no studs, no click
local function btn(parent, name, x, y, w, h, pal, word, size, z, onActivate, done)
	local b
	if done then
		b = H.button(parent, name, x, y, w, h, 12, DONE, z, { lip = 0, plain = true })
		b.AutoButtonColor = false
		b.Active = false
		b:SetAttribute("Pressable", nil)
	else
		b = H.button(parent, name, x, y, w, h, 12, pal, z, { lip = 5, studs = 0.7 })
		if onActivate then b.Activated:Connect(onActivate) end
	end
	txt(b, "Label", word, 6, 2, w - 12, h - (done and 4 or 9), size, b.ZIndex + 3)
	return b
end
local function goldOutline(f, thickness)
	local o = f:FindFirstChild("Outline")
	if o then
		o.Color = GOLD
		o.Thickness = thickness or 5
	end
end
-- a small dark pill with a word, its right edge at `right` (rarity / odds badges)
local function badge(parent, word, right, top, h, size, pal, z)
	local w = TextService:GetTextSize(word, size, Enum.Font.FredokaOne, Vector2.new(1000, 100)).X + 22
	local p = H.rect(parent, "Badge", right - w, top, w, h, 10, z, pal[3])
	H.ink(p, 2.5)
	local l = txt(p, "Text", word, 4, 1, w - 8, h - 2, size, z + 1)
	l.TextScaled = false
	l.TextSize = size
	return p
end
-- FigmaSkin restyles dark frames and buttons inside the menu panels: every piece of this window opts out
local function optOut(root)
	root:SetAttribute("NoSkin", true)
	root:SetAttribute("FS", true)
	for _, d in root:GetDescendants() do
		if d:IsA("GuiObject") then
			d:SetAttribute("NoSkin", true)
			d:SetAttribute("FS", true)
		end
	end
end

-- the egg's menu model in a ViewportFrame (black when undiscovered)
local function eggView(parent, modelName, r, silhouette, z)
	local previews = ReplicatedStorage:FindFirstChild("GameMenu")
	previews = previews and previews:FindFirstChild("EggPreviews")
	local model = previews and modelName and previews:FindFirstChild(modelName)
	if not model then return nil end
	local viewport = H.new("ViewportFrame", { Name = "Egg", BackgroundTransparency = 1, Position = UDim2.fromOffset(r[1], r[2]), Size = UDim2.fromOffset(r[3], r[4]), ZIndex = z,
		Ambient = Color3.new(1, 1, 1), LightColor = Color3.new(1, 1, 1), LightDirection = Vector3.new(-0.4, -0.6, -1) }, parent)
	if silhouette then viewport.ImageColor3 = BLACK end
	local egg = model:Clone()
	egg.Parent = viewport
	local boundsCFrame, boundsSize = egg:GetBoundingBox()
	egg:PivotTo(CFrame.new(-boundsCFrame.Position) * egg:GetPivot())
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, boundsSize.Y * 0.08, -boundsSize.Magnitude * 1.25), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

local function portrait(parent, image, r, silhouette, z, characterId)
	if not image or image == "" then
		return characterId and MenuArt.characterPortrait(parent, characterId, r, z, silhouette)
	end
	local picture = H.new("ImageLabel", { Name = "Portrait", BackgroundTransparency = 1, Image = image, ScaleType = Enum.ScaleType.Fit,
		Position = UDim2.fromOffset(r[1], r[2]), Size = UDim2.fromOffset(r[3], r[4]), ZIndex = z }, parent)
	if silhouette then picture.ImageColor3 = BLACK end
	return picture
end

local function paletteOf(entry, discovered)
	if entry.mutation then return MUTATION[entry.mutation] or C.lilac end
	if discovered == false then return RARITY.Locked end
	return RARITY[entry.rarity] or C.aqua
end

---------------------------------------------------------------- grid cards
function IndexComponent:_card(entry, x, y)
	local pal = paletteOf(entry, entry.discovered)
	local holder = H.new("Frame", { Name = "Card_" .. entry.id, BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(CARD_W, CARD_H), ZIndex = Z + 2 }, nil)
	local f = card(holder, "Face", 0, 0, CARD_W, CARD_H, pal, Z + 1)
	local mutation = entry.mutation and Config.Mutations[entry.mutation]
	if mutation then
		icon(f, "Icon", "IconDna", CARD_W / 2, 92, 110, Z + 4):SetAttribute("Wiggle", 0)
		txt(f, "Subtitle", entry.subtitle or "", 10, CARD_H - 74, CARD_W - 20, 30, 24, Z + 5, GOLD_TEXT)
	elseif entry.egg then
		eggView(f, entry.egg, { 22, 30, CARD_W - 44, 140 }, not entry.discovered, Z + 4)
	else
		portrait(f, entry.image, { 10, 26, CARD_W - 20, 150 }, not entry.discovered, Z + 4, entry.characterId)
	end
	-- 2026-11-07 clean pass: undiscovered cards say "???" once (the name), no second "???" tag in the corner
	if entry.badge or entry.discovered then
		badge(f, entry.badge or entry.rarity, CARD_W - 8, 8, 28, 18, pal, Z + 5)
	end
	txt(f, "Name", entry.discovered and string.upper(entry.name) or "???", 8, CARD_H - 42, CARD_W - 16, 34, 26, Z + 6)
	if entry.selected then
		goldOutline(f, 6)
	end
	if entry.discovered then
		local hit = H.new("TextButton", { Name = "Hit", BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), ZIndex = Z + 8 }, holder)
		hit.MouseEnter:Connect(function() UISound.Play("Hover") end)
		hit.Activated:Connect(function()
			UISound.Play("Click")
			self.model.onSelect(entry.id)
		end)
	end
	optOut(holder)
	holder.Parent = self.grid
	return holder
end

-- cards whose name contains the search text (case-insensitive; undiscovered names never match)
function IndexComponent:_fillGrid()
	local scroller = self.grid
	for _, child in scroller:GetChildren() do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	local needle = string.lower(self.search)
	local shown = 0
	for _, entry in self.model.cards do
		local haystack = entry.discovered and string.lower(entry.name) or ""
		if needle == "" or string.find(haystack, needle, 1, true) then
			local column, row = shown % 4, shown // 4
			self:_card(entry, PAD + column * (CARD_W + GAP), PAD + row * (CARD_H + GAP))
			shown += 1
		end
	end
	if shown == 0 then
		local empty = txt(nil, "Empty", "No characters found", 0, 200, GRID.W, 40, 30, Z + 2)
		optOut(empty)
		empty.Parent = scroller
	end
	local rows = math.ceil(shown / 4)
	local height = rows > 0 and PAD * 2 + rows * CARD_H + (rows - 1) * GAP or 0
	scroller.CanvasSize = UDim2.fromOffset(0, height)
	return height
end

---------------------------------------------------------------- detail
function IndexComponent:_buildDetail(top)
	local canvas, selected = self.canvas, self.model.selected
	local D = { X = DETAIL.X, Y = top, W = DETAIL.W, H = DETAIL.H + (DETAIL.Y - top) }
	if not selected then
		local f = card(canvas, "Detail", D.X, D.Y, D.W, D.H, C.ink, Z)
		icon(f, "Icon", "IconCharacters", D.W / 2, 120, 120, Z + 3):SetAttribute("Float", 120)
		txt(f, "Empty", Config.Detail.EmptyText, 24, 200, D.W - 48, 110, 32, Z + 4, nil, nil, true)
		return
	end
	local pal = paletteOf(selected, true)
	local f = card(canvas, "Detail", D.X, D.Y, D.W, D.H, pal, Z, true)
	local pc = (D.H - 160) / 2 + 8
	H.beams(f, D.W / 2, pc, 330, Z + 2, WHITE, 0.3, 8)
	local mutation = selected.mutation and Config.Mutations[selected.mutation]
	if mutation then
		icon(f, "Icon", "IconDna", D.W / 2, pc, 170, Z + 3):SetAttribute("Float", pc)
	elseif selected.egg and not selected.image and not selected.characterId then
		local v = eggView(f, selected.egg, { 48, 14, D.W - 96, D.H - 172 }, false, Z + 3)
		if v then v:SetAttribute("Float", 14) end
	else
		portrait(f, selected.image, { 30, 12, D.W - 60, D.H - 166 }, false, Z + 3, selected.characterId)
	end
	badge(f, selected.badge or selected.rarity or "", D.W - 10, 10, 34, 22, pal, Z + 5)
	H.gleam(txt(f, "Name", string.upper(selected.name), 12, D.H - 148, D.W - 24, 44, 38, Z + 5))
	-- a status pill: DISCOVERED by default, the income line on mutations
	local status = selected.status or "DISCOVERED"
	local sw = math.min(D.W - 60, TextService:GetTextSize(status, 22, Enum.Font.FredokaOne, Vector2.new(1000, 100)).X + 34)
	local pillF = H.rect(f, "StatusPill", (D.W - sw) / 2, D.H - 100, sw, 32, 12, Z + 5, WHITE)
	H.grad(pillF, DONE[1], DONE[2])
	H.ink(pillF, 3)
	txt(pillF, "Status", status, 6, 2, sw - 12, 28, 22, Z + 6)
	-- how to get it: a white strip with the egg (or the DNA) and the words
	local strip = H.rect(f, "ObtainStrip", 12, D.H - 58, D.W - 24, 46, 12, Z + 5, WHITE)
	H.ink(strip, 3)
	local textX = 14
	if selected.egg then
		if eggView(strip, selected.egg, { 4, -6, 54, 56 }, false, Z + 6) then textX = 62 end
	elseif mutation then
		icon(strip, "ObtainIcon", "IconDna", 30, 23, 36, Z + 6)
		textX = 56
	end
	local obtain = txt(strip, "Obtain", selected.obtain or "", textX, 6, D.W - 24 - textX - 10, 34, 22, Z + 6, hex("3A3150"), Enum.TextXAlignment.Left, true)
	obtain.UIStroke.Enabled = false
end

---------------------------------------------------------------- collection chests
function IndexComponent:_buildRewards()
	local R = REWARDS
	local f = card(self.canvas, "Rewards", R.X, R.Y, R.W, R.H, C.lilac, Z)
	local slot = R.W / 3
	for i, reward in self.model.rewards or {} do
		if i > 3 then break end
		local cx = slot * (i - 0.5)
		local chest = icon(f, "Reward" .. i, "Chest" .. i, cx, 50, 74, Z + 3)
		if not chest then continue end
		if reward.state == "claimed" then
			chest.ImageTransparency = 0.45
			btn(f, "Claimed" .. i, cx - 48, 96, 96, 38, DONE, "✓", 26, Z + 4, nil, true)
		elseif reward.state == "ready" then
			local scale = H.new("UIScale", { Name = "Pulse" }, chest)
			local tween = TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Scale = 1.12 })
			tween:Play()
			table.insert(self.tweens, tween)
			H.beams(f, cx, 50, 120, Z + 2, GOLD, 0.3, 6)
			btn(f, "Claim" .. i, cx - 52, 94, 104, 42, C.leaf, "CLAIM", 24, Z + 4, reward.onActivate)
		else
			local p = H.rect(f, "Need" .. i, cx - 48, 98, 96, 34, 10, Z + 4, WHITE)
			H.ink(p, 3)
			H.art(p, "Lock", "rbxassetid://104989619138958", 24, 17, 30, Z + 5)   -- FOLK gold lock (i_lock)
			local need = txt(p, "Text", tostring(reward.at), 38, 2, 52, 30, 24, Z + 5, hex("3A3150"))
			need.UIStroke.Enabled = false
		end
	end
end

---------------------------------------------------------------- tabs and toolbar
function IndexComponent:_buildSeasons()
	local canvas = self.canvas
	local gap = 12
	local w = (CW - 88 - gap * 2) / 3
	local seasons = {
		{ key = "Original", text = "Original", pal = C.azure, icon = "IconGlobe" },
		{ key = "Halloween", text = "Halloween", pal = C.mango, icon = "IconPumpkin" },
		{ key = "Winter", text = "Winter", pal = C.aqua },
	}
	for i, s in seasons do
		local x = 44 + (i - 1) * (w + gap)
		local b = H.button(canvas, "Season_" .. s.key, x, SEASON_Y, w, SEASON_H, 14, s.pal, Z + 3, { lip = 6, studs = 0.7 })
		if self.model.season == s.key then
			goldOutline(b, 5)
			b.Size = UDim2.fromOffset(w + 6, SEASON_H + 6)
		end
		local label = s.text
		if s.icon then
			icon(b, "Icon", s.icon, 40, 26, 44, b.ZIndex + 2)
		else
			txt(b, "Icon", "❄", 16, 4, 48, 44, 36, b.ZIndex + 2)
		end
		txt(b, "Label", label, 70, 6, w - (s.key == "Winter" and 170 or 84), SEASON_H - 18, 30, b.ZIndex + 3, nil, Enum.TextXAlignment.Left)
		if s.key == "Winter" then
			local soon = H.rect(b, "Soon", w - 96, 12, 82, 30, 10, b.ZIndex + 3, WHITE)
			H.grad(soon, C.coral[1], C.coral[2])
			H.ink(soon, 3)
			soon.Rotation = -4
			soon:SetAttribute("Wiggle", -4)
			txt(soon, "Text", "SOON", 4, 2, 74, 26, 20, b.ZIndex + 4)
			b.Activated:Connect(self.model.onWinter)
		else
			b.Activated:Connect(function() self.model.onSeason(s.key) end)
		end
	end
end

function IndexComponent:_buildBar()
	local canvas, model = self.canvas, self.model
	local track = H.rect(canvas, "CollectionBar", BAR[1], BAR[2], BAR[3], BAR[4], 12, Z + 1, WHITE)
	H.ink(track, 4)
	local ratio = math.clamp(model.progress or 0, 0, 1)
	if ratio > 0 then
		local w = ratio >= 1 and BAR[3] or math.max(30, math.floor(BAR[3] * ratio + 0.5))
		local fill = H.rect(track, "CollectionFill", 0, 0, w, BAR[4], 12, Z + 2, WHITE)
		H.grad(fill, C.gold[1], C.gold[2])
		H.shine(fill, 12, Z + 2)
	end
	H.gleam(txt(track, "CollectionText", model.collectionText or "", 10, 1, BAR[3] - 20, BAR[4] - 2, 26, Z + 3))
end

function IndexComponent:_buildToolbar()
	local canvas, model = self.canvas, self.model
	local search = Config.Search
	local SW = 300
	local box = H.rect(canvas, "SearchBox", 44, TOOL_Y, SW, TOOL_H, 14, Z + 1, WHITE)
	H.ink(box, 4)
	icon(box, "SearchIcon", "IconSearch", 26, TOOL_H / 2, 30, Z + 2)
	local input = H.new("TextBox", { Name = "Search", BackgroundTransparency = 1, FontFace = M.FONT, TextSize = 24, TextColor3 = hex("3A3150"),
		PlaceholderText = search.Placeholder[model.page] or search.Placeholder.Characters, PlaceholderColor3 = hex("A79FC4"), TextXAlignment = Enum.TextXAlignment.Left,
		ClearTextOnFocus = false, Text = self.search, Position = UDim2.fromOffset(50, 6), Size = UDim2.fromOffset(SW - 62, TOOL_H - 12), ZIndex = Z + 2 }, box)
	input:GetPropertyChangedSignal("Text"):Connect(function()
		if #input.Text > search.MaxLength then
			input.Text = string.sub(input.Text, 1, search.MaxLength)
		elseif input.Text ~= self.search then
			self.search = input.Text
			model.onSearch(input.Text)
			self:_fillGrid()
		end
	end)

	local selectedKey
	for _, filter in model.filters or {} do
		if filter.selected then selectedKey = filter.key end
	end
	local x = 44 + SW + 16
	for _, filter in model.filters or {} do
		local key = filter.key
		local w = FILTER_WIDTH[key] or 100
		local pal = key == "All" and C.bubblegum or (RARITY[key] or C.aqua)
		local b = H.button(canvas, "Filter_" .. key, x, TOOL_Y + 2, w, TOOL_H - 4, 12, pal, Z + 3, { lip = 5, studs = 0.7 })
		if key == selectedKey then
			goldOutline(b, 5)
			b.Size = UDim2.fromOffset(w + 6, TOOL_H + 2)
		end
		txt(b, "Label", key, 6, 2, w - 12, TOOL_H - 14, 22, b.ZIndex + 3)
		b.Activated:Connect(function() model.onFilter(key) end)
		x += w + 10
	end
end

function IndexComponent:_buildPages()
	local canvas = self.canvas
	local pages = {
		{ key = "Characters", pal = C.bubblegum, icon = "IconCharacters" },
		{ key = "Eggs", pal = C.leaf, icon = "IconEgg" },
		{ key = "Mutations", pal = C.lilac, icon = "IconDna" },
	}
	local x0 = (CW - (PAGE_W * 3 + 16 * 2)) / 2
	for i, p in pages do
		local x = x0 + (i - 1) * (PAGE_W + 16)
		local b = H.button(canvas, "Page_" .. p.key, x, PAGE_Y, PAGE_W, PAGE_H, 14, p.pal, Z + 5, { lip = 6, studs = 0.7 })
		if self.model.page == p.key then
			goldOutline(b, 5)
			b.Size = UDim2.fromOffset(PAGE_W + 8, PAGE_H + 8)
		end
		icon(b, "Icon", p.icon, 42, 27, 46, b.ZIndex + 2)
		txt(b, "Label", p.key, 74, 6, PAGE_W - 88, PAGE_H - 18, 30, b.ZIndex + 3, nil, Enum.TextXAlignment.Left)
		b.Activated:Connect(function() self.model.onPage(p.key) end)
	end
end

---------------------------------------------------------------- the window
function IndexComponent.new(panel, layer, model)
	local self = setmetatable({ model = model, search = model.search or "", tweens = {} }, IndexComponent)
	for _, name in { "CleanSkin", "CleanBase", "FigmaWindow" } do
		local child = panel:FindFirstChild(name)
		if child and child:IsA("GuiObject") then child.Visible = false end
	end
	-- the panel's own Close button becomes an invisible hit-box over the drawn X
	local closeButton = panel:FindFirstChild("Close")
	if closeButton then
		closeButton.AnchorPoint = Vector2.zero
		closeButton.Position = UDim2.fromScale(CLOSE[1] / CW, CLOSE[2] / CH)
		closeButton.Size = UDim2.fromScale(CLOSE[3] / CW, CLOSE[4] / CH)
		closeButton.BackgroundTransparency = 1
		closeButton.ZIndex = 30
		for _, d in closeButton:GetDescendants() do
			if d:IsA("GuiObject") then d.Visible = false elseif d:IsA("UIStroke") then d.Enabled = false end
		end
		if closeButton:IsA("ImageButton") then closeButton.ImageTransparency = 1
		elseif closeButton:IsA("TextButton") then closeButton.TextTransparency = 1 end
	end

	local canvas = H.new("Frame", { Name = "IndexCanvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CW, CH), ZIndex = Z }, nil)
	local scale = H.new("UIScale", {}, canvas)
	local function fit() scale.Scale = math.max(panel.Size.X.Offset, 1) / CW end
	fit()
	self.sizeConnection = panel:GetPropertyChangedSignal("Size"):Connect(fit)
	self.canvas = canvas

	-- the white studded sheet; the title on the top border, the book over the corner, the X over the other corner
	H.shadow(canvas, "Sheet", 0, 0, CW, CH, 26, Z - 2)
	local sheet = H.rect(canvas, "Background", 0, 0, CW, CH, 26, Z - 1, WHITE)
	H.ink(sheet, 5)
	H.crazy(canvas, sheet, { pal = C.blue, w = CW, h = CH, z = Z, band = 132 })
	H.studs(sheet, Vector2.new(50, 46), 0.8, 26, Z - 1)
	H.beams(canvas, 52, 18, 190, Z + 1, hex("5BEBFF"), 0.35, 6)
	local book = H.art(canvas, "HeaderIcon", INDEX_ICON, 52, 16, 116, Z + 2)
	book:SetAttribute("Float", 16)
	local title = H.text(canvas, "HeaderTitle", "INDEX", CW / 2, 6, 72, Z + 4, WHITE)
	H.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, hex("8FE3FF")) }, title)
	H.gleam(title)
	local x = H.rect(canvas, "CloseArt", CLOSE[1], CLOSE[2], CLOSE[3], CLOSE[4], 14, Z + 6, WHITE)
	H.grad(x, C.coral[1], C.coral[2])
	H.ink(x, 4)
	txt(x, "X", "X", 0, 2, CLOSE[3], CLOSE[4] - 6, 54, Z + 7)

	self:_buildSeasons()
	self:_buildBar()
	if model.page ~= "Mutations" then self:_buildToolbar() end

	-- the grid: a recessed white well with the cards scrolling inside
	local gy = model.page ~= "Mutations" and GRID.Y or TOOL_Y
	local gh = GRID.H + (GRID.Y - gy)
	local well = H.rect(canvas, "GridWell", GRID.X, gy, GRID.W, gh, 18, Z, hex("EDE8FA"))
	H.ink(well, 4)
	self.grid = H.new("ScrollingFrame", { Name = "Grid", BackgroundTransparency = 1, Position = UDim2.fromOffset(GRID.X, gy), Size = UDim2.fromOffset(GRID.W, gh),
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = hex("7C4DF2"), CanvasSize = UDim2.fromOffset(0, 0), ZIndex = Z + 1 }, canvas)
	local height = self:_fillGrid()
	self.grid.CanvasPosition = Vector2.new(0, math.clamp(model.scrollY or 0, 0, math.max(0, height - gh)))
	self.grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		model.onScroll(self.grid.CanvasPosition.Y)
	end)

	self:_buildDetail(gy)
	self:_buildRewards()
	self:_buildPages()

	optOut(canvas)
	M.animate(canvas, { sound = function(kind) UISound.Play(kind == "hover" and "Hover" or "Click") end })
	canvas.Parent = layer
	return self
end

function IndexComponent:Destroy()
	for _, tween in self.tweens do tween:Cancel() end
	self.sizeConnection:Disconnect()
	self.canvas:Destroy()
end

return IndexComponent
