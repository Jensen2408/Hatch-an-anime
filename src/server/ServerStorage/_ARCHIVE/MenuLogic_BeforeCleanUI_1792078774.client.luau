-- StarterGui.GameMenus.MenuLogic (LocalScript)
-- Opens/closes the four ForgeGUI panels and fills them with live data from
-- ServerScriptService.GameMenu (GetState / Action / Changed remotes).
-- All positions below are fractions of each panel image, so they scale with it.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = script.Parent
local dim = gui:WaitForChild("Dim")
local side = gui:WaitForChild("SideButtons")
-- Modal panels must cover HUDs from other ScreenGuis, including Settings.
local hudDisplayOrder = gui.DisplayOrder
local function updateOverlayOrder()
	gui.DisplayOrder = dim.Visible and math.max(60, hudDisplayOrder) or hudDisplayOrder
end
dim:GetPropertyChangedSignal("Visible"):Connect(updateOverlayOrder)
updateOverlayOrder()
-- Use the safe area's height as well as width: wide phones are still short.
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
local SHOP_PHONE_WIDTH = 680
local closing -- panel playing its close tween
local sideScale = Instance.new("UIScale")
sideScale.Name = "ResponsiveScale"
sideScale.Parent = side
local function layoutMenus()
	local v = gui.AbsoluteSize
	if v.X <= 0 or v.Y <= 0 then return end
	local compact = math.min(v.X, v.Y) < 600
	local s = compact and math.min(1, v.X / 600, v.Y / 560) or 1
	-- Phone buttons are 20% smaller; desktop keeps its original size.
	sideScale.Scale = compact and s * 0.8 or s
	side.AnchorPoint = compact and Vector2.new(0, 0) or Vector2.new(0, 0.5)
	side.Position = compact and UDim2.fromOffset(10, 10) or UDim2.new(0, 16, 0.5, 0)
	for _, name in { "Plot", "Index", "Quests", "VipShop" } do
		local panel = gui:FindFirstChild(name)
		if panel then
			local ratio = panel.UIAspectRatioConstraint.AspectRatio
			local width = math.min(1000, v.X * 0.86, (v.Y - 32) * ratio)
			-- The shop is laid out in pixels, so on phones it is built at a fixed design width
			-- and shrunk with its UIScale ("Fit") instead of squeezing the panel.
			local design = (compact and name == "VipShop") and SHOP_PHONE_WIDTH or nil
			if design then width = math.min(width, v.X * 0.8, (v.Y - 48) * ratio) end
			local fit = design and width / design or 1
			local w = design or width
			panel.Size = UDim2.fromOffset(math.max(1, w), math.max(1, w / ratio))
			panel:SetAttribute("Fit", fit)
			if panel.Visible and panel ~= closing then panel.UIScale.Scale = fit end
		end
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layoutMenus)
layoutMenus()
local remotes = RS:WaitForChild("GameMenu"):WaitForChild("Remotes")
local GetState, Action, Changed = remotes:WaitForChild("GetState"), remotes:WaitForChild("Action"), remotes:WaitForChild("Changed")
local Config = require(RS.GameMenu.Config)
local UISound = require(RS:WaitForChild("UISound"))

-- ADD STUDS: put the stud pattern inside any frame.   addStuds(frame, size, strength)
--   size = stud size in pixels (smaller = smaller studs) · strength: 0 = strong, 1 = invisible
local function addStuds(frame, size, strength)
	do return end
	local im = Instance.new("ImageLabel")
	im.Name = "StudPattern"; im.BackgroundTransparency = 1
	im.Image = "rbxassetid://95251902376685"; im.ScaleType = Enum.ScaleType.Tile
	im.TileSize = UDim2.fromOffset(size or 18, size or 18); im.ImageTransparency = strength or 0.5
	im.Size = UDim2.fromScale(1, 1); im.ZIndex = frame.ZIndex
	local c = frame:FindFirstChildOfClass("UICorner"); if c then c:Clone().Parent = im end
	im.Parent = frame
	return im
end
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")
local INK = Color3.fromRGB(74, 44, 30)
local CREAM = Color3.fromRGB(253, 240, 214)
local GREEN = Color3.fromRGB(110, 200, 60)
local GREY = Color3.fromRGB(150, 140, 130)
local RARITY = { Common = Color3.fromRGB(150, 155, 165), Uncommon = Color3.fromRGB(70, 180, 70), Rare = Color3.fromRGB(60, 130, 230), Epic = Color3.fromRGB(150, 80, 220), Legendary = Color3.fromRGB(235, 175, 30) }

