-- StudPolish ([TESTER], Folk Stud restyle 2026-11-07)
-- Fixes that apply to every UI in the game, menus, HUD and world labels alike:
--  1. Font: every Fredoka One text becomes Gotham Black (GothamSSm Heavy), the font the owner picked.
--  2. Studs: every tiled stud layer is snapped to a whole number of tiles, so no stud is ever cut at an edge,
--     and a stud layer that fills a rounded frame gets the same rounded corners, so no studs poke out.
--  3. Colours: no "AI look" indigo / violet / emerald, no hue-drifting gradients (see the colours section).
-- Nothing is rebuilt: other scripts keep making their UI, this only adjusts it as it appears.

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local GOTHAM = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)

-- tiled images that are stud textures (a layer named like "Studs" counts too)
local STUD_IMAGES = {
	["rbxassetid://3014551673"] = true, -- 2 x 2 studs per tile (FolkStudUI, EggLabel, plates, world skin)
	["rbxassetid://132561191216691"] = true, -- the older stud tile
}

------------------------------------------------------------------ fonts

local function isFredoka(face)
	return string.find(face.Family, "FredokaOne", 1, true) ~= nil
end

local fontWatched = setmetatable({}, { __mode = "k" })

local function swapFont(t)
	if isFredoka(t.FontFace) then
		t.FontFace = GOTHAM
	end
end

local function watchText(t)
	if fontWatched[t] then return end
	fontWatched[t] = true
	swapFont(t)
	-- scripts that set the font again later (Font or FontFace) get swapped back
	t:GetPropertyChangedSignal("FontFace"):Connect(function() swapFont(t) end)
end

------------------------------------------------------------------ studs

-- Softer studs (2026-11-08, owner: "lower the sharpness a little"): every stud layer shows this much of the strength its
-- own script asked for. 1 = the old look, lower = fainter. Change only this number.
local STUD_STRENGTH = 0.75

local studWatched = setmetatable({}, { __mode = "k" })
local softSet = setmetatable({}, { __mode = "k" }) -- the ImageTransparency this script last set, per image

local function soften(img)
	if img.ImageTransparency == softSet[img] then return end
	local asked = img.ImageTransparency -- what the owning script set
	local soft = 1 - (1 - asked) * STUD_STRENGTH
	softSet[img] = soft
	img.ImageTransparency = soft
end
local ours = setmetatable({}, { __mode = "k" }) -- the TileSize this script last set, per image

local function isStudLayer(img)
	if img.ScaleType ~= Enum.ScaleType.Tile then return false end
	return STUD_IMAGES[img.Image] or string.find(string.lower(img.Name), "stud", 1, true) ~= nil
end

-- the product of every UIScale between the image and its LayerCollector,
-- so the tile count is worked out in design units and does not change while a window pops
local function scaleOf(g)
	local s = 1
	local p = g
	while p and not p:IsA("LayerCollector") do
		local u = p:FindFirstChildOfClass("UIScale")
		if u then s *= u.Scale end
		p = p.Parent
	end
	return s
end

-- reads what the owning script asked for: an offset tile (design px) or a scale tile (fraction of the layer)
local function readTarget(img)
	local ts = img.TileSize
	if ts.X.Offset > 0 and ts.Y.Offset > 0 then
		img:SetAttribute("StudTile", Vector2.new(ts.X.Offset, ts.Y.Offset))
		img:SetAttribute("StudTileScale", nil)
	elseif ts.X.Scale > 0 and ts.Y.Scale > 0 then
		img:SetAttribute("StudTileScale", Vector2.new(ts.X.Scale, ts.Y.Scale))
		img:SetAttribute("StudTile", nil)
	end
end

-- a stud layer that fills a rounded frame takes the frame's corners (minus its inset), or it pokes out at the corners
local function clipCorners(img)
	local parent = img.Parent
	if not (parent and parent:IsA("GuiObject")) then return end
	local mine = img:FindFirstChild("StudClip")
	local own = img:FindFirstChildOfClass("UICorner")
	if own and own ~= mine then return end -- the owner already rounded it
	local pc = parent:FindFirstChildOfClass("UICorner")
	local size = img.Size
	local fills = size.X.Scale == 1 and size.Y.Scale == 1 and size.X.Offset <= 0 and size.Y.Offset <= 0
	if not (pc and fills) then
		if mine then mine:Destroy() end
		return
	end
	local inset = -size.X.Offset / 2
	local r = pc.CornerRadius
	local radius = UDim.new(r.Scale, math.max(0, r.Offset - inset))
	if not mine then
		mine = Instance.new("UICorner")
		mine.Name = "StudClip"
		mine.Parent = img
	end
	mine.CornerRadius = radius
