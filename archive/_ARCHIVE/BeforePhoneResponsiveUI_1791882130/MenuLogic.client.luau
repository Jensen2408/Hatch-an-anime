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
local remotes = RS:WaitForChild("GameMenu"):WaitForChild("Remotes")
local GetState, Action, Changed = remotes:WaitForChild("GetState"), remotes:WaitForChild("Action"), remotes:WaitForChild("Changed")
local Config = require(RS.GameMenu.Config)
local UISound = require(RS:WaitForChild("UISound"))

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

local toast = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -110), Size = UDim2.fromOffset(420, 40),
	BackgroundColor3 = CREAM, FontFace = FONT, TextScaled = true, TextColor3 = INK, Visible = false, ZIndex = 20 }, gui)
new("UICorner", { CornerRadius = UDim.new(0, 12) }, toast)
new("UIStroke", { Color = INK, Thickness = 3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, toast)
new("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 6) }, toast)
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
			local icon = card(row, 0.06, 0.5, 0.075, 0.7, done and GREEN or Color3.fromRGB(214, 52, 45), 0.3, 7)
			text(icon, done and "✓" or "!", Color3.new(1, 1, 1), { Stroke = 2, Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8 })
			text(row, (q.period and (q.period .. ": ") or "") .. q.title, INK, { Size = UDim2.fromScale(0.5, 0.3), Position = UDim2.fromScale(0.13, 0.12), X = Enum.TextXAlignment.Left, Max = 20, ZIndex = 8 })
			local track = new("Frame", { BackgroundColor3 = Color3.fromRGB(110, 70, 45), BorderSizePixel = 0, Size = UDim2.fromScale(0.48, 0.26), Position = UDim2.fromScale(0.13, 0.56), ZIndex = 7 }, row)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
			local f = new("Frame", { BackgroundColor3 = GREEN, BorderSizePixel = 0, Size = UDim2.fromScale(math.clamp(q.progress / q.target, 0.04, 1), 1), ZIndex = 8 }, track)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
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
	local L = layerOf(panel); clear(L)
	local SR = game:GetService("ReplicatedStorage"):FindFirstChild("ShopSystem")
	local remote = SR and SR:FindFirstChild("ShopRemote")
	local SC = SR and require(SR.ShopConfig)
	if not remote then text(box(L, 0.5, 0.5, 0.6, 0.08), "Shop is loading…") return end
	local ok, st = remote:InvokeServer("State")
	if not ok then text(box(L, 0.5, 0.5, 0.6, 0.08), tostring(st)) return end
	local CREAMc, CARDc, EDGEc, REDc, GOLDc, PURPLE = Color3.fromRGB(255, 243, 217), Color3.fromRGB(250, 233, 204), Color3.fromRGB(196, 150, 100), Color3.fromRGB(204, 68, 54), Color3.fromRGB(242, 190, 85), Color3.fromRGB(78, 50, 120)
	local function act2(action, ...)
		local r, msg = remote:InvokeServer(action, ...)
		if msg then say(msg) end
		if r then
			if action and (string.find(action, "Buy") or string.find(action, "Purchase")) then
				UISound.Play("Purchase")
			else
				UISound.Play("Claim")
			end
		end
		RENDER.VipShop(panel)
	end
	local function frame(parent, h, color, order)
		local f = new("Frame", { LayoutOrder = order or 0, Size = UDim2.new(1, -8, 0, h), BackgroundColor3 = color or CARDc, BorderSizePixel = 0 }, parent)
		new("UICorner", { CornerRadius = UDim.new(0, 12) }, f); new("UIStroke", { Color = EDGEc, Thickness = 2 }, f)
		return f
	end
	local function heading(parent, s, order)
		local h = new("Frame", { LayoutOrder = order, Size = UDim2.new(1, -8, 0, 26), BackgroundTransparency = 1 }, parent)
		text(h, s, REDc, { Size = UDim2.fromScale(1, 1), X = Enum.TextXAlignment.Left, Max = 20 })
	end
	local ICON = SC.Icons or {}
	-- real Robux price for THIS player (Roblox may lower it with managed / regional pricing)
	_G.__shopPrices = _G.__shopPrices or {}
	local function live(id, pass, fallback)
		if not id or id == 0 then return fallback end
		local k = (pass and "p" or "d") .. id
		if _G.__shopPrices[k] == nil then
			local ok, info = pcall(game:GetService("MarketplaceService").GetProductInfo, game:GetService("MarketplaceService"), id, pass and Enum.InfoType.GamePass or Enum.InfoType.Product)
			_G.__shopPrices[k] = ok and info and info.PriceInRobux or false
		end
		return _G.__shopPrices[k] or fallback
	end
	local TS = game:GetService("TweenService")
	local function shine(btn)
		local sh = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, ZIndex = (btn.ZIndex or 8) + 2 }, btn)
		new("UICorner", { CornerRadius = UDim.new(0.25, 0) }, sh)
		local g = new("UIGradient", { Rotation = 20, Offset = Vector2.new(-1.2, 0), Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1) }) }, sh)
		task.spawn(function() while sh.Parent do g.Offset = Vector2.new(-1.2, 0); TS:Create(g, TweenInfo.new(0.9, Enum.EasingStyle.Sine), { Offset = Vector2.new(1.2, 0) }):Play(); task.wait(2.6 + math.random()) end end)
		new("Frame", { Position = UDim2.new(0.06, 0, 0.08, 0), Size = UDim2.new(0.88, 0, 0.22, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.7, BorderSizePixel = 0, ZIndex = (btn.ZIndex or 8) + 1 }, btn):SetAttribute("gloss", true)
	end
	local function glowIcon(parent, key, fallback, pos, size, z, color)
		local id = ICON[key] or fallback
		if not id or id == "" then return end
		local holder = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = pos, Size = size, BackgroundTransparency = 1, ZIndex = z or 8 }, parent)
		-- soft golden glow + light rays behind the item (white texture tinted, slowly spinning & pulsing)
		local glow = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.7, 1.7), BackgroundTransparency = 1,
			Image = ICON.Glow or "", ImageColor3 = color or Color3.fromRGB(255, 166, 40), ImageTransparency = 0, ZIndex = (z or 8) }, holder)
		local core = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1.1, 1.1), BackgroundTransparency = 1,
			Image = ICON.Glow or "", ImageColor3 = Color3.fromRGB(255, 226, 120), ImageTransparency = 0.1, Rotation = 11, ZIndex = (z or 8) }, holder)
		TS:Create(core, TweenInfo.new(14, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = -349 }):Play()
		TS:Create(glow, TweenInfo.new(22, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), { Rotation = 360 }):Play()
		local img = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = id, ScaleType = Enum.ScaleType.Fit, ZIndex = (z or 8) + 1 }, holder)
		TS:Create(img, TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Position = UDim2.fromScale(0, -0.05) }):Play()
		TS:Create(core, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { ImageTransparency = 0.6, Size = UDim2.fromScale(1.25, 1.25) }):Play()
		return img
	end
	local function fmtTime(s) s = math.max(0, math.floor(s)); return string.format("%d:%02d:%02d", s // 3600, (s // 60) % 60, s % 60) end
	local inner = box(L, 0.5, 0.545, 0.8, 0.63)
	local sf = new("ScrollingFrame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6, ScrollBarImageColor3 = EDGEc,
		CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 7 }, inner)
	new("UIListLayout", { Padding = UDim.new(0, 10), SortOrder = Enum.SortOrder.LayoutOrder, HorizontalAlignment = Enum.HorizontalAlignment.Center }, sf)
	new("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingBottom = UDim.new(0, 8) }, sf)

	-- DAILY REWARDS -------------------------------------------------------
	heading(sf, "DAILY REWARDS", 1)
	local daily = frame(sf, 190, CARDc, 2)
	local d = st.daily
	for i, r in SC.Daily do
		local claimed = (i < d.day) or (i == d.day and not d.ready)
		local today = i == d.day and d.ready
		local tile = new("Frame", { Position = UDim2.new((i - 1) / 7, 6, 0, 8), Size = UDim2.new(1 / 7, -10, 0, 124), BackgroundColor3 = today and GOLDc or (i == 7 and Color3.fromRGB(150, 50, 45) or CREAMc), BorderSizePixel = 0, ZIndex = 8 }, daily)
		new("UICorner", { CornerRadius = UDim.new(0, 10) }, tile); new("UIStroke", { Color = today and INK or EDGEc, Thickness = today and 2.5 or 1.5 }, tile)
		text(tile, "DAY " .. i, i == 7 and GOLDc or INK, { Size = UDim2.new(1, 0, 0, 22), Position = UDim2.fromOffset(0, 4), Max = 16, ZIndex = 9 })
		local key = r.kind == "cash" and "Coins" or r.kind == "mystery" and "Chest" or r.boost
		glowIcon(tile, key, nil, UDim2.new(0.5, 0, 0, 48), UDim2.fromOffset(44, 44), 9, today and Color3.new(1, 1, 1) or nil)
		if today then local st2 = tile:FindFirstChildOfClass("UIStroke"); st2.Color = Color3.fromRGB(255, 200, 60); TS:Create(st2, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 4 }):Play() end
		local label = r.label or ("$" .. Config.Short(r.amount))
		text(tile, label, i == 7 and Color3.new(1, 1, 1) or (r.kind == "cash" and Color3.fromRGB(40, 140, 40) or PURPLE), { Stroke = i == 7 and 1.5 or nil, Size = UDim2.new(1, -6, 0, 30), Position = UDim2.new(0.5, 0, 0, 72), AnchorPoint = Vector2.new(0.5, 0), Max = 14, ZIndex = 10 })
		text(tile, claimed and "✓" or (today and "READY" or "🔒"), claimed and GREEN or INK, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.new(0, 0, 1, -22), Max = 14, ZIndex = 9 })
	end
	if d.ready then
		local cb = button(daily, 0.5, 0.86, 0.4, 0.18, "CLAIM DAY " .. d.day, GREEN); cb.ZIndex = 9; shine(cb)
		cb.Activated:Connect(function() act2("ClaimDaily") end)
	else
		local nl = text(daily, "Next reward in " .. fmtTime(d.nextIn), Color3.fromRGB(110, 80, 60), { Size = UDim2.new(1, 0, 0, 24), Position = UDim2.new(0, 0, 1, -34), Max = 16, ZIndex = 9 })
		local endAt = os.clock() + d.nextIn
		task.spawn(function() while nl.Parent and panel.Visible do nl.Text = "Next reward in " .. fmtTime(endAt - os.clock()); task.wait(1) end end)
	end

	-- VIP -----------------------------------------------------------------
	heading(sf, "SHOP", 3)
	local vip = frame(sf, 120, PURPLE, 4)
	vip.Size = UDim2.new(1, -8, 0, 140)
	new("UIGradient", { Rotation = 0, Color = ColorSequence.new(Color3.fromRGB(120, 70, 170), Color3.fromRGB(60, 36, 100)) }, vip)
	glowIcon(vip, "Crown", "rbxassetid://95157813840098", UDim2.new(0.11, 0, 0.5, 0), UDim2.fromOffset(110, 110), 8)
	text(vip, "VIP", GOLDc, { Stroke = 2, Size = UDim2.new(0.4, 0, 0, 36), Position = UDim2.new(0.21, 0, 0, 8), X = Enum.TextXAlignment.Left, Max = 34, ZIndex = 8 })
	text(vip, "Crown over your head  •  Gold [VIP] chat tag\n+10% cash  •  2× daily cash rewards", Color3.fromRGB(235, 225, 255), { Size = UDim2.new(0.5, 0, 0, 48), Position = UDim2.new(0.21, 0, 0, 48), X = Enum.TextXAlignment.Left, Max = 15, ZIndex = 8 })
	local vb = button(vip, 0.84, 0.5, 0.26, 0.5, st.vip and "OWNED" or (SC.GamePasses.VIP == 0 and "SOON" or (live(SC.GamePasses.VIP, true, SC.Prices.VIP) .. " R$")), st.vip and GREY or GREEN); vb.ZIndex = 9; if not st.vip then shine(vb) end
	if not st.vip then vb.Activated:Connect(function() act2("Buy", "VIP") end) end

	-- boosts + starter pack row
	local row = new("Frame", { LayoutOrder = 5, Size = UDim2.new(1, -8, 0, 230), BackgroundTransparency = 1 }, sf)
	local function tile(i, title, desc, key, color, extra)
		local t = new("Frame", { Position = UDim2.new((i - 1) / 3, i == 1 and 0 or 5, 0, 0), Size = UDim2.new(1 / 3, -7, 1, 0), BackgroundColor3 = CARDc, BorderSizePixel = 0, ZIndex = 7 }, row)
		new("UICorner", { CornerRadius = UDim.new(0, 12) }, t); new("UIStroke", { Color = EDGEc, Thickness = 2 }, t)
		text(t, title, color or INK, { Stroke = 1, Size = UDim2.new(1, -10, 0, 26), Position = UDim2.new(0.5, 0, 0, 8), AnchorPoint = Vector2.new(0.5, 0), Max = 20, ZIndex = 8 })
		glowIcon(t, key, nil, UDim2.new(0.5, 0, 0, 92), UDim2.fromOffset(96, 96), 8)
		local dl = text(t, desc, Color3.fromRGB(110, 80, 60), { Size = UDim2.new(1, -14, 0, 30), Position = UDim2.new(0.5, 0, 0, 142), AnchorPoint = Vector2.new(0.5, 0), Max = 13, ZIndex = 10 })
		local owned = extra and extra.owned
		local price = owned and "OWNED" or ((key and (SC.GamePasses[key] or SC.Products[key]) == 0) and "SOON" or (live(SC.GamePasses[key] or SC.Products[key], SC.GamePasses[key] ~= nil, SC.Prices[key]) .. " R$"))
		local b = button(t, 0.5, 0.88, 0.8, 0.17, price, owned and GREY or GREEN); b.ZIndex = 9; if not owned then shine(b) end
		if not owned then b.Activated:Connect(function() act2("Buy", key) end) end
		return dl
	end
	tile(1, "STARTER PACK", "$" .. Config.Short(SC.StarterPack.cash) .. " + 30 min 2× money & hatch", "StarterPack", REDc, { owned = st.starter })
	local function boostDesc(untilT, what) local left = untilT - st.serverTime; return left > 0 and ("ACTIVE • " .. fmtTime(left)) or ("2× " .. what .. " for " .. SC.BoostMinutes .. " min") end
	local m2 = tile(2, "2× MONEY", boostDesc(st.money2xUntil, "money"), "Money2x", Color3.fromRGB(40, 140, 40))
	local h2 = tile(3, "2× HATCH", boostDesc(st.hatch2xUntil, "hatch speed"), "Hatch2x", Color3.fromRGB(64, 140, 220))
	local t0 = os.clock()
	task.spawn(function() while m2.Parent and panel.Visible do
		local tnow = st.serverTime + (os.clock() - t0)
		if st.money2xUntil > tnow then m2.Text = "ACTIVE • " .. fmtTime(st.money2xUntil - tnow) end
		if st.hatch2xUntil > tnow then h2.Text = "ACTIVE • " .. fmtTime(st.hatch2xUntil - tnow) end
		task.wait(1) end end)

	-- money multiplier (in-game cash, up to 1000x)
	local mm = frame(sf, 96, CARDc, 6)
	local lvl = st.moneyLevel
	local cur = lvl > 0 and SC.MoneyLevels[lvl].mult or 1
	local nxt = SC.MoneyLevels[lvl + 1]
	text(mm, "MONEY MULTIPLIER", INK, { Size = UDim2.new(0.6, 0, 0, 24), Position = UDim2.fromOffset(14, 8), X = Enum.TextXAlignment.Left, Max = 20, ZIndex = 8 })
	text(mm, nxt and (cur .. "×  →  " .. nxt.mult .. "×   (max 1000×)") or "1000×  •  MAXED!", Color3.fromRGB(40, 140, 40), { Size = UDim2.new(0.6, 0, 0, 22), Position = UDim2.fromOffset(14, 34), X = Enum.TextXAlignment.Left, Max = 17, ZIndex = 8 })
	for i = 1, #SC.MoneyLevels do
		local pip = new("Frame", { Position = UDim2.new(0, 14 + (i - 1) * 20, 0, 66), Size = UDim2.fromOffset(15, 15), BackgroundColor3 = i <= lvl and GOLDc or Color3.fromRGB(214, 195, 165), BorderSizePixel = 0, ZIndex = 8 }, mm)
		new("UICorner", { CornerRadius = UDim.new(0, 4) }, pip); new("UIStroke", { Color = INK, Thickness = 1.5 }, pip)
	end
	if nxt then
		local ub = button(mm, 0.84, 0.5, 0.26, 0.5, nxt.productId == 0 and "SOON" or (live(nxt.productId, false, nxt.robux) .. " R$"), GREEN); ub.ZIndex = 9; shine(ub)
		glowIcon(mm, "Money2x", nil, UDim2.new(0.62, 0, 0.5, 0), UDim2.fromOffset(70, 70), 8)
		ub.Activated:Connect(function() act2("BuyMoneyLevel") end)
	end

	-- cash packs
	heading(sf, "CASH PACKS", 7)
	local packs = new("Frame", { LayoutOrder = 8, Size = UDim2.new(1, -8, 0, 150), BackgroundTransparency = 1 }, sf)
	for i, k in { "CashSmall", "CashMedium", "CashLarge" } do
		local t = new("Frame", { Position = UDim2.new((i - 1) / 3, i == 1 and 0 or 5, 0, 0), Size = UDim2.new(1 / 3, -7, 1, 0), BackgroundColor3 = CARDc, BorderSizePixel = 0, ZIndex = 7 }, packs)
		new("UICorner", { CornerRadius = UDim.new(0, 12) }, t); new("UIStroke", { Color = EDGEc, Thickness = 2 }, t)
		glowIcon(t, "Coins", nil, UDim2.new(0.5, 0, 0, 30 + i * 2), UDim2.fromOffset(44 + i * 8, 44 + i * 8), 8)
		text(t, "$" .. Config.Short(SC.CashPacks[k]), Color3.fromRGB(40, 140, 40), { Stroke = 1, Size = UDim2.new(1, 0, 0, 24), Position = UDim2.fromOffset(0, 72), Max = 20, ZIndex = 10 })
		local b = button(t, 0.5, 0.83, 0.8, 0.24, SC.Products[k] == 0 and "SOON" or (live(SC.Products[k], false, SC.Prices[k]) .. " R$"), GREEN); b.ZIndex = 9
		shine(b); b.Activated:Connect(function() act2("Buy", k) end)
	end

	-- coming soon egg
	local cs = frame(sf, 84, Color3.fromRGB(40, 32, 70), 9)
	text(cs, "COMING SOON", GOLDc, { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 8), Max = 14, ZIndex = 8 })
	text(cs, SC.ComingSoonEgg.name, Color3.new(1, 1, 1), { Stroke = 1.5, Size = UDim2.new(1, 0, 0, 30), Position = UDim2.fromOffset(0, 26), Max = 26, ZIndex = 8 })
	text(cs, SC.ComingSoonEgg.text, Color3.fromRGB(190, 200, 255), { Size = UDim2.new(1, 0, 0, 18), Position = UDim2.fromOffset(0, 58), Max = 14, ZIndex = 8 })
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
 action(hero,"UpgradeTemple",.66,23,.305,40,level>=3 and "MAX LEVEL" or data.canUpgrade and "UPGRADE TEMPLE" or unlocked.." / "..cap.." SLOTS",data.canUpgrade and RED or Color3.fromRGB(159,139,112),level<3 and function()
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
   action(f,"UpgradeIncubator"..i,.07,55,.86,31,lv<3 and "UPGRADE"or"MAX LEVEL",lv<3 and RED or MUTED,lv<3 and function()act("UpgradeIncubator",{index=i})end or nil)
  elseif i==count+1 then action(f,"AddIncubator",.07,55,.86,31,"+ ADD",Color3.fromRGB(70,151,74),function()act("AddIncubator")end)
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
  local b = button(t, 0.84, 0.5, 0.26, 0.62, allowed and "UPGRADE • FREE" or "BUY ALL SLOTS", allowed and Color3.fromRGB(214,52,45) or Color3.fromRGB(150,135,115))
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
	TweenService:Create(p.UIScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
	task.delay(0.15, function() if open ~= p then p.Visible = false end; if not open then dim.Visible = false end end)
end
local function show(p)
	if open == p then close() return end
	if open then open.Visible = false end
	open = p; p.Visible = true; dim.Visible = true
	p.UIScale.Scale = 0.85
	TweenService:Create(p.UIScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
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
			b.MouseButton1Down:Connect(function() TweenService:Create(face, TweenInfo.new(0.06), { Position = UDim2.new(0.5, 0, 0.5, 2) }):Play() end)
			local function up() TweenService:Create(face, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0.5, -2) }):Play() end
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
