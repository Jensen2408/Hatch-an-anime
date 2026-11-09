-- GameMenus.PlotComponent  (ModuleScript, client)
-- My Plot in the Folk Stud look (2026-11-07): a white studded sheet, "MY PLOT" on the top border with the game's
-- temple hanging over the corner and a red X over the other corner. Three stat cards (income, temple level,
-- incubators), the Character Slots / Upgrades tabs over a scrolling well of slot cards (placed: mint with the
-- character, empty: white, next to buy: mango with a glinting outline, locked: dark) or incubator rows, a white
-- slots bar, three upgrade rows on the right and the next-milestone card.
-- Display only: MenuLogic (RENDER.Plot) reads the plot state, formats every value and passes the actions as callbacks.
-- Same API and model as the atlas version; the names FirstHatchTutorial looks for stay: SlotsTab, UpgradesTab and
-- the upgrade rows TempleUpgrades / IncubatorSpeed / IncubatorUpgrades (each with a Buy button).
--
--   local view = PlotComponent.new(panel, layer, model)
--   view:Destroy()
--
-- model = {
--   tab = "slots" | "upgrades", scrollY = number?,
--   stats = { { label, value } x3 },
--   slots = { { number, state = "placed" | "empty" | "locked", image?, characterId?, name?, income?, price?,
--               onActivate?, onRemove? } },   -- a locked slot with onActivate is the next one to buy
--   slotsText, slotsProgress (0..1),
--   upgrades = { { name, title, subtitle, price, enabled, buttonText?, onActivate } x3 },
--   incubators = { { title, subtitle, progress (0..1), price, enabled, buttonText?, onActivate } },
--   milestone = { dots (0..5), onActivate? },
--   onTab(tab), onScroll(y),
-- }
-- Old version: ServerStorage._ARCHIVE.PlotComponent_BeforeStud_2026-11-07
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.H
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local Config = require(script.Parent:WaitForChild("PlotConfig"))
local Atlas = require(script.Parent:WaitForChild("PlotAtlas"))
local ShopConfig = require(script.Parent:WaitForChild("ShopMenuConfig"))
local ShopAtlas = require(script.Parent:WaitForChild("ShopAtlas"))
local MenuArt = require(ReplicatedStorage:WaitForChild("MenuArt"):WaitForChild("MenuArt"))

local CANVAS = Atlas.Canvas                  -- 1382 x 822: MenuLogic sizes the panel by this aspect
local CW, CH = CANVAS.X, CANVAS.Y
local Z = 10
local C = M.COLOR
local WHITE, BLACK, hex = H.WHITE, H.BLACK, H.hex
local GOLD = hex("FFC400")
local GOLD_TEXT = hex("FFE14D")
local CASH_TEXT = hex("2BF08C")
local INK_TEXT = hex("3A3150")
local CLOSE = { CW - 40, -30, 74, 74 }
local TEMPLE_ICON = "rbxassetid://133879873952343"   -- FOLK house (i_house), same as the rail
local COINS_ICON = "rbxassetid://86652590101281"   -- FOLK cash pile (i_cashpile)
local CASH_ICON = "rbxassetid://136807180106184"   -- FOLK cash stack (i_cash), next to every price
local LOCK_ICON = "rbxassetid://104989619138958"   -- FOLK gold lock (i_lock)
local BOLT_ICON = "rbxassetid://115412194685542"   -- FOLK lightning (i_energy)
local PLUS_ICON = "rbxassetid://124647673169644"   -- FOLK plus (i_plus)

local LEFT = { X = 44, W = 790 }
local TAB_Y, TAB_H = 178, 56
local VIEW = { X = 44, Y = 246, W = 790, H = 470 }
local FOOT_Y = 732
local RIGHT = { X = 854, W = CW - 854 - 44 }
local COLS, CARD_W, CARD_H, GAP, PAD = 4, 180, 214, 12, 8
local ROW_COLORS = { C.coral, C.azure, C.bubblegum }

local PlotComponent = {}
PlotComponent.__index = PlotComponent
PlotComponent.AspectRatio = CW / CH

