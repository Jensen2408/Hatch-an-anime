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
 if res and refresh then refresh()end
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
	local data, err = fetch("shop")
	local L = layerOf(panel); clear(L)
	if not data then text(box(L, 0.5, 0.5, 0.6, 0.08), err) return end
	local inner = innerOf(L)
	if #data.items == 0 then
		local c = card(inner, 0.5, 0.5, 0.7, 0.4, CARD_C, 0.2)
		text(c, "👑", INK, { Size = UDim2.fromScale(0.3, 0.4), Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8, Max = 60 })
		text(c, "New VIP items coming soon!", INK, { Size = UDim2.fromScale(0.85, 0.22), Position = UDim2.fromScale(0.5, 0.72), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8, Max = 30 })
		return
	end
	local items = {}
	for _, it in data.items do if #items < 3 then table.insert(items, it) end end
	for i, it in items do
		local c = card(inner, 0.17 + (i - 1) * 0.33, 0.5, 0.3, 0.95, CARD_C, 0.1)
		text(c, it.name, INK, { Stroke = 1, Size = UDim2.fromScale(0.9, 0.12), Position = UDim2.fromScale(0.5, 0.14), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8 })
		text(c, it.description or "", Color3.fromRGB(120, 90, 70), { Size = UDim2.fromScale(0.9, 0.3), Position = UDim2.fromScale(0.5, 0.48), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8, Max = 18 })
		local price
		if it.owned then price = "OWNED"
		elseif not it.available then price = "SOON"
		elseif it.kind == "cash" then price = "$" .. Config.Short(it.price)
		else price = "R$ BUY" end
		local ok = it.available and not it.owned
		local b = button(c, 0.5, 0.84, 0.8, 0.16, price, ok and GREEN or GREY)
		if ok then b.Activated:Connect(function() act("Buy", { id = it.id }) end)
		else b.Activated:Connect(function() say(it.owned and "You own this already" or "Coming soon") end) end
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
	local CREAM, EDGE, CELL = Color3.fromRGB(253, 241, 218), Color3.fromRGB(196, 150, 100), Color3.fromRGB(246, 226, 192)
	local RED = Color3.fromRGB(214, 52, 45)
	local placed, stored = {}, 0
	for _, it in data.items do if it.state == "placed" then table.insert(placed, it) else stored += 1 end end
	local income = 0; for _, it in placed do income += it.income or 0 end
	local cap = data.availableSlots or (data.level * 12)
	local plot = myPlot()

	-- top info
	local inner = box(L, 0.5, 0.545, 0.79, 0.62)
	local CARD = Color3.fromRGB(250, 233, 204)
	local function frame(f, r) new("UICorner", { CornerRadius = UDim.new(r or 0.12, 0) }, f); new("UIStroke", { Color = EDGE, Thickness = 2 }, f); return f end
	local top = frame(box(inner, 0.5, 0.15, 1, 0.28, { BackgroundTransparency = 0, BackgroundColor3 = CARD, ZIndex = 6 }), 0.18)
	local badge = frame(box(top, 0.09, 0.5, 0.13, 0.78, { BackgroundTransparency = 0, BackgroundColor3 = RED, ZIndex = 7 }), 0.2)
	new("ImageLabel", { BackgroundTransparency = 1, Image = "rbxassetid://77749732102580", ScaleType = Enum.ScaleType.Fit, Size = UDim2.fromScale(0.9, 0.66), Position = UDim2.fromScale(0.5, 0.38), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8 }, badge)
	text(badge, "LV " .. data.level, Color3.new(1, 1, 1), { Stroke = 1.5, Size = UDim2.fromScale(0.9, 0.3), Position = UDim2.fromScale(0.5, 0.8), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 8 })
	local info = box(top, 0.6, 0.5, 0.8, 0.9, { ZIndex = 7 })
	text(info, "TEMPLE LEVEL " .. data.level .. (data.level >= 3 and "  •  MAX" or " / 3"), INK, { ZIndex = 8, Size = UDim2.fromScale(0.58, 0.3), Position = UDim2.fromScale(0.03, 0.05), X = Enum.TextXAlignment.Left })
	text(info, ("Placed: %d / %d  •  Backpack: %d"):format(#placed, data.unlocked or 0, stored), Color3.fromRGB(110, 80, 60), { ZIndex = 8, Size = UDim2.fromScale(0.58, 0.2), Position = UDim2.fromScale(0.03, 0.42), X = Enum.TextXAlignment.Left })
	text(info, "Income: $" .. Config.Short(income) .. " / sec", Color3.fromRGB(40, 140, 40), { ZIndex = 8, Size = UDim2.fromScale(0.58, 0.22), Position = UDim2.fromScale(0.03, 0.7), X = Enum.TextXAlignment.Left })
	local slot = box(info, 0.79, 0.5, 0.38, 0.62, { ZIndex = 8 })
	if data.level >= 3 then
		text(slot, "TEMPLE MAXED", Color3.fromRGB(235, 175, 30), { Stroke = 2, Size = UDim2.fromScale(0.9, 0.6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
	elseif data.canUpgrade then
		local up = button(slot, 0.5, 0.5, 1, 1, "UPGRADE ▶ LV " .. (data.level + 1), RED)
		up.Activated:Connect(function() act("UpgradeTemple") end)
		local st = up:FindFirstChildWhichIsA("UIStroke") or new("UIStroke", { Thickness = 3 }, up)
		st.Color = Color3.fromRGB(255, 210, 60)
		game:GetService("TweenService"):Create(st, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Thickness = 6 }):Play()
	else
		local up = button(slot, 0.5, 0.5, 1, 1, "🔒 SLOTS " .. (data.unlocked or 0) .. "/" .. cap, Color3.fromRGB(150, 135, 115)); up.AutoButtonColor = false
		up.Activated:Connect(function() say("Unlock all " .. cap .. " character slots to upgrade your temple") end)
	end

	-- one clean sheet over the whole lower area (hides the baked sections + bottom bar)
	local sheet = box(inner, 0.5, 0.66, 1, 0.68, { ZIndex = 6 })
	local function section(cx, w, title)
		local f = box(sheet, cx, 0.45, w, 0.62, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(250, 233, 204), ZIndex = 7 })
		new("UICorner", { CornerRadius = UDim.new(0.12, 0) }, f)
		new("UIStroke", { Color = EDGE, Thickness = 2 }, f)
		local tag = box(sheet, cx, 0.14, w * 0.55, 0.12, { BackgroundTransparency = 0, BackgroundColor3 = RED, ZIndex = 9 })
		new("UICorner", { CornerRadius = UDim.new(0.35, 0) }, tag)
		new("UIStroke", { Color = Color3.fromRGB(120, 25, 20), Thickness = 2 }, tag)
		text(tag, title, Color3.new(1, 1, 1), { Stroke = 1.5, Size = UDim2.fromScale(0.9, 0.8), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 10, Max = 18 })
		return f
	end
	local function cell(parent, cx, w)
		local c = box(parent, cx, 0.55, w, 0.78, { BackgroundTransparency = 0, BackgroundColor3 = CELL, ZIndex = 8 })
		new("UICorner", { CornerRadius = UDim.new(0.15, 0) }, c)
		new("UIStroke", { Color = Color3.fromRGB(215, 178, 130), Thickness = 1.5 }, c)
		return c
	end

	-- incubators (3)
	local inc = section(0.245, 0.49, "INCUBATORS")
	local chambers = plot and plot:FindFirstChild("Chambers")
	local count = chambers and #chambers:GetChildren() or 0
	for i = 1, 3 do
		local c = chambers and chambers:FindFirstChild("Chamber" .. i)
		local ce = cell(inc, 0.18 + (i - 1) * 0.32, 0.28)
		if c then
			local cl = c:GetAttribute("UpgradeLevel") or 1
			text(ce, "LV " .. cl, INK, { Stroke = 1, Size = UDim2.fromScale(0.8, 0.24), Position = UDim2.fromScale(0.5, 0.17), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 9 })
			text(ce, tostring(c:GetAttribute("Status") or "Ready"), Color3.fromRGB(110, 80, 60), { Size = UDim2.fromScale(0.9, 0.15), Position = UDim2.fromScale(0.5, 0.42), AnchorPoint = Vector2.new(0.5, 0.5), Max = 13, ZIndex = 9 })
			if cl < 3 then
				local ub = button(ce, 0.5, 0.76, 0.88, 0.32, "UPGRADE", RED); ub.ZIndex = 9
				ub.Activated:Connect(function() act("UpgradeIncubator", { index = i }) end)
			else
				text(ce, "MAX", Color3.fromRGB(235, 175, 30), { Stroke = 1.5, Size = UDim2.fromScale(0.8, 0.3), Position = UDim2.fromScale(0.5, 0.76), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 9 })
			end
		elseif i == count + 1 then
			local ab = button(ce, 0.5, 0.5, 0.88, 0.5, "+ ADD", GREEN); ab.ZIndex = 9
			ab.Activated:Connect(function() act("AddIncubator") end)
		else
			text(ce, "LOCKED", GREY, { Size = UDim2.fromScale(0.8, 0.22), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 9 })
		end
	end

	-- character slots: one cell per unlocked slot + a buy cell
	local cs = section(0.755, 0.49, "CHARACTER SLOTS")
	local sf = box(cs, 0.5, 0.55, 0.95, 0.86, { Class = "ScrollingFrame", ZIndex = 8, ScrollBarThickness = 5, ScrollingDirection = Enum.ScrollingDirection.X, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarImageColor3 = EDGE, BorderSizePixel = 0 })
	new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 6), VerticalAlignment = Enum.VerticalAlignment.Center }, sf)
	new("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 4) }, sf)
	table.sort(placed, function(x, y) return (x.income or 0) > (y.income or 0) end)
	local cells = {}
	local function sc(i)
		local c = new("Frame", { LayoutOrder = i, Size = UDim2.new(0, 70, 0.86, 0), BackgroundColor3 = CELL, ZIndex = 9 }, sf)
		new("UICorner", { CornerRadius = UDim.new(0.15, 0) }, c)
		new("UIStroke", { Color = Color3.fromRGB(215, 178, 130), Thickness = 1.5 }, c)
		table.insert(cells, c); return c
	end
	for i = 1, math.max(1, data.unlocked or 1) do
		local it, c = placed[i], sc(i)
		if it then
			text(c, it.name, RARITY[it.rarity] or INK, { Stroke = 1.5, Size = UDim2.fromScale(0.92, 0.26), Position = UDim2.fromScale(0.5, 0.32), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 10 })
			text(c, "$" .. Config.Short(it.income or 0) .. "/s", Color3.fromRGB(40, 140, 40), { Size = UDim2.fromScale(0.9, 0.2), Position = UDim2.fromScale(0.5, 0.7), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 10 })
		else
			text(c, "EMPTY", GREY, { Size = UDim2.fromScale(0.8, 0.22), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 10 })
		end
	end
	if (data.unlocked or 0) < cap and plot then
		local price
		for i = 1, cap do local sl = plot.Slots:FindFirstChild(string.format("Slot%02d", i)); if sl and not sl:GetAttribute("Unlocked") then price = sl:GetAttribute("UnlockPrice"); break end end
		local c = sc(999)
		local bb = button(c, 0.5, 0.5, 0.92, 0.86, "+$" .. Config.Short(price or 0), GREEN); bb.ZIndex = 10
		bb.Activated:Connect(function() act("UnlockSlot") end)
	end
	task.defer(function() for _, c in cells do c.Size = UDim2.new(0, math.max(40, sf.AbsoluteSize.X * 0.23), 0.86, 0) end end)

	-- bottom bar
	local bar = box(sheet, 0.5, 0.88, 1, 0.17, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(250, 233, 204), ZIndex = 7 })
	new("UICorner", { CornerRadius = UDim.new(0.4, 0) }, bar)
	new("UIStroke", { Color = EDGE, Thickness = 2 }, bar)
	text(bar, "💰 $" .. Config.Short(income) .. " / sec   •   " .. #placed .. " characters working", Color3.fromRGB(110, 80, 60), { Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.04, 0.2), X = Enum.TextXAlignment.Left, ZIndex = 8, Max = 18 })
	local eb = button(bar, 0.84, 0.5, 0.28, 0.82, "EQUIP BEST", Color3.fromRGB(64, 140, 220)); eb.ZIndex = 8
	eb.Activated:Connect(function() act("EquipBest") end)
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
	TweenService:Create(p.UIScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0.85 }):Play()
	task.delay(0.15, function() if open ~= p then p.Visible = false end; if not open then dim.Visible = false end end)