end

local function fit(img)
	if not img.Parent then return end
	local scaleT = img:GetAttribute("StudTileScale")
	local nx, ny
	if scaleT then
		-- scale tiles already follow the layer's size: just make them divide it evenly
		nx = math.max(1, math.floor(1 / scaleT.X + 0.5))
		ny = math.max(1, math.floor(1 / scaleT.Y + 0.5))
	else
		local target = img:GetAttribute("StudTile")
		if not target then return end
		local abs = img.AbsoluteSize
		if abs.X < 2 or abs.Y < 2 then return end
		local s = scaleOf(img)
		if s <= 0.01 then return end
		nx = math.max(1, math.floor(abs.X / s / target.X + 0.5))
		ny = math.max(1, math.floor(abs.Y / s / target.Y + 0.5))
	end
	local want = UDim2.fromScale(1 / nx, 1 / ny)
	if img.TileSize ~= want then
		ours[img] = want
		img.TileSize = want
	end
	clipCorners(img)
end

local function watchStud(img)
	if studWatched[img] then return end
	studWatched[img] = true
	readTarget(img)
	fit(img)
	soften(img)
	img:GetPropertyChangedSignal("ImageTransparency"):Connect(function() soften(img) end)
	img:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() fit(img) end)
	img:GetPropertyChangedSignal("Size"):Connect(function() fit(img) end)
	img:GetPropertyChangedSignal("TileSize"):Connect(function()
		if img.TileSize ~= ours[img] then -- the owning script changed it: take that as the new target
			readTarget(img)
			fit(img)
		end
	end)
	img.AncestryChanged:Connect(function() if img.Parent then fit(img) end end)
	local parent = img.Parent
	if parent then
		parent.ChildAdded:Connect(function(c) if c:IsA("UICorner") then fit(img) end end)
		parent.ChildRemoved:Connect(function(c) if c:IsA("UICorner") then task.defer(fit, img) end end)
	end
end

local function maybeStud(img)
	if isStudLayer(img) then
		watchStud(img)
		return
	end
	-- the image or scale type may be set just after the layer is made
	local conns = {}
	local function check()
		if isStudLayer(img) then
			for _, c in conns do c:Disconnect() end
			watchStud(img)
		end
	end
	table.insert(conns, img:GetPropertyChangedSignal("Image"):Connect(check))
	table.insert(conns, img:GetPropertyChangedSignal("ScaleType"):Connect(check))
end

------------------------------------------------------------------ colours
-- The owner asked to drop the "AI look" colours (2026-11-07). Those are the indigo / violet buttons and purple
-- gradients from the Tailwind UI defaults (indigo-500, violet, emerald-500, sky-500), dark purple backgrounds, and
-- gradients that drift from one hue to another. Every UI colour goes through here:
--  * known kit colours get a toy-brick replacement (each gradient keeps one hue, only lighter on top)
--  * any other violet / indigo: bright ones turn grape (warmer, nearer magenta), dark ones turn warm charcoal
-- Pictures (ImageColor3) and rarity colours are left alone.

