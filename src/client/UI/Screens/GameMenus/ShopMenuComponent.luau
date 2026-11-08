-- GameMenus.ShopMenuComponent  (ModuleScript, client)
-- The Shop in the Folk Stud look (2026-11-07): a white studded sheet with no title bar. "SHOP" sits on the top border
-- with the crown hanging over the corner and a red X over the other corner; six candy tabs (the open one has a gold
-- outline); every page is built from vivid black-outlined cards, spinning light rays behind the heroes, pressable
-- buttons with a lip, and studded lime buttons with no lip for things already done (OWNED, EQUIPPED, CLAIMED, MAXED).
-- Display only: MenuLogic (RENDER.VipShop) reads ShopRemote "State", formats prices and passes the purchases as
-- callbacks. Same API and model as the atlas version, so MenuLogic is unchanged:
--
--   local view = ShopMenuComponent.new(panel, layer, model)
--   view:Destroy()
--
-- model = {
--   tab, onTab(tab),
--   weaponModels = Folder of voxel display Models named by weapon key (ShopModels.Weapons, built by WeaponGiver)?,
--   weapons = { { key, name, stats, price, owned, equipped, special, onBuy, onEquip } },   -- WEAPONS tab
--   featuredWeapon = { key, title, text, button, onOpen }?,   -- FEATURED's left card when no limited deal runs
--   limited = { name, text, eggModel?, endsAt (os.clock), price, onBuy }?,
--   vip = { text, perks, price, owned, onBuy },
--   boosts = { { title, shortText, text, price, activeEnds? (os.clock), duration, onBuy } x2 },
--   starter = { title, text, price, owned, onBuy },
--   money = { value, level, maxLevel, levelText, price, maxed, onBuy },
--   hatch = { value, level, maxLevel, price, maxed, onBuy },
--   cash = { { amount, text, badge?, price, onBuy } x3 },
--   daily = { days = { { label, kind, value, valueColor, state = "claimed" | "today" | "locked", last } },
--             ready, claimText, nextEnds (os.clock), onClaim },
-- }
-- Old version: ServerStorage._ARCHIVE.ShopMenuComponent_BeforeStud_2026-11-07
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local M = require(ReplicatedStorage:WaitForChild("FolkStudUI"))
local H = M.H
local UISound = require(ReplicatedStorage:WaitForChild("UISound"))
local Config = require(script.Parent:WaitForChild("ShopMenuConfig"))
local Atlas = require(script.Parent:WaitForChild("ShopAtlas"))

local CANVAS = Atlas.Canvas            -- 1092 x 679: MenuLogic sizes the panel by this aspect
local CW, CH = CANVAS.X, CANVAS.Y
local Z = 10
local C = M.COLOR
local WHITE, BLACK, hex = H.WHITE, H.BLACK, H.hex
local GOLD_TEXT = hex("FFE14D")
local DONE = { hex("8CF56A"), hex("3CCB3A"), hex("1A6E1E") }   -- flat lime: owned / equipped / claimed
local CLOSE = { CW - 40, -30, 74, 74 }                         -- the X over the top-right corner
local PAGE = { X = 36, Y = 146, W = CW - 72, H = CH - 146 - 30 }

local TABS = {
	{ key = "WEAPONS", text = "Weapons", pal = C.coral, model = "WoodenBat" },
	{ key = "FEATURED", text = "Featured", pal = C.mango, icon = "TabIconFeatured" },
	{ key = "BOOSTS", text = "Boosts", pal = C.lilac, icon = "TabIconBoosts" },
	{ key = "PASSES", text = "Passes", pal = C.bubblegum, icon = "TabIconPasses" },
	{ key = "CASH", text = "Cash", pal = C.leaf, icon = "TabIconCash" },
	{ key = "DAILY", text = "Daily", pal = C.azure, icon = "TabIconDaily" },
}
local WEAPON_COLORS = { C.mango, C.azure, C.gold, C.aqua, C.coral, C.lilac, C.bubblegum }

local ShopMenuComponent = {}
ShopMenuComponent.__index = ShopMenuComponent
ShopMenuComponent.AspectRatio = CW / CH

