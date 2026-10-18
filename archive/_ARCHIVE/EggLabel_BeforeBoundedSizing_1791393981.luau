--[[ ReplicatedStorage.EggLabel  (ModuleScript, client-only)
Clean floating text label for every river egg: name, rarity, price, plus a small Collect hint when near.
Reads data from egg attributes first, then from ReplicatedStorage.CharacterCatalog. No pricing system of its own.
Does not change spawning, river movement, rarity chances or collection. Collection is still the egg's ProximityPrompt.

Start it from a LocalScript:   require(game.ReplicatedStorage.EggLabel).Start()
Eggs are found by CollectionService tag (Config.Tag, default "RiverEgg").
]]
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local Config = {
	Tag = "RiverEgg",
	PlaytestFree = true,               -- hint says "Collect · FREE"; no charges are made either way
	MaxDistance = 90,                  -- labels hide and pause beyond this
	NearFallbackDistance = 10,         -- used only if an egg has no ProximityPrompt
	GuiSize = Vector2.new(210, 114),
	HeightAboveEgg = 0.8,              -- studs between the egg's top and the label's bottom
	Font = Enum.Font.FredokaOne,        -- swap to the exact font from your mockups if you have it
	Outline = rgb(11, 10, 14),
	PriceFree = rgb(255, 255, 0), PriceOk = rgb(20, 255, 0), PriceTooMuch = rgb(255, 16, 16),
	CurrencyStats = { "Money", "Cash", "Coins" },   -- leaderstats value used for green/red price
	CatalogFields = {
		Name = { "DisplayName", "Name", "EggName" },
		Rarity = { "Rarity", "rarity", "Tier" },
		Price = { "Price", "price", "Cost", "cost", "EggPrice" },
	},
	Rarities = {
		Common = rgb(87, 87, 87), Uncommon = rgb(20, 255, 0), Rare = rgb(31, 139, 255),
		Epic = rgb(182, 61, 255), Legendary = rgb(255, 196, 0),
	},
}

local EggLabel = { Config = Config }
EggLabel.__index = EggLabel

---------------------------------------------------------------- helpers
local function make(class, props, parent)
	local o = Instance.new(class)
	for k, v in props do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(r, p) return make("UICorner", { CornerRadius = UDim.new(0, r) }, p) end