local function new(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function box(parent, cx, cy, w, h, props)
	props = props or {}
	local class = props.Class or "Frame"; props.Class = nil
	props.AnchorPoint = Vector2.new(0.5, 0.5)
	props.Position = UDim2.fromScale(cx, cy)
	props.Size = UDim2.fromScale(w, h)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.BorderSizePixel = 0
	props.ZIndex = props.ZIndex or 7
	return new(class, props, parent)
end
local function text(parent, str, color, props)
	props = props or {}
	local l = new("TextLabel", {
		BackgroundTransparency = 1, Size = props.Size or UDim2.fromScale(1, 1), Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(), FontFace = FONT, Text = str, TextColor3 = color or INK,
		TextScaled = true, TextWrapped = true, TextXAlignment = props.X or Enum.TextXAlignment.Center, ZIndex = props.ZIndex or 8,
	}, parent)
	new("UITextSizeConstraint", { MaxTextSize = props.Max or 22 }, l)
	if props.Stroke and props.Stroke > 0 then new("UIStroke", { Color = INK, Thickness = props.Stroke }, l) end
	return l
end
local function button(parent, cx, cy, w, h, label, color)
	local b = box(parent, cx, cy, w, h, { Class = "TextButton", BackgroundTransparency = 0, BackgroundColor3 = color or GREEN, Text = "", AutoButtonColor = true, ZIndex = 8 })
	new("UICorner", { CornerRadius = UDim.new(0.25, 0) }, b)
	new("UIStroke", { Color = INK, Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, b)
	text(b, label, Color3.new(1, 1, 1), { Stroke = 2, ZIndex = 9, Size = UDim2.fromScale(0.85, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	b.Activated:Connect(function() UISound.Play("Click") end)
	b.MouseEnter:Connect(function() UISound.Play("Hover") end)
	return b
end
local function clear(layer) for _, c in layer:GetChildren() do c:Destroy() end end
local function layerOf(panel)
	return panel:FindFirstChild("Live") or new("Frame", { Name = "Live", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 7 }, panel)
end

local toast = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.new(1, -32, 0, 40),
	BackgroundColor3 = CREAM, FontFace = FONT, TextScaled = true, TextColor3 = INK, Visible = false, ZIndex = 20 }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, toast)
new("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, toast)
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, toast)
new("UISizeConstraint", { MaxSize = Vector2.new(420, 40) }, toast)
local toastId = 0
local function say(msg)
	if not msg or msg == "" then return end
	toastId += 1; local my = toastId
	toast.Text = msg; toast.Visible = true
	task.delay(2.2, function() if toastId == my then toast.Visible = false end end)
end
local refresh
local actionBusy=false
local function act(name,args)
 if actionBusy then return false end
 actionBusy=true
	local ok, res, msg = pcall(function() return Action:InvokeServer(name, args) end)
	actionBusy=false
 if not ok then say("Server error");return false end
 say(msg)
 if res then
  if name and name:find("Claim") then
   UISound.Play("Claim")
  elseif name and (name:find("Upgrade") or name:find("Unlock") or name:find("Buy")) then
   UISound.Play("Purchase")
  end
  if refresh then refresh() end
 end
 return res
end
local function fetch(section)
 for attempt=1,3 do
  local ok,data=pcall(function()return GetState:InvokeServer(section)end)
  if not ok or type(data)~="table" then return nil,"Couldn't load"end
  if not data.error then return data end
  if data.error~="Please wait a moment." then return nil,data.error end
  task.wait(.06*attempt)
 end
 return nil,"Couldn't refresh. Please reopen the menu."
end

local RENDER = {}

local EDGE_C, CARD_C, CELL_C = Color3.fromRGB(196, 150, 100), Color3.fromRGB(250, 233, 204), Color3.fromRGB(246, 226, 192)
local function card(parent, cx, cy, w, h, color, r, z)
	local f = box(parent, cx, cy, w, h, { BackgroundTransparency = 0, BackgroundColor3 = color or CARD_C, ZIndex = z or 6 })
	new("UICorner", { CornerRadius = UDim.new(r or 0.12, 0) }, f)
	new("UIStroke", { Color = EDGE_C, Thickness = 2 }, f)
	return f
end
local function innerOf(L) return box(L, 0.5, 0.545, 0.79, 0.62) end

RENDER.Index = function(panel)
	local data, err = fetch("index")
	local L = layerOf(panel); clear(L)
	if not data then text(box(L, 0.5, 0.5, 0.6, 0.08), err) return end
	local inner = innerOf(L)
	local total = math.min(#data.catalog.characters, 15)
	local found = 0
	for i, c in data.catalog.characters do if i <= 15 and data.discovered[c.id] == true then found += 1 end end
	-- progress card
	local top = card(inner, 0.5, 0.09, 1, 0.16, CARD_C, 0.3)
	text(top, "COLLECTION", INK, { Size = UDim2.fromScale(0.25, 0.5), Position = UDim2.fromScale(0.03, 0.25), X = Enum.TextXAlignment.Left, ZIndex = 8 })
	local track = new("Frame", { BackgroundColor3 = Color3.fromRGB(110, 70, 45), BorderSizePixel = 0, Size = UDim2.fromScale(0.5, 0.42), Position = UDim2.fromScale(0.3, 0.29), ZIndex = 7 }, top)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
	local fill = new("Frame", { BackgroundColor3 = GREEN, BorderSizePixel = 0, Size = UDim2.fromScale(math.max(found / math.max(total, 1), 0.04), 1), ZIndex = 8 }, track)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	text(top, found .. " / " .. total .. " found", Color3.fromRGB(40, 140, 40), { Size = UDim2.fromScale(0.17, 0.5), Position = UDim2.fromScale(0.82, 0.25), X = Enum.TextXAlignment.Left, ZIndex = 8 })
	-- grid
	local grid = card(inner, 0.5, 0.59, 1, 0.8)
	for i, c in data.catalog.characters do
		if i > 15 then break end
		local got = data.discovered[c.id] == true
		local col, row = (i - 1) % 5, math.floor((i - 1) / 5)
		local ce = card(grid, 0.11 + col * 0.195, 0.18 + row * 0.32, 0.17, 0.27, got and CELL_C or Color3.fromRGB(232, 215, 188), 0.18, 7)
		if got then
   if c.image and c.image~="" then
    new("ImageLabel",{Name="CharacterPortrait",BackgroundTransparency=1,Image=c.image,ScaleType=Enum.ScaleType.Fit,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.37),Size=UDim2.fromScale(.92,.64),ZIndex=8},ce)
   else
    text(ce,"✓",RARITY[c.rarity] or GREEN,{Size=UDim2.fromScale(.5,.42),Position=UDim2.fromScale(.5,.32),AnchorPoint=Vector2.new(.5,.5),ZIndex=8})
   end
			text(ce, c.name, RARITY[c.rarity] or INK, { Stroke = 1.5, Size = UDim2.fromScale(0.9, 0.26), Position = UDim2.fromScale(0.5, 0.74), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8 })
		else
			text(ce, "?", GREY, { Stroke = 1, Size = UDim2.fromScale(0.5, 0.45), Position = UDim2.fromScale(0.5, 0.36), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8 })
			text(ce, "???", GREY, { Size = UDim2.fromScale(0.7, 0.22), Position = UDim2.fromScale(0.5, 0.76), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8 })
		end
	end
end

RENDER.Quests = function(panel)
	local data, err = fetch("quests")
	local L = layerOf(panel); clear(L)
	if not data then text(box(L, 0.5, 0.5, 0.6, 0.08), err) return end
	local inner = innerOf(L)
	local list = table.clone(data.list or {})
	table.sort(list, function(a, b)
		local ac, bc = a.claimed and 1 or 0, b.claimed and 1 or 0
		if ac ~= bc then return ac < bc end
		local ad, bd = (a.progress >= a.target) and 0 or 1, (b.progress >= b.target) and 0 or 1
		if ad ~= bd then return ad < bd end
		return (a.order or 0) < (b.order or 0)
	end)
	for i = 1, 3 do
		local q = list[i]
		local row = card(inner, 0.5, 0.2 + (i - 1) * 0.31, 1, 0.26, CARD_C, 0.25)
		if q then
			local done = q.progress >= q.target
			local pc = ({ Daily = Color3.fromRGB(66, 150, 236), Weekly = Color3.fromRGB(150, 100, 230), Monthly = Color3.fromRGB(240, 170, 40) })[q.period or ""] or Color3.fromRGB(214, 52, 45)
			local tl = string.lower(q.title or "")
			local em = tl:find("hatch") and "🥚" or tl:find("discover") and "📖" or tl:find("steal") and "🦹" or tl:find("cash") and "💰" or "⭐"
			local icon = card(row, 0.06, 0.5, 0.075, 0.7, done and GREEN or pc, 0.3, 7)
			text(icon, done and "✓" or em, Color3.new(1, 1, 1), { Stroke = 2, Max = 44, Size = UDim2.fromScale(0.9, 0.9), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8 })
			text(row, (q.period and (q.period .. ": ") or "") .. q.title, INK, { Size = UDim2.fromScale(0.5, 0.3), Position = UDim2.fromScale(0.13, 0.12), X = Enum.TextXAlignment.Left, Max = 20, ZIndex = 8 })
			local track = new("Frame", { BackgroundColor3 = Color3.fromRGB(110, 70, 45), BorderSizePixel = 0, Size = UDim2.fromScale(0.48, 0.26), Position = UDim2.fromScale(0.13, 0.56), ZIndex = 7 }, row)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
			local f = new("Frame", { BackgroundColor3 = GREEN, BorderSizePixel = 0, Size = UDim2.fromScale(math.clamp(q.progress / q.target, 0.04, 1), 1), ZIndex = 8 }, track)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, f); new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(150, 235, 110), Color3.fromRGB(60, 165, 50)) }, f)
			text(track, math.min(q.progress, q.target) .. " / " .. q.target, Color3.new(1, 1, 1), { Stroke = 1.5, ZIndex = 9 })
			local reward = q.reward and q.reward.cash and ("$" .. Config.Short(q.reward.cash)) or ""
			text(row, reward, Color3.fromRGB(40, 140, 40), { Stroke = 1, Size = UDim2.fromScale(0.14, 0.42), Position = UDim2.fromScale(0.64, 0.29), ZIndex = 8 })
			local label = q.claimed and "DONE" or done and "CLAIM" or "IN PROGRESS"
			local b = button(row, 0.885, 0.5, 0.2, 0.6, label, (done and not q.claimed) and GREEN or GREY)
			if done and not q.claimed then b.Activated:Connect(function() act("Claim", { id = q.id }) end) else b.AutoButtonColor = false end
		else
			text(row, "No more quests right now", GREY, { Size = UDim2.fromScale(0.8, 0.35), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8 })
		end
	end
end