-- 1:02:03
local function formatHms(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d:%02d", seconds // 3600, (seconds // 60) % 60, seconds % 60)
end
-- 12d 12h 28m; under a day: 12h 28m 05s
local function formatDhm(seconds)
	seconds = math.max(0, math.floor(seconds))
	local days, hours, minutes = seconds // 86400, (seconds // 3600) % 24, (seconds // 60) % 60
	if days > 0 then
		return string.format("%dd %dh %02dm", days, hours, minutes)
	end
	return string.format("%dh %02dm %02ds", hours, minutes, seconds % 60)
end

---------------------------------------------------------------- building blocks
-- a word that fits its box: shrinks, never grows past `size`
local function txt(parent, name, str, x, y, w, h, size, z, col, align, wrap)
	local l = H.new("TextLabel", { Name = name, BackgroundTransparency = 1, FontFace = M.FONT, Text = str or "", TextScaled = true, TextWrapped = wrap == true,
		TextColor3 = col or WHITE, TextXAlignment = align or Enum.TextXAlignment.Center, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z }, parent)
	H.new("UITextSizeConstraint", { MaxTextSize = size }, l)
	H.new("UIStroke", { Name = "UIStroke", Thickness = size >= 28 and 3.7 or (size >= 20 and 3 or 2.5), Color = BLACK, LineJoinMode = Enum.LineJoinMode.Bevel }, l)
	return l
end
-- an atlas icon (the game's own shop icons), centred, fitted into a square
-- FOLK Icon Pack art that replaces an atlas piece (sharper, 256 px): piece name -> image
-- 2026-11-07: every atlas piece now has FOLK art; the old pixel atlas crops cut art and picked up bits of the
-- next icon (stars, calendar, tabs).
local FOLK = {
	IconCrown = "rbxassetid://95884903799789",        -- i_crown
	IconStar = "rbxassetid://87844351568148",         -- i_star
	IconCoins = "rbxassetid://136807180106184",       -- i_cash
	IconBolt = "rbxassetid://115412194685542",        -- i_energy
	IconPotions = "rbxassetid://117826546204271",     -- i_potion
	TabIconFeatured = "rbxassetid://87844351568148",  -- i_star
	TabIconBoosts = "rbxassetid://117826546204271",   -- i_potion
	TabIconPasses = "rbxassetid://129380209486714",   -- i_ticket
	TabIconCash = "rbxassetid://136807180106184",     -- i_cash
	TabIconDaily = "rbxassetid://133619775593354",    -- i_calendar
	IconGift = "rbxassetid://138288609047988",        -- i_daily (gift box)
	IconCheck = "rbxassetid://128694588334272",       -- i_check
	IconLock = "rbxassetid://104989619138958",        -- i_lock
	IconClock = "rbxassetid://123064760828653",       -- i_clock
}
local function icon(parent, name, pieceName, cx, cy, size, z)
	if FOLK[pieceName] then return H.art(parent, name, FOLK[pieceName], cx, cy, size, z) end
	local r = Atlas.Pieces[pieceName]
	if not r then return nil end
	local k = size / math.max(r[3], r[4])
	return H.new("ImageLabel", { Name = name, BackgroundTransparency = 1, Image = Config.Pieces, ImageRectOffset = Vector2.new(r[1], r[2]), ImageRectSize = Vector2.new(r[3], r[4]),
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(r[3] * k, r[4] * k), ZIndex = z }, parent)
end
-- a vivid card you read: gradient face, black outline, faint studs, light sweep, hard shadow
local function card(parent, name, x, y, w, h, pal, z)
	H.shadow(parent, name, x, y, w, h, 18, z)
	local f = H.rect(parent, name, x, y, w, h, 18, z + 1, WHITE)
	H.grad(f, pal[1], pal[2])
	H.ink(f, 4)
	H.studs(f, Vector2.new(48, 48), 0.84, 18, z + 1)
	H.shine(f, 18, z + 1)
	return f
end
-- a pressable button with a word; done = studded lime with no lip and no click (OWNED, EQUIPPED, CLAIMED, MAXED)
local function btn(parent, name, x, y, w, h, pal, word, size, z, onActivate, done)
	local b
	if done then
		-- studded like every other button (user asked 2026-11-07); no lip and no click is what says "done"
		b = H.button(parent, name, x, y, w, h, 14, DONE, z, { lip = 0, studs = 0.7 })
		b.AutoButtonColor = false
		b.Active = false
		b:SetAttribute("Pressable", nil)
	else
		b = H.button(parent, name, x, y, w, h, 14, pal, z, { lip = 6, studs = 0.7 })
		if onActivate then b.Activated:Connect(onActivate) end
	end
	txt(b, "Label", word, 8, 2, w - 16, h - (done and 4 or 10), size, b.ZIndex + 3)
	return b
end
-- level squares on a white track
local function pips(parent, x, y, size, gap, level, maxLevel, z)
	local pad = 6
	local track = H.rect(parent, "PipTrack", x - pad, y - pad, maxLevel * size + (maxLevel - 1) * gap + pad * 2, size + pad * 2, 12, z, WHITE)
	H.ink(track, 3)
	for i = 1, maxLevel do
		local p = H.rect(track, "Pip" .. i, pad + (i - 1) * (size + gap), pad, size, size, 8, z + 1, WHITE)
		if i <= level then H.grad(p, C.gold[1], C.gold[2]) else p.BackgroundColor3 = hex("E4DEF5") end
		H.ink(p, 2.5)
	end
	return track
end
-- a thick gold outline that glints (the equipped bat, today's reward, the open tab)
local function goldOutline(f, thickness)
	f:SetAttribute("Glint", true)
	local o = f:FindFirstChild("Outline")
	if o then
		o.Color = hex("FFC400")
		o.Thickness = thickness or 5
	end
end
-- a red pill (SPECIAL, NEW, LIMITED, BEST VALUE)
local function pill(parent, name, word, x, y, w, h, z, pal)
	local p = H.rect(parent, name, x, y, w, h, 12, z, WHITE)
	H.grad(p, (pal or C.coral)[1], (pal or C.coral)[2])
	H.ink(p, 3)
	p.Rotation = -4
	p:SetAttribute("Wiggle", -4)
	txt(p, "Text", word, 6, 2, w - 12, h - 4, math.floor(h * 0.7), z + 1)
	return p
end

---------------------------------------------------------------- live bits
-- Calls update(secondsLeft) now and then every second while the view lives
function ShopMenuComponent:_tick(endsAt, update)
	update(endsAt - os.clock())
	task.spawn(function()
		while self.alive do
			task.wait(1)
			if self.alive then update(endsAt - os.clock()) end
		end
	end)
end
-- Boost description, replaced by a live "ACTIVE 0:12:34" while the boost runs
function ShopMenuComponent:_boostText(text, boost, idleText)
	if not boost.activeEnds then
		text.Text = idleText
		return
	end
	self:_tick(boost.activeEnds, function(secondsLeft)
		text.Text = secondsLeft > 0 and ("ACTIVE " .. formatHms(secondsLeft)) or idleText
	end)
end
-- the limited egg model spinning in a ViewportFrame
function ShopMenuComponent:_egg(parent, eggModel, x, y, w, h, z)
	local viewport = H.new("ViewportFrame", { Name = "Egg", BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z,
		Ambient = Color3.fromRGB(200, 190, 230), LightColor = WHITE, LightDirection = Vector3.new(-0.4, -0.6, -1) }, parent)
	local egg = eggModel:Clone()
	egg.Parent = viewport
	local boundsCFrame, boundsSize = egg:GetBoundingBox()
	egg:PivotTo(CFrame.new(-boundsCFrame.Position) * egg:GetPivot())
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(0, boundsSize.Y * 0.08, -boundsSize.Magnitude * 1.25), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local basePivot, spinStart = egg:GetPivot(), os.clock()
	local spin
	spin = RunService.RenderStepped:Connect(function()
		if not (self.alive and viewport.Parent) then spin:Disconnect() return end
		if not self.panel.Visible then return end
		local elapsed = os.clock() - spinStart
		egg:PivotTo(CFrame.new(0, math.sin(elapsed * 2) * 0.2, 0) * CFrame.Angles(0, elapsed * 0.9, 0) * basePivot)
	end)
end
-- a weapon's display Model, tilted (spinning when spinSpeed is given), in a ViewportFrame (nil when it isn't there)
function ShopMenuComponent:_weaponModel(parent, key, x, y, w, h, z, spinSpeed, distance, tiltDegrees)
	local template = self.model.weaponModels and self.model.weaponModels:FindFirstChild(key)
	if not template then return nil end
	local viewport = H.new("ViewportFrame", { Name = "Model", BackgroundTransparency = 1, Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), ZIndex = z,
		Ambient = Color3.fromRGB(200, 190, 230), LightColor = WHITE, LightDirection = Vector3.new(-0.4, -0.6, -1) }, parent)
	local model = template:Clone()
	model:PivotTo(CFrame.new())
	model.Parent = viewport
	-- turn about the middle of the box, not the pivot (the bat's pivot is at its handle, so it slid out of frame)
	local box = model:GetBoundingBox()
	local centre = CFrame.new(-box.Position)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.CFrame = CFrame.lookAt(Vector3.new(0, 0, -model:GetExtentsSize().Magnitude * (distance or 2)), Vector3.zero)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	local tilt = CFrame.Angles(0, 0, math.rad(tiltDegrees or -35))
	model:PivotTo(tilt * centre)
	if spinSpeed and spinSpeed > 0 then
		local spinStart = os.clock()
		local spin
		spin = RunService.RenderStepped:Connect(function()
			if not (self.alive and viewport.Parent) then spin:Disconnect() return end
			if not self.panel.Visible then return end
			model:PivotTo(tilt * CFrame.Angles(0, (os.clock() - spinStart) * spinSpeed, 0) * centre)
		end)
	end
	return viewport
end

---------------------------------------------------------------- WEAPONS: one card per bat
function ShopMenuComponent:_weaponsPage()
	local page, weapons = self.page, self.model.weapons or {}
	local n = math.max(#weapons, 1)
	local gap = 14
	local w = (PAGE.W - gap * (n - 1)) / n
	local h = PAGE.H - 8
	for i, weapon in weapons do
		local x = PAGE.X + (i - 1) * (w + gap)
		local f = card(page, "Weapon_" .. weapon.key, x, PAGE.Y, w, h, WEAPON_COLORS[(i - 1) % #WEAPON_COLORS + 1], Z)
		if weapon.equipped then goldOutline(f) end
		if weapon.special or weapon.equipped then
			H.beams(f, w / 2, 112, w * 1.05, Z + 2, WHITE, 0.35, 6)
		end
		self:_weaponModel(f, weapon.key, 10, 14, w - 20, 200, Z + 3, 0.9)
		if weapon.special then pill(f, "Badge", "SPECIAL", 10, 10, 104, 30, Z + 4) end
		H.gleam(txt(f, "Name", weapon.name, 8, 222, w - 16, 40, 32, Z + 4))
		-- 2026-11-07 clean pass: stats as a two-column table in a white box (label left, value right)
		local rows = {}
		for line in string.gmatch(weapon.stats or "", "[^\n]+") do
			local label, value = string.match(line, "^(.-):%s*(.+)$")
			table.insert(rows, { label or line, value or "" })
		end
		local rowH = 30
		local box = H.rect(f, "Stats", 10, 268, w - 20, #rows * rowH + 12, nil, Z + 4, WHITE)
		H.ink(box, 3)
		for r, row in rows do
			local y = 6 + (r - 1) * rowH
			if r > 1 then
				local line = H.rect(box, "Line" .. r, 8, y - 1, w - 36, 2, nil, Z + 5, hex("E2E2E2"))
				line.BorderSizePixel = 0
			end
			-- one fixed size for every word, so the table reads even (scaled text made "Knockback" smaller than the rest)
			for _, l in {
				txt(box, "Label" .. r, row[1], 8, y + 4, (w - 36) * 0.55, rowH - 8, 15, Z + 5, WHITE, Enum.TextXAlignment.Left),
				txt(box, "Value" .. r, row[2], 8 + (w - 36) * 0.55, y + 4, (w - 36) * 0.45, rowH - 8, 15, Z + 5, GOLD_TEXT, Enum.TextXAlignment.Right),
			} do
				l.TextScaled = false
				l.TextSize = 15
			end
		end
		local by = h - 72
		if weapon.equipped then
			btn(f, "Equipped", 12, by, w - 24, 56, DONE, "EQUIPPED", 30, Z + 4, nil, true)
		elseif weapon.owned then
			btn(f, "Equip", 12, by, w - 24, 56, C.azure, "EQUIP", 32, Z + 4, weapon.onEquip)
		else
			btn(f, "Buy", 12, by, w - 24, 56, C.leaf, weapon.price, 32, Z + 4, weapon.onBuy)
		end
	end
end

---------------------------------------------------------------- FEATURED
function ShopMenuComponent:_featured()
	local model, page = self.model, self.page
	-- left: the hero card (a running limited deal, else the bat tiers)
	local LW = 500
	local hero = card(page, "Hero", PAGE.X, PAGE.Y, LW, PAGE.H - 8, C.bubblegum, Z)
	H.beams(hero, LW / 2, 145, 440, Z + 2, WHITE, 0.3, 8)
	local limited = model.limited
	if limited and limited.endsAt <= os.clock() then limited = nil end
	if limited then
		if limited.eggModel then self:_egg(hero, limited.eggModel, 120, 20, 260, 240, Z + 3) end
		pill(hero, "LimitedBadge", "LIMITED", 16, 14, 136, 40, Z + 5, C.coral)
		local timerPill = H.rect(hero, "TimerPill", LW - 210, 16, 192, 38, 12, Z + 5, WHITE)
		H.ink(timerPill, 3)
		local timer = txt(timerPill, "Timer", "", 8, 3, 176, 32, 24, Z + 6, hex("F0284A"))
		self:_tick(limited.endsAt, function(secondsLeft)
			timer.Text = secondsLeft > 0 and formatDhm(secondsLeft) or "ENDED"
		end)
		H.gleam(txt(hero, "Title", string.upper(limited.name), 16, 266, LW - 32, 62, 58, Z + 5))
		txt(hero, "Subtitle", limited.text, 24, 334, LW - 48, 34, 24, Z + 5)
		btn(hero, "Buy", 70, PAGE.H - 8 - 88, LW - 140, 66, C.leaf, "BUY • " .. limited.price, 40, Z + 5, limited.onBuy)
	elseif model.featuredWeapon then
		local fw = model.featuredWeapon
		self:_weaponModel(hero, fw.key, 70, 10, LW - 140, 260, Z + 3, 0.9, 1.7, -40)
		pill(hero, "NewBadge", "NEW", 16, 14, 96, 40, Z + 5, C.coral)
		H.gleam(txt(hero, "Title", fw.title, 16, 266, LW - 32, 62, 58, Z + 5))
		txt(hero, "Subtitle", fw.text, 24, 334, LW - 48, 34, 24, Z + 5)
		btn(hero, "Buy", 70, PAGE.H - 8 - 88, LW - 140, 66, C.leaf, fw.button, 40, Z + 5, fw.onOpen)
	end

	-- right column: VIP, the two boosts, the starter pack
	local RX, RW = PAGE.X + LW + 16, PAGE.W - LW - 16
	local vip = model.vip
	local vipCard = card(page, "Vip", RX, PAGE.Y, RW, 150, C.gold, Z)
	H.beams(vipCard, 70, 75, 170, Z + 2, WHITE, 0.35, 6)
	icon(vipCard, "Crown", "IconCrown", 70, 72, 104, Z + 3):SetAttribute("Float", 72)
	H.gleam(txt(vipCard, "Title", "VIP", 138, 10, 200, 56, 52, Z + 4, nil, Enum.TextXAlignment.Left))
	txt(vipCard, "Text", vip.text, 138, 64, RW - 150, 30, 20, Z + 4, nil, Enum.TextXAlignment.Left)
	btn(vipCard, "VipBuy", RW - 196, 96, 180, 44, C.leaf, vip.owned and "OWNED" or vip.price, 28, Z + 4, vip.onBuy, vip.owned)

	local bw = (RW - 16) / 2
	for i, boost in model.boosts do
		if i > 2 then break end
		local pal = i == 1 and C.lilac or C.azure
		local bx = RX + (i - 1) * (bw + 16)
		local b = card(page, "Boost" .. i, bx, PAGE.Y + 166, bw, 170, pal, Z)
		icon(b, "Icon", i == 1 and "IconBolt" or "IconPotions", 46, 52, 70, Z + 3):SetAttribute("Wiggle", 0)
		txt(b, "Title", boost.title, 86, 14, bw - 96, 30, 26, Z + 4, nil, Enum.TextXAlignment.Left)
		local t = txt(b, "BoostText", "", 86, 48, bw - 96, 26, 20, Z + 4, GOLD_TEXT, Enum.TextXAlignment.Left)
		self:_boostText(t, boost, boost.shortText)
		btn(b, "BoostBuy", 14, 108, bw - 28, 50, C.leaf, boost.price, 30, Z + 4, boost.onBuy)
	end

	local starter = model.starter
	local sy = PAGE.Y + 352
	local s = card(page, "Starter", RX, sy, RW, PAGE.H - 8 - 352, C.mint, Z)
	local sh = PAGE.H - 8 - 352
	icon(s, "Icon", "IconStar", 54, sh / 2, 74, Z + 3):SetAttribute("Float", sh / 2)
	txt(s, "Title", starter.title, 100, 12, RW - 300, 34, 30, Z + 4, nil, Enum.TextXAlignment.Left)
	txt(s, "StarterText", starter.text, 100, 48, RW - 300, 50, 20, Z + 4, nil, Enum.TextXAlignment.Left, true)
	btn(s, "StarterBuy", RW - 192, sh / 2 - 28, 176, 56, C.leaf, starter.owned and "OWNED" or starter.price, 30, Z + 4, starter.onBuy, starter.owned)
end

---------------------------------------------------------------- BOOSTS
function ShopMenuComponent:_boostsPage()
	local model, page = self.model, self.page
	local bw = (PAGE.W - 16) / 2
	for i, boost in model.boosts do
		if i > 2 then break end
		local pal = i == 1 and C.lilac or C.azure
		local b = card(page, "Boost" .. i, PAGE.X + (i - 1) * (bw + 16), PAGE.Y, bw, 230, pal, Z)
		H.beams(b, 74, 86, 160, Z + 2, WHITE, 0.4, 6)
		icon(b, "Icon", i == 1 and "IconBolt" or "IconPotions", 74, 86, 104, Z + 3):SetAttribute("Float", 86)
		H.gleam(txt(b, "Title", boost.title, 146, 16, bw - 160, 46, 40, Z + 4, nil, Enum.TextXAlignment.Left))
		txt(b, "Text", boost.text, 146, 64, bw - 160, 60, 22, Z + 4, nil, Enum.TextXAlignment.Left, true)
		local timer = txt(b, "Timer", "", 146, 126, bw - 160, 26, 22, Z + 4, GOLD_TEXT, Enum.TextXAlignment.Left)
		self:_boostText(timer, boost, "")
		btn(b, "Buy", 146, 160, bw - 166, 56, C.leaf, boost.price, 32, Z + 4, boost.onBuy)
	end

	local hatch = model.hatch
	local hy = PAGE.Y + 246
	local hRow = card(page, "Hatch", PAGE.X, hy, PAGE.W, 118, C.mint, Z)
	H.gleam(txt(hRow, "HatchTitle", "HATCH SPEED", 22, 14, 360, 44, 40, Z + 4, nil, Enum.TextXAlignment.Left))
	txt(hRow, "HatchValue", hatch.value .. "  ·  permanent", 22, 62, 360, 34, 26, Z + 4, GOLD_TEXT, Enum.TextXAlignment.Left)
	local pipSize = math.min(30, math.floor(320 / math.max(hatch.maxLevel, 1)) - 4)
	pips(hRow, 400, 59 - pipSize / 2, pipSize, 4, hatch.level, hatch.maxLevel, Z + 4)
	btn(hRow, "HatchBuy", PAGE.W - 236, 28, 216, 62, C.leaf, hatch.maxed and "MAXED" or hatch.price, 32, Z + 4, hatch.onBuy, hatch.maxed)

	local starter = model.starter
	local sy = hy + 134
	local sRow = card(page, "Starter", PAGE.X, sy, PAGE.W, PAGE.H - 8 - (sy - PAGE.Y), C.bubblegum, Z)
	local sh = PAGE.H - 8 - (sy - PAGE.Y)
	icon(sRow, "Icon", "IconStar", 60, sh / 2, 80, Z + 3):SetAttribute("Float", sh / 2)
	H.gleam(txt(sRow, "StarterTitle", starter.title, 112, 14, PAGE.W - 380, 44, 40, Z + 4, nil, Enum.TextXAlignment.Left))
	txt(sRow, "StarterText", starter.text, 112, 60, PAGE.W - 380, 30, 24, Z + 4, nil, Enum.TextXAlignment.Left)
	btn(sRow, "StarterBuy", PAGE.W - 236, sh / 2 - 31, 216, 62, C.leaf, starter.owned and "OWNED" or starter.price, 32, Z + 4, starter.onBuy, starter.owned)
end

---------------------------------------------------------------- PASSES
function ShopMenuComponent:_passesPage()
	local model, page = self.model, self.page
	local w = (PAGE.W - 16) / 2
	local h = PAGE.H - 8
	local vip = model.vip
	local v = card(page, "Vip", PAGE.X, PAGE.Y, w, h, C.gold, Z)
	H.beams(v, w / 2, 130, 330, Z + 2, WHITE, 0.3, 8)
	icon(v, "Crown", "IconCrown", w / 2, 130, 190, Z + 3):SetAttribute("Float", 130)
	H.gleam(txt(v, "VipTitle", "VIP", 20, 236, w - 40, 84, 84, Z + 4))
	txt(v, "VipText", vip.perks, 30, 322, w - 60, 66, 24, Z + 4, nil, nil, true)
	btn(v, "VipBuy", 60, h - 88, w - 120, 66, C.leaf, vip.owned and "OWNED" or vip.price, 38, Z + 4, vip.onBuy, vip.owned)

	local money = model.money
	local m = card(page, "Money", PAGE.X + w + 16, PAGE.Y, w, h, C.leaf, Z)
	H.gleam(txt(m, "MoneyTitle", "MONEY MULTIPLIER", 20, 16, w - 40, 48, 40, Z + 4))
	H.beams(m, w / 2, 160, 240, Z + 2, WHITE, 0.4, 6)
	icon(m, "Coins", "IconCoins", w / 2, 160, 150, Z + 3):SetAttribute("Float", 160)
	txt(m, "MoneyValue", money.value, 20, 250, w - 40, 50, 44, Z + 4, GOLD_TEXT)
	local size = math.min(34, math.floor((w - 60) / math.max(money.maxLevel, 1)) - 8)
	local rowWidth = money.maxLevel * size + (money.maxLevel - 1) * 8
	pips(m, (w - rowWidth) / 2, 314, size, 8, money.level, money.maxLevel, Z + 4)
	txt(m, "MoneyLevel", money.levelText, 20, 314 + size + 16, w - 40, 30, 24, Z + 4)
	btn(m, "MoneyBuy", 60, h - 88, w - 120, 66, C.mango, money.maxed and "MAXED" or money.price, 38, Z + 4, money.onBuy, money.maxed)
end

---------------------------------------------------------------- CASH
function ShopMenuComponent:_cashPage()
	local page = self.page
	local packs = self.model.cash
	local gap = 16
	local w = (PAGE.W - gap * 2) / 3
	local h = PAGE.H - 8
	local pals = { C.aqua, C.leaf, C.gold }
	for i, pack in packs do
		if i > 3 then break end
		local f = card(page, "Pack" .. i, PAGE.X + (i - 1) * (w + gap), PAGE.Y, w, h, pals[i], Z)
		local big = i == #packs
		H.beams(f, w / 2, 150, big and 330 or 250, Z + 2, WHITE, big and 0.25 or 0.4, big and 8 or 6)
		icon(f, "Coins", "IconCoins", w / 2, 150, 110 + i * 30, Z + 3):SetAttribute("Float", 150)
		if pack.badge then pill(f, "Badge", pack.badge, w / 2 - 70, 12, 140, 36, Z + 5, C.coral) end
		H.gleam(txt(f, "Amount", pack.amount, 14, 268, w - 28, 66, 60, Z + 4, GOLD_TEXT))
		txt(f, "Text", pack.text, 14, 336, w - 28, 30, 22, Z + 4)
		if big then f:SetAttribute("Glint", true) end
		btn(f, "Buy", 26, h - 84, w - 52, 62, C.leaf, pack.price, 34, Z + 4, pack.onBuy, pack.onBuy == nil)
	end
end

---------------------------------------------------------------- DAILY
-- 2026-11-07 clean pass: days 1-6 in a 3 x 2 grid, day 7 as one tall prize card, and a bottom bar like the Quests page
-- (white timer box on the left, CLAIM / CLAIMED on the right). FOLK tick and lock badges replace the emoji marks.
local DAY_PAL = { claimed = DONE, today = C.mango, locked = C.azure }
local DAY_ICON = { cash = "IconCoins", money = "IconBolt", hatch = "IconPotions", mystery = "IconGift" }
-- a small sticker badge (black outline + drop) in a card's corner
local function badge(parent, pieceName, cx, cy, size, z)
	local h = H.new("Frame", { Name = "Badge", BackgroundTransparency = 1, Position = UDim2.fromOffset(cx, cy), Size = UDim2.fromOffset(0, 0), ZIndex = z }, parent)
	for _, d in { { 0, 4, 0.5 }, { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } } do
		H.art(h, "Ink", FOLK[pieceName], d[1], d[2], size, z, d[3]).ImageColor3 = BLACK
	end
	H.art(h, "Art", FOLK[pieceName], 0, 0, size, z)
	return h
end
-- the "DAY n" tag in a card's top-left: white words, sharp dark plate
local function dayTag(parent, word, z)
	local t = H.rect(parent, "DayTag", 10, 10, 86, 32, nil, z, BLACK)
	t.BackgroundTransparency = 0.25
	txt(t, "Label", word, 6, 2, 74, 28, 24, z + 1)
	return t
end
-- the value in a white strip along the bottom of a card (reads like the reward boxes on the Quests page)
local function valueStrip(parent, value, col, w, h, z)
	local strip = H.rect(parent, "ValueStrip", 10, h - 48, w - 20, 38, nil, z, WHITE)
	H.ink(strip, 3)
	txt(strip, "Value", value, 14, 4, w - 48, 30, 26, z + 1, col)
	return strip
end
function ShopMenuComponent:_dailyPage()
	local page, daily = self.page, self.model.daily
	local days = daily.days or {}
	H.gleam(txt(page, "Intro", Config.Daily.IntroText, PAGE.X, PAGE.Y - 2, PAGE.W, 32, 28, Z + 2, nil))

	local gap = 14
	local barH = 66
	local barY = PAGE.Y + PAGE.H - 8 - barH
	local top = PAGE.Y + 40
	local gridH = barY - gap - top
	local bigW = 290
	local w = (PAGE.W - bigW - gap * 3) / 3
	local h = (gridH - gap) / 2

	for i = 1, math.min(#days, 7) do
		local day = days[i]
		local state = DAY_PAL[day.state] and day.state or "locked"
		local isBig = i == 7
		local x, y, cw, ch
		if isBig then
			x, y, cw, ch = PAGE.X + 3 * (w + gap), top, bigW, gridH
		else
			local col, row = (i - 1) % 3, (i - 1) // 3
			x, y, cw, ch = PAGE.X + col * (w + gap), top + row * (h + gap), w, h
		end
		-- day 7 is the prize: gold until it is claimed
		local pal = DAY_PAL[state]
		if isBig and state == "locked" then pal = C.gold end
		local f = card(page, "Day" .. i, x, y, cw, ch, pal, Z)
		if state == "today" then goldOutline(f) end
		if isBig or state == "today" then
			H.beams(f, cw / 2, isBig and ch * 0.42 or ch / 2 - 6, isBig and cw * 1.1 or ch * 1.15, Z + 2, WHITE, 0.3, isBig and 8 or 6)
		end
		dayTag(f, day.label, Z + 4)
		if state == "claimed" then
			badge(f, "IconCheck", cw - 28, 26, 46, Z + 5)
		elseif state == "locked" then
			badge(f, "IconLock", cw - 27, 26, 36, Z + 5)
		else
			pill(f, "Today", "TODAY", cw - 106, 10, 96, 32, Z + 5, C.coral)
		end
		local iconName = DAY_ICON[string.lower(tostring(day.kind or ""))] or "IconStar"
		local iconY = isBig and ch * 0.42 or ch / 2 - 6
		local iconSize = isBig and 170 or math.min(ch - 104, 92)
		local ic = icon(f, "Icon", iconName, cw / 2, iconY, iconSize, Z + 3)
		if ic and (state == "today" or isBig) then ic:SetAttribute("Float", iconY) end
		if isBig then
			H.gleam(txt(f, "Prize", "BIG REWARD", 14, ch - 112, cw - 28, 40, 34, Z + 4))
		end
		valueStrip(f, day.value, day.valueColor or WHITE, cw, ch, Z + 4)
	end

	-- bottom bar: next-reward timer on the left, the claim button on the right
	local timerW = 420
	local box = H.rect(page, "TimerBox", PAGE.X, barY, timerW, barH, nil, Z + 2, WHITE)
	H.ink(box, 4)
	badge(box, "IconClock", 36, barH / 2, 40, Z + 3)
	local timer = txt(box, "Next", "", 66, 6, timerW - 80, barH - 12, 30, Z + 3, nil, Enum.TextXAlignment.Left)
	local bw = 330
	if daily.ready then
		timer.Text = "Your reward is ready!"
		timer.TextColor3 = GOLD_TEXT
		local b = btn(page, "Claim", PAGE.X + PAGE.W - bw, barY, bw, barH, C.leaf, daily.claimText, 38, Z + 4, daily.onClaim)
		b:SetAttribute("Glint", true)
	else
		btn(page, "Claim", PAGE.X + PAGE.W - bw, barY, bw, barH, DONE, "CLAIMED", 38, Z + 4, nil, true)
		self:_tick(daily.nextEnds, function(secondsLeft)
			timer.Text = "Next reward in " .. formatHms(secondsLeft)
		end)
	end
end

local PAGES = {
	WEAPONS = ShopMenuComponent._weaponsPage,
	FEATURED = ShopMenuComponent._featured,
	BOOSTS = ShopMenuComponent._boostsPage,
	PASSES = ShopMenuComponent._passesPage,
	CASH = ShopMenuComponent._cashPage,
	DAILY = ShopMenuComponent._dailyPage,
}

---------------------------------------------------------------- the sheet, title, X and tabs
function ShopMenuComponent:_buildTabs()
	local x0, y0, gap, h = 40, 70, 10, 60
	local w = (CW - 80 - gap * (#TABS - 1)) / #TABS
	for i, tab in TABS do
		local selected = self.model.tab == tab.key
		local x = x0 + (i - 1) * (w + gap)
		local b = H.button(self.canvas, "Tab_" .. tab.key, x, y0, w, h, 14, tab.pal, Z + 3, { lip = 6, studs = 0.7 })
		if selected then
			local o = b:FindFirstChild("Outline")
			if o then o.Color, o.Thickness = hex("FFC400"), 5 end
			b.Size = UDim2.fromOffset(w + 6, h + 6)
		end
		b.Activated:Connect(function() self.model.onTab(tab.key) end)
		if tab.model then
			self:_weaponModel(b, tab.model, 6, 4, 48, 48, b.ZIndex + 2, nil, 1.5, -45)
		else
			icon(b, "Icon", tab.icon, 32, 27, 42, b.ZIndex + 2)
		end
		txt(b, "Label", tab.text, 58, 6, w - 66, h - 18, 28, b.ZIndex + 3, nil, Enum.TextXAlignment.Left)
		if tab.key == "DAILY" and self.model.daily.ready then
			local dot = H.circle(self.canvas, "Alert", x + w - 4, y0 - 2, 30, Z + 6, C.coral[1], C.coral[2], 3)
			txt(dot, "Mark", "!", 0, 0, 30, 30, 24, Z + 7)
			dot:SetAttribute("Wiggle", 0)
		end
	end
end

function ShopMenuComponent.new(panel, layer, model)
	local self = setmetatable({ model = model, panel = panel, alive = true }, ShopMenuComponent)
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

	local canvas = H.new("Frame", { Name = "ShopCanvas", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(CW, CH), ZIndex = Z }, nil)
	local scale = H.new("UIScale", {}, canvas)
	local function fit() scale.Scale = math.max(panel.Size.X.Offset, 1) / CW end
	fit()
	self.sizeConnection = panel:GetPropertyChangedSignal("Size"):Connect(fit)
	self.canvas = canvas

	-- the white studded sheet
	H.shadow(canvas, "Sheet", 0, 0, CW, CH, 26, Z - 2)
	local sheet = H.rect(canvas, "Background", 0, 0, CW, CH, 26, Z - 1, WHITE)
	H.ink(sheet, 5)
	H.studs(sheet, Vector2.new(50, 46), 0.8, 26, Z - 1)
	-- the title sits on the top border, the crown hangs over the corner, the X over the other corner
	H.beams(canvas, 52, 18, 190, Z + 1, hex("FFD000"), 0.35, 6)
	local crown = icon(canvas, "HeaderIcon", "IconCrown", 52, 16, 120, Z + 2)
	crown:SetAttribute("Float", 16)
	local title = H.text(canvas, "HeaderTitle", "SHOP", CW / 2, 6, 72, Z + 4, WHITE)
	H.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(WHITE, hex("FFE14D")) }, title)
	H.gleam(title)
	local x = H.rect(canvas, "CloseArt", CLOSE[1], CLOSE[2], CLOSE[3], CLOSE[4], 14, Z + 6, WHITE)
	H.grad(x, C.red[1], C.red[2])
	H.ink(x, 4)
	txt(x, "X", "X", 0, 2, CLOSE[3], CLOSE[4] - 6, 54, Z + 7)

	self:_buildTabs()
	local page = H.new("Frame", { Name = "Page", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = Z }, canvas)
	self.page = page
	PAGES[model.tab](self)

	-- FigmaSkin restyles dark frames and buttons inside the menu panels: this window opts out, every piece of it
	for _, d in canvas:GetDescendants() do
		if d:IsA("GuiObject") then d:SetAttribute("NoSkin", true); d:SetAttribute("FS", true) end
	end
	canvas:SetAttribute("NoSkin", true)
	M.animate(canvas, { sound = function(kind) UISound.Play(kind == "hover" and "Hover" or "Click") end })
	canvas.Parent = layer
	return self
end

function ShopMenuComponent:Destroy()
	self.alive = false
	self.sizeConnection:Disconnect()
	self.canvas:Destroy()
end

return ShopMenuComponent
