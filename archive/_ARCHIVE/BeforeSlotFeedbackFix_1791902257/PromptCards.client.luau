--[[ StarterPlayerScripts.PromptCards
One shared controller for every ProximityPrompt: hides Roblox's default prompt UI (Style = Custom, client-side)
and draws a compact cream card instead. The prompt itself still fires the existing server Triggered handlers,
so distance / ownership / price checks stay on the server.
Also adds owner-only PICK UP prompts to occupied character slots (server action: InventoryRequest "PickUp").
]]
local Players = game:GetService("Players")
local PPS = game:GetService("ProximityPromptService")
local UIS = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local RS = game:GetService("ReplicatedStorage")
local UISound = require(RS:WaitForChild("UISound"))
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local CREAM, INK, RED, GOLD, GREEN = Color3.fromRGB(255, 243, 217), Color3.fromRGB(56, 34, 24), Color3.fromRGB(204, 68, 54), Color3.fromRGB(242, 190, 85), Color3.fromRGB(85, 163, 78)
local GREY, MUTED = Color3.fromRGB(160, 145, 128), Color3.fromRGB(120, 92, 70)
local RARITY = { Common = Color3.fromRGB(150, 150, 150), Uncommon = Color3.fromRGB(85, 163, 78), Rare = Color3.fromRGB(70, 130, 220), Epic = Color3.fromRGB(150, 80, 210), Legendary = Color3.fromRGB(235, 160, 30), Mythic = Color3.fromRGB(220, 60, 90), Secret = Color3.fromRGB(30, 30, 30) }
local FONT = Font.new("rbxasset://fonts/families/FredokaOne.json")

local function make(c, p, parent) local o = Instance.new(c); for k, v in p do o[k] = v end; if parent then o.Parent = parent end; return o end
local function short(n)
	n = tonumber(n) or 0
	for _, u in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do if n >= u[1] then local v = n / u[1]; return (v >= 100 and string.format("%d", v) or string.format("%.1f", v):gsub("%.0$", "")) .. u[2] end end
	return tostring(math.floor(n))
end
local function cash() local ls = player:FindFirstChild("leaderstats"); local c = ls and ls:FindFirstChild("Cash"); return c and c.Value or 0 end
local function myPlot()
	local plots = workspace:FindFirstChild("Plots"); if not plots then return end
	for _, p in plots:GetChildren() do if p:GetAttribute("OwnerUserId") == player.UserId then return p end end
end
local function menuRefresh()
	local g = playerGui:FindFirstChild("GameMenus"); local e = g and g:FindFirstChild("LocalRefresh")
	if e then e:Fire() end
end

---------------------------------------------------------------- what a prompt is about
local function ancestorWith(inst, attr)
	while inst and inst ~= workspace do if inst:GetAttribute(attr) ~= nil then return inst end; inst = inst.Parent end
end
local function anchorPos(prompt)
	local p = prompt.Parent
	if p:IsA("Attachment") then return p.WorldPosition end
	if p:IsA("BasePart") then return p.Position end
	if p:IsA("Model") then return p:GetPivot().Position end
end
local function nearestModel(pos, tag, radius)
	local best, bd
	for _, m in CollectionService:GetTagged(tag) do
		if m:IsA("Model") and m:IsDescendantOf(workspace) then
			local d = (m:GetPivot().Position - pos).Magnitude
			if d < radius and (not bd or d < bd) then best, bd = m, d end
		end
	end
	return best
end
local function placedOn(slot)
	local plat = slot:FindFirstChild("Platform"); if not plat then return end
	local plot = slot.Parent and slot.Parent.Parent
	local best, bd
	for _, d in (plot or slot):GetDescendants() do
		if d:IsA("Model") and d:GetAttribute("Power") ~= nil then
			local dist = (d:GetPivot().Position - plat.Position).Magnitude
			if dist < 8 and (not bd or dist < bd) then best, bd = d, dist end
		end
	end
	return best