local function stroke(p, color, th, tr) return make("UIStroke", { Color = color, Thickness = th, Transparency = tr or 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, p) end
local function textStroke(p, th) return make("UIStroke", { Color = Config.Outline, Thickness = th, LineJoinMode = Enum.LineJoinMode.Round }, p) end
local function tween(o, t, props, style, dir) local tw = TweenService:Create(o, TweenInfo.new(t, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), props); tw:Play(); return tw end

function EggLabel.FormatPrice(n)
	n = tonumber(n) or 0
	if n <= 0 then return "FREE" end
	for _, u in { { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= u[1] then
			local v = n / u[1]
			local s = v < 10 and string.format("%.2f", v) or v < 100 and string.format("%.1f", v) or tostring(math.floor(v + 0.5))
			if string.find(s, ".", 1, true) then s = s:gsub("0+$", ""):gsub("%.$", "") end
			return "$" .. s .. u[2]
		end
	end
	return "$" .. tostring(math.floor(n))
end

---------------------------------------------------------------- data (attributes → CharacterCatalog)
local catalog
local function getCatalog()
	if catalog ~= nil then return catalog end
	catalog = false
	local m = ReplicatedStorage:FindFirstChild("CharacterCatalog", true)
	if m and m:IsA("ModuleScript") then
		local ok, res = pcall(require, m)
		if ok then catalog = res else warn("[EggLabel] CharacterCatalog failed to load:", res) end
	end
	return catalog
end
local function field(t, names) if type(t) ~= "table" then return nil end for _, n in names do if t[n] ~= nil then return t[n] end end return nil end
local function findEntry(name)
	local cat = getCatalog(); if not cat or not name then return nil end
	local short = name:gsub("%s*[Ee]gg$", "")
	if type(cat.GetEgg) == "function" then local ok, e = pcall(cat.GetEgg, name); if ok and e then return e end end
	for _, pool in { cat.ById or {}, cat.Eggs or {}, cat.eggs or {}, cat } do
		if type(pool) == "table" then
			local e = pool[name] or pool[short] or pool[short .. " Egg"]
			if type(e) == "table" then return e end
			for _, v in pool do
				if type(v) == "table" then
					local n = field(v, Config.CatalogFields.Name)
					if n == name or n == short or n == short .. " Egg" then return v end
				end
			end
		end
	end
	return nil
end
local function resolve(egg)
	local name = egg:GetAttribute("EggName") or egg:GetAttribute("EggType") or egg:GetAttribute("DisplayName") or egg.Name
	local rarity, price = egg:GetAttribute("Rarity"), egg:GetAttribute("Price")
	if rarity == nil or price == nil then
		local e = findEntry(name)
		if e then
			rarity = rarity or field(e, Config.CatalogFields.Rarity)
			price = price or field(e, Config.CatalogFields.Price)
			-- Keep the egg ID as its name; catalog Name is the character reward.
		end
	end
	if not Config.Rarities[rarity] then rarity = "Common" end
	local display = tostring(name)
	if not display:lower():find("egg$") then display ..= " egg" end
	return display, rarity, tonumber(price) or 0
end

---------------------------------------------------------------- alpha fade for plain frames (hint row)
local function fadeTree(root, visible, t)
	for _, o in root:GetDescendants() do
		local props = {}
		if o:IsA("GuiObject") then
			if o:GetAttribute("_bt") == nil then o:SetAttribute("_bt", o.BackgroundTransparency) end
			props.BackgroundTransparency = visible and o:GetAttribute("_bt") or 1
			if o:IsA("TextLabel") or o:IsA("TextButton") then
				if o:GetAttribute("_tt") == nil then o:SetAttribute("_tt", o.TextTransparency) end
				props.TextTransparency = visible and o:GetAttribute("_tt") or 1
			end
		elseif o:IsA("UIStroke") then
			if o:GetAttribute("_st") == nil then o:SetAttribute("_st", o.Transparency) end
			props.Transparency = visible and o:GetAttribute("_st") or 1
		end
		if next(props) then if t > 0 then tween(o, t, props) else for k, v in props do o[k] = v end end end
	end
	if root:IsA("GuiObject") then
		if root:GetAttribute("_bt") == nil then root:SetAttribute("_bt", root.BackgroundTransparency) end
		local v = visible and root:GetAttribute("_bt") or 1
		if t > 0 then tween(root, t, { BackgroundTransparency = v }) else root.BackgroundTransparency = v end
	end
end

---------------------------------------------------------------- build
local labels = {}          -- [egg] = label
local folder               -- PlayerGui holder

local function build(self)
	local W, H = Config.GuiSize.X, Config.GuiSize.Y
	local gui = make("BillboardGui", {
		Name = "EggLabel_" .. self.name, Size = UDim2.fromOffset(W, H), SizeOffset = Vector2.new(0, 0.5),
		StudsOffsetWorldSpace = Vector3.new(0, self.offsetY, 0), AlwaysOnTop = false, LightInfluence = 0,
		MaxDistance = Config.MaxDistance, ResetOnSpawn = false, Active = true, Adornee = self.adornee,
	}, nil)
	local root = make("CanvasGroup", { Name = "Root", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.fromOffset(W, H), BackgroundTransparency = 1, GroupTransparency = 1 }, gui)
	self.fit = make("UIScale", { Name = "Fit" }, root)
	local function text(name, y, h, size, color, str)
		local holder = make("Frame", { Name = name, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, y), Size = UDim2.new(1, -10, 0, h), BackgroundTransparency = 1 }, root)
		local function lbl(n, col, off, z)
			local t = make("TextLabel", { Name = n, Position = UDim2.fromOffset(off.X, off.Y), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Font = Config.Font, Text = str, TextColor3 = col, TextScaled = true, ZIndex = z }, holder)
			make("UITextSizeConstraint", { MaxTextSize = size, MinTextSize = math.floor(size * 0.6) }, t)
			textStroke(t, 1.6)
			return t
		end
		-- A single clean outline avoids the heavy doubled shadow.   -- solid black drop shadow, like the mockups
		return lbl("Fill", color, Vector2.zero, 2), holder
	end
	text("Name", 0, 30, 26, Color3.new(1, 1, 1), self.name)
	-- Rarity row removed: show egg name and price only.
	local priceHolder
	self.price, priceHolder = text("Price", 32, 26, 24, Config.PriceOk, EggLabel.FormatPrice(self.priceValue))
	self.emph = make("UIScale", { Name = "Emph" }, priceHolder)
	self:_updatePrice()
	-- Collect hint (custom ProximityPrompt UI, sits under the price)
	local hint = make("Frame", { Name = "Hint", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 64), Size = UDim2.fromOffset(0, 28), AutomaticSize = Enum.AutomaticSize.X, BackgroundColor3 = Config.Outline, BackgroundTransparency = 0.15 }, root)
	corner(14, hint)
	make("UIPadding", { PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) }, hint)
	make("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, VerticalAlignment = Enum.VerticalAlignment.Center, Padding = UDim.new(0, 7), SortOrder = Enum.SortOrder.LayoutOrder }, hint)
	self.key = make("TextLabel", { Name = "Key", LayoutOrder = 1, Size = UDim2.fromOffset(22, 22), BackgroundColor3 = rgb(243, 238, 232), Font = Config.Font, Text = "E", TextColor3 = Config.Outline, TextSize = 14 }, hint)
	self.keyCorner = corner(5, self.key)
	self.verb = make("TextLabel", { Name = "Verb", LayoutOrder = 2, Size = UDim2.fromOffset(0, 22), AutomaticSize = Enum.AutomaticSize.X, BackgroundTransparency = 1, Font = Config.Font, Text = "Collect", TextColor3 = rgb(243, 238, 232), TextSize = 15 }, hint)
	self.hint = hint
	fadeTree(hint, false, 0)
	self.tap = make("TextButton", { Name = "TapTarget", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 60), Size = UDim2.fromOffset(190, 36), BackgroundTransparency = 1, Text = "", Active = false, Visible = false }, root)
	self.gui, self.root = gui, root
	gui.Parent = folder