local function hexc(s) return Color3.fromHex(s) end
local REMAP = {}
local function swap(old, new) REMAP[string.lower(old)] = hexc(new) end
-- coral: rose -> tomato brick
swap("FF5A6E", "FF4A3D"); swap("F0284A", "E3261B"); swap("8F1229", "8A1209")
-- azure / blue: drop the blue-600 bottom, keep one hue
swap("35A8FF", "2E9BFF"); swap("1B6BF5", "0B72E8"); swap("0C3A99", "053E85")
swap("005DF9", "0B72E8"); swap("00379E", "053E85")
-- mint (emerald-500) -> jade
swap("2FE6A8", "1ED6B8"); swap("0DBF80", "0AAE95"); swap("04704A", "05604F")
-- the game green (emerald) -> grass
swap("12D67A", "2BD14A"); swap("03AE59", "13A831"); swap("006E37", "0A5C1A")
-- mango: yellow -> orange drift -> one orange
swap("FFC43D", "FFB52E"); swap("FF8F1F", "F58C00"); swap("A65200", "8F4E00")
-- lilac + the kit purple (violet / indigo) -> grape
-- (deep grape, so it never reads as the bubblegum pink beside it)
swap("B08CFF", "C83CEB"); swap("7C4DF2", "9C10C4"); swap("44228F", "640878")
swap("9C31FB", "C83CEB"); swap("6C0FE3", "9C10C4"); swap("410891", "640878")
-- dark purple inks -> warm charcoal
swap("3A3150", "3A3330"); swap("241D35", "26211D"); swap("120E1C", "14110F")

local VIOLET_LO, VIOLET_HI = 230 / 360, 282 / 360
local GRAPE = 288 / 360

local function recolour(c)
	local hit = REMAP[string.lower(c:ToHex())]
	if hit then return hit end
	local h, s, v = c:ToHSV()
	if s >= 0.3 and v >= 0.06 and h >= VIOLET_LO and h <= VIOLET_HI then
		if v >= 0.5 then
			return Color3.fromHSV(GRAPE, s, v * 0.88)
		end
		return Color3.fromHSV(25 / 360, math.min(s, 0.18), v)
	end
	-- muted lavender / periwinkle (the "Common" chip and the like) -> plain grey of the same lightness
	if s >= 0.1 and s < 0.55 and h >= 215 / 360 and h <= VIOLET_HI then
		return Color3.fromHSV(0, 0, v)
	end
	return nil
end

-- guis that are Studio / dev tools, not the game
local SKIP_GUIS = { ReplayModeUI = true, AdminTerminal = true, GalaxyReferenceCredit = true }

local function skipped(d)
	local g = d:FindFirstAncestorWhichIsA("LayerCollector")
	return g ~= nil and SKIP_GUIS[g.Name] == true
end

local function watchColour(obj, prop)
	local function apply()
		local new = recolour(obj[prop])
		if new then obj[prop] = new end
	end
	apply()
	obj:GetPropertyChangedSignal(prop):Connect(apply)
end