end
local function show(p)
	if open == p then close() return end
	if open then open.Visible = false end
	open = p; p.Visible = true; dim.Visible = true
	p.UIScale.Scale = 0.85
	TweenService:Create(p.UIScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	refresh()
end
dim.Activated:Connect(close)
Changed.OnClientEvent:Connect(refresh)

for _, b in side:GetChildren() do
	if b:IsA("GuiButton") then
		local panel = gui:WaitForChild(b:GetAttribute("Panel"))
		panel:WaitForChild("Close").Activated:Connect(close)
		local s = b:FindFirstChildOfClass("UIScale")
		b.MouseEnter:Connect(function() if s then TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1.08 }):Play() end end)
		b.MouseLeave:Connect(function() if s then TweenService:Create(s, TweenInfo.new(0.12), { Scale = 1 }):Play() end end)
		local face = b:FindFirstChild("Face", true)
		if face then
			b.MouseButton1Down:Connect(function() TweenService:Create(face, TweenInfo.new(0.06), { Position = UDim2.new(0.5, 0, 0.5, 2) }):Play() end)
			local function up() TweenService:Create(face, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Position = UDim2.new(0.5, 0, 0.5, -2) }):Play() end
			b.MouseButton1Up:Connect(up); b.MouseLeave:Connect(up)
		end
		b.Activated:Connect(function() show(panel) end)
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