RENDER.VipShop = function(panel)
	-- Stud-brick shop. Halloween look while workspace.HalloweenMode is on.
	local L = layerOf(panel); clear(L)
	local SR = game:GetService("ReplicatedStorage"):FindFirstChild("ShopSystem")
	local remote = SR and SR:FindFirstChild("ShopRemote")
	local SC = SR and require(SR.ShopConfig)
	if not remote then text(box(L, 0.5, 0.5, 0.6, 0.08), "Shop is loading…") return end
	local ok, st = remote:InvokeServer("State")
	if not ok then text(box(L, 0.5, 0.5, 0.6, 0.08), tostring(st)) return end
	local TS = game:GetService("TweenService")
	local RunS = game:GetService("RunService")
	local HW = workspace:GetAttribute("HalloweenMode") == true
	local K = Color3.new(0, 0, 0)
	local W1 = Color3.new(1, 1, 1)
	local P = HW and {
		plate = Color3.fromRGB(28, 20, 40), plate2 = Color3.fromRGB(44, 30, 62), card = Color3.fromRGB(58, 40, 82), head = Color3.fromRGB(245, 120, 30),
		accent = Color3.fromRGB(150, 90, 230), slime = Color3.fromRGB(120, 230, 90), text = W1, muted = Color3.fromRGB(205, 185, 230),
		title = "HALLOWEEN SHOP", sub = "spooky deals • limited time", deco = { "🎃", "🦇", "👻", "🕸️", "🍬", "💀" },
	} or {
		plate = Color3.fromRGB(30, 34, 48), plate2 = Color3.fromRGB(40, 46, 64), card = Color3.fromRGB(54, 62, 86), head = Color3.fromRGB(248, 188, 44),
		accent = Color3.fromRGB(66, 134, 236), slime = Color3.fromRGB(92, 192, 70), text = W1, muted = Color3.fromRGB(178, 186, 210),
		title = "SHOP", sub = "boosts • VIP • cash", deco = { "⭐", "💰", "✨", "🥚" },
	}
	local GREENB, REDB, GOLD, PURP, BLUE = Color3.fromRGB(92, 192, 70), Color3.fromRGB(226, 66, 60), Color3.fromRGB(248, 188, 44), Color3.fromRGB(150, 100, 230), Color3.fromRGB(66, 134, 236)
	local function dk(c, a) return c:Lerp(Color3.new(), a or 0.38) end
	local function lt(c, a) return c:Lerp(W1, a or 0.28) end
	local function corner(o, r) new("UICorner", { CornerRadius = UDim.new(0, r or 14) }, o) end
	local function ink(o, t) return new("UIStroke", { Color = K, Thickness = math.max(t or 3.5, 3), LineJoinMode = Enum.LineJoinMode.Miter, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, o) end
	local function lbl(parent, s, size, color, props)
		local l = new("TextLabel", { BackgroundTransparency = 1, Text = s, FontFace = FONT, TextSize = size, TextColor3 = color or W1, ZIndex = 12,
			Size = UDim2.new(1, 0, 0, size + 6), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true }, parent)
		if props then for k, v in props do if k ~= "NoStroke" then l[k] = v end end end
		if (props == nil or props.NoStroke == nil) then new("UIStroke", { Color = K, Thickness = size >= 22 and 2.5 or 1.8 }, l) end
		return l
	end
	local function stud(parent, color, x, w, h, z)
		local base = new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(x, 0, 0, 2), Size = UDim2.fromOffset(w, h), BackgroundColor3 = dk(color, 0.18), BorderSizePixel = 0, ZIndex = z }, parent)
		corner(base, math.floor(h * 0.45)); new("UIStroke", { Color = K, Thickness = 2.5 }, base)
		local top = new("Frame", { BorderSizePixel = 0, BackgroundColor3 = lt(color), Size = UDim2.new(1, -4, 0.55, 0), Position = UDim2.fromOffset(2, 2), ZIndex = z + 1 }, base)
		corner(top, math.floor(h * 0.35))
	end
	local function studs(parent, color, n, inset, w, h)
		do return end -- studs now live ON the surface (studTex), not on top
		local row = new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1 - inset * 2, 0, 0, 0), Position = UDim2.new(inset, 0, 0, 0), ZIndex = parent.ZIndex + 1 }, parent)
		for i = 1, n do stud(row, color, (i - 0.5) / n, w or 26, h or 11, parent.ZIndex + 1) end
	end
	-- LEGO stud surface texture (same HD STUDS texture as the map), clipped to the frame's corners
	local STUD_TEX = "rbxassetid://132561191216691"
	local function studTex(face, color, alpha, tile, r)
		do return new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, face) end
		local im = new("Frame", { Name = "Gloss", BackgroundColor3 = W1, BackgroundTransparency = 0, BorderSizePixel = 0, Size = UDim2.fromScale(1, 0.5), ZIndex = face.ZIndex }, face)
		corner(im, r or 14)
		new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.82), NumberSequenceKeypoint.new(1, 1) }) }, im)
		return im
	end
	local function stripes(face)
		do return new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1) }, face) end
		local f = new("Frame", { Name = "Stripes", BackgroundColor3 = W1, BackgroundTransparency = 0, Size = UDim2.fromScale(1, 1), ZIndex = face.ZIndex, BorderSizePixel = 0 }, face)
		corner(f)
		local kp = {}
		for i = 0, 3 do local x = i / 4
			table.insert(kp, NumberSequenceKeypoint.new(x, 1)); table.insert(kp, NumberSequenceKeypoint.new(x + 0.05, 0.93)); table.insert(kp, NumberSequenceKeypoint.new(x + 0.12, 0.93)); table.insert(kp, NumberSequenceKeypoint.new(x + 0.17, 1)) end
		table.insert(kp, NumberSequenceKeypoint.new(1, 1))
		new("UIGradient", { Rotation = -35, Transparency = NumberSequence.new(kp) }, f)
		return f
	end
	-- coloured brick with darker side; returns face
	local function brick(parent, color, size, pos, order, depth)
		depth = depth or 6
		local holder = new("Frame", { BackgroundTransparency = 1, Size = size, Position = pos or UDim2.new(), LayoutOrder = order or 0, ZIndex = 9 }, parent)
		local side = new("Frame", { BackgroundColor3 = K, Position = UDim2.fromOffset(depth, depth), Size = UDim2.new(1, 0, 1, -depth), ZIndex = 9 }, holder); corner(side, 14); ink(side)
		local face = new("Frame", { Name = "Face", BackgroundColor3 = color, Size = UDim2.new(1, 0, 1, -depth), ZIndex = 10 }, holder); corner(face, 14); ink(face); studTex(face, color); new("UIGradient", { Rotation = 90, Color = ColorSequence.new(lt(color, 0.08), dk(color, 0.12)) }, face)
		-- (highlight line removed)
		return face, holder
	end
	-- gold corner brackets (arcade frame look)
	local function brackets(face, color, len, th)
		color = color or GOLD; len = len or 18; th = th or 4
		local z = face.ZIndex + 6
		for _, c in { {0,0}, {1,0}, {0,1}, {1,1} } do
			local ax = Vector2.new(c[1], c[2])
			local px = UDim2.new(c[1], c[1] == 0 and 4 or -4, c[2], c[2] == 0 and 4 or -4)
			new("Frame", { AnchorPoint = ax, Position = px, Size = UDim2.fromOffset(len, th), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z }, face)
			new("Frame", { AnchorPoint = ax, Position = px, Size = UDim2.fromOffset(th, len), BackgroundColor3 = color, BorderSizePixel = 0, ZIndex = z }, face)
		end
	end
	-- hazard checker strip
	local function checker(face, a, b, h, n)
		n = n or 32; h = h or 8
		local strip = new("Frame", { AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, h), BackgroundColor3 = b, BorderSizePixel = 0, ZIndex = face.ZIndex + 4 }, face)
		for i = 0, n - 1, 2 do new("Frame", { Position = UDim2.fromScale(i / n, 0), Size = UDim2.new(1 / n, 1, 1, 0), BackgroundColor3 = a, BorderSizePixel = 0, ZIndex = strip.ZIndex }, strip) end
		new("Frame", { Size = UDim2.new(1, 0, 0, 3), BackgroundColor3 = K, BorderSizePixel = 0, Position = UDim2.new(0, 0, 0, -3), ZIndex = strip.ZIndex }, strip)
		return strip
	end
	local function shine(btn)
		do return end
		local sh = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = W1, BackgroundTransparency = 0, BorderSizePixel = 0, ZIndex = btn.ZIndex + 3 }, btn); corner(sh, 12)
		local g = new("UIGradient", { Rotation = 20, Offset = Vector2.new(-1.2, 0), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.4), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }) }, sh)
		task.spawn(function() while sh.Parent do g.Offset = Vector2.new(-1.2, 0); TS:Create(g, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Offset = Vector2.new(1.2, 0) }):Play(); task.wait(2.4 + math.random()) end end)
	end
	-- pressable 3D brick button
	local function btn3d(parent, label, color, size, pos, onClick, opts)
		opts = opts or {}
		local depth = 6
		local holder = new("Frame", { BackgroundTransparency = 1, Size = size, Position = pos, AnchorPoint = opts.anchor or Vector2.new(0.5, 0.5), ZIndex = 12 }, parent)
		local side = new("Frame", { BackgroundColor3 = K, Position = UDim2.fromOffset(depth, depth), Size = UDim2.new(1, 0, 1, -depth), ZIndex = 12 }, holder); corner(side, 12); ink(side)
		local face = new("TextButton", { BackgroundColor3 = color, Size = UDim2.new(1, 0, 1, -depth), Text = "", AutoButtonColor = false, ZIndex = 13 }, holder); corner(face, 12); ink(face); studTex(face, color); stripes(face)
		-- (highlight line removed)
		local t = lbl(face, label, opts.textSize or 20, W1, { Size = UDim2.new(1, -10, 1, 0), Position = UDim2.fromScale(0.5, 0.55), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 15 })
		if opts.studs ~= false then studs(face, color, opts.studs or 2, 0.24, 24, 10) end
		local enabled = opts.disabled ~= true
		if not enabled then face.BackgroundColor3 = Color3.fromRGB(120, 128, 150); side.BackgroundColor3 = K else if opts.shine ~= false then shine(face) end end
		face.MouseButton1Down:Connect(function() if enabled then TS:Create(face, TweenInfo.new(0.06), { Position = UDim2.fromOffset(0, depth - 1) }):Play() end end)
		face.MouseButton1Up:Connect(function() TS:Create(face, TweenInfo.new(0.08), { Position = UDim2.fromOffset(0, 0) }):Play() end)
		face.MouseLeave:Connect(function() face.Position = UDim2.fromOffset(0, 0) end)
		face.MouseEnter:Connect(function() if enabled then UISound.Play("Hover") end end)
		face.Activated:Connect(function() if enabled then UISound.Play("Click") if onClick then onClick() end end end)
		return face, t
	end
	local function act2(action, ...)
		local r, msg = remote:InvokeServer(action, ...)
		if msg then say(msg) end
		if r then UISound.Play((action and (string.find(action, "Buy") or string.find(action, "Purchase"))) and "Purchase" or "Claim") end
		RENDER.VipShop(panel)
	end
	local ICON = table.clone(SC.Icons or {})
	ICON.CrownOld = "rbxassetid://95157813840098"
	ICON.StarterPackShop = ICON.Chest
	_G.__shopPrices = _G.__shopPrices or {}
	local function live(id, pass, fallback)
		if not id or id == 0 then return fallback end
		local k = (pass and "p" or "d") .. id
		if _G.__shopPrices[k] == nil then
			local ok2, info = pcall(game:GetService("MarketplaceService").GetProductInfo, game:GetService("MarketplaceService"), id, pass and Enum.InfoType.GamePass or Enum.InfoType.Product)
			_G.__shopPrices[k] = ok2 and info and info.PriceInRobux or false
		end
		return _G.__shopPrices[k] or fallback
	end
	local function price(key, pass)
		local id = pass and SC.GamePasses[key] or SC.Products[key]
		return (live(id, pass, SC.Prices[key]) or "?") .. " R$"
	end
	local function glowIcon(parent, key, pos, size, z, color)
		local id = ICON[key]; if not id or id == "" then return end
		local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = size, BackgroundTransparency = 1, ZIndex = z }, parent)
		local glow = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.7, 1.7), BackgroundTransparency = 1, Image = ICON.Glow or "", ImageColor3 = color or (HW and Color3.fromRGB(255, 130, 30) or Color3.fromRGB(255, 190, 60)), ZIndex = z }, holder)
		TS:Create(glow, TweenInfo.new(18, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
		local img = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = id, ScaleType = Enum.ScaleType.Fit, ZIndex = z + 1 }, holder)
		TS:Create(img, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromScale(0, -0.06) }):Play()
		return img
	end
	local function fmtTime(s) s = math.max(0, math.floor(s)); return string.format("%d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60) end
	local function fmtLong(s) s = math.max(0, math.floor(s)); local d = s // 86400; return (d > 0 and (d .. "d ") or "") .. string.format("%02d:%02d:%02d", (s // 3600) % 24, (s // 60) % 60, s % 60) end

	-- ===== skin (replaces the painted cream frame) =====
	panel.ImageTransparency = 1
	local close = panel:FindFirstChild("Close")
	if close then close.Position = UDim2.fromScale(0.955, 0.075); close.ZIndex = 30; for _, d in close:GetDescendants() do if d:IsA("GuiObject") then d.ZIndex = 31 end end end
	new("Frame", { BackgroundColor3 = K, BorderSizePixel = 0, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromScale(1, 1), ZIndex = 5 }, L):SetAttribute("r", 1)
	for _, f in L:GetChildren() do if f:GetAttribute("r") then corner(f, 22) end end
	local skin = new("Frame", { BackgroundColor3 = W1, Size = UDim2.fromScale(1, 1), ZIndex = 6, ClipsDescendants = true }, L); corner(skin); ink(skin, 5)
	new("UIGradient", { Rotation = 90, Color = ColorSequence.new(P.plate2, P.plate) }, skin)
	studTex(skin, P.plate2)
	-- drifting decorations
	for i = 1, (HW and 14 or 8) do
		local d = new("TextLabel", { BackgroundTransparency = 1, Text = P.deco[(i - 1) % #P.deco + 1], TextSize = math.random(18, 34), TextTransparency = 0.55, Size = UDim2.fromOffset(40, 40), ZIndex = 7,
			Position = UDim2.new(math.random(), 0, 1.1, 0), Rotation = math.random(-20, 20) }, skin)
		task.spawn(function()
			task.wait(i * 0.7)
			while d.Parent do
				d.Position = UDim2.new(math.random() * 0.95, 0, 1.08, 0)
				local tw = TS:Create(d, TweenInfo.new(math.random(9, 15), Enum.EasingStyle.Linear), { Position = UDim2.new(d.Position.X.Scale + (math.random() - 0.5) * 0.15, 0, -0.1, 0), Rotation = math.random(-40, 40) })
				tw:Play(); tw.Completed:Wait()
			end
		end)
	end
	-- header
	local head = new("Frame", { BackgroundColor3 = P.head, Position = UDim2.new(0.015, 0, 0, 16), Size = UDim2.new(0.97, 0, 0, 80), ZIndex = 10 }, skin); corner(head, 16); ink(head); studTex(head, P.head); stripes(head); new("UIGradient", { Rotation = 90, Color = ColorSequence.new(lt(P.head, 0.15), dk(P.head, 0.15)) }, head)
	new("Frame", { BackgroundColor3 = K, BorderSizePixel = 0, Position = UDim2.new(0.015, 6, 0, 22), Size = UDim2.new(0.97, 0, 0, 80), ZIndex = 9 }, skin)
	
	studs(head, P.head, 14, 0.02, 32, 13)
	lbl(head, (HW and "🎃 " or "") .. P.title .. (HW and " 🎃" or ""), 36, W1, { Size = UDim2.new(1, 0, 0, 42), Position = UDim2.fromOffset(0, 8) })
	lbl(head, P.sub, 15, lt(P.head, 0.75), { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 50), NoStroke = true })
	if HW then
		-- flickering candle glow on the header
		local glow = new("Frame", { BackgroundColor3 = Color3.fromRGB(255, 200, 80), BackgroundTransparency = 0.85, Size = UDim2.fromScale(1, 1), ZIndex = 11 }, head); corner(glow, 16)
		task.spawn(function() while glow.Parent do TS:Create(glow, TweenInfo.new(0.15 + math.random() * 0.3), { BackgroundTransparency = 0.75 + math.random() * 0.22 }):Play(); task.wait(0.2 + math.random() * 0.3) end end)
	end
	-- scrolling body
	local sf = new("ScrollingFrame", { Position = UDim2.new(0.015, 0, 0, 112), Size = UDim2.new(0.97, 0, 1, -124), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8,
		ScrollBarImageColor3 = P.head, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 9 }, skin)
	new("UIListLayout", { Padding = UDim.new(0, 24), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, sf)
	new("UIPadding", { PaddingTop = UDim.new(0, 18), PaddingBottom = UDim.new(0, 18), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 14) }, sf)
	local function section(title, color, h, order)
		local face, holder = brick(sf, P.card, UDim2.new(1, 0, 0, h + 6), nil, order); brackets(face, color, 16, 4)
		local tag = new("Frame", { BackgroundColor3 = color, Position = UDim2.fromOffset(14, -14), Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 14 }, face); corner(tag, 9); ink(tag, 2.5)
		new("UIPadding", { PaddingLeft = UDim.new(0, 14), PaddingRight = UDim.new(0, 14) }, tag)
		lbl(tag, title, 17, W1, { Size = UDim2.new(0, 0, 1, 0), AutomaticSize = Enum.AutomaticSize.X, ZIndex = 15 })
		return face
	end

	-- ===== LIMITED DEAL =====
	local LD = SC.LimitedDeal
	if LD then
		local dealCol = HW and Color3.fromRGB(70, 40, 120) or Color3.fromRGB(40, 70, 130)
		local face, holder = brick(sf, dealCol, UDim2.new(1, 0, 0, 236), nil, 1, 8)
		holder.ZIndex = 9
		brackets(face, GOLD, 26, 5); checker(face, GOLD, K, 10, 40)
		studs(face, Color3.fromRGB(120, 200, 255), 10, 0.03, 30, 12)
		local stroke = face:FindFirstChildOfClass("UIStroke")
		
		-- ribbon
		local tagH = new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(-12, -16), Size = UDim2.fromOffset(214, 40), ZIndex = 20 }, face)
		new("Frame", { BackgroundColor3 = K, BorderSizePixel = 0, Position = UDim2.fromOffset(5, 5), Size = UDim2.fromScale(1, 1), ZIndex = 20 }, tagH)
		local t1 = new("Frame", { BackgroundColor3 = GOLD, BorderSizePixel = 0, Size = UDim2.new(0.58, 0, 1, 0), ZIndex = 21 }, tagH); ink(t1, 3)
		lbl(t1, "LIMITED", 22, K, { Size = UDim2.fromScale(1, 1), ZIndex = 22, NoStroke = true })
		local t2 = new("Frame", { BackgroundColor3 = REDB, BorderSizePixel = 0, Position = UDim2.fromScale(0.58, 0), Size = UDim2.new(0.42, 0, 1, 0), ZIndex = 21 }, tagH); ink(t2, 3)
		lbl(t2, "DEAL", 22, W1, { Size = UDim2.fromScale(1, 1), ZIndex = 22 })
		local tsc = new("UIScale", {}, tagH)
		task.spawn(function() while tagH.Parent do TS:Create(tsc, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Scale = 1.08 }):Play(); task.wait(0.12); TS:Create(tsc, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play(); task.wait(1.6) end end)
		-- 3D egg in a viewport with spinning rays + sparkles
		local eggBox = new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.2, 0, 0.55, 0), Size = UDim2.fromOffset(200, 200), ZIndex = 12 }, face)
		local rays = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.35, 1.35), BackgroundTransparency = 1, Image = ICON.Glow or "", ImageColor3 = Color3.fromRGB(140, 230, 255), ZIndex = 12 }, eggBox)
		TS:Create(rays, TweenInfo.new(10, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
		TS:Create(rays, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = 0.45 }):Play()
		local vp = new("ViewportFrame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 13, Ambient = Color3.fromRGB(200, 200, 230), LightColor = Color3.fromRGB(255, 240, 220), LightDirection = Vector3.new(-1, -1, -1) }, eggBox)
		local src = SR:FindFirstChild("ShopModels") and SR.ShopModels:FindFirstChild(LD.key)
		if src then
			local egg = src:Clone(); egg.Parent = vp
			local cf, size = egg:GetBoundingBox()
			egg:PivotTo(CFrame.new(-cf.Position) * egg:GetPivot())
			local cam = new("Camera", { FieldOfView = 40 }, vp); vp.CurrentCamera = cam
			local dist = size.Magnitude * 1.25
			cam.CFrame = CFrame.lookAt(Vector3.new(0, size.Y * 0.08, -dist), Vector3.zero)
			local base = egg:GetPivot(); local t0 = os.clock()
			local conn; conn = RunS.RenderStepped:Connect(function()
				if not vp.Parent then conn:Disconnect() return end
				local t = os.clock() - t0
				egg:PivotTo(CFrame.new(0, math.sin(t * 2) * 0.25, 0) * CFrame.Angles(0, t * 0.9, 0) * base)
			end)
		end
		for i = 1, 6 do
			local sp = new("TextLabel", { BackgroundTransparency = 1, Text = "✨", TextColor3 = Color3.fromRGB(200, 245, 255), TextSize = math.random(14, 24), Size = UDim2.fromOffset(24, 24), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 14, TextTransparency = 1 }, eggBox)
			task.spawn(function() while sp.Parent do sp.Position = UDim2.fromScale(0.15 + math.random() * 0.7, 0.1 + math.random() * 0.8); sp.TextTransparency = 1
				TS:Create(sp, TweenInfo.new(0.4), { TextTransparency = 0 }):Play(); task.wait(0.5); TS:Create(sp, TweenInfo.new(0.5), { TextTransparency = 1 }):Play(); task.wait(0.6 + math.random() * 1.2) end end)
		end
		-- text + countdown + buy
		local info = new("Frame", { BackgroundTransparency = 1, Position = UDim2.new(0.4, 0, 0, 22), Size = UDim2.new(0.58, 0, 1, -30), ZIndex = 12 }, face)
		lbl(info, LD.name, 38, W1, { Size = UDim2.new(1, 0, 0, 44), TextXAlignment = Enum.TextXAlignment.Left })
		lbl(info, LD.text, 17, Color3.fromRGB(215, 240, 255), { Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 46), TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
		local timer = new("Frame", { BackgroundColor3 = Color3.fromRGB(20, 16, 36), Position = UDim2.fromOffset(0, 92), Size = UDim2.fromOffset(250, 36), ZIndex = 13 }, info); corner(timer, 10); ink(timer, 2.5)
		local tl = lbl(timer, "", 18, Color3.fromRGB(255, 120, 110), { Size = UDim2.fromScale(1, 1), ZIndex = 14 })
		task.spawn(function() while tl.Parent and panel.Visible do tl.Text = "⏰ ENDS IN " .. fmtLong(LD.endsAt - os.time()); task.wait(1) end end)
		local id = SC.Products[LD.key]
		btn3d(info, (SC.Prices[LD.key] and (live(id, false, SC.Prices[LD.key]) .. " R$") or "SOON"), GREENB, UDim2.fromOffset(250, 60), UDim2.new(0, 0, 0, 140), function() act2("Buy", LD.key) end, { anchor = Vector2.new(0, 0), textSize = 26, studs = 3 })
	end

	-- ===== DAILY REWARDS =====
	local d = st.daily
	local daily = section("📅 DAILY REWARDS", BLUE, 200, 2)
	for i, r in SC.Daily do
		local claimed = (i < d.day) or (i == d.day and not d.ready)
		local today = i == d.day and d.ready
		local col = today and GOLD or (i == 7 and (HW and Color3.fromRGB(245, 120, 30) or REDB) or P.plate2)
		local tile = brick(daily, col, UDim2.new(1 / 7, -10, 0, 128), UDim2.new((i - 1) / 7, 5, 0, 22), 0, 5)
		lbl(tile, "DAY " .. i, 15, W1, { Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 18) })
		local key = r.kind == "cash" and "Coins" or r.kind == "mystery" and "Chest" or r.boost
		glowIcon(tile, key, UDim2.new(0.5, 0, 0, 52), UDim2.fromOffset(42, 42), 12, today and W1 or nil)
		lbl(tile, r.label or ("$" .. Config.Short(r.amount)), 14, (r.kind == "cash" and Color3.fromRGB(150, 255, 120) or Color3.fromRGB(230, 200, 255)), { Position = UDim2.fromOffset(2, 78), Size = UDim2.new(1, -4, 0, 30) })
		lbl(tile, claimed and "✓" or (today and "READY" or "🔒"), 14, claimed and GREENB or W1, { Position = UDim2.new(0, 0, 1, -22), Size = UDim2.new(1, 0, 0, 18) })
		if today then local s2 = tile:FindFirstChildOfClass("UIStroke"); s2.Color = W1; TS:Create(s2, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 5 }):Play() end
	end
	if d.ready then
		btn3d(daily, "CLAIM DAY " .. d.day, GREENB, UDim2.fromOffset(260, 46), UDim2.new(0.5, 0, 1, -24), function() act2("ClaimDaily") end, { textSize = 19 })
	else
		local nl = lbl(daily, "Next reward in " .. fmtTime(d.nextIn), 17, P.muted, { Position = UDim2.new(0, 0, 1, -38), Size = UDim2.new(1, 0, 0, 22) })
		local endAt = os.clock() + d.nextIn
		task.spawn(function() while nl.Parent and panel.Visible do nl.Text = "Next reward in " .. fmtTime(endAt - os.clock()); task.wait(1) end end)
	end

	-- ===== VIP =====
	local vip = brick(sf, PURP, UDim2.new(1, 0, 0, 150), nil, 3, 7)
	new("UIGradient", { Rotation = 0, Color = ColorSequence.new(Color3.fromRGB(170, 110, 255), Color3.fromRGB(80, 40, 140)) }, vip)
	studs(vip, PURP, 10, 0.03, 30, 12)
	glowIcon(vip, "CrownOld", UDim2.new(0.12, 0, 0.5, 0), UDim2.fromOffset(110, 110), 12, Color3.fromRGB(255, 210, 80))
	lbl(vip, "👑 VIP", 36, GOLD, { Position = UDim2.new(0.24, 0, 0, 16), Size = UDim2.new(0.45, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Left })
	lbl(vip, "Crown over your head • Gold chat tag\n+10% cash • 2× daily cash", 16, Color3.fromRGB(235, 225, 255), { Position = UDim2.new(0.24, 0, 0, 62), Size = UDim2.new(0.45, 0, 0, 48), TextXAlignment = Enum.TextXAlignment.Left, NoStroke = true })
	btn3d(vip, st.vip and "OWNED" or price("VIP", true), st.vip and GREENB or GOLD, UDim2.fromOffset(200, 62), UDim2.new(0.85, 0, 0.5, 0), (not st.vip) and function() act2("Buy", "VIP") end or nil, { disabled = st.vip, textSize = 24, studs = 3 })

	-- ===== BOOSTS ROW =====
	local row = new("Frame", { LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 250), BackgroundTransparency = 1, ZIndex = 9 }, sf)
	local function tile(i, title, desc, key, color, owned, pass)
		local iconKey = key; if key == "StarterPackShop" then key = "StarterPack" end
		local t = brick(row, color, UDim2.new(1 / 3, -10, 1, 0), UDim2.new((i - 1) / 3, 5, 0, 0), 0, 7)
		studs(t, color, 3, 0.15, 30, 12)
		lbl(t, title, 22, W1, { Position = UDim2.fromOffset(0, 12), Size = UDim2.new(1, 0, 0, 28) })
		glowIcon(t, iconKey, UDim2.new(0.5, 0, 0, 92), UDim2.fromOffset(92, 92), 12)
		local dl = lbl(t, desc, 14, W1, { Position = UDim2.new(0.5, 0, 0, 146), AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.new(1, -16, 0, 34), NoStroke = true })
		btn3d(t, owned and "OWNED" or price(key, pass), owned and Color3.fromRGB(120, 128, 150) or GREENB, UDim2.new(0.8, 0, 0, 50), UDim2.new(0.5, 0, 1, -34), (not owned) and function() act2("Buy", key) end or nil, { disabled = owned, textSize = 20 })
		return dl
	end
	tile(1, "STARTER PACK", "$" .. Config.Short(SC.StarterPack.cash) .. " + 30 min 2× money & hatch", "StarterPackShop", HW and Color3.fromRGB(245, 120, 30) or REDB, st.starter, true)
	local function boostDesc(untilT, what) local left = untilT - st.serverTime; return left > 0 and ("ACTIVE • " .. fmtTime(left)) or ("2× " .. what .. " for " .. SC.BoostMinutes .. " min") end
	local m2 = tile(2, "2× MONEY", boostDesc(st.money2xUntil, "money"), "Money2x", Color3.fromRGB(60, 160, 60))
	local h2 = tile(3, "2× HATCH", boostDesc(st.hatch2xUntil, "hatch speed"), "Hatch2x", BLUE)
	local t0 = os.clock()
	task.spawn(function() while m2.Parent and panel.Visible do
		local tnow = st.serverTime + (os.clock() - t0)
		if st.money2xUntil > tnow then m2.Text = "ACTIVE • " .. fmtTime(st.money2xUntil - tnow) end
		if st.hatch2xUntil > tnow then h2.Text = "ACTIVE • " .. fmtTime(st.hatch2xUntil - tnow) end
		task.wait(1) end end)

	-- ===== MONEY MULTIPLIER =====
	local lvl = st.moneyLevel
	local cur = lvl > 0 and SC.MoneyLevels[lvl].mult or 1
	local nxt = SC.MoneyLevels[lvl + 1]
	local mm = section("💰 MONEY MULTIPLIER", GREENB, 120, 5)
	lbl(mm, nxt and (cur .. "×  →  " .. nxt.mult .. "×") or "1000×  MAXED!", 30, Color3.fromRGB(150, 255, 120), { Position = UDim2.fromOffset(20, 28), Size = UDim2.new(0.55, 0, 0, 36), TextXAlignment = Enum.TextXAlignment.Left })
	for i = 1, #SC.MoneyLevels do
		local pip = new("Frame", { Position = UDim2.new(0, 20 + (i - 1) * 26, 0, 78), Size = UDim2.fromOffset(20, 20), BackgroundColor3 = i <= lvl and GOLD or P.plate2, BorderSizePixel = 0, ZIndex = 12 }, mm)
		corner(pip, 5); ink(pip, 2)
	end
	if nxt then btn3d(mm, nxt.productId == 0 and "SOON" or (live(nxt.productId, false, nxt.robux) .. " R$"), GREENB, UDim2.fromOffset(200, 60), UDim2.new(0.84, 0, 0.55, 0), function() act2("BuyMoneyLevel") end, { textSize = 24, studs = 3 }) end

	-- ===== CASH PACKS =====
	local packs = new("Frame", { LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 190), BackgroundTransparency = 1, ZIndex = 9 }, sf)
	for i, k in { "CashSmall", "CashMedium", "CashLarge" } do
		local col = ({ Color3.fromRGB(60, 160, 60), Color3.fromRGB(230, 160, 30), HW and Color3.fromRGB(245, 120, 30) or REDB })[i]
		local t = brick(packs, col, UDim2.new(1 / 3, -10, 1, 0), UDim2.new((i - 1) / 3, 5, 0, 0), 0, 7)
		studs(t, col, 3, 0.15, 30, 12)
		glowIcon(t, "Coins", UDim2.new(0.5, 0, 0, 46), UDim2.fromOffset(44 + i * 10, 44 + i * 10), 12)
		lbl(t, "$" .. Config.Short(SC.CashPacks[k]), 28, Color3.fromRGB(200, 255, 170), { Position = UDim2.fromOffset(0, 86), Size = UDim2.new(1, 0, 0, 32) })
		btn3d(t, SC.Products[k] == 0 and "SOON" or price(k), GREENB, UDim2.new(0.78, 0, 0, 48), UDim2.new(0.5, 0, 1, -32), function() act2("Buy", k) end, { textSize = 20 })
	end