local function watchGradient(g)
	local function apply()
		local kps = g.Color.Keypoints
		local changed = false
		local out = table.create(#kps)
		for i, kp in kps do
			local new = recolour(kp.Value)
			if new then changed = true end
			out[i] = ColorSequenceKeypoint.new(kp.Time, new or kp.Value)
		end
		if changed then g.Color = ColorSequence.new(out) end
	end
	apply()
	g:GetPropertyChangedSignal("Color"):Connect(apply)
end

local colourWatched = setmetatable({}, { __mode = "k" })

local function handleColour(d)
	if colourWatched[d] then return end
	if d:IsA("GuiObject") then
		colourWatched[d] = true
		watchColour(d, "BackgroundColor3")
		if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then watchColour(d, "TextColor3") end
	elseif d:IsA("UIStroke") then
		colourWatched[d] = true
		watchColour(d, "Color")
	elseif d:IsA("UIGradient") then
		colourWatched[d] = true
		watchGradient(d)
	end
end

------------------------------------------------------------------ matching labels
-- Gotham is wider than Fredoka, so in a row of scaled labels (shop tabs, button rows) a long word like
-- "Weapons" shrank smaller than "Boosts". Labels with the same name, in siblings named alike, share one size:
-- the largest size at which every one of them fits. Only rows of 3 to 8 short words (not grids or sentences).

local TextService = game:GetService("TextService")
local groups = setmetatable({}, { __mode = "k" }) -- row holder -> key -> { labels = {}, pending = bool }
local groupOf = setmetatable({}, { __mode = "k" })

local function prefix(name)
	return (string.match(name, "^(.-)[_%d]") or name)
end

local function bestSize(label, cap)
	local abs = label.AbsoluteSize
	if abs.X < 2 or abs.Y < 2 or label.ContentText == "" then return nil end
	local s = scaleOf(label)
	if s <= 0.01 then return nil end
	local w, h = abs.X / s, abs.Y / s
	local pad = label:FindFirstChildOfClass("UIPadding")
	if pad then
		w -= pad.PaddingLeft.Offset + pad.PaddingRight.Offset + (pad.PaddingLeft.Scale + pad.PaddingRight.Scale) * w
		h -= pad.PaddingTop.Offset + pad.PaddingBottom.Offset + (pad.PaddingTop.Scale + pad.PaddingBottom.Scale) * h
	end
	local frame = label.TextWrapped and Vector2.new(w, 1e5) or Vector2.new(1e5, 1e5)
	local lo, hi = 1, cap
	while lo < hi do
		local mid = math.ceil((lo + hi) / 2)
		local b = TextService:GetTextSize(label.ContentText, mid, Enum.Font.GothamBlack, frame)
		if b.X <= w + 0.5 and b.Y <= h + 0.5 then lo = mid else hi = mid - 1 end
	end
	return lo
end

local function refitGroup(g)
	g.pending = false
	local live = {}
	for label in g.labels do
		if label.Parent then table.insert(live, label) else g.labels[label] = nil end
	end
	local short = true -- only short words (tabs, chips, button words); rows of sentences keep their own sizes
	for _, label in live do
		if utf8.len(label.ContentText) and utf8.len(label.ContentText) > 14 then short = false end
	end
	if #live < 3 or #live > 8 or not short then
		for _, label in live do -- not a row any more: give it back its own scaling
			if label:GetAttribute("StudSharedSize") then
				label:SetAttribute("StudSharedSize", nil)
				label.TextScaled = true
			end
		end
		return
	end
	local size
	for _, label in live do
		local c = label:FindFirstChildOfClass("UITextSizeConstraint")
		local cap = label:GetAttribute("StudCap") or (c and c.MaxTextSize) or 100
		label:SetAttribute("StudCap", cap)
		local b = bestSize(label, cap)
		if b then size = math.min(size or b, b) end
	end
	if not size then return end
	for _, label in live do
		label:SetAttribute("StudSharedSize", size)
		label.TextScaled = false
		label.TextSize = size
	end
end

local function queueGroup(g)
	if g.pending then return end
	g.pending = true
	task.defer(refitGroup, g)
end

local function joinGroup(label)
	if groupOf[label] or not (label.TextScaled or label:GetAttribute("StudSharedSize")) then return end
	local parent = label.Parent
	local grand = parent and parent.Parent
	if not (parent and grand and parent:IsA("GuiObject")) then return end
	local key = prefix(parent.Name) .. "|" .. label.Name
	local byKey = groups[grand]
	if not byKey then
		byKey = {}
		groups[grand] = byKey
	end
	local g = byKey[key]
	if not g then
		g = { labels = setmetatable({}, { __mode = "k" }), pending = false }
		byKey[key] = g
	end
	g.labels[label] = true
	groupOf[label] = g
	label:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() queueGroup(g) end)
	label:GetPropertyChangedSignal("ContentText"):Connect(function() queueGroup(g) end)
	label.AncestryChanged:Connect(function() queueGroup(g) end)
	queueGroup(g)
end

------------------------------------------------------------------ wiring

local function handle(d)
	if (d:IsA("GuiObject") or d:IsA("UIStroke") or d:IsA("UIGradient")) and not skipped(d) then
		handleColour(d)
	end
	if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
		watchText(d)
		if not d:IsA("TextBox") then
			-- after the owning script has finished naming and parenting it
			task.defer(function()
				if d.Parent and d.FontFace.Family == GOTHAM.Family and d.FontFace.Weight == GOTHAM.Weight and d:FindFirstAncestorWhichIsA("ScreenGui") then
					joinGroup(d)
				end
			end)
		end
	elseif d:IsA("ImageLabel") or d:IsA("ImageButton") then
		maybeStud(d)
	end
end

local function cover(root)
	root.DescendantAdded:Connect(handle)
	local list = root:GetDescendants()
	for i, d in list do
		handle(d)
		if i % 2000 == 0 then task.wait() end
	end
end

cover(playerGui)
task.spawn(cover, workspace) -- billboards and signs on plots, eggs, leaderboards