end

local function describe(prompt)
	local action, object = prompt.ActionText, prompt.ObjectText
	-- river egg
	local egg = ancestorWith(prompt.Parent, "EggType") or ancestorWith(prompt.Parent, "EggName")
	if egg and prompt.Parent.Name == "CollectAnchor" then
		local price = tonumber(egg:GetAttribute("Price")) or 0
		local name = egg:GetAttribute("EggName") or ((egg:GetAttribute("EggType") or "Mystery") .. " Egg")
		if not tostring(name):find("Egg") then name = name .. " Egg" end
		return { kind = "egg", title = name, badge = egg:GetAttribute("Rarity"), price = price,
			info = price > 0 and ("$" .. short(price)) or "FREE", infoColor = price > 0 and INK or GREEN, button = "BUY", color = GREEN }
	end
	-- hatched character waiting in the incubator
	if prompt.Name == "PickUpCharacter" then
		local m = nearestModel(anchorPos(prompt) or Vector3.zero, "HatchRewardDisplay", 18)
		local name = m and (m:GetAttribute("CharacterName") or m.Name) or object:match("^(.-) •") or object
		local p, inc = m and m:GetAttribute("Power"), m and m:GetAttribute("IncomePerSecond")
		local info = (p and ("Power " .. short(p)) or object:match("Power [%d%.%a]+") or "") .. (inc and ("  •  $" .. short(inc) .. "/s") or "")
		return { kind = "grab", title = name, badge = m and m:GetAttribute("Rarity"), info = info, button = "GRAB", color = GREEN }
	end
	-- owner pick-up (local prompt)
	if prompt.Name == "PickUpPlaced" then
		local m = placedOn(prompt.Parent.Parent)
		local name = m and (m:GetAttribute("CharacterName") or m:GetAttribute("CharacterId") or m.Name) or "Character"
		local p, inc = m and m:GetAttribute("Power"), m and m:GetAttribute("IncomePerSecond")
		return { kind = "pickup", title = name, badge = m and m:GetAttribute("Rarity"),
			info = (p and ("Power " .. short(p)) or "") .. (inc and ("  •  $" .. short(inc) .. "/s") or ""), button = "PICK UP", color = GOLD, dark = true }
	end
	-- character slots
	if prompt.Name == "PlacePrompt" then
		local n = object:match("(%d+)") or "?"
		local price = tonumber((action:gsub(",", "")):match("%$(%d+)"))
		if action:find("Unlock") then
			return { kind = "slot", title = "SLOT " .. n, badge = "LOCKED", badgeColor = MUTED, price = price, info = "$" .. short(price or 0), button = "BUY SLOT", color = GREEN }
		end
		return { kind = "place", title = "SLOT " .. n, info = "Place the character you're holding", infoColor = MUTED, button = "PLACE", color = GOLD, dark = true }
	end
	-- incubator buttons
	if prompt.Parent.Name == "HatchButton" then
		return { kind = "hatch", title = object ~= "" and object or "Incubator", info = action:find("Insert") and "Carry an egg here" or nil, infoColor = MUTED, button = string.upper(action ~= "" and action or "Use"), color = RED }
	end
	return { kind = "generic", title = object ~= "" and object or action, button = string.upper(action ~= "" and action or "Use"), color = RED }
end

---------------------------------------------------------------- card
local gui = playerGui -- billboards must sit directly in PlayerGui to render/receive input -- container for billboards (input-enabled)
local cards = {} -- prompt -> card
local W, H = 260, 66