end

local plotPage = "overview" -- "overview" | "upgrades"
local SLOT_PRICES = { 0, 250, 2500, 25000, 150000, 750000, 5000000, 25000000, 150000000, 750000000, 3000000000, 15000000000 }

local function myPlot()
	for _, p in workspace.Plots:GetChildren() do if p:GetAttribute("OwnerUserId") == player.UserId then return p end end
end

-- page switch tab on top of the panel
local function tabs(L, panel)
	local bar = box(L, 0.22, 0.887, 0.27, 0.075)
	local function tab(x, label, page)
		local on = plotPage == page
		local b = button(bar, x, 0.5, 0.48, 1, label, on and Color3.fromRGB(214, 52, 45) or Color3.fromRGB(150, 120, 100))
		b.Activated:Connect(function() if plotPage ~= page then plotPage = page; RENDER.Plot(panel) end end)
	end
	tab(0.25, "OVERVIEW", "overview")
	tab(0.75, "UPGRADES", "upgrades")
end

local function overview(L, data)
 local plot=myPlot()
 local placed,stored,income={},0,0
 for _,it in data.items or {} do
  if it.state=="placed" then table.insert(placed,it);income+=it.income or 0 else stored+=1 end
 end
 local level=data.level or 1
 local cap=data.availableSlots or level*12
 local unlocked=data.unlocked or 0
 local RED=Color3.fromRGB(188,57,44)
 local MUTED=Color3.fromRGB(139,112,87)
 local PAPER=Color3.fromRGB(255,247,228)
 local sheet=box(L,.5,.55,.82,.64,{BackgroundTransparency=0,BackgroundColor3=CREAM,ZIndex=7})
 sheet.Name="PlotContent"
 new("UICorner",{CornerRadius=UDim.new(0,12)},sheet)
 local scroll=new("ScrollingFrame",{Name="Sections",Size=UDim2.new(1,-8,1,-8),Position=UDim2.fromOffset(4,4),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=4,ScrollBarImageColor3=Color3.fromRGB(184,137,88),CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollingDirection=Enum.ScrollingDirection.Y,ZIndex=8},sheet)
 new("UIPadding",{PaddingLeft=UDim.new(0,5),PaddingRight=UDim.new(0,12),PaddingTop=UDim.new(0,4),PaddingBottom=UDim.new(0,8)},scroll)
 new("UIListLayout",{Padding=UDim.new(0,12),SortOrder=Enum.SortOrder.LayoutOrder},scroll)
 local order=0
 local function section(name,height)
  order+=1
  local f=new("Frame",{Name=name,LayoutOrder=order,Size=UDim2.new(1,0,0,height),BackgroundColor3=PAPER,BorderSizePixel=0,ZIndex=8},scroll)
  new("UICorner",{CornerRadius=UDim.new(0,10)},f)
  new("UIStroke",{Color=Color3.fromRGB(222,195,154),Thickness=1,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},f)
  return f
 end
 local function label(parent,str,x,y,w,h,size,color)
  return text(parent,str,color or INK,{Position=UDim2.new(x,0,0,y),Size=UDim2.new(w,0,0,h),X=Enum.TextXAlignment.Left,Max=size,ZIndex=10})
 end
 local function action(parent,name,x,y,w,h,labelText,color,callback)
  local b=new("TextButton",{Name=name,AnchorPoint=Vector2.new(0,0),Position=UDim2.new(x,0,0,y),Size=UDim2.new(w,0,0,h),BackgroundColor3=color,BorderSizePixel=0,Text="",AutoButtonColor=false,ZIndex=10},parent)
  new("UICorner",{CornerRadius=UDim.new(0,8)},b)
  new("UIStroke",{Color=color:Lerp(Color3.new(0,0,0),.28),Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Border},b)
  local t=text(b,labelText,Color3.new(1,1,1),{Position=UDim2.new(0,7,0,4),Size=UDim2.new(1,-14,1,-8),Max=16,ZIndex=11})
  b.MouseEnter:Connect(function()
   UISound.Play("Hover")
   TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=color:Lerp(Color3.new(1,1,1),.1)}):Play()
  end)
  b.MouseLeave:Connect(function()TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=color}):Play()end)
  if callback then
   b.Activated:Connect(function()
    UISound.Play("Click")
    callback()
   end)
  else
   b.Interactable=false
  end
  return b
 end
 local hero=section("TempleSummary",86)
 label(hero,"TEMPLE  /  LEVEL "..level,.035,12,.59,25,23)
 label(hero,level>=3 and "Your temple is fully upgraded" or "Unlock every slot to open the next floor",.035,44,.59,25,14,MUTED)
 action(hero,"UpgradeTemple",.66,23,.305,40,level>=3 and "MAX LEVEL" or data.canUpgrade and ("UPGRADE $"..Config.Short(require(game.ReplicatedStorage.UpgradePrices).Temple[level+1])) or unlocked.." / "..cap.." SLOTS",data.canUpgrade and RED or Color3.fromRGB(159,139,112),level<3 and function()
  if data.canUpgrade then act("UpgradeTemple")else say("Unlock all "..cap.." slots to open the next floor")end
 end or nil)
 local stats=section("Stats",58)
 for i,v in {{title="INCOME / SEC",value="$"..Config.Short(income),color=Color3.fromRGB(60,137,65)},{title="CHARACTERS PLACED",value=#placed.." / "..unlocked},{title="IN BACKPACK",value=tostring(stored)}} do
  local x=.035+(i-1)*.325
  label(stats,v.title,x,7,.3,17,11,MUTED)
  label(stats,v.value,x,25,.3,25,22,v.color)
 end
 local incubators=section("Incubators",150)
 label(incubators,"INCUBATORS",.035,10,.8,24,18)
 local chambers=plot and plot:FindFirstChild("Chambers")
 local count=chambers and #chambers:GetChildren()or 0
 for i=1,3 do
  local x=.035+(i-1)*.325
  local f=new("Frame",{Name="Incubator"..i,Position=UDim2.new(x,0,0,43),Size=UDim2.new(.305,0,0,95),BackgroundColor3=Color3.fromRGB(245,232,204),BorderSizePixel=0,ZIndex=9},incubators)
  new("UICorner",{CornerRadius=UDim.new(0,8)},f)
  local chamber=chambers and chambers:FindFirstChild("Chamber"..i)
  local lv=chamber and(chamber:GetAttribute("UpgradeLevel")or 1)
  label(f,"#"..i..(lv and "   LEVEL "..lv or "   LOCKED"),.07,6,.88,20,15)
  local status=chamber and tostring(chamber:GetAttribute("Status")or "Ready")or(i==count+1 and "Expand your hatchery"or "Buy the previous incubator")
  label(f,status,.07,29,.88,18,12,MUTED)
  if chamber then
   action(f,"UpgradeIncubator"..i,.07,55,.86,31,lv<3 and ("UPGRADE $"..Config.Short(require(game.ReplicatedStorage.UpgradePrices).IncubatorLevel[lv+1]))or"MAX LEVEL",lv<3 and RED or MUTED,lv<3 and function()act("UpgradeIncubator",{index=i})end or nil)
  elseif i==count+1 then action(f,"AddIncubator",.07,55,.86,31,"+ ADD $"..Config.Short(require(game.ReplicatedStorage.UpgradePrices).AddIncubator[i]),Color3.fromRGB(70,151,74),function()act("AddIncubator")end)
  end
 end
 local slots=section("CharacterSlots",168)
 label(slots,"CHARACTER SLOTS",.035,10,.6,24,18)
 label(slots,unlocked.." / "..cap.." unlocked",.67,12,.3,20,14,MUTED)
 local nextPrice
 for i=1,cap do local sl=plot and plot.Slots:FindFirstChild(string.format("Slot%02d",i));if sl and not sl:GetAttribute("Unlocked")then nextPrice=sl:GetAttribute("UnlockPrice");break end end
 local track=new("Frame",{Position=UDim2.new(.035,0,0,43),Size=UDim2.new(.93,0,0,6),BackgroundColor3=Color3.fromRGB(225,207,175),BorderSizePixel=0,ZIndex=9},slots)
 new("UICorner",{CornerRadius=UDim.new(1,0)},track)
 local fill=new("Frame",{Size=UDim2.fromScale(math.clamp(unlocked/cap,0,1),1),BackgroundColor3=Color3.fromRGB(91,163,80),BorderSizePixel=0,ZIndex=10},track)
 new("UICorner",{CornerRadius=UDim.new(1,0)},fill)
 label(slots,#placed.." working  ·  "..math.max(0,unlocked-#placed).." empty",.035,56,.53,22,15,MUTED)
 action(slots,"UnlockSlot",.60,56,.365,34,nextPrice and "UNLOCK  $"..Config.Short(nextPrice)or"ALL UNLOCKED",nextPrice and Color3.fromRGB(70,151,74)or MUTED,nextPrice and function()act("UnlockSlot")end or nil)
 local list=new("ScrollingFrame",{Name="PlacedCharacters",Position=UDim2.new(.035,0,0,101),Size=UDim2.new(.93,0,0,55),BackgroundTransparency=1,BorderSizePixel=0,ScrollBarThickness=3,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.X,ScrollingDirection=Enum.ScrollingDirection.X,ZIndex=9},slots)
 new("UIListLayout",{FillDirection=Enum.FillDirection.Horizontal,Padding=UDim.new(0,8),SortOrder=Enum.SortOrder.LayoutOrder},list)
 table.sort(placed,function(a,b)return(a.income or 0)>(b.income or 0)end)
 if #placed==0 then label(list,"Place a character to start earning cash.",0,7,1,28,14,MUTED)else
  for i,it in placed do
   local f=new("Frame",{Name="Character"..i,LayoutOrder=i,Size=UDim2.fromOffset(145,46),BackgroundColor3=Color3.fromRGB(245,232,204),BorderSizePixel=0,ZIndex=10},list)
   new("UICorner",{CornerRadius=UDim.new(0,7)},f)
   label(f,it.name,.06,3,.88,20,14,RARITY[it.rarity]or INK)
   label(f,"$"..Config.Short(it.income or 0).."/sec",.06,24,.88,16,12,Color3.fromRGB(60,137,65))
  end
 end
 local footer=section("QuickActions",48)
 label(footer,"Put your strongest characters to work",.035,10,.59,28,14,MUTED)
 action(footer,"EquipBest",.66,7,.305,34,"EQUIP BEST",Color3.fromRGB(66,126,177),function()act("EquipBest")end) task.defer(function()
  if scroll.Parent then scroll.CanvasPosition=Vector2.zero end
 end)

end

local function upgrades(L, data)
	-- cover the baked overview art inside the panel with one clean cream sheet
	local sheet = box(L, 0.5, 0.555, 0.86, 0.55, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(253, 240, 214), ZIndex = 7 })
	new("UICorner", { CornerRadius = UDim.new(0.06, 0) }, sheet)
	new("UIStroke", { Color = Color3.fromRGB(205, 170, 120), Thickness = 2 }, sheet)
	local cover = box(L, 0.496, 0.887, 0.27, 0.105, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(252, 238, 210), ZIndex = 7 })
	new("UICorner", { CornerRadius = UDim.new(0.4, 0) }, cover)
	text(cover, "Upgrades work from anywhere on your plot", Color3.fromRGB(150, 115, 90), { Size = UDim2.fromScale(0.95, 0.42), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), Max = 14 })
	local function row(y, title)
		local r = box(sheet, 0.5, y, 0.94, 0.27, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(246, 226, 190), ZIndex = 8 })
		new("UICorner", { CornerRadius = UDim.new(0.2, 0) }, r)
		text(r, title, Color3.fromRGB(200, 60, 45), { Size = UDim2.fromScale(0.24, 0.32), Position = UDim2.fromScale(0.02, 0.06), X = Enum.TextXAlignment.Left, ZIndex = 9, Max = 18 })
		return r
	end
	local plot = myPlot()

	-- TEMPLE
	local t = row(0.17, "TEMPLE")
	local lv = data.level or 1
	for i = 1, 3 do
		local pip = box(t, 0.06 + i * 0.075, 0.66, 0.06, 0.36, { BackgroundTransparency = 0, BackgroundColor3 = i <= lv and Color3.fromRGB(235, 175, 30) or Color3.fromRGB(200, 185, 160), ZIndex = 9 })
		new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, pip)
		new("UIStroke", { Color = INK, Thickness = 2 }, pip)
	end
	text(t, "Level " .. lv .. " / 3", INK, { Size = UDim2.fromScale(0.3, 0.4), Position = UDim2.fromScale(0.33, 0.45), X = Enum.TextXAlignment.Left, ZIndex = 9 })
	if lv < 3 then
		local allowed=data.canUpgrade==true
		local cost=require(game.ReplicatedStorage.UpgradePrices).Temple[lv+1]
		local b = button(t, 0.84, 0.5, 0.26, 0.62, allowed and ("UPGRADE • $"..Config.Short(cost)) or "BUY ALL SLOTS", allowed and Color3.fromRGB(214,52,45) or Color3.fromRGB(150,135,115))
		b.Interactable=allowed
		if not allowed then text(t,"Buy every current slot first",Color3.fromRGB(150,90,60),{Size=UDim2.fromScale(.5,.22),Position=UDim2.fromScale(.3,.06),ZIndex=9,Max=13})end
		b.Activated:Connect(function() act("UpgradeTemple") end)
	else
		text(t, "MAX", Color3.fromRGB(235, 175, 30), { Stroke = 2, Size = UDim2.fromScale(0.2, 0.5), Position = UDim2.fromScale(0.74, 0.25), ZIndex = 9 })
	end

	-- INCUBATORS
	local ir = row(0.5, "INCUBATORS")
	local chambers = plot and plot:FindFirstChild("Chambers")
	local count = chambers and #chambers:GetChildren() or 0
	for i = 1, 3 do
		local c = chambers and chambers:FindFirstChild("Chamber" .. i)
		local card = box(ir, 0.36 + (i - 1) * 0.215, 0.62, 0.2, 0.62, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(253, 240, 214), ZIndex = 9 })
		new("UICorner", { CornerRadius = UDim.new(0.2, 0) }, card)
		new("UIStroke", { Color = Color3.fromRGB(205, 170, 120), Thickness = 2 }, card)
		if c then
			local l = c:GetAttribute("UpgradeLevel") or 1
			text(card, "#" .. i .. "  LV " .. l, INK, { Size = UDim2.fromScale(0.38, 0.5), Position = UDim2.fromScale(0.04, 0.25), X = Enum.TextXAlignment.Left, ZIndex = 10, Max = 16 })
			if l < 3 then
				local b = button(card, 0.71, 0.5, 0.52, 0.72, "UPGRADE", Color3.fromRGB(214, 52, 45))
				b.ZIndex = 10
				b.Activated:Connect(function() act("UpgradeIncubator", { index = i }) end)
			else
				text(card, "MAX", Color3.fromRGB(235, 175, 30), { Stroke = 1.5, Size = UDim2.fromScale(0.35, 0.5), Position = UDim2.fromScale(0.6, 0.25), ZIndex = 10 })
			end
		elseif i == count + 1 then
			local b = button(card, 0.5, 0.5, 0.8, 0.7, "+ ADD INCUBATOR", GREEN)
			b.Activated:Connect(function() act("AddIncubator") end)
		else
			text(card, "LOCKED", GREY, { Size = UDim2.fromScale(0.6, 0.45), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 10 })
		end
	end

	-- CHARACTER SLOTS
	local sr = row(0.83, "CHARACTER SLOTS")
	local unlocked, nextPrice = 0, nil
 local cap=data.availableSlots or (lv*12)
	for i = 1, cap do
		local s = plot and plot.Slots:FindFirstChild(string.format("Slot%02d", i))
		local on = s and s:GetAttribute("Unlocked")
		if on then unlocked += 1 elseif not nextPrice then nextPrice = s and s:GetAttribute("UnlockPrice") or SLOT_PRICES[i] end
		local pip = box(sr, 0.05 + i * (0.516/cap), 0.68, (0.408/cap), 0.34, { BackgroundTransparency = 0, BackgroundColor3 = on and GREEN or Color3.fromRGB(200, 185, 160), ZIndex = 9 })
		new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, pip)
		new("UIStroke", { Color = INK, Thickness = 1.5 }, pip)
	end
	text(sr, "FLOOR " .. lv, Color3.fromRGB(150, 90, 60), { Size = UDim2.fromScale(0.13, 0.25), Position = UDim2.fromScale(0.6, 0.12), ZIndex = 9, Max = 13 })
	text(sr, unlocked .. " / "..cap, INK, { Size = UDim2.fromScale(0.13, 0.4), Position = UDim2.fromScale(0.6, 0.45), ZIndex = 9 })
	if nextPrice then
		local b = button(sr, 0.86, 0.5, 0.24, 0.62, "UNLOCK • $" .. Config.Short(nextPrice), GREEN)
		b.Activated:Connect(function() act("UnlockSlot") end)
	else
		text(sr, "ALL UNLOCKED", Color3.fromRGB(235, 175, 30), { Stroke = 2, Size = UDim2.fromScale(0.24, 0.45), Position = UDim2.fromScale(0.74, 0.28), ZIndex = 9 })
	end