end

local function playerMoney()
	local ls = Players.LocalPlayer:FindFirstChild("leaderstats")
	if not ls then return nil end
	for _, n in Config.CurrencyStats do local v = ls:FindFirstChild(n); if v and (v:IsA("IntValue") or v:IsA("NumberValue")) then return v.Value end end
	return nil
end
function EggLabel:_updatePrice()
	local col
	if self.priceValue <= 0 then col = Config.PriceFree
	else col = Config.PriceOk end
	if self.price.TextColor3 ~= col then self.price.TextColor3 = col end
end

function EggLabel:_appear()
	if self.shown then return end
	self.shown = true
	tween(self.root, 0.25, { GroupTransparency = 0, Position = UDim2.fromScale(0.5, 0.5) })
end

function EggLabel:_setActive(on) self.active = on end

local function inputKind(promptInput)
	if promptInput == Enum.ProximityPromptInputType.Touch then return "touch" end
	if promptInput == Enum.ProximityPromptInputType.Gamepad then return "gamepad" end
	if promptInput == Enum.ProximityPromptInputType.Keyboard then return "keyboard" end
	local last = UserInputService:GetLastInputType()
	if last == Enum.UserInputType.Touch then return "touch" end
	if last.Name:find("Gamepad") then return "gamepad" end
	return "keyboard"
end
local PAD = { ButtonX = { "X", rgb(47, 111, 224) }, ButtonA = { "A", rgb(52, 168, 83) }, ButtonB = { "B", rgb(220, 60, 60) }, ButtonY = { "Y", rgb(230, 180, 40) } }