---------------------------------------------------------------- building blocks
local function txt(parent, name, str, x, y, w, h, size, z, col, align, wrap)
	local l = H.new("TextLabel", { Name = name, BackgroundTransparency = 1, FontFace = M.FONT, Text = str or "", TextScaled = true, TextWrapped = wrap == true,
		TextColor3 = col or WHITE, TextXAlignment = align or Enum.TextXAlignment.Center, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z }, parent)
	H.new("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = 10 }, l)
	H.new("UIStroke", { Name = "UIStroke", Thickness = size >= 28 and 3.7 or (size >= 20 and 3 or 2.5), Color = BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, l)
	return l
end
local function atlasIcon(parent, name, image, info, cx, cy, size, z)
	local r = info.Rect
	local k = size / math.max(r[3], r[4])
	return H.new("ImageLabel", { Name = name, BackgroundTransparency = 1, Image = image, ImageRectOffset = Vector2.new(r[1], r[2]), ImageRectSize = Vector2.new(r[3], r[4]),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(r[3] * k, r[4] * k), ZIndex = z }, parent)
end
-- a piece of the plot atlas (coins, egg, locks)
local function icon(parent, name, pieceName, cx, cy, size, z)
	local info = Atlas.Pieces[pieceName]
	return info and atlasIcon(parent, name, Config.Pieces, info, cx, cy, size, z)
end
-- a piece of the shop atlas (the bolt)
local function shopIcon(parent, name, pieceName, cx, cy, size, z)
	local r = ShopAtlas.Pieces[pieceName]
	return r and atlasIcon(parent, name, ShopConfig.Pieces, { Rect = r }, cx, cy, size, z)
end
local function picture(parent, name, image, cx, cy, size, z)
	local p = H.art(parent, name, image, cx, cy, size, z)
	return p
end
local function card(parent, name, x, y, w, h, pal, z, shine)
	H.shadow(parent, name, x, y, w, h, 18, z)
	local f = H.rect(parent, name, x, y, w, h, 18, z + 1, WHITE)
	H.grad(f, pal[1], pal[2])
	H.ink(f, 4)
	H.studs(f, Vector2.new(48, 48), 0.84, 18, z + 1)
	if shine then H.shine(f, 18, z + 1) end
	return f
end
-- a pressable button; off = the darkest slab with the reason, no lip, no click (MAX, LOCKED, ...)
local function btn(parent, name, x, y, w, h, pal, word, size, z, onActivate, off)
	local b
	if off then
		b = H.button(parent, name, x, y, w, h, 12, { hex("9A9A9A"), hex("6E6E6E"), hex("3C3C3C") }, z, { lip = 0, studs = 0.75 })
		b.AutoButtonColor = false
		b:SetAttribute("Pressable", nil)
		-- still tells the player why when pressed (MenuLogic shows a toast)
		if onActivate then b.Activated:Connect(onActivate) end
	else
		b = H.button(parent, name, x, y, w, h, 12, pal, z, { lip = 5, studs = 0.7 })
		if onActivate then b.Activated:Connect(onActivate) end
	end
	txt(b, "Label", word, 8, 2, w - 16, h - (off and 4 or 9), size, b.ZIndex + 3)
	return b
end
-- 2026-11-07 clean pass: the price sits ON the button (cash icon + amount), like the shop, instead of floating above it.
-- off = grey slab with one short word (MAX / LOCKED); the long reason goes in the row's subtitle.
local function priceBtn(parent, name, x, y, w, h, pal, price, size, z, onActivate, off, offWord)
	if off or not price or price == "" or price == "MAX" then
		return btn(parent, name, x, y, w, h, pal, offWord or "MAX", size, z, onActivate, true)
	end
	local b = H.button(parent, name, x, y, w, h, 12, pal, z, { lip = 5, studs = 0.7 })
	if onActivate then b.Activated:Connect(onActivate) end
	local row = H.new("Frame", { Name = "Price", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -3),
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, h - 10), ZIndex = b.ZIndex + 3 }, b)
	H.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local coin = H.art(row, "Coin", CASH_ICON, 0, 0, size + 6, b.ZIndex + 3)
	coin.AnchorPoint = Vector2.zero
	coin.LayoutOrder = 1
	local value = H.new("TextLabel", { Name = "Label", BackgroundTransparency = 1, FontFace = M.FONT, Text = price, TextSize = size, TextColor3 = WHITE,
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, h - 10), LayoutOrder = 2, ZIndex = b.ZIndex + 3 }, row)
	H.new("UIStroke", { Name = "UIStroke", Thickness = size >= 28 and 3.7 or 3, Color = BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, value)
	return b
end
-- coin + price, centred on cx (hidden for "MAX": the button says so)
local function priceRow(parent, name, cx, cy, text, enabled, size, z)
	if text == "MAX" then return nil end
	local row = H.new("Frame", { Name = name, BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy),
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, size + 6), ZIndex = z }, parent)
	H.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 6),
		SortOrder = Enum.SortOrder.LayoutOrder }, row)
	local coin = H.art(row, "Coin", CASH_ICON, 0, 0, size + 4, z)
	if coin and not enabled then coin.ImageColor3 = hex("A9A3BF") end
	if coin then
		coin.AnchorPoint = Vector2.zero
		coin.LayoutOrder = 1
	end
	local value = H.new("TextLabel", { Name = "Price", BackgroundTransparency = 1, FontFace = M.FONT, Text = text, TextSize = size, TextColor3 = enabled and CASH_TEXT or hex("D6D6E4"),
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, size + 6), LayoutOrder = 2, ZIndex = z }, row)
	H.new("UIStroke", { Name = "UIStroke", Thickness = 3, Color = BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, value)
	return row
end
-- level dots on a white strip
local function dots(parent, x, y, filled, count, z)
	local s, gap, pad = 22, 8, 6
	local strip = H.rect(parent, "Dots", x, y, count * s + (count - 1) * gap + pad * 2, s + pad * 2, 10, z, WHITE)
	H.ink(strip, 3)
	for i = 1, count do
		local d = H.circle(strip, "Dot" .. i, pad + (i - 1) * (s + gap) + s / 2, pad + s / 2, s, z + 1,
			i <= filled and C.gold[1] or hex("E4DEF5"), i <= filled and C.gold[2] or hex("C9C1E6"), 2.5)
		if i <= filled and i == filled then d:SetAttribute("Wiggle", 0) end
	end
	return strip
end
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

---------------------------------------------------------------- slot cards
function PlotComponent:_slotCard(parent, slot, x, y)
	local isNext = slot.state == "locked" and slot.onActivate ~= nil
	local pal = slot.state == "placed" and C.mint or (slot.state == "empty" and { WHITE, hex("ECECEC") } or (isNext and C.mango or C.ink))
	local f = card(parent, string.format("Slot%02d", slot.number or 0), x, y, CARD_W, CARD_H, pal, Z + 1)
	-- the slot number in a small dark square on the corner
	local n = H.rect(f, "NumberTile", 8, 8, 34, 34, 8, Z + 4, BLACK)
	n.BackgroundColor3 = hex("241D35")
	txt(n, "Number", tostring(slot.number or ""), 0, 1, 34, 30, 24, Z + 5)

	if slot.state == "placed" then
		if slot.image and slot.image ~= "" then
			H.new("ImageLabel", { Name = "Portrait", BackgroundTransparency = 1, Image = slot.image, ScaleType = Enum.ScaleType.Fit,
				Position = UDim2.fromOffset(20, 10), Size = UDim2.fromOffset(CARD_W - 40, 104), ZIndex = Z + 3 }, f)
		elseif slot.characterId then
			MenuArt.characterPortrait(f, slot.characterId, { 20, 10, CARD_W - 40, 104 }, Z + 3)
		end
		txt(f, "Name", string.upper(slot.name or ""), 8, 114, CARD_W - 16, 30, 24, Z + 5)
		priceRow(f, "Income", CARD_W / 2, 154, slot.income or "", true, 24, Z + 5)
		local remove = btn(f, "Remove", 22, CARD_H - 46, CARD_W - 44, 36, C.coral, "REMOVE", 22, Z + 5, slot.onRemove)
		if not slot.onRemove then remove.Active = false end
	elseif slot.state == "empty" then
		-- a clean open slot: a plus and one word, nothing faint
		H.art(f, "Plus", PLUS_ICON, CARD_W / 2, CARD_H / 2 - 22, 70, Z + 4)
		txt(f, "Empty", "EMPTY", 10, CARD_H / 2 + 24, CARD_W - 20, 34, 28, Z + 4)
	elseif isNext then
		local o = f:FindFirstChild("Outline")
		if o then o.Thickness = 5 end
		f:SetAttribute("Glint", true)
		H.beams(f, CARD_W / 2, 52, 150, Z + 2, WHITE, 0.3, 6)
		local lock = H.art(f, "Lock", LOCK_ICON, CARD_W / 2, 50, 62, Z + 4)
		if lock then lock:SetAttribute("Float", 50) end
		H.gleam(txt(f, "NextSlot", "NEXT SLOT", 8, 92, CARD_W - 16, 34, 28, Z + 5))
		priceBtn(f, "Unlock", 14, CARD_H - 60, CARD_W - 28, 48, C.leaf, slot.price, 26, Z + 5, slot.onActivate)
	else
		H.art(f, "Lock", LOCK_ICON, CARD_W / 2, CARD_H / 2 - 24, 66, Z + 4).ImageColor3 = hex("9A9A9A")   -- the gold lock, greyed: not next yet
		-- the price in a white strip along the bottom, like the daily cards
		local strip = H.rect(f, "PriceStrip", 12, CARD_H - 52, CARD_W - 24, 40, nil, Z + 4, WHITE)
		H.ink(strip, 3)
		priceRow(strip, "Price", (CARD_W - 24) / 2, 20, slot.price or "", true, 24, Z + 5)
	end
	return f
end

function PlotComponent:_incubatorRow(parent, i, item, y)
	local w = VIEW.W - PAD * 2 - 10
	local h = 120
	local f = card(parent, "Incubator" .. i, PAD, y, w, h, i % 2 == 1 and C.lilac or C.aqua, Z + 1)
	local tile = H.rect(f, "EggTile", 14, 14, 92, 92, 16, Z + 3, WHITE)
	H.ink(tile, 3.5)
	local egg = icon(tile, "Egg", "Egg", 46, 46, 76, Z + 4)
	if egg and item.enabled then egg:SetAttribute("Wiggle", 0) end
	txt(f, "Title", item.title, 122, 10, w - 470, 36, 32, Z + 4, nil, Enum.TextXAlignment.Left)
	txt(f, "Subtitle", item.subtitle, 122, 46, w - 470, 26, 20, Z + 4, WHITE, Enum.TextXAlignment.Left)
	dots(f, 122, 76, math.floor((item.progress or 0) * 3 + 0.5), 3, Z + 4)
	priceBtn(f, "Buy", w - 214, 34, 190, 54, C.leaf, item.price, 28, Z + 5, item.onActivate, not item.enabled,
		(item.buttonText and #item.buttonText <= 8) and string.upper(item.buttonText) or (item.price == "MAX" and "MAX" or "LOCKED"))
	return f
end

function PlotComponent:_buildContent()
	local model = self.model
	local well = H.rect(self.canvas, "ContentWell", VIEW.X, VIEW.Y, VIEW.W, VIEW.H, 18, Z, hex("EFEFEF"))
	H.ink(well, 4)
	local scroller = H.new("ScrollingFrame", { Name = "Content", BackgroundTransparency = 1, Position = UDim2.fromOffset(VIEW.X, VIEW.Y), Size = UDim2.fromOffset(VIEW.W, VIEW.H),
		ScrollingDirection = Enum.ScrollingDirection.Y, ScrollBarThickness = 8, ScrollBarImageColor3 = hex("2E2A26"), CanvasSize = UDim2.new(), ZIndex = Z + 1 }, self.canvas)
	local height = 0
	if model.tab == "upgrades" then
		for i, item in model.incubators do
			local y = PAD + (i - 1) * (120 + GAP)
			self:_incubatorRow(scroller, i, item, y)
			height = y + 120 + PAD + 6
		end
	else
		local x0 = (VIEW.W - 10 - (COLS * CARD_W + (COLS - 1) * GAP)) / 2
		for i, slot in model.slots do
			local column, row = (i - 1) % COLS, (i - 1) // COLS
			local y = PAD + row * (CARD_H + GAP)
			self:_slotCard(scroller, slot, x0 + column * (CARD_W + GAP), y)
			height = math.max(height, y + CARD_H + PAD + 6)
		end
	end
	scroller.CanvasSize = UDim2.fromOffset(0, height)
	scroller.CanvasPosition = Vector2.new(0, math.clamp(model.scrollY or 0, 0, math.max(0, height - VIEW.H)))
	scroller:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		model.onScroll(scroller.CanvasPosition.Y)
	end)
end

function PlotComponent:_buildTabs()
	local tabs = {
		{ key = "slots", name = "SlotsTab", text = "CHARACTER SLOTS", pal = C.azure, w = 450 },
		{ key = "upgrades", name = "UpgradesTab", text = "UPGRADES", pal = C.lilac, w = LEFT.W - 450 - 12 },
	}
	local x = LEFT.X
	for _, t in tabs do
		local b = H.button(self.canvas, t.name, x, TAB_Y, t.w, TAB_H, 14, t.pal, Z + 3, { lip = 6, studs = 0.7 })
		if self.model.tab == t.key then
			local o = b:FindFirstChild("Outline")
			if o then o.Color, o.Thickness = GOLD, 5 end
			b.Size = UDim2.fromOffset(t.w + 6, TAB_H + 6)
		end
		txt(b, "Label", t.text, 12, 4, t.w - 24, TAB_H - 14, 32, b.ZIndex + 3)
		b.Activated:Connect(function() self.model.onTab(t.key) end)
		x += t.w + 12
	end
end

function PlotComponent:_buildStats()
	local stats = self.model.stats or {}
	local looks = {
		{ pal = C.leaf, art = function(f) picture(f, "Icon", COINS_ICON, 50, 46, 70, Z + 4):SetAttribute("Float", 46) end },
		{ pal = C.mango, art = function(f) picture(f, "Icon", TEMPLE_ICON, 50, 44, 74, Z + 4):SetAttribute("Float", 44) end },
		{ pal = C.bubblegum, art = function(f) icon(f, "Icon", "Egg", 50, 46, 66, Z + 4):SetAttribute("Wiggle", 0) end },
	}
	local gap = 14
	local w = (CW - 88 - gap * 2) / 3
	for i = 1, 3 do
		local stat, look = stats[i], looks[i]
		if stat then
			local f = card(self.canvas, "Stat" .. i, 44 + (i - 1) * (w + gap), 64, w, 94, look.pal, Z, true)
			look.art(f)
			txt(f, "Label", stat[1], 100, 10, w - 116, 26, 22, Z + 5, nil, Enum.TextXAlignment.Left)
			H.gleam(txt(f, "Value", stat[2], 100, 36, w - 116, 48, 44, Z + 5, nil, Enum.TextXAlignment.Left))
		end
	end
end

function PlotComponent:_buildRight()
	local looks = {
		function(tile) picture(tile, "Icon", TEMPLE_ICON, 44, 42, 76, Z + 4) end,
		function(tile) H.art(tile, "Icon", BOLT_ICON, 44, 44, 70, Z + 4) end,
		function(tile) icon(tile, "Icon", "Egg", 44, 44, 70, Z + 4) end,
	}
	local h, gap = 130, 12
	for i, item in self.model.upgrades or {} do
		if i > 3 then break end
		local y = TAB_Y + (i - 1) * (h + gap)
		local name = item.name or (Config.UpgradeRows[i] and Config.UpgradeRows[i].Name) or ("Upgrade" .. i)
		local f = card(self.canvas, name, RIGHT.X, y, RIGHT.W, h, ROW_COLORS[i], Z)
		local tile = H.rect(f, "IconTile", 12, 21, 88, 88, 16, Z + 3, WHITE)
		H.ink(tile, 3.5)
		local art = looks[i]
		if art then art(tile) end
		txt(f, "Title", item.title, 112, 10, RIGHT.W - 124, 34, 30, Z + 4, nil, Enum.TextXAlignment.Left)
		-- one calm line of detail (or the reason it is locked), the price on the button
		local detail = (not item.enabled and item.buttonText and #item.buttonText > 8) and item.buttonText or item.subtitle
		txt(f, "Subtitle", detail, 112, 50, RIGHT.W - 124 - 178, 64, 20, Z + 4, WHITE, Enum.TextXAlignment.Left, true)
		priceBtn(f, "Buy", RIGHT.W - 170, 62, 156, 52, C.leaf, item.price, 26, Z + 5, item.onActivate, not item.enabled,
			(item.buttonText and #item.buttonText <= 8) and string.upper(item.buttonText) or (item.price == "MAX" and "MAX" or "LOCKED"))
	end

	-- the next milestone: press it to buy the next slot (or the temple upgrade)
	local model = self.model.milestone or {}
	local my = TAB_Y + 3 * (h + gap)
	local mh = CH - 44 - my
	local f = card(self.canvas, "Milestone", RIGHT.X, my, RIGHT.W, mh, C.gold, Z, true)
	H.beams(f, 70, mh / 2, 170, Z + 2, WHITE, 0.3, 6)
	picture(f, "Temple", TEMPLE_ICON, 70, mh / 2, 104, Z + 3):SetAttribute("Float", mh / 2)
	H.gleam(txt(f, "Title", "NEXT MILESTONE", 132, 12, RIGHT.W - 148, 36, 32, Z + 4, nil, Enum.TextXAlignment.Left))
	txt(f, "Text", "More space for your collection!", 132, 48, RIGHT.W - 148, 24, 20, Z + 4, nil, Enum.TextXAlignment.Left)
	dots(f, 132, mh - 50, model.dots or 0, 5, Z + 4)
	if model.onActivate then
		f:SetAttribute("Glint", true)
		local hit = H.new("TextButton", { Name = "Hit", BackgroundTransparency = 1, Text = "", AutoButtonColor = false, Size = UDim2.fromScale(1, 1), ZIndex = Z + 8 }, f)
		hit.MouseEnter:Connect(function() UISound.Play("Hover") end)
		hit.Activated:Connect(function()
			UISound.Play("Click")
			model.onActivate()
		end)
	end
end

function PlotComponent:_buildFooter()
	local track = H.rect(self.canvas, "SlotsBar", LEFT.X, FOOT_Y, LEFT.W, 40, 12, Z + 1, WHITE)
	H.ink(track, 4)
	local ratio = math.clamp(self.model.slotsProgress or 0, 0, 1)
	if ratio > 0 then
		local w = ratio >= 1 and LEFT.W or math.max(40, math.floor(LEFT.W * ratio + 0.5))
		local fill = H.rect(track, "SlotsFill", 0, 0, w, 40, 12, Z + 2, WHITE)
		H.grad(fill, C.azure[1], C.azure[2])
		H.shine(fill, 12, Z + 2)
	end
	H.gleam(txt(track, "SlotsText", self.model.slotsText or "", 12, 2, LEFT.W - 24, 36, 28, Z + 3))
end

---------------------------------------------------------------- the window
function PlotComponent.new(panel, layer, model)
	local self = setmetatable({ model = model }, PlotComponent)
	for _, name in { "CleanSkin", "CleanBase", "FigmaWindow" } do
		local child = panel:FindFirstChild(name)
		if child and child:IsA("GuiObject") then child.Visible = false end
	end
	-- the panel's own Close button becomes an invisible hit-box over the drawn X
	local closeButton = panel:FindFirstChild("Close")
	if closeButton then
		closeButton.Visible = true
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

	local canvas = H.new("Frame", { Name = "PlotCanvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CW, CH), ZIndex = Z }, nil)
	local scale = H.new("UIScale", {}, canvas)
	local function fit() scale.Scale = math.max(panel.Size.X.Offset, 1) / CW end
	fit()
	self.sizeConnection = panel:GetPropertyChangedSignal("Size"):Connect(fit)
	self.canvas = canvas

	-- the sheet, the title on the top border, the temple over the corner, the X over the other corner
	H.shadow(canvas, "Sheet", 0, 0, CW, CH, 26, Z - 2)
	local sheet = H.rect(canvas, "Background", 0, 0, CW, CH, 26, Z - 1, WHITE)
	H.ink(sheet, 5)
	H.crazy(canvas, sheet, { pal = C.red, w = CW, h = CH, z = Z, band = 58 })
	H.studs(sheet, Vector2.new(50, 46), 0.8, 26, Z - 1)
	H.beams(canvas, 52, 18, 190, Z + 1, hex("FF5A6E"), 0.35, 6)
	picture(canvas, "HeaderIcon", TEMPLE_ICON, 52, 14, 120, Z + 2):SetAttribute("Float", 14)
	local title = H.text(canvas, "HeaderTitle", "MY PLOT", CW / 2, 6, 72, Z + 4, WHITE)
	H.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, hex("FFB0BA")) }, title)
	H.gleam(title)
	local x = H.rect(canvas, "CloseArt", CLOSE[1], CLOSE[2], CLOSE[3], CLOSE[4], 14, Z + 6, WHITE)
	H.grad(x, C.coral[1], C.coral[2])
	H.ink(x, 4)
	txt(x, "X", "X", 0, 2, CLOSE[3], CLOSE[4] - 6, 54, Z + 7)

	self:_buildStats()
	self:_buildTabs()
	self:_buildContent()
	self:_buildRight()
	self:_buildFooter()

	optOut(canvas)
	M.animate(canvas, { sound = function(kind) UISound.Play(kind == "hover" and "Hover" or "Click") end })
	canvas.Parent = layer
	return self
end

function PlotComponent:Destroy()
	self.sizeConnection:Disconnect()
	self.canvas:Destroy()
end

return PlotComponent