end

RENDER.Plot = function(panel)
	local data, err = fetch("plot")
	local L = layerOf(panel); clear(L)
	if not data then text(box(L, 0.5, 0.5, 0.6, 0.08), err) return end
	overview(L, data)
end

local open
for _, c in gui:GetChildren() do if c:IsA("ImageLabel") then c.Visible = false end end
dim.Visible = false

local refreshRunning=false
local refreshPending=false
refresh=function()
 refreshPending=true
 if refreshRunning then return end
 refreshRunning=true
 task.spawn(function()
  repeat
   refreshPending=false
   local current=open
   if current and RENDER[current.Name] then
    local ok,err=pcall(RENDER[current.Name],current)
    if not ok then warn("[GameMenus] refresh failed:",err)end
   end
   if refreshPending then task.wait(.06)end
  until not refreshPending
  refreshRunning=false
 end)
end
local function close()
	if not open then return end
	local p = open; open = nil
	UISound.Play("Close")
	closing = p
	TweenService:Create(p.UIScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 * (p:GetAttribute("Fit") or 1) }):Play()
	task.delay(0.15, function() if closing == p then closing = nil end; if open ~= p then p.Visible = false end; if not open then dim.Visible = false end end)
end
local function show(p)
	if open == p then close() return end
	if open then open.Visible = false end
	open = p; p.Visible = true; dim.Visible = true
	if closing == p then closing = nil end
	local fit = p:GetAttribute("Fit") or 1
	p.UIScale.Scale = 0.85 * fit
	TweenService:Create(p.UIScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = fit }):Play()
	UISound.Play("Open")
	refresh()