function EggLabel:SetNear(on, promptInput)
	if not self.shown or self.collecting then on = false end
	if self.near == on then return end
	self.near = on
	local free = Config.PlaytestFree and " · Free" or ""
	if on then
		local kind, p = inputKind(promptInput), self.prompt
		if kind == "gamepad" then
			local pad = PAD[(p and p.GamepadKeyCode or Enum.KeyCode.ButtonX).Name] or PAD.ButtonX
			self.key.Text, self.key.BackgroundColor3, self.key.TextColor3 = pad[1], pad[2], Color3.new(1, 1, 1)
			self.keyCorner.CornerRadius = UDim.new(1, 0)
			self.verb.Text = "Collect" .. free
		elseif kind == "touch" then
			self.key.Text, self.key.BackgroundColor3 = "", rgb(243, 238, 232)
			self.keyCorner.CornerRadius = UDim.new(1, 0)
			self.verb.Text = "Tap to collect" .. free
		else
			local code = p and p.KeyboardKeyCode or Enum.KeyCode.E
			local str = UserInputService:GetStringForKeyCode(code)
			self.key.Text = (str ~= nil and str ~= "") and str:upper() or code.Name
			self.key.BackgroundColor3, self.key.TextColor3 = rgb(243, 238, 232), Config.Outline
			self.keyCorner.CornerRadius = UDim.new(0, 5)
			self.verb.Text = "Collect" .. free
		end
		self.key:SetAttribute("_bt", 0); self.key:SetAttribute("_tt", 0)
		self.tap.Visible, self.tap.Active = kind == "touch", kind == "touch"
	else
		self.tap.Visible, self.tap.Active = false, false
	end
	fadeTree(self.hint, on, 0.2)
	tween(self.emph, 0.2, { Scale = on and 1.1 or 1 })
end