local function keycapFor(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then return nil end
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local img = UIS:GetImageForKeyCode(prompt.GamepadKeyCode)
		return { image = img, text = prompt.GamepadKeyCode.Name:gsub("Button", "") }
	end
	local name = prompt.KeyboardKeyCode.Name
	local s = UIS:GetStringForKeyCode(prompt.KeyboardKeyCode)
	return { text = (s ~= "" and s or name):upper() }
end

local function build(prompt, inputType)
	local d = describe(prompt)
	local part = prompt.Parent
	local adornee = (part:IsA("BasePart") or part:IsA("Attachment")) and part or (part:IsA("Model") and part.PrimaryPart) or nil
	if not adornee then return end
	local bb = make("BillboardGui", { Name = "PromptCard", Adornee = adornee, Size = UDim2.fromOffset(W, H), StudsOffsetWorldSpace = Vector3.new(0, d.kind == "egg" and 2.2 or 3.4, 0),
		AlwaysOnTop = true, LightInfluence = 0, ResetOnSpawn = false, Active = true, ClipsDescendants = false, MaxDistance = 60 }, gui)
	local root = make("Frame", { Name = "Root", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 }, bb)
	local scale = make("UIScale", { Scale = 0.85 }, root)
	-- one small line of text above the button: name • rarity / info (no box)
	local line = { d.title or "" }
	if d.badge and d.kind ~= "slot" then table.insert(line, string.format('<font color="#%s">%s</font>', (RARITY[d.badge] or MUTED):ToHex(), d.badge)) end
	if d.info and d.info ~= "" and d.kind ~= "egg" and d.kind ~= "slot" then table.insert(line, d.info) end
	local info = make("TextLabel", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, FontFace = FONT, TextSize = 16, RichText = true,
		TextColor3 = Color3.new(1, 1, 1), Text = table.concat(line, "  •  "), TextTruncate = Enum.TextTruncate.AtEnd }, root)
	make("UIStroke", { Color = INK, Thickness = 1.5 }, info)
	-- chunky pill button with a small dark base
	local btnHold = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 24), Size = UDim2.fromOffset(0, 38), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1 }, root)
	local btnBase = make("Frame", { Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 1, -4), BackgroundColor3 = INK, BorderSizePixel = 0 }, btnHold)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, btnBase)
	local face = make("TextButton", { Size = UDim2.new(0, 0, 1, -4), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = d.color, AutoButtonColor = false, Text = "", BorderSizePixel = 0, ClipsDescendants = true }, btnHold)
	make("UICorner", { CornerRadius = UDim.new(1, 0) }, face); make("UIStroke", { Color = INK, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, face)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 7) }, face)
	make("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 14) }, face)
	local fill = make("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.65, BorderSizePixel = 0, ZIndex = 0 }, btnHold)
	fill.Parent = btnHold; fill.Size = UDim2.fromScale(0, 1); fill.ZIndex = 3; fill.Position = UDim2.fromOffset(0, 0); fill:SetAttribute("Fill", true); make("UICorner", { CornerRadius = UDim.new(1, 0) }, fill)
	local key = keycapFor(prompt, inputType)
	if key then
		local cap = make("Frame", { LayoutOrder = 1, Size = UDim2.fromOffset(24, 24), BackgroundColor3 = CREAM, BorderSizePixel = 0 }, face)
		make("UICorner", { CornerRadius = UDim.new(0, 7) }, cap); make("UIStroke", { Color = INK, Thickness = 1.5 }, cap)
		if key.image and key.image ~= "" then make("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = key.image }, cap)
		else make("TextLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, FontFace = FONT, TextSize = 14, TextColor3 = INK, Text = key.text }, cap) end
	else
		face:FindFirstChildOfClass("UIPadding").PaddingLeft = UDim.new(0, 14)
	end
	local function btnText() return (d.kind == "egg" or d.kind == "slot") and d.price and (d.button .. "  " .. (d.price > 0 and ("$" .. short(d.price)) or "FREE")) or (d.kind == "egg" and (d.button .. "  FREE")) or d.button end
	d.button = btnText()
	local label = make("TextLabel", { LayoutOrder = 2, Size = UDim2.fromOffset(0, 30), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, FontFace = FONT, TextSize = 18, TextColor3 = d.dark and INK or Color3.new(1, 1, 1), Text = d.button }, face)
	local card = { bb = bb, root = root, scale = scale, face = face, fill = fill, label = label, info = info, d = d, prompt = prompt, conns = {}, hold = nil }
	-- affordability (live)
	local function afford()
		if not d.price or d.price <= 0 then return end
		local ok = cash() >= d.price
		face.BackgroundColor3 = ok and d.color or GREY
		label.Text = ok and d.button or ("NEED $" .. short(d.price - cash()))
	end
	afford()
	local ls = player:FindFirstChild("leaderstats"); local cv = ls and ls:FindFirstChild("Cash")
	if cv then table.insert(card.conns, cv.Changed:Connect(afford)) end
	-- hover lift / press push
	local function facePos(y) TweenService:Create(face, TweenInfo.new(0.08), { Position = UDim2.fromOffset(0, y) }):Play() end
	table.insert(card.conns, face.MouseEnter:Connect(function() facePos(-2) end))
	table.insert(card.conns, face.MouseLeave:Connect(function() facePos(0) end))
	table.insert(card.conns, face.MouseButton1Down:Connect(function() facePos(4); prompt:InputHoldBegin() end))
	table.insert(card.conns, face.MouseButton1Up:Connect(function() facePos(0); prompt:InputHoldEnd() end))
	-- live text changes (e.g. slot bought -> PLACE)
	table.insert(card.conns, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		local nd = describe(prompt)
		if card.d.kind == "slot" and nd.kind == "place" then
			label.Text = "UNLOCKED!"; face.BackgroundColor3 = GREEN
			TweenService:Create(scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.08 }):Play()
			task.delay(0.12, function() TweenService:Create(scale, TweenInfo.new(0.15), { Scale = 1 }):Play() end)
			menuRefresh()
		end
	end))
	-- appear
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	-- river eggs already have a floating name label; hide it while the card is up (no double text)
	if d.kind == "egg" then
		local labels = playerGui:FindFirstChild("EggLabels")
		local egg = prompt.Parent.Parent
		if labels and egg then for _, b in labels:GetChildren() do
			if b:IsA("BillboardGui") and b.Adornee and b.Adornee:IsDescendantOf(egg) and b.Enabled then b.Enabled = false; card.hidLabel = b end
		end end
	end
	cards[prompt] = card
	return card
end

local function destroy(prompt, delay)
	local card = cards[prompt]; if not card then return end
	cards[prompt] = nil
	for _, c in card.conns do c:Disconnect() end
	if card.hold then card.hold:Cancel() end
	if card.hidLabel and card.hidLabel.Parent then card.hidLabel.Enabled = true end
	TweenService:Create(card.scale, TweenInfo.new(0.15), { Scale = 0.01 }):Play()
	task.delay(math.max(0.16, delay or 0), function() card.bb:Destroy() end)
end

local function confirm(card, text)
	card.label.Text = text; card.face.BackgroundColor3 = GREEN; card.fill.Size = UDim2.fromScale(1, 1)
	TweenService:Create(card.scale, TweenInfo.new(0.12, Enum.EasingStyle.Back), { Scale = 1.08 }):Play()
end

local function shake(card, text)
	if not card then return end
	card.label.Text = text
	local f = card.root
	for i, x in { 6, -6, 4, -4, 0 } do task.delay(i * 0.04, function() if f.Parent then f.Position = UDim2.fromOffset(x, 0) end end) end
end

PPS.PromptShown:Connect(function(prompt, inputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
	if cards[prompt] then destroy(prompt) end
	build(prompt, inputType)
end)
PPS.PromptHidden:Connect(function(prompt)
	local c = cards[prompt]
	destroy(prompt, c and c.confirmed and 0.35 or 0)
end)
PPS.PromptButtonHoldBegan:Connect(function(prompt)
	local c = cards[prompt]; if not c then return end
	c.fill.Size = UDim2.fromScale(0, 1)
	c.hold = TweenService:Create(c.fill, TweenInfo.new(math.max(prompt.HoldDuration, 0.01), Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }); c.hold:Play()
end)
PPS.PromptButtonHoldEnded:Connect(function(prompt)
	local c = cards[prompt]; if not c then return end
	if c.hold then c.hold:Cancel() end
	if not c.confirmed then TweenService:Create(c.fill, TweenInfo.new(0.12), { Size = UDim2.fromScale(0, 1) }):Play() end
end)
PPS.PromptTriggered:Connect(function(prompt)
	local c = cards[prompt]; if not c then return end
	local k = c.d.kind
	if k == "egg" then
		if not c.d.price or c.d.price <= cash() then
			c.confirmed = true
			confirm(c, "GOT IT!")
			UISound.Play("EggBuy")
		end
	elseif k == "grab" then
		c.confirmed = true
		confirm(c, "GRABBED!")
		UISound.Play("Claim")
	elseif k == "slot" then
		if c.d.price and c.d.price > cash() then
			shake(c, "NOT ENOUGH CASH")
		else
			UISound.Play("EggBuy")
		end
	end
end)

-- server says the egg was too expensive: show it on the card, no popup
local fb = RS:FindFirstChild("RiverEggPurchaseFeedback")
if fb then fb.OnClientEvent:Connect(function(reason)
	for p, c in cards do if c.d.kind == "egg" then c.confirmed = false; shake(c, string.upper(tostring(reason or "Not enough cash"))) end end
end) end

---------------------------------------------------------------- use Custom style everywhere (client-side only)
local function adopt(p) if p:IsA("ProximityPrompt") then p.Style = Enum.ProximityPromptStyle.Custom end end
for _, d in workspace:GetDescendants() do adopt(d) end
workspace.DescendantAdded:Connect(adopt)

---------------------------------------------------------------- owner PICK UP on occupied slots
local inv = RS:WaitForChild("CharacterInventory", 20)
local request = inv and inv:WaitForChild("InventoryRequest", 20)
local pickPrompts, plotConns = {}, {}
local pending = false
local function syncSlot(slot)
	local plat = slot:FindFirstChild("Platform"); if not plat then return end
	local want = slot:GetAttribute("Occupied") == true
	local p = pickPrompts[slot]
	if want and not p then
		p = make("ProximityPrompt", { Name = "PickUpPlaced", ActionText = "Pick up", ObjectText = "Character slot", HoldDuration = 0.35, MaxActivationDistance = 9,
			RequiresLineOfSight = false, Style = Enum.ProximityPromptStyle.Custom }, plat)
		pickPrompts[slot] = p
		p.Triggered:Connect(function()
			if pending or not request then return end
			pending = true
			local c = cards[p]
			local ok, res = pcall(request.InvokeServer, request, "PickUp", { slot = slot.Name })
			pending = false
			if ok and res and res.ok then if c then c.confirmed = true; confirm(c, "PICKED UP!") end; menuRefresh()
			else shake(cards[p], string.upper(tostring(res and res.message or "Try again"))) end
		end)
	elseif not want and p then
		pickPrompts[slot] = nil; p:Destroy()
	end
end
local function watchPlot()
	for _, c in plotConns do c:Disconnect() end; table.clear(plotConns)
	for s, p in pickPrompts do p:Destroy() end; table.clear(pickPrompts)
	local plot = myPlot(); if not plot or not plot:FindFirstChild("Slots") then return end
	for _, slot in plot.Slots:GetChildren() do
		syncSlot(slot)
		table.insert(plotConns, slot:GetAttributeChangedSignal("Occupied"):Connect(function() syncSlot(slot); menuRefresh() end))
		table.insert(plotConns, slot:GetAttributeChangedSignal("Unlocked"):Connect(menuRefresh))
	end
end
task.spawn(function()
	local plots = workspace:WaitForChild("Plots")
	for _, p in plots:GetChildren() do p:GetAttributeChangedSignal("OwnerUserId"):Connect(watchPlot) end
	watchPlot()
end)
