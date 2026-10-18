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
local function act(name, args)
	local ok, res, msg = pcall(function() return Action:InvokeServer(name, args) end)
	if not ok then say("Server error"); return false end
	say(msg)
	return res
end
local function fetch(section)
	local ok, data = pcall(function() return GetState:InvokeServer(section) end)
	if not ok or type(data) ~= "table" then return nil, "Couldn't load" end
	if data.error then return nil, data.error end
	return data
end

local RENDER = {}

RENDER.Index = function(panel)
	local data, err = fetch("index")
	local L = layerOf(panel); clear(L)
	if not data then text(box(L, 0.5, 0.5, 0.6, 0.08), err) return end
	local found = 0
	local cols = { 0.208, 0.354, 0.5, 0.646, 0.792 }
	local rows = { 0.44, 0.625, 0.811 }
	for i, c in data.catalog.characters do
		if i > 15 then break end
		local got = data.discovered[c.id] == true
		if got then found += 1 end
		local cell = box(L, cols[(i - 1) % 5 + 1], rows[math.floor((i - 1) / 5) + 1], 0.118, 0.16)
		if got then
			text(cell, c.name, Color3.new(1, 1, 1), { Stroke = 2, Size = UDim2.fromScale(0.92, 0.26), Position = UDim2.fromScale(0.5, 0.72), AnchorPoint = Vector2.new(0.5, 0.5) })
			text(cell, "✓", RARITY[c.rarity] or GREEN, { Stroke = 2.5, Size = UDim2.fromScale(0.5, 0.45), Position = UDim2.fromScale(0.5, 0.32), AnchorPoint = Vector2.new(0.5, 0.5) })
		else
			text(cell, "???", GREY, { Size = UDim2.fromScale(0.7, 0.24), Position = UDim2.fromScale(0.5, 0.78), AnchorPoint = Vector2.new(0.5, 0.5) })
		end
	end
	local bar = box(L, 0.5, 0.295, 0.43, 0.075, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(150, 95, 50) })
	new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, bar)
	local fill = new("Frame", { BackgroundColor3 = GREEN, BorderSizePixel = 0, Size = UDim2.fromScale(math.max(found / 15 * 0.94, 0.02), 0.38), Position = UDim2.fromScale(0.03, 0.55), ZIndex = 8 }, bar)
	new("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	text(bar, found .. " / 15 found", Color3.new(1, 1, 1), { Stroke = 2, Size = UDim2.fromScale(0.9, 0.5), Position = UDim2.fromScale(0.5, 0.05), AnchorPoint = Vector2.new(0.5, 0) })
end

RENDER.Quests = function(panel)
	local data, err = fetch("quests")
	local L = layerOf(panel); clear(L)
	if not data then text(box(L, 0.5, 0.5, 0.6, 0.08), err) return end
	local list = table.clone(data.list or {})
	table.sort(list, function(a, b)
		local ac, bc = a.claimed and 1 or 0, b.claimed and 1 or 0
		if ac ~= bc then return ac < bc end
		local ad, bd = (a.progress >= a.target) and 0 or 1, (b.progress >= b.target) and 0 or 1
		if ad ~= bd then return ad < bd end
		return (a.order or 0) < (b.order or 0)
	end)
	local rows = { 0.396, 0.581, 0.766 }
	for i = 1, 3 do
		local q = list[i]
		local row = box(L, 0.548, rows[i], 0.57, 0.14, { BackgroundTransparency = 0, BackgroundColor3 = Color3.fromRGB(250, 232, 200) })
		new("UICorner", { CornerRadius = UDim.new(0.15, 0) }, row)
		if q then
			local done = q.progress >= q.target
			text(row, (q.period and (q.period .. ": ") or "") .. q.title, INK, { Size = UDim2.fromScale(0.48, 0.28), Position = UDim2.fromScale(0.05, 0.12), X = Enum.TextXAlignment.Left, Max = 20 })
			local track = new("Frame", { BackgroundColor3 = Color3.fromRGB(90, 55, 35), BorderSizePixel = 0, Size = UDim2.fromScale(0.46, 0.22), Position = UDim2.fromScale(0.05, 0.6), ZIndex = 8 }, row)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, track)
			local f = new("Frame", { BackgroundColor3 = GREEN, BorderSizePixel = 0, Size = UDim2.fromScale(math.clamp(q.progress / q.target, 0.03, 1), 1), ZIndex = 9 }, track)
			new("UICorner", { CornerRadius = UDim.new(1, 0) }, f)
			text(track, math.min(q.progress, q.target) .. " / " .. q.target, Color3.new(1, 1, 1), { Stroke = 1.5, ZIndex = 10 })
			local reward = q.reward and q.reward.cash and ("$" .. Config.Short(q.reward.cash)) or ""
			text(row, reward, Color3.fromRGB(40, 140, 40), { Size = UDim2.fromScale(0.18, 0.45), Position = UDim2.fromScale(0.56, 0.28) })
			local label = q.claimed and "DONE" or done and "CLAIM" or "..."
			local b = button(row, 0.85, 0.5, 0.2, 0.55, label, (done and not q.claimed) and GREEN or GREY)
			if done and not q.claimed then b.Activated:Connect(function() act("Claim", { id = q.id }) end) end
		else
			text(row, "No more quests right now", GREY, { Size = UDim2.fromScale(0.8, 0.35), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
		end
	end
end

RENDER.VipShop = function(panel)
	local data, err = fetch("shop")
	local L = layerOf(panel); clear(L)
	if not data then text(box(L, 0.5, 0.5, 0.6, 0.08), err) return end
	local items = {}
	if #data.items == 0 then text(box(L, 0.5, 0.55, 0.6, 0.1), "New VIP items coming soon!", INK, { Max = 30 }) return end
	for _, it in data.items do if #items < 3 then table.insert(items, it) end end
	local cols = { 0.261, 0.5, 0.739 }
	for i, it in items do
		local card = box(L, cols[i], 0.53, 0.17, 0.25)
		text(card, it.name, INK, { Size = UDim2.fromScale(0.95, 0.28), Position = UDim2.fromScale(0.5, 0.32), AnchorPoint = Vector2.new(0.5, 0.5) })
		text(card, it.description or "", Color3.fromRGB(120, 90, 70), { Size = UDim2.fromScale(0.95, 0.2), Position = UDim2.fromScale(0.5, 0.66), AnchorPoint = Vector2.new(0.5, 0.5) })
		local price
		if it.owned then price = "OWNED"
		elseif not it.available then price = "SOON"
		elseif it.kind == "cash" then price = "$" .. Config.Short(it.price)
		else price = "R$ BUY" end
		local hit = box(L, cols[i], 0.757, 0.18, 0.105, { Class = "TextButton", Text = "", ZIndex = 8 })
		text(hit, price, Color3.new(1, 1, 1), { Stroke = 2, Size = UDim2.fromScale(0.8, 0.6), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 9 })
		if it.available and not it.owned then hit.Activated:Connect(function() act("Buy", { id = it.id }) end)
		else hit.Activated:Connect(function() say(it.owned and "You own this already" or "Coming soon") end) end
	end
end

local plotPage = "overview" -- "overview" | "upgrades"
local SLOT_PRICES = { 0, 250, 2500, 25000, 150000, 750000, 5000000, 25000000, 150000000, 750000000, 3000000000, 15000000000 }

local function myPlot()
	for _, p in workspace.Plots:GetChildren() do if p:GetAttribute("OwnerUserId") == player.UserId then return p end end
end

-- page switch tab on top of the panel
local function tabs(L, panel)
	local bar = box(L, 0.24, 0.887, 0.3, 0.075)
	local function tab(x, label, page)
		local on = plotPage == page
		local b = button(bar, x, 0.5, 0.48, 1, label, on and Color3.fromRGB(214, 52, 45) or Color3.fromRGB(150, 120, 100))
		b.Activated:Connect(function() if plotPage ~= page then plotPage = page; RENDER.Plot(panel) end end)
	end
	tab(0.25, "OVERVIEW", "overview")
	tab(0.75, "UPGRADES", "upgrades")
end

local function overview(L, data)
	local placed, stored = {}, 0
	for _, it in data.items do if it.state == "placed" then table.insert(placed, it) else stored += 1 end end
	local income = 0; for _, it in placed do income += it.income or 0 end
	local info = box(L, 0.585, 0.398, 0.6, 0.2)
	text(info, "TEMPLE LEVEL " .. data.level .. (data.level >= 3 and "  •  MAX" or " / 3"), INK, { Size = UDim2.fromScale(0.95, 0.3), Position = UDim2.fromScale(0.03, 0.05), X = Enum.TextXAlignment.Left })
	text(info, ("Characters placed: %d / %d    •    In backpack: %d"):format(#placed, data.unlocked or 0, stored), Color3.fromRGB(110, 80, 60), { Size = UDim2.fromScale(0.95, 0.2), Position = UDim2.fromScale(0.03, 0.42), X = Enum.TextXAlignment.Left })
	text(info, "Income: $" .. Config.Short(income) .. " / sec", Color3.fromRGB(40, 140, 40), { Size = UDim2.fromScale(0.95, 0.22), Position = UDim2.fromScale(0.03, 0.7), X = Enum.TextXAlignment.Left })
	local plot = myPlot()
	local chambers = plot and plot:FindFirstChild("Chambers")
	local incX = { 0.152, 0.246, 0.340, 0.435 }
	for i = 1, 4 do
		local c = chambers and chambers:FindFirstChild("Chamber" .. i)
		local cell = box(L, incX[i], 0.707, 0.08, 0.16)
		if c then
			text(cell, "LV " .. (c:GetAttribute("UpgradeLevel") or 1), INK, { Size = UDim2.fromScale(0.8, 0.3), Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0.5) })
			text(cell, tostring(c:GetAttribute("Status") or "Ready"), Color3.fromRGB(110, 80, 60), { Size = UDim2.fromScale(0.9, 0.2), Position = UDim2.fromScale(0.5, 0.7), AnchorPoint = Vector2.new(0.5, 0.5), Max = 14 })
		else
			text(cell, i <= 3 and "EMPTY" or "—", GREY, { Size = UDim2.fromScale(0.8, 0.25), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
		end
	end
	table.sort(placed, function(x, y) return (x.income or 0) > (y.income or 0) end)
	local slotX = { 0.553, 0.649, 0.745, 0.841 }
	for i = 1, 4 do
		local it = placed[i]
		local cell = box(L, slotX[i], 0.707, 0.085, 0.16)
		if it then
			text(cell, it.name, RARITY[it.rarity] or INK, { Stroke = 1.5, Size = UDim2.fromScale(0.95, 0.26), Position = UDim2.fromScale(0.5, 0.3), AnchorPoint = Vector2.new(0.5, 0.5) })
			text(cell, "$" .. Config.Short(it.income or 0) .. "/s", Color3.fromRGB(40, 140, 40), { Size = UDim2.fromScale(0.9, 0.22), Position = UDim2.fromScale(0.5, 0.7), AnchorPoint = Vector2.new(0.5, 0.5) })
		else
			text(cell, "EMPTY", GREY, { Size = UDim2.fromScale(0.8, 0.25), Position = UDim2.fromScale(0.5, 0.5), AnchorPoint = Vector2.new(0.5, 0.5) })
		end
	end
	local eb = button(L, 0.82, 0.887, 0.16, 0.075, "EQUIP BEST", Color3.fromRGB(64, 140, 220))
	eb.Activated:Connect(function() act("EquipBest") end)
	local up = box(L, 0.496, 0.887, 0.25, 0.1, { Class = "TextButton", Text = "", ZIndex = 8 })
	up.Activated:Connect(function() act("UpgradeTemple") end)
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
		local b = button(t, 0.84, 0.5, 0.26, 0.62, "UPGRADE • FREE", Color3.fromRGB(214, 52, 45))
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
			text(card, "#" .. i .. "  LV " .. l, INK, { Size = UDim2.fromScale(0.5, 0.5), Position = UDim2.fromScale(0.05, 0.25), X = Enum.TextXAlignment.Left, ZIndex = 10 })
			if l < 3 then
				local b = button(card, 0.77, 0.5, 0.42, 0.7, "UPGRADE", Color3.fromRGB(214, 52, 45))
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
	for i = 1, 12 do
		local s = plot and plot.Slots:FindFirstChild(string.format("Slot%02d", i))
		local on = s and s:GetAttribute("Unlocked")
		if on then unlocked += 1 elseif not nextPrice then nextPrice = SLOT_PRICES[i] end
		local pip = box(sr, 0.05 + i * 0.043, 0.68, 0.034, 0.34, { BackgroundTransparency = 0, BackgroundColor3 = on and GREEN or Color3.fromRGB(200, 185, 160), ZIndex = 9 })
		new("UICorner", { CornerRadius = UDim.new(0.3, 0) }, pip)
		new("UIStroke", { Color = INK, Thickness = 1.5 }, pip)
	end
	text(sr, unlocked .. " / 12", INK, { Size = UDim2.fromScale(0.13, 0.4), Position = UDim2.fromScale(0.6, 0.45), ZIndex = 9 })
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
	tabs(L, panel)
	if plotPage == "upgrades" then upgrades(L, data) else overview(L, data) end
end

local open
for _, c in gui:GetChildren() do if c:IsA("ImageLabel") then c.Visible = false end end
dim.Visible = false

local function refresh()
	if open and RENDER[open.Name] then task.spawn(RENDER[open.Name], open) end
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