end
dim.Activated:Connect(close)
Changed.OnClientEvent:Connect(refresh)
do local lr = gui:FindFirstChild("LocalRefresh") or Instance.new("BindableEvent"); lr.Name = "LocalRefresh"; lr.Parent = gui; lr.Event:Connect(function() if refresh then refresh() end end) end

for _, b in side:GetChildren() do
	if b:IsA("GuiButton") then
		local panel = gui:WaitForChild(b:GetAttribute("Panel"))
		panel:WaitForChild("Close").Activated:Connect(close)
		local s = b:FindFirstChildOfClass("UIScale")
		b.MouseEnter:Connect(function()
			UISound.Play("Hover")
			if s then TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1.08 }):Play() end
		end)
		b.MouseLeave:Connect(function() if s then TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1 }):Play() end end)
		local face = b:FindFirstChild("Face", true)
		if face then
			b.MouseButton1Down:Connect(function() TweenService:Create(face, TweenInfo.new(0.06), { Position = UDim2.new(0.5, 0, 0, 9) }):Play() end)
			local function up() TweenService:Create(face, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0, 4) }):Play() end
			b.MouseButton1Up:Connect(up); b.MouseLeave:Connect(up)
		end
		b.Activated:Connect(function()
			UISound.Play("Click")
			show(panel)
		end)
	end
end

-- TileIcons: use the object-only icons once they're set in ReplicatedStorage.GameMenuImages
local imgs = RS:FindFirstChild("GameMenuImages")
if imgs then
	for _, b in side:GetChildren() do
		if b:IsA("GuiButton") then
			local ic = b:FindFirstChild("Icon", true)
			local sh = b:FindFirstChild("IconShadow", true)
			local function upd() local v = imgs:GetAttribute("Tile" .. b.Name); if ic and v and v ~= "" then ic.Image = v; if sh then sh.Image = v end end end
			imgs:GetAttributeChangedSignal("Tile" .. b.Name):Connect(upd); upd()
		end
	end
end