-- collected=true: quick pulse, then fade. false: the egg drifted away, so just fade.
function EggLabel:Remove(collected)
	if self.collecting then return end
	self.collecting = true
	self:SetNear(false)
	if self.adornee and not self.adornee:IsDescendantOf(workspace) then
		self.temp = make("Part", { Name = "EggLabelTemp", Anchored = true, CanCollide = false, CanQuery = false, CanTouch = false, Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(self.lastPos or self.adornee.Position) }, workspace)
		self.gui.Adornee = self.temp
	end
	if collected and self.shown then
		local base = self.fit.Scale
		local up = tween(self.fit, 0.12, { Scale = base * 1.1 })
		up.Completed:Once(function()
			tween(self.fit, 0.3, { Scale = base * 0.85 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			tween(self.root, 0.3, { GroupTransparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		end)
		task.delay(0.5, function() self:Destroy() end)
	else
		tween(self.root, 0.2, { GroupTransparency = 1 })
		task.delay(0.25, function() self:Destroy() end)
	end
end

function EggLabel:Destroy()
	if not self.alive then return end
	self.alive = false
	for _, c in self.conns do c:Disconnect() end
	if self.gui then self.gui:Destroy() end
	if self.temp then self.temp:Destroy() end
	if labels[self.egg] == self then labels[self.egg] = nil end
end

-- shared 10 Hz update for every label (distance, scale, fallback near)
function EggLabel:_tick(camPos, charPos, vp)
	local a = self.adornee
	if self.collecting or not a or not a:IsDescendantOf(workspace) then return end
	local pos = a.Position
	self.lastPos = pos
	local dist = math.max((camPos - pos).Magnitude, charPos and (charPos - pos).Magnitude or 0)
	self.active = dist <= Config.MaxDistance
	if not self.active then return end
	self:_updatePrice()
	local sc = math.clamp(12 / math.max(dist, 12), 0.12, 1) * vp
	if math.abs(sc - self.fit.Scale) > 0.004 then
		self.fit.Scale = sc
		self.gui.Size = UDim2.fromOffset(Config.GuiSize.X * sc, Config.GuiSize.Y * sc)
	end
	if not self.prompt and charPos and self.collectible then
		self:SetNear((charPos - pos).Magnitude <= Config.NearFallbackDistance)
	end
end

---------------------------------------------------------------- attach / start
local function pickAdornee(egg)
	if egg:IsA("BasePart") then return egg end
	for _, n in { "LabelAnchor", "EggLabelAnchor" } do
		local p = egg:FindFirstChild(n, true); if p and p:IsA("BasePart") then return p end
	end
	return egg.PrimaryPart or egg:FindFirstChildWhichIsA("BasePart", true)
end

function EggLabel.Attach(egg)
	if egg:GetAttribute("RiverEggVisual") ~= true then return end
	if labels[egg] or not (egg:IsA("Model") or egg:IsA("BasePart")) then return labels[egg] end
	local adornee = pickAdornee(egg)
	if not adornee then
		local t0 = os.clock()
		repeat task.wait(0.2); adornee = pickAdornee(egg) until adornee or os.clock() - t0 > 5 or not egg.Parent
		if not adornee or labels[egg] then return labels[egg] end
	end
	local name, rarity, price = resolve(egg)
	local topY
	if egg:IsA("Model") then local cf, size = egg:GetBoundingBox(); topY = cf.Position.Y + size.Y / 2 else topY = adornee.Position.Y + adornee.Size.Y / 2 end
	local self = setmetatable({ egg = egg, adornee = adornee, name = name, rarity = rarity, priceValue = price,
		offsetY = (adornee.Name == "LabelAnchor" and -1.2 or topY - adornee.Position.Y + Config.HeightAboveEgg),
		alive = true, active = true, conns = {} }, EggLabel)
	labels[egg] = self
	build(self)
	-- ProximityPrompt: draw it ourselves so nothing overlaps the label
	local prompt = egg:FindFirstChildWhichIsA("ProximityPrompt", true)
	local function hook(p)
		if self.prompt or not p:IsA("ProximityPrompt") then return end
		self.prompt = p
		p.Style = Enum.ProximityPromptStyle.Custom
		table.insert(self.conns, p.PromptShown:Connect(function(it) self:SetNear(true, it) end))
		table.insert(self.conns, p.PromptHidden:Connect(function() self:SetNear(false) end))
		table.insert(self.conns, p.Triggered:Connect(function() self.triggeredAt = os.clock() end))
		table.insert(self.conns, self.tap.Activated:Connect(function()
			if not p.Enabled then return end
			p:InputHoldBegin()
			task.delay(p.HoldDuration + 0.05, function() p:InputHoldEnd() end)
		end))
	end
	if prompt then hook(prompt) end
	table.insert(self.conns, egg.DescendantAdded:Connect(hook))
	-- appear when collectible (attribute optional)
	local function check()
		self.collectible = egg:GetAttribute("Collectible") ~= false
		if self.collectible then self:_appear() end
	end
	table.insert(self.conns, egg:GetAttributeChangedSignal("Collectible"):Connect(check))
	table.insert(self.conns, egg:GetAttributeChangedSignal("Collected"):Connect(function() if egg:GetAttribute("Collected") then self:Remove(true) end end))
	table.insert(self.conns, egg.AncestryChanged:Connect(function(_, parent)
		if parent == nil then EggLabel.Detach(egg) end
	end))
	check()
	return self
end

function EggLabel.Detach(egg)
	local l = labels[egg]
	if not l then return end
	local collected = egg:GetAttribute("Collected") == true or (l.triggeredAt ~= nil and os.clock() - l.triggeredAt < 1.5)
	l:Remove(collected)
end

local started = false
function EggLabel.Start(tag)
	if started then return end
	started = true
	tag = tag or Config.Tag
	local player = Players.LocalPlayer
	folder = Instance.new("Folder")
	folder.Name = "EggLabels"
	folder.Parent = player:WaitForChild("PlayerGui")
	for _, inst in CollectionService:GetTagged(tag) do task.spawn(EggLabel.Attach, inst) end
	CollectionService:GetInstanceAddedSignal(tag):Connect(function(inst) task.spawn(EggLabel.Attach, inst) end)
	CollectionService:GetInstanceRemovedSignal(tag):Connect(EggLabel.Detach)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 0.1 then return end
		acc = 0
		local cam = workspace.CurrentCamera
		if not cam then return end
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart")
		local vp = math.clamp(cam.ViewportSize.Y / 820, 0.68, 1)
		for _, l in labels do l:_tick(cam.CFrame.Position, hrp and hrp.Position, vp) end
	end)
end

return EggLabel